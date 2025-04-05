//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/BackgroundInfo.h"
#include "td/telegram/ChannelId.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/EncryptedFile.h"
#include "td/telegram/files/FileId.h"
#include "td/telegram/files/FileUploadId.h"
#include "td/telegram/InputGroupCallId.h"
#include "td/telegram/logevent/LogEvent.h"
#include "td/telegram/MessageContentType.h"
#include "td/telegram/MessageCopyOptions.h"
#include "td/telegram/MessageEntity.h"
#include "td/telegram/MessageFullId.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/MessageSelfDestructType.h"
#include "td/telegram/Photo.h"
#include "td/telegram/QuickReplyMessageFullId.h"
#include "td/telegram/ReplyMarkup.h"
#include "td/telegram/secret_api.h"
#include "td/telegram/SecretInputMedia.h"
#include "td/telegram/StickerType.h"
#include "td/telegram/StoryFullId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/TopDialogCategory.h"
#include "td/telegram/UserId.h"
#include "td/telegram/WebPageId.h"

#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"

#include <utility>

namespace td {

class Dependencies;
class Game;
class MultiPromiseActor;
struct Photo;
class RepliedMessageInfo;
class Td;
class Venue;

// Do not forget to update merge_message_contents and compare_message_contents when one of the inheritors of this class changes
class MessageContent {
 public:
  MessageContent() = default;
  MessageContent(const MessageContent &) = default;
  MessageContent &operator=(const MessageContent &) = default;
  MessageContent(MessageContent &&) = default;
  MessageContent &operator=(MessageContent &&) = default;

  virtual MessageContentType get_type() const = 0;
  virtual ~MessageContent() = default;
};

struct InputMessageContent {
  unique_ptr<MessageContent> content;
  bool disable_web_page_preview = false;
  bool invert_media = false;
  bool clear_draft = false;
  MessageSelfDestructType ttl;
  UserId via_bot_user_id;
  string emoji;

