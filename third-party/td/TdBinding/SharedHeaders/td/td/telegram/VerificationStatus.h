//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/CustomEmojiId.h"
#include "td/telegram/td_api.h"

namespace td {

class Td;

td_api::object_ptr<td_api::verificationStatus> get_verification_status_object(
    Td *td, bool is_verified, bool is_scam, bool is_fake, CustomEmojiId bot_verification_custom_emoji_id);

}  // namespace td
