/*
    This file is part of TON Blockchain Library.

    TON Blockchain Library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    TON Blockchain Library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with TON Blockchain Library.  If not, see <http://www.gnu.org/licenses/>.

    Copyright 2017-2019 Telegram Systems LLP
*/
#pragma once

#include "TonlibCallback.h"

#include "tonlib/Config.h"
#include "tonlib/ExtClient.h"
#include "tonlib/ExtClientOutbound.h"
#include "tonlib/KeyStorage.h"
#include "tonlib/KeyValue.h"
#include "tonlib/LastBlockStorage.h"

#include "td/actor/actor.h"

#include "td/utils/CancellationToken.h"
#include "td/utils/optional.h"

#include <map>

namespace tonlib {
namespace int_api {
struct GetAccountState;
struct GetPrivateKey;
struct SendMessage;
inline std::string to_string(const int_api::SendMessage&) {
  return "Send message";
}
}  // namespace int_api
class AccountState;
class Query;

class TonlibClient : public td::actor::Actor {
 public:
  template <class T>
  using object_ptr = tonlib_api::object_ptr<T>;

  explicit TonlibClient(td::unique_ptr<TonlibCallback> callback);
  void request(td::uint64 id, object_ptr<tonlib_api::Function> function);
  void close();
  static object_ptr<tonlib_api::Object> static_request(object_ptr<tonlib_api::Function> function);

  ~TonlibClient();

 private:
  enum class State { Uninited, Running, Closed } state_ = State::Uninited;
  td::unique_ptr<TonlibCallback> callback_;

  // Config
  Config config_;
  td::uint32 config_generation_{0};
  td::uint32 wallet_id_;
  std::string blockchain_name_;
  bool ignore_cache_{false};
  bool use_callbacks_for_network_{false};

  // KeyStorage
  std::shared_ptr<KeyValue> kv_;
  KeyStorage key_storage_;
  LastBlockStorage last_block_storage_;

  // network
  td::actor::ActorOwn<ton::adnl::AdnlExtClient> raw_client_;
  td::actor::ActorId<ExtClientOutbound> ext_client_outbound_;
  td::actor::ActorOwn<LastBlock> raw_last_block_;
  td::actor::ActorOwn<LastConfig> raw_last_config_;
  ExtClient client_;

  td::CancellationTokenSource source_;

  std::map<td::int64, td::actor::ActorOwn<>> actors_;
  td::int64 actor_id_{1};

  ExtClientRef get_client_ref();
  void init_ext_client();
  void init_last_block(td::optional<Config> o_master_config);
  void init_last_config();

  bool is_closing_{false};
  td::uint32 ref_cnt_{1};
  void hangup_shared() override {
    auto it = actors_.find(get_link_token());
    if (it != actors_.end()) {
      actors_.erase(it);
    } else {
      ref_cnt_--;
    }
    try_stop();
  }
  void hangup() override;
  void try_stop() {
    if (is_closing_ && ref_cnt_ == 0 && actors_.empty()) {
      stop();
    }
  }

  void update_last_block_state(LastBlockState state, td::uint32 config_generation_);
  void update_sync_state(LastBlockSyncState state, td::uint32 config_generation);
  void on_result(td::uint64 id, object_ptr<tonlib_api::Object> response);
  void on_update(object_ptr<tonlib_api::Object> response);
  static bool is_static_request(td::int32 id);
  static bool is_uninited_request(td::int32 id);
  template <class T>
  static object_ptr<tonlib_api::Object> do_static_request(const T& request) {
    return tonlib_api::make_object<tonlib_api::error>(400, "Function can't be executed synchronously");
  }
  static object_ptr<tonlib_api::Object> do_static_request(const tonlib_api::runTests& request);
  static object_ptr<tonlib_api::Object> do_static_request(const tonlib_api::raw_getAccountAddress& request);
  static object_ptr<tonlib_api::Object> do_static_request(const tonlib_api::testWallet_getAccountAddress& request);
  static object_ptr<tonlib_api::Object> do_static_request(const tonlib_api::wallet_getAccountAddress& request);
  static object_ptr<tonlib_api::Object> do_static_request(const tonlib_api::wallet_v3_getAccountAddress& request);
  static object_ptr<tonlib_api::Object> do_static_request(const tonlib_api::testGiver_getAccountAddress& request);
  static object_ptr<tonlib_api::Object> do_static_request(const tonlib_api::packAccountAddress& request);
  static object_ptr<tonlib_api::Object> do_static_request(const tonlib_api::unpackAccountAddress& request);
  static object_ptr<tonlib_api::Object> do_static_request(tonlib_api::options_validateConfig& request);
  static object_ptr<tonlib_api::Object> do_static_request(tonlib_api::getBip39Hints& request);

