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
 * \file    satd_sad_mmi.c
 *
 * \brief   Loongson optimization
 *
 * \date    23/07/2018 Created
 *
 *************************************************************************************
 */
#include <stdint.h>
#include "asmdefs_mmi.h"

#define MMI_SumWHorizon1(f0, f2, f4, f6, f8, f10, r0) \
  "dli        "#r0", 0x10                               \n\t" \
  "dmtc1      "#r0", "#f8"                              \n\t" \
  "dli        "#r0", 0x20                               \n\t" \
  "dmtc1      "#r0", "#f10"                             \n\t" \
  "mov.d      "#f4", "#f2"                              \n\t" \
  "xor        "#f6", "#f6", "#f6"                       \n\t" \
  "paddush    "#f0", "#f0", "#f4"                       \n\t" \
  "paddush    "#f2", "#f2", "#f6"                       \n\t" \
  "dsrl       "#f6", "#f2", "#f10"                      \n\t" \
  "punpcklwd  "#f4", "#f2", "#f2"                       \n\t" \
  "punpckhwd  "#f4", "#f0", "#f4"                       \n\t" \
  "paddush    "#f0", "#f0", "#f4"                       \n\t" \
  "paddush    "#f2", "#f2", "#f6"                       \n\t" \
  "dsrl       "#f4", "#f0", "#f8"                       \n\t" \
  "pinsrh_3   "#f4", "#f4", "#f2"                       \n\t" \
  "dsrl       "#f6", "#f2", "#f8"                       \n\t" \
  "paddush    "#f0", "#f0", "#f4"                       \n\t" \
  "paddush    "#f2", "#f2", "#f6"                       \n\t"

#define MMI_GetSad8x4 \
  PTR_ADDU   "$8, %[pSample1], %[iStride1]              \n\t" \
  "gsldlc1    $f0, 0x7(%[pSample1])                     \n\t" \
  "gsldlc1    $f4, 0x7($8)                              \n\t" \
  "gsldrc1    $f0, 0x0(%[pSample1])                     \n\t" \
  "gsldrc1    $f4, 0x0($8)                              \n\t" \
  PTR_ADDU   "%[pSample1], $8, %[iStride1]              \n\t" \
  PTR_ADDU   "$8, %[pSample1], %[iStride1]              \n\t" \
  "gsldlc1    $f2, 0x7(%[pSample1])                     \n\t" \
  "gsldlc1    $f6, 0x7($8)                              \n\t" \
  "gsldlc1    $f8, 0x7(%[pSample2])                     \n\t" \
  "gsldrc1    $f2, 0x0(%[pSample1])                     \n\t" \
  "gsldrc1    $f6, 0x0($8)                              \n\t" \
  "gsldrc1    $f8, 0x0(%[pSample2])                     \n\t" \
  PTR_ADDU   "$9, %[pSample2], %[iStride2]              \n\t" \
  PTR_ADDU   "%[pSample2], $9, %[iStride2]              \n\t" \
  "gsldlc1    $f12, 0x7($9)                             \n\t" \
  "gsldlc1    $f10, 0x7(%[pSample2])                    \n\t" \
  "gsldrc1    $f12, 0x0($9)                             \n\t" \
  PTR_ADDU   "$9, %[pSample2], %[iStride2]              \n\t" \
  "gsldrc1    $f10, 0x0(%[pSample2])                    \n\t" \
  "gsldlc1    $f14, 0x7($9)                             \n\t" \
  "gsldrc1    $f14, 0x0($9)                             \n\t" \
  "pasubub    $f0, $f0, $f8                             \n\t" \
  PTR_ADDU   "%[pSample1], $8, %[iStride1]              \n\t" \
  "pasubub    $f2, $f2, $f10                            \n\t" \
  "biadd      $f0, $f0                                  \n\t" \
  "biadd      $f2, $f2                                  \n\t" \
  "pasubub    $f4, $f4, $f12                            \n\t" \
  PTR_ADDU   "%[pSample2], $9, %[iStride2]              \n\t" \
  "pasubub    $f6, $f6, $f14                            \n\t" \
  "biadd      $f4, $f4                                  \n\t" \
  "biadd      $f6, $f6                                  \n\t" \
  "paddh      $f24, $f24, $f0                           \n\t" \
  "paddh      $f26, $f26, $f2                           \n\t" \
  "paddh      $f24, $f24, $f4                           \n\t" \
  "paddh      $f26, $f26, $f6                           \n\t"

#define MMI_GetSad8x4_End \
  PTR_ADDU   "$8, %[pSample1], %[iStride1]              \n\t" \
  "gsldlc1    $f0, 0x7(%[pSample1])                     \n\t" \
  "gsldlc1    $f4, 0x7($8)                              \n\t" \
  "gsldrc1    $f0, 0x0(%[pSample1])                     \n\t" \
  "gsldrc1    $f4, 0x0($8)                              \n\t" \
  PTR_ADDU   "%[pSample1], $8, %[iStride1]              \n\t" \
  PTR_ADDU   "$8, %[pSample1], %[iStride1]              \n\t" \
  "gsldlc1    $f2, 0x7(%[pSample1])                     \n\t" \
  "gsldlc1    $f6, 0x7($8)                              \n\t" \
  "gsldlc1    $f8, 0x7(%[pSample2])                     \n\t" \
  "gsldrc1    $f2, 0x0(%[pSample1])                     \n\t" \
  "gsldrc1    $f6, 0x0($8)                              \n\t" \
  "gsldrc1    $f8, 0x0(%[pSample2])                     \n\t" \
  PTR_ADDU   "$9, %[pSample2], %[iStride2]              \n\t" \
  PTR_ADDU   "%[pSample2], $9, %[iStride2]              \n\t" \
  "gsldlc1    $f12, 0x7($9)                             \n\t" \
  "gsldlc1    $f10, 0x7(%[pSample2])                    \n\t" \
  "gsldrc1    $f12, 0x0($9)                             \n\t" \
  PTR_ADDU   "$9, %[pSample2], %[iStride2]              \n\t" \
  "gsldrc1    $f10, 0x0(%[pSample2])                    \n\t" \
  "gsldlc1    $f14, 0x7($9)                             \n\t" \
  "gsldrc1    $f14, 0x0($9)                             \n\t" \
  "pasubub    $f0, $f0, $f8                             \n\t" \
  "pasubub    $f2, $f2, $f10                            \n\t" \
  "biadd      $f0, $f0                                  \n\t" \
  "biadd      $f2, $f2                                  \n\t" \
  "pasubub    $f4, $f4, $f12                            \n\t" \
  "pasubub    $f6, $f6, $f14                            \n\t" \
  "biadd      $f4, $f4                                  \n\t" \
  "biadd      $f6, $f6                                  \n\t" \
  "paddh      $f24, $f24, $f0                           \n\t" \
  "paddh      $f26, $f26, $f2                           \n\t" \
  "paddh      $f24, $f24, $f4                           \n\t" \
  "paddh      $f26, $f26, $f6                           \n\t"

#define CACHE_SPLIT_CHECK(r0, width, cacheline) \
  "and        "#r0", "#r0", 0x1f                        \n\t" \
  PTR_ADDIU  ""#r0", "#r0", -0x1f                       \n\t"

#define MMI_GetSad2x16 \
  PTR_ADDU   "%[pSample1], %[pSample1], %[iStride1]     \n\t" \
  PTR_ADDU   "%[pSample2], %[pSample2], %[iStride2]     \n\t" \
  "gsldlc1    $f4, 0x7(%[pSample2])                     \n\t" \
  "gsldlc1    $f6, 0xF(%[pSample2])                     \n\t" \
  "gsldrc1    $f4, 0x0(%[pSample2])                     \n\t" \
  "gsldrc1    $f6, 0x8(%[pSample2])                     \n\t" \
  "gslqc1     $f10, $f8, 0x0(%[pSample1])               \n\t" \
  "pasubub    $f4, $f4, $f8                             \n\t" \
  "pasubub    $f6, $f6, $f10                            \n\t" \
  "biadd      $f4, $f4                                  \n\t" \
  "biadd      $f6, $f6                                  \n\t" \
  "paddh      $f0, $f0, $f4                             \n\t" \
  "paddh      $f2, $f2, $f6                             \n\t" \
  PTR_ADDU   "%[pSample2], %[pSample2], %[iStride2]     \n\t" \
  "gsldlc1    $f4, 0x7(%[pSample2])                     \n\t" \
  "gsldlc1    $f6, 0xF(%[pSample2])                     \n\t" \
  "gsldrc1    $f4, 0x0(%[pSample2])                     \n\t" \
  "gsldrc1    $f6, 0x8(%[pSample2])                     \n\t" \
  PTR_ADDU   "%[pSample1], %[pSample1], %[iStride1]     \n\t" \
  "gslqc1     $f10, $f8, 0x0(%[pSample1])               \n\t" \
  "pasubub    $f4, $f4, $f8                             \n\t" \
  "pasubub    $f6, $f6, $f10                            \n\t" \
  "biadd      $f4, $f4                                  \n\t" \
  "biadd      $f6, $f6                                  \n\t" \
  "paddh      $f0, $f0, $f4                             \n\t" \
  "paddh      $f2, $f2, $f6                             \n\t"

#define MMI_GetSad4x16 \
  "gsldlc1    $f0, 0x7(%[pSample2])                     \n\t" \
  "gsldlc1    $f2, 0xF(%[pSample2])                     \n\t" \
  "gsldrc1    $f0, 0x0(%[pSample2])                     \n\t" \
  "gsldrc1    $f2, 0x8(%[pSample2])                     \n\t" \
  "gslqc1     $f10, $f8, 0x0(%[pSample1])               \n\t" \
  PTR_ADDU   "%[pSample2], %[pSample2], %[iStride2]     \n\t" \
  PTR_ADDU   "%[pSample1], %[pSample1], %[iStride1]     \n\t" \
  "pasubub    $f0, $f0, $f8                             \n\t" \
  "pasubub    $f2, $f2, $f10                            \n\t" \
  "biadd      $f0, $f0                                  \n\t" \
  "biadd      $f2, $f2                                  \n\t" \
  "paddh      $f28, $f28, $f0                           \n\t" \
  "paddh      $f30, $f30, $f2                           \n\t" \
  "gsldlc1    $f4, 0x7(%[pSample2])                     \n\t" \
  "gsldlc1    $f6, 0xF(%[pSample2])                     \n\t" \
  "gsldrc1    $f4, 0x0(%[pSample2])                     \n\t" \
  "gsldrc1    $f6, 0x8(%[pSample2])                     \n\t" \
  "gslqc1     $f10, $f8, 0x0(%[pSample1])               \n\t" \
  PTR_ADDU   "%[pSample2], %[pSample2], %[iStride2]     \n\t" \
  PTR_ADDU   "%[pSample1], %[pSample1], %[iStride1]     \n\t" \
  "pasubub    $f4, $f4, $f8                             \n\t" \
  "pasubub    $f6, $f6, $f10                            \n\t" \
  "biadd      $f4, $f4                                  \n\t" \
  "biadd      $f6, $f6                                  \n\t" \
  "paddh      $f28, $f28, $f4                           \n\t" \
  "paddh      $f30, $f30, $f6                           \n\t" \
  "gsldlc1    $f4, 0x7(%[pSample2])                     \n\t" \
  "gsldlc1    $f6, 0xF(%[pSample2])                     \n\t" \
  "gsldrc1    $f4, 0x0(%[pSample2])                     \n\t" \
  "gsldrc1    $f6, 0x8(%[pSample2])                     \n\t" \
  "gslqc1     $f10, $f8, 0x0(%[pSample1])               \n\t" \
  PTR_ADDU   "%[pSample2], %[pSample2], %[iStride2]     \n\t" \
  PTR_ADDU   "%[pSample1], %[pSample1], %[iStride1]     \n\t" \
  "pasubub    $f4, $f4, $f8                             \n\t" \
  "pasubub    $f6, $f6, $f10                            \n\t" \
  "biadd      $f4, $f4                                  \n\t" \
  "biadd      $f6, $f6                                  \n\t" \
  "paddh      $f28, $f28, $f4                           \n\t" \
  "paddh      $f30, $f30, $f6                           \n\t" \
  "gsldlc1    $f4, 0x7(%[pSample2])                     \n\t" \
  "gsldlc1    $f6, 0xF(%[pSample2])                     \n\t" \
  "gsldrc1    $f4, 0x0(%[pSample2])                     \n\t" \
  "gsldrc1    $f6, 0x8(%[pSample2])                     \n\t" \
  "gslqc1     $f10, $f8, 0x0(%[pSample1])               \n\t" \
  PTR_ADDU   "%[pSample2], %[pSample2], %[iStride2]     \n\t" \
  PTR_ADDU   "%[pSample1], %[pSample1], %[iStride1]     \n\t" \
  "pasubub    $f4, $f4, $f8                             \n\t" \
  "pasubub    $f6, $f6, $f10                            \n\t" \
  "biadd      $f4, $f4                                  \n\t" \
  "biadd      $f6, $f6                                  \n\t" \
  "paddh      $f28, $f28, $f4                           \n\t" \
  "paddh      $f30, $f30, $f6                           \n\t"

#define MMI_GetSad4x16_Aligned \
  "gslqc1     $f2, $f0, 0x0(%[pSample2])                \n\t" \
  "gslqc1     $f10, $f8, 0x0(%[pSample1])               \n\t" \
  PTR_ADDU   "%[pSample2], %[pSample2], %[iStride2]     \n\t" \
  PTR_ADDU   "%[pSample1], %[pSample1], %[iStride1]     \n\t" \
  "pasubub    $f0, $f0, $f8                             \n\t" \
  "pasubub    $f2, $f2, $f10                            \n\t" \
  "biadd      $f0, $f0                                  \n\t" \
  "biadd      $f2, $f2                                  \n\t" \
  "paddh      $f28, $f28, $f0                           \n\t" \
  "paddh      $f30, $f30, $f2                           \n\t" \
  "gslqc1     $f6, $f4, 0x0(%[pSample2])                \n\t" \
  "gslqc1     $f10, $f8, 0x0(%[pSample1])               \n\t" \
  PTR_ADDU   "%[pSample2], %[pSample2], %[iStride2]     \n\t" \
  PTR_ADDU   "%[pSample1], %[pSample1], %[iStride1]     \n\t" \
  "pasubub    $f4, $f4, $f8                             \n\t" \
  "pasubub    $f6, $f6, $f10                            \n\t" \
  "biadd      $f4, $f4                                  \n\t" \
  "biadd      $f6, $f6                                  \n\t" \
  "paddh      $f28, $f28, $f4                           \n\t" \
  "paddh      $f30, $f30, $f6                           \n\t" \
  "gslqc1     $f6, $f4, 0x0(%[pSample2])                \n\t" \
  "gslqc1     $f10, $f8, 0x0(%[pSample1])               \n\t" \
  PTR_ADDU   "%[pSample2], %[pSample2], %[iStride2]     \n\t" \
  PTR_ADDU   "%[pSample1], %[pSample1], %[iStride1]     \n\t" \
  "pasubub    $f4, $f4, $f8                             \n\t" \
  "pasubub    $f6, $f6, $f10                            \n\t" \
  "biadd      $f4, $f4                                  \n\t" \
  "biadd      $f6, $f6                                  \n\t" \
  "paddh      $f28, $f28, $f4                           \n\t" \
  "paddh      $f30, $f30, $f6                           \n\t" \
  "gslqc1     $f6, $f4, 0x0(%[pSample2])                \n\t" \
  "gslqc1     $f10, $f8, 0x0(%[pSample1])               \n\t" \
  PTR_ADDU   "%[pSample2], %[pSample2], %[iStride2]     \n\t" \
  PTR_ADDU   "%[pSample1], %[pSample1], %[iStride1]     \n\t" \
  "pasubub    $f4, $f4, $f8                             \n\t" \
  "pasubub    $f6, $f6, $f10                            \n\t" \
  "biadd      $f4, $f4                                  \n\t" \
  "biadd      $f6, $f6                                  \n\t" \
  "paddh      $f28, $f28, $f4                           \n\t" \
  "paddh      $f30, $f30, $f6                           \n\t"

