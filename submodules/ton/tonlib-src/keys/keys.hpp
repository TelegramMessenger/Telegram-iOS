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

#include "td/utils/int_types.h"
#include "td/utils/buffer.h"
#include "auto/tl/ton_api.h"
#include "td/utils/UInt.h"
#include "td/utils/Variant.h"
#include "td/actor/actor.h"
#include "crypto/common/bitstring.h"
#include "crypto/Ed25519.h"
#include "common/errorcode.h"

namespace ton {

class Encryptor;
class EncryptorAsync;
class Decryptor;
class DecryptorAsync;

class PublicKeyHash {
 public:
  explicit PublicKeyHash(td::Bits256 value) : value_(value) {
  }
  explicit PublicKeyHash(const tl_object_ptr<ton_api::PublicKey> &value);
  PublicKeyHash() {
  }
  static PublicKeyHash zero() {
    return PublicKeyHash{td::Bits256::zero()};
  }
  explicit PublicKeyHash(td::Slice data) {
    CHECK(data.size() == 32);
    value_.as_slice().copy_from(data);
  }

  td::UInt256 uint256_value() const {
    td::UInt256 x;
    x.as_slice().copy_from(value_.as_slice());
    return x;
  }
  td::Bits256 bits256_value() const {
    return value_;
  }
  auto tl() const {
    return value_;
  }

  bool operator<(const PublicKeyHash &with) const {
    return value_ < with.value_;
  }
  bool operator==(const PublicKeyHash &with) const {
    return value_ == with.value_;
  }
  bool operator!=(const PublicKeyHash &with) const {
    return value_ != with.value_;
  }
  td::Slice as_slice() const {
    return td::as_slice(value_);
  }
  bool is_zero() const {
    return value_.is_zero();
  }

 private:
  td::Bits256 value_;
};

namespace pubkeys {

class Ed25519 {
 private:
  td::Bits256 data_;

 public:
  Ed25519(const ton_api::pub_ed25519 &obj) {
    data_ = obj.key_;
  }
  Ed25519(td::Bits256 id) : data_(id) {
  }
  Ed25519() {
  }
  Ed25519(td::Ed25519::PublicKey pk);
  td::Ed25519::PublicKey export_key() {
    return td::Ed25519::PublicKey{td::SecureString(data_.as_slice())};
  }

  auto raw() const {
    return data_;
  }
  td::uint32 serialized_size() const {
    return 36;
  }
  tl_object_ptr<ton_api::pub_ed25519> tl() const {
    return create_tl_object<ton_api::pub_ed25519>(data_);
  }
  bool operator==(const Ed25519 &with) const {
    return data_ == with.data_;
  }
  bool operator!=(const Ed25519 &with) const {
    return data_ != with.data_;
  }
};

class AES {
 private:
  td::Bits256 data_;

 public:
  ~AES() {
    data_.set_zero_s();
  }
  AES(const ton_api::pub_aes &obj) {
    data_ = obj.key_;
  }
  AES(td::Slice data) {
    CHECK(data.size() == 32);
    data_.as_slice().copy_from(data);
  }
  AES(td::Bits256 data) : data_(data) {
  }
  td::uint32 serialized_size() const {
    return 36;
  }
  tl_object_ptr<ton_api::pub_aes> tl() const {
    return create_tl_object<ton_api::pub_aes>(data_);
  }
  bool operator==(const AES &with) const {
    return data_ == with.data_;
  }
  bool operator!=(const AES &with) const {
    return data_ != with.data_;
  }
};

class Unenc {
 private:
  td::SharedSlice data_;

 public:
  Unenc(const ton_api::pub_unenc &obj) {
    data_ = td::SharedSlice{obj.data_.as_slice()};
  }
  Unenc(const Unenc &obj) {
    data_ = obj.data_.clone();
  }
  explicit Unenc(td::BufferSlice data) : data_(td::SharedSlice{data.as_slice()}) {
  }
  explicit Unenc(td::Slice data) : data_(td::SharedSlice{data}) {
  }
  explicit Unenc(td::SharedSlice data) : data_(std::move(data)) {
  }
  td::uint32 serialized_size() const {
    return static_cast<td::uint32>(data_.size()) + 8;
  }
  tl_object_ptr<ton_api::pub_unenc> tl() const {
    return create_tl_object<ton_api::pub_unenc>(data_.clone_as_buffer_slice());
  }
  bool operator==(const Unenc &with) const {
    return data_.as_slice() == with.data_.as_slice();
  }
  bool operator!=(const Unenc &with) const {
    return data_.as_slice() != with.data_.as_slice();
  }
};  // namespace pubkeys

class Overlay {
 private:
  td::SharedSlice data_;

