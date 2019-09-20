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
#include "td/utils/port/Stat.h"

#include "td/utils/port/detail/PollableFd.h"
#include "td/utils/port/FileFd.h"

#if TD_PORT_POSIX

#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/port/Clocks.h"
#include "td/utils/ScopeGuard.h"

#include <utility>

#if TD_DARWIN
#include <mach/mach.h>
#include <sys/time.h>
#endif

// We don't want warnings from system headers
#if TD_GCC
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wconversion"
#endif
#include <sys/stat.h>
#if TD_GCC
#pragma GCC diagnostic pop
#endif

#if TD_ANDROID || TD_TIZEN
#include <sys/syscall.h>
#endif

namespace td {

namespace detail {

template <class...>
struct voider {
  using type = void;
};
template <class... T>
using void_t = typename voider<T...>::type;

template <class T, class = void>
struct TimeNsec {
  static std::pair<int, int> get(const T &) {
    T().warning("Platform lacks support of precise access/modification file times, comment this line to continue");
    return {0, 0};
  }
};

// remove libc compatibility hacks if any: we have our own hacks
#ifdef st_atimespec
#undef st_atimespec
#endif

#ifdef st_atimensec
#undef st_atimensec
#endif

#ifdef st_atime_nsec
#undef st_atime_nsec
#endif

template <class T>
struct TimeNsec<T, void_t<char, decltype(T::st_atimespec), decltype(T::st_mtimespec)>> {
  static std::pair<decltype(decltype(T::st_atimespec)::tv_nsec), decltype(decltype(T::st_mtimespec)::tv_nsec)> get(
      const T &s) {
    return {s.st_atimespec.tv_nsec, s.st_mtimespec.tv_nsec};
  }
};

template <class T>
struct TimeNsec<T, void_t<short, decltype(T::st_atimensec), decltype(T::st_mtimensec)>> {
  static std::pair<decltype(T::st_atimensec), decltype(T::st_mtimensec)> get(const T &s) {
    return {s.st_atimensec, s.st_mtimensec};
  }
};

template <class T>
struct TimeNsec<T, void_t<int, decltype(T::st_atim), decltype(T::st_mtim)>> {
  static std::pair<decltype(decltype(T::st_atim)::tv_nsec), decltype(decltype(T::st_mtim)::tv_nsec)> get(const T &s) {
    return {s.st_atim.tv_nsec, s.st_mtim.tv_nsec};
  }
};

template <class T>
struct TimeNsec<T, void_t<long, decltype(T::st_atime_nsec), decltype(T::st_mtime_nsec)>> {
  static std::pair<decltype(T::st_atime_nsec), decltype(T::st_mtime_nsec)> get(const T &s) {
    return {s.st_atime_nsec, s.st_mtime_nsec};
  }
};

Stat from_native_stat(const struct ::stat &buf) {
  auto time_nsec = TimeNsec<struct ::stat>::get(buf);

  Stat res;
  res.atime_nsec_ = static_cast<uint64>(buf.st_atime) * 1000000000 + time_nsec.first;
  res.mtime_nsec_ = static_cast<uint64>(buf.st_mtime) * 1000000000 + time_nsec.second / 1000 * 1000;
  res.size_ = buf.st_size;
  res.is_dir_ = (buf.st_mode & S_IFMT) == S_IFDIR;
  res.is_reg_ = (buf.st_mode & S_IFMT) == S_IFREG;
  return res;
}

Result<Stat> fstat(int native_fd) {
  struct ::stat buf;
  if (detail::skip_eintr([&] { return ::fstat(native_fd, &buf); }) < 0) {
    return OS_ERROR(PSLICE() << "Stat for fd " << native_fd << " failed");
  }
  return detail::from_native_stat(buf);
}

Status update_atime(int native_fd) {
#if TD_LINUX
  timespec times[2];
  // access time
  times[0].tv_nsec = UTIME_NOW;
  times[0].tv_sec = 0;
  // modify time
  times[1].tv_nsec = UTIME_OMIT;
  times[1].tv_sec = 0;
  if (futimens(native_fd, times) < 0) {
    auto status = OS_ERROR(PSLICE() << "futimens " << tag("fd", native_fd));
    LOG(WARNING) << status;
    return status;
  }
  return Status::OK();
#elif TD_DARWIN
  TRY_RESULT(info, fstat(native_fd));
  timeval upd[2];
  auto now = Clocks::system();
  // access time
  upd[0].tv_sec = static_cast<decltype(upd[0].tv_sec)>(now);
  upd[0].tv_usec = static_cast<decltype(upd[0].tv_usec)>((now - static_cast<double>(upd[0].tv_sec)) * 1000000);
  // modify time
  upd[1].tv_sec = static_cast<decltype(upd[1].tv_sec)>(info.mtime_nsec_ / 1000000000ll);
  upd[1].tv_usec = static_cast<decltype(upd[1].tv_usec)>(info.mtime_nsec_ % 1000000000ll / 1000);
  if (futimes(native_fd, upd) < 0) {
    auto status = OS_ERROR(PSLICE() << "futimes " << tag("fd", native_fd));
    LOG(WARNING) << status;
    return status;
  }
  return Status::OK();
#else
  return Status::Error("Not supported");
// timespec times[2];
//// access time
// times[0].tv_nsec = UTIME_NOW;
//// modify time
// times[1].tv_nsec = UTIME_OMIT;
////  int err = syscall(__NR_utimensat, native_fd, nullptr, times, 0);
// if (futimens(native_fd, times) < 0) {
//   auto status = OS_ERROR(PSLICE() << "futimens " << tag("fd", native_fd));
//   LOG(WARNING) << status;
//   return status;
// }
// return Status::OK();
#endif
}
}  // namespace detail

Status update_atime(CSlice path) {
  TRY_RESULT(file, FileFd::open(path, FileFd::Flags::Read));
  SCOPE_EXIT {
    file.close();
  };
  return detail::update_atime(file.get_native_fd().fd());
}

Result<Stat> stat(CSlice path) {
  struct ::stat buf;
  int err = detail::skip_eintr([&] { return ::stat(path.c_str(), &buf); });
  if (err < 0) {
    return OS_ERROR(PSLICE() << "Stat for file \"" << path << "\" failed");
  }
  return detail::from_native_stat(buf);
}

Result<MemStat> mem_stat() {
#if TD_DARWIN
  task_basic_info t_info;
  mach_msg_type_number_t t_info_count = TASK_BASIC_INFO_COUNT;

  if (KERN_SUCCESS !=
      task_info(mach_task_self(), TASK_BASIC_INFO, reinterpret_cast<task_info_t>(&t_info), &t_info_count)) {
    return Status::Error("task_info failed");
  }
  MemStat res;
  res.resident_size_ = t_info.resident_size;
  res.virtual_size_ = t_info.virtual_size;
  res.resident_size_peak_ = 0;
  res.virtual_size_peak_ = 0;
  return res;
#elif TD_LINUX || TD_ANDROID || TD_TIZEN
  TRY_RESULT(fd, FileFd::open("/proc/self/status", FileFd::Read));
  SCOPE_EXIT {
    fd.close();
  };

  constexpr int TMEM_SIZE = 10000;
  char mem[TMEM_SIZE];
  TRY_RESULT(size, fd.read(MutableSlice(mem, TMEM_SIZE - 1)));
  CHECK(size < TMEM_SIZE - 1);
  mem[size] = 0;

  const char *s = mem;
  MemStat res;
  while (*s) {
    const char *name_begin = s;
    while (*s != 0 && *s != '\n') {
      s++;
    }
    auto name_end = name_begin;
    while (is_alpha(*name_end)) {
      name_end++;
    }
    Slice name(name_begin, name_end);

    uint64 *x = nullptr;
    if (name == "VmPeak") {
      x = &res.virtual_size_peak_;
    }
    if (name == "VmSize") {
      x = &res.virtual_size_;
    }
    if (name == "VmHWM") {
      x = &res.resident_size_peak_;
    }
    if (name == "VmRSS") {
      x = &res.resident_size_;
    }
    if (x != nullptr) {
      Slice value(name_end, s);
      if (!value.empty() && value[0] == ':') {
        value.remove_prefix(1);
      }
      value = trim(value);
      value = split(value).first;
      auto r_mem = to_integer_safe<uint64>(value);
      if (r_mem.is_error()) {
        LOG(ERROR) << "Failed to parse memory stats " << tag("name", name) << tag("value", value);
        *x = static_cast<uint64>(-1);
      } else {
        *x = r_mem.ok() * 1024;  // memory is in kB
      }
    }
    if (*s == 0) {
      break;
    }
    s++;
  }

  return res;
#else
  return Status::Error("Not supported");
#endif
}

#if TD_LINUX
Status cpu_stat_self(CpuStat &stat) {
  TRY_RESULT(fd, FileFd::open("/proc/self/stat", FileFd::Read));
  SCOPE_EXIT {
    fd.close();
  };

  constexpr int TMEM_SIZE = 10000;
  char mem[TMEM_SIZE];
  TRY_RESULT(size, fd.read(MutableSlice(mem, TMEM_SIZE - 1)));
  CHECK(size < TMEM_SIZE - 1);
  mem[size] = 0;

  char *s = mem;
  char *t = mem + size;
  int pass_cnt = 0;

  while (pass_cnt < 15) {
    if (pass_cnt == 13) {
      stat.process_user_ticks = to_integer<uint64>(Slice(s, t));
    }
    if (pass_cnt == 14) {
      stat.process_system_ticks = to_integer<uint64>(Slice(s, t));
    }
    while (*s && *s != ' ') {
      s++;
    }
    if (*s == ' ') {
      s++;
      pass_cnt++;
    } else {
      return Status::Error("unexpected end of proc file");
    }
  }
  return Status::OK();
}
Status cpu_stat_total(CpuStat &stat) {
  TRY_RESULT(fd, FileFd::open("/proc/stat", FileFd::Read));
  SCOPE_EXIT {
    fd.close();
  };

  constexpr int TMEM_SIZE = 10000;
  char mem[TMEM_SIZE];
  TRY_RESULT(size, fd.read(MutableSlice(mem, TMEM_SIZE - 1)));
  CHECK(size < TMEM_SIZE - 1);
  mem[size] = 0;

  uint64 sum = 0, cur = 0;
  for (size_t i = 0; i < size; i++) {
    int c = mem[i];
    if (c >= '0' && c <= '9') {
      cur = cur * 10 + (uint64)c - '0';
    } else {
      sum += cur;
      cur = 0;
      if (c == '\n') {
        break;
      }
    }
  }

  stat.total_ticks = sum;
  return Status::OK();
}
#endif

Result<CpuStat> cpu_stat() {
#if TD_LINUX
  CpuStat stat;
  TRY_STATUS(cpu_stat_self(stat));
  TRY_STATUS(cpu_stat_total(stat));
  return stat;
#else
  return Status::Error("Not supported");
#endif
}
}  // namespace td
#endif

#if TD_PORT_WINDOWS
namespace td {

Result<Stat> stat(CSlice path) {
  TRY_RESULT(fd, FileFd::open(path, FileFd::Flags::Read | FileFd::PrivateFlags::WinStat));
  return fd.stat();
}

Result<CpuStat> cpu_stat() {
  return Status::Error("Not supported");
}

}  // namespace td
#endif
