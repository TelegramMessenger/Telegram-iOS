/*!
 **********************************************************************************
 * Copyright (c) 2022 Loongson Technology Corporation Limited
 * Contributed by Lu Wang <wanglu@loongson.cn>
 *                Jin Bo  <jinbo@loongson.cn>
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
 * \file    deblock_lsx.c
 *
 * \brief   Loongson optimization
 *
 * \date    22/2/2022 Created
 *
 **********************************************************************************
 */

#include <stdint.h>
#include "loongson_intrinsics.h"

void DeblockLumaLt4V_lsx (uint8_t* pPix, int32_t iStrideX,
                          int32_t iAlpha, int32_t iBeta, int8_t* pTc) {
  __m128i p0, p1, p2, q0, q1, q2;
  __m128i p0_l, p1_l, p2_l, q0_l, q1_l, q2_l;
  __m128i p0_h, p1_h, p2_h, q0_h, q1_h, q2_h;
  __m128i t0, t1, t2, t3, t;
  __m128i t0_l, t0_h, t1_l, t1_h, t2_l, t2_h;
  __m128i iTc, iTc0, negiTc, negiTc0, f, flags;
  __m128i iTc_l, iTc_h, negiTc_l, negiTc_h;
  __m128i iTc0_l, iTc0_h, negiTc0_l, negiTc0_h;
  __m128i bDetaP0Q0, bDetaP1P0, bDetaQ1Q0, bDetaP2P0, bDetaQ2Q0;

  __m128i zero = __lsx_vldi(0);
  __m128i alpha = __lsx_vreplgr2vr_b(iAlpha);
  __m128i beta = __lsx_vreplgr2vr_b(iBeta);
  __m128i shuf = {0x0101010100000000, 0x0303030302020202};
  __m128i not_255 = {0xff00ff00ff00ff00, 0xff00ff00ff00ff00};
  int32_t iStrideX_x0 = 0;
  int32_t iStrideX_x2 = iStrideX << 1;
  int32_t iStrideX_x3 = iStrideX_x2 + iStrideX;

  iTc0 = __lsx_vldx(pTc, 0);
  iTc0 = __lsx_vshuf_b(iTc0, iTc0, shuf);
  negiTc0 = __lsx_vneg_b(iTc0);
  iTc = iTc0;

  DUP4_ARG2(__lsx_vldx, pPix, -iStrideX, pPix, -iStrideX_x2, pPix, -iStrideX_x3,
            pPix, iStrideX_x0, p0, p1, p2, q0);
  DUP2_ARG2(__lsx_vldx, pPix, iStrideX, pPix, iStrideX_x2, q1, q2);

  DUP4_ARG2(__lsx_vabsd_bu, p0, q0, p1, p0, q1, q0, p2, p0,
            bDetaP0Q0, bDetaP1P0, bDetaQ1Q0, bDetaP2P0);
  bDetaQ2Q0 = __lsx_vabsd_bu(q2, q0);
  DUP4_ARG2(__lsx_vslt_bu, bDetaP0Q0, alpha, bDetaP1P0, beta, bDetaQ1Q0, beta,
            bDetaP2P0, beta, bDetaP0Q0, bDetaP1P0, bDetaQ1Q0, bDetaP2P0);
  bDetaQ2Q0 = __lsx_vslt_bu(bDetaQ2Q0, beta);

  DUP4_ARG2(__lsx_vilvl_b, zero, p0, zero, p1, zero, p2, zero, q0,
            p0_l, p1_l, p2_l, q0_l);
  DUP2_ARG2(__lsx_vilvl_b, zero, q1, zero, q2, q1_l, q2_l);
  DUP4_ARG2(__lsx_vilvh_b, zero, p0, zero, p1, zero, p2, zero, q0,
            p0_h, p1_h, p2_h, q0_h);
  DUP2_ARG2(__lsx_vilvh_b, zero, q1, zero, q2, q1_h, q2_h);

  DUP2_ARG2(__lsx_vand_v, bDetaP0Q0, bDetaP1P0, f, bDetaQ1Q0, f, f);
  flags = __lsx_vsle_b(zero, iTc0);
  DUP2_ARG2(__lsx_vand_v, f, flags, flags, bDetaP2P0, flags, flags);
  flags = __lsx_vandi_b(flags, 1);
  iTc = __lsx_vadd_b(iTc, flags);
  flags = __lsx_vsle_b(zero, iTc0);
  DUP2_ARG2(__lsx_vand_v, f, flags, flags, bDetaQ2Q0, flags, flags);
  flags = __lsx_vandi_b(flags, 1);
  iTc = __lsx_vadd_b(iTc, flags);
  negiTc = __lsx_vneg_b(iTc);

  flags = __lsx_vslt_b(iTc0, zero);
  iTc0_l = __lsx_vilvl_b(flags, iTc0);
  iTc0_h = __lsx_vilvh_b(flags, iTc0);
  flags = __lsx_vslt_b(negiTc0, zero);
  negiTc0_l = __lsx_vilvl_b(flags, negiTc0);
  negiTc0_h = __lsx_vilvh_b(flags, negiTc0);

  flags = __lsx_vslt_b(iTc, zero);
  iTc_l = __lsx_vilvl_b(flags, iTc);
  iTc_h = __lsx_vilvh_b(flags, iTc);
  flags = __lsx_vslt_b(negiTc, zero);
  negiTc_l = __lsx_vilvl_b(flags, negiTc);
  negiTc_h = __lsx_vilvh_b(flags, negiTc);

  t0_l = __lsx_vadd_h(p0_l, q0_l);
  t0_l = __lsx_vaddi_hu(t0_l, 1);
  t0_l = __lsx_vsrai_h(t0_l, 1);
  t0_l = __lsx_vadd_h(p2_l, t0_l);
  t = __lsx_vslli_h(p1_l, 1);
  t0_l = __lsx_vsub_h(t0_l, t);
  t0_l = __lsx_vsrai_h(t0_l, 1);
  t0_l = __lsx_vmin_h(iTc0_l, t0_l);
  t0_l = __lsx_vmax_h(negiTc0_l, t0_l);
  t0_l = __lsx_vadd_h(p1_l, t0_l);

  t1_l = __lsx_vadd_h(p0_l, q0_l);
  t1_l = __lsx_vaddi_hu(t1_l, 1);
  t1_l = __lsx_vsrai_h(t1_l, 1);
  t1_l = __lsx_vadd_h(q2_l, t1_l);
  t = __lsx_vslli_h(q1_l, 1);
  t1_l = __lsx_vsub_h(t1_l, t);
  t1_l = __lsx_vsrai_h(t1_l, 1);
  t1_l = __lsx_vmin_h(iTc0_l, t1_l);
  t1_l = __lsx_vmax_h(negiTc0_l, t1_l);
  t1_l = __lsx_vadd_h(q1_l, t1_l);

  t0_h = __lsx_vadd_h(p0_h, q0_h);
  t0_h = __lsx_vaddi_hu(t0_h, 1);
  t0_h = __lsx_vsrai_h(t0_h, 1);
  t0_h = __lsx_vadd_h(p2_h, t0_h);
  t = __lsx_vslli_h(p1_h, 1);
  t0_h = __lsx_vsub_h(t0_h, t);
  t0_h = __lsx_vsrai_h(t0_h, 1);
  t0_h = __lsx_vmin_h(iTc0_h, t0_h);
  t0_h = __lsx_vmax_h(negiTc0_h, t0_h);
  t0_h = __lsx_vadd_h(p1_h, t0_h);

  t1_h = __lsx_vadd_h(p0_h, q0_h);
  t1_h = __lsx_vaddi_hu(t1_h, 1);
  t1_h = __lsx_vsrai_h(t1_h, 1);
  t1_h = __lsx_vadd_h(q2_h, t1_h);
  t = __lsx_vslli_h(q1_h, 1);
  t1_h = __lsx_vsub_h(t1_h, t);
  t1_h = __lsx_vsrai_h(t1_h, 1);
  t1_h = __lsx_vmin_h(iTc0_h, t1_h);
  t1_h = __lsx_vmax_h(negiTc0_h, t1_h);
  t1_h = __lsx_vadd_h(q1_h, t1_h);

  t2_l = __lsx_vsub_h(q0_l, p0_l);
  t2_l = __lsx_vslli_h(t2_l, 2);
  t2_l = __lsx_vadd_h(t2_l, p1_l);
  t2_l = __lsx_vsub_h(t2_l, q1_l);
  t2_l = __lsx_vaddi_hu(t2_l, 4);
  t2_l = __lsx_vsrai_h(t2_l, 3);
  t2_l = __lsx_vmin_h(iTc_l, t2_l);
  t2_l = __lsx_vmax_h(negiTc_l, t2_l);

  t2_h = __lsx_vsub_h(q0_h, p0_h);
  t2_h = __lsx_vslli_h(t2_h, 2);
  t2_h = __lsx_vadd_h(t2_h, p1_h);
  t2_h = __lsx_vsub_h(t2_h, q1_h);
  t2_h = __lsx_vaddi_hu(t2_h, 4);
  t2_h = __lsx_vsrai_h(t2_h, 3);
  t2_h = __lsx_vmin_h(iTc_h, t2_h);
  t2_h = __lsx_vmax_h(negiTc_h, t2_h);

  p0_l = __lsx_vadd_h(p0_l, t2_l);
  p1_l = __lsx_vand_v(p0_l, not_255);
  p2_l = __lsx_vsle_h(zero, p0_l);
  flags = __lsx_vseq_h(p1_l, zero);
  p0_l = __lsx_vand_v(p0_l, flags);
  flags = __lsx_vnor_v(flags,flags);
  p2_l = __lsx_vand_v(p2_l, flags);
  p0_l = __lsx_vadd_h(p0_l, p2_l);

  q0_l = __lsx_vsub_h(q0_l, t2_l);
  q1_l = __lsx_vand_v(q0_l, not_255);
  q2_l = __lsx_vsle_h(zero, q0_l);
  flags = __lsx_vseq_h(q1_l, zero);
  q0_l = __lsx_vand_v(q0_l, flags);
  flags = __lsx_vnor_v(flags, flags);
  q2_l = __lsx_vand_v(q2_l, flags);
  q0_l = __lsx_vadd_h(q0_l, q2_l);

  p0_h = __lsx_vadd_h(p0_h, t2_h);
  p1_h = __lsx_vand_v(p0_h, not_255);
  p2_h = __lsx_vsle_h(zero, p0_h);
  flags = __lsx_vseq_h(p1_h, zero);
  p0_h = __lsx_vand_v(p0_h, flags);
  flags = __lsx_vnor_v(flags, flags);
  p2_h = __lsx_vand_v(p2_h, flags);
  p0_h = __lsx_vadd_h(p0_h, p2_h);

  q0_h = __lsx_vsub_h(q0_h, t2_h);
  q1_h = __lsx_vand_v(q0_h, not_255);
  q2_h = __lsx_vsle_h(zero, q0_h);
  flags = __lsx_vseq_h(q1_h, zero);
  q0_h = __lsx_vand_v(q0_h, flags);
  flags = __lsx_vnor_v(flags, flags);
  q2_h = __lsx_vand_v(q2_h, flags);
  q0_h = __lsx_vadd_h(q0_h, q2_h);

  DUP4_ARG2(__lsx_vpickev_b, t0_h, t0_l, t1_h, t1_l,
            p0_h, p0_l, q0_h, q0_l, t0, t1, t2, t3);

  flags = __lsx_vsle_b(zero, iTc0);
  flags = __lsx_vand_v(flags, f);
  t2 = __lsx_vand_v(t2, flags);
  t = __lsx_vnor_v(flags,flags);
  p0 = __lsx_vand_v(p0, t);
  p0 = __lsx_vadd_b(t2, p0);
  t3 = __lsx_vand_v(t3, flags);
  t = __lsx_vnor_v(flags,flags);
  q0 = __lsx_vand_v(q0, t);
  q0 = __lsx_vadd_b(t3, q0);

  DUP2_ARG2(__lsx_vand_v, flags, bDetaP2P0, t0, t, t, t0);
  t = __lsx_vnor_v(t, t);
  p1 = __lsx_vand_v(p1, t);
  p1 = __lsx_vadd_b(t0, p1);
  DUP2_ARG2(__lsx_vand_v, flags, bDetaQ2Q0, t1, t, t, t1);
  t = __lsx_vnor_v(t, t);
  q1 = __lsx_vand_v(q1, t);
  q1 = __lsx_vadd_b(t1, q1);

  __lsx_vstx(p1, pPix, -iStrideX_x2);
  __lsx_vstx(p0, pPix, -iStrideX);
  __lsx_vstx(q0, pPix, iStrideX_x0);
  __lsx_vstx(q1, pPix, iStrideX);
}

