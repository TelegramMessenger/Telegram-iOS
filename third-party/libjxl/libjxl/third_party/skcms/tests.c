/*
 * Copyright 2018 Google Inc.
 *
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#ifdef _MSC_VER
#define _CRT_SECURE_NO_WARNINGS
#pragma warning( disable : 6011 ) // dereferencing NULL pointer (from malloc)
#endif

#include "skcms.h"
#include "skcms_internal.h"
#include "test_only.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if defined(__ARM_FEATURE_FP16_VECTOR_ARITHMETIC) && defined(SKCMS_OPT_INTO_NEON_FP16)
    static bool kFP16 = true;
#else
    static bool kFP16 = false;
#endif

#if defined(_MSC_VER)
    #define DEBUGBREAK __debugbreak
#elif defined(__clang__)
    #define DEBUGBREAK __builtin_debugtrap
#else
    #define DEBUGBREAK __builtin_trap
#endif

#define expect(cond)                                                                  \
    do {                                                                              \
        if (!(cond)) {                                                                \
            fprintf(stderr, "expect(" #cond ") failed at %s:%d\n",__FILE__,__LINE__); \
            fflush(stderr);   /* stderr is buffered on Windows. */                    \
            DEBUGBREAK();                                                             \
        }                                                                             \
    } while(false)

#define expect_close(x,y)                                                                 \
    do {                                                                                  \
        double X = (double)(x),                                                           \
               Y = (double)(y);                                                           \
        if (X == (double)(int)X &&                                                        \
            Y == (double)(int)Y &&                                                        \
            (X == Y-1 || Y == X-1)) {                                                     \
            /* These are ints and off by one.  Sounds close to me. */                     \
        } else {                                                                          \
            double ratio = (X < Y) ? X / Y                                                \
                         : (Y < X) ? Y / X                                                \
                         : 1.0;                                                           \
            if (ratio < (kFP16 ? 0.995 : 1.0)) {                                          \
                fprintf(stderr, "expect_close(" #x "==%g, " #y "==%g) failed at %s:%d\n", \
                        X,Y, __FILE__,__LINE__);                                          \
                fflush(stderr);   /* stderr is buffered on Windows. */                    \
                DEBUGBREAK();                                                             \
            }                                                                             \
        }                                                                                 \
    } while(false)



static void test_ICCProfile() {
    // Nothing works yet.  :)
    skcms_ICCProfile profile;

    const uint8_t buf[] = { 0x42 };
    expect(!skcms_Parse(buf, sizeof(buf), &profile));
}

static void test_FormatConversions() {
    // We can interpret src as 85 RGB_888 pixels or 64 RGB_8888 pixels.
    uint8_t src[256],
            dst[85*4];
    for (int i = 0; i < 256; i++) {
        src[i] = (uint8_t)i;
    }

    // This should basically be a really complicated memcpy().
    expect(skcms_Transform(src, skcms_PixelFormat_RGBA_8888, skcms_AlphaFormat_Unpremul, NULL,
                           dst, skcms_PixelFormat_RGBA_8888, skcms_AlphaFormat_Unpremul, NULL,
                           64));
    for (int i = 0; i < 256; i++) {
        expect(dst[i] == i);
    }

    // We can do RGBA -> BGRA swaps two ways:
    expect(skcms_Transform(src, skcms_PixelFormat_RGBA_8888, skcms_AlphaFormat_Unpremul, NULL,
                           dst, skcms_PixelFormat_BGRA_8888, skcms_AlphaFormat_Unpremul, NULL,
                           64));
    for (int i = 0; i < 64; i++) {
        expect(dst[4*i+0] == 4*i+2);
        expect(dst[4*i+1] == 4*i+1);
        expect(dst[4*i+2] == 4*i+0);
        expect(dst[4*i+3] == 4*i+3);
    }
    expect(skcms_Transform(src, skcms_PixelFormat_BGRA_8888, skcms_AlphaFormat_Unpremul, NULL,
                           dst, skcms_PixelFormat_RGBA_8888, skcms_AlphaFormat_Unpremul, NULL,
                           64));
    for (int i = 0; i < 64; i++) {
        expect(dst[4*i+0] == 4*i+2);
        expect(dst[4*i+1] == 4*i+1);
        expect(dst[4*i+2] == 4*i+0);
        expect(dst[4*i+3] == 4*i+3);
    }

    // Let's convert RGB_888 to RGBA_8888...
    expect(skcms_Transform(src, skcms_PixelFormat_RGB_888  , skcms_AlphaFormat_Unpremul, NULL,
                           dst, skcms_PixelFormat_RGBA_8888, skcms_AlphaFormat_Unpremul, NULL,
                           85));
    for (int i = 0; i < 85; i++) {
        expect(dst[4*i+0] == 3*i+0);
        expect(dst[4*i+1] == 3*i+1);
        expect(dst[4*i+2] == 3*i+2);
        expect(dst[4*i+3] ==   255);
    }
    // ... and now all the variants of R-B swaps.
    expect(skcms_Transform(src, skcms_PixelFormat_BGR_888  , skcms_AlphaFormat_Unpremul, NULL,
                           dst, skcms_PixelFormat_BGRA_8888, skcms_AlphaFormat_Unpremul, NULL,
                           85));
    for (int i = 0; i < 85; i++) {
        expect(dst[4*i+0] == 3*i+0);
        expect(dst[4*i+1] == 3*i+1);
        expect(dst[4*i+2] == 3*i+2);
        expect(dst[4*i+3] ==   255);
    }
    expect(skcms_Transform(src, skcms_PixelFormat_BGR_888  , skcms_AlphaFormat_Unpremul, NULL,
                           dst, skcms_PixelFormat_RGBA_8888, skcms_AlphaFormat_Unpremul, NULL,
                           85));
    for (int i = 0; i < 85; i++) {
        expect(dst[4*i+0] == 3*i+2);
        expect(dst[4*i+1] == 3*i+1);
        expect(dst[4*i+2] == 3*i+0);
        expect(dst[4*i+3] ==   255);
    }
    expect(skcms_Transform(src, skcms_PixelFormat_RGB_888  , skcms_AlphaFormat_Unpremul, NULL,
                           dst, skcms_PixelFormat_BGRA_8888, skcms_AlphaFormat_Unpremul, NULL,
                           85));
    for (int i = 0; i < 85; i++) {
        expect(dst[4*i+0] == 3*i+2);
        expect(dst[4*i+1] == 3*i+1);
        expect(dst[4*i+2] == 3*i+0);
        expect(dst[4*i+3] ==   255);
    }

    // Let's test in-place transforms.
    // RGBA_8888 and RGB_888 aren't the same size, so we shouldn't allow this call.
    expect(!skcms_Transform(src, skcms_PixelFormat_RGB_888  , skcms_AlphaFormat_Unpremul, NULL,
                            src, skcms_PixelFormat_RGBA_8888, skcms_AlphaFormat_Unpremul, NULL,
                            85));

    // These two should work fine.
    expect(skcms_Transform(src, skcms_PixelFormat_BGRA_8888, skcms_AlphaFormat_Unpremul, NULL,
                           src, skcms_PixelFormat_RGBA_8888, skcms_AlphaFormat_Unpremul, NULL,
                           64));
    for (int i = 0; i < 64; i++) {
        expect(src[4*i+0] == 4*i+2);
        expect(src[4*i+1] == 4*i+1);
        expect(src[4*i+2] == 4*i+0);
        expect(src[4*i+3] == 4*i+3);
    }
    expect(skcms_Transform(src, skcms_PixelFormat_RGBA_8888, skcms_AlphaFormat_Unpremul, NULL,
                           src, skcms_PixelFormat_BGRA_8888, skcms_AlphaFormat_Unpremul, NULL,
                           64));
    for (int i = 0; i < 64; i++) {
        expect(src[4*i+0] == 4*i+0);
        expect(src[4*i+1] == 4*i+1);
        expect(src[4*i+2] == 4*i+2);
        expect(src[4*i+3] == 4*i+3);
    }

    uint32_t _8888[3] = { 0x03020100, 0x07060504, 0x0b0a0908 };
    uint8_t _888[9];
    expect(skcms_Transform(_8888, skcms_PixelFormat_RGBA_8888, skcms_AlphaFormat_Unpremul, NULL,
                           _888 , skcms_PixelFormat_RGB_888  , skcms_AlphaFormat_Unpremul, NULL,
                           3));
    expect(_888[0] == 0 && _888[1] == 1 && _888[2] ==  2);
    expect(_888[3] == 4 && _888[4] == 5 && _888[5] ==  6);
    expect(_888[6] == 8 && _888[7] == 9 && _888[8] == 10);
}

static void test_FormatConversions_565() {
    // This should hit all the unique values of each lane of 565.
    uint16_t src[64];
    for (int i = 0; i < 64; i++) {
        src[i] = (uint16_t)( (i/2) <<  0 )
               | (uint16_t)( (i/1) <<  5 )
               | (uint16_t)( (i/2) << 11 );
    }
    expect(src[ 0] == 0x0000);
    expect(src[31] == 0x7bef);
    expect(src[63] == 0xffff);

    uint32_t dst[64];
    expect(skcms_Transform(src, skcms_PixelFormat_RGB_565  , skcms_AlphaFormat_Unpremul, NULL,
                           dst, skcms_PixelFormat_RGBA_8888, skcms_AlphaFormat_Unpremul, NULL,
                           64));
    // We'll just spot check these results a bit.
    for (int i = 0; i < 64; i++) {
        expect((dst[i] >> 24) == 255);  // All opaque.
    }
    expect(dst[ 0] == 0xff000000);  // 0 -> 0
    expect(dst[20] == 0xff525152);  // (10/31) ≈ (82/255) and (20/63) ≈ (81/255)
    expect(dst[62] == 0xfffffbff);  // (31/31) == (255/255) and (62/63) ≈ (251/255)
    expect(dst[63] == 0xffffffff);  // 1 -> 1

    // Let's convert back the other way.
    uint16_t back[64];
    expect(skcms_Transform(dst , skcms_PixelFormat_RGBA_8888, skcms_AlphaFormat_Unpremul, NULL,
                           back, skcms_PixelFormat_RGB_565  , skcms_AlphaFormat_Unpremul, NULL,
                           64));
    for (int i = 0; i < 64; i++) {
        expect(src[i] == back[i]);
    }
}

static void test_FormatConversions_16161616LE() {
    // We want to hit each 16-bit value, 4 per each of 16384 pixels.
    uint64_t* src = malloc(8 * 16384);
    for (int i = 0; i < 16384; i++) {
        src[i] = (uint64_t)(4*i + 0) <<  0
               | (uint64_t)(4*i + 1) << 16
               | (uint64_t)(4*i + 2) << 32
               | (uint64_t)(4*i + 3) << 48;
    }
    expect(src[    0] == 0x0003000200010000);
    expect(src[   32] == 0x0083008200810080);  // just on the cusp of rounding to 0x00 or 0x01
    expect(src[16383] == 0xfffffffefffdfffc);

    uint32_t* dst = malloc(4 * 16384);
    expect(skcms_Transform(src, skcms_PixelFormat_RGBA_16161616LE, skcms_AlphaFormat_Unpremul, NULL,
                           dst, skcms_PixelFormat_RGBA_8888      , skcms_AlphaFormat_Unpremul, NULL,
                           16384));

    // skcms_Transform() will treat src as holding little-endian 16-bit values.

    expect(dst[    0] == 0x00000000);   // 0x0003 rounds to 0x00, etc.
    expect(dst[   32] == 0x01010100);   // 0x80 -> 0.9980544747081712, 0x81 -> 1.0019455252918288
    expect(dst[16383] == 0xffffffff);   // 0xfffc rounds to 0xff, etc.

    // We've lost precision when transforming to 8-bit, so these won't quite round-trip.
    // Instead we should see the 8-bit dst value byte-doubled, as 65535/255 = 257 = 0x0101.
    uint64_t* back = malloc(8 * 16384);
    expect(skcms_Transform(dst , skcms_PixelFormat_RGBA_8888      ,skcms_AlphaFormat_Unpremul, NULL,
                           back, skcms_PixelFormat_RGBA_16161616LE,skcms_AlphaFormat_Unpremul, NULL,
                           16384));
    for (int i = 0; i < 16384; i++) {
        expect_close( ((back[i] >>  0) & 0xffff) , ((dst[i] >>  0) & 0xff) * 0x0101);
        expect_close( ((back[i] >> 16) & 0xffff) , ((dst[i] >>  8) & 0xff) * 0x0101);
        expect_close( ((back[i] >> 32) & 0xffff) , ((dst[i] >> 16) & 0xff) * 0x0101);
        expect_close( ((back[i] >> 48) & 0xffff) , ((dst[i] >> 24) & 0xff) * 0x0101);
    }

    free(src);
    free(dst);
    free(back);
}

