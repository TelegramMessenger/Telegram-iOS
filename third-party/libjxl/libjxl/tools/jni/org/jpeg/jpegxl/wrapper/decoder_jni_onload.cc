// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <jni.h>

#include "tools/jni/org/jpeg/jpegxl/wrapper/decoder_jni.h"

#ifdef __cplusplus
extern "C" {
#endif

static char* kGetBasicInfoName = const_cast<char*>("nativeGetBasicInfo");
static char* kGetBasicInfoSig = const_cast<char*>("([ILjava/nio/Buffer;)V");
static char* kGetPixelsName = const_cast<char*>("nativeGetPixels");
static char* kGetPixelsInfoSig = const_cast<char*>(
    "([ILjava/nio/Buffer;Ljava/nio/Buffer;Ljava/nio/Buffer;)V");

#define JXL_JNI_METHOD(NAME) \
  (reinterpret_cast<void*>(  \
      Java_org_jpeg_jpegxl_wrapper_DecoderJni_native##NAME))

static const JNINativeMethod kDecoderMethods[] = {
    {kGetBasicInfoName, kGetBasicInfoSig, JXL_JNI_METHOD(GetBasicInfo)},
    {kGetPixelsName, kGetPixelsInfoSig, JXL_JNI_METHOD(GetPixels)}};

static const size_t kNumDecoderMethods = 2;

#undef JXL_JNI_METHOD

JNIEXPORT jint JNI_OnLoad(JavaVM* vm, void* reserved) {
  JNIEnv* env;
  if (vm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6) != JNI_OK) {
    return -1;
  }

  jclass clazz = env->FindClass("org/jpeg/jpegxl/wrapper/DecoderJni");
  if (clazz == nullptr) {
    return -1;
  }

  if (env->RegisterNatives(clazz, kDecoderMethods, kNumDecoderMethods) < 0) {
    return -1;
  }

  return JNI_VERSION_1_6;
}

#ifdef __cplusplus
}
#endif
