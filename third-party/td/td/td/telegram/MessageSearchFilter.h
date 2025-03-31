//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

// append only before Size
enum class MessageSearchFilter : int32 {
  Empty,
  Animation,
  Audio,
  Document,
  Photo,
  Video,
  VoiceNote,
  PhotoAndVideo,
  Url,
  ChatPhoto,
  Call,
  MissedCall,
  VideoNote,
  VoiceAndVideoNote,
  Mention,
  UnreadMention,
  FailedToSend,
  Pinned,
  UnreadReaction,
  Size
};

inline constexpr size_t message_search_filter_count() {
  return static_cast<int32>(MessageSearchFilter::Size) - 1;
}

inline int32 message_search_filter_index(MessageSearchFilter filter) {
  CHECK(filter != MessageSearchFilter::Empty);
  return static_cast<int32>(filter) - 1;
}

inline int32 message_search_filter_index_mask(MessageSearchFilter filter) {
  if (filter == MessageSearchFilter::Empty) {
    return 0;
  }
  return 1 << message_search_filter_index(filter);
}

inline int32 call_message_search_filter_index(MessageSearchFilter filter) {
  CHECK(filter == MessageSearchFilter::Call || filter == MessageSearchFilter::MissedCall);
  return static_cast<int32>(filter) - static_cast<int32>(MessageSearchFilter::Call);
}

tl_object_ptr<telegram_api::MessagesFilter> get_input_messages_filter(MessageSearchFilter filter);

MessageSearchFilter get_message_search_filter(const tl_object_ptr<td_api::SearchMessagesFilter> &filter);

StringBuilder &operator<<(StringBuilder &string_builder, MessageSearchFilter filter);

}  // namespace td
