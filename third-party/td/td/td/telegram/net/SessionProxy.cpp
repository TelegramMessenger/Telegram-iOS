//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/net/SessionProxy.h"

#include "td/telegram/Global.h"
#include "td/telegram/net/AuthKeyState.h"
#include "td/telegram/net/ConnectionCreator.h"
#include "td/telegram/net/DcId.h"
#include "td/telegram/net/NetQueryDispatcher.h"
#include "td/telegram/net/Session.h"
#include "td/telegram/Td.h"
#include "td/telegram/TdDb.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UniqueId.h"

#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/format.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/logging.h"
#include "td/utils/Promise.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Time.h"
#include "td/utils/tl_helpers.h"
#include "td/utils/tl_parsers.h"

namespace td {

namespace mtproto {
class RawConnection;
}  // namespace mtproto

class SessionCallback final : public Session::Callback {
 public:
  SessionCallback(ActorShared<SessionProxy> parent, DcId dc_id, bool allow_media_only, bool is_media, uint32 hash)
      : parent_(std::move(parent))
      , dc_id_(dc_id)
      , allow_media_only_(allow_media_only)
      , is_media_(is_media)
      , hash_(hash) {
  }

  void on_failed() final {
    send_closure(parent_, &SessionProxy::on_failed);
  }
  void on_closed() final {
    send_closure(parent_, &SessionProxy::on_closed);
  }
  void request_raw_connection(unique_ptr<mtproto::AuthData> auth_data,
                              Promise<unique_ptr<mtproto::RawConnection>> promise) final {
    send_closure(G()->connection_creator(), &ConnectionCreator::request_raw_connection, dc_id_, allow_media_only_,
                 is_media_, std::move(promise), hash_, std::move(auth_data));
  }

  void on_tmp_auth_key_updated(mtproto::AuthKey auth_key) final {
    send_closure(parent_, &SessionProxy::on_tmp_auth_key_updated, std::move(auth_key));
  }

  void on_server_salt_updated(std::vector<mtproto::ServerSalt> server_salts) final {
    send_closure(parent_, &SessionProxy::on_server_salt_updated, std::move(server_salts));
  }

  void on_update(BufferSlice &&update, uint64 auth_key_id) final {
    TlBufferParser parser(&update);
    auto updates = telegram_api::Updates::fetch(parser);
    parser.fetch_end();
    if (parser.get_error()) {
      LOG(ERROR) << "Failed to fetch update: " << parser.get_error() << format::as_hex_dump<4>(update.as_slice());
      updates = nullptr;
    }
    send_closure_later(G()->td(), &Td::on_update, std::move(updates), auth_key_id);
  }

  void on_result(NetQueryPtr query) final {
    if (UniqueId::extract_type(query->id()) != UniqueId::BindKey) {
      send_closure(parent_, &SessionProxy::on_query_finished);
    }
    G()->net_query_dispatcher().dispatch(std::move(query));
  }

