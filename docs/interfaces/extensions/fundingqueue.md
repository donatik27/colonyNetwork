# Funding Queue (`FundingQueue`)

Funding Queues are a core mechanic described in the Colony whitepaper,
allowing for teams to allocate resources in a distributed manner. Members of
a colony can make and back funding proposals, requesting that some number of tokens be
transferred between domains. The more reputation backing a proposal, the more
quickly the proposal is fulfilled, up to a maximum of half of the source domain's
assets per week. By creating and backing funding proposals throughout the colony,
a steady flow of resources from the root through the domains can be achieved.

_This is a Colony Extension which conforms to the extension interface found [here](icolonyextension.md)._

  
## Interface Methods

### ▸ `authority():DSAuthority authority`

Get the authority of the contract



**Return Parameters**

|Name|Type|Description|
|---|---|---|
|authority|DSAuthority|The authority of the contract

### ▸ `backProposal(uint256 _id, uint256 _backing, uint256 _currPrevId, uint256 _newPrevId, bytes memory _key, bytes memory _value, uint256 _branchMask, bytes32[] memory _siblings)`

Back a funding proposal and advance it along the list


**Parameters**

|Name|Type|Description|
|---|---|---|
|_id|uint256|The proposal Id
|_backing|uint256|The amount of backing to give the proposal (up to user's reputation)
|_currPrevId|uint256|The current previous proposal in the list
|_newPrevId|uint256|The new previous proposal after we re-arrange
|_key|bytes|A reputation hash tree key, of the caller's reputation in _domainId
|_value|bytes|Reputation value indicating the caller's reputation in _domainId
|_branchMask|uint256|The branchmask of the proof
|_siblings|bytes32[]|The siblings of the proof


### ▸ `cancelProposal(uint256 _id, uint256 _prevId)`

Cancel a funding proposal and remove from linked list


**Parameters**

|Name|Type|Description|
|---|---|---|
|_id|uint256|The proposal Id
|_prevId|uint256|The id of the preceding proposal in the linked list


### ▸ `createProposal(uint256 _domainId, uint256 _fromChildSkillIndex, uint256 _toChildSkillIndex, uint256 _fromPot, uint256 _toPot, uint256 _totalRequested, address _token)`

Create a new funding proposal


**Parameters**

|Name|Type|Description|
|---|---|---|
|_domainId|uint256|The domain the extension has the funding permission
|_fromChildSkillIndex|uint256|The index of the fromPot's domain in _domainId.children[]
|_toChildSkillIndex|uint256|The index of the toPot's domain in _domainId.children[]
|_fromPot|uint256|Funding pot id providing the funds
|_toPot|uint256|Funding pot id receiving the funds
|_totalRequested|uint256|The total amount being requested
|_token|address|The token being transferred


### ▸ `deprecate(bool _deprecated)`

Called when deprecating (or undeprecating) the extension


**Parameters**

|Name|Type|Description|
|---|---|---|
|_deprecated|bool|Indicates whether the extension should be deprecated or undeprecated


### ▸ `executeMetaTransaction(address _user, bytes memory _payload, bytes32 _sigR, bytes32 _sigS, uint8 _sigV):bytes returnData`

Main function to be called when user wants to execute meta transaction. The actual function to be called should be passed as param with name functionSignature Here the basic signature recovery is being used. Signature is expected to be generated using personal_sign method.


**Parameters**

|Name|Type|Description|
|---|---|---|
|_user|address|Address of user trying to do meta transaction
|_payload|bytes|Function call to make via meta transaction
|_sigR|bytes32|R part of the signature
|_sigS|bytes32|S part of the signature
|_sigV|uint8|V part of the signature

**Return Parameters**

|Name|Type|Description|
|---|---|---|
|returnData|bytes|Return data returned by the actual function called

### ▸ `finishUpgrade()`

A function to be called after an upgrade has been done from v2 to v3.

*Note: Can only be called by the colony itself, and only expected to be called as part of the `upgrade()` call. Required to be external so it can be an external call.*



### ▸ `getCapabilityRoles(bytes4 _sig):bytes32 roles`

Gets the bytes32 representation of the roles authorized to call a function


**Parameters**

|Name|Type|Description|
|---|---|---|
|_sig|bytes4|The function signature

**Return Parameters**

|Name|Type|Description|
|---|---|---|
|roles|bytes32|bytes32 representation of the authorized roles

### ▸ `getColony():address colony`

Gets the address of the extension's colony



**Return Parameters**

|Name|Type|Description|
|---|---|---|
|colony|address|The address of the colony

### ▸ `getDeprecated():bool deprecated`

Gets the boolean indicating whether or not the extension is deprecated



**Return Parameters**

|Name|Type|Description|
|---|---|---|
|deprecated|bool|Boolean indicating whether or not the extension is deprecated

### ▸ `getMetatransactionNonce(address userAddress):uint256 nonce`

Gets the next metatransaction nonce for user that should be used targeting this contract


**Parameters**

|Name|Type|Description|
|---|---|---|
|userAddress|address|The address of the user that will sign the metatransaction

**Return Parameters**

|Name|Type|Description|
|---|---|---|
|nonce|uint256|The nonce that should be used for the next metatransaction

### ▸ `getNextProposalId(uint256 _id):uint256 nextId`

Gets the id of the next proposal in the list


**Parameters**

|Name|Type|Description|
|---|---|---|
|_id|uint256|The proposal Id

**Return Parameters**

|Name|Type|Description|
|---|---|---|
|nextId|uint256|The next proposal Id in the list

### ▸ `getProposal(uint256 _id):Proposal proposal`

Get the proposal struct for a given proposal


**Parameters**

|Name|Type|Description|
|---|---|---|
|_id|uint256|The proposal Id

**Return Parameters**

|Name|Type|Description|
|---|---|---|
|proposal|Proposal|The proposal struct

### ▸ `getProposalCount():uint256 count`

Get the total number of proposals



**Return Parameters**

|Name|Type|Description|
|---|---|---|
|count|uint256|The count

### ▸ `getSupport(uint256 _id, address _supporter):uint256 support`

Gets the reputation support from a user to a proposal


**Parameters**

|Name|Type|Description|
|---|---|---|
|_id|uint256|The proposal Id
|_supporter|address|The supporter

**Return Parameters**

|Name|Type|Description|
|---|---|---|
|support|uint256|The support amount

### ▸ `identifier():bytes32 _identifier`

Returns the identifier of the extension



**Return Parameters**

|Name|Type|Description|
|---|---|---|
|_identifier|bytes32|The extension's identifier

### ▸ `install(address _colony)`

Configures the extension


**Parameters**

|Name|Type|Description|
|---|---|---|
|_colony|address|The colony in which the extension holds permissions


### ▸ `multicall(bytes[] calldata _data):bytes[] results`

Call multiple functions in the current contract and return the data from all of them if they all succeed

*Note: The `msg.value` should not be trusted for any method callable from multicall.*

**Parameters**

|Name|Type|Description|
|---|---|---|
|_data|bytes[]|The encoded function data for each of the calls to make to this contract

**Return Parameters**

|Name|Type|Description|
|---|---|---|
|results|bytes[]|The results from each of the calls passed in via data

### ▸ `owner():address owner`

Get the owner of the contract



**Return Parameters**

|Name|Type|Description|
|---|---|---|
|owner|address|The owner of the contract

### ▸ `pingProposal(uint256 _id)`

Transfer the marginal funds


**Parameters**

|Name|Type|Description|
|---|---|---|
|_id|uint256|The proposal Id


### ▸ `reclaimStake(uint256 _id)`

Reclaim the stake after the proposal is funded


**Parameters**

|Name|Type|Description|
|---|---|---|
|_id|uint256|The proposal Id


### ▸ `setOwner(address owner_)`

Set the owner of the contract


**Parameters**

|Name|Type|Description|
|---|---|---|
|owner_|address|The new owner of the contract


### ▸ `stakeProposal(uint256 _id, bytes memory _key, bytes memory _value, uint256 _branchMask, bytes32[] memory _siblings)`

Stake a funding proposal


**Parameters**

|Name|Type|Description|
|---|---|---|
|_id|uint256|The proposal Id
|_key|bytes|A reputation hash tree key, of the total reputation in _domainId
|_value|bytes|Reputation value indicating the total reputation in _domainId
|_branchMask|uint256|The branchmask of the proof
|_siblings|bytes32[]|The siblings of the proof


### ▸ `uninstall()`

Called when uninstalling the extension




### ▸ `verify(address _user, uint256 _nonce, uint256 _chainId, bytes memory _payload, bytes32 _sigR, bytes32 _sigS, uint8 _sigV):bool bool`

Verifies the signature for the metatransaction


**Parameters**

|Name|Type|Description|
|---|---|---|
|_user|address|Address of user trying to do meta transaction
|_nonce|uint256|Nonce of the user
|_chainId|uint256|Chain id where the signature is valid for
|_payload|bytes|Function call to make via meta transaction
|_sigR|bytes32|R part of the signature
|_sigS|bytes32|S part of the signature
|_sigV|uint8|V part of the signature

**Return Parameters**

|Name|Type|Description|
|---|---|---|
|bool|bool|indicating if the signature is valid or not

### ▸ `version():uint256 colonyVersion`

Get the Colony contract version. Starts from 1 and is incremented with every deployed contract change.



**Return Parameters**

|Name|Type|Description|
|---|---|---|
|colonyVersion|uint256|Version number