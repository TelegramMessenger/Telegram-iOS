//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/MissingInvitee.h"

#include "td/telegram/UserManager.h"

#include "td/utils/algorithm.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"

namespace td {

MissingInvitee::MissingInvitee(telegram_api::object_ptr<telegram_api::missingInvitee> &&invitee)
    : user_id_(invitee->user_id_)
    , premium_would_allow_invite_(invitee->premium_would_allow_invite_)
    , premium_required_for_pm_(invitee->premium_required_for_pm_) {
}

td_api::object_ptr<td_api::failedToAddMember> MissingInvitee::get_failed_to_add_member_object(
    UserManager *user_manager) const {
  return td_api::make_object<td_api::failedToAddMember>(
      user_manager->get_user_id_object(user_id_, "get_failed_to_add_member_object"), premium_would_allow_invite_,
      premium_required_for_pm_);
}

StringBuilder &operator<<(StringBuilder &string_builder, const MissingInvitee &invitee) {
  return string_builder << '[' << invitee.user_id_ << ' ' << invitee.premium_would_allow_invite_ << ' '
                        << invitee.premium_required_for_pm_ << ']';
}

MissingInvitees::MissingInvitees(vector<telegram_api::object_ptr<telegram_api::missingInvitee>> &&invitees) {
  for (auto &invitee : invitees) {
    missing_invitees_.emplace_back(std::move(invitee));
    if (!missing_invitees_.back().is_valid()) {
      LOG(ERROR) << "Receive invalid " << missing_invitees_.back() << " as a missing invitee";
      missing_invitees_.pop_back();
    }
  }
}

td_api::object_ptr<td_api::failedToAddMembers> MissingInvitees::get_failed_to_add_members_object(
    UserManager *user_manager) const {
  return td_api::make_object<td_api::failedToAddMembers>(
      transform(missing_invitees_, [user_manager](const MissingInvitee &message_invitee) {
        return message_invitee.get_failed_to_add_member_object(user_manager);
      }));
}

StringBuilder &operator<<(StringBuilder &string_builder, const MissingInvitees &invitees) {
  return string_builder << invitees.missing_invitees_;
}

}  // namespace td
