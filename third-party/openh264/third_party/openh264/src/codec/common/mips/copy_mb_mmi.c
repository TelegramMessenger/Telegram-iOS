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
 * \file    copy_mb_mmi.c
 *
 * \brief   Loongson optimization
 *
 * \date    20/07/2018 Created
 *
 *************************************************************************************
 */
#include <stdint.h>
#include "asmdefs_mmi.h"

void WelsCopy8x8_mmi(uint8_t* pDst, int32_t iStrideD, uint8_t* pSrc,
                     int32_t  iStrideS ) {
  __asm__ volatile (
    ".set       arch=loongson3a                 \n\t"
    PTR_ADDU   "$8, %[pSrc], %[iStrideS]        \n\t"
    "gsldlc1    $f0, 0x7(%[pSrc])               \n\t"
    "gsldlc1    $f2, 0x7($8)                    \n\t"
    "gsldrc1    $f0, 0x0(%[pSrc])               \n\t"
    "gsldrc1    $f2, 0x0($8)                    \n\t"
    PTR_ADDU   "%[pSrc], $8, %[iStrideS]        \n\t"
    PTR_ADDU   "$8, %[pSrc], %[iStrideS]        \n\t"
    "gsldlc1    $f4, 0x7(%[pSrc])               \n\t"
    "gsldlc1    $f6, 0x7($8)                    \n\t"
    "gsldrc1    $f4, 0x0(%[pSrc])               \n\t"
    "gsldrc1    $f6, 0x0($8)                    \n\t"
    PTR_ADDU   "%[pSrc], $8, %[iStrideS]        \n\t"
    PTR_ADDU   "$8, %[pSrc], %[iStrideS]        \n\t"
    "gsldlc1    $f8, 0x7(%[pSrc])               \n\t"
    "gsldlc1    $f10, 0x7($8)                   \n\t"
    "gsldrc1    $f8, 0x0(%[pSrc])               \n\t"
    "gsldrc1    $f10, 0x0($8)                   \n\t"
    PTR_ADDU   "%[pSrc], $8, %[iStrideS]        \n\t"
    PTR_ADDU   "$8, %[pSrc], %[iStrideS]        \n\t"
    "gsldlc1    $f12, 0x7(%[pSrc])              \n\t"
    "gsldlc1    $f14, 0x7($8)                   \n\t"
    "gsldrc1    $f12, 0x0(%[pSrc])              \n\t"
    "gsldrc1    $f14, 0x0($8)                   \n\t"

    PTR_ADDU   "$8, %[pDst], %[iStrideD]        \n\t"
    "gssdlc1    $f0, 0x7(%[pDst])               \n\t"
    "gssdlc1    $f2, 0x7($8)                    \n\t"
    "gssdrc1    $f0, 0x0(%[pDst])               \n\t"
    "gssdrc1    $f2, 0x0($8)                    \n\t"
    PTR_ADDU   "%[pDst], $8, %[iStrideD]        \n\t"
    PTR_ADDU   "$8, %[pDst], %[iStrideD]        \n\t"
    "gssdlc1    $f4, 0x7(%[pDst])               \n\t"
    "gssdlc1    $f6, 0x7($8)                    \n\t"
    "gssdrc1    $f4, 0x0(%[pDst])               \n\t"
    "gssdrc1    $f6, 0x0($8)                    \n\t"
    PTR_ADDU   "%[pDst], $8, %[iStrideD]        \n\t"
    PTR_ADDU   "$8, %[pDst], %[iStrideD]        \n\t"
    "gssdlc1    $f8, 0x7(%[pDst])               \n\t"
    "gssdlc1    $f10, 0x7($8)                   \n\t"
    "gssdrc1    $f8, 0x0(%[pDst])               \n\t"
    "gssdrc1    $f10, 0x0($8)                   \n\t"
    PTR_ADDU   "%[pDst], $8, %[iStrideD]        \n\t"
    PTR_ADDU   "$8, %[pDst], %[iStrideD]        \n\t"
    "gssdlc1    $f12, 0x7(%[pDst])              \n\t"
    "gssdlc1    $f14, 0x7($8)                   \n\t"
    "gssdrc1    $f12, 0x0(%[pDst])              \n\t"
    "gssdrc1    $f14, 0x0($8)                   \n\t"
   : [pDst]"+&r"((unsigned char *)pDst), [pSrc]"+&r"((unsigned char *)pSrc)
   : [iStrideD]"r"(iStrideD), [iStrideS]"r"(iStrideS)
   : "memory", "$8", "$f0", "$f2", "$f4", "$f6", "$f8", "$f10", "$f12", "$f14"
  );
}

