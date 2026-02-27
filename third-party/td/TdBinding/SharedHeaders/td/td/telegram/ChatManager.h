//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/AccentColorId.h"
#include "td/telegram/AccessRights.h"
#include "td/telegram/BotCommand.h"
#include "td/telegram/ChannelId.h"
#include "td/telegram/ChannelType.h"
#include "td/telegram/ChatId.h"
#include "td/telegram/CustomEmojiId.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/DialogInviteLink.h"
#include "td/telegram/DialogLocation.h"
#include "td/telegram/DialogParticipant.h"
#include "td/telegram/files/FileId.h"
#include "td/telegram/files/FileSourceId.h"
#include "td/telegram/MessageFullId.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/MessageTtl.h"
#include "td/telegram/net/DcId.h"
#include "td/telegram/Photo.h"
#include "td/telegram/PublicDialogType.h"
#include "td/telegram/QueryCombiner.h"
#include "td/telegram/QueryMerger.h"
#include "td/telegram/RestrictionReason.h"
#include "td/telegram/StickerSetId.h"
#include "td/telegram/StoryId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"
#include "td/telegram/Usernames.h"

#include "td/actor/actor.h"
#include "td/actor/MultiTimeout.h"

#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/FlatHashSet.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/Time.h"
#include "td/utils/WaitFreeHashMap.h"
#include "td/utils/WaitFreeHashSet.h"

#include <utility>

namespace td {

struct BinlogEvent;
class BotVerification;
class EmojiStatus;
struct MinChannel;
class Td;

class ChatManager final : public Actor {
 public:
  ChatManager(Td *td, ActorShared<> parent);
  ChatManager(const ChatManager &) = delete;
  ChatManager &operator=(const ChatManager &) = delete;
  ChatManager(ChatManager &&) = delete;
  ChatManager &operator=(ChatManager &&) = delete;
  ~ChatManager() final;

  static ChatId get_chat_id(const tl_object_ptr<telegram_api::Chat> &chat);
  static ChannelId get_channel_id(const tl_object_ptr<telegram_api::Chat> &chat);
  static DialogId get_dialog_id(const tl_object_ptr<telegram_api::Chat> &chat);

  vector<ChannelId> get_channel_ids(vector<tl_object_ptr<telegram_api::Chat>> &&chats, const char *source);

  // TODO get_input_chat ???

  tl_object_ptr<telegram_api::InputChannel> get_input_channel(ChannelId channel_id) const;

  tl_object_ptr<telegram_api::InputPeer> get_input_peer_chat(ChatId chat_id, AccessRights access_rights) const;
  bool have_input_peer_chat(ChatId chat_id, AccessRights access_rights) const;

  tl_object_ptr<telegram_api::InputPeer> get_simple_input_peer(DialogId dialog_id) const;
  tl_object_ptr<telegram_api::InputPeer> get_input_peer_channel(ChannelId channel_id, AccessRights access_rights) const;
  bool have_input_peer_channel(ChannelId channel_id, AccessRights access_rights) const;

  bool is_chat_received_from_server(ChatId chat_id) const;
  bool is_channel_received_from_server(ChannelId channel_id) const;

  const DialogPhoto *get_chat_dialog_photo(ChatId chat_id) const;
  const DialogPhoto *get_channel_dialog_photo(ChannelId channel_id) const;

  AccentColorId get_channel_accent_color_id(ChannelId channel_id) const;

  int32 get_chat_accent_color_id_object(ChatId chat_id) const;
  int32 get_channel_accent_color_id_object(ChannelId channel_id) const;

  CustomEmojiId get_chat_background_custom_emoji_id(ChatId chat_id) const;
  CustomEmojiId get_channel_background_custom_emoji_id(ChannelId channel_id) const;

  int32 get_chat_profile_accent_color_id_object(ChatId chat_id) const;
  int32 get_channel_profile_accent_color_id_object(ChannelId channel_id) const;

  CustomEmojiId get_chat_profile_background_custom_emoji_id(ChatId chat_id) const;
  CustomEmojiId get_channel_profile_background_custom_emoji_id(ChannelId channel_id) const;

  string get_chat_title(ChatId chat_id) const;
  string get_channel_title(ChannelId channel_id) const;

  RestrictedRights get_chat_default_permissions(ChatId chat_id) const;
  RestrictedRights get_channel_default_permissions(ChannelId channel_id) const;

  td_api::object_ptr<td_api::emojiStatus> get_chat_emoji_status_object(ChatId chat_id) const;
  td_api::object_ptr<td_api::emojiStatus> get_channel_emoji_status_object(ChannelId channel_id) const;

  string get_chat_about(ChatId chat_id);
  string get_channel_about(ChannelId channel_id);

  bool get_chat_has_protected_content(ChatId chat_id) const;
  bool get_channel_has_protected_content(ChannelId channel_id) const;

  bool get_channel_stories_hidden(ChannelId channel_id) const;

  bool get_channel_autotranslation(ChannelId channel_id) const;

  bool can_poll_channel_active_stories(ChannelId channel_id) const;

  bool can_use_premium_custom_emoji_in_channel(ChannelId channel_id) const;

  string get_channel_search_text(ChannelId channel_id) const;

  string get_channel_first_username(ChannelId channel_id) const;
  string get_channel_editable_username(ChannelId channel_id) const;

  void on_binlog_chat_event(BinlogEvent &&event);
  void on_binlog_channel_event(BinlogEvent &&event);

  void on_get_chat(tl_object_ptr<telegram_api::Chat> &&chat, const char *source);
  void on_get_chats(vector<tl_object_ptr<telegram_api::Chat>> &&chats, const char *source);

  void on_get_chat_full(tl_object_ptr<telegram_api::ChatFull> &&chat_full, Promise<Unit> &&promise);
  void on_get_chat_full_failed(ChatId chat_id);
  void on_get_channel_full_failed(ChannelId channel_id);

