/*!
 * \copy
 *     Copyright (C) 2019 Loongson Technology Co. Ltd.
 *     Contributed by Gu Xiwei(guxiwei-hf@loongson.cn)
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
 * \file    deblock_msa.c
 *
 * \brief   MIPS MSA optimizations
 *
 * \date    15/05/2020 Created
 *
 *************************************************************************************
 */

#include <stdint.h>
#include "msa_macros.h"

void DeblockLumaLt4V_msa(uint8_t *pPix, int32_t iStride, int32_t iAlpha,
                         int32_t iBeta, int8_t *pTc) {
    v16u8 p0, p1, p2, q0, q1, q2;
    v16i8 iTc, negiTc, negTc, flags, f;
    v8i16 p0_l, p0_r, p1_l, p1_r, p2_l, p2_r, q0_l, q0_r, q1_l, q1_r, q2_l, q2_r;
    v8i16 tc_l, tc_r, negTc_l, negTc_r;
    v8i16 iTc_l, iTc_r, negiTc_l, negiTc_r;
    // Use for temporary variable
    v8i16 t0, t1, t2, t3;
    v16u8 alpha, beta;
    v16u8 bDetaP0Q0, bDetaP1P0, bDetaQ1Q0, bDetaP2P0, bDetaQ2Q0;
    v16i8 const_1_b = __msa_ldi_b(1);
    v8i16 const_1_h = __msa_ldi_h(1);
    v8i16 const_4_h = __msa_ldi_h(4);
    v8i16 const_not_255_h = __msa_ldi_h(~255);
    v16i8 zero = { 0 };
    v16i8 tc = { pTc[0  >> 2], pTc[1  >> 2], pTc[2  >> 2], pTc[3  >> 2],
                 pTc[4  >> 2], pTc[5  >> 2], pTc[6  >> 2], pTc[7  >> 2],
                 pTc[8  >> 2], pTc[9  >> 2], pTc[10 >> 2], pTc[11 >> 2],
                 pTc[12 >> 2], pTc[13 >> 2], pTc[14 >> 2], pTc[15 >> 2] };
    negTc = zero - tc;
    iTc = tc;

    // Load data from pPix
    MSA_LD_V4(v16u8, pPix - 3 * iStride, iStride, p2, p1, p0, q0);
    MSA_LD_V2(v16u8, pPix + iStride, iStride, q1, q2);
    alpha = (v16u8)__msa_fill_b(iAlpha);
    beta  = (v16u8)__msa_fill_b(iBeta);

    bDetaP0Q0 = __msa_asub_u_b(p0, q0);
    bDetaP1P0 = __msa_asub_u_b(p1, p0);
    bDetaQ1Q0 = __msa_asub_u_b(q1, q0);
    bDetaP2P0 = __msa_asub_u_b(p2, p0);
    bDetaQ2Q0 = __msa_asub_u_b(q2, q0);
    bDetaP0Q0 = (v16u8)__msa_clt_u_b(bDetaP0Q0, alpha);
    bDetaP1P0 = (v16u8)__msa_clt_u_b(bDetaP1P0, beta);
    bDetaQ1Q0 = (v16u8)__msa_clt_u_b(bDetaQ1Q0, beta);
    bDetaP2P0 = (v16u8)__msa_clt_u_b(bDetaP2P0, beta);
    bDetaQ2Q0 = (v16u8)__msa_clt_u_b(bDetaQ2Q0, beta);

    // Unsigned extend p0, p1, p2, q0, q1, q2 from 8 bits to 16 bits
    MSA_ILVRL_B4(v8i16, zero, p0, zero, p1,
                 p0_r, p0_l, p1_r, p1_l);
    MSA_ILVRL_B4(v8i16, zero, p2, zero, q0,
                 p2_r, p2_l, q0_r, q0_l);
    MSA_ILVRL_B4(v8i16, zero, q1, zero, q2,
                 q1_r, q1_l, q2_r, q2_l);
    // Signed extend tc, negTc from 8 bits to 16 bits
    flags = __msa_clt_s_b(tc, zero);
    MSA_ILVRL_B2(v8i16, flags, tc, tc_r, tc_l);
    flags = __msa_clt_s_b(negTc, zero);
    MSA_ILVRL_B2(v8i16, flags, negTc, negTc_r, negTc_l);

    f = (v16i8)bDetaP0Q0 & (v16i8)bDetaP1P0 & (v16i8)bDetaQ1Q0;
    flags = f & (v16i8)bDetaP2P0;
    flags = __msa_ceq_b(flags, zero);
    iTc += ((~flags) & const_1_b);
    flags = f & (v16i8)bDetaQ2Q0;
    flags = __msa_ceq_b(flags, zero);
    iTc += ((~flags) & const_1_b);
    negiTc = zero - iTc;
    // Signed extend iTc, negiTc from 8 bits to 16 bits
    flags = __msa_clt_s_b(iTc, zero);
    MSA_ILVRL_B2(v8i16, flags, iTc, iTc_r, iTc_l);
    flags = __msa_clt_s_b(negiTc, zero);
    MSA_ILVRL_B2(v8i16, flags, negiTc, negiTc_r, negiTc_l);

    // Calculate the left part
    // p1
    t0 = (p2_l + ((p0_l + q0_l + const_1_h) >> 1) - (p1_l << 1)) >> 1;
    t0 = __msa_max_s_h(negTc_l, t0);
    t0 = __msa_min_s_h(tc_l, t0);
    t1 = p1_l + t0;
    // q1
    t0 = (q2_l + ((p0_l + q0_l + const_1_h) >> 1) - (q1_l << 1)) >> 1;
    t0 = __msa_max_s_h(negTc_l, t0);
    t0 = __msa_min_s_h(tc_l, t0);
    t2 = q1_l + t0;
    // iDeta
    t0 = (((q0_l - p0_l) << 2) + (p1_l - q1_l) + const_4_h) >> 3;
    t0 = __msa_max_s_h(negiTc_l, t0);
    t0 = __msa_min_s_h(iTc_l, t0);
    p1_l = t1;
    q1_l = t2;
    // p0
    t1 = p0_l + t0;
    t2 = t1 & const_not_255_h;
    t3 = __msa_cle_s_h((v8i16)zero, t1);
    flags = (v16i8)__msa_ceq_h(t2, (v8i16)zero);
    p0_l = (t1 & (v8i16)flags) + (t3 & (v8i16)(~flags));
    // q0
    t1 = q0_l - t0;
    t2 = t1 & const_not_255_h;
    t3 = __msa_cle_s_h((v8i16)zero, t1);
    flags = (v16i8)__msa_ceq_h(t2, (v8i16)zero);
    q0_l = (t1 & (v8i16)flags) + (t3 & (v8i16)(~flags));

    // Calculate the right part
    // p1
    t0 = (p2_r + ((p0_r + q0_r + const_1_h) >> 1) - (p1_r << 1)) >> 1;
    t0 = __msa_max_s_h(negTc_r, t0);
    t0 = __msa_min_s_h(tc_r, t0);
    t1 = p1_r + t0;
    // q1
    t0 = (q2_r + ((p0_r + q0_r + const_1_h) >> 1) - (q1_r << 1)) >> 1;
    t0 = __msa_max_s_h(negTc_r, t0);
    t0 = __msa_min_s_h(tc_r, t0);
    t2 = q1_r + t0;
    // iDeta
    t0 = (((q0_r - p0_r) << 2) + (p1_r - q1_r) + const_4_h) >> 3;
    t0 = __msa_max_s_h(negiTc_r, t0);
    t0 = __msa_min_s_h(iTc_r, t0);
    p1_r = t1;
    q1_r = t2;
    // p0
    t1 = p0_r + t0;
    t2 = t1 & const_not_255_h;
    t3 = __msa_cle_s_h((v8i16)zero, t1);
    flags = (v16i8)__msa_ceq_h(t2, (v8i16)zero);
    p0_r = (t1 & (v8i16)flags) + (t3 & (v8i16)(~flags));
    // q0
    t1 = q0_r - t0;
    t2 = t1 & const_not_255_h;
    t3 = __msa_cle_s_h((v8i16)zero, t1);
    flags = (v16i8)__msa_ceq_h(t2, (v8i16)zero);
    q0_r = (t1 & (v8i16)flags) + (t3 & (v8i16)(~flags));

    // Combined left and right
    MSA_PCKEV_B4(v8i16, p1_l, p1_r, p0_l, p0_r, q0_l, q0_r, q1_l, q1_r,
                 t0, t1, t2, t3);
    flags = (v16i8)__msa_cle_s_b(zero, tc);
    flags &= f;
    p0 = (v16u8)(((v16i8)t1 & flags) + (p0 & (~flags)));
    q0 = (v16u8)(((v16i8)t2 & flags) + (q0 & (~flags)));
    // Using t1, t2 as temporary flags
    t1 = (v8i16)(flags & (~(__msa_ceq_b((v16i8)bDetaP2P0, zero))));
    p1 = (v16u8)(t0 & t1) + (p1 & (v16u8)(~t1));
    t2 = (v8i16)(flags & (~(__msa_ceq_b((v16i8)bDetaQ2Q0, zero))));
    q1 = (v16u8)(t3 & t2) + (q1 & (v16u8)(~t2));

    // Store data to pPix
    MSA_ST_V4(v16u8, p1, p0, q0, q1, pPix - 2 * iStride, iStride);
}

