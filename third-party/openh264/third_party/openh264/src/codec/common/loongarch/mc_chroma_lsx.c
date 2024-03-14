/*!
 **********************************************************************************
 * Copyright (c) 2021 Loongson Technology Corporation Limited
 * Contributed by Lu Wang <wanglu@loongson.cn>
 *
 * \copy
 *     Copyright (c)  2013, Cisco Systems
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
 * \file    mc_chroma_lsx.c
 *
 * \brief   Loongson optimization
 *
 * \date    12/23/2021 Created
 *
 **********************************************************************************
 */

#include "stdint.h"
#include "loongson_intrinsics.h"

void McCopyWidthEq4_lsx(const uint8_t *pSrc, int iSrcStride,
                         uint8_t *pDst, int iDstStride, int iHeight) {
  __m128i src0, src1;
  int iSrcStride_x2 = iSrcStride << 1;
  int iDstStride_x2 = iDstStride << 1;
  iHeight = iHeight >> 1;
  for (int i = 0; i < iHeight; i++) {
    DUP2_ARG2(__lsx_vld, pSrc, 0, pSrc + iSrcStride, 0, src0, src1);
    __lsx_vstelm_w(src0, pDst, 0, 0);
    __lsx_vstelm_w(src1, pDst + iDstStride, 0, 0);
    pSrc += iSrcStride_x2;
    pDst += iDstStride_x2;
  }
}

void McCopyWidthEq8_lsx(const uint8_t *pSrc, int iSrcStride,
                        uint8_t *pDst, int iDstStride, int iHeight) {
  __m128i src0, src1;
  int iSrcStride_x2 = iSrcStride << 1;
  int iDstStride_x2 = iDstStride << 1;
  iHeight = iHeight >> 1;
  for (int i = 0; i < iHeight; i++) {
    DUP2_ARG2(__lsx_vld, pSrc, 0, pSrc + iSrcStride, 0, src0, src1);
    __lsx_vstelm_d(src0, pDst, 0, 0);
    __lsx_vstelm_d(src1, pDst + iDstStride, 0, 0);
    pSrc += iSrcStride_x2;
    pDst += iDstStride_x2;
  }
}

void McCopyWidthEq16_lsx(const uint8_t *pSrc, int iSrcStride,
                         uint8_t *pDst, int iDstStride, int iHeight) {
  __m128i src0, src1;
  int iSrcStride_x2 = iSrcStride << 1;
  int iDstStride_x2 = iDstStride << 1;
  iHeight = iHeight >> 1;
  for (int i = 0; i < iHeight; i++) {
    DUP2_ARG2(__lsx_vld, pSrc, 0, pSrc + iSrcStride, 0, src0, src1);
    __lsx_vst(src0, pDst, 0);
    __lsx_vstx(src1, pDst, iDstStride);
    pSrc += iSrcStride_x2;
    pDst += iDstStride_x2;
  }
}

