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
 * \date    17/07/2018 Created
 *
 *************************************************************************************
 */
#include <stdint.h>
#include "asmdefs_mmi.h"

#define LOAD_2_LEFT_AND_ADD                                   \
  PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t" \
  "lbu        $9, -0x1(%[pPred])                        \n\t" \
  PTR_ADDU   "$8, $8, $9                                \n\t" \
  PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t" \
  "lbu        $9, -0x1(%[pPred])                        \n\t" \
  PTR_ADDU   "$8, $8, $9                                \n\t"

unsigned char mmi_dc_0x80[16] __attribute__((aligned(16))) = {
  0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,
  0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80};

short mmi_wd_0x02[8] __attribute__((aligned(16))) = {2, 2, 2, 2, 2, 2, 2, 2};
short mmi_plane_inc_minus[8]__attribute__((aligned(16))) = {-7, -6, -5, -4, -3, -2, -1, 0};
short mmi_plane_inc[8]__attribute__((aligned(16))) = {1, 2, 3, 4, 5, 6, 7, 8};
short mmi_plane_dec[8]__attribute__((aligned(16))) = {8, 7, 6, 5, 4, 3, 2, 1};

short mmi_plane_inc_c[4]__attribute__((aligned(16))) = {1, 2, 3, 4};
short mmi_plane_dec_c[4]__attribute__((aligned(16))) = {4, 3, 2, 1};
short mmi_plane_mul_b_c[8]__attribute__((aligned(16))) = {-3, -2, -1, 0, 1, 2, 3, 4};

unsigned char mmi_01bytes[16]__attribute__((aligned(16))) = {1, 1, 1, 1, 1, 1, 1, 1,
                                                             1, 1, 1, 1, 1, 1, 1, 1};

void IdctResAddPred_mmi(uint8_t *pPred, const int32_t kiStride, int16_t *pRs) {
  __asm__ volatile (
    ".set       arch=loongson3a                           \n\t"
    "dli        $8, 0x1                                   \n\t"
    "gsldxc1    $f0, 0x0(%[pRs], $0)                      \n\t"
    "gsldxc1    $f2, 0x8(%[pRs], $0)                      \n\t"
    "gsldxc1    $f4, 0x10(%[pRs], $0)                     \n\t"
    "gsldxc1    $f6, 0x18(%[pRs], $0)                     \n\t"
    "dmtc1      $8, $f14                                  \n\t"

    MMI_Trans4x4H_SINGLE($f0, $f2, $f4, $f6, $f8)
    MMI_IDCT_SINGLE($f2, $f4, $f6, $f8, $f0, $f12, $f14)
    MMI_Trans4x4H_SINGLE($f2, $f6, $f0, $f8, $f4)
    MMI_IDCT_SINGLE($f6, $f0, $f8, $f4, $f2, $f12, $f14)

    "dli        $8, 0x20                                  \n\t"
    "xor        $f14, $f14, $f14                          \n\t"
    "dmtc1      $8, $f12                                  \n\t"
    "pshufh     $f12, $f12, $f14                          \n\t"
    "dli        $8, 0x6                                   \n\t"
    "dmtc1      $8, $f16                                  \n\t"

    MMI_StoreDiff4P_SINGLE($f6, $f0, $f12, $f14, %[pPred], %[pPred], $f16)
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    MMI_StoreDiff4P_SINGLE($f8, $f0, $f12, $f14, %[pPred], %[pPred], $f16)
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    MMI_StoreDiff4P_SINGLE($f2, $f0, $f12, $f14, %[pPred], %[pPred], $f16)
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    MMI_StoreDiff4P_SINGLE($f4, $f0, $f12, $f14, %[pPred], %[pPred], $f16)
    : [pPred]"+&r"((unsigned char *)pPred)
    : [pRs]"r"((unsigned char *)pRs), [kiStride]"r"((int)kiStride)
    : "memory", "$8", "$f0", "$f2", "$f4", "$f6", "$f8", "$f10", "$f12",
      "$f14", "$f16"
  );
}