  void on_ignored_restriction_reasons_changed();

  void on_get_chat_participants(tl_object_ptr<telegram_api::ChatParticipants> &&participants, bool from_update);
  void on_update_chat_add_user(ChatId chat_id, UserId inviter_user_id, UserId user_id, int32 date, int32 version);
  void on_update_chat_description(ChatId chat_id, string &&description);
  void on_update_chat_edit_administrator(ChatId chat_id, UserId user_id, bool is_administrator, int32 version);
  void on_update_chat_delete_user(ChatId chat_id, UserId user_id, int32 version);
  void on_update_chat_default_permissions(ChatId chat_id, RestrictedRights default_permissions, int32 version);
  void on_update_chat_pinned_message(ChatId chat_id, MessageId pinned_message_id, int32 version);
  void on_update_chat_bot_commands(ChatId chat_id, BotCommands &&bot_commands);
  void on_update_chat_permanent_invite_link(ChatId chat_id, const DialogInviteLink &invite_link);

  void on_update_channel_participant_count(ChannelId channel_id, int32 participant_count);
  void on_update_channel_editable_username(ChannelId channel_id, string &&username);
  void on_update_channel_usernames(ChannelId channel_id, Usernames &&usernames);
  void on_update_channel_story_ids(ChannelId channel_id, StoryId max_active_story_id, StoryId max_read_story_id);
  void on_update_channel_max_read_story_id(ChannelId channel_id, StoryId max_read_story_id);
  void on_update_channel_stories_hidden(ChannelId channel_id, bool stories_hidden);
  void on_update_channel_description(ChannelId channel_id, string &&description);
  void on_update_channel_sticker_set(ChannelId channel_id, StickerSetId sticker_set_id);
  void on_update_channel_emoji_sticker_set(ChannelId channel_id, StickerSetId sticker_set_id);
  void on_update_channel_unrestrict_boost_count(ChannelId channel_id, int32 unrestrict_boost_count);
  void on_update_channel_gift_count(ChannelId channel_id, int32 gift_count, bool is_added);
  void on_update_channel_linked_channel_id(ChannelId channel_id, ChannelId group_channel_id);
  void on_update_channel_location(ChannelId channel_id, const DialogLocation &location);
  void on_update_channel_slow_mode_delay(ChannelId channel_id, int32 slow_mode_delay, Promise<Unit> &&promise);
  void on_update_channel_slow_mode_next_send_date(ChannelId channel_id, int32 slow_mode_next_send_date);
  void on_update_channel_is_all_history_available(ChannelId channel_id, bool is_all_history_available,
                                                  Promise<Unit> &&promise);
  void on_update_channel_can_have_sponsored_messages(ChannelId channel_id, bool can_have_sponsored_messages,
                                                     Promise<Unit> &&promise);
  void on_update_channel_has_hidden_participants(ChannelId channel_id, bool has_hidden_participants,
                                                 Promise<Unit> &&promise);
  void on_update_channel_has_aggressive_anti_spam_enabled(ChannelId channel_id, bool has_aggressive_anti_spam_enabled,
                                                          Promise<Unit> &&promise);
  void on_update_channel_has_pinned_stories(ChannelId channel_id, bool has_pinned_stories);
  void on_update_channel_default_permissions(ChannelId channel_id, RestrictedRights default_permissions);
  void on_update_channel_administrator_count(ChannelId channel_id, int32 administrator_count);
  void on_update_channel_bot_commands(ChannelId channel_id, BotCommands &&bot_commands);
  void on_update_channel_permanent_invite_link(ChannelId channel_id, const DialogInviteLink &invite_link);

  void speculative_add_channel_participants(ChannelId channel_id, const vector<UserId> &added_user_ids,
                                            UserId inviter_user_id, int32 date, bool by_me);

  void speculative_delete_channel_participant(ChannelId channel_id, UserId deleted_user_id, bool by_me);

  void invalidate_channel_full(ChannelId channel_id, bool need_drop_slow_mode_delay, const char *source);

  bool on_get_channel_error(ChannelId channel_id, const Status &status, const char *source);

  void on_get_created_public_channels(PublicDialogType type, vector<tl_object_ptr<telegram_api::Chat>> &&chats);

  bool are_created_public_broadcasts_inited() const;

  const vector<ChannelId> &get_created_public_broadcasts() const;

  void on_get_dialogs_for_discussion(vector<tl_object_ptr<telegram_api::Chat>> &&chats);

  void on_get_inactive_channels(vector<tl_object_ptr<telegram_api::Chat>> &&chats, Promise<Unit> &&promise);

  void remove_inactive_channel(ChannelId channel_id);

  void register_message_channels(MessageFullId message_full_id, vector<ChannelId> channel_ids);

  void unregister_message_channels(MessageFullId message_full_id, vector<ChannelId> channel_ids);

  static ChannelId get_unsupported_channel_id();

  void update_chat_online_member_count(ChatId chat_id, bool is_from_server);

  void on_update_channel_bot_user_ids(ChannelId channel_id, vector<UserId> &&bot_user_ids);

  void on_update_channel_username_is_active(ChannelId channel_id, string &&username, bool is_active,
                                            Promise<Unit> &&promise);

  void on_deactivate_channel_usernames(ChannelId channel_id, Promise<Unit> &&promise);

  void on_update_channel_active_usernames_order(ChannelId channel_id, vector<string> &&usernames,
                                                Promise<Unit> &&promise);

  void set_chat_description(ChatId chat_id, const string &description, Promise<Unit> &&promise);

  void set_channel_username(ChannelId channel_id, const string &username, Promise<Unit> &&promise);

  void toggle_channel_username_is_active(ChannelId channel_id, string &&username, bool is_active,
                                         Promise<Unit> &&promise);

  void disable_all_channel_usernames(ChannelId channel_id, Promise<Unit> &&promise);