#define MMI_GetSad4x16_End \
  "gsldlc1    $f0, 0x7(%[pSample2])                     \n\t" \
  "gsldlc1    $f2, 0xF(%[pSample2])                     \n\t" \
  "gsldrc1    $f0, 0x0(%[pSample2])                     \n\t" \
  "gsldrc1    $f2, 0x8(%[pSample2])                     \n\t" \
  "gslqc1     $f10, $f8, 0x0(%[pSample1])               \n\t" \
  PTR_ADDU   "%[pSample2], %[pSample2], %[iStride2]     \n\t" \
  PTR_ADDU   "%[pSample1], %[pSample1], %[iStride1]     \n\t" \
  "pasubub    $f0, $f0, $f8                             \n\t" \
  "pasubub    $f2, $f2, $f10                            \n\t" \
  "biadd      $f0, $f0                                  \n\t" \
  "biadd      $f2, $f2                                  \n\t" \
  "paddh      $f28, $f28, $f0                           \n\t" \
  "paddh      $f30, $f30, $f2                           \n\t" \
  "gsldlc1    $f4, 0x7(%[pSample2])                     \n\t" \
  "gsldlc1    $f6, 0xF(%[pSample2])                     \n\t" \
  "gsldrc1    $f4, 0x0(%[pSample2])                     \n\t" \
  "gsldrc1    $f6, 0x8(%[pSample2])                     \n\t" \
  "gslqc1     $f10, $f8, 0x0(%[pSample1])               \n\t" \
  PTR_ADDU   "%[pSample2], %[pSample2], %[iStride2]     \n\t" \
  PTR_ADDU   "%[pSample1], %[pSample1], %[iStride1]     \n\t" \
  "pasubub    $f4, $f4, $f8                             \n\t" \
  "pasubub    $f6, $f6, $f10                            \n\t" \
  "biadd      $f4, $f4                                  \n\t" \
  "biadd      $f6, $f6                                  \n\t" \
  "paddh      $f28, $f28, $f4                           \n\t" \
  "paddh      $f30, $f30, $f6                           \n\t" \
  "gsldlc1    $f4, 0x7(%[pSample2])                     \n\t" \
  "gsldlc1    $f6, 0xF(%[pSample2])                     \n\t" \
  "gsldrc1    $f4, 0x0(%[pSample2])                     \n\t" \
  "gsldrc1    $f6, 0x8(%[pSample2])                     \n\t" \
  "gslqc1     $f10, $f8, 0x0(%[pSample1])               \n\t" \
  PTR_ADDU   "%[pSample2], %[pSample2], %[iStride2]     \n\t" \
  PTR_ADDU   "%[pSample1], %[pSample1], %[iStride1]     \n\t" \
  "pasubub    $f4, $f4, $f8                             \n\t" \
  "pasubub    $f6, $f6, $f10                            \n\t" \
  "biadd      $f4, $f4                                  \n\t" \
  "biadd      $f6, $f6                                  \n\t" \
  "paddh      $f28, $f28, $f4                           \n\t" \
  "paddh      $f30, $f30, $f6                           \n\t" \
  "gsldlc1    $f4, 0x7(%[pSample2])                     \n\t" \
  "gsldlc1    $f6, 0xF(%[pSample2])                     \n\t" \
  "gsldrc1    $f4, 0x0(%[pSample2])                     \n\t" \
  "gsldrc1    $f6, 0x8(%[pSample2])                     \n\t" \
  "gslqc1     $f10, $f8, 0x0(%[pSample1])               \n\t" \
  "pasubub    $f4, $f4, $f8                             \n\t" \
  "pasubub    $f6, $f6, $f10                            \n\t" \
  "biadd      $f4, $f4                                  \n\t" \
  "biadd      $f6, $f6                                  \n\t" \
  "paddh      $f28, $f28, $f4                           \n\t" \
  "paddh      $f30, $f30, $f6                           \n\t"

#define MMI_GetSad4x16_Aligned_End \
  "gslqc1     $f2, $f0, 0x0(%[pSample2])                \n\t" \
  "gslqc1     $f10, $f8, 0x0(%[pSample1])               \n\t" \
  PTR_ADDU   "%[pSample2], %[pSample2], %[iStride2]     \n\t" \
  PTR_ADDU   "%[pSample1], %[pSample1], %[iStride1]     \n\t" \
  "pasubub    $f0, $f0, $f8                             \n\t" \
  "pasubub    $f2, $f2, $f10                            \n\t" \
  "biadd      $f0, $f0                                  \n\t" \
  "biadd      $f2, $f2                                  \n\t" \
  "paddh      $f28, $f28, $f0                           \n\t" \
  "paddh      $f30, $f30, $f2                           \n\t" \
  "gslqc1     $f6, $f4, 0x0(%[pSample2])                \n\t" \
  "gslqc1     $f10, $f8, 0x0(%[pSample1])               \n\t" \
  PTR_ADDU   "%[pSample2], %[pSample2], %[iStride2]     \n\t" \
  PTR_ADDU   "%[pSample1], %[pSample1], %[iStride1]     \n\t" \
  "pasubub    $f4, $f4, $f8                             \n\t" \
  "pasubub    $f6, $f6, $f10                            \n\t" \
  "biadd      $f4, $f4                                  \n\t" \
  "biadd      $f6, $f6                                  \n\t" \
  "paddh      $f28, $f28, $f4                           \n\t" \
  "paddh      $f30, $f30, $f6                           \n\t" \
  "gslqc1     $f6, $f4, 0x0(%[pSample2])                \n\t" \
  "gslqc1     $f10, $f8, 0x0(%[pSample1])               \n\t" \
  PTR_ADDU   "%[pSample2], %[pSample2], %[iStride2]     \n\t" \
  PTR_ADDU   "%[pSample1], %[pSample1], %[iStride1]     \n\t" \
  "pasubub    $f4, $f4, $f8                             \n\t" \
  "pasubub    $f6, $f6, $f10                            \n\t" \
  "biadd      $f4, $f4                                  \n\t" \
  "biadd      $f6, $f6                                  \n\t" \
  "paddh      $f28, $f28, $f4                           \n\t" \
  "paddh      $f30, $f30, $f6                           \n\t" \
  "gslqc1     $f6, $f4, 0x0(%[pSample2])                \n\t" \
  "gslqc1     $f10, $f8, 0x0(%[pSample1])               \n\t" \
  "pasubub    $f4, $f4, $f8                             \n\t" \
  "pasubub    $f6, $f6, $f10                            \n\t" \
  "biadd      $f4, $f4                                  \n\t" \
  "biadd      $f6, $f6                                  \n\t" \
  "paddh      $f28, $f28, $f4                           \n\t" \
  "paddh      $f30, $f30, $f6                           \n\t"

#define MMI_Get4LW16Sad(f0, f2, f4, f6, f8, f10, f12, f14, r0) \
  "pasubub    "#f0", "#f0", "#f12"                      \n\t" \
  "pasubub    "#f2", "#f2", "#f14"                      \n\t" \
  "pasubub    "#f12", "#f12", "#f8"                     \n\t" \
  "pasubub    "#f14", "#f14", "#f10"                    \n\t" \
  "biadd      "#f0", "#f0"                              \n\t" \
  "biadd      "#f2", "#f2"                              \n\t" \
  "biadd      "#f12", "#f12"                            \n\t" \
  "biadd      "#f14", "#f14"                            \n\t" \
  "paddh      $f20, $f20, "#f0"                         \n\t" \
  "paddh      $f22, $f22, "#f2"                         \n\t" \
  "paddh      $f16, $f16, "#f12"                        \n\t" \
  "paddh      $f18, $f18, "#f14"                        \n\t" \
  "gsldlc1    "#f12", 0x6("#r0")                        \n\t" \
  "gsldlc1    "#f14", 0xE("#r0")                        \n\t" \
  "gsldrc1    "#f12", -0x1("#r0")                       \n\t" \
  "gsldrc1    "#f14", 0x7("#r0")                        \n\t" \
  "pasubub    "#f12", "#f12", "#f4"                     \n\t" \
  "pasubub    "#f14", "#f14", "#f6"                     \n\t" \
  "biadd      "#f12", "#f12"                            \n\t" \
  "biadd      "#f14", "#f14"                            \n\t" \
  "paddh      $f24, $f24, "#f12"                        \n\t" \
  "paddh      $f26, $f26, "#f14"                        \n\t" \
  "gsldlc1    "#f12", 0x8("#r0")                        \n\t" \
  "gsldlc1    "#f14", 0x10("#r0")                       \n\t" \
  "gsldrc1    "#f12", 0x1("#r0")                        \n\t" \
  "gsldrc1    "#f14", 0x9("#r0")                        \n\t" \
  "pasubub    "#f12", "#f12", "#f4"                     \n\t" \
  "pasubub    "#f14", "#f14", "#f6"                     \n\t" \
  "biadd      "#f12", "#f12"                            \n\t" \
  "biadd      "#f14", "#f14"                            \n\t" \
  "paddh      $f28, $f28, "#f12"                        \n\t" \
  "paddh      $f30, $f30, "#f14"                        \n\t"

#define MMI_HDMTwo4x4(f0, f2, f4, f6, f8, f10, f12, f14, f16, f18) \
  MMI_SumSub(f0, f2, f4, f6, f16, f18)      \
  MMI_SumSub(f8, f10, f12, f14, f16, f18)   \
  MMI_SumSub(f4, f6, f12, f14, f16, f18)    \
  MMI_SumSub(f0, f2, f8, f10, f16, f18)

#define MMI_SumAbs4(f0, f2, f4, f6, f8, f10, f12, f14, f16, f18, f20, f22, f24, f26) \
  WELS_AbsH(f0, f2, f0, f2, f8, f10)                          \
  WELS_AbsH(f4, f6, f4, f6, f8, f10)                          \
  WELS_AbsH(f12, f14, f12, f14, f20, f22)                     \
  WELS_AbsH(f16, f18, f16, f18, f20, f22)                     \
  "paddush    "#f0", "#f0", "#f4"                       \n\t" \
  "paddush    "#f2", "#f2", "#f6"                       \n\t" \
  "paddush    "#f12", "#f12", "#f16"                    \n\t" \
  "paddush    "#f14", "#f14", "#f18"                    \n\t" \
  "paddush    "#f24", "#f24", "#f0"                     \n\t" \
  "paddush    "#f26", "#f26", "#f2"                     \n\t" \
  "paddush    "#f24", "#f24", "#f12"                    \n\t" \
  "paddush    "#f26", "#f26", "#f14"                    \n\t"

#define MMI_SumWHorizon(f0, f2, f4, f6, f8, f10) \
  "paddh      "#f0", "#f0", "#f2"                       \n\t" \
  "punpckhhw  "#f2", "#f0", "#f8"                       \n\t" \
  "punpcklhw  "#f0", "#f0", "#f8"                       \n\t" \
  "paddw      "#f0", "#f0", "#f2"                       \n\t" \
  "pshufh     "#f2", "#f0", "#f10"                      \n\t" \
  "paddw      "#f0", "#f0", "#f2"                       \n\t"

#define MMI_LoadDiff8P_Offset_Stride0(f0, f2, f4, f6, f8, r0, r1) \
  "gsldlc1    "#f0", 0x7("#r0")               \n\t" \
  "gsldlc1    "#f4", 0x7("#r1")               \n\t" \
  PTR_ADDU   "$11, %[pSample1], %[iStride1]   \n\t" \
  "gsldrc1    "#f0", 0x0("#r0")               \n\t" \
  "gsldrc1    "#f4", 0x0("#r1")               \n\t" \
  PTR_ADDU   "$12, %[pSample2], %[iStride2]   \n\t" \
  "punpckhbh  "#f2", "#f0", "#f8"             \n\t" \
  "punpcklbh  "#f0", "#f0", "#f8"             \n\t" \
  "punpckhbh  "#f6", "#f4", "#f8"             \n\t" \
  "punpcklbh  "#f4", "#f4", "#f8"             \n\t" \
  "psubh      "#f0", "#f0", "#f4"             \n\t" \
  "psubh      "#f2", "#f2", "#f6"             \n\t"

#define MMI_LoadDiff8P_Offset_Stride1(f0, f2, f4, f6, f8, r0, r1) \
  "gsldlc1    "#f0", 0x7("#r0")               \n\t" \
  "gsldlc1    "#f4", 0x7("#r1")               \n\t" \
  PTR_ADDU   "%[pSample1], $11, %[iStride1]   \n\t" \
  "gsldrc1    "#f0", 0x0("#r0")               \n\t" \
  "gsldrc1    "#f4", 0x0("#r1")               \n\t" \
  PTR_ADDU   "%[pSample2], $12, %[iStride2]   \n\t" \
  "punpckhbh  "#f2", "#f0", "#f8"             \n\t" \
  "punpcklbh  "#f0", "#f0", "#f8"             \n\t" \
  "punpckhbh  "#f6", "#f4", "#f8"             \n\t" \
  "punpcklbh  "#f4", "#f4", "#f8"             \n\t" \
  "psubh      "#f0", "#f0", "#f4"             \n\t" \
  "psubh      "#f2", "#f2", "#f6"             \n\t"

#define MMI_LoadDiff8P_Offset8(f0, f2, f4, f6, f8, r0, r1) \
  "gsldlc1    "#f0", 0x7("#r0")               \n\t" \
  "gsldlc1    "#f4", 0x7("#r1")               \n\t" \
  PTR_ADDU   "%[pSample1], $9, 0x8            \n\t" \
  "gsldrc1    "#f0", 0x0("#r0")               \n\t" \
  "gsldrc1    "#f4", 0x0("#r1")               \n\t" \
  PTR_ADDU   "%[pSample2], $10, 0x8           \n\t" \
  "punpckhbh  "#f2", "#f0", "#f8"             \n\t" \
  "punpcklbh  "#f0", "#f0", "#f8"             \n\t" \
  "punpckhbh  "#f6", "#f4", "#f8"             \n\t" \
  "punpcklbh  "#f4", "#f4", "#f8"             \n\t" \
  "psubh      "#f0", "#f0", "#f4"             \n\t" \
  "psubh      "#f2", "#f2", "#f6"             \n\t"

#define MMI_GetSatd8x8 \
  MMI_LoadDiff8P_Offset_Stride0($f0, $f2, $f16, $f18, $f28, %[pSample1], %[pSample2])        \
  MMI_LoadDiff8P_Offset_Stride1($f4, $f6, $f20, $f22, $f28, $11, $12)                        \
  MMI_LoadDiff8P_Offset_Stride0($f8, $f10, $f16, $f18, $f28, %[pSample1], %[pSample2])       \
  MMI_LoadDiff8P_Offset_Stride1($f12, $f14, $f20, $f22, $f28, $11, $12)                      \
  MMI_HDMTwo4x4($f0, $f2, $f4, $f6, $f8, $f10, $f12, $f14, $f16, $f18)                       \
  MMI_TransTwo4x4H($f12, $f14, $f4, $f6, $f0, $f2, $f8, $f10, $f16, $f18)                    \
  MMI_HDMTwo4x4($f12, $f14, $f4, $f6, $f8, $f10, $f16, $f18, $f20, $f22)                     \
  MMI_SumAbs4($f16, $f18, $f4, $f6, $f0, $f2, $f8, $f10, $f12, $f14, $f20, $f22, $f24, $f26) \
  MMI_LoadDiff8P_Offset_Stride0($f0, $f2, $f16, $f18, $f28, %[pSample1], %[pSample2])        \
  MMI_LoadDiff8P_Offset_Stride1($f4, $f6, $f20, $f22, $f28, $11, $12)                        \
  MMI_LoadDiff8P_Offset_Stride0($f8, $f10, $f16, $f18, $f28, %[pSample1], %[pSample2])       \
  MMI_LoadDiff8P_Offset_Stride1($f12, $f14, $f20, $f22, $f28, $11, $12)                      \
  MMI_HDMTwo4x4($f0, $f2, $f4, $f6, $f8, $f10, $f12, $f14, $f16, $f18)                       \
  MMI_TransTwo4x4H($f12, $f14, $f4, $f6, $f0, $f2, $f8, $f10, $f16, $f18)                    \
  MMI_HDMTwo4x4($f12, $f14, $f4, $f6, $f8, $f10, $f16, $f18, $f20, $f22)                     \
  MMI_SumAbs4($f16, $f18, $f4, $f6, $f0, $f2, $f8, $f10, $f12, $f14, $f20, $f22, $f24, $f26)

#define MMI_GetSatd8x8_Offset8 \
  MMI_LoadDiff8P_Offset_Stride0($f0, $f2, $f16, $f18, $f28, %[pSample1], %[pSample2])        \
  MMI_LoadDiff8P_Offset_Stride1($f4, $f6, $f20, $f22, $f28, $11, $12)                        \
  MMI_LoadDiff8P_Offset_Stride0($f8, $f10, $f16, $f18, $f28, %[pSample1], %[pSample2])       \
  MMI_LoadDiff8P_Offset_Stride1($f12, $f14, $f20, $f22, $f28, $11, $12)                      \
  MMI_HDMTwo4x4($f0, $f2, $f4, $f6, $f8, $f10, $f12, $f14, $f16, $f18)                       \
  MMI_TransTwo4x4H($f12, $f14, $f4, $f6, $f0, $f2, $f8, $f10, $f16, $f18)                    \
  MMI_HDMTwo4x4($f12, $f14, $f4, $f6, $f8, $f10, $f16, $f18, $f20, $f22)                     \
  MMI_SumAbs4($f16, $f18, $f4, $f6, $f0, $f2, $f8, $f10, $f12, $f14, $f20, $f22, $f24, $f26) \
  MMI_LoadDiff8P_Offset_Stride0($f0, $f2, $f16, $f18, $f28, %[pSample1], %[pSample2])        \
  MMI_LoadDiff8P_Offset_Stride1($f4, $f6, $f20, $f22, $f28, $11, $12)                        \
  MMI_LoadDiff8P_Offset_Stride0($f8, $f10, $f16, $f18, $f28, %[pSample1], %[pSample2])       \
  MMI_LoadDiff8P_Offset8($f12, $f14, $f20, $f22, $f28, $11, $12)                             \
  MMI_HDMTwo4x4($f0, $f2, $f4, $f6, $f8, $f10, $f12, $f14, $f16, $f18)                       \
  MMI_TransTwo4x4H($f12, $f14, $f4, $f6, $f0, $f2, $f8, $f10, $f16, $f18)                    \
  MMI_HDMTwo4x4($f12, $f14, $f4, $f6, $f8, $f10, $f16, $f18, $f20, $f22)                     \
  MMI_SumAbs4($f16, $f18, $f4, $f6, $f0, $f2, $f8, $f10, $f12, $f14, $f20, $f22, $f24, $f26)

