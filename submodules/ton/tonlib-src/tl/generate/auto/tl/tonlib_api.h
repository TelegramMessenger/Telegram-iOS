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

class error;

class exportedEncryptedKey;

class exportedKey;

class exportedPemKey;

class inputKey;

class key;

class ok;

class options;

class updateSendLiteServerQuery;

class generic_AccountState;

class generic_InitialAccountState;

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
  std::string config_;
  std::string keystore_directory_;
  bool use_callbacks_for_network_;

  options();

  options(std::string const &config_, std::string const &keystore_directory_, bool use_callbacks_for_network_);

  static const std::int32_t ID = -952483001;
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

class generic_InitialAccountState: public Object {
 public:
};

class generic_initialAccountStateRaw final : public generic_InitialAccountState {
 public:
  object_ptr<raw_initialAccountState> initital_account_state_;

  generic_initialAccountStateRaw();

  explicit generic_initialAccountStateRaw(object_ptr<raw_initialAccountState> &&initital_account_state_);

  static const std::int32_t ID = -1178429153;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class generic_initialAccountStateTestWallet final : public generic_InitialAccountState {
 public:
  object_ptr<testWallet_initialAccountState> initital_account_state_;

  generic_initialAccountStateTestWallet();

  explicit generic_initialAccountStateTestWallet(object_ptr<testWallet_initialAccountState> &&initital_account_state_);

  static const std::int32_t ID = 710924204;
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
  std::int64_t sync_utime_;

  raw_accountState();

  raw_accountState(std::int64_t balance_, std::string const &code_, std::string const &data_, object_ptr<internal_transactionId> &&last_transaction_id_, std::int64_t sync_utime_);

  static const std::int32_t ID = 461615898;
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

  raw_message();

  raw_message(std::string const &source_, std::string const &destination_, std::int64_t value_);

  static const std::int32_t ID = -1131081640;
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
  object_ptr<raw_message> in_msg_;
  std::vector<object_ptr<raw_message>> out_msgs_;

  raw_transaction();

  raw_transaction(std::int64_t utime_, std::string const &data_, object_ptr<internal_transactionId> &&transaction_id_, std::int64_t fee_, object_ptr<raw_message> &&in_msg_, std::vector<object_ptr<raw_message>> &&out_msgs_);

  static const std::int32_t ID = -1159530820;
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

  static const std::int32_t ID = 240548986;
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
  std::int64_t sync_utime_;

  uninited_accountState();

  uninited_accountState(std::int64_t balance_, object_ptr<internal_transactionId> &&last_transaction_id_, std::int64_t sync_utime_);

  static const std::int32_t ID = 1768941188;
  std::int32_t get_id() const final {
    return ID;
  }

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

class deleteKey final : public Function {
 public:
  std::string public_key_;

  deleteKey();

  explicit deleteKey(std::string const &public_key_);

  static const std::int32_t ID = 917647652;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<ok>;

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

  generic_sendGrams();

  generic_sendGrams(object_ptr<inputKey> &&private_key_, object_ptr<accountAddress> &&source_, object_ptr<accountAddress> &&destination_, std::int64_t amount_);

  static const std::int32_t ID = 799772985;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<ok>;

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
  std::string config_;

  options_setConfig();

  explicit options_setConfig(std::string const &config_);

  static const std::int32_t ID = 21225546;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<ok>;

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

  testGiver_sendGrams();

  testGiver_sendGrams(object_ptr<accountAddress> &&destination_, std::int32_t seqno_, std::int64_t amount_);

  static const std::int32_t ID = -178493799;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<ok>;

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

  testWallet_sendGrams();

  testWallet_sendGrams(object_ptr<inputKey> &&private_key_, object_ptr<accountAddress> &&destination_, std::int32_t seqno_, std::int64_t amount_);

  static const std::int32_t ID = -1716705044;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<ok>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

}  // namespace tonlib_api
}  // namespace ton
