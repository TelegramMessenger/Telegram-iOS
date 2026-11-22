/*
 * Copyright (C)2021, 2023 D. R. Commander.  All Rights Reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * - Redistributions of source code must retain the above copyright notice,
 *   this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright notice,
 *   this list of conditions and the following disclaimer in the documentation
 *   and/or other materials provided with the distribution.
 * - Neither the name of the libjpeg-turbo Project nor the names of its
 *   contributors may be used to endorse or promote products derived from this
 *   software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS",
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#include <turbojpeg.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>


extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
  tjhandle handle = NULL;
  unsigned char *dstBufs[1] = { NULL };
  unsigned long dstSizes[1] = { 0 }, maxBufSize;
  int width = 0, height = 0, jpegSubsamp, jpegColorspace, i;
  tjtransform transforms[1];
#if defined(__has_feature) && __has_feature(memory_sanitizer)
  char env[18] = "JSIMD_FORCENONE=1";

  /* The libjpeg-turbo SIMD extensions produce false positives with
     MemorySanitizer. */
  putenv(env);
#endif

  if ((handle = tjInitTransform()) == NULL)
    goto bailout;

  /* We ignore the return value of tjDecompressHeader3(), because some JPEG
     images may have unusual subsampling configurations that the TurboJPEG API
     cannot identify but can still transform. */
  tjDecompressHeader3(handle, data, size, &width, &height, &jpegSubsamp,
                      &jpegColorspace);

  /* Ignore 0-pixel images and images larger than 1 Megapixel.  Casting width
     to (uint64_t) prevents integer overflow if width * height > INT_MAX. */
  if (width < 1 || height < 1 || (uint64_t)width * height > 1048576)
    goto bailout;

  if (jpegSubsamp < 0 || jpegSubsamp >= TJ_NUMSAMP)
    jpegSubsamp = TJSAMP_444;

  memset(&transforms[0], 0, sizeof(tjtransform));

  transforms[0].op = TJXOP_NONE;
  transforms[0].options = TJXOPT_PROGRESSIVE | TJXOPT_COPYNONE;
  dstBufs[0] = (unsigned char *)malloc(tjBufSize(width, height, jpegSubsamp));
  if (!dstBufs[0])
    goto bailout;

  maxBufSize = tjBufSize(width, height, jpegSubsamp);

  if (tjTransform(handle, data, size, 1, dstBufs, dstSizes, transforms,
                  TJFLAG_LIMITSCANS | TJFLAG_NOREALLOC) == 0) {
    /* Touch all of the output pixels in order to catch uninitialized reads
       when using MemorySanitizer. */
    int sum = 0;

    for (i = 0; i < dstSizes[0]; i++)
      sum += dstBufs[0][i];

    /* Prevent the code above from being optimized out.  This test should
       never be true, but the compiler doesn't know that. */
    if (sum > 255 * maxBufSize)
      goto bailout;
  }

  free(dstBufs[0]);
  dstBufs[0] = NULL;

  transforms[0].r.w = (height + 1) / 2;
  transforms[0].r.h = (width + 1) / 2;
  transforms[0].op = TJXOP_TRANSPOSE;
  transforms[0].options = TJXOPT_GRAY | TJXOPT_CROP | TJXOPT_COPYNONE;
  dstBufs[0] =
    (unsigned char *)malloc(tjBufSize((height + 1) / 2, (width + 1) / 2,
                                      jpegSubsamp));
  if (!dstBufs[0])
    goto bailout;

  maxBufSize = tjBufSize((height + 1) / 2, (width + 1) / 2, jpegSubsamp);

  if (tjTransform(handle, data, size, 1, dstBufs, dstSizes, transforms,
                  TJFLAG_LIMITSCANS | TJFLAG_NOREALLOC) == 0) {
    int sum = 0;

    for (i = 0; i < dstSizes[0]; i++)
      sum += dstBufs[0][i];

    if (sum > 255 * maxBufSize)
      goto bailout;
  }

  free(dstBufs[0]);
  dstBufs[0] = NULL;

  transforms[0].op = TJXOP_ROT90;
  transforms[0].options = TJXOPT_TRIM;
  dstBufs[0] = (unsigned char *)malloc(tjBufSize(height, width, jpegSubsamp));
  if (!dstBufs[0])
    goto bailout;

  maxBufSize = tjBufSize(height, width, jpegSubsamp);

  if (tjTransform(handle, data, size, 1, dstBufs, dstSizes, transforms,
                  TJFLAG_LIMITSCANS | TJFLAG_NOREALLOC) == 0) {
    int sum = 0;

    for (i = 0; i < dstSizes[0]; i++)
      sum += dstBufs[0][i];

    if (sum > 255 * maxBufSize)
      goto bailout;
  }

  free(dstBufs[0]);
  dstBufs[0] = NULL;

  transforms[0].op = TJXOP_NONE;
  transforms[0].options = TJXOPT_PROGRESSIVE;
  dstSizes[0] = 0;

  if (tjTransform(handle, data, size, 1, dstBufs, dstSizes, transforms,
                  TJFLAG_LIMITSCANS) == 0) {
    int sum = 0;

    for (i = 0; i < dstSizes[0]; i++)
      sum += dstBufs[0][i];

    if (sum > 255 * maxBufSize)
      goto bailout;
  }

bailout:
  free(dstBufs[0]);
  if (handle) tjDestroy(handle);
  return 0;
}
