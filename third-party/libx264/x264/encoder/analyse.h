/*****************************************************************************
 * analyse.h: macroblock analysis
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

#ifndef X264_ENCODER_ANALYSE_H
#define X264_ENCODER_ANALYSE_H

#define x264_analyse_init_costs x264_template(analyse_init_costs)
int x264_analyse_init_costs( x264_t *h );
#define x264_analyse_free_costs x264_template(analyse_free_costs)
void x264_analyse_free_costs( x264_t *h );
#define x264_analyse_weight_frame x264_template(analyse_weight_frame)
void x264_analyse_weight_frame( x264_t *h, int end );
#define x264_macroblock_analyse x264_template(macroblock_analyse)
void x264_macroblock_analyse( x264_t *h );
#define x264_slicetype_decide x264_template(slicetype_decide)
void x264_slicetype_decide( x264_t *h );

#define x264_slicetype_analyse x264_template(slicetype_analyse)
void x264_slicetype_analyse( x264_t *h, int intra_minigop );

#define x264_lookahead_init x264_template(lookahead_init)
int  x264_lookahead_init( x264_t *h, int i_slicetype_length );
#define x264_lookahead_is_empty x264_template(lookahead_is_empty)
int  x264_lookahead_is_empty( x264_t *h );
#define x264_lookahead_put_frame x264_template(lookahead_put_frame)
void x264_lookahead_put_frame( x264_t *h, x264_frame_t *frame );
#define x264_lookahead_get_frames x264_template(lookahead_get_frames)
void x264_lookahead_get_frames( x264_t *h );
#define x264_lookahead_delete x264_template(lookahead_delete)
void x264_lookahead_delete( x264_t *h );

#endif
