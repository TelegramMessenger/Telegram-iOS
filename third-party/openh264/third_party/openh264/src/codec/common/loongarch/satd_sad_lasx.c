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
 * \file    satd_sad_lasx.c
 *
 * \brief   Loongson optimization
 *
 * \date    12/10/2021 Created
 *
 *************************************************************************************
 */

#include <stdint.h>
#include "loongson_intrinsics.h"

#define HORISUM(in0, in1, out0)            \
  out0 = __lasx_xvabsd_bu(in0, in1);       \
  out0 = __lasx_xvhaddw_hu_bu(out0, out0); \
  out0 = __lasx_xvhaddw_wu_hu(out0, out0); \
  out0 = __lasx_xvhaddw_du_wu(out0, out0); \

int32_t WelsSampleSad4x4_lasx (uint8_t* pSample1, int32_t iStride1,
                               uint8_t* pSample2, int32_t iStride2) {
  uint8_t *pSrc1 = pSample1;
  uint8_t *pSrc2 = pSample2;
  int32_t iStride0 = 0;
  int32_t iStride1_tmp = iStride1 << 1;
  int32_t iStride2_tmp = iStride2 << 1;

  __m256i src1_0, src1_1, src1_2, src1_3;
  __m256i src2_0, src2_1, src2_2, src2_3;

  DUP4_ARG2(__lasx_xvldx,
            pSrc1, iStride0,
            pSrc1, iStride1,
            pSrc1, iStride1_tmp,
            pSrc1, iStride1_tmp + iStride1,
            src1_0, src1_1, src1_2, src1_3);
  DUP4_ARG2(__lasx_xvldx,
            pSrc2, iStride0,
            pSrc2, iStride2,
            pSrc2, iStride2_tmp,
            pSrc2, iStride2_tmp + iStride2,
            src2_0, src2_1, src2_2, src2_3);

  DUP2_ARG2(__lasx_xvpackev_w,
            src1_0, src1_1, src1_2, src1_3,
            src1_0, src1_2);
  DUP2_ARG2(__lasx_xvpackev_w,
            src2_0, src2_1, src2_2, src2_3,
            src2_0, src2_2);
  DUP2_ARG2(__lasx_xvpackev_d,
            src1_0, src1_2, src2_0, src2_2,
            src1_0, src2_0);

  HORISUM(src1_0, src2_0, src1_0);

  src1_0 = __lasx_xvhaddw_qu_du(src1_0, src1_0);

  return __lasx_xvpickve2gr_d(src1_0, 0);
}

