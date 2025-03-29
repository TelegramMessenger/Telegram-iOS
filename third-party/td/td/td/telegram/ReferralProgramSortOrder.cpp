//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/ReferralProgramSortOrder.h"

namespace td {

ReferralProgramSortOrder get_referral_program_sort_order(
    const td_api::object_ptr<td_api::AffiliateProgramSortOrder> &order) {
  if (order == nullptr) {
    return ReferralProgramSortOrder::Profitability;
  }
  switch (order->get_id()) {
    case td_api::affiliateProgramSortOrderProfitability::ID:
      return ReferralProgramSortOrder::Profitability;
    case td_api::affiliateProgramSortOrderCreationDate::ID:
      return ReferralProgramSortOrder::Date;
    case td_api::affiliateProgramSortOrderRevenue::ID:
      return ReferralProgramSortOrder::Revenue;
    default:
      UNREACHABLE();
      return ReferralProgramSortOrder::Profitability;
  }
}

}  // namespace td
