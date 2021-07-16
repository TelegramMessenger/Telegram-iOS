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
 * \file    expand_picture_mmi.c
 *
 * \brief   Loongson optimization
 *
 * \date    24/07/2018 Created
 *
 *************************************************************************************
 */
#include <stdint.h>
#include "asmdefs_mmi.h"

#define mov_line_8x4_mmi_aligned(r0, r1, f0) \
  "gssdxc1    "#f0", 0x0("#r0", $0)           \n\t" \
  PTR_ADDU   ""#r0", "#r0", "#r1"             \n\t" \
  "gssdxc1    "#f0", 0x0("#r0", $0)           \n\t" \
  PTR_ADDU   ""#r0", "#r0", "#r1"             \n\t" \
  "gssdxc1    "#f0", 0x0("#r0", $0)           \n\t" \
  PTR_ADDU   ""#r0", "#r0", "#r1"             \n\t" \
  "gssdxc1    "#f0", 0x0("#r0", $0)           \n\t" \
  PTR_ADDU   ""#r0", "#r0", "#r1"             \n\t"

#define mov_line_8x4_mmi_unaligned(r0, r1, f0) \
  "gssdlc1    "#f0", 0x7("#r0")               \n\t" \
  "gssdrc1    "#f0", 0x0("#r0")               \n\t" \
  PTR_ADDU   ""#r0", "#r0", "#r1"             \n\t" \
  "gssdlc1    "#f0", 0x7("#r0")               \n\t" \
  "gssdrc1    "#f0", 0x0("#r0")               \n\t" \
  PTR_ADDU   ""#r0", "#r0", "#r1"             \n\t" \
  "gssdlc1    "#f0", 0x7("#r0")               \n\t" \
  "gssdrc1    "#f0", 0x0("#r0")               \n\t" \
  PTR_ADDU   ""#r0", "#r0", "#r1"             \n\t" \
  "gssdlc1    "#f0", 0x7("#r0")               \n\t" \
  "gssdrc1    "#f0", 0x0("#r0")               \n\t" \
  PTR_ADDU   ""#r0", "#r0", "#r1"             \n\t"

#define mov_line_end8x4_mmi_aligned(r0, r1, f0) \
  "gssdxc1    "#f0", 0x0("#r0", $0)           \n\t" \
  PTR_ADDU   ""#r0", "#r0", "#r1"             \n\t" \
  "gssdxc1    "#f0", 0x0("#r0", $0)           \n\t" \
  PTR_ADDU   ""#r0", "#r0", "#r1"             \n\t" \
  "gssdxc1    "#f0", 0x0("#r0", $0)           \n\t" \
  PTR_ADDU   ""#r0", "#r0", "#r1"             \n\t" \
  "gssdxc1    "#f0", 0x0("#r0", $0)           \n\t" \
  PTR_ADDU   ""#r0", "#r0", "#r1"             \n\t"

#define mov_line_end8x4_mmi_unaligned(r0, r1, f0) \
  "gssdlc1    "#f0", 0x7("#r0")               \n\t" \
  "gssdrc1    "#f0", 0x0("#r0")               \n\t" \
  PTR_ADDU   ""#r0", "#r0", "#r1"             \n\t" \
  "gssdlc1    "#f0", 0x7("#r0")               \n\t" \
  "gssdrc1    "#f0", 0x0("#r0")               \n\t" \
  PTR_ADDU   ""#r0", "#r0", "#r1"             \n\t" \
  "gssdlc1    "#f0", 0x7("#r0")               \n\t" \
  "gssdrc1    "#f0", 0x0("#r0")               \n\t" \
  PTR_ADDU   ""#r0", "#r0", "#r1"             \n\t" \
  "gssdlc1    "#f0", 0x7("#r0")               \n\t" \
  "gssdrc1    "#f0", 0x0("#r0")               \n\t" \

#define mov_line_16x4_mmi_aligned(r0, r1, f0, f2) \
  "gssqc1     "#f2", "#f0", 0x0("#r0")        \n\t" \
  PTR_ADDU   ""#r0", "#r0", "#r1"             \n\t" \
  "gssqc1     "#f2", "#f0", 0x0("#r0")        \n\t" \
  PTR_ADDU   ""#r0", "#r0", "#r1"             \n\t" \
  "gssqc1     "#f2", "#f0", 0x0("#r0")        \n\t" \
  PTR_ADDU   ""#r0", "#r0", "#r1"             \n\t" \
  "gssqc1     "#f2", "#f0", 0x0("#r0")        \n\t" \
  PTR_ADDU   ""#r0", "#r0", "#r1"             \n\t"

