//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/DialogFilter.h"

#include "td/telegram/ChatManager.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/MessagesManager.h"
#include "td/telegram/misc.h"
#include "td/telegram/Td.h"
#include "td/telegram/UserManager.h"

#include "td/utils/algorithm.h"
#include "td/utils/emoji.h"
#include "td/utils/FlatHashSet.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"

#include <algorithm>
#include <utility>

namespace td {

int32 DialogFilter::get_max_filter_dialogs() {
  return narrow_cast<int32>(G()->get_option_integer("chat_folder_chosen_chat_count_max", 100));
}

unique_ptr<DialogFilter> DialogFilter::get_dialog_filter(
    telegram_api::object_ptr<telegram_api::DialogFilter> filter_ptr, bool with_id) {
  FlatHashSet<DialogId, DialogIdHash> added_dialog_ids;
  switch (filter_ptr->get_id()) {
    case telegram_api::dialogFilter::ID: {
      auto filter = telegram_api::move_object_as<telegram_api::dialogFilter>(filter_ptr);
      DialogFilterId dialog_filter_id(filter->id_);
      if (with_id) {
        if (!dialog_filter_id.is_valid()) {
          LOG(ERROR) << "Receive invalid " << to_string(filter);
          return nullptr;
        }
      } else {
        dialog_filter_id = DialogFilterId();
      }
      auto dialog_filter = make_unique<DialogFilter>();
      dialog_filter->dialog_filter_id_ = dialog_filter_id;
      dialog_filter->title_ = get_formatted_text(nullptr, std::move(filter->title_), true, false, "dialogFilter");
      keep_only_custom_emoji(dialog_filter->title_);
      dialog_filter->animate_title_ = !filter->title_noanimate_;
      dialog_filter->emoji_ = std::move(filter->emoticon_);
      dialog_filter->color_id_ = (filter->flags_ & telegram_api::dialogFilter::COLOR_MASK) != 0 ? filter->color_ : -1;
      dialog_filter->pinned_dialog_ids_ = InputDialogId::get_input_dialog_ids(filter->pinned_peers_, &added_dialog_ids);
      dialog_filter->included_dialog_ids_ =
          InputDialogId::get_input_dialog_ids(filter->include_peers_, &added_dialog_ids);
      dialog_filter->excluded_dialog_ids_ =
          InputDialogId::get_input_dialog_ids(filter->exclude_peers_, &added_dialog_ids);
      auto flags = filter->flags_;
      dialog_filter->exclude_muted_ = (flags & telegram_api::dialogFilter::EXCLUDE_MUTED_MASK) != 0;
      dialog_filter->exclude_read_ = (flags & telegram_api::dialogFilter::EXCLUDE_READ_MASK) != 0;
      dialog_filter->exclude_archived_ = (flags & telegram_api::dialogFilter::EXCLUDE_ARCHIVED_MASK) != 0;
      dialog_filter->include_contacts_ = (flags & telegram_api::dialogFilter::CONTACTS_MASK) != 0;
      dialog_filter->include_non_contacts_ = (flags & telegram_api::dialogFilter::NON_CONTACTS_MASK) != 0;
      dialog_filter->include_bots_ = (flags & telegram_api::dialogFilter::BOTS_MASK) != 0;
      dialog_filter->include_groups_ = (flags & telegram_api::dialogFilter::GROUPS_MASK) != 0;
      dialog_filter->include_channels_ = (flags & telegram_api::dialogFilter::BROADCASTS_MASK) != 0;
      if (!is_valid_color_id(dialog_filter->color_id_)) {
        LOG(ERROR) << "Receive color " << dialog_filter->color_id_;
        dialog_filter->color_id_ = -1;
      }
      return dialog_filter;
    }
    case telegram_api::dialogFilterChatlist::ID: {
      auto filter = telegram_api::move_object_as<telegram_api::dialogFilterChatlist>(filter_ptr);
      DialogFilterId dialog_filter_id(filter->id_);
      if (with_id) {
        if (!dialog_filter_id.is_valid()) {
          LOG(ERROR) << "Receive invalid " << to_string(filter);
          return nullptr;
        }
      } else {
        dialog_filter_id = DialogFilterId();
      }
      auto dialog_filter = make_unique<DialogFilter>();
      dialog_filter->dialog_filter_id_ = dialog_filter_id;
      dialog_filter->title_ =
          get_formatted_text(nullptr, std::move(filter->title_), true, false, "dialogFilterChatlist");
      keep_only_custom_emoji(dialog_filter->title_);
      dialog_filter->animate_title_ = !filter->title_noanimate_;
      dialog_filter->emoji_ = std::move(filter->emoticon_);
      dialog_filter->color_id_ =
          (filter->flags_ & telegram_api::dialogFilterChatlist::COLOR_MASK) != 0 ? filter->color_ : -1;
      dialog_filter->pinned_dialog_ids_ = InputDialogId::get_input_dialog_ids(filter->pinned_peers_, &added_dialog_ids);
      dialog_filter->included_dialog_ids_ =
          InputDialogId::get_input_dialog_ids(filter->include_peers_, &added_dialog_ids);
      dialog_filter->is_shareable_ = true;
      dialog_filter->has_my_invites_ = filter->has_my_invites_;
      if (!is_valid_color_id(dialog_filter->color_id_)) {
        LOG(ERROR) << "Receive color " << dialog_filter->color_id_;
        dialog_filter->color_id_ = -1;
      }
      return dialog_filter;
    }
    default:
      LOG(ERROR) << "Ignore " << to_string(filter_ptr);
      return nullptr;
  }
}

Result<unique_ptr<DialogFilter>> DialogFilter::create_dialog_filter(Td *td, DialogFilterId dialog_filter_id,
                                                                    td_api::object_ptr<td_api::chatFolder> filter) {
  if (filter == nullptr) {
    return Status::Error(400, "Chat folder must be non-empty");
  }
  if (filter->name_ == nullptr || filter->name_->text_ == nullptr) {
    return Status::Error(400, "Chat folder name must be non-empty");
  }
  string icon_name;
  if (filter->icon_ != nullptr) {
    icon_name = std::move(filter->icon_->name_);
    if (!clean_input_string(icon_name)) {
      return Status::Error(400, "Strings must be encoded in UTF-8");
    }
  }

  TRY_RESULT(title, get_formatted_text(td, td->dialog_manager_->get_my_dialog_id(), std::move(filter->name_->text_),
                                       false, false, true, false));
  constexpr size_t MAX_TITLE_LENGTH = 12;  // server-side limit for dialog filter title
  title.text = clean_name(title.text, MAX_TITLE_LENGTH);
  if (title.text.empty()) {
    return Status::Error(400, "Title must be non-empty");
  }
  keep_only_custom_emoji(title);

  auto dialog_filter = make_unique<DialogFilter>();
  dialog_filter->dialog_filter_id_ = dialog_filter_id;

  FlatHashSet<int64> added_dialog_ids;
  auto add_chats = [td, &added_dialog_ids](vector<InputDialogId> &input_dialog_ids, const vector<int64> &chat_ids) {
    for (const auto &chat_id : chat_ids) {
      if (chat_id == 0 || !added_dialog_ids.insert(chat_id).second) {
        // do not allow duplicate chat_ids
        continue;
      }

      input_dialog_ids.push_back(td->dialog_manager_->get_input_dialog_id(DialogId(chat_id)));
    }
  };
  add_chats(dialog_filter->pinned_dialog_ids_, filter->pinned_chat_ids_);
  add_chats(dialog_filter->included_dialog_ids_, filter->included_chat_ids_);
  add_chats(dialog_filter->excluded_dialog_ids_, filter->excluded_chat_ids_);

  dialog_filter->title_ = std::move(title);
  dialog_filter->animate_title_ = filter->name_->animate_custom_emoji_;
  dialog_filter->emoji_ = get_emoji_by_icon_name(icon_name);
  if (dialog_filter->emoji_.empty() && !icon_name.empty()) {
    return Status::Error(400, "Invalid icon name specified");
  }
  dialog_filter->color_id_ = filter->color_id_;
  if (!is_valid_color_id(dialog_filter->color_id_)) {
    return Status::Error(400, "Invalid color identifier specified");
  }
  dialog_filter->exclude_muted_ = filter->exclude_muted_;
  dialog_filter->exclude_read_ = filter->exclude_read_;
  dialog_filter->exclude_archived_ = filter->exclude_archived_;
  dialog_filter->include_contacts_ = filter->include_contacts_;
  dialog_filter->include_non_contacts_ = filter->include_non_contacts_;
  dialog_filter->include_bots_ = filter->include_bots_;
  dialog_filter->include_groups_ = filter->include_groups_;
  dialog_filter->include_channels_ = filter->include_channels_;
  dialog_filter->is_shareable_ = filter->is_shareable_;
  dialog_filter->has_my_invites_ = false;

  TRY_STATUS(dialog_filter->check_limits());
  dialog_filter->sort_input_dialog_ids(td, "create_dialog_filter");

  Status status;
  dialog_filter->for_each_dialog(
      [messages_manager = td->messages_manager_.get(), &status](const InputDialogId &input_dialog_id) {
        if (status.is_error()) {
          return;
        }
        status = messages_manager->can_add_dialog_to_filter(input_dialog_id.get_dialog_id());
      });
  if (status.is_error()) {
    return std::move(status);
  }

  return std::move(dialog_filter);
}

void DialogFilter::set_dialog_is_pinned(InputDialogId input_dialog_id, bool is_pinned) {
  auto dialog_id = input_dialog_id.get_dialog_id();
  if (is_pinned) {
    pinned_dialog_ids_.insert(pinned_dialog_ids_.begin(), input_dialog_id);
    InputDialogId::remove(included_dialog_ids_, dialog_id);
    InputDialogId::remove(excluded_dialog_ids_, dialog_id);
  } else {
    bool is_removed = InputDialogId::remove(pinned_dialog_ids_, dialog_id);
    CHECK(is_removed);
    included_dialog_ids_.push_back(input_dialog_id);
  }
}

void DialogFilter::set_pinned_dialog_ids(vector<InputDialogId> &&input_dialog_ids) {
  FlatHashSet<DialogId, DialogIdHash> new_pinned_dialog_ids;
  for (auto input_dialog_id : input_dialog_ids) {
    auto dialog_id = input_dialog_id.get_dialog_id();
    CHECK(dialog_id.is_valid());
    new_pinned_dialog_ids.insert(dialog_id);
  }

  auto old_pinned_dialog_ids = std::move(pinned_dialog_ids_);
  pinned_dialog_ids_ = std::move(input_dialog_ids);
  auto is_new_pinned = [&new_pinned_dialog_ids](InputDialogId input_dialog_id) {
    return new_pinned_dialog_ids.count(input_dialog_id.get_dialog_id()) > 0;
  };
  td::remove_if(old_pinned_dialog_ids, is_new_pinned);
  td::remove_if(included_dialog_ids_, is_new_pinned);
  td::remove_if(excluded_dialog_ids_, is_new_pinned);
  append(included_dialog_ids_, old_pinned_dialog_ids);
}

void DialogFilter::include_dialog(InputDialogId input_dialog_id) {
  included_dialog_ids_.push_back(input_dialog_id);
  InputDialogId::remove(excluded_dialog_ids_, input_dialog_id.get_dialog_id());
}

void DialogFilter::remove_secret_chat_dialog_ids() {
  auto remove_secret_chats = [](vector<InputDialogId> &input_dialog_ids) {
    td::remove_if(input_dialog_ids, [](InputDialogId input_dialog_id) {
      return input_dialog_id.get_dialog_id().get_type() == DialogType::SecretChat;
    });
  };
  remove_secret_chats(pinned_dialog_ids_);
  remove_secret_chats(included_dialog_ids_);
  remove_secret_chats(excluded_dialog_ids_);
}

void DialogFilter::remove_dialog_id(DialogId dialog_id) {
  InputDialogId::remove(pinned_dialog_ids_, dialog_id);
  InputDialogId::remove(included_dialog_ids_, dialog_id);
  InputDialogId::remove(excluded_dialog_ids_, dialog_id);
}

bool DialogFilter::is_empty(bool for_server) const {
  if (include_contacts_ || include_non_contacts_ || include_bots_ || include_groups_ || include_channels_) {
    return false;
  }

  if (for_server) {
    vector<InputDialogId> empty_input_dialog_ids;
    return InputDialogId::are_equivalent(pinned_dialog_ids_, empty_input_dialog_ids) &&
           InputDialogId::are_equivalent(included_dialog_ids_, empty_input_dialog_ids);
  } else {
    return pinned_dialog_ids_.empty() && included_dialog_ids_.empty();
  }
}

bool DialogFilter::is_dialog_pinned(DialogId dialog_id) const {
  return InputDialogId::contains(pinned_dialog_ids_, dialog_id);
}

bool DialogFilter::is_dialog_included(DialogId dialog_id) const {
  return InputDialogId::contains(included_dialog_ids_, dialog_id) || is_dialog_pinned(dialog_id);
}

bool DialogFilter::can_include_dialog(DialogId dialog_id) const {
  if (is_dialog_included(dialog_id)) {
    return false;
  }

  if (included_dialog_ids_.size() + pinned_dialog_ids_.size() < narrow_cast<size_t>(get_max_filter_dialogs())) {
    // fast path
    return true;
  }

  auto new_dialog_filter = make_unique<DialogFilter>(*this);
  new_dialog_filter->include_dialog(InputDialogId(dialog_id));
  return new_dialog_filter->check_limits().is_ok();
}

Status DialogFilter::check_limits() const {
  auto get_server_dialog_count = [](const vector<InputDialogId> &input_dialog_ids) {
    int32 result = 0;
    for (auto &input_dialog_id : input_dialog_ids) {
      if (input_dialog_id.get_dialog_id().get_type() != DialogType::SecretChat) {
        result++;
      }
    }
    return result;
  };

  auto excluded_server_dialog_count = get_server_dialog_count(excluded_dialog_ids_);
  auto included_server_dialog_count = get_server_dialog_count(included_dialog_ids_);
  auto pinned_server_dialog_count = get_server_dialog_count(pinned_dialog_ids_);

  auto excluded_secret_dialog_count = static_cast<int32>(excluded_dialog_ids_.size()) - excluded_server_dialog_count;
  auto included_secret_dialog_count = static_cast<int32>(included_dialog_ids_.size()) - included_server_dialog_count;
  auto pinned_secret_dialog_count = static_cast<int32>(pinned_dialog_ids_.size()) - pinned_server_dialog_count;

  auto limit = get_max_filter_dialogs();
  if (excluded_server_dialog_count > limit || excluded_secret_dialog_count > limit) {
    return Status::Error(400, "The maximum number of excluded chats exceeded");
  }
  if (included_server_dialog_count > limit || included_secret_dialog_count > limit) {
    return Status::Error(400, "The maximum number of included chats exceeded");
  }
  if (included_server_dialog_count + pinned_server_dialog_count > limit ||
      included_secret_dialog_count + pinned_secret_dialog_count > limit) {
    return Status::Error(400, "The maximum number of pinned chats exceeded");
  }

  if (is_empty(false)) {
    return Status::Error(400, "Folder must contain at least 1 chat");
  }
  if (is_shareable_) {
    if (!excluded_dialog_ids_.empty()) {
      return Status::Error(400, "Shareable folders can't have excluded chats");
    }
    if (include_contacts_ || include_non_contacts_ || include_bots_ || include_groups_ || include_channels_ ||
        exclude_archived_ || exclude_read_ || exclude_muted_) {
      return Status::Error(400, "Shareable folders can't have chat filters");
    }
  } else if (has_my_invites_) {
    LOG(ERROR) << "Have shareable folder with invite links";
  }

  if (include_contacts_ && include_non_contacts_ && include_bots_ && include_groups_ && include_channels_ &&
      exclude_archived_ && !exclude_read_ && !exclude_muted_) {
    return Status::Error(400, "Folder must be different from the main chat list");
  }

  return Status::OK();
}

void DialogFilter::update_from(const DialogFilter &old_filter) {
  has_my_invites_ = old_filter.has_my_invites_;
}

string DialogFilter::get_emoji_by_icon_name(const string &icon_name) {
  init_icon_names();
  auto it = icon_name_to_emoji_.find(icon_name);
  if (it != icon_name_to_emoji_.end()) {
    return it->second;
  }
  return string();
}

string DialogFilter::get_icon_name_by_emoji(const string &emoji) {
  init_icon_names();
  auto it = emoji_to_icon_name_.find(emoji);
  if (it != emoji_to_icon_name_.end()) {
    return it->second;
  }
  return string();
}

string DialogFilter::get_icon_name() const {
  return get_icon_name_by_emoji(emoji_);
}

string DialogFilter::get_chosen_or_default_icon_name() const {
  auto icon_name = get_icon_name();
  if (!icon_name.empty()) {
    return icon_name;
  }

  if (!pinned_dialog_ids_.empty() || !included_dialog_ids_.empty() || !excluded_dialog_ids_.empty()) {
    return "Custom";
  }

  if (include_contacts_ || include_non_contacts_) {
    if (!include_bots_ && !include_groups_ && !include_channels_) {
      return "Private";
    }
  } else {
    if (!include_bots_ && !include_channels_) {
      if (!include_groups_) {
        // just in case
        return "Custom";
      }
      return "Groups";
    }
    if (!include_bots_ && !include_groups_) {
      return "Channels";
    }
    if (!include_groups_ && !include_channels_) {
      return "Bots";
    }
  }
  if (exclude_read_ && !exclude_muted_) {
    return "Unread";
  }
  if (exclude_muted_ && !exclude_read_) {
    return "Unmuted";
  }
  return "Custom";
}

string DialogFilter::get_default_icon_name(const td_api::chatFolder *filter) {
  if (filter->icon_ != nullptr && !filter->icon_->name_.empty() &&
      !get_emoji_by_icon_name(filter->icon_->name_).empty()) {
    return filter->icon_->name_;
  }

  if (!filter->pinned_chat_ids_.empty() || !filter->included_chat_ids_.empty() || !filter->excluded_chat_ids_.empty()) {
    return "Custom";
  }

  if (filter->include_contacts_ || filter->include_non_contacts_) {
    if (!filter->include_bots_ && !filter->include_groups_ && !filter->include_channels_) {
      return "Private";
    }
  } else {
    if (!filter->include_bots_ && !filter->include_channels_) {
      if (!filter->include_groups_) {
        // just in case
        return "Custom";
      }
      return "Groups";
    }
    if (!filter->include_bots_ && !filter->include_groups_) {
      return "Channels";
    }
    if (!filter->include_groups_ && !filter->include_channels_) {
      return "Bots";
    }
  }
  if (filter->exclude_read_ && !filter->exclude_muted_) {
    return "Unread";
  }
  if (filter->exclude_muted_ && !filter->exclude_read_) {
    return "Unmuted";
  }
  return "Custom";
}

telegram_api::object_ptr<telegram_api::DialogFilter> DialogFilter::get_input_dialog_filter() const {
  if (is_shareable_) {
    int32 flags = telegram_api::dialogFilterChatlist::EMOTICON_MASK;
    if (color_id_ != -1) {
      flags |= telegram_api::dialogFilterChatlist::COLOR_MASK;
    }
    if (has_my_invites_) {
      flags |= telegram_api::dialogFilterChatlist::HAS_MY_INVITES_MASK;
    }
    if (!animate_title_) {
      flags |= telegram_api::dialogFilterChatlist::TITLE_NOANIMATE_MASK;
    }
    return telegram_api::make_object<telegram_api::dialogFilterChatlist>(
        flags, false /*ignored*/, false /*ignored*/, dialog_filter_id_.get(),
        get_input_text_with_entities(nullptr, title_, "dialogFilterChatlist"), emoji_, color_id_,
        InputDialogId::get_input_peers(pinned_dialog_ids_), InputDialogId::get_input_peers(included_dialog_ids_));
  }
  int32 flags = telegram_api::dialogFilter::EMOTICON_MASK;
  if (!animate_title_) {
    flags |= telegram_api::dialogFilter::TITLE_NOANIMATE_MASK;
  }
  if (color_id_ != -1) {
    flags |= telegram_api::dialogFilter::COLOR_MASK;
  }
  if (exclude_muted_) {
    flags |= telegram_api::dialogFilter::EXCLUDE_MUTED_MASK;
  }
  if (exclude_read_) {
    flags |= telegram_api::dialogFilter::EXCLUDE_READ_MASK;
  }
  if (exclude_archived_) {
    flags |= telegram_api::dialogFilter::EXCLUDE_ARCHIVED_MASK;
  }
  if (include_contacts_) {
    flags |= telegram_api::dialogFilter::CONTACTS_MASK;
  }
  if (include_non_contacts_) {
    flags |= telegram_api::dialogFilter::NON_CONTACTS_MASK;
  }
  if (include_bots_) {
    flags |= telegram_api::dialogFilter::BOTS_MASK;
  }
  if (include_groups_) {
    flags |= telegram_api::dialogFilter::GROUPS_MASK;
  }
  if (include_channels_) {
    flags |= telegram_api::dialogFilter::BROADCASTS_MASK;
  }

  return telegram_api::make_object<telegram_api::dialogFilter>(
      flags, false /*ignored*/, false /*ignored*/, false /*ignored*/, false /*ignored*/, false /*ignored*/,
      false /*ignored*/, false /*ignored*/, false /*ignored*/, false /*ignored*/, dialog_filter_id_.get(),
      get_input_text_with_entities(nullptr, title_, "dialogFilter"), emoji_, color_id_,
      InputDialogId::get_input_peers(pinned_dialog_ids_), InputDialogId::get_input_peers(included_dialog_ids_),
      InputDialogId::get_input_peers(excluded_dialog_ids_));
}

td_api::object_ptr<td_api::chatFolder> DialogFilter::get_chat_folder_object(
    const vector<DialogId> &unknown_dialog_ids) const {
  auto get_chat_ids = [unknown_dialog_ids](const vector<InputDialogId> &input_dialog_ids) {
    vector<int64> chat_ids;
    chat_ids.reserve(input_dialog_ids.size());
    for (auto &input_dialog_id : input_dialog_ids) {
      auto dialog_id = input_dialog_id.get_dialog_id();
      if (!td::contains(unknown_dialog_ids, dialog_id)) {
        chat_ids.push_back(dialog_id.get());
      }
    }
    return chat_ids;
  };

  td_api::object_ptr<td_api::chatFolderIcon> icon;
  auto icon_name = get_icon_name();
  if (!icon_name.empty()) {
    icon = td_api::make_object<td_api::chatFolderIcon>(icon_name);
  }
  auto name =
      td_api::make_object<td_api::chatFolderName>(get_formatted_text_object(nullptr, title_, true, -1), animate_title_);
  return td_api::make_object<td_api::chatFolder>(
      std::move(name), std::move(icon), color_id_, is_shareable_, get_chat_ids(pinned_dialog_ids_),
      get_chat_ids(included_dialog_ids_), get_chat_ids(excluded_dialog_ids_), exclude_muted_, exclude_read_,
      exclude_archived_, include_contacts_, include_non_contacts_, include_bots_, include_groups_, include_channels_);
}

td_api::object_ptr<td_api::chatFolderInfo> DialogFilter::get_chat_folder_info_object() const {
  auto name =
      td_api::make_object<td_api::chatFolderName>(get_formatted_text_object(nullptr, title_, true, -1), animate_title_);
  return td_api::make_object<td_api::chatFolderInfo>(
      dialog_filter_id_.get(), std::move(name),
      td_api::make_object<td_api::chatFolderIcon>(get_chosen_or_default_icon_name()), color_id_, is_shareable_,
      has_my_invites_);
}

void DialogFilter::for_each_dialog(std::function<void(const InputDialogId &)> callback) const {
  for (auto input_dialog_ids : {&pinned_dialog_ids_, &excluded_dialog_ids_, &included_dialog_ids_}) {
    for (const auto &input_dialog_id : *input_dialog_ids) {
      callback(input_dialog_id);
    }
  }
}

// merges changes from old_server_filter to new_server_filter in old_filter
unique_ptr<DialogFilter> DialogFilter::merge_dialog_filter_changes(const DialogFilter *old_filter,
                                                                   const DialogFilter *old_server_filter,
                                                                   const DialogFilter *new_server_filter) {
  CHECK(old_filter != nullptr);
  CHECK(old_server_filter != nullptr);
  CHECK(new_server_filter != nullptr);
  CHECK(old_filter->dialog_filter_id_ == old_server_filter->dialog_filter_id_);
  CHECK(old_filter->dialog_filter_id_ == new_server_filter->dialog_filter_id_);
  auto dialog_filter_id = old_filter->dialog_filter_id_;
  auto new_filter = make_unique<DialogFilter>(*old_filter);
  new_filter->dialog_filter_id_ = dialog_filter_id;

  auto merge_ordered_changes = [dialog_filter_id](auto &new_dialog_ids, auto old_server_dialog_ids,
                                                  auto new_server_dialog_ids) {
    if (old_server_dialog_ids == new_server_dialog_ids) {
      LOG(INFO) << "Pinned chats were not changed remotely in " << dialog_filter_id << ", keep local changes";
      return;
    }

    if (InputDialogId::are_equivalent(new_dialog_ids, old_server_dialog_ids)) {
      LOG(INFO) << "Pinned chats were not changed locally in " << dialog_filter_id << ", keep remote changes";

      size_t kept_server_dialogs = 0;
      FlatHashSet<DialogId, DialogIdHash> removed_dialog_ids;
      auto old_it = old_server_dialog_ids.rbegin();
      for (auto &input_dialog_id : reversed(new_server_dialog_ids)) {
        auto dialog_id = input_dialog_id.get_dialog_id();
        while (old_it < old_server_dialog_ids.rend()) {
          if (old_it->get_dialog_id() == dialog_id) {
            kept_server_dialogs++;
            ++old_it;
            break;
          }

          // remove the dialog, it could be added back later
          CHECK(old_it->get_dialog_id().is_valid());
          removed_dialog_ids.insert(old_it->get_dialog_id());
          ++old_it;
        }
      }
      while (old_it < old_server_dialog_ids.rend()) {
        // remove the dialog, it could be added back later
        CHECK(old_it->get_dialog_id().is_valid());
        removed_dialog_ids.insert(old_it->get_dialog_id());
        ++old_it;
      }
      td::remove_if(new_dialog_ids, [&removed_dialog_ids](auto input_dialog_id) {
        return removed_dialog_ids.count(input_dialog_id.get_dialog_id()) > 0;
      });
      new_dialog_ids.insert(new_dialog_ids.begin(), new_server_dialog_ids.begin(),
                            new_server_dialog_ids.end() - kept_server_dialogs);
    } else {
      LOG(WARNING) << "Ignore remote changes of pinned chats in " << dialog_filter_id;
      // there are both local and remote changes; ignore remote changes for now
    }
  };

  auto merge_changes = [](auto &new_dialog_ids, const auto &old_server_dialog_ids, const auto &new_server_dialog_ids) {
    if (old_server_dialog_ids == new_server_dialog_ids) {
      // fast path
      return;
    }

    // merge additions and deletions from other clients to the local changes
    FlatHashSet<DialogId, DialogIdHash> deleted_dialog_ids;
    for (const auto &old_dialog_id : old_server_dialog_ids) {
      CHECK(old_dialog_id.get_dialog_id().is_valid());
      deleted_dialog_ids.insert(old_dialog_id.get_dialog_id());
    }
    FlatHashSet<DialogId, DialogIdHash> added_dialog_ids;
    for (const auto &new_dialog_id : new_server_dialog_ids) {
      auto dialog_id = new_dialog_id.get_dialog_id();
      if (deleted_dialog_ids.erase(dialog_id) == 0) {
        added_dialog_ids.insert(dialog_id);
      }
    }
    vector<InputDialogId> result;
    for (const auto &input_dialog_id : new_dialog_ids) {
      // do not add dialog twice
      added_dialog_ids.erase(input_dialog_id.get_dialog_id());
    }
    for (const auto &new_dialog_id : new_server_dialog_ids) {
      if (added_dialog_ids.count(new_dialog_id.get_dialog_id()) == 1) {
        result.push_back(new_dialog_id);
      }
    }
    for (const auto &input_dialog_id : new_dialog_ids) {
      if (deleted_dialog_ids.count(input_dialog_id.get_dialog_id()) == 0) {
        result.push_back(input_dialog_id);
      }
    }
    new_dialog_ids = std::move(result);
  };

  merge_ordered_changes(new_filter->pinned_dialog_ids_, old_server_filter->pinned_dialog_ids_,
                        new_server_filter->pinned_dialog_ids_);
  merge_changes(new_filter->included_dialog_ids_, old_server_filter->included_dialog_ids_,
                new_server_filter->included_dialog_ids_);
  merge_changes(new_filter->excluded_dialog_ids_, old_server_filter->excluded_dialog_ids_,
                new_server_filter->excluded_dialog_ids_);

  {
    FlatHashSet<DialogId, DialogIdHash> added_dialog_ids;
    auto remove_duplicates = [&added_dialog_ids](auto &input_dialog_ids) {
      td::remove_if(input_dialog_ids, [&added_dialog_ids](auto input_dialog_id) {
        auto dialog_id = input_dialog_id.get_dialog_id();
        CHECK(dialog_id.is_valid());
        return !added_dialog_ids.insert(dialog_id).second;
      });
    };
    remove_duplicates(new_filter->pinned_dialog_ids_);
    remove_duplicates(new_filter->included_dialog_ids_);
    remove_duplicates(new_filter->excluded_dialog_ids_);
  }

  auto update_value = [](auto &new_value, const auto &old_server_value, const auto &new_server_value) {
    // if the value was changed from other client and wasn't changed from the current client, update it
    if (new_server_value != old_server_value && old_server_value == new_value) {
      new_value = new_server_value;
    }
  };

  update_value(new_filter->exclude_muted_, old_server_filter->exclude_muted_, new_server_filter->exclude_muted_);
  update_value(new_filter->exclude_read_, old_server_filter->exclude_read_, new_server_filter->exclude_read_);
  update_value(new_filter->exclude_archived_, old_server_filter->exclude_archived_,
               new_server_filter->exclude_archived_);
  update_value(new_filter->include_contacts_, old_server_filter->include_contacts_,
               new_server_filter->include_contacts_);
  update_value(new_filter->include_non_contacts_, old_server_filter->include_non_contacts_,
               new_server_filter->include_non_contacts_);
  update_value(new_filter->include_bots_, old_server_filter->include_bots_, new_server_filter->include_bots_);
  update_value(new_filter->include_groups_, old_server_filter->include_groups_, new_server_filter->include_groups_);
  update_value(new_filter->include_channels_, old_server_filter->include_channels_,
               new_server_filter->include_channels_);
  update_value(new_filter->is_shareable_, old_server_filter->is_shareable_, new_server_filter->is_shareable_);
  update_value(new_filter->has_my_invites_, old_server_filter->has_my_invites_, new_server_filter->has_my_invites_);

  if (new_filter->is_shareable_) {
    new_filter->exclude_muted_ = false;
    new_filter->exclude_read_ = false;
    new_filter->exclude_archived_ = false;
    new_filter->include_contacts_ = false;
    new_filter->include_non_contacts_ = false;
    new_filter->include_bots_ = false;
    new_filter->include_groups_ = false;
    new_filter->include_channels_ = false;
    new_filter->excluded_dialog_ids_.clear();
  } else {
    new_filter->has_my_invites_ = false;
  }

  if (new_filter->check_limits().is_error()) {
    LOG(WARNING) << "Failed to merge local and remote changes in " << new_filter->dialog_filter_id_
                 << ", keep only local changes";
    *new_filter = *old_filter;
  }

  update_value(new_filter->title_, old_server_filter->title_, new_server_filter->title_);
  update_value(new_filter->animate_title_, old_server_filter->animate_title_, new_server_filter->animate_title_);
  update_value(new_filter->emoji_, old_server_filter->emoji_, new_server_filter->emoji_);
  update_value(new_filter->color_id_, old_server_filter->color_id_, new_server_filter->color_id_);

  LOG(INFO) << "Old  local filter: " << *old_filter;
  LOG(INFO) << "Old server filter: " << *old_server_filter;
  LOG(INFO) << "New server filter: " << *new_server_filter;
  LOG(INFO) << "New  local filter: " << *new_filter;

  return new_filter;
}

void DialogFilter::sort_input_dialog_ids(const Td *td, const char *source) {
  if (!include_contacts_ && !include_non_contacts_ && !include_bots_ && !include_groups_ && !include_channels_) {
    excluded_dialog_ids_.clear();
  }

  auto sort_input_dialog_ids = [user_manager = td->user_manager_.get()](vector<InputDialogId> &input_dialog_ids) {
    std::sort(input_dialog_ids.begin(), input_dialog_ids.end(), [user_manager](InputDialogId lhs, InputDialogId rhs) {
      auto get_order = [user_manager](InputDialogId input_dialog_id) {
        auto dialog_id = input_dialog_id.get_dialog_id();
        if (dialog_id.get_type() != DialogType::SecretChat) {
          return dialog_id.get() * 10;
        }
        auto user_id = user_manager->get_secret_chat_user_id(dialog_id.get_secret_chat_id());
        return DialogId(user_id).get() * 10 + 1;
      };
      return get_order(lhs) < get_order(rhs);
    });
  };

  sort_input_dialog_ids(excluded_dialog_ids_);
  sort_input_dialog_ids(included_dialog_ids_);

  FlatHashSet<DialogId, DialogIdHash> all_dialog_ids;
  for_each_dialog([&](const InputDialogId &input_dialog_id) {
    auto dialog_id = input_dialog_id.get_dialog_id();
    CHECK(dialog_id.is_valid());
    LOG_CHECK(all_dialog_ids.insert(dialog_id).second) << source << ' ' << dialog_id << ' ' << *this;
  });
}

vector<DialogId> DialogFilter::get_dialogs_for_invite_link(Td *td) {
  if (!excluded_dialog_ids_.empty() || exclude_muted_ || exclude_read_ || exclude_archived_ || include_contacts_ ||
      include_non_contacts_ || include_bots_ || include_groups_ || include_channels_) {
    return {};
  }
  vector<DialogId> result;
  for_each_dialog([&](const InputDialogId &input_dialog_id) {
    auto dialog_id = input_dialog_id.get_dialog_id();
    if (!td->dialog_manager_->have_dialog_force(dialog_id, "get_dialogs_for_invite_link")) {
      return;
    }
    bool is_good = false;
    switch (dialog_id.get_type()) {
      case DialogType::Chat: {
        auto chat_id = dialog_id.get_chat_id();
        // the user can manage invite links in the chat
        is_good = td->chat_manager_->get_chat_status(chat_id).can_manage_invite_links();
        break;
      }
      case DialogType::Channel: {
        auto channel_id = dialog_id.get_channel_id();
        // the user can manage invite links in the chat
        // or the chat is a public chat, which can be joined without administrator approval
        is_good = td->chat_manager_->get_channel_status(channel_id).can_manage_invite_links() ||
                  (td->chat_manager_->is_channel_public(channel_id) &&
                   !td->chat_manager_->get_channel_join_request(channel_id));
        break;
      }
      default:
        break;
    }
    if (is_good) {
      result.push_back(dialog_id);
    }
  });
  return result;
}

vector<FolderId> DialogFilter::get_folder_ids() const {
  if (exclude_archived_ && pinned_dialog_ids_.empty() && included_dialog_ids_.empty()) {
    return {FolderId::main()};
  }
  return {FolderId::main(), FolderId::archive()};
}

bool DialogFilter::need_dialog(const Td *td, const DialogFilterDialogInfo &dialog_info) const {
  auto dialog_id = dialog_info.dialog_id_;
  if (is_dialog_included(dialog_id)) {
    return true;
  }
  if (InputDialogId::contains(excluded_dialog_ids_, dialog_id)) {
    return false;
  }
  if (dialog_id.get_type() == DialogType::SecretChat) {
    auto user_id = td->user_manager_->get_secret_chat_user_id(dialog_id.get_secret_chat_id());
    if (user_id.is_valid()) {
      auto user_dialog_id = DialogId(user_id);
      if (is_dialog_included(user_dialog_id)) {
        return true;
      }
      if (InputDialogId::contains(excluded_dialog_ids_, user_dialog_id)) {
        return false;
      }
    }
  }
  if (!dialog_info.has_unread_mentions_) {
    if (exclude_muted_ && dialog_info.is_muted_) {
      return false;
    }
    if (exclude_read_ && !dialog_info.has_unread_messages_) {
      return false;
    }
  }
  if (exclude_archived_ && dialog_info.folder_id_ == FolderId::archive()) {
    return false;
  }
  switch (dialog_id.get_type()) {
    case DialogType::User: {
      auto user_id = dialog_id.get_user_id();
      if (td->user_manager_->is_user_bot(user_id)) {
        return include_bots_;
      }
      if (user_id == td->user_manager_->get_my_id() || td->user_manager_->is_user_contact(user_id)) {
        return include_contacts_;
      }
      return include_non_contacts_;
    }
    case DialogType::Chat:
      return include_groups_;
    case DialogType::Channel:
      return td->chat_manager_->is_broadcast_channel(dialog_id.get_channel_id()) ? include_channels_ : include_groups_;
    case DialogType::SecretChat: {
      auto user_id = td->user_manager_->get_secret_chat_user_id(dialog_id.get_secret_chat_id());
      if (td->user_manager_->is_user_bot(user_id)) {
        return include_bots_;
      }
      if (td->user_manager_->is_user_contact(user_id)) {
        return include_contacts_;
      }
      return include_non_contacts_;
    }
    default:
      UNREACHABLE();
      return false;
  }
}

vector<DialogFilterId> DialogFilter::get_dialog_filter_ids(const vector<unique_ptr<DialogFilter>> &dialog_filters,
                                                           int32 main_dialog_list_position) {
  auto result = transform(dialog_filters, [](const auto &dialog_filter) { return dialog_filter->dialog_filter_id_; });
  if (static_cast<size_t>(main_dialog_list_position) <= result.size()) {
    result.insert(result.begin() + main_dialog_list_position, DialogFilterId());
  }
  return result;
}

bool DialogFilter::set_dialog_filters_order(vector<unique_ptr<DialogFilter>> &dialog_filters,
                                            vector<DialogFilterId> dialog_filter_ids) {
  auto old_dialog_filter_ids = get_dialog_filter_ids(dialog_filters, -1);
  if (old_dialog_filter_ids == dialog_filter_ids) {
    return false;
  }
  LOG(INFO) << "Reorder chat folders from " << old_dialog_filter_ids << " to " << dialog_filter_ids;

  if (dialog_filter_ids.size() != old_dialog_filter_ids.size()) {
    for (auto dialog_filter_id : old_dialog_filter_ids) {
      if (!td::contains(dialog_filter_ids, dialog_filter_id)) {
        dialog_filter_ids.push_back(dialog_filter_id);
      }
    }
    CHECK(dialog_filter_ids.size() == old_dialog_filter_ids.size());
  }
  if (old_dialog_filter_ids == dialog_filter_ids) {
    return false;
  }

  CHECK(dialog_filter_ids.size() == dialog_filters.size());
  for (size_t i = 0; i < dialog_filters.size(); i++) {
    for (size_t j = i; j < dialog_filters.size(); j++) {
      if (dialog_filters[j]->dialog_filter_id_ == dialog_filter_ids[i]) {
        if (i != j) {
          std::swap(dialog_filters[i], dialog_filters[j]);
        }
        break;
      }
    }
    CHECK(dialog_filters[i]->dialog_filter_id_ == dialog_filter_ids[i]);
  }
  return true;
}

bool DialogFilter::are_similar(const DialogFilter &lhs, const DialogFilter &rhs) {
  if (lhs.title_ == rhs.title_) {
    return true;
  }
  if (!are_flags_equal(lhs, rhs)) {
    return false;
  }

  vector<InputDialogId> empty_input_dialog_ids;
  if (InputDialogId::are_equivalent(lhs.excluded_dialog_ids_, empty_input_dialog_ids) !=
      InputDialogId::are_equivalent(rhs.excluded_dialog_ids_, empty_input_dialog_ids)) {
    return false;
  }
  if ((InputDialogId::are_equivalent(lhs.pinned_dialog_ids_, empty_input_dialog_ids) &&
       InputDialogId::are_equivalent(lhs.included_dialog_ids_, empty_input_dialog_ids)) !=
      (InputDialogId::are_equivalent(rhs.pinned_dialog_ids_, empty_input_dialog_ids) &&
       InputDialogId::are_equivalent(rhs.included_dialog_ids_, empty_input_dialog_ids))) {
    return false;
  }

  return true;
}

bool DialogFilter::are_equivalent(const DialogFilter &lhs, const DialogFilter &rhs) {
  return lhs.title_ == rhs.title_ && lhs.animate_title_ == rhs.animate_title_ && lhs.emoji_ == rhs.emoji_ &&
         lhs.color_id_ == rhs.color_id_ && lhs.is_shareable_ == rhs.is_shareable_ &&
         lhs.has_my_invites_ == rhs.has_my_invites_ &&
         InputDialogId::are_equivalent(lhs.pinned_dialog_ids_, rhs.pinned_dialog_ids_) &&
         InputDialogId::are_equivalent(lhs.included_dialog_ids_, rhs.included_dialog_ids_) &&
         InputDialogId::are_equivalent(lhs.excluded_dialog_ids_, rhs.excluded_dialog_ids_) && are_flags_equal(lhs, rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const DialogFilter &filter) {
  return string_builder << filter.dialog_filter_id_ << " (pinned " << filter.pinned_dialog_ids_ << ", included "
                        << filter.included_dialog_ids_ << ", excluded " << filter.excluded_dialog_ids_ << ", "
                        << filter.exclude_muted_ << ' ' << filter.exclude_read_ << ' ' << filter.exclude_archived_
                        << '/' << filter.include_contacts_ << ' ' << filter.include_non_contacts_ << ' '
                        << filter.include_bots_ << ' ' << filter.include_groups_ << ' ' << filter.include_channels_
                        << ')';
}

void DialogFilter::init_icon_names() {
  static bool is_inited = [&] {
    vector<string> emojis{"\xF0\x9F\x92\xAC",         "\xE2\x9C\x85",     "\xF0\x9F\x94\x94",
                          "\xF0\x9F\xA4\x96",         "\xF0\x9F\x93\xA2", "\xF0\x9F\x91\xA5",
                          "\xF0\x9F\x91\xA4",         "\xF0\x9F\x93\x81", "\xF0\x9F\x93\x8B",
                          "\xF0\x9F\x90\xB1",         "\xF0\x9F\x91\x91", "\xE2\xAD\x90\xEF\xB8\x8F",
                          "\xF0\x9F\x8C\xB9",         "\xF0\x9F\x8E\xAE", "\xF0\x9F\x8F\xA0",
                          "\xE2\x9D\xA4\xEF\xB8\x8F", "\xF0\x9F\x8E\xAD", "\xF0\x9F\x8D\xB8",
                          "\xE2\x9A\xBD\xEF\xB8\x8F", "\xF0\x9F\x8E\x93", "\xF0\x9F\x93\x88",
                          "\xE2\x9C\x88\xEF\xB8\x8F", "\xF0\x9F\x92\xBC", "\xF0\x9F\x9B\xAB",
                          "\xF0\x9F\x93\x95",         "\xF0\x9F\x92\xA1", "\xF0\x9F\x91\x8D",
                          "\xF0\x9F\x92\xB0",         "\xF0\x9F\x8E\xB5", "\xF0\x9F\x8E\xA8"};
    vector<string> icon_names{"All",   "Unread", "Unmuted", "Bots",     "Channels", "Groups", "Private", "Custom",
                              "Setup", "Cat",    "Crown",   "Favorite", "Flower",   "Game",   "Home",    "Love",
                              "Mask",  "Party",  "Sport",   "Study",    "Trade",    "Travel", "Work",    "Airplane",
                              "Book",  "Light",  "Like",    "Money",    "Note",     "Palette"};

    CHECK(emojis.size() == icon_names.size());
    for (size_t i = 0; i < emojis.size(); i++) {
      remove_emoji_modifiers_in_place(emojis[i]);
      bool is_inserted = emoji_to_icon_name_.emplace(emojis[i], icon_names[i]).second &&
                         icon_name_to_emoji_.emplace(icon_names[i], emojis[i]).second;
      CHECK(is_inserted);
    }
    return true;
  }();
  CHECK(is_inited);
}

bool DialogFilter::is_valid_color_id(int32 color_id) {
  return -1 <= color_id && color_id <= 6;
}

bool DialogFilter::are_flags_equal(const DialogFilter &lhs, const DialogFilter &rhs) {
  return lhs.exclude_muted_ == rhs.exclude_muted_ && lhs.exclude_read_ == rhs.exclude_read_ &&
         lhs.exclude_archived_ == rhs.exclude_archived_ && lhs.include_contacts_ == rhs.include_contacts_ &&
         lhs.include_non_contacts_ == rhs.include_non_contacts_ && lhs.include_bots_ == rhs.include_bots_ &&
         lhs.include_groups_ == rhs.include_groups_ && lhs.include_channels_ == rhs.include_channels_;
}

FlatHashMap<string, string> DialogFilter::emoji_to_icon_name_;
FlatHashMap<string, string> DialogFilter::icon_name_to_emoji_;

}  // namespace td