#define MMI_GetSatd8x8_End \
  MMI_LoadDiff8P_Offset_Stride0($f0, $f2, $f16, $f18, $f28, %[pSample1], %[pSample2])        \
  MMI_LoadDiff8P_Offset_Stride1($f4, $f6, $f20, $f22, $f28, $11, $12)                        \
  MMI_LoadDiff8P_Offset_Stride0($f8, $f10, $f16, $f18, $f28, %[pSample1], %[pSample2])       \
  MMI_LoadDiff8P_Offset_Stride1($f12, $f14, $f20, $f22, $f28, $11, $12)                      \
  MMI_HDMTwo4x4($f0, $f2, $f4, $f6, $f8, $f10, $f12, $f14, $f16, $f18)                       \
  MMI_TransTwo4x4H($f12, $f14, $f4, $f6, $f0, $f2, $f8, $f10, $f16, $f18)                    \
  MMI_HDMTwo4x4($f12, $f14, $f4, $f6, $f8, $f10, $f16, $f18, $f20, $f22)                     \
  MMI_SumAbs4($f16, $f18, $f4, $f6, $f0, $f2, $f8, $f10, $f12, $f14, $f20, $f22, $f24, $f26) \
  MMI_LoadDiff8P_Offset_Stride0($f0, $f2, $f16, $f18, $f28, %[pSample1], %[pSample2])        \
  MMI_LoadDiff8P_Offset_Stride1($f4, $f6, $f20, $f22, $f28, $11, $12)                        \
  MMI_LoadDiff8P_Offset_Stride0($f8, $f10, $f16, $f18, $f28, %[pSample1], %[pSample2])       \
  MMI_LoadDiff8P($f12, $f14, $f20, $f22, $f28, $11, $12)                                     \
  MMI_HDMTwo4x4($f0, $f2, $f4, $f6, $f8, $f10, $f12, $f14, $f16, $f18)                       \
  MMI_TransTwo4x4H($f12, $f14, $f4, $f6, $f0, $f2, $f8, $f10, $f16, $f18)                    \
  MMI_HDMTwo4x4($f12, $f14, $f4, $f6, $f8, $f10, $f16, $f18, $f20, $f22)                     \
  MMI_SumAbs4($f16, $f18, $f4, $f6, $f0, $f2, $f8, $f10, $f12, $f14, $f20, $f22, $f24, $f26)

int32_t WelsSampleSad16x16_mmi (uint8_t* pSample1, int32_t iStride1,
                                uint8_t* pSample2, int32_t iStride2) {
  int32_t iSadSum = 0;
  BACKUP_REG;
  __asm__ volatile (
    ".set       arch=loongson3a                           \n\t"
    "and        $8, %[pSample2], 0xF                      \n\t"
    "xor        $f28, $f28, $f28                          \n\t"
    "xor        $f30, $f30, $f30                          \n\t"
    "bnez       $8, unaligned                             \n\t"
    "aligned:                                             \n\t"
    MMI_GetSad4x16_Aligned
    MMI_GetSad4x16_Aligned
    MMI_GetSad4x16_Aligned
    MMI_GetSad4x16_Aligned_End
    "b          out                                       \n\t"

    "unaligned:                                           \n\t"
    MMI_GetSad4x16
    MMI_GetSad4x16
    MMI_GetSad4x16
    MMI_GetSad4x16_End
    "out:                                                 \n\t"
    "mov.d      $f0, $f30                                 \n\t"
    "paddh      $f0, $f0, $f28                            \n\t"
    "dmfc1      %[iSadSum], $f0                           \n\t"
    : [pSample1]"+&r"((unsigned char *)pSample1), [iSadSum]"=r"((int)iSadSum),
      [pSample2]"+&r"((unsigned char *)pSample2)
    : [iStride1]"r"((int)iStride1),  [iStride2]"r"((int)iStride2)
    : "memory", "$8", "$f0", "$f2", "$f4", "$f6", "$f8", "$f10", "$f12",
      "$f14", "$f16", "$f18", "$f20", "$f22", "$f24", "$f26", "$f28", "$f30"
  );
  RECOVER_REG;
  return iSadSum;
}

int32_t WelsSampleSad16x8_mmi (uint8_t* pSample1, int32_t iStride1,
                               uint8_t* pSample2, int32_t iStride2) {
  int32_t iSadSum = 0;
  BACKUP_REG;
  __asm__ volatile (
    ".set       arch=loongson3a                           \n\t"
    "gsldlc1    $f0, 0x7(%[pSample2])                     \n\t"
    "gsldlc1    $f2, 0xF(%[pSample2])                     \n\t"
    "gsldrc1    $f0, 0x0(%[pSample2])                     \n\t"
    "gsldrc1    $f2, 0x8(%[pSample2])                     \n\t"
    "gslqc1     $f10, $f8, 0x0(%[pSample1])               \n\t"
    PTR_ADDU   "%[pSample2], %[pSample2], %[iStride2]     \n\t"
    PTR_ADDU   "%[pSample1], %[pSample1], %[iStride1]     \n\t"
    "pasubub    $f0, $f0, $f8                             \n\t"
    "pasubub    $f2, $f2, $f10                            \n\t"
    "biadd      $f0, $f0                                  \n\t"
    "biadd      $f2, $f2                                  \n\t"
    "gsldlc1    $f4, 0x7(%[pSample2])                     \n\t"
    "gsldlc1    $f6, 0xF(%[pSample2])                     \n\t"
    "gsldrc1    $f4, 0x0(%[pSample2])                     \n\t"
    "gsldrc1    $f6, 0x8(%[pSample2])                     \n\t"
    "gslqc1     $f10, $f8, 0x0(%[pSample1])               \n\t"
    "pasubub    $f4, $f4, $f8                             \n\t"
    "pasubub    $f6, $f6, $f10                            \n\t"
    "biadd      $f4, $f4                                  \n\t"
    "biadd      $f6, $f6                                  \n\t"
    "paddh      $f0, $f0, $f4                             \n\t"
    "paddh      $f2, $f2, $f6                             \n\t"

    MMI_GetSad2x16
    MMI_GetSad2x16
    MMI_GetSad2x16

    "paddh      $f0, $f0, $f2                             \n\t"
    "dmfc1      %[iSadSum], $f0                           \n\t"
    : [pSample1]"+&r"((unsigned char *)pSample1), [iSadSum]"=r"((int)iSadSum),
      [pSample2]"+&r"((unsigned char *)pSample2)
    : [iStride1]"r"((int)iStride1),  [iStride2]"r"((int)iStride2)
    : "memory", "$f0", "$f2", "$f4", "$f6", "$f8", "$f10", "$f12",
      "$f14", "$f16", "$f18", "$f20", "$f22", "$f24", "$f26"
  );
  RECOVER_REG;
  return iSadSum;
}

int32_t WelsSampleSad8x16_mmi (uint8_t* pSample1, int32_t iStride1,
                               uint8_t* pSample2, int32_t iStride2) {
  int32_t iSadSum = 0;
  BACKUP_REG;
  __asm__ volatile (
    ".set       arch=loongson3a                           \n\t"
    "xor        $f24, $f24, $f24                          \n\t"
    "xor        $f26, $f26, $f26                          \n\t"
    MMI_GetSad8x4
    MMI_GetSad8x4
    MMI_GetSad8x4
    MMI_GetSad8x4_End
    "paddh      $f0, $f26, $f24                           \n\t"
    "dmfc1      %[iSadSum], $f0                           \n\t"
    : [pSample1]"+&r"((unsigned char *)pSample1), [iSadSum]"=r"((int)iSadSum),
      [pSample2]"+&r"((unsigned char *)pSample2)
    : [iStride1]"r"((int)iStride1), [iStride2]"r"((int)iStride2)
    : "memory", "$8", "$9", "$f0", "$f2", "$f4", "$f6", "$f8", "$f10", "$f12",
      "$f14", "$f16", "$f18", "$f20", "$f22", "$f24", "$f26"
  );
  RECOVER_REG;
  return iSadSum;
}

int32_t WelsSampleSad4x4_mmi (uint8_t* pSample1, int32_t iStride1,
                              uint8_t* pSample2, int32_t iStride2) {
  int32_t iSadSum = 0;
  __asm__ volatile (
    ".set       arch=loongson3a                           \n\t"
    PTR_ADDU   "$8, %[pSample1], %[iStride1]              \n\t"
    "gsldlc1    $f0, 0x7(%[pSample1])                     \n\t"
    "gsldlc1    $f2, 0x7($8)                              \n\t"
    "gsldrc1    $f0, 0x0(%[pSample1])                     \n\t"
    "gsldrc1    $f2, 0x0($8)                              \n\t"
    "punpcklwd  $f0, $f0, $f2                             \n\t"

    PTR_ADDU   "$9, %[pSample2], %[iStride2]              \n\t"
    "gsldlc1    $f6, 0x7(%[pSample2])                     \n\t"
    "gsldlc1    $f8, 0x7($9)                              \n\t"
    "gsldrc1    $f6, 0x0(%[pSample2])                     \n\t"
    "gsldrc1    $f8, 0x0($9)                              \n\t"
    "punpcklwd  $f6, $f6, $f8                             \n\t"
    "pasubub    $f0, $f0, $f6                             \n\t"
    "biadd      $f0, $f0                                  \n\t"

    PTR_ADDU   "%[pSample1], $8, %[iStride1]              \n\t"
    PTR_ADDU   "%[pSample2], $9, %[iStride2]              \n\t"

    PTR_ADDU   "$8, %[pSample1], %[iStride1]              \n\t"
    "gsldlc1    $f2, 0x7(%[pSample1])                     \n\t"
    "gsldlc1    $f4, 0x7($8)                              \n\t"
    "gsldrc1    $f2, 0x0(%[pSample1])                     \n\t"
    "gsldrc1    $f4, 0x0($8)                              \n\t"
    "punpcklwd  $f2, $f2, $f4                             \n\t"

    PTR_ADDU   "$9, %[pSample2], %[iStride2]              \n\t"
    "gsldlc1    $f6, 0x7(%[pSample2])                     \n\t"
    "gsldlc1    $f8, 0x7($9)                              \n\t"
    "gsldrc1    $f6, 0x0(%[pSample2])                     \n\t"
    "gsldrc1    $f8, 0x0($9)                              \n\t"
    "punpcklwd  $f6, $f6, $f8                             \n\t"
    "pasubub    $f2, $f2, $f6                             \n\t"
    "biadd      $f2, $f2                                  \n\t"
    "paddh      $f0, $f0, $f2                             \n\t"

    "dmfc1      %[iSadSum], $f0                           \n\t"
    : [pSample1]"+&r"((unsigned char *)pSample1), [iSadSum]"=r"((int)iSadSum),
      [pSample2]"+&r"((unsigned char *)pSample2)
    : [iStride1]"r"((int)iStride1),  [iStride2]"r"((int)iStride2)
    : "memory", "$8", "$9", "$f0", "$f2", "$f4", "$f6", "$f8"
  );
  return iSadSum;
}

int32_t WelsSampleSad8x8_mmi (uint8_t* pSample1, int32_t iStride1,
                              uint8_t* pSample2, int32_t iStride2) {
  int32_t iSadSum = 0;
  BACKUP_REG;
  __asm__ volatile (
    ".set       arch=loongson3a                           \n\t"
    CACHE_SPLIT_CHECK($8, 8, 32)
    "blez       $8, 1f                                    \n\t"
    "nop                                                  \n\t"
    "xor        $f28, $f28, $f28                          \n\t"
    "xor        $f30, $f30, $f30                          \n\t"

    "move       $9, %[pSample2]                           \n\t"
    "and        $9, $9, 0x7                               \n\t"
    PTR_SUBU   "%[pSample2], %[pSample2], $9              \n\t"
    "dli        $8, 0x8                                   \n\t"
    PTR_SUBU   "$8, $8, $9                                \n\t"

    "dsll       $9, $9, 0x3                               \n\t"
    "dsll       $8, $8, 0x3                               \n\t"
    "dmtc1      $9, $f20                                  \n\t"
    "dmtc1      $8, $f24                                  \n\t"
    "dli        $9, 0x8                                   \n\t"
    "gsldlc1    $f0, 0x7(%[pSample1])                     \n\t"
    PTR_ADDU   "$9, $9, %[pSample2]                       \n\t"
    "gsldrc1    $f0, 0x0(%[pSample1])                     \n\t"
    PTR_ADDU   "%[pSample1], %[pSample1], %[iStride1]     \n\t"
    "gsldlc1    $f2, 0x7(%[pSample1])                     \n\t"

    "gsldlc1    $f4, 0x7(%[pSample2])                     \n\t"
    "gsldlc1    $f8, 0x7($9)                              \n\t"
    "gsldrc1    $f2, 0x0(%[pSample1])                     \n\t"
    "gsldrc1    $f4, 0x0(%[pSample2])                     \n\t"
    "gsldrc1    $f8, 0x0($9)                              \n\t"
    PTR_ADDU   "%[pSample2], %[pSample2], %[iStride2]     \n\t"
    "gsldlc1    $f6, 0x7(%[pSample2])                     \n\t"
    PTR_ADDU   "$9, $9, %[iStride2]                       \n\t"
    "gsldrc1    $f6, 0x0(%[pSample2])                     \n\t"
    "gsldlc1    $f10, 0x7($9)                             \n\t"
    "dsrl       $f4, $f4, $f20                            \n\t"
    "gsldrc1    $f10, 0x0($9)                             \n\t"
    "dsrl       $f6, $f6, $f20                            \n\t"
    "dsll       $f8, $f8, $f24                            \n\t"
    "dsll       $f10, $f10, $f24                          \n\t"
    "or         $f4, $f4, $f8                             \n\t"
    "or         $f6, $f6, $f10                            \n\t"

    PTR_ADDU   "%[pSample1], %[pSample1], %[iStride1]     \n\t"
    PTR_ADDU   "%[pSample2], %[pSample2], %[iStride2]     \n\t"
    "pasubub    $f0, $f0, $f4                             \n\t"
    "pasubub    $f2, $f2, $f6                             \n\t"
    "biadd      $f0, $f0                                  \n\t"
    "biadd      $f2, $f2                                  \n\t"
    "paddh      $f28, $f28, $f0                           \n\t"
    "paddh      $f30, $f30, $f2                           \n\t"

    "gsldlc1    $f0, 0x7(%[pSample1])                     \n\t"
    PTR_ADDU   "$9, $9, %[iStride2]                       \n\t"
    "gsldrc1    $f0, 0x0(%[pSample1])                     \n\t"

    PTR_ADDU   "%[pSample1], %[pSample1], %[iStride1]     \n\t"
    "gsldlc1    $f2, 0x7(%[pSample1])                     \n\t"

    "gsldlc1    $f4, 0x7(%[pSample2])                     \n\t"
    "gsldlc1    $f8, 0x7($9)                              \n\t"
    "gsldrc1    $f2, 0x0(%[pSample1])                     \n\t"
    "gsldrc1    $f4, 0x0(%[pSample2])                     \n\t"
    "gsldrc1    $f8, 0x0($9)                              \n\t"
    PTR_ADDU   "%[pSample2], %[pSample2], %[iStride2]     \n\t"
    PTR_ADDU   "$9, $9, %[iStride2]                       \n\t"
    "gsldlc1    $f6, 0x7(%[pSample2])                     \n\t"
    "gsldlc1    $f10, 0x7($9)                             \n\t"
    "gsldrc1    $f6, 0x0(%[pSample2])                     \n\t"
    "gsldrc1    $f10, 0x0($9)                             \n\t"
    "dsrl       $f4, $f4, $f20                            \n\t"
    "dsrl       $f6, $f6, $f20                            \n\t"
    "dsll       $f8, $f8, $f24                            \n\t"
    "dsll       $f10, $f10, $f24                          \n\t"
    "or         $f4, $f4, $f8                             \n\t"
    "or         $f6, $f6, $f10                            \n\t"

    PTR_ADDU   "%[pSample1], %[pSample1], %[iStride1]     \n\t"
    PTR_ADDU   "%[pSample2], %[pSample2], %[iStride2]     \n\t"
    PTR_ADDU   "$9, $9, %[iStride2]                       \n\t"

    "pasubub    $f0, $f0, $f4                             \n\t"
    "pasubub    $f2, $f2, $f6                             \n\t"
    "biadd      $f0, $f0                                  \n\t"
    "biadd      $f2, $f2                                  \n\t"
    "paddh      $f28, $f28, $f0                           \n\t"
    "gsldlc1    $f0, 0x7(%[pSample1])                     \n\t"
    "paddh      $f30, $f30, $f2                           \n\t"
    "gsldrc1    $f0, 0x0(%[pSample1])                     \n\t"

    PTR_ADDU   "%[pSample1], %[pSample1], %[iStride1]     \n\t"
    "gsldlc1    $f2, 0x7(%[pSample1])                     \n\t"

    "gsldlc1    $f4, 0x7(%[pSample2])                     \n\t"
    "gsldlc1    $f8, 0x7($9)                              \n\t"
    "gsldrc1    $f2, 0x0(%[pSample1])                     \n\t"
    "gsldrc1    $f4, 0x0(%[pSample2])                     \n\t"
    "gsldrc1    $f8, 0x0($9)                              \n\t"
    PTR_ADDU   "%[pSample2], %[pSample2], %[iStride2]     \n\t"
    PTR_ADDU   "$9, $9, %[iStride2]                       \n\t"
    "gsldlc1    $f6, 0x7(%[pSample2])                     \n\t"
    "gsldlc1    $f10, 0x7($9)                             \n\t"
    "gsldrc1    $f6, 0x0(%[pSample2])                     \n\t"
    "gsldrc1    $f10, 0x0($9)                             \n\t"
    "dsrl       $f4, $f4, $f20                            \n\t"
    "dsrl       $f6, $f6, $f20                            \n\t"
    "dsll       $f8, $f8, $f24                            \n\t"
    "dsll       $f10, $f10, $f24                          \n\t"
    "or         $f4, $f4, $f8                             \n\t"
    "or         $f6, $f6, $f10                            \n\t"

    PTR_ADDU   "%[pSample1], %[pSample1], %[iStride1]     \n\t"
    PTR_ADDU   "%[pSample2], %[pSample2], %[iStride2]     \n\t"
    PTR_ADDU   "$9, $9, %[iStride2]                       \n\t"

    "pasubub    $f0, $f0, $f4                             \n\t"
    "pasubub    $f2, $f2, $f6                             \n\t"
    "biadd      $f0, $f0                                  \n\t"
    "biadd      $f2, $f2                                  \n\t"
    "paddh      $f28, $f28, $f0                           \n\t"
    "gsldlc1    $f0, 0x7(%[pSample1])                     \n\t"
    "paddh      $f30, $f30, $f2                           \n\t"

    "gsldrc1    $f0, 0x0(%[pSample1])                     \n\t"
    PTR_ADDU   "%[pSample1], %[pSample1], %[iStride1]     \n\t"
    "gsldlc1    $f2, 0x7(%[pSample1])                     \n\t"

    "gsldlc1    $f4, 0x7(%[pSample2])                     \n\t"
    "gsldlc1    $f8, 0x7($9)                              \n\t"
    "gsldrc1    $f2, 0x0(%[pSample1])                     \n\t"
    "gsldrc1    $f4, 0x0(%[pSample2])                     \n\t"
    "gsldrc1    $f8, 0x0($9)                              \n\t"
    PTR_ADDU   "%[pSample2], %[pSample2], %[iStride2]     \n\t"
    PTR_ADDU   "$9, $9, %[iStride2]                       \n\t"
    "gsldlc1    $f6, 0x7(%[pSample2])                     \n\t"
    "gsldlc1    $f10, 0x7($9)                             \n\t"
    "gsldrc1    $f6, 0x0(%[pSample2])                     \n\t"
    "gsldrc1    $f10, 0x0($9)                             \n\t"
    "dsrl       $f4, $f4, $f20                            \n\t"
    "dsrl       $f6, $f6, $f20                            \n\t"
    "dsll       $f8, $f8, $f24                            \n\t"
    "dsll       $f10, $f10, $f24                          \n\t"
    "or         $f4, $f4, $f8                             \n\t"
    "or         $f6, $f6, $f10                            \n\t"

    "pasubub    $f0, $f0, $f4                             \n\t"
    "pasubub    $f2, $f2, $f6                             \n\t"
    "biadd      $f0, $f0                                  \n\t"
    "biadd      $f2, $f2                                  \n\t"
    "paddh      $f28, $f28, $f0                           \n\t"
    "paddh      $f30, $f30, $f2                           \n\t"

    "mov.d      $f0, $f30                                 \n\t"
    "paddh      $f0, $f0, $f28                            \n\t"
    "dmfc1      %[iSadSum], $f0                           \n\t"
    "j          2f                                        \n\t"
    "nop                                                  \n\t"

    "1:                                                   \n\t"
    "xor        $f24, $f24, $f24                          \n\t"
    "xor        $f26, $f26, $f26                          \n\t"
    MMI_GetSad8x4
    MMI_GetSad8x4_End
    "paddh      $f0, $f26, $f24                           \n\t"
    "dmfc1      %[iSadSum], $f0                           \n\t"
    "2:                                                   \n\t"
    : [pSample1]"+&r"((unsigned char *)pSample1), [iSadSum]"=r"((int)iSadSum),
      [pSample2]"+&r"((unsigned char *)pSample2)
    : [iStride1]"r"((int)iStride1),  [iStride2]"r"((int)iStride2)
    : "memory", "$8", "$9", "$f0", "$f2", "$f4", "$f6", "$f8", "$f10", "$f12",
      "$f14", "$f16", "$f18", "$f20", "$f22", "$f24", "$f26", "$f28", "$f30"
  );
  RECOVER_REG;
  return iSadSum;
}

