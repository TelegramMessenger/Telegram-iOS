/*****************************************************************************
 * predict.c: arm intra prediction
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

#include "common/common.h"
#include "predict.h"
#include "pixel.h"

void x264_predict_4x4_init_arm( uint32_t cpu, x264_predict_t pf[12] )
{
    if( !(cpu&X264_CPU_ARMV6) )
        return;

#if !HIGH_BIT_DEPTH
    pf[I_PRED_4x4_H]   = x264_predict_4x4_h_armv6;
    pf[I_PRED_4x4_V]   = x264_predict_4x4_v_armv6;
    pf[I_PRED_4x4_DC]  = x264_predict_4x4_dc_armv6;
    pf[I_PRED_4x4_DDR] = x264_predict_4x4_ddr_armv6;

    if( !(cpu&X264_CPU_NEON) )
        return;

    pf[I_PRED_4x4_DC_TOP] = x264_predict_4x4_dc_top_neon;
    pf[I_PRED_4x4_DDL] = x264_predict_4x4_ddl_neon;
#endif // !HIGH_BIT_DEPTH
}

void x264_predict_8x8c_init_arm( uint32_t cpu, x264_predict_t pf[7] )
{
    if( !(cpu&X264_CPU_NEON) )
        return;

#if !HIGH_BIT_DEPTH
    pf[I_PRED_CHROMA_DC]      = x264_predict_8x8c_dc_neon;
    pf[I_PRED_CHROMA_DC_TOP]  = x264_predict_8x8c_dc_top_neon;
    pf[I_PRED_CHROMA_DC_LEFT] = x264_predict_8x8c_dc_left_neon;
    pf[I_PRED_CHROMA_H] = x264_predict_8x8c_h_neon;
    pf[I_PRED_CHROMA_V] = x264_predict_8x8c_v_neon;
    pf[I_PRED_CHROMA_P] = x264_predict_8x8c_p_neon;
#endif // !HIGH_BIT_DEPTH
}

void x264_predict_8x16c_init_arm( uint32_t cpu, x264_predict_t pf[7] )
{
    if( !(cpu&X264_CPU_NEON) )
        return;

#if !HIGH_BIT_DEPTH
    /* The other functions weren't faster than C (gcc 4.7.3) on Cortex A8 and A9. */
    pf[I_PRED_CHROMA_DC_TOP]  = x264_predict_8x16c_dc_top_neon;
    pf[I_PRED_CHROMA_H]       = x264_predict_8x16c_h_neon;
    pf[I_PRED_CHROMA_P]       = x264_predict_8x16c_p_neon;
#endif // !HIGH_BIT_DEPTH
}

void x264_predict_8x8_init_arm( uint32_t cpu, x264_predict8x8_t pf[12], x264_predict_8x8_filter_t *predict_filter )
{
    if( !(cpu&X264_CPU_NEON) )
        return;

#if !HIGH_BIT_DEPTH
    pf[I_PRED_8x8_DDL] = x264_predict_8x8_ddl_neon;
    pf[I_PRED_8x8_DDR] = x264_predict_8x8_ddr_neon;
    pf[I_PRED_8x8_VL]  = x264_predict_8x8_vl_neon;
    pf[I_PRED_8x8_VR]  = x264_predict_8x8_vr_neon;
    pf[I_PRED_8x8_DC]  = x264_predict_8x8_dc_neon;
    pf[I_PRED_8x8_H]   = x264_predict_8x8_h_neon;
    pf[I_PRED_8x8_HD]  = x264_predict_8x8_hd_neon;
    pf[I_PRED_8x8_HU]  = x264_predict_8x8_hu_neon;
    pf[I_PRED_8x8_V]   = x264_predict_8x8_v_neon;
#endif // !HIGH_BIT_DEPTH
}

void x264_predict_16x16_init_arm( uint32_t cpu, x264_predict_t pf[7] )
{
    if( !(cpu&X264_CPU_NEON) )
        return;

#if !HIGH_BIT_DEPTH
    pf[I_PRED_16x16_DC ]    = x264_predict_16x16_dc_neon;
    pf[I_PRED_16x16_DC_TOP] = x264_predict_16x16_dc_top_neon;
    pf[I_PRED_16x16_DC_LEFT]= x264_predict_16x16_dc_left_neon;
    pf[I_PRED_16x16_H ]     = x264_predict_16x16_h_neon;
    pf[I_PRED_16x16_V ]     = x264_predict_16x16_v_neon;
    pf[I_PRED_16x16_P ]     = x264_predict_16x16_p_neon;
#endif // !HIGH_BIT_DEPTH
}
