//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/ConnectionState.h"
#include "td/telegram/td_api.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"

namespace td {

class Td;

class ConnectionStateManager final : public Actor {
 public:
  ConnectionStateManager(Td *td, ActorShared<> parent);

  void get_current_state(vector<td_api::object_ptr<td_api::Update>> &updates) const;

 private:
  void tear_down() final;

  void start_up() final;

  void on_connection_state_changed(ConnectionState new_state);

  ConnectionState connection_state_ = ConnectionState::Empty;

  Td *td_;
  ActorShared<> parent_;
};

}  // namespace td
