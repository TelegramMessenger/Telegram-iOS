/*****************************************************************************
 * mc.c: ppc motion compensation
 *****************************************************************************
 * Copyright (C) 2003-2022 x264 project
 *
 * Authors: Eric Petit <eric.petit@lapsus.org>
 *          Guillaume Poirier <gpoirier@mplayerhq.hu>
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
#include "mc.h"

#if !HIGH_BIT_DEPTH
typedef void (*pf_mc_t)( uint8_t *src, intptr_t i_src,
                         uint8_t *dst, intptr_t i_dst, int i_height );

static inline void pixel_avg2_w4_altivec( uint8_t *dst,  intptr_t i_dst,
                                          uint8_t *src1, intptr_t i_src1,
                                          uint8_t *src2, int i_height )
{
    for( int y = 0; y < i_height; y++ )
    {
#ifndef __POWER9_VECTOR__
        for( int x = 0; x < 4; x++ )
            dst[x] = ( src1[x] + src2[x] + 1 ) >> 1;
#else
        vec_u8_t s1 = vec_vsx_ld( 0, src1 );
        vec_u8_t s2 = vec_vsx_ld( 0, src2 );
        vec_u8_t avg = vec_avg( s1, s2 );

        vec_xst_len( avg, dst, 4 );
#endif
        dst  += i_dst;
        src1 += i_src1;
        src2 += i_src1;
    }
}

static inline void pixel_avg2_w8_altivec( uint8_t *dst,  intptr_t i_dst,
                                          uint8_t *src1, intptr_t i_src1,
                                          uint8_t *src2, int i_height )
{
    vec_u8_t src1v, src2v;

    for( int y = 0; y < i_height; y++ )
    {
        src1v = vec_vsx_ld( 0, src1 );
        src2v = vec_vsx_ld( 0, src2 );
        src1v = vec_avg( src1v, src2v );

        VEC_STORE8(src1v, dst);

        dst  += i_dst;
        src1 += i_src1;
        src2 += i_src1;
    }
}

static inline void pixel_avg2_w16_altivec( uint8_t *dst,  intptr_t i_dst,
                                           uint8_t *src1, intptr_t i_src1,
                                           uint8_t *src2, int i_height )
{
    vec_u8_t src1v, src2v;

    for( int y = 0; y < i_height; y++ )
    {
        src1v = vec_vsx_ld( 0, src1 );
        src2v = vec_vsx_ld( 0, src2 );
        src1v = vec_avg( src1v, src2v );
        vec_st(src1v, 0, dst);

        dst  += i_dst;
        src1 += i_src1;
        src2 += i_src1;
    }
}

static inline void pixel_avg2_w20_altivec( uint8_t *dst,  intptr_t i_dst,
                                           uint8_t *src1, intptr_t i_src1,
                                           uint8_t *src2, int i_height )
{
    pixel_avg2_w16_altivec(dst, i_dst, src1, i_src1, src2, i_height);
    pixel_avg2_w4_altivec(dst+16, i_dst, src1+16, i_src1, src2+16, i_height);
}

/* mc_copy: plain c */

#ifndef __POWER9_VECTOR__
#define tiny_copy( d, s, l ) memcpy( d, s, l )
#else
#define tiny_copy( d, s, l ) vec_xst_len( vec_vsx_ld( 0, s ), d, l )
#endif

#define MC_COPY( name, a )                                \
static void name( uint8_t *dst, intptr_t i_dst,           \
                  uint8_t *src, intptr_t i_src, int i_height ) \
{                                                         \
    int y;                                                \
    for( y = 0; y < i_height; y++ )                       \
    {                                                     \
        memcpy( dst, src, a );                            \
        src += i_src;                                     \
        dst += i_dst;                                     \
    }                                                     \
}
MC_COPY( mc_copy_w4_altivec,  4  )
MC_COPY( mc_copy_w8_altivec,  8  )

static void mc_copy_w16_altivec( uint8_t *dst, intptr_t i_dst,
                                 uint8_t *src, intptr_t i_src, int i_height )
{
    vec_u8_t cpyV;

    for( int y = 0; y < i_height; y++ )
    {
        cpyV = vec_vsx_ld( 0, src );
        vec_st(cpyV, 0, dst);

        src += i_src;
        dst += i_dst;
    }
}


static void mc_copy_w16_aligned_altivec( uint8_t *dst, intptr_t i_dst,
                                         uint8_t *src, intptr_t i_src, int i_height )
{
    for( int y = 0; y < i_height; ++y )
    {
        vec_u8_t cpyV = vec_ld( 0, src );
        vec_st(cpyV, 0, dst);

        src += i_src;
        dst += i_dst;
    }
}

#define x264_plane_copy_swap_core_altivec x264_template(plane_copy_swap_core_altivec)
void x264_plane_copy_swap_core_altivec( uint8_t *dst, intptr_t i_dst,
                                        uint8_t *src, intptr_t i_src, int w, int h )
{
    const vec_u8_t mask = { 0x01, 0x00, 0x03, 0x02, 0x05, 0x04, 0x07, 0x06, 0x09, 0x08, 0x0B, 0x0A, 0x0D, 0x0C, 0x0F, 0x0E };

    for( int y = 0; y < h; y++, dst += i_dst, src += i_src )
        for( int x = 0; x < 2 * w; x += 16 )
        {
            vec_u8_t srcv = vec_vsx_ld( x, src );
            vec_u8_t dstv = vec_perm( srcv, srcv, mask );

            vec_vsx_st( dstv, x, dst );
        }
}

#define x264_plane_copy_interleave_core_altivec x264_template(plane_copy_interleave_core_altivec)
void x264_plane_copy_interleave_core_altivec( uint8_t *dst, intptr_t i_dst,
                                              uint8_t *srcu, intptr_t i_srcu,
                                              uint8_t *srcv, intptr_t i_srcv, int w, int h )
{
    for( int y = 0; y < h; y++, dst += i_dst, srcu += i_srcu, srcv += i_srcv )
        for( int x = 0; x < w; x += 16 )
        {
            vec_u8_t srcvv = vec_vsx_ld( x, srcv );
            vec_u8_t srcuv = vec_vsx_ld( x, srcu );
            vec_u8_t dstv1 = vec_mergeh( srcuv, srcvv );
            vec_u8_t dstv2 = vec_mergel( srcuv, srcvv );

            vec_vsx_st( dstv1, 2 * x, dst );
            vec_vsx_st( dstv2, 2 * x + 16, dst );
        }
}

void x264_store_interleave_chroma_altivec( uint8_t *dst, intptr_t i_dst,
                                           uint8_t *srcu, uint8_t *srcv, int height )
{
    for( int y = 0; y < height; y++, dst += i_dst, srcu += FDEC_STRIDE, srcv += FDEC_STRIDE )
    {
        vec_u8_t srcvv = vec_vsx_ld( 0, srcv );
        vec_u8_t srcuv = vec_vsx_ld( 0, srcu );
        vec_u8_t dstv = vec_mergeh( srcuv, srcvv );

        vec_vsx_st(dstv, 0, dst);
    }
}

void x264_plane_copy_deinterleave_altivec( uint8_t *dstu, intptr_t i_dstu,
                                           uint8_t *dstv, intptr_t i_dstv,
                                           uint8_t *src, intptr_t i_src, int w, int h )
{
    const vec_u8_t mask[2] = {
        { 0x00, 0x02, 0x04, 0x06, 0x08, 0x0A, 0x0C, 0x0E, 0x10, 0x12, 0x14, 0x16, 0x18, 0x1A, 0x1C, 0x1E },
        { 0x01, 0x03, 0x05, 0x07, 0x09, 0x0B, 0x0D, 0x0F, 0x11, 0x13, 0x15, 0x17, 0x19, 0x1B, 0x1D, 0x1F }
    };
    for( int y = 0; y < h; y++, dstu += i_dstu, dstv += i_dstv, src += i_src )
    {
        for( int x = 0; x < w; x += 16 )
        {
            vec_u8_t srcv1 = vec_vsx_ld( 2 * x, src );
            vec_u8_t srcv2 = vec_vsx_ld( 2 * x + 16, src );
            vec_u8_t dstuv = vec_perm( srcv1, srcv2, mask[0] );
            vec_u8_t dstvv = vec_perm( srcv1, srcv2, mask[1] );

            vec_vsx_st( dstuv, x, dstu );
            vec_vsx_st( dstvv, x, dstv );
        }
    }
}