  void reorder_channel_usernames(ChannelId channel_id, vector<string> &&usernames, Promise<Unit> &&promise);

  void set_channel_accent_color(ChannelId channel_id, AccentColorId accent_color_id,
                                CustomEmojiId background_custom_emoji_id, Promise<Unit> &&promise);

  void set_channel_profile_accent_color(ChannelId channel_id, AccentColorId profile_accent_color_id,
                                        CustomEmojiId profile_background_custom_emoji_id, Promise<Unit> &&promise);

  void set_channel_emoji_status(ChannelId channel_id, const unique_ptr<EmojiStatus> &emoji_status,
                                Promise<Unit> &&promise);

  void set_channel_sticker_set(ChannelId channel_id, StickerSetId sticker_set_id, Promise<Unit> &&promise);

  void set_channel_emoji_sticker_set(ChannelId channel_id, StickerSetId sticker_set_id, Promise<Unit> &&promise);

  void set_channel_unrestrict_boost_count(ChannelId channel_id, int32 unrestrict_boost_count, Promise<Unit> &&promise);

  void toggle_channel_sign_messages(ChannelId channel_id, bool sign_messages, bool show_message_sender,
                                    Promise<Unit> &&promise);

  void toggle_channel_join_to_send(ChannelId channel_id, bool joint_to_send, Promise<Unit> &&promise);

  void toggle_channel_join_request(ChannelId channel_id, bool join_request, Promise<Unit> &&promise);

  void toggle_channel_is_all_history_available(ChannelId channel_id, bool is_all_history_available,
                                               Promise<Unit> &&promise);

  void toggle_channel_can_have_sponsored_messages(ChannelId channel_id, bool can_have_sponsored_messages,
                                                  Promise<Unit> &&promise);

  void toggle_channel_has_automatic_translation(ChannelId channel_id, bool has_automatic_translation,
                                                Promise<Unit> &&promise);

  void toggle_channel_has_hidden_participants(ChannelId channel_id, bool has_hidden_participants,
                                              Promise<Unit> &&promise);

  void toggle_channel_has_aggressive_anti_spam_enabled(ChannelId channel_id, bool has_aggressive_anti_spam_enabled,
                                                       Promise<Unit> &&promise);

  void toggle_channel_is_forum(ChannelId channel_id, bool is_forum, Promise<Unit> &&promise);

  void convert_channel_to_gigagroup(ChannelId channel_id, Promise<Unit> &&promise);

  void set_channel_description(ChannelId channel_id, const string &description, Promise<Unit> &&promise);

  void set_channel_discussion_group(DialogId dialog_id, DialogId discussion_dialog_id, Promise<Unit> &&promise);

  void set_channel_location(ChannelId dialog_id, const DialogLocation &location, Promise<Unit> &&promise);

  void set_channel_slow_mode_delay(DialogId dialog_id, int32 slow_mode_delay, Promise<Unit> &&promise);

  void report_channel_spam(ChannelId channel_id, const vector<MessageId> &message_ids, Promise<Unit> &&promise);

  void report_channel_anti_spam_false_positive(ChannelId channel_id, MessageId message_id, Promise<Unit> &&promise);

  void set_channel_send_paid_messages_star_count(DialogId dialog_id, int64 send_paid_messages_star_count,
                                                 Promise<Unit> &&promise);

  void delete_chat(ChatId chat_id, Promise<Unit> &&promise);

  void delete_channel(ChannelId channel_id, Promise<Unit> &&promise);

  void get_channel_statistics_dc_id(DialogId dialog_id, bool for_full_statistics, Promise<DcId> &&promise);

  bool can_get_channel_message_statistics(ChannelId channel_id) const;

  bool can_get_channel_story_statistics(ChannelId channel_id) const;

  bool can_convert_channel_to_gigagroup(ChannelId channel_id) const;

  void get_created_public_dialogs(PublicDialogType type, Promise<td_api::object_ptr<td_api::chats>> &&promise,
                                  bool from_binlog);

  void check_created_public_dialogs_limit(PublicDialogType type, Promise<Unit> &&promise);

  void reload_created_public_dialogs(PublicDialogType type, Promise<td_api::object_ptr<td_api::chats>> &&promise);

  vector<DialogId> get_dialogs_for_discussion(Promise<Unit> &&promise);

  vector<DialogId> get_inactive_channels(Promise<Unit> &&promise);

  void create_new_chat(const vector<UserId> &user_ids, const string &title, MessageTtl message_ttl,
                       Promise<td_api::object_ptr<td_api::createdBasicGroupChat>> &&promise);

  bool have_chat(ChatId chat_id) const;
  bool have_chat_force(ChatId chat_id, const char *source);
  bool get_chat(ChatId chat_id, int left_tries, Promise<Unit> &&promise);
  void reload_chat(ChatId chat_id, Promise<Unit> &&promise, const char *source);
  void load_chat_full(ChatId chat_id, bool force, Promise<Unit> &&promise, const char *source);
  FileSourceId get_chat_full_file_source_id(ChatId chat_id);
  void reload_chat_full(ChatId chat_id, Promise<Unit> &&promise, const char *source);

  int32 get_chat_date(ChatId chat_id) const;
  int32 get_chat_participant_count(ChatId chat_id) const;
  bool get_chat_is_active(ChatId chat_id) const;
  ChannelId get_chat_migrated_to_channel_id(ChatId chat_id) const;
  DialogParticipantStatus get_chat_status(ChatId chat_id) const;
  DialogParticipantStatus get_chat_permissions(ChatId chat_id) const;
  bool is_appointed_chat_administrator(ChatId chat_id) const;
  const DialogParticipant *get_chat_participant(ChatId chat_id, UserId user_id) const;
  const vector<DialogParticipant> *get_chat_participants(ChatId chat_id) const;

