/*****************************************************************************
 * dct.c: transform and zigzag
 *****************************************************************************
 * Copyright (C) 2003-2022 x264 project
 *
 * Authors: Loren Merritt <lorenm@u.washington.edu>
 *          Laurent Aimar <fenrir@via.ecp.fr>
 *          Henrik Gramner <henrik@gramner.com>
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

#include "common.h"
#if HAVE_MMX
#   include "x86/dct.h"
#endif
#if HAVE_ALTIVEC
#   include "ppc/dct.h"
#endif
#if HAVE_ARMV6
#   include "arm/dct.h"
#endif
#if HAVE_AARCH64
#   include "aarch64/dct.h"
#endif
#if HAVE_MSA
#   include "mips/dct.h"
#endif

static void dct4x4dc( dctcoef d[16] )
{
    dctcoef tmp[16];

    for( int i = 0; i < 4; i++ )
    {
        int s01 = d[i*4+0] + d[i*4+1];
        int d01 = d[i*4+0] - d[i*4+1];
        int s23 = d[i*4+2] + d[i*4+3];
        int d23 = d[i*4+2] - d[i*4+3];

        tmp[0*4+i] = s01 + s23;
        tmp[1*4+i] = s01 - s23;
        tmp[2*4+i] = d01 - d23;
        tmp[3*4+i] = d01 + d23;
    }

    for( int i = 0; i < 4; i++ )
    {
        int s01 = tmp[i*4+0] + tmp[i*4+1];
        int d01 = tmp[i*4+0] - tmp[i*4+1];
        int s23 = tmp[i*4+2] + tmp[i*4+3];
        int d23 = tmp[i*4+2] - tmp[i*4+3];

        d[i*4+0] = ( s01 + s23 + 1 ) >> 1;
        d[i*4+1] = ( s01 - s23 + 1 ) >> 1;
        d[i*4+2] = ( d01 - d23 + 1 ) >> 1;
        d[i*4+3] = ( d01 + d23 + 1 ) >> 1;
    }
}

static void idct4x4dc( dctcoef d[16] )
{
    dctcoef tmp[16];

    for( int i = 0; i < 4; i++ )
    {
        int s01 = d[i*4+0] + d[i*4+1];
        int d01 = d[i*4+0] - d[i*4+1];
        int s23 = d[i*4+2] + d[i*4+3];
        int d23 = d[i*4+2] - d[i*4+3];

        tmp[0*4+i] = s01 + s23;
        tmp[1*4+i] = s01 - s23;
        tmp[2*4+i] = d01 - d23;
        tmp[3*4+i] = d01 + d23;
    }

    for( int i = 0; i < 4; i++ )
    {
        int s01 = tmp[i*4+0] + tmp[i*4+1];
        int d01 = tmp[i*4+0] - tmp[i*4+1];
        int s23 = tmp[i*4+2] + tmp[i*4+3];
        int d23 = tmp[i*4+2] - tmp[i*4+3];

        d[i*4+0] = s01 + s23;
        d[i*4+1] = s01 - s23;
        d[i*4+2] = d01 - d23;
        d[i*4+3] = d01 + d23;
    }
}

static void dct2x4dc( dctcoef dct[8], dctcoef dct4x4[8][16] )
{
    int a0 = dct4x4[0][0] + dct4x4[1][0];
    int a1 = dct4x4[2][0] + dct4x4[3][0];
    int a2 = dct4x4[4][0] + dct4x4[5][0];
    int a3 = dct4x4[6][0] + dct4x4[7][0];
    int a4 = dct4x4[0][0] - dct4x4[1][0];
    int a5 = dct4x4[2][0] - dct4x4[3][0];
    int a6 = dct4x4[4][0] - dct4x4[5][0];
    int a7 = dct4x4[6][0] - dct4x4[7][0];
    int b0 = a0 + a1;
    int b1 = a2 + a3;
    int b2 = a4 + a5;
    int b3 = a6 + a7;
    int b4 = a0 - a1;
    int b5 = a2 - a3;
    int b6 = a4 - a5;
    int b7 = a6 - a7;
    dct[0] = b0 + b1;
    dct[1] = b2 + b3;
    dct[2] = b0 - b1;
    dct[3] = b2 - b3;
    dct[4] = b4 - b5;
    dct[5] = b6 - b7;
    dct[6] = b4 + b5;
    dct[7] = b6 + b7;
    dct4x4[0][0] = 0;
    dct4x4[1][0] = 0;
    dct4x4[2][0] = 0;
    dct4x4[3][0] = 0;
    dct4x4[4][0] = 0;
    dct4x4[5][0] = 0;
    dct4x4[6][0] = 0;
    dct4x4[7][0] = 0;
}

static inline void pixel_sub_wxh( dctcoef *diff, int i_size,
                                  pixel *pix1, int i_pix1, pixel *pix2, int i_pix2 )
{
    for( int y = 0; y < i_size; y++ )
    {
        for( int x = 0; x < i_size; x++ )
            diff[x + y*i_size] = pix1[x] - pix2[x];
        pix1 += i_pix1;
        pix2 += i_pix2;
    }
}

static void sub4x4_dct( dctcoef dct[16], pixel *pix1, pixel *pix2 )
{
    dctcoef d[16];
    dctcoef tmp[16];

    pixel_sub_wxh( d, 4, pix1, FENC_STRIDE, pix2, FDEC_STRIDE );

    for( int i = 0; i < 4; i++ )
    {
        int s03 = d[i*4+0] + d[i*4+3];
        int s12 = d[i*4+1] + d[i*4+2];
        int d03 = d[i*4+0] - d[i*4+3];
        int d12 = d[i*4+1] - d[i*4+2];

        tmp[0*4+i] =   s03 +   s12;
        tmp[1*4+i] = 2*d03 +   d12;
        tmp[2*4+i] =   s03 -   s12;
        tmp[3*4+i] =   d03 - 2*d12;
    }

    for( int i = 0; i < 4; i++ )
    {
        int s03 = tmp[i*4+0] + tmp[i*4+3];
        int s12 = tmp[i*4+1] + tmp[i*4+2];
        int d03 = tmp[i*4+0] - tmp[i*4+3];
        int d12 = tmp[i*4+1] - tmp[i*4+2];

        dct[i*4+0] =   s03 +   s12;
        dct[i*4+1] = 2*d03 +   d12;
        dct[i*4+2] =   s03 -   s12;
        dct[i*4+3] =   d03 - 2*d12;
    }
}

static void sub8x8_dct( dctcoef dct[4][16], pixel *pix1, pixel *pix2 )
{
    sub4x4_dct( dct[0], &pix1[0], &pix2[0] );
    sub4x4_dct( dct[1], &pix1[4], &pix2[4] );
    sub4x4_dct( dct[2], &pix1[4*FENC_STRIDE+0], &pix2[4*FDEC_STRIDE+0] );
    sub4x4_dct( dct[3], &pix1[4*FENC_STRIDE+4], &pix2[4*FDEC_STRIDE+4] );
}

static void sub16x16_dct( dctcoef dct[16][16], pixel *pix1, pixel *pix2 )
{
    sub8x8_dct( &dct[ 0], &pix1[0], &pix2[0] );
    sub8x8_dct( &dct[ 4], &pix1[8], &pix2[8] );
    sub8x8_dct( &dct[ 8], &pix1[8*FENC_STRIDE+0], &pix2[8*FDEC_STRIDE+0] );
    sub8x8_dct( &dct[12], &pix1[8*FENC_STRIDE+8], &pix2[8*FDEC_STRIDE+8] );
}

static int sub4x4_dct_dc( pixel *pix1, pixel *pix2 )
{
    int sum = 0;
    for( int i=0; i<4; i++, pix1 += FENC_STRIDE, pix2 += FDEC_STRIDE )
        sum += pix1[0] + pix1[1] + pix1[2] + pix1[3]
             - pix2[0] - pix2[1] - pix2[2] - pix2[3];
    return sum;
}

static void sub8x8_dct_dc( dctcoef dct[4], pixel *pix1, pixel *pix2 )
{
    dct[0] = sub4x4_dct_dc( &pix1[0], &pix2[0] );
    dct[1] = sub4x4_dct_dc( &pix1[4], &pix2[4] );
    dct[2] = sub4x4_dct_dc( &pix1[4*FENC_STRIDE+0], &pix2[4*FDEC_STRIDE+0] );
    dct[3] = sub4x4_dct_dc( &pix1[4*FENC_STRIDE+4], &pix2[4*FDEC_STRIDE+4] );

    /* 2x2 DC transform */
    int d0 = dct[0] + dct[1];
    int d1 = dct[2] + dct[3];
    int d2 = dct[0] - dct[1];
    int d3 = dct[2] - dct[3];
    dct[0] = d0 + d1;
    dct[1] = d0 - d1;
    dct[2] = d2 + d3;
    dct[3] = d2 - d3;
}

