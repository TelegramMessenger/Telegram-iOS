double ? = Double;
string ? = String;

int32 = Int32;
int53 = Int53;
int64 = Int64;
bytes = Bytes;
secureString = SecureString;
secureBytes = SecureBytes;

boolFalse = Bool;
boolTrue = Bool;

vector {t:Type} # [ t ] = Vector t;

error code:int32 message:string = Error;
ok = Ok;

keyStoreTypeDirectory directory:string = KeyStoreType;
keyStoreTypeInMemory = KeyStoreType;

config config:string blockchain_name:string use_callbacks_for_network:Bool ignore_cache:Bool = Config;

options config:config keystore_type:KeyStoreType = Options;
options.configInfo default_wallet_id:int53 = options.ConfigInfo;

key public_key:string secret:secureBytes = Key;
inputKeyRegular key:key local_password:secureBytes = InputKey;
inputKeyFake = InputKey;
exportedKey word_list:vector<secureString> = ExportedKey;
exportedPemKey pem:secureString = ExportedPemKey;
exportedEncryptedKey data:secureBytes = ExportedEncryptedKey;

bip39Hints words:vector<string> = Bip39Hints;

accountAddress account_address:string = AccountAddress;

unpackedAccountAddress workchain_id:int32 bounceable:Bool testnet:Bool addr:bytes = UnpackedAccountAddress;

internal.transactionId lt:int64 hash:bytes = internal.TransactionId;

raw.initialAccountState code:bytes data:bytes = raw.InitialAccountState;
raw.accountState balance:int64 code:bytes data:bytes last_transaction_id:internal.transactionId frozen_hash:bytes sync_utime:int53 = raw.AccountState;
raw.message source:string destination:string value:int64 fwd_fee:int64 ihr_fee:int64 created_lt:int64 body_hash:bytes message:bytes = raw.Message;
raw.transaction utime:int53 data:bytes transaction_id:internal.transactionId fee:int64 storage_fee:int64 other_fee:int64 in_msg:raw.message out_msgs:vector<raw.message> = raw.Transaction;
raw.transactions transactions:vector<raw.transaction> previous_transaction_id:internal.transactionId = raw.Transactions;

testWallet.initialAccountState public_key:string = testWallet.InitialAccountState;
testWallet.accountState balance:int64 seqno:int32 last_transaction_id:internal.transactionId sync_utime:int53 = testWallet.AccountState;

wallet.initialAccountState public_key:string = wallet.InitialAccountState;
wallet.accountState balance:int64 seqno:int32 last_transaction_id:internal.transactionId sync_utime:int53 = wallet.AccountState;

wallet.v3.initialAccountState public_key:string wallet_id:int53 = wallet.v3.InitialAccountState;
wallet.v3.accountState balance:int64 wallet_id:int53 seqno:int32 last_transaction_id:internal.transactionId sync_utime:int53 = wallet.v3.AccountState;

testGiver.accountState balance:int64 seqno:int32 last_transaction_id:internal.transactionId sync_utime:int53= testGiver.AccountState;

uninited.accountState balance:int64 last_transaction_id:internal.transactionId frozen_hash:bytes sync_utime:int53 = uninited.AccountState;

//generic.initialAccountStateRaw initital_account_state:raw.initialAccountState = generic.InitialAccountState;
//generic.initialAccountStateTestWallet initital_account_state:testWallet.initialAccountState = generic.InitialAccountState;
//generic.initialAccountStateWallet initital_account_state:wallet.initialAccountState = generic.InitialAccountState;

generic.accountStateRaw account_state:raw.accountState = generic.AccountState;
generic.accountStateTestWallet account_state:testWallet.accountState = generic.AccountState;
generic.accountStateWallet account_state:wallet.accountState = generic.AccountState;
generic.accountStateWalletV3 account_state:wallet.v3.accountState = generic.AccountState;
generic.accountStateTestGiver account_state:testGiver.accountState = generic.AccountState;
generic.accountStateUninited account_state:uninited.accountState = generic.AccountState;

sendGramsResult sent_until:int53 body_hash:bytes = SendGramsResult;

syncStateDone = SyncState;
syncStateInProgress from_seqno:int32 to_seqno:int32 current_seqno:int32 = SyncState;

fees in_fwd_fee:int53 storage_fee:int53 gas_fee:int53 fwd_fee:int53= Fees;
query.fees source_fees:fees destination_fees:fees = query.Fees;
query.info id:int53 valid_until:int53 body_hash:bytes  = query.Info;

tvm.slice bytes:string = tvm.Slice;
tvm.cell bytes:string = tvm.Cell;
tvm.numberDecimal number:string = tvm.Number;