  void create_new_channel(const string &title, bool is_forum, bool is_megagroup, const string &description,
                          const DialogLocation &location, bool for_import, MessageTtl message_ttl,
                          Promise<td_api::object_ptr<td_api::chat>> &&promise);

  bool have_min_channel(ChannelId channel_id) const;
  const MinChannel *get_min_channel(ChannelId channel_id) const;
  void add_min_channel(ChannelId channel_id, const MinChannel &min_channel);

  bool have_channel(ChannelId channel_id) const;
  bool have_channel_force(ChannelId channel_id, const char *source);
  bool get_channel(ChannelId channel_id, int left_tries, Promise<Unit> &&promise);
  void reload_channel(ChannelId channel_id, Promise<Unit> &&promise, const char *source);
  void load_channel_full(ChannelId channel_id, bool force, Promise<Unit> &&promise, const char *source);
  FileSourceId get_channel_full_file_source_id(ChannelId channel_id);
  void reload_channel_full(ChannelId channel_id, Promise<Unit> &&promise, const char *source);

  bool is_channel_public(ChannelId channel_id) const;

  ChannelType get_channel_type(ChannelId channel_id) const;
  bool is_broadcast_channel(ChannelId channel_id) const;
  bool is_megagroup_channel(ChannelId channel_id) const;
  bool is_forum_channel(ChannelId channel_id) const;
  int32 get_channel_date(ChannelId channel_id) const;
  DialogParticipantStatus get_channel_status(ChannelId channel_id) const;
  DialogParticipantStatus get_channel_permissions(ChannelId channel_id) const;
  bool get_channel_is_verified(ChannelId channel_id) const;
  td_api::object_ptr<td_api::verificationStatus> get_channel_verification_status_object(ChannelId channel_id) const;
  int32 get_channel_participant_count(ChannelId channel_id) const;
  bool get_channel_sign_messages(ChannelId channel_id) const;
  bool get_channel_show_message_sender(ChannelId channel_id) const;
  bool get_channel_has_linked_channel(ChannelId channel_id) const;
  bool get_channel_join_request(ChannelId channel_id) const;
  bool get_channel_can_be_deleted(ChannelId channel_id) const;
  ChannelId get_channel_linked_channel_id(ChannelId channel_id, const char *source);
  int32 get_channel_slow_mode_delay(ChannelId channel_id, const char *source);
  bool get_channel_effective_has_hidden_participants(ChannelId channel_id, const char *source);
  int32 get_channel_my_boost_count(ChannelId channel_id);

  void get_chat_participant(ChatId chat_id, UserId user_id, Promise<DialogParticipant> &&promise);

  void speculative_add_channel_user(ChannelId channel_id, UserId user_id, const DialogParticipantStatus &new_status,
                                    const DialogParticipantStatus &old_status);

  int64 get_basic_group_id_object(ChatId chat_id, const char *source) const;

  tl_object_ptr<td_api::basicGroup> get_basic_group_object(ChatId chat_id);

  tl_object_ptr<td_api::basicGroupFullInfo> get_basic_group_full_info_object(ChatId chat_id) const;

  int64 get_supergroup_id_object(ChannelId channel_id, const char *source) const;

  td_api::object_ptr<td_api::supergroup> get_supergroup_object(ChannelId channel_id) const;

  tl_object_ptr<td_api::supergroupFullInfo> get_supergroup_full_info_object(ChannelId channel_id) const;

  tl_object_ptr<td_api::chatMember> get_chat_member_object(const DialogParticipant &dialog_participant,
                                                           const char *source) const;

  void repair_chat_participants(ChatId chat_id);

  void get_current_state(vector<td_api::object_ptr<td_api::Update>> &updates) const;

 private:
  struct Chat {
    string title;
    DialogPhoto photo;
    int32 participant_count = 0;
    int32 date = 0;
    int32 version = -1;
    int32 default_permissions_version = -1;
    int32 pinned_message_version = -1;
    ChannelId migrated_to_channel_id;

    DialogParticipantStatus status = DialogParticipantStatus::Banned(0);
    RestrictedRights default_permissions{false, false, false, false, false, false, false, false, false,
                                         false, false, false, false, false, false, false, false, ChannelType::Unknown};

    static constexpr uint32 CACHE_VERSION = 4;
    uint32 cache_version = 0;

    bool is_active = false;
    bool noforwards = false;

    bool is_title_changed = true;
    bool is_photo_changed = true;
    bool is_default_permissions_changed = true;
    bool is_status_changed = true;
    bool is_is_active_changed = true;
    bool is_noforwards_changed = true;
    bool is_being_updated = false;
    bool is_changed = true;             // have new changes that need to be sent to the client and database
    bool need_save_to_database = true;  // have new changes that need only to be saved to the database
    bool is_update_basic_group_sent = false;

    bool is_repaired = false;  // whether cached value is rechecked

    bool is_saved = false;        // is current chat version being saved/is saved to the database
    bool is_being_saved = false;  // is current chat being saved to the database

    bool is_received_from_server = false;  // true, if the chat was received from the server and not the database

    uint64 log_event_id = 0;

    template <class StorerT>
    void store(StorerT &storer) const;

    template <class ParserT>
    void parse(ParserT &parser);
  };

  // do not forget to update drop_chat_full and on_get_chat_full
  struct ChatFull {
    int32 version = -1;
    UserId creator_user_id;
    vector<DialogParticipant> participants;

    Photo photo;
    vector<FileId> registered_photo_file_ids;
    FileSourceId file_source_id;

    string description;

    DialogInviteLink invite_link;

    vector<BotCommands> bot_commands;

    bool can_set_username = false;

    bool is_being_updated = false;
    bool is_changed = true;             // have new changes that need to be sent to the client and database
    bool need_send_update = true;       // have new changes that need only to be sent to the client
    bool need_save_to_database = true;  // have new changes that need only to be saved to the database
    bool is_update_chat_full_sent = false;

