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

#include "td/utils/port/config.h"

#include "td/utils/common.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"

namespace td {

struct Stat {
  bool is_dir_;
  bool is_reg_;
  int64 size_;
  uint64 atime_nsec_;
  uint64 mtime_nsec_;
};

Result<Stat> stat(CSlice path) TD_WARN_UNUSED_RESULT;

struct CpuStat {
  uint64 total_ticks{0};
  uint64 process_user_ticks{0};
  uint64 process_system_ticks{0};
};
Result<CpuStat> cpu_stat() TD_WARN_UNUSED_RESULT;

#if TD_PORT_POSIX

namespace detail {
Result<Stat> fstat(int native_fd);
}  // namespace detail

Status update_atime(CSlice path) TD_WARN_UNUSED_RESULT;

struct MemStat {
  uint64 resident_size_ = 0;
  uint64 resident_size_peak_ = 0;
  uint64 virtual_size_ = 0;
  uint64 virtual_size_peak_ = 0;
};

Result<MemStat> mem_stat() TD_WARN_UNUSED_RESULT;

#endif

}  // namespace td
