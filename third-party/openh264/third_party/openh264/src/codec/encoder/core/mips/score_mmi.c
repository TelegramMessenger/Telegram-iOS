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
 * \file    score_mmi.c
 *
 * \brief   Loongson optimization
 *
 * \date    21/07/2018 Created
 *
 *************************************************************************************
 */
#include <stdint.h>
#include "asmdefs_mmi.h"

unsigned char nozero_count_table[] __attribute__((aligned(16))) = {
    0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4, 1, 2, 2, 3, 2, 3, 3, 4,
    2, 3, 3, 4, 3, 4, 4, 5, 1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5,
    2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6, 1, 2, 2, 3, 2, 3, 3, 4,
    2, 3, 3, 4, 3, 4, 4, 5, 2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6,
    2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6, 3, 4, 4, 5, 4, 5, 5, 6,
    4, 5, 5, 6, 5, 6, 6, 7, 1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5,
    2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6, 2, 3, 3, 4, 3, 4, 4, 5,
    3, 4, 4, 5, 4, 5, 5, 6, 3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7,
    2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6, 3, 4, 4, 5, 4, 5, 5, 6,
    4, 5, 5, 6, 5, 6, 6, 7, 3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7,
    4, 5, 5, 6, 5, 6, 6, 7, 5, 6, 6, 7, 6, 7, 7, 8};

int32_t WelsGetNoneZeroCount_mmi(int16_t *level) {
  int ret_val = 0;
  __asm__ volatile(
    ".set       arch=loongson3a                 \n\t"
    "gslqc1     $f2, $f0, 0x0(%[level])         \n\t"
    "gslqc1     $f6, $f4, 0x10(%[level])        \n\t"
    "xor        $f8, $f8, $f8                   \n\t"
    "pcmpeqh    $f0, $f0, $f8                   \n\t"
    "pcmpeqh    $f2, $f2, $f8                   \n\t"
    "pcmpeqh    $f4, $f4, $f8                   \n\t"
    "pcmpeqh    $f6, $f6, $f8                   \n\t"
    "packsshb   $f4, $f4, $f6                   \n\t"
    "packsshb   $f6, $f0, $f2                   \n\t"
    "pmovmskb   $f0, $f4                        \n\t"
    "pmovmskb   $f2, $f6                        \n\t"
    "dmfc1      $8, $f0                         \n\t"
    "dmfc1      $9, $f2                         \n\t"
    "xor        $8, 0xFF                        \n\t"
    "xor        $9, 0xFF                        \n\t"
    PTR_ADDU   "$10, $8, %[nozero_count_table]  \n\t"
    "lbu        $8, 0x0($10)                    \n\t"
    PTR_ADDU   "$10, $9, %[nozero_count_table]  \n\t"
    "lbu        $9, 0x0($10)                    \n\t"
    PTR_ADDU   "%[ret_val], $8, $9              \n\t"
    : [ret_val] "=r"((int)ret_val)
    : [level] "r"((unsigned char *)level),
      [nozero_count_table] "r"((unsigned char *)nozero_count_table)
    : "memory", "$8", "$9", "$10", "$f0", "$f2", "$f4", "$f6", "$f8"
  );
  return ret_val;
}

