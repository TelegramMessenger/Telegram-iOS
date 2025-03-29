//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/SuggestedActionManager.h"

#include "td/telegram/AccessRights.h"
#include "td/telegram/ChatManager.h"
#include "td/telegram/ConfigManager.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/logevent/LogEvent.h"
#include "td/telegram/SuggestedAction.hpp"
#include "td/telegram/Td.h"
#include "td/telegram/TdDb.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/algorithm.h"
#include "td/utils/buffer.h"
#include "td/utils/logging.h"

namespace td {

class DismissSuggestionQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;

 public:
  explicit DismissSuggestionQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(SuggestedAction action) {
    dialog_id_ = action.dialog_id_;
    telegram_api::object_ptr<telegram_api::InputPeer> input_peer;
    if (dialog_id_.is_valid()) {
      input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Read);
      CHECK(input_peer != nullptr);
    } else {
      input_peer = telegram_api::make_object<telegram_api::inputPeerEmpty>();
    }

    send_query(G()->net_query_creator().create(
        telegram_api::help_dismissSuggestion(std::move(input_peer), action.get_suggested_action_str())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::help_dismissSuggestion>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    if (dialog_id_.is_valid()) {
      td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "DismissSuggestionQuery");
    }
    promise_.set_error(std::move(status));
  }
};

SuggestedActionManager::SuggestedActionManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
}

void SuggestedActionManager::start_up() {
  auto log_event_string = G()->td_db()->get_binlog_pmc()->get(get_suggested_actions_database_key());
  if (!log_event_string.empty()) {
    vector<SuggestedAction> suggested_actions;
    auto status = log_event_parse(suggested_actions, log_event_string);
    if (status.is_error()) {
      LOG(ERROR) << "Failed to parse suggested actions from binlog: " << status;
      save_suggested_actions();
    } else {
      ::td::update_suggested_actions(suggested_actions_, std::move(suggested_actions));
    }
  }
}

void SuggestedActionManager::hangup() {
  while (!dismiss_suggested_action_queries_.empty()) {
    auto it = dismiss_suggested_action_queries_.begin();
    auto promises = std::move(it->second);
    dismiss_suggested_action_queries_.erase(it);
    fail_promises(promises, Global::request_aborted_error());
  }

  stop();
}

void SuggestedActionManager::tear_down() {
  parent_.reset();
}

void SuggestedActionManager::update_suggested_actions(vector<SuggestedAction> &&suggested_actions) {
  if (!dismiss_suggested_action_queries_.empty()) {
    // do not update suggested actions while dismissing an action
    return;
  }
  if (::td::update_suggested_actions(suggested_actions_, std::move(suggested_actions))) {
    save_suggested_actions();
  }
}

void SuggestedActionManager::hide_suggested_action(SuggestedAction suggested_action) {
  if (remove_suggested_action(suggested_actions_, suggested_action)) {
    save_suggested_actions();
  }
}

void SuggestedActionManager::dismiss_suggested_action(SuggestedAction suggested_action, Promise<Unit> &&promise) {
  auto action_str = suggested_action.get_suggested_action_str();
  if (action_str.empty()) {
    return promise.set_value(Unit());
  }

  auto dialog_id = suggested_action.dialog_id_;
  if (dialog_id != DialogId()) {
    TRY_STATUS_PROMISE(promise, td_->dialog_manager_->check_dialog_access(dialog_id, false, AccessRights::Read,
                                                                          "dismiss_suggested_action"));

    auto it = dialog_suggested_actions_.find(dialog_id);
    if (it == dialog_suggested_actions_.end() || !td::contains(it->second, suggested_action)) {
      return promise.set_value(Unit());
    }
    remove_dialog_suggested_action(suggested_action);
  } else {
    if (!remove_suggested_action(suggested_actions_, suggested_action)) {
      return promise.set_value(Unit());
    }
    save_suggested_actions();
  }

  auto &queries = dismiss_suggested_action_queries_[suggested_action];
  queries.push_back(std::move(promise));
  if (queries.size() == 1) {
    auto query_promise = PromiseCreator::lambda([actor_id = actor_id(this), suggested_action](Result<Unit> result) {
      send_closure(actor_id, &SuggestedActionManager::on_dismiss_suggested_action, suggested_action, std::move(result));
    });
    td_->create_handler<DismissSuggestionQuery>(std::move(query_promise))->send(suggested_action);
  }
}

