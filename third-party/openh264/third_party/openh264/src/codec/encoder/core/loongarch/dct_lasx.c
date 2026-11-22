/*!
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
 * \file    dct_lasx.c
 *
 * \brief   Loongson optimization
 *
 * \date    15/02/2022 Created
 *
 *************************************************************************************
 */
#include <stdint.h>
#include "loongson_intrinsics.h"

#define CALC_TEMPS_AND_PDCT(src0, src1, src2, src3, \
                            dst0, dst1, dst2, dst3) \
do {                                                \
  __m256i tms0, tms1, tms2, tms3;                   \
  tms0 = __lasx_xvadd_h(src0, src3);                \
  tms1 = __lasx_xvadd_h(src1, src2);                \
  tms2 = __lasx_xvsub_h(src1, src2);                \
  tms3 = __lasx_xvsub_h(src0, src3);                \
  dst0 = __lasx_xvadd_h(tms0, tms1);                \
  dst1 = __lasx_xvslli_h(tms3, 1);                  \
  dst1 = __lasx_xvadd_h(dst1, tms2);                \
  dst2 = __lasx_xvsub_h(tms0, tms1);                \
  dst3 = __lasx_xvslli_h(tms2, 1);                  \
  dst3 = __lasx_xvsub_h(tms3, dst3);                \
}while(0)

/****************************************************************************
 * DCT functions
 ****************************************************************************/
void WelsDctT4_lasx (int16_t* pDct, uint8_t* pPixel1,
                     int32_t iStride1, uint8_t* pPixel2,
                     int32_t iStride2) {
  int32_t iStride0 = 0;
  int32_t iStride1_x2 = iStride1 << 1;
  int32_t iStride1_x3 = iStride1_x2 + iStride1;
  int32_t iStride2_x2 = iStride2 << 1;
  int32_t iStride2_x3 = iStride2_x2 + iStride2;

  __m256i src0, src1, src2, src3, src4, src5, src6, src7;
  __m256i dst0, dst1, dst2, dst3;

  DUP4_ARG2(__lasx_xvldx,
            pPixel1, iStride0,
            pPixel1, iStride1,
            pPixel1, iStride1_x2,
            pPixel1, iStride1_x3,
            src0, src1, src2, src3);
  DUP4_ARG2(__lasx_xvldx,
            pPixel2, iStride0,
            pPixel2, iStride2,
            pPixel2, iStride2_x2,
            pPixel2, iStride2_x3,
            src4, src5, src6, src7);
  DUP4_ARG2(__lasx_xvilvl_b,
            src0, src4,
            src1, src5,
            src2, src6,
            src3, src7,
            src0, src1, src2, src3);
  DUP4_ARG2(__lasx_xvhsubw_hu_bu,
            src0, src0,
            src1, src1,
            src2, src2,
            src3, src3,
            src0, src1, src2, src3);
  LASX_TRANSPOSE4x4_H(src0, src1, src2, src3,
                      src0, src1, src2, src3);
  CALC_TEMPS_AND_PDCT(src0, src1, src2, src3,
                      dst0, dst1, dst2, dst3);
  LASX_TRANSPOSE4x4_H(dst0, dst1, dst2, dst3,
                      src0, src1, src2, src3);
  CALC_TEMPS_AND_PDCT(src0, src1, src2, src3,
                      dst0, dst1, dst2, dst3);
  dst0 = __lasx_xvpackev_d(dst1, dst0);
  dst2 = __lasx_xvpackev_d(dst3, dst2);
  dst0 = __lasx_xvpermi_q(dst2, dst0, 0x20);
  __lasx_xvst(dst0, pDct, 0);
}

