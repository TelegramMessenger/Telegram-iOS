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
 * \file    mc_horver_lsx.c
 *
 * \brief   Loongson optimization
 *
 * \date    3/3/2022 Created
 *
 *************************************************************************************
 */

#include <stdint.h>
#include "loongson_intrinsics.h"

#define FILTER_INPUT_8BIT(_in0, _in1, _in2, _in3, \
                          _in4, _in5, _out0)      \
do {                                              \
  __m128i _tmp;                                   \
  _in0  = __lsx_vadd_h(_in0, _in5);               \
  _in1  = __lsx_vadd_h(_in1, _in4);               \
  _in2  = __lsx_vadd_h(_in2, _in3);               \
  _tmp  = __lsx_vslli_h(_in1, 2);                 \
  _in1  = __lsx_vadd_h(_tmp, _in1);               \
  _in0  = __lsx_vsub_h(_in0, _in1);               \
  _tmp  = __lsx_vslli_h(_in2, 4);                 \
  _in0  = __lsx_vadd_h(_in0, _tmp);               \
  _tmp  = __lsx_vslli_h(_in2, 2);                 \
  _out0 = __lsx_vadd_h(_in0, _tmp);               \
}while(0)

#define HOR_FILTER_INPUT_16BIT(_in0, _in1, _in2, _in3, \
                               _in4, _in5, _out0)      \
do {                                                   \
  __m128i _pi05, _pi14, _pi23, _temp;                  \
  _pi05 = __lsx_vadd_w(_in0, _in5);                    \
  _pi14 = __lsx_vadd_w(_in1, _in4);                    \
  _pi23 = __lsx_vadd_w(_in2, _in3);                    \
  _temp = __lsx_vslli_w(_pi14, 2);                     \
  _pi14 = __lsx_vadd_w(_temp, _pi14);                  \
  _pi05 = __lsx_vsub_w(_pi05, _pi14);                  \
  _temp = __lsx_vslli_w(_pi23, 4);                     \
  _pi05 = __lsx_vadd_w(_pi05, _temp);                  \
  _temp = __lsx_vslli_w(_pi23, 2);                     \
  _out0 = __lsx_vadd_w(_pi05, _temp);                  \
}while(0)

void PixelAvgWidthEq4_lsx(uint8_t *pDst, int32_t iDstStride, const uint8_t *pSrcA,
                          int32_t iSrcAStride, const uint8_t *pSrcB, int32_t iSrcBStride,
                          int32_t iHeight ) {
  int32_t i;
  __m128i src0, src1;
  for (i = 0; i < iHeight; i++) {
    src0 = __lsx_vldrepl_w(pSrcA, 0);
    src1 = __lsx_vldrepl_w(pSrcB, 0);
    pSrcA += iSrcAStride;
    pSrcB += iSrcBStride;
    src0 = __lsx_vavgr_bu(src0, src1);
    __lsx_vstelm_w(src0, pDst, 0, 0);
    pDst  += iDstStride;
  }
}

void PixelAvgWidthEq8_lsx(uint8_t *pDst, int32_t iDstStride, const uint8_t *pSrcA,
                          int32_t iSrcAStride, const uint8_t *pSrcB, int32_t iSrcBStride,
                          int32_t iHeight ) {
  int32_t i;
  __m128i src0, src1, src2, src3;
  for (i = 0; i < iHeight; i += 2) {
    src0 = __lsx_vldrepl_d(pSrcA, 0);
    src1 = __lsx_vldrepl_d(pSrcB, 0);
    pSrcA += iSrcAStride;
    pSrcB += iSrcBStride;
    src0 = __lsx_vavgr_bu(src0, src1);
    src2 = __lsx_vldrepl_d(pSrcA, 0);
    src3 = __lsx_vldrepl_d(pSrcB, 0);
    pSrcA += iSrcAStride;
    pSrcB += iSrcBStride;
    src2 = __lsx_vavgr_bu(src2, src3);
    __lsx_vstelm_d(src0, pDst, 0, 0);
    pDst  += iDstStride;
    __lsx_vstelm_d(src2, pDst, 0, 0);
    pDst  += iDstStride;
  }
}

