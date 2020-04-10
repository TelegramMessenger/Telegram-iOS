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
#include "td/utils/port/PollFlags.h"

namespace td {

bool PollFlagsSet::write_flags(PollFlags flags) {
  if (flags.empty()) {
    return false;
  }
  auto old_flags = to_write_.fetch_or(flags.raw(), std::memory_order_relaxed);
  return (flags.raw() & ~old_flags) != 0;
}

bool PollFlagsSet::write_flags_local(PollFlags flags) {
  return flags_.add_flags(flags);
}

bool PollFlagsSet::flush() const {
  if (to_write_.load(std::memory_order_relaxed) == 0) {
    return false;
  }
  auto to_write = to_write_.exchange(0, std::memory_order_relaxed);
  auto old_flags = flags_;
  flags_.add_flags(PollFlags::from_raw(to_write));
  if (flags_.can_close()) {
    flags_.remove_flags(PollFlags::Write());
  }
  return flags_ != old_flags;
}

PollFlags PollFlagsSet::read_flags() const {
  flush();
  return flags_;
}

PollFlags PollFlagsSet::read_flags_local() const {
  return flags_;
}

void PollFlagsSet::clear_flags(PollFlags flags) {
  flags_.remove_flags(flags);
}

void PollFlagsSet::clear() {
  to_write_ = 0;
  flags_ = {};
}

StringBuilder &operator<<(StringBuilder &sb, PollFlags flags) {
  sb << '[';
  if (flags.can_read()) {
    sb << 'R';
  }
  if (flags.can_write()) {
    sb << 'W';
  }
  if (flags.can_close()) {
    sb << 'C';
  }
  if (flags.has_pending_error()) {
    sb << 'E';
  }
  return sb << ']';
}

}  // namespace td