static void test_FormatConversions_161616LE() {
    // We'll test the same cases as the _16161616LE() test, as if they were 4 RGB pixels.
    uint16_t src[] = { 0x0000, 0x0001, 0x0002,
                       0x0003, 0x0080, 0x0081,
                       0x0082, 0x0083, 0xfffc,
                       0xfffd, 0xfffe, 0xffff };
    uint32_t dst[4];
    expect(skcms_Transform(src, skcms_PixelFormat_RGB_161616LE, skcms_AlphaFormat_Unpremul, NULL,
                           dst, skcms_PixelFormat_RGBA_8888   , skcms_AlphaFormat_Unpremul, NULL,
                           4));

    expect(dst[0] == 0xff000000);
    expect(dst[1] == 0xff010000);
    expect(dst[2] == 0xffff0101);
    expect(dst[3] == 0xffffffff);

    // We've lost precision when transforming to 8-bit, so these won't quite round-trip.
    // Instead we should see the 8-bit dst value byte-doubled, as 65535/255 = 257 = 0x0101.
    uint16_t back[12];
    expect(skcms_Transform(dst , skcms_PixelFormat_RGBA_8888   , skcms_AlphaFormat_Unpremul, NULL,
                           back, skcms_PixelFormat_RGB_161616LE, skcms_AlphaFormat_Unpremul, NULL,
                           4));

    uint16_t expected[] = { 0x0000, 0x0000, 0x0000,
                            0x0000, 0x0000, 0x0101,
                            0x0101, 0x0101, 0xffff,
                            0xffff, 0xffff, 0xffff };
    for (int i = 0; i < 12; i++) {
        expect_close(back[i], expected[i]);
    }
}

static int bswap16(int x) {
    return (x & 0x00ff) << 8
         | (x & 0xff00) >> 8;
}

static void test_FormatConversions_16161616BE() {
    // We want to hit each 16-bit value, 4 per each of 16384 pixels.
    uint64_t* src = malloc(8 * 16384);
    for (int i = 0; i < 16384; i++) {
        src[i] = (uint64_t)(4*i + 0) <<  0
               | (uint64_t)(4*i + 1) << 16
               | (uint64_t)(4*i + 2) << 32
               | (uint64_t)(4*i + 3) << 48;
    }
    expect(src[    0] == 0x0003000200010000);
    expect(src[ 8127] == 0x7eff7efe7efd7efc);  // This should demonstrate interesting rounding.
    expect(src[16383] == 0xfffffffefffdfffc);

    uint32_t* dst = malloc(4 * 16384);
    expect(skcms_Transform(src, skcms_PixelFormat_RGBA_16161616BE, skcms_AlphaFormat_Unpremul, NULL,
                           dst, skcms_PixelFormat_RGBA_8888      , skcms_AlphaFormat_Unpremul, NULL,
                           16384));

    // skcms_Transform() will treat src as holding big-endian 16-bit values,
    // so the low lanes are actually the most significant byte, and the high least.

    expect(dst[    0] == 0x03020100);
    expect(dst[ 8127] == (kFP16 ? 0xfffefdfc : 0xfefefdfc));
    expect(dst[16383] == 0xfffefdfc);

    // We've lost precision when transforming to 8-bit, so these won't quite round-trip.
    // Instead we should see the 8-bit dst value byte-doubled, as 65535/255 = 257 = 0x0101.
    uint64_t* back = malloc(8 * 16384);
    expect(skcms_Transform(dst , skcms_PixelFormat_RGBA_8888      ,skcms_AlphaFormat_Unpremul, NULL,
                           back, skcms_PixelFormat_RGBA_16161616BE,skcms_AlphaFormat_Unpremul, NULL,
                           16384));
    for (int i = 0; i < 16384; i++) {
        expect_close(bswap16((back[i] >>  0) & 0xffff), ((dst[i] >>  0) & 0xff) * 0x0101);
        expect_close(bswap16((back[i] >> 16) & 0xffff), ((dst[i] >>  8) & 0xff) * 0x0101);
        expect_close(bswap16((back[i] >> 32) & 0xffff), ((dst[i] >> 16) & 0xff) * 0x0101);
        expect_close(bswap16((back[i] >> 48) & 0xffff), ((dst[i] >> 24) & 0xff) * 0x0101);
    }

    free(src);
    free(dst);
    free(back);
}

static void test_FormatConversions_161616BE() {
    // We'll test the same cases as the _16161616BE() test, as if they were 4 RGB pixels.
    uint16_t src[] = { 0x0000, 0x0001, 0x0002,
                       0x0003, 0x7efc, 0x7efd,
                       0x7efe, 0x7eff, 0xfffc,
                       0xfffd, 0xfffe, 0xffff };
    uint32_t dst[4];
    expect(skcms_Transform(src, skcms_PixelFormat_RGB_161616BE, skcms_AlphaFormat_Unpremul, NULL,
                           dst, skcms_PixelFormat_RGBA_8888   , skcms_AlphaFormat_Unpremul, NULL,
                           4));

    expect(dst[0] == 0xff020100);
    expect(dst[1] == 0xfffdfc03);
    expect(dst[2] == (kFP16 ? 0xfffcfffe : 0xfffcfefe));
    expect(dst[3] == 0xfffffefd);

    // We've lost precision when transforming to 8-bit, so these won't quite round-trip.
    // Instead we should see the 8-bit dst value byte doubled, as 65535/255 = 257 = 0x0101.
    uint16_t back[12];
    expect(skcms_Transform(dst , skcms_PixelFormat_RGBA_8888   , skcms_AlphaFormat_Unpremul, NULL,
                           back, skcms_PixelFormat_RGB_161616BE, skcms_AlphaFormat_Unpremul, NULL,
                           4));
    uint16_t expected[] = { 0x0000, 0x0101, 0x0202,
                            0x0303, 0xfcfc, 0xfdfd,
                            0xfefe, 0xfefe, 0xfcfc,
                            0xfdfd, 0xfefe, 0xffff };
    for (int i = 0; i < 12; i++) {
        expect_close(bswap16(back[i]), expected[i]);
    }
}

static void test_FormatConversions_101010() {
    uint32_t src = (uint32_t)1023 <<  0    // 1.0.
                 | (uint32_t) 511 << 10    // About 1/2.
                 | (uint32_t)   4 << 20    // Smallest 10-bit channel that's non-zero in 8-bit.
                 | (uint32_t)   1 << 30;   // 1/3, smallest non-zero alpha.
    uint32_t dst;
    expect(skcms_Transform(&src, skcms_PixelFormat_RGBA_1010102, skcms_AlphaFormat_Unpremul, NULL,
                           &dst, skcms_PixelFormat_RGBA_8888   , skcms_AlphaFormat_Unpremul, NULL,
                           1));
    expect(dst == 0x55017fff);

    // Same as above, but we'll ignore the 1/3 alpha and fill in 1.0.
    expect(skcms_Transform(&src, skcms_PixelFormat_RGBA_1010102, skcms_AlphaFormat_Opaque  , NULL,
                           &dst, skcms_PixelFormat_RGBA_8888   , skcms_AlphaFormat_Unpremul, NULL,
                           1));
    expect(dst == 0xff017fff);

    // Converting 101010x <-> 1010102 will force opaque in either direction.
    expect(skcms_Transform(&src, skcms_PixelFormat_RGBA_1010102, skcms_AlphaFormat_Unpremul, NULL,
                           &dst, skcms_PixelFormat_RGBA_1010102, skcms_AlphaFormat_Opaque  , NULL,
                           1));
    expect(dst == ( (uint32_t)1023 <<  0
                  | (uint32_t) 511 << 10
                  | (uint32_t)   4 << 20
                  | (uint32_t)   3 << 30));
    expect(skcms_Transform(&src, skcms_PixelFormat_RGBA_1010102, skcms_AlphaFormat_Opaque  , NULL,
                           &dst, skcms_PixelFormat_RGBA_1010102, skcms_AlphaFormat_Unpremul, NULL,
                           1));
    expect(dst == ( (uint32_t)1023 <<  0
                  | (uint32_t) 511 << 10
                  | (uint32_t)   4 << 20
                  | (uint32_t)   3 << 30));
}

static void test_FormatConversions_half() {
    uint16_t src[] = {
        0x3c00,  // 1.0
        0x3800,  // 0.5
        0x1805,  // Should round up to 0x01
        0x1803,  // Should round down to 0x00  (0x1804 may go up or down depending on precision)
        0x4000,  // 2.0
        0x03ff,  // A denorm, may be flushed to zero.
        0x83ff,  // A negative denorm, may be flushed to zero.
        0xbc00,  // -1.0
    };

    uint32_t dst[2];
    expect(skcms_Transform(&src, skcms_PixelFormat_RGBA_hhhh, skcms_AlphaFormat_Unpremul, NULL,
                           &dst, skcms_PixelFormat_RGBA_8888, skcms_AlphaFormat_Unpremul, NULL,
                           2));
    expect(dst[0] == 0x000180ff);
    expect(dst[1] == 0x000000ff);  // Notice we've clamped 2.0 to 0xff and -1.0 to 0x00.

    expect(skcms_Transform(&src, skcms_PixelFormat_RGB_hhh  , skcms_AlphaFormat_Unpremul, NULL,
                           &dst, skcms_PixelFormat_RGBA_8888, skcms_AlphaFormat_Unpremul, NULL,
                           2));
    expect(dst[0] == 0xff0180ff);
    expect(dst[1] == 0xff00ff00);  // Remember, this corresponds to src[3-5].

    float fdst[8];
    expect(skcms_Transform( &src, skcms_PixelFormat_RGBA_hhhh, skcms_AlphaFormat_Unpremul, NULL,
                           &fdst, skcms_PixelFormat_RGBA_ffff, skcms_AlphaFormat_Unpremul, NULL,
                           2));
    expect(fdst[0] ==  1.0f);
    expect(fdst[1] ==  0.5f);
    expect(fdst[2] > 1/510.0f);
    expect(fdst[3] < 1/510.0f);
    expect(fdst[4] ==  2.0f);
    expect(fdst[5] == +0.00006097555f || fdst[5] == 0.0f);  // may have been flushed to zero
    expect(fdst[6] == -0.00006097555f || fdst[6] == 0.0f);
    expect(fdst[7] == -1.0f);

    // Now convert back, first to RGBA halfs, then RGB halfs.
    uint16_t back[8];
    expect(skcms_Transform(&fdst, skcms_PixelFormat_RGBA_ffff, skcms_AlphaFormat_Unpremul, NULL,
                           &back, skcms_PixelFormat_RGBA_hhhh, skcms_AlphaFormat_Unpremul, NULL,
                           2));
    expect(back[0] == src[0]);
    expect(back[1] == src[1]);
    expect(back[2] == src[2]);
    expect(back[3] == src[3]);
    expect(back[4] == src[4]);
    expect(back[5] == src[5] || back[5] == 0x0000);
    expect(back[6] == src[6] || back[6] == 0x0000);
    expect(back[7] == src[7]);

    expect(skcms_Transform(&fdst, skcms_PixelFormat_RGBA_ffff, skcms_AlphaFormat_Unpremul, NULL,
                           &back, skcms_PixelFormat_RGB_hhh  , skcms_AlphaFormat_Unpremul, NULL,
                           2));
    expect(back[0] == src[0]);
    expect(back[1] == src[1]);
    expect(back[2] == src[2]);
    expect(back[3] == src[4]);
    expect(back[4] == src[5] || back[4] == 0x0000);
    expect(back[5] == src[6] || back[5] == 0x0000);
}