void DeblockLumaEq4V_msa(uint8_t *pPix, int32_t iStride, int32_t iAlpha,
                         int32_t iBeta) {
    v16u8 p0, p1, p2, p3, q0, q1, q2, q3;
    v8i16 p0_l, p0_r, p1_l, p1_r, p2_l, p2_r, p3_l, p3_r,
          q0_l, q0_r, q1_l, q1_r, q2_l, q2_r, q3_l, q3_r;
    v8i16 t0, t1, t2, t0_con1;
    v8i16 s0, s1, s2, s0_con1;
    v16u8 alpha, beta;
    v16u8 iDetaP0Q0, bDetaP1P0, bDetaQ1Q0, bDetaP2P0, bDetaQ2Q0;
    // Condition mask
    v16u8 mask0, mask1;
    v16i8 const_2_b = __msa_ldi_b(2);
    v8i16 const_2_h = __msa_ldi_h(2);
    v8i16 const_4_h = __msa_ldi_h(4);
    v16i8 zero = { 0 };

    // Load data from pPix
    MSA_LD_V8(v16u8, pPix - 4 * iStride, iStride, p3, p2, p1, p0,
              q0, q1, q2, q3);
    // iAlpha and beta are uint8_t type
    alpha = (v16u8)__msa_fill_b(iAlpha);
    beta  = (v16u8)__msa_fill_b(iBeta);

    // iDetaP0Q0 is not bool type
    iDetaP0Q0 = __msa_asub_u_b(p0, q0);

    bDetaP1P0 = __msa_asub_u_b(p1, p0);
    bDetaQ1Q0 = __msa_asub_u_b(q1, q0);
    bDetaP2P0 = __msa_asub_u_b(p2, p0);
    bDetaQ2Q0 = __msa_asub_u_b(q2, q0);
    bDetaP1P0 = (v16u8)__msa_clt_u_b(bDetaP1P0, beta);
    bDetaQ1Q0 = (v16u8)__msa_clt_u_b(bDetaQ1Q0, beta);
    bDetaP2P0 = (v16u8)__msa_clt_u_b(bDetaP2P0, beta);
    bDetaQ2Q0 = (v16u8)__msa_clt_u_b(bDetaQ2Q0, beta);

    // Unsigned extend p0, p1, p2, p3, q0, q1, q2, q3 from 8 bits to 16 bits
    MSA_ILVRL_B4(v8i16, zero, p0, zero, p1,
                 p0_r, p0_l, p1_r, p1_l);
    MSA_ILVRL_B4(v8i16, zero, p2, zero, p3,
                 p2_r, p2_l, p3_r, p3_l);
    MSA_ILVRL_B4(v8i16, zero, q0, zero, q1,
                 q0_r, q0_l, q1_r, q1_l);
    MSA_ILVRL_B4(v8i16, zero, q2, zero, q3,
                 q2_r, q2_l, q3_r, q3_l);

    // Calculate condition mask
    // (iDetaP0Q0 < iAlpha) && bDetaP1P0 && bDetaQ1Q0
    mask0 = (v16u8)__msa_clt_u_b(iDetaP0Q0, alpha);
    mask0 &= bDetaP1P0;
    mask0 &= bDetaQ1Q0;
    // iDetaP0Q0 < ((iAlpha >> 2) + 2)
    mask1 = (v16u8)((alpha >> 2) + const_2_b);
    mask1 = (v16u8)__msa_clt_u_b(iDetaP0Q0, mask1);

    // Calculate the left part
    // p0
    t0 = (p2_l + (p1_l << 1) + (p0_l << 1) + (q0_l << 1) + q1_l + const_4_h) >> 3;
    // p1
    t1 = (p2_l + p1_l + p0_l + q0_l + const_2_h) >> 2;
    // p2
    t2 = ((p3_l << 1) + p2_l + (p2_l << 1) + p1_l + p0_l + q0_l + const_4_h) >> 3;
    // p0 condition 1
    t0_con1 = ((p1_l << 1) + p0_l + q1_l + const_2_h) >> 2;
    // q0
    s0 = (p1_l + (p0_l << 1) + (q0_l << 1) + (q1_l << 1) + q2_l + const_4_h) >> 3;
    // q1
    s1 = (p0_l + q0_l + q1_l + q2_l + const_2_h) >> 2;
    // q2
    s2 = ((q3_l << 1) + q2_l + (q2_l << 1) + q1_l + q0_l + p0_l + const_4_h) >> 3;
    // q0 condition 1
    s0_con1 = ((q1_l << 1) + q0_l + p1_l + const_2_h) >> 2;
    // Move back
    p0_l = t0;
    p1_l = t1;
    p2_l = t2;
    q0_l = s0;
    q1_l = s1;
    q2_l = s2;
    // Use p3_l, q3_l as tmp
    p3_l = t0_con1;
    q3_l = s0_con1;

    // Calculate the right part
    // p0
    t0 = (p2_r + (p1_r << 1) + (p0_r << 1) + (q0_r << 1) + q1_r + const_4_h) >> 3;
    // p1
    t1 = (p2_r + p1_r + p0_r + q0_r + const_2_h) >> 2;
    // p2
    t2 = ((p3_r << 1) + p2_r + (p2_r << 1) + p1_r + p0_r + q0_r + const_4_h) >> 3;
    // p0 condition 1
    t0_con1 = ((p1_r << 1) + p0_r + q1_r + const_2_h) >> 2;
    // q0
    s0 = (p1_r + (p0_r << 1) + (q0_r << 1) + (q1_r << 1) + q2_r + const_4_h) >> 3;
    // q1
    s1 = (p0_r + q0_r + q1_r + q2_r + const_2_h) >> 2;
    // q2
    s2 = ((q3_r << 1) + q2_r + (q2_r << 1) + q1_r + q0_r + p0_r + const_4_h) >> 3;
    // q0 condition 1
    s0_con1 = ((q1_r << 1) + q0_r + p1_r + const_2_h) >> 2;
    // Move back
    p0_r = t0;
    p1_r = t1;
    p2_r = t2;
    q0_r = s0;
    q1_r = s1;
    q2_r = s2;
    // Use p3_r, q3_r as tmp
    p3_r = t0_con1;
    q3_r = s0_con1;

    // Combined left and right
    MSA_PCKEV_B4(v8i16, p0_l, p0_r, p1_l, p1_r, p2_l, p2_r, q0_l, q0_r,
                 t0, t1, t2, s0);
    MSA_PCKEV_B4(v8i16, q1_l, q1_r, q2_l, q2_r, p3_l, p3_r, q3_l, q3_r,
                 s1, s2, t0_con1, s0_con1);
    t0 = (v8i16)(((v16u8)t0 & mask0 & mask1 & bDetaP2P0) + ((v16u8)t0_con1 &
         mask0 & mask1 & (~bDetaP2P0)) + ((v16u8)t0_con1 & mask0 & (~mask1)));
    t1 = (v8i16)((v16u8)t1 & mask0 & mask1 & bDetaP2P0);
    t2 = (v8i16)((v16u8)t2 & mask0 & mask1 & bDetaP2P0);
    s0 = (v8i16)(((v16u8)s0 & mask0 & mask1 & bDetaQ2Q0) + ((v16u8)s0_con1 &
         mask0 & mask1 & (~bDetaQ2Q0)) + ((v16u8)s0_con1 & mask0 & (~mask1)));
    s1 = (v8i16)((v16u8)s1 & mask0 & mask1 & bDetaQ2Q0);
    s2 = (v8i16)((v16u8)s2 & mask0 & mask1 & bDetaQ2Q0);
    p0 = (v16u8)t0 + (p0 & (~mask0));
    p1 = (v16u8)t1 + (p1 & ~(mask0 & mask1 & bDetaP2P0));
    p2 = (v16u8)t2 + (p2 & ~(mask0 & mask1 & bDetaP2P0));
    q0 = (v16u8)s0 + (q0 & (~mask0));
    q1 = (v16u8)s1 + (q1 & ~(mask0 & mask1 & bDetaQ2Q0));
    q2 = (v16u8)s2 + (q2 & ~(mask0 & mask1 & bDetaQ2Q0));

    // Store data to pPix
    MSA_ST_V4(v16u8, p2, p1, p0, q0, pPix - 3 * iStride, iStride);
    MSA_ST_V2(v16u8, q1, q2, pPix + iStride, iStride);
}


