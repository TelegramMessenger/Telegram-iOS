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
 * \file    intra_pred_com_mmi.c
 *
 * \brief   Loongson optimization
 *
 * \date    23/07/2018 Created
 *
 *************************************************************************************
 */
#include <stdint.h>
#include "asmdefs_mmi.h"

#define MMI_PRED_H_16X16_ONE_LINE \
  PTR_ADDIU  "%[pPred], %[pPred], 0x10                  \n\t" \
  PTR_ADDU   "%[pRef], %[pRef], %[kiStride]             \n\t" \
  "lbu        $8, 0x0(%[pRef])                          \n\t" \
  MMI_Copy16Times($f0, $f2, $f4, $8)                          \
  "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"

#define LOAD_2_LEFT_AND_ADD \
  PTR_ADDU   "%[pRef], %[pRef], %[kiStride]             \n\t" \
  "lbu        $9, -0x1(%[pRef])                         \n\t" \
  PTR_ADDU   "$8, $8, $9                                \n\t" \
  PTR_ADDU   "%[pRef], %[pRef], %[kiStride]             \n\t" \
  "lbu        $9, -0x1(%[pRef])                         \n\t" \
  PTR_ADDU   "$8, $8, $9                                \n\t"

//f2 should be mmi_01bytes, f4 should be 0x38, f6 should be 0x0
#define MMI_PRED_H_8X8_ONE_LINE(f0, f2, f4, f6, r0, r1, r1_offset) \
  PTR_ADDU   ""#r0", "#r0", %[kiStride]                 \n\t" \
  "gsldxc1    "#f0", -0x8("#r0", $0)                    \n\t" \
  "dsrl       "#f0", "#f0", "#f4"                       \n\t" \
  "pmullh     "#f0", "#f0", "#f2"                       \n\t" \
  "pshufh     "#f0", "#f0", "#f6"                       \n\t" \
  "gssdxc1    "#f0", "#r1_offset"+0x0("#r1", $0)        \n\t"

void WelsI16x16LumaPredV_mmi(uint8_t *pPred, uint8_t *pRef, int32_t kiStride) {
  __asm__ volatile (
    ".set     arch=loongson3a                             \n\t"
    PTR_SUBU   "%[pRef], %[pRef], %[kiStride]             \n\t"
    "gslqc1     $f2, $f0, 0x0(%[pRef])                    \n\t"

    "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"
    "gssqc1     $f2, $f0, 0x10(%[pPred])                  \n\t"
    "gssqc1     $f2, $f0, 0x20(%[pPred])                  \n\t"
    "gssqc1     $f2, $f0, 0x30(%[pPred])                  \n\t"
    "gssqc1     $f2, $f0, 0x40(%[pPred])                  \n\t"
    "gssqc1     $f2, $f0, 0x50(%[pPred])                  \n\t"
    "gssqc1     $f2, $f0, 0x60(%[pPred])                  \n\t"
    "gssqc1     $f2, $f0, 0x70(%[pPred])                  \n\t"
    "gssqc1     $f2, $f0, 0x80(%[pPred])                  \n\t"
    "gssqc1     $f2, $f0, 0x90(%[pPred])                  \n\t"
    "gssqc1     $f2, $f0, 0xa0(%[pPred])                  \n\t"
    "gssqc1     $f2, $f0, 0xb0(%[pPred])                  \n\t"
    "gssqc1     $f2, $f0, 0xc0(%[pPred])                  \n\t"
    "gssqc1     $f2, $f0, 0xd0(%[pPred])                  \n\t"
    "gssqc1     $f2, $f0, 0xe0(%[pPred])                  \n\t"
    "gssqc1     $f2, $f0, 0xf0(%[pPred])                  \n\t"
    : [pPred]"+&r"((unsigned char *)pPred), [pRef]"+&r"((unsigned char *)pRef)
    : [kiStride]"r"((int)kiStride)
    : "memory", "$f0", "$f2"
  );
}

