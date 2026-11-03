//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

class UserManager;

class MissingInvitee {
  UserId user_id_;
  bool premium_would_allow_invite_ = false;
  bool premium_required_for_pm_ = false;

  friend StringBuilder &operator<<(StringBuilder &string_builder, const MissingInvitee &invitee);

 public:
  explicit MissingInvitee(telegram_api::object_ptr<telegram_api::missingInvitee> &&invitee);

  bool is_valid() const {
    return user_id_.is_valid();
  }

  td_api::object_ptr<td_api::failedToAddMember> get_failed_to_add_member_object(UserManager *user_manager) const;
};

StringBuilder &operator<<(StringBuilder &string_builder, const MissingInvitee &invitee);

class MissingInvitees {
  vector<MissingInvitee> missing_invitees_;

  friend StringBuilder &operator<<(StringBuilder &string_builder, const MissingInvitees &invitees);

 public:
  MissingInvitees() = default;

  explicit MissingInvitees(vector<telegram_api::object_ptr<telegram_api::missingInvitee>> &&invitees);

  td_api::object_ptr<td_api::failedToAddMembers> get_failed_to_add_members_object(UserManager *user_manager) const;
};

StringBuilder &operator<<(StringBuilder &string_builder, const MissingInvitees &invitees);

}  // namespace td
