/*****************************************************************************
 * dct.c: ppc transform and zigzag
 *****************************************************************************
 * Copyright (C) 2003-2022 x264 project
 *
 * Authors: Guillaume Poirier <gpoirier@mplayerhq.hu>
 *          Eric Petit <eric.petit@lapsus.org>
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
#include "dct.h"

#if !HIGH_BIT_DEPTH
#define VEC_DCT(a0,a1,a2,a3,b0,b1,b2,b3) \
    b1 = vec_add( a0, a3 );              \
    b3 = vec_add( a1, a2 );              \
    b0 = vec_add( b1, b3 );              \
    b2 = vec_sub( b1, b3 );              \
    a0 = vec_sub( a0, a3 );              \
    a1 = vec_sub( a1, a2 );              \
    b1 = vec_add( a0, a0 );              \
    b1 = vec_add( b1, a1 );              \
    b3 = vec_sub( a0, a1 );              \
    b3 = vec_sub( b3, a1 )

void x264_sub4x4_dct_altivec( int16_t dct[16], uint8_t *pix1, uint8_t *pix2 )
{
    PREP_DIFF_8BYTEALIGNED;
    vec_s16_t dct0v, dct1v, dct2v, dct3v;
    vec_s16_t tmp0v, tmp1v, tmp2v, tmp3v;

    vec_u8_t permHighv;

    VEC_DIFF_H_8BYTE_ALIGNED( pix1, FENC_STRIDE, pix2, FDEC_STRIDE, 4, dct0v );
    VEC_DIFF_H_8BYTE_ALIGNED( pix1, FENC_STRIDE, pix2, FDEC_STRIDE, 4, dct1v );
    VEC_DIFF_H_8BYTE_ALIGNED( pix1, FENC_STRIDE, pix2, FDEC_STRIDE, 4, dct2v );
    VEC_DIFF_H_8BYTE_ALIGNED( pix1, FENC_STRIDE, pix2, FDEC_STRIDE, 4, dct3v );
    VEC_DCT( dct0v, dct1v, dct2v, dct3v, tmp0v, tmp1v, tmp2v, tmp3v );
    VEC_TRANSPOSE_4( tmp0v, tmp1v, tmp2v, tmp3v,
                     dct0v, dct1v, dct2v, dct3v );
    permHighv = (vec_u8_t) CV(0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17);
    VEC_DCT( dct0v, dct1v, dct2v, dct3v, tmp0v, tmp1v, tmp2v, tmp3v );

    vec_st(vec_perm(tmp0v, tmp1v, permHighv), 0,  dct);
    vec_st(vec_perm(tmp2v, tmp3v, permHighv), 16, dct);
}

void x264_sub8x8_dct_altivec( int16_t dct[4][16], uint8_t *pix1, uint8_t *pix2 )
{
    PREP_DIFF_8BYTEALIGNED;
    vec_s16_t dct0v, dct1v, dct2v, dct3v, dct4v, dct5v, dct6v, dct7v;
    vec_s16_t tmp0v, tmp1v, tmp2v, tmp3v, tmp4v, tmp5v, tmp6v, tmp7v;

    vec_u8_t permHighv, permLowv;

    VEC_DIFF_H_8BYTE_ALIGNED( pix1, FENC_STRIDE, pix2, FDEC_STRIDE, 8, dct0v );
    VEC_DIFF_H_8BYTE_ALIGNED( pix1, FENC_STRIDE, pix2, FDEC_STRIDE, 8, dct1v );
    VEC_DIFF_H_8BYTE_ALIGNED( pix1, FENC_STRIDE, pix2, FDEC_STRIDE, 8, dct2v );
    VEC_DIFF_H_8BYTE_ALIGNED( pix1, FENC_STRIDE, pix2, FDEC_STRIDE, 8, dct3v );
    VEC_DIFF_H_8BYTE_ALIGNED( pix1, FENC_STRIDE, pix2, FDEC_STRIDE, 8, dct4v );
    VEC_DIFF_H_8BYTE_ALIGNED( pix1, FENC_STRIDE, pix2, FDEC_STRIDE, 8, dct5v );
    VEC_DIFF_H_8BYTE_ALIGNED( pix1, FENC_STRIDE, pix2, FDEC_STRIDE, 8, dct6v );
    VEC_DIFF_H_8BYTE_ALIGNED( pix1, FENC_STRIDE, pix2, FDEC_STRIDE, 8, dct7v );
    VEC_DCT( dct0v, dct1v, dct2v, dct3v, tmp0v, tmp1v, tmp2v, tmp3v );
    VEC_DCT( dct4v, dct5v, dct6v, dct7v, tmp4v, tmp5v, tmp6v, tmp7v );
    VEC_TRANSPOSE_8( tmp0v, tmp1v, tmp2v, tmp3v,
                     tmp4v, tmp5v, tmp6v, tmp7v,
                     dct0v, dct1v, dct2v, dct3v,
                     dct4v, dct5v, dct6v, dct7v );

    permHighv = (vec_u8_t) CV(0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17);
    permLowv  = (vec_u8_t) CV(0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F);

    VEC_DCT( dct0v, dct1v, dct2v, dct3v, tmp0v, tmp1v, tmp2v, tmp3v );
    VEC_DCT( dct4v, dct5v, dct6v, dct7v, tmp4v, tmp5v, tmp6v, tmp7v );

    vec_st(vec_perm(tmp0v, tmp1v, permHighv), 0,   *dct);
    vec_st(vec_perm(tmp2v, tmp3v, permHighv), 16,  *dct);
    vec_st(vec_perm(tmp4v, tmp5v, permHighv), 32,  *dct);
    vec_st(vec_perm(tmp6v, tmp7v, permHighv), 48,  *dct);
    vec_st(vec_perm(tmp0v, tmp1v, permLowv),  64,  *dct);
    vec_st(vec_perm(tmp2v, tmp3v, permLowv),  80,  *dct);
    vec_st(vec_perm(tmp4v, tmp5v, permLowv),  96,  *dct);
    vec_st(vec_perm(tmp6v, tmp7v, permLowv),  112, *dct);
}

void x264_sub16x16_dct_altivec( int16_t dct[16][16], uint8_t *pix1, uint8_t *pix2 )
{
    x264_sub8x8_dct_altivec( &dct[ 0], &pix1[0], &pix2[0] );
    x264_sub8x8_dct_altivec( &dct[ 4], &pix1[8], &pix2[8] );
    x264_sub8x8_dct_altivec( &dct[ 8], &pix1[8*FENC_STRIDE+0], &pix2[8*FDEC_STRIDE+0] );
    x264_sub8x8_dct_altivec( &dct[12], &pix1[8*FENC_STRIDE+8], &pix2[8*FDEC_STRIDE+8] );
}

/***************************************************************************
 * 8x8 transform:
 ***************************************************************************/

