#include "tonlib_api.h"

#include "tl/tl_object_parse.h"
#include "tl/tl_object_store.h"
#include "td/utils/int_types.h"

#include "td/utils/common.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/tl_parsers.h"
#include "td/utils/tl_storers.h"

namespace ton {
namespace tonlib_api {

std::string to_string(const BaseObject &value) {
  td::TlStorerToString storer;
  value.store(storer, "");
  return storer.str();
}

accountAddress::accountAddress()
  : account_address_()
{}

accountAddress::accountAddress(std::string const &account_address_)
  : account_address_(std::move(account_address_))
{}

const std::int32_t accountAddress::ID;

void accountAddress::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "accountAddress");
    s.store_field("account_address", account_address_);
    s.store_class_end();
  }
}

bip39Hints::bip39Hints()
  : words_()
{}

bip39Hints::bip39Hints(std::vector<std::string> &&words_)
  : words_(std::move(words_))
{}

const std::int32_t bip39Hints::ID;

void bip39Hints::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "bip39Hints");
    { const std::vector<std::string> &v = words_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("words", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { s.store_field("", v[i]); } s.store_class_end(); }
    s.store_class_end();
  }
}

error::error()
  : code_()
  , message_()
{}

error::error(std::int32_t code_, std::string const &message_)
  : code_(code_)
  , message_(std::move(message_))
{}

const std::int32_t error::ID;

void error::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "error");
    s.store_field("code", code_);
    s.store_field("message", message_);
    s.store_class_end();
  }
}

exportedEncryptedKey::exportedEncryptedKey()
  : data_()
{}

exportedEncryptedKey::exportedEncryptedKey(td::SecureString &&data_)
  : data_(std::move(data_))
{}

const std::int32_t exportedEncryptedKey::ID;

void exportedEncryptedKey::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "exportedEncryptedKey");
    s.store_bytes_field("data", data_);
    s.store_class_end();
  }
}

exportedKey::exportedKey()
  : word_list_()
{}

exportedKey::exportedKey(std::vector<td::SecureString> &&word_list_)
  : word_list_(std::move(word_list_))
{}

const std::int32_t exportedKey::ID;

void exportedKey::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "exportedKey");
    { const std::vector<td::SecureString> &v = word_list_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("word_list", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { s.store_field("", v[i]); } s.store_class_end(); }
    s.store_class_end();
  }
}

exportedPemKey::exportedPemKey()
  : pem_()
{}

exportedPemKey::exportedPemKey(td::SecureString &&pem_)
  : pem_(std::move(pem_))
{}

const std::int32_t exportedPemKey::ID;

void exportedPemKey::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "exportedPemKey");
    s.store_field("pem", pem_);
    s.store_class_end();
  }
}

inputKey::inputKey()
  : key_()
  , local_password_()
{}

inputKey::inputKey(object_ptr<key> &&key_, td::SecureString &&local_password_)
  : key_(std::move(key_))
  , local_password_(std::move(local_password_))
{}

const std::int32_t inputKey::ID;

void inputKey::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "inputKey");
    if (key_ == nullptr) { s.store_field("key", "null"); } else { key_->store(s, "key"); }
    s.store_bytes_field("local_password", local_password_);
    s.store_class_end();
  }
}

key::key()
  : public_key_()
  , secret_()
{}

key::key(std::string const &public_key_, td::SecureString &&secret_)
  : public_key_(std::move(public_key_))
  , secret_(std::move(secret_))
{}

const std::int32_t key::ID;

void key::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "key");
    s.store_field("public_key", public_key_);
    s.store_bytes_field("secret", secret_);
    s.store_class_end();
  }
}

ok::ok() {
}

const std::int32_t ok::ID;

void ok::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "ok");
    s.store_class_end();
  }
}

options::options()
  : config_()
  , keystore_directory_()
  , use_callbacks_for_network_()
{}

options::options(std::string const &config_, std::string const &keystore_directory_, bool use_callbacks_for_network_)
  : config_(std::move(config_))
  , keystore_directory_(std::move(keystore_directory_))
  , use_callbacks_for_network_(use_callbacks_for_network_)
{}

