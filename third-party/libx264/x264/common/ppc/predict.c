/*****************************************************************************
 * predict.c: ppc intra prediction
 *****************************************************************************
 * Copyright (C) 2007-2022 x264 project
 *
 * Authors: Guillaume Poirier <gpoirier@mplayerhq.hu>
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
#include "ppccommon.h"
#include "predict.h"
#include "pixel.h"

#if !HIGH_BIT_DEPTH
static void predict_8x8c_p_altivec( uint8_t *src )
{
    int H = 0, V = 0;

    for( int i = 0; i < 4; i++ )
    {
        H += ( i + 1 ) * ( src[4+i - FDEC_STRIDE] - src[2 - i -FDEC_STRIDE] );
        V += ( i + 1 ) * ( src[-1 +(i+4)*FDEC_STRIDE] - src[-1+(2-i)*FDEC_STRIDE] );
    }

    int a = 16 * ( src[-1+7*FDEC_STRIDE] + src[7 - FDEC_STRIDE] );
    int b = ( 17 * H + 16 ) >> 5;
    int c = ( 17 * V + 16 ) >> 5;
    int i00 = a -3*b -3*c + 16;

    vec_s16_u i00_u, b_u, c_u;
    i00_u.s[0] = i00;
    b_u.s[0]   = b;
    c_u.s[0]   = c;

    vec_u16_t val5_v = vec_splat_u16(5);
    vec_s16_t i00_v, b_v, c_v;
    i00_v = vec_splat(i00_u.v, 0);
    b_v = vec_splat(b_u.v, 0);
    c_v = vec_splat(c_u.v, 0);

    vec_s16_t induc_v  = (vec_s16_t) CV(0, 1, 2, 3, 4, 5, 6, 7);
    vec_s16_t add_i0_b_0v = vec_mladd(induc_v, b_v, i00_v);

    for( int i = 0; i < 8; ++i )
    {
        vec_s16_t shift_0_v = vec_sra(add_i0_b_0v, val5_v);
        vec_u8_t com_sat_v = vec_packsu(shift_0_v, shift_0_v);
        VEC_STORE8(com_sat_v, &src[0]);
        src += FDEC_STRIDE;
        add_i0_b_0v = vec_adds(add_i0_b_0v, c_v);
    }
}


/****************************************************************************
 * 16x16 prediction for intra luma block
 ****************************************************************************/

static void predict_16x16_p_altivec( uint8_t *src )
{
    int H = 0, V = 0;

    for( int i = 1; i <= 8; i++ )
    {
        H += i * ( src[7+i - FDEC_STRIDE ]  - src[7-i - FDEC_STRIDE ] );
        V += i * ( src[(7+i)*FDEC_STRIDE -1] - src[(7-i)*FDEC_STRIDE -1] );
    }

    int a = 16 * ( src[15*FDEC_STRIDE -1] + src[15 - FDEC_STRIDE] );
    int b = ( 5 * H + 32 ) >> 6;
    int c = ( 5 * V + 32 ) >> 6;
    int i00 = a - b * 7 - c * 7 + 16;

    vec_s16_u i00_u, b_u, c_u;
    i00_u.s[0] = i00;
    b_u.s[0]   = b;
    c_u.s[0]   = c;

    vec_u16_t val5_v = vec_splat_u16(5);
    vec_s16_t i00_v, b_v, c_v;
    i00_v = vec_splat(i00_u.v, 0);
    b_v = vec_splat(b_u.v, 0);
    c_v = vec_splat(c_u.v, 0);
    vec_s16_t induc_v  = (vec_s16_t) CV(0,  1,  2,  3,  4,  5,  6,  7);
    vec_s16_t b8_v = vec_sl(b_v, vec_splat_u16(3));
    vec_s16_t add_i0_b_0v = vec_mladd(induc_v, b_v, i00_v);
    vec_s16_t add_i0_b_8v = vec_adds(b8_v, add_i0_b_0v);

    for( int y = 0; y < 16; y++ )
    {
        vec_s16_t shift_0_v = vec_sra(add_i0_b_0v, val5_v);
        vec_s16_t shift_8_v = vec_sra(add_i0_b_8v, val5_v);
        vec_u8_t com_sat_v = vec_packsu(shift_0_v, shift_8_v);
        vec_st( com_sat_v, 0, &src[0]);
        src += FDEC_STRIDE;
        add_i0_b_0v = vec_adds(add_i0_b_0v, c_v);
        add_i0_b_8v = vec_adds(add_i0_b_8v, c_v);
    }
}