static inline
int32_t WelsSampleSad8x8x2_lasx (uint8_t* pSample1, int32_t iStride1,
                                 uint8_t* pSample2, int32_t iStride2) {
  uint8_t* pSrc1 = pSample1;
  uint8_t* pSrc2 = pSample2;
  int32_t iStride0 = 0;
  int32_t iStride1_tmp2 = iStride1 << 1;
  int32_t iStride1_tmp3 = iStride1_tmp2 + iStride1;
  int32_t iStride1_tmp4 = iStride1 << 2;
  int32_t iStride1_tmp5 = iStride1_tmp4 + iStride1;
  int32_t iStride1_tmp6 = iStride1_tmp5 + iStride1;
  int32_t iStride1_tmp7 = iStride1_tmp6 + iStride1;
  int32_t iStride2_tmp2 = iStride2 << 1;
  int32_t iStride2_tmp3 = iStride2_tmp2 + iStride2;
  int32_t iStride2_tmp4 = iStride2 << 2;
  int32_t iStride2_tmp5 = iStride2_tmp4 + iStride2;
  int32_t iStride2_tmp6 = iStride2_tmp5 + iStride2;
  int32_t iStride2_tmp7 = iStride2_tmp6 + iStride2;

  __m256i src1_0, src1_1, src1_2, src1_3,
          src1_4, src1_5, src1_6, src1_7;
  __m256i src2_0, src2_1, src2_2, src2_3,
          src2_4, src2_5, src2_6, src2_7;
  DUP4_ARG2(__lasx_xvldx,
            pSrc1, iStride0,
            pSrc1, iStride1,
            pSrc1, iStride1_tmp2,
            pSrc1, iStride1_tmp3,
            src1_0, src1_1, src1_2, src1_3);
  DUP4_ARG2(__lasx_xvldx,
            pSrc1, iStride1_tmp4,
            pSrc1, iStride1_tmp5,
            pSrc1, iStride1_tmp6,
            pSrc1, iStride1_tmp7,
            src1_4, src1_5, src1_6, src1_7);
  DUP4_ARG2(__lasx_xvldx,
            pSrc2, iStride0,
            pSrc2, iStride2,
            pSrc2, iStride2_tmp2,
            pSrc2, iStride2_tmp3,
            src2_0, src2_1, src2_2, src2_3);
  DUP4_ARG2(__lasx_xvldx,
            pSrc2, iStride2_tmp4,
            pSrc2, iStride2_tmp5,
            pSrc2, iStride2_tmp6,
            pSrc2, iStride2_tmp7,
            src2_4, src2_5, src2_6, src2_7);
  DUP4_ARG3(__lasx_xvpermi_q,
            src1_0, src1_1, 0x20,
            src1_2, src1_3, 0x20,
            src1_4, src1_5, 0x20,
            src1_6, src1_7, 0x20,
            src1_0, src1_2, src1_4, src1_6);
  DUP4_ARG3(__lasx_xvpermi_q,
            src2_0, src2_1, 0x20,
            src2_2, src2_3, 0x20,
            src2_4, src2_5, 0x20,
            src2_6, src2_7, 0x20,
            src2_0, src2_2, src2_4, src2_6);
  src1_0 = __lasx_xvabsd_bu(src1_0, src2_0);
  src1_2 = __lasx_xvabsd_bu(src1_2, src2_2);
  src1_4 = __lasx_xvabsd_bu(src1_4, src2_4);
  src1_6 = __lasx_xvabsd_bu(src1_6, src2_6);
  src1_0 = __lasx_xvhaddw_hu_bu(src1_0, src1_0);
  src1_2 = __lasx_xvhaddw_hu_bu(src1_2, src1_2);
  src1_4 = __lasx_xvhaddw_hu_bu(src1_4, src1_4);
  src1_6 = __lasx_xvhaddw_hu_bu(src1_6, src1_6);
  src1_0 = __lasx_xvadd_h(src1_0, src1_2);
  src1_0 = __lasx_xvadd_h(src1_0, src1_4);
  src1_0 = __lasx_xvadd_h(src1_0, src1_6);
  src1_0 = __lasx_xvhaddw_wu_hu(src1_0, src1_0);
  src1_0 = __lasx_xvhaddw_du_wu(src1_0, src1_0);
  src1_0 = __lasx_xvhaddw_qu_du(src1_0, src1_0);
  return (__lasx_xvpickve2gr_w(src1_0, 0) +
          __lasx_xvpickve2gr_w(src1_0, 4));
}

