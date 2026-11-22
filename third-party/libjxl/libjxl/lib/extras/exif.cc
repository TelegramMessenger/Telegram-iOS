// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/extras/exif.h"

#include "lib/jxl/base/byte_order.h"

namespace jxl {

constexpr uint16_t kExifOrientationTag = 274;

void ResetExifOrientation(std::vector<uint8_t>& exif) {
  if (exif.size() < 12) return;  // not enough bytes for a valid exif blob
  bool bigendian;
  uint8_t* t = exif.data();
  if (LoadLE32(t) == 0x2A004D4D) {
    bigendian = true;
  } else if (LoadLE32(t) == 0x002A4949) {
    bigendian = false;
  } else {
    return;  // not a valid tiff header
  }
  t += 4;
  uint64_t offset = (bigendian ? LoadBE32(t) : LoadLE32(t));
  if (exif.size() < 12 + offset + 2 || offset < 8) return;
  t += offset - 4;
  uint16_t nb_tags = (bigendian ? LoadBE16(t) : LoadLE16(t));
  t += 2;
  while (nb_tags > 0) {
    if (t + 12 >= exif.data() + exif.size()) return;
    uint16_t tag = (bigendian ? LoadBE16(t) : LoadLE16(t));
    t += 2;
    if (tag == kExifOrientationTag) {
      uint16_t type = (bigendian ? LoadBE16(t) : LoadLE16(t));
      t += 2;
      uint32_t count = (bigendian ? LoadBE32(t) : LoadLE32(t));
      t += 4;
      if (type == 3 && count == 1) {
        if (bigendian) {
          StoreBE16(1, t);
        } else {
          StoreLE16(1, t);
        }
      }
      return;
    } else {
      t += 10;
      nb_tags--;
    }
  }
}

}  // namespace jxl
