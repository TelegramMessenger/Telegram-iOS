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

#include "td/utils/StorerBase.h"

#include "td/utils/common.h"
#include "td/utils/Slice.h"
#include "td/utils/tl_storers.h"

#include <cstring>
#include <limits>

namespace td {

class SliceStorer : public Storer {
  Slice slice;

 public:
  explicit SliceStorer(Slice slice) : slice(slice) {
  }
  size_t size() const override {
    return slice.size();
  }
  size_t store(uint8 *ptr) const override {
    std::memcpy(ptr, slice.ubegin(), slice.size());
    return slice.size();
  }
};

inline SliceStorer create_storer(Slice slice) {
  return SliceStorer(slice);
}

class ConcatStorer : public Storer {
  const Storer &a_;
  const Storer &b_;

 public:
  ConcatStorer(const Storer &a, const Storer &b) : a_(a), b_(b) {
  }

  size_t size() const override {
    return a_.size() + b_.size();
  }

  size_t store(uint8 *ptr) const override {
    uint8 *ptr_save = ptr;
    ptr += a_.store(ptr);
    ptr += b_.store(ptr);
    return ptr - ptr_save;
  }
};

inline ConcatStorer create_storer(const Storer &a, const Storer &b) {
  return ConcatStorer(a, b);
}

template <class T>
class DefaultStorer : public Storer {
 public:
  explicit DefaultStorer(const T &object) : object_(object) {
  }
  size_t size() const override {
    if (size_ == std::numeric_limits<size_t>::max()) {
      size_ = tl_calc_length(object_);
    }
    return size_;
  }
  size_t store(uint8 *ptr) const override {
    return tl_store_unsafe(object_, ptr);
  }

 private:
  mutable size_t size_ = std::numeric_limits<size_t>::max();
  const T &object_;
};

template <class T>
DefaultStorer<T> create_default_storer(const T &from) {
  return DefaultStorer<T>(from);
}

}  // namespace td