    template <class StorerT>
    void store(StorerT &storer) const;

    template <class ParserT>
    void parse(ParserT &parser);
  };

  struct Channel {
    int64 access_hash = 0;
    string title;
    DialogPhoto photo;
    unique_ptr<EmojiStatus> emoji_status;
    unique_ptr<EmojiStatus> last_sent_emoji_status;
    AccentColorId accent_color_id;
    CustomEmojiId background_custom_emoji_id;
    AccentColorId profile_accent_color_id;
    CustomEmojiId profile_background_custom_emoji_id;
    Usernames usernames;
    vector<RestrictionReason> restriction_reasons;
    DialogParticipantStatus status = DialogParticipantStatus::Banned(0);
    RestrictedRights default_permissions{false, false, false, false, false, false, false, false, false,
                                         false, false, false, false, false, false, false, false, ChannelType::Unknown};
    int32 date = 0;
    int32 participant_count = 0;
    int32 boost_level = 0;
    int64 paid_message_star_count = 0;
    CustomEmojiId bot_verification_icon;

    double max_active_story_id_next_reload_time = 0.0;
    StoryId max_active_story_id;
    StoryId max_read_story_id;

    static constexpr uint32 CACHE_VERSION = 10;
    uint32 cache_version = 0;

    bool has_linked_channel = false;
    bool has_location = false;
    bool sign_messages = false;
    bool show_message_sender = false;
    bool is_slow_mode_enabled = false;
    bool noforwards = false;
    bool can_be_deleted = false;
    bool join_to_send = false;
    bool join_request = false;
    bool stories_hidden = false;
    bool autotranslation = false;

    bool is_megagroup = false;
    bool is_gigagroup = false;
    bool is_forum = false;
    bool is_verified = false;
    bool is_scam = false;
    bool is_fake = false;

    bool is_title_changed = true;
    bool is_username_changed = true;
    bool is_photo_changed = true;
    bool is_emoji_status_changed = true;
    bool is_accent_color_changed = true;
    bool is_default_permissions_changed = true;
    bool is_status_changed = true;
    bool is_stories_hidden_changed = true;
    bool is_has_location_changed = true;
    bool is_noforwards_changed = true;
    bool is_creator_changed = true;
    bool had_read_access = true;
    bool is_being_updated = false;
    bool is_changed = true;             // have new changes that need to be sent to the client and database
    bool need_save_to_database = true;  // have new changes that need only to be saved to the database
    bool is_update_supergroup_sent = false;

    bool is_repaired = false;  // whether cached value is rechecked

    bool is_saved = false;        // is current channel version being saved/is saved to the database
    bool is_being_saved = false;  // is current channel being saved to the database

    bool is_received_from_server = false;  // true, if the channel was received from the server and not the database

    uint64 log_event_id = 0;

    template <class StorerT>
    void store(StorerT &storer) const;

    template <class ParserT>
    void parse(ParserT &parser);
  };

  // do not forget to update invalidate_channel_full and on_get_chat_full
  struct ChannelFull {
    Photo photo;
    vector<FileId> registered_photo_file_ids;
    FileSourceId file_source_id;

    string description;
    int32 participant_count = 0;
    int32 administrator_count = 0;
    int32 restricted_count = 0;
    int32 banned_count = 0;
    int32 boost_count = 0;
    int32 unrestrict_boost_count = 0;
    int32 gift_count = 0;

    DialogInviteLink invite_link;

    vector<BotCommands> bot_commands;
    unique_ptr<BotVerification> bot_verification;

    uint32 speculative_version = 1;
    uint32 repair_request_version = 0;

    StickerSetId sticker_set_id;
    StickerSetId emoji_sticker_set_id;

    ChannelId linked_channel_id;

    DialogLocation location;

    DcId stats_dc_id;

    int32 slow_mode_delay = 0;
    int32 slow_mode_next_send_date = 0;

    MessageId migrated_from_max_message_id;
    ChatId migrated_from_chat_id;

    vector<UserId> bot_user_ids;

    bool can_get_participants = false;
    bool has_hidden_participants = false;
    bool can_set_username = false;
    bool can_set_sticker_set = false;
    bool can_set_location = false;
    bool can_view_statistics = false;
    bool is_can_view_statistics_inited = false;
    bool can_view_revenue = false;
    bool can_view_star_revenue = false;
    bool is_all_history_available = true;
    bool can_have_sponsored_messages = true;
    bool has_aggressive_anti_spam_enabled = false;
    bool can_be_deleted = false;
    bool has_pinned_stories = false;
    bool has_paid_media_allowed = false;  // also used for paid reactions
    bool has_stargifts_available = false;
    bool has_paid_messages_available = false;

    bool is_slow_mode_next_send_date_changed = true;
    bool is_being_updated = false;
    bool is_changed = true;             // have new changes that need to be sent to the client and database
    bool need_send_update = true;       // have new changes that need only to be sent to the client
    bool need_save_to_database = true;  // have new changes that need only to be saved to the database
    bool is_update_channel_full_sent = false;

    double expires_at = 0.0;

    bool is_expired() const {
      return expires_at < Time::now();
    }

    template <class StorerT>
    void store(StorerT &storer) const;

    template <class ParserT>
    void parse(ParserT &parser);
  };
  class ChatLogEvent;
  class ChannelLogEvent;

  static constexpr size_t MAX_TITLE_LENGTH = 128;        // server-side limit for chat title
  static constexpr size_t MAX_DESCRIPTION_LENGTH = 255;  // server-side limit for chat/channel description

  static constexpr int32 MAX_ACTIVE_STORY_ID_RELOAD_TIME = 3600;  // some reasonable limit

  static constexpr int32 CHANNEL_FULL_EXPIRE_TIME = 60;

  static bool have_input_peer_chat(const Chat *c, AccessRights access_rights);

  bool have_input_peer_channel(const Channel *c, ChannelId channel_id, AccessRights access_rights,
                               bool from_linked = false) const;

