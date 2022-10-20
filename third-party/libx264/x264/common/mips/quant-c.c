/*****************************************************************************
 * quant-c.c: msa quantization and level-run
 *****************************************************************************
 * Copyright (C) 2015-2022 x264 project
 *
 * Authors: Rishikesh More <rishikesh.more@imgtec.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02111, USA.
 *
 * This program is also available under a commercial proprietary license.
 * For more information, contact us at licensing@x264.com.
 *****************************************************************************/

#include "common/common.h"
#include "macros.h"
#include "quant.h"

#if !HIGH_BIT_DEPTH
static void avc_dequant_4x4_msa( int16_t *p_dct, int32_t pi_dequant_mf[6][16],
                                 int32_t i_qp )
{
    const int32_t i_mf = i_qp % 6;
    const int32_t q_bits = i_qp / 6 - 4;
    v8i16 dct0, dct1;
    v4i32 dequant_m_f0, dequant_m_f1, dequant_m_f2, dequant_m_f3;

    LD_SH2( p_dct, 8, dct0, dct1 );

    LD_SW2( pi_dequant_mf[i_mf], 4, dequant_m_f0, dequant_m_f1 );
    LD_SW2( pi_dequant_mf[i_mf] + 8, 4, dequant_m_f2, dequant_m_f3 );

    if( q_bits >= 0 )
    {
        v8i16 dequant_mf_h0, dequant_mf_h1, q_bits_vec;

        q_bits_vec = __msa_fill_h( q_bits );

        PCKEV_H2_SH( dequant_m_f1, dequant_m_f0, dequant_m_f3, dequant_m_f2,
                     dequant_mf_h0, dequant_mf_h1 );

        dct0 *= dequant_mf_h0;
        dct1 *= dequant_mf_h1;
        dct0 <<= q_bits_vec;
        dct1 <<= q_bits_vec;
        ST_SH2( dct0, dct1, p_dct, 8 );
    }
    else
    {
        const int32_t q_bits_add = 1 << ( -q_bits - 1 );
        v4i32 dct_signed_w0, dct_signed_w1, dct_signed_w2, dct_signed_w3;
        v4i32 q_bits_vec, q_bits_vec_add;

        q_bits_vec_add = __msa_fill_w( q_bits_add );
        q_bits_vec = __msa_fill_w( -q_bits );

        UNPCK_SH_SW( dct0, dct_signed_w0, dct_signed_w1 );
        UNPCK_SH_SW( dct1, dct_signed_w2, dct_signed_w3 );

        dct_signed_w0 *= dequant_m_f0;
        dct_signed_w1 *= dequant_m_f1;
        dct_signed_w2 *= dequant_m_f2;
        dct_signed_w3 *= dequant_m_f3;
        dct_signed_w0 += q_bits_vec_add;
        dct_signed_w1 += q_bits_vec_add;
        dct_signed_w2 += q_bits_vec_add;
        dct_signed_w3 += q_bits_vec_add;

        SRA_4V( dct_signed_w0, dct_signed_w1, dct_signed_w2, dct_signed_w3,
                q_bits_vec );
        PCKEV_H2_SH( dct_signed_w1, dct_signed_w0, dct_signed_w3, dct_signed_w2,
                     dct0, dct1 );
        ST_SH2( dct0, dct1, p_dct, 8 );
    }
}