int32_t WelsSampleSatd4x4_mmi (uint8_t* pSample1, int32_t iStride1,
                               uint8_t* pSample2, int32_t iStride2) {
  int32_t iSatdSum = 0;
  BACKUP_REG;
  __asm__ volatile (
    ".set       arch=loongson3a                           \n\t"
    PTR_ADDU   "$8, %[pSample1], %[iStride1]              \n\t"
    "gsldlc1    $f0, 0x7(%[pSample1])                     \n\t"
    "gsldlc1    $f4, 0x7($8)                              \n\t"
    "gsldrc1    $f0, 0x0(%[pSample1])                     \n\t"
    "gsldrc1    $f4, 0x0($8)                              \n\t"
    PTR_ADDU   "%[pSample1], $8, %[iStride1]              \n\t"
    PTR_ADDU   "$8, %[pSample1], %[iStride1]              \n\t"
    "gsldlc1    $f8, 0x7(%[pSample1])                     \n\t"
    "gsldlc1    $f12, 0x7($8)                             \n\t"
    "gsldrc1    $f8, 0x0(%[pSample1])                     \n\t"
    "gsldrc1    $f12, 0x0($8)                             \n\t"
    "punpcklwd  $f0, $f0, $f8                             \n\t"
    "punpcklwd  $f4, $f4, $f12                            \n\t"

    PTR_ADDU   "$8, %[pSample2], %[iStride2]              \n\t"
    "gsldlc1    $f16, 0x7(%[pSample2])                    \n\t"
    "gsldlc1    $f20, 0x7($8)                             \n\t"
    "gsldrc1    $f16, 0x0(%[pSample2])                    \n\t"
    "gsldrc1    $f20, 0x0($8)                             \n\t"
    PTR_ADDU   "%[pSample2], $8, %[iStride2]              \n\t"
    PTR_ADDU   "$8, %[pSample2], %[iStride2]              \n\t"
    "gsldlc1    $f24, 0x7(%[pSample2])                    \n\t"
    "gsldlc1    $f28, 0x7($8)                             \n\t"
    "gsldrc1    $f24, 0x0(%[pSample2])                    \n\t"
    "gsldrc1    $f28, 0x0($8)                             \n\t"
    "punpcklwd  $f16, $f16, $f24                          \n\t"
    "punpcklwd  $f20, $f20, $f28                          \n\t"

    "xor        $f24, $f24, $f24                          \n\t"
    "xor        $f26, $f26, $f26                          \n\t"
    "punpckhbh  $f2, $f0, $f24                            \n\t"
    "punpcklbh  $f0, $f0, $f24                            \n\t"
    "punpckhbh  $f6, $f4, $f24                            \n\t"
    "punpcklbh  $f4, $f4, $f24                            \n\t"
    "punpckhbh  $f18, $f16, $f24                          \n\t"
    "punpcklbh  $f16, $f16, $f24                          \n\t"
    "punpckhbh  $f22, $f20, $f24                          \n\t"
    "punpcklbh  $f20, $f20, $f24                          \n\t"

    "psubh      $f0, $f0, $f16                            \n\t"
    "psubh      $f2, $f2, $f18                            \n\t"
    "psubh      $f4, $f4, $f20                            \n\t"
    "psubh      $f6, $f6, $f22                            \n\t"

    "mov.d      $f8, $f0                                  \n\t"
    "mov.d      $f10, $f2                                 \n\t"
    "paddh      $f0, $f0, $f4                             \n\t"
    "paddh      $f2, $f2, $f6                             \n\t"
    "psubh      $f8, $f8, $f4                             \n\t"
    "psubh      $f10, $f10, $f6                           \n\t"
    MMI_XSawp_DQ($f0, $f2, $f8, $f10, $f12, $f14)

    "mov.d      $f16, $f0                                 \n\t"
    "mov.d      $f18, $f2                                 \n\t"
    "paddh      $f0, $f0, $f12                            \n\t"
    "paddh      $f2, $f2, $f14                            \n\t"
    "psubh      $f16, $f16, $f12                          \n\t"
    "psubh      $f18, $f18, $f14                          \n\t"

    "mov.d      $f8, $f2                                  \n\t"
    "punpckhhw  $f2, $f0, $f16                            \n\t"
    "punpcklhw  $f0, $f0, $f16                            \n\t"
    "punpcklhw  $f16, $f18, $f8                           \n\t"
    "punpckhhw  $f18, $f18, $f8                           \n\t"

    MMI_XSawp_WD($f0, $f2, $f16, $f18, $f12, $f14)
    MMI_XSawp_DQ($f0, $f2, $f12, $f14, $f20, $f22)

    "mov.d      $f28, $f0                                 \n\t"
    "mov.d      $f30, $f2                                 \n\t"
    "paddh      $f0, $f0, $f20                            \n\t"
    "paddh      $f2, $f2, $f22                            \n\t"
    "psubh      $f28, $f28, $f20                          \n\t"
    "psubh      $f30, $f30, $f22                          \n\t"

    MMI_XSawp_DQ($f0, $f2, $f28, $f30, $f4, $f6)

    "psubh      $f8, $f0, $f4                             \n\t"
    "psubh      $f10, $f2, $f6                            \n\t"
    "paddh      $f0, $f0, $f4                             \n\t"
    "paddh      $f2, $f2, $f6                             \n\t"

    WELS_AbsH($f0, $f2, $f0, $f2, $f12, $f14)
    "paddush    $f24, $f24, $f0                           \n\t"
    "paddush    $f26, $f26, $f2                           \n\t"
    WELS_AbsH($f8, $f10, $f8, $f10, $f16, $f18)
    "paddush    $f24, $f24, $f8                           \n\t"
    "paddush    $f26, $f26, $f10                          \n\t"
    MMI_SumWHorizon1($f24, $f26, $f16, $f18, $f28, $f30, $8)

    "dmfc1      $8, $f24                                  \n\t"
    "dli        $9, 0xffff                                \n\t"
    "and        $8, $8, $9                                \n\t"
    "dsrl       %[iSatdSum], $8, 0x1                      \n\t"
    : [pSample1]"+&r"((unsigned char *)pSample1), [iSatdSum]"=r"((int)iSatdSum),
      [pSample2]"+&r"((unsigned char *)pSample2)
    : [iStride1]"r"((int)iStride1),  [iStride2]"r"((int)iStride2)
    : "memory", "$8", "$9", "$f0", "$f2", "$f4", "$f6", "$f8", "$f10", "$f12",
      "$f14", "$f16", "$f18", "$f20", "$f22", "$f24", "$f26", "$f28", "$f30"
  );
  RECOVER_REG;
  return iSatdSum;
}

int32_t WelsSampleSatd8x8_mmi (uint8_t* pSample1, int32_t iStride1,
                               uint8_t* pSample2, int32_t iStride2) {
  int32_t iSatdSum = 0;
  BACKUP_REG;
  __asm__ volatile (
    ".set       arch=loongson3a                           \n\t"
    "xor        $f24, $f24, $f24                          \n\t"
    "xor        $f26, $f26, $f26                          \n\t"
    "dli        $8, 0x1                                   \n\t"
    "xor        $f28, $f28, $f28                          \n\t"
    "dmtc1      $8, $f30                                  \n\t"
    MMI_GetSatd8x8_End
    "psrlh      $f24, $f24, $f30                          \n\t"
    "dli        $8, 0x4e                                  \n\t"
    "psrlh      $f26, $f26, $f30                          \n\t"
    "dmtc1      $8, $f30                                  \n\t"
    MMI_SumWHorizon($f24, $f26, $f16, $f18, $f28, $f30)
    "mfc1       %[iSatdSum], $f24                         \n\t"
    : [pSample1]"+&r"((unsigned char *)pSample1), [iSatdSum]"=r"((int)iSatdSum),
      [pSample2]"+&r"((unsigned char *)pSample2)
    : [iStride1]"r"((int)iStride1), [iStride2]"r"((int)iStride2)
    : "memory", "$8", "$11", "$12", "$f0", "$f2", "$f4", "$f6", "$f8", "$f10",
      "$f12", "$f14", "$f16", "$f18", "$f20", "$f22", "$f24", "$f26", "$f28", "$f30"
  );
  RECOVER_REG;
  return iSatdSum;
}

int32_t WelsSampleSatd8x16_mmi (uint8_t* pSample1, int32_t iStride1,
                                uint8_t* pSample2, int32_t iStride2) {
  int32_t iSatdSum = 0;
  BACKUP_REG;
  __asm__ volatile (
    ".set       arch=loongson3a                           \n\t"
    "xor        $f24, $f24, $f24                          \n\t"
    "xor        $f26, $f26, $f26                          \n\t"
    "dli        $8, 0x1                                   \n\t"
    "xor        $f28, $f28, $f28                          \n\t"
    "dmtc1      $8, $f30                                  \n\t"
    MMI_GetSatd8x8
    MMI_GetSatd8x8_End
    "psrlh      $f24, $f24, $f30                          \n\t"
    "dli        $8, 0x4e                                  \n\t"
    "psrlh      $f26, $f26, $f30                          \n\t"
    "dmtc1      $8, $f30                                  \n\t"
    MMI_SumWHorizon($f24, $f26, $f16, $f18, $f28, $f30)
    "mfc1       %[iSatdSum], $f24                         \n\t"
    : [pSample1]"+&r"((unsigned char *)pSample1), [iSatdSum]"=r"((int)iSatdSum),
      [pSample2]"+&r"((unsigned char *)pSample2)
    : [iStride1]"r"((int)iStride1), [iStride2]"r"((int)iStride2)
    : "memory", "$8", "$11", "$12", "$f0", "$f2", "$f4", "$f6", "$f8", "$f10",
      "$f12", "$f14", "$f16", "$f18", "$f20", "$f22", "$f24", "$f26", "$f28", "$f30"
  );
  RECOVER_REG;
  return iSatdSum;
}

int32_t WelsSampleSatd16x8_mmi (uint8_t* pSample1, int32_t iStride1,
                                uint8_t* pSample2, int32_t iStride2) {
  int32_t iSatdSum = 0;
  BACKUP_REG;
  __asm__ volatile (
    ".set       arch=loongson3a                           \n\t"
    "xor        $f24, $f24, $f24                          \n\t"
    "xor        $f26, $f26, $f26                          \n\t"
    "dli        $8, 0x1                                   \n\t"
    "xor        $f28, $f28, $f28                          \n\t"
    "dmtc1      $8, $f30                                  \n\t"
    "move       $9, %[pSample1]                           \n\t"
    "move       $10, %[pSample2]                          \n\t"
    MMI_GetSatd8x8_Offset8

    MMI_GetSatd8x8_End
    "psrlh      $f24, $f24, $f30                          \n\t"
    "dli        $8, 0x4e                                  \n\t"
    "psrlh      $f26, $f26, $f30                          \n\t"
    "dmtc1      $8, $f30                                  \n\t"
    MMI_SumWHorizon($f24, $f26, $f16, $f18, $f28, $f30)
    "mfc1       %[iSatdSum], $f24                         \n\t"
    : [pSample1]"+&r"((unsigned char *)pSample1), [iSatdSum]"=r"((int)iSatdSum),
      [pSample2]"+&r"((unsigned char *)pSample2)
    : [iStride1]"r"((int)iStride1), [iStride2]"r"((int)iStride2)
    : "memory", "$8", "$9", "$10", "$11", "$12", "$f0", "$f2", "$f4", "$f6",
      "$f8", "$f10", "$f12", "$f14", "$f16", "$f18", "$f20", "$f22", "$f24",
      "$f26", "$f28", "$f30"
  );
  RECOVER_REG;
  return iSatdSum;
}

int32_t WelsSampleSatd16x16_mmi (uint8_t* pSample1, int32_t iStride1,
                                 uint8_t* pSample2, int32_t iStride2) {
  int32_t iSatdSum = 0;
  BACKUP_REG;
  __asm__ volatile (
    ".set       arch=loongson3a                           \n\t"
    "xor        $f24, $f24, $f24                          \n\t"
    "xor        $f26, $f26, $f26                          \n\t"
    "dli        $8, 0x1                                   \n\t"
    "xor        $f28, $f28, $f28                          \n\t"
    "dmtc1      $8, $f30                                  \n\t"
    "move       $9, %[pSample1]                           \n\t"
    "move       $10, %[pSample2]                          \n\t"

    MMI_GetSatd8x8
    MMI_GetSatd8x8_Offset8

    MMI_GetSatd8x8
    MMI_GetSatd8x8_End

    "dli        $8, 0x4e                                  \n\t"
    "psrlh      $f24, $f24, $f30                          \n\t"
    "dmtc1      $8, $f0                                   \n\t"
    "psrlh      $f26, $f26, $f30                          \n\t"
    MMI_SumWHorizon($f24, $f26, $f16, $f18, $f28, $f0)
    "mfc1       %[iSatdSum], $f24                         \n\t"
    : [pSample1]"+&r"((unsigned char *)pSample1), [iSatdSum]"=r"((int)iSatdSum),
      [pSample2]"+&r"((unsigned char *)pSample2)
    : [iStride1]"r"((int)iStride1), [iStride2]"r"((int)iStride2)
    : "memory", "$8", "$9", "$10", "$11", "$12", "$f0", "$f2", "$f4", "$f6",
      "$f8", "$f10", "$f12", "$f14", "$f16", "$f18", "$f20", "$f22", "$f24",
      "$f26", "$f28", "$f30"
  );
  RECOVER_REG;
  return iSatdSum;
}

