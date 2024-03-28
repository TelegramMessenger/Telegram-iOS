/*!
 *************************************************************************************
 * Copyright (c) 2022 Loongson Technology Corporation Limited
 * Contributed by Jin Bo <jinbo@loongson.cn>
 *
 * \copy
 *     Copyright (c)  2022, Cisco Systems
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
 * \file    mb_aux_lsx.c
 *
 * \brief   Loongson optimization
 *
 * \date    7/3/2022 Created
 *
 *************************************************************************************
 */

#include <stdint.h>
#include "loongson_intrinsics.h"

#define DO(in0, in1, in2, in3, in4, in5, in6, in7, \
           ou0, ou1, ou2, ou3, ou4, ou5, ou6, ou7) \
do {                                               \
  __m128i t0, t1, t2, t3, a0, a1, a2, a3;          \
  __m128i b0, b1, b2, b3, b4, b5, b6, b7;          \
  t0 = __lsx_vsrai_h(in2, 1);                      \
  t1 = __lsx_vsrai_h(in6, 1);                      \
  a0 = __lsx_vadd_h(in0, in4);                     \
  a1 = __lsx_vsub_h(in0, in4);                     \
  a2 = __lsx_vsub_h(in6, t0);                      \
  a3 = __lsx_vadd_h(in2, t1);                      \
  b0 = __lsx_vadd_h(a0, a3);                       \
  b2 = __lsx_vsub_h(a1, a2);                       \
  b4 = __lsx_vadd_h(a1, a2);                       \
  b6 = __lsx_vsub_h(a0, a3);                       \
  DUP4_ARG2(__lsx_vsrai_h,                         \
            in7, 1,                                \
            in3, 1,                                \
            in5, 1,                                \
            in1, 1,                                \
            t0, t1, t2 ,t3);                       \
  a0 = __lsx_vsub_h(in5, in3);                     \
  a0 = __lsx_vsub_h(a0, in7);                      \
  a0 = __lsx_vsub_h(a0, t0);                       \
  a1 = __lsx_vadd_h(in1, in7);                     \
  a1 = __lsx_vsub_h(a1, in3);                      \
  a1 = __lsx_vsub_h(a1, t1);                       \
  a2 = __lsx_vsub_h(in7, in1);                     \
  a2 = __lsx_vadd_h(a2, in5);                      \
  a2 = __lsx_vadd_h(a2, t2);                       \
  a3 = __lsx_vadd_h(in3, in5);                     \
  a3 = __lsx_vadd_h(a3, in1);                      \
  a3 = __lsx_vadd_h(a3, t3);                       \
  DUP4_ARG2(__lsx_vsrai_h,                         \
            a0, 2,                                 \
            a1, 2,                                 \
            a2, 2,                                 \
            a3, 2,                                 \
            t0, t1, t2, t3);                       \
  b1 = __lsx_vadd_h(a0, t3);                       \
  b7 = __lsx_vsub_h(a3, t0);                       \
  b3 = __lsx_vadd_h(a1, t2);                       \
  b5 = __lsx_vsub_h(a2, t1);                       \
  ou0 = __lsx_vadd_h(b0, b7);                      \
  ou1 = __lsx_vsub_h(b2, b5);                      \
  ou2 = __lsx_vadd_h(b4, b3);                      \
  ou3 = __lsx_vadd_h(b6, b1);                      \
  ou4 = __lsx_vsub_h(b6, b1);                      \
  ou5 = __lsx_vsub_h(b4, b3);                      \
  ou6 = __lsx_vadd_h(b2, b5);                      \
  ou7 = __lsx_vsub_h(b0, b7);                      \
}while(0)

