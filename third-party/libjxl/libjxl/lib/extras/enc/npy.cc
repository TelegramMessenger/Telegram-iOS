// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/extras/enc/npy.h"

#include <jxl/types.h>
#include <stdio.h>

#include <sstream>
#include <string>
#include <vector>

#include "lib/extras/packed_image.h"

namespace jxl {
namespace extras {
namespace {

// JSON value writing

class JSONField {
 public:
  virtual ~JSONField() = default;
  virtual void Write(std::ostream& o, uint32_t indent) const = 0;

 protected:
  JSONField() = default;
};

class JSONValue : public JSONField {
 public:
  template <typename T>
  explicit JSONValue(const T& value) : value_(std::to_string(value)) {}

  explicit JSONValue(const std::string& value) : value_("\"" + value + "\"") {}

  explicit JSONValue(bool value) : value_(value ? "true" : "false") {}

  void Write(std::ostream& o, uint32_t indent) const override { o << value_; }

 private:
  std::string value_;
};

class JSONDict : public JSONField {
 public:
  JSONDict() = default;

  template <typename T>
  T* AddEmpty(const std::string& key) {
    static_assert(std::is_convertible<T*, JSONField*>::value,
                  "T must be a JSONField");
    T* ret = new T();
    values_.emplace_back(
        key, std::unique_ptr<JSONField>(static_cast<JSONField*>(ret)));
    return ret;
  }

  template <typename T>
  void Add(const std::string& key, const T& value) {
    values_.emplace_back(key, std::unique_ptr<JSONField>(new JSONValue(value)));
  }

  void Write(std::ostream& o, uint32_t indent) const override {
    std::string indent_str(indent, ' ');
    o << "{";
    bool is_first = true;
    for (const auto& key_value : values_) {
      if (!is_first) {
        o << ",";
      }
      is_first = false;
      o << std::endl << indent_str << "  \"" << key_value.first << "\": ";
      key_value.second->Write(o, indent + 2);
    }
    if (!values_.empty()) {
      o << std::endl << indent_str;
    }
    o << "}";
  }

 private:
  // Dictionary with order.
  std::vector<std::pair<std::string, std::unique_ptr<JSONField>>> values_;
};

class JSONArray : public JSONField {
 public:
  JSONArray() = default;

  template <typename T>
  T* AddEmpty() {
    static_assert(std::is_convertible<T*, JSONField*>::value,
                  "T must be a JSONField");
    T* ret = new T();
    values_.emplace_back(ret);
    return ret;
  }

  template <typename T>
  void Add(const T& value) {
    values_.emplace_back(new JSONValue(value));
  }

  void Write(std::ostream& o, uint32_t indent) const override {
    std::string indent_str(indent, ' ');
    o << "[";
    bool is_first = true;
    for (const auto& value : values_) {
      if (!is_first) {
        o << ",";
      }
      is_first = false;
      o << std::endl << indent_str << "  ";
      value->Write(o, indent + 2);
    }
    if (!values_.empty()) {
      o << std::endl << indent_str;
    }
    o << "]";
  }

