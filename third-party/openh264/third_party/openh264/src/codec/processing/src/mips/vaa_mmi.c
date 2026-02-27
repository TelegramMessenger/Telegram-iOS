/*!
 * \copy
 *     Copyright (c)  2009-2018, Cisco Systems
 *     All rights reserved.
 *
 *     Redistribution and use in source and binary forms, with or without
 *     modification, are permitted provided that the following conditions
 *     are met:
 *
 *        * Redistributions of source code must retain the above copyright
 *          notice, this list of conditions and the following disclaimer.
 *
 *        * Redistributions in binary form must reproduce the above copyright
 *          notice, this list of conditions and the following disclaimer in
 *          the documentation and/or other materials provided with the
 *          distribution.
 *
 *     THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 *     "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 *     LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 *     FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 *     COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 *     INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 *     BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 *     LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 *     CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 *     LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
 *     ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *     POSSIBILITY OF SUCH DAMAGE.
 *
 *
 * \file    vaa_mmi.c
 *
 * \brief   Loongson optimization
 *
 * \date    23/07/2018 Created
 *
 *************************************************************************************
 */
#include <stdint.h>
#include "asmdefs_mmi.h"

//f4 is 0x1, f6 is 0x8
#define WELS_MAX_REG_MMI(f0, f2, f4, f6) \
  "punpckhwd  $f4, "#f0", "#f0"    \n\t" \
  "punpckhwd  $f6, "#f2", "#f2"    \n\t" \
  "pmaxub     "#f0", "#f0", $f4    \n\t" \
  "pmaxub     "#f2", "#f2", $f6    \n\t" \
  "pshufh     $f4, "#f0", "#f4"    \n\t" \
  "pshufh     $f6, "#f2", "#f4"    \n\t" \
  "pmaxub     "#f0", "#f0", $f4    \n\t" \
  "pmaxub     "#f2", "#f2", $f6    \n\t" \
  "dsrl       $f4, "#f0", "#f6"    \n\t" \
  "dsrl       $f6, "#f2", "#f6"    \n\t" \
  "pmaxub     "#f0", "#f0", $f4    \n\t" \
  "pmaxub     "#f2", "#f2", $f6    \n\t"

#define WELS_SAD_SD_MAD_16x1_MMI(f0, f2, f4, f6, f8, f10, f12, f14, r0, r1, r2) \
  "gslqc1     $f6, $f4, 0x0("#r0")                \n\t" \
  "gslqc1     $f10, $f8, 0x0("#r1")               \n\t" \
  "pasubub    $f12, $f4, $f0                      \n\t" \
  "pasubub    $f14, $f6, $f2                      \n\t" \
  "biadd      $f12, $f12                          \n\t" \
  "biadd      $f14, $f14                          \n\t" \
  "paddw      "#f4", "#f4", $f12                  \n\t" \
  "paddw      "#f6", "#f6", $f14                  \n\t" \
  "pasubub    $f12, $f8, $f0                      \n\t" \
  "pasubub    $f14, $f10, $f2                     \n\t" \
  "biadd      $f12, $f12                          \n\t" \
  "biadd      $f14, $f14                          \n\t" \
  "paddw      "#f8", "#f8", $f12                  \n\t" \
  "paddw      "#f10", "#f10", $f14                \n\t" \
  "pasubub    $f12, $f4, $f8                      \n\t" \
  "pasubub    $f14, $f6, $f10                     \n\t" \
  "pmaxub     "#f12", "#f12", $f12                \n\t" \
  "pmaxub     "#f14", "#f14", $f14                \n\t" \
  "pasubub    $f12, $f12, $f0                     \n\t" \
  "pasubub    $f14, $f14, $f2                     \n\t" \
  "biadd      $f12, $f12                          \n\t" \
  "biadd      $f14, $f14                          \n\t" \
  "paddw      "#f0", "#f0", $f12                  \n\t" \
  "paddw      "#f2", "#f2", $f14                  \n\t" \
  PTR_ADDU   ""#r0", "#r0", "#r2"                 \n\t" \
  PTR_ADDU   ""#r1", "#r1", "#r2"                 \n\t"

#define WELS_SAD_16x2_MMI(f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, r1, r2, r3) \
  "gslqc1     "#f1",  "#f2",  0x00("#r1")         \n\t" \
  "gslqc1     "#f3",  "#f4",  0x00("#r2")         \n\t" \
  PTR_ADDU    ""#r1", "#r1",  "#r3"               \n\t" \
  "gslqc1     "#f5",  "#f6",  0x00("#r1")         \n\t" \
  PTR_ADDU    ""#r2", "#r2",  "#r3"               \n\t" \
  "gslqc1     "#f7",  "#f8",  0x00("#r2")         \n\t" \
  "pasubub    "#f1",  "#f1",  "#f3"               \n\t" \
  "pasubub    "#f2",  "#f2",  "#f4"               \n\t" \
  "biadd      "#f1",  "#f1"                       \n\t" \
  "biadd      "#f2",  "#f2"                       \n\t" \
  "pasubub    "#f5",  "#f5",  "#f7"               \n\t" \
  "pasubub    "#f6",  "#f6",  "#f8"               \n\t" \
  "biadd      "#f5",  "#f5"                       \n\t" \
  "biadd      "#f6",  "#f6"                       \n\t" \
  "paddw      "#f9",  "#f9",  "#f1"               \n\t" \
  "paddw      "#f9",  "#f9",  "#f5"               \n\t" \
  "paddw      "#f10", "#f10", "#f2"               \n\t" \
  "paddw      "#f10", "#f10", "#f6"               \n\t" \
  PTR_ADDU    ""#r1", "#r1",  "#r3"               \n\t" \
  PTR_ADDU    ""#r2", "#r2",  "#r3"               \n\t"

#define WELS_SAD_SUM_SQSUM_SQDIFF_16x1_MMI(r0, r1, r2) \
  "gslqc1     $f6, $f4, 0x0("#r0")                \n\t" \
  "gslqc1     $f10, $f8, 0x0("#r1")               \n\t" \
  "pasubub    $f12, $f4, $f8                      \n\t" \
  "pasubub    $f14, $f6, $f10                     \n\t" \
  "biadd      $f12, $f12                          \n\t" \
  "biadd      $f14, $f14                          \n\t" \
  "paddw      $f28, $f28, $f12                    \n\t" \
  "paddw      $f30, $f30, $f14                    \n\t" \
  "pasubub    $f12, $f4, $f8                      \n\t" \
  "pasubub    $f14, $f6, $f10                     \n\t" \
  "pasubub    $f8, $f4, $f0                       \n\t" \
  "pasubub    $f10, $f6, $f2                      \n\t" \
  "biadd      $f8, $f8                            \n\t" \
  "biadd      $f10, $f10                          \n\t" \
  "paddw      $f24, $f24, $f8                     \n\t" \
  "paddw      $f26, $f26, $f10                    \n\t" \
  "punpcklbh  $f8, $f6, $f2                       \n\t" \
  "punpckhbh  $f10, $f6, $f2                      \n\t" \
  "punpckhbh  $f6, $f4, $f0                       \n\t" \
  "punpcklbh  $f4, $f4, $f0                       \n\t" \
  "pmaddhw    $f4, $f4, $f4                       \n\t" \
  "pmaddhw    $f6, $f6, $f6                       \n\t" \
  "pmaddhw    $f8, $f8, $f8                       \n\t" \
  "pmaddhw    $f10, $f10, $f10                    \n\t" \
  "paddw      $f20, $f20, $f4                     \n\t" \
  "paddw      $f22, $f22, $f6                     \n\t" \
  "paddw      $f20, $f20, $f8                     \n\t" \
  "paddw      $f22, $f22, $f10                    \n\t" \
  "punpcklbh  $f4, $f12, $f0                      \n\t" \
  "punpckhbh  $f6, $f12, $f0                      \n\t" \
	"punpcklbh  $f12, $f14, $f2                     \n\t" \
	"punpckhbh  $f14, $f14, $f2                     \n\t" \
  "pmaddhw    $f4, $f4, $f4                       \n\t" \
  "pmaddhw    $f6, $f6, $f6                       \n\t" \
  "pmaddhw    $f12, $f12, $f12                    \n\t" \
  "pmaddhw    $f14, $f14, $f14                    \n\t" \
  "paddw      $f16, $f16, $f4                     \n\t" \
  "paddw      $f18, $f18, $f6                     \n\t" \
  "paddw      $f16, $f16, $f12                    \n\t" \
  "paddw      $f18, $f18, $f14                    \n\t" \
  PTR_ADDU   ""#r0", "#r0", "#r2"                 \n\t" \
  PTR_ADDU   ""#r1", "#r1", "#r2"                 \n\t"

