//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/NewPasswordState.h"

namespace td {

Result<NewPasswordState> get_new_password_state(tl_object_ptr<telegram_api::PasswordKdfAlgo> new_algo,
                                                tl_object_ptr<telegram_api::SecurePasswordKdfAlgo> new_secure_algo) {
  NewPasswordState state;
  CHECK(new_algo != nullptr);
  switch (new_algo->get_id()) {
    case telegram_api::passwordKdfAlgoUnknown::ID:
      return Status::Error(400, "Please update client to continue");
    case telegram_api::passwordKdfAlgoSHA256SHA256PBKDF2HMACSHA512iter100000SHA256ModPow::ID: {
      auto algo =
          move_tl_object_as<telegram_api::passwordKdfAlgoSHA256SHA256PBKDF2HMACSHA512iter100000SHA256ModPow>(new_algo);
      state.client_salt = algo->salt1_.as_slice().str();
      state.server_salt = algo->salt2_.as_slice().str();
      state.srp_g = algo->g_;
      state.srp_p = algo->p_.as_slice().str();
      break;
    }
    default:
      UNREACHABLE();
  }

  CHECK(new_secure_algo != nullptr);
  switch (new_secure_algo->get_id()) {
    case telegram_api::securePasswordKdfAlgoUnknown::ID:
      return Status::Error(400, "Please update client to continue");
    case telegram_api::securePasswordKdfAlgoSHA512::ID:
      return Status::Error(500, "Server has sent outdated secret encryption mode");
    case telegram_api::securePasswordKdfAlgoPBKDF2HMACSHA512iter100000::ID: {
      auto algo = move_tl_object_as<telegram_api::securePasswordKdfAlgoPBKDF2HMACSHA512iter100000>(new_secure_algo);
      state.secure_salt = algo->salt_.as_slice().str();
      break;
    }
    default:
      UNREACHABLE();
  }

  static constexpr size_t MIN_NEW_SECURE_SALT_SIZE = 8;
  if (state.secure_salt.size() < MIN_NEW_SECURE_SALT_SIZE) {
    return Status::Error(500, "New secure salt length too small");
  }

  static constexpr size_t MIN_NEW_SALT_SIZE = 8;
  if (state.client_salt.size() < MIN_NEW_SALT_SIZE) {
    return Status::Error(500, "New salt length too small");
  }
  return state;
}

}  // namespace td