static void test_FormatConversions_half_norm() {
    const uint16_t src[] = {
        0x3800,  //  0.5
        0x3c00,  //  1.0
        0xbc00,  // -1.0
        0x4000,  //  2.0
    };
    uint16_t dst[ARRAY_COUNT(src)];

    const skcms_AlphaFormat upm = skcms_AlphaFormat_Unpremul;

    // No-op, no clamp, should preserve all values.
    expect(skcms_Transform(&src, skcms_PixelFormat_RGBA_hhhh, upm, NULL,
                           &dst, skcms_PixelFormat_RGBA_hhhh, upm, NULL, 1));
    expect(dst[0] == src[0]);
    expect(dst[1] == src[1]);
    expect(dst[2] == src[2]);
    expect(dst[3] == src[3]);

    // Clamp on read.
    expect(skcms_Transform(&src, skcms_PixelFormat_RGBA_hhhh_Norm, upm, NULL,
                           &dst, skcms_PixelFormat_RGBA_hhhh     , upm, NULL, 1));
    expect(dst[0] == src[0]);
    expect(dst[1] == src[1]);
    expect(dst[2] == 0x0000);
    expect(dst[3] == src[1]);

    // Clamp on write.
    expect(skcms_Transform(&src, skcms_PixelFormat_RGBA_hhhh     , upm, NULL,
                           &dst, skcms_PixelFormat_RGBA_hhhh_Norm, upm, NULL, 1));
    expect(dst[0] == src[0]);
    expect(dst[1] == src[1]);
    expect(dst[2] == 0x0000);
    expect(dst[3] == src[1]);
}

static void test_FormatConversions_float() {
    float src[] = { 1.0f, 0.5f, 1/255.0f, 1/512.0f };

    uint32_t dst;
    expect(skcms_Transform(&src, skcms_PixelFormat_RGBA_ffff, skcms_AlphaFormat_Unpremul, NULL,
                           &dst, skcms_PixelFormat_RGBA_8888, skcms_AlphaFormat_Unpremul, NULL,
                           1));
    expect(dst == 0x000180ff);

    // Same as above, but we'll ignore the 1/512 alpha and fill in 1.0.
    expect(skcms_Transform(&src, skcms_PixelFormat_RGB_fff  , skcms_AlphaFormat_Unpremul, NULL,
                           &dst, skcms_PixelFormat_RGBA_8888, skcms_AlphaFormat_Unpremul, NULL,
                           1));
    expect(dst == 0xff0180ff);

    // Let's make sure each byte converts to the float we expect.
    uint32_t bytes[64];
    float   fdst[4*64];
    for (int i = 0; i < 64; i++) {
        bytes[i] = 0x03020100 + 0x04040404 * (uint32_t)i;
    }
    expect(skcms_Transform(&bytes, skcms_PixelFormat_RGBA_8888, skcms_AlphaFormat_Unpremul, NULL,
                            &fdst, skcms_PixelFormat_RGBA_ffff, skcms_AlphaFormat_Unpremul, NULL,
                           64));
    for (int i = 0; i < 256; i++) {
        expect_close(fdst[i], (float)i*(1/255.0f));
        if (i == 0 || i == 255) {
            expect(fdst[i] == (float)i*(1/255.0f));
        }
    }

    float ffff[16] = { 0,1,2,3, 4,5,6,7, 8,9,10,11, 12,13,14,15 };
    float  fff[12] = { 0,0,0, 0,0,0, 0,0,0, 0,0,0};
    expect(skcms_Transform(ffff, skcms_PixelFormat_RGBA_ffff, skcms_AlphaFormat_Unpremul, NULL,
                           fff , skcms_PixelFormat_RGB_fff  , skcms_AlphaFormat_Unpremul, NULL,
                           1));
    expect(fff[0] == 0); expect(fff[1] == 1); expect(fff[2] == 2);

    expect(skcms_Transform(ffff, skcms_PixelFormat_RGBA_ffff, skcms_AlphaFormat_Unpremul, NULL,
                           fff , skcms_PixelFormat_RGB_fff  , skcms_AlphaFormat_Unpremul, NULL,
                           4));
    expect(fff[0] ==  0); expect(fff[ 1] ==  1); expect(fff[ 2] ==  2);
    expect(fff[3] ==  4); expect(fff[ 4] ==  5); expect(fff[ 5] ==  6);
    expect(fff[6] ==  8); expect(fff[ 7] ==  9); expect(fff[ 8] == 10);
    expect(fff[9] == 12); expect(fff[10] == 13); expect(fff[11] == 14);
}

static const char* profile_test_cases[] = {
    // iccMAX profiles that we can't parse at all
    "profiles/color.org/sRGB_D65_colorimetric.icc",
    "profiles/color.org/sRGB_D65_MAT.icc",
    "profiles/color.org/sRGB_ISO22028.icc",

    // V2 or V4 profiles that only include A2B/B2A tags (no TRC or XYZ)
    "profiles/color.org/sRGB_ICC_v4_Appearance.icc",
    "profiles/color.org/sRGB_v4_ICC_preference.icc",
    "profiles/color.org/Upper_Left.icc",
    "profiles/color.org/Upper_Right.icc",
    "profiles/misc/Apple_Wide_Color.icc",
    "profiles/misc/Coated_FOGRA27_CMYK.icc",
    "profiles/misc/Coated_FOGRA39_CMYK.icc",
    "profiles/misc/ColorLogic_ISO_Coated_CMYK.icc",  // Has kTRC.
    "profiles/misc/Japan_Color_2001_Coated.icc",
    "profiles/misc/Lexmark_X110.icc",
    "profiles/misc/MartiMaria_browsertest_A2B.icc",
    "profiles/misc/PrintOpen_ISO_Coated_CMYK.icc",   // Has kTRC.
    "profiles/misc/sRGB_ICC_v4_beta.icc",
    "profiles/misc/SWOP_Coated_20_GCR_CMYK.icc",
    "profiles/misc/US_Web_Coated_SWOP_CMYK.icc",
    "profiles/misc/XRite_GRACol7_340_CMYK.icc",

    // V2 monochrome output profiles that include kTRC but no A2B
    "profiles/misc/Dot_Gain_20_Grayscale.icc",  // kTRC table
    "profiles/misc/Gray_Gamma_22.icc",          // kTRC gamma

    // V4 profiles with parametric TRC curves and XYZ
    "profiles/mobile/Display_P3_parametric.icc",
    "profiles/mobile/sRGB_parametric.icc",
    "profiles/mobile/iPhone7p.icc",
    "profiles/misc/sRGB_lcms.icc",

    // V4 profiles with LUT TRC curves and XYZ
    "profiles/mobile/Display_P3_LUT.icc",
    "profiles/mobile/sRGB_LUT.icc",

    // V2 profiles with gamma TRC and XYZ
    "profiles/color.org/Lower_Left.icc",
    "profiles/color.org/Lower_Right.icc",
    "profiles/misc/AdobeRGB.icc",
    "profiles/misc/AdobeColorSpin.icc",
    "profiles/misc/Color_Spin_Gamma_18.icc",
    "profiles/misc/Generic_RGB_Gamma_18.icc",

    // V2 profiles with LUT TRC and XYZ
    "profiles/color.org/sRGB2014.icc",
    "profiles/sRGB_Facebook.icc",
    "profiles/misc/Apple_Color_LCD.icc",
    "profiles/misc/HD_709.icc",
    "profiles/misc/sRGB_black_scaled.icc",
    "profiles/misc/sRGB_HP.icc",
    "profiles/misc/sRGB_HP_2.icc",

    // Calibrated monitor profile with identical sRGB-ish tables.
    "profiles/misc/sRGB_Calibrated_Homogeneous.icc",

    // Calibrated monitor profile with slightly different sRGB-like tables for each channel.
    "profiles/misc/sRGB_Calibrated_Heterogeneous.icc",

    // Calibrated monitor profile with non-monotonic TRC tables. We approximate, but badly.
    "profiles/misc/DisplayCal_ASUS_NonMonotonic.icc",

    // Hard test profile. Non-invertible XYZ, three separate tables that fail to approximate
    "profiles/misc/MartiMaria_browsertest_HARD.icc",

    // Camera profile with three separate tables that fail to approximate
    "profiles/misc/Phase_One_P25.icc",

    // Profile claims to be sRGB, but seems quite different
    "profiles/misc/Kodak_sRGB.icc",

    // Bad profiles found inn the wild
    "profiles/misc/ColorGATE_Sihl_PhotoPaper.icc",  // Broken tag table, and A2B0 fails to parse
    "profiles/misc/bad_pcs.icc",                    // PCS is 'RGB '

    // Unsure what the bug here is, chromium:875650.
    "profiles/misc/ThinkpadX1YogaV2.icc",
    "profiles/misc/XPS13_9360.icc",

    // Calibrated profile where A2B/B2A and XYZ+TRC produce very different gamut mappings.
    // User was (rightly) confused & convinced that profile was being ignored.
    "profiles/misc/Calibrated_A2B_XYZ_Mismatch.icc",  // chromium:1055154

    // HDR profiles that include the new 'cicp' tag (from ICC 4.4.0)
    "profiles/misc/P3_PQ_cicp.icc",
    "profiles/misc/Rec2020_HLG_cicp.icc",
    "profiles/misc/Rec2020_PQ_cicp.icc",

    // fuzzer generated profiles that found parsing bugs

    // Bad tag table data - these should not parse
    "profiles/fuzz/last_tag_too_small.icc",   // skia:7592
    "profiles/fuzz/named_tag_too_small.icc",  // skia:7592

    // Bad tag data - these should not parse
    "profiles/fuzz/curv_size_overflow.icc",           // skia:7593
    "profiles/fuzz/truncated_curv_tag.icc",           // oss-fuzz:6103
    "profiles/fuzz/zero_a.icc",                       // oss-fuzz:????
    "profiles/fuzz/a2b_too_many_input_channels.icc",  // oss-fuzz:6521
    "profiles/fuzz/a2b_too_many_input_channels2.icc", // oss-fuzz:32765
    "profiles/fuzz/mangled_trc_tags.icc",             // chromium:835666
    "profiles/fuzz/negative_g_para.icc",              // chromium:836634
    "profiles/fuzz/b2a_too_few_output_channels.icc",  // oss-fuzz:33281

    // A B2A profile with no CLUT.
    "profiles/fuzz/b2a_no_clut.icc",  // oss-fuzz:33396

    // Caused skcms_PolyTF fit to round trip indices outside the range of int.
    "profiles/fuzz/infinite_roundtrip.icc",           // oss-fuzz:8101
    "profiles/fuzz/polytf_big_float_to_int_cast.icc", // oss-fuzz:8142

    // Caused skcms_ApproximateCurve to violate the a*d+b >= 0 constraint.
    "profiles/fuzz/inverse_tf_adb_negative.icc",      // oss-fuzz:8130

    // Caused skcms_PolyTF fit to send P to NaN due to very large inverse lhs
    "profiles/fuzz/polytf_nan_after_update.icc",      // oss-fuzz:8165

    // Table is approximated by an inverse TF whose inverse is not invertible.
    "profiles/fuzz/inverse_tf_not_invertible.icc",    // chromium:841210

    // Table is approximated by a TF whose inverse has g > 16M (timeout in approx_pow)
    "profiles/fuzz/inverse_tf_huge_g.icc",            // chromium:842374

    // mAB has a CLUT with 1 input channel
    "profiles/fuzz/one_d_clut.icc",                   // chromium:874433

    // Non-D50 profiles.
    "profiles/misc/SM245B.icc",
    "profiles/misc/BenQ_GL2450.icc",

    // This profile is fine, but has really small TRC tables (5 points).
    "profiles/misc/BenQ_RL2455.icc",                 // chromium:869115

    // This calibrated profile has a non-zero black.
    "profiles/misc/calibrated_nonzero_black.icc",

    // A zero g term causes a divide by zero when inverting.
    "profiles/fuzz/zero_g.icc",                       // oss-fuzz:12430

    // Reasonable table, but gets approximated very badly
    "profiles/misc/crbug_976551.icc",                 // chromium:976551

    // The a term goes negative when inverting.
    "profiles/fuzz/negative_a_when_inverted.icc",     // oss-fuzz:16581

    // a + b is negative when inverting, because d>0
    "profiles/fuzz/negative_a_plus_b.icc",            // oss-fuzz:16584

    "profiles/fuzz/nan_s.icc",                        // oss-fuzz:16674
    "profiles/fuzz/inf_a.icc",                        // oss-fuzz:16675

    "profiles/fuzz/fit_pq.icc",                       // oss-fuzz:18249

    // Reasonable table, bad approximation (converges very slowly)
    "profiles/misc/MR2416GSDF.icc",                   // chromium:869115

    // Three different tables w/shoulders, bad approximation (slow convergence)
    "profiles/misc/crbug_1017960_19.icc",             // chromium:1017960

    "profiles/fuzz/direct_fit_not_invertible.icc",    // oss-fuzz:19341
    "profiles/fuzz/direct_fit_negative_a.icc",        // oss-fuzz:19467

    // g = 1027 -> -nan from exp2f_, sign-strip doesn't work, leading to powf_ assert
    "profiles/fuzz/large_g.icc",                      // chromium:996795
};