  const Chat *get_chat(ChatId chat_id) const;
  Chat *get_chat(ChatId chat_id);
  Chat *get_chat_force(ChatId chat_id, const char *source);

  Chat *add_chat(ChatId chat_id);

  const ChatFull *get_chat_full(ChatId chat_id) const;
  ChatFull *get_chat_full(ChatId chat_id);
  ChatFull *get_chat_full_force(ChatId chat_id, const char *source);

  ChatFull *add_chat_full(ChatId chat_id);

  void send_get_chat_full_query(ChatId chat_id, Promise<Unit> &&promise, const char *source);

  const Channel *get_channel(ChannelId channel_id) const;
  Channel *get_channel(ChannelId channel_id);
  Channel *get_channel_force(ChannelId channel_id, const char *source);

  Channel *add_channel(ChannelId channel_id, const char *source);

  const ChannelFull *get_channel_full(ChannelId channel_id) const;
  const ChannelFull *get_channel_full_const(ChannelId channel_id) const;
  ChannelFull *get_channel_full(ChannelId channel_id, bool only_local, const char *source);
  ChannelFull *get_channel_full_force(ChannelId channel_id, bool only_local, const char *source);

  ChannelFull *add_channel_full(ChannelId channel_id);

  void send_get_channel_full_query(ChannelFull *channel_full, ChannelId channel_id, Promise<Unit> &&promise,
                                   const char *source);

  static DialogParticipantStatus get_chat_status(const Chat *c);
  DialogParticipantStatus get_chat_permissions(const Chat *c) const;

  static ChannelType get_channel_type(const Channel *c);
  static DialogParticipantStatus get_channel_status(const Channel *c);
  DialogParticipantStatus get_channel_permissions(ChannelId channel_id, const Channel *c) const;
  td_api::object_ptr<td_api::verificationStatus> get_channel_verification_status_object(const Channel *c) const;
  static bool get_channel_sign_messages(const Channel *c);
  static bool get_channel_show_message_sender(const Channel *c);
  static bool get_channel_has_linked_channel(const Channel *c);
  static bool get_channel_can_be_deleted(const Channel *c);
  static bool get_channel_join_to_send(const Channel *c);
  static bool get_channel_join_request(const Channel *c);

  void on_update_chat_status(Chat *c, ChatId chat_id, DialogParticipantStatus status);
  static void on_update_chat_default_permissions(Chat *c, ChatId chat_id, RestrictedRights default_permissions,
                                                 int32 version);
  void on_update_chat_participant_count(Chat *c, ChatId chat_id, int32 participant_count, int32 version,
                                        const string &debug_str);
  void on_update_chat_photo(Chat *c, ChatId chat_id, tl_object_ptr<telegram_api::ChatPhoto> &&chat_photo_ptr);
  void on_update_chat_photo(Chat *c, ChatId chat_id, DialogPhoto &&photo, bool invalidate_photo_cache);
  static void on_update_chat_title(Chat *c, ChatId chat_id, string &&title);
  static void on_update_chat_active(Chat *c, ChatId chat_id, bool is_active);
  static void on_update_chat_migrated_to_channel_id(Chat *c, ChatId chat_id, ChannelId migrated_to_channel_id);
  static void on_update_chat_noforwards(Chat *c, ChatId chat_id, bool noforwards);

  void on_update_chat_full_photo(ChatFull *chat_full, ChatId chat_id, Photo photo);
  bool on_update_chat_full_participants_short(ChatFull *chat_full, ChatId chat_id, int32 version);
  void on_update_chat_full_participants(ChatFull *chat_full, ChatId chat_id, vector<DialogParticipant> participants,
                                        int32 version, bool from_update);
  void on_update_chat_full_invite_link(ChatFull *chat_full,
                                       tl_object_ptr<telegram_api::ExportedChatInvite> &&invite_link);

  void on_update_channel_photo(Channel *c, ChannelId channel_id,
                               tl_object_ptr<telegram_api::ChatPhoto> &&chat_photo_ptr);
  void on_update_channel_photo(Channel *c, ChannelId channel_id, DialogPhoto &&photo, bool invalidate_photo_cache);
  void on_update_channel_emoji_status(Channel *c, ChannelId channel_id, unique_ptr<EmojiStatus> emoji_status);
  void on_update_channel_accent_color_id(Channel *c, ChannelId channel_id, AccentColorId accent_color_id);
  void on_update_channel_background_custom_emoji_id(Channel *c, ChannelId channel_id,
                                                    CustomEmojiId background_custom_emoji_id);
  void on_update_channel_profile_accent_color_id(Channel *c, ChannelId channel_id,
                                                 AccentColorId profile_accent_color_id);
  void on_update_channel_profile_background_custom_emoji_id(Channel *c, ChannelId channel_id,
                                                            CustomEmojiId profile_background_custom_emoji_id);
  static void on_update_channel_title(Channel *c, ChannelId channel_id, string &&title);
  void on_update_channel_usernames(Channel *c, ChannelId channel_id, Usernames &&usernames);
  void on_update_channel_status(Channel *c, ChannelId channel_id, DialogParticipantStatus &&status);
  static void on_update_channel_default_permissions(Channel *c, ChannelId channel_id,
                                                    RestrictedRights default_permissions);
  static void on_update_channel_has_location(Channel *c, ChannelId channel_id, bool has_location);
  static void on_update_channel_noforwards(Channel *c, ChannelId channel_id, bool noforwards);
  void on_update_channel_stories_hidden(Channel *c, ChannelId channel_id, bool stories_hidden);
  void on_update_channel_story_ids_impl(Channel *c, ChannelId channel_id, StoryId max_active_story_id,
                                        StoryId max_read_story_id);
  void on_update_channel_max_read_story_id(Channel *c, ChannelId channel_id, StoryId max_read_story_id);
  void on_update_channel_bot_verification_icon(Channel *c, ChannelId channel_id, CustomEmojiId bot_verification_icon);