const std::int32_t options::ID;

void options::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "options");
    s.store_field("config", config_);
    s.store_field("keystore_directory", keystore_directory_);
    s.store_field("use_callbacks_for_network", use_callbacks_for_network_);
    s.store_class_end();
  }
}

updateSendLiteServerQuery::updateSendLiteServerQuery()
  : id_()
  , data_()
{}

updateSendLiteServerQuery::updateSendLiteServerQuery(std::int64_t id_, std::string const &data_)
  : id_(id_)
  , data_(std::move(data_))
{}

const std::int32_t updateSendLiteServerQuery::ID;

void updateSendLiteServerQuery::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "updateSendLiteServerQuery");
    s.store_field("id", id_);
    s.store_bytes_field("data", data_);
    s.store_class_end();
  }
}

generic_accountStateRaw::generic_accountStateRaw()
  : account_state_()
{}

generic_accountStateRaw::generic_accountStateRaw(object_ptr<raw_accountState> &&account_state_)
  : account_state_(std::move(account_state_))
{}

const std::int32_t generic_accountStateRaw::ID;

void generic_accountStateRaw::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "generic_accountStateRaw");
    if (account_state_ == nullptr) { s.store_field("account_state", "null"); } else { account_state_->store(s, "account_state"); }
    s.store_class_end();
  }
}

generic_accountStateTestWallet::generic_accountStateTestWallet()
  : account_state_()
{}

generic_accountStateTestWallet::generic_accountStateTestWallet(object_ptr<testWallet_accountState> &&account_state_)
  : account_state_(std::move(account_state_))
{}

const std::int32_t generic_accountStateTestWallet::ID;

void generic_accountStateTestWallet::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "generic_accountStateTestWallet");
    if (account_state_ == nullptr) { s.store_field("account_state", "null"); } else { account_state_->store(s, "account_state"); }
    s.store_class_end();
  }
}

generic_accountStateTestGiver::generic_accountStateTestGiver()
  : account_state_()
{}

generic_accountStateTestGiver::generic_accountStateTestGiver(object_ptr<testGiver_accountState> &&account_state_)
  : account_state_(std::move(account_state_))
{}

const std::int32_t generic_accountStateTestGiver::ID;

void generic_accountStateTestGiver::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "generic_accountStateTestGiver");
    if (account_state_ == nullptr) { s.store_field("account_state", "null"); } else { account_state_->store(s, "account_state"); }
    s.store_class_end();
  }
}

generic_accountStateUninited::generic_accountStateUninited()
  : account_state_()
{}

generic_accountStateUninited::generic_accountStateUninited(object_ptr<uninited_accountState> &&account_state_)
  : account_state_(std::move(account_state_))
{}

const std::int32_t generic_accountStateUninited::ID;

void generic_accountStateUninited::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "generic_accountStateUninited");
    if (account_state_ == nullptr) { s.store_field("account_state", "null"); } else { account_state_->store(s, "account_state"); }
    s.store_class_end();
  }
}

generic_initialAccountStateRaw::generic_initialAccountStateRaw()
  : initital_account_state_()
{}

generic_initialAccountStateRaw::generic_initialAccountStateRaw(object_ptr<raw_initialAccountState> &&initital_account_state_)
  : initital_account_state_(std::move(initital_account_state_))
{}

const std::int32_t generic_initialAccountStateRaw::ID;

void generic_initialAccountStateRaw::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "generic_initialAccountStateRaw");
    if (initital_account_state_ == nullptr) { s.store_field("initital_account_state", "null"); } else { initital_account_state_->store(s, "initital_account_state"); }
    s.store_class_end();
  }
}

generic_initialAccountStateTestWallet::generic_initialAccountStateTestWallet()
  : initital_account_state_()
{}

generic_initialAccountStateTestWallet::generic_initialAccountStateTestWallet(object_ptr<testWallet_initialAccountState> &&initital_account_state_)
  : initital_account_state_(std::move(initital_account_state_))
{}

const std::int32_t generic_initialAccountStateTestWallet::ID;

