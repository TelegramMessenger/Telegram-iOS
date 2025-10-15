//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

namespace td {

enum class SecretChatLayer : int32 {
  Default = 73,
  Mtproto2 = 73,
  NewEntities = 101,
  DeleteMessagesOnClose = 123,
  SupportBigFiles = 143,
  SpoilerAndCustomEmojiEntities = 144,
  Current = SpoilerAndCustomEmojiEntities
};

}  // namespace td
