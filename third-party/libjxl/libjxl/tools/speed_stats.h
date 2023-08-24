// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef TOOLS_SPEED_STATS_H_
#define TOOLS_SPEED_STATS_H_

#include <stddef.h>
#include <stdint.h>

#include <vector>

namespace jpegxl {
namespace tools {

class SpeedStats {
 public:
  void NotifyElapsed(double elapsed_seconds);

  struct Summary {
    // How central_tendency was computed - depends on number of reps.
    const char* type;

    // Elapsed time
    double central_tendency;
    double min;
    double max;
    double variability;
  };

  // Non-const, may sort elapsed_.
  bool GetSummary(Summary* summary);

  // Sets the image size to allow computing MP/s values.
  void SetImageSize(size_t xsize, size_t ysize) {
    xsize_ = xsize;
    ysize_ = ysize;
  }

  // Sets the file size to allow computing MB/s values.
  void SetFileSize(size_t file_size) { file_size_ = file_size; }

  // Calls GetSummary and prints megapixels/sec. SetImageSize() must be called
  // once before this can be used.
  bool Print(size_t worker_threads);

 private:
  std::vector<double> elapsed_;
  size_t xsize_ = 0;
  size_t ysize_ = 0;

  // Size of the source binary file, meaningful when decoding a recompressed
  // JPEG.
  size_t file_size_ = 0;
};

}  // namespace tools
}  // namespace jpegxl

#endif  // TOOLS_SPEED_STATS_H_