void generic_initialAccountStateTestWallet::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "generic_initialAccountStateTestWallet");
    if (initital_account_state_ == nullptr) { s.store_field("initital_account_state", "null"); } else { initital_account_state_->store(s, "initital_account_state"); }
    s.store_class_end();
  }
}

internal_transactionId::internal_transactionId()
  : lt_()
  , hash_()
{}

internal_transactionId::internal_transactionId(std::int64_t lt_, std::string const &hash_)
  : lt_(lt_)
  , hash_(std::move(hash_))
{}

const std::int32_t internal_transactionId::ID;

void internal_transactionId::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "internal_transactionId");
    s.store_field("lt", lt_);
    s.store_bytes_field("hash", hash_);
    s.store_class_end();
  }
}

raw_accountState::raw_accountState()
  : balance_()
  , code_()
  , data_()
  , last_transaction_id_()
  , sync_utime_()
{}

raw_accountState::raw_accountState(std::int64_t balance_, std::string const &code_, std::string const &data_, object_ptr<internal_transactionId> &&last_transaction_id_, std::int64_t sync_utime_)
  : balance_(balance_)
  , code_(std::move(code_))
  , data_(std::move(data_))
  , last_transaction_id_(std::move(last_transaction_id_))
  , sync_utime_(sync_utime_)
{}

const std::int32_t raw_accountState::ID;

void raw_accountState::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "raw_accountState");
    s.store_field("balance", balance_);
    s.store_bytes_field("code", code_);
    s.store_bytes_field("data", data_);
    if (last_transaction_id_ == nullptr) { s.store_field("last_transaction_id", "null"); } else { last_transaction_id_->store(s, "last_transaction_id"); }
    s.store_field("sync_utime", sync_utime_);
    s.store_class_end();
  }
}

raw_initialAccountState::raw_initialAccountState()
  : code_()
  , data_()
{}

raw_initialAccountState::raw_initialAccountState(std::string const &code_, std::string const &data_)
  : code_(std::move(code_))
  , data_(std::move(data_))
{}

const std::int32_t raw_initialAccountState::ID;

void raw_initialAccountState::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "raw_initialAccountState");
    s.store_bytes_field("code", code_);
    s.store_bytes_field("data", data_);
    s.store_class_end();
  }
}

raw_message::raw_message()
  : source_()
  , destination_()
  , value_()
  , message_()
{}

raw_message::raw_message(std::string const &source_, std::string const &destination_, std::int64_t value_, std::string const &message_)
  : source_(std::move(source_))
  , destination_(std::move(destination_))
  , value_(value_)
  , message_(std::move(message_))
{}

const std::int32_t raw_message::ID;

void raw_message::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "raw_message");
    s.store_field("source", source_);
    s.store_field("destination", destination_);
    s.store_field("value", value_);
    s.store_bytes_field("message", message_);
    s.store_class_end();
  }
}

raw_transaction::raw_transaction()
  : utime_()
  , data_()
  , transaction_id_()
  , fee_()
  , in_msg_()
  , out_msgs_()
{}

raw_transaction::raw_transaction(std::int64_t utime_, std::string const &data_, object_ptr<internal_transactionId> &&transaction_id_, std::int64_t fee_, object_ptr<raw_message> &&in_msg_, std::vector<object_ptr<raw_message>> &&out_msgs_)
  : utime_(utime_)
  , data_(std::move(data_))
  , transaction_id_(std::move(transaction_id_))
  , fee_(fee_)
  , in_msg_(std::move(in_msg_))
  , out_msgs_(std::move(out_msgs_))
{}

const std::int32_t raw_transaction::ID;

void raw_transaction::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "raw_transaction");
    s.store_field("utime", utime_);
    s.store_bytes_field("data", data_);
    if (transaction_id_ == nullptr) { s.store_field("transaction_id", "null"); } else { transaction_id_->store(s, "transaction_id"); }
    s.store_field("fee", fee_);
    if (in_msg_ == nullptr) { s.store_field("in_msg", "null"); } else { in_msg_->store(s, "in_msg"); }
    { const std::vector<object_ptr<raw_message>> &v = out_msgs_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("out_msgs", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    s.store_class_end();
  }
}

