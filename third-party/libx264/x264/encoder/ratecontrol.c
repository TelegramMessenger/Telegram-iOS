/*****************************************************************************
 * ratecontrol.c: ratecontrol
 *****************************************************************************
 * Copyright (C) 2005-2022 x264 project
 *
 * Authors: Loren Merritt <lorenm@u.washington.edu>
 *          Michael Niedermayer <michaelni@gmx.at>
 *          Gabriel Bouvigne <gabriel.bouvigne@joost.com>
 *          Fiona Glaser <fiona@x264.com>
 *          Måns Rullgård <mru@mru.ath.cx>
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

#undef NDEBUG // always check asserts, the speed effect is far too small to disable them

#include "common/common.h"
#include "ratecontrol.h"
#include "me.h"

typedef struct
{
    int pict_type;
    int frame_type;
    int kept_as_ref;
    double qscale;
    int mv_bits;
    int tex_bits;
    int misc_bits;
    double expected_bits; /* total expected bits up to the current frame (current one excluded) */
    double expected_vbv;
    double new_qscale;
    float new_qp;
    int i_count;
    int p_count;
    int s_count;
    float blurred_complexity;
    char direct_mode;
    int16_t weight[3][2];
    int16_t i_weight_denom[2];
    int refcount[16];
    int refs;
    int64_t i_duration;
    int64_t i_cpb_duration;
    int out_num;
} ratecontrol_entry_t;

typedef struct
{
    float coeff_min;
    float coeff;
    float count;
    float decay;
    float offset;
} predictor_t;

struct x264_ratecontrol_t
{
    /* constants */
    int b_abr;
    int b_2pass;
    int b_vbv;
    int b_vbv_min_rate;
    double fps;
    double bitrate;
    double rate_tolerance;
    double qcompress;
    int nmb;                    /* number of macroblocks in a frame */
    int qp_constant[3];

    /* current frame */
    ratecontrol_entry_t *rce;
    float qpm;                  /* qp for current macroblock: precise float for AQ */
    float qpa_rc;               /* average of macroblocks' qp before aq */
    float qpa_rc_prev;
    int   qpa_aq;               /* average of macroblocks' qp after aq */
    int   qpa_aq_prev;
    float qp_novbv;             /* QP for the current frame if 1-pass VBV was disabled. */

    /* VBV stuff */
    double buffer_size;
    int64_t buffer_fill_final;
    int64_t buffer_fill_final_min;
    double buffer_fill;         /* planned buffer, if all in-progress frames hit their bit budget */
    double buffer_rate;         /* # of bits added to buffer_fill after each frame */
    double vbv_max_rate;        /* # of bits added to buffer_fill per second */
    predictor_t *pred;          /* predict frame size from satd */
    int single_frame_vbv;
    float rate_factor_max_increment; /* Don't allow RF above (CRF + this value). */

    /* ABR stuff */
    int    last_satd;
    double last_rceq;
    double cplxr_sum;           /* sum of bits*qscale/rceq */
    double expected_bits_sum;   /* sum of qscale2bits after rceq, ratefactor, and overflow, only includes finished frames */
    int64_t filler_bits_sum;    /* sum in bits of finished frames' filler data */
    double wanted_bits_window;  /* target bitrate * window */
    double cbr_decay;
    double short_term_cplxsum;
    double short_term_cplxcount;
    double rate_factor_constant;
    double ip_offset;
    double pb_offset;

    /* 2pass stuff */
    FILE *p_stat_file_out;
    char *psz_stat_file_tmpname;
    FILE *p_mbtree_stat_file_out;
    char *psz_mbtree_stat_file_tmpname;
    char *psz_mbtree_stat_file_name;
    FILE *p_mbtree_stat_file_in;

    int num_entries;            /* number of ratecontrol_entry_ts */
    ratecontrol_entry_t *entry; /* FIXME: copy needed data and free this once init is done */
    ratecontrol_entry_t **entry_out;
    double last_qscale;
    double last_qscale_for[3];  /* last qscale for a specific pict type, used for max_diff & ipb factor stuff */
    int last_non_b_pict_type;
    double accum_p_qp;          /* for determining I-frame quant */
    double accum_p_norm;
    double last_accum_p_norm;
    double lmin[3];             /* min qscale by frame type */
    double lmax[3];
    double lstep;               /* max change (multiply) in qscale per frame */
    struct
    {
        uint16_t *qp_buffer[2]; /* Global buffers for converting MB-tree quantizer data. */
        int qpbuf_pos;          /* In order to handle pyramid reordering, QP buffer acts as a stack.
                                 * This value is the current position (0 or 1). */
        int src_mb_count;

        /* For rescaling */
        int rescale_enabled;
        float *scale_buffer[2]; /* Intermediate buffers */
        int filtersize[2];      /* filter size (H/V) */
        float *coeffs[2];
        int *pos[2];
        int srcdim[2];          /* Source dimensions (W/H) */
    } mbtree;

    /* MBRC stuff */
    volatile float frame_size_estimated; /* Access to this variable must be atomic: double is
                                          * not atomic on all arches we care about */
    double frame_size_maximum;  /* Maximum frame size due to MinCR */
    double frame_size_planned;
    double slice_size_planned;
    predictor_t *row_pred;
    predictor_t row_preds[3][2];
    predictor_t *pred_b_from_p; /* predict B-frame size from P-frame satd */
    int bframes;                /* # consecutive B-frames before this P-frame */
    int bframe_bits;            /* total cost of those frames */

    int i_zones;
    x264_zone_t *zones;
    x264_zone_t *prev_zone;

    /* hrd stuff */
    int initial_cpb_removal_delay;
    int initial_cpb_removal_delay_offset;
    double nrt_first_access_unit; /* nominal removal time */
    double previous_cpb_final_arrival_time;
    uint64_t hrd_multiply_denom;
};


static int parse_zones( x264_t *h );
static int init_pass2(x264_t *);
static float rate_estimate_qscale( x264_t *h );
static int update_vbv( x264_t *h, int bits );
static void update_vbv_plan( x264_t *h, int overhead );
static float predict_size( predictor_t *p, float q, float var );
static void update_predictor( predictor_t *p, float q, float var, float bits );

#define CMP_OPT_FIRST_PASS( opt, param_val )\
{\
    if( ( p = strstr( opts, opt "=" ) ) && sscanf( p, opt "=%d" , &i ) && param_val != i )\
    {\
        x264_log( h, X264_LOG_ERROR, "different " opt " setting than first pass (%d vs %d)\n", param_val, i );\
        return -1;\
    }\
}

/* Terminology:
 * qp = h.264's quantizer
 * qscale = linearized quantizer = Lagrange multiplier
 */
static inline float qp2qscale( float qp )
{
    return 0.85f * powf( 2.0f, ( qp - (12.0f + QP_BD_OFFSET) ) / 6.0f );
}
static inline float qscale2qp( float qscale )
{
    return (12.0f + QP_BD_OFFSET) + 6.0f * log2f( qscale/0.85f );
}

/* Texture bitrate is not quite inversely proportional to qscale,
 * probably due the the changing number of SKIP blocks.
 * MV bits level off at about qp<=12, because the lambda used
 * for motion estimation is constant there. */
static inline double qscale2bits( ratecontrol_entry_t *rce, double qscale )
{
    if( qscale<0.1 )
        qscale = 0.1;
    return (rce->tex_bits + .1) * pow( rce->qscale / qscale, 1.1 )
           + rce->mv_bits * pow( X264_MAX(rce->qscale, 1) / X264_MAX(qscale, 1), 0.5 )
           + rce->misc_bits;
}

static ALWAYS_INLINE uint32_t ac_energy_var( uint64_t sum_ssd, int shift, x264_frame_t *frame, int i, int b_store )
{
    uint32_t sum = sum_ssd;
    uint32_t ssd = sum_ssd >> 32;
    if( b_store )
    {
        frame->i_pixel_sum[i] += sum;
        frame->i_pixel_ssd[i] += ssd;
    }
    return ssd - ((uint64_t)sum * sum >> shift);
}

static ALWAYS_INLINE uint32_t ac_energy_plane( x264_t *h, int mb_x, int mb_y, x264_frame_t *frame, int i, int b_chroma, int b_field, int b_store )
{
    int height = b_chroma ? 16>>CHROMA_V_SHIFT : 16;
    int stride = frame->i_stride[i];
    int offset = b_field
        ? 16 * mb_x + height * (mb_y&~1) * stride + (mb_y&1) * stride
        : 16 * mb_x + height * mb_y * stride;
    stride <<= b_field;
    if( b_chroma )
    {
        ALIGNED_ARRAY_64( pixel, pix,[FENC_STRIDE*16] );
        int chromapix = h->luma2chroma_pixel[PIXEL_16x16];
        int shift = 7 - CHROMA_V_SHIFT;

        h->mc.load_deinterleave_chroma_fenc( pix, frame->plane[1] + offset, stride, height );
        return ac_energy_var( h->pixf.var[chromapix]( pix,               FENC_STRIDE ), shift, frame, 1, b_store )
             + ac_energy_var( h->pixf.var[chromapix]( pix+FENC_STRIDE/2, FENC_STRIDE ), shift, frame, 2, b_store );
    }
    else
        return ac_energy_var( h->pixf.var[PIXEL_16x16]( frame->plane[i] + offset, stride ), 8, frame, i, b_store );
}

// Find the total AC energy of the block in all planes.
static NOINLINE uint32_t ac_energy_mb( x264_t *h, int mb_x, int mb_y, x264_frame_t *frame )
{
    /* This function contains annoying hacks because GCC has a habit of reordering emms
     * and putting it after floating point ops.  As a result, we put the emms at the end of the
     * function and make sure that its always called before the float math.  Noinline makes
     * sure no reordering goes on. */
    uint32_t var;
    x264_prefetch_fenc( h, frame, mb_x, mb_y );
    if( h->mb.b_adaptive_mbaff )
    {
        /* We don't know the super-MB mode we're going to pick yet, so
         * simply try both and pick the lower of the two. */
        uint32_t var_interlaced, var_progressive;
        var_interlaced   = ac_energy_plane( h, mb_x, mb_y, frame, 0, 0, 1, 1 );
        var_progressive  = ac_energy_plane( h, mb_x, mb_y, frame, 0, 0, 0, 0 );
        if( CHROMA444 )
        {
            var_interlaced  += ac_energy_plane( h, mb_x, mb_y, frame, 1, 0, 1, 1 );
            var_progressive += ac_energy_plane( h, mb_x, mb_y, frame, 1, 0, 0, 0 );
            var_interlaced  += ac_energy_plane( h, mb_x, mb_y, frame, 2, 0, 1, 1 );
            var_progressive += ac_energy_plane( h, mb_x, mb_y, frame, 2, 0, 0, 0 );
        }
        else if( CHROMA_FORMAT )
        {
            var_interlaced  += ac_energy_plane( h, mb_x, mb_y, frame, 1, 1, 1, 1 );
            var_progressive += ac_energy_plane( h, mb_x, mb_y, frame, 1, 1, 0, 0 );
        }
        var = X264_MIN( var_interlaced, var_progressive );
    }
    else
    {
        var  = ac_energy_plane( h, mb_x, mb_y, frame, 0, 0, PARAM_INTERLACED, 1 );
        if( CHROMA444 )
        {
            var += ac_energy_plane( h, mb_x, mb_y, frame, 1, 0, PARAM_INTERLACED, 1 );
            var += ac_energy_plane( h, mb_x, mb_y, frame, 2, 0, PARAM_INTERLACED, 1 );
        }
        else if( CHROMA_FORMAT )
            var += ac_energy_plane( h, mb_x, mb_y, frame, 1, 1, PARAM_INTERLACED, 1 );
    }
    x264_emms();
    return var;
}

void x264_adaptive_quant_frame( x264_t *h, x264_frame_t *frame, float *quant_offsets )
{
    /* Initialize frame stats */
    for( int i = 0; i < 3; i++ )
    {
        frame->i_pixel_sum[i] = 0;
        frame->i_pixel_ssd[i] = 0;
    }

    /* Degenerate cases */
    if( h->param.rc.i_aq_mode == X264_AQ_NONE || h->param.rc.f_aq_strength == 0 )
    {
        /* Need to init it anyways for MB tree */
        if( h->param.rc.i_aq_mode && h->param.rc.f_aq_strength == 0 )
        {
            if( quant_offsets )
            {
                for( int mb_xy = 0; mb_xy < h->mb.i_mb_count; mb_xy++ )
                    frame->f_qp_offset[mb_xy] = frame->f_qp_offset_aq[mb_xy] = quant_offsets[mb_xy];
                if( h->frames.b_have_lowres )
                    for( int mb_xy = 0; mb_xy < h->mb.i_mb_count; mb_xy++ )
                        frame->i_inv_qscale_factor[mb_xy] = x264_exp2fix8( frame->f_qp_offset[mb_xy] );
            }
            else
            {
                memset( frame->f_qp_offset, 0, h->mb.i_mb_count * sizeof(float) );
                memset( frame->f_qp_offset_aq, 0, h->mb.i_mb_count * sizeof(float) );
                if( h->frames.b_have_lowres )
                    for( int mb_xy = 0; mb_xy < h->mb.i_mb_count; mb_xy++ )
                        frame->i_inv_qscale_factor[mb_xy] = 256;
            }
        }
        /* Need variance data for weighted prediction */
        if( h->param.analyse.i_weighted_pred )
        {
            for( int mb_y = 0; mb_y < h->mb.i_mb_height; mb_y++ )
                for( int mb_x = 0; mb_x < h->mb.i_mb_width; mb_x++ )
                    ac_energy_mb( h, mb_x, mb_y, frame );
        }
        else
            return;
    }
    /* Actual adaptive quantization */
    else
    {
        /* constants chosen to result in approximately the same overall bitrate as without AQ.
         * FIXME: while they're written in 5 significant digits, they're only tuned to 2. */
        float strength;
        float avg_adj = 0.f;
        float bias_strength = 0.f;

        if( h->param.rc.i_aq_mode == X264_AQ_AUTOVARIANCE || h->param.rc.i_aq_mode == X264_AQ_AUTOVARIANCE_BIASED )
        {
            float bit_depth_correction = 1.f / (1 << (2*(BIT_DEPTH-8)));
            float avg_adj_pow2 = 0.f;
            for( int mb_y = 0; mb_y < h->mb.i_mb_height; mb_y++ )
                for( int mb_x = 0; mb_x < h->mb.i_mb_width; mb_x++ )
                {
                    uint32_t energy = ac_energy_mb( h, mb_x, mb_y, frame );
                    float qp_adj = powf( energy * bit_depth_correction + 1, 0.125f );
                    frame->f_qp_offset[mb_x + mb_y*h->mb.i_mb_stride] = qp_adj;
                    avg_adj += qp_adj;
                    avg_adj_pow2 += qp_adj * qp_adj;
                }
            avg_adj /= h->mb.i_mb_count;
            avg_adj_pow2 /= h->mb.i_mb_count;
            strength = h->param.rc.f_aq_strength * avg_adj;
            avg_adj = avg_adj - 0.5f * (avg_adj_pow2 - 14.f) / avg_adj;
            bias_strength = h->param.rc.f_aq_strength;
        }
        else
            strength = h->param.rc.f_aq_strength * 1.0397f;

        for( int mb_y = 0; mb_y < h->mb.i_mb_height; mb_y++ )
            for( int mb_x = 0; mb_x < h->mb.i_mb_width; mb_x++ )
            {
                float qp_adj;
                int mb_xy = mb_x + mb_y*h->mb.i_mb_stride;
                if( h->param.rc.i_aq_mode == X264_AQ_AUTOVARIANCE_BIASED )
                {
                    qp_adj = frame->f_qp_offset[mb_xy];
                    qp_adj = strength * (qp_adj - avg_adj) + bias_strength * (1.f - 14.f / (qp_adj * qp_adj));
                }
                else if( h->param.rc.i_aq_mode == X264_AQ_AUTOVARIANCE )
                {
                    qp_adj = frame->f_qp_offset[mb_xy];
                    qp_adj = strength * (qp_adj - avg_adj);
                }
                else
                {
                    uint32_t energy = ac_energy_mb( h, mb_x, mb_y, frame );
                    qp_adj = strength * (x264_log2( X264_MAX(energy, 1) ) - (14.427f + 2*(BIT_DEPTH-8)));
                }
                if( quant_offsets )
                    qp_adj += quant_offsets[mb_xy];
                frame->f_qp_offset[mb_xy] =
                frame->f_qp_offset_aq[mb_xy] = qp_adj;
                if( h->frames.b_have_lowres )
                    frame->i_inv_qscale_factor[mb_xy] = x264_exp2fix8(qp_adj);
            }
    }

    /* Remove mean from SSD calculation */
    for( int i = 0; i < 3; i++ )
    {
        uint64_t ssd = frame->i_pixel_ssd[i];
        uint64_t sum = frame->i_pixel_sum[i];
        int width  = 16*h->mb.i_mb_width  >> (i && CHROMA_H_SHIFT);
        int height = 16*h->mb.i_mb_height >> (i && CHROMA_V_SHIFT);
        frame->i_pixel_ssd[i] = ssd - (sum * sum + width * height / 2) / (width * height);
    }
}

