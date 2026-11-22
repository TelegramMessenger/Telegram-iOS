//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/e2e/e2e_api.h"
#include "td/e2e/e2e_errors.h"
#include "td/e2e/Keys.h"

#include "td/utils/as.h"
#include "td/utils/int_types.h"
#include "td/utils/Random.h"
#include "td/utils/SharedSlice.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Status.h"
#include "td/utils/tl_helpers.h"
#include "td/utils/tl_storers.h"
#include "td/utils/UInt.h"

#include <string>
#include <utility>

namespace tde2e_api {

inline Error to_error(const td::Status &status) {
  auto error_code = ErrorCode(status.code());
  if (error_string(error_code) == "UNKNOWN_ERROR") {
    return Error{ErrorCode::UnknownError, status.message().str()};
  }
  return Error{error_code, status.message().str()};
}

template <class T>
Result<T> to_result(td::Result<T> &value) {
  if (value.is_ok()) {
    return Result<T>(value.move_as_ok());
  }
  return Result<T>(to_error(value.error()));
}

template <typename T>
Result<T>::Result(td::Result<T> &&value) : Result(to_result(value)) {
}

template <typename T>
Result<T>::Result(td::Status &&status) : Result(to_error(status)) {
}

}  // namespace tde2e_api

namespace tde2e_core {

using E = tde2e_api::ErrorCode;

inline td::Status Error(E error_code) {
  auto msg = tde2e_api::error_string(error_code);
  return td::Status::Error(static_cast<int>(error_code), td::Slice(msg.data(), msg.size()));
}

inline td::Status Error(E error_code, td::Slice message) {
  auto msg = tde2e_api::error_string(error_code);
  return td::Status::Error(static_cast<int>(error_code), PSLICE()
                                                             << td::Slice(msg.data(), msg.size()) << ": " << message);
}

template <typename T, typename = void>
constexpr bool has_static_ID = false;

template <typename T>
constexpr bool has_static_ID<T, decltype((void)T::ID, void())> = true;

template <class T>
std::string serialize_boxed(const T &object) {
  if constexpr (has_static_ID<T>) {
    auto suffix = serialize(object);
    std::string result(4 + suffix.size(), 0);
    td::TlStorerUnsafe storer(td::MutableSlice(result).ubegin());
    storer.store_int(T::ID);
    storer.store_slice(suffix);
    return result;
  } else {
    return td::serialize(object);
  }
}

template <class T>
td::SecureString serialize_boxed_secure(const T &object) {
  if constexpr (has_static_ID<T>) {
    auto suffix = td::serialize_secure(object);
    td::SecureString result(4 + suffix.size(), 0);
    td::TlStorerUnsafe storer(result.as_mutable_slice().ubegin());
    storer.store_int(T::ID);
    storer.store_slice(suffix);
    return result;
  } else {
    return td::serialize_secure(object);
  }
}

struct UInt256Hash {
  td::uint32 operator()(const td::UInt256 v) const {
    return td::as<td::uint32>(v.raw);
  }
};

inline td::UInt256 generate_nonce() {
  td::UInt256 nonce;
  td::Random::secure_bytes(nonce.as_mutable_slice());
  return nonce;
}

template <class T>
td::Status verify_signature(const PublicKey &public_key, T &signed_tl_object) {
  auto signature = signed_tl_object.signature_;
  signed_tl_object.signature_ = {};
  auto to_sign = serialize_boxed(signed_tl_object);
  auto result = public_key.verify(to_sign, Signature::from_u512(signature));
  signed_tl_object.signature_ = signature;
  if (result.is_error()) {
    return Error(E::InvalidBlock_InvalidSignature, result.message());
  }
  return result;
}

template <class T>
td::Result<Signature> sign(const PrivateKey &private_key, T &unsigned_tl_object) {
  unsigned_tl_object.signature_ = {};
  auto to_sign = serialize_boxed(unsigned_tl_object);
  return private_key.sign(to_sign);
}

template <class T>
td::Result<T> to_td(tde2e_api::Result<T> &&r) {
  if (r.is_ok()) {
    return std::move(r.value());
  }
  return td::Status::Error(static_cast<int>(r.error().code), r.error().message);
}

inline td::Status to_td(tde2e_api::Result<tde2e_api::Ok> &r) {
  if (r.is_ok()) {
    return td::Status::OK();
  }
  return td::Status::Error(static_cast<int>(r.error().code), r.error().message);
}

}  // namespace tde2e_core
