double ? = Double;
string ? = String;

int32 = Int32;
int53 = Int53;
int64 = Int64;
bytes = Bytes;
secureString = SecureString;
secureBytes = SecureBytes;

object ? = Object;
function ? = Function;

boolFalse = Bool;
boolTrue = Bool;

vector {t:Type} # [ t ] = Vector t;

error code:int32 message:string = Error;
ok = Ok;

keyStoreTypeDirectory directory:string = KeyStoreType;
keyStoreTypeInMemory = KeyStoreType;

config config:string blockchain_name:string use_callbacks_for_network:Bool ignore_cache:Bool = Config;

options config:config keystore_type:KeyStoreType = Options;
options.configInfo default_wallet_id:int64 = options.ConfigInfo;
options.info config_info:options.configInfo = options.Info;

key public_key:string secret:secureBytes = Key;
inputKeyRegular key:key local_password:secureBytes = InputKey;
inputKeyFake = InputKey;
exportedKey word_list:vector<secureString> = ExportedKey;
exportedPemKey pem:secureString = ExportedPemKey;
exportedEncryptedKey data:secureBytes = ExportedEncryptedKey;
exportedUnencryptedKey data:secureBytes = ExportedUnencryptedKey;

bip39Hints words:vector<string> = Bip39Hints;

adnlAddress adnl_address:string = AdnlAddress;

accountAddress account_address:string = AccountAddress;
accountRevisionList revisions:vector<int32> = AccountRevisionList;

unpackedAccountAddress workchain_id:int32 bounceable:Bool testnet:Bool addr:bytes = UnpackedAccountAddress;

internal.transactionId lt:int64 hash:bytes = internal.TransactionId;

ton.blockId workchain:int32 shard:int64 seqno:int32 = internal.BlockId;
ton.blockIdExt workchain:int32 shard:int64 seqno:int32 root_hash:bytes file_hash:bytes = ton.BlockIdExt;

raw.fullAccountState balance:int64 code:bytes data:bytes last_transaction_id:internal.transactionId block_id:ton.blockIdExt frozen_hash:bytes sync_utime:int53 = raw.FullAccountState;
raw.message source:accountAddress destination:accountAddress value:int64 fwd_fee:int64 ihr_fee:int64 created_lt:int64 body_hash:bytes msg_data:msg.Data = raw.Message;
raw.transaction utime:int53 data:bytes transaction_id:internal.transactionId fee:int64 storage_fee:int64 other_fee:int64 in_msg:raw.message out_msgs:vector<raw.message> = raw.Transaction;
raw.transactions transactions:vector<raw.transaction> previous_transaction_id:internal.transactionId = raw.Transactions;

pchan.config alice_public_key:string alice_address:accountAddress bob_public_key:string bob_address:accountAddress init_timeout:int32 close_timeout:int32 channel_id:int64 = pchan.Config;

raw.initialAccountState code:bytes data:bytes = InitialAccountState;
testGiver.initialAccountState = InitialAccountState;
testWallet.initialAccountState public_key:string = InitialAccountState;
wallet.initialAccountState public_key:string = InitialAccountState;
wallet.v3.initialAccountState public_key:string wallet_id:int64 = InitialAccountState;
wallet.highload.v1.initialAccountState public_key:string wallet_id:int64 = InitialAccountState;
wallet.highload.v2.initialAccountState public_key:string wallet_id:int64 = InitialAccountState;

rwallet.limit seconds:int32 value:int64 = rwallet.Limit;
rwallet.config start_at:int53 limits:vector<rwallet.limit> = rwallet.Config;
rwallet.initialAccountState init_public_key:string public_key:string wallet_id:int64 = InitialAccountState;

dns.initialAccountState public_key:string wallet_id:int64 = InitialAccountState;
pchan.initialAccountState config:pchan.config = InitialAccountState;

