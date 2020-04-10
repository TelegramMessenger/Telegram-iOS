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

#include "td/utils/common.h"
#include "td/utils/port/FileFd.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"

namespace td {

class MemoryMapping {
 public:
  struct Options {
    int64 offset{0};
    int64 size{-1};

    Options() {
    }
    Options &with_offset(int64 new_offset) {
      offset = new_offset;
      return *this;
    }
    Options &with_size(int64 new_size) {
      size = new_size;
      return *this;
    }
  };

  static Result<MemoryMapping> create_anonymous(const Options &options = {});
  static Result<MemoryMapping> create_from_file(const FileFd &file, const Options &options = {});

  Slice as_slice() const;
  MutableSlice as_mutable_slice();  // returns empty slice if memory is read-only

  MemoryMapping(const MemoryMapping &other) = delete;
  const MemoryMapping &operator=(const MemoryMapping &other) = delete;
  MemoryMapping(MemoryMapping &&other);
  MemoryMapping &operator=(MemoryMapping &&other);
  ~MemoryMapping();

 private:
  class Impl;
  unique_ptr<Impl> impl_;
  explicit MemoryMapping(unique_ptr<Impl> impl);
};

}  // namespace td
