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
#include "tl/tl_object_parse.h"
#include "td/utils/tl_parsers.h"

#include "crypto/common/bitstring.h"

namespace ton {

template <class Tp>
td::BufferSlice serialize_tl_object(const tl_object_ptr<Tp> &T, bool boxed) {
  return serialize_tl_object(T.get(), boxed);
}

template <class Tp>
td::BufferSlice serialize_tl_object(const tl_object_ptr<Tp> &T, bool boxed, td::BufferSlice &&suffix) {
  return serialize_tl_object(T.get(), boxed, std::move(suffix));
}

template <class Tp>
td::BufferSlice serialize_tl_object(const tl_object_ptr<Tp> &T, bool boxed, td::Slice suffix) {
  return serialize_tl_object(T.get(), boxed, std::move(suffix));
}

template <class Tp>
td::UInt256 get_tl_object_sha256(const tl_object_ptr<Tp> &T) {
  return get_tl_object_sha256(T.get());
}

template <class Tp>
td::Bits256 get_tl_object_sha_bits256(const tl_object_ptr<Tp> &T) {
  return get_tl_object_sha_bits256(T.get());
}

template <typename T>
td::Result<tl_object_ptr<std::enable_if_t<std::is_constructible<T>::value, T>>> fetch_tl_object(
    const td::BufferSlice &data, bool boxed) {
  td::TlBufferParser p(&data);
  tl_object_ptr<T> R;
  if (boxed) {
    R = TlFetchBoxed<TlFetchObject<T>, T::ID>::parse(p);
  } else {
    R = move_tl_object_as<T>(T::fetch(p));
  }
  p.fetch_end();
  if (p.get_status().is_ok()) {
    return std::move(R);
  } else {
    return p.get_status();
  }
}

template <typename T>
td::Result<tl_object_ptr<std::enable_if_t<!std::is_constructible<T>::value, T>>> fetch_tl_object(
    const td::BufferSlice &data, bool boxed) {
  CHECK(boxed);
  td::TlBufferParser p(&data);
  tl_object_ptr<T> R;
  R = move_tl_object_as<T>(T::fetch(p));
  p.fetch_end();
  if (p.get_status().is_ok()) {
    return std::move(R);
  } else {
    return p.get_status();
  }
}

template <typename T>
td::Result<tl_object_ptr<std::enable_if_t<std::is_constructible<T>::value, T>>> fetch_tl_object(td::Slice data,
                                                                                                bool boxed) {
  td::TlParser p(data);
  tl_object_ptr<T> R;
  if (boxed) {
    R = TlFetchBoxed<TlFetchObject<T>, T::ID>::parse(p);
  } else {
    R = move_tl_object_as<T>(T::fetch(p));
  }
  p.fetch_end();
  if (p.get_status().is_ok()) {
    return std::move(R);
  } else {
    return p.get_status();
  }
}

template <typename T>
td::Result<tl_object_ptr<std::enable_if_t<!std::is_constructible<T>::value, T>>> fetch_tl_object(td::Slice data,
                                                                                                 bool boxed) {
  CHECK(boxed);
  td::TlParser p(data);
  tl_object_ptr<T> R;
  R = move_tl_object_as<T>(T::fetch(p));
  p.fetch_end();
  if (p.get_status().is_ok()) {
    return std::move(R);
  } else {
    return p.get_status();
  }
}

template <typename T>
td::Result<tl_object_ptr<std::enable_if_t<std::is_constructible<T>::value, T>>> fetch_tl_prefix(td::BufferSlice &data,
                                                                                                bool boxed) {
  td::TlBufferParser p(&data);
  tl_object_ptr<T> R;
  if (boxed) {
    R = TlFetchBoxed<TlFetchObject<T>, T::ID>::parse(p);
  } else {
    R = move_tl_object_as<T>(T::fetch(p));
  }
  if (p.get_status().is_ok()) {
    data.confirm_read(data.size() - p.get_left_len());
    return std::move(R);
  } else {
    return p.get_status();
  }
}

template <typename T>
td::Result<tl_object_ptr<std::enable_if_t<!std::is_constructible<T>::value, T>>> fetch_tl_prefix(td::BufferSlice &data,
                                                                                                 bool boxed) {
  CHECK(boxed);
  td::TlBufferParser p(&data);
  tl_object_ptr<T> R;
  R = move_tl_object_as<T>(T::fetch(p));
  if (p.get_status().is_ok()) {
    data.confirm_read(data.size() - p.get_left_len());
    return std::move(R);
  } else {
    return p.get_status();
  }
}

template <class T>
[[deprecated]] tl_object_ptr<T> clone_tl_object(const tl_object_ptr<T> &obj) {
  auto B = serialize_tl_object(obj, true);
  auto R = fetch_tl_object<T>(std::move(B), true);
  R.ensure();
  return R.move_as_ok();
}

template <class T>
td::Result<typename T::ReturnType> fetch_result(td::Slice message, bool check_end = true) {
  td::TlParser parser(message);
  auto result = T::fetch_result(parser);

  if (check_end) {
    parser.fetch_end();
  }
  const char *error = parser.get_error();
  if (error != nullptr) {
    LOG(ERROR) << "Can't parse: " << td::format::as_hex_dump<4>(message);
    return td::Status::Error(500, td::Slice(error));
  }

  return std::move(result);
}

template <class T>
td::Result<typename T::ReturnType> fetch_result(const td::BufferSlice &message, bool check_end = true) {
  td::TlBufferParser parser(&message);
  auto result = T::fetch_result(parser);

  if (check_end) {
    parser.fetch_end();
  }
  const char *error = parser.get_error();
  if (error != nullptr) {
    LOG(ERROR) << "Can't parse: " << td::format::as_hex_dump<4>(message.as_slice());
    return td::Status::Error(500, td::Slice(error));
  }

  return std::move(result);
}

template <class Type, class... Args>
td::BufferSlice create_serialize_tl_object(Args &&... args) {
  return serialize_tl_object(create_tl_object<Type>(std::forward<Args>(args)...), true);
}

template <class Type, class... Args>
td::BufferSlice create_serialize_tl_object_suffix(td::Slice suffix, Args &&... args) {
  return serialize_tl_object(create_tl_object<Type>(std::forward<Args>(args)...), true, suffix);
}

template <class Type, class... Args>
auto create_hash_tl_object(Args &&... args) {
  return get_tl_object_sha_bits256(create_tl_object<Type>(std::forward<Args>(args)...));
}

}  // namespace ton