void WelsDecoderI16x16LumaPredDc_mmi(uint8_t *pPred, const int32_t kiStride) {
  __asm__ volatile(
    ".set       arch=loongson3a                           \n\t"
    "dli        $8, 0x5                                   \n\t"
    "gsldxc1    $f10, 0x0(%[mmi_01bytes], $0)             \n\t"
    "dmtc1      $8, $f8                                   \n\t"

    "move       $10, %[pPred]                             \n\t"
    PTR_SUBU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gslqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"
    "xor        $f4, $f4, $f4                             \n\t"
    "pasubub    $f0, $f0, $f4                             \n\t"
    "pasubub    $f2, $f2, $f4                             \n\t"
    "biadd      $f0, $f0                                  \n\t"
    "biadd      $f2, $f2                                  \n\t"
    "paddh      $f0, $f0, $f2                             \n\t"

    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "lbu        $8, -0x1(%[pPred])                        \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "lbu        $9, -0x1(%[pPred])                        \n\t"
    PTR_ADDU   "$8, $8, $9                                \n\t"

    LOAD_2_LEFT_AND_ADD
    LOAD_2_LEFT_AND_ADD
    LOAD_2_LEFT_AND_ADD
    LOAD_2_LEFT_AND_ADD
    LOAD_2_LEFT_AND_ADD
    LOAD_2_LEFT_AND_ADD
    LOAD_2_LEFT_AND_ADD

    PTR_ADDIU  "$8, $8, 0x10                              \n\t"
    "dmtc1      $8, $f4                                   \n\t"
    "paddh      $f0, $f0, $f4                             \n\t"
    "psrlw      $f0, $f0, $f8                             \n\t"
    "pmuluw     $f0, $f0, $f10                            \n\t"
    "punpcklwd  $f0, $f0, $f0                             \n\t"
    "mov.d      $f2, $f0                                  \n\t"

    "gssqc1     $f2, $f0, 0x0($10)                        \n\t"
    PTR_ADDU   "$10, $10, %[kiStride]                     \n\t"
    "gssqc1     $f2, $f0, 0x0($10)                        \n\t"
    PTR_ADDU   "$10, $10, %[kiStride]                     \n\t"
    "gssqc1     $f2, $f0, 0x0($10)                        \n\t"

    PTR_ADDU   "$10, $10, %[kiStride]                     \n\t"
    "gssqc1     $f2, $f0, 0x0($10)                        \n\t"
    PTR_ADDU   "$10, $10, %[kiStride]                     \n\t"
    "gssqc1     $f2, $f0, 0x0($10)                        \n\t"

    PTR_ADDU   "$10, $10, %[kiStride]                     \n\t"
    "gssqc1     $f2, $f0, 0x0($10)                        \n\t"
    PTR_ADDU   "$10, $10, %[kiStride]                     \n\t"
    "gssqc1     $f2, $f0, 0x0($10)                        \n\t"

    PTR_ADDU   "$10, $10, %[kiStride]                     \n\t"
    "gssqc1     $f2, $f0, 0x0($10)                        \n\t"
    PTR_ADDU   "$10, $10, %[kiStride]                     \n\t"
    "gssqc1     $f2, $f0, 0x0($10)                        \n\t"

    PTR_ADDU   "$10, $10, %[kiStride]                     \n\t"
    "gssqc1     $f2, $f0, 0x0($10)                        \n\t"
    PTR_ADDU   "$10, $10, %[kiStride]                     \n\t"
    "gssqc1     $f2, $f0, 0x0($10)                        \n\t"

    PTR_ADDU   "$10, $10, %[kiStride]                     \n\t"
    "gssqc1     $f2, $f0, 0x0($10)                        \n\t"
    PTR_ADDU   "$10, $10, %[kiStride]                     \n\t"
    "gssqc1     $f2, $f0, 0x0($10)                        \n\t"

    PTR_ADDU   "$10, $10, %[kiStride]                     \n\t"
    "gssqc1     $f2, $f0, 0x0($10)                        \n\t"
    PTR_ADDU   "$10, $10, %[kiStride]                     \n\t"
    "gssqc1     $f2, $f0, 0x0($10)                        \n\t"

    PTR_ADDU   "$10, $10, %[kiStride]                     \n\t"
    "gssqc1     $f2, $f0, 0x0($10)                        \n\t"
    : [pPred] "+&r"((unsigned char *)pPred)
    : [kiStride] "r"((int)kiStride),
      [mmi_01bytes] "r"((unsigned char *)mmi_01bytes)
    : "memory", "$8", "$f0", "$f2", "$f4", "$f6", "$f8", "$f10"
  );
}