void DeblockLumaLt4H_msa(uint8_t* pPix, int32_t iStride, int32_t iAlpha,
                         int32_t iBeta, int8_t* pTc) {
    v16u8 p0, p1, p2, q0, q1, q2;
    v16i8 iTc, negiTc, negTc, flags, f;
    v8i16 p0_l, p0_r, p1_l, p1_r, p2_l, p2_r, q0_l, q0_r, q1_l, q1_r, q2_l, q2_r;
    v8i16 tc_l, tc_r, negTc_l, negTc_r;
    v8i16 iTc_l, iTc_r, negiTc_l, negiTc_r;
    // Use for temporary variable
    v8i16 t0, t1, t2, t3;
    v16u8 alpha, beta;
    v16u8 bDetaP0Q0, bDetaP1P0, bDetaQ1Q0, bDetaP2P0, bDetaQ2Q0;
    v16i8 const_1_b = __msa_ldi_b(1);
    v8i16 const_1_h = __msa_ldi_h(1);
    v8i16 const_4_h = __msa_ldi_h(4);
    v8i16 const_not_255_h = __msa_ldi_h(~255);
    v16i8 zero = { 0 };
    v16i8 tc = { pTc[0  >> 2], pTc[1  >> 2], pTc[2  >> 2], pTc[3  >> 2],
                 pTc[4  >> 2], pTc[5  >> 2], pTc[6  >> 2], pTc[7  >> 2],
                 pTc[8  >> 2], pTc[9  >> 2], pTc[10 >> 2], pTc[11 >> 2],
                 pTc[12 >> 2], pTc[13 >> 2], pTc[14 >> 2], pTc[15 >> 2] };
    negTc = zero - tc;
    iTc = tc;

    // Load data from pPix
    MSA_LD_V8(v8i16, pPix - 3, iStride, t0, t1, t2, t3, q1_l, q1_r, q2_l, q2_r);
    MSA_LD_V8(v8i16, pPix + 8 * iStride - 3, iStride, p0_l, p0_r, p1_l, p1_r,
              p2_l, p2_r, q0_l, q0_r);
    // Transpose 16x8 to 8x16, we just need p0, p1, p2, q0, q1, q2
    MSA_TRANSPOSE16x8_B(v16u8, t0, t1, t2, t3, q1_l, q1_r, q2_l, q2_r,
                        p0_l, p0_r, p1_l, p1_r, p2_l, p2_r, q0_l, q0_r,
                        p2, p1, p0, q0, q1, q2, alpha, beta);

    alpha = (v16u8)__msa_fill_b(iAlpha);
    beta  = (v16u8)__msa_fill_b(iBeta);

    bDetaP0Q0 = __msa_asub_u_b(p0, q0);
    bDetaP1P0 = __msa_asub_u_b(p1, p0);
    bDetaQ1Q0 = __msa_asub_u_b(q1, q0);
    bDetaP2P0 = __msa_asub_u_b(p2, p0);
    bDetaQ2Q0 = __msa_asub_u_b(q2, q0);
    bDetaP0Q0 = (v16u8)__msa_clt_u_b(bDetaP0Q0, alpha);
    bDetaP1P0 = (v16u8)__msa_clt_u_b(bDetaP1P0, beta);
    bDetaQ1Q0 = (v16u8)__msa_clt_u_b(bDetaQ1Q0, beta);
    bDetaP2P0 = (v16u8)__msa_clt_u_b(bDetaP2P0, beta);
    bDetaQ2Q0 = (v16u8)__msa_clt_u_b(bDetaQ2Q0, beta);

    // Unsigned extend p0, p1, p2, q0, q1, q2 from 8 bits to 16 bits
    MSA_ILVRL_B4(v8i16, zero, p0, zero, p1,
                 p0_r, p0_l, p1_r, p1_l);
    MSA_ILVRL_B4(v8i16, zero, p2, zero, q0,
                 p2_r, p2_l, q0_r, q0_l);
    MSA_ILVRL_B4(v8i16, zero, q1, zero, q2,
                 q1_r, q1_l, q2_r, q2_l);
    // Signed extend tc, negTc from 8 bits to 16 bits
    flags = __msa_clt_s_b(tc, zero);
    MSA_ILVRL_B2(v8i16, flags, tc, tc_r, tc_l);
    flags = __msa_clt_s_b(negTc, zero);
    MSA_ILVRL_B2(v8i16, flags, negTc, negTc_r, negTc_l);

    f = (v16i8)bDetaP0Q0 & (v16i8)bDetaP1P0 & (v16i8)bDetaQ1Q0;
    flags = f & (v16i8)bDetaP2P0;
    flags = __msa_ceq_b(flags, zero);
    iTc += ((~flags) & const_1_b);
    flags = f & (v16i8)bDetaQ2Q0;
    flags = __msa_ceq_b(flags, zero);
    iTc += ((~flags) & const_1_b);
    negiTc = zero - iTc;
    // Signed extend iTc, negiTc from 8 bits to 16 bits
    flags = __msa_clt_s_b(iTc, zero);
    MSA_ILVRL_B2(v8i16, flags, iTc, iTc_r, iTc_l);
    flags = __msa_clt_s_b(negiTc, zero);
    MSA_ILVRL_B2(v8i16, flags, negiTc, negiTc_r, negiTc_l);

    // Calculate the left part
    // p1
    t0 = (p2_l + ((p0_l + q0_l + const_1_h) >> 1) - (p1_l << 1)) >> 1;
    t0 = __msa_max_s_h(negTc_l, t0);
    t0 = __msa_min_s_h(tc_l, t0);
    t1 = p1_l + t0;
    // q1
    t0 = (q2_l + ((p0_l + q0_l + const_1_h) >> 1) - (q1_l << 1)) >> 1;
    t0 = __msa_max_s_h(negTc_l, t0);
    t0 = __msa_min_s_h(tc_l, t0);
    t2 = q1_l + t0;
    // iDeta
    t0 = (((q0_l - p0_l) << 2) + (p1_l - q1_l) + const_4_h) >> 3;
    t0 = __msa_max_s_h(negiTc_l, t0);
    t0 = __msa_min_s_h(iTc_l, t0);
    p1_l = t1;
    q1_l = t2;
    // p0
    t1 = p0_l + t0;
    t2 = t1 & const_not_255_h;
    t3 = __msa_cle_s_h((v8i16)zero, t1);
    flags = (v16i8)__msa_ceq_h(t2, (v8i16)zero);
    p0_l = (t1 & (v8i16)flags) + (t3 & (v8i16)(~flags));
    // q0
    t1 = q0_l - t0;
    t2 = t1 & const_not_255_h;
    t3 = __msa_cle_s_h((v8i16)zero, t1);
    flags = (v16i8)__msa_ceq_h(t2, (v8i16)zero);
    q0_l = (t1 & (v8i16)flags) + (t3 & (v8i16)(~flags));

    // Calculate the right part
    // p1
    t0 = (p2_r + ((p0_r + q0_r + const_1_h) >> 1) - (p1_r << 1)) >> 1;
    t0 = __msa_max_s_h(negTc_r, t0);
    t0 = __msa_min_s_h(tc_r, t0);
    t1 = p1_r + t0;
    // q1
    t0 = (q2_r + ((p0_r + q0_r + const_1_h) >> 1) - (q1_r << 1)) >> 1;
    t0 = __msa_max_s_h(negTc_r, t0);
    t0 = __msa_min_s_h(tc_r, t0);
    t2 = q1_r + t0;
    // iDeta
    t0 = (((q0_r - p0_r) << 2) + (p1_r - q1_r) + const_4_h) >> 3;
    t0 = __msa_max_s_h(negiTc_r, t0);
    t0 = __msa_min_s_h(iTc_r, t0);
    p1_r = t1;
    q1_r = t2;
    // p0
    t1 = p0_r + t0;
    t2 = t1 & const_not_255_h;
    t3 = __msa_cle_s_h((v8i16)zero, t1);
    flags = (v16i8)__msa_ceq_h(t2, (v8i16)zero);
    p0_r = (t1 & (v8i16)flags) + (t3 & (v8i16)(~flags));
    // q0
    t1 = q0_r - t0;
    t2 = t1 & const_not_255_h;
    t3 = __msa_cle_s_h((v8i16)zero, t1);
    flags = (v16i8)__msa_ceq_h(t2, (v8i16)zero);
    q0_r = (t1 & (v8i16)flags) + (t3 & (v8i16)(~flags));

    // Combined left and right
    MSA_PCKEV_B4(v8i16, p1_l, p1_r, p0_l, p0_r, q0_l, q0_r, q1_l, q1_r,
                 t0, t1, t2, t3);
    flags = (v16i8)__msa_cle_s_b(zero, tc);
    flags &= f;
    p0 = (v16u8)(((v16i8)t1 & flags) + (p0 & (~flags)));
    q0 = (v16u8)(((v16i8)t2 & flags) + (q0 & (~flags)));
    // Using t1, t2 as temporary flags
    t1 = (v8i16)(flags & (~(__msa_ceq_b((v16i8)bDetaP2P0, zero))));
    p1 = (v16u8)(t0 & t1) + (p1 & (v16u8)(~t1));
    t2 = (v8i16)(flags & (~(__msa_ceq_b((v16i8)bDetaQ2Q0, zero))));
    q1 = (v16u8)(t3 & t2) + (q1 & (v16u8)(~t2));

    MSA_ILVRL_B4(v8i16, p0, p1, q1, q0, t0, t1, t2, t3);
    MSA_ILVRL_H4(v16u8, t2, t0, t3, t1, p1, p0, q0, q1);
    // Store data to pPix
    MSA_ST_W8(p1, p0, 0, 1, 2, 3, 0, 1, 2, 3, pPix - 2, iStride);
    MSA_ST_W8(q0, q1, 0, 1, 2, 3, 0, 1, 2, 3, pPix + 8 * iStride - 2, iStride);
}