void PixelAvgWidthEq16_lsx(uint8_t *pDst, int32_t iDstStride, const uint8_t *pSrcA,
                           int32_t iSrcAStride, const uint8_t *pSrcB, int32_t iSrcBStride,
                           int32_t iHeight ) {
  int32_t i;
  __m128i src0, src1, src2, src3;
  __m128i src4, src5, src6, src7;
  for (i = 0; i < iHeight; i += 4) {
    src0 = __lsx_vld(pSrcA, 0);
    src1 = __lsx_vld(pSrcB, 0);
    pSrcA += iSrcAStride;
    pSrcB += iSrcBStride;
    src0 = __lsx_vavgr_bu(src0, src1);
    src2 = __lsx_vld(pSrcA, 0);
    src3 = __lsx_vld(pSrcB, 0);
    pSrcA += iSrcAStride;
    pSrcB += iSrcBStride;
    src2 = __lsx_vavgr_bu(src2, src3);
    src4 = __lsx_vld(pSrcA, 0);
    src5 = __lsx_vld(pSrcB, 0);
    pSrcA += iSrcAStride;
    pSrcB += iSrcBStride;
    src4 = __lsx_vavgr_bu(src4, src5);
    src6 = __lsx_vld(pSrcA, 0);
    src7 = __lsx_vld(pSrcB, 0);
    pSrcA += iSrcAStride;
    pSrcB += iSrcBStride;
    src6 = __lsx_vavgr_bu(src6, src7);
    __lsx_vst(src0, pDst, 0);
    pDst  += iDstStride;
    __lsx_vst(src2, pDst, 0);
    pDst += iDstStride;
    __lsx_vst(src4, pDst, 0);
    pDst += iDstStride;
    __lsx_vst(src6, pDst, 0);
    pDst += iDstStride;
  }
}

void McHorVer02WidthEq8_lsx(const uint8_t *pSrc, int32_t iSrcStride, uint8_t *pDst,
                            int32_t iDstStride, int32_t iHeight) {
  int32_t iStride1 = iSrcStride;
  int32_t iStride2 = iSrcStride << 1;
  int32_t iStride3 = iStride1 + iStride2;
  uint8_t *psrc = (uint8_t*)pSrc;
  __m128i src0, src1, src2, src3, src4, src5;
  for (int i = 0; i < iHeight; i++) {
    DUP4_ARG2(__lsx_vldx,
              psrc, -iStride2,
              psrc, -iStride1,
              psrc, iStride1,
              psrc, iStride2,
              src0, src1, src3, src4);
    src2 = __lsx_vld(psrc, 0);
    src5 = __lsx_vldx(psrc, iStride3);
    DUP4_ARG2(__lsx_vsllwil_hu_bu,
              src0, 0,
              src1, 0,
              src2, 0,
              src3, 0,
              src0, src1, src2, src3);
    src4 = __lsx_vsllwil_hu_bu(src4, 0);
    src5 = __lsx_vsllwil_hu_bu(src5, 0);
    FILTER_INPUT_8BIT(src0, src1, src2, src3 ,src4, src5 ,src0);
    src0 = __lsx_vsrari_h(src0, 5);
    src0 = __lsx_vclip255_h(src0);
    src0 = __lsx_vpickev_b(src0, src0);
    __lsx_vstelm_d(src0, pDst, 0, 0);
    pDst += iDstStride;
    psrc += iSrcStride;
  }
}