  static object_ptr<tonlib_api::Object> do_static_request(tonlib_api::setLogStream& request);
  static object_ptr<tonlib_api::Object> do_static_request(const tonlib_api::getLogStream& request);
  static object_ptr<tonlib_api::Object> do_static_request(const tonlib_api::setLogVerbosityLevel& request);
  static object_ptr<tonlib_api::Object> do_static_request(const tonlib_api::setLogTagVerbosityLevel& request);
  static object_ptr<tonlib_api::Object> do_static_request(const tonlib_api::getLogVerbosityLevel& request);
  static object_ptr<tonlib_api::Object> do_static_request(const tonlib_api::getLogTagVerbosityLevel& request);
  static object_ptr<tonlib_api::Object> do_static_request(const tonlib_api::getLogTags& request);
  static object_ptr<tonlib_api::Object> do_static_request(const tonlib_api::addLogMessage& request);

  static object_ptr<tonlib_api::Object> do_static_request(const tonlib_api::encrypt& request);
  static object_ptr<tonlib_api::Object> do_static_request(const tonlib_api::decrypt& request);
  static object_ptr<tonlib_api::Object> do_static_request(const tonlib_api::kdf& request);

  template <class P>
  td::Status do_request(const tonlib_api::runTests& request, P&&);
  template <class P>
  td::Status do_request(const tonlib_api::raw_getAccountAddress& request, P&&);
  template <class P>
  td::Status do_request(const tonlib_api::testWallet_getAccountAddress& request, P&&);
  template <class P>
  td::Status do_request(const tonlib_api::wallet_getAccountAddress& request, P&&);
  template <class P>
  td::Status do_request(const tonlib_api::wallet_v3_getAccountAddress& request, P&&);
  template <class P>
  td::Status do_request(const tonlib_api::testGiver_getAccountAddress& request, P&&);
  template <class P>
  td::Status do_request(const tonlib_api::packAccountAddress& request, P&&);
  template <class P>
  td::Status do_request(const tonlib_api::unpackAccountAddress& request, P&&);
  template <class P>
  td::Status do_request(const tonlib_api::options_validateConfig& request, P&&);
  template <class P>
  td::Status do_request(tonlib_api::getBip39Hints& request, P&&);

  template <class P>
  td::Status do_request(tonlib_api::setLogStream& request, P&&);
  template <class P>
  td::Status do_request(const tonlib_api::getLogStream& request, P&&);
  template <class P>
  td::Status do_request(const tonlib_api::setLogVerbosityLevel& request, P&&);
  template <class P>
  td::Status do_request(const tonlib_api::setLogTagVerbosityLevel& request, P&&);
  template <class P>
  td::Status do_request(const tonlib_api::getLogVerbosityLevel& request, P&&);
  template <class P>
  td::Status do_request(const tonlib_api::getLogTagVerbosityLevel& request, P&&);
  template <class P>
  td::Status do_request(const tonlib_api::getLogTags& request, P&&);
  template <class P>
  td::Status do_request(const tonlib_api::addLogMessage& request, P&&);

  template <class P>
  td::Status do_request(const tonlib_api::encrypt& request, P&&);
  template <class P>
  td::Status do_request(const tonlib_api::decrypt& request, P&&);
  template <class P>
  td::Status do_request(const tonlib_api::kdf& request, P&&);

  template <class T, class P>
  void make_request(T&& request, P&& promise) {
    auto status = do_request(std::forward<T>(request), std::move(promise));
    if (status.is_error()) {
      promise.operator()(std::move(status));
    }
  }

