/*****************************************************************************
 * slicetype.c: lookahead analysis
 *****************************************************************************
 * Copyright (C) 2005-2022 x264 project
 *
 * Authors: Fiona Glaser <fiona@x264.com>
 *          Loren Merritt <lorenm@u.washington.edu>
 *          Dylan Yudaken <dyudaken@gmail.com>
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
#include "macroblock.h"
#include "me.h"

// Indexed by pic_struct values
static const uint8_t delta_tfi_divisor[10] = { 0, 2, 1, 1, 2, 2, 3, 3, 4, 6 };

static int slicetype_frame_cost( x264_t *h, x264_mb_analysis_t *a,
                                 x264_frame_t **frames, int p0, int p1, int b );

#define x264_weights_analyse x264_template(weights_analyse)
void x264_weights_analyse( x264_t *h, x264_frame_t *fenc, x264_frame_t *ref, int b_lookahead );

#if HAVE_OPENCL
#include "slicetype-cl.h"
#endif

static void lowres_context_init( x264_t *h, x264_mb_analysis_t *a )
{
    a->i_qp = X264_LOOKAHEAD_QP;
    a->i_lambda = x264_lambda_tab[ a->i_qp ];
    mb_analyse_load_costs( h, a );
    if( h->param.analyse.i_subpel_refine > 1 )
    {
        h->mb.i_me_method = X264_MIN( X264_ME_HEX, h->param.analyse.i_me_method );
        h->mb.i_subpel_refine = 4;
    }
    else
    {
        h->mb.i_me_method = X264_ME_DIA;
        h->mb.i_subpel_refine = 2;
    }
    h->mb.b_chroma_me = 0;
}

/* makes a non-h264 weight (i.e. fix7), into an h264 weight */
static void weight_get_h264( int weight_nonh264, int offset, x264_weight_t *w )
{
    w->i_offset = offset;
    w->i_denom = 7;
    w->i_scale = weight_nonh264;
    while( w->i_denom > 0 && (w->i_scale > 127) )
    {
        w->i_denom--;
        w->i_scale >>= 1;
    }
    w->i_scale = X264_MIN( w->i_scale, 127 );
}

static NOINLINE pixel *weight_cost_init_luma( x264_t *h, x264_frame_t *fenc, x264_frame_t *ref, pixel *dest )
{
    int ref0_distance = fenc->i_frame - ref->i_frame - 1;
    /* Note: this will never run during lookahead as weights_analyse is only called if no
     * motion search has been done. */
    if( fenc->lowres_mvs[0][ref0_distance][0][0] != 0x7FFF )
    {
        int i_stride = fenc->i_stride_lowres;
        int i_lines = fenc->i_lines_lowres;
        int i_width = fenc->i_width_lowres;
        int i_mb_xy = 0;
        pixel *p = dest;

        for( int y = 0; y < i_lines; y += 8, p += i_stride*8 )
            for( int x = 0; x < i_width; x += 8, i_mb_xy++ )
            {
                int mvx = fenc->lowres_mvs[0][ref0_distance][i_mb_xy][0];
                int mvy = fenc->lowres_mvs[0][ref0_distance][i_mb_xy][1];
                h->mc.mc_luma( p+x, i_stride, ref->lowres, i_stride,
                               mvx+(x<<2), mvy+(y<<2), 8, 8, x264_weight_none );
            }
        x264_emms();
        return dest;
    }
    x264_emms();
    return ref->lowres[0];
}

/* How data is organized for 4:2:0/4:2:2 chroma weightp:
 * [U: ref] [U: fenc]
 * [V: ref] [V: fenc]
 * fenc = ref + offset
 * v = u + stride * chroma height */

static NOINLINE void weight_cost_init_chroma( x264_t *h, x264_frame_t *fenc, x264_frame_t *ref, pixel *dstu, pixel *dstv )
{
    int ref0_distance = fenc->i_frame - ref->i_frame - 1;
    int i_stride = fenc->i_stride[1];
    int i_lines = fenc->i_lines[1];
    int i_width = fenc->i_width[1];
    int v_shift = CHROMA_V_SHIFT;
    int cw = 8*h->mb.i_mb_width;
    int ch = 16*h->mb.i_mb_height >> v_shift;
    int height = 16 >> v_shift;

    if( fenc->lowres_mvs[0][ref0_distance][0][0] != 0x7FFF )
    {
        x264_frame_expand_border_chroma( h, ref, 1 );
        for( int y = 0, mb_xy = 0, pel_offset_y = 0; y < i_lines; y += height, pel_offset_y = y*i_stride )
            for( int x = 0, pel_offset_x = 0; x < i_width; x += 8, mb_xy++, pel_offset_x += 8 )
            {
                pixel *pixu = dstu + pel_offset_y + pel_offset_x;
                pixel *pixv = dstv + pel_offset_y + pel_offset_x;
                pixel *src1 =  ref->plane[1] + pel_offset_y + pel_offset_x*2; /* NV12/NV16 */
                int mvx = fenc->lowres_mvs[0][ref0_distance][mb_xy][0];
                int mvy = fenc->lowres_mvs[0][ref0_distance][mb_xy][1];
                h->mc.mc_chroma( pixu, pixv, i_stride, src1, i_stride, mvx, 2*mvy>>v_shift, 8, height );
            }
    }
    else
        h->mc.plane_copy_deinterleave( dstu, i_stride, dstv, i_stride, ref->plane[1], i_stride, cw, ch );
    h->mc.plane_copy_deinterleave( dstu+i_width, i_stride, dstv+i_width, i_stride, fenc->plane[1], i_stride, cw, ch );
    x264_emms();
}

static NOINLINE pixel *weight_cost_init_chroma444( x264_t *h, x264_frame_t *fenc, x264_frame_t *ref, pixel *dst, int p )
{
    int ref0_distance = fenc->i_frame - ref->i_frame - 1;
    int i_stride = fenc->i_stride[p];
    int i_lines = fenc->i_lines[p];
    int i_width = fenc->i_width[p];

    if( fenc->lowres_mvs[0][ref0_distance][0][0] != 0x7FFF )
    {
        x264_frame_expand_border_chroma( h, ref, p );
        for( int y = 0, mb_xy = 0, pel_offset_y = 0; y < i_lines; y += 16, pel_offset_y = y*i_stride )
            for( int x = 0, pel_offset_x = 0; x < i_width; x += 16, mb_xy++, pel_offset_x += 16 )
            {
                pixel *pix = dst + pel_offset_y + pel_offset_x;
                pixel *src = ref->plane[p] + pel_offset_y + pel_offset_x;
                int mvx = fenc->lowres_mvs[0][ref0_distance][mb_xy][0] / 2;
                int mvy = fenc->lowres_mvs[0][ref0_distance][mb_xy][1] / 2;
                /* We don't want to calculate hpels for fenc frames, so we round the motion
                 * vectors to fullpel here.  It's not too bad, I guess? */
                h->mc.copy_16x16_unaligned( pix, i_stride, src+mvx+mvy*i_stride, i_stride, 16 );
            }
        x264_emms();
        return dst;
    }
    x264_emms();
    return ref->plane[p];
}

static int weight_slice_header_cost( x264_t *h, x264_weight_t *w, int b_chroma )
{
    /* Add cost of weights in the slice header. */
    int lambda = x264_lambda_tab[X264_LOOKAHEAD_QP];
    /* 4 times higher, because chroma is analyzed at full resolution. */
    if( b_chroma )
        lambda *= 4;
    int numslices;
    if( h->param.i_slice_count )
        numslices = h->param.i_slice_count;
    else if( h->param.i_slice_max_mbs )
        numslices = (h->mb.i_mb_width * h->mb.i_mb_height + h->param.i_slice_max_mbs-1) / h->param.i_slice_max_mbs;
    else
        numslices = 1;
    /* FIXME: find a way to account for --slice-max-size?
     * Multiply by 2 as there will be a duplicate. 10 bits added as if there is a weighted frame, then an additional duplicate is used.
     * Cut denom cost in half if chroma, since it's shared between the two chroma planes. */
    int denom_cost = bs_size_ue( w[0].i_denom ) * (2 - b_chroma);
    return lambda * numslices * ( 10 + denom_cost + 2 * (bs_size_se( w[0].i_scale ) + bs_size_se( w[0].i_offset )) );
}

static NOINLINE unsigned int weight_cost_luma( x264_t *h, x264_frame_t *fenc, pixel *src, x264_weight_t *w )
{
    unsigned int cost = 0;
    int i_stride = fenc->i_stride_lowres;
    int i_lines = fenc->i_lines_lowres;
    int i_width = fenc->i_width_lowres;
    pixel *fenc_plane = fenc->lowres[0];
    ALIGNED_ARRAY_16( pixel, buf,[8*8] );
    int pixoff = 0;
    int i_mb = 0;

    if( w )
    {
        for( int y = 0; y < i_lines; y += 8, pixoff = y*i_stride )
            for( int x = 0; x < i_width; x += 8, i_mb++, pixoff += 8)
            {
                w->weightfn[8>>2]( buf, 8, &src[pixoff], i_stride, w, 8 );
                int cmp = h->pixf.mbcmp[PIXEL_8x8]( buf, 8, &fenc_plane[pixoff], i_stride );
                cost += X264_MIN( cmp, fenc->i_intra_cost[i_mb] );
            }
        cost += weight_slice_header_cost( h, w, 0 );
    }
    else
        for( int y = 0; y < i_lines; y += 8, pixoff = y*i_stride )
            for( int x = 0; x < i_width; x += 8, i_mb++, pixoff += 8 )
            {
                int cmp = h->pixf.mbcmp[PIXEL_8x8]( &src[pixoff], i_stride, &fenc_plane[pixoff], i_stride );
                cost += X264_MIN( cmp, fenc->i_intra_cost[i_mb] );
            }
    x264_emms();
    return cost;
}

static NOINLINE unsigned int weight_cost_chroma( x264_t *h, x264_frame_t *fenc, pixel *ref, x264_weight_t *w )
{
    unsigned int cost = 0;
    int i_stride = fenc->i_stride[1];
    int i_lines = fenc->i_lines[1];
    int i_width = fenc->i_width[1];
    pixel *src = ref + i_width;
    ALIGNED_ARRAY_16( pixel, buf, [8*16] );
    int pixoff = 0;
    int height = 16 >> CHROMA_V_SHIFT;
    if( w )
    {
        for( int y = 0; y < i_lines; y += height, pixoff = y*i_stride )
            for( int x = 0; x < i_width; x += 8, pixoff += 8 )
            {
                w->weightfn[8>>2]( buf, 8, &ref[pixoff], i_stride, w, height );
                /* The naive and seemingly sensible algorithm is to use mbcmp as in luma.
                 * But testing shows that for chroma the DC coefficient is by far the most
                 * important part of the coding cost.  Thus a more useful chroma weight is
                 * obtained by comparing each block's DC coefficient instead of the actual
                 * pixels. */
                cost += h->pixf.asd8( buf, 8, &src[pixoff], i_stride, height );
            }
        cost += weight_slice_header_cost( h, w, 1 );
    }
    else
        for( int y = 0; y < i_lines; y += height, pixoff = y*i_stride )
            for( int x = 0; x < i_width; x += 8, pixoff += 8 )
                cost += h->pixf.asd8( &ref[pixoff], i_stride, &src[pixoff], i_stride, height );
    x264_emms();
    return cost;
}