void WelsI16x16LumaPredH_mmi(uint8_t *pPred, uint8_t *pRef, int32_t kiStride) {
  __asm__ volatile (
    ".set     arch=loongson3a                             \n\t"
    PTR_ADDIU  "%[pRef], %[pRef], -0x1                    \n\t"
    "lbu        $8, 0x0(%[pRef])                          \n\t"
    "xor        $f4, $f4, $f4                             \n\t"
    MMI_Copy16Times($f0, $f2, $f4, $8)
    "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"

    MMI_PRED_H_16X16_ONE_LINE
    MMI_PRED_H_16X16_ONE_LINE
    MMI_PRED_H_16X16_ONE_LINE
    MMI_PRED_H_16X16_ONE_LINE
    MMI_PRED_H_16X16_ONE_LINE
    MMI_PRED_H_16X16_ONE_LINE
    MMI_PRED_H_16X16_ONE_LINE
    MMI_PRED_H_16X16_ONE_LINE
    MMI_PRED_H_16X16_ONE_LINE
    MMI_PRED_H_16X16_ONE_LINE
    MMI_PRED_H_16X16_ONE_LINE
    MMI_PRED_H_16X16_ONE_LINE
    MMI_PRED_H_16X16_ONE_LINE
    MMI_PRED_H_16X16_ONE_LINE
    MMI_PRED_H_16X16_ONE_LINE
    : [pPred]"+&r"((unsigned char *)pPred), [pRef]"+&r"((unsigned char *)pRef)
    : [kiStride]"r"((int)kiStride)
    : "memory", "$8", "$f0", "$f2", "$f4"
  );
}

void WelsI16x16LumaPredDc_mmi(uint8_t *pPred, uint8_t *pRef, int32_t kiStride) {
  unsigned char mmi_01bytes[16]__attribute__((aligned(16))) =
                {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1};
  __asm__ volatile (
    ".set     arch=loongson3a                             \n\t"
    PTR_SUBU   "%[pRef], %[pRef], %[kiStride]             \n\t"
    "gslqc1     $f2, $f0, 0x0(%[pRef])                    \n\t"
    "xor        $f4, $f4, $f4                             \n\t"
    "pasubub    $f0, $f0, $f4                             \n\t"
    "pasubub    $f2, $f2, $f4                             \n\t"
    "biadd      $f0, $f0                                  \n\t"
    "biadd      $f2, $f2                                  \n\t"
    "paddh      $f0, $f0, $f2                             \n\t"

    PTR_ADDU   "%[pRef], %[pRef], %[kiStride]             \n\t"
    "lbu        $8, -0x1(%[pRef])                         \n\t"
    PTR_ADDU   "%[pRef], %[pRef], %[kiStride]             \n\t"
    "lbu        $9, -0x1(%[pRef])                         \n\t"
    PTR_ADDU   "$8, $8, $9                                \n\t"

    LOAD_2_LEFT_AND_ADD
    LOAD_2_LEFT_AND_ADD
    LOAD_2_LEFT_AND_ADD
    LOAD_2_LEFT_AND_ADD
    LOAD_2_LEFT_AND_ADD
    LOAD_2_LEFT_AND_ADD
    LOAD_2_LEFT_AND_ADD

    "dli        $10, 0x5                                  \n\t"
    "dmtc1      $10, $f6                                  \n\t"
    PTR_ADDIU  "$8, 0x10                                  \n\t"
    "dmtc1      $8, $f4                                   \n\t"
    "paddh      $f0, $f0, $f4                             \n\t"
    "psrlw      $f0, $f0, $f6                             \n\t"
    "gsldxc1    $f6, 0x0(%[mmi_01bytes], $0)              \n\t"
    "pmuluw     $f0, $f0, $f6                             \n\t"
    "punpcklwd  $f0, $f0, $f0                             \n\t"
    "mov.d      $f2, $f0                                  \n\t"

    "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"
    "gssqc1     $f2, $f0, 0x10(%[pPred])                  \n\t"
    "gssqc1     $f2, $f0, 0x20(%[pPred])                  \n\t"
    "gssqc1     $f2, $f0, 0x30(%[pPred])                  \n\t"
    "gssqc1     $f2, $f0, 0x40(%[pPred])                  \n\t"
    "gssqc1     $f2, $f0, 0x50(%[pPred])                  \n\t"
    "gssqc1     $f2, $f0, 0x60(%[pPred])                  \n\t"
    "gssqc1     $f2, $f0, 0x70(%[pPred])                  \n\t"
    "gssqc1     $f2, $f0, 0x80(%[pPred])                  \n\t"
    "gssqc1     $f2, $f0, 0x90(%[pPred])                  \n\t"
    "gssqc1     $f2, $f0, 0xa0(%[pPred])                  \n\t"
    "gssqc1     $f2, $f0, 0xb0(%[pPred])                  \n\t"
    "gssqc1     $f2, $f0, 0xc0(%[pPred])                  \n\t"
    "gssqc1     $f2, $f0, 0xd0(%[pPred])                  \n\t"
    "gssqc1     $f2, $f0, 0xe0(%[pPred])                  \n\t"
    "gssqc1     $f2, $f0, 0xf0(%[pPred])                  \n\t"
    : [pPred]"+&r"((unsigned char *)pPred), [pRef]"+&r"((unsigned char *)pRef)
    : [kiStride]"r"((int)kiStride), [mmi_01bytes]"r"((unsigned char *)mmi_01bytes)
    : "memory", "$8", "$f0", "$f2", "$f4", "$f6"
  );
}