void DeblockLumaEq4H_msa(uint8_t *pPix, int32_t iStride, int32_t iAlpha,
                         int32_t iBeta) {
    v16u8 p0, p1, p2, p3, q0, q1, q2, q3;
    v8i16 p0_l, p0_r, p1_l, p1_r, p2_l, p2_r, p3_l, p3_r,
          q0_l, q0_r, q1_l, q1_r, q2_l, q2_r, q3_l, q3_r;
    v8i16 t0, t1, t2, t0_con1;
    v8i16 s0, s1, s2, s0_con1;
    v16u8 alpha, beta;
    v16u8 iDetaP0Q0, bDetaP1P0, bDetaQ1Q0, bDetaP2P0, bDetaQ2Q0;
    // Condition mask
    v16u8 mask0, mask1;
    v16i8 const_2_b = __msa_ldi_b(2);
    v8i16 const_2_h = __msa_ldi_h(2);
    v8i16 const_4_h = __msa_ldi_h(4);
    v16i8 zero = { 0 };

    // Load data from pPix
    MSA_LD_V8(v8i16, pPix - 4, iStride, p0_l, p0_r, p1_l, p1_r,
              p2_l, p2_r, p3_l, p3_r);
    MSA_LD_V8(v8i16, pPix + 8 * iStride - 4, iStride,
              q0_l, q0_r, q1_l, q1_r, q2_l, q2_r, q3_l, q3_r);
    // Transpose 16x8 to 8x16, we just need p0, p1, p2, p3, q0, q1, q2, q3
    MSA_TRANSPOSE16x8_B(v16u8, p0_l, p0_r, p1_l, p1_r, p2_l, p2_r, p3_l, p3_r,
                        q0_l, q0_r, q1_l, q1_r, q2_l, q2_r, q3_l, q3_r,
                        p3, p2, p1, p0, q0, q1, q2, q3);
    // iAlpha and beta are uint8_t type
    alpha = (v16u8)__msa_fill_b(iAlpha);
    beta  = (v16u8)__msa_fill_b(iBeta);

    // iDetaP0Q0 is not bool type
    iDetaP0Q0 = __msa_asub_u_b(p0, q0);

    bDetaP1P0 = __msa_asub_u_b(p1, p0);
    bDetaQ1Q0 = __msa_asub_u_b(q1, q0);
    bDetaP2P0 = __msa_asub_u_b(p2, p0);
    bDetaQ2Q0 = __msa_asub_u_b(q2, q0);
    bDetaP1P0 = (v16u8)__msa_clt_u_b(bDetaP1P0, beta);
    bDetaQ1Q0 = (v16u8)__msa_clt_u_b(bDetaQ1Q0, beta);
    bDetaP2P0 = (v16u8)__msa_clt_u_b(bDetaP2P0, beta);
    bDetaQ2Q0 = (v16u8)__msa_clt_u_b(bDetaQ2Q0, beta);

    // Unsigned extend p0, p1, p2, p3, q0, q1, q2, q3 from 8 bits to 16 bits
    MSA_ILVRL_B4(v8i16, zero, p0, zero, p1,
                 p0_r, p0_l, p1_r, p1_l);
    MSA_ILVRL_B4(v8i16, zero, p2, zero, p3,
                 p2_r, p2_l, p3_r, p3_l);
    MSA_ILVRL_B4(v8i16, zero, q0, zero, q1,
                 q0_r, q0_l, q1_r, q1_l);
    MSA_ILVRL_B4(v8i16, zero, q2, zero, q3,
                 q2_r, q2_l, q3_r, q3_l);

    // Calculate condition mask
    // (iDetaP0Q0 < iAlpha) && bDetaP1P0 && bDetaQ1Q0
    mask0 = (v16u8)__msa_clt_u_b(iDetaP0Q0, alpha);
    mask0 &= bDetaP1P0;
    mask0 &= bDetaQ1Q0;
    // iDetaP0Q0 < ((iAlpha >> 2) + 2)
    mask1 = (v16u8)((alpha >> 2) + const_2_b);
    mask1 = (v16u8)__msa_clt_u_b(iDetaP0Q0, mask1);

    // Calculate the left part
    // p0
    t0 = (p2_l + (p1_l << 1) + (p0_l << 1) + (q0_l << 1) + q1_l + const_4_h) >> 3;
    // p1
    t1 = (p2_l + p1_l + p0_l + q0_l + const_2_h) >> 2;
    // p2
    t2 = ((p3_l << 1) + p2_l + (p2_l << 1) + p1_l + p0_l + q0_l + const_4_h) >> 3;
    // p0 condition 1
    t0_con1 = ((p1_l << 1) + p0_l + q1_l + const_2_h) >> 2;
    // q0
    s0 = (p1_l + (p0_l << 1) + (q0_l << 1) + (q1_l << 1) + q2_l + const_4_h) >> 3;
    // q1
    s1 = (p0_l + q0_l + q1_l + q2_l + const_2_h) >> 2;
    // q2
    s2 = ((q3_l << 1) + q2_l + (q2_l << 1) + q1_l + q0_l + p0_l + const_4_h) >> 3;
    // q0 condition 1
    s0_con1 = ((q1_l << 1) + q0_l + p1_l + const_2_h) >> 2;
    // Move back
    p0_l = t0;
    p1_l = t1;
    p2_l = t2;
    q0_l = s0;
    q1_l = s1;
    q2_l = s2;
    // Use p3_l, q3_l as tmp
    p3_l = t0_con1;
    q3_l = s0_con1;

    // Calculate the right part
    // p0
    t0 = (p2_r + (p1_r << 1) + (p0_r << 1) + (q0_r << 1) + q1_r + const_4_h) >> 3;
    // p1
    t1 = (p2_r + p1_r + p0_r + q0_r + const_2_h) >> 2;
    // p2
    t2 = ((p3_r << 1) + p2_r + (p2_r << 1) + p1_r + p0_r + q0_r + const_4_h) >> 3;
    // p0 condition 1
    t0_con1 = ((p1_r << 1) + p0_r + q1_r + const_2_h) >> 2;
    // q0
    s0 = (p1_r + (p0_r << 1) + (q0_r << 1) + (q1_r << 1) + q2_r + const_4_h) >> 3;
    // q1
    s1 = (p0_r + q0_r + q1_r + q2_r + const_2_h) >> 2;
    // q2
    s2 = ((q3_r << 1) + q2_r + (q2_r << 1) + q1_r + q0_r + p0_r + const_4_h) >> 3;
    // q0 condition 1
    s0_con1 = ((q1_r << 1) + q0_r + p1_r + const_2_h) >> 2;
    // Move back
    p0_r = t0;
    p1_r = t1;
    p2_r = t2;
    q0_r = s0;
    q1_r = s1;
    q2_r = s2;
    // Use p3_r, q3_r as tmp
    p3_r = t0_con1;
    q3_r = s0_con1;

    // Combined left and right
    MSA_PCKEV_B4(v8i16, p0_l, p0_r, p1_l, p1_r, p2_l, p2_r, q0_l, q0_r,
                 t0, t1, t2, s0);
    MSA_PCKEV_B4(v8i16, q1_l, q1_r, q2_l, q2_r, p3_l, p3_r, q3_l, q3_r,
                 s1, s2, t0_con1, s0_con1);
    t0 = (v8i16)(((v16u8)t0 & mask0 & mask1 & bDetaP2P0) + ((v16u8)t0_con1 &
         mask0 & mask1 & (~bDetaP2P0)) + ((v16u8)t0_con1 & mask0 & (~mask1)));
    t1 = (v8i16)((v16u8)t1 & mask0 & mask1 & bDetaP2P0);
    t2 = (v8i16)((v16u8)t2 & mask0 & mask1 & bDetaP2P0);
    s0 = (v8i16)(((v16u8)s0 & mask0 & mask1 & bDetaQ2Q0) + ((v16u8)s0_con1 &
         mask0 & mask1 & (~bDetaQ2Q0)) + ((v16u8)s0_con1 & mask0 & (~mask1)));
    s1 = (v8i16)((v16u8)s1 & mask0 & mask1 & bDetaQ2Q0);
    s2 = (v8i16)((v16u8)s2 & mask0 & mask1 & bDetaQ2Q0);
    p0 = (v16u8)t0 + (p0 & (~mask0));
    p1 = (v16u8)t1 + (p1 & ~(mask0 & mask1 & bDetaP2P0));
    p2 = (v16u8)t2 + (p2 & ~(mask0 & mask1 & bDetaP2P0));
    q0 = (v16u8)s0 + (q0 & (~mask0));
    q1 = (v16u8)s1 + (q1 & ~(mask0 & mask1 & bDetaQ2Q0));
    q2 = (v16u8)s2 + (q2 & ~(mask0 & mask1 & bDetaQ2Q0));

    MSA_ILVRL_B4(v8i16, p1, p2, q0, p0, t0, s0, t1, s1);
    MSA_ILVRL_B2(v8i16, q2, q1, t2, s2);
    MSA_ILVRL_H4(v16u8, t1, t0, s1, s0, p2, p1, p0, q0);
    // Store data to pPix
    MSA_ST_W8(p2, p1, 0, 1, 2, 3, 0, 1, 2, 3, pPix - 3, iStride);
    MSA_ST_W8(p0, q0, 0, 1, 2, 3, 0, 1, 2, 3, pPix + 8 * iStride - 3, iStride);
    MSA_ST_H8(t2, 0, 1, 2, 3, 4, 5, 6, 7, pPix + 1, iStride);
    MSA_ST_H8(s2, 0, 1, 2, 3, 4, 5, 6, 7, pPix + 8 * iStride + 1, iStride);
}