static void sub8x16_dct_dc( dctcoef dct[8], pixel *pix1, pixel *pix2 )
{
    int a0 = sub4x4_dct_dc( &pix1[ 0*FENC_STRIDE+0], &pix2[ 0*FDEC_STRIDE+0] );
    int a1 = sub4x4_dct_dc( &pix1[ 0*FENC_STRIDE+4], &pix2[ 0*FDEC_STRIDE+4] );
    int a2 = sub4x4_dct_dc( &pix1[ 4*FENC_STRIDE+0], &pix2[ 4*FDEC_STRIDE+0] );
    int a3 = sub4x4_dct_dc( &pix1[ 4*FENC_STRIDE+4], &pix2[ 4*FDEC_STRIDE+4] );
    int a4 = sub4x4_dct_dc( &pix1[ 8*FENC_STRIDE+0], &pix2[ 8*FDEC_STRIDE+0] );
    int a5 = sub4x4_dct_dc( &pix1[ 8*FENC_STRIDE+4], &pix2[ 8*FDEC_STRIDE+4] );
    int a6 = sub4x4_dct_dc( &pix1[12*FENC_STRIDE+0], &pix2[12*FDEC_STRIDE+0] );
    int a7 = sub4x4_dct_dc( &pix1[12*FENC_STRIDE+4], &pix2[12*FDEC_STRIDE+4] );

    /* 2x4 DC transform */
    int b0 = a0 + a1;
    int b1 = a2 + a3;
    int b2 = a4 + a5;
    int b3 = a6 + a7;
    int b4 = a0 - a1;
    int b5 = a2 - a3;
    int b6 = a4 - a5;
    int b7 = a6 - a7;
    a0 = b0 + b1;
    a1 = b2 + b3;
    a2 = b4 + b5;
    a3 = b6 + b7;
    a4 = b0 - b1;
    a5 = b2 - b3;
    a6 = b4 - b5;
    a7 = b6 - b7;
    dct[0] = a0 + a1;
    dct[1] = a2 + a3;
    dct[2] = a0 - a1;
    dct[3] = a2 - a3;
    dct[4] = a4 - a5;
    dct[5] = a6 - a7;
    dct[6] = a4 + a5;
    dct[7] = a6 + a7;
}

static void add4x4_idct( pixel *p_dst, dctcoef dct[16] )
{
    dctcoef d[16];
    dctcoef tmp[16];

    for( int i = 0; i < 4; i++ )
    {
        int s02 =  dct[0*4+i]     +  dct[2*4+i];
        int d02 =  dct[0*4+i]     -  dct[2*4+i];
        int s13 =  dct[1*4+i]     + (dct[3*4+i]>>1);
        int d13 = (dct[1*4+i]>>1) -  dct[3*4+i];

        tmp[i*4+0] = s02 + s13;
        tmp[i*4+1] = d02 + d13;
        tmp[i*4+2] = d02 - d13;
        tmp[i*4+3] = s02 - s13;
    }

    for( int i = 0; i < 4; i++ )
    {
        int s02 =  tmp[0*4+i]     +  tmp[2*4+i];
        int d02 =  tmp[0*4+i]     -  tmp[2*4+i];
        int s13 =  tmp[1*4+i]     + (tmp[3*4+i]>>1);
        int d13 = (tmp[1*4+i]>>1) -  tmp[3*4+i];

        d[0*4+i] = ( s02 + s13 + 32 ) >> 6;
        d[1*4+i] = ( d02 + d13 + 32 ) >> 6;
        d[2*4+i] = ( d02 - d13 + 32 ) >> 6;
        d[3*4+i] = ( s02 - s13 + 32 ) >> 6;
    }


    for( int y = 0; y < 4; y++ )
    {
        for( int x = 0; x < 4; x++ )
            p_dst[x] = x264_clip_pixel( p_dst[x] + d[y*4+x] );
        p_dst += FDEC_STRIDE;
    }
}

static void add8x8_idct( pixel *p_dst, dctcoef dct[4][16] )
{
    add4x4_idct( &p_dst[0],               dct[0] );
    add4x4_idct( &p_dst[4],               dct[1] );
    add4x4_idct( &p_dst[4*FDEC_STRIDE+0], dct[2] );
    add4x4_idct( &p_dst[4*FDEC_STRIDE+4], dct[3] );
}

static void add16x16_idct( pixel *p_dst, dctcoef dct[16][16] )
{
    add8x8_idct( &p_dst[0],               &dct[0] );
    add8x8_idct( &p_dst[8],               &dct[4] );
    add8x8_idct( &p_dst[8*FDEC_STRIDE+0], &dct[8] );
    add8x8_idct( &p_dst[8*FDEC_STRIDE+8], &dct[12] );
}