void WelsDctFourT4_lasx (int16_t* pDct, uint8_t* pPixel1,
                         int32_t iStride1, uint8_t* pPixel2,
                         int32_t iStride2) {
  int32_t stride_1 = iStride1 << 2;
  int32_t stride_2 = iStride2 << 2;
  int32_t iStride0 = 0;
  int32_t iStride1_x2 = iStride1 << 1;
  int32_t iStride1_x3 = iStride1_x2 + iStride1;
  int32_t iStride2_x2 = iStride2 << 1;
  int32_t iStride2_x3 = iStride2_x2 + iStride2;
  uint8_t *psrc10 = pPixel1, *psrc11 = pPixel2;
  uint8_t *psrc20 = pPixel1 + stride_1, *psrc21 = pPixel2 + stride_2;

  __m256i src0, src1, src2, src3, src4, src5, src6, src7,
          src8, src9, src10, src11, src12, src13, src14 ,src15;
  __m256i tmp0, tmp1, tmp2, tmp3, dst0, dst1, dst2, dst3, dst4,
          dst5, dst6, dst7;

  DUP4_ARG2(__lasx_xvldx,
            psrc10, iStride0,
            psrc10, iStride1,
            psrc10, iStride1_x2,
            psrc10, iStride1_x3,
            src0, src1, src2, src3);
  DUP4_ARG2(__lasx_xvldx,
            psrc11, iStride0,
            psrc11, iStride2,
            psrc11, iStride2_x2,
            psrc11, iStride2_x3,
            src4, src5, src6, src7);
  DUP4_ARG2(__lasx_xvldx,
            psrc20, iStride0,
            psrc20, iStride1,
            psrc20, iStride1_x2,
            psrc20, iStride1_x3,
            src8, src9, src10, src11);
  DUP4_ARG2(__lasx_xvldx,
            psrc21, iStride0,
            psrc21, iStride2,
            psrc21, iStride2_x2,
            psrc21, iStride2_x3,
            src12, src13, src14, src15);
  DUP4_ARG2(__lasx_xvilvl_b,
            src0, src4,
            src1, src5,
            src2, src6,
            src3, src7,
            src0, src1, src2, src3);
  DUP4_ARG2(__lasx_xvilvl_b,
            src8, src12,
            src9, src13,
            src10, src14,
            src11, src15,
            src8, src9, src10, src11);
  DUP4_ARG2(__lasx_xvhsubw_hu_bu,
            src0, src0,
            src1, src1,
            src2, src2,
            src3, src3,
            src0, src1, src2, src3);
  DUP4_ARG2(__lasx_xvhsubw_hu_bu,
            src8, src8,
            src9, src9,
            src10, src10,
            src11, src11,
            src8, src9, src10 ,src11);
  LASX_TRANSPOSE8x8_H(src0, src1, src2, src3, src8, src9, src10, src11,
                      src0, src1, src2, src3, src8, src9, src10, src11);
  DUP4_ARG3(__lasx_xvpermi_q,
            src8, src0, 0x20,
            src9, src1, 0x20,
            src10,src2, 0x20,
            src11,src3, 0x20,
            src0, src1, src2, src3);
  CALC_TEMPS_AND_PDCT(src0, src1, src2, src3,
                      dst0, dst1, dst2, dst3);
  DUP4_ARG3(__lasx_xvpermi_q,
            dst0, dst0, 0x31,
            dst1, dst1, 0x31,
            dst2, dst2, 0x31,
            dst3, dst3, 0x31,
            dst4, dst5, dst6, dst7);
  LASX_TRANSPOSE8x8_H(dst0, dst1, dst2, dst3, dst4, dst5, dst6, dst7,
                      dst0, dst1, dst2, dst3, dst4, dst5, dst6, dst7);
  DUP4_ARG3(__lasx_xvpermi_q,
            dst4, dst0, 0x20,
            dst5, dst1, 0x20,
            dst6, dst2, 0x20,
            dst7, dst3, 0x20,
            dst0, dst1, dst2, dst3);
  CALC_TEMPS_AND_PDCT(dst0, dst1, dst2, dst3,
                      dst0, dst1, dst2, dst3);
  DUP2_ARG2(__lasx_xvpackev_d,
            dst1, dst0,
            dst3, dst2,
            tmp0, tmp1);
  DUP2_ARG2(__lasx_xvpackod_d,
            dst1, dst0,
            dst3, dst2,
            tmp2, tmp3);
  DUP2_ARG3(__lasx_xvpermi_q,
            tmp1, tmp0, 0x20,
            tmp3, tmp2, 0x20,
            dst0, dst1);
  DUP2_ARG3(__lasx_xvpermi_q,
            tmp1, tmp0, 0x31,
            tmp3, tmp2, 0x31,
            dst2, dst3);
  __lasx_xvst(dst0, pDct, 0);
  __lasx_xvst(dst1, pDct, 32);
  __lasx_xvst(dst2, pDct, 64);
  __lasx_xvst(dst3, pDct, 96);
}