static void avc_dequant_8x8_msa( int16_t *p_dct, int32_t pi_dequant_mf[6][64],
                                 int32_t i_qp )
{
    const int32_t i_mf = i_qp % 6;
    const int32_t q_bits = i_qp / 6 - 6;
    v8i16 dct0, dct1, dct2, dct3, dct4, dct5, dct6, dct7;
    v4i32 dequant_m_f0, dequant_m_f1, dequant_m_f2, dequant_m_f3;
    v4i32 dequant_m_f4, dequant_m_f5, dequant_m_f6, dequant_m_f7;
    v4i32 dequant_m_f8, dequant_m_f9, dequant_m_f10, dequant_m_f11;
    v4i32 dequant_m_f12, dequant_m_f13, dequant_m_f14, dequant_m_f15;

    LD_SH8( p_dct, 8, dct0, dct1, dct2, dct3, dct4, dct5, dct6, dct7 );

    LD_SW2( pi_dequant_mf[i_mf], 4, dequant_m_f0, dequant_m_f1 );
    LD_SW2( pi_dequant_mf[i_mf] + 8, 4, dequant_m_f2, dequant_m_f3 );
    LD_SW2( pi_dequant_mf[i_mf] + 16, 4, dequant_m_f4, dequant_m_f5 );
    LD_SW2( pi_dequant_mf[i_mf] + 24, 4, dequant_m_f6, dequant_m_f7 );
    LD_SW2( pi_dequant_mf[i_mf] + 32, 4, dequant_m_f8, dequant_m_f9 );
    LD_SW2( pi_dequant_mf[i_mf] + 40, 4, dequant_m_f10, dequant_m_f11 );
    LD_SW2( pi_dequant_mf[i_mf] + 48, 4, dequant_m_f12, dequant_m_f13 );
    LD_SW2( pi_dequant_mf[i_mf] + 56, 4, dequant_m_f14, dequant_m_f15 );

    if( q_bits >= 0 )
    {
        v8i16 q_bits_vec;
        v8i16 dequant_mf_h0, dequant_mf_h1, dequant_mf_h2, dequant_mf_h3;
        v8i16 dequant_mf_h4, dequant_mf_h5, dequant_mf_h6, dequant_mf_h7;

        q_bits_vec = __msa_fill_h( q_bits );

        PCKEV_H4_SH( dequant_m_f1, dequant_m_f0, dequant_m_f3, dequant_m_f2,
                     dequant_m_f5, dequant_m_f4, dequant_m_f7, dequant_m_f6,
                     dequant_mf_h0, dequant_mf_h1,
                     dequant_mf_h2, dequant_mf_h3 );
        PCKEV_H4_SH( dequant_m_f9, dequant_m_f8, dequant_m_f11, dequant_m_f10,
                     dequant_m_f13, dequant_m_f12, dequant_m_f15, dequant_m_f14,
                     dequant_mf_h4, dequant_mf_h5,
                     dequant_mf_h6, dequant_mf_h7 );

        dct0 *= dequant_mf_h0;
        dct1 *= dequant_mf_h1;
        dct2 *= dequant_mf_h2;
        dct3 *= dequant_mf_h3;
        dct4 *= dequant_mf_h4;
        dct5 *= dequant_mf_h5;
        dct6 *= dequant_mf_h6;
        dct7 *= dequant_mf_h7;

        SLLI_4V( dct0, dct1, dct2, dct3, q_bits_vec );
        SLLI_4V( dct4, dct5, dct6, dct7, q_bits_vec );

        ST_SH8( dct0, dct1, dct2, dct3, dct4, dct5, dct6, dct7, p_dct, 8 );
    }
    else
    {
        const int32_t q_bits_add = 1 << ( -q_bits - 1 );
        v4i32 dct_signed_w0, dct_signed_w1, dct_signed_w2, dct_signed_w3;
        v4i32 dct_signed_w4, dct_signed_w5, dct_signed_w6, dct_signed_w7;
        v4i32 dct_signed_w8, dct_signed_w9, dct_signed_w10, dct_signed_w11;
        v4i32 dct_signed_w12, dct_signed_w13, dct_signed_w14, dct_signed_w15;
        v4i32 q_bits_vec, q_bits_vec_add;

        q_bits_vec_add = __msa_fill_w( q_bits_add );
        q_bits_vec = __msa_fill_w( -q_bits );

        UNPCK_SH_SW( dct0, dct_signed_w0, dct_signed_w1 );
        UNPCK_SH_SW( dct1, dct_signed_w2, dct_signed_w3 );
        UNPCK_SH_SW( dct2, dct_signed_w4, dct_signed_w5 );
        UNPCK_SH_SW( dct3, dct_signed_w6, dct_signed_w7 );
        UNPCK_SH_SW( dct4, dct_signed_w8, dct_signed_w9 );
        UNPCK_SH_SW( dct5, dct_signed_w10, dct_signed_w11 );
        UNPCK_SH_SW( dct6, dct_signed_w12, dct_signed_w13 );
        UNPCK_SH_SW( dct7, dct_signed_w14, dct_signed_w15 );

        dct_signed_w0 *= dequant_m_f0;
        dct_signed_w1 *= dequant_m_f1;
        dct_signed_w2 *= dequant_m_f2;
        dct_signed_w3 *= dequant_m_f3;
        dct_signed_w4 *= dequant_m_f4;
        dct_signed_w5 *= dequant_m_f5;
        dct_signed_w6 *= dequant_m_f6;
        dct_signed_w7 *= dequant_m_f7;
        dct_signed_w8 *= dequant_m_f8;
        dct_signed_w9 *= dequant_m_f9;
        dct_signed_w10 *= dequant_m_f10;
        dct_signed_w11 *= dequant_m_f11;
        dct_signed_w12 *= dequant_m_f12;
        dct_signed_w13 *= dequant_m_f13;
        dct_signed_w14 *= dequant_m_f14;
        dct_signed_w15 *= dequant_m_f15;

        dct_signed_w0 += q_bits_vec_add;
        dct_signed_w1 += q_bits_vec_add;
        dct_signed_w2 += q_bits_vec_add;
        dct_signed_w3 += q_bits_vec_add;
        dct_signed_w4 += q_bits_vec_add;
        dct_signed_w5 += q_bits_vec_add;
        dct_signed_w6 += q_bits_vec_add;
        dct_signed_w7 += q_bits_vec_add;
        dct_signed_w8 += q_bits_vec_add;
        dct_signed_w9 += q_bits_vec_add;
        dct_signed_w10 += q_bits_vec_add;
        dct_signed_w11 += q_bits_vec_add;
        dct_signed_w12 += q_bits_vec_add;
        dct_signed_w13 += q_bits_vec_add;
        dct_signed_w14 += q_bits_vec_add;
        dct_signed_w15 += q_bits_vec_add;

        SRA_4V( dct_signed_w0, dct_signed_w1, dct_signed_w2, dct_signed_w3,
                q_bits_vec );
        SRA_4V( dct_signed_w4, dct_signed_w5, dct_signed_w6, dct_signed_w7,
                q_bits_vec );
        SRA_4V( dct_signed_w8, dct_signed_w9, dct_signed_w10, dct_signed_w11,
                q_bits_vec );
        SRA_4V( dct_signed_w12, dct_signed_w13, dct_signed_w14, dct_signed_w15,
                q_bits_vec );
        PCKEV_H4_SH( dct_signed_w1, dct_signed_w0, dct_signed_w3, dct_signed_w2,
                     dct_signed_w5, dct_signed_w4, dct_signed_w7, dct_signed_w6,
                     dct0, dct1, dct2, dct3 );
        PCKEV_H4_SH( dct_signed_w9, dct_signed_w8, dct_signed_w11,
                     dct_signed_w10, dct_signed_w13, dct_signed_w12,
                     dct_signed_w15, dct_signed_w14, dct4, dct5, dct6, dct7 );
        ST_SH8( dct0, dct1, dct2, dct3, dct4, dct5, dct6, dct7, p_dct, 8 );
    }
}

