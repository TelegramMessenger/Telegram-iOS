/*****************************************************************************
 * pixel.c: ppc pixel metrics
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
#include "pixel.h"

#if !HIGH_BIT_DEPTH
/***********************************************************************
 * SAD routines
 **********************************************************************/

#define PIXEL_SAD_ALTIVEC( name, lx, ly, a, b )        \
static int name( uint8_t *pix1, intptr_t i_pix1,       \
                 uint8_t *pix2, intptr_t i_pix2 )      \
{                                                      \
    ALIGNED_16( int sum );                             \
                                                       \
    LOAD_ZERO;                                         \
    vec_u8_t  pix1v, pix2v;                            \
    vec_s32_t sumv = zero_s32v;                        \
    for( int y = 0; y < ly; y++ )                      \
    {                                                  \
        pix1v = vec_vsx_ld( 0, pix1 );                 \
        pix2v = vec_vsx_ld( 0, pix2 );                 \
        sumv = (vec_s32_t) vec_sum4s(                  \
                   vec_absd( pix1v, pix2v ),           \
                   (vec_u32_t) sumv );                 \
        pix1 += i_pix1;                                \
        pix2 += i_pix2;                                \
    }                                                  \
    sumv = vec_sum##a( sumv, zero_s32v );              \
    sumv = vec_splat( sumv, b );                       \
    vec_ste( sumv, 0, &sum );                          \
    return sum;                                        \
}

PIXEL_SAD_ALTIVEC( pixel_sad_16x16_altivec, 16, 16, s,  3 )
PIXEL_SAD_ALTIVEC( pixel_sad_8x16_altivec,  8,  16, 2s, 1 )
PIXEL_SAD_ALTIVEC( pixel_sad_16x8_altivec,  16, 8,  s,  3 )
PIXEL_SAD_ALTIVEC( pixel_sad_8x8_altivec,   8,  8,  2s, 1 )



/***********************************************************************
 * SATD routines
 **********************************************************************/

/***********************************************************************
 * VEC_HADAMAR
 ***********************************************************************
 * b[0] = a[0] + a[1] + a[2] + a[3]
 * b[1] = a[0] + a[1] - a[2] - a[3]
 * b[2] = a[0] - a[1] - a[2] + a[3]
 * b[3] = a[0] - a[1] + a[2] - a[3]
 **********************************************************************/
#define VEC_HADAMAR(a0,a1,a2,a3,b0,b1,b2,b3) \
    b2 = vec_add( a0, a1 ); \
    b3 = vec_add( a2, a3 ); \
    a0 = vec_sub( a0, a1 ); \
    a2 = vec_sub( a2, a3 ); \
    b0 = vec_add( b2, b3 ); \
    b1 = vec_sub( b2, b3 ); \
    b2 = vec_sub( a0, a2 ); \
    b3 = vec_add( a0, a2 )

/***********************************************************************
 * VEC_ABS
 ***********************************************************************
 * a: s16v
 *
 * a = abs(a)
 *
 * Call vec_sub()/vec_max() instead of vec_abs() because vec_abs()
 * actually also calls vec_splat(0), but we already have a null vector.
 **********************************************************************/
#define VEC_ABS(a)                            \
    a = vec_max( a, vec_sub( zero_s16v, a ) );

#define VEC_ABSOLUTE(a) (vec_u16_t)vec_max( a, vec_sub( zero_s16v, a ) )

/***********************************************************************
 * VEC_ADD_ABS
 ***********************************************************************
 * a:    s16v
 * b, c: s32v
 *
 * c[i] = abs(a[2*i]) + abs(a[2*i+1]) + [bi]
 **********************************************************************/
#define VEC_ADD_ABS(a,b,c) \
    VEC_ABS( a );          \
    c = vec_sum4s( a, b )

static ALWAYS_INLINE vec_s32_t add_abs_4( vec_s16_t a, vec_s16_t b,
                                          vec_s16_t c, vec_s16_t d )
{
    vec_s16_t t0 = vec_abs( a );
    vec_s16_t t1 = vec_abs( b );
    vec_s16_t t2 = vec_abs( c );
    vec_s16_t t3 = vec_abs( d );

    vec_s16_t s0 = vec_adds( t0, t1 );
    vec_s16_t s1 = vec_adds( t2, t3 );

    vec_s32_t s01 = vec_sum4s( s0, vec_splat_s32( 0 ) );
    vec_s32_t s23 = vec_sum4s( s1, vec_splat_s32( 0 ) );

    return vec_add( s01, s23 );
}

/***********************************************************************
 * SATD 4x4
 **********************************************************************/
static int pixel_satd_4x4_altivec( uint8_t *pix1, intptr_t i_pix1,
                                   uint8_t *pix2, intptr_t i_pix2 )
{
    ALIGNED_16( int i_satd );

    PREP_DIFF;
    vec_s16_t diff0v, diff1v, diff2v, diff3v;
    vec_s16_t temp0v, temp1v, temp2v, temp3v;
    vec_s32_t satdv;

    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 4, diff0v );
    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 4, diff1v );
    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 4, diff2v );
    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 4, diff3v );

    /* Hadamar H */
    VEC_HADAMAR( diff0v, diff1v, diff2v, diff3v,
                 temp0v, temp1v, temp2v, temp3v );

    VEC_TRANSPOSE_4( temp0v, temp1v, temp2v, temp3v,
                     diff0v, diff1v, diff2v, diff3v );
    /* Hadamar V */
    VEC_HADAMAR( diff0v, diff1v, diff2v, diff3v,
                 temp0v, temp1v, temp2v, temp3v );

    satdv = add_abs_4( temp0v, temp1v, temp2v, temp3v );

    satdv = vec_sum2s( satdv, zero_s32v );
    satdv = vec_splat( satdv, 1 );
    vec_ste( satdv, 0, &i_satd );

    return i_satd >> 1;
}

/***********************************************************************
 * SATD 4x8
 **********************************************************************/
static int pixel_satd_4x8_altivec( uint8_t *pix1, intptr_t i_pix1,
                                   uint8_t *pix2, intptr_t i_pix2 )
{
    ALIGNED_16( int i_satd );

    PREP_DIFF;
    vec_s16_t diff0v, diff1v, diff2v, diff3v;
    vec_s16_t temp0v, temp1v, temp2v, temp3v;
    vec_s32_t satdv;

    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 4, diff0v );
    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 4, diff1v );
    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 4, diff2v );
    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 4, diff3v );
    VEC_HADAMAR( diff0v, diff1v, diff2v, diff3v,
                 temp0v, temp1v, temp2v, temp3v );
    VEC_TRANSPOSE_4( temp0v, temp1v, temp2v, temp3v,
                     diff0v, diff1v, diff2v, diff3v );
    VEC_HADAMAR( diff0v, diff1v, diff2v, diff3v,
                 temp0v, temp1v, temp2v, temp3v );

    satdv = add_abs_4( temp0v, temp1v, temp2v, temp3v );

    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 4, diff0v );
    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 4, diff1v );
    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 4, diff2v );
    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 4, diff3v );
    VEC_HADAMAR( diff0v, diff1v, diff2v, diff3v,
                 temp0v, temp1v, temp2v, temp3v );
    VEC_TRANSPOSE_4( temp0v, temp1v, temp2v, temp3v,
                     diff0v, diff1v, diff2v, diff3v );
    VEC_HADAMAR( diff0v, diff1v, diff2v, diff3v,
                 temp0v, temp1v, temp2v, temp3v );

    satdv = vec_add( satdv, add_abs_4( temp0v, temp1v, temp2v, temp3v ) );

    satdv = vec_sum2s( satdv, zero_s32v );
    satdv = vec_splat( satdv, 1 );
    vec_ste( satdv, 0, &i_satd );

    return i_satd >> 1;
}

static ALWAYS_INLINE vec_s32_t add_abs_8( vec_s16_t a, vec_s16_t b,
                                          vec_s16_t c, vec_s16_t d,
                                          vec_s16_t e, vec_s16_t f,
                                          vec_s16_t g, vec_s16_t h )
{
    vec_s16_t t0 = vec_abs( a );
    vec_s16_t t1 = vec_abs( b );
    vec_s16_t t2 = vec_abs( c );
    vec_s16_t t3 = vec_abs( d );

    vec_s16_t s0 = vec_adds( t0, t1 );
    vec_s16_t s1 = vec_adds( t2, t3 );

    vec_s32_t s01 = vec_sum4s( s0, vec_splat_s32( 0 ) );
    vec_s32_t s23 = vec_sum4s( s1, vec_splat_s32( 0 ) );

    vec_s16_t t4 = vec_abs( e );
    vec_s16_t t5 = vec_abs( f );
    vec_s16_t t6 = vec_abs( g );
    vec_s16_t t7 = vec_abs( h );

    vec_s16_t s2 = vec_adds( t4, t5 );
    vec_s16_t s3 = vec_adds( t6, t7 );

    vec_s32_t s0145 = vec_sum4s( s2, s01 );
    vec_s32_t s2367 = vec_sum4s( s3, s23 );

    return vec_add( s0145, s2367 );
}

/***********************************************************************
 * SATD 8x4
 **********************************************************************/
