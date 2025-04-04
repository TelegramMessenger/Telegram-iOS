int ? = Int;
long ? = Long;
double ? = Double;
string ? = String;

bytes = Bytes;

boolFalse = Bool;
boolTrue = Bool;

true#3fedd339 = True;

vector {t:Type} # [ t ] = Vector t;

int32 = Int32;
int53 = Int53;
int64 = Int64;

int128 4*[ int ] = Int128;
int256 8*[ int ] = Int256;
int512 16*[ int ] = Int512;

secureBytes = SecureBytes;
secureString = SecureString;

ok = Ok;

//
//                  Handshake
//

e2e.handshakeQR bob_ephemeral_PK:int256 bob_nonce:int256 = e2e.HandshakePublic;
e2e.handshakeEncryptedMessage message:bytes = e2e.HandshakePublic; // author of the message is given externally
e2e.handshakeLoginExport accept:bytes encrypted_key:bytes = e2e.HandshakePublic;

e2e.handshakePrivateAccept alice_PK:int256 bob_PK:int256 alice_user_id:int64 bob_user_id:int64 alice_nonce:int256 bob_nonce:int256 = e2e.HandshakePrivate;
e2e.handshakePrivateFinish alice_PK:int256 bob_PK:int256 alice_user_id:int64 bob_user_id:int64 alice_nonce:int256 bob_nonce:int256 = e2e.HandshakePrivate;


//
//                  Personal information
//

e2e.personalUserId user_id:int64 = e2e.Personal;
e2e.personalName first_name:string last_name:string = e2e.Personal;
e2e.personalPhoneNumber phone_number:string = e2e.Personal;
e2e.personalContactState flags:# is_contact:flags.0?true = e2e.Personal;
e2e.personalEmojiNonces flags:# self_nonce:flags.0?int256 contact_nonce_hash:flags.1?int256 contact_nonce:flags.2?int256 = e2e.Personal;

e2e.personalOnServer signature:int512 signed_at:int32 personal:e2e.Personal = e2e.PersonalOnServer;
e2e.personalOnClient signed_at:int32 personal:e2e.Personal = e2e.PersonalOnClient;

// This is stored by server. We don't want to store it in public user's blockchain, because all history of
// changes will be public. Instead, we store signed_at. Also, client may send personalData during QR verification
// server must ensure that each public_key is used exactly once
e2e.personalData public_key:int256 data:vector<e2e.personalOnServer> = e2e.PersonalData;

// Key value storage layout
e2e.keyContactByUserId user_id:int64 = e2e.Key;
e2e.valueContactByUserId public_keys:vector<int256> = e2e.Value;

// TODO: encrypt key instead of hashing and drop public_key. Key type will be determined by value type
e2e.keyContactByPublicKey public_key:int256 = e2e.Key;
// TODO: store string instead of e2e.personalOnClient to support forward compatibility
e2e.valueContactByPublicKey entries:vector<e2e.personalOnClient> = e2e.Value;

e2e.chain.groupBroadcastNonceCommit#d1512ae7 signature:int512 user_id:int64 chain_height:int32 chain_hash:int256 nonce_hash:int256 = e2e.chain.GroupBroadcast;
e2e.chain.groupBroadcastNonceReveal#83f4f9d8 signature:int512 user_id:int64 chain_height:int32 chain_hash:int256 nonce:int256 = e2e.chain.GroupBroadcast;

e2e.chain.groupParticipant user_id:long public_key:int256 flags:# add_users:flags.0?true remove_users:flags.1?true version:int = e2e.chain.GroupParticipant;
e2e.chain.groupState participants:vector<e2e.chain.GroupParticipant> external_permissions:int = e2e.chain.GroupState;
e2e.chain.sharedKey ek:int256 encrypted_shared_key:string dest_user_id:vector<long> dest_header:vector<bytes> = e2e.chain.SharedKey;

e2e.chain.changeNoop nonce:int256 = e2e.chain.Change;
e2e.chain.changeSetValue key:bytes value:bytes = e2e.chain.Change;
e2e.chain.changeSetGroupState group_state:e2e.chain.GroupState = e2e.chain.Change;
e2e.chain.changeSetSharedKey shared_key:e2e.chain.SharedKey = e2e.chain.Change;

e2e.chain.stateProof flags:# kv_hash:int256 group_state:flags.0?e2e.chain.GroupState shared_key:flags.1?e2e.chain.SharedKey = e2e.chain.StateProof;

// signature is for the same block, but with empty signature
e2e.chain.block#639a3db6 signature:int512 flags:# prev_block_hash:int256 changes:vector<e2e.chain.Change> height:int state_proof:e2e.chain.StateProof signature_public_key:flags.0?int256 = e2e.chain.Block;

--- functions ---

e2e.nop = Bool;