 private:
  ActorShared<SessionProxy> parent_;
  DcId dc_id_;
  bool allow_media_only_ = false;
  bool is_media_ = false;
  uint32 hash_ = 0;
};

SessionProxy::SessionProxy(unique_ptr<Callback> callback, std::shared_ptr<AuthDataShared> shared_auth_data,
                           bool is_primary, bool is_main, bool allow_media_only, bool is_media, bool use_pfs,
                           bool persist_tmp_auth_key, bool is_cdn, bool need_destroy_auth_key)
    : callback_(std::move(callback))
    , auth_data_(std::move(shared_auth_data))
    , is_primary_(is_primary)
    , is_main_(is_main)
    , allow_media_only_(allow_media_only)
    , is_media_(is_media)
    , use_pfs_(use_pfs)
    , persist_tmp_auth_key_(use_pfs && persist_tmp_auth_key)
    , is_cdn_(is_cdn)
    , need_destroy_auth_key_(need_destroy_auth_key) {
}

void SessionProxy::start_up() {
  class Listener final : public AuthDataShared::Listener {
   public:
    explicit Listener(ActorShared<SessionProxy> session_proxy) : session_proxy_(std::move(session_proxy)) {
    }
    bool notify() final {
      if (!session_proxy_.is_alive()) {
        return false;
      }
      send_closure(session_proxy_, &SessionProxy::update_auth_key_state);
      return true;
    }

   private:
    ActorShared<SessionProxy> session_proxy_;
  };
  auth_key_state_ = get_auth_key_state(auth_data_->get_auth_key());
  auth_data_->add_auth_key_listener(make_unique<Listener>(actor_shared(this)));

  string saved_auth_key = G()->td_db()->get_binlog_pmc()->get(tmp_auth_key_key());
  if (!saved_auth_key.empty()) {
    if (persist_tmp_auth_key_) {
      unserialize(tmp_auth_key_, saved_auth_key).ensure();
      if (tmp_auth_key_.expires_at() < Time::now()) {
        tmp_auth_key_ = {};
      } else {
        LOG(WARNING) << "Loaded tmp_auth_key " << tmp_auth_key_.id() << ": " << get_auth_key_state(tmp_auth_key_);
      }
    } else {
      LOG(WARNING) << "Drop saved tmp_auth_key";
      G()->td_db()->get_binlog_pmc()->erase(tmp_auth_key_key());
    }
  }
  open_session();
}

void SessionProxy::tear_down() {
  for (auto &query : pending_queries_) {
    query->resend();
    callback_->on_query_finished();
    G()->net_query_dispatcher().dispatch(std::move(query));
  }
  pending_queries_.clear();
}

void SessionProxy::send(NetQueryPtr query) {
  if (query->auth_flag() == NetQuery::AuthFlag::On && auth_key_state_ != AuthKeyState::OK) {
    query->debug(PSTRING() << get_name() << ": wait for auth");
    pending_queries_.emplace_back(std::move(query));
    return;
  }
  open_session(true);
  query->debug(PSTRING() << get_name() << ": sent to session");
  send_closure(session_, &Session::send, std::move(query));
}

void SessionProxy::update_main_flag(bool is_main) {
  if (is_main_ == is_main) {
    return;
  }
  LOG(INFO) << "Update is_main to " << is_main;
  is_main_ = is_main;
  close_session("update_main_flag");
  open_session();
}

void SessionProxy::on_failed() {
  if (session_generation_ != get_link_token()) {
    return;
  }
  close_session("on_failed");
  open_session();
}

void SessionProxy::update_mtproto_header() {
  close_session("update_mtproto_header");
  open_session();
}

void SessionProxy::on_closed() {
}

void SessionProxy::close_session(const char *source) {
  LOG(INFO) << "Close session from " << source;
  send_closure(std::move(session_), &Session::close);
  session_generation_++;
}

void SessionProxy::open_session(bool force) {
  if (!session_.empty()) {
    return;
  }
  // There are several assumption that make this code OK
  // 1. All unauthorized query will be sent into the same SessionProxy
  // 2. All authorized query are delayed before we have authorization
  // So only one SessionProxy will be active before we have authorization key
  auto should_open = [&] {
    if (force) {
      return true;
    }
    if (need_destroy_auth_key_) {
      return auth_key_state_ != AuthKeyState::Empty;
    }
    if (is_main_) {
      return true;
    }
    if (auth_key_state_ != AuthKeyState::OK) {
      return false;
    }
    return !pending_queries_.empty();
  }();
  if (!should_open) {
    return;
  }

  CHECK(session_.empty());
  auto dc_id = auth_data_->dc_id();
  string name = PSTRING() << "Session" << get_name().substr(Slice("SessionProxy").size());
  string hash_string = PSTRING() << name << " " << dc_id.get_raw_id() << " " << allow_media_only_;
  auto hash = Hash<string>()(hash_string);
  int32 raw_dc_id = dc_id.get_raw_id();
  int32 int_dc_id = raw_dc_id;
  if (G()->is_test_dc()) {
    int_dc_id += 10000;
  }
  if (allow_media_only_ && !is_cdn_) {
    int_dc_id = -int_dc_id;
  }
  session_ = create_actor<Session>(
      name,
      make_unique<SessionCallback>(actor_shared(this, session_generation_), dc_id, allow_media_only_, is_media_, hash),
      auth_data_, raw_dc_id, int_dc_id, is_primary_, is_main_, use_pfs_, persist_tmp_auth_key_, is_cdn_,
      need_destroy_auth_key_, tmp_auth_key_, server_salts_);
}

void SessionProxy::update_auth_key_state() {
  auto old_auth_key_state = auth_key_state_;
  auth_key_state_ = get_auth_key_state(auth_data_->get_auth_key());
  if (auth_key_state_ != old_auth_key_state && old_auth_key_state == AuthKeyState::OK) {
    close_session("update_auth_key_state");
  }
  open_session();
  if (session_.empty() || auth_key_state_ != AuthKeyState::OK) {
    return;
  }
  for (auto &query : pending_queries_) {
    query->debug(PSTRING() << get_name() << ": sent to session");
    send_closure(session_, &Session::send, std::move(query));
  }
  pending_queries_.clear();
}

void SessionProxy::on_tmp_auth_key_updated(mtproto::AuthKey auth_key) {
  LOG(WARNING) << "Have tmp_auth_key " << auth_key.id() << ": " << get_auth_key_state(auth_key);
  tmp_auth_key_ = std::move(auth_key);
  if (persist_tmp_auth_key_) {
    G()->td_db()->get_binlog_pmc()->set(tmp_auth_key_key(), serialize(tmp_auth_key_));
  }
}

string SessionProxy::tmp_auth_key_key() const {
  return PSTRING() << "tmp_auth" << get_name();
}

void SessionProxy::on_server_salt_updated(std::vector<mtproto::ServerSalt> server_salts) {
  server_salts_ = std::move(server_salts);
}

void SessionProxy::on_query_finished() {
  callback_->on_query_finished();
}

}  // namespace td