 public:
  Overlay(const ton_api::pub_overlay &obj) {
    data_ = td::SharedSlice{obj.name_.as_slice()};
  }
  Overlay(const Overlay &obj) {
    data_ = obj.data_.clone();
  }
  explicit Overlay(td::BufferSlice data) : data_(td::SharedSlice{data.as_slice()}) {
  }
  explicit Overlay(td::Slice data) : data_(td::SharedSlice{data}) {
  }
  explicit Overlay(td::SharedSlice data) : data_(std::move(data)) {
  }
  td::uint32 serialized_size() const {
    return static_cast<td::uint32>(data_.size()) + 8;
  }
  tl_object_ptr<ton_api::pub_overlay> tl() const {
    return create_tl_object<ton_api::pub_overlay>(data_.clone_as_buffer_slice());
  }
  bool operator==(const Overlay &with) const {
    return data_.as_slice() == with.data_.as_slice();
  }
  bool operator!=(const Overlay &with) const {
    return data_.as_slice() != with.data_.as_slice();
  }
};

}  // namespace pubkeys

class PublicKey {
 private:
  class Empty {
   public:
    tl_object_ptr<ton_api::PublicKey> tl() const {
      UNREACHABLE();
    }
    td::uint32 serialized_size() const {
      UNREACHABLE();
    }
    bool operator==(const Empty &with) const {
      return false;
    }
    bool operator!=(const Empty &with) const {
      return true;
    }
  };
  td::Variant<Empty, pubkeys::Ed25519, pubkeys::AES, pubkeys::Unenc, pubkeys::Overlay> pub_key_{Empty{}};

 public:
  explicit PublicKey(const tl_object_ptr<ton_api::PublicKey> &id);
  PublicKey() {
  }
  PublicKey(pubkeys::Ed25519 pub) : pub_key_(std::move(pub)) {
  }
  PublicKey(pubkeys::AES pub) : pub_key_(std::move(pub)) {
  }
  PublicKey(pubkeys::Unenc pub) : pub_key_(std::move(pub)) {
  }
  PublicKey(pubkeys::Overlay pub) : pub_key_(std::move(pub)) {
  }

  bool empty() const;

  PublicKeyHash compute_short_id() const;
  td::uint32 serialized_size() const;
  tl_object_ptr<ton_api::PublicKey> tl() const;
  td::BufferSlice export_as_slice() const;
  static td::Result<PublicKey> import(td::Slice s);

  pubkeys::Ed25519 ed25519_value() const {
    CHECK(pub_key_.get_offset() == pub_key_.offset<pubkeys::Ed25519>());
    return pub_key_.get<pubkeys::Ed25519>();
  }

  td::Result<std::unique_ptr<Encryptor>> create_encryptor() const;
  td::Result<td::actor::ActorOwn<EncryptorAsync>> create_encryptor_async() const;

  bool operator==(const PublicKey &with) const {
    return pub_key_ == with.pub_key_;
  }
  bool operator!=(const PublicKey &with) const {
    return !(pub_key_ == with.pub_key_);
  }
};

namespace privkeys {

class Ed25519 {
 private:
  td::Bits256 data_;

 public:
  ~Ed25519() {
    data_.set_zero_s();
  }
  Ed25519(const ton_api::pk_ed25519 &obj) {
    data_ = obj.key_;
  }
  Ed25519(td::Bits256 id) : data_(id) {
    id.set_zero_s();
  }
  Ed25519(td::Slice data) {
    CHECK(data.size() == 32);
    data_.as_slice().copy_from(data);
  }
  Ed25519() {
  }
  Ed25519(td::Ed25519::PrivateKey pk);
  td::Ed25519::PrivateKey export_key() {
    return td::Ed25519::PrivateKey{td::SecureString(data_.as_slice())};
  }
  td::SecureString export_as_slice() const {
    td::SecureString s{36};
    auto id = ton_api::pk_ed25519::ID;
    s.as_mutable_slice().copy_from(td::Slice{reinterpret_cast<const td::uint8 *>(&id), 4});
    s.as_mutable_slice().remove_prefix(4).copy_from(data_.as_slice());
    return s;
  }
  bool exportable() const {
    return true;
  }
  static td::Result<Ed25519> import(td::Slice slice) {
    if (slice.size() != 32) {
      return td::Status::Error(ErrorCode::error, "bad length");
    }
    return Ed25519{slice};
  }
  tl_object_ptr<ton_api::pk_ed25519> tl() const {
    return create_tl_object<ton_api::pk_ed25519>(data_);
  }
  tl_object_ptr<ton_api::PublicKey> pub_tl() const;
  pubkeys::Ed25519 pub() const;
  static Ed25519 random();
};

class AES {
 private:
  td::Bits256 data_;

