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

#include "td/utils/common.h"
#include "td/utils/Slice.h"

#include <cstring>

namespace td {

template <size_t size>
struct UInt {
  static_assert(size % 8 == 0, "size should be divisible by 8");
  uint8 raw[size / 8];

  Slice as_slice() const {
    return Slice(raw, size / 8);
  }

  MutableSlice as_slice() {
    return MutableSlice(raw, size / 8);
  }

  bool is_zero() const {
    for (size_t i = 0; i < size / 8; i++) {
      if (raw[i] != 0) {
        return false;
      }
    }
    return true;
  }
  void set_zero() {
    for (size_t i = 0; i < size / 8; i++) {
      raw[i] = 0;
    }
  }
  static UInt zero() {
    UInt v;
    v.set_zero();
    return v;
  }
};

template <size_t size>
bool operator==(const UInt<size> &a, const UInt<size> &b) {
  return a.as_slice() == b.as_slice();
}

template <size_t size>
bool operator!=(const UInt<size> &a, const UInt<size> &b) {
  return !(a == b);
}

template <size_t size>
td::UInt<size> operator^(const UInt<size> &a, const UInt<size> &b) {
  td::UInt<size> res;
  for (size_t i = 0; i < size / 8; i++) {
    res.raw[i] = static_cast<uint8>(a.raw[i] ^ b.raw[i]);
  }
  return res;
}

template <size_t size>
int get_kth_bit(const UInt<size> &a, uint32 bit) {
  uint8 b = a.raw[bit / 8];
  bit &= 7;
  return (b >> (7 - bit)) & 1;
}

template <size_t size>
Slice as_slice(const UInt<size> &value) {
  return value.as_slice();
}

template <size_t size>
MutableSlice as_slice(UInt<size> &value) {
  return value.as_slice();
}

template <size_t size>
bool operator<(const UInt<size> &a, const UInt<size> &b) {
  return a.as_slice() < b.as_slice();
}

using UInt128 = UInt<128>;
using UInt256 = UInt<256>;

}  // namespace td
