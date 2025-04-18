// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "tools/box/box.h"

#include <string.h>

#include "lib/jxl/base/byte_order.h"

namespace jpegxl {
namespace tools {

namespace {
// Checks if a + b > size, taking possible integer overflow into account.
bool OutOfBounds(size_t a, size_t b, size_t size) {
  size_t pos = a + b;
  if (pos > size) return true;
  if (pos < a) return true;  // overflow happened
  return false;
}
}  // namespace

// Parses the header of a BMFF box. Returns the result in a Box struct.
// Sets the position to the end of the box header after parsing. The data size
// is output if known, or must be handled by the caller and runs until the end
// of the container file if not known.
jxl::Status ParseBoxHeader(const uint8_t** next_in, size_t* available_in,
                           Box* box) {
  size_t pos = 0;
  size_t size = *available_in;
  const uint8_t* in = *next_in;

  if (OutOfBounds(pos, 8, size)) return JXL_FAILURE("out of bounds");

  const size_t initial_pos = pos;

  // Total box_size including this header itself.
  uint64_t box_size = LoadBE32(in + pos);
  pos += 4;
  if (box_size == 1) {
    // If the size is 1, it indicates extended size read from 64-bit integer.
    if (OutOfBounds(pos, 8, size)) return JXL_FAILURE("out of bounds");
    box_size = LoadBE64(in + pos);
    pos += 8;
  }
  memcpy(box->type, in + pos, 4);
  pos += 4;
  if (!memcmp("uuid", box->type, 4)) {
    if (OutOfBounds(pos, 16, size)) return JXL_FAILURE("out of bounds");
    memcpy(box->extended_type, in + pos, 16);
    pos += 16;
  }

  // This is the end of the box header, the box data begins here. Handle
  // the data size now.
  const size_t data_pos = pos;
  const size_t header_size = data_pos - initial_pos;

  if (box_size != 0) {
    if (box_size < header_size) {
      return JXL_FAILURE("invalid box size");
    }
    box->data_size_given = true;
    box->data_size = box_size - header_size;
  } else {
    // The size extends to the end of the file. We don't necessarily know the
    // end of the file here, since the input size may be only part of the full
    // container file. Indicate the size is not given, the caller must handle
    // this.
    box->data_size_given = false;
    box->data_size = 0;
  }

  // The remaining bytes are the data. If the box is a full box, the first
  // bytes of the data have a certain structure but this is to be handled by
  // the caller for the appropriate box type.
  *next_in += pos;
  *available_in -= pos;

  return true;
}

jxl::Status AppendBoxHeader(const Box& box, jxl::PaddedBytes* out) {
  bool use_extended = !memcmp("uuid", box.type, 4);

  uint64_t box_size = 0;
  bool large_size = false;
  if (box.data_size_given) {
    box_size = box.data_size + 8 + (use_extended ? 16 : 0);
    if (box_size >= 0x100000000ull) {
      large_size = true;
    }
  }

  out->resize(out->size() + 4);
  StoreBE32(large_size ? 1 : box_size, &out->back() - 4 + 1);

  out->resize(out->size() + 4);
  memcpy(&out->back() - 4 + 1, box.type, 4);

  if (large_size) {
    out->resize(out->size() + 8);
    StoreBE64(box_size, &out->back() - 8 + 1);
  }

  if (use_extended) {
    out->resize(out->size() + 16);
    memcpy(&out->back() - 16 + 1, box.extended_type, 16);
  }

  return true;
}

bool IsContainerHeader(const uint8_t* data, size_t size) {
  const uint8_t box_header[] = {0,   0,   0,   0xc, 'J',  'X',
                                'L', ' ', 0xd, 0xa, 0x87, 0xa};
  if (size < sizeof(box_header)) return false;
  return memcmp(box_header, data, sizeof(box_header)) == 0;
}

jxl::Status DecodeJpegXlContainerOneShot(const uint8_t* data, size_t size,
                                         JpegXlContainer* container) {
  const uint8_t* in = data;
  size_t available_in = size;

  container->exif = nullptr;
  container->exif_size = 0;
  container->exfc = nullptr;
  container->exfc_size = 0;
  container->xml.clear();
  container->xmlc.clear();
  container->jumb = nullptr;
  container->jumb_size = 0;
  container->codestream.clear();
  container->jpeg_reconstruction = nullptr;
  container->jpeg_reconstruction_size = 0;

  size_t box_index = 0;

  while (available_in != 0) {
    Box box;
    if (!ParseBoxHeader(&in, &available_in, &box)) {
      return JXL_FAILURE("Invalid box header");
    }

    size_t data_size = box.data_size_given ? box.data_size : available_in;

    if (box.data_size > available_in) {
      return JXL_FAILURE("Unexpected end of file");
    }

    if (box_index == 0) {
      // TODO(lode): leave out magic signature box?
      // Must be magic signature box.
      if (memcmp("JXL ", box.type, 4) != 0) {
        return JXL_FAILURE("Invalid magic signature");
      }
      if (box.data_size != 4) return JXL_FAILURE("Invalid magic signature");
      if (in[0] != 0xd || in[1] != 0xa || in[2] != 0x87 || in[3] != 0xa) {
        return JXL_FAILURE("Invalid magic signature");
      }
    } else if (box_index == 1) {
      // Must be ftyp box.
      if (memcmp("ftyp", box.type, 4) != 0) {
        return JXL_FAILURE("Invalid ftyp");
      }
      if (box.data_size != 12) return JXL_FAILURE("Invalid ftyp");
      const char* expected = "jxl \0\0\0\0jxl ";
      if (memcmp(expected, in, 12) != 0) return JXL_FAILURE("Invalid ftyp");
    } else if (!memcmp("jxli", box.type, 4)) {
      // TODO(lode): parse JXL frame index box
      if (!container->codestream.empty()) {
        return JXL_FAILURE("frame index must come before codestream");
      }
    } else if (!memcmp("jxlc", box.type, 4)) {
      container->codestream.append(in, in + data_size);
    } else if (!memcmp("jxlp", box.type, 4)) {
      if (data_size < 4) return JXL_FAILURE("Invalid jxlp");
      // TODO(jon): don't just ignore the counter
      container->codestream.append(in + 4, in + data_size);
    } else if (!memcmp("Exif", box.type, 4)) {
      if (data_size < 4) return JXL_FAILURE("Invalid Exif");
      uint32_t tiff_header_offset = LoadBE32(in);
      if (tiff_header_offset > data_size - 4)
        return JXL_FAILURE("Invalid Exif tiff header offset");
      container->exif = in + 4 + tiff_header_offset;
      container->exif_size = data_size - 4 - tiff_header_offset;
    } else if (!memcmp("Exfc", box.type, 4)) {
      container->exfc = in;
      container->exfc_size = data_size;
    } else if (!memcmp("xml ", box.type, 4)) {
      container->xml.emplace_back(in, data_size);
    } else if (!memcmp("xmlc", box.type, 4)) {
      container->xmlc.emplace_back(in, data_size);
    } else if (!memcmp("jumb", box.type, 4)) {
      container->jumb = in;
      container->jumb_size = data_size;
    } else if (!memcmp("jbrd", box.type, 4)) {
      container->jpeg_reconstruction = in;
      container->jpeg_reconstruction_size = data_size;
    } else {
      // Do nothing: box not recognized here but may be recognizable by
      // other software.
    }

    in += data_size;
    available_in -= data_size;
    box_index++;
  }

  return true;
}

static jxl::Status AppendBoxAndData(const char type[4], const uint8_t* data,
                                    size_t data_size, jxl::PaddedBytes* out,
                                    bool exif = false) {
  Box box;
  memcpy(box.type, type, 4);
  box.data_size = data_size + (exif ? 4 : 0);
  box.data_size_given = true;
  JXL_RETURN_IF_ERROR(AppendBoxHeader(box, out));
  // for Exif: always use tiff header offset 0
  if (exif)
    for (int i = 0; i < 4; i++) out->push_back(0);
  out->append(data, data + data_size);
  return true;
}

jxl::Status EncodeJpegXlContainerOneShot(const JpegXlContainer& container,
                                         jxl::PaddedBytes* out) {
  const unsigned char header[] = {0,   0,   0,    0xc, 'J', 'X', 'L', ' ',
                                  0xd, 0xa, 0x87, 0xa, 0,   0,   0,   0x14,
                                  'f', 't', 'y',  'p', 'j', 'x', 'l', ' ',
                                  0,   0,   0,    0,   'j', 'x', 'l', ' '};
  size_t header_size = sizeof(header);
  out->append(header, header + header_size);

  if (container.exif) {
    JXL_RETURN_IF_ERROR(AppendBoxAndData("Exif", container.exif,
                                         container.exif_size, out, true));
  }

  if (container.exfc) {
    JXL_RETURN_IF_ERROR(
        AppendBoxAndData("Exfc", container.exfc, container.exfc_size, out));
  }

  for (size_t i = 0; i < container.xml.size(); i++) {
    JXL_RETURN_IF_ERROR(AppendBoxAndData("xml ", container.xml[i].first,
                                         container.xml[i].second, out));
  }

  for (size_t i = 0; i < container.xmlc.size(); i++) {
    JXL_RETURN_IF_ERROR(AppendBoxAndData("xmlc", container.xmlc[i].first,
                                         container.xmlc[i].second, out));
  }

  if (container.jpeg_reconstruction) {
    JXL_RETURN_IF_ERROR(AppendBoxAndData("jbrd", container.jpeg_reconstruction,
                                         container.jpeg_reconstruction_size,
                                         out));
  }

  if (!container.codestream.empty()) {
    JXL_RETURN_IF_ERROR(AppendBoxAndData("jxlc", container.codestream.data(),
                                         container.codestream.size(), out));
  } else {
    return JXL_FAILURE("must have primary image frame");
  }

  if (container.jumb) {
    JXL_RETURN_IF_ERROR(
        AppendBoxAndData("jumb", container.jumb, container.jumb_size, out));
  }

  return true;
}

// TODO(veluca): the format defined here encode some things multiple times. Fix
// that.

}  // namespace tools
}  // namespace jpegxl