static void test_Parse(bool regen) {
    for (int i = 0; i < ARRAY_COUNT(profile_test_cases); ++i) {
        const char* filename = profile_test_cases[i];

        void* buf = NULL;
        size_t len = 0;
        expect(load_file(filename, &buf, &len));
        skcms_ICCProfile profile;
        bool parsed = skcms_Parse(buf, len, &profile);

        FILE* dump = tmpfile();
        expect(dump);

        if (parsed) {
            dump_profile(&profile, dump);
        } else {
            fprintf(dump, "Unable to parse ICC profile\n");
        }

        // MakeUsable functions should leave input unchanged when returning false
        skcms_ICCProfile as_dst = profile;
        if (!skcms_MakeUsableAsDestination(&as_dst)) {
            expect(memcmp(&as_dst, &profile, sizeof(profile)) == 0);
        }

        as_dst = profile;
        if (!skcms_MakeUsableAsDestinationWithSingleCurve(&as_dst)) {
            expect(memcmp(&as_dst, &profile, sizeof(profile)) == 0);
        }

        void* dump_buf = NULL;
        size_t dump_len = 0;
        expect(load_file_fp(dump, &dump_buf, &dump_len));
        fclose(dump);

        char ref_filename[256];
        if (snprintf(ref_filename, sizeof(ref_filename), "%s.txt", filename) < 0) {
            expect(false);
        }

        if (regen) {
            // Just write out new test data if in regen mode
            expect(write_file(ref_filename, dump_buf, dump_len));
        } else {
            // Read in existing test data
            void* ref_buf = NULL;
            size_t ref_len = 0;
            expect(load_file(ref_filename, &ref_buf, &ref_len));

            if (dump_len != ref_len || memcmp(dump_buf, ref_buf, dump_len) != 0) {
                const char* cur = dump_buf;
                const char* ref =  ref_buf;
                while (*cur == *ref) { cur++; ref++; }
                size_t off = (size_t)(cur - (const char*)dump_buf);
                // Write out the new data on a mismatch
                fprintf(stderr, "Parse mismatch for %s:\n", filename);
                fwrite(dump_buf, 1, dump_len, stderr);
                fprintf(stderr, "\n");

                fprintf(stderr, "Mismatch begins at offset %zu, expected '%c', got,\n", off, *ref);
                fwrite(cur, 1, dump_len - off, stderr);
                fprintf(stderr, "\n");

                expect(false);
            }
            free(ref_buf);
        }

        free(buf);
        free(dump_buf);
    }
}

static void test_ApproximateCurve_clamped() {
    // These data represent a transfer function that is clamped at the high
    // end of its domain. It comes from the color profile attached to
    // https://crbug.com/750459
    float t[256] = {
        0.000000f, 0.000305f, 0.000610f, 0.000916f, 0.001221f, 0.001511f,
        0.001816f, 0.002121f, 0.002426f, 0.002731f, 0.003037f, 0.003601f,
        0.003937f, 0.004303f, 0.004685f, 0.005081f, 0.005509f, 0.005951f,
        0.006409f, 0.006882f, 0.007385f, 0.007904f, 0.008438f, 0.009003f,
        0.009583f, 0.010193f, 0.010819f, 0.011460f, 0.012131f, 0.012818f,
        0.013535f, 0.014267f, 0.015030f, 0.015808f, 0.016617f, 0.017456f,
        0.018296f, 0.019181f, 0.020081f, 0.021012f, 0.021958f, 0.022934f,
        0.023926f, 0.024949f, 0.026001f, 0.027070f, 0.028168f, 0.029297f,
        0.030442f, 0.031617f, 0.032822f, 0.034058f, 0.035309f, 0.036591f,
        0.037903f, 0.039231f, 0.040604f, 0.041993f, 0.043412f, 0.044846f,
        0.046326f, 0.047822f, 0.049348f, 0.050904f, 0.052491f, 0.054108f,
        0.055756f, 0.057420f, 0.059113f, 0.060853f, 0.062608f, 0.064393f,
        0.066209f, 0.068055f, 0.069932f, 0.071839f, 0.073762f, 0.075731f,
        0.077729f, 0.079759f, 0.081804f, 0.083894f, 0.086015f, 0.088167f,
        0.090333f, 0.092546f, 0.094789f, 0.097063f, 0.099367f, 0.101701f,
        0.104067f, 0.106477f, 0.108904f, 0.111360f, 0.113863f, 0.116381f,
        0.118944f, 0.121538f, 0.124163f, 0.126818f, 0.129519f, 0.132235f,
        0.134997f, 0.137789f, 0.140612f, 0.143465f, 0.146365f, 0.149279f,
        0.152239f, 0.155230f, 0.158267f, 0.161318f, 0.164416f, 0.167544f,
        0.170718f, 0.173907f, 0.177142f, 0.180407f, 0.183719f, 0.187045f,
        0.190433f, 0.193835f, 0.197284f, 0.200763f, 0.204273f, 0.207813f,
        0.211398f, 0.215030f, 0.218692f, 0.222385f, 0.226108f, 0.229877f,
        0.233677f, 0.237522f, 0.241382f, 0.245304f, 0.249256f, 0.253239f,
        0.257252f, 0.261311f, 0.265415f, 0.269551f, 0.273716f, 0.277928f,
        0.282170f, 0.286458f, 0.290776f, 0.295140f, 0.299535f, 0.303975f,
        0.308446f, 0.312947f, 0.317494f, 0.322087f, 0.326711f, 0.331380f,
        0.336080f, 0.340826f, 0.345602f, 0.350423f, 0.355291f, 0.360174f,
        0.365118f, 0.370092f, 0.375113f, 0.380163f, 0.385260f, 0.390387f,
        0.395560f, 0.400778f, 0.406027f, 0.411322f, 0.416663f, 0.422034f,
        0.427451f, 0.432898f, 0.438392f, 0.443931f, 0.449500f, 0.455116f,
        0.460777f, 0.466468f, 0.472221f, 0.477989f, 0.483818f, 0.489677f,
        0.495583f, 0.501518f, 0.507500f, 0.513527f, 0.519600f, 0.525719f,
        0.531868f, 0.538064f, 0.544289f, 0.550576f, 0.556893f, 0.563256f,
        0.569650f, 0.576104f, 0.582589f, 0.589120f, 0.595697f, 0.602304f,
        0.608972f, 0.615671f, 0.622415f, 0.629206f, 0.636027f, 0.642908f,
        0.649821f, 0.656779f, 0.663783f, 0.670832f, 0.677913f, 0.685054f,
        0.692226f, 0.699443f, 0.706706f, 0.714015f, 0.721370f, 0.728771f,
        0.736202f, 0.743694f, 0.751217f, 0.758785f, 0.766400f, 0.774060f,
        0.781765f, 0.789517f, 0.797314f, 0.805158f, 0.813031f, 0.820966f,
        0.828946f, 0.836957f, 0.845029f, 0.853132f, 0.861280f, 0.869490f,
        0.877729f, 0.886015f, 0.894362f, 0.902739f, 0.911162f, 0.919631f,
        0.928161f, 0.936721f, 0.945327f, 0.953994f, 0.962692f, 0.971435f,
        0.980240f, 0.989075f, 0.997955f, 1.000000f,
    };

    uint8_t table_8[ARRAY_COUNT(t)];
    for (int i = 0; i < ARRAY_COUNT(t); i++) {
        table_8[i] = (uint8_t)(t[i] * 255.0f + 0.5f);
    }

    skcms_Curve curve;
    curve.table_entries = (uint32_t)ARRAY_COUNT(t);
    curve.table_8       = table_8;

    skcms_TransferFunction tf;
    float max_error;
    expect(skcms_ApproximateCurve(&curve, &tf, &max_error));

    // The approximation isn't very good.
    expect(max_error < 1 / 40.0f);
}

static void expect_eq_Matrix3x3(skcms_Matrix3x3 a, skcms_Matrix3x3 b) {
    for (int r = 0; r < 3; r++)
    for (int c = 0; c < 3; c++) {
        expect(a.vals[r][c] == b.vals[r][c]);
    }
}

static void test_Matrix3x3_invert() {
    skcms_Matrix3x3 inv;

    skcms_Matrix3x3 I = {{
        { 1.0f, 0.0f, 0.0f },
        { 0.0f, 1.0f, 0.0f },
        { 0.0f, 0.0f, 1.0f },
    }};
    inv = (skcms_Matrix3x3){{ {0,0,0}, {0,0,0}, {0,0,0} }};
    expect(skcms_Matrix3x3_invert(&I, &inv));
    expect_eq_Matrix3x3(inv, I);

    skcms_Matrix3x3 T = {{
        { 1.0f, 0.0f, 3.0f },
        { 0.0f, 1.0f, 4.0f },
        { 0.0f, 0.0f, 1.0f },
    }};
    inv = (skcms_Matrix3x3){{ {0,0,0}, {0,0,0}, {0,0,0} }};
    expect(skcms_Matrix3x3_invert(&T, &inv));
    expect_eq_Matrix3x3(inv, (skcms_Matrix3x3){{
        { 1.0f, 0.0f, -3.0f },
        { 0.0f, 1.0f, -4.0f },
        { 0.0f, 0.0f,  1.0f },
    }});

    skcms_Matrix3x3 S = {{
        { 2.0f, 0.0f, 0.0f },
        { 0.0f, 4.0f, 0.0f },
        { 0.0f, 0.0f, 8.0f },
    }};
    inv = (skcms_Matrix3x3){{ {0,0,0}, {0,0,0}, {0,0,0} }};
    expect(skcms_Matrix3x3_invert(&S, &inv));
    expect_eq_Matrix3x3(inv, (skcms_Matrix3x3){{
        { 0.500f, 0.000f,  0.000f },
        { 0.000f, 0.250f,  0.000f },
        { 0.000f, 0.000f,  0.125f },
    }});
}

