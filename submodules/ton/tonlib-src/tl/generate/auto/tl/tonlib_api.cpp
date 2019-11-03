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

config::config()
  : config_()
  , blockchain_name_()
  , use_callbacks_for_network_()
  , ignore_cache_()
{}

config::config(std::string const &config_, std::string const &blockchain_name_, bool use_callbacks_for_network_, bool ignore_cache_)
  : config_(std::move(config_))
  , blockchain_name_(std::move(blockchain_name_))
  , use_callbacks_for_network_(use_callbacks_for_network_)
  , ignore_cache_(ignore_cache_)
{}

const std::int32_t config::ID;

void config::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "config");
    s.store_field("config", config_);
    s.store_field("blockchain_name", blockchain_name_);
    s.store_field("use_callbacks_for_network", use_callbacks_for_network_);
    s.store_field("ignore_cache", ignore_cache_);
    s.store_class_end();
  }
}

data::data()
  : bytes_()
{}

data::data(td::SecureString &&bytes_)
  : bytes_(std::move(bytes_))
{}

const std::int32_t data::ID;

void data::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "data");
    s.store_bytes_field("bytes", bytes_);
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

fees::fees()
  : in_fwd_fee_()
  , storage_fee_()
  , gas_fee_()
  , fwd_fee_()
{}

fees::fees(std::int64_t in_fwd_fee_, std::int64_t storage_fee_, std::int64_t gas_fee_, std::int64_t fwd_fee_)
  : in_fwd_fee_(in_fwd_fee_)
  , storage_fee_(storage_fee_)
  , gas_fee_(gas_fee_)
  , fwd_fee_(fwd_fee_)
{}

const std::int32_t fees::ID;

void fees::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "fees");
    s.store_field("in_fwd_fee", in_fwd_fee_);
    s.store_field("storage_fee", storage_fee_);
    s.store_field("gas_fee", gas_fee_);
    s.store_field("fwd_fee", fwd_fee_);
    s.store_class_end();
  }
}

inputKeyRegular::inputKeyRegular()
  : key_()
  , local_password_()
{}

inputKeyRegular::inputKeyRegular(object_ptr<key> &&key_, td::SecureString &&local_password_)
  : key_(std::move(key_))
  , local_password_(std::move(local_password_))
{}

const std::int32_t inputKeyRegular::ID;

void inputKeyRegular::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "inputKeyRegular");
    if (key_ == nullptr) { s.store_field("key", "null"); } else { key_->store(s, "key"); }
    s.store_bytes_field("local_password", local_password_);
    s.store_class_end();
  }
}

inputKeyFake::inputKeyFake() {
}

const std::int32_t inputKeyFake::ID;

void inputKeyFake::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "inputKeyFake");
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

keyStoreTypeDirectory::keyStoreTypeDirectory()
  : directory_()
{}

keyStoreTypeDirectory::keyStoreTypeDirectory(std::string const &directory_)
  : directory_(std::move(directory_))
{}

const std::int32_t keyStoreTypeDirectory::ID;

void keyStoreTypeDirectory::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "keyStoreTypeDirectory");
    s.store_field("directory", directory_);
    s.store_class_end();
  }
}

keyStoreTypeInMemory::keyStoreTypeInMemory() {
}

const std::int32_t keyStoreTypeInMemory::ID;

void keyStoreTypeInMemory::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "keyStoreTypeInMemory");
    s.store_class_end();
  }
}

logStreamDefault::logStreamDefault() {
}

const std::int32_t logStreamDefault::ID;

void logStreamDefault::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "logStreamDefault");
    s.store_class_end();
  }
}

logStreamFile::logStreamFile()
  : path_()
  , max_file_size_()
{}

logStreamFile::logStreamFile(std::string const &path_, std::int64_t max_file_size_)
  : path_(std::move(path_))
  , max_file_size_(max_file_size_)
{}

const std::int32_t logStreamFile::ID;

void logStreamFile::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "logStreamFile");
    s.store_field("path", path_);
    s.store_field("max_file_size", max_file_size_);
    s.store_class_end();
  }
}

logStreamEmpty::logStreamEmpty() {
}

const std::int32_t logStreamEmpty::ID;

void logStreamEmpty::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "logStreamEmpty");
    s.store_class_end();
  }
}

logTags::logTags()
  : tags_()
{}

logTags::logTags(std::vector<std::string> &&tags_)
  : tags_(std::move(tags_))
{}

const std::int32_t logTags::ID;

void logTags::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "logTags");
    { const std::vector<std::string> &v = tags_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("tags", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { s.store_field("", v[i]); } s.store_class_end(); }
    s.store_class_end();
  }
}

logVerbosityLevel::logVerbosityLevel()
  : verbosity_level_()
{}

logVerbosityLevel::logVerbosityLevel(std::int32_t verbosity_level_)
  : verbosity_level_(verbosity_level_)
{}

const std::int32_t logVerbosityLevel::ID;

void logVerbosityLevel::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "logVerbosityLevel");
    s.store_field("verbosity_level", verbosity_level_);
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
  , keystore_type_()
{}

options::options(object_ptr<config> &&config_, object_ptr<KeyStoreType> &&keystore_type_)
  : config_(std::move(config_))
  , keystore_type_(std::move(keystore_type_))
{}

const std::int32_t options::ID;