static void load_deinterleave_chroma_fenc_altivec( uint8_t *dst, uint8_t *src, intptr_t i_src, int height )
{
    const vec_u8_t mask = { 0x00, 0x02, 0x04, 0x06, 0x08, 0x0A, 0x0C, 0x0E, 0x01, 0x03, 0x05, 0x07, 0x09, 0x0B, 0x0D, 0x0F };

    for( int y = 0; y < height; y += 2, dst += 2*FENC_STRIDE, src += 2*i_src )
    {
        vec_u8_t src0 = vec_ld( 0, src );
        vec_u8_t src1 = vec_ld( i_src, src );

        vec_st( vec_perm( src0, src0, mask ), 0*FENC_STRIDE, dst );
        vec_st( vec_perm( src1, src1, mask ), 1*FENC_STRIDE, dst );
    }
}

#if HAVE_VSX
void x264_plane_copy_deinterleave_rgb_altivec( uint8_t *dsta, intptr_t i_dsta,
                                               uint8_t *dstb, intptr_t i_dstb,
                                               uint8_t *dstc, intptr_t i_dstc,
                                               uint8_t *src, intptr_t i_src,
                                               int pw, int w, int h )
{
    if( pw == 3 )
    {
        const vec_u8_t mask[4] = {
            { 0x00, 0x03, 0x06, 0x09, 0x0C, 0x0F, 0x12, 0x15, 0x01, 0x04, 0x07, 0x0A, 0x0D, 0x10, 0x13, 0x16 },
            { 0x08, 0x0B, 0x0E, 0x11, 0x14, 0x17, 0x1A, 0x1D, 0x09, 0x0C, 0x0F, 0x12, 0x15, 0x18, 0x1B, 0x1E },
            { 0x02, 0x05, 0x08, 0x0B, 0x0E, 0x11, 0x14, 0x17, 0x1A, 0x1D, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF },
            { 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x10, 0x13, 0x16, 0x19, 0x1C, 0x1F }
        };

        for( int y = 0; y < h; y++, dsta += i_dsta, dstb += i_dstb, dstc += i_dstc, src += i_src )
        {
            for( int x = 0; x < w; x += 16 )
            {
                vec_u8_t srcv1 = vec_vsx_ld( 3 * x, src );
                vec_u8_t srcv2 = vec_vsx_ld( 3 * x + 16, src );
                vec_u8_t srcv3 = vec_vsx_ld( 3 * x + 32, src );
                vec_u64_t tmp1 = (vec_u64_t)vec_perm( srcv1, srcv2, mask[0] ); // a0  a1  a2  a3  a4  a5  a6  a7  b0  b1  b2  b3  b4  b5  b6  b7
                vec_u64_t tmp2 = (vec_u64_t)vec_perm( srcv2, srcv3, mask[1] ); // a8  a9  a10 a11 a12 a13 a14 a15 b8  b9  b10 b11 b12 b13 b14 b15
                vec_st( (vec_u8_t)vec_mergeh( tmp1, tmp2 ), x, dsta );
                vec_st( (vec_u8_t)vec_mergel( tmp1, tmp2 ), x, dstb );

                srcv1 = vec_perm( srcv1, srcv2, mask[2] );          // c0  c1  c2  c3  c4  c5  c6  c7  c8  c9
                srcv1 = vec_perm( srcv1, srcv3, mask[3] );          // c0  c1  c2  c3  c4  c5  c6  c7  c8  c9  c10 c11 c12 c13 c14 c15
                vec_st( srcv1, x, dstc );
            }
        }
    }
    else
    {
        const vec_u8_t mask[2] = {
            { 0x00, 0x04, 0x08, 0x0C, 0x10, 0x14, 0x18, 0x1C, 0x01, 0x05, 0x09, 0x0D, 0x11, 0x15, 0x19, 0x1D },
            { 0x02, 0x06, 0x0A, 0x0E, 0x12, 0x16, 0x1A, 0x1E, 0x03, 0x07, 0x0B, 0x0F, 0x13, 0x17, 0x1B, 0x1F }
        };

        for( int y = 0; y < h; y++, dsta += i_dsta, dstb += i_dstb, dstc += i_dstc, src += i_src )
        {
            for( int x = 0; x < w; x += 16 )
            {
                vec_u8_t srcv1 = vec_vsx_ld( 4 * x, src );
                vec_u8_t srcv2 = vec_vsx_ld( 4 * x + 16, src );
                vec_u8_t srcv3 = vec_vsx_ld( 4 * x + 32, src );
                vec_u8_t srcv4 = vec_vsx_ld( 4 * x + 48, src );

                vec_u64_t tmp1 = (vec_u64_t)vec_perm( srcv1, srcv2, mask[0] ); // a0  a1  a2  a3  a4  a5  a6  a7  b0  b1  b2  b3  b4  b5  b6  b7
                vec_u64_t tmp2 = (vec_u64_t)vec_perm( srcv3, srcv4, mask[0] ); // a8  a9  a10 a11 a12 a13 a14 a15 b8  b9  b10 b11 b12 b13 b14 b15
                vec_st( (vec_u8_t)vec_mergeh( tmp1, tmp2 ), x, dsta );
                vec_st( (vec_u8_t)vec_mergel( tmp1, tmp2 ), x, dstb );

                tmp1 = (vec_u64_t)vec_perm( srcv1, srcv2, mask[1] );           // c0  c1  c2  c3  c4  c5  c6  c7
                tmp2 = (vec_u64_t)vec_perm( srcv3, srcv4, mask[1] );           // c8  c9  c10 c11 c12 c13 c14 c15
                vec_st( (vec_u8_t)vec_mergeh( tmp1, tmp2 ), x, dstc );
            }
        }
    }
}
#endif

static void mc_luma_altivec( uint8_t *dst,    intptr_t i_dst_stride,
                             uint8_t *src[4], intptr_t i_src_stride,
                             int mvx, int mvy,
                             int i_width, int i_height, const x264_weight_t *weight )
{
    int qpel_idx = ((mvy&3)<<2) + (mvx&3);
    intptr_t offset = (mvy>>2)*i_src_stride + (mvx>>2);
    uint8_t *src1 = src[x264_hpel_ref0[qpel_idx]] + offset + ((mvy&3) == 3) * i_src_stride;
    if( qpel_idx & 5 ) /* qpel interpolation needed */
    {
        uint8_t *src2 = src[x264_hpel_ref1[qpel_idx]] + offset + ((mvx&3) == 3);

        switch( i_width )
        {
            case 4:
                pixel_avg2_w4_altivec( dst, i_dst_stride, src1, i_src_stride, src2, i_height );
                break;
            case 8:
                pixel_avg2_w8_altivec( dst, i_dst_stride, src1, i_src_stride, src2, i_height );
                break;
            case 16:
            default:
                pixel_avg2_w16_altivec( dst, i_dst_stride, src1, i_src_stride, src2, i_height );
        }
        if( weight->weightfn )
            weight->weightfn[i_width>>2]( dst, i_dst_stride, dst, i_dst_stride, weight, i_height );
    }
    else if( weight->weightfn )
        weight->weightfn[i_width>>2]( dst, i_dst_stride, src1, i_src_stride, weight, i_height );
    else
    {
        switch( i_width )
        {
            case 4:
                mc_copy_w4_altivec( dst, i_dst_stride, src1, i_src_stride, i_height );
                break;
            case 8:
                mc_copy_w8_altivec( dst, i_dst_stride, src1, i_src_stride, i_height );
                break;
            case 16:
                mc_copy_w16_altivec( dst, i_dst_stride, src1, i_src_stride, i_height );
                break;
        }
    }
}