static void pix_diff( uint8_t *p1, uint8_t *p2, vec_s16_t *diff, int i )
{
    vec_s16_t pix1v, pix2v, tmp[4];
    vec_u8_t pix1v8, pix2v8;
    LOAD_ZERO;

    for( int j = 0; j < 4; j++ )
    {
        pix1v8 = vec_vsx_ld( 0, p1 );
        pix2v8 = vec_vsx_ld( 0, p2 );
        pix1v = vec_u8_to_s16_h( pix1v8 );
        pix2v = vec_u8_to_s16_h( pix2v8 );
        tmp[j] = vec_sub( pix1v, pix2v );
        p1 += FENC_STRIDE;
        p2 += FDEC_STRIDE;
    }
    diff[i] = vec_add( tmp[0], tmp[1] );
    diff[i] = vec_add( diff[i], tmp[2] );
    diff[i] = vec_add( diff[i], tmp[3] );
}

void x264_sub8x8_dct_dc_altivec( int16_t dct[4], uint8_t *pix1, uint8_t *pix2 )
{
    vec_s16_t diff[2], tmp;
    vec_s32_t sum[2];
    vec_s32_t zero32 = vec_splat_s32(0);
    vec_u8_t mask = { 0x00, 0x01, 0x00, 0x01, 0x04, 0x05, 0x04, 0x05,
                      0x02, 0x03, 0x02, 0x03, 0x06, 0x07, 0x06, 0x07 };

    pix_diff( &pix1[0], &pix2[0], diff, 0 );
    pix_diff( &pix1[4*FENC_STRIDE], &pix2[4*FDEC_STRIDE], diff, 1 );

    sum[0] = vec_sum4s( diff[0], zero32 );
    sum[1] = vec_sum4s( diff[1], zero32 );
    diff[0] = vec_packs( sum[0], sum[1] );
    sum[0] = vec_sum4s( diff[0], zero32 );
    diff[0] = vec_packs( sum[0], zero32 );

    diff[0] = vec_perm( diff[0], diff[0], mask ); // 0 0 2 2 1 1 3 3
    tmp = xxpermdi( diff[0], diff[0], 2 );        // 1 1 3 3 0 0 2 2
    diff[1] = vec_add( diff[0], tmp );            // 0+1 0+1 2+3 2+3
    diff[0] = vec_sub( diff[0], tmp );            // 0-1 0-1 2-3 2-3
    tmp = vec_mergeh( diff[1], diff[0] );         // 0+1 0-1 0+1 0-1 2+3 2-3 2+3 2-3
    diff[0] = xxpermdi( tmp, tmp, 2 );            // 2+3 2-3 2+3 2-3
    diff[1] = vec_add( tmp, diff[0] );            // 0+1+2+3 0-1+2+3
    diff[0] = vec_sub( tmp, diff[0] );            // 0+1-2-3 0-1-2+3
    diff[0] = vec_mergeh( diff[1], diff[0] );

    diff[1] = vec_ld( 0, dct );
    diff[0] = xxpermdi( diff[0], diff[1], 0 );
    vec_st( diff[0], 0, dct );
}

/* DCT8_1D unrolled by 8 in Altivec */
#define DCT8_1D_ALTIVEC( dct0v, dct1v, dct2v, dct3v, dct4v, dct5v, dct6v, dct7v ) \
{ \
    /* int s07 = SRC(0) + SRC(7);         */ \
    vec_s16_t s07v = vec_add( dct0v, dct7v); \
    /* int s16 = SRC(1) + SRC(6);         */ \
    vec_s16_t s16v = vec_add( dct1v, dct6v); \
    /* int s25 = SRC(2) + SRC(5);         */ \
    vec_s16_t s25v = vec_add( dct2v, dct5v); \
    /* int s34 = SRC(3) + SRC(4);         */ \
    vec_s16_t s34v = vec_add( dct3v, dct4v); \
\
    /* int a0 = s07 + s34;                */ \
    vec_s16_t a0v = vec_add(s07v, s34v);     \
    /* int a1 = s16 + s25;                */ \
    vec_s16_t a1v = vec_add(s16v, s25v);     \
    /* int a2 = s07 - s34;                */ \
    vec_s16_t a2v = vec_sub(s07v, s34v);     \
    /* int a3 = s16 - s25;                */ \
    vec_s16_t a3v = vec_sub(s16v, s25v);     \
\
    /* int d07 = SRC(0) - SRC(7);         */ \
    vec_s16_t d07v = vec_sub( dct0v, dct7v); \
    /* int d16 = SRC(1) - SRC(6);         */ \
    vec_s16_t d16v = vec_sub( dct1v, dct6v); \
    /* int d25 = SRC(2) - SRC(5);         */ \
    vec_s16_t d25v = vec_sub( dct2v, dct5v); \
    /* int d34 = SRC(3) - SRC(4);         */ \
    vec_s16_t d34v = vec_sub( dct3v, dct4v); \
\
    /* int a4 = d16 + d25 + (d07 + (d07>>1)); */ \
    vec_s16_t a4v = vec_add( vec_add(d16v, d25v), vec_add(d07v, vec_sra(d07v, onev)) );\
    /* int a5 = d07 - d34 - (d25 + (d25>>1)); */ \
    vec_s16_t a5v = vec_sub( vec_sub(d07v, d34v), vec_add(d25v, vec_sra(d25v, onev)) );\
    /* int a6 = d07 + d34 - (d16 + (d16>>1)); */ \
    vec_s16_t a6v = vec_sub( vec_add(d07v, d34v), vec_add(d16v, vec_sra(d16v, onev)) );\
    /* int a7 = d16 - d25 + (d34 + (d34>>1)); */ \
    vec_s16_t a7v = vec_add( vec_sub(d16v, d25v), vec_add(d34v, vec_sra(d34v, onev)) );\
\
    /* DST(0) =  a0 + a1;                    */ \
    dct0v = vec_add( a0v, a1v );                \
    /* DST(1) =  a4 + (a7>>2);               */ \
    dct1v = vec_add( a4v, vec_sra(a7v, twov) ); \
    /* DST(2) =  a2 + (a3>>1);               */ \
    dct2v = vec_add( a2v, vec_sra(a3v, onev) ); \
    /* DST(3) =  a5 + (a6>>2);               */ \
    dct3v = vec_add( a5v, vec_sra(a6v, twov) ); \
    /* DST(4) =  a0 - a1;                    */ \
    dct4v = vec_sub( a0v, a1v );                \
    /* DST(5) =  a6 - (a5>>2);               */ \
    dct5v = vec_sub( a6v, vec_sra(a5v, twov) ); \
    /* DST(6) = (a2>>1) - a3 ;               */ \
    dct6v = vec_sub( vec_sra(a2v, onev), a3v ); \
    /* DST(7) = (a4>>2) - a7 ;               */ \
    dct7v = vec_sub( vec_sra(a4v, twov), a7v ); \
}