/****************************************************************************
 * 8x8 transform:
 ****************************************************************************/

#define DCT8_1D {\
    int s07 = SRC(0) + SRC(7);\
    int s16 = SRC(1) + SRC(6);\
    int s25 = SRC(2) + SRC(5);\
    int s34 = SRC(3) + SRC(4);\
    int a0 = s07 + s34;\
    int a1 = s16 + s25;\
    int a2 = s07 - s34;\
    int a3 = s16 - s25;\
    int d07 = SRC(0) - SRC(7);\
    int d16 = SRC(1) - SRC(6);\
    int d25 = SRC(2) - SRC(5);\
    int d34 = SRC(3) - SRC(4);\
    int a4 = d16 + d25 + (d07 + (d07>>1));\
    int a5 = d07 - d34 - (d25 + (d25>>1));\
    int a6 = d07 + d34 - (d16 + (d16>>1));\
    int a7 = d16 - d25 + (d34 + (d34>>1));\
    DST(0) =  a0 + a1     ;\
    DST(1) =  a4 + (a7>>2);\
    DST(2) =  a2 + (a3>>1);\
    DST(3) =  a5 + (a6>>2);\
    DST(4) =  a0 - a1     ;\
    DST(5) =  a6 - (a5>>2);\
    DST(6) = (a2>>1) - a3 ;\
    DST(7) = (a4>>2) - a7 ;\
}

static void sub8x8_dct8( dctcoef dct[64], pixel *pix1, pixel *pix2 )
{
    dctcoef tmp[64];

    pixel_sub_wxh( tmp, 8, pix1, FENC_STRIDE, pix2, FDEC_STRIDE );

#define SRC(x) tmp[x*8+i]
#define DST(x) tmp[x*8+i]
    for( int i = 0; i < 8; i++ )
        DCT8_1D
#undef SRC
#undef DST

#define SRC(x) tmp[i*8+x]
#define DST(x) dct[x*8+i]
    for( int i = 0; i < 8; i++ )
        DCT8_1D
#undef SRC
#undef DST
}

static void sub16x16_dct8( dctcoef dct[4][64], pixel *pix1, pixel *pix2 )
{
    sub8x8_dct8( dct[0], &pix1[0],               &pix2[0] );
    sub8x8_dct8( dct[1], &pix1[8],               &pix2[8] );
    sub8x8_dct8( dct[2], &pix1[8*FENC_STRIDE+0], &pix2[8*FDEC_STRIDE+0] );
    sub8x8_dct8( dct[3], &pix1[8*FENC_STRIDE+8], &pix2[8*FDEC_STRIDE+8] );
}

#define IDCT8_1D {\
    int a0 =  SRC(0) + SRC(4);\
    int a2 =  SRC(0) - SRC(4);\
    int a4 = (SRC(2)>>1) - SRC(6);\
    int a6 = (SRC(6)>>1) + SRC(2);\
    int b0 = a0 + a6;\
    int b2 = a2 + a4;\
    int b4 = a2 - a4;\
    int b6 = a0 - a6;\
    int a1 = -SRC(3) + SRC(5) - SRC(7) - (SRC(7)>>1);\
    int a3 =  SRC(1) + SRC(7) - SRC(3) - (SRC(3)>>1);\
    int a5 = -SRC(1) + SRC(7) + SRC(5) + (SRC(5)>>1);\
    int a7 =  SRC(3) + SRC(5) + SRC(1) + (SRC(1)>>1);\
    int b1 = (a7>>2) + a1;\
    int b3 =  a3 + (a5>>2);\
    int b5 = (a3>>2) - a5;\
    int b7 =  a7 - (a1>>2);\
    DST(0, b0 + b7);\
    DST(1, b2 + b5);\
    DST(2, b4 + b3);\
    DST(3, b6 + b1);\
    DST(4, b6 - b1);\
    DST(5, b4 - b3);\
    DST(6, b2 - b5);\
    DST(7, b0 - b7);\
}

static void add8x8_idct8( pixel *dst, dctcoef dct[64] )
{
    dct[0] += 32; // rounding for the >>6 at the end

#define SRC(x)     dct[x*8+i]
#define DST(x,rhs) dct[x*8+i] = (rhs)
    for( int i = 0; i < 8; i++ )
        IDCT8_1D
#undef SRC
#undef DST

#define SRC(x)     dct[i*8+x]
#define DST(x,rhs) dst[i + x*FDEC_STRIDE] = x264_clip_pixel( dst[i + x*FDEC_STRIDE] + ((rhs) >> 6) );
    for( int i = 0; i < 8; i++ )
        IDCT8_1D
#undef SRC
#undef DST
}

static void add16x16_idct8( pixel *dst, dctcoef dct[4][64] )
{
    add8x8_idct8( &dst[0],               dct[0] );
    add8x8_idct8( &dst[8],               dct[1] );
    add8x8_idct8( &dst[8*FDEC_STRIDE+0], dct[2] );
    add8x8_idct8( &dst[8*FDEC_STRIDE+8], dct[3] );
}

static inline void add4x4_idct_dc( pixel *p_dst, dctcoef dc )
{
    dc = (dc + 32) >> 6;
    for( int i = 0; i < 4; i++, p_dst += FDEC_STRIDE )
    {
        p_dst[0] = x264_clip_pixel( p_dst[0] + dc );
        p_dst[1] = x264_clip_pixel( p_dst[1] + dc );
        p_dst[2] = x264_clip_pixel( p_dst[2] + dc );
        p_dst[3] = x264_clip_pixel( p_dst[3] + dc );
    }
}

static void add8x8_idct_dc( pixel *p_dst, dctcoef dct[4] )
{
    add4x4_idct_dc( &p_dst[0],               dct[0] );
    add4x4_idct_dc( &p_dst[4],               dct[1] );
    add4x4_idct_dc( &p_dst[4*FDEC_STRIDE+0], dct[2] );
    add4x4_idct_dc( &p_dst[4*FDEC_STRIDE+4], dct[3] );
}

static void add16x16_idct_dc( pixel *p_dst, dctcoef dct[16] )
{
    for( int i = 0; i < 4; i++, dct += 4, p_dst += 4*FDEC_STRIDE )
    {
        add4x4_idct_dc( &p_dst[ 0], dct[0] );
        add4x4_idct_dc( &p_dst[ 4], dct[1] );
        add4x4_idct_dc( &p_dst[ 8], dct[2] );
        add4x4_idct_dc( &p_dst[12], dct[3] );
    }
}


/****************************************************************************
 * x264_dct_init:
 ****************************************************************************/