static int pixel_satd_8x4_altivec( uint8_t *pix1, intptr_t i_pix1,
                                   uint8_t *pix2, intptr_t i_pix2 )
{
    ALIGNED_16( int i_satd );

    PREP_DIFF;
    vec_s16_t diff0v, diff1v, diff2v, diff3v,
              diff4v, diff5v, diff6v, diff7v;
    vec_s16_t temp0v, temp1v, temp2v, temp3v,
              temp4v, temp5v, temp6v, temp7v;
    vec_s32_t satdv;

    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 8, diff0v );
    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 8, diff1v );
    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 8, diff2v );
    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 8, diff3v );

    VEC_HADAMAR( diff0v, diff1v, diff2v, diff3v,
                 temp0v, temp1v, temp2v, temp3v );
    /* This causes warnings because temp4v...temp7v haven't be set,
       but we don't care */
    VEC_TRANSPOSE_8( temp0v, temp1v, temp2v, temp3v,
                     temp4v, temp5v, temp6v, temp7v,
                     diff0v, diff1v, diff2v, diff3v,
                     diff4v, diff5v, diff6v, diff7v );
    VEC_HADAMAR( diff0v, diff1v, diff2v, diff3v,
                 temp0v, temp1v, temp2v, temp3v );
    VEC_HADAMAR( diff4v, diff5v, diff6v, diff7v,
                 temp4v, temp5v, temp6v, temp7v );

    satdv = add_abs_8( temp0v, temp1v, temp2v, temp3v,
                       temp4v, temp5v, temp6v, temp7v );

    satdv = vec_sum2s( satdv, zero_s32v );
    satdv = vec_splat( satdv, 1 );
    vec_ste( satdv, 0, &i_satd );

    return i_satd >> 1;
}

/***********************************************************************
 * SATD 8x8
 **********************************************************************/
static int pixel_satd_8x8_altivec( uint8_t *pix1, intptr_t i_pix1,
                                   uint8_t *pix2, intptr_t i_pix2 )
{
    ALIGNED_16( int i_satd );

    PREP_DIFF;
    vec_s16_t diff0v, diff1v, diff2v, diff3v,
              diff4v, diff5v, diff6v, diff7v;
    vec_s16_t temp0v, temp1v, temp2v, temp3v,
              temp4v, temp5v, temp6v, temp7v;
    vec_s32_t satdv;

    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 8, diff0v );
    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 8, diff1v );
    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 8, diff2v );
    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 8, diff3v );
    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 8, diff4v );
    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 8, diff5v );
    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 8, diff6v );
    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 8, diff7v );

    VEC_HADAMAR( diff0v, diff1v, diff2v, diff3v,
                 temp0v, temp1v, temp2v, temp3v );
    VEC_HADAMAR( diff4v, diff5v, diff6v, diff7v,
                 temp4v, temp5v, temp6v, temp7v );

    VEC_TRANSPOSE_8( temp0v, temp1v, temp2v, temp3v,
                     temp4v, temp5v, temp6v, temp7v,
                     diff0v, diff1v, diff2v, diff3v,
                     diff4v, diff5v, diff6v, diff7v );

    VEC_HADAMAR( diff0v, diff1v, diff2v, diff3v,
                 temp0v, temp1v, temp2v, temp3v );
    VEC_HADAMAR( diff4v, diff5v, diff6v, diff7v,
                 temp4v, temp5v, temp6v, temp7v );

    satdv = add_abs_8( temp0v, temp1v, temp2v, temp3v,
                       temp4v, temp5v, temp6v, temp7v );

    satdv = vec_sums( satdv, zero_s32v );
    satdv = vec_splat( satdv, 3 );
    vec_ste( satdv, 0, &i_satd );

    return i_satd >> 1;
}

/***********************************************************************
 * SATD 8x16
 **********************************************************************/
static int pixel_satd_8x16_altivec( uint8_t *pix1, intptr_t i_pix1,
                                    uint8_t *pix2, intptr_t i_pix2 )
{
    ALIGNED_16( int i_satd );

    PREP_DIFF;
    vec_s16_t diff0v, diff1v, diff2v, diff3v,
              diff4v, diff5v, diff6v, diff7v;
    vec_s16_t temp0v, temp1v, temp2v, temp3v,
              temp4v, temp5v, temp6v, temp7v;
    vec_s32_t satdv;

    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 8, diff0v );
    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 8, diff1v );
    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 8, diff2v );
    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 8, diff3v );
    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 8, diff4v );
    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 8, diff5v );
    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 8, diff6v );
    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 8, diff7v );
    VEC_HADAMAR( diff0v, diff1v, diff2v, diff3v,
                 temp0v, temp1v, temp2v, temp3v );
    VEC_HADAMAR( diff4v, diff5v, diff6v, diff7v,
                 temp4v, temp5v, temp6v, temp7v );
    VEC_TRANSPOSE_8( temp0v, temp1v, temp2v, temp3v,
                     temp4v, temp5v, temp6v, temp7v,
                     diff0v, diff1v, diff2v, diff3v,
                     diff4v, diff5v, diff6v, diff7v );
    VEC_HADAMAR( diff0v, diff1v, diff2v, diff3v,
                 temp0v, temp1v, temp2v, temp3v );
    VEC_HADAMAR( diff4v, diff5v, diff6v, diff7v,
                 temp4v, temp5v, temp6v, temp7v );

    satdv = add_abs_8( temp0v, temp1v, temp2v, temp3v,
                       temp4v, temp5v, temp6v, temp7v );

    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 8, diff0v );
    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 8, diff1v );
    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 8, diff2v );
    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 8, diff3v );
    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 8, diff4v );
    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 8, diff5v );
    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 8, diff6v );
    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 8, diff7v );
    VEC_HADAMAR( diff0v, diff1v, diff2v, diff3v,
                 temp0v, temp1v, temp2v, temp3v );
    VEC_HADAMAR( diff4v, diff5v, diff6v, diff7v,
                 temp4v, temp5v, temp6v, temp7v );
    VEC_TRANSPOSE_8( temp0v, temp1v, temp2v, temp3v,
                     temp4v, temp5v, temp6v, temp7v,
                     diff0v, diff1v, diff2v, diff3v,
                     diff4v, diff5v, diff6v, diff7v );
    VEC_HADAMAR( diff0v, diff1v, diff2v, diff3v,
                 temp0v, temp1v, temp2v, temp3v );
    VEC_HADAMAR( diff4v, diff5v, diff6v, diff7v,
                 temp4v, temp5v, temp6v, temp7v );

    satdv = vec_add( satdv, add_abs_8( temp0v, temp1v, temp2v, temp3v,
                                       temp4v, temp5v, temp6v, temp7v ) );

    satdv = vec_sums( satdv, zero_s32v );
    satdv = vec_splat( satdv, 3 );
    vec_ste( satdv, 0, &i_satd );

    return i_satd >> 1;
}

/***********************************************************************
 * SATD 16x8
 **********************************************************************/
static int pixel_satd_16x8_altivec( uint8_t *pix1, intptr_t i_pix1,
                                    uint8_t *pix2, intptr_t i_pix2 )
{
    ALIGNED_16( int i_satd );

    LOAD_ZERO;
    vec_s32_t satdv;
    vec_s16_t pix1v, pix2v;
    vec_s16_t diffh0v, diffh1v, diffh2v, diffh3v,
              diffh4v, diffh5v, diffh6v, diffh7v;
    vec_s16_t diffl0v, diffl1v, diffl2v, diffl3v,
              diffl4v, diffl5v, diffl6v, diffl7v;
    vec_s16_t temp0v, temp1v, temp2v, temp3v,
              temp4v, temp5v, temp6v, temp7v;

    VEC_DIFF_HL( pix1, i_pix1, pix2, i_pix2, diffh0v, diffl0v );
    VEC_DIFF_HL( pix1, i_pix1, pix2, i_pix2, diffh1v, diffl1v );
    VEC_DIFF_HL( pix1, i_pix1, pix2, i_pix2, diffh2v, diffl2v );
    VEC_DIFF_HL( pix1, i_pix1, pix2, i_pix2, diffh3v, diffl3v );
    VEC_DIFF_HL( pix1, i_pix1, pix2, i_pix2, diffh4v, diffl4v );
    VEC_DIFF_HL( pix1, i_pix1, pix2, i_pix2, diffh5v, diffl5v );
    VEC_DIFF_HL( pix1, i_pix1, pix2, i_pix2, diffh6v, diffl6v );
    VEC_DIFF_HL( pix1, i_pix1, pix2, i_pix2, diffh7v, diffl7v );

    VEC_HADAMAR( diffh0v, diffh1v, diffh2v, diffh3v,
                 temp0v, temp1v, temp2v, temp3v );
    VEC_HADAMAR( diffh4v, diffh5v, diffh6v, diffh7v,
                 temp4v, temp5v, temp6v, temp7v );

    VEC_TRANSPOSE_8( temp0v, temp1v, temp2v, temp3v,
                     temp4v, temp5v, temp6v, temp7v,
                     diffh0v, diffh1v, diffh2v, diffh3v,
                     diffh4v, diffh5v, diffh6v, diffh7v );

    VEC_HADAMAR( diffh0v, diffh1v, diffh2v, diffh3v,
                 temp0v, temp1v, temp2v, temp3v );
    VEC_HADAMAR( diffh4v, diffh5v, diffh6v, diffh7v,
                 temp4v, temp5v, temp6v, temp7v );

    satdv = add_abs_8( temp0v, temp1v, temp2v, temp3v,
                       temp4v, temp5v, temp6v, temp7v );

    VEC_HADAMAR( diffl0v, diffl1v, diffl2v, diffl3v,
                 temp0v, temp1v, temp2v, temp3v );
    VEC_HADAMAR( diffl4v, diffl5v, diffl6v, diffl7v,
                 temp4v, temp5v, temp6v, temp7v );

    VEC_TRANSPOSE_8( temp0v, temp1v, temp2v, temp3v,
                     temp4v, temp5v, temp6v, temp7v,
                     diffl0v, diffl1v, diffl2v, diffl3v,
                     diffl4v, diffl5v, diffl6v, diffl7v );

    VEC_HADAMAR( diffl0v, diffl1v, diffl2v, diffl3v,
                 temp0v, temp1v, temp2v, temp3v );
    VEC_HADAMAR( diffl4v, diffl5v, diffl6v, diffl7v,
                 temp4v, temp5v, temp6v, temp7v );

    satdv = vec_add( satdv, add_abs_8( temp0v, temp1v, temp2v, temp3v,
                                       temp4v, temp5v, temp6v, temp7v ) );

    satdv = vec_sums( satdv, zero_s32v );
    satdv = vec_splat( satdv, 3 );
    vec_ste( satdv, 0, &i_satd );

    return i_satd >> 1;
}