#define WELS_SAD_BGD_SQDIFF_16x1_MMI(f0, f2, f4, f6, f8, f10, f12, f14, r0, r1, r2) \
  "gslqc1     $f6, $f4, 0x0("#r0")                \n\t" \
  "punpcklbh  $f8, $f4, $f0                       \n\t" \
  "punpckhbh  $f10, $f4, $f0                      \n\t" \
  "punpcklbh  $f12, $f6, $f2                      \n\t" \
  "punpckhbh  $f14, $f6, $f2                      \n\t" \
  "pmaddhw    $f8, $f8, $f8                       \n\t" \
  "pmaddhw    $f10, $f10, $f10                    \n\t" \
  "pmaddhw    $f12, $f12, $f12                    \n\t" \
  "pmaddhw    $f14, $f14, $f14                    \n\t" \
  "paddw      $f8, $f8, $f12                      \n\t" \
  "paddw      $f10, $f10, $f14                    \n\t" \
  "punpckhwd  $f12, $f0, $f8                      \n\t" \
  "punpckhwd  $f14, $f0, $f10                     \n\t" \
  "punpcklwd  $f8, $f0, $f8                       \n\t" \
  "punpcklwd  $f10, $f0, $f10                     \n\t" \
  "paddw      $f8, $f8, $f12                      \n\t" \
  "paddw      $f10, $f10, $f14                    \n\t" \
  "paddw      "#f0", "#f0", $f8                   \n\t" \
  "paddw      "#f2", "#f2", $f10                  \n\t" \
  "gslqc1     $f10, $f8, 0x0("#r1")               \n\t" \
  "pasubub    $f12, $f4, $f0                      \n\t" \
  "pasubub    $f14, $f6, $f2                      \n\t" \
  "biadd      $f12, $f12                          \n\t" \
  "biadd      $f14, $f14                          \n\t" \
  "paddw      "#f4", "#f4", $f12                  \n\t" \
  "paddw      "#f6", "#f6", $f14                  \n\t" \
  "pasubub    $f12, $f8, $f0                      \n\t" \
  "pasubub    $f14, $f10, $f2                     \n\t" \
  "biadd      $f12, $f12                          \n\t" \
  "biadd      $f14, $f14                          \n\t" \
  "punpcklwd  $f14, $f14, $f14                    \n\t" \
  "punpckhwd  $f14, $f12, $f14                    \n\t" \
  "punpcklwd  $f12, $f0, $f12                     \n\t" \
  "paddw      "#f4", "#f4", $f12                  \n\t" \
  "paddw      "#f6", "#f6", $f14                  \n\t" \
  "pasubub    $f12, $f4, $f8                      \n\t" \
  "pasubub    $f14, $f6, $f10                     \n\t" \
  "pmaxub     "#f8", "#f8", $f12                  \n\t" \
  "pmaxub     "#f10", "#f10", $f14                \n\t" \
  "paddw      $f4, $f0, $f12                      \n\t" \
  "paddw      $f6, $f0, $f14                      \n\t" \
  "pasubub    $f12, $f12, $f0                     \n\t" \
  "pasubub    $f14, $f14, $f2                     \n\t" \
  "biadd      $f12, $f12                          \n\t" \
  "biadd      $f14, $f14                          \n\t" \
  "paddw      "#f0", "#f0", $f12                  \n\t" \
  "paddw      "#f2", "#f2", $f14                  \n\t" \
  "paddw      $f12, $f0, $f4                      \n\t" \
  "paddw      $f14, $f0, $f6                      \n\t" \
  "punpcklbh  $f4, $f12, $f0                      \n\t" \
  "punpckhbh  $f6, $f12, $f0                      \n\t" \
  "punpcklbh  $f12, $f14, $f2                     \n\t" \
  "punpckhbh  $f14, $f14, $f2                     \n\t" \
  "pmaddhw    $f4, $f4, $f4                       \n\t" \
  "pmaddhw    $f6, $f6, $f6                       \n\t" \
  "pmaddhw    $f12, $f12, $f12                    \n\t" \
  "pmaddhw    $f14, $f14, $f14                    \n\t" \
  "paddw      "#f12", "#f12", $f4                 \n\t" \
  "paddw      "#f14", "#f14", $f6                 \n\t" \
  "paddw      "#f12", "#f12", $f12                \n\t" \
  "paddw      "#f14", "#f14", $f14                \n\t" \
  PTR_ADDU   ""#r0", "#r0", "#r2"                 \n\t" \
  PTR_ADDU   ""#r1", "#r1", "#r2"                 \n\t"

#define WELS_SAD_SUM_SQSUM_16x1_MMI(r0, r1, r2) \
  "gslqc1     $f6, $f4, 0x0("#r0")                \n\t" \
  "gslqc1     $f10, $f8, 0x0("#r1")               \n\t" \
  "pasubub    $f12, $f4, $f8                      \n\t" \
  "pasubub    $f14, $f6, $f10                     \n\t" \
  "biadd      $f12, $f12                          \n\t" \
  "biadd      $f14, $f14                          \n\t" \
  "paddw      $f24, $f24, $f12                    \n\t" \
  "paddw      $f26, $f26, $f14                    \n\t" \
  "pasubub    $f12, $f4, $f0                      \n\t" \
  "pasubub    $f14, $f6, $f2                      \n\t" \
  "biadd      $f12, $f12                          \n\t" \
  "biadd      $f14, $f14                          \n\t" \
  "paddw      $f20, $f20, $f12                    \n\t" \
  "paddw      $f22, $f22, $f14                    \n\t" \
  "punpcklbh  $f8, $f6, $f2                       \n\t" \
  "punpckhbh  $f10, $f6, $f2                      \n\t" \
  "punpckhbh  $f6, $f4, $f0                       \n\t" \
  "punpcklbh  $f4, $f4, $f0                       \n\t" \
  "pmaddhw    $f4, $f4, $f4                       \n\t" \
  "pmaddhw    $f6, $f6, $f6                       \n\t" \
  "pmaddhw    $f8, $f8, $f8                       \n\t" \
  "pmaddhw    $f10, $f10, $f10                    \n\t" \
  "paddw      $f16, $f16, $f4                     \n\t" \
  "paddw      $f18, $f18, $f6                     \n\t" \
  "paddw      $f16, $f16, $f8                     \n\t" \
  "paddw      $f18, $f18, $f10                    \n\t" \
  PTR_ADDU   ""#r0", "#r0", "#r2"                 \n\t" \
  PTR_ADDU   ""#r1", "#r1", "#r2"                 \n\t"

