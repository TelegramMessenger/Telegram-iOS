#pragma once

#include "tl/TlObject.h"

#include "td/utils/int_types.h"

#include <string>
#include "td/utils/SharedSlice.h"

#include <cstdint>
#include <memory>
#include <utility>
#include <vector>

namespace td {
class TlStorerToString;
}  // namespace td

namespace ton {
namespace tonlib_api{
using BaseObject = ::ton::TlObject;

template <class Type>
using object_ptr = ::ton::tl_object_ptr<Type>;

template <class Type, class... Args>
object_ptr<Type> make_object(Args &&... args) {
  return object_ptr<Type>(new Type(std::forward<Args>(args)...));
}

template <class ToType, class FromType>
object_ptr<ToType> move_object_as(FromType &&from) {
  return object_ptr<ToType>(static_cast<ToType *>(from.release()));
}

std::string to_string(const BaseObject &value);

template <class T>
std::string to_string(const object_ptr<T> &value) {
  if (value == nullptr) {
    return "null";
  }

  return to_string(*value);
}

class accountAddress;

class bip39Hints;

class config;

class data;

class error;

class exportedEncryptedKey;

class exportedKey;

class exportedPemKey;

class inputKey;

class key;

class KeyStoreType;

class LogStream;

class logTags;

class logVerbosityLevel;

class ok;

class options;

class sendGramsResult;

class unpackedAccountAddress;

class updateSendLiteServerQuery;

class generic_AccountState;

class internal_transactionId;

class raw_accountState;

class raw_initialAccountState;

class raw_message;

class raw_transaction;

class raw_transactions;

class testGiver_accountState;

class testWallet_accountState;

class testWallet_initialAccountState;

class uninited_accountState;

class wallet_accountState;

class wallet_initialAccountState;

class Object;

class Object: public TlObject {
 public:
};

class Function: public TlObject {
 public:
};

class accountAddress final : public Object {
 public:
  std::string account_address_;

  accountAddress();

  explicit accountAddress(std::string const &account_address_);

