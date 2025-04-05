//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/AccentColorId.h"
#include "td/telegram/AccessRights.h"
#include "td/telegram/ChannelId.h"
#include "td/telegram/ChatId.h"
#include "td/telegram/CustomEmojiId.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/DialogLocation.h"
#include "td/telegram/DialogParticipant.h"
#include "td/telegram/files/FileId.h"
#include "td/telegram/files/FileUploadId.h"
#include "td/telegram/FolderId.h"
#include "td/telegram/InputDialogId.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/NotificationSettingsScope.h"
#include "td/telegram/Photo.h"
#include "td/telegram/RecentDialogList.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/FlatHashSet.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"
#include "td/utils/WaitFreeHashMap.h"

#include <memory>
#include <utility>

namespace td {

struct BinlogEvent;
struct ChatReactions;
class EmojiStatus;
class ReportReason;
class Td;
class Usernames;

class DialogManager final : public Actor {
 public:
  DialogManager(Td *td, ActorShared<> parent);
  DialogManager(const DialogManager &) = delete;
  DialogManager &operator=(const DialogManager &) = delete;
  DialogManager(DialogManager &&) = delete;
  DialogManager &operator=(DialogManager &&) = delete;
  ~DialogManager() final;

  DialogId get_my_dialog_id() const;

  InputDialogId get_input_dialog_id(DialogId dialog_id) const;

  tl_object_ptr<telegram_api::InputPeer> get_input_peer(DialogId dialog_id, AccessRights access_rights) const;

  static tl_object_ptr<telegram_api::InputPeer> get_input_peer_force(DialogId dialog_id);

  vector<tl_object_ptr<telegram_api::InputPeer>> get_input_peers(const vector<DialogId> &dialog_ids,
                                                                 AccessRights access_rights) const;

  tl_object_ptr<telegram_api::InputDialogPeer> get_input_dialog_peer(DialogId dialog_id,
                                                                     AccessRights access_rights) const;

  vector<tl_object_ptr<telegram_api::InputDialogPeer>> get_input_dialog_peers(const vector<DialogId> &dialog_ids,
                                                                              AccessRights access_rights) const;

  tl_object_ptr<telegram_api::inputEncryptedChat> get_input_encrypted_chat(DialogId dialog_id,
                                                                           AccessRights access_rights) const;

  Status check_dialog_access(DialogId dialog_id, bool allow_secret_chats, AccessRights access_rights,
                             const char *source) const;

  Status check_dialog_access_in_memory(DialogId dialog_id, bool allow_secret_chats, AccessRights access_rights) const;

  bool have_input_peer(DialogId dialog_id, bool allow_secret_chats, AccessRights access_rights) const;

  bool have_dialog_force(DialogId dialog_id, const char *source) const;

  void force_create_dialog(DialogId dialog_id, const char *source, bool expect_no_access = false,
                           bool force_update_dialog_pos = false);

  vector<DialogId> get_peers_dialog_ids(vector<telegram_api::object_ptr<telegram_api::Peer>> &&peers,
                                        bool expect_no_access = false);

  bool have_dialog_info(DialogId dialog_id) const;

  bool have_dialog_info_force(DialogId dialog_id, const char *source) const;

  void reload_dialog_info(DialogId dialog_id, Promise<Unit> &&promise);

  bool is_dialog_info_received_from_server(DialogId dialog_id) const;

  void get_dialog_info_full(DialogId dialog_id, Promise<Unit> &&promise, const char *source);

  void reload_dialog_info_full(DialogId dialog_id, const char *source);

  void on_dialog_info_full_invalidated(DialogId dialog_id);

  int64 get_chat_id_object(DialogId dialog_id, const char *source) const;

  vector<int64> get_chat_ids_object(const vector<DialogId> &dialog_ids, const char *source) const;

  td_api::object_ptr<td_api::chats> get_chats_object(int32 total_count, const vector<DialogId> &dialog_ids,
                                                     const char *source) const;

  td_api::object_ptr<td_api::chats> get_chats_object(const std::pair<int32, vector<DialogId>> &dialog_ids,
                                                     const char *source) const;

  td_api::object_ptr<td_api::ChatType> get_chat_type_object(DialogId dialog_id, const char *source) const;

  NotificationSettingsScope get_dialog_notification_setting_scope(DialogId dialog_id) const;

  void migrate_dialog_to_megagroup(DialogId dialog_id, Promise<td_api::object_ptr<td_api::chat>> &&promise);

