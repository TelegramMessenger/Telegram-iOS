/*!
 **********************************************************************************
 * Copyright (c) 2022 Loongson Technology Corporation Limited
 * Contributed by Lu Wang <wanglu@loongson.cn>
 *
 * \copy
 *     Copyright (c)  2009-2013, Cisco Systems
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
 * \file    intra_pred_com_lasx.c
 *
 * \brief   Loongson optimization
 *
 * \date    13/10/2022 Created
 *
 **********************************************************************************
 */

#include <stdint.h>
#include "loongson_intrinsics.h"

void WelsIChromaPredV_lasx (uint8_t* pPred, uint8_t* pRef, const int32_t kiStride) {
  __m256i vec_kuiSrc64 = __lasx_xvldrepl_d (pRef - kiStride, 0);

  __lasx_xvst(vec_kuiSrc64, pPred, 0);
  __lasx_xvst(vec_kuiSrc64, pPred, 32);
}

void WelsIChromaPredH_lasx (uint8_t* pPred, uint8_t* pRef, const int32_t kiStride) {
  __m256i vec_kuiSrc0, vec_kuiSrc1;
  int32_t iStride_x2 = (kiStride << 1);
  int32_t iStride_x3 = (kiStride << 1) + kiStride;
  int32_t iStride_x4 = (kiStride << 2);

  pRef -= 1;
  vec_kuiSrc0 = __lasx_xvldrepl_b(pRef + kiStride, 0);
  vec_kuiSrc1 = __lasx_xvldrepl_b(pRef, 0);
  vec_kuiSrc0 = __lasx_xvilvl_d(vec_kuiSrc0, vec_kuiSrc1);
  __lasx_xvst(vec_kuiSrc0, pPred, 0);

  vec_kuiSrc0 = __lasx_xvldrepl_b(pRef + iStride_x3, 0);
  vec_kuiSrc1 = __lasx_xvldrepl_b(pRef + iStride_x2, 0);
  vec_kuiSrc0 = __lasx_xvilvl_d(vec_kuiSrc0, vec_kuiSrc1);
  __lasx_xvst(vec_kuiSrc0, pPred, 16);

  pRef += iStride_x4;
  vec_kuiSrc0 = __lasx_xvldrepl_b(pRef + kiStride, 0);
  vec_kuiSrc1 = __lasx_xvldrepl_b(pRef, 0);
  vec_kuiSrc0 = __lasx_xvilvl_d(vec_kuiSrc0, vec_kuiSrc1);
  __lasx_xvst(vec_kuiSrc0, pPred, 32);

  vec_kuiSrc0 = __lasx_xvldrepl_b(pRef + iStride_x3, 0);
  vec_kuiSrc1 = __lasx_xvldrepl_b(pRef + iStride_x2, 0);
  vec_kuiSrc0 = __lasx_xvilvl_d(vec_kuiSrc0, vec_kuiSrc1);
  __lasx_xvst(vec_kuiSrc0, pPred, 48);
}

void WelsIChromaPredDc_lasx (uint8_t* pPred, uint8_t* pRef, const int32_t kiStride) {
  const int32_t kuiL1 = kiStride - 1;
  const int32_t kuiL2 = kuiL1 + kiStride;
  const int32_t kuiL3 = kuiL2 + kiStride;
  const int32_t kuiL4 = kuiL3 + kiStride;
  const int32_t kuiL5 = kuiL4 + kiStride;
  const int32_t kuiL6 = kuiL5 + kiStride;
  const int32_t kuiL7 = kuiL6 + kiStride;
  /*caculate the iMean value*/
  const uint8_t kuiMean1 = (pRef[-kiStride] + pRef[1 - kiStride] + pRef[2 - kiStride] +
                           pRef[3 - kiStride] + pRef[-1] + pRef[kuiL1] + pRef[kuiL2] +
                           pRef[kuiL3] + 4) >> 3;
  const uint32_t kuiSum2 = pRef[4 - kiStride] + pRef[5 - kiStride] + pRef[6 - kiStride]
                           + pRef[7 - kiStride];
  const uint32_t kuiSum3 = pRef[kuiL4] + pRef[kuiL5] + pRef[kuiL6] + pRef[kuiL7];
  const uint8_t kuiMean2 = (kuiSum2 + 2) >> 2;
  const uint8_t kuiMean3 = (kuiSum3 + 2) >> 2;
  const uint8_t kuiMean4 = (kuiSum2 + kuiSum3 + 4) >> 3;

  const uint8_t kuiTopMean[8] = {kuiMean1, kuiMean1, kuiMean1, kuiMean1, kuiMean2,
                                 kuiMean2, kuiMean2, kuiMean2};
  const uint8_t kuiBottomMean[8] = {kuiMean3, kuiMean3, kuiMean3, kuiMean3, kuiMean4,
                                    kuiMean4, kuiMean4, kuiMean4};

  __m256i vec_kuiTopMean64 = __lasx_xvldrepl_d(kuiTopMean, 0);
  __m256i vec_kuiBottomMean64 = __lasx_xvldrepl_d(kuiBottomMean, 0);

  __lasx_xvst(vec_kuiTopMean64, pPred, 0);
  __lasx_xvst(vec_kuiBottomMean64, pPred, 32);
}