static int macroblock_tree_rescale_init( x264_t *h, x264_ratecontrol_t *rc )
{
    /* Use fractional QP array dimensions to compensate for edge padding */
    float srcdim[2] = {rc->mbtree.srcdim[0] / 16.f, rc->mbtree.srcdim[1] / 16.f};
    float dstdim[2] = {    h->param.i_width / 16.f,    h->param.i_height / 16.f};
    int srcdimi[2] = {ceil(srcdim[0]), ceil(srcdim[1])};
    int dstdimi[2] = {ceil(dstdim[0]), ceil(dstdim[1])};
    if( h->param.b_interlaced || h->param.b_fake_interlaced )
    {
        srcdimi[1] = (srcdimi[1]+1)&~1;
        dstdimi[1] = (dstdimi[1]+1)&~1;
    }

    rc->mbtree.src_mb_count = srcdimi[0] * srcdimi[1];

    CHECKED_MALLOC( rc->mbtree.qp_buffer[0], rc->mbtree.src_mb_count * sizeof(uint16_t) );
    if( h->param.i_bframe_pyramid && h->param.rc.b_stat_read )
        CHECKED_MALLOC( rc->mbtree.qp_buffer[1], rc->mbtree.src_mb_count * sizeof(uint16_t) );
    rc->mbtree.qpbuf_pos = -1;

    /* No rescaling to do */
    if( srcdimi[0] == dstdimi[0] && srcdimi[1] == dstdimi[1] )
        return 0;

    rc->mbtree.rescale_enabled = 1;

    /* Allocate intermediate scaling buffers */
    CHECKED_MALLOC( rc->mbtree.scale_buffer[0], srcdimi[0] * srcdimi[1] * sizeof(float) );
    CHECKED_MALLOC( rc->mbtree.scale_buffer[1], dstdimi[0] * srcdimi[1] * sizeof(float) );

    /* Allocate and calculate resize filter parameters and coefficients */
    for( int i = 0; i < 2; i++ )
    {
        if( srcdim[i] > dstdim[i] ) // downscale
            rc->mbtree.filtersize[i] = 1 + (2 * srcdimi[i] + dstdimi[i] - 1) / dstdimi[i];
        else                        // upscale
            rc->mbtree.filtersize[i] = 3;

        CHECKED_MALLOC( rc->mbtree.coeffs[i], rc->mbtree.filtersize[i] * dstdimi[i] * sizeof(float) );
        CHECKED_MALLOC( rc->mbtree.pos[i], dstdimi[i] * sizeof(int) );

        /* Initialize filter coefficients */
        float inc = srcdim[i] / dstdim[i];
        float dmul = inc > 1.f ? dstdim[i] / srcdim[i] : 1.f;
        float dstinsrc = 0.5f * inc - 0.5f;
        int filtersize = rc->mbtree.filtersize[i];
        for( int j = 0; j < dstdimi[i]; j++ )
        {
            int pos = dstinsrc - (filtersize - 2.f) * 0.5f;
            float sum = 0.0;
            rc->mbtree.pos[i][j] = pos;
            for( int k = 0; k < filtersize; k++ )
            {
                float d = fabs( pos + k - dstinsrc ) * dmul;
                float coeff = X264_MAX( 1.f - d, 0 );
                rc->mbtree.coeffs[i][j * filtersize + k] = coeff;
                sum += coeff;
            }
            sum = 1.0f / sum;
            for( int k = 0; k < filtersize; k++ )
                rc->mbtree.coeffs[i][j * filtersize + k] *= sum;
            dstinsrc += inc;
        }
    }

    /* Write back actual qp array dimensions */
    rc->mbtree.srcdim[0] = srcdimi[0];
    rc->mbtree.srcdim[1] = srcdimi[1];
    return 0;
fail:
    return -1;
}

static void macroblock_tree_rescale_destroy( x264_ratecontrol_t *rc )
{
    for( int i = 0; i < 2; i++ )
    {
        x264_free( rc->mbtree.qp_buffer[i] );
        x264_free( rc->mbtree.scale_buffer[i] );
        x264_free( rc->mbtree.coeffs[i] );
        x264_free( rc->mbtree.pos[i] );
    }
}

static ALWAYS_INLINE float tapfilter( float *src, int pos, int max, int stride, float *coeff, int filtersize )
{
    float sum = 0.f;
    for( int i = 0; i < filtersize; i++, pos++ )
        sum += src[x264_clip3( pos, 0, max-1 )*stride] * coeff[i];
    return sum;
}

static void macroblock_tree_rescale( x264_t *h, x264_ratecontrol_t *rc, float *dst )
{
    float *input, *output;
    int filtersize, stride, height;

    /* H scale first */
    input = rc->mbtree.scale_buffer[0];
    output = rc->mbtree.scale_buffer[1];
    filtersize = rc->mbtree.filtersize[0];
    stride = rc->mbtree.srcdim[0];
    height = rc->mbtree.srcdim[1];
    for( int y = 0; y < height; y++, input += stride, output += h->mb.i_mb_width )
    {
        float *coeff = rc->mbtree.coeffs[0];
        for( int x = 0; x < h->mb.i_mb_width; x++, coeff+=filtersize )
            output[x] = tapfilter( input, rc->mbtree.pos[0][x], stride, 1, coeff, filtersize );
    }

    /* V scale next */
    input = rc->mbtree.scale_buffer[1];
    output = dst;
    filtersize = rc->mbtree.filtersize[1];
    stride = h->mb.i_mb_width;
    height = rc->mbtree.srcdim[1];
    for( int x = 0; x < h->mb.i_mb_width; x++, input++, output++ )
    {
        float *coeff = rc->mbtree.coeffs[1];
        for( int y = 0; y < h->mb.i_mb_height; y++, coeff+=filtersize )
            output[y*stride] = tapfilter( input, rc->mbtree.pos[1][y], height, stride, coeff, filtersize );
    }
}

int x264_macroblock_tree_read( x264_t *h, x264_frame_t *frame, float *quant_offsets )
{
    x264_ratecontrol_t *rc = h->rc;
    uint8_t i_type_actual = rc->entry[frame->i_frame].pict_type;

    if( rc->entry[frame->i_frame].kept_as_ref )
    {
        uint8_t i_type;
        if( rc->mbtree.qpbuf_pos < 0 )
        {
            do
            {
                rc->mbtree.qpbuf_pos++;

                if( !fread( &i_type, 1, 1, rc->p_mbtree_stat_file_in ) )
                    goto fail;
                if( fread( rc->mbtree.qp_buffer[rc->mbtree.qpbuf_pos], sizeof(uint16_t), rc->mbtree.src_mb_count, rc->p_mbtree_stat_file_in ) != (unsigned)rc->mbtree.src_mb_count )
                    goto fail;

                if( i_type != i_type_actual && rc->mbtree.qpbuf_pos == 1 )
                {
                    x264_log( h, X264_LOG_ERROR, "MB-tree frametype %d doesn't match actual frametype %d.\n", i_type, i_type_actual );
                    return -1;
                }
            } while( i_type != i_type_actual );
        }

        float *dst = rc->mbtree.rescale_enabled ? rc->mbtree.scale_buffer[0] : frame->f_qp_offset;
        h->mc.mbtree_fix8_unpack( dst, rc->mbtree.qp_buffer[rc->mbtree.qpbuf_pos], rc->mbtree.src_mb_count );
        if( rc->mbtree.rescale_enabled )
            macroblock_tree_rescale( h, rc, frame->f_qp_offset );
        if( h->frames.b_have_lowres )
            for( int i = 0; i < h->mb.i_mb_count; i++ )
                frame->i_inv_qscale_factor[i] = x264_exp2fix8( frame->f_qp_offset[i] );
        rc->mbtree.qpbuf_pos--;
    }
    else
        x264_adaptive_quant_frame( h, frame, quant_offsets );
    return 0;
fail:
    x264_log( h, X264_LOG_ERROR, "Incomplete MB-tree stats file.\n" );
    return -1;
}

int x264_reference_build_list_optimal( x264_t *h )
{
    ratecontrol_entry_t *rce = h->rc->rce;
    x264_frame_t *frames[16];
    x264_weight_t weights[16][3];
    int refcount[16];

    if( rce->refs != h->i_ref[0] )
        return -1;

    memcpy( frames, h->fref[0], sizeof(frames) );
    memcpy( refcount, rce->refcount, sizeof(refcount) );
    memcpy( weights, h->fenc->weight, sizeof(weights) );
    memset( &h->fenc->weight[1][0], 0, sizeof(x264_weight_t[15][3]) );

    /* For now don't reorder ref 0; it seems to lower quality
       in most cases due to skips. */
    for( int ref = 1; ref < h->i_ref[0]; ref++ )
    {
        int max = -1;
        int bestref = 1;

        for( int i = 1; i < h->i_ref[0]; i++ )
            /* Favor lower POC as a tiebreaker. */
            COPY2_IF_GT( max, refcount[i], bestref, i );

        /* FIXME: If there are duplicates from frames other than ref0 then it is possible
         * that the optimal ordering doesn't place every duplicate. */

        refcount[bestref] = -1;
        h->fref[0][ref] = frames[bestref];
        memcpy( h->fenc->weight[ref], weights[bestref], sizeof(weights[bestref]) );
    }

    return 0;
}

static char *strcat_filename( char *input, char *suffix )
{
    char *output = x264_malloc( strlen( input ) + strlen( suffix ) + 1 );
    if( !output )
        return NULL;
    strcpy( output, input );
    strcat( output, suffix );
    return output;
}

void x264_ratecontrol_init_reconfigurable( x264_t *h, int b_init )
{
    x264_ratecontrol_t *rc = h->rc;
    if( !b_init && rc->b_2pass )
        return;

    if( h->param.rc.i_rc_method == X264_RC_CRF )
    {
        /* Arbitrary rescaling to make CRF somewhat similar to QP.
         * Try to compensate for MB-tree's effects as well. */
        double base_cplx = h->mb.i_mb_count * (h->param.i_bframe ? 120 : 80);
        double mbtree_offset = h->param.rc.b_mb_tree ? (1.0-h->param.rc.f_qcompress)*13.5 : 0;
        rc->rate_factor_constant = pow( base_cplx, 1 - rc->qcompress )
                                 / qp2qscale( h->param.rc.f_rf_constant + mbtree_offset + QP_BD_OFFSET );
    }

    if( h->param.rc.i_vbv_max_bitrate > 0 && h->param.rc.i_vbv_buffer_size > 0 )
    {
        /* We don't support changing the ABR bitrate right now,
           so if the stream starts as CBR, keep it CBR. */
        if( rc->b_vbv_min_rate )
            h->param.rc.i_vbv_max_bitrate = h->param.rc.i_bitrate;

        if( h->param.rc.i_vbv_buffer_size < (int)(h->param.rc.i_vbv_max_bitrate / rc->fps) )
        {
            h->param.rc.i_vbv_buffer_size = h->param.rc.i_vbv_max_bitrate / rc->fps;
            x264_log( h, X264_LOG_WARNING, "VBV buffer size cannot be smaller than one frame, using %d kbit\n",
                      h->param.rc.i_vbv_buffer_size );
        }

        int kilobit_size = h->param.i_avcintra_class ? 1024 : 1000;
        int vbv_buffer_size = h->param.rc.i_vbv_buffer_size * kilobit_size;
        int vbv_max_bitrate = h->param.rc.i_vbv_max_bitrate * kilobit_size;

        /* Init HRD */
        if( h->param.i_nal_hrd && b_init )
        {
            h->sps->vui.hrd.i_cpb_cnt = 1;
            h->sps->vui.hrd.b_cbr_hrd = h->param.i_nal_hrd == X264_NAL_HRD_CBR;
            h->sps->vui.hrd.i_time_offset_length = 0;

            #define BR_SHIFT  6
            #define CPB_SHIFT 4

            // normalize HRD size and rate to the value / scale notation
            h->sps->vui.hrd.i_bit_rate_scale = x264_clip3( x264_ctz( vbv_max_bitrate ) - BR_SHIFT, 0, 15 );
            h->sps->vui.hrd.i_bit_rate_value = vbv_max_bitrate >> ( h->sps->vui.hrd.i_bit_rate_scale + BR_SHIFT );
            h->sps->vui.hrd.i_bit_rate_unscaled = h->sps->vui.hrd.i_bit_rate_value << ( h->sps->vui.hrd.i_bit_rate_scale + BR_SHIFT );
            h->sps->vui.hrd.i_cpb_size_scale = x264_clip3( x264_ctz( vbv_buffer_size ) - CPB_SHIFT, 0, 15 );
            h->sps->vui.hrd.i_cpb_size_value = vbv_buffer_size >> ( h->sps->vui.hrd.i_cpb_size_scale + CPB_SHIFT );
            h->sps->vui.hrd.i_cpb_size_unscaled = h->sps->vui.hrd.i_cpb_size_value << ( h->sps->vui.hrd.i_cpb_size_scale + CPB_SHIFT );

            #undef CPB_SHIFT
            #undef BR_SHIFT

            // arbitrary
            #define MAX_DURATION 0.5

            int max_cpb_output_delay = X264_MIN( h->param.i_keyint_max * MAX_DURATION * h->sps->vui.i_time_scale / h->sps->vui.i_num_units_in_tick, INT_MAX );
            int max_dpb_output_delay = h->sps->vui.i_max_dec_frame_buffering * MAX_DURATION * h->sps->vui.i_time_scale / h->sps->vui.i_num_units_in_tick;
            int max_delay = (int)(90000.0 * (double)h->sps->vui.hrd.i_cpb_size_unscaled / h->sps->vui.hrd.i_bit_rate_unscaled + 0.5);

            h->sps->vui.hrd.i_initial_cpb_removal_delay_length = 2 + x264_clip3( 32 - x264_clz( max_delay ), 4, 22 );
            h->sps->vui.hrd.i_cpb_removal_delay_length = x264_clip3( 32 - x264_clz( max_cpb_output_delay ), 4, 31 );
            h->sps->vui.hrd.i_dpb_output_delay_length  = x264_clip3( 32 - x264_clz( max_dpb_output_delay ), 4, 31 );

            #undef MAX_DURATION

            vbv_buffer_size = h->sps->vui.hrd.i_cpb_size_unscaled;
            vbv_max_bitrate = h->sps->vui.hrd.i_bit_rate_unscaled;
        }
        else if( h->param.i_nal_hrd && !b_init )
        {
            x264_log( h, X264_LOG_WARNING, "VBV parameters cannot be changed when NAL HRD is in use\n" );
            return;
        }
        h->sps->vui.hrd.i_bit_rate_unscaled = vbv_max_bitrate;
        h->sps->vui.hrd.i_cpb_size_unscaled = vbv_buffer_size;

        if( rc->b_vbv_min_rate )
            rc->bitrate = (double)h->param.rc.i_bitrate * kilobit_size;
        rc->buffer_rate = vbv_max_bitrate / rc->fps;
        rc->vbv_max_rate = vbv_max_bitrate;
        rc->buffer_size = vbv_buffer_size;
        rc->single_frame_vbv = rc->buffer_rate * 1.1 > rc->buffer_size;
        if( rc->b_abr && h->param.rc.i_rc_method == X264_RC_ABR )
            rc->cbr_decay = 1.0 - rc->buffer_rate / rc->buffer_size
                          * 0.5 * X264_MAX(0, 1.5 - rc->buffer_rate * rc->fps / rc->bitrate);
        if( h->param.rc.i_rc_method == X264_RC_CRF && h->param.rc.f_rf_constant_max )
        {
            rc->rate_factor_max_increment = h->param.rc.f_rf_constant_max - h->param.rc.f_rf_constant;
            if( rc->rate_factor_max_increment <= 0 )
            {
                x264_log( h, X264_LOG_WARNING, "CRF max must be greater than CRF\n" );
                rc->rate_factor_max_increment = 0;
            }
        }
        if( b_init )
        {
            if( h->param.rc.f_vbv_buffer_init > 1. )
                h->param.rc.f_vbv_buffer_init = x264_clip3f( h->param.rc.f_vbv_buffer_init / h->param.rc.i_vbv_buffer_size, 0, 1 );
            h->param.rc.f_vbv_buffer_init = x264_clip3f( X264_MAX( h->param.rc.f_vbv_buffer_init, rc->buffer_rate / rc->buffer_size ), 0, 1);
            rc->buffer_fill_final =
            rc->buffer_fill_final_min = rc->buffer_size * h->param.rc.f_vbv_buffer_init * h->sps->vui.i_time_scale;
            rc->b_vbv = 1;
            rc->b_vbv_min_rate = !rc->b_2pass
                          && h->param.rc.i_rc_method == X264_RC_ABR
                          && h->param.rc.i_vbv_max_bitrate <= h->param.rc.i_bitrate;
        }
    }
}