void WelsCopy8x16_mmi(uint8_t* pDst, int32_t iStrideD, uint8_t* pSrc,
                      int32_t iStrideS) {
  __asm__ volatile (
    ".set       arch=loongson3a                 \n\t"
    PTR_ADDU   "$8, %[pSrc], %[iStrideS]        \n\t"
    "gsldlc1    $f0, 0x7(%[pSrc])               \n\t"
    "gsldlc1    $f2, 0x7($8)                    \n\t"
    "gsldrc1    $f0, 0x0(%[pSrc])               \n\t"
    "gsldrc1    $f2, 0x0($8)                    \n\t"
    PTR_ADDU   "%[pSrc], $8, %[iStrideS]        \n\t"
    PTR_ADDU   "$8, %[pSrc], %[iStrideS]        \n\t"
    "gsldlc1    $f4, 0x7(%[pSrc])               \n\t"
    "gsldlc1    $f6, 0x7($8)                    \n\t"
    "gsldrc1    $f4, 0x0(%[pSrc])               \n\t"
    "gsldrc1    $f6, 0x0($8)                    \n\t"
    PTR_ADDU   "%[pSrc], $8, %[iStrideS]        \n\t"
    PTR_ADDU   "$8, %[pSrc], %[iStrideS]        \n\t"
    "gsldlc1    $f8, 0x7(%[pSrc])               \n\t"
    "gsldlc1    $f10, 0x7($8)                   \n\t"
    "gsldrc1    $f8, 0x0(%[pSrc])               \n\t"
    "gsldrc1    $f10, 0x0($8)                   \n\t"
    PTR_ADDU   "%[pSrc], $8, %[iStrideS]        \n\t"
    PTR_ADDU   "$8, %[pSrc], %[iStrideS]        \n\t"
    "gsldlc1    $f12, 0x7(%[pSrc])              \n\t"
    "gsldlc1    $f14, 0x7($8)                   \n\t"
    "gsldrc1    $f12, 0x0(%[pSrc])              \n\t"
    "gsldrc1    $f14, 0x0($8)                   \n\t"
    PTR_ADDU   "%[pSrc], $8, %[iStrideS]        \n\t"

    PTR_ADDU   "$8, %[pDst], %[iStrideD]        \n\t"
    "gssdlc1    $f0, 0x7(%[pDst])               \n\t"
    "gssdlc1    $f2, 0x7($8)                    \n\t"
    "gssdrc1    $f0, 0x0(%[pDst])               \n\t"
    "gssdrc1    $f2, 0x0($8)                    \n\t"
    PTR_ADDU   "%[pDst], $8, %[iStrideD]        \n\t"
    PTR_ADDU   "$8, %[pDst], %[iStrideD]        \n\t"
    "gssdlc1    $f4, 0x7(%[pDst])               \n\t"
    "gssdlc1    $f6, 0x7($8)                    \n\t"
    "gssdrc1    $f4, 0x0(%[pDst])               \n\t"
    "gssdrc1    $f6, 0x0($8)                    \n\t"
    PTR_ADDU   "%[pDst], $8, %[iStrideD]        \n\t"
    PTR_ADDU   "$8, %[pDst], %[iStrideD]        \n\t"
    "gssdlc1    $f8, 0x7(%[pDst])               \n\t"
    "gssdlc1    $f10, 0x7($8)                   \n\t"
    "gssdrc1    $f8, 0x0(%[pDst])               \n\t"
    "gssdrc1    $f10, 0x0($8)                   \n\t"
    PTR_ADDU   "%[pDst], $8, %[iStrideD]        \n\t"
    PTR_ADDU   "$8, %[pDst], %[iStrideD]        \n\t"
    "gssdlc1    $f12, 0x7(%[pDst])              \n\t"
    "gssdlc1    $f14, 0x7($8)                   \n\t"
    "gssdrc1    $f12, 0x0(%[pDst])              \n\t"
    "gssdrc1    $f14, 0x0($8)                   \n\t"
    PTR_ADDU   "%[pDst], $8, %[iStrideD]        \n\t"

    PTR_ADDU   "$8, %[pSrc], %[iStrideS]        \n\t"
    "gsldlc1    $f0, 0x7(%[pSrc])               \n\t"
    "gsldlc1    $f2, 0x7($8)                    \n\t"
    "gsldrc1    $f0, 0x0(%[pSrc])               \n\t"
    "gsldrc1    $f2, 0x0($8)                    \n\t"
    PTR_ADDU   "%[pSrc], $8, %[iStrideS]        \n\t"
    PTR_ADDU   "$8, %[pSrc], %[iStrideS]        \n\t"
    "gsldlc1    $f4, 0x7(%[pSrc])               \n\t"
    "gsldlc1    $f6, 0x7($8)                    \n\t"
    "gsldrc1    $f4, 0x0(%[pSrc])               \n\t"
    "gsldrc1    $f6, 0x0($8)                    \n\t"
    PTR_ADDU   "%[pSrc], $8, %[iStrideS]        \n\t"
    PTR_ADDU   "$8, %[pSrc], %[iStrideS]        \n\t"
    "gsldlc1    $f8, 0x7(%[pSrc])               \n\t"
    "gsldlc1    $f10, 0x7($8)                   \n\t"
    "gsldrc1    $f8, 0x0(%[pSrc])               \n\t"
    "gsldrc1    $f10, 0x0($8)                   \n\t"
    PTR_ADDU   "%[pSrc], $8, %[iStrideS]        \n\t"
    PTR_ADDU   "$8, %[pSrc], %[iStrideS]        \n\t"
    "gsldlc1    $f12, 0x7(%[pSrc])              \n\t"
    "gsldlc1    $f14, 0x7($8)                   \n\t"
    "gsldrc1    $f12, 0x0(%[pSrc])              \n\t"
    "gsldrc1    $f14, 0x0($8)                   \n\t"

    PTR_ADDU   "$8, %[pDst], %[iStrideD]        \n\t"
    "gssdlc1    $f0, 0x7(%[pDst])               \n\t"
    "gssdlc1    $f2, 0x7($8)                    \n\t"
    "gssdrc1    $f0, 0x0(%[pDst])               \n\t"
    "gssdrc1    $f2, 0x0($8)                    \n\t"
    PTR_ADDU   "%[pDst], $8, %[iStrideD]        \n\t"
    PTR_ADDU   "$8, %[pDst], %[iStrideD]        \n\t"
    "gssdlc1    $f4, 0x7(%[pDst])               \n\t"
    "gssdlc1    $f6, 0x7($8)                    \n\t"
    "gssdrc1    $f4, 0x0(%[pDst])               \n\t"
    "gssdrc1    $f6, 0x0($8)                    \n\t"
    PTR_ADDU   "%[pDst], $8, %[iStrideD]        \n\t"
    PTR_ADDU   "$8, %[pDst], %[iStrideD]        \n\t"
    "gssdlc1    $f8, 0x7(%[pDst])               \n\t"
    "gssdlc1    $f10, 0x7($8)                   \n\t"
    "gssdrc1    $f8, 0x0(%[pDst])               \n\t"
    "gssdrc1    $f10, 0x0($8)                   \n\t"
    PTR_ADDU   "%[pDst], $8, %[iStrideD]        \n\t"
    PTR_ADDU   "$8, %[pDst], %[iStrideD]        \n\t"
    "gssdlc1    $f12, 0x7(%[pDst])              \n\t"
    "gssdlc1    $f14, 0x7($8)                   \n\t"
    "gssdrc1    $f12, 0x0(%[pDst])              \n\t"
    "gssdrc1    $f14, 0x0($8)                   \n\t"
   : [pDst]"+&r"((unsigned char *)pDst), [pSrc]"+&r"((unsigned char *)pSrc)
   : [iStrideD]"r"(iStrideD), [iStrideS]"r"(iStrideS)
   : "memory", "$8", "$f0", "$f2", "$f4", "$f6", "$f8", "$f10", "$f12", "$f14"
  );
}

