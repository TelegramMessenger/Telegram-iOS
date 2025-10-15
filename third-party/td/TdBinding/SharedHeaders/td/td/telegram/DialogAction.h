//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/MessageContentType.h"
#include "td/telegram/secret_api.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

class DialogAction {
  enum class Type : int32 {
    Cancel,
    Typing,
    RecordingVideo,
    UploadingVideo,
    RecordingVoiceNote,
    UploadingVoiceNote,
    UploadingPhoto,
    UploadingDocument,
    ChoosingLocation,
    ChoosingContact,
    StartPlayingGame,
    RecordingVideoNote,
    UploadingVideoNote,
    SpeakingInVoiceChat,
    ImportingMessages,
    ChoosingSticker,
    WatchingAnimations,
    ClickingAnimatedEmoji
  };
  Type type_ = Type::Cancel;
  int32 progress_ = 0;
  string emoji_;

  DialogAction(Type type, int32 progress);

  void init(Type type);

  void init(Type type, int32 progress);

  void init(Type type, string emoji);

  void init(Type type, int32 message_id, string emoji, const string &data);

  static bool is_valid_emoji(string &emoji);

 public:
  DialogAction() = default;

  explicit DialogAction(td_api::object_ptr<td_api::ChatAction> &&action);

  explicit DialogAction(telegram_api::object_ptr<telegram_api::SendMessageAction> &&action);

  tl_object_ptr<telegram_api::SendMessageAction> get_input_send_message_action() const;

  tl_object_ptr<secret_api::SendMessageAction> get_secret_input_send_message_action() const;

  td_api::object_ptr<td_api::ChatAction> get_chat_action_object() const;

  bool is_canceled_by_message_of_type(MessageContentType message_content_type) const;

  static DialogAction get_uploading_action(MessageContentType message_content_type, int32 progress);

  static DialogAction get_typing_action();

  static DialogAction get_speaking_action();

  int32 get_importing_messages_action_progress() const;

  string get_watching_animations_emoji() const;

  struct ClickingAnimateEmojiInfo {
    int32 message_id = 0;
    string emoji;
    string data;
  };
  ClickingAnimateEmojiInfo get_clicking_animated_emoji_action_info() const;

  friend bool operator==(const DialogAction &lhs, const DialogAction &rhs) {
    return lhs.type_ == rhs.type_ && lhs.progress_ == rhs.progress_ && lhs.emoji_ == rhs.emoji_;
  }

  friend StringBuilder &operator<<(StringBuilder &string_builder, const DialogAction &action);
};

inline bool operator!=(const DialogAction &lhs, const DialogAction &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const DialogAction &action);

}  // namespace td