void McHorVer02WidthEq16_lsx(const uint8_t *pSrc, int32_t iSrcStride, uint8_t *pDst,
                             int32_t iDstStride, int32_t iHeight) {
  int32_t iStride1 = iSrcStride;
  int32_t iStride2 = iSrcStride << 1;
  int32_t iStride3 = iStride1 + iStride2;
  uint8_t *psrc = (uint8_t*)pSrc;
  __m128i src0, src1, src2, src3, src4, src5;
  __m128i tmp0, tmp1, tmp2, tmp3, tmp4, tmp5, out0_l, out0_h;
  for (int i = 0; i < iHeight; i++) {
    DUP4_ARG2(__lsx_vldx,
              psrc, -iStride2,
              psrc, -iStride1,
              psrc, iStride1,
              psrc, iStride2,
              src0, src1, src3, src4);
    src2 = __lsx_vld(psrc, 0);
    src5 = __lsx_vldx(psrc, iStride3);
    //l part
    DUP4_ARG2(__lsx_vsllwil_hu_bu,
              src0, 0,
              src1, 0,
              src2, 0,
              src3, 0,
              tmp0, tmp1, tmp2, tmp3);
    tmp4 = __lsx_vsllwil_hu_bu(src4, 0);
    tmp5 = __lsx_vsllwil_hu_bu(src5, 0);
    FILTER_INPUT_8BIT(tmp0, tmp1, tmp2, tmp3, tmp4, tmp5, out0_l);
    out0_l = __lsx_vsrari_h(out0_l, 5);
    out0_l = __lsx_vclip255_h(out0_l);
    //h part
    DUP4_ARG1(__lsx_vexth_hu_bu,
              src0,
              src1,
              src2,
              src3,
              tmp0, tmp1, tmp2, tmp3);
    tmp4 = __lsx_vexth_hu_bu(src4);
    tmp5 = __lsx_vexth_hu_bu(src5);
    FILTER_INPUT_8BIT(tmp0, tmp1, tmp2, tmp3, tmp4, tmp5, out0_h);
    out0_h = __lsx_vsrari_h(out0_h, 5);
    out0_h = __lsx_vclip255_h(out0_h);
    out0_l = __lsx_vpickev_b(out0_h, out0_l);
    __lsx_vst(out0_l, pDst, 0);
    pDst += iDstStride;
    psrc += iSrcStride;
  }
}

void McHorVer20WidthEq4_lsx(const uint8_t *pSrc, int32_t iSrcStride, uint8_t *pDst,
                            int32_t iDstStride, int32_t iHeight) {
  uint8_t *psrc = (uint8_t*)pSrc -2;
  __m128i src0, src1, src2, src3, src4, src5;
  for (int i = 0; i < iHeight; i++) {
    src0 = __lsx_vld(psrc, 0);
    DUP4_ARG2(__lsx_vbsrl_v,
              src0, 1,
              src0, 2,
              src0, 3,
              src0, 4,
              src1, src2, src3, src4);
    src5 = __lsx_vbsrl_v(src0, 5);
    DUP4_ARG2(__lsx_vsllwil_hu_bu,
              src0, 0,
              src1, 0,
              src2, 0,
              src3, 0,
              src0, src1, src2, src3);
    src4 = __lsx_vsllwil_hu_bu(src4, 0);
    src5 = __lsx_vsllwil_hu_bu(src5, 0);
    FILTER_INPUT_8BIT(src0, src1, src2, src3 ,src4, src5 ,src0);
    src0 = __lsx_vsrari_h(src0, 5);
    src0 = __lsx_vclip255_h(src0);
    src0 = __lsx_vpickev_b(src0, src0);
    __lsx_vstelm_w(src0, pDst, 0, 0);
    pDst += iDstStride;
    psrc += iSrcStride;
  }
}