raw_transactions::raw_transactions()
  : transactions_()
  , previous_transaction_id_()
{}

raw_transactions::raw_transactions(std::vector<object_ptr<raw_transaction>> &&transactions_, object_ptr<internal_transactionId> &&previous_transaction_id_)
  : transactions_(std::move(transactions_))
  , previous_transaction_id_(std::move(previous_transaction_id_))
{}

const std::int32_t raw_transactions::ID;

void raw_transactions::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "raw_transactions");
    { const std::vector<object_ptr<raw_transaction>> &v = transactions_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("transactions", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    if (previous_transaction_id_ == nullptr) { s.store_field("previous_transaction_id", "null"); } else { previous_transaction_id_->store(s, "previous_transaction_id"); }
    s.store_class_end();
  }
}

testGiver_accountState::testGiver_accountState()
  : balance_()
  , seqno_()
  , last_transaction_id_()
  , sync_utime_()
{}

testGiver_accountState::testGiver_accountState(std::int64_t balance_, std::int32_t seqno_, object_ptr<internal_transactionId> &&last_transaction_id_, std::int64_t sync_utime_)
  : balance_(balance_)
  , seqno_(seqno_)
  , last_transaction_id_(std::move(last_transaction_id_))
  , sync_utime_(sync_utime_)
{}

const std::int32_t testGiver_accountState::ID;

void testGiver_accountState::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "testGiver_accountState");
    s.store_field("balance", balance_);
    s.store_field("seqno", seqno_);
    if (last_transaction_id_ == nullptr) { s.store_field("last_transaction_id", "null"); } else { last_transaction_id_->store(s, "last_transaction_id"); }
    s.store_field("sync_utime", sync_utime_);
    s.store_class_end();
  }
}

testWallet_accountState::testWallet_accountState()
  : balance_()
  , seqno_()
  , last_transaction_id_()
  , sync_utime_()
{}

testWallet_accountState::testWallet_accountState(std::int64_t balance_, std::int32_t seqno_, object_ptr<internal_transactionId> &&last_transaction_id_, std::int64_t sync_utime_)
  : balance_(balance_)
  , seqno_(seqno_)
  , last_transaction_id_(std::move(last_transaction_id_))
  , sync_utime_(sync_utime_)
{}

const std::int32_t testWallet_accountState::ID;

void testWallet_accountState::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "testWallet_accountState");
    s.store_field("balance", balance_);
    s.store_field("seqno", seqno_);
    if (last_transaction_id_ == nullptr) { s.store_field("last_transaction_id", "null"); } else { last_transaction_id_->store(s, "last_transaction_id"); }
    s.store_field("sync_utime", sync_utime_);
    s.store_class_end();
  }
}

testWallet_initialAccountState::testWallet_initialAccountState()
  : public_key_()
{}

testWallet_initialAccountState::testWallet_initialAccountState(std::string const &public_key_)
  : public_key_(std::move(public_key_))
{}

const std::int32_t testWallet_initialAccountState::ID;

void testWallet_initialAccountState::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "testWallet_initialAccountState");
    s.store_field("public_key", public_key_);
    s.store_class_end();
  }
}

uninited_accountState::uninited_accountState()
  : balance_()
  , last_transaction_id_()
  , sync_utime_()
{}

uninited_accountState::uninited_accountState(std::int64_t balance_, object_ptr<internal_transactionId> &&last_transaction_id_, std::int64_t sync_utime_)
  : balance_(balance_)
  , last_transaction_id_(std::move(last_transaction_id_))
  , sync_utime_(sync_utime_)
{}

const std::int32_t uninited_accountState::ID;

void uninited_accountState::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "uninited_accountState");
    s.store_field("balance", balance_);
    if (last_transaction_id_ == nullptr) { s.store_field("last_transaction_id", "null"); } else { last_transaction_id_->store(s, "last_transaction_id"); }
    s.store_field("sync_utime", sync_utime_);
    s.store_class_end();
  }
}

changeLocalPassword::changeLocalPassword()
  : input_key_()
  , new_local_password_()
{}