static uint8_t *get_ref_altivec( uint8_t *dst,   intptr_t *i_dst_stride,
                                 uint8_t *src[4], intptr_t i_src_stride,
                                 int mvx, int mvy,
                                 int i_width, int i_height, const x264_weight_t *weight )
{
    int qpel_idx = ((mvy&3)<<2) + (mvx&3);
    intptr_t offset = (mvy>>2)*i_src_stride + (mvx>>2);
    uint8_t *src1 = src[x264_hpel_ref0[qpel_idx]] + offset + ((mvy&3) == 3) * i_src_stride;
    if( qpel_idx & 5 ) /* qpel interpolation needed */
    {
        uint8_t *src2 = src[x264_hpel_ref1[qpel_idx]] + offset + ((mvx&3) == 3);
        switch( i_width )
        {
            case 4:
                pixel_avg2_w4_altivec( dst, *i_dst_stride, src1, i_src_stride, src2, i_height );
                break;
            case 8:
                pixel_avg2_w8_altivec( dst, *i_dst_stride, src1, i_src_stride, src2, i_height );
                break;
            case 12:
            case 16:
            default:
                pixel_avg2_w16_altivec( dst, *i_dst_stride, src1, i_src_stride, src2, i_height );
                break;
            case 20:
                pixel_avg2_w20_altivec( dst, *i_dst_stride, src1, i_src_stride, src2, i_height );
                break;
        }
        if( weight->weightfn )
            weight->weightfn[i_width>>2]( dst, *i_dst_stride, dst, *i_dst_stride, weight, i_height );
        return dst;
    }
    else if( weight->weightfn )
    {
        weight->weightfn[i_width>>2]( dst, *i_dst_stride, src1, i_src_stride, weight, i_height );
        return dst;
    }
    else
    {
        *i_dst_stride = i_src_stride;
        return src1;
    }
}

static void mc_chroma_2xh( uint8_t *dstu, uint8_t *dstv, intptr_t i_dst_stride,
                           uint8_t *src, intptr_t i_src_stride,
                           int mvx, int mvy, int i_height )
{
    uint8_t *srcp;
    int d8x = mvx&0x07;
    int d8y = mvy&0x07;

    int cA = (8-d8x)*(8-d8y);
    int cB = d8x    *(8-d8y);
    int cC = (8-d8x)*d8y;
    int cD = d8x    *d8y;

    src += (mvy >> 3) * i_src_stride + (mvx >> 3)*2;
    srcp = &src[i_src_stride];

    for( int y = 0; y < i_height; y++ )
    {
        dstu[0] = ( cA*src[0] + cB*src[2] + cC*srcp[0] + cD*srcp[2] + 32 ) >> 6;
        dstv[0] = ( cA*src[1] + cB*src[3] + cC*srcp[1] + cD*srcp[3] + 32 ) >> 6;
        dstu[1] = ( cA*src[2] + cB*src[4] + cC*srcp[2] + cD*srcp[4] + 32 ) >> 6;
        dstv[1] = ( cA*src[3] + cB*src[5] + cC*srcp[3] + cD*srcp[5] + 32 ) >> 6;

        src  += i_src_stride;
        srcp += i_src_stride;
        dstu += i_dst_stride;
        dstv += i_dst_stride;
    }
 }

#ifdef WORDS_BIGENDIAN
#define VSLD(a,b,n) vec_sld(a,b,n)
#else
#define VSLD(a,b,n) vec_sld(b,a,16-n)
#endif

#ifndef __POWER9_VECTOR__
#define STORE4_ALIGNED(d, s) vec_ste( (vec_u32_t)s, 0, (uint32_t*) d )
#define STORE2_UNALIGNED(d, s) vec_ste( vec_splat( (vec_u16_t)s, 0 ), 0, (uint16_t*)d )
#else
#define STORE4_ALIGNED(d, s) vec_xst_len( (vec_u8_t)s, d, 4 )
#define STORE2_UNALIGNED(d, s) vec_xst_len( (vec_u8_t)s, d, 2 )
#endif

static void mc_chroma_4xh_altivec( uint8_t *dstu, uint8_t *dstv, intptr_t i_dst_stride,
                                   uint8_t *src, intptr_t i_src_stride,
                                   int mvx, int mvy, int i_height )
{
    uint8_t *srcp;
    int d8x = mvx & 0x07;
    int d8y = mvy & 0x07;

    ALIGNED_16( uint16_t coeff[4] );
    coeff[0] = (8-d8x)*(8-d8y);
    coeff[1] = d8x    *(8-d8y);
    coeff[2] = (8-d8x)*d8y;
    coeff[3] = d8x    *d8y;

    src += (mvy >> 3) * i_src_stride + (mvx >> 3)*2;
    srcp = &src[i_src_stride];

    LOAD_ZERO;
    vec_u16_t   coeff0v, coeff1v, coeff2v, coeff3v;
    vec_u8_t    src2v_8, dstuv, dstvv;
    vec_u16_t   src0v_16, src1v_16, src2v_16, src3v_16, dstv16;
    vec_u16_t   shiftv, k32v;

#ifdef WORDS_BIGENDIAN
    static const vec_u8_t perm0v = CV(1,5,9,13,1,5,9,13,1,5,9,13,1,5,9,13);
    static const vec_u8_t perm1v = CV(3,7,11,15,3,7,11,15,3,7,11,15,3,7,11,15);
#else
    static const vec_u8_t perm0v = CV(0,4,8,12,0,4,8,12,0,4,8,12,0,4,8,12);
    static const vec_u8_t perm1v = CV(2,6,10,14,2,6,10,14,2,6,10,14,2,6,10,14);
#endif

    coeff0v = vec_ld( 0, coeff );
    coeff3v = vec_splat( coeff0v, 3 );
    coeff2v = vec_splat( coeff0v, 2 );
    coeff1v = vec_splat( coeff0v, 1 );
    coeff0v = vec_splat( coeff0v, 0 );
    k32v    = vec_sl( vec_splat_u16( 1 ), vec_splat_u16( 5 ) );
    shiftv  = vec_splat_u16( 6 );

    src2v_8 = vec_vsx_ld( 0, src );
    src2v_16 = vec_u8_to_u16( src2v_8 );
    src3v_16 = vec_u8_to_u16( VSLD( src2v_8, src2v_8, 2 ) );

    for( int y = 0; y < i_height; y += 2 )
    {
        src0v_16 = src2v_16;
        src1v_16 = src3v_16;
        src2v_8 = vec_vsx_ld( 0, srcp );
        src2v_16 = vec_u8_to_u16( src2v_8 );
        src3v_16 = vec_u8_to_u16( VSLD( src2v_8, src2v_8, 2 ) );

        dstv16 = vec_mladd( coeff0v, src0v_16, k32v );
        dstv16 = vec_mladd( coeff1v, src1v_16, dstv16 );
        dstv16 = vec_mladd( coeff2v, src2v_16, dstv16 );
        dstv16 = vec_mladd( coeff3v, src3v_16, dstv16 );

        dstv16 = vec_sr( dstv16, shiftv );

        dstuv = (vec_u8_t)vec_perm( dstv16, dstv16, perm0v );
        dstvv = (vec_u8_t)vec_perm( dstv16, dstv16, perm1v );
        STORE4_ALIGNED( dstu, dstuv );
        STORE4_ALIGNED( dstv, dstvv );

        srcp += i_src_stride;
        dstu += i_dst_stride;
        dstv += i_dst_stride;

        src0v_16 = src2v_16;
        src1v_16 = src3v_16;
        src2v_8 = vec_vsx_ld( 0, srcp );
        src2v_16 = vec_u8_to_u16( src2v_8 );
        src3v_16 = vec_u8_to_u16( VSLD( src2v_8, src2v_8, 2 ) );

        dstv16 = vec_mladd( coeff0v, src0v_16, k32v );
        dstv16 = vec_mladd( coeff1v, src1v_16, dstv16 );
        dstv16 = vec_mladd( coeff2v, src2v_16, dstv16 );
        dstv16 = vec_mladd( coeff3v, src3v_16, dstv16 );

        dstv16 = vec_sr( dstv16, shiftv );

        dstuv = (vec_u8_t)vec_perm( dstv16, dstv16, perm0v );
        dstvv = (vec_u8_t)vec_perm( dstv16, dstv16, perm1v );
        STORE4_ALIGNED( dstu, dstuv );
        STORE4_ALIGNED( dstv, dstvv );

        srcp += i_src_stride;
        dstu += i_dst_stride;
        dstv += i_dst_stride;
    }
}