int x264_ratecontrol_new( x264_t *h )
{
    x264_ratecontrol_t *rc;

    x264_emms();

    CHECKED_MALLOCZERO( h->rc, h->param.i_threads * sizeof(x264_ratecontrol_t) );
    rc = h->rc;

    rc->b_abr = h->param.rc.i_rc_method != X264_RC_CQP && !h->param.rc.b_stat_read;
    rc->b_2pass = h->param.rc.i_rc_method == X264_RC_ABR && h->param.rc.b_stat_read;

    /* FIXME: use integers */
    if( h->param.i_fps_num > 0 && h->param.i_fps_den > 0 )
        rc->fps = (float) h->param.i_fps_num / h->param.i_fps_den;
    else
        rc->fps = 25.0;

    if( h->param.rc.b_mb_tree )
    {
        h->param.rc.f_pb_factor = 1;
        rc->qcompress = 1;
    }
    else
        rc->qcompress = h->param.rc.f_qcompress;

    rc->bitrate = h->param.rc.i_bitrate * (h->param.i_avcintra_class ? 1024. : 1000.);
    rc->rate_tolerance = h->param.rc.f_rate_tolerance;
    rc->nmb = h->mb.i_mb_count;
    rc->last_non_b_pict_type = -1;
    rc->cbr_decay = 1.0;

    if( h->param.rc.i_rc_method != X264_RC_ABR && h->param.rc.b_stat_read )
    {
        x264_log( h, X264_LOG_ERROR, "CRF/CQP is incompatible with 2pass.\n" );
        return -1;
    }

    x264_ratecontrol_init_reconfigurable( h, 1 );

    if( h->param.i_nal_hrd )
    {
        uint64_t denom = (uint64_t)h->sps->vui.hrd.i_bit_rate_unscaled * h->sps->vui.i_time_scale;
        uint64_t num = 90000;
        x264_reduce_fraction64( &num, &denom );
        rc->hrd_multiply_denom = 90000 / num;

        double bits_required = log2( num )
                             + log2( h->sps->vui.i_time_scale )
                             + log2( h->sps->vui.hrd.i_cpb_size_unscaled );
        if( bits_required >= 63 )
        {
            x264_log( h, X264_LOG_ERROR, "HRD with very large timescale and bufsize not supported\n" );
            return -1;
        }
    }

    if( rc->rate_tolerance < 0.01 )
    {
        x264_log( h, X264_LOG_WARNING, "bitrate tolerance too small, using .01\n" );
        rc->rate_tolerance = 0.01;
    }

    h->mb.b_variable_qp = rc->b_vbv || h->param.rc.i_aq_mode;

    if( rc->b_abr )
    {
        /* FIXME ABR_INIT_QP is actually used only in CRF */
#define ABR_INIT_QP (( h->param.rc.i_rc_method == X264_RC_CRF ? h->param.rc.f_rf_constant : 24 ) + QP_BD_OFFSET)
        rc->accum_p_norm = .01;
        rc->accum_p_qp = ABR_INIT_QP * rc->accum_p_norm;
        /* estimated ratio that produces a reasonable QP for the first I-frame */
        rc->cplxr_sum = .01 * pow( 7.0e5, rc->qcompress ) * pow( h->mb.i_mb_count, 0.5 );
        rc->wanted_bits_window = 1.0 * rc->bitrate / rc->fps;
        rc->last_non_b_pict_type = SLICE_TYPE_I;
    }

    rc->ip_offset = 6.0 * log2f( h->param.rc.f_ip_factor );
    rc->pb_offset = 6.0 * log2f( h->param.rc.f_pb_factor );
    rc->qp_constant[SLICE_TYPE_P] = h->param.rc.i_qp_constant;
    rc->qp_constant[SLICE_TYPE_I] = x264_clip3( h->param.rc.i_qp_constant - rc->ip_offset + 0.5, 0, QP_MAX );
    rc->qp_constant[SLICE_TYPE_B] = x264_clip3( h->param.rc.i_qp_constant + rc->pb_offset + 0.5, 0, QP_MAX );
    h->mb.ip_offset = rc->ip_offset + 0.5;

    rc->lstep = pow( 2, h->param.rc.i_qp_step / 6.0 );
    rc->last_qscale = qp2qscale( 26 + QP_BD_OFFSET );
    int num_preds = h->param.b_sliced_threads * h->param.i_threads + 1;
    CHECKED_MALLOC( rc->pred, 5 * sizeof(predictor_t) * num_preds );
    CHECKED_MALLOC( rc->pred_b_from_p, sizeof(predictor_t) );
    static const float pred_coeff_table[3] = { 1.0, 1.0, 1.5 };
    for( int i = 0; i < 3; i++ )
    {
        rc->last_qscale_for[i] = qp2qscale( ABR_INIT_QP );
        rc->lmin[i] = qp2qscale( h->param.rc.i_qp_min );
        rc->lmax[i] = qp2qscale( h->param.rc.i_qp_max );
        for( int j = 0; j < num_preds; j++ )
        {
            rc->pred[i+j*5].coeff_min = pred_coeff_table[i] / 2;
            rc->pred[i+j*5].coeff = pred_coeff_table[i];
            rc->pred[i+j*5].count = 1.0;
            rc->pred[i+j*5].decay = 0.5;
            rc->pred[i+j*5].offset = 0.0;
        }
        for( int j = 0; j < 2; j++ )
        {
            rc->row_preds[i][j].coeff_min = .25 / 4;
            rc->row_preds[i][j].coeff = .25;
            rc->row_preds[i][j].count = 1.0;
            rc->row_preds[i][j].decay = 0.5;
            rc->row_preds[i][j].offset = 0.0;
        }
    }
    rc->pred_b_from_p->coeff_min = 0.5 / 2;
    rc->pred_b_from_p->coeff = 0.5;
    rc->pred_b_from_p->count = 1.0;
    rc->pred_b_from_p->decay = 0.5;
    rc->pred_b_from_p->offset = 0.0;

    if( parse_zones( h ) < 0 )
    {
        x264_log( h, X264_LOG_ERROR, "failed to parse zones\n" );
        return -1;
    }

    /* Load stat file and init 2pass algo */
    if( h->param.rc.b_stat_read )
    {
        char *p, *stats_in, *stats_buf;

        /* read 1st pass stats */
        assert( h->param.rc.psz_stat_in );
        stats_buf = stats_in = x264_slurp_file( h->param.rc.psz_stat_in );
        if( !stats_buf )
        {
            x264_log( h, X264_LOG_ERROR, "ratecontrol_init: can't open stats file\n" );
            return -1;
        }
        if( h->param.rc.b_mb_tree )
        {
            char *mbtree_stats_in = strcat_filename( h->param.rc.psz_stat_in, ".mbtree" );
            if( !mbtree_stats_in )
                return -1;
            rc->p_mbtree_stat_file_in = x264_fopen( mbtree_stats_in, "rb" );
            x264_free( mbtree_stats_in );
            if( !rc->p_mbtree_stat_file_in )
            {
                x264_log( h, X264_LOG_ERROR, "ratecontrol_init: can't open mbtree stats file\n" );
                return -1;
            }
        }

        /* check whether 1st pass options were compatible with current options */
        if( strncmp( stats_buf, "#options:", 9 ) )
        {
            x264_log( h, X264_LOG_ERROR, "options list in stats file not valid\n" );
            return -1;
        }

        float res_factor, res_factor_bits;
        {
            int i, j;
            uint32_t k, l;
            char *opts = stats_buf;
            stats_in = strchr( stats_buf, '\n' );
            if( !stats_in )
                return -1;
            *stats_in = '\0';
            stats_in++;
            if( sscanf( opts, "#options: %dx%d", &i, &j ) != 2 )
            {
                x264_log( h, X264_LOG_ERROR, "resolution specified in stats file not valid\n" );
                return -1;
            }
            else if( h->param.rc.b_mb_tree )
            {
                rc->mbtree.srcdim[0] = i;
                rc->mbtree.srcdim[1] = j;
            }
            res_factor = (float)h->param.i_width * h->param.i_height / (i*j);
            /* Change in bits relative to resolution isn't quite linear on typical sources,
             * so we'll at least try to roughly approximate this effect. */
            res_factor_bits = powf( res_factor, 0.7 );

            if( !( p = strstr( opts, "timebase=" ) ) || sscanf( p, "timebase=%u/%u", &k, &l ) != 2 )
            {
                x264_log( h, X264_LOG_ERROR, "timebase specified in stats file not valid\n" );
                return -1;
            }
            if( k != h->param.i_timebase_num || l != h->param.i_timebase_den )
            {
                x264_log( h, X264_LOG_ERROR, "timebase mismatch with 1st pass (%u/%u vs %u/%u)\n",
                          h->param.i_timebase_num, h->param.i_timebase_den, k, l );
                return -1;
            }

            CMP_OPT_FIRST_PASS( "bitdepth", BIT_DEPTH );
            CMP_OPT_FIRST_PASS( "weightp", X264_MAX( 0, h->param.analyse.i_weighted_pred ) );
            CMP_OPT_FIRST_PASS( "bframes", h->param.i_bframe );
            CMP_OPT_FIRST_PASS( "b_pyramid", h->param.i_bframe_pyramid );
            CMP_OPT_FIRST_PASS( "intra_refresh", h->param.b_intra_refresh );
            CMP_OPT_FIRST_PASS( "open_gop", h->param.b_open_gop );
            CMP_OPT_FIRST_PASS( "bluray_compat", h->param.b_bluray_compat );
            CMP_OPT_FIRST_PASS( "mbtree", h->param.rc.b_mb_tree );

            if( (p = strstr( opts, "interlaced=" )) )
            {
                char *current = h->param.b_interlaced ? h->param.b_tff ? "tff" : "bff" : h->param.b_fake_interlaced ? "fake" : "0";
                char buf[5];
                sscanf( p, "interlaced=%4s", buf );
                if( strcmp( current, buf ) )
                {
                    x264_log( h, X264_LOG_ERROR, "different interlaced setting than first pass (%s vs %s)\n", current, buf );
                    return -1;
                }
            }

            if( (p = strstr( opts, "keyint=" )) )
            {
                p += 7;
                char buf[13] = "infinite ";
                if( h->param.i_keyint_max != X264_KEYINT_MAX_INFINITE )
                    sprintf( buf, "%d ", h->param.i_keyint_max );
                if( strncmp( p, buf, strlen(buf) ) )
                {
                    x264_log( h, X264_LOG_ERROR, "different keyint setting than first pass (%.*s vs %.*s)\n",
                              strlen(buf)-1, buf, strcspn(p, " "), p );
                    return -1;
                }
            }

            if( strstr( opts, "qp=0" ) && h->param.rc.i_rc_method == X264_RC_ABR )
                x264_log( h, X264_LOG_WARNING, "1st pass was lossless, bitrate prediction will be inaccurate\n" );

            if( !strstr( opts, "direct=3" ) && h->param.analyse.i_direct_mv_pred == X264_DIRECT_PRED_AUTO )
            {
                x264_log( h, X264_LOG_WARNING, "direct=auto not used on the first pass\n" );
                h->mb.b_direct_auto_write = 1;
            }

            if( ( p = strstr( opts, "b_adapt=" ) ) && sscanf( p, "b_adapt=%d", &i ) && i >= X264_B_ADAPT_NONE && i <= X264_B_ADAPT_TRELLIS )
                h->param.i_bframe_adaptive = i;
            else if( h->param.i_bframe )
            {
                x264_log( h, X264_LOG_ERROR, "b_adapt method specified in stats file not valid\n" );
                return -1;
            }

            if( (h->param.rc.b_mb_tree || h->param.rc.i_vbv_buffer_size) && ( p = strstr( opts, "rc_lookahead=" ) ) && sscanf( p, "rc_lookahead=%d", &i ) )
                h->param.rc.i_lookahead = i;
        }

        /* find number of pics */
        p = stats_in;
        int num_entries;
        for( num_entries = -1; p; num_entries++ )
            p = strchr( p + 1, ';' );
        if( !num_entries )
        {
            x264_log( h, X264_LOG_ERROR, "empty stats file\n" );
            return -1;
        }
        rc->num_entries = num_entries;

        if( h->param.i_frame_total < rc->num_entries && h->param.i_frame_total > 0 )
        {
            x264_log( h, X264_LOG_WARNING, "2nd pass has fewer frames than 1st pass (%d vs %d)\n",
                      h->param.i_frame_total, rc->num_entries );
        }
        if( h->param.i_frame_total > rc->num_entries )
        {
            x264_log( h, X264_LOG_ERROR, "2nd pass has more frames than 1st pass (%d vs %d)\n",
                      h->param.i_frame_total, rc->num_entries );
            return -1;
        }

        CHECKED_MALLOCZERO( rc->entry, rc->num_entries * sizeof(ratecontrol_entry_t) );
        CHECKED_MALLOC( rc->entry_out, rc->num_entries * sizeof(ratecontrol_entry_t*) );

        /* init all to skipped p frames */
        for( int i = 0; i < rc->num_entries; i++ )
        {
            ratecontrol_entry_t *rce = &rc->entry[i];
            rce->pict_type = SLICE_TYPE_P;
            rce->qscale = rce->new_qscale = qp2qscale( 20 + QP_BD_OFFSET );
            rce->misc_bits = rc->nmb + 10;
            rce->new_qp = 0;
            rc->entry_out[i] = rce;
        }

        /* read stats */
        p = stats_in;
        double total_qp_aq = 0;
        for( int i = 0; i < rc->num_entries; i++ )
        {
            ratecontrol_entry_t *rce;
            int frame_number = 0;
            int frame_out_number = 0;
            char pict_type = 0;
            int e;
            char *next;
            float qp_rc, qp_aq;
            int ref;

            next= strchr(p, ';');
            if( next )
                *next++ = 0; //sscanf is unbelievably slow on long strings
            e = sscanf( p, " in:%d out:%d ", &frame_number, &frame_out_number );

            if( frame_number < 0 || frame_number >= rc->num_entries )
            {
                x264_log( h, X264_LOG_ERROR, "bad frame number (%d) at stats line %d\n", frame_number, i );
                return -1;
            }
            if( frame_out_number < 0 || frame_out_number >= rc->num_entries )
            {
                x264_log( h, X264_LOG_ERROR, "bad frame output number (%d) at stats line %d\n", frame_out_number, i );
                return -1;
            }
            rce = &rc->entry[frame_number];
            rc->entry_out[frame_out_number] = rce;
            rce->direct_mode = 0;

            e += sscanf( p, " in:%*d out:%*d type:%c dur:%"SCNd64" cpbdur:%"SCNd64" q:%f aq:%f tex:%d mv:%d misc:%d imb:%d pmb:%d smb:%d d:%c",
                   &pict_type, &rce->i_duration, &rce->i_cpb_duration, &qp_rc, &qp_aq, &rce->tex_bits,
                   &rce->mv_bits, &rce->misc_bits, &rce->i_count, &rce->p_count,
                   &rce->s_count, &rce->direct_mode );
            rce->tex_bits  *= res_factor_bits;
            rce->mv_bits   *= res_factor_bits;
            rce->misc_bits *= res_factor_bits;
            rce->i_count   *= res_factor;
            rce->p_count   *= res_factor;
            rce->s_count   *= res_factor;

            p = strstr( p, "ref:" );
            if( !p )
                goto parse_error;
            p += 4;
            for( ref = 0; ref < 16; ref++ )
            {
                if( sscanf( p, " %d", &rce->refcount[ref] ) != 1 )
                    break;
                p = strchr( p+1, ' ' );
                if( !p )
                    goto parse_error;
            }
            rce->refs = ref;

            /* find weights */
            rce->i_weight_denom[0] = rce->i_weight_denom[1] = -1;
            char *w = strchr( p, 'w' );
            if( w )
            {
                int count = sscanf( w, "w:%hd,%hd,%hd,%hd,%hd,%hd,%hd,%hd",
                                    &rce->i_weight_denom[0], &rce->weight[0][0], &rce->weight[0][1],
                                    &rce->i_weight_denom[1], &rce->weight[1][0], &rce->weight[1][1],
                                    &rce->weight[2][0], &rce->weight[2][1] );
                if( count == 3 )
                    rce->i_weight_denom[1] = -1;
                else if( count != 8 )
                    rce->i_weight_denom[0] = rce->i_weight_denom[1] = -1;
            }

            if( pict_type != 'b' )
                rce->kept_as_ref = 1;
            switch( pict_type )
            {
                case 'I':
                    rce->frame_type = X264_TYPE_IDR;
                    rce->pict_type  = SLICE_TYPE_I;
                    break;
                case 'i':
                    rce->frame_type = X264_TYPE_I;
                    rce->pict_type  = SLICE_TYPE_I;
                    break;
                case 'P':
                    rce->frame_type = X264_TYPE_P;
                    rce->pict_type  = SLICE_TYPE_P;
                    break;
                case 'B':
                    rce->frame_type = X264_TYPE_BREF;
                    rce->pict_type  = SLICE_TYPE_B;
                    break;
                case 'b':
                    rce->frame_type = X264_TYPE_B;
                    rce->pict_type  = SLICE_TYPE_B;
                    break;
                default:  e = -1; break;
            }
            if( e < 14 )
            {
parse_error:
                x264_log( h, X264_LOG_ERROR, "statistics are damaged at line %d, parser out=%d\n", i, e );
                return -1;
            }
            rce->qscale = qp2qscale( qp_rc );
            total_qp_aq += qp_aq;
            p = next;
        }
        if( !h->param.b_stitchable )
            h->pps->i_pic_init_qp = SPEC_QP( (int)(total_qp_aq / rc->num_entries + 0.5) );

        x264_free( stats_buf );

        if( h->param.rc.i_rc_method == X264_RC_ABR )
        {
            if( init_pass2( h ) < 0 )
                return -1;
        } /* else we're using constant quant, so no need to run the bitrate allocation */
    }

    /* Open output file */
    /* If input and output files are the same, output to a temp file
     * and move it to the real name only when it's complete */
    if( h->param.rc.b_stat_write )
    {
        char *p;
        rc->psz_stat_file_tmpname = strcat_filename( h->param.rc.psz_stat_out, ".temp" );
        if( !rc->psz_stat_file_tmpname )
            return -1;

        rc->p_stat_file_out = x264_fopen( rc->psz_stat_file_tmpname, "wb" );
        if( rc->p_stat_file_out == NULL )
        {
            x264_log( h, X264_LOG_ERROR, "ratecontrol_init: can't open stats file\n" );
            return -1;
        }

        p = x264_param2string( &h->param, 1 );
        if( p )
            fprintf( rc->p_stat_file_out, "#options: %s\n", p );
        x264_free( p );
        if( h->param.rc.b_mb_tree && !h->param.rc.b_stat_read )
        {
            rc->psz_mbtree_stat_file_tmpname = strcat_filename( h->param.rc.psz_stat_out, ".mbtree.temp" );
            rc->psz_mbtree_stat_file_name = strcat_filename( h->param.rc.psz_stat_out, ".mbtree" );
            if( !rc->psz_mbtree_stat_file_tmpname || !rc->psz_mbtree_stat_file_name )
                return -1;

            rc->p_mbtree_stat_file_out = x264_fopen( rc->psz_mbtree_stat_file_tmpname, "wb" );
            if( rc->p_mbtree_stat_file_out == NULL )
            {
                x264_log( h, X264_LOG_ERROR, "ratecontrol_init: can't open mbtree stats file\n" );
                return -1;
            }
        }
    }

    if( h->param.rc.b_mb_tree && (h->param.rc.b_stat_read || h->param.rc.b_stat_write) )
    {
        if( !h->param.rc.b_stat_read )
        {
            rc->mbtree.srcdim[0] = h->param.i_width;
            rc->mbtree.srcdim[1] = h->param.i_height;
        }
        if( macroblock_tree_rescale_init( h, rc ) < 0 )
            return -1;
    }

    for( int i = 0; i<h->param.i_threads; i++ )
    {
        h->thread[i]->rc = rc+i;
        if( i )
        {
            rc[i] = rc[0];
            h->thread[i]->param = h->param;
            h->thread[i]->mb.b_variable_qp = h->mb.b_variable_qp;
            h->thread[i]->mb.ip_offset = h->mb.ip_offset;
        }
    }

    return 0;
fail:
    return -1;
}

