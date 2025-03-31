//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/ChannelType.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"
#include "td/telegram/Version.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/tl_helpers.h"

namespace td {

class Td;

class AdministratorRights {
  static constexpr uint64 CAN_CHANGE_INFO_AND_SETTINGS = 1 << 0;
  static constexpr uint64 CAN_POST_MESSAGES = 1 << 1;
  static constexpr uint64 CAN_EDIT_MESSAGES = 1 << 2;
  static constexpr uint64 CAN_DELETE_MESSAGES = 1 << 3;
  static constexpr uint64 CAN_INVITE_USERS = 1 << 4;
  // static constexpr uint64 CAN_EXPORT_DIALOG_INVITE_LINK = 1 << 5;
  static constexpr uint64 CAN_RESTRICT_MEMBERS = 1 << 6;
  static constexpr uint64 CAN_PIN_MESSAGES = 1 << 7;
  static constexpr uint64 CAN_PROMOTE_MEMBERS = 1 << 8;
  static constexpr uint64 CAN_MANAGE_CALLS = 1 << 9;
  static constexpr uint64 CAN_MANAGE_DIALOG = 1 << 10;
  static constexpr uint64 CAN_MANAGE_TOPICS = 1 << 11;
  static constexpr uint64 LEGACY_CAN_SEND_MEDIA = 1 << 17;
  static constexpr uint64 CAN_POST_STORIES = static_cast<uint64>(1) << 48;
  static constexpr uint64 CAN_EDIT_STORIES = static_cast<uint64>(1) << 49;
  static constexpr uint64 CAN_DELETE_STORIES = static_cast<uint64>(1) << 50;
  static constexpr uint64 IS_ANONYMOUS = 1 << 13;

  static constexpr uint64 ALL_ADMINISTRATOR_RIGHTS =
      CAN_CHANGE_INFO_AND_SETTINGS | CAN_POST_MESSAGES | CAN_EDIT_MESSAGES | CAN_DELETE_MESSAGES | CAN_INVITE_USERS |
      CAN_RESTRICT_MEMBERS | CAN_PIN_MESSAGES | CAN_MANAGE_TOPICS | CAN_PROMOTE_MEMBERS | CAN_MANAGE_CALLS |
      CAN_MANAGE_DIALOG | CAN_POST_STORIES | CAN_EDIT_STORIES | CAN_DELETE_STORIES;

  uint64 flags_;

  friend class DialogParticipantStatus;

  explicit AdministratorRights(uint64 flags) : flags_(flags & (ALL_ADMINISTRATOR_RIGHTS | IS_ANONYMOUS)) {
  }

 public:
  AdministratorRights() : flags_(0) {
  }

  AdministratorRights(const tl_object_ptr<telegram_api::chatAdminRights> &admin_rights, ChannelType channel_type);

  AdministratorRights(const td_api::object_ptr<td_api::chatAdministratorRights> &administrator_rights,
                      ChannelType channel_type);

  AdministratorRights(bool is_anonymous, bool can_manage_dialog, bool can_change_info, bool can_post_messages,
                      bool can_edit_messages, bool can_delete_messages, bool can_invite_users,
                      bool can_restrict_members, bool can_pin_messages, bool can_manage_topics,
                      bool can_promote_members, bool can_manage_calls, bool can_post_stories, bool can_edit_stories,
                      bool can_delete_stories, ChannelType channel_type);

  telegram_api::object_ptr<telegram_api::chatAdminRights> get_chat_admin_rights() const;

  td_api::object_ptr<td_api::chatAdministratorRights> get_chat_administrator_rights_object() const;

  bool can_manage_dialog() const {
    return (flags_ & CAN_MANAGE_DIALOG) != 0;
  }

  bool can_change_info_and_settings() const {
    return (flags_ & CAN_CHANGE_INFO_AND_SETTINGS) != 0;
  }

  bool can_post_messages() const {
    return (flags_ & CAN_POST_MESSAGES) != 0;
  }

  bool can_edit_messages() const {
    return (flags_ & CAN_EDIT_MESSAGES) != 0;
  }

  bool can_delete_messages() const {
    return (flags_ & CAN_DELETE_MESSAGES) != 0;
  }

  bool can_invite_users() const {
    return (flags_ & CAN_INVITE_USERS) != 0;
  }

