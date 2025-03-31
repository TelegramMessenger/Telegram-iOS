//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/ReferralProgramParameters.h"

namespace td {

ReferralProgramParameters::ReferralProgramParameters(int32 commission_permille, int32 duration_months)
    : commission_(commission_permille), month_count_(duration_months) {
}

ReferralProgramParameters::ReferralProgramParameters(
    const td_api::object_ptr<td_api::affiliateProgramParameters> &parameters) {
  if (parameters != nullptr) {
    commission_ = parameters->commission_per_mille_;
    month_count_ = parameters->month_count_;
    if (!is_valid()) {
      commission_ = -1;
    }
  }
}

td_api::object_ptr<td_api::affiliateProgramParameters>
ReferralProgramParameters::get_affiliate_program_parameters_object() const {
  CHECK(is_valid());
  return td_api::make_object<td_api::affiliateProgramParameters>(commission_, month_count_);
}

bool operator==(const ReferralProgramParameters &lhs, const ReferralProgramParameters &rhs) {
  return lhs.commission_ == rhs.commission_ && lhs.month_count_ == rhs.month_count_;
}

StringBuilder &operator<<(StringBuilder &string_builder, const ReferralProgramParameters &parameters) {
  string_builder << "ReferralProgram[" << parameters.commission_;
  if (parameters.month_count_ != 0) {
    string_builder << " X " << parameters.month_count_;
  }
  return string_builder << ']';
}

}  // namespace td