void McHorVer20WidthEq5_lsx(const uint8_t *pSrc, int32_t iSrcStride, uint8_t *pDst,
                            int32_t iDstStride, int32_t iHeight) {
  uint8_t *psrc = (uint8_t*)pSrc -2;
  __m128i src0, src1, src2, src3, src4, src5;
  for (int i = 0; i < iHeight; i++) {
    src0 = __lsx_vld(psrc, 0);
    DUP4_ARG2(__lsx_vbsrl_v,
              src0, 1,
              src0, 2,
              src0, 3,
              src0, 4,
              src1, src2, src3, src4);
    src5 = __lsx_vbsrl_v(src0, 5);
    DUP4_ARG2(__lsx_vsllwil_hu_bu,
              src0, 0,
              src1, 0,
              src2, 0,
              src3, 0,
              src0, src1, src2, src3);
    src4 = __lsx_vsllwil_hu_bu(src4, 0);
    src5 = __lsx_vsllwil_hu_bu(src5, 0);
    FILTER_INPUT_8BIT(src0, src1, src2, src3 ,src4, src5 ,src0);
    src0 = __lsx_vsrari_h(src0, 5);
    src0 = __lsx_vclip255_h(src0);
    src0 = __lsx_vpickev_b(src0, src0);
    __lsx_vstelm_w(src0, pDst, 0, 0);
    __lsx_vstelm_b(src0, pDst, 4, 4);
    pDst += iDstStride;
    psrc += iSrcStride;
  }
}

void McHorVer20WidthEq8_lsx(const uint8_t *pSrc, int32_t iSrcStride, uint8_t *pDst,
                            int32_t iDstStride, int32_t iHeight) {
  uint8_t *psrc = (uint8_t*)pSrc -2;
  __m128i src0, src1, src2, src3, src4, src5;
  for (int i = 0; i < iHeight; i++) {
    src0 = __lsx_vld(psrc, 0);
    DUP4_ARG2(__lsx_vbsrl_v,
              src0, 1,
              src0, 2,
              src0, 3,
              src0, 4,
              src1, src2, src3, src4);
    src5 = __lsx_vbsrl_v(src0, 5);
    DUP4_ARG2(__lsx_vsllwil_hu_bu,
              src0, 0,
              src1, 0,
              src2, 0,
              src3, 0,
              src0, src1, src2, src3);
    src4 = __lsx_vsllwil_hu_bu(src4, 0);
    src5 = __lsx_vsllwil_hu_bu(src5, 0);
    FILTER_INPUT_8BIT(src0, src1, src2, src3 ,src4, src5 ,src0);
    src0 = __lsx_vsrari_h(src0, 5);
    src0 = __lsx_vclip255_h(src0);
    src0 = __lsx_vpickev_b(src0, src0);
    __lsx_vstelm_d(src0, pDst, 0, 0);
    pDst += iDstStride;
    psrc += iSrcStride;
  }
}

void McHorVer20WidthEq9_lsx(const uint8_t *pSrc, int32_t iSrcStride, uint8_t *pDst,
                            int32_t iDstStride, int32_t iHeight) {
  McHorVer20WidthEq4_lsx(pSrc, iSrcStride, pDst, iDstStride, iHeight);
  McHorVer20WidthEq5_lsx(&pSrc[4], iSrcStride, &pDst[4], iDstStride, iHeight);
}