void options::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "options");
    if (config_ == nullptr) { s.store_field("config", "null"); } else { config_->store(s, "config"); }
    if (keystore_type_ == nullptr) { s.store_field("keystore_type", "null"); } else { keystore_type_->store(s, "keystore_type"); }
    s.store_class_end();
  }
}

sendGramsResult::sendGramsResult()
  : sent_until_()
  , body_hash_()
{}

sendGramsResult::sendGramsResult(std::int64_t sent_until_, std::string const &body_hash_)
  : sent_until_(sent_until_)
  , body_hash_(std::move(body_hash_))
{}

const std::int32_t sendGramsResult::ID;

void sendGramsResult::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "sendGramsResult");
    s.store_field("sent_until", sent_until_);
    s.store_bytes_field("body_hash", body_hash_);
    s.store_class_end();
  }
}

syncStateDone::syncStateDone() {
}

const std::int32_t syncStateDone::ID;

void syncStateDone::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "syncStateDone");
    s.store_class_end();
  }
}

syncStateInProgress::syncStateInProgress()
  : from_seqno_()
  , to_seqno_()
  , current_seqno_()
{}

syncStateInProgress::syncStateInProgress(std::int32_t from_seqno_, std::int32_t to_seqno_, std::int32_t current_seqno_)
  : from_seqno_(from_seqno_)
  , to_seqno_(to_seqno_)
  , current_seqno_(current_seqno_)
{}

const std::int32_t syncStateInProgress::ID;

void syncStateInProgress::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "syncStateInProgress");
    s.store_field("from_seqno", from_seqno_);
    s.store_field("to_seqno", to_seqno_);
    s.store_field("current_seqno", current_seqno_);
    s.store_class_end();
  }
}

unpackedAccountAddress::unpackedAccountAddress()
  : workchain_id_()
  , bounceable_()
  , testnet_()
  , addr_()
{}

unpackedAccountAddress::unpackedAccountAddress(std::int32_t workchain_id_, bool bounceable_, bool testnet_, std::string const &addr_)
  : workchain_id_(workchain_id_)
  , bounceable_(bounceable_)
  , testnet_(testnet_)
  , addr_(std::move(addr_))
{}

const std::int32_t unpackedAccountAddress::ID;

void unpackedAccountAddress::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "unpackedAccountAddress");
    s.store_field("workchain_id", workchain_id_);
    s.store_field("bounceable", bounceable_);
    s.store_field("testnet", testnet_);
    s.store_bytes_field("addr", addr_);
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

updateSyncState::updateSyncState()
  : sync_state_()
{}

updateSyncState::updateSyncState(object_ptr<SyncState> &&sync_state_)
  : sync_state_(std::move(sync_state_))
{}

const std::int32_t updateSyncState::ID;

void updateSyncState::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "updateSyncState");
    if (sync_state_ == nullptr) { s.store_field("sync_state", "null"); } else { sync_state_->store(s, "sync_state"); }
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

generic_accountStateWallet::generic_accountStateWallet()
  : account_state_()
{}

generic_accountStateWallet::generic_accountStateWallet(object_ptr<wallet_accountState> &&account_state_)
  : account_state_(std::move(account_state_))
{}

const std::int32_t generic_accountStateWallet::ID;

void generic_accountStateWallet::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "generic_accountStateWallet");
    if (account_state_ == nullptr) { s.store_field("account_state", "null"); } else { account_state_->store(s, "account_state"); }
    s.store_class_end();
  }
}

generic_accountStateWalletV3::generic_accountStateWalletV3()
  : account_state_()
{}

generic_accountStateWalletV3::generic_accountStateWalletV3(object_ptr<wallet_v3_accountState> &&account_state_)
  : account_state_(std::move(account_state_))
{}

const std::int32_t generic_accountStateWalletV3::ID;

void generic_accountStateWalletV3::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "generic_accountStateWalletV3");
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

liteServer_info::liteServer_info()
  : now_()
  , version_()
  , capabilities_()
{}

liteServer_info::liteServer_info(std::int64_t now_, std::int32_t version_, std::int64_t capabilities_)
  : now_(now_)
  , version_(version_)
  , capabilities_(capabilities_)
{}

const std::int32_t liteServer_info::ID;

void liteServer_info::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "liteServer_info");
    s.store_field("now", now_);
    s.store_field("version", version_);
    s.store_field("capabilities", capabilities_);
    s.store_class_end();
  }
}

options_configInfo::options_configInfo()
  : default_wallet_id_()
{}

options_configInfo::options_configInfo(std::int64_t default_wallet_id_)
  : default_wallet_id_(default_wallet_id_)
{}

const std::int32_t options_configInfo::ID;

void options_configInfo::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "options_configInfo");
    s.store_field("default_wallet_id", default_wallet_id_);
    s.store_class_end();
  }
}

query_fees::query_fees()
  : source_fees_()
  , destination_fees_()
{}

query_fees::query_fees(object_ptr<fees> &&source_fees_, object_ptr<fees> &&destination_fees_)
  : source_fees_(std::move(source_fees_))
  , destination_fees_(std::move(destination_fees_))
{}

const std::int32_t query_fees::ID;

void query_fees::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "query_fees");
    if (source_fees_ == nullptr) { s.store_field("source_fees", "null"); } else { source_fees_->store(s, "source_fees"); }
    if (destination_fees_ == nullptr) { s.store_field("destination_fees", "null"); } else { destination_fees_->store(s, "destination_fees"); }
    s.store_class_end();
  }
}