/***********************************************************************
 * SATD 16x16
 **********************************************************************/
static int pixel_satd_16x16_altivec( uint8_t *pix1, intptr_t i_pix1,
                                     uint8_t *pix2, intptr_t i_pix2 )
{
    ALIGNED_16( int i_satd );

    LOAD_ZERO;
    vec_s32_t satdv;
    vec_s16_t pix1v, pix2v;
    vec_s16_t diffh0v, diffh1v, diffh2v, diffh3v,
              diffh4v, diffh5v, diffh6v, diffh7v;
    vec_s16_t diffl0v, diffl1v, diffl2v, diffl3v,
              diffl4v, diffl5v, diffl6v, diffl7v;
    vec_s16_t temp0v, temp1v, temp2v, temp3v,
              temp4v, temp5v, temp6v, temp7v;

    VEC_DIFF_HL( pix1, i_pix1, pix2, i_pix2, diffh0v, diffl0v );
    VEC_DIFF_HL( pix1, i_pix1, pix2, i_pix2, diffh1v, diffl1v );
    VEC_DIFF_HL( pix1, i_pix1, pix2, i_pix2, diffh2v, diffl2v );
    VEC_DIFF_HL( pix1, i_pix1, pix2, i_pix2, diffh3v, diffl3v );
    VEC_DIFF_HL( pix1, i_pix1, pix2, i_pix2, diffh4v, diffl4v );
    VEC_DIFF_HL( pix1, i_pix1, pix2, i_pix2, diffh5v, diffl5v );
    VEC_DIFF_HL( pix1, i_pix1, pix2, i_pix2, diffh6v, diffl6v );
    VEC_DIFF_HL( pix1, i_pix1, pix2, i_pix2, diffh7v, diffl7v );
    VEC_HADAMAR( diffh0v, diffh1v, diffh2v, diffh3v,
                 temp0v, temp1v, temp2v, temp3v );
    VEC_HADAMAR( diffh4v, diffh5v, diffh6v, diffh7v,
                 temp4v, temp5v, temp6v, temp7v );
    VEC_TRANSPOSE_8( temp0v, temp1v, temp2v, temp3v,
                     temp4v, temp5v, temp6v, temp7v,
                     diffh0v, diffh1v, diffh2v, diffh3v,
                     diffh4v, diffh5v, diffh6v, diffh7v );
    VEC_HADAMAR( diffh0v, diffh1v, diffh2v, diffh3v,
                 temp0v, temp1v, temp2v, temp3v );
    VEC_HADAMAR( diffh4v, diffh5v, diffh6v, diffh7v,
                 temp4v, temp5v, temp6v, temp7v );

    satdv = add_abs_8( temp0v, temp1v, temp2v, temp3v,
                       temp4v, temp5v, temp6v, temp7v );

    VEC_HADAMAR( diffl0v, diffl1v, diffl2v, diffl3v,
                 temp0v, temp1v, temp2v, temp3v );
    VEC_HADAMAR( diffl4v, diffl5v, diffl6v, diffl7v,
                 temp4v, temp5v, temp6v, temp7v );
    VEC_TRANSPOSE_8( temp0v, temp1v, temp2v, temp3v,
                     temp4v, temp5v, temp6v, temp7v,
                     diffl0v, diffl1v, diffl2v, diffl3v,
                     diffl4v, diffl5v, diffl6v, diffl7v );
    VEC_HADAMAR( diffl0v, diffl1v, diffl2v, diffl3v,
                 temp0v, temp1v, temp2v, temp3v );
    VEC_HADAMAR( diffl4v, diffl5v, diffl6v, diffl7v,
                 temp4v, temp5v, temp6v, temp7v );

    satdv = vec_add( satdv, add_abs_8( temp0v, temp1v, temp2v, temp3v,
                                       temp4v, temp5v, temp6v, temp7v ) );

    VEC_DIFF_HL( pix1, i_pix1, pix2, i_pix2, diffh0v, diffl0v );
    VEC_DIFF_HL( pix1, i_pix1, pix2, i_pix2, diffh1v, diffl1v );
    VEC_DIFF_HL( pix1, i_pix1, pix2, i_pix2, diffh2v, diffl2v );
    VEC_DIFF_HL( pix1, i_pix1, pix2, i_pix2, diffh3v, diffl3v );
    VEC_DIFF_HL( pix1, i_pix1, pix2, i_pix2, diffh4v, diffl4v );
    VEC_DIFF_HL( pix1, i_pix1, pix2, i_pix2, diffh5v, diffl5v );
    VEC_DIFF_HL( pix1, i_pix1, pix2, i_pix2, diffh6v, diffl6v );
    VEC_DIFF_HL( pix1, i_pix1, pix2, i_pix2, diffh7v, diffl7v );
    VEC_HADAMAR( diffh0v, diffh1v, diffh2v, diffh3v,
                 temp0v, temp1v, temp2v, temp3v );
    VEC_HADAMAR( diffh4v, diffh5v, diffh6v, diffh7v,
                 temp4v, temp5v, temp6v, temp7v );
    VEC_TRANSPOSE_8( temp0v, temp1v, temp2v, temp3v,
                     temp4v, temp5v, temp6v, temp7v,
                     diffh0v, diffh1v, diffh2v, diffh3v,
                     diffh4v, diffh5v, diffh6v, diffh7v );
    VEC_HADAMAR( diffh0v, diffh1v, diffh2v, diffh3v,
                 temp0v, temp1v, temp2v, temp3v );
    VEC_HADAMAR( diffh4v, diffh5v, diffh6v, diffh7v,
                 temp4v, temp5v, temp6v, temp7v );

    satdv = vec_add( satdv, add_abs_8( temp0v, temp1v, temp2v, temp3v,
                                       temp4v, temp5v, temp6v, temp7v ) );

    VEC_HADAMAR( diffl0v, diffl1v, diffl2v, diffl3v,
                 temp0v, temp1v, temp2v, temp3v );
    VEC_HADAMAR( diffl4v, diffl5v, diffl6v, diffl7v,
                 temp4v, temp5v, temp6v, temp7v );
    VEC_TRANSPOSE_8( temp0v, temp1v, temp2v, temp3v,
                     temp4v, temp5v, temp6v, temp7v,
                     diffl0v, diffl1v, diffl2v, diffl3v,
                     diffl4v, diffl5v, diffl6v, diffl7v );
    VEC_HADAMAR( diffl0v, diffl1v, diffl2v, diffl3v,
                 temp0v, temp1v, temp2v, temp3v );
    VEC_HADAMAR( diffl4v, diffl5v, diffl6v, diffl7v,
                 temp4v, temp5v, temp6v, temp7v );

    satdv = vec_add( satdv, add_abs_8( temp0v, temp1v, temp2v, temp3v,
                                       temp4v, temp5v, temp6v, temp7v ) );

    satdv = vec_sums( satdv, zero_s32v );
    satdv = vec_splat( satdv, 3 );
    vec_ste( satdv, 0, &i_satd );

    return i_satd >> 1;
}



/***********************************************************************
* Interleaved SAD routines
**********************************************************************/

static void pixel_sad_x4_16x16_altivec( uint8_t *fenc,
                                        uint8_t *pix0, uint8_t *pix1,
                                        uint8_t *pix2, uint8_t *pix3,
                                        intptr_t i_stride, int scores[4] )
{
    ALIGNED_16( int sum0 );
    ALIGNED_16( int sum1 );
    ALIGNED_16( int sum2 );
    ALIGNED_16( int sum3 );

    LOAD_ZERO;
    vec_u8_t fencv, pix0v, pix1v, pix2v, pix3v;
    vec_s32_t sum0v, sum1v, sum2v, sum3v;

    sum0v = vec_splat_s32(0);
    sum1v = vec_splat_s32(0);
    sum2v = vec_splat_s32(0);
    sum3v = vec_splat_s32(0);

    for( int y = 0; y < 8; y++ )
    {
        pix0v = vec_vsx_ld( 0, pix0 );
        pix0 += i_stride;

        pix1v = vec_vsx_ld( 0, pix1 );
        pix1 += i_stride;

        fencv = vec_ld(0, fenc);
        fenc += FENC_STRIDE;

        pix2v = vec_vsx_ld( 0, pix2 );
        pix2 += i_stride;

        pix3v = vec_vsx_ld( 0, pix3 );
        pix3 += i_stride;

        sum0v = (vec_s32_t) vec_sum4s( vec_absd( fencv, pix0v ), (vec_u32_t) sum0v );
        sum1v = (vec_s32_t) vec_sum4s( vec_absd( fencv, pix1v ), (vec_u32_t) sum1v );
        sum2v = (vec_s32_t) vec_sum4s( vec_absd( fencv, pix2v ), (vec_u32_t) sum2v );
        sum3v = (vec_s32_t) vec_sum4s( vec_absd( fencv, pix3v ), (vec_u32_t) sum3v );

        pix0v = vec_vsx_ld( 0, pix0 );
        pix0 += i_stride;

        pix1v = vec_vsx_ld( 0, pix1 );
        pix1 += i_stride;

        fencv = vec_ld(0, fenc);
        fenc += FENC_STRIDE;

        pix2v = vec_vsx_ld( 0, pix2 );
        pix2 += i_stride;

        pix3v = vec_vsx_ld( 0, pix3 );
        pix3 += i_stride;

        sum0v = (vec_s32_t) vec_sum4s( vec_absd( fencv, pix0v ), (vec_u32_t) sum0v );
        sum1v = (vec_s32_t) vec_sum4s( vec_absd( fencv, pix1v ), (vec_u32_t) sum1v );
        sum2v = (vec_s32_t) vec_sum4s( vec_absd( fencv, pix2v ), (vec_u32_t) sum2v );
        sum3v = (vec_s32_t) vec_sum4s( vec_absd( fencv, pix3v ), (vec_u32_t) sum3v );

    }

    sum0v = vec_sums( sum0v, zero_s32v );
    sum1v = vec_sums( sum1v, zero_s32v );
    sum2v = vec_sums( sum2v, zero_s32v );
    sum3v = vec_sums( sum3v, zero_s32v );

    sum0v = vec_splat( sum0v, 3 );
    sum1v = vec_splat( sum1v, 3 );
    sum2v = vec_splat( sum2v, 3 );
    sum3v = vec_splat( sum3v, 3 );

    vec_ste( sum0v, 0, &sum0);
    vec_ste( sum1v, 0, &sum1);
    vec_ste( sum2v, 0, &sum2);
    vec_ste( sum3v, 0, &sum3);

    scores[0] = sum0;
    scores[1] = sum1;
    scores[2] = sum2;
    scores[3] = sum3;
}