void x264_sub8x8_dct8_altivec( int16_t dct[64], uint8_t *pix1, uint8_t *pix2 )
{
    vec_u16_t onev = vec_splat_u16(1);
    vec_u16_t twov = vec_add( onev, onev );

    PREP_DIFF_8BYTEALIGNED;

    vec_s16_t dct0v, dct1v, dct2v, dct3v,
              dct4v, dct5v, dct6v, dct7v;

    VEC_DIFF_H_8BYTE_ALIGNED( pix1, FENC_STRIDE, pix2, FDEC_STRIDE, 8, dct0v );
    VEC_DIFF_H_8BYTE_ALIGNED( pix1, FENC_STRIDE, pix2, FDEC_STRIDE, 8, dct1v );
    VEC_DIFF_H_8BYTE_ALIGNED( pix1, FENC_STRIDE, pix2, FDEC_STRIDE, 8, dct2v );
    VEC_DIFF_H_8BYTE_ALIGNED( pix1, FENC_STRIDE, pix2, FDEC_STRIDE, 8, dct3v );

    VEC_DIFF_H_8BYTE_ALIGNED( pix1, FENC_STRIDE, pix2, FDEC_STRIDE, 8, dct4v );
    VEC_DIFF_H_8BYTE_ALIGNED( pix1, FENC_STRIDE, pix2, FDEC_STRIDE, 8, dct5v );
    VEC_DIFF_H_8BYTE_ALIGNED( pix1, FENC_STRIDE, pix2, FDEC_STRIDE, 8, dct6v );
    VEC_DIFF_H_8BYTE_ALIGNED( pix1, FENC_STRIDE, pix2, FDEC_STRIDE, 8, dct7v );

    DCT8_1D_ALTIVEC( dct0v, dct1v, dct2v, dct3v,
                     dct4v, dct5v, dct6v, dct7v );

    vec_s16_t dct_tr0v, dct_tr1v, dct_tr2v, dct_tr3v,
        dct_tr4v, dct_tr5v, dct_tr6v, dct_tr7v;

    VEC_TRANSPOSE_8(dct0v, dct1v, dct2v, dct3v,
                    dct4v, dct5v, dct6v, dct7v,
                    dct_tr0v, dct_tr1v, dct_tr2v, dct_tr3v,
                    dct_tr4v, dct_tr5v, dct_tr6v, dct_tr7v );

    DCT8_1D_ALTIVEC( dct_tr0v, dct_tr1v, dct_tr2v, dct_tr3v,
                     dct_tr4v, dct_tr5v, dct_tr6v, dct_tr7v );

    vec_st( dct_tr0v,  0,  dct );
    vec_st( dct_tr1v, 16,  dct );
    vec_st( dct_tr2v, 32,  dct );
    vec_st( dct_tr3v, 48,  dct );

    vec_st( dct_tr4v, 64,  dct );
    vec_st( dct_tr5v, 80,  dct );
    vec_st( dct_tr6v, 96,  dct );
    vec_st( dct_tr7v, 112, dct );
}

void x264_sub16x16_dct8_altivec( int16_t dct[4][64], uint8_t *pix1, uint8_t *pix2 )
{
    x264_sub8x8_dct8_altivec( dct[0], &pix1[0],               &pix2[0] );
    x264_sub8x8_dct8_altivec( dct[1], &pix1[8],               &pix2[8] );
    x264_sub8x8_dct8_altivec( dct[2], &pix1[8*FENC_STRIDE+0], &pix2[8*FDEC_STRIDE+0] );
    x264_sub8x8_dct8_altivec( dct[3], &pix1[8*FENC_STRIDE+8], &pix2[8*FDEC_STRIDE+8] );
}


/****************************************************************************
 * IDCT transform:
 ****************************************************************************/

#define ALTIVEC_STORE8_DC_SUM_CLIP(dest, dcv)                         \
{                                                                     \
    /* unaligned load */                                              \
    vec_u8_t dstv   = vec_vsx_ld( 0, dest );                          \
    vec_s16_t dcvsum = vec_adds( dcv, vec_u8_to_s16_h( dstv ) );      \
    vec_u8_t dcvsum8 = vec_packsu( dcvsum, vec_u8_to_s16_l( dstv ) ); \
    /* unaligned store */                                             \
    vec_vsx_st( dcvsum8, 0, dest );                                   \
}