void DeblockLumaLt4H_lsx (uint8_t* pPix, int32_t iStrideY,
                          int32_t iAlpha, int32_t iBeta, int8_t* pTc) {
  __m128i p0, p1, p2, q0, q1, q2;
  __m128i p0_l, p1_l, p2_l, q0_l, q1_l, q2_l;
  __m128i p0_h, p1_h, p2_h, q0_h, q1_h, q2_h;
  __m128i t0, t1, t2, t3, t;
  __m128i t0_l, t0_h, t1_l, t1_h, t2_l, t2_h;
  __m128i iTc, iTc0, negiTc, negiTc0, f, flags;
  __m128i iTc_l, iTc_h, negiTc_l, negiTc_h;
  __m128i iTc0_l, iTc0_h, negiTc0_l, negiTc0_h;
  __m128i bDetaP0Q0, bDetaP1P0, bDetaQ1Q0, bDetaP2P0, bDetaQ2Q0;

  __m128i zero = __lsx_vldi(0);
  __m128i alpha = __lsx_vreplgr2vr_b(iAlpha);
  __m128i beta = __lsx_vreplgr2vr_b(iBeta);
  __m128i shuf = {0x0101010100000000, 0x0303030302020202};
  __m128i not_255 = {0xff00ff00ff00ff00, 0xff00ff00ff00ff00};
  int32_t iStrideY_x0 = 0;
  int32_t iStrideY_x2 = iStrideY << 1;
  int32_t iStrideY_x3 = iStrideY_x2 + iStrideY;
  int32_t iStrideY_x4 = iStrideY << 2;

  iTc0 = __lsx_vldx(pTc, 0);
  iTc0 = __lsx_vshuf_b(iTc0, iTc0, shuf);
  negiTc0 = __lsx_vneg_b(iTc0);
  iTc = iTc0;

  pPix -= 3;
  DUP4_ARG2(__lsx_vldx, pPix, iStrideY_x0, pPix, iStrideY, pPix, iStrideY_x2,
            pPix, iStrideY_x3, p0_l, p1_l, p2_l, q0_l);
  pPix += iStrideY_x4;
  DUP4_ARG2(__lsx_vldx, pPix, iStrideY_x0, pPix, iStrideY, pPix, iStrideY_x2,
            pPix, iStrideY_x3, p0_h, p1_h, p2_h, q0_h);
  pPix += iStrideY_x4;
  DUP4_ARG2(__lsx_vldx, pPix, iStrideY_x0, pPix, iStrideY, pPix, iStrideY_x2,
            pPix, iStrideY_x3, q1_l, q2_l, t0_l, t1_l);
  pPix += iStrideY_x4;
  DUP4_ARG2(__lsx_vldx, pPix, iStrideY_x0, pPix, iStrideY, pPix, iStrideY_x2,
            pPix, iStrideY_x3, q1_h, q2_h, t0_h, t1_h);
  LSX_TRANSPOSE16x8_B(p0_l, p1_l, p2_l, q0_l, p0_h, p1_h, p2_h, q0_h, q1_l, q2_l,
                      t0_l, t1_l, q1_h, q2_h, t0_h, t1_h, p2, p1, p0, q0, q1, q2,
                      t, f);

  DUP4_ARG2(__lsx_vabsd_bu, p0, q0, p1, p0, q1, q0, p2, p0,
            bDetaP0Q0, bDetaP1P0, bDetaQ1Q0, bDetaP2P0);
  bDetaQ2Q0 = __lsx_vabsd_bu(q2, q0);
  DUP4_ARG2(__lsx_vslt_bu, bDetaP0Q0, alpha, bDetaP1P0, beta, bDetaQ1Q0, beta,
            bDetaP2P0, beta, bDetaP0Q0, bDetaP1P0, bDetaQ1Q0, bDetaP2P0);
  bDetaQ2Q0 = __lsx_vslt_bu(bDetaQ2Q0, beta);

  DUP4_ARG2(__lsx_vilvl_b, zero, p0, zero, p1, zero, p2, zero, q0,
            p0_l, p1_l, p2_l, q0_l);
  DUP2_ARG2(__lsx_vilvl_b, zero, q1, zero, q2, q1_l, q2_l);
  DUP4_ARG2(__lsx_vilvh_b, zero, p0, zero, p1, zero, p2, zero, q0,
            p0_h, p1_h, p2_h, q0_h);
  DUP2_ARG2(__lsx_vilvh_b, zero, q1, zero, q2, q1_h, q2_h);

  DUP2_ARG2(__lsx_vand_v, bDetaP0Q0, bDetaP1P0, f, bDetaQ1Q0, f, f);
  flags = __lsx_vsle_b(zero, iTc0);
  DUP2_ARG2(__lsx_vand_v, f, flags, flags, bDetaP2P0, flags, flags);
  flags = __lsx_vandi_b(flags, 1);
  iTc = __lsx_vadd_b(iTc, flags);
  flags = __lsx_vsle_b(zero, iTc0);
  DUP2_ARG2(__lsx_vand_v, f, flags, flags, bDetaQ2Q0, flags, flags);
  flags = __lsx_vandi_b(flags, 1);
  iTc = __lsx_vadd_b(iTc, flags);
  negiTc = __lsx_vneg_b(iTc);

  flags = __lsx_vslt_b(iTc0, zero);
  iTc0_l = __lsx_vilvl_b(flags, iTc0);
  iTc0_h = __lsx_vilvh_b(flags, iTc0);
  flags = __lsx_vslt_b(negiTc0, zero);
  negiTc0_l = __lsx_vilvl_b(flags, negiTc0);
  negiTc0_h = __lsx_vilvh_b(flags, negiTc0);

  flags = __lsx_vslt_b(iTc, zero);
  iTc_l = __lsx_vilvl_b(flags, iTc);
  iTc_h = __lsx_vilvh_b(flags, iTc);
  flags = __lsx_vslt_b(negiTc, zero);
  negiTc_l = __lsx_vilvl_b(flags, negiTc);
  negiTc_h = __lsx_vilvh_b(flags, negiTc);

  t0_l = __lsx_vadd_h(p0_l, q0_l);
  t0_l = __lsx_vaddi_hu(t0_l, 1);
  t0_l = __lsx_vsrai_h(t0_l, 1);
  t0_l = __lsx_vadd_h(p2_l, t0_l);
  t = __lsx_vslli_h(p1_l, 1);
  t0_l = __lsx_vsub_h(t0_l, t);
  t0_l = __lsx_vsrai_h(t0_l, 1);
  t0_l = __lsx_vmin_h(iTc0_l, t0_l);
  t0_l = __lsx_vmax_h(negiTc0_l, t0_l);
  t0_l = __lsx_vadd_h(p1_l, t0_l);

  t1_l = __lsx_vadd_h(p0_l, q0_l);
  t1_l = __lsx_vaddi_hu(t1_l, 1);
  t1_l = __lsx_vsrai_h(t1_l, 1);
  t1_l = __lsx_vadd_h(q2_l, t1_l);
  t = __lsx_vslli_h(q1_l, 1);
  t1_l = __lsx_vsub_h(t1_l, t);
  t1_l = __lsx_vsrai_h(t1_l, 1);
  t1_l = __lsx_vmin_h(iTc0_l, t1_l);
  t1_l = __lsx_vmax_h(negiTc0_l, t1_l);
  t1_l = __lsx_vadd_h(q1_l, t1_l);

  t0_h = __lsx_vadd_h(p0_h, q0_h);
  t0_h = __lsx_vaddi_hu(t0_h, 1);
  t0_h = __lsx_vsrai_h(t0_h, 1);
  t0_h = __lsx_vadd_h(p2_h, t0_h);
  t = __lsx_vslli_h(p1_h, 1);
  t0_h = __lsx_vsub_h(t0_h, t);
  t0_h = __lsx_vsrai_h(t0_h, 1);
  t0_h = __lsx_vmin_h(iTc0_h, t0_h);
  t0_h = __lsx_vmax_h(negiTc0_h, t0_h);
  t0_h = __lsx_vadd_h(p1_h, t0_h);

  t1_h = __lsx_vadd_h(p0_h, q0_h);
  t1_h = __lsx_vaddi_hu(t1_h, 1);
  t1_h = __lsx_vsrai_h(t1_h, 1);
  t1_h = __lsx_vadd_h(q2_h, t1_h);
  t = __lsx_vslli_h(q1_h, 1);
  t1_h = __lsx_vsub_h(t1_h, t);
  t1_h = __lsx_vsrai_h(t1_h, 1);
  t1_h = __lsx_vmin_h(iTc0_h, t1_h);
  t1_h = __lsx_vmax_h(negiTc0_h, t1_h);
  t1_h = __lsx_vadd_h(q1_h, t1_h);

  t2_l = __lsx_vsub_h(q0_l, p0_l);
  t2_l = __lsx_vslli_h(t2_l, 2);
  t2_l = __lsx_vadd_h(t2_l, p1_l);
  t2_l = __lsx_vsub_h(t2_l, q1_l);
  t2_l = __lsx_vaddi_hu(t2_l, 4);
  t2_l = __lsx_vsrai_h(t2_l, 3);
  t2_l = __lsx_vmin_h(iTc_l, t2_l);
  t2_l = __lsx_vmax_h(negiTc_l, t2_l);

  t2_h = __lsx_vsub_h(q0_h, p0_h);
  t2_h = __lsx_vslli_h(t2_h, 2);
  t2_h = __lsx_vadd_h(t2_h, p1_h);
  t2_h = __lsx_vsub_h(t2_h, q1_h);
  t2_h = __lsx_vaddi_hu(t2_h, 4);
  t2_h = __lsx_vsrai_h(t2_h, 3);
  t2_h = __lsx_vmin_h(iTc_h, t2_h);
  t2_h = __lsx_vmax_h(negiTc_h, t2_h);

  p0_l = __lsx_vadd_h(p0_l, t2_l);
  p1_l = __lsx_vand_v(p0_l, not_255);
  p2_l = __lsx_vsle_h(zero, p0_l);
  flags = __lsx_vseq_h(p1_l, zero);
  p0_l = __lsx_vand_v(p0_l, flags);
  flags = __lsx_vnor_v(flags,flags);
  p2_l = __lsx_vand_v(p2_l, flags);
  p0_l = __lsx_vadd_h(p0_l, p2_l);

  q0_l = __lsx_vsub_h(q0_l, t2_l);
  q1_l = __lsx_vand_v(q0_l, not_255);
  q2_l = __lsx_vsle_h(zero, q0_l);
  flags = __lsx_vseq_h(q1_l, zero);
  q0_l = __lsx_vand_v(q0_l, flags);
  flags = __lsx_vnor_v(flags, flags);
  q2_l = __lsx_vand_v(q2_l, flags);
  q0_l = __lsx_vadd_h(q0_l, q2_l);

  p0_h = __lsx_vadd_h(p0_h, t2_h);
  p1_h = __lsx_vand_v(p0_h, not_255);
  p2_h = __lsx_vsle_h(zero, p0_h);
  flags = __lsx_vseq_h(p1_h, zero);
  p0_h = __lsx_vand_v(p0_h, flags);
  flags = __lsx_vnor_v(flags, flags);
  p2_h = __lsx_vand_v(p2_h, flags);
  p0_h = __lsx_vadd_h(p0_h, p2_h);

  q0_h = __lsx_vsub_h(q0_h, t2_h);
  q1_h = __lsx_vand_v(q0_h, not_255);
  q2_h = __lsx_vsle_h(zero, q0_h);
  flags = __lsx_vseq_h(q1_h, zero);
  q0_h = __lsx_vand_v(q0_h, flags);
  flags = __lsx_vnor_v(flags, flags);
  q2_h = __lsx_vand_v(q2_h, flags);
  q0_h = __lsx_vadd_h(q0_h, q2_h);

  DUP4_ARG2(__lsx_vpickev_b, t0_h, t0_l, t1_h, t1_l,
            p0_h, p0_l, q0_h, q0_l, t0, t1, t2, t3);

  flags = __lsx_vsle_b(zero, iTc0);
  flags = __lsx_vand_v(flags, f);
  t2 = __lsx_vand_v(t2, flags);
  t = __lsx_vnor_v(flags,flags);
  p0 = __lsx_vand_v(p0, t);
  p0 = __lsx_vadd_b(t2, p0);
  t3 = __lsx_vand_v(t3, flags);
  t = __lsx_vnor_v(flags,flags);
  q0 = __lsx_vand_v(q0, t);
  q0 = __lsx_vadd_b(t3, q0);

  DUP2_ARG2(__lsx_vand_v, flags, bDetaP2P0, t0, t, t, t0);
  t = __lsx_vnor_v(t, t);
  p1 = __lsx_vand_v(p1, t);
  p1 = __lsx_vadd_b(t0, p1);
  DUP2_ARG2(__lsx_vand_v, flags, bDetaQ2Q0, t1, t, t, t1);
  t = __lsx_vnor_v(t, t);
  q1 = __lsx_vand_v(q1, t);
  q1 = __lsx_vadd_b(t1, q1);

  DUP2_ARG2(__lsx_vilvl_b, p0, p1, q1, q0, t0, t2);
  DUP2_ARG2(__lsx_vilvh_b, p0, p1, q1, q0, t1, t3);
  DUP2_ARG2(__lsx_vilvl_h, t2, t0, t3, t1, p0, p2);
  DUP2_ARG2(__lsx_vilvh_h, t2, t0, t3, t1, p1, q0);

  pPix -= iStrideY_x4;
  pPix -= iStrideY_x4;
  pPix -= iStrideY_x4 - 1;
  __lsx_vstelm_w(p0, pPix, 0, 0);
  __lsx_vstelm_w(p0, pPix + iStrideY, 0, 1);
  __lsx_vstelm_w(p0, pPix + iStrideY_x2, 0, 2);
  __lsx_vstelm_w(p0, pPix + iStrideY_x3, 0, 3);
  pPix += iStrideY_x4;
  __lsx_vstelm_w(p1, pPix, 0, 0);
  __lsx_vstelm_w(p1, pPix + iStrideY, 0, 1);
  __lsx_vstelm_w(p1, pPix + iStrideY_x2, 0, 2);
  __lsx_vstelm_w(p1, pPix + iStrideY_x3, 0, 3);
  pPix += iStrideY_x4;
  __lsx_vstelm_w(p2, pPix, 0, 0);
  __lsx_vstelm_w(p2, pPix + iStrideY, 0, 1);
  __lsx_vstelm_w(p2, pPix + iStrideY_x2, 0, 2);
  __lsx_vstelm_w(p2, pPix + iStrideY_x3, 0, 3);
  pPix += iStrideY_x4;
  __lsx_vstelm_w(q0, pPix, 0, 0);
  __lsx_vstelm_w(q0, pPix + iStrideY, 0, 1);
  __lsx_vstelm_w(q0, pPix + iStrideY_x2, 0, 2);
  __lsx_vstelm_w(q0, pPix + iStrideY_x3, 0, 3);
}