void WelsSampleSadFour16x16_mmi (uint8_t* pSample1, int32_t iStride1, uint8_t* pSample2,
                                 int32_t iStride2, int32_t* pSad) {
  BACKUP_REG;
  __asm__ volatile (
    ".set       arch=loongson3a                           \n\t"
    "xor        $f16, $f16, $f16                          \n\t"
    "xor        $f18, $f18, $f18                          \n\t"
    "xor        $f20, $f20, $f20                          \n\t"
    "xor        $f22, $f22, $f22                          \n\t"
    PTR_SUBU   "%[pSample2], %[pSample2], %[iStride2]     \n\t"
    "xor        $f24, $f24, $f24                          \n\t"
    "xor        $f26, $f26, $f26                          \n\t"
    "xor        $f28, $f28, $f28                          \n\t"
    "xor        $f30, $f30, $f30                          \n\t"
    "gslqc1     $f2, $f0, 0x0(%[pSample1])                \n\t"
    "gsldlc1    $f12, 0x7(%[pSample2])                    \n\t"
    "gsldlc1    $f14, 0xF(%[pSample2])                    \n\t"
    "gsldrc1    $f12, 0x0(%[pSample2])                    \n\t"
    "gsldrc1    $f14, 0x8(%[pSample2])                    \n\t"
    PTR_ADDU   "%[pSample1], %[pSample1], %[iStride1]     \n\t"
    PTR_ADDU   "%[pSample2], %[pSample2], %[iStride2]     \n\t"
    "pasubub    $f12, $f12, $f0                           \n\t"
    "pasubub    $f14, $f14, $f2                           \n\t"
    "biadd      $f12, $f12                                \n\t"
    "biadd      $f14, $f14                                \n\t"
    "paddh      $f16, $f16, $f12                          \n\t"
    "paddh      $f18, $f18, $f14                          \n\t"

    "gslqc1     $f6, $f4, 0x0(%[pSample1])                \n\t"
    "gsldlc1    $f12, 0x7(%[pSample2])                    \n\t"
    "gsldlc1    $f14, 0xF(%[pSample2])                    \n\t"
    "gsldrc1    $f12, 0x0(%[pSample2])                    \n\t"
    "gsldrc1    $f14, 0x8(%[pSample2])                    \n\t"
    "pasubub    $f12, $f12, $f4                           \n\t"
    "pasubub    $f14, $f14, $f6                           \n\t"
    "biadd      $f12, $f12                                \n\t"
    "biadd      $f14, $f14                                \n\t"
    "paddh      $f16, $f16, $f12                          \n\t"
    "paddh      $f18, $f18, $f14                          \n\t"

    "gsldlc1    $f8, 0x6(%[pSample2])                     \n\t"
    "gsldlc1    $f10, 0xE(%[pSample2])                    \n\t"
    "gsldrc1    $f8, -0x1(%[pSample2])                    \n\t"
    "gsldrc1    $f10, 0x7(%[pSample2])                    \n\t"
    "pasubub    $f8, $f8, $f0                             \n\t"
    "pasubub    $f10, $f10, $f2                           \n\t"
    "biadd      $f8, $f8                                  \n\t"
    "biadd      $f10, $f10                                \n\t"
    "paddh      $f24, $f24, $f8                           \n\t"
    "paddh      $f26, $f26, $f10                          \n\t"

    "gsldlc1    $f12, 0x8(%[pSample2])                    \n\t"
    "gsldrc1    $f12, 0x1(%[pSample2])                    \n\t"
    "gsldlc1    $f14, 0x10(%[pSample2])                   \n\t"
    "gsldrc1    $f14, 0x9(%[pSample2])                    \n\t"
    PTR_ADDU   "$8, %[pSample1], %[iStride1]              \n\t"
    PTR_ADDU   "$9, %[pSample2], %[iStride2]              \n\t"
    "pasubub    $f12, $f12, $f0                           \n\t"
    "pasubub    $f14, $f14, $f2                           \n\t"
    "biadd      $f12, $f12                                \n\t"
    "biadd      $f14, $f14                                \n\t"
    "paddh      $f28, $f28, $f12                          \n\t"
    "paddh      $f30, $f30, $f14                          \n\t"

    "gslqc1     $f10, $f8, 0x0($8)                        \n\t"
    "gsldlc1    $f12, 0x7($9)                             \n\t"
    "gsldlc1    $f14, 0xF($9)                             \n\t"
    "gsldrc1    $f12, 0x0($9)                             \n\t"
    "gsldrc1    $f14, 0x8($9)                             \n\t"
    PTR_ADDU   "%[pSample1], $8, %[iStride1]              \n\t"
    PTR_ADDU   "%[pSample2], $9, %[iStride2]              \n\t"
    MMI_Get4LW16Sad($f0, $f2, $f4, $f6, $f8, $f10, $f12, $f14, $9)
    "gslqc1     $f2, $f0, 0x0(%[pSample1])                \n\t"
    "gsldlc1    $f12, 0x7(%[pSample2])                    \n\t"
    "gsldlc1    $f14, 0xF(%[pSample2])                    \n\t"
    "gsldrc1    $f12, 0x0(%[pSample2])                    \n\t"
    "gsldrc1    $f14, 0x8(%[pSample2])                    \n\t"
    PTR_ADDU   "$8, %[pSample1], %[iStride1]              \n\t"
    PTR_ADDU   "$9, %[pSample2], %[iStride2]              \n\t"
    MMI_Get4LW16Sad($f4, $f6, $f8, $f10, $f0, $f2, $f12, $f14, %[pSample2])
    "gslqc1     $f6, $f4, 0x0($8)                         \n\t"
    "gsldlc1    $f12, 0x7($9)                             \n\t"
    "gsldlc1    $f14, 0xF($9)                             \n\t"
    "gsldrc1    $f12, 0x0($9)                             \n\t"
    "gsldrc1    $f14, 0x8($9)                             \n\t"
    PTR_ADDU   "%[pSample1], $8, %[iStride1]              \n\t"
    PTR_ADDU   "%[pSample2], $9, %[iStride2]              \n\t"
    MMI_Get4LW16Sad($f8, $f10, $f0, $f2, $f4, $f6, $f12, $f14, $9)
    "gslqc1     $f10, $f8, 0x0(%[pSample1])               \n\t"
    "gsldlc1    $f12, 0x7(%[pSample2])                    \n\t"
    "gsldlc1    $f14, 0xF(%[pSample2])                    \n\t"
    "gsldrc1    $f12, 0x0(%[pSample2])                    \n\t"
    "gsldrc1    $f14, 0x8(%[pSample2])                    \n\t"
    PTR_ADDU   "$8, %[pSample1], %[iStride1]              \n\t"
    PTR_ADDU   "$9, %[pSample2], %[iStride2]              \n\t"
    MMI_Get4LW16Sad($f0, $f2, $f4, $f6, $f8, $f10, $f12, $f14, %[pSample2])
    "gslqc1     $f2, $f0, 0x0($8)                         \n\t"
    "gsldlc1    $f12, 0x7($9)                             \n\t"
    "gsldlc1    $f14, 0xF($9)                             \n\t"
    "gsldrc1    $f12, 0x0($9)                             \n\t"
    "gsldrc1    $f14, 0x8($9)                             \n\t"
    PTR_ADDU   "%[pSample1], $8, %[iStride1]              \n\t"
    PTR_ADDU   "%[pSample2], $9, %[iStride2]              \n\t"
    MMI_Get4LW16Sad($f4, $f6, $f8, $f10, $f0, $f2, $f12, $f14, $9)
    "gslqc1     $f6, $f4, 0x0(%[pSample1])                \n\t"
    "gsldlc1    $f12, 0x7(%[pSample2])                    \n\t"
    "gsldlc1    $f14, 0xF(%[pSample2])                    \n\t"
    "gsldrc1    $f12, 0x0(%[pSample2])                    \n\t"
    "gsldrc1    $f14, 0x8(%[pSample2])                    \n\t"
    PTR_ADDU   "$8, %[pSample1], %[iStride1]              \n\t"
    PTR_ADDU   "$9, %[pSample2], %[iStride2]              \n\t"
    MMI_Get4LW16Sad($f8, $f10, $f0, $f2, $f4, $f6, $f12, $f14, %[pSample2])

    "gslqc1     $f10, $f8, 0x0($8)                        \n\t"
    "gsldlc1    $f12, 0x7($9)                             \n\t"
    "gsldlc1    $f14, 0xF($9)                             \n\t"
    "gsldrc1    $f12, 0x0($9)                             \n\t"
    "gsldrc1    $f14, 0x8($9)                             \n\t"
    PTR_ADDU   "%[pSample1], $8, %[iStride1]              \n\t"
    PTR_ADDU   "%[pSample2], $9, %[iStride2]              \n\t"
    MMI_Get4LW16Sad($f0, $f2, $f4, $f6, $f8, $f10, $f12, $f14, $9)
    "gslqc1     $f2, $f0, 0x0(%[pSample1])                \n\t"
    "gsldlc1    $f12, 0x7(%[pSample2])                    \n\t"
    "gsldlc1    $f14, 0xF(%[pSample2])                    \n\t"
    "gsldrc1    $f12, 0x0(%[pSample2])                    \n\t"
    "gsldrc1    $f14, 0x8(%[pSample2])                    \n\t"
    PTR_ADDU   "$8, %[pSample1], %[iStride1]              \n\t"
    PTR_ADDU   "$9, %[pSample2], %[iStride2]              \n\t"
    MMI_Get4LW16Sad($f4, $f6, $f8, $f10, $f0, $f2, $f12, $f14, %[pSample2])
    "gslqc1     $f6, $f4, 0x0($8)                         \n\t"
    "gsldlc1    $f12, 0x7($9)                             \n\t"
    "gsldlc1    $f14, 0xF($9)                             \n\t"
    "gsldrc1    $f12, 0x0($9)                             \n\t"
    "gsldrc1    $f14, 0x8($9)                             \n\t"
    PTR_ADDU   "%[pSample1], $8, %[iStride1]              \n\t"
    PTR_ADDU   "%[pSample2], $9, %[iStride2]              \n\t"
    MMI_Get4LW16Sad($f8, $f10, $f0, $f2, $f4, $f6, $f12, $f14, $9)
    "gslqc1     $f10, $f8, 0x0(%[pSample1])               \n\t"
    "gsldlc1    $f12, 0x7(%[pSample2])                    \n\t"
    "gsldlc1    $f14, 0xF(%[pSample2])                    \n\t"
    "gsldrc1    $f12, 0x0(%[pSample2])                    \n\t"
    "gsldrc1    $f14, 0x8(%[pSample2])                    \n\t"
    PTR_ADDU   "$8, %[pSample1], %[iStride1]              \n\t"
    PTR_ADDU   "$9, %[pSample2], %[iStride2]              \n\t"
    MMI_Get4LW16Sad($f0, $f2, $f4, $f6, $f8, $f10, $f12, $f14, %[pSample2])
    "gslqc1     $f2, $f0, 0x0($8)                         \n\t"
    "gsldlc1    $f12, 0x7($9)                             \n\t"
    "gsldlc1    $f14, 0xF($9)                             \n\t"
    "gsldrc1    $f12, 0x0($9)                             \n\t"
    "gsldrc1    $f14, 0x8($9)                             \n\t"
    PTR_ADDU   "%[pSample1], $8, %[iStride1]              \n\t"
    PTR_ADDU   "%[pSample2], $9, %[iStride2]              \n\t"
    MMI_Get4LW16Sad($f4, $f6, $f8, $f10, $f0, $f2, $f12, $f14, $9)
    "gslqc1     $f6, $f4, 0x0(%[pSample1])                \n\t"
    "gsldlc1    $f12, 0x7(%[pSample2])                    \n\t"
    "gsldlc1    $f14, 0xF(%[pSample2])                    \n\t"
    "gsldrc1    $f12, 0x0(%[pSample2])                    \n\t"
    "gsldrc1    $f14, 0x8(%[pSample2])                    \n\t"
    PTR_ADDU   "$8, %[pSample1], %[iStride1]              \n\t"
    PTR_ADDU   "$9, %[pSample2], %[iStride2]              \n\t"
    MMI_Get4LW16Sad($f8, $f10, $f0, $f2, $f4, $f6, $f12, $f14, %[pSample2])

    "gslqc1     $f10, $f8, 0x0($8)                        \n\t"
    "gsldlc1    $f12, 0x7($9)                             \n\t"
    "gsldlc1    $f14, 0xF($9)                             \n\t"
    "gsldrc1    $f12, 0x0($9)                             \n\t"
    "gsldrc1    $f14, 0x8($9)                             \n\t"
    PTR_ADDU   "%[pSample1], $8, %[iStride1]              \n\t"
    PTR_ADDU   "%[pSample2], $9, %[iStride2]              \n\t"
    MMI_Get4LW16Sad($f0, $f2, $f4, $f6, $f8, $f10, $f12, $f14, $9)
    "gslqc1     $f2, $f0, 0x0(%[pSample1])                \n\t"
    "gsldlc1    $f12, 0x7(%[pSample2])                    \n\t"
    "gsldlc1    $f14, 0xF(%[pSample2])                    \n\t"
    "gsldrc1    $f12, 0x0(%[pSample2])                    \n\t"
    "gsldrc1    $f14, 0x8(%[pSample2])                    \n\t"
    PTR_ADDU   "$9, %[pSample2], %[iStride2]              \n\t"
    MMI_Get4LW16Sad($f4, $f6, $f8, $f10, $f0, $f2, $f12, $f14, %[pSample2])
    "gsldlc1    $f12, 0x7($9)                             \n\t"
    "gsldlc1    $f14, 0xF($9)                             \n\t"
    "gsldrc1    $f12, 0x0($9)                             \n\t"
    "gsldrc1    $f14, 0x8($9)                             \n\t"
    "pasubub    $f8, $f8, $f12                            \n\t"
    "pasubub    $f10, $f10, $f14                          \n\t"
    "biadd      $f8, $f8                                  \n\t"
    "biadd      $f10, $f10                                \n\t"
    "paddh      $f20, $f20, $f8                           \n\t"
    "paddh      $f22, $f22, $f10                          \n\t"

    "gsldlc1    $f8, 0x6($9)                              \n\t"
    "gsldlc1    $f10, 0xE($9)                             \n\t"
    "gsldrc1    $f8, -0x1($9)                             \n\t"
    "gsldrc1    $f10, 0x7($9)                             \n\t"
    "pasubub    $f8, $f8, $f0                             \n\t"
    "pasubub    $f10, $f10, $f2                           \n\t"
    "biadd      $f8, $f8                                  \n\t"
    "biadd      $f10, $f10                                \n\t"
    "paddh      $f24, $f24, $f8                           \n\t"
    "paddh      $f26, $f26, $f10                          \n\t"

    "gsldlc1    $f12, 0x8($9)                             \n\t"
    "gsldlc1    $f14, 0x10($9)                            \n\t"
    "gsldrc1    $f12, 0x1($9)                             \n\t"
    "gsldrc1    $f14, 0x9($9)                             \n\t"
    PTR_ADDU   "%[pSample2], $9, %[iStride2]              \n\t"
    "pasubub    $f12, $f12, $f0                           \n\t"
    "pasubub    $f14, $f14, $f2                           \n\t"
    "biadd      $f12, $f12                                \n\t"
    "biadd      $f14, $f14                                \n\t"
    "paddh      $f28, $f28, $f12                          \n\t"
    "paddh      $f30, $f30, $f14                          \n\t"

    "gsldlc1    $f12, 0x7(%[pSample2])                    \n\t"
    "gsldlc1    $f14, 0xF(%[pSample2])                    \n\t"
    "gsldrc1    $f12, 0x0(%[pSample2])                    \n\t"
    "gsldrc1    $f14, 0x8(%[pSample2])                    \n\t"
    "pasubub    $f0, $f0, $f12                            \n\t"
    "pasubub    $f2, $f2, $f14                            \n\t"
    "biadd      $f0, $f0                                  \n\t"
    "biadd      $f2, $f2                                  \n\t"
    "paddh      $f20, $f20, $f0                           \n\t"
    "paddh      $f22, $f22, $f2                           \n\t"

    "paddh      $f16, $f16, $f18                          \n\t"
    "paddh      $f20, $f20, $f22                          \n\t"
    "paddh      $f24, $f24, $f26                          \n\t"
    "paddh      $f28, $f28, $f30                          \n\t"
    "punpcklwd  $f16, $f16, $f20                          \n\t"
    "punpcklwd  $f24, $f24, $f28                          \n\t"
    "gssqc1     $f24, $f16, 0x0(%[pSad])                  \n\t"
    : [pSample1]"+&r"((unsigned char *)pSample1),
      [pSample2]"+&r"((unsigned char *)pSample2)
    : [iStride1]"r"((int)iStride1), [iStride2]"r"((int)iStride2),
      [pSad]"r"((int *)pSad)
    : "memory", "$8", "$9", "$f0", "$f2", "$f4", "$f6", "$f8", "$f10", "$f12",
      "$f14", "$f16", "$f18", "$f20", "$f22", "$f24", "$f26", "$f28", "$f30"
  );
  RECOVER_REG;
}

