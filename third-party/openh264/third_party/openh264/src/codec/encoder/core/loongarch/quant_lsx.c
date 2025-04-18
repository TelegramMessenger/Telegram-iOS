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
 * \file    quant_lsx.c
 *
 * \brief   Loongson optimization
 *
 * \date    12/10/2021 Created
 *
 **********************************************************************************
 */

#include <stdint.h>
#include "loongson_intrinsics.h"

void WelsQuantFour4x4_lsx (int16_t* pDct, const int16_t* pFF, const int16_t* pMF) {
  int32_t i;
  __m128i vec_pFF0, vec_pFF1, vec_pFF2, vec_pMF0, vec_pMF1, vec_pMF2;
  __m128i vec_pDct, vec_pDct0, vec_pDct1, vec_pDct2, vec_pFF, vec_pMF;
  __m128i vec_pDct10, vec_pDct11, vec_pDct12, vec_pDct20, vec_pDct21, vec_pDct22;
  __m128i vec_iSign1, vec_iSign2;

  DUP2_ARG2(__lsx_vld, pFF, 0, pMF, 0, vec_pFF, vec_pMF);
  DUP2_ARG2(__lsx_vsrai_h, vec_pFF, 15, vec_pMF, 15, vec_pFF0, vec_pMF0);
  DUP2_ARG2(__lsx_vilvl_h, vec_pFF0, vec_pFF, vec_pMF0, vec_pMF, vec_pFF1, vec_pMF1);
  DUP2_ARG2(__lsx_vilvh_h, vec_pFF0, vec_pFF, vec_pMF0, vec_pMF, vec_pFF2, vec_pMF2);

  for (i = 0; i < 8; i++) {
    vec_pDct = __lsx_vld(pDct, 0);
    vec_pDct0 = __lsx_vsrai_h(vec_pDct, 15);
    vec_pDct1 = __lsx_vilvl_h(vec_pDct0, vec_pDct);
    vec_pDct2 = __lsx_vilvh_h(vec_pDct0, vec_pDct);

    vec_iSign1 = __lsx_vsrai_w(vec_pDct1, 31);
    vec_iSign2 = __lsx_vsrai_w(vec_pDct2, 31);

    vec_pDct10 = __lsx_vxor_v(vec_iSign1, vec_pDct1);
    vec_pDct10 = __lsx_vsub_w(vec_pDct10, vec_iSign1);
    vec_pDct11 = __lsx_vadd_w(vec_pFF1, vec_pDct10);
    vec_pDct11 = __lsx_vmul_w(vec_pDct11, vec_pMF1);
    vec_pDct11 = __lsx_vsrai_w(vec_pDct11, 16);
    vec_pDct12 = __lsx_vxor_v(vec_iSign1, vec_pDct11);
    vec_pDct12 = __lsx_vsub_w(vec_pDct12, vec_iSign1);

    vec_pDct20 = __lsx_vxor_v(vec_iSign2, vec_pDct2);
    vec_pDct20 = __lsx_vsub_w(vec_pDct20, vec_iSign2);
    vec_pDct21 = __lsx_vadd_w(vec_pFF2, vec_pDct20);
    vec_pDct21 = __lsx_vmul_w(vec_pDct21, vec_pMF2);
    vec_pDct21 = __lsx_vsrai_w(vec_pDct21, 16);
    vec_pDct22 = __lsx_vxor_v(vec_iSign2, vec_pDct21);
    vec_pDct22 = __lsx_vsub_w(vec_pDct22, vec_iSign2);

    vec_pDct = __lsx_vpickev_h(vec_pDct22, vec_pDct12);
    __lsx_vst(vec_pDct, pDct, 0);
    pDct += 8;
  }
}