void x264_add8x8_idct_dc_altivec( uint8_t *p_dst, int16_t dct[4] )
{
    vec_s16_t dcv0, dcv1;
    vec_s16_t v32 = vec_sl( vec_splat_s16( 8 ), vec_splat_u16( 2 ) );
    vec_u16_t v6 = vec_splat_u16( 6 );
    vec_s16_t dctv = vec_ld( 0, dct );
    vec_u8_t dstv0, dstv1, dstv2, dstv3, dstv4, dstv5, dstv6, dstv7;
    vec_s16_t dcvsum0, dcvsum1, dcvsum2, dcvsum3, dcvsum4, dcvsum5, dcvsum6, dcvsum7;
    vec_u8_t dcvsum8_0, dcvsum8_1, dcvsum8_2, dcvsum8_3, dcvsum8_4, dcvsum8_5, dcvsum8_6, dcvsum8_7;
    LOAD_ZERO;

    dctv = vec_sra( vec_add( dctv, v32 ), v6 );
    dcv1 = (vec_s16_t)vec_mergeh( dctv, dctv );
    dcv0 = (vec_s16_t)vec_mergeh( (vec_s32_t)dcv1, (vec_s32_t)dcv1 );
    dcv1 = (vec_s16_t)vec_mergel( (vec_s32_t)dcv1, (vec_s32_t)dcv1 );

    dstv0   = vec_vsx_ld( 0, p_dst );
    dstv4   = vec_vsx_ld( 0, p_dst + 4*FDEC_STRIDE );
    dstv1   = vec_vsx_ld( 0, p_dst + 1*FDEC_STRIDE );
    dstv5   = vec_vsx_ld( 0, p_dst + 4*FDEC_STRIDE + 1*FDEC_STRIDE );
    dstv2   = vec_vsx_ld( 0, p_dst + 2*FDEC_STRIDE);
    dstv6   = vec_vsx_ld( 0, p_dst + 4*FDEC_STRIDE + 2*FDEC_STRIDE );
    dstv3   = vec_vsx_ld( 0, p_dst + 3*FDEC_STRIDE);
    dstv7   = vec_vsx_ld( 0, p_dst + 4*FDEC_STRIDE + 3*FDEC_STRIDE );

    vec_s16_t s0 = vec_u8_to_s16_h( dstv0 );
    vec_s16_t s1 = vec_u8_to_s16_h( dstv4 );
    vec_s16_t s2 = vec_u8_to_s16_h( dstv1 );
    vec_s16_t s3 = vec_u8_to_s16_h( dstv5 );
    vec_s16_t s4 = vec_u8_to_s16_h( dstv2 );
    vec_s16_t s5 = vec_u8_to_s16_h( dstv6 );
    vec_s16_t s6 = vec_u8_to_s16_h( dstv3 );
    vec_s16_t s7 = vec_u8_to_s16_h( dstv7 );
    dcvsum0 = vec_adds( dcv0, s0 );
    dcvsum4 = vec_adds( dcv1, s1 );
    dcvsum1 = vec_adds( dcv0, s2 );
    dcvsum5 = vec_adds( dcv1, s3 );
    dcvsum2 = vec_adds( dcv0, s4 );
    dcvsum6 = vec_adds( dcv1, s5 );
    dcvsum3 = vec_adds( dcv0, s6 );
    dcvsum7 = vec_adds( dcv1, s7 );
    dcvsum8_0 = vec_packsu( dcvsum0, vec_u8_to_s16_l( dstv0 ) );
    dcvsum8_1 = vec_packsu( dcvsum1, vec_u8_to_s16_l( dstv1 ) );
    dcvsum8_2 = vec_packsu( dcvsum2, vec_u8_to_s16_l( dstv2 ) );
    dcvsum8_3 = vec_packsu( dcvsum3, vec_u8_to_s16_l( dstv3 ) );
    dcvsum8_4 = vec_packsu( dcvsum4, vec_u8_to_s16_l( dstv4 ) );
    dcvsum8_5 = vec_packsu( dcvsum5, vec_u8_to_s16_l( dstv5 ) );
    dcvsum8_6 = vec_packsu( dcvsum6, vec_u8_to_s16_l( dstv6 ) );
    dcvsum8_7 = vec_packsu( dcvsum7, vec_u8_to_s16_l( dstv7 ) );

    vec_vsx_st( dcvsum8_0, 0, p_dst );
    vec_vsx_st( dcvsum8_4, 0, p_dst + 4*FDEC_STRIDE );
    vec_vsx_st( dcvsum8_1, 0, p_dst + 1*FDEC_STRIDE );
    vec_vsx_st( dcvsum8_5, 0, p_dst + 4*FDEC_STRIDE + 1*FDEC_STRIDE );
    vec_vsx_st( dcvsum8_2, 0, p_dst + 2*FDEC_STRIDE );
    vec_vsx_st( dcvsum8_6, 0, p_dst + 4*FDEC_STRIDE + 2*FDEC_STRIDE );
    vec_vsx_st( dcvsum8_3, 0, p_dst + 3*FDEC_STRIDE );
    vec_vsx_st( dcvsum8_7, 0, p_dst + 4*FDEC_STRIDE + 3*FDEC_STRIDE );
}

#define LOAD16                                  \
    dstv0 = vec_ld( 0, p_dst );                 \
    dstv1 = vec_ld( 0, p_dst + 1*FDEC_STRIDE ); \
    dstv2 = vec_ld( 0, p_dst + 2*FDEC_STRIDE ); \
    dstv3 = vec_ld( 0, p_dst + 3*FDEC_STRIDE );

#define SUM16                                                 \
        dcvsum0 = vec_adds( dcv0, vec_u8_to_s16_h( dstv0 ) ); \
        dcvsum4 = vec_adds( dcv1, vec_u8_to_s16_l( dstv0 ) ); \
        dcvsum1 = vec_adds( dcv0, vec_u8_to_s16_h( dstv1 ) ); \
        dcvsum5 = vec_adds( dcv1, vec_u8_to_s16_l( dstv1 ) ); \
        dcvsum2 = vec_adds( dcv0, vec_u8_to_s16_h( dstv2 ) ); \
        dcvsum6 = vec_adds( dcv1, vec_u8_to_s16_l( dstv2 ) ); \
        dcvsum3 = vec_adds( dcv0, vec_u8_to_s16_h( dstv3 ) ); \
        dcvsum7 = vec_adds( dcv1, vec_u8_to_s16_l( dstv3 ) ); \
        dcvsum8_0 = vec_packsu( dcvsum0, dcvsum4 );           \
        dcvsum8_1 = vec_packsu( dcvsum1, dcvsum5 );           \
        dcvsum8_2 = vec_packsu( dcvsum2, dcvsum6 );           \
        dcvsum8_3 = vec_packsu( dcvsum3, dcvsum7 );

#define STORE16                                    \
    vec_st( dcvsum8_0, 0, p_dst );                 \
    vec_st( dcvsum8_1, 0, p_dst + 1*FDEC_STRIDE ); \
    vec_st( dcvsum8_2, 0, p_dst + 2*FDEC_STRIDE ); \
    vec_st( dcvsum8_3, 0, p_dst + 3*FDEC_STRIDE );