void DeblockLumaEq4V_lsx(uint8_t *pPix, int32_t iStride, int32_t iAlpha,
                         int32_t iBeta) {
  int32_t iStride0 = 0;
  int32_t iStride_x2 = iStride << 1;
  int32_t iStride_x3 = iStride + iStride_x2;
  int32_t iStride_x4 = iStride << 2;
  __m128i p0, p1, p2, p3, q0, q1, q2, q3;
  __m128i p0_l, p1_l, p2_l, p3_l, q0_l, q1_l, q2_l, q3_l;
  __m128i p0_h, p1_h, p2_h, p3_h, q0_h, q1_h, q2_h, q3_h;
  __m128i t0, t1, t2, t0_con1, s0, s1, s2, s0_con1;
  __m128i alpha, beta;
  __m128i iDetaP0Q0, bDetaP1P0, bDetaQ1Q0, bDetaP2P0, bDetaQ2Q0;
  __m128i mask0, mask1;

  DUP4_ARG2(__lsx_vldx,
            pPix, -iStride_x4,
            pPix, -iStride_x3,
            pPix, -iStride_x2,
            pPix, -iStride,
            p3, p2, p1, p0);
  DUP4_ARG2(__lsx_vldx,
            pPix, iStride_x3,
            pPix, iStride_x2,
            pPix, iStride,
            pPix, iStride0,
            q3, q2, q1, q0);
  alpha = __lsx_vreplgr2vr_b(iAlpha);
  beta  = __lsx_vreplgr2vr_b(iBeta);
  iDetaP0Q0 = __lsx_vabsd_bu(p0, q0);
  DUP4_ARG2(__lsx_vabsd_bu,
            p1, p0,
            q1, q0,
            p2, p0,
            q2, q0,
            bDetaP1P0, bDetaQ1Q0, bDetaP2P0, bDetaQ2Q0);
  DUP4_ARG2(__lsx_vslt_bu,
            bDetaP1P0, beta,
            bDetaQ1Q0, beta,
            bDetaP2P0, beta,
            bDetaQ2Q0, beta,
            bDetaP1P0, bDetaQ1Q0, bDetaP2P0, bDetaQ2Q0);
  DUP4_ARG2(__lsx_vsllwil_hu_bu,
            p0, 0,
            p1, 0,
            p2, 0,
            p3, 0,
            p0_l, p1_l, p2_l, p3_l);
  DUP4_ARG1(__lsx_vexth_hu_bu,
            p0,
            p1,
            p2,
            p3,
            p0_h, p1_h, p2_h, p3_h);
  DUP4_ARG2(__lsx_vsllwil_hu_bu,
            q0, 0,
            q1, 0,
            q2, 0,
            q3, 0,
            q0_l, q1_l, q2_l, q3_l);
  DUP4_ARG1(__lsx_vexth_hu_bu,
            q0,
            q1,
            q2,
            q3,
            q0_h, q1_h, q2_h, q3_h);
  //(iDetaP0Q0 < iAlpha) && bDetaP1P0 && bDetaQ1Q0
  mask0 = __lsx_vslt_bu(iDetaP0Q0, alpha);
  mask0 &= bDetaP1P0;
  mask0 &= bDetaQ1Q0;
  //iDetaP0Q0 < ((iAlpha >> 2) + 2)
  mask1 = __lsx_vsrli_b(alpha, 2);
  mask1 = __lsx_vaddi_bu(mask1, 2);
  mask1 = __lsx_vslt_bu(iDetaP0Q0, mask1);
  //low part
  //p0
  t0 = __lsx_vadd_h(__lsx_vslli_h(p1_l, 1), p2_l);
  t0 = __lsx_vadd_h(__lsx_vslli_h(p0_l, 1), t0);
  t0 = __lsx_vadd_h(__lsx_vslli_h(q0_l, 1), t0);
  t0 = __lsx_vadd_h(q1_l, t0);
  t0 = __lsx_vsrari_h(t0, 3);
  //p1
  t1 = __lsx_vadd_h(p2_l, p1_l);
  t1 = __lsx_vadd_h(p0_l, t1);
  t1 = __lsx_vadd_h(q0_l, t1);
  t1 = __lsx_vsrari_h(t1, 2);
  //p2
  t2 = __lsx_vadd_h(__lsx_vslli_h(p3_l, 1), p2_l);
  t2 = __lsx_vadd_h(__lsx_vslli_h(p2_l, 1), t2);
  t2 = __lsx_vadd_h(p1_l, t2);
  t2 = __lsx_vadd_h(p0_l, t2);
  t2 = __lsx_vadd_h(q0_l, t2);
  t2 = __lsx_vsrari_h(t2, 3);
  //p0 condition 1
  t0_con1 = __lsx_vadd_h(__lsx_vslli_h(p1_l, 1), p0_l);
  t0_con1 = __lsx_vadd_h(q1_l, t0_con1);
  t0_con1 = __lsx_vsrari_h(t0_con1, 2);
  //q0
  s0 = __lsx_vadd_h(__lsx_vslli_h(p0_l, 1), p1_l);
  s0 = __lsx_vadd_h(__lsx_vslli_h(q0_l, 1), s0);
  s0 = __lsx_vadd_h(__lsx_vslli_h(q1_l, 1), s0);
  s0 = __lsx_vadd_h(q2_l, s0);
  s0 = __lsx_vsrari_h(s0, 3);
  //q1
  s1 = __lsx_vadd_h(p0_l, q0_l);
  s1 = __lsx_vadd_h(q1_l, s1);
  s1 = __lsx_vadd_h(q2_l, s1);
  s1 = __lsx_vsrari_h(s1, 2);
  //q2
  s2 = __lsx_vadd_h(__lsx_vslli_h(q3_l, 1), q2_l);
  s2 = __lsx_vadd_h(__lsx_vslli_h(q2_l, 1), s2);
  s2 = __lsx_vadd_h(q1_l, s2);
  s2 = __lsx_vadd_h(q0_l, s2);
  s2 = __lsx_vadd_h(p0_l, s2);
  s2 = __lsx_vsrari_h(s2, 3);
  //q0 condition 1
  s0_con1 = __lsx_vadd_h(__lsx_vslli_h(q1_l, 1), q0_l);
  s0_con1 = __lsx_vadd_h(p1_l, s0_con1);
  s0_con1 = __lsx_vsrari_h(s0_con1, 2);
  //move back
  p0_l = t0; p1_l = t1; p2_l = t2;
  q0_l = s0; q1_l = s1; q2_l = s2;
  p3_l = t0_con1; q3_l = s0_con1;

  //high part
  //p0
  t0 = __lsx_vadd_h(__lsx_vslli_h(p1_h, 1), p2_h);
  t0 = __lsx_vadd_h(__lsx_vslli_h(p0_h, 1), t0);
  t0 = __lsx_vadd_h(__lsx_vslli_h(q0_h, 1), t0);
  t0 = __lsx_vadd_h(q1_h, t0);
  t0 = __lsx_vsrari_h(t0, 3);
  //p1
  t1 = __lsx_vadd_h(p2_h, p1_h);
  t1 = __lsx_vadd_h(p0_h, t1);
  t1 = __lsx_vadd_h(q0_h, t1);
  t1 = __lsx_vsrari_h(t1, 2);
  //p2
  t2 = __lsx_vadd_h(__lsx_vslli_h(p3_h, 1), p2_h);
  t2 = __lsx_vadd_h(__lsx_vslli_h(p2_h, 1), t2);
  t2 = __lsx_vadd_h(p1_h, t2);
  t2 = __lsx_vadd_h(p0_h, t2);
  t2 = __lsx_vadd_h(q0_h, t2);
  t2 = __lsx_vsrari_h(t2, 3);
  //p0 condition 1
  t0_con1 = __lsx_vadd_h(__lsx_vslli_h(p1_h, 1), p0_h);
  t0_con1 = __lsx_vadd_h(q1_h, t0_con1);
  t0_con1 = __lsx_vsrari_h(t0_con1, 2);
  //q0
  s0 = __lsx_vadd_h(__lsx_vslli_h(p0_h, 1), p1_h);
  s0 = __lsx_vadd_h(__lsx_vslli_h(q0_h, 1), s0);
  s0 = __lsx_vadd_h(__lsx_vslli_h(q1_h, 1), s0);
  s0 = __lsx_vadd_h(q2_h, s0);
  s0 = __lsx_vsrari_h(s0, 3);
  //q1
  s1 = __lsx_vadd_h(p0_h, q0_h);
  s1 = __lsx_vadd_h(q1_h, s1);
  s1 = __lsx_vadd_h(q2_h, s1);
  s1 = __lsx_vsrari_h(s1, 2);
  //q2
  s2 = __lsx_vadd_h(__lsx_vslli_h(q3_h, 1), q2_h);
  s2 = __lsx_vadd_h(__lsx_vslli_h(q2_h, 1), s2);
  s2 = __lsx_vadd_h(q1_h, s2);
  s2 = __lsx_vadd_h(q0_h, s2);
  s2 = __lsx_vadd_h(p0_h, s2);
  s2 = __lsx_vsrari_h(s2, 3);
  //q0 condition 1
  s0_con1 = __lsx_vadd_h(__lsx_vslli_h(q1_h, 1), q0_h);
  s0_con1 = __lsx_vadd_h(p1_h, s0_con1);
  s0_con1 = __lsx_vsrari_h(s0_con1, 2);
  //move back
  p0_h = t0; p1_h = t1; p2_h = t2;
  q0_h = s0; q1_h = s1; q2_h = s2;
  p3_h = t0_con1; q3_h = s0_con1;

  //pack low part and high part
  DUP4_ARG2(__lsx_vpickev_b,
            p0_h, p0_l,
            p1_h, p1_l,
            p2_h, p2_l,
            q0_h, q0_l,
            t0, t1, t2, s0);
  DUP4_ARG2(__lsx_vpickev_b,
            q1_h, q1_l,
            q2_h, q2_l,
            p3_h, p3_l,
            q3_h, q3_l,
            s1, s2, t0_con1, s0_con1);
  t0 = t0 & mask0 & mask1 & bDetaP2P0;
  t0 = __lsx_vadd_b(t0, t0_con1 & mask0 & mask1 & (~bDetaP2P0));
  t0 = __lsx_vadd_b(t0, t0_con1 & mask0 & (~mask1));
  t1 = t1 & mask0 & mask1 & bDetaP2P0;
  t2 = t2 & mask0 & mask1 & bDetaP2P0;
  s0 = s0 & mask0 & mask1 & bDetaQ2Q0;
  s0 = __lsx_vadd_b(s0, s0_con1 & mask0 & mask1 & (~bDetaQ2Q0));
  s0 = __lsx_vadd_b(s0, s0_con1 & mask0 & (~mask1));
  s1 = s1 & mask0 & mask1 & bDetaQ2Q0;
  s2 = s2 & mask0 & mask1 & bDetaQ2Q0;
  p0 = __lsx_vadd_b(t0, p0 & (~mask0));
  p1 = __lsx_vadd_b(t1, p1 & ~(mask0 & mask1 & bDetaP2P0));
  p2 = __lsx_vadd_b(t2, p2 & ~(mask0 & mask1 & bDetaP2P0));
  q0 = __lsx_vadd_b(s0, q0 & (~mask0));
  q1 = __lsx_vadd_b(s1, q1 & ~(mask0 & mask1 & bDetaQ2Q0));
  q2 = __lsx_vadd_b(s2, q2 & ~(mask0 & mask1 & bDetaQ2Q0));
  //Store back
  __lsx_vstx(p2, pPix, -iStride_x3);
  __lsx_vstx(p1, pPix, -iStride_x2);
  __lsx_vstx(p0, pPix, -iStride);
  __lsx_vstx(q0, pPix, iStride0);
  __lsx_vstx(q1, pPix, iStride);
  __lsx_vstx(q2, pPix, iStride_x2);
}