#define mov_line_16x4_mmi_unaligned(r0, r1, f0, f2) \
  "gssdlc1    "#f0", 0x7("#r0")               \n\t" \
  "gssdlc1    "#f2", 0xF("#r0")               \n\t" \
  "gssdrc1    "#f0", 0x0("#r0")               \n\t" \
  "gssdrc1    "#f2", 0x8("#r0")               \n\t" \
  PTR_ADDU   ""#r0", "#r0", "#r1"             \n\t" \
  "gssdlc1    "#f0", 0x7("#r0")               \n\t" \
  "gssdlc1    "#f2", 0xF("#r0")               \n\t" \
  "gssdrc1    "#f0", 0x0("#r0")               \n\t" \
  "gssdrc1    "#f2", 0x8("#r0")               \n\t" \
  PTR_ADDU   ""#r0", "#r0", "#r1"             \n\t" \
  "gssdlc1    "#f0", 0x7("#r0")               \n\t" \
  "gssdlc1    "#f2", 0xF("#r0")               \n\t" \
  "gssdrc1    "#f0", 0x0("#r0")               \n\t" \
  "gssdrc1    "#f2", 0x8("#r0")               \n\t" \
  PTR_ADDU   ""#r0", "#r0", "#r1"             \n\t" \
  "gssdlc1    "#f0", 0x7("#r0")               \n\t" \
  "gssdlc1    "#f2", 0xF("#r0")               \n\t" \
  "gssdrc1    "#f0", 0x0("#r0")               \n\t" \
  "gssdrc1    "#f2", 0x8("#r0")               \n\t" \
  PTR_ADDU   ""#r0", "#r0", "#r1"             \n\t"

#define mov_line_end16x4_mmi_aligned(r0, r1, f0, f2) \
  "gssqc1     "#f2", "#f0", 0x0("#r0")        \n\t" \
  PTR_ADDU   ""#r0", "#r0", "#r1"             \n\t" \
  "gssqc1     "#f2", "#f0", 0x0("#r0")        \n\t" \
  PTR_ADDU   ""#r0", "#r0", "#r1"             \n\t" \
  "gssqc1     "#f2", "#f0", 0x0("#r0")        \n\t" \
  PTR_ADDU   ""#r0", "#r0", "#r1"             \n\t" \
  "gssqc1     "#f2", "#f0", 0x0("#r0")        \n\t"

#define mov_line_end16x4_mmi_unaligned(r0, r1, f0, f2) \
  "gssdlc1    "#f0", 0x7("#r0")               \n\t" \
  "gssdlc1    "#f2", 0xF("#r0")               \n\t" \
  "gssdrc1    "#f0", 0x0("#r0")               \n\t" \
  "gssdrc1    "#f2", 0x8("#r0")               \n\t" \
  PTR_ADDU   ""#r0", "#r0", "#r1"             \n\t" \
  "gssdlc1    "#f0", 0x7("#r0")               \n\t" \
  "gssdlc1    "#f2", 0xF("#r0")               \n\t" \
  "gssdrc1    "#f0", 0x0("#r0")               \n\t" \
  "gssdrc1    "#f2", 0x8("#r0")               \n\t" \
  PTR_ADDU   ""#r0", "#r0", "#r1"             \n\t" \
  "gssdlc1    "#f0", 0x7("#r0")               \n\t" \
  "gssdlc1    "#f2", 0xF("#r0")               \n\t" \
  "gssdrc1    "#f0", 0x0("#r0")               \n\t" \
  "gssdrc1    "#f2", 0x8("#r0")               \n\t" \
  PTR_ADDU   ""#r0", "#r0", "#r1"             \n\t" \
  "gssdlc1    "#f0", 0x7("#r0")               \n\t" \
  "gssdlc1    "#f2", 0xF("#r0")               \n\t" \
  "gssdrc1    "#f0", 0x0("#r0")               \n\t" \
  "gssdrc1    "#f2", 0x8("#r0")               \n\t" \

#define exp_top_bottom_mmi_32 \
  "dsra       %[iWidth], %[iWidth], 0x4              \n\t" \
  "1:                                                \n\t" \
  "gslqc1     $f2, $f0, 0x0(%[pDst])                 \n\t" \
  mov_line_16x4_mmi_aligned($9, %[iStride], $f0, $f2)      \
  mov_line_16x4_mmi_aligned($9, %[iStride], $f0, $f2)      \
  mov_line_16x4_mmi_aligned($9, %[iStride], $f0, $f2)      \
  mov_line_16x4_mmi_aligned($9, %[iStride], $f0, $f2)      \
  mov_line_16x4_mmi_aligned($9, %[iStride], $f0, $f2)      \
  mov_line_16x4_mmi_aligned($9, %[iStride], $f0, $f2)      \
  mov_line_16x4_mmi_aligned($9, %[iStride], $f0, $f2)      \
  mov_line_end16x4_mmi_aligned($9, %[iStride], $f0, $f2)   \
  "gslqc1     $f6, $f4, 0x0(%[iHeight])              \n\t" \
  mov_line_16x4_mmi_aligned($11, %[iStride], $f4, $f6)     \
  mov_line_16x4_mmi_aligned($11, %[iStride], $f4, $f6)     \
  mov_line_16x4_mmi_aligned($11, %[iStride], $f4, $f6)     \
  mov_line_16x4_mmi_aligned($11, %[iStride], $f4, $f6)     \
  mov_line_16x4_mmi_aligned($11, %[iStride], $f4, $f6)     \
  mov_line_16x4_mmi_aligned($11, %[iStride], $f4, $f6)     \
  mov_line_16x4_mmi_aligned($11, %[iStride], $f4, $f6)     \
  mov_line_end16x4_mmi_aligned($11, %[iStride], $f4, $f6)  \
  PTR_ADDIU  "%[pDst], %[pDst], 0x10                 \n\t" \
  PTR_ADDIU  "$9, $9, 0x10                           \n\t" \
  PTR_ADDIU  "%[iHeight], %[iHeight], 0x10           \n\t" \
  PTR_ADDIU  "$11, $11, 0x10                         \n\t" \
  "dnegu      %[iStride], %[iStride]                 \n\t" \
  PTR_ADDIU  "%[iWidth], %[iWidth], -0x1             \n\t" \
  "bnez       %[iWidth], 1b                          \n\t" \
  "nop                                               \n\t"

