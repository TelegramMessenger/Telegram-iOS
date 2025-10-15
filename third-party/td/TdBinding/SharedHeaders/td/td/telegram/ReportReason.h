//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"

namespace td {

class ReportReason {
  enum class Type : int32 {
    Spam,
    Violence,
    Pornography,
    ChildAbuse,
    Copyright,
    UnrelatedLocation,
    Fake,
    IllegalDrugs,
    PersonalDetails,
    Custom
  };
  Type type_ = Type::Spam;
  string message_;

  friend StringBuilder &operator<<(StringBuilder &string_builder, const ReportReason &report_reason);

  ReportReason(Type type, string &&message) : type_(type), message_(std::move(message)) {
  }

 public:
  ReportReason() = default;

  static Result<ReportReason> get_report_reason(td_api::object_ptr<td_api::ReportReason> reason, string &&message);

  tl_object_ptr<telegram_api::ReportReason> get_input_report_reason() const;

  const string &get_message() const {
    return message_;
  }

  bool is_spam() const {
    return type_ == Type::Spam;
  }

  bool is_unrelated_location() const {
    return type_ == Type::UnrelatedLocation;
  }
};

StringBuilder &operator<<(StringBuilder &string_builder, const ReportReason &report_reason);

}  // namespace td