void DeblockLumaEq4H_lsx (uint8_t* pPix, int32_t iStrideY, int32_t iAlpha, int32_t iBeta) {
  __m128i p0, p1, p2, p3, q0, q1, q2, q3;
  __m128i p0_l, p1_l, p2_l, p3_l, q0_l, q1_l, q2_l, q3_l;
  __m128i p0_h, p1_h, p2_h, p3_h, q0_h, q1_h, q2_h, q3_h;
  __m128i t0, t1, t2, t3, t4, t5, t6, t7, temp;
  __m128i t0_l, t0_h, t1_l, t1_h, t2_l, t2_h;
  __m128i t3_l, t3_h, t4_l, t4_h, t5_l, t5_h;
  __m128i t6_l, t6_h, t7_l, t7_h;
  __m128i f0, f1, f2, f3, fn;
  __m128i bDetaP0Q0, bDetaP1P0, bDetaQ1Q0, bDetaP2P0, bDetaQ2Q0;

  __m128i zero = __lsx_vldi(0);
  __m128i alpha = __lsx_vreplgr2vr_b(iAlpha);
  __m128i beta = __lsx_vreplgr2vr_b(iBeta);
  int32_t iStrideY_x0 = 0;
  int32_t iStrideY_x2 = iStrideY << 1;
  int32_t iStrideY_x3 = iStrideY_x2 + iStrideY;
  int32_t iStrideY_x4 = iStrideY << 2;

  // Load data from pPix
  pPix -= 4;
  DUP4_ARG2(__lsx_vldx, pPix, iStrideY_x0, pPix, iStrideY, pPix, iStrideY_x2,
            pPix, iStrideY_x3, p0_l, p1_l, p2_l, q0_l);
  pPix += iStrideY_x4;
  DUP4_ARG2(__lsx_vldx, pPix, iStrideY_x0, pPix, iStrideY, pPix, iStrideY_x2,
            pPix, iStrideY_x3, p0_h, p1_h, p2_h, q0_h);
  pPix += iStrideY_x4;
  DUP4_ARG2(__lsx_vldx, pPix, iStrideY_x0, pPix, iStrideY, pPix, iStrideY_x2,
            pPix, iStrideY_x3, q1_l, q2_l, t0_l, t1_l);
  pPix += iStrideY_x4;
  DUP4_ARG2(__lsx_vldx, pPix, iStrideY_x0, pPix, iStrideY, pPix, iStrideY_x2,
            pPix, iStrideY_x3, q1_h, q2_h, t0_h, t1_h);
  LSX_TRANSPOSE16x8_B(p0_l, p1_l, p2_l, q0_l, p0_h, p1_h, p2_h, q0_h, q1_l, q2_l,
                      t0_l, t1_l, q1_h, q2_h, t0_h, t1_h, p3, p2, p1, p0, q0, q1,
                      q2, q3);

  // Calculate condition mask
  bDetaP0Q0 = __lsx_vabsd_bu(p0, q0);
  DUP4_ARG2(__lsx_vabsd_bu, p1, p0, q1, q0, p2, p0, q2, q0,
            bDetaP1P0, bDetaQ1Q0, bDetaP2P0, bDetaQ2Q0);
  DUP4_ARG2(__lsx_vslt_bu, bDetaP1P0, beta, bDetaQ1Q0, beta, bDetaP2P0, beta,
            bDetaQ2Q0, beta, bDetaP1P0, bDetaQ1Q0, bDetaP2P0, bDetaQ2Q0);

  // Unsigned extend p0, p1, p2, p3, q0, q1, q2, q3 from 8 bits to 16 bits
  DUP4_ARG2(__lsx_vilvl_b, zero, p0, zero, p1, zero, p2, zero, q0,
            p0_l, p1_l, p2_l, q0_l);
  DUP4_ARG2(__lsx_vilvh_b, zero, p0, zero, p1, zero, p2, zero, q0,
            p0_h, p1_h, p2_h, q0_h);
  DUP2_ARG2(__lsx_vilvl_b, zero, q1, zero, q2, q1_l, q2_l);
  DUP2_ARG2(__lsx_vilvh_b, zero, q1, zero, q2, q1_h, q2_h);
  DUP2_ARG2(__lsx_vilvl_b, zero, p3, zero, q3, p3_l, q3_l);
  DUP2_ARG2(__lsx_vilvh_b, zero, p3, zero, q3, p3_h, q3_h);

  // Calculate the low part
  // (p2 + (p1 * (1 << 1)) + (p0 * (1 << 1)) + (q0 * (1 << 1)) + q1 + 4) >> 3
  t0_l = __lsx_vslli_h(p1_l, 1);
  t0_l = __lsx_vadd_h(t0_l, p2_l);
  temp = __lsx_vslli_h(p0_l, 1);
  t0_l = __lsx_vadd_h(t0_l, temp);
  temp = __lsx_vslli_h(q0_l, 1);
  t0_l = __lsx_vadd_h(t0_l, temp);
  t0_l = __lsx_vadd_h(t0_l, q1_l);
  t0_l = __lsx_vaddi_hu(t0_l, 4);
  t0_l = __lsx_vsrai_h(t0_l, 3);

  // (p2 + p1 + p0 + q0 + 2) >> 2
  t1_l = __lsx_vadd_h(p2_l, p1_l);
  t1_l = __lsx_vadd_h(t1_l, p0_l);
  t1_l = __lsx_vadd_h(t1_l, q0_l);
  t1_l = __lsx_vaddi_hu(t1_l, 2);
  t1_l = __lsx_vsrai_h(t1_l, 2);

  // ((p3 * (1 << 1)) + p2 + (p2 * (1 << 1)) + p1 + p0 + q0 + 4) >> 3
  t2_l = __lsx_vslli_h(p3_l, 1);
  t2_l = __lsx_vadd_h(t2_l, p2_l);
  temp = __lsx_vslli_h(p2_l, 1);
  t2_l = __lsx_vadd_h(t2_l, temp);
  t2_l = __lsx_vadd_h(t2_l, p1_l);
  t2_l = __lsx_vadd_h(t2_l, p0_l);
  t2_l = __lsx_vadd_h(t2_l, q0_l);
  t2_l = __lsx_vaddi_hu(t2_l, 4);
  t2_l = __lsx_vsrai_h(t2_l, 3);

  // ((p1 * (1 << 1)) + p0 + q1 + 2) >> 2
  t3_l = __lsx_vslli_h(p1_l, 1);
  t3_l = __lsx_vadd_h(t3_l, p0_l);
  t3_l = __lsx_vadd_h(t3_l, q1_l);
  t3_l = __lsx_vaddi_hu(t3_l, 2);
  t3_l = __lsx_vsrai_h(t3_l, 2);

  // (p1 + (p0 * (1 << 1)) + (q0 * (1 << 1)) + (q1 * (1 << 1)) + q2 + 4) >> 3
  t4_l = __lsx_vslli_h(p0_l, 1);
  t4_l = __lsx_vadd_h(t4_l, p1_l);
  temp = __lsx_vslli_h(q0_l, 1);
  t4_l = __lsx_vadd_h(t4_l, temp);
  temp = __lsx_vslli_h(q1_l, 1);
  t4_l = __lsx_vadd_h(t4_l, temp);
  t4_l = __lsx_vadd_h(t4_l, q2_l);
  t4_l = __lsx_vaddi_hu(t4_l, 4);
  t4_l = __lsx_vsrai_h(t4_l, 3);

  // (p0 + q0 + q1 + q2 + 2) >> 2
  t5_l = __lsx_vadd_h(p0_l, q0_l);
  t5_l = __lsx_vadd_h(t5_l, q1_l);
  t5_l = __lsx_vadd_h(t5_l, q2_l);
  t5_l = __lsx_vaddi_hu(t5_l, 2);
  t5_l = __lsx_vsrai_h(t5_l, 2);

  // ((q3 * (1 << 1)) + q2 + (q2 * (1 << 1)) + q1 + q0 + p0 + 4) >> 3
  t6_l = __lsx_vslli_h(q3_l, 1);
  t6_l = __lsx_vadd_h(t6_l, q2_l);
  temp = __lsx_vslli_h(q2_l, 1);
  t6_l = __lsx_vadd_h(t6_l, temp);
  t6_l = __lsx_vadd_h(t6_l, q1_l);
  t6_l = __lsx_vadd_h(t6_l, q0_l);
  t6_l = __lsx_vadd_h(t6_l, p0_l);
  t6_l = __lsx_vaddi_hu(t6_l, 4);
  t6_l = __lsx_vsrai_h(t6_l, 3);

  // ((q1 * (1 << 1)) + q0 + p1 + 2) >> 2
  t7_l = __lsx_vslli_h(q1_l, 1);
  t7_l = __lsx_vadd_h(t7_l, q0_l);
  t7_l = __lsx_vadd_h(t7_l, p1_l);
  t7_l = __lsx_vaddi_hu(t7_l, 2);
  t7_l = __lsx_vsrai_h(t7_l, 2);

  // Calculate the high part
  // (p2 + (p1 * (1 << 1)) + (p0 * (1 << 1)) + (q0 * (1 << 1)) + q1 + 4) >> 3
  t0_h = __lsx_vslli_h(p1_h, 1);
  t0_h = __lsx_vadd_h(t0_h, p2_h);
  temp = __lsx_vslli_h(p0_h, 1);
  t0_h = __lsx_vadd_h(t0_h, temp);
  temp = __lsx_vslli_h(q0_h, 1);
  t0_h = __lsx_vadd_h(t0_h, temp);
  t0_h = __lsx_vadd_h(t0_h, q1_h);
  t0_h = __lsx_vaddi_hu(t0_h, 4);
  t0_h = __lsx_vsrai_h(t0_h, 3);

  // (p2 + p1 + p0 + q0 + 2) >> 2
  t1_h = __lsx_vadd_h(p2_h, p1_h);
  t1_h = __lsx_vadd_h(t1_h, p0_h);
  t1_h = __lsx_vadd_h(t1_h, q0_h);
  t1_h = __lsx_vaddi_hu(t1_h, 2);
  t1_h = __lsx_vsrai_h(t1_h, 2);

  // ((p3 * (1 << 1)) + p2 + (p2 * (1 << 1)) + p1 + p0 + q0 + 4) >> 3
  t2_h = __lsx_vslli_h(p3_h, 1);
  t2_h = __lsx_vadd_h(t2_h, p2_h);
  temp = __lsx_vslli_h(p2_h, 1);
  t2_h = __lsx_vadd_h(t2_h, temp);
  t2_h = __lsx_vadd_h(t2_h, p1_h);
  t2_h = __lsx_vadd_h(t2_h, p0_h);
  t2_h = __lsx_vadd_h(t2_h, q0_h);
  t2_h = __lsx_vaddi_hu(t2_h, 4);
  t2_h = __lsx_vsrai_h(t2_h, 3);

  // ((p1 * (1 << 1)) + p0 + q1 + 2) >> 2
  t3_h = __lsx_vslli_h(p1_h, 1);
  t3_h = __lsx_vadd_h(t3_h, p0_h);
  t3_h = __lsx_vadd_h(t3_h, q1_h);
  t3_h = __lsx_vaddi_hu(t3_h, 2);
  t3_h = __lsx_vsrai_h(t3_h, 2);

  // (p1 + (p0 * (1 << 1)) + (q0 * (1 << 1)) + (q1 * (1 << 1)) + q2 + 4) >> 3
  t4_h = __lsx_vslli_h(p0_h, 1);
  t4_h = __lsx_vadd_h(t4_h, p1_h);
  temp = __lsx_vslli_h(q0_h, 1);
  t4_h = __lsx_vadd_h(t4_h, temp);
  temp = __lsx_vslli_h(q1_h, 1);
  t4_h = __lsx_vadd_h(t4_h, temp);
  t4_h = __lsx_vadd_h(t4_h, q2_h);
  t4_h = __lsx_vaddi_hu(t4_h, 4);
  t4_h = __lsx_vsrai_h(t4_h, 3);

  // (p0 + q0 + q1 + q2 + 2) >> 2
  t5_h = __lsx_vadd_h(p0_h, q0_h);
  t5_h = __lsx_vadd_h(t5_h, q1_h);
  t5_h = __lsx_vadd_h(t5_h, q2_h);
  t5_h = __lsx_vaddi_hu(t5_h, 2);
  t5_h = __lsx_vsrai_h(t5_h, 2);

  // ((q3 * (1 << 1)) + q2 + (q2 * (1 << 1)) + q1 + q0 + p0 + 4) >> 3
  t6_h = __lsx_vslli_h(q3_h, 1);
  t6_h = __lsx_vadd_h(t6_h, q2_h);
  temp = __lsx_vslli_h(q2_h, 1);
  t6_h = __lsx_vadd_h(t6_h, temp);
  t6_h = __lsx_vadd_h(t6_h, q1_h);
  t6_h = __lsx_vadd_h(t6_h, q0_h);
  t6_h = __lsx_vadd_h(t6_h, p0_h);
  t6_h = __lsx_vaddi_hu(t6_h, 4);
  t6_h = __lsx_vsrai_h(t6_h, 3);

  // ((q1 * (1 << 1)) + q0 + p1 + 2) >> 2
  t7_h = __lsx_vslli_h(q1_h, 1);
  t7_h = __lsx_vadd_h(t7_h, q0_h);
  t7_h = __lsx_vadd_h(t7_h, p1_h);
  t7_h = __lsx_vaddi_hu(t7_h, 2);
  t7_h = __lsx_vsrai_h(t7_h, 2);

  // Combined low and high
  DUP4_ARG2(__lsx_vpickev_b, t0_h, t0_l, t1_h, t1_l, t2_h, t2_l,
            t3_h, t3_l, t0, t1, t2, t3);
  DUP4_ARG2(__lsx_vpickev_b, t4_h, t4_l, t5_h, t5_l, t6_h, t6_l,
            t7_h, t7_l, t4, t5, t6, t7);

  f0 = __lsx_vslt_bu(bDetaP0Q0, alpha);
  f0 = __lsx_vand_v(f0, bDetaP1P0);
  f0 = __lsx_vand_v(f0, bDetaQ1Q0);

  f1 = __lsx_vsrli_b(alpha, 2);
  f1 = __lsx_vaddi_bu(f1, 2);
  f1 = __lsx_vslt_bu(bDetaP0Q0, f1);

  // t0
  f2 = __lsx_vand_v(f0, f1);
  fn = __lsx_vand_v(f2, bDetaP2P0);
  f3 = __lsx_vand_v(fn, t0);
  f2 = __lsx_vnor_v(bDetaP2P0, bDetaP2P0);
  fn = __lsx_vand_v(f0, f2);
  fn = __lsx_vand_v(fn, f1);
  t0 = __lsx_vand_v(fn, t3);
  t0 = __lsx_vadd_b(f3, t0);
  fn = __lsx_vnor_v(f1, f1);
  fn = __lsx_vand_v(fn, f0);
  f3 = __lsx_vand_v(fn, t3);
  t0 = __lsx_vadd_b(f3, t0);

  // t1
  f2 = __lsx_vand_v(f0, f1);
  f2 = __lsx_vand_v(f2, bDetaP2P0);
  t1 = __lsx_vand_v(f2, t1);

  // t2
  f2 = __lsx_vand_v(f0, f1);
  f2 = __lsx_vand_v(f2, bDetaP2P0);
  t2 = __lsx_vand_v(f2, t2);

  // t3
  f2 = __lsx_vand_v(f0, f1);
  fn = __lsx_vand_v(f2, bDetaQ2Q0);
  f3 = __lsx_vand_v(fn, t4);
  fn = __lsx_vnor_v(bDetaQ2Q0, bDetaQ2Q0);
  fn = __lsx_vand_v(fn, f2);
  t3 = __lsx_vand_v(fn, t7);
  t3 = __lsx_vadd_b(f3, t3);
  fn = __lsx_vnor_v(f1, f1);
  fn = __lsx_vand_v(fn, f0);
  f3 = __lsx_vand_v(fn, t7);
  t3 = __lsx_vadd_b(f3, t3);

  // t4
  f2 = __lsx_vand_v(f0, f1);
  f2 = __lsx_vand_v(f2, bDetaQ2Q0);
  t4 = __lsx_vand_v(f2, t5);

  // t5
  f2 = __lsx_vand_v(f0, f1);
  f2 = __lsx_vand_v(f2, bDetaQ2Q0);
  t5 = __lsx_vand_v(f2, t6);

  // p0
  fn = __lsx_vnor_v(f0, f0);
  p0 = __lsx_vand_v(fn, p0);
  p0 = __lsx_vadd_b(p0, t0);

  // p1
  f2 = __lsx_vand_v(f0, f1);
  f2 = __lsx_vand_v(f2, bDetaP2P0);
  fn = __lsx_vnor_v(f2, f2);
  p1 = __lsx_vand_v(fn, p1);
  p1 = __lsx_vadd_b(t1, p1);

  // p2
  f2 = __lsx_vand_v(f0, f1);
  f2 = __lsx_vand_v(f2, bDetaP2P0);
  fn = __lsx_vnor_v(f2, f2);
  p2 = __lsx_vand_v(fn, p2);
  p2 = __lsx_vadd_b(t2, p2);

  // q0
  fn = __lsx_vnor_v(f0, f0);
  q0 = __lsx_vand_v(fn, q0);
  q0 = __lsx_vadd_b(q0, t3);

  // q1
  f2 = __lsx_vand_v(f0, f1);
  f2 = __lsx_vand_v(f2, bDetaQ2Q0);
  fn = __lsx_vnor_v(f2, f2);
  q1 = __lsx_vand_v(fn, q1);
  q1 = __lsx_vadd_b(q1, t4);

  // q2
  f2 = __lsx_vand_v(f0, f1);
  f2 = __lsx_vand_v(f2, bDetaQ2Q0);
  fn = __lsx_vnor_v(f2, f2);
  q2 = __lsx_vand_v(fn, q2);
  q2 = __lsx_vadd_b(q2, t5);

  DUP2_ARG2(__lsx_vilvl_b, p1, p2, q0, p0, t0, t1);
  DUP2_ARG2(__lsx_vilvh_b, p1, p2, q0, p0, t2, t3);

  DUP2_ARG2(__lsx_vilvl_h, t1, t0, t3, t2, p0, p1);
  DUP2_ARG2(__lsx_vilvh_h, t1, t0, t3, t2, p2, p3);

  t1 = __lsx_vilvl_b(q2, q1);
  t2 = __lsx_vilvh_b(q2, q1);

  // Store data to pPix
  pPix -= iStrideY_x4;
  pPix -= iStrideY_x4;
  pPix -= iStrideY_x4;
  pPix += 1;
  __lsx_vstelm_w(p0, pPix, 0, 0);
  __lsx_vstelm_w(p0, pPix + iStrideY, 0, 1);
  __lsx_vstelm_w(p0, pPix + iStrideY_x2, 0, 2);
  __lsx_vstelm_w(p0, pPix + iStrideY_x3, 0, 3);
  pPix += iStrideY_x4;
  __lsx_vstelm_w(p2, pPix, 0, 0);
  __lsx_vstelm_w(p2, pPix + iStrideY, 0, 1);
  __lsx_vstelm_w(p2, pPix + iStrideY_x2, 0, 2);
  __lsx_vstelm_w(p2, pPix + iStrideY_x3, 0, 3);
  pPix += iStrideY_x4;
  __lsx_vstelm_w(p1, pPix, 0, 0);
  __lsx_vstelm_w(p1, pPix + iStrideY, 0, 1);
  __lsx_vstelm_w(p1, pPix + iStrideY_x2, 0, 2);
  __lsx_vstelm_w(p1, pPix + iStrideY_x3, 0, 3);
  pPix += iStrideY_x4;
  __lsx_vstelm_w(p3, pPix, 0, 0);
  __lsx_vstelm_w(p3, pPix + iStrideY, 0, 1);
  __lsx_vstelm_w(p3, pPix + iStrideY_x2, 0, 2);
  __lsx_vstelm_w(p3, pPix + iStrideY_x3, 0, 3);

  pPix -= iStrideY_x4;
  pPix -= iStrideY_x4;
  pPix -= iStrideY_x4;
  pPix += 4;
  __lsx_vstelm_h(t1, pPix, 0, 0);
  __lsx_vstelm_h(t1, pPix + iStrideY, 0, 1);
  __lsx_vstelm_h(t1, pPix + iStrideY_x2, 0, 2);
  __lsx_vstelm_h(t1, pPix + iStrideY_x3, 0, 3);
  pPix += iStrideY_x4;
  __lsx_vstelm_h(t1, pPix, 0, 4);
  __lsx_vstelm_h(t1, pPix + iStrideY, 0, 5);
  __lsx_vstelm_h(t1, pPix + iStrideY_x2, 0, 6);
  __lsx_vstelm_h(t1, pPix + iStrideY_x3, 0, 7);
  pPix += iStrideY_x4;
  __lsx_vstelm_h(t2, pPix, 0, 0);
  __lsx_vstelm_h(t2, pPix + iStrideY, 0, 1);
  __lsx_vstelm_h(t2, pPix + iStrideY_x2, 0, 2);
  __lsx_vstelm_h(t2, pPix + iStrideY_x3, 0, 3);
  pPix += iStrideY_x4;
  __lsx_vstelm_h(t2, pPix, 0, 4);
  __lsx_vstelm_h(t2, pPix + iStrideY, 0, 5);
  __lsx_vstelm_h(t2, pPix + iStrideY_x2, 0, 6);
  __lsx_vstelm_h(t2, pPix + iStrideY_x3, 0, 7);
}