query_info::query_info()
  : id_()
  , valid_until_()
  , body_hash_()
{}

query_info::query_info(std::int64_t id_, std::int64_t valid_until_, std::string const &body_hash_)
  : id_(id_)
  , valid_until_(valid_until_)
  , body_hash_(std::move(body_hash_))
{}

const std::int32_t query_info::ID;

void query_info::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "query_info");
    s.store_field("id", id_);
    s.store_field("valid_until", valid_until_);
    s.store_bytes_field("body_hash", body_hash_);
    s.store_class_end();
  }
}

raw_accountState::raw_accountState()
  : balance_()
  , code_()
  , data_()
  , last_transaction_id_()
  , frozen_hash_()
  , sync_utime_()
{}

raw_accountState::raw_accountState(std::int64_t balance_, std::string const &code_, std::string const &data_, object_ptr<internal_transactionId> &&last_transaction_id_, std::string const &frozen_hash_, std::int64_t sync_utime_)
  : balance_(balance_)
  , code_(std::move(code_))
  , data_(std::move(data_))
  , last_transaction_id_(std::move(last_transaction_id_))
  , frozen_hash_(std::move(frozen_hash_))
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
    s.store_bytes_field("frozen_hash", frozen_hash_);
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
  , fwd_fee_()
  , ihr_fee_()
  , created_lt_()
  , body_hash_()
  , message_()
{}

raw_message::raw_message(std::string const &source_, std::string const &destination_, std::int64_t value_, std::int64_t fwd_fee_, std::int64_t ihr_fee_, std::int64_t created_lt_, std::string const &body_hash_, std::string const &message_)
  : source_(std::move(source_))
  , destination_(std::move(destination_))
  , value_(value_)
  , fwd_fee_(fwd_fee_)
  , ihr_fee_(ihr_fee_)
  , created_lt_(created_lt_)
  , body_hash_(std::move(body_hash_))
  , message_(std::move(message_))
{}

const std::int32_t raw_message::ID;

void raw_message::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "raw_message");
    s.store_field("source", source_);
    s.store_field("destination", destination_);
    s.store_field("value", value_);
    s.store_field("fwd_fee", fwd_fee_);
    s.store_field("ihr_fee", ihr_fee_);
    s.store_field("created_lt", created_lt_);
    s.store_bytes_field("body_hash", body_hash_);
    s.store_bytes_field("message", message_);
    s.store_class_end();
  }
}

raw_transaction::raw_transaction()
  : utime_()
  , data_()
  , transaction_id_()
  , fee_()
  , storage_fee_()
  , other_fee_()
  , in_msg_()
  , out_msgs_()
{}

raw_transaction::raw_transaction(std::int64_t utime_, std::string const &data_, object_ptr<internal_transactionId> &&transaction_id_, std::int64_t fee_, std::int64_t storage_fee_, std::int64_t other_fee_, object_ptr<raw_message> &&in_msg_, std::vector<object_ptr<raw_message>> &&out_msgs_)
  : utime_(utime_)
  , data_(std::move(data_))
  , transaction_id_(std::move(transaction_id_))
  , fee_(fee_)
  , storage_fee_(storage_fee_)
  , other_fee_(other_fee_)
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
    s.store_field("storage_fee", storage_fee_);
    s.store_field("other_fee", other_fee_);
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

smc_info::smc_info()
  : id_()
{}

smc_info::smc_info(std::int64_t id_)
  : id_(id_)
{}

const std::int32_t smc_info::ID;

void smc_info::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "smc_info");
    s.store_field("id", id_);
    s.store_class_end();
  }
}

smc_methodIdNumber::smc_methodIdNumber()
  : number_()
{}

smc_methodIdNumber::smc_methodIdNumber(std::int32_t number_)
  : number_(number_)
{}

const std::int32_t smc_methodIdNumber::ID;

void smc_methodIdNumber::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "smc_methodIdNumber");
    s.store_field("number", number_);
    s.store_class_end();
  }
}

smc_methodIdName::smc_methodIdName()
  : name_()
{}

smc_methodIdName::smc_methodIdName(std::string const &name_)
  : name_(std::move(name_))
{}

const std::int32_t smc_methodIdName::ID;

void smc_methodIdName::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "smc_methodIdName");
    s.store_field("name", name_);
    s.store_class_end();
  }
}

smc_runResult::smc_runResult()
  : gas_used_()
  , stack_()
  , exit_code_()
{}

smc_runResult::smc_runResult(std::int64_t gas_used_, std::vector<object_ptr<tvm_StackEntry>> &&stack_, std::int32_t exit_code_)
  : gas_used_(gas_used_)
  , stack_(std::move(stack_))
  , exit_code_(exit_code_)
{}

const std::int32_t smc_runResult::ID;

void smc_runResult::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "smc_runResult");
    s.store_field("gas_used", gas_used_);
    { const std::vector<object_ptr<tvm_StackEntry>> &v = stack_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("stack", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    s.store_field("exit_code", exit_code_);
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

tvm_cell::tvm_cell()
  : bytes_()
{}

tvm_cell::tvm_cell(std::string const &bytes_)
  : bytes_(std::move(bytes_))
{}

const std::int32_t tvm_cell::ID;

void tvm_cell::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tvm_cell");
    s.store_field("bytes", bytes_);
    s.store_class_end();
  }
}