changeLocalPassword::changeLocalPassword(object_ptr<inputKey> &&input_key_, td::SecureString &&new_local_password_)
  : input_key_(std::move(input_key_))
  , new_local_password_(std::move(new_local_password_))
{}

const std::int32_t changeLocalPassword::ID;

void changeLocalPassword::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "changeLocalPassword");
    if (input_key_ == nullptr) { s.store_field("input_key", "null"); } else { input_key_->store(s, "input_key"); }
    s.store_bytes_field("new_local_password", new_local_password_);
    s.store_class_end();
  }
}

close::close() {
}

const std::int32_t close::ID;

void close::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "close");
    s.store_class_end();
  }
}

createNewKey::createNewKey()
  : local_password_()
  , mnemonic_password_()
  , random_extra_seed_()
{}

createNewKey::createNewKey(td::SecureString &&local_password_, td::SecureString &&mnemonic_password_, td::SecureString &&random_extra_seed_)
  : local_password_(std::move(local_password_))
  , mnemonic_password_(std::move(mnemonic_password_))
  , random_extra_seed_(std::move(random_extra_seed_))
{}

const std::int32_t createNewKey::ID;

void createNewKey::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "createNewKey");
    s.store_bytes_field("local_password", local_password_);
    s.store_bytes_field("mnemonic_password", mnemonic_password_);
    s.store_bytes_field("random_extra_seed", random_extra_seed_);
    s.store_class_end();
  }
}

deleteKey::deleteKey()
  : public_key_()
{}

deleteKey::deleteKey(std::string const &public_key_)
  : public_key_(std::move(public_key_))
{}

const std::int32_t deleteKey::ID;

void deleteKey::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "deleteKey");
    s.store_field("public_key", public_key_);
    s.store_class_end();
  }
}

exportEncryptedKey::exportEncryptedKey()
  : input_key_()
  , key_password_()
{}

exportEncryptedKey::exportEncryptedKey(object_ptr<inputKey> &&input_key_, td::SecureString &&key_password_)
  : input_key_(std::move(input_key_))
  , key_password_(std::move(key_password_))
{}

const std::int32_t exportEncryptedKey::ID;

void exportEncryptedKey::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "exportEncryptedKey");
    if (input_key_ == nullptr) { s.store_field("input_key", "null"); } else { input_key_->store(s, "input_key"); }
    s.store_bytes_field("key_password", key_password_);
    s.store_class_end();
  }
}

exportKey::exportKey()
  : input_key_()
{}

exportKey::exportKey(object_ptr<inputKey> &&input_key_)
  : input_key_(std::move(input_key_))
{}

const std::int32_t exportKey::ID;

void exportKey::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "exportKey");
    if (input_key_ == nullptr) { s.store_field("input_key", "null"); } else { input_key_->store(s, "input_key"); }
    s.store_class_end();
  }
}

exportPemKey::exportPemKey()
  : input_key_()
  , key_password_()
{}

exportPemKey::exportPemKey(object_ptr<inputKey> &&input_key_, td::SecureString &&key_password_)
  : input_key_(std::move(input_key_))
  , key_password_(std::move(key_password_))
{}

const std::int32_t exportPemKey::ID;

void exportPemKey::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "exportPemKey");
    if (input_key_ == nullptr) { s.store_field("input_key", "null"); } else { input_key_->store(s, "input_key"); }
    s.store_bytes_field("key_password", key_password_);
    s.store_class_end();
  }
}

generic_getAccountState::generic_getAccountState()
  : account_address_()
{}

generic_getAccountState::generic_getAccountState(object_ptr<accountAddress> &&account_address_)
  : account_address_(std::move(account_address_))
{}

const std::int32_t generic_getAccountState::ID;

void generic_getAccountState::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "generic_getAccountState");
    if (account_address_ == nullptr) { s.store_field("account_address", "null"); } else { account_address_->store(s, "account_address"); }
    s.store_class_end();
  }
}

generic_sendGrams::generic_sendGrams()
  : private_key_()
  , source_()
  , destination_()
  , amount_()
  , message_()
{}

