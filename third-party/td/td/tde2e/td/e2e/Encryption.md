# Encryption in Secret Group Calls

A group call consists of three primary components:

1. **Blockchain** shared among all group members. This serves as a synchronization point for all group changes and generates verification codes for MitM protection. Its hash incorporates the entire history of call changes, including the shared key hash. Each block contains call participant changes and new shared keys individually encrypted for each participant.

2. **Encryption protocol** for network packets. Designed for efficiency, this protocol encrypts at the video and audio frame level rather than the network level. Each packet is signed to enable authorship verification. Similar encryption primitives secure the shared key for each participant.

3. **Emoji generation protocol**. Direct generation of emojis from the blockchain hash is vulnerable to brute-force attacks by block creators. To mitigate this, we implement a two-phase protocol: first, each party commits to a value by publishing its hash; second, each party reveals their value. The combined hash of all values introduces unpredictable randomness into the blockchain hash.

Let's examine each component in detail:

## Blockchain

The blockchain functions as a distributed ledger for managing group call state. Each block contains a participant list and new shared keys individually encrypted for all participants.

The hash of the most recent block generates **verification words**.

The hash of the most recent block, combined with unpredictable random values, generates **verification emojis**.

For improved user experience, any person can currently join a call with server permission, without requiring explicit confirmation from existing participants.
While the blockchain supports an explicit confirmation mode, we currently use `external_permissions` in the blockchain state to allow self-addition to groups.

Call security in this scheme depends on emoji verification by each participant. This approach could be enhanced in future versions with persistent user identities.

### Typical Workflow

#### Joining a Call

To join a call, a user must:
- Request the latest blockchain block from the server
- Create a new block containing updated state that includes themselves and a new shared key encrypted for all participants (including themselves)
- Submit this block to the server

The server validates that the block only adds the new user and attempts to apply it to the blockchain:

- Upon success, all participants receive the new block, update their blockchain, and implement the new shared key
- If conflicts exist (such as another block already applied at the same height), the operation fails

#### Removing a Participant from the Call

When a participant becomes inactive, they must be removed from the call. This process follows a similar pattern to joining but is initiated by any active participant.

For comprehensive details, refer to the [Blockchain documentation](Blockchain.md).

#### Security
- Clients must only apply blocks as received from the server, which prevents blockchain forks when the server operates correctly
- The blockchain state must be explicitly displayed in the UI, even when the server withholds information about certain participants
- MitM protection relies on either verification words (currently not used in UI) or emojis; all participants must verify they see identical emojis
- If the server delivers different blocks to different participants, the resulting fork hashes will permanently differ
- The creator of a new key must be included as a participant in the block since they generate the shared key
- Notably, participants cannot remove themselves from a group, as this would require generating a new shared key for the remaining participants
- Active participants should remove inactive users from the group, particularly those blocking the emoji generation process
- In the current implementation without explicit confirmations, signatures provide limited security value since anyone with a key can join a call; however, they enhance protocol robustness


## Encryption

### Core Primitives

Our encryption system utilizes several primitives similar to MTProto 2.0. The key functions include:

#### encrypt_data(payload, secret) - encrypts payload with shared secret

1) padding_size = ((16 + payload.size + 15) & -16) - payload.size
2) padding = random_bytes(padding_size) with padding[0] = padding_size
3) padded_data = padding || payload
4) large_secret = KDF(secret, "tde2e_encrypt_data")
5) encrypt_secret = large_secret[0:32]
6) hmac_secret = large_secret[32:64]
7) msg_id = HMAC-SHA512(hmac_secret, padded_data)[0:16]
8) (aes_key, aes_iv) = HMAC-SHA512(encrypt_secret, msg_id)[0:48]
9) encrypted = aes_cbc(aes_key, aes_iv, padded_data)
10) result = msg_id || encrypted

#### encrypt_header(header, encrypted_msg, secret) - encrypts 32-byte header

1) msg_id = encrypted_msg[0:16]  // First 16 bytes
2) encrypt_secret = KDF(secret, "tde2e_encrypt_header")[0:32]
3) (aes_key, aes_iv) = HMAC-SHA512(encrypt_secret, msg_id)[0:48]
4) encrypted_header = aes_cbc(aes_key, aes_iv, header)

Note: KDF refers to HMAC-SHA512 throughout this document

#### Security
- Verification of `msg_id` during decryption is essential before accepting any payload
- Replay protection is implemented at a higher protocol level

