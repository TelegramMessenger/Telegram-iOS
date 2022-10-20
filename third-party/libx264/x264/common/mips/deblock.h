/*****************************************************************************
 * deblock.h: msa deblocking
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

#ifndef X264_MIPS_DEBLOCK_H
#define X264_MIPS_DEBLOCK_H

#if !HIGH_BIT_DEPTH
#define x264_deblock_v_luma_msa x264_template(deblock_v_luma_msa)
void x264_deblock_v_luma_msa( uint8_t *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 );
#define x264_deblock_h_luma_msa x264_template(deblock_h_luma_msa)
void x264_deblock_h_luma_msa( uint8_t *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 );
#define x264_deblock_v_chroma_msa x264_template(deblock_v_chroma_msa)
void x264_deblock_v_chroma_msa( uint8_t *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 );
#define x264_deblock_h_chroma_msa x264_template(deblock_h_chroma_msa)
void x264_deblock_h_chroma_msa( uint8_t *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 );
#define x264_deblock_v_luma_intra_msa x264_template(deblock_v_luma_intra_msa)
void x264_deblock_v_luma_intra_msa( uint8_t *pix, intptr_t stride, int alpha, int beta );
#define x264_deblock_h_luma_intra_msa x264_template(deblock_h_luma_intra_msa)
void x264_deblock_h_luma_intra_msa( uint8_t *pix, intptr_t stride, int alpha, int beta );
#define x264_deblock_v_chroma_intra_msa x264_template(deblock_v_chroma_intra_msa)
void x264_deblock_v_chroma_intra_msa( uint8_t *pix, intptr_t stride, int alpha, int beta );
#define x264_deblock_h_chroma_intra_msa x264_template(deblock_h_chroma_intra_msa)
void x264_deblock_h_chroma_intra_msa( uint8_t *pix, intptr_t stride, int alpha, int beta );
#define x264_deblock_strength_msa x264_template(deblock_strength_msa)
void x264_deblock_strength_msa( uint8_t nnz[X264_SCAN8_SIZE], int8_t ref[2][X264_SCAN8_LUMA_SIZE],
                                int16_t mv[2][X264_SCAN8_LUMA_SIZE][2], uint8_t bs[2][8][4], int mvy_limit,
                                int bframe );
#endif

#endif
