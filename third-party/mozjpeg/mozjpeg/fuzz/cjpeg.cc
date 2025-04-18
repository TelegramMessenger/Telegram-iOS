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

/* This fuzz target wraps cjpeg in order to test esoteric compression options
   as well as the GIF and Targa readers. */

#define main  cjpeg_main
#define CJPEG_FUZZER
extern "C" {
#include "../cjpeg.c"
}
#undef main
#undef CJPEG_FUZZER

#include <stdint.h>
#include <unistd.h>


extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
  char filename[FILENAME_MAX] = { 0 };
  char *argv1[] = {
    (char *)"cjpeg", (char *)"-dct", (char *)"float", (char *)"-memdst",
    (char *)"-optimize", (char *)"-quality", (char *)"100,99,98",
    (char *)"-restart", (char *)"2", (char *)"-sample", (char *)"4x1,2x2,1x2",
    (char *)"-targa", NULL
  };
  char *argv2[] = {
    (char *)"cjpeg", (char *)"-arithmetic", (char *)"-dct", (char *)"float",
    (char *)"-memdst", (char *)"-quality", (char *)"90,80,70", (char *)"-rgb",
    (char *)"-sample", (char *)"2x2", (char *)"-smooth", (char *)"50",
    (char *)"-targa", NULL
  };
  int fd = -1;
#if defined(__has_feature) && __has_feature(memory_sanitizer)
  char env[18] = "JSIMD_FORCENONE=1";

  /* The libjpeg-turbo SIMD extensions produce false positives with
     MemorySanitizer. */
  putenv(env);
#endif

  snprintf(filename, FILENAME_MAX, "/tmp/libjpeg-turbo_cjpeg_fuzz.XXXXXX");
  if ((fd = mkstemp(filename)) < 0 || write(fd, data, size) < 0)
    goto bailout;

  argv1[12] = argv2[13] = filename;

  cjpeg_main(13, argv1);
  cjpeg_main(14, argv2);

  argv1[12] = argv2[13] = NULL;
  argv1[11] = argv2[12] = filename;

  cjpeg_main(12, argv1);
  cjpeg_main(13, argv2);

bailout:
  if (fd >= 0) {
    close(fd);
    if (strlen(filename) > 0) unlink(filename);
  }
  return 0;
}
