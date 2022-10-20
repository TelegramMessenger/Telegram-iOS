/*****************************************************************************
 * predict.c: intra prediction
 *****************************************************************************
 * Copyright (C) 2003-2022 x264 project
 *
 * Authors: Laurent Aimar <fenrir@via.ecp.fr>
 *          Loren Merritt <lorenm@u.washington.edu>
 *          Fiona Glaser <fiona@x264.com>
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

/* predict4x4 are inspired from ffmpeg h264 decoder */


#include "common.h"

#if HAVE_MMX
#   include "x86/predict.h"
#endif
#if HAVE_ALTIVEC
#   include "ppc/predict.h"
#endif
#if HAVE_ARMV6
#   include "arm/predict.h"
#endif
#if HAVE_AARCH64
#   include "aarch64/predict.h"
#endif
#if HAVE_MSA
#   include "mips/predict.h"
#endif

/****************************************************************************
 * 16x16 prediction for intra luma block
 ****************************************************************************/

#define PREDICT_16x16_DC(v)\
    for( int i = 0; i < 16; i++ )\
    {\
        MPIXEL_X4( src+ 0 ) = v;\
        MPIXEL_X4( src+ 4 ) = v;\
        MPIXEL_X4( src+ 8 ) = v;\
        MPIXEL_X4( src+12 ) = v;\
        src += FDEC_STRIDE;\
    }

void x264_predict_16x16_dc_c( pixel *src )
{
    int dc = 0;

    for( int i = 0; i < 16; i++ )
    {
        dc += src[-1 + i * FDEC_STRIDE];
        dc += src[i - FDEC_STRIDE];
    }
    pixel4 dcsplat = PIXEL_SPLAT_X4( ( dc + 16 ) >> 5 );

    PREDICT_16x16_DC( dcsplat );
}
static void predict_16x16_dc_left_c( pixel *src )
{
    int dc = 0;

    for( int i = 0; i < 16; i++ )
        dc += src[-1 + i * FDEC_STRIDE];
    pixel4 dcsplat = PIXEL_SPLAT_X4( ( dc + 8 ) >> 4 );

    PREDICT_16x16_DC( dcsplat );
}
static void predict_16x16_dc_top_c( pixel *src )
{
    int dc = 0;

    for( int i = 0; i < 16; i++ )
        dc += src[i - FDEC_STRIDE];
    pixel4 dcsplat = PIXEL_SPLAT_X4( ( dc + 8 ) >> 4 );

    PREDICT_16x16_DC( dcsplat );
}
static void predict_16x16_dc_128_c( pixel *src )
{
    PREDICT_16x16_DC( PIXEL_SPLAT_X4( 1 << (BIT_DEPTH-1) ) );
}
void x264_predict_16x16_h_c( pixel *src )
{
    for( int i = 0; i < 16; i++ )
    {
        const pixel4 v = PIXEL_SPLAT_X4( src[-1] );
        MPIXEL_X4( src+ 0 ) = v;
        MPIXEL_X4( src+ 4 ) = v;
        MPIXEL_X4( src+ 8 ) = v;
        MPIXEL_X4( src+12 ) = v;
        src += FDEC_STRIDE;
    }
}
void x264_predict_16x16_v_c( pixel *src )
{
    pixel4 v0 = MPIXEL_X4( &src[ 0-FDEC_STRIDE] );
    pixel4 v1 = MPIXEL_X4( &src[ 4-FDEC_STRIDE] );
    pixel4 v2 = MPIXEL_X4( &src[ 8-FDEC_STRIDE] );
    pixel4 v3 = MPIXEL_X4( &src[12-FDEC_STRIDE] );

    for( int i = 0; i < 16; i++ )
    {
        MPIXEL_X4( src+ 0 ) = v0;
        MPIXEL_X4( src+ 4 ) = v1;
        MPIXEL_X4( src+ 8 ) = v2;
        MPIXEL_X4( src+12 ) = v3;
        src += FDEC_STRIDE;
    }
}
void x264_predict_16x16_p_c( pixel *src )
{
    int H = 0, V = 0;

    /* calculate H and V */
    for( int i = 0; i <= 7; i++ )
    {
        H += ( i + 1 ) * ( src[ 8 + i - FDEC_STRIDE ] - src[6 -i -FDEC_STRIDE] );
        V += ( i + 1 ) * ( src[-1 + (8+i)*FDEC_STRIDE] - src[-1 + (6-i)*FDEC_STRIDE] );
    }

    int a = 16 * ( src[-1 + 15*FDEC_STRIDE] + src[15 - FDEC_STRIDE] );
    int b = ( 5 * H + 32 ) >> 6;
    int c = ( 5 * V + 32 ) >> 6;

    int i00 = a - b * 7 - c * 7 + 16;

    for( int y = 0; y < 16; y++ )
    {
        int pix = i00;
        for( int x = 0; x < 16; x++ )
        {
            src[x] = x264_clip_pixel( pix>>5 );
            pix += b;
        }
        src += FDEC_STRIDE;
        i00 += c;
    }
}


/****************************************************************************
 * 8x8 prediction for intra chroma block (4:2:0)
 ****************************************************************************/

