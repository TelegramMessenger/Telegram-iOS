//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/AnimationsManager.h"
#include "td/telegram/AttachMenuManager.h"
#include "td/telegram/BackgroundManager.h"
#include "td/telegram/BotInfoManager.h"
#include "td/telegram/ChannelId.h"
#include "td/telegram/ChatId.h"
#include "td/telegram/ChatManager.h"
#include "td/telegram/FileReferenceManager.h"
#include "td/telegram/files/FileSourceId.h"
#include "td/telegram/MessageFullId.h"
#include "td/telegram/MessagesManager.h"
#include "td/telegram/NotificationSettingsManager.h"
#include "td/telegram/QuickReplyManager.h"
#include "td/telegram/QuickReplyMessageFullId.h"
#include "td/telegram/StarManager.h"
#include "td/telegram/StickersManager.h"
#include "td/telegram/StoryFullId.h"
#include "td/telegram/StoryManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/UserId.h"
#include "td/telegram/UserManager.h"
#include "td/telegram/WebAppManager.h"
#include "td/telegram/WebPagesManager.h"

#include "td/utils/common.h"
#include "td/utils/overloaded.h"
#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void FileReferenceManager::store_file_source(FileSourceId file_source_id, StorerT &storer) const {
  auto index = static_cast<size_t>(file_source_id.get()) - 1;
  CHECK(index < file_sources_.size());
  auto &source = file_sources_[index];
  td::store(source.get_offset(), storer);
  source.visit(overloaded([&](const FileSourceMessage &source) { td::store(source.message_full_id, storer); },
                          [&](const FileSourceUserPhoto &source) {
                            td::store(source.user_id, storer);
                            td::store(source.photo_id, storer);
                          },
                          [&](const FileSourceChatPhoto &source) { td::store(source.chat_id, storer); },
                          [&](const FileSourceChannelPhoto &source) { td::store(source.channel_id, storer); },
                          [&](const FileSourceWallpapers &source) {},
                          [&](const FileSourceWebPage &source) { td::store(source.url, storer); },
                          [&](const FileSourceSavedAnimations &source) {},
                          [&](const FileSourceRecentStickers &source) { td::store(source.is_attached, storer); },
                          [&](const FileSourceFavoriteStickers &source) {},
                          [&](const FileSourceBackground &source) {
                            td::store(source.background_id, storer);
                            td::store(source.access_hash, storer);
                          },
                          [&](const FileSourceChatFull &source) { td::store(source.chat_id, storer); },
                          [&](const FileSourceChannelFull &source) { td::store(source.channel_id, storer); },
                          [&](const FileSourceAppConfig &source) {}, [&](const FileSourceSavedRingtones &source) {},
                          [&](const FileSourceUserFull &source) { td::store(source.user_id, storer); },
                          [&](const FileSourceAttachMenuBot &source) { td::store(source.user_id, storer); },
                          [&](const FileSourceWebApp &source) {
                            td::store(source.user_id, storer);
                            td::store(source.short_name, storer);
                          },
                          [&](const FileSourceStory &source) { td::store(source.story_full_id, storer); },
                          [&](const FileSourceQuickReplyMessage &source) { td::store(source.message_full_id, storer); },
                          [&](const FileSourceStarTransaction &source) {
                            td::store(source.dialog_id, storer);
                            td::store(source.transaction_id, storer);
                            td::store(source.is_refund, storer);
                          },
                          [&](const FileSourceBotMediaPreview &source) { td::store(source.bot_user_id, storer); },
                          [&](const FileSourceBotMediaPreviewInfo &source) {
                            td::store(source.bot_user_id, storer);
                            td::store(source.language_code, storer);
                          }));
}

template <class ParserT>
FileSourceId FileReferenceManager::parse_file_source(Td *td, ParserT &parser) {
  auto type = parser.fetch_int();
  switch (type) {
    case 0: {
      MessageFullId message_full_id;
      td::parse(message_full_id, parser);
      return td->messages_manager_->get_message_file_source_id(message_full_id);
    }
    case 1: {
      UserId user_id;
      int64 photo_id;
      td::parse(user_id, parser);
      td::parse(photo_id, parser);
      return td->user_manager_->get_user_profile_photo_file_source_id(user_id, photo_id);
    }
    case 2: {
      ChatId chat_id;
      td::parse(chat_id, parser);
      return FileSourceId();  // there is no need to repair chat photos
    }
    case 3: {
      ChannelId channel_id;
      td::parse(channel_id, parser);
      return FileSourceId();  // there is no need to repair channel photos
    }
    case 4:
      return FileSourceId();  // there is no way to repair old wallpapers
    case 5: {
      string url;
      td::parse(url, parser);
      return td->web_pages_manager_->get_url_file_source_id(url);
    }
    case 6:
      return td->animations_manager_->get_saved_animations_file_source_id();
    case 7: {
      bool is_attached;
      td::parse(is_attached, parser);
      return td->stickers_manager_->get_recent_stickers_file_source_id(is_attached);
    }
    case 8:
      return td->stickers_manager_->get_favorite_stickers_file_source_id();
    case 9: {
      BackgroundId background_id;
      int64 access_hash;
      td::parse(background_id, parser);
      td::parse(access_hash, parser);
      return td->background_manager_->get_background_file_source_id(background_id, access_hash);
    }
    case 10: {
      ChatId chat_id;
      td::parse(chat_id, parser);
      return td->chat_manager_->get_chat_full_file_source_id(chat_id);
    }
    case 11: {
      ChannelId channel_id;
      td::parse(channel_id, parser);
      return td->chat_manager_->get_channel_full_file_source_id(channel_id);
    }
    case 12:
      return td->stickers_manager_->get_app_config_file_source_id();
    case 13:
      return td->notification_settings_manager_->get_saved_ringtones_file_source_id();
    case 14: {
      UserId user_id;
      td::parse(user_id, parser);
      return td->user_manager_->get_user_full_file_source_id(user_id);
    }
    case 15: {
      UserId user_id;
      td::parse(user_id, parser);
      return td->attach_menu_manager_->get_attach_menu_bot_file_source_id(user_id);
    }
    case 16: {
      UserId user_id;
      string short_name;
      td::parse(user_id, parser);
      td::parse(short_name, parser);
      return td->web_app_manager_->get_web_app_file_source_id(user_id, short_name);
    }
    case 17: {
      StoryFullId story_full_id;
      td::parse(story_full_id, parser);
      return td->story_manager_->get_story_file_source_id(story_full_id);
    }
    case 18: {
      QuickReplyMessageFullId message_full_id;
      td::parse(message_full_id, parser);
      return td->quick_reply_manager_->get_quick_reply_message_file_source_id(message_full_id);
    }
    case 19: {
      DialogId dialog_id;
      string transaction_id;
      bool is_refund;
      td::parse(dialog_id, parser);
      td::parse(transaction_id, parser);
      td::parse(is_refund, parser);
      return td->star_manager_->get_star_transaction_file_source_id(dialog_id, transaction_id, is_refund);
    }
    case 20: {
      UserId bot_user_id;
      td::parse(bot_user_id, parser);
      return td->bot_info_manager_->get_bot_media_preview_file_source_id(bot_user_id);
    }
    case 21: {
      UserId bot_user_id;
      string language_code;
      td::parse(bot_user_id, parser);
      td::parse(language_code, parser);
      return td->bot_info_manager_->get_bot_media_preview_info_file_source_id(bot_user_id, language_code);
    }
    default:
      parser.set_error("Invalid type in FileSource");
      return FileSourceId();
  }
}

}  // namespace td
