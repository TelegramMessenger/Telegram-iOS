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
 * \file    dct_mmi.c
 *
 * \brief   Loongson optimization
 *
 * \date    20/07/2018 Created
 *
 *************************************************************************************
 */
#include <stdint.h>
#include "asmdefs_mmi.h"

#define MMI_Load4x8p(r0, f0, f2, f4, f6, f8, f10, f12, f14, f16, f18) \
  "gslqc1     "#f2", "#f0", 0x0("#r0")        \n\t" \
  "gslqc1     "#f10", "#f8", 0x10("#r0")      \n\t" \
  "gslqc1     "#f18", "#f16", 0x20("#r0")     \n\t" \
  "gslqc1     "#f6", "#f4", 0x30("#r0")       \n\t" \
  MMI_XSawp_DQ(f8, f10, f4, f6, f12, f14)           \
  MMI_XSawp_DQ(f0, f2, f16, f18, f4, f6)

#define MMI_SumSubDiv2(f0, f2, f4, f6, f8, f10, f12, f14, f16) \
  "mov.d      "#f8", "#f4"                    \n\t" \
  "mov.d      "#f10", "#f6"                   \n\t" \
  "psrah      "#f4", "#f4", "#f16"            \n\t" \
  "psrah      "#f6", "#f6", "#f16"            \n\t" \
  "psrah      "#f12", "#f0", "#f16"           \n\t" \
  "psrah      "#f14", "#f2", "#f16"           \n\t" \
  "paddh      "#f0", "#f0", "#f4"             \n\t" \
  "paddh      "#f2", "#f2", "#f6"             \n\t" \
  "psubh      "#f12", "#f12", "#f8"           \n\t" \
  "psubh      "#f14", "#f14", "#f10"          \n\t"

#define MMI_IDCT(f0, f2, f4, f6, f8, f10, f12, f14, f16, f18, f20, f22, f24, f26, f28) \
  MMI_SumSub(f24, f26, f4, f6, f20, f22)                        \
  MMI_SumSubDiv2(f0, f2, f8, f10, f16, f18, f12, f14, f28)      \
  MMI_SumSub(f4, f6, f0, f2, f16, f18)                          \
  MMI_SumSub(f24, f26, f12, f14, f16, f18)

#define MMI_StoreDiff8p_6(f0, f2, f4, f6, f8, f12, r0, r1, f14) \
  "paddh      "#f0", "#f0", "#f8"             \n\t" \
  "paddh      "#f2", "#f2", "#f8"             \n\t" \
  "psrah      "#f0", "#f0", "#f14"            \n\t" \
  "psrah      "#f2", "#f2", "#f14"            \n\t" \
  "gsldlc1    "#f4", 0x7("#r1")               \n\t" \
  "gsldrc1    "#f4", 0x0("#r1")               \n\t" \
  "punpckhbh  "#f6", "#f4", "#f12"            \n\t" \
  "punpcklbh  "#f4", "#f4", "#f12"            \n\t" \
  "paddsh     "#f4", "#f4", "#f0"             \n\t" \
  "paddsh     "#f6", "#f6", "#f2"             \n\t" \
  "packushb   "#f4", "#f4", "#f6"             \n\t" \
  "gssdlc1    "#f4", 0x7("#r0")               \n\t" \
  "gssdrc1    "#f4", 0x0("#r0")               \n\t"

#define MMI_StoreDiff8p_5(f0, f2, f4, f6, f8, r0, r1, offset) \
  "gsldlc1    "#f4", "#offset"+0x7("#r1")     \n\t" \
  "gsldrc1    "#f4", "#offset"+0x0("#r1")     \n\t" \
  "punpckhbh  "#f6", "#f4", "#f8"             \n\t" \
  "punpcklbh  "#f4", "#f4", "#f8"             \n\t" \
  "paddsh     "#f4", "#f4", "#f0"             \n\t" \
  "paddsh     "#f6", "#f6", "#f2"             \n\t" \
  "packushb   "#f4", "#f4", "#f6"             \n\t" \
  "gssdlc1    "#f4", "#offset"+0x7("#r0")     \n\t" \
  "gssdrc1    "#f4", "#offset"+0x0("#r0")     \n\t"