static void mc_chroma_8xh_altivec( uint8_t *dstu, uint8_t *dstv, intptr_t i_dst_stride,
                                   uint8_t *src, intptr_t i_src_stride,
                                   int mvx, int mvy, int i_height )
{
    uint8_t *srcp;
    int d8x = mvx & 0x07;
    int d8y = mvy & 0x07;

    ALIGNED_16( uint16_t coeff[4] );
    coeff[0] = (8-d8x)*(8-d8y);
    coeff[1] = d8x    *(8-d8y);
    coeff[2] = (8-d8x)*d8y;
    coeff[3] = d8x    *d8y;

    src += (mvy >> 3) * i_src_stride + (mvx >> 3)*2;
    srcp = &src[i_src_stride];

    LOAD_ZERO;
    vec_u16_t   coeff0v, coeff1v, coeff2v, coeff3v;
    vec_u8_t    src0v_8, src1v_8, src2v_8, src3v_8;
    vec_u8_t    dstuv, dstvv;
    vec_u16_t   src0v_16h, src1v_16h, src2v_16h, src3v_16h, dstv_16h;
    vec_u16_t   src0v_16l, src1v_16l, src2v_16l, src3v_16l, dstv_16l;
    vec_u16_t   shiftv, k32v;

    coeff0v = vec_ld( 0, coeff );
    coeff3v = vec_splat( coeff0v, 3 );
    coeff2v = vec_splat( coeff0v, 2 );
    coeff1v = vec_splat( coeff0v, 1 );
    coeff0v = vec_splat( coeff0v, 0 );
    k32v    = vec_sl( vec_splat_u16( 1 ), vec_splat_u16( 5 ) );
    shiftv  = vec_splat_u16( 6 );

#ifdef WORDS_BIGENDIAN
    static const vec_u8_t perm0v = CV(1,5,9,13,17,21,25,29,0,0,0,0,0,0,0,0);
    static const vec_u8_t perm1v = CV(3,7,11,15,19,23,27,31,0,0,0,0,0,0,0,0);
#else
    static const vec_u8_t perm0v = CV(0,4,8,12,16,20,24,28,1,1,1,1,1,1,1,1);
    static const vec_u8_t perm1v = CV(2,6,10,14,18,22,26,30,1,1,1,1,1,1,1,1);
#endif

    src2v_8 = vec_vsx_ld( 0, src );
    src3v_8 = vec_vsx_ld( 16, src );
    src3v_8 = VSLD( src2v_8, src3v_8, 2 );

    for( int y = 0; y < i_height; y += 2 )
    {
        src0v_8 = src2v_8;
        src1v_8 = src3v_8;
        src2v_8 = vec_vsx_ld( 0, srcp );
        src3v_8 = vec_vsx_ld( 16, srcp );

        src3v_8 = VSLD( src2v_8, src3v_8, 2 );

        src0v_16h = vec_u8_to_u16_h( src0v_8 );
        src0v_16l = vec_u8_to_u16_l( src0v_8 );
        src1v_16h = vec_u8_to_u16_h( src1v_8 );
        src1v_16l = vec_u8_to_u16_l( src1v_8 );
        src2v_16h = vec_u8_to_u16_h( src2v_8 );
        src2v_16l = vec_u8_to_u16_l( src2v_8 );
        src3v_16h = vec_u8_to_u16_h( src3v_8 );
        src3v_16l = vec_u8_to_u16_l( src3v_8 );

        dstv_16h = vec_mladd( coeff0v, src0v_16h, k32v );
        dstv_16l = vec_mladd( coeff0v, src0v_16l, k32v );
        dstv_16h = vec_mladd( coeff1v, src1v_16h, dstv_16h );
        dstv_16l = vec_mladd( coeff1v, src1v_16l, dstv_16l );
        dstv_16h = vec_mladd( coeff2v, src2v_16h, dstv_16h );
        dstv_16l = vec_mladd( coeff2v, src2v_16l, dstv_16l );
        dstv_16h = vec_mladd( coeff3v, src3v_16h, dstv_16h );
        dstv_16l = vec_mladd( coeff3v, src3v_16l, dstv_16l );

        dstv_16h = vec_sr( dstv_16h, shiftv );
        dstv_16l = vec_sr( dstv_16l, shiftv );

        dstuv = (vec_u8_t)vec_perm( dstv_16h, dstv_16l, perm0v );
        dstvv = (vec_u8_t)vec_perm( dstv_16h, dstv_16l, perm1v );

        VEC_STORE8( dstuv, dstu );
        VEC_STORE8( dstvv, dstv );

        srcp += i_src_stride;
        dstu += i_dst_stride;
        dstv += i_dst_stride;

        src0v_8 = src2v_8;
        src1v_8 = src3v_8;
        src2v_8 = vec_vsx_ld( 0, srcp );
        src3v_8 = vec_vsx_ld( 16, srcp );

        src3v_8 = VSLD( src2v_8, src3v_8, 2 );

        src0v_16h = vec_u8_to_u16_h( src0v_8 );
        src0v_16l = vec_u8_to_u16_l( src0v_8 );
        src1v_16h = vec_u8_to_u16_h( src1v_8 );
        src1v_16l = vec_u8_to_u16_l( src1v_8 );
        src2v_16h = vec_u8_to_u16_h( src2v_8 );
        src2v_16l = vec_u8_to_u16_l( src2v_8 );
        src3v_16h = vec_u8_to_u16_h( src3v_8 );
        src3v_16l = vec_u8_to_u16_l( src3v_8 );

        dstv_16h = vec_mladd( coeff0v, src0v_16h, k32v );
        dstv_16l = vec_mladd( coeff0v, src0v_16l, k32v );
        dstv_16h = vec_mladd( coeff1v, src1v_16h, dstv_16h );
        dstv_16l = vec_mladd( coeff1v, src1v_16l, dstv_16l );
        dstv_16h = vec_mladd( coeff2v, src2v_16h, dstv_16h );
        dstv_16l = vec_mladd( coeff2v, src2v_16l, dstv_16l );
        dstv_16h = vec_mladd( coeff3v, src3v_16h, dstv_16h );
        dstv_16l = vec_mladd( coeff3v, src3v_16l, dstv_16l );

        dstv_16h = vec_sr( dstv_16h, shiftv );
        dstv_16l = vec_sr( dstv_16l, shiftv );

        dstuv = (vec_u8_t)vec_perm( dstv_16h, dstv_16l, perm0v );
        dstvv = (vec_u8_t)vec_perm( dstv_16h, dstv_16l, perm1v );

        VEC_STORE8( dstuv, dstu );
        VEC_STORE8( dstvv, dstv );

        srcp += i_src_stride;
        dstu += i_dst_stride;
        dstv += i_dst_stride;
    }
}

static void mc_chroma_altivec( uint8_t *dstu, uint8_t *dstv, intptr_t i_dst_stride,
                               uint8_t *src, intptr_t i_src_stride,
                               int mvx, int mvy, int i_width, int i_height )
{
    if( i_width == 8 )
        mc_chroma_8xh_altivec( dstu, dstv, i_dst_stride, src, i_src_stride,
                               mvx, mvy, i_height );
    else if( i_width == 4 )
        mc_chroma_4xh_altivec( dstu, dstv, i_dst_stride, src, i_src_stride,
                               mvx, mvy, i_height );
    else
        mc_chroma_2xh( dstu, dstv, i_dst_stride, src, i_src_stride,
                       mvx, mvy, i_height );
}

#define HPEL_FILTER_1( t1v, t2v, t3v, t4v, t5v, t6v ) \
{                                                     \
    t1v = vec_add( t1v, t6v );                        \
    t2v = vec_add( t2v, t5v );                        \
    t3v = vec_add( t3v, t4v );                        \
                                                      \
    t1v = vec_sub( t1v, t2v );   /* (a-b) */          \
    t2v = vec_sub( t2v, t3v );   /* (b-c) */          \
    t2v = vec_sl(  t2v, twov );  /* (b-c)*4 */        \
    t1v = vec_sub( t1v, t2v );   /* a-5*b+4*c */      \
    t3v = vec_sl(  t3v, fourv ); /* 16*c */           \
    t1v = vec_add( t1v, t3v );   /* a-5*b+20*c */     \
}