/****************************************************************************
 * IDCT functions, final output = prediction(CS) + IDCT(scaled_coeff)
 ****************************************************************************/
void WelsIDctT4Rec_lasx (uint8_t* pRec, int32_t iStride,
                         uint8_t* pPred, int32_t iPredStride,
                         int16_t* pDct) {
  int32_t iDstStride_x2 = iStride << 1;
  int32_t iDstStride_x3 = iStride + iDstStride_x2;
  int32_t iPredStride_x2 = iPredStride << 1;
  int32_t iPredStride_x3 = iPredStride + iPredStride_x2;

  __m256i src0, src1, src2, src3, src4, src5, src6, src7,
          tmp0, tmp1, tmp2, tmp3, tmp4, tmp5, tmp6, tmp7,
          dst0, dst1, dst2, dst3;

  src0 = __lasx_xvld(pDct, 0);
  src4 = __lasx_xvld(pPred, 0);
  src5 = __lasx_xvldx(pPred, iPredStride);
  src6 = __lasx_xvldx(pPred, iPredStride_x2);
  src7 = __lasx_xvldx(pPred, iPredStride_x3);

  src1 = __lasx_xvpickve_d(src0, 1);
  src2 = __lasx_xvpickve_d(src0, 2);
  src3 = __lasx_xvpickve_d(src0, 3);

  LASX_TRANSPOSE4x4_H(src0, src1, src2, src3,
                      src0, src1, src2, src3);
  //horizon
  tmp0 = __lasx_xvadd_h(src0, src2); //0+2 sumu
  tmp1 = __lasx_xvsrai_h(src3, 1);
  tmp1 = __lasx_xvadd_h(src1, tmp1); //1+3 sumd
  tmp2 = __lasx_xvsub_h(src0, src2); //0-2 delu
  tmp3 = __lasx_xvsrai_h(src1, 1);
  tmp3 = __lasx_xvsub_h(tmp3, src3); //1-3 deld

  src0 = __lasx_xvadd_h(tmp0 ,tmp1); //0 4 8  12
  src1 = __lasx_xvadd_h(tmp2, tmp3); //1 5 9  13
  src2 = __lasx_xvsub_h(tmp2, tmp3); //2 6 10 14
  src3 = __lasx_xvsub_h(tmp0, tmp1); //3 7 11 15
  //vertical
  LASX_TRANSPOSE4x4_H(src0, src1, src2, src3,
                      src0, src1, src2, src3);
  tmp0 = __lasx_xvadd_h(src0, src2); //suml
  tmp1 = __lasx_xvsrai_h(src3, 1);
  tmp1 = __lasx_xvadd_h(src1, tmp1); //sumr
  tmp2 = __lasx_xvsub_h(src0, src2); //dell
  tmp3 = __lasx_xvsrai_h(src1, 1);
  tmp3 = __lasx_xvsub_h(tmp3, src3); //delr

  dst0 = __lasx_xvadd_h(tmp0, tmp1);
  dst1 = __lasx_xvadd_h(tmp2, tmp3);
  dst2 = __lasx_xvsub_h(tmp2, tmp3);
  dst3 = __lasx_xvsub_h(tmp0, tmp1);
  DUP4_ARG2(__lasx_xvsrari_h,
            dst0, 6,
            dst1, 6,
            dst2, 6,
            dst3, 6,
            dst0, dst1, dst2, dst3);
  DUP4_ARG1(__lasx_vext2xv_hu_bu,
            src4, src5, src6, src7,
            tmp4, tmp5, tmp6, tmp7);
  DUP4_ARG2(__lasx_xvsadd_h,
            tmp4, dst0,
            tmp5, dst1,
            tmp6, dst2,
            tmp7, dst3,
            dst0, dst1, dst2, dst3);
  DUP4_ARG1(__lasx_xvclip255_h,
            dst0, dst1, dst2, dst3,
            dst0, dst1, dst2, dst3);
  DUP2_ARG2(__lasx_xvpickev_b,
            dst1, dst0,
            dst3, dst2,
            dst0, dst2);
  __lasx_xvstelm_w(dst0, pRec, 0, 0);
  __lasx_xvstelm_w(dst0, pRec + iStride, 0, 2);
  __lasx_xvstelm_w(dst2, pRec + iDstStride_x2, 0, 0);
  __lasx_xvstelm_w(dst2, pRec + iDstStride_x3, 0, 2);
}