#define MMI_Load8DC(f0, f2, f4, f6, f8, f10, f12, f14, f16, r0, offset, f20) \
  "gslqc1     "#f2", "#f0", "#offset"+0x0("#r0") \n\t" \
  "paddh      "#f0", "#f0", "#f16"               \n\t" \
  "paddh      "#f2", "#f2", "#f16"               \n\t" \
  "psrah      "#f0", "#f0", "#f20"               \n\t" \
  "psrah      "#f2", "#f2", "#f20"               \n\t" \
  "punpckhhw  "#f4", "#f0", "#f0"                \n\t" \
  "punpckhwd  "#f6", "#f4", "#f4"                \n\t" \
  "punpcklwd  "#f4", "#f4", "#f4"                \n\t" \
  "punpcklhw  "#f8", "#f2", "#f2"                \n\t" \
  "punpckhwd  "#f10", "#f8", "#f8"               \n\t" \
  "punpcklwd  "#f8", "#f8", "#f8"                \n\t" \
  "punpckhhw  "#f12", "#f2", "#f2"               \n\t" \
  "punpckhwd  "#f14", "#f12", "#f12"             \n\t" \
  "punpcklwd  "#f12", "#f12", "#f12"             \n\t" \
  "punpcklhw  "#f0", "#f0", "#f0"                \n\t" \
  "punpckhwd  "#f2", "#f0", "#f0"                \n\t" \
  "punpcklwd  "#f0", "#f0", "#f0"                \n\t"

#define MMI_StoreDiff4x8p(f0, f2, f4, f6, f8, f10, f12, r0, r1, r2, r3) \
  MMI_StoreDiff8p_5(f0, f2, f8, f10, f12, r0, r1, 0x0)         \
  MMI_StoreDiff8p_5(f4, f6, f8, f10, f12, r0, r1, 0x8)         \
  PTR_ADDU   ""#r0", "#r0", "#r2"                        \n\t" \
  PTR_ADDU   ""#r1", "#r1", "#r3"                        \n\t" \
  MMI_StoreDiff8p_5(f0, f2, f8, f10, f12, r0, r1, 0x0)         \
  MMI_StoreDiff8p_5(f4, f6, f8, f10, f12, r0, r1, 0x8)

#define MMI_Load4Col(f0, f2, f4, f6, f8, r0, offset) \
  "lh         $8, "#offset"("#r0")        \n\t" \
  "dmtc1      $8, "#f0"                   \n\t" \
  "lh         $8, "#offset"+0x20("#r0")   \n\t" \
  "dmtc1      $8, "#f4"                   \n\t" \
  "punpcklwd  "#f0", "#f0", "#f4"         \n\t" \
  "lh         $8, "#offset"+0x80("#r0")   \n\t" \
  "dmtc1      $8, "#f6"                   \n\t" \
  "lh         $8, "#offset"+0xa0("#r0")   \n\t" \
  "dmtc1      $8, "#f8"                   \n\t" \
  "punpcklwd  "#f2", "#f6", "#f8"         \n\t"

#define MMI_SumSubD(f0, f2, f4, f6, f8, f10) \
  "mov.d      "#f8", "#f4"                \n\t" \
  "mov.d      "#f10", "#f6"               \n\t" \
  "paddw      "#f4", "#f4", "#f0"         \n\t" \
  "paddw      "#f6", "#f6", "#f2"         \n\t" \
  "psubw      "#f0", "#f0", "#f8"         \n\t" \
  "psubw      "#f2", "#f2", "#f10"        \n\t"

#define WELS_DD1(f0, f2, f_val_31) \
  "pcmpeqh    "#f0", "#f0", "#f0"         \n\t" \
  "pcmpeqh    "#f2", "#f2", "#f2"         \n\t" \
  "psrlw      "#f0", "#f0", "#f_val_31"   \n\t" \
  "psrlw      "#f2", "#f2", "#f_val_31"   \n\t"

#define MMI_SumSubDiv2D(f0, f2, f4, f6, f8, f10, f12, f14, f_val_1) \
  "paddw      "#f0", "#f0", "#f4"         \n\t" \
  "paddw      "#f2", "#f2", "#f6"         \n\t" \
  "paddw      "#f0", "#f0", "#f8"         \n\t" \
  "paddw      "#f2", "#f2", "#f10"        \n\t" \
  "psraw      "#f0", "#f0", "#f_val_1"    \n\t" \
  "psraw      "#f2", "#f2", "#f_val_1"    \n\t" \
  "mov.d      "#f12", "#f0"               \n\t" \
  "mov.d      "#f14", "#f2"               \n\t" \
  "psubw      "#f12", "#f12", "#f4"       \n\t" \
  "psubw      "#f14", "#f14", "#f6"       \n\t"