void WelsSampleSadFour16x8_mmi (uint8_t* pSample1, int32_t iStride1, uint8_t* pSample2,
                                int32_t iStride2, int32_t* pSad) {
  BACKUP_REG;
  __asm__ volatile (
    ".set       arch=loongson3a                           \n\t"
    "xor        $f16, $f16, $f16                          \n\t"
    "xor        $f18, $f18, $f18                          \n\t"
    "xor        $f20, $f20, $f20                          \n\t"
    "xor        $f22, $f22, $f22                          \n\t"
    "gslqc1     $f2, $f0, 0x0(%[pSample1])                \n\t"
    PTR_SUBU   "%[pSample2], %[pSample2], %[iStride2]     \n\t"
    "xor        $f24, $f24, $f24                          \n\t"
    "xor        $f26, $f26, $f26                          \n\t"
    "xor        $f28, $f28, $f28                          \n\t"
    "xor        $f30, $f30, $f30                          \n\t"
    "gsldlc1    $f12, 0x7(%[pSample2])                    \n\t"
    "gsldlc1    $f14, 0xF(%[pSample2])                    \n\t"
    "gsldrc1    $f12, 0x0(%[pSample2])                    \n\t"
    "gsldrc1    $f14, 0x8(%[pSample2])                    \n\t"
    PTR_ADDU   "%[pSample1], %[pSample1], %[iStride1]     \n\t"
    "pasubub    $f12, $f12, $f0                           \n\t"
    "pasubub    $f14, $f14, $f2                           \n\t"
    PTR_ADDU   "%[pSample2], %[pSample2], %[iStride2]     \n\t"
    "biadd      $f12, $f12                                \n\t"
    "biadd      $f14, $f14                                \n\t"
    "paddh      $f16, $f16, $f12                          \n\t"
    "paddh      $f18, $f18, $f14                          \n\t"

    "gslqc1     $f6, $f4, 0x0(%[pSample1])                \n\t"
    "gsldlc1    $f12, 0x7(%[pSample2])                    \n\t"
    "gsldlc1    $f14, 0xF(%[pSample2])                    \n\t"
    "gsldrc1    $f12, 0x0(%[pSample2])                    \n\t"
    "gsldrc1    $f14, 0x8(%[pSample2])                    \n\t"
    "pasubub    $f12, $f12, $f4                           \n\t"
    "pasubub    $f14, $f14, $f6                           \n\t"
    "biadd      $f12, $f12                                \n\t"
    "biadd      $f14, $f14                                \n\t"
    "paddh      $f16, $f16, $f12                          \n\t"
    "paddh      $f18, $f18, $f14                          \n\t"

    "gsldlc1    $f8, 0x6(%[pSample2])                     \n\t"
    "gsldlc1    $f10, 0xE(%[pSample2])                    \n\t"
    "gsldrc1    $f8, -0x1(%[pSample2])                    \n\t"
    "gsldrc1    $f10, 0x7(%[pSample2])                    \n\t"
    "pasubub    $f8, $f8, $f0                             \n\t"
    "pasubub    $f10, $f10, $f2                           \n\t"
    "biadd      $f8, $f8                                  \n\t"
    "biadd      $f10, $f10                                \n\t"
    "paddh      $f24, $f24, $f8                           \n\t"
    "paddh      $f26, $f26, $f10                          \n\t"

    "gsldlc1    $f12, 0x8(%[pSample2])                    \n\t"
    "gsldlc1    $f14, 0x10(%[pSample2])                   \n\t"
    "gsldrc1    $f12, 0x1(%[pSample2])                    \n\t"
    "gsldrc1    $f14, 0x9(%[pSample2])                    \n\t"
    PTR_ADDU   "$8, %[pSample1], %[iStride1]              \n\t"
    "pasubub    $f12, $f12, $f0                           \n\t"
    "pasubub    $f14, $f14, $f2                           \n\t"
    PTR_ADDU   "$9, %[pSample2], %[iStride2]              \n\t"
    "biadd      $f12, $f12                                \n\t"
    "biadd      $f14, $f14                                \n\t"
    "paddh      $f28, $f28, $f12                          \n\t"
    "paddh      $f30, $f30, $f14                          \n\t"

    "gslqc1     $f10, $f8, 0x0($8)                        \n\t"
    "gsldlc1    $f12, 0x7($9)                             \n\t"
    "gsldlc1    $f14, 0xF($9)                             \n\t"
    "gsldrc1    $f12, 0x0($9)                             \n\t"
    "gsldrc1    $f14, 0x8($9)                             \n\t"
    PTR_ADDU   "%[pSample1], $8, %[iStride1]              \n\t"
    PTR_ADDU   "%[pSample2], $9, %[iStride2]              \n\t"
    MMI_Get4LW16Sad($f0, $f2, $f4, $f6, $f8, $f10, $f12, $f14, $9)
    "gslqc1     $f2, $f0, 0x0(%[pSample1])                \n\t"
    "gsldlc1    $f12, 0x7(%[pSample2])                    \n\t"
    "gsldlc1    $f14, 0xF(%[pSample2])                    \n\t"
    "gsldrc1    $f12, 0x0(%[pSample2])                    \n\t"
    "gsldrc1    $f14, 0x8(%[pSample2])                    \n\t"
    PTR_ADDU   "$8, %[pSample1], %[iStride1]              \n\t"
    PTR_ADDU   "$9, %[pSample2], %[iStride2]              \n\t"
    MMI_Get4LW16Sad($f4, $f6, $f8, $f10, $f0, $f2, $f12, $f14, %[pSample2])
    "gslqc1     $f6, $f4, 0x0($8)                         \n\t"
    "gsldlc1    $f12, 0x7($9)                             \n\t"
    "gsldlc1    $f14, 0xF($9)                             \n\t"
    "gsldrc1    $f12, 0x0($9)                             \n\t"
    "gsldrc1    $f14, 0x8($9)                             \n\t"
    PTR_ADDU   "%[pSample1], $8, %[iStride1]              \n\t"
    PTR_ADDU   "%[pSample2], $9, %[iStride2]              \n\t"
    MMI_Get4LW16Sad($f8, $f10, $f0, $f2, $f4, $f6, $f12, $f14, $9)
    "gslqc1     $f10, $f8, 0x0(%[pSample1])               \n\t"
    "gsldlc1    $f12, 0x7(%[pSample2])                    \n\t"
    "gsldlc1    $f14, 0xF(%[pSample2])                    \n\t"
    "gsldrc1    $f12, 0x0(%[pSample2])                    \n\t"
    "gsldrc1    $f14, 0x8(%[pSample2])                    \n\t"
    PTR_ADDU   "$8, %[pSample1], %[iStride1]              \n\t"
    PTR_ADDU   "$9, %[pSample2], %[iStride2]              \n\t"
    MMI_Get4LW16Sad($f0, $f2, $f4, $f6, $f8, $f10, $f12, $f14, %[pSample2])
    "gslqc1     $f2, $f0, 0x0($8)                         \n\t"
    "gsldlc1    $f12, 0x7($9)                             \n\t"
    "gsldlc1    $f14, 0xF($9)                             \n\t"
    "gsldrc1    $f12, 0x0($9)                             \n\t"
    "gsldrc1    $f14, 0x8($9)                             \n\t"
    PTR_ADDU   "%[pSample1], $8, %[iStride1]              \n\t"
    PTR_ADDU   "%[pSample2], $9, %[iStride2]              \n\t"
    MMI_Get4LW16Sad($f4, $f6, $f8, $f10, $f0, $f2, $f12, $f14, $9)
    "gslqc1     $f6, $f4, 0x0(%[pSample1])                \n\t"
    "gsldlc1    $f12, 0x7(%[pSample2])                    \n\t"
    "gsldlc1    $f14, 0xF(%[pSample2])                    \n\t"
    "gsldrc1    $f12, 0x0(%[pSample2])                    \n\t"
    "gsldrc1    $f14, 0x8(%[pSample2])                    \n\t"
    PTR_ADDU   "$9, %[pSample2], %[iStride2]              \n\t"
    MMI_Get4LW16Sad($f8, $f10, $f0, $f2, $f4, $f6, $f12, $f14, %[pSample2])
    "gsldlc1    $f12, 0x7($9)                             \n\t"
    "gsldlc1    $f14, 0xF($9)                             \n\t"
    "gsldrc1    $f12, 0x0($9)                             \n\t"
    "gsldrc1    $f14, 0x8($9)                             \n\t"
    "pasubub    $f0, $f0, $f12                            \n\t"
    "pasubub    $f2, $f2, $f14                            \n\t"
    "biadd      $f0, $f0                                  \n\t"
    "biadd      $f2, $f2                                  \n\t"
    "paddh      $f20, $f20, $f0                           \n\t"
    "paddh      $f22, $f22, $f2                           \n\t"

    "gsldlc1    $f0, 0x6($9)                              \n\t"
    "gsldlc1    $f2, 0xE($9)                              \n\t"
    "gsldrc1    $f0, -0x1($9)                             \n\t"
    "gsldrc1    $f2, 0x7($9)                              \n\t"
    "pasubub    $f0, $f0, $f4                             \n\t"
    "pasubub    $f2, $f2, $f6                             \n\t"
    "biadd      $f0, $f0                                  \n\t"
    "biadd      $f2, $f2                                  \n\t"
    "paddh      $f24, $f24, $f0                           \n\t"
    "paddh      $f26, $f26, $f2                           \n\t"

    "gsldlc1    $f12, 0x8($9)                             \n\t"
    "gsldlc1    $f14, 0x10($9)                            \n\t"
    "gsldrc1    $f12, 0x1($9)                             \n\t"
    "gsldrc1    $f14, 0x9($9)                             \n\t"
    PTR_ADDU   "%[pSample2], $9, %[iStride2]              \n\t"
    "pasubub    $f12, $f12, $f4                           \n\t"
    "pasubub    $f14, $f14, $f6                           \n\t"
    "biadd      $f12, $f12                                \n\t"
    "biadd      $f14, $f14                                \n\t"
    "paddh      $f28, $f28, $f12                          \n\t"
    "paddh      $f30, $f30, $f14                          \n\t"

    "gsldlc1    $f12, 0x7(%[pSample2])                    \n\t"
    "gsldlc1    $f14, 0xF(%[pSample2])                    \n\t"
    "gsldrc1    $f12, 0x0(%[pSample2])                    \n\t"
    "gsldrc1    $f14, 0x8(%[pSample2])                    \n\t"
    "pasubub    $f4, $f4, $f12                            \n\t"
    "pasubub    $f6, $f6, $f14                            \n\t"
    "biadd      $f4, $f4                                  \n\t"
    "biadd      $f6, $f6                                  \n\t"
    "paddh      $f20, $f20, $f4                           \n\t"
    "paddh      $f22, $f22, $f6                           \n\t"

    "paddh      $f16, $f16, $f18                          \n\t"
    "paddh      $f20, $f20, $f22                          \n\t"
    "paddh      $f24, $f24, $f26                          \n\t"
    "paddh      $f28, $f28, $f30                          \n\t"
    "punpcklwd  $f16, $f16, $f20                          \n\t"
    "punpcklwd  $f24, $f24, $f28                          \n\t"
    "gssqc1     $f24, $f16, 0x0(%[pSad])                  \n\t"
    : [pSample1]"+&r"((unsigned char *)pSample1),
      [pSample2]"+&r"((unsigned char *)pSample2)
    : [iStride1]"r"((int)iStride1), [iStride2]"r"((int)iStride2),
      [pSad]"r"((int *)pSad)
    : "memory", "$8", "$9", "$f0", "$f2", "$f4", "$f6", "$f8", "$f10", "$f12",
      "$f14", "$f16", "$f18", "$f20", "$f22", "$f24", "$f26", "$f28","$f30"
  );
  RECOVER_REG;
}