static void predict_8x8c_dc_128_c( pixel *src )
{
    for( int y = 0; y < 8; y++ )
    {
        MPIXEL_X4( src+0 ) = PIXEL_SPLAT_X4( 1 << (BIT_DEPTH-1) );
        MPIXEL_X4( src+4 ) = PIXEL_SPLAT_X4( 1 << (BIT_DEPTH-1) );
        src += FDEC_STRIDE;
    }
}
static void predict_8x8c_dc_left_c( pixel *src )
{
    int dc0 = 0, dc1 = 0;

    for( int y = 0; y < 4; y++ )
    {
        dc0 += src[y * FDEC_STRIDE     - 1];
        dc1 += src[(y+4) * FDEC_STRIDE - 1];
    }
    pixel4 dc0splat = PIXEL_SPLAT_X4( ( dc0 + 2 ) >> 2 );
    pixel4 dc1splat = PIXEL_SPLAT_X4( ( dc1 + 2 ) >> 2 );

    for( int y = 0; y < 4; y++ )
    {
        MPIXEL_X4( src+0 ) = dc0splat;
        MPIXEL_X4( src+4 ) = dc0splat;
        src += FDEC_STRIDE;
    }
    for( int y = 0; y < 4; y++ )
    {
        MPIXEL_X4( src+0 ) = dc1splat;
        MPIXEL_X4( src+4 ) = dc1splat;
        src += FDEC_STRIDE;
    }

}
static void predict_8x8c_dc_top_c( pixel *src )
{
    int dc0 = 0, dc1 = 0;

    for( int x = 0; x < 4; x++ )
    {
        dc0 += src[x     - FDEC_STRIDE];
        dc1 += src[x + 4 - FDEC_STRIDE];
    }
    pixel4 dc0splat = PIXEL_SPLAT_X4( ( dc0 + 2 ) >> 2 );
    pixel4 dc1splat = PIXEL_SPLAT_X4( ( dc1 + 2 ) >> 2 );

    for( int y = 0; y < 8; y++ )
    {
        MPIXEL_X4( src+0 ) = dc0splat;
        MPIXEL_X4( src+4 ) = dc1splat;
        src += FDEC_STRIDE;
    }
}
void x264_predict_8x8c_dc_c( pixel *src )
{
    int s0 = 0, s1 = 0, s2 = 0, s3 = 0;

    /*
          s0 s1
       s2
       s3
    */
    for( int i = 0; i < 4; i++ )
    {
        s0 += src[i - FDEC_STRIDE];
        s1 += src[i + 4 - FDEC_STRIDE];
        s2 += src[-1 + i * FDEC_STRIDE];
        s3 += src[-1 + (i+4)*FDEC_STRIDE];
    }
    /*
       dc0 dc1
       dc2 dc3
     */
    pixel4 dc0 = PIXEL_SPLAT_X4( ( s0 + s2 + 4 ) >> 3 );
    pixel4 dc1 = PIXEL_SPLAT_X4( ( s1 + 2 ) >> 2 );
    pixel4 dc2 = PIXEL_SPLAT_X4( ( s3 + 2 ) >> 2 );
    pixel4 dc3 = PIXEL_SPLAT_X4( ( s1 + s3 + 4 ) >> 3 );

    for( int y = 0; y < 4; y++ )
    {
        MPIXEL_X4( src+0 ) = dc0;
        MPIXEL_X4( src+4 ) = dc1;
        src += FDEC_STRIDE;
    }

    for( int y = 0; y < 4; y++ )
    {
        MPIXEL_X4( src+0 ) = dc2;
        MPIXEL_X4( src+4 ) = dc3;
        src += FDEC_STRIDE;
    }
}
void x264_predict_8x8c_h_c( pixel *src )
{
    for( int i = 0; i < 8; i++ )
    {
        pixel4 v = PIXEL_SPLAT_X4( src[-1] );
        MPIXEL_X4( src+0 ) = v;
        MPIXEL_X4( src+4 ) = v;
        src += FDEC_STRIDE;
    }
}
void x264_predict_8x8c_v_c( pixel *src )
{
    pixel4 v0 = MPIXEL_X4( src+0-FDEC_STRIDE );
    pixel4 v1 = MPIXEL_X4( src+4-FDEC_STRIDE );

    for( int i = 0; i < 8; i++ )
    {
        MPIXEL_X4( src+0 ) = v0;
        MPIXEL_X4( src+4 ) = v1;
        src += FDEC_STRIDE;
    }
}
void x264_predict_8x8c_p_c( pixel *src )
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

    for( int y = 0; y < 8; y++ )
    {
        int pix = i00;
        for( int x = 0; x < 8; x++ )
        {
            src[x] = x264_clip_pixel( pix>>5 );
            pix += b;
        }
        src += FDEC_STRIDE;
        i00 += c;
    }
}

/****************************************************************************
 * 8x16 prediction for intra chroma block (4:2:2)
 ****************************************************************************/