#define MMI_Trans4x4W(f0, f2, f4, f6, f8, f10, f12, f14, f16, f18) \
  MMI_XSawp_WD(f0, f2, f4, f6, f16, f18)  \
  MMI_XSawp_WD(f8, f10, f12, f14, f4, f6) \
  MMI_XSawp_DQ(f0, f2, f8, f10, f12, f14) \
  MMI_XSawp_DQ(f16, f18, f4, f6, f8, f10)

#define MMI_SumSubMul2(f0, f2, f4, f6, f8, f10) \
  "mov.d      "#f8", "#f0"                    \n\t" \
  "mov.d      "#f10", "#f2"                   \n\t" \
  "paddh      "#f0", "#f0", "#f0"             \n\t" \
  "paddh      "#f2", "#f2", "#f2"             \n\t" \
  "paddh      "#f0", "#f0", "#f4"             \n\t" \
  "paddh      "#f2", "#f2", "#f6"             \n\t" \
  "psubh      "#f8", "#f8", "#f4"             \n\t" \
  "psubh      "#f10", "#f10", "#f6"           \n\t" \
  "psubh      "#f8", "#f8", "#f4"             \n\t" \
  "psubh      "#f10", "#f10", "#f6"           \n\t"

#define MMI_DCT(f0, f2, f4, f6, f8, f10, f12, f14, f16, f18, f20, f22) \
  MMI_SumSub(f20, f22, f8, f10, f16, f18)   \
  MMI_SumSub(f0, f2, f4, f6, f16, f18)      \
  MMI_SumSub(f8, f10, f4, f6, f16, f18)     \
  MMI_SumSubMul2(f20, f22, f0, f2, f12, f14)

#define MMI_Store4x8p(r0, f0, f2, f4, f6, f8, f10, f12, f14, f16, f18) \
  MMI_XSawp_DQ(f0, f2, f4, f6, f16, f18)            \
  MMI_XSawp_DQ(f8, f10, f12, f14, f4, f6)           \
  "gssqc1     "#f2", "#f0", 0x0("#r0")        \n\t" \
  "gssqc1     "#f10", "#f8", 0x10("#r0")      \n\t" \
  "gssqc1     "#f18", "#f16", 0x20("#r0")     \n\t" \
  "gssqc1     "#f6", "#f4", 0x30("#r0")       \n\t"

#define MMI_LoadDiff4P_SINGLE(f0, f2, r0, r1, f4) \
  "gsldlc1    "#f0", 0x7("#r0")               \n\t" \
  "gsldlc1    "#f2", 0x7("#r1")               \n\t" \
  "gsldrc1    "#f0", 0x0("#r0")               \n\t" \
  "gsldrc1    "#f2", 0x0("#r1")               \n\t" \
  "punpcklbh  "#f0", "#f0", "#f4"             \n\t" \
  "punpcklbh  "#f2", "#f2", "#f4"             \n\t" \
  "psubh      "#f0", "#f0", "#f2"             \n\t"

#define MMI_LoadDiff4x4P_SINGLE(f0, f2, f4, f6, r0, r1, r2, r3, f8, f10) \
  MMI_LoadDiff4P_SINGLE(f0, f8, r0, r2, f10)        \
  PTR_ADDU   ""#r0", "#r0", "#r1"             \n\t" \
  PTR_ADDU   ""#r2", "#r2", "#r3"             \n\t" \
  MMI_LoadDiff4P_SINGLE(f2, f8, r0, r2, f10)        \
  PTR_ADDU   ""#r0", "#r0", "#r1"             \n\t" \
  PTR_ADDU   ""#r2", "#r2", "#r3"             \n\t" \
  MMI_LoadDiff4P_SINGLE(f4, f8, r0, r2, f10)        \
  PTR_ADDU   ""#r0", "#r0", "#r1"             \n\t" \
  PTR_ADDU   ""#r2", "#r2", "#r3"             \n\t" \
  MMI_LoadDiff4P_SINGLE(f6, f8, r0, r2, f10)