#define HPEL_FILTER_2( t1v, t2v, t3v, t4v, t5v, t6v ) \
{                                                     \
    t1v = vec_add( t1v, t6v );                        \
    t2v = vec_add( t2v, t5v );                        \
    t3v = vec_add( t3v, t4v );                        \
                                                      \
    t1v = vec_sub( t1v, t2v );  /* (a-b) */           \
    t1v = vec_sra( t1v, twov ); /* (a-b)/4 */         \
    t1v = vec_sub( t1v, t2v );  /* (a-b)/4-b */       \
    t1v = vec_add( t1v, t3v );  /* (a-b)/4-b+c */     \
    t1v = vec_sra( t1v, twov ); /* ((a-b)/4-b+c)/4 */ \
    t1v = vec_add( t1v, t3v );  /* ((a-b)/4-b+c)/4+c = (a-5*b+20*c)/16 */ \
}

#define HPEL_FILTER_HORIZONTAL()                             \
{                                                            \
    src1v = vec_vsx_ld( x- 2+i_stride*y, src );              \
    src6v = vec_vsx_ld( x+14+i_stride*y, src );              \
                                                             \
    src2v = VSLD( src1v, src6v,  1 );                        \
    src3v = VSLD( src1v, src6v,  2 );                        \
    src4v = VSLD( src1v, src6v,  3 );                        \
    src5v = VSLD( src1v, src6v,  4 );                        \
    src6v = VSLD( src1v, src6v,  5 );                        \
                                                             \
    temp1v = vec_u8_to_s16_h( src1v );                       \
    temp2v = vec_u8_to_s16_h( src2v );                       \
    temp3v = vec_u8_to_s16_h( src3v );                       \
    temp4v = vec_u8_to_s16_h( src4v );                       \
    temp5v = vec_u8_to_s16_h( src5v );                       \
    temp6v = vec_u8_to_s16_h( src6v );                       \
                                                             \
    HPEL_FILTER_1( temp1v, temp2v, temp3v,                   \
                   temp4v, temp5v, temp6v );                 \
                                                             \
    dest1v = vec_add( temp1v, sixteenv );                    \
    dest1v = vec_sra( dest1v, fivev );                       \
                                                             \
    temp1v = vec_u8_to_s16_l( src1v );                       \
    temp2v = vec_u8_to_s16_l( src2v );                       \
    temp3v = vec_u8_to_s16_l( src3v );                       \
    temp4v = vec_u8_to_s16_l( src4v );                       \
    temp5v = vec_u8_to_s16_l( src5v );                       \
    temp6v = vec_u8_to_s16_l( src6v );                       \
                                                             \
    HPEL_FILTER_1( temp1v, temp2v, temp3v,                   \
                   temp4v, temp5v, temp6v );                 \
                                                             \
    dest2v = vec_add( temp1v, sixteenv );                    \
    dest2v = vec_sra( dest2v, fivev );                       \
                                                             \
    destv = vec_packsu( dest1v, dest2v );                    \
                                                             \
    vec_vsx_st( destv, x+i_stride*y, dsth );                 \
}

#define HPEL_FILTER_VERTICAL()                                    \
{                                                                 \
    src1v = vec_vsx_ld( x+i_stride*(y-2), src );                  \
    src2v = vec_vsx_ld( x+i_stride*(y-1), src );                  \
    src3v = vec_vsx_ld( x+i_stride*(y-0), src );                  \
    src4v = vec_vsx_ld( x+i_stride*(y+1), src );                  \
    src5v = vec_vsx_ld( x+i_stride*(y+2), src );                  \
    src6v = vec_vsx_ld( x+i_stride*(y+3), src );                  \
                                                                  \
    temp1v = vec_u8_to_s16_h( src1v );                            \
    temp2v = vec_u8_to_s16_h( src2v );                            \
    temp3v = vec_u8_to_s16_h( src3v );                            \
    temp4v = vec_u8_to_s16_h( src4v );                            \
    temp5v = vec_u8_to_s16_h( src5v );                            \
    temp6v = vec_u8_to_s16_h( src6v );                            \
                                                                  \
    HPEL_FILTER_1( temp1v, temp2v, temp3v,                        \
                   temp4v, temp5v, temp6v );                      \
                                                                  \
    dest1v = vec_add( temp1v, sixteenv );                         \
    dest1v = vec_sra( dest1v, fivev );                            \
                                                                  \
    temp4v = vec_u8_to_s16_l( src1v );                            \
    temp5v = vec_u8_to_s16_l( src2v );                            \
    temp6v = vec_u8_to_s16_l( src3v );                            \
    temp7v = vec_u8_to_s16_l( src4v );                            \
    temp8v = vec_u8_to_s16_l( src5v );                            \
    temp9v = vec_u8_to_s16_l( src6v );                            \
                                                                  \
    HPEL_FILTER_1( temp4v, temp5v, temp6v,                        \
                   temp7v, temp8v, temp9v );                      \
                                                                  \
    dest2v = vec_add( temp4v, sixteenv );                         \
    dest2v = vec_sra( dest2v, fivev );                            \
                                                                  \
    destv = vec_packsu( dest1v, dest2v );                         \
                                                                  \
    vec_vsx_st( destv, x+i_stride*y, dstv );                      \
}

#define HPEL_FILTER_CENTRAL()                           \
{                                                       \
    temp1v = VSLD( tempav, tempbv, 12 );                \
    temp2v = VSLD( tempav, tempbv, 14 );                \
    temp3v = tempbv;                                    \
    temp4v = VSLD( tempbv, tempcv,  2 );                \
    temp5v = VSLD( tempbv, tempcv,  4 );                \
    temp6v = VSLD( tempbv, tempcv,  6 );                \
                                                        \
    HPEL_FILTER_2( temp1v, temp2v, temp3v,              \
                   temp4v, temp5v, temp6v );            \
                                                        \
    dest1v = vec_add( temp1v, thirtytwov );             \
    dest1v = vec_sra( dest1v, sixv );                   \
                                                        \
    temp1v = VSLD( tempbv, tempcv, 12 );                \
    temp2v = VSLD( tempbv, tempcv, 14 );                \
    temp3v = tempcv;                                    \
    temp4v = VSLD( tempcv, tempdv,  2 );                \
    temp5v = VSLD( tempcv, tempdv,  4 );                \
    temp6v = VSLD( tempcv, tempdv,  6 );                \
                                                        \
    HPEL_FILTER_2( temp1v, temp2v, temp3v,              \
                   temp4v, temp5v, temp6v );            \
                                                        \
    dest2v = vec_add( temp1v, thirtytwov );             \
    dest2v = vec_sra( dest2v, sixv );                   \
                                                        \
    destv = vec_packsu( dest1v, dest2v );               \
                                                        \
    vec_vsx_st( destv, x-16+i_stride*y, dstc );         \
}

