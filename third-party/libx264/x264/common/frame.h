/*****************************************************************************
 * frame.h: frame handling
 *****************************************************************************
 * Copyright (C) 2003-2022 x264 project
 *
 * Authors: Laurent Aimar <fenrir@via.ecp.fr>
 *          Loren Merritt <lorenm@u.washington.edu>
 *          Fiona Glaser <fiona@x264.com>
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

#ifndef X264_FRAME_H
#define X264_FRAME_H

/* number of pixels past the edge of the frame, for motion estimation/compensation */
#define PADH 32
#define PADV 32
#define PADH_ALIGN X264_MAX( PADH, NATIVE_ALIGN / SIZEOF_PIXEL )
#define PADH2 (PADH_ALIGN + PADH)

typedef struct x264_frame
{
    /* */
    uint8_t *base;       /* Base pointer for all malloced data in this frame. */
    int     i_poc;
    int     i_delta_poc[2];
    int     i_type;
    int     i_forced_type;
    int     i_qpplus1;
    int64_t i_pts;
    int64_t i_dts;
    int64_t i_reordered_pts;
    int64_t i_duration;  /* in SPS time_scale units (i.e 2 * timebase units) used for vfr */
    float   f_duration;  /* in seconds */
    int64_t i_cpb_duration;
    int64_t i_cpb_delay; /* in SPS time_scale units (i.e 2 * timebase units) */
    int64_t i_dpb_output_delay;
    x264_param_t *param;

    int     i_frame;     /* Presentation frame number */
    int     i_coded;     /* Coded frame number */
    int64_t i_field_cnt; /* Presentation field count */
    int     i_frame_num; /* 7.4.3 frame_num */
    int     b_kept_as_ref;
    int     i_pic_struct;
    int     b_keyframe;
    uint8_t b_fdec;
    uint8_t b_last_minigop_bframe; /* this frame is the last b in a sequence of bframes */
    uint8_t i_bframes;   /* number of bframes following this nonb in coded order */
    float   f_qp_avg_rc; /* QPs as decided by ratecontrol */
    float   f_qp_avg_aq; /* QPs as decided by AQ in addition to ratecontrol */
    float   f_crf_avg;   /* Average effective CRF for this frame */
    int     i_poc_l0ref0; /* poc of first refframe in L0, used to check if direct temporal is possible */

    /* YUV buffer */
    int     i_csp; /* Internal csp */
    int     i_plane;
    int     i_stride[3];
    int     i_width[3];
    int     i_lines[3];
    int     i_stride_lowres;
    int     i_width_lowres;
    int     i_lines_lowres;
    pixel *plane[3];
    pixel *plane_fld[3];
    pixel *filtered[3][4]; /* plane[0], H, V, HV */
    pixel *filtered_fld[3][4];
    pixel *lowres[4]; /* half-size copy of input frame: Orig, H, V, HV */
    uint16_t *integral;

    /* for unrestricted mv we allocate more data than needed
     * allocated data are stored in buffer */
    pixel *buffer[4];
    pixel *buffer_fld[4];
    pixel *buffer_lowres;

    x264_weight_t weight[X264_REF_MAX][3]; /* [ref_index][plane] */
    pixel *weighted[X264_REF_MAX]; /* plane[0] weighted of the reference frames */
    int b_duplicate;
    struct x264_frame *orig;

    /* motion data */
    int8_t  *mb_type;
    uint8_t *mb_partition;
    int16_t (*mv[2])[2];
    int16_t (*mv16x16)[2];
    int16_t (*lowres_mvs[2][X264_BFRAME_MAX+1])[2];
    uint8_t *field;
    uint8_t *effective_qp;

    /* Stored as (lists_used << LOWRES_COST_SHIFT) + (cost).
     * Doesn't need special addressing for intra cost because
     * lists_used is guaranteed to be zero in that cast. */
    uint16_t (*lowres_costs[X264_BFRAME_MAX+2][X264_BFRAME_MAX+2]);
    #define LOWRES_COST_MASK ((1<<14)-1)
    #define LOWRES_COST_SHIFT 14

    int     *lowres_mv_costs[2][X264_BFRAME_MAX+1];
    int8_t  *ref[2];
    int     i_ref[2];
    int     ref_poc[2][X264_REF_MAX];
    int16_t inv_ref_poc[2]; // inverse values of ref0 poc to avoid divisions in temporal MV prediction

    /* for adaptive B-frame decision.
     * contains the SATD cost of the lowres frame encoded in various modes
     * FIXME: how big an array do we need? */
    int     i_cost_est[X264_BFRAME_MAX+2][X264_BFRAME_MAX+2];
    int     i_cost_est_aq[X264_BFRAME_MAX+2][X264_BFRAME_MAX+2];
    int     i_satd; // the i_cost_est of the selected frametype
    int     i_intra_mbs[X264_BFRAME_MAX+2];
    int     *i_row_satds[X264_BFRAME_MAX+2][X264_BFRAME_MAX+2];
    int     *i_row_satd;
    int     *i_row_bits;
    float   *f_row_qp;
    float   *f_row_qscale;
    float   *f_qp_offset;
    float   *f_qp_offset_aq;
    int     b_intra_calculated;
    uint16_t *i_intra_cost;
    uint16_t *i_propagate_cost;
    uint16_t *i_inv_qscale_factor;
    int     b_scenecut; /* Set to zero if the frame cannot possibly be part of a real scenecut. */
    float   f_weighted_cost_delta[X264_BFRAME_MAX+2];
    uint32_t i_pixel_sum[3];
    uint64_t i_pixel_ssd[3];

    /* hrd */
    x264_hrd_t hrd_timing;

    /* vbv */
    uint8_t i_planned_type[X264_LOOKAHEAD_MAX+1];
    int i_planned_satd[X264_LOOKAHEAD_MAX+1];
    double f_planned_cpb_duration[X264_LOOKAHEAD_MAX+1];
    int64_t i_coded_fields_lookahead;
    int64_t i_cpb_delay_lookahead;

    /* threading */
    int     i_lines_completed; /* in pixels */
    int     i_lines_weighted; /* FIXME: this only supports weighting of one reference frame */
    int     i_reference_count; /* number of threads using this frame (not necessarily the number of pointers) */
    x264_pthread_mutex_t mutex;
    x264_pthread_cond_t  cv;
    int     i_slice_count; /* Atomically written to/read from with slice threads */

    /* periodic intra refresh */
    float   f_pir_position;
    int     i_pir_start_col;
    int     i_pir_end_col;
    int     i_frames_since_pir;

    /* interactive encoder control */
    int     b_corrupt;

    /* user sei */
    x264_sei_t extra_sei;

    /* user data */
    void *opaque;

    /* user frame properties */
    uint8_t *mb_info;
    void (*mb_info_free)( void* );

#if HAVE_OPENCL
    x264_frame_opencl_t opencl;
#endif
} x264_frame_t;