void WelsSampleSadFour8x16_mmi (uint8_t* pSample1, int32_t iStride1, uint8_t* pSample2,
                                int32_t iStride2, int32_t* pSad) {
  BACKUP_REG;
  __asm__ volatile (
    ".set       arch=loongson3a                           \n\t"
    "xor        $f16, $f16, $f16                          \n\t"
    "xor        $f18, $f18, $f18                          \n\t"
    "xor        $f20, $f20, $f20                          \n\t"
    "xor        $f22, $f22, $f22                          \n\t"
    "xor        $f24, $f24, $f24                          \n\t"
    "xor        $f26, $f26, $f26                          \n\t"
    "xor        $f28, $f28, $f28                          \n\t"
    "xor        $f30, $f30, $f30                          \n\t"
    PTR_ADDU   "$8, %[pSample1], %[iStride1]              \n\t"
    PTR_SUBU   "$9, %[pSample2], %[iStride2]              \n\t"
    PTR_ADDU   "%[pSample2], $9, %[iStride2]              \n\t"
    "gsldlc1    $f0, 0x7(%[pSample1])                     \n\t"
    "gsldlc1    $f2, 0x7($8)                              \n\t"
    "gsldlc1    $f12, 0x7($9)                             \n\t"
    "gsldlc1    $f14, 0x7(%[pSample2])                    \n\t"
    "gsldrc1    $f0, 0x0(%[pSample1])                     \n\t"
    "gsldrc1    $f2, 0x0($8)                              \n\t"
    "gsldrc1    $f12, 0x0($9)                             \n\t"
    "gsldrc1    $f14, 0x0(%[pSample2])                    \n\t"
    "pasubub    $f12, $f12, $f0                           \n\t"
    "pasubub    $f14, $f14, $f2                           \n\t"
    "biadd      $f12, $f12                                \n\t"
    "biadd      $f14, $f14                                \n\t"
    "paddh      $f16, $f16, $f12                          \n\t"
    "paddh      $f18, $f18, $f14                          \n\t"

    PTR_ADDU   "$9, %[pSample2], %[iStride2]              \n\t"
    "gsldlc1    $f4, 0x6(%[pSample2])                     \n\t"
    "gsldlc1    $f12, 0x8(%[pSample2])                    \n\t"
    "gsldrc1    $f4, -0x1(%[pSample2])                    \n\t"
    "gsldrc1    $f12, 0x1(%[pSample2])                    \n\t"

    PTR_ADDU   "%[pSample1], $8, %[iStride1]              \n\t"
    "gsldlc1    $f6, 0x6($9)                              \n\t"
    "gsldlc1    $f14, 0x8($9)                             \n\t"
    "gsldrc1    $f6, -0x1($9)                             \n\t"
    "gsldrc1    $f14, 0x1($9)                             \n\t"
    "pasubub    $f4, $f4, $f0                             \n\t"
    "pasubub    $f6, $f6, $f2                             \n\t"
    "biadd      $f4, $f4                                  \n\t"
    "biadd      $f6, $f6                                  \n\t"
    "paddh      $f24, $f24, $f4                           \n\t"
    "paddh      $f26, $f26, $f6                           \n\t"
    "pasubub    $f12, $f12, $f0                           \n\t"
    "pasubub    $f14, $f14, $f2                           \n\t"
    PTR_ADDU   "%[pSample2], $9, %[iStride2]              \n\t"
    "biadd      $f12, $f12                                \n\t"
    "biadd      $f14, $f14                                \n\t"
    "paddh      $f28, $f28, $f12                          \n\t"
    "paddh      $f30, $f30, $f14                          \n\t"

    "gsldlc1    $f12, 0x7($9)                             \n\t"
    "gsldlc1    $f14, 0x7(%[pSample2])                    \n\t"
    "gsldrc1    $f12, 0x0($9)                             \n\t"
    "gsldrc1    $f14, 0x0(%[pSample2])                    \n\t"
    "pasubub    $f0, $f0, $f12                            \n\t"
    "pasubub    $f2, $f2, $f14                            \n\t"
    PTR_ADDU   "$8, %[pSample1], %[iStride1]              \n\t"
    "biadd      $f0, $f0                                  \n\t"
    "biadd      $f2, $f2                                  \n\t"
    "paddh      $f20, $f20, $f0                           \n\t"
    "paddh      $f22, $f22, $f2                           \n\t"

    "gsldlc1    $f0, 0x7(%[pSample1])                     \n\t"
    "gsldlc1    $f2, 0x7($8)                              \n\t"
    "gsldrc1    $f0, 0x0(%[pSample1])                     \n\t"
    "gsldrc1    $f2, 0x0($8)                              \n\t"
    "pasubub    $f12, $f12, $f0                           \n\t"
    "pasubub    $f14, $f14, $f2                           \n\t"
    "biadd      $f12, $f12                                \n\t"
    "biadd      $f14, $f14                                \n\t"
    "paddh      $f16, $f16, $f12                          \n\t"
    "paddh      $f18, $f18, $f14                          \n\t"

    "gsldlc1    $f4, 0x6(%[pSample2])                     \n\t"
    "gsldlc1    $f12, 0x8(%[pSample2])                    \n\t"
    PTR_ADDU   "$9, %[pSample2], %[iStride2]              \n\t"
    "gsldrc1    $f4, -0x1(%[pSample2])                    \n\t"
    "gsldrc1    $f12, 0x1(%[pSample2])                    \n\t"

    PTR_ADDU   "%[pSample1], $8, %[iStride1]              \n\t"
    "gsldlc1    $f6, 0x6($9)                              \n\t"
    "gsldlc1    $f14, 0x8($9)                             \n\t"
    "gsldrc1    $f6, -0x1($9)                             \n\t"
    "gsldrc1    $f14, 0x1($9)                             \n\t"

    "pasubub    $f4, $f4, $f0                             \n\t"
    "pasubub    $f6, $f6, $f2                             \n\t"
    "biadd      $f4, $f4                                  \n\t"
    "biadd      $f6, $f6                                  \n\t"
    "paddh      $f24, $f24, $f4                           \n\t"
    "paddh      $f26, $f26, $f6                           \n\t"
    "pasubub    $f12, $f12, $f0                           \n\t"
    "pasubub    $f14, $f14, $f2                           \n\t"
    PTR_ADDU   "%[pSample2], $9, %[iStride2]              \n\t"
    "biadd      $f12, $f12                                \n\t"
    "biadd      $f14, $f14                                \n\t"
    "paddh      $f28, $f28, $f12                          \n\t"
    "paddh      $f30, $f30, $f14                          \n\t"

    "gsldlc1    $f12, 0x7($9)                             \n\t"
    "gsldlc1    $f14, 0x7(%[pSample2])                    \n\t"
    "gsldrc1    $f12, 0x0($9)                             \n\t"
    "gsldrc1    $f14, 0x0(%[pSample2])                    \n\t"
    "pasubub    $f0, $f0, $f12                            \n\t"
    "pasubub    $f2, $f2, $f14                            \n\t"
    PTR_ADDU   "$8, %[pSample1], %[iStride1]              \n\t"
    "biadd      $f0, $f0                                  \n\t"
    "biadd      $f2, $f2                                  \n\t"
    "paddh      $f20, $f20, $f0                           \n\t"
    "paddh      $f22, $f22, $f2                           \n\t"

    "gsldlc1    $f0, 0x7(%[pSample1])                     \n\t"
    "gsldlc1    $f2, 0x7($8)                              \n\t"
    "gsldrc1    $f0, 0x0(%[pSample1])                     \n\t"
    "gsldrc1    $f2, 0x0($8)                              \n\t"
    "pasubub    $f12, $f12, $f0                           \n\t"
    "pasubub    $f14, $f14, $f2                           \n\t"
    "biadd      $f12, $f12                                \n\t"
    "biadd      $f14, $f14                                \n\t"
    "paddh      $f16, $f16, $f12                          \n\t"
    "paddh      $f18, $f18, $f14                          \n\t"

    "gsldlc1    $f4, 0x6(%[pSample2])                     \n\t"
    "gsldlc1    $f12, 0x8(%[pSample2])                    \n\t"
    PTR_ADDU   "$9, %[pSample2], %[iStride2]              \n\t"
    "gsldrc1    $f4, -0x1(%[pSample2])                    \n\t"
    "gsldrc1    $f12, 0x1(%[pSample2])                    \n\t"

    PTR_ADDU   "%[pSample1], $8, %[iStride1]              \n\t"
    "gsldlc1    $f6, 0x6($9)                              \n\t"
    "gsldlc1    $f14, 0x8($9)                             \n\t"
    "gsldrc1    $f6, -0x1($9)                             \n\t"
    "gsldrc1    $f14, 0x1($9)                             \n\t"

    "pasubub    $f4, $f4, $f0                             \n\t"
    "pasubub    $f6, $f6, $f2                             \n\t"
    "biadd      $f4, $f4                                  \n\t"
    "biadd      $f6, $f6                                  \n\t"
    "paddh      $f24, $f24, $f4                           \n\t"
    "paddh      $f26, $f26, $f6                           \n\t"
    "pasubub    $f12, $f12, $f0                           \n\t"
    "pasubub    $f14, $f14, $f2                           \n\t"
    PTR_ADDU   "%[pSample2], $9, %[iStride2]              \n\t"
    "biadd      $f12, $f12                                \n\t"
    "biadd      $f14, $f14                                \n\t"
    "paddh      $f28, $f28, $f12                          \n\t"
    "paddh      $f30, $f30, $f14                          \n\t"

    "gsldlc1    $f12, 0x7($9)                             \n\t"
    "gsldlc1    $f14, 0x7(%[pSample2])                    \n\t"
    "gsldrc1    $f12, 0x0($9)                             \n\t"
    "gsldrc1    $f14, 0x0(%[pSample2])                    \n\t"
    "pasubub    $f0, $f0, $f12                            \n\t"
    "pasubub    $f2, $f2, $f14                            \n\t"
    PTR_ADDU   "$8, %[pSample1], %[iStride1]              \n\t"
    "biadd      $f0, $f0                                  \n\t"
    "biadd      $f2, $f2                                  \n\t"
    "paddh      $f20, $f20, $f0                           \n\t"
    "paddh      $f22, $f22, $f2                           \n\t"

    "gsldlc1    $f0, 0x7(%[pSample1])                     \n\t"
    "gsldlc1    $f2, 0x7($8)                              \n\t"
    "gsldrc1    $f0, 0x0(%[pSample1])                     \n\t"
    "gsldrc1    $f2, 0x0($8)                              \n\t"
    "pasubub    $f12, $f12, $f0                           \n\t"
    "pasubub    $f14, $f14, $f2                           \n\t"
    "biadd      $f12, $f12                                \n\t"
    "biadd      $f14, $f14                                \n\t"
    "paddh      $f16, $f16, $f12                          \n\t"
    "paddh      $f18, $f18, $f14                          \n\t"

    "gsldlc1    $f4, 0x6(%[pSample2])                     \n\t"
    "gsldlc1    $f12, 0x8(%[pSample2])                    \n\t"
    PTR_ADDU   "$9, %[pSample2], %[iStride2]              \n\t"
    "gsldrc1    $f4, -0x1(%[pSample2])                    \n\t"
    "gsldrc1    $f12, 0x1(%[pSample2])                    \n\t"

    PTR_ADDU   "%[pSample1], $8, %[iStride1]              \n\t"
    "gsldlc1    $f6, 0x6($9)                              \n\t"
    "gsldlc1    $f14, 0x8($9)                             \n\t"
    "gsldrc1    $f6, -0x1($9)                             \n\t"
    "gsldrc1    $f14, 0x1($9)                             \n\t"
    "pasubub    $f4, $f4, $f0                             \n\t"
    "pasubub    $f6, $f6, $f2                             \n\t"
    "biadd      $f4, $f4                                  \n\t"
    "biadd      $f6, $f6                                  \n\t"
    "paddh      $f24, $f24, $f4                           \n\t"
    "paddh      $f26, $f26, $f6                           \n\t"
    "pasubub    $f12, $f12, $f0                           \n\t"
    "pasubub    $f14, $f14, $f2                           \n\t"
    PTR_ADDU   "%[pSample2], $9, %[iStride2]              \n\t"
    "biadd      $f12, $f12                                \n\t"
    "biadd      $f14, $f14                                \n\t"
    "paddh      $f28, $f28, $f12                          \n\t"
    "paddh      $f30, $f30, $f14                          \n\t"

    "gsldlc1    $f12, 0x7($9)                             \n\t"
    "gsldlc1    $f14, 0x7(%[pSample2])                    \n\t"
    "gsldrc1    $f12, 0x0($9)                             \n\t"
    "gsldrc1    $f14, 0x0(%[pSample2])                    \n\t"
    "pasubub    $f0, $f0, $f12                            \n\t"
    "pasubub    $f2, $f2, $f14                            \n\t"
    PTR_ADDU   "$8, %[pSample1], %[iStride1]              \n\t"
    "biadd      $f0, $f0                                  \n\t"
    "biadd      $f2, $f2                                  \n\t"
    "paddh      $f20, $f20, $f0                           \n\t"
    "paddh      $f22, $f22, $f2                           \n\t"

    "gsldlc1    $f0, 0x7(%[pSample1])                     \n\t"
    "gsldlc1    $f2, 0x7($8)                              \n\t"
    "gsldrc1    $f0, 0x0(%[pSample1])                     \n\t"
    "gsldrc1    $f2, 0x0($8)                              \n\t"
    "pasubub    $f12, $f12, $f0                           \n\t"
    "pasubub    $f14, $f14, $f2                           \n\t"
    "biadd      $f12, $f12                                \n\t"
    "biadd      $f14, $f14                                \n\t"
    "paddh      $f16, $f16, $f12                          \n\t"
    "paddh      $f18, $f18, $f14                          \n\t"

    "gsldlc1    $f4, 0x6(%[pSample2])                     \n\t"
    "gsldlc1    $f12, 0x8(%[pSample2])                    \n\t"
    PTR_ADDU   "$9, %[pSample2], %[iStride2]              \n\t"
    "gsldrc1    $f4, -0x1(%[pSample2])                    \n\t"
    "gsldrc1    $f12, 0x1(%[pSample2])                    \n\t"

    PTR_ADDU   "%[pSample1], $8, %[iStride1]              \n\t"
    "gsldlc1    $f6, 0x6($9)                              \n\t"
    "gsldlc1    $f14, 0x8($9)                             \n\t"
    "gsldrc1    $f6, -0x1($9)                             \n\t"
    "gsldrc1    $f14, 0x1($9)                             \n\t"

    "pasubub    $f4, $f4, $f0                             \n\t"
    "pasubub    $f6, $f6, $f2                             \n\t"
    "biadd      $f4, $f4                                  \n\t"
    "biadd      $f6, $f6                                  \n\t"
    "paddh      $f24, $f24, $f4                           \n\t"
    "paddh      $f26, $f26, $f6                           \n\t"
    "pasubub    $f12, $f12, $f0                           \n\t"
    "pasubub    $f14, $f14, $f2                           \n\t"
    PTR_ADDU   "%[pSample2], $9, %[iStride2]              \n\t"
    "biadd      $f12, $f12                                \n\t"
    "biadd      $f14, $f14                                \n\t"
    "paddh      $f28, $f28, $f12                          \n\t"
    "paddh      $f30, $f30, $f14                          \n\t"

    "gsldlc1    $f12, 0x7($9)                             \n\t"
    "gsldlc1    $f14, 0x7(%[pSample2])                    \n\t"
    "gsldrc1    $f12, 0x0($9)                             \n\t"
    "gsldrc1    $f14, 0x0(%[pSample2])                    \n\t"
    "pasubub    $f0, $f0, $f12                            \n\t"
    "pasubub    $f2, $f2, $f14                            \n\t"
    PTR_ADDU   "$8, %[pSample1], %[iStride1]              \n\t"
    "biadd      $f0, $f0                                  \n\t"
    "biadd      $f2, $f2                                  \n\t"
    "paddh      $f20, $f20, $f0                           \n\t"
    "paddh      $f22, $f22, $f2                           \n\t"

    "gsldlc1    $f0, 0x7(%[pSample1])                     \n\t"
    "gsldlc1    $f2, 0x7($8)                              \n\t"
    "gsldrc1    $f0, 0x0(%[pSample1])                     \n\t"
    "gsldrc1    $f2, 0x0($8)                              \n\t"
    "pasubub    $f12, $f12, $f0                           \n\t"
    "pasubub    $f14, $f14, $f2                           \n\t"
    "biadd      $f12, $f12                                \n\t"
    "biadd      $f14, $f14                                \n\t"
    "paddh      $f16, $f16, $f12                          \n\t"
    "paddh      $f18, $f18, $f14                          \n\t"

    "gsldlc1    $f4, 0x6(%[pSample2])                     \n\t"
    "gsldlc1    $f12, 0x8(%[pSample2])                    \n\t"
    PTR_ADDU   "$9, %[pSample2], %[iStride2]              \n\t"
    "gsldrc1    $f4, -0x1(%[pSample2])                    \n\t"
    "gsldrc1    $f12, 0x1(%[pSample2])                    \n\t"

    PTR_ADDU   "%[pSample1], $8, %[iStride1]              \n\t"
    "gsldlc1    $f6, 0x6($9)                              \n\t"
    "gsldlc1    $f14, 0x8($9)                             \n\t"
    "gsldrc1    $f6, -0x1($9)                             \n\t"
    "gsldrc1    $f14, 0x1($9)                             \n\t"

    "pasubub    $f4, $f4, $f0                             \n\t"
    "pasubub    $f6, $f6, $f2                             \n\t"
    "biadd      $f4, $f4                                  \n\t"
    "biadd      $f6, $f6                                  \n\t"
    "paddh      $f24, $f24, $f4                           \n\t"
    "paddh      $f26, $f26, $f6                           \n\t"
    "pasubub    $f12, $f12, $f0                           \n\t"
    "pasubub    $f14, $f14, $f2                           \n\t"
    PTR_ADDU   "%[pSample2], $9, %[iStride2]              \n\t"
    "biadd      $f12, $f12                                \n\t"
    "biadd      $f14, $f14                                \n\t"
    "paddh      $f28, $f28, $f12                          \n\t"
    "paddh      $f30, $f30, $f14                          \n\t"

    "gsldlc1    $f12, 0x7($9)                             \n\t"
    "gsldlc1    $f14, 0x7(%[pSample2])                    \n\t"
    "gsldrc1    $f12, 0x0($9)                             \n\t"
    "gsldrc1    $f14, 0x0(%[pSample2])                    \n\t"
    "pasubub    $f0, $f0, $f12                            \n\t"
    "pasubub    $f2, $f2, $f14                            \n\t"
    PTR_ADDU   "$8, %[pSample1], %[iStride1]              \n\t"
    "biadd      $f0, $f0                                  \n\t"
    "biadd      $f2, $f2                                  \n\t"
    "paddh      $f20, $f20, $f0                           \n\t"
    "paddh      $f22, $f22, $f2                           \n\t"

    "gsldlc1    $f0, 0x7(%[pSample1])                     \n\t"
    "gsldlc1    $f2, 0x7($8)                              \n\t"
    "gsldrc1    $f0, 0x0(%[pSample1])                     \n\t"
    "gsldrc1    $f2, 0x0($8)                              \n\t"
    "pasubub    $f12, $f12, $f0                           \n\t"
    "pasubub    $f14, $f14, $f2                           \n\t"
    "biadd      $f12, $f12                                \n\t"
    "biadd      $f14, $f14                                \n\t"
    "paddh      $f16, $f16, $f12                          \n\t"
    "paddh      $f18, $f18, $f14                          \n\t"

    "gsldlc1    $f4, 0x6(%[pSample2])                     \n\t"
    "gsldlc1    $f12, 0x8(%[pSample2])                    \n\t"
    PTR_ADDU   "$9, %[pSample2], %[iStride2]              \n\t"
    "gsldrc1    $f4, -0x1(%[pSample2])                    \n\t"
    "gsldrc1    $f12, 0x1(%[pSample2])                    \n\t"

    PTR_ADDU   "%[pSample1], $8, %[iStride1]              \n\t"
    "gsldlc1    $f6, 0x6($9)                              \n\t"
    "gsldlc1    $f14, 0x8($9)                             \n\t"
    "gsldrc1    $f6, -0x1($9)                             \n\t"
    "gsldrc1    $f14, 0x1($9)                             \n\t"

    "pasubub    $f4, $f4, $f0                             \n\t"
    "pasubub    $f6, $f6, $f2                             \n\t"
    "biadd      $f4, $f4                                  \n\t"
    "biadd      $f6, $f6                                  \n\t"
    "paddh      $f24, $f24, $f4                           \n\t"
    "paddh      $f26, $f26, $f6                           \n\t"
    "pasubub    $f12, $f12, $f0                           \n\t"
    "pasubub    $f14, $f14, $f2                           \n\t"
    PTR_ADDU   "%[pSample2], $9, %[iStride2]              \n\t"
    "biadd      $f12, $f12                                \n\t"
    "biadd      $f14, $f14                                \n\t"
    "paddh      $f28, $f28, $f12                          \n\t"
    "paddh      $f30, $f30, $f14                          \n\t"

    "gsldlc1    $f12, 0x7($9)                             \n\t"
    "gsldlc1    $f14, 0x7(%[pSample2])                    \n\t"
    "gsldrc1    $f12, 0x0($9)                             \n\t"
    "gsldrc1    $f14, 0x0(%[pSample2])                    \n\t"
    "pasubub    $f0, $f0, $f12                            \n\t"
    "pasubub    $f2, $f2, $f14                            \n\t"
    PTR_ADDU   "$8, %[pSample1], %[iStride1]              \n\t"
    "biadd      $f0, $f0                                  \n\t"
    "biadd      $f2, $f2                                  \n\t"
    "paddh      $f20, $f20, $f0                           \n\t"
    "paddh      $f22, $f22, $f2                           \n\t"

    "gsldlc1    $f0, 0x7(%[pSample1])                     \n\t"
    "gsldlc1    $f2, 0x7($8)                              \n\t"
    "gsldrc1    $f0, 0x0(%[pSample1])                     \n\t"
    "gsldrc1    $f2, 0x0($8)                              \n\t"
    "pasubub    $f12, $f12, $f0                           \n\t"
    "pasubub    $f14, $f14, $f2                           \n\t"
    "biadd      $f12, $f12                                \n\t"
    "biadd      $f14, $f14                                \n\t"
    "paddh      $f16, $f16, $f12                          \n\t"
    "paddh      $f18, $f18, $f14                          \n\t"

    "gsldlc1    $f4, 0x6(%[pSample2])                     \n\t"
    "gsldlc1    $f12, 0x8(%[pSample2])                    \n\t"
    PTR_ADDU   "$9, %[pSample2], %[iStride2]              \n\t"
    "gsldrc1    $f4, -0x1(%[pSample2])                    \n\t"
    "gsldrc1    $f12, 0x1(%[pSample2])                    \n\t"

    PTR_ADDU   "%[pSample1], $8, %[iStride1]              \n\t"
    "gsldlc1    $f6, 0x6($9)                              \n\t"
    "gsldlc1    $f14, 0x8($9)                             \n\t"
    "gsldrc1    $f6, -0x1($9)                             \n\t"
    "gsldrc1    $f14, 0x1($9)                             \n\t"

    "pasubub    $f4, $f4, $f0                             \n\t"
    "pasubub    $f6, $f6, $f2                             \n\t"
    "biadd      $f4, $f4                                  \n\t"
    "biadd      $f6, $f6                                  \n\t"
    "paddh      $f24, $f24, $f4                           \n\t"
    "paddh      $f26, $f26, $f6                           \n\t"
    "pasubub    $f12, $f12, $f0                           \n\t"
    "pasubub    $f14, $f14, $f2                           \n\t"
    PTR_ADDU   "%[pSample2], $9, %[iStride2]              \n\t"
    "biadd      $f12, $f12                                \n\t"
    "biadd      $f14, $f14                                \n\t"
    "paddh      $f28, $f28, $f12                          \n\t"
    "paddh      $f30, $f30, $f14                          \n\t"

    "gsldlc1    $f12, 0x7($9)                             \n\t"
    "gsldlc1    $f14, 0x7(%[pSample2])                    \n\t"
    "gsldrc1    $f12, 0x0($9)                             \n\t"
    "gsldrc1    $f14, 0x0(%[pSample2])                    \n\t"
    "pasubub    $f0, $f0, $f12                            \n\t"
    "pasubub    $f2, $f2, $f14                            \n\t"
    "biadd      $f0, $f0                                  \n\t"
    "biadd      $f2, $f2                                  \n\t"
    "paddh      $f20, $f20, $f0                           \n\t"
    "paddh      $f22, $f22, $f2                           \n\t"

    "paddh      $f16, $f16, $f18                          \n\t"
    "paddh      $f20, $f20, $f22                          \n\t"
    "paddh      $f24, $f24, $f26                          \n\t"
    "paddh      $f28, $f28, $f30                          \n\t"
    "punpcklwd  $f16, $f16, $f20                          \n\t"
    "punpcklwd  $f24, $f24, $f28                          \n\t"
    "gssqc1     $f24, $f16, 0x0(%[pSad])                  \n\t"
    : [pSample1]"+&r"((unsigned char *)pSample1),
      [pSample2]"+&r"((unsigned char *)pSample2)
    : [iStride1]"r"((int)iStride1), [iStride2]"r"((int)iStride2),
      [pSad]"r"((int *)pSad)
    : "memory", "$8", "$9", "$f0", "$f2", "$f4", "$f6", "$f8", "$f10", "$f12",
      "$f14", "$f16", "$f18", "$f20", "$f22", "$f24", "$f26", "$f28", "$f30"
  );
  RECOVER_REG;
}