int32_t WelsSampleSad8x8_lasx (uint8_t* pSample1, int32_t iStride1,
                               uint8_t* pSample2, int32_t iStride2) {
  uint8_t* pSrc1 = pSample1;
  uint8_t* pSrc2 = pSample2;
  int32_t iStride0 = 0;
  int32_t iStride1_tmp2 = iStride1 << 1;
  int32_t iStride1_tmp3 = iStride1_tmp2 + iStride1;
  int32_t iStride1_tmp4 = iStride1 << 2;
  int32_t iStride1_tmp5 = iStride1_tmp4 + iStride1;
  int32_t iStride1_tmp6 = iStride1_tmp5 + iStride1;
  int32_t iStride1_tmp7 = iStride1_tmp6 + iStride1;
  int32_t iStride2_tmp2 = iStride2 << 1;
  int32_t iStride2_tmp3 = iStride2_tmp2 + iStride2;
  int32_t iStride2_tmp4 = iStride2 << 2;
  int32_t iStride2_tmp5 = iStride2_tmp4 + iStride2;
  int32_t iStride2_tmp6 = iStride2_tmp5 + iStride2;
  int32_t iStride2_tmp7 = iStride2_tmp6 + iStride2;

  __m256i src1_0, src1_1, src1_2, src1_3,
          src1_4, src1_5, src1_6, src1_7;
  __m256i src2_0, src2_1, src2_2, src2_3,
          src2_4, src2_5, src2_6, src2_7;

  DUP4_ARG2(__lasx_xvldx,
            pSrc1, iStride0,
            pSrc1, iStride1,
            pSrc1, iStride1_tmp2,
            pSrc1, iStride1_tmp3,
            src1_0, src1_1, src1_2, src1_3);
  DUP4_ARG2(__lasx_xvldx,
            pSrc1, iStride1_tmp4,
            pSrc1, iStride1_tmp5,
            pSrc1, iStride1_tmp6,
            pSrc1, iStride1_tmp7,
            src1_4, src1_5, src1_6, src1_7);
  DUP4_ARG2(__lasx_xvldx,
            pSrc2, iStride0,
            pSrc2, iStride2,
            pSrc2, iStride2_tmp2,
            pSrc2, iStride2_tmp3,
            src2_0, src2_1, src2_2, src2_3);
  DUP4_ARG2(__lasx_xvldx,
            pSrc2, iStride2_tmp4,
            pSrc2, iStride2_tmp5,
            pSrc2, iStride2_tmp6,
            pSrc2, iStride2_tmp7,
            src2_4, src2_5, src2_6, src2_7);

  DUP4_ARG2(__lasx_xvpackev_d,
            src1_0, src1_1, src1_2, src1_3,
            src1_4, src1_5, src1_6, src1_7,
            src1_0, src1_2, src1_4, src1_6);
  DUP2_ARG3(__lasx_xvpermi_q,
            src1_0, src1_2, 0x20,
            src1_4, src1_6, 0x20,
            src1_0, src1_4);
  DUP4_ARG2(__lasx_xvpackev_d,
            src2_0, src2_1, src2_2, src2_3,
            src2_4, src2_5, src2_6, src2_7,
            src2_0, src2_2, src2_4, src2_6);
  DUP2_ARG3(__lasx_xvpermi_q,
            src2_0, src2_2, 0x20,
            src2_4, src2_6, 0x20,
            src2_0, src2_4);

  HORISUM(src1_0, src2_0, src1_0);
  HORISUM(src1_4, src2_4, src1_4);

  src1_0 = __lasx_xvadd_d(src1_0, src1_4);
  src1_0 = __lasx_xvhaddw_qu_du(src1_0, src1_0);

  return (__lasx_xvpickve2gr_d(src1_0, 0) +
          __lasx_xvpickve2gr_d(src1_0, 2));
}