void x264_dct_init( uint32_t cpu, x264_dct_function_t *dctf )
{
    dctf->sub4x4_dct    = sub4x4_dct;
    dctf->add4x4_idct   = add4x4_idct;

    dctf->sub8x8_dct    = sub8x8_dct;
    dctf->sub8x8_dct_dc = sub8x8_dct_dc;
    dctf->add8x8_idct   = add8x8_idct;
    dctf->add8x8_idct_dc = add8x8_idct_dc;

    dctf->sub8x16_dct_dc = sub8x16_dct_dc;

    dctf->sub16x16_dct  = sub16x16_dct;
    dctf->add16x16_idct = add16x16_idct;
    dctf->add16x16_idct_dc = add16x16_idct_dc;

    dctf->sub8x8_dct8   = sub8x8_dct8;
    dctf->add8x8_idct8  = add8x8_idct8;

    dctf->sub16x16_dct8  = sub16x16_dct8;
    dctf->add16x16_idct8 = add16x16_idct8;

    dctf->dct4x4dc  = dct4x4dc;
    dctf->idct4x4dc = idct4x4dc;

    dctf->dct2x4dc = dct2x4dc;

#if HIGH_BIT_DEPTH
#if HAVE_MMX
    if( cpu&X264_CPU_MMX )
    {
        dctf->sub4x4_dct    = x264_sub4x4_dct_mmx;
        dctf->sub8x8_dct    = x264_sub8x8_dct_mmx;
        dctf->sub16x16_dct  = x264_sub16x16_dct_mmx;
    }
    if( cpu&X264_CPU_SSE2 )
    {
        dctf->add4x4_idct     = x264_add4x4_idct_sse2;
        dctf->dct4x4dc        = x264_dct4x4dc_sse2;
        dctf->idct4x4dc       = x264_idct4x4dc_sse2;
        dctf->dct2x4dc        = x264_dct2x4dc_sse2;
        dctf->sub8x8_dct8     = x264_sub8x8_dct8_sse2;
        dctf->sub16x16_dct8   = x264_sub16x16_dct8_sse2;
        dctf->add8x8_idct     = x264_add8x8_idct_sse2;
        dctf->add16x16_idct   = x264_add16x16_idct_sse2;
        dctf->add8x8_idct8    = x264_add8x8_idct8_sse2;
        dctf->add16x16_idct8    = x264_add16x16_idct8_sse2;
        dctf->sub8x8_dct_dc   = x264_sub8x8_dct_dc_sse2;
        dctf->add8x8_idct_dc  = x264_add8x8_idct_dc_sse2;
        dctf->sub8x16_dct_dc  = x264_sub8x16_dct_dc_sse2;
        dctf->add16x16_idct_dc= x264_add16x16_idct_dc_sse2;
    }
    if( cpu&X264_CPU_SSE4 )
    {
        dctf->sub8x8_dct8     = x264_sub8x8_dct8_sse4;
        dctf->sub16x16_dct8   = x264_sub16x16_dct8_sse4;
    }
    if( cpu&X264_CPU_AVX )
    {
        dctf->add4x4_idct     = x264_add4x4_idct_avx;
        dctf->dct4x4dc        = x264_dct4x4dc_avx;
        dctf->idct4x4dc       = x264_idct4x4dc_avx;
        dctf->dct2x4dc        = x264_dct2x4dc_avx;
        dctf->sub8x8_dct8     = x264_sub8x8_dct8_avx;
        dctf->sub16x16_dct8   = x264_sub16x16_dct8_avx;
        dctf->add8x8_idct     = x264_add8x8_idct_avx;
        dctf->add16x16_idct   = x264_add16x16_idct_avx;
        dctf->add8x8_idct8    = x264_add8x8_idct8_avx;
        dctf->add16x16_idct8  = x264_add16x16_idct8_avx;
        dctf->add8x8_idct_dc  = x264_add8x8_idct_dc_avx;
        dctf->sub8x16_dct_dc  = x264_sub8x16_dct_dc_avx;
        dctf->add16x16_idct_dc= x264_add16x16_idct_dc_avx;
    }
#endif // HAVE_MMX
#else // !HIGH_BIT_DEPTH
#if HAVE_MMX
    if( cpu&X264_CPU_MMX )
    {
        dctf->sub4x4_dct    = x264_sub4x4_dct_mmx;
        dctf->add4x4_idct   = x264_add4x4_idct_mmx;
        dctf->idct4x4dc     = x264_idct4x4dc_mmx;
        dctf->sub8x8_dct_dc = x264_sub8x8_dct_dc_mmx2;

#if !ARCH_X86_64
        dctf->sub8x8_dct    = x264_sub8x8_dct_mmx;
        dctf->sub16x16_dct  = x264_sub16x16_dct_mmx;
        dctf->add8x8_idct   = x264_add8x8_idct_mmx;
        dctf->add16x16_idct = x264_add16x16_idct_mmx;

        dctf->sub8x8_dct8   = x264_sub8x8_dct8_mmx;
        dctf->sub16x16_dct8 = x264_sub16x16_dct8_mmx;
        dctf->add8x8_idct8  = x264_add8x8_idct8_mmx;
        dctf->add16x16_idct8= x264_add16x16_idct8_mmx;
#endif
    }

    if( cpu&X264_CPU_MMX2 )
    {
        dctf->dct4x4dc         = x264_dct4x4dc_mmx2;
        dctf->dct2x4dc         = x264_dct2x4dc_mmx2;
        dctf->add8x8_idct_dc   = x264_add8x8_idct_dc_mmx2;
        dctf->add16x16_idct_dc = x264_add16x16_idct_dc_mmx2;
    }

    if( cpu&X264_CPU_SSE2 )
    {
        dctf->sub8x8_dct8   = x264_sub8x8_dct8_sse2;
        dctf->sub16x16_dct8 = x264_sub16x16_dct8_sse2;
        dctf->sub8x8_dct_dc = x264_sub8x8_dct_dc_sse2;
        dctf->sub8x16_dct_dc= x264_sub8x16_dct_dc_sse2;
        dctf->add8x8_idct8  = x264_add8x8_idct8_sse2;
        dctf->add16x16_idct8= x264_add16x16_idct8_sse2;

        if( !(cpu&X264_CPU_SSE2_IS_SLOW) )
        {
            dctf->sub8x8_dct    = x264_sub8x8_dct_sse2;
            dctf->sub16x16_dct  = x264_sub16x16_dct_sse2;
            dctf->add8x8_idct   = x264_add8x8_idct_sse2;
            dctf->add16x16_idct = x264_add16x16_idct_sse2;
            dctf->add16x16_idct_dc = x264_add16x16_idct_dc_sse2;
        }
    }

    if( (cpu&X264_CPU_SSSE3) && !(cpu&X264_CPU_SSE2_IS_SLOW) )
    {
        dctf->sub8x16_dct_dc = x264_sub8x16_dct_dc_ssse3;
        if( !(cpu&X264_CPU_SLOW_ATOM) )
        {
            dctf->sub4x4_dct    = x264_sub4x4_dct_ssse3;
            dctf->sub8x8_dct    = x264_sub8x8_dct_ssse3;
            dctf->sub16x16_dct  = x264_sub16x16_dct_ssse3;
            dctf->sub8x8_dct8   = x264_sub8x8_dct8_ssse3;
            dctf->sub16x16_dct8 = x264_sub16x16_dct8_ssse3;
            if( !(cpu&X264_CPU_SLOW_PSHUFB) )
            {
                dctf->add8x8_idct_dc = x264_add8x8_idct_dc_ssse3;
                dctf->add16x16_idct_dc = x264_add16x16_idct_dc_ssse3;
            }
        }
    }

    if( cpu&X264_CPU_SSE4 )
        dctf->add4x4_idct   = x264_add4x4_idct_sse4;

    if( cpu&X264_CPU_AVX )
    {
        dctf->add4x4_idct      = x264_add4x4_idct_avx;
        dctf->add8x8_idct      = x264_add8x8_idct_avx;
        dctf->add16x16_idct    = x264_add16x16_idct_avx;
        dctf->add8x8_idct8     = x264_add8x8_idct8_avx;
        dctf->add16x16_idct8   = x264_add16x16_idct8_avx;
        dctf->add16x16_idct_dc = x264_add16x16_idct_dc_avx;
        dctf->sub8x8_dct       = x264_sub8x8_dct_avx;
        dctf->sub16x16_dct     = x264_sub16x16_dct_avx;
        dctf->sub8x8_dct8      = x264_sub8x8_dct8_avx;
        dctf->sub16x16_dct8    = x264_sub16x16_dct8_avx;
    }

    if( cpu&X264_CPU_XOP )
    {
        dctf->sub8x8_dct       = x264_sub8x8_dct_xop;
        dctf->sub16x16_dct     = x264_sub16x16_dct_xop;
    }

    if( cpu&X264_CPU_AVX2 )
    {
        dctf->add8x8_idct      = x264_add8x8_idct_avx2;
        dctf->add16x16_idct    = x264_add16x16_idct_avx2;
        dctf->sub8x8_dct       = x264_sub8x8_dct_avx2;
        dctf->sub16x16_dct     = x264_sub16x16_dct_avx2;
        dctf->add16x16_idct_dc = x264_add16x16_idct_dc_avx2;
#if ARCH_X86_64
        dctf->sub16x16_dct8    = x264_sub16x16_dct8_avx2;
#endif
    }

    if( cpu&X264_CPU_AVX512 )
    {
        dctf->sub4x4_dct       = x264_sub4x4_dct_avx512;
        dctf->sub8x8_dct       = x264_sub8x8_dct_avx512;
        dctf->sub16x16_dct     = x264_sub16x16_dct_avx512;
        dctf->sub8x8_dct_dc    = x264_sub8x8_dct_dc_avx512;
        dctf->sub8x16_dct_dc   = x264_sub8x16_dct_dc_avx512;
        dctf->add8x8_idct      = x264_add8x8_idct_avx512;
    }
#endif //HAVE_MMX

#if HAVE_ALTIVEC
    if( cpu&X264_CPU_ALTIVEC )
    {
        dctf->sub4x4_dct    = x264_sub4x4_dct_altivec;
        dctf->sub8x8_dct    = x264_sub8x8_dct_altivec;
        dctf->sub16x16_dct  = x264_sub16x16_dct_altivec;

        dctf->add8x8_idct_dc = x264_add8x8_idct_dc_altivec;
        dctf->add16x16_idct_dc = x264_add16x16_idct_dc_altivec;

        dctf->add4x4_idct   = x264_add4x4_idct_altivec;
        dctf->add8x8_idct   = x264_add8x8_idct_altivec;
        dctf->add16x16_idct = x264_add16x16_idct_altivec;

        dctf->sub8x8_dct_dc = x264_sub8x8_dct_dc_altivec;
        dctf->sub8x8_dct8   = x264_sub8x8_dct8_altivec;
        dctf->sub16x16_dct8 = x264_sub16x16_dct8_altivec;

        dctf->add8x8_idct8  = x264_add8x8_idct8_altivec;
        dctf->add16x16_idct8= x264_add16x16_idct8_altivec;
    }
#endif

#if HAVE_ARMV6 || HAVE_AARCH64
    if( cpu&X264_CPU_NEON )
    {
        dctf->sub4x4_dct    = x264_sub4x4_dct_neon;
        dctf->sub8x8_dct    = x264_sub8x8_dct_neon;
        dctf->sub16x16_dct  = x264_sub16x16_dct_neon;
        dctf->add8x8_idct_dc = x264_add8x8_idct_dc_neon;
        dctf->add16x16_idct_dc = x264_add16x16_idct_dc_neon;
        dctf->sub8x8_dct_dc = x264_sub8x8_dct_dc_neon;
        dctf->dct4x4dc      = x264_dct4x4dc_neon;
        dctf->idct4x4dc     = x264_idct4x4dc_neon;

        dctf->add4x4_idct   = x264_add4x4_idct_neon;
        dctf->add8x8_idct   = x264_add8x8_idct_neon;
        dctf->add16x16_idct = x264_add16x16_idct_neon;

        dctf->sub8x8_dct8   = x264_sub8x8_dct8_neon;
        dctf->sub16x16_dct8 = x264_sub16x16_dct8_neon;

        dctf->add8x8_idct8  = x264_add8x8_idct8_neon;
        dctf->add16x16_idct8= x264_add16x16_idct8_neon;
        dctf->sub8x16_dct_dc= x264_sub8x16_dct_dc_neon;
    }
#endif

#if HAVE_MSA
    if( cpu&X264_CPU_MSA )
    {
        dctf->sub4x4_dct       = x264_sub4x4_dct_msa;
        dctf->sub8x8_dct       = x264_sub8x8_dct_msa;
        dctf->sub16x16_dct     = x264_sub16x16_dct_msa;
        dctf->sub8x8_dct_dc    = x264_sub8x8_dct_dc_msa;
        dctf->sub8x16_dct_dc   = x264_sub8x16_dct_dc_msa;
        dctf->dct4x4dc         = x264_dct4x4dc_msa;
        dctf->idct4x4dc        = x264_idct4x4dc_msa;
        dctf->add4x4_idct      = x264_add4x4_idct_msa;
        dctf->add8x8_idct      = x264_add8x8_idct_msa;
        dctf->add8x8_idct_dc   = x264_add8x8_idct_dc_msa;
        dctf->add16x16_idct    = x264_add16x16_idct_msa;
        dctf->add16x16_idct_dc = x264_add16x16_idct_dc_msa;
        dctf->add8x8_idct8     = x264_add8x8_idct8_msa;
        dctf->add16x16_idct8   = x264_add16x16_idct8_msa;
    }
#endif

#endif // HIGH_BIT_DEPTH
}