static void predict_8x16c_dc_128_c( pixel *src )
{
    for( int y = 0; y < 16; y++ )
    {
        MPIXEL_X4( src+0 ) = PIXEL_SPLAT_X4( 1 << (BIT_DEPTH-1) );
        MPIXEL_X4( src+4 ) = PIXEL_SPLAT_X4( 1 << (BIT_DEPTH-1) );
        src += FDEC_STRIDE;
    }
}
static void predict_8x16c_dc_left_c( pixel *src )
{
    for( int i = 0; i < 4; i++ )
    {
        int dc = 0;

        for( int y = 0; y < 4; y++ )
            dc += src[y*FDEC_STRIDE - 1];

        pixel4 dcsplat = PIXEL_SPLAT_X4( (dc + 2) >> 2 );

        for( int y = 0; y < 4; y++ )
        {
            MPIXEL_X4( src+0 ) = dcsplat;
            MPIXEL_X4( src+4 ) = dcsplat;
            src += FDEC_STRIDE;
        }
    }
}
static void predict_8x16c_dc_top_c( pixel *src )
{
    int dc0 = 0, dc1 = 0;

    for( int  x = 0; x < 4; x++ )
    {
        dc0 += src[x     - FDEC_STRIDE];
        dc1 += src[x + 4 - FDEC_STRIDE];
    }
    pixel4 dc0splat = PIXEL_SPLAT_X4( ( dc0 + 2 ) >> 2 );
    pixel4 dc1splat = PIXEL_SPLAT_X4( ( dc1 + 2 ) >> 2 );

    for( int y = 0; y < 16; y++ )
    {
        MPIXEL_X4( src+0 ) = dc0splat;
        MPIXEL_X4( src+4 ) = dc1splat;
        src += FDEC_STRIDE;
    }
}
void x264_predict_8x16c_dc_c( pixel *src )
{
    int s0 = 0, s1 = 0, s2 = 0, s3 = 0, s4 = 0, s5 = 0;

    /*
          s0 s1
       s2
       s3
       s4
       s5
    */
    for( int i = 0; i < 4; i++ )
    {
        s0 += src[i+0 - FDEC_STRIDE];
        s1 += src[i+4 - FDEC_STRIDE];
        s2 += src[-1 + (i+0)  * FDEC_STRIDE];
        s3 += src[-1 + (i+4)  * FDEC_STRIDE];
        s4 += src[-1 + (i+8)  * FDEC_STRIDE];
        s5 += src[-1 + (i+12) * FDEC_STRIDE];
    }
    /*
       dc0 dc1
       dc2 dc3
       dc4 dc5
       dc6 dc7
    */
    pixel4 dc0 = PIXEL_SPLAT_X4( ( s0 + s2 + 4 ) >> 3 );
    pixel4 dc1 = PIXEL_SPLAT_X4( ( s1 + 2 ) >> 2 );
    pixel4 dc2 = PIXEL_SPLAT_X4( ( s3 + 2 ) >> 2 );
    pixel4 dc3 = PIXEL_SPLAT_X4( ( s1 + s3 + 4 ) >> 3 );
    pixel4 dc4 = PIXEL_SPLAT_X4( ( s4 + 2 ) >> 2 );
    pixel4 dc5 = PIXEL_SPLAT_X4( ( s1 + s4 + 4 ) >> 3 );
    pixel4 dc6 = PIXEL_SPLAT_X4( ( s5 + 2 ) >> 2 );
    pixel4 dc7 = PIXEL_SPLAT_X4( ( s1 + s5 + 4 ) >> 3 );

    for( int y = 0; y < 4; y++ )
    {
        MPIXEL_X4( src+0 ) = dc0;
        MPIXEL_X4( src+4 ) = dc1;
        src += FDEC_STRIDE;
    }
    for( int y = 0; y < 4; y++ )
    {
        MPIXEL_X4( src+0 ) = dc2;
        MPIXEL_X4( src+4 ) = dc3;
        src += FDEC_STRIDE;
    }
    for( int y = 0; y < 4; y++ )
    {
        MPIXEL_X4( src+0 ) = dc4;
        MPIXEL_X4( src+4 ) = dc5;
        src += FDEC_STRIDE;
    }
    for( int y = 0; y < 4; y++ )
    {
        MPIXEL_X4( src+0 ) = dc6;
        MPIXEL_X4( src+4 ) = dc7;
        src += FDEC_STRIDE;
    }
}
void x264_predict_8x16c_h_c( pixel *src )
{
    for( int i = 0; i < 16; i++ )
    {
        pixel4 v = PIXEL_SPLAT_X4( src[-1] );
        MPIXEL_X4( src+0 ) = v;
        MPIXEL_X4( src+4 ) = v;
        src += FDEC_STRIDE;
    }
}
void x264_predict_8x16c_v_c( pixel *src )
{
    pixel4 v0 = MPIXEL_X4( src+0-FDEC_STRIDE );
    pixel4 v1 = MPIXEL_X4( src+4-FDEC_STRIDE );

    for( int i = 0; i < 16; i++ )
    {
        MPIXEL_X4( src+0 ) = v0;
        MPIXEL_X4( src+4 ) = v1;
        src += FDEC_STRIDE;
    }
}
void x264_predict_8x16c_p_c( pixel *src )
{
    int H = 0;
    int V = 0;

    for( int i = 0; i < 4; i++ )
        H += ( i + 1 ) * ( src[4 + i - FDEC_STRIDE] - src[2 - i - FDEC_STRIDE] );
    for( int i = 0; i < 8; i++ )
        V += ( i + 1 ) * ( src[-1 + (i+8)*FDEC_STRIDE] - src[-1 + (6-i)*FDEC_STRIDE] );

    int a = 16 * ( src[-1 + 15*FDEC_STRIDE] + src[7 - FDEC_STRIDE] );
    int b = ( 17 * H + 16 ) >> 5;
    int c = ( 5 * V + 32 ) >> 6;
    int i00 = a -3*b -7*c + 16;

    for( int y = 0; y < 16; y++ )
    {
        int pix = i00;
        for( int x = 0; x < 8; x++ )
        {
            src[x] = x264_clip_pixel( pix>>5 );
            pix += b;
        }
        src += FDEC_STRIDE;
        i00 += c;
    }
}

/****************************************************************************
 * 4x4 prediction for intra luma block
 ****************************************************************************/

#define SRC(x,y) src[(x)+(y)*FDEC_STRIDE]
#define SRC_X4(x,y) MPIXEL_X4( &SRC(x,y) )

#define PREDICT_4x4_DC(v)\
    SRC_X4(0,0) = SRC_X4(0,1) = SRC_X4(0,2) = SRC_X4(0,3) = v;

static void predict_4x4_dc_128_c( pixel *src )
{
    PREDICT_4x4_DC( PIXEL_SPLAT_X4( 1 << (BIT_DEPTH-1) ) );
}
static void predict_4x4_dc_left_c( pixel *src )
{
    pixel4 dc = PIXEL_SPLAT_X4( (SRC(-1,0) + SRC(-1,1) + SRC(-1,2) + SRC(-1,3) + 2) >> 2 );
    PREDICT_4x4_DC( dc );
}
static void predict_4x4_dc_top_c( pixel *src )
{
    pixel4 dc = PIXEL_SPLAT_X4( (SRC(0,-1) + SRC(1,-1) + SRC(2,-1) + SRC(3,-1) + 2) >> 2 );
    PREDICT_4x4_DC( dc );
}
void x264_predict_4x4_dc_c( pixel *src )
{
    pixel4 dc = PIXEL_SPLAT_X4( (SRC(-1,0) + SRC(-1,1) + SRC(-1,2) + SRC(-1,3) +
                                 SRC(0,-1) + SRC(1,-1) + SRC(2,-1) + SRC(3,-1) + 4) >> 3 );
    PREDICT_4x4_DC( dc );
}
void x264_predict_4x4_h_c( pixel *src )
{
    SRC_X4(0,0) = PIXEL_SPLAT_X4( SRC(-1,0) );
    SRC_X4(0,1) = PIXEL_SPLAT_X4( SRC(-1,1) );
    SRC_X4(0,2) = PIXEL_SPLAT_X4( SRC(-1,2) );
    SRC_X4(0,3) = PIXEL_SPLAT_X4( SRC(-1,3) );
}
void x264_predict_4x4_v_c( pixel *src )
{
    PREDICT_4x4_DC(SRC_X4(0,-1));
}

#define PREDICT_4x4_LOAD_LEFT\
    int l0 = SRC(-1,0);\
    int l1 = SRC(-1,1);\
    int l2 = SRC(-1,2);\
    UNUSED int l3 = SRC(-1,3);

#define PREDICT_4x4_LOAD_TOP\
    int t0 = SRC(0,-1);\
    int t1 = SRC(1,-1);\
    int t2 = SRC(2,-1);\
    UNUSED int t3 = SRC(3,-1);

#define PREDICT_4x4_LOAD_TOP_RIGHT\
    int t4 = SRC(4,-1);\
    int t5 = SRC(5,-1);\
    int t6 = SRC(6,-1);\
    UNUSED int t7 = SRC(7,-1);

