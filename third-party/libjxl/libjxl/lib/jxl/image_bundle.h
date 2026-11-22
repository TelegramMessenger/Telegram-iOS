// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JXL_IMAGE_BUNDLE_H_
#define LIB_JXL_IMAGE_BUNDLE_H_

// The main image or frame consists of a bundle of associated images.

#include <jxl/cms_interface.h>
#include <stddef.h>
#include <stdint.h>

#include <vector>

#include "lib/jxl/base/compiler_specific.h"
#include "lib/jxl/base/data_parallel.h"
#include "lib/jxl/base/status.h"
#include "lib/jxl/color_encoding_internal.h"
#include "lib/jxl/common.h"
#include "lib/jxl/dec_bit_reader.h"
#include "lib/jxl/dec_xyb.h"
#include "lib/jxl/field_encodings.h"
#include "lib/jxl/frame_header.h"
#include "lib/jxl/headers.h"
#include "lib/jxl/image.h"
#include "lib/jxl/image_metadata.h"
#include "lib/jxl/jpeg/jpeg_data.h"
#include "lib/jxl/opsin_params.h"
#include "lib/jxl/quantizer.h"

namespace jxl {

// A bundle of color/alpha/depth/plane images.
class ImageBundle {
 public:
  // Uninitialized state for use as output parameter.
  ImageBundle() : metadata_(nullptr) {}
  // Caller is responsible for setting metadata before calling Set*.
  explicit ImageBundle(const ImageMetadata* metadata) : metadata_(metadata) {}

  // Move-only (allows storing in std::vector).
  ImageBundle(ImageBundle&&) = default;
  ImageBundle& operator=(ImageBundle&&) = default;

  ImageBundle Copy() const {
    ImageBundle copy(metadata_);
    copy.color_ = Image3F(color_.xsize(), color_.ysize());
    CopyImageTo(color_, &copy.color_);
    copy.c_current_ = c_current_;
    copy.extra_channels_.reserve(extra_channels_.size());
    for (const ImageF& plane : extra_channels_) {
      ImageF ec(plane.xsize(), plane.ysize());
      CopyImageTo(plane, &ec);
      copy.extra_channels_.emplace_back(std::move(ec));
    }

    copy.jpeg_data =
        jpeg_data ? make_unique<jpeg::JPEGData>(*jpeg_data) : nullptr;
    copy.color_transform = color_transform;
    copy.chroma_subsampling = chroma_subsampling;

    return copy;
  }

  // -- SIZE

  size_t xsize() const {
    if (IsJPEG()) return jpeg_data->width;
    if (color_.xsize() != 0) return color_.xsize();
    return extra_channels_.empty() ? 0 : extra_channels_[0].xsize();
  }
  size_t ysize() const {
    if (IsJPEG()) return jpeg_data->height;
    if (color_.ysize() != 0) return color_.ysize();
    return extra_channels_.empty() ? 0 : extra_channels_[0].ysize();
  }
  void ShrinkTo(size_t xsize, size_t ysize);

  // sizes taking orientation into account
  size_t oriented_xsize() const {
    if (static_cast<uint32_t>(metadata_->GetOrientation()) > 4) {
      return ysize();
    } else {
      return xsize();
    }
  }
  size_t oriented_ysize() const {
    if (static_cast<uint32_t>(metadata_->GetOrientation()) > 4) {
      return xsize();
    } else {
      return ysize();
    }
  }

  // -- COLOR

  // Whether color() is valid/usable. Returns true in most cases. Even images
  // with spot colors (one example of when !planes().empty()) typically have a
  // part that can be converted to RGB.
  bool HasColor() const { return color_.xsize() != 0; }

  // For resetting the size when switching from a reference to main frame.
  void RemoveColor() { color_ = Image3F(); }

  // Do not use if !HasColor().
  const Image3F& color() const {
    // If this fails, Set* was not called - perhaps because decoding failed?
    JXL_DASSERT(HasColor());
    return color_;
  }

  // Do not use if !HasColor().
  Image3F* color() {
    JXL_DASSERT(HasColor());
    return &color_;
  }

  // If c_current.IsGray(), all planes must be identical. NOTE: c_current is
  // independent of metadata()->color_encoding, which is the original, whereas
  // a decoder might return pixels in a different c_current.
  // This only sets the color channels, you must also make extra channels
  // match the amount that is in the metadata.
  void SetFromImage(Image3F&& color, const ColorEncoding& c_current);

  // -- COLOR ENCODING

  const ColorEncoding& c_current() const { return c_current_; }

  // Returns whether the color image has identical planes. Once established by
  // Set*, remains unchanged until a subsequent Set* or TransformTo.
  bool IsGray() const { return c_current_.IsGray(); }

  bool IsSRGB() const { return c_current_.IsSRGB(); }
  bool IsLinearSRGB() const {
    return c_current_.white_point == WhitePoint::kD65 &&
           c_current_.primaries == Primaries::kSRGB && c_current_.tf.IsLinear();
  }

