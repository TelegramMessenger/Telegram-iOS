/*****************************************************************************
 * dct.h: ppc transform and zigzag
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

#ifndef X264_PPC_DCT_H
#define X264_PPC_DCT_H

#define x264_sub4x4_dct_altivec x264_template(sub4x4_dct_altivec)
void x264_sub4x4_dct_altivec( int16_t dct[16], uint8_t *pix1, uint8_t *pix2 );
#define x264_sub8x8_dct_altivec x264_template(sub8x8_dct_altivec)
void x264_sub8x8_dct_altivec( int16_t dct[4][16], uint8_t *pix1, uint8_t *pix2 );
#define x264_sub16x16_dct_altivec x264_template(sub16x16_dct_altivec)
void x264_sub16x16_dct_altivec( int16_t dct[16][16], uint8_t *pix1, uint8_t *pix2 );

#define x264_add8x8_idct_dc_altivec x264_template(add8x8_idct_dc_altivec)
void x264_add8x8_idct_dc_altivec( uint8_t *p_dst, int16_t dct[4] );
#define x264_add16x16_idct_dc_altivec x264_template(add16x16_idct_dc_altivec)
void x264_add16x16_idct_dc_altivec( uint8_t *p_dst, int16_t dct[16] );

#define x264_add4x4_idct_altivec x264_template(add4x4_idct_altivec)
void x264_add4x4_idct_altivec( uint8_t *p_dst, int16_t dct[16] );
#define x264_add8x8_idct_altivec x264_template(add8x8_idct_altivec)
void x264_add8x8_idct_altivec( uint8_t *p_dst, int16_t dct[4][16] );
#define x264_add16x16_idct_altivec x264_template(add16x16_idct_altivec)
void x264_add16x16_idct_altivec( uint8_t *p_dst, int16_t dct[16][16] );

#define x264_sub8x8_dct_dc_altivec x264_template(sub8x8_dct_dc_altivec)
void x264_sub8x8_dct_dc_altivec( int16_t dct[4], uint8_t *pix1, uint8_t *pix2 );
#define x264_sub8x8_dct8_altivec x264_template(sub8x8_dct8_altivec)
void x264_sub8x8_dct8_altivec( int16_t dct[64], uint8_t *pix1, uint8_t *pix2 );
#define x264_sub16x16_dct8_altivec x264_template(sub16x16_dct8_altivec)
void x264_sub16x16_dct8_altivec( int16_t dct[4][64], uint8_t *pix1, uint8_t *pix2 );

#define x264_add8x8_idct8_altivec x264_template(add8x8_idct8_altivec)
void x264_add8x8_idct8_altivec( uint8_t *dst, int16_t dct[64] );
#define x264_add16x16_idct8_altivec x264_template(add16x16_idct8_altivec)
void x264_add16x16_idct8_altivec( uint8_t *dst, int16_t dct[4][64] );

#define x264_zigzag_scan_4x4_frame_altivec x264_template(zigzag_scan_4x4_frame_altivec)
void x264_zigzag_scan_4x4_frame_altivec( int16_t level[16], int16_t dct[16] );
#define x264_zigzag_scan_4x4_field_altivec x264_template(zigzag_scan_4x4_field_altivec)
void x264_zigzag_scan_4x4_field_altivec( int16_t level[16], int16_t dct[16] );
#define x264_zigzag_scan_8x8_frame_altivec x264_template(zigzag_scan_8x8_frame_altivec)
void x264_zigzag_scan_8x8_frame_altivec( int16_t level[64], int16_t dct[64] );
#define x264_zigzag_interleave_8x8_cavlc_altivec x264_template(zigzag_interleave_8x8_cavlc_altivec)
void x264_zigzag_interleave_8x8_cavlc_altivec( int16_t *dst, int16_t *src, uint8_t *nnz );

#endif