static NOINLINE unsigned int weight_cost_chroma444( x264_t *h, x264_frame_t *fenc, pixel *ref, x264_weight_t *w, int p )
{
    unsigned int cost = 0;
    int i_stride = fenc->i_stride[p];
    int i_lines = fenc->i_lines[p];
    int i_width = fenc->i_width[p];
    pixel *src = fenc->plane[p];
    ALIGNED_ARRAY_64( pixel, buf, [16*16] );
    int pixoff = 0;
    if( w )
    {
        for( int y = 0; y < i_lines; y += 16, pixoff = y*i_stride )
            for( int x = 0; x < i_width; x += 16, pixoff += 16 )
            {
                w->weightfn[16>>2]( buf, 16, &ref[pixoff], i_stride, w, 16 );
                cost += h->pixf.mbcmp[PIXEL_16x16]( buf, 16, &src[pixoff], i_stride );
            }
        cost += weight_slice_header_cost( h, w, 1 );
    }
    else
        for( int y = 0; y < i_lines; y += 16, pixoff = y*i_stride )
            for( int x = 0; x < i_width; x += 16, pixoff += 16 )
                cost += h->pixf.mbcmp[PIXEL_16x16]( &ref[pixoff], i_stride, &src[pixoff], i_stride );
    x264_emms();
    return cost;
}

void x264_weights_analyse( x264_t *h, x264_frame_t *fenc, x264_frame_t *ref, int b_lookahead )
{
    int i_delta_index = fenc->i_frame - ref->i_frame - 1;
    /* epsilon is chosen to require at least a numerator of 127 (with denominator = 128) */
    const float epsilon = 1.f/128.f;
    x264_weight_t *weights = fenc->weight[0];
    SET_WEIGHT( weights[0], 0, 1, 0, 0 );
    SET_WEIGHT( weights[1], 0, 1, 0, 0 );
    SET_WEIGHT( weights[2], 0, 1, 0, 0 );
    int chroma_initted = 0;
    float guess_scale[3];
    float fenc_mean[3];
    float ref_mean[3];
    for( int plane = 0; plane <= 2*!b_lookahead; plane++ )
    {
        if( !plane || CHROMA_FORMAT )
        {
            int zero_bias = !ref->i_pixel_ssd[plane];
            float fenc_var = fenc->i_pixel_ssd[plane] + zero_bias;
            float ref_var  =  ref->i_pixel_ssd[plane] + zero_bias;
            guess_scale[plane] = sqrtf( fenc_var / ref_var );
            fenc_mean[plane] = (float)(fenc->i_pixel_sum[plane] + zero_bias) / (fenc->i_lines[!!plane] * fenc->i_width[!!plane]) / (1 << (BIT_DEPTH - 8));
            ref_mean[plane]  = (float)( ref->i_pixel_sum[plane] + zero_bias) / (fenc->i_lines[!!plane] * fenc->i_width[!!plane]) / (1 << (BIT_DEPTH - 8));
        }
        else
        {
            guess_scale[plane] = 1;
            fenc_mean[plane] = 0;
            ref_mean[plane]  = 0;
        }
    }

    int chroma_denom = 7;
    if( !b_lookahead )
    {
        /* make sure both our scale factors fit */
        while( chroma_denom > 0 )
        {
            float thresh = 127.f / (1<<chroma_denom);
            if( guess_scale[1] < thresh && guess_scale[2] < thresh )
                break;
            chroma_denom--;
        }
    }

    /* Don't check chroma in lookahead, or if there wasn't a luma weight. */
    for( int plane = 0; plane < (CHROMA_FORMAT ? 3 : 1) && !( plane && ( !weights[0].weightfn || b_lookahead ) ); plane++ )
    {
        int minoff, minscale, mindenom;
        unsigned int minscore, origscore;
        int found;

        //early termination
        if( fabsf( ref_mean[plane] - fenc_mean[plane] ) < 0.5f && fabsf( 1.f - guess_scale[plane] ) < epsilon )
        {
            SET_WEIGHT( weights[plane], 0, 1, 0, 0 );
            continue;
        }

        if( plane )
        {
            weights[plane].i_denom = chroma_denom;
            weights[plane].i_scale = x264_clip3( round( guess_scale[plane] * (1<<chroma_denom) ), 0, 255 );
            if( weights[plane].i_scale > 127 )
            {
                weights[1].weightfn = weights[2].weightfn = NULL;
                break;
            }
        }
        else
            weight_get_h264( round( guess_scale[plane] * 128 ), 0, &weights[plane] );

        found = 0;
        mindenom = weights[plane].i_denom;
        minscale = weights[plane].i_scale;
        minoff = 0;

        pixel *mcbuf;
        if( !plane )
        {
            if( !fenc->b_intra_calculated )
            {
                x264_mb_analysis_t a;
                lowres_context_init( h, &a );
                slicetype_frame_cost( h, &a, &fenc, 0, 0, 0 );
            }
            mcbuf = weight_cost_init_luma( h, fenc, ref, h->mb.p_weight_buf[0] );
            origscore = minscore = weight_cost_luma( h, fenc, mcbuf, NULL );
        }
        else
        {
            if( CHROMA444 )
            {
                mcbuf = weight_cost_init_chroma444( h, fenc, ref, h->mb.p_weight_buf[0], plane );
                origscore = minscore = weight_cost_chroma444( h, fenc, mcbuf, NULL, plane );
            }
            else
            {
                pixel *dstu = h->mb.p_weight_buf[0];
                pixel *dstv = h->mb.p_weight_buf[0]+fenc->i_stride[1]*fenc->i_lines[1];
                if( !chroma_initted++ )
                    weight_cost_init_chroma( h, fenc, ref, dstu, dstv );
                mcbuf = plane == 1 ? dstu : dstv;
                origscore = minscore = weight_cost_chroma( h, fenc, mcbuf, NULL );
            }
        }

        if( !minscore )
            continue;

        /* Picked somewhat arbitrarily */
        static const uint8_t weight_check_distance[][2] =
        {
            {0,0},{0,0},{0,1},{0,1},
            {0,1},{0,1},{0,1},{1,1},
            {1,1},{2,1},{2,1},{4,2}
        };
        int scale_dist =  b_lookahead ? 0 : weight_check_distance[h->param.analyse.i_subpel_refine][0];
        int offset_dist = b_lookahead ? 0 : weight_check_distance[h->param.analyse.i_subpel_refine][1];

        int start_scale  = x264_clip3( minscale - scale_dist, 0, 127 );
        int end_scale    = x264_clip3( minscale + scale_dist, 0, 127 );
        for( int i_scale = start_scale; i_scale <= end_scale; i_scale++ )
        {
            int cur_scale = i_scale;
            int cur_offset = fenc_mean[plane] - ref_mean[plane] * cur_scale / (1 << mindenom) + 0.5f * b_lookahead;
            if( cur_offset < - 128 || cur_offset > 127 )
            {
                /* Rescale considering the constraints on cur_offset. We do it in this order
                 * because scale has a much wider range than offset (because of denom), so
                 * it should almost never need to be clamped. */
                cur_offset = x264_clip3( cur_offset, -128, 127 );
                cur_scale = x264_clip3f( (1 << mindenom) * (fenc_mean[plane] - cur_offset) / ref_mean[plane] + 0.5f, 0, 127 );
            }
            int start_offset = x264_clip3( cur_offset - offset_dist, -128, 127 );
            int end_offset   = x264_clip3( cur_offset + offset_dist, -128, 127 );
            for( int i_off = start_offset; i_off <= end_offset; i_off++ )
            {
                SET_WEIGHT( weights[plane], 1, cur_scale, mindenom, i_off );
                unsigned int s;
                if( plane )
                {
                    if( CHROMA444 )
                        s = weight_cost_chroma444( h, fenc, mcbuf, &weights[plane], plane );
                    else
                        s = weight_cost_chroma( h, fenc, mcbuf, &weights[plane] );
                }
                else
                    s = weight_cost_luma( h, fenc, mcbuf, &weights[plane] );
                COPY4_IF_LT( minscore, s, minscale, cur_scale, minoff, i_off, found, 1 );

                // Don't check any more offsets if the previous one had a lower cost than the current one
                if( minoff == start_offset && i_off != start_offset )
                    break;
            }
        }
        x264_emms();

        /* Use a smaller denominator if possible */
        if( !plane )
        {
            while( mindenom > 0 && !(minscale&1) )
            {
                mindenom--;
                minscale >>= 1;
            }
        }

        /* FIXME: More analysis can be done here on SAD vs. SATD termination. */
        /* 0.2% termination derived experimentally to avoid weird weights in frames that are mostly intra. */
        if( !found || (minscale == 1 << mindenom && minoff == 0) || (float)minscore / origscore > 0.998f )
        {
            SET_WEIGHT( weights[plane], 0, 1, 0, 0 );
            continue;
        }
        else
            SET_WEIGHT( weights[plane], 1, minscale, mindenom, minoff );

        if( h->param.analyse.i_weighted_pred == X264_WEIGHTP_FAKE && weights[0].weightfn && !plane )
            fenc->f_weighted_cost_delta[i_delta_index] = (float)minscore / origscore;
    }

    /* Optimize and unify denominator */
    if( weights[1].weightfn || weights[2].weightfn )
    {
        int denom = weights[1].weightfn ? weights[1].i_denom : weights[2].i_denom;
        int both_weighted = weights[1].weightfn && weights[2].weightfn;
        /* If only one plane is weighted, the other has an implicit scale of 1<<denom.
         * With denom==7, this comes out to 128, which is invalid, so don't allow that. */
        while( (!both_weighted && denom==7) ||
               (denom > 0 && !(weights[1].weightfn && (weights[1].i_scale&1))
                         && !(weights[2].weightfn && (weights[2].i_scale&1))) )
        {
            denom--;
            for( int i = 1; i <= 2; i++ )
                if( weights[i].weightfn )
                {
                    weights[i].i_scale >>= 1;
                    weights[i].i_denom = denom;
                }
        }
    }
    for( int i = 1; i <= 2; i++ )
        if( weights[i].weightfn )
            h->mc.weight_cache( h, &weights[i] );

    if( weights[0].weightfn && b_lookahead )
    {
        //scale lowres in lookahead for slicetype_frame_cost
        pixel *src = ref->buffer_lowres;
        pixel *dst = h->mb.p_weight_buf[0];
        int width = ref->i_width_lowres + PADH2;
        int height = ref->i_lines_lowres + PADV*2;
        x264_weight_scale_plane( h, dst, ref->i_stride_lowres, src, ref->i_stride_lowres,
                                 width, height, &weights[0] );
        fenc->weighted[0] = h->mb.p_weight_buf[0] + PADH_ALIGN + ref->i_stride_lowres * PADV;
    }
}

/* Output buffers are separated by 128 bytes to avoid false sharing of cachelines
 * in multithreaded lookahead. */
#define PAD_SIZE 32
/* cost_est, cost_est_aq, intra_mbs, num rows */
#define NUM_INTS 4
#define COST_EST 0
#define COST_EST_AQ 1
#define INTRA_MBS 2
#define NUM_ROWS 3
#define ROW_SATD (NUM_INTS + (h->mb.i_mb_y - h->i_threadslice_start))