int32_t WelsSampleSatd4x4_lasx (uint8_t* pSample1, int32_t iStride1,
                                uint8_t* pSample2, int32_t iStride2) {
  int32_t iSatdSum;
  uint8_t* pSrc1 = pSample1;
  uint8_t* pSrc2 = pSample2;
  int32_t iStride0 = 0;
  int32_t iStride1_tmp = iStride1 << 1;
  int32_t iStride2_tmp = iStride2 << 1;

  __m256i src1_0, src1_1, src1_2, src1_3;
  __m256i src2_0, src2_1, src2_2, src2_3;
  __m256i iSample01, iSample23;
  __m256i tmp0, tmp1, tmp2, tmp3;
  __m256i zero = __lasx_xvldi(0);
  v16i16 mask= {1, 0, 3, 2, 5, 4, 7, 6, 1, 0, 3, 2, 5, 4, 7, 6};

  DUP4_ARG2(__lasx_xvldx,
            pSrc1, iStride0,
            pSrc1, iStride1,
            pSrc1, iStride1_tmp,
            pSrc1, iStride1_tmp + iStride1,
            src1_0, src1_1, src1_2, src1_3);
  DUP4_ARG2(__lasx_xvldx,
            pSrc2, iStride0,
            pSrc2, iStride2,
            pSrc2, iStride2_tmp,
            pSrc2, iStride2_tmp + iStride2,
            src2_0, src2_1, src2_2, src2_3);
  DUP4_ARG2(__lasx_xvpackev_w,
            src1_0, src1_1,
            src1_2, src1_3,
            src2_0, src2_1,
            src2_2, src2_3,
            src1_0, src1_2, src2_0, src2_2);
  DUP2_ARG2(__lasx_xvpackev_d,
            src1_0, src1_2,
            src2_0, src2_2,
            src1_0, src2_0);

  tmp0 = __lasx_xvsubwev_h_bu(src1_0, src2_0);
  tmp1 = __lasx_xvsubwod_h_bu(src1_0, src2_0);
  tmp2 = __lasx_xvilvl_w(tmp0, tmp1);
  tmp3 = __lasx_xvilvh_w(tmp0, tmp1);
  tmp0 = __lasx_xvpermi_q(tmp3, tmp2, 0x20);
  tmp0 = __lasx_xvshuf_h((__m256i)mask, tmp0, tmp0);

  iSample01 = __lasx_xvhaddw_w_h(tmp0, tmp0);
  iSample23 = __lasx_xvhsubw_w_h(tmp0, tmp0);
  tmp0 = __lasx_xvhaddw_d_w(iSample01, iSample01);
  tmp1 = __lasx_xvhaddw_d_w(iSample23, iSample23);
  tmp2 = __lasx_xvhsubw_d_w(iSample23, iSample23);
  tmp3 = __lasx_xvhsubw_d_w(iSample01, iSample01);

  tmp1 = __lasx_xvpackev_w(tmp1, tmp0);
  tmp3 = __lasx_xvpackev_w(tmp3, tmp2);
  tmp0 = __lasx_xvpermi_q(tmp3, tmp1, 0x20);
  tmp2 = __lasx_xvpermi_q(tmp3, tmp1, 0x31);
  tmp0 = __lasx_xvpermi_w(tmp0, tmp0, 0x72);
  tmp2 = __lasx_xvpermi_w(tmp2, tmp2, 0x72);

  iSample01 = __lasx_xvadd_w(tmp0, tmp2);
  iSample23 = __lasx_xvsub_w(tmp0, tmp2);

  tmp0 = __lasx_xvhaddw_d_w(iSample01, iSample01);
  tmp1 = __lasx_xvhaddw_d_w(iSample23, iSample23);
  tmp2 = __lasx_xvhsubw_d_w(iSample23, iSample23);
  tmp3 = __lasx_xvhsubw_d_w(iSample01, iSample01);

  tmp0 = __lasx_xvpackev_w(tmp0, tmp1);
  tmp2 = __lasx_xvpackev_w(tmp2, tmp3);

  tmp0 = __lasx_xvabsd_w(tmp0, zero);
  tmp2 = __lasx_xvabsd_w(tmp2, zero);
  tmp0 = __lasx_xvadd_w(tmp0, tmp2);
  tmp0 = __lasx_xvhaddw_d_w(tmp0, tmp0);
  tmp0 = __lasx_xvhaddw_q_d(tmp0, tmp0);

  iSatdSum = __lasx_xvpickve2gr_d(tmp0, 0) +
             __lasx_xvpickve2gr_d(tmp0, 2);

  return ((iSatdSum + 1) >> 1);
}

int32_t WelsSampleSad16x8_lasx (uint8_t* pSample1, int32_t iStride1,
                                uint8_t* pSample2, int32_t iStride2) {

  return WelsSampleSad8x8x2_lasx (pSample1, iStride1,
                                  pSample2, iStride2);
}

int32_t WelsSampleSad8x16_lasx (uint8_t* pSample1, int32_t iStride1,
                                uint8_t* pSample2, int32_t iStride2) {
  int32_t iSadSum = 0;

  iSadSum += WelsSampleSad8x8_lasx (pSample1, iStride1,
                                    pSample2, iStride2);
  iSadSum += WelsSampleSad8x8_lasx (pSample1 + (iStride1 << 3), iStride1,
                                    pSample2 + (iStride2 << 3), iStride2);
  return iSadSum;
}