#define ZIG(i,y,x) level[i] = dct[x*8+y];
#define ZIGZAG8_FRAME\
    ZIG( 0,0,0) ZIG( 1,0,1) ZIG( 2,1,0) ZIG( 3,2,0)\
    ZIG( 4,1,1) ZIG( 5,0,2) ZIG( 6,0,3) ZIG( 7,1,2)\
    ZIG( 8,2,1) ZIG( 9,3,0) ZIG(10,4,0) ZIG(11,3,1)\
    ZIG(12,2,2) ZIG(13,1,3) ZIG(14,0,4) ZIG(15,0,5)\
    ZIG(16,1,4) ZIG(17,2,3) ZIG(18,3,2) ZIG(19,4,1)\
    ZIG(20,5,0) ZIG(21,6,0) ZIG(22,5,1) ZIG(23,4,2)\
    ZIG(24,3,3) ZIG(25,2,4) ZIG(26,1,5) ZIG(27,0,6)\
    ZIG(28,0,7) ZIG(29,1,6) ZIG(30,2,5) ZIG(31,3,4)\
    ZIG(32,4,3) ZIG(33,5,2) ZIG(34,6,1) ZIG(35,7,0)\
    ZIG(36,7,1) ZIG(37,6,2) ZIG(38,5,3) ZIG(39,4,4)\
    ZIG(40,3,5) ZIG(41,2,6) ZIG(42,1,7) ZIG(43,2,7)\
    ZIG(44,3,6) ZIG(45,4,5) ZIG(46,5,4) ZIG(47,6,3)\
    ZIG(48,7,2) ZIG(49,7,3) ZIG(50,6,4) ZIG(51,5,5)\
    ZIG(52,4,6) ZIG(53,3,7) ZIG(54,4,7) ZIG(55,5,6)\
    ZIG(56,6,5) ZIG(57,7,4) ZIG(58,7,5) ZIG(59,6,6)\
    ZIG(60,5,7) ZIG(61,6,7) ZIG(62,7,6) ZIG(63,7,7)\