void WelsI16x16LumaPredPlane_mmi(uint8_t *pPred, uint8_t *pRef, int32_t kiStride) {
  short mmi_plane_inc_minus[8]__attribute__((aligned(16))) = {-7, -6, -5, -4,
                                                              -3, -2, -1, 0};
  short mmi_plane_inc[8]__attribute__((aligned(16))) = {1, 2, 3, 4, 5, 6, 7, 8};
  short mmi_plane_dec[8]__attribute__((aligned(16))) = {8, 7, 6, 5, 4, 3, 2, 1};
  BACKUP_REG;
  __asm__ volatile (
    ".set       arch=loongson3a                           \n\t"
    PTR_ADDIU  "%[pRef], %[pRef], -0x1                    \n\t"
    PTR_SUBU   "%[pRef], %[pRef], %[kiStride]             \n\t"

    "gsldlc1    $f0, 0x7(%[pRef])                         \n\t"
    "xor        $f28, $f28, $f28                          \n\t"
    "gsldrc1    $f0, 0x0(%[pRef])                         \n\t"
    "gslqc1     $f22, $f20, 0x0(%[mmi_plane_dec])         \n\t"
    "punpckhbh  $f2, $f0, $f28                            \n\t"
    "punpcklbh  $f0, $f0, $f28                            \n\t"
    "gsldlc1    $f4, 0x10(%[pRef])                        \n\t"
    "pmullh     $f0, $f0, $f20                            \n\t"
    "pmullh     $f2, $f2, $f22                            \n\t"
    "gsldrc1    $f4, 0x9(%[pRef])                         \n\t"
    "gslqc1     $f26, $f24, 0x0(%[mmi_plane_inc])         \n\t"
    "punpckhbh  $f6, $f4, $f28                            \n\t"
    "punpcklbh  $f4, $f4, $f28                            \n\t"
    "pmullh     $f4, $f4, $f24                            \n\t"
    "pmullh     $f6, $f6, $f26                            \n\t"
    "psubh      $f4, $f4, $f0                             \n\t"
    "psubh      $f6, $f6, $f2                             \n\t"

    "xor        $f8, $f8, $f8                             \n\t"
    SUMH_HORIZON($f4, $f6, $f0, $f2, $f8)
    "dmfc1      $8, $f4                                   \n\t"
    "seh        $8, $8                                    \n\t"
    "mul        $8, $8, 0x5                               \n\t"
    PTR_ADDIU  "$8, $8, 0x20                              \n\t"
    "sra        $8, $8, 0x6                               \n\t"
    MMI_Copy8Times($f4, $f6, $f28, $8)

    "lbu        $9, 0x10(%[pRef])                         \n\t"
    PTR_ADDIU  "%[pRef], %[pRef], -0x3                    \n\t"
    LOAD_COLUMN($f0, $f2, $f8, $f10, $f12, $f14, $f16,
                $f18, %[pRef], %[kiStride], $11)

    PTR_ADDIU  "%[pRef], %[pRef], 0x3                     \n\t"
    "dsll       $10, %[kiStride], 0x3                     \n\t"
    PTR_ADDU   "$10, $10, %[pRef]                         \n\t"
    "lbu        $8, 0x0($10)                              \n\t"
    PTR_ADDU   "$9, $9, $8                                \n\t"
    "dsll       $9, $9, 0x4                               \n\t"

    PTR_ADDIU  "%[pRef], %[pRef], -0x3                    \n\t"
    PTR_ADDU   "%[pRef], %[pRef], %[kiStride]             \n\t"
    LOAD_COLUMN($f28, $f30, $f8, $f10, $f12, $f14, $f16,
                $f18, %[pRef], %[kiStride], $11)
    "xor        $f16, $f16, $f16                          \n\t"
    "xor        $f18, $f18, $f18                          \n\t"
    "punpcklbh  $f0, $f2, $f18                            \n\t"
    "punpckhbh  $f2, $f2, $f18                            \n\t"
    "pmullh     $f0, $f0, $f20                            \n\t"
    "pmullh     $f2, $f2, $f22                            \n\t"
    "punpcklbh  $f28, $f30, $f18                          \n\t"
    "punpckhbh  $f30, $f30, $f18                          \n\t"
    "pmullh     $f28, $f28, $f24                          \n\t"
    "pmullh     $f30, $f30, $f26                          \n\t"
    "psubh      $f28, $f28, $f0                           \n\t"
    "psubh      $f30, $f30, $f2                           \n\t"

    SUMH_HORIZON($f28, $f30, $f0, $f2, $f8)
    "dmfc1      $8, $f28                                  \n\t"
    "seh        $8, $8                                    \n\t"
    "mul        $8, $8, 0x5                               \n\t"
    PTR_ADDIU  "$8, $8, 0x20                              \n\t"
    "sra        $8, $8, 0x6                               \n\t"
    "xor        $f20, $f20, $f20                          \n\t"
    MMI_Copy8Times($f16, $f18, $f20, $8)

    PTR_ADDIU  "$9, $9, 0x10                              \n\t"
    "mul        $8, $8, -0x7                              \n\t"
    PTR_ADDU   "$8, $8, $9                                \n\t"
    "xor        $f20, $f20, $f20                          \n\t"
    MMI_Copy8Times($f0, $f2, $f20, $8)

    "xor        $8, $8, $8                                \n\t"
    "gslqc1     $f22, $f20, 0x0(%[mmi_plane_inc_minus])   \n\t"

    "dli        $10, 0x5                                  \n\t"
    "dmtc1      $10, $f30                                 \n\t"
    "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"
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
    PTR_ADDIU  "%[pPred], %[pPred], 0x10                  \n\t"
    PTR_ADDIU  "$8, $8, 0x1                               \n\t"
    PTR_ADDIU  "$10, $8, -0x10                            \n\t"
    "bnez       $10, 1b                                   \n\t"
    "nop                                                  \n\t"
    : [pPred]"+&r"((unsigned char *)pPred), [pRef]"+&r"((unsigned char *)pRef)
    : [kiStride]"r"((int)kiStride), [mmi_plane_inc_minus]"r"(mmi_plane_inc_minus),
      [mmi_plane_inc]"r"(mmi_plane_inc), [mmi_plane_dec]"r"(mmi_plane_dec)
    : "memory", "$8", "$9", "$10", "$11", "$f0", "$f2", "$f4", "$f6", "$f8",
      "$f10", "$f12", "$f14", "$f16", "$f18", "$f20", "$f22", "$f24", "$f26",
      "$f28", "$f30"
  );
  RECOVER_REG;
}