static void test_SimpleRoundTrip() {
    // We'll test that parametric sRGB roundtrips with itself, bytes -> bytes.
    void*  srgb_ptr;
    size_t srgb_len;
    expect(load_file("profiles/mobile/sRGB_parametric.icc", &srgb_ptr, &srgb_len));

    skcms_ICCProfile srgbA, srgbB;
    expect(skcms_Parse(srgb_ptr, srgb_len, &srgbA));
    expect(skcms_Parse(srgb_ptr, srgb_len, &srgbB));

    uint8_t src[256],
            dst[256];
    for (int i = 0; i < 256; i++) {
        src[i] = (uint8_t)i;
    }

    expect(skcms_Transform(src, skcms_PixelFormat_RGBA_8888, skcms_AlphaFormat_Unpremul, &srgbB,
                           dst, skcms_PixelFormat_RGBA_8888, skcms_AlphaFormat_Unpremul, &srgbA,
                           64));
    for (int i = 0; i < 256; i++) {
        expect(dst[i] == (uint8_t)i);
    }

    free(srgb_ptr);
}

// Floats should hold enough precision that we can round trip any two non-degenerate profiles.
static void expect_round_trip_through_floats(const skcms_ICCProfile* A,
                                             const skcms_ICCProfile* B) {
    uint8_t bytes[256];
    float  floats[256];
    for (int i = 0; i < 256; i++) {
        bytes[i] = (uint8_t)i;
    }

    expect(skcms_Transform(bytes , skcms_PixelFormat_RGBA_8888, skcms_AlphaFormat_Unpremul, B,
                           floats, skcms_PixelFormat_RGBA_ffff, skcms_AlphaFormat_Unpremul, A,
                           64));
    for (int i = 0; i < 256; i++) {
        bytes[i] = 0;
    }
    expect(skcms_Transform(floats, skcms_PixelFormat_RGBA_ffff, skcms_AlphaFormat_Unpremul, A,
                           bytes , skcms_PixelFormat_RGBA_8888, skcms_AlphaFormat_Unpremul, B,
                           64));

    for (int i = 0; i < 256; i++) {
        expect(bytes[i] == (uint8_t)i);
    }
}

static void test_FloatRoundTrips() {
    void*  srgb_ptr;
    size_t srgb_len;
    expect(load_file("profiles/mobile/sRGB_parametric.icc", &srgb_ptr, &srgb_len));


    void*  dp3_ptr;
    size_t dp3_len;
    expect(load_file("profiles/mobile/Display_P3_parametric.icc", &dp3_ptr, &dp3_len));

    void*  ll_ptr;
    size_t ll_len;
    expect(load_file("profiles/color.org/Lower_Left.icc", &ll_ptr, &ll_len));

    void*  lr_ptr;
    size_t lr_len;
    expect(load_file("profiles/color.org/Lower_Right.icc", &lr_ptr, &lr_len));

    skcms_ICCProfile srgb, dp3, ll, lr;
    expect(skcms_Parse(srgb_ptr, srgb_len, &srgb));
    expect(skcms_Parse( dp3_ptr,  dp3_len, &dp3 ));
    expect(skcms_Parse(  ll_ptr,   ll_len, &ll  ));
    expect(skcms_Parse(  lr_ptr,   lr_len, &lr  ));


    const skcms_ICCProfile* profiles[] = { &srgb, &dp3, &ll, &lr };
    for (int i = 0; i < ARRAY_COUNT(profiles); i++)
    for (int j = 0; j < ARRAY_COUNT(profiles); j++) {
        expect_round_trip_through_floats(profiles[i], profiles[j]);
    }

    free(srgb_ptr);
    free( dp3_ptr);
    free(  ll_ptr);
    free(  lr_ptr);
}

static void test_sRGB_AllBytes() {
    // Test that our transfer function implementation is perfect to at least 8-bit precision.

    void* ptr;
    size_t len;
    skcms_ICCProfile sRGB;
    expect( load_file("profiles/mobile/sRGB_parametric.icc", &ptr, &len) );
    expect( skcms_Parse(ptr, len, &sRGB) );

    skcms_ICCProfile linear_sRGB = sRGB;
    skcms_TransferFunction linearTF = { 1,1,0,0,0,0,0 };
    skcms_SetTransferFunction(&linear_sRGB, &linearTF);

    // Enough to hit all distinct bytes when interpreted as RGB 888.
    uint8_t src[258],
            dst[258];
    for (int i = 0; i < 258; i++) {
        src[i] = (uint8_t)(i & 0xFF);  // (We don't really care about bytes 256 and 257.)
    }

    expect( skcms_Transform(src, skcms_PixelFormat_RGB_888, skcms_AlphaFormat_Unpremul, &sRGB,
                            dst, skcms_PixelFormat_RGB_888, skcms_AlphaFormat_Unpremul, &linear_sRGB,
                            258/3) );

    for (int i = 0; i < 256; i++) {
        float linear = skcms_TransferFunction_eval(&sRGB.trc[0].parametric, (float)i * (1/255.0f));
        uint8_t expected = (uint8_t)(linear * 255.0f + 0.5f);

        if (dst[i] != expected) {
            fprintf(stderr, "%d -> %u, want %u\n", i, dst[i], expected);
        }

        expect(dst[i] == expected);
    }

    free(ptr);
}

static void test_TRC_Table16() {
    // We'll convert from FB (table-based sRGB) to sRGB (parametric sRGB).
    skcms_ICCProfile FB, sRGB;

    void  *FB_ptr, *sRGB_ptr;
    size_t FB_len,  sRGB_len;
    expect( load_file("profiles/sRGB_Facebook.icc"         , &  FB_ptr, &  FB_len) );
    expect( load_file("profiles/mobile/sRGB_parametric.icc", &sRGB_ptr, &sRGB_len) );
    expect( skcms_Parse(  FB_ptr,   FB_len, &  FB) );
    expect( skcms_Parse(sRGB_ptr, sRGB_len, &sRGB) );

    // Enough to hit all distinct bytes when interpreted as RGB 888.
    uint8_t src[258],
            dst[258];
    for (int i = 0; i < 258; i++) {
        src[i] = (uint8_t)(i & 0xFF);  // (We don't really care about bytes 256 and 257.)
    }

    expect( skcms_Transform(src, skcms_PixelFormat_RGB_888, skcms_AlphaFormat_Unpremul, &FB,
                            dst, skcms_PixelFormat_RGB_888, skcms_AlphaFormat_Unpremul, &sRGB,
                            258/3) );

    for (int i = 0; i < 256; i++) {
        expect( dst[i] == i );
    }

    free(  FB_ptr);
    free(sRGB_ptr);
}

static void test_Premul() {
    void* ptr;
    size_t len;
    skcms_ICCProfile sRGB;
    expect( load_file("profiles/mobile/sRGB_parametric.icc", &ptr, &len) );
    expect( skcms_Parse(ptr, len, &sRGB) );

    expect (sRGB.has_trc && sRGB.trc[0].table_entries == 0);

    const skcms_TransferFunction* tf = &sRGB.trc[0].parametric;
    skcms_TransferFunction inv;
    expect (skcms_TransferFunction_invert(tf, &inv));

    uint8_t src[256],
            dst[256] = {0};
    for (int i = 0; i < 256; i++) {
        src[i] = (uint8_t)i;
    }

    expect(skcms_Transform(
        src, skcms_PixelFormat_RGBA_8888, skcms_AlphaFormat_Unpremul       , &sRGB,
        dst, skcms_PixelFormat_RGBA_8888, skcms_AlphaFormat_PremulAsEncoded, &sRGB,
        64));
    for (int i = 0; i < 256; i+=4) {
        expect_close( dst[i+0], (uint8_t)( src[i+0] * (src[i+3]/255.0f) + 0.5f ) );
        expect_close( dst[i+1], (uint8_t)( src[i+1] * (src[i+3]/255.0f) + 0.5f ) );
        expect_close( dst[i+2], (uint8_t)( src[i+2] * (src[i+3]/255.0f) + 0.5f ) );
        expect      ( dst[i+3] == src[i+3] );
    }

    expect(skcms_Transform(
        src, skcms_PixelFormat_RGBA_8888, skcms_AlphaFormat_PremulAsEncoded, &sRGB,
        dst, skcms_PixelFormat_RGBA_8888, skcms_AlphaFormat_Unpremul       , &sRGB,
        64));
    for (int i = 0; i < 256; i+=4) {
        expect_close( dst[i+0], (uint8_t)( src[i+0] / (src[i+3]/255.0f) + 0.5f ) );
        expect_close( dst[i+1], (uint8_t)( src[i+1] / (src[i+3]/255.0f) + 0.5f ) );
        expect_close( dst[i+2], (uint8_t)( src[i+2] / (src[i+3]/255.0f) + 0.5f ) );
        expect      ( dst[i+3] == src[i+3] );
    }

    free(ptr);
}

static void test_ByteToLinearFloat() {
    uint32_t src[1] = { 0xFFFFFFFF };
    float dst[4];

    void*  srgb_ptr;
    size_t srgb_len;
    expect(load_file("profiles/mobile/sRGB_parametric.icc", &srgb_ptr, &srgb_len));

    skcms_ICCProfile srgb, srgb_linear;
    expect(skcms_Parse(srgb_ptr, srgb_len, &srgb));
    srgb_linear = srgb;
    for (int i = 0; i < 3; ++i) {
        srgb_linear.trc[i].parametric.g = 1.0f;
        srgb_linear.trc[i].parametric.a = 1.0f;
        srgb_linear.trc[i].parametric.b = 0.0f;
        srgb_linear.trc[i].parametric.c = 0.0f;
        srgb_linear.trc[i].parametric.d = 0.0f;
        srgb_linear.trc[i].parametric.e = 0.0f;
        srgb_linear.trc[i].parametric.f = 0.0f;
    }

    skcms_Transform(src, skcms_PixelFormat_BGRA_8888, skcms_AlphaFormat_Unpremul, &srgb,
                    dst, skcms_PixelFormat_RGBA_ffff, skcms_AlphaFormat_Unpremul, &srgb_linear, 1);

    expect(dst[0] == 1.0f);
    expect(dst[1] == 1.0f);
    expect(dst[2] == 1.0f);
    expect(dst[3] == 1.0f);

    free(srgb_ptr);
}