#define exp_left_right_mmi_32 \
  "2:                                             \n\t" \
  "lbu        %[iWidth], 0x0(%[pDst])             \n\t" \
  MMI_Copy16Times($f0, $f2, $f28, %[iWidth])            \
  "gssqc1     $f2, $f0, 0x0($9)                   \n\t" \
  "gssqc1     $f2, $f0, 0x10($9)                  \n\t" \
  "lbu        %[iWidth], 0x0(%[iHeight])          \n\t" \
  MMI_Copy16Times($f4, $f6, $f28, %[iWidth])            \
  "gssqc1     $f6, $f4, 0x0($11)                  \n\t" \
  "gssqc1     $f6, $f4, 0x10($11)                 \n\t" \
  PTR_ADDU   "%[pDst], %[pDst], %[iStride]        \n\t" \
  PTR_ADDU   "$9, $9, %[iStride]                  \n\t" \
  PTR_ADDU   "%[iHeight], %[iHeight], %[iStride]  \n\t" \
  PTR_ADDU   "$11, $11, %[iStride]                \n\t" \
  PTR_ADDIU  "$8, $8, -0x1                        \n\t" \
  "bnez       $8, 2b                              \n\t" \
  "nop                                            \n\t"

#define mov_line_32x4_mmi(r0, r1, f0, f2) \
  "gssqc1     "#f2", "#f0", 0x0("#r0")         \n\t" \
  "gssqc1     "#f2", "#f0", 0x10("#r0")        \n\t" \
  PTR_ADDU   ""#r0", "#r0", "#r1"              \n\t" \
  "gssqc1     "#f2", "#f0", 0x0("#r0")         \n\t" \
  "gssqc1     "#f2", "#f0", 0x10("#r0")        \n\t" \
  PTR_ADDU   ""#r0", "#r0", "#r1"              \n\t" \
  "gssqc1     "#f2", "#f0", 0x0("#r0")         \n\t" \
  "gssqc1     "#f2", "#f0", 0x10("#r0")        \n\t" \
  PTR_ADDU   ""#r0", "#r0", "#r1"              \n\t" \
  "gssqc1     "#f2", "#f0", 0x0("#r0")         \n\t" \
  "gssqc1     "#f2", "#f0", 0x10("#r0")        \n\t" \
  PTR_ADDU   ""#r0", "#r0", "#r1"              \n\t"

#define mov_line_end32x4_mmi(r0, r1, f0, f2) \
  "gssqc1     "#f2", "#f0", 0x0("#r0")         \n\t" \
  "gssqc1     "#f2", "#f0", 0x10("#r0")        \n\t" \
  PTR_ADDU   ""#r0", "#r0", "#r1"              \n\t" \
  "gssqc1     "#f2", "#f0", 0x0("#r0")         \n\t" \
  "gssqc1     "#f2", "#f0", 0x10("#r0")        \n\t" \
  PTR_ADDU   ""#r0", "#r0", "#r1"              \n\t" \
  "gssqc1     "#f2", "#f0", 0x0("#r0")         \n\t" \
  "gssqc1     "#f2", "#f0", 0x10("#r0")        \n\t" \
  PTR_ADDU   ""#r0", "#r0", "#r1"              \n\t" \
  "gssqc1     "#f2", "#f0", 0x0("#r0")         \n\t" \
  "gssqc1     "#f2", "#f0", 0x10("#r0")        \n\t"

#define  exp_cross_mmi_32 \
  mov_line_32x4_mmi(%[iHeight], %[iStride], $f12, $f14)        \
  mov_line_32x4_mmi(%[iHeight], %[iStride], $f12, $f14)        \
  mov_line_32x4_mmi(%[iHeight], %[iStride], $f12, $f14)        \
  mov_line_32x4_mmi(%[iHeight], %[iStride], $f12, $f14)        \
  mov_line_32x4_mmi(%[iHeight], %[iStride], $f12, $f14)        \
  mov_line_32x4_mmi(%[iHeight], %[iStride], $f12, $f14)        \
  mov_line_32x4_mmi(%[iHeight], %[iStride], $f12, $f14)        \
  mov_line_end32x4_mmi(%[iHeight], %[iStride], $f12, $f14)     \
  mov_line_32x4_mmi($11, %[iStride], $f16, $f18)               \
  mov_line_32x4_mmi($11, %[iStride], $f16, $f18)               \
  mov_line_32x4_mmi($11, %[iStride], $f16, $f18)               \
  mov_line_32x4_mmi($11, %[iStride], $f16, $f18)               \
  mov_line_32x4_mmi($11, %[iStride], $f16, $f18)               \
  mov_line_32x4_mmi($11, %[iStride], $f16, $f18)               \
  mov_line_32x4_mmi($11, %[iStride], $f16, $f18)               \
  mov_line_end32x4_mmi($11, %[iStride], $f16, $f18)            \
  mov_line_32x4_mmi($9, %[iStride], $f20, $f22)                \
  mov_line_32x4_mmi($9, %[iStride], $f20, $f22)                \
  mov_line_32x4_mmi($9, %[iStride], $f20, $f22)                \
  mov_line_32x4_mmi($9, %[iStride], $f20, $f22)                \
  mov_line_32x4_mmi($9, %[iStride], $f20, $f22)                \
  mov_line_32x4_mmi($9, %[iStride], $f20, $f22)                \
  mov_line_32x4_mmi($9, %[iStride], $f20, $f22)                \
  mov_line_end32x4_mmi($9, %[iStride], $f20, $f22)             \
  mov_line_32x4_mmi($8, %[iStride], $f24, $f26)                \
  mov_line_32x4_mmi($8, %[iStride], $f24, $f26)                \
  mov_line_32x4_mmi($8, %[iStride], $f24, $f26)                \
  mov_line_32x4_mmi($8, %[iStride], $f24, $f26)                \
  mov_line_32x4_mmi($8, %[iStride], $f24, $f26)                \
  mov_line_32x4_mmi($8, %[iStride], $f24, $f26)                \
  mov_line_32x4_mmi($8, %[iStride], $f24, $f26)                \
  mov_line_end32x4_mmi($8, %[iStride], $f24, $f26)