#define MMI_DCT_SINGLE(f0, f2, f4, f6, f8, f10, f12) \
  MMI_SumSub_SINGLE(f6, f0, f10)     \
  MMI_SumSub_SINGLE(f4, f2, f10)     \
  MMI_SumSub_SINGLE(f4, f6, f10)     \
  MMI_SumSubMul2_SINGLE(f0, f2, f8, f12)

void WelsIDctT4Rec_mmi(uint8_t* pRec, int32_t iStride, uint8_t* pPred,
                       int32_t iPredStride, int16_t* pDct) {
  __asm__ volatile (
    ".set       arch=loongson3a                    \n\t"
    "gsldlc1    $f0, 0x7(%[pDct])                  \n\t"
    "gsldrc1    $f0, 0x0(%[pDct])                  \n\t"
    "gsldlc1    $f2, 0xF(%[pDct])                  \n\t"
    "gsldrc1    $f2, 0x8(%[pDct])                  \n\t"
    "gsldlc1    $f4, 0x17(%[pDct])                 \n\t"
    "gsldrc1    $f4, 0x10(%[pDct])                 \n\t"
    "gsldlc1    $f6, 0x1F(%[pDct])                 \n\t"
    "gsldrc1    $f6, 0x18(%[pDct])                 \n\t"

    "dli        $8, 0x1                            \n\t"
    "dmtc1      $8, $f16                           \n\t"
    "dli        $8, 0x6                            \n\t"
    "dmtc1      $8, $f18                           \n\t"

    MMI_Trans4x4H_SINGLE($f0, $f2, $f4, $f6, $f8)
    MMI_IDCT_SINGLE($f2, $f4, $f6, $f8, $f0, $f12, $f16)
    MMI_Trans4x4H_SINGLE($f2, $f6, $f0, $f8, $f4)
    MMI_IDCT_SINGLE($f6, $f0, $f8, $f4, $f2, $f12, $f16)

    "xor        $f14, $f14, $f14                   \n\t"
    "dli        $8, 0x0020                         \n\t"
    "dmtc1      $8, $f12                           \n\t"
    "punpcklhw  $f12, $f12, $f12                   \n\t"
    "punpcklwd  $f12, $f12, $f12                   \n\t"

    MMI_StoreDiff4P_SINGLE($f6, $f0, $f12, $f14, %[pRec], %[pPred], $f18)
    PTR_ADDU   "%[pRec], %[pRec], %[iStride]       \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[iPredStride] \n\t"
    MMI_StoreDiff4P_SINGLE($f8, $f0, $f12, $f14, %[pRec], %[pPred], $f18)
    PTR_ADDU   "%[pRec], %[pRec], %[iStride]       \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[iPredStride] \n\t"
    MMI_StoreDiff4P_SINGLE($f2, $f0, $f12, $f14, %[pRec], %[pPred], $f18)
    PTR_ADDU   "%[pRec], %[pRec], %[iStride]       \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[iPredStride] \n\t"
    MMI_StoreDiff4P_SINGLE($f4, $f0, $f12, $f14, %[pRec], %[pPred], $f18)
    : [pRec]"+&r"((uint8_t *)pRec), [pPred]"+&r"((uint8_t *)pPred)
    : [iStride]"r"((int)iStride), [iPredStride]"r"((int)iPredStride),
      [pDct]"r"((short *)pDct)
    : "memory", "$8", "$f0", "$f2", "$f4", "$f6", "$f8", "$f10", "$f12",
      "$f14", "$f16", "$f18"
  );
}

