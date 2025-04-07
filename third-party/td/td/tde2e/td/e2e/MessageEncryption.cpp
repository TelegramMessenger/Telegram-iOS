//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/e2e/MessageEncryption.h"

#include "td/utils/common.h"
#include "td/utils/misc.h"
#include "td/utils/Random.h"
#include "td/utils/SharedSlice.h"

#include <utility>

namespace tde2e_core {

namespace {
constexpr size_t MIN_PADDING = 16;
}  // namespace

td::AesCbcState MessageEncryption::calc_aes_cbc_state_from_hash(td::Slice hash) {
  CHECK(hash.size() >= 48);
  td::SecureString key(32);
  key.as_mutable_slice().copy_from(hash.substr(0, 32));
  td::SecureString iv(16);
  iv.as_mutable_slice().copy_from(hash.substr(32, 16));
  return td::AesCbcState{key, iv};
}

td::SecureString MessageEncryption::gen_random_prefix(td::int64 data_size, td::int64 min_padding) {
  td::SecureString buff(
      td::narrow_cast<size_t>(((min_padding + 15 + data_size) & ~static_cast<td::int64>(15)) - data_size), '\0');
  td::Random::secure_bytes(buff.as_mutable_slice());
  buff.as_mutable_slice().ubegin()[0] = td::narrow_cast<td::uint8>(buff.size());
  CHECK((buff.size() + data_size) % 16 == 0);
  return buff;
}

td::SecureString MessageEncryption::gen_deterministic_prefix(td::int64 data_size, td::int64 min_padding) {
  td::SecureString buff(
      td::narrow_cast<size_t>(((min_padding + 15 + data_size) & ~static_cast<td::int64>(15)) - data_size), '\0');
  buff.as_mutable_slice().ubegin()[0] = td::narrow_cast<td::uint8>(buff.size());
  CHECK((buff.size() + data_size) % 16 == 0);
  return buff;
}

td::SecureString MessageEncryption::kdf(td::Slice secret, td::Slice password, int iterations) {
  td::SecureString new_secret(64);
  pbkdf2_sha512(secret, password, iterations, new_secret.as_mutable_slice());
  return new_secret;
}

td::SecureString MessageEncryption::encrypt_data_with_prefix(td::Slice data, td::Slice secret) {
  CHECK(data.size() % 16 == 0);
  auto large_secret = kdf_expand(secret, "tde2e_encrypt_data");
  auto encrypt_secret = large_secret.as_slice().substr(0, 32);
  auto hmac_secret = large_secret.as_mutable_slice().substr(32, 32);

  auto large_msg_id = hmac_sha512(hmac_secret, data);
  auto msg_id = large_msg_id.as_slice().substr(0, 16);

  td::SecureString res_buf(data.size() + 16, '\0');
  auto res = res_buf.as_mutable_slice();
  res.copy_from(msg_id);

  auto cbc_state = calc_aes_cbc_state_from_hash(hmac_sha512(encrypt_secret, msg_id));
  cbc_state.encrypt(data, res.substr(16));

  return res_buf;
}
td::SecureString MessageEncryption::kdf_expand(td::Slice random_secret, td::Slice info) {
  return hmac_sha512(random_secret, info);
}

td::SecureString MessageEncryption::encrypt_data(td::Slice data, td::Slice secret) {
  auto prefix = gen_random_prefix(data.size(), MIN_PADDING);
  td::SecureString combined(prefix.size() + data.size());
  combined.as_mutable_slice().copy_from(prefix);
  combined.as_mutable_slice().substr(prefix.size()).copy_from(data);
  return encrypt_data_with_prefix(combined.as_slice(), secret);
}

td::Result<td::SecureString> MessageEncryption::decrypt_data(td::Slice encrypted_data, td::Slice secret) {
  if (encrypted_data.size() < 16) {
    return td::Status::Error("Failed to decrypt: encrypted_data is less than 16 bytes");
  }
  if (encrypted_data.size() % 16 != 0) {
    return td::Status::Error("Failed to decrypt: data size is not divisible by 16");
  }

  auto large_secret = kdf_expand(secret, "tde2e_encrypt_data");
  auto encrypt_secret = large_secret.as_slice().substr(0, 32);
  auto hmac_secret = large_secret.as_mutable_slice().substr(32, 32);

  auto msg_id = encrypted_data.substr(0, 16);
  encrypted_data = encrypted_data.substr(16);

  auto cbc_state = calc_aes_cbc_state_from_hash(hmac_sha512(encrypt_secret, msg_id));
  td::SecureString decrypted_data(encrypted_data.size(), '\0');
  cbc_state.decrypt(encrypted_data, decrypted_data.as_mutable_slice());

  auto expected_large_msg_id = hmac_sha512(hmac_secret, decrypted_data);
  auto expected_msg_id = expected_large_msg_id.as_slice().substr(0, 16);

  // check hash
  int is_mac_bad = 0;
  for (size_t i = 0; i < 16; i++) {
    is_mac_bad |= expected_msg_id[i] ^ msg_id[i];
  }
  if (is_mac_bad != 0) {
    return td::Status::Error("Failed to decrypt: msg_id mismatch");
  }

  auto prefix_size = static_cast<td::uint8>(decrypted_data[0]);
  if (prefix_size > decrypted_data.size() || prefix_size < MIN_PADDING) {
    return td::Status::Error("Failed to decrypt: invalid prefix size");
  }

  return td::SecureString(decrypted_data.as_slice().substr(prefix_size));
}

td::SecureString MessageEncryption::hmac_sha512(td::Slice key, td::Slice message) {
  td::SecureString res(64, 0);
  td::hmac_sha512(key, message, res.as_mutable_slice());
  return res;
}

td::Result<td::SecureString> MessageEncryption::encrypt_header(td::Slice decrypted_header, td::Slice encrypted_message,
                                                               td::Slice secret) {
  if (encrypted_message.size() < 16) {
    return td::Status::Error("Failed to encrypt header: encrypted_message is too small");
  }
  if (decrypted_header.size() != 32) {
    return td::Status::Error("Failed to encrypt header: header must be 32 bytes");
  }
  auto large_key = kdf_expand(secret, "tde2e_encrypt_header");
  auto encryption_key = large_key.as_slice().substr(0, 32);

  auto msg_id = encrypted_message.substr(0, 16);
  auto cbc_state = calc_aes_cbc_state_from_hash(kdf_expand(encryption_key, msg_id));

  td::SecureString encrypted_header(32, 0);
  cbc_state.encrypt(decrypted_header, encrypted_header.as_mutable_slice());
  return encrypted_header;
}

td::Result<td::SecureString> MessageEncryption::decrypt_header(td::Slice encrypted_header, td::Slice encrypted_message,
                                                               td::Slice secret) {
  if (encrypted_message.size() < 16) {
    return td::Status::Error("Failed to decrypt: invalid message size");
  }
  if (encrypted_header.size() != 32) {
    return td::Status::Error("Failed to decrypt: invalid header size");
  }

  auto large_key = kdf_expand(secret, "tde2e_encrypt_header");
  auto encryption_key = large_key.as_slice().substr(0, 32);

  auto msg_id = encrypted_message.substr(0, 16);
  auto cbc_state = calc_aes_cbc_state_from_hash(hmac_sha512(encryption_key, msg_id));

  td::SecureString decrypted_header(32, 0);
  cbc_state.decrypt(encrypted_header, decrypted_header.as_mutable_slice());
  return decrypted_header;
}

}  // namespace tde2e_core
