/*****************************************************************************
 * predict.h: msa intra prediction
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

#ifndef X264_MIPS_PREDICT_H
#define X264_MIPS_PREDICT_H

#define x264_intra_predict_dc_16x16_msa x264_template(intra_predict_dc_16x16_msa)
void x264_intra_predict_dc_16x16_msa( uint8_t *p_src );
#define x264_intra_predict_dc_left_16x16_msa x264_template(intra_predict_dc_left_16x16_msa)
void x264_intra_predict_dc_left_16x16_msa( uint8_t *p_src );
#define x264_intra_predict_dc_top_16x16_msa x264_template(intra_predict_dc_top_16x16_msa)
void x264_intra_predict_dc_top_16x16_msa( uint8_t *p_src );
#define x264_intra_predict_dc_128_16x16_msa x264_template(intra_predict_dc_128_16x16_msa)
void x264_intra_predict_dc_128_16x16_msa( uint8_t *p_src );
#define x264_intra_predict_hor_16x16_msa x264_template(intra_predict_hor_16x16_msa)
void x264_intra_predict_hor_16x16_msa( uint8_t *p_src );
#define x264_intra_predict_vert_16x16_msa x264_template(intra_predict_vert_16x16_msa)
void x264_intra_predict_vert_16x16_msa( uint8_t *p_src );
#define x264_intra_predict_plane_16x16_msa x264_template(intra_predict_plane_16x16_msa)
void x264_intra_predict_plane_16x16_msa( uint8_t *p_src );
#define x264_intra_predict_dc_4blk_8x8_msa x264_template(intra_predict_dc_4blk_8x8_msa)
void x264_intra_predict_dc_4blk_8x8_msa( uint8_t *p_src );
#define x264_intra_predict_hor_8x8_msa x264_template(intra_predict_hor_8x8_msa)
void x264_intra_predict_hor_8x8_msa( uint8_t *p_src );
#define x264_intra_predict_vert_8x8_msa x264_template(intra_predict_vert_8x8_msa)
void x264_intra_predict_vert_8x8_msa( uint8_t *p_src );
#define x264_intra_predict_plane_8x8_msa x264_template(intra_predict_plane_8x8_msa)
void x264_intra_predict_plane_8x8_msa( uint8_t *p_src );
#define x264_intra_predict_ddl_8x8_msa x264_template(intra_predict_ddl_8x8_msa)
void x264_intra_predict_ddl_8x8_msa( uint8_t *p_src, uint8_t pu_xyz[36] );
#define x264_intra_predict_dc_8x8_msa x264_template(intra_predict_dc_8x8_msa)
void x264_intra_predict_dc_8x8_msa( uint8_t *p_src, uint8_t pu_xyz[36] );
#define x264_intra_predict_h_8x8_msa x264_template(intra_predict_h_8x8_msa)
void x264_intra_predict_h_8x8_msa( uint8_t *p_src, uint8_t pu_xyz[36] );
#define x264_intra_predict_v_8x8_msa x264_template(intra_predict_v_8x8_msa)
void x264_intra_predict_v_8x8_msa( uint8_t *p_src, uint8_t pu_xyz[36] );
#define x264_intra_predict_dc_4x4_msa x264_template(intra_predict_dc_4x4_msa)
void x264_intra_predict_dc_4x4_msa( uint8_t *p_src );
#define x264_intra_predict_hor_4x4_msa x264_template(intra_predict_hor_4x4_msa)
void x264_intra_predict_hor_4x4_msa( uint8_t *p_src );
#define x264_intra_predict_vert_4x4_msa x264_template(intra_predict_vert_4x4_msa)
void x264_intra_predict_vert_4x4_msa( uint8_t *p_src );

#endif