raw.accountState code:bytes data:bytes frozen_hash:bytes = AccountState;
testWallet.accountState seqno:int32 = AccountState;
wallet.accountState seqno:int32 = AccountState;
wallet.v3.accountState wallet_id:int64 seqno:int32 = AccountState;
wallet.highload.v1.accountState wallet_id:int64 seqno:int32 = AccountState;
wallet.highload.v2.accountState wallet_id:int64 = AccountState;
testGiver.accountState seqno:int32 = AccountState;
dns.accountState wallet_id:int64 = AccountState;
rwallet.accountState wallet_id:int64 seqno:int32 unlocked_balance:int64 config:rwallet.config = AccountState;

pchan.stateInit signed_A:Bool signed_B:Bool min_A:int64 min_B:int64 expire_at:int53 A:int64 B:int64 = pchan.State;
pchan.stateClose signed_A:Bool signed_B:Bool min_A:int64 min_B:int64 expire_at:int53 A:int64 B:int64 = pchan.State;
pchan.statePayout A:int64 B:int64 = pchan.State;

pchan.accountState config:pchan.config state:pchan.State description:string = AccountState;
uninited.accountState frozen_hash:bytes = AccountState;

fullAccountState balance:int64 last_transaction_id:internal.transactionId block_id:ton.blockIdExt sync_utime:int53 account_state:AccountState = FullAccountState;

syncStateDone = SyncState;
syncStateInProgress from_seqno:int32 to_seqno:int32 current_seqno:int32 = SyncState;

//
// MSG
//

msg.dataRaw body:bytes init_state:bytes = msg.Data;
msg.dataText text:bytes = msg.Data;
msg.dataDecryptedText text:bytes = msg.Data;
msg.dataEncryptedText text:bytes = msg.Data;

msg.dataEncrypted source:accountAddress data:msg.Data = msg.DataEncrypted;
msg.dataDecrypted proof:bytes data:msg.Data = msg.DataDecrypted;

msg.dataEncryptedArray elements:vector<msg.dataEncrypted> = msg.DataEncryptedArray;
msg.dataDecryptedArray elements:vector<msg.dataDecrypted> = msg.DataDecryptedArray;

msg.message destination:accountAddress public_key:string amount:int64 data:msg.Data = msg.Message;

//
// DNS
//

dns.entryDataUnknown bytes:bytes = dns.EntryData;
dns.entryDataText text:string = dns.EntryData;
dns.entryDataNextResolver resolver:AccountAddress = dns.EntryData;
dns.entryDataSmcAddress smc_address:AccountAddress = dns.EntryData;
dns.entryDataAdnlAddress adnl_address:AdnlAddress = dns.EntryData;

dns.entry name:string category:int32 entry:dns.EntryData = dns.Entry;

dns.actionDeleteAll = dns.Action;
// use category = 0 to delete all entries
dns.actionDelete name:string category:int32 = dns.Action;
dns.actionSet entry:dns.entry = dns.Action;

dns.resolved entries:vector<dns.entry> = dns.Resolved;


//
// Payment channel
//
pchan.promise signature:bytes promise_A:int64 promise_B:int64 channel_id:int64 = pchan.Promise;

pchan.actionInit inc_A:int64 inc_B:int64 min_A:int64 min_B:int64 = pchan.Action;
pchan.actionClose extra_A:int64 extra_B:int64 promise:pchan.promise = pchan.Action;
pchan.actionTimeout = pchan.Action;

//
// Restricted wallet initialization
//
rwallet.actionInit config:rwallet.config = rwallet.Action;

//
// Actions
//

actionNoop  = Action;
actionMsg messages:vector<msg.message> allow_send_to_uninited:Bool = Action;
actionDns actions:vector<dns.Action> = Action;
actionPchan action:pchan.Action = Action;
actionRwallet action:rwallet.actionInit = Action;
//actionMultisig actions:vector<multisig.order> = Action;

fees in_fwd_fee:int53 storage_fee:int53 gas_fee:int53 fwd_fee:int53 = Fees;
query.fees source_fees:fees destination_fees:vector<fees> = query.Fees;
// query.emulationResult exit_code:int32 fees:fees = query.EmulationResult;
query.info id:int53 valid_until:int53 body_hash:bytes body:bytes init_state:bytes = query.Info;