void WelsIDctFourT4Rec_mmi(uint8_t* pRec, int32_t iStride, uint8_t* pPred,
                           int32_t iPredStride, int16_t* pDct) {
  BACKUP_REG;
  __asm__ volatile (
    ".set       arch=loongson3a                    \n\t"
    MMI_Load4x8p(%[pDct], $f0, $f2, $f4, $f6, $f16, $f18, $f8, $f10, $f20, $f22)

    MMI_TransTwo4x4H($f0, $f2, $f4, $f6, $f16, $f18, $f8, $f10, $f12, $f14)
    "dli        $8, 0x1                            \n\t"
    "dmtc1      $8, $f30                           \n\t"
    MMI_IDCT($f4, $f6, $f8, $f10, $f12, $f14, $f16, $f18, $f20, $f22, $f24, $f26,
             $f0, $f2, $f30)
    MMI_TransTwo4x4H($f4, $f6, $f16, $f18, $f0, $f2, $f8, $f10, $f12, $f14)
    MMI_IDCT($f16, $f18, $f8, $f10, $f12, $f14, $f0, $f2, $f20, $f22, $f24, $f26,
             $f4, $f6, $f30)

    "xor        $f28, $f28, $f28                   \n\t"
    "dli        $8, 0x6                            \n\t"
    "dmtc1      $8, $f26                           \n\t"
    "dli        $8, 0x0020                         \n\t"
    "dmtc1      $8, $f24                           \n\t"
    "punpcklhw  $f24, $f24, $f24                   \n\t"
    "punpcklwd  $f24, $f24, $f24                   \n\t"

    MMI_StoreDiff8p_6($f16, $f18, $f20, $f22, $f24, $f28, %[pRec], %[pPred], $f26)
    PTR_ADDU   "%[pRec], %[pRec], %[iStride]       \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[iPredStride] \n\t"
    MMI_StoreDiff8p_6($f0, $f2, $f20, $f22, $f24, $f28, %[pRec], %[pPred], $f26)
    PTR_ADDU   "%[pRec], %[pRec], %[iStride]       \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[iPredStride] \n\t"
    MMI_StoreDiff8p_6($f4, $f6, $f20, $f22, $f24, $f28, %[pRec], %[pPred], $f26)
    PTR_ADDU   "%[pRec], %[pRec], %[iStride]       \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[iPredStride] \n\t"
    MMI_StoreDiff8p_6($f8, $f10, $f20, $f22, $f24, $f28, %[pRec], %[pPred], $f26)

    PTR_ADDIU  "%[pDct], %[pDct], 0x40             \n\t"
    PTR_ADDU   "%[pRec], %[pRec], %[iStride]       \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[iPredStride] \n\t"
    MMI_Load4x8p(%[pDct], $f0, $f2, $f4, $f6, $f16, $f18, $f8, $f10, $f20, $f22)

    MMI_TransTwo4x4H($f0, $f2, $f4, $f6, $f16, $f18, $f8, $f10, $f12, $f14)
    MMI_IDCT($f4, $f6, $f8, $f10, $f12, $f14, $f16, $f18, $f20, $f22, $f24, $f26,
             $f0, $f2, $f30)
    MMI_TransTwo4x4H($f4, $f6, $f16, $f18, $f0, $f2, $f8, $f10, $f12, $f14)
    MMI_IDCT($f16, $f18, $f8, $f10, $f12, $f14, $f0, $f2, $f20, $f22, $f24, $f26,
             $f4, $f6, $f30)

    "dli        $8, 0x6                            \n\t"
    "dmtc1      $8, $f26                           \n\t"
    "dli        $8, 0x0020                         \n\t"
    "dmtc1      $8, $f24                           \n\t"
    "punpcklhw  $f24, $f24, $f24                   \n\t"
    "punpcklwd  $f24, $f24, $f24                   \n\t"

    MMI_StoreDiff8p_6($f16, $f18, $f20, $f22, $f24, $f28, %[pRec], %[pPred], $f26)
    PTR_ADDU   "%[pRec], %[pRec], %[iStride]       \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[iPredStride] \n\t"
    MMI_StoreDiff8p_6($f0, $f2, $f20, $f22, $f24, $f28, %[pRec], %[pPred], $f26)
    PTR_ADDU   "%[pRec], %[pRec], %[iStride]       \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[iPredStride] \n\t"
    MMI_StoreDiff8p_6($f4, $f6, $f20, $f22, $f24, $f28, %[pRec], %[pPred], $f26)
    PTR_ADDU   "%[pRec], %[pRec], %[iStride]       \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[iPredStride] \n\t"
    MMI_StoreDiff8p_6($f8, $f10, $f20, $f22, $f24, $f28, %[pRec], %[pPred], $f26)
    : [pRec]"+&r"((uint8_t *)pRec), [pPred]"+&r"((uint8_t *)pPred),
      [pDct]"+&r"((short *)pDct)
    : [iStride]"r"((int)iStride), [iPredStride]"r"((int)iPredStride)
    : "memory", "$8", "$f0", "$f2", "$f4", "$f6", "$f8", "$f10", "$f12",
      "$f14", "$f16", "$f18", "$f20", "$f22", "$f24", "$f26", "$f28", "$f30"
  );
  RECOVER_REG;
}

