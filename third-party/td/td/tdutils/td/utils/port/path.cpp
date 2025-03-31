//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/port/path.h"

#include "td/utils/port/config.h"

#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/port/detail/skip_eintr.h"
#include "td/utils/ScopeGuard.h"
#include "td/utils/SliceBuilder.h"

#if TD_PORT_WINDOWS
#include "td/utils/port/FromApp.h"
#include "td/utils/port/wstring_convert.h"
#include "td/utils/Random.h"
#endif

#if TD_PORT_POSIX

#include <dirent.h>
#include <limits.h>
#include <stdio.h>

// We don't want warnings from system headers
#if TD_GCC
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wconversion"
#endif
#include <sys/stat.h>
#if TD_GCC
#pragma GCC diagnostic pop
#endif

#include <sys/types.h>
#include <unistd.h>

#endif

#if TD_DARWIN
#include <sys/syslimits.h>
#endif

#include <cerrno>
#include <cstdlib>
#include <string>

namespace td {

static string temporary_dir;

Status set_temporary_dir(CSlice dir) {
  string input_dir = dir.str();
  if (!dir.empty() && dir.back() != TD_DIR_SLASH) {
    input_dir += TD_DIR_SLASH;
  }
  TRY_STATUS(mkpath(input_dir, 0750));
  TRY_RESULT_ASSIGN(temporary_dir, realpath(input_dir));
  return Status::OK();
}

Status mkpath(CSlice path, int32 mode) {
  Status first_error = Status::OK();
  Status last_error = Status::OK();
  for (size_t i = 1; i < path.size(); i++) {
    if (path[i] == TD_DIR_SLASH) {
      last_error = mkdir(PSLICE() << path.substr(0, i), mode);
      if (last_error.is_error() && first_error.is_ok()) {
        first_error = last_error.clone();
      }
    }
  }
  if (last_error.is_error()) {
    if (last_error.message() == first_error.message() && last_error.code() == first_error.code()) {
      return first_error;
    }
    return last_error.move_as_error_suffix(PSLICE() << ": " << first_error);
  }
  return Status::OK();
}

Status rmrf(CSlice path) {
  return walk_path(path, [](CSlice path, WalkPath::Type type) {
    switch (type) {
      case WalkPath::Type::EnterDir:
        break;
      case WalkPath::Type::ExitDir:
        rmdir(path).ignore();
        break;
      case WalkPath::Type::RegularFile:
        unlink(path).ignore();
        break;
      case WalkPath::Type::Symlink:
        // never follow symbolic links, but delete the link themselves
        unlink(path).ignore();
        break;
    }
  });
}

#if TD_PORT_POSIX

Status mkdir(CSlice dir, int32 mode) {
  int mkdir_res = [&] {
    int res;
    do {
      errno = 0;  // just in case
      res = ::mkdir(dir.c_str(), static_cast<mode_t>(mode));
    } while (res < 0 && (errno == EINTR || errno == EAGAIN));
    return res;
  }();
  if (mkdir_res == 0) {
    return Status::OK();
  }
  auto mkdir_errno = errno;
  if (mkdir_errno == EEXIST) {
    // TODO check that it is a directory
    return Status::OK();
  }
  return Status::PosixError(mkdir_errno, PSLICE() << "Can't create directory \"" << dir << '"');
}

Status rename(CSlice from, CSlice to) {
  int rename_res = detail::skip_eintr([&] { return ::rename(from.c_str(), to.c_str()); });
  if (rename_res < 0) {
    return OS_ERROR(PSLICE() << "Can't rename \"" << from << "\" to \"" << to << '\"');
  }
  return Status::OK();
}

Result<string> realpath(CSlice slice, bool ignore_access_denied) {
  char full_path[PATH_MAX + 1];
  string res;
  char *err = detail::skip_eintr_cstr([&] { return ::realpath(slice.c_str(), full_path); });
  if (err != full_path) {
    if (ignore_access_denied && (errno == EACCES || errno == EPERM)) {
      res = slice.str();
    } else {
      return OS_ERROR(PSLICE() << "Realpath failed for \"" << slice << '"');
    }
  } else {
    res = full_path;
  }
  if (res.empty()) {
    return Status::Error("Empty path");
  }
  if (!slice.empty() && slice.end()[-1] == TD_DIR_SLASH) {
    if (res.back() != TD_DIR_SLASH) {
      res += TD_DIR_SLASH;
    }
  }
  return res;
}

Status chdir(CSlice dir) {
  int chdir_res = detail::skip_eintr([&] { return ::chdir(dir.c_str()); });
  if (chdir_res) {
    return OS_ERROR(PSLICE() << "Can't change directory to \"" << dir << '"');
  }
  return Status::OK();
}

Status rmdir(CSlice dir) {
  int rmdir_res = detail::skip_eintr([&] { return ::rmdir(dir.c_str()); });
  if (rmdir_res) {
    return OS_ERROR(PSLICE() << "Can't delete directory \"" << dir << '"');
  }
  return Status::OK();
}

Status unlink(CSlice path) {
  int unlink_res = detail::skip_eintr([&] { return ::unlink(path.c_str()); });
  if (unlink_res) {
    return OS_ERROR(PSLICE() << "Can't unlink \"" << path << '"');
  }
  return Status::OK();
}

CSlice get_temporary_dir() {
  static bool is_inited = [] {
    if (temporary_dir.empty()) {
      const char *s = std::getenv("TMPDIR");
      if (s != nullptr && s[0] != '\0') {
        temporary_dir = s;
      } else if (P_tmpdir != nullptr && P_tmpdir[0] != '\0') {
        temporary_dir = P_tmpdir;
      } else {
        return false;
      }
    }
    if (temporary_dir.size() > 1 && temporary_dir.back() == TD_DIR_SLASH) {
      temporary_dir.pop_back();
    }
    return true;
  }();
  LOG_IF(FATAL, !is_inited) << "Can't find temporary directory";
  return temporary_dir;
}

Result<std::pair<FileFd, string>> mkstemp(CSlice dir) {
  if (dir.empty()) {
    dir = get_temporary_dir();
    if (dir.empty()) {
      return Status::Error("Can't find temporary directory");
    }
  }

  TRY_RESULT(dir_real, realpath(dir));
  CHECK(!dir_real.empty());

  string file_pattern;
  file_pattern.reserve(dir_real.size() + 14);
  file_pattern = dir_real;
  if (file_pattern.back() != TD_DIR_SLASH) {
    file_pattern += TD_DIR_SLASH;
  }
  file_pattern += "tmpXXXXXXXXXX";

  int fd = detail::skip_eintr([&] { return ::mkstemp(&file_pattern[0]); });
  if (fd == -1) {
    return OS_ERROR(PSLICE() << "Can't create temporary file \"" << file_pattern << '"');
  }
  if (close(fd)) {
    return OS_ERROR(PSLICE() << "Can't close temporary file \"" << file_pattern << '"');
  }
  // TODO create file from fd
  TRY_RESULT(file, FileFd::open(file_pattern, FileFd::Write | FileFd::Truncate | FileFd::Append));
  return std::make_pair(std::move(file), std::move(file_pattern));
}

Result<string> mkdtemp(CSlice dir, Slice prefix) {
  if (dir.empty()) {
    dir = get_temporary_dir();
    if (dir.empty()) {
      return Status::Error("Can't find temporary directory");
    }
  }

  TRY_RESULT(dir_real, realpath(dir));
  CHECK(!dir_real.empty());

  string dir_pattern;
  dir_pattern.reserve(dir_real.size() + prefix.size() + 7);
  dir_pattern = dir_real;
  if (dir_pattern.back() != TD_DIR_SLASH) {
    dir_pattern += TD_DIR_SLASH;
  }
  dir_pattern.append(prefix.begin(), prefix.size());
  dir_pattern += "XXXXXX";

  char *result = detail::skip_eintr_cstr([&] { return ::mkdtemp(&dir_pattern[0]); });
  if (result == nullptr) {
    return OS_ERROR(PSLICE() << "Can't create temporary directory \"" << dir_pattern << '"');
  }
  return result;
}

namespace detail {
using WalkFunction = std::function<WalkPath::Action(CSlice name, WalkPath::Type type)>;
Result<bool> walk_path_dir(string &path, FileFd fd, const WalkFunction &func) TD_WARN_UNUSED_RESULT;

Result<bool> walk_path_dir(string &path, const WalkFunction &func) TD_WARN_UNUSED_RESULT;

Result<bool> walk_path_file(string &path, const WalkFunction &func) TD_WARN_UNUSED_RESULT;

Result<bool> walk_path_symlink(string &path, const WalkFunction &func) TD_WARN_UNUSED_RESULT;

Result<bool> walk_path(string &path, const WalkFunction &func) TD_WARN_UNUSED_RESULT;

Result<bool> walk_path_subdir(string &path, DIR *dir, const WalkFunction &func) {
  while (true) {
    errno = 0;
    auto *entry = readdir(dir);
    auto readdir_errno = errno;
    if (readdir_errno) {
      return Status::PosixError(readdir_errno, "readdir");
    }
    if (entry == nullptr) {
      return true;
    }
    Slice name = Slice(static_cast<const char *>(entry->d_name));
    if (name == "." || name == "..") {
      continue;
    }
    auto size = path.size();
    if (path.back() != TD_DIR_SLASH) {
      path += TD_DIR_SLASH;
    }
    path.append(name.begin(), name.size());
    SCOPE_EXIT {
      path.resize(size);
    };
    Result<bool> status = true;
#ifdef DT_DIR
    if (entry->d_type == DT_UNKNOWN) {
      status = walk_path(path, func);
    } else if (entry->d_type == DT_DIR) {
      status = walk_path_dir(path, func);
    } else if (entry->d_type == DT_REG) {
      status = walk_path_file(path, func);
    } else if (entry->d_type == DT_LNK) {
      status = walk_path_symlink(path, func);
    }
#else
#if !TD_SOLARIS
#warning "Slow walk_path"
#endif
    status = walk_path(path, func);
#endif
    if (status.is_error() || !status.ok()) {
      return status;
    }
  }
}

Result<bool> walk_path_dir(string &path, DIR *subdir, const WalkFunction &func) {
  SCOPE_EXIT {
    closedir(subdir);
  };
  switch (func(path, WalkPath::Type::EnterDir)) {
    case WalkPath::Action::Abort:
      return false;
    case WalkPath::Action::SkipDir:
      return true;
    case WalkPath::Action::Continue:
      break;
  }
  auto status = walk_path_subdir(path, subdir, func);
  if (status.is_error() || !status.ok()) {
    return status;
  }
  switch (func(path, WalkPath::Type::ExitDir)) {
    case WalkPath::Action::Abort:
      return false;
    case WalkPath::Action::SkipDir:
    case WalkPath::Action::Continue:
      break;
  }
  return true;
}

Result<bool> walk_path_dir(string &path, FileFd fd, const WalkFunction &func) {
  auto native_fd = fd.move_as_native_fd();
  auto *subdir = fdopendir(native_fd.fd());
  if (subdir == nullptr) {
    return OS_ERROR("fdopendir");
  }
  native_fd.release();
  return walk_path_dir(path, subdir, func);
}

Result<bool> walk_path_dir(string &path, const WalkFunction &func) {
  auto *subdir = opendir(path.c_str());
  if (subdir == nullptr) {
    return OS_ERROR(PSLICE() << tag("opendir", path));
  }
  return walk_path_dir(path, subdir, func);
}

Result<bool> walk_path_file(string &path, const WalkFunction &func) {
  switch (func(path, WalkPath::Type::RegularFile)) {
    case WalkPath::Action::Abort:
      return false;
    case WalkPath::Action::SkipDir:
    case WalkPath::Action::Continue:
      break;
  }
  return true;
}

Result<bool> walk_path_symlink(string &path, const WalkFunction &func) {
  switch (func(path, WalkPath::Type::Symlink)) {
    case WalkPath::Action::Abort:
      return false;
    case WalkPath::Action::SkipDir:
    case WalkPath::Action::Continue:
      break;
  }
  return true;
}

Result<bool> walk_path(string &path, const WalkFunction &func) {
  TRY_RESULT(fd, FileFd::open(path, FileFd::Read));
  TRY_RESULT(stat, fd.stat());

  if (stat.is_dir_) {
    return walk_path_dir(path, std::move(fd), func);
  }

  fd.close();

  if (stat.is_reg_) {
    return walk_path_file(path, func);
  }

  if (stat.is_symbolic_link_) {
    return walk_path_symlink(path, func);
  }

  return true;
}
}  // namespace detail

Status WalkPath::do_run(CSlice path, const detail::WalkFunction &func) {
  string curr_path;
  curr_path.reserve(PATH_MAX + 10);
  curr_path = path.c_str();
  TRY_STATUS(detail::walk_path(curr_path, func));
  return Status::OK();
}

#endif

#if TD_PORT_WINDOWS

Status mkdir(CSlice dir, int32 mode) {
  TRY_RESULT(wdir, to_wstring(dir));
  while (!wdir.empty() && (wdir.back() == L'/' || wdir.back() == L'\\')) {
    wdir.pop_back();
  }
  auto status = td::CreateDirectoryFromAppW(wdir.c_str(), nullptr);
  if (status == 0 && GetLastError() != ERROR_ALREADY_EXISTS) {
    return OS_ERROR(PSLICE() << "Can't create directory \"" << dir << '"');
  }
  return Status::OK();
}

Status rename(CSlice from, CSlice to) {
  TRY_RESULT(wfrom, to_wstring(from));
  TRY_RESULT(wto, to_wstring(to));
  auto status = td::MoveFileExFromAppW(wfrom.c_str(), wto.c_str(), MOVEFILE_REPLACE_EXISTING);
  if (status == 0) {
    return OS_ERROR(PSLICE() << "Can't rename \"" << from << "\" to \"" << to << '\"');
  }
  return Status::OK();
}

Result<string> realpath(CSlice slice, bool ignore_access_denied) {
  wchar_t buf[MAX_PATH + 1];
  TRY_RESULT(wslice, to_wstring(slice));
  auto status = GetFullPathNameW(wslice.c_str(), MAX_PATH, buf, nullptr);
  string res;
  if (status == 0) {
    if (ignore_access_denied && errno == ERROR_ACCESS_DENIED) {
      res = slice.str();
    } else {
      return OS_ERROR(PSLICE() << "GetFullPathNameW failed for \"" << slice << '"');
    }
  } else {
    TRY_RESULT_ASSIGN(res, from_wstring(buf));
  }
  if (res.empty()) {
    return Status::Error("Empty path");
  }
  // TODO GetFullPathName doesn't resolve symbolic links
  if (!slice.empty() && slice.end()[-1] == TD_DIR_SLASH) {
    if (res.back() != TD_DIR_SLASH) {
      res += TD_DIR_SLASH;
    }
  }
  return res;
}

Status chdir(CSlice dir) {
  TRY_RESULT(wdir, to_wstring(dir));
  auto res = SetCurrentDirectoryW(wdir.c_str());
  if (res == 0) {
    return OS_ERROR(PSLICE() << "Can't change directory to \"" << dir << '"');
  }
  return Status::OK();
}

Status rmdir(CSlice dir) {
  TRY_RESULT(wdir, to_wstring(dir));
  int status = td::RemoveDirectoryFromAppW(wdir.c_str());
  if (!status) {
    return OS_ERROR(PSLICE() << "Can't delete directory \"" << dir << '"');
  }
  return Status::OK();
}

Status unlink(CSlice path) {
  TRY_RESULT(wpath, to_wstring(path));
  int status = td::DeleteFileFromAppW(wpath.c_str());
  if (!status) {
    return OS_ERROR(PSLICE() << "Can't unlink \"" << path << '"');
  }
  return Status::OK();
}

CSlice get_temporary_dir() {
  static bool is_inited = [] {
    if (temporary_dir.empty()) {
      wchar_t buf[MAX_PATH + 1];
      if (GetTempPathW(MAX_PATH, buf) == 0) {
        auto error = OS_ERROR("GetTempPathW failed");
        LOG(FATAL) << error;
      }
      auto rs = from_wstring(buf);
      LOG_IF(FATAL, rs.is_error()) << "GetTempPathW failed: " << rs.error();
      temporary_dir = rs.move_as_ok();
    }
    if (temporary_dir.size() > 1 && temporary_dir.back() == TD_DIR_SLASH) {
      temporary_dir.pop_back();
    }
    return true;
  }();
  LOG_IF(FATAL, !is_inited) << "Can't find temporary directory";
  return temporary_dir;
}

Result<string> mkdtemp(CSlice dir, Slice prefix) {
  if (dir.empty()) {
    dir = get_temporary_dir();
    if (dir.empty()) {
      return Status::Error("Can't find temporary directory");
    }
  }

  TRY_RESULT(dir_real, realpath(dir));
  CHECK(!dir_real.empty());

  string dir_pattern;
  dir_pattern.reserve(dir_real.size() + prefix.size() + 7);
  dir_pattern = dir_real;
  if (dir_pattern.back() != TD_DIR_SLASH) {
    dir_pattern += TD_DIR_SLASH;
  }
  dir_pattern.append(prefix.begin(), prefix.size());

  for (auto iter = 0; iter < 20; iter++) {
    auto path = dir_pattern;
    for (int i = 0; i < 6 + iter / 5; i++) {
      path += static_cast<char>(Random::fast('a', 'z'));
    }
    auto status = mkdir(path);
    if (status.is_ok()) {
      return path;
    }
  }
  return Status::Error(PSLICE() << "Can't create temporary directory \"" << dir_pattern << '"');
}

Result<std::pair<FileFd, string>> mkstemp(CSlice dir) {
  if (dir.empty()) {
    dir = get_temporary_dir();
    if (dir.empty()) {
      return Status::Error("Can't find temporary directory");
    }
  }

  TRY_RESULT(dir_real, realpath(dir));
  CHECK(!dir_real.empty());

  string file_pattern;
  file_pattern.reserve(dir_real.size() + 14);
  file_pattern = dir_real;
  if (file_pattern.back() != TD_DIR_SLASH) {
    file_pattern += TD_DIR_SLASH;
  }
  file_pattern += "tmp";

  for (auto iter = 0; iter < 20; iter++) {
    auto path = file_pattern;
    for (int i = 0; i < 6 + iter / 5; i++) {
      path += static_cast<char>(Random::fast('a', 'z'));
    }
    auto r_file = FileFd::open(path, FileFd::Write | FileFd::Read | FileFd::CreateNew);
    if (r_file.is_ok()) {
      return std::make_pair(r_file.move_as_ok(), path);
    }
  }

  return Status::Error(PSLICE() << "Can't create temporary file \"" << file_pattern << '"');
}

static Result<bool> walk_path_dir(const std::wstring &dir_name,
                                  const std::function<WalkPath::Action(CSlice name, WalkPath::Type type)> &func) {
  std::wstring name = dir_name + L"\\*";
  WIN32_FIND_DATA file_data;
  auto handle =
      td::FindFirstFileExFromAppW(name.c_str(), FindExInfoStandard, &file_data, FindExSearchNameMatch, nullptr, 0);
  if (handle == INVALID_HANDLE_VALUE) {
    return OS_ERROR(PSLICE() << "FindFirstFileEx" << tag("name", from_wstring(name).ok()));
  }

  SCOPE_EXIT {
    FindClose(handle);
  };

  TRY_RESULT(dir_entry_name, from_wstring(dir_name));
  switch (func(dir_entry_name, WalkPath::Type::EnterDir)) {
    case WalkPath::Action::Abort:
      return false;
    case WalkPath::Action::SkipDir:
      return true;
    case WalkPath::Action::Continue:
      break;
  }

  while (true) {
    auto full_name = dir_name + L"\\" + file_data.cFileName;
    TRY_RESULT(entry_name, from_wstring(full_name));
    if (file_data.cFileName[0] != '.') {
      if ((file_data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0) {
        TRY_RESULT(is_ok, walk_path_dir(full_name, func));
        if (!is_ok) {
          return false;
        }
      } else if ((file_data.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) == 0) {
        switch (func(entry_name, WalkPath::Type::RegularFile)) {
          case WalkPath::Action::Abort:
            return false;
          case WalkPath::Action::SkipDir:
          case WalkPath::Action::Continue:
            break;
        }
      } else if (file_data.dwReserved0 == IO_REPARSE_TAG_SYMLINK) {
        switch (func(entry_name, WalkPath::Type::Symlink)) {
          case WalkPath::Action::Abort:
            return false;
          case WalkPath::Action::SkipDir:
          case WalkPath::Action::Continue:
            break;
        }
      } else {
        // skip other reparse points
      }
    }
    auto status = FindNextFileW(handle, &file_data);
    if (status == 0) {
      auto last_error = GetLastError();
      if (last_error == ERROR_NO_MORE_FILES) {
        break;
      }
      return OS_ERROR("FindNextFileW");
    }
  }
  switch (func(dir_entry_name, WalkPath::Type::ExitDir)) {
    case WalkPath::Action::Abort:
      return false;
    case WalkPath::Action::SkipDir:
    case WalkPath::Action::Continue:
      break;
  }
  return true;
}

Status WalkPath::do_run(CSlice path, const std::function<Action(CSlice name, Type)> &func) {
  TRY_RESULT(wpath, to_wstring(path));
  Slice path_slice = path;
  while (!path_slice.empty() && (path_slice.back() == '/' || path_slice.back() == '\\')) {
    path_slice.remove_suffix(1);
    wpath.pop_back();
  }
  TRY_STATUS(walk_path_dir(wpath, func));
  return Status::OK();
}

#endif

}  // namespace td