void WelsCopy16x16_mmi(uint8_t* pDst, int32_t iDstStride, uint8_t* pSrc,
                       int32_t iSrcStride) {
  BACKUP_REG;
  __asm__ volatile (
    ".set       arch=loongson3a                 \n\t"
    "gslqc1     $f0, $f2, 0x0(%[pSrc])          \n\t"
    PTR_ADDU   "%[pSrc], %[pSrc], %[iSrcStride] \n\t"
    "gslqc1     $f4, $f6, 0x0(%[pSrc])          \n\t"
    PTR_ADDU   "%[pSrc], %[pSrc], %[iSrcStride] \n\t"
    "gslqc1     $f8, $f10, 0x0(%[pSrc])         \n\t"
    PTR_ADDU   "%[pSrc], %[pSrc], %[iSrcStride] \n\t"
    "gslqc1     $f12, $f14, 0x0(%[pSrc])        \n\t"
    PTR_ADDU   "%[pSrc], %[pSrc], %[iSrcStride] \n\t"
    "gslqc1     $f16, $f18, 0x0(%[pSrc])        \n\t"
    PTR_ADDU   "%[pSrc], %[pSrc], %[iSrcStride] \n\t"
    "gslqc1     $f20, $f22, 0x0(%[pSrc])        \n\t"
    PTR_ADDU   "%[pSrc], %[pSrc], %[iSrcStride] \n\t"
    "gslqc1     $f24, $f26, 0x0(%[pSrc])        \n\t"
    PTR_ADDU   "%[pSrc], %[pSrc], %[iSrcStride] \n\t"
    "gslqc1     $f28, $f30, 0x0(%[pSrc])        \n\t"
    PTR_ADDU   "%[pSrc], %[pSrc], %[iSrcStride] \n\t"

    "gssqc1     $f0, $f2, 0x0(%[pDst])          \n\t"
    PTR_ADDU   "%[pDst], %[pDst], %[iDstStride] \n\t"
    "gssqc1     $f4, $f6, 0x0(%[pDst])          \n\t"
    PTR_ADDU   "%[pDst], %[pDst], %[iDstStride] \n\t"
    "gssqc1     $f8, $f10, 0x0(%[pDst])         \n\t"
    PTR_ADDU   "%[pDst], %[pDst], %[iDstStride] \n\t"
    "gssqc1     $f12, $f14, 0x0(%[pDst])        \n\t"
    PTR_ADDU   "%[pDst], %[pDst], %[iDstStride] \n\t"
    "gssqc1     $f16, $f18, 0x0(%[pDst])        \n\t"
    PTR_ADDU   "%[pDst], %[pDst], %[iDstStride] \n\t"
    "gssqc1     $f20, $f22, 0x0(%[pDst])        \n\t"
    PTR_ADDU   "%[pDst], %[pDst], %[iDstStride] \n\t"
    "gssqc1     $f24, $f26, 0x0(%[pDst])        \n\t"
    PTR_ADDU   "%[pDst], %[pDst], %[iDstStride] \n\t"
    "gssqc1     $f28, $f30, 0x0(%[pDst])        \n\t"
    PTR_ADDU   "%[pDst], %[pDst], %[iDstStride] \n\t"

    "gslqc1     $f0, $f2, 0x0(%[pSrc])          \n\t"
    PTR_ADDU   "%[pSrc], %[pSrc], %[iSrcStride] \n\t"
    "gslqc1     $f4, $f6, 0x0(%[pSrc])          \n\t"
    PTR_ADDU   "%[pSrc], %[pSrc], %[iSrcStride] \n\t"
    "gslqc1     $f8, $f10, 0x0(%[pSrc])         \n\t"
    PTR_ADDU   "%[pSrc], %[pSrc], %[iSrcStride] \n\t"
    "gslqc1     $f12, $f14, 0x0(%[pSrc])        \n\t"
    PTR_ADDU   "%[pSrc], %[pSrc], %[iSrcStride] \n\t"
    "gslqc1     $f16, $f18, 0x0(%[pSrc])        \n\t"
    PTR_ADDU   "%[pSrc], %[pSrc], %[iSrcStride] \n\t"
    "gslqc1     $f20, $f22, 0x0(%[pSrc])        \n\t"
    PTR_ADDU   "%[pSrc], %[pSrc], %[iSrcStride] \n\t"
    "gslqc1     $f24, $f26, 0x0(%[pSrc])        \n\t"
    PTR_ADDU   "%[pSrc], %[pSrc], %[iSrcStride] \n\t"
    "gslqc1     $f28, $f30, 0x0(%[pSrc])        \n\t"

    "gssqc1     $f0, $f2, 0x0(%[pDst])          \n\t"
    PTR_ADDU   "%[pDst], %[pDst], %[iDstStride] \n\t"
    "gssqc1     $f4, $f6, 0x0(%[pDst])          \n\t"
    PTR_ADDU   "%[pDst], %[pDst], %[iDstStride] \n\t"
    "gssqc1     $f8, $f10, 0x0(%[pDst])         \n\t"
    PTR_ADDU   "%[pDst], %[pDst], %[iDstStride] \n\t"
    "gssqc1     $f12, $f14, 0x0(%[pDst])        \n\t"
    PTR_ADDU   "%[pDst], %[pDst], %[iDstStride] \n\t"
    "gssqc1     $f16, $f18, 0x0(%[pDst])        \n\t"
    PTR_ADDU   "%[pDst], %[pDst], %[iDstStride] \n\t"
    "gssqc1     $f20, $f22, 0x0(%[pDst])        \n\t"
    PTR_ADDU   "%[pDst], %[pDst], %[iDstStride] \n\t"
    "gssqc1     $f24, $f26, 0x0(%[pDst])        \n\t"
    PTR_ADDU   "%[pDst], %[pDst], %[iDstStride] \n\t"
    "gssqc1     $f28, $f30, 0x0(%[pDst])        \n\t"
   : [pDst]"+&r"((unsigned char *)pDst), [pSrc]"+&r"((unsigned char *)pSrc)
   : [iDstStride]"r"((int)iDstStride), [iSrcStride]"r"((int)iSrcStride)
   : "memory", "$f0", "$f2", "$f4", "$f6", "$f8", "$f10", "$f12",
     "$f14", "$f16", "$f18", "$f20", "$f22", "$f24", "$f26", "$f28", "$f30"
  );
  RECOVER_REG;
}