#define exp_top_bottom_mmi_16_aligned \
  "move       $8, %[iWidth]                              \n\t" \
  "dsra       %[iWidth], %[iWidth], 0x4                  \n\t" \
  "1:                                                    \n\t" \
  "gslqc1     $f2, $f0, 0x0(%[pDst])                     \n\t" \
  mov_line_16x4_mmi_aligned($9, %[iStride], $f0, $f2)          \
  mov_line_16x4_mmi_aligned($9, %[iStride], $f0, $f2)          \
  mov_line_16x4_mmi_aligned($9, %[iStride], $f0, $f2)          \
  mov_line_end16x4_mmi_aligned($9, %[iStride], $f0, $f2)       \
  "gslqc1     $f6, $f4, 0x0(%[iHeight])                  \n\t" \
  mov_line_16x4_mmi_aligned($11, %[iStride], $f4, $f6)         \
  mov_line_16x4_mmi_aligned($11, %[iStride], $f4, $f6)         \
  mov_line_16x4_mmi_aligned($11, %[iStride], $f4, $f6)         \
  mov_line_end16x4_mmi_aligned($11, %[iStride], $f4, $f6)      \
  PTR_ADDIU  "%[pDst], %[pDst], 0x10                     \n\t" \
  PTR_ADDIU  "$9, $9, 0x10                               \n\t" \
  PTR_ADDIU  "%[iHeight], %[iHeight], 0x10               \n\t" \
  PTR_ADDIU  "$11, $11, 0x10                             \n\t" \
  "dnegu      %[iStride], %[iStride]                     \n\t" \
  PTR_ADDIU  "%[iWidth], %[iWidth], -0x1                 \n\t" \
  "bnez       %[iWidth], 1b                              \n\t" \
  "nop                                                   \n\t" \
  "and        $8, 0x0F                                   \n\t" \
  "beqz       $8, 2f                                     \n\t" \
  "nop                                                   \n\t" \
  "gsldxc1    $f0, 0x0(%[pDst], $0)                      \n\t" \
  mov_line_8x4_mmi_aligned($9, %[iStride], $f0)                \
  mov_line_8x4_mmi_aligned($9, %[iStride], $f0)                \
  mov_line_8x4_mmi_aligned($9, %[iStride], $f0)                \
  mov_line_end8x4_mmi_aligned($9, %[iStride], $f0)             \
  "gsldxc1    $f4, 0x0(%[iHeight], $0)                   \n\t" \
  mov_line_8x4_mmi_aligned($11, %[iStride], $f4)               \
  mov_line_8x4_mmi_aligned($11, %[iStride], $f4)               \
  mov_line_8x4_mmi_aligned($11, %[iStride], $f4)               \
  mov_line_end8x4_mmi_aligned($11, %[iStride], $f4)            \
  "2:                                                    \n\t"