tvm_numberDecimal::tvm_numberDecimal()
  : number_()
{}

tvm_numberDecimal::tvm_numberDecimal(std::string const &number_)
  : number_(std::move(number_))
{}

const std::int32_t tvm_numberDecimal::ID;

void tvm_numberDecimal::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tvm_numberDecimal");
    s.store_field("number", number_);
    s.store_class_end();
  }
}

tvm_slice::tvm_slice()
  : bytes_()
{}

tvm_slice::tvm_slice(std::string const &bytes_)
  : bytes_(std::move(bytes_))
{}

const std::int32_t tvm_slice::ID;

void tvm_slice::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tvm_slice");
    s.store_field("bytes", bytes_);
    s.store_class_end();
  }
}

tvm_stackEntrySlice::tvm_stackEntrySlice()
  : slice_()
{}

tvm_stackEntrySlice::tvm_stackEntrySlice(object_ptr<tvm_slice> &&slice_)
  : slice_(std::move(slice_))
{}

const std::int32_t tvm_stackEntrySlice::ID;

void tvm_stackEntrySlice::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tvm_stackEntrySlice");
    if (slice_ == nullptr) { s.store_field("slice", "null"); } else { slice_->store(s, "slice"); }
    s.store_class_end();
  }
}

tvm_stackEntryCell::tvm_stackEntryCell()
  : cell_()
{}

tvm_stackEntryCell::tvm_stackEntryCell(object_ptr<tvm_cell> &&cell_)
  : cell_(std::move(cell_))
{}

const std::int32_t tvm_stackEntryCell::ID;

void tvm_stackEntryCell::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tvm_stackEntryCell");
    if (cell_ == nullptr) { s.store_field("cell", "null"); } else { cell_->store(s, "cell"); }
    s.store_class_end();
  }
}

tvm_stackEntryNumber::tvm_stackEntryNumber()
  : number_()
{}

tvm_stackEntryNumber::tvm_stackEntryNumber(object_ptr<tvm_numberDecimal> &&number_)
  : number_(std::move(number_))
{}

const std::int32_t tvm_stackEntryNumber::ID;

void tvm_stackEntryNumber::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tvm_stackEntryNumber");
    if (number_ == nullptr) { s.store_field("number", "null"); } else { number_->store(s, "number"); }
    s.store_class_end();
  }
}

tvm_stackEntryUnsupported::tvm_stackEntryUnsupported() {
}

const std::int32_t tvm_stackEntryUnsupported::ID;

void tvm_stackEntryUnsupported::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "tvm_stackEntryUnsupported");
    s.store_class_end();
  }
}

uninited_accountState::uninited_accountState()
  : balance_()
  , last_transaction_id_()
  , frozen_hash_()
  , sync_utime_()
{}

uninited_accountState::uninited_accountState(std::int64_t balance_, object_ptr<internal_transactionId> &&last_transaction_id_, std::string const &frozen_hash_, std::int64_t sync_utime_)
  : balance_(balance_)
  , last_transaction_id_(std::move(last_transaction_id_))
  , frozen_hash_(std::move(frozen_hash_))
  , sync_utime_(sync_utime_)
{}

const std::int32_t uninited_accountState::ID;

void uninited_accountState::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "uninited_accountState");
    s.store_field("balance", balance_);
    if (last_transaction_id_ == nullptr) { s.store_field("last_transaction_id", "null"); } else { last_transaction_id_->store(s, "last_transaction_id"); }
    s.store_bytes_field("frozen_hash", frozen_hash_);
    s.store_field("sync_utime", sync_utime_);
    s.store_class_end();
  }
}

wallet_accountState::wallet_accountState()
  : balance_()
  , seqno_()
  , last_transaction_id_()
  , sync_utime_()
{}

wallet_accountState::wallet_accountState(std::int64_t balance_, std::int32_t seqno_, object_ptr<internal_transactionId> &&last_transaction_id_, std::int64_t sync_utime_)
  : balance_(balance_)
  , seqno_(seqno_)
  , last_transaction_id_(std::move(last_transaction_id_))
  , sync_utime_(sync_utime_)
{}

const std::int32_t wallet_accountState::ID;

void wallet_accountState::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "wallet_accountState");
    s.store_field("balance", balance_);
    s.store_field("seqno", seqno_);
    if (last_transaction_id_ == nullptr) { s.store_field("last_transaction_id", "null"); } else { last_transaction_id_->store(s, "last_transaction_id"); }
    s.store_field("sync_utime", sync_utime_);
    s.store_class_end();
  }
}

wallet_initialAccountState::wallet_initialAccountState()
  : public_key_()
{}

wallet_initialAccountState::wallet_initialAccountState(std::string const &public_key_)
  : public_key_(std::move(public_key_))
{}

const std::int32_t wallet_initialAccountState::ID;

void wallet_initialAccountState::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "wallet_initialAccountState");
    s.store_field("public_key", public_key_);
    s.store_class_end();
  }
}

wallet_v3_accountState::wallet_v3_accountState()
  : balance_()
  , wallet_id_()
  , seqno_()
  , last_transaction_id_()
  , sync_utime_()
{}