void WelsCopy16x16NotAligned_mmi(uint8_t* pDst, int32_t iDstStride, uint8_t* pSrc,
                                 int32_t iSrcStride) {
  BACKUP_REG;
  __asm__ volatile (
    ".set       arch=loongson3a                 \n\t"
    "gsldlc1    $f2, 0x7(%[pSrc])               \n\t"
    "gsldlc1    $f0, 0xF(%[pSrc])               \n\t"
    "gsldrc1    $f2, 0x0(%[pSrc])               \n\t"
    "gsldrc1    $f0, 0x8(%[pSrc])               \n\t"
    PTR_ADDU   "%[pSrc], %[pSrc], %[iSrcStride] \n\t"
    "gsldlc1    $f6, 0x7(%[pSrc])               \n\t"
    "gsldlc1    $f4, 0xF(%[pSrc])               \n\t"
    "gsldrc1    $f6, 0x0(%[pSrc])               \n\t"
    "gsldrc1    $f4, 0x8(%[pSrc])               \n\t"
    PTR_ADDU   "%[pSrc], %[pSrc], %[iSrcStride] \n\t"
    "gsldlc1    $f10, 0x7(%[pSrc])              \n\t"
    "gsldlc1    $f8, 0xF(%[pSrc])               \n\t"
    "gsldrc1    $f10, 0x0(%[pSrc])              \n\t"
    "gsldrc1    $f8, 0x8(%[pSrc])               \n\t"
    PTR_ADDU   "%[pSrc], %[pSrc], %[iSrcStride] \n\t"
    "gsldlc1    $f14, 0x7(%[pSrc])              \n\t"
    "gsldlc1    $f12, 0xF(%[pSrc])              \n\t"
    "gsldrc1    $f14, 0x0(%[pSrc])              \n\t"
    "gsldrc1    $f12, 0x8(%[pSrc])              \n\t"
    PTR_ADDU   "%[pSrc], %[pSrc], %[iSrcStride] \n\t"
    "gsldlc1    $f18, 0x7(%[pSrc])              \n\t"
    "gsldlc1    $f16, 0xF(%[pSrc])              \n\t"
    "gsldrc1    $f18, 0x0(%[pSrc])              \n\t"
    "gsldrc1    $f16, 0x8(%[pSrc])              \n\t"
    PTR_ADDU   "%[pSrc], %[pSrc], %[iSrcStride] \n\t"
    "gsldlc1    $f22, 0x7(%[pSrc])              \n\t"
    "gsldlc1    $f20, 0xF(%[pSrc])              \n\t"
    "gsldrc1    $f22, 0x0(%[pSrc])              \n\t"
    "gsldrc1    $f20, 0x8(%[pSrc])              \n\t"
    PTR_ADDU   "%[pSrc], %[pSrc], %[iSrcStride] \n\t"
    "gsldlc1    $f26, 0x7(%[pSrc])              \n\t"
    "gsldlc1    $f24, 0xF(%[pSrc])              \n\t"
    "gsldrc1    $f26, 0x0(%[pSrc])              \n\t"
    "gsldrc1    $f24, 0x8(%[pSrc])              \n\t"
    PTR_ADDU   "%[pSrc], %[pSrc], %[iSrcStride] \n\t"
    "gsldlc1    $f30, 0x7(%[pSrc])              \n\t"
    "gsldlc1    $f28, 0xF(%[pSrc])              \n\t"
    "gsldrc1    $f30, 0x0(%[pSrc])              \n\t"
    "gsldrc1    $f28, 0x8(%[pSrc])              \n\t"
    PTR_ADDU   "%[pSrc], %[pSrc], %[iSrcStride] \n\t"

    PTR_ADDU   "$8, %[pDst], %[iDstStride]      \n\t"
    "gssqc1     $f0, $f2, 0x0(%[pDst])          \n\t"
    "gssqc1     $f4, $f6, 0x0($8)               \n\t"
    PTR_ADDU   "%[pDst], $8, %[iDstStride]      \n\t"
    PTR_ADDU   "$8, %[pDst], %[iDstStride]      \n\t"
    "gssqc1     $f8, $f10, 0x0(%[pDst])         \n\t"
    "gssqc1     $f12, $f14, 0x0($8)             \n\t"
    PTR_ADDU   "%[pDst], $8, %[iDstStride]      \n\t"
    PTR_ADDU   "$8, %[pDst], %[iDstStride]      \n\t"
    "gssqc1     $f16, $f18, 0x0(%[pDst])        \n\t"
    "gssqc1     $f20, $f22, 0x0($8)             \n\t"
    PTR_ADDU   "%[pDst], $8, %[iDstStride]      \n\t"
    PTR_ADDU   "$8, %[pDst], %[iDstStride]      \n\t"
    "gssqc1     $f24, $f26, 0x0(%[pDst])        \n\t"
    "gssqc1     $f28, $f30, 0x0($8)             \n\t"
    PTR_ADDU   "%[pDst], $8, %[iDstStride]      \n\t"

    "gsldlc1    $f2, 0x7(%[pSrc])               \n\t"
    "gsldlc1    $f0, 0xF(%[pSrc])               \n\t"
    "gsldrc1    $f2, 0x0(%[pSrc])               \n\t"
    "gsldrc1    $f0, 0x8(%[pSrc])               \n\t"
    PTR_ADDU   "%[pSrc], %[pSrc], %[iSrcStride] \n\t"
    "gsldlc1    $f6, 0x7(%[pSrc])               \n\t"
    "gsldlc1    $f4, 0xF(%[pSrc])               \n\t"
    "gsldrc1    $f6, 0x0(%[pSrc])               \n\t"
    "gsldrc1    $f4, 0x8(%[pSrc])               \n\t"
    PTR_ADDU   "%[pSrc], %[pSrc], %[iSrcStride] \n\t"
    "gsldlc1    $f10, 0x7(%[pSrc])              \n\t"
    "gsldlc1    $f8, 0xF(%[pSrc])               \n\t"
    "gsldrc1    $f10, 0x0(%[pSrc])              \n\t"
    "gsldrc1    $f8, 0x8(%[pSrc])               \n\t"
    PTR_ADDU   "%[pSrc], %[pSrc], %[iSrcStride] \n\t"
    "gsldlc1    $f14, 0x7(%[pSrc])              \n\t"
    "gsldlc1    $f12, 0xF(%[pSrc])              \n\t"
    "gsldrc1    $f14, 0x0(%[pSrc])              \n\t"
    "gsldrc1    $f12, 0x8(%[pSrc])              \n\t"
    PTR_ADDU   "%[pSrc], %[pSrc], %[iSrcStride] \n\t"
    "gsldlc1    $f18, 0x7(%[pSrc])              \n\t"
    "gsldlc1    $f16, 0xF(%[pSrc])              \n\t"
    "gsldrc1    $f18, 0x0(%[pSrc])              \n\t"
    "gsldrc1    $f16, 0x8(%[pSrc])              \n\t"
    PTR_ADDU   "%[pSrc], %[pSrc], %[iSrcStride] \n\t"
    "gsldlc1    $f22, 0x7(%[pSrc])              \n\t"
    "gsldlc1    $f20, 0xF(%[pSrc])              \n\t"
    "gsldrc1    $f22, 0x0(%[pSrc])              \n\t"
    "gsldrc1    $f20, 0x8(%[pSrc])              \n\t"
    PTR_ADDU   "%[pSrc], %[pSrc], %[iSrcStride] \n\t"
    "gsldlc1    $f26, 0x7(%[pSrc])              \n\t"
    "gsldlc1    $f24, 0xF(%[pSrc])              \n\t"
    "gsldrc1    $f26, 0x0(%[pSrc])              \n\t"
    "gsldrc1    $f24, 0x8(%[pSrc])              \n\t"
    PTR_ADDU   "%[pSrc], %[pSrc], %[iSrcStride] \n\t"
    "gsldlc1    $f30, 0x7(%[pSrc])              \n\t"
    "gsldlc1    $f28, 0xF(%[pSrc])              \n\t"
    "gsldrc1    $f30, 0x0(%[pSrc])              \n\t"
    "gsldrc1    $f28, 0x8(%[pSrc])              \n\t"

    PTR_ADDU   "$8, %[pDst], %[iDstStride]      \n\t"
    "gssqc1     $f0, $f2, 0x0(%[pDst])          \n\t"
    "gssqc1     $f4, $f6, 0x0($8)               \n\t"
    PTR_ADDU   "%[pDst], $8, %[iDstStride]      \n\t"
    PTR_ADDU   "$8, %[pDst], %[iDstStride]      \n\t"
    "gssqc1     $f8, $f10, 0x0(%[pDst])         \n\t"
    "gssqc1     $f12, $f14, 0x0($8)             \n\t"
    PTR_ADDU   "%[pDst], $8, %[iDstStride]      \n\t"
    PTR_ADDU   "$8, %[pDst], %[iDstStride]      \n\t"
    "gssqc1     $f16, $f18, 0x0(%[pDst])        \n\t"
    "gssqc1     $f20, $f22, 0x0($8)             \n\t"
    PTR_ADDU   "%[pDst], $8, %[iDstStride]      \n\t"
    PTR_ADDU   "$8, %[pDst], %[iDstStride]      \n\t"
    "gssqc1     $f24, $f26, 0x0(%[pDst])        \n\t"
    "gssqc1     $f28, $f30, 0x0($8)             \n\t"
   : [pDst]"+&r"((unsigned char *)pDst), [pSrc]"+&r"((unsigned char *)pSrc)
   : [iDstStride]"r"((int)iDstStride), [iSrcStride]"r"((int)iSrcStride)
   : "memory", "$8", "$f0", "$f2", "$f4", "$f6", "$f8", "$f10", "$f12",
     "$f14", "$f16", "$f18", "$f20", "$f22", "$f24", "$f26", "$f28", "$f30"
  );
  RECOVER_REG;
}

