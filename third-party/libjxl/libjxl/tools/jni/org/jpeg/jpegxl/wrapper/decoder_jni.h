// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef TOOLS_JNI_ORG_JPEG_JPEGXL_WRAPPER_DECODER_JNI
#define TOOLS_JNI_ORG_JPEG_JPEGXL_WRAPPER_DECODER_JNI

#include <jni.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Get basic image information (size, etc.)
 *
 * @param ctx {in_pixel_format_out_status, out_width, out_height, pixels_size,
 *             icc_size} tuple
 * @param data [in] Buffer with encoded JXL stream
 */
JNIEXPORT void JNICALL
Java_org_jpeg_jpegxl_wrapper_DecoderJni_nativeGetBasicInfo(JNIEnv* env,
                                                           jobject /*jobj*/,
                                                           jintArray ctx,
                                                           jobject data_buffer);

/**
 * Get image pixel data.
 *
 * @param ctx {in_pixel_format_out_status} tuple
 * @param data [in] Buffer with encoded JXL stream
 * @param pixels [out] Buffer to place pixels to
 */
JNIEXPORT void JNICALL Java_org_jpeg_jpegxl_wrapper_DecoderJni_nativeGetPixels(
    JNIEnv* env, jobject /*jobj*/, jintArray ctx, jobject data_buffer,
    jobject pixels_buffer, jobject icc_buffer);

#ifdef __cplusplus
}
#endif

#endif  // TOOLS_JNI_ORG_JPEG_JPEGXL_WRAPPER_DECODER_JNI