void VAACalcSad_mmi(const uint8_t* pCurData, const uint8_t* pRefData,
                    int32_t iPicWidth, int32_t iPicHeight, int32_t iPicStride,
                    int32_t* pFrameSad, int32_t* pSad8x8) {
  double ftmp[13];
  uint64_t tmp[2];
  mips_reg addr[3];

  __asm__ volatile (
    ".set       arch=loongson3a                                     \n\t"
    PTR_SRL    "%[iPicWidth],   %[iPicWidth],   0x04                \n\t"
    PTR_SRL    "%[iPicHeight],  %[iPicHeight],  0x04                \n\t"
    "move       %[addr2],       %[iPicStride]                       \n\t"
    PTR_SLL    "%[iPicStride],  %[iPicStride],  0x04                \n\t"
    "xor        %[ftmp0],       %[ftmp0],       %[ftmp0]            \n\t"
    "xor        %[ftmp11],      %[ftmp11],      %[ftmp11]           \n\t"
    "xor        %[ftmp12],      %[ftmp12],      %[ftmp12]           \n\t"
    "1:                                                             \n\t"
    "move       %[addr0],       %[pCurData]                         \n\t"
    "move       %[addr1],       %[pRefData]                         \n\t"
    "move       %[tmp0],        %[iPicWidth]                        \n\t"
    "2:                                                             \n\t"
    "xor        %[ftmp9],       %[ftmp9],       %[ftmp9]            \n\t"
    "xor        %[ftmp10],      %[ftmp10],      %[ftmp10]           \n\t"
    WELS_SAD_16x2_MMI(%[ftmp1], %[ftmp2], %[ftmp3], %[ftmp4], %[ftmp5],
                      %[ftmp6], %[ftmp7], %[ftmp8], %[ftmp9], %[ftmp10],
                      %[addr0], %[addr1], %[addr2])
    WELS_SAD_16x2_MMI(%[ftmp1], %[ftmp2], %[ftmp3], %[ftmp4], %[ftmp5],
                      %[ftmp6], %[ftmp7], %[ftmp8], %[ftmp9], %[ftmp10],
                      %[addr0], %[addr1], %[addr2])
    WELS_SAD_16x2_MMI(%[ftmp1], %[ftmp2], %[ftmp3], %[ftmp4], %[ftmp5],
                      %[ftmp6], %[ftmp7], %[ftmp8], %[ftmp9], %[ftmp10],
                      %[addr0], %[addr1], %[addr2])
    WELS_SAD_16x2_MMI(%[ftmp1], %[ftmp2], %[ftmp3], %[ftmp4], %[ftmp5],
                      %[ftmp6], %[ftmp7], %[ftmp8], %[ftmp9], %[ftmp10],
                      %[addr0], %[addr1], %[addr2])
    "paddw      %[ftmp11],      %[ftmp11],      %[ftmp9]            \n\t"
    "paddw      %[ftmp12],      %[ftmp12],      %[ftmp10]           \n\t"
    "swc1       %[ftmp10],      0x00(%[pSad8x8])                    \n\t"
    "swc1       %[ftmp9],       0x04(%[pSad8x8])                    \n\t"

    "xor        %[ftmp9],       %[ftmp9],       %[ftmp9]            \n\t"
    "xor        %[ftmp10],      %[ftmp10],      %[ftmp10]           \n\t"
    WELS_SAD_16x2_MMI(%[ftmp1], %[ftmp2], %[ftmp3], %[ftmp4], %[ftmp5],
                      %[ftmp6], %[ftmp7], %[ftmp8], %[ftmp9], %[ftmp10],
                      %[addr0], %[addr1], %[addr2])
    WELS_SAD_16x2_MMI(%[ftmp1], %[ftmp2], %[ftmp3], %[ftmp4], %[ftmp5],
                      %[ftmp6], %[ftmp7], %[ftmp8], %[ftmp9], %[ftmp10],
                      %[addr0], %[addr1], %[addr2])
    WELS_SAD_16x2_MMI(%[ftmp1], %[ftmp2], %[ftmp3], %[ftmp4], %[ftmp5],
                      %[ftmp6], %[ftmp7], %[ftmp8], %[ftmp9], %[ftmp10],
                      %[addr0], %[addr1], %[addr2])
    WELS_SAD_16x2_MMI(%[ftmp1], %[ftmp2], %[ftmp3], %[ftmp4], %[ftmp5],
                      %[ftmp6], %[ftmp7], %[ftmp8], %[ftmp9], %[ftmp10],
                      %[addr0], %[addr1], %[addr2])
    "paddw      %[ftmp11],      %[ftmp11],      %[ftmp9]            \n\t"
    "paddw      %[ftmp12],      %[ftmp12],      %[ftmp10]           \n\t"
    "swc1       %[ftmp10],      0x08(%[pSad8x8])                    \n\t"
    "swc1       %[ftmp9],       0x0c(%[pSad8x8])                    \n\t"

    PTR_ADDU   "%[pSad8x8],     %[pSad8x8],     0x10                \n\t"
    PTR_SUBU   "%[addr0],       %[addr0],       %[iPicStride]       \n\t"
    PTR_SUBU   "%[addr1],       %[addr1],       %[iPicStride]       \n\t"
    PTR_ADDI   "%[tmp0],        %[tmp0],        -0x01               \n\t"
    PTR_ADDU   "%[addr0],       %[addr0],       0x10                \n\t"
    PTR_ADDU   "%[addr1],       %[addr1],       0x10                \n\t"
    "bnez       %[tmp0],        2b                                  \n\t"

    PTR_ADDI   "%[iPicHeight],  %[iPicHeight],  -0x01               \n\t"
    PTR_ADDU   "%[pCurData],    %[pCurData],    %[iPicStride]       \n\t"
    PTR_ADDU   "%[pRefData],    %[pRefData],    %[iPicStride]       \n\t"
    "bnez       %[iPicHeight],  1b                                  \n\t"

    "paddw      %[ftmp11],      %[ftmp11],      %[ftmp12]           \n\t"
    "swc1       %[ftmp11],      0x00(%[pFrameSad])                  \n\t"
    : [ftmp0]"=&f"(ftmp[0]),            [ftmp1]"=&f"(ftmp[1]),
      [ftmp2]"=&f"(ftmp[2]),            [ftmp3]"=&f"(ftmp[3]),
      [ftmp4]"=&f"(ftmp[4]),            [ftmp5]"=&f"(ftmp[5]),
      [ftmp6]"=&f"(ftmp[6]),            [ftmp7]"=&f"(ftmp[7]),
      [ftmp8]"=&f"(ftmp[8]),            [ftmp9]"=&f"(ftmp[9]),
      [ftmp10]"=&f"(ftmp[10]),          [ftmp11]"=&f"(ftmp[11]),
      [ftmp12]"=&f"(ftmp[12]),          [tmp0]"=&r"(tmp[0]),
      [addr0]"=&r"(addr[0]),            [addr1]"=&r"(addr[1]),
      [pCurData]"+&r"(pCurData),        [pRefData]"+&r"(pRefData),
      [iPicHeight]"+&r"(iPicHeight),    [iPicWidth]"+&r"(iPicWidth),
      [pSad8x8]"+&r"(pSad8x8),          [iPicStride]"+&r"(iPicStride),
      [addr2]"=&r"(addr[2])
    : [pFrameSad]"r"(pFrameSad)
    : "memory"
  );
}