  void on_dialog_opened(DialogId dialog_id);

  void on_dialog_deleted(DialogId dialog_id);

  Status add_recently_found_dialog(DialogId dialog_id) TD_WARN_UNUSED_RESULT;

  Status remove_recently_found_dialog(DialogId dialog_id) TD_WARN_UNUSED_RESULT;

  void clear_recently_found_dialogs();

  std::pair<int32, vector<DialogId>> search_recently_found_dialogs(const string &query, int32 limit,
                                                                   Promise<Unit> &&promise);

  std::pair<int32, vector<DialogId>> get_recently_opened_dialogs(int32 limit, Promise<Unit> &&promise);

  bool is_anonymous_administrator(DialogId dialog_id, string *author_signature) const;

  bool is_group_dialog(DialogId dialog_id) const;

  bool is_forum_channel(DialogId dialog_id) const;

  bool is_broadcast_channel(DialogId dialog_id) const;

  bool on_get_dialog_error(DialogId dialog_id, const Status &status, const char *source);

  void delete_dialog(DialogId dialog_id, Promise<Unit> &&promise);

  string get_dialog_title(DialogId dialog_id) const;

  const DialogPhoto *get_dialog_photo(DialogId dialog_id) const;

  int32 get_dialog_accent_color_id_object(DialogId dialog_id) const;

  CustomEmojiId get_dialog_background_custom_emoji_id(DialogId dialog_id) const;

  int32 get_dialog_profile_accent_color_id_object(DialogId dialog_id) const;

  CustomEmojiId get_dialog_profile_background_custom_emoji_id(DialogId dialog_id) const;

  RestrictedRights get_dialog_default_permissions(DialogId dialog_id) const;

  td_api::object_ptr<td_api::emojiStatus> get_dialog_emoji_status_object(DialogId dialog_id) const;

  string get_dialog_about(DialogId dialog_id);

  string get_dialog_search_text(DialogId dialog_id) const;

  bool get_dialog_has_protected_content(DialogId dialog_id) const;

  bool is_dialog_action_unneeded(DialogId dialog_id) const;

  void set_dialog_title(DialogId dialog_id, const string &title, Promise<Unit> &&promise);

  void set_dialog_photo(DialogId dialog_id, const td_api::object_ptr<td_api::InputChatPhoto> &input_photo,
                        Promise<Unit> &&promise);

  void set_dialog_accent_color(DialogId dialog_id, AccentColorId accent_color_id,
                               CustomEmojiId background_custom_emoji_id, Promise<Unit> &&promise);

  void set_dialog_profile_accent_color(DialogId dialog_id, AccentColorId profile_accent_color_id,
                                       CustomEmojiId profile_background_custom_emoji_id, Promise<Unit> &&promise);

  void set_dialog_permissions(DialogId dialog_id, const td_api::object_ptr<td_api::chatPermissions> &permissions,
                              Promise<Unit> &&promise);

  void set_dialog_emoji_status(DialogId dialog_id, const unique_ptr<EmojiStatus> &emoji_status,
                               Promise<Unit> &&promise);

  void toggle_dialog_has_protected_content(DialogId dialog_id, bool has_protected_content, Promise<Unit> &&promise);

  void set_dialog_description(DialogId dialog_id, const string &description, Promise<Unit> &&promise);

  void set_dialog_location(DialogId dialog_id, const DialogLocation &location, Promise<Unit> &&promise);

  void load_dialog_marks_as_unread();

  bool can_report_dialog(DialogId dialog_id) const;

  void report_dialog(DialogId dialog_id, const string &option_id, const vector<MessageId> &message_ids,
                     const string &text, Promise<td_api::object_ptr<td_api::ReportChatResult>> &&promise);

  void report_dialog_photo(DialogId dialog_id, FileId file_id, ReportReason &&reason, Promise<Unit> &&promise);

  Status can_pin_messages(DialogId dialog_id) const;

  bool can_use_premium_custom_emoji_in_dialog(DialogId dialog_id) const;

  bool is_dialog_removed_from_dialog_list(DialogId dialog_id) const;

  void upload_dialog_photo(DialogId dialog_id, FileUploadId file_upload_id, bool is_animation,
                           double main_frame_timestamp, bool is_reupload, Promise<Unit> &&promise,
                           vector<int> bad_parts = {});

