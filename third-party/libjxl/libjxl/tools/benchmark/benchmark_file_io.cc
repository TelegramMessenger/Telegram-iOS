// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
#include "tools/benchmark/benchmark_file_io.h"

#include <errno.h>
#include <sys/stat.h>

#include <cstdio>

#if defined(_WIN32) || defined(_WIN64)
#include "third_party/dirent.h"
#else
#include <dirent.h>
#include <unistd.h>
#endif

#ifndef HAS_GLOB
#define HAS_GLOB 0
#if defined __has_include
// <glob.h> is included in previous APIs but glob() function is not defined
// until API 28.
#if __has_include(<glob.h>) && \
    (!defined(__ANDROID_API__) || __ANDROID_API__ >= 28)
#undef HAS_GLOB
#define HAS_GLOB 1
#endif  // __has_include(<glob.h>)
#endif  // __has_include
#endif  // HAS_GLOB

#if HAS_GLOB
#include <glob.h>
#endif  // HAS_GLOB

// There is no "user" in embedded filesystems.
#ifndef GLOB_TILDE
#define GLOB_TILDE 0
#endif

namespace jpegxl {
namespace tools {

const char kPathSeparator = '/';

// RAII, ensures dir is closed even when returning early.
class DirWrapper {
 public:
  DirWrapper(const DirWrapper& other) = delete;
  DirWrapper& operator=(const DirWrapper& other) = delete;

  explicit DirWrapper(const std::string& pathname)
      : dir_(opendir(pathname.c_str())) {}

  ~DirWrapper() {
    if (dir_ != nullptr) {
      const int err = closedir(dir_);
      JXL_CHECK(err == 0);
    }
  }

  // NOLINTNEXTLINE(google-explicit-constructor)
  operator DIR*() const { return dir_; }

 private:
  DIR* const dir_;
};

// Checks if the file exists, either as file or as directory
bool PathExists(const std::string& fname) {
  struct stat s;
  if (stat(fname.c_str(), &s) != 0) return false;
  return true;
}

// Checks if the file exists and is a regular file.
bool IsRegularFile(const std::string& fname) {
  struct stat s;
  if (stat(fname.c_str(), &s) != 0) return false;
  return S_ISREG(s.st_mode);
}

// Checks if the file exists and is a directory.
bool IsDirectory(const std::string& fname) {
  struct stat s;
  if (stat(fname.c_str(), &s) != 0) return false;
  return S_ISDIR(s.st_mode);
}

// Recursively makes dir, or successfully does nothing if it already exists.
Status MakeDir(const std::string& dirname) {
  size_t pos = 0;
  for (pos = dirname.size(); pos > 0; pos--) {
    if (pos == dirname.size() || dirname[pos] == kPathSeparator) {
      // Found existing dir or regular file, break and then start creating
      // from here (in the latter case we'll get error below).
      if (PathExists(dirname.substr(0, pos + 1))) {
        pos += 1;  // Skip past this existing path
        break;
      }
    }
  }
  for (; pos <= dirname.size(); pos++) {
    if (pos == dirname.size() || dirname[pos] == kPathSeparator) {
      std::string subdir = dirname.substr(0, pos + 1);
      if (mkdir(subdir.c_str(), 0777) && errno != EEXIST) {
        return JXL_FAILURE("Failed to create directory");
      }
    }
  }
  if (!IsDirectory(dirname)) return JXL_FAILURE("Failed to create directory");
  return true;  // success
}

Status DeleteFile(const std::string& fname) {
  if (!IsRegularFile(fname)) {
    return JXL_FAILURE("Trying to delete non-regular file");
  }
  if (std::remove(fname.c_str())) return JXL_FAILURE("Failed to delete file");
  return true;
}

std::string FileBaseName(const std::string& fname) {
  size_t pos = fname.rfind('/');
  if (pos == std::string::npos) return fname;
  return fname.substr(pos + 1);
}

std::string FileDirName(const std::string& fname) {
  size_t pos = fname.rfind('/');
  if (pos == std::string::npos) return "";
  return fname.substr(0, pos);
}

std::string FileExtension(const std::string& fname) {
  size_t pos = fname.rfind('.');
  if (pos == std::string::npos) return "";
  return fname.substr(pos);
}

std::string JoinPath(const std::string& first, const std::string& second) {
  JXL_CHECK(second.empty() || second[0] != kPathSeparator);
  return (!first.empty() && first.back() == kPathSeparator)
             ? (first + second)
             : (first + kPathSeparator + second);
}

// Can match a single file, or multiple files in a directory (non-recursive).
// With POSIX, supports glob(), otherwise supports a subset.
Status MatchFiles(const std::string& pattern, std::vector<std::string>* list) {
#if HAS_GLOB
  glob_t g;
  memset(&g, 0, sizeof(g));
  int error = glob(pattern.c_str(), GLOB_TILDE, NULL, &g);
  if (!error) {
    for (size_t i = 0; i < g.gl_pathc; ++i) {
      list->push_back(g.gl_pathv[i]);
    }
  }
  globfree(&g);
  if (error) return JXL_FAILURE("glob failed for %s", pattern.c_str());
  return true;
#else
  std::string dirname = FileDirName(pattern);
  std::string basename = FileBaseName(pattern);
  size_t pos0 = basename.find('*');
  size_t pos1 = pos0 == std::string::npos ? pos0 : basename.find('*', pos0 + 1);
  std::string prefix, middle, suffix;
  if (pos0 != std::string::npos) {
    prefix = basename.substr(0, pos0);
    if (pos1 != std::string::npos) {
      middle = basename.substr(pos0 + 1, pos1 - pos0 - 1);
      suffix = basename.substr(pos1 + 1);
    } else {
      suffix = basename.substr(pos0 + 1);
    }
  }

  if (prefix.find_first_of("*?[") != std::string::npos ||
      middle.find_first_of("*?[") != std::string::npos ||
      suffix.find_first_of("*?[") != std::string::npos ||
      dirname.find_first_of("*?[") != std::string::npos) {
    return JXL_FAILURE(
        "Only glob patterns with max two '*' in the basename"
        " are supported, e.g. directory/path/*.png or"
        " /directory/path/*heatmap*");
  }

  if (pos0 != std::string::npos) {
    DirWrapper dir(dirname);
    if (!dir) return JXL_FAILURE("directory %s doesn't exist", dirname.c_str());
    for (;;) {
      dirent* ent = readdir(dir);
      if (!ent) break;
      std::string name = ent->d_name;
      // If there was a suffix, only add if it matches (e.g. ".png")
      bool matches =
          name.size() >= (prefix.size() + middle.size() + suffix.size());
      if (matches) {
        if (!prefix.empty() && name.substr(0, prefix.size()) != prefix) {
          matches = false;
        }
        if (!middle.empty()) {
          size_t pos = name.find(middle, prefix.size());
          if (pos == std::string::npos ||
              pos + middle.size() > name.size() - suffix.size()) {
            matches = false;
          }
        }
        if (!suffix.empty() &&
            name.substr(name.size() - suffix.size()) != suffix) {
          matches = false;
        }
      }
      if (matches) {
        std::string path = JoinPath(dirname, name);

        if (IsRegularFile(path)) {
          list->push_back(path);
        }
      }
    }
    return true;
  }
  // No *, so a single regular file is intended
  if (IsRegularFile(pattern)) {
    list->push_back(pattern);
  }
  return true;
#endif  // HAS_GLOB
}

}  // namespace tools
}  // namespace jpegxl
