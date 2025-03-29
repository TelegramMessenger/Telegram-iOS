//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/MessageSearchFilter.h"

#include "td/utils/common.h"

namespace td {

tl_object_ptr<telegram_api::MessagesFilter> get_input_messages_filter(MessageSearchFilter filter) {
  switch (filter) {
    case MessageSearchFilter::Empty:
      return make_tl_object<telegram_api::inputMessagesFilterEmpty>();
    case MessageSearchFilter::Animation:
      return make_tl_object<telegram_api::inputMessagesFilterGif>();
    case MessageSearchFilter::Audio:
      return make_tl_object<telegram_api::inputMessagesFilterMusic>();
    case MessageSearchFilter::Document:
      return make_tl_object<telegram_api::inputMessagesFilterDocument>();
    case MessageSearchFilter::Photo:
      return make_tl_object<telegram_api::inputMessagesFilterPhotos>();
    case MessageSearchFilter::Video:
      return make_tl_object<telegram_api::inputMessagesFilterVideo>();
    case MessageSearchFilter::VoiceNote:
      return make_tl_object<telegram_api::inputMessagesFilterVoice>();
    case MessageSearchFilter::PhotoAndVideo:
      return make_tl_object<telegram_api::inputMessagesFilterPhotoVideo>();
    case MessageSearchFilter::Url:
      return make_tl_object<telegram_api::inputMessagesFilterUrl>();
    case MessageSearchFilter::ChatPhoto:
      return make_tl_object<telegram_api::inputMessagesFilterChatPhotos>();
    case MessageSearchFilter::Call:
      return make_tl_object<telegram_api::inputMessagesFilterPhoneCalls>(0, false);
    case MessageSearchFilter::MissedCall:
      return make_tl_object<telegram_api::inputMessagesFilterPhoneCalls>(0, true);
    case MessageSearchFilter::VideoNote:
      return make_tl_object<telegram_api::inputMessagesFilterRoundVideo>();
    case MessageSearchFilter::VoiceAndVideoNote:
      return make_tl_object<telegram_api::inputMessagesFilterRoundVoice>();
    case MessageSearchFilter::Mention:
      return make_tl_object<telegram_api::inputMessagesFilterMyMentions>();
    case MessageSearchFilter::Pinned:
      return make_tl_object<telegram_api::inputMessagesFilterPinned>();
    case MessageSearchFilter::UnreadMention:
    case MessageSearchFilter::FailedToSend:
    case MessageSearchFilter::UnreadReaction:
    default:
      UNREACHABLE();
      return nullptr;
  }
}

MessageSearchFilter get_message_search_filter(const tl_object_ptr<td_api::SearchMessagesFilter> &filter) {
  if (filter == nullptr) {
    return MessageSearchFilter::Empty;
  }
  switch (filter->get_id()) {
    case td_api::searchMessagesFilterEmpty::ID:
      return MessageSearchFilter::Empty;
    case td_api::searchMessagesFilterAnimation::ID:
      return MessageSearchFilter::Animation;
    case td_api::searchMessagesFilterAudio::ID:
      return MessageSearchFilter::Audio;
    case td_api::searchMessagesFilterDocument::ID:
      return MessageSearchFilter::Document;
    case td_api::searchMessagesFilterPhoto::ID:
      return MessageSearchFilter::Photo;
    case td_api::searchMessagesFilterVideo::ID:
      return MessageSearchFilter::Video;
    case td_api::searchMessagesFilterVoiceNote::ID:
      return MessageSearchFilter::VoiceNote;
    case td_api::searchMessagesFilterPhotoAndVideo::ID:
      return MessageSearchFilter::PhotoAndVideo;
    case td_api::searchMessagesFilterUrl::ID:
      return MessageSearchFilter::Url;
    case td_api::searchMessagesFilterChatPhoto::ID:
      return MessageSearchFilter::ChatPhoto;
    case td_api::searchMessagesFilterVideoNote::ID:
      return MessageSearchFilter::VideoNote;
    case td_api::searchMessagesFilterVoiceAndVideoNote::ID:
      return MessageSearchFilter::VoiceAndVideoNote;
    case td_api::searchMessagesFilterMention::ID:
      return MessageSearchFilter::Mention;
    case td_api::searchMessagesFilterUnreadMention::ID:
      return MessageSearchFilter::UnreadMention;
    case td_api::searchMessagesFilterFailedToSend::ID:
      return MessageSearchFilter::FailedToSend;
    case td_api::searchMessagesFilterPinned::ID:
      return MessageSearchFilter::Pinned;
    case td_api::searchMessagesFilterUnreadReaction::ID:
      return MessageSearchFilter::UnreadReaction;
    default:
      UNREACHABLE();
      return MessageSearchFilter::Empty;
  }
}

StringBuilder &operator<<(StringBuilder &string_builder, MessageSearchFilter filter) {
  switch (filter) {
    case MessageSearchFilter::Empty:
      return string_builder << "Empty";
    case MessageSearchFilter::Animation:
      return string_builder << "Animation";
    case MessageSearchFilter::Audio:
      return string_builder << "Audio";
    case MessageSearchFilter::Document:
      return string_builder << "Document";
    case MessageSearchFilter::Photo:
      return string_builder << "Photo";
    case MessageSearchFilter::Video:
      return string_builder << "Video";
    case MessageSearchFilter::VoiceNote:
      return string_builder << "VoiceNote";
    case MessageSearchFilter::PhotoAndVideo:
      return string_builder << "PhotoAndVideo";
    case MessageSearchFilter::Url:
      return string_builder << "Url";
    case MessageSearchFilter::ChatPhoto:
      return string_builder << "ChatPhoto";
    case MessageSearchFilter::Call:
      return string_builder << "Call";
    case MessageSearchFilter::MissedCall:
      return string_builder << "MissedCall";
    case MessageSearchFilter::VideoNote:
      return string_builder << "VideoNote";
    case MessageSearchFilter::VoiceAndVideoNote:
      return string_builder << "VoiceAndVideoNote";
    case MessageSearchFilter::Mention:
      return string_builder << "Mention";
    case MessageSearchFilter::UnreadMention:
      return string_builder << "UnreadMention";
    case MessageSearchFilter::FailedToSend:
      return string_builder << "FailedToSend";
    case MessageSearchFilter::Pinned:
      return string_builder << "Pinned";
    case MessageSearchFilter::UnreadReaction:
      return string_builder << "UnreadReaction";
    default:
      UNREACHABLE();
      return string_builder;
  }
}

}  // namespace td
