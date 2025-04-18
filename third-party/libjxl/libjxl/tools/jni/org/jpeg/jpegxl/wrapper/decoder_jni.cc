// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "tools/jni/org/jpeg/jpegxl/wrapper/decoder_jni.h"

#include <jni.h>
#include <jxl/decode.h>
#include <jxl/thread_parallel_runner.h>

#include <cstdlib>

namespace {

template <typename From, typename To>
bool StaticCast(const From& from, To* to) {
  To tmp = static_cast<To>(from);
  // Check sign is preserved.
  if ((from < 0 && tmp > 0) || (from > 0 && tmp < 0)) return false;
  // Check value is preserved.
  if (from != static_cast<From>(tmp)) return false;
  *to = tmp;
  return true;
}

bool BufferToSpan(JNIEnv* env, jobject buffer, uint8_t** data, size_t* size) {
  if (buffer == nullptr) return true;

  *data = reinterpret_cast<uint8_t*>(env->GetDirectBufferAddress(buffer));
  if (*data == nullptr) return false;
  return StaticCast(env->GetDirectBufferCapacity(buffer), size);
}

enum class Status { OK = 0, FATAL_ERROR = -1, NOT_ENOUGH_INPUT = 1 };

bool IsOk(Status status) { return status == Status::OK; }

#define FAILURE(M) Status::FATAL_ERROR

constexpr const size_t kLastPixelFormat = 3;
constexpr const size_t kNoPixelFormat = static_cast<size_t>(-1);

JxlPixelFormat ToPixelFormat(size_t pixel_format) {
  if (pixel_format == 0) {
    // RGBA, 4 x byte per pixel, no scanline padding.
    return {/*num_channels=*/4, JXL_TYPE_UINT8, JXL_LITTLE_ENDIAN, /*align=*/0};
  } else if (pixel_format == 1) {
    // RGBA, 4 x float16 per pixel, no scanline padding.
    return {/*num_channels=*/4, JXL_TYPE_FLOAT16, JXL_LITTLE_ENDIAN,
            /*align=*/0};
  } else if (pixel_format == 2) {
    // RGB, 4 x byte per pixel, no scanline padding.
    return {/*num_channels=*/3, JXL_TYPE_UINT8, JXL_LITTLE_ENDIAN, /*align=*/0};
  } else if (pixel_format == 3) {
    // RGB, 4 x float16 per pixel, no scanline padding.
    return {/*num_channels=*/3, JXL_TYPE_FLOAT16, JXL_LITTLE_ENDIAN,
            /*align=*/0};
  } else {
    abort();
    return {0, JXL_TYPE_UINT8, JXL_LITTLE_ENDIAN, 0};
  }
}

Status DoDecode(JNIEnv* env, jobject data_buffer, size_t* info_pixels_size,
                size_t* info_icc_size, JxlBasicInfo* info, size_t pixel_format,
                jobject pixels_buffer, jobject icc_buffer) {
  if (data_buffer == nullptr) return FAILURE("No data buffer");

  uint8_t* data = nullptr;
  size_t data_size = 0;
  if (!BufferToSpan(env, data_buffer, &data, &data_size)) {
    return FAILURE("Failed to access data buffer");
  }

  uint8_t* pixels = nullptr;
  size_t pixels_size = 0;
  if (!BufferToSpan(env, pixels_buffer, &pixels, &pixels_size)) {
    return FAILURE("Failed to access pixels buffer");
  }

  uint8_t* icc = nullptr;
  size_t icc_size = 0;
  if (!BufferToSpan(env, icc_buffer, &icc, &icc_size)) {
    return FAILURE("Failed to access ICC buffer");
  }

  JxlDecoder* dec = JxlDecoderCreate(NULL);

  constexpr size_t kNumThreads = 0;  // Do everything in this thread.
  void* runner = JxlThreadParallelRunnerCreate(NULL, kNumThreads);

  struct Defer {
    JxlDecoder* dec;
    void* runner;
    ~Defer() {
      JxlThreadParallelRunnerDestroy(runner);
      JxlDecoderDestroy(dec);
    }
  } defer{dec, runner};

  auto status =
      JxlDecoderSetParallelRunner(dec, JxlThreadParallelRunner, runner);
  if (status != JXL_DEC_SUCCESS) {
    return FAILURE("Failed to set parallel runner");
  }
  status = JxlDecoderSubscribeEvents(
      dec, JXL_DEC_BASIC_INFO | JXL_DEC_FULL_IMAGE | JXL_DEC_COLOR_ENCODING);
  if (status != JXL_DEC_SUCCESS) {
    return FAILURE("Failed to subscribe for events");
  }
  status = JxlDecoderSetInput(dec, data, data_size);
  if (status != JXL_DEC_SUCCESS) {
    return FAILURE("Failed to set input");
  }
  status = JxlDecoderProcessInput(dec);
  if (status == JXL_DEC_NEED_MORE_INPUT) {
    return Status::NOT_ENOUGH_INPUT;
  }
  if (status != JXL_DEC_BASIC_INFO) {
    return FAILURE("Unexpected notification (want: basic info)");
  }
  if (info_pixels_size) {
    JxlPixelFormat format = ToPixelFormat(pixel_format);
    status = JxlDecoderImageOutBufferSize(dec, &format, info_pixels_size);
    if (status != JXL_DEC_SUCCESS) {
      return FAILURE("Failed to get pixels size");
    }
  }
  if (info) {
    status = JxlDecoderGetBasicInfo(dec, info);
    if (status != JXL_DEC_SUCCESS) {
      return FAILURE("Failed to get basic info");
    }
  }
  status = JxlDecoderProcessInput(dec);
  if (status != JXL_DEC_COLOR_ENCODING) {
    return FAILURE("Unexpected notification (want: color encoding)");
  }
  if (info_icc_size) {
    status = JxlDecoderGetICCProfileSize(dec, JXL_COLOR_PROFILE_TARGET_DATA,
                                         info_icc_size);
    if (status != JXL_DEC_SUCCESS) *info_icc_size = 0;
  }
  if (icc && icc_size > 0) {
    status = JxlDecoderGetColorAsICCProfile(dec, JXL_COLOR_PROFILE_TARGET_DATA,
                                            icc, icc_size);
    if (status != JXL_DEC_SUCCESS) {
      return FAILURE("Failed to get ICC");
    }
  }
  if (pixels) {
    JxlPixelFormat format = ToPixelFormat(pixel_format);
    status = JxlDecoderProcessInput(dec);
    if (status != JXL_DEC_NEED_IMAGE_OUT_BUFFER) {
      return FAILURE("Unexpected notification (want: need out buffer)");
    }
    status = JxlDecoderSetImageOutBuffer(dec, &format, pixels, pixels_size);
    if (status != JXL_DEC_SUCCESS) {
      return FAILURE("Failed to set out buffer");
    }
    status = JxlDecoderProcessInput(dec);
    if (status != JXL_DEC_FULL_IMAGE) {
      return FAILURE("Unexpected notification (want: full image)");
    }
    status = JxlDecoderProcessInput(dec);
    if (status != JXL_DEC_SUCCESS) {
      return FAILURE("Unexpected notification (want: success)");
    }
  }

  return Status::OK;
}

}  // namespace