void WelsDecoderI16x16LumaPredPlane_mmi(uint8_t *pPred, const int32_t kiStride) {
  BACKUP_REG;
  __asm__ volatile (
    ".set       arch=loongson3a                           \n\t"
    "move       $10, %[pPred]                             \n\t"
    PTR_ADDIU  "%[pPred], %[pPred], -0x1                  \n\t"
    PTR_SUBU   "%[pPred], %[pPred], %[kiStride]           \n\t"

    "gsldlc1    $f0, 0x7(%[pPred])                        \n\t"
    "xor        $f28, $f28, $f28                          \n\t"
    "gsldrc1    $f0, 0x0(%[pPred])                        \n\t"
    "gslqc1     $f22, $f20, 0x0(%[mmi_plane_dec])         \n\t"
    "punpckhbh  $f2, $f0, $f28                            \n\t"
    "punpcklbh  $f0, $f0, $f28                            \n\t"
    "pmullh     $f0, $f0, $f20                            \n\t"
    "gsldlc1    $f4, 0x10(%[pPred])                       \n\t"
    "pmullh     $f2, $f2, $f22                            \n\t"
    "gsldrc1    $f4, 0x9(%[pPred])                        \n\t"
    "gslqc1     $f26, $f24, 0x0(%[mmi_plane_inc])         \n\t"
    "punpckhbh  $f6, $f4, $f28                            \n\t"
    "punpcklbh  $f4, $f4, $f28                            \n\t"
    "pmullh     $f4, $f4, $f24                            \n\t"
    "pmullh     $f6, $f6, $f26                            \n\t"
    "psubh      $f4, $f4, $f0                             \n\t"
    "psubh      $f6, $f6, $f2                             \n\t"

    SUMH_HORIZON($f4, $f6, $f0, $f2, $f8)
    "dmfc1      $8, $f4                                   \n\t"
    "seh        $8, $8                                    \n\t"
    "mul        $8, $8, 0x5                               \n\t"
    PTR_ADDIU  "$8, $8, 0x20                              \n\t"
    "sra        $8, $8, 0x6                               \n\t"
    MMI_Copy8Times($f4, $f6, $f28, $8)

    "lbu        $9, 0x10(%[pPred])                        \n\t"
    PTR_ADDIU  "%[pPred], %[pPred], -0x3                  \n\t"
    LOAD_COLUMN($f0, $f2, $f8, $f10, $f12, $f14, $f16, $f18, %[pPred],
                %[kiStride], $11)

    PTR_ADDIU  "%[pPred], %[pPred], 0x3                   \n\t"
    "dsll       $11, %[kiStride], 0x3                     \n\t"
    PTR_ADDU   "$11, $11, %[pPred]                        \n\t"
    "lbu        $8, 0x0($11)                              \n\t"
    PTR_ADDU   "$9, $9, $8                                \n\t"
    "dsll       $9, $9, 0x4                               \n\t"

    PTR_ADDIU  "%[pPred], %[pPred], -0x3                  \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    LOAD_COLUMN($f28, $f30, $f8, $f10, $f12, $f14, $f16, $f18, %[pPred],
                %[kiStride], $11)

    "xor        $f16, $f16, $f16                          \n\t"
    "punpcklbh  $f0, $f2, $f16                            \n\t"
    "punpckhbh  $f2, $f2, $f16                            \n\t"
    "pmullh     $f0, $f0, $f20                            \n\t"
    "pmullh     $f2, $f2, $f22                            \n\t"
    "punpcklbh  $f28, $f30, $f16                          \n\t"
    "punpckhbh  $f30, $f30, $f16                          \n\t"
    "pmullh     $f28, $f28, $f24                          \n\t"
    "pmullh     $f30, $f30, $f26                          \n\t"
    "psubh      $f28, $f28, $f0                           \n\t"
    "psubh      $f30, $f30, $f2                           \n\t"

    "xor        $f8, $f8, $f8                             \n\t"

    SUMH_HORIZON($f28, $f30, $f0, $f2, $f8)
    "dmfc1      $8, $f28                                  \n\t"
    "seh        $8, $8                                    \n\t"

    "mul        $8, $8, 0x5                               \n\t"
    PTR_ADDIU  "$8, $8, 0x20                              \n\t"
    "sra        $8, $8, 0x6                               \n\t"
    MMI_Copy8Times($f16, $f18, $f8, $8)

    "move       %[pPred], $10                             \n\t"
    PTR_ADDIU  "$9, $9, 0x10                              \n\t"
    "mul        $8, $8, -0x7                              \n\t"
    PTR_ADDU   "$9, $9, $8                                \n\t"
    MMI_Copy8Times($f0, $f2, $f8, $9)

    "xor        $8, $8, $8                                \n\t"
    "gslqc1     $f22, $f20, 0x0(%[mmi_plane_inc_minus])   \n\t"

    "dli        $11, 0x5                                  \n\t"
    "dmtc1      $11, $f30                                 \n\t"
    "1:                                                   \n\t"
    "pmullh     $f8, $f4, $f20                            \n\t"
    "pmullh     $f10, $f6, $f22                           \n\t"
    "paddh      $f8, $f8, $f0                             \n\t"
    "paddh      $f10, $f10, $f2                           \n\t"
    "psrah      $f8, $f8, $f30                            \n\t"
    "psrah      $f10, $f10, $f30                          \n\t"
    "pmullh     $f12, $f4, $f24                           \n\t"
    "pmullh     $f14, $f6, $f26                           \n\t"
    "paddh      $f12, $f12, $f0                           \n\t"
    "paddh      $f14, $f14, $f2                           \n\t"
    "psrah      $f12, $f12, $f30                          \n\t"
    "psrah      $f14, $f14, $f30                          \n\t"
    "packushb   $f8, $f8, $f10                            \n\t"
    "packushb   $f10, $f12, $f14                          \n\t"
    "gssqc1     $f10, $f8, 0x0(%[pPred])                  \n\t"
    "paddh      $f0, $f0, $f16                            \n\t"
    "paddh      $f2, $f2, $f18                            \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    PTR_ADDIU  "$8, $8, 0x1                               \n\t"
    PTR_ADDIU  "$11, $8, -0x10                            \n\t"
    "bnez       $11, 1b                                   \n\t"
    "nop                                                  \n\t"
    : [pPred]"+&r"((unsigned char *)pPred)
    : [kiStride]"r"((int)kiStride), [mmi_plane_inc_minus]"r"(mmi_plane_inc_minus),
      [mmi_plane_inc]"r"(mmi_plane_inc), [mmi_plane_dec]"r"(mmi_plane_dec)
    : "memory", "$8", "$9", "$10", "$11", "$f0", "$f2", "$f4", "$f6", "$f8",
      "$f10", "$f12", "$f14", "$f16", "$f18", "$f20", "$f22", "$f24", "$f26",
      "$f28", "$f30"
  );
  RECOVER_REG;
}

