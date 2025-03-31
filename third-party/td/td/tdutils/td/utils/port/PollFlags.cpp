//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
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
