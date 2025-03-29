//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/OnlineManager.h"

#include "td/telegram/AuthManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/OptionManager.h"
#include "td/telegram/StateManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UpdatesManager.h"
#include "td/telegram/UserManager.h"

#include "td/utils/buffer.h"
#include "td/utils/logging.h"
#include "td/utils/Random.h"
#include "td/utils/Status.h"

namespace td {

class UpdateStatusQuery final : public Td::ResultHandler {
  bool is_offline_;

 public:
  NetQueryRef send(bool is_offline) {
    is_offline_ = is_offline;
    auto net_query = G()->net_query_creator().create(telegram_api::account_updateStatus(is_offline));
    auto result = net_query.get_weak();
    send_query(std::move(net_query));
    return result;
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_updateStatus>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.ok();
    LOG(INFO) << "Receive result for UpdateStatusQuery: " << result;
    td_->online_manager_->on_update_status_success(!is_offline_);
  }

  void on_error(Status status) final {
    if (status.code() != NetQuery::Canceled && !G()->is_expected_error(status)) {
      LOG(ERROR) << "Receive error for UpdateStatusQuery: " << status;
    }
  }
};

OnlineManager::OnlineManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
}

void OnlineManager::tear_down() {
  parent_.reset();
}

void OnlineManager::start_up() {
  init();
}

void OnlineManager::init() {
  if (is_online_) {
    on_online_updated(false /*ignored*/, true);
  }
  if (td_->auth_manager_->is_bot()) {
    set_is_bot_online(true);
  }
}

void OnlineManager::on_online_timeout_callback(void *online_manager_ptr) {
  if (G()->close_flag()) {
    return;
  }

  auto online_manager = static_cast<OnlineManager *>(online_manager_ptr);
  send_closure_later(online_manager->actor_id(online_manager), &OnlineManager::on_online_updated, false, true);
}

void OnlineManager::on_ping_server_timeout_callback(void *online_manager_ptr) {
  if (G()->close_flag()) {
    return;
  }

  auto online_manager = static_cast<OnlineManager *>(online_manager_ptr);
  send_closure_later(online_manager->actor_id(online_manager), &OnlineManager::on_ping_server_timeout);
}

void OnlineManager::on_online_updated(bool force, bool send_update) {
  if (G()->close_flag() || !td_->auth_manager_->is_authorized() || td_->auth_manager_->is_bot()) {
    return;
  }
  if (force || is_online_) {
    td_->user_manager_->set_my_online_status(is_online_, send_update, true);
    if (!update_status_query_.empty()) {
      LOG(INFO) << "Cancel previous update status query";
      cancel_query(update_status_query_);
    }
    update_status_query_ = td_->create_handler<UpdateStatusQuery>()->send(!is_online_);
  }
  if (is_online_) {
    online_timeout_.set_callback(std::move(on_online_timeout_callback));
    online_timeout_.set_callback_data(static_cast<void *>(this));
    online_timeout_.set_timeout_in(static_cast<double>(G()->get_option_integer("online_update_period_ms", 210000)) *
                                   1e-3);
  } else {
    online_timeout_.cancel_timeout();
  }
}

void OnlineManager::on_update_status_success(bool is_online) {
  if (is_online == is_online_) {
    if (!update_status_query_.empty()) {
      update_status_query_ = NetQueryRef();
    }
    td_->user_manager_->set_my_online_status(is_online_, true, false);
  }
}

bool OnlineManager::is_online() const {
  return is_online_;
}

void OnlineManager::set_is_online(bool is_online) {
  if (is_online == is_online_) {
    return;
  }

  is_online_ = is_online;
  if (td_->auth_manager_ != nullptr) {  // postpone if there is no AuthManager yet
    on_online_updated(true, true);
  }
}

void OnlineManager::set_is_bot_online(bool is_bot_online) {
  ping_server_timeout_.set_callback(std::move(on_ping_server_timeout_callback));
  ping_server_timeout_.set_callback_data(static_cast<void *>(this));
  ping_server_timeout_.set_timeout_in(PING_SERVER_TIMEOUT + Random::fast(0, PING_SERVER_TIMEOUT / 5));

  if (td_->option_manager_->get_option_integer("session_count") > 1) {
    is_bot_online = false;
  }

  if (is_bot_online == is_bot_online_) {
    return;
  }

  is_bot_online_ = is_bot_online;
  send_closure(G()->state_manager(), &StateManager::on_online, is_bot_online_);
}

void OnlineManager::on_ping_server_timeout() {
  if (G()->close_flag() || td_->updates_manager_ == nullptr || !td_->auth_manager_->is_authorized()) {
    return;
  }
  td_->updates_manager_->ping_server();
  set_is_bot_online(false);
}

}  // namespace td
