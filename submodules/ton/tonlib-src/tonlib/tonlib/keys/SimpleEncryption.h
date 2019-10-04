/*
    This file is part of TON Blockchain Library.

    TON Blockchain Library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    TON Blockchain Library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with TON Blockchain Library.  If not, see <http://www.gnu.org/licenses/>.

    Copyright 2017-2019 Telegram Systems LLP
*/
#pragma once

#include "td/utils/crypto.h"
#include "td/utils/Slice.h"
#include "td/utils/SharedSlice.h"

namespace tonlib {
class SimpleEncryption {
 public:
  static td::SecureString encrypt_data(td::Slice data, td::Slice secret);
  static td::Result<td::SecureString> decrypt_data(td::Slice encrypted_data, td::Slice secret);
  static td::SecureString combine_secrets(td::Slice a, td::Slice b);
  static td::SecureString kdf(td::Slice secret, td::Slice password, int iterations);

 private:
  static td::AesCbcState calc_aes_cbc_state_hash(td::Slice hash);
  static td::AesCbcState calc_aes_cbc_state_sha512(td::Slice seed);
  static td::SecureString gen_random_prefix(td::int64 data_size);

  static td::SecureString encrypt_data_with_prefix(td::Slice data, td::Slice secret);
};
}  // namespace tonlib