void WelsCopy16x8NotAligned_mmi(uint8_t* pDst, int32_t iDstStride, uint8_t* pSrc,
                                int32_t iSrcStride) {
  BACKUP_REG;
  __asm__ volatile (
    ".set       arch=loongson3a                 \n\t"
    "gsldlc1    $f2, 0x7(%[pSrc])               \n\t"
    "gsldlc1    $f0, 0xF(%[pSrc])               \n\t"
    "gsldrc1    $f2, 0x0(%[pSrc])               \n\t"
    "gsldrc1    $f0, 0x8(%[pSrc])               \n\t"
    PTR_ADDU   "%[pSrc], %[pSrc], %[iSrcStride] \n\t"
    "gsldlc1    $f6, 0x7(%[pSrc])               \n\t"
    "gsldlc1    $f4, 0xF(%[pSrc])               \n\t"
    "gsldrc1    $f6, 0x0(%[pSrc])               \n\t"
    "gsldrc1    $f4, 0x8(%[pSrc])               \n\t"
    PTR_ADDU   "%[pSrc], %[pSrc], %[iSrcStride] \n\t"
    "gsldlc1    $f10, 0x7(%[pSrc])              \n\t"
    "gsldlc1    $f8, 0xF(%[pSrc])               \n\t"
    "gsldrc1    $f10, 0x0(%[pSrc])              \n\t"
    "gsldrc1    $f8, 0x8(%[pSrc])               \n\t"
    PTR_ADDU   "%[pSrc], %[pSrc], %[iSrcStride] \n\t"
    "gsldlc1    $f14, 0x7(%[pSrc])              \n\t"
    "gsldlc1    $f12, 0xF(%[pSrc])              \n\t"
    "gsldrc1    $f14, 0x0(%[pSrc])              \n\t"
    "gsldrc1    $f12, 0x8(%[pSrc])              \n\t"
    PTR_ADDU   "%[pSrc], %[pSrc], %[iSrcStride] \n\t"
    "gsldlc1    $f18, 0x7(%[pSrc])              \n\t"
    "gsldlc1    $f16, 0xF(%[pSrc])              \n\t"
    "gsldrc1    $f18, 0x0(%[pSrc])              \n\t"
    "gsldrc1    $f16, 0x8(%[pSrc])              \n\t"
    PTR_ADDU   "%[pSrc], %[pSrc], %[iSrcStride] \n\t"
    "gsldlc1    $f22, 0x7(%[pSrc])              \n\t"
    "gsldlc1    $f20, 0xF(%[pSrc])              \n\t"
    "gsldrc1    $f22, 0x0(%[pSrc])              \n\t"
    "gsldrc1    $f20, 0x8(%[pSrc])              \n\t"
    PTR_ADDU   "%[pSrc], %[pSrc], %[iSrcStride] \n\t"
    "gsldlc1    $f26, 0x7(%[pSrc])              \n\t"
    "gsldlc1    $f24, 0xF(%[pSrc])              \n\t"
    "gsldrc1    $f26, 0x0(%[pSrc])              \n\t"
    "gsldrc1    $f24, 0x8(%[pSrc])              \n\t"
    PTR_ADDU   "%[pSrc], %[pSrc], %[iSrcStride] \n\t"
    "gsldlc1    $f30, 0x7(%[pSrc])              \n\t"
    "gsldlc1    $f28, 0xF(%[pSrc])              \n\t"
    "gsldrc1    $f30, 0x0(%[pSrc])              \n\t"
    "gsldrc1    $f28, 0x8(%[pSrc])              \n\t"

    "gssqc1     $f0, $f2, 0x0(%[pDst])          \n\t"
    PTR_ADDU   "%[pDst], %[pDst], %[iDstStride] \n\t"
    "gssqc1     $f4, $f6, 0x0(%[pDst])          \n\t"
    PTR_ADDU   "%[pDst], %[pDst], %[iDstStride] \n\t"
    "gssqc1     $f8, $f10, 0x0(%[pDst])         \n\t"
    PTR_ADDU   "%[pDst], %[pDst], %[iDstStride] \n\t"
    "gssqc1     $f12, $f14, 0x0(%[pDst])        \n\t"
    PTR_ADDU   "%[pDst], %[pDst], %[iDstStride] \n\t"
    "gssqc1     $f16, $f18, 0x0(%[pDst])        \n\t"
    PTR_ADDU   "%[pDst], %[pDst], %[iDstStride] \n\t"
    "gssqc1     $f20, $f22, 0x0(%[pDst])        \n\t"
    PTR_ADDU   "%[pDst], %[pDst], %[iDstStride] \n\t"
    "gssqc1     $f24, $f26, 0x0(%[pDst])        \n\t"
    PTR_ADDU   "%[pDst], %[pDst], %[iDstStride] \n\t"
    "gssqc1     $f28, $f30, 0x0(%[pDst])        \n\t"
   : [pDst]"+&r"((unsigned char *)pDst), [pSrc]"+&r"((unsigned char *)pSrc)
   : [iDstStride]"r"((int)iDstStride), [iSrcStride]"r"((int)iSrcStride)
   : "memory", "$f0", "$f2", "$f4", "$f6", "$f8", "$f10", "$f12",
     "$f14", "$f16", "$f18", "$f20", "$f22", "$f24", "$f26", "$f28", "$f30"
  );
  RECOVER_REG;
}