// This test is written with the expectation that we use A2B1, not A2B0.
#if 0
static void test_CLUT() {
    // Identity* transform from a v4 A2B profile to good old parametric sRGB.
    //   * Approximate identity, apparently?
    void  *srgb_ptr, *a2b_ptr;
    size_t srgb_len,  a2b_len;
    expect(load_file("profiles/mobile/sRGB_parametric.icc",           &srgb_ptr, &srgb_len));
    expect(load_file("profiles/color.org/sRGB_ICC_v4_Appearance.icc", & a2b_ptr, & a2b_len));

    skcms_ICCProfile srgb, a2b;
    expect( skcms_Parse(srgb_ptr, srgb_len, &srgb) );
    expect( skcms_Parse( a2b_ptr,  a2b_len, & a2b) );

    // We'll test some edge and middle RGB values.
    uint8_t src[] = {
        0x00, 0x00, 0x00,
        0x00, 0x00, 0x7f,
        0x00, 0x00, 0xff,
        0x00, 0x7f, 0x00,
        0x00, 0xff, 0x00,
        0x00, 0x7f, 0x7f,
        0x00, 0xff, 0xff,
        0x7f, 0x00, 0x00,
        0xff, 0x00, 0x00,
        0x7f, 0x00, 0x7f,
        0xff, 0x00, 0xff,
        0x7f, 0x7f, 0x00,
        0xff, 0xff, 0x00,
        0x7f, 0x7f, 0x7f,
        0xff, 0xff, 0xff,
    }, dst[ARRAY_COUNT(src)];

    expect(skcms_Transform(src, skcms_PixelFormat_RGB_888, skcms_AlphaFormat_Unpremul, &a2b,
                           dst, skcms_PixelFormat_RGB_888, skcms_AlphaFormat_Unpremul, &srgb,
                           ARRAY_COUNT(src)/3));

    for (int i = 0; i < ARRAY_COUNT(src); i++) {
        // We'd like these all to be perfect (tol = 0),
        // but that doesn't seem to be what the profile is telling us to do.
        int tol = 1;
        if (src[i] == 0) {
            tol = 9;
        }
        if (abs(dst[i] - src[i]) > tol) {
            printf("%d: %d vs %d\n", i, dst[i], src[i]);
        }
        expect(abs(dst[i] - src[i]) <= tol);
    }

    free(srgb_ptr);
    free(a2b_ptr);
}
#endif

static void test_MakeUsableAsDestination() {
    void*  ptr;
    size_t len;
    expect(load_file("profiles/mobile/sRGB_LUT.icc", &ptr, &len));

    skcms_ICCProfile profile;
    expect(skcms_Parse(ptr, len, &profile));

    uint32_t src = 0xffaaccee, dst;

    // We can't transform to table-based profiles (yet?).
    expect(!skcms_Transform(
                &src, skcms_PixelFormat_RGBA_8888, skcms_AlphaFormat_Unpremul, skcms_sRGB_profile(),
                &dst, skcms_PixelFormat_RGBA_8888, skcms_AlphaFormat_Unpremul, &profile,
                1));

    // We should be able to approximate this profile
    expect(skcms_MakeUsableAsDestination(&profile));

    // Now the transform should work.
    expect(skcms_Transform(
               &src, skcms_PixelFormat_RGBA_8888, skcms_AlphaFormat_Unpremul, skcms_sRGB_profile(),
               &dst, skcms_PixelFormat_RGBA_8888, skcms_AlphaFormat_Unpremul, &profile,
               1));

    // This should be pretty much an identity transform.
    expect(dst == 0xffaaccee);

    free(ptr);
}

static void test_MakeUsableAsDestinationAdobe() {
    void*  ptr;
    size_t len;
    expect(load_file("profiles/misc/AdobeRGB.icc", &ptr, &len));

    skcms_ICCProfile profile;
    expect(skcms_Parse(ptr, len, &profile));

    skcms_ICCProfile usable_as_dst = profile;
    expect(skcms_MakeUsableAsDestination(&usable_as_dst));

    // This profile was already parametric, so it should remain unchanged
    expect(memcmp(&usable_as_dst, &profile, sizeof(profile)) == 0);

    // Same sequence as above, using the more aggressive SingleCurve version.
    skcms_ICCProfile single_curve = profile;
    expect(skcms_MakeUsableAsDestinationWithSingleCurve(&single_curve));
    expect(memcmp(&single_curve, &profile, sizeof(profile)) == 0);

    free(ptr);
}

static void test_AdaptToD50() {
    skcms_Matrix3x3 xyz_to_xyzD50;
    float x_D65 = 0.3127f;
    float y_D65 = 0.3290f;
    expect(skcms_AdaptToXYZD50(x_D65, y_D65, &xyz_to_xyzD50));
    skcms_Matrix3x3 sRGB_D65 = {{
        { 0.4124564f, 0.3575761f, 0.1804375f },
        { 0.2126729f, 0.7151522f, 0.0721750f },
        { 0.0193339f, 0.1191920f, 0.9503041f }
    }};
    skcms_Matrix3x3 sRGB_D50 = skcms_Matrix3x3_concat(&xyz_to_xyzD50, &sRGB_D65);
    skcms_ICCProfile p = *skcms_sRGB_profile();
    for (int r = 0; r < 3; ++r)
        for (int c = 0; c < 3; ++c) {
            expect(fabsf_(sRGB_D50.vals[r][c] - p.toXYZD50.vals[r][c]) < 0.0001f);
        }
}

static void test_PrimariesToXYZ() {
    skcms_Matrix3x3 srgb_to_xyz;
    expect(skcms_PrimariesToXYZD50(0.64f, 0.33f,
                                   0.30f, 0.60f,
                                   0.15f, 0.06f,
                                   0.3127f, 0.3290f,
                                   &srgb_to_xyz));

    skcms_ICCProfile p = *skcms_sRGB_profile();
    for (int r = 0; r < 3; ++r)
        for (int c = 0; c < 3; ++c) {
            expect(fabsf_(srgb_to_xyz.vals[r][c] - p.toXYZD50.vals[r][c]) < 0.0001f);
        }
}

static void test_Programmatic_sRGB() {
    skcms_Matrix3x3 srgb_to_xyz;
    expect(skcms_PrimariesToXYZD50(0.64f, 0.33f,
                                   0.30f, 0.60f,
                                   0.15f, 0.06f,
                                   0.3127f, 0.3290f,
                                   &srgb_to_xyz));
    skcms_ICCProfile srgb = *skcms_sRGB_profile();

    skcms_ICCProfile p;
    skcms_Init(&p);
    skcms_SetTransferFunction(&p, &srgb.trc[0].parametric);
    skcms_SetXYZD50(&p, &srgb_to_xyz);

    expect(skcms_ApproximatelyEqualProfiles(&p, &srgb));
}

static void test_ExactlyEqual() {
    const skcms_ICCProfile* srgb = skcms_sRGB_profile();
    skcms_ICCProfile        copy = *srgb;

    expect(skcms_ApproximatelyEqualProfiles( srgb,  srgb));
    expect(skcms_ApproximatelyEqualProfiles( srgb, &copy));
    expect(skcms_ApproximatelyEqualProfiles(&copy,  srgb));
    expect(skcms_ApproximatelyEqualProfiles(&copy, &copy));

    // This should make a bitwise exact copy of sRGB.
    skcms_ICCProfile exact;
    skcms_Init(&exact);
    skcms_SetTransferFunction(&exact, &srgb->trc[0].parametric);
    skcms_SetXYZD50(&exact, &srgb->toXYZD50);
    expect(0 == memcmp(&exact, srgb, sizeof(skcms_ICCProfile)));
}

static void test_GrayscaleAndRGBCanBeEqual() {
    const skcms_ICCProfile* srgb = skcms_sRGB_profile();
    skcms_ICCProfile        gray = *srgb;
    gray.data_color_space = skcms_Signature_Gray;

    expect(skcms_ApproximatelyEqualProfiles(srgb, &gray));
    expect(skcms_ApproximatelyEqualProfiles(&gray, srgb));
}

static void test_Clamp() {
    // Test that we clamp out-of-gamut values when converting to fixed point,
    // not just to byte value range but also to gamut (for compatibility with
    // older systems).

    void*  dp3_ptr;
    size_t dp3_len;
    expect(load_file("profiles/mobile/Display_P3_parametric.icc", &dp3_ptr, &dp3_len));

    // Here's the basic premise of the test: sRGB can't represent P3's full green,
    // but if we scale it by 50% alpha, it would "fit" in a byte.  We want to avoid that.
    skcms_ICCProfile src,
                     dst = *skcms_sRGB_profile();
    skcms_Parse(dp3_ptr, dp3_len, &src);
    uint8_t rgba[] = { 0, 255, 0, 127 };

    // First double check that the green channel is out of gamut by transforming to float.
    float flts[4];
    skcms_Transform(rgba, skcms_PixelFormat_RGBA_8888, skcms_AlphaFormat_Unpremul, &src,
                    flts, skcms_PixelFormat_RGBA_ffff, skcms_AlphaFormat_Unpremul, &dst,
                    1);
    expect(flts[0] < 0);   // A typical out-of-gamut green.  r,b are negative, and g > 1.
    expect(flts[1] > 1);
    expect(flts[2] < 0);
    expect_close(flts[3], 127*(1/255.0f));

    // Now the real test, making sure we clamp that green channel to 1.0 before premul.
    skcms_Transform(rgba, skcms_PixelFormat_RGBA_8888, skcms_AlphaFormat_Unpremul       , &src,
                    rgba, skcms_PixelFormat_RGBA_8888, skcms_AlphaFormat_PremulAsEncoded, &dst,
                    1);

    expect(rgba[0] ==   0);
    expect(rgba[1] == 127);  // would be 129 if we clamped after premul
    expect(rgba[2] ==   0);
    expect(rgba[3] == 127);


    free(dp3_ptr);
}

static void test_AliasedTransforms() {
    // We should be able to skcms_Transform() in place if the source and destination
    // buffers are perfectly aligned and the pixel formats are the same size.

    uint64_t buf = 0;
    skcms_AlphaFormat upm = skcms_AlphaFormat_Unpremul;
    const skcms_ICCProfile *srgb = skcms_sRGB_profile(),
                           *xyz  = skcms_XYZD50_profile();

    expect( skcms_Transform(&buf, skcms_PixelFormat_A_8, upm, srgb,
                            &buf, skcms_PixelFormat_G_8, upm, xyz, 1) );

    expect( skcms_Transform(&buf, skcms_PixelFormat_RGB_565  , upm, srgb,
                            &buf, skcms_PixelFormat_ABGR_4444, upm, xyz, 1) );

    expect( skcms_Transform(&buf, skcms_PixelFormat_RGBA_8888   , upm, srgb,
                            &buf, skcms_PixelFormat_RGBA_1010102, upm, xyz, 1) );

    expect( skcms_Transform(&buf, skcms_PixelFormat_RGB_161616BE, upm, srgb,
                            &buf, skcms_PixelFormat_BGR_hhh     , upm, xyz, 1) );

    expect( skcms_Transform(&buf, skcms_PixelFormat_RGB_161616LE, upm, srgb,
                            &buf, skcms_PixelFormat_BGR_161616BE, upm, xyz, 1) );
}

static void test_Palette8() {
    uint32_t palette[256];
    for (int i = 0; i < 256; i++) {
        palette[i] = (uint32_t)(255 - i) * 0x01010101;
    }

    uint8_t  src[512];
    uint32_t dst[512];
    for (int i = 0; i < 512; i++) {
        src[i] = (uint8_t)(i % 256);
    }

    const skcms_ICCProfile* srgb = skcms_sRGB_profile();
    const skcms_AlphaFormat upm = skcms_AlphaFormat_Unpremul;

    expect( skcms_TransformWithPalette(src, skcms_PixelFormat_RGBA_8888_Palette8, upm, srgb,
                                       dst, skcms_PixelFormat_RGBA_8888         , upm, srgb,
                                       512, palette) );

    for (int i = 0; i < 512; i++) {
        uint32_t expected = (uint32_t)(255 - i%256) * 0x01010101;
        expect( dst[i] == expected );
    }


    // Double check we can't transform skcms_PixelFormat_RGBA_8888_Palette8 without a palette.
    expect( !skcms_Transform(src, skcms_PixelFormat_RGBA_8888_Palette8, upm, srgb,
                             dst, skcms_PixelFormat_RGBA_8888         , upm, srgb,
                             512) );
    expect( !skcms_TransformWithPalette(src, skcms_PixelFormat_RGBA_8888_Palette8, upm, srgb,
                                        dst, skcms_PixelFormat_RGBA_8888         , upm, srgb,
                                        512, NULL) );
}