static int parse_zone( x264_t *h, x264_zone_t *z, char *p )
{
    int len = 0;
    char *tok, UNUSED *saveptr=NULL;
    z->param = NULL;
    z->f_bitrate_factor = 1;
    if( 3 <= sscanf(p, "%d,%d,q=%d%n", &z->i_start, &z->i_end, &z->i_qp, &len) )
        z->b_force_qp = 1;
    else if( 3 <= sscanf(p, "%d,%d,b=%f%n", &z->i_start, &z->i_end, &z->f_bitrate_factor, &len) )
        z->b_force_qp = 0;
    else if( 2 <= sscanf(p, "%d,%d%n", &z->i_start, &z->i_end, &len) )
        z->b_force_qp = 0;
    else
    {
        x264_log( h, X264_LOG_ERROR, "invalid zone: \"%s\"\n", p );
        return -1;
    }
    p += len;
    if( !*p )
        return 0;
    CHECKED_MALLOC( z->param, sizeof(x264_param_t) );
    memcpy( z->param, &h->param, sizeof(x264_param_t) );
    z->param->opaque = NULL;
    z->param->param_free = x264_free;
    while( (tok = strtok_r( p, ",", &saveptr )) )
    {
        char *val = strchr( tok, '=' );
        if( val )
        {
            *val = '\0';
            val++;
        }
        if( x264_param_parse( z->param, tok, val ) )
        {
            x264_log( h, X264_LOG_ERROR, "invalid zone param: %s = %s\n", tok, val );
            return -1;
        }
        p = NULL;
    }
    return 0;
fail:
    return -1;
}

static int parse_zones( x264_t *h )
{
    x264_ratecontrol_t *rc = h->rc;
    if( h->param.rc.psz_zones && !h->param.rc.i_zones )
    {
        char *psz_zones, *p;
        CHECKED_MALLOC( psz_zones, strlen( h->param.rc.psz_zones )+1 );
        strcpy( psz_zones, h->param.rc.psz_zones );
        h->param.rc.i_zones = 1;
        for( p = psz_zones; *p; p++ )
            h->param.rc.i_zones += (*p == '/');
        CHECKED_MALLOC( h->param.rc.zones, h->param.rc.i_zones * sizeof(x264_zone_t) );
        p = psz_zones;
        for( int i = 0; i < h->param.rc.i_zones; i++ )
        {
            int i_tok = strcspn( p, "/" );
            p[i_tok] = 0;
            if( parse_zone( h, &h->param.rc.zones[i], p ) )
            {
                x264_free( psz_zones );
                return -1;
            }
            p += i_tok + 1;
        }
        x264_free( psz_zones );
    }

    if( h->param.rc.i_zones > 0 )
    {
        for( int i = 0; i < h->param.rc.i_zones; i++ )
        {
            x264_zone_t z = h->param.rc.zones[i];
            if( z.i_start < 0 || z.i_start > z.i_end )
            {
                x264_log( h, X264_LOG_ERROR, "invalid zone: start=%d end=%d\n",
                          z.i_start, z.i_end );
                return -1;
            }
            else if( !z.b_force_qp && z.f_bitrate_factor <= 0 )
            {
                x264_log( h, X264_LOG_ERROR, "invalid zone: bitrate_factor=%f\n",
                          z.f_bitrate_factor );
                return -1;
            }
        }

        rc->i_zones = h->param.rc.i_zones + 1;
        CHECKED_MALLOC( rc->zones, rc->i_zones * sizeof(x264_zone_t) );
        memcpy( rc->zones+1, h->param.rc.zones, (rc->i_zones-1) * sizeof(x264_zone_t) );

        // default zone to fall back to if none of the others match
        rc->zones[0].i_start = 0;
        rc->zones[0].i_end = INT_MAX;
        rc->zones[0].b_force_qp = 0;
        rc->zones[0].f_bitrate_factor = 1;
        CHECKED_MALLOC( rc->zones[0].param, sizeof(x264_param_t) );
        memcpy( rc->zones[0].param, &h->param, sizeof(x264_param_t) );
        rc->zones[0].param->opaque = NULL;
        for( int i = 1; i < rc->i_zones; i++ )
        {
            if( !rc->zones[i].param )
                rc->zones[i].param = rc->zones[0].param;
        }
    }

    return 0;
fail:
    return -1;
}

static x264_zone_t *get_zone( x264_t *h, int frame_num )
{
    x264_ratecontrol_t *rc = h->rc;
    for( int i = rc->i_zones - 1; i >= 0; i-- )
    {
        x264_zone_t *z = &rc->zones[i];
        if( frame_num >= z->i_start && frame_num <= z->i_end )
            return z;
    }
    return NULL;
}

void x264_ratecontrol_summary( x264_t *h )
{
    x264_ratecontrol_t *rc = h->rc;
    if( rc->b_abr && h->param.rc.i_rc_method == X264_RC_ABR && rc->cbr_decay > .9999 )
    {
        double base_cplx = h->mb.i_mb_count * (h->param.i_bframe ? 120 : 80);
        double mbtree_offset = h->param.rc.b_mb_tree ? (1.0-h->param.rc.f_qcompress)*13.5 : 0;
        x264_log( h, X264_LOG_INFO, "final ratefactor: %.2f\n",
                  qscale2qp( pow( base_cplx, 1 - rc->qcompress )
                             * rc->cplxr_sum / rc->wanted_bits_window ) - mbtree_offset - QP_BD_OFFSET );
    }
}

void x264_ratecontrol_delete( x264_t *h )
{
    x264_ratecontrol_t *rc = h->rc;
    int b_regular_file;

    if( rc->p_stat_file_out )
    {
        b_regular_file = x264_is_regular_file( rc->p_stat_file_out );
        fclose( rc->p_stat_file_out );
        if( h->i_frame >= rc->num_entries && b_regular_file )
            if( x264_rename( rc->psz_stat_file_tmpname, h->param.rc.psz_stat_out ) != 0 )
            {
                x264_log( h, X264_LOG_ERROR, "failed to rename \"%s\" to \"%s\"\n",
                          rc->psz_stat_file_tmpname, h->param.rc.psz_stat_out );
            }
        x264_free( rc->psz_stat_file_tmpname );
    }
    if( rc->p_mbtree_stat_file_out )
    {
        b_regular_file = x264_is_regular_file( rc->p_mbtree_stat_file_out );
        fclose( rc->p_mbtree_stat_file_out );
        if( h->i_frame >= rc->num_entries && b_regular_file )
            if( x264_rename( rc->psz_mbtree_stat_file_tmpname, rc->psz_mbtree_stat_file_name ) != 0 )
            {
                x264_log( h, X264_LOG_ERROR, "failed to rename \"%s\" to \"%s\"\n",
                          rc->psz_mbtree_stat_file_tmpname, rc->psz_mbtree_stat_file_name );
            }
        x264_free( rc->psz_mbtree_stat_file_tmpname );
        x264_free( rc->psz_mbtree_stat_file_name );
    }
    if( rc->p_mbtree_stat_file_in )
        fclose( rc->p_mbtree_stat_file_in );
    x264_free( rc->pred );
    x264_free( rc->pred_b_from_p );
    x264_free( rc->entry );
    x264_free( rc->entry_out );
    macroblock_tree_rescale_destroy( rc );
    if( rc->zones )
    {
        x264_param_cleanup( rc->zones[0].param );
        x264_free( rc->zones[0].param );
        for( int i = 1; i < rc->i_zones; i++ )
            if( rc->zones[i].param != rc->zones[0].param && rc->zones[i].param->param_free )
            {
                x264_param_cleanup( rc->zones[i].param );
                rc->zones[i].param->param_free( rc->zones[i].param );
            }
        x264_free( rc->zones );
    }
    x264_free( rc );
}

static void accum_p_qp_update( x264_t *h, float qp )
{
    x264_ratecontrol_t *rc = h->rc;
    rc->accum_p_qp   *= .95;
    rc->accum_p_norm *= .95;
    rc->accum_p_norm += 1;
    if( h->sh.i_type == SLICE_TYPE_I )
        rc->accum_p_qp += qp + rc->ip_offset;
    else
        rc->accum_p_qp += qp;
}

void x264_ratecontrol_zone_init( x264_t *h )
{
    x264_ratecontrol_t *rc = h->rc;
    x264_zone_t *zone = get_zone( h, h->fenc->i_frame );
    if( zone && (!rc->prev_zone || zone->param != rc->prev_zone->param) )
        x264_encoder_reconfig_apply( h, zone->param );
    rc->prev_zone = zone;
}

/* Before encoding a frame, choose a QP for it */
void x264_ratecontrol_start( x264_t *h, int i_force_qp, int overhead )
{
    x264_ratecontrol_t *rc = h->rc;
    ratecontrol_entry_t *rce = NULL;
    x264_zone_t *zone = get_zone( h, h->fenc->i_frame );
    float q;

    x264_emms();

    if( h->param.rc.b_stat_read )
    {
        int frame = h->fenc->i_frame;
        assert( frame >= 0 && frame < rc->num_entries );
        rce = rc->rce = &rc->entry[frame];

        if( h->sh.i_type == SLICE_TYPE_B
            && h->param.analyse.i_direct_mv_pred == X264_DIRECT_PRED_AUTO )
        {
            h->sh.b_direct_spatial_mv_pred = ( rce->direct_mode == 's' );
            h->mb.b_direct_auto_read = ( rce->direct_mode == 's' || rce->direct_mode == 't' );
        }
    }

    if( rc->b_vbv )
    {
        memset( h->fdec->i_row_bits, 0, h->mb.i_mb_height * sizeof(int) );
        memset( h->fdec->f_row_qp, 0, h->mb.i_mb_height * sizeof(float) );
        memset( h->fdec->f_row_qscale, 0, h->mb.i_mb_height * sizeof(float) );
        rc->row_pred = rc->row_preds[h->sh.i_type];
        rc->buffer_rate = h->fenc->i_cpb_duration * rc->vbv_max_rate * h->sps->vui.i_num_units_in_tick / h->sps->vui.i_time_scale;
        update_vbv_plan( h, overhead );

        const x264_level_t *l = x264_levels;
        while( l->level_idc != 0 && l->level_idc != h->param.i_level_idc )
            l++;

        int mincr = l->mincr;

        if( h->param.b_bluray_compat )
            mincr = 4;

        /* Profiles above High don't require minCR, so just set the maximum to a large value. */
        if( h->sps->i_profile_idc > PROFILE_HIGH )
            rc->frame_size_maximum = 1e9;
        else
        {
            /* The spec has a bizarre special case for the first frame. */
            if( h->i_frame == 0 )
            {
                //384 * ( Max( PicSizeInMbs, fR * MaxMBPS ) + MaxMBPS * ( tr( 0 ) - tr,n( 0 ) ) ) / MinCR
                double fr = 1. / (h->param.i_level_idc >= 60 ? 300 : 172);
                int pic_size_in_mbs = h->mb.i_mb_width * h->mb.i_mb_height;
                rc->frame_size_maximum = 384 * BIT_DEPTH * X264_MAX( pic_size_in_mbs, fr*l->mbps ) / mincr;
            }
            else
            {
                //384 * MaxMBPS * ( tr( n ) - tr( n - 1 ) ) / MinCR
                rc->frame_size_maximum = 384 * BIT_DEPTH * ((double)h->fenc->i_cpb_duration * h->sps->vui.i_num_units_in_tick / h->sps->vui.i_time_scale) * l->mbps / mincr;
            }
        }
    }

    if( h->sh.i_type != SLICE_TYPE_B )
        rc->bframes = h->fenc->i_bframes;

    if( rc->b_abr )
    {
        q = qscale2qp( rate_estimate_qscale( h ) );
    }
    else if( rc->b_2pass )
    {
        rce->new_qscale = rate_estimate_qscale( h );
        q = qscale2qp( rce->new_qscale );
    }
    else /* CQP */
    {
        if( h->sh.i_type == SLICE_TYPE_B && h->fdec->b_kept_as_ref )
            q = ( rc->qp_constant[ SLICE_TYPE_B ] + rc->qp_constant[ SLICE_TYPE_P ] ) / 2;
        else
            q = rc->qp_constant[ h->sh.i_type ];

        if( zone )
        {
            if( zone->b_force_qp )
                q += zone->i_qp - rc->qp_constant[SLICE_TYPE_P];
            else
                q -= 6*log2f( zone->f_bitrate_factor );
        }
    }
    if( i_force_qp != X264_QP_AUTO )
        q = i_force_qp - 1;

    q = x264_clip3f( q, h->param.rc.i_qp_min, h->param.rc.i_qp_max );

    rc->qpa_rc = rc->qpa_rc_prev =
    rc->qpa_aq = rc->qpa_aq_prev = 0;
    h->fdec->f_qp_avg_rc =
    h->fdec->f_qp_avg_aq =
    rc->qpm = q;
    if( rce )
        rce->new_qp = q;

    accum_p_qp_update( h, rc->qpm );

    if( h->sh.i_type != SLICE_TYPE_B )
        rc->last_non_b_pict_type = h->sh.i_type;
}

static float predict_row_size( x264_t *h, int y, float qscale )
{
    /* average between two predictors:
     * absolute SATD, and scaled bit cost of the colocated row in the previous frame */
    x264_ratecontrol_t *rc = h->rc;
    float pred_s = predict_size( &rc->row_pred[0], qscale, h->fdec->i_row_satd[y] );
    if( h->sh.i_type == SLICE_TYPE_I || qscale >= h->fref[0][0]->f_row_qscale[y] )
    {
        if( h->sh.i_type == SLICE_TYPE_P
            && h->fref[0][0]->i_type == h->fdec->i_type
            && h->fref[0][0]->f_row_qscale[y] > 0
            && h->fref[0][0]->i_row_satd[y] > 0
            && (abs(h->fref[0][0]->i_row_satd[y] - h->fdec->i_row_satd[y]) < h->fdec->i_row_satd[y]/2))
        {
            float pred_t = h->fref[0][0]->i_row_bits[y] * h->fdec->i_row_satd[y] / h->fref[0][0]->i_row_satd[y]
                         * h->fref[0][0]->f_row_qscale[y] / qscale;
            return (pred_s + pred_t) * 0.5f;
        }
        return pred_s;
    }
    /* Our QP is lower than the reference! */
    else
    {
        float pred_intra = predict_size( &rc->row_pred[1], qscale, h->fdec->i_row_satds[0][0][y] );
        /* Sum: better to overestimate than underestimate by using only one of the two predictors. */
        return pred_intra + pred_s;
    }
}

static int row_bits_so_far( x264_t *h, int y )
{
    int bits = 0;
    for( int i = h->i_threadslice_start; i <= y; i++ )
        bits += h->fdec->i_row_bits[i];
    return bits;
}