#define exp_top_bottom_mmi_16_unaligned \
  "move       $8, %[iWidth]                              \n\t" \
  "dsra       %[iWidth], %[iWidth], 0x4                  \n\t" \
  "1:                                                    \n\t" \
  "gsldlc1    $f0, 0x7(%[pDst])                          \n\t" \
  "gsldlc1    $f2, 0xF(%[pDst])                          \n\t" \
  "gsldrc1    $f0, 0x0(%[pDst])                          \n\t" \
  "gsldrc1    $f2, 0x8(%[pDst])                          \n\t" \
  mov_line_16x4_mmi_unaligned($9, %[iStride], $f0, $f2)        \
  mov_line_16x4_mmi_unaligned($9, %[iStride], $f0, $f2)        \
  mov_line_16x4_mmi_unaligned($9, %[iStride], $f0, $f2)        \
  mov_line_end16x4_mmi_unaligned($9, %[iStride], $f0, $f2)     \
  "gsldlc1    $f4, 0x7(%[iHeight])                       \n\t" \
  "gsldlc1    $f6, 0xF(%[iHeight])                       \n\t" \
  "gsldrc1    $f4, 0x0(%[iHeight])                       \n\t" \
  "gsldrc1    $f6, 0x8(%[iHeight])                       \n\t" \
  mov_line_16x4_mmi_unaligned($11, %[iStride], $f4, $f6)       \
  mov_line_16x4_mmi_unaligned($11, %[iStride], $f4, $f6)       \
  mov_line_16x4_mmi_unaligned($11, %[iStride], $f4, $f6)       \
  mov_line_end16x4_mmi_unaligned($11, %[iStride], $f4, $f6)    \
  PTR_ADDIU  "%[pDst], %[pDst], 0x10                     \n\t" \
  PTR_ADDIU  "$9, $9, 0x10                               \n\t" \
  PTR_ADDIU  "%[iHeight], %[iHeight], 0x10               \n\t" \
  PTR_ADDIU  "$11, $11, 0x10                             \n\t" \
  "dnegu      %[iStride], %[iStride]                     \n\t" \
  PTR_ADDIU  "%[iWidth], %[iWidth], -0x1                 \n\t" \
  "bnez       %[iWidth], 1b                              \n\t" \
  "nop                                                   \n\t" \
  "and        $8, 0x0F                                   \n\t" \
  "beqz       $8, 2f                                     \n\t" \
  "nop                                                   \n\t" \
  "gsldlc1    $f0, 0x7(%[pDst])                          \n\t" \
  "gsldrc1    $f0, 0x0(%[pDst])                          \n\t" \
  mov_line_8x4_mmi_unaligned($9, %[iStride], $f0)              \
  mov_line_8x4_mmi_unaligned($9, %[iStride], $f0)              \
  mov_line_8x4_mmi_unaligned($9, %[iStride], $f0)              \
  mov_line_end8x4_mmi_unaligned($9, %[iStride], $f0)           \
  "gsldlc1    $f4, 0x7(%[iHeight])                       \n\t" \
  "gsldrc1    $f4, 0x0(%[iHeight])                       \n\t" \
  mov_line_8x4_mmi_unaligned($11, %[iStride], $f4)             \
  mov_line_8x4_mmi_unaligned($11, %[iStride], $f4)             \
  mov_line_8x4_mmi_unaligned($11, %[iStride], $f4)             \
  mov_line_end8x4_mmi_unaligned($11, %[iStride], $f4)          \
  "2:                                                    \n\t"

#define exp_left_right_mmi_16_aligned \
  "3:                                             \n\t" \
  "lbu        %[iWidth], 0x0(%[pDst])             \n\t" \
  MMI_Copy16Times($f0, $f2, $f28, %[iWidth])            \
  "gssqc1     $f2, $f0, 0x0($9)                   \n\t" \
  "lbu        %[iWidth], 0x0(%[iHeight])          \n\t" \
  MMI_Copy16Times($f4, $f6, $f28, %[iWidth])            \
  "gssqc1     $f6, $f4, 0x0($11)                  \n\t" \
  PTR_ADDU   "%[pDst], %[pDst], %[iStride]        \n\t" \
  PTR_ADDU   "$9, $9, %[iStride]                  \n\t" \
  PTR_ADDU   "%[iHeight], %[iHeight], %[iStride]  \n\t" \
  PTR_ADDU   "$11, $11, %[iStride]                \n\t" \
  PTR_ADDIU  "$8, $8, -0x1                        \n\t" \
  "bnez       $8, 3b                              \n\t" \
  "nop                                            \n\t"

#define exp_left_right_mmi_16_unaligned \
  "3:                                             \n\t" \
  "lbu        %[iWidth], 0x0(%[pDst])             \n\t" \
  MMI_Copy16Times($f0, $f2, $f28, %[iWidth])            \
  "gssdlc1    $f0, 0x7($9)                        \n\t" \
  "gssdlc1    $f2, 0xF($9)                        \n\t" \
  "gssdrc1    $f0, 0x0($9)                        \n\t" \
  "gssdrc1    $f2, 0x8($9)                        \n\t" \
  "lbu        %[iWidth], 0x0(%[iHeight])          \n\t" \
  MMI_Copy16Times($f4, $f6, $f28, %[iWidth])            \
  "gssdlc1    $f4, 0x7($11)                       \n\t" \
  "gssdlc1    $f6, 0xF($11)                       \n\t" \
  "gssdrc1    $f4, 0x0($11)                       \n\t" \
  "gssdrc1    $f6, 0x8($11)                       \n\t" \
  PTR_ADDU   "%[pDst], %[pDst], %[iStride]        \n\t" \
  PTR_ADDU   "$9, $9, %[iStride]                  \n\t" \
  PTR_ADDU   "%[iHeight], %[iHeight], %[iStride]  \n\t" \
  PTR_ADDU   "$11, $11, %[iStride]                \n\t" \
  PTR_ADDIU  "$8, $8, -0x1                        \n\t" \
  "bnez       $8, 3b                              \n\t" \
  "nop                                            \n\t"

