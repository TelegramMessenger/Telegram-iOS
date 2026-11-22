//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/AccentColorId.h"
#include "td/telegram/AccessRights.h"
#include "td/telegram/Birthdate.h"
#include "td/telegram/BotCommand.h"
#include "td/telegram/BotMenuButton.h"
#include "td/telegram/BotVerifierSettings.h"
#include "td/telegram/BusinessConnectionId.h"
#include "td/telegram/ChannelId.h"
#include "td/telegram/Contact.h"
#include "td/telegram/CustomEmojiId.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/DialogLocation.h"
#include "td/telegram/DialogParticipant.h"
#include "td/telegram/files/FileId.h"
#include "td/telegram/files/FileSourceId.h"
#include "td/telegram/files/FileUploadId.h"
#include "td/telegram/FolderId.h"
#include "td/telegram/MessageFullId.h"
#include "td/telegram/Photo.h"
#include "td/telegram/QueryCombiner.h"
#include "td/telegram/QueryMerger.h"
#include "td/telegram/ReferralProgramInfo.h"
#include "td/telegram/RestrictionReason.h"
#include "td/telegram/SecretChatId.h"
#include "td/telegram/StarGiftSettings.h"
#include "td/telegram/StoryId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"
#include "td/telegram/Usernames.h"

#include "td/actor/actor.h"
#include "td/actor/MultiPromise.h"
#include "td/actor/MultiTimeout.h"

#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/FlatHashSet.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/Hints.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/Time.h"
#include "td/utils/WaitFreeHashMap.h"
#include "td/utils/WaitFreeHashSet.h"

#include <functional>
#include <memory>
#include <utility>

namespace td {

struct BinlogEvent;
class BotVerification;
class BusinessAwayMessage;
class BusinessGreetingMessage;
class BusinessInfo;
class BusinessIntro;
class BusinessWorkHours;
class EmojiStatus;
class Td;

class UserManager final : public Actor {
 public:
  UserManager(Td *td, ActorShared<> parent);
  UserManager(const UserManager &) = delete;
  UserManager &operator=(const UserManager &) = delete;
  UserManager(UserManager &&) = delete;
  UserManager &operator=(UserManager &&) = delete;
  ~UserManager() final;

  static UserId get_user_id(const telegram_api::object_ptr<telegram_api::User> &user);

  vector<UserId> get_user_ids(vector<telegram_api::object_ptr<telegram_api::User>> &&users, const char *source);

  static UserId load_my_id();

  UserId get_my_id() const;

  static UserId get_service_notifications_user_id();

  UserId add_service_notifications_user();

  static UserId get_replies_bot_user_id();

  static UserId get_verification_codes_bot_user_id();

  static UserId get_anonymous_bot_user_id();

  static UserId get_channel_bot_user_id();

  static UserId get_anti_spam_bot_user_id();

  UserId add_anonymous_bot_user();

  UserId add_channel_bot_user();

  struct MyOnlineStatusInfo {
    bool is_online_local = false;
    bool is_online_remote = false;
    int32 was_online_local = 0;
    int32 was_online_remote = 0;
  };
  MyOnlineStatusInfo get_my_online_status() const;

  void set_my_online_status(bool is_online, bool send_update, bool is_local);

  void on_get_user(telegram_api::object_ptr<telegram_api::User> &&user, const char *source);

  void on_get_users(vector<telegram_api::object_ptr<telegram_api::User>> &&users, const char *source);

  void on_binlog_user_event(BinlogEvent &&event);

  void on_binlog_secret_chat_event(BinlogEvent &&event);

  void on_update_user_name(UserId user_id, string &&first_name, string &&last_name);

  void on_update_user_usernames(UserId user_id, Usernames &&usernames);

  void on_update_user_phone_number(UserId user_id, string &&phone_number);

  void register_suggested_profile_photo(const Photo &photo);

  void on_update_user_emoji_status(UserId user_id, telegram_api::object_ptr<telegram_api::EmojiStatus> &&emoji_status);

  void on_update_user_story_ids(UserId user_id, StoryId max_active_story_id, StoryId max_read_story_id);

  void on_update_user_max_read_story_id(UserId user_id, StoryId max_read_story_id);

  void on_update_user_stories_hidden(UserId user_id, bool stories_hidden);

  void on_update_user_online(UserId user_id, telegram_api::object_ptr<telegram_api::UserStatus> &&status);

  void on_update_user_local_was_online(UserId user_id, int32 local_was_online);

  // use on_update_dialog_is_blocked instead
  void on_update_user_is_blocked(UserId user_id, bool is_blocked, bool is_blocked_for_stories);

  void on_update_user_has_pinned_stories(UserId user_id, bool has_pinned_stories);

  void on_update_user_common_chat_count(UserId user_id, int32 common_chat_count);

  void on_update_user_gift_count(UserId user_id, int32 gift_count);

  void on_update_my_gift_count(int32 added_gift_count);

  void on_update_my_user_gift_settings(StarGiftSettings &&gift_settings, Promise<Unit> &&promise);

  void on_update_my_user_location(DialogLocation &&location);

  void on_update_my_user_work_hours(BusinessWorkHours &&work_hours);

  void on_update_my_user_away_message(BusinessAwayMessage &&away_message);

  void on_update_my_user_greeting_message(BusinessGreetingMessage &&greeting_message);

  void on_update_my_user_intro(BusinessIntro &&intro);

  void on_update_user_commands(UserId user_id,
                               vector<telegram_api::object_ptr<telegram_api::botCommand>> &&bot_commands);

  void on_update_user_referral_program_info(UserId user_id, ReferralProgramInfo &&referral_program_info);

  void on_update_user_verifier_settings(UserId user_id, unique_ptr<BotVerifierSettings> &&verifier_settings);

  void on_update_user_need_phone_number_privacy_exception(UserId user_id, bool need_phone_number_privacy_exception);

  void on_update_user_charge_paid_message_stars(UserId user_id, int64 charge_paid_message_stars);

