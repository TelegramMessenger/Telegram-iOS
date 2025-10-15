//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/port/config.h"

#include "td/utils/common.h"
#include "td/utils/port/detail/NativeFd.h"
#include "td/utils/port/detail/PollableFd.h"
#include "td/utils/port/IoSlice.h"
#include "td/utils/port/Stat.h"
#include "td/utils/Slice.h"
#include "td/utils/Span.h"
#include "td/utils/Status.h"

namespace td {
namespace detail {
class FileFdImpl;
}  // namespace detail

class FileFd {
 public:
  FileFd();
  FileFd(FileFd &&) noexcept;
  FileFd &operator=(FileFd &&) noexcept;
  ~FileFd();
  FileFd(const FileFd &) = delete;
  FileFd &operator=(const FileFd &) = delete;

  enum Flags : int32 { Write = 1, Read = 2, Truncate = 4, Create = 8, Append = 16, CreateNew = 32, Direct = 64 };
  enum PrivateFlags : int32 { WinStat = 128 };

  static Result<FileFd> open(CSlice filepath, int32 flags, int32 mode = 0600) TD_WARN_UNUSED_RESULT;
  static FileFd from_native_fd(NativeFd fd) TD_WARN_UNUSED_RESULT;

  Result<size_t> write(Slice slice) TD_WARN_UNUSED_RESULT;
  Result<size_t> writev(Span<IoSlice> slices) TD_WARN_UNUSED_RESULT;
  Result<size_t> read(MutableSlice slice) TD_WARN_UNUSED_RESULT;

  Result<size_t> pwrite(Slice slice, int64 offset) TD_WARN_UNUSED_RESULT;
  Result<size_t> pread(MutableSlice slice, int64 offset) const TD_WARN_UNUSED_RESULT;

  enum class LockFlags { Write, Read, Unlock };
  Status lock(LockFlags flags, const string &path, int32 max_tries) TD_WARN_UNUSED_RESULT;
  static void remove_local_lock(const string &path);

  PollableFdInfo &get_poll_info();
  const PollableFdInfo &get_poll_info() const;

  void close();

  bool empty() const;

  Result<int64> get_size() const;

  Result<int64> get_real_size() const;

  Result<Stat> stat() const;

  Status sync() TD_WARN_UNUSED_RESULT;
  Status sync_barrier() TD_WARN_UNUSED_RESULT;

  Status seek(int64 position) TD_WARN_UNUSED_RESULT;

  Status truncate_to_current_position(int64 current_position) TD_WARN_UNUSED_RESULT;

  const NativeFd &get_native_fd() const;
  NativeFd move_as_native_fd();

 private:
  unique_ptr<detail::FileFdImpl> impl_;

  explicit FileFd(unique_ptr<detail::FileFdImpl> impl);
};

}  // namespace td
