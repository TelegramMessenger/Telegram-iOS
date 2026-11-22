//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"
#include "td/telegram/UserId.h"

#include "td/utils/common.h"
#include "td/utils/Promise.h"

namespace td {

class Td;

void get_user_info(Td *td, UserId user_id, Promise<td_api::object_ptr<td_api::userSupportInfo>> &&promise);

void set_user_info(Td *td, UserId user_id, td_api::object_ptr<td_api::formattedText> &&message,
                   Promise<td_api::object_ptr<td_api::userSupportInfo>> &&promise);

void get_support_name(Td *td, Promise<string> &&promise);

}  // namespace td