void VAACalcSadBgd_mmi(const uint8_t *cur_data, const uint8_t *ref_data,
                       int32_t iPicWidth, int32_t iPicHeight, int32_t iPicStride,
                       int32_t *psadframe, int32_t *psad8x8, int32_t *p_sd8x8,
                       uint8_t *p_mad8x8) {
  BACKUP_REG;
  __asm__ volatile (
    ".set       arch=loongson3a                           \n\t"
    "move       $15, %[cur_data]                          \n\t"
    "dsrl       %[iPicWidth], %[iPicWidth], 0x4           \n\t"
    "dsrl       %[iPicHeight], %[iPicHeight], 0x4         \n\t"
    "dsll       $13, %[iPicStride], 0x4                   \n\t"
    "xor        $f0, $f0, $f0                             \n\t"
    "xor        $f2, $f2, $f2                             \n\t"
    "xor        $14, $14, $14                             \n\t"
    "1:                                                   \n\t"
    "move       $9, %[iPicWidth]                          \n\t"
    "move       $10, $15                                  \n\t"
    "move       $11, %[ref_data]                          \n\t"
    "2:                                                   \n\t"
    "xor        $f28, $f28, $f28                          \n\t"
    "xor        $f30, $f30, $f30                          \n\t"
    "xor        $f24, $f24, $f24                          \n\t"
    "xor        $f26, $f26, $f26                          \n\t"
    "xor        $f20, $f20, $f20                          \n\t"
    "xor        $f22, $f22, $f22                          \n\t"
    "xor        $f16, $f16, $f16                          \n\t"
    "xor        $f18, $f18, $f18                          \n\t"
    WELS_SAD_SD_MAD_16x1_MMI($f28, $f30, $f24, $f26, $f20, $f22, $f16, $f18,
                             $15, %[ref_data], %[iPicStride])
    WELS_SAD_SD_MAD_16x1_MMI($f28, $f30, $f24, $f26, $f20, $f22, $f16, $f18,
                             $15, %[ref_data], %[iPicStride])
    WELS_SAD_SD_MAD_16x1_MMI($f28, $f30, $f24, $f26, $f20, $f22, $f16, $f18,
                             $15, %[ref_data], %[iPicStride])
    WELS_SAD_SD_MAD_16x1_MMI($f28, $f30, $f24, $f26, $f20, $f22, $f16, $f18,
                             $15, %[ref_data], %[iPicStride])
    WELS_SAD_SD_MAD_16x1_MMI($f28, $f30, $f24, $f26, $f20, $f22, $f16, $f18,
                             $15, %[ref_data], %[iPicStride])
    WELS_SAD_SD_MAD_16x1_MMI($f28, $f30, $f24, $f26, $f20, $f22, $f16, $f18,
                             $15, %[ref_data], %[iPicStride])
    WELS_SAD_SD_MAD_16x1_MMI($f28, $f30, $f24, $f26, $f20, $f22, $f16, $f18,
                             $15, %[ref_data], %[iPicStride])
    WELS_SAD_SD_MAD_16x1_MMI($f28, $f30, $f24, $f26, $f20, $f22, $f16, $f18,
                             $15, %[ref_data], %[iPicStride])

    "dli        $8, 0x1                                   \n\t"
    "dmtc1      $8, $f8                                   \n\t"
    "dli        $8, 0x8                                   \n\t"
    "dmtc1      $8, $f10                                  \n\t"
    WELS_MAX_REG_MMI($f16, $f18, $f8, $f10)

    "dmfc1      $8, $f16                                  \n\t"
    "sb         $8, 0x0(%[p_mad8x8])                      \n\t"
    "dmfc1      $8, $f18                                  \n\t"
    "sb         $8, 0x1(%[p_mad8x8])                      \n\t"
    PTR_ADDIU  "%[p_mad8x8], %[p_mad8x8], 0x2             \n\t"

    "xor        $f16, $f16, $f16                          \n\t"
    "xor        $f18, $f18, $f18                          \n\t"
    "punpcklwd  $f30, $f30, $f30                          \n\t"
    "punpcklwd  $f26, $f26, $f26                          \n\t"
    "punpcklwd  $f22, $f22, $f22                          \n\t"

    "punpckhwd  $f30, $f28, $f30                          \n\t"
    "punpckhwd  $f26, $f24, $f26                          \n\t"
    "punpckhwd  $f22, $f20, $f22                          \n\t"

    "punpcklwd  $f28, $f16, $f28                          \n\t"
    "punpcklwd  $f24, $f16, $f24                          \n\t"
    "punpcklwd  $f20, $f16, $f20                          \n\t"

    WELS_SAD_SD_MAD_16x1_MMI($f28, $f30, $f24, $f26, $f20, $f22, $f16, $f18,
                             $15, %[ref_data], %[iPicStride])
    WELS_SAD_SD_MAD_16x1_MMI($f28, $f30, $f24, $f26, $f20, $f22, $f16, $f18,
                             $15, %[ref_data], %[iPicStride])
    WELS_SAD_SD_MAD_16x1_MMI($f28, $f30, $f24, $f26, $f20, $f22, $f16, $f18,
                             $15, %[ref_data], %[iPicStride])
    WELS_SAD_SD_MAD_16x1_MMI($f28, $f30, $f24, $f26, $f20, $f22, $f16, $f18,
                             $15, %[ref_data], %[iPicStride])
    WELS_SAD_SD_MAD_16x1_MMI($f28, $f30, $f24, $f26, $f20, $f22, $f16, $f18,
                             $15, %[ref_data], %[iPicStride])
    WELS_SAD_SD_MAD_16x1_MMI($f28, $f30, $f24, $f26, $f20, $f22, $f16, $f18,
                             $15, %[ref_data], %[iPicStride])
    WELS_SAD_SD_MAD_16x1_MMI($f28, $f30, $f24, $f26, $f20, $f22, $f16, $f18,
                             $15, %[ref_data], %[iPicStride])
    WELS_SAD_SD_MAD_16x1_MMI($f28, $f30, $f24, $f26, $f20, $f22, $f16, $f18,
                             $15, %[ref_data], %[iPicStride])

    "dli        $8, 0x1                                   \n\t"
    "dmtc1      $8, $f8                                   \n\t"
    "dli        $8, 0x8                                   \n\t"
    "dmtc1      $8, $f10                                  \n\t"
    WELS_MAX_REG_MMI($f16, $f18, $f8, $f10)

    "dmfc1      $8, $f16                                  \n\t"
    "sb         $8, 0x0(%[p_mad8x8])                      \n\t"
    "dmfc1      $8, $f18                                  \n\t"
    "sb         $8, 0x1(%[p_mad8x8])                      \n\t"
    "punpckhwd  $f4, $f28, $f30                           \n\t"
    PTR_ADDIU  "%[p_mad8x8], %[p_mad8x8], 0x2             \n\t"

    "punpcklwd  $f6, $f28, $f30                           \n\t"
    "gssqc1     $f6, $f4, 0x0(%[psad8x8])                 \n\t"
    PTR_ADDIU  "%[psad8x8], %[psad8x8], 0x10              \n\t"

    "paddw      $f6, $f6, $f30                            \n\t"
    "paddw      $f4, $f4, $f28                            \n\t"
    "punpckhwd  $f8, $f6, $f6                             \n\t"
    "paddw      $f4, $f4, $f8                             \n\t"
    "dmtc1      $14, $f6                                  \n\t"
    "paddw      $f6, $f6, $f4                             \n\t"
    "dmfc1      $14, $f6                                  \n\t"

    "psubw      $f24, $f24, $f20                          \n\t"
    "psubw      $f26, $f26, $f22                          \n\t"
    "punpckhwd  $f4, $f24, $f26                           \n\t"
    "punpcklwd  $f6, $f24, $f26                           \n\t"
    "gssqc1     $f6, $f4, 0x0(%[p_sd8x8])                 \n\t"
    PTR_ADDIU  "%[p_sd8x8], %[p_sd8x8], 0x10              \n\t"

    PTR_SUBU   "$15, $15, $13                             \n\t"
    PTR_SUBU   "%[ref_data], %[ref_data], $13             \n\t"
    PTR_ADDIU  "$15, $15, 0x10                            \n\t"
    PTR_ADDIU  "%[ref_data], %[ref_data], 0x10            \n\t"

    PTR_ADDIU  "%[iPicWidth], %[iPicWidth], -0x1          \n\t"
    "bnez       %[iPicWidth], 2b                          \n\t"
    "move       %[iPicWidth], $9                          \n\t"
    "move       $15, $10                                  \n\t"
    "move       %[ref_data], $11                          \n\t"
    PTR_ADDU   "$15, $15, $13                             \n\t"
    PTR_ADDU   "%[ref_data], %[ref_data], $13             \n\t"

    PTR_ADDIU  "%[iPicHeight], %[iPicHeight], -0x1        \n\t"
    "bnez       %[iPicHeight], 1b                         \n\t"

    "swl        $14, 0x3(%[psadframe])                    \n\t"
    "swr        $14, 0x0(%[psadframe])                    \n\t"
    : [ref_data]"+&r"((unsigned char *)ref_data), [iPicWidth]"+&r"((int)iPicWidth),
      [iPicHeight]"+&r"((int)iPicHeight), [psad8x8]"+&r"((int *)psad8x8),
      [p_sd8x8]"+&r"((int *)p_sd8x8), [p_mad8x8]"+&r"((unsigned char *)p_mad8x8)
    : [cur_data]"r"((unsigned char *)cur_data), [iPicStride]"r"((int)iPicStride),
      [psadframe]"r"((int *)psadframe)
    : "memory", "$8", "$9", "$10", "$11", "$12", "$13", "$14", "$15", "$f0", "$f2",
      "$f4", "$f6", "$f8", "$f10", "$f12", "$f14", "$f16", "$f18", "$f20", "$f22",
      "$f24", "$f26", "$f28", "$f30"
  );
  RECOVER_REG;
}