  bool can_restrict_members() const {
    return (flags_ & CAN_RESTRICT_MEMBERS) != 0;
  }

  bool can_pin_messages() const {
    return (flags_ & CAN_PIN_MESSAGES) != 0;
  }

  bool can_manage_topics() const {
    return (flags_ & CAN_MANAGE_TOPICS) != 0;
  }

  bool can_promote_members() const {
    return (flags_ & CAN_PROMOTE_MEMBERS) != 0;
  }

  bool can_manage_calls() const {
    return (flags_ & CAN_MANAGE_CALLS) != 0;
  }

  bool can_post_stories() const {
    return (flags_ & CAN_POST_STORIES) != 0;
  }

  bool can_edit_stories() const {
    return (flags_ & CAN_EDIT_STORIES) != 0;
  }

  bool can_delete_stories() const {
    return (flags_ & CAN_DELETE_STORIES) != 0;
  }

  bool is_anonymous() const {
    return (flags_ & IS_ANONYMOUS) != 0;
  }

  template <class StorerT>
  void store(StorerT &storer) const {
    td::store(flags_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    if (parser.version() >= static_cast<int32>(Version::MakeParticipantFlags64Bit)) {
      td::parse(flags_, parser);
    } else {
      uint32 legacy_flags;
      td::parse(legacy_flags, parser);
      flags_ = legacy_flags;
    }
  }

  friend bool operator==(const AdministratorRights &lhs, const AdministratorRights &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const AdministratorRights &status);
};

bool operator==(const AdministratorRights &lhs, const AdministratorRights &rhs);

bool operator!=(const AdministratorRights &lhs, const AdministratorRights &rhs);

StringBuilder &operator<<(StringBuilder &string_builder, const AdministratorRights &status);

class RestrictedRights {
  static constexpr uint64 CAN_SEND_MESSAGES = 1 << 16;
  static constexpr uint64 LEGACY_CAN_SEND_MEDIA = 1 << 17;
  static constexpr uint64 CAN_SEND_AUDIOS = static_cast<uint64>(1) << 32;
  static constexpr uint64 CAN_SEND_DOCUMENTS = static_cast<uint64>(1) << 33;
  static constexpr uint64 CAN_SEND_PHOTOS = static_cast<uint64>(1) << 34;
  static constexpr uint64 CAN_SEND_VIDEOS = static_cast<uint64>(1) << 35;
  static constexpr uint64 CAN_SEND_VIDEO_NOTES = static_cast<uint64>(1) << 36;
  static constexpr uint64 CAN_SEND_VOICE_NOTES = static_cast<uint64>(1) << 37;
  static constexpr uint64 CAN_SEND_STICKERS = 1 << 18;
  static constexpr uint64 CAN_SEND_ANIMATIONS = 1 << 19;
  static constexpr uint64 CAN_SEND_GAMES = 1 << 20;
  static constexpr uint64 CAN_USE_INLINE_BOTS = 1 << 21;
  static constexpr uint64 CAN_ADD_WEB_PAGE_PREVIEWS = 1 << 22;
  static constexpr uint64 CAN_SEND_POLLS = 1 << 23;
  static constexpr uint64 CAN_CHANGE_INFO_AND_SETTINGS = 1 << 24;
  static constexpr uint64 CAN_INVITE_USERS = 1 << 25;
  static constexpr uint64 CAN_PIN_MESSAGES = 1 << 26;
  static constexpr uint64 CAN_MANAGE_TOPICS = 1 << 12;

  static constexpr uint64 ALL_ADMIN_PERMISSION_RIGHTS =
      CAN_CHANGE_INFO_AND_SETTINGS | CAN_INVITE_USERS | CAN_PIN_MESSAGES | CAN_MANAGE_TOPICS;

  static constexpr uint64 ALL_RESTRICTED_RIGHTS =
      CAN_SEND_MESSAGES | CAN_SEND_STICKERS | CAN_SEND_ANIMATIONS | CAN_SEND_GAMES | CAN_USE_INLINE_BOTS |
      CAN_ADD_WEB_PAGE_PREVIEWS | CAN_SEND_POLLS | ALL_ADMIN_PERMISSION_RIGHTS | CAN_SEND_AUDIOS | CAN_SEND_DOCUMENTS |
      CAN_SEND_PHOTOS | CAN_SEND_VIDEOS | CAN_SEND_VIDEO_NOTES | CAN_SEND_VOICE_NOTES;

