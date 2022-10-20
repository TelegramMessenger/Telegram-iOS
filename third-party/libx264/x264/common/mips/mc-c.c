/*****************************************************************************
 * mc-c.c: msa motion compensation
 *****************************************************************************
 * Copyright (C) 2015-2022 x264 project
 *
 * Authors: Neha Rana <neha.rana@imgtec.com>
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
#include "mc.h"

#if !HIGH_BIT_DEPTH
static const uint8_t pu_luma_mask_arr[16 * 8] =
{
    /* 8 width cases */
    0, 5, 1, 6, 2, 7, 3, 8, 4, 9, 5, 10, 6, 11, 7, 12,
    1, 4, 2, 5, 3, 6, 4, 7, 5, 8, 6, 9, 7, 10, 8, 11,
    2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10,
    /* 4 width cases */
    0, 5, 1, 6, 2, 7, 3, 8, 16, 21, 17, 22, 18, 23, 19, 24,
    1, 4, 2, 5, 3, 6, 4, 7, 17, 20, 18, 21, 19, 22, 20, 23,
    2, 3, 3, 4, 4, 5, 5, 6, 18, 19, 19, 20, 20, 21, 21, 22,
    2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 24, 25,
    3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 24, 25, 26
};

static const uint8_t pu_chroma_mask_arr[16 * 5] =
{
    0, 1, 1, 2, 2, 3, 3, 4, 16, 17, 17, 18, 18, 19, 19, 20,
    0, 2, 2, 4, 4, 6, 6, 8, 16, 18, 18, 20, 20, 22, 22, 24,
    0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8,
    0, 1, 1, 2, 16, 17, 17, 18, 4, 5, 5, 6, 6, 7, 7, 8,
    0, 1, 1, 2, 16, 17, 17, 18, 16, 17, 17, 18, 18, 19, 19, 20
};

static void avc_luma_hz_16w_msa( uint8_t *p_src, int32_t i_src_stride,
                                 uint8_t *p_dst, int32_t i_dst_stride,
                                 int32_t i_height )
{
    uint32_t u_loop_cnt, u_h4w;
    v16u8 dst0;
    v16i8 src0, src1, src2, src3, src4, src5, src6, src7;
    v8i16 res0, res1, res2, res3, res4, res5, res6, res7;
    v16i8 mask0, mask1, mask2;
    v16i8 vec0, vec1, vec2, vec3, vec4, vec5;
    v16i8 vec6, vec7, vec8, vec9, vec10, vec11;
    v16i8 minus5b = __msa_ldi_b( -5 );
    v16i8 plus20b = __msa_ldi_b( 20 );

    u_h4w = i_height % 4;
    LD_SB3( &pu_luma_mask_arr[0], 16, mask0, mask1, mask2 );

    for( u_loop_cnt = ( i_height >> 2 ); u_loop_cnt--; )
    {
        LD_SB2( p_src, 8, src0, src1 );
        p_src += i_src_stride;
        LD_SB2( p_src, 8, src2, src3 );
        p_src += i_src_stride;

        XORI_B4_128_SB( src0, src1, src2, src3 );
        VSHF_B2_SB( src0, src0, src1, src1, mask0, mask0, vec0, vec3 );
        VSHF_B2_SB( src2, src2, src3, src3, mask0, mask0, vec6, vec9 );
        VSHF_B2_SB( src0, src0, src1, src1, mask1, mask1, vec1, vec4 );
        VSHF_B2_SB( src2, src2, src3, src3, mask1, mask1, vec7, vec10 );
        VSHF_B2_SB( src0, src0, src1, src1, mask2, mask2, vec2, vec5 );
        VSHF_B2_SB( src2, src2, src3, src3, mask2, mask2, vec8, vec11 );
        HADD_SB4_SH( vec0, vec3, vec6, vec9, res0, res1, res2, res3 );
        DPADD_SB4_SH( vec1, vec4, vec7, vec10, minus5b, minus5b, minus5b,
                      minus5b, res0, res1, res2, res3 );
        DPADD_SB4_SH( vec2, vec5, vec8, vec11, plus20b, plus20b, plus20b,
                      plus20b, res0, res1, res2, res3 );

        LD_SB2( p_src, 8, src4, src5 );
        p_src += i_src_stride;
        LD_SB2( p_src, 8, src6, src7 );
        p_src += i_src_stride;

        XORI_B4_128_SB( src4, src5, src6, src7 );
        VSHF_B2_SB( src4, src4, src5, src5, mask0, mask0, vec0, vec3 );
        VSHF_B2_SB( src6, src6, src7, src7, mask0, mask0, vec6, vec9 );
        VSHF_B2_SB( src4, src4, src5, src5, mask1, mask1, vec1, vec4 );
        VSHF_B2_SB( src6, src6, src7, src7, mask1, mask1, vec7, vec10 );
        VSHF_B2_SB( src4, src4, src5, src5, mask2, mask2, vec2, vec5 );
        VSHF_B2_SB( src6, src6, src7, src7, mask2, mask2, vec8, vec11 );
        HADD_SB4_SH( vec0, vec3, vec6, vec9, res4, res5, res6, res7 );
        DPADD_SB4_SH( vec1, vec4, vec7, vec10, minus5b, minus5b, minus5b,
                      minus5b, res4, res5, res6, res7 );
        DPADD_SB4_SH( vec2, vec5, vec8, vec11, plus20b, plus20b, plus20b,
                      plus20b, res4, res5, res6, res7 );
        SRARI_H4_SH( res0, res1, res2, res3, 5 );
        SRARI_H4_SH( res4, res5, res6, res7, 5 );
        SAT_SH4_SH( res0, res1, res2, res3, 7 );
        SAT_SH4_SH( res4, res5, res6, res7, 7 );
        PCKEV_B4_SB( res1, res0, res3, res2, res5, res4, res7, res6,
                     vec0, vec1, vec2, vec3 );
        XORI_B4_128_SB( vec0, vec1, vec2, vec3 );

        ST_SB4( vec0, vec1, vec2, vec3, p_dst, i_dst_stride );
        p_dst += ( 4 * i_dst_stride );
    }

    for( u_loop_cnt = u_h4w; u_loop_cnt--; )
    {
        LD_SB2( p_src, 8, src0, src1 );
        p_src += i_src_stride;

        XORI_B2_128_SB( src0, src1 );
        VSHF_B2_SB( src0, src0, src1, src1, mask0, mask0, vec0, vec3 );
        VSHF_B2_SB( src0, src0, src1, src1, mask1, mask1, vec1, vec4 );
        VSHF_B2_SB( src0, src0, src1, src1, mask2, mask2, vec2, vec5 );
        res0 = __msa_hadd_s_h( vec0, vec0 );
        DPADD_SB2_SH( vec1, vec2, minus5b, plus20b, res0, res0 );
        res1 = __msa_hadd_s_h( vec3, vec3 );
        DPADD_SB2_SH( vec4, vec5, minus5b, plus20b, res1, res1 );
        SRARI_H2_SH( res0, res1, 5 );
        SAT_SH2_SH( res0, res1, 7 );
        dst0 = PCKEV_XORI128_UB( res0, res1 );
        ST_UB( dst0, p_dst );
        p_dst += i_dst_stride;
    }
}

static void avc_luma_vt_16w_msa( uint8_t *p_src, int32_t i_src_stride,
                                 uint8_t *p_dst, int32_t i_dst_stride,
                                 int32_t i_height )
{
    uint32_t u_loop_cnt, u_h4w;
    const int16_t i_filt_const0 = 0xfb01;
    const int16_t i_filt_const1 = 0x1414;
    const int16_t i_filt_const2 = 0x1fb;
    v16i8 src0, src1, src2, src3, src4, src5, src6, src7, src8;
    v16i8 src10_r, src32_r, src54_r, src76_r, src21_r, src43_r, src65_r;
    v16i8 src87_r, src10_l, src32_l, src54_l, src76_l, src21_l, src43_l;
    v16i8 src65_l, src87_l;
    v8i16 out0_r, out1_r, out2_r, out3_r, out0_l, out1_l, out2_l, out3_l;
    v16u8 res0, res1, res2, res3;
    v16i8 filt0, filt1, filt2;

    u_h4w = i_height % 4;
    filt0 = ( v16i8 ) __msa_fill_h( i_filt_const0 );
    filt1 = ( v16i8 ) __msa_fill_h( i_filt_const1 );
    filt2 = ( v16i8 ) __msa_fill_h( i_filt_const2 );

    LD_SB5( p_src, i_src_stride, src0, src1, src2, src3, src4 );
    p_src += ( 5 * i_src_stride );

    XORI_B5_128_SB( src0, src1, src2, src3, src4 );
    ILVR_B4_SB( src1, src0, src2, src1, src3, src2, src4, src3,
                src10_r, src21_r, src32_r, src43_r );
    ILVL_B4_SB( src1, src0, src2, src1, src3, src2, src4, src3,
                src10_l, src21_l, src32_l, src43_l );

    for( u_loop_cnt = ( i_height >> 2 ); u_loop_cnt--; )
    {
        LD_SB4( p_src, i_src_stride, src5, src6, src7, src8 );
        p_src += ( 4 * i_src_stride );

        XORI_B4_128_SB( src5, src6, src7, src8 );
        ILVR_B4_SB( src5, src4, src6, src5, src7, src6, src8, src7,
                    src54_r, src65_r, src76_r, src87_r );
        ILVL_B4_SB( src5, src4, src6, src5, src7, src6, src8, src7,
                    src54_l, src65_l, src76_l, src87_l );
        out0_r = DPADD_SH3_SH( src10_r, src32_r, src54_r,
                               filt0, filt1, filt2 );
        out1_r = DPADD_SH3_SH( src21_r, src43_r, src65_r,
                               filt0, filt1, filt2 );
        out2_r = DPADD_SH3_SH( src32_r, src54_r, src76_r,
                               filt0, filt1, filt2 );
        out3_r = DPADD_SH3_SH( src43_r, src65_r, src87_r,
                               filt0, filt1, filt2 );
        out0_l = DPADD_SH3_SH( src10_l, src32_l, src54_l,
                               filt0, filt1, filt2 );
        out1_l = DPADD_SH3_SH( src21_l, src43_l, src65_l,
                               filt0, filt1, filt2 );
        out2_l = DPADD_SH3_SH( src32_l, src54_l, src76_l,
                               filt0, filt1, filt2 );
        out3_l = DPADD_SH3_SH( src43_l, src65_l, src87_l,
                               filt0, filt1, filt2 );
        SRARI_H4_SH( out0_r, out1_r, out2_r, out3_r, 5 );
        SAT_SH4_SH( out0_r, out1_r, out2_r, out3_r, 7 );
        SRARI_H4_SH( out0_l, out1_l, out2_l, out3_l, 5 );
        SAT_SH4_SH( out0_l, out1_l, out2_l, out3_l, 7 );
        PCKEV_B4_UB( out0_l, out0_r, out1_l, out1_r, out2_l, out2_r, out3_l,
                     out3_r, res0, res1, res2, res3 );
        XORI_B4_128_UB( res0, res1, res2, res3 );

        ST_UB4( res0, res1, res2, res3, p_dst, i_dst_stride );
        p_dst += ( 4 * i_dst_stride );

        src10_r = src54_r;
        src32_r = src76_r;
        src21_r = src65_r;
        src43_r = src87_r;
        src10_l = src54_l;
        src32_l = src76_l;
        src21_l = src65_l;
        src43_l = src87_l;
        src4 = src8;
    }

    for( u_loop_cnt = u_h4w; u_loop_cnt--; )
    {
        src5 = LD_SB( p_src );
        p_src += ( i_src_stride );
        src5 = ( v16i8 ) __msa_xori_b( ( v16u8 ) src5, 128 );
        ILVRL_B2_SB( src5, src4, src54_r, src54_l );
        out0_r = DPADD_SH3_SH( src10_r, src32_r, src54_r,
                               filt0, filt1, filt2 );
        out0_l = DPADD_SH3_SH( src10_l, src32_l, src54_l,
                               filt0, filt1, filt2 );
        SRARI_H2_SH( out0_r, out0_l, 5 );
        SAT_SH2_SH( out0_r, out0_l, 7 );
        out0_r = ( v8i16 ) __msa_pckev_b( ( v16i8 ) out0_l, ( v16i8 ) out0_r );
        res0 = __msa_xori_b( ( v16u8 ) out0_r, 128 );
        ST_UB( res0, p_dst );
        p_dst += i_dst_stride;

        src10_r = src21_r;
        src21_r = src32_r;
        src32_r = src43_r;
        src43_r = src54_r;

        src10_l = src21_l;
        src21_l = src32_l;
        src32_l = src43_l;
        src43_l = src54_l;

        src4 = src5;
    }
}

static void avc_luma_mid_8w_msa( uint8_t *p_src, int32_t i_src_stride,
                                 uint8_t *p_dst, int32_t i_dst_stride,
                                 int32_t i_height )
{
    uint32_t u_loop_cnt, u_h4w;
    uint64_t u_out0;
    v16i8 tmp0;
    v16i8 src0, src1, src2, src3, src4;
    v16i8 mask0, mask1, mask2;
    v8i16 hz_out0, hz_out1, hz_out2, hz_out3;
    v8i16 hz_out4, hz_out5, hz_out6, hz_out7, hz_out8;
    v8i16 dst0, dst1, dst2, dst3;
    v16u8 out0, out1;

    u_h4w = i_height % 4;
    LD_SB3( &pu_luma_mask_arr[0], 16, mask0, mask1, mask2 );

    LD_SB5( p_src, i_src_stride, src0, src1, src2, src3, src4 );
    XORI_B5_128_SB( src0, src1, src2, src3, src4 );
    p_src += ( 5 * i_src_stride );

    hz_out0 = AVC_HORZ_FILTER_SH( src0, mask0, mask1, mask2 );
    hz_out1 = AVC_HORZ_FILTER_SH( src1, mask0, mask1, mask2 );
    hz_out2 = AVC_HORZ_FILTER_SH( src2, mask0, mask1, mask2 );
    hz_out3 = AVC_HORZ_FILTER_SH( src3, mask0, mask1, mask2 );
    hz_out4 = AVC_HORZ_FILTER_SH( src4, mask0, mask1, mask2 );

    for( u_loop_cnt = ( i_height >> 2 ); u_loop_cnt--; )
    {
        LD_SB4( p_src, i_src_stride, src0, src1, src2, src3 );
        XORI_B4_128_SB( src0, src1, src2, src3 );
        p_src += ( 4 * i_src_stride );

        hz_out5 = AVC_HORZ_FILTER_SH( src0, mask0, mask1, mask2 );
        hz_out6 = AVC_HORZ_FILTER_SH( src1, mask0, mask1, mask2 );
        hz_out7 = AVC_HORZ_FILTER_SH( src2, mask0, mask1, mask2 );
        hz_out8 = AVC_HORZ_FILTER_SH( src3, mask0, mask1, mask2 );
        dst0 = AVC_CALC_DPADD_H_6PIX_2COEFF_SH( hz_out0, hz_out1, hz_out2,
                                                hz_out3, hz_out4, hz_out5 );
        dst1 = AVC_CALC_DPADD_H_6PIX_2COEFF_SH( hz_out1, hz_out2, hz_out3,
                                                hz_out4, hz_out5, hz_out6 );
        dst2 = AVC_CALC_DPADD_H_6PIX_2COEFF_SH( hz_out2, hz_out3, hz_out4,
                                                hz_out5, hz_out6, hz_out7 );
        dst3 = AVC_CALC_DPADD_H_6PIX_2COEFF_SH( hz_out3, hz_out4, hz_out5,
                                                hz_out6, hz_out7, hz_out8 );
        out0 = PCKEV_XORI128_UB( dst0, dst1 );
        out1 = PCKEV_XORI128_UB( dst2, dst3 );
        ST8x4_UB( out0, out1, p_dst, i_dst_stride );

        p_dst += ( 4 * i_dst_stride );
        hz_out3 = hz_out7;
        hz_out1 = hz_out5;
        hz_out5 = hz_out4;
        hz_out4 = hz_out8;
        hz_out2 = hz_out6;
        hz_out0 = hz_out5;
    }

    for( u_loop_cnt = u_h4w; u_loop_cnt--; )
    {
        src0 = LD_SB( p_src );
        p_src += i_src_stride;

        src0 = ( v16i8 ) __msa_xori_b( ( v16u8 ) src0, 128 );
        hz_out5 = AVC_HORZ_FILTER_SH( src0, mask0, mask1, mask2 );

        dst0 = AVC_CALC_DPADD_H_6PIX_2COEFF_SH( hz_out0, hz_out1,
                                                hz_out2, hz_out3,
                                                hz_out4, hz_out5 );

        tmp0 = __msa_pckev_b( ( v16i8 ) ( dst0 ), ( v16i8 ) ( dst0 ) );
        tmp0 = ( v16i8 ) __msa_xori_b( ( v16u8 ) tmp0, 128 );
        u_out0 = __msa_copy_u_d( ( v2i64 ) tmp0, 0 );
        SD( u_out0, p_dst );
        p_dst += i_dst_stride;

        hz_out0 = hz_out1;
        hz_out1 = hz_out2;
        hz_out2 = hz_out3;
        hz_out3 = hz_out4;
        hz_out4 = hz_out5;
    }
}

static void avc_luma_mid_16w_msa( uint8_t *p_src, int32_t i_src_stride,
                                  uint8_t *p_dst, int32_t i_dst_stride,
                                  int32_t i_height )
{
    uint32_t u_multiple8_cnt;

    for( u_multiple8_cnt = 2; u_multiple8_cnt--; )
    {
        avc_luma_mid_8w_msa( p_src, i_src_stride, p_dst, i_dst_stride,
                             i_height );
        p_src += 8;
        p_dst += 8;
    }
}

static void avc_interleaved_chroma_hv_2x2_msa( uint8_t *p_src,
                                               int32_t i_src_stride,
                                               uint8_t *p_dst_u,
                                               uint8_t *p_dst_v,
                                               int32_t i_dst_stride,
                                               uint32_t u_coef_hor0,
                                               uint32_t u_coef_hor1,
                                               uint32_t u_coef_ver0,
                                               uint32_t u_coef_ver1 )
{
    uint16_t u_out0, u_out1, u_out2, u_out3;
    v16u8 src0, src1, src2, src3, src4;
    v8u16 res_hz0, res_hz1, res_hz2, res_hz3;
    v8u16 res_vt0, res_vt1, res_vt2, res_vt3;
    v16i8 mask;
    v16i8 coeff_hz_vec0 = __msa_fill_b( u_coef_hor0 );
    v16i8 coeff_hz_vec1 = __msa_fill_b( u_coef_hor1 );
    v16u8 coeff_hz_vec = ( v16u8 ) __msa_ilvr_b( coeff_hz_vec0, coeff_hz_vec1 );
    v8u16 coeff_vt_vec0 = ( v8u16 ) __msa_fill_h( u_coef_ver0 );
    v8u16 coeff_vt_vec1 = ( v8u16 ) __msa_fill_h( u_coef_ver1 );
    v8i16 res0, res1;

    mask = LD_SB( &pu_chroma_mask_arr[16] );

    LD_UB3( p_src, i_src_stride, src0, src1, src2 );
    VSHF_B2_UB( src0, src1, src1, src2,
                ( mask + 1 ), ( mask + 1 ), src3, src4 );
    VSHF_B2_UB( src0, src1, src1, src2, mask, mask, src0, src1 );
    DOTP_UB4_UH( src0, src1, src3, src4, coeff_hz_vec, coeff_hz_vec,
                 coeff_hz_vec, coeff_hz_vec, res_hz0, res_hz1, res_hz2,
                 res_hz3 );
    MUL4( res_hz0, coeff_vt_vec1, res_hz1, coeff_vt_vec0, res_hz2,
          coeff_vt_vec1, res_hz3, coeff_vt_vec0, res_vt0, res_vt1, res_vt2,
          res_vt3 );
    ADD2( res_vt0, res_vt1, res_vt2, res_vt3, res_vt0, res_vt2 );
    SRARI_H2_UH( res_vt0, res_vt2, 6 );
    SAT_UH2_UH( res_vt0, res_vt2, 7 );
    PCKEV_B2_SH( res_vt0, res_vt0, res_vt2, res_vt2, res0, res1 );

    u_out0 = __msa_copy_u_h( res0, 0 );
    u_out1 = __msa_copy_u_h( res0, 2 );
    u_out2 = __msa_copy_u_h( res1, 0 );
    u_out3 = __msa_copy_u_h( res1, 2 );

    SH( u_out0, p_dst_u );
    p_dst_u += i_dst_stride;
    SH( u_out1, p_dst_u );

    SH( u_out2, p_dst_v );
    p_dst_v += i_dst_stride;
    SH( u_out3, p_dst_v );
}