void WelsIDctFourT4Rec_lasx (uint8_t* pRec, int32_t iStride,
                             uint8_t* pPred, int32_t iPredStride,
                             int16_t* pDct) {
  __m256i src0, src1, src2, src3, src4, src5, src6, src7;
  __m256i sumu, delu, sumd, deld, SumL, DelL, DelR, SumR;
  __m256i vec0, vec1, vec2, vec3, vec4, vec5, vec6, vec7;
  __m256i tmp0;
  DUP4_ARG2(__lasx_xvld,
            pDct, 0,
            pDct, 32,
            pDct, 64,
            pDct, 96,
            src0, src2, src4, src6);
  DUP4_ARG3(__lasx_xvpermi_q,
            src0, src0, 0x31,
            src2, src2, 0x31,
            src4, src4, 0x31,
            src6, src6, 0x31,
            src1, src3, src5, src7);
  LASX_TRANSPOSE8x8_H(src0, src1, src2, src3, src4, src5, src6, src7,
                      src0, src1, src2, src3, src4, src5, src6, src7);
  sumu = __lasx_xvadd_h(src0, src2);
  delu = __lasx_xvsub_h(src0, src2);
  tmp0 = __lasx_xvsrai_h(src3, 1);
  sumd = __lasx_xvadd_h(src1, tmp0);
  tmp0 = __lasx_xvsrai_h(src1, 1);
  deld = __lasx_xvsub_h(tmp0, src3);
  src0 = __lasx_xvadd_h(sumu, sumd);
  src1 = __lasx_xvadd_h(delu, deld);
  src2 = __lasx_xvsub_h(delu, deld);
  src3 = __lasx_xvsub_h(sumu, sumd);
  sumu = __lasx_xvadd_h(src4, src6);
  delu = __lasx_xvsub_h(src4, src6);
  tmp0 = __lasx_xvsrai_h(src7, 1);
  sumd = __lasx_xvadd_h(src5, tmp0);
  tmp0 = __lasx_xvsrai_h(src5, 1);
  deld = __lasx_xvsub_h(tmp0, src7);
  src4 = __lasx_xvadd_h(sumu, sumd);
  src5 = __lasx_xvadd_h(delu, deld);
  src6 = __lasx_xvsub_h(delu, deld);
  src7 = __lasx_xvsub_h(sumu, sumd);
  LASX_TRANSPOSE8x8_H(src0, src1, src2, src3, src4, src5, src6, src7,
                      src0, src1, src2, src3, src4, src5, src6, src7);
  src0 = __lasx_xvpermi_q(src2, src0, 0x20);
  src1 = __lasx_xvpermi_q(src3, src1, 0x20);
  src4 = __lasx_xvpermi_q(src6, src4, 0x20);
  src5 = __lasx_xvpermi_q(src7, src5, 0x20);
  SumL = __lasx_xvadd_h(src0, src1);
  DelL = __lasx_xvsub_h(src0, src1);
  tmp0 = __lasx_xvsrai_h(src0, 1);
  DelR = __lasx_xvsub_h(tmp0, src1);
  tmp0 = __lasx_xvsrai_h(src1, 1);
  SumR = __lasx_xvadd_h(src0, tmp0);
  SumR = __lasx_xvbsrl_v(SumR, 8);
  DelR = __lasx_xvbsrl_v(DelR, 8);
  src0 = __lasx_xvadd_h(SumL, SumR);
  src1 = __lasx_xvadd_h(DelL, DelR);
  src2 = __lasx_xvsub_h(DelL, DelR);
  src3 = __lasx_xvsub_h(SumL, SumR);
  SumL = __lasx_xvadd_h(src4, src5);
  DelL = __lasx_xvsub_h(src4, src5);
  tmp0 = __lasx_xvsrai_h(src4, 1);
  DelR = __lasx_xvsub_h(tmp0, src5);
  tmp0 = __lasx_xvsrai_h(src5, 1);
  SumR = __lasx_xvadd_h(src4, tmp0);
  SumR = __lasx_xvbsrl_v(SumR, 8);
  DelR = __lasx_xvbsrl_v(DelR, 8);
  src4 = __lasx_xvadd_h(SumL, SumR);
  src5 = __lasx_xvadd_h(DelL, DelR);
  src6 = __lasx_xvsub_h(DelL, DelR);
  src7 = __lasx_xvsub_h(SumL, SumR);
  DUP4_ARG2(__lasx_xvsrari_h,
            src0, 6,
            src1, 6,
            src2, 6,
            src3, 6,
            src0, src1, src2, src3);
  DUP4_ARG2(__lasx_xvsrari_h,
            src4, 6,
            src5, 6,
            src6, 6,
            src7, 6,
            src4, src5, src6, src7);
  DUP4_ARG2(__lasx_xvpermi_d,
            src0, 0xd8,
            src1, 0xd8,
            src2, 0xd8,
            src3, 0xd8,
            src0, src1, src2, src3);
  DUP4_ARG2(__lasx_xvpermi_d,
            src4, 0xd8,
            src5, 0xd8,
            src6, 0xd8,
            src7, 0xd8,
            src4, src5, src6, src7);
  DUP4_ARG2(__lasx_xvldx,
            pPred, iPredStride*0,
            pPred, iPredStride,
            pPred, iPredStride*2,
            pPred, iPredStride*3,
            vec0, vec1, vec2, vec3);
  pPred += iPredStride*4;
  DUP4_ARG2(__lasx_xvldx,
            pPred, iPredStride*0,
            pPred, iPredStride,
            pPred, iPredStride*2,
            pPred, iPredStride*3,
            vec4, vec5, vec6, vec7);
  DUP4_ARG1(__lasx_vext2xv_hu_bu,
            vec0, vec1, vec2, vec3,
            vec0, vec1, vec2, vec3);
  DUP4_ARG1(__lasx_vext2xv_hu_bu,
            vec4, vec5, vec6, vec7,
            vec4, vec5, vec6, vec7);
  DUP4_ARG2(__lasx_xvsadd_h,
            src0, vec0,
            src1, vec1,
            src2, vec2,
            src3, vec3,
            src0, src1, src2, src3);
  DUP4_ARG2(__lasx_xvsadd_h,
            src4, vec4,
            src5, vec5,
            src6, vec6,
            src7, vec7,
            src4, src5, src6, src7);
  DUP4_ARG1(__lasx_xvclip255_h,
            src0, src1, src2, src3,
            src0, src1, src2, src3);
  DUP4_ARG1(__lasx_xvclip255_h,
            src4, src5, src6, src7,
            src4, src5, src6, src7);
  DUP4_ARG2(__lasx_xvpickev_b,
            src1, src0, src3, src2,
            src5, src4, src7, src6,
            src0, src2, src4, src6);
  __lasx_xvstelm_d(src0, pRec, 0, 0);
  __lasx_xvstelm_d(src0, pRec + iStride, 0, 1);
  __lasx_xvstelm_d(src2, pRec + iStride*2, 0, 0);
  __lasx_xvstelm_d(src2, pRec + iStride*3, 0, 1);
  pRec += iStride*4;
  __lasx_xvstelm_d(src4, pRec, 0, 0);
  __lasx_xvstelm_d(src4, pRec + iStride, 0, 1);
  __lasx_xvstelm_d(src6, pRec + iStride*2, 0, 0);
  __lasx_xvstelm_d(src6, pRec + iStride*3, 0, 1);
}
