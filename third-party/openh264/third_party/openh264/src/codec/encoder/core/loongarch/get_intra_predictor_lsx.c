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
 * \file    get_intra_predictor_lsx.c
 *
 * \brief   Loongson optimization
 *
 * \date    03/03/2022 Created
 *
 *************************************************************************************
 */
#include <stdint.h>
#include "loongson_intrinsics.h"

void WelsI16x16LumaPredPlane_lsx (uint8_t* pPred, uint8_t* pRef,
                                  const int32_t kiStride) {
  int32_t iLTshift = 0, iTopshift = 0;
  int32_t iLeftshift = 0, iTopSum = 0, iLeftSum = 0;
  int32_t i, j;
  uint8_t* pTop = &pRef[-kiStride];
  uint8_t* pLeft = &pRef[-1];
  int32_t iPredStride = 16;
  int32_t kiStride_x2 = kiStride << 1;
  int32_t kiStride_x3 = kiStride_x2 + kiStride;
  int32_t kiStride_x4 = kiStride << 2;
  int32_t kiStride_x5 = kiStride_x4 + kiStride;
  int32_t kiStride_x6 = kiStride_x4 + kiStride_x2;
  int32_t kiStride_x7 = kiStride_x4 + kiStride_x3;
  int32_t kiStride_x8 = kiStride << 3;

  __m128i q0, q1, q2, q3, q4, q5, q6, q7, p0, p1, p2;
  __m128i q0_l, q1_l, q2_l, q3_l, q4_l, q5_l, q6_l, q7_l, p0_l, p1_l;
  __m128i TopSum, LeftSum, sum, sum0, sum1, uiTmp, uiTmp0, uiTmp1;
  __m128i iLTshift_vec, iLeftshift_vec, iLeftshift_vec0;
  __m128i iTopshift_vec, iTopshift_vec0, iTopshift_vec1;
  __m128i tmp, flags, num;
  __m128i zero = __lsx_vldi(0);
  __m128i i_vec = {0x0004000300020001, 0x0008000700060005};
  __m128i shuf = {0x0001020304050607, 0x0f0e0d0c0b0a0908};
  __m128i not_255 = {0xff00ff00ff00ff00, 0xff00ff00ff00ff00};
  __m128i sixteen = {0x10001000100010, 0x10001000100010};
  __m128i t0 = {0xfffcfffbfffafff9, 0x0000fffffffefffd};
  __m128i t1 = {0x0004000300020001, 0x0008000700060005};

  DUP2_ARG2(__lsx_vldx, pTop, 8, pTop, -1, p0, p1);
  p1 = __lsx_vshuf_b(p1, p1, shuf);
  DUP2_ARG2(__lsx_vilvl_b, zero, p0, zero, p1, p0_l, p1_l);

  p2 = __lsx_vsub_h(p0_l, p1_l);
  TopSum = __lsx_vmul_h(i_vec, p2);
  tmp = __lsx_vbsrl_v(TopSum, 8);
  TopSum = __lsx_vadd_h(TopSum, tmp);
  tmp = __lsx_vbsrl_v(TopSum, 4);
  TopSum = __lsx_vadd_h(TopSum, tmp);
  tmp = __lsx_vbsrl_v(TopSum, 2);
  TopSum = __lsx_vadd_h(TopSum, tmp);
  iTopSum = __lsx_vpickve2gr_h(TopSum, 0);

  pLeft += kiStride_x7;
  DUP4_ARG2(__lsx_vldx, pLeft, kiStride, pLeft, kiStride_x2, pLeft, kiStride_x3,
            pLeft, kiStride_x4, q0, q1, q2, q3);
  DUP4_ARG2(__lsx_vldx, pLeft, kiStride_x5, pLeft, kiStride_x6, pLeft, kiStride_x7,
            pLeft, kiStride_x8, q4, q5, q6, q7);
  DUP4_ARG2(__lsx_vilvl_b, zero, q0, zero, q1, zero, q2, zero, q3,
            q0_l, q1_l, q2_l, q3_l);
  DUP4_ARG2(__lsx_vilvl_b, zero, q4, zero, q5, zero, q6, zero, q7,
            q4_l, q5_l, q6_l, q7_l);
  LSX_TRANSPOSE8x8_H(q0_l, q1_l, q2_l, q3_l, q4_l, q5_l, q6_l, q7_l,
                     p0, q1, q2, q3, q4, q5, q6, q7);

  DUP4_ARG2(__lsx_vldx, pLeft, -kiStride, pLeft, -kiStride_x2, pLeft, -kiStride_x3,
            pLeft, -kiStride_x4, q0, q1, q2, q3);
  DUP4_ARG2(__lsx_vldx, pLeft, -kiStride_x5, pLeft, -kiStride_x6, pLeft, -kiStride_x7,
            pLeft, -kiStride_x8, q4, q5, q6, q7);
  DUP4_ARG2(__lsx_vilvl_b, zero, q0, zero, q1, zero, q2, zero, q3,
            q0_l, q1_l, q2_l, q3_l);
  DUP4_ARG2(__lsx_vilvl_b, zero, q4, zero, q5, zero, q6, zero, q7,
            q4_l, q5_l, q6_l, q7_l);
  LSX_TRANSPOSE8x8_H(q0_l, q1_l, q2_l, q3_l, q4_l, q5_l, q6_l, q7_l,
                     q0, q1, q2, q3, q4, q5, q6, q7);

  q1 = __lsx_vsub_h(p0, q0);
  LeftSum = __lsx_vmul_h(i_vec, q1);
  tmp = __lsx_vbsrl_v(LeftSum, 8);
  LeftSum = __lsx_vadd_h(LeftSum, tmp);
  tmp = __lsx_vbsrl_v(LeftSum, 4);
  LeftSum = __lsx_vadd_h(LeftSum, tmp);
  tmp = __lsx_vbsrl_v(LeftSum, 2);
  LeftSum = __lsx_vadd_h(LeftSum, tmp);
  iLeftSum = __lsx_vpickve2gr_h(LeftSum, 0);

  iLTshift = (pLeft[kiStride_x8] + pTop[15]) << 4;
  iTopshift = ((iTopSum << 2) + iTopSum + 32) >> 6;
  iLeftshift = ((iLeftSum << 2) + iLeftSum + 32) >> 6;

  DUP2_ARG1(__lsx_vreplgr2vr_h, iLTshift, iTopshift,
            iLTshift_vec, iTopshift_vec);
  iLeftshift_vec = __lsx_vreplgr2vr_h(iLeftshift);

  DUP2_ARG2(__lsx_vmul_h, iTopshift_vec, t0, iTopshift_vec, t1,
            iTopshift_vec0, iTopshift_vec1);
  DUP2_ARG2(__lsx_vadd_h, iLTshift_vec, iTopshift_vec0, sum0, sixteen, sum0, sum0);
  DUP2_ARG2(__lsx_vadd_h, iLTshift_vec, iTopshift_vec1, sum1, sixteen, sum1, sum1);

  for (i = 0; i < 16; i++) {
    j = i - 7;
    num = __lsx_vreplgr2vr_h(j);
    iLeftshift_vec0 = __lsx_vmul_h(iLeftshift_vec, num);

    sum = __lsx_vadd_h(sum0, iLeftshift_vec0);
    sum = __lsx_vsrai_h(sum, 5);
    flags = __lsx_vand_v(sum, not_255);
    flags = __lsx_vseq_h(flags, zero);
    tmp = __lsx_vslt_h(zero, sum);
    uiTmp = __lsx_vand_v(flags, sum);
    flags = __lsx_vnor_v(flags, flags);
    tmp = __lsx_vand_v(flags, tmp);
    uiTmp0 = __lsx_vadd_h(uiTmp, tmp);

    sum = __lsx_vadd_h(sum1, iLeftshift_vec0);
    sum = __lsx_vsrai_h(sum, 5);
    flags = __lsx_vand_v(sum, not_255);
    flags = __lsx_vseq_h(flags, zero);
    tmp = __lsx_vslt_h(zero, sum);
    uiTmp = __lsx_vand_v(flags, sum);
    flags = __lsx_vnor_v(flags, flags);
    tmp = __lsx_vand_v(flags, tmp);
    uiTmp1 = __lsx_vadd_h(uiTmp, tmp);

    uiTmp = __lsx_vpickev_b(uiTmp1, uiTmp0);
    __lsx_vst(uiTmp, pPred, 0);
    pPred += iPredStride;
  }
}