int32_t WelsSampleSad16x16_lasx (uint8_t* pSample1, int32_t iStride1,
                                 uint8_t* pSample2, int32_t iStride2) {
  int32_t iSadSum = 0;

  iSadSum += WelsSampleSad8x8x2_lasx (pSample1, iStride1,
                                      pSample2, iStride2);
  iSadSum += WelsSampleSad8x8x2_lasx (pSample1 + (iStride1 << 3), iStride1,
                                      pSample2 + (iStride2 << 3), iStride2);
  return iSadSum;
}

void WelsSampleSadFour4x4_lasx (uint8_t* iSample1, int32_t iStride1,
                                uint8_t* iSample2, int32_t iStride2,
                                int32_t* pSad) {
  uint8_t *pSrc1 = iSample1;
  uint8_t *pSrc2 = iSample2 - iStride2;
  uint8_t *pSrc3 = iSample2 + iStride2;
  uint8_t *pSrc4 = iSample2 - 1;
  uint8_t *pSrc5 = iSample2 + 1;
  int32_t iStride0 = 0;
  int32_t iStride1_tmp = iStride1 << 1;
  int32_t iStride2_tmp = iStride2 << 1;

  __m256i src1_0, src1_1, src1_2, src1_3;
  __m256i src2_0, src2_1, src2_2, src2_3;
  __m256i cb0, cb1, cb2, cb3, cb4, cb5, cb6, cb7;

  DUP4_ARG2(__lasx_xvldx,
            pSrc1, iStride0,
            pSrc1, iStride1,
            pSrc1, iStride1_tmp,
            pSrc1, iStride1_tmp + iStride1,
            src1_0, src1_1, src1_2, src1_3);
  DUP4_ARG2(__lasx_xvldx,
            pSrc2, iStride0,
            pSrc2, iStride2,
            pSrc2, iStride2_tmp,
            pSrc2, iStride2_tmp + iStride2,
            src2_0, src2_1, src2_2, src2_3);
  DUP4_ARG2(__lasx_xvpackev_w,
            src1_0, src1_1, src1_2, src1_3,
            src2_0, src2_1, src2_2, src2_3,
            src1_0, src1_2, src2_0, src2_2);
  DUP2_ARG2(__lasx_xvpackev_d,
            src1_0, src1_2, src2_0, src2_2,
            cb0, cb1); //16 16
  DUP4_ARG2(__lasx_xvldx,
            pSrc1, iStride0,
            pSrc1, iStride1,
            pSrc1, iStride1_tmp,
            pSrc1, iStride1_tmp + iStride1,
            src1_0, src1_1, src1_2, src1_3);
  DUP4_ARG2(__lasx_xvldx,
            pSrc3, iStride0,
            pSrc3, iStride2,
            pSrc3, iStride2_tmp,
            pSrc3, iStride2_tmp + iStride2,
            src2_0, src2_1, src2_2, src2_3);
  DUP4_ARG2(__lasx_xvpackev_w,
            src1_0, src1_1, src1_2, src1_3,
            src2_0, src2_1, src2_2, src2_3,
            src1_0, src1_2, src2_0, src2_2);
  DUP2_ARG2(__lasx_xvpackev_d,
            src1_0, src1_2, src2_0, src2_2,
            cb2, cb3); //16 16
  DUP4_ARG2(__lasx_xvldx,
            pSrc1, iStride0,
            pSrc1, iStride1,
            pSrc1, iStride1_tmp,
            pSrc1, iStride1_tmp + iStride1,
            src1_0, src1_1, src1_2, src1_3);
  DUP4_ARG2(__lasx_xvldx,
            pSrc4, iStride0,
            pSrc4, iStride2,
            pSrc4, iStride2_tmp,
            pSrc4, iStride2_tmp + iStride2,
            src2_0, src2_1, src2_2, src2_3);
  DUP4_ARG2(__lasx_xvpackev_w,
            src1_0, src1_1, src1_2, src1_3,
            src2_0, src2_1, src2_2, src2_3,
            src1_0, src1_2, src2_0, src2_2);
  DUP2_ARG2(__lasx_xvpackev_d,
            src1_0, src1_2, src2_0, src2_2,
            cb4, cb5); //16 16
  DUP4_ARG2(__lasx_xvldx,
            pSrc1, iStride0,
            pSrc1, iStride1,
            pSrc1, iStride1_tmp,
            pSrc1, iStride1_tmp + iStride1,
            src1_0, src1_1, src1_2, src1_3);
  DUP4_ARG2(__lasx_xvldx,
            pSrc5, iStride0,
            pSrc5, iStride2,
            pSrc5, iStride2_tmp,
            pSrc5, iStride2_tmp + iStride2,
            src2_0, src2_1, src2_2, src2_3);
  DUP4_ARG2(__lasx_xvpackev_w,
            src1_0, src1_1, src1_2, src1_3,
            src2_0, src2_1, src2_2, src2_3,
            src1_0, src1_2, src2_0, src2_2);
  DUP2_ARG2(__lasx_xvpackev_d,
            src1_0, src1_2, src2_0, src2_2,
            cb6, cb7); //16 16

  cb0 = __lasx_xvpermi_q(cb2, cb0, 0x20);
  cb1 = __lasx_xvpermi_q(cb3, cb1, 0x20);
  cb4 = __lasx_xvpermi_q(cb6, cb4, 0x20);
  cb5 = __lasx_xvpermi_q(cb7, cb5, 0x20);

  HORISUM(cb0, cb1, cb0);
  HORISUM(cb4, cb5, cb4);

  DUP2_ARG2(__lasx_xvhaddw_qu_du,
           cb0, cb0, cb4, cb4,
           cb0, cb4);

  * (pSad) = __lasx_xvpickve2gr_d(cb0, 0);
  * (pSad + 1) = __lasx_xvpickve2gr_d(cb0, 2);
  * (pSad + 2) = __lasx_xvpickve2gr_d(cb4, 0);
  * (pSad + 3) = __lasx_xvpickve2gr_d(cb4, 2);
}