void SuggestedActionManager::on_dismiss_suggested_action(SuggestedAction suggested_action, Result<Unit> &&result) {
  if (G()->close_flag()) {
    return;
  }

  auto it = dismiss_suggested_action_queries_.find(suggested_action);
  CHECK(it != dismiss_suggested_action_queries_.end());
  auto promises = std::move(it->second);
  CHECK(!promises.empty());
  dismiss_suggested_action_queries_.erase(it);

  if (result.is_error()) {
    return fail_promises(promises, result.move_as_error());
  }

  if (suggested_action.dialog_id_ != DialogId()) {
    remove_dialog_suggested_action(suggested_action);
  } else {
    if (remove_suggested_action(suggested_actions_, suggested_action)) {
      save_suggested_actions();
    }
    send_closure(G()->config_manager(), &ConfigManager::reget_app_config, Promise<Unit>());
  }

  set_promises(promises);
}

string SuggestedActionManager::get_suggested_actions_database_key() {
  return "suggested_actions";
}

void SuggestedActionManager::save_suggested_actions() {
  if (suggested_actions_.empty()) {
    G()->td_db()->get_binlog_pmc()->erase(get_suggested_actions_database_key());
  } else {
    G()->td_db()->get_binlog_pmc()->set(get_suggested_actions_database_key(),
                                        log_event_store(suggested_actions_).as_slice().str());
  }
}

void SuggestedActionManager::set_dialog_pending_suggestions(DialogId dialog_id, vector<string> &&pending_suggestions) {
  if (!dismiss_suggested_action_queries_.empty()) {
    return;
  }
  auto it = dialog_suggested_actions_.find(dialog_id);
  if (it == dialog_suggested_actions_.end() && !pending_suggestions.empty()) {
    return;
  }
  vector<SuggestedAction> suggested_actions;
  for (auto &action_str : pending_suggestions) {
    SuggestedAction suggested_action(action_str, dialog_id);
    if (!suggested_action.is_empty()) {
      if (suggested_action == SuggestedAction{SuggestedAction::Type::ConvertToGigagroup, dialog_id} &&
          (dialog_id.get_type() != DialogType::Channel ||
           !td_->chat_manager_->can_convert_channel_to_gigagroup(dialog_id.get_channel_id()))) {
        LOG(INFO) << "Skip ConvertToGigagroup suggested action";
      } else {
        suggested_actions.push_back(suggested_action);
      }
    }
  }
  if (it == dialog_suggested_actions_.end()) {
    it = dialog_suggested_actions_.emplace(dialog_id, vector<SuggestedAction>()).first;
  }
  ::td::update_suggested_actions(it->second, std::move(suggested_actions));
  if (it->second.empty()) {
    dialog_suggested_actions_.erase(it);
  }
}

void SuggestedActionManager::remove_dialog_suggested_action(SuggestedAction action) {
  auto it = dialog_suggested_actions_.find(action.dialog_id_);
  if (it == dialog_suggested_actions_.end()) {
    return;
  }
  remove_suggested_action(it->second, action);
  if (it->second.empty()) {
    dialog_suggested_actions_.erase(it);
  }
}

void SuggestedActionManager::get_current_state(vector<td_api::object_ptr<td_api::Update>> &updates) const {
  if (!suggested_actions_.empty()) {
    updates.push_back(get_update_suggested_actions_object(suggested_actions_, {}, "get_current_state"));
  }
  for (const auto &actions : dialog_suggested_actions_) {
    updates.push_back(get_update_suggested_actions_object(actions.second, {}, "get_current_state 2"));
  }
}

}  // namespace td