void x264_add16x16_idct_dc_altivec( uint8_t *p_dst, int16_t dct[16] )
{
    vec_s16_t dcv0, dcv1;
    vec_s16_t v32 = vec_sl( vec_splat_s16( 8 ), vec_splat_u16( 2 ) );
    vec_u16_t v6 = vec_splat_u16( 6 );
    vec_u8_t dstv0, dstv1, dstv2, dstv3;
    vec_s16_t dcvsum0, dcvsum1, dcvsum2, dcvsum3, dcvsum4, dcvsum5, dcvsum6, dcvsum7;
    vec_u8_t dcvsum8_0, dcvsum8_1, dcvsum8_2, dcvsum8_3;
    LOAD_ZERO;

    for( int i = 0; i < 2; i++ )
    {
        vec_s16_t dctv = vec_ld( 0, dct );

        dctv = vec_sra( vec_add( dctv, v32 ), v6 );
        dcv1 = (vec_s16_t)vec_mergeh( dctv, dctv );
        dcv0 = (vec_s16_t)vec_mergeh( (vec_s32_t)dcv1, (vec_s32_t)dcv1 );
        dcv1 = (vec_s16_t)vec_mergel( (vec_s32_t)dcv1, (vec_s32_t)dcv1 );
        LOAD16;
        SUM16;
        STORE16;

        p_dst += 4*FDEC_STRIDE;
        dcv1 = (vec_s16_t)vec_mergel( dctv, dctv );
        dcv0 = (vec_s16_t)vec_mergeh( (vec_s32_t)dcv1, (vec_s32_t)dcv1 );
        dcv1 = (vec_s16_t)vec_mergel( (vec_s32_t)dcv1, (vec_s32_t)dcv1 );
        LOAD16;
        SUM16;
        STORE16;

        dct += 8;
        p_dst += 4*FDEC_STRIDE;
    }
}

#define IDCT_1D_ALTIVEC(s0, s1, s2, s3,  d0, d1, d2, d3) \
{                                                        \
    /*        a0  = SRC(0) + SRC(2); */                  \
    vec_s16_t a0v = vec_add(s0, s2);                     \
    /*        a1  = SRC(0) - SRC(2); */                  \
    vec_s16_t a1v = vec_sub(s0, s2);                     \
    /*        a2  =           (SRC(1)>>1) - SRC(3); */   \
    vec_s16_t a2v = vec_sub(vec_sra(s1, onev), s3);      \
    /*        a3  =           (SRC(3)>>1) + SRC(1); */   \
    vec_s16_t a3v = vec_add(vec_sra(s3, onev), s1);      \
    /* DST(0,    a0 + a3); */                            \
    d0 = vec_add(a0v, a3v);                              \
    /* DST(1,    a1 + a2); */                            \
    d1 = vec_add(a1v, a2v);                              \
    /* DST(2,    a1 - a2); */                            \
    d2 = vec_sub(a1v, a2v);                              \
    /* DST(3,    a0 - a3); */                            \
    d3 = vec_sub(a0v, a3v);                              \
}

#define VEC_LOAD_U8_ADD_S16_STORE_U8(va)             \
    vdst_orig = vec_ld(0, dst);                      \
    vdst = vec_perm(vdst_orig, zero_u8v, vdst_mask); \
    vdst_ss = (vec_s16_t)vec_mergeh(zero_u8v, vdst); \
    va = vec_add(va, vdst_ss);                       \
    va_u8 = vec_s16_to_u8(va);                       \
    va_u32 = vec_splat((vec_u32_t)va_u8, 0);         \
    vec_ste(va_u32, element, (uint32_t*)dst);

#define ALTIVEC_STORE4_SUM_CLIP(dest, idctv)                    \
{                                                               \
    /* unaligned load */                                        \
    vec_u8_t dstv = vec_vsx_ld(0, dest);                        \
    vec_s16_t idct_sh6 = vec_sra(idctv, sixv);                  \
    vec_u16_t dst16 = vec_u8_to_u16_h(dstv);                    \
    vec_s16_t idstsum = vec_adds(idct_sh6, (vec_s16_t)dst16);   \
    vec_u8_t idstsum8 = vec_s16_to_u8(idstsum);                 \
    /* unaligned store */                                       \
    vec_u32_t bodyv = vec_splat((vec_u32_t)idstsum8, 0);        \
    int element = ((unsigned long)dest & 0xf) >> 2;             \
    vec_ste(bodyv, element, (uint32_t *)dest);                  \
}

void x264_add4x4_idct_altivec( uint8_t *dst, int16_t dct[16] )
{
    vec_u16_t onev = vec_splat_u16(1);

    dct[0] += 32; // rounding for the >>6 at the end

    vec_s16_t s0, s1, s2, s3;

    s0 = vec_ld( 0x00, dct );
    s1 = vec_sld( s0, s0, 8 );
    s2 = vec_ld( 0x10, dct );
    s3 = vec_sld( s2, s2, 8 );

    vec_s16_t d0, d1, d2, d3;
    IDCT_1D_ALTIVEC( s0, s1, s2, s3, d0, d1, d2, d3 );

    vec_s16_t tr0, tr1, tr2, tr3;

    VEC_TRANSPOSE_4( d0, d1, d2, d3, tr0, tr1, tr2, tr3 );

    vec_s16_t idct0, idct1, idct2, idct3;
    IDCT_1D_ALTIVEC( tr0, tr1, tr2, tr3, idct0, idct1, idct2, idct3 );

    vec_u16_t sixv = vec_splat_u16(6);
    LOAD_ZERO;

    ALTIVEC_STORE4_SUM_CLIP( &dst[0*FDEC_STRIDE], idct0 );
    ALTIVEC_STORE4_SUM_CLIP( &dst[1*FDEC_STRIDE], idct1 );
    ALTIVEC_STORE4_SUM_CLIP( &dst[2*FDEC_STRIDE], idct2 );
    ALTIVEC_STORE4_SUM_CLIP( &dst[3*FDEC_STRIDE], idct3 );
}

void x264_add8x8_idct_altivec( uint8_t *p_dst, int16_t dct[4][16] )
{
    x264_add4x4_idct_altivec( &p_dst[0],               dct[0] );
    x264_add4x4_idct_altivec( &p_dst[4],               dct[1] );
    x264_add4x4_idct_altivec( &p_dst[4*FDEC_STRIDE+0], dct[2] );
    x264_add4x4_idct_altivec( &p_dst[4*FDEC_STRIDE+4], dct[3] );
}

void x264_add16x16_idct_altivec( uint8_t *p_dst, int16_t dct[16][16] )
{
    x264_add8x8_idct_altivec( &p_dst[0],               &dct[0] );
    x264_add8x8_idct_altivec( &p_dst[8],               &dct[4] );
    x264_add8x8_idct_altivec( &p_dst[8*FDEC_STRIDE+0], &dct[8] );
    x264_add8x8_idct_altivec( &p_dst[8*FDEC_STRIDE+8], &dct[12] );
}