void WelsIDctRecI16x16Dc_mmi(uint8_t* pRec, int32_t iStride, uint8_t* pPred,
                             int32_t iPredStride, int16_t* pDct) {
  BACKUP_REG;
  __asm__ volatile (
    ".set       arch=loongson3a                    \n\t"
    "xor        $f28, $f28, $f28                   \n\t"
    "dli        $8, 0x0020                         \n\t"
    "dmtc1      $8, $f24                           \n\t"
    "punpcklhw  $f24, $f24, $f24                   \n\t"
    "punpcklwd  $f24, $f24, $f24                   \n\t"
    "dli        $8, 0x6                            \n\t"
    "dmtc1      $8, $f30                           \n\t"

    MMI_Load8DC($f0, $f2, $f4, $f6, $f8, $f10, $f12, $f14, $f24,
                %[pDct], 0x0, $f30)

    MMI_StoreDiff4x8p($f0, $f2, $f4, $f6, $f20, $f22, $f28, %[pRec],
                      %[pPred], %[iStride], %[iPredStride])

    PTR_ADDU   "%[pRec], %[pRec], %[iStride]       \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[iPredStride] \n\t"
    MMI_StoreDiff4x8p($f0, $f2, $f4, $f6, $f20, $f22, $f28, %[pRec],
                      %[pPred], %[iStride], %[iPredStride])

    PTR_ADDU   "%[pRec], %[pRec], %[iStride]       \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[iPredStride] \n\t"
    MMI_StoreDiff4x8p($f8, $f10, $f12, $f14, $f20, $f22, $f28, %[pRec],
                      %[pPred], %[iStride], %[iPredStride])

    PTR_ADDU   "%[pRec], %[pRec], %[iStride]       \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[iPredStride] \n\t"
    MMI_StoreDiff4x8p($f8, $f10, $f12, $f14, $f20, $f22, $f28, %[pRec],
                      %[pPred], %[iStride], %[iPredStride])

    MMI_Load8DC($f0, $f2, $f4, $f6, $f8, $f10, $f12, $f14, $f24, %[pDct], 0x10, $f30)
    PTR_ADDU   "%[pRec], %[pRec], %[iStride]       \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[iPredStride] \n\t"
    MMI_StoreDiff4x8p($f0, $f2, $f4, $f6, $f20, $f22, $f28, %[pRec],
                      %[pPred], %[iStride], %[iPredStride])

    PTR_ADDU   "%[pRec], %[pRec], %[iStride]       \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[iPredStride] \n\t"
    MMI_StoreDiff4x8p($f0, $f2, $f4, $f6, $f20, $f22, $f28, %[pRec],
                      %[pPred], %[iStride], %[iPredStride])

    PTR_ADDU   "%[pRec], %[pRec], %[iStride]       \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[iPredStride] \n\t"
    MMI_StoreDiff4x8p($f8, $f10, $f12, $f14, $f20, $f22, $f28, %[pRec],
                      %[pPred], %[iStride], %[iPredStride])

    PTR_ADDU   "%[pRec], %[pRec], %[iStride]       \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[iPredStride] \n\t"
    MMI_StoreDiff4x8p($f8, $f10, $f12, $f14, $f20, $f22, $f28, %[pRec],
                      %[pPred], %[iStride], %[iPredStride])
    : [pRec]"+&r"((uint8_t *)pRec), [pPred]"+&r"((uint8_t *)pPred),
      [pDct]"+&r"((short *)pDct)
    : [iStride]"r"((int)iStride), [iPredStride]"r"((int)iPredStride)
    : "memory", "$8", "$f0", "$f2", "$f4", "$f6", "$f8", "$f10", "$f12",
      "$f14", "$f20", "$f22", "$f24", "$f26", "$f28", "$f30"
  );
  RECOVER_REG;
}