tvm.slice bytes:bytes = tvm.Slice;
tvm.cell bytes:bytes = tvm.Cell;
tvm.numberDecimal number:string = tvm.Number;
tvm.tuple elements:vector<tvm.StackEntry> = tvm.Tuple;
tvm.list elements:vector<tvm.StackEntry> = tvm.List;

tvm.stackEntrySlice slice:tvm.slice = tvm.StackEntry;
tvm.stackEntryCell cell:tvm.cell = tvm.StackEntry;
tvm.stackEntryNumber number:tvm.Number = tvm.StackEntry;
tvm.stackEntryTuple tuple:tvm.Tuple = tvm.StackEntry;
tvm.stackEntryList list:tvm.List = tvm.StackEntry;
tvm.stackEntryUnsupported = tvm.StackEntry;

smc.info id:int53 = smc.Info;

smc.methodIdNumber number:int32 = smc.MethodId;
smc.methodIdName name:string = smc.MethodId;

smc.runResult gas_used:int53 stack:vector<tvm.StackEntry> exit_code:int32 = smc.RunResult;

updateSendLiteServerQuery id:int64 data:bytes = Update;
updateSyncState sync_state:SyncState = Update;

//@class LogStream @description Describes a stream to which tonlib internal log is written

//@description The log is written to stderr or an OS specific log
logStreamDefault = LogStream;

//@description The log is written to a file @path Path to the file to where the internal tonlib log will be written @max_file_size Maximum size of the file to where the internal tonlib log is written before the file will be auto-rotated
logStreamFile path:string max_file_size:int53 = LogStream;

//@description The log is written nowhere
logStreamEmpty = LogStream;


//@description Contains a tonlib internal log verbosity level @verbosity_level Log verbosity level
logVerbosityLevel verbosity_level:int32 = LogVerbosityLevel;

//@description Contains a list of available tonlib internal log tags @tags List of log tags
logTags tags:vector<string> = LogTags;

data bytes:secureBytes = Data;

liteServer.info now:int53 version:int32 capabilities:int64 = liteServer.Info;

---functions---

init options:options = options.Info;
close = Ok;

options.setConfig config:config = options.ConfigInfo;
options.validateConfig config:config = options.ConfigInfo;

createNewKey local_password:secureBytes mnemonic_password:secureBytes random_extra_seed:secureBytes = Key;
deleteKey key:key = Ok;
deleteAllKeys = Ok;
exportKey input_key:InputKey = ExportedKey;
exportPemKey input_key:InputKey key_password:secureBytes = ExportedPemKey;
exportEncryptedKey input_key:InputKey key_password:secureBytes = ExportedEncryptedKey;
exportUnencryptedKey input_key:InputKey = ExportedUnencryptedKey;
importKey local_password:secureBytes mnemonic_password:secureBytes exported_key:exportedKey = Key;
importPemKey local_password:secureBytes key_password:secureBytes exported_key:exportedPemKey = Key;
importEncryptedKey local_password:secureBytes key_password:secureBytes exported_encrypted_key:exportedEncryptedKey = Key;
importUnencryptedKey local_password:secureBytes  exported_unencrypted_key:exportedUnencryptedKey = Key;
changeLocalPassword input_key:InputKey new_local_password:secureBytes = Key;

encrypt decrypted_data:secureBytes secret:secureBytes = Data;
decrypt encrypted_data:secureBytes secret:secureBytes = Data;
kdf password:secureBytes salt:secureBytes iterations:int32 = Data;

unpackAccountAddress account_address:string = UnpackedAccountAddress;
packAccountAddress account_address:unpackedAccountAddress = AccountAddress;
getBip39Hints prefix:string = Bip39Hints;

//raw.init initial_account_state:raw.initialAccountState = Ok;
raw.getAccountState account_address:accountAddress = raw.FullAccountState;
raw.getTransactions private_key:InputKey account_address:accountAddress from_transaction_id:internal.transactionId = raw.Transactions;
raw.sendMessage body:bytes  = Ok;
raw.createAndSendMessage destination:accountAddress initial_account_state:bytes data:bytes = Ok;
raw.createQuery destination:accountAddress init_code:bytes init_data:bytes body:bytes = query.Info;

sync = ton.BlockIdExt;