void WelsSampleSadFour8x8_mmi (uint8_t* pSample1, int32_t iStride1, uint8_t* pSample2,
                               int32_t iStride2, int32_t* pSad) {
  BACKUP_REG;
  __asm__ volatile (
    ".set       arch=loongson3a                           \n\t"
    "xor        $f16, $f16, $f16                          \n\t"
    "xor        $f18, $f18, $f18                          \n\t"
    "gsldlc1    $f0, 0x7(%[pSample1])                     \n\t"
    "xor        $f20, $f20, $f20                          \n\t"
    "xor        $f22, $f22, $f22                          \n\t"
    "gsldrc1    $f0, 0x0(%[pSample1])                     \n\t"
    "xor        $f24, $f24, $f24                          \n\t"
    "xor        $f26, $f26, $f26                          \n\t"
    PTR_ADDU   "$8, %[pSample1], %[iStride1]              \n\t"
    PTR_SUBU   "$9, %[pSample2], %[iStride2]              \n\t"
    "xor        $f28, $f28, $f28                          \n\t"
    "xor        $f30, $f30, $f30                          \n\t"
    "gsldlc1    $f2, 0x7($8)                              \n\t"
    "gsldlc1    $f12, 0x7($9)                             \n\t"
    PTR_ADDU   "%[pSample2], $9, %[iStride2]              \n\t"
    "gsldrc1    $f2, 0x0($8)                              \n\t"
    "gsldrc1    $f12, 0x0($9)                             \n\t"
    "gsldlc1    $f14, 0x7(%[pSample2])                    \n\t"
    "gsldrc1    $f14, 0x0(%[pSample2])                    \n\t"
    "pasubub    $f12, $f12, $f0                           \n\t"
    "pasubub    $f14, $f14, $f2                           \n\t"
    "biadd      $f12, $f12                                \n\t"
    "biadd      $f14, $f14                                \n\t"
    "paddh      $f16, $f16, $f12                          \n\t"
    "paddh      $f18, $f18, $f14                          \n\t"

    "gsldlc1    $f4, 0x6(%[pSample2])                     \n\t"
    "gsldlc1    $f12, 0x8(%[pSample2])                    \n\t"
    PTR_ADDU   "$9, %[pSample2], %[iStride2]              \n\t"
    PTR_ADDU   "%[pSample1], $8, %[iStride1]              \n\t"
    "gsldrc1    $f4, -0x1(%[pSample2])                    \n\t"
    "gsldrc1    $f12, 0x1(%[pSample2])                    \n\t"

    "gsldlc1    $f6, 0x6($9)                              \n\t"
    "gsldlc1    $f14, 0x8($9)                             \n\t"
    "gsldrc1    $f6, -0x1($9)                             \n\t"
    "gsldrc1    $f14, 0x1($9)                             \n\t"
    "pasubub    $f4, $f4, $f0                             \n\t"
    "pasubub    $f6, $f6, $f2                             \n\t"
    "biadd      $f4, $f4                                  \n\t"
    "biadd      $f6, $f6                                  \n\t"
    "paddh      $f24, $f24, $f4                           \n\t"
    "paddh      $f26, $f26, $f6                           \n\t"
    "pasubub    $f12, $f12, $f0                           \n\t"
    "pasubub    $f14, $f14, $f2                           \n\t"
    "biadd      $f12, $f12                                \n\t"
    "biadd      $f14, $f14                                \n\t"
    "paddh      $f28, $f28, $f12                          \n\t"
    PTR_ADDU   "%[pSample2], $9, %[iStride2]              \n\t"
    "paddh      $f30, $f30, $f14                          \n\t"

    "gsldlc1    $f12, 0x7($9)                             \n\t"
    "gsldlc1    $f14, 0x7(%[pSample2])                    \n\t"
    "gsldrc1    $f12, 0x0($9)                             \n\t"
    "gsldrc1    $f14, 0x0(%[pSample2])                    \n\t"
    "pasubub    $f0, $f0, $f12                            \n\t"
    "pasubub    $f2, $f2, $f14                            \n\t"
    PTR_ADDU   "$8, %[pSample1], %[iStride1]              \n\t"
    "biadd      $f0, $f0                                  \n\t"
    "biadd      $f2, $f2                                  \n\t"
    "paddh      $f20, $f20, $f0                           \n\t"
    "paddh      $f22, $f22, $f2                           \n\t"

    "gsldlc1    $f0, 0x7(%[pSample1])                     \n\t"
    "gsldlc1    $f2, 0x7($8)                              \n\t"
    "gsldrc1    $f0, 0x0(%[pSample1])                     \n\t"
    "gsldrc1    $f2, 0x0($8)                              \n\t"
    "pasubub    $f12, $f12, $f0                           \n\t"
    "pasubub    $f14, $f14, $f2                           \n\t"
    "biadd      $f12, $f12                                \n\t"
    "biadd      $f14, $f14                                \n\t"
    "paddh      $f16, $f16, $f12                          \n\t"
    "paddh      $f18, $f18, $f14                          \n\t"

    "gsldlc1    $f4, 0x6(%[pSample2])                     \n\t"
    "gsldlc1    $f12, 0x8(%[pSample2])                    \n\t"
    PTR_ADDU   "$9, %[pSample2], %[iStride2]              \n\t"
    PTR_ADDU   "%[pSample1], $8, %[iStride1]              \n\t"
    "gsldrc1    $f4, -0x1(%[pSample2])                    \n\t"
    "gsldrc1    $f12, 0x1(%[pSample2])                    \n\t"

    "gsldlc1    $f6, 0x6($9)                              \n\t"
    "gsldlc1    $f14, 0x8($9)                             \n\t"
    "gsldrc1    $f6, -0x1($9)                             \n\t"
    "gsldrc1    $f14, 0x1($9)                             \n\t"

    "pasubub    $f4, $f4, $f0                             \n\t"
    "pasubub    $f6, $f6, $f2                             \n\t"
    "biadd      $f4, $f4                                  \n\t"
    "biadd      $f6, $f6                                  \n\t"
    "paddh      $f24, $f24, $f4                           \n\t"
    "paddh      $f26, $f26, $f6                           \n\t"
    "pasubub    $f12, $f12, $f0                           \n\t"
    "pasubub    $f14, $f14, $f2                           \n\t"
    PTR_ADDU   "%[pSample2], $9, %[iStride2]              \n\t"
    "biadd      $f12, $f12                                \n\t"
    "biadd      $f14, $f14                                \n\t"
    "paddh      $f28, $f28, $f12                          \n\t"
    "paddh      $f30, $f30, $f14                          \n\t"

    "gsldlc1    $f12, 0x7($9)                             \n\t"
    "gsldlc1    $f14, 0x7(%[pSample2])                    \n\t"
    "gsldrc1    $f12, 0x0($9)                             \n\t"
    "gsldrc1    $f14, 0x0(%[pSample2])                    \n\t"
    "pasubub    $f0, $f0, $f12                            \n\t"
    "pasubub    $f2, $f2, $f14                            \n\t"
    PTR_ADDU   "$8, %[pSample1], %[iStride1]              \n\t"
    "biadd      $f0, $f0                                  \n\t"
    "biadd      $f2, $f2                                  \n\t"
    "paddh      $f20, $f20, $f0                           \n\t"
    "paddh      $f22, $f22, $f2                           \n\t"

    "gsldlc1    $f0, 0x7(%[pSample1])                     \n\t"
    "gsldlc1    $f2, 0x7($8)                              \n\t"
    "gsldrc1    $f0, 0x0(%[pSample1])                     \n\t"
    "gsldrc1    $f2, 0x0($8)                              \n\t"
    "pasubub    $f12, $f12, $f0                           \n\t"
    "pasubub    $f14, $f14, $f2                           \n\t"
    "biadd      $f12, $f12                                \n\t"
    "biadd      $f14, $f14                                \n\t"
    "paddh      $f16, $f16, $f12                          \n\t"
    "paddh      $f18, $f18, $f14                          \n\t"

    "gsldlc1    $f4, 0x6(%[pSample2])                     \n\t"
    "gsldlc1    $f12, 0x8(%[pSample2])                    \n\t"
    PTR_ADDU   "$9, %[pSample2], %[iStride2]              \n\t"
    PTR_ADDU   "%[pSample1], $8, %[iStride1]              \n\t"
    "gsldrc1    $f4, -0x1(%[pSample2])                    \n\t"
    "gsldrc1    $f12, 0x1(%[pSample2])                    \n\t"

    "gsldlc1    $f6, 0x6($9)                              \n\t"
    "gsldlc1    $f14, 0x8($9)                             \n\t"
    "gsldrc1    $f6, -0x1($9)                             \n\t"
    "gsldrc1    $f14, 0x1($9)                             \n\t"

    "pasubub    $f4, $f4, $f0                             \n\t"
    "pasubub    $f6, $f6, $f2                             \n\t"
    "biadd      $f4, $f4                                  \n\t"
    "biadd      $f6, $f6                                  \n\t"
    "paddh      $f24, $f24, $f4                           \n\t"
    "paddh      $f26, $f26, $f6                           \n\t"
    "pasubub    $f12, $f12, $f0                           \n\t"
    "pasubub    $f14, $f14, $f2                           \n\t"
    PTR_ADDU   "%[pSample2], $9, %[iStride2]              \n\t"
    "biadd      $f12, $f12                                \n\t"
    "biadd      $f14, $f14                                \n\t"
    "paddh      $f28, $f28, $f12                          \n\t"
    "paddh      $f30, $f30, $f14                          \n\t"

    "gsldlc1    $f12, 0x7($9)                             \n\t"
    "gsldlc1    $f14, 0x7(%[pSample2])                    \n\t"
    "gsldrc1    $f12, 0x0($9)                             \n\t"
    "gsldrc1    $f14, 0x0(%[pSample2])                    \n\t"
    "pasubub    $f0, $f0, $f12                            \n\t"
    "pasubub    $f2, $f2, $f14                            \n\t"
    PTR_ADDU   "$8, %[pSample1], %[iStride1]              \n\t"
    "biadd      $f0, $f0                                  \n\t"
    "biadd      $f2, $f2                                  \n\t"
    "paddh      $f20, $f20, $f0                           \n\t"
    "paddh      $f22, $f22, $f2                           \n\t"

    "gsldlc1    $f0, 0x7(%[pSample1])                     \n\t"
    "gsldlc1    $f2, 0x7($8)                              \n\t"
    "gsldrc1    $f0, 0x0(%[pSample1])                     \n\t"
    "gsldrc1    $f2, 0x0($8)                              \n\t"
    "pasubub    $f12, $f12, $f0                           \n\t"
    "pasubub    $f14, $f14, $f2                           \n\t"
    "biadd      $f12, $f12                                \n\t"
    "biadd      $f14, $f14                                \n\t"
    "paddh      $f16, $f16, $f12                          \n\t"
    "paddh      $f18, $f18, $f14                          \n\t"

    "gsldlc1    $f4, 0x6(%[pSample2])                     \n\t"
    "gsldlc1    $f12, 0x8(%[pSample2])                    \n\t"
    PTR_ADDU   "$9, %[pSample2], %[iStride2]              \n\t"
    PTR_ADDU   "%[pSample1], $8, %[iStride1]              \n\t"
    "gsldrc1    $f4, -0x1(%[pSample2])                    \n\t"
    "gsldrc1    $f12, 0x1(%[pSample2])                    \n\t"

    "gsldlc1    $f6, 0x6($9)                              \n\t"
    "gsldlc1    $f14, 0x8($9)                             \n\t"
    "gsldrc1    $f6, -0x1($9)                             \n\t"
    "gsldrc1    $f14, 0x1($9)                             \n\t"

    "pasubub    $f4, $f4, $f0                             \n\t"
    "pasubub    $f6, $f6, $f2                             \n\t"
    "biadd      $f4, $f4                                  \n\t"
    "biadd      $f6, $f6                                  \n\t"
    "paddh      $f24, $f24, $f4                           \n\t"
    "paddh      $f26, $f26, $f6                           \n\t"
    "pasubub    $f12, $f12, $f0                           \n\t"
    "pasubub    $f14, $f14, $f2                           \n\t"
    PTR_ADDU   "%[pSample2], $9, %[iStride2]              \n\t"
    "biadd      $f12, $f12                                \n\t"
    "biadd      $f14, $f14                                \n\t"
    "paddh      $f28, $f28, $f12                          \n\t"
    "paddh      $f30, $f30, $f14                          \n\t"

    "gsldlc1    $f12, 0x7($9)                             \n\t"
    "gsldlc1    $f14, 0x7(%[pSample2])                    \n\t"
    "gsldrc1    $f12, 0x0($9)                             \n\t"
    "gsldrc1    $f14, 0x0(%[pSample2])                    \n\t"
    "pasubub    $f0, $f0, $f12                            \n\t"
    "pasubub    $f2, $f2, $f14                            \n\t"
    "biadd      $f0, $f0                                  \n\t"
    "biadd      $f2, $f2                                  \n\t"
    "paddh      $f20, $f20, $f0                           \n\t"
    "paddh      $f22, $f22, $f2                           \n\t"

    "paddh      $f16, $f16, $f18                          \n\t"
    "paddh      $f20, $f20, $f22                          \n\t"
    "paddh      $f24, $f24, $f26                          \n\t"
    "paddh      $f28, $f28, $f30                          \n\t"
    "punpcklwd  $f16, $f16, $f20                          \n\t"
    "punpcklwd  $f24, $f24, $f28                          \n\t"
    "gssqc1     $f24, $f16, 0x0(%[pSad])                  \n\t"
    : [pSample1]"+&r"((unsigned char *)pSample1),
      [pSample2]"+&r"((unsigned char *)pSample2)
    : [iStride1]"r"((int)iStride1), [iStride2]"r"((int)iStride2),
      [pSad]"r"((int *)pSad)
    : "memory", "$8", "$9", "$f0", "$f2", "$f4", "$f6", "$f8", "$f10", "$f12",
      "$f14", "$f16", "$f18", "$f20", "$f22", "$f24", "$f26", "$f28","$f30"
  );
  RECOVER_REG;
}