static void pixel_sad_x3_16x16_altivec( uint8_t *fenc, uint8_t *pix0,
                                        uint8_t *pix1, uint8_t *pix2,
                                        intptr_t i_stride, int scores[3] )
{
    ALIGNED_16( int sum0 );
    ALIGNED_16( int sum1 );
    ALIGNED_16( int sum2 );

    LOAD_ZERO;
    vec_u8_t fencv, pix0v, pix1v, pix2v;
    vec_s32_t sum0v, sum1v, sum2v;

    sum0v = vec_splat_s32(0);
    sum1v = vec_splat_s32(0);
    sum2v = vec_splat_s32(0);

    for( int y = 0; y < 8; y++ )
    {
        pix0v = vec_vsx_ld( 0, pix0 );
        pix0 += i_stride;

        pix1v = vec_vsx_ld( 0, pix1 );
        pix1 += i_stride;

        fencv = vec_ld(0, fenc);
        fenc += FENC_STRIDE;

        pix2v = vec_vsx_ld( 0, pix2 );
        pix2 += i_stride;

        sum0v = (vec_s32_t) vec_sum4s( vec_absd( fencv, pix0v ), (vec_u32_t) sum0v );
        sum1v = (vec_s32_t) vec_sum4s( vec_absd( fencv, pix1v ), (vec_u32_t) sum1v );
        sum2v = (vec_s32_t) vec_sum4s( vec_absd( fencv, pix2v ), (vec_u32_t) sum2v );
        pix0v = vec_vsx_ld( 0, pix0 );
        pix0 += i_stride;


        pix1v = vec_vsx_ld( 0, pix1 );
        pix1 += i_stride;

        fencv = vec_ld(0, fenc);
        fenc += FENC_STRIDE;

        pix2v = vec_vsx_ld( 0, pix2 );
        pix2 += i_stride;

        sum0v = (vec_s32_t) vec_sum4s( vec_absd( fencv, pix0v ), (vec_u32_t) sum0v );
        sum1v = (vec_s32_t) vec_sum4s( vec_absd( fencv, pix1v ), (vec_u32_t) sum1v );
        sum2v = (vec_s32_t) vec_sum4s( vec_absd( fencv, pix2v ), (vec_u32_t) sum2v );
    }

    sum0v = vec_sums( sum0v, zero_s32v );
    sum1v = vec_sums( sum1v, zero_s32v );
    sum2v = vec_sums( sum2v, zero_s32v );

    sum0v = vec_splat( sum0v, 3 );
    sum1v = vec_splat( sum1v, 3 );
    sum2v = vec_splat( sum2v, 3 );

    vec_ste( sum0v, 0, &sum0);
    vec_ste( sum1v, 0, &sum1);
    vec_ste( sum2v, 0, &sum2);

    scores[0] = sum0;
    scores[1] = sum1;
    scores[2] = sum2;
}

static void pixel_sad_x4_16x8_altivec( uint8_t *fenc, uint8_t *pix0, uint8_t *pix1, uint8_t *pix2,
                                       uint8_t *pix3, intptr_t i_stride, int scores[4] )
{
    ALIGNED_16( int sum0 );
    ALIGNED_16( int sum1 );
    ALIGNED_16( int sum2 );
    ALIGNED_16( int sum3 );

    LOAD_ZERO;
    vec_u8_t fencv, pix0v, pix1v, pix2v, pix3v;
    vec_s32_t sum0v, sum1v, sum2v, sum3v;

    sum0v = vec_splat_s32(0);
    sum1v = vec_splat_s32(0);
    sum2v = vec_splat_s32(0);
    sum3v = vec_splat_s32(0);

    for( int y = 0; y < 4; y++ )
    {
        pix0v = vec_vsx_ld( 0, pix0 );
        pix0 += i_stride;

        pix1v = vec_vsx_ld( 0, pix1 );
        pix1 += i_stride;

        fencv = vec_ld( 0, fenc );
        fenc += FENC_STRIDE;

        pix2v = vec_vsx_ld( 0, pix2 );
        pix2 += i_stride;

        pix3v = vec_vsx_ld( 0, pix3 );
        pix3 += i_stride;

        sum0v = (vec_s32_t) vec_sum4s( vec_absd( fencv, pix0v ), (vec_u32_t) sum0v );
        sum1v = (vec_s32_t) vec_sum4s( vec_absd( fencv, pix1v ), (vec_u32_t) sum1v );
        sum2v = (vec_s32_t) vec_sum4s( vec_absd( fencv, pix2v ), (vec_u32_t) sum2v );
        sum3v = (vec_s32_t) vec_sum4s( vec_absd( fencv, pix3v ), (vec_u32_t) sum3v );

        pix0v = vec_vsx_ld( 0, pix0 );
        pix0 += i_stride;

        pix1v = vec_vsx_ld( 0, pix1 );
        pix1 += i_stride;

        fencv = vec_ld(0, fenc);
        fenc += FENC_STRIDE;

        pix2v = vec_vsx_ld( 0, pix2 );
        pix2 += i_stride;

        pix3v = vec_vsx_ld( 0, pix3 );
        pix3 += i_stride;

        sum0v = (vec_s32_t) vec_sum4s( vec_absd( fencv, pix0v ), (vec_u32_t) sum0v );
        sum1v = (vec_s32_t) vec_sum4s( vec_absd( fencv, pix1v ), (vec_u32_t) sum1v );
        sum2v = (vec_s32_t) vec_sum4s( vec_absd( fencv, pix2v ), (vec_u32_t) sum2v );
        sum3v = (vec_s32_t) vec_sum4s( vec_absd( fencv, pix3v ), (vec_u32_t) sum3v );
    }

    sum0v = vec_sums( sum0v, zero_s32v );
    sum1v = vec_sums( sum1v, zero_s32v );
    sum2v = vec_sums( sum2v, zero_s32v );
    sum3v = vec_sums( sum3v, zero_s32v );

    sum0v = vec_splat( sum0v, 3 );
    sum1v = vec_splat( sum1v, 3 );
    sum2v = vec_splat( sum2v, 3 );
    sum3v = vec_splat( sum3v, 3 );

    vec_ste( sum0v, 0, &sum0);
    vec_ste( sum1v, 0, &sum1);
    vec_ste( sum2v, 0, &sum2);
    vec_ste( sum3v, 0, &sum3);

    scores[0] = sum0;
    scores[1] = sum1;
    scores[2] = sum2;
    scores[3] = sum3;
}

#define PROCESS_PIXS                                                                  \
        vec_u8_t pix0vH = vec_vsx_ld( 0, pix0 );                                      \
        pix0 += i_stride;                                                             \
                                                                                      \
        vec_u8_t pix1vH = vec_vsx_ld( 0, pix1 );                                      \
        pix1 += i_stride;                                                             \
                                                                                      \
        vec_u8_t fencvH = vec_vsx_ld( 0, fenc );                                      \
        fenc += FENC_STRIDE;                                                          \
                                                                                      \
        vec_u8_t pix2vH = vec_vsx_ld( 0, pix2 );                                      \
        pix2 += i_stride;                                                             \
                                                                                      \
        vec_u8_t pix0vL = vec_vsx_ld( 0, pix0 );                                      \
        pix0 += i_stride;                                                             \
                                                                                      \
        vec_u8_t pix1vL = vec_vsx_ld( 0, pix1 );                                      \
        pix1 += i_stride;                                                             \
                                                                                      \
        vec_u8_t fencvL = vec_vsx_ld( 0, fenc );                                      \
        fenc += FENC_STRIDE;                                                          \
                                                                                      \
        vec_u8_t pix2vL = vec_vsx_ld( 0, pix2 );                                      \
        pix2 += i_stride;                                                             \
                                                                                      \
        fencv = xxpermdi( fencvH, fencvL, 0 );                                        \
        pix0v = xxpermdi( pix0vH, pix0vL, 0 );                                        \
        pix1v = xxpermdi( pix1vH, pix1vL, 0 );                                        \
        pix2v = xxpermdi( pix2vH, pix2vL, 0 );                                        \
                                                                                      \
        sum0v = (vec_s32_t) vec_sum4s( vec_absd( fencv, pix0v ), (vec_u32_t) sum0v ); \
        sum1v = (vec_s32_t) vec_sum4s( vec_absd( fencv, pix1v ), (vec_u32_t) sum1v ); \
        sum2v = (vec_s32_t) vec_sum4s( vec_absd( fencv, pix2v ), (vec_u32_t) sum2v );