static void slicetype_mb_cost( x264_t *h, x264_mb_analysis_t *a,
                               x264_frame_t **frames, int p0, int p1, int b,
                               int dist_scale_factor, int do_search[2], const x264_weight_t *w,
                               int *output_inter, int *output_intra )
{
    x264_frame_t *fref0 = frames[p0];
    x264_frame_t *fref1 = frames[p1];
    x264_frame_t *fenc  = frames[b];
    const int b_bidir = (b < p1);
    const int i_mb_x = h->mb.i_mb_x;
    const int i_mb_y = h->mb.i_mb_y;
    const int i_mb_stride = h->mb.i_mb_width;
    const int i_mb_xy = i_mb_x + i_mb_y * i_mb_stride;
    const int i_stride = fenc->i_stride_lowres;
    const int i_pel_offset = 8 * (i_mb_x + i_mb_y * i_stride);
    const int i_bipred_weight = h->param.analyse.b_weighted_bipred ? 64 - (dist_scale_factor>>2) : 32;
    int16_t (*fenc_mvs[2])[2] = { b != p0 ? &fenc->lowres_mvs[0][b-p0-1][i_mb_xy] : NULL, b != p1 ? &fenc->lowres_mvs[1][p1-b-1][i_mb_xy] : NULL };
    int (*fenc_costs[2]) = { b != p0 ? &fenc->lowres_mv_costs[0][b-p0-1][i_mb_xy] : NULL, b != p1 ? &fenc->lowres_mv_costs[1][p1-b-1][i_mb_xy] : NULL };
    int b_frame_score_mb = (i_mb_x > 0 && i_mb_x < h->mb.i_mb_width - 1 &&
                            i_mb_y > 0 && i_mb_y < h->mb.i_mb_height - 1) ||
                            h->mb.i_mb_width <= 2 || h->mb.i_mb_height <= 2;

    ALIGNED_ARRAY_16( pixel, pix1,[9*FDEC_STRIDE] );
    pixel *pix2 = pix1+8;
    x264_me_t m[2];
    int i_bcost = COST_MAX;
    int list_used = 0;
    /* A small, arbitrary bias to avoid VBV problems caused by zero-residual lookahead blocks. */
    int lowres_penalty = 4;

    h->mb.pic.p_fenc[0] = h->mb.pic.fenc_buf;
    h->mc.copy[PIXEL_8x8]( h->mb.pic.p_fenc[0], FENC_STRIDE, &fenc->lowres[0][i_pel_offset], i_stride, 8 );

    if( p0 == p1 )
        goto lowres_intra_mb;

    int mv_range = 2 * h->param.analyse.i_mv_range;
    // no need for h->mb.mv_min[]
    h->mb.mv_min_spel[0] = X264_MAX( 4*(-8*h->mb.i_mb_x - 12), -mv_range );
    h->mb.mv_max_spel[0] = X264_MIN( 4*(8*(h->mb.i_mb_width - h->mb.i_mb_x - 1) + 12), mv_range-1 );
    h->mb.mv_limit_fpel[0][0] = h->mb.mv_min_spel[0] >> 2;
    h->mb.mv_limit_fpel[1][0] = h->mb.mv_max_spel[0] >> 2;
    if( h->mb.i_mb_x >= h->mb.i_mb_width - 2 )
    {
        h->mb.mv_min_spel[1] = X264_MAX( 4*(-8*h->mb.i_mb_y - 12), -mv_range );
        h->mb.mv_max_spel[1] = X264_MIN( 4*(8*( h->mb.i_mb_height - h->mb.i_mb_y - 1) + 12), mv_range-1 );
        h->mb.mv_limit_fpel[0][1] = h->mb.mv_min_spel[1] >> 2;
        h->mb.mv_limit_fpel[1][1] = h->mb.mv_max_spel[1] >> 2;
    }

#define LOAD_HPELS_LUMA(dst, src) \
    { \
        (dst)[0] = &(src)[0][i_pel_offset]; \
        (dst)[1] = &(src)[1][i_pel_offset]; \
        (dst)[2] = &(src)[2][i_pel_offset]; \
        (dst)[3] = &(src)[3][i_pel_offset]; \
    }
#define LOAD_WPELS_LUMA(dst,src) \
    (dst) = &(src)[i_pel_offset];

#define CLIP_MV( mv ) \
    { \
        mv[0] = x264_clip3( mv[0], h->mb.mv_min_spel[0], h->mb.mv_max_spel[0] ); \
        mv[1] = x264_clip3( mv[1], h->mb.mv_min_spel[1], h->mb.mv_max_spel[1] ); \
    }
#define TRY_BIDIR( mv0, mv1, penalty ) \
    { \
        int i_cost; \
        if( h->param.analyse.i_subpel_refine <= 1 ) \
        { \
            int hpel_idx1 = (((mv0)[0]&2)>>1) + ((mv0)[1]&2); \
            int hpel_idx2 = (((mv1)[0]&2)>>1) + ((mv1)[1]&2); \
            pixel *src1 = m[0].p_fref[hpel_idx1] + ((mv0)[0]>>2) + ((mv0)[1]>>2) * m[0].i_stride[0]; \
            pixel *src2 = m[1].p_fref[hpel_idx2] + ((mv1)[0]>>2) + ((mv1)[1]>>2) * m[1].i_stride[0]; \
            h->mc.avg[PIXEL_8x8]( pix1, 16, src1, m[0].i_stride[0], src2, m[1].i_stride[0], i_bipred_weight ); \
        } \
        else \
        { \
            intptr_t stride1 = 16, stride2 = 16; \
            pixel *src1, *src2; \
            src1 = h->mc.get_ref( pix1, &stride1, m[0].p_fref, m[0].i_stride[0], \
                                  (mv0)[0], (mv0)[1], 8, 8, w ); \
            src2 = h->mc.get_ref( pix2, &stride2, m[1].p_fref, m[1].i_stride[0], \
                                  (mv1)[0], (mv1)[1], 8, 8, w ); \
            h->mc.avg[PIXEL_8x8]( pix1, 16, src1, stride1, src2, stride2, i_bipred_weight ); \
        } \
        i_cost = penalty * a->i_lambda + h->pixf.mbcmp[PIXEL_8x8]( \
                           m[0].p_fenc[0], FENC_STRIDE, pix1, 16 ); \
        COPY2_IF_LT( i_bcost, i_cost, list_used, 3 ); \
    }

    m[0].i_pixel = PIXEL_8x8;
    m[0].p_cost_mv = a->p_cost_mv;
    m[0].i_stride[0] = i_stride;
    m[0].p_fenc[0] = h->mb.pic.p_fenc[0];
    m[0].weight = w;
    m[0].i_ref = 0;
    LOAD_HPELS_LUMA( m[0].p_fref, fref0->lowres );
    m[0].p_fref_w = m[0].p_fref[0];
    if( w[0].weightfn )
        LOAD_WPELS_LUMA( m[0].p_fref_w, fenc->weighted[0] );

    if( b_bidir )
    {
        ALIGNED_ARRAY_8( int16_t, dmv,[2],[2] );

        m[1].i_pixel = PIXEL_8x8;
        m[1].p_cost_mv = a->p_cost_mv;
        m[1].i_stride[0] = i_stride;
        m[1].p_fenc[0] = h->mb.pic.p_fenc[0];
        m[1].i_ref = 0;
        m[1].weight = x264_weight_none;
        LOAD_HPELS_LUMA( m[1].p_fref, fref1->lowres );
        m[1].p_fref_w = m[1].p_fref[0];

        if( fref1->lowres_mvs[0][p1-p0-1][0][0] != 0x7FFF )
        {
            int16_t *mvr = fref1->lowres_mvs[0][p1-p0-1][i_mb_xy];
            dmv[0][0] = ( mvr[0] * dist_scale_factor + 128 ) >> 8;
            dmv[0][1] = ( mvr[1] * dist_scale_factor + 128 ) >> 8;
            dmv[1][0] = dmv[0][0] - mvr[0];
            dmv[1][1] = dmv[0][1] - mvr[1];
            CLIP_MV( dmv[0] );
            CLIP_MV( dmv[1] );
            if( h->param.analyse.i_subpel_refine <= 1 )
                M64( dmv ) &= ~0x0001000100010001ULL; /* mv & ~1 */
        }
        else
            M64( dmv ) = 0;

        TRY_BIDIR( dmv[0], dmv[1], 0 );
        if( M64( dmv ) )
        {
            int i_cost;
            h->mc.avg[PIXEL_8x8]( pix1, 16, m[0].p_fref[0], m[0].i_stride[0], m[1].p_fref[0], m[1].i_stride[0], i_bipred_weight );
            i_cost = h->pixf.mbcmp[PIXEL_8x8]( m[0].p_fenc[0], FENC_STRIDE, pix1, 16 );
            COPY2_IF_LT( i_bcost, i_cost, list_used, 3 );
        }
    }

    for( int l = 0; l < 1 + b_bidir; l++ )
    {
        if( do_search[l] )
        {
            int i_mvc = 0;
            int16_t (*fenc_mv)[2] = fenc_mvs[l];
            ALIGNED_ARRAY_8( int16_t, mvc,[4],[2] );

            /* Reverse-order MV prediction. */
            M32( mvc[0] ) = 0;
            M32( mvc[2] ) = 0;
#define MVC(mv) { CP32( mvc[i_mvc], mv ); i_mvc++; }
            if( i_mb_x < h->mb.i_mb_width - 1 )
                MVC( fenc_mv[1] );
            if( i_mb_y < h->i_threadslice_end - 1 )
            {
                MVC( fenc_mv[i_mb_stride] );
                if( i_mb_x > 0 )
                    MVC( fenc_mv[i_mb_stride-1] );
                if( i_mb_x < h->mb.i_mb_width - 1 )
                    MVC( fenc_mv[i_mb_stride+1] );
            }
#undef MVC
            if( i_mvc <= 1 )
                CP32( m[l].mvp, mvc[0] );
            else
                x264_median_mv( m[l].mvp, mvc[0], mvc[1], mvc[2] );

            /* Fast skip for cases of near-zero residual.  Shortcut: don't bother except in the mv0 case,
             * since anything else is likely to have enough residual to not trigger the skip. */
            if( !M32( m[l].mvp ) )
            {
                m[l].cost = h->pixf.mbcmp[PIXEL_8x8]( m[l].p_fenc[0], FENC_STRIDE, m[l].p_fref[0], m[l].i_stride[0] );
                if( m[l].cost < 64 )
                {
                    M32( m[l].mv ) = 0;
                    goto skip_motionest;
                }
            }

            x264_me_search( h, &m[l], mvc, i_mvc );
            m[l].cost -= a->p_cost_mv[0]; // remove mvcost from skip mbs
            if( M32( m[l].mv ) )
                m[l].cost += 5 * a->i_lambda;

skip_motionest:
            CP32( fenc_mvs[l], m[l].mv );
            *fenc_costs[l] = m[l].cost;
        }
        else
        {
            CP32( m[l].mv, fenc_mvs[l] );
            m[l].cost = *fenc_costs[l];
        }
        COPY2_IF_LT( i_bcost, m[l].cost, list_used, l+1 );
    }

    if( b_bidir && ( M32( m[0].mv ) || M32( m[1].mv ) ) )
        TRY_BIDIR( m[0].mv, m[1].mv, 5 );

lowres_intra_mb:
    if( !fenc->b_intra_calculated )
    {
        ALIGNED_ARRAY_16( pixel, edge,[36] );
        pixel *pix = &pix1[8+FDEC_STRIDE];
        pixel *src = &fenc->lowres[0][i_pel_offset];
        const int intra_penalty = 5 * a->i_lambda;
        int satds[3];
        int pixoff = 4 / SIZEOF_PIXEL;

        /* Avoid store forwarding stalls by writing larger chunks */
        memcpy( pix-FDEC_STRIDE, src-i_stride, 16 * SIZEOF_PIXEL );
        for( int i = -1; i < 8; i++ )
            M32( &pix[i*FDEC_STRIDE-pixoff] ) = M32( &src[i*i_stride-pixoff] );

        h->pixf.intra_mbcmp_x3_8x8c( h->mb.pic.p_fenc[0], pix, satds );
        int i_icost = X264_MIN3( satds[0], satds[1], satds[2] );

        if( h->param.analyse.i_subpel_refine > 1 )
        {
            h->predict_8x8c[I_PRED_CHROMA_P]( pix );
            int satd = h->pixf.mbcmp[PIXEL_8x8]( h->mb.pic.p_fenc[0], FENC_STRIDE, pix, FDEC_STRIDE );
            i_icost = X264_MIN( i_icost, satd );
            h->predict_8x8_filter( pix, edge, ALL_NEIGHBORS, ALL_NEIGHBORS );
            for( int i = 3; i < 9; i++ )
            {
                h->predict_8x8[i]( pix, edge );
                satd = h->pixf.mbcmp[PIXEL_8x8]( h->mb.pic.p_fenc[0], FENC_STRIDE, pix, FDEC_STRIDE );
                i_icost = X264_MIN( i_icost, satd );
            }
        }

        i_icost = ((i_icost + intra_penalty) >> (BIT_DEPTH - 8)) + lowres_penalty;
        fenc->i_intra_cost[i_mb_xy] = i_icost;
        int i_icost_aq = i_icost;
        if( h->param.rc.i_aq_mode )
            i_icost_aq = (i_icost_aq * fenc->i_inv_qscale_factor[i_mb_xy] + 128) >> 8;
        output_intra[ROW_SATD] += i_icost_aq;
        if( b_frame_score_mb )
        {
            output_intra[COST_EST] += i_icost;
            output_intra[COST_EST_AQ] += i_icost_aq;
        }
    }
    i_bcost = (i_bcost >> (BIT_DEPTH - 8)) + lowres_penalty;

    /* forbid intra-mbs in B-frames, because it's rare and not worth checking */
    /* FIXME: Should we still forbid them now that we cache intra scores? */
    if( !b_bidir )
    {
        int i_icost = fenc->i_intra_cost[i_mb_xy];
        int b_intra = i_icost < i_bcost;
        if( b_intra )
        {
            i_bcost = i_icost;
            list_used = 0;
        }
        if( b_frame_score_mb )
            output_inter[INTRA_MBS] += b_intra;
    }

    /* In an I-frame, we've already added the results above in the intra section. */
    if( p0 != p1 )
    {
        int i_bcost_aq = i_bcost;
        if( h->param.rc.i_aq_mode )
            i_bcost_aq = (i_bcost_aq * fenc->i_inv_qscale_factor[i_mb_xy] + 128) >> 8;
        output_inter[ROW_SATD] += i_bcost_aq;
        if( b_frame_score_mb )
        {
            /* Don't use AQ-weighted costs for slicetype decision, only for ratecontrol. */
            output_inter[COST_EST] += i_bcost;
            output_inter[COST_EST_AQ] += i_bcost_aq;
        }
    }

    fenc->lowres_costs[b-p0][p1-b][i_mb_xy] = X264_MIN( i_bcost, LOWRES_COST_MASK ) + (list_used << LOWRES_COST_SHIFT);
}
#undef TRY_BIDIR