#define PREDICT_16x16_DC_ALTIVEC(v) \
for( int i = 0; i < 16; i += 2)     \
{                                   \
    vec_st(v, 0, src);              \
    vec_st(v, FDEC_STRIDE, src);    \
    src += FDEC_STRIDE*2;           \
}

static void predict_16x16_dc_altivec( uint8_t *src )
{
    uint32_t dc = 0;

    for( int i = 0; i < 16; i++ )
    {
        dc += src[-1 + i * FDEC_STRIDE];
        dc += src[i - FDEC_STRIDE];
    }
    vec_u8_u v ; v.s[0] = (( dc + 16 ) >> 5);
    vec_u8_t bc_v = vec_splat(v.v, 0);

    PREDICT_16x16_DC_ALTIVEC(bc_v);
}

static void predict_16x16_dc_left_altivec( uint8_t *src )
{
    uint32_t dc = 0;

    for( int i = 0; i < 16; i++ )
        dc += src[-1 + i * FDEC_STRIDE];
    vec_u8_u v ; v.s[0] = (( dc + 8 ) >> 4);
    vec_u8_t bc_v = vec_splat(v.v, 0);

    PREDICT_16x16_DC_ALTIVEC(bc_v);
}

static void predict_16x16_dc_top_altivec( uint8_t *src )
{
    uint32_t dc = 0;

    for( int i = 0; i < 16; i++ )
        dc += src[i - FDEC_STRIDE];
    vec_u8_u v ; v.s[0] = (( dc + 8 ) >> 4);
    vec_u8_t bc_v = vec_splat(v.v, 0);

    PREDICT_16x16_DC_ALTIVEC(bc_v);
}

static void predict_16x16_dc_128_altivec( uint8_t *src )
{
    /* test if generating the constant is faster than loading it.
    vector unsigned int bc_v = (vector unsigned int)CV(0x80808080, 0x80808080, 0x80808080, 0x80808080);
    */
    vec_u8_t bc_v = vec_vslb((vec_u8_t)vec_splat_u8(1),(vec_u8_t)vec_splat_u8(7));
    PREDICT_16x16_DC_ALTIVEC(bc_v);
}