#define ZIGZAG8_FIELD\
    ZIG( 0,0,0) ZIG( 1,1,0) ZIG( 2,2,0) ZIG( 3,0,1)\
    ZIG( 4,1,1) ZIG( 5,3,0) ZIG( 6,4,0) ZIG( 7,2,1)\
    ZIG( 8,0,2) ZIG( 9,3,1) ZIG(10,5,0) ZIG(11,6,0)\
    ZIG(12,7,0) ZIG(13,4,1) ZIG(14,1,2) ZIG(15,0,3)\
    ZIG(16,2,2) ZIG(17,5,1) ZIG(18,6,1) ZIG(19,7,1)\
    ZIG(20,3,2) ZIG(21,1,3) ZIG(22,0,4) ZIG(23,2,3)\
    ZIG(24,4,2) ZIG(25,5,2) ZIG(26,6,2) ZIG(27,7,2)\
    ZIG(28,3,3) ZIG(29,1,4) ZIG(30,0,5) ZIG(31,2,4)\
    ZIG(32,4,3) ZIG(33,5,3) ZIG(34,6,3) ZIG(35,7,3)\
    ZIG(36,3,4) ZIG(37,1,5) ZIG(38,0,6) ZIG(39,2,5)\
    ZIG(40,4,4) ZIG(41,5,4) ZIG(42,6,4) ZIG(43,7,4)\
    ZIG(44,3,5) ZIG(45,1,6) ZIG(46,2,6) ZIG(47,4,5)\
    ZIG(48,5,5) ZIG(49,6,5) ZIG(50,7,5) ZIG(51,3,6)\
    ZIG(52,0,7) ZIG(53,1,7) ZIG(54,4,6) ZIG(55,5,6)\
    ZIG(56,6,6) ZIG(57,7,6) ZIG(58,2,7) ZIG(59,3,7)\
    ZIG(60,4,7) ZIG(61,5,7) ZIG(62,6,7) ZIG(63,7,7)

#define ZIGZAG4_FRAME\
    ZIGDC( 0,0,0) ZIG( 1,0,1) ZIG( 2,1,0) ZIG( 3,2,0)\
    ZIG( 4,1,1) ZIG( 5,0,2) ZIG( 6,0,3) ZIG( 7,1,2)\
    ZIG( 8,2,1) ZIG( 9,3,0) ZIG(10,3,1) ZIG(11,2,2)\
    ZIG(12,1,3) ZIG(13,2,3) ZIG(14,3,2) ZIG(15,3,3)

#define ZIGZAG4_FIELD\
    ZIGDC( 0,0,0) ZIG( 1,1,0) ZIG( 2,0,1) ZIG( 3,2,0)\
    ZIG( 4,3,0) ZIG( 5,1,1) ZIG( 6,2,1) ZIG( 7,3,1)\
    ZIG( 8,0,2) ZIG( 9,1,2) ZIG(10,2,2) ZIG(11,3,2)\
    ZIG(12,0,3) ZIG(13,1,3) ZIG(14,2,3) ZIG(15,3,3)

static void zigzag_scan_8x8_frame( dctcoef level[64], dctcoef dct[64] )
{
    ZIGZAG8_FRAME
}

static void zigzag_scan_8x8_field( dctcoef level[64], dctcoef dct[64] )
{
    ZIGZAG8_FIELD
}

#undef ZIG
#define ZIG(i,y,x) level[i] = dct[x*4+y];
#define ZIGDC(i,y,x) ZIG(i,y,x)

static void zigzag_scan_4x4_frame( dctcoef level[16], dctcoef dct[16] )
{
    ZIGZAG4_FRAME
}

static void zigzag_scan_4x4_field( dctcoef level[16], dctcoef dct[16] )
{
    memcpy( level, dct, 2 * sizeof(dctcoef) );
    ZIG(2,0,1) ZIG(3,2,0) ZIG(4,3,0) ZIG(5,1,1)
    memcpy( level+6, dct+6, 10 * sizeof(dctcoef) );
}

#undef ZIG
#define ZIG(i,y,x) {\
    int oe = x+y*FENC_STRIDE;\
    int od = x+y*FDEC_STRIDE;\
    level[i] = p_src[oe] - p_dst[od];\
    nz |= level[i];\
}
#define COPY4x4\
    CPPIXEL_X4( p_dst+0*FDEC_STRIDE, p_src+0*FENC_STRIDE );\
    CPPIXEL_X4( p_dst+1*FDEC_STRIDE, p_src+1*FENC_STRIDE );\
    CPPIXEL_X4( p_dst+2*FDEC_STRIDE, p_src+2*FENC_STRIDE );\
    CPPIXEL_X4( p_dst+3*FDEC_STRIDE, p_src+3*FENC_STRIDE );