#define COPY_16_TIMES(r0, f0, f2, f4, f6, f8)                 \
  "gslqc1     "#f2", "#f0", -0x10("#r0")                \n\t" \
  "dsrl       "#f0", "#f2", "#f4"                       \n\t" \
  "pmuluw     "#f0", "#f0", "#f6"                       \n\t" \
  "punpcklwd  "#f0", "#f0", "#f0"                       \n\t" \
  "mov.d      "#f2", "#f0"                              \n\t"

#define MMI_PRED_H_16X16_TWO_LINE_DEC                         \
  PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t" \
  COPY_16_TIMES(%[pPred], $f0, $f2, $f4, $f6, $f8)            \
  "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t" \
  PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t" \
  COPY_16_TIMES(%[pPred], $f0, $f2, $f4, $f6, $f8)            \
  "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"

void WelsDecoderI16x16LumaPredH_mmi(uint8_t *pPred, const int32_t kiStride) {
  __asm__ volatile (
    ".set       arch=loongson3a                           \n\t"
    "dli        $8, 56                                    \n\t"
    "dmtc1      $8, $f4                                   \n\t"
    "gsldxc1    $f6, 0x0(%[mmi_01bytes], $0)              \n\t"
    "xor        $f8, $f8, $f8                             \n\t"

    COPY_16_TIMES(%[pPred], $f0, $f2, $f4, $f6, $f8)
    "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    COPY_16_TIMES(%[pPred], $f0, $f2, $f4, $f6, $f8)
    "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"

    MMI_PRED_H_16X16_TWO_LINE_DEC
    MMI_PRED_H_16X16_TWO_LINE_DEC
    MMI_PRED_H_16X16_TWO_LINE_DEC
    MMI_PRED_H_16X16_TWO_LINE_DEC
    MMI_PRED_H_16X16_TWO_LINE_DEC
    MMI_PRED_H_16X16_TWO_LINE_DEC
    MMI_PRED_H_16X16_TWO_LINE_DEC
    : [pPred]"+&r"((unsigned char *)pPred)
    : [kiStride]"r"((int)kiStride),
      [mmi_01bytes]"r"((unsigned char *)mmi_01bytes)
    : "memory", "$8", "$f0", "$f2", "$f4", "$f6", "$f8"
  );
}

void WelsDecoderI16x16LumaPredV_mmi(uint8_t *pPred, const int32_t kiStride) {
  __asm__ volatile(
    ".set       arch=loongson3a                           \n\t"
    PTR_SUBU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gslqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"

    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"
    : [pPred] "+&r"((unsigned char *)pPred)
    : [kiStride] "r"((int)kiStride)
    : "memory", "$f0", "$f2"
  );
}