void IdctResAddPred_lsx (uint8_t* pPred, const int32_t kiStride,
                         int16_t* pRs) {
  int32_t iStride0 = 0;
  int32_t iStride_x2 = kiStride << 1;
  int32_t iStride_x3 = kiStride + iStride_x2;

  __m128i src0, src1, src2, src3, dst0, dst1, dst2, dst3;
  __m128i pre0, pre1, pre2, pre3, tmp0, tmp1, tmp2, tmp3;
  __m128i t0, t1, t2, t3;

  DUP2_ARG2(__lsx_vld,
            pRs, 0,
            pRs, 16,
            src0, src2);
  DUP4_ARG2(__lsx_vldx,
            pPred, iStride0,
            pPred, kiStride,
            pPred, iStride_x2,
            pPred, iStride_x3,
            pre0, pre1, pre2, pre3);
  src1 = __lsx_vbsrl_v(src0, 8);
  src3 = __lsx_vbsrl_v(src2, 8);

  tmp1 = __lsx_vilvl_h(src1, src0);
  tmp3 = __lsx_vilvl_h(src3, src2);
  src0 = __lsx_vilvl_w(tmp3, tmp1);
  src1 = __lsx_vilvh_d(src0, src0);
  src2 = __lsx_vilvh_w(tmp3, tmp1);
  src3 = __lsx_vilvh_d(src2, src2);
  t0   = __lsx_vadd_h(src0, src2);
  t1   = __lsx_vsub_h(src0, src2);
  t2   = __lsx_vsrai_h(src1, 1);
  t2   = __lsx_vsub_h(t2, src3);
  t3   = __lsx_vsrai_h(src3, 1);
  t3   = __lsx_vadd_h(src1, t3);
  src0 = __lsx_vadd_h(t0, t3);  //0 4 8  12
  src1 = __lsx_vadd_h(t1, t2);  //1 5 9  13
  src2 = __lsx_vsub_h(t1, t2);  //2 6 10 14
  src3 = __lsx_vsub_h(t0, t3);  //3 7 11 15
  tmp1 = __lsx_vilvl_h(src1, src0);
  tmp3 = __lsx_vilvl_h(src3, src2);
  src0 = __lsx_vilvl_w(tmp3, tmp1);
  src1 = __lsx_vilvh_d(src0, src0);
  src2 = __lsx_vilvh_w(tmp3, tmp1);
  src3 = __lsx_vilvh_d(src2, src2);
  t1   = __lsx_vadd_h(src0, src2);
  t2   = __lsx_vsrai_h(src3, 1);
  t2   = __lsx_vadd_h(src1, t2);
  dst0 = __lsx_vadd_h(t1, t2);
  dst3 = __lsx_vsub_h(t1, t2);
  t1   = __lsx_vsub_h(src0, src2);
  t2   = __lsx_vsrai_h(src1, 1);
  t2   = __lsx_vsub_h(t2, src3);
  dst1 = __lsx_vadd_h(t1, t2);
  dst2 = __lsx_vsub_h(t1, t2);
  DUP2_ARG2(__lsx_vpackev_d,
            dst1, dst0,
            dst3, dst2,
            dst0, dst2);
  DUP2_ARG2(__lsx_vpackev_w,
            pre1, pre0,
            pre3, pre2,
            pre0, pre2);
  DUP2_ARG2(__lsx_vsllwil_hu_bu,
            pre0, 0,
            pre2, 0,
            tmp0, tmp2);
  DUP2_ARG2(__lsx_vsrari_h,
            dst0, 6,
            dst2, 6,
            dst0, dst2);
  DUP2_ARG2(__lsx_vadd_h,
            tmp0, dst0,
            tmp2, dst2,
            dst0, dst2);
  DUP2_ARG1(__lsx_vclip255_h,
            dst0, dst2,
            dst0, dst2);
  dst0 = __lsx_vpickev_b(dst2, dst0);
  __lsx_vstelm_w(dst0, pPred, 0, 0);
  __lsx_vstelm_w(dst0, pPred + kiStride, 0, 1);
  __lsx_vstelm_w(dst0, pPred + iStride_x2, 0, 2);
  __lsx_vstelm_w(dst0, pPred + iStride_x3, 0, 3);
}

