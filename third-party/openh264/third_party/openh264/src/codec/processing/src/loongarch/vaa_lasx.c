/*!
 **********************************************************************************
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
 * \file    vaa_lasx.c
 *
 * \brief   Loongson optimization
 *
 * \date    14/4/2023 Created
 *
 **********************************************************************************
 */

#include <stdint.h>
#include "loongson_intrinsics.h"

#define LASX_SELECT_MAX_H(in0, out0, out1) do {\
  __m256i tmp0 = __lasx_xvbsrl_v(in0, 8);\
  tmp0 = __lasx_xvmax_hu(tmp0, in0);\
  in0 = __lasx_xvbsrl_v(tmp0, 4);\
  tmp0 = __lasx_xvmax_hu(tmp0, in0);\
  in0 = __lasx_xvbsrl_v(tmp0, 2);\
  tmp0 = __lasx_xvmax_hu(tmp0, in0);\
  out0 = __lasx_xvpickve2gr_w(tmp0, 0);\
  out1 = __lasx_xvpickve2gr_w(tmp0, 4);\
} while(0)

#define CALC_SAD_SD_MAD(in0, in1) do {\
  vec_diff = __lasx_xvsub_h(in0, in1);\
  abs_diff = __lasx_xvabsd_hu(in0, in1);\
  vec_l_sad = __lasx_xvadd_h(vec_l_sad, abs_diff);\
  vec_l_sd = __lasx_xvadd_h(vec_l_sd, vec_diff);\
  vec_l_mad = __lasx_xvmax_hu(abs_diff, vec_l_mad);\
} while(0)

#define LASX_HADD_UH_U32(in, sum_ml, sum_mh)\
{\
  __m256i res_m;\
  __m256i res0_m, res1_m;\
\
  res_m = __lasx_xvhaddw_wu_hu(in, in);\
  res0_m = __lasx_xvhaddw_du_wu(res_m, res_m);\
  res1_m = __lasx_xvbsrl_v(res0_m, 8);\
  res0_m = __lasx_xvadd_d(res0_m, res1_m);\
  sum_ml = __lasx_xvpickve2gr_wu(res0_m, 0);\
  sum_mh = __lasx_xvpickve2gr_wu(res0_m, 4);\
}

#define LASX_HADD_SH_S32(in, sum_ml, sum_mh)\
{\
  __m256i res_m;\
  __m256i res0_m, res1_m;\
\
  res_m = __lasx_xvhaddw_w_h(in, in);\
  res0_m = __lasx_xvhaddw_d_w(res_m, res_m);\
  res1_m = __lasx_xvbsrl_v(res0_m, 8);\
  res0_m = __lasx_xvadd_d(res0_m, res1_m);\
  sum_ml = __lasx_xvpickve2gr_w(res0_m, 0);\
  sum_mh = __lasx_xvpickve2gr_w(res0_m, 4);\
}

