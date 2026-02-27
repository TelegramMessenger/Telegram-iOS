//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"

#include "td/utils/common.h"
#include "td/utils/Promise.h"

namespace td {

class Td;

void send_bot_custom_query(Td *td, const string &method, const string &parameters,
                           Promise<td_api::object_ptr<td_api::customRequestResult>> &&promise);

void answer_bot_custom_query(Td *td, int64 custom_query_id, const string &data, Promise<Unit> &&promise);

void set_bot_updates_status(Td *td, int32 pending_update_count, const string &error_message, Promise<Unit> &&promise);

}  // namespace td