static void avc_dequant_4x4_dc_msa( int16_t *p_dct,
                                    int32_t pi_dequant_mf[6][16],
                                    int32_t i_qp )
{
    const int32_t q_bits = i_qp / 6 - 6;
    int32_t i_dmf = pi_dequant_mf[i_qp % 6][0];
    v8i16 dct0, dct1, dequant_mf_h;

    LD_SH2( p_dct, 8, dct0, dct1 );

    if( q_bits >= 0 )
    {
        i_dmf <<= q_bits;

        dequant_mf_h = __msa_fill_h( i_dmf );
        dct0 = dct0 * dequant_mf_h;
        dct1 = dct1 * dequant_mf_h;

        ST_SH2( dct0, dct1, p_dct, 8 );
    }
    else
    {
        const int32_t q_bits_add = 1 << ( -q_bits - 1 );
        v4i32 dequant_m_f, q_bits_vec, q_bits_vec_add;
        v4i32 dct_signed_w0, dct_signed_w1, dct_signed_w2, dct_signed_w3;

        q_bits_vec_add = __msa_fill_w( q_bits_add );
        q_bits_vec = __msa_fill_w( -q_bits );

        dequant_m_f = __msa_fill_w( i_dmf );

        UNPCK_SH_SW( dct0, dct_signed_w0, dct_signed_w1 );
        UNPCK_SH_SW( dct1, dct_signed_w2, dct_signed_w3 );

        dct_signed_w0 *= dequant_m_f;
        dct_signed_w1 *= dequant_m_f;
        dct_signed_w2 *= dequant_m_f;
        dct_signed_w3 *= dequant_m_f;

        dct_signed_w0 += q_bits_vec_add;
        dct_signed_w1 += q_bits_vec_add;
        dct_signed_w2 += q_bits_vec_add;
        dct_signed_w3 += q_bits_vec_add;

        SRA_4V( dct_signed_w0, dct_signed_w1, dct_signed_w2, dct_signed_w3,
                q_bits_vec );
        PCKEV_H2_SH( dct_signed_w1, dct_signed_w0, dct_signed_w3, dct_signed_w2,
                     dct0, dct1 );
        ST_SH2( dct0, dct1, p_dct, 8 );
    }
}