#define IDCT8_1D_ALTIVEC(s0, s1, s2, s3, s4, s5, s6, s7,  d0, d1, d2, d3, d4, d5, d6, d7)\
{\
    /*        a0  = SRC(0) + SRC(4); */ \
    vec_s16_t a0v = vec_add(s0, s4);    \
    /*        a2  = SRC(0) - SRC(4); */ \
    vec_s16_t a2v = vec_sub(s0, s4);    \
    /*        a4  =           (SRC(2)>>1) - SRC(6); */ \
    vec_s16_t a4v = vec_sub(vec_sra(s2, onev), s6);    \
    /*        a6  =           (SRC(6)>>1) + SRC(2); */ \
    vec_s16_t a6v = vec_add(vec_sra(s6, onev), s2);    \
    /*        b0  =         a0 + a6; */ \
    vec_s16_t b0v = vec_add(a0v, a6v);  \
    /*        b2  =         a2 + a4; */ \
    vec_s16_t b2v = vec_add(a2v, a4v);  \
    /*        b4  =         a2 - a4; */ \
    vec_s16_t b4v = vec_sub(a2v, a4v);  \
    /*        b6  =         a0 - a6; */ \
    vec_s16_t b6v = vec_sub(a0v, a6v);  \
    /* a1 =  SRC(5) - SRC(3) - SRC(7) - (SRC(7)>>1); */ \
    /*        a1 =             (SRC(5)-SRC(3)) -  (SRC(7)  +  (SRC(7)>>1)); */ \
    vec_s16_t a1v = vec_sub( vec_sub(s5, s3), vec_add(s7, vec_sra(s7, onev)) );\
    /* a3 =  SRC(7) + SRC(1) - SRC(3) - (SRC(3)>>1); */ \
    /*        a3 =             (SRC(7)+SRC(1)) -  (SRC(3)  +  (SRC(3)>>1)); */ \
    vec_s16_t a3v = vec_sub( vec_add(s7, s1), vec_add(s3, vec_sra(s3, onev)) );\
    /* a5 =  SRC(7) - SRC(1) + SRC(5) + (SRC(5)>>1); */ \
    /*        a5 =             (SRC(7)-SRC(1)) +   SRC(5) +   (SRC(5)>>1); */  \
    vec_s16_t a5v = vec_add( vec_sub(s7, s1), vec_add(s5, vec_sra(s5, onev)) );\
    /*        a7 =                SRC(5)+SRC(3) +  SRC(1) +   (SRC(1)>>1); */  \
    vec_s16_t a7v = vec_add( vec_add(s5, s3), vec_add(s1, vec_sra(s1, onev)) );\
    /*        b1 =                  (a7>>2)  +  a1; */  \
    vec_s16_t b1v = vec_add( vec_sra(a7v, twov), a1v);  \
    /*        b3 =          a3 +        (a5>>2); */     \
    vec_s16_t b3v = vec_add(a3v, vec_sra(a5v, twov));   \
    /*        b5 =                  (a3>>2)  -   a5; */ \
    vec_s16_t b5v = vec_sub( vec_sra(a3v, twov), a5v);  \
    /*        b7 =           a7 -        (a1>>2); */    \
    vec_s16_t b7v = vec_sub( a7v, vec_sra(a1v, twov));  \
    /* DST(0,    b0 + b7); */ \
    d0 = vec_add(b0v, b7v); \
    /* DST(1,    b2 + b5); */ \
    d1 = vec_add(b2v, b5v); \
    /* DST(2,    b4 + b3); */ \
    d2 = vec_add(b4v, b3v); \
    /* DST(3,    b6 + b1); */ \
    d3 = vec_add(b6v, b1v); \
    /* DST(4,    b6 - b1); */ \
    d4 = vec_sub(b6v, b1v); \
    /* DST(5,    b4 - b3); */ \
    d5 = vec_sub(b4v, b3v); \
    /* DST(6,    b2 - b5); */ \
    d6 = vec_sub(b2v, b5v); \
    /* DST(7,    b0 - b7); */ \
    d7 = vec_sub(b0v, b7v); \
}

#define ALTIVEC_STORE_SUM_CLIP(dest, idctv)                             \
{                                                                       \
    vec_s16_t idct_sh6 = vec_sra( idctv, sixv );                        \
    /* unaligned load */                                                \
    vec_u8_t dstv   = vec_vsx_ld( 0, dest );                            \
    vec_s16_t idstsum = vec_adds( idct_sh6, vec_u8_to_s16_h( dstv ) );  \
    vec_u8_t idstsum8 = vec_packsu( idstsum, vec_u8_to_s16_l( dstv ) ); \
    /* unaligned store */                                               \
    vec_vsx_st( idstsum8, 0, dest );                                    \
}

void x264_add8x8_idct8_altivec( uint8_t *dst, int16_t dct[64] )
{
    vec_u16_t onev = vec_splat_u16(1);
    vec_u16_t twov = vec_splat_u16(2);

    dct[0] += 32; // rounding for the >>6 at the end

    vec_s16_t s0, s1, s2, s3, s4, s5, s6, s7;

    s0 = vec_ld(0x00, dct);
    s1 = vec_ld(0x10, dct);
    s2 = vec_ld(0x20, dct);
    s3 = vec_ld(0x30, dct);
    s4 = vec_ld(0x40, dct);
    s5 = vec_ld(0x50, dct);
    s6 = vec_ld(0x60, dct);
    s7 = vec_ld(0x70, dct);

    vec_s16_t d0, d1, d2, d3, d4, d5, d6, d7;
    IDCT8_1D_ALTIVEC(s0, s1, s2, s3, s4, s5, s6, s7,  d0, d1, d2, d3, d4, d5, d6, d7);

    vec_s16_t tr0, tr1, tr2, tr3, tr4, tr5, tr6, tr7;

    VEC_TRANSPOSE_8( d0,  d1,  d2,  d3,  d4,  d5,  d6, d7,
                    tr0, tr1, tr2, tr3, tr4, tr5, tr6, tr7);

    vec_s16_t idct0, idct1, idct2, idct3, idct4, idct5, idct6, idct7;
    IDCT8_1D_ALTIVEC(tr0,     tr1,   tr2,   tr3,   tr4,   tr5,   tr6,   tr7,
                     idct0, idct1, idct2, idct3, idct4, idct5, idct6, idct7);

    vec_u16_t sixv = vec_splat_u16(6);
    LOAD_ZERO;

    ALTIVEC_STORE_SUM_CLIP(&dst[0*FDEC_STRIDE], idct0);
    ALTIVEC_STORE_SUM_CLIP(&dst[1*FDEC_STRIDE], idct1);
    ALTIVEC_STORE_SUM_CLIP(&dst[2*FDEC_STRIDE], idct2);
    ALTIVEC_STORE_SUM_CLIP(&dst[3*FDEC_STRIDE], idct3);
    ALTIVEC_STORE_SUM_CLIP(&dst[4*FDEC_STRIDE], idct4);
    ALTIVEC_STORE_SUM_CLIP(&dst[5*FDEC_STRIDE], idct5);
    ALTIVEC_STORE_SUM_CLIP(&dst[6*FDEC_STRIDE], idct6);
    ALTIVEC_STORE_SUM_CLIP(&dst[7*FDEC_STRIDE], idct7);
}

