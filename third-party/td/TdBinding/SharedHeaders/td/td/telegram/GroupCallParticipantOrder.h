//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

class GroupCallParticipantOrder {
  bool has_video_ = false;
  int32 active_date_ = 0;
  int32 joined_date_ = 0;
  int64 raise_hand_rating_ = 0;

  friend StringBuilder &operator<<(StringBuilder &string_builder,
                                   const GroupCallParticipantOrder &group_call_participant_order);

  friend bool operator==(const GroupCallParticipantOrder &lhs, const GroupCallParticipantOrder &rhs);

  friend bool operator<(const GroupCallParticipantOrder &lhs, const GroupCallParticipantOrder &rhs);

 public:
  GroupCallParticipantOrder() = default;

  GroupCallParticipantOrder(bool has_video, int32 active_date, int64 raise_hand_rating, int32 joined_date)
      : has_video_(has_video)
      , active_date_(active_date)
      , joined_date_(joined_date)
      , raise_hand_rating_(raise_hand_rating) {
  }

  static GroupCallParticipantOrder min();

  static GroupCallParticipantOrder max();

  bool is_valid() const;

  bool has_video() const {
    return has_video_;
  }

  string get_group_call_participant_order_object() const;
};

bool operator==(const GroupCallParticipantOrder &lhs, const GroupCallParticipantOrder &rhs);

bool operator!=(const GroupCallParticipantOrder &lhs, const GroupCallParticipantOrder &rhs);

bool operator<(const GroupCallParticipantOrder &lhs, const GroupCallParticipantOrder &rhs);

bool operator<=(const GroupCallParticipantOrder &lhs, const GroupCallParticipantOrder &rhs);

bool operator>(const GroupCallParticipantOrder &lhs, const GroupCallParticipantOrder &rhs);

bool operator>=(const GroupCallParticipantOrder &lhs, const GroupCallParticipantOrder &rhs);

StringBuilder &operator<<(StringBuilder &string_builder, const GroupCallParticipantOrder &group_call_participant_order);

}  // namespace td
