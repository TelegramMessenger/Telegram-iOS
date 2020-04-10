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
#include <utility>
#include <memory>
#include <atomic>

#include "td/utils/common.h"

namespace td {
class FileSyncState {
  struct Self;

 public:
  class Reader {
   public:
    Reader() = default;
    Reader(std::shared_ptr<Self> self);
    bool set_requested_sync_size(size_t size) const;
    size_t synced_size() const;
    size_t flushed_size() const;

   private:
    std::shared_ptr<Self> self;
  };

  class Writer {
   public:
    Writer() = default;
    Writer(std::shared_ptr<Self> self);
    size_t get_requested_synced_size();
    bool set_synced_size(size_t size);
    bool set_flushed_size(size_t size);

   private:
    std::shared_ptr<Self> self;
  };

  static std::pair<Reader, Writer> create();

 private:
  struct Self {
    std::atomic<size_t> requested_synced_size{0};

    std::atomic<size_t> synced_size{0};
    std::atomic<size_t> flushed_size{0};
  };
};
}  // namespace td
