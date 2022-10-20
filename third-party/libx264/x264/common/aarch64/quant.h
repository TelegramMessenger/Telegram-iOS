/*****************************************************************************
 * quant.h: arm quantization and level-run
 *****************************************************************************
 * Copyright (C) 2005-2022 x264 project
 *
 * Authors: David Conrad <lessen42@gmail.com>
 *          Janne Grunau <janne-x264@jannau.net>
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

#ifndef X264_AARCH64_QUANT_H
#define X264_AARCH64_QUANT_H

#define x264_quant_2x2_dc_aarch64 x264_template(quant_2x2_dc_aarch64)
int x264_quant_2x2_dc_aarch64( int16_t dct[4], int mf, int bias );

#define x264_quant_2x2_dc_neon x264_template(quant_2x2_dc_neon)
int x264_quant_2x2_dc_neon( int16_t dct[4], int mf, int bias );
#define x264_quant_4x4_dc_neon x264_template(quant_4x4_dc_neon)
int x264_quant_4x4_dc_neon( int16_t dct[16], int mf, int bias );
#define x264_quant_4x4_neon x264_template(quant_4x4_neon)
int x264_quant_4x4_neon( int16_t dct[16], uint16_t mf[16], uint16_t bias[16] );
#define x264_quant_4x4x4_neon x264_template(quant_4x4x4_neon)
int x264_quant_4x4x4_neon( int16_t dct[4][16], uint16_t mf[16], uint16_t bias[16] );
#define x264_quant_8x8_neon x264_template(quant_8x8_neon)
int x264_quant_8x8_neon( int16_t dct[64], uint16_t mf[64], uint16_t bias[64] );

#define x264_dequant_4x4_dc_neon x264_template(dequant_4x4_dc_neon)
void x264_dequant_4x4_dc_neon( int16_t dct[16], int dequant_mf[6][16], int i_qp );
#define x264_dequant_4x4_neon x264_template(dequant_4x4_neon)
void x264_dequant_4x4_neon( int16_t dct[16], int dequant_mf[6][16], int i_qp );
#define x264_dequant_8x8_neon x264_template(dequant_8x8_neon)
void x264_dequant_8x8_neon( int16_t dct[64], int dequant_mf[6][64], int i_qp );

#define x264_decimate_score15_neon x264_template(decimate_score15_neon)
int x264_decimate_score15_neon( int16_t * );
#define x264_decimate_score16_neon x264_template(decimate_score16_neon)
int x264_decimate_score16_neon( int16_t * );
#define x264_decimate_score64_neon x264_template(decimate_score64_neon)
int x264_decimate_score64_neon( int16_t * );

#define x264_coeff_last4_aarch64 x264_template(coeff_last4_aarch64)
int x264_coeff_last4_aarch64( int16_t * );
#define x264_coeff_last8_aarch64 x264_template(coeff_last8_aarch64)
int x264_coeff_last8_aarch64( int16_t * );
#define x264_coeff_last15_neon x264_template(coeff_last15_neon)
int x264_coeff_last15_neon( int16_t * );
#define x264_coeff_last16_neon x264_template(coeff_last16_neon)
int x264_coeff_last16_neon( int16_t * );
#define x264_coeff_last64_neon x264_template(coeff_last64_neon)
int x264_coeff_last64_neon( int16_t * );

#define x264_coeff_level_run4_aarch64 x264_template(coeff_level_run4_aarch64)
int x264_coeff_level_run4_aarch64( int16_t *, x264_run_level_t * );
#define x264_coeff_level_run8_neon x264_template(coeff_level_run8_neon)
int x264_coeff_level_run8_neon( int16_t *, x264_run_level_t * );
#define x264_coeff_level_run15_neon x264_template(coeff_level_run15_neon)
int x264_coeff_level_run15_neon( int16_t *, x264_run_level_t * );
#define x264_coeff_level_run16_neon x264_template(coeff_level_run16_neon)
int x264_coeff_level_run16_neon( int16_t *, x264_run_level_t * );

#define x264_denoise_dct_neon x264_template(denoise_dct_neon)
void x264_denoise_dct_neon( dctcoef *, uint32_t *, udctcoef *, int );

#endif
