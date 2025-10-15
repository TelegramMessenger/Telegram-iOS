//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/mtproto/AuthKey.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

enum class AuthKeyState : int32 { Empty, NoAuth, OK };

inline AuthKeyState get_auth_key_state(const mtproto::AuthKey &auth_key) {
  if (auth_key.empty()) {
    return AuthKeyState::Empty;
  } else if (auth_key.auth_flag()) {
    return AuthKeyState::OK;
  } else {
    return AuthKeyState::NoAuth;
  }
}

inline StringBuilder &operator<<(StringBuilder &sb, AuthKeyState state) {
  switch (state) {
    case AuthKeyState::Empty:
      return sb << "Empty";
    case AuthKeyState::NoAuth:
      return sb << "NoAuth";
    case AuthKeyState::OK:
      return sb << "OK";
    default:
      return sb << "Unknown AuthKeyState";
  }
}

}  // namespace td
