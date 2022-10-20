/*****************************************************************************
 * ratecontrol.h: ratecontrol
 *****************************************************************************
 * Copyright (C) 2003-2022 x264 project
 *
 * Authors: Loren Merritt <lorenm@u.washington.edu>
 *          Laurent Aimar <fenrir@via.ecp.fr>
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

#ifndef X264_ENCODER_RATECONTROL_H
#define X264_ENCODER_RATECONTROL_H

/* Completely arbitrary.  Ratecontrol lowers relative quality at higher framerates
 * and the reverse at lower framerates; this serves as the center of the curve.
 * Halve all the values for frame-packed 3D to compensate for the "doubled"
 * framerate. */
#define BASE_FRAME_DURATION (0.04f / ((h->param.i_frame_packing == 5)+1))

/* Arbitrary limitations as a sanity check. */
#define MAX_FRAME_DURATION (1.00f / ((h->param.i_frame_packing == 5)+1))
#define MIN_FRAME_DURATION (0.01f / ((h->param.i_frame_packing == 5)+1))

#define CLIP_DURATION(f) x264_clip3f(f,MIN_FRAME_DURATION,MAX_FRAME_DURATION)

#define x264_ratecontrol_new x264_template(ratecontrol_new)
int  x264_ratecontrol_new   ( x264_t * );
#define x264_ratecontrol_delete x264_template(ratecontrol_delete)
void x264_ratecontrol_delete( x264_t * );

#define x264_ratecontrol_init_reconfigurable x264_template(ratecontrol_init_reconfigurable)
void x264_ratecontrol_init_reconfigurable( x264_t *h, int b_init );
#define x264_encoder_reconfig_apply x264_template(encoder_reconfig_apply)
int x264_encoder_reconfig_apply( x264_t *h, x264_param_t *param );

#define x264_adaptive_quant_frame x264_template(adaptive_quant_frame)
void x264_adaptive_quant_frame( x264_t *h, x264_frame_t *frame, float *quant_offsets );
#define x264_macroblock_tree_read x264_template(macroblock_tree_read)
int  x264_macroblock_tree_read( x264_t *h, x264_frame_t *frame, float *quant_offsets );
#define x264_reference_build_list_optimal x264_template(reference_build_list_optimal)
int  x264_reference_build_list_optimal( x264_t *h );
#define x264_thread_sync_ratecontrol x264_template(thread_sync_ratecontrol)
void x264_thread_sync_ratecontrol( x264_t *cur, x264_t *prev, x264_t *next );
#define x264_ratecontrol_zone_init x264_template(ratecontrol_zone_init)
void x264_ratecontrol_zone_init( x264_t * );
#define x264_ratecontrol_start x264_template(ratecontrol_start)
void x264_ratecontrol_start( x264_t *, int i_force_qp, int overhead );
#define x264_ratecontrol_slice_type x264_template(ratecontrol_slice_type)
int  x264_ratecontrol_slice_type( x264_t *, int i_frame );
#define x264_ratecontrol_set_weights x264_template(ratecontrol_set_weights)
void x264_ratecontrol_set_weights( x264_t *h, x264_frame_t *frm );
#define x264_ratecontrol_mb x264_template(ratecontrol_mb)
int  x264_ratecontrol_mb( x264_t *, int bits );
#define x264_ratecontrol_qp x264_template(ratecontrol_qp)
int  x264_ratecontrol_qp( x264_t * );
#define x264_ratecontrol_mb_qp x264_template(ratecontrol_mb_qp)
int  x264_ratecontrol_mb_qp( x264_t *h );
#define x264_ratecontrol_end x264_template(ratecontrol_end)
int  x264_ratecontrol_end( x264_t *, int bits, int *filler );
#define x264_ratecontrol_summary x264_template(ratecontrol_summary)
void x264_ratecontrol_summary( x264_t * );
#define x264_rc_analyse_slice x264_template(rc_analyse_slice)
int  x264_rc_analyse_slice( x264_t *h );
#define x264_threads_distribute_ratecontrol x264_template(threads_distribute_ratecontrol)
void x264_threads_distribute_ratecontrol( x264_t *h );
#define x264_threads_merge_ratecontrol x264_template(threads_merge_ratecontrol)
void x264_threads_merge_ratecontrol( x264_t *h );
#define x264_hrd_fullness x264_template(hrd_fullness)
void x264_hrd_fullness( x264_t *h );

#endif