  void on_update_user_wallpaper_overridden(UserId user_id, bool wallpaper_overridden);

  void on_update_bot_menu_button(UserId bot_user_id,
                                 telegram_api::object_ptr<telegram_api::BotMenuButton> &&bot_menu_button);

  void on_update_bot_has_preview_medias(UserId bot_user_id, bool has_preview_medias);

  void on_update_bot_can_manage_emoji_status(UserId bot_user_id, bool can_manage_emoji_status);

  void on_update_secret_chat(SecretChatId secret_chat_id, int64 access_hash, UserId user_id, SecretChatState state,
                             bool is_outbound, int32 ttl, int32 date, string key_hash, int32 layer,
                             FolderId initial_folder_id);

  void on_update_online_status_privacy();

  void on_update_phone_number_privacy();

  void on_ignored_restriction_reasons_changed();

  void on_update_freeze_state(int32 freeze_since_date, int32 freeze_until_date, string freeze_appeal_url);

  void invalidate_user_full(UserId user_id);

  bool have_user(UserId user_id) const;

  bool have_min_user(UserId user_id) const;

  bool have_user_force(UserId user_id, const char *source);

  static void send_get_me_query(Td *td, Promise<Unit> &&promise);

  UserId get_me(Promise<Unit> &&promise);

  bool get_user(UserId user_id, int left_tries, Promise<Unit> &&promise);

  void reload_user(UserId user_id, Promise<Unit> &&promise, const char *source);

  Result<telegram_api::object_ptr<telegram_api::InputUser>> get_input_user(UserId user_id) const;

  telegram_api::object_ptr<telegram_api::InputUser> get_input_user_force(UserId user_id) const;

  bool have_input_peer_user(UserId user_id, AccessRights access_rights) const;

  telegram_api::object_ptr<telegram_api::InputPeer> get_input_peer_user(UserId user_id,
                                                                        AccessRights access_rights) const;

  bool have_input_encrypted_peer(SecretChatId secret_chat_id, AccessRights access_rights) const;

  telegram_api::object_ptr<telegram_api::inputEncryptedChat> get_input_encrypted_chat(SecretChatId secret_chat_id,
                                                                                      AccessRights access_rights) const;

  bool is_user_contact(UserId user_id, bool is_mutual = false) const;

  bool is_user_premium(UserId user_id) const;

  bool is_user_deleted(UserId user_id) const;

  bool is_user_support(UserId user_id) const;

  bool is_user_bot(UserId user_id) const;

  struct BotData {
    string username;
    bool can_be_edited = false;
    bool can_join_groups = false;
    bool can_read_all_group_messages = false;
    bool has_main_app = false;
    bool is_inline = false;
    bool is_business = false;
    bool need_location = false;
    bool can_be_added_to_attach_menu = false;
  };
  Result<BotData> get_bot_data(UserId user_id) const TD_WARN_UNUSED_RESULT;

  bool is_user_online(UserId user_id, int32 tolerance = 0, int32 unix_time = 0) const;

  int32 get_user_was_online(UserId user_id, int32 unix_time = 0) const;

  bool is_user_status_exact(UserId user_id) const;

  bool is_user_received_from_server(UserId user_id) const;

  bool can_report_user(UserId user_id) const;

  const DialogPhoto *get_user_dialog_photo(UserId user_id);

  const DialogPhoto *get_secret_chat_dialog_photo(SecretChatId secret_chat_id);

  int32 get_user_accent_color_id_object(UserId user_id) const;

  int32 get_secret_chat_accent_color_id_object(SecretChatId secret_chat_id) const;

  CustomEmojiId get_user_background_custom_emoji_id(UserId user_id) const;

  CustomEmojiId get_secret_chat_background_custom_emoji_id(SecretChatId secret_chat_id) const;

  int32 get_user_profile_accent_color_id_object(UserId user_id) const;

  int32 get_secret_chat_profile_accent_color_id_object(SecretChatId secret_chat_id) const;

  CustomEmojiId get_user_profile_background_custom_emoji_id(UserId user_id) const;

  CustomEmojiId get_secret_chat_profile_background_custom_emoji_id(SecretChatId secret_chat_id) const;

  string get_user_title(UserId user_id) const;

  string get_secret_chat_title(SecretChatId secret_chat_id) const;

  RestrictedRights get_user_default_permissions(UserId user_id) const;

  RestrictedRights get_secret_chat_default_permissions(SecretChatId secret_chat_id) const;

  td_api::object_ptr<td_api::emojiStatus> get_user_emoji_status_object(UserId user_id) const;

  td_api::object_ptr<td_api::emojiStatus> get_secret_chat_emoji_status_object(SecretChatId secret_chat_id) const;

  bool get_user_stories_hidden(UserId user_id) const;

  bool can_poll_user_active_stories(UserId user_id) const;

  string get_user_about(UserId user_id);

  string get_secret_chat_about(SecretChatId secret_chat_id);

  string get_user_private_forward_name(UserId user_id);

  bool get_user_voice_messages_forbidden(UserId user_id) const;

  bool get_my_sponsored_enabled() const;

  bool get_user_read_dates_private(UserId user_id);

  string get_user_search_text(UserId user_id) const;

  void for_each_secret_chat_with_user(UserId user_id, const std::function<void(SecretChatId)> &f);

  string get_user_first_username(UserId user_id) const;

  int32 get_secret_chat_date(SecretChatId secret_chat_id) const;

  int32 get_secret_chat_ttl(SecretChatId secret_chat_id) const;

  UserId get_secret_chat_user_id(SecretChatId secret_chat_id) const;

  bool get_secret_chat_is_outbound(SecretChatId secret_chat_id) const;

  SecretChatState get_secret_chat_state(SecretChatId secret_chat_id) const;

  int32 get_secret_chat_layer(SecretChatId secret_chat_id) const;

  FolderId get_secret_chat_initial_folder_id(SecretChatId secret_chat_id) const;

  vector<BotCommands> get_bot_commands(vector<telegram_api::object_ptr<telegram_api::botInfo>> &&bot_infos,
                                       const vector<DialogParticipant> *participants);