void WelsHadamardT4Dc_mmi( int16_t *luma_dc, int16_t *pDct) {
  BACKUP_REG;
  __asm__ volatile (
    ".set       arch=loongson3a                 \n\t"
    MMI_Load4Col($f4, $f6, $f20, $f24, $f0, %[pDct], 0x0)
    MMI_Load4Col($f8, $f10, $f20, $f24, $f0, %[pDct], 0x40)
    MMI_Load4Col($f12, $f14, $f20, $f24, $f0, %[pDct], 0x100)
    MMI_Load4Col($f16, $f18, $f20, $f24, $f0, %[pDct], 0x140)

    MMI_SumSubD($f4, $f6, $f8, $f10, $f28, $f30)
    MMI_SumSubD($f12, $f14, $f16, $f18, $f28, $f30)
    MMI_SumSubD($f8, $f10, $f16, $f18, $f28, $f30)
    MMI_SumSubD($f4, $f6, $f12, $f14, $f28, $f30)

    MMI_Trans4x4W($f16, $f18, $f8, $f10, $f4, $f6, $f12, $f14, $f20, $f22)

    MMI_SumSubD($f16, $f18, $f12, $f14, $f28, $f30)
    MMI_SumSubD($f20, $f22, $f4, $f6, $f28, $f30)

    "dli        $8, 0x1F                        \n\t"
    "dmtc1      $8, $f30                        \n\t"

    WELS_DD1($f24, $f26, $f30)

    "dli        $8, 0x1                         \n\t"
    "dmtc1      $8, $f30                        \n\t"

    MMI_SumSubDiv2D($f12, $f14, $f4, $f6, $f24, $f26, $f0, $f2, $f30)
    MMI_SumSubDiv2D($f16, $f18, $f20, $f22, $f24, $f26, $f4, $f6, $f30)
    MMI_Trans4x4W($f12, $f14, $f0, $f2, $f4, $f6, $f16, $f18, $f8, $f10)

    "packsswh   $f12, $f12, $f14                \n\t"
    "packsswh   $f14, $f16, $f18                \n\t"

    "packsswh   $f8, $f8, $f10                  \n\t"
    "packsswh   $f10, $f4, $f6                  \n\t"
    "gssqc1     $f14, $f12, 0x0(%[luma_dc])     \n\t"
    "gssqc1     $f10, $f8, 0x10(%[luma_dc])     \n\t"
   :
   : [luma_dc]"r"((short *)luma_dc), [pDct]"r"((short *)pDct)
   : "memory", "$8", "$f0", "$f2", "$f4", "$f6", "$f8", "$f10", "$f12",
     "$f14", "$f16", "$f18", "$f20", "$f22", "$f24", "$f26", "$f28", "$f30"
  );
  RECOVER_REG;
}

void WelsDctT4_mmi(int16_t *pDct, uint8_t *pix1, int32_t i_pix1,
                   uint8_t *pix2, int32_t i_pix2 ) {
  __asm__ volatile (
    ".set       arch=loongson3a                 \n\t"
    "xor        $f14, $f14, $f14                \n\t"
    "dli        $8, 0x1                         \n\t"
    "dmtc1      $8, $f16                        \n\t"

    MMI_LoadDiff4x4P_SINGLE($f2, $f4, $f6, $f8, %[pix1], %[i_pix1],
                            %[pix2], %[i_pix2], $f0, $f14)

    MMI_DCT_SINGLE($f2, $f4, $f6, $f8, $f10, $f12, $f16)
    MMI_Trans4x4H_SINGLE($f6, $f2, $f8, $f10, $f4)

    MMI_DCT_SINGLE($f6, $f10, $f4, $f8, $f2, $f12, $f16)
    MMI_Trans4x4H_SINGLE($f4, $f6, $f8, $f2, $f10)

    "gssdlc1    $f4, 0x7(%[pDct])               \n\t"
    "gssdlc1    $f2, 0xF(%[pDct])               \n\t"
    "gssdlc1    $f10, 0x17(%[pDct])             \n\t"
    "gssdlc1    $f8, 0x1F(%[pDct])              \n\t"
    "gssdrc1    $f4, 0x0(%[pDct])               \n\t"
    "gssdrc1    $f2, 0x8(%[pDct])               \n\t"
    "gssdrc1    $f10, 0x10(%[pDct])             \n\t"
    "gssdrc1    $f8, 0x18(%[pDct])              \n\t"
   : [pDct]"+&r"((short *)pDct), [pix1]"+&r"(pix1), [pix2]"+&r"(pix2)
   : [i_pix1]"r"(i_pix1), [i_pix2]"r"(i_pix2)
   : "memory", "$8", "$f0", "$f2", "$f4", "$f6", "$f8", "$f10", "$f12",
     "$f14", "$f16"
  );
}