void x264_add16x16_idct8_altivec( uint8_t *dst, int16_t dct[4][64] )
{
    x264_add8x8_idct8_altivec( &dst[0],               dct[0] );
    x264_add8x8_idct8_altivec( &dst[8],               dct[1] );
    x264_add8x8_idct8_altivec( &dst[8*FDEC_STRIDE+0], dct[2] );
    x264_add8x8_idct8_altivec( &dst[8*FDEC_STRIDE+8], dct[3] );
}

void x264_zigzag_scan_4x4_frame_altivec( int16_t level[16], int16_t dct[16] )
{
    vec_s16_t dct0v, dct1v;
    vec_s16_t tmp0v, tmp1v;

    dct0v = vec_ld(0x00, dct);
    dct1v = vec_ld(0x10, dct);

    const vec_u8_t sel0 = (vec_u8_t) CV(0,1,8,9,2,3,4,5,10,11,16,17,24,25,18,19);
    const vec_u8_t sel1 = (vec_u8_t) CV(12,13,6,7,14,15,20,21,26,27,28,29,22,23,30,31);

    tmp0v = vec_perm( dct0v, dct1v, sel0 );
    tmp1v = vec_perm( dct0v, dct1v, sel1 );

    vec_st( tmp0v, 0x00, level );
    vec_st( tmp1v, 0x10, level );
}

void x264_zigzag_scan_4x4_field_altivec( int16_t level[16], int16_t dct[16] )
{
    vec_s16_t dct0v, dct1v;
    vec_s16_t tmp0v, tmp1v;

    dct0v = vec_ld(0x00, dct);
    dct1v = vec_ld(0x10, dct);

    const vec_u8_t sel0 = (vec_u8_t) CV(0,1,2,3,8,9,4,5,6,7,10,11,12,13,14,15);

    tmp0v = vec_perm( dct0v, dct1v, sel0 );
    tmp1v = dct1v;

    vec_st( tmp0v, 0x00, level );
    vec_st( tmp1v, 0x10, level );
}

void x264_zigzag_scan_8x8_frame_altivec( int16_t level[64], int16_t dct[64] )
{
    vec_s16_t tmpv[6];
    vec_s16_t dct0v = vec_ld( 0*16, dct );
    vec_s16_t dct1v = vec_ld( 1*16, dct );
    vec_s16_t dct2v = vec_ld( 2*16, dct );
    vec_s16_t dct3v = vec_ld( 3*16, dct );
    vec_s16_t dct4v = vec_ld( 4*16, dct );
    vec_s16_t dct5v = vec_ld( 5*16, dct );
    vec_s16_t dct6v = vec_ld( 6*16, dct );
    vec_s16_t dct7v = vec_ld( 7*16, dct );

    const vec_u8_t mask1[14] = {
        { 0x00, 0x01, 0x02, 0x03, 0x12, 0x13, 0x14, 0x15, 0x0A, 0x0B, 0x04, 0x05, 0x06, 0x07, 0x0C, 0x0D },
        { 0x0A, 0x0B, 0x0C, 0x0D, 0x00, 0x00, 0x0E, 0x0F, 0x00, 0x00, 0x00, 0x00, 0x10, 0x11, 0x12, 0x13 },
        { 0x00, 0x01, 0x02, 0x03, 0x18, 0x19, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F },
        { 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x18, 0x19, 0x16, 0x17, 0x0C, 0x0D, 0x0E, 0x0F },
        { 0x00, 0x00, 0x14, 0x15, 0x18, 0x19, 0x02, 0x03, 0x04, 0x05, 0x08, 0x09, 0x06, 0x07, 0x12, 0x13 },
        { 0x12, 0x13, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F },
        { 0x1A, 0x1B, 0x10, 0x11, 0x08, 0x09, 0x04, 0x05, 0x02, 0x03, 0x0C, 0x0D, 0x14, 0x15, 0x18, 0x19 },
        { 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x0A, 0x0B },
        { 0x00, 0x01, 0x02, 0x03, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 0x06, 0x07, 0x04, 0x05, 0x08, 0x09 },
        { 0x00, 0x11, 0x16, 0x17, 0x18, 0x19, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x1A, 0x1B },
        { 0x02, 0x03, 0x18, 0x19, 0x16, 0x17, 0x1A, 0x1B, 0x1C, 0x1D, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09 },
        { 0x08, 0x09, 0x0A, 0x0B, 0x06, 0x07, 0x0E, 0x0F, 0x10, 0x11, 0x00, 0x00, 0x12, 0x13, 0x14, 0x15 },
        { 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x16, 0x17, 0x0C, 0x0D, 0x0E, 0x0F },
        { 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 0x08, 0x09, 0x06, 0x07, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F }
    };

    tmpv[0] = vec_mergeh( dct0v, dct1v );
    tmpv[1] = vec_mergeh( dct2v, dct3v );
    tmpv[2] = (vec_s16_t)vec_mergeh( (vec_s32_t)tmpv[0], (vec_s32_t)tmpv[1] );
    tmpv[3] = vec_perm( tmpv[2], dct0v, mask1[0] );
    vec_st( tmpv[3], 0*16, level );

    tmpv[4] = vec_mergeh( dct4v, dct5v );
    tmpv[3] = vec_perm( tmpv[0], tmpv[4], mask1[1] );
    tmpv[3] = vec_perm( tmpv[3], dct0v, mask1[2] );
    tmpv[3] = vec_perm( tmpv[3], tmpv[1], mask1[3] );
    vec_st( tmpv[3], 1*16, level );

    tmpv[3] = vec_mergel( dct0v, dct1v );
    tmpv[1] = vec_mergel( tmpv[1], dct2v );
    tmpv[5] = vec_perm( tmpv[3], tmpv[1], mask1[4] );
    tmpv[5] = vec_perm( tmpv[5], dct4v, mask1[5] );
    vec_st( tmpv[5], 2*16, level );

    tmpv[2] = vec_mergeh( dct5v, dct6v );
    tmpv[5] = vec_mergeh( tmpv[2], dct7v );
    tmpv[4] = vec_mergel( tmpv[4], tmpv[1] );
    tmpv[0] = vec_perm( tmpv[5], tmpv[4], mask1[6] );
    vec_st( tmpv[0], 3*16, level );

    tmpv[1] = vec_mergel( dct2v, dct3v );
    tmpv[0] = vec_mergel( dct4v, dct5v );
    tmpv[4] = vec_perm( tmpv[1], tmpv[0], mask1[7] );
    tmpv[3] = vec_perm( tmpv[4], tmpv[3], mask1[8] );
    vec_st( tmpv[3], 4*16, level );

    tmpv[3] = vec_mergeh( dct6v, dct7v );
    tmpv[2] = vec_mergel( dct3v, dct4v );
    tmpv[2] = vec_perm( tmpv[2], dct5v, mask1[9] );
    tmpv[3] = vec_perm( tmpv[2], tmpv[3], mask1[10] );
    vec_st( tmpv[3], 5*16, level );

    tmpv[1] = vec_mergel( tmpv[1], tmpv[2] );
    tmpv[2] = vec_mergel( dct6v, dct7v );
    tmpv[1] = vec_perm( tmpv[1], tmpv[2], mask1[11] );
    tmpv[1] = vec_perm( tmpv[1], dct7v, mask1[12] );
    vec_st( tmpv[1], 6*16, level );

    tmpv[2] = vec_perm( tmpv[2], tmpv[0], mask1[13] );
    vec_st( tmpv[2], 7*16, level );
}