#define exp_cross_mmi_16_aligned \
  mov_line_16x4_mmi_aligned(%[iHeight], %[iStride], $f12, $f14)        \
  mov_line_16x4_mmi_aligned(%[iHeight], %[iStride], $f12, $f14)        \
  mov_line_16x4_mmi_aligned(%[iHeight], %[iStride], $f12, $f14)        \
  mov_line_end16x4_mmi_aligned(%[iHeight], %[iStride], $f12, $f14)     \
  mov_line_16x4_mmi_aligned($11, %[iStride], $f16, $f18)               \
  mov_line_16x4_mmi_aligned($11, %[iStride], $f16, $f18)               \
  mov_line_16x4_mmi_aligned($11, %[iStride], $f16, $f18)               \
  mov_line_end16x4_mmi_aligned($11, %[iStride], $f16, $f18)            \
  mov_line_16x4_mmi_aligned($9, %[iStride], $f20, $f22)                \
  mov_line_16x4_mmi_aligned($9, %[iStride], $f20, $f22)                \
  mov_line_16x4_mmi_aligned($9, %[iStride], $f20, $f22)                \
  mov_line_end16x4_mmi_aligned($9, %[iStride], $f20, $f22)             \
  mov_line_16x4_mmi_aligned($8, %[iStride], $f24, $f26)                \
  mov_line_16x4_mmi_aligned($8, %[iStride], $f24, $f26)                \
  mov_line_16x4_mmi_aligned($8, %[iStride], $f24, $f26)                \
  mov_line_end16x4_mmi_aligned($8, %[iStride], $f24, $f26)

#define exp_cross_mmi_16_unaligned \
  mov_line_16x4_mmi_unaligned(%[iHeight], %[iStride], $f12, $f14)      \
  mov_line_16x4_mmi_unaligned(%[iHeight], %[iStride], $f12, $f14)      \
  mov_line_16x4_mmi_unaligned(%[iHeight], %[iStride], $f12, $f14)      \
  mov_line_end16x4_mmi_unaligned(%[iHeight], %[iStride], $f12, $f14)   \
  mov_line_16x4_mmi_unaligned($11, %[iStride], $f16, $f18)             \
  mov_line_16x4_mmi_unaligned($11, %[iStride], $f16, $f18)             \
  mov_line_16x4_mmi_unaligned($11, %[iStride], $f16, $f18)             \
  mov_line_end16x4_mmi_unaligned($11, %[iStride], $f16, $f18)          \
  mov_line_16x4_mmi_unaligned($9, %[iStride], $f20, $f22)              \
  mov_line_16x4_mmi_unaligned($9, %[iStride], $f20, $f22)              \
  mov_line_16x4_mmi_unaligned($9, %[iStride], $f20, $f22)              \
  mov_line_end16x4_mmi_unaligned($9, %[iStride], $f20, $f22)           \
  mov_line_16x4_mmi_unaligned($8, %[iStride], $f24, $f26)              \
  mov_line_16x4_mmi_unaligned($8, %[iStride], $f24, $f26)              \
  mov_line_16x4_mmi_unaligned($8, %[iStride], $f24, $f26)              \
  mov_line_end16x4_mmi_unaligned($8, %[iStride], $f24, $f26)

void ExpandPictureLuma_mmi(uint8_t *pDst, int32_t iStride, int32_t iWidth,
                           int32_t iHeight) {
  BACKUP_REG;
  __asm__ volatile (
    ".set       arch=loongson3a                     \n\t"
    "xor        $f28, $f28, $f28                    \n\t"
    "lbu        $8, 0x0(%[pDst])                    \n\t"

    MMI_Copy16Times($f12, $f14, $f28, $8)

    "dnegu      %[iStride], %[iStride]              \n\t"
    PTR_ADDU   "$9, %[pDst], %[iStride]             \n\t"
    "dnegu      %[iStride], %[iStride]              \n\t"
    "move       $10, %[iHeight]                     \n\t"
    PTR_ADDU   "%[iHeight], %[iHeight], -0x1        \n\t"
    "dmul       %[iHeight], %[iHeight], %[iStride]  \n\t"
    PTR_ADDU   "%[iHeight], %[iHeight], %[pDst]     \n\t"

    "move       $8, %[iStride]                      \n\t"
    "dsll       $8, 0x5                             \n\t"
    PTR_ADDU   "$11, %[iHeight], $8                 \n\t"

    "lbu        $8, 0x0(%[iHeight])                 \n\t"
    MMI_Copy16Times($f20, $f22, $f28, $8)
    PTR_ADDU   "$8, %[iHeight], %[iWidth]           \n\t"
    PTR_ADDIU  "$8, -0x1                            \n\t"
    "lbu        $8, 0x0($8)                         \n\t"
    "dmtc1      $8, $f24                            \n\t"
    "pshufh     $f24, $f24, $f28                    \n\t"
    "packushb   $f24, $f24, $f24                    \n\t"
    "mov.d      $f26, $f24                          \n\t"
    "dnegu      %[iStride], %[iStride]              \n\t"
    "move       $12, %[pDst]                        \n\t"
    "move       $13, %[iStride]                     \n\t"
    "move       $14, %[iWidth]                      \n\t"
    exp_top_bottom_mmi_32
    "move       %[iWidth], $14                      \n\t"
    "move       %[iStride], $13                     \n\t"
    "move       %[pDst], $12                        \n\t"
    PTR_ADDIU  "$9, %[pDst], -0x20                  \n\t"
    PTR_ADDU   "%[iHeight], %[pDst], %[iWidth]      \n\t"
    PTR_ADDIU  "%[iHeight], %[iHeight], -0x1        \n\t"
    PTR_ADDIU  "$11, %[iHeight], 0x1                \n\t"
    "lbu        $8, 0x0(%[iHeight])                 \n\t"
    MMI_Copy16Times($f16, $f18, $f28, $8)
    "dnegu      %[iStride], %[iStride]              \n\t"
    "move       $8, $10                             \n\t"
    "move       $10, %[pDst]                        \n\t"
    "move       $12, %[iStride]                     \n\t"
    "move       $13, %[iWidth]                      \n\t"
    "move       $14, $8                             \n\t"

    exp_left_right_mmi_32

    "move       $8, $14                             \n\t"
    "move       %[iWidth], $13                      \n\t"
    "move       %[iStride], $12                     \n\t"
    "move       %[pDst], $10                        \n\t"
    "dnegu      %[iStride], %[iStride]              \n\t"
    PTR_ADDIU  "%[iHeight], %[pDst], -0x20          \n\t"
    PTR_ADDU   "%[iHeight], %[iHeight], %[iStride]  \n\t"
    PTR_ADDU   "$11, %[pDst], %[iWidth]             \n\t"
    PTR_ADDU   "$11, $11, %[iStride]                \n\t"
    "dnegu      %[iStride], %[iStride]              \n\t"
    PTR_ADDIU  "$8, $8, 0x20                        \n\t"
    "dmul       $8, $8, %[iStride]                  \n\t"
    PTR_ADDU   "$9, %[iHeight], $8                  \n\t"
    PTR_ADDU   "$8, $11, $8                         \n\t"
    "dnegu      %[iStride], %[iStride]              \n\t"
    exp_cross_mmi_32
    : [pDst]"+&r"((unsigned char *)pDst), [iStride]"+&r"((int)iStride),
      [iWidth]"+&r"((int)iWidth), [iHeight]"+&r"((int)iHeight)
    :
    : "memory", "$8", "$9", "$10", "$11", "$12", "$13", "$14", "$f0", "$f2",
      "$f4", "$f6", "$f8", "$f10", "$f12", "$f14", "$f16", "$f18", "$f20",
      "$f22", "$f24", "$f26", "$f28"
  );
  RECOVER_REG;
}

