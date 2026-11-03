//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/MessageId.h"
#include "td/telegram/td_api.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

struct DialogParticipant;
class Td;

class DialogParticipantFilter {
  enum class Type : int32 { Contacts, Administrators, Members, Restricted, Banned, Mention, Bots };
  Type type_;
  MessageId top_thread_message_id_;

  friend StringBuilder &operator<<(StringBuilder &string_builder, const DialogParticipantFilter &filter);

 public:
  explicit DialogParticipantFilter(const td_api::object_ptr<td_api::ChatMembersFilter> &filter);

  td_api::object_ptr<td_api::SupergroupMembersFilter> get_supergroup_members_filter_object(const string &query) const;

  bool has_query() const;

  bool is_dialog_participant_suitable(const Td *td, const DialogParticipant &participant) const;
};

StringBuilder &operator<<(StringBuilder &string_builder, const DialogParticipantFilter &filter);

}  // namespace td
