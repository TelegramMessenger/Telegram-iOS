/*****************************************************************************
 * me.h: motion estimation
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

#ifndef X264_ENCODER_ME_H
#define X264_ENCODER_ME_H

#define COST_MAX (1<<28)
#define COST_MAX64 (1ULL<<60)

typedef struct
{
    /* aligning the first member is a gcc hack to force the struct to be aligned,
     * as well as force sizeof(struct) to be a multiple of the alignment. */
    /* input */
    ALIGNED_64( int i_pixel );   /* PIXEL_WxH */
    uint16_t *p_cost_mv; /* lambda * nbits for each possible mv */
    int      i_ref_cost;
    int      i_ref;
    const x264_weight_t *weight;

    pixel *p_fref[12];
    pixel *p_fref_w;
    pixel *p_fenc[3];
    uint16_t *integral;
    int      i_stride[3];

    ALIGNED_4( int16_t mvp[2] );

    /* output */
    int cost_mv;        /* lambda * nbits for the chosen mv */
    int cost;           /* satd + lambda * nbits */
    ALIGNED_8( int16_t mv[2] );
} ALIGNED_64( x264_me_t );

#define x264_me_search_ref x264_template(me_search_ref)
void x264_me_search_ref( x264_t *h, x264_me_t *m, int16_t (*mvc)[2], int i_mvc, int *p_fullpel_thresh );
#define x264_me_search( h, m, mvc, i_mvc )\
    x264_me_search_ref( h, m, mvc, i_mvc, NULL )

#define x264_me_refine_qpel x264_template(me_refine_qpel)
void x264_me_refine_qpel( x264_t *h, x264_me_t *m );
#define x264_me_refine_qpel_refdupe x264_template(me_refine_qpel_refdupe)
void x264_me_refine_qpel_refdupe( x264_t *h, x264_me_t *m, int *p_halfpel_thresh );
#define x264_me_refine_qpel_rd x264_template(me_refine_qpel_rd)
void x264_me_refine_qpel_rd( x264_t *h, x264_me_t *m, int i_lambda2, int i4, int i_list );
#define x264_me_refine_bidir_rd x264_template(me_refine_bidir_rd)
void x264_me_refine_bidir_rd( x264_t *h, x264_me_t *m0, x264_me_t *m1, int i_weight, int i8, int i_lambda2 );
#define x264_me_refine_bidir_satd x264_template(me_refine_bidir_satd)
void x264_me_refine_bidir_satd( x264_t *h, x264_me_t *m0, x264_me_t *m1, int i_weight );
#define x264_rd_cost_part x264_template(rd_cost_part)
uint64_t x264_rd_cost_part( x264_t *h, int i_lambda2, int i8, int i_pixel );

#define COPY1_IF_LT(x,y)\
if( (y) < (x) )\
    (x) = (y);

#define COPY2_IF_LT(x,y,a,b)\
if( (y) < (x) )\
{\
    (x) = (y);\
    (a) = (b);\
}

#define COPY3_IF_LT(x,y,a,b,c,d)\
if( (y) < (x) )\
{\
    (x) = (y);\
    (a) = (b);\
    (c) = (d);\
}

#define COPY4_IF_LT(x,y,a,b,c,d,e,f)\
if( (y) < (x) )\
{\
    (x) = (y);\
    (a) = (b);\
    (c) = (d);\
    (e) = (f);\
}

#define COPY2_IF_GT(x,y,a,b)\
if( (y) > (x) )\
{\
    (x) = (y);\
    (a) = (b);\
}

#endif