void ExpandPictureChromaUnalign_mmi(uint8_t *pDst, int32_t iStride, int32_t iWidth,
                                    int32_t iHeight) {
  BACKUP_REG;
  __asm__ volatile (
    ".set       arch=loongson3a                     \n\t"
    "xor        $f28, $f28, $f28                    \n\t"
    "lbu        $8, 0x0(%[pDst])                    \n\t"

    MMI_Copy16Times($f12, $f14, $f28, $8)

    "dnegu      %[iStride], %[iStride]              \n\t"
    PTR_ADDU   "$9, %[pDst], %[iStride]             \n\t"
    "dnegu      %[iStride], %[iStride]              \n\t"
    "move       $10, %[iHeight]                     \n\t"
    PTR_ADDU   "%[iHeight], %[iHeight], -0x1        \n\t"
    "dmul       %[iHeight], %[iHeight], %[iStride]  \n\t"
    PTR_ADDU   "%[iHeight], %[iHeight], %[pDst]     \n\t"
    "move       $8, %[iStride]                      \n\t"
    "dsll       $8, 0x4                             \n\t"
    PTR_ADDU   "$11, %[iHeight], $8                 \n\t"
    "lbu        $8, 0x0(%[iHeight])                 \n\t"

    MMI_Copy16Times($f20, $f22, $f28, $8)

    PTR_ADDU   "$8, %[iHeight], %[iWidth]           \n\t"
    PTR_ADDIU  "$8, -0x1                            \n\t"
    "lbu        $8, 0x0($8)                         \n\t"

    MMI_Copy16Times($f24, $f26, $f28, $8)

    "dnegu      %[iStride], %[iStride]              \n\t"
    "move       $12, %[pDst]                        \n\t"
    "move       $13, %[iStride]                     \n\t"
    "move       $14, %[iWidth]                      \n\t"

    exp_top_bottom_mmi_16_unaligned

    "move       %[iWidth], $14                      \n\t"
    "move       %[iStride], $13                     \n\t"
    "move       %[pDst], $12                        \n\t"
    PTR_ADDIU  "$9, %[pDst], -0x10                  \n\t"
    PTR_ADDU   "%[iHeight], %[pDst], %[iWidth]      \n\t"
    PTR_ADDIU  "%[iHeight], %[iHeight], -0x1        \n\t"
    PTR_ADDIU  "$11, %[iHeight], 0x1                \n\t"
    "lbu        $8, 0x0(%[iHeight])                 \n\t"
    MMI_Copy16Times($f16, $f18, $f28, $8)

    "dnegu      %[iStride], %[iStride]              \n\t"
    "move       $8, $10                             \n\t"

    "move       $10, %[pDst]                        \n\t"
    "move       $12, %[iStride]                     \n\t"
    "move       $13, %[iWidth]                      \n\t"
    "move       $14, $8                             \n\t"

    exp_left_right_mmi_16_unaligned

    "move       $8, $14                             \n\t"
    "move       %[iWidth], $13                      \n\t"
    "move       %[iStride], $12                     \n\t"
    "move       %[pDst], $10                        \n\t"

    "dnegu      %[iStride], %[iStride]              \n\t"
    PTR_ADDIU  "%[iHeight], %[pDst], -0x10          \n\t"
    PTR_ADDU   "%[iHeight], %[iHeight], %[iStride]  \n\t"
    PTR_ADDU   "$11, %[pDst], %[iWidth]             \n\t"
    PTR_ADDU   "$11, $11, %[iStride]                \n\t"

    "dnegu      %[iStride], %[iStride]              \n\t"
    PTR_ADDIU  "$8, $8, 0x10                        \n\t"
    "dmul       $8, $8, %[iStride]                  \n\t"

    PTR_ADDU   "$9, %[iHeight], $8                  \n\t"
    PTR_ADDU   "$8, $11, $8                         \n\t"
    "dnegu      %[iStride], %[iStride]              \n\t"

    exp_cross_mmi_16_unaligned
    : [pDst]"+&r"((unsigned char *)pDst), [iStride]"+&r"((int)iStride),
      [iWidth]"+&r"((int)iWidth), [iHeight]"+&r"((int)iHeight)
    :
    : "memory", "$8", "$9", "$10", "$11", "$12", "$13", "$14", "$f0", "$f2",
      "$f4", "$f6", "$f8", "$f10", "$f12", "$f14", "$f16", "$f18", "$f20",
      "$f22", "$f24", "$f26", "$f28"
  );
  RECOVER_REG;
}