void IdctResAddPred8x8_lsx (uint8_t* pPred, const int32_t kiStride,
                            int16_t* pRs) {
  int32_t iStride0   = 0;
  int32_t iStride_x2 = kiStride << 1;
  int32_t iStride_x3 = kiStride + iStride_x2;
  int32_t iStride_x4 = kiStride << 2;
  int32_t iStride_x5 = kiStride + iStride_x4;
  int32_t iStride_x6 = kiStride + iStride_x5;
  int32_t iStride_x7 = kiStride + iStride_x6;

  __m128i src0, src1, src2, src3, src4, src5, src6, src7;
  __m128i pre0, pre1, pre2, pre3, pre4, pre5, pre6, pre7;
  __m128i tmp0, tmp1, tmp2 ,tmp3, tmp4, tmp5, tmp6, tmp7;

  DUP4_ARG2(__lsx_vld,
            pRs, 0,
            pRs, 16,
            pRs, 32,
            pRs, 48,
            src0, src1, src2, src3);
  DUP4_ARG2(__lsx_vld,
            pRs, 64,
            pRs, 80,
            pRs, 96,
            pRs, 112,
            src4, src5, src6, src7);
  DUP4_ARG2(__lsx_vldx,
            pPred, iStride0,
            pPred, kiStride,
            pPred, iStride_x2,
            pPred, iStride_x3,
            pre0, pre1, pre2, pre3);
  DUP4_ARG2(__lsx_vldx,
            pPred, iStride_x4,
            pPred, iStride_x5,
            pPred, iStride_x6,
            pPred, iStride_x7,
            pre4, pre5, pre6, pre7);
  //Horizontal
  LSX_TRANSPOSE8x8_H(src0, src1, src2, src3, src4, src5, src6, src7,
                     src0, src1, src2, src3, src4, src5, src6, src7);
  DO(src0, src1, src2, src3, src4, src5, src6, src7,
     src0, src1, src2, src3, src4, src5, src6, src7);
  //Vertical
  LSX_TRANSPOSE8x8_H(src0, src1, src2, src3, src4, src5, src6, src7,
                     src0, src1, src2, src3, src4, src5, src6, src7);
  DO(src0, src1, src2, src3, src4, src5, src6, src7,
     src0, src1, src2, src3, src4, src5, src6, src7);
  DUP4_ARG2(__lsx_vsllwil_hu_bu,
            pre0, 0,
            pre1, 0,
            pre2, 0,
            pre3, 0,
            tmp0, tmp1, tmp2, tmp3);
  DUP4_ARG2(__lsx_vsllwil_hu_bu,
            pre4, 0,
            pre5, 0,
            pre6, 0,
            pre7, 0,
            tmp4, tmp5, tmp6, tmp7);
  DUP4_ARG2(__lsx_vsrari_h,
            src0, 6,
            src1, 6,
            src2, 6,
            src3, 6,
            src0, src1, src2, src3);
  DUP4_ARG2(__lsx_vsrari_h,
            src4, 6,
            src5, 6,
            src6, 6,
            src7, 6,
            src4, src5, src6, src7);
  DUP4_ARG2(__lsx_vadd_h,
            src0, tmp0,
            src1, tmp1,
            src2, tmp2,
            src3, tmp3,
            src0, src1, src2, src3);
  DUP4_ARG2(__lsx_vadd_h,
            src4, tmp4,
            src5, tmp5,
            src6, tmp6,
            src7, tmp7,
            src4, src5, src6, src7);
  DUP4_ARG1(__lsx_vclip255_h,
            src0,
            src1,
            src2,
            src3,
            src0, src1, src2, src3);
  DUP4_ARG1(__lsx_vclip255_h,
            src4,
            src5,
            src6,
            src7,
            src4, src5, src6, src7);
  DUP4_ARG2(__lsx_vpickev_b,
            src4, src0,
            src5, src1,
            src6, src2,
            src7, src3,
            src0, src1, src2, src3);
   __lsx_vstelm_d(src0, pPred,              0, 0);
   __lsx_vstelm_d(src1, pPred + kiStride,   0, 0);
   __lsx_vstelm_d(src2, pPred + iStride_x2, 0, 0);
   __lsx_vstelm_d(src3, pPred + iStride_x3, 0, 0);
   __lsx_vstelm_d(src0, pPred + iStride_x4, 0, 1);
   __lsx_vstelm_d(src1, pPred + iStride_x5, 0, 1);
   __lsx_vstelm_d(src2, pPred + iStride_x6, 0, 1);
   __lsx_vstelm_d(src3, pPred + iStride_x7, 0, 1);
}