void WelsIChromaPredPlane_mmi(uint8_t *pPred, uint8_t *pRef, int32_t kiStride) {
  short mmi_plane_inc_c[4]__attribute__((aligned(16))) = {1, 2, 3, 4};
  short mmi_plane_dec_c[4]__attribute__((aligned(16))) = {4, 3, 2, 1};
  short mmi_plane_mul_b_c[8]__attribute__((aligned(16))) = {-3, -2, -1, 0,
                                                            1, 2, 3, 4};
  BACKUP_REG;
  __asm__ volatile (
    ".set       arch=loongson3a                           \n\t"
    PTR_ADDIU  "%[pRef], %[pRef], -0x1                    \n\t"
    PTR_SUBU   "%[pRef], %[pRef], %[kiStride]             \n\t"

    "gsldlc1    $f0, 0x7(%[pRef])                         \n\t"
    "xor        $f28, $f28, $f28                          \n\t"
    "gsldrc1    $f0, 0x0(%[pRef])                         \n\t"
    "gsldxc1    $f20, 0x0(%[mmi_plane_dec_c], $0)         \n\t"
    "punpcklbh  $f0, $f0, $f28                            \n\t"
    "gsldlc1    $f4, 0xc(%[pRef])                         \n\t"
    "pmullh     $f0, $f0, $f20                            \n\t"
    "gsldrc1    $f4, 0x5(%[pRef])                         \n\t"
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
    MMI_Copy8Times($f4, $f6, $f28, $8)

    "lbu        $8, 0x8(%[pRef])                          \n\t"
    PTR_ADDIU  "%[pRef], %[pRef], -0x3                    \n\t"
    LOAD_COLUMN_C($f0, $f8, $f12, $f16, %[pRef], %[kiStride], $10)

    PTR_ADDIU  "%[pRef], %[pRef], 0x3                     \n\t"
    "dsll       $10, %[kiStride], 0x2                     \n\t"
    PTR_ADDU   "$10, $10, %[pRef]                         \n\t"
    "lbu        $9, 0x0($10)                              \n\t"
    PTR_ADDU   "$9, $9, $8                                \n\t"
    "dsll       $9, $9, 0x4                               \n\t"

    PTR_ADDIU  "%[pRef], %[pRef], -0x3                    \n\t"
    PTR_ADDU   "%[pRef], %[pRef], %[kiStride]             \n\t"
    LOAD_COLUMN_C($f28, $f8, $f12, $f16, %[pRef], %[kiStride], $10)
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

    PTR_ADDIU  "$9, $9, 0x10                              \n\t"
    "mul        $8, $8, -0x3                              \n\t"
    PTR_ADDU   "$8, $8, $9                                \n\t"
    MMI_Copy8Times($f0, $f2, $f8, $8)

    "xor        $8, $8, $8                                \n\t"
    "gslqc1     $f22, $f20, 0x0(%[mmi_plane_mul_b_c])     \n\t"

    "dli        $10, 0x5                                  \n\t"
    "dmtc1      $10, $f30                                 \n\t"
    "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"

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
    PTR_ADDIU  "%[pPred], %[pPred], 0x8                   \n\t"
    PTR_ADDIU  "$8, $8, 0x1                               \n\t"
    PTR_ADDIU  "$10, $8, -0x8                             \n\t"
    "bnez       $10, 1b                                   \n\t"
    "nop                                                  \n\t"
    : [pPred]"+&r"((unsigned char *)pPred), [pRef]"+&r"((unsigned char *)pRef)
    : [kiStride]"r"((int)kiStride), [mmi_plane_mul_b_c]"r"(mmi_plane_mul_b_c),
      [mmi_plane_inc_c]"r"(mmi_plane_inc_c), [mmi_plane_dec_c]"r"(mmi_plane_dec_c)
    : "memory", "$8", "$9", "$10", "$f0", "$f2", "$f4", "$f6", "$f8", "$f10", "$f12",
      "$f14", "$f16", "$f18", "$f20", "$f22", "$f24", "$f26", "$f28", "$f30"
  );
  RECOVER_REG;
}

