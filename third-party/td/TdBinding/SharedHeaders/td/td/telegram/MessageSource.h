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

enum class MessageSource : int32 {
  Auto,
  DialogHistory,
  MessageThreadHistory,
  ForumTopicHistory,
  HistoryPreview,
  DialogList,
  Search,
  DialogEventLog,
  Notification,
  Screenshot,
  Other
};

StringBuilder &operator<<(StringBuilder &string_builder, MessageSource source);

MessageSource get_message_source(const td_api::object_ptr<td_api::MessageSource> &source);

}  // namespace td
