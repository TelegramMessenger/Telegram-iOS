//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"

#include "td/utils/common.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"

namespace td {

class DialogSource {
  enum class Type : int32 { Membership, MtprotoProxy, PublicServiceAnnouncement };
  Type type_ = Type::Membership;
  string psa_type_;
  string psa_text_;

  friend bool operator==(const DialogSource &lhs, const DialogSource &rhs);

  friend bool operator!=(const DialogSource &lhs, const DialogSource &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const DialogSource &source);

 public:
  static DialogSource mtproto_proxy();

  static DialogSource public_service_announcement(string psa_type, string psa_text);

  static Result<DialogSource> unserialize(Slice str);

  string serialize() const;

  td_api::object_ptr<td_api::ChatSource> get_chat_source_object() const;
};

bool operator==(const DialogSource &lhs, const DialogSource &rhs);

bool operator!=(const DialogSource &lhs, const DialogSource &rhs);

StringBuilder &operator<<(StringBuilder &string_builder, const DialogSource &source);

}  // namespace td