#define NUM_MBS\
   (h->mb.i_mb_width > 2 && h->mb.i_mb_height > 2 ?\
   (h->mb.i_mb_width - 2) * (h->mb.i_mb_height - 2) :\
    h->mb.i_mb_width * h->mb.i_mb_height)

typedef struct
{
    x264_t *h;
    x264_mb_analysis_t *a;
    x264_frame_t **frames;
    int p0;
    int p1;
    int b;
    int dist_scale_factor;
    int *do_search;
    const x264_weight_t *w;
    int *output_inter;
    int *output_intra;
} x264_slicetype_slice_t;

static void slicetype_slice_cost( x264_slicetype_slice_t *s )
{
    x264_t *h = s->h;

    /* Lowres lookahead goes backwards because the MVs are used as predictors in the main encode.
     * This considerably improves MV prediction overall. */

    /* The edge mbs seem to reduce the predictive quality of the
     * whole frame's score, but are needed for a spatial distribution. */
    int do_edges = h->param.rc.b_mb_tree || h->param.rc.i_vbv_buffer_size || h->mb.i_mb_width <= 2 || h->mb.i_mb_height <= 2;

    int start_y = X264_MIN( h->i_threadslice_end - 1, h->mb.i_mb_height - 2 + do_edges );
    int end_y = X264_MAX( h->i_threadslice_start, 1 - do_edges );
    int start_x = h->mb.i_mb_width - 2 + do_edges;
    int end_x = 1 - do_edges;

    for( h->mb.i_mb_y = start_y; h->mb.i_mb_y >= end_y; h->mb.i_mb_y-- )
        for( h->mb.i_mb_x = start_x; h->mb.i_mb_x >= end_x; h->mb.i_mb_x-- )
            slicetype_mb_cost( h, s->a, s->frames, s->p0, s->p1, s->b, s->dist_scale_factor,
                               s->do_search, s->w, s->output_inter, s->output_intra );
}

static int slicetype_frame_cost( x264_t *h, x264_mb_analysis_t *a,
                                 x264_frame_t **frames, int p0, int p1, int b )
{
    int i_score = 0;
    int do_search[2];
    const x264_weight_t *w = x264_weight_none;
    x264_frame_t *fenc = frames[b];

    /* Check whether we already evaluated this frame
     * If we have tried this frame as P, then we have also tried
     * the preceding frames as B. (is this still true?) */
    /* Also check that we already calculated the row SATDs for the current frame. */
    if( fenc->i_cost_est[b-p0][p1-b] >= 0 && (!h->param.rc.i_vbv_buffer_size || fenc->i_row_satds[b-p0][p1-b][0] != -1) )
        i_score = fenc->i_cost_est[b-p0][p1-b];
    else
    {
        int dist_scale_factor = 128;

        /* For each list, check to see whether we have lowres motion-searched this reference frame before. */
        do_search[0] = b != p0 && fenc->lowres_mvs[0][b-p0-1][0][0] == 0x7FFF;
        do_search[1] = b != p1 && fenc->lowres_mvs[1][p1-b-1][0][0] == 0x7FFF;
        if( do_search[0] )
        {
            if( h->param.analyse.i_weighted_pred && b == p1 )
            {
                x264_emms();
                x264_weights_analyse( h, fenc, frames[p0], 1 );
                w = fenc->weight[0];
            }
            fenc->lowres_mvs[0][b-p0-1][0][0] = 0;
        }
        if( do_search[1] ) fenc->lowres_mvs[1][p1-b-1][0][0] = 0;

        if( p1 != p0 )
            dist_scale_factor = ( ((b-p0) << 8) + ((p1-p0) >> 1) ) / (p1-p0);

        int output_buf_size = h->mb.i_mb_height + (NUM_INTS + PAD_SIZE) * h->param.i_lookahead_threads;
        int *output_inter[X264_LOOKAHEAD_THREAD_MAX+1];
        int *output_intra[X264_LOOKAHEAD_THREAD_MAX+1];
        output_inter[0] = h->scratch_buffer2;
        output_intra[0] = output_inter[0] + output_buf_size;

#if HAVE_OPENCL
        if( h->param.b_opencl )
        {
            x264_opencl_lowres_init(h, fenc, a->i_lambda );
            if( do_search[0] )
            {
                x264_opencl_lowres_init( h, frames[p0], a->i_lambda );
                x264_opencl_motionsearch( h, frames, b, p0, 0, a->i_lambda, w );
            }
            if( do_search[1] )
            {
                x264_opencl_lowres_init( h, frames[p1], a->i_lambda );
                x264_opencl_motionsearch( h, frames, b, p1, 1, a->i_lambda, NULL );
            }
            if( b != p0 )
                x264_opencl_finalize_cost( h, a->i_lambda, frames, p0, p1, b, dist_scale_factor );
            x264_opencl_flush( h );

            i_score = fenc->i_cost_est[b-p0][p1-b];
        }
        else
#endif
        {
            if( h->param.i_lookahead_threads > 1 )
            {
                x264_slicetype_slice_t s[X264_LOOKAHEAD_THREAD_MAX];

                for( int i = 0; i < h->param.i_lookahead_threads; i++ )
                {
                    x264_t *t = h->lookahead_thread[i];

                    /* FIXME move this somewhere else */
                    t->mb.i_me_method = h->mb.i_me_method;
                    t->mb.i_subpel_refine = h->mb.i_subpel_refine;
                    t->mb.b_chroma_me = h->mb.b_chroma_me;

                    s[i] = (x264_slicetype_slice_t){ t, a, frames, p0, p1, b, dist_scale_factor, do_search, w,
                        output_inter[i], output_intra[i] };

                    t->i_threadslice_start = ((h->mb.i_mb_height *  i    + h->param.i_lookahead_threads/2) / h->param.i_lookahead_threads);
                    t->i_threadslice_end   = ((h->mb.i_mb_height * (i+1) + h->param.i_lookahead_threads/2) / h->param.i_lookahead_threads);

                    int thread_height = t->i_threadslice_end - t->i_threadslice_start;
                    int thread_output_size = thread_height + NUM_INTS;
                    memset( output_inter[i], 0, thread_output_size * sizeof(int) );
                    memset( output_intra[i], 0, thread_output_size * sizeof(int) );
                    output_inter[i][NUM_ROWS] = output_intra[i][NUM_ROWS] = thread_height;

                    output_inter[i+1] = output_inter[i] + thread_output_size + PAD_SIZE;
                    output_intra[i+1] = output_intra[i] + thread_output_size + PAD_SIZE;

                    x264_threadpool_run( h->lookaheadpool, (void*)slicetype_slice_cost, &s[i] );
                }
                for( int i = 0; i < h->param.i_lookahead_threads; i++ )
                    x264_threadpool_wait( h->lookaheadpool, &s[i] );
            }
            else
            {
                h->i_threadslice_start = 0;
                h->i_threadslice_end = h->mb.i_mb_height;
                memset( output_inter[0], 0, (output_buf_size - PAD_SIZE) * sizeof(int) );
                memset( output_intra[0], 0, (output_buf_size - PAD_SIZE) * sizeof(int) );
                output_inter[0][NUM_ROWS] = output_intra[0][NUM_ROWS] = h->mb.i_mb_height;
                x264_slicetype_slice_t s = (x264_slicetype_slice_t){ h, a, frames, p0, p1, b, dist_scale_factor, do_search, w,
                    output_inter[0], output_intra[0] };
                slicetype_slice_cost( &s );
            }

            /* Sum up accumulators */
            if( b == p1 )
                fenc->i_intra_mbs[b-p0] = 0;
            if( !fenc->b_intra_calculated )
            {
                fenc->i_cost_est[0][0] = 0;
                fenc->i_cost_est_aq[0][0] = 0;
            }
            fenc->i_cost_est[b-p0][p1-b] = 0;
            fenc->i_cost_est_aq[b-p0][p1-b] = 0;

            int *row_satd_inter = fenc->i_row_satds[b-p0][p1-b];
            int *row_satd_intra = fenc->i_row_satds[0][0];
            for( int i = 0; i < h->param.i_lookahead_threads; i++ )
            {
                if( b == p1 )
                    fenc->i_intra_mbs[b-p0] += output_inter[i][INTRA_MBS];
                if( !fenc->b_intra_calculated )
                {
                    fenc->i_cost_est[0][0] += output_intra[i][COST_EST];
                    fenc->i_cost_est_aq[0][0] += output_intra[i][COST_EST_AQ];
                }

                fenc->i_cost_est[b-p0][p1-b] += output_inter[i][COST_EST];
                fenc->i_cost_est_aq[b-p0][p1-b] += output_inter[i][COST_EST_AQ];

                if( h->param.rc.i_vbv_buffer_size )
                {
                    int row_count = output_inter[i][NUM_ROWS];
                    memcpy( row_satd_inter, output_inter[i] + NUM_INTS, row_count * sizeof(int) );
                    if( !fenc->b_intra_calculated )
                        memcpy( row_satd_intra, output_intra[i] + NUM_INTS, row_count * sizeof(int) );
                    row_satd_inter += row_count;
                    row_satd_intra += row_count;
                }
            }

            i_score = fenc->i_cost_est[b-p0][p1-b];
            if( b != p1 )
                i_score = (uint64_t)i_score * 100 / (120 + h->param.i_bframe_bias);
            else
                fenc->b_intra_calculated = 1;

            fenc->i_cost_est[b-p0][p1-b] = i_score;
            x264_emms();
        }
    }

    return i_score;
}

/* If MB-tree changes the quantizers, we need to recalculate the frame cost without
 * re-running lookahead. */
