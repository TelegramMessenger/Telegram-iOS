//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/CommonDialogManager.h"

#include "td/telegram/ChatManager.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserManager.h"

#include "td/utils/algorithm.h"
#include "td/utils/buffer.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Status.h"
#include "td/utils/Time.h"

#include <algorithm>

namespace td {

class GetCommonDialogsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  UserId user_id_;
  int64 offset_chat_id_ = 0;

 public:
  explicit GetCommonDialogsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(UserId user_id, tl_object_ptr<telegram_api::InputUser> &&input_user, int64 offset_chat_id, int32 limit) {
    user_id_ = user_id;
    offset_chat_id_ = offset_chat_id;

    send_query(G()->net_query_creator().create(
        telegram_api::messages_getCommonChats(std::move(input_user), offset_chat_id, limit)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getCommonChats>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto chats_ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetCommonDialogsQuery: " << to_string(chats_ptr);
    switch (chats_ptr->get_id()) {
      case telegram_api::messages_chats::ID: {
        auto chats = move_tl_object_as<telegram_api::messages_chats>(chats_ptr);
        td_->common_dialog_manager_->on_get_common_dialogs(user_id_, offset_chat_id_, std::move(chats->chats_),
                                                           narrow_cast<int32>(chats->chats_.size()));
        break;
      }
      case telegram_api::messages_chatsSlice::ID: {
        auto chats = move_tl_object_as<telegram_api::messages_chatsSlice>(chats_ptr);
        td_->common_dialog_manager_->on_get_common_dialogs(user_id_, offset_chat_id_, std::move(chats->chats_),
                                                           chats->count_);
        break;
      }
      default:
        UNREACHABLE();
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

CommonDialogManager::CommonDialogManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
}

CommonDialogManager::~CommonDialogManager() {
  Scheduler::instance()->destroy_on_scheduler(G()->get_gc_scheduler_id(), found_common_dialogs_);
}

void CommonDialogManager::tear_down() {
  parent_.reset();
}

void CommonDialogManager::drop_common_dialogs_cache(UserId user_id) {
  auto it = found_common_dialogs_.find(user_id);
  if (it != found_common_dialogs_.end()) {
    it->second.is_outdated = true;
  }
}

std::pair<int32, vector<DialogId>> CommonDialogManager::get_common_dialogs(UserId user_id, DialogId offset_dialog_id,
                                                                           int32 limit, bool force,
                                                                           Promise<Unit> &&promise) {
  auto r_input_user = td_->user_manager_->get_input_user(user_id);
  if (r_input_user.is_error()) {
    promise.set_error(r_input_user.move_as_error());
    return {};
  }

  if (user_id == td_->user_manager_->get_my_id()) {
    promise.set_error(Status::Error(400, "Can't get common chats with self"));
    return {};
  }
  if (limit <= 0) {
    promise.set_error(Status::Error(400, "Parameter limit must be positive"));
    return {};
  }
  if (limit > MAX_GET_DIALOGS) {
    limit = MAX_GET_DIALOGS;
  }

  int64 offset_chat_id = 0;
  switch (offset_dialog_id.get_type()) {
    case DialogType::Chat:
      offset_chat_id = offset_dialog_id.get_chat_id().get();
      break;
    case DialogType::Channel:
      offset_chat_id = offset_dialog_id.get_channel_id().get();
      break;
    case DialogType::None:
      if (offset_dialog_id == DialogId()) {
        break;
      }
    // fallthrough
    case DialogType::User:
    case DialogType::SecretChat:
      promise.set_error(Status::Error(400, "Wrong offset_chat_id"));
      return {};
    default:
      UNREACHABLE();
      break;
  }

  auto it = found_common_dialogs_.find(user_id);
  if (it != found_common_dialogs_.end() && !it->second.dialog_ids.empty()) {
    int32 total_count = it->second.total_count;
    vector<DialogId> &common_dialog_ids = it->second.dialog_ids;
    bool use_cache = (!it->second.is_outdated && it->second.receive_time >= Time::now() - 3600) || force ||
                     offset_chat_id != 0 || common_dialog_ids.size() >= static_cast<size_t>(MAX_GET_DIALOGS);
    // use cache if it is up-to-date, or we required to use it or we can't update it
    if (use_cache) {
      auto offset_it = common_dialog_ids.begin();
      if (offset_dialog_id != DialogId()) {
        offset_it = std::find(common_dialog_ids.begin(), common_dialog_ids.end(), offset_dialog_id);
        if (offset_it == common_dialog_ids.end()) {
          promise.set_error(Status::Error(400, "Wrong offset_chat_id"));
          return {};
        }
        ++offset_it;
      }
      vector<DialogId> result;
      while (result.size() < static_cast<size_t>(limit)) {
        if (offset_it == common_dialog_ids.end()) {
          break;
        }
        auto dialog_id = *offset_it++;
        if (dialog_id == DialogId()) {  // end of the list
          promise.set_value(Unit());
          return {total_count, std::move(result)};
        }
        result.push_back(dialog_id);
      }
      if (result.size() == static_cast<size_t>(limit) || force) {
        promise.set_value(Unit());
        return {total_count, std::move(result)};
      }
    }
  }

  td_->create_handler<GetCommonDialogsQuery>(std::move(promise))
      ->send(user_id, r_input_user.move_as_ok(), offset_chat_id, MAX_GET_DIALOGS);
  return {};
}

void CommonDialogManager::on_get_common_dialogs(UserId user_id, int64 offset_chat_id,
                                                vector<tl_object_ptr<telegram_api::Chat>> &&chats, int32 total_count) {
  CHECK(user_id.is_valid());
  td_->user_manager_->on_update_user_common_chat_count(user_id, total_count);

  auto &common_dialogs = found_common_dialogs_[user_id];
  if (common_dialogs.is_outdated && offset_chat_id == 0 &&
      common_dialogs.dialog_ids.size() < static_cast<size_t>(MAX_GET_DIALOGS)) {
    // drop outdated cache if possible
    common_dialogs = CommonDialogs();
  }
  if (common_dialogs.receive_time == 0) {
    common_dialogs.receive_time = Time::now();
  }
  common_dialogs.is_outdated = false;
  auto &result = common_dialogs.dialog_ids;
  if (!result.empty() && result.back() == DialogId()) {
    return;
  }
  bool is_last = chats.empty() && offset_chat_id == 0;
  for (auto &chat : chats) {
    auto dialog_id = ChatManager::get_dialog_id(chat);
    if (!dialog_id.is_valid()) {
      LOG(ERROR) << "Receive invalid " << to_string(chat);
      continue;
    }
    td_->chat_manager_->on_get_chat(std::move(chat), "on_get_common_dialogs");

    if (!td::contains(result, dialog_id)) {
      td_->dialog_manager_->force_create_dialog(dialog_id, "get common dialogs");
      result.push_back(dialog_id);
    }
  }
  if (result.size() >= static_cast<size_t>(total_count) || is_last) {
    if (result.size() != static_cast<size_t>(total_count)) {
      LOG(ERROR) << "Fix total count of common groups with " << user_id << " from " << total_count << " to "
                 << result.size();
      total_count = narrow_cast<int32>(result.size());
      td_->user_manager_->on_update_user_common_chat_count(user_id, total_count);
    }

    result.emplace_back();
  }
  common_dialogs.total_count = total_count;
}

}  // namespace td