static float predict_row_size_to_end( x264_t *h, int y, float qp )
{
    float qscale = qp2qscale( qp );
    float bits = 0;
    for( int i = y+1; i < h->i_threadslice_end; i++ )
        bits += predict_row_size( h, i, qscale );
    return bits;
}

/* TODO:
 *  eliminate all use of qp in row ratecontrol: make it entirely qscale-based.
 *  make this function stop being needlessly O(N^2)
 *  update more often than once per row? */
int x264_ratecontrol_mb( x264_t *h, int bits )
{
    x264_ratecontrol_t *rc = h->rc;
    const int y = h->mb.i_mb_y;

    h->fdec->i_row_bits[y] += bits;
    rc->qpa_aq += h->mb.i_qp;

    if( h->mb.i_mb_x != h->mb.i_mb_width - 1 )
        return 0;

    x264_emms();
    rc->qpa_rc += rc->qpm * h->mb.i_mb_width;

    if( !rc->b_vbv )
        return 0;

    float qscale = qp2qscale( rc->qpm );
    h->fdec->f_row_qp[y] = rc->qpm;
    h->fdec->f_row_qscale[y] = qscale;

    update_predictor( &rc->row_pred[0], qscale, h->fdec->i_row_satd[y], h->fdec->i_row_bits[y] );
    if( h->sh.i_type != SLICE_TYPE_I && rc->qpm < h->fref[0][0]->f_row_qp[y] )
        update_predictor( &rc->row_pred[1], qscale, h->fdec->i_row_satds[0][0][y], h->fdec->i_row_bits[y] );

    /* update ratecontrol per-mbpair in MBAFF */
    if( SLICE_MBAFF && !(y&1) )
        return 0;

    /* FIXME: We don't currently support the case where there's a slice
     * boundary in between. */
    int can_reencode_row = h->sh.i_first_mb <= ((h->mb.i_mb_y - SLICE_MBAFF) * h->mb.i_mb_stride);

    /* tweak quality based on difference from predicted size */
    float prev_row_qp = h->fdec->f_row_qp[y];
    float qp_absolute_max = h->param.rc.i_qp_max;
    if( rc->rate_factor_max_increment )
        qp_absolute_max = X264_MIN( qp_absolute_max, rc->qp_novbv + rc->rate_factor_max_increment );
    float qp_max = X264_MIN( prev_row_qp + h->param.rc.i_qp_step, qp_absolute_max );
    float qp_min = X264_MAX( prev_row_qp - h->param.rc.i_qp_step, h->param.rc.i_qp_min );
    float step_size = 0.5f;
    float slice_size_planned = h->param.b_sliced_threads ? rc->slice_size_planned : rc->frame_size_planned;
    float bits_so_far = row_bits_so_far( h, y );
    float max_frame_error = x264_clip3f( 1.0 / h->mb.i_mb_height, 0.05, 0.25 );
    float max_frame_size = rc->frame_size_maximum - rc->frame_size_maximum * max_frame_error;
    max_frame_size = X264_MIN( max_frame_size, rc->buffer_fill - rc->buffer_rate * max_frame_error );
    float size_of_other_slices = 0;
    if( h->param.b_sliced_threads )
    {
        float size_of_other_slices_planned = 0;
        for( int i = 0; i < h->param.i_threads; i++ )
            if( h != h->thread[i] )
            {
                size_of_other_slices += h->thread[i]->rc->frame_size_estimated;
                size_of_other_slices_planned += h->thread[i]->rc->slice_size_planned;
            }
        float weight = rc->slice_size_planned / rc->frame_size_planned;
        size_of_other_slices = (size_of_other_slices - size_of_other_slices_planned) * weight + size_of_other_slices_planned;
    }
    if( y < h->i_threadslice_end-1 )
    {
        /* B-frames shouldn't use lower QP than their reference frames. */
        if( h->sh.i_type == SLICE_TYPE_B )
        {
            qp_min = X264_MAX( qp_min, X264_MAX( h->fref[0][0]->f_row_qp[y+1], h->fref[1][0]->f_row_qp[y+1] ) );
            rc->qpm = X264_MAX( rc->qpm, qp_min );
        }

        float buffer_left_planned = rc->buffer_fill - rc->frame_size_planned;
        buffer_left_planned = X264_MAX( buffer_left_planned, 0.f );
        /* More threads means we have to be more cautious in letting ratecontrol use up extra bits. */
        float rc_tol = buffer_left_planned / h->param.i_threads * rc->rate_tolerance;
        float b1 = bits_so_far + predict_row_size_to_end( h, y, rc->qpm ) + size_of_other_slices;
        float trust_coeff = x264_clip3f( bits_so_far / slice_size_planned, 0.0, 1.0 );

        /* Don't increase the row QPs until a sufficient amount of the bits of the frame have been processed, in case a flat */
        /* area at the top of the frame was measured inaccurately. */
        if( trust_coeff < 0.05f )
            qp_max = qp_absolute_max = prev_row_qp;

        if( h->sh.i_type != SLICE_TYPE_I )
            rc_tol *= 0.5f;

        if( !rc->b_vbv_min_rate )
            qp_min = X264_MAX( qp_min, rc->qp_novbv );

        while( rc->qpm < qp_max
               && ((b1 > rc->frame_size_planned + rc_tol) ||
                   (b1 > rc->frame_size_planned && rc->qpm < rc->qp_novbv) ||
                   (b1 > rc->buffer_fill - buffer_left_planned * 0.5f)) )
        {
            rc->qpm += step_size;
            b1 = bits_so_far + predict_row_size_to_end( h, y, rc->qpm ) + size_of_other_slices;
        }

        float b_max = b1 + ((rc->buffer_fill - rc->buffer_size + rc->buffer_rate) * 0.90f - b1) * trust_coeff;
        rc->qpm -= step_size;
        float b2 = bits_so_far + predict_row_size_to_end( h, y, rc->qpm ) + size_of_other_slices;
        while( rc->qpm > qp_min && rc->qpm < prev_row_qp
               && (rc->qpm > h->fdec->f_row_qp[0] || rc->single_frame_vbv)
               && (b2 < max_frame_size)
               && ((b2 < rc->frame_size_planned * 0.8f) || (b2 < b_max)) )
        {
            b1 = b2;
            rc->qpm -= step_size;
            b2 = bits_so_far + predict_row_size_to_end( h, y, rc->qpm ) + size_of_other_slices;
        }
        rc->qpm += step_size;

        /* avoid VBV underflow or MinCR violation */
        while( rc->qpm < qp_absolute_max && (b1 > max_frame_size) )
        {
            rc->qpm += step_size;
            b1 = bits_so_far + predict_row_size_to_end( h, y, rc->qpm ) + size_of_other_slices;
        }

        rc->frame_size_estimated = b1 - size_of_other_slices;

        /* If the current row was large enough to cause a large QP jump, try re-encoding it. */
        if( rc->qpm > qp_max && prev_row_qp < qp_max && can_reencode_row )
        {
            /* Bump QP to halfway in between... close enough. */
            rc->qpm = x264_clip3f( (prev_row_qp + rc->qpm)*0.5f, prev_row_qp + 1.0f, qp_max );
            rc->qpa_rc = rc->qpa_rc_prev;
            rc->qpa_aq = rc->qpa_aq_prev;
            h->fdec->i_row_bits[y] = 0;
            h->fdec->i_row_bits[y-SLICE_MBAFF] = 0;
            return -1;
        }
    }
    else
    {
        rc->frame_size_estimated = bits_so_far;

        /* Last-ditch attempt: if the last row of the frame underflowed the VBV,
         * try again. */
        if( rc->qpm < qp_max && can_reencode_row
            && (bits_so_far + size_of_other_slices > X264_MIN( rc->frame_size_maximum, rc->buffer_fill )) )
        {
            rc->qpm = qp_max;
            rc->qpa_rc = rc->qpa_rc_prev;
            rc->qpa_aq = rc->qpa_aq_prev;
            h->fdec->i_row_bits[y] = 0;
            h->fdec->i_row_bits[y-SLICE_MBAFF] = 0;
            return -1;
        }
    }

    rc->qpa_rc_prev = rc->qpa_rc;
    rc->qpa_aq_prev = rc->qpa_aq;

    return 0;
}

int x264_ratecontrol_qp( x264_t *h )
{
    x264_emms();
    return x264_clip3( h->rc->qpm + 0.5f, h->param.rc.i_qp_min, h->param.rc.i_qp_max );
}

int x264_ratecontrol_mb_qp( x264_t *h )
{
    x264_emms();
    float qp = h->rc->qpm;
    if( h->param.rc.i_aq_mode )
    {
         /* MB-tree currently doesn't adjust quantizers in unreferenced frames. */
        float qp_offset = h->fdec->b_kept_as_ref ? h->fenc->f_qp_offset[h->mb.i_mb_xy] : h->fenc->f_qp_offset_aq[h->mb.i_mb_xy];
        /* Scale AQ's effect towards zero in emergency mode. */
        if( qp > QP_MAX_SPEC )
            qp_offset *= (QP_MAX - qp) / (QP_MAX - QP_MAX_SPEC);
        qp += qp_offset;
    }
    return x264_clip3( qp + 0.5f, h->param.rc.i_qp_min, h->param.rc.i_qp_max );
}

/* In 2pass, force the same frame types as in the 1st pass */
int x264_ratecontrol_slice_type( x264_t *h, int frame_num )
{
    x264_ratecontrol_t *rc = h->rc;
    if( h->param.rc.b_stat_read )
    {
        if( frame_num >= rc->num_entries )
        {
            /* We could try to initialize everything required for ABR and
             * adaptive B-frames, but that would be complicated.
             * So just calculate the average QP used so far. */
            h->param.rc.i_qp_constant = (h->stat.i_frame_count[SLICE_TYPE_P] == 0) ? 24 + QP_BD_OFFSET
                                      : 1 + h->stat.f_frame_qp[SLICE_TYPE_P] / h->stat.i_frame_count[SLICE_TYPE_P];
            rc->qp_constant[SLICE_TYPE_P] = x264_clip3( h->param.rc.i_qp_constant, 0, QP_MAX );
            rc->qp_constant[SLICE_TYPE_I] = x264_clip3( (int)( qscale2qp( qp2qscale( h->param.rc.i_qp_constant ) / h->param.rc.f_ip_factor ) + 0.5 ), 0, QP_MAX );
            rc->qp_constant[SLICE_TYPE_B] = x264_clip3( (int)( qscale2qp( qp2qscale( h->param.rc.i_qp_constant ) * h->param.rc.f_pb_factor ) + 0.5 ), 0, QP_MAX );

            x264_log( h, X264_LOG_ERROR, "2nd pass has more frames than 1st pass (%d)\n", rc->num_entries );
            x264_log( h, X264_LOG_ERROR, "continuing anyway, at constant QP=%d\n", h->param.rc.i_qp_constant );
            if( h->param.i_bframe_adaptive )
                x264_log( h, X264_LOG_ERROR, "disabling adaptive B-frames\n" );

            for( int i = 0; i < h->param.i_threads; i++ )
            {
                h->thread[i]->rc->b_abr = 0;
                h->thread[i]->rc->b_2pass = 0;
                h->thread[i]->param.rc.i_rc_method = X264_RC_CQP;
                h->thread[i]->param.rc.b_stat_read = 0;
                h->thread[i]->param.i_bframe_adaptive = 0;
                h->thread[i]->param.i_scenecut_threshold = 0;
                h->thread[i]->param.rc.b_mb_tree = 0;
                if( h->thread[i]->param.i_bframe > 1 )
                    h->thread[i]->param.i_bframe = 1;
            }
            return X264_TYPE_AUTO;
        }
        return rc->entry[frame_num].frame_type;
    }
    else
        return X264_TYPE_AUTO;
}

void x264_ratecontrol_set_weights( x264_t *h, x264_frame_t *frm )
{
    ratecontrol_entry_t *rce = &h->rc->entry[frm->i_frame];
    if( h->param.analyse.i_weighted_pred <= 0 )
        return;

    if( rce->i_weight_denom[0] >= 0 )
        SET_WEIGHT( frm->weight[0][0], 1, rce->weight[0][0], rce->i_weight_denom[0], rce->weight[0][1] );

    if( rce->i_weight_denom[1] >= 0 )
    {
        SET_WEIGHT( frm->weight[0][1], 1, rce->weight[1][0], rce->i_weight_denom[1], rce->weight[1][1] );
        SET_WEIGHT( frm->weight[0][2], 1, rce->weight[2][0], rce->i_weight_denom[1], rce->weight[2][1] );
    }
}

/* After encoding one frame, save stats and update ratecontrol state */
int x264_ratecontrol_end( x264_t *h, int bits, int *filler )
{
    x264_ratecontrol_t *rc = h->rc;
    const int *mbs = h->stat.frame.i_mb_count;

    x264_emms();

    h->stat.frame.i_mb_count_skip = mbs[P_SKIP] + mbs[B_SKIP];
    h->stat.frame.i_mb_count_i = mbs[I_16x16] + mbs[I_8x8] + mbs[I_4x4] + mbs[I_PCM];
    h->stat.frame.i_mb_count_p = mbs[P_L0] + mbs[P_8x8];
    for( int i = B_DIRECT; i <= B_8x8; i++ )
        h->stat.frame.i_mb_count_p += mbs[i];

    h->fdec->f_qp_avg_rc = rc->qpa_rc /= h->mb.i_mb_count;
    h->fdec->f_qp_avg_aq = (float)rc->qpa_aq / h->mb.i_mb_count;
    h->fdec->f_crf_avg = h->param.rc.f_rf_constant + h->fdec->f_qp_avg_rc - rc->qp_novbv;

    if( h->param.rc.b_stat_write )
    {
        char c_type = h->sh.i_type==SLICE_TYPE_I ? (h->fenc->i_poc==0 ? 'I' : 'i')
                    : h->sh.i_type==SLICE_TYPE_P ? 'P'
                    : h->fenc->b_kept_as_ref ? 'B' : 'b';
        int dir_frame = h->stat.frame.i_direct_score[1] - h->stat.frame.i_direct_score[0];
        int dir_avg = h->stat.i_direct_score[1] - h->stat.i_direct_score[0];
        char c_direct = h->mb.b_direct_auto_write ?
                        ( dir_frame>0 ? 's' : dir_frame<0 ? 't' :
                          dir_avg>0 ? 's' : dir_avg<0 ? 't' : '-' )
                        : '-';
        if( fprintf( rc->p_stat_file_out,
                 "in:%d out:%d type:%c dur:%"PRId64" cpbdur:%"PRId64" q:%.2f aq:%.2f tex:%d mv:%d misc:%d imb:%d pmb:%d smb:%d d:%c ref:",
                 h->fenc->i_frame, h->i_frame,
                 c_type, h->fenc->i_duration,
                 h->fenc->i_cpb_duration,
                 rc->qpa_rc, h->fdec->f_qp_avg_aq,
                 h->stat.frame.i_tex_bits,
                 h->stat.frame.i_mv_bits,
                 h->stat.frame.i_misc_bits,
                 h->stat.frame.i_mb_count_i,
                 h->stat.frame.i_mb_count_p,
                 h->stat.frame.i_mb_count_skip,
                 c_direct) < 0 )
            goto fail;

        /* Only write information for reference reordering once. */
        int use_old_stats = h->param.rc.b_stat_read && rc->rce->refs > 1;
        for( int i = 0; i < (use_old_stats ? rc->rce->refs : h->i_ref[0]); i++ )
        {
            int refcount = use_old_stats         ? rc->rce->refcount[i]
                         : PARAM_INTERLACED      ? h->stat.frame.i_mb_count_ref[0][i*2]
                                                 + h->stat.frame.i_mb_count_ref[0][i*2+1]
                         :                         h->stat.frame.i_mb_count_ref[0][i];
            if( fprintf( rc->p_stat_file_out, "%d ", refcount ) < 0 )
                goto fail;
        }

        if( h->param.analyse.i_weighted_pred >= X264_WEIGHTP_SIMPLE && h->sh.weight[0][0].weightfn )
        {
            if( fprintf( rc->p_stat_file_out, "w:%d,%d,%d",
                         h->sh.weight[0][0].i_denom, h->sh.weight[0][0].i_scale, h->sh.weight[0][0].i_offset ) < 0 )
                goto fail;
            if( h->sh.weight[0][1].weightfn || h->sh.weight[0][2].weightfn )
            {
                if( fprintf( rc->p_stat_file_out, ",%d,%d,%d,%d,%d ",
                             h->sh.weight[0][1].i_denom, h->sh.weight[0][1].i_scale, h->sh.weight[0][1].i_offset,
                             h->sh.weight[0][2].i_scale, h->sh.weight[0][2].i_offset ) < 0 )
                    goto fail;
            }
            else if( fprintf( rc->p_stat_file_out, " " ) < 0 )
                goto fail;
        }

        if( fprintf( rc->p_stat_file_out, ";\n") < 0 )
            goto fail;

        /* Don't re-write the data in multi-pass mode. */
        if( h->param.rc.b_mb_tree && h->fenc->b_kept_as_ref && !h->param.rc.b_stat_read )
        {
            uint8_t i_type = h->sh.i_type;
            h->mc.mbtree_fix8_pack( rc->mbtree.qp_buffer[0], h->fenc->f_qp_offset, h->mb.i_mb_count );
            if( fwrite( &i_type, 1, 1, rc->p_mbtree_stat_file_out ) < 1 )
                goto fail;
            if( fwrite( rc->mbtree.qp_buffer[0], sizeof(uint16_t), h->mb.i_mb_count, rc->p_mbtree_stat_file_out ) < (unsigned)h->mb.i_mb_count )
                goto fail;
        }
    }

    if( rc->b_abr )
    {
        if( h->sh.i_type != SLICE_TYPE_B )
            rc->cplxr_sum += bits * qp2qscale( rc->qpa_rc ) / rc->last_rceq;
        else
        {
            /* Depends on the fact that B-frame's QP is an offset from the following P-frame's.
             * Not perfectly accurate with B-refs, but good enough. */
            rc->cplxr_sum += bits * qp2qscale( rc->qpa_rc ) / (rc->last_rceq * h->param.rc.f_pb_factor);
        }
        rc->cplxr_sum *= rc->cbr_decay;
        rc->wanted_bits_window += h->fenc->f_duration * rc->bitrate;
        rc->wanted_bits_window *= rc->cbr_decay;
    }

    if( rc->b_2pass )
        rc->expected_bits_sum += qscale2bits( rc->rce, qp2qscale( rc->rce->new_qp ) );

    if( h->mb.b_variable_qp )
    {
        if( h->sh.i_type == SLICE_TYPE_B )
        {
            rc->bframe_bits += bits;
            if( h->fenc->b_last_minigop_bframe )
            {
                update_predictor( rc->pred_b_from_p, qp2qscale( rc->qpa_rc ),
                                  h->fref[1][h->i_ref[1]-1]->i_satd, rc->bframe_bits / rc->bframes );
                rc->bframe_bits = 0;
            }
        }
    }

    *filler = update_vbv( h, bits );
    rc->filler_bits_sum += *filler * 8;

    if( h->sps->vui.b_nal_hrd_parameters_present )
    {
        if( h->fenc->i_frame == 0 )
        {
            // access unit initialises the HRD
            h->fenc->hrd_timing.cpb_initial_arrival_time = 0;
            rc->initial_cpb_removal_delay = h->initial_cpb_removal_delay;
            rc->initial_cpb_removal_delay_offset = h->initial_cpb_removal_delay_offset;
            h->fenc->hrd_timing.cpb_removal_time = rc->nrt_first_access_unit = (double)rc->initial_cpb_removal_delay / 90000;
        }
        else
        {
            h->fenc->hrd_timing.cpb_removal_time = rc->nrt_first_access_unit + (double)(h->fenc->i_cpb_delay - h->i_cpb_delay_pir_offset) *
                                                   h->sps->vui.i_num_units_in_tick / h->sps->vui.i_time_scale;

            if( h->fenc->b_keyframe )
            {
                rc->nrt_first_access_unit = h->fenc->hrd_timing.cpb_removal_time;
                rc->initial_cpb_removal_delay = h->initial_cpb_removal_delay;
                rc->initial_cpb_removal_delay_offset = h->initial_cpb_removal_delay_offset;
            }

            double cpb_earliest_arrival_time = h->fenc->hrd_timing.cpb_removal_time - (double)rc->initial_cpb_removal_delay / 90000;
            if( !h->fenc->b_keyframe )
                cpb_earliest_arrival_time -= (double)rc->initial_cpb_removal_delay_offset / 90000;

            if( h->sps->vui.hrd.b_cbr_hrd )
                h->fenc->hrd_timing.cpb_initial_arrival_time = rc->previous_cpb_final_arrival_time;
            else
                h->fenc->hrd_timing.cpb_initial_arrival_time = X264_MAX( rc->previous_cpb_final_arrival_time, cpb_earliest_arrival_time );
        }
        int filler_bits = *filler ? X264_MAX( (FILLER_OVERHEAD - h->param.b_annexb), *filler )*8 : 0;
        // Equation C-6
        h->fenc->hrd_timing.cpb_final_arrival_time = rc->previous_cpb_final_arrival_time = h->fenc->hrd_timing.cpb_initial_arrival_time +
                                                     (double)(bits + filler_bits) / h->sps->vui.hrd.i_bit_rate_unscaled;

        h->fenc->hrd_timing.dpb_output_time = (double)h->fenc->i_dpb_output_delay * h->sps->vui.i_num_units_in_tick / h->sps->vui.i_time_scale +
                                              h->fenc->hrd_timing.cpb_removal_time;
    }

    return 0;
fail:
    x264_log( h, X264_LOG_ERROR, "ratecontrol_end: stats file could not be written to\n" );
    return -1;
}