static void avc_interleaved_chroma_hv_2x4_msa( uint8_t *p_src,
                                               int32_t i_src_stride,
                                               uint8_t *p_dst_u,
                                               uint8_t *p_dst_v,
                                               int32_t i_dst_stride,
                                               uint32_t u_coef_hor0,
                                               uint32_t u_coef_hor1,
                                               uint32_t u_coef_ver0,
                                               uint32_t u_coef_ver1 )
{
    uint16_t u_out0, u_out1, u_out2, u_out3;
    v16u8 src0, src1, src2, src3, src4, src5, src6, src7, src8;
    v8u16 res_hz0, res_hz1, res_hz2, res_hz3;
    v8u16 res_vt0, res_vt1, res_vt2, res_vt3;
    v16i8 mask;
    v8i16 res0, res1;
    v16i8 coeff_hz_vec0 = __msa_fill_b( u_coef_hor0 );
    v16i8 coeff_hz_vec1 = __msa_fill_b( u_coef_hor1 );
    v16u8 coeff_hz_vec = ( v16u8 ) __msa_ilvr_b( coeff_hz_vec0, coeff_hz_vec1 );
    v8u16 coeff_vt_vec0 = ( v8u16 ) __msa_fill_h( u_coef_ver0 );
    v8u16 coeff_vt_vec1 = ( v8u16 ) __msa_fill_h( u_coef_ver1 );

    mask = LD_SB( &pu_chroma_mask_arr[16] );

    LD_UB5( p_src, i_src_stride, src0, src1, src2, src3, src4 );

    VSHF_B2_UB( src0, src1, src1, src2,
                ( mask + 1 ), ( mask + 1 ), src5, src6 );
    VSHF_B2_UB( src2, src3, src3, src4,
                ( mask + 1 ), ( mask + 1 ), src7, src8 );
    VSHF_B2_UB( src0, src1, src1, src2, mask, mask, src0, src1 );
    VSHF_B2_UB( src2, src3, src3, src4, mask, mask, src2, src3 );
    DOTP_UB4_UH( src0, src1, src2, src3, coeff_hz_vec, coeff_hz_vec,
                 coeff_hz_vec, coeff_hz_vec, res_hz0,
                 res_hz1, res_hz2, res_hz3 );
    MUL4( res_hz0, coeff_vt_vec1, res_hz1, coeff_vt_vec0, res_hz2,
          coeff_vt_vec1, res_hz3, coeff_vt_vec0, res_vt0, res_vt1, res_vt2,
          res_vt3 );
    ADD2( res_vt0, res_vt1, res_vt2, res_vt3, res_vt0, res_vt1 );
    SRARI_H2_UH( res_vt0, res_vt1, 6 );
    SAT_UH2_UH( res_vt0, res_vt1, 7 );
    PCKEV_B2_SH( res_vt0, res_vt0, res_vt1, res_vt1, res0, res1 );

    u_out0 = __msa_copy_u_h( res0, 0 );
    u_out1 = __msa_copy_u_h( res0, 2 );
    u_out2 = __msa_copy_u_h( res1, 0 );
    u_out3 = __msa_copy_u_h( res1, 2 );

    SH( u_out0, p_dst_u );
    p_dst_u += i_dst_stride;
    SH( u_out1, p_dst_u );
    p_dst_u += i_dst_stride;
    SH( u_out2, p_dst_u );
    p_dst_u += i_dst_stride;
    SH( u_out3, p_dst_u );

    DOTP_UB4_UH( src5, src6, src7, src8, coeff_hz_vec, coeff_hz_vec,
                 coeff_hz_vec, coeff_hz_vec, res_hz0, res_hz1, res_hz2,
                 res_hz3 );
    MUL4( res_hz0, coeff_vt_vec1, res_hz1, coeff_vt_vec0, res_hz2,
          coeff_vt_vec1, res_hz3, coeff_vt_vec0, res_vt0, res_vt1, res_vt2,
          res_vt3 );
    ADD2( res_vt0, res_vt1, res_vt2, res_vt3, res_vt0, res_vt1 );
    SRARI_H2_UH( res_vt0, res_vt1, 6 );
    SAT_UH2_UH( res_vt0, res_vt1, 7 );
    PCKEV_B2_SH( res_vt0, res_vt0, res_vt1, res_vt1, res0, res1 );

    u_out0 = __msa_copy_u_h( res0, 0 );
    u_out1 = __msa_copy_u_h( res0, 2 );
    u_out2 = __msa_copy_u_h( res1, 0 );
    u_out3 = __msa_copy_u_h( res1, 2 );

    SH( u_out0, p_dst_v );
    p_dst_v += i_dst_stride;
    SH( u_out1, p_dst_v );
    p_dst_v += i_dst_stride;
    SH( u_out2, p_dst_v );
    p_dst_v += i_dst_stride;
    SH( u_out3, p_dst_v );
}

static void avc_interleaved_chroma_hv_2w_msa( uint8_t *p_src,
                                              int32_t i_src_stride,
                                              uint8_t *p_dst_u,
                                              uint8_t *p_dst_v,
                                              int32_t i_dst_stride,
                                              uint32_t u_coef_hor0,
                                              uint32_t u_coef_hor1,
                                              uint32_t u_coef_ver0,
                                              uint32_t u_coef_ver1,
                                              int32_t i_height )
{
    if( 2 == i_height )
    {
        avc_interleaved_chroma_hv_2x2_msa( p_src, i_src_stride,
                                           p_dst_u, p_dst_v, i_dst_stride,
                                           u_coef_hor0, u_coef_hor1,
                                           u_coef_ver0, u_coef_ver1 );
    }
    else if( 4 == i_height )
    {
        avc_interleaved_chroma_hv_2x4_msa( p_src, i_src_stride,
                                           p_dst_u, p_dst_v, i_dst_stride,
                                           u_coef_hor0, u_coef_hor1,
                                           u_coef_ver0, u_coef_ver1 );
    }
}

static void avc_interleaved_chroma_hv_4x2_msa( uint8_t *p_src,
                                               int32_t i_src_stride,
                                               uint8_t *p_dst_u,
                                               uint8_t *p_dst_v,
                                               int32_t i_dst_stride,
                                               uint32_t u_coef_hor0,
                                               uint32_t u_coef_hor1,
                                               uint32_t u_coef_ver0,
                                               uint32_t u_coef_ver1 )
{
    uint32_t u_out0, u_out1, u_out2, u_out3;
    v16u8 src0, src1, src2, src3, src4;
    v8u16 res_hz0, res_hz1, res_hz2, res_hz3;
    v8u16 res_vt0, res_vt1, res_vt2, res_vt3;
    v16i8 mask;
    v16i8 coeff_hz_vec0 = __msa_fill_b( u_coef_hor0 );
    v16i8 coeff_hz_vec1 = __msa_fill_b( u_coef_hor1 );
    v16u8 coeff_hz_vec = ( v16u8 ) __msa_ilvr_b( coeff_hz_vec0, coeff_hz_vec1 );
    v8u16 coeff_vt_vec0 = ( v8u16 ) __msa_fill_h( u_coef_ver0 );
    v8u16 coeff_vt_vec1 = ( v8u16 ) __msa_fill_h( u_coef_ver1 );
    v4i32 res0, res1;

    mask = LD_SB( &pu_chroma_mask_arr[16] );

    LD_UB3( p_src, i_src_stride, src0, src1, src2 );
    VSHF_B2_UB( src0, src1, src1, src2,
                ( mask + 1 ), ( mask + 1 ), src3, src4 );
    VSHF_B2_UB( src0, src1, src1, src2, mask, mask, src0, src1 );
    DOTP_UB4_UH( src0, src1, src3, src4, coeff_hz_vec, coeff_hz_vec,
                 coeff_hz_vec, coeff_hz_vec, res_hz0, res_hz1, res_hz2,
                 res_hz3 );
    MUL4( res_hz0, coeff_vt_vec1, res_hz1, coeff_vt_vec0, res_hz2,
          coeff_vt_vec1, res_hz3, coeff_vt_vec0, res_vt0, res_vt1, res_vt2,
          res_vt3 );
    ADD2( res_vt0, res_vt1, res_vt2, res_vt3, res_vt0, res_vt2 );
    SRARI_H2_UH( res_vt0, res_vt2, 6 );
    SAT_UH2_UH( res_vt0, res_vt2, 7 );
    PCKEV_B2_SW( res_vt0, res_vt0, res_vt2, res_vt2, res0, res1 );

    u_out0 = __msa_copy_u_w( res0, 0 );
    u_out1 = __msa_copy_u_w( res0, 1 );
    u_out2 = __msa_copy_u_w( res1, 0 );
    u_out3 = __msa_copy_u_w( res1, 1 );
    SW( u_out0, p_dst_u );
    p_dst_u += i_dst_stride;
    SW( u_out1, p_dst_u );
    SW( u_out2, p_dst_v );
    p_dst_v += i_dst_stride;
    SW( u_out3, p_dst_v );
}

static void avc_interleaved_chroma_hv_4x4mul_msa( uint8_t *p_src,
                                                  int32_t i_src_stride,
                                                  uint8_t *p_dst_u,
                                                  uint8_t *p_dst_v,
                                                  int32_t i_dst_stride,
                                                  uint32_t u_coef_hor0,
                                                  uint32_t u_coef_hor1,
                                                  uint32_t u_coef_ver0,
                                                  uint32_t u_coef_ver1,
                                                  int32_t i_height )
{
    uint32_t u_row;
    v16u8 src0, src1, src2, src3, src4, src5, src6, src7, src8;
    v8u16 res_hz0, res_hz1, res_hz2, res_hz3;
    v8u16 res_vt0, res_vt1, res_vt2, res_vt3;
    v16i8 mask;
    v4i32 res0, res1;
    v16i8 coeff_hz_vec0 = __msa_fill_b( u_coef_hor0 );
    v16i8 coeff_hz_vec1 = __msa_fill_b( u_coef_hor1 );
    v16u8 coeff_hz_vec = ( v16u8 ) __msa_ilvr_b( coeff_hz_vec0, coeff_hz_vec1 );
    v8u16 coeff_vt_vec0 = ( v8u16 ) __msa_fill_h( u_coef_ver0 );
    v8u16 coeff_vt_vec1 = ( v8u16 ) __msa_fill_h( u_coef_ver1 );

    mask = LD_SB( &pu_chroma_mask_arr[16] );

    src0 = LD_UB( p_src );
    p_src += i_src_stride;

    for( u_row = ( i_height >> 2 ); u_row--; )
    {
        LD_UB4( p_src, i_src_stride, src1, src2, src3, src4 );
        p_src += ( 4 * i_src_stride );

        VSHF_B2_UB( src0, src1, src1, src2,
                    ( mask + 1 ), ( mask + 1 ), src5, src6 );
        VSHF_B2_UB( src2, src3, src3, src4,
                    ( mask + 1 ), ( mask + 1 ), src7, src8 );
        VSHF_B2_UB( src0, src1, src1, src2, mask, mask, src0, src1 );
        VSHF_B2_UB( src2, src3, src3, src4, mask, mask, src2, src3 );
        DOTP_UB4_UH( src0, src1, src2, src3, coeff_hz_vec, coeff_hz_vec,
                     coeff_hz_vec, coeff_hz_vec, res_hz0, res_hz1, res_hz2,
                     res_hz3 );
        MUL4( res_hz0, coeff_vt_vec1, res_hz1, coeff_vt_vec0, res_hz2,
              coeff_vt_vec1, res_hz3, coeff_vt_vec0, res_vt0, res_vt1, res_vt2,
              res_vt3 );
        ADD2( res_vt0, res_vt1, res_vt2, res_vt3, res_vt0, res_vt1 );
        SRARI_H2_UH( res_vt0, res_vt1, 6 );
        SAT_UH2_UH( res_vt0, res_vt1, 7 );
        PCKEV_B2_SW( res_vt0, res_vt0, res_vt1, res_vt1, res0, res1 );

        ST4x4_UB( res0, res1, 0, 1, 0, 1, p_dst_u, i_dst_stride );
        p_dst_u += ( 4 * i_dst_stride );

        DOTP_UB4_UH( src5, src6, src7, src8, coeff_hz_vec, coeff_hz_vec,
                     coeff_hz_vec, coeff_hz_vec, res_hz0, res_hz1, res_hz2,
                     res_hz3 );
        MUL4( res_hz0, coeff_vt_vec1, res_hz1, coeff_vt_vec0, res_hz2,
              coeff_vt_vec1, res_hz3, coeff_vt_vec0, res_vt0, res_vt1, res_vt2,
              res_vt3 );
        ADD2( res_vt0, res_vt1, res_vt2, res_vt3, res_vt0, res_vt1 );
        SRARI_H2_UH( res_vt0, res_vt1, 6 );
        SAT_UH2_UH( res_vt0, res_vt1, 7 );
        PCKEV_B2_SW( res_vt0, res_vt0, res_vt1, res_vt1, res0, res1 );

        ST4x4_UB( res0, res1, 0, 1, 0, 1, p_dst_v, i_dst_stride );
        p_dst_v += ( 4 * i_dst_stride );
        src0 = src4;
    }
}

static void avc_interleaved_chroma_hv_4w_msa( uint8_t *p_src,
                                              int32_t i_src_stride,
                                              uint8_t *p_dst_u,
                                              uint8_t *p_dst_v,
                                              int32_t i_dst_stride,
                                              uint32_t u_coef_hor0,
                                              uint32_t u_coef_hor1,
                                              uint32_t u_coef_ver0,
                                              uint32_t u_coef_ver1,
                                              int32_t i_height )
{
    if( 2 == i_height )
    {
        avc_interleaved_chroma_hv_4x2_msa( p_src, i_src_stride,
                                           p_dst_u, p_dst_v, i_dst_stride,
                                           u_coef_hor0, u_coef_hor1,
                                           u_coef_ver0, u_coef_ver1 );
    }
    else
    {
        avc_interleaved_chroma_hv_4x4mul_msa( p_src, i_src_stride,
                                              p_dst_u, p_dst_v, i_dst_stride,
                                              u_coef_hor0, u_coef_hor1,
                                              u_coef_ver0, u_coef_ver1,
                                              i_height );
    }
}

static void avc_interleaved_chroma_hv_8w_msa( uint8_t *p_src,
                                              int32_t i_src_stride,
                                              uint8_t *p_dst_u,
                                              uint8_t *p_dst_v,
                                              int32_t i_dst_stride,
                                              uint32_t u_coef_hor0,
                                              uint32_t u_coef_hor1,
                                              uint32_t u_coef_ver0,
                                              uint32_t u_coef_ver1,
                                              int32_t i_height )
{
    uint32_t u_row;
    v16u8 src0, src1, src2, src3, src4, src5, src6, src7, src8, src9;
    v16u8 src10, src11, src12, src13, src14;
    v8u16 res_hz0, res_hz1, res_hz2, res_hz3, res_hz4, res_hz5;
    v8u16 res_vt0, res_vt1, res_vt2, res_vt3;
    v16i8 mask = { 0, 2, 2, 4, 4, 6, 6, 8, 8, 10, 10, 12, 12, 14, 14, 16 };
    v16i8 coeff_hz_vec0, coeff_hz_vec1;
    v16i8 tmp0, tmp1;
    v16u8 coeff_hz_vec;
    v8u16 coeff_vt_vec0, coeff_vt_vec1;

    coeff_hz_vec0 = __msa_fill_b( u_coef_hor0 );
    coeff_hz_vec1 = __msa_fill_b( u_coef_hor1 );
    coeff_hz_vec = ( v16u8 ) __msa_ilvr_b( coeff_hz_vec0, coeff_hz_vec1 );
    coeff_vt_vec0 = ( v8u16 ) __msa_fill_h( u_coef_ver0 );
    coeff_vt_vec1 = ( v8u16 ) __msa_fill_h( u_coef_ver1 );

    LD_UB2( p_src, 16, src0, src13 );
    p_src += i_src_stride;

    VSHF_B2_UB( src0, src13, src0, src13, ( mask + 1 ), mask, src14, src0 );
    DOTP_UB2_UH( src0, src14, coeff_hz_vec, coeff_hz_vec, res_hz0, res_hz5 );

    for( u_row = ( i_height >> 2 ); u_row--; )
    {
        LD_UB4( p_src, i_src_stride, src1, src2, src3, src4 );
        LD_UB4( p_src + 16, i_src_stride, src5, src6, src7, src8 );
        p_src += ( 4 * i_src_stride );

        VSHF_B2_UB( src1, src5, src2, src6, mask, mask, src9, src10 );
        VSHF_B2_UB( src3, src7, src4, src8, mask, mask, src11, src12 );
        DOTP_UB4_UH( src9, src10, src11, src12, coeff_hz_vec, coeff_hz_vec,
                     coeff_hz_vec, coeff_hz_vec, res_hz1, res_hz2, res_hz3,
                     res_hz4 );
        MUL4( res_hz1, coeff_vt_vec0, res_hz2, coeff_vt_vec0, res_hz3,
              coeff_vt_vec0, res_hz4, coeff_vt_vec0, res_vt0, res_vt1, res_vt2,
              res_vt3 );

        res_vt0 += ( res_hz0 * coeff_vt_vec1 );
        res_vt1 += ( res_hz1 * coeff_vt_vec1 );
        res_vt2 += ( res_hz2 * coeff_vt_vec1 );
        res_vt3 += ( res_hz3 * coeff_vt_vec1 );

        SRARI_H4_UH( res_vt0, res_vt1, res_vt2, res_vt3, 6 );
        SAT_UH4_UH( res_vt0, res_vt1, res_vt2, res_vt3, 7 );
        PCKEV_B2_SB( res_vt1, res_vt0, res_vt3, res_vt2, tmp0, tmp1 );
        ST8x4_UB( tmp0, tmp1, p_dst_u, i_dst_stride );
        p_dst_u += ( 4 * i_dst_stride );
        res_hz0 = res_hz4;

        VSHF_B2_UB( src1, src5, src2, src6,
                    ( mask + 1 ), ( mask + 1 ), src5, src6 );
        VSHF_B2_UB( src3, src7, src4, src8,
                    ( mask + 1 ), ( mask + 1 ), src7, src8 );
        DOTP_UB4_UH( src5, src6, src7, src8, coeff_hz_vec, coeff_hz_vec,
                     coeff_hz_vec, coeff_hz_vec, res_hz1, res_hz2, res_hz3,
                     res_hz4 );
        MUL4( res_hz1, coeff_vt_vec0, res_hz2, coeff_vt_vec0, res_hz3,
              coeff_vt_vec0, res_hz4, coeff_vt_vec0, res_vt0, res_vt1, res_vt2,
              res_vt3 );

        res_vt0 += ( res_hz5 * coeff_vt_vec1 );
        res_vt1 += ( res_hz1 * coeff_vt_vec1 );
        res_vt2 += ( res_hz2 * coeff_vt_vec1 );
        res_vt3 += ( res_hz3 * coeff_vt_vec1 );

        SRARI_H4_UH( res_vt0, res_vt1, res_vt2, res_vt3, 6 );
        SAT_UH4_UH( res_vt0, res_vt1, res_vt2, res_vt3, 7 );
        PCKEV_B2_SB( res_vt1, res_vt0, res_vt3, res_vt2, tmp0, tmp1 );
        ST8x4_UB( tmp0, tmp1, p_dst_v, i_dst_stride );
        p_dst_v += ( 4 * i_dst_stride );
        res_hz5 = res_hz4;
    }
}

static void avc_wgt_opscale_4x2_msa( uint8_t *p_src, int32_t i_src_stride,
                                     uint8_t *p_dst, int32_t i_dst_stride,
                                     int32_t i_log2_denom, int32_t i_weight,
                                     int32_t i_offset_in )
{
    uint32_t u_load0, u_load1, u_out0, u_out1;
    v16u8 zero = { 0 };
    v16u8 src0, src1;
    v4i32 dst0, dst1;
    v8u16 temp0, temp1, wgt, denom, offset, tp0, tp1;
    v8i16 vec0, vec1;

    i_offset_in <<= ( i_log2_denom );

    if( i_log2_denom )
    {
        i_offset_in += ( 1 << ( i_log2_denom - 1 ) );
    }

    wgt = ( v8u16 ) __msa_fill_h( i_weight );
    offset = ( v8u16 ) __msa_fill_h( i_offset_in );
    denom = ( v8u16 ) __msa_fill_h( i_log2_denom );

    u_load0 = LW( p_src );
    p_src += i_src_stride;
    u_load1 = LW( p_src );

    src0 = ( v16u8 ) __msa_fill_w( u_load0 );
    src1 = ( v16u8 ) __msa_fill_w( u_load1 );

    ILVR_B2_UH( zero, src0, zero, src1, temp0, temp1 );
    MUL2( wgt, temp0, wgt, temp1, temp0, temp1 );
    ADDS_SH2_SH( temp0, offset, temp1, offset, vec0, vec1 );
    MAXI_SH2_SH( vec0, vec1, 0 );

    tp0 = ( v8u16 ) __msa_srl_h( vec0, ( v8i16 ) denom );
    tp1 = ( v8u16 ) __msa_srl_h( vec1, ( v8i16 ) denom );

    SAT_UH2_UH( tp0, tp1, 7 );
    PCKEV_B2_SW( tp0, tp0, tp1, tp1, dst0, dst1 );

    u_out0 = __msa_copy_u_w( dst0, 0 );
    u_out1 = __msa_copy_u_w( dst1, 0 );
    SW( u_out0, p_dst );
    p_dst += i_dst_stride;
    SW( u_out1, p_dst );
}

static void avc_wgt_opscale_4x4multiple_msa( uint8_t *p_src,
                                             int32_t i_src_stride,
                                             uint8_t *p_dst,
                                             int32_t i_dst_stride,
                                             int32_t i_height,
                                             int32_t i_log2_denom,
                                             int32_t i_weight,
                                             int32_t i_offset_in )
{
    uint8_t u_cnt;
    uint32_t u_load0, u_load1, u_load2, u_load3;
    v16u8 zero = { 0 };
    v16u8 src0, src1, src2, src3;
    v8u16 temp0, temp1, temp2, temp3;
    v8u16 wgt, denom, offset;

    i_offset_in <<= ( i_log2_denom );

    if( i_log2_denom )
    {
        i_offset_in += ( 1 << ( i_log2_denom - 1 ) );
    }

    wgt = ( v8u16 ) __msa_fill_h( i_weight );
    offset = ( v8u16 ) __msa_fill_h( i_offset_in );
    denom = ( v8u16 ) __msa_fill_h( i_log2_denom );

    for( u_cnt = i_height / 4; u_cnt--; )
    {
        LW4( p_src, i_src_stride, u_load0, u_load1, u_load2, u_load3 );
        p_src += 4 * i_src_stride;

        src0 = ( v16u8 ) __msa_fill_w( u_load0 );
        src1 = ( v16u8 ) __msa_fill_w( u_load1 );
        src2 = ( v16u8 ) __msa_fill_w( u_load2 );
        src3 = ( v16u8 ) __msa_fill_w( u_load3 );

        ILVR_B4_UH( zero, src0, zero, src1, zero, src2, zero, src3,
                    temp0, temp1, temp2, temp3 );
        MUL4( wgt, temp0, wgt, temp1, wgt, temp2, wgt, temp3,
              temp0, temp1, temp2, temp3 );
        ADDS_SH4_UH( temp0, offset, temp1, offset, temp2, offset, temp3, offset,
                     temp0, temp1, temp2, temp3 );
        MAXI_SH4_UH( temp0, temp1, temp2, temp3, 0 );
        SRL_H4_UH( temp0, temp1, temp2, temp3, denom );
        SAT_UH4_UH( temp0, temp1, temp2, temp3, 7 );
        PCKEV_ST4x4_UB( temp0, temp1, temp2, temp3, p_dst, i_dst_stride );
        p_dst += ( 4 * i_dst_stride );
    }
}

