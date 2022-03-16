/*****************************************************************************
 * deblock.h: x86 deblocking
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

#ifndef X264_X86_DEBLOCK_H
#define X264_X86_DEBLOCK_H

#define x264_deblock_v_luma_sse2 x264_template(deblock_v_luma_sse2)
void x264_deblock_v_luma_sse2( pixel *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 );
#define x264_deblock_v_luma_avx x264_template(deblock_v_luma_avx)
void x264_deblock_v_luma_avx ( pixel *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 );
#define x264_deblock_h_luma_sse2 x264_template(deblock_h_luma_sse2)
void x264_deblock_h_luma_sse2( pixel *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 );
#define x264_deblock_h_luma_avx x264_template(deblock_h_luma_avx)
void x264_deblock_h_luma_avx ( pixel *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 );
#define x264_deblock_v_chroma_sse2 x264_template(deblock_v_chroma_sse2)
void x264_deblock_v_chroma_sse2( pixel *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 );
#define x264_deblock_v_chroma_avx x264_template(deblock_v_chroma_avx)
void x264_deblock_v_chroma_avx ( pixel *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 );
#define x264_deblock_h_chroma_sse2 x264_template(deblock_h_chroma_sse2)
void x264_deblock_h_chroma_sse2( pixel *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 );
#define x264_deblock_h_chroma_avx x264_template(deblock_h_chroma_avx)
void x264_deblock_h_chroma_avx ( pixel *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 );
#define x264_deblock_h_chroma_mbaff_sse2 x264_template(deblock_h_chroma_mbaff_sse2)
void x264_deblock_h_chroma_mbaff_sse2( pixel *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 );
#define x264_deblock_h_chroma_mbaff_avx x264_template(deblock_h_chroma_mbaff_avx)
void x264_deblock_h_chroma_mbaff_avx ( pixel *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 );
#define x264_deblock_h_chroma_422_mmx2 x264_template(deblock_h_chroma_422_mmx2)
void x264_deblock_h_chroma_422_mmx2( pixel *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 );
#define x264_deblock_h_chroma_422_sse2 x264_template(deblock_h_chroma_422_sse2)
void x264_deblock_h_chroma_422_sse2( pixel *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 );
#define x264_deblock_h_chroma_422_avx x264_template(deblock_h_chroma_422_avx)
void x264_deblock_h_chroma_422_avx ( pixel *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 );
#define x264_deblock_v_luma_intra_sse2 x264_template(deblock_v_luma_intra_sse2)
void x264_deblock_v_luma_intra_sse2( pixel *pix, intptr_t stride, int alpha, int beta );
#define x264_deblock_v_luma_intra_avx x264_template(deblock_v_luma_intra_avx)
void x264_deblock_v_luma_intra_avx ( pixel *pix, intptr_t stride, int alpha, int beta );
#define x264_deblock_h_luma_intra_sse2 x264_template(deblock_h_luma_intra_sse2)
void x264_deblock_h_luma_intra_sse2( pixel *pix, intptr_t stride, int alpha, int beta );
#define x264_deblock_h_luma_intra_avx x264_template(deblock_h_luma_intra_avx)
void x264_deblock_h_luma_intra_avx ( pixel *pix, intptr_t stride, int alpha, int beta );
#define x264_deblock_v_chroma_intra_sse2 x264_template(deblock_v_chroma_intra_sse2)
void x264_deblock_v_chroma_intra_sse2( pixel *pix, intptr_t stride, int alpha, int beta );
#define x264_deblock_v_chroma_intra_avx x264_template(deblock_v_chroma_intra_avx)
void x264_deblock_v_chroma_intra_avx ( pixel *pix, intptr_t stride, int alpha, int beta );
#define x264_deblock_h_chroma_intra_sse2 x264_template(deblock_h_chroma_intra_sse2)
void x264_deblock_h_chroma_intra_sse2( pixel *pix, intptr_t stride, int alpha, int beta );
#define x264_deblock_h_chroma_intra_avx x264_template(deblock_h_chroma_intra_avx)
void x264_deblock_h_chroma_intra_avx ( pixel *pix, intptr_t stride, int alpha, int beta );
#define x264_deblock_h_chroma_422_intra_mmx2 x264_template(deblock_h_chroma_422_intra_mmx2)
void x264_deblock_h_chroma_422_intra_mmx2( pixel *pix, intptr_t stride, int alpha, int beta );
#define x264_deblock_h_chroma_422_intra_sse2 x264_template(deblock_h_chroma_422_intra_sse2)
void x264_deblock_h_chroma_422_intra_sse2( pixel *pix, intptr_t stride, int alpha, int beta );
#define x264_deblock_h_chroma_422_intra_avx x264_template(deblock_h_chroma_422_intra_avx)
void x264_deblock_h_chroma_422_intra_avx ( pixel *pix, intptr_t stride, int alpha, int beta );
#define x264_deblock_strength_sse2 x264_template(deblock_strength_sse2)
void x264_deblock_strength_sse2  ( uint8_t nnz[X264_SCAN8_SIZE], int8_t ref[2][X264_SCAN8_LUMA_SIZE],
                                   int16_t mv[2][X264_SCAN8_LUMA_SIZE][2], uint8_t bs[2][8][4],
                                   int mvy_limit, int bframe );
#define x264_deblock_strength_ssse3 x264_template(deblock_strength_ssse3)
void x264_deblock_strength_ssse3 ( uint8_t nnz[X264_SCAN8_SIZE], int8_t ref[2][X264_SCAN8_LUMA_SIZE],
                                   int16_t mv[2][X264_SCAN8_LUMA_SIZE][2], uint8_t bs[2][8][4],
                                   int mvy_limit, int bframe );
#define x264_deblock_strength_avx x264_template(deblock_strength_avx)
void x264_deblock_strength_avx   ( uint8_t nnz[X264_SCAN8_SIZE], int8_t ref[2][X264_SCAN8_LUMA_SIZE],
                                   int16_t mv[2][X264_SCAN8_LUMA_SIZE][2], uint8_t bs[2][8][4],
                                   int mvy_limit, int bframe );
#define x264_deblock_strength_avx2 x264_template(deblock_strength_avx2)
void x264_deblock_strength_avx2  ( uint8_t nnz[X264_SCAN8_SIZE], int8_t ref[2][X264_SCAN8_LUMA_SIZE],
                                   int16_t mv[2][X264_SCAN8_LUMA_SIZE][2], uint8_t bs[2][8][4],
                                   int mvy_limit, int bframe );
#define x264_deblock_strength_avx512 x264_template(deblock_strength_avx512)
void x264_deblock_strength_avx512( uint8_t nnz[X264_SCAN8_SIZE], int8_t ref[2][X264_SCAN8_LUMA_SIZE],
                                   int16_t mv[2][X264_SCAN8_LUMA_SIZE][2], uint8_t bs[2][8][4],
                                   int mvy_limit, int bframe );

#define x264_deblock_h_chroma_intra_mbaff_mmx2 x264_template(deblock_h_chroma_intra_mbaff_mmx2)
void x264_deblock_h_chroma_intra_mbaff_mmx2( pixel *pix, intptr_t stride, int alpha, int beta );
#define x264_deblock_h_chroma_intra_mbaff_sse2 x264_template(deblock_h_chroma_intra_mbaff_sse2)
void x264_deblock_h_chroma_intra_mbaff_sse2( pixel *pix, intptr_t stride, int alpha, int beta );
#define x264_deblock_h_chroma_intra_mbaff_avx x264_template(deblock_h_chroma_intra_mbaff_avx)
void x264_deblock_h_chroma_intra_mbaff_avx ( pixel *pix, intptr_t stride, int alpha, int beta );
#if ARCH_X86
#define x264_deblock_h_luma_mmx2 x264_template(deblock_h_luma_mmx2)
void x264_deblock_h_luma_mmx2( pixel *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 );
#define x264_deblock_v8_luma_mmx2 x264_template(deblock_v8_luma_mmx2)
void x264_deblock_v8_luma_mmx2( uint8_t *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 );
#define x264_deblock_v_chroma_mmx2 x264_template(deblock_v_chroma_mmx2)
void x264_deblock_v_chroma_mmx2( pixel *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 );
#define x264_deblock_h_chroma_mmx2 x264_template(deblock_h_chroma_mmx2)
void x264_deblock_h_chroma_mmx2( pixel *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 );
#define x264_deblock_h_chroma_mbaff_mmx2 x264_template(deblock_h_chroma_mbaff_mmx2)
void x264_deblock_h_chroma_mbaff_mmx2( pixel *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 );
#define x264_deblock_h_luma_intra_mmx2 x264_template(deblock_h_luma_intra_mmx2)
void x264_deblock_h_luma_intra_mmx2( pixel *pix, intptr_t stride, int alpha, int beta );
#define x264_deblock_v8_luma_intra_mmx2 x264_template(deblock_v8_luma_intra_mmx2)
void x264_deblock_v8_luma_intra_mmx2( uint8_t *pix, intptr_t stride, int alpha, int beta );
#define x264_deblock_v_chroma_intra_mmx2 x264_template(deblock_v_chroma_intra_mmx2)
void x264_deblock_v_chroma_intra_mmx2( pixel *pix, intptr_t stride, int alpha, int beta );
#define x264_deblock_h_chroma_intra_mmx2 x264_template(deblock_h_chroma_intra_mmx2)
void x264_deblock_h_chroma_intra_mmx2( pixel *pix, intptr_t stride, int alpha, int beta );
#define x264_deblock_v_chroma_intra_mbaff_mmx2 x264_template(deblock_v_chroma_intra_mbaff_mmx2)
void x264_deblock_h_chroma_intra_mbaff_mmx2( pixel *pix, intptr_t stride, int alpha, int beta );

#define x264_deblock_v_luma_mmx2 x264_template(deblock_v_luma_mmx2)
#define x264_deblock_v_luma_intra_mmx2 x264_template(deblock_v_luma_intra_mmx2)
#if HIGH_BIT_DEPTH
void x264_deblock_v_luma_mmx2( pixel *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 );
void x264_deblock_v_luma_intra_mmx2( pixel *pix, intptr_t stride, int alpha, int beta );
#else
// FIXME this wrapper has a significant cpu cost
static ALWAYS_INLINE void x264_deblock_v_luma_mmx2( uint8_t *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 )
{
    x264_deblock_v8_luma_mmx2( pix,   stride, alpha, beta, tc0   );
    x264_deblock_v8_luma_mmx2( pix+8, stride, alpha, beta, tc0+2 );
}
static ALWAYS_INLINE void x264_deblock_v_luma_intra_mmx2( uint8_t *pix, intptr_t stride, int alpha, int beta )
{
    x264_deblock_v8_luma_intra_mmx2( pix,   stride, alpha, beta );
    x264_deblock_v8_luma_intra_mmx2( pix+8, stride, alpha, beta );
}
#endif // HIGH_BIT_DEPTH
#endif

#endif
