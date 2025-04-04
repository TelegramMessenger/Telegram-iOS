//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/FlatHashSet.h"
#include "td/utils/misc.h"
#include "td/utils/SharedSlice.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/StackAllocator.h"
#include "td/utils/Status.h"
#include "td/utils/tl_parsers.h"
#include "td/utils/tl_storers.h"
#include "td/utils/UInt.h"
#include "td/utils/unique_value_ptr.h"
#include "td/utils/Variant.h"

#include <type_traits>
#include <utility>

#define BEGIN_STORE_FLAGS()       \
  do {                            \
    ::td::uint32 flags_store = 0; \
  ::td::uint32 bit_offset_store = 0

#define STORE_FLAG(flag)                                                         \
  static_assert(std::is_same<decltype(flag), bool>::value, "flag must be bool"); \
  flags_store |= (flag) << bit_offset_store;                                     \
  bit_offset_store++

#define END_STORE_FLAGS()           \
  CHECK(bit_offset_store < 31);     \
  ::td::store(flags_store, storer); \
  }                                 \
  while (false)

#define BEGIN_PARSE_FLAGS()            \
  do {                                 \
    ::td::uint32 flags_parse;          \
    ::td::uint32 bit_offset_parse = 0; \
  ::td::parse(flags_parse, parser)

#define PARSE_FLAG(flag)                                                         \
  static_assert(std::is_same<decltype(flag), bool>::value, "flag must be bool"); \
  flag = ((flags_parse >> bit_offset_parse) & 1) != 0;                           \
  bit_offset_parse++

#define END_PARSE_FLAGS()                                                                                           \
  CHECK(bit_offset_parse < 31);                                                                                     \
  if ((flags_parse & ~((1 << bit_offset_parse) - 1)) != 0) {                                                        \
    parser.set_error(PSTRING() << "Invalid flags " << flags_parse << " left, current bit is " << bit_offset_parse); \
  }                                                                                                                 \
  }                                                                                                                 \
  while (false)

