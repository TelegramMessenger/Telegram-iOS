//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/NotificationType.h"

#include "td/telegram/AnimationsManager.h"
#include "td/telegram/AudiosManager.h"
#include "td/telegram/DocumentsManager.h"
#include "td/telegram/MessageSender.h"
#include "td/telegram/MessagesManager.h"
#include "td/telegram/PhotoFormat.h"
#include "td/telegram/StickersManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/VideoNotesManager.h"
#include "td/telegram/VideosManager.h"
#include "td/telegram/VoiceNotesManager.h"

#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Slice.h"

#include <tuple>

namespace td {

class NotificationTypeMessage final : public NotificationType {
  bool can_be_delayed() const final {
    return message_id_.is_valid() && message_id_.is_server();
  }

  bool is_temporary() const final {
    return false;
  }

  NotificationObjectId get_object_id() const final {
    return message_id_;
  }

  vector<FileId> get_file_ids(const Td *td) const final {
    return {};
  }

  td_api::object_ptr<td_api::NotificationType> get_notification_type_object(Td *td, DialogId dialog_id) const final {
    auto message_object =
        td->messages_manager_->get_message_object({dialog_id, message_id_}, "get_notification_type_object");
    if (message_object == nullptr) {
      return nullptr;
    }
    return td_api::make_object<td_api::notificationTypeNewMessage>(std::move(message_object), show_preview_);
  }

  StringBuilder &to_string_builder(StringBuilder &string_builder) const final {
    return string_builder << "NewMessageNotification[" << message_id_ << ']';
  }

  MessageId message_id_;
  bool show_preview_;

 public:
  NotificationTypeMessage(MessageId message_id, bool show_preview)
      : message_id_(message_id), show_preview_(show_preview) {
  }
};

class NotificationTypeSecretChat final : public NotificationType {
  bool can_be_delayed() const final {
    return false;
  }

  bool is_temporary() const final {
    return false;
  }

  NotificationObjectId get_object_id() const final {
    return NotificationObjectId();
  }

  vector<FileId> get_file_ids(const Td *td) const final {
    return {};
  }

  td_api::object_ptr<td_api::NotificationType> get_notification_type_object(Td *, DialogId) const final {
    return td_api::make_object<td_api::notificationTypeNewSecretChat>();
  }

  StringBuilder &to_string_builder(StringBuilder &string_builder) const final {
    return string_builder << "NewSecretChatNotification[]";
  }

 public:
  NotificationTypeSecretChat() {
  }
};

class NotificationTypeCall final : public NotificationType {
  bool can_be_delayed() const final {
    return false;
  }

  bool is_temporary() const final {
    return false;
  }

  NotificationObjectId get_object_id() const final {
    return NotificationObjectId::max();
  }

  vector<FileId> get_file_ids(const Td *td) const final {
    return {};
  }

  td_api::object_ptr<td_api::NotificationType> get_notification_type_object(Td *, DialogId) const final {
    return td_api::make_object<td_api::notificationTypeNewCall>(call_id_.get());
  }

  StringBuilder &to_string_builder(StringBuilder &string_builder) const final {
    return string_builder << "NewCallNotification[" << call_id_ << ']';
  }

  CallId call_id_;

 public:
  explicit NotificationTypeCall(CallId call_id) : call_id_(call_id) {
  }
};

class NotificationTypePushMessage final : public NotificationType {
  bool can_be_delayed() const final {
    return false;
  }

  bool is_temporary() const final {
    return true;
  }

  NotificationObjectId get_object_id() const final {
    return message_id_;
  }

  vector<FileId> get_file_ids(const Td *td) const final {
    if (!document_.empty()) {
      return document_.get_file_ids(td);
    }

    return photo_get_file_ids(photo_);
  }