#define PIXEL_SAD_X3_ALTIVEC( name, ly )            \
static int name( uint8_t *fenc, uint8_t *pix0,      \
                 uint8_t *pix1, uint8_t *pix2,      \
                 intptr_t i_stride, int scores[3] ) \
{                                                   \
    ALIGNED_16( int sum0 );                         \
    ALIGNED_16( int sum1 );                         \
    ALIGNED_16( int sum2 );                         \
                                                    \
    LOAD_ZERO;                                      \
    vec_u8_t fencv, pix0v, pix1v, pix2v;            \
    vec_s32_t sum0v, sum1v, sum2v;                  \
                                                    \
    sum0v = vec_splat_s32( 0 );                     \
    sum1v = vec_splat_s32( 0 );                     \
    sum2v = vec_splat_s32( 0 );                     \
                                                    \
    for( int y = 0; y < ly; y++ )                   \
    {                                               \
        PROCESS_PIXS                                \
    }                                               \
                                                    \
    sum0v = vec_sums( sum0v, zero_s32v );           \
    sum1v = vec_sums( sum1v, zero_s32v );           \
    sum2v = vec_sums( sum2v, zero_s32v );           \
                                                    \
    sum0v = vec_splat( sum0v, 3 );                  \
    sum1v = vec_splat( sum1v, 3 );                  \
    sum2v = vec_splat( sum2v, 3 );                  \
                                                    \
    vec_ste( sum0v, 0, &sum0 );                     \
    vec_ste( sum1v, 0, &sum1 );                     \
    vec_ste( sum2v, 0, &sum2 );                     \
                                                    \
    scores[0] = sum0;                               \
    scores[1] = sum1;                               \
    scores[2] = sum2;                               \
}

PIXEL_SAD_X3_ALTIVEC( pixel_sad_x3_8x8_altivec, 4 )
PIXEL_SAD_X3_ALTIVEC( pixel_sad_x3_8x16_altivec, 8 )

static void pixel_sad_x3_16x8_altivec( uint8_t *fenc, uint8_t *pix0,
                                       uint8_t *pix1, uint8_t *pix2,
                                       intptr_t i_stride, int scores[3] )
{
    ALIGNED_16( int sum0 );
    ALIGNED_16( int sum1 );
    ALIGNED_16( int sum2 );

    LOAD_ZERO;
    vec_u8_t fencv, pix0v, pix1v, pix2v;
    vec_s32_t sum0v, sum1v, sum2v;

    sum0v = vec_splat_s32(0);
    sum1v = vec_splat_s32(0);
    sum2v = vec_splat_s32(0);

    for( int y = 0; y < 4; y++ )
    {
        pix0v = vec_vsx_ld(0, pix0);
        pix0 += i_stride;

        pix1v = vec_vsx_ld(0, pix1);
        pix1 += i_stride;

        fencv = vec_ld(0, fenc);
        fenc += FENC_STRIDE;

        pix2v = vec_vsx_ld(0, pix2);
        pix2 += i_stride;

        sum0v = (vec_s32_t) vec_sum4s( vec_absd( fencv, pix0v ), (vec_u32_t) sum0v );
        sum1v = (vec_s32_t) vec_sum4s( vec_absd( fencv, pix1v ), (vec_u32_t) sum1v );
        sum2v = (vec_s32_t) vec_sum4s( vec_absd( fencv, pix2v ), (vec_u32_t) sum2v );

        pix0v = vec_vsx_ld(0, pix0);
        pix0 += i_stride;

        pix1v = vec_vsx_ld(0, pix1);
        pix1 += i_stride;

        fencv = vec_ld(0, fenc);
        fenc += FENC_STRIDE;

        pix2v = vec_vsx_ld(0, pix2);
        pix2 += i_stride;

        sum0v = (vec_s32_t) vec_sum4s( vec_absd( fencv, pix0v ), (vec_u32_t) sum0v );
        sum1v = (vec_s32_t) vec_sum4s( vec_absd( fencv, pix1v ), (vec_u32_t) sum1v );
        sum2v = (vec_s32_t) vec_sum4s( vec_absd( fencv, pix2v ), (vec_u32_t) sum2v );
    }

    sum0v = vec_sums( sum0v, zero_s32v );
    sum1v = vec_sums( sum1v, zero_s32v );
    sum2v = vec_sums( sum2v, zero_s32v );

    sum0v = vec_splat( sum0v, 3 );
    sum1v = vec_splat( sum1v, 3 );
    sum2v = vec_splat( sum2v, 3 );

    vec_ste( sum0v, 0, &sum0);
    vec_ste( sum1v, 0, &sum1);
    vec_ste( sum2v, 0, &sum2);

    scores[0] = sum0;
    scores[1] = sum1;
    scores[2] = sum2;
}

#define PIXEL_SAD_X4_ALTIVEC( name, ly )                                              \
static int name( uint8_t *fenc,                                                       \
                 uint8_t *pix0, uint8_t *pix1,                                        \
                 uint8_t *pix2, uint8_t *pix3,                                        \
                 intptr_t i_stride, int scores[4] )                                   \
{                                                                                     \
    ALIGNED_16( int sum0 );                                                           \
    ALIGNED_16( int sum1 );                                                           \
    ALIGNED_16( int sum2 );                                                           \
                                                                                      \
    LOAD_ZERO;                                                                        \
    vec_u8_t fencv, pix0v, pix1v, pix2v, pix3v;                                       \
    vec_s32_t sum0v, sum1v, sum2v, sum3v;                                             \
                                                                                      \
    sum0v = vec_splat_s32( 0 );                                                       \
    sum1v = vec_splat_s32( 0 );                                                       \
    sum2v = vec_splat_s32( 0 );                                                       \
                                                                                      \
    for( int y = 0; y < ly; y++ )                                                     \
    {                                                                                 \
        PROCESS_PIXS                                                                  \
        vec_u8_t pix3vH = vec_vsx_ld( 0, pix3 );                                      \
        pix3 += i_stride;                                                             \
        vec_u8_t pix3vL = vec_vsx_ld( 0, pix3 );                                      \
        pix3 += i_stride;                                                             \
        pix3v = xxpermdi( pix3vH, pix3vL, 0 );                                        \
        sum3v = (vec_s32_t) vec_sum4s( vec_absd( fencv, pix3v ), (vec_u32_t) sum3v ); \
    }                                                                                 \
                                                                                      \
    sum0v = vec_sums( sum0v, zero_s32v );                                             \
    sum1v = vec_sums( sum1v, zero_s32v );                                             \
    sum2v = vec_sums( sum2v, zero_s32v );                                             \
    sum3v = vec_sums( sum3v, zero_s32v );                                             \
                                                                                      \
    vec_s32_t s01 = vec_mergel( sum0v, sum1v );                                       \
    vec_s32_t s23 = vec_mergel( sum2v, sum3v );                                       \
    vec_s32_t s = xxpermdi( s01, s23, 3 );                                            \
                                                                                      \
    vec_vsx_st( s, 0, scores );                                                       \
}

PIXEL_SAD_X4_ALTIVEC( pixel_sad_x4_8x8_altivec, 4 )
PIXEL_SAD_X4_ALTIVEC( pixel_sad_x4_8x16_altivec, 8 )

/***********************************************************************
* SSD routines
**********************************************************************/

static int pixel_ssd_16x16_altivec( uint8_t *pix1, intptr_t i_stride_pix1,
                                    uint8_t *pix2, intptr_t i_stride_pix2 )
{
    ALIGNED_16( int sum );

    LOAD_ZERO;
    vec_u8_t  pix1vA, pix2vA, pix1vB, pix2vB;
    vec_u32_t sumv;
    vec_u8_t diffA, diffB;

    sumv = vec_splat_u32(0);

    pix2vA = vec_vsx_ld(0, pix2);
    pix1vA = vec_ld(0, pix1);

    for( int y = 0; y < 7; y++ )
    {
        pix1 += i_stride_pix1;
        pix2 += i_stride_pix2;

        pix2vB = vec_vsx_ld(0, pix2);
        pix1vB = vec_ld(0, pix1);

        diffA = vec_absd(pix1vA, pix2vA);
        sumv = vec_msum(diffA, diffA, sumv);

        pix1 += i_stride_pix1;
        pix2 += i_stride_pix2;

        pix2vA = vec_vsx_ld(0, pix2);
        pix1vA = vec_ld(0, pix1);

        diffB = vec_absd(pix1vB, pix2vB);
        sumv = vec_msum(diffB, diffB, sumv);
    }

    pix1 += i_stride_pix1;
    pix2 += i_stride_pix2;

    pix2vB = vec_vsx_ld(0, pix2);
    pix1vB = vec_ld(0, pix1);

    diffA = vec_absd(pix1vA, pix2vA);
    sumv = vec_msum(diffA, diffA, sumv);

    diffB = vec_absd(pix1vB, pix2vB);
    sumv = vec_msum(diffB, diffB, sumv);

    sumv = (vec_u32_t) vec_sums((vec_s32_t) sumv, zero_s32v);
    sumv = vec_splat(sumv, 3);
    vec_ste((vec_s32_t) sumv, 0, &sum);
    return sum;
}

static int pixel_ssd_8x8_altivec( uint8_t *pix1, intptr_t i_stride_pix1,
                                  uint8_t *pix2, intptr_t i_stride_pix2 )
{
    ALIGNED_16( int sum );

    LOAD_ZERO;
    vec_u8_t  pix1v, pix2v;
    vec_u32_t sumv;
    vec_u8_t diffv;

    const vec_u32_t sel = (vec_u32_t)CV(-1,-1,0,0);

    sumv = vec_splat_u32(0);

    for( int y = 0; y < 8; y++ )
    {
        pix1v = vec_vsx_ld(0, pix1);
        pix2v = vec_vsx_ld(0, pix2);

        diffv = vec_absd( pix1v, pix2v );
        sumv = vec_msum(diffv, diffv, sumv);

        pix1 += i_stride_pix1;
        pix2 += i_stride_pix2;
    }

    sumv = vec_sel( zero_u32v, sumv, sel );

    sumv = (vec_u32_t) vec_sums((vec_s32_t) sumv, zero_s32v);
    sumv = vec_splat(sumv, 3);
    vec_ste((vec_s32_t) sumv, 0, &sum);

    return sum;
}


/****************************************************************************
 * variance
 ****************************************************************************/