  uint64 flags_;

  friend class DialogParticipantStatus;

  explicit RestrictedRights(uint64 flags) : flags_(flags & ALL_RESTRICTED_RIGHTS) {
  }

 public:
  RestrictedRights(const tl_object_ptr<telegram_api::chatBannedRights> &rights, ChannelType channel_type);

  RestrictedRights(const td_api::object_ptr<td_api::chatPermissions> &rights, ChannelType channel_type);

  RestrictedRights(bool can_send_messages, bool can_send_audios, bool can_send_documents, bool can_send_photos,
                   bool can_send_videos, bool can_send_video_notes, bool can_send_voice_notes, bool can_send_stickers,
                   bool can_send_animations, bool can_send_games, bool can_use_inline_bots,
                   bool can_add_web_page_previews, bool can_send_polls, bool can_change_info_and_settings,
                   bool can_invite_users, bool can_pin_messages, bool can_manage_topics, ChannelType channel_type);

  td_api::object_ptr<td_api::chatPermissions> get_chat_permissions_object() const;

  tl_object_ptr<telegram_api::chatBannedRights> get_chat_banned_rights() const;

  bool can_change_info_and_settings() const {
    return (flags_ & CAN_CHANGE_INFO_AND_SETTINGS) != 0;
  }

  bool can_invite_users() const {
    return (flags_ & CAN_INVITE_USERS) != 0;
  }

  bool can_pin_messages() const {
    return (flags_ & CAN_PIN_MESSAGES) != 0;
  }

  bool can_manage_topics() const {
    return (flags_ & CAN_MANAGE_TOPICS) != 0;
  }

  bool can_send_messages() const {
    return (flags_ & CAN_SEND_MESSAGES) != 0;
  }

  bool can_send_audios() const {
    return (flags_ & CAN_SEND_AUDIOS) != 0;
  }

  bool can_send_documents() const {
    return (flags_ & CAN_SEND_DOCUMENTS) != 0;
  }

  bool can_send_photos() const {
    return (flags_ & CAN_SEND_PHOTOS) != 0;
  }

  bool can_send_videos() const {
    return (flags_ & CAN_SEND_VIDEOS) != 0;
  }

  bool can_send_video_notes() const {
    return (flags_ & CAN_SEND_VIDEO_NOTES) != 0;
  }

  bool can_send_voice_notes() const {
    return (flags_ & CAN_SEND_VOICE_NOTES) != 0;
  }

  bool can_send_stickers() const {
    return (flags_ & CAN_SEND_STICKERS) != 0;
  }

  bool can_send_animations() const {
    return (flags_ & CAN_SEND_ANIMATIONS) != 0;
  }

  bool can_send_games() const {
    return (flags_ & CAN_SEND_GAMES) != 0;
  }

  bool can_use_inline_bots() const {
    return (flags_ & CAN_USE_INLINE_BOTS) != 0;
  }

  bool can_add_web_page_previews() const {
    return (flags_ & CAN_ADD_WEB_PAGE_PREVIEWS) != 0;
  }

  bool can_send_polls() const {
    return (flags_ & CAN_SEND_POLLS) != 0;
  }

  template <class StorerT>
  void store(StorerT &storer) const {
    td::store(flags_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    if (parser.version() >= static_cast<int32>(Version::MakeParticipantFlags64Bit)) {
      td::parse(flags_, parser);
    } else {
      uint32 legacy_flags;
      td::parse(legacy_flags, parser);
      flags_ = legacy_flags;
    }
    if (flags_ & LEGACY_CAN_SEND_MEDIA) {
      flags_ |= CAN_SEND_AUDIOS | CAN_SEND_DOCUMENTS | CAN_SEND_PHOTOS | CAN_SEND_VIDEOS | CAN_SEND_VIDEO_NOTES |
                CAN_SEND_VOICE_NOTES;
    }
  }

  friend bool operator==(const RestrictedRights &lhs, const RestrictedRights &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const RestrictedRights &status);
};

bool operator==(const RestrictedRights &lhs, const RestrictedRights &rhs);

bool operator!=(const RestrictedRights &lhs, const RestrictedRights &rhs);

StringBuilder &operator<<(StringBuilder &string_builder, const RestrictedRights &status);

class DialogParticipantStatus {
  static constexpr uint64 HAS_RANK = 1 << 14;
  static constexpr uint64 CAN_BE_EDITED = 1 << 15;

