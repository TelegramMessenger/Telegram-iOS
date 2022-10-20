/*****************************************************************************
 * predict.h: x86 intra prediction
 *****************************************************************************
 * Copyright (C) 2003-2022 x264 project
 *
 * Authors: Laurent Aimar <fenrir@via.ecp.fr>
 *          Loren Merritt <lorenm@u.washington.edu>
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

#ifndef X264_X86_PREDICT_H
#define X264_X86_PREDICT_H

#define x264_predict_16x16_init_mmx x264_template(predict_16x16_init_mmx)
void x264_predict_16x16_init_mmx( uint32_t cpu, x264_predict_t pf[7] );
#define x264_predict_8x16c_init_mmx x264_template(predict_8x16c_init_mmx)
void x264_predict_8x16c_init_mmx( uint32_t cpu, x264_predict_t pf[7] );
#define x264_predict_8x8c_init_mmx x264_template(predict_8x8c_init_mmx)
void x264_predict_8x8c_init_mmx ( uint32_t cpu, x264_predict_t pf[7] );
#define x264_predict_4x4_init_mmx x264_template(predict_4x4_init_mmx)
void x264_predict_4x4_init_mmx  ( uint32_t cpu, x264_predict_t pf[12] );
#define x264_predict_8x8_init_mmx x264_template(predict_8x8_init_mmx)
void x264_predict_8x8_init_mmx  ( uint32_t cpu, x264_predict8x8_t pf[12], x264_predict_8x8_filter_t *predict_8x8_filter );

#define x264_predict_16x16_v_mmx2 x264_template(predict_16x16_v_mmx2)
void x264_predict_16x16_v_mmx2( pixel *src );
#define x264_predict_16x16_v_sse x264_template(predict_16x16_v_sse)
void x264_predict_16x16_v_sse ( pixel *src );
#define x264_predict_16x16_v_avx x264_template(predict_16x16_v_avx)
void x264_predict_16x16_v_avx ( uint16_t *src );
#define x264_predict_16x16_h_mmx2 x264_template(predict_16x16_h_mmx2)
void x264_predict_16x16_h_mmx2( pixel *src );
#define x264_predict_16x16_h_sse2 x264_template(predict_16x16_h_sse2)
void x264_predict_16x16_h_sse2( uint16_t *src );
#define x264_predict_16x16_h_ssse3 x264_template(predict_16x16_h_ssse3)
void x264_predict_16x16_h_ssse3( uint8_t *src );
#define x264_predict_16x16_h_avx2 x264_template(predict_16x16_h_avx2)
void x264_predict_16x16_h_avx2( uint16_t *src );
#define x264_predict_16x16_dc_sse2 x264_template(predict_16x16_dc_sse2)
void x264_predict_16x16_dc_sse2( pixel *src );
#define x264_predict_16x16_dc_avx2 x264_template(predict_16x16_dc_avx2)
void x264_predict_16x16_dc_avx2( pixel *src );
#define x264_predict_16x16_dc_left_sse2 x264_template(predict_16x16_dc_left_sse2)
void x264_predict_16x16_dc_left_sse2( pixel *src );
#define x264_predict_16x16_dc_left_avx2 x264_template(predict_16x16_dc_left_avx2)
void x264_predict_16x16_dc_left_avx2( pixel *src );
#define x264_predict_16x16_dc_top_sse2 x264_template(predict_16x16_dc_top_sse2)
void x264_predict_16x16_dc_top_sse2( pixel *src );
#define x264_predict_16x16_dc_top_avx2 x264_template(predict_16x16_dc_top_avx2)
void x264_predict_16x16_dc_top_avx2( pixel *src );
#define x264_predict_16x16_p_core_mmx2 x264_template(predict_16x16_p_core_mmx2)
void x264_predict_16x16_p_core_mmx2( uint8_t *src, int i00, int b, int c );
#define x264_predict_16x16_p_core_sse2 x264_template(predict_16x16_p_core_sse2)
void x264_predict_16x16_p_core_sse2( pixel *src, int i00, int b, int c );
#define x264_predict_16x16_p_core_avx x264_template(predict_16x16_p_core_avx)
void x264_predict_16x16_p_core_avx( pixel *src, int i00, int b, int c );
#define x264_predict_16x16_p_core_avx2 x264_template(predict_16x16_p_core_avx2)
void x264_predict_16x16_p_core_avx2( pixel *src, int i00, int b, int c );
#define x264_predict_8x16c_dc_mmx2 x264_template(predict_8x16c_dc_mmx2)
void x264_predict_8x16c_dc_mmx2( pixel *src );
#define x264_predict_8x16c_dc_sse2 x264_template(predict_8x16c_dc_sse2)
void x264_predict_8x16c_dc_sse2( uint16_t *src );
#define x264_predict_8x16c_dc_top_mmx2 x264_template(predict_8x16c_dc_top_mmx2)
void x264_predict_8x16c_dc_top_mmx2( uint8_t *src );
#define x264_predict_8x16c_dc_top_sse2 x264_template(predict_8x16c_dc_top_sse2)
void x264_predict_8x16c_dc_top_sse2( uint16_t *src );
#define x264_predict_8x16c_v_mmx x264_template(predict_8x16c_v_mmx)
void x264_predict_8x16c_v_mmx( uint8_t *src );
#define x264_predict_8x16c_v_sse x264_template(predict_8x16c_v_sse)
void x264_predict_8x16c_v_sse( uint16_t *src );
#define x264_predict_8x16c_h_mmx2 x264_template(predict_8x16c_h_mmx2)
void x264_predict_8x16c_h_mmx2( pixel *src );
#define x264_predict_8x16c_h_sse2 x264_template(predict_8x16c_h_sse2)
void x264_predict_8x16c_h_sse2( uint16_t *src );
#define x264_predict_8x16c_h_ssse3 x264_template(predict_8x16c_h_ssse3)
void x264_predict_8x16c_h_ssse3( uint8_t *src );
#define x264_predict_8x16c_h_avx2 x264_template(predict_8x16c_h_avx2)
void x264_predict_8x16c_h_avx2( uint16_t *src );
#define x264_predict_8x16c_p_core_mmx2 x264_template(predict_8x16c_p_core_mmx2)
void x264_predict_8x16c_p_core_mmx2( uint8_t *src, int i00, int b, int c );
#define x264_predict_8x16c_p_core_sse2 x264_template(predict_8x16c_p_core_sse2)
void x264_predict_8x16c_p_core_sse2( pixel *src, int i00, int b, int c );
#define x264_predict_8x16c_p_core_avx x264_template(predict_8x16c_p_core_avx)
void x264_predict_8x16c_p_core_avx ( pixel *src, int i00, int b, int c );
#define x264_predict_8x16c_p_core_avx2 x264_template(predict_8x16c_p_core_avx2)
void x264_predict_8x16c_p_core_avx2( pixel *src, int i00, int b, int c );
#define x264_predict_8x8c_p_core_mmx2 x264_template(predict_8x8c_p_core_mmx2)
void x264_predict_8x8c_p_core_mmx2( uint8_t *src, int i00, int b, int c );
#define x264_predict_8x8c_p_core_sse2 x264_template(predict_8x8c_p_core_sse2)
void x264_predict_8x8c_p_core_sse2( pixel *src, int i00, int b, int c );
#define x264_predict_8x8c_p_core_avx x264_template(predict_8x8c_p_core_avx)
void x264_predict_8x8c_p_core_avx ( pixel *src, int i00, int b, int c );
#define x264_predict_8x8c_p_core_avx2 x264_template(predict_8x8c_p_core_avx2)
void x264_predict_8x8c_p_core_avx2( pixel *src, int i00, int b, int c );
#define x264_predict_8x8c_dc_mmx2 x264_template(predict_8x8c_dc_mmx2)
void x264_predict_8x8c_dc_mmx2( pixel *src );
#define x264_predict_8x8c_dc_sse2 x264_template(predict_8x8c_dc_sse2)
void x264_predict_8x8c_dc_sse2( uint16_t *src );
#define x264_predict_8x8c_dc_top_mmx2 x264_template(predict_8x8c_dc_top_mmx2)
void x264_predict_8x8c_dc_top_mmx2( uint8_t *src );
#define x264_predict_8x8c_dc_top_sse2 x264_template(predict_8x8c_dc_top_sse2)
void x264_predict_8x8c_dc_top_sse2( uint16_t *src );
#define x264_predict_8x8c_v_mmx x264_template(predict_8x8c_v_mmx)
void x264_predict_8x8c_v_mmx( pixel *src );
#define x264_predict_8x8c_v_sse x264_template(predict_8x8c_v_sse)
void x264_predict_8x8c_v_sse( uint16_t *src );
#define x264_predict_8x8c_h_mmx2 x264_template(predict_8x8c_h_mmx2)
void x264_predict_8x8c_h_mmx2( pixel *src );
#define x264_predict_8x8c_h_sse2 x264_template(predict_8x8c_h_sse2)
void x264_predict_8x8c_h_sse2( uint16_t *src );
#define x264_predict_8x8c_h_ssse3 x264_template(predict_8x8c_h_ssse3)
void x264_predict_8x8c_h_ssse3( uint8_t *src );
#define x264_predict_8x8c_h_avx2 x264_template(predict_8x8c_h_avx2)
void x264_predict_8x8c_h_avx2( uint16_t *src );
#define x264_predict_8x8_v_mmx2 x264_template(predict_8x8_v_mmx2)
void x264_predict_8x8_v_mmx2( uint8_t *src, uint8_t edge[36] );
#define x264_predict_8x8_v_sse x264_template(predict_8x8_v_sse)
void x264_predict_8x8_v_sse ( uint16_t *src, uint16_t edge[36] );
#define x264_predict_8x8_h_mmx2 x264_template(predict_8x8_h_mmx2)
void x264_predict_8x8_h_mmx2( uint8_t *src, uint8_t edge[36] );
#define x264_predict_8x8_h_sse2 x264_template(predict_8x8_h_sse2)
void x264_predict_8x8_h_sse2( uint16_t *src, uint16_t edge[36] );
#define x264_predict_8x8_hd_mmx2 x264_template(predict_8x8_hd_mmx2)
void x264_predict_8x8_hd_mmx2( uint8_t *src, uint8_t edge[36] );
#define x264_predict_8x8_hu_mmx2 x264_template(predict_8x8_hu_mmx2)
void x264_predict_8x8_hu_mmx2( uint8_t *src, uint8_t edge[36] );
#define x264_predict_8x8_dc_mmx2 x264_template(predict_8x8_dc_mmx2)
void x264_predict_8x8_dc_mmx2( uint8_t *src, uint8_t edge[36] );
#define x264_predict_8x8_dc_sse2 x264_template(predict_8x8_dc_sse2)
void x264_predict_8x8_dc_sse2( uint16_t *src, uint16_t edge[36] );
#define x264_predict_8x8_dc_top_mmx2 x264_template(predict_8x8_dc_top_mmx2)
void x264_predict_8x8_dc_top_mmx2( uint8_t *src, uint8_t edge[36] );
#define x264_predict_8x8_dc_top_sse2 x264_template(predict_8x8_dc_top_sse2)
void x264_predict_8x8_dc_top_sse2( uint16_t *src, uint16_t edge[36] );
#define x264_predict_8x8_dc_left_mmx2 x264_template(predict_8x8_dc_left_mmx2)
void x264_predict_8x8_dc_left_mmx2( uint8_t *src, uint8_t edge[36] );
#define x264_predict_8x8_dc_left_sse2 x264_template(predict_8x8_dc_left_sse2)
void x264_predict_8x8_dc_left_sse2( uint16_t *src, uint16_t edge[36] );
#define x264_predict_8x8_ddl_mmx2 x264_template(predict_8x8_ddl_mmx2)
void x264_predict_8x8_ddl_mmx2( uint8_t *src, uint8_t edge[36] );
#define x264_predict_8x8_ddl_sse2 x264_template(predict_8x8_ddl_sse2)
void x264_predict_8x8_ddl_sse2( pixel *src, pixel edge[36] );
#define x264_predict_8x8_ddl_ssse3 x264_template(predict_8x8_ddl_ssse3)
void x264_predict_8x8_ddl_ssse3( pixel *src, pixel edge[36] );
#define x264_predict_8x8_ddl_cache64_ssse3 x264_template(predict_8x8_ddl_cache64_ssse3)
void x264_predict_8x8_ddl_cache64_ssse3( pixel *src, pixel edge[36] );
#define x264_predict_8x8_ddl_avx x264_template(predict_8x8_ddl_avx)
void x264_predict_8x8_ddl_avx( pixel *src, pixel edge[36] );
#define x264_predict_8x8_ddr_mmx2 x264_template(predict_8x8_ddr_mmx2)
void x264_predict_8x8_ddr_mmx2( uint8_t *src, uint8_t edge[36] );
#define x264_predict_8x8_ddr_sse2 x264_template(predict_8x8_ddr_sse2)
void x264_predict_8x8_ddr_sse2( pixel *src, pixel edge[36] );
#define x264_predict_8x8_ddr_ssse3 x264_template(predict_8x8_ddr_ssse3)
void x264_predict_8x8_ddr_ssse3( pixel *src, pixel edge[36] );
#define x264_predict_8x8_ddr_cache64_ssse3 x264_template(predict_8x8_ddr_cache64_ssse3)
void x264_predict_8x8_ddr_cache64_ssse3( pixel *src, pixel edge[36] );
#define x264_predict_8x8_ddr_avx x264_template(predict_8x8_ddr_avx)
void x264_predict_8x8_ddr_avx( pixel *src, pixel edge[36] );
#define x264_predict_8x8_vl_sse2 x264_template(predict_8x8_vl_sse2)
void x264_predict_8x8_vl_sse2( pixel *src, pixel edge[36] );
#define x264_predict_8x8_vl_ssse3 x264_template(predict_8x8_vl_ssse3)
void x264_predict_8x8_vl_ssse3( pixel *src, pixel edge[36] );
#define x264_predict_8x8_vl_avx x264_template(predict_8x8_vl_avx)
void x264_predict_8x8_vl_avx( pixel *src, pixel edge[36] );
#define x264_predict_8x8_vl_mmx2 x264_template(predict_8x8_vl_mmx2)
void x264_predict_8x8_vl_mmx2( uint8_t *src, uint8_t edge[36] );
#define x264_predict_8x8_vr_mmx2 x264_template(predict_8x8_vr_mmx2)
void x264_predict_8x8_vr_mmx2( uint8_t *src, uint8_t edge[36] );
#define x264_predict_8x8_vr_sse2 x264_template(predict_8x8_vr_sse2)
void x264_predict_8x8_vr_sse2( pixel *src, pixel edge[36] );
#define x264_predict_8x8_vr_ssse3 x264_template(predict_8x8_vr_ssse3)
void x264_predict_8x8_vr_ssse3( pixel *src, pixel edge[36] );
#define x264_predict_8x8_vr_avx x264_template(predict_8x8_vr_avx)
void x264_predict_8x8_vr_avx( pixel *src, pixel edge[36] );
#define x264_predict_8x8_hu_sse2 x264_template(predict_8x8_hu_sse2)
void x264_predict_8x8_hu_sse2( pixel *src, pixel edge[36] );
#define x264_predict_8x8_hu_ssse3 x264_template(predict_8x8_hu_ssse3)
void x264_predict_8x8_hu_ssse3( pixel *src, pixel edge[36] );
#define x264_predict_8x8_hu_avx x264_template(predict_8x8_hu_avx)
void x264_predict_8x8_hu_avx( pixel *src, pixel edge[36] );
#define x264_predict_8x8_hd_sse2 x264_template(predict_8x8_hd_sse2)
void x264_predict_8x8_hd_sse2( pixel *src, pixel edge[36] );
#define x264_predict_8x8_hd_ssse3 x264_template(predict_8x8_hd_ssse3)
void x264_predict_8x8_hd_ssse3( pixel *src, pixel edge[36] );
#define x264_predict_8x8_hd_avx x264_template(predict_8x8_hd_avx)
void x264_predict_8x8_hd_avx( pixel *src, pixel edge[36] );
#define x264_predict_8x8_filter_mmx2 x264_template(predict_8x8_filter_mmx2)
void x264_predict_8x8_filter_mmx2( uint8_t *src, uint8_t edge[36], int i_neighbor, int i_filters );
#define x264_predict_8x8_filter_sse2 x264_template(predict_8x8_filter_sse2)
void x264_predict_8x8_filter_sse2( uint16_t *src, uint16_t edge[36], int i_neighbor, int i_filters );
#define x264_predict_8x8_filter_ssse3 x264_template(predict_8x8_filter_ssse3)
void x264_predict_8x8_filter_ssse3( pixel *src, pixel edge[36], int i_neighbor, int i_filters );
#define x264_predict_8x8_filter_avx x264_template(predict_8x8_filter_avx)
void x264_predict_8x8_filter_avx( uint16_t *src, uint16_t edge[36], int i_neighbor, int i_filters );
#define x264_predict_4x4_h_avx2 x264_template(predict_4x4_h_avx2)
void x264_predict_4x4_h_avx2( uint16_t *src );
#define x264_predict_4x4_ddl_mmx2 x264_template(predict_4x4_ddl_mmx2)
void x264_predict_4x4_ddl_mmx2( pixel *src );
#define x264_predict_4x4_ddl_sse2 x264_template(predict_4x4_ddl_sse2)
void x264_predict_4x4_ddl_sse2( uint16_t *src );
#define x264_predict_4x4_ddl_avx x264_template(predict_4x4_ddl_avx)
void x264_predict_4x4_ddl_avx( uint16_t *src );
#define x264_predict_4x4_ddr_mmx2 x264_template(predict_4x4_ddr_mmx2)
void x264_predict_4x4_ddr_mmx2( pixel *src );
#define x264_predict_4x4_vl_mmx2 x264_template(predict_4x4_vl_mmx2)
void x264_predict_4x4_vl_mmx2( pixel *src );
#define x264_predict_4x4_vl_sse2 x264_template(predict_4x4_vl_sse2)
void x264_predict_4x4_vl_sse2( uint16_t *src );
#define x264_predict_4x4_vl_avx x264_template(predict_4x4_vl_avx)
void x264_predict_4x4_vl_avx( uint16_t *src );
#define x264_predict_4x4_vr_mmx2 x264_template(predict_4x4_vr_mmx2)
void x264_predict_4x4_vr_mmx2( uint8_t *src );
#define x264_predict_4x4_vr_sse2 x264_template(predict_4x4_vr_sse2)
void x264_predict_4x4_vr_sse2( uint16_t *src );
#define x264_predict_4x4_vr_ssse3 x264_template(predict_4x4_vr_ssse3)
void x264_predict_4x4_vr_ssse3( pixel *src );
#define x264_predict_4x4_vr_cache64_ssse3 x264_template(predict_4x4_vr_cache64_ssse3)
void x264_predict_4x4_vr_cache64_ssse3( uint8_t *src );
#define x264_predict_4x4_vr_avx x264_template(predict_4x4_vr_avx)
void x264_predict_4x4_vr_avx( uint16_t *src );
#define x264_predict_4x4_hd_mmx2 x264_template(predict_4x4_hd_mmx2)
void x264_predict_4x4_hd_mmx2( pixel *src );
#define x264_predict_4x4_hd_sse2 x264_template(predict_4x4_hd_sse2)
void x264_predict_4x4_hd_sse2( uint16_t *src );
#define x264_predict_4x4_hd_ssse3 x264_template(predict_4x4_hd_ssse3)
void x264_predict_4x4_hd_ssse3( pixel *src );
#define x264_predict_4x4_hd_avx x264_template(predict_4x4_hd_avx)
void x264_predict_4x4_hd_avx( uint16_t *src );
#define x264_predict_4x4_dc_mmx2 x264_template(predict_4x4_dc_mmx2)
void x264_predict_4x4_dc_mmx2( pixel *src );
#define x264_predict_4x4_ddr_sse2 x264_template(predict_4x4_ddr_sse2)
void x264_predict_4x4_ddr_sse2( uint16_t *src );
#define x264_predict_4x4_ddr_ssse3 x264_template(predict_4x4_ddr_ssse3)
void x264_predict_4x4_ddr_ssse3( pixel *src );
#define x264_predict_4x4_ddr_avx x264_template(predict_4x4_ddr_avx)
void x264_predict_4x4_ddr_avx( uint16_t *src );
#define x264_predict_4x4_hu_mmx2 x264_template(predict_4x4_hu_mmx2)
void x264_predict_4x4_hu_mmx2( pixel *src );

#endif