void DeblockChromaLt4V_lsx (uint8_t* pPixCb, uint8_t* pPixCr, int32_t iStrideX,
                            int32_t iAlpha, int32_t iBeta, int8_t* pTc) {
  __m128i p0, p1, q0, q1, t0, t1, tp;
  __m128i p0_l, p1_l, p2_l, q0_l, q1_l, q2_l;
  __m128i iTc0, negiTc0, iTc0_l, negiTc0_l;
  __m128i flags, flag, iDeta_l;
  __m128i bDetaP0Q0, bDetaP1P0, bDetaQ1Q0;

  __m128i zero = __lsx_vldi(0);
  __m128i alpha = __lsx_vreplgr2vr_b(iAlpha);
  __m128i beta = __lsx_vreplgr2vr_b(iBeta);
  __m128i shuf = {0x0303020201010000, 0x0};
  __m128i not_255 = {0xff00ff00ff00ff00, 0xff00ff00ff00ff00};

  int32_t iStrideX_x0 = 0;
  int32_t iStrideX_x2 = iStrideX << 1;

  iTc0 = __lsx_vldx(pTc, 0);
  iTc0 = __lsx_vshuf_b(iTc0, iTc0, shuf);
  negiTc0 = __lsx_vneg_b(iTc0);

  flag = __lsx_vslt_b(iTc0, zero);
  iTc0_l = __lsx_vilvl_b(flag, iTc0);
  flag = __lsx_vslt_b(negiTc0, zero);
  negiTc0_l = __lsx_vilvl_b(flag, negiTc0);

  // Load data from pPixCb
  DUP4_ARG2(__lsx_vldx, pPixCb, -iStrideX, pPixCb, -iStrideX_x2, pPixCb,
            iStrideX_x0, pPixCb, iStrideX, p0, p1, q0, q1);
  DUP4_ARG2(__lsx_vilvl_b, zero, p0, zero, p1, zero, q0, zero, q1,
            p0_l, p1_l, q0_l, q1_l);
  // Calculate condition mask
  DUP2_ARG2(__lsx_vabsd_bu, p0, q0, p1, p0, bDetaP0Q0, bDetaP1P0);
  bDetaQ1Q0 = __lsx_vabsd_bu(q1, q0);
  DUP2_ARG2(__lsx_vslt_bu, bDetaP0Q0, alpha, bDetaP1P0, beta, bDetaP0Q0, bDetaP1P0);
  bDetaQ1Q0 = __lsx_vslt_bu(bDetaQ1Q0, beta);
  DUP2_ARG2(__lsx_vand_v, bDetaP0Q0, bDetaP1P0, bDetaQ1Q0, flags, flags, flags);

  // Calculate the low part
  // WELS_CLIP3 ((((q0 - p0) * (1 << 2)) + (p1 - q1) + 4) >> 3, -iTc0, iTc0)
  iDeta_l = __lsx_vsub_h(q0_l, p0_l);
  iDeta_l = __lsx_vslli_h(iDeta_l, 2);
  iDeta_l = __lsx_vadd_h(iDeta_l, p1_l);
  iDeta_l = __lsx_vsub_h(iDeta_l, q1_l);
  iDeta_l = __lsx_vaddi_hu(iDeta_l, 4);
  iDeta_l = __lsx_vsrai_h(iDeta_l, 3);
  iDeta_l = __lsx_vmin_h(iTc0_l, iDeta_l);
  iDeta_l = __lsx_vmax_h(negiTc0_l, iDeta_l);

  // WelsClip1 (p0 + iDeta)
  p0_l = __lsx_vadd_h(p0_l, iDeta_l);
  p1_l = __lsx_vand_v(p0_l, not_255);
  p2_l = __lsx_vsle_h(zero, p0_l);
  flag = __lsx_vseq_h(p1_l, zero);
  p0_l = __lsx_vand_v(p0_l, flag);
  flag = __lsx_vnor_v(flag,flag);
  p2_l = __lsx_vand_v(p2_l, flag);
  p0_l = __lsx_vadd_h(p0_l, p2_l);

  // WelsClip1 (q0 - iDeta)
  q0_l = __lsx_vsub_h(q0_l, iDeta_l);
  q1_l = __lsx_vand_v(q0_l, not_255);
  q2_l = __lsx_vsle_h(zero, q0_l);
  flag = __lsx_vseq_h(q1_l, zero);
  q0_l = __lsx_vand_v(q0_l, flag);
  flag = __lsx_vnor_v(flag, flag);
  q2_l = __lsx_vand_v(q2_l, flag);
  q0_l = __lsx_vadd_h(q0_l, q2_l);

  DUP2_ARG2(__lsx_vpickev_b, zero, p0_l, zero, q0_l, t0, t1);
  flag = __lsx_vsle_b(zero, iTc0);
  flag = __lsx_vand_v(flag, flags);
  t0 = __lsx_vand_v(t0, flag);
  tp = __lsx_vnor_v(flag,flag);
  p0 = __lsx_vand_v(p0, tp);
  p0 = __lsx_vadd_b(t0, p0);
  t1 = __lsx_vand_v(t1, flag);
  tp = __lsx_vnor_v(flag,flag);
  q0 = __lsx_vand_v(q0, tp);
  q0 = __lsx_vadd_b(t1, q0);

  // Store data to pPixCb
  __lsx_vstelm_d(p0, pPixCb - iStrideX, 0, 0);
  __lsx_vstelm_d(q0, pPixCb, 0, 0);

  // Load data from pPixCr
  DUP4_ARG2(__lsx_vldx, pPixCr, -iStrideX, pPixCr, -iStrideX_x2, pPixCr,
            iStrideX_x0, pPixCr, iStrideX, p0, p1, q0, q1);
  DUP4_ARG2(__lsx_vilvl_b, zero, p0, zero, p1, zero, q0, zero, q1,
            p0_l, p1_l, q0_l, q1_l);
  // Calculate condition mask
  DUP2_ARG2(__lsx_vabsd_bu, p0, q0, p1, p0, bDetaP0Q0, bDetaP1P0);
  bDetaQ1Q0 = __lsx_vabsd_bu(q1, q0);
  DUP2_ARG2(__lsx_vslt_bu, bDetaP0Q0, alpha, bDetaP1P0, beta, bDetaP0Q0, bDetaP1P0);
  bDetaQ1Q0 = __lsx_vslt_bu(bDetaQ1Q0, beta);
  DUP2_ARG2(__lsx_vand_v, bDetaP0Q0, bDetaP1P0, bDetaQ1Q0, flags, flags, flags);

  // Calculate the low part
  // WELS_CLIP3 ((((q0 - p0) * (1 << 2)) + (p1 - q1) + 4) >> 3, -iTc0, iTc0)
  iDeta_l = __lsx_vsub_h(q0_l, p0_l);
  iDeta_l = __lsx_vslli_h(iDeta_l, 2);
  iDeta_l = __lsx_vadd_h(iDeta_l, p1_l);
  iDeta_l = __lsx_vsub_h(iDeta_l, q1_l);
  iDeta_l = __lsx_vaddi_hu(iDeta_l, 4);
  iDeta_l = __lsx_vsrai_h(iDeta_l, 3);
  iDeta_l = __lsx_vmin_h(iTc0_l, iDeta_l);
  iDeta_l = __lsx_vmax_h(negiTc0_l, iDeta_l);

  // WelsClip1 (p0 + iDeta)
  p0_l = __lsx_vadd_h(p0_l, iDeta_l);
  p1_l = __lsx_vand_v(p0_l, not_255);
  p2_l = __lsx_vsle_h(zero, p0_l);
  flag = __lsx_vseq_h(p1_l, zero);
  p0_l = __lsx_vand_v(p0_l, flag);
  flag = __lsx_vnor_v(flag,flag);
  p2_l = __lsx_vand_v(p2_l, flag);
  p0_l = __lsx_vadd_h(p0_l, p2_l);

  // WelsClip1 (q0 - iDeta)
  q0_l = __lsx_vsub_h(q0_l, iDeta_l);
  q1_l = __lsx_vand_v(q0_l, not_255);
  q2_l = __lsx_vsle_h(zero, q0_l);
  flag = __lsx_vseq_h(q1_l, zero);
  q0_l = __lsx_vand_v(q0_l, flag);
  flag = __lsx_vnor_v(flag, flag);
  q2_l = __lsx_vand_v(q2_l, flag);
  q0_l = __lsx_vadd_h(q0_l, q2_l);

  DUP2_ARG2(__lsx_vpickev_b, zero, p0_l, zero, q0_l, t0, t1);
  flag = __lsx_vsle_b(zero, iTc0);
  flag = __lsx_vand_v(flag, flags);
  t0 = __lsx_vand_v(t0, flag);
  tp = __lsx_vnor_v(flag,flag);
  p0 = __lsx_vand_v(p0, tp);
  p0 = __lsx_vadd_b(t0, p0);
  t1 = __lsx_vand_v(t1, flag);
  tp = __lsx_vnor_v(flag,flag);
  q0 = __lsx_vand_v(q0, tp);
  q0 = __lsx_vadd_b(t1, q0);

  // Store data to pPixCr
  __lsx_vstelm_d(p0, pPixCr - iStrideX, 0, 0);
  __lsx_vstelm_d(q0, pPixCr, 0, 0);
}