void WelsDecoderI16x16LumaPredDcTop_mmi(uint8_t *pPred, const int32_t kiStride) {
  BACKUP_REG;
  __asm__ volatile (
    ".set       arch=loongson3a                           \n\t"
    PTR_SUBU   "$8, %[pPred], %[kiStride]                 \n\t"
    "gslqc1     $f2, $f0, 0x0($8)                         \n\t"
    "xor        $f28, $f28, $f28                          \n\t"
    "pasubub    $f0, $f0, $f28                            \n\t"
    "pasubub    $f2, $f2, $f28                            \n\t"
    "biadd      $f0, $f0                                  \n\t"
    "biadd      $f2, $f2                                  \n\t"
    "paddh      $f0, $f0, $f2                             \n\t"
    "dmfc1      $8, $f0                                   \n\t"

    PTR_ADDIU  "$8, $8, 0x8                               \n\t"
    "dsra       $8, $8, 0x4                               \n\t"
    MMI_Copy16Times($f4, $f6, $f28, $8)
    "mov.d      $f0, $f4                                  \n\t"
    "mov.d      $f2, $f6                                  \n\t"

    "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f6, $f4, 0x0(%[pPred])                   \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f6, $f4, 0x0(%[pPred])                   \n\t"

    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f6, $f4, 0x0(%[pPred])                   \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f6, $f4, 0x0(%[pPred])                   \n\t"

    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f6, $f4, 0x0(%[pPred])                   \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f6, $f4, 0x0(%[pPred])                   \n\t"

    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f6, $f4, 0x0(%[pPred])                   \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f6, $f4, 0x0(%[pPred])                   \n\t"
    : [pPred]"+&r"((unsigned char *)pPred)
    : [kiStride]"r"((int)kiStride)
    : "memory", "$8", "$f0", "$f2", "$f4", "$f6"
  );
  RECOVER_REG;
}

void WelsDecoderI16x16LumaPredDcNA_mmi(uint8_t *pPred, const int32_t kiStride) {
  __asm__ volatile(
    ".set       arch=loongson3a                           \n\t"
    "gslqc1     $f2, $f0, 0x0(%[mmi_dc_0x80])             \n\t"
    "mov.d      $f4, $f0                                  \n\t"
    "mov.d      $f6, $f2                                  \n\t"
    "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f6, $f4, 0x0(%[pPred])                   \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f6, $f4, 0x0(%[pPred])                   \n\t"

    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f6, $f4, 0x0(%[pPred])                   \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f6, $f4, 0x0(%[pPred])                   \n\t"

    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f6, $f4, 0x0(%[pPred])                   \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f6, $f4, 0x0(%[pPred])                   \n\t"

    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f6, $f4, 0x0(%[pPred])                   \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssqc1     $f6, $f4, 0x0(%[pPred])                   \n\t"
    : [pPred] "+&r"((unsigned char *)pPred)
    : [kiStride] "r"((int)kiStride), [mmi_dc_0x80] "r"(mmi_dc_0x80)
    : "memory", "$8", "$f0", "$f2", "$f4", "$f6"
  );
}

