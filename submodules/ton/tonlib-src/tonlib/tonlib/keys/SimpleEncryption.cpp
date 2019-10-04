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
#include "SimpleEncryption.h"

#include "td/utils/Random.h"
#include "td/utils/SharedSlice.h"

namespace tonlib {
td::AesCbcState SimpleEncryption::calc_aes_cbc_state_hash(td::Slice hash) {
  CHECK(hash.size() == 64);
  td::SecureString key(32);
  key.as_mutable_slice().copy_from(hash.substr(0, 32));
  td::SecureString iv(16);
  iv.as_mutable_slice().copy_from(hash.substr(32, 16));
  return td::AesCbcState{key, iv};
}

td::AesCbcState SimpleEncryption::calc_aes_cbc_state_sha512(td::Slice seed) {
  td::SecureString hash(64);
  sha512(seed, hash.as_mutable_slice());
  return calc_aes_cbc_state_hash(hash.as_slice());
}
td::SecureString SimpleEncryption::gen_random_prefix(td::int64 data_size) {
  td::SecureString buff(td::narrow_cast<size_t>(((32 + 15 + data_size) & -16) - data_size), 0);
  td::Random::secure_bytes(buff.as_mutable_slice());
  buff.as_mutable_slice()[0] = td::narrow_cast<td::uint8>(buff.size());
  CHECK((buff.size() + data_size) % 16 == 0);
  return buff;
}

td::SecureString SimpleEncryption::combine_secrets(td::Slice a, td::Slice b) {
  td::SecureString res(64, 0);
  hmac_sha512(a, b, res.as_mutable_slice());
  return res;
}

td::SecureString SimpleEncryption::kdf(td::Slice secret, td::Slice password, int iterations) {
  td::SecureString new_secret(64);
  pbkdf2_sha512(secret, password, iterations, new_secret.as_mutable_slice());
  return new_secret;
}

td::SecureString SimpleEncryption::encrypt_data_with_prefix(td::Slice data, td::Slice secret) {
  CHECK(data.size() % 16 == 0);
  auto data_hash = sha256(data);

  td::SecureString res_buf(data.size() + 32, 0);
  auto res = res_buf.as_mutable_slice();
  res.copy_from(data_hash);

  auto cbc_state = calc_aes_cbc_state_hash(combine_secrets(data_hash, secret));
  cbc_state.encrypt(data, res.substr(32));

  return res_buf;
}

td::SecureString SimpleEncryption::encrypt_data(td::Slice data, td::Slice secret) {
  auto prefix = gen_random_prefix(data.size());
  td::SecureString combined(prefix.size() + data.size());
  combined.as_mutable_slice().copy_from(prefix);
  combined.as_mutable_slice().substr(prefix.size()).copy_from(data);
  return encrypt_data_with_prefix(combined.as_slice(), secret);
}

td::Result<td::SecureString> SimpleEncryption::decrypt_data(td::Slice encrypted_data, td::Slice secret) {
  if (encrypted_data.size() < 33) {
    return td::Status::Error("Failed to decrypt: data is too small");
  }
  if (encrypted_data.size() % 16 != 0) {
    return td::Status::Error("Failed to decrypt: data size is not divisible by 16");
  }
  auto data_hash = encrypted_data.substr(0, 32);
  encrypted_data = encrypted_data.substr(32);

  auto cbc_state = calc_aes_cbc_state_hash(combine_secrets(data_hash, secret));
  td::SecureString decrypted_data(encrypted_data.size(), 0);
  cbc_state.decrypt(encrypted_data, decrypted_data.as_mutable_slice());

  // check hash
  if (data_hash != td::sha256(decrypted_data)) {
    return td::Status::Error("Failed to decrypt: hash mismatch");
  }

  td::uint8 prefix_size = static_cast<td::uint8>(decrypted_data[0]);
  if (prefix_size > decrypted_data.size() || prefix_size < 32) {
    return td::Status::Error("Failed to decrypt: invalid prefix size");
  }

  return td::SecureString(decrypted_data.as_slice().substr(prefix_size));
}
}  // namespace tonlib