static void avc_wgt_opscale_4width_msa( uint8_t *p_src, int32_t i_src_stride,
                                        uint8_t *p_dst, int32_t i_dst_stride,
                                        int32_t i_height, int32_t i_log2_denom,
                                        int32_t i_weight, int32_t i_offset_in )
{
    if( 2 == i_height )
    {
        avc_wgt_opscale_4x2_msa( p_src, i_src_stride, p_dst, i_dst_stride,
                                 i_log2_denom, i_weight, i_offset_in );
    }
    else
    {
        avc_wgt_opscale_4x4multiple_msa( p_src, i_src_stride,
                                         p_dst, i_dst_stride,
                                         i_height, i_log2_denom,
                                         i_weight, i_offset_in );
    }
}

static void avc_wgt_opscale_8width_msa( uint8_t *p_src, int32_t i_src_stride,
                                        uint8_t *p_dst, int32_t i_dst_stride,
                                        int32_t i_height, int32_t i_log2_denom,
                                        int32_t i_weight, int32_t i_offset_in )
{
    uint8_t u_cnt;
    v16u8 zero = { 0 };
    v16u8 src0, src1, src2, src3;
    v8u16 temp0, temp1, temp2, temp3;
    v8u16 wgt, denom, offset;
    v16i8 out0, out1;

    i_offset_in <<= ( i_log2_denom );

    if( i_log2_denom )
    {
        i_offset_in += ( 1 << ( i_log2_denom - 1 ) );
    }

    wgt = ( v8u16 ) __msa_fill_h( i_weight );
    offset = ( v8u16 ) __msa_fill_h( i_offset_in );
    denom = ( v8u16 ) __msa_fill_h( i_log2_denom );

    for( u_cnt = i_height / 4; u_cnt--; )
    {
        LD_UB4( p_src, i_src_stride, src0, src1, src2, src3 );
        p_src += 4 * i_src_stride;

        ILVR_B4_UH( zero, src0, zero, src1, zero, src2, zero, src3,
                    temp0, temp1, temp2, temp3 );
        MUL4( wgt, temp0, wgt, temp1, wgt, temp2, wgt, temp3,
              temp0, temp1, temp2, temp3 );
        ADDS_SH4_UH( temp0, offset, temp1, offset, temp2, offset, temp3, offset,
                     temp0, temp1, temp2, temp3 );
        MAXI_SH4_UH( temp0, temp1, temp2, temp3, 0 );
        SRL_H4_UH( temp0, temp1, temp2, temp3, denom );
        SAT_UH4_UH( temp0, temp1, temp2, temp3, 7 );
        PCKEV_B2_SB( temp1, temp0, temp3, temp2, out0, out1 );
        ST8x4_UB( out0, out1, p_dst, i_dst_stride );
        p_dst += ( 4 * i_dst_stride );
    }
}

static void avc_wgt_opscale_16width_msa( uint8_t *p_src, int32_t i_src_stride,
                                         uint8_t *p_dst, int32_t i_dst_stride,
                                         int32_t i_height, int32_t i_log2_denom,
                                         int32_t i_weight, int32_t i_offset_in )
{
    uint8_t u_cnt;
    v16i8 zero = { 0 };
    v16u8 src0, src1, src2, src3, dst0, dst1, dst2, dst3;
    v8u16 temp0, temp1, temp2, temp3, temp4, temp5, temp6, temp7;
    v8u16 wgt, denom, offset;

    i_offset_in <<= ( i_log2_denom );

    if( i_log2_denom )
    {
        i_offset_in += ( 1 << ( i_log2_denom - 1 ) );
    }

    wgt = ( v8u16 ) __msa_fill_h( i_weight );
    offset = ( v8u16 ) __msa_fill_h( i_offset_in );
    denom = ( v8u16 ) __msa_fill_h( i_log2_denom );

    for( u_cnt = i_height / 4; u_cnt--; )
    {
        LD_UB4( p_src, i_src_stride, src0, src1, src2, src3 );
        p_src += 4 * i_src_stride;

        ILVR_B4_UH( zero, src0, zero, src1, zero, src2, zero, src3,
                    temp0, temp2, temp4, temp6 );
        ILVL_B4_UH( zero, src0, zero, src1, zero, src2, zero, src3,
                    temp1, temp3, temp5, temp7 );
        MUL4( wgt, temp0, wgt, temp1, wgt, temp2, wgt, temp3,
              temp0, temp1, temp2, temp3 );
        MUL4( wgt, temp4, wgt, temp5, wgt, temp6, wgt, temp7,
              temp4, temp5, temp6, temp7 );
        ADDS_SH4_UH( temp0, offset, temp1, offset, temp2, offset, temp3, offset,
                     temp0, temp1, temp2, temp3 );
        ADDS_SH4_UH( temp4, offset, temp5, offset, temp6, offset, temp7, offset,
                     temp4, temp5, temp6, temp7 );
        MAXI_SH4_UH( temp0, temp1, temp2, temp3, 0 );
        MAXI_SH4_UH( temp4, temp5, temp6, temp7, 0 );
        SRL_H4_UH( temp0, temp1, temp2, temp3, denom );
        SRL_H4_UH( temp4, temp5, temp6, temp7, denom );
        SAT_UH4_UH( temp0, temp1, temp2, temp3, 7 );
        SAT_UH4_UH( temp4, temp5, temp6, temp7, 7 );
        PCKEV_B4_UB( temp1, temp0, temp3, temp2, temp5, temp4, temp7, temp6,
                     dst0, dst1, dst2, dst3 );

        ST_UB4( dst0, dst1, dst2, dst3, p_dst, i_dst_stride );
        p_dst += 4 * i_dst_stride;
    }
}

static void avc_biwgt_opscale_4x2_nw_msa( uint8_t *p_src1_in,
                                          int32_t i_src1_stride,
                                          uint8_t *p_src2_in,
                                          int32_t i_src2_stride,
                                          uint8_t *p_dst,
                                          int32_t i_dst_stride,
                                          int32_t i_log2_denom,
                                          int32_t i_src1_weight,
                                          int32_t i_src2_weight,
                                          int32_t i_offset_in )
{
    uint32_t u_load0, u_load1, u_out0, u_out1;
    v8i16 src1_wgt, src2_wgt;
    v16u8 in0, in1, in2, in3;
    v8i16 temp0, temp1, temp2, temp3;
    v16i8 zero = { 0 };
    v8i16 denom = __msa_ldi_h( i_log2_denom + 1 );

    src1_wgt = __msa_fill_h( i_src1_weight );
    src2_wgt = __msa_fill_h( i_src2_weight );
    u_load0 = LW( p_src1_in );
    u_load1 = LW( p_src1_in + i_src1_stride );
    in0 = ( v16u8 ) __msa_fill_w( u_load0 );
    in1 = ( v16u8 ) __msa_fill_w( u_load1 );
    u_load0 = LW( p_src2_in );
    u_load1 = LW( p_src2_in + i_src2_stride );
    in2 = ( v16u8 ) __msa_fill_w( u_load0 );
    in3 = ( v16u8 ) __msa_fill_w( u_load1 );
    ILVR_B4_SH( zero, in0, zero, in1, zero, in2, zero, in3,
                temp0, temp1, temp2, temp3 );
    temp0 = ( temp0 * src1_wgt ) + ( temp2 * src2_wgt );
    temp1 = ( temp1 * src1_wgt ) + ( temp3 * src2_wgt );
    SRAR_H2_SH( temp0, temp1, denom );
    CLIP_SH2_0_255( temp0, temp1 );
    PCKEV_B2_UB( temp0, temp0, temp1, temp1, in0, in1 );
    u_out0 = __msa_copy_u_w( ( v4i32 ) in0, 0 );
    u_out1 = __msa_copy_u_w( ( v4i32 ) in1, 0 );
    SW( u_out0, p_dst );
    p_dst += i_dst_stride;
    SW( u_out1, p_dst );
}

static void avc_biwgt_opscale_4x4multiple_nw_msa( uint8_t *p_src1_in,
                                                  int32_t i_src1_stride,
                                                  uint8_t *p_src2_in,
                                                  int32_t i_src2_stride,
                                                  uint8_t *p_dst,
                                                  int32_t i_dst_stride,
                                                  int32_t i_height,
                                                  int32_t i_log2_denom,
                                                  int32_t i_src1_weight,
                                                  int32_t i_src2_weight,
                                                  int32_t i_offset_in )
{
    uint8_t u_cnt;
    uint32_t u_load0, u_load1, u_load2, u_load3;
    v8i16 src1_wgt, src2_wgt;
    v16u8 src0, src1, src2, src3, src4, src5, src6, src7;
    v8i16 temp0, temp1, temp2, temp3, temp4, temp5, temp6, temp7;
    v16i8 zero = { 0 };
    v8i16 denom = __msa_ldi_h( i_log2_denom + 1 );

    src1_wgt = __msa_fill_h( i_src1_weight );
    src2_wgt = __msa_fill_h( i_src2_weight );
    for( u_cnt = i_height / 4; u_cnt--; )
    {
        LW4( p_src1_in, i_src1_stride, u_load0, u_load1, u_load2, u_load3 );
        p_src1_in += ( 4 * i_src1_stride );
        src0 = ( v16u8 ) __msa_fill_w( u_load0 );
        src1 = ( v16u8 ) __msa_fill_w( u_load1 );
        src2 = ( v16u8 ) __msa_fill_w( u_load2 );
        src3 = ( v16u8 ) __msa_fill_w( u_load3 );
        LW4( p_src2_in, i_src2_stride, u_load0, u_load1, u_load2, u_load3 );
        p_src2_in += ( 4 * i_src2_stride );
        src4 = ( v16u8 ) __msa_fill_w( u_load0 );
        src5 = ( v16u8 ) __msa_fill_w( u_load1 );
        src6 = ( v16u8 ) __msa_fill_w( u_load2 );
        src7 = ( v16u8 ) __msa_fill_w( u_load3 );
        ILVR_B4_SH( zero, src0, zero, src1, zero, src2, zero, src3,
                    temp0, temp1, temp2, temp3 );
        ILVR_B4_SH( zero, src4, zero, src5, zero, src6, zero, src7,
                    temp4, temp5, temp6, temp7 );
        temp0 = ( temp0 * src1_wgt ) + ( temp4 * src2_wgt );
        temp1 = ( temp1 * src1_wgt ) + ( temp5 * src2_wgt );
        temp2 = ( temp2 * src1_wgt ) + ( temp6 * src2_wgt );
        temp3 = ( temp3 * src1_wgt ) + ( temp7 * src2_wgt );
        SRAR_H4_SH( temp0, temp1, temp2, temp3, denom );
        CLIP_SH4_0_255( temp0, temp1, temp2, temp3 );
        PCKEV_ST4x4_UB( temp0, temp1, temp2, temp3, p_dst, i_dst_stride );
        p_dst += ( 4 * i_dst_stride );
    }
}

static void avc_biwgt_opscale_4width_nw_msa( uint8_t *p_src1_in,
                                             int32_t i_src1_stride,
                                             uint8_t *p_src2_in,
                                             int32_t i_src2_stride,
                                             uint8_t *p_dst,
                                             int32_t i_dst_stride,
                                             int32_t i_height,
                                             int32_t i_log2_denom,
                                             int32_t i_src1_weight,
                                             int32_t i_src2_weight,
                                             int32_t i_offset_in )
{
    if( 2 == i_height )
    {
        avc_biwgt_opscale_4x2_nw_msa( p_src1_in, i_src1_stride,
                                      p_src2_in, i_src2_stride,
                                      p_dst, i_dst_stride,
                                      i_log2_denom, i_src1_weight,
                                      i_src2_weight, i_offset_in );
    }
    else
    {
        avc_biwgt_opscale_4x4multiple_nw_msa( p_src1_in, i_src1_stride,
                                              p_src2_in, i_src2_stride,
                                              p_dst, i_dst_stride,
                                              i_height, i_log2_denom,
                                              i_src1_weight, i_src2_weight,
                                              i_offset_in );
    }
}

static void avc_biwgt_opscale_8width_nw_msa( uint8_t *p_src1_in,
                                             int32_t i_src1_stride,
                                             uint8_t *p_src2_in,
                                             int32_t i_src2_stride,
                                             uint8_t *p_dst,
                                             int32_t i_dst_stride,
                                             int32_t i_height,
                                             int32_t i_log2_denom,
                                             int32_t i_src1_weight,
                                             int32_t i_src2_weight,
                                             int32_t i_offset_in )
{
    uint8_t u_cnt;
    v8i16 src1_wgt, src2_wgt;
    v16u8 src0, src1, src2, src3;
    v16u8 dst0, dst1, dst2, dst3;
    v8i16 temp0, temp1, temp2, temp3;
    v8i16 res0, res1, res2, res3;
    v16i8 zero = { 0 };
    v8i16 denom = __msa_ldi_h( i_log2_denom + 1 );

    src1_wgt = __msa_fill_h( i_src1_weight );
    src2_wgt = __msa_fill_h( i_src2_weight );

    for( u_cnt = i_height / 4; u_cnt--; )
    {
        LD_UB4( p_src1_in, i_src1_stride, src0, src1, src2, src3 );
        p_src1_in += ( 4 * i_src1_stride );
        LD_UB4( p_src2_in, i_src2_stride, dst0, dst1, dst2, dst3 );
        p_src2_in += ( 4 * i_src2_stride );
        ILVR_B4_SH( zero, src0, zero, src1, zero, src2, zero, src3,
                    temp0, temp1, temp2, temp3 );
        ILVR_B4_SH( zero, dst0, zero, dst1, zero, dst2, zero, dst3,
                    res0, res1, res2, res3 );
        res0 = ( temp0 * src1_wgt ) + ( res0 * src2_wgt );
        res1 = ( temp1 * src1_wgt ) + ( res1 * src2_wgt );
        res2 = ( temp2 * src1_wgt ) + ( res2 * src2_wgt );
        res3 = ( temp3 * src1_wgt ) + ( res3 * src2_wgt );
        SRAR_H4_SH( res0, res1, res2, res3, denom );
        CLIP_SH4_0_255( res0, res1, res2, res3 );
        PCKEV_B4_UB( res0, res0, res1, res1, res2, res2, res3, res3,
                     dst0, dst1, dst2, dst3 );
        ST8x1_UB( dst0, p_dst );
        p_dst += i_dst_stride;
        ST8x1_UB( dst1, p_dst );
        p_dst += i_dst_stride;
        ST8x1_UB( dst2, p_dst );
        p_dst += i_dst_stride;
        ST8x1_UB( dst3, p_dst );
        p_dst += i_dst_stride;
    }
}

static void avc_biwgt_opscale_16width_nw_msa( uint8_t *p_src1_in,
                                              int32_t i_src1_stride,
                                              uint8_t *p_src2_in,
                                              int32_t i_src2_stride,
                                              uint8_t *p_dst,
                                              int32_t i_dst_stride,
                                              int32_t i_height,
                                              int32_t i_log2_denom,
                                              int32_t i_src1_weight,
                                              int32_t i_src2_weight,
                                              int32_t i_offset_in )
{
    uint8_t u_cnt;
    v8i16 src1_wgt, src2_wgt;
    v16u8 src0, src1, src2, src3;
    v16u8 dst0, dst1, dst2, dst3;
    v8i16 temp0, temp1, temp2, temp3, temp4, temp5, temp6, temp7;
    v8i16 res0, res1, res2, res3, res4, res5, res6, res7;
    v16i8 zero = { 0 };
    v8i16 denom = __msa_ldi_h( i_log2_denom + 1 );

    src1_wgt = __msa_fill_h( i_src1_weight );
    src2_wgt = __msa_fill_h( i_src2_weight );

    for( u_cnt = i_height / 4; u_cnt--; )
    {
        LD_UB4( p_src1_in, i_src1_stride, src0, src1, src2, src3 );
        p_src1_in += ( 4 * i_src1_stride );
        LD_UB4( p_src2_in, i_src2_stride, dst0, dst1, dst2, dst3 );
        p_src2_in += ( 4 * i_src2_stride );
        ILVRL_B2_SH( zero, src0, temp1, temp0 );
        ILVRL_B2_SH( zero, src1, temp3, temp2 );
        ILVRL_B2_SH( zero, src2, temp5, temp4 );
        ILVRL_B2_SH( zero, src3, temp7, temp6 );
        ILVRL_B2_SH( zero, dst0, res1, res0 );
        ILVRL_B2_SH( zero, dst1, res3, res2 );
        ILVRL_B2_SH( zero, dst2, res5, res4 );
        ILVRL_B2_SH( zero, dst3, res7, res6 );
        res0 = ( temp0 * src1_wgt ) + ( res0 * src2_wgt );
        res1 = ( temp1 * src1_wgt ) + ( res1 * src2_wgt );
        res2 = ( temp2 * src1_wgt ) + ( res2 * src2_wgt );
        res3 = ( temp3 * src1_wgt ) + ( res3 * src2_wgt );
        res4 = ( temp4 * src1_wgt ) + ( res4 * src2_wgt );
        res5 = ( temp5 * src1_wgt ) + ( res5 * src2_wgt );
        res6 = ( temp6 * src1_wgt ) + ( res6 * src2_wgt );
        res7 = ( temp7 * src1_wgt ) + ( res7 * src2_wgt );
        SRAR_H4_SH( res0, res1, res2, res3, denom );
        SRAR_H4_SH( res4, res5, res6, res7, denom );
        CLIP_SH4_0_255( res0, res1, res2, res3 );
        CLIP_SH4_0_255( res4, res5, res6, res7 );
        PCKEV_B4_UB( res0, res1, res2, res3, res4, res5, res6, res7,
                     dst0, dst1, dst2, dst3 );
        ST_UB4( dst0, dst1, dst2, dst3, p_dst, i_dst_stride );
        p_dst += 4 * i_dst_stride;
    }
}

static void avc_biwgt_opscale_4x2_msa( uint8_t *p_src1_in,
                                       int32_t i_src1_stride,
                                       uint8_t *p_src2_in,
                                       int32_t i_src2_stride,
                                       uint8_t *p_dst, int32_t i_dst_stride,
                                       int32_t i_log2_denom,
                                       int32_t i_src1_weight,
                                       int32_t i_src2_weight,
                                       int32_t i_offset_in )
{
    uint32_t u_load0, u_load1, u_out0, u_out1;
    v16u8 src1_wgt, src2_wgt, wgt;
    v16i8 in0, in1, in2, in3;
    v8u16 temp0, temp1, denom, offset;

    i_offset_in = ( ( i_offset_in + 1 ) | 1 ) << i_log2_denom;

    src1_wgt = ( v16u8 ) __msa_fill_b( i_src1_weight );
    src2_wgt = ( v16u8 ) __msa_fill_b( i_src2_weight );
    offset = ( v8u16 ) __msa_fill_h( i_offset_in );
    denom = ( v8u16 ) __msa_fill_h( i_log2_denom + 1 );

    wgt = ( v16u8 ) __msa_ilvev_b( ( v16i8 ) src2_wgt, ( v16i8 ) src1_wgt );

    u_load0 = LW( p_src1_in );
    u_load1 = LW( p_src1_in + i_src1_stride );
    in0 = ( v16i8 ) __msa_fill_w( u_load0 );
    in1 = ( v16i8 ) __msa_fill_w( u_load1 );

    u_load0 = LW( p_src2_in );
    u_load1 = LW( p_src2_in + i_src2_stride );
    in2 = ( v16i8 ) __msa_fill_w( u_load0 );
    in3 = ( v16i8 ) __msa_fill_w( u_load1 );

    ILVR_B2_SB( in2, in0, in3, in1, in0, in1 );

    temp0 = __msa_dpadd_u_h( offset, wgt, ( v16u8 ) in0 );
    temp1 = __msa_dpadd_u_h( offset, wgt, ( v16u8 ) in1 );
    temp0 >>= denom;
    temp1 >>= denom;
    MAXI_SH2_UH( temp0, temp1, 0 );
    SAT_UH2_UH( temp0, temp1, 7 );
    PCKEV_B2_SB( temp0, temp0, temp1, temp1, in0, in1 );

    u_out0 = __msa_copy_u_w( ( v4i32 ) in0, 0 );
    u_out1 = __msa_copy_u_w( ( v4i32 ) in1, 0 );
    SW( u_out0, p_dst );
    p_dst += i_dst_stride;
    SW( u_out1, p_dst );
}

static void avc_biwgt_opscale_4x4multiple_msa( uint8_t *p_src1_in,
                                               int32_t i_src1_stride,
                                               uint8_t *p_src2_in,
                                               int32_t i_src2_stride,
                                               uint8_t *p_dst,
                                               int32_t i_dst_stride,
                                               int32_t i_height,
                                               int32_t i_log2_denom,
                                               int32_t i_src1_weight,
                                               int32_t i_src2_weight,
                                               int32_t i_offset_in )
{
    uint8_t u_cnt;
    uint32_t u_load0, u_load1, u_load2, u_load3;
    v16u8 src1_wgt, src2_wgt, wgt;
    v16u8 src0, src1, src2, src3, src4, src5, src6, src7;
    v16u8 temp0, temp1, temp2, temp3;
    v8u16 res0, res1, res2, res3;
    v8u16 denom, offset;

    i_offset_in = ( ( i_offset_in + 1 ) | 1 ) << i_log2_denom;

    src1_wgt = ( v16u8 ) __msa_fill_b( i_src1_weight );
    src2_wgt = ( v16u8 ) __msa_fill_b( i_src2_weight );
    offset = ( v8u16 ) __msa_fill_h( i_offset_in );
    denom = ( v8u16 ) __msa_fill_h( i_log2_denom + 1 );

    wgt = ( v16u8 ) __msa_ilvev_b( ( v16i8 ) src2_wgt, ( v16i8 ) src1_wgt );

    for( u_cnt = i_height / 4; u_cnt--; )
    {
        LW4( p_src1_in, i_src1_stride, u_load0, u_load1, u_load2, u_load3 );
        p_src1_in += ( 4 * i_src1_stride );

        src0 = ( v16u8 ) __msa_fill_w( u_load0 );
        src1 = ( v16u8 ) __msa_fill_w( u_load1 );
        src2 = ( v16u8 ) __msa_fill_w( u_load2 );
        src3 = ( v16u8 ) __msa_fill_w( u_load3 );

        LW4( p_src2_in, i_src2_stride, u_load0, u_load1, u_load2, u_load3 );
        p_src2_in += ( 4 * i_src2_stride );

        src4 = ( v16u8 ) __msa_fill_w( u_load0 );
        src5 = ( v16u8 ) __msa_fill_w( u_load1 );
        src6 = ( v16u8 ) __msa_fill_w( u_load2 );
        src7 = ( v16u8 ) __msa_fill_w( u_load3 );

        ILVR_B4_UB( src4, src0, src5, src1, src6, src2, src7, src3,
                    temp0, temp1, temp2, temp3 );
        DOTP_UB4_UH( temp0, temp1, temp2, temp3, wgt, wgt, wgt, wgt,
                     res0, res1, res2, res3 );
        ADD4( res0, offset, res1, offset, res2, offset, res3, offset,
              res0, res1, res2, res3 );
        SRA_4V( res0, res1, res2, res3, denom );
        MAXI_SH4_UH( res0, res1, res2, res3, 0 );
        SAT_UH4_UH( res0, res1, res2, res3, 7 );
        PCKEV_ST4x4_UB( res0, res1, res2, res3, p_dst, i_dst_stride );
        p_dst += ( 4 * i_dst_stride );
    }
}

