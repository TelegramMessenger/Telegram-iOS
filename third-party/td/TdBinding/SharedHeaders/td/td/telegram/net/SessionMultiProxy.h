//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/net/AuthDataShared.h"
#include "td/telegram/net/NetQuery.h"

#include "td/actor/actor.h"

#include <memory>

namespace td {

class SessionProxy;

class SessionMultiProxy final : public Actor {
 public:
  SessionMultiProxy(int32 session_count, std::shared_ptr<AuthDataShared> shared_auth_data, bool is_primary,
                    bool is_main, bool use_pfs, bool allow_media_only, bool is_media, bool is_cdn);
  SessionMultiProxy(const SessionMultiProxy &) = delete;
  SessionMultiProxy &operator=(const SessionMultiProxy &) = delete;
  ~SessionMultiProxy() final;

  void send(NetQueryPtr query);
  void update_main_flag(bool is_main);

  void update_session_count(int32 session_count);
  void update_use_pfs(bool use_pfs);
  void update_options(int32 session_count, bool use_pfs, bool need_destroy_auth_key);
  void update_mtproto_header();

  void destroy_auth_key();

 private:
  int32 session_count_ = 0;
  std::shared_ptr<AuthDataShared> auth_data_;
  const bool is_primary_;
  bool is_main_ = false;
  bool use_pfs_ = false;
  bool allow_media_only_ = false;
  bool is_media_ = false;
  bool is_cdn_ = false;
  bool need_destroy_auth_key_ = false;
  struct SessionInfo {
    ActorOwn<SessionProxy> proxy;
    int query_count{0};
  };
  uint32 sessions_generation_{0};
  std::vector<SessionInfo> sessions_;

  void start_up() final;
  void init();

  bool get_pfs_flag() const;

  void on_query_finished(uint32 generation, int session_id);
};

}  // namespace td
