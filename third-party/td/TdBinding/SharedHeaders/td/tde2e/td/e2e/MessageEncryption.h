//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/crypto.h"
#include "td/utils/SharedSlice.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"

namespace tde2e_core {

class MessageEncryption {
 public:
  static td::SecureString encrypt_data(td::Slice data, td::Slice secret);
  static td::Result<td::SecureString> decrypt_data(td::Slice encrypted_data, td::Slice secret);
  static td::SecureString combine_secrets(td::Slice a, td::Slice b);
  static td::SecureString kdf(td::Slice secret, td::Slice password, int iterations);
  static td::SecureString encrypt_header(td::Slice decrypted_header, td::Slice encrypted_message, td::Slice secret);
  static td::Result<td::SecureString> decrypt_header(td::Slice encrypted_header, td::Slice encrypted_message,
                                                     td::Slice secret);

 private:
  static td::AesCbcState calc_aes_cbc_state_from_hash(td::Slice hash);
  static td::AesCbcState calc_aes_cbc_state_from_secret(td::Slice seed);
  static td::SecureString gen_random_prefix(td::int64 data_size, td::int64 min_padding);

  static td::SecureString encrypt_data_with_prefix(td::Slice data, td::Slice secret);

  friend class SimpleEncryptionV2;
};

}  // namespace tde2e_core