  static td_api::object_ptr<td_api::PushMessageContent> get_push_message_content_object(Td *td, Slice key,
                                                                                        const string &arg,
                                                                                        const Photo &photo,
                                                                                        const Document &document) {
    bool is_pinned = false;
    if (begins_with(key, "PINNED_")) {
      is_pinned = true;
      key = key.substr(7);
    }
    if (key == "MESSAGE") {
      return td_api::make_object<td_api::pushMessageContentHidden>(is_pinned);
    }
    if (key == "MESSAGES") {
      return td_api::make_object<td_api::pushMessageContentMediaAlbum>(to_integer<int32>(arg), true, true, false,
                                                                       false);
    }
    CHECK(key.size() > 8);
    switch (key[8]) {
      case 'A':
        if (key == "MESSAGE_ANIMATION") {
          return td_api::make_object<td_api::pushMessageContentAnimation>(
              td->animations_manager_->get_animation_object(document.file_id), arg, is_pinned);
        }
        if (key == "MESSAGE_AUDIO") {
          return td_api::make_object<td_api::pushMessageContentAudio>(
              td->audios_manager_->get_audio_object(document.file_id), is_pinned);
        }
        if (key == "MESSAGE_AUDIOS") {
          return td_api::make_object<td_api::pushMessageContentMediaAlbum>(to_integer<int32>(arg), false, false, true,
                                                                           false);
        }
        break;
      case 'B':
        if (key == "MESSAGE_BASIC_GROUP_CHAT_CREATE") {
          return td_api::make_object<td_api::pushMessageContentBasicGroupChatCreate>();
        }
        break;
      case 'C':
        if (key == "MESSAGE_CHAT_ADD_MEMBERS") {
          return td_api::make_object<td_api::pushMessageContentChatAddMembers>(arg, false, false);
        }
        if (key == "MESSAGE_CHAT_ADD_MEMBERS_RETURNED") {
          return td_api::make_object<td_api::pushMessageContentChatAddMembers>(arg, false, true);
        }
        if (key == "MESSAGE_CHAT_ADD_MEMBERS_YOU") {
          return td_api::make_object<td_api::pushMessageContentChatAddMembers>(arg, true, false);
        }
        if (key == "MESSAGE_CHAT_CHANGE_PHOTO") {
          return td_api::make_object<td_api::pushMessageContentChatChangePhoto>();
        }
        if (key == "MESSAGE_CHAT_CHANGE_THEME") {
          return td_api::make_object<td_api::pushMessageContentChatSetTheme>(arg);
        }
        if (key == "MESSAGE_CHAT_CHANGE_TITLE") {
          return td_api::make_object<td_api::pushMessageContentChatChangeTitle>(arg);
        }
        if (key == "MESSAGE_CHAT_DELETE_MEMBER") {
          return td_api::make_object<td_api::pushMessageContentChatDeleteMember>(arg, false, false);
        }
        if (key == "MESSAGE_CHAT_DELETE_MEMBER_LEFT") {
          return td_api::make_object<td_api::pushMessageContentChatDeleteMember>(arg, false, true);
        }
        if (key == "MESSAGE_CHAT_DELETE_MEMBER_YOU") {
          return td_api::make_object<td_api::pushMessageContentChatDeleteMember>(arg, true, false);
        }
        if (key == "MESSAGE_CHAT_JOIN_BY_LINK") {
          return td_api::make_object<td_api::pushMessageContentChatJoinByLink>();
        }
        if (key == "MESSAGE_CHAT_JOIN_BY_REQUEST") {
          return td_api::make_object<td_api::pushMessageContentChatJoinByRequest>();
        }
        if (key == "MESSAGE_CHAT_LIVESTREAM_END") {
          return td_api::make_object<td_api::pushMessageContentVideoChatEnded>();
        }
        if (key == "MESSAGE_CHAT_LIVESTREAM_START") {
          return td_api::make_object<td_api::pushMessageContentVideoChatStarted>();
        }
        if (key == "MESSAGE_CHAT_VOICECHAT_END") {
          return td_api::make_object<td_api::pushMessageContentVideoChatEnded>();
        }
        if (key == "MESSAGE_CHAT_VOICECHAT_INVITE") {
          return td_api::make_object<td_api::pushMessageContentInviteVideoChatParticipants>(false);
        }
        if (key == "MESSAGE_CHAT_VOICECHAT_INVITE_YOU") {
          return td_api::make_object<td_api::pushMessageContentInviteVideoChatParticipants>(true);
        }
        if (key == "MESSAGE_CHAT_VOICECHAT_START") {
          return td_api::make_object<td_api::pushMessageContentVideoChatStarted>();
        }
        if (key == "MESSAGE_CONTACT") {
          return td_api::make_object<td_api::pushMessageContentContact>(arg, is_pinned);
        }
        if (key == "MESSAGE_CONTACT_REGISTERED") {
          return td_api::make_object<td_api::pushMessageContentContactRegistered>();
        }
        break;
      case 'D':
        if (key == "MESSAGE_DOCUMENT") {
          return td_api::make_object<td_api::pushMessageContentDocument>(
              td->documents_manager_->get_document_object(document.file_id, PhotoFormat::Jpeg), is_pinned);
        }
        if (key == "MESSAGE_DOCUMENTS") {
          return td_api::make_object<td_api::pushMessageContentMediaAlbum>(to_integer<int32>(arg), false, false, false,
                                                                           true);
        }
        break;
      case 'F':
        if (key == "MESSAGE_FORWARDS") {
          return td_api::make_object<td_api::pushMessageContentMessageForwards>(to_integer<int32>(arg));
        }
        break;
      case 'G':
        if (key == "MESSAGE_GAME") {
          return td_api::make_object<td_api::pushMessageContentGame>(arg, is_pinned);
        }
        if (key == "MESSAGE_GAME_SCORE") {
          int32 score = 0;
          string title;
          if (!is_pinned) {
            string score_str;
            std::tie(score_str, title) = split(arg);
            score = to_integer<int32>(score_str);
          }
          return td_api::make_object<td_api::pushMessageContentGameScore>(title, score, is_pinned);
        }
        if (key == "MESSAGE_GIFTCODE") {
          auto month_count = to_integer<int32>(arg);
          return td_api::make_object<td_api::pushMessageContentPremiumGiftCode>(month_count);
        }
        if (key == "MESSAGE_GIVEAWAY") {
          int32 user_count = 0;
          int32 month_count = 0;
          if (!is_pinned) {
            string user_count_str;
            string month_count_str;
            std::tie(user_count_str, month_count_str) = split(arg);
            user_count = to_integer<int32>(user_count_str);
            month_count = to_integer<int32>(month_count_str);
          }
          return td_api::make_object<td_api::pushMessageContentGiveaway>(
              user_count, is_pinned ? nullptr : td_api::make_object<td_api::giveawayPrizePremium>(month_count),
              is_pinned);
        }
        if (key == "MESSAGE_GIVEAWAY_STARS") {
          int32 user_count = 0;
          int64 star_count = 0;
          if (!is_pinned) {
            string user_count_str;
            string star_count_str;
            std::tie(user_count_str, star_count_str) = split(arg);
            user_count = to_integer<int32>(user_count_str);
            star_count = to_integer<int64>(star_count_str);
          }
          return td_api::make_object<td_api::pushMessageContentGiveaway>(
              user_count, is_pinned ? nullptr : td_api::make_object<td_api::giveawayPrizeStars>(star_count), is_pinned);
        }
        break;
      case 'I':
        if (key == "MESSAGE_INVOICE") {
          return td_api::make_object<td_api::pushMessageContentInvoice>(arg, is_pinned);
        }
        break;
      case 'L':
        if (key == "MESSAGE_LIVE_LOCATION") {
          return td_api::make_object<td_api::pushMessageContentLocation>(false, is_pinned);
        }
        if (key == "MESSAGE_LOCATION") {
          return td_api::make_object<td_api::pushMessageContentLocation>(true, is_pinned);
        }
        break;
      case 'P':
        if (key == "MESSAGE_PAID_MEDIA") {
          int64 star_count = 0;
          if (!is_pinned) {
            star_count = to_integer<int64>(arg);
          }
          return td_api::make_object<td_api::pushMessageContentPaidMedia>(star_count, is_pinned);
        }
        if (key == "MESSAGE_PHOTO") {
          return td_api::make_object<td_api::pushMessageContentPhoto>(get_photo_object(td->file_manager_.get(), photo),
                                                                      arg, false, is_pinned);
        }
        if (key == "MESSAGE_PHOTOS") {
          return td_api::make_object<td_api::pushMessageContentMediaAlbum>(to_integer<int32>(arg), true, false, false,
                                                                           false);
        }
        if (key == "MESSAGE_POLL") {
          return td_api::make_object<td_api::pushMessageContentPoll>(arg, true, is_pinned);
        }
        if (key == "MESSAGE_PROXIMITY") {
          return td_api::make_object<td_api::pushMessageContentProximityAlertTriggered>(to_integer<int32>(arg));
        }
        break;
      case 'Q':
        if (key == "MESSAGE_QUIZ") {
          return td_api::make_object<td_api::pushMessageContentPoll>(arg, false, is_pinned);
        }
        break;
      case 'R':
        if (key == "MESSAGE_RECURRING_PAYMENT") {
          return td_api::make_object<td_api::pushMessageContentRecurringPayment>(arg);
        }
        break;
      case 'S':
        if (key == "MESSAGE_SAME_WALLPAPER") {
          return td_api::make_object<td_api::pushMessageContentChatSetBackground>(true);
        }
        if (key == "MESSAGE_SCREENSHOT_TAKEN") {
          return td_api::make_object<td_api::pushMessageContentScreenshotTaken>();
        }
        if (key == "MESSAGE_SECRET_PHOTO") {
          return td_api::make_object<td_api::pushMessageContentPhoto>(nullptr, arg, true, false);
        }
        if (key == "MESSAGE_SECRET_VIDEO") {
          return td_api::make_object<td_api::pushMessageContentVideo>(nullptr, arg, true, false);
        }
        if (key == "MESSAGE_STARGIFT") {
          auto star_count = to_integer<int64>(arg);
          return td_api::make_object<td_api::pushMessageContentGift>(star_count);
        }
        if (key == "MESSAGE_STARGIFT_TRANSFER") {
          return td_api::make_object<td_api::pushMessageContentUpgradedGift>(false);
        }
        if (key == "MESSAGE_STARGIFT_UPGRADE") {
          return td_api::make_object<td_api::pushMessageContentUpgradedGift>(true);
        }
        if (key == "MESSAGE_STICKER") {
          return td_api::make_object<td_api::pushMessageContentSticker>(
              td->stickers_manager_->get_sticker_object(document.file_id), trim(arg), is_pinned);
        }
        if (key == "MESSAGE_STORY") {
          return td_api::make_object<td_api::pushMessageContentStory>(false, is_pinned);
        }
        if (key == "MESSAGE_STORY_MENTION") {
          return td_api::make_object<td_api::pushMessageContentStory>(true, is_pinned);
        }
        if (key == "MESSAGE_SUGGEST_PHOTO") {
          return td_api::make_object<td_api::pushMessageContentSuggestProfilePhoto>();
        }
        break;
      case 'T':
        if (key == "MESSAGE_TEXT") {
          return td_api::make_object<td_api::pushMessageContentText>(arg, is_pinned);
        }
        break;
      case 'V':
        if (key == "MESSAGE_VIDEO") {
          return td_api::make_object<td_api::pushMessageContentVideo>(
              td->videos_manager_->get_video_object(document.file_id), arg, false, is_pinned);
        }
        if (key == "MESSAGE_VIDEO_NOTE") {
          return td_api::make_object<td_api::pushMessageContentVideoNote>(
              td->video_notes_manager_->get_video_note_object(document.file_id), is_pinned);
        }
        if (key == "MESSAGE_VIDEOS") {
          return td_api::make_object<td_api::pushMessageContentMediaAlbum>(to_integer<int32>(arg), false, true, false,
                                                                           false);
        }
        if (key == "MESSAGE_VOICE_NOTE") {
          return td_api::make_object<td_api::pushMessageContentVoiceNote>(
              td->voice_notes_manager_->get_voice_note_object(document.file_id), is_pinned);
        }
        break;
      case 'W':
        if (key == "MESSAGE_WALLPAPER") {
          return td_api::make_object<td_api::pushMessageContentChatSetBackground>(false);
        }
        break;
      default:
        break;
    }
    LOG(FATAL) << "Have unsupported push notification key " << key;
    return nullptr;
  }

