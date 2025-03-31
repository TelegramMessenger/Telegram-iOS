//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/InputBusinessChatLink.h"

#include "td/telegram/DialogManager.h"
#include "td/telegram/misc.h"
#include "td/telegram/Td.h"

#include "td/utils/logging.h"

namespace td {

InputBusinessChatLink::InputBusinessChatLink(const Td *td, td_api::object_ptr<td_api::inputBusinessChatLink> &&link) {
  if (link == nullptr) {
    return;
  }
  auto r_text =
      get_formatted_text(td, td->dialog_manager_->get_my_dialog_id(), std::move(link->text_), false, true, true, false);
  if (r_text.is_error()) {
    LOG(INFO) << "Ignore draft text: " << r_text.error();
  } else {
    text_ = r_text.move_as_ok();
  }
  if (clean_input_string(link->title_)) {
    title_ = std::move(link->title_);
  }
}

telegram_api::object_ptr<telegram_api::inputBusinessChatLink> InputBusinessChatLink::get_input_business_chat_link(
    const UserManager *user_manager) const {
  int32 flags = 0;
  auto entities = get_input_message_entities(user_manager, &text_, "get_input_business_chat_link");
  if (!entities.empty()) {
    flags |= telegram_api::inputBusinessChatLink::ENTITIES_MASK;
  }
  if (!title_.empty()) {
    flags |= telegram_api::inputBusinessChatLink::TITLE_MASK;
  }
  return telegram_api::make_object<telegram_api::inputBusinessChatLink>(flags, text_.text, std::move(entities), title_);
}

StringBuilder &operator<<(StringBuilder &string_builder, const InputBusinessChatLink &link) {
  return string_builder << '[' << link.title_ << ']';
}

}  // namespace td