static uint64_t pixel_var_16x16_altivec( uint8_t *pix, intptr_t i_stride )
{
    ALIGNED_16(uint32_t sum_tab[4]);
    ALIGNED_16(uint32_t sqr_tab[4]);

    LOAD_ZERO;
    vec_u32_t sqr_v = zero_u32v;
    vec_u32_t sum_v = zero_u32v;

    for( int y = 0; y < 16; y++ )
    {
        vec_u8_t pix0_v = vec_ld(0, pix);
        sum_v = vec_sum4s(pix0_v, sum_v);
        sqr_v = vec_msum(pix0_v, pix0_v, sqr_v);

        pix += i_stride;
    }
    sum_v = (vec_u32_t)vec_sums( (vec_s32_t)sum_v, zero_s32v );
    sqr_v = (vec_u32_t)vec_sums( (vec_s32_t)sqr_v, zero_s32v );
    vec_ste(sum_v, 12, sum_tab);
    vec_ste(sqr_v, 12, sqr_tab);

    uint32_t sum = sum_tab[3];
    uint32_t sqr = sqr_tab[3];
    return sum + ((uint64_t)sqr<<32);
}

static uint64_t pixel_var_8x8_altivec( uint8_t *pix, intptr_t i_stride )
{
    ALIGNED_16(uint32_t sum_tab[4]);
    ALIGNED_16(uint32_t sqr_tab[4]);

    LOAD_ZERO;
    vec_u32_t sqr_v = zero_u32v;
    vec_u32_t sum_v = zero_u32v;

    static const vec_u8_t perm_tab[] =
    {
        CV(0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,  /* pix=mod16, i_stride=mod16 */
           0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17),
        CV(0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F,  /* pix=mod8, i_stride=mod16  */
           0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F),
    };
    vec_u8_t perm = perm_tab[ ((uintptr_t)pix & 8) >> 3 ];

    for( int y = 0; y < 4; y++ )
    {
        vec_u8_t pix0_v = vec_ld(0, pix);
        vec_u8_t pix1_v = vec_ld(i_stride, pix);
        vec_u8_t pix_v = vec_perm(pix0_v, pix1_v, perm);
        sum_v = vec_sum4s(pix_v, sum_v);
        sqr_v = vec_msum(pix_v, pix_v, sqr_v);

        pix += i_stride<<1;
    }
    sum_v = (vec_u32_t)vec_sums( (vec_s32_t)sum_v, zero_s32v );
    sqr_v = (vec_u32_t)vec_sums( (vec_s32_t)sqr_v, zero_s32v );
    vec_ste(sum_v, 12, sum_tab);
    vec_ste(sqr_v, 12, sqr_tab);

    uint32_t sum = sum_tab[3];
    uint32_t sqr = sqr_tab[3];
    return sum + ((uint64_t)sqr<<32);
}


/**********************************************************************
 * SA8D routines: sum of 8x8 Hadamard transformed differences
 **********************************************************************/
/* SA8D_1D unrolled by 8 in Altivec */
#define SA8D_1D_ALTIVEC( sa8d0v, sa8d1v, sa8d2v, sa8d3v,  \
                         sa8d4v, sa8d5v, sa8d6v, sa8d7v ) \
{                                                         \
    /* int    a0  =        SRC(0) + SRC(4) */             \
    vec_s16_t a0v = vec_add(sa8d0v, sa8d4v);              \
    /* int    a4  =        SRC(0) - SRC(4) */             \
    vec_s16_t a4v = vec_sub(sa8d0v, sa8d4v);              \
    /* int    a1  =        SRC(1) + SRC(5) */             \
    vec_s16_t a1v = vec_add(sa8d1v, sa8d5v);              \
    /* int    a5  =        SRC(1) - SRC(5) */             \
    vec_s16_t a5v = vec_sub(sa8d1v, sa8d5v);              \
    /* int    a2  =        SRC(2) + SRC(6) */             \
    vec_s16_t a2v = vec_add(sa8d2v, sa8d6v);              \
    /* int    a6  =        SRC(2) - SRC(6) */             \
    vec_s16_t a6v = vec_sub(sa8d2v, sa8d6v);              \
    /* int    a3  =        SRC(3) + SRC(7) */             \
    vec_s16_t a3v = vec_add(sa8d3v, sa8d7v);              \
    /* int    a7  =        SRC(3) - SRC(7) */             \
    vec_s16_t a7v = vec_sub(sa8d3v, sa8d7v);              \
                                                          \
    /* int    b0  =         a0 + a2  */                   \
    vec_s16_t b0v = vec_add(a0v, a2v);                    \
    /* int    b2  =         a0 - a2; */                   \
    vec_s16_t  b2v = vec_sub(a0v, a2v);                   \
    /* int    b1  =         a1 + a3; */                   \
    vec_s16_t b1v = vec_add(a1v, a3v);                    \
    /* int    b3  =         a1 - a3; */                   \
    vec_s16_t b3v = vec_sub(a1v, a3v);                    \
    /* int    b4  =         a4 + a6; */                   \
    vec_s16_t b4v = vec_add(a4v, a6v);                    \
    /* int    b6  =         a4 - a6; */                   \
    vec_s16_t b6v = vec_sub(a4v, a6v);                    \
    /* int    b5  =         a5 + a7; */                   \
    vec_s16_t b5v = vec_add(a5v, a7v);                    \
    /* int    b7  =         a5 - a7; */                   \
    vec_s16_t b7v = vec_sub(a5v, a7v);                    \
                                                          \
    /* DST(0,        b0 + b1) */                          \
    sa8d0v = vec_add(b0v, b1v);                           \
    /* DST(1,        b0 - b1) */                          \
    sa8d1v = vec_sub(b0v, b1v);                           \
    /* DST(2,        b2 + b3) */                          \
    sa8d2v = vec_add(b2v, b3v);                           \
    /* DST(3,        b2 - b3) */                          \
    sa8d3v = vec_sub(b2v, b3v);                           \
    /* DST(4,        b4 + b5) */                          \
    sa8d4v = vec_add(b4v, b5v);                           \
    /* DST(5,        b4 - b5) */                          \
    sa8d5v = vec_sub(b4v, b5v);                           \
    /* DST(6,        b6 + b7) */                          \
    sa8d6v = vec_add(b6v, b7v);                           \
    /* DST(7,        b6 - b7) */                          \
    sa8d7v = vec_sub(b6v, b7v);                           \
}

static int pixel_sa8d_8x8_core_altivec( uint8_t *pix1, intptr_t i_pix1,
                                        uint8_t *pix2, intptr_t i_pix2 )
{
    int32_t i_satd=0;

    PREP_DIFF;

    vec_s16_t diff0v, diff1v, diff2v, diff3v, diff4v, diff5v, diff6v, diff7v;

    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 8, diff0v );
    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 8, diff1v );
    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 8, diff2v );
    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 8, diff3v );

    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 8, diff4v );
    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 8, diff5v );
    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 8, diff6v );
    VEC_DIFF_H( pix1, i_pix1, pix2, i_pix2, 8, diff7v );

    vec_s16_t sa8d0v, sa8d1v, sa8d2v, sa8d3v, sa8d4v, sa8d5v, sa8d6v, sa8d7v;

    SA8D_1D_ALTIVEC(diff0v, diff1v, diff2v, diff3v,
                    diff4v, diff5v, diff6v, diff7v);

    VEC_TRANSPOSE_8(diff0v, diff1v, diff2v, diff3v,
                    diff4v, diff5v, diff6v, diff7v,
                    sa8d0v, sa8d1v, sa8d2v, sa8d3v,
                    sa8d4v, sa8d5v, sa8d6v, sa8d7v );

    SA8D_1D_ALTIVEC(sa8d0v, sa8d1v, sa8d2v, sa8d3v,
                    sa8d4v, sa8d5v, sa8d6v, sa8d7v );

    /* accumulation of the absolute value of all elements of the resulting block */
    vec_s16_t abs0v = VEC_ABS(sa8d0v);
    vec_s16_t abs1v = VEC_ABS(sa8d1v);
    vec_s16_t sum01v = vec_add(abs0v, abs1v);

    vec_s16_t abs2v = VEC_ABS(sa8d2v);
    vec_s16_t abs3v = VEC_ABS(sa8d3v);
    vec_s16_t sum23v = vec_add(abs2v, abs3v);

    vec_s16_t abs4v = VEC_ABS(sa8d4v);
    vec_s16_t abs5v = VEC_ABS(sa8d5v);
    vec_s16_t sum45v = vec_add(abs4v, abs5v);

    vec_s16_t abs6v = VEC_ABS(sa8d6v);
    vec_s16_t abs7v = VEC_ABS(sa8d7v);
    vec_s16_t sum67v = vec_add(abs6v, abs7v);

    vec_s16_t sum0123v = vec_add(sum01v, sum23v);
    vec_s16_t sum4567v = vec_add(sum45v, sum67v);

    vec_s32_t sumblocv;

    sumblocv = vec_sum4s(sum0123v, (vec_s32_t)zerov );
    sumblocv = vec_sum4s(sum4567v, sumblocv );

    sumblocv = vec_sums(sumblocv, (vec_s32_t)zerov );

    sumblocv = vec_splat(sumblocv, 3);

    vec_ste(sumblocv, 0, &i_satd);

    return i_satd;
}

static int pixel_sa8d_8x8_altivec( uint8_t *pix1, intptr_t i_pix1,
                                   uint8_t *pix2, intptr_t i_pix2 )
{
    int32_t i_satd;
    i_satd = (pixel_sa8d_8x8_core_altivec( pix1, i_pix1, pix2, i_pix2 )+2)>>2;
    return i_satd;
}

static int pixel_sa8d_16x16_altivec( uint8_t *pix1, intptr_t i_pix1,
                                     uint8_t *pix2, intptr_t i_pix2 )
{
    int32_t i_satd;

    i_satd = (pixel_sa8d_8x8_core_altivec( &pix1[0],          i_pix1, &pix2[0],          i_pix2 )
            + pixel_sa8d_8x8_core_altivec( &pix1[8],          i_pix1, &pix2[8],          i_pix2 )
            + pixel_sa8d_8x8_core_altivec( &pix1[8*i_pix1],   i_pix1, &pix2[8*i_pix2],   i_pix2 )
            + pixel_sa8d_8x8_core_altivec( &pix1[8*i_pix1+8], i_pix1, &pix2[8*i_pix2+8], i_pix2 ) +2)>>2;
    return i_satd;
}