void DeblockChromaLt4V_msa(uint8_t* pPixCb, uint8_t* pPixCr, int32_t iStride,
                           int32_t iAlpha, int32_t iBeta, int8_t* pTc) {
    v16u8 p0, p1, q0, q1;
    v8i16 p0_e, p1_e, q0_e, q1_e;
    v16i8 negTc, flags, f;
    v8i16 tc_e, negTc_e;
    // Use for temporary variable
    v8i16 t0, t1, t2, t3;
    v16u8 alpha, beta;
    v16u8 bDetaP0Q0, bDetaP1P0, bDetaQ1Q0;
    v8i16 const_4_h = __msa_ldi_h(4);
    v8i16 const_not_255_h = __msa_ldi_h(~255);
    v16i8 zero = { 0 };
    v16i8 tc = { pTc[0  >> 1], pTc[1  >> 1], pTc[2  >> 1], pTc[3  >> 1],
                 pTc[4  >> 1], pTc[5  >> 1], pTc[6  >> 1], pTc[7  >> 1] };
    negTc = zero - tc;

    alpha = (v16u8)__msa_fill_b(iAlpha);
    beta  = (v16u8)__msa_fill_b(iBeta);
    // Signed extend tc, negTc from 8 bits to 16 bits
    flags = __msa_clt_s_b(tc, zero);
    MSA_ILVR_B(v8i16, flags, tc, tc_e);
    flags = __msa_clt_s_b(negTc, zero);
    MSA_ILVR_B(v8i16, flags, negTc, negTc_e);

    // Cb
    // Load data from pPixCb
    MSA_LD_V4(v16u8, pPixCb - 2 * iStride, iStride, p1, p0, q0, q1);

    bDetaP0Q0 = __msa_asub_u_b(p0, q0);
    bDetaP1P0 = __msa_asub_u_b(p1, p0);
    bDetaQ1Q0 = __msa_asub_u_b(q1, q0);
    bDetaP0Q0 = (v16u8)__msa_clt_u_b(bDetaP0Q0, alpha);
    bDetaP1P0 = (v16u8)__msa_clt_u_b(bDetaP1P0, beta);
    bDetaQ1Q0 = (v16u8)__msa_clt_u_b(bDetaQ1Q0, beta);

    // Unsigned extend p0, p1, q0, q1 from 8 bits to 16 bits
    MSA_ILVR_B4(v8i16, zero, p0, zero, p1, zero, q0, zero, q1,
                p0_e, p1_e, q0_e, q1_e);

    f = (v16i8)bDetaP0Q0 & (v16i8)bDetaP1P0 & (v16i8)bDetaQ1Q0;

    // iDeta
    t0 = (((q0_e - p0_e) << 2) + (p1_e - q1_e) + const_4_h) >> 3;
    t0 = __msa_max_s_h(negTc_e, t0);
    t0 = __msa_min_s_h(tc_e, t0);
    // p0
    t1 = p0_e + t0;
    t2 = t1 & const_not_255_h;
    t3 = __msa_cle_s_h((v8i16)zero, t1);
    flags = (v16i8)__msa_ceq_h(t2, (v8i16)zero);
    p0_e = (t1 & (v8i16)flags) + (t3 & (v8i16)(~flags));
    // q0
    t1 = q0_e - t0;
    t2 = t1 & const_not_255_h;
    t3 = __msa_cle_s_h((v8i16)zero, t1);
    flags = (v16i8)__msa_ceq_h(t2, (v8i16)zero);
    q0_e = (t1 & (v8i16)flags) + (t3 & (v8i16)(~flags));

    MSA_PCKEV_B2(v8i16, p0_e, p0_e, q0_e, q0_e, t0, t1);
    flags = (v16i8)__msa_cle_s_b(zero, tc);
    flags &= f;
    p0 = (v16u8)(((v16i8)t0 & flags) + (p0 & (~flags)));
    q0 = (v16u8)(((v16i8)t1 & flags) + (q0 & (~flags)));
    // Store data to pPixCb
    MSA_ST_D(p0, 0, pPixCb - iStride);
    MSA_ST_D(q0, 0, pPixCb);

    // Cr
    // Load data from pPixCr
    MSA_LD_V4(v16u8, pPixCr - 2 * iStride, iStride, p1, p0, q0, q1);

    bDetaP0Q0 = __msa_asub_u_b(p0, q0);
    bDetaP1P0 = __msa_asub_u_b(p1, p0);
    bDetaQ1Q0 = __msa_asub_u_b(q1, q0);
    bDetaP0Q0 = (v16u8)__msa_clt_u_b(bDetaP0Q0, alpha);
    bDetaP1P0 = (v16u8)__msa_clt_u_b(bDetaP1P0, beta);
    bDetaQ1Q0 = (v16u8)__msa_clt_u_b(bDetaQ1Q0, beta);

    // Unsigned extend p0, p1, q0, q1 from 8 bits to 16 bits
    MSA_ILVR_B4(v8i16, zero, p0, zero, p1, zero, q0, zero, q1,
                p0_e, p1_e, q0_e, q1_e);

    f = (v16i8)bDetaP0Q0 & (v16i8)bDetaP1P0 & (v16i8)bDetaQ1Q0;

    // iDeta
    t0 = (((q0_e - p0_e) << 2) + (p1_e - q1_e) + const_4_h) >> 3;
    t0 = __msa_max_s_h(negTc_e, t0);
    t0 = __msa_min_s_h(tc_e, t0);
    // p0
    t1 = p0_e + t0;
    t2 = t1 & const_not_255_h;
    t3 = __msa_cle_s_h((v8i16)zero, t1);
    flags = (v16i8)__msa_ceq_h(t2, (v8i16)zero);
    p0_e = (t1 & (v8i16)flags) + (t3 & (v8i16)(~flags));
    // q0
    t1 = q0_e - t0;
    t2 = t1 & const_not_255_h;
    t3 = __msa_cle_s_h((v8i16)zero, t1);
    flags = (v16i8)__msa_ceq_h(t2, (v8i16)zero);
    q0_e = (t1 & (v8i16)flags) + (t3 & (v8i16)(~flags));

    MSA_PCKEV_B2(v8i16, p0_e, p0_e, q0_e, q0_e, t0, t1);
    flags = (v16i8)__msa_cle_s_b(zero, tc);
    flags &= f;
    p0 = (v16u8)(((v16i8)t0 & flags) + (p0 & (~flags)));
    q0 = (v16u8)(((v16i8)t1 & flags) + (q0 & (~flags)));
    // Store data to pPixCr
    MSA_ST_D(p0, 0, pPixCr - iStride);
    MSA_ST_D(q0, 0, pPixCr);
}

