/*
 * Copyright 2018 Google Inc.
 *
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

// A simple bench harness for skcms_Transform(), mostly to run in a profiler.

#ifdef _MSC_VER
    #define _CRT_SECURE_NO_WARNINGS
#endif

#include "skcms.h"
#include "skcms_internal.h"
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define expect(cond) if (!(cond)) exit(1)

static void load_file(const char* filename, void** buf, size_t* len) {
    FILE* fp = fopen(filename, "rb");
    expect(fp);

    expect(fseek(fp, 0L, SEEK_END) == 0);
    long size = ftell(fp);
    expect(size > 0);
    *len = (size_t)size;
    rewind(fp);

    *buf = malloc(*len);
    expect(*buf);

    size_t bytes_read = fread(*buf, 1, *len, fp);
    expect(bytes_read == *len);
}

// Just to keep us on our toes, we transform a non-power-of-two number of pixels.
#define NPIXELS 255

static float src_pixels[NPIXELS * 4],
             dst_pixels[NPIXELS * 4];

int main(int argc, char** argv) {
    int           n = 100000;
    const char* src = NULL;
    const char* dst = NULL;

    for (int i = 0; i < argc; i++) {
        if (0 == strcmp(argv[i], "-n")) { n   = atoi(argv[++i]); }
        if (0 == strcmp(argv[i], "-s")) { src =      argv[++i] ; }
        if (0 == strcmp(argv[i], "-d")) { dst =      argv[++i] ; }
    }

    // Default to sRGB -> Display P3.
    skcms_ICCProfile src_profile = *skcms_sRGB_profile(),
                     dst_profile = *skcms_sRGB_profile();
    dst_profile.toXYZD50 = (skcms_Matrix3x3){{
        { 0.51512146f  , 0.29197692f , 0.15710449f},
        { 0.24119567f  , 0.6922454f  , 0.0665741f },
        {-0.0010375976f, 0.041885376f, 0.7840728f },
    }};

    void *src_buf = NULL,
         *dst_buf = NULL;
    size_t src_len,
           dst_len;
    if (src) {
        load_file(src, &src_buf, &src_len);
        if (!skcms_Parse(src_buf, src_len, &src_profile)) {
            return 1;
        }
    }
    if (dst) {
        load_file(dst, &dst_buf, &dst_len);
        if (!skcms_Parse(dst_buf, dst_len, &dst_profile)) {
            return 1;
        }
    }

    // We'll rotate through pixel formats to get samples from all the various stages.
    skcms_PixelFormat src_fmt = skcms_PixelFormat_RGB_565,
                      dst_fmt = skcms_PixelFormat_RGB_565;
    const int wrap = skcms_PixelFormat_BGRA_ffff+1;

    uint32_t palette[256];
    for (int i = 0; i < 256; i++) {
        palette[i] = (uint32_t)(255 - i%256) * 0x01010101;
    }

    clock_t start = clock();
    bool all_ok = true;
    for (int i = 0; i < n; i++) {
        const skcms_AlphaFormat upm = skcms_AlphaFormat_Unpremul;
        all_ok &= skcms_TransformWithPalette(src_pixels, src_fmt, upm, &src_profile,
                                             dst_pixels, dst_fmt, upm, &dst_profile,
                                             NPIXELS, palette);
        src_fmt = (src_fmt + 3) % wrap;
        do {
            dst_fmt = (dst_fmt + 7) % wrap;
        } while (needs_palette(dst_fmt));
    }

    clock_t ticks = clock() - start;
    printf("%d loops in %g clock ticks, %.3g ns / pixel\n",
            n, (double)ticks, (double)ticks / (CLOCKS_PER_SEC * 1e-9) / (n * NPIXELS));

    if (src_buf) { free(src_buf); }
    if (dst_buf) { free(dst_buf); }

    return all_ok ? 0 : 1;
}