void WelsIChromaPredV_mmi(uint8_t *pPred, uint8_t *pRef, int32_t kiStride) {
  __asm__ volatile (
    ".set       arch=loongson3a                           \n\t"
    PTR_SUBU   "%[pRef], %[pRef], %[kiStride]             \n\t"
    "gsldxc1    $f0, 0x0(%[pRef], $0)                     \n\t"
    "mov.d      $f2, $f0                                  \n\t"

    "gssqc1     $f2, $f0, 0x0(%[pPred])                   \n\t"
    "gssqc1     $f2, $f0, 0x10(%[pPred])                  \n\t"
    "gssqc1     $f2, $f0, 0x20(%[pPred])                  \n\t"
    "gssqc1     $f2, $f0, 0x30(%[pPred])                  \n\t"
    : [pPred]"+&r"((unsigned char *)pPred), [pRef]"+&r"((unsigned char *)pRef)
    : [kiStride]"r"((int)kiStride)
    : "memory", "$f0", "$f2"
  );
}

void WelsIChromaPredDc_mmi(uint8_t *pPred, uint8_t *pRef, int32_t kiStride) {
  short mmi_0x02[4]__attribute__((aligned(16))) = {2, 0, 0, 0};
  unsigned char mmi_01bytes[16]__attribute__((aligned(16))) =
                {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1};
  __asm__ volatile (
    ".set       arch=loongson3a                           \n\t"
    PTR_SUBU   "%[pRef], %[pRef], %[kiStride]             \n\t"
    "gsldxc1    $f0, 0x0(%[pRef], $0)                     \n\t"

    PTR_ADDU   "%[pRef], %[pRef], %[kiStride]             \n\t"
    "lbu        $8, -0x1(%[pRef])                         \n\t"
    PTR_ADDU   "%[pRef], %[pRef], %[kiStride]             \n\t"
    "lbu        $9, -0x1(%[pRef])                         \n\t"
    PTR_ADDU   "$8, $8, $9                                \n\t"
    PTR_ADDU   "%[pRef], %[pRef], %[kiStride]             \n\t"
    "lbu        $9, -0x1(%[pRef])                         \n\t"
    PTR_ADDU   "$8, $8, $9                                \n\t"
    PTR_ADDU   "%[pRef], %[pRef], %[kiStride]             \n\t"
    "lbu        $9, -0x1(%[pRef])                         \n\t"
    PTR_ADDU   "$8, $8, $9                                \n\t"
    "dmtc1      $8, $f2                                   \n\t"

    PTR_ADDU   "%[pRef], %[pRef], %[kiStride]             \n\t"
    "lbu        $8, -0x1(%[pRef])                         \n\t"
    PTR_ADDU   "%[pRef], %[pRef], %[kiStride]             \n\t"
    "lbu        $9, -0x1(%[pRef])                         \n\t"
    PTR_ADDU   "$8, $8, $9                                \n\t"
    PTR_ADDU   "%[pRef], %[pRef], %[kiStride]             \n\t"
    "lbu        $9, -0x1(%[pRef])                         \n\t"
    PTR_ADDU   "$8, $8, $9                                \n\t"
    PTR_ADDU   "%[pRef], %[pRef], %[kiStride]             \n\t"
    "lbu        $9, -0x1(%[pRef])                         \n\t"
    PTR_ADDU   "$8, $8, $9                                \n\t"
    "dmtc1      $8, $f4                                   \n\t"

    "xor        $f8, $f8, $f8                             \n\t"
    "punpcklwd  $f6, $f0, $f8                             \n\t"
    "punpckhwd  $f0, $f0, $f8                             \n\t"
    "pasubub    $f0, $f0, $f8                             \n\t"
    "pasubub    $f6, $f6, $f8                             \n\t"
    "biadd      $f0, $f0                                  \n\t"
    "biadd      $f6, $f6                                  \n\t"

    "dadd       $f6, $f6, $f2                             \n\t"
    "dadd       $f2, $f4, $f0                             \n\t"

    "gsldxc1    $f8, 0x0(%[mmi_0x02], $0)                 \n\t"

    "dli        $10, 0x2                                  \n\t"
    "dmtc1      $10, $f10                                 \n\t"
    "dadd       $f0, $f0, $f8                             \n\t"
    "dsrl       $f0, $f0, $f10                            \n\t"

    "dadd       $f4, $f4, $f8                             \n\t"
    "dsrl       $f4, $f4, $f10                            \n\t"

    "dli        $10, 0x3                                  \n\t"
    "dmtc1      $10, $f10                                 \n\t"
    "dadd       $f6, $f6, $f8                             \n\t"
    "dadd       $f6, $f6, $f8                             \n\t"
    "dsrl       $f6, $f6, $f10                            \n\t"

    "dadd       $f2, $f2, $f8                             \n\t"
    "dadd       $f2, $f2, $f8                             \n\t"
    "dsrl       $f2, $f2, $f10                            \n\t"

    "dli        $10, 0x20                                 \n\t"
    "dmtc1      $10, $f10                                 \n\t"
    "gsldxc1    $f12, 0x0(%[mmi_01bytes], $0)             \n\t"
    "pmuluw     $f0, $f0, $f12                            \n\t"
    "pmuluw     $f6, $f6, $f12                            \n\t"
    "dsll       $f0, $f0, $f10                            \n\t"
    "xor        $f0, $f0, $f6                             \n\t"

    "pmuluw     $f4, $f4, $f12                            \n\t"
    "pmuluw     $f2, $f2, $f12                            \n\t"
    "dsll       $f2, $f2, $f10                            \n\t"
    "xor        $f2, $f2, $f4                             \n\t"

    "gssdxc1    $f0, 0x0(%[pPred], $0)                    \n\t"
    "gssdxc1    $f0, 0x8(%[pPred], $0)                    \n\t"
    "gssdxc1    $f0, 0x10(%[pPred], $0)                   \n\t"
    "gssdxc1    $f0, 0x18(%[pPred], $0)                   \n\t"

    "gssdxc1    $f2, 0x20(%[pPred], $0)                   \n\t"
    "gssdxc1    $f2, 0x28(%[pPred], $0)                   \n\t"
    "gssdxc1    $f2, 0x30(%[pPred], $0)                   \n\t"
    "gssdxc1    $f2, 0x38(%[pPred], $0)                   \n\t"
    : [pPred]"+&r"((unsigned char *)pPred), [pRef]"+&r"((unsigned char *)pRef)
    : [kiStride]"r"((int)kiStride), [mmi_01bytes]"r"((unsigned char *)mmi_01bytes),
      [mmi_0x02]"r"((unsigned char *)mmi_0x02)
    : "memory", "$8", "$9", "$10", "$f0", "$f2", "$f4", "$f6", "$f8", "$f10", "$f12"
  );
}