void x264_zigzag_interleave_8x8_cavlc_altivec( int16_t *dst, int16_t *src, uint8_t *nnz )
{
    vec_s16_t tmpv[8];
    vec_s16_t merge[2];
    vec_s16_t permv[3];
    vec_s16_t orv[4];
    vec_s16_t src0v = vec_ld( 0*16, src );
    vec_s16_t src1v = vec_ld( 1*16, src );
    vec_s16_t src2v = vec_ld( 2*16, src );
    vec_s16_t src3v = vec_ld( 3*16, src );
    vec_s16_t src4v = vec_ld( 4*16, src );
    vec_s16_t src5v = vec_ld( 5*16, src );
    vec_s16_t src6v = vec_ld( 6*16, src );
    vec_s16_t src7v = vec_ld( 7*16, src );
    vec_u8_t pack;
    vec_u8_t nnzv = vec_vsx_ld( 0, nnz );
    vec_u8_t shift = vec_splat_u8( 7 );
    LOAD_ZERO;

    const vec_u8_t mask[3] = {
        { 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17 },
        { 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F },
        { 0x10, 0x11, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x12, 0x13, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F }
    };

    tmpv[0] = vec_mergeh( src0v, src1v );
    tmpv[1] = vec_mergel( src0v, src1v );

    tmpv[2] = vec_mergeh( src2v, src3v );
    tmpv[3] = vec_mergel( src2v, src3v );

    tmpv[4] = vec_mergeh( src4v, src5v );
    tmpv[5] = vec_mergel( src4v, src5v );

    tmpv[6] = vec_mergeh( src6v, src7v );
    tmpv[7] = vec_mergel( src6v, src7v );

    merge[0] = vec_mergeh( tmpv[0], tmpv[1] );
    merge[1] = vec_mergeh( tmpv[2], tmpv[3] );
    permv[0] = vec_perm( merge[0], merge[1], mask[0] );
    permv[1] = vec_perm( merge[0], merge[1], mask[1] );
    vec_st( permv[0], 0*16, dst );

    merge[0] = vec_mergeh( tmpv[4], tmpv[5] );
    merge[1] = vec_mergeh( tmpv[6], tmpv[7] );
    permv[0] = vec_perm( merge[0], merge[1], mask[0] );
    permv[2] = vec_perm( merge[0], merge[1], mask[1] );
    vec_st( permv[0], 1*16, dst );
    vec_st( permv[1], 2*16, dst );
    vec_st( permv[2], 3*16, dst );

    merge[0] = vec_mergel( tmpv[0], tmpv[1] );
    merge[1] = vec_mergel( tmpv[2], tmpv[3] );
    permv[0] = vec_perm( merge[0], merge[1], mask[0] );
    permv[1] = vec_perm( merge[0], merge[1], mask[1] );
    vec_st( permv[0], 4*16, dst );

    merge[0] = vec_mergel( tmpv[4], tmpv[5] );
    merge[1] = vec_mergel( tmpv[6], tmpv[7] );
    permv[0] = vec_perm( merge[0], merge[1], mask[0] );
    permv[2] = vec_perm( merge[0], merge[1], mask[1] );
    vec_st( permv[0], 5*16, dst );
    vec_st( permv[1], 6*16, dst );
    vec_st( permv[2], 7*16, dst );

    orv[0] = vec_or( src0v, src1v );
    orv[1] = vec_or( src2v, src3v );
    orv[2] = vec_or( src4v, src5v );
    orv[3] = vec_or( src6v, src7v );

    permv[0] = vec_or( orv[0], orv[1] );
    permv[1] = vec_or( orv[2], orv[3] );
    permv[0] = vec_or( permv[0], permv[1] );

    permv[1] = vec_perm( permv[0], permv[0], mask[1] );
    permv[0] = vec_or( permv[0], permv[1] );

    pack = (vec_u8_t)vec_packs( permv[0], permv[0] );
    pack = (vec_u8_t)vec_cmpeq( pack, zerov );
    pack = vec_nor( pack, zerov );
    pack = vec_sr( pack, shift );
    nnzv = vec_perm( nnzv, pack, mask[2] );
    vec_st( nnzv, 0, nnz );
}
#endif // !HIGH_BIT_DEPTH