  void on_update_dialog_bot_commands(DialogId dialog_id, UserId bot_user_id,
                                     vector<telegram_api::object_ptr<telegram_api::botCommand>> &&bot_commands);

  void on_dialog_usernames_updated(DialogId dialog_id, const Usernames &old_usernames, const Usernames &new_usernames);

  void on_dialog_usernames_received(DialogId dialog_id, const Usernames &usernames, bool from_database);

  enum class CheckDialogUsernameResult : uint8 {
    Ok,
    Invalid,
    Occupied,
    Purchasable,
    PublicDialogsTooMany,
    PublicGroupsUnavailable
  };
  void check_dialog_username(DialogId dialog_id, const string &username, Promise<CheckDialogUsernameResult> &&promise);

  static td_api::object_ptr<td_api::CheckChatUsernameResult> get_check_chat_username_result_object(
      CheckDialogUsernameResult result);

  void resolve_dialog(const string &username, ChannelId channel_id, Promise<DialogId> promise);

  DialogId get_resolved_dialog_by_username(const string &username) const;

  DialogId resolve_dialog_username(const string &username, Promise<Unit> &promise);

  DialogId search_public_dialog(const string &username_to_search, bool force, Promise<Unit> &&promise);

  void on_get_public_dialogs_search_result(const string &query,
                                           vector<telegram_api::object_ptr<telegram_api::Peer>> &&my_peers,
                                           vector<telegram_api::object_ptr<telegram_api::Peer>> &&peers);

  void on_failed_public_dialogs_search(const string &query, Status &&error);

  vector<DialogId> search_public_dialogs(const string &query, Promise<Unit> &&promise);

  vector<DialogId> search_dialogs_on_server(const string &query, int32 limit, Promise<Unit> &&promise);

  void reload_voice_chat_on_search(const string &username);

  void reget_peer_settings(DialogId dialog_id);

  void toggle_dialog_report_spam_state_on_server(DialogId dialog_id, bool is_spam_dialog, uint64 log_event_id,
                                                 Promise<Unit> &&promise);

  void get_blocked_dialogs(const td_api::object_ptr<td_api::BlockList> &block_list, int32 offset, int32 limit,
                           Promise<td_api::object_ptr<td_api::messageSenders>> &&promise);

  void on_get_blocked_dialogs(int32 offset, int32 limit, int32 total_count,
                              vector<telegram_api::object_ptr<telegram_api::peerBlocked>> &&blocked_peers,
                              Promise<td_api::object_ptr<td_api::messageSenders>> &&promise);

  void reorder_pinned_dialogs_on_server(FolderId folder_id, const vector<DialogId> &dialog_ids, uint64 log_event_id);

  void set_dialog_available_reactions_on_server(DialogId dialog_id, const ChatReactions &available_reactions,
                                                Promise<Unit> &&promise);

  void set_dialog_default_send_as_on_server(DialogId dialog_id, DialogId send_as_dialog_id, Promise<Unit> &&promise);

  void set_dialog_folder_id_on_server(DialogId dialog_id, FolderId folder_id, Promise<Unit> &&promise);

  void set_dialog_message_ttl_on_server(DialogId dialog_id, int32 ttl, Promise<Unit> &&promise);

  void set_dialog_theme_on_server(DialogId dialog_id, const string &theme_name, Promise<Unit> &&promise);

  void toggle_dialog_is_blocked_on_server(DialogId dialog_id, bool is_blocked, bool is_blocked_for_stories,
                                          uint64 log_event_id);

  void toggle_dialog_is_marked_as_unread_on_server(DialogId dialog_id, bool is_marked_as_unread, uint64 log_event_id);

  void toggle_dialog_is_pinned_on_server(DialogId dialog_id, bool is_pinned, uint64 log_event_id);

  void toggle_dialog_is_translatable_on_server(DialogId dialog_id, bool is_translatable, uint64 log_event_id);

  void toggle_dialog_view_as_messages_on_server(DialogId dialog_id, bool view_as_messages, uint64 log_event_id);

  void on_binlog_events(vector<BinlogEvent> &&events);

 private:
  static constexpr size_t MAX_TITLE_LENGTH = 128;                  // server-side limit for chat title
  static constexpr int32 MIN_SEARCH_PUBLIC_DIALOG_PREFIX_LEN = 4;  // server-side limit
  static constexpr int32 MAX_GET_DIALOGS = 100;                    // server-side limit
  static constexpr int32 MAX_RECENT_DIALOGS = 50;                  // some reasonable value