  static constexpr uint64 IS_MEMBER = 1 << 27;

  // bits 28-30 reserved for Type
  static constexpr int TYPE_SHIFT = 28;
  static constexpr int TYPE_SIZE = 3;
  static constexpr uint64 HAS_UNTIL_DATE = 1u << 31;

  enum class Type : int32 { Creator, Administrator, Member, Restricted, Left, Banned };
  // all fields are logically const, but should be updated in update_restrictions()
  mutable Type type_;
  mutable int32 until_date_;  // member, restricted and banned only
  mutable uint64 flags_;
  string rank_;  // creator and administrator only

  static int32 fix_until_date(int32 date);

  DialogParticipantStatus(Type type, uint64 flags, int32 until_date, string rank);

  AdministratorRights get_administrator_rights() const {
    return AdministratorRights(flags_);
  }

  RestrictedRights get_restricted_rights() const {
    return RestrictedRights(flags_);
  }

 public:
  static DialogParticipantStatus Creator(bool is_member, bool is_anonymous, string &&rank);

  static DialogParticipantStatus Administrator(AdministratorRights administrator_rights, string &&rank,
                                               bool can_be_edited);

  static DialogParticipantStatus Member(int32 member_until_date);

  static DialogParticipantStatus Restricted(RestrictedRights restricted_rights, bool is_member,
                                            int32 restricted_until_date, ChannelType channel_type);

  static DialogParticipantStatus Left();

  static DialogParticipantStatus Banned(int32 banned_until_date);

  // legacy rights
  static DialogParticipantStatus GroupAdministrator(bool is_creator);

  // legacy rights
  static DialogParticipantStatus ChannelAdministrator(bool is_creator, bool is_megagroup);

  // forcely returns an administrator
  DialogParticipantStatus(bool can_be_edited, tl_object_ptr<telegram_api::chatAdminRights> &&admin_rights, string rank,
                          ChannelType channel_type);

  // forcely returns a restricted or banned
  DialogParticipantStatus(bool is_member, tl_object_ptr<telegram_api::chatBannedRights> &&banned_rights,
                          ChannelType channel_type);

  bool has_all_administrator_rights(AdministratorRights administrator_rights) const {
    auto flags = administrator_rights.flags_ &
                 (AdministratorRights::ALL_ADMINISTRATOR_RIGHTS | AdministratorRights::IS_ANONYMOUS);
    return (get_administrator_rights().flags_ & flags) == flags;
  }

  RestrictedRights get_effective_restricted_rights() const;

  DialogParticipantStatus apply_restrictions(RestrictedRights default_restrictions, bool is_booster, bool is_bot) const;

  tl_object_ptr<td_api::ChatMemberStatus> get_chat_member_status_object() const;

  tl_object_ptr<telegram_api::chatAdminRights> get_chat_admin_rights() const;

  tl_object_ptr<telegram_api::chatBannedRights> get_chat_banned_rights() const;

  // unrestricts user if restriction time expired. Should be called before all privileges checks
  void update_restrictions() const;

  bool can_manage_dialog() const {
    return get_administrator_rights().can_manage_dialog();
  }

  bool can_change_info_and_settings_as_administrator() const {
    return get_administrator_rights().can_change_info_and_settings();
  }

  bool can_change_info_and_settings() const {
    return get_administrator_rights().can_change_info_and_settings() ||
           get_restricted_rights().can_change_info_and_settings();
  }

  bool can_post_messages() const {
    return get_administrator_rights().can_post_messages();
  }

  bool can_edit_messages() const {
    return get_administrator_rights().can_edit_messages();
  }

  bool can_delete_messages() const {
    return get_administrator_rights().can_delete_messages();
  }

  bool can_invite_users() const {
    return get_administrator_rights().can_invite_users() || get_restricted_rights().can_invite_users();
  }

  bool can_manage_invite_links() const {
    // invite links can be managed, only if administrator was explicitly granted the right
    return get_administrator_rights().can_invite_users();
  }

  bool can_restrict_members() const {
    return get_administrator_rights().can_restrict_members();
  }