static int32_t avc_quant_4x4_msa( int16_t *p_dct, uint16_t *p_mf,
                                  uint16_t *p_bias )
{
    int32_t non_zero = 0;
    v8i16 dct0, dct1;
    v8i16 zero = { 0 };
    v8i16 dct0_mask, dct1_mask;
    v8i16 dct_h0, dct_h1, mf_h0, mf_h1, bias_h0, bias_h1;
    v4i32 dct_signed_w0, dct_signed_w1, dct_signed_w2, dct_signed_w3;
    v4i32 dct_w0, dct_w1, dct_w2, dct_w3;
    v4i32 mf_vec0, mf_vec1, mf_vec2, mf_vec3;
    v4i32 bias0, bias1, bias2, bias3;

    LD_SH2( p_dct, 8, dct0, dct1 );
    LD_SH2( p_bias, 8, bias_h0, bias_h1 );
    LD_SH2( p_mf, 8, mf_h0, mf_h1 );

    dct0_mask = __msa_clei_s_h( dct0, 0 );
    dct1_mask = __msa_clei_s_h( dct1, 0 );

    UNPCK_SH_SW( dct0, dct_signed_w0, dct_signed_w1 );
    UNPCK_SH_SW( dct1, dct_signed_w2, dct_signed_w3 );
    ILVR_H2_SW( zero, bias_h0, zero, bias_h1, bias0, bias2 );
    ILVL_H2_SW( zero, bias_h0, zero, bias_h1, bias1, bias3 );
    ILVR_H2_SW( zero, mf_h0, zero, mf_h1, mf_vec0, mf_vec2 );
    ILVL_H2_SW( zero, mf_h0, zero, mf_h1, mf_vec1, mf_vec3 );

    dct_w1 = __msa_add_a_w( dct_signed_w1, bias1 );
    dct_w0 = __msa_add_a_w( dct_signed_w0, bias0 );
    dct_w2 = __msa_add_a_w( dct_signed_w2, bias2 );
    dct_w3 = __msa_add_a_w( dct_signed_w3, bias3 );

    dct_w0 *= mf_vec0;
    dct_w1 *= mf_vec1;
    dct_w2 *= mf_vec2;
    dct_w3 *= mf_vec3;

    SRA_4V( dct_w0, dct_w1, dct_w2, dct_w3, 16 );
    PCKEV_H2_SH( dct_w1, dct_w0, dct_w3, dct_w2, dct_h0, dct_h1 );

    dct0 = zero - dct_h0;
    dct1 = zero - dct_h1;

    dct0 = ( v8i16 ) __msa_bmnz_v( ( v16u8 ) dct_h0, ( v16u8 ) dct0,
                                   ( v16u8 ) dct0_mask );
    dct1 = ( v8i16 ) __msa_bmnz_v( ( v16u8 ) dct_h1, ( v16u8 ) dct1,
                                   ( v16u8 ) dct1_mask );
    non_zero = HADD_SW_S32( ( v4u32 ) ( dct_h0 + dct_h1 ) );
    ST_SH2( dct0, dct1, p_dct, 8 );

    return !!non_zero;
}