#define F1(a,b)   (((a)+(b)+1)>>1)
#define F2(a,b,c) (((a)+2*(b)+(c)+2)>>2)

static void predict_4x4_ddl_c( pixel *src )
{
    PREDICT_4x4_LOAD_TOP
    PREDICT_4x4_LOAD_TOP_RIGHT
    SRC(0,0)= F2(t0,t1,t2);
    SRC(1,0)=SRC(0,1)= F2(t1,t2,t3);
    SRC(2,0)=SRC(1,1)=SRC(0,2)= F2(t2,t3,t4);
    SRC(3,0)=SRC(2,1)=SRC(1,2)=SRC(0,3)= F2(t3,t4,t5);
    SRC(3,1)=SRC(2,2)=SRC(1,3)= F2(t4,t5,t6);
    SRC(3,2)=SRC(2,3)= F2(t5,t6,t7);
    SRC(3,3)= F2(t6,t7,t7);
}
static void predict_4x4_ddr_c( pixel *src )
{
    int lt = SRC(-1,-1);
    PREDICT_4x4_LOAD_LEFT
    PREDICT_4x4_LOAD_TOP
    SRC(3,0)= F2(t3,t2,t1);
    SRC(2,0)=SRC(3,1)= F2(t2,t1,t0);
    SRC(1,0)=SRC(2,1)=SRC(3,2)= F2(t1,t0,lt);
    SRC(0,0)=SRC(1,1)=SRC(2,2)=SRC(3,3)= F2(t0,lt,l0);
    SRC(0,1)=SRC(1,2)=SRC(2,3)= F2(lt,l0,l1);
    SRC(0,2)=SRC(1,3)= F2(l0,l1,l2);
    SRC(0,3)= F2(l1,l2,l3);
}

static void predict_4x4_vr_c( pixel *src )
{
    int lt = SRC(-1,-1);
    PREDICT_4x4_LOAD_LEFT
    PREDICT_4x4_LOAD_TOP
    SRC(0,3)= F2(l2,l1,l0);
    SRC(0,2)= F2(l1,l0,lt);
    SRC(0,1)=SRC(1,3)= F2(l0,lt,t0);
    SRC(0,0)=SRC(1,2)= F1(lt,t0);
    SRC(1,1)=SRC(2,3)= F2(lt,t0,t1);
    SRC(1,0)=SRC(2,2)= F1(t0,t1);
    SRC(2,1)=SRC(3,3)= F2(t0,t1,t2);
    SRC(2,0)=SRC(3,2)= F1(t1,t2);
    SRC(3,1)= F2(t1,t2,t3);
    SRC(3,0)= F1(t2,t3);
}

static void predict_4x4_hd_c( pixel *src )
{
    int lt= SRC(-1,-1);
    PREDICT_4x4_LOAD_LEFT
    PREDICT_4x4_LOAD_TOP
    SRC(0,3)= F1(l2,l3);
    SRC(1,3)= F2(l1,l2,l3);
    SRC(0,2)=SRC(2,3)= F1(l1,l2);
    SRC(1,2)=SRC(3,3)= F2(l0,l1,l2);
    SRC(0,1)=SRC(2,2)= F1(l0,l1);
    SRC(1,1)=SRC(3,2)= F2(lt,l0,l1);
    SRC(0,0)=SRC(2,1)= F1(lt,l0);
    SRC(1,0)=SRC(3,1)= F2(t0,lt,l0);
    SRC(2,0)= F2(t1,t0,lt);
    SRC(3,0)= F2(t2,t1,t0);
}

static void predict_4x4_vl_c( pixel *src )
{
    PREDICT_4x4_LOAD_TOP
    PREDICT_4x4_LOAD_TOP_RIGHT
    SRC(0,0)= F1(t0,t1);
    SRC(0,1)= F2(t0,t1,t2);
    SRC(1,0)=SRC(0,2)= F1(t1,t2);
    SRC(1,1)=SRC(0,3)= F2(t1,t2,t3);
    SRC(2,0)=SRC(1,2)= F1(t2,t3);
    SRC(2,1)=SRC(1,3)= F2(t2,t3,t4);
    SRC(3,0)=SRC(2,2)= F1(t3,t4);
    SRC(3,1)=SRC(2,3)= F2(t3,t4,t5);
    SRC(3,2)= F1(t4,t5);
    SRC(3,3)= F2(t4,t5,t6);
}

static void predict_4x4_hu_c( pixel *src )
{
    PREDICT_4x4_LOAD_LEFT
    SRC(0,0)= F1(l0,l1);
    SRC(1,0)= F2(l0,l1,l2);
    SRC(2,0)=SRC(0,1)= F1(l1,l2);
    SRC(3,0)=SRC(1,1)= F2(l1,l2,l3);
    SRC(2,1)=SRC(0,2)= F1(l2,l3);
    SRC(3,1)=SRC(1,2)= F2(l2,l3,l3);
    SRC(3,2)=SRC(1,3)=SRC(0,3)=
    SRC(2,2)=SRC(2,3)=SRC(3,3)= l3;
}

/****************************************************************************
 * 8x8 prediction for intra luma block
 ****************************************************************************/

#define PL(y) \
    edge[14-y] = F2(SRC(-1,y-1), SRC(-1,y), SRC(-1,y+1));
#define PT(x) \
    edge[16+x] = F2(SRC(x-1,-1), SRC(x,-1), SRC(x+1,-1));