  void set_name(const string &first_name, const string &last_name, Promise<Unit> &&promise);

  void set_bio(const string &bio, Promise<Unit> &&promise);

  void on_update_profile_success(int32 flags, const string &first_name, const string &last_name, const string &about);

  FileId get_profile_photo_file_id(int64 photo_id) const;

  void set_bot_profile_photo(UserId bot_user_id, const td_api::object_ptr<td_api::InputChatPhoto> &input_photo,
                             Promise<Unit> &&promise);

  void set_business_profile_photo(BusinessConnectionId business_connection_id,
                                  const td_api::object_ptr<td_api::InputChatPhoto> &input_photo, bool is_fallback,
                                  Promise<Unit> &&promise);

  void set_profile_photo(const td_api::object_ptr<td_api::InputChatPhoto> &input_photo, bool is_fallback,
                         Promise<Unit> &&promise);

  void set_user_profile_photo(UserId user_id, const td_api::object_ptr<td_api::InputChatPhoto> &input_photo,
                              bool only_suggest, Promise<Unit> &&promise);

  void send_update_profile_photo_query(UserId user_id, FileId file_id, int64 old_photo_id, bool is_fallback,
                                       Promise<Unit> &&promise);

  void on_set_profile_photo(UserId user_id, telegram_api::object_ptr<telegram_api::photos_photo> &&photo,
                            bool is_fallback, int64 old_photo_id, Promise<Unit> &&promise);

  void delete_profile_photo(int64 profile_photo_id, bool is_recursive, Promise<Unit> &&promise);

  void on_delete_profile_photo(int64 profile_photo_id, Promise<Unit> promise);

  void toggle_user_can_manage_emoji_status(UserId user_id, bool can_manage_emoji_status, Promise<Unit> &&promise);

  void set_user_emoji_status(UserId user_id, const unique_ptr<EmojiStatus> &emoji_status, Promise<Unit> &&promise);

  void on_set_user_emoji_status(UserId user_id, unique_ptr<EmojiStatus> emoji_status, Promise<Unit> &&promise);

  void set_username(const string &username, Promise<Unit> &&promise);

  void toggle_username_is_active(string &&username, bool is_active, Promise<Unit> &&promise);

  void reorder_usernames(vector<string> &&usernames, Promise<Unit> &&promise);

  void toggle_bot_username_is_active(UserId bot_user_id, string &&username, bool is_active, Promise<Unit> &&promise);

  void reorder_bot_usernames(UserId bot_user_id, vector<string> &&usernames, Promise<Unit> &&promise);

  void on_update_username_is_active(UserId user_id, string &&username, bool is_active, Promise<Unit> &&promise);

  void on_update_active_usernames_order(UserId user_id, vector<string> &&usernames, Promise<Unit> &&promise);

  void set_accent_color(AccentColorId accent_color_id, CustomEmojiId background_custom_emoji_id,
                        Promise<Unit> &&promise);

  void set_profile_accent_color(AccentColorId accent_color_id, CustomEmojiId background_custom_emoji_id,
                                Promise<Unit> &&promise);

  void on_update_accent_color_success(bool for_profile, AccentColorId accent_color_id,
                                      CustomEmojiId background_custom_emoji_id);

  void set_birthdate(Birthdate &&birthdate, Promise<Unit> &&promise);

  void set_personal_channel(DialogId dialog_id, Promise<Unit> &&promise);

  void set_emoji_status(const unique_ptr<EmojiStatus> &emoji_status, Promise<Unit> &&promise);

  void toggle_sponsored_messages(bool sponsored_enabled, Promise<Unit> &&promise);

  void get_support_user(Promise<td_api::object_ptr<td_api::user>> &&promise);

  void get_user_profile_photos(UserId user_id, int32 offset, int32 limit,
                               Promise<td_api::object_ptr<td_api::chatPhotos>> &&promise);

  void reload_user_profile_photo(UserId user_id, int64 photo_id, Promise<Unit> &&promise);

  FileSourceId get_user_profile_photo_file_source_id(UserId user_id, int64 photo_id);

  void on_get_user_photos(UserId user_id, int32 offset, int32 limit, int32 total_count,
                          vector<telegram_api::object_ptr<telegram_api::Photo>> photos);

  void register_message_users(MessageFullId message_full_id, vector<UserId> user_ids);

  void unregister_message_users(MessageFullId message_full_id, vector<UserId> user_ids);

  void can_send_message_to_user(UserId user_id, bool force,
                                Promise<td_api::object_ptr<td_api::CanSendMessageToUserResult>> &&promise);

  void on_get_is_premium_required_to_contact_users(
      vector<UserId> &&user_ids, vector<telegram_api::object_ptr<telegram_api::RequirementToContact>> &&requirements,
      Promise<Unit> &&promise);

  void allow_send_message_to_user(UserId user_id);

  void share_phone_number(UserId user_id, Promise<Unit> &&promise);

  void reload_contacts(bool force);

  void on_get_contacts(telegram_api::object_ptr<telegram_api::contacts_Contacts> &&new_contacts);

  void on_get_contacts_failed(Status error);

  void on_get_contacts_statuses(vector<telegram_api::object_ptr<telegram_api::contactStatus>> &&statuses);

  void add_contact(Contact contact, bool share_phone_number, Promise<Unit> &&promise);

  std::pair<vector<UserId>, vector<int32>> import_contacts(const vector<Contact> &contacts, int64 &random_id,
                                                           Promise<Unit> &&promise);

  void on_imported_contacts(int64 random_id,
                            Result<telegram_api::object_ptr<telegram_api::contacts_importedContacts>> result);

  void remove_contacts(const vector<UserId> &user_ids, Promise<Unit> &&promise);

  void remove_contacts_by_phone_number(vector<string> user_phone_numbers, vector<UserId> user_ids,
                                       Promise<Unit> &&promise);

  void on_deleted_contacts(const vector<UserId> &deleted_contact_user_ids);

  void get_imported_contact_count(Promise<int32> &&promise);