#define CPPIXEL_X8(dst,src) ( CPPIXEL_X4(dst,src), CPPIXEL_X4(dst+4,src+4) )
#define COPY8x8\
    CPPIXEL_X8( p_dst+0*FDEC_STRIDE, p_src+0*FENC_STRIDE );\
    CPPIXEL_X8( p_dst+1*FDEC_STRIDE, p_src+1*FENC_STRIDE );\
    CPPIXEL_X8( p_dst+2*FDEC_STRIDE, p_src+2*FENC_STRIDE );\
    CPPIXEL_X8( p_dst+3*FDEC_STRIDE, p_src+3*FENC_STRIDE );\
    CPPIXEL_X8( p_dst+4*FDEC_STRIDE, p_src+4*FENC_STRIDE );\
    CPPIXEL_X8( p_dst+5*FDEC_STRIDE, p_src+5*FENC_STRIDE );\
    CPPIXEL_X8( p_dst+6*FDEC_STRIDE, p_src+6*FENC_STRIDE );\
    CPPIXEL_X8( p_dst+7*FDEC_STRIDE, p_src+7*FENC_STRIDE );

static int zigzag_sub_4x4_frame( dctcoef level[16], const pixel *p_src, pixel *p_dst )
{
    int nz = 0;
    ZIGZAG4_FRAME
    COPY4x4
    return !!nz;
}

static int zigzag_sub_4x4_field( dctcoef level[16], const pixel *p_src, pixel *p_dst )
{
    int nz = 0;
    ZIGZAG4_FIELD
    COPY4x4
    return !!nz;
}

#undef ZIGDC
#define ZIGDC(i,y,x) {\
    int oe = x+y*FENC_STRIDE;\
    int od = x+y*FDEC_STRIDE;\
    *dc = p_src[oe] - p_dst[od];\
    level[0] = 0;\
}

static int zigzag_sub_4x4ac_frame( dctcoef level[16], const pixel *p_src, pixel *p_dst, dctcoef *dc )
{
    int nz = 0;
    ZIGZAG4_FRAME
    COPY4x4
    return !!nz;
}

static int zigzag_sub_4x4ac_field( dctcoef level[16], const pixel *p_src, pixel *p_dst, dctcoef *dc )
{
    int nz = 0;
    ZIGZAG4_FIELD
    COPY4x4
    return !!nz;
}

static int zigzag_sub_8x8_frame( dctcoef level[64], const pixel *p_src, pixel *p_dst )
{
    int nz = 0;
    ZIGZAG8_FRAME
    COPY8x8
    return !!nz;
}
static int zigzag_sub_8x8_field( dctcoef level[64], const pixel *p_src, pixel *p_dst )
{
    int nz = 0;
    ZIGZAG8_FIELD
    COPY8x8
    return !!nz;
}

#undef ZIG
#undef COPY4x4

static void zigzag_interleave_8x8_cavlc( dctcoef *dst, dctcoef *src, uint8_t *nnz )
{
    for( int i = 0; i < 4; i++ )
    {
        int nz = 0;
        for( int j = 0; j < 16; j++ )
        {
            nz |= src[i+j*4];
            dst[i*16+j] = src[i+j*4];
        }
        nnz[(i&1) + (i>>1)*8] = !!nz;
    }
}