static int slicetype_frame_cost_recalculate( x264_t *h, x264_frame_t **frames, int p0, int p1, int b )
{
    int i_score = 0;
    int *row_satd = frames[b]->i_row_satds[b-p0][p1-b];
    float *qp_offset = IS_X264_TYPE_B(frames[b]->i_type) ? frames[b]->f_qp_offset_aq : frames[b]->f_qp_offset;
    x264_emms();
    for( h->mb.i_mb_y = h->mb.i_mb_height - 1; h->mb.i_mb_y >= 0; h->mb.i_mb_y-- )
    {
        row_satd[ h->mb.i_mb_y ] = 0;
        for( h->mb.i_mb_x = h->mb.i_mb_width - 1; h->mb.i_mb_x >= 0; h->mb.i_mb_x-- )
        {
            int i_mb_xy = h->mb.i_mb_x + h->mb.i_mb_y*h->mb.i_mb_stride;
            int i_mb_cost = frames[b]->lowres_costs[b-p0][p1-b][i_mb_xy] & LOWRES_COST_MASK;
            float qp_adj = qp_offset[i_mb_xy];
            i_mb_cost = (i_mb_cost * x264_exp2fix8(qp_adj) + 128) >> 8;
            row_satd[ h->mb.i_mb_y ] += i_mb_cost;
            if( (h->mb.i_mb_y > 0 && h->mb.i_mb_y < h->mb.i_mb_height - 1 &&
                 h->mb.i_mb_x > 0 && h->mb.i_mb_x < h->mb.i_mb_width - 1) ||
                 h->mb.i_mb_width <= 2 || h->mb.i_mb_height <= 2 )
            {
                i_score += i_mb_cost;
            }
        }
    }
    return i_score;
}

/* Trade off precision in mbtree for increased range */
#define MBTREE_PRECISION 0.5f

static void macroblock_tree_finish( x264_t *h, x264_frame_t *frame, float average_duration, int ref0_distance )
{
    int fps_factor = round( CLIP_DURATION(average_duration) / CLIP_DURATION(frame->f_duration) * 256 / MBTREE_PRECISION );
    float weightdelta = 0.0;
    if( ref0_distance && frame->f_weighted_cost_delta[ref0_distance-1] > 0 )
        weightdelta = (1.0 - frame->f_weighted_cost_delta[ref0_distance-1]);

    /* Allow the strength to be adjusted via qcompress, since the two
     * concepts are very similar. */
    float strength = 5.0f * (1.0f - h->param.rc.f_qcompress);
    for( int mb_index = 0; mb_index < h->mb.i_mb_count; mb_index++ )
    {
        int intra_cost = (frame->i_intra_cost[mb_index] * frame->i_inv_qscale_factor[mb_index] + 128) >> 8;
        if( intra_cost )
        {
            int propagate_cost = (frame->i_propagate_cost[mb_index] * fps_factor + 128) >> 8;
            float log2_ratio = x264_log2(intra_cost + propagate_cost) - x264_log2(intra_cost) + weightdelta;
            frame->f_qp_offset[mb_index] = frame->f_qp_offset_aq[mb_index] - strength * log2_ratio;
        }
    }
}

static void macroblock_tree_propagate( x264_t *h, x264_frame_t **frames, float average_duration, int p0, int p1, int b, int referenced )
{
    uint16_t *ref_costs[2] = {frames[p0]->i_propagate_cost,frames[p1]->i_propagate_cost};
    int dist_scale_factor = ( ((b-p0) << 8) + ((p1-p0) >> 1) ) / (p1-p0);
    int i_bipred_weight = h->param.analyse.b_weighted_bipred ? 64 - (dist_scale_factor>>2) : 32;
    int16_t (*mvs[2])[2] = { b != p0 ? frames[b]->lowres_mvs[0][b-p0-1] : NULL, b != p1 ? frames[b]->lowres_mvs[1][p1-b-1] : NULL };
    int bipred_weights[2] = {i_bipred_weight, 64 - i_bipred_weight};
    int16_t *buf = h->scratch_buffer;
    uint16_t *propagate_cost = frames[b]->i_propagate_cost;
    uint16_t *lowres_costs = frames[b]->lowres_costs[b-p0][p1-b];

    x264_emms();
    float fps_factor = CLIP_DURATION(frames[b]->f_duration) / (CLIP_DURATION(average_duration) * 256.0f) * MBTREE_PRECISION;

    /* For non-reffed frames the source costs are always zero, so just memset one row and re-use it. */
    if( !referenced )
        memset( frames[b]->i_propagate_cost, 0, h->mb.i_mb_width * sizeof(uint16_t) );

    for( h->mb.i_mb_y = 0; h->mb.i_mb_y < h->mb.i_mb_height; h->mb.i_mb_y++ )
    {
        int mb_index = h->mb.i_mb_y*h->mb.i_mb_stride;
        h->mc.mbtree_propagate_cost( buf, propagate_cost,
            frames[b]->i_intra_cost+mb_index, lowres_costs+mb_index,
            frames[b]->i_inv_qscale_factor+mb_index, &fps_factor, h->mb.i_mb_width );
        if( referenced )
            propagate_cost += h->mb.i_mb_width;

        h->mc.mbtree_propagate_list( h, ref_costs[0], &mvs[0][mb_index], buf, &lowres_costs[mb_index],
                                     bipred_weights[0], h->mb.i_mb_y, h->mb.i_mb_width, 0 );
        if( b != p1 )
        {
            h->mc.mbtree_propagate_list( h, ref_costs[1], &mvs[1][mb_index], buf, &lowres_costs[mb_index],
                                         bipred_weights[1], h->mb.i_mb_y, h->mb.i_mb_width, 1 );
        }
    }

    if( h->param.rc.i_vbv_buffer_size && h->param.rc.i_lookahead && referenced )
        macroblock_tree_finish( h, frames[b], average_duration, b == p1 ? b - p0 : 0 );
}

static void macroblock_tree( x264_t *h, x264_mb_analysis_t *a, x264_frame_t **frames, int num_frames, int b_intra )
{
    int idx = !b_intra;
    int last_nonb, cur_nonb = 1;
    int bframes = 0;

    x264_emms();
    float total_duration = 0.0;
    for( int j = 0; j <= num_frames; j++ )
        total_duration += frames[j]->f_duration;
    float average_duration = total_duration / (num_frames + 1);

    int i = num_frames;

    if( b_intra )
        slicetype_frame_cost( h, a, frames, 0, 0, 0 );

    while( i > 0 && IS_X264_TYPE_B( frames[i]->i_type ) )
        i--;
    last_nonb = i;

    /* Lookaheadless MB-tree is not a theoretically distinct case; the same extrapolation could
     * be applied to the end of a lookahead buffer of any size.  However, it's most needed when
     * lookahead=0, so that's what's currently implemented. */
    if( !h->param.rc.i_lookahead )
    {
        if( b_intra )
        {
            memset( frames[0]->i_propagate_cost, 0, h->mb.i_mb_count * sizeof(uint16_t) );
            memcpy( frames[0]->f_qp_offset, frames[0]->f_qp_offset_aq, h->mb.i_mb_count * sizeof(float) );
            return;
        }
        XCHG( uint16_t*, frames[last_nonb]->i_propagate_cost, frames[0]->i_propagate_cost );
        memset( frames[0]->i_propagate_cost, 0, h->mb.i_mb_count * sizeof(uint16_t) );
    }
    else
    {
        if( last_nonb < idx )
            return;
        memset( frames[last_nonb]->i_propagate_cost, 0, h->mb.i_mb_count * sizeof(uint16_t) );
    }

    while( i-- > idx )
    {
        cur_nonb = i;
        while( IS_X264_TYPE_B( frames[cur_nonb]->i_type ) && cur_nonb > 0 )
            cur_nonb--;
        if( cur_nonb < idx )
            break;
        slicetype_frame_cost( h, a, frames, cur_nonb, last_nonb, last_nonb );
        memset( frames[cur_nonb]->i_propagate_cost, 0, h->mb.i_mb_count * sizeof(uint16_t) );
        bframes = last_nonb - cur_nonb - 1;
        if( h->param.i_bframe_pyramid && bframes > 1 )
        {
            int middle = (bframes + 1)/2 + cur_nonb;
            slicetype_frame_cost( h, a, frames, cur_nonb, last_nonb, middle );
            memset( frames[middle]->i_propagate_cost, 0, h->mb.i_mb_count * sizeof(uint16_t) );
            while( i > cur_nonb )
            {
                int p0 = i > middle ? middle : cur_nonb;
                int p1 = i < middle ? middle : last_nonb;
                if( i != middle )
                {
                    slicetype_frame_cost( h, a, frames, p0, p1, i );
                    macroblock_tree_propagate( h, frames, average_duration, p0, p1, i, 0 );
                }
                i--;
            }
            macroblock_tree_propagate( h, frames, average_duration, cur_nonb, last_nonb, middle, 1 );
        }
        else
        {
            while( i > cur_nonb )
            {
                slicetype_frame_cost( h, a, frames, cur_nonb, last_nonb, i );
                macroblock_tree_propagate( h, frames, average_duration, cur_nonb, last_nonb, i, 0 );
                i--;
            }
        }
        macroblock_tree_propagate( h, frames, average_duration, cur_nonb, last_nonb, last_nonb, 1 );
        last_nonb = cur_nonb;
    }

    if( !h->param.rc.i_lookahead )
    {
        slicetype_frame_cost( h, a, frames, 0, last_nonb, last_nonb );
        macroblock_tree_propagate( h, frames, average_duration, 0, last_nonb, last_nonb, 1 );
        XCHG( uint16_t*, frames[last_nonb]->i_propagate_cost, frames[0]->i_propagate_cost );
    }

    macroblock_tree_finish( h, frames[last_nonb], average_duration, last_nonb );
    if( h->param.i_bframe_pyramid && bframes > 1 && !h->param.rc.i_vbv_buffer_size )
        macroblock_tree_finish( h, frames[last_nonb+(bframes+1)/2], average_duration, 0 );
}

static int vbv_frame_cost( x264_t *h, x264_mb_analysis_t *a, x264_frame_t **frames, int p0, int p1, int b )
{
    int cost = slicetype_frame_cost( h, a, frames, p0, p1, b );
    if( h->param.rc.i_aq_mode )
    {
        if( h->param.rc.b_mb_tree )
            return slicetype_frame_cost_recalculate( h, frames, p0, p1, b );
        else
            return frames[b]->i_cost_est_aq[b-p0][p1-b];
    }
    return cost;
}

static void calculate_durations( x264_t *h, x264_frame_t *cur_frame, x264_frame_t *prev_frame, int64_t *i_cpb_delay, int64_t *i_coded_fields )
{
    cur_frame->i_cpb_delay = *i_cpb_delay;
    cur_frame->i_dpb_output_delay = cur_frame->i_field_cnt - *i_coded_fields;

    // add a correction term for frame reordering
    cur_frame->i_dpb_output_delay += h->sps->vui.i_num_reorder_frames*2;

    // fix possible negative dpb_output_delay because of pulldown changes and reordering
    if( cur_frame->i_dpb_output_delay < 0 )
    {
        cur_frame->i_cpb_delay += cur_frame->i_dpb_output_delay;
        cur_frame->i_dpb_output_delay = 0;
        if( prev_frame )
            prev_frame->i_cpb_duration += cur_frame->i_dpb_output_delay;
    }

    // don't reset cpb delay for IDR frames when using intra-refresh
    if( cur_frame->b_keyframe && !h->param.b_intra_refresh )
        *i_cpb_delay = 0;

    *i_cpb_delay += cur_frame->i_duration;
    *i_coded_fields += cur_frame->i_duration;
    cur_frame->i_cpb_duration = cur_frame->i_duration;
}

