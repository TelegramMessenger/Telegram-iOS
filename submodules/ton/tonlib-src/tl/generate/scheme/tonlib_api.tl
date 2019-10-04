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

key public_key:string secret:secureBytes = Key;
inputKey key:key local_password:secureBytes = InputKey;
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

testGiver.accountState balance:int64 seqno:int32 last_transaction_id:internal.transactionId sync_utime:int53= testGiver.AccountState;

uninited.accountState balance:int64 last_transaction_id:internal.transactionId frozen_hash:bytes sync_utime:int53 = uninited.AccountState;

//generic.initialAccountStateRaw initital_account_state:raw.initialAccountState = generic.InitialAccountState;
//generic.initialAccountStateTestWallet initital_account_state:testWallet.initialAccountState = generic.InitialAccountState;
//generic.initialAccountStateWallet initital_account_state:wallet.initialAccountState = generic.InitialAccountState;

generic.accountStateRaw account_state:raw.accountState = generic.AccountState;
generic.accountStateTestWallet account_state:testWallet.accountState = generic.AccountState;
generic.accountStateWallet account_state:wallet.accountState = generic.AccountState;
generic.accountStateTestGiver account_state:testGiver.accountState = generic.AccountState;
generic.accountStateUninited account_state:uninited.accountState = generic.AccountState;

sendGramsResult sent_until:int53 body_hash:bytes = SendGramsResult;

updateSendLiteServerQuery id:int64 data:bytes = Update;

//@class LogStream @description Describes a stream to which TDLib internal log is written

//@description The log is written to stderr or an OS specific log
logStreamDefault = LogStream;

//@description The log is written to a file @path Path to the file to where the internal TDLib log will be written @max_file_size Maximum size of the file to where the internal TDLib log is written before the file will be auto-rotated
logStreamFile path:string max_file_size:int53 = LogStream;

//@description The log is written nowhere
logStreamEmpty = LogStream;


//@description Contains a TDLib internal log verbosity level @verbosity_level Log verbosity level
logVerbosityLevel verbosity_level:int32 = LogVerbosityLevel;

//@description Contains a list of available TDLib internal log tags @tags List of log tags
logTags tags:vector<string> = LogTags;

---functions---

init options:options = Ok;
close = Ok;

options.setConfig config:config = Ok;

createNewKey local_password:secureBytes mnemonic_password:secureBytes random_extra_seed:secureBytes = Key;
deleteKey key:key = Ok;
deleteAllKeys = Ok;
exportKey input_key:inputKey = ExportedKey;
exportPemKey input_key:inputKey key_password:secureBytes = ExportedPemKey;
exportEncryptedKey input_key:inputKey key_password:secureBytes = ExportedEncryptedKey;
importKey local_password:secureBytes mnemonic_password:secureBytes exported_key:exportedKey = Key;
importPemKey local_password:secureBytes key_password:secureBytes exported_key:exportedPemKey = Key;
importEncryptedKey local_password:secureBytes key_password:secureBytes exported_encrypted_key:exportedEncryptedKey = Key;
changeLocalPassword input_key:inputKey new_local_password:secureBytes = Key;

unpackAccountAddress account_address:string = UnpackedAccountAddress;
packAccountAddress account_address:unpackedAccountAddress = AccountAddress;

getBip39Hints prefix:string = Bip39Hints;

//raw.init initial_account_state:raw.initialAccountState = Ok;
raw.getAccountAddress initital_account_state:raw.initialAccountState = AccountAddress;
raw.getAccountState account_address:accountAddress = raw.AccountState;
raw.sendMessage destination:accountAddress initial_account_state:bytes data:bytes = Ok;
raw.getTransactions account_address:accountAddress from_transaction_id:internal.transactionId = raw.Transactions;

testWallet.init private_key:inputKey = Ok;
testWallet.getAccountAddress initital_account_state:testWallet.initialAccountState = AccountAddress;
testWallet.getAccountState account_address:accountAddress = testWallet.AccountState;
testWallet.sendGrams private_key:inputKey destination:accountAddress seqno:int32 amount:int64 message:bytes = SendGramsResult;

wallet.init private_key:inputKey = Ok;
wallet.getAccountAddress initital_account_state:wallet.initialAccountState = AccountAddress;
wallet.getAccountState account_address:accountAddress = wallet.AccountState;
wallet.sendGrams private_key:inputKey destination:accountAddress seqno:int32 valid_until:int53 amount:int64 message:bytes = SendGramsResult;

testGiver.getAccountState = testGiver.AccountState;
testGiver.getAccountAddress = AccountAddress;
testGiver.sendGrams destination:accountAddress seqno:int32 amount:int64 message:bytes = SendGramsResult;

//generic.getAccountAddress initital_account_state:generic.InitialAccountState = AccountAddress;
generic.getAccountState account_address:accountAddress = generic.AccountState;
generic.sendGrams private_key:inputKey source:accountAddress destination:accountAddress amount:int64 timeout:int32 allow_send_to_uninited:Bool message:bytes = SendGramsResult;

onLiteServerQueryResult id:int64 bytes:bytes = Ok;
onLiteServerQueryError id:int64 error:error = Ok;

runTests dir:string = Ok;

//@description Sets new log stream for internal logging of TDLib. This is an offline method. Can be called before authorization. Can be called synchronously @log_stream New log stream
setLogStream log_stream:LogStream = Ok;

//@description Returns information about currently used log stream for internal logging of TDLib. This is an offline method. Can be called before authorization. Can be called synchronously
getLogStream = LogStream;

//@description Sets the verbosity level of the internal logging of TDLib. This is an offline method. Can be called before authorization. Can be called synchronously
//@new_verbosity_level New value of the verbosity level for logging. Value 0 corresponds to fatal errors, value 1 corresponds to errors, value 2 corresponds to warnings and debug warnings, value 3 corresponds to informational, value 4 corresponds to debug, value 5 corresponds to verbose debug, value greater than 5 and up to 1023 can be used to enable even more logging
setLogVerbosityLevel new_verbosity_level:int32 = Ok;

//@description Returns current verbosity level of the internal logging of TDLib. This is an offline method. Can be called before authorization. Can be called synchronously
getLogVerbosityLevel = LogVerbosityLevel;

//@description Returns list of available TDLib internal log tags, for example, ["actor", "binlog", "connections", "notifications", "proxy"]. This is an offline method. Can be called before authorization. Can be called synchronously
getLogTags = LogTags;

//@description Sets the verbosity level for a specified TDLib internal log tag. This is an offline method. Can be called before authorization. Can be called synchronously
//@tag Logging tag to change verbosity level @new_verbosity_level New verbosity level; 1-1024
setLogTagVerbosityLevel tag:string new_verbosity_level:int32 = Ok;

//@description Returns current verbosity level for a specified TDLib internal log tag. This is an offline method. Can be called before authorization. Can be called synchronously @tag Logging tag to change verbosity level
getLogTagVerbosityLevel tag:string = LogVerbosityLevel;

//@description Adds a message to TDLib internal log. This is an offline method. Can be called before authorization. Can be called synchronously
//@verbosity_level Minimum verbosity level needed for the message to be logged, 0-1023 @text Text of a message to log
addLogMessage verbosity_level:int32 text:string = Ok;