void x264_zigzag_init( uint32_t cpu, x264_zigzag_function_t *pf_progressive, x264_zigzag_function_t *pf_interlaced )
{
    pf_interlaced->scan_8x8   = zigzag_scan_8x8_field;
    pf_progressive->scan_8x8  = zigzag_scan_8x8_frame;
    pf_interlaced->scan_4x4   = zigzag_scan_4x4_field;
    pf_progressive->scan_4x4  = zigzag_scan_4x4_frame;
    pf_interlaced->sub_8x8    = zigzag_sub_8x8_field;
    pf_progressive->sub_8x8   = zigzag_sub_8x8_frame;
    pf_interlaced->sub_4x4    = zigzag_sub_4x4_field;
    pf_progressive->sub_4x4   = zigzag_sub_4x4_frame;
    pf_interlaced->sub_4x4ac  = zigzag_sub_4x4ac_field;
    pf_progressive->sub_4x4ac = zigzag_sub_4x4ac_frame;

#if HIGH_BIT_DEPTH
#if HAVE_MMX
    if( cpu&X264_CPU_SSE2 )
    {
        pf_interlaced->scan_4x4  = x264_zigzag_scan_4x4_field_sse2;
        pf_progressive->scan_4x4 = x264_zigzag_scan_4x4_frame_sse2;
        pf_progressive->scan_8x8 = x264_zigzag_scan_8x8_frame_sse2;
    }
    if( cpu&X264_CPU_SSE4 )
        pf_interlaced->scan_8x8 = x264_zigzag_scan_8x8_field_sse4;
    if( cpu&X264_CPU_AVX )
        pf_interlaced->scan_8x8 = x264_zigzag_scan_8x8_field_avx;
#if ARCH_X86_64
    if( cpu&X264_CPU_AVX )
    {
        pf_progressive->scan_4x4 = x264_zigzag_scan_4x4_frame_avx;
        pf_progressive->scan_8x8 = x264_zigzag_scan_8x8_frame_avx;
    }
#endif // ARCH_X86_64
    if( cpu&X264_CPU_AVX512 )
    {
        pf_interlaced->scan_4x4  = x264_zigzag_scan_4x4_field_avx512;
        pf_progressive->scan_4x4 = x264_zigzag_scan_4x4_frame_avx512;
        pf_interlaced->scan_8x8  = x264_zigzag_scan_8x8_field_avx512;
        pf_progressive->scan_8x8 = x264_zigzag_scan_8x8_frame_avx512;
    }
#endif // HAVE_MMX
#else
#if HAVE_MMX
    if( cpu&X264_CPU_MMX )
        pf_progressive->scan_4x4 = x264_zigzag_scan_4x4_frame_mmx;
    if( cpu&X264_CPU_MMX2 )
    {
        pf_interlaced->scan_8x8  = x264_zigzag_scan_8x8_field_mmx2;
        pf_progressive->scan_8x8 = x264_zigzag_scan_8x8_frame_mmx2;
    }
    if( cpu&X264_CPU_SSE )
        pf_interlaced->scan_4x4  = x264_zigzag_scan_4x4_field_sse;
    if( cpu&X264_CPU_SSE2_IS_FAST )
        pf_progressive->scan_8x8 = x264_zigzag_scan_8x8_frame_sse2;
    if( cpu&X264_CPU_SSSE3 )
    {
        pf_interlaced->sub_4x4   = x264_zigzag_sub_4x4_field_ssse3;
        pf_progressive->sub_4x4  = x264_zigzag_sub_4x4_frame_ssse3;
        pf_interlaced->sub_4x4ac = x264_zigzag_sub_4x4ac_field_ssse3;
        pf_progressive->sub_4x4ac= x264_zigzag_sub_4x4ac_frame_ssse3;
        pf_progressive->scan_8x8 = x264_zigzag_scan_8x8_frame_ssse3;
        if( !(cpu&X264_CPU_SLOW_SHUFFLE) )
            pf_progressive->scan_4x4 = x264_zigzag_scan_4x4_frame_ssse3;
    }
    if( cpu&X264_CPU_AVX )
    {
        pf_interlaced->sub_4x4   = x264_zigzag_sub_4x4_field_avx;
        pf_progressive->sub_4x4  = x264_zigzag_sub_4x4_frame_avx;
#if ARCH_X86_64
        pf_interlaced->sub_4x4ac = x264_zigzag_sub_4x4ac_field_avx;
        pf_progressive->sub_4x4ac= x264_zigzag_sub_4x4ac_frame_avx;
#endif
        pf_progressive->scan_4x4 = x264_zigzag_scan_4x4_frame_avx;
    }
    if( cpu&X264_CPU_XOP )
    {
        pf_progressive->scan_4x4 = x264_zigzag_scan_4x4_frame_xop;
        pf_progressive->scan_8x8 = x264_zigzag_scan_8x8_frame_xop;
        pf_interlaced->scan_8x8 = x264_zigzag_scan_8x8_field_xop;
    }
    if( cpu&X264_CPU_AVX512 )
    {
        pf_interlaced->scan_4x4  = x264_zigzag_scan_4x4_field_avx512;
        pf_progressive->scan_4x4 = x264_zigzag_scan_4x4_frame_avx512;
        pf_interlaced->scan_8x8  = x264_zigzag_scan_8x8_field_avx512;
        pf_progressive->scan_8x8 = x264_zigzag_scan_8x8_frame_avx512;
    }
#endif // HAVE_MMX
#if HAVE_ALTIVEC
    if( cpu&X264_CPU_ALTIVEC )
    {
        pf_interlaced->scan_4x4  = x264_zigzag_scan_4x4_field_altivec;
        pf_progressive->scan_4x4 = x264_zigzag_scan_4x4_frame_altivec;
        pf_progressive->scan_8x8  = x264_zigzag_scan_8x8_frame_altivec;
    }
#endif
#if HAVE_ARMV6 || HAVE_AARCH64
    if( cpu&X264_CPU_NEON )
    {
        pf_progressive->scan_4x4  = x264_zigzag_scan_4x4_frame_neon;
#if HAVE_AARCH64
        pf_interlaced->scan_4x4   = x264_zigzag_scan_4x4_field_neon;
        pf_interlaced->scan_8x8   = x264_zigzag_scan_8x8_field_neon;
        pf_interlaced->sub_4x4    = x264_zigzag_sub_4x4_field_neon;
        pf_interlaced->sub_4x4ac  = x264_zigzag_sub_4x4ac_field_neon;
        pf_interlaced->sub_8x8    = x264_zigzag_sub_8x8_field_neon;
        pf_progressive->scan_8x8  = x264_zigzag_scan_8x8_frame_neon;
        pf_progressive->sub_4x4   = x264_zigzag_sub_4x4_frame_neon;
        pf_progressive->sub_4x4ac = x264_zigzag_sub_4x4ac_frame_neon;
        pf_progressive->sub_8x8   = x264_zigzag_sub_8x8_frame_neon;
#endif // HAVE_AARCH64
    }
#endif // HAVE_ARMV6 || HAVE_AARCH64
#endif // HIGH_BIT_DEPTH

    pf_interlaced->interleave_8x8_cavlc =
    pf_progressive->interleave_8x8_cavlc = zigzag_interleave_8x8_cavlc;
#if HAVE_MMX
#if HIGH_BIT_DEPTH
    if( cpu&X264_CPU_SSE2 )
    {
        pf_interlaced->interleave_8x8_cavlc =
        pf_progressive->interleave_8x8_cavlc = x264_zigzag_interleave_8x8_cavlc_sse2;
    }
    if( cpu&X264_CPU_AVX )
    {
        pf_interlaced->interleave_8x8_cavlc =
        pf_progressive->interleave_8x8_cavlc = x264_zigzag_interleave_8x8_cavlc_avx;
    }
    if( cpu&X264_CPU_AVX512 )
    {
        pf_interlaced->interleave_8x8_cavlc =
        pf_progressive->interleave_8x8_cavlc = x264_zigzag_interleave_8x8_cavlc_avx512;
    }
#else
    if( cpu&X264_CPU_MMX )
    {
        pf_interlaced->interleave_8x8_cavlc =
        pf_progressive->interleave_8x8_cavlc = x264_zigzag_interleave_8x8_cavlc_mmx;
    }
    if( (cpu&X264_CPU_SSE2) && !(cpu&(X264_CPU_SLOW_SHUFFLE|X264_CPU_SSE2_IS_SLOW)) )
    {
        pf_interlaced->interleave_8x8_cavlc =
        pf_progressive->interleave_8x8_cavlc = x264_zigzag_interleave_8x8_cavlc_sse2;
    }

    if( cpu&X264_CPU_AVX )
    {
        pf_interlaced->interleave_8x8_cavlc =
        pf_progressive->interleave_8x8_cavlc = x264_zigzag_interleave_8x8_cavlc_avx;
    }

    if( cpu&X264_CPU_AVX2 )
    {
        pf_interlaced->interleave_8x8_cavlc =
        pf_progressive->interleave_8x8_cavlc = x264_zigzag_interleave_8x8_cavlc_avx2;
    }
    if( cpu&X264_CPU_AVX512 )
    {
        pf_interlaced->interleave_8x8_cavlc =
        pf_progressive->interleave_8x8_cavlc = x264_zigzag_interleave_8x8_cavlc_avx512;
    }
#endif // HIGH_BIT_DEPTH
#endif
#if !HIGH_BIT_DEPTH
#if HAVE_AARCH64
    if( cpu&X264_CPU_NEON )
    {
        pf_interlaced->interleave_8x8_cavlc =
        pf_progressive->interleave_8x8_cavlc =  x264_zigzag_interleave_8x8_cavlc_neon;
    }
#endif // HAVE_AARCH64

#if HAVE_ALTIVEC
    if( cpu&X264_CPU_ALTIVEC )
    {
        pf_interlaced->interleave_8x8_cavlc =
        pf_progressive->interleave_8x8_cavlc = x264_zigzag_interleave_8x8_cavlc_altivec;
    }
#endif // HAVE_ALTIVEC

#if HAVE_MSA
    if( cpu&X264_CPU_MSA )
    {
        pf_progressive->scan_4x4  = x264_zigzag_scan_4x4_frame_msa;
    }
#endif
#endif // !HIGH_BIT_DEPTH
}