void WelsDecoderIChromaPredPlane_mmi(uint8_t *pPred, const int32_t kiStride) {
  BACKUP_REG;
  __asm__ volatile (
    ".set       arch=loongson3a                           \n\t"
    "move       $10, %[pPred]                             \n\t"
    PTR_ADDIU  "%[pPred], %[pPred], -0x1                  \n\t"
    PTR_SUBU   "%[pPred], %[pPred], %[kiStride]           \n\t"

    "gsldlc1    $f0, 0x7(%[pPred])                        \n\t"
    "xor        $f28, $f28, $f28                          \n\t"
    "gsldrc1    $f0, 0x0(%[pPred])                        \n\t"
    "gsldxc1    $f20, 0x0(%[mmi_plane_dec_c], $0)         \n\t"
    "punpcklbh  $f0, $f0, $f28                            \n\t"
    "gsldlc1    $f4, 0xc(%[pPred])                        \n\t"
    "pmullh     $f0, $f0, $f20                            \n\t"
    "gsldrc1    $f4, 0x5(%[pPred])                        \n\t"
    "gsldxc1    $f24, 0x0(%[mmi_plane_inc_c], $0)         \n\t"
    "punpcklbh  $f4, $f4, $f28                            \n\t"
    "pmullh     $f4, $f4, $f24                            \n\t"
    "psubh      $f4, $f4, $f0                             \n\t"

    "xor        $f6, $f6, $f6                             \n\t"
    "xor        $f8, $f8, $f8                             \n\t"
    SUMH_HORIZON($f4, $f6, $f0, $f2, $f8)
    "dmfc1      $8, $f4                                   \n\t"
    "seh        $8, $8                                    \n\t"
    "mul        $8, $8, 0x11                              \n\t"
    PTR_ADDIU  "$8, $8, 0x10                              \n\t"
    "sra        $8, $8, 0x5                               \n\t"
    MMI_Copy8Times($f4, $f6, $f8, $8)

    "lbu        $9, 0x8(%[pPred])                         \n\t"
    PTR_ADDIU  "%[pPred], %[pPred], -0x3                  \n\t"
    LOAD_COLUMN_C($f0, $f8, $f12, $f16, %[pPred], %[kiStride], $11)

    PTR_ADDIU  "%[pPred], %[pPred], 0x3                   \n\t"
    "dsll       $11, %[kiStride], 0x2                     \n\t"
    PTR_ADDU   "$11, $11, %[pPred]                        \n\t"
    "lbu        $8, 0x0($11)                              \n\t"
    PTR_ADDU   "$9, $9, $8                                \n\t"
    "dsll       $9, $9, 0x4                               \n\t"

    PTR_ADDIU  "%[pPred], %[pPred], -0x3                  \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    LOAD_COLUMN_C($f28, $f8, $f12, $f16, %[pPred], %[kiStride], $11)
    "xor        $f16, $f16, $f16                          \n\t"
    "punpckhbh  $f0, $f0, $f16                            \n\t"
    "pmullh     $f0, $f0, $f20                            \n\t"
    "punpckhbh  $f28, $f28, $f16                          \n\t"
    "pmullh     $f28, $f28, $f24                          \n\t"
    "psubh      $f28, $f28, $f0                           \n\t"

    "xor        $f30, $f30, $f30                          \n\t"
    "xor        $f8, $f8, $f8                             \n\t"
    SUMH_HORIZON($f28, $f30, $f0, $f2, $f8)
    "dmfc1      $8, $f28                                  \n\t"
    "seh        $8, $8                                    \n\t"

    "mul        $8, $8, 0x11                              \n\t"
    PTR_ADDIU  "$8, $8, 0x10                              \n\t"
    "sra        $8, $8, 0x5                               \n\t"
    MMI_Copy8Times($f16, $f18, $f8, $8)

    "move       %[pPred], $10                             \n\t"
    PTR_ADDIU  "$9, $9, 0x10                              \n\t"
    "mul        $8, $8, -0x3                              \n\t"
    PTR_ADDU   "$9, $9, $8                                \n\t"
    MMI_Copy8Times($f0, $f2, $f8, $9)

    "xor        $8, $8, $8                                \n\t"
    "gslqc1     $f22, $f20, 0x0(%[mmi_plane_mul_b_c])     \n\t"

    "dli        $11, 0x5                                  \n\t"
    "dmtc1      $11, $f30                                 \n\t"
    "1:                                                   \n\t"
    "pmullh     $f8, $f4, $f20                            \n\t"
    "pmullh     $f10, $f6, $f22                           \n\t"
    "paddh      $f8, $f8, $f0                             \n\t"
    "paddh      $f10, $f10, $f2                           \n\t"
    "psrah      $f8, $f8, $f30                            \n\t"
    "psrah      $f10, $f10, $f30                          \n\t"
    "packushb   $f8, $f8, $f10                            \n\t"
    "gssdxc1    $f8, 0x0(%[pPred], $0)                    \n\t"
    "paddh      $f0, $f0, $f16                            \n\t"
    "paddh      $f2, $f2, $f18                            \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    PTR_ADDIU  "$8, $8, 0x1                               \n\t"
    PTR_ADDIU  "$11, $8, -0x8                             \n\t"
    "bnez       $11, 1b                                   \n\t"
    "nop                                                  \n\t"
    : [pPred]"+&r"((unsigned char *)pPred)
    : [kiStride]"r"((int)kiStride), [mmi_plane_mul_b_c]"r"(mmi_plane_mul_b_c),
      [mmi_plane_inc_c]"r"(mmi_plane_inc_c), [mmi_plane_dec_c]"r"(mmi_plane_dec_c)
    : "memory", "$8", "$9", "$10", "$11", "$f0", "$f2", "$f4", "$f6", "$f8", "$f10",
      "$f12", "$f14", "$f16", "$f18", "$f20", "$f22", "$f24", "$f26", "$f28", "$f30"
  );
  RECOVER_REG;
}

