//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/VerificationStatus.h"

namespace td {

td_api::object_ptr<td_api::verificationStatus> get_verification_status_object(
    Td *td, bool is_verified, bool is_scam, bool is_fake, CustomEmojiId bot_verification_custom_emoji_id) {
  if (!is_verified && !is_scam && !is_fake && !bot_verification_custom_emoji_id.is_valid()) {
    return nullptr;
  }
  return td_api::make_object<td_api::verificationStatus>(is_verified, is_scam, is_fake,
                                                         bot_verification_custom_emoji_id.get());
}

}  // namespace td
