// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_EXTRAS_ENC_ENCODE_H_
#define LIB_EXTRAS_ENC_ENCODE_H_

// Facade for image encoders.

#include <string>
#include <unordered_map>

#include "lib/extras/dec/decode.h"
#include "lib/jxl/base/data_parallel.h"
#include "lib/jxl/base/status.h"

namespace jxl {
namespace extras {

struct EncodedImage {
  // One (if the format supports animations or the image has only one frame) or
  // more sequential bitstreams.
  std::vector<std::vector<uint8_t>> bitstreams;

  // For each extra channel one or more sequential bitstreams.
  std::vector<std::vector<std::vector<uint8_t>>> extra_channel_bitstreams;

  std::vector<uint8_t> preview_bitstream;

  // If the format does not support embedding color profiles into the bitstreams
  // above, it will be present here, to be written as a separate file. If it
  // does support them, this field will be empty.
  std::vector<uint8_t> icc;

  // Additional output for conformance testing, only filled in by NumPyEncoder.
  std::vector<uint8_t> metadata;
};

class Encoder {
 public:
  static std::unique_ptr<Encoder> FromExtension(std::string extension);

  virtual ~Encoder() = default;

  // Set of pixel formats that this encoder takes as input.
  // If empty, the 'encoder' does not need any pixels (it's metadata-only).
  virtual std::vector<JxlPixelFormat> AcceptedFormats() const = 0;

  // Any existing data in encoded_image is discarded.
  virtual Status Encode(const PackedPixelFile& ppf, EncodedImage* encoded_image,
                        ThreadPool* pool = nullptr) const = 0;

  void SetOption(std::string name, std::string value) {
    options_[std::move(name)] = std::move(value);
  }

  static Status VerifyBasicInfo(const JxlBasicInfo& info);
  static Status VerifyImageSize(const PackedImage& image,
                                const JxlBasicInfo& info);
  static Status VerifyBitDepth(JxlDataType data_type, uint32_t bits_per_sample,
                               uint32_t exponent_bits);

 protected:
  const std::unordered_map<std::string, std::string>& options() const {
    return options_;
  }

  Status VerifyFormat(const JxlPixelFormat& format) const;

  Status VerifyPackedImage(const PackedImage& image,
                           const JxlBasicInfo& info) const;

 private:
  std::unordered_map<std::string, std::string> options_;
};

// TODO(sboukortt): consider exposing this as part of the C API.
Status SelectFormat(const std::vector<JxlPixelFormat>& accepted_formats,
                    const JxlBasicInfo& basic_info, JxlPixelFormat* format);

}  // namespace extras
}  // namespace jxl

#endif  // LIB_EXTRAS_ENC_ENCODE_H_