void McHorVer20WidthEq16_lsx(const uint8_t *pSrc, int32_t iSrcStride, uint8_t *pDst,
                             int32_t iDstStride, int32_t iHeight) {
  uint8_t *psrc = (uint8_t*)pSrc - 2;
  __m128i src0, src1, src2, src3, src4, src5;
  __m128i tmp0, tmp1, tmp2 ,tmp3 ,tmp4, tmp5, out0_l, out0_h;
  for (int i = 0; i < iHeight; i++) {
    DUP4_ARG2(__lsx_vld,
              psrc,  0,
              psrc + 1, 0,
              psrc + 2, 0,
              psrc + 3, 0,
              src0, src1, src2, src3);
    src4 = __lsx_vld(psrc + 4, 0);
    src5 = __lsx_vld(psrc + 5, 0);
    //l part
    DUP4_ARG2(__lsx_vsllwil_hu_bu,
              src0, 0,
              src1, 0,
              src2, 0,
              src3, 0,
              tmp0, tmp1, tmp2, tmp3);
    tmp4 = __lsx_vsllwil_hu_bu(src4, 0);
    tmp5 = __lsx_vsllwil_hu_bu(src5, 0);
    FILTER_INPUT_8BIT(tmp0, tmp1, tmp2, tmp3, tmp4, tmp5, out0_l);
    out0_l = __lsx_vsrari_h(out0_l, 5);
    out0_l = __lsx_vclip255_h(out0_l);
    //h part
    DUP4_ARG1(__lsx_vexth_hu_bu,
              src0,
              src1,
              src2,
              src3,
              tmp0, tmp1, tmp2, tmp3);
    tmp4 = __lsx_vexth_hu_bu(src4);
    tmp5 = __lsx_vexth_hu_bu(src5);
    FILTER_INPUT_8BIT(tmp0, tmp1, tmp2, tmp3, tmp4, tmp5, out0_h);
    out0_h = __lsx_vsrari_h(out0_h, 5);
    out0_h = __lsx_vclip255_h(out0_h);
    out0_l = __lsx_vpickev_b(out0_h, out0_l);
    __lsx_vst(out0_l, pDst, 0);
    pDst += iDstStride;
    psrc += iSrcStride;
  }
}

void McHorVer20WidthEq17_lsx(const uint8_t *pSrc, int32_t iSrcStride, uint8_t *pDst,
                             int32_t iDstStride, int32_t iHeight) {
  McHorVer20WidthEq8_lsx(pSrc, iSrcStride, pDst, iDstStride, iHeight);
  McHorVer20WidthEq9_lsx(&pSrc[8], iSrcStride, &pDst[8], iDstStride, iHeight);
}