void WelsSampleSadFour8x8_lasx (uint8_t* iSample1, int32_t iStride1,
                                uint8_t* iSample2, int32_t iStride2,
                                int32_t* pSad) {
  * (pSad)     = WelsSampleSad8x8_lasx (iSample1, iStride1,
                                       (iSample2 - iStride2), iStride2);
  * (pSad + 1) = WelsSampleSad8x8_lasx (iSample1, iStride1,
                                       (iSample2 + iStride2), iStride2);
  * (pSad + 2) = WelsSampleSad8x8_lasx (iSample1, iStride1,
                                       (iSample2 - 1), iStride2);
  * (pSad + 3) = WelsSampleSad8x8_lasx (iSample1, iStride1,
                                       (iSample2 + 1), iStride2);
}

void WelsSampleSadFour8x16_lasx (uint8_t* iSample1, int32_t iStride1,
                                 uint8_t* iSample2, int32_t iStride2,
                                 int32_t* pSad) {
  * (pSad)     = WelsSampleSad8x16_lasx (iSample1, iStride1,
                                        (iSample2 - iStride2), iStride2);
  * (pSad + 1) = WelsSampleSad8x16_lasx (iSample1, iStride1,
                                        (iSample2 + iStride2), iStride2);
  * (pSad + 2) = WelsSampleSad8x16_lasx (iSample1, iStride1,
                                        (iSample2 - 1), iStride2);
  * (pSad + 3) = WelsSampleSad8x16_lasx (iSample1, iStride1,
                                        (iSample2 + 1), iStride2);
}