/****************************************************************************
 * 2 pass functions
 ***************************************************************************/

/**
 * modify the bitrate curve from pass1 for one frame
 */
static double get_qscale(x264_t *h, ratecontrol_entry_t *rce, double rate_factor, int frame_num)
{
    x264_ratecontrol_t *rcc= h->rc;
    x264_zone_t *zone = get_zone( h, frame_num );
    double q;
    if( h->param.rc.b_mb_tree )
    {
        double timescale = (double)h->sps->vui.i_num_units_in_tick / h->sps->vui.i_time_scale;
        q = pow( BASE_FRAME_DURATION / CLIP_DURATION(rce->i_duration * timescale), 1 - h->param.rc.f_qcompress );
    }
    else
        q = pow( rce->blurred_complexity, 1 - rcc->qcompress );

    // avoid NaN's in the rc_eq
    if( !isfinite(q) || rce->tex_bits + rce->mv_bits == 0 )
        q = rcc->last_qscale_for[rce->pict_type];
    else
    {
        rcc->last_rceq = q;
        q /= rate_factor;
        rcc->last_qscale = q;
    }

    if( zone )
    {
        if( zone->b_force_qp )
            q = qp2qscale( zone->i_qp );
        else
            q /= zone->f_bitrate_factor;
    }

    return q;
}

static double get_diff_limited_q(x264_t *h, ratecontrol_entry_t *rce, double q, int frame_num)
{
    x264_ratecontrol_t *rcc = h->rc;
    const int pict_type = rce->pict_type;
    x264_zone_t *zone = get_zone( h, frame_num );

    // force I/B quants as a function of P quants
    if( pict_type == SLICE_TYPE_I )
    {
        double iq = q;
        double pq = qp2qscale( rcc->accum_p_qp / rcc->accum_p_norm );
        double ip_factor = h->param.rc.f_ip_factor;
        /* don't apply ip_factor if the following frame is also I */
        if( rcc->accum_p_norm <= 0 )
            q = iq;
        else if( rcc->accum_p_norm >= 1 )
            q = pq / ip_factor;
        else
            q = rcc->accum_p_norm * pq / ip_factor + (1 - rcc->accum_p_norm) * iq;
    }
    else if( pict_type == SLICE_TYPE_B )
    {
        q = rcc->last_qscale_for[rcc->last_non_b_pict_type];
        if( !rce->kept_as_ref )
            q *= h->param.rc.f_pb_factor;
    }
    else if( pict_type == SLICE_TYPE_P
             && rcc->last_non_b_pict_type == SLICE_TYPE_P
             && rce->tex_bits == 0 )
    {
        q = rcc->last_qscale_for[SLICE_TYPE_P];
    }

    /* last qscale / qdiff stuff */
    if( rcc->last_non_b_pict_type == pict_type &&
        (pict_type!=SLICE_TYPE_I || rcc->last_accum_p_norm < 1) )
    {
        double last_q = rcc->last_qscale_for[pict_type];
        double max_qscale = last_q * rcc->lstep;
        double min_qscale = last_q / rcc->lstep;

        if     ( q > max_qscale ) q = max_qscale;
        else if( q < min_qscale ) q = min_qscale;
    }

    rcc->last_qscale_for[pict_type] = q;
    if( pict_type != SLICE_TYPE_B )
        rcc->last_non_b_pict_type = pict_type;
    if( pict_type == SLICE_TYPE_I )
    {
        rcc->last_accum_p_norm = rcc->accum_p_norm;
        rcc->accum_p_norm = 0;
        rcc->accum_p_qp = 0;
    }
    if( pict_type == SLICE_TYPE_P )
    {
        float mask = 1 - pow( (float)rce->i_count / rcc->nmb, 2 );
        rcc->accum_p_qp   = mask * (qscale2qp( q ) + rcc->accum_p_qp);
        rcc->accum_p_norm = mask * (1 + rcc->accum_p_norm);
    }

    if( zone )
    {
        if( zone->b_force_qp )
            q = qp2qscale( zone->i_qp );
        else
            q /= zone->f_bitrate_factor;
    }

    return q;
}

static float predict_size( predictor_t *p, float q, float var )
{
    return (p->coeff*var + p->offset) / (q*p->count);
}

static void update_predictor( predictor_t *p, float q, float var, float bits )
{
    float range = 1.5;
    if( var < 10 )
        return;
    float old_coeff = p->coeff / p->count;
    float old_offset = p->offset / p->count;
    float new_coeff = X264_MAX( (bits*q - old_offset) / var, p->coeff_min );
    float new_coeff_clipped = x264_clip3f( new_coeff, old_coeff/range, old_coeff*range );
    float new_offset = bits*q - new_coeff_clipped * var;
    if( new_offset >= 0 )
        new_coeff = new_coeff_clipped;
    else
        new_offset = 0;
    p->count  *= p->decay;
    p->coeff  *= p->decay;
    p->offset *= p->decay;
    p->count  ++;
    p->coeff  += new_coeff;
    p->offset += new_offset;
}

// update VBV after encoding a frame
static int update_vbv( x264_t *h, int bits )
{
    int filler = 0;
    int bitrate = h->sps->vui.hrd.i_bit_rate_unscaled;
    x264_ratecontrol_t *rcc = h->rc;
    x264_ratecontrol_t *rct = h->thread[0]->rc;
    int64_t buffer_size = (int64_t)h->sps->vui.hrd.i_cpb_size_unscaled * h->sps->vui.i_time_scale;

    if( rcc->last_satd >= h->mb.i_mb_count )
        update_predictor( &rct->pred[h->sh.i_type], qp2qscale( rcc->qpa_rc ), rcc->last_satd, bits );

    if( !rcc->b_vbv )
        return filler;

    uint64_t buffer_diff = (uint64_t)bits * h->sps->vui.i_time_scale;
    rct->buffer_fill_final -= buffer_diff;
    rct->buffer_fill_final_min -= buffer_diff;

    if( rct->buffer_fill_final_min < 0 )
    {
        double underflow = (double)rct->buffer_fill_final_min / h->sps->vui.i_time_scale;
        if( rcc->rate_factor_max_increment && rcc->qpm >= rcc->qp_novbv + rcc->rate_factor_max_increment )
            x264_log( h, X264_LOG_DEBUG, "VBV underflow due to CRF-max (frame %d, %.0f bits)\n", h->i_frame, underflow );
        else
            x264_log( h, X264_LOG_WARNING, "VBV underflow (frame %d, %.0f bits)\n", h->i_frame, underflow );
        rct->buffer_fill_final =
        rct->buffer_fill_final_min = 0;
    }

    if( h->param.i_avcintra_class )
        buffer_diff = buffer_size;
    else
        buffer_diff = (uint64_t)bitrate * h->sps->vui.i_num_units_in_tick * h->fenc->i_cpb_duration;
    rct->buffer_fill_final += buffer_diff;
    rct->buffer_fill_final_min += buffer_diff;

    if( rct->buffer_fill_final > buffer_size )
    {
        if( h->param.rc.b_filler )
        {
            int64_t scale = (int64_t)h->sps->vui.i_time_scale * 8;
            filler = (rct->buffer_fill_final - buffer_size + scale - 1) / scale;
            bits = h->param.i_avcintra_class ? filler * 8 : X264_MAX( (FILLER_OVERHEAD - h->param.b_annexb), filler ) * 8;
            buffer_diff = (uint64_t)bits * h->sps->vui.i_time_scale;
            rct->buffer_fill_final -= buffer_diff;
            rct->buffer_fill_final_min -= buffer_diff;
        }
        else
        {
            rct->buffer_fill_final = X264_MIN( rct->buffer_fill_final, buffer_size );
            rct->buffer_fill_final_min = X264_MIN( rct->buffer_fill_final_min, buffer_size );
        }
    }

    return filler;
}

void x264_hrd_fullness( x264_t *h )
{
    x264_ratecontrol_t *rct = h->thread[0]->rc;
    uint64_t denom = (uint64_t)h->sps->vui.hrd.i_bit_rate_unscaled * h->sps->vui.i_time_scale / rct->hrd_multiply_denom;
    uint64_t cpb_state = rct->buffer_fill_final;
    uint64_t cpb_size = (uint64_t)h->sps->vui.hrd.i_cpb_size_unscaled * h->sps->vui.i_time_scale;
    uint64_t multiply_factor = 90000 / rct->hrd_multiply_denom;

    if( rct->buffer_fill_final < 0 || rct->buffer_fill_final > (int64_t)cpb_size )
    {
         x264_log( h, X264_LOG_WARNING, "CPB %s: %.0f bits in a %.0f-bit buffer\n",
                   rct->buffer_fill_final < 0 ? "underflow" : "overflow",
                   (double)rct->buffer_fill_final / h->sps->vui.i_time_scale, (double)cpb_size / h->sps->vui.i_time_scale );
    }

    h->initial_cpb_removal_delay = (multiply_factor * cpb_state) / denom;
    h->initial_cpb_removal_delay_offset = (multiply_factor * cpb_size) / denom - h->initial_cpb_removal_delay;

    int64_t decoder_buffer_fill = h->initial_cpb_removal_delay * denom / multiply_factor;
    rct->buffer_fill_final_min = X264_MIN( rct->buffer_fill_final_min, decoder_buffer_fill );
}

// provisionally update VBV according to the planned size of all frames currently in progress
static void update_vbv_plan( x264_t *h, int overhead )
{
    x264_ratecontrol_t *rcc = h->rc;
    rcc->buffer_fill = h->thread[0]->rc->buffer_fill_final_min / h->sps->vui.i_time_scale;
    if( h->i_thread_frames > 1 )
    {
        int j = rcc - h->thread[0]->rc;
        for( int i = 1; i < h->i_thread_frames; i++ )
        {
            x264_t *t = h->thread[ (j+i)%h->i_thread_frames ];
            double bits = t->rc->frame_size_planned;
            if( !t->b_thread_active )
                continue;
            bits = X264_MAX(bits, t->rc->frame_size_estimated);
            rcc->buffer_fill -= bits;
            rcc->buffer_fill = X264_MAX( rcc->buffer_fill, 0 );
            rcc->buffer_fill += t->rc->buffer_rate;
            rcc->buffer_fill = X264_MIN( rcc->buffer_fill, rcc->buffer_size );
        }
    }
    rcc->buffer_fill = X264_MIN( rcc->buffer_fill, rcc->buffer_size );
    rcc->buffer_fill -= overhead;
}

