//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/Status.h"

namespace td {

struct NewPasswordState {
  string client_salt;
  string server_salt;
  string srp_p;
  string secure_salt;
  int32 srp_g = 0;
};

Result<NewPasswordState> get_new_password_state(tl_object_ptr<telegram_api::PasswordKdfAlgo> new_algo,
                                                tl_object_ptr<telegram_api::SecurePasswordKdfAlgo> new_secure_algo);

}  // namespace td