static int32_t avc_quant_8x8_msa( int16_t *p_dct, uint16_t *p_mf,
                                  uint16_t *p_bias )
{
    int32_t non_zero = 0;
    v8i16 dct0, dct1, dct2, dct3;
    v8i16 zero = { 0 };
    v8i16 dct0_mask, dct1_mask, dct2_mask, dct3_mask;
    v8i16 dct_h0, dct_h1, dct_h2, dct_h3, mf_h0, mf_h1, mf_h2, mf_h3;
    v8i16 bias_h0, bias_h1, bias_h2, bias_h3;
    v4i32 dct_w0, dct_w1, dct_w2, dct_w3, dct_w4, dct_w5, dct_w6, dct_w7;
    v4i32 dct_signed_w0, dct_signed_w1, dct_signed_w2, dct_signed_w3;
    v4i32 dct_signed_w4, dct_signed_w5, dct_signed_w6, dct_signed_w7;
    v4i32 mf_vec0, mf_vec1, mf_vec2, mf_vec3;
    v4i32 mf_vec4, mf_vec5, mf_vec6, mf_vec7;
    v4i32 bias0, bias1, bias2, bias3, bias4, bias5, bias6, bias7;

    LD_SH4( p_dct, 8, dct0, dct1, dct2, dct3 );

    dct0_mask = __msa_clei_s_h( dct0, 0 );
    dct1_mask = __msa_clei_s_h( dct1, 0 );
    dct2_mask = __msa_clei_s_h( dct2, 0 );
    dct3_mask = __msa_clei_s_h( dct3, 0 );

    UNPCK_SH_SW( dct0, dct_signed_w0, dct_signed_w1 );
    UNPCK_SH_SW( dct1, dct_signed_w2, dct_signed_w3 );
    UNPCK_SH_SW( dct2, dct_signed_w4, dct_signed_w5 );
    UNPCK_SH_SW( dct3, dct_signed_w6, dct_signed_w7 );
    LD_SH4( p_bias, 8, bias_h0, bias_h1, bias_h2, bias_h3 );
    ILVR_H4_SW( zero, bias_h0, zero, bias_h1, zero, bias_h2, zero, bias_h3,
                bias0, bias2, bias4, bias6 );
    ILVL_H4_SW( zero, bias_h0, zero, bias_h1, zero, bias_h2, zero, bias_h3,
                bias1, bias3, bias5, bias7 );
    LD_SH4( p_mf, 8, mf_h0, mf_h1, mf_h2, mf_h3 );
    ILVR_H4_SW( zero, mf_h0, zero, mf_h1, zero, mf_h2, zero, mf_h3,
                mf_vec0, mf_vec2, mf_vec4, mf_vec6 );
    ILVL_H4_SW( zero, mf_h0, zero, mf_h1, zero, mf_h2, zero, mf_h3,
                mf_vec1, mf_vec3, mf_vec5, mf_vec7 );

    dct_w0 = __msa_add_a_w( dct_signed_w0, bias0 );
    dct_w1 = __msa_add_a_w( dct_signed_w1, bias1 );
    dct_w2 = __msa_add_a_w( dct_signed_w2, bias2 );
    dct_w3 = __msa_add_a_w( dct_signed_w3, bias3 );
    dct_w4 = __msa_add_a_w( dct_signed_w4, bias4 );
    dct_w5 = __msa_add_a_w( dct_signed_w5, bias5 );
    dct_w6 = __msa_add_a_w( dct_signed_w6, bias6 );
    dct_w7 = __msa_add_a_w( dct_signed_w7, bias7 );

    dct_w0 *= mf_vec0;
    dct_w1 *= mf_vec1;
    dct_w2 *= mf_vec2;
    dct_w3 *= mf_vec3;
    dct_w4 *= mf_vec4;
    dct_w5 *= mf_vec5;
    dct_w6 *= mf_vec6;
    dct_w7 *= mf_vec7;

    SRA_4V( dct_w0, dct_w1, dct_w2, dct_w3, 16 );
    SRA_4V( dct_w4, dct_w5, dct_w6, dct_w7, 16 );
    PCKEV_H4_SH( dct_w1, dct_w0, dct_w3, dct_w2, dct_w5, dct_w4, dct_w7, dct_w6,
                 dct_h0, dct_h1, dct_h2, dct_h3 );
    SUB4( zero, dct_h0, zero, dct_h1, zero, dct_h2, zero, dct_h3,
          dct0, dct1, dct2, dct3 );

    dct0 = ( v8i16 ) __msa_bmnz_v( ( v16u8 ) dct_h0,
                                   ( v16u8 ) dct0, ( v16u8 ) dct0_mask );
    dct1 = ( v8i16 ) __msa_bmnz_v( ( v16u8 ) dct_h1,
                                   ( v16u8 ) dct1, ( v16u8 ) dct1_mask );
    dct2 = ( v8i16 ) __msa_bmnz_v( ( v16u8 ) dct_h2,
                                   ( v16u8 ) dct2, ( v16u8 ) dct2_mask );
    dct3 = ( v8i16 ) __msa_bmnz_v( ( v16u8 ) dct_h3,
                                   ( v16u8 ) dct3, ( v16u8 ) dct3_mask );

    non_zero = HADD_SW_S32( ( v4u32 )( dct_h0 + dct_h1 + dct_h2 + dct_h3 ) );
    ST_SH4( dct0, dct1, dct2, dct3, p_dct, 8 );
    LD_SH4( p_dct + 32, 8, dct0, dct1, dct2, dct3 );

    dct0_mask = __msa_clei_s_h( dct0, 0 );
    dct1_mask = __msa_clei_s_h( dct1, 0 );
    dct2_mask = __msa_clei_s_h( dct2, 0 );
    dct3_mask = __msa_clei_s_h( dct3, 0 );

    UNPCK_SH_SW( dct0, dct_signed_w0, dct_signed_w1 );
    UNPCK_SH_SW( dct1, dct_signed_w2, dct_signed_w3 );
    UNPCK_SH_SW( dct2, dct_signed_w4, dct_signed_w5 );
    UNPCK_SH_SW( dct3, dct_signed_w6, dct_signed_w7 );
    LD_SH4( p_bias + 32, 8, bias_h0, bias_h1, bias_h2, bias_h3 );
    ILVR_H4_SW( zero, bias_h0, zero, bias_h1, zero, bias_h2, zero, bias_h3,
                bias0, bias2, bias4, bias6 );
    ILVL_H4_SW( zero, bias_h0, zero, bias_h1, zero, bias_h2, zero, bias_h3,
                bias1, bias3, bias5, bias7 );
    LD_SH4( p_mf + 32, 8, mf_h0, mf_h1, mf_h2, mf_h3 );
    ILVR_H4_SW( zero, mf_h0, zero, mf_h1, zero, mf_h2, zero, mf_h3,
                mf_vec0, mf_vec2, mf_vec4, mf_vec6 );
    ILVL_H4_SW( zero, mf_h0, zero, mf_h1, zero, mf_h2, zero, mf_h3,
                mf_vec1, mf_vec3, mf_vec5, mf_vec7 );

    dct_w0 = __msa_add_a_w( dct_signed_w0, bias0 );
    dct_w1 = __msa_add_a_w( dct_signed_w1, bias1 );
    dct_w2 = __msa_add_a_w( dct_signed_w2, bias2 );
    dct_w3 = __msa_add_a_w( dct_signed_w3, bias3 );
    dct_w4 = __msa_add_a_w( dct_signed_w4, bias4 );
    dct_w5 = __msa_add_a_w( dct_signed_w5, bias5 );
    dct_w6 = __msa_add_a_w( dct_signed_w6, bias6 );
    dct_w7 = __msa_add_a_w( dct_signed_w7, bias7 );

    dct_w0 *= mf_vec0;
    dct_w1 *= mf_vec1;
    dct_w2 *= mf_vec2;
    dct_w3 *= mf_vec3;
    dct_w4 *= mf_vec4;
    dct_w5 *= mf_vec5;
    dct_w6 *= mf_vec6;
    dct_w7 *= mf_vec7;

    SRA_4V( dct_w0, dct_w1, dct_w2, dct_w3, 16 );
    SRA_4V( dct_w4, dct_w5, dct_w6, dct_w7, 16 );
    PCKEV_H2_SH( dct_w1, dct_w0, dct_w3, dct_w2, dct_h0, dct_h1 );
    PCKEV_H2_SH( dct_w5, dct_w4, dct_w7, dct_w6, dct_h2, dct_h3 );
    SUB4( zero, dct_h0, zero, dct_h1, zero, dct_h2, zero, dct_h3,
          dct0, dct1, dct2, dct3 );

    dct0 = ( v8i16 ) __msa_bmnz_v( ( v16u8 ) dct_h0,
                                   ( v16u8 ) dct0, ( v16u8 ) dct0_mask );
    dct1 = ( v8i16 ) __msa_bmnz_v( ( v16u8 ) dct_h1,
                                   ( v16u8 ) dct1, ( v16u8 ) dct1_mask );
    dct2 = ( v8i16 ) __msa_bmnz_v( ( v16u8 ) dct_h2,
                                   ( v16u8 ) dct2, ( v16u8 ) dct2_mask );
    dct3 = ( v8i16 ) __msa_bmnz_v( ( v16u8 ) dct_h3,
                                   ( v16u8 ) dct3, ( v16u8 ) dct3_mask );

    non_zero += HADD_SW_S32( ( v4u32 ) ( dct_h0 + dct_h1 + dct_h2 + dct_h3 ) );
    ST_SH4( dct0, dct1, dct2, dct3, p_dct + 32, 8 );

    return !!non_zero;
}

