//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/net/NetQuery.h"

#include "td/actor/actor.h"
#include "td/actor/Timeout.h"

#include "td/utils/common.h"

namespace td {

class Td;

class OnlineManager final : public Actor {
 public:
  OnlineManager(Td *td, ActorShared<> parent);

  void init();

  void on_online_updated(bool force, bool send_update);

  void on_update_status_success(bool is_online);

  bool is_online() const;

  void set_is_online(bool is_online);

  void set_is_bot_online(bool is_bot_online);

 private:
  static constexpr int32 PING_SERVER_TIMEOUT = 300;

  void tear_down() final;

  void start_up() final;

  static void on_online_timeout_callback(void *online_manager_ptr);

  static void on_ping_server_timeout_callback(void *online_manager_ptr);

  void on_ping_server_timeout();

  Td *td_;
  ActorShared<> parent_;

  bool is_online_ = false;
  bool is_bot_online_ = false;
  NetQueryRef update_status_query_;

  Timeout online_timeout_;
  Timeout ping_server_timeout_;
};

}  // namespace td
