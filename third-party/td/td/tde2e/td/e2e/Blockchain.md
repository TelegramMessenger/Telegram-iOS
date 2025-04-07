# Blockchain Implementation Documentation

## Overview

The blockchain implementation provides a distributed ledger system that maintains a consistent state across multiple participants. It supports key-value storage, participant management, and secure state transitions. The blockchain is designed with security in mind, ensuring only valid blocks with proper signatures and correct heights can be applied.

## Core Components

### Block Structure

As defined in the e2e_api.tl scheme:
```
e2e.chain.block signature:int512 flags:# prev_block_hash:int256 changes:vector<e2e.chain.Change> height:int state_proof:e2e.chain.StateProof signature_public_key:flags.0?int256 = e2e.chain.Block;
```

A block consists of:
- **Signature**: Cryptographic signature verifying the block's authenticity
- **Previous Block Hash**: Links to the previous block, creating a chain
- **Changes**: A vector of operations to apply to the blockchain state
- **Height**: Sequential block number, critical for validation
- **State Proof**: Contains hashes and states for validation. This proof represents the state of the blockchain after the block was applied.
- **Signature Public Key**: The key of the participant who created the block

### Signature Generation

The signature is generated for the TL-serialized block with the signature field zeroed.

### Block Hash Generation

The hash of the block is the SHA256 of the TL-serialized block.

### Change Types

The blockchain supports four types of changes:

1. **ChangeSetValue**: Updates a key-value pair in the blockchain
   ```
   e2e.chain.changeSetValue key:bytes value:bytes = e2e.chain.Change;
   ```

2. **ChangeSetGroupState**: Updates the group of participants and their permissions
   ```
   e2e.chain.groupParticipant user_id:long public_key:int256 flags:# add_users:flags.0?true remove_users:flags.1?true version:int = e2e.chain.GroupParticipant;
   e2e.chain.groupState participants:vector<e2e.chain.GroupParticipant> = e2e.chain.GroupState;
   e2e.chain.changeSetGroupState group_state:e2e.chain.GroupState = e2e.chain.Change;
   ```

3. **ChangeSetSharedKey**: Updates the encryption keys shared among participants
   ```
   e2e.chain.sharedKey ek:int256 encrypted_shared_key:string dest_user_id:vector<long> dest_header:vector<bytes> = e2e.chain.SharedKey;
   e2e.chain.changeSetSharedKey shared_key:e2e.chain.SharedKey = e2e.chain.Change;
   ```

4. **ChangeNoop**: Does nothing and can be used for hash randomization. Currently, it must be present in the zero block.
   ```
   e2e.chain.changeNoop random:int256 = e2e.chain.Change;
   ```

### Participants and Permissions

Participants in the blockchain have specific permissions:
- **AddUsers**: Can add new participants to the blockchain
- **RemoveUsers**: Can remove existing participants from the blockchain

```
e2e.chain.groupParticipant user_id:long public_key:int256 flags:# add_users:flags.0?true remove_users:flags.1?true version:int = e2e.chain.GroupParticipant;
```

### Implementation Details

#### Key-Value State

The blockchain uses a persistent trie for key-value storage, with the following properties:
- Supports set/get operations
- Generates pruned trees for a given set of keys
- A pruned tree allows:
  - `get` operations for any of the specified keys
  - `set` operations for any of those keys to create a new (pruned) trie

```c++
td::Result<TrieRef> set(TrieRef n, BitString key, td::Slice value, td::Slice snapshot = {});
td::Result<std::string> get(const TrieRef &n, BitString key, td::Slice snapshot = {});
td::Result<TrieRef> generate_pruned_tree(const TrieRef &n, td::Span<td::Slice> keys, td::Slice snapshot = {});
```

The trie can be serialized for network transmission or persistent storage:

```c++
static td::Result<std::string> serialize_for_network(TrieRef node);
static td::Result<TrieRef> fetch_from_network(td::Slice data);
static td::Result<std::string> serialize_for_snapshot(TrieRef node, td::Slice snapshot);
static td::Result<TrieRef> fetch_from_snapshot(td::Slice snapshot);
```

- `{serialize_for,fetch_from}_network` is used for passing a pruned trie over the network
- `{serialize_for,fetch_from}_snapshot` is used by the server to persist the entire state to disk

