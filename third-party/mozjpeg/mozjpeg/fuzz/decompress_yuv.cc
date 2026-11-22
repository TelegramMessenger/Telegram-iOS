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


#define NUMPF  3


extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
  tjhandle handle = NULL;
  unsigned char *dstBuf = NULL, *yuvBuf = NULL;
  int width = 0, height = 0, jpegSubsamp, jpegColorspace, pfi;
  /* TJPF_RGB-TJPF_BGR share the same code paths, as do TJPF_RGBX-TJPF_XRGB and
     TJPF_RGBA-TJPF_ARGB.  Thus, the pixel formats below should be the minimum
     necessary to achieve full coverage. */
  enum TJPF pixelFormats[NUMPF] =
    { TJPF_BGR, TJPF_XRGB, TJPF_GRAY };
#if defined(__has_feature) && __has_feature(memory_sanitizer)
  char env[18] = "JSIMD_FORCENONE=1";

  /* The libjpeg-turbo SIMD extensions produce false positives with
     MemorySanitizer. */
  putenv(env);
#endif

  if ((handle = tjInitDecompress()) == NULL)
    goto bailout;

  if (tjDecompressHeader3(handle, data, size, &width, &height, &jpegSubsamp,
                          &jpegColorspace) < 0)
    goto bailout;

  /* Ignore 0-pixel images and images larger than 1 Megapixel.  Casting width
     to (uint64_t) prevents integer overflow if width * height > INT_MAX. */
  if (width < 1 || height < 1 || (uint64_t)width * height > 1048576)
    goto bailout;

  for (pfi = 0; pfi < NUMPF; pfi++) {
    int pf = pixelFormats[pfi], flags = TJFLAG_LIMITSCANS, i, sum = 0;
    int w = width, h = height;

    /* Test non-default decompression options on the first iteration. */
    if (pfi == 0)
      flags |= TJFLAG_BOTTOMUP | TJFLAG_FASTUPSAMPLE | TJFLAG_FASTDCT;
    /* Test IDCT scaling on the second iteration. */
    else if (pfi == 1) {
      w = (width + 3) / 4;
      h = (height + 3) / 4;
    }

    if ((dstBuf = (unsigned char *)malloc(w * h * tjPixelSize[pf])) == NULL)
      goto bailout;
    if ((yuvBuf =
         (unsigned char *)malloc(tjBufSizeYUV2(w, 1, h, jpegSubsamp))) == NULL)
      goto bailout;

    if (tjDecompressToYUV2(handle, data, size, yuvBuf, w, 1, h, flags) == 0 &&
        tjDecodeYUV(handle, yuvBuf, 1, jpegSubsamp, dstBuf, w, 0, h, pf,
                    flags) == 0) {
      /* Touch all of the output pixels in order to catch uninitialized reads
         when using MemorySanitizer. */
      for (i = 0; i < w * h * tjPixelSize[pf]; i++)
        sum += dstBuf[i];
    } else
      goto bailout;

    free(dstBuf);
    dstBuf = NULL;
    free(yuvBuf);
    yuvBuf = NULL;

    /* Prevent the code above from being optimized out.  This test should never
       be true, but the compiler doesn't know that. */
    if (sum > 255 * 1048576 * tjPixelSize[pf])
      goto bailout;
  }

bailout:
  free(dstBuf);
  free(yuvBuf);
  if (handle) tjDestroy(handle);
  return 0;
}
