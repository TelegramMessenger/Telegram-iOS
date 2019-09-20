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

#include "td/actor/actor.h"
#include "td/utils/buffer.h"
#include "td/utils/Status.h"
#include "td/actor/PromiseFuture.h"
#include "auto/tl/ton_api.h"

namespace ton {

class Encryptor {
 public:
  virtual td::Result<td::BufferSlice> encrypt(td::Slice data) = 0;
  virtual td::Status check_signature(td::Slice message, td::Slice signature) = 0;
  virtual ~Encryptor() = default;
  static td::Result<std::unique_ptr<Encryptor>> create(const ton_api::PublicKey *id);
};

class Decryptor {
 public:
  virtual td::Result<td::BufferSlice> decrypt(td::Slice data) = 0;
  virtual td::Result<td::BufferSlice> sign(td::Slice data) = 0;
  virtual std::vector<td::Result<td::BufferSlice>> sign_batch(std::vector<td::Slice> data);
  virtual ~Decryptor() = default;
  static td::Result<std::unique_ptr<Decryptor>> create(const ton_api::PrivateKey *id);
};

class EncryptorAsync : public td::actor::Actor {
 private:
  std::unique_ptr<Encryptor> encryptor_;

 public:
  EncryptorAsync(std::unique_ptr<Encryptor> encryptor) : encryptor_(std::move(encryptor)) {
  }
  void check_signature(td::BufferSlice data, td::BufferSlice signature, td::Promise<td::Unit> promise) {
    auto res = encryptor_->check_signature(data.as_slice(), signature.as_slice());
    if (res.is_ok()) {
      promise.set_value(td::Unit());
    } else {
      promise.set_error(res.move_as_error());
    }
  }
  void encrypt(td::BufferSlice data, td::Promise<td::BufferSlice> promise) {
    promise.set_result(encryptor_->encrypt(data.as_slice()));
  }
  template <class T>
  static td::Result<td::actor::ActorOwn<EncryptorAsync>> create(T &id) {
    TRY_RESULT(d, Encryptor::create(id));
    return td::actor::create_actor<EncryptorAsync>("encryptor", std::move(d));
  }
  template <class T>
  static td::Result<td::actor::ActorOwn<EncryptorAsync>> create(T *id) {
    TRY_RESULT(d, Encryptor::create(id));
    return td::actor::create_actor<EncryptorAsync>("encryptor", std::move(d));
  }
};

class DecryptorAsync : public td::actor::Actor {
 private:
  std::unique_ptr<Decryptor> decryptor_;

 public:
  DecryptorAsync(std::unique_ptr<Decryptor> decryptor) : decryptor_(std::move(decryptor)) {
  }
  auto decrypt(td::BufferSlice data) {
    return decryptor_->decrypt(data.as_slice());
  }
  auto sign(td::BufferSlice data) {
    return decryptor_->sign(data.as_slice());
  }
  auto sign_batch(std::vector<td::BufferSlice> data) {
    std::vector<td::Slice> v;
    v.resize(data.size());
    for (size_t i = 0; i < data.size(); i++) {
      v[i] = data[i].as_slice();
    }
    return decryptor_->sign_batch(v);
  }
  template <class T>
  static td::Result<td::actor::ActorOwn<DecryptorAsync>> create(T &id) {
    TRY_RESULT(d, Decryptor::create(id));
    return td::actor::create_actor<DecryptorAsync>("decryptor", std::move(d));
  }
  template <class T>
  static td::Result<td::actor::ActorOwn<DecryptorAsync>> create(T *id) {
    TRY_RESULT(d, Decryptor::create(id));
    return td::actor::create_actor<DecryptorAsync>("decryptor", std::move(d));
  }
};

}  // namespace ton