static void avc_biwgt_opscale_4width_msa( uint8_t *p_src1_in,
                                          int32_t i_src1_stride,
                                          uint8_t *p_src2_in,
                                          int32_t i_src2_stride,
                                          uint8_t *p_dst,
                                          int32_t i_dst_stride,
                                          int32_t i_height,
                                          int32_t i_log2_denom,
                                          int32_t i_src1_weight,
                                          int32_t i_src2_weight,
                                          int32_t i_offset_in )
{
    if( 2 == i_height )
    {
        avc_biwgt_opscale_4x2_msa( p_src1_in, i_src1_stride,
                                   p_src2_in, i_src2_stride,
                                   p_dst, i_dst_stride,
                                   i_log2_denom, i_src1_weight,
                                   i_src2_weight, i_offset_in );
    }
    else
    {
        avc_biwgt_opscale_4x4multiple_msa( p_src1_in, i_src1_stride,
                                           p_src2_in, i_src2_stride,
                                           p_dst, i_dst_stride,
                                           i_height, i_log2_denom,
                                           i_src1_weight,
                                           i_src2_weight, i_offset_in );
    }
}


static void avc_biwgt_opscale_8width_msa( uint8_t *p_src1_in,
                                          int32_t i_src1_stride,
                                          uint8_t *p_src2_in,
                                          int32_t i_src2_stride,
                                          uint8_t *p_dst,
                                          int32_t i_dst_stride,
                                          int32_t i_height,
                                          int32_t i_log2_denom,
                                          int32_t i_src1_weight,
                                          int32_t i_src2_weight,
                                          int32_t i_offset_in )
{
    uint8_t u_cnt;
    v16u8 src1_wgt, src2_wgt, wgt;
    v16u8 src0, src1, src2, src3, src4, src5, src6, src7;
    v16u8 temp0, temp1, temp2, temp3;
    v8u16 res0, res1, res2, res3;
    v8u16 denom, offset;
    v16i8 out0, out1;

    i_offset_in = ( ( i_offset_in + 1 ) | 1 ) << i_log2_denom;

    src1_wgt = ( v16u8 ) __msa_fill_b( i_src1_weight );
    src2_wgt = ( v16u8 ) __msa_fill_b( i_src2_weight );
    offset = ( v8u16 ) __msa_fill_h( i_offset_in );
    denom = ( v8u16 ) __msa_fill_h( i_log2_denom + 1 );

    wgt = ( v16u8 ) __msa_ilvev_b( ( v16i8 ) src2_wgt, ( v16i8 ) src1_wgt );

    for( u_cnt = i_height / 4; u_cnt--; )
    {
        LD_UB4( p_src1_in, i_src1_stride, src0, src1, src2, src3 );
        p_src1_in += ( 4 * i_src1_stride );

        LD_UB4( p_src2_in, i_src2_stride, src4, src5, src6, src7 );
        p_src2_in += ( 4 * i_src2_stride );

        ILVR_B4_UB( src4, src0, src5, src1, src6, src2, src7, src3,
                    temp0, temp1, temp2, temp3 );
        DOTP_UB4_UH( temp0, temp1, temp2, temp3, wgt, wgt, wgt, wgt,
                     res0, res1, res2, res3 );
        ADD4( res0, offset, res1, offset, res2, offset, res3, offset,
              res0, res1, res2, res3 );
        SRA_4V( res0, res1, res2, res3, denom );
        MAXI_SH4_UH( res0, res1, res2, res3, 0 );
        SAT_UH4_UH( res0, res1, res2, res3, 7 );
        PCKEV_B2_SB( res1, res0, res3, res2, out0, out1 );
        ST8x4_UB( out0, out1, p_dst, i_dst_stride );
        p_dst += 4 * i_dst_stride;
    }
}

static void avc_biwgt_opscale_16width_msa( uint8_t *p_src1_in,
                                           int32_t i_src1_stride,
                                           uint8_t *p_src2_in,
                                           int32_t i_src2_stride,
                                           uint8_t *p_dst,
                                           int32_t i_dst_stride,
                                           int32_t i_height,
                                           int32_t i_log2_denom,
                                           int32_t i_src1_weight,
                                           int32_t i_src2_weight,
                                           int32_t i_offset_in )
{
    uint8_t u_cnt;
    v16u8 src1_wgt, src2_wgt, wgt;
    v16u8 src0, src1, src2, src3, src4, src5, src6, src7;
    v16u8 temp0, temp1, temp2, temp3, temp4, temp5, temp6, temp7;
    v8u16 res0, res1, res2, res3, res4, res5, res6, res7;
    v8u16 denom, offset;

    i_offset_in = ( ( i_offset_in + 1 ) | 1 ) << i_log2_denom;

    src1_wgt = ( v16u8 ) __msa_fill_b( i_src1_weight );
    src2_wgt = ( v16u8 ) __msa_fill_b( i_src2_weight );
    offset = ( v8u16 ) __msa_fill_h( i_offset_in );
    denom = ( v8u16 ) __msa_fill_h( i_log2_denom + 1 );

    wgt = ( v16u8 ) __msa_ilvev_b( ( v16i8 ) src2_wgt, ( v16i8 ) src1_wgt );

    for( u_cnt = i_height / 4; u_cnt--; )
    {
        LD_UB4( p_src1_in, i_src1_stride, src0, src1, src2, src3 );
        p_src1_in += ( 4 * i_src1_stride );

        LD_UB4( p_src2_in, i_src2_stride, src4, src5, src6, src7 );
        p_src2_in += ( 4 * i_src2_stride );

        ILVR_B4_UB( src4, src0, src5, src1, src6, src2, src7, src3,
                    temp0, temp2, temp4, temp6 );
        ILVL_B4_UB( src4, src0, src5, src1, src6, src2, src7, src3,
                    temp1, temp3, temp5, temp7 );
        DOTP_UB4_UH( temp0, temp1, temp2, temp3, wgt, wgt, wgt, wgt,
                     res0, res1, res2, res3 );
        ADD4( res0, offset, res1, offset, res2, offset, res3, offset,
              res0, res1, res2, res3 );
        DOTP_UB4_UH( temp4, temp5, temp6, temp7, wgt, wgt, wgt, wgt,
                     res4, res5, res6, res7 );
        ADD4( res4, offset, res5, offset, res6, offset, res7, offset,
              res4, res5, res6, res7 );
        SRA_4V( res0, res1, res2, res3, denom );
        SRA_4V( res4, res5, res6, res7, denom );
        MAXI_SH4_UH( res0, res1, res2, res3, 0 );
        MAXI_SH4_UH( res4, res5, res6, res7, 0 );
        SAT_UH4_UH( res0, res1, res2, res3, 7 );
        SAT_UH4_UH( res4, res5, res6, res7, 7 );
        PCKEV_B4_UB( res1, res0, res3, res2, res5, res4, res7, res6,
                     temp0, temp1, temp2, temp3 );
        ST_UB4( temp0, temp1, temp2, temp3, p_dst, i_dst_stride );
        p_dst += 4 * i_dst_stride;
    }
}

static void copy_width4_msa( uint8_t *p_src, int32_t i_src_stride,
                             uint8_t *p_dst, int32_t i_dst_stride,
                             int32_t i_height )
{
    int32_t i_cnt;
    uint32_t u_src0, u_src1;

    for( i_cnt = ( i_height / 2 ); i_cnt--;  )
    {
        u_src0 = LW( p_src );
        p_src += i_src_stride;
        u_src1 = LW( p_src );
        p_src += i_src_stride;

        SW( u_src0, p_dst );
        p_dst += i_dst_stride;
        SW( u_src1, p_dst );
        p_dst += i_dst_stride;
    }
}

static void copy_width8_msa( uint8_t *p_src, int32_t i_src_stride,
                             uint8_t *p_dst, int32_t i_dst_stride,
                             int32_t i_height )
{
    int32_t i_cnt;
    uint64_t u_out0, u_out1, u_out2, u_out3, u_out4, u_out5, u_out6, u_out7;
    v16u8 src0, src1, src2, src3, src4, src5, src6, src7;

    if( 0 == i_height % 12 )
    {
        for( i_cnt = ( i_height / 12 ); i_cnt--; )
        {
            LD_UB8( p_src, i_src_stride,
                    src0, src1, src2, src3, src4, src5, src6, src7 );
            p_src += ( 8 * i_src_stride );

            u_out0 = __msa_copy_u_d( ( v2i64 ) src0, 0 );
            u_out1 = __msa_copy_u_d( ( v2i64 ) src1, 0 );
            u_out2 = __msa_copy_u_d( ( v2i64 ) src2, 0 );
            u_out3 = __msa_copy_u_d( ( v2i64 ) src3, 0 );
            u_out4 = __msa_copy_u_d( ( v2i64 ) src4, 0 );
            u_out5 = __msa_copy_u_d( ( v2i64 ) src5, 0 );
            u_out6 = __msa_copy_u_d( ( v2i64 ) src6, 0 );
            u_out7 = __msa_copy_u_d( ( v2i64 ) src7, 0 );

            SD4( u_out0, u_out1, u_out2, u_out3, p_dst, i_dst_stride );
            p_dst += ( 4 * i_dst_stride );
            SD4( u_out4, u_out5, u_out6, u_out7, p_dst, i_dst_stride );
            p_dst += ( 4 * i_dst_stride );

            LD_UB4( p_src, i_src_stride, src0, src1, src2, src3 );
            p_src += ( 4 * i_src_stride );

            u_out0 = __msa_copy_u_d( ( v2i64 ) src0, 0 );
            u_out1 = __msa_copy_u_d( ( v2i64 ) src1, 0 );
            u_out2 = __msa_copy_u_d( ( v2i64 ) src2, 0 );
            u_out3 = __msa_copy_u_d( ( v2i64 ) src3, 0 );

            SD4( u_out0, u_out1, u_out2, u_out3, p_dst, i_dst_stride );
            p_dst += ( 4 * i_dst_stride );
        }
    }
    else if( 0 == i_height % 8 )
    {
        for( i_cnt = i_height >> 3; i_cnt--; )
        {
            LD_UB8( p_src, i_src_stride,
                    src0, src1, src2, src3, src4, src5, src6, src7 );
            p_src += ( 8 * i_src_stride );

            u_out0 = __msa_copy_u_d( ( v2i64 ) src0, 0 );
            u_out1 = __msa_copy_u_d( ( v2i64 ) src1, 0 );
            u_out2 = __msa_copy_u_d( ( v2i64 ) src2, 0 );
            u_out3 = __msa_copy_u_d( ( v2i64 ) src3, 0 );
            u_out4 = __msa_copy_u_d( ( v2i64 ) src4, 0 );
            u_out5 = __msa_copy_u_d( ( v2i64 ) src5, 0 );
            u_out6 = __msa_copy_u_d( ( v2i64 ) src6, 0 );
            u_out7 = __msa_copy_u_d( ( v2i64 ) src7, 0 );

            SD4( u_out0, u_out1, u_out2, u_out3, p_dst, i_dst_stride );
            p_dst += ( 4 * i_dst_stride );
            SD4( u_out4, u_out5, u_out6, u_out7, p_dst, i_dst_stride );
            p_dst += ( 4 * i_dst_stride );
        }
    }
    else if( 0 == i_height % 4 )
    {
        for( i_cnt = ( i_height / 4 ); i_cnt--; )
        {
            LD_UB4( p_src, i_src_stride, src0, src1, src2, src3 );
            p_src += ( 4 * i_src_stride );
            u_out0 = __msa_copy_u_d( ( v2i64 ) src0, 0 );
            u_out1 = __msa_copy_u_d( ( v2i64 ) src1, 0 );
            u_out2 = __msa_copy_u_d( ( v2i64 ) src2, 0 );
            u_out3 = __msa_copy_u_d( ( v2i64 ) src3, 0 );

            SD4( u_out0, u_out1, u_out2, u_out3, p_dst, i_dst_stride );
            p_dst += ( 4 * i_dst_stride );
        }
    }
    else if( 0 == i_height % 2 )
    {
        for( i_cnt = ( i_height / 2 ); i_cnt--; )
        {
            LD_UB2( p_src, i_src_stride, src0, src1 );
            p_src += ( 2 * i_src_stride );
            u_out0 = __msa_copy_u_d( ( v2i64 ) src0, 0 );
            u_out1 = __msa_copy_u_d( ( v2i64 ) src1, 0 );

            SD( u_out0, p_dst );
            p_dst += i_dst_stride;
            SD( u_out1, p_dst );
            p_dst += i_dst_stride;
        }
    }
}


static void copy_16multx8mult_msa( uint8_t *p_src, int32_t i_src_stride,
                                   uint8_t *p_dst, int32_t i_dst_stride,
                                   int32_t i_height, int32_t i_width )
{
    int32_t i_cnt, i_loop_cnt;
    uint8_t *p_src_tmp, *p_dst_tmp;
    v16u8 src0, src1, src2, src3, src4, src5, src6, src7;

    for( i_cnt = ( i_width >> 4 ); i_cnt--; )
    {
        p_src_tmp = p_src;
        p_dst_tmp = p_dst;

        for( i_loop_cnt = ( i_height >> 3 ); i_loop_cnt--; )
        {
            LD_UB8( p_src_tmp, i_src_stride,
                    src0, src1, src2, src3, src4, src5, src6, src7 );
            p_src_tmp += ( 8 * i_src_stride );

            ST_UB8( src0, src1, src2, src3, src4, src5, src6, src7,
                    p_dst_tmp, i_dst_stride );
            p_dst_tmp += ( 8 * i_dst_stride );
        }

        p_src += 16;
        p_dst += 16;
    }
}

static void copy_width16_msa( uint8_t *p_src, int32_t i_src_stride,
                              uint8_t *p_dst, int32_t i_dst_stride,
                              int32_t i_height )
{
    int32_t i_cnt;
    v16u8 src0, src1, src2, src3, src4, src5, src6, src7;

    if( 0 == i_height % 12 )
    {
        for( i_cnt = ( i_height / 12 ); i_cnt--; )
        {
            LD_UB8( p_src, i_src_stride,
                    src0, src1, src2, src3, src4, src5, src6, src7 );
            p_src += ( 8 * i_src_stride );
            ST_UB8( src0, src1, src2, src3, src4, src5, src6, src7,
                    p_dst, i_dst_stride );
            p_dst += ( 8 * i_dst_stride );

            LD_UB4( p_src, i_src_stride, src0, src1, src2, src3 );
            p_src += ( 4 * i_src_stride );
            ST_UB4( src0, src1, src2, src3, p_dst, i_dst_stride );
            p_dst += ( 4 * i_dst_stride );
        }
    }
    else if( 0 == i_height % 8 )
    {
        copy_16multx8mult_msa( p_src, i_src_stride,
                               p_dst, i_dst_stride, i_height, 16 );
    }
    else if( 0 == i_height % 4 )
    {
        for( i_cnt = ( i_height >> 2 ); i_cnt--; )
        {
            LD_UB4( p_src, i_src_stride, src0, src1, src2, src3 );
            p_src += ( 4 * i_src_stride );

            ST_UB4( src0, src1, src2, src3, p_dst, i_dst_stride );
            p_dst += ( 4 * i_dst_stride );
        }
    }
}

static void avg_src_width4_msa( uint8_t *p_src1, int32_t i_src1_stride,
                                uint8_t *p_src2, int32_t i_src2_stride,
                                uint8_t *p_dst, int32_t i_dst_stride,
                                int32_t i_height )
{
    int32_t i_cnt;
    uint32_t u_out0, u_out1;
    v16u8 src0, src1, src2, src3;
    v16u8 dst0, dst1;

    for( i_cnt = ( i_height / 2 ); i_cnt--; )
    {
        LD_UB2( p_src1, i_src1_stride, src0, src1 );
        p_src1 += ( 2 * i_src1_stride );
        LD_UB2( p_src2, i_src2_stride, src2, src3 );
        p_src2 += ( 2 * i_src2_stride );

        AVER_UB2_UB( src0, src2, src1, src3, dst0, dst1 );

        u_out0 = __msa_copy_u_w( ( v4i32 ) dst0, 0 );
        u_out1 = __msa_copy_u_w( ( v4i32 ) dst1, 0 );
        SW( u_out0, p_dst );
        p_dst += i_dst_stride;
        SW( u_out1, p_dst );
        p_dst += i_dst_stride;
    }
}

static void avg_src_width8_msa( uint8_t *p_src1, int32_t i_src1_stride,
                                uint8_t *p_src2, int32_t i_src2_stride,
                                uint8_t *p_dst, int32_t i_dst_stride,
                                int32_t i_height )
{
    int32_t i_cnt;
    uint64_t u_out0, u_out1, u_out2, u_out3;
    v16u8 src0, src1, src2, src3, src4, src5, src6, src7;
    v16u8 dst0, dst1, dst2, dst3;

    for( i_cnt = ( i_height / 4 ); i_cnt--; )
    {
        LD_UB4( p_src1, i_src1_stride, src0, src1, src2, src3 );
        p_src1 += ( 4 * i_src1_stride );
        LD_UB4( p_src2, i_src2_stride, src4, src5, src6, src7 );
        p_src2 += ( 4 * i_src2_stride );

        AVER_UB4_UB( src0, src4, src1, src5, src2, src6, src3, src7,
                     dst0, dst1, dst2, dst3 );

        u_out0 = __msa_copy_u_d( ( v2i64 ) dst0, 0 );
        u_out1 = __msa_copy_u_d( ( v2i64 ) dst1, 0 );
        u_out2 = __msa_copy_u_d( ( v2i64 ) dst2, 0 );
        u_out3 = __msa_copy_u_d( ( v2i64 ) dst3, 0 );
        SD4( u_out0, u_out1, u_out2, u_out3, p_dst, i_dst_stride );
        p_dst += ( 4 * i_dst_stride );
    }
}

static void avg_src_width16_msa( uint8_t *p_src1, int32_t i_src1_stride,
                                 uint8_t *p_src2, int32_t i_src2_stride,
                                 uint8_t *p_dst, int32_t i_dst_stride,
                                 int32_t i_height )
{
    int32_t i_cnt;
    v16u8 src0, src1, src2, src3, src4, src5, src6, src7;
    v16u8 dst0, dst1, dst2, dst3, dst4, dst5, dst6, dst7;

    for( i_cnt = ( i_height / 8 ); i_cnt--; )
    {
        LD_UB8( p_src1, i_src1_stride,
                src0, src1, src2, src3, src4, src5, src6, src7 );
        p_src1 += ( 8 * i_src1_stride );
        LD_UB8( p_src2, i_src2_stride,
                dst0, dst1, dst2, dst3, dst4, dst5, dst6, dst7 );
        p_src2 += ( 8 * i_src2_stride );

        AVER_UB4_UB( src0, dst0, src1, dst1, src2, dst2, src3, dst3,
                     dst0, dst1, dst2, dst3 );
        AVER_UB4_UB( src4, dst4, src5, dst5, src6, dst6, src7, dst7,
                     dst4, dst5, dst6, dst7 );

        ST_UB8( dst0, dst1, dst2, dst3, dst4, dst5, dst6, dst7,
                p_dst, i_dst_stride );
        p_dst += ( 8 * i_dst_stride );
    }
}

static void memset_zero_16width_msa( uint8_t *p_src, int32_t i_stride,
                                     int32_t i_height )
{
    int8_t i_cnt;
    v16u8 zero = { 0 };

    for( i_cnt = ( i_height / 2 ); i_cnt--; )
    {
        ST_UB( zero, p_src );
        p_src += i_stride;
        ST_UB( zero, p_src );
        p_src += i_stride;
    }
}