void WelsDctFourT4_mmi(int16_t *pDct, uint8_t *pix1, int32_t i_pix1,
                       uint8_t *pix2, int32_t i_pix2 ) {
  BACKUP_REG;
  __asm__ volatile (
    ".set       arch=loongson3a                 \n\t"
    "xor        $f28, $f28, $f28                \n\t"
    MMI_LoadDiff8P($f0, $f2, $f24, $f26, $f28, %[pix1], %[pix2])
    PTR_ADDU   "%[pix1], %[pix1], %[i_pix1]     \n\t"
    PTR_ADDU   "%[pix2], %[pix2], %[i_pix2]     \n\t"
    MMI_LoadDiff8P($f4, $f6, $f24, $f26, $f28, %[pix1], %[pix2])
    PTR_ADDU   "%[pix1], %[pix1], %[i_pix1]     \n\t"
    PTR_ADDU   "%[pix2], %[pix2], %[i_pix2]     \n\t"
    MMI_LoadDiff8P($f8, $f10, $f24, $f26, $f28, %[pix1], %[pix2])
    PTR_ADDU   "%[pix1], %[pix1], %[i_pix1]     \n\t"
    PTR_ADDU   "%[pix2], %[pix2], %[i_pix2]     \n\t"
    MMI_LoadDiff8P($f12, $f14, $f24, $f26, $f28, %[pix1], %[pix2])

    MMI_DCT($f4, $f6, $f8, $f10, $f12, $f14, $f16, $f18, $f20, $f22, $f0, $f2)
    MMI_TransTwo4x4H($f8, $f10, $f0, $f2, $f12, $f14, $f16, $f18, $f4, $f6)
    MMI_DCT($f0, $f2, $f16, $f18, $f4, $f6, $f12, $f14, $f20, $f22, $f8, $f10)
    MMI_TransTwo4x4H($f16, $f18, $f8, $f10, $f4, $f6, $f12, $f14, $f0, $f2)

    MMI_Store4x8p(%[pDct], $f16, $f18, $f8, $f10, $f12, $f14, $f0, $f2, $f20, $f22)
    PTR_ADDU   "%[pix1], %[pix1], %[i_pix1]     \n\t"
    PTR_ADDU   "%[pix2], %[pix2], %[i_pix2]     \n\t"
    MMI_LoadDiff8P($f0, $f2, $f24, $f26, $f28, %[pix1], %[pix2])
    PTR_ADDU   "%[pix1], %[pix1], %[i_pix1]     \n\t"
    PTR_ADDU   "%[pix2], %[pix2], %[i_pix2]     \n\t"
    MMI_LoadDiff8P($f4, $f6, $f24, $f26, $f28, %[pix1], %[pix2])
    PTR_ADDU   "%[pix1], %[pix1], %[i_pix1]     \n\t"
    PTR_ADDU   "%[pix2], %[pix2], %[i_pix2]     \n\t"
    MMI_LoadDiff8P($f8, $f10, $f24, $f26, $f28, %[pix1], %[pix2])
    PTR_ADDU   "%[pix1], %[pix1], %[i_pix1]     \n\t"
    PTR_ADDU   "%[pix2], %[pix2], %[i_pix2]     \n\t"
    MMI_LoadDiff8P($f12, $f14, $f24, $f26, $f28, %[pix1], %[pix2])

    MMI_DCT($f4, $f6, $f8, $f10, $f12, $f14, $f16, $f18, $f20, $f22, $f0, $f2)
    MMI_TransTwo4x4H($f8, $f10, $f0, $f2, $f12, $f14, $f16, $f18, $f4, $f6)
    MMI_DCT($f0, $f2, $f16, $f18, $f4, $f6, $f12, $f14, $f20, $f22, $f8, $f10)
    MMI_TransTwo4x4H($f16, $f18, $f8, $f10, $f4, $f6, $f12, $f14, $f0, $f2)

    PTR_ADDIU  "%[pDct], %[pDct], 0x40          \n\t"
    MMI_Store4x8p(%[pDct], $f16, $f18, $f8, $f10, $f12, $f14, $f0, $f2, $f20, $f22)
   : [pDct]"+&r"((short *)pDct), [pix1]"+&r"(pix1), [pix2]"+&r"(pix2)
   : [i_pix1]"r"(i_pix1), [i_pix2]"r"(i_pix2)
   : "memory", "$8", "$f0", "$f2", "$f4", "$f6", "$f8", "$f10", "$f12",
     "$f14", "$f16", "$f18", "$f20", "$f22", "$f24", "$f26", "$f28"
  );
  RECOVER_REG;
}