void McChromaWidthEq4_lsx(const uint8_t *pSrc, int32_t iSrcStride, uint8_t *pDst,
                          int32_t iDstStride, const uint8_t *pABCD, int32_t iHeight) {
  int32_t i;
  int8_t iA, iB, iC, iD;
  uint16_t iFillData;
  int32_t iSrcStride_x2 = iSrcStride << 1;
  int32_t iDstStride_x2 = iDstStride << 1;
  __m128i paramAB, paramCD, paramConst;
  __m128i src0, src1, src2, src0Even, src1Even, src2Even;
  __m128i out0, outNext0, out1, outNext1;
  __m128i shift;

  iA = pABCD[0];
  iB = pABCD[1];
  iC = pABCD[2];
  iD = pABCD[3];

  iFillData = (iB << 8) | iA;
  paramAB = __lsx_vreplgr2vr_h(iFillData);
  iFillData = (iD << 8) | iC;
  paramCD = __lsx_vreplgr2vr_h(iFillData);
  paramConst = __lsx_vreplgr2vr_h(32);
  shift = __lsx_vreplgr2vr_h(6);
  iHeight = iHeight >> 1;

  for (i = 0; i < iHeight; i++) {
    DUP2_ARG2(__lsx_vld, pSrc, 0, pSrc + iSrcStride, 0, src0, src1);
    src2 = __lsx_vld(pSrc + iSrcStride_x2, 0);
    pSrc += 1;
    DUP2_ARG2(__lsx_vld, pSrc, 0, pSrc + iSrcStride, 0, src0Even, src1Even);
    src2Even = __lsx_vld(pSrc + iSrcStride_x2, 0);
    pSrc -= 1;

    DUP2_ARG2(__lsx_vilvl_w, src0Even, src0, src1Even, src1, src0, src1);
    src2 = __lsx_vilvl_w(src2Even, src2);
    DUP4_ARG2(__lsx_vdp2_h_bu, src0, paramAB, src1, paramCD, src1, paramAB, src2,
              paramCD, out0, outNext0, out1, outNext1);
    DUP4_ARG2(__lsx_vadd_h, out0, outNext0, out0, paramConst, out1, outNext1, out1,
              paramConst, out0, out0, out1, out1);
    DUP2_ARG2(__lsx_vsrl_h, out0, shift, out1, shift, out0, out1);
    DUP2_ARG2(__lsx_vsrl_d, out0, paramConst, out1, paramConst, outNext0, outNext1);
    DUP2_ARG2(__lsx_vpackev_b, outNext0, out0, outNext1, out1, out0, out1);
    __lsx_vstelm_w(out0, pDst, 0, 0);
    __lsx_vstelm_w(out1, pDst + iDstStride, 0, 0);

    pDst += iDstStride_x2;
    pSrc += iSrcStride_x2;
  }
}

void McChromaWidthEq8_lsx(const uint8_t *pSrc, int32_t iSrcStride, uint8_t *pDst,
                          int32_t iDstStride, const uint8_t *pABCD, int32_t iHeight) {
  int32_t i;
  int8_t iA, iB, iC, iD;
  uint16_t iFillData;
  int32_t iSrcStride_x2 = iSrcStride << 1;
  int32_t iDstStride_x2 = iDstStride << 1;
  __m128i paramAB, paramCD, paramConst;
  __m128i src0, src1, src2, src0Even, src1Even, src2Even;
  __m128i out0, outNext0, out1, outNext1;
  __m128i shift;

  iA = pABCD[0];
  iB = pABCD[1];
  iC = pABCD[2];
  iD = pABCD[3];

  iFillData = (iB << 8) | iA;
  paramAB = __lsx_vreplgr2vr_h(iFillData);
  iFillData = (iD << 8) | iC;
  paramCD = __lsx_vreplgr2vr_h(iFillData);
  paramConst = __lsx_vreplgr2vr_h(32);
  shift = __lsx_vreplgr2vr_h(6);
  iHeight = iHeight >> 1;

  for (i = 0; i < iHeight; i++) {
    DUP2_ARG2(__lsx_vld, pSrc, 0, pSrc + iSrcStride, 0, src0, src1);
    src2 = __lsx_vld(pSrc + iSrcStride_x2, 0);
    pSrc += 1;
    DUP2_ARG2(__lsx_vld, pSrc, 0, pSrc + iSrcStride, 0, src0Even, src1Even);
    src2Even = __lsx_vld(pSrc + iSrcStride_x2, 0);
    pSrc -= 1;

    DUP2_ARG2(__lsx_vilvl_d, src0Even, src0, src1Even, src1, src0, src1);
    src2 = __lsx_vilvl_d(src2Even, src2);
    DUP4_ARG2(__lsx_vdp2_h_bu, src0, paramAB, src1, paramCD, src1, paramAB, src2,
              paramCD, out0, outNext0, out1, outNext1);
    DUP4_ARG2(__lsx_vadd_h, out0, outNext0, out0, paramConst, out1, outNext1, out1,
              paramConst, out0, out0, out1, out1);
    DUP2_ARG2(__lsx_vsrl_h, out0, shift, out1, shift, out0, out1);

    DUP2_ARG2(__lsx_vilvh_d, out0, out0, out1, out1, outNext0, outNext1);
    DUP2_ARG2(__lsx_vpackev_b, outNext0, out0, outNext1, out1, out0, out1);

    __lsx_vstelm_d(out0, pDst, 0, 0);
    __lsx_vstelm_d(out1, pDst + iDstStride, 0, 0);

    pDst += iDstStride_x2;
    pSrc += iSrcStride_x2;
  }
}