static void predict_8x8_filter_c( pixel *src, pixel edge[36], int i_neighbor, int i_filters )
{
    /* edge[7..14] = l7..l0
     * edge[15] = lt
     * edge[16..31] = t0 .. t15
     * edge[32] = t15 */

    int have_lt = i_neighbor & MB_TOPLEFT;
    if( i_filters & MB_LEFT )
    {
        edge[15] = (SRC(0,-1) + 2*SRC(-1,-1) + SRC(-1,0) + 2) >> 2;
        edge[14] = ((have_lt ? SRC(-1,-1) : SRC(-1,0))
                 + 2*SRC(-1,0) + SRC(-1,1) + 2) >> 2;
        PL(1) PL(2) PL(3) PL(4) PL(5) PL(6)
        edge[6] =
        edge[7] = (SRC(-1,6) + 3*SRC(-1,7) + 2) >> 2;
    }

    if( i_filters & MB_TOP )
    {
        int have_tr = i_neighbor & MB_TOPRIGHT;
        edge[16] = ((have_lt ? SRC(-1,-1) : SRC(0,-1))
                 + 2*SRC(0,-1) + SRC(1,-1) + 2) >> 2;
        PT(1) PT(2) PT(3) PT(4) PT(5) PT(6)
        edge[23] = (SRC(6,-1) + 2*SRC(7,-1)
                 + (have_tr ? SRC(8,-1) : SRC(7,-1)) + 2) >> 2;

        if( i_filters & MB_TOPRIGHT )
        {
            if( have_tr )
            {
                PT(8) PT(9) PT(10) PT(11) PT(12) PT(13) PT(14)
                edge[31] =
                edge[32] = (SRC(14,-1) + 3*SRC(15,-1) + 2) >> 2;
            }
            else
            {
                MPIXEL_X4( edge+24 ) = PIXEL_SPLAT_X4( SRC(7,-1) );
                MPIXEL_X4( edge+28 ) = PIXEL_SPLAT_X4( SRC(7,-1) );
                edge[32] = SRC(7,-1);
            }
        }
    }
}

#undef PL
#undef PT

#define PL(y) \
    UNUSED int l##y = edge[14-y];
#define PT(x) \
    UNUSED int t##x = edge[16+x];
#define PREDICT_8x8_LOAD_TOPLEFT \
    int lt = edge[15];
#define PREDICT_8x8_LOAD_LEFT \
    PL(0) PL(1) PL(2) PL(3) PL(4) PL(5) PL(6) PL(7)
#define PREDICT_8x8_LOAD_TOP \
    PT(0) PT(1) PT(2) PT(3) PT(4) PT(5) PT(6) PT(7)
#define PREDICT_8x8_LOAD_TOPRIGHT \
    PT(8) PT(9) PT(10) PT(11) PT(12) PT(13) PT(14) PT(15)

#define PREDICT_8x8_DC(v) \
    for( int y = 0; y < 8; y++ ) { \
        MPIXEL_X4( src+0 ) = v; \
        MPIXEL_X4( src+4 ) = v; \
        src += FDEC_STRIDE; \
    }