void x264_hpel_filter_altivec( uint8_t *dsth, uint8_t *dstv, uint8_t *dstc, uint8_t *src,
                               intptr_t i_stride, int i_width, int i_height, int16_t *buf )
{
    vec_u8_t destv;
    vec_u8_t src1v, src2v, src3v, src4v, src5v, src6v;
    vec_s16_t dest1v, dest2v;
    vec_s16_t temp1v, temp2v, temp3v, temp4v, temp5v, temp6v, temp7v, temp8v, temp9v;
    vec_s16_t tempav, tempbv, tempcv, tempdv, tempev;

    LOAD_ZERO;

    vec_u16_t twov, fourv, fivev, sixv;
    vec_s16_t sixteenv, thirtytwov;

    twov = vec_splats( (uint16_t)2 );
    fourv = vec_splats( (uint16_t)4 );
    fivev = vec_splats( (uint16_t)5 );
    sixv = vec_splats( (uint16_t)6 );
    sixteenv = vec_splats( (int16_t)16 );
    thirtytwov = vec_splats( (int16_t)32 );

    for( int y = 0; y < i_height; y++ )
    {
        int x = 0;

        /* horizontal_filter */
        HPEL_FILTER_HORIZONTAL();

        /* vertical_filter */
        HPEL_FILTER_VERTICAL();

        /* central_filter */
        tempav = tempcv;
        tempbv = tempdv;
        tempcv = vec_splat( temp1v, 0 ); /* first only */
        tempdv = temp1v;
        tempev = temp4v;

        for( x = 16; x < i_width; x+=16 )
        {
            /* horizontal_filter */
            HPEL_FILTER_HORIZONTAL();

            /* vertical_filter */
            HPEL_FILTER_VERTICAL();

            /* central_filter */
            tempav = tempcv;
            tempbv = tempdv;
            tempcv = tempev;
            tempdv = temp1v;
            tempev = temp4v;

            HPEL_FILTER_CENTRAL();
        }

        /* Partial vertical filter */
        src1v = vec_vsx_ld( x+i_stride*(y-2), src );
        src2v = vec_vsx_ld( x+i_stride*(y-1), src );
        src3v = vec_vsx_ld( x+i_stride*(y-0), src );
        src4v = vec_vsx_ld( x+i_stride*(y+1), src );
        src5v = vec_vsx_ld( x+i_stride*(y+2), src );
        src6v = vec_vsx_ld( x+i_stride*(y+3), src );

        temp1v = vec_u8_to_s16_h( src1v );
        temp2v = vec_u8_to_s16_h( src2v );
        temp3v = vec_u8_to_s16_h( src3v );
        temp4v = vec_u8_to_s16_h( src4v );
        temp5v = vec_u8_to_s16_h( src5v );
        temp6v = vec_u8_to_s16_h( src6v );

        HPEL_FILTER_1( temp1v, temp2v, temp3v, temp4v, temp5v, temp6v );

        /* central_filter */
        tempav = tempcv;
        tempbv = tempdv;
        tempcv = tempev;
        tempdv = temp1v;
        /* tempev is not used */

        HPEL_FILTER_CENTRAL();
    }
}

static void frame_init_lowres_core_altivec( uint8_t *src0, uint8_t *dst0, uint8_t *dsth, uint8_t *dstv, uint8_t *dstc,
                                            intptr_t src_stride, intptr_t dst_stride, int width, int height )
{
    int w = width >> 4;
    int end = (width & 15);
    vec_u8_t src0v, src1v, src2v;
    vec_u8_t lv, hv, src1p1v;
    vec_u8_t avg0v, avg1v, avghv, avghp1v, avgleftv, avgrightv;
    static const vec_u8_t inverse_bridge_shuffle = CV(0x00, 0x02, 0x04, 0x06, 0x08, 0x0A, 0x0C, 0x0E, 0x10, 0x12, 0x14, 0x16, 0x18, 0x1A, 0x1C, 0x1E );
#ifndef WORDS_BIGENDIAN
    static const vec_u8_t inverse_bridge_shuffle_1 = CV(0x01, 0x03, 0x05, 0x07, 0x09, 0x0B, 0x0D, 0x0F, 0x11, 0x13, 0x15, 0x17, 0x19, 0x1B, 0x1D, 0x1F );
#endif

    for( int y = 0; y < height; y++ )
    {
        int x;
        uint8_t *src1 = src0+src_stride;
        uint8_t *src2 = src1+src_stride;

        src0v = vec_ld(0, src0);
        src1v = vec_ld(0, src1);
        src2v = vec_ld(0, src2);

        avg0v = vec_avg(src0v, src1v);
        avg1v = vec_avg(src1v, src2v);

        for( x = 0; x < w; x++ )
        {
            lv = vec_ld(16*(x*2+1), src0);
            src1v = vec_ld(16*(x*2+1), src1);
            avghv = vec_avg(lv, src1v);

            lv = vec_ld(16*(x*2+2), src0);
            src1p1v = vec_ld(16*(x*2+2), src1);
            avghp1v = vec_avg(lv, src1p1v);

            avgleftv = vec_avg(VSLD(avg0v, avghv, 1), avg0v);
            avgrightv = vec_avg(VSLD(avghv, avghp1v, 1), avghv);

            vec_st(vec_perm(avgleftv, avgrightv, inverse_bridge_shuffle), 16*x, dst0);
#ifdef WORDS_BIGENDIAN
            vec_st((vec_u8_t)vec_pack((vec_u16_t)avgleftv,(vec_u16_t)avgrightv), 16*x, dsth);
#else
            vec_st(vec_perm(avgleftv, avgrightv, inverse_bridge_shuffle_1), 16*x, dsth);
#endif

            avg0v = avghp1v;

            hv = vec_ld(16*(x*2+1), src2);
            avghv = vec_avg(src1v, hv);

            hv = vec_ld(16*(x*2+2), src2);
            avghp1v = vec_avg(src1p1v, hv);

            avgleftv = vec_avg(VSLD(avg1v, avghv, 1), avg1v);
            avgrightv = vec_avg(VSLD(avghv, avghp1v, 1), avghv);

            vec_st(vec_perm(avgleftv, avgrightv, inverse_bridge_shuffle), 16*x, dstv);
#ifdef WORDS_BIGENDIAN
            vec_st((vec_u8_t)vec_pack((vec_u16_t)avgleftv,(vec_u16_t)avgrightv), 16*x, dstc);
#else
            vec_st(vec_perm(avgleftv, avgrightv, inverse_bridge_shuffle_1), 16*x, dstc);
#endif

            avg1v = avghp1v;

        }
        if( end )
        {
            lv = vec_ld(16*(x*2+1), src0);
            src1v = vec_ld(16*(x*2+1), src1);
            avghv = vec_avg(lv, src1v);

            lv = vec_ld(16*(x*2+1), src2);
            avghp1v = vec_avg(src1v, lv);

            avgleftv = vec_avg(VSLD(avg0v, avghv, 1), avg0v);
            avgrightv = vec_avg(VSLD(avg1v, avghp1v, 1), avg1v);

            lv = vec_perm(avgleftv, avgrightv, inverse_bridge_shuffle);
#ifdef WORDS_BIGENDIAN
            hv = (vec_u8_t)vec_pack((vec_u16_t)avgleftv,(vec_u16_t)avgrightv);
#else
            hv = vec_perm(avgleftv, avgrightv, inverse_bridge_shuffle_1);
#endif

            VEC_STORE8( lv, dst0 + 16 * x );
            VEC_STORE8( hv, dsth + 16 * x );

            lv = vec_sld(lv, lv, 8);
            hv = vec_sld(hv, hv, 8);

            VEC_STORE8( lv, dstv + 16 * x );
            VEC_STORE8( hv, dstc + 16 * x );
        }

        src0 += src_stride*2;
        dst0 += dst_stride;
        dsth += dst_stride;
        dstv += dst_stride;
        dstc += dst_stride;
    }
}