  static const std::int32_t ID = 755613099;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class bip39Hints final : public Object {
 public:
  std::vector<std::string> words_;

  bip39Hints();

  explicit bip39Hints(std::vector<std::string> &&words_);

  static const std::int32_t ID = 1012243456;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class config final : public Object {
 public:
  std::string config_;
  std::string blockchain_name_;
  bool use_callbacks_for_network_;
  bool ignore_cache_;

  config();

  config(std::string const &config_, std::string const &blockchain_name_, bool use_callbacks_for_network_, bool ignore_cache_);

  static const std::int32_t ID = -1538391496;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class data final : public Object {
 public:
  td::SecureString bytes_;

  data();

  explicit data(td::SecureString &&bytes_);

  static const std::int32_t ID = -414733967;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class error final : public Object {
 public:
  std::int32_t code_;
  std::string message_;

  error();

  error(std::int32_t code_, std::string const &message_);

  static const std::int32_t ID = -1679978726;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class exportedEncryptedKey final : public Object {
 public:
  td::SecureString data_;

  exportedEncryptedKey();

  explicit exportedEncryptedKey(td::SecureString &&data_);

  static const std::int32_t ID = 2024406612;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class exportedKey final : public Object {
 public:
  std::vector<td::SecureString> word_list_;

  exportedKey();

  explicit exportedKey(std::vector<td::SecureString> &&word_list_);

  static const std::int32_t ID = -1449248297;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class exportedPemKey final : public Object {
 public:
  td::SecureString pem_;

  exportedPemKey();

  explicit exportedPemKey(td::SecureString &&pem_);

  static const std::int32_t ID = 1425473725;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class inputKey final : public Object {
 public:
  object_ptr<key> key_;
  td::SecureString local_password_;

  inputKey();

  inputKey(object_ptr<key> &&key_, td::SecureString &&local_password_);

  static const std::int32_t ID = 869287093;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class key final : public Object {
 public:
  std::string public_key_;
  td::SecureString secret_;

  key();

  key(std::string const &public_key_, td::SecureString &&secret_);

  static const std::int32_t ID = -1978362923;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class KeyStoreType: public Object {
 public:
};

class keyStoreTypeDirectory final : public KeyStoreType {
 public:
  std::string directory_;

  keyStoreTypeDirectory();

  explicit keyStoreTypeDirectory(std::string const &directory_);

  static const std::int32_t ID = -378990038;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class keyStoreTypeInMemory final : public KeyStoreType {
 public:

  keyStoreTypeInMemory();

  static const std::int32_t ID = -2106848825;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class LogStream: public Object {
 public:
};

class logStreamDefault final : public LogStream {
 public:

  logStreamDefault();

  static const std::int32_t ID = 1390581436;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class logStreamFile final : public LogStream {
 public:
  std::string path_;
  std::int64_t max_file_size_;

  logStreamFile();

  logStreamFile(std::string const &path_, std::int64_t max_file_size_);

  static const std::int32_t ID = -1880085930;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class logStreamEmpty final : public LogStream {
 public:

  logStreamEmpty();

  static const std::int32_t ID = -499912244;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class logTags final : public Object {
 public:
  std::vector<std::string> tags_;

  logTags();

  explicit logTags(std::vector<std::string> &&tags_);

  static const std::int32_t ID = -1604930601;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class logVerbosityLevel final : public Object {
 public:
  std::int32_t verbosity_level_;

  logVerbosityLevel();

  explicit logVerbosityLevel(std::int32_t verbosity_level_);

  static const std::int32_t ID = 1734624234;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class ok final : public Object {
 public:

  ok();

  static const std::int32_t ID = -722616727;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class options final : public Object {
 public:
  object_ptr<config> config_;
  object_ptr<KeyStoreType> keystore_type_;

  options();

  options(object_ptr<config> &&config_, object_ptr<KeyStoreType> &&keystore_type_);

  static const std::int32_t ID = -1924388359;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class sendGramsResult final : public Object {
 public:
  std::int64_t sent_until_;
  std::string body_hash_;

  sendGramsResult();

  sendGramsResult(std::int64_t sent_until_, std::string const &body_hash_);

  static const std::int32_t ID = 426872238;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class unpackedAccountAddress final : public Object {
 public:
  std::int32_t workchain_id_;
  bool bounceable_;
  bool testnet_;
  std::string addr_;

  unpackedAccountAddress();

  unpackedAccountAddress(std::int32_t workchain_id_, bool bounceable_, bool testnet_, std::string const &addr_);

  static const std::int32_t ID = 1892946998;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class updateSendLiteServerQuery final : public Object {
 public:
  std::int64_t id_;
  std::string data_;

  updateSendLiteServerQuery();

  updateSendLiteServerQuery(std::int64_t id_, std::string const &data_);

  static const std::int32_t ID = -1555130916;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class generic_AccountState: public Object {
 public:
};

class generic_accountStateRaw final : public generic_AccountState {
 public:
  object_ptr<raw_accountState> account_state_;

  generic_accountStateRaw();

  explicit generic_accountStateRaw(object_ptr<raw_accountState> &&account_state_);

  static const std::int32_t ID = -1387096685;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class generic_accountStateTestWallet final : public generic_AccountState {
 public:
  object_ptr<testWallet_accountState> account_state_;

  generic_accountStateTestWallet();

  explicit generic_accountStateTestWallet(object_ptr<testWallet_accountState> &&account_state_);

  static const std::int32_t ID = -1041955397;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class generic_accountStateWallet final : public generic_AccountState {
 public:
  object_ptr<wallet_accountState> account_state_;

  generic_accountStateWallet();

  explicit generic_accountStateWallet(object_ptr<wallet_accountState> &&account_state_);

  static const std::int32_t ID = 942582925;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class generic_accountStateTestGiver final : public generic_AccountState {
 public:
  object_ptr<testGiver_accountState> account_state_;

  generic_accountStateTestGiver();

  explicit generic_accountStateTestGiver(object_ptr<testGiver_accountState> &&account_state_);

  static const std::int32_t ID = 1134654598;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class generic_accountStateUninited final : public generic_AccountState {
 public:
  object_ptr<uninited_accountState> account_state_;

  generic_accountStateUninited();

  explicit generic_accountStateUninited(object_ptr<uninited_accountState> &&account_state_);

  static const std::int32_t ID = -908702008;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class internal_transactionId final : public Object {
 public:
  std::int64_t lt_;
  std::string hash_;

  internal_transactionId();

  internal_transactionId(std::int64_t lt_, std::string const &hash_);

  static const std::int32_t ID = -989527262;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class raw_accountState final : public Object {
 public:
  std::int64_t balance_;
  std::string code_;
  std::string data_;
  object_ptr<internal_transactionId> last_transaction_id_;
  std::string frozen_hash_;
  std::int64_t sync_utime_;

  raw_accountState();

  raw_accountState(std::int64_t balance_, std::string const &code_, std::string const &data_, object_ptr<internal_transactionId> &&last_transaction_id_, std::string const &frozen_hash_, std::int64_t sync_utime_);

  static const std::int32_t ID = 1205935434;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class raw_initialAccountState final : public Object {
 public:
  std::string code_;
  std::string data_;

  raw_initialAccountState();

  raw_initialAccountState(std::string const &code_, std::string const &data_);

  static const std::int32_t ID = 777456197;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class raw_message final : public Object {
 public:
  std::string source_;
  std::string destination_;
  std::int64_t value_;
  std::int64_t fwd_fee_;
  std::int64_t ihr_fee_;
  std::int64_t created_lt_;
  std::string body_hash_;
  std::string message_;

  raw_message();

  raw_message(std::string const &source_, std::string const &destination_, std::int64_t value_, std::int64_t fwd_fee_, std::int64_t ihr_fee_, std::int64_t created_lt_, std::string const &body_hash_, std::string const &message_);

  static const std::int32_t ID = -906281442;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class raw_transaction final : public Object {
 public:
  std::int64_t utime_;
  std::string data_;
  object_ptr<internal_transactionId> transaction_id_;
  std::int64_t fee_;
  std::int64_t storage_fee_;
  std::int64_t other_fee_;
  object_ptr<raw_message> in_msg_;
  std::vector<object_ptr<raw_message>> out_msgs_;

  raw_transaction();

  raw_transaction(std::int64_t utime_, std::string const &data_, object_ptr<internal_transactionId> &&transaction_id_, std::int64_t fee_, std::int64_t storage_fee_, std::int64_t other_fee_, object_ptr<raw_message> &&in_msg_, std::vector<object_ptr<raw_message>> &&out_msgs_);

  static const std::int32_t ID = 1887601793;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class raw_transactions final : public Object {
 public:
  std::vector<object_ptr<raw_transaction>> transactions_;
  object_ptr<internal_transactionId> previous_transaction_id_;

  raw_transactions();

  raw_transactions(std::vector<object_ptr<raw_transaction>> &&transactions_, object_ptr<internal_transactionId> &&previous_transaction_id_);

  static const std::int32_t ID = -2063931155;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class testGiver_accountState final : public Object {
 public:
  std::int64_t balance_;
  std::int32_t seqno_;
  object_ptr<internal_transactionId> last_transaction_id_;
  std::int64_t sync_utime_;

  testGiver_accountState();

  testGiver_accountState(std::int64_t balance_, std::int32_t seqno_, object_ptr<internal_transactionId> &&last_transaction_id_, std::int64_t sync_utime_);

  static const std::int32_t ID = 860930426;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class testWallet_accountState final : public Object {
 public:
  std::int64_t balance_;
  std::int32_t seqno_;
  object_ptr<internal_transactionId> last_transaction_id_;
  std::int64_t sync_utime_;

  testWallet_accountState();

  testWallet_accountState(std::int64_t balance_, std::int32_t seqno_, object_ptr<internal_transactionId> &&last_transaction_id_, std::int64_t sync_utime_);

  static const std::int32_t ID = 305698744;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class testWallet_initialAccountState final : public Object {
 public:
  std::string public_key_;

  testWallet_initialAccountState();

  explicit testWallet_initialAccountState(std::string const &public_key_);

  static const std::int32_t ID = -1231516227;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class uninited_accountState final : public Object {
 public:
  std::int64_t balance_;
  object_ptr<internal_transactionId> last_transaction_id_;
  std::string frozen_hash_;
  std::int64_t sync_utime_;

  uninited_accountState();

  uninited_accountState(std::int64_t balance_, object_ptr<internal_transactionId> &&last_transaction_id_, std::string const &frozen_hash_, std::int64_t sync_utime_);

  static const std::int32_t ID = -918880075;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class wallet_accountState final : public Object {
 public:
  std::int64_t balance_;
  std::int32_t seqno_;
  object_ptr<internal_transactionId> last_transaction_id_;
  std::int64_t sync_utime_;

  wallet_accountState();

  wallet_accountState(std::int64_t balance_, std::int32_t seqno_, object_ptr<internal_transactionId> &&last_transaction_id_, std::int64_t sync_utime_);

  static const std::int32_t ID = -1919815977;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class wallet_initialAccountState final : public Object {
 public:
  std::string public_key_;

  wallet_initialAccountState();

  explicit wallet_initialAccountState(std::string const &public_key_);

  static const std::int32_t ID = -1079249978;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class addLogMessage final : public Function {
 public:
  std::int32_t verbosity_level_;
  std::string text_;

  addLogMessage();

  addLogMessage(std::int32_t verbosity_level_, std::string const &text_);

  static const std::int32_t ID = 1597427692;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<ok>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class changeLocalPassword final : public Function {
 public:
  object_ptr<inputKey> input_key_;
  td::SecureString new_local_password_;

  changeLocalPassword();

  changeLocalPassword(object_ptr<inputKey> &&input_key_, td::SecureString &&new_local_password_);

  static const std::int32_t ID = -1685491421;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<key>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class close final : public Function {
 public:

  close();

  static const std::int32_t ID = -1187782273;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<ok>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class createNewKey final : public Function {
 public:
  td::SecureString local_password_;
  td::SecureString mnemonic_password_;
  td::SecureString random_extra_seed_;

  createNewKey();

  createNewKey(td::SecureString &&local_password_, td::SecureString &&mnemonic_password_, td::SecureString &&random_extra_seed_);

  static const std::int32_t ID = -1861385712;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<key>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class decrypt final : public Function {
 public:
  td::SecureString encrypted_data_;
  td::SecureString secret_;

  decrypt();

  decrypt(td::SecureString &&encrypted_data_, td::SecureString &&secret_);

  static const std::int32_t ID = 357991854;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<data>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class deleteAllKeys final : public Function {
 public:

  deleteAllKeys();

  static const std::int32_t ID = 1608776483;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<ok>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class deleteKey final : public Function {
 public:
  object_ptr<key> key_;

  deleteKey();

  explicit deleteKey(object_ptr<key> &&key_);

  static const std::int32_t ID = -1579595571;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<ok>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class encrypt final : public Function {
 public:
  td::SecureString decrypted_data_;
  td::SecureString secret_;

  encrypt();

  encrypt(td::SecureString &&decrypted_data_, td::SecureString &&secret_);

  static const std::int32_t ID = -1821422820;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<data>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class exportEncryptedKey final : public Function {
 public:
  object_ptr<inputKey> input_key_;
  td::SecureString key_password_;

  exportEncryptedKey();

  exportEncryptedKey(object_ptr<inputKey> &&input_key_, td::SecureString &&key_password_);

  static const std::int32_t ID = 155352861;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<exportedEncryptedKey>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class exportKey final : public Function {
 public:
  object_ptr<inputKey> input_key_;

  exportKey();

  explicit exportKey(object_ptr<inputKey> &&input_key_);

  static const std::int32_t ID = 399723440;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<exportedKey>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class exportPemKey final : public Function {
 public:
  object_ptr<inputKey> input_key_;
  td::SecureString key_password_;

  exportPemKey();

  exportPemKey(object_ptr<inputKey> &&input_key_, td::SecureString &&key_password_);

  static const std::int32_t ID = -2047752448;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<exportedPemKey>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class generic_getAccountState final : public Function {
 public:
  object_ptr<accountAddress> account_address_;

  generic_getAccountState();

  explicit generic_getAccountState(object_ptr<accountAddress> &&account_address_);

  static const std::int32_t ID = -657000446;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<generic_AccountState>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class generic_sendGrams final : public Function {
 public:
  object_ptr<inputKey> private_key_;
  object_ptr<accountAddress> source_;
  object_ptr<accountAddress> destination_;
  std::int64_t amount_;
  std::int32_t timeout_;
  bool allow_send_to_uninited_;
  std::string message_;

  generic_sendGrams();

  generic_sendGrams(object_ptr<inputKey> &&private_key_, object_ptr<accountAddress> &&source_, object_ptr<accountAddress> &&destination_, std::int64_t amount_, std::int32_t timeout_, bool allow_send_to_uninited_, std::string const &message_);

  static const std::int32_t ID = -758801136;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<sendGramsResult>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class getBip39Hints final : public Function {
 public:
  std::string prefix_;

  getBip39Hints();

  explicit getBip39Hints(std::string const &prefix_);

  static const std::int32_t ID = -1889640982;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<bip39Hints>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class getLogStream final : public Function {
 public:

  getLogStream();

  static const std::int32_t ID = 1167608667;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<LogStream>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class getLogTagVerbosityLevel final : public Function {
 public:
  std::string tag_;

  getLogTagVerbosityLevel();

  explicit getLogTagVerbosityLevel(std::string const &tag_);

  static const std::int32_t ID = 951004547;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<logVerbosityLevel>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class getLogTags final : public Function {
 public:

  getLogTags();

  static const std::int32_t ID = -254449190;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<logTags>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class getLogVerbosityLevel final : public Function {
 public:

  getLogVerbosityLevel();

  static const std::int32_t ID = 594057956;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<logVerbosityLevel>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class importEncryptedKey final : public Function {
 public:
  td::SecureString local_password_;
  td::SecureString key_password_;
  object_ptr<exportedEncryptedKey> exported_encrypted_key_;

  importEncryptedKey();

  importEncryptedKey(td::SecureString &&local_password_, td::SecureString &&key_password_, object_ptr<exportedEncryptedKey> &&exported_encrypted_key_);

  static const std::int32_t ID = 656724958;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<key>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class importKey final : public Function {
 public:
  td::SecureString local_password_;
  td::SecureString mnemonic_password_;
  object_ptr<exportedKey> exported_key_;

  importKey();

  importKey(td::SecureString &&local_password_, td::SecureString &&mnemonic_password_, object_ptr<exportedKey> &&exported_key_);

  static const std::int32_t ID = -1607900903;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<key>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class importPemKey final : public Function {
 public:
  td::SecureString local_password_;
  td::SecureString key_password_;
  object_ptr<exportedPemKey> exported_key_;

  importPemKey();

  importPemKey(td::SecureString &&local_password_, td::SecureString &&key_password_, object_ptr<exportedPemKey> &&exported_key_);

  static const std::int32_t ID = 76385617;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<key>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class init final : public Function {
 public:
  object_ptr<options> options_;

  init();

  explicit init(object_ptr<options> &&options_);

  static const std::int32_t ID = -2014661877;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<ok>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class kdf final : public Function {
 public:
  td::SecureString password_;
  td::SecureString salt_;
  std::int32_t iterations_;

  kdf();

  kdf(td::SecureString &&password_, td::SecureString &&salt_, std::int32_t iterations_);

  static const std::int32_t ID = -1667861635;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<data>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class onLiteServerQueryError final : public Function {
 public:
  std::int64_t id_;
  object_ptr<error> error_;

  onLiteServerQueryError();

  onLiteServerQueryError(std::int64_t id_, object_ptr<error> &&error_);

  static const std::int32_t ID = -677427533;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<ok>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class onLiteServerQueryResult final : public Function {
 public:
  std::int64_t id_;
  std::string bytes_;

  onLiteServerQueryResult();

  onLiteServerQueryResult(std::int64_t id_, std::string const &bytes_);

  static const std::int32_t ID = 2056444510;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<ok>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class options_setConfig final : public Function {
 public:
  object_ptr<config> config_;

  options_setConfig();

  explicit options_setConfig(object_ptr<config> &&config_);

  static const std::int32_t ID = 646497241;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<ok>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class packAccountAddress final : public Function {
 public:
  object_ptr<unpackedAccountAddress> account_address_;

  packAccountAddress();

  explicit packAccountAddress(object_ptr<unpackedAccountAddress> &&account_address_);

  static const std::int32_t ID = -1388561940;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<accountAddress>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class raw_getAccountAddress final : public Function {
 public:
  object_ptr<raw_initialAccountState> initital_account_state_;

  raw_getAccountAddress();

  explicit raw_getAccountAddress(object_ptr<raw_initialAccountState> &&initital_account_state_);

  static const std::int32_t ID = -521283849;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<accountAddress>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class raw_getAccountState final : public Function {
 public:
  object_ptr<accountAddress> account_address_;

  raw_getAccountState();

  explicit raw_getAccountState(object_ptr<accountAddress> &&account_address_);

  static const std::int32_t ID = 663706721;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<raw_accountState>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class raw_getTransactions final : public Function {
 public:
  object_ptr<accountAddress> account_address_;
  object_ptr<internal_transactionId> from_transaction_id_;

  raw_getTransactions();

  raw_getTransactions(object_ptr<accountAddress> &&account_address_, object_ptr<internal_transactionId> &&from_transaction_id_);

  static const std::int32_t ID = 935377269;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<raw_transactions>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class raw_sendMessage final : public Function {
 public:
  object_ptr<accountAddress> destination_;
  std::string initial_account_state_;
  std::string data_;

  raw_sendMessage();

  raw_sendMessage(object_ptr<accountAddress> &&destination_, std::string const &initial_account_state_, std::string const &data_);

  static const std::int32_t ID = 473889461;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<ok>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class runTests final : public Function {
 public:
  std::string dir_;

  runTests();

  explicit runTests(std::string const &dir_);

  static const std::int32_t ID = -2039925427;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<ok>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class setLogStream final : public Function {
 public:
  object_ptr<LogStream> log_stream_;

  setLogStream();

  explicit setLogStream(object_ptr<LogStream> &&log_stream_);

  static const std::int32_t ID = -1364199535;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<ok>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class setLogTagVerbosityLevel final : public Function {
 public:
  std::string tag_;
  std::int32_t new_verbosity_level_;

  setLogTagVerbosityLevel();

  setLogTagVerbosityLevel(std::string const &tag_, std::int32_t new_verbosity_level_);

  static const std::int32_t ID = -2095589738;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<ok>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class setLogVerbosityLevel final : public Function {
 public:
  std::int32_t new_verbosity_level_;

  setLogVerbosityLevel();

  explicit setLogVerbosityLevel(std::int32_t new_verbosity_level_);

  static const std::int32_t ID = -303429678;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<ok>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class testGiver_getAccountAddress final : public Function {
 public:

  testGiver_getAccountAddress();

  static const std::int32_t ID = -540100768;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<accountAddress>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class testGiver_getAccountState final : public Function {
 public:

  testGiver_getAccountState();

  static const std::int32_t ID = 267738275;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<testGiver_accountState>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class testGiver_sendGrams final : public Function {
 public:
  object_ptr<accountAddress> destination_;
  std::int32_t seqno_;
  std::int64_t amount_;
  std::string message_;

  testGiver_sendGrams();

  testGiver_sendGrams(object_ptr<accountAddress> &&destination_, std::int32_t seqno_, std::int64_t amount_, std::string const &message_);

  static const std::int32_t ID = -1785750375;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<sendGramsResult>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class testWallet_getAccountAddress final : public Function {
 public:
  object_ptr<testWallet_initialAccountState> initital_account_state_;

  testWallet_getAccountAddress();

  explicit testWallet_getAccountAddress(object_ptr<testWallet_initialAccountState> &&initital_account_state_);

  static const std::int32_t ID = -1557748223;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<accountAddress>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class testWallet_getAccountState final : public Function {
 public:
  object_ptr<accountAddress> account_address_;

  testWallet_getAccountState();

  explicit testWallet_getAccountState(object_ptr<accountAddress> &&account_address_);

  static const std::int32_t ID = 654082364;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<testWallet_accountState>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class testWallet_init final : public Function {
 public:
  object_ptr<inputKey> private_key_;

  testWallet_init();

  explicit testWallet_init(object_ptr<inputKey> &&private_key_);

  static const std::int32_t ID = 419055225;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<ok>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class testWallet_sendGrams final : public Function {
 public:
  object_ptr<inputKey> private_key_;
  object_ptr<accountAddress> destination_;
  std::int32_t seqno_;
  std::int64_t amount_;
  std::string message_;

  testWallet_sendGrams();

  testWallet_sendGrams(object_ptr<inputKey> &&private_key_, object_ptr<accountAddress> &&destination_, std::int32_t seqno_, std::int64_t amount_, std::string const &message_);

  static const std::int32_t ID = 1290131585;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<sendGramsResult>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class unpackAccountAddress final : public Function {
 public:
  std::string account_address_;

  unpackAccountAddress();

  explicit unpackAccountAddress(std::string const &account_address_);

  static const std::int32_t ID = -682459063;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<unpackedAccountAddress>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class wallet_getAccountAddress final : public Function {
 public:
  object_ptr<wallet_initialAccountState> initital_account_state_;

  wallet_getAccountAddress();

  explicit wallet_getAccountAddress(object_ptr<wallet_initialAccountState> &&initital_account_state_);

  static const std::int32_t ID = -1004103180;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<accountAddress>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class wallet_getAccountState final : public Function {
 public:
  object_ptr<accountAddress> account_address_;

  wallet_getAccountState();

  explicit wallet_getAccountState(object_ptr<accountAddress> &&account_address_);

  static const std::int32_t ID = 462294850;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<wallet_accountState>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class wallet_init final : public Function {
 public:
  object_ptr<inputKey> private_key_;

  wallet_init();

  explicit wallet_init(object_ptr<inputKey> &&private_key_);

  static const std::int32_t ID = 1528056782;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<ok>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class wallet_sendGrams final : public Function {
 public:
  object_ptr<inputKey> private_key_;
  object_ptr<accountAddress> destination_;
  std::int32_t seqno_;
  std::int64_t valid_until_;
  std::int64_t amount_;
  std::string message_;

  wallet_sendGrams();

  wallet_sendGrams(object_ptr<inputKey> &&private_key_, object_ptr<accountAddress> &&destination_, std::int32_t seqno_, std::int64_t valid_until_, std::int64_t amount_, std::string const &message_);

  static const std::int32_t ID = -1837893526;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<sendGramsResult>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

}  // namespace tonlib_api
}  // namespace ton