void McHorVer22WidthEq8_lsx(const uint8_t *pSrc, int32_t iSrcStride, uint8_t *pDst,
                            int32_t iDstStride, int32_t iHeight) {
  int32_t iStride1 = iSrcStride;
  int32_t iStride2 = iSrcStride << 1;
  int32_t iStride3 = iStride1 + iStride2;
  uint8_t *psrc = (uint8_t*)pSrc - 2;
  __m128i src0, src1, src2, src3, src4, src5;
  __m128i tmp0, tmp1, tmp2, tmp3, tmp4, tmp5, out0_l, out0_h;
  __m128i dst0, dst1, dst2, dst3, dst4, dst5, dst6, dst7;
  v8i16 mask1 = {3, 4, 5, 6, 7, 8, 9, 10};
  v8i16 mask2 = {6, 7, 8, 9, 10, 11, 12 ,13};
  for (int i = 0; i < iHeight; i++) {
    DUP4_ARG2(__lsx_vldx,
              psrc, -iStride2,
              psrc, -iStride1,
              psrc, iStride1,
              psrc, iStride2,
              src0, src1, src3, src4);
    src2 = __lsx_vld(psrc, 0);
    src5 = __lsx_vldx(psrc, iStride3);
    //l part
    DUP4_ARG2(__lsx_vsllwil_hu_bu,
              src0, 0,
              src1, 0,
              src2, 0,
              src3, 0,
              tmp0, tmp1, tmp2, tmp3);
    tmp4 = __lsx_vsllwil_hu_bu(src4, 0);
    tmp5 = __lsx_vsllwil_hu_bu(src5, 0);
    FILTER_INPUT_8BIT(tmp0, tmp1 ,tmp2, tmp3, tmp4, tmp5, out0_l);
    //h part
    DUP4_ARG1(__lsx_vexth_hu_bu,
              src0,
              src1,
              src2,
              src3,
              tmp0, tmp1, tmp2, tmp3);
    tmp4 = __lsx_vexth_hu_bu(src4);
    tmp5 = __lsx_vexth_hu_bu(src5);
    FILTER_INPUT_8BIT(tmp0, tmp1 ,tmp2, tmp3, tmp4, tmp5, out0_h);
    dst0 = out0_l;
    dst1 = __lsx_vbsrl_v(out0_l, 2);
    dst2 = __lsx_vbsrl_v(out0_l, 4);
    dst3 = __lsx_vshuf_h((__m128i)mask1, out0_h, out0_l);
    dst4 = __lsx_vbsrl_v(dst3, 2);
    dst5 = __lsx_vbsrl_v(dst3, 4);
    dst6 = __lsx_vshuf_h((__m128i)mask2, out0_h, out0_l);
    dst7 = __lsx_vbsrl_v(dst6, 2);
    LSX_TRANSPOSE8x8_H(dst0, dst1, dst2, dst3, dst4, dst5, dst6, dst7,
                       dst0, dst1, dst2, dst3, dst4, dst5, dst6, dst7);
    //l part
    DUP4_ARG2(__lsx_vsllwil_w_h,
              dst0, 0,
              dst1, 0,
              dst2, 0,
              dst3, 0,
              tmp0, tmp1, tmp2, tmp3);
    DUP2_ARG2(__lsx_vsllwil_w_h,
              dst4, 0,
              dst5, 0,
              tmp4, tmp5);
    HOR_FILTER_INPUT_16BIT(tmp0, tmp1, tmp2, tmp3, tmp4, tmp5, out0_l);
    //h part
    DUP4_ARG1(__lsx_vexth_w_h,
              dst0,
              dst1,
              dst2,
              dst3,
              tmp0, tmp1, tmp2, tmp3);
    DUP2_ARG1(__lsx_vexth_w_h,
              dst4,
              dst5,
              tmp4, tmp5);
    HOR_FILTER_INPUT_16BIT(tmp0, tmp1, tmp2, tmp3, tmp4, tmp5, out0_h);
    out0_l = __lsx_vsrari_w(out0_l, 10);
    out0_h = __lsx_vsrari_w(out0_h, 10);
    DUP2_ARG1(__lsx_vclip255_w,
              out0_l, out0_h,
              out0_l, out0_h);
    out0_l = __lsx_vpickev_h(out0_h, out0_l);
    out0_l = __lsx_vpickev_b(out0_l, out0_l);
    __lsx_vstelm_d(out0_l, pDst, 0, 0);
    psrc += iSrcStride;
    pDst += iDstStride;
  }
}

