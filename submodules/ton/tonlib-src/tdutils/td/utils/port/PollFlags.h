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

#include "td/utils/StringBuilder.h"

#include <atomic>

namespace td {

class PollFlags {
 public:
  using Raw = int32;
  bool can_read() const {
    return has_flags(Read());
  }
  bool can_write() const {
    return has_flags(Write());
  }
  bool can_close() const {
    return has_flags(Close());
  }
  bool has_pending_error() const {
    return has_flags(Error());
  }
  void remove_flags(PollFlags flags) {
    remove_flags(flags.raw());
  }
  bool add_flags(PollFlags flags) {
    auto old_flags = flags_;
    add_flags(flags.raw());
    return old_flags != flags_;
  }
  bool has_flags(PollFlags flags) const {
    return has_flags(flags.raw());
  }

  bool empty() const {
    return flags_ == 0;
  }
  Raw raw() const {
    return flags_;
  }
  static PollFlags from_raw(Raw raw) {
    return PollFlags(raw);
  }
  PollFlags() = default;

  bool operator==(const PollFlags &other) const {
    return flags_ == other.flags_;
  }
  bool operator!=(const PollFlags &other) const {
    return !(*this == other);
  }
  PollFlags operator|(const PollFlags other) const {
    return from_raw(raw() | other.raw());
  }

  static PollFlags Write() {
    return PollFlags(Flag::Write);
  }
  static PollFlags Error() {
    return PollFlags(Flag::Error);
  }
  static PollFlags Close() {
    return PollFlags(Flag::Close);
  }
  static PollFlags Read() {
    return PollFlags(Flag::Read);
  }
  static PollFlags ReadWrite() {
    return Read() | Write();
  }

 private:
  enum class Flag : Raw { Write = 0x001, Read = 0x002, Close = 0x004, Error = 0x008, None = 0 };
  Raw flags_{static_cast<Raw>(Flag::None)};

  explicit PollFlags(Raw raw) : flags_(raw) {
  }
  explicit PollFlags(Flag flag) : PollFlags(static_cast<Raw>(flag)) {
  }

  PollFlags &add_flags(Raw flags) {
    flags_ |= flags;
    return *this;
  }
  PollFlags &remove_flags(Raw flags) {
    flags_ &= ~flags;
    return *this;
  }
  bool has_flags(Raw flags) const {
    return (flags_ & flags) == flags;
  }
};

StringBuilder &operator<<(StringBuilder &sb, PollFlags flags);

class PollFlagsSet {
 public:
  // write flags from any thread
  // this is the only function that should be called from other threads
  bool write_flags(PollFlags flags);

  bool write_flags_local(PollFlags flags);
  bool flush() const;

  PollFlags read_flags() const;
  PollFlags read_flags_local() const;
  void clear_flags(PollFlags flags);
  void clear();

 private:
  mutable std::atomic<PollFlags::Raw> to_write_{0};
  mutable PollFlags flags_;
};

}  // namespace td
