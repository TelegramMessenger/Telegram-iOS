//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/UserPrivacySetting.h"

namespace td {

Result<UserPrivacySetting> UserPrivacySetting::get_user_privacy_setting(
    td_api::object_ptr<td_api::UserPrivacySetting> key) {
  if (key == nullptr) {
    return Status::Error(400, "UserPrivacySetting must be non-empty");
  }
  return UserPrivacySetting(*key);
}

UserPrivacySetting::UserPrivacySetting(const telegram_api::PrivacyKey &key) {
  switch (key.get_id()) {
    case telegram_api::privacyKeyStatusTimestamp::ID:
      type_ = Type::UserStatus;
      break;
    case telegram_api::privacyKeyChatInvite::ID:
      type_ = Type::ChatInvite;
      break;
    case telegram_api::privacyKeyPhoneCall::ID:
      type_ = Type::Call;
      break;
    case telegram_api::privacyKeyPhoneP2P::ID:
      type_ = Type::PeerToPeerCall;
      break;
    case telegram_api::privacyKeyForwards::ID:
      type_ = Type::LinkInForwardedMessages;
      break;
    case telegram_api::privacyKeyProfilePhoto::ID:
      type_ = Type::UserProfilePhoto;
      break;
    case telegram_api::privacyKeyPhoneNumber::ID:
      type_ = Type::UserPhoneNumber;
      break;
    case telegram_api::privacyKeyAddedByPhone::ID:
      type_ = Type::FindByPhoneNumber;
      break;
    case telegram_api::privacyKeyVoiceMessages::ID:
      type_ = Type::VoiceMessages;
      break;
    case telegram_api::privacyKeyAbout::ID:
      type_ = Type::UserBio;
      break;
    case telegram_api::privacyKeyBirthday::ID:
      type_ = Type::UserBirthdate;
      break;
    case telegram_api::privacyKeyStarGiftsAutoSave::ID:
      type_ = Type::StarGiftAutosave;
      break;
    case telegram_api::privacyKeyNoPaidMessages::ID:
      type_ = Type::NoPaidMessages;
      break;
    default:
      UNREACHABLE();
      type_ = Type::UserStatus;
  }
}

td_api::object_ptr<td_api::UserPrivacySetting> UserPrivacySetting::get_user_privacy_setting_object() const {
  switch (type_) {
    case Type::UserStatus:
      return td_api::make_object<td_api::userPrivacySettingShowStatus>();
    case Type::ChatInvite:
      return td_api::make_object<td_api::userPrivacySettingAllowChatInvites>();
    case Type::Call:
      return td_api::make_object<td_api::userPrivacySettingAllowCalls>();
    case Type::PeerToPeerCall:
      return td_api::make_object<td_api::userPrivacySettingAllowPeerToPeerCalls>();
    case Type::LinkInForwardedMessages:
      return td_api::make_object<td_api::userPrivacySettingShowLinkInForwardedMessages>();
    case Type::UserProfilePhoto:
      return td_api::make_object<td_api::userPrivacySettingShowProfilePhoto>();
    case Type::UserPhoneNumber:
      return td_api::make_object<td_api::userPrivacySettingShowPhoneNumber>();
    case Type::FindByPhoneNumber:
      return td_api::make_object<td_api::userPrivacySettingAllowFindingByPhoneNumber>();
    case Type::VoiceMessages:
      return td_api::make_object<td_api::userPrivacySettingAllowPrivateVoiceAndVideoNoteMessages>();
    case Type::UserBio:
      return td_api::make_object<td_api::userPrivacySettingShowBio>();
    case Type::UserBirthdate:
      return td_api::make_object<td_api::userPrivacySettingShowBirthdate>();
    case Type::StarGiftAutosave:
      return td_api::make_object<td_api::userPrivacySettingAutosaveGifts>();
    case Type::NoPaidMessages:
      return td_api::make_object<td_api::userPrivacySettingAllowUnpaidMessages>();
    default:
      UNREACHABLE();
      return nullptr;
  }
}
telegram_api::object_ptr<telegram_api::InputPrivacyKey> UserPrivacySetting::get_input_privacy_key() const {
  switch (type_) {
    case Type::UserStatus:
      return telegram_api::make_object<telegram_api::inputPrivacyKeyStatusTimestamp>();
    case Type::ChatInvite:
      return telegram_api::make_object<telegram_api::inputPrivacyKeyChatInvite>();
    case Type::Call:
      return telegram_api::make_object<telegram_api::inputPrivacyKeyPhoneCall>();
    case Type::PeerToPeerCall:
      return telegram_api::make_object<telegram_api::inputPrivacyKeyPhoneP2P>();
    case Type::LinkInForwardedMessages:
      return telegram_api::make_object<telegram_api::inputPrivacyKeyForwards>();
    case Type::UserProfilePhoto:
      return telegram_api::make_object<telegram_api::inputPrivacyKeyProfilePhoto>();
    case Type::UserPhoneNumber:
      return telegram_api::make_object<telegram_api::inputPrivacyKeyPhoneNumber>();
    case Type::FindByPhoneNumber:
      return telegram_api::make_object<telegram_api::inputPrivacyKeyAddedByPhone>();
    case Type::VoiceMessages:
      return telegram_api::make_object<telegram_api::inputPrivacyKeyVoiceMessages>();
    case Type::UserBio:
      return telegram_api::make_object<telegram_api::inputPrivacyKeyAbout>();
    case Type::UserBirthdate:
      return telegram_api::make_object<telegram_api::inputPrivacyKeyBirthday>();
    case Type::StarGiftAutosave:
      return telegram_api::make_object<telegram_api::inputPrivacyKeyStarGiftsAutoSave>();
    case Type::NoPaidMessages:
      return telegram_api::make_object<telegram_api::inputPrivacyKeyNoPaidMessages>();
    default:
      UNREACHABLE();
      return nullptr;
  }
}

UserPrivacySetting::UserPrivacySetting(const td_api::UserPrivacySetting &key) {
  switch (key.get_id()) {
    case td_api::userPrivacySettingShowStatus::ID:
      type_ = Type::UserStatus;
      break;
    case td_api::userPrivacySettingAllowChatInvites::ID:
      type_ = Type::ChatInvite;
      break;
    case td_api::userPrivacySettingAllowCalls::ID:
      type_ = Type::Call;
      break;
    case td_api::userPrivacySettingAllowPeerToPeerCalls::ID:
      type_ = Type::PeerToPeerCall;
      break;
    case td_api::userPrivacySettingShowLinkInForwardedMessages::ID:
      type_ = Type::LinkInForwardedMessages;
      break;
    case td_api::userPrivacySettingShowProfilePhoto::ID:
      type_ = Type::UserProfilePhoto;
      break;
    case td_api::userPrivacySettingShowPhoneNumber::ID:
      type_ = Type::UserPhoneNumber;
      break;
    case td_api::userPrivacySettingAllowFindingByPhoneNumber::ID:
      type_ = Type::FindByPhoneNumber;
      break;
    case td_api::userPrivacySettingAllowPrivateVoiceAndVideoNoteMessages::ID:
      type_ = Type::VoiceMessages;
      break;
    case td_api::userPrivacySettingShowBio::ID:
      type_ = Type::UserBio;
      break;
    case td_api::userPrivacySettingShowBirthdate::ID:
      type_ = Type::UserBirthdate;
      break;
    case td_api::userPrivacySettingAutosaveGifts::ID:
      type_ = Type::StarGiftAutosave;
      break;
    case td_api::userPrivacySettingAllowUnpaidMessages::ID:
      type_ = Type::NoPaidMessages;
      break;
    default:
      UNREACHABLE();
      type_ = Type::UserStatus;
  }
}

}  // namespace td