static void vbv_lookahead( x264_t *h, x264_mb_analysis_t *a, x264_frame_t **frames, int num_frames, int keyframe )
{
    int last_nonb = 0, cur_nonb = 1, idx = 0;
    x264_frame_t *prev_frame = NULL;
    int prev_frame_idx = 0;
    while( cur_nonb < num_frames && IS_X264_TYPE_B( frames[cur_nonb]->i_type ) )
        cur_nonb++;
    int next_nonb = keyframe ? last_nonb : cur_nonb;

    if( frames[cur_nonb]->i_coded_fields_lookahead >= 0 )
    {
        h->i_coded_fields_lookahead = frames[cur_nonb]->i_coded_fields_lookahead;
        h->i_cpb_delay_lookahead = frames[cur_nonb]->i_cpb_delay_lookahead;
    }

    while( cur_nonb < num_frames )
    {
        /* P/I cost: This shouldn't include the cost of next_nonb */
        if( next_nonb != cur_nonb )
        {
            int p0 = IS_X264_TYPE_I( frames[cur_nonb]->i_type ) ? cur_nonb : last_nonb;
            frames[next_nonb]->i_planned_satd[idx] = vbv_frame_cost( h, a, frames, p0, cur_nonb, cur_nonb );
            frames[next_nonb]->i_planned_type[idx] = frames[cur_nonb]->i_type;
            frames[cur_nonb]->i_coded_fields_lookahead = h->i_coded_fields_lookahead;
            frames[cur_nonb]->i_cpb_delay_lookahead = h->i_cpb_delay_lookahead;
            calculate_durations( h, frames[cur_nonb], prev_frame, &h->i_cpb_delay_lookahead, &h->i_coded_fields_lookahead );
            if( prev_frame )
            {
                frames[next_nonb]->f_planned_cpb_duration[prev_frame_idx] = (double)prev_frame->i_cpb_duration *
                                                                            h->sps->vui.i_num_units_in_tick / h->sps->vui.i_time_scale;
            }
            frames[next_nonb]->f_planned_cpb_duration[idx] = (double)frames[cur_nonb]->i_cpb_duration *
                                                             h->sps->vui.i_num_units_in_tick / h->sps->vui.i_time_scale;
            prev_frame = frames[cur_nonb];
            prev_frame_idx = idx;
            idx++;
        }
        /* Handle the B-frames: coded order */
        for( int i = last_nonb+1; i < cur_nonb; i++, idx++ )
        {
            frames[next_nonb]->i_planned_satd[idx] = vbv_frame_cost( h, a, frames, last_nonb, cur_nonb, i );
            frames[next_nonb]->i_planned_type[idx] = X264_TYPE_B;
            frames[i]->i_coded_fields_lookahead = h->i_coded_fields_lookahead;
            frames[i]->i_cpb_delay_lookahead = h->i_cpb_delay_lookahead;
            calculate_durations( h, frames[i], prev_frame, &h->i_cpb_delay_lookahead, &h->i_coded_fields_lookahead );
            if( prev_frame )
            {
                frames[next_nonb]->f_planned_cpb_duration[prev_frame_idx] = (double)prev_frame->i_cpb_duration *
                                                                            h->sps->vui.i_num_units_in_tick / h->sps->vui.i_time_scale;
            }
            frames[next_nonb]->f_planned_cpb_duration[idx] = (double)frames[i]->i_cpb_duration *
                                                             h->sps->vui.i_num_units_in_tick / h->sps->vui.i_time_scale;
            prev_frame = frames[i];
            prev_frame_idx = idx;
        }
        last_nonb = cur_nonb;
        cur_nonb++;
        while( cur_nonb <= num_frames && IS_X264_TYPE_B( frames[cur_nonb]->i_type ) )
            cur_nonb++;
    }
    frames[next_nonb]->i_planned_type[idx] = X264_TYPE_AUTO;
}

static uint64_t slicetype_path_cost( x264_t *h, x264_mb_analysis_t *a, x264_frame_t **frames, char *path, uint64_t threshold )
{
    uint64_t cost = 0;
    int loc = 1;
    int cur_nonb = 0;
    path--; /* Since the 1st path element is really the second frame */
    while( path[loc] )
    {
        int next_nonb = loc;
        /* Find the location of the next non-B-frame. */
        while( path[next_nonb] == 'B' )
            next_nonb++;

        /* Add the cost of the non-B-frame found above */
        if( path[next_nonb] == 'P' )
            cost += slicetype_frame_cost( h, a, frames, cur_nonb, next_nonb, next_nonb );
        else /* I-frame */
            cost += slicetype_frame_cost( h, a, frames, next_nonb, next_nonb, next_nonb );
        /* Early terminate if the cost we have found is larger than the best path cost so far */
        if( cost > threshold )
            break;

        if( h->param.i_bframe_pyramid && next_nonb - cur_nonb > 2 )
        {
            int middle = cur_nonb + (next_nonb - cur_nonb)/2;
            cost += slicetype_frame_cost( h, a, frames, cur_nonb, next_nonb, middle );
            for( int next_b = loc; next_b < middle && cost < threshold; next_b++ )
                cost += slicetype_frame_cost( h, a, frames, cur_nonb, middle, next_b );
            for( int next_b = middle+1; next_b < next_nonb && cost < threshold; next_b++ )
                cost += slicetype_frame_cost( h, a, frames, middle, next_nonb, next_b );
        }
        else
            for( int next_b = loc; next_b < next_nonb && cost < threshold; next_b++ )
                cost += slicetype_frame_cost( h, a, frames, cur_nonb, next_nonb, next_b );

        loc = next_nonb + 1;
        cur_nonb = next_nonb;
    }
    return cost;
}

/* Viterbi/trellis slicetype decision algorithm. */
/* Uses strings due to the fact that the speed of the control functions is
   negligible compared to the cost of running slicetype_frame_cost, and because
   it makes debugging easier. */
static void slicetype_path( x264_t *h, x264_mb_analysis_t *a, x264_frame_t **frames, int length, char (*best_paths)[X264_LOOKAHEAD_MAX+1] )
{
    char paths[2][X264_LOOKAHEAD_MAX+1];
    int num_paths = X264_MIN( h->param.i_bframe+1, length );
    uint64_t best_cost = COST_MAX64;
    int best_possible = 0;
    int idx = 0;

    /* Iterate over all currently possible paths */
    for( int path = 0; path < num_paths; path++ )
    {
        /* Add suffixes to the current path */
        int len = length - (path + 1);
        memcpy( paths[idx], best_paths[len % (X264_BFRAME_MAX+1)], len );
        memset( paths[idx]+len, 'B', path );
        strcpy( paths[idx]+len+path, "P" );

        int possible = 1;
        for( int i = 1; i <= length; i++ )
        {
            int i_type = frames[i]->i_type;
            if( i_type == X264_TYPE_AUTO )
                continue;
            if( IS_X264_TYPE_B( i_type ) )
                possible = possible && (i < len || i == length || paths[idx][i-1] == 'B');
            else
            {
                possible = possible && (i < len || paths[idx][i-1] != 'B');
                paths[idx][i-1] = IS_X264_TYPE_I( i_type ) ? 'I' : 'P';
            }
        }

        if( possible || !best_possible )
        {
            if( possible && !best_possible )
                best_cost = COST_MAX64;
            /* Calculate the actual cost of the current path */
            uint64_t cost = slicetype_path_cost( h, a, frames, paths[idx], best_cost );
            if( cost < best_cost )
            {
                best_cost = cost;
                best_possible = possible;
                idx ^= 1;
            }
        }
    }

    /* Store the best path. */
    memcpy( best_paths[length % (X264_BFRAME_MAX+1)], paths[idx^1], length );
}

static int scenecut_internal( x264_t *h, x264_mb_analysis_t *a, x264_frame_t **frames, int p0, int p1, int real_scenecut )
{
    x264_frame_t *frame = frames[p1];

    /* Don't do scenecuts on the right view of a frame-packed video. */
    if( real_scenecut && h->param.i_frame_packing == 5 && (frame->i_frame&1) )
        return 0;

    slicetype_frame_cost( h, a, frames, p0, p1, p1 );

    int icost = frame->i_cost_est[0][0];
    int pcost = frame->i_cost_est[p1-p0][0];
    float f_bias;
    int i_gop_size = frame->i_frame - h->lookahead->i_last_keyframe;
    float f_thresh_max = h->param.i_scenecut_threshold / 100.0;
    /* magic numbers pulled out of thin air */
    float f_thresh_min = f_thresh_max * 0.25;
    int res;

    if( h->param.i_keyint_min == h->param.i_keyint_max )
        f_thresh_min = f_thresh_max;
    if( i_gop_size <= h->param.i_keyint_min / 4 || h->param.b_intra_refresh )
        f_bias = f_thresh_min / 4;
    else if( i_gop_size <= h->param.i_keyint_min )
        f_bias = f_thresh_min * i_gop_size / h->param.i_keyint_min;
    else
    {
        f_bias = f_thresh_min
                 + ( f_thresh_max - f_thresh_min )
                 * ( i_gop_size - h->param.i_keyint_min )
                 / ( h->param.i_keyint_max - h->param.i_keyint_min );
    }

    res = pcost >= (1.0 - f_bias) * icost;
    if( res && real_scenecut )
    {
        int imb = frame->i_intra_mbs[p1-p0];
        int pmb = NUM_MBS - imb;
        x264_log( h, X264_LOG_DEBUG, "scene cut at %d Icost:%d Pcost:%d ratio:%.4f bias:%.4f gop:%d (imb:%d pmb:%d)\n",
                  frame->i_frame,
                  icost, pcost, 1. - (double)pcost / icost,
                  f_bias, i_gop_size, imb, pmb );
    }
    return res;
}

static int scenecut( x264_t *h, x264_mb_analysis_t *a, x264_frame_t **frames, int p0, int p1, int real_scenecut, int num_frames, int i_max_search )
{
    /* Only do analysis during a normal scenecut check. */
    if( real_scenecut && h->param.i_bframe )
    {
        int origmaxp1 = p0 + 1;
        /* Look ahead to avoid coding short flashes as scenecuts. */
        if( h->param.i_bframe_adaptive == X264_B_ADAPT_TRELLIS )
            /* Don't analyse any more frames than the trellis would have covered. */
            origmaxp1 += h->param.i_bframe;
        else
            origmaxp1++;
        int maxp1 = X264_MIN( origmaxp1, num_frames );

        /* Where A and B are scenes: AAAAAABBBAAAAAA
         * If BBB is shorter than (maxp1-p0), it is detected as a flash
         * and not considered a scenecut. */
        for( int curp1 = p1; curp1 <= maxp1; curp1++ )
            if( !scenecut_internal( h, a, frames, p0, curp1, 0 ) )
                /* Any frame in between p0 and cur_p1 cannot be a real scenecut. */
                for( int i = curp1; i > p0; i-- )
                    frames[i]->b_scenecut = 0;

        /* Where A-F are scenes: AAAAABBCCDDEEFFFFFF
         * If each of BB ... EE are shorter than (maxp1-p0), they are
         * detected as flashes and not considered scenecuts.
         * Instead, the first F frame becomes a scenecut.
         * If the video ends before F, no frame becomes a scenecut. */
        for( int curp0 = p0; curp0 <= maxp1; curp0++ )
            if( origmaxp1 > i_max_search || (curp0 < maxp1 && scenecut_internal( h, a, frames, curp0, maxp1, 0 )) )
                /* If cur_p0 is the p0 of a scenecut, it cannot be the p1 of a scenecut. */
                    frames[curp0]->b_scenecut = 0;
    }

    /* Ignore frames that are part of a flash, i.e. cannot be real scenecuts. */
    if( !frames[p1]->b_scenecut )
        return 0;
    return scenecut_internal( h, a, frames, p0, p1, real_scenecut );
}

#define IS_X264_TYPE_AUTO_OR_I(x) ((x)==X264_TYPE_AUTO || IS_X264_TYPE_I(x))
#define IS_X264_TYPE_AUTO_OR_B(x) ((x)==X264_TYPE_AUTO || IS_X264_TYPE_B(x))

