/*
 * Copyright (C)2021 D. R. Commander.  All Rights Reserved.
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
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>


#define NUMTESTS  7
/* Private flag that triggers different TurboJPEG API behavior when fuzzing */
#define TJFLAG_FUZZING  (1 << 30)


struct test {
  enum TJPF pf;
  enum TJSAMP subsamp;
  int quality;
};


extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
  tjhandle handle = NULL;
  unsigned char *srcBuf = NULL, *dstBuf = NULL;
  int width = 0, height = 0, fd = -1, i, ti;
  char filename[FILENAME_MAX] = { 0 };
  struct test tests[NUMTESTS] = {
    { TJPF_RGB, TJSAMP_444, 100 },
    { TJPF_BGR, TJSAMP_422, 90 },
    { TJPF_RGBX, TJSAMP_420, 80 },
    { TJPF_BGRA, TJSAMP_411, 70 },
    { TJPF_XRGB, TJSAMP_GRAY, 60 },
    { TJPF_GRAY, TJSAMP_GRAY, 50 },
    { TJPF_CMYK, TJSAMP_440, 40 }
  };
#if defined(__has_feature) && __has_feature(memory_sanitizer)
  char env[18] = "JSIMD_FORCENONE=1";

  /* The libjpeg-turbo SIMD extensions produce false positives with
     MemorySanitizer. */
  putenv(env);
#endif

  snprintf(filename, FILENAME_MAX, "/tmp/libjpeg-turbo_compress_fuzz.XXXXXX");
  if ((fd = mkstemp(filename)) < 0 || write(fd, data, size) < 0)
    goto bailout;

  if ((handle = tjInitCompress()) == NULL)
    goto bailout;

  for (ti = 0; ti < NUMTESTS; ti++) {
    int flags = TJFLAG_FUZZING, sum = 0, pf = tests[ti].pf;
    unsigned long dstSize = 0, maxBufSize;

    /* Test non-default compression options on specific iterations. */
    if (ti == 0)
      flags |= TJFLAG_BOTTOMUP | TJFLAG_ACCURATEDCT;
    else if (ti == 1)
      flags |= TJFLAG_PROGRESSIVE;
    if (ti != 2)
      flags |= TJFLAG_NOREALLOC;

    /* tjLoadImage() refuses to load images larger than 1 Megapixel when
       FUZZING_BUILD_MODE_UNSAFE_FOR_PRODUCTION is defined (yes, that's a dirty
       hack), so we don't need to check the width and height here. */
    if ((srcBuf = tjLoadImage(filename, &width, 1, &height, &pf,
                              flags)) == NULL)
      continue;

    maxBufSize = tjBufSize(width, height, tests[ti].subsamp);
    if (flags & TJFLAG_NOREALLOC) {
      if ((dstBuf = (unsigned char *)malloc(maxBufSize)) == NULL)
        goto bailout;
    } else
      dstBuf = NULL;

    if (tjCompress2(handle, srcBuf, width, 0, height, pf, &dstBuf, &dstSize,
                    tests[ti].subsamp, tests[ti].quality, flags) == 0) {
      /* Touch all of the output pixels in order to catch uninitialized reads
         when using MemorySanitizer. */
      for (i = 0; i < dstSize; i++)
        sum += dstBuf[i];
    }

    free(dstBuf);
    dstBuf = NULL;
    tjFree(srcBuf);
    srcBuf = NULL;

    /* Prevent the code above from being optimized out.  This test should never
       be true, but the compiler doesn't know that. */
    if (sum > 255 * maxBufSize)
      goto bailout;
  }

bailout:
  free(dstBuf);
  tjFree(srcBuf);
  if (fd >= 0) {
    close(fd);
    if (strlen(filename) > 0) unlink(filename);
  }
  if (handle) tjDestroy(handle);
  return 0;
}
