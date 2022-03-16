/*****************************************************************************
 * slicetype-cl.h: OpenCL slicetype decision code (lowres lookahead)
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

#ifndef X264_ENCODER_SLICETYPE_CL_H
#define X264_ENCODER_SLICETYPE_CL_H

#define x264_opencl_lowres_init x264_template(opencl_lowres_init)
int x264_opencl_lowres_init( x264_t *h, x264_frame_t *fenc, int lambda );
#define x264_opencl_motionsearch x264_template(opencl_motionsearch)
int x264_opencl_motionsearch( x264_t *h, x264_frame_t **frames, int b, int ref, int b_islist1, int lambda, const x264_weight_t *w );
#define x264_opencl_finalize_cost x264_template(opencl_finalize_cost)
int x264_opencl_finalize_cost( x264_t *h, int lambda, x264_frame_t **frames, int p0, int p1, int b, int dist_scale_factor );
#define x264_opencl_precalculate_frame_cost x264_template(opencl_precalculate_frame_cost)
int x264_opencl_precalculate_frame_cost( x264_t *h, x264_frame_t **frames, int lambda, int p0, int p1, int b );
#define x264_opencl_flush x264_template(opencl_flush)
void x264_opencl_flush( x264_t *h );
#define x264_opencl_slicetype_prep x264_template(opencl_slicetype_prep)
void x264_opencl_slicetype_prep( x264_t *h, x264_frame_t **frames, int num_frames, int lambda );
#define x264_opencl_slicetype_end x264_template(opencl_slicetype_end)
void x264_opencl_slicetype_end( x264_t *h );

#endif