void x264_slicetype_analyse( x264_t *h, int intra_minigop )
{
    x264_mb_analysis_t a;
    x264_frame_t *frames[X264_LOOKAHEAD_MAX+3] = { NULL, };
    int num_frames, orig_num_frames, keyint_limit, framecnt;
    int i_max_search = X264_MIN( h->lookahead->next.i_size, X264_LOOKAHEAD_MAX );
    int b_vbv_lookahead = h->param.rc.i_vbv_buffer_size && h->param.rc.i_lookahead;
    /* For determinism we should limit the search to the number of frames lookahead has for sure
     * in h->lookahead->next.list buffer, except at the end of stream.
     * For normal calls with (intra_minigop == 0) that is h->lookahead->i_slicetype_length + 1 frames.
     * And for I-frame calls (intra_minigop != 0) we already removed intra_minigop frames from there. */
    if( h->param.b_deterministic )
        i_max_search = X264_MIN( i_max_search, h->lookahead->i_slicetype_length + 1 - intra_minigop );
    int keyframe = !!intra_minigop;

    assert( h->frames.b_have_lowres );

    if( !h->lookahead->last_nonb )
        return;
    frames[0] = h->lookahead->last_nonb;
    for( framecnt = 0; framecnt < i_max_search; framecnt++ )
        frames[framecnt+1] = h->lookahead->next.list[framecnt];

    lowres_context_init( h, &a );

    if( !framecnt )
    {
        if( h->param.rc.b_mb_tree )
            macroblock_tree( h, &a, frames, 0, keyframe );
        return;
    }

    keyint_limit = h->param.i_keyint_max - frames[0]->i_frame + h->lookahead->i_last_keyframe - 1;
    orig_num_frames = num_frames = h->param.b_intra_refresh ? framecnt : X264_MIN( framecnt, keyint_limit );

    /* This is important psy-wise: if we have a non-scenecut keyframe,
     * there will be significant visual artifacts if the frames just before
     * go down in quality due to being referenced less, despite it being
     * more RD-optimal. */
    if( (h->param.analyse.b_psy && h->param.rc.b_mb_tree) || b_vbv_lookahead )
        num_frames = framecnt;
    else if( h->param.b_open_gop && num_frames < framecnt )
        num_frames++;
    else if( num_frames == 0 )
    {
        frames[1]->i_type = X264_TYPE_I;
        return;
    }

    if( IS_X264_TYPE_AUTO_OR_I( frames[1]->i_type ) &&
        h->param.i_scenecut_threshold && scenecut( h, &a, frames, 0, 1, 1, orig_num_frames, i_max_search ) )
    {
        if( frames[1]->i_type == X264_TYPE_AUTO )
            frames[1]->i_type = X264_TYPE_I;
        return;
    }

#if HAVE_OPENCL
    x264_opencl_slicetype_prep( h, frames, num_frames, a.i_lambda );
#endif

    /* Replace forced keyframes with I/IDR-frames */
    for( int j = 1; j <= num_frames; j++ )
    {
        if( frames[j]->i_type == X264_TYPE_KEYFRAME )
            frames[j]->i_type = h->param.b_open_gop ? X264_TYPE_I : X264_TYPE_IDR;
    }

    /* Close GOP at IDR-frames */
    for( int j = 2; j <= num_frames; j++ )
    {
        if( frames[j]->i_type == X264_TYPE_IDR && IS_X264_TYPE_AUTO_OR_B( frames[j-1]->i_type ) )
            frames[j-1]->i_type = X264_TYPE_P;
    }

    int num_analysed_frames = num_frames;
    int reset_start;

    if( h->param.i_bframe )
    {
        if( h->param.i_bframe_adaptive == X264_B_ADAPT_TRELLIS )
        {
            if( num_frames > 1 )
            {
                char best_paths[X264_BFRAME_MAX+1][X264_LOOKAHEAD_MAX+1] = {"","P"};
                int best_path_index = num_frames % (X264_BFRAME_MAX+1);

                /* Perform the frametype analysis. */
                for( int j = 2; j <= num_frames; j++ )
                    slicetype_path( h, &a, frames, j, best_paths );

                /* Load the results of the analysis into the frame types. */
                for( int j = 1; j < num_frames; j++ )
                {
                    if( best_paths[best_path_index][j-1] != 'B' )
                    {
                        if( IS_X264_TYPE_AUTO_OR_B( frames[j]->i_type ) )
                            frames[j]->i_type = X264_TYPE_P;
                    }
                    else
                    {
                        if( frames[j]->i_type == X264_TYPE_AUTO )
                            frames[j]->i_type = X264_TYPE_B;
                    }
                }
            }
        }
        else if( h->param.i_bframe_adaptive == X264_B_ADAPT_FAST )
        {
            int last_nonb = 0;
            int num_bframes = h->param.i_bframe;
            char path[X264_LOOKAHEAD_MAX+1];
            for( int j = 1; j < num_frames; j++ )
            {
                if( j-1 > 0 && IS_X264_TYPE_B( frames[j-1]->i_type ) )
                    num_bframes--;
                else
                {
                    last_nonb = j-1;
                    num_bframes = h->param.i_bframe;
                }
                if( !num_bframes )
                {
                    if( IS_X264_TYPE_AUTO_OR_B( frames[j]->i_type ) )
                        frames[j]->i_type = X264_TYPE_P;
                    continue;
                }

                if( frames[j]->i_type != X264_TYPE_AUTO )
                    continue;

                if( IS_X264_TYPE_B( frames[j+1]->i_type ) )
                {
                    frames[j]->i_type = X264_TYPE_P;
                    continue;
                }

                int bframes = j - last_nonb - 1;
                memset( path, 'B', bframes );
                strcpy( path+bframes, "PP" );
                uint64_t cost_p = slicetype_path_cost( h, &a, frames+last_nonb, path, COST_MAX64 );
                strcpy( path+bframes, "BP" );
                uint64_t cost_b = slicetype_path_cost( h, &a, frames+last_nonb, path, cost_p );

                if( cost_b < cost_p )
                    frames[j]->i_type = X264_TYPE_B;
                else
                    frames[j]->i_type = X264_TYPE_P;
            }
        }
        else
        {
            int num_bframes = h->param.i_bframe;
            for( int j = 1; j < num_frames; j++ )
            {
                if( !num_bframes )
                {
                    if( IS_X264_TYPE_AUTO_OR_B( frames[j]->i_type ) )
                        frames[j]->i_type = X264_TYPE_P;
                }
                else if( frames[j]->i_type == X264_TYPE_AUTO )
                {
                    if( IS_X264_TYPE_B( frames[j+1]->i_type ) )
                        frames[j]->i_type = X264_TYPE_P;
                    else
                        frames[j]->i_type = X264_TYPE_B;
                }
                if( IS_X264_TYPE_B( frames[j]->i_type ) )
                    num_bframes--;
                else
                    num_bframes = h->param.i_bframe;
            }
        }
        if( IS_X264_TYPE_AUTO_OR_B( frames[num_frames]->i_type ) )
            frames[num_frames]->i_type = X264_TYPE_P;

        int num_bframes = 0;
        while( num_bframes < num_frames && IS_X264_TYPE_B( frames[num_bframes+1]->i_type ) )
            num_bframes++;

        /* Check scenecut on the first minigop. */
        for( int j = 1; j < num_bframes+1; j++ )
        {
            if( frames[j]->i_forced_type == X264_TYPE_AUTO && IS_X264_TYPE_AUTO_OR_I( frames[j+1]->i_forced_type ) &&
                h->param.i_scenecut_threshold && scenecut( h, &a, frames, j, j+1, 0, orig_num_frames, i_max_search ) )
            {
                frames[j]->i_type = X264_TYPE_P;
                num_analysed_frames = j;
                break;
            }
        }

        reset_start = keyframe ? 1 : X264_MIN( num_bframes+2, num_analysed_frames+1 );
    }
    else
    {
        for( int j = 1; j <= num_frames; j++ )
            if( IS_X264_TYPE_AUTO_OR_B( frames[j]->i_type ) )
                frames[j]->i_type = X264_TYPE_P;
        reset_start = !keyframe + 1;
    }

    /* Perform the actual macroblock tree analysis.
     * Don't go farther than the maximum keyframe interval; this helps in short GOPs. */
    if( h->param.rc.b_mb_tree )
        macroblock_tree( h, &a, frames, X264_MIN(num_frames, h->param.i_keyint_max), keyframe );

    /* Enforce keyframe limit. */
    if( !h->param.b_intra_refresh )
    {
        int last_keyframe = h->lookahead->i_last_keyframe;
        int last_possible = 0;
        for( int j = 1; j <= num_frames; j++ )
        {
            x264_frame_t *frm = frames[j];
            int keyframe_dist = frm->i_frame - last_keyframe;

            if( IS_X264_TYPE_AUTO_OR_I( frm->i_forced_type ) )
            {
                if( h->param.b_open_gop || !IS_X264_TYPE_B( frames[j-1]->i_forced_type ) )
                    last_possible = j;
            }
            if( keyframe_dist >= h->param.i_keyint_max )
            {
                if( last_possible != 0 && last_possible != j )
                {
                    j = last_possible;
                    frm = frames[j];
                    keyframe_dist = frm->i_frame - last_keyframe;
                }
                last_possible = 0;
                if( frm->i_type != X264_TYPE_IDR )
                    frm->i_type = h->param.b_open_gop ? X264_TYPE_I : X264_TYPE_IDR;
            }
            if( frm->i_type == X264_TYPE_I && keyframe_dist >= h->param.i_keyint_min )
            {
                if( h->param.b_open_gop )
                {
                    last_keyframe = frm->i_frame;
                    if( h->param.b_bluray_compat )
                    {
                        // Use bluray order
                        int bframes = 0;
                        while( bframes < j-1 && IS_X264_TYPE_B( frames[j-1-bframes]->i_type ) )
                            bframes++;
                        last_keyframe -= bframes;
                    }
                }
                else if( frm->i_forced_type != X264_TYPE_I )
                    frm->i_type = X264_TYPE_IDR;
            }
            if( frm->i_type == X264_TYPE_IDR )
            {
                last_keyframe = frm->i_frame;
                if( j > 1 && IS_X264_TYPE_B( frames[j-1]->i_type ) )
                    frames[j-1]->i_type = X264_TYPE_P;
            }
        }
    }

    if( b_vbv_lookahead )
        vbv_lookahead( h, &a, frames, num_frames, keyframe );

    /* Restore frametypes for all frames that haven't actually been decided yet. */
    for( int j = reset_start; j <= num_frames; j++ )
        frames[j]->i_type = frames[j]->i_forced_type;

#if HAVE_OPENCL
    x264_opencl_slicetype_end( h );
#endif
}

