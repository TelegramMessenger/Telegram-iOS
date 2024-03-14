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
 * \file    vaa_lsx.c
 *
 * \brief   Loongson optimization
 *
 * \date    12/10/2021 Created
 *
 **********************************************************************************
 */

#include "stdint.h"
#include "loongson_intrinsics.h"

void VAACalcSad_lsx (const uint8_t* pCurData, const uint8_t* pRefData,
                     int32_t iPicWidth, int32_t iPicHeight, int32_t iPicStride,
                     int32_t* pFrameSad, int32_t* pSad8x8, int32_t* pSd8x8,
                     uint8_t* pMad8x8) {
  const uint8_t* tmp_ref = pRefData;
  const uint8_t* tmp_cur = pCurData;
  int32_t iMbWidth = (iPicWidth >> 4);
  int32_t mb_height = (iPicHeight >> 4);
  int32_t mb_index = 0;
  int32_t pic_stride_x8 = iPicStride << 3;
  int32_t step = (iPicStride << 4) - iPicWidth;

  *pFrameSad = 0;
  for (int32_t i = 0; i < mb_height; i++) {
    for (int32_t j = 0; j < iMbWidth; j++) {
      int32_t k, l_sad;
      const uint8_t* tmp_cur_row;
      const uint8_t* tmp_ref_row;
      int32_t tmp_mb_index = mb_index << 2;
      int32_t tmp_mb_index1 = tmp_mb_index + 1;
      int32_t tmp_mb_index2 = tmp_mb_index + 2;
      int32_t tmp_mb_index3 = tmp_mb_index + 3;
      __m128i cur, ref;
      __m128i vec_abs_diff, tmp_l_sad;
      __m128i zero = __lsx_vreplgr2vr_b(0);
      __m128i vec_l_sad = zero;

      l_sad =  0;
      tmp_cur_row = tmp_cur;
      tmp_ref_row = tmp_ref;
      for (k = 0; k < 8; k ++) {
        DUP2_ARG2(__lsx_vld, tmp_cur_row, 0, tmp_ref_row, 0, cur, ref);
        DUP2_ARG2(__lsx_vilvl_b, zero, cur, zero, ref, cur, ref);

        vec_abs_diff = __lsx_vabsd_h(cur, ref);
        vec_l_sad = __lsx_vadd_h(vec_l_sad, vec_abs_diff);
        tmp_cur_row += iPicStride;
        tmp_ref_row += iPicStride;
      }
      tmp_l_sad = __lsx_vhaddw_w_h(vec_l_sad, vec_l_sad);
      tmp_l_sad = __lsx_vhaddw_d_w(tmp_l_sad, tmp_l_sad);
      tmp_l_sad = __lsx_vhaddw_q_d(tmp_l_sad, tmp_l_sad);
      l_sad = __lsx_vpickve2gr_d(tmp_l_sad, 0);
      *pFrameSad += l_sad;
      pSad8x8[tmp_mb_index] = l_sad;

      l_sad =  0;
      tmp_cur_row = tmp_cur + 8;
      tmp_ref_row = tmp_ref + 8;
      vec_l_sad = zero;
      for (k = 0; k < 8; k ++) {
        DUP2_ARG2(__lsx_vld, tmp_cur_row, 0, tmp_ref_row, 0, cur, ref);
        DUP2_ARG2(__lsx_vilvl_b, zero, cur, zero, ref, cur, ref);

        vec_abs_diff = __lsx_vabsd_h(cur, ref);
        vec_l_sad = __lsx_vadd_h(vec_l_sad, vec_abs_diff);
        tmp_cur_row += iPicStride;
        tmp_ref_row += iPicStride;
      }
      tmp_l_sad = __lsx_vhaddw_w_h(vec_l_sad, vec_l_sad);
      tmp_l_sad = __lsx_vhaddw_d_w(tmp_l_sad, tmp_l_sad);
      tmp_l_sad = __lsx_vhaddw_q_d(tmp_l_sad, tmp_l_sad);
      l_sad = __lsx_vpickve2gr_d(tmp_l_sad, 0);
      *pFrameSad += l_sad;
      pSad8x8[tmp_mb_index1] = l_sad;

      l_sad =  0;
      tmp_cur_row = tmp_cur + pic_stride_x8;
      tmp_ref_row = tmp_ref + pic_stride_x8;
      vec_l_sad = zero;
      for (k = 0; k < 8; k ++) {
        DUP2_ARG2(__lsx_vld, tmp_cur_row, 0, tmp_ref_row, 0, cur, ref);
        DUP2_ARG2(__lsx_vilvl_b, zero, cur, zero, ref, cur, ref);

        vec_abs_diff = __lsx_vabsd_h(cur, ref);
        vec_l_sad = __lsx_vadd_h(vec_l_sad, vec_abs_diff);
        tmp_cur_row += iPicStride;
        tmp_ref_row += iPicStride;
      }
      tmp_l_sad = __lsx_vhaddw_w_h(vec_l_sad, vec_l_sad);
      tmp_l_sad = __lsx_vhaddw_d_w(tmp_l_sad, tmp_l_sad);
      tmp_l_sad = __lsx_vhaddw_q_d(tmp_l_sad, tmp_l_sad);
      l_sad = __lsx_vpickve2gr_d(tmp_l_sad, 0);
      *pFrameSad += l_sad;
      pSad8x8[tmp_mb_index2] = l_sad;

      l_sad =  0;
      tmp_cur_row = tmp_cur + pic_stride_x8 + 8;
      tmp_ref_row = tmp_ref + pic_stride_x8 + 8;
      vec_l_sad = zero;
      for (k = 0; k < 8; k ++) {
        DUP2_ARG2(__lsx_vld, tmp_cur_row, 0, tmp_ref_row, 0, cur, ref);
        DUP2_ARG2(__lsx_vilvl_b, zero, cur, zero, ref, cur, ref);

        vec_abs_diff = __lsx_vabsd_h(cur, ref);
        vec_l_sad = __lsx_vadd_h(vec_l_sad, vec_abs_diff);
        tmp_cur_row += iPicStride;
        tmp_ref_row += iPicStride;
      }
      tmp_l_sad = __lsx_vhaddw_w_h(vec_l_sad, vec_l_sad);
      tmp_l_sad = __lsx_vhaddw_d_w(tmp_l_sad, tmp_l_sad);
      tmp_l_sad = __lsx_vhaddw_q_d(tmp_l_sad, tmp_l_sad);
      l_sad = __lsx_vpickve2gr_d(tmp_l_sad, 0);
      *pFrameSad += l_sad;
      pSad8x8[tmp_mb_index3] = l_sad;

      tmp_ref += 16;
      tmp_cur += 16;
      ++mb_index;
    }
    tmp_ref += step;
    tmp_cur += step;
  }
}