static void predict_8x8_dc_128_c( pixel *src, pixel edge[36] )
{
    PREDICT_8x8_DC( PIXEL_SPLAT_X4( 1 << (BIT_DEPTH-1) ) );
}
static void predict_8x8_dc_left_c( pixel *src, pixel edge[36] )
{
    PREDICT_8x8_LOAD_LEFT
    pixel4 dc = PIXEL_SPLAT_X4( (l0+l1+l2+l3+l4+l5+l6+l7+4) >> 3 );
    PREDICT_8x8_DC( dc );
}
static void predict_8x8_dc_top_c( pixel *src, pixel edge[36] )
{
    PREDICT_8x8_LOAD_TOP
    pixel4 dc = PIXEL_SPLAT_X4( (t0+t1+t2+t3+t4+t5+t6+t7+4) >> 3 );
    PREDICT_8x8_DC( dc );
}
void x264_predict_8x8_dc_c( pixel *src, pixel edge[36] )
{
    PREDICT_8x8_LOAD_LEFT
    PREDICT_8x8_LOAD_TOP
    pixel4 dc = PIXEL_SPLAT_X4( (l0+l1+l2+l3+l4+l5+l6+l7+t0+t1+t2+t3+t4+t5+t6+t7+8) >> 4 );
    PREDICT_8x8_DC( dc );
}
void x264_predict_8x8_h_c( pixel *src, pixel edge[36] )
{
    PREDICT_8x8_LOAD_LEFT
#define ROW(y) MPIXEL_X4( src+y*FDEC_STRIDE+0 ) =\
               MPIXEL_X4( src+y*FDEC_STRIDE+4 ) = PIXEL_SPLAT_X4( l##y );
    ROW(0); ROW(1); ROW(2); ROW(3); ROW(4); ROW(5); ROW(6); ROW(7);
#undef ROW
}
void x264_predict_8x8_v_c( pixel *src, pixel edge[36] )
{
    pixel4 top[2] = { MPIXEL_X4( edge+16 ),
                      MPIXEL_X4( edge+20 ) };
    for( int y = 0; y < 8; y++ )
    {
        MPIXEL_X4( src+y*FDEC_STRIDE+0 ) = top[0];
        MPIXEL_X4( src+y*FDEC_STRIDE+4 ) = top[1];
    }
}
static void predict_8x8_ddl_c( pixel *src, pixel edge[36] )
{
    PREDICT_8x8_LOAD_TOP
    PREDICT_8x8_LOAD_TOPRIGHT
    SRC(0,0)= F2(t0,t1,t2);
    SRC(0,1)=SRC(1,0)= F2(t1,t2,t3);
    SRC(0,2)=SRC(1,1)=SRC(2,0)= F2(t2,t3,t4);
    SRC(0,3)=SRC(1,2)=SRC(2,1)=SRC(3,0)= F2(t3,t4,t5);
    SRC(0,4)=SRC(1,3)=SRC(2,2)=SRC(3,1)=SRC(4,0)= F2(t4,t5,t6);
    SRC(0,5)=SRC(1,4)=SRC(2,3)=SRC(3,2)=SRC(4,1)=SRC(5,0)= F2(t5,t6,t7);
    SRC(0,6)=SRC(1,5)=SRC(2,4)=SRC(3,3)=SRC(4,2)=SRC(5,1)=SRC(6,0)= F2(t6,t7,t8);
    SRC(0,7)=SRC(1,6)=SRC(2,5)=SRC(3,4)=SRC(4,3)=SRC(5,2)=SRC(6,1)=SRC(7,0)= F2(t7,t8,t9);
    SRC(1,7)=SRC(2,6)=SRC(3,5)=SRC(4,4)=SRC(5,3)=SRC(6,2)=SRC(7,1)= F2(t8,t9,t10);
    SRC(2,7)=SRC(3,6)=SRC(4,5)=SRC(5,4)=SRC(6,3)=SRC(7,2)= F2(t9,t10,t11);
    SRC(3,7)=SRC(4,6)=SRC(5,5)=SRC(6,4)=SRC(7,3)= F2(t10,t11,t12);
    SRC(4,7)=SRC(5,6)=SRC(6,5)=SRC(7,4)= F2(t11,t12,t13);
    SRC(5,7)=SRC(6,6)=SRC(7,5)= F2(t12,t13,t14);
    SRC(6,7)=SRC(7,6)= F2(t13,t14,t15);
    SRC(7,7)= F2(t14,t15,t15);
}
static void predict_8x8_ddr_c( pixel *src, pixel edge[36] )
{
    PREDICT_8x8_LOAD_TOP
    PREDICT_8x8_LOAD_LEFT
    PREDICT_8x8_LOAD_TOPLEFT
    SRC(0,7)= F2(l7,l6,l5);
    SRC(0,6)=SRC(1,7)= F2(l6,l5,l4);
    SRC(0,5)=SRC(1,6)=SRC(2,7)= F2(l5,l4,l3);
    SRC(0,4)=SRC(1,5)=SRC(2,6)=SRC(3,7)= F2(l4,l3,l2);
    SRC(0,3)=SRC(1,4)=SRC(2,5)=SRC(3,6)=SRC(4,7)= F2(l3,l2,l1);
    SRC(0,2)=SRC(1,3)=SRC(2,4)=SRC(3,5)=SRC(4,6)=SRC(5,7)= F2(l2,l1,l0);
    SRC(0,1)=SRC(1,2)=SRC(2,3)=SRC(3,4)=SRC(4,5)=SRC(5,6)=SRC(6,7)= F2(l1,l0,lt);
    SRC(0,0)=SRC(1,1)=SRC(2,2)=SRC(3,3)=SRC(4,4)=SRC(5,5)=SRC(6,6)=SRC(7,7)= F2(l0,lt,t0);
    SRC(1,0)=SRC(2,1)=SRC(3,2)=SRC(4,3)=SRC(5,4)=SRC(6,5)=SRC(7,6)= F2(lt,t0,t1);
    SRC(2,0)=SRC(3,1)=SRC(4,2)=SRC(5,3)=SRC(6,4)=SRC(7,5)= F2(t0,t1,t2);
    SRC(3,0)=SRC(4,1)=SRC(5,2)=SRC(6,3)=SRC(7,4)= F2(t1,t2,t3);
    SRC(4,0)=SRC(5,1)=SRC(6,2)=SRC(7,3)= F2(t2,t3,t4);
    SRC(5,0)=SRC(6,1)=SRC(7,2)= F2(t3,t4,t5);
    SRC(6,0)=SRC(7,1)= F2(t4,t5,t6);
    SRC(7,0)= F2(t5,t6,t7);

}
static void predict_8x8_vr_c( pixel *src, pixel edge[36] )
{
    PREDICT_8x8_LOAD_TOP
    PREDICT_8x8_LOAD_LEFT
    PREDICT_8x8_LOAD_TOPLEFT
    SRC(0,6)= F2(l5,l4,l3);
    SRC(0,7)= F2(l6,l5,l4);
    SRC(0,4)=SRC(1,6)= F2(l3,l2,l1);
    SRC(0,5)=SRC(1,7)= F2(l4,l3,l2);
    SRC(0,2)=SRC(1,4)=SRC(2,6)= F2(l1,l0,lt);
    SRC(0,3)=SRC(1,5)=SRC(2,7)= F2(l2,l1,l0);
    SRC(0,1)=SRC(1,3)=SRC(2,5)=SRC(3,7)= F2(l0,lt,t0);
    SRC(0,0)=SRC(1,2)=SRC(2,4)=SRC(3,6)= F1(lt,t0);
    SRC(1,1)=SRC(2,3)=SRC(3,5)=SRC(4,7)= F2(lt,t0,t1);
    SRC(1,0)=SRC(2,2)=SRC(3,4)=SRC(4,6)= F1(t0,t1);
    SRC(2,1)=SRC(3,3)=SRC(4,5)=SRC(5,7)= F2(t0,t1,t2);
    SRC(2,0)=SRC(3,2)=SRC(4,4)=SRC(5,6)= F1(t1,t2);
    SRC(3,1)=SRC(4,3)=SRC(5,5)=SRC(6,7)= F2(t1,t2,t3);
    SRC(3,0)=SRC(4,2)=SRC(5,4)=SRC(6,6)= F1(t2,t3);
    SRC(4,1)=SRC(5,3)=SRC(6,5)=SRC(7,7)= F2(t2,t3,t4);
    SRC(4,0)=SRC(5,2)=SRC(6,4)=SRC(7,6)= F1(t3,t4);
    SRC(5,1)=SRC(6,3)=SRC(7,5)= F2(t3,t4,t5);
    SRC(5,0)=SRC(6,2)=SRC(7,4)= F1(t4,t5);
    SRC(6,1)=SRC(7,3)= F2(t4,t5,t6);
    SRC(6,0)=SRC(7,2)= F1(t5,t6);
    SRC(7,1)= F2(t5,t6,t7);
    SRC(7,0)= F1(t6,t7);
}
static void predict_8x8_hd_c( pixel *src, pixel edge[36] )
{
    PREDICT_8x8_LOAD_TOP
    PREDICT_8x8_LOAD_LEFT
    PREDICT_8x8_LOAD_TOPLEFT
    int p1 = pack_pixel_1to2(F1(l6,l7), F2(l5,l6,l7));
    int p2 = pack_pixel_1to2(F1(l5,l6), F2(l4,l5,l6));
    int p3 = pack_pixel_1to2(F1(l4,l5), F2(l3,l4,l5));
    int p4 = pack_pixel_1to2(F1(l3,l4), F2(l2,l3,l4));
    int p5 = pack_pixel_1to2(F1(l2,l3), F2(l1,l2,l3));
    int p6 = pack_pixel_1to2(F1(l1,l2), F2(l0,l1,l2));
    int p7 = pack_pixel_1to2(F1(l0,l1), F2(lt,l0,l1));
    int p8 = pack_pixel_1to2(F1(lt,l0), F2(l0,lt,t0));
    int p9 = pack_pixel_1to2(F2(t1,t0,lt), F2(t2,t1,t0));
    int p10 = pack_pixel_1to2(F2(t3,t2,t1), F2(t4,t3,t2));
    int p11 = pack_pixel_1to2(F2(t5,t4,t3), F2(t6,t5,t4));
    SRC_X4(0,7)= pack_pixel_2to4(p1,p2);
    SRC_X4(0,6)= pack_pixel_2to4(p2,p3);
    SRC_X4(4,7)=SRC_X4(0,5)= pack_pixel_2to4(p3,p4);
    SRC_X4(4,6)=SRC_X4(0,4)= pack_pixel_2to4(p4,p5);
    SRC_X4(4,5)=SRC_X4(0,3)= pack_pixel_2to4(p5,p6);
    SRC_X4(4,4)=SRC_X4(0,2)= pack_pixel_2to4(p6,p7);
    SRC_X4(4,3)=SRC_X4(0,1)= pack_pixel_2to4(p7,p8);
    SRC_X4(4,2)=SRC_X4(0,0)= pack_pixel_2to4(p8,p9);
    SRC_X4(4,1)= pack_pixel_2to4(p9,p10);
    SRC_X4(4,0)= pack_pixel_2to4(p10,p11);
}
static void predict_8x8_vl_c( pixel *src, pixel edge[36] )
{
    PREDICT_8x8_LOAD_TOP
    PREDICT_8x8_LOAD_TOPRIGHT
    SRC(0,0)= F1(t0,t1);
    SRC(0,1)= F2(t0,t1,t2);
    SRC(0,2)=SRC(1,0)= F1(t1,t2);
    SRC(0,3)=SRC(1,1)= F2(t1,t2,t3);
    SRC(0,4)=SRC(1,2)=SRC(2,0)= F1(t2,t3);
    SRC(0,5)=SRC(1,3)=SRC(2,1)= F2(t2,t3,t4);
    SRC(0,6)=SRC(1,4)=SRC(2,2)=SRC(3,0)= F1(t3,t4);
    SRC(0,7)=SRC(1,5)=SRC(2,3)=SRC(3,1)= F2(t3,t4,t5);
    SRC(1,6)=SRC(2,4)=SRC(3,2)=SRC(4,0)= F1(t4,t5);
    SRC(1,7)=SRC(2,5)=SRC(3,3)=SRC(4,1)= F2(t4,t5,t6);
    SRC(2,6)=SRC(3,4)=SRC(4,2)=SRC(5,0)= F1(t5,t6);
    SRC(2,7)=SRC(3,5)=SRC(4,3)=SRC(5,1)= F2(t5,t6,t7);
    SRC(3,6)=SRC(4,4)=SRC(5,2)=SRC(6,0)= F1(t6,t7);
    SRC(3,7)=SRC(4,5)=SRC(5,3)=SRC(6,1)= F2(t6,t7,t8);
    SRC(4,6)=SRC(5,4)=SRC(6,2)=SRC(7,0)= F1(t7,t8);
    SRC(4,7)=SRC(5,5)=SRC(6,3)=SRC(7,1)= F2(t7,t8,t9);
    SRC(5,6)=SRC(6,4)=SRC(7,2)= F1(t8,t9);
    SRC(5,7)=SRC(6,5)=SRC(7,3)= F2(t8,t9,t10);
    SRC(6,6)=SRC(7,4)= F1(t9,t10);
    SRC(6,7)=SRC(7,5)= F2(t9,t10,t11);
    SRC(7,6)= F1(t10,t11);
    SRC(7,7)= F2(t10,t11,t12);
}
static void predict_8x8_hu_c( pixel *src, pixel edge[36] )
{
    PREDICT_8x8_LOAD_LEFT
    int p1 = pack_pixel_1to2(F1(l0,l1), F2(l0,l1,l2));
    int p2 = pack_pixel_1to2(F1(l1,l2), F2(l1,l2,l3));
    int p3 = pack_pixel_1to2(F1(l2,l3), F2(l2,l3,l4));
    int p4 = pack_pixel_1to2(F1(l3,l4), F2(l3,l4,l5));
    int p5 = pack_pixel_1to2(F1(l4,l5), F2(l4,l5,l6));
    int p6 = pack_pixel_1to2(F1(l5,l6), F2(l5,l6,l7));
    int p7 = pack_pixel_1to2(F1(l6,l7), F2(l6,l7,l7));
    int p8 = pack_pixel_1to2(l7,l7);
    SRC_X4(0,0)= pack_pixel_2to4(p1,p2);
    SRC_X4(0,1)= pack_pixel_2to4(p2,p3);
    SRC_X4(4,0)=SRC_X4(0,2)= pack_pixel_2to4(p3,p4);
    SRC_X4(4,1)=SRC_X4(0,3)= pack_pixel_2to4(p4,p5);
    SRC_X4(4,2)=SRC_X4(0,4)= pack_pixel_2to4(p5,p6);
    SRC_X4(4,3)=SRC_X4(0,5)= pack_pixel_2to4(p6,p7);
    SRC_X4(4,4)=SRC_X4(0,6)= pack_pixel_2to4(p7,p8);
    SRC_X4(4,5)=SRC_X4(4,6)= SRC_X4(0,7) = SRC_X4(4,7) = pack_pixel_2to4(p8,p8);
}

/****************************************************************************
 * Exported functions:
 ****************************************************************************/
void x264_predict_16x16_init( uint32_t cpu, x264_predict_t pf[7] )
{
    pf[I_PRED_16x16_V ]     = x264_predict_16x16_v_c;
    pf[I_PRED_16x16_H ]     = x264_predict_16x16_h_c;
    pf[I_PRED_16x16_DC]     = x264_predict_16x16_dc_c;
    pf[I_PRED_16x16_P ]     = x264_predict_16x16_p_c;
    pf[I_PRED_16x16_DC_LEFT]= predict_16x16_dc_left_c;
    pf[I_PRED_16x16_DC_TOP ]= predict_16x16_dc_top_c;
    pf[I_PRED_16x16_DC_128 ]= predict_16x16_dc_128_c;

#if HAVE_MMX
    x264_predict_16x16_init_mmx( cpu, pf );
#endif

#if HAVE_ALTIVEC
    if( cpu&X264_CPU_ALTIVEC )
        x264_predict_16x16_init_altivec( pf );
#endif

#if HAVE_ARMV6
    x264_predict_16x16_init_arm( cpu, pf );
#endif

#if HAVE_AARCH64
    x264_predict_16x16_init_aarch64( cpu, pf );
#endif

#if !HIGH_BIT_DEPTH
#if HAVE_MSA
    if( cpu&X264_CPU_MSA )
    {
        pf[I_PRED_16x16_V ]     = x264_intra_predict_vert_16x16_msa;
        pf[I_PRED_16x16_H ]     = x264_intra_predict_hor_16x16_msa;
        pf[I_PRED_16x16_DC]     = x264_intra_predict_dc_16x16_msa;
        pf[I_PRED_16x16_P ]     = x264_intra_predict_plane_16x16_msa;
        pf[I_PRED_16x16_DC_LEFT]= x264_intra_predict_dc_left_16x16_msa;
        pf[I_PRED_16x16_DC_TOP ]= x264_intra_predict_dc_top_16x16_msa;
        pf[I_PRED_16x16_DC_128 ]= x264_intra_predict_dc_128_16x16_msa;
    }
#endif
#endif
}

void x264_predict_8x8c_init( uint32_t cpu, x264_predict_t pf[7] )
{
    pf[I_PRED_CHROMA_V ]     = x264_predict_8x8c_v_c;
    pf[I_PRED_CHROMA_H ]     = x264_predict_8x8c_h_c;
    pf[I_PRED_CHROMA_DC]     = x264_predict_8x8c_dc_c;
    pf[I_PRED_CHROMA_P ]     = x264_predict_8x8c_p_c;
    pf[I_PRED_CHROMA_DC_LEFT]= predict_8x8c_dc_left_c;
    pf[I_PRED_CHROMA_DC_TOP ]= predict_8x8c_dc_top_c;
    pf[I_PRED_CHROMA_DC_128 ]= predict_8x8c_dc_128_c;

#if HAVE_MMX
    x264_predict_8x8c_init_mmx( cpu, pf );
#endif

#if HAVE_ALTIVEC
    if( cpu&X264_CPU_ALTIVEC )
        x264_predict_8x8c_init_altivec( pf );
#endif

#if HAVE_ARMV6
    x264_predict_8x8c_init_arm( cpu, pf );
#endif

#if HAVE_AARCH64
    x264_predict_8x8c_init_aarch64( cpu, pf );
#endif

#if !HIGH_BIT_DEPTH
#if HAVE_MSA
    if( cpu&X264_CPU_MSA )
    {
        pf[I_PRED_CHROMA_P ]     = x264_intra_predict_plane_8x8_msa;
    }
#endif
#endif
}

void x264_predict_8x16c_init( uint32_t cpu, x264_predict_t pf[7] )
{
    pf[I_PRED_CHROMA_V ]     = x264_predict_8x16c_v_c;
    pf[I_PRED_CHROMA_H ]     = x264_predict_8x16c_h_c;
    pf[I_PRED_CHROMA_DC]     = x264_predict_8x16c_dc_c;
    pf[I_PRED_CHROMA_P ]     = x264_predict_8x16c_p_c;
    pf[I_PRED_CHROMA_DC_LEFT]= predict_8x16c_dc_left_c;
    pf[I_PRED_CHROMA_DC_TOP ]= predict_8x16c_dc_top_c;
    pf[I_PRED_CHROMA_DC_128 ]= predict_8x16c_dc_128_c;

#if HAVE_MMX
    x264_predict_8x16c_init_mmx( cpu, pf );
#endif

#if HAVE_ARMV6
    x264_predict_8x16c_init_arm( cpu, pf );
#endif

#if HAVE_AARCH64
    x264_predict_8x16c_init_aarch64( cpu, pf );
#endif
}

void x264_predict_8x8_init( uint32_t cpu, x264_predict8x8_t pf[12], x264_predict_8x8_filter_t *predict_filter )
{
    pf[I_PRED_8x8_V]      = x264_predict_8x8_v_c;
    pf[I_PRED_8x8_H]      = x264_predict_8x8_h_c;
    pf[I_PRED_8x8_DC]     = x264_predict_8x8_dc_c;
    pf[I_PRED_8x8_DDL]    = predict_8x8_ddl_c;
    pf[I_PRED_8x8_DDR]    = predict_8x8_ddr_c;
    pf[I_PRED_8x8_VR]     = predict_8x8_vr_c;
    pf[I_PRED_8x8_HD]     = predict_8x8_hd_c;
    pf[I_PRED_8x8_VL]     = predict_8x8_vl_c;
    pf[I_PRED_8x8_HU]     = predict_8x8_hu_c;
    pf[I_PRED_8x8_DC_LEFT]= predict_8x8_dc_left_c;
    pf[I_PRED_8x8_DC_TOP] = predict_8x8_dc_top_c;
    pf[I_PRED_8x8_DC_128] = predict_8x8_dc_128_c;
    *predict_filter       = predict_8x8_filter_c;

#if HAVE_MMX
    x264_predict_8x8_init_mmx( cpu, pf, predict_filter );
#endif

#if HAVE_ARMV6
    x264_predict_8x8_init_arm( cpu, pf, predict_filter );
#endif

#if HAVE_AARCH64
    x264_predict_8x8_init_aarch64( cpu, pf, predict_filter );
#endif

#if !HIGH_BIT_DEPTH
#if HAVE_MSA
    if( cpu&X264_CPU_MSA )
    {
        pf[I_PRED_8x8_DDL]    = x264_intra_predict_ddl_8x8_msa;
    }
#endif
#endif
}

void x264_predict_4x4_init( uint32_t cpu, x264_predict_t pf[12] )
{
    pf[I_PRED_4x4_V]      = x264_predict_4x4_v_c;
    pf[I_PRED_4x4_H]      = x264_predict_4x4_h_c;
    pf[I_PRED_4x4_DC]     = x264_predict_4x4_dc_c;
    pf[I_PRED_4x4_DDL]    = predict_4x4_ddl_c;
    pf[I_PRED_4x4_DDR]    = predict_4x4_ddr_c;
    pf[I_PRED_4x4_VR]     = predict_4x4_vr_c;
    pf[I_PRED_4x4_HD]     = predict_4x4_hd_c;
    pf[I_PRED_4x4_VL]     = predict_4x4_vl_c;
    pf[I_PRED_4x4_HU]     = predict_4x4_hu_c;
    pf[I_PRED_4x4_DC_LEFT]= predict_4x4_dc_left_c;
    pf[I_PRED_4x4_DC_TOP] = predict_4x4_dc_top_c;
    pf[I_PRED_4x4_DC_128] = predict_4x4_dc_128_c;

#if HAVE_MMX
    x264_predict_4x4_init_mmx( cpu, pf );
#endif

#if HAVE_ARMV6
    x264_predict_4x4_init_arm( cpu, pf );
#endif

#if HAVE_AARCH64
    x264_predict_4x4_init_aarch64( cpu, pf );
#endif
}