static void mc_weight_w2_altivec( uint8_t *dst, intptr_t i_dst, uint8_t *src, intptr_t i_src,
                                  const x264_weight_t *weight, int i_height )
{
    LOAD_ZERO;
    vec_u8_t srcv;
    vec_s16_t weightv;
    vec_s16_t scalev, offsetv, denomv, roundv;

    int denom = weight->i_denom;

    scalev = vec_splats( (int16_t)weight->i_scale );
    offsetv = vec_splats( (int16_t)weight->i_offset );

    if( denom >= 1 )
    {
        denomv = vec_splats( (int16_t)denom );
        roundv = vec_splats( (int16_t)(1 << (denom - 1)) );

        for( int y = 0; y < i_height; y++, dst += i_dst, src += i_src )
        {
            srcv = vec_vsx_ld( 0, src );
            weightv = vec_u8_to_s16( srcv );

            weightv = vec_mladd( weightv, scalev, roundv );
            weightv = vec_sra( weightv, (vec_u16_t)denomv );
            weightv = vec_add( weightv, offsetv );

            srcv = vec_packsu( weightv, zero_s16v );
            STORE2_UNALIGNED( dst, srcv );
        }
    }
    else
    {
        for( int y = 0; y < i_height; y++, dst += i_dst, src += i_src )
        {
            srcv = vec_vsx_ld( 0, src );
            weightv = vec_u8_to_s16( srcv );

            weightv = vec_mladd( weightv, scalev, offsetv );

            srcv = vec_packsu( weightv, zero_s16v );
            STORE2_UNALIGNED( dst, srcv );
        }
    }
}
static void mc_weight_w4_altivec( uint8_t *dst, intptr_t i_dst, uint8_t *src, intptr_t i_src,
                                  const x264_weight_t *weight, int i_height )
{
    LOAD_ZERO;
    vec_u8_t srcv;
    vec_s16_t weightv;
    vec_s16_t scalev, offsetv, denomv, roundv;

    int denom = weight->i_denom;

    scalev = vec_splats( (int16_t)weight->i_scale );
    offsetv = vec_splats( (int16_t)weight->i_offset );

    if( denom >= 1 )
    {
        denomv = vec_splats( (int16_t)denom );
        roundv = vec_splats( (int16_t)(1 << (denom - 1)) );

        for( int y = 0; y < i_height; y++, dst += i_dst, src += i_src )
        {
            srcv = vec_vsx_ld( 0, src );
            weightv = vec_u8_to_s16( srcv );

            weightv = vec_mladd( weightv, scalev, roundv );
            weightv = vec_sra( weightv, (vec_u16_t)denomv );
            weightv = vec_add( weightv, offsetv );

            srcv = vec_packsu( weightv, zero_s16v );
            vec_ste( vec_splat( (vec_u32_t)srcv, 0 ), 0, (uint32_t*)dst );
        }
    }
    else
    {
        for( int y = 0; y < i_height; y++, dst += i_dst, src += i_src )
        {
            srcv = vec_vsx_ld( 0, src );
            weightv = vec_u8_to_s16( srcv );

            weightv = vec_mladd( weightv, scalev, offsetv );

            srcv = vec_packsu( weightv, zero_s16v );
            vec_ste( vec_splat( (vec_u32_t)srcv, 0 ), 0, (uint32_t*)dst );
        }
    }
}
static void mc_weight_w8_altivec( uint8_t *dst, intptr_t i_dst, uint8_t *src, intptr_t i_src,
                                  const x264_weight_t *weight, int i_height )
{
    LOAD_ZERO;
    vec_u8_t srcv;
    vec_s16_t weightv;
    vec_s16_t scalev, offsetv, denomv, roundv;

    int denom = weight->i_denom;

    scalev = vec_splats( (int16_t)weight->i_scale );
    offsetv = vec_splats( (int16_t)weight->i_offset );

    if( denom >= 1 )
    {
        denomv = vec_splats( (int16_t)denom );
        roundv = vec_splats( (int16_t)(1 << (denom - 1)) );

        for( int y = 0; y < i_height; y++, dst += i_dst, src += i_src )
        {
            srcv = vec_vsx_ld( 0, src );
            weightv = vec_u8_to_s16( srcv );

            weightv = vec_mladd( weightv, scalev, roundv );
            weightv = vec_sra( weightv, (vec_u16_t)denomv );
            weightv = vec_add( weightv, offsetv );

            srcv = vec_packsu( weightv, zero_s16v );
            VEC_STORE8( srcv, dst );
        }
    }
    else
    {
        for( int y = 0; y < i_height; y++, dst += i_dst, src += i_src )
        {
            srcv = vec_vsx_ld( 0, src );
            weightv = vec_u8_to_s16( srcv );

            weightv = vec_mladd( weightv, scalev, offsetv );

            srcv = vec_packsu( weightv, zero_s16v );
            VEC_STORE8( srcv, dst );
        }
    }
}
static void mc_weight_w16_altivec( uint8_t *dst, intptr_t i_dst, uint8_t *src, intptr_t i_src,
                                   const x264_weight_t *weight, int i_height )
{
    LOAD_ZERO;
    vec_u8_t srcv;
    vec_s16_t weight_lv, weight_hv;
    vec_s16_t scalev, offsetv, denomv, roundv;

    int denom = weight->i_denom;

    scalev = vec_splats( (int16_t)weight->i_scale );
    offsetv = vec_splats( (int16_t)weight->i_offset );

    if( denom >= 1 )
    {
        denomv = vec_splats( (int16_t)denom );
        roundv = vec_splats( (int16_t)(1 << (denom - 1)) );

        for( int y = 0; y < i_height; y++, dst += i_dst, src += i_src )
        {
            srcv = vec_vsx_ld( 0, src );
            weight_hv = vec_u8_to_s16_h( srcv );
            weight_lv = vec_u8_to_s16_l( srcv );

            weight_hv = vec_mladd( weight_hv, scalev, roundv );
            weight_lv = vec_mladd( weight_lv, scalev, roundv );
            weight_hv = vec_sra( weight_hv, (vec_u16_t)denomv );
            weight_lv = vec_sra( weight_lv, (vec_u16_t)denomv );
            weight_hv = vec_add( weight_hv, offsetv );
            weight_lv = vec_add( weight_lv, offsetv );

            srcv = vec_packsu( weight_hv, weight_lv );
            vec_st( srcv, 0, dst );
        }
    }
    else
    {
        for( int y = 0; y < i_height; y++, dst += i_dst, src += i_src )
        {
            srcv = vec_vsx_ld( 0, src );
            weight_hv = vec_u8_to_s16_h( srcv );
            weight_lv = vec_u8_to_s16_l( srcv );

            weight_hv = vec_mladd( weight_hv, scalev, offsetv );
            weight_lv = vec_mladd( weight_lv, scalev, offsetv );

            srcv = vec_packsu( weight_hv, weight_lv );
            vec_st( srcv, 0, dst );
        }
    }
}
static void mc_weight_w20_altivec( uint8_t *dst, intptr_t i_dst, uint8_t *src, intptr_t i_src,
                                   const x264_weight_t *weight, int i_height )
{
    LOAD_ZERO;
    vec_u8_t srcv, srcv2;
    vec_s16_t weight_lv, weight_hv, weight_3v;
    vec_s16_t scalev, offsetv, denomv, roundv;

    int denom = weight->i_denom;

    scalev = vec_splats( (int16_t)weight->i_scale );
    offsetv = vec_splats( (int16_t)weight->i_offset );

    if( denom >= 1 )
    {
        int16_t round = 1 << (denom - 1);
        vec_s16_t tab[4] = {
            { weight->i_scale, weight->i_scale, weight->i_scale, weight->i_scale, 1, 1, 1, 1 },
            { weight->i_offset, weight->i_offset, weight->i_offset, weight->i_offset, 0, 0, 0, 0 },
            { denom, denom, denom, denom, 0, 0, 0, 0 },
            { round, round, round, round, 0, 0, 0, 0 },
        };

        denomv = vec_splats( (int16_t)denom );
        roundv = vec_splats( (int16_t)(1 << (denom - 1)) );

        for( int y = 0; y < i_height; y++, dst += i_dst, src += i_src )
        {
            srcv = vec_vsx_ld( 0, src );
            srcv2 = vec_vsx_ld( 16, src );

            weight_hv = vec_u8_to_s16_h( srcv );
            weight_lv = vec_u8_to_s16_l( srcv );
            weight_3v = vec_u8_to_s16_h( srcv2 );

            weight_hv = vec_mladd( weight_hv, scalev, roundv );
            weight_lv = vec_mladd( weight_lv, scalev, roundv );
            weight_3v = vec_mladd( weight_3v, tab[0], tab[3] );

            weight_hv = vec_sra( weight_hv, (vec_u16_t)denomv );
            weight_lv = vec_sra( weight_lv, (vec_u16_t)denomv );
            weight_3v = vec_sra( weight_3v, (vec_u16_t)tab[2] );

            weight_hv = vec_add( weight_hv, offsetv );
            weight_lv = vec_add( weight_lv, offsetv );
            weight_3v = vec_add( weight_3v, tab[1] );

            srcv = vec_packsu( weight_hv, weight_lv );
            srcv2 = vec_packsu( weight_3v, vec_u8_to_s16_l( srcv2 ) );
            vec_vsx_st( srcv, 0, dst );
            vec_vsx_st( srcv2, 16, dst );
        }
    }
    else
    {
        vec_s16_t offset_mask = { weight->i_offset, weight->i_offset, weight->i_offset,
                                  weight->i_offset, 0, 0, 0, 0 };
        for( int y = 0; y < i_height; y++, dst += i_dst, src += i_src )
        {
            srcv = vec_vsx_ld( 0, src );
            srcv2 = vec_vsx_ld( 16, src );

            weight_hv = vec_u8_to_s16_h( srcv );
            weight_lv = vec_u8_to_s16_l( srcv );
            weight_3v = vec_u8_to_s16_h( srcv2 );

            weight_hv = vec_mladd( weight_hv, scalev, offsetv );
            weight_lv = vec_mladd( weight_lv, scalev, offsetv );
            weight_3v = vec_mladd( weight_3v, scalev, offset_mask );

            srcv = vec_packsu( weight_hv, weight_lv );
            srcv2 = vec_packsu( weight_3v, vec_u8_to_s16_l( srcv2 ) );
            vec_vsx_st( srcv, 0, dst );
            vec_vsx_st( srcv2, 16, dst );
        }
    }
}