void WelsDecoderIChromaPredDc_mmi(uint8_t *pPred, const int32_t kiStride) {
  __asm__ volatile(
    ".set       arch=loongson3a                           \n\t"
    "move       $10, %[pPred]                             \n\t"

    PTR_SUBU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gsldxc1    $f0, 0x0(%[pPred], $0)                    \n\t"

    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "lbu        $8, -0x1(%[pPred])                        \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "lbu        $9, -0x1(%[pPred])                        \n\t"
    PTR_ADDU   "$8, $8, $9                                \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "lbu        $9, -0x1(%[pPred])                        \n\t"
    PTR_ADDU   "$8, $8, $9                                \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "lbu        $9, -0x1(%[pPred])                        \n\t"
    PTR_ADDU   "$8, $8, $9                                \n\t"
    "dmtc1      $8, $f2                                   \n\t"

    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "lbu        $8, -0x1(%[pPred])                        \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "lbu        $9, -0x1(%[pPred])                        \n\t"
    PTR_ADDU   "$8, $8, $9                                \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "lbu        $9, -0x1(%[pPred])                        \n\t"
    PTR_ADDU   "$8, $8, $9                                \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "lbu        $9, -0x1(%[pPred])                        \n\t"
    PTR_ADDU   "$8, $8, $9                                \n\t"
    "dmtc1      $8, $f4                                   \n\t"

    "xor        $f8, $f8, $f8                             \n\t"
    "punpcklwd  $f6, $f0, $f8                             \n\t"
    "punpckhwd  $f0, $f0, $f8                             \n\t"
    "pasubub    $f0, $f0, $f8                             \n\t"
    "pasubub    $f6, $f6, $f8                             \n\t"
    "biadd      $f0, $f0                                  \n\t"
    "biadd      $f6, $f6                                  \n\t"

    "paddd      $f6, $f6, $f2                             \n\t"
    "paddd      $f2, $f4, $f0                             \n\t"

    "dli        $8, 0x2                                   \n\t"
    "dmtc1      $8, $f8                                   \n\t"
    "gsldxc1    $f12, 0x0(%[mmi_01bytes], $0)             \n\t"
    "dli        $8, 0x3                                   \n\t"
    "dmtc1      $8, $f10                                  \n\t"

    "paddd      $f0, $f0, $f8                             \n\t"
    "dsrl       $f0, $f0, $f8                             \n\t"

    "paddd      $f4, $f4, $f8                             \n\t"
    "dsrl       $f4, $f4, $f8                             \n\t"

    "paddd      $f6, $f6, $f8                             \n\t"
    "paddd      $f6, $f6, $f8                             \n\t"
    "dsrl       $f6, $f6, $f10                            \n\t"

    "paddd      $f2, $f2, $f8                             \n\t"
    "paddd      $f2, $f2, $f8                             \n\t"
    "dsrl       $f2, $f2, $f10                            \n\t"

    "dli        $8, 0x20                                  \n\t"
    "dmtc1      $8, $f8                                   \n\t"
    "pmuluw     $f0, $f0, $f12                            \n\t"
    "pmuluw     $f6, $f6, $f12                            \n\t"
    "dsll       $f0, $f0, $f8                             \n\t"
    "xor        $f0, $f0, $f6                             \n\t"

    "pmuluw     $f4, $f4, $f12                            \n\t"
    "pmuluw     $f2, $f2, $f12                            \n\t"
    "dsll       $f2, $f2, $f8                             \n\t"
    "xor        $f2, $f2, $f4                             \n\t"

    "gssdxc1    $f0, 0x0($10, $0)                         \n\t"
    PTR_ADDU   "$10, $10, %[kiStride]                     \n\t"
    "gssdxc1    $f0, 0x0($10, $0)                         \n\t"
    PTR_ADDU   "$10, $10, %[kiStride]                     \n\t"
    "gssdxc1    $f0, 0x0($10, $0)                         \n\t"
    PTR_ADDU   "$10, $10, %[kiStride]                     \n\t"
    "gssdxc1    $f0, 0x0($10, $0)                         \n\t"

    PTR_ADDU   "$10, $10, %[kiStride]                     \n\t"
    "gssdxc1    $f2, 0x0($10, $0)                         \n\t"
    PTR_ADDU   "$10, $10, %[kiStride]                     \n\t"
    "gssdxc1    $f2, 0x0($10, $0)                         \n\t"
    PTR_ADDU   "$10, $10, %[kiStride]                     \n\t"
    "gssdxc1    $f2, 0x0($10, $0)                         \n\t"
    PTR_ADDU   "$10, $10, %[kiStride]                     \n\t"
    "gssdxc1    $f2, 0x0($10, $0)                         \n\t"
    : [pPred] "+&r"((unsigned char *)pPred)
    : [kiStride] "r"((int)kiStride),
      [mmi_01bytes] "r"((unsigned char *)mmi_01bytes)
    : "memory", "$8", "$9", "$10", "$f0", "$f2", "$f4", "$f6", "$f8", "$f10",
      "$f12"
  );
}

