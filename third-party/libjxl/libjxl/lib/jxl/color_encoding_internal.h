// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JXL_COLOR_ENCODING_INTERNAL_H_
#define LIB_JXL_COLOR_ENCODING_INTERNAL_H_

// Metadata for color space conversions.

#include <jxl/cms_interface.h>
#include <jxl/color_encoding.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

#include <cmath>  // std::abs
#include <ostream>
#include <string>
#include <vector>

#include "lib/jxl/base/compiler_specific.h"
#include "lib/jxl/base/padded_bytes.h"
#include "lib/jxl/base/status.h"
#include "lib/jxl/field_encodings.h"

namespace jxl {

// (All CIE units are for the standard 1931 2 degree observer)

// Color space the color pixel data is encoded in. The color pixel data is
// 3-channel in all cases except in case of kGray, where it uses only 1 channel.
// This also determines the amount of channels used in modular encoding.
enum class ColorSpace : uint32_t {
  // Trichromatic color data. This also includes CMYK if a kBlack
  // ExtraChannelInfo is present. This implies, if there is an ICC profile, that
  // the ICC profile uses a 3-channel color space if no kBlack extra channel is
  // present, or uses color space 'CMYK' if a kBlack extra channel is present.
  kRGB,
  // Single-channel data. This implies, if there is an ICC profile, that the ICC
  // profile also represents single-channel data and has the appropriate color
  // space ('GRAY').
  kGray,
  // Like kRGB, but implies fixed values for primaries etc.
  kXYB,
  // For non-RGB/gray data, e.g. from non-electro-optical sensors. Otherwise
  // the same conditions as kRGB apply.
  kUnknown
};

static inline const char* EnumName(ColorSpace /*unused*/) {
  return "ColorSpace";
}
static inline constexpr uint64_t EnumBits(ColorSpace /*unused*/) {
  using CS = ColorSpace;
  return MakeBit(CS::kRGB) | MakeBit(CS::kGray) | MakeBit(CS::kXYB) |
         MakeBit(CS::kUnknown);
}

// Values from CICP ColourPrimaries.
enum class WhitePoint : uint32_t {
  kD65 = 1,     // sRGB/BT.709/Display P3/BT.2020
  kCustom = 2,  // Actual values encoded in separate fields
  kE = 10,      // XYZ
  kDCI = 11,    // DCI-P3
};

static inline const char* EnumName(WhitePoint /*unused*/) {
  return "WhitePoint";
}
static inline constexpr uint64_t EnumBits(WhitePoint /*unused*/) {
  return MakeBit(WhitePoint::kD65) | MakeBit(WhitePoint::kCustom) |
         MakeBit(WhitePoint::kE) | MakeBit(WhitePoint::kDCI);
}

// Values from CICP ColourPrimaries
enum class Primaries : uint32_t {
  kSRGB = 1,    // Same as BT.709
  kCustom = 2,  // Actual values encoded in separate fields
  k2100 = 9,    // Same as BT.2020
  kP3 = 11,
};

static inline const char* EnumName(Primaries /*unused*/) { return "Primaries"; }
static inline constexpr uint64_t EnumBits(Primaries /*unused*/) {
  using Pr = Primaries;
  return MakeBit(Pr::kSRGB) | MakeBit(Pr::kCustom) | MakeBit(Pr::k2100) |
         MakeBit(Pr::kP3);
}

// Values from CICP TransferCharacteristics
enum class TransferFunction : uint32_t {
  k709 = 1,
  kUnknown = 2,
  kLinear = 8,
  kSRGB = 13,
  kPQ = 16,   // from BT.2100
  kDCI = 17,  // from SMPTE RP 431-2 reference projector
  kHLG = 18,  // from BT.2100
};

static inline const char* EnumName(TransferFunction /*unused*/) {
  return "TransferFunction";
}
static inline constexpr uint64_t EnumBits(TransferFunction /*unused*/) {
  using TF = TransferFunction;
  return MakeBit(TF::k709) | MakeBit(TF::kLinear) | MakeBit(TF::kSRGB) |
         MakeBit(TF::kPQ) | MakeBit(TF::kDCI) | MakeBit(TF::kHLG) |
         MakeBit(TF::kUnknown);
}

enum class RenderingIntent : uint32_t {
  // Values match ICC sRGB encodings.
  kPerceptual = 0,  // good for photos, requires a profile with LUT.
  kRelative,        // good for logos.
  kSaturation,      // perhaps useful for CG with fully saturated colors.
  kAbsolute,        // leaves white point unchanged; good for proofing.
};

static inline const char* EnumName(RenderingIntent /*unused*/) {
  return "RenderingIntent";
}
static inline constexpr uint64_t EnumBits(RenderingIntent /*unused*/) {
  using RI = RenderingIntent;
  return MakeBit(RI::kPerceptual) | MakeBit(RI::kRelative) |
         MakeBit(RI::kSaturation) | MakeBit(RI::kAbsolute);
}

// Chromaticity (Y is omitted because it is 1 for primaries/white points)
struct CIExy {
  double x = 0.0;
  double y = 0.0;
};

struct PrimariesCIExy {
  CIExy r;
  CIExy g;
  CIExy b;
};

// Serializable form of CIExy.
struct Customxy : public Fields {
  Customxy();
  JXL_FIELDS_NAME(Customxy)