  struct FullConfig {
    Config config;
    td::optional<Config> o_master_config;
    bool use_callbacks_for_network;
    bool ignore_cache;
    td::uint32 wallet_id;
  };
  static td::Result<FullConfig> validate_config(tonlib_api::object_ptr<tonlib_api::config> config);
  void set_config(FullConfig config);
  td::Status do_request(const tonlib_api::init& request, td::Promise<object_ptr<tonlib_api::ok>>&& promise);
  td::Status do_request(const tonlib_api::close& request, td::Promise<object_ptr<tonlib_api::ok>>&& promise);
  td::Status do_request(tonlib_api::options_setConfig& request, td::Promise<object_ptr<tonlib_api::ok>>&& promise);

  td::Status do_request(const tonlib_api::raw_sendMessage& request, td::Promise<object_ptr<tonlib_api::ok>>&& promise);
  td::Status do_request(const tonlib_api::raw_createAndSendMessage& request,
                        td::Promise<object_ptr<tonlib_api::ok>>&& promise);
  td::Status do_request(const tonlib_api::raw_createQuery& request,
                        td::Promise<object_ptr<tonlib_api::query_info>>&& promise);

  td::Status do_request(tonlib_api::raw_getAccountState& request,
                        td::Promise<object_ptr<tonlib_api::raw_accountState>>&& promise);
  td::Status do_request(tonlib_api::raw_getTransactions& request,
                        td::Promise<object_ptr<tonlib_api::raw_transactions>>&& promise);

  td::Status do_request(const tonlib_api::testWallet_init& request, td::Promise<object_ptr<tonlib_api::ok>>&& promise);
  td::Status do_request(const tonlib_api::testWallet_sendGrams& request,
                        td::Promise<object_ptr<tonlib_api::sendGramsResult>>&& promise);
  td::Status do_request(tonlib_api::testWallet_getAccountState& request,
                        td::Promise<object_ptr<tonlib_api::testWallet_accountState>>&& promise);

  td::Status do_request(const tonlib_api::wallet_init& request, td::Promise<object_ptr<tonlib_api::ok>>&& promise);
  td::Status do_request(const tonlib_api::wallet_sendGrams& request,
                        td::Promise<object_ptr<tonlib_api::sendGramsResult>>&& promise);
  td::Status do_request(tonlib_api::wallet_getAccountState& request,
                        td::Promise<object_ptr<tonlib_api::wallet_accountState>>&& promise);

  td::Status do_request(const tonlib_api::testGiver_getAccountState& request,
                        td::Promise<object_ptr<tonlib_api::testGiver_accountState>>&& promise);
  td::Status do_request(const tonlib_api::testGiver_sendGrams& request,
                        td::Promise<object_ptr<tonlib_api::sendGramsResult>>&& promise);

  td::Status do_request(const tonlib_api::generic_getAccountState& request,
                        td::Promise<object_ptr<tonlib_api::generic_AccountState>>&& promise);
  td::Status do_request(tonlib_api::generic_sendGrams& request,
                        td::Promise<object_ptr<tonlib_api::sendGramsResult>>&& promise);

  td::Status do_request(tonlib_api::sync& request, td::Promise<object_ptr<tonlib_api::ok>>&& promise);

  td::Status do_request(const tonlib_api::createNewKey& request, td::Promise<object_ptr<tonlib_api::key>>&& promise);
  td::Status do_request(const tonlib_api::exportKey& request,
                        td::Promise<object_ptr<tonlib_api::exportedKey>>&& promise);
  td::Status do_request(const tonlib_api::deleteKey& request, td::Promise<object_ptr<tonlib_api::ok>>&& promise);
  td::Status do_request(const tonlib_api::deleteAllKeys& request, td::Promise<object_ptr<tonlib_api::ok>>&& promise);
  td::Status do_request(const tonlib_api::importKey& request, td::Promise<object_ptr<tonlib_api::key>>&& promise);

  td::Status do_request(const tonlib_api::exportPemKey& request,
                        td::Promise<object_ptr<tonlib_api::exportedPemKey>>&& promise);
  td::Status do_request(const tonlib_api::importPemKey& request, td::Promise<object_ptr<tonlib_api::key>>&& promise);

