// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef TOOLS_BENCHMARK_BENCHMARK_UTILS_H_
#define TOOLS_BENCHMARK_BENCHMARK_UTILS_H_

#include <string>
#include <vector>

#include "lib/jxl/base/status.h"

namespace jpegxl {
namespace tools {

using ::jxl::Status;

class TemporaryFile final {
 public:
  explicit TemporaryFile(std::string basename, std::string extension);
  TemporaryFile(const TemporaryFile&) = delete;
  TemporaryFile& operator=(const TemporaryFile&) = delete;
  ~TemporaryFile();
  Status GetFileName(std::string* output) const;

 private:
  bool ok_ = true;

  std::string temp_filename_;
};

std::string GetBaseName(std::string filename);

Status RunCommand(const std::string& command,
                  const std::vector<std::string>& arguments,
                  bool quiet = false);

}  // namespace tools
}  // namespace jpegxl

#endif  // TOOLS_BENCHMARK_BENCHMARK_UTILS_H_
