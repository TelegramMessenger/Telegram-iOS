//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/ConnectionStateManager.h"

#include "td/telegram/Global.h"
#include "td/telegram/StateManager.h"
#include "td/telegram/Td.h"

#include "td/utils/logging.h"

namespace td {

ConnectionStateManager::ConnectionStateManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
}

void ConnectionStateManager::tear_down() {
  parent_.reset();
}

void ConnectionStateManager::start_up() {
  class StateCallback final : public StateManager::Callback {
   public:
    explicit StateCallback(ActorId<ConnectionStateManager> parent) : parent_(std::move(parent)) {
    }
    bool on_state(ConnectionState state) final {
      send_closure(parent_, &ConnectionStateManager::on_connection_state_changed, state);
      return parent_.is_alive();
    }

   private:
    ActorId<ConnectionStateManager> parent_;
  };
  send_closure(td_->state_manager_, &StateManager::add_callback, make_unique<StateCallback>(actor_id(this)));
}

void ConnectionStateManager::on_connection_state_changed(ConnectionState new_state) {
  if (G()->close_flag()) {
    return;
  }
  if (new_state == connection_state_) {
    LOG(ERROR) << "State manager sent update about unchanged state " << static_cast<int32>(new_state);
    return;
  }
  connection_state_ = new_state;

  send_closure(G()->td(), &Td::send_update, get_update_connection_state_object(connection_state_));
}

void ConnectionStateManager::get_current_state(vector<td_api::object_ptr<td_api::Update>> &updates) const {
  if (connection_state_ == ConnectionState::Empty) {
    return;
  }

  updates.push_back(get_update_connection_state_object(connection_state_));
}

}  // namespace td
