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
#include "SimpleEncryption.h"

#include "td/utils/Random.h"
#include "td/utils/SharedSlice.h"

namespace tonlib {
td::AesCbcState SimpleEncryption::calc_aes_cbc_state_hash(td::Slice hash) {
  CHECK(hash.size() >= 48);
  td::SecureString key(32);
  key.as_mutable_slice().copy_from(hash.substr(0, 32));
  td::SecureString iv(16);
  iv.as_mutable_slice().copy_from(hash.substr(32, 16));
  return td::AesCbcState{key, iv};
}

td::AesCbcState SimpleEncryption::calc_aes_cbc_state_sha512(td::Slice seed) {
  td::SecureString hash(64);
  sha512(seed, hash.as_mutable_slice());
  return calc_aes_cbc_state_hash(hash.as_slice().substr(0, 48));
}

td::SecureString SimpleEncryption::gen_random_prefix(td::int64 data_size, td::int64 min_padding) {
  td::SecureString buff(td::narrow_cast<size_t>(((min_padding + 15 + data_size) & -16) - data_size), 0);
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
  auto prefix = gen_random_prefix(data.size(), 32);
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

td::Result<td::SecureString> SimpleEncryptionV2::encrypt_data(td::Slice data, const td::Ed25519::PublicKey &public_key,
                                                              td::Slice salt) {
  TRY_RESULT(tmp_private_key, td::Ed25519::generate_private_key());
  return encrypt_data(data, public_key, tmp_private_key, salt);
}

namespace {
td::SecureString secure_xor(td::Slice a, td::Slice b) {
  CHECK(a.size() == b.size());
  td::SecureString res(a.size());
  for (size_t i = 0; i < res.size(); i++) {
    res.as_mutable_slice()[i] = a[i] ^ b[i];
  }
  return res;
}
}  // namespace

td::Result<td::SecureString> SimpleEncryptionV2::encrypt_data(td::Slice data, const td::Ed25519::PublicKey &public_key,
                                                              const td::Ed25519::PrivateKey &private_key,
                                                              td::Slice salt) {
  TRY_RESULT(shared_secret, td::Ed25519::compute_shared_secret(public_key, private_key));
  auto encrypted = encrypt_data(data, shared_secret.as_slice(), salt);
  TRY_RESULT(tmp_public_key, private_key.get_public_key());
  td::SecureString prefixed_encrypted(tmp_public_key.LENGTH + encrypted.size());
  prefixed_encrypted.as_mutable_slice().copy_from(tmp_public_key.as_octet_string());
  auto xored_keys = secure_xor(public_key.as_octet_string().as_slice(), tmp_public_key.as_octet_string().as_slice());
  prefixed_encrypted.as_mutable_slice().copy_from(xored_keys.as_slice());
  prefixed_encrypted.as_mutable_slice().substr(xored_keys.size()).copy_from(encrypted);
  return std::move(prefixed_encrypted);
}

td::Result<SimpleEncryptionV2::Decrypted> SimpleEncryptionV2::decrypt_data(td::Slice data,
                                                                           const td::Ed25519::PrivateKey &private_key,
                                                                           td::Slice salt) {
  if (data.size() < td::Ed25519::PublicKey::LENGTH) {
    return td::Status::Error("Failed to decrypte: data is too small");
  }
  TRY_RESULT(public_key, private_key.get_public_key());
  auto tmp_public_key =
      td::Ed25519::PublicKey(secure_xor(data.substr(0, td::Ed25519::PublicKey::LENGTH), public_key.as_octet_string()));
  TRY_RESULT(shared_secret, td::Ed25519::compute_shared_secret(tmp_public_key, private_key));
  TRY_RESULT(decrypted, decrypt_data(data.substr(td::Ed25519::PublicKey::LENGTH), shared_secret.as_slice(), salt));
  return std::move(decrypted);
}

td::SecureString SimpleEncryptionV2::encrypt_data(td::Slice data, td::Slice secret, td::Slice salt) {
  auto prefix = SimpleEncryption::gen_random_prefix(data.size(), 16);
  td::SecureString combined(prefix.size() + data.size());
  combined.as_mutable_slice().copy_from(prefix);
  combined.as_mutable_slice().substr(prefix.size()).copy_from(data);
  return encrypt_data_with_prefix(combined.as_slice(), secret, salt);
}

td::Result<std::pair<td::Slice, td::Slice>> unpack_encrypted_data(td::Slice encrypted_data) {
  if (encrypted_data.size() < 17) {
    return td::Status::Error("Failed to decrypt: data is too small");
  }
  if (encrypted_data.size() % 16 != 0) {
    return td::Status::Error("Failed to decrypt: data size is not divisible by 16");
  }
  auto msg_key = encrypted_data.substr(0, 16);
  auto data = encrypted_data.substr(16);
  return std::make_pair(msg_key, data);
}

td::Result<td::SecureString> SimpleEncryptionV2::do_decrypt(td::Slice cbc_state_secret, td::Slice msg_key,
                                                            td::Slice encrypted_data, td::Slice salt) {
  auto cbc_state = SimpleEncryption::calc_aes_cbc_state_hash(cbc_state_secret);
  td::SecureString decrypted_data(encrypted_data.size(), 0);
  auto iv_copy = cbc_state.raw().key.copy();
  cbc_state.decrypt(encrypted_data, decrypted_data.as_mutable_slice());

  auto data_hash = SimpleEncryption::combine_secrets(salt, decrypted_data);
  auto got_msg_key = data_hash.as_slice().substr(0, 16);
  // check hash
  if (msg_key != got_msg_key) {
    return td::Status::Error("Failed to decrypt: hash mismatch");
  }

  td::uint8 prefix_size = static_cast<td::uint8>(decrypted_data[0]);
  if (prefix_size > decrypted_data.size() || prefix_size < 16) {
    return td::Status::Error("Failed to decrypt: invalid prefix size");
  }

  return td::SecureString(decrypted_data.as_slice().substr(prefix_size));
}

td::Result<SimpleEncryptionV2::Decrypted> SimpleEncryptionV2::decrypt_data(td::Slice encrypted_data, td::Slice secret,
                                                                           td::Slice salt) {
  TRY_RESULT(p, unpack_encrypted_data(encrypted_data));
  auto msg_key = p.first;
  auto data = p.second;
  auto cbc_state_secret = td::SecureString(SimpleEncryption::combine_secrets(secret, msg_key).as_slice().substr(0, 48));
  TRY_RESULT(res, do_decrypt(cbc_state_secret.as_slice(), msg_key, data, salt));
  return Decrypted{std::move(cbc_state_secret), std::move(res)};
}

td::Result<td::SecureString> SimpleEncryptionV2::decrypt_data_with_proof(td::Slice encrypted_data, td::Slice proof,
                                                                         td::Slice salt) {
  if (encrypted_data.size() < td::Ed25519::PublicKey::LENGTH) {
    return td::Status::Error("Failed to decrypte: data is too small");
  }
  if (proof.size() != 48) {
    return td::Status::Error("Invalid proof size");
  }
  encrypted_data = encrypted_data.substr(td::Ed25519::PublicKey::LENGTH);
  TRY_RESULT(p, unpack_encrypted_data(encrypted_data));
  auto msg_key = p.first;
  auto data = p.second;
  return do_decrypt(proof, msg_key, data, salt);
}

td::SecureString SimpleEncryptionV2::encrypt_data_with_prefix(td::Slice data, td::Slice secret, td::Slice salt) {
  CHECK(data.size() % 16 == 0);
  auto data_hash = SimpleEncryption::combine_secrets(salt, data);
  auto msg_key = data_hash.as_slice().substr(0, 16);

  td::SecureString res_buf(data.size() + 16, 0);
  auto res = res_buf.as_mutable_slice();
  res.copy_from(msg_key);

  auto cbc_state = SimpleEncryption::calc_aes_cbc_state_hash(SimpleEncryption::combine_secrets(secret, msg_key));
  cbc_state.encrypt(data, res.substr(16));

  return res_buf;
}
}  // namespace tonlib
