/*****************************************************************************
 * quant.h: x86 quantization and level-run
 *****************************************************************************
 * Copyright (C) 2005-2022 x264 project
 *
 * Authors: Loren Merritt <lorenm@u.washington.edu>
 *          Fiona Glaser <fiona@x264.com>
 *          Christian Heine <sennindemokrit@gmx.net>
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

#ifndef X264_X86_QUANT_H
#define X264_X86_QUANT_H

#define x264_quant_2x2_dc_mmx2 x264_template(quant_2x2_dc_mmx2)
int x264_quant_2x2_dc_mmx2( dctcoef dct[4], int mf, int bias );
#define x264_quant_4x4_dc_mmx2 x264_template(quant_4x4_dc_mmx2)
int x264_quant_4x4_dc_mmx2( dctcoef dct[16], int mf, int bias );
#define x264_quant_4x4_mmx2 x264_template(quant_4x4_mmx2)
int x264_quant_4x4_mmx2( dctcoef dct[16], udctcoef mf[16], udctcoef bias[16] );
#define x264_quant_8x8_mmx2 x264_template(quant_8x8_mmx2)
int x264_quant_8x8_mmx2( dctcoef dct[64], udctcoef mf[64], udctcoef bias[64] );
#define x264_quant_2x2_dc_sse2 x264_template(quant_2x2_dc_sse2)
int x264_quant_2x2_dc_sse2( dctcoef dct[16], int mf, int bias );
#define x264_quant_4x4_dc_sse2 x264_template(quant_4x4_dc_sse2)
int x264_quant_4x4_dc_sse2( dctcoef dct[16], int mf, int bias );
#define x264_quant_4x4_sse2 x264_template(quant_4x4_sse2)
int x264_quant_4x4_sse2( dctcoef dct[16], udctcoef mf[16], udctcoef bias[16] );
#define x264_quant_4x4x4_sse2 x264_template(quant_4x4x4_sse2)
int x264_quant_4x4x4_sse2( dctcoef dct[4][16], udctcoef mf[16], udctcoef bias[16] );
#define x264_quant_8x8_sse2 x264_template(quant_8x8_sse2)
int x264_quant_8x8_sse2( dctcoef dct[64], udctcoef mf[64], udctcoef bias[64] );
#define x264_quant_2x2_dc_ssse3 x264_template(quant_2x2_dc_ssse3)
int x264_quant_2x2_dc_ssse3( dctcoef dct[4], int mf, int bias );
#define x264_quant_4x4_dc_ssse3 x264_template(quant_4x4_dc_ssse3)
int x264_quant_4x4_dc_ssse3( dctcoef dct[16], int mf, int bias );
#define x264_quant_4x4_ssse3 x264_template(quant_4x4_ssse3)
int x264_quant_4x4_ssse3( dctcoef dct[16], udctcoef mf[16], udctcoef bias[16] );
#define x264_quant_4x4x4_ssse3 x264_template(quant_4x4x4_ssse3)
int x264_quant_4x4x4_ssse3( dctcoef dct[4][16], udctcoef mf[16], udctcoef bias[16] );
#define x264_quant_8x8_ssse3 x264_template(quant_8x8_ssse3)
int x264_quant_8x8_ssse3( dctcoef dct[64], udctcoef mf[64], udctcoef bias[64] );
#define x264_quant_2x2_dc_sse4 x264_template(quant_2x2_dc_sse4)
int x264_quant_2x2_dc_sse4( dctcoef dct[16], int mf, int bias );
#define x264_quant_4x4_dc_sse4 x264_template(quant_4x4_dc_sse4)
int x264_quant_4x4_dc_sse4( dctcoef dct[16], int mf, int bias );
#define x264_quant_4x4_sse4 x264_template(quant_4x4_sse4)
int x264_quant_4x4_sse4( dctcoef dct[16], udctcoef mf[16], udctcoef bias[16] );
#define x264_quant_4x4x4_sse4 x264_template(quant_4x4x4_sse4)
int x264_quant_4x4x4_sse4( dctcoef dct[4][16], udctcoef mf[16], udctcoef bias[16] );
#define x264_quant_8x8_sse4 x264_template(quant_8x8_sse4)
int x264_quant_8x8_sse4( dctcoef dct[64], udctcoef mf[64], udctcoef bias[64] );
#define x264_quant_4x4_avx2 x264_template(quant_4x4_avx2)
int x264_quant_4x4_avx2( dctcoef dct[16], udctcoef mf[16], udctcoef bias[16] );
#define x264_quant_4x4_dc_avx2 x264_template(quant_4x4_dc_avx2)
int x264_quant_4x4_dc_avx2( dctcoef dct[16], int mf, int bias );
#define x264_quant_8x8_avx2 x264_template(quant_8x8_avx2)
int x264_quant_8x8_avx2( dctcoef dct[64], udctcoef mf[64], udctcoef bias[64] );
#define x264_quant_4x4x4_avx2 x264_template(quant_4x4x4_avx2)
int x264_quant_4x4x4_avx2( dctcoef dct[4][16], udctcoef mf[16], udctcoef bias[16] );
#define x264_dequant_4x4_mmx x264_template(dequant_4x4_mmx)
void x264_dequant_4x4_mmx( int16_t dct[16], int dequant_mf[6][16], int i_qp );
#define x264_dequant_4x4dc_mmx2 x264_template(dequant_4x4dc_mmx2)
void x264_dequant_4x4dc_mmx2( int16_t dct[16], int dequant_mf[6][16], int i_qp );
#define x264_dequant_8x8_mmx x264_template(dequant_8x8_mmx)
void x264_dequant_8x8_mmx( int16_t dct[64], int dequant_mf[6][64], int i_qp );
#define x264_dequant_4x4_sse2 x264_template(dequant_4x4_sse2)
void x264_dequant_4x4_sse2( dctcoef dct[16], int dequant_mf[6][16], int i_qp );
#define x264_dequant_4x4dc_sse2 x264_template(dequant_4x4dc_sse2)
void x264_dequant_4x4dc_sse2( dctcoef dct[16], int dequant_mf[6][16], int i_qp );
#define x264_dequant_8x8_sse2 x264_template(dequant_8x8_sse2)
void x264_dequant_8x8_sse2( dctcoef dct[64], int dequant_mf[6][64], int i_qp );
#define x264_dequant_4x4_avx x264_template(dequant_4x4_avx)
void x264_dequant_4x4_avx( dctcoef dct[16], int dequant_mf[6][16], int i_qp );
#define x264_dequant_4x4dc_avx x264_template(dequant_4x4dc_avx)
void x264_dequant_4x4dc_avx( dctcoef dct[16], int dequant_mf[6][16], int i_qp );
#define x264_dequant_8x8_avx x264_template(dequant_8x8_avx)
void x264_dequant_8x8_avx( dctcoef dct[64], int dequant_mf[6][64], int i_qp );
#define x264_dequant_4x4_xop x264_template(dequant_4x4_xop)
void x264_dequant_4x4_xop( dctcoef dct[16], int dequant_mf[6][16], int i_qp );
#define x264_dequant_4x4dc_xop x264_template(dequant_4x4dc_xop)
void x264_dequant_4x4dc_xop( dctcoef dct[16], int dequant_mf[6][16], int i_qp );
#define x264_dequant_8x8_xop x264_template(dequant_8x8_xop)
void x264_dequant_8x8_xop( dctcoef dct[64], int dequant_mf[6][64], int i_qp );
#define x264_dequant_4x4_avx2 x264_template(dequant_4x4_avx2)
void x264_dequant_4x4_avx2( dctcoef dct[16], int dequant_mf[6][16], int i_qp );
#define x264_dequant_4x4dc_avx2 x264_template(dequant_4x4dc_avx2)
void x264_dequant_4x4dc_avx2( dctcoef dct[16], int dequant_mf[6][16], int i_qp );
#define x264_dequant_8x8_avx2 x264_template(dequant_8x8_avx2)
void x264_dequant_8x8_avx2( dctcoef dct[64], int dequant_mf[6][64], int i_qp );
#define x264_dequant_4x4_avx512 x264_template(dequant_4x4_avx512)
void x264_dequant_4x4_avx512( dctcoef dct[16], int dequant_mf[6][16], int i_qp );
#define x264_dequant_8x8_avx512 x264_template(dequant_8x8_avx512)
void x264_dequant_8x8_avx512( dctcoef dct[64], int dequant_mf[6][64], int i_qp );
#define x264_dequant_4x4_flat16_mmx x264_template(dequant_4x4_flat16_mmx)
void x264_dequant_4x4_flat16_mmx( int16_t dct[16], int dequant_mf[6][16], int i_qp );
#define x264_dequant_8x8_flat16_mmx x264_template(dequant_8x8_flat16_mmx)
void x264_dequant_8x8_flat16_mmx( int16_t dct[64], int dequant_mf[6][64], int i_qp );
#define x264_dequant_4x4_flat16_sse2 x264_template(dequant_4x4_flat16_sse2)
void x264_dequant_4x4_flat16_sse2( int16_t dct[16], int dequant_mf[6][16], int i_qp );
#define x264_dequant_8x8_flat16_sse2 x264_template(dequant_8x8_flat16_sse2)
void x264_dequant_8x8_flat16_sse2( int16_t dct[64], int dequant_mf[6][64], int i_qp );
#define x264_dequant_4x4_flat16_avx2 x264_template(dequant_4x4_flat16_avx2)
void x264_dequant_4x4_flat16_avx2( int16_t dct[16], int dequant_mf[6][16], int i_qp );
#define x264_dequant_8x8_flat16_avx2 x264_template(dequant_8x8_flat16_avx2)
void x264_dequant_8x8_flat16_avx2( int16_t dct[64], int dequant_mf[6][64], int i_qp );
#define x264_dequant_8x8_flat16_avx512 x264_template(dequant_8x8_flat16_avx512)
void x264_dequant_8x8_flat16_avx512( int16_t dct[64], int dequant_mf[6][64], int i_qp );
#define x264_idct_dequant_2x4_dc_sse2 x264_template(idct_dequant_2x4_dc_sse2)
void x264_idct_dequant_2x4_dc_sse2( dctcoef dct[8], dctcoef dct4x4[8][16], int dequant_mf[6][16], int i_qp );
#define x264_idct_dequant_2x4_dc_avx x264_template(idct_dequant_2x4_dc_avx)
void x264_idct_dequant_2x4_dc_avx ( dctcoef dct[8], dctcoef dct4x4[8][16], int dequant_mf[6][16], int i_qp );
#define x264_idct_dequant_2x4_dconly_sse2 x264_template(idct_dequant_2x4_dconly_sse2)
void x264_idct_dequant_2x4_dconly_sse2( dctcoef dct[8], int dequant_mf[6][16], int i_qp );
#define x264_idct_dequant_2x4_dconly_avx x264_template(idct_dequant_2x4_dconly_avx)
void x264_idct_dequant_2x4_dconly_avx ( dctcoef dct[8], int dequant_mf[6][16], int i_qp );
#define x264_optimize_chroma_2x2_dc_sse2 x264_template(optimize_chroma_2x2_dc_sse2)
int x264_optimize_chroma_2x2_dc_sse2( dctcoef dct[4], int dequant_mf );
#define x264_optimize_chroma_2x2_dc_ssse3 x264_template(optimize_chroma_2x2_dc_ssse3)
int x264_optimize_chroma_2x2_dc_ssse3( dctcoef dct[4], int dequant_mf );
#define x264_optimize_chroma_2x2_dc_sse4 x264_template(optimize_chroma_2x2_dc_sse4)
int x264_optimize_chroma_2x2_dc_sse4( dctcoef dct[4], int dequant_mf );
#define x264_optimize_chroma_2x2_dc_avx x264_template(optimize_chroma_2x2_dc_avx)
int x264_optimize_chroma_2x2_dc_avx( dctcoef dct[4], int dequant_mf );
#define x264_denoise_dct_mmx x264_template(denoise_dct_mmx)
void x264_denoise_dct_mmx  ( dctcoef *dct, uint32_t *sum, udctcoef *offset, int size );
#define x264_denoise_dct_sse2 x264_template(denoise_dct_sse2)
void x264_denoise_dct_sse2 ( dctcoef *dct, uint32_t *sum, udctcoef *offset, int size );
#define x264_denoise_dct_ssse3 x264_template(denoise_dct_ssse3)
void x264_denoise_dct_ssse3( dctcoef *dct, uint32_t *sum, udctcoef *offset, int size );
#define x264_denoise_dct_avx x264_template(denoise_dct_avx)
void x264_denoise_dct_avx  ( dctcoef *dct, uint32_t *sum, udctcoef *offset, int size );
#define x264_denoise_dct_avx2 x264_template(denoise_dct_avx2)
void x264_denoise_dct_avx2 ( dctcoef *dct, uint32_t *sum, udctcoef *offset, int size );
#define x264_decimate_score15_sse2 x264_template(decimate_score15_sse2)
int x264_decimate_score15_sse2( dctcoef *dct );
#define x264_decimate_score15_ssse3 x264_template(decimate_score15_ssse3)
int x264_decimate_score15_ssse3( dctcoef *dct );
#define x264_decimate_score15_avx512 x264_template(decimate_score15_avx512)
int x264_decimate_score15_avx512( dctcoef *dct );
#define x264_decimate_score16_sse2 x264_template(decimate_score16_sse2)
int x264_decimate_score16_sse2( dctcoef *dct );
#define x264_decimate_score16_ssse3 x264_template(decimate_score16_ssse3)
int x264_decimate_score16_ssse3( dctcoef *dct );
#define x264_decimate_score16_avx512 x264_template(decimate_score16_avx512)
int x264_decimate_score16_avx512( dctcoef *dct );
#define x264_decimate_score64_sse2 x264_template(decimate_score64_sse2)
int x264_decimate_score64_sse2( dctcoef *dct );
#define x264_decimate_score64_ssse3 x264_template(decimate_score64_ssse3)
int x264_decimate_score64_ssse3( dctcoef *dct );
#define x264_decimate_score64_avx2 x264_template(decimate_score64_avx2)
int x264_decimate_score64_avx2( int16_t *dct );
#define x264_decimate_score64_avx512 x264_template(decimate_score64_avx512)
int x264_decimate_score64_avx512( dctcoef *dct );
#define x264_coeff_last4_mmx2 x264_template(coeff_last4_mmx2)
int x264_coeff_last4_mmx2( dctcoef *dct );
#define x264_coeff_last8_mmx2 x264_template(coeff_last8_mmx2)
int x264_coeff_last8_mmx2( dctcoef *dct );
#define x264_coeff_last15_mmx2 x264_template(coeff_last15_mmx2)
int x264_coeff_last15_mmx2( dctcoef *dct );
#define x264_coeff_last16_mmx2 x264_template(coeff_last16_mmx2)
int x264_coeff_last16_mmx2( dctcoef *dct );
#define x264_coeff_last64_mmx2 x264_template(coeff_last64_mmx2)
int x264_coeff_last64_mmx2( dctcoef *dct );
#define x264_coeff_last8_sse2 x264_template(coeff_last8_sse2)
int x264_coeff_last8_sse2( dctcoef *dct );
#define x264_coeff_last15_sse2 x264_template(coeff_last15_sse2)
int x264_coeff_last15_sse2( dctcoef *dct );
#define x264_coeff_last16_sse2 x264_template(coeff_last16_sse2)
int x264_coeff_last16_sse2( dctcoef *dct );
#define x264_coeff_last64_sse2 x264_template(coeff_last64_sse2)
int x264_coeff_last64_sse2( dctcoef *dct );
#define x264_coeff_last4_lzcnt x264_template(coeff_last4_lzcnt)
int x264_coeff_last4_lzcnt( dctcoef *dct );
#define x264_coeff_last8_lzcnt x264_template(coeff_last8_lzcnt)
int x264_coeff_last8_lzcnt( dctcoef *dct );
#define x264_coeff_last15_lzcnt x264_template(coeff_last15_lzcnt)
int x264_coeff_last15_lzcnt( dctcoef *dct );
#define x264_coeff_last16_lzcnt x264_template(coeff_last16_lzcnt)
int x264_coeff_last16_lzcnt( dctcoef *dct );
#define x264_coeff_last64_lzcnt x264_template(coeff_last64_lzcnt)
int x264_coeff_last64_lzcnt( dctcoef *dct );
#define x264_coeff_last64_avx2 x264_template(coeff_last64_avx2)
int x264_coeff_last64_avx2 ( dctcoef *dct );
#define x264_coeff_last4_avx512 x264_template(coeff_last4_avx512)
int x264_coeff_last4_avx512( int32_t *dct );
#define x264_coeff_last8_avx512 x264_template(coeff_last8_avx512)
int x264_coeff_last8_avx512( dctcoef *dct );
#define x264_coeff_last15_avx512 x264_template(coeff_last15_avx512)
int x264_coeff_last15_avx512( dctcoef *dct );
#define x264_coeff_last16_avx512 x264_template(coeff_last16_avx512)
int x264_coeff_last16_avx512( dctcoef *dct );
#define x264_coeff_last64_avx512 x264_template(coeff_last64_avx512)
int x264_coeff_last64_avx512( dctcoef *dct );
#define x264_coeff_level_run16_mmx2 x264_template(coeff_level_run16_mmx2)
int x264_coeff_level_run16_mmx2( dctcoef *dct, x264_run_level_t *runlevel );
#define x264_coeff_level_run16_sse2 x264_template(coeff_level_run16_sse2)
int x264_coeff_level_run16_sse2( dctcoef *dct, x264_run_level_t *runlevel );
#define x264_coeff_level_run16_lzcnt x264_template(coeff_level_run16_lzcnt)
int x264_coeff_level_run16_lzcnt( dctcoef *dct, x264_run_level_t *runlevel );
#define x264_coeff_level_run16_ssse3 x264_template(coeff_level_run16_ssse3)
int x264_coeff_level_run16_ssse3( dctcoef *dct, x264_run_level_t *runlevel );
#define x264_coeff_level_run16_ssse3_lzcnt x264_template(coeff_level_run16_ssse3_lzcnt)
int x264_coeff_level_run16_ssse3_lzcnt( dctcoef *dct, x264_run_level_t *runlevel );
#define x264_coeff_level_run16_avx2 x264_template(coeff_level_run16_avx2)
int x264_coeff_level_run16_avx2( dctcoef *dct, x264_run_level_t *runlevel );
#define x264_coeff_level_run15_mmx2 x264_template(coeff_level_run15_mmx2)
int x264_coeff_level_run15_mmx2( dctcoef *dct, x264_run_level_t *runlevel );
#define x264_coeff_level_run15_sse2 x264_template(coeff_level_run15_sse2)
int x264_coeff_level_run15_sse2( dctcoef *dct, x264_run_level_t *runlevel );
#define x264_coeff_level_run15_lzcnt x264_template(coeff_level_run15_lzcnt)
int x264_coeff_level_run15_lzcnt( dctcoef *dct, x264_run_level_t *runlevel );
#define x264_coeff_level_run15_ssse3 x264_template(coeff_level_run15_ssse3)
int x264_coeff_level_run15_ssse3( dctcoef *dct, x264_run_level_t *runlevel );
#define x264_coeff_level_run15_ssse3_lzcnt x264_template(coeff_level_run15_ssse3_lzcnt)
int x264_coeff_level_run15_ssse3_lzcnt( dctcoef *dct, x264_run_level_t *runlevel );
#define x264_coeff_level_run15_avx2 x264_template(coeff_level_run15_avx2)
int x264_coeff_level_run15_avx2( dctcoef *dct, x264_run_level_t *runlevel );
#define x264_coeff_level_run4_mmx2 x264_template(coeff_level_run4_mmx2)
int x264_coeff_level_run4_mmx2( dctcoef *dct, x264_run_level_t *runlevel );
#define x264_coeff_level_run4_lzcnt x264_template(coeff_level_run4_lzcnt)
int x264_coeff_level_run4_lzcnt( dctcoef *dct, x264_run_level_t *runlevel );
#define x264_coeff_level_run4_ssse3 x264_template(coeff_level_run4_ssse3)
int x264_coeff_level_run4_ssse3( dctcoef *dct, x264_run_level_t *runlevel );
#define x264_coeff_level_run4_ssse3_lzcnt x264_template(coeff_level_run4_ssse3_lzcnt)
int x264_coeff_level_run4_ssse3_lzcnt( dctcoef *dct, x264_run_level_t *runlevel );
#define x264_coeff_level_run8_mmx2 x264_template(coeff_level_run8_mmx2)
int x264_coeff_level_run8_mmx2( dctcoef *dct, x264_run_level_t *runlevel );
#define x264_coeff_level_run8_lzcnt x264_template(coeff_level_run8_lzcnt)
int x264_coeff_level_run8_lzcnt( dctcoef *dct, x264_run_level_t *runlevel );
#define x264_coeff_level_run8_sse2 x264_template(coeff_level_run8_sse2)
int x264_coeff_level_run8_sse2( dctcoef *dct, x264_run_level_t *runlevel );
#define x264_coeff_level_run8_ssse3 x264_template(coeff_level_run8_ssse3)
int x264_coeff_level_run8_ssse3( dctcoef *dct, x264_run_level_t *runlevel );
#define x264_coeff_level_run8_ssse3_lzcnt x264_template(coeff_level_run8_ssse3_lzcnt)
int x264_coeff_level_run8_ssse3_lzcnt( dctcoef *dct, x264_run_level_t *runlevel );
#define x264_trellis_cabac_4x4_sse2 x264_template(trellis_cabac_4x4_sse2)
int x264_trellis_cabac_4x4_sse2 ( TRELLIS_PARAMS, int b_ac );
#define x264_trellis_cabac_4x4_ssse3 x264_template(trellis_cabac_4x4_ssse3)
int x264_trellis_cabac_4x4_ssse3( TRELLIS_PARAMS, int b_ac );
#define x264_trellis_cabac_8x8_sse2 x264_template(trellis_cabac_8x8_sse2)
int x264_trellis_cabac_8x8_sse2 ( TRELLIS_PARAMS, int b_interlaced );
#define x264_trellis_cabac_8x8_ssse3 x264_template(trellis_cabac_8x8_ssse3)
int x264_trellis_cabac_8x8_ssse3( TRELLIS_PARAMS, int b_interlaced );
#define x264_trellis_cabac_4x4_psy_sse2 x264_template(trellis_cabac_4x4_psy_sse2)
int x264_trellis_cabac_4x4_psy_sse2 ( TRELLIS_PARAMS, int b_ac, dctcoef *fenc_dct, int i_psy_trellis );
#define x264_trellis_cabac_4x4_psy_ssse3 x264_template(trellis_cabac_4x4_psy_ssse3)
int x264_trellis_cabac_4x4_psy_ssse3( TRELLIS_PARAMS, int b_ac, dctcoef *fenc_dct, int i_psy_trellis );
#define x264_trellis_cabac_8x8_psy_sse2 x264_template(trellis_cabac_8x8_psy_sse2)
int x264_trellis_cabac_8x8_psy_sse2 ( TRELLIS_PARAMS, int b_interlaced, dctcoef *fenc_dct, int i_psy_trellis );
#define x264_trellis_cabac_8x8_psy_ssse3 x264_template(trellis_cabac_8x8_psy_ssse3)
int x264_trellis_cabac_8x8_psy_ssse3( TRELLIS_PARAMS, int b_interlaced, dctcoef *fenc_dct, int i_psy_trellis );
#define x264_trellis_cabac_dc_sse2 x264_template(trellis_cabac_dc_sse2)
int x264_trellis_cabac_dc_sse2 ( TRELLIS_PARAMS, int i_coefs );
#define x264_trellis_cabac_dc_ssse3 x264_template(trellis_cabac_dc_ssse3)
int x264_trellis_cabac_dc_ssse3( TRELLIS_PARAMS, int i_coefs );
#define x264_trellis_cabac_chroma_422_dc_sse2 x264_template(trellis_cabac_chroma_422_dc_sse2)
int x264_trellis_cabac_chroma_422_dc_sse2 ( TRELLIS_PARAMS );
#define x264_trellis_cabac_chroma_422_dc_ssse3 x264_template(trellis_cabac_chroma_422_dc_ssse3)
int x264_trellis_cabac_chroma_422_dc_ssse3( TRELLIS_PARAMS );

#endif