void WelsSampleSadFour16x8_lasx (uint8_t* iSample1, int32_t iStride1,
                                 uint8_t* iSample2, int32_t iStride2,
                                 int32_t* pSad) {
  * (pSad)     = WelsSampleSad16x8_lasx (iSample1, iStride1,
                                        (iSample2 - iStride2), iStride2);
  * (pSad + 1) = WelsSampleSad16x8_lasx (iSample1, iStride1,
                                        (iSample2 + iStride2), iStride2);
  * (pSad + 2) = WelsSampleSad16x8_lasx (iSample1, iStride1,
                                        (iSample2 - 1), iStride2);
  * (pSad + 3) = WelsSampleSad16x8_lasx (iSample1, iStride1,
                                        (iSample2 + 1), iStride2);
}

void WelsSampleSadFour16x16_lasx (uint8_t* iSample1, int32_t iStride1,
                                  uint8_t* iSample2, int32_t iStride2,
                                  int32_t* pSad) {
  * (pSad)     = WelsSampleSad16x16_lasx (iSample1, iStride1,
                                         (iSample2 - iStride2), iStride2);
  * (pSad + 1) = WelsSampleSad16x16_lasx (iSample1, iStride1,
                                         (iSample2 + iStride2), iStride2);
  * (pSad + 2) = WelsSampleSad16x16_lasx (iSample1, iStride1,
                                         (iSample2 - 1), iStride2);
  * (pSad + 3) = WelsSampleSad16x16_lasx (iSample1, iStride1,
                                         (iSample2 + 1), iStride2);
}

int32_t WelsSampleSatd8x8_lasx (uint8_t* pSample1, int32_t iStride1,
                                uint8_t* pSample2, int32_t iStride2) {
  int32_t iSatdSum = 0;

  iSatdSum += WelsSampleSatd4x4_lasx (pSample1, iStride1,
                                      pSample2, iStride2);
  iSatdSum += WelsSampleSatd4x4_lasx (pSample1 + 4, iStride1,
                                      pSample2 + 4, iStride2);
  iSatdSum += WelsSampleSatd4x4_lasx (pSample1 + (iStride1 << 2), iStride1,
                                      pSample2 + (iStride2 << 2),   iStride2);
  iSatdSum += WelsSampleSatd4x4_lasx (pSample1 + (iStride1 << 2) + 4, iStride1,
                                      pSample2 + (iStride2 << 2) + 4, iStride2);
  return iSatdSum;
}

int32_t WelsSampleSatd16x8_lasx (uint8_t* pSample1, int32_t iStride1,
                                 uint8_t* pSample2, int32_t iStride2) {
  int32_t iSatdSum = 0;

  iSatdSum += WelsSampleSatd8x8_lasx (pSample1, iStride1,
                                      pSample2, iStride2);
  iSatdSum += WelsSampleSatd8x8_lasx (pSample1 + 8, iStride1,
                                      pSample2 + 8, iStride2);
  return iSatdSum;
}

int32_t WelsSampleSatd8x16_lasx (uint8_t* pSample1, int32_t iStride1,
                                 uint8_t* pSample2, int32_t iStride2) {
  int32_t iSatdSum = 0;

  iSatdSum += WelsSampleSatd8x8_lasx (pSample1, iStride1,
                                      pSample2, iStride2);
  iSatdSum += WelsSampleSatd8x8_lasx (pSample1 + (iStride1 << 3), iStride1,
                                      pSample2 + (iStride2 << 3), iStride2);
  return iSatdSum;
}

int32_t WelsSampleSatd16x16_lasx (uint8_t* pSample1, int32_t iStride1,
                                  uint8_t* pSample2, int32_t iStride2) {
  int32_t iSatdSum = 0;

  iSatdSum += WelsSampleSatd8x8_lasx (pSample1, iStride1,
                                      pSample2, iStride2);
  iSatdSum += WelsSampleSatd8x8_lasx (pSample1 + 8, iStride1,
                                      pSample2 + 8, iStride2);
  iSatdSum += WelsSampleSatd8x8_lasx (pSample1 + (iStride1 << 3), iStride1,
                                      pSample2 + (iStride2 << 3), iStride2);
  iSatdSum += WelsSampleSatd8x8_lasx (pSample1 + (iStride1 << 3) + 8, iStride1,
                                      pSample2 + (iStride2 << 3) + 8, iStride2);
  return iSatdSum;
}
