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
#include "keys.hpp"
#include "auto/tl/ton_api.hpp"
#include "td/utils/overloaded.h"
#include "tl-utils/tl-utils.hpp"
#include "encryptor.h"
#include "crypto/Ed25519.h"

namespace ton {

PublicKeyHash::PublicKeyHash(const tl_object_ptr<ton_api::PublicKey> &value) {
  value_ = get_tl_object_sha_bits256(value);
}

PublicKey::PublicKey(const tl_object_ptr<ton_api::PublicKey> &id) {
  ton_api::downcast_call(
      *const_cast<ton_api::PublicKey *>(id.get()),
      td::overloaded([&](const ton_api::pub_ed25519 &obj) { this->pub_key_ = pubkeys::Ed25519{obj}; },
                     [&](const ton_api::pub_aes &obj) { this->pub_key_ = pubkeys::AES{obj}; },
                     [&](const ton_api::pub_unenc &obj) { this->pub_key_ = pubkeys::Unenc{obj}; },
                     [&](const ton_api::pub_overlay &obj) { this->pub_key_ = pubkeys::Overlay{obj}; }));
}

PublicKeyHash PublicKey::compute_short_id() const {
  return PublicKeyHash{get_tl_object_sha_bits256(tl())};
}

td::uint32 PublicKey::serialized_size() const {
  td::uint32 res = 0;
  pub_key_.visit([&](auto &obj) { res = obj.serialized_size(); });
  return res;
}

tl_object_ptr<ton_api::PublicKey> PublicKey::tl() const {
  tl_object_ptr<ton_api::PublicKey> res;
  pub_key_.visit([&](auto &obj) { res = obj.tl(); });
  return res;
}

td::BufferSlice PublicKey::export_as_slice() const {
  return serialize_tl_object(tl(), true);
}

td::Result<PublicKey> PublicKey::import(td::Slice s) {
  TRY_RESULT(x, fetch_tl_object<ton_api::PublicKey>(s, true));
  return PublicKey{x};
}

td::Result<std::unique_ptr<Encryptor>> PublicKey::create_encryptor() const {
  return Encryptor::create(tl().get());
}

td::Result<td::actor::ActorOwn<EncryptorAsync>> PublicKey::create_encryptor_async() const {
  return EncryptorAsync::create(tl().get());
}

bool PublicKey::empty() const {
  return pub_key_.get_offset() == pub_key_.offset<Empty>();
}

tl_object_ptr<ton_api::PublicKey> privkeys::Ed25519::pub_tl() const {
  td::Ed25519::PrivateKey pkey(td::SecureString(as_slice(data_)));
  auto r_public_key = pkey.get_public_key();
  if (r_public_key.is_error()) {
    return nullptr;
  } else {
    auto public_key = r_public_key.ok().as_octet_string();
    td::Bits256 X;
    as_slice(X).copy_from(public_key);
    return create_tl_object<ton_api::pub_ed25519>(X);
  }
}

pubkeys::Ed25519 privkeys::Ed25519::pub() const {
  td::Ed25519::PrivateKey pkey(td::SecureString(as_slice(data_)));
  return pubkeys::Ed25519{pkey.get_public_key().move_as_ok()};
}

privkeys::Ed25519 privkeys::Ed25519::random() {
  while (true) {
    auto key = td::Ed25519::generate_private_key();
    if (key.is_error()) {
      LOG(WARNING) << "failed to generate private key: " << key.move_as_error();
    }
    return Ed25519{key.move_as_ok()};
  }
}

privkeys::Ed25519::Ed25519(td::Ed25519::PrivateKey key) {
  auto s = key.as_octet_string();
  CHECK(s.length() == 32);
  data_.as_slice().copy_from(td::Slice(s));
}

pubkeys::Ed25519::Ed25519(td::Ed25519::PublicKey key) {
  auto s = key.as_octet_string();
  CHECK(s.length() == 32);
  data_.as_slice().copy_from(td::Slice(s));
}

PrivateKey::PrivateKey(const tl_object_ptr<ton_api::PrivateKey> &id) {
  ton_api::downcast_call(
      *const_cast<ton_api::PrivateKey *>(id.get()),
      td::overloaded([&](const ton_api::pk_ed25519 &obj) { this->priv_key_ = privkeys::Ed25519{obj}; },
                     [&](const ton_api::pk_aes &obj) { this->priv_key_ = privkeys::AES{obj}; },
                     [&](const ton_api::pk_unenc &obj) { this->priv_key_ = privkeys::Unenc{obj}; },
                     [&](const ton_api::pk_overlay &obj) { this->priv_key_ = privkeys::Overlay{obj}; }));
}

bool PrivateKey::empty() const {
  return priv_key_.get_offset() == priv_key_.offset<Empty>();
}

PublicKey PrivateKey::compute_public_key() const {
  PublicKey res;
  priv_key_.visit([&](auto &obj) { res = obj.pub(); });
  return res;
}

PublicKeyHash PrivateKey::compute_short_id() const {
  tl_object_ptr<ton_api::PublicKey> res;
  priv_key_.visit([&](auto &obj) { res = obj.pub_tl(); });
  return PublicKeyHash{res};
}

td::SecureString PrivateKey::export_as_slice() const {
  td::SecureString res;
  priv_key_.visit([&](auto &obj) { res = obj.export_as_slice(); });
  return res;
}

bool PrivateKey::exportable() const {
  bool res;
  priv_key_.visit([&](auto &obj) { res = obj.exportable(); });
  return res;
}

td::Result<PrivateKey> PrivateKey::import(td::Slice s) {
  if (s.size() < 4) {
    return td::Status::Error(ErrorCode::protoviolation, "too short key");
  }
  td::int32 id;
  td::MutableSlice{reinterpret_cast<char *>(&id), 4}.copy_from(s.copy().truncate(4));
  s.remove_prefix(4);
  switch (id) {
    case ton_api::pk_ed25519::ID: {
      auto R = privkeys::Ed25519::import(s);
      if (R.is_error()) {
        return R.move_as_error();
      } else {
        return R.move_as_ok();
      }
    } break;
    case ton_api::pk_aes::ID: {
      auto R = privkeys::AES::import(s);
      if (R.is_error()) {
        return R.move_as_error();
      } else {
        return R.move_as_ok();
      }
    } break;
    default:
      return td::Status::Error(ErrorCode::protoviolation, PSTRING() << "unknown magic " << id);
  }
}

tl_object_ptr<ton_api::PrivateKey> PrivateKey::tl() const {
  tl_object_ptr<ton_api::PrivateKey> res;
  priv_key_.visit([&](auto &obj) { res = obj.tl(); });
  return res;
}

td::Result<std::unique_ptr<Decryptor>> PrivateKey::create_decryptor() const {
  return Decryptor::create(tl().get());
}

td::Result<td::actor::ActorOwn<DecryptorAsync>> PrivateKey::create_decryptor_async() const {
  return DecryptorAsync::create(tl().get());
}

}  // namespace ton