generic_sendGrams::generic_sendGrams(object_ptr<inputKey> &&private_key_, object_ptr<accountAddress> &&source_, object_ptr<accountAddress> &&destination_, std::int64_t amount_, std::string const &message_)
  : private_key_(std::move(private_key_))
  , source_(std::move(source_))
  , destination_(std::move(destination_))
  , amount_(amount_)
  , message_(std::move(message_))
{}

const std::int32_t generic_sendGrams::ID;

void generic_sendGrams::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "generic_sendGrams");
    if (private_key_ == nullptr) { s.store_field("private_key", "null"); } else { private_key_->store(s, "private_key"); }
    if (source_ == nullptr) { s.store_field("source", "null"); } else { source_->store(s, "source"); }
    if (destination_ == nullptr) { s.store_field("destination", "null"); } else { destination_->store(s, "destination"); }
    s.store_field("amount", amount_);
    s.store_bytes_field("message", message_);
    s.store_class_end();
  }
}

getBip39Hints::getBip39Hints()
  : prefix_()
{}

getBip39Hints::getBip39Hints(std::string const &prefix_)
  : prefix_(std::move(prefix_))
{}

const std::int32_t getBip39Hints::ID;

void getBip39Hints::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "getBip39Hints");
    s.store_field("prefix", prefix_);
    s.store_class_end();
  }
}

importEncryptedKey::importEncryptedKey()
  : local_password_()
  , key_password_()
  , exported_encrypted_key_()
{}

importEncryptedKey::importEncryptedKey(td::SecureString &&local_password_, td::SecureString &&key_password_, object_ptr<exportedEncryptedKey> &&exported_encrypted_key_)
  : local_password_(std::move(local_password_))
  , key_password_(std::move(key_password_))
  , exported_encrypted_key_(std::move(exported_encrypted_key_))
{}

const std::int32_t importEncryptedKey::ID;

void importEncryptedKey::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "importEncryptedKey");
    s.store_bytes_field("local_password", local_password_);
    s.store_bytes_field("key_password", key_password_);
    if (exported_encrypted_key_ == nullptr) { s.store_field("exported_encrypted_key", "null"); } else { exported_encrypted_key_->store(s, "exported_encrypted_key"); }
    s.store_class_end();
  }
}

importKey::importKey()
  : local_password_()
  , mnemonic_password_()
  , exported_key_()
{}

importKey::importKey(td::SecureString &&local_password_, td::SecureString &&mnemonic_password_, object_ptr<exportedKey> &&exported_key_)
  : local_password_(std::move(local_password_))
  , mnemonic_password_(std::move(mnemonic_password_))
  , exported_key_(std::move(exported_key_))
{}

const std::int32_t importKey::ID;

void importKey::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "importKey");
    s.store_bytes_field("local_password", local_password_);
    s.store_bytes_field("mnemonic_password", mnemonic_password_);
    if (exported_key_ == nullptr) { s.store_field("exported_key", "null"); } else { exported_key_->store(s, "exported_key"); }
    s.store_class_end();
  }
}

importPemKey::importPemKey()
  : local_password_()
  , key_password_()
  , exported_key_()
{}

importPemKey::importPemKey(td::SecureString &&local_password_, td::SecureString &&key_password_, object_ptr<exportedPemKey> &&exported_key_)
  : local_password_(std::move(local_password_))
  , key_password_(std::move(key_password_))
  , exported_key_(std::move(exported_key_))
{}

const std::int32_t importPemKey::ID;

void importPemKey::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "importPemKey");
    s.store_bytes_field("local_password", local_password_);
    s.store_bytes_field("key_password", key_password_);
    if (exported_key_ == nullptr) { s.store_field("exported_key", "null"); } else { exported_key_->store(s, "exported_key"); }
    s.store_class_end();
  }
}

init::init()
  : options_()
{}

init::init(object_ptr<options> &&options_)
  : options_(std::move(options_))
{}

const std::int32_t init::ID;

void init::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "init");
    if (options_ == nullptr) { s.store_field("options", "null"); } else { options_->store(s, "options"); }
    s.store_class_end();
  }
}

onLiteServerQueryError::onLiteServerQueryError()
  : id_()
  , error_()
{}

