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
 * \file    svc_motion_estimate_lsx.c
 *
 * \brief   Loongson optimization
 *
 * \date    13/10/2022 Created
 *
 **********************************************************************************
 */

#include <stdint.h>
#include "loongson_intrinsics.h"

int32_t SumOf8x8SingleBlock_lsx (uint8_t* pRef, const int32_t kiRefStride) {
  __m128i vec_pRef0, vec_pRef1, vec_pRef2, vec_pRef3;
  __m128i vec_pRef4, vec_pRef5, vec_pRef6, vec_pRef7;

  int32_t iSum;
  int32_t kiRefStride_x2 = kiRefStride << 1;
  int32_t kiRefStride_x3 = kiRefStride_x2 + kiRefStride;
  int32_t kiRefStride_x4 = kiRefStride << 2;

  vec_pRef0 = __lsx_vld(pRef, 0);
  vec_pRef1 = __lsx_vldx(pRef, kiRefStride);
  vec_pRef2 = __lsx_vldx(pRef, kiRefStride_x2);
  vec_pRef3 = __lsx_vldx(pRef, kiRefStride_x3);
  pRef += kiRefStride_x4;
  vec_pRef4 = __lsx_vld(pRef, 0);
  vec_pRef5 = __lsx_vldx(pRef, kiRefStride);
  vec_pRef6 = __lsx_vldx(pRef, kiRefStride_x2);
  vec_pRef7 = __lsx_vldx(pRef, kiRefStride_x3);

  vec_pRef0 = __lsx_vilvl_d(vec_pRef1, vec_pRef0);
  vec_pRef2 = __lsx_vilvl_d(vec_pRef3, vec_pRef2);
  vec_pRef4 = __lsx_vilvl_d(vec_pRef5, vec_pRef4);
  vec_pRef6 = __lsx_vilvl_d(vec_pRef7, vec_pRef6);

  vec_pRef0 = __lsx_vhaddw_hu_bu(vec_pRef0, vec_pRef0);
  vec_pRef2 = __lsx_vhaddw_hu_bu(vec_pRef2, vec_pRef2);
  vec_pRef4 = __lsx_vhaddw_hu_bu(vec_pRef4, vec_pRef4);
  vec_pRef6 = __lsx_vhaddw_hu_bu(vec_pRef6, vec_pRef6);

  vec_pRef0 = __lsx_vadd_h(vec_pRef0, vec_pRef2);
  vec_pRef4 = __lsx_vadd_h(vec_pRef4, vec_pRef6);
  vec_pRef0 = __lsx_vadd_h(vec_pRef0, vec_pRef4);
  vec_pRef1 = __lsx_vhaddw_wu_hu(vec_pRef0, vec_pRef0);
  vec_pRef2 = __lsx_vhaddw_du_wu(vec_pRef1, vec_pRef1);
  vec_pRef0 = __lsx_vhaddw_qu_du(vec_pRef2, vec_pRef2);

  iSum = __lsx_vpickve2gr_w(vec_pRef0, 0);
  return iSum;
}

void SumOf8x8BlockOfFrame_lsx(uint8_t* pRefPicture, const int32_t kiWidth,
                              const int32_t kiHeight, const int32_t kiRefStride,
                              uint16_t* pFeatureOfBlock, uint32_t pTimesOfFeatureValue[]) {
  int32_t x, y;
  uint8_t* pRef;
  uint16_t* pBuffer;
  int32_t iSum;
  for (y = 0; y < kiHeight; y++) {
    pRef = pRefPicture  + kiRefStride * y;
    pBuffer  = pFeatureOfBlock + kiWidth * y;
    for (x = 0; x < kiWidth; x++) {
      iSum = SumOf8x8SingleBlock_lsx(pRef + x, kiRefStride);

      pBuffer[x] = iSum;
      pTimesOfFeatureValue[iSum]++;
    }
  }
}