void x264_slicetype_decide( x264_t *h )
{
    x264_frame_t *frames[X264_BFRAME_MAX+2];
    x264_frame_t *frm;
    int bframes;
    int brefs;

    if( !h->lookahead->next.i_size )
        return;

    int lookahead_size = h->lookahead->next.i_size;

    for( int i = 0; i < h->lookahead->next.i_size; i++ )
    {
        if( h->param.b_vfr_input )
        {
            if( lookahead_size-- > 1 )
                h->lookahead->next.list[i]->i_duration = 2 * (h->lookahead->next.list[i+1]->i_pts - h->lookahead->next.list[i]->i_pts);
            else
                h->lookahead->next.list[i]->i_duration = h->i_prev_duration;
        }
        else
            h->lookahead->next.list[i]->i_duration = delta_tfi_divisor[h->lookahead->next.list[i]->i_pic_struct];
        h->i_prev_duration = h->lookahead->next.list[i]->i_duration;
        h->lookahead->next.list[i]->f_duration = (double)h->lookahead->next.list[i]->i_duration
                                               * h->sps->vui.i_num_units_in_tick
                                               / h->sps->vui.i_time_scale;

        if( h->lookahead->next.list[i]->i_frame > h->i_disp_fields_last_frame && lookahead_size > 0 )
        {
            h->lookahead->next.list[i]->i_field_cnt = h->i_disp_fields;
            h->i_disp_fields += h->lookahead->next.list[i]->i_duration;
            h->i_disp_fields_last_frame = h->lookahead->next.list[i]->i_frame;
        }
        else if( lookahead_size == 0 )
        {
            h->lookahead->next.list[i]->i_field_cnt = h->i_disp_fields;
            h->lookahead->next.list[i]->i_duration = h->i_prev_duration;
        }
    }

    if( h->param.rc.b_stat_read )
    {
        /* Use the frame types from the first pass */
        for( int i = 0; i < h->lookahead->next.i_size; i++ )
            h->lookahead->next.list[i]->i_type =
                x264_ratecontrol_slice_type( h, h->lookahead->next.list[i]->i_frame );
    }
    else if( (h->param.i_bframe && h->param.i_bframe_adaptive)
             || h->param.i_scenecut_threshold
             || h->param.rc.b_mb_tree
             || (h->param.rc.i_vbv_buffer_size && h->param.rc.i_lookahead) )
        x264_slicetype_analyse( h, 0 );

    for( bframes = 0, brefs = 0;; bframes++ )
    {
        frm = h->lookahead->next.list[bframes];

        if( frm->i_forced_type != X264_TYPE_AUTO && frm->i_type != frm->i_forced_type &&
            !(frm->i_forced_type == X264_TYPE_KEYFRAME && IS_X264_TYPE_I( frm->i_type )) )
        {
            x264_log( h, X264_LOG_WARNING, "forced frame type (%d) at %d was changed to frame type (%d)\n",
                      frm->i_forced_type, frm->i_frame, frm->i_type );
        }

        if( frm->i_type == X264_TYPE_BREF && h->param.i_bframe_pyramid < X264_B_PYRAMID_NORMAL &&
            brefs == h->param.i_bframe_pyramid )
        {
            frm->i_type = X264_TYPE_B;
            x264_log( h, X264_LOG_WARNING, "B-ref at frame %d incompatible with B-pyramid %s \n",
                      frm->i_frame, x264_b_pyramid_names[h->param.i_bframe_pyramid] );
        }
        /* pyramid with multiple B-refs needs a big enough dpb that the preceding P-frame stays available.
           smaller dpb could be supported by smart enough use of mmco, but it's easier just to forbid it. */
        else if( frm->i_type == X264_TYPE_BREF && h->param.i_bframe_pyramid == X264_B_PYRAMID_NORMAL &&
            brefs && h->param.i_frame_reference <= (brefs+3) )
        {
            frm->i_type = X264_TYPE_B;
            x264_log( h, X264_LOG_WARNING, "B-ref at frame %d incompatible with B-pyramid %s and %d reference frames\n",
                      frm->i_frame, x264_b_pyramid_names[h->param.i_bframe_pyramid], h->param.i_frame_reference );
        }

        if( frm->i_type == X264_TYPE_KEYFRAME )
            frm->i_type = h->param.b_open_gop ? X264_TYPE_I : X264_TYPE_IDR;

        /* Limit GOP size */
        if( (!h->param.b_intra_refresh || frm->i_frame == 0) && frm->i_frame - h->lookahead->i_last_keyframe >= h->param.i_keyint_max )
        {
            if( frm->i_type == X264_TYPE_AUTO || frm->i_type == X264_TYPE_I )
                frm->i_type = h->param.b_open_gop && h->lookahead->i_last_keyframe >= 0 ? X264_TYPE_I : X264_TYPE_IDR;
            int warn = frm->i_type != X264_TYPE_IDR;
            if( warn && h->param.b_open_gop )
                warn &= frm->i_type != X264_TYPE_I;
            if( warn )
            {
                x264_log( h, X264_LOG_WARNING, "specified frame type (%d) at %d is not compatible with keyframe interval\n", frm->i_type, frm->i_frame );
                frm->i_type = h->param.b_open_gop && h->lookahead->i_last_keyframe >= 0 ? X264_TYPE_I : X264_TYPE_IDR;
            }
        }
        if( frm->i_type == X264_TYPE_I && frm->i_frame - h->lookahead->i_last_keyframe >= h->param.i_keyint_min )
        {
            if( h->param.b_open_gop )
            {
                h->lookahead->i_last_keyframe = frm->i_frame; // Use display order
                if( h->param.b_bluray_compat )
                    h->lookahead->i_last_keyframe -= bframes; // Use bluray order
                frm->b_keyframe = 1;
            }
            else
                frm->i_type = X264_TYPE_IDR;
        }
        if( frm->i_type == X264_TYPE_IDR )
        {
            /* Close GOP */
            h->lookahead->i_last_keyframe = frm->i_frame;
            frm->b_keyframe = 1;
            if( bframes > 0 )
            {
                bframes--;
                h->lookahead->next.list[bframes]->i_type = X264_TYPE_P;
            }
        }

        if( bframes == h->param.i_bframe ||
            !h->lookahead->next.list[bframes+1] )
        {
            if( IS_X264_TYPE_B( frm->i_type ) )
                x264_log( h, X264_LOG_WARNING, "specified frame type is not compatible with max B-frames\n" );
            if( frm->i_type == X264_TYPE_AUTO
                || IS_X264_TYPE_B( frm->i_type ) )
                frm->i_type = X264_TYPE_P;
        }

        if( frm->i_type == X264_TYPE_BREF )
            brefs++;

        if( frm->i_type == X264_TYPE_AUTO )
            frm->i_type = X264_TYPE_B;

        else if( !IS_X264_TYPE_B( frm->i_type ) ) break;
    }

    if( bframes )
        h->lookahead->next.list[bframes-1]->b_last_minigop_bframe = 1;
    h->lookahead->next.list[bframes]->i_bframes = bframes;

    /* insert a bref into the sequence */
    if( h->param.i_bframe_pyramid && bframes > 1 && !brefs )
    {
        h->lookahead->next.list[(bframes-1)/2]->i_type = X264_TYPE_BREF;
        brefs++;
    }

    /* calculate the frame costs ahead of time for x264_rc_analyse_slice while we still have lowres */
    if( h->param.rc.i_rc_method != X264_RC_CQP )
    {
        x264_mb_analysis_t a;
        int p0, p1, b;
        p1 = b = bframes + 1;

        lowres_context_init( h, &a );

        frames[0] = h->lookahead->last_nonb;
        memcpy( &frames[1], h->lookahead->next.list, (bframes+1) * sizeof(x264_frame_t*) );
        if( IS_X264_TYPE_I( h->lookahead->next.list[bframes]->i_type ) )
            p0 = bframes + 1;
        else // P
            p0 = 0;

        slicetype_frame_cost( h, &a, frames, p0, p1, b );

        if( (p0 != p1 || bframes) && h->param.rc.i_vbv_buffer_size )
        {
            /* We need the intra costs for row SATDs. */
            slicetype_frame_cost( h, &a, frames, b, b, b );

            /* We need B-frame costs for row SATDs. */
            p0 = 0;
            for( b = 1; b <= bframes; b++ )
            {
                if( frames[b]->i_type == X264_TYPE_B )
                    for( p1 = b; frames[p1]->i_type == X264_TYPE_B; )
                        p1++;
                else
                    p1 = bframes + 1;
                slicetype_frame_cost( h, &a, frames, p0, p1, b );
                if( frames[b]->i_type == X264_TYPE_BREF )
                    p0 = b;
            }
        }
    }

    /* Analyse for weighted P frames */
    if( !h->param.rc.b_stat_read && h->lookahead->next.list[bframes]->i_type == X264_TYPE_P
        && h->param.analyse.i_weighted_pred >= X264_WEIGHTP_SIMPLE )
    {
        x264_emms();
        x264_weights_analyse( h, h->lookahead->next.list[bframes], h->lookahead->last_nonb, 0 );
    }

    /* shift sequence to coded order.
       use a small temporary list to avoid shifting the entire next buffer around */
    int i_coded = h->lookahead->next.list[0]->i_frame;
    if( bframes )
    {
        int idx_list[] = { brefs+1, 1 };
        for( int i = 0; i < bframes; i++ )
        {
            int idx = idx_list[h->lookahead->next.list[i]->i_type == X264_TYPE_BREF]++;
            frames[idx] = h->lookahead->next.list[i];
            frames[idx]->i_reordered_pts = h->lookahead->next.list[idx]->i_pts;
        }
        frames[0] = h->lookahead->next.list[bframes];
        frames[0]->i_reordered_pts = h->lookahead->next.list[0]->i_pts;
        memcpy( h->lookahead->next.list, frames, (bframes+1) * sizeof(x264_frame_t*) );
    }

    for( int i = 0; i <= bframes; i++ )
    {
        h->lookahead->next.list[i]->i_coded = i_coded++;
        if( i )
        {
            calculate_durations( h, h->lookahead->next.list[i], h->lookahead->next.list[i-1], &h->i_cpb_delay, &h->i_coded_fields );
            h->lookahead->next.list[0]->f_planned_cpb_duration[i-1] = (double)h->lookahead->next.list[i]->i_cpb_duration *
                                                                      h->sps->vui.i_num_units_in_tick / h->sps->vui.i_time_scale;
        }
        else
            calculate_durations( h, h->lookahead->next.list[i], NULL, &h->i_cpb_delay, &h->i_coded_fields );
    }
}

int x264_rc_analyse_slice( x264_t *h )
{
    int p0 = 0, p1, b;
    int cost;
    x264_emms();

    if( IS_X264_TYPE_I(h->fenc->i_type) )
        p1 = b = 0;
    else if( h->fenc->i_type == X264_TYPE_P )
        p1 = b = h->fenc->i_bframes + 1;
    else //B
    {
        p1 = (h->fref_nearest[1]->i_poc - h->fref_nearest[0]->i_poc)/2;
        b  = (h->fenc->i_poc - h->fref_nearest[0]->i_poc)/2;
    }
    /* We don't need to assign p0/p1 since we are not performing any real analysis here. */
    x264_frame_t **frames = &h->fenc - b;

    /* cost should have been already calculated by x264_slicetype_decide */
    cost = frames[b]->i_cost_est[b-p0][p1-b];
    assert( cost >= 0 );

    if( h->param.rc.b_mb_tree && !h->param.rc.b_stat_read )
    {
        cost = slicetype_frame_cost_recalculate( h, frames, p0, p1, b );
        if( b && h->param.rc.i_vbv_buffer_size )
            slicetype_frame_cost_recalculate( h, frames, b, b, b );
    }
    /* In AQ, use the weighted score instead. */
    else if( h->param.rc.i_aq_mode )
        cost = frames[b]->i_cost_est_aq[b-p0][p1-b];

    h->fenc->i_row_satd = h->fenc->i_row_satds[b-p0][p1-b];
    h->fdec->i_row_satd = h->fdec->i_row_satds[b-p0][p1-b];
    h->fdec->i_satd = cost;
    memcpy( h->fdec->i_row_satd, h->fenc->i_row_satd, h->mb.i_mb_height * sizeof(int) );
    if( !IS_X264_TYPE_I(h->fenc->i_type) )
        memcpy( h->fdec->i_row_satds[0][0], h->fenc->i_row_satds[0][0], h->mb.i_mb_height * sizeof(int) );

    if( h->param.b_intra_refresh && h->param.rc.i_vbv_buffer_size && h->fenc->i_type == X264_TYPE_P )
    {
        int ip_factor = 256 * h->param.rc.f_ip_factor; /* fix8 */
        for( int y = 0; y < h->mb.i_mb_height; y++ )
        {
            int mb_xy = y * h->mb.i_mb_stride + h->fdec->i_pir_start_col;
            for( int x = h->fdec->i_pir_start_col; x <= h->fdec->i_pir_end_col; x++, mb_xy++ )
            {
                int intra_cost = (h->fenc->i_intra_cost[mb_xy] * ip_factor + 128) >> 8;
                int inter_cost = h->fenc->lowres_costs[b-p0][p1-b][mb_xy] & LOWRES_COST_MASK;
                int diff = intra_cost - inter_cost;
                if( h->param.rc.i_aq_mode )
                    h->fdec->i_row_satd[y] += (diff * frames[b]->i_inv_qscale_factor[mb_xy] + 128) >> 8;
                else
                    h->fdec->i_row_satd[y] += diff;
                cost += diff;
            }
        }
    }

    return cost;
}