void DeblockChromaEq4V_msa(uint8_t* pPixCb, uint8_t* pPixCr, int32_t iStride,
                           int32_t iAlpha, int32_t iBeta) {
    v16u8 p0, p1, q0, q1;
    v8i16 p0_e, p1_e, q0_e, q1_e;
    v16i8 f;
    // Use for temporary variable
    v8i16 t0, t1;
    v16u8 alpha, beta;
    v16u8 bDetaP0Q0, bDetaP1P0, bDetaQ1Q0;
    v8i16 const_2_h = __msa_ldi_h(2);
    v16i8 zero = { 0 };

    alpha = (v16u8)__msa_fill_b(iAlpha);
    beta  = (v16u8)__msa_fill_b(iBeta);

    // Cb
    // Load data from pPixCb
    MSA_LD_V4(v16u8, pPixCb - 2 * iStride, iStride, p1, p0, q0, q1);

    bDetaP0Q0 = __msa_asub_u_b(p0, q0);
    bDetaP1P0 = __msa_asub_u_b(p1, p0);
    bDetaQ1Q0 = __msa_asub_u_b(q1, q0);
    bDetaP0Q0 = (v16u8)__msa_clt_u_b(bDetaP0Q0, alpha);
    bDetaP1P0 = (v16u8)__msa_clt_u_b(bDetaP1P0, beta);
    bDetaQ1Q0 = (v16u8)__msa_clt_u_b(bDetaQ1Q0, beta);

    // Unsigned extend p0, p1, q0, q1 from 8 bits to 16 bits
    MSA_ILVR_B4(v8i16, zero, p0, zero, p1, zero, q0, zero, q1,
                p0_e, p1_e, q0_e, q1_e);

    f = (v16i8)bDetaP0Q0 & (v16i8)bDetaP1P0 & (v16i8)bDetaQ1Q0;

    // p0
    p0_e = ((p1_e << 1) + p0_e + q1_e + const_2_h) >> 2;
    // q0
    q0_e = ((q1_e << 1) + q0_e + p1_e + const_2_h) >> 2;

    MSA_PCKEV_B2(v8i16, p0_e, p0_e, q0_e, q0_e, t0, t1);
    p0 = (v16u8)(((v16i8)t0 & f) + (p0 & (~f)));
    q0 = (v16u8)(((v16i8)t1 & f) + (q0 & (~f)));
    // Store data to pPixCb
    MSA_ST_D(p0, 0, pPixCb - iStride);
    MSA_ST_D(q0, 0, pPixCb);

    // Cr
    // Load data from pPixCr
    MSA_LD_V4(v16u8, pPixCr - 2 * iStride, iStride, p1, p0, q0, q1);

    bDetaP0Q0 = __msa_asub_u_b(p0, q0);
    bDetaP1P0 = __msa_asub_u_b(p1, p0);
    bDetaQ1Q0 = __msa_asub_u_b(q1, q0);
    bDetaP0Q0 = (v16u8)__msa_clt_u_b(bDetaP0Q0, alpha);
    bDetaP1P0 = (v16u8)__msa_clt_u_b(bDetaP1P0, beta);
    bDetaQ1Q0 = (v16u8)__msa_clt_u_b(bDetaQ1Q0, beta);

    // Unsigned extend p0, p1, q0, q1 from 8 bits to 16 bits
    MSA_ILVR_B4(v8i16, zero, p0, zero, p1, zero, q0, zero, q1,
                p0_e, p1_e, q0_e, q1_e);

    f = (v16i8)bDetaP0Q0 & (v16i8)bDetaP1P0 & (v16i8)bDetaQ1Q0;

    // p0
    p0_e = ((p1_e << 1) + p0_e + q1_e + const_2_h) >> 2;
    // q0
    q0_e = ((q1_e << 1) + q0_e + p1_e + const_2_h) >> 2;

    MSA_PCKEV_B2(v8i16, p0_e, p0_e, q0_e, q0_e, t0, t1);
    p0 = (v16u8)(((v16i8)t0 & f) + (p0 & (~f)));
    q0 = (v16u8)(((v16i8)t1 & f) + (q0 & (~f)));
    // Store data to pPixCr
    MSA_ST_D(p0, 0, pPixCr - iStride);
    MSA_ST_D(q0, 0, pPixCr);
}

