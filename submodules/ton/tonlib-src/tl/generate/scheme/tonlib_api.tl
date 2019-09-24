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

options config:string keystore_directory:string use_callbacks_for_network:Bool = Options;

key public_key:string secret:secureBytes = Key;
inputKey key:key local_password:secureBytes = InputKey;
exportedKey word_list:vector<secureString> = ExportedKey;
exportedPemKey pem:secureString = ExportedPemKey;
exportedEncryptedKey data:secureBytes = ExportedEncryptedKey;

bip39Hints words:vector<string> = Bip39Hints;

accountAddress account_address:string = AccountAddress;

internal.transactionId lt:int64 hash:bytes = internal.TransactionId;

raw.initialAccountState code:bytes data:bytes = raw.InitialAccountState;
raw.accountState balance:int64 code:bytes data:bytes last_transaction_id:internal.transactionId sync_utime:int53 = raw.AccountState;
raw.message source:string destination:string value:int64 message:bytes = raw.Message;
raw.transaction utime:int53 data:bytes transaction_id:internal.transactionId fee:int64 in_msg:raw.message out_msgs:vector<raw.message> = raw.Transaction;
raw.transactions transactions:vector<raw.Transaction> previous_transaction_id:internal.transactionId = raw.Transactions;

testWallet.initialAccountState public_key:string = testWallet.InitialAccountState;
testWallet.accountState balance:int64 seqno:int32 last_transaction_id:internal.transactionId sync_utime:int53 = testWallet.AccountState;

testGiver.accountState balance:int64 seqno:int32 last_transaction_id:internal.transactionId sync_utime:int53= testGiver.AccountState;

uninited.accountState balance:int64 last_transaction_id:internal.transactionId sync_utime:int53 = uninited.AccountState;

generic.initialAccountStateRaw initital_account_state:raw.initialAccountState = generic.InitialAccountState;
generic.initialAccountStateTestWallet initital_account_state:testWallet.initialAccountState = generic.InitialAccountState;

generic.accountStateRaw account_state:raw.accountState = generic.AccountState;
generic.accountStateTestWallet account_state:testWallet.accountState = generic.AccountState;
generic.accountStateTestGiver account_state:testGiver.accountState = generic.AccountState;
generic.accountStateUninited account_state:uninited.accountState = generic.AccountState;

updateSendLiteServerQuery id:int64 data:bytes = Update;

---functions---

init options:options = Ok;
close = Ok;

options.setConfig config:string = Ok;

createNewKey local_password:secureBytes mnemonic_password:secureBytes random_extra_seed:secureBytes = Key;
deleteKey public_key:string = Ok;
exportKey input_key:inputKey = ExportedKey;
exportPemKey input_key:inputKey key_password:secureBytes = ExportedPemKey;
exportEncryptedKey input_key:inputKey key_password:secureBytes = ExportedEncryptedKey;
importKey local_password:secureBytes mnemonic_password:secureBytes exported_key:exportedKey = Key;
importPemKey local_password:secureBytes key_password:secureBytes exported_key:exportedPemKey = Key;
importEncryptedKey local_password:secureBytes key_password:secureBytes exported_encrypted_key:exportedEncryptedKey = Key;
changeLocalPassword input_key:inputKey new_local_password:secureBytes = Key;

getBip39Hints prefix:string = Bip39Hints;

//raw.init initial_account_state:raw.initialAccountState = Ok;
raw.getAccountAddress initital_account_state:raw.initialAccountState = AccountAddress;
raw.getAccountState account_address:accountAddress = raw.AccountState;
raw.sendMessage destination:accountAddress initial_account_state:bytes data:bytes = Ok;
raw.getTransactions account_address:accountAddress from_transaction_id:internal.transactionId = raw.Transactions;

testWallet.init private_key:inputKey = Ok;
testWallet.getAccountAddress initital_account_state:testWallet.initialAccountState = AccountAddress;
testWallet.getAccountState account_address:accountAddress = testWallet.AccountState;
testWallet.sendGrams private_key:inputKey destination:accountAddress seqno:int32 amount:int64 message:bytes = Ok;

testGiver.getAccountState = testGiver.AccountState;
testGiver.getAccountAddress = AccountAddress;
testGiver.sendGrams destination:accountAddress seqno:int32 amount:int64 message:bytes = Ok;

//generic.getAccountAddress initital_account_state:generic.InitialAccountState = AccountAddress;
generic.getAccountState account_address:accountAddress = generic.AccountState;
generic.sendGrams private_key:inputKey source:accountAddress destination:accountAddress amount:int64 message:bytes = Ok;

onLiteServerQueryResult id:int64 bytes:bytes = Ok;
onLiteServerQueryError id:int64 error:error = Ok;

runTests dir:string = Ok;