wallet_v3_accountState::wallet_v3_accountState(std::int64_t balance_, std::int64_t wallet_id_, std::int32_t seqno_, object_ptr<internal_transactionId> &&last_transaction_id_, std::int64_t sync_utime_)
  : balance_(balance_)
  , wallet_id_(wallet_id_)
  , seqno_(seqno_)
  , last_transaction_id_(std::move(last_transaction_id_))
  , sync_utime_(sync_utime_)
{}

const std::int32_t wallet_v3_accountState::ID;

void wallet_v3_accountState::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "wallet_v3_accountState");
    s.store_field("balance", balance_);
    s.store_field("wallet_id", wallet_id_);
    s.store_field("seqno", seqno_);
    if (last_transaction_id_ == nullptr) { s.store_field("last_transaction_id", "null"); } else { last_transaction_id_->store(s, "last_transaction_id"); }
    s.store_field("sync_utime", sync_utime_);
    s.store_class_end();
  }
}

wallet_v3_initialAccountState::wallet_v3_initialAccountState()
  : public_key_()
  , wallet_id_()
{}

wallet_v3_initialAccountState::wallet_v3_initialAccountState(std::string const &public_key_, std::int64_t wallet_id_)
  : public_key_(std::move(public_key_))
  , wallet_id_(wallet_id_)
{}

const std::int32_t wallet_v3_initialAccountState::ID;

void wallet_v3_initialAccountState::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "wallet_v3_initialAccountState");
    s.store_field("public_key", public_key_);
    s.store_field("wallet_id", wallet_id_);
    s.store_class_end();
  }
}

addLogMessage::addLogMessage()
  : verbosity_level_()
  , text_()
{}

addLogMessage::addLogMessage(std::int32_t verbosity_level_, std::string const &text_)
  : verbosity_level_(verbosity_level_)
  , text_(std::move(text_))
{}

const std::int32_t addLogMessage::ID;

void addLogMessage::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "addLogMessage");
    s.store_field("verbosity_level", verbosity_level_);
    s.store_field("text", text_);
    s.store_class_end();
  }
}

changeLocalPassword::changeLocalPassword()
  : input_key_()
  , new_local_password_()
{}

changeLocalPassword::changeLocalPassword(object_ptr<InputKey> &&input_key_, td::SecureString &&new_local_password_)
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

decrypt::decrypt()
  : encrypted_data_()
  , secret_()
{}

decrypt::decrypt(td::SecureString &&encrypted_data_, td::SecureString &&secret_)
  : encrypted_data_(std::move(encrypted_data_))
  , secret_(std::move(secret_))
{}

const std::int32_t decrypt::ID;

void decrypt::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "decrypt");
    s.store_bytes_field("encrypted_data", encrypted_data_);
    s.store_bytes_field("secret", secret_);
    s.store_class_end();
  }
}

deleteAllKeys::deleteAllKeys() {
}

const std::int32_t deleteAllKeys::ID;

void deleteAllKeys::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "deleteAllKeys");
    s.store_class_end();
  }
}

deleteKey::deleteKey()
  : key_()
{}

deleteKey::deleteKey(object_ptr<key> &&key_)
  : key_(std::move(key_))
{}

const std::int32_t deleteKey::ID;

void deleteKey::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "deleteKey");
    if (key_ == nullptr) { s.store_field("key", "null"); } else { key_->store(s, "key"); }
    s.store_class_end();
  }
}

encrypt::encrypt()
  : decrypted_data_()
  , secret_()
{}

encrypt::encrypt(td::SecureString &&decrypted_data_, td::SecureString &&secret_)
  : decrypted_data_(std::move(decrypted_data_))
  , secret_(std::move(secret_))
{}

const std::int32_t encrypt::ID;

void encrypt::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "encrypt");
    s.store_bytes_field("decrypted_data", decrypted_data_);
    s.store_bytes_field("secret", secret_);
    s.store_class_end();
  }
}

exportEncryptedKey::exportEncryptedKey()
  : input_key_()
  , key_password_()
{}

exportEncryptedKey::exportEncryptedKey(object_ptr<InputKey> &&input_key_, td::SecureString &&key_password_)
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

exportKey::exportKey(object_ptr<InputKey> &&input_key_)
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

exportPemKey::exportPemKey(object_ptr<InputKey> &&input_key_, td::SecureString &&key_password_)
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

generic_createSendGramsQuery::generic_createSendGramsQuery()
  : private_key_()
  , source_()
  , destination_()
  , amount_()
  , timeout_()
  , allow_send_to_uninited_()
  , message_()
{}

generic_createSendGramsQuery::generic_createSendGramsQuery(object_ptr<InputKey> &&private_key_, object_ptr<accountAddress> &&source_, object_ptr<accountAddress> &&destination_, std::int64_t amount_, std::int32_t timeout_, bool allow_send_to_uninited_, std::string const &message_)
  : private_key_(std::move(private_key_))
  , source_(std::move(source_))
  , destination_(std::move(destination_))
  , amount_(amount_)
  , timeout_(timeout_)
  , allow_send_to_uninited_(allow_send_to_uninited_)
  , message_(std::move(message_))
{}

const std::int32_t generic_createSendGramsQuery::ID;