static void core_plane_copy_interleave_msa( uint8_t *p_src0, int32_t i_src0_stride,
                                            uint8_t *p_src1, int32_t i_src1_stride,
                                            uint8_t *p_dst, int32_t i_dst_stride,
                                            int32_t i_width, int32_t i_height )
{
    int32_t i_loop_width, i_loop_height, i_w_mul8, i_h4w;
    v16u8 src0, src1, src2, src3, src4, src5, src6, src7;
    v16u8 vec_ilv_r0, vec_ilv_r1, vec_ilv_r2, vec_ilv_r3;
    v16u8 vec_ilv_l0, vec_ilv_l1, vec_ilv_l2, vec_ilv_l3;

    i_w_mul8 = i_width - i_width % 8;
    i_h4w = i_height - i_height % 4;

    for( i_loop_height = ( i_h4w >> 2 ); i_loop_height--; )
    {
        for( i_loop_width = ( i_width >> 4 ); i_loop_width--; )
        {
            LD_UB4( p_src0, i_src0_stride, src0, src1, src2, src3 );
            LD_UB4( p_src1, i_src1_stride, src4, src5, src6, src7 );
            ILVR_B4_UB( src4, src0, src5, src1, src6, src2, src7, src3,
                        vec_ilv_r0, vec_ilv_r1, vec_ilv_r2, vec_ilv_r3 );
            ILVL_B4_UB( src4, src0, src5, src1, src6, src2, src7, src3,
                        vec_ilv_l0, vec_ilv_l1, vec_ilv_l2, vec_ilv_l3 );
            ST_UB4( vec_ilv_r0, vec_ilv_r1, vec_ilv_r2, vec_ilv_r3,
                    p_dst, i_dst_stride );
            ST_UB4( vec_ilv_l0, vec_ilv_l1, vec_ilv_l2, vec_ilv_l3,
                    ( p_dst + 16 ), i_dst_stride );
            p_src0 += 16;
            p_src1 += 16;
            p_dst += 32;
        }

        for( i_loop_width = ( i_width % 16 ) >> 3; i_loop_width--; )
        {
            LD_UB4( p_src0, i_src0_stride, src0, src1, src2, src3 );
            LD_UB4( p_src1, i_src1_stride, src4, src5, src6, src7 );
            ILVR_B4_UB( src4, src0, src5, src1, src6, src2, src7, src3,
                        vec_ilv_r0, vec_ilv_r1, vec_ilv_r2, vec_ilv_r3 );
            ST_UB4( vec_ilv_r0, vec_ilv_r1, vec_ilv_r2, vec_ilv_r3,
                    p_dst, i_dst_stride );
            p_src0 += 8;
            p_src1 += 8;
            p_dst += 16;
        }

        for( i_loop_width = i_w_mul8; i_loop_width < i_width; i_loop_width++ )
        {
            p_dst[0] = p_src0[0];
            p_dst[1] = p_src1[0];
            p_dst[i_dst_stride] = p_src0[i_src0_stride];
            p_dst[i_dst_stride + 1] = p_src1[i_src1_stride];
            p_dst[2 * i_dst_stride] = p_src0[2 * i_src0_stride];
            p_dst[2 * i_dst_stride + 1] = p_src1[2 * i_src1_stride];
            p_dst[3 * i_dst_stride] = p_src0[3 * i_src0_stride];
            p_dst[3 * i_dst_stride + 1] = p_src1[3 * i_src1_stride];
            p_src0 += 1;
            p_src1 += 1;
            p_dst += 2;
        }

        p_src0 += ( ( 4 * i_src0_stride ) - i_width );
        p_src1 += ( ( 4 * i_src1_stride ) - i_width );
        p_dst += ( ( 4 * i_dst_stride ) - ( i_width * 2 ) );
    }

    for( i_loop_height = i_h4w; i_loop_height < i_height; i_loop_height++ )
    {
        for( i_loop_width = ( i_width >> 4 ); i_loop_width--; )
        {
            src0 = LD_UB( p_src0 );
            src4 = LD_UB( p_src1 );
            ILVRL_B2_UB( src4, src0, vec_ilv_r0, vec_ilv_l0 );
            ST_UB2( vec_ilv_r0, vec_ilv_l0, p_dst, 16 );
            p_src0 += 16;
            p_src1 += 16;
            p_dst += 32;
        }

        for( i_loop_width = ( i_width % 16 ) >> 3; i_loop_width--; )
        {
            src0 = LD_UB( p_src0 );
            src4 = LD_UB( p_src1 );
            vec_ilv_r0 = ( v16u8 ) __msa_ilvr_b( ( v16i8 ) src4,
                                                 ( v16i8 ) src0 );
            ST_UB( vec_ilv_r0, p_dst );
            p_src0 += 8;
            p_src1 += 8;
            p_dst += 16;
        }

        for( i_loop_width = i_w_mul8; i_loop_width < i_width; i_loop_width++ )
        {
            p_dst[0] = p_src0[0];
            p_dst[1] = p_src1[0];
            p_src0 += 1;
            p_src1 += 1;
            p_dst += 2;
        }

        p_src0 += ( i_src0_stride - i_width );
        p_src1 += ( i_src1_stride - i_width );
        p_dst += ( i_dst_stride - ( i_width * 2 ) );
    }
}

static void core_plane_copy_deinterleave_msa( uint8_t *p_src, int32_t i_src_stride,
                                              uint8_t *p_dst0, int32_t dst0_stride,
                                              uint8_t *p_dst1, int32_t dst1_stride,
                                              int32_t i_width, int32_t i_height )
{
    int32_t i_loop_width, i_loop_height, i_w_mul4, i_w_mul8, i_h4w;
    uint32_t u_res_w0, u_res_w1;
    v16u8 in0, in1, in2, in3, in4, in5, in6, in7;
    v16u8 vec_pckev0, vec_pckev1, vec_pckev2, vec_pckev3;
    v16u8 vec_pckod0, vec_pckod1, vec_pckod2, vec_pckod3;
    uint8_t *p_dst;

    i_w_mul8 = i_width - i_width % 8;
    i_w_mul4 = i_width - i_width % 4;
    i_h4w = i_height - i_height % 8;

    for( i_loop_height = ( i_h4w >> 3 ); i_loop_height--; )
    {
        for( i_loop_width = ( i_w_mul8 >> 3 ); i_loop_width--; )
        {
            LD_UB8( p_src, i_src_stride,
                    in0, in1, in2, in3, in4, in5, in6, in7 );
            p_src += 16;
            PCKEV_B4_UB( in1, in0, in3, in2, in5, in4, in7, in6,
                         vec_pckev0, vec_pckev1, vec_pckev2, vec_pckev3 );
            PCKOD_B4_UB( in1, in0, in3, in2, in5, in4, in7, in6,
                         vec_pckod0, vec_pckod1, vec_pckod2, vec_pckod3 );
            ST8x4_UB( vec_pckev0, vec_pckev1, p_dst0, dst0_stride );
            p_dst = p_dst0 + 4 * dst0_stride;
            ST8x4_UB( vec_pckev2, vec_pckev3, p_dst, dst0_stride );
            ST8x4_UB( vec_pckod0, vec_pckod1, p_dst1, dst1_stride );
            p_dst = p_dst1 + 4 * dst1_stride;
            ST8x4_UB( vec_pckod2, vec_pckod3, p_dst, dst1_stride );
            p_dst0 += 8;
            p_dst1 += 8;
        }

        for( i_loop_width = ( ( i_width % 8 ) >> 2 ); i_loop_width--; )
        {
            LD_UB8( p_src, i_src_stride,
                    in0, in1, in2, in3, in4, in5, in6, in7 );
            p_src += 8;
            PCKEV_B4_UB( in1, in0, in3, in2, in5, in4, in7, in6,
                         vec_pckev0, vec_pckev1, vec_pckev2, vec_pckev3 );
            PCKOD_B4_UB( in1, in0, in3, in2, in5, in4, in7, in6,
                         vec_pckod0, vec_pckod1, vec_pckod2, vec_pckod3 );
            ST4x4_UB( vec_pckev0, vec_pckev1, 0, 2, 0, 2, p_dst0, dst0_stride );
            p_dst = p_dst0 + 4 * dst0_stride;
            ST4x4_UB( vec_pckev2, vec_pckev3, 0, 2, 0, 2, p_dst, dst0_stride );
            ST4x4_UB( vec_pckod0, vec_pckod1, 0, 2, 0, 2, p_dst1, dst1_stride );
            p_dst = p_dst1 + 4 * dst1_stride;
            ST4x4_UB( vec_pckod2, vec_pckod3, 0, 2, 0, 2, p_dst, dst1_stride );
            p_dst0 += 4;
            p_dst1 += 4;
        }

        for( i_loop_width = i_w_mul4; i_loop_width < i_width; i_loop_width++ )
        {
            p_dst0[0] = p_src[0];
            p_dst1[0] = p_src[1];
            p_dst0[dst0_stride] = p_src[i_src_stride];
            p_dst1[dst1_stride] = p_src[i_src_stride + 1];
            p_dst0[2 * dst0_stride] = p_src[2 * i_src_stride];
            p_dst1[2 * dst1_stride] = p_src[2 * i_src_stride + 1];
            p_dst0[3 * dst0_stride] = p_src[3 * i_src_stride];
            p_dst1[3 * dst1_stride] = p_src[3 * i_src_stride + 1];
            p_dst0[4 * dst0_stride] = p_src[4 * i_src_stride];
            p_dst1[4 * dst1_stride] = p_src[4 * i_src_stride + 1];
            p_dst0[5 * dst0_stride] = p_src[5 * i_src_stride];
            p_dst1[5 * dst1_stride] = p_src[5 * i_src_stride + 1];
            p_dst0[6 * dst0_stride] = p_src[6 * i_src_stride];
            p_dst1[6 * dst1_stride] = p_src[6 * i_src_stride + 1];
            p_dst0[7 * dst0_stride] = p_src[7 * i_src_stride];
            p_dst1[7 * dst1_stride] = p_src[7 * i_src_stride + 1];
            p_dst0 += 1;
            p_dst1 += 1;
            p_src += 2;
        }

        p_src += ( ( 8 * i_src_stride ) - ( i_width << 1 ) );
        p_dst0 += ( ( 8 * dst0_stride ) - i_width );
        p_dst1 += ( ( 8 * dst1_stride ) - i_width );
    }

    for( i_loop_height = i_h4w; i_loop_height < i_height; i_loop_height++ )
    {
        for( i_loop_width = ( i_w_mul8 >> 3 ); i_loop_width--; )
        {
            in0 = LD_UB( p_src );
            p_src += 16;
            vec_pckev0 = ( v16u8 ) __msa_pckev_b( ( v16i8 ) in0,
                                                  ( v16i8 ) in0 );
            vec_pckod0 = ( v16u8 ) __msa_pckod_b( ( v16i8 ) in0,
                                                  ( v16i8 ) in0 );
            ST8x1_UB( vec_pckev0, p_dst0 );
            ST8x1_UB( vec_pckod0, p_dst1 );
            p_dst0 += 8;
            p_dst1 += 8;
        }

        for( i_loop_width = ( ( i_width % 8 ) >> 2 ); i_loop_width--; )
        {
            in0 = LD_UB( p_src );
            p_src += 8;
            vec_pckev0 = ( v16u8 ) __msa_pckev_b( ( v16i8 ) in0,
                                                  ( v16i8 ) in0 );
            vec_pckod0 = ( v16u8 ) __msa_pckod_b( ( v16i8 ) in0,
                                                  ( v16i8 ) in0 );
            u_res_w0 = __msa_copy_u_w( ( v4i32 ) vec_pckev0, 0 );
            SW( u_res_w0, p_dst0 );
            u_res_w1 = __msa_copy_u_w( ( v4i32 ) vec_pckod0, 0 );
            SW( u_res_w1, p_dst1 );
            p_dst0 += 4;
            p_dst1 += 4;
        }

        for( i_loop_width = i_w_mul4; i_loop_width < i_width; i_loop_width++ )
        {
            p_dst0[0] = p_src[0];
            p_dst1[0] = p_src[1];
            p_dst0 += 1;
            p_dst1 += 1;
            p_src += 2;
        }

        p_src += ( ( i_src_stride ) - ( i_width << 1 ) );
        p_dst0 += ( ( dst0_stride ) - i_width );
        p_dst1 += ( ( dst1_stride ) - i_width );
    }
}


static void core_plane_copy_deinterleave_rgb_msa( uint8_t *p_src,
                                                  int32_t i_src_stride,
                                                  uint8_t *p_dst0,
                                                  int32_t i_dst0_stride,
                                                  uint8_t *p_dst1,
                                                  int32_t i_dst1_stride,
                                                  uint8_t *p_dst2,
                                                  int32_t i_dst2_stride,
                                                  int32_t i_width,
                                                  int32_t i_height )
{
    uint8_t *p_src_orig = p_src;
    uint8_t *p_dst0_orig = p_dst0;
    uint8_t *p_dst1_orig = p_dst1;
    uint8_t *p_dst2_orig = p_dst2;
    int32_t i_loop_width, i_loop_height, i_w_mul8, i_h_mul4;
    v16i8 in0, in1, in2, in3, in4, in5, in6, in7;
    v16i8 temp0, temp1, temp2, temp3;
    v16i8 mask0 = { 0, 3, 6, 9, 12, 15, 18, 21, 0, 0, 0, 0, 0, 0, 0, 0 };
    v16i8 mask1 = { 1, 4, 7, 10, 13, 16, 19, 22, 0, 0, 0, 0, 0, 0, 0, 0 };
    v16i8 mask2 = { 2, 5, 8, 11, 14, 17, 20, 23, 0, 0, 0, 0, 0, 0, 0, 0 };

    i_w_mul8 = i_width - i_width % 8;
    i_h_mul4 = i_height - i_height % 4;

    for( i_loop_height = ( i_height >> 2 ); i_loop_height--; )
    {
        p_src = p_src_orig;
        p_dst0 = p_dst0_orig;
        p_dst1 = p_dst1_orig;
        p_dst2 = p_dst2_orig;

        for( i_loop_width = ( i_width >> 3 ); i_loop_width--; )
        {
            LD_SB4( p_src, i_src_stride, in0, in1, in2, in3 );
            LD_SB4( ( p_src + 16 ), i_src_stride, in4, in5, in6, in7 );

            VSHF_B2_SB( in0, in4, in1, in5, mask0, mask0, temp0, temp1 );
            VSHF_B2_SB( in2, in6, in3, in7, mask0, mask0, temp2, temp3 );
            ST8x1_UB( temp0, p_dst0 );
            ST8x1_UB( temp1, p_dst0 + i_dst0_stride );
            ST8x1_UB( temp2, p_dst0 + 2 * i_dst0_stride );
            ST8x1_UB( temp3, p_dst0 + 3 * i_dst0_stride );

            VSHF_B2_SB( in0, in4, in1, in5, mask1, mask1, temp0, temp1 );
            VSHF_B2_SB( in2, in6, in3, in7, mask1, mask1, temp2, temp3 );
            ST8x1_UB( temp0, p_dst1 );
            ST8x1_UB( temp1, p_dst1 + i_dst1_stride );
            ST8x1_UB( temp2, p_dst1 + 2 * i_dst1_stride );
            ST8x1_UB( temp3, p_dst1 + 3 * i_dst1_stride );

            VSHF_B2_SB( in0, in4, in1, in5, mask2, mask2, temp0, temp1 );
            VSHF_B2_SB( in2, in6, in3, in7, mask2, mask2, temp2, temp3 );
            ST8x1_UB( temp0, p_dst2 );
            ST8x1_UB( temp1, p_dst2 + i_dst2_stride );
            ST8x1_UB( temp2, p_dst2 + 2 * i_dst2_stride );
            ST8x1_UB( temp3, p_dst2 + 3 * i_dst2_stride );

            p_src += 8 * 3;
            p_dst0 += 8;
            p_dst1 += 8;
            p_dst2 += 8;
        }

        for( i_loop_width = i_w_mul8; i_loop_width < i_width; i_loop_width++ )
        {
            p_dst0_orig[i_loop_width] = p_src_orig[0 + 3 * i_loop_width];
            p_dst1_orig[i_loop_width] = p_src_orig[1 + 3 * i_loop_width];
            p_dst2_orig[i_loop_width] = p_src_orig[2 + 3 * i_loop_width];

            p_dst0_orig[i_loop_width + i_dst0_stride] =
                p_src_orig[0 + i_src_stride + 3 * i_loop_width];
            p_dst1_orig[i_loop_width + i_dst1_stride] =
                p_src_orig[1 + i_src_stride + 3 * i_loop_width];
            p_dst2_orig[i_loop_width + i_dst2_stride] =
                p_src_orig[2 + i_src_stride + 3 * i_loop_width];

            p_dst0_orig[i_loop_width + 2 * i_dst0_stride] =
                p_src_orig[0 + 2 * i_src_stride + 3 * i_loop_width];
            p_dst1_orig[i_loop_width + 2 * i_dst1_stride] =
                p_src_orig[1 + 2 * i_src_stride + 3 * i_loop_width];
            p_dst2_orig[i_loop_width + 2 * i_dst2_stride] =
                p_src_orig[2 + 2 * i_src_stride + 3 * i_loop_width];

            p_dst0_orig[i_loop_width + 3 * i_dst0_stride] =
                p_src_orig[0 + 3 * i_src_stride + 3 * i_loop_width];
            p_dst1_orig[i_loop_width + 3 * i_dst1_stride] =
                p_src_orig[1 + 3 * i_src_stride + 3 * i_loop_width];
            p_dst2_orig[i_loop_width + 3 * i_dst2_stride] =
                p_src_orig[2 + 3 * i_src_stride + 3 * i_loop_width];
        }

        p_src_orig += ( 4 * i_src_stride );
        p_dst0_orig += ( 4 * i_dst0_stride );
        p_dst1_orig += ( 4 * i_dst1_stride );
        p_dst2_orig += ( 4 * i_dst2_stride );
    }

    for( i_loop_height = i_h_mul4; i_loop_height < i_height; i_loop_height++ )
    {
        p_src = p_src_orig;
        p_dst0 = p_dst0_orig;
        p_dst1 = p_dst1_orig;
        p_dst2 = p_dst2_orig;

        for( i_loop_width = ( i_width >> 3 ); i_loop_width--; )
        {
            in0 = LD_SB( p_src );
            in4 = LD_SB( p_src + 16 );
            temp0 = __msa_vshf_b( mask0, in4, in0 );
            ST8x1_UB( temp0, p_dst0 );
            temp0 = __msa_vshf_b( mask1, in4, in0 );
            ST8x1_UB( temp0, p_dst1 );
            temp0 = __msa_vshf_b( mask2, in4, in0 );
            ST8x1_UB( temp0, p_dst2 );

            p_src += 8 * 3;
            p_dst0 += 8;
            p_dst1 += 8;
            p_dst2 += 8;
        }

        for( i_loop_width = i_w_mul8; i_loop_width < i_width; i_loop_width++ )
        {
            p_dst0_orig[i_loop_width] = p_src_orig[3 * i_loop_width];
            p_dst1_orig[i_loop_width] = p_src_orig[3 * i_loop_width + 1];
            p_dst2_orig[i_loop_width] = p_src_orig[3 * i_loop_width + 2];
        }

        p_src_orig += ( i_src_stride );
        p_dst0_orig += ( i_dst0_stride );
        p_dst1_orig += ( i_dst1_stride );
        p_dst2_orig += ( i_dst2_stride );
    }
}