  bool can_pin_messages() const {
    return get_administrator_rights().can_pin_messages() || get_restricted_rights().can_pin_messages();
  }

  bool can_edit_topics() const {
    // topics can be edited, only if administrator was explicitly granted the right
    return get_administrator_rights().can_manage_topics();
  }

  bool can_pin_topics() const {
    // topics can be pinned, only if administrator was explicitly granted the right
    return get_administrator_rights().can_manage_topics();
  }

  bool can_create_topics() const {
    return get_administrator_rights().can_manage_topics() || get_restricted_rights().can_manage_topics();
  }

  bool can_promote_members() const {
    return get_administrator_rights().can_promote_members();
  }

  bool can_manage_calls() const {
    return get_administrator_rights().can_manage_calls();
  }

  bool can_post_stories() const {
    return get_administrator_rights().can_post_stories();
  }

  bool can_edit_stories() const {
    return get_administrator_rights().can_edit_stories();
  }

  bool can_delete_stories() const {
    return get_administrator_rights().can_delete_stories();
  }

  bool can_be_edited() const {
    return (flags_ & CAN_BE_EDITED) != 0;
  }

  void toggle_can_be_edited() {
    flags_ ^= CAN_BE_EDITED;
  }

  bool can_send_messages() const {
    return get_restricted_rights().can_send_messages();
  }

  bool can_send_audios() const {
    return get_restricted_rights().can_send_audios();
  }

  bool can_send_documents() const {
    return get_restricted_rights().can_send_documents();
  }

  bool can_send_photos() const {
    return get_restricted_rights().can_send_photos();
  }

  bool can_send_videos() const {
    return get_restricted_rights().can_send_videos();
  }

  bool can_send_video_notes() const {
    return get_restricted_rights().can_send_video_notes();
  }

  bool can_send_voice_notes() const {
    return get_restricted_rights().can_send_voice_notes();
  }

  bool can_send_stickers() const {
    return get_restricted_rights().can_send_stickers();
  }

  bool can_send_animations() const {
    return get_restricted_rights().can_send_animations();
  }

  bool can_send_games() const {
    return get_restricted_rights().can_send_games();
  }

  bool can_use_inline_bots() const {
    return get_restricted_rights().can_use_inline_bots();
  }

  bool can_add_web_page_previews() const {
    return get_restricted_rights().can_add_web_page_previews();
  }

  bool can_send_polls() const {
    return get_restricted_rights().can_send_polls();
  }

  void set_is_member(bool is_member) {
    if (is_member) {
      flags_ |= IS_MEMBER;
    } else {
      flags_ &= ~IS_MEMBER;
    }
  }

  bool is_member() const {
    return (flags_ & IS_MEMBER) != 0;
  }

  bool is_left() const {
    return (flags_ & IS_MEMBER) == 0;
  }

  bool is_creator() const {
    return type_ == Type::Creator;
  }

  bool is_administrator() const {
    return type_ == Type::Administrator || type_ == Type::Creator;
  }

  bool is_administrator_member() const {
    return type_ == Type::Administrator || (type_ == Type::Creator && is_member());
  }

  bool is_restricted() const {
    return type_ == Type::Restricted;
  }

  bool is_banned() const {
    return type_ == Type::Banned;
  }

  int32 get_until_date() const {
    return until_date_;
  }

  bool is_anonymous() const {
    return get_administrator_rights().is_anonymous();
  }

  const string &get_rank() const {
    return rank_;
  }

