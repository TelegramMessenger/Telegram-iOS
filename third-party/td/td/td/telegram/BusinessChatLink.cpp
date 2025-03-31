//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/BusinessChatLink.h"

#include "td/utils/algorithm.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"

namespace td {

BusinessChatLink::BusinessChatLink(const UserManager *user_manager,
                                   telegram_api::object_ptr<telegram_api::businessChatLink> &&link)
    : link_(std::move(link->link_))
    , text_(get_message_text(user_manager, std::move(link->message_), std::move(link->entities_), true, true, 0, false,
                             "BusinessChatLink"))
    , title_(std::move(link->title_))
    , view_count_(link->views_) {
}

td_api::object_ptr<td_api::businessChatLink> BusinessChatLink::get_business_chat_link_object(
    const UserManager *user_manager) const {
  return td_api::make_object<td_api::businessChatLink>(link_, get_formatted_text_object(user_manager, text_, true, -1),
                                                       title_, view_count_);
}

StringBuilder &operator<<(StringBuilder &string_builder, const BusinessChatLink &link) {
  return string_builder << '[' << link.link_ << ' ' << link.title_ << ' ' << link.view_count_ << ']';
}

BusinessChatLinks::BusinessChatLinks(const UserManager *user_manager,
                                     vector<telegram_api::object_ptr<telegram_api::businessChatLink>> &&links) {
  for (auto &link : links) {
    business_chat_links_.emplace_back(user_manager, std::move(link));
    if (!business_chat_links_.back().is_valid()) {
      LOG(ERROR) << "Receive invalid " << business_chat_links_.back() << " business link";
      business_chat_links_.pop_back();
    }
  }
}

td_api::object_ptr<td_api::businessChatLinks> BusinessChatLinks::get_business_chat_links_object(
    const UserManager *user_manager) const {
  return td_api::make_object<td_api::businessChatLinks>(transform(
      business_chat_links_,
      [user_manager](const BusinessChatLink &link) { return link.get_business_chat_link_object(user_manager); }));
}

StringBuilder &operator<<(StringBuilder &string_builder, const BusinessChatLinks &links) {
  return string_builder << links.business_chat_links_;
}

}  // namespace td
