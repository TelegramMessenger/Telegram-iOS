/*****************************************************************************
 * predict.h: arm intra prediction
 *****************************************************************************
 * Copyright (C) 2009-2022 x264 project
 *
 * Authors: David Conrad <lessen42@gmail.com>
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

#ifndef X264_ARM_PREDICT_H
#define X264_ARM_PREDICT_H

#define x264_predict_4x4_dc_armv6 x264_template(predict_4x4_dc_armv6)
void x264_predict_4x4_dc_armv6( uint8_t *src );
#define x264_predict_4x4_dc_top_neon x264_template(predict_4x4_dc_top_neon)
void x264_predict_4x4_dc_top_neon( uint8_t *src );
#define x264_predict_4x4_v_armv6 x264_template(predict_4x4_v_armv6)
void x264_predict_4x4_v_armv6( uint8_t *src );
#define x264_predict_4x4_h_armv6 x264_template(predict_4x4_h_armv6)
void x264_predict_4x4_h_armv6( uint8_t *src );
#define x264_predict_4x4_ddr_armv6 x264_template(predict_4x4_ddr_armv6)
void x264_predict_4x4_ddr_armv6( uint8_t *src );
#define x264_predict_4x4_ddl_neon x264_template(predict_4x4_ddl_neon)
void x264_predict_4x4_ddl_neon( uint8_t *src );

#define x264_predict_8x8c_dc_neon x264_template(predict_8x8c_dc_neon)
void x264_predict_8x8c_dc_neon( uint8_t *src );
#define x264_predict_8x8c_dc_top_neon x264_template(predict_8x8c_dc_top_neon)
void x264_predict_8x8c_dc_top_neon( uint8_t *src );
#define x264_predict_8x8c_dc_left_neon x264_template(predict_8x8c_dc_left_neon)
void x264_predict_8x8c_dc_left_neon( uint8_t *src );
#define x264_predict_8x8c_h_neon x264_template(predict_8x8c_h_neon)
void x264_predict_8x8c_h_neon( uint8_t *src );
#define x264_predict_8x8c_v_neon x264_template(predict_8x8c_v_neon)
void x264_predict_8x8c_v_neon( uint8_t *src );
#define x264_predict_8x8c_p_neon x264_template(predict_8x8c_p_neon)
void x264_predict_8x8c_p_neon( uint8_t *src );

#define x264_predict_8x16c_h_neon x264_template(predict_8x16c_h_neon)
void x264_predict_8x16c_h_neon( uint8_t *src );
#define x264_predict_8x16c_dc_top_neon x264_template(predict_8x16c_dc_top_neon)
void x264_predict_8x16c_dc_top_neon( uint8_t *src );
#define x264_predict_8x16c_p_neon x264_template(predict_8x16c_p_neon)
void x264_predict_8x16c_p_neon( uint8_t *src );

#define x264_predict_8x8_dc_neon x264_template(predict_8x8_dc_neon)
void x264_predict_8x8_dc_neon( uint8_t *src, uint8_t edge[36] );
#define x264_predict_8x8_ddl_neon x264_template(predict_8x8_ddl_neon)
void x264_predict_8x8_ddl_neon( uint8_t *src, uint8_t edge[36] );
#define x264_predict_8x8_ddr_neon x264_template(predict_8x8_ddr_neon)
void x264_predict_8x8_ddr_neon( uint8_t *src, uint8_t edge[36] );
#define x264_predict_8x8_vl_neon x264_template(predict_8x8_vl_neon)
void x264_predict_8x8_vl_neon( uint8_t *src, uint8_t edge[36] );
#define x264_predict_8x8_vr_neon x264_template(predict_8x8_vr_neon)
void x264_predict_8x8_vr_neon( uint8_t *src, uint8_t edge[36] );
#define x264_predict_8x8_v_neon x264_template(predict_8x8_v_neon)
void x264_predict_8x8_v_neon( uint8_t *src, uint8_t edge[36] );
#define x264_predict_8x8_h_neon x264_template(predict_8x8_h_neon)
void x264_predict_8x8_h_neon( uint8_t *src, uint8_t edge[36] );
#define x264_predict_8x8_hd_neon x264_template(predict_8x8_hd_neon)
void x264_predict_8x8_hd_neon( uint8_t *src, uint8_t edge[36] );
#define x264_predict_8x8_hu_neon x264_template(predict_8x8_hu_neon)
void x264_predict_8x8_hu_neon( uint8_t *src, uint8_t edge[36] );

#define x264_predict_16x16_dc_neon x264_template(predict_16x16_dc_neon)
void x264_predict_16x16_dc_neon( uint8_t *src );
#define x264_predict_16x16_dc_top_neon x264_template(predict_16x16_dc_top_neon)
void x264_predict_16x16_dc_top_neon( uint8_t *src );
#define x264_predict_16x16_dc_left_neon x264_template(predict_16x16_dc_left_neon)
void x264_predict_16x16_dc_left_neon( uint8_t *src );
#define x264_predict_16x16_h_neon x264_template(predict_16x16_h_neon)
void x264_predict_16x16_h_neon( uint8_t *src );
#define x264_predict_16x16_v_neon x264_template(predict_16x16_v_neon)
void x264_predict_16x16_v_neon( uint8_t *src );
#define x264_predict_16x16_p_neon x264_template(predict_16x16_p_neon)
void x264_predict_16x16_p_neon( uint8_t *src );

#define x264_predict_4x4_init_arm x264_template(predict_4x4_init_arm)
void x264_predict_4x4_init_arm( uint32_t cpu, x264_predict_t pf[12] );
#define x264_predict_8x8_init_arm x264_template(predict_8x8_init_arm)
void x264_predict_8x8_init_arm( uint32_t cpu, x264_predict8x8_t pf[12], x264_predict_8x8_filter_t *predict_filter );
#define x264_predict_8x8c_init_arm x264_template(predict_8x8c_init_arm)
void x264_predict_8x8c_init_arm( uint32_t cpu, x264_predict_t pf[7] );
#define x264_predict_8x16c_init_arm x264_template(predict_8x16c_init_arm)
void x264_predict_8x16c_init_arm( uint32_t cpu, x264_predict_t pf[7] );
#define x264_predict_16x16_init_arm x264_template(predict_16x16_init_arm)
void x264_predict_16x16_init_arm( uint32_t cpu, x264_predict_t pf[7] );

#endif