 public:
  ~AES() {
    data_.set_zero_s();
  }
  AES(const ton_api::pk_aes &obj) {
    data_ = obj.key_;
  }
  AES(td::Slice data) {
    CHECK(data.size() == 32);
    data_.as_slice().copy_from(data);
  }
  td::SecureString export_as_slice() const {
    td::SecureString s{40};
    auto id = ton_api::pk_aes::ID;
    s.as_mutable_slice().copy_from(td::Slice{reinterpret_cast<const td::uint8 *>(&id), 4});
    s.as_mutable_slice().remove_prefix(4).copy_from(data_.as_slice());
    return s;
  }
  bool exportable() const {
    return true;
  }
  static td::Result<AES> import(td::Slice slice) {
    if (slice.size() != 32) {
      return td::Status::Error(ErrorCode::error, "bad length");
    }
    return AES{slice};
  }
  tl_object_ptr<ton_api::pk_aes> tl() const {
    return create_tl_object<ton_api::pk_aes>(data_);
  }
  tl_object_ptr<ton_api::PublicKey> pub_tl() const {
    return create_tl_object<ton_api::pub_aes>(data_);
  }
  pubkeys::AES pub() const {
    return pubkeys::AES{data_};
  }
};

class Unenc {
 private:
  td::SharedSlice data_;

 public:
  Unenc(const ton_api::pk_unenc &obj) {
    data_ = td::SharedSlice{obj.data_.as_slice()};
  }
  Unenc(const Unenc &obj) {
    data_ = obj.data_.clone();
  }
  explicit Unenc(td::BufferSlice data) : data_(td::SharedSlice{data.as_slice()}) {
  }
  explicit Unenc(td::Slice data) : data_(td::SharedSlice{data}) {
  }
  explicit Unenc(td::SharedSlice data) : data_(std::move(data)) {
  }
  td::SecureString export_as_slice() const {
    UNREACHABLE();
  }
  bool exportable() const {
    return false;
  }
  tl_object_ptr<ton_api::pk_unenc> tl() const {
    return create_tl_object<ton_api::pk_unenc>(data_.clone_as_buffer_slice());
  }
  tl_object_ptr<ton_api::PublicKey> pub_tl() const {
    return create_tl_object<ton_api::pub_unenc>(data_.clone_as_buffer_slice());
  }
  pubkeys::Unenc pub() const {
    return pubkeys::Unenc{data_.clone()};
  }
};

class Overlay {
 private:
  td::SharedSlice data_;

 public:
  Overlay(const ton_api::pk_overlay &obj) {
    data_ = td::SharedSlice{obj.name_.as_slice()};
  }
  Overlay(const Overlay &obj) {
    data_ = obj.data_.clone();
  }
  explicit Overlay(td::BufferSlice data) : data_(td::SharedSlice{data.as_slice()}) {
  }
  explicit Overlay(td::Slice data) : data_(td::SharedSlice{data}) {
  }
  explicit Overlay(td::SharedSlice data) : data_(std::move(data)) {
  }
  td::SecureString export_as_slice() const {
    UNREACHABLE();
  }
  bool exportable() const {
    return false;
  }
  tl_object_ptr<ton_api::pk_overlay> tl() const {
    return create_tl_object<ton_api::pk_overlay>(data_.clone_as_buffer_slice());
  }
  tl_object_ptr<ton_api::PublicKey> pub_tl() const {
    return create_tl_object<ton_api::pub_overlay>(data_.clone_as_buffer_slice());
  }
  pubkeys::Overlay pub() const {
    return pubkeys::Overlay{data_.clone()};
  }
};

}  // namespace privkeys

class PrivateKey {
 private:
  class Empty {
   public:
    td::SecureString export_as_slice() const {
      UNREACHABLE();
    }
    bool exportable() const {
      return false;
    }
    tl_object_ptr<ton_api::PrivateKey> tl() const {
      UNREACHABLE();
    }
    tl_object_ptr<ton_api::PublicKey> pub_tl() const {
      UNREACHABLE();
    }
    PublicKey pub() const {
      UNREACHABLE();
    }
  };
  td::Variant<Empty, privkeys::Ed25519, privkeys::AES, privkeys::Unenc, privkeys::Overlay> priv_key_{Empty{}};

 public:
  explicit PrivateKey(const tl_object_ptr<ton_api::PrivateKey> &pk);
  template <class T>
  PrivateKey(T key) : priv_key_(std::move(key)) {
  }
  PrivateKey() {
  }

  bool empty() const;

  PublicKey compute_public_key() const;
  PublicKeyHash compute_short_id() const;
  td::SecureString export_as_slice() const;
  static td::Result<PrivateKey> import(td::Slice s);
  bool exportable() const;
  tl_object_ptr<ton_api::PrivateKey> tl() const;

  td::Result<std::unique_ptr<Decryptor>> create_decryptor() const;
  td::Result<td::actor::ActorOwn<DecryptorAsync>> create_decryptor_async() const;
};

}  // namespace ton