static void test_TF_invert() {
    const skcms_TransferFunction *sRGB = skcms_sRGB_TransferFunction(),
                                 *inv  = skcms_sRGB_Inverse_TransferFunction();
    expect(1.0f == skcms_TransferFunction_eval(sRGB, 1.0f));
    expect(1.0f == skcms_TransferFunction_eval( inv, 1.0f));

    skcms_TransferFunction sRGB2, inv2;
    expect(skcms_TransferFunction_invert( inv, &sRGB2));
    expect(skcms_TransferFunction_invert(sRGB, & inv2));

    expect(1.0f == skcms_TransferFunction_eval(&sRGB2, 1.0f));
    expect(1.0f == skcms_TransferFunction_eval(& inv2, 1.0f));

    expect(0 == memcmp( inv, & inv2, sizeof(skcms_TransferFunction)));
  //expect(0 == memcmp(sRGB, &sRGB2, sizeof(skcms_TransferFunction)));
}

static void test_PQ() {
    {
        // This PQ function maps [0,1] to [0,1].
        skcms_TransferFunction pq;
        expect(skcms_TransferFunction_makePQ(&pq));

        expect(0.0000f == skcms_TransferFunction_eval(&pq, 0.0f));
        expect(1.0000f == skcms_TransferFunction_eval(&pq, 1.0f));

        // 100 nits is around 0.508.
        expect(0.0099f < skcms_TransferFunction_eval(&pq, 0.508f));
        expect(0.0101f > skcms_TransferFunction_eval(&pq, 0.508f));

        // Try again with skcms_transform().
        float rgb[] = {0.0f,1.0f,0.508f};
        skcms_ICCProfile src = *skcms_XYZD50_profile(),
                         dst = *skcms_XYZD50_profile();
        skcms_SetTransferFunction(&src, &pq);

        expect(skcms_Transform(rgb, skcms_PixelFormat_RGB_fff,skcms_AlphaFormat_Unpremul, &src,
                               rgb, skcms_PixelFormat_RGB_fff,skcms_AlphaFormat_Unpremul, &dst, 1));
        expect(rgb[0] == 0.0f);
        expect(rgb[1] == 1.0f);
        expect(0.0099f < rgb[2] && rgb[2] < 0.0101f);

        // And back.
        expect(skcms_Transform(rgb, skcms_PixelFormat_RGB_fff,skcms_AlphaFormat_Unpremul, &dst,
                               rgb, skcms_PixelFormat_RGB_fff,skcms_AlphaFormat_Unpremul, &src, 1));
        expect(0 < rgb[0] && rgb[0] < 1e-6);  // TODO: can we get this perfect?
        expect(rgb[1] == 1.0f);
        expect(0.507f < rgb[2] && rgb[2] < 0.508f);
    }

    {
        // Let's see if we can get absolute 0-10000 nits.
        skcms_TransferFunction pq_abs;

        // Mathematically to get 10000 on the output, we want to
        // scale the A and B PQ terms by R = 10000 ^ (1/F).
        float R = powf_(10000.0f, 1305/8192.0f);   // ~= 4.33691
        expect(skcms_TransferFunction_makePQish(&pq_abs,
                    R*(-107/128.0f), R*       1.0f,   32/2523.0f,
                       2413/128.0f,   -2392/128.0f, 8192/1305.0f));

        // That gets us close.
        expect(0.0f == skcms_TransferFunction_eval(&pq_abs, 0.0f));
        expect(   99.8f < skcms_TransferFunction_eval(&pq_abs, 0.508f));
        expect(  100.0f > skcms_TransferFunction_eval(&pq_abs, 0.508f));
        expect( 9989.0f < skcms_TransferFunction_eval(&pq_abs, 1.0f));
        expect( 9991.0f > skcms_TransferFunction_eval(&pq_abs, 1.0f));

        // We can get a lot closer with an unprincpled tweak to that math.
        R = powf_(10009.9f, 1305/8192.0f);  // ~= 4.33759
        expect(skcms_TransferFunction_makePQish(&pq_abs,
                    R*(-107/128.0f), R*       1.0f,   32/2523.0f,
                       2413/128.0f,   -2392/128.0f, 8192/1305.0f));
        expect(0.0f == skcms_TransferFunction_eval(&pq_abs, 0.0f));
        expect(   99.9f < skcms_TransferFunction_eval(&pq_abs, 0.508f));
        expect(  100.0f > skcms_TransferFunction_eval(&pq_abs, 0.508f));
        expect( 9999.0f < skcms_TransferFunction_eval(&pq_abs, 1.0f));
        expect(10000.0f > skcms_TransferFunction_eval(&pq_abs, 1.0f));
    }
}

static void test_HLG() {
    skcms_TransferFunction enc, dec;
    expect(skcms_TransferFunction_makeHLG(&dec));
    expect(skcms_TransferFunction_invert(&dec, &enc));

    // Spot check the lower half of the curve.
    // Linear 0 encodes as 0.5*(0)^0.5 == 0.
    expect(0.0f == skcms_TransferFunction_eval(&enc, 0.0f));
    expect(0.0f == skcms_TransferFunction_eval(&dec, 0.0f));

    // Linear 1 encodes as 0.5*(1)^0.5 == 0.5
    expect(0.5f == skcms_TransferFunction_eval(&enc, 1.0f));
    expect(1.0f == skcms_TransferFunction_eval(&dec, 0.5f));

    // Linear 0.5 encodes as 0.5*(0.5)^0.5, about 0.3535.
    expect(0.3535f < skcms_TransferFunction_eval(&enc, 0.5f));
    expect(0.3536f > skcms_TransferFunction_eval(&enc, 0.5f));
    expect(0.5000f < skcms_TransferFunction_eval(&dec, skcms_TransferFunction_eval(&enc, 0.5f)));
    expect(0.5001f > skcms_TransferFunction_eval(&dec, skcms_TransferFunction_eval(&enc, 0.5f)));

    // Spot check upper half of the curve.
    // We should have some continuity with the lower half.
    expect(0.5000f < skcms_TransferFunction_eval(&enc, 1.000001f));
    expect(0.5001f > skcms_TransferFunction_eval(&enc, 1.000001f));

    // TODO: this isn't really the best round-trip precision.
    expect(1.000001f < skcms_TransferFunction_eval(&dec,
                                                   skcms_TransferFunction_eval(&enc, 1.000001f)));
    expect(1.000010f > skcms_TransferFunction_eval(&dec,
                                                   skcms_TransferFunction_eval(&enc, 1.000001f)));

    // The maximum value we can encode should be 12.
    // TODO: it'd be nice to get this to exactly 1.0f.
    expect(0.999999f < skcms_TransferFunction_eval(&enc, 12.0f));
    expect(1.000000f > skcms_TransferFunction_eval(&enc, 12.0f));
    // TODO: it'd be nice to get this to exactly 12.0f.
    expect(12.00000f < skcms_TransferFunction_eval(&dec, 1.0f));
    expect(12.00001f > skcms_TransferFunction_eval(&dec, 1.0f));

    // Now let's try that all again with skcms_Transform(), first linear -> HLG.
    float rgb[] = { 0.0f,1.0f,0.5f, 1.000001f,6.0f,12.0f };

    skcms_ICCProfile src = *skcms_XYZD50_profile(),
                     dst = *skcms_XYZD50_profile();
    skcms_SetTransferFunction(&dst, &dec);

    expect(skcms_Transform(rgb, skcms_PixelFormat_RGB_fff,skcms_AlphaFormat_Unpremul, &src,
                           rgb, skcms_PixelFormat_RGB_fff,skcms_AlphaFormat_Unpremul, &dst, 2));
    expect(rgb[0] == 0.0f);
    expect(rgb[1] == 0.5f);
    expect(0.35350f < rgb[2] && rgb[2] < 0.35360f);
    expect(0.50000f < rgb[3] && rgb[3] < 0.50010f);
    expect(0.87164f < rgb[4] && rgb[4] < 0.87165f);
    expect(0.99999f < rgb[5] && rgb[5] < 1.00000f);

    // Convert back.
    expect(skcms_Transform(rgb, skcms_PixelFormat_RGB_fff,skcms_AlphaFormat_Unpremul, &dst,
                           rgb, skcms_PixelFormat_RGB_fff,skcms_AlphaFormat_Unpremul, &src, 2));
    expect(rgb[0] == 0.0f);
    expect(rgb[1] == 1.0f);
    expect( 0.50000f < rgb[2] && rgb[2] <  0.50001f);
    expect( 1.00000f < rgb[3] && rgb[3] <  1.00001f);
    expect( 6.00000f < rgb[4] && rgb[4] <  6.00001f);
    expect(12.00000f < rgb[5] && rgb[5] < 12.00001f);
}

static void test_scaled_HLG() {
    // HLG curve scaled 4x, spot checked at a bunch of interesting points.
    skcms_TransferFunction enc, dec;
    expect(skcms_TransferFunction_makeScaledHLGish(
                &dec, 4.0f, 2.0f,2.0f
                    , 1/0.17883277f, 0.28466892f, 0.55991073f));
    expect(skcms_TransferFunction_invert(&dec, &enc));

    // TODO: tolerance in ulps?
    const float exact = 0.0000f,
                tight = 0.0001f,
                loose = 0.0002f;
    struct {
        float tol, linear, encoded;
    } cases[] = {
        // Points well on the gamma side of the curve.
        {exact, 0.0f, 0.0f},                 // = 0.5*(0.0/4)^0.5
        {tight, 0.5f, 0.1767766952966369f},  // ≈ 0.5*(0.5/4)^0.5
        {tight, 1.0f, 0.25f},                // = 0.5*(1.0/4)^0.5
        {tight, 2.0f, 0.3535533905932738f},  // ≈ 0.5*(2.0/4)^0.5

        // With a scale of 4, linear 4.0f is the border between gamma and exponential curves.
        {tight, 3.999f, 0.49993749609326166f},   // ≈ 0.5*(3.999/4)^0.5
        {exact, 4.000f, 0.5f},                   // = 0.5*(4.000/4)^0.5
        {tight, 4.001f, 0.5000624895514657f},    // ≈ 0.17883*ln(4.001/4 - 0.28467) + 0.55991

        // Points well on the exponential side of the curve.
        {loose,  6.0f, 0.5947860768815979f},     // ≈ 0.17883*ln( 6.0/4 - 0.28467) + 0.55991
        {tight, 12.0f, 0.7385492680658274f},     // ≈ 0.17883*ln(12.0/4 - 0.28467) + 0.55991
        {tight, 48.0f, 1.0f},                    // Unscaled max is 12, ours is 4x higher, 48.
    };

    for (int i = 0; i < ARRAY_COUNT(cases); i++) {
        float encoded = skcms_TransferFunction_eval(&enc, cases[i].linear);
        //fprintf(stderr, "%g -> %g, want %g\n", cases[i].linear, encoded, cases[i].encoded);
        expect(encoded <= cases[i].encoded + cases[i].tol);
        expect(encoded >= cases[i].encoded - cases[i].tol);

        float linear = skcms_TransferFunction_eval(&dec, cases[i].encoded);
        //fprintf(stderr, "%g -> %g, want %g\n", cases[i].encoded, linear, cases[i].linear);
        expect(linear <= cases[i].linear + cases[i].tol);
        expect(linear >= cases[i].linear - cases[i].tol);
    }

    // Now try all the same with skcms_Transform().
    #define N ((ARRAY_COUNT(cases)+2)/3)
    float rgb[N*3] = {0};

    skcms_ICCProfile src = *skcms_XYZD50_profile(),
                     dst = *skcms_XYZD50_profile();
    skcms_SetTransferFunction(&dst, &dec);

    for (int i = 0; i < ARRAY_COUNT(cases); i++) {
        rgb[i] = cases[i].linear;
    }
    expect(skcms_Transform(rgb, skcms_PixelFormat_RGB_fff,skcms_AlphaFormat_Unpremul, &src,
                           rgb, skcms_PixelFormat_RGB_fff,skcms_AlphaFormat_Unpremul, &dst, N));
    for (int i = 0; i < ARRAY_COUNT(cases); i++) {
        expect(rgb[i] <= cases[i].encoded + cases[i].tol);
        expect(rgb[i] >= cases[i].encoded - cases[i].tol);
    }

    for (int i = 0; i < ARRAY_COUNT(cases); i++) {
        rgb[i] = cases[i].encoded;
    }
    expect(skcms_Transform(rgb, skcms_PixelFormat_RGB_fff,skcms_AlphaFormat_Unpremul, &dst,
                           rgb, skcms_PixelFormat_RGB_fff,skcms_AlphaFormat_Unpremul, &src, N));
    for (int i = 0; i < ARRAY_COUNT(cases); i++) {
        expect(rgb[i] <= cases[i].linear + cases[i].tol);
        expect(rgb[i] >= cases[i].linear - cases[i].tol);
    }
    #undef N
}