void WelsScan4x4DcAc_mmi(int16_t level[16], int16_t *pDct) {
  BACKUP_REG;
  __asm__ volatile(
    ".set       arch=loongson3a                 \n\t"
    "gslqc1     $f2, $f0, 0x0(%[pDct])          \n\t"
    "gslqc1     $f6, $f4, 0x10(%[pDct])         \n\t"
    "dli        $8, 0x3                         \n\t"
    "dmtc1      $8, $f22                        \n\t"
    "dli        $8, 0x2                         \n\t"
    "dmtc1      $8, $f24                        \n\t"
    "dli        $8, 0x1                         \n\t"
    "dmtc1      $8, $f26                        \n\t"
    "dmtc1      $0, $f28                        \n\t"
    "pextrh     $f18, $f2, $f22                 \n\t"
    "pextrh     $f20, $f4, $f24                 \n\t"
    "pextrh     $f16, $f2, $f26                 \n\t"
    "pinsrh_2   $f4, $f4, $f18                  \n\t"
    "pinsrh_3   $f2, $f2, $f16                  \n\t"
    "pextrh     $f18, $f4, $f28                 \n\t"
    "pinsrh_1   $f2, $f2, $f18                  \n\t"
    "pinsrh_0   $f4, $f4, $f20                  \n\t"
    "dli        $8, 0x93                        \n\t"
    "dmtc1      $8, $f22                        \n\t"
    "dli        $8, 0x39                        \n\t"
    "dmtc1      $8, $f24                        \n\t"
    "punpckhwd  $f10, $f0, $f2                  \n\t"
    "punpcklwd  $f8, $f0, $f2                   \n\t"
    "punpckhwd  $f14, $f4, $f6                  \n\t"
    "punpcklwd  $f12, $f4, $f6                  \n\t"
    "mov.d      $f0, $f8                        \n\t"
    "pshufh     $f2, $f10, $f22                 \n\t"
    "pshufh     $f4, $f12, $f24                 \n\t"
    "mov.d      $f6, $f14                       \n\t"
    "gssqc1     $f2, $f0, 0x0(%[level])         \n\t"
    "gssqc1     $f6, $f4, 0x10(%[level])        \n\t"
    :
    : [level] "r"((short *)level), [pDct] "r"((short *)pDct)
    : "memory", "$8", "$f0", "$f2", "$f4", "$f6", "$f8", "$f10", "$f12",
      "$f14", "$f16", "$f18", "$f20", "$f22", "$f24", "$f26", "$f28"
  );
  RECOVER_REG;
}

void WelsScan4x4Ac_mmi(int16_t *zig_value, int16_t *pDct) {
  BACKUP_REG;
  __asm__ volatile(
    ".set       arch=loongson3a                 \n\t"
    "gslqc1     $f2, $f0, 0x0(%[pDct])          \n\t"
    "gslqc1     $f6, $f4, 0x10(%[pDct])         \n\t"
    "mov.d      $f8, $f2                        \n\t"
    "mov.d      $f2, $f4                        \n\t"
    "mov.d      $f10, $f6                       \n\t"

    "mov.d      $f12, $f2                       \n\t"
    "punpckhwd  $f2, $f0, $f8                   \n\t"
    "punpcklwd  $f0, $f0, $f8                   \n\t"
    "punpckhwd  $f14, $f12, $f10                \n\t"
    "punpcklwd  $f12, $f12, $f10                \n\t"

    "dmtc1      $0, $f20                        \n\t"
    "dli        $8, 0x10                        \n\t"
    "dmtc1      $8, $f22                        \n\t"
    "dli        $8, 0x30                        \n\t"
    "dmtc1      $8, $f24                        \n\t"
    "dli        $8, 0x3                         \n\t"
    "dmtc1      $8, $f26                        \n\t"
    "dli        $8, 0x93                        \n\t"
    "dmtc1      $8, $f28                        \n\t"
    "dli        $8, 0x39                        \n\t"
    "dmtc1      $8, $f30                        \n\t"
    "pextrh     $f16, $f0, $f26                 \n\t"
    "pextrh     $f18, $f2, $f26                 \n\t"
    "pinsrh_3   $f2, $f2, $f16                  \n\t"
    "pextrh     $f16, $f14, $f20                \n\t"
    "pinsrh_0   $f14, $f14, $f18                \n\t"
    "pextrh     $f18, $f12, $f20                \n\t"
    "pinsrh_0   $f12, $f12, $f16                \n\t"
    "pinsrh_3   $f0, $f0, $f18                  \n\t"

    "mov.d      $f4, $f0                        \n\t"
    "pshufh     $f6, $f2, $f28                  \n\t"
    "pshufh     $f8, $f12, $f30                 \n\t"
    "mov.d      $f10, $f14                      \n\t"

    "mov.d      $f12, $f8                       \n\t"
    "mov.d      $f14, $f10                      \n\t"
    "dsrl       $f4, $f4, $f22                  \n\t"
    "pinsrh_3   $f4, $f4, $f6                   \n\t"
    "dsrl       $f6, $f6, $f22                  \n\t"
    "dsll       $f14, $f12, $f24                \n\t"
    "xor        $f12, $f12, $f12                \n\t"
    "or         $f4, $f4, $f12                  \n\t"
    "or         $f6, $f6, $f14                  \n\t"
    "dsrl       $f8, $f8, $f22                  \n\t"
    "pinsrh_3   $f8, $f8, $f10                  \n\t"
    "dsrl       $f10, $f10, $f22                \n\t"
    "gssqc1     $f6, $f4, 0x0(%[zig_value])     \n\t"
    "gssqc1     $f10, $f8, 0x10(%[zig_value])   \n\t"
    :
    : [zig_value] "r"((short *)zig_value), [pDct] "r"((short *)pDct)
    : "memory", "$8", "$f0", "$f2", "$f4", "$f6", "$f8", "$f10", "$f12",
      "$f14", "$f16", "$f18", "$f20", "$f22", "$f24", "$f26", "$f28", "$f30"
  );
  RECOVER_REG;
}

