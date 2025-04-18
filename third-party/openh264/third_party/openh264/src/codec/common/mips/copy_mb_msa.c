/*!
 * \copy
 *     Copyright (C) 2020 Loongson Technology Co. Ltd.
 *     Contributed by Gu Xiwei(guxiwei-hf@loongson.cn)
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
 * \file    copy_mb_msa.c
 *
 * \brief   MIPS MSA optimizations
 *
 * \date    14/05/2020 Created
 *
 *************************************************************************************
 */

#include <stdint.h>
#include "msa_macros.h"

void WelsCopy8x8_msa(uint8_t* pDst, int32_t iStrideD, uint8_t* pSrc,
                     int32_t  iStrideS ) {
    v16u8 src0, src1;
    for (int i = 0; i < 4; i++) {
        MSA_LD_V2(v16u8, pSrc, iStrideS, src0, src1);
        MSA_ST_D(src0, 0, pDst);
        MSA_ST_D(src1, 0, pDst + iStrideD);
        pSrc += 2 * iStrideS;
        pDst += 2 * iStrideD;
    }
}

void WelsCopy8x16_msa(uint8_t* pDst, int32_t iStrideD, uint8_t* pSrc,
                      int32_t iStrideS) {
    WelsCopy8x8_msa(pDst, iStrideD, pSrc, iStrideS);
    WelsCopy8x8_msa(pDst + 8 * iStrideD, iStrideD,
                    pSrc + 8 * iStrideS, iStrideS);
}

void WelsCopy16x8_msa(uint8_t* pDst, int32_t iStrideD, uint8_t* pSrc,
                      int32_t iStrideS) {
    v16u8 src0, src1;
    for (int i = 0; i < 4; i++) {
        MSA_LD_V2(v16u8, pSrc, iStrideS, src0, src1);
        MSA_ST_V2(v16u8, src0, src1, pDst, iStrideD);
        pSrc += 2 * iStrideS;
        pDst += 2 * iStrideD;
    }
}

void WelsCopy16x16_msa(uint8_t* pDst, int32_t iStrideD, uint8_t* pSrc,
                       int32_t iStrideS) {
    WelsCopy16x8_msa(pDst, iStrideD, pSrc, iStrideS);
    WelsCopy16x8_msa(pDst + 8 * iStrideD, iStrideD,
                     pSrc + 8 * iStrideS, iStrideS);
};
