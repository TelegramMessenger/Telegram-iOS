//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/port/FileFd.h"

#if TD_PORT_WINDOWS
#include "td/utils/port/FromApp.h"
#include "td/utils/port/Stat.h"
#include "td/utils/port/wstring_convert.h"
#endif

#include "td/utils/common.h"
#include "td/utils/ExitGuard.h"
#include "td/utils/FlatHashSet.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/port/detail/PollableFd.h"
#include "td/utils/port/detail/skip_eintr.h"
#include "td/utils/port/PollFlags.h"
#include "td/utils/port/sleep.h"
#include "td/utils/ScopeGuard.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/StringBuilder.h"

#include <cstring>
#include <mutex>
#include <utility>

#if TD_PORT_POSIX
#include <cerrno>

#include <fcntl.h>
#include <sys/file.h>
#include <sys/types.h>
#include <sys/uio.h>
#include <unistd.h>
#else
#include <limits>
#endif

#if TD_PORT_WINDOWS && defined(WIN32_LEAN_AND_MEAN)
#include <winioctl.h>
#endif

namespace td {

namespace {

struct PrintFlags {
  int32 flags;
};

StringBuilder &operator<<(StringBuilder &sb, const PrintFlags &print_flags) {
  auto flags = print_flags.flags;
  if (flags & ~(FileFd::Write | FileFd::Read | FileFd::Truncate | FileFd::Create | FileFd::Append | FileFd::CreateNew |
                FileFd::Direct | FileFd::WinStat)) {
    return sb << "opened with invalid flags " << flags;
  }

  if (flags & FileFd::Create) {
    sb << "opened/created ";
  } else if (flags & FileFd::CreateNew) {
    sb << "created ";
  } else {
    sb << "opened ";
  }

  if ((flags & FileFd::Write) && (flags & FileFd::Read)) {
    if (flags & FileFd::Append) {
      sb << "for reading and appending";
    } else {
      sb << "for reading and writing";
    }
  } else if (flags & FileFd::Write) {
    if (flags & FileFd::Append) {
      sb << "for appending";
    } else {
      sb << "for writing";
    }
  } else if (flags & FileFd::Read) {
    sb << "for reading";
  } else {
    sb << "for nothing";
  }

  if (flags & FileFd::Truncate) {
    sb << " with truncation";
  }
  if (flags & FileFd::Direct) {
    sb << " for direct io";
  }
  if (flags & FileFd::WinStat) {
    sb << " for stat";
  }
  return sb;
}

}  // namespace

namespace detail {
class FileFdImpl {
 public:
  PollableFdInfo info_;
};
}  // namespace detail

FileFd::FileFd() = default;
FileFd::FileFd(FileFd &&) noexcept = default;
FileFd &FileFd::operator=(FileFd &&) noexcept = default;
FileFd::~FileFd() = default;

FileFd::FileFd(unique_ptr<detail::FileFdImpl> impl) : impl_(std::move(impl)) {
}

Result<FileFd> FileFd::open(CSlice filepath, int32 flags, int32 mode) {
  if (flags & ~(Write | Read | Truncate | Create | Append | CreateNew | Direct | WinStat)) {
    return Status::Error(PSLICE() << "File \"" << filepath << "\" has failed to be " << PrintFlags{flags});
  }

  if ((flags & (Write | Read)) == 0) {
    return Status::Error(PSLICE() << "File \"" << filepath << "\" can't be " << PrintFlags{flags});
  }

#if TD_PORT_POSIX
  int native_flags = 0;

  if ((flags & Write) && (flags & Read)) {
    native_flags |= O_RDWR;
  } else if (flags & Write) {
    native_flags |= O_WRONLY;
  } else {
    CHECK(flags & Read);
    native_flags |= O_RDONLY;
  }

  if (flags & Truncate) {
    native_flags |= O_TRUNC;
  }

  if (flags & Create) {
    native_flags |= O_CREAT;
  } else if (flags & CreateNew) {
    native_flags |= O_CREAT;
    native_flags |= O_EXCL;
  }

  if (flags & Append) {
    native_flags |= O_APPEND;
  }

#if TD_LINUX
  if (flags & Direct) {
    native_flags |= O_DIRECT;
  }
#endif

  while (true) {
    int native_fd =
        detail::skip_eintr([&] { return ::open(filepath.c_str(), native_flags, static_cast<mode_t>(mode)); });
    if (native_fd < 0) {
      return OS_ERROR(PSLICE() << "File \"" << filepath << "\" can't be " << PrintFlags{flags});
    }
    // Avoid the use of low-numbered file descriptors, which can be used directly by some other functions
    constexpr int MINIMUM_FILE_DESCRIPTOR = 3;
    if (native_fd < MINIMUM_FILE_DESCRIPTOR) {
      ::close(native_fd);
      LOG(ERROR) << "Receive " << native_fd << " as a file descriptor";
      int dummy_fd = detail::skip_eintr([&] { return ::open("/dev/null", O_RDONLY, 0); });
      if (dummy_fd < 0) {
        return OS_ERROR("Can't open /dev/null");
      }
      continue;
    }
    return from_native_fd(NativeFd(native_fd));
  }
#elif TD_PORT_WINDOWS
  // TODO: support modes
  auto r_filepath = to_wstring(filepath);
  if (r_filepath.is_error()) {
    return Status::Error(PSLICE() << "Failed to convert file path \" << filepath << \" to UTF-16");
  }
  auto w_filepath = r_filepath.move_as_ok();
  DWORD desired_access = 0;
  if ((flags & Write) && (flags & Read)) {
    desired_access |= GENERIC_READ | GENERIC_WRITE;
  } else if (flags & Write) {
    desired_access |= GENERIC_WRITE;
  } else {
    CHECK(flags & Read);
    desired_access |= GENERIC_READ;
  }

  // TODO: share mode
  DWORD share_mode = FILE_SHARE_READ | FILE_SHARE_DELETE | FILE_SHARE_WRITE;

  DWORD native_flags = 0;

  DWORD creation_disposition = 0;
  if (flags & Create) {
    if (flags & Truncate) {
      creation_disposition = CREATE_ALWAYS;
    } else {
      creation_disposition = OPEN_ALWAYS;
    }
  } else if (flags & CreateNew) {
    creation_disposition = CREATE_NEW;
  } else {
    if (flags & Truncate) {
      creation_disposition = TRUNCATE_EXISTING;
    } else {
      creation_disposition = OPEN_EXISTING;
    }
#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP | WINAPI_PARTITION_SYSTEM)
    native_flags |= FILE_FLAG_OPEN_REPARSE_POINT;
#endif
  }

  if (flags & Direct) {
    native_flags |= FILE_FLAG_WRITE_THROUGH | FILE_FLAG_NO_BUFFERING;
  }
  if (flags & WinStat) {
    native_flags |= FILE_FLAG_BACKUP_SEMANTICS;
  }
#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP | WINAPI_PARTITION_SYSTEM)
  auto handle =
      CreateFile(w_filepath.c_str(), desired_access, share_mode, nullptr, creation_disposition, native_flags, nullptr);
#else
  CREATEFILE2_EXTENDED_PARAMETERS extended_parameters;
  std::memset(&extended_parameters, 0, sizeof(extended_parameters));
  extended_parameters.dwSize = sizeof(extended_parameters);
  extended_parameters.dwFileAttributes = FILE_ATTRIBUTE_NORMAL;
  extended_parameters.dwFileFlags = native_flags;
  auto handle = td::CreateFile2FromAppW(w_filepath.c_str(), desired_access, share_mode, creation_disposition,
                                        &extended_parameters);
#endif
  if (handle == INVALID_HANDLE_VALUE) {
    return OS_ERROR(PSLICE() << "File \"" << filepath << "\" can't be " << PrintFlags{flags});
  }
#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP | WINAPI_PARTITION_SYSTEM)
  if (flags & Write) {
    DWORD bytes_returned = 0;
    DeviceIoControl(handle, FSCTL_SET_SPARSE, nullptr, 0, nullptr, 0, &bytes_returned, nullptr);
  }
#endif
  auto native_fd = NativeFd(handle);
  if (flags & Append) {
    LARGE_INTEGER offset;
    offset.QuadPart = 0;
    auto set_pointer_res = SetFilePointerEx(handle, offset, nullptr, FILE_END);
    if (!set_pointer_res) {
      return OS_ERROR(PSLICE() << "Failed to seek to the end of file \"" << filepath << "\"");
    }
  }
  return from_native_fd(std::move(native_fd));
#endif
}

FileFd FileFd::from_native_fd(NativeFd native_fd) {
  auto impl = make_unique<detail::FileFdImpl>();
  impl->info_.set_native_fd(std::move(native_fd));
  impl->info_.add_flags(PollFlags::Write());
  return FileFd(std::move(impl));
}

Result<size_t> FileFd::write(Slice slice) {
  auto native_fd = get_native_fd().fd();
#if TD_PORT_POSIX
  auto bytes_written = detail::skip_eintr([&] { return ::write(native_fd, slice.begin(), slice.size()); });
  bool success = bytes_written >= 0;
#elif TD_PORT_WINDOWS
  DWORD bytes_written = 0;
  BOOL success = WriteFile(native_fd, slice.data(), narrow_cast<DWORD>(slice.size()), &bytes_written, nullptr);
#endif
  if (success) {
    auto result = narrow_cast<size_t>(bytes_written);
    CHECK(result <= slice.size());
    return result;
  }
  return OS_ERROR(PSLICE() << "Write to " << get_native_fd() << " has failed");
}

Result<size_t> FileFd::writev(Span<IoSlice> slices) {
#if TD_PORT_POSIX
  auto native_fd = get_native_fd().fd();
  TRY_RESULT(slices_size, narrow_cast_safe<int>(slices.size()));
  auto bytes_written = detail::skip_eintr([&] { return ::writev(native_fd, slices.begin(), slices_size); });
  bool success = bytes_written >= 0;
  if (success) {
    auto result = narrow_cast<size_t>(bytes_written);
    auto left = result;
    for (const auto &slice : slices) {
      if (left <= slice.iov_len) {
        return result;
      }
      left -= slice.iov_len;
    }
    UNREACHABLE();
  }
  return OS_ERROR(PSLICE() << "Writev to " << get_native_fd() << " has failed");
#else
  size_t res = 0;
  for (const auto &slice : slices) {
    if (slice.size() > std::numeric_limits<size_t>::max() - res) {
      break;
    }
    TRY_RESULT(size, write(slice));
    res += size;
    if (size != slice.size()) {
      CHECK(size < slice.size());
      break;
    }
  }
  return res;
#endif
}

Result<size_t> FileFd::read(MutableSlice slice) {
  auto native_fd = get_native_fd().fd();
#if TD_PORT_POSIX
  auto bytes_read = detail::skip_eintr([&] { return ::read(native_fd, slice.begin(), slice.size()); });
  bool success = bytes_read >= 0;
  if (!success) {
    auto read_errno = errno;
    if (read_errno == EAGAIN
#if EAGAIN != EWOULDBLOCK
        || read_errno == EWOULDBLOCK
#endif
    ) {
      success = true;
      bytes_read = 0;
    }
  }
  bool is_eof = success && narrow_cast<size_t>(bytes_read) < slice.size();
#elif TD_PORT_WINDOWS
  DWORD bytes_read = 0;
  BOOL success = ReadFile(native_fd, slice.data(), narrow_cast<DWORD>(slice.size()), &bytes_read, nullptr);
  bool is_eof = bytes_read == 0;
#endif
  if (success) {
    if (is_eof) {
      get_poll_info().clear_flags(PollFlags::Read());
    }
    auto result = narrow_cast<size_t>(bytes_read);
    CHECK(result <= slice.size());
    return result;
  }
  return OS_ERROR(PSLICE() << "Read from " << get_native_fd() << " has failed");
}

Result<size_t> FileFd::pwrite(Slice slice, int64 offset) {
  if (offset < 0) {
    return Status::Error("Offset must be non-negative");
  }
  auto native_fd = get_native_fd().fd();
#if TD_PORT_POSIX
  TRY_RESULT(offset_off_t, narrow_cast_safe<off_t>(offset));
  auto bytes_written =
      detail::skip_eintr([&] { return ::pwrite(native_fd, slice.begin(), slice.size(), offset_off_t); });
  bool success = bytes_written >= 0;
#elif TD_PORT_WINDOWS
  DWORD bytes_written = 0;
  OVERLAPPED overlapped;
  std::memset(&overlapped, 0, sizeof(overlapped));
  overlapped.Offset = static_cast<DWORD>(offset);
  overlapped.OffsetHigh = static_cast<DWORD>(offset >> 32);
  BOOL success = WriteFile(native_fd, slice.data(), narrow_cast<DWORD>(slice.size()), &bytes_written, &overlapped);
#endif
  if (success) {
    auto result = narrow_cast<size_t>(bytes_written);
    CHECK(result <= slice.size());
    return result;
  }
  return OS_ERROR(PSLICE() << "Pwrite to " << get_native_fd() << " at offset " << offset << " has failed");
}

Result<size_t> FileFd::pread(MutableSlice slice, int64 offset) const {
  if (offset < 0) {
    return Status::Error("Offset must be non-negative");
  }
  auto native_fd = get_native_fd().fd();
#if TD_PORT_POSIX
  TRY_RESULT(offset_off_t, narrow_cast_safe<off_t>(offset));
  auto bytes_read = detail::skip_eintr([&] { return ::pread(native_fd, slice.begin(), slice.size(), offset_off_t); });
  bool success = bytes_read >= 0;
#elif TD_PORT_WINDOWS
  DWORD bytes_read = 0;
  OVERLAPPED overlapped;
  std::memset(&overlapped, 0, sizeof(overlapped));
  overlapped.Offset = static_cast<DWORD>(offset);
  overlapped.OffsetHigh = static_cast<DWORD>(offset >> 32);
  BOOL success = ReadFile(native_fd, slice.data(), narrow_cast<DWORD>(slice.size()), &bytes_read, &overlapped);
#endif
  if (success) {
    auto result = narrow_cast<size_t>(bytes_read);
    CHECK(result <= slice.size());
    return result;
  }
  return OS_ERROR(PSLICE() << "Pread from " << get_native_fd() << " at offset " << offset << " has failed");
}

static std::mutex in_process_lock_mutex;
static FlatHashSet<string> locked_files;
static ExitGuard exit_guard;

static Status create_local_lock(const string &path, int32 &max_tries) {
  while (true) {
    {  // mutex lock scope
      std::lock_guard<std::mutex> lock(in_process_lock_mutex);
      if (!path.empty() && locked_files.count(path) == 0) {
        VLOG(fd) << "Lock file \"" << path << '"';
        locked_files.insert(path);
        return Status::OK();
      }
    }

    if (--max_tries <= 0) {
      return Status::Error(
          0, PSLICE() << "Can't lock file \"" << path << "\", because it is already in use by current program");
    }

    usleep_for(100000);
  }
}

Status FileFd::lock(LockFlags flags, const string &path, int32 max_tries) {
  if (max_tries <= 0) {
    return Status::Error("Can't lock file: wrong max_tries");
  }

  bool need_local_unlock = false;
  if (!path.empty()) {
    if (flags == LockFlags::Unlock) {
      need_local_unlock = true;
    } else if (flags == LockFlags::Read) {
      LOG(FATAL) << "Local locking in Read mode is unsupported";
    } else {
      CHECK(flags == LockFlags::Write);
      VLOG(fd) << "Trying to lock file \"" << path << '"';
      TRY_STATUS(create_local_lock(path, max_tries));
      need_local_unlock = true;
    }
  }
  SCOPE_EXIT {
    if (need_local_unlock) {
      remove_local_lock(path);
    }
  };

#if TD_PORT_POSIX
  auto native_fd = get_native_fd().fd();
#elif TD_PORT_WINDOWS
  auto native_fd = get_native_fd().fd();
#endif
  while (true) {
#if TD_PORT_POSIX
    struct flock lock;
    std::memset(&lock, 0, sizeof(lock));

    lock.l_type = static_cast<short>([&] {
      switch (flags) {
        case LockFlags::Read:
          return F_RDLCK;
        case LockFlags::Write:
          return F_WRLCK;
        case LockFlags::Unlock:
          return F_UNLCK;
        default:
          UNREACHABLE();
          return F_UNLCK;
      }
    }());

    lock.l_whence = SEEK_SET;
    if (fcntl(native_fd, F_SETLK, &lock) == -1) {
      if (errno == EAGAIN) {
#elif TD_PORT_WINDOWS
    OVERLAPPED overlapped;
    std::memset(&overlapped, 0, sizeof(overlapped));

    BOOL result;
    if (flags == LockFlags::Unlock) {
      result = UnlockFileEx(native_fd, 0, MAXDWORD, MAXDWORD, &overlapped);
    } else {
      DWORD dw_flags = LOCKFILE_FAIL_IMMEDIATELY;
      if (flags == LockFlags::Write) {
        dw_flags |= LOCKFILE_EXCLUSIVE_LOCK;
      }

      result = LockFileEx(native_fd, dw_flags, 0, MAXDWORD, MAXDWORD, &overlapped);
    }

    if (!result) {
      if (GetLastError() == ERROR_LOCK_VIOLATION) {
#endif
        if (--max_tries > 0) {
          usleep_for(100000);
          continue;
        }

        return OS_ERROR(PSLICE() << "Can't lock file \"" << path
                                 << "\", because it is already in use; check for another program instance running");
      }

      return OS_ERROR("Can't lock file");
    }

    break;
  }

  if (flags == LockFlags::Write) {
    need_local_unlock = false;
  }
  return Status::OK();
}

void FileFd::remove_local_lock(const string &path) {
  if (path.empty() || ExitGuard::is_exited()) {
    return;
  }
  VLOG(fd) << "Unlock file \"" << path << '"';
  std::unique_lock<std::mutex> lock(in_process_lock_mutex);
  auto erased_count = locked_files.erase(path);
  CHECK(erased_count > 0 || path.empty() || ExitGuard::is_exited());
}

void FileFd::close() {
  impl_.reset();
}

bool FileFd::empty() const {
  return !impl_;
}

const NativeFd &FileFd::get_native_fd() const {
  return get_poll_info().native_fd();
}

NativeFd FileFd::move_as_native_fd() {
  auto res = get_poll_info().move_as_native_fd();
  impl_.reset();
  return res;
}

#if TD_PORT_WINDOWS
namespace {

uint64 filetime_to_unix_time_nsec(LONGLONG filetime) {
  const auto FILETIME_UNIX_TIME_DIFF = 116444736000000000ll;
  return static_cast<uint64>((filetime - FILETIME_UNIX_TIME_DIFF) * 100);
}

struct FileSize {
  int64 size_;
  int64 real_size_;
};

Result<FileSize> get_file_size(const FileFd &file_fd) {
  FILE_STANDARD_INFO standard_info;
  if (!GetFileInformationByHandleEx(file_fd.get_native_fd().fd(), FileStandardInfo, &standard_info,
                                    sizeof(standard_info))) {
    return OS_ERROR("Get FileStandardInfo failed");
  }
  FileSize res;
  res.size_ = standard_info.EndOfFile.QuadPart;
  res.real_size_ = standard_info.AllocationSize.QuadPart;

  if (res.size_ > 0 && res.real_size_ <= 0) {  // just in case
    LOG(ERROR) << "Fix real file size from " << res.real_size_ << " to " << res.size_;
    res.real_size_ = res.size_;
  }

  return res;
}

}  // namespace
#endif

Result<int64> FileFd::get_size() const {
#if TD_PORT_POSIX
  TRY_RESULT(s, stat());
#elif TD_PORT_WINDOWS
  TRY_RESULT(s, get_file_size(*this));
#endif
  return s.size_;
}

Result<int64> FileFd::get_real_size() const {
#if TD_PORT_POSIX
  TRY_RESULT(s, stat());
#elif TD_PORT_WINDOWS
  TRY_RESULT(s, get_file_size(*this));
#endif
  return s.real_size_;
}

Result<Stat> FileFd::stat() const {
  CHECK(!empty());
#if TD_PORT_POSIX
  return detail::fstat(get_native_fd().fd());
#elif TD_PORT_WINDOWS
  Stat res;

  FILE_BASIC_INFO basic_info;
  auto status = GetFileInformationByHandleEx(get_native_fd().fd(), FileBasicInfo, &basic_info, sizeof(basic_info));
  if (!status) {
    return OS_ERROR("Get FileBasicInfo failed");
  }
  res.atime_nsec_ = filetime_to_unix_time_nsec(basic_info.LastAccessTime.QuadPart);
  res.mtime_nsec_ = filetime_to_unix_time_nsec(basic_info.LastWriteTime.QuadPart);
  res.is_dir_ = (basic_info.FileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0;
  if ((basic_info.FileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0) {
    FILE_ATTRIBUTE_TAG_INFO tag_info;
    status = GetFileInformationByHandleEx(get_native_fd().fd(), FileAttributeTagInfo, &tag_info, sizeof(tag_info));
    if (!status) {
      return OS_ERROR("Get FileAttributeTagInfo failed");
    }
    res.is_reg_ = false;
    res.is_symbolic_link_ =
        (tag_info.FileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0 && tag_info.ReparseTag == IO_REPARSE_TAG_SYMLINK;
  } else {
    res.is_reg_ = !res.is_dir_;
    res.is_symbolic_link_ = false;
  }

  TRY_RESULT(file_size, get_file_size(*this));
  res.size_ = file_size.size_;
  res.real_size_ = file_size.real_size_;

  return res;
#endif
}

Status FileFd::sync() {
  CHECK(!empty());
#if TD_PORT_POSIX
#if TD_DARWIN
  if (detail::skip_eintr([&] { return fcntl(get_native_fd().fd(), F_FULLFSYNC); }) == -1) {
#else
  if (detail::skip_eintr([&] { return fsync(get_native_fd().fd()); }) != 0) {
#endif
#elif TD_PORT_WINDOWS
  if (FlushFileBuffers(get_native_fd().fd()) == 0) {
#endif
    return OS_ERROR("Sync failed");
  }
  return Status::OK();
}

Status FileFd::sync_barrier() {
  CHECK(!empty());
#if TD_DARWIN && defined(F_BARRIERFSYNC)
  if (detail::skip_eintr([&] { return fcntl(get_native_fd().fd(), F_BARRIERFSYNC); }) != -1) {
    return Status::OK();
  }
#endif
  return sync();
}

Status FileFd::seek(int64 position) {
  CHECK(!empty());
#if TD_PORT_POSIX
  TRY_RESULT(position_off_t, narrow_cast_safe<off_t>(position));
  if (detail::skip_eintr([&] { return ::lseek(get_native_fd().fd(), position_off_t, SEEK_SET); }) < 0) {
#elif TD_PORT_WINDOWS
  LARGE_INTEGER offset;
  offset.QuadPart = position;
  if (SetFilePointerEx(get_native_fd().fd(), offset, nullptr, FILE_BEGIN) == 0) {
#endif
    return OS_ERROR("Seek failed");
  }
  return Status::OK();
}

Status FileFd::truncate_to_current_position(int64 current_position) {
  CHECK(!empty());
#if TD_PORT_POSIX
  TRY_RESULT(current_position_off_t, narrow_cast_safe<off_t>(current_position));
  if (detail::skip_eintr([&] { return ::ftruncate(get_native_fd().fd(), current_position_off_t); }) < 0) {
#elif TD_PORT_WINDOWS
  if (SetEndOfFile(get_native_fd().fd()) == 0) {
#endif
    return OS_ERROR("Truncate failed");
  }
  return Status::OK();
}
PollableFdInfo &FileFd::get_poll_info() {
  CHECK(!empty());
  return impl_->info_;
}
const PollableFdInfo &FileFd::get_poll_info() const {
  CHECK(!empty());
  return impl_->info_;
}

}  // namespace td