void generic_createSendGramsQuery::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "generic_createSendGramsQuery");
    if (private_key_ == nullptr) { s.store_field("private_key", "null"); } else { private_key_->store(s, "private_key"); }
    if (source_ == nullptr) { s.store_field("source", "null"); } else { source_->store(s, "source"); }
    if (destination_ == nullptr) { s.store_field("destination", "null"); } else { destination_->store(s, "destination"); }
    s.store_field("amount", amount_);
    s.store_field("timeout", timeout_);
    s.store_field("allow_send_to_uninited", allow_send_to_uninited_);
    s.store_bytes_field("message", message_);
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
  , timeout_()
  , allow_send_to_uninited_()
  , message_()
{}

generic_sendGrams::generic_sendGrams(object_ptr<InputKey> &&private_key_, object_ptr<accountAddress> &&source_, object_ptr<accountAddress> &&destination_, std::int64_t amount_, std::int32_t timeout_, bool allow_send_to_uninited_, std::string const &message_)
  : private_key_(std::move(private_key_))
  , source_(std::move(source_))
  , destination_(std::move(destination_))
  , amount_(amount_)
  , timeout_(timeout_)
  , allow_send_to_uninited_(allow_send_to_uninited_)
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
    s.store_field("timeout", timeout_);
    s.store_field("allow_send_to_uninited", allow_send_to_uninited_);
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

getLogStream::getLogStream() {
}

const std::int32_t getLogStream::ID;

void getLogStream::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "getLogStream");
    s.store_class_end();
  }
}

getLogTagVerbosityLevel::getLogTagVerbosityLevel()
  : tag_()
{}

getLogTagVerbosityLevel::getLogTagVerbosityLevel(std::string const &tag_)
  : tag_(std::move(tag_))
{}

const std::int32_t getLogTagVerbosityLevel::ID;

void getLogTagVerbosityLevel::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "getLogTagVerbosityLevel");
    s.store_field("tag", tag_);
    s.store_class_end();
  }
}

getLogTags::getLogTags() {
}

const std::int32_t getLogTags::ID;

void getLogTags::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "getLogTags");
    s.store_class_end();
  }
}

getLogVerbosityLevel::getLogVerbosityLevel() {
}

const std::int32_t getLogVerbosityLevel::ID;

void getLogVerbosityLevel::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "getLogVerbosityLevel");
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

kdf::kdf()
  : password_()
  , salt_()
  , iterations_()
{}

kdf::kdf(td::SecureString &&password_, td::SecureString &&salt_, std::int32_t iterations_)
  : password_(std::move(password_))
  , salt_(std::move(salt_))
  , iterations_(iterations_)
{}

const std::int32_t kdf::ID;

void kdf::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "kdf");
    s.store_bytes_field("password", password_);
    s.store_bytes_field("salt", salt_);
    s.store_field("iterations", iterations_);
    s.store_class_end();
  }
}

liteServer_getInfo::liteServer_getInfo() {
}

const std::int32_t liteServer_getInfo::ID;

void liteServer_getInfo::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "liteServer_getInfo");
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

options_setConfig::options_setConfig(object_ptr<config> &&config_)
  : config_(std::move(config_))
{}

const std::int32_t options_setConfig::ID;

void options_setConfig::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "options_setConfig");
    if (config_ == nullptr) { s.store_field("config", "null"); } else { config_->store(s, "config"); }
    s.store_class_end();
  }
}

options_validateConfig::options_validateConfig()
  : config_()
{}

options_validateConfig::options_validateConfig(object_ptr<config> &&config_)
  : config_(std::move(config_))
{}

const std::int32_t options_validateConfig::ID;

void options_validateConfig::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "options_validateConfig");
    if (config_ == nullptr) { s.store_field("config", "null"); } else { config_->store(s, "config"); }
    s.store_class_end();
  }
}

packAccountAddress::packAccountAddress()
  : account_address_()
{}

packAccountAddress::packAccountAddress(object_ptr<unpackedAccountAddress> &&account_address_)
  : account_address_(std::move(account_address_))
{}

const std::int32_t packAccountAddress::ID;

void packAccountAddress::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "packAccountAddress");
    if (account_address_ == nullptr) { s.store_field("account_address", "null"); } else { account_address_->store(s, "account_address"); }
    s.store_class_end();
  }
}

query_estimateFees::query_estimateFees()
  : id_()
  , ignore_chksig_()
{}

query_estimateFees::query_estimateFees(std::int64_t id_, bool ignore_chksig_)
  : id_(id_)
  , ignore_chksig_(ignore_chksig_)
{}

const std::int32_t query_estimateFees::ID;

void query_estimateFees::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "query_estimateFees");
    s.store_field("id", id_);
    s.store_field("ignore_chksig", ignore_chksig_);
    s.store_class_end();
  }
}

query_forget::query_forget()
  : id_()
{}

query_forget::query_forget(std::int64_t id_)
  : id_(id_)
{}

const std::int32_t query_forget::ID;

void query_forget::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "query_forget");
    s.store_field("id", id_);
    s.store_class_end();
  }
}

query_getInfo::query_getInfo()
  : id_()
{}

query_getInfo::query_getInfo(std::int64_t id_)
  : id_(id_)
{}

const std::int32_t query_getInfo::ID;

void query_getInfo::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "query_getInfo");
    s.store_field("id", id_);
    s.store_class_end();
  }
}

query_send::query_send()
  : id_()
{}

