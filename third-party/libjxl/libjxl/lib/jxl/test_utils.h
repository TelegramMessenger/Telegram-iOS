// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JXL_TEST_UTILS_H_
#define LIB_JXL_TEST_UTILS_H_

// TODO(eustas): reduce includes (move to .cc)

// Macros and functions useful for tests.

#include <jxl/codestream_header.h>
#include <jxl/thread_parallel_runner_cxx.h>
#include <stddef.h>
#include <stdint.h>

#include <ostream>
#include <vector>

#include "lib/extras/dec/decode.h"
#include "lib/extras/dec/jxl.h"
#include "lib/extras/enc/jxl.h"
#include "lib/extras/packed_image.h"
#include "lib/jxl/base/data_parallel.h"
#include "lib/jxl/base/padded_bytes.h"
#include "lib/jxl/base/span.h"
#include "lib/jxl/base/status.h"
#include "lib/jxl/codec_in_out.h"
#include "lib/jxl/color_encoding_internal.h"
#include "lib/jxl/enc_params.h"

#define TEST_LIBJPEG_SUPPORT()                                              \
  do {                                                                      \
    if (!jxl::extras::CanDecode(jxl::extras::Codec::kJPG)) {                \
      fprintf(stderr, "Skipping test because of missing libjpeg codec.\n"); \
      return;                                                               \
    }                                                                       \
  } while (0)

namespace jxl {

struct AuxOut;

namespace test {

std::string GetTestDataPath(const std::string& filename);
PaddedBytes ReadTestData(const std::string& filename);

void JxlBasicInfoSetFromPixelFormat(JxlBasicInfo* basic_info,
                                    const JxlPixelFormat* pixel_format);

void DefaultAcceptedFormats(extras::JXLDecompressParams& dparams);

template <typename Params>
void SetThreadParallelRunner(Params params, ThreadPool* pool) {
  if (pool && !params.runner_opaque) {
    params.runner = pool->runner();
    params.runner_opaque = pool->runner_opaque();
  }
}

Status DecodeFile(extras::JXLDecompressParams dparams,
                  const Span<const uint8_t> file, CodecInOut* JXL_RESTRICT io,
                  ThreadPool* pool = nullptr);

bool Roundtrip(const CodecInOut* io, const CompressParams& cparams,
               extras::JXLDecompressParams dparams,
               CodecInOut* JXL_RESTRICT io2, std::stringstream& failures,
               size_t* compressed_size = nullptr, ThreadPool* pool = nullptr,
               AuxOut* aux_out = nullptr);

// Returns compressed size [bytes].
size_t Roundtrip(const extras::PackedPixelFile& ppf_in,
                 extras::JXLCompressParams cparams,
                 extras::JXLDecompressParams dparams, ThreadPool* pool,
                 extras::PackedPixelFile* ppf_out);

// A POD descriptor of a ColorEncoding. Only used in tests as the return value
// of AllEncodings().
struct ColorEncodingDescriptor {
  ColorSpace color_space;
  WhitePoint white_point;
  Primaries primaries;
  TransferFunction tf;
  RenderingIntent rendering_intent;
};

ColorEncoding ColorEncodingFromDescriptor(const ColorEncodingDescriptor& desc);

// Define the operator<< for tests.
static inline ::std::ostream& operator<<(::std::ostream& os,
                                         const ColorEncodingDescriptor& c) {
  return os << "ColorEncoding/" << Description(ColorEncodingFromDescriptor(c));
}

// Returns ColorEncodingDescriptors, which are only used in tests. To obtain a
// ColorEncoding object call ColorEncodingFromDescriptor and then call
// ColorEncoding::CreateProfile() on that object to generate a profile.
std::vector<ColorEncodingDescriptor> AllEncodings();

// Returns a CodecInOut based on the buf, xsize, ysize, and the assumption
// that the buffer was created using `GetSomeTestImage`.
jxl::CodecInOut SomeTestImageToCodecInOut(const std::vector<uint8_t>& buf,
                                          size_t num_channels, size_t xsize,
                                          size_t ysize);

bool Near(double expected, double value, double max_dist);

float LoadLEFloat16(const uint8_t* p);

float LoadBEFloat16(const uint8_t* p);

size_t GetPrecision(JxlDataType data_type);

size_t GetDataBits(JxlDataType data_type);

// Procedure to convert pixels to double precision, not efficient, but
// well-controlled for testing. It uses double, to be able to represent all
// precisions needed for the maximum data types the API supports: uint32_t
// integers, and, single precision float. The values are in range 0-1 for SDR.
std::vector<double> ConvertToRGBA32(const uint8_t* pixels, size_t xsize,
                                    size_t ysize, const JxlPixelFormat& format,
                                    double factor = 0.0);

// Returns amount of pixels which differ between the two pictures. Image b is
// the image after roundtrip after roundtrip, image a before roundtrip. There
// are more strict requirements for the alpha channel and grayscale values of
// the output image.
size_t ComparePixels(const uint8_t* a, const uint8_t* b, size_t xsize,
                     size_t ysize, const JxlPixelFormat& format_a,
                     const JxlPixelFormat& format_b,
                     double threshold_multiplier = 1.0);

double DistanceRMS(const uint8_t* a, const uint8_t* b, size_t xsize,
                   size_t ysize, const JxlPixelFormat& format);

float ButteraugliDistance(const extras::PackedPixelFile& a,
                          const extras::PackedPixelFile& b,
                          ThreadPool* pool = nullptr);

float Butteraugli3Norm(const extras::PackedPixelFile& a,
                       const extras::PackedPixelFile& b,
                       ThreadPool* pool = nullptr);

float ComputeDistance2(const extras::PackedPixelFile& a,
                       const extras::PackedPixelFile& b);

bool SameAlpha(const extras::PackedPixelFile& a,
               const extras::PackedPixelFile& b);

bool SamePixels(const extras::PackedImage& a, const extras::PackedImage& b);

bool SamePixels(const extras::PackedPixelFile& a,
                const extras::PackedPixelFile& b);

class ThreadPoolForTests {
 public:
  explicit ThreadPoolForTests(int num_threads) {
    runner_ =
        JxlThreadParallelRunnerMake(/* memory_manager */ nullptr, num_threads);
    pool_ =
        jxl::make_unique<ThreadPool>(JxlThreadParallelRunner, runner_.get());
  }
  ThreadPoolForTests(const ThreadPoolForTests&) = delete;
  ThreadPoolForTests& operator&(const ThreadPoolForTests&) = delete;
  ThreadPool* operator&() { return pool_.get(); }

 private:
  JxlThreadParallelRunnerPtr runner_;
  std::unique_ptr<ThreadPool> pool_;
};

}  // namespace test

bool operator==(const jxl::PaddedBytes& a, const jxl::PaddedBytes& b);

// Allow using EXPECT_EQ on jxl::PaddedBytes
bool operator!=(const jxl::PaddedBytes& a, const jxl::PaddedBytes& b);

}  // namespace jxl

#endif  // LIB_JXL_TEST_UTILS_H_