#define HADAMARD4_ALTIVEC(d0,d1,d2,d3,s0,s1,s2,s3) {\
    vec_s16_t t0 = vec_add(s0, s1);                 \
    vec_s16_t t1 = vec_sub(s0, s1);                 \
    vec_s16_t t2 = vec_add(s2, s3);                 \
    vec_s16_t t3 = vec_sub(s2, s3);                 \
    d0 = vec_add(t0, t2);                           \
    d2 = vec_sub(t0, t2);                           \
    d1 = vec_add(t1, t3);                           \
    d3 = vec_sub(t1, t3);                           \
}

#ifdef WORDS_BIGENDIAN
#define vec_perm_extend_s16(val, perm) (vec_s16_t)vec_perm(val, zero_u8v, perm)
#else
#define vec_perm_extend_s16(val, perm) (vec_s16_t)vec_perm(zero_u8v, val, perm)
#endif

#define VEC_LOAD_HIGH( p, num )                                    \
    vec_u8_t pix8_##num = vec_ld( stride*num, p );                 \
    vec_s16_t pix16_s##num = vec_perm_extend_s16( pix8_##num, perm ); \
    vec_s16_t pix16_d##num;

static uint64_t pixel_hadamard_ac_altivec( uint8_t *pix, intptr_t stride, const vec_u8_t perm )
{
    ALIGNED_16( int32_t sum4_tab[4] );
    ALIGNED_16( int32_t sum8_tab[4] );
    LOAD_ZERO;

    VEC_LOAD_HIGH( pix, 0 );
    VEC_LOAD_HIGH( pix, 1 );
    VEC_LOAD_HIGH( pix, 2 );
    VEC_LOAD_HIGH( pix, 3 );
    HADAMARD4_ALTIVEC(pix16_d0,pix16_d1,pix16_d2,pix16_d3,
                      pix16_s0,pix16_s1,pix16_s2,pix16_s3);

    VEC_LOAD_HIGH( pix, 4 );
    VEC_LOAD_HIGH( pix, 5 );
    VEC_LOAD_HIGH( pix, 6 );
    VEC_LOAD_HIGH( pix, 7 );
    HADAMARD4_ALTIVEC(pix16_d4,pix16_d5,pix16_d6,pix16_d7,
                      pix16_s4,pix16_s5,pix16_s6,pix16_s7);

    VEC_TRANSPOSE_8(pix16_d0, pix16_d1, pix16_d2, pix16_d3,
                    pix16_d4, pix16_d5, pix16_d6, pix16_d7,
                    pix16_s0, pix16_s1, pix16_s2, pix16_s3,
                    pix16_s4, pix16_s5, pix16_s6, pix16_s7);

    HADAMARD4_ALTIVEC(pix16_d0,pix16_d1,pix16_d2,pix16_d3,
                      pix16_s0,pix16_s1,pix16_s2,pix16_s3);

    HADAMARD4_ALTIVEC(pix16_d4,pix16_d5,pix16_d6,pix16_d7,
                      pix16_s4,pix16_s5,pix16_s6,pix16_s7);

    vec_u16_t addabs01 = vec_add( VEC_ABSOLUTE(pix16_d0), VEC_ABSOLUTE(pix16_d1) );
    vec_u16_t addabs23 = vec_add( VEC_ABSOLUTE(pix16_d2), VEC_ABSOLUTE(pix16_d3) );
    vec_u16_t addabs45 = vec_add( VEC_ABSOLUTE(pix16_d4), VEC_ABSOLUTE(pix16_d5) );
    vec_u16_t addabs67 = vec_add( VEC_ABSOLUTE(pix16_d6), VEC_ABSOLUTE(pix16_d7) );

    vec_u16_t sum4_v = vec_add(vec_add(addabs01, addabs23), vec_add(addabs45, addabs67));
    vec_ste(vec_sums(vec_sum4s((vec_s16_t)sum4_v, zero_s32v), zero_s32v), 12, sum4_tab);

    vec_s16_t tmpi0 = vec_add(pix16_d0, pix16_d4);
    vec_s16_t tmpi4 = vec_sub(pix16_d0, pix16_d4);
    vec_s16_t tmpi1 = vec_add(pix16_d1, pix16_d5);
    vec_s16_t tmpi5 = vec_sub(pix16_d1, pix16_d5);
    vec_s16_t tmpi2 = vec_add(pix16_d2, pix16_d6);
    vec_s16_t tmpi6 = vec_sub(pix16_d2, pix16_d6);
    vec_s16_t tmpi3 = vec_add(pix16_d3, pix16_d7);
    vec_s16_t tmpi7 = vec_sub(pix16_d3, pix16_d7);

    int sum4 = sum4_tab[3];

    VEC_TRANSPOSE_8(tmpi0, tmpi1, tmpi2, tmpi3,
                    tmpi4, tmpi5, tmpi6, tmpi7,
                    pix16_d0, pix16_d1, pix16_d2, pix16_d3,
                    pix16_d4, pix16_d5, pix16_d6, pix16_d7);

    vec_u16_t addsum04 = vec_add( VEC_ABSOLUTE( vec_add(pix16_d0, pix16_d4) ),
                                  VEC_ABSOLUTE( vec_sub(pix16_d0, pix16_d4) ) );
    vec_u16_t addsum15 = vec_add( VEC_ABSOLUTE( vec_add(pix16_d1, pix16_d5) ),
                                  VEC_ABSOLUTE( vec_sub(pix16_d1, pix16_d5) ) );
    vec_u16_t addsum26 = vec_add( VEC_ABSOLUTE( vec_add(pix16_d2, pix16_d6) ),
                                  VEC_ABSOLUTE( vec_sub(pix16_d2, pix16_d6) ) );
    vec_u16_t addsum37 = vec_add( VEC_ABSOLUTE( vec_add(pix16_d3, pix16_d7) ),
                                  VEC_ABSOLUTE( vec_sub(pix16_d3, pix16_d7) ) );

    vec_u16_t sum8_v = vec_add( vec_add(addsum04, addsum15), vec_add(addsum26, addsum37) );
    vec_ste(vec_sums(vec_sum4s((vec_s16_t)sum8_v, zero_s32v), zero_s32v), 12, sum8_tab);

    int sum8 = sum8_tab[3];

    ALIGNED_16( int16_t tmp0_4_tab[8] );
    vec_ste(vec_add(pix16_d0, pix16_d4), 0, tmp0_4_tab);

    sum4 -= tmp0_4_tab[0];
    sum8 -= tmp0_4_tab[0];
    return ((uint64_t)sum8<<32) + sum4;
}


static const vec_u8_t hadamard_permtab[] =
{
    CV(0x10,0x00,0x11,0x01, 0x12,0x02,0x13,0x03,     /* pix = mod16 */
       0x14,0x04,0x15,0x05, 0x16,0x06,0x17,0x07 ),
    CV(0x18,0x08,0x19,0x09, 0x1A,0x0A,0x1B,0x0B,     /* pix = mod8 */
       0x1C,0x0C,0x1D,0x0D, 0x1E,0x0E,0x1F,0x0F )
 };

static uint64_t pixel_hadamard_ac_16x16_altivec( uint8_t *pix, intptr_t stride )
{
    int idx =  ((uintptr_t)pix & 8) >> 3;
    vec_u8_t permh = hadamard_permtab[idx];
    vec_u8_t perml = hadamard_permtab[!idx];
    uint64_t sum = pixel_hadamard_ac_altivec( pix, stride, permh );
    sum += pixel_hadamard_ac_altivec( pix+8, stride, perml );
    sum += pixel_hadamard_ac_altivec( pix+8*stride, stride, permh );
    sum += pixel_hadamard_ac_altivec( pix+8*stride+8, stride, perml );
    return ((sum>>34)<<32) + ((uint32_t)sum>>1);
}

static uint64_t pixel_hadamard_ac_16x8_altivec( uint8_t *pix, intptr_t stride )
{
    int idx =  ((uintptr_t)pix & 8) >> 3;
    vec_u8_t permh = hadamard_permtab[idx];
    vec_u8_t perml = hadamard_permtab[!idx];
    uint64_t sum = pixel_hadamard_ac_altivec( pix, stride, permh );
    sum += pixel_hadamard_ac_altivec( pix+8, stride, perml );
    return ((sum>>34)<<32) + ((uint32_t)sum>>1);
}

static uint64_t pixel_hadamard_ac_8x16_altivec( uint8_t *pix, intptr_t stride )
{
    vec_u8_t perm = hadamard_permtab[ (((uintptr_t)pix & 8) >> 3) ];
    uint64_t sum = pixel_hadamard_ac_altivec( pix, stride, perm );
    sum += pixel_hadamard_ac_altivec( pix+8*stride, stride, perm );
    return ((sum>>34)<<32) + ((uint32_t)sum>>1);
}

static uint64_t pixel_hadamard_ac_8x8_altivec( uint8_t *pix, intptr_t stride )
{
    vec_u8_t perm = hadamard_permtab[ (((uintptr_t)pix & 8) >> 3) ];
    uint64_t sum = pixel_hadamard_ac_altivec( pix, stride, perm );
    return ((sum>>34)<<32) + ((uint32_t)sum>>1);
}


/****************************************************************************
 * structural similarity metric
 ****************************************************************************/