  std::pair<vector<UserId>, vector<int32>> change_imported_contacts(vector<Contact> &contacts, int64 &random_id,
                                                                    Promise<Unit> &&promise);

  void clear_imported_contacts(Promise<Unit> &&promise);

  void on_update_contacts_reset();

  std::pair<int32, vector<UserId>> search_contacts(const string &query, int32 limit, Promise<Unit> &&promise);

  void reload_contact_birthdates(bool force);

  void on_get_contact_birthdates(telegram_api::object_ptr<telegram_api::contacts_contactBirthdays> &&birthdays);

  void hide_contact_birthdays(Promise<Unit> &&promise);

  vector<UserId> get_close_friends(Promise<Unit> &&promise);

  void set_close_friends(vector<UserId> user_ids, Promise<Unit> &&promise);

  void on_set_close_friends(const vector<UserId> &user_ids, Promise<Unit> &&promise);

  UserId search_user_by_phone_number(string phone_number, bool only_local, Promise<Unit> &&promise);

  void on_resolved_phone_number(const string &phone_number, UserId user_id);

  void load_user_full(UserId user_id, bool force, Promise<Unit> &&promise, const char *source);

  void reload_user_full(UserId user_id, Promise<Unit> &&promise, const char *source);

  void on_get_user_full(telegram_api::object_ptr<telegram_api::userFull> &&user);

  FileSourceId get_user_full_file_source_id(UserId user_id);

  void get_web_app_placeholder(UserId user_id, Promise<td_api::object_ptr<td_api::outline>> &&promise);

  bool have_secret_chat(SecretChatId secret_chat_id) const;

  bool have_secret_chat_force(SecretChatId secret_chat_id, const char *source);

  bool get_secret_chat(SecretChatId secret_chat_id, bool force, Promise<Unit> &&promise);

  void create_new_secret_chat(UserId user_id, Promise<td_api::object_ptr<td_api::chat>> &&promise);

  int64 get_user_id_object(UserId user_id, const char *source) const;

  void get_user_id_object_async(UserId user_id, Promise<int64> &&promise);

  td_api::object_ptr<td_api::user> get_user_object(UserId user_id) const;

  vector<int64> get_user_ids_object(const vector<UserId> &user_ids, const char *source) const;

  td_api::object_ptr<td_api::users> get_users_object(int32 total_count, const vector<UserId> &user_ids) const;

  td_api::object_ptr<td_api::userFullInfo> get_user_full_info_object(UserId user_id) const;

  int32 get_secret_chat_id_object(SecretChatId secret_chat_id, const char *source) const;

  td_api::object_ptr<td_api::secretChat> get_secret_chat_object(SecretChatId secret_chat_id);

  void get_current_state(vector<td_api::object_ptr<td_api::Update>> &updates) const;

 private:
  struct User {
    string first_name;
    string last_name;
    Usernames usernames;
    string phone_number;
    int64 access_hash = -1;
    unique_ptr<EmojiStatus> emoji_status;
    unique_ptr<EmojiStatus> last_sent_emoji_status;

    ProfilePhoto photo;

    vector<RestrictionReason> restriction_reasons;
    string inline_query_placeholder;
    int32 bot_active_users = 0;
    int32 bot_info_version = -1;

    CustomEmojiId bot_verification_icon;

    AccentColorId accent_color_id;
    CustomEmojiId background_custom_emoji_id;
    AccentColorId profile_accent_color_id;
    CustomEmojiId profile_background_custom_emoji_id;

    int32 was_online = 0;
    int32 local_was_online = 0;

    double max_active_story_id_next_reload_time = 0.0;
    StoryId max_active_story_id;
    StoryId max_read_story_id;

    int64 paid_message_star_count = 0;

    string language_code;

    FlatHashSet<int64> photo_ids;

    static constexpr uint32 CACHE_VERSION = 4;
    uint32 cache_version = 0;

    bool is_min_access_hash = true;
    bool is_received = false;
    bool is_verified = false;
    bool is_premium = false;
    bool is_support = false;
    bool is_deleted = true;
    bool is_bot = true;
    bool can_join_groups = true;
    bool can_read_all_group_messages = true;
    bool can_be_edited_bot = false;
    bool has_main_app = false;
    bool is_inline_bot = false;
    bool is_business_bot = false;
    bool need_location_bot = false;
    bool is_scam = false;
    bool is_fake = false;
    bool is_contact = false;
    bool is_mutual_contact = false;
    bool is_close_friend = false;
    bool need_apply_min_photo = false;
    bool can_be_added_to_attach_menu = false;
    bool attach_menu_enabled = false;
    bool stories_hidden = false;
    bool contact_require_premium = false;

    bool is_photo_inited = false;

    bool is_repaired = false;  // whether cached value is rechecked

    bool is_name_changed = true;
    bool is_username_changed = true;
    bool is_photo_changed = true;
    bool is_accent_color_changed = true;
    bool is_phone_number_changed = true;
    bool is_emoji_status_changed = true;
    bool is_is_contact_changed = true;
    bool is_is_mutual_contact_changed = true;
    bool is_is_deleted_changed = true;
    bool is_is_premium_changed = true;
    bool is_stories_hidden_changed = true;
    bool is_full_info_changed = false;
    bool is_being_updated = false;
    bool is_changed = true;             // have new changes that need to be sent to the client and database
    bool need_save_to_database = true;  // have new changes that need only to be saved to the database
    bool is_status_changed = true;
    bool is_online_status_changed = true;  // whether online/offline has changed
    bool is_update_user_sent = false;

    bool is_saved = false;         // is current user version being saved/is saved to the database
    bool is_being_saved = false;   // is current user being saved to the database
    bool is_status_saved = false;  // is current user status being saved/is saved to the database

    bool is_received_from_server = false;  // true, if the user was received from the server and not the database

    uint64 log_event_id = 0;

    template <class StorerT>
    void store(StorerT &storer) const;

    template <class ParserT>
    void parse(ParserT &parser);
  };