void DeblockChromaLt4H_msa(uint8_t* pPixCb, uint8_t* pPixCr, int32_t iStride,
                           int32_t iAlpha, int32_t iBeta, int8_t* pTc) {
    v16u8 p0, p1, q0, q1;
    v8i16 p0_e, p1_e, q0_e, q1_e;
    v16i8 negTc, flags, f;
    v8i16 tc_e, negTc_e;
    // Use for temporary variable
    v8i16 t0, t1, t2, t3;
    v16u8 alpha, beta;
    v16u8 bDetaP0Q0, bDetaP1P0, bDetaQ1Q0;
    v8i16 const_4_h = __msa_ldi_h(4);
    v8i16 const_not_255_h = __msa_ldi_h(~255);
    v16i8 zero = { 0 };
    v16i8 tc = { pTc[0  >> 1], pTc[1  >> 1], pTc[2  >> 1], pTc[3  >> 1],
                 pTc[4  >> 1], pTc[5  >> 1], pTc[6  >> 1], pTc[7  >> 1] };
    negTc = zero - tc;

    alpha = (v16u8)__msa_fill_b(iAlpha);
    beta  = (v16u8)__msa_fill_b(iBeta);
    // Signed extend tc, negTc from 8 bits to 16 bits
    flags = __msa_clt_s_b(tc, zero);
    MSA_ILVR_B(v8i16, flags, tc, tc_e);
    flags = __msa_clt_s_b(negTc, zero);
    MSA_ILVR_B(v8i16, flags, negTc, negTc_e);

    // Cb
    // Load data from pPixCb
    MSA_LD_V8(v8i16, pPixCb - 2, iStride, p1_e, p0_e, q0_e, q1_e,
              t0, t1, t2, t3);
    // Transpose 8x4 to 4x8, we just need p0, p1, q0, q1
    MSA_TRANSPOSE8x4_B(v16u8, p1_e, p0_e, q0_e, q1_e, t0, t1, t2, t3,
                       p1, p0, q0, q1);

    bDetaP0Q0 = __msa_asub_u_b(p0, q0);
    bDetaP1P0 = __msa_asub_u_b(p1, p0);
    bDetaQ1Q0 = __msa_asub_u_b(q1, q0);
    bDetaP0Q0 = (v16u8)__msa_clt_u_b(bDetaP0Q0, alpha);
    bDetaP1P0 = (v16u8)__msa_clt_u_b(bDetaP1P0, beta);
    bDetaQ1Q0 = (v16u8)__msa_clt_u_b(bDetaQ1Q0, beta);

    // Unsigned extend p0, p1, q0, q1 from 8 bits to 16 bits
    MSA_ILVR_B4(v8i16, zero, p0, zero, p1, zero, q0, zero, q1,
                p0_e, p1_e, q0_e, q1_e);

    f = (v16i8)bDetaP0Q0 & (v16i8)bDetaP1P0 & (v16i8)bDetaQ1Q0;

    // iDeta
    t0 = (((q0_e - p0_e) << 2) + (p1_e - q1_e) + const_4_h) >> 3;
    t0 = __msa_max_s_h(negTc_e, t0);
    t0 = __msa_min_s_h(tc_e, t0);
    // p0
    t1 = p0_e + t0;
    t2 = t1 & const_not_255_h;
    t3 = __msa_cle_s_h((v8i16)zero, t1);
    flags = (v16i8)__msa_ceq_h(t2, (v8i16)zero);
    p0_e = (t1 & (v8i16)flags) + (t3 & (v8i16)(~flags));
    // q0
    t1 = q0_e - t0;
    t2 = t1 & const_not_255_h;
    t3 = __msa_cle_s_h((v8i16)zero, t1);
    flags = (v16i8)__msa_ceq_h(t2, (v8i16)zero);
    q0_e = (t1 & (v8i16)flags) + (t3 & (v8i16)(~flags));

    MSA_PCKEV_B2(v8i16, p0_e, p0_e, q0_e, q0_e, t0, t1);
    flags = (v16i8)__msa_cle_s_b(zero, tc);
    flags &= f;
    p0 = (v16u8)(((v16i8)t0 & flags) + (p0 & (~flags)));
    q0 = (v16u8)(((v16i8)t1 & flags) + (q0 & (~flags)));
    // Store data to pPixCb
    MSA_ILVR_B(v16u8, q0, p0, p0);
    MSA_ST_H8(p0, 0, 1, 2, 3, 4, 5, 6, 7, pPixCb - 1, iStride);

    // Cr
    // Load data from pPixCr
    MSA_LD_V8(v8i16, pPixCr - 2, iStride, p1_e, p0_e, q0_e, q1_e,
              t0, t1, t2, t3);
    // Transpose 8x4 to 4x8, we just need p0, p1, q0, q1
    MSA_TRANSPOSE8x4_B(v16u8, p1_e, p0_e, q0_e, q1_e, t0, t1, t2, t3,
                       p1, p0, q0, q1);

    bDetaP0Q0 = __msa_asub_u_b(p0, q0);
    bDetaP1P0 = __msa_asub_u_b(p1, p0);
    bDetaQ1Q0 = __msa_asub_u_b(q1, q0);
    bDetaP0Q0 = (v16u8)__msa_clt_u_b(bDetaP0Q0, alpha);
    bDetaP1P0 = (v16u8)__msa_clt_u_b(bDetaP1P0, beta);
    bDetaQ1Q0 = (v16u8)__msa_clt_u_b(bDetaQ1Q0, beta);

    // Unsigned extend p0, p1, q0, q1 from 8 bits to 16 bits
    MSA_ILVR_B4(v8i16, zero, p0, zero, p1, zero, q0, zero, q1,
                p0_e, p1_e, q0_e, q1_e);

    f = (v16i8)bDetaP0Q0 & (v16i8)bDetaP1P0 & (v16i8)bDetaQ1Q0;

    // iDeta
    t0 = (((q0_e - p0_e) << 2) + (p1_e - q1_e) + const_4_h) >> 3;
    t0 = __msa_max_s_h(negTc_e, t0);
    t0 = __msa_min_s_h(tc_e, t0);
    // p0
    t1 = p0_e + t0;
    t2 = t1 & const_not_255_h;
    t3 = __msa_cle_s_h((v8i16)zero, t1);
    flags = (v16i8)__msa_ceq_h(t2, (v8i16)zero);
    p0_e = (t1 & (v8i16)flags) + (t3 & (v8i16)(~flags));
    // q0
    t1 = q0_e - t0;
    t2 = t1 & const_not_255_h;
    t3 = __msa_cle_s_h((v8i16)zero, t1);
    flags = (v16i8)__msa_ceq_h(t2, (v8i16)zero);
    q0_e = (t1 & (v8i16)flags) + (t3 & (v8i16)(~flags));

    MSA_PCKEV_B2(v8i16, p0_e, p0_e, q0_e, q0_e, t0, t1);
    flags = (v16i8)__msa_cle_s_b(zero, tc);
    flags &= f;
    p0 = (v16u8)(((v16i8)t0 & flags) + (p0 & (~flags)));
    q0 = (v16u8)(((v16i8)t1 & flags) + (q0 & (~flags)));
    // Store data to pPixCr
    MSA_ILVR_B(v16u8, q0, p0, p0);
    MSA_ST_H8(p0, 0, 1, 2, 3, 4, 5, 6, 7, pPixCr - 1, iStride);
}