void VAACalcSadBgd_lsx (const uint8_t* pCurData, const uint8_t* pRefData,
                        int32_t iPicWidth, int32_t iPicHeight, int32_t iPicStride,
                        int32_t* pFrameSad, int32_t* pSad8x8, int32_t* pSd8x8,
                        uint8_t* pMad8x8) {
  const uint8_t* tmp_ref = pRefData;
  const uint8_t* tmp_cur = pCurData;
  int32_t iMbWidth = (iPicWidth >> 4);
  int32_t mb_height = (iPicHeight >> 4);
  int32_t mb_index = 0;
  int32_t pic_stride_x8 = iPicStride << 3;
  int32_t step = (iPicStride << 4) - iPicWidth;

  *pFrameSad = 0;
  for (int32_t i = 0; i < mb_height; i++) {
    for (int32_t j = 0; j < iMbWidth; j++) {
      int32_t k;
      int32_t l_sad, l_sd, l_mad;
      const uint8_t* tmp_cur_row;
      const uint8_t* tmp_ref_row;
      int32_t tmp_mb_index = mb_index << 2;
      int32_t tmp_mb_index1 = tmp_mb_index + 1;
      int32_t tmp_mb_index2 = tmp_mb_index + 2;
      int32_t tmp_mb_index3 = tmp_mb_index + 3;
      __m128i cur, ref;
      __m128i vec_diff, vec_abs_diff, tmp_l_sd, tmp_l_sad, tmp_l_mad;
      __m128i zero = __lsx_vreplgr2vr_b(0);
      __m128i vec_l_sd =  zero;
      __m128i vec_l_sad = zero;
      __m128i vec_l_mad = zero;

      l_mad = l_sd = l_sad =  0;
      tmp_cur_row = tmp_cur;
      tmp_ref_row = tmp_ref;
      for (k = 0; k < 8; k ++) {
        DUP2_ARG2(__lsx_vld, tmp_cur_row, 0, tmp_ref_row, 0, cur, ref);
        DUP2_ARG2(__lsx_vilvl_b, zero, cur, zero, ref, cur, ref);

        vec_diff = __lsx_vsub_h(cur, ref);
        vec_l_sd = __lsx_vadd_h(vec_l_sd, vec_diff);
        vec_abs_diff = __lsx_vabsd_h(cur, ref);
        vec_l_sad = __lsx_vadd_h(vec_l_sad, vec_abs_diff);
        vec_l_mad = __lsx_vmax_h(vec_l_mad, vec_abs_diff);
        tmp_cur_row += iPicStride;
        tmp_ref_row += iPicStride;
      }

      DUP2_ARG2(__lsx_vhaddw_w_h, vec_l_sd, vec_l_sd, vec_l_sad, vec_l_sad,
                tmp_l_sd, tmp_l_sad);
      DUP2_ARG2(__lsx_vhaddw_d_w, tmp_l_sd, tmp_l_sd, tmp_l_sad, tmp_l_sad,
                tmp_l_sd, tmp_l_sad);
      DUP2_ARG2(__lsx_vhaddw_q_d, tmp_l_sd, tmp_l_sd, tmp_l_sad, tmp_l_sad,
                tmp_l_sd,  tmp_l_sad);
      DUP2_ARG2(__lsx_vpickve2gr_d, tmp_l_sd, 0, tmp_l_sad, 0, l_sd, l_sad);

      tmp_l_mad = __lsx_vbsrl_v(vec_l_mad, 8);
      vec_l_mad = __lsx_vmax_h(vec_l_mad, tmp_l_mad);
      tmp_l_mad = __lsx_vbsrl_v(vec_l_mad, 4);
      vec_l_mad = __lsx_vmax_h(vec_l_mad, tmp_l_mad);
      tmp_l_mad = __lsx_vbsrl_v(vec_l_mad, 2);
      vec_l_mad = __lsx_vmax_h(vec_l_mad, tmp_l_mad);
      l_mad = __lsx_vpickve2gr_h(vec_l_mad, 0);

      *pFrameSad += l_sad;
      pSad8x8[tmp_mb_index] = l_sad;
      pSd8x8[tmp_mb_index] = l_sd;
      pMad8x8[tmp_mb_index] = l_mad;

      l_mad = l_sd = l_sad =  0;
      tmp_cur_row = tmp_cur + 8;
      tmp_ref_row = tmp_ref + 8;
      vec_l_sd = vec_l_sad = vec_l_mad = zero;
      for (k = 0; k < 8; k ++) {
        DUP2_ARG2(__lsx_vld, tmp_cur_row, 0, tmp_ref_row, 0, cur, ref);
        DUP2_ARG2(__lsx_vilvl_b, zero, cur, zero, ref, cur, ref);

        vec_diff = __lsx_vsub_h(cur, ref);
        vec_l_sd = __lsx_vadd_h(vec_l_sd, vec_diff);
        vec_abs_diff = __lsx_vabsd_h(cur, ref);
        vec_l_sad = __lsx_vadd_h(vec_l_sad, vec_abs_diff);
        vec_l_mad = __lsx_vmax_h(vec_l_mad, vec_abs_diff);
        tmp_cur_row += iPicStride;
        tmp_ref_row += iPicStride;
      }

      DUP2_ARG2(__lsx_vhaddw_w_h, vec_l_sd, vec_l_sd, vec_l_sad, vec_l_sad,
                tmp_l_sd, tmp_l_sad);
      DUP2_ARG2(__lsx_vhaddw_d_w, tmp_l_sd, tmp_l_sd, tmp_l_sad, tmp_l_sad,
                tmp_l_sd, tmp_l_sad);
      DUP2_ARG2(__lsx_vhaddw_q_d, tmp_l_sd, tmp_l_sd, tmp_l_sad, tmp_l_sad,
                tmp_l_sd,  tmp_l_sad);
      DUP2_ARG2(__lsx_vpickve2gr_d, tmp_l_sd, 0, tmp_l_sad, 0, l_sd, l_sad);

      tmp_l_mad = __lsx_vbsrl_v(vec_l_mad, 8);
      vec_l_mad = __lsx_vmax_h(vec_l_mad, tmp_l_mad);
      tmp_l_mad = __lsx_vbsrl_v(vec_l_mad, 4);
      vec_l_mad = __lsx_vmax_h(vec_l_mad, tmp_l_mad);
      tmp_l_mad = __lsx_vbsrl_v(vec_l_mad, 2);
      vec_l_mad = __lsx_vmax_h(vec_l_mad, tmp_l_mad);
      l_mad = __lsx_vpickve2gr_h(vec_l_mad, 0);

      *pFrameSad += l_sad;
      pSad8x8[tmp_mb_index1] = l_sad;
      pSd8x8[tmp_mb_index1] = l_sd;
      pMad8x8[tmp_mb_index1] = l_mad;

      l_mad = l_sd = l_sad =  0;
      tmp_cur_row = tmp_cur + pic_stride_x8;
      tmp_ref_row = tmp_ref + pic_stride_x8;
      vec_l_sd = vec_l_sad = vec_l_mad = zero;
      for (k = 0; k < 8; k ++) {
        DUP2_ARG2(__lsx_vld, tmp_cur_row, 0, tmp_ref_row, 0, cur, ref);
        DUP2_ARG2(__lsx_vilvl_b, zero, cur, zero, ref, cur, ref);

        vec_diff = __lsx_vsub_h(cur, ref);
        vec_l_sd = __lsx_vadd_h(vec_l_sd, vec_diff);
        vec_abs_diff = __lsx_vabsd_h(cur, ref);
        vec_l_sad = __lsx_vadd_h(vec_l_sad, vec_abs_diff);
        vec_l_mad = __lsx_vmax_h(vec_l_mad, vec_abs_diff);
        tmp_cur_row += iPicStride;
        tmp_ref_row += iPicStride;
      }

      DUP2_ARG2(__lsx_vhaddw_w_h, vec_l_sd, vec_l_sd, vec_l_sad, vec_l_sad,
                tmp_l_sd, tmp_l_sad);
      DUP2_ARG2(__lsx_vhaddw_d_w, tmp_l_sd, tmp_l_sd, tmp_l_sad, tmp_l_sad,
                tmp_l_sd, tmp_l_sad);
      DUP2_ARG2(__lsx_vhaddw_q_d, tmp_l_sd, tmp_l_sd, tmp_l_sad, tmp_l_sad,
                tmp_l_sd,  tmp_l_sad);
      DUP2_ARG2(__lsx_vpickve2gr_d, tmp_l_sd, 0, tmp_l_sad, 0, l_sd, l_sad);

      tmp_l_mad = __lsx_vbsrl_v(vec_l_mad, 8);
      vec_l_mad = __lsx_vmax_h(vec_l_mad, tmp_l_mad);
      tmp_l_mad = __lsx_vbsrl_v(vec_l_mad, 4);
      vec_l_mad = __lsx_vmax_h(vec_l_mad, tmp_l_mad);
      tmp_l_mad = __lsx_vbsrl_v(vec_l_mad, 2);
      vec_l_mad = __lsx_vmax_h(vec_l_mad, tmp_l_mad);
      l_mad = __lsx_vpickve2gr_h(vec_l_mad, 0);

      *pFrameSad += l_sad;
      pSad8x8[tmp_mb_index2] = l_sad;
      pSd8x8[tmp_mb_index2] = l_sd;
      pMad8x8[tmp_mb_index2] = l_mad;

      l_mad = l_sd = l_sad =  0;
      tmp_cur_row = tmp_cur + pic_stride_x8 + 8;
      tmp_ref_row = tmp_ref + pic_stride_x8 + 8;
      vec_l_sd = vec_l_sad = vec_l_mad = zero;
      for (k = 0; k < 8; k ++) {
        DUP2_ARG2(__lsx_vld, tmp_cur_row, 0, tmp_ref_row, 0, cur, ref);
        DUP2_ARG2(__lsx_vilvl_b, zero, cur, zero, ref, cur, ref);

        vec_diff = __lsx_vsub_h(cur, ref);
        vec_l_sd = __lsx_vadd_h(vec_l_sd, vec_diff);
        vec_abs_diff = __lsx_vabsd_h(cur, ref);
        vec_l_sad = __lsx_vadd_h(vec_l_sad, vec_abs_diff);
        vec_l_mad = __lsx_vmax_h(vec_l_mad, vec_abs_diff);
        tmp_cur_row += iPicStride;
        tmp_ref_row += iPicStride;
      }

      DUP2_ARG2(__lsx_vhaddw_w_h, vec_l_sd, vec_l_sd, vec_l_sad, vec_l_sad,
                tmp_l_sd, tmp_l_sad);
      DUP2_ARG2(__lsx_vhaddw_d_w, tmp_l_sd, tmp_l_sd, tmp_l_sad, tmp_l_sad,
                tmp_l_sd, tmp_l_sad);
      DUP2_ARG2(__lsx_vhaddw_q_d, tmp_l_sd, tmp_l_sd, tmp_l_sad, tmp_l_sad,
                tmp_l_sd,  tmp_l_sad);
      DUP2_ARG2(__lsx_vpickve2gr_d, tmp_l_sd, 0, tmp_l_sad, 0, l_sd, l_sad);

      tmp_l_mad = __lsx_vbsrl_v(vec_l_mad, 8);
      vec_l_mad = __lsx_vmax_h(vec_l_mad, tmp_l_mad);
      tmp_l_mad = __lsx_vbsrl_v(vec_l_mad, 4);
      vec_l_mad = __lsx_vmax_h(vec_l_mad, tmp_l_mad);
      tmp_l_mad = __lsx_vbsrl_v(vec_l_mad, 2);
      vec_l_mad = __lsx_vmax_h(vec_l_mad, tmp_l_mad);
      l_mad = __lsx_vpickve2gr_h(vec_l_mad, 0);

      *pFrameSad += l_sad;
      pSad8x8[tmp_mb_index3] = l_sad;
      pSd8x8[tmp_mb_index3] = l_sd;
      pMad8x8[tmp_mb_index3] = l_mad;

      tmp_ref += 16;
      tmp_cur += 16;
      ++mb_index;
    }
    tmp_ref += step;
    tmp_cur += step;
  }
}
