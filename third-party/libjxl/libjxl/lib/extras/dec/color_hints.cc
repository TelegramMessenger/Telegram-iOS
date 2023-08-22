// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/extras/dec/color_hints.h"

#include <jxl/encode.h>

#include <vector>

#include "lib/extras/dec/color_description.h"
#include "lib/jxl/base/status.h"

namespace jxl {
namespace extras {

Status ApplyColorHints(const ColorHints& color_hints,
                       const bool color_already_set, const bool is_gray,
                       PackedPixelFile* ppf) {
  bool got_color_space = color_already_set;

  JXL_RETURN_IF_ERROR(color_hints.Foreach(
      [color_already_set, is_gray, ppf, &got_color_space](
          const std::string& key, const std::string& value) -> Status {
        if (color_already_set && (key == "color_space" || key == "icc")) {
          JXL_WARNING("Decoder ignoring %s hint", key.c_str());
          return true;
        }
        if (key == "color_space") {
          JxlColorEncoding c_original_external;
          if (!ParseDescription(value, &c_original_external)) {
            return JXL_FAILURE("Failed to apply color_space");
          }
          ppf->color_encoding = c_original_external;

          if (is_gray !=
              (ppf->color_encoding.color_space == JXL_COLOR_SPACE_GRAY)) {
            return JXL_FAILURE("mismatch between file and color_space hint");
          }

          got_color_space = true;
        } else if (key == "icc") {
          const uint8_t* data = reinterpret_cast<const uint8_t*>(value.data());
          std::vector<uint8_t> icc(data, data + value.size());
          ppf->icc.swap(icc);
          got_color_space = true;
        } else if (key == "exif") {
          const uint8_t* data = reinterpret_cast<const uint8_t*>(value.data());
          std::vector<uint8_t> blob(data, data + value.size());
          ppf->metadata.exif.swap(blob);
        } else if (key == "xmp") {
          const uint8_t* data = reinterpret_cast<const uint8_t*>(value.data());
          std::vector<uint8_t> blob(data, data + value.size());
          ppf->metadata.xmp.swap(blob);
        } else if (key == "jumbf") {
          const uint8_t* data = reinterpret_cast<const uint8_t*>(value.data());
          std::vector<uint8_t> blob(data, data + value.size());
          ppf->metadata.jumbf.swap(blob);
        } else {
          JXL_WARNING("Ignoring %s hint", key.c_str());
        }
        return true;
      }));

  if (!got_color_space) {
    ppf->color_encoding.color_space =
        is_gray ? JXL_COLOR_SPACE_GRAY : JXL_COLOR_SPACE_RGB;
    ppf->color_encoding.white_point = JXL_WHITE_POINT_D65;
    ppf->color_encoding.primaries = JXL_PRIMARIES_SRGB;
    ppf->color_encoding.transfer_function = JXL_TRANSFER_FUNCTION_SRGB;
  }

  return true;
}

}  // namespace extras
}  // namespace jxl
