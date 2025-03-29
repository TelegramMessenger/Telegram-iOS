//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/SecretChatDb.h"

namespace td {

SecretChatDb::SecretChatDb(std::shared_ptr<KeyValueSyncInterface> pmc, int32 chat_id)
    : pmc_(std::move(pmc)), chat_id_(chat_id) {
}

}  // namespace td