  struct BotInfo {
    string description;
    Photo description_photo;
    FileId description_animation_file_id;

    unique_ptr<BotMenuButton> menu_button;
    vector<BotCommand> commands;
    string privacy_policy_url;
    AdministratorRights group_administrator_rights;
    AdministratorRights broadcast_administrator_rights;
    ReferralProgramInfo referral_program_info;
    unique_ptr<BotVerifierSettings> verifier_settings;

    string placeholder_path;
    int32 background_color = -1;
    int32 background_dark_color = -1;
    int32 header_color = -1;
    int32 header_dark_color = -1;
  };

  // do not forget to update drop_user_full and on_get_user_full
  struct UserFull {
    Photo photo;
    Photo fallback_photo;
    Photo personal_photo;

    string about;
    string private_forward_name;
    vector<FileId> registered_file_ids;
    FileSourceId file_source_id;

    int32 gift_count = 0;
    int32 common_chat_count = 0;
    Birthdate birthdate;
    StarGiftSettings gift_settings;

    ChannelId personal_channel_id;

    unique_ptr<BotInfo> bot_info;
    unique_ptr<BusinessInfo> business_info;
    unique_ptr<BotVerification> bot_verification;

    int64 charge_paid_message_stars = 0;
    int64 send_paid_message_stars = 0;

    bool is_blocked = false;
    bool is_blocked_for_stories = false;
    bool can_be_called = false;
    bool supports_video_calls = false;
    bool has_private_calls = false;
    bool can_pin_messages = true;
    bool need_phone_number_privacy_exception = false;
    bool wallpaper_overridden = false;
    bool voice_messages_forbidden = false;
    bool has_pinned_stories = false;
    bool read_dates_private = false;
    bool contact_require_premium = false;
    bool sponsored_enabled = false;
    bool has_preview_medias = false;
    bool can_view_revenue = false;
    bool can_manage_emoji_status = false;

    bool is_common_chat_count_changed = true;
    bool is_being_updated = false;
    bool is_changed = true;             // have new changes that need to be sent to the client and database
    bool need_send_update = true;       // have new changes that need only to be sent to the client
    bool need_save_to_database = true;  // have new changes that need only to be saved to the database
    bool is_update_user_full_sent = false;

    double expires_at = 0.0;

    bool is_expired() const {
      return expires_at < Time::now();
    }

    BotInfo *add_bot_info() {
      if (bot_info == nullptr) {
        bot_info = make_unique<BotInfo>();
      }
      return bot_info.get();
    }

    template <class StorerT>
    void store(StorerT &storer) const;

    template <class ParserT>
    void parse(ParserT &parser);
  };

  struct SecretChat {
    int64 access_hash = 0;
    UserId user_id;
    SecretChatState state = SecretChatState::Unknown;
    string key_hash;
    int32 ttl = 0;
    int32 date = 0;
    int32 layer = 0;
    FolderId initial_folder_id;

    bool is_outbound = false;

    bool is_ttl_changed = true;
    bool is_state_changed = true;
    bool is_being_updated = false;
    bool is_changed = true;             // have new changes that need to be sent to the client and database
    bool need_save_to_database = true;  // have new changes that need only to be saved to the database

    bool is_saved = false;        // is current secret chat version being saved/is saved to the database
    bool is_being_saved = false;  // is current secret chat being saved to the database

    uint64 log_event_id = 0;

    template <class StorerT>
    void store(StorerT &storer) const;

    template <class ParserT>
    void parse(ParserT &parser);
  };

  struct PendingGetPhotoRequest {
    int32 offset = 0;
    int32 limit = 0;
    int32 retry_count = 0;
    Promise<td_api::object_ptr<td_api::chatPhotos>> promise;
  };

  struct UserPhotos {
    vector<Photo> photos;
    int32 count = -1;
    int32 offset = -1;

    vector<PendingGetPhotoRequest> pending_requests;
  };

  class UserLogEvent;
  class SecretChatLogEvent;

  static constexpr int32 MAX_GET_PROFILE_PHOTOS = 100;  // server-side limit
  static constexpr size_t MAX_NAME_LENGTH = 64;         // server-side limit for first/last name

  static constexpr int32 MAX_ACTIVE_STORY_ID_RELOAD_TIME = 3600;  // some reasonable limit

  static constexpr int32 USER_FULL_EXPIRE_TIME = 60;

  static constexpr int32 ACCOUNT_UPDATE_FIRST_NAME = 1 << 0;
  static constexpr int32 ACCOUNT_UPDATE_LAST_NAME = 1 << 1;
  static constexpr int32 ACCOUNT_UPDATE_ABOUT = 1 << 2;

  void tear_down() final;

  static void on_user_online_timeout_callback(void *user_manager_ptr, int64 user_id_long);

  void on_user_online_timeout(UserId user_id);

  static void on_user_emoji_status_timeout_callback(void *user_manager_ptr, int64 user_id_long);

  void on_user_emoji_status_timeout(UserId user_id);

  void set_my_id(UserId my_id);

  const User *get_user(UserId user_id) const;

  User *get_user(UserId user_id);

  User *add_user(UserId user_id);

  void save_user(User *u, UserId user_id, bool from_binlog);

  static string get_user_database_key(UserId user_id);

  static string get_user_database_value(const User *u);

  void save_user_to_database(User *u, UserId user_id);

  void save_user_to_database_impl(User *u, UserId user_id, string value);

  void on_save_user_to_database(UserId user_id, bool success);

  void load_user_from_database(User *u, UserId user_id, Promise<Unit> promise);

  void load_user_from_database_impl(UserId user_id, Promise<Unit> promise);

  void on_load_user_from_database(UserId user_id, string value, bool force);

  User *get_user_force(UserId user_id, const char *source);

  User *get_user_force_impl(UserId user_id, const char *source);

  bool is_user_contact(const User *u, UserId user_id, bool is_mutual) const;

  static bool is_user_premium(const User *u);

  static bool is_user_deleted(const User *u);

  static bool is_user_support(const User *u);