query_send::query_send(std::int64_t id_)
  : id_(id_)
{}

const std::int32_t query_send::ID;

void query_send::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "query_send");
    s.store_field("id", id_);
    s.store_class_end();
  }
}

raw_createAndSendMessage::raw_createAndSendMessage()
  : destination_()
  , initial_account_state_()
  , data_()
{}

raw_createAndSendMessage::raw_createAndSendMessage(object_ptr<accountAddress> &&destination_, std::string const &initial_account_state_, std::string const &data_)
  : destination_(std::move(destination_))
  , initial_account_state_(std::move(initial_account_state_))
  , data_(std::move(data_))
{}

const std::int32_t raw_createAndSendMessage::ID;

void raw_createAndSendMessage::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "raw_createAndSendMessage");
    if (destination_ == nullptr) { s.store_field("destination", "null"); } else { destination_->store(s, "destination"); }
    s.store_bytes_field("initial_account_state", initial_account_state_);
    s.store_bytes_field("data", data_);
    s.store_class_end();
  }
}

raw_createQuery::raw_createQuery()
  : destination_()
  , init_code_()
  , init_data_()
  , body_()
{}

raw_createQuery::raw_createQuery(object_ptr<accountAddress> &&destination_, std::string const &init_code_, std::string const &init_data_, std::string const &body_)
  : destination_(std::move(destination_))
  , init_code_(std::move(init_code_))
  , init_data_(std::move(init_data_))
  , body_(std::move(body_))
{}

const std::int32_t raw_createQuery::ID;

void raw_createQuery::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "raw_createQuery");
    if (destination_ == nullptr) { s.store_field("destination", "null"); } else { destination_->store(s, "destination"); }
    s.store_bytes_field("init_code", init_code_);
    s.store_bytes_field("init_data", init_data_);
    s.store_bytes_field("body", body_);
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
  : body_()
{}

raw_sendMessage::raw_sendMessage(std::string const &body_)
  : body_(std::move(body_))
{}

const std::int32_t raw_sendMessage::ID;

void raw_sendMessage::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "raw_sendMessage");
    s.store_bytes_field("body", body_);
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

setLogStream::setLogStream()
  : log_stream_()
{}

setLogStream::setLogStream(object_ptr<LogStream> &&log_stream_)
  : log_stream_(std::move(log_stream_))
{}

const std::int32_t setLogStream::ID;

void setLogStream::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "setLogStream");
    if (log_stream_ == nullptr) { s.store_field("log_stream", "null"); } else { log_stream_->store(s, "log_stream"); }
    s.store_class_end();
  }
}

setLogTagVerbosityLevel::setLogTagVerbosityLevel()
  : tag_()
  , new_verbosity_level_()
{}

setLogTagVerbosityLevel::setLogTagVerbosityLevel(std::string const &tag_, std::int32_t new_verbosity_level_)
  : tag_(std::move(tag_))
  , new_verbosity_level_(new_verbosity_level_)
{}

const std::int32_t setLogTagVerbosityLevel::ID;

void setLogTagVerbosityLevel::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "setLogTagVerbosityLevel");
    s.store_field("tag", tag_);
    s.store_field("new_verbosity_level", new_verbosity_level_);
    s.store_class_end();
  }
}

setLogVerbosityLevel::setLogVerbosityLevel()
  : new_verbosity_level_()
{}

setLogVerbosityLevel::setLogVerbosityLevel(std::int32_t new_verbosity_level_)
  : new_verbosity_level_(new_verbosity_level_)
{}

const std::int32_t setLogVerbosityLevel::ID;

void setLogVerbosityLevel::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "setLogVerbosityLevel");
    s.store_field("new_verbosity_level", new_verbosity_level_);
    s.store_class_end();
  }
}

smc_getCode::smc_getCode()
  : id_()
{}

smc_getCode::smc_getCode(std::int64_t id_)
  : id_(id_)
{}

const std::int32_t smc_getCode::ID;

void smc_getCode::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "smc_getCode");
    s.store_field("id", id_);
    s.store_class_end();
  }
}

smc_getData::smc_getData()
  : id_()
{}

smc_getData::smc_getData(std::int64_t id_)
  : id_(id_)
{}

const std::int32_t smc_getData::ID;

void smc_getData::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "smc_getData");
    s.store_field("id", id_);
    s.store_class_end();
  }
}

smc_getState::smc_getState()
  : id_()
{}

smc_getState::smc_getState(std::int64_t id_)
  : id_(id_)
{}

const std::int32_t smc_getState::ID;

void smc_getState::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "smc_getState");
    s.store_field("id", id_);
    s.store_class_end();
  }
}

smc_load::smc_load()
  : account_address_()
{}

smc_load::smc_load(object_ptr<accountAddress> &&account_address_)
  : account_address_(std::move(account_address_))
{}

const std::int32_t smc_load::ID;

void smc_load::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "smc_load");
    if (account_address_ == nullptr) { s.store_field("account_address", "null"); } else { account_address_->store(s, "account_address"); }
    s.store_class_end();
  }
}

smc_runGetMethod::smc_runGetMethod()
  : id_()
  , method_()
  , stack_()
{}

smc_runGetMethod::smc_runGetMethod(std::int64_t id_, object_ptr<smc_MethodId> &&method_, std::vector<object_ptr<tvm_StackEntry>> &&stack_)
  : id_(id_)
  , method_(std::move(method_))
  , stack_(std::move(stack_))
{}

