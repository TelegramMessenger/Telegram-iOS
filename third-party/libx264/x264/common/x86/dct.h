/*****************************************************************************
 * dct.h: x86 transform and zigzag
 *****************************************************************************
 * Copyright (C) 2003-2022 x264 project
 *
 * Authors: Loren Merritt <lorenm@u.washington.edu>
 *          Laurent Aimar <fenrir@via.ecp.fr>
 *          Fiona Glaser <fiona@x264.com>
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

#ifndef X264_X86_DCT_H
#define X264_X86_DCT_H

#define x264_sub4x4_dct_mmx x264_template(sub4x4_dct_mmx)
void x264_sub4x4_dct_mmx    ( dctcoef dct    [16], pixel   *pix1, pixel   *pix2 );
#define x264_sub8x8_dct_mmx x264_template(sub8x8_dct_mmx)
void x264_sub8x8_dct_mmx    ( dctcoef dct[ 4][16], pixel   *pix1, pixel   *pix2 );
#define x264_sub16x16_dct_mmx x264_template(sub16x16_dct_mmx)
void x264_sub16x16_dct_mmx  ( dctcoef dct[16][16], pixel   *pix1, pixel   *pix2 );
#define x264_sub8x8_dct_sse2 x264_template(sub8x8_dct_sse2)
void x264_sub8x8_dct_sse2   ( int16_t dct[ 4][16], uint8_t *pix1, uint8_t *pix2 );
#define x264_sub16x16_dct_sse2 x264_template(sub16x16_dct_sse2)
void x264_sub16x16_dct_sse2 ( int16_t dct[16][16], uint8_t *pix1, uint8_t *pix2 );
#define x264_sub4x4_dct_ssse3 x264_template(sub4x4_dct_ssse3)
void x264_sub4x4_dct_ssse3  ( int16_t dct    [16], uint8_t *pix1, uint8_t *pix2 );
#define x264_sub4x4_dct_avx512 x264_template(sub4x4_dct_avx512)
void x264_sub4x4_dct_avx512 ( int16_t dct    [16], uint8_t *pix1, uint8_t *pix2 );
#define x264_sub8x8_dct_ssse3 x264_template(sub8x8_dct_ssse3)
void x264_sub8x8_dct_ssse3  ( int16_t dct[ 4][16], uint8_t *pix1, uint8_t *pix2 );
#define x264_sub16x16_dct_ssse3 x264_template(sub16x16_dct_ssse3)
void x264_sub16x16_dct_ssse3( int16_t dct[16][16], uint8_t *pix1, uint8_t *pix2 );
#define x264_sub8x8_dct_avx x264_template(sub8x8_dct_avx)
void x264_sub8x8_dct_avx    ( int16_t dct[ 4][16], uint8_t *pix1, uint8_t *pix2 );
#define x264_sub16x16_dct_avx x264_template(sub16x16_dct_avx)
void x264_sub16x16_dct_avx  ( int16_t dct[16][16], uint8_t *pix1, uint8_t *pix2 );
#define x264_sub8x8_dct_xop x264_template(sub8x8_dct_xop)
void x264_sub8x8_dct_xop    ( int16_t dct[ 4][16], uint8_t *pix1, uint8_t *pix2 );
#define x264_sub16x16_dct_xop x264_template(sub16x16_dct_xop)
void x264_sub16x16_dct_xop  ( int16_t dct[16][16], uint8_t *pix1, uint8_t *pix2 );
#define x264_sub8x8_dct_avx2 x264_template(sub8x8_dct_avx2)
void x264_sub8x8_dct_avx2   ( int16_t dct[ 4][16], uint8_t *pix1, uint8_t *pix2 );
#define x264_sub8x8_dct_avx512 x264_template(sub8x8_dct_avx512)
void x264_sub8x8_dct_avx512 ( int16_t dct[ 4][16], uint8_t *pix1, uint8_t *pix2 );
#define x264_sub16x16_dct_avx2 x264_template(sub16x16_dct_avx2)
void x264_sub16x16_dct_avx2 ( int16_t dct[16][16], uint8_t *pix1, uint8_t *pix2 );
#define x264_sub16x16_dct_avx512 x264_template(sub16x16_dct_avx512)
void x264_sub16x16_dct_avx512( int16_t dct[16][16], uint8_t *pix1, uint8_t *pix2 );
#define x264_sub8x8_dct_dc_mmx2 x264_template(sub8x8_dct_dc_mmx2)
void x264_sub8x8_dct_dc_mmx2   ( int16_t dct [ 4], uint8_t *pix1, uint8_t *pix2 );
#define x264_sub8x8_dct_dc_sse2 x264_template(sub8x8_dct_dc_sse2)
void x264_sub8x8_dct_dc_sse2   ( dctcoef dct [ 4], pixel   *pix1, pixel   *pix2 );
#define x264_sub8x8_dct_dc_avx512 x264_template(sub8x8_dct_dc_avx512)
void x264_sub8x8_dct_dc_avx512 ( int16_t dct [ 4], uint8_t *pix1, uint8_t *pix2 );
#define x264_sub8x16_dct_dc_sse2 x264_template(sub8x16_dct_dc_sse2)
void x264_sub8x16_dct_dc_sse2  ( dctcoef dct [ 8], pixel   *pix1, pixel   *pix2 );
#define x264_sub8x16_dct_dc_ssse3 x264_template(sub8x16_dct_dc_ssse3)
void x264_sub8x16_dct_dc_ssse3 ( int16_t dct [ 8], uint8_t *pix1, uint8_t *pix2 );
#define x264_sub8x16_dct_dc_avx x264_template(sub8x16_dct_dc_avx)
void x264_sub8x16_dct_dc_avx   ( dctcoef dct [ 8], pixel   *pix1, pixel   *pix2 );
#define x264_sub8x16_dct_dc_avx512 x264_template(sub8x16_dct_dc_avx512)
void x264_sub8x16_dct_dc_avx512( int16_t dct [ 8], uint8_t *pix1, uint8_t *pix2 );

#define x264_add4x4_idct_mmx x264_template(add4x4_idct_mmx)
void x264_add4x4_idct_mmx       ( uint8_t *p_dst, int16_t dct    [16] );
#define x264_add4x4_idct_sse2 x264_template(add4x4_idct_sse2)
void x264_add4x4_idct_sse2     ( uint16_t *p_dst, int32_t dct    [16] );
#define x264_add4x4_idct_sse4 x264_template(add4x4_idct_sse4)
void x264_add4x4_idct_sse4      ( uint8_t *p_dst, int16_t dct    [16] );
#define x264_add4x4_idct_avx x264_template(add4x4_idct_avx)
void x264_add4x4_idct_avx       ( pixel   *p_dst, dctcoef dct    [16] );
#define x264_add8x8_idct_mmx x264_template(add8x8_idct_mmx)
void x264_add8x8_idct_mmx       ( uint8_t *p_dst, int16_t dct[ 4][16] );
#define x264_add8x8_idct_dc_mmx2 x264_template(add8x8_idct_dc_mmx2)
void x264_add8x8_idct_dc_mmx2   ( uint8_t *p_dst, int16_t dct    [ 4] );
#define x264_add16x16_idct_mmx x264_template(add16x16_idct_mmx)
void x264_add16x16_idct_mmx     ( uint8_t *p_dst, int16_t dct[16][16] );
#define x264_add16x16_idct_dc_mmx2 x264_template(add16x16_idct_dc_mmx2)
void x264_add16x16_idct_dc_mmx2 ( uint8_t *p_dst, int16_t dct    [16] );
#define x264_add8x8_idct_sse2 x264_template(add8x8_idct_sse2)
void x264_add8x8_idct_sse2      ( pixel   *p_dst, dctcoef dct[ 4][16] );
#define x264_add8x8_idct_avx x264_template(add8x8_idct_avx)
void x264_add8x8_idct_avx       ( pixel   *p_dst, dctcoef dct[ 4][16] );
#define x264_add8x8_idct_avx2 x264_template(add8x8_idct_avx2)
void x264_add8x8_idct_avx2      ( pixel   *p_dst, dctcoef dct[ 4][16] );
#define x264_add8x8_idct_avx512 x264_template(add8x8_idct_avx512)
void x264_add8x8_idct_avx512    ( uint8_t *p_dst, int16_t dct[ 4][16] );
#define x264_add16x16_idct_sse2 x264_template(add16x16_idct_sse2)
void x264_add16x16_idct_sse2    ( pixel   *p_dst, dctcoef dct[16][16] );
#define x264_add16x16_idct_avx x264_template(add16x16_idct_avx)
void x264_add16x16_idct_avx     ( pixel   *p_dst, dctcoef dct[16][16] );
#define x264_add16x16_idct_avx2 x264_template(add16x16_idct_avx2)
void x264_add16x16_idct_avx2    ( pixel   *p_dst, dctcoef dct[16][16] );
#define x264_add8x8_idct_dc_sse2 x264_template(add8x8_idct_dc_sse2)
void x264_add8x8_idct_dc_sse2   ( pixel   *p_dst, dctcoef dct    [ 4] );
#define x264_add16x16_idct_dc_sse2 x264_template(add16x16_idct_dc_sse2)
void x264_add16x16_idct_dc_sse2 ( pixel   *p_dst, dctcoef dct    [16] );
#define x264_add8x8_idct_dc_ssse3 x264_template(add8x8_idct_dc_ssse3)
void x264_add8x8_idct_dc_ssse3  ( uint8_t *p_dst, int16_t dct    [ 4] );
#define x264_add16x16_idct_dc_ssse3 x264_template(add16x16_idct_dc_ssse3)
void x264_add16x16_idct_dc_ssse3( uint8_t *p_dst, int16_t dct    [16] );
#define x264_add8x8_idct_dc_avx x264_template(add8x8_idct_dc_avx)
void x264_add8x8_idct_dc_avx    ( pixel   *p_dst, dctcoef dct    [ 4] );
#define x264_add16x16_idct_dc_avx x264_template(add16x16_idct_dc_avx)
void x264_add16x16_idct_dc_avx  ( pixel   *p_dst, dctcoef dct    [16] );
#define x264_add16x16_idct_dc_avx2 x264_template(add16x16_idct_dc_avx2)
void x264_add16x16_idct_dc_avx2 ( uint8_t *p_dst, int16_t dct    [16] );

#define x264_dct4x4dc_mmx2 x264_template(dct4x4dc_mmx2)
void x264_dct4x4dc_mmx2      ( int16_t d[16] );
#define x264_dct4x4dc_sse2 x264_template(dct4x4dc_sse2)
void x264_dct4x4dc_sse2      ( int32_t d[16] );
#define x264_dct4x4dc_avx x264_template(dct4x4dc_avx)
void x264_dct4x4dc_avx       ( int32_t d[16] );
#define x264_idct4x4dc_mmx x264_template(idct4x4dc_mmx)
void x264_idct4x4dc_mmx      ( int16_t d[16] );
#define x264_idct4x4dc_sse2 x264_template(idct4x4dc_sse2)
void x264_idct4x4dc_sse2     ( int32_t d[16] );
#define x264_idct4x4dc_avx x264_template(idct4x4dc_avx)
void x264_idct4x4dc_avx      ( int32_t d[16] );

#define x264_dct2x4dc_mmx2 x264_template(dct2x4dc_mmx2)
void x264_dct2x4dc_mmx2( dctcoef dct[8], dctcoef dct4x4[8][16] );
#define x264_dct2x4dc_sse2 x264_template(dct2x4dc_sse2)
void x264_dct2x4dc_sse2( dctcoef dct[8], dctcoef dct4x4[8][16] );
#define x264_dct2x4dc_avx x264_template(dct2x4dc_avx)
void x264_dct2x4dc_avx ( dctcoef dct[8], dctcoef dct4x4[8][16] );

#define x264_sub8x8_dct8_mmx x264_template(sub8x8_dct8_mmx)
void x264_sub8x8_dct8_mmx    ( int16_t dct   [64], uint8_t *pix1, uint8_t *pix2 );
#define x264_sub16x16_dct8_mmx x264_template(sub16x16_dct8_mmx)
void x264_sub16x16_dct8_mmx  ( int16_t dct[4][64], uint8_t *pix1, uint8_t *pix2 );
#define x264_sub8x8_dct8_sse2 x264_template(sub8x8_dct8_sse2)
void x264_sub8x8_dct8_sse2   ( dctcoef dct   [64], pixel *pix1, pixel *pix2 );
#define x264_sub16x16_dct8_sse2 x264_template(sub16x16_dct8_sse2)
void x264_sub16x16_dct8_sse2 ( dctcoef dct[4][64], pixel *pix1, pixel *pix2 );
#define x264_sub8x8_dct8_ssse3 x264_template(sub8x8_dct8_ssse3)
void x264_sub8x8_dct8_ssse3  ( int16_t dct   [64], uint8_t *pix1, uint8_t *pix2 );
#define x264_sub16x16_dct8_ssse3 x264_template(sub16x16_dct8_ssse3)
void x264_sub16x16_dct8_ssse3( int16_t dct[4][64], uint8_t *pix1, uint8_t *pix2 );
#define x264_sub8x8_dct8_sse4 x264_template(sub8x8_dct8_sse4)
void x264_sub8x8_dct8_sse4   ( int32_t dct   [64], uint16_t *pix1, uint16_t *pix2 );
#define x264_sub16x16_dct8_sse4 x264_template(sub16x16_dct8_sse4)
void x264_sub16x16_dct8_sse4 ( int32_t dct[4][64], uint16_t *pix1, uint16_t *pix2 );
#define x264_sub8x8_dct8_avx x264_template(sub8x8_dct8_avx)
void x264_sub8x8_dct8_avx    ( dctcoef dct   [64], pixel *pix1, pixel *pix2 );
#define x264_sub16x16_dct8_avx x264_template(sub16x16_dct8_avx)
void x264_sub16x16_dct8_avx  ( dctcoef dct[4][64], pixel *pix1, pixel *pix2 );
#define x264_sub16x16_dct8_avx2 x264_template(sub16x16_dct8_avx2)
void x264_sub16x16_dct8_avx2 ( dctcoef dct[4][64], pixel *pix1, pixel *pix2 );


#define x264_add8x8_idct8_mmx x264_template(add8x8_idct8_mmx)
void x264_add8x8_idct8_mmx   ( uint8_t *dst, int16_t dct   [64] );
#define x264_add16x16_idct8_mmx x264_template(add16x16_idct8_mmx)
void x264_add16x16_idct8_mmx ( uint8_t *dst, int16_t dct[4][64] );
#define x264_add8x8_idct8_sse2 x264_template(add8x8_idct8_sse2)
void x264_add8x8_idct8_sse2  ( pixel *dst, dctcoef dct   [64] );
#define x264_add16x16_idct8_sse2 x264_template(add16x16_idct8_sse2)
void x264_add16x16_idct8_sse2( pixel *dst, dctcoef dct[4][64] );
#define x264_add8x8_idct8_avx x264_template(add8x8_idct8_avx)
void x264_add8x8_idct8_avx   ( pixel *dst, dctcoef dct   [64] );
#define x264_add16x16_idct8_avx x264_template(add16x16_idct8_avx)
void x264_add16x16_idct8_avx ( pixel *dst, dctcoef dct[4][64] );

#define x264_zigzag_scan_8x8_frame_mmx2 x264_template(zigzag_scan_8x8_frame_mmx2)
void x264_zigzag_scan_8x8_frame_mmx2  ( int16_t level[64], int16_t dct[64] );
#define x264_zigzag_scan_8x8_frame_sse2 x264_template(zigzag_scan_8x8_frame_sse2)
void x264_zigzag_scan_8x8_frame_sse2  ( dctcoef level[64], dctcoef dct[64] );
#define x264_zigzag_scan_8x8_frame_ssse3 x264_template(zigzag_scan_8x8_frame_ssse3)
void x264_zigzag_scan_8x8_frame_ssse3 ( int16_t level[64], int16_t dct[64] );
#define x264_zigzag_scan_8x8_frame_avx x264_template(zigzag_scan_8x8_frame_avx)
void x264_zigzag_scan_8x8_frame_avx   ( dctcoef level[64], dctcoef dct[64] );
#define x264_zigzag_scan_8x8_frame_xop x264_template(zigzag_scan_8x8_frame_xop)
void x264_zigzag_scan_8x8_frame_xop   ( int16_t level[64], int16_t dct[64] );
#define x264_zigzag_scan_8x8_frame_avx512 x264_template(zigzag_scan_8x8_frame_avx512)
void x264_zigzag_scan_8x8_frame_avx512( dctcoef level[64], dctcoef dct[64] );
#define x264_zigzag_scan_4x4_frame_mmx x264_template(zigzag_scan_4x4_frame_mmx)
void x264_zigzag_scan_4x4_frame_mmx   ( int16_t level[16], int16_t dct[16] );
#define x264_zigzag_scan_4x4_frame_sse2 x264_template(zigzag_scan_4x4_frame_sse2)
void x264_zigzag_scan_4x4_frame_sse2  ( int32_t level[16], int32_t dct[16] );
#define x264_zigzag_scan_4x4_frame_ssse3 x264_template(zigzag_scan_4x4_frame_ssse3)
void x264_zigzag_scan_4x4_frame_ssse3 ( int16_t level[16], int16_t dct[16] );
#define x264_zigzag_scan_4x4_frame_avx x264_template(zigzag_scan_4x4_frame_avx)
void x264_zigzag_scan_4x4_frame_avx   ( dctcoef level[16], dctcoef dct[16] );
#define x264_zigzag_scan_4x4_frame_xop x264_template(zigzag_scan_4x4_frame_xop)
void x264_zigzag_scan_4x4_frame_xop   ( dctcoef level[16], dctcoef dct[16] );
#define x264_zigzag_scan_4x4_frame_avx512 x264_template(zigzag_scan_4x4_frame_avx512)
void x264_zigzag_scan_4x4_frame_avx512( dctcoef level[16], dctcoef dct[16] );
#define x264_zigzag_scan_4x4_field_sse x264_template(zigzag_scan_4x4_field_sse)
void x264_zigzag_scan_4x4_field_sse   ( int16_t level[16], int16_t dct[16] );
#define x264_zigzag_scan_4x4_field_sse2 x264_template(zigzag_scan_4x4_field_sse2)
void x264_zigzag_scan_4x4_field_sse2  ( int32_t level[16], int32_t dct[16] );
#define x264_zigzag_scan_4x4_field_avx512 x264_template(zigzag_scan_4x4_field_avx512)
void x264_zigzag_scan_4x4_field_avx512( dctcoef level[16], dctcoef dct[16] );
#define x264_zigzag_scan_8x8_field_mmx2 x264_template(zigzag_scan_8x8_field_mmx2)
void x264_zigzag_scan_8x8_field_mmx2  ( int16_t level[64], int16_t dct[64] );
#define x264_zigzag_scan_8x8_field_sse4 x264_template(zigzag_scan_8x8_field_sse4)
void x264_zigzag_scan_8x8_field_sse4  ( int32_t level[64], int32_t dct[64] );
#define x264_zigzag_scan_8x8_field_avx x264_template(zigzag_scan_8x8_field_avx)
void x264_zigzag_scan_8x8_field_avx   ( int32_t level[64], int32_t dct[64] );
#define x264_zigzag_scan_8x8_field_xop x264_template(zigzag_scan_8x8_field_xop)
void x264_zigzag_scan_8x8_field_xop   ( int16_t level[64], int16_t dct[64] );
#define x264_zigzag_scan_8x8_field_avx512 x264_template(zigzag_scan_8x8_field_avx512)
void x264_zigzag_scan_8x8_field_avx512( dctcoef level[64], dctcoef dct[64] );
#define x264_zigzag_sub_4x4_frame_avx x264_template(zigzag_sub_4x4_frame_avx)
int  x264_zigzag_sub_4x4_frame_avx    ( int16_t level[16], const uint8_t *src, uint8_t *dst );
#define x264_zigzag_sub_4x4_frame_ssse3 x264_template(zigzag_sub_4x4_frame_ssse3)
int  x264_zigzag_sub_4x4_frame_ssse3  ( int16_t level[16], const uint8_t *src, uint8_t *dst );
#define x264_zigzag_sub_4x4ac_frame_avx x264_template(zigzag_sub_4x4ac_frame_avx)
int  x264_zigzag_sub_4x4ac_frame_avx  ( int16_t level[16], const uint8_t *src, uint8_t *dst, int16_t *dc );
#define x264_zigzag_sub_4x4ac_frame_ssse3 x264_template(zigzag_sub_4x4ac_frame_ssse3)
int  x264_zigzag_sub_4x4ac_frame_ssse3( int16_t level[16], const uint8_t *src, uint8_t *dst, int16_t *dc );
#define x264_zigzag_sub_4x4_field_avx x264_template(zigzag_sub_4x4_field_avx)
int  x264_zigzag_sub_4x4_field_avx    ( int16_t level[16], const uint8_t *src, uint8_t *dst );
#define x264_zigzag_sub_4x4_field_ssse3 x264_template(zigzag_sub_4x4_field_ssse3)
int  x264_zigzag_sub_4x4_field_ssse3  ( int16_t level[16], const uint8_t *src, uint8_t *dst );
#define x264_zigzag_sub_4x4ac_field_avx x264_template(zigzag_sub_4x4ac_field_avx)
int  x264_zigzag_sub_4x4ac_field_avx  ( int16_t level[16], const uint8_t *src, uint8_t *dst, int16_t *dc );
#define x264_zigzag_sub_4x4ac_field_ssse3 x264_template(zigzag_sub_4x4ac_field_ssse3)
int  x264_zigzag_sub_4x4ac_field_ssse3( int16_t level[16], const uint8_t *src, uint8_t *dst, int16_t *dc );
#define x264_zigzag_interleave_8x8_cavlc_mmx x264_template(zigzag_interleave_8x8_cavlc_mmx)
void x264_zigzag_interleave_8x8_cavlc_mmx   ( int16_t *dst, int16_t *src, uint8_t *nnz );
#define x264_zigzag_interleave_8x8_cavlc_sse2 x264_template(zigzag_interleave_8x8_cavlc_sse2)
void x264_zigzag_interleave_8x8_cavlc_sse2  ( dctcoef *dst, dctcoef *src, uint8_t *nnz );
#define x264_zigzag_interleave_8x8_cavlc_avx x264_template(zigzag_interleave_8x8_cavlc_avx)
void x264_zigzag_interleave_8x8_cavlc_avx   ( dctcoef *dst, dctcoef *src, uint8_t *nnz );
#define x264_zigzag_interleave_8x8_cavlc_avx2 x264_template(zigzag_interleave_8x8_cavlc_avx2)
void x264_zigzag_interleave_8x8_cavlc_avx2  ( int16_t *dst, int16_t *src, uint8_t *nnz );
#define x264_zigzag_interleave_8x8_cavlc_avx512 x264_template(zigzag_interleave_8x8_cavlc_avx512)
void x264_zigzag_interleave_8x8_cavlc_avx512( dctcoef *dst, dctcoef *src, uint8_t *nnz );

#endif
