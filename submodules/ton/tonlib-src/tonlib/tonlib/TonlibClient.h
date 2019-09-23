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
#include "tonlib/LastBlockStorage.h"

#include "td/actor/actor.h"

namespace tonlib {
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
  Config config_;

  bool use_callbacks_for_network_{false};
  td::actor::ActorId<ExtClientOutbound> ext_client_outbound_;

  // KeyStorage
  KeyStorage key_storage_;
  LastBlockStorage last_block_storage_;

  // network
  td::actor::ActorOwn<ton::adnl::AdnlExtClient> raw_client_;
  td::actor::ActorOwn<LastBlock> raw_last_block_;
  ExtClient client_;

  ExtClientRef get_client_ref();
  void init_ext_client();
  void init_last_block();

  bool is_closing_{false};
  td::uint32 ref_cnt_{1};
  void hangup_shared() override {
    ref_cnt_--;
    try_stop();
  }
  void hangup() override;
  void try_stop() {
    if (is_closing_ && ref_cnt_ == 0) {
      stop();
    }
  }

  void update_last_block_state(LastBlockState state);
  void on_result(td::uint64 id, object_ptr<tonlib_api::Object> response);
  static bool is_static_request(td::int32 id);
  static bool is_uninited_request(td::int32 id);
  template <class T>
  static object_ptr<tonlib_api::Object> do_static_request(const T& request) {
    return tonlib_api::make_object<tonlib_api::error>(400, "Function can't be executed synchronously");
  }
  static object_ptr<tonlib_api::Object> do_static_request(const tonlib_api::runTests& request);
  static object_ptr<tonlib_api::Object> do_static_request(const tonlib_api::raw_getAccountAddress& request);
  static object_ptr<tonlib_api::Object> do_static_request(const tonlib_api::testWallet_getAccountAddress& request);
  static object_ptr<tonlib_api::Object> do_static_request(const tonlib_api::testGiver_getAccountAddress& request);
  static object_ptr<tonlib_api::Object> do_static_request(tonlib_api::getBip39Hints& request);
  template <class T, class P>
  td::Status do_request(const T& request, P&& promise) {
    return td::Status::Error(400, "Function is unsupported");
  }

  td::Status set_config(std::string config);

  td::Status do_request(const tonlib_api::init& request, td::Promise<object_ptr<tonlib_api::ok>>&& promise);
  td::Status do_request(const tonlib_api::close& request, td::Promise<object_ptr<tonlib_api::ok>>&& promise);
  td::Status do_request(const tonlib_api::options_setConfig& request,
                        td::Promise<object_ptr<tonlib_api::ok>>&& promise);

  td::Status do_request(const tonlib_api::raw_sendMessage& request, td::Promise<object_ptr<tonlib_api::ok>>&& promise);
  td::Status do_request(tonlib_api::raw_getAccountState& request,
                        td::Promise<object_ptr<tonlib_api::raw_accountState>>&& promise);
  td::Status do_request(tonlib_api::raw_getTransactions& request,
                        td::Promise<object_ptr<tonlib_api::raw_transactions>>&& promise);

  td::Status do_request(const tonlib_api::testWallet_init& request, td::Promise<object_ptr<tonlib_api::ok>>&& promise);
  td::Status do_request(const tonlib_api::testWallet_sendGrams& request,
                        td::Promise<object_ptr<tonlib_api::ok>>&& promise);
  td::Status do_request(tonlib_api::testWallet_getAccountState& request,
                        td::Promise<object_ptr<tonlib_api::testWallet_accountState>>&& promise);

  td::Status do_request(const tonlib_api::testGiver_getAccountState& request,
                        td::Promise<object_ptr<tonlib_api::testGiver_accountState>>&& promise);
  td::Status do_request(const tonlib_api::testGiver_sendGrams& request,
                        td::Promise<object_ptr<tonlib_api::ok>>&& promise);

  td::Status do_request(const tonlib_api::generic_getAccountState& request,
                        td::Promise<object_ptr<tonlib_api::generic_AccountState>>&& promise);
  td::Status do_request(tonlib_api::generic_sendGrams& request, td::Promise<object_ptr<tonlib_api::ok>>&& promise);

  td::Status do_request(const tonlib_api::createNewKey& request, td::Promise<object_ptr<tonlib_api::key>>&& promise);
  td::Status do_request(const tonlib_api::exportKey& request,
                        td::Promise<object_ptr<tonlib_api::exportedKey>>&& promise);
  td::Status do_request(const tonlib_api::deleteKey& request, td::Promise<object_ptr<tonlib_api::ok>>&& promise);
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

  void proxy_request(td::int64 query_id, std::string data);
};
}  // namespace tonlib
