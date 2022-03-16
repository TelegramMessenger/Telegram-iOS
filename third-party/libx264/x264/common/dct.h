/*****************************************************************************
 * dct.h: transform and zigzag
 *****************************************************************************
 * Copyright (C) 2004-2022 x264 project
 *
 * Authors: Loren Merritt <lorenm@u.washington.edu>
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

#ifndef X264_DCT_H
#define X264_DCT_H

typedef struct
{
    // pix1  stride = FENC_STRIDE
    // pix2  stride = FDEC_STRIDE
    // p_dst stride = FDEC_STRIDE
    void (*sub4x4_dct) ( dctcoef dct[16], pixel *pix1, pixel *pix2 );
    void (*add4x4_idct)( pixel *p_dst, dctcoef dct[16] );

    void (*sub8x8_dct)    ( dctcoef dct[4][16], pixel *pix1, pixel *pix2 );
    void (*sub8x8_dct_dc) ( dctcoef dct[4], pixel *pix1, pixel *pix2 );
    void (*add8x8_idct)   ( pixel *p_dst, dctcoef dct[4][16] );
    void (*add8x8_idct_dc)( pixel *p_dst, dctcoef dct[4] );

    void (*sub8x16_dct_dc)( dctcoef dct[8], pixel *pix1, pixel *pix2 );

    void (*sub16x16_dct)    ( dctcoef dct[16][16], pixel *pix1, pixel *pix2 );
    void (*add16x16_idct)   ( pixel *p_dst, dctcoef dct[16][16] );
    void (*add16x16_idct_dc)( pixel *p_dst, dctcoef dct[16] );

    void (*sub8x8_dct8) ( dctcoef dct[64], pixel *pix1, pixel *pix2 );
    void (*add8x8_idct8)( pixel *p_dst, dctcoef dct[64] );

    void (*sub16x16_dct8) ( dctcoef dct[4][64], pixel *pix1, pixel *pix2 );
    void (*add16x16_idct8)( pixel *p_dst, dctcoef dct[4][64] );

    void (*dct4x4dc) ( dctcoef d[16] );
    void (*idct4x4dc)( dctcoef d[16] );

    void (*dct2x4dc)( dctcoef dct[8], dctcoef dct4x4[8][16] );

} x264_dct_function_t;

typedef struct
{
    void (*scan_8x8)( dctcoef level[64], dctcoef dct[64] );
    void (*scan_4x4)( dctcoef level[16], dctcoef dct[16] );
    int  (*sub_8x8)  ( dctcoef level[64], const pixel *p_src, pixel *p_dst );
    int  (*sub_4x4)  ( dctcoef level[16], const pixel *p_src, pixel *p_dst );
    int  (*sub_4x4ac)( dctcoef level[16], const pixel *p_src, pixel *p_dst, dctcoef *dc );
    void (*interleave_8x8_cavlc)( dctcoef *dst, dctcoef *src, uint8_t *nnz );

} x264_zigzag_function_t;

#define x264_dct_init x264_template(dct_init)
void x264_dct_init( uint32_t cpu, x264_dct_function_t *dctf );
#define x264_zigzag_init x264_template(zigzag_init)
void x264_zigzag_init( uint32_t cpu, x264_zigzag_function_t *pf_progressive, x264_zigzag_function_t *pf_interlaced );

#endif