  td_api::object_ptr<td_api::NotificationType> get_notification_type_object(Td *td, DialogId) const final {
    auto sender = get_message_sender_object(td, sender_user_id_, sender_dialog_id_, "get_notification_type_object");
    return td_api::make_object<td_api::notificationTypeNewPushMessage>(
        message_id_.get(), std::move(sender), sender_name_, is_outgoing_,
        get_push_message_content_object(td, key_, arg_, photo_, document_));
  }

  StringBuilder &to_string_builder(StringBuilder &string_builder) const final {
    return string_builder << "NewPushMessageNotification[" << sender_user_id_ << "/" << sender_dialog_id_ << "/\""
                          << sender_name_ << "\", " << message_id_ << ", " << key_ << ", " << arg_ << ", " << photo_
                          << ", " << document_ << ']';
  }

  UserId sender_user_id_;
  DialogId sender_dialog_id_;
  MessageId message_id_;
  string sender_name_;
  string key_;
  string arg_;
  Photo photo_;
  Document document_;
  bool is_outgoing_;

 public:
  NotificationTypePushMessage(UserId sender_user_id, DialogId sender_dialog_id, string sender_name, bool is_outgoing,
                              MessageId message_id, string key, string arg, Photo photo, Document document)
      : sender_user_id_(sender_user_id)
      , sender_dialog_id_(sender_dialog_id)
      , message_id_(message_id)
      , sender_name_(std::move(sender_name))
      , key_(std::move(key))
      , arg_(std::move(arg))
      , photo_(std::move(photo))
      , document_(std::move(document))
      , is_outgoing_(is_outgoing) {
  }
};

unique_ptr<NotificationType> create_new_message_notification(MessageId message_id, bool show_preview) {
  return make_unique<NotificationTypeMessage>(message_id, show_preview);
}

unique_ptr<NotificationType> create_new_secret_chat_notification() {
  return make_unique<NotificationTypeSecretChat>();
}

unique_ptr<NotificationType> create_new_call_notification(CallId call_id) {
  return make_unique<NotificationTypeCall>(call_id);
}

unique_ptr<NotificationType> create_new_push_message_notification(UserId sender_user_id, DialogId sender_dialog_id,
                                                                  string sender_name, bool is_outgoing,
                                                                  MessageId message_id, string key, string arg,
                                                                  Photo photo, Document document) {
  return td::make_unique<NotificationTypePushMessage>(sender_user_id, sender_dialog_id, std::move(sender_name),
                                                      is_outgoing, message_id, std::move(key), std::move(arg),
                                                      std::move(photo), std::move(document));
}

}  // namespace td