static void ssim_4x4x2_core_altivec( const uint8_t *pix1, intptr_t stride1,
                                     const uint8_t *pix2, intptr_t stride2,
                                     int sums[2][4] )
{
    ALIGNED_16( int temp[4] );

    vec_u8_t pix1v, pix2v;
    vec_u32_t s1v, s2v, ssv, s12v;
    LOAD_ZERO;

    s1v = s2v = ssv = s12v = zero_u32v;

    for( int y = 0; y < 4; y++ )
    {
        pix1v = vec_vsx_ld( y*stride1, pix1 );
        pix2v = vec_vsx_ld( y*stride2, pix2 );

        s1v = vec_sum4s( pix1v, s1v );
        s2v = vec_sum4s( pix2v, s2v );
        ssv = vec_msum( pix1v, pix1v, ssv );
        ssv = vec_msum( pix2v, pix2v, ssv );
        s12v = vec_msum( pix1v, pix2v, s12v );
    }

    vec_st( (vec_s32_t)s1v, 0, temp );
    sums[0][0] = temp[0];
    sums[1][0] = temp[1];
    vec_st( (vec_s32_t)s2v, 0, temp );
    sums[0][1] = temp[0];
    sums[1][1] = temp[1];
    vec_st( (vec_s32_t)ssv, 0, temp );
    sums[0][2] = temp[0];
    sums[1][2] = temp[1];
    vec_st( (vec_s32_t)s12v, 0, temp );
    sums[0][3] = temp[0];
    sums[1][3] = temp[1];
}

#define SATD_X( size ) \
static void pixel_satd_x3_##size##_altivec( uint8_t *fenc, uint8_t *pix0, uint8_t *pix1, uint8_t *pix2,\
                                            intptr_t i_stride, int scores[3] )\
{\
    scores[0] = pixel_satd_##size##_altivec( fenc, FENC_STRIDE, pix0, i_stride );\
    scores[1] = pixel_satd_##size##_altivec( fenc, FENC_STRIDE, pix1, i_stride );\
    scores[2] = pixel_satd_##size##_altivec( fenc, FENC_STRIDE, pix2, i_stride );\
}\
static void pixel_satd_x4_##size##_altivec( uint8_t *fenc, uint8_t *pix0, uint8_t *pix1, uint8_t *pix2,\
                                            uint8_t *pix3, intptr_t i_stride, int scores[4] )\
{\
    scores[0] = pixel_satd_##size##_altivec( fenc, FENC_STRIDE, pix0, i_stride );\
    scores[1] = pixel_satd_##size##_altivec( fenc, FENC_STRIDE, pix1, i_stride );\
    scores[2] = pixel_satd_##size##_altivec( fenc, FENC_STRIDE, pix2, i_stride );\
    scores[3] = pixel_satd_##size##_altivec( fenc, FENC_STRIDE, pix3, i_stride );\
}
SATD_X( 16x16 )\
SATD_X( 16x8 )\
SATD_X( 8x16 )\
SATD_X( 8x8 )\
SATD_X( 8x4 )\
SATD_X( 4x8 )\
SATD_X( 4x4 )


#define INTRA_MBCMP_8x8( mbcmp )\
static void intra_##mbcmp##_x3_8x8_altivec( uint8_t *fenc, uint8_t edge[36], int res[3] )\
{\
    ALIGNED_8( uint8_t pix[8*FDEC_STRIDE] );\
    x264_predict_8x8_v_c( pix, edge );\
    res[0] = pixel_##mbcmp##_8x8_altivec( pix, FDEC_STRIDE, fenc, FENC_STRIDE );\
    x264_predict_8x8_h_c( pix, edge );\
    res[1] = pixel_##mbcmp##_8x8_altivec( pix, FDEC_STRIDE, fenc, FENC_STRIDE );\
    x264_predict_8x8_dc_c( pix, edge );\
    res[2] = pixel_##mbcmp##_8x8_altivec( pix, FDEC_STRIDE, fenc, FENC_STRIDE );\
}

INTRA_MBCMP_8x8(sad)
INTRA_MBCMP_8x8(sa8d)

#define INTRA_MBCMP( mbcmp, size, pred1, pred2, pred3, chroma )\
static void intra_##mbcmp##_x3_##size##x##size##chroma##_altivec( uint8_t *fenc, uint8_t *fdec, int res[3] )\
{\
    x264_predict_##size##x##size##chroma##_##pred1##_c( fdec );\
    res[0] = pixel_##mbcmp##_##size##x##size##_altivec( fdec, FDEC_STRIDE, fenc, FENC_STRIDE );\
    x264_predict_##size##x##size##chroma##_##pred2##_c( fdec );\
    res[1] = pixel_##mbcmp##_##size##x##size##_altivec( fdec, FDEC_STRIDE, fenc, FENC_STRIDE );\
    x264_predict_##size##x##size##chroma##_##pred3##_c( fdec );\
    res[2] = pixel_##mbcmp##_##size##x##size##_altivec( fdec, FDEC_STRIDE, fenc, FENC_STRIDE );\
}

INTRA_MBCMP(satd, 4, v, h, dc, )
INTRA_MBCMP(sad, 8, dc, h, v, c )
INTRA_MBCMP(satd, 8, dc, h, v, c )
INTRA_MBCMP(sad, 16, v, h, dc, )
INTRA_MBCMP(satd, 16, v, h, dc, )
#endif // !HIGH_BIT_DEPTH

/****************************************************************************
 * x264_pixel_init:
 ****************************************************************************/
void x264_pixel_init_altivec( x264_pixel_function_t *pixf )
{
#if !HIGH_BIT_DEPTH
    pixf->sad[PIXEL_16x16]  = pixel_sad_16x16_altivec;
    pixf->sad[PIXEL_8x16]   = pixel_sad_8x16_altivec;
    pixf->sad[PIXEL_16x8]   = pixel_sad_16x8_altivec;
    pixf->sad[PIXEL_8x8]    = pixel_sad_8x8_altivec;

    pixf->sad_x3[PIXEL_16x16] = pixel_sad_x3_16x16_altivec;
    pixf->sad_x3[PIXEL_8x16]  = pixel_sad_x3_8x16_altivec;
    pixf->sad_x3[PIXEL_16x8]  = pixel_sad_x3_16x8_altivec;
    pixf->sad_x3[PIXEL_8x8]   = pixel_sad_x3_8x8_altivec;

    pixf->sad_x4[PIXEL_16x16] = pixel_sad_x4_16x16_altivec;
    pixf->sad_x4[PIXEL_8x16]  = pixel_sad_x4_8x16_altivec;
    pixf->sad_x4[PIXEL_16x8]  = pixel_sad_x4_16x8_altivec;
    pixf->sad_x4[PIXEL_8x8]   = pixel_sad_x4_8x8_altivec;

    pixf->satd[PIXEL_16x16] = pixel_satd_16x16_altivec;
    pixf->satd[PIXEL_8x16]  = pixel_satd_8x16_altivec;
    pixf->satd[PIXEL_16x8]  = pixel_satd_16x8_altivec;
    pixf->satd[PIXEL_8x8]   = pixel_satd_8x8_altivec;
    pixf->satd[PIXEL_8x4]   = pixel_satd_8x4_altivec;
    pixf->satd[PIXEL_4x8]   = pixel_satd_4x8_altivec;
    pixf->satd[PIXEL_4x4]   = pixel_satd_4x4_altivec;

    pixf->satd_x3[PIXEL_16x16] = pixel_satd_x3_16x16_altivec;
    pixf->satd_x3[PIXEL_8x16]  = pixel_satd_x3_8x16_altivec;
    pixf->satd_x3[PIXEL_16x8]  = pixel_satd_x3_16x8_altivec;
    pixf->satd_x3[PIXEL_8x8]   = pixel_satd_x3_8x8_altivec;
    pixf->satd_x3[PIXEL_8x4]   = pixel_satd_x3_8x4_altivec;
    pixf->satd_x3[PIXEL_4x8]   = pixel_satd_x3_4x8_altivec;
    pixf->satd_x3[PIXEL_4x4]   = pixel_satd_x3_4x4_altivec;

    pixf->satd_x4[PIXEL_16x16] = pixel_satd_x4_16x16_altivec;
    pixf->satd_x4[PIXEL_8x16]  = pixel_satd_x4_8x16_altivec;
    pixf->satd_x4[PIXEL_16x8]  = pixel_satd_x4_16x8_altivec;
    pixf->satd_x4[PIXEL_8x8]   = pixel_satd_x4_8x8_altivec;
    pixf->satd_x4[PIXEL_8x4]   = pixel_satd_x4_8x4_altivec;
    pixf->satd_x4[PIXEL_4x8]   = pixel_satd_x4_4x8_altivec;
    pixf->satd_x4[PIXEL_4x4]   = pixel_satd_x4_4x4_altivec;

    pixf->intra_sad_x3_8x8    = intra_sad_x3_8x8_altivec;
    pixf->intra_sad_x3_8x8c   = intra_sad_x3_8x8c_altivec;
    pixf->intra_sad_x3_16x16  = intra_sad_x3_16x16_altivec;

    pixf->intra_satd_x3_4x4   = intra_satd_x3_4x4_altivec;
    pixf->intra_satd_x3_8x8c  = intra_satd_x3_8x8c_altivec;
    pixf->intra_satd_x3_16x16 = intra_satd_x3_16x16_altivec;

    pixf->ssd[PIXEL_16x16] = pixel_ssd_16x16_altivec;
    pixf->ssd[PIXEL_8x8]   = pixel_ssd_8x8_altivec;

    pixf->sa8d[PIXEL_16x16] = pixel_sa8d_16x16_altivec;
    pixf->sa8d[PIXEL_8x8]   = pixel_sa8d_8x8_altivec;

    pixf->intra_sa8d_x3_8x8   = intra_sa8d_x3_8x8_altivec;

    pixf->var[PIXEL_16x16] = pixel_var_16x16_altivec;
    pixf->var[PIXEL_8x8]   = pixel_var_8x8_altivec;

    pixf->hadamard_ac[PIXEL_16x16] = pixel_hadamard_ac_16x16_altivec;
    pixf->hadamard_ac[PIXEL_16x8]  = pixel_hadamard_ac_16x8_altivec;
    pixf->hadamard_ac[PIXEL_8x16]  = pixel_hadamard_ac_8x16_altivec;
    pixf->hadamard_ac[PIXEL_8x8]   = pixel_hadamard_ac_8x8_altivec;

    pixf->ssim_4x4x2_core = ssim_4x4x2_core_altivec;
#endif // !HIGH_BIT_DEPTH
}