  static constexpr int32 USERNAME_CACHE_EXPIRE_TIME = 86400;

  void hangup() final;

  void tear_down() final;

  void on_migrate_chat_to_megagroup(ChatId chat_id, Promise<td_api::object_ptr<td_api::chat>> &&promise);

  void on_upload_dialog_photo(FileUploadId file_upload_id,
                              telegram_api::object_ptr<telegram_api::InputFile> input_file);

  void on_upload_dialog_photo_error(FileUploadId file_upload_id, Status status);

  void send_edit_dialog_photo_query(DialogId dialog_id, FileUploadId file_upload_id,
                                    telegram_api::object_ptr<telegram_api::InputChatPhoto> &&input_chat_photo,
                                    Promise<Unit> &&promise);

  void send_resolve_dialog_username_query(const string &username, Promise<Unit> &&promise);

  void on_resolved_username(const string &username, Result<DialogId> r_dialog_id);

  void drop_username(const string &username);

  void on_resolve_dialog(const string &username, ChannelId channel_id, Promise<DialogId> &&promise);

  void send_search_public_dialogs_query(const string &query, Promise<Unit> &&promise);

  static uint64 save_reorder_pinned_dialogs_on_server_log_event(FolderId folder_id, const vector<DialogId> &dialog_ids);

  static uint64 save_toggle_dialog_is_blocked_on_server_log_event(DialogId dialog_id, bool is_blocked,
                                                                  bool is_blocked_for_stories);

  static uint64 save_toggle_dialog_is_marked_as_unread_on_server_log_event(DialogId dialog_id,
                                                                           bool is_marked_as_unread);

  static uint64 save_toggle_dialog_is_pinned_on_server_log_event(DialogId dialog_id, bool is_pinned);

  static uint64 save_toggle_dialog_is_translatable_on_server_log_event(DialogId dialog_id, bool is_translatable);

  static uint64 save_toggle_dialog_report_spam_state_on_server_log_event(DialogId dialog_id, bool is_spam_dialog);

  static uint64 save_toggle_dialog_view_as_messages_on_server_log_event(DialogId dialog_id, bool view_as_messages);

  class ReorderPinnedDialogsOnServerLogEvent;
  class ToggleDialogIsBlockedOnServerLogEvent;
  class ToggleDialogPropertyOnServerLogEvent;
  class ToggleDialogReportSpamStateOnServerLogEvent;

  class UploadDialogPhotoCallback;
  std::shared_ptr<UploadDialogPhotoCallback> upload_dialog_photo_callback_;

  struct UploadedDialogPhotoInfo {
    DialogId dialog_id;
    double main_frame_timestamp;
    bool is_animation;
    bool is_reupload;
    Promise<Unit> promise;

    UploadedDialogPhotoInfo(DialogId dialog_id, double main_frame_timestamp, bool is_animation, bool is_reupload,
                            Promise<Unit> promise)
        : dialog_id(dialog_id)
        , main_frame_timestamp(main_frame_timestamp)
        , is_animation(is_animation)
        , is_reupload(is_reupload)
        , promise(std::move(promise)) {
    }
  };
  FlatHashMap<FileUploadId, UploadedDialogPhotoInfo, FileUploadIdHash> being_uploaded_dialog_photos_;

  struct ResolvedUsername {
    DialogId dialog_id;
    double expires_at = 0.0;

    ResolvedUsername() = default;
    ResolvedUsername(DialogId dialog_id, double expires_at) : dialog_id(dialog_id), expires_at(expires_at) {
    }
  };
  WaitFreeHashMap<string, ResolvedUsername> resolved_usernames_;
  WaitFreeHashMap<string, DialogId> inaccessible_resolved_usernames_;
  FlatHashSet<string> reload_voice_chat_on_search_usernames_;

  FlatHashMap<string, vector<Promise<Unit>>> resolve_dialog_username_queries_;

  FlatHashMap<string, vector<Promise<Unit>>> search_public_dialogs_queries_;
  FlatHashMap<string, vector<DialogId>> found_public_dialogs_;     // TODO time bound cache
  FlatHashMap<string, vector<DialogId>> found_on_server_dialogs_;  // TODO time bound cache

  RecentDialogList recently_found_dialogs_;
  RecentDialogList recently_opened_dialogs_;

  Td *td_;
  ActorShared<> parent_;
};

}  // namespace td