void VAACalcSadSsd_mmi(const uint8_t *cur_data, const uint8_t *ref_data,
                       int32_t iPicWidth, int32_t iPicHeight, int32_t iPicStride,
                       int32_t *psadframe, int32_t *psad8x8, int32_t *psum16x16,
                       int32_t *psqsum16x16, int32_t *psqdiff16x16) {
  BACKUP_REG;
  __asm__ volatile (
    ".set       arch=loongson3a                           \n\t"
    "move       $15, %[cur_data]                          \n\t"
    "dsrl       %[iPicWidth], %[iPicWidth], 0x4           \n\t"
    "dsrl       %[iPicHeight], %[iPicHeight], 0x4         \n\t"
    "dsll       $13, %[iPicStride], 0x4                   \n\t"
    "xor        $f0, $f0, $f0                             \n\t"
    "xor        $f2, $f2, $f2                             \n\t"
    "xor        $12, $12, $12                             \n\t"
    "xor        $14, $14, $14                             \n\t"
    "1:                                                   \n\t"
    "move       $9, %[iPicWidth]                          \n\t"
    "move       $10, $15                                  \n\t"
    "move       $11, %[ref_data]                          \n\t"
    "2:                                                   \n\t"
    "xor        $f28, $f28, $f28                          \n\t"
    "xor        $f30, $f30, $f30                          \n\t"
    "xor        $f24, $f24, $f24                          \n\t"
    "xor        $f26, $f26, $f26                          \n\t"
    "xor        $f20, $f20, $f20                          \n\t"
    "xor        $f22, $f22, $f22                          \n\t"
    "xor        $f16, $f16, $f16                          \n\t"
    "xor        $f18, $f18, $f18                          \n\t"
    WELS_SAD_SUM_SQSUM_SQDIFF_16x1_MMI($15, %[ref_data], %[iPicStride])
    WELS_SAD_SUM_SQSUM_SQDIFF_16x1_MMI($15, %[ref_data], %[iPicStride])
    WELS_SAD_SUM_SQSUM_SQDIFF_16x1_MMI($15, %[ref_data], %[iPicStride])
    WELS_SAD_SUM_SQSUM_SQDIFF_16x1_MMI($15, %[ref_data], %[iPicStride])
    WELS_SAD_SUM_SQSUM_SQDIFF_16x1_MMI($15, %[ref_data], %[iPicStride])
    WELS_SAD_SUM_SQSUM_SQDIFF_16x1_MMI($15, %[ref_data], %[iPicStride])
    WELS_SAD_SUM_SQSUM_SQDIFF_16x1_MMI($15, %[ref_data], %[iPicStride])
    WELS_SAD_SUM_SQSUM_SQDIFF_16x1_MMI($15, %[ref_data], %[iPicStride])
    "dmfc1      $8, $f28                                  \n\t"
    "sw         $8, 0x0(%[psad8x8])                       \n\t"
    "dmfc1      $8, $f30                                  \n\t"
    "sw         $8, 0x4(%[psad8x8])                       \n\t"
    "paddw      $f4, $f28, $f30                           \n\t"
    "dmfc1      $12, $f4                                  \n\t"
	  PTR_ADDU   "$14, $14, $12                             \n\t"

    "xor        $f28, $f28, $f28                          \n\t"
    "xor        $f30, $f30, $f30                          \n\t"
    WELS_SAD_SUM_SQSUM_SQDIFF_16x1_MMI($15, %[ref_data], %[iPicStride])
    WELS_SAD_SUM_SQSUM_SQDIFF_16x1_MMI($15, %[ref_data], %[iPicStride])
    WELS_SAD_SUM_SQSUM_SQDIFF_16x1_MMI($15, %[ref_data], %[iPicStride])
    WELS_SAD_SUM_SQSUM_SQDIFF_16x1_MMI($15, %[ref_data], %[iPicStride])
    WELS_SAD_SUM_SQSUM_SQDIFF_16x1_MMI($15, %[ref_data], %[iPicStride])
    WELS_SAD_SUM_SQSUM_SQDIFF_16x1_MMI($15, %[ref_data], %[iPicStride])
    WELS_SAD_SUM_SQSUM_SQDIFF_16x1_MMI($15, %[ref_data], %[iPicStride])
    WELS_SAD_SUM_SQSUM_SQDIFF_16x1_MMI($15, %[ref_data], %[iPicStride])
    "dmfc1      $8, $f28                                  \n\t"
    "sw         $8, 0x8(%[psad8x8])                       \n\t"
    "dmfc1      $8, $f30                                  \n\t"
    "paddw      $f4, $f28, $f30                           \n\t"
    "sw         $8, 0xc(%[psad8x8])                       \n\t"
    "dmfc1      $12, $f4                                  \n\t"
	  PTR_ADDU   "$14, $14, $12                             \n\t"
    PTR_ADDIU  "%[psad8x8],   %[psad8x8],   0x10          \n\t"

    "paddw      $f24, $f24, $f26                          \n\t"
    "dmfc1      $8, $f24                                  \n\t"
    "sw         $8, 0x0(%[psum16x16])                     \n\t"
    PTR_ADDIU  "%[psum16x16], %[psum16x16], 0x4           \n\t"
    "paddw      $f24, $f20, $f22                          \n\t"
	  "punpcklwd  $f20, $f24, $f24                          \n\t"
	  "punpckhwd  $f22, $f24, $f24                          \n\t"
    "paddw      $f20, $f20, $f22                          \n\t"
    "dmfc1      $8, $f20                                  \n\t"
    "sw         $8, 0x0(%[psqsum16x16])                   \n\t"
    PTR_ADDIU  "%[psqsum16x16], %[psqsum16x16], 0x4       \n\t"

    "paddw      $f20, $f16, $f18                          \n\t"
	  "punpcklwd  $f16, $f20, $f20                          \n\t"
	  "punpckhwd  $f18, $f20, $f20                          \n\t"
    "paddw      $f16, $f16, $f18                          \n\t"
    "dmfc1      $8, $f16                                  \n\t"
    "sw         $8, 0x0(%[psqdiff16x16])                  \n\t"
    PTR_ADDIU  "%[psqdiff16x16], %[psqdiff16x16], 0x4     \n\t"

    PTR_SUBU   "$15, $15, $13                             \n\t"
    PTR_SUBU   "%[ref_data], %[ref_data], $13             \n\t"
    PTR_ADDIU  "$15, $15, 0x10                            \n\t"
    PTR_ADDIU  "%[ref_data], %[ref_data], 0x10            \n\t"

    PTR_ADDIU  "%[iPicWidth], %[iPicWidth], -0x1          \n\t"
    "bnez       %[iPicWidth], 2b                          \n\t"
    "nop                                                  \n\t"
    "move       %[iPicWidth], $9                          \n\t"
    "move       $15, $10                                  \n\t"
    "move       %[ref_data], $11                          \n\t"
    PTR_ADDU   "$15, $15, $13                             \n\t"
    PTR_ADDU   "%[ref_data], %[ref_data], $13             \n\t"

    PTR_ADDIU  "%[iPicHeight], %[iPicHeight], -0x1        \n\t"
    "bnez       %[iPicHeight], 1b                         \n\t"
    "nop                                                  \n\t"

    "sw         $14, 0x0(%[psadframe])                    \n\t"
    : [ref_data]"+&r"((unsigned char *)ref_data), [iPicWidth]"+&r"((int)iPicWidth),
      [iPicHeight]"+&r"((int)iPicHeight), [psum16x16]"+&r"((int *)psum16x16),
      [psqsum16x16]"+&r"((int *)psqsum16x16), [psqdiff16x16]"+&r"((int *)psqdiff16x16)
    : [cur_data]"r"((unsigned char *)cur_data), [iPicStride]"r"((int)iPicStride),
      [psadframe]"r"((int *)psadframe), [psad8x8]"r"((int *)psad8x8)
    : "memory", "$8", "$9", "$10", "$11", "$12", "$13", "$14", "$15", "$f0", "$f2",
      "$f4", "$f6", "$f8", "$f10", "$f12", "$f14", "$f16", "$f18", "$f20", "$f22",
      "$f24", "$f26", "$f28", "$f30"
  );
  RECOVER_REG;
}