/* synchronized frame list */
typedef struct
{
   x264_frame_t **list;
   int i_max_size;
   int i_size;
   x264_pthread_mutex_t     mutex;
   x264_pthread_cond_t      cv_fill;  /* event signaling that the list became fuller */
   x264_pthread_cond_t      cv_empty; /* event signaling that the list became emptier */
} x264_sync_frame_list_t;

typedef void (*x264_deblock_inter_t)( pixel *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 );
typedef void (*x264_deblock_intra_t)( pixel *pix, intptr_t stride, int alpha, int beta );
typedef struct
{
    x264_deblock_inter_t deblock_luma[2];
    x264_deblock_inter_t deblock_chroma[2];
    x264_deblock_inter_t deblock_h_chroma_420;
    x264_deblock_inter_t deblock_h_chroma_422;
    x264_deblock_intra_t deblock_luma_intra[2];
    x264_deblock_intra_t deblock_chroma_intra[2];
    x264_deblock_intra_t deblock_h_chroma_420_intra;
    x264_deblock_intra_t deblock_h_chroma_422_intra;
    x264_deblock_inter_t deblock_luma_mbaff;
    x264_deblock_inter_t deblock_chroma_mbaff;
    x264_deblock_inter_t deblock_chroma_420_mbaff;
    x264_deblock_inter_t deblock_chroma_422_mbaff;
    x264_deblock_intra_t deblock_luma_intra_mbaff;
    x264_deblock_intra_t deblock_chroma_intra_mbaff;
    x264_deblock_intra_t deblock_chroma_420_intra_mbaff;
    x264_deblock_intra_t deblock_chroma_422_intra_mbaff;
    void (*deblock_strength)( uint8_t nnz[X264_SCAN8_SIZE], int8_t ref[2][X264_SCAN8_LUMA_SIZE],
                              int16_t mv[2][X264_SCAN8_LUMA_SIZE][2], uint8_t bs[2][8][4], int mvy_limit,
                              int bframe );
} x264_deblock_function_t;

#define x264_frame_delete x264_template(frame_delete)
void          x264_frame_delete( x264_frame_t *frame );

#define x264_frame_copy_picture x264_template(frame_copy_picture)
int           x264_frame_copy_picture( x264_t *h, x264_frame_t *dst, x264_picture_t *src );