  Status VisitFields(Visitor* JXL_RESTRICT visitor) override;

  CIExy Get() const;
  // Returns false if x or y do not fit in the encoding.
  Status Set(const CIExy& xy);

  int32_t x;
  int32_t y;
};

struct CustomTransferFunction : public Fields {
  CustomTransferFunction();
  JXL_FIELDS_NAME(CustomTransferFunction)

  // Sets fields and returns true if nonserialized_color_space has an implicit
  // transfer function, otherwise leaves fields unchanged and returns false.
  bool SetImplicit();

  // Gamma: only used for PNG inputs
  bool IsGamma() const { return have_gamma_; }
  double GetGamma() const {
    JXL_ASSERT(IsGamma());
    return gamma_ * 1E-7;  // (0, 1)
  }
  Status SetGamma(double gamma);

  TransferFunction GetTransferFunction() const {
    JXL_ASSERT(!IsGamma());
    return transfer_function_;
  }
  void SetTransferFunction(const TransferFunction tf) {
    have_gamma_ = false;
    transfer_function_ = tf;
  }

  bool IsUnknown() const {
    return !have_gamma_ && (transfer_function_ == TransferFunction::kUnknown);
  }
  bool IsSRGB() const {
    return !have_gamma_ && (transfer_function_ == TransferFunction::kSRGB);
  }
  bool IsLinear() const {
    return !have_gamma_ && (transfer_function_ == TransferFunction::kLinear);
  }
  bool IsPQ() const {
    return !have_gamma_ && (transfer_function_ == TransferFunction::kPQ);
  }
  bool IsHLG() const {
    return !have_gamma_ && (transfer_function_ == TransferFunction::kHLG);
  }
  bool Is709() const {
    return !have_gamma_ && (transfer_function_ == TransferFunction::k709);
  }
  bool IsDCI() const {
    return !have_gamma_ && (transfer_function_ == TransferFunction::kDCI);
  }
  bool IsSame(const CustomTransferFunction& other) const {
    if (have_gamma_ != other.have_gamma_) return false;
    if (have_gamma_) {
      if (gamma_ != other.gamma_) return false;
    } else {
      if (transfer_function_ != other.transfer_function_) return false;
    }
    return true;
  }

  Status VisitFields(Visitor* JXL_RESTRICT visitor) override;

  // Must be set before calling VisitFields!
  ColorSpace nonserialized_color_space = ColorSpace::kRGB;

 private:
  static constexpr uint32_t kGammaMul = 10000000;

  bool have_gamma_;

  // OETF exponent to go from linear to gamma-compressed.
  uint32_t gamma_;  // Only used if have_gamma_.

  // Can be kUnknown.
  TransferFunction transfer_function_;  // Only used if !have_gamma_.
};

// Compact encoding of data required to interpret and translate pixels to a
// known color space. Stored in Metadata. Thread-compatible.
struct ColorEncoding : public Fields {
  ColorEncoding();
  JXL_FIELDS_NAME(ColorEncoding)

  // Returns ready-to-use color encodings (initialized on-demand).
  static const ColorEncoding& SRGB(bool is_gray = false);
  static const ColorEncoding& LinearSRGB(bool is_gray = false);