static weight_fn_t mc_weight_wtab_altivec[6] =
{
    mc_weight_w2_altivec,
    mc_weight_w4_altivec,
    mc_weight_w8_altivec,
    mc_weight_w16_altivec,
    mc_weight_w16_altivec,
    mc_weight_w20_altivec,
};

PLANE_COPY_SWAP(16, altivec)
PLANE_INTERLEAVE(altivec)
#endif // !HIGH_BIT_DEPTH

#if HIGH_BIT_DEPTH

#define LOAD_SRC( l )                   \
{                                       \
    srcv[l] = vec_vsx_ld( s, src );     \
    s += 16;                            \
    srcv[l + 1] = vec_vsx_ld( s, src ); \
    s += 16;                            \
}

#define STORE_8( mask, shift, dst, a, b )                 \
{                                                         \
    dstv = (vec_u16_t)vec_perm( srcv[a], srcv[b], mask ); \
    dstv = vec_sr( dstv, shift );                         \
    dstv = vec_and( dstv, and_mask );                     \
                                                          \
    vec_st( dstv, offset, dst );                          \
}

// v210 input is only compatible with bit-depth of 10 bits
void x264_plane_copy_deinterleave_v210_altivec( uint16_t *dsty, intptr_t i_dsty,
                                                uint16_t *dstc, intptr_t i_dstc,
                                                uint32_t *src, intptr_t i_src, int w, int h )
{
#ifdef WORDS_BIGENDIAN
    const vec_u8_t masky[3] = {
        { 0x02, 0x01, 0x05, 0x04, 0x07, 0x06, 0x0A, 0x09, 0x0D, 0x0C, 0x0F, 0x0E, 0x12, 0x11, 0x15, 0x14 },
        { 0x07, 0x06, 0x0A, 0x09, 0x0D, 0x0C, 0x0F, 0x0E, 0x12, 0x11, 0x15, 0x14, 0x17, 0x16, 0x1A, 0x19 },
        { 0x0D, 0x0C, 0x0F, 0x0E, 0x12, 0x11, 0x15, 0x14, 0x17, 0x16, 0x1A, 0x19, 0x1D, 0x1C, 0x1F, 0x1E }
    };
    const vec_u8_t maskc[3] = {
        { 0x01, 0x00, 0x03, 0x02, 0x06, 0x05, 0x09, 0x08, 0x0B, 0x0A, 0x0E, 0x0D, 0x11, 0x10, 0x13, 0x12 },
        { 0x06, 0x05, 0x09, 0x08, 0x0B, 0x0A, 0x0E, 0x0D, 0x11, 0x10, 0x13, 0x12, 0x16, 0x15, 0x19, 0x18 },
        { 0x0B, 0x0A, 0x0E, 0x0D, 0x11, 0x10, 0x13, 0x12, 0x16, 0x15, 0x19, 0x18, 0x1B, 0x1A, 0x1E, 0x1D }
    };
#else
    const vec_u8_t masky[3] = {
        { 0x01, 0x02, 0x04, 0x05, 0x06, 0x07, 0x09, 0x0A, 0x0C, 0x0D, 0x0E, 0x0F, 0x11, 0x12, 0x14, 0x15 },
        { 0x06, 0x07, 0x09, 0x0A, 0x0C, 0x0D, 0x0E, 0x0F, 0x11, 0x12, 0x14, 0x15, 0x16, 0x17, 0x19, 0x1A },
        { 0x0C, 0x0D, 0x0E, 0x0F, 0x11, 0x12, 0x14, 0x15, 0x16, 0x17, 0x19, 0x1A, 0x1C, 0x1D, 0x1E, 0x1F }
    };
    const vec_u8_t maskc[3] = {
        { 0x00, 0x01, 0x02, 0x03, 0x05, 0x06, 0x08, 0x09, 0x0A, 0x0B, 0x0D, 0x0E, 0x10, 0x11, 0x12, 0x13 },
        { 0x05, 0x06, 0x08, 0x09, 0x0A, 0x0B, 0x0D, 0x0E, 0x10, 0x11, 0x12, 0x13, 0x15, 0x16, 0x18, 0x19 },
        { 0x0A, 0x0B, 0x0D, 0x0E, 0x10, 0x11, 0x12, 0x13, 0x15, 0x16, 0x18, 0x19, 0x1A, 0x1B, 0x1D, 0x1E }
    };
#endif
    const vec_u16_t shift[3] = {
        { 0, 4, 2, 0, 4, 2, 0, 4 },
        { 2, 0, 4, 2, 0, 4, 2, 0 },
        { 4, 2, 0, 4, 2, 0, 4, 2 }
    };

    vec_u16_t dstv;
    vec_u16_t and_mask = vec_sub( vec_sl( vec_splat_u16( 1 ), vec_splat_u16( 10 ) ), vec_splat_u16( 1 ) );
    vec_u32_t srcv[4];

    for( int i = 0; i < h; i++ )
    {
        int offset = 0;
        int s = 0;

        for( int j = 0; j < w; j += 24 )
        {
            LOAD_SRC( 0 );
            STORE_8( maskc[0], shift[0], dstc, 0, 1 );
            STORE_8( masky[0], shift[1], dsty, 0, 1 );
            offset += 16;

            LOAD_SRC( 2 );
            STORE_8( maskc[1], shift[1], dstc, 1, 2 );
            STORE_8( masky[1], shift[2], dsty, 1, 2 );
            offset += 16;

            STORE_8( maskc[2], shift[2], dstc, 2, 3 );
            STORE_8( masky[2], shift[0], dsty, 2, 3 );
            offset += 16;
        }

        dsty += i_dsty;
        dstc += i_dstc;
        src  += i_src;
    }
}

#endif // HIGH_BIT_DEPTH

void x264_mc_init_altivec( x264_mc_functions_t *pf )
{
#if HIGH_BIT_DEPTH
    pf->plane_copy_deinterleave_v210 = x264_plane_copy_deinterleave_v210_altivec;
#else // !HIGH_BIT_DEPTH
    pf->mc_luma   = mc_luma_altivec;
    pf->get_ref   = get_ref_altivec;
    pf->mc_chroma = mc_chroma_altivec;

    pf->copy_16x16_unaligned = mc_copy_w16_altivec;
    pf->copy[PIXEL_16x16] = mc_copy_w16_aligned_altivec;

    pf->hpel_filter = x264_hpel_filter_altivec;
    pf->frame_init_lowres_core = frame_init_lowres_core_altivec;

    pf->weight = mc_weight_wtab_altivec;

    pf->plane_copy_swap = plane_copy_swap_altivec;
    pf->plane_copy_interleave = plane_copy_interleave_altivec;
    pf->store_interleave_chroma = x264_store_interleave_chroma_altivec;
    pf->plane_copy_deinterleave = x264_plane_copy_deinterleave_altivec;
    pf->load_deinterleave_chroma_fenc = load_deinterleave_chroma_fenc_altivec;
#if HAVE_VSX
    pf->plane_copy_deinterleave_rgb = x264_plane_copy_deinterleave_rgb_altivec;
#endif // HAVE_VSX
#endif // !HIGH_BIT_DEPTH
}