void VAACalcSadSsdBgd_mmi(const uint8_t *cur_data, const uint8_t *ref_data,
                          int32_t iPicWidth, int32_t iPicHeight, int32_t iPicStride,
                          int32_t *psadframe, int32_t *psad8x8, int32_t *psum16x16,
                          int32_t *psqsum16x16, int32_t *psqdiff16x16, int32_t *p_sd8x8,
                          uint8_t *p_mad8x8) {
  BACKUP_REG;
  __asm__ volatile (
    ".set       arch=loongson3a                           \n\t"
    "move       $15, %[cur_data]                          \n\t"
    "dsrl       %[iPicWidth], %[iPicWidth], 0x4           \n\t"
    "dsrl       %[iPicHeight], %[iPicHeight], 0x4         \n\t"
    "dsll       $13, %[iPicStride], 0x4                   \n\t"
    "xor        $f0, $f0, $f0                             \n\t"
    "xor        $f2, $f2, $f2                             \n\t"
    "xor        $12, $12, $12                             \n\t"
    "xor        $14, $14, $14                             \n\t"
    "1:                                                   \n\t"
    "move       $9, %[iPicWidth]                          \n\t"
    "move       $10, $15                                  \n\t"
    "move       $11, %[ref_data]                          \n\t"
    "2:                                                   \n\t"
    "xor        $f28, $f28, $f28                          \n\t"
    "xor        $f30, $f30, $f30                          \n\t"
    "xor        $f24, $f24, $f24                          \n\t"
    "xor        $f26, $f26, $f26                          \n\t"
    "xor        $f20, $f20, $f20                          \n\t"
    "xor        $f22, $f22, $f22                          \n\t"
    "xor        $f16, $f16, $f16                          \n\t"
    "xor        $f18, $f18, $f18                          \n\t"
    WELS_SAD_BGD_SQDIFF_16x1_MMI($f28, $f30, $f24, $f26, $f20, $f22, $f16,
                                 $f18, $15, %[ref_data], %[iPicStride])
    WELS_SAD_BGD_SQDIFF_16x1_MMI($f28, $f30, $f24, $f26, $f20, $f22, $f16,
                                 $f18, $15, %[ref_data], %[iPicStride])
    WELS_SAD_BGD_SQDIFF_16x1_MMI($f28, $f30, $f24, $f26, $f20, $f22, $f16,
                                 $f18, $15, %[ref_data], %[iPicStride])
    WELS_SAD_BGD_SQDIFF_16x1_MMI($f28, $f30, $f24, $f26, $f20, $f22, $f16,
                                 $f18, $15, %[ref_data], %[iPicStride])
    WELS_SAD_BGD_SQDIFF_16x1_MMI($f28, $f30, $f24, $f26, $f20, $f22, $f16,
                                 $f18, $15, %[ref_data], %[iPicStride])
    WELS_SAD_BGD_SQDIFF_16x1_MMI($f28, $f30, $f24, $f26, $f20, $f22, $f16,
                                 $f18, $15, %[ref_data], %[iPicStride])
    WELS_SAD_BGD_SQDIFF_16x1_MMI($f28, $f30, $f24, $f26, $f20, $f22, $f16,
                                 $f18, $15, %[ref_data], %[iPicStride])
    WELS_SAD_BGD_SQDIFF_16x1_MMI($f28, $f30, $f24, $f26, $f20, $f22, $f16,
                                 $f18, $15, %[ref_data], %[iPicStride])

    "dmfc1      $8, $f28                                  \n\t"
    "sw         $8, 0x0(%[psad8x8])                       \n\t"
    "dmfc1      $8, $f30                                  \n\t"
    "sw         $8, 0x4(%[psad8x8])                       \n\t"
    PTR_ADDIU  "%[psad8x8], %[psad8x8], 0x8               \n\t"

    "paddw      $f4, $f28, $f30                           \n\t"
    "dmfc1      $12, $f4                                  \n\t"
    PTR_ADDU   "$14, $14,  $12                            \n\t"

    "paddw      $f4, $f24, $f26                           \n\t"
    "dmfc1      $8, $f4                                   \n\t"
    "sw         $8, 0x0(%[psum16x16])                     \n\t"

    "punpckhwd  $f4, $f24, $f26                           \n\t"
    "punpcklwd  $f6, $f24, $f26                           \n\t"
    "psubw      $f6, $f6, $f4                             \n\t"
    "dmfc1      $8, $f6                                   \n\t"
    PTR_S      "$8, 0x0(%[p_sd8x8])                       \n\t"
    PTR_ADDIU  "%[p_sd8x8], %[p_sd8x8], 0x8               \n\t"

    "dli        $8, 0x1                                   \n\t"
    "dmtc1      $8, $f8                                   \n\t"
    "dli        $8, 0x8                                   \n\t"
    "dmtc1      $8, $f10                                  \n\t"
    WELS_MAX_REG_MMI($f20, $f22, $f8, $f10)

    "dmfc1      $8, $f20                                  \n\t"
    "sb         $8, 0x0(%[p_mad8x8])                      \n\t"
    "dmfc1      $8, $f22                                  \n\t"
    "sb         $8, 0x1(%[p_mad8x8])                      \n\t"
    PTR_ADDIU  "%[p_mad8x8], %[p_mad8x8], 0x2             \n\t"

    "xor        $f20, $f20, $f20                          \n\t"
    "xor        $f22, $f22, $f22                          \n\t"
    "punpckhwd  $f28, $f20, $f28                          \n\t"
    "xor        $f24, $f24, $f24                          \n\t"
    "xor        $f26, $f26, $f26                          \n\t"
    "punpckhwd  $f30, $f20, $f30                          \n\t"
    WELS_SAD_BGD_SQDIFF_16x1_MMI($f28, $f30, $f24, $f26, $f20, $f22, $f16,
                                 $f18, $15, %[ref_data], %[iPicStride])
    WELS_SAD_BGD_SQDIFF_16x1_MMI($f28, $f30, $f24, $f26, $f20, $f22, $f16,
                                 $f18, $15, %[ref_data], %[iPicStride])
    WELS_SAD_BGD_SQDIFF_16x1_MMI($f28, $f30, $f24, $f26, $f20, $f22, $f16,
                                 $f18, $15, %[ref_data], %[iPicStride])
    WELS_SAD_BGD_SQDIFF_16x1_MMI($f28, $f30, $f24, $f26, $f20, $f22, $f16,
                                 $f18, $15, %[ref_data], %[iPicStride])
    WELS_SAD_BGD_SQDIFF_16x1_MMI($f28, $f30, $f24, $f26, $f20, $f22, $f16,
                                 $f18, $15, %[ref_data], %[iPicStride])
    WELS_SAD_BGD_SQDIFF_16x1_MMI($f28, $f30, $f24, $f26, $f20, $f22, $f16,
                                 $f18, $15, %[ref_data], %[iPicStride])
    WELS_SAD_BGD_SQDIFF_16x1_MMI($f28, $f30, $f24, $f26, $f20, $f22, $f16,
                                 $f18, $15, %[ref_data], %[iPicStride])
    WELS_SAD_BGD_SQDIFF_16x1_MMI($f28, $f30, $f24, $f26, $f20, $f22, $f16,
                                 $f18, $15, %[ref_data], %[iPicStride])

    "dmfc1      $8, $f28                                  \n\t"
    "sw         $8, 0x0(%[psad8x8])                       \n\t"
    "dmfc1      $8, $f30                                  \n\t"
    "sw         $8, 0x4(%[psad8x8])                       \n\t"
    PTR_ADDIU  "%[psad8x8], %[psad8x8], 0x8               \n\t"

    "paddw      $f4, $f28, $f30                           \n\t"
    "dmfc1      $12, $f4                                  \n\t"
    PTR_ADDU   "$14, $14, $12                             \n\t"

    "paddw      $f4, $f24, $f26                           \n\t"
    "dmfc1      $8, $f4                                   \n\t"
    "lw         $12, 0x0(%[psum16x16])                    \n\t"
    PTR_ADDU   "$8, $8, $12                               \n\t"
    "sw         $8, 0x0(%[psum16x16])                     \n\t"
    "xor        $f8, $f8, $f8                             \n\t"
    PTR_ADDIU  "%[psum16x16], %[psum16x16], 0x4           \n\t"

    "punpckhwd  $f30, $f30, $f8                           \n\t"
    "punpckhwd  $f28, $f28, $f8                           \n\t"
    "paddw      $f8, $f28, $f30                           \n\t"
    "dmfc1      $8, $f8                                   \n\t"
    "sw         $8, 0x0(%[psqsum16x16])                   \n\t"
    PTR_ADDIU  "%[psqsum16x16], %[psqsum16x16], 0x4       \n\t"

    "punpckhwd  $f4, $f24, $f26                           \n\t"
    "punpcklwd  $f6, $f24, $f26                           \n\t"
    "psubw      $f6, $f6, $f4                             \n\t"
    "dmfc1      $8, $f6                                   \n\t"
    PTR_S      "$8, 0x0(%[p_sd8x8])                       \n\t"
    PTR_ADDIU  "%[p_sd8x8], %[p_sd8x8], 0x8               \n\t"

    "dli        $8, 0x1                                   \n\t"
    "dmtc1      $8, $f8                                   \n\t"
    "dli        $8, 0x8                                   \n\t"
    "dmtc1      $8, $f10                                  \n\t"
    WELS_MAX_REG_MMI($f20, $f22, $f8, $f10)

    "dmfc1      $8, $f20                                  \n\t"
    "sb         $8, 0x0(%[p_mad8x8])                      \n\t"
    "dmfc1      $8, $f22                                  \n\t"
    "sb         $8, 0x1(%[p_mad8x8])                      \n\t"
    PTR_ADDIU  "%[p_mad8x8], %[p_mad8x8], 0x2             \n\t"

    "paddw      $f20, $f16, $f18                          \n\t"
	  "punpcklwd  $f16, $f20, $f20                          \n\t"
	  "punpckhwd  $f18, $f20, $f20                          \n\t"
    "paddw      $f16, $f16, $f18                          \n\t"
    "dmfc1      $8, $f16                                  \n\t"
    "sw         $8, 0x0(%[psqdiff16x16])                  \n\t"
    PTR_ADDIU  "%[psqdiff16x16], %[psqdiff16x16], 0x4     \n\t"

    PTR_SUBU   "$15, $15, $13                             \n\t"
    PTR_SUBU   "%[ref_data], %[ref_data], $13             \n\t"
    PTR_ADDIU  "$15, $15, 0x10                            \n\t"
    PTR_ADDIU  "%[ref_data], %[ref_data], 0x10            \n\t"

    PTR_ADDIU  "%[iPicWidth], %[iPicWidth], -0x1          \n\t"
    "bnez       %[iPicWidth], 2b                          \n\t"
    "nop                                                  \n\t"
    "move       %[iPicWidth], $9                          \n\t"
    "move       $15, $10                                  \n\t"
    "move       %[ref_data], $11                          \n\t"
    PTR_ADDU   "$15, $15, $13                             \n\t"
    PTR_ADDU   "%[ref_data], %[ref_data], $13             \n\t"

    PTR_ADDIU  "%[iPicHeight], %[iPicHeight], -0x1        \n\t"
    "bnez       %[iPicHeight], 1b                         \n\t"
    "nop                                                  \n\t"

    "sw         $14, 0x0(%[psadframe])                    \n\t"
    : [ref_data]"+&r"((unsigned char *)ref_data), [iPicWidth]"+&r"((int)iPicWidth),
      [iPicHeight]"+&r"((int)iPicHeight), [psad8x8]"+&r"((int *)psad8x8),
      [psum16x16]"+&r"((int *)psum16x16), [psqsum16x16]"+&r"((int *)psqsum16x16),
	    [psqdiff16x16]"+&r"((int *)psqdiff16x16), [p_sd8x8]"+&r"((int *)p_sd8x8),
      [p_mad8x8]"+&r"((unsigned char *)p_mad8x8)
    : [cur_data]"r"((unsigned char *)cur_data), [iPicStride]"r"((int)iPicStride),
      [psadframe]"r"((int *)psadframe)
    : "memory", "$8", "$9", "$10", "$11", "$12", "$13", "$14", "$15", "$f0", "$f2",
      "$f4", "$f6", "$f8", "$f10", "$f12", "$f14", "$f16", "$f18", "$f20", "$f22",
      "$f24", "$f26", "$f28", "$f30"
  );
  RECOVER_REG;
}