const std::int32_t smc_runGetMethod::ID;

void smc_runGetMethod::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "smc_runGetMethod");
    s.store_field("id", id_);
    if (method_ == nullptr) { s.store_field("method", "null"); } else { method_->store(s, "method"); }
    { const std::vector<object_ptr<tvm_StackEntry>> &v = stack_; const std::uint32_t multiplicity = static_cast<std::uint32_t>(v.size()); const auto vector_name = "vector[" + td::to_string(multiplicity)+ "]"; s.store_class_begin("stack", vector_name.c_str()); for (std::uint32_t i = 0; i < multiplicity; i++) { if (v[i] == nullptr) { s.store_field("", "null"); } else { v[i]->store(s, ""); } } s.store_class_end(); }
    s.store_class_end();
  }
}

sync::sync() {
}

const std::int32_t sync::ID;

void sync::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "sync");
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

testWallet_init::testWallet_init(object_ptr<InputKey> &&private_key_)
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

testWallet_sendGrams::testWallet_sendGrams(object_ptr<InputKey> &&private_key_, object_ptr<accountAddress> &&destination_, std::int32_t seqno_, std::int64_t amount_, std::string const &message_)
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

unpackAccountAddress::unpackAccountAddress()
  : account_address_()
{}

unpackAccountAddress::unpackAccountAddress(std::string const &account_address_)
  : account_address_(std::move(account_address_))
{}

const std::int32_t unpackAccountAddress::ID;

void unpackAccountAddress::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "unpackAccountAddress");
    s.store_field("account_address", account_address_);
    s.store_class_end();
  }
}

wallet_getAccountAddress::wallet_getAccountAddress()
  : initital_account_state_()
{}

wallet_getAccountAddress::wallet_getAccountAddress(object_ptr<wallet_initialAccountState> &&initital_account_state_)
  : initital_account_state_(std::move(initital_account_state_))
{}

const std::int32_t wallet_getAccountAddress::ID;

void wallet_getAccountAddress::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "wallet_getAccountAddress");
    if (initital_account_state_ == nullptr) { s.store_field("initital_account_state", "null"); } else { initital_account_state_->store(s, "initital_account_state"); }
    s.store_class_end();
  }
}

wallet_getAccountState::wallet_getAccountState()
  : account_address_()
{}

wallet_getAccountState::wallet_getAccountState(object_ptr<accountAddress> &&account_address_)
  : account_address_(std::move(account_address_))
{}

const std::int32_t wallet_getAccountState::ID;

void wallet_getAccountState::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "wallet_getAccountState");
    if (account_address_ == nullptr) { s.store_field("account_address", "null"); } else { account_address_->store(s, "account_address"); }
    s.store_class_end();
  }
}

wallet_init::wallet_init()
  : private_key_()
{}

wallet_init::wallet_init(object_ptr<InputKey> &&private_key_)
  : private_key_(std::move(private_key_))
{}

const std::int32_t wallet_init::ID;

void wallet_init::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "wallet_init");
    if (private_key_ == nullptr) { s.store_field("private_key", "null"); } else { private_key_->store(s, "private_key"); }
    s.store_class_end();
  }
}

wallet_sendGrams::wallet_sendGrams()
  : private_key_()
  , destination_()
  , seqno_()
  , valid_until_()
  , amount_()
  , message_()
{}

wallet_sendGrams::wallet_sendGrams(object_ptr<InputKey> &&private_key_, object_ptr<accountAddress> &&destination_, std::int32_t seqno_, std::int64_t valid_until_, std::int64_t amount_, std::string const &message_)
  : private_key_(std::move(private_key_))
  , destination_(std::move(destination_))
  , seqno_(seqno_)
  , valid_until_(valid_until_)
  , amount_(amount_)
  , message_(std::move(message_))
{}

const std::int32_t wallet_sendGrams::ID;

void wallet_sendGrams::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "wallet_sendGrams");
    if (private_key_ == nullptr) { s.store_field("private_key", "null"); } else { private_key_->store(s, "private_key"); }
    if (destination_ == nullptr) { s.store_field("destination", "null"); } else { destination_->store(s, "destination"); }
    s.store_field("seqno", seqno_);
    s.store_field("valid_until", valid_until_);
    s.store_field("amount", amount_);
    s.store_bytes_field("message", message_);
    s.store_class_end();
  }
}

wallet_v3_getAccountAddress::wallet_v3_getAccountAddress()
  : initital_account_state_()
{}

wallet_v3_getAccountAddress::wallet_v3_getAccountAddress(object_ptr<wallet_v3_initialAccountState> &&initital_account_state_)
  : initital_account_state_(std::move(initital_account_state_))
{}

const std::int32_t wallet_v3_getAccountAddress::ID;

void wallet_v3_getAccountAddress::store(td::TlStorerToString &s, const char *field_name) const {
  if (!LOG_IS_STRIPPED(ERROR)) {
    s.store_class_begin(field_name, "wallet_v3_getAccountAddress");
    if (initital_account_state_ == nullptr) { s.store_field("initital_account_state", "null"); } else { initital_account_state_->store(s, "initital_account_state"); }
    s.store_class_end();
  }
}
}  // namespace tonlib_api
}  // namespace ton