void DeblockChromaLt4H_lsx (uint8_t* pPixCb, uint8_t* pPixCr, int32_t iStrideY,
                            int32_t iAlpha, int32_t iBeta, int8_t* pTc) {
  __m128i p0, p1, q0, q1, t0, t1, t2, t3, tp;
  __m128i p0_l, p1_l, p2_l, q0_l, q1_l, q2_l;
  __m128i iTc0, negiTc0, iTc0_l, negiTc0_l;
  __m128i flags, flag, iDeta_l;
  __m128i bDetaP0Q0, bDetaP1P0, bDetaQ1Q0;

  __m128i zero = __lsx_vldi(0);
  __m128i alpha = __lsx_vreplgr2vr_b(iAlpha);
  __m128i beta = __lsx_vreplgr2vr_b(iBeta);
  __m128i shuf = {0x0303020201010000, 0x0};
  __m128i not_255 = {0xff00ff00ff00ff00, 0xff00ff00ff00ff00};

  int32_t iStrideY_x0 = 0;
  int32_t iStrideY_x2 = iStrideY << 1;
  int32_t iStrideY_x3 = iStrideY_x2 + iStrideY;
  int32_t iStrideY_x4 = iStrideY << 2;

  iTc0 = __lsx_vldx(pTc, 0);
  iTc0 = __lsx_vshuf_b(iTc0, iTc0, shuf);
  negiTc0 = __lsx_vneg_b(iTc0);

  flag = __lsx_vslt_b(iTc0, zero);
  iTc0_l = __lsx_vilvl_b(flag, iTc0);
  flag = __lsx_vslt_b(negiTc0, zero);
  negiTc0_l = __lsx_vilvl_b(flag, negiTc0);

  // Load data from pPixCb
  pPixCb -= 2;
  DUP4_ARG2(__lsx_vldx, pPixCb, iStrideY_x0, pPixCb, iStrideY, pPixCb,
            iStrideY_x2, pPixCb, iStrideY_x3, p1, p0, q0, q1);
  pPixCb += iStrideY_x4;
  DUP4_ARG2(__lsx_vldx, pPixCb, iStrideY_x0, pPixCb, iStrideY, pPixCb,
            iStrideY_x2, pPixCb, iStrideY_x3, t0, t1, t2, t3);
  LSX_TRANSPOSE8x4_B(p1, p0, q0, q1, t0, t1, t2, t3, p1, p0, q0, q1);
  DUP4_ARG2(__lsx_vilvl_b, zero, p0, zero, p1, zero, q0, zero, q1,
            p0_l, p1_l, q0_l, q1_l);

  // Calculate condition mask
  DUP2_ARG2(__lsx_vabsd_bu, p0, q0, p1, p0, bDetaP0Q0, bDetaP1P0);
  bDetaQ1Q0 = __lsx_vabsd_bu(q1, q0);
  DUP2_ARG2(__lsx_vslt_bu, bDetaP0Q0, alpha, bDetaP1P0, beta, bDetaP0Q0, bDetaP1P0);
  bDetaQ1Q0 = __lsx_vslt_bu(bDetaQ1Q0, beta);
  DUP2_ARG2(__lsx_vand_v, bDetaP0Q0, bDetaP1P0, bDetaQ1Q0, flags, flags, flags);

  // Calculate the low part
  // WELS_CLIP3 ((((q0 - p0) * (1 << 2)) + (p1 - q1) + 4) >> 3, -iTc0, iTc0)
  iDeta_l = __lsx_vsub_h(q0_l, p0_l);
  iDeta_l = __lsx_vslli_h(iDeta_l, 2);
  iDeta_l = __lsx_vadd_h(iDeta_l, p1_l);
  iDeta_l = __lsx_vsub_h(iDeta_l, q1_l);
  iDeta_l = __lsx_vaddi_hu(iDeta_l, 4);
  iDeta_l = __lsx_vsrai_h(iDeta_l, 3);
  iDeta_l = __lsx_vmin_h(iTc0_l, iDeta_l);
  iDeta_l = __lsx_vmax_h(negiTc0_l, iDeta_l);

  // WelsClip1 (p0 + iDeta)
  p0_l = __lsx_vadd_h(p0_l, iDeta_l);
  p1_l = __lsx_vand_v(p0_l, not_255);
  p2_l = __lsx_vsle_h(zero, p0_l);
  flag = __lsx_vseq_h(p1_l, zero);
  p0_l = __lsx_vand_v(p0_l, flag);
  flag = __lsx_vnor_v(flag,flag);
  p2_l = __lsx_vand_v(p2_l, flag);
  p0_l = __lsx_vadd_h(p0_l, p2_l);

  // WelsClip1 (q0 - iDeta)
  q0_l = __lsx_vsub_h(q0_l, iDeta_l);
  q1_l = __lsx_vand_v(q0_l, not_255);
  q2_l = __lsx_vsle_h(zero, q0_l);
  flag = __lsx_vseq_h(q1_l, zero);
  q0_l = __lsx_vand_v(q0_l, flag);
  flag = __lsx_vnor_v(flag, flag);
  q2_l = __lsx_vand_v(q2_l, flag);
  q0_l = __lsx_vadd_h(q0_l, q2_l);

  DUP2_ARG2(__lsx_vpickev_b, zero, p0_l, zero, q0_l, t0, t1);
  flag = __lsx_vsle_b(zero, iTc0);
  flag = __lsx_vand_v(flag, flags);
  t0 = __lsx_vand_v(t0, flag);
  tp = __lsx_vnor_v(flag,flag);
  p0 = __lsx_vand_v(p0, tp);
  p0 = __lsx_vadd_b(t0, p0);
  t1 = __lsx_vand_v(t1, flag);
  tp = __lsx_vnor_v(flag,flag);
  q0 = __lsx_vand_v(q0, tp);
  q0 = __lsx_vadd_b(t1, q0);
  p0 = __lsx_vilvl_b(q0, p0);

  // Store data to pPixCb
  pPixCb -= iStrideY_x4 - 1;
  __lsx_vstelm_h(p0, pPixCb, 0, 0);
  __lsx_vstelm_h(p0, pPixCb + iStrideY, 0, 1);
  __lsx_vstelm_h(p0, pPixCb + iStrideY_x2, 0, 2);
  __lsx_vstelm_h(p0, pPixCb + iStrideY_x3, 0, 3);
  pPixCb += iStrideY_x4;
  __lsx_vstelm_h(p0, pPixCb, 0, 4);
  __lsx_vstelm_h(p0, pPixCb + iStrideY, 0, 5);
  __lsx_vstelm_h(p0, pPixCb + iStrideY_x2, 0, 6);
  __lsx_vstelm_h(p0, pPixCb + iStrideY_x3, 0, 7);

  // Load data from pPixCr
  pPixCr -= 2;
  DUP4_ARG2(__lsx_vldx, pPixCr, iStrideY_x0, pPixCr, iStrideY, pPixCr,
            iStrideY_x2, pPixCr, iStrideY_x3, p1, p0, q0, q1);
  pPixCr += iStrideY_x4;
  DUP4_ARG2(__lsx_vldx, pPixCr, iStrideY_x0, pPixCr, iStrideY, pPixCr,
            iStrideY_x2, pPixCr, iStrideY_x3, t0, t1, t2, t3);
  LSX_TRANSPOSE8x4_B(p1, p0, q0, q1, t0, t1, t2, t3, p1, p0, q0, q1);

  DUP4_ARG2(__lsx_vilvl_b, zero, p0, zero, p1, zero, q0, zero, q1,
            p0_l, p1_l, q0_l, q1_l);
  DUP2_ARG2(__lsx_vabsd_bu, p0, q0, p1, p0, bDetaP0Q0, bDetaP1P0);
  bDetaQ1Q0 = __lsx_vabsd_bu(q1, q0);
  DUP2_ARG2(__lsx_vslt_bu, bDetaP0Q0, alpha, bDetaP1P0, beta, bDetaP0Q0, bDetaP1P0);
  bDetaQ1Q0 = __lsx_vslt_bu(bDetaQ1Q0, beta);
  DUP2_ARG2(__lsx_vand_v, bDetaP0Q0, bDetaP1P0, bDetaQ1Q0, flags, flags, flags);

  // Calculate the low part
  // WELS_CLIP3 ((((q0 - p0) * (1 << 2)) + (p1 - q1) + 4) >> 3, -iTc0, iTc0)
  iDeta_l = __lsx_vsub_h(q0_l, p0_l);
  iDeta_l = __lsx_vslli_h(iDeta_l, 2);
  iDeta_l = __lsx_vadd_h(iDeta_l, p1_l);
  iDeta_l = __lsx_vsub_h(iDeta_l, q1_l);
  iDeta_l = __lsx_vaddi_hu(iDeta_l, 4);
  iDeta_l = __lsx_vsrai_h(iDeta_l, 3);
  iDeta_l = __lsx_vmin_h(iTc0_l, iDeta_l);
  iDeta_l = __lsx_vmax_h(negiTc0_l, iDeta_l);

  // WelsClip1 (p0 + iDeta)
  p0_l = __lsx_vadd_h(p0_l, iDeta_l);
  p1_l = __lsx_vand_v(p0_l, not_255);
  p2_l = __lsx_vsle_h(zero, p0_l);
  flag = __lsx_vseq_h(p1_l, zero);
  p0_l = __lsx_vand_v(p0_l, flag);
  flag = __lsx_vnor_v(flag,flag);
  p2_l = __lsx_vand_v(p2_l, flag);
  p0_l = __lsx_vadd_h(p0_l, p2_l);

  // WelsClip1 (q0 - iDeta)
  q0_l = __lsx_vsub_h(q0_l, iDeta_l);
  q1_l = __lsx_vand_v(q0_l, not_255);
  q2_l = __lsx_vsle_h(zero, q0_l);
  flag = __lsx_vseq_h(q1_l, zero);
  q0_l = __lsx_vand_v(q0_l, flag);
  flag = __lsx_vnor_v(flag, flag);
  q2_l = __lsx_vand_v(q2_l, flag);
  q0_l = __lsx_vadd_h(q0_l, q2_l);

  DUP2_ARG2(__lsx_vpickev_b, zero, p0_l, zero, q0_l, t0, t1);
  flag = __lsx_vsle_b(zero, iTc0);
  flag = __lsx_vand_v(flag, flags);
  t0 = __lsx_vand_v(t0, flag);
  tp = __lsx_vnor_v(flag,flag);
  p0 = __lsx_vand_v(p0, tp);
  p0 = __lsx_vadd_b(t0, p0);
  t1 = __lsx_vand_v(t1, flag);
  tp = __lsx_vnor_v(flag,flag);
  q0 = __lsx_vand_v(q0, tp);
  q0 = __lsx_vadd_b(t1, q0);
  p0 = __lsx_vilvl_b(q0, p0);

  // Store data to pPixCr
  pPixCr -= iStrideY_x4 - 1;
  __lsx_vstelm_h(p0, pPixCr, 0, 0);
  __lsx_vstelm_h(p0, pPixCr + iStrideY, 0, 1);
  __lsx_vstelm_h(p0, pPixCr + iStrideY_x2, 0, 2);
  __lsx_vstelm_h(p0, pPixCr + iStrideY_x3, 0, 3);
  pPixCr += iStrideY_x4;
  __lsx_vstelm_h(p0, pPixCr, 0, 4);
  __lsx_vstelm_h(p0, pPixCr + iStrideY, 0, 5);
  __lsx_vstelm_h(p0, pPixCr + iStrideY_x2, 0, 6);
  __lsx_vstelm_h(p0, pPixCr + iStrideY_x3, 0, 7);
}