void VAACalcSadVar_mmi(const uint8_t *cur_data, const uint8_t *ref_data,
                       int32_t iPicWidth, int32_t iPicHeight, int32_t iPicStride,
                       int32_t *psadframe, int32_t *psad8x8, int32_t *psum16x16,
                       int32_t *psqsum16x16) {
  BACKUP_REG;
  __asm__ volatile (
    ".set       arch=loongson3a                           \n\t"
    "move       $15, %[cur_data]                          \n\t"
    "dsrl       %[iPicWidth], %[iPicWidth], 0x4           \n\t"
    "dsrl       %[iPicHeight], %[iPicHeight], 0x4         \n\t"
    "dsll       $13, %[iPicStride], 0x4                   \n\t"
    "xor        $f0, $f0, $f0                             \n\t"
    "xor        $f2, $f2, $f2                             \n\t"
    "xor        $f28, $f28, $f28                          \n\t"
    "xor        $f30, $f30, $f30                          \n\t"
    "xor        $14, $14, $14                             \n\t"
    "1:                                                   \n\t"
    "move       $9, %[iPicWidth]                          \n\t"
    "move       $10, $15                                  \n\t"
    "move       $11, %[ref_data]                          \n\t"
    "2:                                                   \n\t"
    "xor        $f24, $f24, $f24                          \n\t"
    "xor        $f26, $f26, $f26                          \n\t"
    "xor        $f20, $f20, $f20                          \n\t"
    "xor        $f22, $f22, $f22                          \n\t"
    "xor        $f16, $f16, $f16                          \n\t"
    "xor        $f18, $f18, $f18                          \n\t"
    WELS_SAD_SUM_SQSUM_16x1_MMI($15, %[ref_data], %[iPicStride])
    WELS_SAD_SUM_SQSUM_16x1_MMI($15, %[ref_data], %[iPicStride])
    WELS_SAD_SUM_SQSUM_16x1_MMI($15, %[ref_data], %[iPicStride])
    WELS_SAD_SUM_SQSUM_16x1_MMI($15, %[ref_data], %[iPicStride])
    WELS_SAD_SUM_SQSUM_16x1_MMI($15, %[ref_data], %[iPicStride])
    WELS_SAD_SUM_SQSUM_16x1_MMI($15, %[ref_data], %[iPicStride])
    WELS_SAD_SUM_SQSUM_16x1_MMI($15, %[ref_data], %[iPicStride])
    WELS_SAD_SUM_SQSUM_16x1_MMI($15, %[ref_data], %[iPicStride])
    "paddw      $f28, $f24, $f28                          \n\t"
    "paddw      $f30, $f26, $f30                          \n\t"
    "dmfc1      $8, $f24                                  \n\t"
    "sw         $8, 0x0(%[psad8x8])                       \n\t"
    "dmfc1      $8, $f26                                  \n\t"
    "sw         $8, 0x4(%[psad8x8])                       \n\t"

    "xor        $f24, $f24, $f24                          \n\t"
    "xor        $f26, $f26, $f26                          \n\t"
    WELS_SAD_SUM_SQSUM_16x1_MMI($15, %[ref_data], %[iPicStride])
    WELS_SAD_SUM_SQSUM_16x1_MMI($15, %[ref_data], %[iPicStride])
    WELS_SAD_SUM_SQSUM_16x1_MMI($15, %[ref_data], %[iPicStride])
    WELS_SAD_SUM_SQSUM_16x1_MMI($15, %[ref_data], %[iPicStride])
    WELS_SAD_SUM_SQSUM_16x1_MMI($15, %[ref_data], %[iPicStride])
    WELS_SAD_SUM_SQSUM_16x1_MMI($15, %[ref_data], %[iPicStride])
    WELS_SAD_SUM_SQSUM_16x1_MMI($15, %[ref_data], %[iPicStride])
    WELS_SAD_SUM_SQSUM_16x1_MMI($15, %[ref_data], %[iPicStride])
    "paddw      $f28, $f24, $f28                          \n\t"
    "paddw      $f30, $f26, $f30                          \n\t"
    "dmfc1      $8, $f24                                  \n\t"
    "sw         $8, 0x8(%[psad8x8])                       \n\t"
    "dmfc1      $8, $f26                                  \n\t"
    "sw         $8, 0xc(%[psad8x8])                       \n\t"
    PTR_ADDIU  "%[psad8x8],   %[psad8x8],   0x10          \n\t"

    "paddw      $f20, $f20, $f22                          \n\t"
    "dmfc1      $8, $f20                                  \n\t"
    "sw         $8, 0x0(%[psum16x16])                     \n\t"
    PTR_ADDIU  "%[psum16x16], %[psum16x16], 0x4           \n\t"

    "paddw      $f20, $f16, $f18                          \n\t"
	  "punpcklwd  $f16, $f20, $f20                          \n\t"
	  "punpckhwd  $f18, $f20, $f20                          \n\t"
    "paddw      $f16, $f16, $f18                          \n\t"
    "dmfc1      $8, $f16                                  \n\t"
    "sw         $8, 0x0(%[psqsum16x16])                   \n\t"
    PTR_ADDIU  "%[psqsum16x16], %[psqsum16x16], 0x4       \n\t"

    PTR_SUBU   "$15, $15, $13                             \n\t"
    PTR_SUBU   "%[ref_data], %[ref_data], $13             \n\t"
    PTR_ADDIU  "$15, $15, 0x10                            \n\t"
    PTR_ADDIU  "%[ref_data], %[ref_data], 0x10            \n\t"

    PTR_ADDIU  "%[iPicWidth], %[iPicWidth], -0x1          \n\t"
    "bnez       %[iPicWidth], 2b                          \n\t"
    "nop                                                  \n\t"
    "move       %[iPicWidth], $9                          \n\t"
    "move       $15, $10                                  \n\t"
    "move       %[ref_data], $11                          \n\t"
    PTR_ADDU   "$15, $15, $13                             \n\t"
    PTR_ADDU   "%[ref_data], %[ref_data], $13             \n\t"

    PTR_ADDIU  "%[iPicHeight], %[iPicHeight], -0x1        \n\t"
    "bnez       %[iPicHeight], 1b                         \n\t"
    "nop                                                  \n\t"

    "paddw      $f28, $f28, $f30                          \n\t"
    "dmfc1      $8, $f28                                  \n\t"
    "sw         $8, 0x0(%[psadframe])                     \n\t"
    : [ref_data]"+&r"((unsigned char *)ref_data), [iPicWidth]"+&r"((int)iPicWidth),
      [iPicHeight]"+&r"((int)iPicHeight), [psum16x16]"+&r"((int *)psum16x16),
      [psqsum16x16]"+&r"((int *)psqsum16x16)
    : [cur_data]"r"((unsigned char *)cur_data), [iPicStride]"r"((int)iPicStride),
      [psadframe]"r"((int *)psadframe), [psad8x8]"r"((int *)psad8x8)
    : "memory", "$8", "$9", "$10", "$11", "$12", "$13", "$14", "$15", "$f0", "$f2",
      "$f4", "$f6", "$f8", "$f10", "$f12", "$f14", "$f16", "$f18", "$f20", "$f22",
      "$f24", "$f26", "$f28", "$f30"
  );
  RECOVER_REG;
}