void WelsIChromaPredH_mmi(uint8_t *pPred, uint8_t *pRef, int32_t kiStride) {
  unsigned char mmi_01bytes[16]__attribute__((aligned(16))) =
                {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1};
  __asm__ volatile (
    ".set       arch=loongson3a                           \n\t"
    "gsldxc1    $f2, 0x0(%[mmi_01bytes], $0)              \n\t"
    "dli        $8, 0x38                                  \n\t"
    "dmtc1      $8, $f4                                   \n\t"
    "xor        $f6, $f6, $f6                             \n\t"
    "gsldxc1    $f0, -0x8(%[pRef], $0)                    \n\t"
    "dsrl       $f0, $f0, $f4                             \n\t"

    "pmullh     $f0, $f0, $f2                             \n\t"
    "pshufh     $f0, $f0, $f6                             \n\t"
    "gssdxc1    $f0, 0x0(%[pPred], $0)                    \n\t"

    MMI_PRED_H_8X8_ONE_LINE($f0, $f2, $f4, $f6, %[pRef], %[pPred], 0x8)
    MMI_PRED_H_8X8_ONE_LINE($f0, $f2, $f4, $f6, %[pRef], %[pPred], 0x10)
    MMI_PRED_H_8X8_ONE_LINE($f0, $f2, $f4, $f6, %[pRef], %[pPred], 0x18)
    MMI_PRED_H_8X8_ONE_LINE($f0, $f2, $f4, $f6, %[pRef], %[pPred], 0x20)
    MMI_PRED_H_8X8_ONE_LINE($f0, $f2, $f4, $f6, %[pRef], %[pPred], 0x28)
    MMI_PRED_H_8X8_ONE_LINE($f0, $f2, $f4, $f6, %[pRef], %[pPred], 0x30)
    MMI_PRED_H_8X8_ONE_LINE($f0, $f2, $f4, $f6, %[pRef], %[pPred], 0x38)
   : [pPred]"+&r"((unsigned char *)pPred), [pRef]"+&r"((unsigned char *)pRef)
   : [kiStride]"r"((int)kiStride), [mmi_01bytes]"r"((unsigned char *)mmi_01bytes)
   : "memory", "$8", "$f0", "$f2", "$f4", "$f6"
  );
}