 private:
  std::vector<std::unique_ptr<JSONField>> values_;
};

void GenerateMetadata(const PackedPixelFile& ppf, std::vector<uint8_t>* out) {
  JSONDict meta;
  // Same order as in 18181-3 CD.

  // Frames.
  auto* meta_frames = meta.AddEmpty<JSONArray>("frames");
  for (size_t i = 0; i < ppf.frames.size(); i++) {
    auto* frame_i = meta_frames->AddEmpty<JSONDict>();
    if (ppf.info.have_animation) {
      frame_i->Add("duration",
                   JSONValue(ppf.frames[i].frame_info.duration * 1.0f *
                             ppf.info.animation.tps_denominator /
                             ppf.info.animation.tps_numerator));
    }

    frame_i->Add("name", JSONValue(ppf.frames[i].name));

    if (ppf.info.animation.have_timecodes) {
      frame_i->Add("timecode", JSONValue(ppf.frames[i].frame_info.timecode));
    }
  }

#define METADATA(FIELD) meta.Add(#FIELD, ppf.info.FIELD)

  METADATA(intensity_target);
  METADATA(min_nits);
  METADATA(relative_to_max_display);
  METADATA(linear_below);

  if (ppf.info.have_preview) {
    meta.AddEmpty<JSONDict>("preview");
    // TODO(veluca): can we have duration/name/timecode here?
  }

  {
    auto ectype = meta.AddEmpty<JSONArray>("extra_channel_type");
    auto bps = meta.AddEmpty<JSONArray>("bits_per_sample");
    auto ebps = meta.AddEmpty<JSONArray>("exp_bits_per_sample");
    bps->Add(ppf.info.bits_per_sample);
    ebps->Add(ppf.info.exponent_bits_per_sample);
    for (size_t i = 0; i < ppf.extra_channels_info.size(); i++) {
      switch (ppf.extra_channels_info[i].ec_info.type) {
        case JXL_CHANNEL_ALPHA: {
          ectype->Add(std::string("Alpha"));
          break;
        }
        case JXL_CHANNEL_DEPTH: {
          ectype->Add(std::string("Depth"));
          break;
        }
        case JXL_CHANNEL_SPOT_COLOR: {
          ectype->Add(std::string("SpotColor"));
          break;
        }
        case JXL_CHANNEL_SELECTION_MASK: {
          ectype->Add(std::string("SelectionMask"));
          break;
        }
        case JXL_CHANNEL_BLACK: {
          ectype->Add(std::string("Black"));
          break;
        }
        case JXL_CHANNEL_CFA: {
          ectype->Add(std::string("CFA"));
          break;
        }
        case JXL_CHANNEL_THERMAL: {
          ectype->Add(std::string("Thermal"));
          break;
        }
        default: {
          ectype->Add(std::string("UNKNOWN"));
          break;
        }
      }
      bps->Add(ppf.extra_channels_info[i].ec_info.bits_per_sample);
      ebps->Add(ppf.extra_channels_info[i].ec_info.exponent_bits_per_sample);
    }
  }

  std::ostringstream os;
  meta.Write(os, 0);
  out->resize(os.str().size());
  memcpy(out->data(), os.str().data(), os.str().size());
}

void Append(std::vector<uint8_t>* out, const void* data, size_t size) {
  size_t pos = out->size();
  out->resize(pos + size);
  memcpy(out->data() + pos, data, size);
}

void WriteNPYHeader(size_t xsize, size_t ysize, uint32_t num_channels,
                    size_t num_frames, std::vector<uint8_t>* out) {
  const uint8_t header[] = "\x93NUMPY\x01\x00";
  Append(out, header, 8);
  std::stringstream ss;
  ss << "{'descr': '<f4', 'fortran_order': False, 'shape': (" << num_frames
     << ", " << ysize << ", " << xsize << ", " << num_channels << "), }\n";
  // 16-bit little endian header length.
  uint8_t header_len[2] = {static_cast<uint8_t>(ss.str().size() % 256),
                           static_cast<uint8_t>(ss.str().size() / 256)};
  Append(out, header_len, 2);
  Append(out, ss.str().data(), ss.str().size());
}

bool WriteFrameToNPYArray(size_t xsize, size_t ysize, const PackedFrame& frame,
                          std::vector<uint8_t>* out) {
  const auto& color = frame.color;
  if (color.xsize != xsize || color.ysize != ysize) {
    return false;
  }
  for (const auto& ec : frame.extra_channels) {
    if (ec.xsize != xsize || ec.ysize != ysize) {
      return false;
    }
  }
  // interleave the samples from color and extra channels
  for (size_t y = 0; y < ysize; ++y) {
    for (size_t x = 0; x < xsize; ++x) {
      {
        size_t sample_size = color.pixel_stride();
        size_t offset = y * color.stride + x * sample_size;
        uint8_t* pixels = reinterpret_cast<uint8_t*>(color.pixels());
        JXL_ASSERT(offset + sample_size <= color.pixels_size);
        Append(out, pixels + offset, sample_size);
      }
      for (const auto& ec : frame.extra_channels) {
        size_t sample_size = ec.pixel_stride();
        size_t offset = y * ec.stride + x * sample_size;
        uint8_t* pixels = reinterpret_cast<uint8_t*>(ec.pixels());
        JXL_ASSERT(offset + sample_size <= ec.pixels_size);
        Append(out, pixels + offset, sample_size);
      }
    }
  }
  return true;
}

// Writes a PackedPixelFile as a numpy 4D ndarray in binary format.
bool WriteNPYArray(const PackedPixelFile& ppf, std::vector<uint8_t>* out) {
  size_t xsize = ppf.info.xsize;
  size_t ysize = ppf.info.ysize;
  WriteNPYHeader(xsize, ysize,
                 ppf.info.num_color_channels + ppf.extra_channels_info.size(),
                 ppf.frames.size(), out);
  for (const auto& frame : ppf.frames) {
    if (!WriteFrameToNPYArray(xsize, ysize, frame, out)) {
      return false;
    }
  }
  return true;
}

class NumPyEncoder : public Encoder {
 public:
  Status Encode(const PackedPixelFile& ppf, EncodedImage* encoded_image,
                ThreadPool* pool = nullptr) const override {
    JXL_RETURN_IF_ERROR(VerifyBasicInfo(ppf.info));
    GenerateMetadata(ppf, &encoded_image->metadata);
    encoded_image->bitstreams.emplace_back();
    if (!WriteNPYArray(ppf, &encoded_image->bitstreams.back())) {
      return false;
    }
    if (ppf.preview_frame) {
      size_t xsize = ppf.info.preview.xsize;
      size_t ysize = ppf.info.preview.ysize;
      WriteNPYHeader(xsize, ysize, ppf.info.num_color_channels, 1,
                     &encoded_image->preview_bitstream);
      if (!WriteFrameToNPYArray(xsize, ysize, *ppf.preview_frame,
                                &encoded_image->preview_bitstream)) {
        return false;
      }
    }
    return true;
  }
  std::vector<JxlPixelFormat> AcceptedFormats() const override {
    std::vector<JxlPixelFormat> formats;
    for (const uint32_t num_channels : {1, 3}) {
      formats.push_back(JxlPixelFormat{num_channels, JXL_TYPE_FLOAT,
                                       JXL_LITTLE_ENDIAN, /*align=*/0});
    }
    return formats;
  }
};

}  // namespace

std::unique_ptr<Encoder> GetNumPyEncoder() {
  return jxl::make_unique<NumPyEncoder>();
}

}  // namespace extras
}  // namespace jxl