static int32_t avc_quant_4x4_dc_msa( int16_t *p_dct, int32_t i_mf,
                                     int32_t i_bias )
{
    int32_t non_zero = 0;
    v8i16 dct0, dct1, dct0_mask, dct1_mask;
    v8i16 zero = { 0 };
    v8i16 dct_h0, dct_h1;
    v4i32 dct_signed_w0, dct_signed_w1, dct_signed_w2, dct_signed_w3;
    v4i32 dct_w0, dct_w1, dct_w2, dct_w3;
    v4i32 mf_vec, bias_vec;

    LD_SH2( p_dct, 8, dct0, dct1 );

    dct0_mask = __msa_clei_s_h( dct0, 0 );
    dct1_mask = __msa_clei_s_h( dct1, 0 );

    UNPCK_SH_SW( dct0, dct_signed_w0, dct_signed_w1 );
    UNPCK_SH_SW( dct1, dct_signed_w2, dct_signed_w3 );

    bias_vec = __msa_fill_w( i_bias );
    mf_vec = __msa_fill_w( i_mf );

    dct_w0 = __msa_add_a_w( dct_signed_w0, bias_vec );
    dct_w1 = __msa_add_a_w( dct_signed_w1, bias_vec );
    dct_w2 = __msa_add_a_w( dct_signed_w2, bias_vec );
    dct_w3 = __msa_add_a_w( dct_signed_w3, bias_vec );

    dct_w0 *= mf_vec;
    dct_w1 *= mf_vec;
    dct_w2 *= mf_vec;
    dct_w3 *= mf_vec;

    SRA_4V( dct_w0, dct_w1, dct_w2, dct_w3, 16 );
    PCKEV_H2_SH( dct_w1, dct_w0, dct_w3, dct_w2, dct_h0, dct_h1 );

    dct0 = zero - dct_h0;
    dct1 = zero - dct_h1;
    dct0 = ( v8i16 ) __msa_bmnz_v( ( v16u8 ) dct_h0,
                                   ( v16u8 ) dct0, ( v16u8 ) dct0_mask );
    dct1 = ( v8i16 ) __msa_bmnz_v( ( v16u8 ) dct_h1,
                                   ( v16u8 ) dct1, ( v16u8 ) dct1_mask );
    non_zero = HADD_SW_S32( ( v4u32 ) ( dct_h0 + dct_h1 ) );

    ST_SH2( dct0, dct1, p_dct, 8 );

    return !!non_zero;
}