// apply VBV constraints and clip qscale to between lmin and lmax
static double clip_qscale( x264_t *h, int pict_type, double q )
{
    x264_ratecontrol_t *rcc = h->rc;
    double lmin = rcc->lmin[pict_type];
    double lmax = rcc->lmax[pict_type];
    if( rcc->rate_factor_max_increment )
        lmax = X264_MIN( lmax, qp2qscale( rcc->qp_novbv + rcc->rate_factor_max_increment ) );
    double q0 = q;

    /* B-frames are not directly subject to VBV,
     * since they are controlled by the P-frames' QPs. */

    if( rcc->b_vbv && rcc->last_satd > 0 )
    {
        double fenc_cpb_duration = (double)h->fenc->i_cpb_duration *
                                   h->sps->vui.i_num_units_in_tick / h->sps->vui.i_time_scale;
        /* Lookahead VBV: raise the quantizer as necessary such that no frames in
         * the lookahead overflow and such that the buffer is in a reasonable state
         * by the end of the lookahead. */
        if( h->param.rc.i_lookahead )
        {
            int terminate = 0;

            /* Avoid an infinite loop. */
            for( int iterations = 0; iterations < 1000 && terminate != 3; iterations++ )
            {
                double frame_q[3];
                double cur_bits = predict_size( &rcc->pred[h->sh.i_type], q, rcc->last_satd );
                double buffer_fill_cur = rcc->buffer_fill - cur_bits;
                double target_fill;
                double total_duration = 0;
                double last_duration = fenc_cpb_duration;
                frame_q[0] = h->sh.i_type == SLICE_TYPE_I ? q * h->param.rc.f_ip_factor : q;
                frame_q[1] = frame_q[0] * h->param.rc.f_pb_factor;
                frame_q[2] = frame_q[0] / h->param.rc.f_ip_factor;

                /* Loop over the planned future frames. */
                for( int j = 0; buffer_fill_cur >= 0 && buffer_fill_cur <= rcc->buffer_size; j++ )
                {
                    total_duration += last_duration;
                    buffer_fill_cur += rcc->vbv_max_rate * last_duration;
                    int i_type = h->fenc->i_planned_type[j];
                    int i_satd = h->fenc->i_planned_satd[j];
                    if( i_type == X264_TYPE_AUTO )
                        break;
                    i_type = IS_X264_TYPE_I( i_type ) ? SLICE_TYPE_I : IS_X264_TYPE_B( i_type ) ? SLICE_TYPE_B : SLICE_TYPE_P;
                    cur_bits = predict_size( &rcc->pred[i_type], frame_q[i_type], i_satd );
                    buffer_fill_cur -= cur_bits;
                    last_duration = h->fenc->f_planned_cpb_duration[j];
                }
                /* Try to get to get the buffer at least 50% filled, but don't set an impossible goal. */
                target_fill = X264_MIN( rcc->buffer_fill + total_duration * rcc->vbv_max_rate * 0.5, rcc->buffer_size * 0.5 );
                if( buffer_fill_cur < target_fill )
                {
                    q *= 1.01;
                    terminate |= 1;
                    continue;
                }
                /* Try to get the buffer no more than 80% filled, but don't set an impossible goal. */
                target_fill = x264_clip3f( rcc->buffer_fill - total_duration * rcc->vbv_max_rate * 0.5, rcc->buffer_size * 0.8, rcc->buffer_size );
                if( rcc->b_vbv_min_rate && buffer_fill_cur > target_fill )
                {
                    q /= 1.01;
                    terminate |= 2;
                    continue;
                }
                break;
            }
        }
        /* Fallback to old purely-reactive algorithm: no lookahead. */
        else
        {
            if( ( pict_type == SLICE_TYPE_P ||
                ( pict_type == SLICE_TYPE_I && rcc->last_non_b_pict_type == SLICE_TYPE_I ) ) &&
                rcc->buffer_fill/rcc->buffer_size < 0.5 )
            {
                q /= x264_clip3f( 2.0*rcc->buffer_fill/rcc->buffer_size, 0.5, 1.0 );
            }

            /* Now a hard threshold to make sure the frame fits in VBV.
             * This one is mostly for I-frames. */
            double bits = predict_size( &rcc->pred[h->sh.i_type], q, rcc->last_satd );
            /* For small VBVs, allow the frame to use up the entire VBV. */
            double max_fill_factor = h->param.rc.i_vbv_buffer_size >= 5*h->param.rc.i_vbv_max_bitrate / rcc->fps ? 2 : 1;
            /* For single-frame VBVs, request that the frame use up the entire VBV. */
            double min_fill_factor = rcc->single_frame_vbv ? 1 : 2;

            if( bits > rcc->buffer_fill/max_fill_factor )
            {
                double qf = x264_clip3f( rcc->buffer_fill/(max_fill_factor*bits), 0.2, 1.0 );
                q /= qf;
                bits *= qf;
            }
            if( bits < rcc->buffer_rate/min_fill_factor )
            {
                double qf = x264_clip3f( bits*min_fill_factor/rcc->buffer_rate, 0.001, 1.0 );
                q *= qf;
            }
            q = X264_MAX( q0, q );
        }

        /* Check B-frame complexity, and use up any bits that would
         * overflow before the next P-frame. */
        if( h->sh.i_type == SLICE_TYPE_P && !rcc->single_frame_vbv )
        {
            int nb = rcc->bframes;
            double bits = predict_size( &rcc->pred[h->sh.i_type], q, rcc->last_satd );
            double pbbits = bits;
            double bbits = predict_size( rcc->pred_b_from_p, q * h->param.rc.f_pb_factor, rcc->last_satd );
            double space;
            double bframe_cpb_duration = 0;
            double minigop_cpb_duration;
            for( int i = 0; i < nb; i++ )
                bframe_cpb_duration += h->fenc->f_planned_cpb_duration[i];

            if( bbits * nb > bframe_cpb_duration * rcc->vbv_max_rate )
            {
                nb = 0;
                bframe_cpb_duration = 0;
            }
            pbbits += nb * bbits;

            minigop_cpb_duration = bframe_cpb_duration + fenc_cpb_duration;
            space = rcc->buffer_fill + minigop_cpb_duration*rcc->vbv_max_rate - rcc->buffer_size;
            if( pbbits < space )
            {
                q *= X264_MAX( pbbits / space, bits / (0.5 * rcc->buffer_size) );
            }
            q = X264_MAX( q0/2, q );
        }

        /* Apply MinCR and buffer fill restrictions */
        double bits = predict_size( &rcc->pred[h->sh.i_type], q, rcc->last_satd );
        double frame_size_maximum = X264_MIN( rcc->frame_size_maximum, X264_MAX( rcc->buffer_fill, 0.001 ) );
        if( bits > frame_size_maximum )
            q *= bits / frame_size_maximum;

        if( !rcc->b_vbv_min_rate )
            q = X264_MAX( q0, q );
    }

    if( lmin==lmax )
        return lmin;
    else if( rcc->b_2pass )
    {
        double min2 = log( lmin );
        double max2 = log( lmax );
        q = (log(q) - min2)/(max2-min2) - 0.5;
        q = 1.0/(1.0 + exp( -4*q ));
        q = q*(max2-min2) + min2;
        return exp( q );
    }
    else
        return x264_clip3f( q, lmin, lmax );
}

// update qscale for 1 frame based on actual bits used so far
static float rate_estimate_qscale( x264_t *h )
{
    float q;
    x264_ratecontrol_t *rcc = h->rc;
    ratecontrol_entry_t rce = {0};
    int pict_type = h->sh.i_type;
    int64_t total_bits = 8*(h->stat.i_frame_size[SLICE_TYPE_I]
                          + h->stat.i_frame_size[SLICE_TYPE_P]
                          + h->stat.i_frame_size[SLICE_TYPE_B])
                       - rcc->filler_bits_sum;

    if( rcc->b_2pass )
    {
        rce = *rcc->rce;
        if( pict_type != rce.pict_type )
        {
            x264_log( h, X264_LOG_ERROR, "slice=%c but 2pass stats say %c\n",
                      slice_type_to_char[pict_type], slice_type_to_char[rce.pict_type] );
        }
    }

    if( pict_type == SLICE_TYPE_B )
    {
        /* B-frames don't have independent ratecontrol, but rather get the
         * average QP of the two adjacent P-frames + an offset */

        int i0 = IS_X264_TYPE_I(h->fref_nearest[0]->i_type);
        int i1 = IS_X264_TYPE_I(h->fref_nearest[1]->i_type);
        int dt0 = abs(h->fenc->i_poc - h->fref_nearest[0]->i_poc);
        int dt1 = abs(h->fenc->i_poc - h->fref_nearest[1]->i_poc);
        float q0 = h->fref_nearest[0]->f_qp_avg_rc;
        float q1 = h->fref_nearest[1]->f_qp_avg_rc;

        if( h->fref_nearest[0]->i_type == X264_TYPE_BREF )
            q0 -= rcc->pb_offset/2;
        if( h->fref_nearest[1]->i_type == X264_TYPE_BREF )
            q1 -= rcc->pb_offset/2;

        if( i0 && i1 )
            q = (q0 + q1) / 2 + rcc->ip_offset;
        else if( i0 )
            q = q1;
        else if( i1 )
            q = q0;
        else
            q = (q0*dt1 + q1*dt0) / (dt0 + dt1);

        if( h->fenc->b_kept_as_ref )
            q += rcc->pb_offset/2;
        else
            q += rcc->pb_offset;

        rcc->qp_novbv = q;
        q = qp2qscale( q );
        if( rcc->b_2pass )
            rcc->frame_size_planned = qscale2bits( &rce, q );
        else
            rcc->frame_size_planned = predict_size( rcc->pred_b_from_p, q, h->fref[1][h->i_ref[1]-1]->i_satd );
        /* Limit planned size by MinCR */
        if( rcc->b_vbv )
            rcc->frame_size_planned = X264_MIN( rcc->frame_size_planned, rcc->frame_size_maximum );
        rcc->frame_size_estimated = rcc->frame_size_planned;

        /* For row SATDs */
        if( rcc->b_vbv )
            rcc->last_satd = x264_rc_analyse_slice( h );
        return q;
    }
    else
    {
        double abr_buffer = 2 * rcc->rate_tolerance * rcc->bitrate;
        double predicted_bits = total_bits;
        if( h->i_thread_frames > 1 )
        {
            int j = rcc - h->thread[0]->rc;
            for( int i = 1; i < h->i_thread_frames; i++ )
            {
                x264_t *t = h->thread[(j+i) % h->i_thread_frames];
                double bits = t->rc->frame_size_planned;
                if( !t->b_thread_active )
                    continue;
                bits = X264_MAX(bits, t->rc->frame_size_estimated);
                predicted_bits += bits;
            }
        }

        if( rcc->b_2pass )
        {
            double lmin = rcc->lmin[pict_type];
            double lmax = rcc->lmax[pict_type];
            double diff;

            /* Adjust ABR buffer based on distance to the end of the video. */
            if( rcc->num_entries > h->i_frame )
            {
                double final_bits = rcc->entry_out[rcc->num_entries-1]->expected_bits;
                double video_pos = rce.expected_bits / final_bits;
                double scale_factor = sqrt( (1 - video_pos) * rcc->num_entries );
                abr_buffer *= 0.5 * X264_MAX( scale_factor, 0.5 );
            }

            diff = predicted_bits - rce.expected_bits;
            q = rce.new_qscale;
            q /= x264_clip3f((abr_buffer - diff) / abr_buffer, .5, 2);
            if( h->i_frame >= rcc->fps && rcc->expected_bits_sum >= 1 )
            {
                /* Adjust quant based on the difference between
                 * achieved and expected bitrate so far */
                double cur_time = (double)h->i_frame / rcc->num_entries;
                double w = x264_clip3f( cur_time*100, 0.0, 1.0 );
                q *= pow( (double)total_bits / rcc->expected_bits_sum, w );
            }
            rcc->qp_novbv = qscale2qp( q );
            if( rcc->b_vbv )
            {
                /* Do not overflow vbv */
                double expected_size = qscale2bits( &rce, q );
                double expected_vbv = rcc->buffer_fill + rcc->buffer_rate - expected_size;
                double expected_fullness = rce.expected_vbv / rcc->buffer_size;
                double qmax = q*(2 - expected_fullness);
                double size_constraint = 1 + expected_fullness;
                qmax = X264_MAX( qmax, rce.new_qscale );
                if( expected_fullness < .05 )
                    qmax = lmax;
                qmax = X264_MIN(qmax, lmax);
                while( ((expected_vbv < rce.expected_vbv/size_constraint) && (q < qmax)) ||
                        ((expected_vbv < 0) && (q < lmax)))
                {
                    q *= 1.05;
                    expected_size = qscale2bits(&rce, q);
                    expected_vbv = rcc->buffer_fill + rcc->buffer_rate - expected_size;
                }
                rcc->last_satd = x264_rc_analyse_slice( h );
            }
            q = x264_clip3f( q, lmin, lmax );
        }
        else /* 1pass ABR */
        {
            /* Calculate the quantizer which would have produced the desired
             * average bitrate if it had been applied to all frames so far.
             * Then modulate that quant based on the current frame's complexity
             * relative to the average complexity so far (using the 2pass RCEQ).
             * Then bias the quant up or down if total size so far was far from
             * the target.
             * Result: Depending on the value of rate_tolerance, there is a
             * tradeoff between quality and bitrate precision. But at large
             * tolerances, the bit distribution approaches that of 2pass. */

            double wanted_bits, overflow = 1;

            rcc->last_satd = x264_rc_analyse_slice( h );
            rcc->short_term_cplxsum *= 0.5;
            rcc->short_term_cplxcount *= 0.5;
            rcc->short_term_cplxsum += rcc->last_satd / (CLIP_DURATION(h->fenc->f_duration) / BASE_FRAME_DURATION);
            rcc->short_term_cplxcount ++;

            rce.tex_bits = rcc->last_satd;
            rce.blurred_complexity = rcc->short_term_cplxsum / rcc->short_term_cplxcount;
            rce.mv_bits = 0;
            rce.p_count = rcc->nmb;
            rce.i_count = 0;
            rce.s_count = 0;
            rce.qscale = 1;
            rce.pict_type = pict_type;
            rce.i_duration = h->fenc->i_duration;

            if( h->param.rc.i_rc_method == X264_RC_CRF )
            {
                q = get_qscale( h, &rce, rcc->rate_factor_constant, h->fenc->i_frame );
            }
            else
            {
                q = get_qscale( h, &rce, rcc->wanted_bits_window / rcc->cplxr_sum, h->fenc->i_frame );

                /* ABR code can potentially be counterproductive in CBR, so just don't bother.
                 * Don't run it if the frame complexity is zero either. */
                if( !rcc->b_vbv_min_rate && rcc->last_satd )
                {
                    // FIXME is it simpler to keep track of wanted_bits in ratecontrol_end?
                    int i_frame_done = h->i_frame;
                    double time_done = i_frame_done / rcc->fps;
                    if( h->param.b_vfr_input && i_frame_done > 0 )
                        time_done = ((double)(h->fenc->i_reordered_pts - h->i_reordered_pts_delay)) * h->param.i_timebase_num / h->param.i_timebase_den;
                    wanted_bits = time_done * rcc->bitrate;
                    if( wanted_bits > 0 )
                    {
                        abr_buffer *= X264_MAX( 1, sqrt( time_done ) );
                        overflow = x264_clip3f( 1.0 + (predicted_bits - wanted_bits) / abr_buffer, .5, 2 );
                        q *= overflow;
                    }
                }
            }

            if( pict_type == SLICE_TYPE_I && h->param.i_keyint_max > 1
                /* should test _next_ pict type, but that isn't decided yet */
                && rcc->last_non_b_pict_type != SLICE_TYPE_I )
            {
                q = qp2qscale( rcc->accum_p_qp / rcc->accum_p_norm );
                q /= h->param.rc.f_ip_factor;
            }
            else if( h->i_frame > 0 )
            {
                if( h->param.rc.i_rc_method != X264_RC_CRF )
                {
                    /* Asymmetric clipping, because symmetric would prevent
                     * overflow control in areas of rapidly oscillating complexity */
                    double lmin = rcc->last_qscale_for[pict_type] / rcc->lstep;
                    double lmax = rcc->last_qscale_for[pict_type] * rcc->lstep;
                    if( overflow > 1.1 && h->i_frame > 3 )
                        lmax *= rcc->lstep;
                    else if( overflow < 0.9 )
                        lmin /= rcc->lstep;

                    q = x264_clip3f(q, lmin, lmax);
                }
            }
            else if( h->param.rc.i_rc_method == X264_RC_CRF && rcc->qcompress != 1 )
            {
                q = qp2qscale( ABR_INIT_QP ) / h->param.rc.f_ip_factor;
            }
            rcc->qp_novbv = qscale2qp( q );

            //FIXME use get_diff_limited_q() ?
            q = clip_qscale( h, pict_type, q );
        }

        rcc->last_qscale_for[pict_type] =
        rcc->last_qscale = q;

        if( !(rcc->b_2pass && !rcc->b_vbv) && h->fenc->i_frame == 0 )
            rcc->last_qscale_for[SLICE_TYPE_P] = q * h->param.rc.f_ip_factor;

        if( rcc->b_2pass )
            rcc->frame_size_planned = qscale2bits( &rce, q );
        else
            rcc->frame_size_planned = predict_size( &rcc->pred[h->sh.i_type], q, rcc->last_satd );

        /* Always use up the whole VBV in this case. */
        if( rcc->single_frame_vbv )
            rcc->frame_size_planned = rcc->buffer_rate;
        /* Limit planned size by MinCR */
        if( rcc->b_vbv )
            rcc->frame_size_planned = X264_MIN( rcc->frame_size_planned, rcc->frame_size_maximum );
        rcc->frame_size_estimated = rcc->frame_size_planned;
        return q;
    }
}

static void threads_normalize_predictors( x264_t *h )
{
    double totalsize = 0;
    for( int i = 0; i < h->param.i_threads; i++ )
        totalsize += h->thread[i]->rc->slice_size_planned;
    double factor = h->rc->frame_size_planned / totalsize;
    for( int i = 0; i < h->param.i_threads; i++ )
        h->thread[i]->rc->slice_size_planned *= factor;
}

void x264_threads_distribute_ratecontrol( x264_t *h )
{
    int row;
    x264_ratecontrol_t *rc = h->rc;
    x264_emms();
    float qscale = qp2qscale( rc->qpm );

    /* Initialize row predictors */
    if( h->i_frame == 0 )
        for( int i = 0; i < h->param.i_threads; i++ )
        {
            x264_t *t = h->thread[i];
            if( t != h )
                memcpy( t->rc->row_preds, rc->row_preds, sizeof(rc->row_preds) );
        }

    for( int i = 0; i < h->param.i_threads; i++ )
    {
        x264_t *t = h->thread[i];
        if( t != h )
            memcpy( t->rc, rc, offsetof(x264_ratecontrol_t, row_pred) );
        t->rc->row_pred = t->rc->row_preds[h->sh.i_type];
        /* Calculate the planned slice size. */
        if( rc->b_vbv && rc->frame_size_planned )
        {
            int size = 0;
            for( row = t->i_threadslice_start; row < t->i_threadslice_end; row++ )
                size += h->fdec->i_row_satd[row];
            t->rc->slice_size_planned = predict_size( &rc->pred[h->sh.i_type + (i+1)*5], qscale, size );
        }
        else
            t->rc->slice_size_planned = 0;
    }
    if( rc->b_vbv && rc->frame_size_planned )
    {
        threads_normalize_predictors( h );

        if( rc->single_frame_vbv )
        {
            /* Compensate for our max frame error threshold: give more bits (proportionally) to smaller slices. */
            for( int i = 0; i < h->param.i_threads; i++ )
            {
                x264_t *t = h->thread[i];
                float max_frame_error = x264_clip3f( 1.0 / (t->i_threadslice_end - t->i_threadslice_start), 0.05, 0.25 );
                t->rc->slice_size_planned += 2 * max_frame_error * rc->frame_size_planned;
            }
            threads_normalize_predictors( h );
        }

        for( int i = 0; i < h->param.i_threads; i++ )
            h->thread[i]->rc->frame_size_estimated = h->thread[i]->rc->slice_size_planned;
    }
}

