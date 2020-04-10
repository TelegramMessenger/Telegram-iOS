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
#pragma once

#include <cstdint>
#include <memory>
#include <string>
#include <vector>

#include "tl/TlObject.h"

#include "td/utils/misc.h"

namespace ton {

template <class Func, std::int32_t constructor_id>
class TlStoreBoxed {
 public:
  template <class T, class Storer>
  static void store(const T &x, Storer &s) {
    s.store_binary(constructor_id);
    Func::store(x, s);
  }
};

template <class Func>
class TlStoreBoxedUnknown {
 public:
  template <class T, class Storer>
  static void store(const T &x, Storer &s) {
    s.store_binary(x->get_id());
    Func::store(x, s);
  }
};

class TlStoreBool {
 public:
  template <class Storer>
  static void store(const bool &x, Storer &s) {
    constexpr std::int32_t ID_BOOL_FALSE = 0xbc799737;
    constexpr std::int32_t ID_BOOL_TRUE = 0x997275b5;

    s.store_binary(x ? ID_BOOL_TRUE : ID_BOOL_FALSE);
  }
};

class TlStoreTrue {
 public:
  template <class Storer>
  static void store(const bool &x, Storer &s) {
    // currently nothing to do
  }
};

class TlStoreBinary {
 public:
  template <class T, class Storer>
  static void store(const T &x, Storer &s) {
    s.store_binary(x);
  }
};

class TlStoreString {
 public:
  template <class T, class Storer>
  static void store(const T &x, Storer &s) {
    s.store_string(x);
  }
};

template <class Func>
class TlStoreVector {
 public:
  template <class T, class Storer>
  static void store(const T &vec, Storer &s) {
    s.store_binary(td::narrow_cast<td::int32>(vec.size()));
    for (auto &val : vec) {
      Func::store(val, s);
    }
  }
};

class TlStoreObject {
 public:
  template <class T, class Storer>
  static void store(const tl_object_ptr<T> &obj, Storer &s) {
    return obj->store(s);
  }
};

}  // namespace ton