tvm.stackEntrySlice slice:tvm.slice = tvm.StackEntry;
tvm.stackEntryCell cell:tvm.cell = tvm.StackEntry;
tvm.stackEntryNumber number:tvm.Number = tvm.StackEntry;
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

init options:options = Ok;
close = Ok;

options.setConfig config:config = Ok;
options.validateConfig config:config = options.ConfigInfo;

createNewKey local_password:secureBytes mnemonic_password:secureBytes random_extra_seed:secureBytes = Key;
deleteKey key:key = Ok;
deleteAllKeys = Ok;
exportKey input_key:InputKey = ExportedKey;
exportPemKey input_key:InputKey key_password:secureBytes = ExportedPemKey;
exportEncryptedKey input_key:InputKey key_password:secureBytes = ExportedEncryptedKey;
importKey local_password:secureBytes mnemonic_password:secureBytes exported_key:exportedKey = Key;
importPemKey local_password:secureBytes key_password:secureBytes exported_key:exportedPemKey = Key;
importEncryptedKey local_password:secureBytes key_password:secureBytes exported_encrypted_key:exportedEncryptedKey = Key;
changeLocalPassword input_key:InputKey new_local_password:secureBytes = Key;

encrypt decrypted_data:secureBytes secret:secureBytes = Data;
decrypt encrypted_data:secureBytes secret:secureBytes = Data;
kdf password:secureBytes salt:secureBytes iterations:int32 = Data;

unpackAccountAddress account_address:string = UnpackedAccountAddress;
packAccountAddress account_address:unpackedAccountAddress = AccountAddress;
getBip39Hints prefix:string = Bip39Hints;

//raw.init initial_account_state:raw.initialAccountState = Ok;
raw.getAccountAddress initital_account_state:raw.initialAccountState = AccountAddress;
raw.getAccountState account_address:accountAddress = raw.AccountState;
raw.getTransactions account_address:accountAddress from_transaction_id:internal.transactionId = raw.Transactions;
raw.sendMessage body:bytes  = Ok;
raw.createAndSendMessage destination:accountAddress initial_account_state:bytes data:bytes = Ok;
raw.createQuery destination:accountAddress init_code:bytes init_data:bytes body:bytes = query.Info;

testWallet.init private_key:InputKey = Ok;
testWallet.getAccountAddress initital_account_state:testWallet.initialAccountState = AccountAddress;
testWallet.getAccountState account_address:accountAddress = testWallet.AccountState;
testWallet.sendGrams private_key:InputKey destination:accountAddress seqno:int32 amount:int64 message:bytes = SendGramsResult;

wallet.init private_key:InputKey = Ok;
wallet.getAccountAddress initital_account_state:wallet.initialAccountState = AccountAddress;
wallet.getAccountState account_address:accountAddress = wallet.AccountState;
wallet.sendGrams private_key:InputKey destination:accountAddress seqno:int32 valid_until:int53 amount:int64 message:bytes = SendGramsResult;

wallet.v3.getAccountAddress initital_account_state:wallet.v3.initialAccountState = AccountAddress;

testGiver.getAccountState = testGiver.AccountState;
testGiver.getAccountAddress = AccountAddress;
testGiver.sendGrams destination:accountAddress seqno:int32 amount:int64 message:bytes = SendGramsResult;

sync = Ok;

//generic.getAccountAddress initital_account_state:generic.InitialAccountState = AccountAddress;
generic.getAccountState account_address:accountAddress = generic.AccountState;
generic.sendGrams private_key:InputKey source:accountAddress destination:accountAddress amount:int64 timeout:int32 allow_send_to_uninited:Bool message:bytes = SendGramsResult;

generic.createSendGramsQuery private_key:InputKey source:accountAddress destination:accountAddress amount:int64 timeout:int32 allow_send_to_uninited:Bool message:bytes = query.Info;

query.send id:int53 = Ok;
query.forget id:int53 = Ok;
query.estimateFees id:int53 ignore_chksig:Bool = query.Fees;
query.getInfo id:int53 = query.Info;

smc.load account_address:accountAddress = smc.Info;
smc.getCode id:int53 = tvm.Cell;
smc.getData id:int53 = tvm.Cell;
smc.getState id:int53 = tvm.Cell;
smc.runGetMethod id:int53 method:smc.MethodId stack:vector<tvm.StackEntry> = smc.RunResult;

onLiteServerQueryResult id:int64 bytes:bytes = Ok;
onLiteServerQueryError id:int64 error:error = Ok;

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
