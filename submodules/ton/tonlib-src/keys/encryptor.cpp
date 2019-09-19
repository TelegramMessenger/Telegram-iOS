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
#include "td/utils/crypto.h"
#include "td/utils/overloaded.h"

#include "encryptor.h"
#include "encryptor.hpp"
#include "auto/tl/ton_api.hpp"

#include "common/status.h"
#include "common/errorcode.h"
#include "keys.hpp"

namespace ton {

td::Result<std::unique_ptr<Encryptor>> Encryptor::create(const ton_api::PublicKey *id) {
  td::Result<std::unique_ptr<Encryptor>> res;
  ton_api::downcast_call(
      *const_cast<ton_api::PublicKey *>(id),
      td::overloaded([&](const ton_api::pub_unenc &obj) { res = std::make_unique<EncryptorNone>(); },
                     [&](const ton_api::pub_ed25519 &obj) { res = std::make_unique<EncryptorEd25519>(obj.key_); },
                     [&](const ton_api::pub_overlay &obj) { res = std::make_unique<EncryptorOverlay>(); },
                     [&](const ton_api::pub_aes &obj) { res = std::make_unique<EncryptorAES>(obj.key_); }));
  return res;
}

td::Result<std::unique_ptr<Decryptor>> Decryptor::create(const ton_api::PrivateKey *id) {
  td::Result<std::unique_ptr<Decryptor>> res;
  ton_api::downcast_call(
      *const_cast<ton_api::PrivateKey *>(id),
      td::overloaded([&](const ton_api::pk_unenc &obj) { res = std::make_unique<DecryptorNone>(); },
                     [&](const ton_api::pk_ed25519 &obj) { res = std::make_unique<DecryptorEd25519>(obj.key_); },
                     [&](const ton_api::pk_overlay &obj) { res = std::make_unique<DecryptorFail>(); },
                     [&](const ton_api::pk_aes &obj) { res = std::make_unique<DecryptorAES>(obj.key_); }));
  return res;
}

td::Result<td::BufferSlice> EncryptorEd25519::encrypt(td::Slice data) {
  TRY_RESULT_PREFIX(pk, td::Ed25519::generate_private_key(), "failed to generate private key: ");
  TRY_RESULT_PREFIX(pubkey, pk.get_public_key(), "failed to get public key from private: ");
  auto pubkey_str = pubkey.as_octet_string();

  td::BufferSlice msg(pubkey_str.size() + 32 + data.size());
  td::MutableSlice slice = msg.as_slice();
  slice.copy_from(pubkey_str);
  slice.remove_prefix(pubkey_str.size());

  TRY_RESULT_PREFIX(shared_secret, td::Ed25519::compute_shared_secret(pub_, pk), "failed to compute shared secret: ");

  td::MutableSlice digest = slice.substr(0, 32);
  slice.remove_prefix(32);
  td::sha256(data, digest);

  td::SecureString key(32);
  {
    auto S = key.as_mutable_slice();
    S.copy_from(td::Slice(shared_secret).truncate(16));
    S.remove_prefix(16);
    S.copy_from(digest.copy().remove_prefix(16).truncate(16));
  }

  td::SecureString iv(16);
  {
    auto S = iv.as_mutable_slice();
    S.copy_from(digest.copy().truncate(4));
    S.remove_prefix(4);
    S.copy_from(td::Slice(shared_secret).remove_prefix(20).truncate(12));
  }

  td::AesCtrState ctr;
  ctr.init(key, iv);
  ctr.encrypt(data, slice);

  return std::move(msg);
}

td::Status EncryptorEd25519::check_signature(td::Slice message, td::Slice signature) {
  return td::status_prefix(pub_.verify_signature(message, signature), "bad signature: ");
}

td::Result<td::BufferSlice> DecryptorEd25519::decrypt(td::Slice data) {
  if (data.size() < td::Ed25519::PublicKey::LENGTH + 32) {
    return td::Status::Error(ErrorCode::protoviolation, "message is too short");
  }

  td::Slice pub = data.substr(0, td::Ed25519::PublicKey::LENGTH);
  data.remove_prefix(td::Ed25519::PublicKey::LENGTH);

  td::Slice digest = data.substr(0, 32);
  data.remove_prefix(32);

  TRY_RESULT_PREFIX(shared_secret,
                    td::Ed25519::compute_shared_secret(td::Ed25519::PublicKey(td::SecureString(pub)), pk_),
                    "failed to generate shared secret: ");

  td::SecureString key(32);
  key.as_mutable_slice().copy_from(td::Slice(shared_secret).substr(0, 16));
  key.as_mutable_slice().substr(16).copy_from(digest.substr(16, 16));

  td::SecureString iv(16);
  iv.as_mutable_slice().copy_from(digest.substr(0, 4));
  iv.as_mutable_slice().substr(4).copy_from(td::Slice(shared_secret).substr(20, 12));

  td::BufferSlice res(data.size());

  td::AesCtrState ctr;
  ctr.init(key, iv);
  ctr.encrypt(data, res.as_slice());

  td::UInt256 real_digest;
  td::sha256(res.as_slice(), as_slice(real_digest));

  if (as_slice(real_digest) != digest) {
    return td::Status::Error(ErrorCode::protoviolation, "sha256 mismatch after decryption");
  }

  return std::move(res);
}

td::Result<td::BufferSlice> DecryptorEd25519::sign(td::Slice data) {
  TRY_RESULT_PREFIX(signature, pk_.sign(data), "failed to sign: ");
  return td::BufferSlice(signature);
}

td::Result<td::BufferSlice> EncryptorAES::encrypt(td::Slice data) {
  td::BufferSlice msg(32 + data.size());
  td::MutableSlice slice = msg.as_slice();

  td::MutableSlice digest = slice.substr(0, 32);
  slice.remove_prefix(32);
  td::sha256(data, digest);

  td::SecureString key(32);
  key.as_mutable_slice().copy_from(shared_secret_.as_slice().substr(0, 16));
  key.as_mutable_slice().substr(16).copy_from(digest.substr(16, 16));

  td::SecureString iv(16);
  iv.as_mutable_slice().copy_from(digest.substr(0, 4));
  iv.as_mutable_slice().substr(4).copy_from(shared_secret_.as_slice().substr(20, 12));

  td::AesCtrState ctr;
  ctr.init(key, iv);
  ctr.encrypt(data, slice);

  return std::move(msg);
}

td::Result<td::BufferSlice> DecryptorAES::decrypt(td::Slice data) {
  if (data.size() < 32) {
    return td::Status::Error(ErrorCode::protoviolation, "message is too short");
  }

  td::Slice digest = data.substr(0, 32);
  data.remove_prefix(32);

  td::SecureString key(32);
  key.as_mutable_slice().copy_from(shared_secret_.as_slice().substr(0, 16));
  key.as_mutable_slice().substr(16).copy_from(digest.substr(16, 16));

  td::SecureString iv(16);
  iv.as_mutable_slice().copy_from(digest.substr(0, 4));
  iv.as_mutable_slice().substr(4).copy_from(shared_secret_.as_slice().substr(20, 12));

  td::BufferSlice res(data.size());

  td::AesCtrState ctr;
  ctr.init(key, iv);
  ctr.encrypt(data, res.as_slice());

  td::UInt256 real_digest;
  td::sha256(res.as_slice(), as_slice(real_digest));

  if (as_slice(real_digest) != digest) {
    return td::Status::Error(ErrorCode::protoviolation, "sha256 mismatch after decryption");
  }

  return std::move(res);
}

std::vector<td::Result<td::BufferSlice>> Decryptor::sign_batch(std::vector<td::Slice> data) {
  std::vector<td::Result<td::BufferSlice>> r;
  r.resize(data.size());
  for (size_t i = 0; i < data.size(); i++) {
    r[i] = sign(data[i]);
  }
  return r;
}

}  // namespace ton
