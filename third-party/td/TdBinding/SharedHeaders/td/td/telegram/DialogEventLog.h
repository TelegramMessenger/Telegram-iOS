//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/UserId.h"

#include "td/utils/common.h"
#include "td/utils/Promise.h"

namespace td {

class Td;

void get_dialog_event_log(Td *td, DialogId dialog_id, const string &query, int64 from_event_id, int32 limit,
                          const td_api::object_ptr<td_api::chatEventLogFilters> &filters,
                          const vector<UserId> &user_ids, Promise<td_api::object_ptr<td_api::chatEvents>> &&promise);

}  // namespace td
