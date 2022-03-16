/*****************************************************************************
 * dct.h: msa transform and zigzag
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

#ifndef X264_MIPS_DCT_H
#define X264_MIPS_DCT_H

#define x264_dct4x4dc_msa x264_template(dct4x4dc_msa)
void x264_dct4x4dc_msa( int16_t d[16] );
#define x264_idct4x4dc_msa x264_template(idct4x4dc_msa)
void x264_idct4x4dc_msa( int16_t d[16] );
#define x264_add4x4_idct_msa x264_template(add4x4_idct_msa)
void x264_add4x4_idct_msa( uint8_t *p_dst, int16_t pi_dct[16] );
#define x264_add8x8_idct_msa x264_template(add8x8_idct_msa)
void x264_add8x8_idct_msa( uint8_t *p_dst, int16_t pi_dct[4][16] );
#define x264_add16x16_idct_msa x264_template(add16x16_idct_msa)
void x264_add16x16_idct_msa( uint8_t *p_dst, int16_t pi_dct[16][16] );
#define x264_add8x8_idct8_msa x264_template(add8x8_idct8_msa)
void x264_add8x8_idct8_msa( uint8_t *p_dst, int16_t pi_dct[64] );
#define x264_add16x16_idct8_msa x264_template(add16x16_idct8_msa)
void x264_add16x16_idct8_msa( uint8_t *p_dst, int16_t pi_dct[4][64] );
#define x264_add8x8_idct_dc_msa x264_template(add8x8_idct_dc_msa)
void x264_add8x8_idct_dc_msa( uint8_t *p_dst, int16_t pi_dct[4] );
#define x264_add16x16_idct_dc_msa x264_template(add16x16_idct_dc_msa)
void x264_add16x16_idct_dc_msa( uint8_t *p_dst, int16_t pi_dct[16] );
#define x264_sub4x4_dct_msa x264_template(sub4x4_dct_msa)
void x264_sub4x4_dct_msa( int16_t p_dst[16], uint8_t *p_src, uint8_t *p_ref );
#define x264_sub8x8_dct_msa x264_template(sub8x8_dct_msa)
void x264_sub8x8_dct_msa( int16_t p_dst[4][16], uint8_t *p_src,
                          uint8_t *p_ref );
#define x264_sub16x16_dct_msa x264_template(sub16x16_dct_msa)
void x264_sub16x16_dct_msa( int16_t p_dst[16][16], uint8_t *p_src,
                            uint8_t *p_ref );
#define x264_sub8x8_dct_dc_msa x264_template(sub8x8_dct_dc_msa)
void x264_sub8x8_dct_dc_msa( int16_t pi_dct[4], uint8_t *p_pix1,
                             uint8_t *p_pix2 );
#define x264_sub8x16_dct_dc_msa x264_template(sub8x16_dct_dc_msa)
void x264_sub8x16_dct_dc_msa( int16_t pi_dct[8], uint8_t *p_pix1,
                              uint8_t *p_pix2 );
#define x264_zigzag_scan_4x4_frame_msa x264_template(zigzag_scan_4x4_frame_msa)
void x264_zigzag_scan_4x4_frame_msa( int16_t pi_level[16], int16_t pi_dct[16] );

#endif
