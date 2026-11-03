//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/Slice.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/tl_helpers.h"

namespace td {

class RestrictionReason {
  string platform_;
  string reason_;
  string description_;

  friend StringBuilder &operator<<(StringBuilder &string_builder, const RestrictionReason &reason) {
    return string_builder << "RestrictionReason[" << reason.platform_ << ", " << reason.reason_ << ", "
                          << reason.description_ << "]";
  }

  friend bool operator==(const RestrictionReason &lhs, const RestrictionReason &rhs) {
    return lhs.platform_ == rhs.platform_ && lhs.reason_ == rhs.reason_ && lhs.description_ == rhs.description_;
  }

  friend const RestrictionReason *get_restriction_reason(const vector<RestrictionReason> &restriction_reasons,
                                                         bool sensitive);

  friend string get_restriction_reason_description(const vector<RestrictionReason> &restriction_reasons);

  bool is_sensitive() const {
    return reason_ == "sensitive";
  }

 public:
  RestrictionReason() = default;

  RestrictionReason(string &&platform, string &&reason, string &&description)
      : platform_(std::move(platform)), reason_(std::move(reason)), description_(std::move(description)) {
    if (description_.empty()) {
      description_ = reason_;
    }
  }

  template <class StorerT>
  void store(StorerT &storer) const {
    td::store(platform_, storer);
    td::store(reason_, storer);
    td::store(description_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    td::parse(platform_, parser);
    td::parse(reason_, parser);
    td::parse(description_, parser);
  }
};

inline bool operator!=(const RestrictionReason &lhs, const RestrictionReason &rhs) {
  return !(lhs == rhs);
}

bool get_restriction_reason_has_sensitive_content(const vector<RestrictionReason> &restriction_reasons);

string get_restriction_reason_description(const vector<RestrictionReason> &restriction_reasons);

vector<RestrictionReason> get_restriction_reasons(Slice legacy_restriction_reason);

vector<RestrictionReason> get_restriction_reasons(
    vector<telegram_api::object_ptr<telegram_api::restrictionReason>> &&restriction_reasons);

}  // namespace td