#define x264_frame_expand_border x264_template(frame_expand_border)
void          x264_frame_expand_border( x264_t *h, x264_frame_t *frame, int mb_y );
#define x264_frame_expand_border_filtered x264_template(frame_expand_border_filtered)
void          x264_frame_expand_border_filtered( x264_t *h, x264_frame_t *frame, int mb_y, int b_end );
#define x264_frame_expand_border_lowres x264_template(frame_expand_border_lowres)
void          x264_frame_expand_border_lowres( x264_frame_t *frame );
#define x264_frame_expand_border_chroma x264_template(frame_expand_border_chroma)
void          x264_frame_expand_border_chroma( x264_t *h, x264_frame_t *frame, int plane );
#define x264_frame_expand_border_mod16 x264_template(frame_expand_border_mod16)
void          x264_frame_expand_border_mod16( x264_t *h, x264_frame_t *frame );
#define x264_expand_border_mbpair x264_template(expand_border_mbpair)
void          x264_expand_border_mbpair( x264_t *h, int mb_x, int mb_y );

#define x264_frame_deblock_row x264_template(frame_deblock_row)
void          x264_frame_deblock_row( x264_t *h, int mb_y );
#define x264_macroblock_deblock x264_template(macroblock_deblock)
void          x264_macroblock_deblock( x264_t *h );

#define x264_frame_filter x264_template(frame_filter)
void          x264_frame_filter( x264_t *h, x264_frame_t *frame, int mb_y, int b_end );
#define x264_frame_init_lowres x264_template(frame_init_lowres)
void          x264_frame_init_lowres( x264_t *h, x264_frame_t *frame );

#define x264_deblock_init x264_template(deblock_init)
void          x264_deblock_init( uint32_t cpu, x264_deblock_function_t *pf, int b_mbaff );

#define x264_frame_cond_broadcast x264_template(frame_cond_broadcast)
void          x264_frame_cond_broadcast( x264_frame_t *frame, int i_lines_completed );
#define x264_frame_cond_wait x264_template(frame_cond_wait)
int           x264_frame_cond_wait( x264_frame_t *frame, int i_lines_completed );
#define x264_frame_new_slice x264_template(frame_new_slice)
int           x264_frame_new_slice( x264_t *h, x264_frame_t *frame );

#define x264_threadslice_cond_broadcast x264_template(threadslice_cond_broadcast)
void          x264_threadslice_cond_broadcast( x264_t *h, int pass );
#define x264_threadslice_cond_wait x264_template(threadslice_cond_wait)
void          x264_threadslice_cond_wait( x264_t *h, int pass );

#define x264_frame_push x264_template(frame_push)
X264_API void          x264_frame_push( x264_frame_t **list, x264_frame_t *frame );
#define x264_frame_pop x264_template(frame_pop)
X264_API x264_frame_t *x264_frame_pop( x264_frame_t **list );
#define x264_frame_unshift x264_template(frame_unshift)
X264_API void          x264_frame_unshift( x264_frame_t **list, x264_frame_t *frame );
#define x264_frame_shift x264_template(frame_shift)
X264_API x264_frame_t *x264_frame_shift( x264_frame_t **list );

#define x264_frame_push_unused x264_template(frame_push_unused)
void          x264_frame_push_unused( x264_t *h, x264_frame_t *frame );
#define x264_frame_push_blank_unused x264_template(frame_push_blank_unused)
void          x264_frame_push_blank_unused( x264_t *h, x264_frame_t *frame );
#define x264_frame_pop_blank_unused x264_template(frame_pop_blank_unused)
x264_frame_t *x264_frame_pop_blank_unused( x264_t *h );
#define x264_weight_scale_plane x264_template(weight_scale_plane)
void x264_weight_scale_plane( x264_t *h, pixel *dst, intptr_t i_dst_stride, pixel *src, intptr_t i_src_stride,
                              int i_width, int i_height, x264_weight_t *w );
#define x264_frame_pop_unused x264_template(frame_pop_unused)
x264_frame_t *x264_frame_pop_unused( x264_t *h, int b_fdec );
#define x264_frame_delete_list x264_template(frame_delete_list)
void          x264_frame_delete_list( x264_frame_t **list );

#define x264_sync_frame_list_init x264_template(sync_frame_list_init)
int           x264_sync_frame_list_init( x264_sync_frame_list_t *slist, int nelem );
#define x264_sync_frame_list_delete x264_template(sync_frame_list_delete)
void          x264_sync_frame_list_delete( x264_sync_frame_list_t *slist );
#define x264_sync_frame_list_push x264_template(sync_frame_list_push)
void          x264_sync_frame_list_push( x264_sync_frame_list_t *slist, x264_frame_t *frame );
#define x264_sync_frame_list_pop x264_template(sync_frame_list_pop)
x264_frame_t *x264_sync_frame_list_pop( x264_sync_frame_list_t *slist );

#endif