static void core_plane_copy_deinterleave_rgba_msa( uint8_t *p_src,
                                                   int32_t i_src_stride,
                                                   uint8_t *p_dst0,
                                                   int32_t i_dst0_stride,
                                                   uint8_t *p_dst1,
                                                   int32_t i_dst1_stride,
                                                   uint8_t *p_dst2,
                                                   int32_t i_dst2_stride,
                                                   int32_t i_width,
                                                   int32_t i_height )
{
    uint8_t *p_src_orig = p_src;
    uint8_t *p_dst0_orig = p_dst0;
    uint8_t *p_dst1_orig = p_dst1;
    uint8_t *p_dst2_orig = p_dst2;
    int32_t i_loop_width, i_loop_height, i_w_mul8, i_h_mul4;
    v16i8 in0, in1, in2, in3, in4, in5, in6, in7;
    v16i8 in8, in9, in10, in11, in12, in13, in14, in15;
    v8i16 temp0, temp1, temp2, temp3, temp4, temp5, temp6, temp7;
    v8i16 temp8, temp9, temp10, temp11, temp12, temp13, temp14, temp15;

    i_w_mul8 = i_width - i_width % 8;
    i_h_mul4 = i_height - i_height % 4;

    for( i_loop_height = ( i_height >> 2 ); i_loop_height--; )
    {
        p_src = p_src_orig;
        p_dst0 = p_dst0_orig;
        p_dst1 = p_dst1_orig;
        p_dst2 = p_dst2_orig;

        for( i_loop_width = ( i_width >> 4 ); i_loop_width--; )
        {
            LD_SB4( p_src, i_src_stride, in0, in1, in2, in3 );
            LD_SB4( ( p_src + 16 ), i_src_stride, in4, in5, in6, in7 );
            LD_SB4( ( p_src + 32 ), i_src_stride, in8, in9, in10, in11 );
            LD_SB4( ( p_src + 48 ), i_src_stride, in12, in13, in14, in15 );

            PCKEV_H2_SH( in4, in0, in12, in8, temp0, temp1 );
            temp2 = __msa_pckod_h( ( v8i16 ) in4, ( v8i16 ) in0 );
            temp3 = __msa_pckod_h( ( v8i16 ) in12, ( v8i16 ) in8 );
            PCKEV_H2_SH( in5, in1, in13, in9, temp4, temp5 );
            temp6 = __msa_pckod_h( ( v8i16 ) in5, ( v8i16 ) in1 );
            temp7 = __msa_pckod_h( ( v8i16 ) in13, ( v8i16 ) in9 );
            PCKEV_H2_SH( in6, in2, in14, in10, temp8, temp9 );
            temp10 = __msa_pckod_h( ( v8i16 ) in6, ( v8i16 ) in2 );
            temp11 = __msa_pckod_h( ( v8i16 ) in14, ( v8i16 ) in10 );
            PCKEV_H2_SH( in7, in3, in15, in11, temp12, temp13 );
            temp14 = __msa_pckod_h( ( v8i16 ) in7, ( v8i16 ) in3 );
            temp15 = __msa_pckod_h( ( v8i16 ) in15, ( v8i16 ) in11 );
            PCKEV_B2_SB( temp1, temp0, temp3, temp2, in0, in1 );
            in2 = __msa_pckod_b( ( v16i8 ) temp1, ( v16i8 ) temp0 );
            PCKEV_B2_SB( temp5, temp4, temp7, temp6, in4, in5 );
            in6 = __msa_pckod_b( ( v16i8 ) temp5, ( v16i8 ) temp4 );
            PCKEV_B2_SB( temp9, temp8, temp11, temp10, in8, in9 );
            in10 = __msa_pckod_b( ( v16i8 ) temp9, ( v16i8 ) temp8 );
            PCKEV_B2_SB( temp13, temp12, temp15, temp14, in12, in13 );
            in14 = __msa_pckod_b( ( v16i8 ) temp13, ( v16i8 ) temp12 );
            ST_SB4( in0, in4, in8, in12, p_dst0, i_dst0_stride );
            ST_SB4( in1, in5, in9, in13, p_dst2, i_dst2_stride );
            ST_SB4( in2, in6, in10, in14, p_dst1, i_dst1_stride );

            p_src += 16 * 4;
            p_dst0 += 16;
            p_dst1 += 16;
            p_dst2 += 16;
        }

        for( i_loop_width = ( ( i_width % 16 ) >> 3 ); i_loop_width--; )
        {
            LD_SB4( p_src, i_src_stride, in0, in1, in2, in3 );
            LD_SB4( p_src + 16, i_src_stride, in4, in5, in6, in7 );

            PCKEV_H2_SH( in4, in0, in5, in1, temp0, temp4 );
            temp2 = __msa_pckod_h( ( v8i16 ) in4, ( v8i16 ) in0 );
            temp6 = __msa_pckod_h( ( v8i16 ) in5, ( v8i16 ) in1 );

            PCKEV_H2_SH( in6, in2, in7, in3, temp8, temp12 );
            temp10 = __msa_pckod_h( ( v8i16 ) in6, ( v8i16 ) in2 );
            temp14 = __msa_pckod_h( ( v8i16 ) in7, ( v8i16 ) in3 );

            PCKEV_B2_SB( temp0, temp0, temp2, temp2, in0, in1 );
            in2 = __msa_pckod_b( ( v16i8 ) temp0, ( v16i8 ) temp0 );
            PCKEV_B2_SB( temp4, temp4, temp6, temp6, in4, in5 );
            in6 = __msa_pckod_b( ( v16i8 ) temp4, ( v16i8 ) temp4 );
            PCKEV_B2_SB( temp8, temp8, temp10, temp10, in8, in9 );
            in10 = __msa_pckod_b( ( v16i8 ) temp8, ( v16i8 ) temp8 );
            PCKEV_B2_SB( temp12, temp12, temp14, temp14, in12, in13 );
            in14 = __msa_pckod_b( ( v16i8 ) temp12, ( v16i8 ) temp12 );

            ST8x1_UB( in0, p_dst0 );
            ST8x1_UB( in4, p_dst0 + i_dst0_stride );
            ST8x1_UB( in8, p_dst0 + 2 * i_dst0_stride );
            ST8x1_UB( in12, p_dst0 + 3 * i_dst0_stride );

            ST8x1_UB( in1, p_dst2 );
            ST8x1_UB( in5, p_dst2 + i_dst2_stride );
            ST8x1_UB( in9, p_dst2 + 2 * i_dst2_stride );
            ST8x1_UB( in13, p_dst2 + 3 * i_dst2_stride );

            ST8x1_UB( in2, p_dst1 );
            ST8x1_UB( in6, p_dst1 + i_dst1_stride );
            ST8x1_UB( in10, p_dst1 + 2 * i_dst1_stride );
            ST8x1_UB( in14, p_dst1 + 3 * i_dst1_stride );

            p_src += 8 * 4;
            p_dst0 += 8;
            p_dst1 += 8;
            p_dst2 += 8;
        }

        for( i_loop_width = i_w_mul8; i_loop_width < i_width; i_loop_width++ )
        {
            p_dst0_orig[i_loop_width] = p_src_orig[4 * i_loop_width];
            p_dst1_orig[i_loop_width] = p_src_orig[4 * i_loop_width + 1];
            p_dst2_orig[i_loop_width] = p_src_orig[4 * i_loop_width + 2];

            p_dst0_orig[i_dst0_stride + i_loop_width] =
                p_src_orig[i_src_stride + 4 * i_loop_width];
            p_dst1_orig[i_dst1_stride + i_loop_width] =
                p_src_orig[i_src_stride + 4 * i_loop_width + 1];
            p_dst2_orig[i_dst2_stride + i_loop_width] =
                p_src_orig[i_src_stride + 4 * i_loop_width + 2];

            p_dst0_orig[2 * i_dst0_stride + i_loop_width] =
                p_src_orig[2 * i_src_stride + 4 * i_loop_width];
            p_dst1_orig[2 * i_dst1_stride + i_loop_width] =
                p_src_orig[2 * i_src_stride + 4 * i_loop_width + 1];
            p_dst2_orig[2 * i_dst2_stride + i_loop_width] =
                p_src_orig[2 * i_src_stride + 4 * i_loop_width + 2];

            p_dst0_orig[3 * i_dst0_stride + i_loop_width] =
                p_src_orig[3 * i_src_stride + 4 * i_loop_width];
            p_dst1_orig[3 * i_dst1_stride + i_loop_width] =
                p_src_orig[3 * i_src_stride + 4 * i_loop_width + 1];
            p_dst2_orig[3 * i_dst2_stride + i_loop_width] =
                p_src_orig[3 * i_src_stride + 4 * i_loop_width + 2];
        }

        p_src_orig += ( 4 * i_src_stride );
        p_dst0_orig += ( 4 * i_dst0_stride );
        p_dst1_orig += ( 4 * i_dst1_stride );
        p_dst2_orig += ( 4 * i_dst2_stride );
    }

    for( i_loop_height = i_h_mul4; i_loop_height < i_height; i_loop_height++ )
    {
        p_src = p_src_orig;
        p_dst0 = p_dst0_orig;
        p_dst1 = p_dst1_orig;
        p_dst2 = p_dst2_orig;

        for( i_loop_width = ( i_width >> 4 ); i_loop_width--; )
        {
            LD_SB4( p_src, 16, in0, in4, in8, in12 );

            PCKEV_H2_SH( in4, in0, in12, in8, temp0, temp1 );
            temp2 = __msa_pckod_h( ( v8i16 ) in4, ( v8i16 ) in0 );
            temp3 = __msa_pckod_h( ( v8i16 ) in12, ( v8i16 ) in8 );
            PCKEV_B2_SB( temp1, temp0, temp3, temp2, in0, in1 );
            in2 = __msa_pckod_b( ( v16i8 ) temp1, ( v16i8 ) temp0 );
            ST_SB( in0, p_dst0 );
            ST_SB( in0, p_dst0 );
            ST_SB( in1, p_dst2 );
            ST_SB( in1, p_dst2 );
            ST_SB( in2, p_dst1 );
            ST_SB( in2, p_dst1 );

            p_src += 16 * 4;
            p_dst0 += 16;
            p_dst1 += 16;
            p_dst2 += 16;
        }

        for( i_loop_width = ( ( i_width % 16 ) >> 3 ); i_loop_width--; )
        {
            in0 = LD_SB( p_src );
            in4 = LD_SB( p_src + 16 );

            temp0 = __msa_pckev_h( ( v8i16 ) in4, ( v8i16 ) in0 );
            temp2 = __msa_pckod_h( ( v8i16 ) in4, ( v8i16 ) in0 );
            PCKEV_B2_SB( temp0, temp0, temp2, temp2, in0, in1 );
            in2 = __msa_pckod_b( ( v16i8 ) temp0, ( v16i8 ) temp0 );
            ST8x1_UB( in0, p_dst0 );
            ST8x1_UB( in1, p_dst2 );
            ST8x1_UB( in2, p_dst1 );

            p_src += 8 * 4;
            p_dst0 += 8;
            p_dst1 += 8;
            p_dst2 += 8;
        }

        for( i_loop_width = i_w_mul8; i_loop_width < i_width; i_loop_width++ )
        {
            p_dst0_orig[i_loop_width] = p_src_orig[4 * i_loop_width];
            p_dst1_orig[i_loop_width] = p_src_orig[4 * i_loop_width + 1];
            p_dst2_orig[i_loop_width] = p_src_orig[4 * i_loop_width + 2];
        }

        p_src_orig += ( i_src_stride );
        p_dst0_orig += ( i_dst0_stride );
        p_dst1_orig += ( i_dst1_stride );
        p_dst2_orig += ( i_dst2_stride );
    }
}

static void core_store_interleave_chroma_msa( uint8_t *p_src0, int32_t i_src0_stride,
                                              uint8_t *p_src1, int32_t i_src1_stride,
                                              uint8_t *p_dst, int32_t i_dst_stride,
                                              int32_t i_height )
{
    int32_t i_loop_height, i_h4w;
    v16u8 in0, in1, in2, in3, in4, in5, in6, in7;
    v16u8 ilvr_vec0, ilvr_vec1, ilvr_vec2, ilvr_vec3;

    i_h4w = i_height % 4;
    for( i_loop_height = ( i_height >> 2 ); i_loop_height--; )
    {
        LD_UB4( p_src0, i_src0_stride, in0, in1, in2, in3 );
        p_src0 += ( 4 * i_src0_stride );
        LD_UB4( p_src1, i_src1_stride, in4, in5, in6, in7 );
        p_src1 += ( 4 * i_src1_stride );
        ILVR_B4_UB( in4, in0, in5, in1, in6, in2, in7, in3,
                    ilvr_vec0, ilvr_vec1, ilvr_vec2, ilvr_vec3 );
        ST_UB4( ilvr_vec0, ilvr_vec1, ilvr_vec2, ilvr_vec3,
                p_dst, i_dst_stride );
        p_dst += ( 4 * i_dst_stride );
    }

    for( i_loop_height = i_h4w; i_loop_height--; )
    {
        in0 = LD_UB( p_src0 );
        p_src0 += ( i_src0_stride );
        in1 = LD_UB( p_src1 );
        p_src1 += ( i_src1_stride );
        ilvr_vec0 = ( v16u8 ) __msa_ilvr_b( ( v16i8 ) in1, ( v16i8 ) in0 );
        ST_UB( ilvr_vec0, p_dst );
        p_dst += ( i_dst_stride );
    }
}

static void core_frame_init_lowres_core_msa( uint8_t *p_src, int32_t i_src_stride,
                                             uint8_t *p_dst0, int32_t dst0_stride,
                                             uint8_t *p_dst1, int32_t dst1_stride,
                                             uint8_t *p_dst2, int32_t dst2_stride,
                                             uint8_t *p_dst3, int32_t dst3_stride,
                                             int32_t i_width, int32_t i_height )
{
    int32_t i_loop_width, i_loop_height, i_w16_mul;
    v16u8 src0, src1, src2, src3, src4, src5, src6, src7, src8;
    v16u8 sld1_vec0, sld1_vec1, sld1_vec2, sld1_vec3, sld1_vec4, sld1_vec5;
    v16u8 pckev_vec0, pckev_vec1, pckev_vec2;
    v16u8 pckod_vec0, pckod_vec1, pckod_vec2;
    v16u8 tmp0, tmp1, tmp2, tmp3;
    v16u8 res0, res1;

    i_w16_mul = i_width - i_width % 16;
    for( i_loop_height = i_height; i_loop_height--; )
    {
        LD_UB3( p_src, i_src_stride, src0, src1, src2 );
        p_src += 16;
        for( i_loop_width = 0; i_loop_width < ( i_w16_mul >> 4 ); i_loop_width++ )
        {
            LD_UB3( p_src, i_src_stride, src3, src4, src5 );
            p_src += 16;
            LD_UB3( p_src, i_src_stride, src6, src7, src8 );
            p_src += 16;
            PCKEV_B2_UB( src3, src0, src4, src1, pckev_vec0, pckev_vec1 );
            PCKOD_B2_UB( src3, src0, src4, src1, pckod_vec0, pckod_vec1 );
            pckev_vec2 = ( v16u8 ) __msa_pckev_b( ( v16i8 ) src5,
                                                  ( v16i8 ) src2 );
            pckod_vec2 = ( v16u8 ) __msa_pckod_b( ( v16i8 ) src5,
                                                  ( v16i8 ) src2 );
            AVER_UB4_UB( pckev_vec1, pckev_vec0, pckod_vec1, pckod_vec0,
                         pckev_vec2, pckev_vec1, pckod_vec2, pckod_vec1,
                         tmp0, tmp1, tmp2, tmp3 );
            AVER_UB2_UB( tmp1, tmp0, tmp3, tmp2, res0, res1 );
            ST_UB( res0, p_dst0 );
            ST_UB( res1, p_dst2 );

            SLDI_B2_UB( src3, src4, src0, src1, sld1_vec0, sld1_vec1, 1 );
            SLDI_B2_UB( src5, src6, src2, src3, sld1_vec2, sld1_vec3, 1 );
            SLDI_B2_UB( src7, src8, src4, src5, sld1_vec4, sld1_vec5, 1 );
            PCKOD_B2_UB( sld1_vec3, sld1_vec0, sld1_vec4, sld1_vec1,
                         pckev_vec0, pckev_vec1 )
            pckev_vec2 = ( v16u8 ) __msa_pckod_b( ( v16i8 ) sld1_vec5,
                                                  ( v16i8 ) sld1_vec2 );
            AVER_UB4_UB( pckev_vec1, pckev_vec0, pckod_vec1, pckod_vec0,
                         pckev_vec2, pckev_vec1, pckod_vec2, pckod_vec1,
                         tmp0, tmp1, tmp2, tmp3 );
            AVER_UB2_UB( tmp1, tmp0, tmp3, tmp2, res0, res1 );
            ST_UB( res0, p_dst1 );
            ST_UB( res1, p_dst3 );

            src0 = src6;
            src1 = src7;
            src2 = src8;
            p_dst0 += 16;
            p_dst1 += 16;
            p_dst2 += 16;
            p_dst3 += 16;
        }

        for( i_loop_width = i_w16_mul; i_loop_width < i_width;
             i_loop_width += 8 )
        {
            LD_UB3( p_src, i_src_stride, src3, src4, src5 );
            p_src += 16;
            PCKEV_B2_UB( src3, src0, src4, src1, pckev_vec0, pckev_vec1 );
            PCKOD_B2_UB( src3, src0, src4, src1, pckod_vec0, pckod_vec1 );
            pckev_vec2 = ( v16u8 ) __msa_pckev_b( ( v16i8 ) src5,
                                                  ( v16i8 ) src2 );
            pckod_vec2 = ( v16u8 ) __msa_pckod_b( ( v16i8 ) src5,
                                                  ( v16i8 ) src2 );
            AVER_UB4_UB( pckev_vec1, pckev_vec0, pckod_vec1, pckod_vec0,
                         pckev_vec2, pckev_vec1, pckod_vec2, pckod_vec1,
                         tmp0, tmp1, tmp2, tmp3 );
            AVER_UB2_UB( tmp1, tmp0, tmp3, tmp2, res0, res1 );
            ST8x1_UB( res0, p_dst0 );
            ST8x1_UB( res1, p_dst2 );

            SLDI_B2_UB( src3, src4, src0, src1, sld1_vec0, sld1_vec1, 1 );
            SLDI_B2_UB( src5, src3, src2, src3, sld1_vec2, sld1_vec3, 1 );
            SLDI_B2_UB( src4, src5, src4, src5, sld1_vec4, sld1_vec5, 1 );
            PCKOD_B2_UB( sld1_vec3, sld1_vec0, sld1_vec4, sld1_vec1,
                         pckev_vec0, pckev_vec1 )
            pckev_vec2 = ( v16u8 ) __msa_pckod_b( ( v16i8 ) sld1_vec5,
                                                  ( v16i8 ) sld1_vec2 );
            AVER_UB4_UB( pckev_vec1, pckev_vec0, pckod_vec1, pckod_vec0,
                         pckev_vec2, pckev_vec1, pckod_vec2, pckod_vec1,
                         tmp0, tmp1, tmp2, tmp3 );
            AVER_UB2_UB( tmp1, tmp0, tmp3, tmp2, res0, res1 );
            ST8x1_UB( res0, p_dst1 );
            ST8x1_UB( res1, p_dst3 );
            p_dst0 += 8;
            p_dst1 += 8;
            p_dst2 += 8;
            p_dst3 += 8;
        }

        p_src += ( i_src_stride * 2 - ( ( i_width * 2 ) + 16 ) );
        p_dst0 += ( dst0_stride - i_width );
        p_dst1 += ( dst1_stride - i_width );
        p_dst2 += ( dst2_stride - i_width );
        p_dst3 += ( dst3_stride - i_width );
    }
}

static void mc_copy_w16_msa( uint8_t *p_dst, intptr_t i_dst_stride,
                             uint8_t *p_src, intptr_t i_src_stride,
                             int32_t i_height )
{
    copy_width16_msa( p_src, i_src_stride, p_dst, i_dst_stride, i_height );
}

static void mc_copy_w8_msa( uint8_t *p_dst, intptr_t i_dst_stride, uint8_t *p_src,
                            intptr_t i_src_stride, int32_t i_height )
{
    copy_width8_msa( p_src, i_src_stride, p_dst, i_dst_stride, i_height );
}

static void mc_copy_w4_msa( uint8_t *p_dst, intptr_t i_dst_stride, uint8_t *p_src,
                            intptr_t i_src_stride, int32_t i_height )
{
    copy_width4_msa( p_src, i_src_stride, p_dst, i_dst_stride, i_height );
}

static void pixel_avg_16x16_msa( uint8_t *p_pix1, intptr_t pix1_stride,
                                 uint8_t *p_pix2, intptr_t pix2_stride,
                                 uint8_t *p_pix3, intptr_t pix3_stride,
                                 int32_t i_weight )
{
    if( 32 == i_weight )
    {
        avg_src_width16_msa( p_pix2, pix2_stride, p_pix3, pix3_stride,
                             p_pix1, pix1_stride, 16 );
    }
    else if( i_weight < 0 || i_weight > 63 )
    {
        avc_biwgt_opscale_16width_nw_msa( p_pix2, pix2_stride,
                                          p_pix3, pix3_stride,
                                          p_pix1, pix1_stride,
                                          16, 5, i_weight,
                                          ( 64 - i_weight ), 0 );
    }
    else
    {
        avc_biwgt_opscale_16width_msa( p_pix2, pix2_stride,
                                       p_pix3, pix3_stride,
                                       p_pix1, pix1_stride,
                                       16, 5, i_weight,
                                       ( 64 - i_weight ), 0 );
    }
}

static void pixel_avg_16x8_msa( uint8_t *p_pix1, intptr_t pix1_stride,
                                uint8_t *p_pix2, intptr_t pix2_stride,
                                uint8_t *p_pix3, intptr_t pix3_stride,
                                int32_t i_weight )
{
    if( 32 == i_weight )
    {
        avg_src_width16_msa( p_pix2, pix2_stride, p_pix3, pix3_stride,
                             p_pix1, pix1_stride, 8 );
    }
    else if( i_weight < 0 || i_weight > 63 )
    {
        avc_biwgt_opscale_16width_nw_msa( p_pix2, pix2_stride,
                                          p_pix3, pix3_stride,
                                          p_pix1, pix1_stride,
                                          8, 5, i_weight,
                                          ( 64 - i_weight ), 0 );
    }
    else
    {
        avc_biwgt_opscale_16width_msa( p_pix2, pix2_stride,
                                       p_pix3, pix3_stride,
                                       p_pix1, pix1_stride,
                                       8, 5, i_weight,
                                       ( 64 - i_weight ), 0 );
    }
}

static void pixel_avg_8x16_msa( uint8_t *p_pix1, intptr_t pix1_stride,
                                uint8_t *p_pix2, intptr_t pix2_stride,
                                uint8_t *p_pix3, intptr_t pix3_stride,
                                int32_t i_weight )
{
    if( 32 == i_weight )
    {
        avg_src_width8_msa( p_pix2, pix2_stride, p_pix3, pix3_stride,
                            p_pix1, pix1_stride, 16 );
    }
    else if( i_weight < 0 || i_weight > 63 )
    {
        avc_biwgt_opscale_8width_nw_msa( p_pix2, pix2_stride,
                                         p_pix3, pix3_stride,
                                         p_pix1, pix1_stride, 16, 5, i_weight,
                                         ( 64 - i_weight ), 0 );
    }
    else
    {
        avc_biwgt_opscale_8width_msa( p_pix2, pix2_stride,
                                      p_pix3, pix3_stride,
                                      p_pix1, pix1_stride, 16, 5, i_weight,
                                      ( 64 - i_weight ), 0 );
    }
}

static void pixel_avg_8x8_msa( uint8_t *p_pix1, intptr_t pix1_stride,
                               uint8_t *p_pix2, intptr_t pix2_stride,
                               uint8_t *p_pix3, intptr_t pix3_stride,
                               int32_t i_weight )
{
    if( 32 == i_weight )
    {
        avg_src_width8_msa( p_pix2, pix2_stride, p_pix3, pix3_stride,
                            p_pix1, pix1_stride, 8 );
    }
    else if( i_weight < 0 || i_weight > 63 )
    {
        avc_biwgt_opscale_8width_nw_msa( p_pix2, pix2_stride,
                                         p_pix3, pix3_stride,
                                         p_pix1, pix1_stride, 8, 5, i_weight,
                                         ( 64 - i_weight ), 0 );
    }
    else
    {
        avc_biwgt_opscale_8width_msa( p_pix2, pix2_stride,
                                      p_pix3, pix3_stride,
                                      p_pix1, pix1_stride, 8, 5, i_weight,
                                      ( 64 - i_weight ), 0 );
    }
}

static void pixel_avg_8x4_msa( uint8_t *p_pix1, intptr_t pix1_stride,
                               uint8_t *p_pix2, intptr_t pix2_stride,
                               uint8_t *p_pix3, intptr_t pix3_stride,
                               int32_t i_weight )
{
    if( 32 == i_weight )
    {
        avg_src_width8_msa( p_pix2, pix2_stride, p_pix3, pix3_stride,
                            p_pix1, pix1_stride, 4 );
    }
    else if( i_weight < 0 || i_weight > 63 )
    {
        avc_biwgt_opscale_8width_nw_msa( p_pix2, pix2_stride,
                                         p_pix3, pix3_stride,
                                         p_pix1, pix1_stride, 4, 5, i_weight,
                                         ( 64 - i_weight ), 0 );
    }
    else
    {
        avc_biwgt_opscale_8width_msa( p_pix2, pix2_stride,
                                      p_pix3, pix3_stride,
                                      p_pix1, pix1_stride, 4, 5, i_weight,
                                      ( 64 - i_weight ), 0 );
    }
}

static void pixel_avg_4x16_msa( uint8_t *p_pix1, intptr_t pix1_stride,
                                uint8_t *p_pix2, intptr_t pix2_stride,
                                uint8_t *p_pix3, intptr_t pix3_stride,
                                int32_t i_weight )
{
    if( 32 == i_weight )
    {
        avg_src_width4_msa( p_pix2, pix2_stride, p_pix3, pix3_stride,
                            p_pix1, pix1_stride, 16 );
    }
    else if( i_weight < 0 || i_weight > 63 )
    {
        avc_biwgt_opscale_4width_nw_msa( p_pix2, pix2_stride,
                                         p_pix3, pix3_stride,
                                         p_pix1, pix1_stride, 16, 5, i_weight,
                                         ( 64 - i_weight ), 0 );
    }
    else
    {
        avc_biwgt_opscale_4width_msa( p_pix2, pix2_stride,
                                      p_pix3, pix3_stride,
                                      p_pix1, pix1_stride, 16, 5, i_weight,
                                      ( 64 - i_weight ), 0 );
    }
}