  // Returns true if an ICC profile was successfully created from fields.
  // Must be called after modifying fields. Defined in color_management.cc.
  Status CreateICC();

  // Returns non-empty and valid ICC profile, unless:
  // - between calling InternalRemoveICC() and CreateICC() in tests;
  // - WantICC() == true and SetICC() was not yet called;
  // - after a failed call to SetSRGB(), SetICC(), or CreateICC().
  const PaddedBytes& ICC() const { return icc_; }

  // Internal only, do not call except from tests.
  void InternalRemoveICC() { icc_.clear(); }

  // Returns true if `icc` is assigned and decoded successfully. If so,
  // subsequent WantICC() will return true until DecideIfWantICC() changes it.
  // Returning false indicates data has been lost.
  Status SetICC(PaddedBytes&& icc, const JxlCmsInterface* cms) {
    if (icc.empty()) return false;
    icc_ = std::move(icc);

    if (cms == nullptr) {
      want_icc_ = true;
      have_fields_ = false;
      return true;
    }

    if (!SetFieldsFromICC(*cms)) {
      InternalRemoveICC();
      return false;
    }

    want_icc_ = true;
    return true;
  }

  // Sets the raw ICC profile bytes, without parsing the ICC, and without
  // updating the direct fields such as whitepoint, primaries and color
  // space. Functions to get and set fields, such as SetWhitePoint, cannot be
  // used anymore after this and functions such as IsSRGB return false no matter
  // what the contents of the icc profile.
  Status SetICCRaw(PaddedBytes&& icc) {
    if (icc.empty()) return false;
    icc_ = std::move(icc);

    want_icc_ = true;
    have_fields_ = false;
    return true;
  }

  // Returns whether to send the ICC profile in the codestream.
  bool WantICC() const { return want_icc_; }

  // Return whether the direct fields are set, if false but ICC is set, only
  // raw ICC bytes are known.
  bool HaveFields() const { return have_fields_; }

  // Causes WantICC() to return false if ICC() can be reconstructed from fields.
  void DecideIfWantICC(const JxlCmsInterface& cms);

  bool IsGray() const { return color_space_ == ColorSpace::kGray; }
  bool IsCMYK() const { return cmyk_; }
  size_t Channels() const { return IsGray() ? 1 : 3; }

  // Returns false if the field is invalid and unusable.
  bool HasPrimaries() const {
    return !IsGray() && color_space_ != ColorSpace::kXYB;
  }

  // Returns true after setting the field to a value defined by color_space,
  // otherwise false and leaves the field unchanged.
  bool ImplicitWhitePoint() {
    if (color_space_ == ColorSpace::kXYB) {
      white_point = WhitePoint::kD65;
      return true;
    }
    return false;
  }

  // Returns whether the color space is known to be sRGB. If a raw unparsed ICC
  // profile is set without the fields being set, this returns false, even if
  // the content of the ICC profile would match sRGB.
  bool IsSRGB() const {
    if (!have_fields_) return false;
    if (!IsGray() && color_space_ != ColorSpace::kRGB) return false;
    if (white_point != WhitePoint::kD65) return false;
    if (primaries != Primaries::kSRGB) return false;
    if (!tf.IsSRGB()) return false;
    return true;
  }

  // Returns whether the color space is known to be linear sRGB. If a raw
  // unparsed ICC profile is set without the fields being set, this returns
  // false, even if the content of the ICC profile would match linear sRGB.
  bool IsLinearSRGB() const {
    if (!have_fields_) return false;
    if (!IsGray() && color_space_ != ColorSpace::kRGB) return false;
    if (white_point != WhitePoint::kD65) return false;
    if (primaries != Primaries::kSRGB) return false;
    if (!tf.IsLinear()) return false;
    return true;
  }

  Status SetSRGB(const ColorSpace cs,
                 const RenderingIntent ri = RenderingIntent::kRelative) {
    InternalRemoveICC();
    JXL_ASSERT(cs == ColorSpace::kGray || cs == ColorSpace::kRGB);
    color_space_ = cs;
    white_point = WhitePoint::kD65;
    primaries = Primaries::kSRGB;
    tf.SetTransferFunction(TransferFunction::kSRGB);
    rendering_intent = ri;
    return CreateICC();
  }