void ExpandPictureChromaAlign_mmi(uint8_t *pDst, int32_t iStride, int32_t iWidth,
                                  int32_t iHeight) {
  BACKUP_REG;
  __asm__ volatile (
    ".set       arch=loongson3a                     \n\t"
    "xor        $f28, $f28, $f28                    \n\t"
    "lbu        $8, 0x0(%[pDst])                    \n\t"

    MMI_Copy16Times($f12, $f14, $f28, $8)

    "dnegu      %[iStride], %[iStride]              \n\t"
    PTR_ADDU   "$9, %[pDst], %[iStride]             \n\t"
    "dnegu      %[iStride], %[iStride]              \n\t"
    "move       $10, %[iHeight]                     \n\t"
    PTR_ADDU   "%[iHeight], %[iHeight], -0x1        \n\t"
    "dmul       %[iHeight], %[iHeight], %[iStride]  \n\t"
    PTR_ADDU   "%[iHeight], %[iHeight], %[pDst]     \n\t"
    "move       $8, %[iStride]                      \n\t"
    "dsll       $8, 0x4                             \n\t"
    PTR_ADDU   "$11, %[iHeight], $8                 \n\t"
    "lbu        $8, 0x0(%[iHeight])                 \n\t"

    MMI_Copy16Times($f20, $f22, $f28, $8)

    PTR_ADDU   "$8, %[iHeight], %[iWidth]           \n\t"
    PTR_ADDIU  "$8, -0x1                            \n\t"
    "lbu        $8, 0x0($8)                         \n\t"

    MMI_Copy16Times($f24, $f26, $f28, $8)

    "dnegu      %[iStride], %[iStride]              \n\t"

    "move       $12, %[pDst]                        \n\t"
    "move       $13, %[iStride]                     \n\t"
    "move       $14, %[iWidth]                      \n\t"
    exp_top_bottom_mmi_16_aligned

    "move       %[iWidth], $14                      \n\t"
    "move       %[iStride], $13                     \n\t"
    "move       %[pDst], $12                        \n\t"

    PTR_ADDIU  "$9, %[pDst], -0x10                  \n\t"

    PTR_ADDU   "%[iHeight], %[pDst], %[iWidth]      \n\t"
    PTR_ADDIU  "%[iHeight], %[iHeight], -0x1        \n\t"
    PTR_ADDIU  "$11, %[iHeight], 0x1                \n\t"

    "lbu        $8, 0x0(%[iHeight])                 \n\t"

    MMI_Copy16Times($f16, $f18, $f28, $8)

    "dnegu      %[iStride], %[iStride]              \n\t"
    "move       $8, $10                             \n\t"

    "move       $10, %[pDst]                        \n\t"
    "move       $12, %[iStride]                     \n\t"
    "move       $13, %[iWidth]                      \n\t"
    "move       $14, $8                             \n\t"

    exp_left_right_mmi_16_aligned

    "move       $8, $14                             \n\t"
    "move       %[iWidth], $13                      \n\t"
    "move       %[iStride], $12                     \n\t"
    "move       %[pDst], $10                        \n\t"

    "dnegu      %[iStride], %[iStride]              \n\t"
    PTR_ADDIU  "%[iHeight], %[pDst], -0x10          \n\t"
    PTR_ADDU   "%[iHeight], %[iHeight], %[iStride]  \n\t"
    PTR_ADDU   "$11, %[pDst], %[iWidth]             \n\t"
    PTR_ADDU   "$11, $11, %[iStride]                \n\t"

    "dnegu      %[iStride], %[iStride]              \n\t"
    PTR_ADDIU  "$8, $8, 0x10                        \n\t"
    "dmul       $8, $8, %[iStride]                  \n\t"

    PTR_ADDU   "$9, %[iHeight], $8                  \n\t"
    PTR_ADDU   "$8, $11, $8                         \n\t"
    "dnegu      %[iStride], %[iStride]              \n\t"

    exp_cross_mmi_16_aligned
    : [pDst]"+&r"((unsigned char *)pDst), [iStride]"+&r"((int)iStride),
      [iWidth]"+&r"((int)iWidth), [iHeight]"+&r"((int)iHeight)
    :
    : "memory", "$8", "$9", "$10", "$11", "$12", "$13", "$14", "$f0", "$f2",
      "$f4", "$f6", "$f8", "$f10", "$f12", "$f14", "$f16", "$f18", "$f20",
      "$f22", "$f24", "$f26", "$f28"
  );
  RECOVER_REG;
}
