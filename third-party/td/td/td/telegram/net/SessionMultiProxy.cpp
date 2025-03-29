//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/net/SessionMultiProxy.h"

#include "td/telegram/net/SessionProxy.h"

#include "td/utils/common.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Random.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"

namespace td {

SessionMultiProxy::~SessionMultiProxy() = default;

SessionMultiProxy::SessionMultiProxy(int32 session_count, std::shared_ptr<AuthDataShared> shared_auth_data,
                                     bool is_primary, bool is_main, bool use_pfs, bool allow_media_only, bool is_media,
                                     bool is_cdn)
    : session_count_(session_count)
    , auth_data_(std::move(shared_auth_data))
    , is_primary_(is_primary)
    , is_main_(is_main)
    , use_pfs_(use_pfs)
    , allow_media_only_(allow_media_only)
    , is_media_(is_media)
    , is_cdn_(is_cdn) {
  if (allow_media_only_) {
    CHECK(is_media_);
  }
}

void SessionMultiProxy::send(NetQueryPtr query) {
  size_t pos = 0;
  if (query->auth_flag() == NetQuery::AuthFlag::On) {
    size_t session_rand = query->session_rand();
    if (session_rand) {
      pos = session_rand % sessions_.size();
    } else {
      size_t equal_count = 1;
      int min_query_count = sessions_[pos].query_count;
      for (size_t i = 1; i < sessions_.size(); i++) {
        if (sessions_[i].query_count < min_query_count) {
          pos = i;
          min_query_count = sessions_[pos].query_count;
          equal_count = 1;
        } else if (sessions_[i].query_count == min_query_count) {
          equal_count++;
          if (Random::fast_uint32() % equal_count == 0) {
            pos = i;
          }
        }
      }
    }
  }
  // query->debug(PSTRING() << get_name() << ": send to proxy #" << pos);
  sessions_[pos].query_count++;
  send_closure(sessions_[pos].proxy, &SessionProxy::send, std::move(query));
}

void SessionMultiProxy::update_main_flag(bool is_main) {
  LOG(INFO) << "Update is_main to " << is_main;
  is_main_ = is_main;
  for (auto &session : sessions_) {
    send_closure(session.proxy, &SessionProxy::update_main_flag, is_main);
  }
}

void SessionMultiProxy::destroy_auth_key() {
  update_options(1, false, true);
}

void SessionMultiProxy::update_session_count(int32 session_count) {
  update_options(session_count, use_pfs_, need_destroy_auth_key_);
}

void SessionMultiProxy::update_use_pfs(bool use_pfs) {
  update_options(session_count_, use_pfs, need_destroy_auth_key_);
}

void SessionMultiProxy::update_options(int32 session_count, bool use_pfs, bool need_destroy_auth_key) {
  if (need_destroy_auth_key_) {
    LOG(INFO) << "Ignore session option changes while destroying auth key";
    return;
  }

  bool is_changed = false;

  session_count = clamp(session_count, 1, 100);
  if (session_count != session_count_) {
    session_count_ = session_count;
    LOG(INFO) << "Update session_count to " << session_count_;
    is_changed = true;
  }

  if (use_pfs != use_pfs_) {
    bool old_pfs_flag = get_pfs_flag();
    use_pfs_ = use_pfs;
    if (old_pfs_flag != get_pfs_flag()) {
      LOG(INFO) << "Update use_pfs to " << use_pfs_;
      is_changed = true;
    }
  }

  if (need_destroy_auth_key) {
    need_destroy_auth_key_ = need_destroy_auth_key;
    is_changed = true;
    LOG(WARNING) << "Destroy auth key";
  }

  if (is_changed) {
    init();
  }
}

void SessionMultiProxy::update_mtproto_header() {
  for (auto &session : sessions_) {
    send_closure_later(session.proxy, &SessionProxy::update_mtproto_header);
  }
}

void SessionMultiProxy::start_up() {
  init();
}

bool SessionMultiProxy::get_pfs_flag() const {
  return use_pfs_ && !is_cdn_;
}

void SessionMultiProxy::init() {
  sessions_generation_++;
  sessions_.clear();
  if (is_main_ && session_count_ > 1) {
    LOG(WARNING) << tag("session_count", session_count_);
  }
  for (int32 i = 0; i < session_count_; i++) {
    string name = PSTRING() << "Session" << get_name().substr(Slice("SessionMulti").size())
                            << format::cond(session_count_ > 1, format::concat("#", i));

    SessionInfo info;
    class Callback final : public SessionProxy::Callback {
     public:
      Callback(ActorId<SessionMultiProxy> parent, uint32 generation, int32 session_id)
          : parent_(parent), generation_(generation), session_id_(session_id) {
      }
      void on_query_finished() final {
        send_closure(parent_, &SessionMultiProxy::on_query_finished, generation_, session_id_);
      }

     private:
      ActorId<SessionMultiProxy> parent_;
      uint32 generation_;
      int32 session_id_;
    };
    info.proxy =
        create_actor<SessionProxy>(name, make_unique<Callback>(actor_id(this), sessions_generation_, i), auth_data_,
                                   is_primary_, is_main_, allow_media_only_, is_media_, get_pfs_flag(),
                                   session_count_ > 1 && is_primary_, is_cdn_, need_destroy_auth_key_ && i == 0);
    sessions_.push_back(std::move(info));
  }
}

void SessionMultiProxy::on_query_finished(uint32 generation, int session_id) {
  if (generation != sessions_generation_) {
    return;
  }
  CHECK(static_cast<size_t>(session_id) < sessions_.size());
  auto &query_count = sessions_[session_id].query_count;
  CHECK(query_count > 0);
  query_count--;
}

}  // namespace td
