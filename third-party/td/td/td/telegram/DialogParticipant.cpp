//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/DialogParticipant.h"

#include "td/telegram/ChatManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/misc.h"
#include "td/telegram/Td.h"

#include "td/utils/common.h"
#include "td/utils/logging.h"

#include <limits>

namespace td {

AdministratorRights::AdministratorRights(const tl_object_ptr<telegram_api::chatAdminRights> &rights,
                                         ChannelType channel_type) {
  if (rights == nullptr) {
    flags_ = 0;
    return;
  }

  if (!rights->other_) {
    LOG(ERROR) << "Receive wrong other flag in " << to_string(rights);
  }
  *this =
      AdministratorRights(rights->anonymous_, rights->other_, rights->change_info_, rights->post_messages_,
                          rights->edit_messages_, rights->delete_messages_, rights->invite_users_, rights->ban_users_,
                          rights->pin_messages_, rights->manage_topics_, rights->add_admins_, rights->manage_call_,
                          rights->post_stories_, rights->edit_stories_, rights->delete_stories_, channel_type);
}

AdministratorRights::AdministratorRights(const td_api::object_ptr<td_api::chatAdministratorRights> &rights,
                                         ChannelType channel_type) {
  if (rights == nullptr) {
    flags_ = 0;
    return;
  }
  *this = AdministratorRights(rights->is_anonymous_, rights->can_manage_chat_, rights->can_change_info_,
                              rights->can_post_messages_, rights->can_edit_messages_, rights->can_delete_messages_,
                              rights->can_invite_users_, rights->can_restrict_members_, rights->can_pin_messages_,
                              rights->can_manage_topics_, rights->can_promote_members_, rights->can_manage_video_chats_,
                              rights->can_post_stories_, rights->can_edit_stories_, rights->can_delete_stories_,
                              channel_type);
}

AdministratorRights::AdministratorRights(bool is_anonymous, bool can_manage_dialog, bool can_change_info,
                                         bool can_post_messages, bool can_edit_messages, bool can_delete_messages,
                                         bool can_invite_users, bool can_restrict_members, bool can_pin_messages,
                                         bool can_manage_topics, bool can_promote_members, bool can_manage_calls,
                                         bool can_post_stories, bool can_edit_stories, bool can_delete_stories,
                                         ChannelType channel_type) {
  switch (channel_type) {
    case ChannelType::Broadcast:
      can_pin_messages = false;
      can_manage_topics = false;
      is_anonymous = false;
      break;
    case ChannelType::Megagroup:
      can_post_messages = false;
      can_edit_messages = false;
      break;
    case ChannelType::Unknown:
      break;
  }
  flags_ = (static_cast<uint64>(can_manage_dialog) * CAN_MANAGE_DIALOG) |
           (static_cast<uint64>(can_change_info) * CAN_CHANGE_INFO_AND_SETTINGS) |
           (static_cast<uint64>(can_post_messages) * CAN_POST_MESSAGES) |
           (static_cast<uint64>(can_edit_messages) * CAN_EDIT_MESSAGES) |
           (static_cast<uint64>(can_delete_messages) * CAN_DELETE_MESSAGES) |
           (static_cast<uint64>(can_invite_users) * CAN_INVITE_USERS) |
           (static_cast<uint64>(can_restrict_members) * CAN_RESTRICT_MEMBERS) |
           (static_cast<uint64>(can_pin_messages) * CAN_PIN_MESSAGES) |
           (static_cast<uint64>(can_manage_topics) * CAN_MANAGE_TOPICS) |
           (static_cast<uint64>(can_promote_members) * CAN_PROMOTE_MEMBERS) |
           (static_cast<uint64>(can_manage_calls) * CAN_MANAGE_CALLS) |
           (static_cast<uint64>(can_post_stories) * CAN_POST_STORIES) |
           (static_cast<uint64>(can_edit_stories) * CAN_EDIT_STORIES) |
           (static_cast<uint64>(can_delete_stories) * CAN_DELETE_STORIES) |
           (static_cast<uint64>(is_anonymous) * IS_ANONYMOUS);
  if (flags_ != 0) {
    flags_ |= CAN_MANAGE_DIALOG;
    if (channel_type == ChannelType::Broadcast) {
      flags_ |= CAN_RESTRICT_MEMBERS;
    }
  }
}

telegram_api::object_ptr<telegram_api::chatAdminRights> AdministratorRights::get_chat_admin_rights() const {
  int32 flags = 0;
  if (can_change_info_and_settings()) {
    flags |= telegram_api::chatAdminRights::CHANGE_INFO_MASK;
  }
  if (can_post_messages()) {
    flags |= telegram_api::chatAdminRights::POST_MESSAGES_MASK;
  }
  if (can_edit_messages()) {
    flags |= telegram_api::chatAdminRights::EDIT_MESSAGES_MASK;
  }
  if (can_delete_messages()) {
    flags |= telegram_api::chatAdminRights::DELETE_MESSAGES_MASK;
  }
  if (can_invite_users()) {
    flags |= telegram_api::chatAdminRights::INVITE_USERS_MASK;
  }
  if (can_restrict_members()) {
    flags |= telegram_api::chatAdminRights::BAN_USERS_MASK;
  }
  if (can_pin_messages()) {
    flags |= telegram_api::chatAdminRights::PIN_MESSAGES_MASK;
  }
  if (can_manage_topics()) {
    flags |= telegram_api::chatAdminRights::MANAGE_TOPICS_MASK;
  }
  if (can_promote_members()) {
    flags |= telegram_api::chatAdminRights::ADD_ADMINS_MASK;
  }
  if (can_manage_calls()) {
    flags |= telegram_api::chatAdminRights::MANAGE_CALL_MASK;
  }
  if (can_manage_dialog()) {
    flags |= telegram_api::chatAdminRights::OTHER_MASK;
  }
  if (can_post_stories()) {
    flags |= telegram_api::chatAdminRights::POST_STORIES_MASK;
  }
  if (can_edit_stories()) {
    flags |= telegram_api::chatAdminRights::EDIT_STORIES_MASK;
  }
  if (can_delete_stories()) {
    flags |= telegram_api::chatAdminRights::DELETE_STORIES_MASK;
  }
  if (is_anonymous()) {
    flags |= telegram_api::chatAdminRights::ANONYMOUS_MASK;
  }

  return telegram_api::make_object<telegram_api::chatAdminRights>(
      flags, false /*ignored*/, false /*ignored*/, false /*ignored*/, false /*ignored*/, false /*ignored*/,
      false /*ignored*/, false /*ignored*/, false /*ignored*/, false /*ignored*/, false /*ignored*/, false /*ignored*/,
      false /*ignored*/, false /*ignored*/, false /*ignored*/, false /*ignored*/);
}

td_api::object_ptr<td_api::chatAdministratorRights> AdministratorRights::get_chat_administrator_rights_object() const {
  return td_api::make_object<td_api::chatAdministratorRights>(
      can_manage_dialog(), can_change_info_and_settings(), can_post_messages(), can_edit_messages(),
      can_delete_messages(), can_invite_users(), can_restrict_members(), can_pin_messages(), can_manage_topics(),
      can_promote_members(), can_manage_calls(), can_post_stories(), can_edit_stories(), can_delete_stories(),
      is_anonymous());
}

bool operator==(const AdministratorRights &lhs, const AdministratorRights &rhs) {
  return lhs.flags_ == rhs.flags_;
}

bool operator!=(const AdministratorRights &lhs, const AdministratorRights &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const AdministratorRights &status) {
  string_builder << "Administrator: ";
  if (status.can_manage_dialog()) {
    string_builder << "(manage)";
  }
  if (status.can_change_info_and_settings()) {
    string_builder << "(change)";
  }
  if (status.can_post_messages()) {
    string_builder << "(post)";
  }
  if (status.can_edit_messages()) {
    string_builder << "(edit)";
  }
  if (status.can_delete_messages()) {
    string_builder << "(delete)";
  }
  if (status.can_invite_users()) {
    string_builder << "(invite)";
  }
  if (status.can_restrict_members()) {
    string_builder << "(restrict)";
  }
  if (status.can_pin_messages()) {
    string_builder << "(pin)";
  }
  if (status.can_manage_topics()) {
    string_builder << "(manage_topics)";
  }
  if (status.can_promote_members()) {
    string_builder << "(promote)";
  }
  if (status.can_manage_calls()) {
    string_builder << "(voice chat)";
  }
  if (status.can_post_stories()) {
    string_builder << "(post story)";
  }
  if (status.can_edit_stories()) {
    string_builder << "(edit story)";
  }
  if (status.can_delete_stories()) {
    string_builder << "(delete story)";
  }
  if (status.is_anonymous()) {
    string_builder << "(anonymous)";
  }
  return string_builder;
}

RestrictedRights::RestrictedRights(const tl_object_ptr<telegram_api::chatBannedRights> &rights,
                                   ChannelType channel_type) {
  if (rights == nullptr || channel_type == ChannelType::Broadcast) {
    flags_ = 0;
    return;
  }
  if (rights->view_messages_) {
    LOG(ERROR) << "Can't view messages in banned rights " << to_string(rights);
  }
  LOG_IF(ERROR, rights->until_date_ != std::numeric_limits<int32>::max())
      << "Have until date " << rights->until_date_ << " in restricted rights";

  *this = RestrictedRights(!rights->send_plain_, !rights->send_audios_, !rights->send_docs_, !rights->send_photos_,
                           !rights->send_videos_, !rights->send_roundvideos_, !rights->send_voices_,
                           !rights->send_stickers_, !rights->send_gifs_, !rights->send_games_, !rights->send_inline_,
                           !rights->embed_links_, !rights->send_polls_, !rights->change_info_, !rights->invite_users_,
                           !rights->pin_messages_, !rights->manage_topics_, channel_type);
}

RestrictedRights::RestrictedRights(const td_api::object_ptr<td_api::chatPermissions> &rights,
                                   ChannelType channel_type) {
  if (rights == nullptr || channel_type == ChannelType::Broadcast) {
    flags_ = 0;
    return;
  }

  *this = RestrictedRights(rights->can_send_basic_messages_, rights->can_send_audios_, rights->can_send_documents_,
                           rights->can_send_photos_, rights->can_send_videos_, rights->can_send_video_notes_,
                           rights->can_send_voice_notes_, rights->can_send_other_messages_,
                           rights->can_send_other_messages_, rights->can_send_other_messages_,
                           rights->can_send_other_messages_, rights->can_add_link_previews_, rights->can_send_polls_,
                           rights->can_change_info_, rights->can_invite_users_, rights->can_pin_messages_,
                           rights->can_create_topics_, channel_type);
}

RestrictedRights::RestrictedRights(bool can_send_messages, bool can_send_audios, bool can_send_documents,
                                   bool can_send_photos, bool can_send_videos, bool can_send_video_notes,
                                   bool can_send_voice_notes, bool can_send_stickers, bool can_send_animations,
                                   bool can_send_games, bool can_use_inline_bots, bool can_add_web_page_previews,
                                   bool can_send_polls, bool can_change_info_and_settings, bool can_invite_users,
                                   bool can_pin_messages, bool can_manage_topics, ChannelType channel_type) {
  if (channel_type == ChannelType::Broadcast) {
    flags_ = 0;
    return;
  }
  flags_ = (static_cast<uint64>(can_send_messages) * CAN_SEND_MESSAGES) |
           (static_cast<uint64>(can_send_audios) * CAN_SEND_AUDIOS) |
           (static_cast<uint64>(can_send_documents) * CAN_SEND_DOCUMENTS) |
           (static_cast<uint64>(can_send_photos) * CAN_SEND_PHOTOS) |
           (static_cast<uint64>(can_send_videos) * CAN_SEND_VIDEOS) |
           (static_cast<uint64>(can_send_video_notes) * CAN_SEND_VIDEO_NOTES) |
           (static_cast<uint64>(can_send_voice_notes) * CAN_SEND_VOICE_NOTES) |
           (static_cast<uint64>(can_send_stickers) * CAN_SEND_STICKERS) |
           (static_cast<uint64>(can_send_animations) * CAN_SEND_ANIMATIONS) |
           (static_cast<uint64>(can_send_games) * CAN_SEND_GAMES) |
           (static_cast<uint64>(can_use_inline_bots) * CAN_USE_INLINE_BOTS) |
           (static_cast<uint64>(can_add_web_page_previews) * CAN_ADD_WEB_PAGE_PREVIEWS) |
           (static_cast<uint64>(can_send_polls) * CAN_SEND_POLLS) |
           (static_cast<uint64>(can_change_info_and_settings) * CAN_CHANGE_INFO_AND_SETTINGS) |
           (static_cast<uint64>(can_invite_users) * CAN_INVITE_USERS) |
           (static_cast<uint64>(can_pin_messages) * CAN_PIN_MESSAGES) |
           (static_cast<uint64>(can_manage_topics) * CAN_MANAGE_TOPICS);
}

td_api::object_ptr<td_api::chatPermissions> RestrictedRights::get_chat_permissions_object() const {
  return td_api::make_object<td_api::chatPermissions>(
      can_send_messages(), can_send_audios(), can_send_documents(), can_send_photos(), can_send_videos(),
      can_send_video_notes(), can_send_voice_notes(), can_send_polls(),
      can_send_stickers() || can_send_animations() || can_send_games() || can_use_inline_bots(),
      can_add_web_page_previews(), can_change_info_and_settings(), can_invite_users(), can_pin_messages(),
      can_manage_topics());
}

tl_object_ptr<telegram_api::chatBannedRights> RestrictedRights::get_chat_banned_rights() const {
  int32 flags = 0;
  if (!can_send_messages()) {
    flags |= telegram_api::chatBannedRights::SEND_PLAIN_MASK;
  }
  if (!can_send_audios()) {
    flags |= telegram_api::chatBannedRights::SEND_AUDIOS_MASK;
  }
  if (!can_send_documents()) {
    flags |= telegram_api::chatBannedRights::SEND_DOCS_MASK;
  }
  if (!can_send_photos()) {
    flags |= telegram_api::chatBannedRights::SEND_PHOTOS_MASK;
  }
  if (!can_send_videos()) {
    flags |= telegram_api::chatBannedRights::SEND_VIDEOS_MASK;
  }
  if (!can_send_video_notes()) {
    flags |= telegram_api::chatBannedRights::SEND_ROUNDVIDEOS_MASK;
  }
  if (!can_send_voice_notes()) {
    flags |= telegram_api::chatBannedRights::SEND_VOICES_MASK;
  }
  if (!can_send_stickers()) {
    flags |= telegram_api::chatBannedRights::SEND_STICKERS_MASK;
  }
  if (!can_send_animations()) {
    flags |= telegram_api::chatBannedRights::SEND_GIFS_MASK;
  }
  if (!can_send_games()) {
    flags |= telegram_api::chatBannedRights::SEND_GAMES_MASK;
  }
  if (!can_use_inline_bots()) {
    flags |= telegram_api::chatBannedRights::SEND_INLINE_MASK;
  }
  if (!can_add_web_page_previews()) {
    flags |= telegram_api::chatBannedRights::EMBED_LINKS_MASK;
  }
  if (!can_send_polls()) {
    flags |= telegram_api::chatBannedRights::SEND_POLLS_MASK;
  }
  if (!can_change_info_and_settings()) {
    flags |= telegram_api::chatBannedRights::CHANGE_INFO_MASK;
  }
  if (!can_invite_users()) {
    flags |= telegram_api::chatBannedRights::INVITE_USERS_MASK;
  }
  if (!can_pin_messages()) {
    flags |= telegram_api::chatBannedRights::PIN_MESSAGES_MASK;
  }
  if (!can_manage_topics()) {
    flags |= telegram_api::chatBannedRights::MANAGE_TOPICS_MASK;
  }

  LOG(INFO) << "Create chat banned rights " << flags;
  return make_tl_object<telegram_api::chatBannedRights>(
      flags, false /*ignored*/, false /*ignored*/, false /*ignored*/, false /*ignored*/, false /*ignored*/,
      false /*ignored*/, false /*ignored*/, false /*ignored*/, false /*ignored*/, false /*ignored*/, false /*ignored*/,
      false /*ignored*/, false /*ignored*/, false /*ignored*/, false /*ignored*/, false /*ignored*/, false /*ignored*/,
      false /*ignored*/, false /*ignored*/, false /*ignored*/, 0);
}

bool operator==(const RestrictedRights &lhs, const RestrictedRights &rhs) {
  return lhs.flags_ == rhs.flags_;
}

bool operator!=(const RestrictedRights &lhs, const RestrictedRights &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const RestrictedRights &status) {
  string_builder << "Restricted: ";
  if (!status.can_send_messages()) {
    string_builder << "(text+contact+invoice+location+venue)";
  }
  if (!status.can_send_audios()) {
    string_builder << "(audios)";
  }
  if (!status.can_send_documents()) {
    string_builder << "(documents)";
  }
  if (!status.can_send_photos()) {
    string_builder << "(photos)";
  }
  if (!status.can_send_videos()) {
    string_builder << "(videos)";
  }
  if (!status.can_send_video_notes()) {
    string_builder << "(video notes)";
  }
  if (!status.can_send_voice_notes()) {
    string_builder << "(voice notes)";
  }
  if (!status.can_send_stickers()) {
    string_builder << "(stickers+dices)";
  }
  if (!status.can_send_animations()) {
    string_builder << "(animations)";
  }
  if (!status.can_send_games()) {
    string_builder << "(games)";
  }
  if (!status.can_send_polls()) {
    string_builder << "(polls)";
  }
  if (!status.can_use_inline_bots()) {
    string_builder << "(inline bots)";
  }
  if (!status.can_add_web_page_previews()) {
    string_builder << "(links)";
  }
  if (!status.can_change_info_and_settings()) {
    string_builder << "(change)";
  }
  if (!status.can_invite_users()) {
    string_builder << "(invite)";
  }
  if (!status.can_pin_messages()) {
    string_builder << "(pin)";
  }
  if (!status.can_manage_topics()) {
    string_builder << "(topics)";
  }
  return string_builder;
}

DialogParticipantStatus::DialogParticipantStatus(Type type, uint64 flags, int32 until_date, string rank)
    : type_(type), until_date_(until_date), flags_(flags), rank_(strip_empty_characters(std::move(rank), 16)) {
}

int32 DialogParticipantStatus::fix_until_date(int32 date) {
  if (date == std::numeric_limits<int32>::max() || date < 0) {
    return 0;
  }
  return date;
}

DialogParticipantStatus DialogParticipantStatus::Creator(bool is_member, bool is_anonymous, string &&rank) {
  return DialogParticipantStatus(Type::Creator,
                                 AdministratorRights::ALL_ADMINISTRATOR_RIGHTS |
                                     RestrictedRights::ALL_RESTRICTED_RIGHTS | (is_member ? IS_MEMBER : 0) |
                                     (is_anonymous ? AdministratorRights::IS_ANONYMOUS : 0),
                                 0, std::move(rank));
}

DialogParticipantStatus DialogParticipantStatus::Administrator(AdministratorRights administrator_rights, string &&rank,
                                                               bool can_be_edited) {
  uint64 flags = administrator_rights.flags_;
  if (flags == 0) {
    return Member(0);
  }
  flags = flags | (static_cast<uint64>(can_be_edited) * CAN_BE_EDITED);
  return DialogParticipantStatus(
      Type::Administrator,
      IS_MEMBER | (RestrictedRights::ALL_RESTRICTED_RIGHTS & ~RestrictedRights::ALL_ADMIN_PERMISSION_RIGHTS) | flags, 0,
      std::move(rank));
}

DialogParticipantStatus DialogParticipantStatus::Member(int32 member_until_date) {
  return DialogParticipantStatus(Type::Member, IS_MEMBER | RestrictedRights::ALL_RESTRICTED_RIGHTS, member_until_date,
                                 string());
}

DialogParticipantStatus DialogParticipantStatus::Restricted(RestrictedRights restricted_rights, bool is_member,
                                                            int32 restricted_until_date, ChannelType channel_type) {
  uint64 flags = restricted_rights.flags_;
  if (flags == RestrictedRights::ALL_RESTRICTED_RIGHTS || channel_type == ChannelType::Broadcast) {
    return is_member ? Member(0) : Left();
  }
  flags |= (static_cast<uint64>(is_member) * IS_MEMBER);
  return DialogParticipantStatus(Type::Restricted, flags, fix_until_date(restricted_until_date), string());
}

DialogParticipantStatus DialogParticipantStatus::Left() {
  return DialogParticipantStatus(Type::Left, RestrictedRights::ALL_RESTRICTED_RIGHTS, 0, string());
}

DialogParticipantStatus DialogParticipantStatus::Banned(int32 banned_until_date) {
  return DialogParticipantStatus(Type::Banned, 0, fix_until_date(banned_until_date), string());
}

DialogParticipantStatus DialogParticipantStatus::GroupAdministrator(bool is_creator) {
  return Administrator(AdministratorRights(false, true, true, false, false, true, true, true, true, false, false, true,
                                           false, false, false, ChannelType::Unknown),
                       string(), is_creator);
}

DialogParticipantStatus DialogParticipantStatus::ChannelAdministrator(bool is_creator, bool is_megagroup) {
  auto rights = is_megagroup ? AdministratorRights(false, true, true, false, false, true, true, true, true, true, false,
                                                   false, false, false, false, ChannelType::Megagroup)
                             : AdministratorRights(false, true, false, true, true, true, false, true, false, false,
                                                   false, false, true, true, true, ChannelType::Broadcast);
  return Administrator(rights, string(), is_creator);
}

DialogParticipantStatus::DialogParticipantStatus(bool can_be_edited,
                                                 tl_object_ptr<telegram_api::chatAdminRights> &&admin_rights,
                                                 string rank, ChannelType channel_type) {
  CHECK(admin_rights != nullptr);
  *this = Administrator(AdministratorRights(admin_rights, channel_type), std::move(rank), can_be_edited);
}

DialogParticipantStatus::DialogParticipantStatus(bool is_member,
                                                 tl_object_ptr<telegram_api::chatBannedRights> &&banned_rights,
                                                 ChannelType channel_type) {
  CHECK(banned_rights != nullptr);
  if (banned_rights->view_messages_) {
    *this = Banned(banned_rights->until_date_);
    return;
  }
  if (channel_type == ChannelType::Broadcast) {
    *this = is_member ? Member(0) : Left();
    return;
  }

  auto until_date = fix_until_date(banned_rights->until_date_);
  banned_rights->until_date_ = std::numeric_limits<int32>::max();

  // manually create Restricted status, because the user can be restricted, but with yet unknown restrictions
  uint64 flags = RestrictedRights(banned_rights, channel_type).flags_ | (static_cast<uint64>(is_member) * IS_MEMBER);
  *this = DialogParticipantStatus(Type::Restricted, flags, until_date, string());
}

RestrictedRights DialogParticipantStatus::get_effective_restricted_rights() const {
  return RestrictedRights(can_send_messages(), can_send_audios(), can_send_documents(), can_send_photos(),
                          can_send_videos(), can_send_video_notes(), can_send_voice_notes(), can_send_stickers(),
                          can_send_animations(), can_send_games(), can_use_inline_bots(), can_add_web_page_previews(),
                          can_send_polls(), can_change_info_and_settings(), can_invite_users(), can_pin_messages(),
                          can_create_topics(), ChannelType::Unknown);
}

tl_object_ptr<td_api::ChatMemberStatus> DialogParticipantStatus::get_chat_member_status_object() const {
  switch (type_) {
    case Type::Creator:
      return td_api::make_object<td_api::chatMemberStatusCreator>(rank_, is_anonymous(), is_member());
    case Type::Administrator:
      return td_api::make_object<td_api::chatMemberStatusAdministrator>(
          rank_, can_be_edited(), get_administrator_rights().get_chat_administrator_rights_object());
    case Type::Member:
      return td_api::make_object<td_api::chatMemberStatusMember>(until_date_);
    case Type::Restricted:
      return td_api::make_object<td_api::chatMemberStatusRestricted>(
          is_member(), until_date_, get_restricted_rights().get_chat_permissions_object());
    case Type::Left:
      return td_api::make_object<td_api::chatMemberStatusLeft>();
    case Type::Banned:
      return td_api::make_object<td_api::chatMemberStatusBanned>(until_date_);
    default:
      UNREACHABLE();
      return nullptr;
  }
}

tl_object_ptr<telegram_api::chatAdminRights> DialogParticipantStatus::get_chat_admin_rights() const {
  return get_administrator_rights().get_chat_admin_rights();
}

tl_object_ptr<telegram_api::chatBannedRights> DialogParticipantStatus::get_chat_banned_rights() const {
  auto result = get_restricted_rights().get_chat_banned_rights();
  if (type_ == Type::Banned) {
    result->flags_ |= telegram_api::chatBannedRights::VIEW_MESSAGES_MASK;
  }
  result->until_date_ = until_date_;
  return result;
}

DialogParticipantStatus DialogParticipantStatus::apply_restrictions(RestrictedRights default_restrictions,
                                                                    bool is_booster, bool is_bot) const {
  auto flags = flags_;
  switch (type_) {
    case Type::Creator:
      // creator can do anything and isn't affected by restrictions
      break;
    case Type::Administrator:
      // administrators aren't affected by restrictions, but if everyone can invite users,
      // pin messages or change info, they also can do that
      if (!is_bot) {
        flags |= default_restrictions.flags_ & RestrictedRights::ALL_ADMIN_PERMISSION_RIGHTS;
      }
      break;
    case Type::Member:
    case Type::Restricted:
    case Type::Left:
      if (!is_booster) {
        // members and restricted are affected by default restrictions unless they are supergroup boosters
        flags &= (~RestrictedRights::ALL_RESTRICTED_RIGHTS) | default_restrictions.flags_;
      }
      if (is_bot) {
        // bots must be explicitly granted administrator rights to use them
        flags &= ~RestrictedRights::ALL_ADMIN_PERMISSION_RIGHTS;
      }
      break;
    case Type::Banned:
      // banned can do nothing, even restrictions allows them to do that
      break;
    default:
      UNREACHABLE();
      break;
  }

  return DialogParticipantStatus(type_, flags, 0, string());
}

void DialogParticipantStatus::update_restrictions() const {
  if (until_date_ != 0 && G()->unix_time() > until_date_) {
    until_date_ = 0;
    if (type_ == Type::Restricted) {
      if (is_member()) {
        type_ = Type::Member;
      } else {
        type_ = Type::Left;
      }
      flags_ |= RestrictedRights::ALL_RESTRICTED_RIGHTS;
    } else if (type_ == Type::Banned || type_ == Type::Member) {
      type_ = Type::Left;
    } else {
      UNREACHABLE();
    }
  }
}

bool operator==(const DialogParticipantStatus &lhs, const DialogParticipantStatus &rhs) {
  return lhs.type_ == rhs.type_ && lhs.flags_ == rhs.flags_ && lhs.until_date_ == rhs.until_date_ &&
         lhs.rank_ == rhs.rank_;
}

bool operator!=(const DialogParticipantStatus &lhs, const DialogParticipantStatus &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const DialogParticipantStatus &status) {
  switch (status.type_) {
    case DialogParticipantStatus::Type::Creator:
      string_builder << "Creator";
      if (!status.is_member()) {
        string_builder << "-non-member";
      }
      if (!status.rank_.empty()) {
        string_builder << " [" << status.rank_ << "]";
      }
      if (status.is_anonymous()) {
        string_builder << "-anonymous";
      }
      return string_builder;
    case DialogParticipantStatus::Type::Administrator:
      string_builder << status.get_administrator_rights();
      if (status.can_be_edited()) {
        string_builder << "(can_be_edited)";
      }
      if (!status.rank_.empty()) {
        string_builder << " [" << status.rank_ << "]";
      }
      return string_builder;
    case DialogParticipantStatus::Type::Member:
      string_builder << "Member";
      if (status.until_date_ != 0) {
        string_builder << " until " << status.until_date_;
      }
      return string_builder;
    case DialogParticipantStatus::Type::Restricted:
      string_builder << status.get_restricted_rights();
      if (status.until_date_ == 0) {
        string_builder << "forever ";
      } else {
        string_builder << "until " << status.until_date_ << " ";
      }
      if (!status.is_member()) {
        string_builder << "non-";
      }
      string_builder << "member";
      return string_builder;
    case DialogParticipantStatus::Type::Left:
      return string_builder << "Left";
    case DialogParticipantStatus::Type::Banned:
      string_builder << "Banned ";
      if (status.until_date_ == 0) {
        string_builder << "forever";
      } else {
        string_builder << "until " << status.until_date_;
      }
      return string_builder;
    default:
      UNREACHABLE();
      return string_builder << "Impossible";
  }
}

DialogParticipantStatus get_dialog_participant_status(const td_api::object_ptr<td_api::ChatMemberStatus> &status,
                                                      ChannelType channel_type) {
  auto constructor_id = status == nullptr ? td_api::chatMemberStatusMember::ID : status->get_id();
  auto fix_until_date = [](int32 until_date) {
    if (until_date == 0) {
      // fast path
      return 0;
    }

    // if user is restricted for more than 366 days or less than 30 seconds from the current time,
    // they are considered to be restricted forever
    auto unix_time = G()->unix_time();
    if (until_date < unix_time + 30 || until_date > unix_time + 366 * 86400) {
      return 0;
    }
    return until_date;
  };
  switch (constructor_id) {
    case td_api::chatMemberStatusCreator::ID: {
      auto st = static_cast<const td_api::chatMemberStatusCreator *>(status.get());
      auto custom_title = st->custom_title_;
      if (!clean_input_string(custom_title)) {
        custom_title.clear();
      }
      return DialogParticipantStatus::Creator(st->is_member_, st->is_anonymous_, std::move(custom_title));
    }
    case td_api::chatMemberStatusAdministrator::ID: {
      auto st = static_cast<const td_api::chatMemberStatusAdministrator *>(status.get());
      auto custom_title = st->custom_title_;
      if (!clean_input_string(custom_title)) {
        custom_title.clear();
      }
      return DialogParticipantStatus::Administrator(AdministratorRights(st->rights_, channel_type),
                                                    std::move(custom_title), true /*st->can_be_edited_*/);
    }
    case td_api::chatMemberStatusMember::ID:
      return DialogParticipantStatus::Member(0);
    case td_api::chatMemberStatusRestricted::ID: {
      auto st = static_cast<const td_api::chatMemberStatusRestricted *>(status.get());
      return DialogParticipantStatus::Restricted(RestrictedRights(st->permissions_, channel_type), st->is_member_,
                                                 fix_until_date(st->restricted_until_date_), channel_type);
    }
    case td_api::chatMemberStatusLeft::ID:
      return DialogParticipantStatus::Left();
    case td_api::chatMemberStatusBanned::ID: {
      auto st = static_cast<const td_api::chatMemberStatusBanned *>(status.get());
      return DialogParticipantStatus::Banned(fix_until_date(st->banned_until_date_));
    }
    default:
      UNREACHABLE();
      return DialogParticipantStatus::Member(0);
  }
}

DialogParticipant::DialogParticipant(DialogId dialog_id, UserId inviter_user_id, int32 joined_date,
                                     DialogParticipantStatus status)
    : dialog_id_(dialog_id), inviter_user_id_(inviter_user_id), joined_date_(joined_date), status_(std::move(status)) {
  if (!inviter_user_id_.is_valid() && inviter_user_id_ != UserId()) {
    LOG(ERROR) << "Receive inviter " << inviter_user_id_;
    inviter_user_id_ = UserId();
  }
  if (joined_date_ < 0) {
    LOG(ERROR) << "Receive date " << joined_date_;
    joined_date_ = 0;
  }
}

DialogParticipant::DialogParticipant(tl_object_ptr<telegram_api::ChatParticipant> &&participant_ptr,
                                     int32 chat_creation_date, bool is_creator) {
  switch (participant_ptr->get_id()) {
    case telegram_api::chatParticipant::ID: {
      auto participant = move_tl_object_as<telegram_api::chatParticipant>(participant_ptr);
      *this = {DialogId(UserId(participant->user_id_)), UserId(participant->inviter_id_), participant->date_,
               DialogParticipantStatus::Member(0)};
      break;
    }
    case telegram_api::chatParticipantCreator::ID: {
      auto participant = move_tl_object_as<telegram_api::chatParticipantCreator>(participant_ptr);
      *this = {DialogId(UserId(participant->user_id_)), UserId(participant->user_id_), chat_creation_date,
               DialogParticipantStatus::Creator(true, false, string())};
      break;
    }
    case telegram_api::chatParticipantAdmin::ID: {
      auto participant = move_tl_object_as<telegram_api::chatParticipantAdmin>(participant_ptr);
      *this = {DialogId(UserId(participant->user_id_)), UserId(participant->inviter_id_), participant->date_,
               DialogParticipantStatus::GroupAdministrator(is_creator)};
      break;
    }
    default:
      UNREACHABLE();
  }
}

DialogParticipant::DialogParticipant(tl_object_ptr<telegram_api::ChannelParticipant> &&participant_ptr,
                                     ChannelType channel_type) {
  CHECK(participant_ptr != nullptr);

  switch (participant_ptr->get_id()) {
    case telegram_api::channelParticipant::ID: {
      auto participant = move_tl_object_as<telegram_api::channelParticipant>(participant_ptr);
      *this = {DialogId(UserId(participant->user_id_)), UserId(), participant->date_,
               DialogParticipantStatus::Member(participant->subscription_until_date_)};
      break;
    }
    case telegram_api::channelParticipantSelf::ID: {
      auto participant = move_tl_object_as<telegram_api::channelParticipantSelf>(participant_ptr);
      *this = {DialogId(UserId(participant->user_id_)), UserId(participant->inviter_id_), participant->date_,
               DialogParticipantStatus::Member(participant->subscription_until_date_)};
      break;
    }
    case telegram_api::channelParticipantCreator::ID: {
      auto participant = move_tl_object_as<telegram_api::channelParticipantCreator>(participant_ptr);
      *this = {DialogId(UserId(participant->user_id_)), UserId(), 0,
               DialogParticipantStatus::Creator(true, participant->admin_rights_->anonymous_,
                                                std::move(participant->rank_))};
      break;
    }
    case telegram_api::channelParticipantAdmin::ID: {
      auto participant = move_tl_object_as<telegram_api::channelParticipantAdmin>(participant_ptr);
      *this = {DialogId(UserId(participant->user_id_)), UserId(participant->promoted_by_), participant->date_,
               DialogParticipantStatus(participant->can_edit_, std::move(participant->admin_rights_),
                                       std::move(participant->rank_), channel_type)};
      break;
    }
    case telegram_api::channelParticipantLeft::ID: {
      auto participant = move_tl_object_as<telegram_api::channelParticipantLeft>(participant_ptr);
      *this = {DialogId(participant->peer_), UserId(), 0, DialogParticipantStatus::Left()};
      break;
    }
    case telegram_api::channelParticipantBanned::ID: {
      auto participant = move_tl_object_as<telegram_api::channelParticipantBanned>(participant_ptr);
      *this = {DialogId(participant->peer_), UserId(participant->kicked_by_), participant->date_,
               DialogParticipantStatus(!participant->left_, std::move(participant->banned_rights_), channel_type)};
      break;
    }
    default:
      UNREACHABLE();
      break;
  }
}

bool DialogParticipant::is_valid() const {
  if (!dialog_id_.is_valid() || joined_date_ < 0) {
    return false;
  }
  if (status_.is_restricted() || status_.is_banned() || (status_.is_administrator() && !status_.is_creator())) {
    return inviter_user_id_.is_valid();
  }
  return true;
}

StringBuilder &operator<<(StringBuilder &string_builder, const DialogParticipant &dialog_participant) {
  return string_builder << '[' << dialog_participant.dialog_id_ << " invited by " << dialog_participant.inviter_user_id_
                        << " at " << dialog_participant.joined_date_ << " with status " << dialog_participant.status_
                        << ']';
}

td_api::object_ptr<td_api::chatMembers> DialogParticipants::get_chat_members_object(Td *td, const char *source) const {
  vector<tl_object_ptr<td_api::chatMember>> chat_members;
  chat_members.reserve(participants_.size());
  for (auto &participant : participants_) {
    chat_members.push_back(td->chat_manager_->get_chat_member_object(participant, source));
  }

  return td_api::make_object<td_api::chatMembers>(total_count_, std::move(chat_members));
}

}  // namespace td
