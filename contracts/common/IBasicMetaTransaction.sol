// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.27;

interface IBasicMetaTransaction {
  event MetaTransactionExecuted(address userAddress, address payable relayerAddress, bytes payload);

  /// @notice Executes a metatransaction targeting this contract
  /// @param userAddress The address of the user that signed the metatransaction
  /// @param payload The transaction data that will be executed if signature valid
  /// @param sigR The 'r' part of the signature
  /// @param sigS The 's' part of the signature
  /// @param sigV The 'v' part of the signature
  /// @return returnData The return data of the executed transaction
  function executeMetaTransaction(
    address userAddress,
    bytes memory payload,
    bytes32 sigR,
    bytes32 sigS,
    uint8 sigV
  ) external payable returns (bytes memory returnData);

  /// @notice Gets the next metatransaction nonce for user that should be used targeting this contract
  /// @param userAddress The address of the user that will sign the metatransaction
  /// @return nonce The nonce that should be used for the next metatransaction
  function getMetatransactionNonce(address userAddress) external view returns (uint256 nonce);
}