#### Blockchain State

The complete blockchain state consists of:
- A trie (TrieRef root + Slice snapshot) for key-value storage
- A group state (participants and their permissions)
- Shared key information (encryption keys shared among participants)

## Expected Behaviors

### Block Application Process

A block is either applied completely or not at all.

1. The block's height is checked. It must be exactly one more than the current blockchain height.
   - If the height is incorrect, the block is rejected with `HEIGHT_MISMATCH`
2. The hash of the previous block is checked. It must match the hash of the last applied block.
   - If the hash is incorrect, the block is rejected with `PREVIOUS_BLOCK_HASH_MISMATCH`
3. The permissions of the participant who created the block (the one with `signer_public_key`) are determined.
   - First, we look for the signer's public key in the previous state. If found, we use its permissions; otherwise, we use external_permissions
4. The block signature is verified.
   - If the signature is invalid, the block is rejected with `INVALID_SIGNATURE`
5. Next, changes from the block are applied one by one.
   - Before applying a change, we check that the participant has sufficient permissions to apply it.
   - Then, the change is applied.
   - After applying a block, the block creator's permissions could be updated. This is important because any subsequent changes should be applied using the new permissions. The idea is that applying changes in the same block should yield the same result as applying them in separate blocks.
   - If any change is invalid, the block is rejected with the corresponding error.
6. After all changes are applied, the block's state proof must be valid for the new state.
   - If the state proof is invalid, the block is rejected with `INVALID_STATE_PROOF`

To apply the first block, an ephemeral block with height `-1` is used:
   - It has a hash of `UInt256(0)`
   - Its height is `-1`
   - It has effective (but not explicitly stored, i.e., not reflected in its hash) `self_join_permissions` with all permissions

There are also several optimizations for block serialization:
   - The `signer_public_key` can be omitted if it is the same as the public key of the first participant in the group state
   - `group_state` in `state_proof` can be omitted if there is a `SetGroupState` change in the block
   - `shared_key` in `state_proof` can be omitted if there is a `SetSharedKey` or `SetGroupState` change in the block

### Applying Changes

The idea is that applying changes within the same block should lead to the same state as applying them in multiple blocks.

#### Key Value Updates

Currently, any participant can update any key with a new value. This change is always successful. Deletion is the same as overwriting with an empty value.

- The trie is updated with the new value
- The trie hash must be stored in the new state proof

### Participant Management

- Only participants with the `AddUsers` permission can add new participants
- A participant may add users with permissions that are a non-strict subset of its own permissions
- As an exception, it is possible to give permissions to another user
- Only participants with the `RemoveUsers` permission can remove existing participants
- Both the public key and user ID are unique in the group state
- Any new state of the group is allowed otherwise
- The shared key is automatically cleared by this change

#### Shared Key Updates

- The shared key cannot be overwritten by other participants. One must update the group state to clear the key first.
- The shared key is automatically cleared by a `SetGroupState` change.
- The shared key must contain all user_ids of all participants, and only them.
- How the shared key is encrypted is not the blockchain's concern.
- Only participants may update the key.

Note:
- It is impossible to create a new key if the user is not in the group, even if it is an automatic removal of the key
- Only participants may create a new key
- It is impossible to remove yourself from the group (this could be allowed in the future, but would lead to an empty shared key)

## Known Behaviors and Considerations

### Multiple Blocks at the Same Height

If two blocks are built concurrently for the same height:
- Only the first applied block will succeed
- The second block will be rejected with `HEIGHT_MISMATCH`
- This is intended behavior to avoid forks and force all changes to be applied **exactly** in the way the creator intended

### Partial State Handling

The client library does not store the entire key-value state. To create a block, the client must receive a proof of all changed keys from the server.

### Security

There are several aspects we should be particularly careful about:

1. Clients must apply only blocks received from the server. This is especially important for blocks created by the client itself. The server does extra work to ensure correctness of blocks and to prevent forks. Forks per se are not a security problem, but they would lead to broken calls.

2. Blocks should be sent to the server until a response is received. This could be either success or error. In case of an error like INVALID_BLOCK__HASH_MISMATCH, a new block could be created, but one should be careful about how the group state has been changed.

3. Broadcast blocks should also be sent until they are accepted or declined.



