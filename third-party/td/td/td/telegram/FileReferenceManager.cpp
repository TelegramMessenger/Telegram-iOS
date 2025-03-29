//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/FileReferenceManager.h"

#include "td/telegram/AnimationsManager.h"
#include "td/telegram/AttachMenuManager.h"
#include "td/telegram/BackgroundManager.h"
#include "td/telegram/BotInfoManager.h"
#include "td/telegram/ChatManager.h"
#include "td/telegram/ConfigManager.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/files/FileManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/MessagesManager.h"
#include "td/telegram/NotificationSettingsManager.h"
#include "td/telegram/QuickReplyManager.h"
#include "td/telegram/StarManager.h"
#include "td/telegram/StickerSetId.h"
#include "td/telegram/StickersManager.h"
#include "td/telegram/StoryManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/UserManager.h"
#include "td/telegram/WebAppManager.h"
#include "td/telegram/WebPageId.h"
#include "td/telegram/WebPagesManager.h"

#include "td/utils/algorithm.h"
#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/overloaded.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Time.h"

namespace td {

int VERBOSITY_NAME(file_references) = VERBOSITY_NAME(INFO);

FileReferenceManager::FileReferenceManager(ActorShared<> parent) : parent_(std::move(parent)) {
}

FileReferenceManager::~FileReferenceManager() {
  Scheduler::instance()->destroy_on_scheduler(G()->get_gc_scheduler_id(), file_sources_, nodes_);
}

void FileReferenceManager::tear_down() {
  parent_.reset();
}

bool FileReferenceManager::is_file_reference_error(const Status &error) {
  return error.is_error() && error.code() == 400 && begins_with(error.message(), "FILE_REFERENCE_");
}

FileReferenceManager::FileReferenceErrorSource FileReferenceManager::get_file_reference_error_source(
    const Status &error) {
  if (!is_file_reference_error(error)) {
    return {0, false};
  }
  auto offset = Slice("FILE_REFERENCE_").size();
  Slice message = error.message();
  if (message.size() <= offset) {
    return {0, false};
  }
  message = message.substr(offset);
  if (!is_digit(message[0])) {
    if (message[0] == '_') {
      message = message.substr(1);
    }
    return {0, begins_with(message, "COVER_")};
  }
  auto underscore_pos = message.find('_');
  auto is_cover = underscore_pos != Slice::npos && begins_with(message.substr(underscore_pos + 1), "COVER_");
  return {to_integer<size_t>(message) + 1, is_cover};
}

/*
fileSourceMessage chat_id:int53 message_id:int53 = FileSource;                             // get_message_from_server
fileSourceUserProfilePhoto user_id:int53 photo_id:int64 = FileSource;                      // photos.getUserPhotos
fileSourceBasicGroupPhoto basic_group_id:int53 = FileSource;                               // no need to repair
fileSourceSupergroupPhoto supergroup_id:int53 = FileSource;                                // no need to repair
fileSourceWebPage url:string = FileSource;                                                 // messages.getWebPage
fileSourceWallpapers = FileSource;                                                         // can't be repaired
fileSourceSavedAnimations = FileSource;                                                    // messages.getSavedGifs
fileSourceRecentStickers is_attached:Bool = FileSource;                                    // messages.getRecentStickers, not reliable
fileSourceFavoriteStickers = FileSource;                                                   // messages.getFavedStickers, not reliable
fileSourceBackground background_id:int64 access_hash:int64 = FileSource;                   // account.getWallPaper
fileSourceBasicGroupFull basic_group_id:int53 = FileSource;                                // messages.getFullChat
fileSourceSupergroupFull supergroup_id:int53 = FileSource;                                 // messages.getFullChannel
fileSourceAppConfig = FileSource;                                                          // help.getAppConfig, not reliable
fileSourceSavedRingtones = FileSource;                                                     // account.getSavedRingtones
fileSourceUserFull = FileSource;                                                           // users.getFullUser
fileSourceAttachmentMenuBot user_id:int53 = FileSource;                                    // messages.getAttachMenuBot
fileSourceWebApp user_id:int53 short_name:string = FileSource;                             // messages.getAttachMenuBot
fileSourceStory chat_id:int53 story_id:int32 = FileSource;                                 // stories.getStoriesByID
fileSourceQuickReplyMessage shortcut_id:int32 message_id:int53 = FileSource;               // messages.getQuickReplyMessages
fileSourceStarTransaction chat_id:int53 transaction_id:string is_refund:Bool = FileSource; // payments.getStarsTransactionsByID
fileSourceBotMediaPreview bot_user_id:int53 = FileSource;                                  // bots.getPreviewMedias
fileSourceBotMediaPreviewInfo bot_user_id:int53 language_code:string = FileSource;         // bots.getPreviewMediaInfo
*/

FileSourceId FileReferenceManager::get_current_file_source_id() const {
  return FileSourceId(narrow_cast<int32>(file_sources_.size()));
}

template <class T>
FileSourceId FileReferenceManager::add_file_source_id(T &source, Slice source_str) {
  file_sources_.emplace_back(std::move(source));
  VLOG(file_references) << "Create file source " << file_sources_.size() << " for " << source_str;
  return get_current_file_source_id();
}

FileSourceId FileReferenceManager::create_message_file_source(MessageFullId message_full_id) {
  FileSourceMessage source{message_full_id};
  return add_file_source_id(source, PSLICE() << message_full_id);
}

FileSourceId FileReferenceManager::create_user_photo_file_source(UserId user_id, int64 photo_id) {
  FileSourceUserPhoto source{photo_id, user_id};
  return add_file_source_id(source, PSLICE() << "photo " << photo_id << " of " << user_id);
}

FileSourceId FileReferenceManager::create_web_page_file_source(string url) {
  FileSourceWebPage source{std::move(url)};
  auto source_str = PSTRING() << "web page of " << source.url;
  return add_file_source_id(source, source_str);
}

FileSourceId FileReferenceManager::create_saved_animations_file_source() {
  FileSourceSavedAnimations source;
  return add_file_source_id(source, "saved animations");
}

FileSourceId FileReferenceManager::create_recent_stickers_file_source(bool is_attached) {
  FileSourceRecentStickers source{is_attached};
  return add_file_source_id(source, PSLICE() << "recent " << (is_attached ? "attached " : "") << "stickers");
}

FileSourceId FileReferenceManager::create_favorite_stickers_file_source() {
  FileSourceFavoriteStickers source;
  return add_file_source_id(source, "favorite stickers");
}

FileSourceId FileReferenceManager::create_background_file_source(BackgroundId background_id, int64 access_hash) {
  FileSourceBackground source{background_id, access_hash};
  return add_file_source_id(source, PSLICE() << background_id);
}

FileSourceId FileReferenceManager::create_chat_full_file_source(ChatId chat_id) {
  FileSourceChatFull source{chat_id};
  return add_file_source_id(source, PSLICE() << "full " << chat_id);
}

FileSourceId FileReferenceManager::create_channel_full_file_source(ChannelId channel_id) {
  FileSourceChannelFull source{channel_id};
  return add_file_source_id(source, PSLICE() << "full " << channel_id);
}

FileSourceId FileReferenceManager::create_app_config_file_source() {
  FileSourceAppConfig source;
  return add_file_source_id(source, "app config");
}

FileSourceId FileReferenceManager::create_saved_ringtones_file_source() {
  FileSourceSavedRingtones source;
  return add_file_source_id(source, "saved notification sounds");
}

FileSourceId FileReferenceManager::create_user_full_file_source(UserId user_id) {
  FileSourceUserFull source{user_id};
  return add_file_source_id(source, PSLICE() << "full " << user_id);
}

FileSourceId FileReferenceManager::create_attach_menu_bot_file_source(UserId user_id) {
  FileSourceAttachMenuBot source{user_id};
  return add_file_source_id(source, PSLICE() << "attachment menu bot " << user_id);
}

FileSourceId FileReferenceManager::create_web_app_file_source(UserId user_id, const string &short_name) {
  FileSourceWebApp source{user_id, short_name};
  return add_file_source_id(source, PSLICE() << "Web App " << user_id << '/' << short_name);
}

FileSourceId FileReferenceManager::create_story_file_source(StoryFullId story_full_id) {
  FileSourceStory source{story_full_id};
  return add_file_source_id(source, PSLICE() << story_full_id);
}

FileSourceId FileReferenceManager::create_quick_reply_message_file_source(QuickReplyMessageFullId message_full_id) {
  FileSourceQuickReplyMessage source{message_full_id};
  return add_file_source_id(source, PSLICE() << "quick reply " << message_full_id);
}

FileSourceId FileReferenceManager::create_star_transaction_file_source(DialogId dialog_id, const string &transaction_id,
                                                                       bool is_refund) {
  FileSourceStarTransaction source{dialog_id, transaction_id, is_refund};
  return add_file_source_id(source, PSLICE() << "star transaction " << transaction_id << " in " << dialog_id);
}

FileSourceId FileReferenceManager::create_bot_media_preview_file_source(UserId bot_user_id) {
  FileSourceBotMediaPreview source{bot_user_id};
  return add_file_source_id(source, PSLICE() << "bot media preview " << bot_user_id);
}

FileSourceId FileReferenceManager::create_bot_media_preview_info_file_source(UserId bot_user_id,
                                                                             const string &language_code) {
  FileSourceBotMediaPreviewInfo source{bot_user_id, language_code};
  return add_file_source_id(source, PSLICE() << "bot media preview info " << bot_user_id << " for " << language_code);
}

FileReferenceManager::Node &FileReferenceManager::add_node(NodeId node_id) {
  CHECK(node_id.is_valid());
  auto &node = nodes_[node_id];
  if (node == nullptr) {
    node = make_unique<Node>();
  }
  return *node;
}

bool FileReferenceManager::add_file_source(NodeId node_id, FileSourceId file_source_id, const char *source) {
  auto &node = add_node(node_id);
  bool is_added = node.file_source_ids.add(file_source_id);
  VLOG(file_references) << "Add " << (is_added ? "new" : "old") << ' ' << file_source_id << " for file " << node_id
                        << " from " << source;
  return is_added;
}

bool FileReferenceManager::remove_file_source(NodeId node_id, FileSourceId file_source_id, const char *source) {
  CHECK(node_id.is_valid());
  auto *node = nodes_.get_pointer(node_id);
  bool is_removed = node != nullptr && node->file_source_ids.remove(file_source_id);
  if (is_removed) {
    VLOG(file_references) << "Remove " << file_source_id << " from file " << node_id << " from " << source;
  } else {
    VLOG(file_references) << "Can't find " << file_source_id << " from file " << node_id << " to remove it from "
                          << source;
  }
  return is_removed;
}

vector<FileSourceId> FileReferenceManager::get_some_file_sources(NodeId node_id) {
  auto *node = nodes_.get_pointer(node_id);
  if (node == nullptr) {
    return {};
  }
  return node->file_source_ids.get_some_elements();
}

vector<MessageFullId> FileReferenceManager::get_some_message_file_sources(NodeId node_id) {
  auto file_source_ids = get_some_file_sources(node_id);

  vector<MessageFullId> result;
  for (auto file_source_id : file_source_ids) {
    auto index = static_cast<size_t>(file_source_id.get()) - 1;
    CHECK(index < file_sources_.size());
    const auto &file_source = file_sources_[index];
    if (file_source.get_offset() == 0) {
      result.push_back(file_source.get<FileSourceMessage>().message_full_id);
    }
  }
  return result;
}

void FileReferenceManager::merge(NodeId to_node_id, NodeId from_node_id) {
  auto *from_node_ptr = nodes_.get_pointer(from_node_id);
  if (from_node_ptr == nullptr) {
    return;
  }
  auto &from = *from_node_ptr;

  auto &to = add_node(to_node_id);
  VLOG(file_references) << "Merge " << to.file_source_ids.size() << " and " << from.file_source_ids.size()
                        << " sources of files " << to_node_id << " and " << from_node_id;
  CHECK(!to.query || to.query->proxy.is_empty());
  CHECK(!from.query || from.query->proxy.is_empty());
  if (to.query || from.query) {
    if (!to.query) {
      to.query = make_unique<Query>();
      to.query->generation = ++query_generation_;
    }
    if (from.query) {
      combine(to.query->promises, std::move(from.query->promises));
      to.query->active_queries += from.query->active_queries;
      from.query->proxy = Destination(to_node_id, to.query->generation);
    }
  }
  to.file_source_ids.merge(std::move(from.file_source_ids));
  run_node(to_node_id);
  run_node(from_node_id);
}

void FileReferenceManager::run_node(NodeId node_id) {
  CHECK(node_id.is_valid());
  auto *node_ptr = nodes_.get_pointer(node_id);
  if (node_ptr == nullptr) {
    return;
  }
  Node &node = *node_ptr;
  if (!node.query) {
    return;
  }
  if (node.query->active_queries != 0) {
    return;
  }
  VLOG(file_references) << "Trying to repair file reference for file " << node_id;
  if (node.query->promises.empty()) {
    node.query = {};
    return;
  }
  if (!node.file_source_ids.has_next()) {
    VLOG(file_references) << "Have no more file sources to repair file reference for file " << node_id;
    for (auto &p : node.query->promises) {
      if (node.file_source_ids.empty()) {
        p.set_error(Status::Error(400, "File source is not found"));
      } else {
        p.set_error(Status::Error(429, "Too Many Requests: retry after 1"));
      }
    }
    node.query = {};
    return;
  }
  if (node.last_successful_repair_time >= Time::now() - 60) {
    VLOG(file_references) << "Recently repaired file reference for file " << node_id << ", do not try again";
    for (auto &p : node.query->promises) {
      p.set_error(Status::Error(429, "Too Many Requests: retry after 60"));
    }
    node.query = {};
    return;
  }
  auto file_source_id = node.file_source_ids.next();
  send_query(Destination(node_id, node.query->generation), file_source_id);
}

void FileReferenceManager::send_query(Destination dest, FileSourceId file_source_id) {
  VLOG(file_references) << "Send file reference repair query for file " << dest.node_id << " with generation "
                        << dest.generation << " from " << file_source_id;
  auto &node = add_node(dest.node_id);
  node.query->active_queries++;

  auto promise = PromiseCreator::lambda([actor_id = actor_id(this), file_manager_actor_id = G()->file_manager(), dest,
                                         file_source_id](Result<Unit> result) {
    auto new_promise = PromiseCreator::lambda([actor_id, dest, file_source_id](Result<Unit> result) {
      Status status;
      if (result.is_error()) {
        status = result.move_as_error();
      }
      send_closure(actor_id, &FileReferenceManager::on_query_result, dest, file_source_id, std::move(status), 0);
    });

    send_closure(file_manager_actor_id, &FileManager::on_file_reference_repaired, dest.node_id, file_source_id,
                 std::move(result), std::move(new_promise));
  });
  auto index = static_cast<size_t>(file_source_id.get()) - 1;
  CHECK(index < file_sources_.size());
  file_sources_[index].visit(overloaded(
      [&](const FileSourceMessage &source) {
        send_closure_later(G()->messages_manager(), &MessagesManager::get_message_from_server, source.message_full_id,
                           std::move(promise), "FileSourceMessage", nullptr);
      },
      [&](const FileSourceUserPhoto &source) {
        send_closure_later(G()->user_manager(), &UserManager::reload_user_profile_photo, source.user_id,
                           source.photo_id, std::move(promise));
      },
      [&](const FileSourceChatPhoto &source) {
        send_closure_later(G()->chat_manager(), &ChatManager::reload_chat, source.chat_id, std::move(promise),
                           "FileSourceChatPhoto");
      },
      [&](const FileSourceChannelPhoto &source) {
        send_closure_later(G()->chat_manager(), &ChatManager::reload_channel, source.channel_id, std::move(promise),
                           "FileSourceChannelPhoto");
      },
      [&](const FileSourceWallpapers &source) { promise.set_error(Status::Error("Can't repair old wallpapers")); },
      [&](const FileSourceWebPage &source) {
        send_closure_later(G()->web_pages_manager(), &WebPagesManager::reload_web_page_by_url, source.url, false,
                           PromiseCreator::lambda([promise = std::move(promise)](Result<WebPageId> &&result) mutable {
                             if (result.is_error()) {
                               promise.set_error(result.move_as_error());
                             } else {
                               promise.set_value(Unit());
                             }
                           }));
      },
      [&](const FileSourceSavedAnimations &source) {
        send_closure_later(G()->animations_manager(), &AnimationsManager::repair_saved_animations, std::move(promise));
      },
      [&](const FileSourceRecentStickers &source) {
        send_closure_later(G()->stickers_manager(), &StickersManager::repair_recent_stickers, source.is_attached,
                           std::move(promise));
      },
      [&](const FileSourceFavoriteStickers &source) {
        send_closure_later(G()->stickers_manager(), &StickersManager::repair_favorite_stickers, std::move(promise));
      },
      [&](const FileSourceBackground &source) {
        send_closure_later(G()->background_manager(), &BackgroundManager::reload_background, source.background_id,
                           source.access_hash, std::move(promise));
      },
      [&](const FileSourceChatFull &source) {
        send_closure_later(G()->chat_manager(), &ChatManager::reload_chat_full, source.chat_id, std::move(promise),
                           "FileSourceChatFull");
      },
      [&](const FileSourceChannelFull &source) {
        send_closure_later(G()->chat_manager(), &ChatManager::reload_channel_full, source.channel_id,
                           std::move(promise), "FileSourceChannelFull");
      },
      [&](const FileSourceAppConfig &source) {
        send_closure_later(G()->config_manager(), &ConfigManager::reget_app_config, std::move(promise));
      },
      [&](const FileSourceSavedRingtones &source) {
        send_closure_later(G()->notification_settings_manager(), &NotificationSettingsManager::repair_saved_ringtones,
                           std::move(promise));
      },
      [&](const FileSourceUserFull &source) {
        send_closure_later(G()->user_manager(), &UserManager::reload_user_full, source.user_id, std::move(promise),
                           "FileSourceUserFull");
      },
      [&](const FileSourceAttachMenuBot &source) {
        send_closure_later(G()->attach_menu_manager(), &AttachMenuManager::reload_attach_menu_bot, source.user_id,
                           std::move(promise));
      },
      [&](const FileSourceWebApp &source) {
        send_closure_later(G()->web_app_manager(), &WebAppManager::reload_web_app, source.user_id, source.short_name,
                           std::move(promise));
      },
      [&](const FileSourceStory &source) {
        send_closure_later(G()->story_manager(), &StoryManager::reload_story, source.story_full_id, std::move(promise),
                           "FileSourceStory");
      },
      [&](const FileSourceQuickReplyMessage &source) {
        send_closure_later(G()->quick_reply_manager(), &QuickReplyManager::reload_quick_reply_message,
                           source.message_full_id.get_quick_reply_shortcut_id(),
                           source.message_full_id.get_message_id(), std::move(promise));
      },
      [&](const FileSourceStarTransaction &source) {
        send_closure_later(G()->star_manager(), &StarManager::reload_star_transaction, source.dialog_id,
                           source.transaction_id, source.is_refund, std::move(promise));
      },
      [&](const FileSourceBotMediaPreview &source) {
        send_closure_later(G()->bot_info_manager(), &BotInfoManager::reload_bot_media_previews, source.bot_user_id,
                           std::move(promise));
      },
      [&](const FileSourceBotMediaPreviewInfo &source) {
        send_closure_later(G()->bot_info_manager(), &BotInfoManager::reload_bot_media_preview_info, source.bot_user_id,
                           source.language_code, std::move(promise));
      }));
}

FileReferenceManager::Destination FileReferenceManager::on_query_result(Destination dest, FileSourceId file_source_id,
                                                                        Status status, int32 sub) {
  if (G()->close_flag()) {
    VLOG(file_references) << "Ignore file reference repair from " << file_source_id << " during closing";
    return dest;
  }

  VLOG(file_references) << "Receive result of file reference repair query for file " << dest.node_id
                        << " with generation " << dest.generation << " from " << file_source_id << ": " << status << " "
                        << sub;
  auto &node = add_node(dest.node_id);

  auto query = node.query.get();
  if (!query) {
    return dest;
  }
  if (query->generation != dest.generation) {
    return dest;
  }
  query->active_queries--;
  CHECK(query->active_queries >= 0);

  if (!query->proxy.is_empty()) {
    query->active_queries -= sub;
    CHECK(query->active_queries >= 0);
    auto new_proxy = on_query_result(query->proxy, file_source_id, std::move(status), query->active_queries);
    query->proxy = new_proxy;
    run_node(dest.node_id);
    return new_proxy;
  }

  if (status.is_ok()) {
    node.last_successful_repair_time = Time::now();
    for (auto &p : query->promises) {
      p.set_value(Unit());
    }
    node.query = {};
  }

  run_node(dest.node_id);
  return dest;
}

void FileReferenceManager::repair_file_reference(NodeId node_id, Promise<> promise) {
  auto main_file_id = G()->td().get_actor_unsafe()->file_manager_->get_file_view(node_id).get_main_file_id();
  VLOG(file_references) << "Repair file reference for file " << node_id << "/" << main_file_id;
  node_id = main_file_id;
  auto &node = add_node(node_id);
  if (!node.query) {
    node.query = make_unique<Query>();
    node.query->generation = ++query_generation_;
    node.file_source_ids.reset_position();
    VLOG(file_references) << "Create new file reference repair query with generation " << query_generation_;
  }
  node.query->promises.push_back(std::move(promise));
  run_node(node_id);
}

void FileReferenceManager::reload_photo(PhotoSizeSource source, Promise<Unit> promise) {
  switch (source.get_type("reload_photo")) {
    case PhotoSizeSource::Type::DialogPhotoBig:
    case PhotoSizeSource::Type::DialogPhotoSmall:
    case PhotoSizeSource::Type::DialogPhotoBigLegacy:
    case PhotoSizeSource::Type::DialogPhotoSmallLegacy:
      send_closure(G()->dialog_manager(), &DialogManager::reload_dialog_info, source.dialog_photo().dialog_id,
                   std::move(promise));
      break;
    case PhotoSizeSource::Type::StickerSetThumbnail:
    case PhotoSizeSource::Type::StickerSetThumbnailLegacy:
    case PhotoSizeSource::Type::StickerSetThumbnailVersion:
      send_closure(G()->stickers_manager(), &StickersManager::reload_sticker_set,
                   StickerSetId(source.sticker_set_thumbnail().sticker_set_id),
                   source.sticker_set_thumbnail().sticker_set_access_hash, std::move(promise));
      break;
    case PhotoSizeSource::Type::Legacy:
    case PhotoSizeSource::Type::FullLegacy:
    case PhotoSizeSource::Type::Thumbnail:
      promise.set_error(Status::Error("Unexpected PhotoSizeSource type"));
      break;
    default:
      UNREACHABLE();
  }
}

void FileReferenceManager::get_file_search_text(FileSourceId file_source_id, string unique_file_id,
                                                Promise<string> promise) {
  auto index = static_cast<size_t>(file_source_id.get()) - 1;
  CHECK(index < file_sources_.size());
  file_sources_[index].visit(overloaded(
      [&](const FileSourceMessage &source) {
        send_closure_later(G()->messages_manager(), &MessagesManager::get_message_file_search_text,
                           source.message_full_id, std::move(unique_file_id), std::move(promise));
      },
      [&](const auto &source) { promise.set_error(Status::Error(500, "Unsupported file source")); }));
}

td_api::object_ptr<td_api::message> FileReferenceManager::get_message_object(FileSourceId file_source_id) const {
  auto index = static_cast<size_t>(file_source_id.get()) - 1;
  CHECK(index < file_sources_.size());
  td_api::object_ptr<td_api::message> result;
  file_sources_[index].visit(overloaded(
      [&](const FileSourceMessage &source) {
        result = G()->td().get_actor_unsafe()->messages_manager_->get_message_object(source.message_full_id,
                                                                                     "FileReferenceManager");
      },
      [&](const auto &source) { LOG(ERROR) << "Unsupported file source"; }));
  return result;
}

}  // namespace td