  Status VisitFields(Visitor* JXL_RESTRICT visitor) override;

  // Accessors ensure tf.nonserialized_color_space is updated at the same time.
  ColorSpace GetColorSpace() const { return color_space_; }
  void SetColorSpace(const ColorSpace cs) {
    color_space_ = cs;
    tf.nonserialized_color_space = cs;
  }

  CIExy GetWhitePoint() const;
  Status SetWhitePoint(const CIExy& xy);

  PrimariesCIExy GetPrimaries() const;
  Status SetPrimaries(const PrimariesCIExy& xy);

  // Checks if the color spaces (including white point / primaries) are the
  // same, but ignores the transfer function, rendering intent and ICC bytes.
  bool SameColorSpace(const ColorEncoding& other) const {
    if (color_space_ != other.color_space_) return false;

    if (white_point != other.white_point) return false;
    if (white_point == WhitePoint::kCustom) {
      if (white_.x != other.white_.x || white_.y != other.white_.y)
        return false;
    }

    if (HasPrimaries() != other.HasPrimaries()) return false;
    if (HasPrimaries()) {
      if (primaries != other.primaries) return false;
      if (primaries == Primaries::kCustom) {
        if (red_.x != other.red_.x || red_.y != other.red_.y) return false;
        if (green_.x != other.green_.x || green_.y != other.green_.y)
          return false;
        if (blue_.x != other.blue_.x || blue_.y != other.blue_.y) return false;
      }
    }
    return true;
  }

  // Checks if the color space and transfer function are the same, ignoring
  // rendering intent and ICC bytes
  bool SameColorEncoding(const ColorEncoding& other) const {
    return SameColorSpace(other) && tf.IsSame(other.tf);
  }

  mutable bool all_default;

  // Only valid if HaveFields()
  WhitePoint white_point;
  Primaries primaries;  // Only valid if HasPrimaries()
  CustomTransferFunction tf;
  RenderingIntent rendering_intent;

 private:
  // Returns true if all fields have been initialized (possibly to kUnknown).
  // Returns false if the ICC profile is invalid or decoding it fails.
  Status SetFieldsFromICC(const JxlCmsInterface& cms);

  // If true, the codestream contains an ICC profile and we do not serialize
  // fields. Otherwise, fields are serialized and we create an ICC profile.
  bool want_icc_;

  // When false, fields such as white_point and tf are invalid and must not be
  // used. This occurs after setting a raw bytes-only ICC profile, only the
  // ICC bytes may be used. The color_space_ field is still valid.
  bool have_fields_ = true;

  PaddedBytes icc_;  // Valid ICC profile

  ColorSpace color_space_;  // Can be kUnknown
  bool cmyk_ = false;

  // Only used if white_point == kCustom.
  Customxy white_;

  // Only used if primaries == kCustom.
  Customxy red_;
  Customxy green_;
  Customxy blue_;
};

// Returns whether the two inputs are approximately equal.
static inline bool ApproxEq(const double a, const double b,
                            double max_l1 = 1E-3) {
  // Threshold should be sufficient for ICC's 15-bit fixed-point numbers.
  // We have seen differences of 7.1E-5 with lcms2 and 1E-3 with skcms.
  return std::abs(a - b) <= max_l1;
}

// Returns a representation of the ColorEncoding fields (not icc).
// Example description: "RGB_D65_SRG_Rel_Lin"
std::string Description(const ColorEncoding& c);
static inline std::ostream& operator<<(std::ostream& os,
                                       const ColorEncoding& c) {
  return os << Description(c);
}

void ConvertInternalToExternalColorEncoding(const jxl::ColorEncoding& internal,
                                            JxlColorEncoding* external);

Status ConvertExternalToInternalColorEncoding(const JxlColorEncoding& external,
                                              jxl::ColorEncoding* internal);

Status PrimariesToXYZ(float rx, float ry, float gx, float gy, float bx,
                      float by, float wx, float wy, float matrix[9]);
Status PrimariesToXYZD50(float rx, float ry, float gx, float gy, float bx,
                         float by, float wx, float wy, float matrix[9]);
Status AdaptToXYZD50(float wx, float wy, float matrix[9]);

}  // namespace jxl

#endif  // LIB_JXL_COLOR_ENCODING_INTERNAL_H_
