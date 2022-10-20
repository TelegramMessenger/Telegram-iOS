/*****************************************************************************
 * bitstream.h: x86 bitstream functions
 *****************************************************************************
 * Copyright (C) 2017-2022 x264 project
 *
 * Authors: Anton Mitrofanov <BugMaster@narod.ru>
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

#ifndef X264_X86_BITSTREAM_H
#define X264_X86_BITSTREAM_H

#define x264_nal_escape_mmx2 x264_template(nal_escape_mmx2)
uint8_t *x264_nal_escape_mmx2( uint8_t *dst, uint8_t *src, uint8_t *end );
#define x264_nal_escape_sse2 x264_template(nal_escape_sse2)
uint8_t *x264_nal_escape_sse2( uint8_t *dst, uint8_t *src, uint8_t *end );
#define x264_nal_escape_avx2 x264_template(nal_escape_avx2)
uint8_t *x264_nal_escape_avx2( uint8_t *dst, uint8_t *src, uint8_t *end );
#define x264_cabac_block_residual_rd_internal_sse2 x264_template(cabac_block_residual_rd_internal_sse2)
void x264_cabac_block_residual_rd_internal_sse2       ( dctcoef *l, int b_interlaced, intptr_t ctx_block_cat, x264_cabac_t *cb );
#define x264_cabac_block_residual_rd_internal_lzcnt x264_template(cabac_block_residual_rd_internal_lzcnt)
void x264_cabac_block_residual_rd_internal_lzcnt      ( dctcoef *l, int b_interlaced, intptr_t ctx_block_cat, x264_cabac_t *cb );
#define x264_cabac_block_residual_rd_internal_ssse3 x264_template(cabac_block_residual_rd_internal_ssse3)
void x264_cabac_block_residual_rd_internal_ssse3      ( dctcoef *l, int b_interlaced, intptr_t ctx_block_cat, x264_cabac_t *cb );
#define x264_cabac_block_residual_rd_internal_ssse3_lzcnt x264_template(cabac_block_residual_rd_internal_ssse3_lzcnt)
void x264_cabac_block_residual_rd_internal_ssse3_lzcnt( dctcoef *l, int b_interlaced, intptr_t ctx_block_cat, x264_cabac_t *cb );
#define x264_cabac_block_residual_rd_internal_avx512 x264_template(cabac_block_residual_rd_internal_avx512)
void x264_cabac_block_residual_rd_internal_avx512     ( dctcoef *l, int b_interlaced, intptr_t ctx_block_cat, x264_cabac_t *cb );
#define x264_cabac_block_residual_8x8_rd_internal_sse2 x264_template(cabac_block_residual_8x8_rd_internal_sse2)
void x264_cabac_block_residual_8x8_rd_internal_sse2       ( dctcoef *l, int b_interlaced, intptr_t ctx_block_cat, x264_cabac_t *cb );
#define x264_cabac_block_residual_8x8_rd_internal_lzcnt x264_template(cabac_block_residual_8x8_rd_internal_lzcnt)
void x264_cabac_block_residual_8x8_rd_internal_lzcnt      ( dctcoef *l, int b_interlaced, intptr_t ctx_block_cat, x264_cabac_t *cb );
#define x264_cabac_block_residual_8x8_rd_internal_ssse3 x264_template(cabac_block_residual_8x8_rd_internal_ssse3)
void x264_cabac_block_residual_8x8_rd_internal_ssse3      ( dctcoef *l, int b_interlaced, intptr_t ctx_block_cat, x264_cabac_t *cb );
#define x264_cabac_block_residual_8x8_rd_internal_ssse3_lzcnt x264_template(cabac_block_residual_8x8_rd_internal_ssse3_lzcnt)
void x264_cabac_block_residual_8x8_rd_internal_ssse3_lzcnt( dctcoef *l, int b_interlaced, intptr_t ctx_block_cat, x264_cabac_t *cb );
#define x264_cabac_block_residual_8x8_rd_internal_avx512 x264_template(cabac_block_residual_8x8_rd_internal_avx512)
void x264_cabac_block_residual_8x8_rd_internal_avx512     ( dctcoef *l, int b_interlaced, intptr_t ctx_block_cat, x264_cabac_t *cb );
#define x264_cabac_block_residual_internal_sse2 x264_template(cabac_block_residual_internal_sse2)
void x264_cabac_block_residual_internal_sse2  ( dctcoef *l, int b_interlaced, intptr_t ctx_block_cat, x264_cabac_t *cb );
#define x264_cabac_block_residual_internal_lzcnt x264_template(cabac_block_residual_internal_lzcnt)
void x264_cabac_block_residual_internal_lzcnt ( dctcoef *l, int b_interlaced, intptr_t ctx_block_cat, x264_cabac_t *cb );
#define x264_cabac_block_residual_internal_avx2 x264_template(cabac_block_residual_internal_avx2)
void x264_cabac_block_residual_internal_avx2  ( dctcoef *l, int b_interlaced, intptr_t ctx_block_cat, x264_cabac_t *cb );
#define x264_cabac_block_residual_internal_avx512 x264_template(cabac_block_residual_internal_avx512)
void x264_cabac_block_residual_internal_avx512( dctcoef *l, int b_interlaced, intptr_t ctx_block_cat, x264_cabac_t *cb );

#endif