  static bool is_user_bot(const User *u);

  int32 get_user_was_online(const User *u, UserId user_id, int32 unix_time) const;

  void on_update_user_name(User *u, UserId user_id, string &&first_name, string &&last_name);

  void on_update_user_usernames(User *u, UserId user_id, Usernames &&usernames);

  void on_update_user_phone_number(User *u, UserId user_id, string &&phone_number);

  void on_update_user_photo(User *u, UserId user_id, telegram_api::object_ptr<telegram_api::UserProfilePhoto> &&photo,
                            const char *source);

  void do_update_user_photo(User *u, UserId user_id, telegram_api::object_ptr<telegram_api::UserProfilePhoto> &&photo,
                            const char *source);

  void do_update_user_photo(User *u, UserId user_id, ProfilePhoto &&new_photo, bool invalidate_photo_cache,
                            const char *source);

  void register_user_photo(User *u, UserId user_id, const Photo &photo);

  void on_update_user_accent_color_id(User *u, UserId user_id, AccentColorId accent_color_id);

  void on_update_user_background_custom_emoji_id(User *u, UserId user_id, CustomEmojiId background_custom_emoji_id);

  void on_update_user_profile_accent_color_id(User *u, UserId user_id, AccentColorId accent_color_id);

  void on_update_user_profile_background_custom_emoji_id(User *u, UserId user_id,
                                                         CustomEmojiId background_custom_emoji_id);

  void on_update_user_emoji_status(User *u, UserId user_id, unique_ptr<EmojiStatus> emoji_status);

  void on_update_user_story_ids_impl(User *u, UserId user_id, StoryId max_active_story_id, StoryId max_read_story_id);

  void on_update_user_max_read_story_id(User *u, UserId user_id, StoryId max_read_story_id);

  void on_update_user_stories_hidden(User *u, UserId user_id, bool stories_hidden);

  void on_update_user_bot_verification_icon(User *u, UserId user_id, CustomEmojiId bot_verification_icon);

  void on_update_user_is_contact(User *u, UserId user_id, bool is_contact, bool is_mutual_contact,
                                 bool is_close_friend);

  void on_update_user_online(User *u, UserId user_id, telegram_api::object_ptr<telegram_api::UserStatus> &&status);

  void on_update_user_local_was_online(User *u, UserId user_id, int32 local_was_online);

  static void on_update_user_full_is_blocked(UserFull *user_full, UserId user_id, bool is_blocked,
                                             bool is_blocked_for_stories);

  static void on_update_user_full_gift_count(UserFull *user_full, UserId user_id, int32 gift_count);

  static void on_update_user_full_common_chat_count(UserFull *user_full, UserId user_id, int32 common_chat_count);

  static void on_update_user_full_location(UserFull *user_full, UserId user_id, DialogLocation &&location);

  static void on_update_user_full_work_hours(UserFull *user_full, UserId user_id, BusinessWorkHours &&work_hours);

  void on_update_user_full_away_message(UserFull *user_full, UserId user_id, BusinessAwayMessage &&away_message) const;

  void on_update_user_full_greeting_message(UserFull *user_full, UserId user_id,
                                            BusinessGreetingMessage &&greeting_message) const;

  static void on_update_user_full_intro(UserFull *user_full, UserId user_id, BusinessIntro &&intro);

  static void on_update_user_full_commands(UserFull *user_full, UserId user_id,
                                           vector<telegram_api::object_ptr<telegram_api::botCommand>> &&bot_commands);

  void on_update_user_full_referral_program_info(UserFull *user_full, UserId user_id,
                                                 ReferralProgramInfo &&referral_program_info);

  void on_update_user_full_verifier_settings(UserFull *user_full, UserId user_id,
                                             unique_ptr<BotVerifierSettings> &&verifier_settings);

  void on_update_user_full_need_phone_number_privacy_exception(UserFull *user_full, UserId user_id,
                                                               bool need_phone_number_privacy_exception) const;

  void on_update_user_full_charge_paid_message_stars(UserFull *user_full, UserId user_id,
                                                     int64 charge_paid_message_stars) const;

  void on_update_user_full_send_paid_message_stars(UserFull *user_full, UserId user_id,
                                                   int64 send_paid_message_stars) const;

  void on_update_user_full_wallpaper_overridden(UserFull *user_full, UserId user_id, bool wallpaper_overridden) const;

  static void on_update_user_full_menu_button(UserFull *user_full, UserId user_id,
                                              telegram_api::object_ptr<telegram_api::BotMenuButton> &&bot_menu_button);

  static void on_update_user_full_has_preview_medias(UserFull *user_full, UserId user_id, bool has_preview_medias);

  static void on_update_user_full_can_manage_emoji_status(UserFull *user_full, UserId user_id,
                                                          bool can_manage_emoji_status);

  bool have_input_peer_user(const User *u, UserId user_id, AccessRights access_rights) const;

  static bool have_input_encrypted_peer(const SecretChat *secret_chat, AccessRights access_rights);

  bool need_poll_user_active_stories(const User *u, UserId user_id) const;

  static string get_user_search_text(const User *u);

  void set_profile_photo_impl(UserId user_id, const td_api::object_ptr<td_api::InputChatPhoto> &input_photo,
                              bool is_fallback, bool only_suggest, Promise<Unit> &&promise);

  void upload_profile_photo(UserId user_id, FileUploadId file_upload_id, bool is_fallback, bool only_suggest,
                            bool is_animation, double main_frame_timestamp, Promise<Unit> &&promise,
                            int reupload_count = 0, vector<int> bad_parts = {});

  void on_upload_profile_photo(FileUploadId file_upload_id,
                               telegram_api::object_ptr<telegram_api::InputFile> input_file);

  void on_upload_profile_photo_error(FileUploadId file_upload_id, Status status);

  void add_set_profile_photo_to_cache(UserId user_id, Photo &&photo, bool is_fallback);

  bool delete_my_profile_photo_from_cache(int64 profile_photo_id);

  void toggle_username_is_active_impl(string &&username, bool is_active, Promise<Unit> &&promise);