static
void McHorVer22WidthEq4_lsx(const uint8_t *pSrc, int32_t iSrcStride, uint8_t *pDst,
                            int32_t iDstStride, int32_t iHeight) {
  int32_t iStride1 = iSrcStride;
  int32_t iStride2 = iSrcStride << 1;
  int32_t iStride3 = iStride1 + iStride2;
  uint8_t *psrc = (uint8_t*)pSrc - 2;
  __m128i src0, src1, src2, src3, src4, src5;
  __m128i tmp0, tmp1, tmp2, tmp3, tmp4, tmp5, out0_l, out0_h;
  __m128i dst0, dst1, dst2, dst3, dst4, dst5, dst6, dst7;
  v8i16 mask1 = {3, 4, 5, 6, 7, 8, 9, 10};
  for (int i = 0; i < iHeight; i++) {
    DUP4_ARG2(__lsx_vldx,
              psrc, -iStride2,
              psrc, -iStride1,
              psrc, iStride1,
              psrc, iStride2,
              src0, src1, src3, src4);
    src2 = __lsx_vld(psrc, 0);
    src5 = __lsx_vldx(psrc, iStride3);
    //l part
    DUP4_ARG2(__lsx_vsllwil_hu_bu,
              src0, 0,
              src1, 0,
              src2, 0,
              src3, 0,
              tmp0, tmp1, tmp2, tmp3);
    tmp4 = __lsx_vsllwil_hu_bu(src4, 0);
    tmp5 = __lsx_vsllwil_hu_bu(src5, 0);
    FILTER_INPUT_8BIT(tmp0, tmp1 ,tmp2, tmp3, tmp4, tmp5, out0_l);
    //h part
    DUP4_ARG1(__lsx_vexth_hu_bu,
              src0,
              src1,
              src2,
              src3,
              tmp0, tmp1, tmp2, tmp3);
    tmp4 = __lsx_vexth_hu_bu(src4);
    tmp5 = __lsx_vexth_hu_bu(src5);
    FILTER_INPUT_8BIT(tmp0, tmp1 ,tmp2, tmp3, tmp4, tmp5, out0_h);
    dst0 = out0_l;
    dst1 = __lsx_vbsrl_v(out0_l, 2);
    dst2 = __lsx_vbsrl_v(out0_l, 4);
    dst3 = __lsx_vshuf_h((__m128i)mask1, out0_h, out0_l);
    LSX_TRANSPOSE8x8_H(dst0, dst1, dst2, dst3, dst4, dst5, dst6, dst7,
                       dst0, dst1, dst2, dst3, dst4, dst5, dst6, dst7);
    //l part
    DUP4_ARG2(__lsx_vsllwil_w_h,
              dst0, 0,
              dst1, 0,
              dst2, 0,
              dst3, 0,
              tmp0, tmp1, tmp2, tmp3);
    DUP2_ARG2(__lsx_vsllwil_w_h,
              dst4, 0,
              dst5, 0,
              tmp4, tmp5);
    HOR_FILTER_INPUT_16BIT(tmp0, tmp1, tmp2, tmp3, tmp4, tmp5, out0_l);
    //h part
    DUP4_ARG1(__lsx_vexth_w_h,
              dst0,
              dst1,
              dst2,
              dst3,
              tmp0, tmp1, tmp2, tmp3);
    DUP2_ARG1(__lsx_vexth_w_h,
              dst4,
              dst5,
              tmp4, tmp5);
    HOR_FILTER_INPUT_16BIT(tmp0, tmp1, tmp2, tmp3, tmp4, tmp5, out0_h);
    out0_l = __lsx_vsrari_w(out0_l, 10);
    out0_h = __lsx_vsrari_w(out0_h, 10);
    DUP2_ARG1(__lsx_vclip255_w,
              out0_l, out0_h,
              out0_l, out0_h);
    out0_l = __lsx_vpickev_h(out0_h, out0_l);
    out0_l = __lsx_vpickev_b(out0_l, out0_l);
    __lsx_vstelm_w(out0_l, pDst, 0, 0);
    psrc += iSrcStride;
    pDst += iDstStride;
  }
}

