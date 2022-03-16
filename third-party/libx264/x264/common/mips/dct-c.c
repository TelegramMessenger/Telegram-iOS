/*****************************************************************************
 * dct-c.c: msa transform and zigzag
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
#include "dct.h"

#if !HIGH_BIT_DEPTH
#define AVC_ITRANS_H( in0, in1, in2, in3, out0, out1, out2, out3 )          \
{                                                                           \
    v8i16 tmp0_m, tmp1_m, tmp2_m, tmp3_m;                                   \
                                                                            \
    tmp0_m = in0 + in2;                                                     \
    tmp1_m = in0 - in2;                                                     \
    tmp2_m = in1 >> 1;                                                      \
    tmp2_m = tmp2_m - in3;                                                  \
    tmp3_m = in3 >> 1;                                                      \
    tmp3_m = in1 + tmp3_m;                                                  \
                                                                            \
    BUTTERFLY_4( tmp0_m, tmp1_m, tmp2_m, tmp3_m, out0, out1, out2, out3 );  \
}

static void avc_dct4x4dc_msa( int16_t *p_src, int16_t *p_dst,
                              int32_t i_src_stride )
{
    v8i16 src0, src1, src2, src3, ver_res0, ver_res1, ver_res2, ver_res3;
    v4i32 src0_r, src1_r, src2_r, src3_r, tmp0, tmp1, tmp2, tmp3;
    v4i32 hor_res0, hor_res1, hor_res2, hor_res3;
    v4i32 ver_res0_r, ver_res1_r, ver_res2_r, ver_res3_r;

    LD_SH4( p_src, i_src_stride, src0, src1, src2, src3 );
    UNPCK_R_SH_SW( src0, src0_r );
    UNPCK_R_SH_SW( src1, src1_r );
    UNPCK_R_SH_SW( src2, src2_r );
    UNPCK_R_SH_SW( src3, src3_r );
    BUTTERFLY_4( src0_r, src2_r, src3_r, src1_r,
                 tmp0, tmp3, tmp2, tmp1 );
    BUTTERFLY_4( tmp0, tmp1, tmp2, tmp3,
                 hor_res0, hor_res3, hor_res2, hor_res1 );
    TRANSPOSE4x4_SW_SW( hor_res0, hor_res1, hor_res2, hor_res3,
                        hor_res0, hor_res1, hor_res2, hor_res3 );
    BUTTERFLY_4( hor_res0, hor_res2, hor_res3, hor_res1,
                 tmp0, tmp3, tmp2, tmp1 );
    BUTTERFLY_4( tmp0, tmp1, tmp2, tmp3,
                 ver_res0_r, ver_res3_r, ver_res2_r, ver_res1_r );
    SRARI_W4_SW( ver_res0_r, ver_res1_r, ver_res2_r, ver_res3_r, 1 );
    PCKEV_H4_SH( ver_res0_r, ver_res0_r, ver_res1_r, ver_res1_r,
                 ver_res2_r, ver_res2_r, ver_res3_r, ver_res3_r,
                 ver_res0, ver_res1, ver_res2, ver_res3 );
    PCKOD_D2_SH( ver_res1, ver_res0, ver_res3, ver_res2, ver_res0, ver_res2 );
    ST_SH2( ver_res0, ver_res2, p_dst, 8 );
}

static void avc_sub4x4_dct_msa( uint8_t *p_src, int32_t i_src_stride,
                                uint8_t *p_ref, int32_t i_dst_stride,
                                int16_t *p_dst )
{
    uint32_t i_src0, i_src1, i_src2, i_src3;
    uint32_t i_ref0, i_ref1, i_ref2, i_ref3;
    v16i8 src = { 0 };
    v16i8 ref = { 0 };
    v16u8 inp0, inp1;
    v8i16 diff0, diff1, diff2, diff3;
    v8i16 temp0, temp1, temp2, temp3;

    LW4( p_src, i_src_stride, i_src0, i_src1, i_src2, i_src3 );
    LW4( p_ref, i_dst_stride, i_ref0, i_ref1, i_ref2, i_ref3 );

    INSERT_W4_SB( i_src0, i_src1, i_src2, i_src3, src );
    INSERT_W4_SB( i_ref0, i_ref1, i_ref2, i_ref3, ref );

    ILVRL_B2_UB( src, ref, inp0, inp1 );

    HSUB_UB2_SH( inp0, inp1, diff0, diff2 );

    diff1 = ( v8i16 ) __msa_ilvl_d( ( v2i64 ) diff0, ( v2i64 ) diff0 );
    diff3 = ( v8i16 ) __msa_ilvl_d( ( v2i64 ) diff2, ( v2i64 ) diff2 );

    BUTTERFLY_4( diff0, diff1, diff2, diff3, temp0, temp1, temp2, temp3 );

    diff0 = temp0 + temp1;
    diff1 = ( temp3 << 1 ) + temp2;
    diff2 = temp0 - temp1;
    diff3 = temp3 - ( temp2 << 1 );

    TRANSPOSE4x4_SH_SH( diff0, diff1, diff2, diff3,
                        temp0, temp1, temp2, temp3 );
    BUTTERFLY_4( temp0, temp1, temp2, temp3, diff0, diff1, diff2, diff3 );

    temp0 = diff0 + diff1;
    temp1 = ( diff3 << 1 ) + diff2;
    temp2 = diff0 - diff1;
    temp3 = diff3 - ( diff2 << 1 );

    ILVR_D2_UB( temp1, temp0, temp3, temp2, inp0, inp1 );
    ST_UB2( inp0, inp1, p_dst, 8 );
}

static void avc_zigzag_scan_4x4_frame_msa( int16_t pi_dct[16],
                                           int16_t pi_level[16] )
{
    v8i16 src0, src1;
    v8i16 mask0 = { 0, 4, 1, 2, 5, 8, 12, 9 };
    v8i16 mask1 = { 6, 3, 7, 10, 13, 14, 11, 15 };

    LD_SH2( pi_dct, 8, src0, src1 );
    VSHF_H2_SH( src0, src1, src0, src1, mask0, mask1, mask0, mask1 );
    ST_SH2( mask0, mask1, pi_level, 8 );
}

static void avc_idct4x4_addblk_msa( uint8_t *p_dst, int16_t *p_src,
                                    int32_t i_dst_stride )
{
    v8i16 src0, src1, src2, src3;
    v8i16 hres0, hres1, hres2, hres3;
    v8i16 vres0, vres1, vres2, vres3;
    v8i16 zeros = { 0 };

    LD4x4_SH( p_src, src0, src1, src2, src3 );
    AVC_ITRANS_H( src0, src1, src2, src3, hres0, hres1, hres2, hres3 );
    TRANSPOSE4x4_SH_SH( hres0, hres1, hres2, hres3,
                        hres0, hres1, hres2, hres3 );
    AVC_ITRANS_H( hres0, hres1, hres2, hres3, vres0, vres1, vres2, vres3 );
    SRARI_H4_SH( vres0, vres1, vres2, vres3, 6 );
    ADDBLK_ST4x4_UB( vres0, vres1, vres2, vres3, p_dst, i_dst_stride );
    ST_SH2( zeros, zeros, p_src, 8 );
}

static void avc_idct4x4_addblk_dc_msa( uint8_t *p_dst, int16_t *p_src,
                                       int32_t i_dst_stride )
{
    int16_t i_dc;
    uint32_t i_src0, i_src1, i_src2, i_src3;
    v16u8 pred = { 0 };
    v16i8 out;
    v8i16 input_dc, pred_r, pred_l;

    i_dc = ( p_src[0] + 32 ) >> 6;
    input_dc = __msa_fill_h( i_dc );
    p_src[ 0 ] = 0;

    LW4( p_dst, i_dst_stride, i_src0, i_src1, i_src2, i_src3 );
    INSERT_W4_UB( i_src0, i_src1, i_src2, i_src3, pred );
    UNPCK_UB_SH( pred, pred_r, pred_l );

    pred_r += input_dc;
    pred_l += input_dc;

    CLIP_SH2_0_255( pred_r, pred_l );
    out = __msa_pckev_b( ( v16i8 ) pred_l, ( v16i8 ) pred_r );
    ST4x4_UB( out, out, 0, 1, 2, 3, p_dst, i_dst_stride );
}

static void avc_idct8_addblk_msa( uint8_t *p_dst, int16_t *p_src,
                                  int32_t i_dst_stride )
{
    v8i16 src0, src1, src2, src3, src4, src5, src6, src7;
    v8i16 vec0, vec1, vec2, vec3;
    v8i16 tmp0, tmp1, tmp2, tmp3, tmp4, tmp5, tmp6, tmp7;
    v8i16 res0, res1, res2, res3, res4, res5, res6, res7;
    v4i32 tmp0_r, tmp1_r, tmp2_r, tmp3_r, tmp4_r, tmp5_r, tmp6_r, tmp7_r;
    v4i32 tmp0_l, tmp1_l, tmp2_l, tmp3_l, tmp4_l, tmp5_l, tmp6_l, tmp7_l;
    v4i32 vec0_r, vec1_r, vec2_r, vec3_r, vec0_l, vec1_l, vec2_l, vec3_l;
    v4i32 res0_r, res1_r, res2_r, res3_r, res4_r, res5_r, res6_r, res7_r;
    v4i32 res0_l, res1_l, res2_l, res3_l, res4_l, res5_l, res6_l, res7_l;
    v16i8 dst0, dst1, dst2, dst3, dst4, dst5, dst6, dst7;
    v16i8 zeros = { 0 };

    p_src[ 0 ] += 32;

    LD_SH8( p_src, 8, src0, src1, src2, src3, src4, src5, src6, src7 );

    vec0 = src0 + src4;
    vec1 = src0 - src4;
    vec2 = src2 >> 1;
    vec2 = vec2 - src6;
    vec3 = src6 >> 1;
    vec3 = src2 + vec3;

    BUTTERFLY_4( vec0, vec1, vec2, vec3, tmp0, tmp1, tmp2, tmp3 );

    vec0 = src7 >> 1;
    vec0 = src5 - vec0 - src3 - src7;
    vec1 = src3 >> 1;
    vec1 = src1 - vec1 + src7 - src3;
    vec2 = src5 >> 1;
    vec2 = vec2 - src1 + src7 + src5;
    vec3 = src1 >> 1;
    vec3 = vec3 + src3 + src5 + src1;
    tmp4 = vec3 >> 2;
    tmp4 += vec0;
    tmp5 = vec2 >> 2;
    tmp5 += vec1;
    tmp6 = vec1 >> 2;
    tmp6 -= vec2;
    tmp7 = vec0 >> 2;
    tmp7 = vec3 - tmp7;

    BUTTERFLY_8( tmp0, tmp1, tmp2, tmp3, tmp4, tmp5, tmp6, tmp7,
                 res0, res1, res2, res3, res4, res5, res6, res7 );
    TRANSPOSE8x8_SH_SH( res0, res1, res2, res3, res4, res5, res6, res7,
                        res0, res1, res2, res3, res4, res5, res6, res7 );
    UNPCK_SH_SW( res0, tmp0_r, tmp0_l );
    UNPCK_SH_SW( res1, tmp1_r, tmp1_l );
    UNPCK_SH_SW( res2, tmp2_r, tmp2_l );
    UNPCK_SH_SW( res3, tmp3_r, tmp3_l );
    UNPCK_SH_SW( res4, tmp4_r, tmp4_l );
    UNPCK_SH_SW( res5, tmp5_r, tmp5_l );
    UNPCK_SH_SW( res6, tmp6_r, tmp6_l );
    UNPCK_SH_SW( res7, tmp7_r, tmp7_l );
    BUTTERFLY_4( tmp0_r, tmp0_l, tmp4_l, tmp4_r,
                 vec0_r, vec0_l, vec1_l, vec1_r );

    vec2_r = tmp2_r >> 1;
    vec2_l = tmp2_l >> 1;
    vec2_r -= tmp6_r;
    vec2_l -= tmp6_l;
    vec3_r = tmp6_r >> 1;
    vec3_l = tmp6_l >> 1;
    vec3_r += tmp2_r;
    vec3_l += tmp2_l;

    BUTTERFLY_4( vec0_r, vec1_r, vec2_r, vec3_r,
                 tmp0_r, tmp2_r, tmp4_r, tmp6_r );
    BUTTERFLY_4( vec0_l, vec1_l, vec2_l, vec3_l,
                 tmp0_l, tmp2_l, tmp4_l, tmp6_l );

    vec0_r = tmp7_r >> 1;
    vec0_l = tmp7_l >> 1;
    vec0_r = tmp5_r - vec0_r - tmp3_r - tmp7_r;
    vec0_l = tmp5_l - vec0_l - tmp3_l - tmp7_l;
    vec1_r = tmp3_r >> 1;
    vec1_l = tmp3_l >> 1;
    vec1_r = tmp1_r - vec1_r + tmp7_r - tmp3_r;
    vec1_l = tmp1_l - vec1_l + tmp7_l - tmp3_l;
    vec2_r = tmp5_r >> 1;
    vec2_l = tmp5_l >> 1;
    vec2_r = vec2_r - tmp1_r + tmp7_r + tmp5_r;
    vec2_l = vec2_l - tmp1_l + tmp7_l + tmp5_l;
    vec3_r = tmp1_r >> 1;
    vec3_l = tmp1_l >> 1;
    vec3_r = vec3_r + tmp3_r + tmp5_r + tmp1_r;
    vec3_l = vec3_l + tmp3_l + tmp5_l + tmp1_l;
    tmp1_r = vec3_r >> 2;
    tmp1_l = vec3_l >> 2;
    tmp1_r += vec0_r;
    tmp1_l += vec0_l;
    tmp3_r = vec2_r >> 2;
    tmp3_l = vec2_l >> 2;
    tmp3_r += vec1_r;
    tmp3_l += vec1_l;
    tmp5_r = vec1_r >> 2;
    tmp5_l = vec1_l >> 2;
    tmp5_r -= vec2_r;
    tmp5_l -= vec2_l;
    tmp7_r = vec0_r >> 2;
    tmp7_l = vec0_l >> 2;
    tmp7_r = vec3_r - tmp7_r;
    tmp7_l = vec3_l - tmp7_l;

    BUTTERFLY_4( tmp0_r, tmp0_l, tmp7_l, tmp7_r,
                 res0_r, res0_l, res7_l, res7_r );
    BUTTERFLY_4( tmp2_r, tmp2_l, tmp5_l, tmp5_r,
                 res1_r, res1_l, res6_l, res6_r );
    BUTTERFLY_4( tmp4_r, tmp4_l, tmp3_l, tmp3_r,
                 res2_r, res2_l, res5_l, res5_r );
    BUTTERFLY_4( tmp6_r, tmp6_l, tmp1_l, tmp1_r,
                 res3_r, res3_l, res4_l, res4_r );
    SRA_4V( res0_r, res0_l, res1_r, res1_l, 6 );
    SRA_4V( res2_r, res2_l, res3_r, res3_l, 6 );
    SRA_4V( res4_r, res4_l, res5_r, res5_l, 6 );
    SRA_4V( res6_r, res6_l, res7_r, res7_l, 6 );
    PCKEV_H4_SH( res0_l, res0_r, res1_l, res1_r, res2_l, res2_r, res3_l, res3_r,
                 res0, res1, res2, res3 );
    PCKEV_H4_SH( res4_l, res4_r, res5_l, res5_r, res6_l, res6_r, res7_l, res7_r,
                 res4, res5, res6, res7 );
    LD_SB8( p_dst, i_dst_stride,
            dst0, dst1, dst2, dst3,
            dst4, dst5, dst6, dst7 );
    ILVR_B4_SH( zeros, dst0, zeros, dst1, zeros, dst2, zeros, dst3,
                tmp0, tmp1, tmp2, tmp3 );
    ILVR_B4_SH( zeros, dst4, zeros, dst5, zeros, dst6, zeros, dst7,
                tmp4, tmp5, tmp6, tmp7 );
    ADD4( res0, tmp0, res1, tmp1, res2, tmp2, res3, tmp3,
          res0, res1, res2, res3 );
    ADD4( res4, tmp4, res5, tmp5, res6, tmp6, res7, tmp7,
          res4, res5, res6, res7 );
    CLIP_SH4_0_255( res0, res1, res2, res3 );
    CLIP_SH4_0_255( res4, res5, res6, res7 );
    PCKEV_B4_SB( res1, res0, res3, res2, res5, res4, res7, res6,
                 dst0, dst1, dst2, dst3 );
    ST8x4_UB( dst0, dst1, p_dst, i_dst_stride );
    p_dst += ( 4 * i_dst_stride );
    ST8x4_UB( dst2, dst3, p_dst, i_dst_stride );
}

static void avc_idct4x4dc_msa( int16_t *p_src, int32_t i_src_stride,
                               int16_t *p_dst, int32_t i_dst_stride )
{
    v8i16 src0, src1, src2, src3;
    v4i32 src0_r, src1_r, src2_r, src3_r;
    v4i32 hres0, hres1, hres2, hres3;
    v8i16 vres0, vres1, vres2, vres3;
    v4i32 vec0, vec1, vec2, vec3, vec4, vec5, vec6, vec7;
    v2i64 res0, res1;

    LD_SH4( p_src, i_src_stride, src0, src1, src2, src3 );
    UNPCK_R_SH_SW( src0, src0_r );
    UNPCK_R_SH_SW( src1, src1_r );
    UNPCK_R_SH_SW( src2, src2_r );
    UNPCK_R_SH_SW( src3, src3_r );
    BUTTERFLY_4( src0_r, src2_r, src3_r, src1_r, vec0, vec3, vec2, vec1 );
    BUTTERFLY_4( vec0, vec1, vec2, vec3, hres0, hres3, hres2, hres1 );
    TRANSPOSE4x4_SW_SW( hres0, hres1, hres2, hres3,
                        hres0, hres1, hres2, hres3 );
    BUTTERFLY_4( hres0, hres2, hres3, hres1, vec0, vec3, vec2, vec1 );
    BUTTERFLY_4( vec0, vec1, vec2, vec3, vec4, vec7, vec6, vec5 );
    PCKEV_H4_SH( vec4, vec4, vec5, vec5, vec6, vec6, vec7, vec7,
                 vres0, vres1, vres2, vres3 );
    PCKOD_D2_SD( vres1, vres0, vres3, vres2, res0, res1 );
    ST8x4_UB( res0, res1, p_dst, i_dst_stride * 2 );
}

static int32_t subtract_sum4x4_msa( uint8_t *p_src, int32_t i_src_stride,
                                    uint8_t *pred_ptr, int32_t i_pred_stride )
{
    int16_t i_sum;
    uint32_t i_src0, i_src1, i_src2, i_src3;
    uint32_t i_pred0, i_pred1, i_pred2, i_pred3;
    v16i8 src = { 0 };
    v16i8 pred = { 0 };
    v16u8 src_l0, src_l1;
    v8i16 diff0, diff1;

    LW4( p_src, i_src_stride, i_src0, i_src1, i_src2, i_src3 );
    LW4( pred_ptr, i_pred_stride, i_pred0, i_pred1, i_pred2, i_pred3 );
    INSERT_W4_SB( i_src0, i_src1, i_src2, i_src3, src );
    INSERT_W4_SB( i_pred0, i_pred1, i_pred2, i_pred3, pred );
    ILVRL_B2_UB( src, pred, src_l0, src_l1 );
    HSUB_UB2_SH( src_l0, src_l1, diff0, diff1 );
    i_sum = HADD_UH_U32( diff0 + diff1 );

    return i_sum;
}

void x264_dct4x4dc_msa( int16_t d[16] )
{
    avc_dct4x4dc_msa( d, d, 4 );
}

void x264_idct4x4dc_msa( int16_t d[16] )
{
    avc_idct4x4dc_msa( d, 4, d, 4 );
}

void x264_add4x4_idct_msa( uint8_t *p_dst, int16_t pi_dct[16] )
{
    avc_idct4x4_addblk_msa( p_dst, pi_dct, FDEC_STRIDE );
}

void x264_add8x8_idct_msa( uint8_t *p_dst, int16_t pi_dct[4][16] )
{
    avc_idct4x4_addblk_msa( &p_dst[0], &pi_dct[0][0], FDEC_STRIDE );
    avc_idct4x4_addblk_msa( &p_dst[4], &pi_dct[1][0], FDEC_STRIDE );
    avc_idct4x4_addblk_msa( &p_dst[4 * FDEC_STRIDE + 0],
                            &pi_dct[2][0], FDEC_STRIDE );
    avc_idct4x4_addblk_msa( &p_dst[4 * FDEC_STRIDE + 4],
                            &pi_dct[3][0], FDEC_STRIDE );
}

void x264_add16x16_idct_msa( uint8_t *p_dst, int16_t pi_dct[16][16] )
{
    x264_add8x8_idct_msa( &p_dst[0], &pi_dct[0] );
    x264_add8x8_idct_msa( &p_dst[8], &pi_dct[4] );
    x264_add8x8_idct_msa( &p_dst[8 * FDEC_STRIDE + 0], &pi_dct[8] );
    x264_add8x8_idct_msa( &p_dst[8 * FDEC_STRIDE + 8], &pi_dct[12] );
}

void x264_add8x8_idct8_msa( uint8_t *p_dst, int16_t pi_dct[64] )
{
    avc_idct8_addblk_msa( p_dst, pi_dct, FDEC_STRIDE );
}

void x264_add16x16_idct8_msa( uint8_t *p_dst, int16_t pi_dct[4][64] )
{
    avc_idct8_addblk_msa( &p_dst[0], &pi_dct[0][0], FDEC_STRIDE );
    avc_idct8_addblk_msa( &p_dst[8], &pi_dct[1][0], FDEC_STRIDE );
    avc_idct8_addblk_msa( &p_dst[8 * FDEC_STRIDE + 0],
                          &pi_dct[2][0], FDEC_STRIDE );
    avc_idct8_addblk_msa( &p_dst[8 * FDEC_STRIDE + 8],
                          &pi_dct[3][0], FDEC_STRIDE );
}

void x264_add8x8_idct_dc_msa( uint8_t *p_dst, int16_t pi_dct[4] )
{
    avc_idct4x4_addblk_dc_msa( &p_dst[0], &pi_dct[0], FDEC_STRIDE );
    avc_idct4x4_addblk_dc_msa( &p_dst[4], &pi_dct[1], FDEC_STRIDE );
    avc_idct4x4_addblk_dc_msa( &p_dst[4 * FDEC_STRIDE + 0],
                               &pi_dct[2], FDEC_STRIDE );
    avc_idct4x4_addblk_dc_msa( &p_dst[4 * FDEC_STRIDE + 4],
                               &pi_dct[3], FDEC_STRIDE );
}

void x264_add16x16_idct_dc_msa( uint8_t *p_dst, int16_t pi_dct[16] )
{
    for( int32_t i = 0; i < 4; i++, pi_dct += 4, p_dst += 4 * FDEC_STRIDE )
    {
        avc_idct4x4_addblk_dc_msa( &p_dst[ 0], &pi_dct[0], FDEC_STRIDE );
        avc_idct4x4_addblk_dc_msa( &p_dst[ 4], &pi_dct[1], FDEC_STRIDE );
        avc_idct4x4_addblk_dc_msa( &p_dst[ 8], &pi_dct[2], FDEC_STRIDE );
        avc_idct4x4_addblk_dc_msa( &p_dst[12], &pi_dct[3], FDEC_STRIDE );
    }
}

void x264_sub4x4_dct_msa( int16_t p_dst[16], uint8_t *p_src,
                          uint8_t *p_ref )
{
    avc_sub4x4_dct_msa( p_src, FENC_STRIDE, p_ref, FDEC_STRIDE, p_dst );
}

void x264_sub8x8_dct_msa( int16_t p_dst[4][16], uint8_t *p_src,
                          uint8_t *p_ref )
{
    avc_sub4x4_dct_msa( &p_src[0], FENC_STRIDE,
                        &p_ref[0], FDEC_STRIDE, p_dst[0] );
    avc_sub4x4_dct_msa( &p_src[4], FENC_STRIDE, &p_ref[4],
                        FDEC_STRIDE, p_dst[1] );
    avc_sub4x4_dct_msa( &p_src[4 * FENC_STRIDE + 0],
                        FENC_STRIDE, &p_ref[4 * FDEC_STRIDE + 0],
                        FDEC_STRIDE, p_dst[2] );
    avc_sub4x4_dct_msa( &p_src[4 * FENC_STRIDE + 4],
                        FENC_STRIDE, &p_ref[4 * FDEC_STRIDE + 4],
                        FDEC_STRIDE, p_dst[3] );
}

void x264_sub16x16_dct_msa( int16_t p_dst[16][16],
                            uint8_t *p_src,
                            uint8_t *p_ref )
{
    x264_sub8x8_dct_msa( &p_dst[ 0], &p_src[0], &p_ref[0] );
    x264_sub8x8_dct_msa( &p_dst[ 4], &p_src[8], &p_ref[8] );
    x264_sub8x8_dct_msa( &p_dst[ 8], &p_src[8 * FENC_STRIDE + 0],
                         &p_ref[8*FDEC_STRIDE+0] );
    x264_sub8x8_dct_msa( &p_dst[12], &p_src[8 * FENC_STRIDE + 8],
                         &p_ref[8*FDEC_STRIDE+8] );
}

void x264_sub8x8_dct_dc_msa( int16_t pi_dct[4],
                             uint8_t *p_pix1, uint8_t *p_pix2 )
{
    int32_t d0, d1, d2, d3;

    pi_dct[0] = subtract_sum4x4_msa( &p_pix1[0], FENC_STRIDE,
                                     &p_pix2[0], FDEC_STRIDE );
    pi_dct[1] = subtract_sum4x4_msa( &p_pix1[4], FENC_STRIDE,
                                     &p_pix2[4], FDEC_STRIDE );
    pi_dct[2] = subtract_sum4x4_msa( &p_pix1[4 * FENC_STRIDE + 0], FENC_STRIDE,
                                     &p_pix2[4 * FDEC_STRIDE + 0],
                                     FDEC_STRIDE );
    pi_dct[3] = subtract_sum4x4_msa( &p_pix1[4 * FENC_STRIDE + 4], FENC_STRIDE,
                                     &p_pix2[4 * FDEC_STRIDE + 4],
                                     FDEC_STRIDE );

    BUTTERFLY_4( pi_dct[0], pi_dct[2], pi_dct[3], pi_dct[1], d0, d1, d3, d2 );
    BUTTERFLY_4( d0, d2, d3, d1, pi_dct[0], pi_dct[2], pi_dct[3], pi_dct[1] );
}

void x264_sub8x16_dct_dc_msa( int16_t pi_dct[8],
                              uint8_t *p_pix1, uint8_t *p_pix2 )
{
    int32_t a0, a1, a2, a3, a4, a5, a6, a7;
    int32_t b0, b1, b2, b3, b4, b5, b6, b7;

    a0 = subtract_sum4x4_msa( &p_pix1[ 0 * FENC_STRIDE + 0], FENC_STRIDE,
                              &p_pix2[ 0 * FDEC_STRIDE + 0], FDEC_STRIDE );
    a1 = subtract_sum4x4_msa( &p_pix1[ 0 * FENC_STRIDE + 4], FENC_STRIDE,
                              &p_pix2[ 0 * FDEC_STRIDE + 4], FDEC_STRIDE );
    a2 = subtract_sum4x4_msa( &p_pix1[ 4 * FENC_STRIDE + 0], FENC_STRIDE,
                              &p_pix2[ 4 * FDEC_STRIDE + 0], FDEC_STRIDE );
    a3 = subtract_sum4x4_msa( &p_pix1[ 4 * FENC_STRIDE + 4], FENC_STRIDE,
                              &p_pix2[ 4 * FDEC_STRIDE + 4], FDEC_STRIDE );
    a4 = subtract_sum4x4_msa( &p_pix1[ 8 * FENC_STRIDE + 0], FENC_STRIDE,
                              &p_pix2[ 8 * FDEC_STRIDE + 0], FDEC_STRIDE );
    a5 = subtract_sum4x4_msa( &p_pix1[ 8 * FENC_STRIDE + 4], FENC_STRIDE,
                              &p_pix2[ 8 * FDEC_STRIDE + 4], FDEC_STRIDE );
    a6 = subtract_sum4x4_msa( &p_pix1[12 * FENC_STRIDE + 0], FENC_STRIDE,
                              &p_pix2[12 * FDEC_STRIDE + 0], FDEC_STRIDE );
    a7 = subtract_sum4x4_msa( &p_pix1[12 * FENC_STRIDE + 4], FENC_STRIDE,
                              &p_pix2[12 * FDEC_STRIDE + 4], FDEC_STRIDE );

    BUTTERFLY_8( a0, a2, a4, a6, a7, a5, a3, a1,
                 b0, b1, b2, b3, b7, b6, b5, b4 );
    BUTTERFLY_8( b0, b2, b4, b6, b7, b5, b3, b1,
                 a0, a1, a2, a3, a7, a6, a5, a4 );
    BUTTERFLY_8( a0, a2, a4, a6, a7, a5, a3, a1,
                 pi_dct[0], pi_dct[1], pi_dct[6], pi_dct[7],
                 pi_dct[5], pi_dct[4], pi_dct[3], pi_dct[2] );
}

void x264_zigzag_scan_4x4_frame_msa( int16_t pi_level[16], int16_t pi_dct[16] )
{
    avc_zigzag_scan_4x4_frame_msa( pi_dct, pi_level );
}
#endif
