//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
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

  MemoryMapping(const MemoryMapping &) = delete;
  MemoryMapping &operator=(const MemoryMapping &) = delete;
  MemoryMapping(MemoryMapping &&other) noexcept;
  MemoryMapping &operator=(MemoryMapping &&other) noexcept;
  ~MemoryMapping();

 private:
  class Impl;
  unique_ptr<Impl> impl_;
  explicit MemoryMapping(unique_ptr<Impl> impl);
};

}  // namespace td