### Packet Encryption

The encryption process for video and audio packets follows this sequence:

#### encrypt_packet(payload, active_epochs, user_id, channel_id, seqno, private_key) - encrypts a packet

First, generate header_a describing the epochs (blockchain heights) in use:
1) epoch_id[i] = active_epochs[i].epoch (4 bytes)
2) header_a = active_epochs.size (4 bytes) || epoch_id[0] || epoch_id[1] || ...

Next, encrypt the payload using a one-time key. The signature in the payload incorporates the unencrypted header:
1) one_time_key = random(32)
2) packet_payload = channel_id (4 bytes) || seqno (4 bytes) || payload
3) to_sign = HMAC-SHA512(header_a, packet_payload)
4) signature = sign(to_sign, private_key) // 64 bytes
5) signed_payload = packet_payload || signature
6) encrypted_payload = encrypt_data(signed_payload, one_time_key)

Finally, encrypt the one-time key using the shared secret from each active epoch:
1) encrypted_key[i] = encrypt_header(one_time_key, encrypted_payload, active_epochs[i].shared_key) (32 bytes)
2) header_b = encrypted_key[0] || encrypted_key[1] || ...

The complete packet format is: header_a || header_b || encrypted_payload

#### Security
- The seqno value is unique for each (public key, channel_id) pair, providing protection against replay attacks; receivers should maintain records of recent seqno values and reject packets with known or outdated seqno values
- During decryption, the public key must be retrieved from the blockchain state using the externally provided user_id; this public key verifies the signature

### Shared Key Encryption

When modifying group state or shared key, the new shared key is encrypted for each participant using their respective public keys from the blockchain state:

1. Generate new cryptographic material:
   - `group_shared_key = random(32 bytes)` - the new shared key for the call
   - `one_time_secret = random(32 bytes)` - secret used for encryption
   - `e_private_key, e_public_key = generate_private_key()` - key pair used to encrypt the one_time_secret

2. Encrypt the group shared key:
   - `encrypted_group_shared_key = encrypt_data(group_shared_key, one_time_secret)`

3. For each participant in the group:
   - `shared_key = compute_shared_secret(e_private_key, participant.public_key)`
   - `encrypted_header = encrypt_header(one_time_secret, encrypted_group_shared_key, shared_key)`

The `e_public_key`, `encrypted_group_shared_key`, and `encrypted_header` for each participant are recorded in the blockchain state.

#### Security
- We cannot guarantee that every participant will successfully decrypt the key
- However, all participants who can decrypt will obtain the identical `shared_secret`
- Participants unable to decrypt the key must exit the call immediately, and specifically must not participate in the emoji generation process


## Emoji Generation

The emoji hash generation employs a two-phase commit-reveal protocol to prevent block creators from performing brute-force attacks.

#### Protocol Workflow

1. Initial Setup:
   - Each participant generates a random 32-byte nonce
   - `nonce_hash = SHA256(nonce)`

2. Commit Phase:
   - Each participant broadcasts their `nonce_hash` with a signature
   - The system waits for all participants to submit commits
   - Transition to the Reveal phase occurs only after receiving all commits

3. Reveal Phase:
   - Each participant broadcasts their original `nonce` with signature
   - The system verifies that `SHA256(revealed_nonce) == committed_hash`
   - The process waits for all participants to complete the reveal step

4. Final Hash Generation:
   - All revealed nonces are concatenated in order
   - `emoji_hash = HMAC-SHA512(concatenated_sorted_nonces, blockchain_hash)`


The TL schema for this broadcast mechanism is:
```
e2e.chain.groupBroadcastNonceCommit signature:int512 public_key:int256 chain_height:int32 chain_hash:int256 nonce_hash:int256 = e2e.chain.GroupBroadcast;
e2e.chain.groupBroadcastNonceReveal signature:int512 public_key:int256 chain_height:int32 chain_hash:int256 nonce:int256 = e2e.chain.GroupBroadcast;
```

The signature applies to the TL serialization of the same object with a zeroed signature field.

#### Security
- The resulting `emoji_hash` remains completely unpredictable for all protocol participants
- For simplicity and protection against bugs, participants should only apply messages (including those they created themselves) when received from the server; this approach ensures that when any participant sees a packet, all participants see the packet
- Consequently, emojis won't be displayed before all clients with reasonable internet connections can also view them
- The two-phase commit-reveal protocol prevents any participant from biasing the emoji selection toward a specific pattern