static void test_PQ_invert() {
    skcms_TransferFunction pqA, invA, invB;

    expect(skcms_TransferFunction_makePQ(&pqA));
    // PQ's inverse is actually also PQish, so we can write out its expected value here.
    expect(skcms_TransferFunction_makePQish(&invA, 107/128.0f, 2413/128.0f, 1305/8192.0f
                                                 ,       1.0f, 2392/128.0f, 2523/  32.0f));
    expect(skcms_TransferFunction_invert(&pqA, &invB));

    // a,b,d,e really just negate and swap around,
    // so those should be exact.  c and f will 1.0f/x
    // each other, so they might not be exactly perfect,
    // but it turns out we do get lucky here.

    expect(invA.g == invB.g);  // I.e. are we still PQ?
    expect(invA.a == invB.a);
    expect(invA.b == invB.b);
    expect(invA.c == invB.c);  // We got lucky here.
    expect(invA.d == invB.d);
    expect(invA.e == invB.e);
    expect(invA.f == invB.f);  // And here.

    // Just for fun, invert back to PQ.
    // This just tests the same code path twice.
    skcms_TransferFunction pqB;
    expect(skcms_TransferFunction_invert(&invA, &pqB));

    expect(pqA.g == pqB.g);
    expect(pqA.a == pqB.a);
    expect(pqA.b == pqB.b);
    expect(pqA.c == pqB.c);
    expect(pqA.d == pqB.d);
    expect(pqA.e == pqB.e);
    expect(pqA.f == pqB.f);

    // PQ functions invert to the same form.
    expect(pqA.g == invA.g);

    // TODO: would be nice for this to pass.
#if 0
    skcms_Curve pq_curve = {{0,  pqA}},
               inv_curve = {{0, invA}};

    expect(skcms_AreApproximateInverses(& pq_curve, &invA));
    expect(skcms_AreApproximateInverses(&inv_curve, & pqA));
#endif
}

static void test_HLG_invert() {
    skcms_TransferFunction hlg, inv;

    expect(skcms_TransferFunction_makeHLG(&hlg));
    // Unlike PQ, we can't create HLG's inverse directly, only via _invert().
    expect(skcms_TransferFunction_invert(&hlg, &inv));

    skcms_TransferFunction back;
    expect(skcms_TransferFunction_invert(&inv, &back));

    expect(hlg.g == back.g);
    expect(hlg.a == back.a);
    expect(hlg.b == back.b);
    expect(hlg.c == back.c);
    expect(hlg.d == back.d);
    expect(hlg.e == back.e);
    expect(hlg.f == back.f);

    // HLG functions invert between two different forms.
    expect(hlg.g != inv.g);

    skcms_Curve hlg_curve = {{0, hlg}},
                inv_curve = {{0, inv}};

    expect(skcms_AreApproximateInverses(&hlg_curve, &inv));
    expect(skcms_AreApproximateInverses(&inv_curve, &hlg));
}

static void test_RGBA_8888_sRGB() {
    // We'll convert sRGB to Display P3 two ways and test they're equivalent.

    // Method A: normal sRGB profile we're used to, paired with RGBA_8888.
    const skcms_ICCProfile* sRGB = skcms_sRGB_profile();

    // Method B: linear sRGB profile paired with RGBA_8888_sRGB.
    skcms_ICCProfile linear_sRGB = *sRGB;
    skcms_TransferFunction linearTF = { 1,1,0,0,0,0,0 };
    skcms_SetTransferFunction(&linear_sRGB, &linearTF);

    struct {
        skcms_PixelFormat       fmt;
        const skcms_ICCProfile* prof;
        float                   f32[256];
    } A = { skcms_PixelFormat_RGBA_8888     ,         sRGB, {0} },
      B = { skcms_PixelFormat_RGBA_8888_sRGB, &linear_sRGB, {0} };

    // We'll skip some bytes as alpha, but this is probably plenty of testing.
    uint8_t bytes[256];
    for (int i = 0; i < 256; i++) {
        bytes[i] = i & 0xff;
    }

    // We transform to another gamut to make sure both methods go through a full-power transform.
    void*  ptr;
    size_t len;
    expect(load_file("profiles/mobile/Display_P3_parametric.icc", &ptr,&len));
    skcms_ICCProfile dp3;
    expect(skcms_Parse(ptr, len, &dp3));

    expect(skcms_Transform(bytes,                       A.fmt, skcms_AlphaFormat_Unpremul, A.prof,
                           A.f32, skcms_PixelFormat_RGBA_ffff, skcms_AlphaFormat_Unpremul,   &dp3,
                           64));
    expect(skcms_Transform(bytes,                       B.fmt, skcms_AlphaFormat_Unpremul, B.prof,
                           B.f32, skcms_PixelFormat_RGBA_ffff, skcms_AlphaFormat_Unpremul,   &dp3,
                           64));

    // The two methods should be bit-exact.
    for (int i = 0; i < 256; i++) {
        expect(A.f32[i] == B.f32[i]);
    }

    // Now let's transform both back and test they're round-trip the same.
    for (int i = 0; i < 256; i++) { bytes[i] = 0; }
    expect(skcms_Transform(A.f32, skcms_PixelFormat_RGBA_ffff, skcms_AlphaFormat_Unpremul,   &dp3,
                           bytes,                       A.fmt, skcms_AlphaFormat_Unpremul, A.prof,
                           64));
    for (int i = 0; i < 256; i++) {
        expect(bytes[i] == i);
    }

    for (int i = 0; i < 256; i++) { bytes[i] = 0; }
    expect(skcms_Transform(B.f32, skcms_PixelFormat_RGBA_ffff, skcms_AlphaFormat_Unpremul,   &dp3,
                           bytes,                       B.fmt, skcms_AlphaFormat_Unpremul, B.prof,
                           64));
    for (int i = 0; i < 256; i++) {
        expect(bytes[i] == i);
    }

    free(ptr);
}

static void test_ParseWithA2BPriority() {
    void*  ptr;
    size_t len;
    expect(load_file("profiles/misc/US_Web_Coated_SWOP_CMYK.icc", &ptr,&len));

    skcms_ICCProfile simple;
    expect(skcms_Parse(ptr, len, &simple));  // This will pick up A2B0.
    expect(simple.has_A2B);

    for (int priority = -1; priority < 4; priority++) {
        skcms_ICCProfile profile;

        bool ok = skcms_ParseWithA2BPriority(ptr, len, &priority, 1, &profile);
        if (priority < 0 || priority > 2) {
            expect(!ok);
            continue;
        }
        expect(ok);
        if (priority == 0) {
            expect(0 == memcmp(&profile, &simple, sizeof(profile)));
        } else {
            // A2B1 != A2B0, and while A2B2 == A2B0, B2A2 != B2A0.
            expect(0 != memcmp(&profile, &simple, sizeof(profile)));
        }
    }

    free(ptr);
}

static void test_B2A() {
    void*  ptr;
    size_t len;
    expect(load_file("profiles/color.org/Upper_Left.icc", &ptr,&len));

    skcms_ICCProfile profile;
    expect(skcms_Parse(ptr, len, &profile));
    expect(!profile.has_trc);
    expect(!profile.has_toXYZD50);
    expect( profile.has_A2B);
    expect( profile.has_B2A);

    // A B2A profile is usable as a destination unchanged.
    skcms_ICCProfile copy = profile;
    expect(skcms_MakeUsableAsDestination(&copy));
    expect(0 == memcmp(&copy, &profile, sizeof(profile)));

    // A B2A-only profile does not have the TRC curves that …WithSingleCurve() needs.
    expect(!skcms_MakeUsableAsDestinationWithSingleCurve(&profile));

    // A2B transform should be well-supported.
    const uint8_t* src = skcms_252_random_bytes;
    float xyza[252];
    expect(skcms_Transform(
            src,  skcms_PixelFormat_RGBA_8888, skcms_AlphaFormat_Unpremul, &profile,
            xyza, skcms_PixelFormat_RGBA_ffff, skcms_AlphaFormat_Unpremul, skcms_XYZD50_profile(),
            252/4));

    // Now convert back using B2A.
    uint8_t dst[252];
    expect(skcms_Transform(
            xyza, skcms_PixelFormat_RGBA_ffff, skcms_AlphaFormat_Unpremul, skcms_XYZD50_profile(),
            dst,  skcms_PixelFormat_RGBA_8888, skcms_AlphaFormat_Unpremul, &profile,
            252/4));

    for (int i = 0; i < 252; i++) {
        // Alpha should not be changed.
        if (i % 4 == 3) {
            expect(dst[i] == src[i]);
            continue;
        }
#if 0  // TODO: this looks nothing like an identity transform!
        fprintf(stderr, "%3d   %02x  % .4f   %02x\n", i, src[i], xyza[i], dst[i]);
        //expect(dst[i] == src[i]);
#endif
    }

    free(ptr);
}

int main(int argc, char** argv) {
    bool regenTestData = false;
    for (int i = 1; i < argc; ++i) {
        if (0 == strcmp(argv[i], "-t")) {
            regenTestData = true;
        }
    }

    test_ICCProfile();
    test_FormatConversions();
    test_FormatConversions_565();
    test_FormatConversions_101010();
    test_FormatConversions_16161616LE();
    test_FormatConversions_161616LE();
    test_FormatConversions_16161616BE();
    test_FormatConversions_161616BE();
    test_FormatConversions_half();
    test_FormatConversions_half_norm();
    test_FormatConversions_float();
    test_ApproximateCurve_clamped();
    test_Matrix3x3_invert();
    test_SimpleRoundTrip();
    test_FloatRoundTrips();
    test_ByteToLinearFloat();
    test_MakeUsableAsDestination();
    test_MakeUsableAsDestinationAdobe();
    test_AdaptToD50();
    test_PrimariesToXYZ();
    test_Programmatic_sRGB();
    test_ExactlyEqual();
    test_GrayscaleAndRGBCanBeEqual();
    test_AliasedTransforms();
    test_Palette8();
    test_TF_invert();
    test_Clamp();
    test_Premul();
    test_PQ();
    test_HLG();
    test_scaled_HLG();
    test_PQ_invert();
    test_HLG_invert();
    test_RGBA_8888_sRGB();
    test_ParseWithA2BPriority();
    test_B2A();

    // Temporarily disable some tests while getting FP16 compute working.
    if (!kFP16) {
        test_Parse(regenTestData);
        test_sRGB_AllBytes();
        test_TRC_Table16();
    }
#if 0
    test_CLUT();
#endif

    return 0;
}
