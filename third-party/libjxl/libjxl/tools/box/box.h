// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Tools for reading from / writing to ISOBMFF format for JPEG XL.

#ifndef TOOLS_BOX_BOX_H_
#define TOOLS_BOX_BOX_H_

#include <stddef.h>
#include <stdint.h>

#include <string>
#include <utility>
#include <vector>

#include "lib/jxl/base/padded_bytes.h"
#include "lib/jxl/base/status.h"

namespace jpegxl {
namespace tools {

// A top-level box in the box format.
struct Box {
  // The type of the box.
  // If "uuid", use extended_type instead
  char type[4];

  // The extended_type is only used when type == "uuid".
  // Extended types are not used in JXL. However, the box format itself
  // supports this so they are handled correctly.
  char extended_type[16];

  // Size of the data, excluding box header. The box ends, and next box
  // begins, at data + size. May not be used if data_size_given is false.
  uint64_t data_size;

  // If the size is not given, the datasize extends to the end of the file.
  // If this field is false, the size field may not be used.
  bool data_size_given;
};

// Parses the header of a BMFF box. Returns the result in a Box struct.
// Updates next_in and available_in to point at the data in the box, directly
// after the header.
// Sets the data_size if known, or must be handled by the caller and runs until
// the end of the container file if not known.
// NOTE: available_in should be at least 8 up to 32 bytes to parse the
// header without error.
jxl::Status ParseBoxHeader(const uint8_t** next_in, size_t* available_in,
                           Box* box);

// TODO(lode): streaming C API
jxl::Status AppendBoxHeader(const Box& box, jxl::PaddedBytes* out);

// NOTE: after DecodeJpegXlContainerOneShot, the exif etc. pointers point to
// regions within the input data passed to that function.
struct JpegXlContainer {
  // Exif metadata, or null if not present in the container.
  // The exif data has the format of 'Exif block' as defined in
  // ISO/IEC23008-12:2017 Clause A.2.1
  // Here we assume the tiff header offset is 0 and store only the
  // actual Exif data (starting with the tiff header MM or II)
  // TODO(lode): support the theoretical case of multiple exif boxes
  const uint8_t* exif = nullptr;  // Not owned
  size_t exif_size = 0;

  // Brotli-compressed exif metadata, if present. The data points to the brotli
  // compressed stream, it is not decompressed here.
  const uint8_t* exfc = nullptr;  // Not owned
  size_t exfc_size = 0;

  // XML boxes for XMP. There may be multiple XML boxes.
  // Each entry points to XML location and provides size.
  // The memory is not owned.
  // TODO(lode): for C API, cannot use std::vector.
  std::vector<std::pair<const uint8_t*, size_t>> xml;

  // Brotli-compressed xml boxes. The bytes are given in brotli-compressed form
  // and are not decompressed here.
  std::vector<std::pair<const uint8_t*, size_t>> xmlc;

  // JUMBF superbox data, or null if not present in the container.
  // The parsing of the nested boxes inside is not handled here.
  const uint8_t* jumb = nullptr;  // Not owned
  size_t jumb_size = 0;

  // TODO(lode): add frame index data

  // JPEG reconstruction data, or null if not present in the container.
  const uint8_t* jpeg_reconstruction = nullptr;
  size_t jpeg_reconstruction_size = 0;

  // The main JPEG XL codestream, of which there must be 1 in the container.
  jxl::PaddedBytes codestream;
};

// Returns whether `data` starts with a container header; definitely returns
// false if `size` is less than 12 bytes.
bool IsContainerHeader(const uint8_t* data, size_t size);

// NOTE: the input data must remain valid as long as `container` is used,
// because its exif etc. pointers point to that data.
jxl::Status DecodeJpegXlContainerOneShot(const uint8_t* data, size_t size,
                                         JpegXlContainer* container);

// TODO(lode): streaming C API
jxl::Status EncodeJpegXlContainerOneShot(const JpegXlContainer& container,
                                         jxl::PaddedBytes* out);

}  // namespace tools
}  // namespace jpegxl

#endif  // TOOLS_BOX_BOX_H_
