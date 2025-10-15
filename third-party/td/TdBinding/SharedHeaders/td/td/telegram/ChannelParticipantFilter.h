//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/MessageId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

class ChannelParticipantFilter {
  enum class Type : int32 { Recent, Contacts, Administrators, Search, Mention, Restricted, Banned, Bots };
  Type type_;
  string query_;
  MessageId top_thread_message_id_;

  friend StringBuilder &operator<<(StringBuilder &string_builder, const ChannelParticipantFilter &filter);

 public:
  explicit ChannelParticipantFilter(const td_api::object_ptr<td_api::SupergroupMembersFilter> &filter);

  tl_object_ptr<telegram_api::ChannelParticipantsFilter> get_input_channel_participants_filter() const;

  bool is_administrators() const {
    return type_ == Type::Administrators;
  }

  bool is_bots() const {
    return type_ == Type::Bots;
  }

  bool is_recent() const {
    return type_ == Type::Recent;
  }

  bool is_contacts() const {
    return type_ == Type::Contacts;
  }

  bool is_search() const {
    return type_ == Type::Search;
  }

  bool is_restricted() const {
    return type_ == Type::Restricted;
  }

  bool is_banned() const {
    return type_ == Type::Banned;
  }
};

StringBuilder &operator<<(StringBuilder &string_builder, const ChannelParticipantFilter &filter);

}  // namespace td