static int32_t avc_coeff_last64_msa( int16_t *p_src )
{
    uint32_t u_res;
    v8i16 src0, src1, src2, src3, src4, src5, src6, src7;
    v8i16 tmp_h0, tmp_h1, tmp_h2, tmp_h3, tmp_h4, tmp_h5, tmp_h6, tmp_h7;
    v16u8 tmp0, tmp1, tmp2, tmp3;
    v8u16 vec0, vec1, vec2, vec3;
    v4i32 out0;
    v16u8 mask = { 1, 2, 4, 8, 16, 32, 64, 128, 1, 2, 4, 8, 16, 32, 64, 128 };

    LD_SH8( p_src, 8, src0, src1, src2, src3, src4, src5, src6, src7 );

    tmp_h0 = __msa_ceqi_h( src0, 0 );
    tmp_h1 = __msa_ceqi_h( src1, 0 );
    tmp_h2 = __msa_ceqi_h( src2, 0 );
    tmp_h3 = __msa_ceqi_h( src3, 0 );
    tmp_h4 = __msa_ceqi_h( src4, 0 );
    tmp_h5 = __msa_ceqi_h( src5, 0 );
    tmp_h6 = __msa_ceqi_h( src6, 0 );
    tmp_h7 = __msa_ceqi_h( src7, 0 );

    PCKEV_B4_UB( tmp_h1, tmp_h0, tmp_h3, tmp_h2, tmp_h5, tmp_h4, tmp_h7, tmp_h6,
                 tmp0, tmp1, tmp2, tmp3 );

    tmp0 = tmp0 & mask;
    tmp1 = tmp1 & mask;
    tmp2 = tmp2 & mask;
    tmp3 = tmp3 & mask;

    HADD_UB4_UH( tmp0, tmp1, tmp2, tmp3, vec0, vec1, vec2, vec3 );
    PCKEV_B2_UB( vec1, vec0, vec3, vec2, tmp0, tmp1 );
    HADD_UB2_UH( tmp0, tmp1, vec0, vec1 );

    tmp0 = ( v16u8 ) __msa_pckev_b( ( v16i8 ) vec1, ( v16i8 ) vec0 );
    vec0 = __msa_hadd_u_h( tmp0, tmp0 );
    tmp0 = ( v16u8 ) __msa_pckev_b( ( v16i8 ) vec0, ( v16i8 ) vec0 );
    out0 = ( v4i32 ) __msa_nloc_d( ( v2i64 ) tmp0 );
    u_res = __msa_copy_u_w( out0, 0 );

    return ( 63 - u_res );
}