#ifdef __cplusplus
extern "C" {
#endif

JNIEXPORT void JNICALL
Java_org_jpeg_jpegxl_wrapper_DecoderJni_nativeGetBasicInfo(
    JNIEnv* env, jobject /*jobj*/, jintArray ctx, jobject data_buffer) {
  jint context[6] = {0};
  env->GetIntArrayRegion(ctx, 0, 1, context);

  JxlBasicInfo info = {};
  size_t pixels_size = 0;
  size_t icc_size = 0;
  size_t pixel_format = 0;

  Status status = Status::OK;

  if (IsOk(status)) {
    pixel_format = context[0];
    if (pixel_format == kNoPixelFormat) {
      // OK
    } else if (pixel_format > kLastPixelFormat) {
      status = FAILURE("Unrecognized pixel format");
    }
  }

  if (IsOk(status)) {
    bool want_output_size = (pixel_format != kNoPixelFormat);
    if (want_output_size) {
      status = DoDecode(
          env, data_buffer, &pixels_size, &icc_size, &info, pixel_format,
          /* pixels_buffer= */ nullptr, /* icc_buffer= */ nullptr);
    } else {
      status =
          DoDecode(env, data_buffer, /* info_pixels_size= */ nullptr,
                   /* info_icc_size= */ nullptr, &info, pixel_format,
                   /* pixels_buffer= */ nullptr, /* icc_buffer= */ nullptr);
    }
  }

  if (IsOk(status)) {
    bool ok = true;
    ok &= StaticCast(info.xsize, context + 1);
    ok &= StaticCast(info.ysize, context + 2);
    ok &= StaticCast(pixels_size, context + 3);
    ok &= StaticCast(icc_size, context + 4);
    ok &= StaticCast(info.alpha_bits, context + 5);
    if (!ok) status = FAILURE("Invalid value");
  }

  context[0] = static_cast<int>(status);

  env->SetIntArrayRegion(ctx, 0, 6, context);
}

/**
 * Get image pixel data.
 *
 * @param ctx {out_status} tuple
 * @param data [in] Buffer with encoded JXL stream
 * @param pixels [out] Buffer to place pixels to
 */
JNIEXPORT void JNICALL Java_org_jpeg_jpegxl_wrapper_DecoderJni_nativeGetPixels(
    JNIEnv* env, jobject /* jobj */, jintArray ctx, jobject data_buffer,
    jobject pixels_buffer, jobject icc_buffer) {
  jint context[1] = {0};
  env->GetIntArrayRegion(ctx, 0, 1, context);

  size_t pixel_format = 0;

  Status status = Status::OK;

  if (IsOk(status)) {
    // Unlike getBasicInfo, "no-pixel-format" is not supported.
    pixel_format = context[0];
    if (pixel_format > kLastPixelFormat) {
      status = FAILURE("Unrecognized pixel format");
    }
  }

  if (IsOk(status)) {
    status = DoDecode(env, data_buffer, /* info_pixels_size= */ nullptr,
                      /* info_icc_size= */ nullptr, /* info= */ nullptr,
                      pixel_format, pixels_buffer, icc_buffer);
  }

  context[0] = static_cast<int>(status);
  env->SetIntArrayRegion(ctx, 0, 1, context);
}

#undef FAILURE

#ifdef __cplusplus
}
#endif