onLiteServerQueryError::onLiteServerQueryError(std::int64_t id_, object_ptr<error> &&error_)
  : id_(id_)
  , error_(std::move(error_))
{}

const std::int32_t onLiteServerQueryError::ID;

void onLiteServerQueryError::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "onLiteServerQueryError");
    s.store_field("id", id_);
    if (error_ == nullptr) { s.store_field("error", "null"); } else { error_->store(s, "error"); }
    s.store_class_end();
  }
}

onLiteServerQueryResult::onLiteServerQueryResult()
  : id_()
  , bytes_()
{}

onLiteServerQueryResult::onLiteServerQueryResult(std::int64_t id_, std::string const &bytes_)
  : id_(id_)
  , bytes_(std::move(bytes_))
{}

const std::int32_t onLiteServerQueryResult::ID;

void onLiteServerQueryResult::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "onLiteServerQueryResult");
    s.store_field("id", id_);
    s.store_bytes_field("bytes", bytes_);
    s.store_class_end();
  }
}

options_setConfig::options_setConfig()
  : config_()
{}

options_setConfig::options_setConfig(std::string const &config_)
  : config_(std::move(config_))
{}

const std::int32_t options_setConfig::ID;

void options_setConfig::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "options_setConfig");
    s.store_field("config", config_);
    s.store_class_end();
  }
}

raw_getAccountAddress::raw_getAccountAddress()
  : initital_account_state_()
{}

raw_getAccountAddress::raw_getAccountAddress(object_ptr<raw_initialAccountState> &&initital_account_state_)
  : initital_account_state_(std::move(initital_account_state_))
{}

const std::int32_t raw_getAccountAddress::ID;

void raw_getAccountAddress::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "raw_getAccountAddress");
    if (initital_account_state_ == nullptr) { s.store_field("initital_account_state", "null"); } else { initital_account_state_->store(s, "initital_account_state"); }
    s.store_class_end();
  }
}

raw_getAccountState::raw_getAccountState()
  : account_address_()
{}

raw_getAccountState::raw_getAccountState(object_ptr<accountAddress> &&account_address_)
  : account_address_(std::move(account_address_))
{}

const std::int32_t raw_getAccountState::ID;

void raw_getAccountState::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "raw_getAccountState");
    if (account_address_ == nullptr) { s.store_field("account_address", "null"); } else { account_address_->store(s, "account_address"); }
    s.store_class_end();
  }
}

raw_getTransactions::raw_getTransactions()
  : account_address_()
  , from_transaction_id_()
{}

raw_getTransactions::raw_getTransactions(object_ptr<accountAddress> &&account_address_, object_ptr<internal_transactionId> &&from_transaction_id_)
  : account_address_(std::move(account_address_))
  , from_transaction_id_(std::move(from_transaction_id_))
{}

const std::int32_t raw_getTransactions::ID;

void raw_getTransactions::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "raw_getTransactions");
    if (account_address_ == nullptr) { s.store_field("account_address", "null"); } else { account_address_->store(s, "account_address"); }
    if (from_transaction_id_ == nullptr) { s.store_field("from_transaction_id", "null"); } else { from_transaction_id_->store(s, "from_transaction_id"); }
    s.store_class_end();
  }
}

raw_sendMessage::raw_sendMessage()
  : destination_()
  , initial_account_state_()
  , data_()
{}

raw_sendMessage::raw_sendMessage(object_ptr<accountAddress> &&destination_, std::string const &initial_account_state_, std::string const &data_)
  : destination_(std::move(destination_))
  , initial_account_state_(std::move(initial_account_state_))
  , data_(std::move(data_))
{}

const std::int32_t raw_sendMessage::ID;

void raw_sendMessage::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "raw_sendMessage");
    if (destination_ == nullptr) { s.store_field("destination", "null"); } else { destination_->store(s, "destination"); }
    s.store_bytes_field("initial_account_state", initial_account_state_);
    s.store_bytes_field("data", data_);
    s.store_class_end();
  }
}

runTests::runTests()
  : dir_()
{}

runTests::runTests(std::string const &dir_)
  : dir_(std::move(dir_))
{}

const std::int32_t runTests::ID;