void VAACalcSadBgd_lasx (const uint8_t* pCurData, const uint8_t* pRefData,
                         int32_t iPicWidth, int32_t iPicHeight, int32_t iPicStride,
                         int32_t* pFrameSad, int32_t* pSad8x8, int32_t* pSd8x8,
                         uint8_t* pMad8x8) {
  uint8_t* tmp_ref = (uint8_t*)pRefData;
  uint8_t* tmp_cur = (uint8_t*)pCurData;
  int32_t iMbWidth = (iPicWidth >> 4);
  int32_t mb_height = (iPicHeight >> 4);
  int32_t mb_index = 0;
  int32_t pic_stride_x8 = iPicStride << 3;
  int32_t step = (iPicStride << 4) - iPicWidth;
  int32_t iStridex0 = 0, iStridex1 = iPicStride, iStridex2 = iStridex1 + iPicStride,
          iStridex3 = iStridex2 + iPicStride, iStridex4 = iStridex3 + iPicStride,
		  iStridex5 = iStridex4 + iPicStride, iStridex6 = iStridex5 + iPicStride,
		  iStridex7 = iStridex6 + iPicStride;
  uint8_t* tmp_cur_row;
  uint8_t* tmp_ref_row;
  int32_t l_sad_l, l_sd_l, l_mad_l, l_sad_h, l_sd_h, l_mad_h;
  int32_t iFrameSad = 0, index;
  __m256i zero = {0};
  __m256i src0, src1, src2, src3, src4, src5, src6, src7;
  __m256i vec0, vec1, vec2, vec3, vec4, vec5, vec6, vec7;
  __m256i vec_diff, vec_l_sd;
  __m256i abs_diff, vec_l_sad, vec_l_mad;
  for (int32_t i = 0; i < mb_height; i++) {
    for (int32_t j = 0; j < iMbWidth; j++) {
      index = mb_index << 2;
      tmp_cur_row = tmp_cur;
      tmp_ref_row = tmp_ref;
      vec_l_sad = zero;
      vec_l_sd  = zero;
      vec_l_mad = zero;
      DUP4_ARG2(__lasx_xvldx,
                tmp_cur_row, iStridex0,
                tmp_cur_row, iStridex1,
                tmp_cur_row, iStridex2,
                tmp_cur_row, iStridex3,
                src0, src1, src2, src3);
      DUP4_ARG2(__lasx_xvldx,
                tmp_cur_row, iStridex4,
                tmp_cur_row, iStridex5,
                tmp_cur_row, iStridex6,
                tmp_cur_row, iStridex7,
                src4, src5, src6, src7);
      DUP4_ARG2(__lasx_xvldx,
                tmp_ref_row, iStridex0,
                tmp_ref_row, iStridex1,
                tmp_ref_row, iStridex2,
                tmp_ref_row, iStridex3,
                vec0, vec1, vec2, vec3);
      DUP4_ARG2(__lasx_xvldx,
                tmp_ref_row, iStridex4,
                tmp_ref_row, iStridex5,
                tmp_ref_row, iStridex6,
                tmp_ref_row, iStridex7,
                vec4, vec5, vec6, vec7);
      src0 = __lasx_vext2xv_hu_bu(src0);
      src1 = __lasx_vext2xv_hu_bu(src1);
      src2 = __lasx_vext2xv_hu_bu(src2);
      src3 = __lasx_vext2xv_hu_bu(src3);
      src4 = __lasx_vext2xv_hu_bu(src4);
      src5 = __lasx_vext2xv_hu_bu(src5);
      src6 = __lasx_vext2xv_hu_bu(src6);
      src7 = __lasx_vext2xv_hu_bu(src7);
      vec0 = __lasx_vext2xv_hu_bu(vec0);
      vec1 = __lasx_vext2xv_hu_bu(vec1);
      vec2 = __lasx_vext2xv_hu_bu(vec2);
      vec3 = __lasx_vext2xv_hu_bu(vec3);
      vec4 = __lasx_vext2xv_hu_bu(vec4);
      vec5 = __lasx_vext2xv_hu_bu(vec5);
      vec6 = __lasx_vext2xv_hu_bu(vec6);
      vec7 = __lasx_vext2xv_hu_bu(vec7);
      CALC_SAD_SD_MAD(src0, vec0);
      CALC_SAD_SD_MAD(src1, vec1);
      CALC_SAD_SD_MAD(src2, vec2);
      CALC_SAD_SD_MAD(src3, vec3);
      CALC_SAD_SD_MAD(src4, vec4);
      CALC_SAD_SD_MAD(src5, vec5);
      CALC_SAD_SD_MAD(src6, vec6);
      CALC_SAD_SD_MAD(src7, vec7);
      LASX_HADD_UH_U32(vec_l_sad, l_sad_l, l_sad_h);
      LASX_HADD_SH_S32(vec_l_sd, l_sd_l, l_sd_h);
      LASX_SELECT_MAX_H(vec_l_mad, l_mad_l, l_mad_h);
      iFrameSad += l_sad_l + l_sad_h;
      pSad8x8[index + 0] = l_sad_l;
      pSd8x8 [index + 0] = l_sd_l;
      pMad8x8[index + 0] = l_mad_l;
      pSad8x8[index + 1] = l_sad_h;
      pSd8x8 [index + 1] = l_sd_h;
      pMad8x8[index + 1] = l_mad_h;
      tmp_cur_row = tmp_cur + pic_stride_x8;
      tmp_ref_row = tmp_ref + pic_stride_x8;
      vec_l_sad = zero;
      vec_l_sd  = zero;
      vec_l_mad = zero;
      DUP4_ARG2(__lasx_xvldx,
                tmp_cur_row, iStridex0,
                tmp_cur_row, iStridex1,
                tmp_cur_row, iStridex2,
                tmp_cur_row, iStridex3,
                src0, src1, src2, src3);
      DUP4_ARG2(__lasx_xvldx,
                tmp_cur_row, iStridex4,
                tmp_cur_row, iStridex5,
                tmp_cur_row, iStridex6,
                tmp_cur_row, iStridex7,
                src4, src5, src6, src7);
      DUP4_ARG2(__lasx_xvldx,
                tmp_ref_row, iStridex0,
                tmp_ref_row, iStridex1,
                tmp_ref_row, iStridex2,
                tmp_ref_row, iStridex3,
                vec0, vec1, vec2, vec3);
      DUP4_ARG2(__lasx_xvldx,
                tmp_ref_row, iStridex4,
                tmp_ref_row, iStridex5,
                tmp_ref_row, iStridex6,
                tmp_ref_row, iStridex7,
                vec4, vec5, vec6, vec7);
      src0 = __lasx_vext2xv_hu_bu(src0);
      src1 = __lasx_vext2xv_hu_bu(src1);
      src2 = __lasx_vext2xv_hu_bu(src2);
      src3 = __lasx_vext2xv_hu_bu(src3);
      src4 = __lasx_vext2xv_hu_bu(src4);
      src5 = __lasx_vext2xv_hu_bu(src5);
      src6 = __lasx_vext2xv_hu_bu(src6);
      src7 = __lasx_vext2xv_hu_bu(src7);
      vec0 = __lasx_vext2xv_hu_bu(vec0);
      vec1 = __lasx_vext2xv_hu_bu(vec1);
      vec2 = __lasx_vext2xv_hu_bu(vec2);
      vec3 = __lasx_vext2xv_hu_bu(vec3);
      vec4 = __lasx_vext2xv_hu_bu(vec4);
      vec5 = __lasx_vext2xv_hu_bu(vec5);
      vec6 = __lasx_vext2xv_hu_bu(vec6);
      vec7 = __lasx_vext2xv_hu_bu(vec7);
      CALC_SAD_SD_MAD(src0, vec0);
      CALC_SAD_SD_MAD(src1, vec1);
      CALC_SAD_SD_MAD(src2, vec2);
      CALC_SAD_SD_MAD(src3, vec3);
      CALC_SAD_SD_MAD(src4, vec4);
      CALC_SAD_SD_MAD(src5, vec5);
      CALC_SAD_SD_MAD(src6, vec6);
      CALC_SAD_SD_MAD(src7, vec7);
      LASX_HADD_UH_U32(vec_l_sad, l_sad_l, l_sad_h);
      LASX_HADD_SH_S32(vec_l_sd, l_sd_l, l_sd_h);
      LASX_SELECT_MAX_H(vec_l_mad, l_mad_l, l_mad_h);
      iFrameSad += l_sad_l + l_sad_h;
      pSad8x8[index + 2] = l_sad_l;
      pSd8x8 [index + 2] = l_sd_l;
      pMad8x8[index + 2] = l_mad_l;
      pSad8x8[index + 3] = l_sad_h;
      pSd8x8 [index + 3] = l_sd_h;
      pMad8x8[index + 3] = l_mad_h;
      tmp_ref += 16;
      tmp_cur += 16;
      ++mb_index;
    }
    tmp_ref += step;
    tmp_cur += step;
  }
  *pFrameSad = iFrameSad;
}