  void on_update_channel_full_photo(ChannelFull *channel_full, ChannelId channel_id, Photo photo);
  void on_update_channel_full_invite_link(ChannelFull *channel_full,
                                          tl_object_ptr<telegram_api::ExportedChatInvite> &&invite_link);
  void on_update_channel_full_linked_channel_id(ChannelFull *channel_full, ChannelId channel_id,
                                                ChannelId linked_channel_id);
  void on_update_channel_full_location(ChannelFull *channel_full, ChannelId channel_id, const DialogLocation &location);
  void on_update_channel_full_slow_mode_delay(ChannelFull *channel_full, ChannelId channel_id, int32 slow_mode_delay,
                                              int32 slow_mode_next_send_date);
  static void on_update_channel_full_slow_mode_next_send_date(ChannelFull *channel_full,
                                                              int32 slow_mode_next_send_date);
  static void on_update_channel_full_bot_user_ids(ChannelFull *channel_full, ChannelId channel_id,
                                                  vector<UserId> &&bot_user_ids);

  void on_channel_status_changed(Channel *c, ChannelId channel_id, const DialogParticipantStatus &old_status,
                                 const DialogParticipantStatus &new_status);
  void on_channel_usernames_changed(const Channel *c, ChannelId channel_id, const Usernames &old_usernames,
                                    const Usernames &new_usernames);

  void remove_linked_channel_id(ChannelId channel_id);
  ChannelId get_linked_channel_id(ChannelId channel_id) const;

  static bool speculative_add_count(int32 &count, int32 delta_count, int32 min_count = 0);

  void speculative_add_channel_participant_count(ChannelId channel_id, int32 delta_participant_count, bool by_me);

  void drop_chat_full(ChatId chat_id);

  void do_invalidate_channel_full(ChannelFull *channel_full, ChannelId channel_id, bool need_drop_slow_mode_delay);

  void update_chat_online_member_count(const ChatFull *chat_full, ChatId chat_id, bool is_from_server);

  void on_get_chat_empty(telegram_api::chatEmpty &chat, const char *source);
  void on_get_chat(telegram_api::chat &chat, const char *source);
  void on_get_chat_forbidden(telegram_api::chatForbidden &chat, const char *source);
  void on_get_channel(telegram_api::channel &channel, const char *source);
  void on_get_channel_forbidden(telegram_api::channelForbidden &channel, const char *source);

  void save_chat(Chat *c, ChatId chat_id, bool from_binlog);
  static string get_chat_database_key(ChatId chat_id);
  static string get_chat_database_value(const Chat *c);
  void save_chat_to_database(Chat *c, ChatId chat_id);
  void save_chat_to_database_impl(Chat *c, ChatId chat_id, string value);
  void on_save_chat_to_database(ChatId chat_id, bool success);
  void load_chat_from_database(Chat *c, ChatId chat_id, Promise<Unit> promise);
  void load_chat_from_database_impl(ChatId chat_id, Promise<Unit> promise);
  void on_load_chat_from_database(ChatId chat_id, string value, bool force);

  void save_channel(Channel *c, ChannelId channel_id, bool from_binlog);
  static string get_channel_database_key(ChannelId channel_id);
  static string get_channel_database_value(const Channel *c);
  void save_channel_to_database(Channel *c, ChannelId channel_id);
  void save_channel_to_database_impl(Channel *c, ChannelId channel_id, string value);
  void on_save_channel_to_database(ChannelId channel_id, bool success);
  void load_channel_from_database(Channel *c, ChannelId channel_id, Promise<Unit> promise);
  void load_channel_from_database_impl(ChannelId channel_id, Promise<Unit> promise);
  void on_load_channel_from_database(ChannelId channel_id, string value, bool force);

  static void save_chat_full(const ChatFull *chat_full, ChatId chat_id);
  static string get_chat_full_database_key(ChatId chat_id);
  static string get_chat_full_database_value(const ChatFull *chat_full);
  void on_load_chat_full_from_database(ChatId chat_id, string value);

  static void save_channel_full(const ChannelFull *channel_full, ChannelId channel_id);
  static string get_channel_full_database_key(ChannelId channel_id);
  static string get_channel_full_database_value(const ChannelFull *channel_full);
  void on_load_channel_full_from_database(ChannelId channel_id, string value, const char *source);

  void update_chat(Chat *c, ChatId chat_id, bool from_binlog = false, bool from_database = false);
  void update_channel(Channel *c, ChannelId channel_id, bool from_binlog = false, bool from_database = false);

  void update_chat_full(ChatFull *chat_full, ChatId chat_id, const char *source, bool from_database = false);
  void update_channel_full(ChannelFull *channel_full, ChannelId channel_id, const char *source,
                           bool from_database = false);

  bool is_chat_full_outdated(const ChatFull *chat_full, const Chat *c, ChatId chat_id, bool only_participants) const;

  static bool is_channel_public(const Channel *c);

  static bool is_suitable_created_public_channel(PublicDialogType type, const Channel *c);

  static void return_created_public_dialogs(Promise<td_api::object_ptr<td_api::chats>> &&promise,
                                            const vector<ChannelId> &channel_ids);

  void finish_get_created_public_dialogs(PublicDialogType type, Result<Unit> &&result);

  void update_created_public_channels(Channel *c, ChannelId channel_id);

  void save_created_public_channels(PublicDialogType type);

  bool update_permanent_invite_link(DialogInviteLink &invite_link, DialogInviteLink new_invite_link);

  static const DialogParticipant *get_chat_full_participant(const ChatFull *chat_full, DialogId dialog_id);

  void finish_get_chat_participant(ChatId chat_id, UserId user_id, Promise<DialogParticipant> &&promise);