  void reorder_usernames_impl(vector<string> &&usernames, Promise<Unit> &&promise);

  void on_set_birthdate(Birthdate birthdate, Promise<Unit> &&promise);

  void on_set_personal_channel(ChannelId channel_id, Promise<Unit> &&promise);

  void on_set_emoji_status(unique_ptr<EmojiStatus> emoji_status, Promise<Unit> &&promise);

  void on_toggle_sponsored_messages(bool sponsored_enabled, Promise<Unit> &&promise);

  void on_get_support_user(UserId user_id, Promise<td_api::object_ptr<td_api::user>> &&promise);

  void send_get_user_photos_query(UserId user_id, const UserPhotos *user_photos);

  void on_get_user_profile_photos(UserId user_id, Result<Unit> &&result);

  UserPhotos *add_user_photos(UserId user_id);

  void apply_pending_user_photo(User *u, UserId user_id, const char *source);

  void load_contacts(Promise<Unit> &&promise);

  int64 get_contacts_hash();

  void save_next_contacts_sync_date();

  void save_contacts_to_database();

  void on_load_contacts_from_database(string value);

  void on_get_contacts_finished(size_t expected_contact_count);

  void do_import_contacts(vector<Contact> contacts, int64 random_id, Promise<Unit> &&promise);

  void on_import_contacts_finished(int64 random_id, vector<UserId> imported_contact_user_ids,
                                   vector<int32> unimported_contact_invites);

  void load_imported_contacts(Promise<Unit> &&promise);

  void on_load_imported_contacts_from_database(string value);

  void on_load_imported_contacts_finished();

  void on_clear_imported_contacts(vector<Contact> &&contacts, vector<size_t> contacts_unique_id,
                                  std::pair<vector<size_t>, vector<Contact>> &&to_add, Promise<Unit> &&promise);

  void update_contacts_hints(const User *u, UserId user_id, bool from_database);

  const UserFull *get_user_full(UserId user_id) const;

  UserFull *get_user_full(UserId user_id);

  UserFull *add_user_full(UserId user_id);

  UserFull *get_user_full_force(UserId user_id, const char *source);

  void send_get_user_full_query(UserId user_id, telegram_api::object_ptr<telegram_api::InputUser> &&input_user,
                                Promise<Unit> &&promise, const char *source);

  static void save_user_full(const UserFull *user_full, UserId user_id);

  static string get_user_full_database_key(UserId user_id);

  static string get_user_full_database_value(const UserFull *user_full);

  void on_load_user_full_from_database(UserId user_id, string value);

  int64 get_user_full_profile_photo_id(const UserFull *user_full);

  void drop_user_full_photos(UserFull *user_full, UserId user_id, int64 expected_photo_id, const char *source);

  void drop_user_photos(UserId user_id, bool is_empty, const char *source);

  void drop_user_full(UserId user_id);

  const SecretChat *get_secret_chat(SecretChatId secret_chat_id) const;

  SecretChat *get_secret_chat(SecretChatId secret_chat_id);

  SecretChat *add_secret_chat(SecretChatId secret_chat_id);

  SecretChat *get_secret_chat_force(SecretChatId secret_chat_id, const char *source);

  void save_secret_chat(SecretChat *c, SecretChatId secret_chat_id, bool from_binlog);

  static string get_secret_chat_database_key(SecretChatId secret_chat_id);

  static string get_secret_chat_database_value(const SecretChat *c);

  void save_secret_chat_to_database(SecretChat *c, SecretChatId secret_chat_id);

  void save_secret_chat_to_database_impl(SecretChat *c, SecretChatId secret_chat_id, string value);

  void on_save_secret_chat_to_database(SecretChatId secret_chat_id, bool success);

  void load_secret_chat_from_database(SecretChat *c, SecretChatId secret_chat_id, Promise<Unit> promise);

  void load_secret_chat_from_database_impl(SecretChatId secret_chat_id, Promise<Unit> promise);

  void on_load_secret_chat_from_database(SecretChatId secret_chat_id, string value, bool force);

  void on_create_new_secret_chat(SecretChatId secret_chat_id, Promise<td_api::object_ptr<td_api::chat>> &&promise);

  void update_user(User *u, UserId user_id, bool from_binlog = false, bool from_database = false);

  void update_secret_chat(SecretChat *c, SecretChatId secret_chat_id, bool from_binlog = false,
                          bool from_database = false);

  void update_user_full(UserFull *user_full, UserId user_id, const char *source, bool from_database = false);

  td_api::object_ptr<td_api::UserStatus> get_user_status_object(UserId user_id, const User *u, int32 unix_time) const;

  static bool get_user_has_unread_stories(const User *u);

  td_api::object_ptr<td_api::updateUser> get_update_user_object(UserId user_id, const User *u) const;

  td_api::object_ptr<td_api::updateUser> get_update_unknown_user_object(UserId user_id) const;

  td_api::object_ptr<td_api::user> get_user_object(UserId user_id, const User *u) const;

  td_api::object_ptr<td_api::userFullInfo> get_user_full_info_object(UserId user_id, const UserFull *user_full) const;

  td_api::object_ptr<td_api::updateContactCloseBirthdays> get_update_contact_close_birthdays() const;

  static td_api::object_ptr<td_api::SecretChatState> get_secret_chat_state_object(SecretChatState state);

  td_api::object_ptr<td_api::updateSecretChat> get_update_secret_chat_object(SecretChatId secret_chat_id,
                                                                             const SecretChat *secret_chat);

  static td_api::object_ptr<td_api::updateSecretChat> get_update_unknown_secret_chat_object(
      SecretChatId secret_chat_id);

  td_api::object_ptr<td_api::secretChat> get_secret_chat_object(SecretChatId secret_chat_id,
                                                                const SecretChat *secret_chat);

  td_api::object_ptr<td_api::secretChat> get_secret_chat_object_const(SecretChatId secret_chat_id,
                                                                      const SecretChat *secret_chat) const;

