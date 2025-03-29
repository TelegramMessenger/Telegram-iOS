//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/RecentDialogList.h"

#include "td/telegram/AccessRights.h"
#include "td/telegram/ChatManager.h"
#include "td/telegram/DialogListId.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/FolderId.h"
#include "td/telegram/Global.h"
#include "td/telegram/MessagesManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/td_api.h"
#include "td/telegram/TdDb.h"
#include "td/telegram/UserManager.h"

#include "td/actor/MultiPromise.h"

#include "td/utils/algorithm.h"
#include "td/utils/misc.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"

namespace td {

RecentDialogList::RecentDialogList(Td *td, const char *name, size_t max_size)
    : td_(td), name_(name), max_size_(max_size) {
  register_actor(PSLICE() << name << "_chats", this).release();
}

string RecentDialogList::get_binlog_key() const {
  return PSTRING() << name_ << "_dialog_usernames_and_ids";
}

void RecentDialogList::save_dialogs() const {
  if (!is_loaded_) {
    return;
  }
  CHECK(removed_dialog_ids_.empty());

  SliceBuilder sb;
  for (auto &dialog_id : dialog_ids_) {
    sb << ',';
    if (!G()->use_chat_info_database()) {
      // if there is no dialog info database, prefer to save dialogs by username
      string username;
      switch (dialog_id.get_type()) {
        case DialogType::User:
          if (!td_->user_manager_->is_user_contact(dialog_id.get_user_id())) {
            username = td_->user_manager_->get_user_first_username(dialog_id.get_user_id());
          }
          break;
        case DialogType::Chat:
          break;
        case DialogType::Channel:
          username = td_->chat_manager_->get_channel_first_username(dialog_id.get_channel_id());
          break;
        case DialogType::SecretChat:
          break;
        case DialogType::None:
        default:
          UNREACHABLE();
      }
      if (!username.empty() && username.find(',') == string::npos) {
        sb << '@' << username;
        continue;
      }
    }
    sb << dialog_id.get();
  }
  auto result = sb.as_cslice();
  if (!result.empty()) {
    result.remove_prefix(1);
  }
  G()->td_db()->get_binlog_pmc()->set(get_binlog_key(), result.str());
}

void RecentDialogList::load_dialogs(Promise<Unit> &&promise) {
  if (is_loaded_) {
    return promise.set_value(Unit());
  }

  load_list_queries_.push_back(std::move(promise));
  if (load_list_queries_.size() != 1) {
    return;
  }

  auto found_dialogs = full_split(G()->td_db()->get_binlog_pmc()->get(get_binlog_key()), ',');
  MultiPromiseActorSafe mpas{"LoadRecentDialogListMultiPromiseActor"};
  mpas.add_promise(PromiseCreator::lambda([actor_id = actor_id(this), found_dialogs](Unit) mutable {
    send_closure(actor_id, &RecentDialogList::on_load_dialogs, std::move(found_dialogs));
  }));
  mpas.set_ignore_errors(true);
  auto lock = mpas.get_promise();

  vector<DialogId> dialog_ids;
  for (auto &found_dialog : found_dialogs) {
    if (found_dialog[0] == '@') {
      td_->dialog_manager_->search_public_dialog(found_dialog, false, mpas.get_promise());
    } else {
      dialog_ids.push_back(DialogId(to_integer<int64>(found_dialog)));
    }
  }
  if (!dialog_ids.empty()) {
    if (G()->use_chat_info_database() && !G()->td_db()->was_dialog_db_created()) {
      td_->messages_manager_->load_dialogs(
          std::move(dialog_ids),
          PromiseCreator::lambda(
              [promise = mpas.get_promise()](vector<DialogId> dialog_ids) mutable { promise.set_value(Unit()); }));
    } else {
      td_->messages_manager_->get_dialogs_from_list(
          DialogListId(FolderId::main()), 102,
          PromiseCreator::lambda([promise = mpas.get_promise()](td_api::object_ptr<td_api::chats> &&chats) mutable {
            promise.set_value(Unit());
          }));
      td_->user_manager_->search_contacts("", 1, mpas.get_promise());
    }
  }

  lock.set_value(Unit());
}

void RecentDialogList::on_load_dialogs(vector<string> &&found_dialogs) {
  auto promises = std::move(load_list_queries_);
  CHECK(!promises.empty());

  if (G()->close_flag()) {
    return fail_promises(promises, Global::request_aborted_error());
  }

  auto newly_found_dialogs = std::move(dialog_ids_);
  reset_to_empty(dialog_ids_);

  for (auto it = found_dialogs.rbegin(); it != found_dialogs.rend(); ++it) {
    DialogId dialog_id;
    if ((*it)[0] == '@') {
      dialog_id = td_->dialog_manager_->get_resolved_dialog_by_username(it->substr(1));
    } else {
      dialog_id = DialogId(to_integer<int64>(*it));
    }
    if (dialog_id.is_valid() && td::contains(removed_dialog_ids_, dialog_id) == 0 &&
        td_->dialog_manager_->have_dialog_info(dialog_id) &&
        td_->dialog_manager_->have_input_peer(dialog_id, true, AccessRights::Read)) {
      td_->dialog_manager_->force_create_dialog(dialog_id, "recent dialog");
      do_add_dialog(dialog_id);
    }
  }
  for (auto it = newly_found_dialogs.rbegin(); it != newly_found_dialogs.rend(); ++it) {
    do_add_dialog(*it);
  }
  is_loaded_ = true;
  removed_dialog_ids_.clear();
  if (!newly_found_dialogs.empty()) {
    save_dialogs();
  }

  set_promises(promises);
}

void RecentDialogList::add_dialog(DialogId dialog_id) {
  if (!is_loaded_) {
    load_dialogs(Promise<Unit>());
  }
  if (do_add_dialog(dialog_id)) {
    save_dialogs();
  }
}

bool RecentDialogList::do_add_dialog(DialogId dialog_id) {
  if (!dialog_ids_.empty() && dialog_ids_[0] == dialog_id) {
    return false;
  }

  add_to_top(dialog_ids_, max_size_, dialog_id);

  td::remove(removed_dialog_ids_, dialog_id);
  return true;
}

void RecentDialogList::remove_dialog(DialogId dialog_id) {
  if (!dialog_id.is_valid()) {
    return;
  }
  if (!is_loaded_) {
    load_dialogs(Promise<Unit>());
  }
  if (td::remove(dialog_ids_, dialog_id)) {
    save_dialogs();
  } else if (!is_loaded_ && !td::contains(removed_dialog_ids_, dialog_id)) {
    removed_dialog_ids_.push_back(dialog_id);
  }
}

void RecentDialogList::update_dialogs() {
  CHECK(is_loaded_);
  vector<DialogId> dialog_ids;
  for (auto dialog_id : dialog_ids_) {
    if (!td_->messages_manager_->have_dialog(dialog_id)) {
      continue;
    }
    switch (dialog_id.get_type()) {
      case DialogType::User:
        // always keep
        break;
      case DialogType::Chat: {
        auto channel_id = td_->chat_manager_->get_chat_migrated_to_channel_id(dialog_id.get_chat_id());
        if (channel_id.is_valid() && td_->messages_manager_->have_dialog(DialogId(channel_id))) {
          dialog_id = DialogId(channel_id);
        }
        break;
      }
      case DialogType::Channel:
        // always keep
        break;
      case DialogType::SecretChat:
        if (td_->messages_manager_->is_deleted_secret_chat(dialog_id)) {
          dialog_id = DialogId();
        }
        break;
      case DialogType::None:
      default:
        UNREACHABLE();
        break;
    }
    if (dialog_id.is_valid()) {
      dialog_ids.push_back(dialog_id);
    }
  }

  if (dialog_ids != dialog_ids_) {
    dialog_ids_ = std::move(dialog_ids);
    save_dialogs();
  }
}

std::pair<int32, vector<DialogId>> RecentDialogList::get_dialogs(int32 limit, Promise<Unit> &&promise) {
  load_dialogs(std::move(promise));
  if (!is_loaded_) {
    return {};
  }

  update_dialogs();

  CHECK(limit >= 0);
  auto total_count = narrow_cast<int32>(dialog_ids_.size());
  return {total_count, vector<DialogId>(dialog_ids_.begin(), dialog_ids_.begin() + min(limit, total_count))};
}

void RecentDialogList::clear_dialogs() {
  if (dialog_ids_.empty() && is_loaded_) {
    return;
  }

  is_loaded_ = true;
  dialog_ids_.clear();
  removed_dialog_ids_.clear();
  save_dialogs();
}

}  // namespace td
