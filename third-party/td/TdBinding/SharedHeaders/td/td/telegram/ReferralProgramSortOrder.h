//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

enum class ReferralProgramSortOrder : int32 { Profitability, Date, Revenue };

ReferralProgramSortOrder get_referral_program_sort_order(
    const td_api::object_ptr<td_api::AffiliateProgramSortOrder> &order);

}  // namespace td