  InputMessageContent(unique_ptr<MessageContent> &&content, bool disable_web_page_preview, bool invert_media,
                      bool clear_draft, MessageSelfDestructType ttl, UserId via_bot_user_id, string emoji)
      : content(std::move(content))
      , disable_web_page_preview(disable_web_page_preview)
      , invert_media(invert_media)
      , clear_draft(clear_draft)
      , ttl(ttl)
      , via_bot_user_id(via_bot_user_id)
      , emoji(std::move(emoji)) {
  }
};

struct InlineMessageContent {
  unique_ptr<MessageContent> message_content;
  unique_ptr<ReplyMarkup> message_reply_markup;
  bool disable_web_page_preview;
  bool invert_media;
};

void store_message_content(const MessageContent *content, LogEventStorerCalcLength &storer);

void store_message_content(const MessageContent *content, LogEventStorerUnsafe &storer);

void parse_message_content(unique_ptr<MessageContent> &content, LogEventParser &parser);

InlineMessageContent create_inline_message_content(Td *td, FileId file_id,
                                                   tl_object_ptr<telegram_api::BotInlineMessage> &&bot_inline_message,
                                                   int32 allowed_media_content_id, Photo *photo, Game *game);

unique_ptr<MessageContent> create_text_message_content(string text, vector<MessageEntity> entities,
                                                       WebPageId web_page_id, bool force_small_media,
                                                       bool force_large_media, bool skip_confitmation,
                                                       string &&web_page_url);

unique_ptr<MessageContent> create_photo_message_content(Photo photo);

unique_ptr<MessageContent> create_video_message_content(FileId file_id, Photo cover, int32 start_timestamp);

unique_ptr<MessageContent> create_contact_registered_message_content();

unique_ptr<MessageContent> create_screenshot_taken_message_content();

unique_ptr<MessageContent> create_chat_set_ttl_message_content(int32 ttl, UserId from_user_id);

td_api::object_ptr<td_api::formattedText> extract_input_caption(
    td_api::object_ptr<td_api::InputMessageContent> &input_message_content);

bool extract_input_invert_media(const td_api::object_ptr<td_api::InputMessageContent> &input_message_content);

Result<InputMessageContent> get_input_message_content(
    DialogId dialog_id, tl_object_ptr<td_api::InputMessageContent> &&input_message_content, Td *td, bool is_premium);

Status check_message_group_message_contents(const vector<InputMessageContent> &message_contents);

bool can_message_content_have_input_media(const Td *td, const MessageContent *content, bool is_server);

SecretInputMedia get_message_content_secret_input_media(
    const MessageContent *content, Td *td, telegram_api::object_ptr<telegram_api::InputEncryptedFile> input_file,
    BufferSlice thumbnail, int32 layer);

telegram_api::object_ptr<telegram_api::InputMedia> get_message_content_input_media(
    const MessageContent *content, int32 media_pos, Td *td,
    telegram_api::object_ptr<telegram_api::InputFile> input_file,
    telegram_api::object_ptr<telegram_api::InputFile> input_thumbnail, FileUploadId file_upload_id,
    FileUploadId thumbnail_file_upload_id, MessageSelfDestructType ttl, const string &emoji, bool force);

telegram_api::object_ptr<telegram_api::InputMedia> get_message_content_input_media(const MessageContent *content,
                                                                                   Td *td, MessageSelfDestructType ttl,
                                                                                   const string &emoji, bool force,
                                                                                   int32 media_pos = -1);

telegram_api::object_ptr<telegram_api::InputMedia> get_message_content_fake_input_media(
    Td *td, telegram_api::object_ptr<telegram_api::InputFile> input_file, FileId file_id);

telegram_api::object_ptr<telegram_api::InputMedia> get_message_content_input_media_web_page(
    const Td *td, const MessageContent *content);

bool is_uploaded_input_media(telegram_api::object_ptr<telegram_api::InputMedia> &input_media);

void delete_message_content_thumbnail(MessageContent *content, Td *td, int32 media_pos = -1);

Status can_send_message_content(DialogId dialog_id, const MessageContent *content, bool is_forward,
                                bool check_permissions, const Td *td);

bool can_forward_message_content(const MessageContent *content);

bool update_opened_message_content(MessageContent *content);

int32 get_message_content_index_mask(const MessageContent *content, const Td *td, bool is_outgoing);

vector<unique_ptr<MessageContent>> get_individual_message_contents(const MessageContent *content);

StickerType get_message_content_sticker_type(const Td *td, const MessageContent *content);

MessageId get_message_content_pinned_message_id(const MessageContent *content);

BackgroundInfo get_message_content_my_background_info(const MessageContent *content, bool is_outgoing);

string get_message_content_theme_name(const MessageContent *content);

MessageFullId get_message_content_replied_message_id(DialogId dialog_id, const MessageContent *content);

std::pair<InputGroupCallId, bool> get_message_content_group_call_info(const MessageContent *content);

vector<UserId> get_message_content_min_user_ids(const Td *td, const MessageContent *message_content);

vector<ChannelId> get_message_content_min_channel_ids(const Td *td, const MessageContent *message_content);

vector<UserId> get_message_content_added_user_ids(const MessageContent *content);

UserId get_message_content_deleted_user_id(const MessageContent *content);

int32 get_message_content_live_location_period(const MessageContent *content);

bool get_message_content_poll_is_anonymous(const Td *td, const MessageContent *content);

bool get_message_content_poll_is_closed(const Td *td, const MessageContent *content);

const Venue *get_message_content_venue(const MessageContent *content);

bool has_message_content_web_page(const MessageContent *content);

void remove_message_content_web_page(MessageContent *content);

bool can_message_content_have_media_timestamp(const MessageContent *content);

void set_message_content_poll_answer(Td *td, const MessageContent *content, MessageFullId message_full_id,
                                     vector<int32> &&option_ids, Promise<Unit> &&promise);

void get_message_content_poll_voters(Td *td, const MessageContent *content, MessageFullId message_full_id,
                                     int32 option_id, int32 offset, int32 limit,
                                     Promise<td_api::object_ptr<td_api::messageSenders>> &&promise);

void stop_message_content_poll(Td *td, const MessageContent *content, MessageFullId message_full_id,
                               unique_ptr<ReplyMarkup> &&reply_markup, Promise<Unit> &&promise);

void merge_message_contents(Td *td, const MessageContent *old_content, MessageContent *new_content,
                            bool need_message_changed_warning, DialogId dialog_id, bool need_merge_files,
                            bool &is_content_changed, bool &need_update);

bool merge_message_content_file_id(Td *td, MessageContent *message_content, FileId new_file_id);

void compare_message_contents(Td *td, const MessageContent *lhs_content, const MessageContent *rhs_content,
                              bool &is_content_changed, bool &need_update);

void register_message_content(Td *td, const MessageContent *content, MessageFullId message_full_id, const char *source);

void reregister_message_content(Td *td, const MessageContent *old_content, const MessageContent *new_content,
                                MessageFullId message_full_id, const char *source);

void unregister_message_content(Td *td, const MessageContent *content, MessageFullId message_full_id,
                                const char *source);

void register_reply_message_content(Td *td, const MessageContent *content);

void unregister_reply_message_content(Td *td, const MessageContent *content);

void register_quick_reply_message_content(Td *td, const MessageContent *content,
                                          QuickReplyMessageFullId message_full_id, const char *source);

void unregister_quick_reply_message_content(Td *td, const MessageContent *content,
                                            QuickReplyMessageFullId message_full_id, const char *source);

unique_ptr<MessageContent> get_secret_message_content(
    Td *td, string message_text, unique_ptr<EncryptedFile> file,
    tl_object_ptr<secret_api::DecryptedMessageMedia> &&media_ptr,
    vector<tl_object_ptr<secret_api::MessageEntity>> &&secret_entities, DialogId owner_dialog_id,
    MultiPromiseActor &load_data_multipromise, bool is_premium);

unique_ptr<MessageContent> get_message_content(Td *td, FormattedText message_text,
                                               tl_object_ptr<telegram_api::MessageMedia> &&media_ptr,
                                               DialogId owner_dialog_id, int32 message_date, bool is_content_read,
                                               UserId via_bot_user_id, MessageSelfDestructType *ttl,
                                               bool *disable_web_page_preview, const char *source);

unique_ptr<MessageContent> get_uploaded_message_content(
    Td *td, const MessageContent *old_content, int32 media_pos,
    telegram_api::object_ptr<telegram_api::MessageMedia> &&media_ptr, DialogId owner_dialog_id, int32 message_date,
    const char *source);

enum class MessageContentDupType : int32 {
  Send,        // normal message sending
  SendViaBot,  // message sending via bot
  Forward,     // server-side message forward
  Copy,        // local message copy
  ServerCopy   // server-side message copy
};

unique_ptr<MessageContent> dup_message_content(Td *td, DialogId dialog_id, const MessageContent *content,
                                               MessageContentDupType type, MessageCopyOptions &&copy_options);

unique_ptr<MessageContent> get_action_message_content(Td *td, tl_object_ptr<telegram_api::MessageAction> &&action_ptr,
                                                      DialogId owner_dialog_id, int32 message_date,
                                                      const RepliedMessageInfo &replied_message_info,
                                                      bool is_business_message);

td_api::object_ptr<td_api::MessageContent> get_message_content_object(const MessageContent *content, Td *td,
                                                                      DialogId dialog_id, MessageId message_id,
                                                                      bool is_outgoing, int32 message_date,
                                                                      bool is_content_secret, bool skip_bot_commands,
                                                                      int32 max_media_timestamp, bool invert_media,
                                                                      bool disable_web_page_preview);

td_api::object_ptr<td_api::upgradeGiftResult> get_message_content_upgrade_gift_result_object(
    const MessageContent *content, Td *td, DialogId dialog_id, MessageId message_id);

FormattedText *get_message_content_text_mutable(MessageContent *content);

const FormattedText *get_message_content_text(const MessageContent *content);

const FormattedText *get_message_content_caption(const MessageContent *content);

int64 get_message_content_star_count(const MessageContent *content);

string get_message_content_payload(const MessageContent *content);

int32 get_message_content_duration(const MessageContent *content, const Td *td);

int32 get_message_content_media_duration(const MessageContent *content, const Td *td);

const Photo *get_message_content_cover(const MessageContent *content);

vector<const Photo *> get_message_content_need_to_upload_covers(Td *td, const MessageContent *content);

const Photo *get_message_content_photo(const MessageContent *content);

FileId get_message_content_any_file_id(const MessageContent *content);

vector<FileId> get_message_content_any_file_ids(const MessageContent *content);

FileId get_message_content_cover_any_file_id(const MessageContent *content);

vector<FileId> get_message_content_cover_any_file_ids(const MessageContent *content);

void update_message_content_file_id_remote(MessageContent *content, FileId file_id);

void update_message_content_file_id_remotes(MessageContent *content, const vector<FileId> &file_ids);

FileId get_message_content_thumbnail_file_id(const MessageContent *content, const Td *td);

vector<FileId> get_message_content_thumbnail_file_ids(const MessageContent *content, const Td *td);

vector<FileId> get_message_content_file_ids(const MessageContent *content, const Td *td);

StoryFullId get_message_content_story_full_id(const Td *td, const MessageContent *content);

string get_message_content_search_text(const Td *td, const MessageContent *content);

bool update_message_content_extended_media(
    MessageContent *content, vector<telegram_api::object_ptr<telegram_api::MessageExtendedMedia>> extended_media,
    DialogId owner_dialog_id, Td *td);

bool need_poll_message_content_extended_media(const MessageContent *content);

void set_message_content_video_start_timestamp(MessageContent *content, int32 start_timestamp);

void get_message_content_animated_emoji_click_sticker(const MessageContent *content, MessageFullId message_full_id,
                                                      Td *td, Promise<td_api::object_ptr<td_api::sticker>> &&promise);

void on_message_content_animated_emoji_clicked(const MessageContent *content, MessageFullId message_full_id, Td *td,
                                               string &&emoji, string &&data);

bool need_reget_message_content(const MessageContent *content);

bool need_delay_message_content_notification(const MessageContent *content, UserId my_user_id);

void update_expired_message_content(unique_ptr<MessageContent> &content);

void update_failed_to_send_message_content(Td *td, unique_ptr<MessageContent> &content);

void add_message_content_dependencies(Dependencies &dependencies, const MessageContent *message_content, bool is_bot);

void update_forum_topic_info_by_service_message_content(Td *td, const MessageContent *content, DialogId dialog_id,
                                                        MessageId top_thread_message_id);

void on_sent_message_content(Td *td, const MessageContent *content);

void move_message_content_sticker_set_to_top(Td *td, const MessageContent *content);

void on_dialog_used(TopDialogCategory category, DialogId dialog_id, int32 date);

void update_used_hashtags(Td *td, const MessageContent *content);

}  // namespace td