void DeblockChromaEq4H_lsx (uint8_t* pPixCb, uint8_t* pPixCr, int32_t iStrideY,
                            int32_t iAlpha, int32_t iBeta) {
  __m128i p0, p1, q0, q1, t0, t1, t2, t3, tp;
  __m128i p0_l, p1_l, p2_l, q0_l, q1_l, q2_l;
  __m128i bDetaP0Q0, bDetaP1P0, bDetaQ1Q0, flags;

  __m128i zero = __lsx_vldi(0);
  __m128i alpha = __lsx_vreplgr2vr_b(iAlpha);
  __m128i beta = __lsx_vreplgr2vr_b(iBeta);

  int32_t iStrideY_x0 = 0;
  int32_t iStrideY_x2 = iStrideY << 1;
  int32_t iStrideY_x3 = iStrideY_x2 + iStrideY;
  int32_t iStrideY_x4 = iStrideY << 2;

  // Load data from pPixCb
  pPixCb -= 2;
  DUP4_ARG2(__lsx_vldx, pPixCb, iStrideY_x0, pPixCb, iStrideY, pPixCb,
            iStrideY_x2, pPixCb, iStrideY_x3, p1, p0, q0, q1);
  pPixCb += iStrideY_x4;
  DUP4_ARG2(__lsx_vldx, pPixCb, iStrideY_x0, pPixCb, iStrideY, pPixCb,
            iStrideY_x2, pPixCb, iStrideY_x3, t0, t1, t2, t3);
  LSX_TRANSPOSE8x4_B(p1, p0, q0, q1, t0, t1, t2, t3, p1, p0, q0, q1);
  DUP4_ARG2(__lsx_vilvl_b, zero, p0, zero, p1, zero, q0, zero, q1,
            p0_l, p1_l, q0_l, q1_l);

  // Calculate condition mask
  DUP2_ARG2(__lsx_vabsd_bu, p0, q0, p1, p0, bDetaP0Q0, bDetaP1P0);
  bDetaQ1Q0 = __lsx_vabsd_bu(q1, q0);
  DUP2_ARG2(__lsx_vslt_bu, bDetaP0Q0, alpha, bDetaP1P0, beta, bDetaP0Q0, bDetaP1P0);
  bDetaQ1Q0 = __lsx_vslt_bu(bDetaQ1Q0, beta);
  DUP2_ARG2(__lsx_vand_v, bDetaP0Q0, bDetaP1P0, bDetaQ1Q0, flags, flags, flags);

  // ((p1 * (1 << 1)) + p0 + q1 + 2) >> 2
  p2_l = __lsx_vslli_h(p1_l, 1);
  p2_l = __lsx_vadd_h(p2_l, p0_l);
  p2_l = __lsx_vadd_h(p2_l, q1_l);
  p2_l = __lsx_vaddi_hu(p2_l, 2);
  p2_l = __lsx_vsrai_h(p2_l, 2);

  // ((q1 * (1 << 1)) + q0 + p1 + 2) >> 2
  q2_l = __lsx_vslli_h(q1_l, 1);
  q2_l = __lsx_vadd_h(q2_l, q0_l);
  q2_l = __lsx_vadd_h(q2_l, p1_l);
  q2_l = __lsx_vaddi_hu(q2_l, 2);
  q2_l = __lsx_vsrai_h(q2_l, 2);

  DUP2_ARG2(__lsx_vpickev_b, zero, p2_l, zero, q2_l, t0, t1);
  t0 = __lsx_vand_v(t0, flags);
  tp = __lsx_vnor_v(flags,flags);
  p0 = __lsx_vand_v(p0, tp);
  p0 = __lsx_vadd_b(t0, p0);
  t1 = __lsx_vand_v(t1, flags);
  tp = __lsx_vnor_v(flags,flags);
  q0 = __lsx_vand_v(q0, tp);
  q0 = __lsx_vadd_b(t1, q0);
  p0 = __lsx_vilvl_b(q0, p0);

  // Store data to pPixCb
  pPixCb -= iStrideY_x4 - 1;
  __lsx_vstelm_h(p0, pPixCb, 0, 0);
  __lsx_vstelm_h(p0, pPixCb + iStrideY, 0, 1);
  __lsx_vstelm_h(p0, pPixCb + iStrideY_x2, 0, 2);
  __lsx_vstelm_h(p0, pPixCb + iStrideY_x3, 0, 3);
  pPixCb += iStrideY_x4;
  __lsx_vstelm_h(p0, pPixCb, 0, 4);
  __lsx_vstelm_h(p0, pPixCb + iStrideY, 0, 5);
  __lsx_vstelm_h(p0, pPixCb + iStrideY_x2, 0, 6);
  __lsx_vstelm_h(p0, pPixCb + iStrideY_x3, 0, 7);

  // Load data from pPixCr
  pPixCr -= 2;
  DUP4_ARG2(__lsx_vldx, pPixCr, iStrideY_x0, pPixCr, iStrideY, pPixCr,
            iStrideY_x2, pPixCr, iStrideY_x3, p1, p0, q0, q1);
  pPixCr += iStrideY_x4;
  DUP4_ARG2(__lsx_vldx, pPixCr, iStrideY_x0, pPixCr, iStrideY, pPixCr,
            iStrideY_x2, pPixCr, iStrideY_x3, t0, t1, t2, t3);
  LSX_TRANSPOSE8x4_B(p1, p0, q0, q1, t0, t1, t2, t3, p1, p0, q0, q1);
  DUP4_ARG2(__lsx_vilvl_b, zero, p0, zero, p1, zero, q0, zero, q1,
            p0_l, p1_l, q0_l, q1_l);

  // Calculate condition mask
  DUP2_ARG2(__lsx_vabsd_bu, p0, q0, p1, p0, bDetaP0Q0, bDetaP1P0);
  bDetaQ1Q0 = __lsx_vabsd_bu(q1, q0);
  DUP2_ARG2(__lsx_vslt_bu, bDetaP0Q0, alpha, bDetaP1P0, beta, bDetaP0Q0, bDetaP1P0);
  bDetaQ1Q0 = __lsx_vslt_bu(bDetaQ1Q0, beta);
  DUP2_ARG2(__lsx_vand_v, bDetaP0Q0, bDetaP1P0, bDetaQ1Q0, flags, flags, flags);

  // ((p1 * (1 << 1)) + p0 + q1 + 2) >> 2
  p2_l = __lsx_vslli_h(p1_l, 1);
  p2_l = __lsx_vadd_h(p2_l, p0_l);
  p2_l = __lsx_vadd_h(p2_l, q1_l);
  p2_l = __lsx_vaddi_hu(p2_l, 2);
  p2_l = __lsx_vsrai_h(p2_l, 2);

  // ((q1 * (1 << 1)) + q0 + p1 + 2) >> 2
  q2_l = __lsx_vslli_h(q1_l, 1);
  q2_l = __lsx_vadd_h(q2_l, q0_l);
  q2_l = __lsx_vadd_h(q2_l, p1_l);
  q2_l = __lsx_vaddi_hu(q2_l, 2);
  q2_l = __lsx_vsrai_h(q2_l, 2);

  DUP2_ARG2(__lsx_vpickev_b, zero, p2_l, zero, q2_l, t0, t1);
  t0 = __lsx_vand_v(t0, flags);
  tp = __lsx_vnor_v(flags,flags);
  p0 = __lsx_vand_v(p0, tp);
  p0 = __lsx_vadd_b(t0, p0);
  t1 = __lsx_vand_v(t1, flags);
  tp = __lsx_vnor_v(flags,flags);
  q0 = __lsx_vand_v(q0, tp);
  q0 = __lsx_vadd_b(t1, q0);
  p0 = __lsx_vilvl_b(q0, p0);

  // Store data to pPixCr
  pPixCr -= iStrideY_x4 - 1;
  __lsx_vstelm_h(p0, pPixCr, 0, 0);
  __lsx_vstelm_h(p0, pPixCr + iStrideY, 0, 1);
  __lsx_vstelm_h(p0, pPixCr + iStrideY_x2, 0, 2);
  __lsx_vstelm_h(p0, pPixCr + iStrideY_x3, 0, 3);
  pPixCr += iStrideY_x4;
  __lsx_vstelm_h(p0, pPixCr, 0, 4);
  __lsx_vstelm_h(p0, pPixCr + iStrideY, 0, 5);
  __lsx_vstelm_h(p0, pPixCr + iStrideY_x2, 0, 6);
  __lsx_vstelm_h(p0, pPixCr + iStrideY_x3, 0, 7);
}
