//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/ReferralProgramParameters.h"
#include "td/telegram/StarAmount.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

class ReferralProgramInfo {
  ReferralProgramParameters parameters_;
  int32 end_date_ = 0;
  StarAmount daily_star_amount_;

  friend bool operator==(const ReferralProgramInfo &lhs, const ReferralProgramInfo &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const ReferralProgramInfo &info);

 public:
  ReferralProgramInfo() = default;

  explicit ReferralProgramInfo(telegram_api::object_ptr<telegram_api::starRefProgram> &&program);

  bool is_valid() const {
    return parameters_.is_valid() && end_date_ >= 0;
  }

  bool is_active() const {
    return end_date_ == 0;
  }

  td_api::object_ptr<td_api::affiliateProgramInfo> get_affiliate_program_info_object() const;

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

bool operator==(const ReferralProgramInfo &lhs, const ReferralProgramInfo &rhs);

inline bool operator!=(const ReferralProgramInfo &lhs, const ReferralProgramInfo &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const ReferralProgramInfo &info);

}  // namespace td
