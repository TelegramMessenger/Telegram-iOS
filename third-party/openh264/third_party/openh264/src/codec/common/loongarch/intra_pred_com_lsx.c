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
 *
 * \file    intra_pred_com_lsx.c
 *
 * \brief   Loongson optimization
 *
 * \date    03/03/2022 Created
 *
 *************************************************************************************
 */
#include <stdint.h>
#include "loongson_intrinsics.h"

void WelsI16x16LumaPredV_lsx (uint8_t* pPred, uint8_t* pRef, const int32_t kiStride) {
  const int8_t* kpSrc = (int8_t*)&pRef[-kiStride];
  const uint64_t kuiT1 = *(uint64_t*)kpSrc;
  const uint64_t kuiT2 = *(uint64_t*)(kpSrc + 8);
  uint8_t* pDst = pPred;
  __m128i kuiT_vec, kuiT1_vec, kuiT2_vec;

  kuiT1_vec = __lsx_vreplgr2vr_d(kuiT1);
  kuiT2_vec = __lsx_vreplgr2vr_d(kuiT2);
  kuiT_vec = __lsx_vpackev_d(kuiT2_vec, kuiT1_vec);

  __lsx_vst(kuiT_vec, pDst, 0);
  __lsx_vstx(kuiT_vec, pDst, 16);
  __lsx_vstx(kuiT_vec, pDst, 32);
  __lsx_vstx(kuiT_vec, pDst, 48);
  __lsx_vstx(kuiT_vec, pDst, 64);
  __lsx_vstx(kuiT_vec, pDst, 80);
  __lsx_vstx(kuiT_vec, pDst, 96);
  __lsx_vstx(kuiT_vec, pDst, 112);
  __lsx_vstx(kuiT_vec, pDst, 128);
  __lsx_vstx(kuiT_vec, pDst, 144);
  __lsx_vstx(kuiT_vec, pDst, 160);
  __lsx_vstx(kuiT_vec, pDst, 176);
  __lsx_vstx(kuiT_vec, pDst, 192);
  __lsx_vstx(kuiT_vec, pDst, 208);
  __lsx_vstx(kuiT_vec, pDst, 224);
  __lsx_vstx(kuiT_vec, pDst, 240);
}

void WelsI16x16LumaPredH_lsx (uint8_t* pPred, uint8_t* pRef, const int32_t kiStride) {
  int32_t iStridex15 = (kiStride << 4) - kiStride;
  int32_t iPredStride = 16;
  int32_t iPredStridex15 = 240; //(iPredStride<<4)-iPredStride;
  uint8_t i = 15;
  __m128i kuiV64_vec;

  do {
    const uint8_t kuiSrc8 = pRef[iStridex15 - 1];
    kuiV64_vec = __lsx_vreplgr2vr_b(kuiSrc8);
    __lsx_vstx(kuiV64_vec, pPred, iPredStridex15);

    iStridex15 -= kiStride;
    iPredStridex15 -= iPredStride;
  } while (i-- > 0);
}
