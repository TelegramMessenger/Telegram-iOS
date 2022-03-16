/*****************************************************************************
 * predict-c.c: msa intra prediction
 *****************************************************************************
 * Copyright (C) 2015-2022 x264 project
 *
 * Authors: Mandar Sahastrabuddhe <mandar.sahastrabuddhe@imgtec.com>
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
#include "predict.h"

#if !HIGH_BIT_DEPTH
static void intra_predict_vert_4x4_msa( uint8_t *p_src, uint8_t *p_dst,
                                        int32_t i_dst_stride )
{
    uint32_t u_src_data;

    u_src_data = LW( p_src );

    SW4( u_src_data, u_src_data, u_src_data, u_src_data, p_dst, i_dst_stride );
}

static void intra_predict_vert_8x8_msa( uint8_t *p_src, uint8_t *p_dst,
                                        int32_t i_dst_stride )
{
    uint64_t u_out;

    u_out = LD( p_src );

    SD4( u_out, u_out, u_out, u_out, p_dst, i_dst_stride );
    p_dst += ( 4 * i_dst_stride );
    SD4( u_out, u_out, u_out, u_out, p_dst, i_dst_stride );
}

static void intra_predict_vert_16x16_msa( uint8_t *p_src, uint8_t *p_dst,
                                          int32_t i_dst_stride )
{
    v16u8 src0 = LD_UB( p_src );

    ST_UB8( src0, src0, src0, src0, src0, src0, src0, src0, p_dst,
            i_dst_stride );
    p_dst += ( 8 * i_dst_stride );
    ST_UB8( src0, src0, src0, src0, src0, src0, src0, src0, p_dst,
            i_dst_stride );
}

static void intra_predict_horiz_4x4_msa( uint8_t *p_src, int32_t i_src_stride,
                                         uint8_t *p_dst, int32_t i_dst_stride )
{
    uint32_t u_out0, u_out1, u_out2, u_out3;

    u_out0 = p_src[0 * i_src_stride] * 0x01010101;
    u_out1 = p_src[1 * i_src_stride] * 0x01010101;
    u_out2 = p_src[2 * i_src_stride] * 0x01010101;
    u_out3 = p_src[3 * i_src_stride] * 0x01010101;

    SW4( u_out0, u_out1, u_out2, u_out3, p_dst, i_dst_stride );
}

static void intra_predict_horiz_8x8_msa( uint8_t *p_src, int32_t i_src_stride,
                                         uint8_t *p_dst, int32_t i_dst_stride )
{
    uint64_t u_out0, u_out1, u_out2, u_out3, u_out4, u_out5, u_out6, u_out7;

    u_out0 = p_src[0 * i_src_stride] * 0x0101010101010101ull;
    u_out1 = p_src[1 * i_src_stride] * 0x0101010101010101ull;
    u_out2 = p_src[2 * i_src_stride] * 0x0101010101010101ull;
    u_out3 = p_src[3 * i_src_stride] * 0x0101010101010101ull;
    u_out4 = p_src[4 * i_src_stride] * 0x0101010101010101ull;
    u_out5 = p_src[5 * i_src_stride] * 0x0101010101010101ull;
    u_out6 = p_src[6 * i_src_stride] * 0x0101010101010101ull;
    u_out7 = p_src[7 * i_src_stride] * 0x0101010101010101ull;

    SD4( u_out0, u_out1, u_out2, u_out3, p_dst, i_dst_stride );
    p_dst += ( 4 * i_dst_stride );
    SD4( u_out4, u_out5, u_out6, u_out7, p_dst, i_dst_stride );
}

static void intra_predict_horiz_16x16_msa( uint8_t *p_src, int32_t i_src_stride,
                                           uint8_t *p_dst,
                                           int32_t i_dst_stride )
{
    uint32_t u_row;
    uint8_t u_inp0, u_inp1, u_inp2, u_inp3;
    v16u8 src0, src1, src2, src3;

    for( u_row = 4; u_row--; )
    {
        u_inp0 = p_src[0];
        p_src += i_src_stride;
        u_inp1 = p_src[0];
        p_src += i_src_stride;
        u_inp2 = p_src[0];
        p_src += i_src_stride;
        u_inp3 = p_src[0];
        p_src += i_src_stride;

        src0 = ( v16u8 ) __msa_fill_b( u_inp0 );
        src1 = ( v16u8 ) __msa_fill_b( u_inp1 );
        src2 = ( v16u8 ) __msa_fill_b( u_inp2 );
        src3 = ( v16u8 ) __msa_fill_b( u_inp3 );

        ST_UB4( src0, src1, src2, src3, p_dst, i_dst_stride );
        p_dst += ( 4 * i_dst_stride );
    }
}

static void intra_predict_dc_4x4_msa( uint8_t *p_src_top, uint8_t *p_src_left,
                                      int32_t i_src_stride_left,
                                      uint8_t *p_dst, int32_t i_dst_stride,
                                      uint8_t is_above, uint8_t is_left )
{
    uint32_t u_row;
    uint32_t u_out, u_addition = 0;
    v16u8 src_above, store;
    v8u16 sum_above;
    v4u32 sum;

    if( is_left && is_above )
    {
        src_above = LD_UB( p_src_top );

        sum_above = __msa_hadd_u_h( src_above, src_above );
        sum = __msa_hadd_u_w( sum_above, sum_above );
        u_addition = __msa_copy_u_w( ( v4i32 ) sum, 0 );

        for( u_row = 0; u_row < 4; u_row++ )
        {
            u_addition += p_src_left[u_row * i_src_stride_left];
        }

        u_addition = ( u_addition + 4 ) >> 3;
        store = ( v16u8 ) __msa_fill_b( u_addition );
    }
    else if( is_left )
    {
        for( u_row = 0; u_row < 4; u_row++ )
        {
            u_addition += p_src_left[u_row * i_src_stride_left];
        }

        u_addition = ( u_addition + 2 ) >> 2;
        store = ( v16u8 ) __msa_fill_b( u_addition );
    }
    else if( is_above )
    {
        src_above = LD_UB( p_src_top );

        sum_above = __msa_hadd_u_h( src_above, src_above );
        sum = __msa_hadd_u_w( sum_above, sum_above );
        sum = ( v4u32 ) __msa_srari_w( ( v4i32 ) sum, 2 );
        store = ( v16u8 ) __msa_splati_b( ( v16i8 ) sum, 0 );
    }
    else
    {
        store = ( v16u8 ) __msa_ldi_b( 128 );
    }

    u_out = __msa_copy_u_w( ( v4i32 ) store, 0 );

    SW4( u_out, u_out, u_out, u_out, p_dst, i_dst_stride );
}

static void intra_predict_dc_8x8_msa( uint8_t *p_src_top, uint8_t *p_src_left,
                                      uint8_t *p_dst, int32_t i_dst_stride )
{
    uint64_t u_val0, u_val1;
    v16i8 store;
    v16u8 src = { 0 };
    v8u16 sum_h;
    v4u32 sum_w;
    v2u64 sum_d;

    u_val0 = LD( p_src_top );
    u_val1 = LD( p_src_left );
    INSERT_D2_UB( u_val0, u_val1, src );
    sum_h = __msa_hadd_u_h( src, src );
    sum_w = __msa_hadd_u_w( sum_h, sum_h );
    sum_d = __msa_hadd_u_d( sum_w, sum_w );
    sum_w = ( v4u32 ) __msa_pckev_w( ( v4i32 ) sum_d, ( v4i32 ) sum_d );
    sum_d = __msa_hadd_u_d( sum_w, sum_w );
    sum_w = ( v4u32 ) __msa_srari_w( ( v4i32 ) sum_d, 4 );
    store = __msa_splati_b( ( v16i8 ) sum_w, 0 );
    u_val0 = __msa_copy_u_d( ( v2i64 ) store, 0 );

    SD4( u_val0, u_val0, u_val0, u_val0, p_dst, i_dst_stride );
    p_dst += ( 4 * i_dst_stride );
    SD4( u_val0, u_val0, u_val0, u_val0, p_dst, i_dst_stride );
}

static void intra_predict_dc_16x16_msa( uint8_t *p_src_top, uint8_t *p_src_left,
                                        int32_t i_src_stride_left,
                                        uint8_t *p_dst, int32_t i_dst_stride,
                                        uint8_t is_above, uint8_t is_left )
{
    uint32_t u_row;
    uint32_t u_addition = 0;
    v16u8 src_above, store;
    v8u16 sum_above;
    v4u32 sum_top;
    v2u64 sum;

    if( is_left && is_above )
    {
        src_above = LD_UB( p_src_top );

        sum_above = __msa_hadd_u_h( src_above, src_above );
        sum_top = __msa_hadd_u_w( sum_above, sum_above );
        sum = __msa_hadd_u_d( sum_top, sum_top );
        sum_top = ( v4u32 ) __msa_pckev_w( ( v4i32 ) sum, ( v4i32 ) sum );
        sum = __msa_hadd_u_d( sum_top, sum_top );
        u_addition = __msa_copy_u_w( ( v4i32 ) sum, 0 );

        for( u_row = 0; u_row < 16; u_row++ )
        {
            u_addition += p_src_left[u_row * i_src_stride_left];
        }

        u_addition = ( u_addition + 16 ) >> 5;
        store = ( v16u8 ) __msa_fill_b( u_addition );
    }
    else if( is_left )
    {
        for( u_row = 0; u_row < 16; u_row++ )
        {
            u_addition += p_src_left[u_row * i_src_stride_left];
        }

        u_addition = ( u_addition + 8 ) >> 4;
        store = ( v16u8 ) __msa_fill_b( u_addition );
    }
    else if( is_above )
    {
        src_above = LD_UB( p_src_top );

        sum_above = __msa_hadd_u_h( src_above, src_above );
        sum_top = __msa_hadd_u_w( sum_above, sum_above );
        sum = __msa_hadd_u_d( sum_top, sum_top );
        sum_top = ( v4u32 ) __msa_pckev_w( ( v4i32 ) sum, ( v4i32 ) sum );
        sum = __msa_hadd_u_d( sum_top, sum_top );
        sum = ( v2u64 ) __msa_srari_d( ( v2i64 ) sum, 4 );
        store = ( v16u8 ) __msa_splati_b( ( v16i8 ) sum, 0 );
    }
    else
    {
        store = ( v16u8 ) __msa_ldi_b( 128 );
    }

    ST_UB8( store, store, store, store, store, store, store, store, p_dst,
            i_dst_stride );
    p_dst += ( 8 * i_dst_stride );
    ST_UB8( store, store, store, store, store, store, store, store, p_dst,
            i_dst_stride );
}

static void intra_predict_plane_8x8_msa( uint8_t *p_src, int32_t i_stride )
{
    uint8_t u_lpcnt;
    int32_t i_res, i_res0, i_res1, i_res2, i_res3;
    uint64_t u_out0, u_out1;
    v16i8 shf_mask = { 3, 5, 2, 6, 1, 7, 0, 8, 3, 5, 2, 6, 1, 7, 0, 8 };
    v8i16 short_multiplier = { 1, 2, 3, 4, 1, 2, 3, 4 };
    v4i32 int_multiplier = { 0, 1, 2, 3 };
    v16u8 p_src_top;
    v8i16 vec9, vec10, vec11;
    v4i32 vec0, vec1, vec2, vec3, vec4, vec5, vec6, vec7, vec8;
    v2i64 sum;

    p_src_top = LD_UB( p_src - ( i_stride + 1 ) );
    p_src_top = ( v16u8 ) __msa_vshf_b( shf_mask, ( v16i8 ) p_src_top,
                                        ( v16i8 ) p_src_top );

    vec9 = __msa_hsub_u_h( p_src_top, p_src_top );
    vec9 *= short_multiplier;
    vec8 = __msa_hadd_s_w( vec9, vec9 );
    sum = __msa_hadd_s_d( vec8, vec8 );

    i_res0 = __msa_copy_s_w( ( v4i32 ) sum, 0 );

    i_res1 = ( p_src[4 * i_stride - 1] - p_src[2 * i_stride - 1] ) +
             2 * ( p_src[5 * i_stride - 1] - p_src[i_stride - 1] ) +
             3 * ( p_src[6 * i_stride - 1] - p_src[-1] ) +
             4 * ( p_src[7 * i_stride - 1] - p_src[-i_stride - 1] );

    i_res0 *= 17;
    i_res1 *= 17;
    i_res0 = ( i_res0 + 16 ) >> 5;
    i_res1 = ( i_res1 + 16 ) >> 5;

    i_res3 = 3 * ( i_res0 + i_res1 );
    i_res2 = 16 * ( p_src[7 * i_stride - 1] + p_src[-i_stride + 7] + 1 );
    i_res = i_res2 - i_res3;

    vec8 = __msa_fill_w( i_res0 );
    vec4 = __msa_fill_w( i_res );
    vec2 = __msa_fill_w( i_res1 );
    vec5 = vec8 * int_multiplier;
    vec3 = vec8 * 4;

    for( u_lpcnt = 4; u_lpcnt--; )
    {
        vec0 = vec5;
        vec0 += vec4;
        vec1 = vec0 + vec3;
        vec6 = vec5;
        vec4 += vec2;
        vec6 += vec4;
        vec7 = vec6 + vec3;

        SRA_4V( vec0, vec1, vec6, vec7, 5 );
        PCKEV_H2_SH( vec1, vec0, vec7, vec6, vec10, vec11 );
        CLIP_SH2_0_255( vec10, vec11 );
        PCKEV_B2_SH( vec10, vec10, vec11, vec11, vec10, vec11 );

        u_out0 = __msa_copy_s_d( ( v2i64 ) vec10, 0 );
        u_out1 = __msa_copy_s_d( ( v2i64 ) vec11, 0 );
        SD( u_out0, p_src );
        p_src += i_stride;
        SD( u_out1, p_src );
        p_src += i_stride;

        vec4 += vec2;
    }
}

static void intra_predict_plane_16x16_msa( uint8_t *p_src, int32_t i_stride )
{
    uint8_t u_lpcnt;
    int32_t i_res0, i_res1, i_res2, i_res3;
    uint64_t u_load0, u_load1;
    v16i8 shf_mask = { 7, 8, 6, 9, 5, 10, 4, 11, 3, 12, 2, 13, 1, 14, 0, 15 };
    v8i16 short_multiplier = { 1, 2, 3, 4, 5, 6, 7, 8 };
    v4i32 int_multiplier = { 0, 1, 2, 3 };
    v16u8 p_src_top = { 0 };
    v8i16 vec9, vec10;
    v4i32 vec0, vec1, vec2, vec3, vec4, vec5, vec6, vec7, vec8, res_add;

    u_load0 = LD( p_src - ( i_stride + 1 ) );
    u_load1 = LD( p_src - ( i_stride + 1 ) + 9 );

    INSERT_D2_UB( u_load0, u_load1, p_src_top );

    p_src_top = ( v16u8 ) __msa_vshf_b( shf_mask, ( v16i8 ) p_src_top,
                                        ( v16i8 ) p_src_top );

    vec9 = __msa_hsub_u_h( p_src_top, p_src_top );
    vec9 *= short_multiplier;
    vec8 = __msa_hadd_s_w( vec9, vec9 );
    res_add = ( v4i32 ) __msa_hadd_s_d( vec8, vec8 );

    i_res0 = __msa_copy_s_w( res_add, 0 ) + __msa_copy_s_w( res_add, 2 );

    i_res1 = ( p_src[8 * i_stride - 1] - p_src[6 * i_stride - 1] ) +
             2 * ( p_src[9 * i_stride - 1] - p_src[5 * i_stride - 1] ) +
             3 * ( p_src[10 * i_stride - 1] - p_src[4 * i_stride - 1] ) +
             4 * ( p_src[11 * i_stride - 1] - p_src[3 * i_stride - 1] ) +
             5 * ( p_src[12 * i_stride - 1] - p_src[2 * i_stride - 1] ) +
             6 * ( p_src[13 * i_stride - 1] - p_src[i_stride - 1] ) +
             7 * ( p_src[14 * i_stride - 1] - p_src[-1] ) +
             8 * ( p_src[15 * i_stride - 1] - p_src[-1 * i_stride - 1] );

    i_res0 *= 5;
    i_res1 *= 5;
    i_res0 = ( i_res0 + 32 ) >> 6;
    i_res1 = ( i_res1 + 32 ) >> 6;

    i_res3 = 7 * ( i_res0 + i_res1 );
    i_res2 = 16 * ( p_src[15 * i_stride - 1] + p_src[-i_stride + 15] + 1 );
    i_res2 -= i_res3;

    vec8 = __msa_fill_w( i_res0 );
    vec4 = __msa_fill_w( i_res2 );
    vec5 = __msa_fill_w( i_res1 );
    vec6 = vec8 * 4;
    vec7 = vec8 * int_multiplier;

    for( u_lpcnt = 16; u_lpcnt--; )
    {
        vec0 = vec7;
        vec0 += vec4;
        vec1 = vec0 + vec6;
        vec2 = vec1 + vec6;
        vec3 = vec2 + vec6;

        SRA_4V( vec0, vec1, vec2, vec3, 5 );
        PCKEV_H2_SH( vec1, vec0, vec3, vec2, vec9, vec10 );
        CLIP_SH2_0_255( vec9, vec10 );
        PCKEV_ST_SB( vec9, vec10, p_src );
        p_src += i_stride;

        vec4 += vec5;
    }
}

static void intra_predict_dc_4blk_8x8_msa( uint8_t *p_src, int32_t i_stride )
{
    uint8_t u_lp_cnt;
    uint32_t u_src0, u_src1, u_src3, u_src2 = 0;
    uint32_t u_out0, u_out1, u_out2, u_out3;
    v16u8 p_src_top;
    v8u16 add;
    v4u32 sum;

    p_src_top = LD_UB( p_src - i_stride );
    add = __msa_hadd_u_h( ( v16u8 ) p_src_top, ( v16u8 ) p_src_top );
    sum = __msa_hadd_u_w( add, add );
    u_src0 = __msa_copy_u_w( ( v4i32 ) sum, 0 );
    u_src1 = __msa_copy_u_w( ( v4i32 ) sum, 1 );

    for( u_lp_cnt = 0; u_lp_cnt < 4; u_lp_cnt++ )
    {
        u_src0 += p_src[u_lp_cnt * i_stride - 1];
        u_src2 += p_src[( 4 + u_lp_cnt ) * i_stride - 1];
    }

    u_src0 = ( u_src0 + 4 ) >> 3;
    u_src3 = ( u_src1 + u_src2 + 4 ) >> 3;
    u_src1 = ( u_src1 + 2 ) >> 2;
    u_src2 = ( u_src2 + 2 ) >> 2;

    u_out0 = u_src0 * 0x01010101;
    u_out1 = u_src1 * 0x01010101;
    u_out2 = u_src2 * 0x01010101;
    u_out3 = u_src3 * 0x01010101;

    for( u_lp_cnt = 4; u_lp_cnt--; )
    {
        SW( u_out0, p_src );
        SW( u_out1, ( p_src + 4 ) );
        SW( u_out2, ( p_src + 4 * i_stride ) );
        SW( u_out3, ( p_src + 4 * i_stride + 4 ) );
        p_src += i_stride;
    }
}

static void intra_predict_ddl_8x8_msa( uint8_t *p_src, uint8_t *p_dst,
                                       int32_t i_dst_stride )
{
    uint8_t u_src_val = p_src[15];
    uint64_t u_out0, u_out1, u_out2, u_out3;
    v16u8 src, vec4, vec5, res0;
    v8u16 vec0, vec1, vec2, vec3;
    v2i64 res1, res2, res3;

    src = LD_UB( p_src );

    vec4 = ( v16u8 ) __msa_sldi_b( ( v16i8 ) src, ( v16i8 ) src, 1 );
    vec5 = ( v16u8 ) __msa_sldi_b( ( v16i8 ) src, ( v16i8 ) src, 2 );
    vec5 = ( v16u8 ) __msa_insert_b( ( v16i8 ) vec5, 14, u_src_val );
    ILVR_B2_UH( vec5, src, vec4, vec4, vec0, vec1 );
    ILVL_B2_UH( vec5, src, vec4, vec4, vec2, vec3 );
    HADD_UB4_UH( vec0, vec1, vec2, vec3, vec0, vec1, vec2, vec3 );

    vec0 += vec1;
    vec2 += vec3;
    vec0 = ( v8u16 ) __msa_srari_h( ( v8i16 ) vec0, 2 );
    vec2 = ( v8u16 ) __msa_srari_h( ( v8i16 ) vec2, 2 );

    res0 = ( v16u8 ) __msa_pckev_b( ( v16i8 ) vec2, ( v16i8 ) vec0 );
    res1 = ( v2i64 ) __msa_sldi_b( ( v16i8 ) res0, ( v16i8 ) res0, 1 );
    res2 = ( v2i64 ) __msa_sldi_b( ( v16i8 ) res0, ( v16i8 ) res0, 2 );
    res3 = ( v2i64 ) __msa_sldi_b( ( v16i8 ) res0, ( v16i8 ) res0, 3 );

    u_out0 = __msa_copy_u_d( ( v2i64 ) res0, 0 );
    u_out1 = __msa_copy_u_d( res1, 0 );
    u_out2 = __msa_copy_u_d( res2, 0 );
    u_out3 = __msa_copy_u_d( res3, 0 );
    SD4( u_out0, u_out1, u_out2, u_out3, p_dst, i_dst_stride );
    p_dst += ( 4 * i_dst_stride );

    res0 = ( v16u8 ) __msa_sldi_b( ( v16i8 ) res0, ( v16i8 ) res0, 4 );
    res1 = ( v2i64 ) __msa_sldi_b( ( v16i8 ) res0, ( v16i8 ) res0, 1 );
    res2 = ( v2i64 ) __msa_sldi_b( ( v16i8 ) res0, ( v16i8 ) res0, 2 );
    res3 = ( v2i64 ) __msa_sldi_b( ( v16i8 ) res0, ( v16i8 ) res0, 3 );

    u_out0 = __msa_copy_u_d( ( v2i64 ) res0, 0 );
    u_out1 = __msa_copy_u_d( res1, 0 );
    u_out2 = __msa_copy_u_d( res2, 0 );
    u_out3 = __msa_copy_u_d( res3, 0 );
    SD4( u_out0, u_out1, u_out2, u_out3, p_dst, i_dst_stride );
}

static void intra_predict_128dc_16x16_msa( uint8_t *p_dst,
                                           int32_t i_dst_stride )
{
    v16u8 out = ( v16u8 ) __msa_ldi_b( 128 );

    ST_UB8( out, out, out, out, out, out, out, out, p_dst, i_dst_stride );
    p_dst += ( 8 * i_dst_stride );
    ST_UB8( out, out, out, out, out, out, out, out, p_dst, i_dst_stride );
}

void x264_intra_predict_dc_16x16_msa( uint8_t *p_src )
{
    intra_predict_dc_16x16_msa( ( p_src - FDEC_STRIDE ), ( p_src - 1 ),
                                FDEC_STRIDE, p_src, FDEC_STRIDE, 1, 1 );
}

void x264_intra_predict_dc_left_16x16_msa( uint8_t *p_src )
{
    intra_predict_dc_16x16_msa( ( p_src - FDEC_STRIDE ), ( p_src - 1 ),
                                FDEC_STRIDE, p_src, FDEC_STRIDE, 0, 1 );
}

void x264_intra_predict_dc_top_16x16_msa( uint8_t *p_src )
{
    intra_predict_dc_16x16_msa( ( p_src - FDEC_STRIDE ), ( p_src - 1 ),
                                FDEC_STRIDE, p_src, FDEC_STRIDE, 1, 0 );
}

void x264_intra_predict_dc_128_16x16_msa( uint8_t *p_src )
{
    intra_predict_128dc_16x16_msa( p_src, FDEC_STRIDE );
}

void x264_intra_predict_hor_16x16_msa( uint8_t *p_src )
{
    intra_predict_horiz_16x16_msa( ( p_src - 1 ), FDEC_STRIDE,
                                   p_src, FDEC_STRIDE );
}

void x264_intra_predict_vert_16x16_msa( uint8_t *p_src )
{
    intra_predict_vert_16x16_msa( ( p_src - FDEC_STRIDE ), p_src, FDEC_STRIDE );
}

void x264_intra_predict_plane_16x16_msa( uint8_t *p_src )
{
    intra_predict_plane_16x16_msa( p_src, FDEC_STRIDE );
}

void x264_intra_predict_dc_4blk_8x8_msa( uint8_t *p_src )
{
    intra_predict_dc_4blk_8x8_msa( p_src, FDEC_STRIDE );
}

void x264_intra_predict_hor_8x8_msa( uint8_t *p_src )
{
    intra_predict_horiz_8x8_msa( ( p_src - 1 ), FDEC_STRIDE,
                                 p_src, FDEC_STRIDE );
}

void x264_intra_predict_vert_8x8_msa( uint8_t *p_src )
{
    intra_predict_vert_8x8_msa( ( p_src - FDEC_STRIDE ), p_src, FDEC_STRIDE );
}

void x264_intra_predict_plane_8x8_msa( uint8_t *p_src )
{
    intra_predict_plane_8x8_msa( p_src, FDEC_STRIDE );
}

void x264_intra_predict_ddl_8x8_msa( uint8_t *p_src, uint8_t pu_xyz[36] )
{
    intra_predict_ddl_8x8_msa( ( pu_xyz + 16 ), p_src, FDEC_STRIDE );
}

void x264_intra_predict_dc_8x8_msa( uint8_t *p_src, uint8_t pu_xyz[36] )
{
    intra_predict_dc_8x8_msa( ( pu_xyz + 16 ), ( pu_xyz + 7 ),
                              p_src, FDEC_STRIDE );
}

void x264_intra_predict_h_8x8_msa( uint8_t *p_src, uint8_t pu_xyz[36] )
{
    intra_predict_horiz_8x8_msa( ( pu_xyz + 14 ), -1, p_src, FDEC_STRIDE );
}

void x264_intra_predict_v_8x8_msa( uint8_t *p_src, uint8_t pu_xyz[36] )
{
    intra_predict_vert_8x8_msa( ( pu_xyz + 16 ), p_src, FDEC_STRIDE );
}

void x264_intra_predict_dc_4x4_msa( uint8_t *p_src )
{
    intra_predict_dc_4x4_msa( ( p_src - FDEC_STRIDE ), ( p_src - 1 ),
                              FDEC_STRIDE, p_src, FDEC_STRIDE, 1, 1 );
}

void x264_intra_predict_hor_4x4_msa( uint8_t *p_src )
{
    intra_predict_horiz_4x4_msa( ( p_src - 1 ), FDEC_STRIDE,
                                 p_src, FDEC_STRIDE );
}

void x264_intra_predict_vert_4x4_msa( uint8_t *p_src )
{
    intra_predict_vert_4x4_msa( ( p_src - FDEC_STRIDE ), p_src, FDEC_STRIDE );
}
#endif
