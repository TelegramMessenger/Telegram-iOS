// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/decode_to_jpeg.h"

namespace jxl {

#if JPEGXL_ENABLE_TRANSCODE_JPEG

JxlDecoderStatus JxlToJpegDecoder::Process(const uint8_t** next_in,
                                           size_t* avail_in) {
  if (!inside_box_) {
    JXL_UNREACHABLE(
        "processing of JPEG reconstruction data outside JPEG reconstruction "
        "box");
  }
  Span<const uint8_t> to_decode;
  if (box_until_eof_) {
    // Until EOF means consume all data.
    to_decode = Span<const uint8_t>(*next_in, *avail_in);
    *next_in += *avail_in;
    *avail_in = 0;
  } else {
    // Defined size means consume min(available, needed).
    size_t avail_recon_in =
        std::min<size_t>(*avail_in, box_size_ - buffer_.size());
    to_decode = Span<const uint8_t>(*next_in, avail_recon_in);
    *next_in += avail_recon_in;
    *avail_in -= avail_recon_in;
  }
  bool old_data_exists = !buffer_.empty();
  if (old_data_exists) {
    // Append incoming data to buffer if we already had data in the buffer.
    buffer_.insert(buffer_.end(), to_decode.data(),
                   to_decode.data() + to_decode.size());
    to_decode = Span<const uint8_t>(buffer_.data(), buffer_.size());
  }
  if (!box_until_eof_ && to_decode.size() > box_size_) {
    JXL_UNREACHABLE("JPEG reconstruction data to decode larger than expected");
  }
  if (box_until_eof_ || to_decode.size() == box_size_) {
    // If undefined size, or the right size, try to decode.
    jpeg_data_ = make_unique<jpeg::JPEGData>();
    const auto status = jpeg::DecodeJPEGData(to_decode, jpeg_data_.get());
    if (status.IsFatalError()) return JXL_DEC_ERROR;
    if (status) {
      // Successful decoding, emit event after updating state to track that we
      // are no longer parsing JPEG reconstruction data.
      inside_box_ = false;
      return JXL_DEC_JPEG_RECONSTRUCTION;
    }
    if (box_until_eof_) {
      // Unsuccessful decoding and undefined size, assume incomplete data. Copy
      // the data if we haven't already.
      if (!old_data_exists) {
        buffer_.insert(buffer_.end(), to_decode.data(),
                       to_decode.data() + to_decode.size());
      }
    } else {
      // Unsuccessful decoding of correct amount of data, assume error.
      return JXL_DEC_ERROR;
    }
  } else {
    // Not enough data, copy the data if we haven't already.
    if (!old_data_exists) {
      buffer_.insert(buffer_.end(), to_decode.data(),
                     to_decode.data() + to_decode.size());
    }
  }
  return JXL_DEC_NEED_MORE_INPUT;
}

size_t JxlToJpegDecoder::NumExifMarkers(const jpeg::JPEGData& jpeg_data) {
  size_t num = 0;
  for (size_t i = 0; i < jpeg_data.app_data.size(); ++i) {
    if (jpeg_data.app_marker_type[i] == jxl::jpeg::AppMarkerType::kExif) {
      num++;
    }
  }
  return num;
}

size_t JxlToJpegDecoder::NumXmpMarkers(const jpeg::JPEGData& jpeg_data) {
  size_t num = 0;
  for (size_t i = 0; i < jpeg_data.app_data.size(); ++i) {
    if (jpeg_data.app_marker_type[i] == jxl::jpeg::AppMarkerType::kXMP) {
      num++;
    }
  }
  return num;
}

JxlDecoderStatus JxlToJpegDecoder::ExifBoxContentSize(
    const jpeg::JPEGData& jpeg_data, size_t* size) {
  for (size_t i = 0; i < jpeg_data.app_data.size(); ++i) {
    if (jpeg_data.app_marker_type[i] == jxl::jpeg::AppMarkerType::kExif) {
      if (jpeg_data.app_data[i].size() < 3 + sizeof(jpeg::kExifTag)) {
        // too small for app marker header
        return JXL_DEC_ERROR;
      }
      // The first 4 bytes are the TIFF header from the box contents, and are
      // not included in the JPEG
      *size = jpeg_data.app_data[i].size() + 4 - 3 - sizeof(jpeg::kExifTag);
      return JXL_DEC_SUCCESS;
    }
  }
  return JXL_DEC_ERROR;
}

JxlDecoderStatus JxlToJpegDecoder::XmlBoxContentSize(
    const jpeg::JPEGData& jpeg_data, size_t* size) {
  for (size_t i = 0; i < jpeg_data.app_data.size(); ++i) {
    if (jpeg_data.app_marker_type[i] == jxl::jpeg::AppMarkerType::kXMP) {
      if (jpeg_data.app_data[i].size() < 3 + sizeof(jpeg::kXMPTag)) {
        // too small for app marker header
        return JXL_DEC_ERROR;
      }
      *size = jpeg_data.app_data[i].size() - 3 - sizeof(jpeg::kXMPTag);
      return JXL_DEC_SUCCESS;
    }
  }
  return JXL_DEC_ERROR;
}

JxlDecoderStatus JxlToJpegDecoder::SetExif(const uint8_t* data, size_t size,
                                           jpeg::JPEGData* jpeg_data) {
  for (size_t i = 0; i < jpeg_data->app_data.size(); ++i) {
    if (jpeg_data->app_marker_type[i] == jxl::jpeg::AppMarkerType::kExif) {
      if (jpeg_data->app_data[i].size() !=
          size + 3 + sizeof(jpeg::kExifTag) - 4)
        return JXL_DEC_ERROR;
      // The first 9 bytes are used for JPEG marker header.
      jpeg_data->app_data[i][0] = 0xE1;
      // The second and third byte are already filled in correctly
      memcpy(jpeg_data->app_data[i].data() + 3, jpeg::kExifTag,
             sizeof(jpeg::kExifTag));
      // The first 4 bytes are the TIFF header from the box contents, and are
      // not included in the JPEG
      memcpy(jpeg_data->app_data[i].data() + 3 + sizeof(jpeg::kExifTag),
             data + 4, size - 4);
      return JXL_DEC_SUCCESS;
    }
  }
  return JXL_DEC_ERROR;
}
JxlDecoderStatus JxlToJpegDecoder::SetXmp(const uint8_t* data, size_t size,
                                          jpeg::JPEGData* jpeg_data) {
  for (size_t i = 0; i < jpeg_data->app_data.size(); ++i) {
    if (jpeg_data->app_marker_type[i] == jxl::jpeg::AppMarkerType::kXMP) {
      if (jpeg_data->app_data[i].size() != size + 3 + sizeof(jpeg::kXMPTag))
        return JXL_DEC_ERROR;
      // The first 9 bytes are used for JPEG marker header.
      jpeg_data->app_data[i][0] = 0xE1;
      // The second and third byte are already filled in correctly
      memcpy(jpeg_data->app_data[i].data() + 3, jpeg::kXMPTag,
             sizeof(jpeg::kXMPTag));
      memcpy(jpeg_data->app_data[i].data() + 3 + sizeof(jpeg::kXMPTag), data,
             size);
      return JXL_DEC_SUCCESS;
    }
  }
  return JXL_DEC_ERROR;
}

#endif  // JPEGXL_ENABLE_TRANSCODE_JPEG

}  // namespace jxl