static void predict_16x16_h_altivec( uint8_t *src )
{
    vec_u8_t v1 = vec_ld( -1, src );
    vec_u8_t v2 = vec_ld( -1, src + FDEC_STRIDE );
    vec_u8_t v3 = vec_ld( -1, src + FDEC_STRIDE * 2 );
    vec_u8_t v4 = vec_ld( -1, src + FDEC_STRIDE * 3 );

    vec_u8_t v5 = vec_ld( -1, src + FDEC_STRIDE * 4 );
    vec_u8_t v6 = vec_ld( -1, src + FDEC_STRIDE * 5 );
    vec_u8_t v7 = vec_ld( -1, src + FDEC_STRIDE * 6 );
    vec_u8_t v8 = vec_ld( -1, src + FDEC_STRIDE * 7 );

    vec_u8_t v9 = vec_ld( -1, src + FDEC_STRIDE * 8 );
    vec_u8_t vA = vec_ld( -1, src + FDEC_STRIDE * 9 );
    vec_u8_t vB = vec_ld( -1, src + FDEC_STRIDE * 10 );
    vec_u8_t vC = vec_ld( -1, src + FDEC_STRIDE * 11 );

    vec_u8_t vD = vec_ld( -1, src + FDEC_STRIDE * 12 );
    vec_u8_t vE = vec_ld( -1, src + FDEC_STRIDE * 13 );
    vec_u8_t vF = vec_ld( -1, src + FDEC_STRIDE * 14 );
    vec_u8_t vG = vec_ld( -1, src + FDEC_STRIDE * 15 );

    vec_u8_t v_v1 = vec_splat( v1, 15 );
    vec_u8_t v_v2 = vec_splat( v2, 15 );
    vec_u8_t v_v3 = vec_splat( v3, 15 );
    vec_u8_t v_v4 = vec_splat( v4, 15 );

    vec_u8_t v_v5 = vec_splat( v5, 15 );
    vec_u8_t v_v6 = vec_splat( v6, 15 );
    vec_u8_t v_v7 = vec_splat( v7, 15 );
    vec_u8_t v_v8 = vec_splat( v8, 15 );

    vec_u8_t v_v9 = vec_splat( v9, 15 );
    vec_u8_t v_vA = vec_splat( vA, 15 );
    vec_u8_t v_vB = vec_splat( vB, 15 );
    vec_u8_t v_vC = vec_splat( vC, 15 );

    vec_u8_t v_vD = vec_splat( vD, 15 );
    vec_u8_t v_vE = vec_splat( vE, 15 );
    vec_u8_t v_vF = vec_splat( vF, 15 );
    vec_u8_t v_vG = vec_splat( vG, 15 );

    vec_st( v_v1, 0, src );
    vec_st( v_v2, 0, src + FDEC_STRIDE );
    vec_st( v_v3, 0, src + FDEC_STRIDE * 2 );
    vec_st( v_v4, 0, src + FDEC_STRIDE * 3 );

    vec_st( v_v5, 0, src + FDEC_STRIDE * 4 );
    vec_st( v_v6, 0, src + FDEC_STRIDE * 5 );
    vec_st( v_v7, 0, src + FDEC_STRIDE * 6 );
    vec_st( v_v8, 0, src + FDEC_STRIDE * 7 );

    vec_st( v_v9, 0, src + FDEC_STRIDE * 8 );
    vec_st( v_vA, 0, src + FDEC_STRIDE * 9 );
    vec_st( v_vB, 0, src + FDEC_STRIDE * 10 );
    vec_st( v_vC, 0, src + FDEC_STRIDE * 11 );

    vec_st( v_vD, 0, src + FDEC_STRIDE * 12 );
    vec_st( v_vE, 0, src + FDEC_STRIDE * 13 );
    vec_st( v_vF, 0, src + FDEC_STRIDE * 14 );
    vec_st( v_vG, 0, src + FDEC_STRIDE * 15 );
}

static void predict_16x16_v_altivec( uint8_t *src )
{
    vec_u32_u v;
    v.s[0] = *(uint32_t*)&src[ 0-FDEC_STRIDE];
    v.s[1] = *(uint32_t*)&src[ 4-FDEC_STRIDE];
    v.s[2] = *(uint32_t*)&src[ 8-FDEC_STRIDE];
    v.s[3] = *(uint32_t*)&src[12-FDEC_STRIDE];

    for( int i = 0; i < 16; i++ )
    {
        vec_st(v.v, 0, (uint32_t*)src);
        src += FDEC_STRIDE;
    }
}
#endif // !HIGH_BIT_DEPTH


/****************************************************************************
 * Exported functions:
 ****************************************************************************/
void x264_predict_16x16_init_altivec( x264_predict_t pf[7] )
{
#if !HIGH_BIT_DEPTH
    pf[I_PRED_16x16_V ]      = predict_16x16_v_altivec;
    pf[I_PRED_16x16_H ]      = predict_16x16_h_altivec;
    pf[I_PRED_16x16_DC]      = predict_16x16_dc_altivec;
    pf[I_PRED_16x16_P ]      = predict_16x16_p_altivec;
    pf[I_PRED_16x16_DC_LEFT] = predict_16x16_dc_left_altivec;
    pf[I_PRED_16x16_DC_TOP ] = predict_16x16_dc_top_altivec;
    pf[I_PRED_16x16_DC_128 ] = predict_16x16_dc_128_altivec;
#endif // !HIGH_BIT_DEPTH
}

void x264_predict_8x8c_init_altivec( x264_predict_t pf[7] )
{
#if !HIGH_BIT_DEPTH
    pf[I_PRED_CHROMA_P]       = predict_8x8c_p_altivec;
#endif // !HIGH_BIT_DEPTH
}
