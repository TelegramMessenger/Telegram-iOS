//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/e2e/utils.h"

#include "td/utils/optional.h"
#include "td/utils/SharedSlice.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"

namespace tde2e_core {

struct DecryptedKey;
struct EncryptedKey {
  static constexpr int PBKDF_ITERATIONS = 100000;
  static constexpr int PBKDF_FAST_ITERATIONS = 1;
  td::SecureString encrypted_data;
  td::optional<PublicKey> o_public_key;
  td::SecureString secret;

  td::Result<DecryptedKey> decrypt(td::Slice local_password, bool check_public_key = true) const;
};

}  // namespace tde2e_core
