// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#define _DEFAULT_SOURCE  // for mkstemps().

#include "tools/benchmark/benchmark_utils.h"

// Not supported on Windows due to Linux-specific functions.
// Not supported in Android NDK before API 28.
#if !defined(_WIN32) && !defined(__EMSCRIPTEN__) && \
    (!defined(__ANDROID_API__) || __ANDROID_API__ >= 28)

#include <libgen.h>
#include <spawn.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#include <fstream>

#include "lib/jxl/image_bundle.h"
#include "tools/file_io.h"

extern char** environ;

namespace jpegxl {
namespace tools {
TemporaryFile::TemporaryFile(std::string basename, std::string extension) {
  const auto extension_size = 1 + extension.size();
  temp_filename_ = std::move(basename) + "_XXXXXX." + std::move(extension);
  const int fd = mkstemps(&temp_filename_[0], extension_size);
  if (fd == -1) {
    ok_ = false;
    return;
  }
  close(fd);
}
TemporaryFile::~TemporaryFile() {
  if (ok_) {
    unlink(temp_filename_.c_str());
  }
}

Status TemporaryFile::GetFileName(std::string* const output) const {
  JXL_RETURN_IF_ERROR(ok_);
  *output = temp_filename_;
  return true;
}

std::string GetBaseName(std::string filename) {
  std::string result = std::move(filename);
  result = basename(&result[0]);
  const size_t dot = result.rfind('.');
  if (dot != std::string::npos) {
    result.resize(dot);
  }
  return result;
}

Status RunCommand(const std::string& command,
                  const std::vector<std::string>& arguments, bool quiet) {
  std::vector<char*> args;
  args.reserve(arguments.size() + 2);
  args.push_back(const_cast<char*>(command.c_str()));
  for (const std::string& argument : arguments) {
    args.push_back(const_cast<char*>(argument.c_str()));
  }
  args.push_back(nullptr);
  pid_t pid;
  posix_spawn_file_actions_t file_actions;
  posix_spawn_file_actions_init(&file_actions);
  if (quiet) {
    posix_spawn_file_actions_addclose(&file_actions, STDOUT_FILENO);
    posix_spawn_file_actions_addclose(&file_actions, STDERR_FILENO);
  }
  JXL_RETURN_IF_ERROR(posix_spawnp(&pid, command.c_str(), &file_actions,
                                   nullptr, args.data(), environ) == 0);
  int wstatus;
  waitpid(pid, &wstatus, 0);
  posix_spawn_file_actions_destroy(&file_actions);
  return WIFEXITED(wstatus) && WEXITSTATUS(wstatus) == EXIT_SUCCESS;
}

}  // namespace tools
}  // namespace jpegxl

#else

namespace jpegxl {
namespace tools {

TemporaryFile::TemporaryFile(std::string basename, std::string extension) {}
TemporaryFile::~TemporaryFile() {}
Status TemporaryFile::GetFileName(std::string* const output) const {
  (void)ok_;
  return JXL_FAILURE("Not supported on this build");
}

std::string GetBaseName(std::string filename) { return filename; }

Status RunCommand(const std::string& command,
                  const std::vector<std::string>& arguments, bool quiet) {
  return JXL_FAILURE("Not supported on this build");
}

}  // namespace tools
}  // namespace jpegxl

#endif  // _MSC_VER
