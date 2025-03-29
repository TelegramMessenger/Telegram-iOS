//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/DialogFilterInviteLink.h"

#include "td/telegram/DialogManager.h"
#include "td/telegram/LinkManager.h"
#include "td/telegram/Td.h"

#include "td/utils/logging.h"

namespace td {

DialogFilterInviteLink::DialogFilterInviteLink(
    Td *td, telegram_api::object_ptr<telegram_api::exportedChatlistInvite> exported_invite) {
  CHECK(exported_invite != nullptr);
  LOG_IF(ERROR, !is_valid_invite_link(exported_invite->url_)) << "Unsupported " << to_string(exported_invite);
  invite_link_ = std::move(exported_invite->url_);
  title_ = std::move(exported_invite->title_);
  for (const auto &peer : exported_invite->peers_) {
    DialogId dialog_id(peer);
    if (dialog_id.is_valid()) {
      td->dialog_manager_->force_create_dialog(dialog_id, "DialogFilterInviteLink");
      dialog_ids_.push_back(dialog_id);
    }
  }
}

td_api::object_ptr<td_api::chatFolderInviteLink> DialogFilterInviteLink::get_chat_folder_invite_link_object(
    const Td *td) const {
  return td_api::make_object<td_api::chatFolderInviteLink>(
      invite_link_, title_, td->dialog_manager_->get_chat_ids_object(dialog_ids_, "chatFolderInviteLink"));
}

bool DialogFilterInviteLink::is_valid_invite_link(Slice invite_link) {
  return !LinkManager::get_dialog_filter_invite_link_slug(invite_link).empty();
}

bool operator==(const DialogFilterInviteLink &lhs, const DialogFilterInviteLink &rhs) {
  return lhs.invite_link_ == rhs.invite_link_ && lhs.title_ == rhs.title_ && lhs.dialog_ids_ == rhs.dialog_ids_;
}

bool operator!=(const DialogFilterInviteLink &lhs, const DialogFilterInviteLink &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const DialogFilterInviteLink &invite_link) {
  return string_builder << "FolderInviteLink[" << invite_link.invite_link_ << '(' << invite_link.title_ << ')'
                        << invite_link.dialog_ids_ << ']';
}

}  // namespace td