  td::Status do_request(const tonlib_api::exportEncryptedKey& request,
                        td::Promise<object_ptr<tonlib_api::exportedEncryptedKey>>&& promise);
  td::Status do_request(const tonlib_api::importEncryptedKey& request,
                        td::Promise<object_ptr<tonlib_api::key>>&& promise);

  td::Status do_request(const tonlib_api::changeLocalPassword& request,
                        td::Promise<object_ptr<tonlib_api::key>>&& promise);

  td::Status do_request(const tonlib_api::onLiteServerQueryResult& request,
                        td::Promise<object_ptr<tonlib_api::ok>>&& promise);
  td::Status do_request(const tonlib_api::onLiteServerQueryError& request,
                        td::Promise<object_ptr<tonlib_api::ok>>&& promise);

  td::int64 next_query_id_{0};
  std::map<td::int64, td::unique_ptr<Query>> queries_;
  td::int64 register_query(td::unique_ptr<Query> query);
  td::Result<tonlib_api::object_ptr<tonlib_api::query_info>> get_query_info(td::int64 id);
  void finish_create_query(td::Result<td::unique_ptr<Query>> r_query,
                           td::Promise<object_ptr<tonlib_api::query_info>>&& promise);
  void finish_send_query(td::Result<td::unique_ptr<Query>> r_query,
                         td::Promise<object_ptr<tonlib_api::sendGramsResult>>&& promise);
  void query_estimate_fees(td::int64 id, bool ignore_chksig, td::Result<LastConfigState> r_state,
                           td::Promise<object_ptr<tonlib_api::query_fees>>&& promise);

  td::Status do_request(const tonlib_api::query_getInfo& request,
                        td::Promise<object_ptr<tonlib_api::query_info>>&& promise);
  td::Status do_request(const tonlib_api::query_estimateFees& request,
                        td::Promise<object_ptr<tonlib_api::query_fees>>&& promise);
  td::Status do_request(const tonlib_api::query_send& request, td::Promise<object_ptr<tonlib_api::ok>>&& promise);
  td::Status do_request(tonlib_api::query_forget& request, td::Promise<object_ptr<tonlib_api::ok>>&& promise);

  td::Status do_request(tonlib_api::generic_createSendGramsQuery& request,
                        td::Promise<object_ptr<tonlib_api::query_info>>&& promise);

  td::int64 next_smc_id_{0};
  std::map<td::int64, td::unique_ptr<AccountState>> smcs_;

  td::int64 register_smc(td::unique_ptr<AccountState> smc);
  td::Result<tonlib_api::object_ptr<tonlib_api::smc_info>> get_smc_info(td::int64 id);
  void finish_load_smc(td::unique_ptr<AccountState> query, td::Promise<object_ptr<tonlib_api::smc_info>>&& promise);
  td::Status do_request(const tonlib_api::smc_load& request, td::Promise<object_ptr<tonlib_api::smc_info>>&& promise);
  td::Status do_request(const tonlib_api::smc_getCode& request,
                        td::Promise<object_ptr<tonlib_api::tvm_cell>>&& promise);
  td::Status do_request(const tonlib_api::smc_getData& request,
                        td::Promise<object_ptr<tonlib_api::tvm_cell>>&& promise);
  td::Status do_request(const tonlib_api::smc_getState& request,
                        td::Promise<object_ptr<tonlib_api::tvm_cell>>&& promise);

  td::Status do_request(const tonlib_api::smc_runGetMethod& request,
                        td::Promise<object_ptr<tonlib_api::smc_runResult>>&& promise);

  td::Status do_request(int_api::GetAccountState request, td::Promise<td::unique_ptr<AccountState>>&&);
  td::Status do_request(int_api::GetPrivateKey request, td::Promise<KeyStorage::PrivateKey>&&);
  td::Status do_request(int_api::SendMessage request, td::Promise<td::Unit>&& promise);

  td::Status do_request(const tonlib_api::liteServer_getInfo& request,
                        td::Promise<object_ptr<tonlib_api::liteServer_info>>&& promise);

  void proxy_request(td::int64 query_id, std::string data);

  friend class TonlibQueryActor;
};
}  // namespace tonlib