static int32_t avc_coeff_last16_msa( int16_t *p_src )
{
    uint32_t u_res;
    v8i16 src0, src1;
    v8u16 tmp_h0;
    v16u8 tmp0;
    v8i16 out0, out1;
    v16i8 res0;
    v16u8 mask = { 1, 2, 4, 8, 16, 32, 64, 128, 1, 2, 4, 8, 16, 32, 64, 128 };

    LD_SH2( p_src, 8, src0, src1 );

    out0 = __msa_ceqi_h( src0, 0 );
    out1 = __msa_ceqi_h( src1, 0 );

    tmp0 = ( v16u8 ) __msa_pckev_b( ( v16i8 ) out1, ( v16i8 ) out0 );
    tmp0 = tmp0 & mask;
    tmp_h0 = __msa_hadd_u_h( tmp0, tmp0 );
    tmp0 = ( v16u8 ) __msa_pckev_b( ( v16i8 ) tmp_h0, ( v16i8 ) tmp_h0 );
    tmp_h0 = __msa_hadd_u_h( tmp0, tmp0 );
    tmp0 = ( v16u8 ) __msa_pckev_b( ( v16i8 ) tmp_h0, ( v16i8 ) tmp_h0 );
    tmp_h0 = __msa_hadd_u_h( tmp0, tmp0 );
    res0 = __msa_pckev_b( ( v16i8 ) tmp_h0, ( v16i8 ) tmp_h0 );
    out0 = __msa_nloc_h( ( v8i16 ) res0 );
    u_res = __msa_copy_u_h( out0, 0 );

    return ( 15 - u_res );
}

void x264_dequant_4x4_msa( int16_t *p_dct, int32_t pi_dequant_mf[6][16],
                           int32_t i_qp )
{
    avc_dequant_4x4_msa( p_dct, pi_dequant_mf, i_qp );
}

void x264_dequant_8x8_msa( int16_t *p_dct, int32_t pi_dequant_mf[6][64],
                           int32_t i_qp )
{
    avc_dequant_8x8_msa( p_dct, pi_dequant_mf, i_qp );
}

void x264_dequant_4x4_dc_msa( int16_t *p_dct, int32_t pi_dequant_mf[6][16],
                              int32_t i_qp )
{
    avc_dequant_4x4_dc_msa( p_dct, pi_dequant_mf, i_qp );
}

int32_t x264_quant_4x4_msa( int16_t *p_dct, uint16_t *p_mf, uint16_t *p_bias )
{
    return avc_quant_4x4_msa( p_dct, p_mf, p_bias );
}

int32_t x264_quant_4x4x4_msa( int16_t p_dct[4][16],
                              uint16_t pu_mf[16], uint16_t pu_bias[16] )
{
    int32_t i_non_zero, i_non_zero_acc = 0;

    for( int32_t j = 0; j < 4; j++  )
    {
        i_non_zero = x264_quant_4x4_msa( p_dct[j], pu_mf, pu_bias );

        i_non_zero_acc |= ( !!i_non_zero ) << j;
    }

    return i_non_zero_acc;
}

int32_t x264_quant_8x8_msa( int16_t *p_dct, uint16_t *p_mf, uint16_t *p_bias )
{
    return avc_quant_8x8_msa( p_dct, p_mf, p_bias );
}

int32_t x264_quant_4x4_dc_msa( int16_t *p_dct, int32_t i_mf, int32_t i_bias )
{
    return avc_quant_4x4_dc_msa( p_dct, i_mf, i_bias );
}

int32_t x264_coeff_last64_msa( int16_t *p_src )
{
    return avc_coeff_last64_msa( p_src );
}

int32_t x264_coeff_last16_msa( int16_t *p_src )
{
    return avc_coeff_last16_msa( p_src );
}
#endif