  td_api::object_ptr<td_api::updateBasicGroup> get_update_basic_group_object(ChatId chat_id, const Chat *c);

  static td_api::object_ptr<td_api::updateBasicGroup> get_update_unknown_basic_group_object(ChatId chat_id);

  tl_object_ptr<td_api::basicGroup> get_basic_group_object(ChatId chat_id, const Chat *c);

  tl_object_ptr<td_api::basicGroup> get_basic_group_object_const(ChatId chat_id, const Chat *c) const;

  tl_object_ptr<td_api::basicGroupFullInfo> get_basic_group_full_info_object(ChatId chat_id,
                                                                             const ChatFull *chat_full) const;

  bool need_poll_channel_active_stories(const Channel *c, ChannelId channel_id) const;

  static bool get_channel_has_unread_stories(const Channel *c);

  td_api::object_ptr<td_api::updateSupergroup> get_update_supergroup_object(ChannelId channel_id,
                                                                            const Channel *c) const;

  td_api::object_ptr<td_api::updateSupergroup> get_update_unknown_supergroup_object(ChannelId channel_id) const;

  td_api::object_ptr<td_api::supergroup> get_supergroup_object(ChannelId channel_id, const Channel *c) const;

  Status can_hide_chat_participants(ChatId chat_id) const;

  Status can_hide_channel_participants(ChannelId channel_id, const ChannelFull *channel_full) const;

  Status can_toggle_chat_aggressive_anti_spam(ChatId chat_id) const;

  Status can_toggle_channel_aggressive_anti_spam(ChannelId channel_id, const ChannelFull *channel_full) const;

  tl_object_ptr<td_api::supergroupFullInfo> get_supergroup_full_info_object(ChannelId channel_id,
                                                                            const ChannelFull *channel_full) const;

  vector<DialogId> get_dialog_ids(vector<tl_object_ptr<telegram_api::Chat>> &&chats, const char *source);

  void on_create_inactive_channels(vector<ChannelId> &&channel_ids, Promise<Unit> &&promise);

  void update_dialogs_for_discussion(DialogId dialog_id, bool is_suitable);

  void get_channel_statistics_dc_id_impl(ChannelId channel_id, bool for_full_statistics, Promise<DcId> &&promise);

  static void on_channel_emoji_status_timeout_callback(void *chat_manager_ptr, int64 channel_id_long);

  static void on_channel_unban_timeout_callback(void *chat_manager_ptr, int64 channel_id_long);

  static void on_slow_mode_delay_timeout_callback(void *chat_manager_ptr, int64 channel_id_long);

  void on_channel_emoji_status_timeout(ChannelId channel_id);

  void on_channel_unban_timeout(ChannelId channel_id);

  void on_slow_mode_delay_timeout(ChannelId channel_id);

  void tear_down() final;

  Td *td_;
  ActorShared<> parent_;

  WaitFreeHashMap<ChatId, unique_ptr<Chat>, ChatIdHash> chats_;
  WaitFreeHashMap<ChatId, unique_ptr<ChatFull>, ChatIdHash> chats_full_;
  mutable FlatHashSet<ChatId, ChatIdHash> unknown_chats_;
  WaitFreeHashMap<ChatId, FileSourceId, ChatIdHash> chat_full_file_source_ids_;

  WaitFreeHashMap<ChannelId, unique_ptr<MinChannel>, ChannelIdHash> min_channels_;
  WaitFreeHashMap<ChannelId, unique_ptr<Channel>, ChannelIdHash> channels_;
  WaitFreeHashMap<ChannelId, unique_ptr<ChannelFull>, ChannelIdHash> channels_full_;
  mutable FlatHashSet<ChannelId, ChannelIdHash> unknown_channels_;
  WaitFreeHashSet<ChannelId, ChannelIdHash> invalidated_channels_full_;
  WaitFreeHashMap<ChannelId, FileSourceId, ChannelIdHash> channel_full_file_source_ids_;

  bool created_public_channels_inited_[3] = {false, false, false};
  vector<ChannelId> created_public_channels_[3];
  vector<Promise<td_api::object_ptr<td_api::chats>>> get_created_public_channels_queries_[3];

  bool dialogs_for_discussion_inited_ = false;
  vector<DialogId> dialogs_for_discussion_;

  bool inactive_channel_ids_inited_ = false;
  vector<ChannelId> inactive_channel_ids_;

  FlatHashMap<ChatId, vector<Promise<Unit>>, ChatIdHash> load_chat_from_database_queries_;
  FlatHashSet<ChatId, ChatIdHash> loaded_from_database_chats_;
  FlatHashSet<ChatId, ChatIdHash> unavailable_chat_fulls_;

  FlatHashMap<ChannelId, vector<Promise<Unit>>, ChannelIdHash> load_channel_from_database_queries_;
  FlatHashSet<ChannelId, ChannelIdHash> loaded_from_database_channels_;
  FlatHashSet<ChannelId, ChannelIdHash> unavailable_channel_fulls_;

  QueryMerger get_chat_queries_{"GetChatMerger", 3, 50};
  QueryMerger get_channel_queries_{"GetChannelMerger", 100, 1};  // can't merge getChannel queries without access hash

  QueryCombiner get_chat_full_queries_{"GetChatFullCombiner", 2.0};

  FlatHashMap<ChannelId, FlatHashSet<MessageFullId, MessageFullIdHash>, ChannelIdHash> channel_messages_;

  WaitFreeHashMap<ChannelId, ChannelId, ChannelIdHash> linked_channel_ids_;

  WaitFreeHashSet<ChannelId, ChannelIdHash> restricted_channel_ids_;

  MultiTimeout channel_emoji_status_timeout_{"ChannelEmojiStatusTimeout"};
  MultiTimeout channel_unban_timeout_{"ChannelUnbanTimeout"};
  MultiTimeout slow_mode_delay_timeout_{"SlowModeDelayTimeout"};
};

}  // namespace td