unsigned char i_ds_table[]__attribute__((aligned(16))) = {
      3, 2, 2, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
unsigned char high_mask_table[]__attribute__((aligned(16))) = {
      0, 0, 0, 3, 0, 2, 3, 6, 0, 2,
      2, 5, 3, 5, 6, 9, 0, 1, 2, 5,
      2, 4, 5, 8, 3, 5, 5, 8, 6, 8,
      9,12, 0, 1, 1, 4, 2, 4, 5, 8,
      2, 4, 4, 7, 5, 7, 8,11, 3, 4,
      5, 8, 5, 7, 8,11, 6, 8, 8,11,
      9,11,12,15, 0, 1, 1, 4, 1, 3,
      4, 7, 2, 4, 4, 7, 5, 7, 8,11,
      2, 3, 4, 7, 4, 6, 7,10, 5, 7,
      7,10, 8,10,11,14, 3, 4, 4, 7,
      5, 7, 8,11, 5, 7, 7,10, 8,10,
     11,14, 6, 7, 8,11, 8,10,11,14,
      9,11,11,14,12,14,15,18, 0, 0,
      1, 4, 1, 3, 4, 7, 1, 3, 3, 6,
      4, 6, 7,10, 2, 3, 4, 7, 4, 6,
      7,10, 5, 7, 7,10, 8,10,11,14,
      2, 3, 3, 6, 4, 6, 7,10, 4, 6,
      6, 9, 7, 9,10,13, 5, 6, 7,10,
      7, 9,10,13, 8,10,10,13,11,13,
     14,17, 3, 4, 4, 7, 4, 6, 7,10,
      5, 7, 7,10, 8,10,11,14, 5, 6,
      7,10, 7, 9,10,13, 8,10,10,13,
     11,13,14,17, 6, 7, 7,10, 8,10,
     11,14, 8,10,10,13,11,13,14,17,
      9,10,11,14,11,13,14,17,12,14,
     14,17,15,17,18,21};

unsigned char low_mask_table[]__attribute__((aligned(16))) = {
      0, 3, 2, 6, 2, 5, 5, 9, 1, 5,
      4, 8, 5, 8, 8,12, 1, 4, 4, 8,
      4, 7, 7,11, 4, 8, 7,11, 8,11,
     11,15, 1, 4, 3, 7, 4, 7, 7,11,
      3, 7, 6,10, 7,10,10,14, 4, 7,
      7,11, 7,10,10,14, 7,11,10,14,
     11,14,14,18, 0, 4, 3, 7, 3, 6,
      6,10, 3, 7, 6,10, 7,10,10,14,
      3, 6, 6,10, 6, 9, 9,13, 6,10,
      9,13,10,13,13,17, 4, 7, 6,10,
      7,10,10,14, 6,10, 9,13,10,13,
     13,17, 7,10,10,14,10,13,13,17,
     10,14,13,17,14,17,17,21, 0, 3,
      3, 7, 3, 6, 6,10, 2, 6, 5, 9,
      6, 9, 9,13, 3, 6, 6,10, 6, 9,
      9,13, 6,10, 9,13,10,13,13,17,
      3, 6, 5, 9, 6, 9, 9,13, 5, 9,
      8,12, 9,12,12,16, 6, 9, 9,13,
      9,12,12,16, 9,13,12,16,13,16,
     16,20, 3, 7, 6,10, 6, 9, 9,13,
      6,10, 9,13,10,13,13,17, 6, 9,
      9,13, 9,12,12,16, 9,13,12,16,
     13,16,16,20, 7,10, 9,13,10,13,
     13,17, 9,13,12,16,13,16,16,20,
     10,13,13,17,13,16,16,20,13,17,
     16,20,17,20,20,24};

int32_t WelsCalculateSingleCtr4x4_mmi(int16_t *pDct) {
  int32_t iSingleCtr = 0;
  __asm__ volatile(
    ".set       arch=loongson3a                 \n\t"
    "gslqc1     $f2, $f0, 0x0(%[pDct])          \n\t"
    "gslqc1     $f6, $f4, 0x10(%[pDct])         \n\t"
    "packsshb   $f0, $f0, $f2                   \n\t"
    "packsshb   $f2, $f4, $f6                   \n\t"

    "xor        $f10, $f10, $f10                \n\t"
    "xor        $f8, $f8, $f8                   \n\t"

    "pcmpeqb    $f0, $f0, $f8                   \n\t"
    "pcmpeqb    $f2, $f2, $f8                   \n\t"

    "pmovmskb   $f10, $f0                       \n\t"
    "pmovmskb   $f12, $f2                       \n\t"
    "punpcklbh  $f10, $f10, $f12                \n\t"

    "dmfc1      $12, $f10                       \n\t"
    "dli        $8, 0xffff                      \n\t"
    "xor        $12, $12, $8                    \n\t"

    "xor        %[pDct], %[pDct], %[pDct]       \n\t"
    "dli        $8, 0x80                        \n\t"
    "dli        $9, 0x7                         \n\t"
    "dli        $10, 0x100                      \n\t"
    "dli        $11, 0x8                        \n\t"

    "1:                                         \n\t"
    "and        $13, $12, $8                    \n\t"
    "bnez       $13, 2f                         \n\t"
    "nop                                        \n\t"
    "daddiu     $9, -0x1                        \n\t"
    "dsrl       $8, 1                           \n\t"
    "bnez       $9, 1b                          \n\t"
    "nop                                        \n\t"
    "2:                                         \n\t"
    "and        $13, $12, $10                   \n\t"
    "bnez       $13, 3f                         \n\t"
    "nop                                        \n\t"
    "daddiu     $11, 0x1                        \n\t"
    "dsll       $10, 1                          \n\t"
    "daddiu     $13, $11, -0x10                 \n\t"
    "bltz       $13, 2b                         \n\t"
    "nop                                        \n\t"
    "3:                                         \n\t"
    "dsubu      $11, $11, $9                    \n\t"
    "daddiu     $11, -0x1                       \n\t"
    PTR_ADDU   "$8, %[i_ds_table], $11          \n\t"
    "lb         $10, 0x0($8)                    \n\t"
    PTR_ADDU   "%[pDct], %[pDct], $10           \n\t"
    "move       $11, $12                        \n\t"
    "dli        $10, 0xff                       \n\t"
    "and        $12, $10                        \n\t"
    "dsrl       $11, 0x8                        \n\t"
    "and        $11, $10                        \n\t"
    PTR_ADDU   "$8, %[low_mask_table], $12      \n\t"
    "lb         $10, 0x0($8)                    \n\t"
    PTR_ADDU   "%[pDct], %[pDct], $10           \n\t"
    PTR_ADDU   "$8, %[high_mask_table], $11     \n\t"
    "lb         $10, 0x0($8)                    \n\t"
    PTR_ADDU   "%[iSingleCtr], %[pDct], $10     \n\t"
    : [iSingleCtr] "=r"(iSingleCtr)
    : [pDct] "r"((short *)pDct),
      [i_ds_table] "r"((unsigned char *)i_ds_table),
      [high_mask_table] "r"((unsigned char *)high_mask_table),
      [low_mask_table] "r"((unsigned char *)low_mask_table)
    : "memory", "$8", "$9", "$10", "$11", "$12", "$13", "$f0", "$f2", "$f4",
      "$f6", "$f8", "$f10", "$f12"
  );
  return iSingleCtr;
}