static void pixel_avg_4x8_msa( uint8_t *p_pix1, intptr_t pix1_stride,
                               uint8_t *p_pix2, intptr_t pix2_stride,
                               uint8_t *p_pix3, intptr_t pix3_stride,
                               int32_t i_weight )
{
    if( 32 == i_weight )
    {
        avg_src_width4_msa( p_pix2, pix2_stride, p_pix3, pix3_stride,
                            p_pix1, pix1_stride, 8 );
    }
    else if( i_weight < 0 || i_weight > 63 )
    {
        avc_biwgt_opscale_4width_nw_msa( p_pix2, pix2_stride,
                                         p_pix3, pix3_stride,
                                         p_pix1, pix1_stride, 8, 5, i_weight,
                                         ( 64 - i_weight ), 0 );
    }
    else
    {
        avc_biwgt_opscale_4width_msa( p_pix2, pix2_stride,
                                      p_pix3, pix3_stride,
                                      p_pix1, pix1_stride, 8, 5, i_weight,
                                      ( 64 - i_weight ), 0 );
    }
}

static void pixel_avg_4x4_msa( uint8_t *p_pix1, intptr_t pix1_stride,
                               uint8_t *p_pix2, intptr_t pix2_stride,
                               uint8_t *p_pix3, intptr_t pix3_stride,
                               int32_t i_weight )
{
    if( 32 == i_weight )
    {
        avg_src_width4_msa( p_pix2, pix2_stride, p_pix3, pix3_stride,
                            p_pix1, pix1_stride, 4 );
    }
    else if( i_weight < 0 || i_weight > 63 )
    {
        avc_biwgt_opscale_4width_nw_msa( p_pix2, pix2_stride,
                                         p_pix3, pix3_stride,
                                         p_pix1, pix1_stride, 4, 5, i_weight,
                                         ( 64 - i_weight ), 0 );
    }
    else
    {
        avc_biwgt_opscale_4width_msa( p_pix2, pix2_stride,
                                      p_pix3, pix3_stride,
                                      p_pix1, pix1_stride, 4, 5, i_weight,
                                      ( 64 - i_weight ), 0 );
    }
}

static void pixel_avg_4x2_msa( uint8_t *p_pix1, intptr_t pix1_stride,
                               uint8_t *p_pix2, intptr_t pix2_stride,
                               uint8_t *p_pix3, intptr_t pix3_stride,
                               int32_t i_weight )
{
    if( 32 == i_weight )
    {
        avg_src_width4_msa( p_pix2, pix2_stride, p_pix3, pix3_stride,
                            p_pix1, pix1_stride, 2 );
    }
    else if( i_weight < 0 || i_weight > 63 )
    {
        avc_biwgt_opscale_4x2_nw_msa( p_pix2, pix2_stride,
                                      p_pix3, pix3_stride,
                                      p_pix1, pix1_stride, 5, i_weight,
                                      ( 64 - i_weight ), 0 );
    }
    else
    {
        avc_biwgt_opscale_4x2_msa( p_pix2, pix2_stride,
                                   p_pix3, pix3_stride,
                                   p_pix1, pix1_stride, 5, i_weight,
                                   ( 64 - i_weight ), 0 );
    }
}


static void memzero_aligned_msa( void *p_dst, size_t n )
{
    uint32_t u_tot32_mul_lines = n >> 5;
    uint32_t u_remaining = n - ( u_tot32_mul_lines << 5 );

    memset_zero_16width_msa( p_dst, 16, ( n / 16 ) );

    if( u_remaining )
    {
        memset( p_dst + ( u_tot32_mul_lines << 5 ), 0, u_remaining );
    }
}

static void mc_weight_w4_msa( uint8_t *p_dst, intptr_t i_dst_stride,
                              uint8_t *p_src, intptr_t i_src_stride,
                              const x264_weight_t *pWeight, int32_t i_height )
{
    int32_t i_log2_denom = pWeight->i_denom;
    int32_t i_offset = pWeight->i_offset;
    int32_t i_weight = pWeight->i_scale;

    avc_wgt_opscale_4width_msa( p_src, i_src_stride, p_dst, i_dst_stride,
                                i_height, i_log2_denom, i_weight, i_offset );
}

static void mc_weight_w8_msa( uint8_t *p_dst, intptr_t i_dst_stride,
                              uint8_t *p_src, intptr_t i_src_stride,
                              const x264_weight_t *pWeight, int32_t i_height )
{
    int32_t i_log2_denom = pWeight->i_denom;
    int32_t i_offset = pWeight->i_offset;
    int32_t i_weight = pWeight->i_scale;

    avc_wgt_opscale_8width_msa( p_src, i_src_stride, p_dst, i_dst_stride,
                                i_height, i_log2_denom, i_weight, i_offset );
}

static void mc_weight_w16_msa( uint8_t *p_dst, intptr_t i_dst_stride,
                               uint8_t *p_src, intptr_t i_src_stride,
                               const x264_weight_t *pWeight, int32_t i_height )
{
    int32_t i_log2_denom = pWeight->i_denom;
    int32_t i_offset = pWeight->i_offset;
    int32_t i_weight = pWeight->i_scale;

    avc_wgt_opscale_16width_msa( p_src, i_src_stride, p_dst, i_dst_stride,
                                 i_height, i_log2_denom, i_weight, i_offset );
}

static void mc_weight_w20_msa( uint8_t *p_dst, intptr_t i_dst_stride,
                               uint8_t *p_src, intptr_t i_src_stride,
                               const x264_weight_t *pWeight, int32_t i_height )
{
    mc_weight_w16_msa( p_dst, i_dst_stride, p_src, i_src_stride,
                       pWeight, i_height );
    mc_weight_w4_msa( p_dst + 16, i_dst_stride, p_src + 16, i_src_stride,
                      pWeight, i_height );
}

static void mc_luma_msa( uint8_t *p_dst, intptr_t i_dst_stride,
                         uint8_t *p_src[4], intptr_t i_src_stride,
                         int32_t m_vx, int32_t m_vy,
                         int32_t i_width, int32_t i_height,
                         const x264_weight_t *pWeight )
{
    int32_t  i_qpel_idx;
    int32_t  i_offset;
    uint8_t  *p_src1;

    i_qpel_idx = ( ( m_vy & 3 ) << 2 ) + ( m_vx & 3 );
    i_offset = ( m_vy >> 2 ) * i_src_stride + ( m_vx >> 2 );
    p_src1 = p_src[x264_hpel_ref0[i_qpel_idx]] + i_offset +
             ( 3 == ( m_vy & 3 ) ) * i_src_stride;

    if( i_qpel_idx & 5 )
    {
        uint8_t *p_src2 = p_src[x264_hpel_ref1[i_qpel_idx]] +
                          i_offset + ( 3 == ( m_vx&3 ) );

        if( 16 == i_width )
        {
            avg_src_width16_msa( p_src1, i_src_stride, p_src2, i_src_stride,
                                 p_dst, i_dst_stride, i_height );
        }
        else if( 8 == i_width )
        {
            avg_src_width8_msa( p_src1, i_src_stride, p_src2, i_src_stride,
                                p_dst, i_dst_stride, i_height );
        }
        else if( 4 == i_width )
        {
            avg_src_width4_msa( p_src1, i_src_stride, p_src2, i_src_stride,
                                p_dst, i_dst_stride, i_height );
        }

        if( pWeight->weightfn )
        {
            if( 16 == i_width )
            {
                mc_weight_w16_msa( p_dst, i_dst_stride,
                                   p_dst, i_dst_stride,
                                   pWeight, i_height );
            }
            else if( 8 == i_width )
            {
                mc_weight_w8_msa( p_dst, i_dst_stride, p_dst, i_dst_stride,
                                  pWeight, i_height );
            }
            else if( 4 == i_width )
            {
                mc_weight_w4_msa( p_dst, i_dst_stride, p_dst, i_dst_stride,
                                  pWeight, i_height );
            }
        }
    }
    else if( pWeight->weightfn )
    {
        if( 16 == i_width )
        {
            mc_weight_w16_msa( p_dst, i_dst_stride, p_src1, i_src_stride,
                               pWeight, i_height );
        }
        else if( 8 == i_width )
        {
            mc_weight_w8_msa( p_dst, i_dst_stride, p_src1, i_src_stride,
                              pWeight, i_height );
        }
        else if( 4 == i_width )
        {
            mc_weight_w4_msa( p_dst, i_dst_stride, p_src1, i_src_stride,
                              pWeight, i_height );
        }
    }
    else
    {
        if( 16 == i_width )
        {
            copy_width16_msa( p_src1, i_src_stride, p_dst, i_dst_stride,
                              i_height );
        }
        else if( 8 == i_width )
        {
            copy_width8_msa( p_src1, i_src_stride, p_dst, i_dst_stride,
                             i_height );
        }
        else if( 4 == i_width )
        {
            copy_width4_msa( p_src1, i_src_stride, p_dst, i_dst_stride,
                             i_height );
        }
    }
}

static void mc_chroma_msa( uint8_t *p_dst_u, uint8_t *p_dst_v,
                           intptr_t i_dst_stride,
                           uint8_t *p_src, intptr_t i_src_stride,
                           int32_t m_vx, int32_t m_vy,
                           int32_t i_width, int32_t i_height )
{
    int32_t i_d8x = m_vx & 0x07;
    int32_t i_d8y = m_vy & 0x07;
    int32_t i_coeff_horiz1 = ( 8 - i_d8x );
    int32_t i_coeff_vert1 = ( 8 - i_d8y );
    int32_t i_coeff_horiz0 = i_d8x;
    int32_t i_coeff_vert0 = i_d8y;

    p_src += ( m_vy >> 3 ) * i_src_stride + ( m_vx >> 3 ) * 2;

    if( 2 == i_width )
    {
        avc_interleaved_chroma_hv_2w_msa( p_src, i_src_stride,
                                          p_dst_u, p_dst_v, i_dst_stride,
                                          i_coeff_horiz0, i_coeff_horiz1,
                                          i_coeff_vert0, i_coeff_vert1,
                                          i_height );
    }
    else if( 4 == i_width )
    {
        avc_interleaved_chroma_hv_4w_msa( p_src, i_src_stride,
                                          p_dst_u, p_dst_v, i_dst_stride,
                                          i_coeff_horiz0, i_coeff_horiz1,
                                          i_coeff_vert0, i_coeff_vert1,
                                          i_height );
    }
    else if( 8 == i_width )
    {
        avc_interleaved_chroma_hv_8w_msa( p_src, i_src_stride,
                                          p_dst_u, p_dst_v, i_dst_stride,
                                          i_coeff_horiz0, i_coeff_horiz1,
                                          i_coeff_vert0, i_coeff_vert1,
                                          i_height );
    }
}

static void hpel_filter_msa( uint8_t *p_dsth, uint8_t *p_dst_v,
                             uint8_t *p_dstc, uint8_t *p_src,
                             intptr_t i_stride, int32_t i_width,
                             int32_t i_height, int16_t *p_buf )
{
    for( int32_t i = 0; i < ( i_width / 16 ); i++ )
    {
        avc_luma_vt_16w_msa( p_src - 2 - ( 2 * i_stride ), i_stride,
                             p_dst_v - 2, i_stride, i_height );
        avc_luma_mid_16w_msa( p_src - 2 - ( 2 * i_stride ) , i_stride,
                              p_dstc, i_stride, i_height );
        avc_luma_hz_16w_msa( p_src - 2, i_stride, p_dsth, i_stride, i_height );

        p_src += 16;
        p_dst_v += 16;
        p_dsth += 16;
        p_dstc += 16;
    }
}

static void plane_copy_interleave_msa( uint8_t *p_dst, intptr_t i_dst_stride,
                                       uint8_t *p_src0, intptr_t i_src_stride0,
                                       uint8_t *p_src1, intptr_t i_src_stride1,
                                       int32_t i_width, int32_t i_height )
{
    core_plane_copy_interleave_msa( p_src0, i_src_stride0, p_src1, i_src_stride1,
                                    p_dst, i_dst_stride, i_width, i_height );
}

static void plane_copy_deinterleave_msa( uint8_t *p_dst0, intptr_t i_dst_stride0,
                                         uint8_t *p_dst1, intptr_t i_dst_stride1,
                                         uint8_t *p_src, intptr_t i_src_stride,
                                         int32_t i_width, int32_t i_height )
{
    core_plane_copy_deinterleave_msa( p_src, i_src_stride, p_dst0, i_dst_stride0,
                                      p_dst1, i_dst_stride1, i_width, i_height );
}

static void plane_copy_deinterleave_rgb_msa( uint8_t *p_dst0,
                                             intptr_t i_dst_stride0,
                                             uint8_t *p_dst1,
                                             intptr_t i_dst_stride1,
                                             uint8_t *p_dst2,
                                             intptr_t i_dst_stride2,
                                             uint8_t *p_src,
                                             intptr_t i_src_stride,
                                             int32_t i_src_width,
                                             int32_t i_width,
                                             int32_t i_height )
{
    if( 3 == i_src_width )
    {
        core_plane_copy_deinterleave_rgb_msa( p_src, i_src_stride,
                                              p_dst0, i_dst_stride0,
                                              p_dst1, i_dst_stride1,
                                              p_dst2, i_dst_stride2,
                                              i_width, i_height );
    }
    else if( 4 == i_src_width )
    {
        core_plane_copy_deinterleave_rgba_msa( p_src, i_src_stride,
                                               p_dst0, i_dst_stride0,
                                               p_dst1, i_dst_stride1,
                                               p_dst2, i_dst_stride2,
                                               i_width, i_height );
    }
}

static void store_interleave_chroma_msa( uint8_t *p_dst, intptr_t i_dst_stride,
                                         uint8_t *p_src0, uint8_t *p_src1,
                                         int32_t i_height )
{
    core_store_interleave_chroma_msa( p_src0, FDEC_STRIDE, p_src1, FDEC_STRIDE,
                                      p_dst, i_dst_stride, i_height );
}

static void load_deinterleave_chroma_fenc_msa( uint8_t *p_dst, uint8_t *p_src,
                                               intptr_t i_src_stride,
                                               int32_t i_height )
{
    core_plane_copy_deinterleave_msa( p_src, i_src_stride, p_dst, FENC_STRIDE,
                                     ( p_dst + ( FENC_STRIDE / 2 ) ), FENC_STRIDE,
                                     8, i_height );
}

static void load_deinterleave_chroma_fdec_msa( uint8_t *p_dst, uint8_t *p_src,
                                               intptr_t i_src_stride,
                                               int32_t i_height )
{
    core_plane_copy_deinterleave_msa( p_src, i_src_stride, p_dst, FDEC_STRIDE,
                                      ( p_dst + ( FDEC_STRIDE / 2 ) ), FDEC_STRIDE,
                                      8, i_height );
}

static void frame_init_lowres_core_msa( uint8_t *p_src, uint8_t *p_dst0,
                                        uint8_t *p_dst1, uint8_t *p_dst2,
                                        uint8_t *p_dst3, intptr_t i_src_stride,
                                        intptr_t i_dst_stride, int32_t i_width,
                                        int32_t i_height )
{
    core_frame_init_lowres_core_msa( p_src, i_src_stride, p_dst0, i_dst_stride,
                                     p_dst1, i_dst_stride, p_dst2, i_dst_stride,
                                     p_dst3, i_dst_stride, i_width, i_height );
}