void runTests::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "runTests");
    s.store_field("dir", dir_);
    s.store_class_end();
  }
}

testGiver_getAccountAddress::testGiver_getAccountAddress() {
}

const std::int32_t testGiver_getAccountAddress::ID;

void testGiver_getAccountAddress::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "testGiver_getAccountAddress");
    s.store_class_end();
  }
}

testGiver_getAccountState::testGiver_getAccountState() {
}

const std::int32_t testGiver_getAccountState::ID;

void testGiver_getAccountState::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "testGiver_getAccountState");
    s.store_class_end();
  }
}

testGiver_sendGrams::testGiver_sendGrams()
  : destination_()
  , seqno_()
  , amount_()
  , message_()
{}

testGiver_sendGrams::testGiver_sendGrams(object_ptr<accountAddress> &&destination_, std::int32_t seqno_, std::int64_t amount_, std::string const &message_)
  : destination_(std::move(destination_))
  , seqno_(seqno_)
  , amount_(amount_)
  , message_(std::move(message_))
{}

const std::int32_t testGiver_sendGrams::ID;

void testGiver_sendGrams::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "testGiver_sendGrams");
    if (destination_ == nullptr) { s.store_field("destination", "null"); } else { destination_->store(s, "destination"); }
    s.store_field("seqno", seqno_);
    s.store_field("amount", amount_);
    s.store_bytes_field("message", message_);
    s.store_class_end();
  }
}

testWallet_getAccountAddress::testWallet_getAccountAddress()
  : initital_account_state_()
{}

testWallet_getAccountAddress::testWallet_getAccountAddress(object_ptr<testWallet_initialAccountState> &&initital_account_state_)
  : initital_account_state_(std::move(initital_account_state_))
{}

const std::int32_t testWallet_getAccountAddress::ID;

void testWallet_getAccountAddress::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "testWallet_getAccountAddress");
    if (initital_account_state_ == nullptr) { s.store_field("initital_account_state", "null"); } else { initital_account_state_->store(s, "initital_account_state"); }
    s.store_class_end();
  }
}

testWallet_getAccountState::testWallet_getAccountState()
  : account_address_()
{}

testWallet_getAccountState::testWallet_getAccountState(object_ptr<accountAddress> &&account_address_)
  : account_address_(std::move(account_address_))
{}

const std::int32_t testWallet_getAccountState::ID;

void testWallet_getAccountState::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "testWallet_getAccountState");
    if (account_address_ == nullptr) { s.store_field("account_address", "null"); } else { account_address_->store(s, "account_address"); }
    s.store_class_end();
  }
}

testWallet_init::testWallet_init()
  : private_key_()
{}

testWallet_init::testWallet_init(object_ptr<inputKey> &&private_key_)
  : private_key_(std::move(private_key_))
{}

const std::int32_t testWallet_init::ID;

void testWallet_init::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "testWallet_init");
    if (private_key_ == nullptr) { s.store_field("private_key", "null"); } else { private_key_->store(s, "private_key"); }
    s.store_class_end();
  }
}

testWallet_sendGrams::testWallet_sendGrams()
  : private_key_()
  , destination_()
  , seqno_()
  , amount_()
  , message_()
{}

testWallet_sendGrams::testWallet_sendGrams(object_ptr<inputKey> &&private_key_, object_ptr<accountAddress> &&destination_, std::int32_t seqno_, std::int64_t amount_, std::string const &message_)
  : private_key_(std::move(private_key_))
  , destination_(std::move(destination_))
  , seqno_(seqno_)
  , amount_(amount_)
  , message_(std::move(message_))
{}

const std::int32_t testWallet_sendGrams::ID;

void testWallet_sendGrams::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "testWallet_sendGrams");
    if (private_key_ == nullptr) { s.store_field("private_key", "null"); } else { private_key_->store(s, "private_key"); }
    if (destination_ == nullptr) { s.store_field("destination", "null"); } else { destination_->store(s, "destination"); }
    s.store_field("seqno", seqno_);
    s.store_field("amount", amount_);
    s.store_bytes_field("message", message_);
    s.store_class_end();
  }
}
}  // namespace tonlib_api
}  // namespace ton