void x264_threads_merge_ratecontrol( x264_t *h )
{
    x264_ratecontrol_t *rc = h->rc;
    x264_emms();

    for( int i = 0; i < h->param.i_threads; i++ )
    {
        x264_t *t = h->thread[i];
        x264_ratecontrol_t *rct = h->thread[i]->rc;
        if( h->param.rc.i_vbv_buffer_size )
        {
            int size = 0;
            for( int row = t->i_threadslice_start; row < t->i_threadslice_end; row++ )
                size += h->fdec->i_row_satd[row];
            int bits = t->stat.frame.i_mv_bits + t->stat.frame.i_tex_bits + t->stat.frame.i_misc_bits;
            int mb_count = (t->i_threadslice_end - t->i_threadslice_start) * h->mb.i_mb_width;
            update_predictor( &rc->pred[h->sh.i_type+(i+1)*5], qp2qscale( rct->qpa_rc/mb_count ), size, bits );
        }
        if( !i )
            continue;
        rc->qpa_rc += rct->qpa_rc;
        rc->qpa_aq += rct->qpa_aq;
    }
}

void x264_thread_sync_ratecontrol( x264_t *cur, x264_t *prev, x264_t *next )
{
    if( cur != prev )
    {
#define COPY(var) memcpy(&cur->rc->var, &prev->rc->var, sizeof(cur->rc->var))
        /* these vars are updated in x264_ratecontrol_start()
         * so copy them from the context that most recently started (prev)
         * to the context that's about to start (cur). */
        COPY(accum_p_qp);
        COPY(accum_p_norm);
        COPY(last_satd);
        COPY(last_rceq);
        COPY(last_qscale_for);
        COPY(last_non_b_pict_type);
        COPY(short_term_cplxsum);
        COPY(short_term_cplxcount);
        COPY(bframes);
        COPY(prev_zone);
        COPY(mbtree.qpbuf_pos);
        /* these vars can be updated by x264_ratecontrol_init_reconfigurable */
        COPY(bitrate);
        COPY(buffer_size);
        COPY(buffer_rate);
        COPY(vbv_max_rate);
        COPY(single_frame_vbv);
        COPY(cbr_decay);
        COPY(rate_factor_constant);
        COPY(rate_factor_max_increment);
#undef COPY
    }
    if( cur != next )
    {
#define COPY(var) next->rc->var = cur->rc->var
        /* these vars are updated in x264_ratecontrol_end()
         * so copy them from the context that most recently ended (cur)
         * to the context that's about to end (next) */
        COPY(cplxr_sum);
        COPY(expected_bits_sum);
        COPY(filler_bits_sum);
        COPY(wanted_bits_window);
        COPY(bframe_bits);
        COPY(initial_cpb_removal_delay);
        COPY(initial_cpb_removal_delay_offset);
        COPY(nrt_first_access_unit);
        COPY(previous_cpb_final_arrival_time);
#undef COPY
    }
    //FIXME row_preds[] (not strictly necessary, but would improve prediction)
    /* the rest of the variables are either constant or thread-local */
}

static int find_underflow( x264_t *h, double *fills, int *t0, int *t1, int over )
{
    /* find an interval ending on an overflow or underflow (depending on whether
     * we're adding or removing bits), and starting on the earliest frame that
     * can influence the buffer fill of that end frame. */
    x264_ratecontrol_t *rcc = h->rc;
    const double buffer_min = .1 * rcc->buffer_size;
    const double buffer_max = .9 * rcc->buffer_size;
    double fill = fills[*t0-1];
    double parity = over ? 1. : -1.;
    int start = -1, end = -1;
    for( int i = *t0; i < rcc->num_entries; i++ )
    {
        fill += (rcc->entry_out[i]->i_cpb_duration * rcc->vbv_max_rate * h->sps->vui.i_num_units_in_tick / h->sps->vui.i_time_scale -
                 qscale2bits( rcc->entry_out[i], rcc->entry_out[i]->new_qscale )) * parity;
        fill = x264_clip3f(fill, 0, rcc->buffer_size);
        fills[i] = fill;
        if( fill <= buffer_min || i == 0 )
        {
            if( end >= 0 )
                break;
            start = i;
        }
        else if( fill >= buffer_max && start >= 0 )
            end = i;
    }
    *t0 = start;
    *t1 = end;
    return start >= 0 && end >= 0;
}

static int fix_underflow( x264_t *h, int t0, int t1, double adjustment, double qscale_min, double qscale_max )
{
    x264_ratecontrol_t *rcc = h->rc;
    double qscale_orig, qscale_new;
    int adjusted = 0;
    if( t0 > 0 )
        t0++;
    for( int i = t0; i <= t1; i++ )
    {
        qscale_orig = rcc->entry_out[i]->new_qscale;
        qscale_orig = x264_clip3f( qscale_orig, qscale_min, qscale_max );
        qscale_new  = qscale_orig * adjustment;
        qscale_new  = x264_clip3f( qscale_new, qscale_min, qscale_max );
        rcc->entry_out[i]->new_qscale = qscale_new;
        adjusted = adjusted || (qscale_new != qscale_orig);
    }
    return adjusted;
}

static double count_expected_bits( x264_t *h )
{
    x264_ratecontrol_t *rcc = h->rc;
    double expected_bits = 0;
    for( int i = 0; i < rcc->num_entries; i++ )
    {
        ratecontrol_entry_t *rce = rcc->entry_out[i];
        rce->expected_bits = expected_bits;
        expected_bits += qscale2bits( rce, rce->new_qscale );
    }
    return expected_bits;
}

static int vbv_pass2( x264_t *h, double all_available_bits )
{
    /* for each interval of buffer_full .. underflow, uniformly increase the qp of all
     * frames in the interval until either buffer is full at some intermediate frame or the
     * last frame in the interval no longer underflows.  Recompute intervals and repeat.
     * Then do the converse to put bits back into overflow areas until target size is met */

    x264_ratecontrol_t *rcc = h->rc;
    double *fills;
    double expected_bits = 0;
    double adjustment;
    double prev_bits = 0;
    int t0, t1;
    double qscale_min = qp2qscale( h->param.rc.i_qp_min );
    double qscale_max = qp2qscale( h->param.rc.i_qp_max );
    int iterations = 0;
    int adj_min, adj_max;
    CHECKED_MALLOC( fills, (rcc->num_entries+1)*sizeof(double) );

    fills++;

    /* adjust overall stream size */
    do
    {
        iterations++;
        prev_bits = expected_bits;

        if( expected_bits )
        {   /* not first iteration */
            adjustment = X264_MAX(X264_MIN(expected_bits / all_available_bits, 0.999), 0.9);
            fills[-1] = rcc->buffer_size * h->param.rc.f_vbv_buffer_init;
            t0 = 0;
            /* fix overflows */
            adj_min = 1;
            while( adj_min && find_underflow( h, fills, &t0, &t1, 1 ) )
            {
                adj_min = fix_underflow( h, t0, t1, adjustment, qscale_min, qscale_max );
                t0 = t1;
            }
        }

        fills[-1] = rcc->buffer_size * (1. - h->param.rc.f_vbv_buffer_init);
        t0 = 0;
        /* fix underflows -- should be done after overflow, as we'd better undersize target than underflowing VBV */
        adj_max = 1;
        while( adj_max && find_underflow( h, fills, &t0, &t1, 0 ) )
            adj_max = fix_underflow( h, t0, t1, 1.001, qscale_min, qscale_max );

        expected_bits = count_expected_bits( h );
    } while( (expected_bits < .995*all_available_bits) && ((int64_t)(expected_bits+.5) > (int64_t)(prev_bits+.5)) );

    if( !adj_max )
        x264_log( h, X264_LOG_WARNING, "vbv-maxrate issue, qpmax or vbv-maxrate too low\n");

    /* store expected vbv filling values for tracking when encoding */
    for( int i = 0; i < rcc->num_entries; i++ )
        rcc->entry_out[i]->expected_vbv = rcc->buffer_size - fills[i];

    x264_free( fills-1 );
    return 0;
fail:
    return -1;
}

static int init_pass2( x264_t *h )
{
    x264_ratecontrol_t *rcc = h->rc;
    uint64_t all_const_bits = 0;
    double timescale = (double)h->sps->vui.i_num_units_in_tick / h->sps->vui.i_time_scale;
    double duration = 0;
    for( int i = 0; i < rcc->num_entries; i++ )
        duration += rcc->entry[i].i_duration;
    duration *= timescale;
    uint64_t all_available_bits = h->param.rc.i_bitrate * 1000. * duration;
    double rate_factor, step_mult;
    double qblur = h->param.rc.f_qblur;
    double cplxblur = h->param.rc.f_complexity_blur;
    const int filter_size = (int)(qblur*4) | 1;
    double expected_bits;
    double *qscale, *blurred_qscale;
    double base_cplx = h->mb.i_mb_count * (h->param.i_bframe ? 120 : 80);

    /* find total/average complexity & const_bits */
    for( int i = 0; i < rcc->num_entries; i++ )
    {
        ratecontrol_entry_t *rce = &rcc->entry[i];
        all_const_bits += rce->misc_bits;
    }

    if( all_available_bits < all_const_bits)
    {
        x264_log( h, X264_LOG_ERROR, "requested bitrate is too low. estimated minimum is %d kbps\n",
                 (int)(all_const_bits * rcc->fps / (rcc->num_entries * 1000.)) );
        return -1;
    }

    /* Blur complexities, to reduce local fluctuation of QP.
     * We don't blur the QPs directly, because then one very simple frame
     * could drag down the QP of a nearby complex frame and give it more
     * bits than intended. */
    for( int i = 0; i < rcc->num_entries; i++ )
    {
        ratecontrol_entry_t *rce = &rcc->entry[i];
        double weight_sum = 0;
        double cplx_sum = 0;
        double weight = 1.0;
        double gaussian_weight;
        /* weighted average of cplx of future frames */
        for( int j = 1; j < cplxblur*2 && j < rcc->num_entries-i; j++ )
        {
            ratecontrol_entry_t *rcj = &rcc->entry[i+j];
            double frame_duration = CLIP_DURATION(rcj->i_duration * timescale) / BASE_FRAME_DURATION;
            weight *= 1 - pow( (float)rcj->i_count / rcc->nmb, 2 );
            if( weight < .0001 )
                break;
            gaussian_weight = weight * exp( -j*j/200.0 );
            weight_sum += gaussian_weight;
            cplx_sum += gaussian_weight * (qscale2bits( rcj, 1 ) - rcj->misc_bits) / frame_duration;
        }
        /* weighted average of cplx of past frames */
        weight = 1.0;
        for( int j = 0; j <= cplxblur*2 && j <= i; j++ )
        {
            ratecontrol_entry_t *rcj = &rcc->entry[i-j];
            double frame_duration = CLIP_DURATION(rcj->i_duration * timescale) / BASE_FRAME_DURATION;
            gaussian_weight = weight * exp( -j*j/200.0 );
            weight_sum += gaussian_weight;
            cplx_sum += gaussian_weight * (qscale2bits( rcj, 1 ) - rcj->misc_bits) / frame_duration;
            weight *= 1 - pow( (float)rcj->i_count / rcc->nmb, 2 );
            if( weight < .0001 )
                break;
        }
        rce->blurred_complexity = cplx_sum / weight_sum;
    }

    CHECKED_MALLOC( qscale, sizeof(double)*rcc->num_entries );
    if( filter_size > 1 )
        CHECKED_MALLOC( blurred_qscale, sizeof(double)*rcc->num_entries );
    else
        blurred_qscale = qscale;

    /* Search for a factor which, when multiplied by the RCEQ values from
     * each frame, adds up to the desired total size.
     * There is no exact closed-form solution because of VBV constraints and
     * because qscale2bits is not invertible, but we can start with the simple
     * approximation of scaling the 1st pass by the ratio of bitrates.
     * The search range is probably overkill, but speed doesn't matter here. */

    expected_bits = 1;
    for( int i = 0; i < rcc->num_entries; i++ )
    {
        double q = get_qscale(h, &rcc->entry[i], 1.0, i);
        expected_bits += qscale2bits(&rcc->entry[i], q);
        rcc->last_qscale_for[rcc->entry[i].pict_type] = q;
    }
    step_mult = all_available_bits / expected_bits;

    rate_factor = 0;
    for( double step = 1E4 * step_mult; step > 1E-7 * step_mult; step *= 0.5)
    {
        expected_bits = 0;
        rate_factor += step;

        rcc->last_non_b_pict_type = -1;
        rcc->last_accum_p_norm = 1;
        rcc->accum_p_norm = 0;

        rcc->last_qscale_for[0] =
        rcc->last_qscale_for[1] =
        rcc->last_qscale_for[2] = pow( base_cplx, 1 - rcc->qcompress ) / rate_factor;

        /* find qscale */
        for( int i = 0; i < rcc->num_entries; i++ )
        {
            qscale[i] = get_qscale( h, &rcc->entry[i], rate_factor, -1 );
            rcc->last_qscale_for[rcc->entry[i].pict_type] = qscale[i];
        }

        /* fixed I/B qscale relative to P */
        for( int i = rcc->num_entries-1; i >= 0; i-- )
        {
            qscale[i] = get_diff_limited_q( h, &rcc->entry[i], qscale[i], i );
            assert(qscale[i] >= 0);
        }

        /* smooth curve */
        if( filter_size > 1 )
        {
            assert( filter_size%2 == 1 );
            for( int i = 0; i < rcc->num_entries; i++ )
            {
                ratecontrol_entry_t *rce = &rcc->entry[i];
                double q = 0.0, sum = 0.0;

                for( int j = 0; j < filter_size; j++ )
                {
                    int idx = i+j-filter_size/2;
                    double d = idx-i;
                    double coeff = qblur==0 ? 1.0 : exp( -d*d/(qblur*qblur) );
                    if( idx < 0 || idx >= rcc->num_entries )
                        continue;
                    if( rce->pict_type != rcc->entry[idx].pict_type )
                        continue;
                    q += qscale[idx] * coeff;
                    sum += coeff;
                }
                blurred_qscale[i] = q/sum;
            }
        }

        /* find expected bits */
        for( int i = 0; i < rcc->num_entries; i++ )
        {
            ratecontrol_entry_t *rce = &rcc->entry[i];
            rce->new_qscale = clip_qscale( h, rce->pict_type, blurred_qscale[i] );
            assert(rce->new_qscale >= 0);
            expected_bits += qscale2bits( rce, rce->new_qscale );
        }

        if( expected_bits > all_available_bits )
            rate_factor -= step;
    }

    x264_free( qscale );
    if( filter_size > 1 )
        x264_free( blurred_qscale );

    if( rcc->b_vbv )
        if( vbv_pass2( h, all_available_bits ) )
            return -1;
    expected_bits = count_expected_bits( h );

    if( fabs( expected_bits/all_available_bits - 1.0 ) > 0.01 )
    {
        double avgq = 0;
        for( int i = 0; i < rcc->num_entries; i++ )
            avgq += rcc->entry[i].new_qscale;
        avgq = qscale2qp( avgq / rcc->num_entries );

        if( expected_bits > all_available_bits || !rcc->b_vbv )
            x264_log( h, X264_LOG_WARNING, "Error: 2pass curve failed to converge\n" );
        x264_log( h, X264_LOG_WARNING, "target: %.2f kbit/s, expected: %.2f kbit/s, avg QP: %.4f\n",
                  (float)h->param.rc.i_bitrate,
                  expected_bits * rcc->fps / (rcc->num_entries * 1000.),
                  avgq );
        if( expected_bits < all_available_bits && avgq < h->param.rc.i_qp_min + 2 )
        {
            if( h->param.rc.i_qp_min > 0 )
                x264_log( h, X264_LOG_WARNING, "try reducing target bitrate or reducing qp_min (currently %d)\n", h->param.rc.i_qp_min );
            else
                x264_log( h, X264_LOG_WARNING, "try reducing target bitrate\n" );
        }
        else if( expected_bits > all_available_bits && avgq > h->param.rc.i_qp_max - 2 )
        {
            if( h->param.rc.i_qp_max < QP_MAX )
                x264_log( h, X264_LOG_WARNING, "try increasing target bitrate or increasing qp_max (currently %d)\n", h->param.rc.i_qp_max );
            else
                x264_log( h, X264_LOG_WARNING, "try increasing target bitrate\n");
        }
        else if( !(rcc->b_2pass && rcc->b_vbv) )
            x264_log( h, X264_LOG_WARNING, "internal error\n" );
    }

    return 0;
fail:
    return -1;
}