static uint8_t *get_ref_msa( uint8_t *p_dst, intptr_t *p_dst_stride,
                             uint8_t *p_src[4], intptr_t i_src_stride,
                             int32_t m_vx, int32_t m_vy,
                             int32_t i_width, int32_t i_height,
                             const x264_weight_t *pWeight )
{
    int32_t i_qpel_idx, i_cnt, i_h4w;
    int32_t i_offset;
    uint8_t *p_src1, *src1_org;

    i_qpel_idx = ( ( m_vy & 3 ) << 2 ) + ( m_vx & 3 );
    i_offset = ( m_vy >> 2 ) * i_src_stride + ( m_vx >> 2 );
    p_src1 = p_src[x264_hpel_ref0[i_qpel_idx]] + i_offset +
           ( 3 == ( m_vy & 3 ) ) * i_src_stride;

    i_h4w = i_height - i_height%4;

    if( i_qpel_idx & 5 )
    {
        uint8_t *p_src2 = p_src[x264_hpel_ref1[i_qpel_idx]] +
                          i_offset + ( 3 == ( m_vx & 3 ) );

        if( 16 == i_width )
        {
            avg_src_width16_msa( p_src1, i_src_stride,
                                 p_src2, i_src_stride,
                                 p_dst, *p_dst_stride, i_h4w );
            for( i_cnt = i_h4w; i_cnt < i_height; i_cnt++ )
            {
                v16u8 src_vec1, src_vec2;
                v16u8 dst_vec0;

                src_vec1 = LD_UB( p_src1 + i_cnt * i_src_stride );
                src_vec2 = LD_UB( p_src2 + i_cnt * i_src_stride );

                dst_vec0 = __msa_aver_u_b( src_vec1, src_vec2 );

                ST_UB( dst_vec0, p_dst + i_cnt * ( *p_dst_stride ) );
            }
        }
        else if( 20 == i_width )
        {
            avg_src_width16_msa( p_src1, i_src_stride, p_src2, i_src_stride,
                                 p_dst, *p_dst_stride, i_h4w );
            avg_src_width4_msa( p_src1 + 16, i_src_stride,
                                p_src2 + 16, i_src_stride,
                                p_dst + 16, *p_dst_stride, i_h4w );

            for( i_cnt = i_h4w; i_cnt < i_height; i_cnt++ )
            {
                v16u8 src_vec1, src_vec2, src_vec3, src_vec4;
                v16u8 dst_vec0, dst_vec1;
                uint32_t temp0;

                src_vec1 = LD_UB( p_src1 + i_cnt * i_src_stride );
                src_vec2 = LD_UB( p_src2 + i_cnt * i_src_stride );
                src_vec3 = LD_UB( p_src1 + i_cnt * i_src_stride + 16 );
                src_vec4 = LD_UB( p_src2 + i_cnt * i_src_stride + 16 );

                dst_vec0 = __msa_aver_u_b( src_vec1, src_vec2 );
                dst_vec1 = __msa_aver_u_b( src_vec3, src_vec4 );

                temp0 = __msa_copy_u_w( ( v4i32 ) dst_vec1, 0 );

                ST_UB( dst_vec0, p_dst + i_cnt * ( *p_dst_stride ) );
                SW( temp0, p_dst + i_cnt * ( *p_dst_stride ) + 16 );
            }
        }
        else if( 12 == i_width )
        {
            avg_src_width8_msa( p_src1, i_src_stride,
                                p_src2, i_src_stride,
                                p_dst, *p_dst_stride, i_h4w );
            avg_src_width4_msa( p_src1 + 8, i_src_stride,
                                p_src2 + 8, i_src_stride,
                                p_dst + 8, *p_dst_stride, i_h4w );
            for( i_cnt = i_h4w; i_cnt < i_height; i_cnt++ )
            {
                uint32_t temp0;
                uint64_t dst0;
                v16u8 src_vec1, src_vec2;
                v16u8 dst_vec0;

                src_vec1 = LD_UB( p_src1 + i_cnt * i_src_stride );
                src_vec2 = LD_UB( p_src2 + i_cnt * i_src_stride );

                dst_vec0 = __msa_aver_u_b( src_vec1, src_vec2 );

                dst0 = __msa_copy_u_d( ( v2i64 ) dst_vec0, 0 );
                temp0 = __msa_copy_u_w( ( v4i32 ) dst_vec0, 2 );

                SD( dst0, p_dst + i_cnt * ( *p_dst_stride ) );
                SW( temp0, p_dst + i_cnt * ( *p_dst_stride ) + 8 );
            }
        }
        else if( 8 == i_width )
        {
            avg_src_width8_msa( p_src1, i_src_stride,
                                p_src2, i_src_stride,
                                p_dst, *p_dst_stride, i_h4w );
            for( i_cnt = i_h4w; i_cnt < i_height; i_cnt++ )
            {
                uint64_t dst0;
                v16u8 src_vec1, src_vec2;
                v16u8 dst_vec0;

                src_vec1 = LD_UB( p_src1 + i_cnt * i_src_stride );
                src_vec2 = LD_UB( p_src2 + i_cnt * i_src_stride );

                dst_vec0 = __msa_aver_u_b( src_vec1, src_vec2 );

                dst0 = __msa_copy_u_d( ( v2i64 ) dst_vec0, 0 );

                SD( dst0, p_dst + i_cnt * ( *p_dst_stride ) );
            }
        }
        else if( 4 == i_width )
        {
            avg_src_width4_msa( p_src1, i_src_stride,
                                p_src2, i_src_stride,
                                p_dst, *p_dst_stride, i_h4w );
            for( i_cnt = i_h4w; i_cnt < i_height; i_cnt++ )
            {
                uint32_t temp0;
                v16u8 src_vec1, src_vec2;
                v16u8 dst_vec0;

                src_vec1 = LD_UB( p_src1 + i_cnt * i_src_stride );
                src_vec2 = LD_UB( p_src2 + i_cnt * i_src_stride );

                dst_vec0 = __msa_aver_u_b( src_vec1, src_vec2 );
                temp0 = __msa_copy_u_w( ( v4i32 ) dst_vec0, 0 );

                SW( temp0, p_dst + i_cnt * ( *p_dst_stride ) );
            }
        }

        if( pWeight->weightfn )
        {
            int32_t i_log2_denom;
            int32_t i_offset_val;
            int32_t i_weight;

            i_log2_denom = pWeight->i_denom;
            i_offset_val = pWeight->i_offset;
            i_weight = pWeight->i_scale;

            if( 16 == i_width || 12 == i_width )
            {
                mc_weight_w16_msa( p_dst, *p_dst_stride,
                                   p_dst, *p_dst_stride,
                                   pWeight, i_h4w );
                for( i_cnt = i_h4w; i_cnt < i_height; i_cnt++ )
                {
                    v16i8 zero = {0};
                    v16u8 src_vec0;
                    v16i8 tmp0;
                    v8u16 temp_vec0, temp_vec1;
                    v8u16 wgt, offset_val0;
                    v8i16 denom;

                    i_offset_val <<= ( i_log2_denom );

                    if( i_log2_denom )
                    {
                        i_offset_val += ( 1 << ( i_log2_denom - 1 ) );
                    }

                    wgt = ( v8u16 ) __msa_fill_h( i_weight );
                    offset_val0 = ( v8u16 ) __msa_fill_h( i_offset_val );
                    denom = __msa_fill_h( i_log2_denom );

                    src_vec0 = LD_UB( p_dst + i_cnt * ( *p_dst_stride ) );

                    temp_vec1 = ( v8u16 ) __msa_ilvl_b( zero,
                                                        ( v16i8 ) src_vec0 );
                    temp_vec0 = ( v8u16 ) __msa_ilvr_b( zero,
                                                        ( v16i8 ) src_vec0 );

                    temp_vec0 = wgt * temp_vec0;
                    temp_vec1 = wgt * temp_vec1;

                    temp_vec0 =
                        ( v8u16 ) __msa_adds_s_h( ( v8i16 ) temp_vec0,
                                                  ( v8i16 ) offset_val0 );
                    temp_vec1 =
                        ( v8u16 ) __msa_adds_s_h( ( v8i16 ) temp_vec1,
                                                  ( v8i16 ) offset_val0 );

                    temp_vec0 =
                        ( v8u16 ) __msa_maxi_s_h( ( v8i16 ) temp_vec0, 0 );
                    temp_vec1 =
                        ( v8u16 ) __msa_maxi_s_h( ( v8i16 ) temp_vec1, 0 );

                    temp_vec0 =
                        ( v8u16 ) __msa_srl_h( ( v8i16 ) temp_vec0, denom );
                    temp_vec1 =
                        ( v8u16 ) __msa_srl_h( ( v8i16 ) temp_vec1, denom );

                    temp_vec0 = __msa_sat_u_h( temp_vec0, 7 );
                    temp_vec1 = __msa_sat_u_h( temp_vec1, 7 );

                    tmp0 = __msa_pckev_b( ( v16i8 ) temp_vec1,
                                          ( v16i8 ) temp_vec0 );
                    ST_SB( tmp0, p_dst + i_cnt * ( *p_dst_stride ) );
                }
            }
            else if( 20 == i_width )
            {
                mc_weight_w20_msa( p_dst, *p_dst_stride,
                                   p_dst, *p_dst_stride,
                                   pWeight, i_h4w );
                for( i_cnt = i_h4w; i_cnt < i_height; i_cnt++ )
                {
                    uint32_t temp0;
                    v16i8 zero = {0};
                    v16u8 src_vec0;
                    v16i8 tmp0;
                    v8u16 temp_vec0, temp_vec1;
                    v8u16 wgt;
                    v8i16 denom, offset_val0;

                    i_offset_val <<= ( i_log2_denom );

                    if( i_log2_denom )
                    {
                        i_offset_val += ( 1 << ( i_log2_denom - 1 ) );
                    }

                    wgt = ( v8u16 ) __msa_fill_h( i_weight );
                    offset_val0 = __msa_fill_h( i_offset_val );
                    denom = __msa_fill_h( i_log2_denom );

                    src_vec0 = LD_UB( p_dst + i_cnt * ( *p_dst_stride ) );
                    temp0 = LW( p_dst + i_cnt * ( *p_dst_stride ) + 16 );

                    temp_vec1 = ( v8u16 ) __msa_ilvl_b( zero,
                                                        ( v16i8 ) src_vec0 );
                    temp_vec0 = ( v8u16 ) __msa_ilvr_b( zero,
                                                        ( v16i8 ) src_vec0 );

                    temp_vec0 = wgt * temp_vec0;
                    temp_vec1 = wgt * temp_vec1;

                    temp_vec0 = ( v8u16 ) __msa_adds_s_h( ( v8i16 ) temp_vec0,
                                                          offset_val0 );
                    temp_vec1 = ( v8u16 ) __msa_adds_s_h( ( v8i16 ) temp_vec1,
                                                          offset_val0 );

                    temp_vec0 =
                        ( v8u16 ) __msa_maxi_s_h( ( v8i16 ) temp_vec0, 0 );
                    temp_vec1 =
                        ( v8u16 ) __msa_maxi_s_h( ( v8i16 ) temp_vec1, 0 );

                    temp_vec0 =
                        ( v8u16 ) __msa_srl_h( ( v8i16 ) temp_vec0, denom );
                    temp_vec1 =
                        ( v8u16 ) __msa_srl_h( ( v8i16 ) temp_vec1, denom );

                    temp_vec0 = __msa_sat_u_h( temp_vec0, 7 );
                    temp_vec1 = __msa_sat_u_h( temp_vec1, 7 );

                    tmp0 = __msa_pckev_b( ( v16i8 ) temp_vec1,
                                          ( v16i8 ) temp_vec0 );
                    ST_SB( tmp0, p_dst + i_cnt * ( *p_dst_stride ) );

                    src_vec0 = ( v16u8 ) __msa_fill_w( temp0 );
                    temp_vec0 = ( v8u16 ) __msa_ilvr_b( zero,
                                                        ( v16i8 ) src_vec0 );
                    temp_vec0 = wgt * temp_vec0;

                    temp_vec0 = ( v8u16 ) __msa_adds_s_h( ( v8i16 ) temp_vec0,
                                                          offset_val0 );
                    temp_vec0 =
                        ( v8u16 ) __msa_maxi_s_h( ( v8i16 ) temp_vec0, 0 );
                    temp_vec0 = ( v8u16 ) __msa_srl_h( ( v8i16 ) temp_vec0,
                                                       denom );
                    temp_vec0 = __msa_sat_u_h( temp_vec0, 7 );

                    tmp0 = __msa_pckev_b( ( v16i8 ) temp_vec0,
                                          ( v16i8 ) temp_vec0 );
                    temp0 = __msa_copy_u_w( ( v4i32 ) tmp0, 0 );
                    SW( temp0, p_dst + i_cnt * ( *p_dst_stride ) + 16 );
                }
            }
            else if( 8 == i_width )
            {
                mc_weight_w8_msa( p_dst, *p_dst_stride,
                                  p_dst, *p_dst_stride,
                                  pWeight, i_h4w );
                for( i_cnt = i_h4w; i_cnt < i_height; i_cnt++ )
                {
                    uint64_t temp0;
                    v16i8 zero = {0};
                    v16u8 src_vec0;
                    v16i8 tmp0;
                    v8u16 temp_vec0;
                    v8u16 wgt;
                    v8i16 denom, offset_val0;

                    i_offset_val = i_offset_val << i_log2_denom;

                    if( i_log2_denom )
                    {
                        i_offset_val += ( 1 << ( i_log2_denom - 1 ) );
                    }

                    wgt = ( v8u16 ) __msa_fill_h( i_weight );
                    offset_val0 = __msa_fill_h( i_offset_val );
                    denom = __msa_fill_h( i_log2_denom );

                    src_vec0 = LD_UB( p_dst + i_cnt * ( *p_dst_stride ) );

                    temp_vec0 = ( v8u16 ) __msa_ilvr_b( zero,
                                                        ( v16i8 ) src_vec0 );
                    temp_vec0 = wgt * temp_vec0;

                    temp_vec0 = ( v8u16 ) __msa_adds_s_h( ( v8i16 ) temp_vec0,
                                                          offset_val0 );
                    temp_vec0 =
                        ( v8u16 ) __msa_maxi_s_h( ( v8i16 ) temp_vec0, 0 );
                    temp_vec0 =
                        ( v8u16 ) __msa_srl_h( ( v8i16 ) temp_vec0, denom );
                    temp_vec0 = __msa_sat_u_h( temp_vec0, 7 );

                    tmp0 = __msa_pckev_b( ( v16i8 ) temp_vec0,
                                          ( v16i8 ) temp_vec0 );
                    temp0 = __msa_copy_u_d( ( v2i64 ) tmp0, 0 );
                    SD( temp0, p_dst + i_cnt * ( *p_dst_stride ) );
                }
            }
            else if( 4 == i_width )
            {
                mc_weight_w4_msa( p_dst, *p_dst_stride,
                                  p_dst, *p_dst_stride,
                                  pWeight, i_h4w );
                for( i_cnt = i_h4w; i_cnt < i_height; i_cnt++ )
                {
                    uint32_t temp0;
                    v16i8 zero = {0};
                    v16u8 src_vec0;
                    v16i8 tmp0;
                    v8u16 temp_vec0;
                    v8u16 wgt;
                    v8i16 denom, offset_val0;

                    i_offset_val <<= ( i_log2_denom );

                    if( i_log2_denom )
                    {
                        i_offset_val += ( 1 << ( i_log2_denom - 1 ) );
                    }

                    wgt = ( v8u16 ) __msa_fill_h( i_weight );
                    offset_val0 = __msa_fill_h( i_offset_val );
                    denom = __msa_fill_h( i_log2_denom );

                    temp0 = LW( p_dst + i_cnt * ( *p_dst_stride ) );

                    src_vec0 = ( v16u8 ) __msa_fill_w( temp0 );

                    temp_vec0 = ( v8u16 ) __msa_ilvr_b( zero,
                                                        ( v16i8 ) src_vec0 );
                    temp_vec0 = wgt * temp_vec0;

                    temp_vec0 = ( v8u16 ) __msa_adds_s_h( ( v8i16 ) temp_vec0,
                                                          offset_val0 );
                    temp_vec0 =
                        ( v8u16 ) __msa_maxi_s_h( ( v8i16 ) temp_vec0, 0 );
                    temp_vec0 = ( v8u16 ) __msa_srl_h( ( v8i16 ) temp_vec0,
                                                       denom );
                    temp_vec0 = __msa_sat_u_h( temp_vec0, 7 );

                    tmp0 = __msa_pckev_b( ( v16i8 ) temp_vec0,
                                          ( v16i8 ) temp_vec0 );
                    temp0 = __msa_copy_u_w( ( v4i32 ) tmp0, 0 );
                    SW( temp0, p_dst + i_cnt * ( *p_dst_stride ) );
                }
            }
        }

        return p_dst;
    }
    else if( pWeight->weightfn )
    {
        int32_t i_offset_val, i_log2_denom, i_weight;

        i_log2_denom = pWeight->i_denom;
        i_offset_val = pWeight->i_offset;
        i_weight = pWeight->i_scale;

        i_h4w = i_height - i_height%4;

        src1_org = p_src1;

        if( 16 == i_width || 12 == i_width )
        {
            mc_weight_w16_msa( p_dst, *p_dst_stride, p_src1, i_src_stride,
                               pWeight, i_h4w );
            p_src1 = src1_org + i_h4w * i_src_stride;

            for( i_cnt = i_h4w; i_cnt < i_height; i_cnt++ )
            {
                v16i8 zero = {0};
                v16u8 src_vec0;
                v16i8 tmp0;
                v8u16 temp_vec0, temp_vec1;
                v8u16 wgt;
                v8i16 denom, offset_val0;

                i_offset_val <<= ( i_log2_denom );

                if( i_log2_denom )
                {
                    i_offset_val += ( 1 << ( i_log2_denom - 1 ) );
                }

                wgt = ( v8u16 ) __msa_fill_h( i_weight );
                offset_val0 = __msa_fill_h( i_offset_val );
                denom = __msa_fill_h( i_log2_denom );

                src_vec0 = LD_UB( p_src1 );
                p_src1 += i_src_stride;

                temp_vec1 = ( v8u16 ) __msa_ilvl_b( zero, ( v16i8 ) src_vec0 );
                temp_vec0 = ( v8u16 ) __msa_ilvr_b( zero, ( v16i8 ) src_vec0 );

                temp_vec0 = wgt * temp_vec0;
                temp_vec1 = wgt * temp_vec1;

                temp_vec0 = ( v8u16 ) __msa_adds_s_h( ( v8i16 ) temp_vec0,
                                                      offset_val0 );
                temp_vec1 = ( v8u16 ) __msa_adds_s_h( ( v8i16 ) temp_vec1,
                                                      offset_val0 );

                temp_vec0 = ( v8u16 ) __msa_maxi_s_h( ( v8i16 ) temp_vec0, 0 );
                temp_vec1 = ( v8u16 ) __msa_maxi_s_h( ( v8i16 ) temp_vec1, 0 );

                temp_vec0 = ( v8u16 ) __msa_srl_h( ( v8i16 ) temp_vec0, denom );
                temp_vec1 = ( v8u16 ) __msa_srl_h( ( v8i16 ) temp_vec1, denom );

                temp_vec0 = __msa_sat_u_h( temp_vec0, 7 );
                temp_vec1 = __msa_sat_u_h( temp_vec1, 7 );

                tmp0 = __msa_pckev_b( ( v16i8 ) temp_vec1,
                                      ( v16i8 ) temp_vec0 );
                ST_SB( tmp0, p_dst + i_cnt * ( *p_dst_stride ) );
            }
        }
        else if( 20 == i_width )
        {
            mc_weight_w20_msa( p_dst, *p_dst_stride, p_src1, i_src_stride,
                               pWeight, i_h4w );
            p_src1 = src1_org + i_h4w * i_src_stride;

            for( i_cnt = i_h4w; i_cnt < i_height; i_cnt++ )
            {
                uint32_t temp0;
                v16i8 zero = {0};
                v16u8 src_vec0;
                v16i8 tmp0;
                v8u16 temp_vec0, temp_vec1;
                v8u16 wgt;
                v8i16 denom, offset_val0;

                i_offset_val <<= ( i_log2_denom );

                if( i_log2_denom )
                {
                    i_offset_val += ( 1 << ( i_log2_denom - 1 ) );
                }

                wgt = ( v8u16 ) __msa_fill_h( i_weight );
                offset_val0 = __msa_fill_h( i_offset_val );
                denom = __msa_fill_h( i_log2_denom );

                src_vec0 = LD_UB( p_src1 );
                temp0 = LW( p_src1 + 16 );
                p_src1 += i_src_stride;

                temp_vec1 = ( v8u16 ) __msa_ilvl_b( zero, ( v16i8 ) src_vec0 );
                temp_vec0 = ( v8u16 ) __msa_ilvr_b( zero, ( v16i8 ) src_vec0 );

                temp_vec0 = wgt * temp_vec0;
                temp_vec1 = wgt * temp_vec1;

                temp_vec0 = ( v8u16 ) __msa_adds_s_h( ( v8i16 ) temp_vec0,
                                                      offset_val0 );
                temp_vec1 = ( v8u16 ) __msa_adds_s_h( ( v8i16 ) temp_vec1,
                                                      offset_val0 );

                temp_vec0 = ( v8u16 ) __msa_maxi_s_h( ( v8i16 ) temp_vec0, 0 );
                temp_vec1 = ( v8u16 ) __msa_maxi_s_h( ( v8i16 ) temp_vec1, 0 );

                temp_vec0 = ( v8u16 ) __msa_srl_h( ( v8i16 ) temp_vec0, denom );
                temp_vec1 = ( v8u16 ) __msa_srl_h( ( v8i16 ) temp_vec1, denom );

                temp_vec0 = __msa_sat_u_h( temp_vec0, 7 );
                temp_vec1 = __msa_sat_u_h( temp_vec1, 7 );

                tmp0 = __msa_pckev_b( ( v16i8 ) temp_vec1,
                                      ( v16i8 ) temp_vec0 );
                ST_SB( tmp0, p_dst + i_cnt * ( *p_dst_stride ) );

                src_vec0 = ( v16u8 ) __msa_fill_w( temp0 );
                temp_vec0 = ( v8u16 ) __msa_ilvr_b( zero, ( v16i8 ) src_vec0 );
                temp_vec0 = wgt * temp_vec0;

                temp_vec0 = ( v8u16 ) __msa_adds_s_h( ( v8i16 ) temp_vec0,
                                                      offset_val0 );
                temp_vec0 = ( v8u16 ) __msa_maxi_s_h( ( v8i16 ) temp_vec0, 0 );
                temp_vec0 = ( v8u16 ) __msa_srl_h( ( v8i16 ) temp_vec0, denom );
                temp_vec0 = __msa_sat_u_h( temp_vec0, 7 );

                tmp0 = __msa_pckev_b( ( v16i8 ) temp_vec0,
                                      ( v16i8 ) temp_vec0 );
                temp0 = __msa_copy_u_w( ( v4i32 ) tmp0, 0 );
                SW( temp0,p_dst + i_cnt * ( *p_dst_stride ) + 16 );
            }
        }
        else if( 8 == i_width )
        {
            mc_weight_w8_msa( p_dst, *p_dst_stride, p_src1, i_src_stride,
                              pWeight, i_h4w );
            p_src1 = src1_org + i_h4w * i_src_stride;

            for( i_cnt = i_h4w; i_cnt < i_height; i_cnt++ )
            {
                uint64_t u_temp0;
                v16i8 zero = {0};
                v16u8 src_vec0;
                v16i8 tmp0;
                v8u16 temp_vec0;
                v8u16 wgt;
                v8i16 denom, offset_val0;

                i_offset_val = i_offset_val << i_log2_denom;

                if( i_log2_denom )
                {
                    i_offset_val += ( 1 << ( i_log2_denom - 1 ) );
                }

                wgt = ( v8u16 ) __msa_fill_h( i_weight );
                offset_val0 = __msa_fill_h( i_offset_val );
                denom = __msa_fill_h( i_log2_denom );

                src_vec0 = LD_UB( p_src1 );
                p_src1 += i_src_stride;

                temp_vec0 = ( v8u16 ) __msa_ilvr_b( zero, ( v16i8 ) src_vec0 );
                temp_vec0 = wgt * temp_vec0;

                temp_vec0 = ( v8u16 ) __msa_adds_s_h( ( v8i16 ) temp_vec0,
                                                      offset_val0 );
                temp_vec0 = ( v8u16 ) __msa_maxi_s_h( ( v8i16 ) temp_vec0, 0 );
                temp_vec0 = ( v8u16 ) __msa_srl_h( ( v8i16 ) temp_vec0, denom );
                temp_vec0 = __msa_sat_u_h( temp_vec0, 7 );

                tmp0 = __msa_pckev_b( ( v16i8 ) temp_vec0,
                                      ( v16i8 ) temp_vec0 );
                u_temp0 = __msa_copy_u_d( ( v2i64 ) tmp0, 0 );
                SD( u_temp0, p_dst + i_cnt * ( *p_dst_stride ) );
            }
        }
        else if( 4 == i_width )
        {
            mc_weight_w4_msa( p_dst, *p_dst_stride, p_src1, i_src_stride,
                              pWeight, i_h4w );
            p_src1 = src1_org + i_h4w * i_src_stride;

            for( i_cnt = i_h4w; i_cnt < i_height; i_cnt++ )
            {
                uint32_t u_temp0;
                v16i8 zero = {0};
                v16u8 src_vec0;
                v16i8 tmp0;
                v8u16 temp_vec0;
                v8u16 wgt;
                v8i16 denom, offset_val0;

                i_offset_val <<= ( i_log2_denom );

                if( i_log2_denom )
                {
                    i_offset_val += ( 1 << ( i_log2_denom - 1 ) );
                }

                wgt = ( v8u16 ) __msa_fill_h( i_weight );
                offset_val0 = __msa_fill_h( i_offset_val );
                denom = __msa_fill_h( i_log2_denom );

                u_temp0 = LW( p_src1 );
                p_src1 += i_src_stride;

                src_vec0 = ( v16u8 ) __msa_fill_w( u_temp0 );

                temp_vec0 = ( v8u16 ) __msa_ilvr_b( zero, ( v16i8 ) src_vec0 );
                temp_vec0 = wgt * temp_vec0;

                temp_vec0 = ( v8u16 ) __msa_adds_s_h( ( v8i16 ) temp_vec0,
                                                      offset_val0 );
                temp_vec0 = ( v8u16 ) __msa_maxi_s_h( ( v8i16 ) temp_vec0, 0 );
                temp_vec0 = ( v8u16 ) __msa_srl_h( ( v8i16 ) temp_vec0, denom );
                temp_vec0 = __msa_sat_u_h( temp_vec0, 7 );

                tmp0 = __msa_pckev_b( ( v16i8 ) temp_vec0,
                                      ( v16i8 ) temp_vec0 );
                u_temp0 = __msa_copy_u_w( ( v4i32 ) tmp0, 0 );
                SW( u_temp0, p_dst + i_cnt * ( *p_dst_stride ) );
            }
        }

        return p_dst;
    }
    else
    {
        *p_dst_stride = i_src_stride;
        return p_src1;
    }
}

static weight_fn_t mc_weight_wtab_msa[6] =
{
    mc_weight_w4_msa,
    mc_weight_w4_msa,
    mc_weight_w8_msa,
    mc_weight_w16_msa,
    mc_weight_w16_msa,
    mc_weight_w20_msa,
};
#endif // !HIGH_BIT_DEPTH

void x264_mc_init_mips( uint32_t cpu, x264_mc_functions_t *pf  )
{
#if !HIGH_BIT_DEPTH
    if( cpu & X264_CPU_MSA )
    {
        pf->mc_luma = mc_luma_msa;
        pf->mc_chroma = mc_chroma_msa;
        pf->get_ref = get_ref_msa;

        pf->avg[PIXEL_16x16]= pixel_avg_16x16_msa;
        pf->avg[PIXEL_16x8] = pixel_avg_16x8_msa;
        pf->avg[PIXEL_8x16] = pixel_avg_8x16_msa;
        pf->avg[PIXEL_8x8] = pixel_avg_8x8_msa;
        pf->avg[PIXEL_8x4] = pixel_avg_8x4_msa;
        pf->avg[PIXEL_4x16] = pixel_avg_4x16_msa;
        pf->avg[PIXEL_4x8] = pixel_avg_4x8_msa;
        pf->avg[PIXEL_4x4] = pixel_avg_4x4_msa;
        pf->avg[PIXEL_4x2] = pixel_avg_4x2_msa;

        pf->weight = mc_weight_wtab_msa;
        pf->offsetadd = mc_weight_wtab_msa;
        pf->offsetsub = mc_weight_wtab_msa;

        pf->copy_16x16_unaligned = mc_copy_w16_msa;
        pf->copy[PIXEL_16x16] = mc_copy_w16_msa;
        pf->copy[PIXEL_8x8] = mc_copy_w8_msa;
        pf->copy[PIXEL_4x4] = mc_copy_w4_msa;

        pf->store_interleave_chroma = store_interleave_chroma_msa;
        pf->load_deinterleave_chroma_fenc = load_deinterleave_chroma_fenc_msa;
        pf->load_deinterleave_chroma_fdec = load_deinterleave_chroma_fdec_msa;

        pf->plane_copy_interleave = plane_copy_interleave_msa;
        pf->plane_copy_deinterleave = plane_copy_deinterleave_msa;
        pf->plane_copy_deinterleave_rgb = plane_copy_deinterleave_rgb_msa;

        pf->hpel_filter = hpel_filter_msa;

        pf->memcpy_aligned = memcpy;
        pf->memzero_aligned = memzero_aligned_msa;
        pf->frame_init_lowres_core = frame_init_lowres_core_msa;
    }
#endif // !HIGH_BIT_DEPTH
}