  td_api::object_ptr<td_api::updateFreezeState> get_update_freeze_state_object() const;

  Td *td_;
  ActorShared<> parent_;
  UserId my_id_;
  UserId support_user_id_;
  int32 my_was_online_local_ = 0;

  WaitFreeHashMap<UserId, unique_ptr<User>, UserIdHash> users_;
  WaitFreeHashMap<UserId, unique_ptr<UserFull>, UserIdHash> users_full_;
  WaitFreeHashMap<UserId, unique_ptr<UserPhotos>, UserIdHash> user_photos_;
  mutable FlatHashSet<UserId, UserIdHash> unknown_users_;
  WaitFreeHashMap<UserId, telegram_api::object_ptr<telegram_api::UserProfilePhoto>, UserIdHash> pending_user_photos_;
  struct UserIdPhotoIdHash {
    uint32 operator()(const std::pair<UserId, int64> &pair) const {
      return combine_hashes(UserIdHash()(pair.first), Hash<int64>()(pair.second));
    }
  };
  WaitFreeHashMap<std::pair<UserId, int64>, FileSourceId, UserIdPhotoIdHash> user_profile_photo_file_source_ids_;
  FlatHashMap<int64, FileId> my_photo_file_id_;
  WaitFreeHashMap<UserId, FileSourceId, UserIdHash> user_full_file_source_ids_;

  WaitFreeHashMap<SecretChatId, unique_ptr<SecretChat>, SecretChatIdHash> secret_chats_;
  mutable FlatHashSet<SecretChatId, SecretChatIdHash> unknown_secret_chats_;

  FlatHashMap<UserId, vector<SecretChatId>, UserIdHash> secret_chats_with_user_;

  FlatHashMap<UserId, vector<Promise<Unit>>, UserIdHash> load_user_from_database_queries_;
  FlatHashSet<UserId, UserIdHash> loaded_from_database_users_;
  FlatHashSet<UserId, UserIdHash> unavailable_user_fulls_;

  FlatHashMap<SecretChatId, vector<Promise<Unit>>, SecretChatIdHash> load_secret_chat_from_database_queries_;
  FlatHashSet<SecretChatId, SecretChatIdHash> loaded_from_database_secret_chats_;

  QueryMerger get_user_queries_{"GetUserMerger", 3, 50};

  QueryMerger get_is_premium_required_to_contact_queries_{"GetIsPremiumRequiredToContactMerger", 3, 100};

  QueryCombiner get_user_full_queries_{"GetUserFullCombiner", 2.0};
  class UploadProfilePhotoCallback;
  std::shared_ptr<UploadProfilePhotoCallback> upload_profile_photo_callback_;

  struct UploadedProfilePhoto {
    UserId user_id;
    bool is_fallback;
    bool only_suggest;
    double main_frame_timestamp;
    bool is_animation;
    int reupload_count;
    Promise<Unit> promise;

    UploadedProfilePhoto(UserId user_id, bool is_fallback, bool only_suggest, double main_frame_timestamp,
                         bool is_animation, int32 reupload_count, Promise<Unit> promise)
        : user_id(user_id)
        , is_fallback(is_fallback)
        , only_suggest(only_suggest)
        , main_frame_timestamp(main_frame_timestamp)
        , is_animation(is_animation)
        , reupload_count(reupload_count)
        , promise(std::move(promise)) {
    }
  };
  FlatHashMap<FileUploadId, UploadedProfilePhoto, FileUploadIdHash> being_uploaded_profile_photos_;

  struct ImportContactsTask {
    Promise<Unit> promise_;
    vector<Contact> input_contacts_;
    vector<UserId> imported_user_ids_;
    vector<int32> unimported_contact_invites_;
  };
  FlatHashMap<int64, unique_ptr<ImportContactsTask>> import_contact_tasks_;

  FlatHashMap<int64, std::pair<vector<UserId>, vector<int32>>> imported_contacts_;

  FlatHashMap<string, UserId> resolved_phone_numbers_;

  FlatHashMap<UserId, FlatHashSet<MessageFullId, MessageFullIdHash>, UserIdHash> user_messages_;

  bool are_contacts_loaded_ = false;
  int32 next_contacts_sync_date_ = 0;
  Hints contacts_hints_;  // search contacts by first name, last name and usernames
  vector<Promise<Unit>> load_contacts_queries_;
  MultiPromiseActor load_contact_users_multipromise_{"LoadContactUsersMultiPromiseActor"};
  int32 saved_contact_count_ = -1;

  int32 was_online_local_ = 0;
  int32 was_online_remote_ = 0;

  bool are_imported_contacts_loaded_ = false;
  vector<Promise<Unit>> load_imported_contacts_queries_;
  MultiPromiseActor load_imported_contact_users_multipromise_{"LoadImportedContactUsersMultiPromiseActor"};
  vector<Contact> all_imported_contacts_;
  bool are_imported_contacts_changing_ = false;
  bool need_clear_imported_contacts_ = false;

  FlatHashMap<UserId, int64, UserIdHash> user_full_contact_price_;  // -1 - premium required

  WaitFreeHashSet<UserId, UserIdHash> restricted_user_ids_;

  int32 freeze_since_date_ = 0;
  int32 freeze_until_date_ = 0;
  string freeze_appeal_url_;

  struct ContactBirthdates {
    vector<std::pair<UserId, Birthdate>> users_;
    double next_sync_time_ = 0.0;
    bool is_being_synced_ = false;
    bool need_drop_ = false;
  };
  ContactBirthdates contact_birthdates_;

  vector<Contact> next_all_imported_contacts_;
  vector<size_t> imported_contacts_unique_id_;
  vector<size_t> imported_contacts_pos_;

  vector<UserId> imported_contact_user_ids_;  // result of change_imported_contacts
  vector<int32> unimported_contact_invites_;  // result of change_imported_contacts

  MultiTimeout user_online_timeout_{"UserOnlineTimeout"};
  MultiTimeout user_emoji_status_timeout_{"UserEmojiStatusTimeout"};
};

}  // namespace td
