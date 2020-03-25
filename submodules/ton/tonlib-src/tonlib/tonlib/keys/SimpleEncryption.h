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

    Copyright 2017-2020 Telegram Systems LLP
*/
#pragma once

#include "td/utils/crypto.h"
#include "td/utils/Slice.h"
#include "td/utils/SharedSlice.h"
#include "crypto/Ed25519.h"

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
  static td::SecureString gen_random_prefix(td::int64 data_size, td::int64 min_padding);

  static td::SecureString encrypt_data_with_prefix(td::Slice data, td::Slice secret);

  friend class SimpleEncryptionV2;
};

class SimpleEncryptionV2 {
 public:
  static td::Result<td::SecureString> encrypt_data(td::Slice data, const td::Ed25519::PublicKey &public_key,
                                                   td::Slice salt = {});
  struct Decrypted {
    td::SecureString proof;
    td::SecureString data;
  };

  static td::Result<Decrypted> decrypt_data(td::Slice data, const td::Ed25519::PrivateKey &private_key,
                                            td::Slice sallt = {});
  static td::Result<td::SecureString> encrypt_data(td::Slice data, const td::Ed25519::PublicKey &public_key,
                                                   const td::Ed25519::PrivateKey &private_key, td::Slice salt = {});

  static td::Result<td::SecureString> decrypt_data_with_proof(td::Slice encrypted_data, td::Slice proof,
                                                              td::Slice salt = {});

  static td::SecureString encrypt_data(td::Slice data, td::Slice secret, td::Slice salt = {});
  static td::Result<Decrypted> decrypt_data(td::Slice encrypted_data, td::Slice secret, td::Slice salt = {});

 private:
  static td::SecureString encrypt_data_with_prefix(td::Slice data, td::Slice secret, td::Slice salt = {});
  static td::Result<td::SecureString> do_decrypt(td::Slice cbc_state_secret, td::Slice msg_key,
                                                 td::Slice encrypted_data, td::Slice salt);
};
}  // namespace tonlib
