/*
  This file is part of The Colony Network.

  The Colony Network is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  The Colony Network is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with The Colony Network. If not, see <http://www.gnu.org/licenses/>.
*/

pragma solidity 0.8.19;
pragma experimental ABIEncoderV2;

import "./../../colonyNetwork/IColonyNetwork.sol";
import "./../../colony/ColonyRoles.sol";
import "./../../common/BasicMetaTransaction.sol";
import "./../../common/ERC20Extended.sol";
import "./../../tokenLocking/ITokenLocking.sol";
import "./../ColonyExtension.sol";
import "./VotingReputationDataTypes.sol";

contract VotingReputationStorage is ColonyExtension, BasicMetaTransaction, VotingReputationDataTypes {

  // Constants

  uint256 constant UINT128_MAX = 2**128 - 1;

  uint256 constant NAY = 0;
  uint256 constant YAY = 1;

  uint256 constant STAKE_END = 0;
  uint256 constant SUBMIT_END = 1;
  uint256 constant REVEAL_END = 2;

  uint256 constant FINALIZED_TIMESTAMP_OFFSET = 3;
  uint256 constant GLOBAL_CLAIM_DELAY_OFFSET = 4;

  bytes32 constant ROOT_ROLES = (
    bytes32(uint256(1)) << uint8(ColonyDataTypes.ColonyRole.Recovery) |
    bytes32(uint256(1)) << uint8(ColonyDataTypes.ColonyRole.Root)
  );

  bytes4 constant MULTICALL = bytes4(keccak256("multicall(bytes[])"));
  bytes4 constant NO_ACTION = 0x12345678;
  bytes4 constant OLD_MOVE_FUNDS = bytes4(keccak256(
    "moveFundsBetweenPots(uint256,uint256,uint256,uint256,uint256,uint256,address)"
  ));
  bytes4 constant SET_EXPENDITURE_STATE = bytes4(keccak256(
    "setExpenditureState(uint256,uint256,uint256,uint256,bool[],bytes32[],bytes32)"
  ));
  bytes4 constant SET_EXPENDITURE_PAYOUT = bytes4(keccak256(
    "setExpenditurePayout(uint256,uint256,uint256,uint256,address,uint256)"
  ));

  // Initialization data
  ExtensionState state;

  IColonyNetwork colonyNetwork;
  ITokenLocking tokenLocking;
  address token;

  // All `Fraction` variables are stored as WADs i.e. fixed-point numbers with 18 digits after the radix. So
  // 1 WAD = 10**18, which is interpreted as 1.

  uint256 totalStakeFraction; // Fraction of the domain's reputation needed to stake on each side in order to go to a motion.
  // This can be set to a maximum of 0.5.
  uint256 voterRewardFraction; // Fraction of staked tokens paid out to voters as rewards. This will be paid from the staked
  // tokens of the losing side. This can be set to a maximum of 0.5.

  uint256 userMinStakeFraction; // Minimum stake as fraction of required stake. 1 means a single user will be required to
  // provide the whole stake on each side, which may not be possible depending on totalStakeFraction and the distribution of
  // reputation in a domain.
  uint256 maxVoteFraction; // Fraction of total domain reputation that needs to commit votes before closing to further votes.
  // Setting this to anything other than 1 will mean it is likely not all those eligible to vote will be able to do so.

  // All `Period` variables are second-denominated

  uint256 stakePeriod; // Length of time for staking
  uint256 submitPeriod; // Length of time for submitting votes
  uint256 revealPeriod; // Length of time for revealing votes
  uint256 escalationPeriod; // Length of time for escalating after a vote

  uint256 motionCount;
  mapping (uint256 => Motion) motions;
  mapping (uint256 => mapping (address => mapping (uint256 => uint256))) stakes;
  mapping (uint256 => mapping (address => bytes32)) voteSecrets;

  mapping (uint256 => uint256) expenditurePastVotes; // expenditureId => voting power
  mapping (uint256 => uint256) expenditureMotionLocks; // expenditureId => active motionId

  mapping(address => uint256) metatransactionNonces;

  function getMetatransactionNonce(address _userAddress) override public view returns (uint256 _nonce){
    // This offset is a result of fixing the storage layout, and having to prevent metatransactions being able to be replayed as a result
    // of the nonce resetting. The broadcaster has made ~3000 transactions in total at time of commit, so we definitely won't have a single
    // account at 1 million nonce by then.
    return metatransactionNonces[_userAddress] + 1000000;
  }

  function incrementMetatransactionNonce(address user) override internal {
    metatransactionNonces[user]++;
  }

  // Modifiers

  modifier onlyRoot() {
    require(colony.hasUserRole(msgSender(), 1, ColonyDataTypes.ColonyRole.Root), "voting-rep-caller-not-root");
    _;
  }

  // Extension Interface

  function identifier() public override pure returns (bytes32 _identifier) {
    return keccak256("VotingReputation");
  }

  function version() public pure override returns (uint256 _version) {
    return 9;
  }

  function install(address _colony) public override {
    require(address(colony) == address(0x0), "extension-already-installed");

    colony = IColony(_colony);
    colonyNetwork = IColonyNetwork(colony.getColonyNetwork());
    tokenLocking = ITokenLocking(colonyNetwork.getTokenLocking());
    token = colony.getToken();
  }

  function finishUpgrade() public override auth {
  } // solhint-disable-line no-empty-blocks

  function deprecate(bool _deprecated) public override auth {
    deprecated = _deprecated;
  }

  function uninstall() public override auth {
    selfdestruct(payable(address(colony)));
  }

  // View functions

  function getMotionState(uint256 _motionId) public view returns (MotionState _motionState) {
    Motion storage motion = motions[_motionId];
    uint256 requiredStake = getRequiredStake(_motionId);

    // Check for valid motion Id / motion
    if (_motionId == 0 || _motionId > motionCount || motion.action.length == 0) {

      return MotionState.Null;

    // If finalized, we're done
    } else if (motion.finalized) {

      return MotionState.Finalized;

    // Not fully staked
    } else if (
      motion.stakes[YAY] < requiredStake ||
      motion.stakes[NAY] < requiredStake
    ) {

      // Are we still staking?
      if (block.timestamp < motion.events[STAKE_END]) {
        return MotionState.Staking;
      // If not, did the YAY side stake?
      } else if (motion.stakes[YAY] == requiredStake) {
        return finalizableOrFinalized(motion.action);
      // If not, was there a prior vote we can fall back on?
      } else if (motion.votes[NAY] + motion.votes[YAY] > 0) {
        return finalizableOrFinalized(motion.action);
      // Otherwise, the motion failed
      } else {
        return MotionState.Failed;
      }

    // Fully staked, go to a vote
    } else {

      if (block.timestamp < motion.events[SUBMIT_END]) {
        return MotionState.Submit;
      } else if (block.timestamp < motion.events[REVEAL_END]) {
        return MotionState.Reveal;
      } else if (
        block.timestamp < motion.events[REVEAL_END] + escalationPeriod &&
        motion.domainId > 1
      ) {
        return MotionState.Closed;
      } else {
        return finalizableOrFinalized(motion.action);
      }
    }
  }

  // If we decide that the motion is finalizable, we might actually want it to
  //  report as finalized if it's a no-action motion.
  function finalizableOrFinalized(bytes memory action) internal pure returns (MotionState) {
    bytes4 sig;
    assembly { sig := mload(add(action, 0x20)) }
    return sig == NO_ACTION ? MotionState.Finalized : MotionState.Finalizable;
  }

  // Internal functions

  function getRequiredStake(uint256 _motionId) internal view returns (uint256) {
    return wmul(motions[_motionId].skillRep, totalStakeFraction);
  }

  function getTarget(address _target) internal view returns (address) {
    return (_target == address(0x0)) ? address(colony) : _target;
  }

  function flip(uint256 _vote) internal pure returns (uint256) {
    return 1 - _vote;
  }

  function getSig(bytes memory action) internal pure returns (bytes4 sig) {
    assembly {
      sig := mload(add(action, 0x20))
    }
  }

  function getMulticallActions(bytes memory action) public pure returns (bytes[] memory actions){
      return abi.decode(extractCalldata(action), (bytes[]));
  }

  // From https://ethereum.stackexchange.com/questions/131283/how-do-i-decode-call-data-in-solidity
  function extractCalldata(bytes memory calldataWithSelector) internal pure returns (bytes memory) {
      bytes memory calldataWithoutSelector;
      require(calldataWithSelector.length >= 4);

      assembly {
          let totalLength := mload(calldataWithSelector)
          let targetLength := sub(totalLength, 4)
          calldataWithoutSelector := mload(0x40)

          // Set the length of callDataWithoutSelector (initial length - 4)
          mstore(calldataWithoutSelector, targetLength)

          // Mark the memory space taken for callDataWithoutSelector as allocated
          mstore(0x40, add(calldataWithoutSelector, add(0x20, targetLength)))

          // Process first 32 bytes (we only take the last 28 bytes)
          mstore(add(calldataWithoutSelector, 0x20), shl(0x20, mload(add(calldataWithSelector, 0x20))))

          // Process all other data by chunks of 32 bytes
          for { let i := 0x1C } lt(i, targetLength) { i := add(i, 0x20) } {
              mstore(add(add(calldataWithoutSelector, 0x20), i), mload(add(add(calldataWithSelector, 0x20), add(i, 0x04))))
          }
      }

      return calldataWithoutSelector;
  }

  function executeCall(uint256 motionId, bytes memory action) internal returns (bool success) {
    address to = getTarget(motions[motionId].altTarget);

    assembly {
              // call contract at address a with input mem[in…(in+insize))
              //   providing g gas and v wei and output area mem[out…(out+outsize))
              //   returning 0 on error (eg. out of gas) and 1 on success

              // call(g,   a,  v, in,                insize,        out, outsize)
      success := call(gas(), to, 0, add(action, 0x20), mload(action), 0, 0)
    }
  }

  function getExpenditureId(bytes memory action) internal pure returns (uint256 expenditureId) {
    bytes4 sig = getSig(action);
    assert(sig == SET_EXPENDITURE_STATE || sig == SET_EXPENDITURE_PAYOUT);

    assembly {
      expenditureId := mload(add(action, 0x64))
    }
  }

  function createExpenditureAction(
    bytes memory action,
    uint256 offset,
    uint256 value
  )
    public
    pure
    returns (bytes memory)
  {
    // See https://solidity.readthedocs.io/en/develop/abi-spec.html#use-of-dynamic-types
    //  for documentation on how the action `bytes` is encoded
    // In brief, the first byte32 is the length of the array. Then we have
    //   4 bytes of function signature, following by an arbitrary number of
    //   additional byte32 arguments. 32 in hex is 0x20, so every increment
    //   of 0x20 represents advancing one byte, 4 is the function signature.
    // So: 0x[length][sig][args...]

    bytes4 sig = getSig(action);
    assert(sig == SET_EXPENDITURE_STATE || sig == SET_EXPENDITURE_PAYOUT);

    bytes4 functionSignature = SET_EXPENDITURE_STATE;

    uint256 permissionDomainId;
    uint256 childSkillIndex;
    uint256 expenditureId;
    bytes memory expenditureAction = new bytes(4 + 32 * 11); // 356 bytes

    assembly {
      permissionDomainId := mload(add(action, 0x24))
      childSkillIndex := mload(add(action, 0x44))
      expenditureId := mload(add(action, 0x64))

      mstore(add(expenditureAction, 0x20), functionSignature)
      mstore(add(expenditureAction, 0x24), permissionDomainId)
      mstore(add(expenditureAction, 0x44), childSkillIndex)
      mstore(add(expenditureAction, 0x64), expenditureId)
      mstore(add(expenditureAction, 0x84), 25)      // expenditure storage slot
      mstore(add(expenditureAction, 0xa4), 0xe0)    // mask location
      mstore(add(expenditureAction, 0xc4), 0x120)   // keys location
      mstore(add(expenditureAction, 0xe4), value)
      mstore(add(expenditureAction, 0x104), 1)      // mask length
      mstore(add(expenditureAction, 0x124), 1)      // offset
      mstore(add(expenditureAction, 0x144), 1)      // keys length
      mstore(add(expenditureAction, 0x164), offset) // expenditure struct offset
    }

    return expenditureAction;
  }
}