  template <class StorerT>
  void store(StorerT &storer) const {
    uint64 stored_flags = flags_ | (static_cast<uint64>(static_cast<int32>(type_)) << TYPE_SHIFT);
    if (until_date_ > 0) {
      stored_flags |= HAS_UNTIL_DATE;
    }
    if (!rank_.empty()) {
      stored_flags |= HAS_RANK;
    }
    td::store(stored_flags, storer);
    if (until_date_ > 0) {
      td::store(until_date_, storer);
    }
    if (!rank_.empty()) {
      td::store(rank_, storer);
    }
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    uint64 stored_flags;
    if (parser.version() >= static_cast<int32>(Version::MakeParticipantFlags64Bit)) {
      td::parse(stored_flags, parser);
    } else {
      uint32 legacy_flags;
      td::parse(legacy_flags, parser);
      stored_flags = legacy_flags;
    }
    if ((stored_flags & HAS_UNTIL_DATE) != 0) {
      td::parse(until_date_, parser);
      stored_flags &= ~HAS_UNTIL_DATE;
    }
    if ((stored_flags & HAS_RANK) != 0) {
      td::parse(rank_, parser);
      stored_flags &= ~HAS_RANK;
    }
    type_ = static_cast<Type>(static_cast<int32>((stored_flags >> TYPE_SHIFT) & ((1 << TYPE_SIZE) - 1)));
    stored_flags -= static_cast<uint64>(static_cast<int32>(type_)) << TYPE_SHIFT;

    flags_ = stored_flags;

    if (flags_ & RestrictedRights::LEGACY_CAN_SEND_MEDIA) {
      flags_ |= RestrictedRights::CAN_SEND_AUDIOS | RestrictedRights::CAN_SEND_DOCUMENTS |
                RestrictedRights::CAN_SEND_PHOTOS | RestrictedRights::CAN_SEND_VIDEOS |
                RestrictedRights::CAN_SEND_VIDEO_NOTES | RestrictedRights::CAN_SEND_VOICE_NOTES;
    }

    if (is_creator()) {
      flags_ |= AdministratorRights::ALL_ADMINISTRATOR_RIGHTS | RestrictedRights::ALL_RESTRICTED_RIGHTS;
    } else if (is_administrator()) {
      flags_ |= AdministratorRights::CAN_MANAGE_DIALOG;
    }
  }

  friend bool operator==(const DialogParticipantStatus &lhs, const DialogParticipantStatus &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const DialogParticipantStatus &status);
};

bool operator==(const DialogParticipantStatus &lhs, const DialogParticipantStatus &rhs);

bool operator!=(const DialogParticipantStatus &lhs, const DialogParticipantStatus &rhs);

StringBuilder &operator<<(StringBuilder &string_builder, const DialogParticipantStatus &status);

struct DialogParticipant {
  DialogId dialog_id_;
  UserId inviter_user_id_;
  int32 joined_date_ = 0;
  DialogParticipantStatus status_ = DialogParticipantStatus::Left();

  DialogParticipant() = default;

  DialogParticipant(DialogId dialog_id, UserId inviter_user_id, int32 joined_date, DialogParticipantStatus status);

  DialogParticipant(tl_object_ptr<telegram_api::ChatParticipant> &&participant_ptr, int32 chat_creation_date,
                    bool is_creator);

  DialogParticipant(tl_object_ptr<telegram_api::ChannelParticipant> &&participant_ptr, ChannelType channel_type);

  static DialogParticipant left(DialogId dialog_id) {
    return {dialog_id, UserId(), 0, DialogParticipantStatus::Left()};
  }

  static DialogParticipant private_member(UserId user_id, UserId other_user_id) {
    auto inviter_user_id = other_user_id.is_valid() ? other_user_id : user_id;
    return {DialogId(user_id), inviter_user_id, 0, DialogParticipantStatus::Member(0)};
  }

  bool is_valid() const;

  template <class StorerT>
  void store(StorerT &storer) const {
    td::store(dialog_id_, storer);
    td::store(inviter_user_id_, storer);
    td::store(joined_date_, storer);
    td::store(status_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    if (parser.version() >= static_cast<int32>(Version::SupportBannedChannels)) {
      td::parse(dialog_id_, parser);
    } else {
      UserId user_id;
      td::parse(user_id, parser);
      dialog_id_ = DialogId(user_id);
    }
    td::parse(inviter_user_id_, parser);
    td::parse(joined_date_, parser);
    td::parse(status_, parser);
  }
};

StringBuilder &operator<<(StringBuilder &string_builder, const DialogParticipant &dialog_participant);

struct DialogParticipants {
  int32 total_count_ = 0;
  vector<DialogParticipant> participants_;

  DialogParticipants() = default;
  DialogParticipants(int32 total_count, vector<DialogParticipant> &&participants)
      : total_count_(total_count), participants_(std::move(participants)) {
  }

  td_api::object_ptr<td_api::chatMembers> get_chat_members_object(Td *td, const char *source) const;
};

DialogParticipantStatus get_dialog_participant_status(const td_api::object_ptr<td_api::ChatMemberStatus> &status,
                                                      ChannelType channel_type);

}  // namespace td
