// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_EXTRAS_COLOR_HINTS_H_
#define LIB_EXTRAS_COLOR_HINTS_H_

// Not all the formats implemented in the extras lib support bundling color
// information into the file, and those that support it may not have it.
// To allow attaching color information to those file formats the caller can
// define these color hints.
// Besides color space information, 'ColorHints' may also include other
// additional information such as Exif, XMP and JUMBF metadata.

#include <stddef.h>
#include <stdint.h>

#include <string>
#include <vector>

#include "lib/extras/packed_image.h"
#include "lib/jxl/base/status.h"

namespace jxl {
namespace extras {

class ColorHints {
 public:
  // key=color_space, value=Description(c/pp): specify the ColorEncoding of
  //   the pixels for decoding. Otherwise, if the codec did not obtain an ICC
  //   profile from the image, assume sRGB.
  //
  // Strings are taken from the command line, so avoid spaces for convenience.
  void Add(const std::string& key, const std::string& value) {
    kv_.emplace_back(key, value);
  }

  // Calls `func(key, value)` for each key/value in the order they were added,
  // returning false immediately if `func` returns false.
  template <class Func>
  Status Foreach(const Func& func) const {
    for (const KeyValue& kv : kv_) {
      Status ok = func(kv.key, kv.value);
      if (!ok) {
        return JXL_FAILURE("ColorHints::Foreach returned false");
      }
    }
    return true;
  }

 private:
  // Splitting into key/value avoids parsing in each codec.
  struct KeyValue {
    KeyValue(std::string key, std::string value)
        : key(std::move(key)), value(std::move(value)) {}

    std::string key;
    std::string value;
  };

  std::vector<KeyValue> kv_;
};

// Apply the color hints to the decoded image in PackedPixelFile if any.
// color_already_set tells whether the color encoding was already set, in which
// case the hints are ignored if any hint is passed.
Status ApplyColorHints(const ColorHints& color_hints, bool color_already_set,
                       bool is_gray, PackedPixelFile* ppf);

}  // namespace extras
}  // namespace jxl

#endif  // LIB_EXTRAS_COLOR_HINTS_H_