  // Set the c_current profile without doing any transformation, e.g. if the
  // transformation was already applied.
  void OverrideProfile(const ColorEncoding& new_c_current) {
    c_current_ = new_c_current;
  }

  // TODO(lode): TransformTo and CopyTo are implemented in enc_image_bundle.cc,
  // move these functions out of this header file and class, to
  // enc_image_bundle.h.

  // Transforms color to c_desired and sets c_current to c_desired. Alpha and
  // metadata remains unchanged.
  Status TransformTo(const ColorEncoding& c_desired, const JxlCmsInterface& cms,
                     ThreadPool* pool = nullptr);
  // Copies this:rect, converts to c_desired, and allocates+fills out.
  Status CopyTo(const Rect& rect, const ColorEncoding& c_desired,
                const JxlCmsInterface& cms, Image3F* out,
                ThreadPool* pool = nullptr) const;

  // Detect 'real' bit depth, which can be lower than nominal bit depth
  // (this is common in PNG), returns 'real' bit depth
  size_t DetectRealBitdepth() const;

  // -- ALPHA

  void SetAlpha(ImageF&& alpha);
  bool HasAlpha() const {
    return metadata_->Find(ExtraChannel::kAlpha) != nullptr;
  }
  bool AlphaIsPremultiplied() const {
    const ExtraChannelInfo* eci = metadata_->Find(ExtraChannel::kAlpha);
    return (eci == nullptr) ? false : eci->alpha_associated;
  }
  const ImageF& alpha() const;
  ImageF* alpha();

  // -- EXTRA CHANNELS
  bool HasBlack() const {
    return metadata_->Find(ExtraChannel::kBlack) != nullptr;
  }
  const ImageF& black() const;

  // Extra channels of unknown interpretation (e.g. spot colors).
  void SetExtraChannels(std::vector<ImageF>&& extra_channels);
  void ClearExtraChannels() { extra_channels_.clear(); }
  bool HasExtraChannels() const { return !extra_channels_.empty(); }
  const std::vector<ImageF>& extra_channels() const { return extra_channels_; }
  std::vector<ImageF>& extra_channels() { return extra_channels_; }

  const ImageMetadata* metadata() const { return metadata_; }

  void VerifyMetadata() const;

  void SetDecodedBytes(size_t decoded_bytes) { decoded_bytes_ = decoded_bytes; }
  size_t decoded_bytes() const { return decoded_bytes_; }

  // -- JPEG transcoding:

  // Returns true if image does or will represent quantized DCT-8 coefficients,
  // stored in 8x8 pixel regions.
  bool IsJPEG() const {
#if JPEGXL_ENABLE_TRANSCODE_JPEG
    return jpeg_data != nullptr;
#else   // JPEGXL_ENABLE_TRANSCODE_JPEG
    return false;
#endif  // JPEGXL_ENABLE_TRANSCODE_JPEG
  }

  std::unique_ptr<jpeg::JPEGData> jpeg_data;
  // these fields are used to signal the input JPEG color space
  // NOTE: JPEG doesn't actually provide a way to determine whether YCbCr was
  // applied or not.
  ColorTransform color_transform = ColorTransform::kNone;
  YCbCrChromaSubsampling chroma_subsampling;

  FrameOrigin origin{0, 0};

  // Animation-related information, corresponding to the timecode and duration
  // fields of the jxl::AnimationFrame of the jxl::FrameHeader.
  // TODO(lode): ImageBundle is used here to carry the information from
  // jxl::FrameHeader, consider instead passing a jxl::FrameHeader directly to
  // EncodeFrame or having a field of that type here.
  uint32_t duration = 0;
  uint32_t timecode = 0;

  // TODO(lode): these fields do not match the JXL frame header, it should be
  // possible to specify up to 4 (3 if nonzero duration) slots to save this
  // frame as reference (see save_as_reference).
  bool use_for_next_frame = false;
  bool blend = false;
  BlendMode blendmode = BlendMode::kBlend;

  std::string name;

 private:
  // Called after any Set* to ensure their sizes are compatible.
  void VerifySizes() const;

  // Required for TransformTo so that an ImageBundle is self-sufficient. Always
  // points to the same thing, but cannot be const-pointer because that prevents
  // the compiler from generating a move ctor.
  const ImageMetadata* metadata_;

  // Initialized by Set*:
  Image3F color_;  // If empty, planes_ is not; all planes equal if IsGray().
  ColorEncoding c_current_;  // of color_

  // Initialized by SetPlanes; size = ImageMetadata.num_extra_channels
  std::vector<ImageF> extra_channels_;

  // How many bytes of the input were actually read.
  size_t decoded_bytes_ = 0;
};

}  // namespace jxl

#endif  // LIB_JXL_IMAGE_BUNDLE_H_
