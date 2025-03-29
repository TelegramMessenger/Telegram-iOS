//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/MessageSource.h"

namespace td {

StringBuilder &operator<<(StringBuilder &string_builder, MessageSource source) {
  switch (source) {
    case MessageSource::Auto:
      return string_builder << "Auto";
    case MessageSource::DialogHistory:
      return string_builder << "ChatHistory";
    case MessageSource::MessageThreadHistory:
      return string_builder << "MessageThreadHistory";
    case MessageSource::ForumTopicHistory:
      return string_builder << "ForumTopicHistory";
    case MessageSource::HistoryPreview:
      return string_builder << "HistoryPreview";
    case MessageSource::DialogList:
      return string_builder << "DialogList";
    case MessageSource::Search:
      return string_builder << "Search";
    case MessageSource::DialogEventLog:
      return string_builder << "DialogEventLog";
    case MessageSource::Notification:
      return string_builder << "Notification";
    case MessageSource::Screenshot:
      return string_builder << "Screenshot";
    case MessageSource::Other:
      return string_builder << "Other";
    default:
      UNREACHABLE();
  }
}

MessageSource get_message_source(const td_api::object_ptr<td_api::MessageSource> &source) {
  if (source == nullptr) {
    return MessageSource::Auto;
  }
  switch (source->get_id()) {
    case td_api::messageSourceChatHistory::ID:
      return MessageSource::DialogHistory;
    case td_api::messageSourceMessageThreadHistory::ID:
      return MessageSource::MessageThreadHistory;
    case td_api::messageSourceForumTopicHistory::ID:
      return MessageSource::ForumTopicHistory;
    case td_api::messageSourceHistoryPreview::ID:
      return MessageSource::HistoryPreview;
    case td_api::messageSourceChatList::ID:
      return MessageSource::DialogList;
    case td_api::messageSourceSearch::ID:
      return MessageSource::Search;
    case td_api::messageSourceChatEventLog::ID:
      return MessageSource::DialogEventLog;
    case td_api::messageSourceNotification::ID:
      return MessageSource::Notification;
    case td_api::messageSourceScreenshot::ID:
      return MessageSource::Screenshot;
    case td_api::messageSourceOther::ID:
      return MessageSource::Other;
    default:
      UNREACHABLE();
      return MessageSource::Other;
  }
}

}  // namespace td
