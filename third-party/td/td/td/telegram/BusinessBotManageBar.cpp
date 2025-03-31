//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/BusinessBotManageBar.h"

#include "td/telegram/Dependencies.h"
#include "td/telegram/Td.h"
#include "td/telegram/UserManager.h"

#include "td/utils/logging.h"

namespace td {

unique_ptr<BusinessBotManageBar> BusinessBotManageBar::create(bool is_business_bot_paused, bool can_business_bot_reply,
                                                              UserId business_bot_user_id,
                                                              string business_bot_manage_url) {
  auto action_bar = make_unique<BusinessBotManageBar>();
  action_bar->is_business_bot_paused_ = is_business_bot_paused;
  action_bar->can_business_bot_reply_ = can_business_bot_reply;
  action_bar->business_bot_user_id_ = business_bot_user_id;
  action_bar->business_bot_manage_url_ = std::move(business_bot_manage_url);
  if (action_bar->is_empty()) {
    return nullptr;
  }
  return action_bar;
}

bool BusinessBotManageBar::is_empty() const {
  return !business_bot_user_id_.is_valid();
}

void BusinessBotManageBar::fix(DialogId dialog_id) {
  bool is_valid = business_bot_user_id_.is_valid()
                      ? dialog_id.get_type() == DialogType::User && !business_bot_manage_url_.empty()
                      : business_bot_manage_url_.empty() && !is_business_bot_paused_ && !can_business_bot_reply_;
  if (!is_valid) {
    LOG(ERROR) << "Receive business bot " << business_bot_user_id_ << " in " << dialog_id << " with manage URL "
               << business_bot_manage_url_;
    *this = {};
  }
}

td_api::object_ptr<td_api::businessBotManageBar> BusinessBotManageBar::get_business_bot_manage_bar_object(
    Td *td) const {
  if (is_empty()) {
    return nullptr;
  }
  return td_api::make_object<td_api::businessBotManageBar>(
      td->user_manager_->get_user_id_object(business_bot_user_id_, "businessBotManageBar"), business_bot_manage_url_,
      is_business_bot_paused_, can_business_bot_reply_);
}

bool BusinessBotManageBar::on_user_deleted() {
  if (is_empty()) {
    return false;
  }

  *this = {};
  return true;
}

bool BusinessBotManageBar::set_business_bot_is_paused(bool is_paused) {
  if (!business_bot_user_id_.is_valid() || is_business_bot_paused_ == is_paused) {
    return false;
  }
  is_business_bot_paused_ = is_paused;
  return true;
}

void BusinessBotManageBar::add_dependencies(Dependencies &dependencies) const {
  dependencies.add(business_bot_user_id_);
}

bool operator==(const BusinessBotManageBar &lhs, const BusinessBotManageBar &rhs) {
  return lhs.business_bot_user_id_ == rhs.business_bot_user_id_ &&
         lhs.business_bot_manage_url_ == rhs.business_bot_manage_url_ &&
         lhs.is_business_bot_paused_ == rhs.is_business_bot_paused_ &&
         lhs.can_business_bot_reply_ == rhs.can_business_bot_reply_;
}

bool operator!=(const BusinessBotManageBar &lhs, const BusinessBotManageBar &rhs) {
  return !(lhs == rhs);
}

}  // namespace td