void DeblockChromaEq4H_msa(uint8_t* pPixCb, uint8_t* pPixCr, int32_t iStride,
                           int32_t iAlpha, int32_t iBeta) {
    v16u8 p0, p1, q0, q1;
    v8i16 p0_e, p1_e, q0_e, q1_e;
    v16i8 f;
    // Use for temporary variable
    v8i16 t0, t1, t2, t3;
    v16u8 alpha, beta;
    v16u8 bDetaP0Q0, bDetaP1P0, bDetaQ1Q0;
    v8i16 const_2_h = __msa_ldi_h(2);
    v16i8 zero = { 0 };

    alpha = (v16u8)__msa_fill_b(iAlpha);
    beta  = (v16u8)__msa_fill_b(iBeta);

    // Cb
    // Load data from pPixCb
    MSA_LD_V8(v8i16, pPixCb - 2, iStride, p1_e, p0_e, q0_e, q1_e,
              t0, t1, t2, t3);
    // Transpose 8x4 to 4x8, we just need p0, p1, q0, q1
    MSA_TRANSPOSE8x4_B(v16u8, p1_e, p0_e, q0_e, q1_e, t0, t1, t2, t3,
                       p1, p0, q0, q1);

    bDetaP0Q0 = __msa_asub_u_b(p0, q0);
    bDetaP1P0 = __msa_asub_u_b(p1, p0);
    bDetaQ1Q0 = __msa_asub_u_b(q1, q0);
    bDetaP0Q0 = (v16u8)__msa_clt_u_b(bDetaP0Q0, alpha);
    bDetaP1P0 = (v16u8)__msa_clt_u_b(bDetaP1P0, beta);
    bDetaQ1Q0 = (v16u8)__msa_clt_u_b(bDetaQ1Q0, beta);

    // Unsigned extend p0, p1, q0, q1 from 8 bits to 16 bits
    MSA_ILVR_B4(v8i16, zero, p0, zero, p1, zero, q0, zero, q1,
                p0_e, p1_e, q0_e, q1_e);

    f = (v16i8)bDetaP0Q0 & (v16i8)bDetaP1P0 & (v16i8)bDetaQ1Q0;

    // p0
    p0_e = ((p1_e << 1) + p0_e + q1_e + const_2_h) >> 2;
    // q0
    q0_e = ((q1_e << 1) + q0_e + p1_e + const_2_h) >> 2;

    MSA_PCKEV_B2(v8i16, p0_e, p0_e, q0_e, q0_e, t0, t1);
    p0 = (v16u8)(((v16i8)t0 & f) + (p0 & (~f)));
    q0 = (v16u8)(((v16i8)t1 & f) + (q0 & (~f)));
    // Store data to pPixCb
    MSA_ILVR_B(v16u8, q0, p0, p0);
    MSA_ST_H8(p0, 0, 1, 2, 3, 4, 5, 6, 7, pPixCb - 1, iStride);

    // Cr
    // Load data from pPixCr
    MSA_LD_V8(v8i16, pPixCr - 2, iStride, p1_e, p0_e, q0_e, q1_e,
              t0, t1, t2, t3);
    // Transpose 8x4 to 4x8, we just need p0, p1, q0, q1
    MSA_TRANSPOSE8x4_B(v16u8, p1_e, p0_e, q0_e, q1_e, t0, t1, t2, t3,
                       p1, p0, q0, q1);

    bDetaP0Q0 = __msa_asub_u_b(p0, q0);
    bDetaP1P0 = __msa_asub_u_b(p1, p0);
    bDetaQ1Q0 = __msa_asub_u_b(q1, q0);
    bDetaP0Q0 = (v16u8)__msa_clt_u_b(bDetaP0Q0, alpha);
    bDetaP1P0 = (v16u8)__msa_clt_u_b(bDetaP1P0, beta);
    bDetaQ1Q0 = (v16u8)__msa_clt_u_b(bDetaQ1Q0, beta);

    // Unsigned extend p0, p1, q0, q1 from 8 bits to 16 bits
    MSA_ILVR_B4(v8i16, zero, p0, zero, p1, zero, q0, zero, q1,
                p0_e, p1_e, q0_e, q1_e);

    f = (v16i8)bDetaP0Q0 & (v16i8)bDetaP1P0 & (v16i8)bDetaQ1Q0;

    // p0
    p0_e = ((p1_e << 1) + p0_e + q1_e + const_2_h) >> 2;
    // q0
    q0_e = ((q1_e << 1) + q0_e + p1_e + const_2_h) >> 2;

    MSA_PCKEV_B2(v8i16, p0_e, p0_e, q0_e, q0_e, t0, t1);
    p0 = (v16u8)(((v16i8)t0 & f) + (p0 & (~f)));
    q0 = (v16u8)(((v16i8)t1 & f) + (q0 & (~f)));
    // Store data to pPixCr
    MSA_ILVR_B(v16u8, q0, p0, p0);
    MSA_ST_H8(p0, 0, 1, 2, 3, 4, 5, 6, 7, pPixCr - 1, iStride);
}

void WelsNonZeroCount_msa(int8_t* pNonZeroCount) {
    v16u8 src0, src1;
    v16u8 zero = { 0 };
    v16u8 const_1 = (v16u8)__msa_fill_b(0x01);

    MSA_LD_V2(v16u8, pNonZeroCount, 16, src0, src1);
    src0 = (v16u8)__msa_ceq_b((v16i8)zero, (v16i8)src0);
    src1 = (v16u8)__msa_ceq_b((v16i8)zero, (v16i8)src1);
    src0 += const_1;
    src1 += const_1;
    MSA_ST_V(v16u8, src0, pNonZeroCount);
    MSA_ST_D(src1, 0, pNonZeroCount + 16);
}
