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

class accountRevisionList;

class AccountState;

class Action;

class adnlAddress;

class bip39Hints;

class config;

class data;

class error;

class exportedEncryptedKey;

class exportedKey;

class exportedPemKey;

class exportedUnencryptedKey;

class fees;

class fullAccountState;

class InitialAccountState;

class InputKey;

class key;

class KeyStoreType;

class LogStream;

class logTags;

class logVerbosityLevel;

class ok;

class options;

class SyncState;

class unpackedAccountAddress;

class Update;

class dns_Action;

class dns_entry;

class dns_EntryData;

class dns_resolved;

class ton_blockId;

class internal_transactionId;

class liteServer_info;

class msg_Data;

class msg_dataDecrypted;

class msg_dataDecryptedArray;

class msg_dataEncrypted;

class msg_dataEncryptedArray;

class msg_message;

class options_configInfo;

class options_info;

class pchan_Action;

class pchan_config;

class pchan_promise;

class pchan_State;

class query_fees;

class query_info;

class raw_fullAccountState;

class raw_message;

class raw_transaction;

class raw_transactions;

class rwallet_actionInit;

class rwallet_config;

class rwallet_limit;

class smc_info;

class smc_MethodId;

class smc_runResult;

class ton_blockIdExt;

class tvm_cell;

class tvm_list;

class tvm_numberDecimal;

class tvm_slice;

class tvm_StackEntry;

class tvm_tuple;

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

class accountRevisionList final : public Object {
 public:
  std::vector<std::int32_t> revisions_;

  accountRevisionList();

  explicit accountRevisionList(std::vector<std::int32_t> &&revisions_);

  static const std::int32_t ID = 120583012;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class AccountState: public Object {
 public:
};

class raw_accountState final : public AccountState {
 public:
  std::string code_;
  std::string data_;
  std::string frozen_hash_;

  raw_accountState();

  raw_accountState(std::string const &code_, std::string const &data_, std::string const &frozen_hash_);

