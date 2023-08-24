// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef PLUGINS_GIMP_COMMON_H_
#define PLUGINS_GIMP_COMMON_H_

#include <libgimp/gimp.h>
#include <libgimp/gimpui.h>
#include <math.h>

#include <fstream>
#include <iterator>
#include <string>
#include <vector>

#define PLUG_IN_BINARY "file-jxl"
#define SAVE_PROC "file-jxl-save"

// Defined by both FUIF and glib.
#undef MAX
#undef MIN
#undef CLAMP

#include <jxl/resizable_parallel_runner.h>
#include <jxl/resizable_parallel_runner_cxx.h>

namespace jxl {

class JpegXlGimpProgress {
 public:
  explicit JpegXlGimpProgress(const char *message);
  void update();
  void finished();

 private:
  int cur_progress;
  int max_progress;

};  // class JpegXlGimpProgress

}  // namespace jxl

#endif  // PLUGINS_GIMP_COMMON_H_
