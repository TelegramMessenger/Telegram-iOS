//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/Status.h"

namespace td {

class UserPrivacySetting {
 public:
  enum class Type : int32 {
    UserStatus,
    ChatInvite,
    Call,
    PeerToPeerCall,
    LinkInForwardedMessages,
    UserProfilePhoto,
    UserPhoneNumber,
    FindByPhoneNumber,
    VoiceMessages,
    UserBio,
    UserBirthdate,
    StarGiftAutosave,
    NoPaidMessages,
    Size
  };

  explicit UserPrivacySetting(const telegram_api::PrivacyKey &key);

  static Result<UserPrivacySetting> get_user_privacy_setting(td_api::object_ptr<td_api::UserPrivacySetting> key);

  td_api::object_ptr<td_api::UserPrivacySetting> get_user_privacy_setting_object() const;

  telegram_api::object_ptr<telegram_api::InputPrivacyKey> get_input_privacy_key() const;

  Type type() const {
    return type_;
  }

 private:
  Type type_;

  explicit UserPrivacySetting(const td_api::UserPrivacySetting &key);
};

}  // namespace td