// revision = 0 -- use default revision
// revision = x (x > 0) -- use revision x
// revision = -1 -- use experimental (newest) revision. Only for debug purpose
getAccountAddress initial_account_state:InitialAccountState revision:int32 = AccountAddress;
guessAccountRevision initial_account_state:InitialAccountState = AccountRevisionList;
getAccountState account_address:accountAddress = FullAccountState;
createQuery private_key:InputKey address:accountAddress timeout:int32 action:Action initial_account_state:InitialAccountState = query.Info;

msg.decrypt input_key:InputKey data:msg.dataEncryptedArray = msg.DataDecryptedArray;
msg.decryptWithProof proof:bytes data:msg.dataEncrypted = msg.Data;

query.send id:int53 = Ok;
query.forget id:int53 = Ok;
query.estimateFees id:int53 ignore_chksig:Bool = query.Fees;
// query.emulate id:int53 ignore_chksig:Bool = query.EmulationResult;
query.getInfo id:int53 = query.Info;

smc.load account_address:accountAddress = smc.Info;
//smc.forget id:int53 = Ok;
smc.getCode id:int53 = tvm.Cell;
smc.getData id:int53 = tvm.Cell;
smc.getState id:int53 = tvm.Cell;
smc.runGetMethod id:int53 method:smc.MethodId stack:vector<tvm.StackEntry> = smc.RunResult;

dns.resolve account_address:accountAddress name:string category:int32 ttl:int32 = dns.Resolved;

pchan.signPromise input_key:InputKey promise:pchan.promise = pchan.Promise;
pchan.validatePromise public_key:bytes promise:pchan.promise = Ok;

pchan.packPromise promise:pchan.promise = Data;
pchan.unpackPromise data:secureBytes = pchan.Promise;

onLiteServerQueryResult id:int64 bytes:bytes = Ok;
onLiteServerQueryError id:int64 error:error = Ok;

withBlock id:ton.blockIdExt function:Function = Object;

runTests dir:string = Ok;

liteServer.getInfo = liteServer.Info;

//@description Sets new log stream for internal logging of tonlib. This is an offline method. Can be called before authorization. Can be called synchronously @log_stream New log stream
setLogStream log_stream:LogStream = Ok;

//@description Returns information about currently used log stream for internal logging of tonlib. This is an offline method. Can be called before authorization. Can be called synchronously
getLogStream = LogStream;

//@description Sets the verbosity level of the internal logging of tonlib. This is an offline method. Can be called before authorization. Can be called synchronously
//@new_verbosity_level New value of the verbosity level for logging. Value 0 corresponds to fatal errors, value 1 corresponds to errors, value 2 corresponds to warnings and debug warnings, value 3 corresponds to informational, value 4 corresponds to debug, value 5 corresponds to verbose debug, value greater than 5 and up to 1023 can be used to enable even more logging
setLogVerbosityLevel new_verbosity_level:int32 = Ok;

//@description Returns current verbosity level of the internal logging of tonlib. This is an offline method. Can be called before authorization. Can be called synchronously
getLogVerbosityLevel = LogVerbosityLevel;

//@description Returns list of available tonlib internal log tags, for example, ["actor", "binlog", "connections", "notifications", "proxy"]. This is an offline method. Can be called before authorization. Can be called synchronously
getLogTags = LogTags;

//@description Sets the verbosity level for a specified tonlib internal log tag. This is an offline method. Can be called before authorization. Can be called synchronously
//@tag Logging tag to change verbosity level @new_verbosity_level New verbosity level; 1-1024
setLogTagVerbosityLevel tag:string new_verbosity_level:int32 = Ok;

//@description Returns current verbosity level for a specified tonlib internal log tag. This is an offline method. Can be called before authorization. Can be called synchronously @tag Logging tag to change verbosity level
getLogTagVerbosityLevel tag:string = LogVerbosityLevel;

//@description Adds a message to tonlib internal log. This is an offline method. Can be called before authorization. Can be called synchronously
//@verbosity_level Minimum verbosity level needed for the message to be logged, 0-1023 @text Text of a message to log
addLogMessage verbosity_level:int32 text:string = Ok;
