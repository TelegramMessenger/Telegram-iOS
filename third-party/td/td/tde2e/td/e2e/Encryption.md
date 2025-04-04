# Encryption in secret group calls

A group call consists of three parts:

1. Blockchain shared by all group members. It serves as a synchronization point for all changes in the group. It is also used to generate verification codes for MitM protection, as its hash depends on the whole history of call changes, including hash of shared key. Each block consists of changes to call participants and new shared keys encrypted for each participant.

2. Encryption protocol for network packets. It is currently designed to send a relatively small amount of packets as we encrypt at the video frame and audio frame level, not at the network level. We also sign each packet, so it is possible to verify authorship. Similar primitives are also used to encrypt a shared key for each participant.

3. Protocol for emoji generation. Naive generation of emoji straight from blockchain hash would not work, as it could be brute forced by the block's creator. To handle this we introduce a simple two-phase protocol. In the first phase each party commits to a value i.e. publishes its hash. In the second phase each party reveals a value. Hash of all values is used to mix unpredictable randomness into the blockchain's hash.

Let's review each part in detail:

## Blockchain

The blockchain serves as a distributed ledger for group call state management. Each block contains a list of call participants and new shared keys encrypted for each of them.

Hash of last block is used to generate **verification words**

Hash of last block with mixed unpredictable random is used to generate **verification emojis**

For details see [this document](Blockchain.md).

## Encryption

### Primitives used

We use several encryption primitives similar to MTProto 2.0. Here are the key functions:

#### encrypt_data(payload, secret) - encrypts payload with shared secret

1) padding_size = ((16 + payload.size + 15) & -16) - payload.size
2) padding = random_bytes(padding_size) with padding[0] = padding_size
3) padded_data = padding || payload
4) large_secret = KDF(secret, "tde2e_encrypt_data")
5) encrypt_secret = larges_secret[0:32]
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

KDF = HMAC-SHA512, also

Decryption must verify that the message has a valid `msg_id` by computing HMAC over the decrypted data and comparing with the message's msg_id before accepting the payload.

### Packet encryption

This is how we encrypt actual packets:

#### encrypt_packet(payload, active_epochs, user_id, channel_id, seq_num, private_key) - encrypts a packet

First, we generate header_a describing epochs (blockchain heights) used
1) epoch_id[i] = active_epochs[i].epoch (4 bytes)
2) header_a = active_epochs.size (4 bytes) || epoch_id[0]  || epoch_id[1] || ...

Then, we encrypt payload with one_time_key. Signature in payload includes unencrypted header
1) one_time_key = random(32)
2) packet_payload = channel_id (4 bytes) || seq_num (4 bytes) || payload
3) to_sign = HMAC-SHA512(header_a, packet_payload)
4) signature = sign(to_sign, private_key) // 64 bytes
5) signed_payload = packet_payload || signature
6) encrypted_payload = encrypt_data(signed_payload, one_time_key)

Finally, encrypt one_time_key with shared secret from each active epoch
1) encrypted_key[i] = encrypt_header(one_time_key, encrypted_payload, active_epochs[i].shared_key) (32 bytes)
2) header_b = encrypted_key[0] || encrypted_key[1] || ...


result = header_a || header_b || encrypted_payload

- seqno is unique for each pair (public key; channel_id), so it is used as protection from replay attacks
- list of active epochs is also signed

During decryption, we must take public key from blockchain's state. We also must verify user_id and channel_id. Expected user_id and channel_id are known externally

### Encryption of shared key

When changing group state or shared key, the following process is used:

1. Generate new keys:
   - `e_private_key = generate_private_key()`
   - `group_shared_key = random(32 bytes)`
   - `one_time_secret = random(32 bytes)`

2. Encrypt group shared key:
   - `encrypted_group_shared_key = encrypt_data(group_shared_key, one_time_secret)`

3. For each participant:
   - `shared_key = compute_shared_secret(e_private_key, participant.public_key)`
   - `encrypted_header = encrypt_header(one_time_secret, encrypted_group_shared_key, shared_key)`


Key properties:
- Each participant may decrypt their version of header with their private key
- All participants will decrypt the same key (if they decrypt anything)

## Emoji generation

The emoji hash generation uses a two-phase commit-reveal protocol to prevent brute-forcing by block creators.

### Protocol Steps

1. Initial Setup:
   - Each participant generates a random 32-byte nonce
   - `nonce_hash = SHA256(nonce)`

2. Commit Phase:
   - Each participant broadcasts `nonce_hash` with their signature
   - Must wait for all participants to commit
   - State transitions to Reveal only after all commits received

3. Reveal Phase:
   - Each participant broadcasts their original `nonce` with signature
   - Verifies that `SHA256(revealed_nonce) == committed_hash`
   - Must wait for all participants to reveal

4. Final Hash Generation:
   - Concatenate all revealed nonces in order
   - `emoji_hash = SHA512(blockchain_hash || concatenated_sorted_nonces)`

Tl schema used for such broadcast is the following
```
e2e.chain.groupBroadcastNonceCommit signature:int512 public_key:int256 chain_height:int32 chain_hash:int256 nonce_hash:int256 = e2e.chain.GroupBroadcast;
e2e.chain.groupBroadcastNonceReveal signature:int512 public_key:int256 chain_height:int32 chain_hash:int256 nonce:int256 = e2e.chain.GroupBroadcast;
```

The signature is for the TL serialization of the same object with zeroed signature 