void McHorVer22WidthEq5_lsx(const uint8_t *pSrc, int32_t iSrcStride, uint8_t *pDst,
                            int32_t iDstStride, int32_t iHeight) {
  int32_t iStride1 = iSrcStride;
  int32_t iStride2 = iSrcStride << 1;
  int32_t iStride3 = iStride1 + iStride2;
  uint8_t *psrc = (uint8_t*)pSrc - 2;
  __m128i src0, src1, src2, src3, src4, src5;
  __m128i tmp0, tmp1, tmp2, tmp3, tmp4, tmp5, out0_l, out0_h;
  __m128i dst0, dst1, dst2, dst3, dst4, dst5, dst6, dst7;
  v8i16 mask1 = {3, 4, 5, 6, 7, 8, 9, 10};
  for (int i = 0; i < iHeight; i++) {
    DUP4_ARG2(__lsx_vldx,
              psrc, -iStride2,
              psrc, -iStride1,
              psrc, iStride1,
              psrc, iStride2,
              src0, src1, src3, src4);
    src2 = __lsx_vld(psrc, 0);
    src5 = __lsx_vldx(psrc, iStride3);
    //l part
    DUP4_ARG2(__lsx_vsllwil_hu_bu,
              src0, 0,
              src1, 0,
              src2, 0,
              src3, 0,
              tmp0, tmp1, tmp2, tmp3);
    tmp4 = __lsx_vsllwil_hu_bu(src4, 0);
    tmp5 = __lsx_vsllwil_hu_bu(src5, 0);
    FILTER_INPUT_8BIT(tmp0, tmp1 ,tmp2, tmp3, tmp4, tmp5, out0_l);
    //h part
    DUP4_ARG1(__lsx_vexth_hu_bu,
              src0,
              src1,
              src2,
              src3,
              tmp0, tmp1, tmp2, tmp3);
    tmp4 = __lsx_vexth_hu_bu(src4);
    tmp5 = __lsx_vexth_hu_bu(src5);
    FILTER_INPUT_8BIT(tmp0, tmp1 ,tmp2, tmp3, tmp4, tmp5, out0_h);
    dst0 = out0_l;
    dst1 = __lsx_vbsrl_v(out0_l, 2);
    dst2 = __lsx_vbsrl_v(out0_l, 4);
    dst3 = __lsx_vshuf_h((__m128i)mask1, out0_h, out0_l);
    dst4 = __lsx_vbsrl_v(dst3, 2);
    LSX_TRANSPOSE8x8_H(dst0, dst1, dst2, dst3, dst4, dst5, dst6, dst7,
                       dst0, dst1, dst2, dst3, dst4, dst5, dst6, dst7);
    //l part
    DUP4_ARG2(__lsx_vsllwil_w_h,
              dst0, 0,
              dst1, 0,
              dst2, 0,
              dst3, 0,
              tmp0, tmp1, tmp2, tmp3);
    DUP2_ARG2(__lsx_vsllwil_w_h,
              dst4, 0,
              dst5, 0,
              tmp4, tmp5);
    HOR_FILTER_INPUT_16BIT(tmp0, tmp1, tmp2, tmp3, tmp4, tmp5, out0_l);
    //h part
    DUP4_ARG1(__lsx_vexth_w_h,
              dst0,
              dst1,
              dst2,
              dst3,
              tmp0, tmp1, tmp2, tmp3);
    DUP2_ARG1(__lsx_vexth_w_h,
              dst4,
              dst5,
              tmp4, tmp5);
    HOR_FILTER_INPUT_16BIT(tmp0, tmp1, tmp2, tmp3, tmp4, tmp5, out0_h);
    out0_l = __lsx_vsrari_w(out0_l, 10);
    out0_h = __lsx_vsrari_w(out0_h, 10);
    DUP2_ARG1(__lsx_vclip255_w,
              out0_l, out0_h,
              out0_l, out0_h);
    out0_l = __lsx_vpickev_h(out0_h, out0_l);
    out0_l = __lsx_vpickev_b(out0_l, out0_l);
    __lsx_vstelm_w(out0_l, pDst, 0, 0);
    __lsx_vstelm_b(out0_l, pDst, 4, 4);
    psrc += iSrcStride;
    pDst += iDstStride;
  }
}

void McHorVer22WidthEq9_lsx(const uint8_t *pSrc, int32_t iSrcStride, uint8_t *pDst,
                            int32_t iDstStride, int32_t iHeight) {
  McHorVer22WidthEq4_lsx(pSrc, iSrcStride, pDst, iDstStride, iHeight);
  McHorVer22WidthEq5_lsx(&pSrc[4], iSrcStride, &pDst[4], iDstStride, iHeight);
}

void McHorVer22WidthEq17_lsx(const uint8_t *pSrc, int32_t iSrcStride, uint8_t *pDst,
                             int32_t iDstStride, int32_t iHeight) {
  McHorVer22WidthEq8_lsx(pSrc, iSrcStride, pDst, iDstStride, iHeight);
  McHorVer22WidthEq9_lsx(&pSrc[8], iSrcStride, &pDst[8], iDstStride, iHeight);
}
