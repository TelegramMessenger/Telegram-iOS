#pragma once

#include "TlObject.h"

#include "int_types.h"

#include <string>

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

class error;

class exportedKey;

class exportedPemKey;

class inputKey;

class key;

class ok;

class options;

class generic_AccountState;

class generic_InitialAccountState;

class internal_transactionId;

class raw_accountState;

class raw_initialAccountState;

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

class exportedKey final : public Object {
 public:
  std::vector<std::string> word_list_;

  exportedKey();

  explicit exportedKey(std::vector<std::string> &&word_list_);

  static const std::int32_t ID = -1591775274;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class exportedPemKey final : public Object {
 public:
  std::string pem_;

  exportedPemKey();

  explicit exportedPemKey(std::string const &pem_);

  static const std::int32_t ID = -1606004936;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class inputKey final : public Object {
 public:
  object_ptr<key> key_;
  std::string local_password_;

  inputKey();

  inputKey(object_ptr<key> &&key_, std::string const &local_password_);

  static const std::int32_t ID = -896546932;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class key final : public Object {
 public:
  std::string public_key_;
  std::string secret_;

  key();

  key(std::string const &public_key_, std::string const &secret_);

  static const std::int32_t ID = -1824886393;
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

  options();

  options(std::string const &config_, std::string const &keystore_directory_);

  static const std::int32_t ID = -876766471;
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
  object_ptr<internal_transactionId> last_transaction_;

  raw_accountState();

  raw_accountState(std::int64_t balance_, std::string const &code_, std::string const &data_, object_ptr<internal_transactionId> &&last_transaction_);

  static const std::int32_t ID = 1473454653;
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

class testGiver_accountState final : public Object {
 public:
  std::int64_t balance_;
  std::int32_t seqno_;
  object_ptr<internal_transactionId> last_transaction_id_;

  testGiver_accountState();

  testGiver_accountState(std::int64_t balance_, std::int32_t seqno_, object_ptr<internal_transactionId> &&last_transaction_id_);

  static const std::int32_t ID = 2037609684;
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

  testWallet_accountState();

  testWallet_accountState(std::int64_t balance_, std::int32_t seqno_, object_ptr<internal_transactionId> &&last_transaction_id_);

  static const std::int32_t ID = 105752218;
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

  static const std::int32_t ID = 276948331;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class uninited_accountState final : public Object {
 public:
  std::int64_t balance_;

  uninited_accountState();

  explicit uninited_accountState(std::int64_t balance_);

  static const std::int32_t ID = -1992757598;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class changeLocalPassword final : public Function {
 public:
  object_ptr<inputKey> input_key_;
  std::string new_local_password_;

  changeLocalPassword();

  changeLocalPassword(object_ptr<inputKey> &&input_key_, std::string const &new_local_password_);

  static const std::int32_t ID = 1851603483;
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
  std::string local_password_;
  std::string mnemonic_password_;

  createNewKey();

  createNewKey(std::string const &local_password_, std::string const &mnemonic_password_);

  static const std::int32_t ID = -132817741;
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

  static const std::int32_t ID = -1148357295;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<ok>;

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
  std::string key_password_;

  exportPemKey();

  exportPemKey(object_ptr<inputKey> &&input_key_, std::string const &key_password_);

  static const std::int32_t ID = -189764962;
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

class importKey final : public Function {
 public:
  std::string local_password_;
  std::string mnemonic_password_;
  object_ptr<exportedKey> exported_key_;

  importKey();

  importKey(std::string const &local_password_, std::string const &mnemonic_password_, object_ptr<exportedKey> &&exported_key_);

  static const std::int32_t ID = -1396771552;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<key>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class importPemKey final : public Function {
 public:
  std::string local_password_;
  std::string key_password_;
  object_ptr<exportedPemKey> exported_key_;

  importPemKey();

  importPemKey(std::string const &local_password_, std::string const &key_password_, object_ptr<exportedPemKey> &&exported_key_);

  static const std::int32_t ID = -15644852;
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
