//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/DialogParticipantFilter.h"

#include "td/telegram/DialogId.h"
#include "td/telegram/DialogParticipant.h"
#include "td/telegram/Td.h"
#include "td/telegram/UserManager.h"

namespace td {

StringBuilder &operator<<(StringBuilder &string_builder, const DialogParticipantFilter &filter) {
  switch (filter.type_) {
    case DialogParticipantFilter::Type::Contacts:
      return string_builder << "Contacts";
    case DialogParticipantFilter::Type::Administrators:
      return string_builder << "Administrators";
    case DialogParticipantFilter::Type::Members:
      return string_builder << "Members";
    case DialogParticipantFilter::Type::Restricted:
      return string_builder << "Restricted";
    case DialogParticipantFilter::Type::Banned:
      return string_builder << "Banned";
    case DialogParticipantFilter::Type::Mention:
      return string_builder << "Mention";
    case DialogParticipantFilter::Type::Bots:
      return string_builder << "Bots";
    default:
      UNREACHABLE();
      return string_builder;
  }
}

DialogParticipantFilter::DialogParticipantFilter(const td_api::object_ptr<td_api::ChatMembersFilter> &filter) {
  if (filter == nullptr) {
    type_ = Type::Members;
    return;
  }
  switch (filter->get_id()) {
    case td_api::chatMembersFilterContacts::ID:
      type_ = Type::Contacts;
      break;
    case td_api::chatMembersFilterAdministrators::ID:
      type_ = Type::Administrators;
      break;
    case td_api::chatMembersFilterMembers::ID:
      type_ = Type::Members;
      break;
    case td_api::chatMembersFilterRestricted::ID:
      type_ = Type::Restricted;
      break;
    case td_api::chatMembersFilterBanned::ID:
      type_ = Type::Banned;
      break;
    case td_api::chatMembersFilterMention::ID: {
      auto mention_filter = static_cast<const td_api::chatMembersFilterMention *>(filter.get());
      top_thread_message_id_ = MessageId(mention_filter->message_thread_id_);
      if (!top_thread_message_id_.is_valid() || !top_thread_message_id_.is_server()) {
        top_thread_message_id_ = MessageId();
      }
      type_ = Type::Mention;
      break;
    }
    case td_api::chatMembersFilterBots::ID:
      type_ = Type::Bots;
      break;
    default:
      UNREACHABLE();
      type_ = Type::Members;
      break;
  }
}

td_api::object_ptr<td_api::SupergroupMembersFilter> DialogParticipantFilter::get_supergroup_members_filter_object(
    const string &query) const {
  switch (type_) {
    case Type::Contacts:
      return td_api::make_object<td_api::supergroupMembersFilterContacts>();
    case Type::Administrators:
      return td_api::make_object<td_api::supergroupMembersFilterAdministrators>();
    case Type::Members:
      return td_api::make_object<td_api::supergroupMembersFilterSearch>(query);
    case Type::Restricted:
      return td_api::make_object<td_api::supergroupMembersFilterRestricted>(query);
    case Type::Banned:
      return td_api::make_object<td_api::supergroupMembersFilterBanned>(query);
    case Type::Mention:
      return td_api::make_object<td_api::supergroupMembersFilterMention>(query, top_thread_message_id_.get());
    case Type::Bots:
      return td_api::make_object<td_api::supergroupMembersFilterBots>();
    default:
      UNREACHABLE();
      return nullptr;
  }
}

bool DialogParticipantFilter::has_query() const {
  switch (type_) {
    case Type::Members:
    case Type::Restricted:
    case Type::Banned:
    case Type::Mention:
      return true;
    case Type::Contacts:
    case Type::Administrators:
    case Type::Bots:
      return false;
    default:
      UNREACHABLE();
      return false;
  }
}

bool DialogParticipantFilter::is_dialog_participant_suitable(const Td *td, const DialogParticipant &participant) const {
  switch (type_) {
    case Type::Contacts:
      return participant.dialog_id_.get_type() == DialogType::User &&
             td->user_manager_->is_user_contact(participant.dialog_id_.get_user_id());
    case Type::Administrators:
      return participant.status_.is_administrator();
    case Type::Members:
      return participant.status_.is_member();
    case Type::Restricted:
      return participant.status_.is_restricted();
    case Type::Banned:
      return participant.status_.is_banned();
    case Type::Mention:
      return true;
    case Type::Bots:
      return participant.dialog_id_.get_type() == DialogType::User &&
             td->user_manager_->is_user_bot(participant.dialog_id_.get_user_id());
    default:
      UNREACHABLE();
      return false;
  }
}

}  // namespace td