  static const std::int32_t ID = -531917254;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class testWallet_accountState final : public AccountState {
 public:
  std::int32_t seqno_;

  testWallet_accountState();

  explicit testWallet_accountState(std::int32_t seqno_);

  static const std::int32_t ID = -2053909931;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class wallet_accountState final : public AccountState {
 public:
  std::int32_t seqno_;

  wallet_accountState();

  explicit wallet_accountState(std::int32_t seqno_);

  static const std::int32_t ID = -390017192;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class wallet_v3_accountState final : public AccountState {
 public:
  std::int64_t wallet_id_;
  std::int32_t seqno_;

  wallet_v3_accountState();

  wallet_v3_accountState(std::int64_t wallet_id_, std::int32_t seqno_);

  static const std::int32_t ID = -1619351478;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class wallet_highload_v1_accountState final : public AccountState {
 public:
  std::int64_t wallet_id_;
  std::int32_t seqno_;

  wallet_highload_v1_accountState();

  wallet_highload_v1_accountState(std::int64_t wallet_id_, std::int32_t seqno_);

  static const std::int32_t ID = 1616372956;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class wallet_highload_v2_accountState final : public AccountState {
 public:
  std::int64_t wallet_id_;

  wallet_highload_v2_accountState();

  explicit wallet_highload_v2_accountState(std::int64_t wallet_id_);

  static const std::int32_t ID = -1803723441;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class testGiver_accountState final : public AccountState {
 public:
  std::int32_t seqno_;

  testGiver_accountState();

  explicit testGiver_accountState(std::int32_t seqno_);

  static const std::int32_t ID = -696813142;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class dns_accountState final : public AccountState {
 public:
  std::int64_t wallet_id_;

  dns_accountState();

  explicit dns_accountState(std::int64_t wallet_id_);

  static const std::int32_t ID = 1727715434;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class rwallet_accountState final : public AccountState {
 public:
  std::int64_t wallet_id_;
  std::int32_t seqno_;
  std::int64_t unlocked_balance_;
  object_ptr<rwallet_config> config_;

  rwallet_accountState();

  rwallet_accountState(std::int64_t wallet_id_, std::int32_t seqno_, std::int64_t unlocked_balance_, object_ptr<rwallet_config> &&config_);

  static const std::int32_t ID = -739540008;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class pchan_accountState final : public AccountState {
 public:
  object_ptr<pchan_config> config_;
  object_ptr<pchan_State> state_;
  std::string description_;

  pchan_accountState();

  pchan_accountState(object_ptr<pchan_config> &&config_, object_ptr<pchan_State> &&state_, std::string const &description_);

  static const std::int32_t ID = 1612869496;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class uninited_accountState final : public AccountState {
 public:
  std::string frozen_hash_;

  uninited_accountState();

  explicit uninited_accountState(std::string const &frozen_hash_);

  static const std::int32_t ID = 1522374408;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class Action: public Object {
 public:
};

class actionNoop final : public Action {
 public:

  actionNoop();

  static const std::int32_t ID = 1135848603;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class actionMsg final : public Action {
 public:
  std::vector<object_ptr<msg_message>> messages_;
  bool allow_send_to_uninited_;

  actionMsg();

  actionMsg(std::vector<object_ptr<msg_message>> &&messages_, bool allow_send_to_uninited_);

  static const std::int32_t ID = 246839120;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class actionDns final : public Action {
 public:
  std::vector<object_ptr<dns_Action>> actions_;

  actionDns();

  explicit actionDns(std::vector<object_ptr<dns_Action>> &&actions_);

  static const std::int32_t ID = 1193750561;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class actionPchan final : public Action {
 public:
  object_ptr<pchan_Action> action_;

  actionPchan();

  explicit actionPchan(object_ptr<pchan_Action> &&action_);

  static const std::int32_t ID = -1490172447;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class actionRwallet final : public Action {
 public:
  object_ptr<rwallet_actionInit> action_;

  actionRwallet();

  explicit actionRwallet(object_ptr<rwallet_actionInit> &&action_);

  static const std::int32_t ID = -117295163;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class adnlAddress final : public Object {
 public:
  std::string adnl_address_;

  adnlAddress();

  explicit adnlAddress(std::string const &adnl_address_);

  static const std::int32_t ID = 70358284;
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

class exportedUnencryptedKey final : public Object {
 public:
  td::SecureString data_;

  exportedUnencryptedKey();

  explicit exportedUnencryptedKey(td::SecureString &&data_);

  static const std::int32_t ID = 730045160;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class fees final : public Object {
 public:
  std::int64_t in_fwd_fee_;
  std::int64_t storage_fee_;
  std::int64_t gas_fee_;
  std::int64_t fwd_fee_;

  fees();

  fees(std::int64_t in_fwd_fee_, std::int64_t storage_fee_, std::int64_t gas_fee_, std::int64_t fwd_fee_);

  static const std::int32_t ID = 1676273340;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class fullAccountState final : public Object {
 public:
  std::int64_t balance_;
  object_ptr<internal_transactionId> last_transaction_id_;
  object_ptr<ton_blockIdExt> block_id_;
  std::int64_t sync_utime_;
  object_ptr<AccountState> account_state_;

  fullAccountState();

  fullAccountState(std::int64_t balance_, object_ptr<internal_transactionId> &&last_transaction_id_, object_ptr<ton_blockIdExt> &&block_id_, std::int64_t sync_utime_, object_ptr<AccountState> &&account_state_);

  static const std::int32_t ID = -686286006;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class InitialAccountState: public Object {
 public:
};

class raw_initialAccountState final : public InitialAccountState {
 public:
  std::string code_;
  std::string data_;

  raw_initialAccountState();

  raw_initialAccountState(std::string const &code_, std::string const &data_);

  static const std::int32_t ID = -337945529;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class testGiver_initialAccountState final : public InitialAccountState {
 public:

  testGiver_initialAccountState();

  static const std::int32_t ID = -1448412176;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class testWallet_initialAccountState final : public InitialAccountState {
 public:
  std::string public_key_;

  testWallet_initialAccountState();

  explicit testWallet_initialAccountState(std::string const &public_key_);

  static const std::int32_t ID = 819380068;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class wallet_initialAccountState final : public InitialAccountState {
 public:
  std::string public_key_;

  wallet_initialAccountState();

  explicit wallet_initialAccountState(std::string const &public_key_);

  static const std::int32_t ID = -1122166790;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class wallet_v3_initialAccountState final : public InitialAccountState {
 public:
  std::string public_key_;
  std::int64_t wallet_id_;

  wallet_v3_initialAccountState();

  wallet_v3_initialAccountState(std::string const &public_key_, std::int64_t wallet_id_);

  static const std::int32_t ID = -118074048;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class wallet_highload_v1_initialAccountState final : public InitialAccountState {
 public:
  std::string public_key_;
  std::int64_t wallet_id_;

  wallet_highload_v1_initialAccountState();

  wallet_highload_v1_initialAccountState(std::string const &public_key_, std::int64_t wallet_id_);

  static const std::int32_t ID = -327901626;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class wallet_highload_v2_initialAccountState final : public InitialAccountState {
 public:
  std::string public_key_;
  std::int64_t wallet_id_;

  wallet_highload_v2_initialAccountState();

  wallet_highload_v2_initialAccountState(std::string const &public_key_, std::int64_t wallet_id_);

  static const std::int32_t ID = 1966373161;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class rwallet_initialAccountState final : public InitialAccountState {
 public:
  std::string init_public_key_;
  std::string public_key_;
  std::int64_t wallet_id_;

  rwallet_initialAccountState();

  rwallet_initialAccountState(std::string const &init_public_key_, std::string const &public_key_, std::int64_t wallet_id_);

  static const std::int32_t ID = 1169755156;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class dns_initialAccountState final : public InitialAccountState {
 public:
  std::string public_key_;
  std::int64_t wallet_id_;

  dns_initialAccountState();

  dns_initialAccountState(std::string const &public_key_, std::int64_t wallet_id_);

  static const std::int32_t ID = 1842062527;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class pchan_initialAccountState final : public InitialAccountState {
 public:
  object_ptr<pchan_config> config_;

  pchan_initialAccountState();

  explicit pchan_initialAccountState(object_ptr<pchan_config> &&config_);

  static const std::int32_t ID = -1304552124;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class InputKey: public Object {
 public:
};

class inputKeyRegular final : public InputKey {
 public:
  object_ptr<key> key_;
  td::SecureString local_password_;

  inputKeyRegular();

  inputKeyRegular(object_ptr<key> &&key_, td::SecureString &&local_password_);

  static const std::int32_t ID = -555399522;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class inputKeyFake final : public InputKey {
 public:

  inputKeyFake();

  static const std::int32_t ID = -1074054722;
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

class SyncState: public Object {
 public:
};

class syncStateDone final : public SyncState {
 public:

  syncStateDone();

  static const std::int32_t ID = 1408448777;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class syncStateInProgress final : public SyncState {
 public:
  std::int32_t from_seqno_;
  std::int32_t to_seqno_;
  std::int32_t current_seqno_;

  syncStateInProgress();

  syncStateInProgress(std::int32_t from_seqno_, std::int32_t to_seqno_, std::int32_t current_seqno_);

  static const std::int32_t ID = 107726023;
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

class Update: public Object {
 public:
};

class updateSendLiteServerQuery final : public Update {
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

class updateSyncState final : public Update {
 public:
  object_ptr<SyncState> sync_state_;

  updateSyncState();

  explicit updateSyncState(object_ptr<SyncState> &&sync_state_);

  static const std::int32_t ID = 1204298718;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class dns_Action: public Object {
 public:
};

class dns_actionDeleteAll final : public dns_Action {
 public:

  dns_actionDeleteAll();

  static const std::int32_t ID = 1067356318;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class dns_actionDelete final : public dns_Action {
 public:
  std::string name_;
  std::int32_t category_;

  dns_actionDelete();

  dns_actionDelete(std::string const &name_, std::int32_t category_);

  static const std::int32_t ID = 775206882;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class dns_actionSet final : public dns_Action {
 public:
  object_ptr<dns_entry> entry_;

  dns_actionSet();

  explicit dns_actionSet(object_ptr<dns_entry> &&entry_);

  static const std::int32_t ID = -1374965309;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class dns_entry final : public Object {
 public:
  std::string name_;
  std::int32_t category_;
  object_ptr<dns_EntryData> entry_;

  dns_entry();

  dns_entry(std::string const &name_, std::int32_t category_, object_ptr<dns_EntryData> &&entry_);

  static const std::int32_t ID = -1842435400;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class dns_EntryData: public Object {
 public:
};

class dns_entryDataUnknown final : public dns_EntryData {
 public:
  std::string bytes_;

  dns_entryDataUnknown();

  explicit dns_entryDataUnknown(std::string const &bytes_);

  static const std::int32_t ID = -1285893248;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class dns_entryDataText final : public dns_EntryData {
 public:
  std::string text_;

  dns_entryDataText();

  explicit dns_entryDataText(std::string const &text_);

  static const std::int32_t ID = -792485614;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class dns_entryDataNextResolver final : public dns_EntryData {
 public:
  object_ptr<accountAddress> resolver_;

  dns_entryDataNextResolver();

  explicit dns_entryDataNextResolver(object_ptr<accountAddress> &&resolver_);

  static const std::int32_t ID = 330382792;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class dns_entryDataSmcAddress final : public dns_EntryData {
 public:
  object_ptr<accountAddress> smc_address_;

  dns_entryDataSmcAddress();

  explicit dns_entryDataSmcAddress(object_ptr<accountAddress> &&smc_address_);

  static const std::int32_t ID = -1759937982;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class dns_entryDataAdnlAddress final : public dns_EntryData {
 public:
  object_ptr<adnlAddress> adnl_address_;

  dns_entryDataAdnlAddress();

  explicit dns_entryDataAdnlAddress(object_ptr<adnlAddress> &&adnl_address_);

  static const std::int32_t ID = -1114064368;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class dns_resolved final : public Object {
 public:
  std::vector<object_ptr<dns_entry>> entries_;

  dns_resolved();

  explicit dns_resolved(std::vector<object_ptr<dns_entry>> &&entries_);

  static const std::int32_t ID = 2090272150;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class ton_blockId final : public Object {
 public:
  std::int32_t workchain_;
  std::int64_t shard_;
  std::int32_t seqno_;

  ton_blockId();

  ton_blockId(std::int32_t workchain_, std::int64_t shard_, std::int32_t seqno_);

  static const std::int32_t ID = -1185382494;
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

class liteServer_info final : public Object {
 public:
  std::int64_t now_;
  std::int32_t version_;
  std::int64_t capabilities_;

  liteServer_info();

  liteServer_info(std::int64_t now_, std::int32_t version_, std::int64_t capabilities_);

  static const std::int32_t ID = -1250165133;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class msg_Data: public Object {
 public:
};

class msg_dataRaw final : public msg_Data {
 public:
  std::string body_;
  std::string init_state_;

  msg_dataRaw();

  msg_dataRaw(std::string const &body_, std::string const &init_state_);

  static const std::int32_t ID = -1928962698;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class msg_dataText final : public msg_Data {
 public:
  std::string text_;

  msg_dataText();

  explicit msg_dataText(std::string const &text_);

  static const std::int32_t ID = -341560688;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class msg_dataDecryptedText final : public msg_Data {
 public:
  std::string text_;

  msg_dataDecryptedText();

  explicit msg_dataDecryptedText(std::string const &text_);

  static const std::int32_t ID = -1289133895;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class msg_dataEncryptedText final : public msg_Data {
 public:
  std::string text_;

  msg_dataEncryptedText();

  explicit msg_dataEncryptedText(std::string const &text_);

  static const std::int32_t ID = -296612902;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class msg_dataDecrypted final : public Object {
 public:
  std::string proof_;
  object_ptr<msg_Data> data_;

  msg_dataDecrypted();

  msg_dataDecrypted(std::string const &proof_, object_ptr<msg_Data> &&data_);

  static const std::int32_t ID = 195649769;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class msg_dataDecryptedArray final : public Object {
 public:
  std::vector<object_ptr<msg_dataDecrypted>> elements_;

  msg_dataDecryptedArray();

  explicit msg_dataDecryptedArray(std::vector<object_ptr<msg_dataDecrypted>> &&elements_);

  static const std::int32_t ID = -480491767;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class msg_dataEncrypted final : public Object {
 public:
  object_ptr<accountAddress> source_;
  object_ptr<msg_Data> data_;

  msg_dataEncrypted();

  msg_dataEncrypted(object_ptr<accountAddress> &&source_, object_ptr<msg_Data> &&data_);

  static const std::int32_t ID = 564215121;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class msg_dataEncryptedArray final : public Object {
 public:
  std::vector<object_ptr<msg_dataEncrypted>> elements_;

  msg_dataEncryptedArray();

  explicit msg_dataEncryptedArray(std::vector<object_ptr<msg_dataEncrypted>> &&elements_);

  static const std::int32_t ID = 608655794;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class msg_message final : public Object {
 public:
  object_ptr<accountAddress> destination_;
  std::string public_key_;
  std::int64_t amount_;
  object_ptr<msg_Data> data_;

  msg_message();

  msg_message(object_ptr<accountAddress> &&destination_, std::string const &public_key_, std::int64_t amount_, object_ptr<msg_Data> &&data_);

  static const std::int32_t ID = -2110533580;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class options_configInfo final : public Object {
 public:
  std::int64_t default_wallet_id_;

  options_configInfo();

  explicit options_configInfo(std::int64_t default_wallet_id_);

  static const std::int32_t ID = 451217371;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class options_info final : public Object {
 public:
  object_ptr<options_configInfo> config_info_;

  options_info();

  explicit options_info(object_ptr<options_configInfo> &&config_info_);

  static const std::int32_t ID = -64676736;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class pchan_Action: public Object {
 public:
};

class pchan_actionInit final : public pchan_Action {
 public:
  std::int64_t inc_A_;
  std::int64_t inc_B_;
  std::int64_t min_A_;
  std::int64_t min_B_;

  pchan_actionInit();

  pchan_actionInit(std::int64_t inc_A_, std::int64_t inc_B_, std::int64_t min_A_, std::int64_t min_B_);

  static const std::int32_t ID = 439088778;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class pchan_actionClose final : public pchan_Action {
 public:
  std::int64_t extra_A_;
  std::int64_t extra_B_;
  object_ptr<pchan_promise> promise_;

  pchan_actionClose();

  pchan_actionClose(std::int64_t extra_A_, std::int64_t extra_B_, object_ptr<pchan_promise> &&promise_);

  static const std::int32_t ID = 1671187222;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class pchan_actionTimeout final : public pchan_Action {
 public:

  pchan_actionTimeout();

  static const std::int32_t ID = 1998487795;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class pchan_config final : public Object {
 public:
  std::string alice_public_key_;
  object_ptr<accountAddress> alice_address_;
  std::string bob_public_key_;
  object_ptr<accountAddress> bob_address_;
  std::int32_t init_timeout_;
  std::int32_t close_timeout_;
  std::int64_t channel_id_;

  pchan_config();

  pchan_config(std::string const &alice_public_key_, object_ptr<accountAddress> &&alice_address_, std::string const &bob_public_key_, object_ptr<accountAddress> &&bob_address_, std::int32_t init_timeout_, std::int32_t close_timeout_, std::int64_t channel_id_);

  static const std::int32_t ID = -2071530442;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class pchan_promise final : public Object {
 public:
  std::string signature_;
  std::int64_t promise_A_;
  std::int64_t promise_B_;
  std::int64_t channel_id_;

  pchan_promise();

  pchan_promise(std::string const &signature_, std::int64_t promise_A_, std::int64_t promise_B_, std::int64_t channel_id_);

  static const std::int32_t ID = -1576102819;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class pchan_State: public Object {
 public:
};

class pchan_stateInit final : public pchan_State {
 public:
  bool signed_A_;
  bool signed_B_;
  std::int64_t min_A_;
  std::int64_t min_B_;
  std::int64_t expire_at_;
  std::int64_t A_;
  std::int64_t B_;

  pchan_stateInit();

  pchan_stateInit(bool signed_A_, bool signed_B_, std::int64_t min_A_, std::int64_t min_B_, std::int64_t expire_at_, std::int64_t A_, std::int64_t B_);

  static const std::int32_t ID = -1188426504;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class pchan_stateClose final : public pchan_State {
 public:
  bool signed_A_;
  bool signed_B_;
  std::int64_t min_A_;
  std::int64_t min_B_;
  std::int64_t expire_at_;
  std::int64_t A_;
  std::int64_t B_;

  pchan_stateClose();

  pchan_stateClose(bool signed_A_, bool signed_B_, std::int64_t min_A_, std::int64_t min_B_, std::int64_t expire_at_, std::int64_t A_, std::int64_t B_);

  static const std::int32_t ID = 887226867;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class pchan_statePayout final : public pchan_State {
 public:
  std::int64_t A_;
  std::int64_t B_;

  pchan_statePayout();

  pchan_statePayout(std::int64_t A_, std::int64_t B_);

  static const std::int32_t ID = 664671303;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class query_fees final : public Object {
 public:
  object_ptr<fees> source_fees_;
  std::vector<object_ptr<fees>> destination_fees_;

  query_fees();

  query_fees(object_ptr<fees> &&source_fees_, std::vector<object_ptr<fees>> &&destination_fees_);

  static const std::int32_t ID = 1614616510;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class query_info final : public Object {
 public:
  std::int64_t id_;
  std::int64_t valid_until_;
  std::string body_hash_;
  std::string body_;
  std::string init_state_;

  query_info();

  query_info(std::int64_t id_, std::int64_t valid_until_, std::string const &body_hash_, std::string const &body_, std::string const &init_state_);

  static const std::int32_t ID = 1451875440;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class raw_fullAccountState final : public Object {
 public:
  std::int64_t balance_;
  std::string code_;
  std::string data_;
  object_ptr<internal_transactionId> last_transaction_id_;
  object_ptr<ton_blockIdExt> block_id_;
  std::string frozen_hash_;
  std::int64_t sync_utime_;

  raw_fullAccountState();

  raw_fullAccountState(std::int64_t balance_, std::string const &code_, std::string const &data_, object_ptr<internal_transactionId> &&last_transaction_id_, object_ptr<ton_blockIdExt> &&block_id_, std::string const &frozen_hash_, std::int64_t sync_utime_);

  static const std::int32_t ID = -1465398385;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class raw_message final : public Object {
 public:
  object_ptr<accountAddress> source_;
  object_ptr<accountAddress> destination_;
  std::int64_t value_;
  std::int64_t fwd_fee_;
  std::int64_t ihr_fee_;
  std::int64_t created_lt_;
  std::string body_hash_;
  object_ptr<msg_Data> msg_data_;

  raw_message();

  raw_message(object_ptr<accountAddress> &&source_, object_ptr<accountAddress> &&destination_, std::int64_t value_, std::int64_t fwd_fee_, std::int64_t ihr_fee_, std::int64_t created_lt_, std::string const &body_hash_, object_ptr<msg_Data> &&msg_data_);

  static const std::int32_t ID = 1368093263;
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

class rwallet_actionInit final : public Object {
 public:
  object_ptr<rwallet_config> config_;

  rwallet_actionInit();

  explicit rwallet_actionInit(object_ptr<rwallet_config> &&config_);

  static const std::int32_t ID = 624147819;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class rwallet_config final : public Object {
 public:
  std::int64_t start_at_;
  std::vector<object_ptr<rwallet_limit>> limits_;

  rwallet_config();

  rwallet_config(std::int64_t start_at_, std::vector<object_ptr<rwallet_limit>> &&limits_);

  static const std::int32_t ID = -85490534;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class rwallet_limit final : public Object {
 public:
  std::int32_t seconds_;
  std::int64_t value_;

  rwallet_limit();

  rwallet_limit(std::int32_t seconds_, std::int64_t value_);

  static const std::int32_t ID = 1222571646;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class smc_info final : public Object {
 public:
  std::int64_t id_;

  smc_info();

  explicit smc_info(std::int64_t id_);

  static const std::int32_t ID = 1134270012;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class smc_MethodId: public Object {
 public:
};

class smc_methodIdNumber final : public smc_MethodId {
 public:
  std::int32_t number_;

  smc_methodIdNumber();

  explicit smc_methodIdNumber(std::int32_t number_);

  static const std::int32_t ID = -1541162500;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class smc_methodIdName final : public smc_MethodId {
 public:
  std::string name_;

  smc_methodIdName();

  explicit smc_methodIdName(std::string const &name_);

  static const std::int32_t ID = -249036908;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class smc_runResult final : public Object {
 public:
  std::int64_t gas_used_;
  std::vector<object_ptr<tvm_StackEntry>> stack_;
  std::int32_t exit_code_;

  smc_runResult();

  smc_runResult(std::int64_t gas_used_, std::vector<object_ptr<tvm_StackEntry>> &&stack_, std::int32_t exit_code_);

  static const std::int32_t ID = 1413805043;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class ton_blockIdExt final : public Object {
 public:
  std::int32_t workchain_;
  std::int64_t shard_;
  std::int32_t seqno_;
  std::string root_hash_;
  std::string file_hash_;

  ton_blockIdExt();

  ton_blockIdExt(std::int32_t workchain_, std::int64_t shard_, std::int32_t seqno_, std::string const &root_hash_, std::string const &file_hash_);

  static const std::int32_t ID = 2031156378;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class tvm_cell final : public Object {
 public:
  std::string bytes_;

  tvm_cell();

  explicit tvm_cell(std::string const &bytes_);

  static const std::int32_t ID = -413424735;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class tvm_list final : public Object {
 public:
  std::vector<object_ptr<tvm_StackEntry>> elements_;

  tvm_list();

  explicit tvm_list(std::vector<object_ptr<tvm_StackEntry>> &&elements_);

  static const std::int32_t ID = 1270320392;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class tvm_numberDecimal final : public Object {
 public:
  std::string number_;

  tvm_numberDecimal();

  explicit tvm_numberDecimal(std::string const &number_);

  static const std::int32_t ID = 1172477619;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class tvm_slice final : public Object {
 public:
  std::string bytes_;

  tvm_slice();

  explicit tvm_slice(std::string const &bytes_);

  static const std::int32_t ID = 537299687;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class tvm_StackEntry: public Object {
 public:
};

class tvm_stackEntrySlice final : public tvm_StackEntry {
 public:
  object_ptr<tvm_slice> slice_;

  tvm_stackEntrySlice();

  explicit tvm_stackEntrySlice(object_ptr<tvm_slice> &&slice_);

  static const std::int32_t ID = 1395485477;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class tvm_stackEntryCell final : public tvm_StackEntry {
 public:
  object_ptr<tvm_cell> cell_;

  tvm_stackEntryCell();

  explicit tvm_stackEntryCell(object_ptr<tvm_cell> &&cell_);

  static const std::int32_t ID = 1303473952;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class tvm_stackEntryNumber final : public tvm_StackEntry {
 public:
  object_ptr<tvm_numberDecimal> number_;

  tvm_stackEntryNumber();

  explicit tvm_stackEntryNumber(object_ptr<tvm_numberDecimal> &&number_);

  static const std::int32_t ID = 1358642622;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class tvm_stackEntryTuple final : public tvm_StackEntry {
 public:
  object_ptr<tvm_tuple> tuple_;

  tvm_stackEntryTuple();

  explicit tvm_stackEntryTuple(object_ptr<tvm_tuple> &&tuple_);

  static const std::int32_t ID = -157391908;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class tvm_stackEntryList final : public tvm_StackEntry {
 public:
  object_ptr<tvm_list> list_;

  tvm_stackEntryList();

  explicit tvm_stackEntryList(object_ptr<tvm_list> &&list_);

  static const std::int32_t ID = -1186714229;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class tvm_stackEntryUnsupported final : public tvm_StackEntry {
 public:

  tvm_stackEntryUnsupported();

  static const std::int32_t ID = 378880498;
  std::int32_t get_id() const final {
    return ID;
  }

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class tvm_tuple final : public Object {
 public:
  std::vector<object_ptr<tvm_StackEntry>> elements_;

  tvm_tuple();

  explicit tvm_tuple(std::vector<object_ptr<tvm_StackEntry>> &&elements_);

  static const std::int32_t ID = -1363953053;
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
  object_ptr<InputKey> input_key_;
  td::SecureString new_local_password_;

  changeLocalPassword();

  changeLocalPassword(object_ptr<InputKey> &&input_key_, td::SecureString &&new_local_password_);

  static const std::int32_t ID = -401590337;
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

class createQuery final : public Function {
 public:
  object_ptr<InputKey> private_key_;
  object_ptr<accountAddress> address_;
  std::int32_t timeout_;
  object_ptr<Action> action_;
  object_ptr<InitialAccountState> initial_account_state_;

  createQuery();

  createQuery(object_ptr<InputKey> &&private_key_, object_ptr<accountAddress> &&address_, std::int32_t timeout_, object_ptr<Action> &&action_, object_ptr<InitialAccountState> &&initial_account_state_);

  static const std::int32_t ID = -242540347;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<query_info>;

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

class dns_resolve final : public Function {
 public:
  object_ptr<accountAddress> account_address_;
  std::string name_;
  std::int32_t category_;
  std::int32_t ttl_;

  dns_resolve();

  dns_resolve(object_ptr<accountAddress> &&account_address_, std::string const &name_, std::int32_t category_, std::int32_t ttl_);

  static const std::int32_t ID = -149238065;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<dns_resolved>;

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
  object_ptr<InputKey> input_key_;
  td::SecureString key_password_;

  exportEncryptedKey();

  exportEncryptedKey(object_ptr<InputKey> &&input_key_, td::SecureString &&key_password_);

  static const std::int32_t ID = 218237311;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<exportedEncryptedKey>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class exportKey final : public Function {
 public:
  object_ptr<InputKey> input_key_;

  exportKey();

  explicit exportKey(object_ptr<InputKey> &&input_key_);

  static const std::int32_t ID = -1622353549;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<exportedKey>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class exportPemKey final : public Function {
 public:
  object_ptr<InputKey> input_key_;
  td::SecureString key_password_;

  exportPemKey();

  exportPemKey(object_ptr<InputKey> &&input_key_, td::SecureString &&key_password_);

  static const std::int32_t ID = -643259462;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<exportedPemKey>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class exportUnencryptedKey final : public Function {
 public:
  object_ptr<InputKey> input_key_;

  exportUnencryptedKey();

  explicit exportUnencryptedKey(object_ptr<InputKey> &&input_key_);

  static const std::int32_t ID = -634665152;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<exportedUnencryptedKey>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class getAccountAddress final : public Function {
 public:
  object_ptr<InitialAccountState> initial_account_state_;
  std::int32_t revision_;

  getAccountAddress();

  getAccountAddress(object_ptr<InitialAccountState> &&initial_account_state_, std::int32_t revision_);

  static const std::int32_t ID = -1159101819;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<accountAddress>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class getAccountState final : public Function {
 public:
  object_ptr<accountAddress> account_address_;

  getAccountState();

  explicit getAccountState(object_ptr<accountAddress> &&account_address_);

  static const std::int32_t ID = -2116357050;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<fullAccountState>;

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

class guessAccountRevision final : public Function {
 public:
  object_ptr<InitialAccountState> initial_account_state_;

  guessAccountRevision();

  explicit guessAccountRevision(object_ptr<InitialAccountState> &&initial_account_state_);

  static const std::int32_t ID = 1463344293;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<accountRevisionList>;

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

class importUnencryptedKey final : public Function {
 public:
  td::SecureString local_password_;
  object_ptr<exportedUnencryptedKey> exported_unencrypted_key_;

  importUnencryptedKey();

  importUnencryptedKey(td::SecureString &&local_password_, object_ptr<exportedUnencryptedKey> &&exported_unencrypted_key_);

  static const std::int32_t ID = -1184671467;
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

  static const std::int32_t ID = -1000594762;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<options_info>;

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

class liteServer_getInfo final : public Function {
 public:

  liteServer_getInfo();

  static const std::int32_t ID = 1435327470;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<liteServer_info>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class msg_decrypt final : public Function {
 public:
  object_ptr<InputKey> input_key_;
  object_ptr<msg_dataEncryptedArray> data_;

  msg_decrypt();

  msg_decrypt(object_ptr<InputKey> &&input_key_, object_ptr<msg_dataEncryptedArray> &&data_);

  static const std::int32_t ID = 223596297;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<msg_dataDecryptedArray>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class msg_decryptWithProof final : public Function {
 public:
  std::string proof_;
  object_ptr<msg_dataEncrypted> data_;

  msg_decryptWithProof();

  msg_decryptWithProof(std::string const &proof_, object_ptr<msg_dataEncrypted> &&data_);

  static const std::int32_t ID = -2111649663;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<msg_Data>;

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

  static const std::int32_t ID = 1870064579;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<options_configInfo>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class options_validateConfig final : public Function {
 public:
  object_ptr<config> config_;

  options_validateConfig();

  explicit options_validateConfig(object_ptr<config> &&config_);

  static const std::int32_t ID = -346965447;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<options_configInfo>;

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

class pchan_packPromise final : public Function {
 public:
  object_ptr<pchan_promise> promise_;

  pchan_packPromise();

  explicit pchan_packPromise(object_ptr<pchan_promise> &&promise_);

  static const std::int32_t ID = -851703103;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<data>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class pchan_signPromise final : public Function {
 public:
  object_ptr<InputKey> input_key_;
  object_ptr<pchan_promise> promise_;

  pchan_signPromise();

  pchan_signPromise(object_ptr<InputKey> &&input_key_, object_ptr<pchan_promise> &&promise_);

  static const std::int32_t ID = 1814322974;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<pchan_promise>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class pchan_unpackPromise final : public Function {
 public:
  td::SecureString data_;

  pchan_unpackPromise();

  explicit pchan_unpackPromise(td::SecureString &&data_);

  static const std::int32_t ID = -1250106157;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<pchan_promise>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class pchan_validatePromise final : public Function {
 public:
  std::string public_key_;
  object_ptr<pchan_promise> promise_;

  pchan_validatePromise();

  pchan_validatePromise(std::string const &public_key_, object_ptr<pchan_promise> &&promise_);

  static const std::int32_t ID = 258262242;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<ok>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class query_estimateFees final : public Function {
 public:
  std::int64_t id_;
  bool ignore_chksig_;

  query_estimateFees();

  query_estimateFees(std::int64_t id_, bool ignore_chksig_);

  static const std::int32_t ID = -957002175;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<query_fees>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class query_forget final : public Function {
 public:
  std::int64_t id_;

  query_forget();

  explicit query_forget(std::int64_t id_);

  static const std::int32_t ID = -1211985313;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<ok>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class query_getInfo final : public Function {
 public:
  std::int64_t id_;

  query_getInfo();

  explicit query_getInfo(std::int64_t id_);

  static const std::int32_t ID = -799333669;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<query_info>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class query_send final : public Function {
 public:
  std::int64_t id_;

  query_send();

  explicit query_send(std::int64_t id_);

  static const std::int32_t ID = 925242739;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<ok>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class raw_createAndSendMessage final : public Function {
 public:
  object_ptr<accountAddress> destination_;
  std::string initial_account_state_;
  std::string data_;

  raw_createAndSendMessage();

  raw_createAndSendMessage(object_ptr<accountAddress> &&destination_, std::string const &initial_account_state_, std::string const &data_);

  static const std::int32_t ID = -772224603;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<ok>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class raw_createQuery final : public Function {
 public:
  object_ptr<accountAddress> destination_;
  std::string init_code_;
  std::string init_data_;
  std::string body_;

  raw_createQuery();

  raw_createQuery(object_ptr<accountAddress> &&destination_, std::string const &init_code_, std::string const &init_data_, std::string const &body_);

  static const std::int32_t ID = -1928557909;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<query_info>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class raw_getAccountState final : public Function {
 public:
  object_ptr<accountAddress> account_address_;

  raw_getAccountState();

  explicit raw_getAccountState(object_ptr<accountAddress> &&account_address_);

  static const std::int32_t ID = -1327847118;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<raw_fullAccountState>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class raw_getTransactions final : public Function {
 public:
  object_ptr<InputKey> private_key_;
  object_ptr<accountAddress> account_address_;
  object_ptr<internal_transactionId> from_transaction_id_;

  raw_getTransactions();

  raw_getTransactions(object_ptr<InputKey> &&private_key_, object_ptr<accountAddress> &&account_address_, object_ptr<internal_transactionId> &&from_transaction_id_);

  static const std::int32_t ID = 1029612317;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<raw_transactions>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class raw_sendMessage final : public Function {
 public:
  std::string body_;

  raw_sendMessage();

  explicit raw_sendMessage(std::string const &body_);

  static const std::int32_t ID = -1789427488;
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

class smc_getCode final : public Function {
 public:
  std::int64_t id_;

  smc_getCode();

  explicit smc_getCode(std::int64_t id_);

  static const std::int32_t ID = -2115626088;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<tvm_cell>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class smc_getData final : public Function {
 public:
  std::int64_t id_;

  smc_getData();

  explicit smc_getData(std::int64_t id_);

  static const std::int32_t ID = -427601079;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<tvm_cell>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class smc_getState final : public Function {
 public:
  std::int64_t id_;

  smc_getState();

  explicit smc_getState(std::int64_t id_);

  static const std::int32_t ID = -214390293;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<tvm_cell>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class smc_load final : public Function {
 public:
  object_ptr<accountAddress> account_address_;

  smc_load();

  explicit smc_load(object_ptr<accountAddress> &&account_address_);

  static const std::int32_t ID = -903491521;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<smc_info>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class smc_runGetMethod final : public Function {
 public:
  std::int64_t id_;
  object_ptr<smc_MethodId> method_;
  std::vector<object_ptr<tvm_StackEntry>> stack_;

  smc_runGetMethod();

  smc_runGetMethod(std::int64_t id_, object_ptr<smc_MethodId> &&method_, std::vector<object_ptr<tvm_StackEntry>> &&stack_);

  static const std::int32_t ID = -255261270;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<smc_runResult>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

class sync final : public Function {
 public:

  sync();

  static const std::int32_t ID = -1875977070;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<ton_blockIdExt>;

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

class withBlock final : public Function {
 public:
  object_ptr<ton_blockIdExt> id_;
  object_ptr<Function> function_;

  withBlock();

  withBlock(object_ptr<ton_blockIdExt> &&id_, object_ptr<Function> &&function_);

  static const std::int32_t ID = -789093723;
  std::int32_t get_id() const final {
    return ID;
  }

  using ReturnType = object_ptr<Object>;

  void store(td::TlStorerToString &s, const char *field_name) const final;
};

}  // namespace tonlib_api
}  // namespace ton