void WelsQuantFour4x4Max_lsx (int16_t* pDct, const int16_t* pFF, const int16_t* pMF, int16_t* pMax) {
  int32_t k;
  int16_t iMaxAbs;
  __m128i vec_pDct1, vec_pDct2, vec_pDct3, vec_pDct4;
  __m128i vec_pFF, vec_pMF, vec_iMaxAbs, tmp_iMaxAbs;
  __m128i vec_pFF0, vec_pFF1, vec_pFF2, vec_pMF0, vec_pMF1, vec_pMF2;
  __m128i vec_pDct10, vec_pDct11, vec_pDct12, vec_pDct20, vec_pDct21, vec_pDct22;
  __m128i vec_iSign11, vec_iSign12, vec_iSign21, vec_iSign22;
  __m128i vec_iSign31, vec_iSign32, vec_iSign41, vec_iSign42;

  DUP2_ARG2(__lsx_vld, pFF, 0, pMF, 0, vec_pFF, vec_pMF);
  DUP2_ARG2(__lsx_vsrai_h, vec_pFF, 15, vec_pMF, 15, vec_pFF0, vec_pMF0);
  DUP2_ARG2(__lsx_vilvl_h, vec_pFF0, vec_pFF, vec_pMF0, vec_pMF, vec_pFF1, vec_pMF1);
  DUP2_ARG2(__lsx_vilvh_h, vec_pFF0, vec_pFF, vec_pMF0, vec_pMF, vec_pFF2, vec_pMF2);

  for (k = 0; k < 4; k++) {
    iMaxAbs = 0;
    vec_iMaxAbs = __lsx_vreplgr2vr_h(0);
    DUP2_ARG2(__lsx_vld, pDct, 0, pDct + 8, 0, vec_pDct1, vec_pDct2);
    DUP2_ARG2(__lsx_vsrai_h, vec_pDct1, 15, vec_pDct2, 15, vec_pDct10, vec_pDct20);
    DUP2_ARG2(__lsx_vilvl_h, vec_pDct10, vec_pDct1, vec_pDct20, vec_pDct2, vec_pDct11,
              vec_pDct21);
    DUP2_ARG2(__lsx_vilvh_h, vec_pDct10, vec_pDct1, vec_pDct20, vec_pDct2, vec_pDct12,
              vec_pDct22);

    DUP4_ARG2(__lsx_vsrai_w, vec_pDct11, 31, vec_pDct12, 31, vec_pDct21, 31, vec_pDct22,
              31, vec_iSign11, vec_iSign12, vec_iSign21, vec_iSign22);
    vec_iSign31 =  __lsx_vsub_w(__lsx_vxor_v(vec_iSign11, vec_pDct11), vec_iSign11);
    vec_iSign32 =  __lsx_vsub_w(__lsx_vxor_v(vec_iSign12, vec_pDct12), vec_iSign12);
    vec_iSign41 =  __lsx_vsub_w(__lsx_vxor_v(vec_iSign21, vec_pDct21), vec_iSign21);
    vec_iSign42 =  __lsx_vsub_w(__lsx_vxor_v(vec_iSign22, vec_pDct22), vec_iSign22);

    DUP4_ARG2(__lsx_vadd_w, vec_pFF1, vec_iSign31, vec_pFF2, vec_iSign32, vec_pFF1,
              vec_iSign41, vec_pFF2, vec_iSign42, vec_iSign31, vec_iSign32, vec_iSign41,
	      vec_iSign42);
    DUP4_ARG2(__lsx_vmul_w, vec_pMF1, vec_iSign31, vec_pMF2, vec_iSign32, vec_pMF1,
              vec_iSign41, vec_pMF2, vec_iSign42, vec_pDct11, vec_pDct12, vec_pDct21,
              vec_pDct22);
    DUP4_ARG2(__lsx_vsrai_w, vec_pDct11, 16, vec_pDct12, 16, vec_pDct21, 16, vec_pDct22,
              16, vec_pDct11, vec_pDct12, vec_pDct21, vec_pDct22);
    DUP4_ARG2(__lsx_vmax_w, vec_iMaxAbs, vec_pDct11, vec_iMaxAbs, vec_pDct12, vec_iMaxAbs,
              vec_pDct21, vec_iMaxAbs, vec_pDct22, vec_iMaxAbs, vec_iMaxAbs, vec_iMaxAbs,
              vec_iMaxAbs);
    tmp_iMaxAbs = __lsx_vbsrl_v(vec_iMaxAbs, 8);
    vec_iMaxAbs = __lsx_vmax_w(vec_iMaxAbs, tmp_iMaxAbs);
    tmp_iMaxAbs = __lsx_vbsrl_v(vec_iMaxAbs, 4);
    vec_iMaxAbs = __lsx_vmax_w(vec_iMaxAbs, tmp_iMaxAbs);
    iMaxAbs = __lsx_vpickve2gr_h(vec_iMaxAbs, 0);

    vec_pDct1 = __lsx_vsub_w(__lsx_vxor_v(vec_iSign11, vec_pDct11), vec_iSign11);
    vec_pDct2 = __lsx_vsub_w(__lsx_vxor_v(vec_iSign12, vec_pDct12), vec_iSign12);
    vec_pDct3 = __lsx_vsub_w(__lsx_vxor_v(vec_iSign21, vec_pDct21), vec_iSign21);
    vec_pDct4 = __lsx_vsub_w(__lsx_vxor_v(vec_iSign22, vec_pDct22), vec_iSign22);
    DUP2_ARG2(__lsx_vpickev_h, vec_pDct2, vec_pDct1, vec_pDct4, vec_pDct3, vec_pDct1,
              vec_pDct2);

    __lsx_vst(vec_pDct1, pDct, 0);
    __lsx_vst(vec_pDct2, pDct + 8, 0);

    pDct += 16;
    pMax[k] = iMaxAbs;
  }
}

