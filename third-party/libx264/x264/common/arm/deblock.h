/*****************************************************************************
 * deblock.h: arm deblocking
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

#ifndef X264_ARM_DEBLOCK_H
#define X264_ARM_DEBLOCK_H

#define x264_deblock_v_luma_neon x264_template(deblock_v_luma_neon)
void x264_deblock_v_luma_neon  ( uint8_t *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 );
#define x264_deblock_h_luma_neon x264_template(deblock_h_luma_neon)
void x264_deblock_h_luma_neon  ( uint8_t *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 );
#define x264_deblock_v_chroma_neon x264_template(deblock_v_chroma_neon)
void x264_deblock_v_chroma_neon( uint8_t *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 );
#define x264_deblock_h_chroma_neon x264_template(deblock_h_chroma_neon)
void x264_deblock_h_chroma_neon( uint8_t *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 );
#define x264_deblock_strength_neon x264_template(deblock_strength_neon)
void x264_deblock_strength_neon( uint8_t nnz[X264_SCAN8_SIZE], int8_t ref[2][X264_SCAN8_LUMA_SIZE],
                                 int16_t mv[2][X264_SCAN8_LUMA_SIZE][2], uint8_t bs[2][8][4],
                                 int mvy_limit, int bframe );
#define x264_deblock_h_chroma_422_neon x264_template(deblock_h_chroma_422_neon)
void x264_deblock_h_chroma_422_neon( uint8_t *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 );
#define x264_deblock_h_chroma_mbaff_neon x264_template(deblock_h_chroma_mbaff_neon)
void x264_deblock_h_chroma_mbaff_neon( uint8_t *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 );
#define x264_deblock_h_chroma_intra_mbaff_neon x264_template(deblock_h_chroma_intra_mbaff_neon)
void x264_deblock_h_chroma_intra_mbaff_neon( uint8_t *pix, intptr_t stride, int alpha, int beta );
#define x264_deblock_h_chroma_intra_neon x264_template(deblock_h_chroma_intra_neon)
void x264_deblock_h_chroma_intra_neon( uint8_t *pix, intptr_t stride, int alpha, int beta );
#define x264_deblock_h_chroma_422_intra_neon x264_template(deblock_h_chroma_422_intra_neon)
void x264_deblock_h_chroma_422_intra_neon( uint8_t *pix, intptr_t stride, int alpha, int beta );
#define x264_deblock_v_chroma_intra_neon x264_template(deblock_v_chroma_intra_neon)
void x264_deblock_v_chroma_intra_neon( uint8_t *pix, intptr_t stride, int alpha, int beta );
#define x264_deblock_h_luma_intra_neon x264_template(deblock_h_luma_intra_neon)
void x264_deblock_h_luma_intra_neon( uint8_t *pix, intptr_t stride, int alpha, int beta );
#define x264_deblock_v_luma_intra_neon x264_template(deblock_v_luma_intra_neon)
void x264_deblock_v_luma_intra_neon( uint8_t *pix, intptr_t stride, int alpha, int beta );

#endif
