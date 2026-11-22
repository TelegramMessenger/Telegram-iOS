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
 * \file    sample_lasx.c
 *
 * \brief   Loongson optimization
 *
 * \date    13/10/2022 Created
 *
 **********************************************************************************
 */
#include "sad_common.h"

void WelsIChromaPredV_lasx (uint8_t* pPred, uint8_t* pRef, const int32_t kiStride);
void WelsIChromaPredH_lasx (uint8_t* pPred, uint8_t* pRef, const int32_t kiStride);
void WelsIChromaPredDc_lasx (uint8_t* pPred, uint8_t* pRef, const int32_t kiStride);

int32_t WelsIntra8x8Combined3Sad_lasx (uint8_t* pDecCb, int32_t iDecStride,
                                       uint8_t* pEncCb, int32_t iEncStride,
                                       int32_t* pBestMode, int32_t iLambda,
                                       uint8_t* pDstChroma, uint8_t* pDecCr,
                                       uint8_t* pEncCr) {
  int32_t iBestMode = -1;
  int32_t iCurCost, iBestCost = INT_MAX;

  WelsIChromaPredV_lasx (pDstChroma, pDecCb, iDecStride);
  WelsIChromaPredV_lasx (pDstChroma + 64, pDecCr, iDecStride);
  iCurCost = WelsSampleSad8x8_lasx(pDstChroma, 8, pEncCb, iEncStride);
  iCurCost += WelsSampleSad8x8_lasx(pDstChroma + 64, 8, pEncCr, iEncStride) + iLambda * 2;

  if (iCurCost < iBestCost) {
    iBestMode = 2;
    iBestCost = iCurCost;
  }

  WelsIChromaPredH_lasx(pDstChroma, pDecCb, iDecStride);
  WelsIChromaPredH_lasx(pDstChroma + 64, pDecCr, iDecStride);
  iCurCost = WelsSampleSad8x8_lasx(pDstChroma, 8, pEncCb, iEncStride);
  iCurCost += WelsSampleSad8x8_lasx(pDstChroma + 64, 8, pEncCr, iEncStride) + iLambda * 2;
  if (iCurCost < iBestCost) {
    iBestMode = 1;
    iBestCost = iCurCost;
  }

  WelsIChromaPredDc_lasx(pDstChroma, pDecCb, iDecStride);
  WelsIChromaPredDc_lasx(pDstChroma + 64, pDecCr, iDecStride);
  iCurCost = WelsSampleSad8x8_lasx(pDstChroma, 8, pEncCb, iEncStride);
  iCurCost += WelsSampleSad8x8_lasx(pDstChroma + 64, 8, pEncCr, iEncStride);
  if (iCurCost < iBestCost) {
    iBestMode = 0;
    iBestCost = iCurCost;
  }
  *pBestMode = iBestMode;

  return iBestCost;
}