namespace td {

template <class StorerT>
void store(bool x, StorerT &storer) {
  storer.store_binary(static_cast<int32>(x));
}
template <class ParserT>
void parse(bool &x, ParserT &parser) {
  x = parser.fetch_int() != 0;
}

template <class StorerT>
void store(int32 x, StorerT &storer) {
  storer.store_binary(x);
}
template <class ParserT>
void parse(int32 &x, ParserT &parser) {
  x = parser.fetch_int();
}

template <class StorerT>
void store(uint32 x, StorerT &storer) {
  storer.store_binary(x);
}
template <class ParserT>
void parse(uint32 &x, ParserT &parser) {
  x = static_cast<uint32>(parser.fetch_int());
}

template <class StorerT>
void store(int64 x, StorerT &storer) {
  storer.store_binary(x);
}
template <class ParserT>
void parse(int64 &x, ParserT &parser) {
  x = parser.fetch_long();
}
template <class StorerT>
void store(uint64 x, StorerT &storer) {
  storer.store_binary(x);
}
template <class ParserT>
void parse(uint64 &x, ParserT &parser) {
  x = static_cast<uint64>(parser.fetch_long());
}

template <class StorerT>
void store(UInt256 x, StorerT &storer) {
  storer.store_binary(x);
}
template <class ParserT>
void parse(UInt256 &x, ParserT &parser) {
  x = parser.template fetch_binary<UInt256>();
}

template <class StorerT>
void store(UInt512 x, StorerT &storer) {
  storer.store_binary(x);
}
template <class ParserT>
void parse(UInt512 &x, ParserT &parser) {
  x = parser.template fetch_binary<UInt512>();
}

template <class StorerT>
void store(double x, StorerT &storer) {
  storer.store_binary(x);
}
template <class ParserT>
void parse(double &x, ParserT &parser) {
  x = parser.fetch_double();
}

template <class StorerT>
void store(Slice x, StorerT &storer) {
  storer.store_string(x);
}
template <class StorerT>
void store(const string &x, StorerT &storer) {
  storer.store_string(x);
}
template <class StorerT>
void store(const SecureString &x, StorerT &storer) {
  storer.store_string(x.as_slice());
}
template <class ParserT>
void parse(string &x, ParserT &parser) {
  x = parser.template fetch_string<string>();
}

template <class ParserT>
void parse(SecureString &x, ParserT &parser) {
  x = parser.template fetch_string<SecureString>();
}

template <class T, class StorerT>
void store(const vector<T> &vec, StorerT &storer) {
  storer.store_binary(narrow_cast<int32>(vec.size()));
  for (auto &val : vec) {
    store(val, storer);
  }
}
template <class T, class StorerT>
void store(const vector<T *> &vec, StorerT &storer) {
  storer.store_binary(narrow_cast<int32>(vec.size()));
  for (auto &val : vec) {
    store(*val, storer);
  }
}
template <class T, class ParserT>
void parse(vector<T> &vec, ParserT &parser) {
  uint32 size = parser.fetch_int();
  if (parser.get_left_len() < size) {
    parser.set_error("Wrong vector length");
    return;
  }
  vec = vector<T>(size);
  for (auto &val : vec) {
    parse(val, parser);
  }
}

template <class T, class StorerT>
void store(const unique_ptr<T> &ptr, StorerT &storer) {
  CHECK(ptr != nullptr);
  store(*ptr, storer);
}
template <class T, class ParserT>
void parse(unique_ptr<T> &ptr, ParserT &parser) {
  CHECK(ptr == nullptr);
  ptr = make_unique<T>();
  parse(*ptr, parser);
}

template <class T, class StorerT>
void store(const unique_value_ptr<T> &ptr, StorerT &storer) {
  CHECK(ptr != nullptr);
  store(*ptr, storer);
}
template <class T, class ParserT>
void parse(unique_value_ptr<T> &ptr, ParserT &parser) {
  CHECK(ptr == nullptr);
  ptr = make_unique_value<T>();
  parse(*ptr, parser);
}

template <class Key, class Hash, class KeyEqual, class StorerT>
void store(const FlatHashSet<Key, Hash, KeyEqual> &s, StorerT &storer) {
  storer.store_binary(narrow_cast<int32>(s.size()));
  for (auto &val : s) {
    store(val, storer);
  }
}
template <class Key, class Hash, class KeyEqual, class ParserT>
void parse(FlatHashSet<Key, Hash, KeyEqual> &s, ParserT &parser) {
  uint32 size = parser.fetch_int();
  if (parser.get_left_len() < size) {
    parser.set_error("Wrong set length");
    return;
  }
  s.clear();
  for (uint32 i = 0; i < size; i++) {
    Key val;
    parse(val, parser);
    s.insert(std::move(val));
  }
}

template <class U, class V, class StorerT>
void store(const std::pair<U, V> &pair, StorerT &storer) {
  store(pair.first, storer);
  store(pair.second, storer);
}
template <class U, class V, class ParserT>
void parse(std::pair<U, V> &pair, ParserT &parser) {
  parse(pair.first, parser);
  parse(pair.second, parser);
}

template <class T, class StorerT>
std::enable_if_t<std::is_enum<T>::value> store(const T &val, StorerT &storer) {
  store(static_cast<int32>(val), storer);
}
template <class T, class ParserT>
std::enable_if_t<std::is_enum<T>::value> parse(T &val, ParserT &parser) {
  int32 result;
  parse(result, parser);
  val = static_cast<T>(result);
}

template <class T, class StorerT>
std::enable_if_t<!std::is_enum<T>::value> store(const T &val, StorerT &storer) {
  val.store(storer);
}
template <class T, class ParserT>
std::enable_if_t<!std::is_enum<T>::value> parse(T &val, ParserT &parser) {
  val.parse(parser);
}

template <class... Types, class StorerT>
void store(const Variant<Types...> &variant, StorerT &storer) {
  store(variant.get_offset(), storer);
  variant.visit([&storer](auto &&value) {
    using td::store;
    store(value, storer);
  });
}
template <class... Types, class ParserT>
void parse(Variant<Types...> &variant, ParserT &parser) {
  auto type_offset = parser.fetch_int();
  if (type_offset < 0 || type_offset >= static_cast<int32>(sizeof...(Types))) {
    return parser.set_error("Invalid type");
  }
  variant.for_each([type_offset, &parser, &variant](int offset, auto *ptr) {
    using T = std::decay_t<decltype(*ptr)>;
    if (offset == type_offset) {
      variant = T();
      parse(variant.template get<T>(), parser);
    }
  });
}

template <class T>
string serialize(const T &object) {
  TlStorerCalcLength calc_length;
  store(object, calc_length);
  size_t length = calc_length.get_length();

  string key(length, '\0');
  if (!is_aligned_pointer<4>(key.data())) {
    auto ptr = StackAllocator::alloc(length);
    MutableSlice data = ptr.as_slice();
    TlStorerUnsafe storer(data.ubegin());
    store(object, storer);
    CHECK(storer.get_buf() == data.uend());
    key.assign(data.begin(), data.size());
  } else {
    MutableSlice data = key;
    TlStorerUnsafe storer(data.ubegin());
    store(object, storer);
    CHECK(storer.get_buf() == data.uend());
  }
  return key;
}

template <class T>
SecureString serialize_secure(const T &object) {
  TlStorerCalcLength calc_length;
  store(object, calc_length);
  size_t length = calc_length.get_length();

  SecureString key(length, '\0');
  CHECK(is_aligned_pointer<4>(key.data()));
  MutableSlice data = key.as_mutable_slice();
  TlStorerUnsafe storer(data.ubegin());
  store(object, storer);
  CHECK(storer.get_buf() == data.uend());
  return key;
}

template <class T>
TD_WARN_UNUSED_RESULT Status unserialize(T &object, Slice data) {
  TlParser parser(data);
  parse(object, parser);
  parser.fetch_end();
  return parser.get_status();
}

}  // namespace td