void WelsDecoderIChromaPredDcTop_mmi(uint8_t *pPred, const int32_t kiStride) {
  BACKUP_REG;
  __asm__ volatile (
    ".set       arch=loongson3a                           \n\t"
    "dli        $8, 0x4e                                  \n\t"
    "dmtc1      $8, $f16                                  \n\t"
    "dli        $8, 0xb1                                  \n\t"
    "dmtc1      $8, $f18                                  \n\t"
    "dli        $8, 0x2                                   \n\t"
    "dmtc1      $8, $f20                                  \n\t"
    PTR_SUBU   "$8, %[pPred], %[kiStride]                 \n\t"
    "gsldxc1    $f0, 0x0($8, $0)                          \n\t"
    "xor        $f28, $f28, $f28                          \n\t"
    "punpckhbh  $f2, $f0, $f28                            \n\t"
    "punpcklbh  $f0, $f0, $f28                            \n\t"
    "pshufh     $f4, $f0, $f16                            \n\t"
    "pshufh     $f6, $f2, $f16                            \n\t"
    "paddh      $f0, $f0, $f4                             \n\t"
    "paddh      $f2, $f2, $f6                             \n\t"

    "pshufh     $f8, $f0, $f18                            \n\t"
    "pshufh     $f14, $f2, $f18                           \n\t"
    "paddh      $f2, $f2, $f14                            \n\t"
    "paddh      $f0, $f0, $f8                             \n\t"

    "gslqc1     $f26, $f24, 0x0(%[mmi_wd_0x02])           \n\t"
    "paddh      $f0, $f0, $f24                            \n\t"
    "paddh      $f2, $f2, $f26                            \n\t"
    "psrah      $f0, $f0, $f20                            \n\t"
    "psrah      $f2, $f2, $f20                            \n\t"
    "packushb   $f0, $f0, $f2                             \n\t"

    "gssdxc1    $f0, 0x0(%[pPred], $0)                    \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssdxc1    $f0, 0x0(%[pPred], $0)                    \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssdxc1    $f0, 0x0(%[pPred], $0)                    \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssdxc1    $f0, 0x0(%[pPred], $0)                    \n\t"

    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssdxc1    $f0, 0x0(%[pPred], $0)                    \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssdxc1    $f0, 0x0(%[pPred], $0)                    \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssdxc1    $f0, 0x0(%[pPred], $0)                    \n\t"
    PTR_ADDU   "%[pPred], %[pPred], %[kiStride]           \n\t"
    "gssdxc1    $f0, 0x0(%[pPred], $0)                    \n\t"
    : [pPred] "+&r"((unsigned char *)pPred)
    : [kiStride] "r"((int)kiStride), [mmi_wd_0x02] "r"((short *)mmi_wd_0x02)
    : "memory", "$8", "$f0", "$f2", "$f4", "$f6"
  );
  RECOVER_REG;
}

void WelsDecoderI4x4LumaPredH_mmi(uint8_t *pPred, const int32_t kiStride) {
  __asm__ volatile(
    ".set       arch=loongson3a                           \n\t"
    "gsldxc1    $f8, 0x0(%[mmi_01bytes], $0)              \n\t"
    "lbu        $8, -0x1(%[pPred])                        \n\t"
    "dmtc1      $8, $f0                                   \n\t"
    "pmuluw     $f0, $f0, $f8                             \n\t"

    PTR_ADDU   "$9, %[pPred], %[kiStride]                 \n\t"
    "lbu        $8, -0x1($9)                              \n\t"
    "dmtc1      $8, $f2                                   \n\t"
    "pmuluw     $f2, $f2, $f8                             \n\t"

    PTR_ADDU   "$10, $9, %[kiStride]                      \n\t"
    "lbu        $8, -0x1($10)                             \n\t"
    "dmtc1      $8, $f4                                   \n\t"
    "pmuluw     $f4, $f4, $f8                             \n\t"

    PTR_ADDU   "$11, $10, %[kiStride]                     \n\t"
    "lbu        $8, -0x1($11)                             \n\t"
    "dmtc1      $8, $f6                                   \n\t"
    "pmuluw     $f6, $f6, $f8                             \n\t"

    "gsswxc1    $f0, 0x0(%[pPred], $0)                    \n\t"
    "gsswxc1    $f2, 0x0($9, $0)                          \n\t"
    "gsswxc1    $f4, 0x0($10, $0)                         \n\t"
    "gsswxc1    $f6, 0x0($11, $0)                         \n\t"
    : [pPred] "+&r"((unsigned char *)pPred)
    : [kiStride] "r"((int)kiStride),
      [mmi_01bytes] "r"((unsigned char *)mmi_01bytes)
    : "memory", "$8", "$9", "$10", "$11", "$f0", "$f2", "$f4", "$f6", "$f8"
  );
}
