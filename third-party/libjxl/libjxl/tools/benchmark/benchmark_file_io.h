// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// File utilities for benchmarking and testing, but which are not needed for
// main jxl itself.

#ifndef TOOLS_BENCHMARK_BENCHMARK_FILE_IO_H_
#define TOOLS_BENCHMARK_BENCHMARK_FILE_IO_H_

#include <string>
#include <vector>

#include "lib/jxl/base/status.h"
#include "tools/file_io.h"

namespace jpegxl {
namespace tools {

using ::jxl::Status;

// Checks if the file exists, either as file or as directory
bool PathExists(const std::string& fname);

// Checks if the file exists and is a regular file.
bool IsRegularFile(const std::string& fname);

// Checks if the file exists and is a directory.
bool IsDirectory(const std::string& fname);

// Recursively makes dir, or successfully does nothing if it already exists.
Status MakeDir(const std::string& dirname);

// Deletes a single regular file.
Status DeleteFile(const std::string& fname);

// Returns value similar to unix basename, except it returns empty string if
// fname ends in '/'.
std::string FileBaseName(const std::string& fname);
// Returns value similar to unix dirname, except returns up to before the last
// slash if fname ends in '/'.
std::string FileDirName(const std::string& fname);

// Returns the part of the filename starting from the last dot, or empty
// string if there is no dot.
std::string FileExtension(const std::string& fname);

// Matches one or more files given glob pattern.
Status MatchFiles(const std::string& pattern, std::vector<std::string>* list);

std::string JoinPath(const std::string& first, const std::string& second);

}  // namespace tools
}  // namespace jpegxl

#endif  // TOOLS_BENCHMARK_BENCHMARK_FILE_IO_H_
