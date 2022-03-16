/*****************************************************************************
 * encoder.c: top-level encoder functions
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

#include "common/common.h"

#include "set.h"
#include "analyse.h"
#include "ratecontrol.h"
#include "macroblock.h"
#include "me.h"
#if HAVE_INTEL_DISPATCHER
#include "extras/intel_dispatcher.h"
#endif

//#define DEBUG_MB_TYPE

#define bs_write_ue bs_write_ue_big

// forward declaration needed for template usage
void x264_nal_encode( x264_t *h, uint8_t *dst, x264_nal_t *nal );
void x264_macroblock_cache_load_progressive( x264_t *h, int i_mb_x, int i_mb_y );

static int encoder_frame_end( x264_t *h, x264_t *thread_current,
                              x264_nal_t **pp_nal, int *pi_nal,
                              x264_picture_t *pic_out );

/****************************************************************************
 *
 ******************************* x264 libs **********************************
 *
 ****************************************************************************/
static double calc_psnr( double sqe, double size )
{
    double mse = sqe / (PIXEL_MAX*PIXEL_MAX * size);
    if( mse <= 0.0000000001 ) /* Max 100dB */
        return 100;

    return -10.0 * log10( mse );
}

static double calc_ssim_db( double ssim )
{
    double inv_ssim = 1 - ssim;
    if( inv_ssim <= 0.0000000001 ) /* Max 100dB */
        return 100;

    return -10.0 * log10( inv_ssim );
}

static int threadpool_wait_all( x264_t *h )
{
    for( int i = 0; i < h->param.i_threads; i++ )
        if( h->thread[i]->b_thread_active )
        {
            h->thread[i]->b_thread_active = 0;
            if( (intptr_t)x264_threadpool_wait( h->threadpool, h->thread[i] ) < 0 )
                return -1;
        }
    return 0;
}

static void frame_dump( x264_t *h )
{
    FILE *f = x264_fopen( h->param.psz_dump_yuv, "r+b" );
    if( !f )
        return;

    /* Wait for the threads to finish deblocking */
    if( h->param.b_sliced_threads )
        threadpool_wait_all( h );

    /* Write the frame in display order */
    int frame_size = FRAME_SIZE( h->param.i_height * h->param.i_width * SIZEOF_PIXEL );
    if( !fseek( f, (int64_t)h->fdec->i_frame * frame_size, SEEK_SET ) )
    {
        for( int p = 0; p < (CHROMA444 ? 3 : 1); p++ )
            for( int y = 0; y < h->param.i_height; y++ )
                fwrite( &h->fdec->plane[p][y*h->fdec->i_stride[p]], SIZEOF_PIXEL, h->param.i_width, f );
        if( CHROMA_FORMAT == CHROMA_420 || CHROMA_FORMAT == CHROMA_422 )
        {
            int cw = h->param.i_width>>1;
            int ch = h->param.i_height>>CHROMA_V_SHIFT;
            pixel *planeu = x264_malloc( 2 * (cw*ch*SIZEOF_PIXEL + 32) );
            if( planeu )
            {
                pixel *planev = planeu + cw*ch + 32/SIZEOF_PIXEL;
                h->mc.plane_copy_deinterleave( planeu, cw, planev, cw, h->fdec->plane[1], h->fdec->i_stride[1], cw, ch );
                fwrite( planeu, 1, cw*ch*SIZEOF_PIXEL, f );
                fwrite( planev, 1, cw*ch*SIZEOF_PIXEL, f );
                x264_free( planeu );
            }
        }
    }
    fclose( f );
}

/* Fill "default" values */
static void slice_header_init( x264_t *h, x264_slice_header_t *sh,
                               x264_sps_t *sps, x264_pps_t *pps,
                               int i_idr_pic_id, int i_frame, int i_qp )
{
    x264_param_t *param = &h->param;

    /* First we fill all fields */
    sh->sps = sps;
    sh->pps = pps;

    sh->i_first_mb  = 0;
    sh->i_last_mb   = h->mb.i_mb_count - 1;
    sh->i_pps_id    = pps->i_id;

    sh->i_frame_num = i_frame;

    sh->b_mbaff = PARAM_INTERLACED;
    sh->b_field_pic = 0;    /* no field support for now */
    sh->b_bottom_field = 0; /* not yet used */

    sh->i_idr_pic_id = i_idr_pic_id;

    /* poc stuff, fixed later */
    sh->i_poc = 0;
    sh->i_delta_poc_bottom = 0;
    sh->i_delta_poc[0] = 0;
    sh->i_delta_poc[1] = 0;

    sh->i_redundant_pic_cnt = 0;

    h->mb.b_direct_auto_write = h->param.analyse.i_direct_mv_pred == X264_DIRECT_PRED_AUTO
                                && h->param.i_bframe
                                && ( h->param.rc.b_stat_write || !h->param.rc.b_stat_read );

    if( !h->mb.b_direct_auto_read && sh->i_type == SLICE_TYPE_B )
    {
        if( h->fref[1][0]->i_poc_l0ref0 == h->fref[0][0]->i_poc )
        {
            if( h->mb.b_direct_auto_write )
                sh->b_direct_spatial_mv_pred = ( h->stat.i_direct_score[1] > h->stat.i_direct_score[0] );
            else
                sh->b_direct_spatial_mv_pred = ( param->analyse.i_direct_mv_pred == X264_DIRECT_PRED_SPATIAL );
        }
        else
        {
            h->mb.b_direct_auto_write = 0;
            sh->b_direct_spatial_mv_pred = 1;
        }
    }
    /* else b_direct_spatial_mv_pred was read from the 2pass statsfile */

    sh->b_num_ref_idx_override = 0;
    sh->i_num_ref_idx_l0_active = 1;
    sh->i_num_ref_idx_l1_active = 1;

    sh->b_ref_pic_list_reordering[0] = h->b_ref_reorder[0];
    sh->b_ref_pic_list_reordering[1] = h->b_ref_reorder[1];

    /* If the ref list isn't in the default order, construct reordering header */
    for( int list = 0; list < 2; list++ )
    {
        if( sh->b_ref_pic_list_reordering[list] )
        {
            int pred_frame_num = i_frame;
            for( int i = 0; i < h->i_ref[list]; i++ )
            {
                int diff = h->fref[list][i]->i_frame_num - pred_frame_num;
                sh->ref_pic_list_order[list][i].idc = ( diff > 0 );
                sh->ref_pic_list_order[list][i].arg = (abs(diff) - 1) & ((1 << sps->i_log2_max_frame_num) - 1);
                pred_frame_num = h->fref[list][i]->i_frame_num;
            }
        }
    }

    sh->i_cabac_init_idc = param->i_cabac_init_idc;

    sh->i_qp = SPEC_QP(i_qp);
    sh->i_qp_delta = sh->i_qp - pps->i_pic_init_qp;
    sh->b_sp_for_swidth = 0;
    sh->i_qs_delta = 0;

    int deblock_thresh = i_qp + 2 * X264_MIN(param->i_deblocking_filter_alphac0, param->i_deblocking_filter_beta);
    /* If effective qp <= 15, deblocking would have no effect anyway */
    if( param->b_deblocking_filter && (h->mb.b_variable_qp || 15 < deblock_thresh ) )
        sh->i_disable_deblocking_filter_idc = param->b_sliced_threads ? 2 : 0;
    else
        sh->i_disable_deblocking_filter_idc = 1;
    sh->i_alpha_c0_offset = param->i_deblocking_filter_alphac0 * 2;
    sh->i_beta_offset = param->i_deblocking_filter_beta * 2;
}

static void slice_header_write( bs_t *s, x264_slice_header_t *sh, int i_nal_ref_idc )
{
    if( sh->b_mbaff )
    {
        int first_x = sh->i_first_mb % sh->sps->i_mb_width;
        int first_y = sh->i_first_mb / sh->sps->i_mb_width;
        assert( (first_y&1) == 0 );
        bs_write_ue( s, (2*first_x + sh->sps->i_mb_width*(first_y&~1) + (first_y&1)) >> 1 );
    }
    else
        bs_write_ue( s, sh->i_first_mb );

    bs_write_ue( s, sh->i_type + 5 );   /* same type things */
    bs_write_ue( s, sh->i_pps_id );
    bs_write( s, sh->sps->i_log2_max_frame_num, sh->i_frame_num & ((1<<sh->sps->i_log2_max_frame_num)-1) );

    if( !sh->sps->b_frame_mbs_only )
    {
        bs_write1( s, sh->b_field_pic );
        if( sh->b_field_pic )
            bs_write1( s, sh->b_bottom_field );
    }

    if( sh->i_idr_pic_id >= 0 ) /* NAL IDR */
        bs_write_ue( s, sh->i_idr_pic_id );

    if( sh->sps->i_poc_type == 0 )
    {
        bs_write( s, sh->sps->i_log2_max_poc_lsb, sh->i_poc & ((1<<sh->sps->i_log2_max_poc_lsb)-1) );
        if( sh->pps->b_pic_order && !sh->b_field_pic )
            bs_write_se( s, sh->i_delta_poc_bottom );
    }

    if( sh->pps->b_redundant_pic_cnt )
        bs_write_ue( s, sh->i_redundant_pic_cnt );

    if( sh->i_type == SLICE_TYPE_B )
        bs_write1( s, sh->b_direct_spatial_mv_pred );

    if( sh->i_type == SLICE_TYPE_P || sh->i_type == SLICE_TYPE_B )
    {
        bs_write1( s, sh->b_num_ref_idx_override );
        if( sh->b_num_ref_idx_override )
        {
            bs_write_ue( s, sh->i_num_ref_idx_l0_active - 1 );
            if( sh->i_type == SLICE_TYPE_B )
                bs_write_ue( s, sh->i_num_ref_idx_l1_active - 1 );
        }
    }

    /* ref pic list reordering */
    if( sh->i_type != SLICE_TYPE_I )
    {
        bs_write1( s, sh->b_ref_pic_list_reordering[0] );
        if( sh->b_ref_pic_list_reordering[0] )
        {
            for( int i = 0; i < sh->i_num_ref_idx_l0_active; i++ )
            {
                bs_write_ue( s, sh->ref_pic_list_order[0][i].idc );
                bs_write_ue( s, sh->ref_pic_list_order[0][i].arg );
            }
            bs_write_ue( s, 3 );
        }
    }
    if( sh->i_type == SLICE_TYPE_B )
    {
        bs_write1( s, sh->b_ref_pic_list_reordering[1] );
        if( sh->b_ref_pic_list_reordering[1] )
        {
            for( int i = 0; i < sh->i_num_ref_idx_l1_active; i++ )
            {
                bs_write_ue( s, sh->ref_pic_list_order[1][i].idc );
                bs_write_ue( s, sh->ref_pic_list_order[1][i].arg );
            }
            bs_write_ue( s, 3 );
        }
    }

    sh->b_weighted_pred = 0;
    if( sh->pps->b_weighted_pred && sh->i_type == SLICE_TYPE_P )
    {
        sh->b_weighted_pred = sh->weight[0][0].weightfn || sh->weight[0][1].weightfn || sh->weight[0][2].weightfn;
        /* pred_weight_table() */
        bs_write_ue( s, sh->weight[0][0].i_denom ); /* luma_log2_weight_denom */
        if( sh->sps->i_chroma_format_idc )
            bs_write_ue( s, sh->weight[0][1].i_denom ); /* chroma_log2_weight_denom */
        for( int i = 0; i < sh->i_num_ref_idx_l0_active; i++ )
        {
            int luma_weight_l0_flag = !!sh->weight[i][0].weightfn;
            bs_write1( s, luma_weight_l0_flag );
            if( luma_weight_l0_flag )
            {
                bs_write_se( s, sh->weight[i][0].i_scale );
                bs_write_se( s, sh->weight[i][0].i_offset );
            }
            if( sh->sps->i_chroma_format_idc )
            {
                int chroma_weight_l0_flag = sh->weight[i][1].weightfn || sh->weight[i][2].weightfn;
                bs_write1( s, chroma_weight_l0_flag );
                if( chroma_weight_l0_flag )
                {
                    for( int j = 1; j < 3; j++ )
                    {
                        bs_write_se( s, sh->weight[i][j].i_scale );
                        bs_write_se( s, sh->weight[i][j].i_offset );
                    }
                }
            }
        }
    }
    else if( sh->pps->b_weighted_bipred == 1 && sh->i_type == SLICE_TYPE_B )
    {
      /* TODO */
    }

    if( i_nal_ref_idc != 0 )
    {
        if( sh->i_idr_pic_id >= 0 )
        {
            bs_write1( s, 0 );  /* no output of prior pics flag */
            bs_write1( s, 0 );  /* long term reference flag */
        }
        else
        {
            bs_write1( s, sh->i_mmco_command_count > 0 ); /* adaptive_ref_pic_marking_mode_flag */
            if( sh->i_mmco_command_count > 0 )
            {
                for( int i = 0; i < sh->i_mmco_command_count; i++ )
                {
                    bs_write_ue( s, 1 ); /* mark short term ref as unused */
                    bs_write_ue( s, sh->mmco[i].i_difference_of_pic_nums - 1 );
                }
                bs_write_ue( s, 0 ); /* end command list */
            }
        }
    }

    if( sh->pps->b_cabac && sh->i_type != SLICE_TYPE_I )
        bs_write_ue( s, sh->i_cabac_init_idc );

    bs_write_se( s, sh->i_qp_delta );      /* slice qp delta */

    if( sh->pps->b_deblocking_filter_control )
    {
        bs_write_ue( s, sh->i_disable_deblocking_filter_idc );
        if( sh->i_disable_deblocking_filter_idc != 1 )
        {
            bs_write_se( s, sh->i_alpha_c0_offset >> 1 );
            bs_write_se( s, sh->i_beta_offset >> 1 );
        }
    }
}

/* If we are within a reasonable distance of the end of the memory allocated for the bitstream, */
/* reallocate, adding an arbitrary amount of space. */
static int bitstream_check_buffer_internal( x264_t *h, int size, int b_cabac, int i_nal )
{
    if( (b_cabac && (h->cabac.p_end - h->cabac.p < size)) ||
        (h->out.bs.p_end - h->out.bs.p < size) )
    {
        if( size > INT_MAX - h->out.i_bitstream )
            return -1;
        int buf_size = h->out.i_bitstream + size;
        uint8_t *buf = x264_malloc( buf_size );
        if( !buf )
            return -1;
        int aligned_size = h->out.i_bitstream & ~15;
        h->mc.memcpy_aligned( buf, h->out.p_bitstream, aligned_size );
        memcpy( buf + aligned_size, h->out.p_bitstream + aligned_size, h->out.i_bitstream - aligned_size );

        intptr_t delta = buf - h->out.p_bitstream;

        h->out.bs.p_start += delta;
        h->out.bs.p += delta;
        h->out.bs.p_end = buf + buf_size;

        h->cabac.p_start += delta;
        h->cabac.p += delta;
        h->cabac.p_end = buf + buf_size;

        for( int i = 0; i <= i_nal; i++ )
            h->out.nal[i].p_payload += delta;

        x264_free( h->out.p_bitstream );
        h->out.p_bitstream = buf;
        h->out.i_bitstream = buf_size;
    }
    return 0;
}

static int bitstream_check_buffer( x264_t *h )
{
    int max_row_size = (2500 << SLICE_MBAFF) * h->mb.i_mb_width;
    return bitstream_check_buffer_internal( h, max_row_size, h->param.b_cabac, h->out.i_nal );
}

static int bitstream_check_buffer_filler( x264_t *h, int filler )
{
    filler += 32; // add padding for safety
    return bitstream_check_buffer_internal( h, filler, 0, -1 );
}

/****************************************************************************
 *
 ****************************************************************************
 ****************************** External API*********************************
 ****************************************************************************
 *
 ****************************************************************************/

static int validate_parameters( x264_t *h, int b_open )
{
    if( !h->param.pf_log )
    {
        x264_log_internal( X264_LOG_ERROR, "pf_log not set! did you forget to call x264_param_default?\n" );
        return -1;
    }

#if HAVE_MMX
    if( b_open )
    {
        uint32_t cpuflags = x264_cpu_detect();
        int fail = 0;
#ifdef __SSE__
        if( !(cpuflags & X264_CPU_SSE) )
        {
            x264_log( h, X264_LOG_ERROR, "your cpu does not support SSE1, but x264 was compiled with asm\n");
            fail = 1;
        }
#else
        if( !(cpuflags & X264_CPU_MMX2) )
        {
            x264_log( h, X264_LOG_ERROR, "your cpu does not support MMXEXT, but x264 was compiled with asm\n");
            fail = 1;
        }
#endif
        if( fail )
        {
            x264_log( h, X264_LOG_ERROR, "to run x264, recompile without asm (configure --disable-asm)\n");
            return -1;
        }
    }
#endif

#if HAVE_INTERLACED
    h->param.b_interlaced = !!PARAM_INTERLACED;
#else
    if( h->param.b_interlaced )
    {
        x264_log( h, X264_LOG_ERROR, "not compiled with interlaced support\n" );
        return -1;
    }
#endif

#define MAX_RESOLUTION 16384
    if( h->param.i_width <= 0 || h->param.i_height <= 0 ||
        h->param.i_width > MAX_RESOLUTION || h->param.i_height > MAX_RESOLUTION )
    {
        x264_log( h, X264_LOG_ERROR, "invalid width x height (%dx%d)\n",
                  h->param.i_width, h->param.i_height );
        return -1;
    }

    int i_csp = h->param.i_csp & X264_CSP_MASK;
#if X264_CHROMA_FORMAT
    if( CHROMA_FORMAT != CHROMA_400 && i_csp == X264_CSP_I400 )
    {
        x264_log( h, X264_LOG_ERROR, "not compiled with 4:0:0 support\n" );
        return -1;
    }
    else if( CHROMA_FORMAT != CHROMA_420 && i_csp >= X264_CSP_I420 && i_csp < X264_CSP_I422 )
    {
        x264_log( h, X264_LOG_ERROR, "not compiled with 4:2:0 support\n" );
        return -1;
    }
    else if( CHROMA_FORMAT != CHROMA_422 && i_csp >= X264_CSP_I422 && i_csp < X264_CSP_I444 )
    {
        x264_log( h, X264_LOG_ERROR, "not compiled with 4:2:2 support\n" );
        return -1;
    }
    else if( CHROMA_FORMAT != CHROMA_444 && i_csp >= X264_CSP_I444 && i_csp <= X264_CSP_RGB )
    {
        x264_log( h, X264_LOG_ERROR, "not compiled with 4:4:4 support\n" );
        return -1;
    }
#endif
    if( i_csp <= X264_CSP_NONE || i_csp >= X264_CSP_MAX )
    {
        x264_log( h, X264_LOG_ERROR, "invalid CSP (only I400/I420/YV12/NV12/NV21/I422/YV16/NV16/YUYV/UYVY/"
                                     "I444/YV24/BGR/BGRA/RGB supported)\n" );
        return -1;
    }

    int w_mod = 1;
    int h_mod = 1 << (PARAM_INTERLACED || h->param.b_fake_interlaced);
    if( i_csp == X264_CSP_I400 )
    {
        h->param.analyse.i_chroma_qp_offset = 0;
        h->param.analyse.b_chroma_me = 0;
        h->param.vui.i_colmatrix = 2; /* undefined */
    }
    else if( i_csp < X264_CSP_I444 )
    {
        w_mod = 2;
        if( i_csp < X264_CSP_I422 )
            h_mod *= 2;
    }

    if( h->param.i_width % w_mod )
    {
        x264_log( h, X264_LOG_ERROR, "width not divisible by %d (%dx%d)\n",
                  w_mod, h->param.i_width, h->param.i_height );
        return -1;
    }
    if( h->param.i_height % h_mod )
    {
        x264_log( h, X264_LOG_ERROR, "height not divisible by %d (%dx%d)\n",
                  h_mod, h->param.i_width, h->param.i_height );
        return -1;
    }

    if( h->param.crop_rect.i_left   < 0 || h->param.crop_rect.i_left   >= h->param.i_width ||
        h->param.crop_rect.i_right  < 0 || h->param.crop_rect.i_right  >= h->param.i_width ||
        h->param.crop_rect.i_top    < 0 || h->param.crop_rect.i_top    >= h->param.i_height ||
        h->param.crop_rect.i_bottom < 0 || h->param.crop_rect.i_bottom >= h->param.i_height ||
        h->param.crop_rect.i_left + h->param.crop_rect.i_right  >= h->param.i_width ||
        h->param.crop_rect.i_top  + h->param.crop_rect.i_bottom >= h->param.i_height )
    {
        x264_log( h, X264_LOG_ERROR, "invalid crop-rect %d,%d,%d,%d\n", h->param.crop_rect.i_left,
                  h->param.crop_rect.i_top, h->param.crop_rect.i_right,  h->param.crop_rect.i_bottom );
        return -1;
    }
    if( h->param.crop_rect.i_left % w_mod || h->param.crop_rect.i_right  % w_mod ||
        h->param.crop_rect.i_top  % h_mod || h->param.crop_rect.i_bottom % h_mod )
    {
        x264_log( h, X264_LOG_ERROR, "crop-rect %d,%d,%d,%d not divisible by %dx%d\n", h->param.crop_rect.i_left,
                  h->param.crop_rect.i_top, h->param.crop_rect.i_right,  h->param.crop_rect.i_bottom, w_mod, h_mod );
        return -1;
    }

    if( h->param.vui.i_sar_width <= 0 || h->param.vui.i_sar_height <= 0 )
    {
        h->param.vui.i_sar_width = 0;
        h->param.vui.i_sar_height = 0;
    }

    if( h->param.i_threads == X264_THREADS_AUTO )
    {
        h->param.i_threads = x264_cpu_num_processors() * (h->param.b_sliced_threads?2:3)/2;
        /* Avoid too many threads as they don't improve performance and
         * complicate VBV. Capped at an arbitrary 2 rows per thread. */
        int max_threads = X264_MAX( 1, (h->param.i_height+15)/16 / 2 );
        h->param.i_threads = X264_MIN( h->param.i_threads, max_threads );
    }
    int max_sliced_threads = X264_MAX( 1, (h->param.i_height+15)/16 / 4 );
    if( h->param.i_threads > 1 )
    {
#if !HAVE_THREAD
        x264_log( h, X264_LOG_WARNING, "not compiled with thread support!\n");
        h->param.i_threads = 1;
#endif
        /* Avoid absurdly small thread slices as they can reduce performance
         * and VBV compliance.  Capped at an arbitrary 4 rows per thread. */
        if( h->param.b_sliced_threads )
            h->param.i_threads = X264_MIN( h->param.i_threads, max_sliced_threads );
    }
    h->param.i_threads = x264_clip3( h->param.i_threads, 1, X264_THREAD_MAX );
    if( h->param.i_threads == 1 )
    {
        h->param.b_sliced_threads = 0;
        h->param.i_lookahead_threads = 1;
    }
    h->i_thread_frames = h->param.b_sliced_threads ? 1 : h->param.i_threads;
    if( h->i_thread_frames > 1 )
        h->param.nalu_process = NULL;

    if( h->param.b_opencl )
    {
#if !HAVE_OPENCL
        x264_log( h, X264_LOG_WARNING, "OpenCL: not compiled with OpenCL support, disabling\n" );
        h->param.b_opencl = 0;
#elif BIT_DEPTH > 8
        x264_log( h, X264_LOG_WARNING, "OpenCL lookahead does not support high bit depth, disabling opencl\n" );
        h->param.b_opencl = 0;
#else
        if( h->param.i_width < 32 || h->param.i_height < 32 )
        {
            x264_log( h, X264_LOG_WARNING, "OpenCL: frame size is too small, disabling opencl\n" );
            h->param.b_opencl = 0;
        }
#endif
        if( h->param.opencl_device_id && h->param.i_opencl_device )
        {
            x264_log( h, X264_LOG_WARNING, "OpenCL: device id and device skip count configured; dropping skip\n" );
            h->param.i_opencl_device = 0;
        }
    }

    h->param.i_keyint_max = x264_clip3( h->param.i_keyint_max, 1, X264_KEYINT_MAX_INFINITE );
    if( h->param.i_keyint_max == 1 )
    {
        h->param.b_intra_refresh = 0;
        h->param.analyse.i_weighted_pred = 0;
        h->param.i_frame_reference = 1;
        h->param.i_dpb_size = 1;
    }

    if( h->param.i_frame_packing < -1 || h->param.i_frame_packing > 7 )
    {
        x264_log( h, X264_LOG_WARNING, "ignoring unknown frame packing value\n" );
        h->param.i_frame_packing = -1;
    }
    if( h->param.i_frame_packing == 7 &&
        ((h->param.i_width - h->param.crop_rect.i_left - h->param.crop_rect.i_right)  % 3 ||
         (h->param.i_height - h->param.crop_rect.i_top - h->param.crop_rect.i_bottom) % 3) )
    {
        x264_log( h, X264_LOG_ERROR, "cropped resolution %dx%d not compatible with tile format frame packing\n",
                  h->param.i_width - h->param.crop_rect.i_left - h->param.crop_rect.i_right,
                  h->param.i_height - h->param.crop_rect.i_top - h->param.crop_rect.i_bottom );
        return -1;
    }

    if( h->param.mastering_display.b_mastering_display )
    {
        if( h->param.mastering_display.i_green_x > UINT16_MAX || h->param.mastering_display.i_green_x < 0 ||
            h->param.mastering_display.i_green_y > UINT16_MAX || h->param.mastering_display.i_green_y < 0 ||
            h->param.mastering_display.i_blue_x > UINT16_MAX || h->param.mastering_display.i_blue_x < 0 ||
            h->param.mastering_display.i_blue_y > UINT16_MAX || h->param.mastering_display.i_blue_y < 0 ||
            h->param.mastering_display.i_red_x > UINT16_MAX || h->param.mastering_display.i_red_x < 0 ||
            h->param.mastering_display.i_red_y > UINT16_MAX || h->param.mastering_display.i_red_y < 0 ||
            h->param.mastering_display.i_white_x > UINT16_MAX || h->param.mastering_display.i_white_x < 0 ||
            h->param.mastering_display.i_white_y > UINT16_MAX || h->param.mastering_display.i_white_y < 0 )
        {
            x264_log( h, X264_LOG_ERROR, "mastering display xy coordinates out of range [0,%u]\n", UINT16_MAX );
            return -1;
        }
        if( h->param.mastering_display.i_display_max > UINT32_MAX || h->param.mastering_display.i_display_max < 0 ||
            h->param.mastering_display.i_display_min > UINT32_MAX || h->param.mastering_display.i_display_min < 0 )
        {
            x264_log( h, X264_LOG_ERROR, "mastering display brightness out of range [0,%u]\n", UINT32_MAX );
            return -1;
        }
        if( h->param.mastering_display.i_display_min == 50000 && h->param.mastering_display.i_display_max == 50000 )
        {
            x264_log( h, X264_LOG_ERROR, "mastering display min and max brightness cannot both be 50000\n" );
            return -1;
        }
    }

    if( h->param.content_light_level.b_cll &&
        (h->param.content_light_level.i_max_cll > UINT16_MAX || h->param.content_light_level.i_max_cll < 0 ||
         h->param.content_light_level.i_max_fall > UINT16_MAX || h->param.content_light_level.i_max_fall < 0) )
    {
        x264_log( h, X264_LOG_ERROR, "content light levels out of range [0,%u]\n", UINT16_MAX );
        return -1;
    }

    /* Detect default ffmpeg settings and terminate with an error. */
    if( b_open )
    {
        int score = 0;
        score += h->param.analyse.i_me_range == 0;
        score += h->param.rc.i_qp_step == 3;
        score += h->param.i_keyint_max == 12;
        score += h->param.rc.i_qp_min == 2;
        score += h->param.rc.i_qp_max == 31;
        score += h->param.rc.f_qcompress == 0.5;
        score += fabs(h->param.rc.f_ip_factor - 1.25) < 0.01;
        score += fabs(h->param.rc.f_pb_factor - 1.25) < 0.01;
        score += h->param.analyse.inter == 0 && h->param.analyse.i_subpel_refine == 8;
        if( score >= 5 )
        {
            x264_log( h, X264_LOG_ERROR, "broken ffmpeg default settings detected\n" );
            x264_log( h, X264_LOG_ERROR, "use an encoding preset (e.g. -vpre medium)\n" );
            x264_log( h, X264_LOG_ERROR, "preset usage: -vpre <speed> -vpre <profile>\n" );
            x264_log( h, X264_LOG_ERROR, "speed presets are listed in x264 --help\n" );
            x264_log( h, X264_LOG_ERROR, "profile is optional; x264 defaults to high\n" );
            return -1;
        }
    }

    if( h->param.rc.i_rc_method < 0 || h->param.rc.i_rc_method > 2 )
    {
        x264_log( h, X264_LOG_ERROR, "no ratecontrol method specified\n" );
        return -1;
    }

    if( PARAM_INTERLACED )
        h->param.b_pic_struct = 1;

    if( h->param.i_avcintra_class )
    {
        if( BIT_DEPTH != 10 )
        {
            x264_log( h, X264_LOG_ERROR, "%2d-bit AVC-Intra is not widely compatible\n", BIT_DEPTH );
            x264_log( h, X264_LOG_ERROR, "10-bit x264 is required to encode AVC-Intra\n" );
            return -1;
        }

        int type = h->param.i_avcintra_class == 480 ? 4 :
                   h->param.i_avcintra_class == 300 ? 3 :
                   h->param.i_avcintra_class == 200 ? 2 :
                   h->param.i_avcintra_class == 100 ? 1 :
                   h->param.i_avcintra_class == 50 ? 0 : -1;
        if( type < 0 )
        {
            x264_log( h, X264_LOG_ERROR, "Invalid AVC-Intra class\n" );
            return -1;
        }
        else if( type > 2 && h->param.i_avcintra_flavor != X264_AVCINTRA_FLAVOR_SONY )
        {
            x264_log( h, X264_LOG_ERROR, "AVC-Intra %d only supported by Sony XAVC flavor\n", h->param.i_avcintra_class );
            return -1;
        }

        /* [50/100/200/300/480][res][fps] */
        static const struct
        {
            uint16_t fps_num;
            uint16_t fps_den;
            uint8_t interlaced;
            uint16_t frame_size;
            const uint8_t *cqm_4iy;
            const uint8_t *cqm_4ic;
            const uint8_t *cqm_8iy;
        } avcintra_lut[5][2][7] =
        {
            {{{ 60000, 1001, 0,   912, x264_cqm_jvt4i, x264_cqm_avci50_4ic, x264_cqm_avci50_p_8iy },
              {    50,    1, 0,  1100, x264_cqm_jvt4i, x264_cqm_avci50_4ic, x264_cqm_avci50_p_8iy },
              { 30000, 1001, 0,   912, x264_cqm_jvt4i, x264_cqm_avci50_4ic, x264_cqm_avci50_p_8iy },
              {    25,    1, 0,  1100, x264_cqm_jvt4i, x264_cqm_avci50_4ic, x264_cqm_avci50_p_8iy },
              { 24000, 1001, 0,   912, x264_cqm_jvt4i, x264_cqm_avci50_4ic, x264_cqm_avci50_p_8iy }},
             {{ 30000, 1001, 1,  1820, x264_cqm_jvt4i, x264_cqm_avci50_4ic, x264_cqm_avci50_1080i_8iy },
              {    25,    1, 1,  2196, x264_cqm_jvt4i, x264_cqm_avci50_4ic, x264_cqm_avci50_1080i_8iy },
              { 60000, 1001, 0,  1820, x264_cqm_jvt4i, x264_cqm_avci50_4ic, x264_cqm_avci50_p_8iy },
              { 30000, 1001, 0,  1820, x264_cqm_jvt4i, x264_cqm_avci50_4ic, x264_cqm_avci50_p_8iy },
              {    50,    1, 0,  2196, x264_cqm_jvt4i, x264_cqm_avci50_4ic, x264_cqm_avci50_p_8iy },
              {    25,    1, 0,  2196, x264_cqm_jvt4i, x264_cqm_avci50_4ic, x264_cqm_avci50_p_8iy },
              { 24000, 1001, 0,  1820, x264_cqm_jvt4i, x264_cqm_avci50_4ic, x264_cqm_avci50_p_8iy }}},
            {{{ 60000, 1001, 0,  1848, x264_cqm_jvt4i, x264_cqm_avci100_720p_4ic, x264_cqm_avci100_720p_8iy  },
              {    50,    1, 0,  2224, x264_cqm_jvt4i, x264_cqm_avci100_720p_4ic, x264_cqm_avci100_720p_8iy  },
              { 30000, 1001, 0,  1848, x264_cqm_jvt4i, x264_cqm_avci100_720p_4ic, x264_cqm_avci100_720p_8iy  },
              {    25,    1, 0,  2224, x264_cqm_jvt4i, x264_cqm_avci100_720p_4ic, x264_cqm_avci100_720p_8iy  },
              { 24000, 1001, 0,  1848, x264_cqm_jvt4i, x264_cqm_avci100_720p_4ic, x264_cqm_avci100_720p_8iy  }},
             {{ 30000, 1001, 1,  3692, x264_cqm_jvt4i, x264_cqm_avci100_1080_4ic, x264_cqm_avci100_1080i_8iy },
              {    25,    1, 1,  4444, x264_cqm_jvt4i, x264_cqm_avci100_1080_4ic, x264_cqm_avci100_1080i_8iy },
              { 60000, 1001, 0,  3692, x264_cqm_jvt4i, x264_cqm_avci100_1080_4ic, x264_cqm_avci100_1080p_8iy },
              { 30000, 1001, 0,  3692, x264_cqm_jvt4i, x264_cqm_avci100_1080_4ic, x264_cqm_avci100_1080p_8iy },
              {    50,    1, 0,  4444, x264_cqm_jvt4i, x264_cqm_avci100_1080_4ic, x264_cqm_avci100_1080p_8iy },
              {    25,    1, 0,  4444, x264_cqm_jvt4i, x264_cqm_avci100_1080_4ic, x264_cqm_avci100_1080p_8iy },
              { 24000, 1001, 0,  3692, x264_cqm_jvt4i, x264_cqm_avci100_1080_4ic, x264_cqm_avci100_1080p_8iy }}},
            {{{ 60000, 1001, 0,  3724, x264_cqm_jvt4i, x264_cqm_avci100_720p_4ic, x264_cqm_avci100_720p_8iy  },
              {    50,    1, 0,  4472, x264_cqm_jvt4i, x264_cqm_avci100_720p_4ic, x264_cqm_avci100_720p_8iy  }},
             {{ 30000, 1001, 1,  7444, x264_cqm_jvt4i, x264_cqm_avci100_1080_4ic, x264_cqm_avci100_1080i_8iy },
              {    25,    1, 1,  8940, x264_cqm_jvt4i, x264_cqm_avci100_1080_4ic, x264_cqm_avci100_1080i_8iy },
              { 60000, 1001, 0,  7444, x264_cqm_jvt4i, x264_cqm_avci100_1080_4ic, x264_cqm_avci100_1080p_8iy },
              { 30000, 1001, 0,  7444, x264_cqm_jvt4i, x264_cqm_avci100_1080_4ic, x264_cqm_avci100_1080p_8iy },
              {    50,    1, 0,  8940, x264_cqm_jvt4i, x264_cqm_avci100_1080_4ic, x264_cqm_avci100_1080p_8iy },
              {    25,    1, 0,  8940, x264_cqm_jvt4i, x264_cqm_avci100_1080_4ic, x264_cqm_avci100_1080p_8iy },
              { 24000, 1001, 0,  7444, x264_cqm_jvt4i, x264_cqm_avci100_1080_4ic, x264_cqm_avci100_1080p_8iy }}},
            {{{ 60000, 1001, 0,  9844, x264_cqm_avci300_2160p_4iy, x264_cqm_avci300_2160p_4ic, x264_cqm_avci300_2160p_8iy },
              {    50,    1, 0,  9844, x264_cqm_avci300_2160p_4iy, x264_cqm_avci300_2160p_4ic, x264_cqm_avci300_2160p_8iy },
              { 30000, 1001, 0,  9844, x264_cqm_avci300_2160p_4iy, x264_cqm_avci300_2160p_4ic, x264_cqm_avci300_2160p_8iy },
              {    25,    1, 0,  9844, x264_cqm_avci300_2160p_4iy, x264_cqm_avci300_2160p_4ic, x264_cqm_avci300_2160p_8iy },
              { 24000, 1001, 0,  9844, x264_cqm_avci300_2160p_4iy, x264_cqm_avci300_2160p_4ic, x264_cqm_avci300_2160p_8iy }}},
            {{{ 60000, 1001, 0, 15700, x264_cqm_avci300_2160p_4iy, x264_cqm_avci300_2160p_4ic, x264_cqm_avci300_2160p_8iy },
              {    50,    1, 0, 15700, x264_cqm_avci300_2160p_4iy, x264_cqm_avci300_2160p_4ic, x264_cqm_avci300_2160p_8iy },
              { 30000, 1001, 0, 15700, x264_cqm_avci300_2160p_4iy, x264_cqm_avci300_2160p_4ic, x264_cqm_avci300_2160p_8iy },
              {    25,    1, 0, 15700, x264_cqm_avci300_2160p_4iy, x264_cqm_avci300_2160p_4ic, x264_cqm_avci300_2160p_8iy },
              { 24000, 1001, 0, 15700, x264_cqm_avci300_2160p_4iy, x264_cqm_avci300_2160p_4ic, x264_cqm_avci300_2160p_8iy }}}
        };

        int res = -1;
        if( i_csp >= X264_CSP_I420 && i_csp < X264_CSP_I422 && !type )
        {
            if(      h->param.i_width == 1440 && h->param.i_height == 1080 ) res = 1;
            else if( h->param.i_width ==  960 && h->param.i_height ==  720 ) res = 0;
        }
        else if( i_csp >= X264_CSP_I422 && i_csp < X264_CSP_I444 && type )
        {
            if( type < 3 )
            {
                if(      h->param.i_width == 1920 && h->param.i_height == 1080 ) res = 1;
                else if( h->param.i_width == 2048 && h->param.i_height == 1080 ) res = 1;
                else if( h->param.i_width == 1280 && h->param.i_height ==  720 ) res = 0;
            }
            else
            {
                if(      h->param.i_width == 3840 && h->param.i_height == 2160 ) res = 0;
                else if( h->param.i_width == 4096 && h->param.i_height == 2160 ) res = 0;
            }
        }
        else
        {
            x264_log( h, X264_LOG_ERROR, "Invalid colorspace for AVC-Intra %d\n", h->param.i_avcintra_class );
            return -1;
        }

        if( res < 0 )
        {
            x264_log( h, X264_LOG_ERROR, "Resolution %dx%d invalid for AVC-Intra %d\n",
                      h->param.i_width, h->param.i_height, h->param.i_avcintra_class );
            return -1;
        }

        if( h->param.nalu_process )
        {
            x264_log( h, X264_LOG_ERROR, "nalu_process is not supported in AVC-Intra mode\n" );
            return -1;
        }

        if( !h->param.b_repeat_headers )
        {
            x264_log( h, X264_LOG_ERROR, "Separate headers not supported in AVC-Intra mode\n" );
            return -1;
        }

        int i;
        uint32_t fps_num = h->param.i_fps_num, fps_den = h->param.i_fps_den;
        x264_reduce_fraction( &fps_num, &fps_den );
        for( i = 0; i < 7; i++ )
        {
            if( avcintra_lut[type][res][i].fps_num == fps_num &&
                avcintra_lut[type][res][i].fps_den == fps_den &&
                avcintra_lut[type][res][i].interlaced == PARAM_INTERLACED )
            {
                break;
            }
        }
        if( i == 7 )
        {
            x264_log( h, X264_LOG_ERROR, "FPS %d/%d%c not compatible with AVC-Intra %d\n",
                      h->param.i_fps_num, h->param.i_fps_den, PARAM_INTERLACED ? 'i' : 'p', h->param.i_avcintra_class );
            return -1;
        }

        h->param.i_keyint_max = 1;
        h->param.b_intra_refresh = 0;
        h->param.analyse.i_weighted_pred = 0;
        h->param.i_frame_reference = 1;
        h->param.i_dpb_size = 1;

        h->param.b_bluray_compat = 0;
        h->param.b_vfr_input = 0;
        h->param.b_aud = 1;
        h->param.vui.i_chroma_loc = 0;
        h->param.i_nal_hrd = X264_NAL_HRD_NONE;
        h->param.b_deblocking_filter = 0;
        h->param.b_stitchable = 1;
        h->param.b_pic_struct = 0;
        h->param.analyse.b_transform_8x8 = 1;
        h->param.analyse.intra = X264_ANALYSE_I8x8;
        h->param.analyse.i_chroma_qp_offset = type > 2 ? -4 : res && type ? 3 : 4;
        h->param.b_cabac = !type;
        h->param.rc.i_vbv_buffer_size = avcintra_lut[type][res][i].frame_size;
        h->param.rc.i_vbv_max_bitrate =
        h->param.rc.i_bitrate = h->param.rc.i_vbv_buffer_size * fps_num / fps_den;
        h->param.rc.i_rc_method = X264_RC_ABR;
        h->param.rc.f_vbv_buffer_init = 1.0;
        h->param.rc.b_filler = 1;
        h->param.i_cqm_preset = X264_CQM_CUSTOM;
        memcpy( h->param.cqm_4iy, avcintra_lut[type][res][i].cqm_4iy, sizeof(h->param.cqm_4iy) );
        memcpy( h->param.cqm_4ic, avcintra_lut[type][res][i].cqm_4ic, sizeof(h->param.cqm_4ic) );
        memcpy( h->param.cqm_8iy, avcintra_lut[type][res][i].cqm_8iy, sizeof(h->param.cqm_8iy) );

        /* Sony XAVC flavor much more simple */
        if( h->param.i_avcintra_flavor == X264_AVCINTRA_FLAVOR_SONY )
        {
            h->param.i_slice_count = 8;
            if( h->param.b_sliced_threads )
                h->param.i_threads = h->param.i_slice_count;
            /* Sony XAVC unlike AVC-Intra doesn't seem to have a QP floor */
        }
        else
        {
            /* Need exactly 10 slices of equal MB count... why?  $deity knows... */
            h->param.i_slice_max_mbs = ((h->param.i_width + 15) / 16) * ((h->param.i_height + 15) / 16) / 10;
            h->param.i_slice_max_size = 0;
            /* The slice structure only allows a maximum of 2 threads for 1080i/p
             * and 1 or 5 threads for 720p */
            if( h->param.b_sliced_threads )
            {
                if( res )
                    h->param.i_threads = X264_MIN( 2, h->param.i_threads );
                else
                {
                    h->param.i_threads = X264_MIN( 5, h->param.i_threads );
                    if( h->param.i_threads < 5 )
                        h->param.i_threads = 1;
                }
            }

            /* Official encoder doesn't appear to go under 13
             * and Avid cannot handle negative QPs */
            h->param.rc.i_qp_min = X264_MAX( h->param.rc.i_qp_min, QP_BD_OFFSET + 1 );
        }

        if( type )
            h->param.vui.i_sar_width = h->param.vui.i_sar_height = 1;
        else
        {
            h->param.vui.i_sar_width  = 4;
            h->param.vui.i_sar_height = 3;
        }
    }

    h->param.rc.f_rf_constant = x264_clip3f( h->param.rc.f_rf_constant, -QP_BD_OFFSET, 51 );
    h->param.rc.f_rf_constant_max = x264_clip3f( h->param.rc.f_rf_constant_max, -QP_BD_OFFSET, 51 );
    h->param.rc.i_qp_constant = x264_clip3( h->param.rc.i_qp_constant, -1, QP_MAX );
    h->param.analyse.i_subpel_refine = x264_clip3( h->param.analyse.i_subpel_refine, 0, 11 );
    h->param.rc.f_ip_factor = x264_clip3f( h->param.rc.f_ip_factor, 0.01, 10.0 );
    h->param.rc.f_pb_factor = x264_clip3f( h->param.rc.f_pb_factor, 0.01, 10.0 );
    if( h->param.rc.i_rc_method == X264_RC_CRF )
    {
        h->param.rc.i_qp_constant = h->param.rc.f_rf_constant + QP_BD_OFFSET;
        h->param.rc.i_bitrate = 0;
    }
    if( b_open && (h->param.rc.i_rc_method == X264_RC_CQP || h->param.rc.i_rc_method == X264_RC_CRF)
        && h->param.rc.i_qp_constant == 0 )
    {
        h->mb.b_lossless = 1;
        h->param.i_cqm_preset = X264_CQM_FLAT;
        h->param.psz_cqm_file = NULL;
        h->param.rc.i_rc_method = X264_RC_CQP;
        h->param.rc.f_ip_factor = 1;
        h->param.rc.f_pb_factor = 1;
        h->param.analyse.b_psnr = 0;
        h->param.analyse.b_ssim = 0;
        h->param.analyse.i_chroma_qp_offset = 0;
        h->param.analyse.i_trellis = 0;
        h->param.analyse.b_fast_pskip = 0;
        h->param.analyse.i_noise_reduction = 0;
        h->param.analyse.b_psy = 0;
        h->param.i_bframe = 0;
        /* 8x8dct is not useful without RD in CAVLC lossless */
        if( !h->param.b_cabac && h->param.analyse.i_subpel_refine < 6 )
            h->param.analyse.b_transform_8x8 = 0;
    }
    if( h->param.rc.i_rc_method == X264_RC_CQP )
    {
        float qp_p = h->param.rc.i_qp_constant;
        float qp_i = qp_p - 6*log2f( h->param.rc.f_ip_factor );
        float qp_b = qp_p + 6*log2f( h->param.rc.f_pb_factor );
        if( qp_p < 0 )
        {
            x264_log( h, X264_LOG_ERROR, "qp not specified\n" );
            return -1;
        }

        h->param.rc.i_qp_min = x264_clip3( (int)(X264_MIN3( qp_p, qp_i, qp_b )), 0, QP_MAX );
        h->param.rc.i_qp_max = x264_clip3( (int)(X264_MAX3( qp_p, qp_i, qp_b ) + .999), 0, QP_MAX );
        h->param.rc.i_aq_mode = 0;
        h->param.rc.b_mb_tree = 0;
        h->param.rc.i_bitrate = 0;
    }
    h->param.rc.i_qp_max = x264_clip3( h->param.rc.i_qp_max, 0, QP_MAX );
    h->param.rc.i_qp_min = x264_clip3( h->param.rc.i_qp_min, 0, h->param.rc.i_qp_max );
    h->param.rc.i_qp_step = x264_clip3( h->param.rc.i_qp_step, 2, QP_MAX );
    h->param.rc.i_bitrate = x264_clip3( h->param.rc.i_bitrate, 0, 2000000 );
    if( h->param.rc.i_rc_method == X264_RC_ABR && !h->param.rc.i_bitrate )
    {
        x264_log( h, X264_LOG_ERROR, "bitrate not specified\n" );
        return -1;
    }
    h->param.rc.i_vbv_buffer_size = x264_clip3( h->param.rc.i_vbv_buffer_size, 0, 2000000 );
    h->param.rc.i_vbv_max_bitrate = x264_clip3( h->param.rc.i_vbv_max_bitrate, 0, 2000000 );
    h->param.rc.f_vbv_buffer_init = x264_clip3f( h->param.rc.f_vbv_buffer_init, 0, 2000000 );
    if( h->param.rc.i_vbv_buffer_size )
    {
        if( h->param.rc.i_rc_method == X264_RC_CQP )
        {
            x264_log( h, X264_LOG_WARNING, "VBV is incompatible with constant QP, ignored.\n" );
            h->param.rc.i_vbv_max_bitrate = 0;
            h->param.rc.i_vbv_buffer_size = 0;
        }
        else if( h->param.rc.i_vbv_max_bitrate == 0 )
        {
            if( h->param.rc.i_rc_method == X264_RC_ABR )
            {
                x264_log( h, X264_LOG_WARNING, "VBV maxrate unspecified, assuming CBR\n" );
                h->param.rc.i_vbv_max_bitrate = h->param.rc.i_bitrate;
            }
            else
            {
                x264_log( h, X264_LOG_WARNING, "VBV bufsize set but maxrate unspecified, ignored\n" );
                h->param.rc.i_vbv_buffer_size = 0;
            }
        }
        else if( h->param.rc.i_vbv_max_bitrate < h->param.rc.i_bitrate &&
                 h->param.rc.i_rc_method == X264_RC_ABR )
        {
            x264_log( h, X264_LOG_WARNING, "max bitrate less than average bitrate, assuming CBR\n" );
            h->param.rc.i_bitrate = h->param.rc.i_vbv_max_bitrate;
        }
    }
    else if( h->param.rc.i_vbv_max_bitrate )
    {
        x264_log( h, X264_LOG_WARNING, "VBV maxrate specified, but no bufsize, ignored\n" );
        h->param.rc.i_vbv_max_bitrate = 0;
    }

    h->param.i_slice_max_size = X264_MAX( h->param.i_slice_max_size, 0 );
    h->param.i_slice_max_mbs = X264_MAX( h->param.i_slice_max_mbs, 0 );
    h->param.i_slice_min_mbs = X264_MAX( h->param.i_slice_min_mbs, 0 );
    if( h->param.i_slice_max_mbs )
        h->param.i_slice_min_mbs = X264_MIN( h->param.i_slice_min_mbs, h->param.i_slice_max_mbs/2 );
    else if( !h->param.i_slice_max_size )
        h->param.i_slice_min_mbs = 0;
    if( PARAM_INTERLACED && h->param.i_slice_min_mbs )
    {
        x264_log( h, X264_LOG_WARNING, "interlace + slice-min-mbs is not implemented\n" );
        h->param.i_slice_min_mbs = 0;
    }
    int mb_width = (h->param.i_width+15)/16;
    if( h->param.i_slice_min_mbs > mb_width )
    {
        x264_log( h, X264_LOG_WARNING, "slice-min-mbs > row mb size (%d) not implemented\n", mb_width );
        h->param.i_slice_min_mbs = mb_width;
    }

    int max_slices = (h->param.i_height+((16<<PARAM_INTERLACED)-1))/(16<<PARAM_INTERLACED);
    if( h->param.b_sliced_threads )
        h->param.i_slice_count = x264_clip3( h->param.i_threads, 0, max_slices );
    else
    {
        h->param.i_slice_count = x264_clip3( h->param.i_slice_count, 0, max_slices );
        if( h->param.i_slice_max_mbs || h->param.i_slice_max_size )
            h->param.i_slice_count = 0;
    }
    if( h->param.i_slice_count_max > 0 )
        h->param.i_slice_count_max = X264_MAX( h->param.i_slice_count, h->param.i_slice_count_max );

    if( h->param.b_bluray_compat )
    {
        h->param.i_bframe_pyramid = X264_MIN( X264_B_PYRAMID_STRICT, h->param.i_bframe_pyramid );
        h->param.i_bframe = X264_MIN( h->param.i_bframe, 3 );
        h->param.b_aud = 1;
        h->param.i_nal_hrd = X264_MAX( h->param.i_nal_hrd, X264_NAL_HRD_VBR );
        h->param.i_slice_max_size = 0;
        h->param.i_slice_max_mbs = 0;
        h->param.b_intra_refresh = 0;
        h->param.i_frame_reference = X264_MIN( h->param.i_frame_reference, 6 );
        h->param.i_dpb_size = X264_MIN( h->param.i_dpb_size, 6 );
        /* Don't use I-frames, because Blu-ray treats them the same as IDR. */
        h->param.i_keyint_min = 1;
        /* Due to the proliferation of broken players that don't handle dupes properly. */
        h->param.analyse.i_weighted_pred = X264_MIN( h->param.analyse.i_weighted_pred, X264_WEIGHTP_SIMPLE );
        if( h->param.b_fake_interlaced )
            h->param.b_pic_struct = 1;
    }

    h->param.i_frame_reference = x264_clip3( h->param.i_frame_reference, 1, X264_REF_MAX );
    h->param.i_dpb_size = x264_clip3( h->param.i_dpb_size, 1, X264_REF_MAX );
    if( h->param.i_scenecut_threshold < 0 )
        h->param.i_scenecut_threshold = 0;
    h->param.analyse.i_direct_mv_pred = x264_clip3( h->param.analyse.i_direct_mv_pred, X264_DIRECT_PRED_NONE, X264_DIRECT_PRED_AUTO );
    if( !h->param.analyse.i_subpel_refine && h->param.analyse.i_direct_mv_pred > X264_DIRECT_PRED_SPATIAL )
    {
        x264_log( h, X264_LOG_WARNING, "subme=0 + direct=temporal is not supported\n" );
        h->param.analyse.i_direct_mv_pred = X264_DIRECT_PRED_SPATIAL;
    }
    h->param.i_bframe = x264_clip3( h->param.i_bframe, 0, X264_MIN( X264_BFRAME_MAX, h->param.i_keyint_max-1 ) );
    h->param.i_bframe_bias = x264_clip3( h->param.i_bframe_bias, -90, 100 );
    if( h->param.i_bframe <= 1 )
        h->param.i_bframe_pyramid = X264_B_PYRAMID_NONE;
    h->param.i_bframe_pyramid = x264_clip3( h->param.i_bframe_pyramid, X264_B_PYRAMID_NONE, X264_B_PYRAMID_NORMAL );
    h->param.i_bframe_adaptive = x264_clip3( h->param.i_bframe_adaptive, X264_B_ADAPT_NONE, X264_B_ADAPT_TRELLIS );
    if( !h->param.i_bframe )
    {
        h->param.i_bframe_adaptive = X264_B_ADAPT_NONE;
        h->param.analyse.i_direct_mv_pred = 0;
        h->param.analyse.b_weighted_bipred = 0;
        h->param.b_open_gop = 0;
    }
    if( h->param.b_intra_refresh && h->param.i_bframe_pyramid == X264_B_PYRAMID_NORMAL )
    {
        x264_log( h, X264_LOG_WARNING, "b-pyramid normal + intra-refresh is not supported\n" );
        h->param.i_bframe_pyramid = X264_B_PYRAMID_STRICT;
    }
    if( h->param.b_intra_refresh && (h->param.i_frame_reference > 1 || h->param.i_dpb_size > 1) )
    {
        x264_log( h, X264_LOG_WARNING, "ref > 1 + intra-refresh is not supported\n" );
        h->param.i_frame_reference = 1;
        h->param.i_dpb_size = 1;
    }
    if( h->param.b_intra_refresh && h->param.b_open_gop )
    {
        x264_log( h, X264_LOG_WARNING, "intra-refresh is not compatible with open-gop\n" );
        h->param.b_open_gop = 0;
    }
    if( !h->param.i_fps_num || !h->param.i_fps_den )
    {
        h->param.i_fps_num = 25;
        h->param.i_fps_den = 1;
    }
    float fps = (float)h->param.i_fps_num / h->param.i_fps_den;
    if( h->param.i_keyint_min == X264_KEYINT_MIN_AUTO )
        h->param.i_keyint_min = X264_MIN( h->param.i_keyint_max / 10, (int)fps );
    h->param.i_keyint_min = x264_clip3( h->param.i_keyint_min, 1, h->param.i_keyint_max/2+1 );
    h->param.rc.i_lookahead = x264_clip3( h->param.rc.i_lookahead, 0, X264_LOOKAHEAD_MAX );
    {
        int maxrate = X264_MAX( h->param.rc.i_vbv_max_bitrate, h->param.rc.i_bitrate );
        float bufsize = maxrate ? (float)h->param.rc.i_vbv_buffer_size / maxrate : 0;
        h->param.rc.i_lookahead = X264_MIN( h->param.rc.i_lookahead, X264_MAX( h->param.i_keyint_max, bufsize*fps ) );
    }

    if( !h->param.i_timebase_num || !h->param.i_timebase_den || !(h->param.b_vfr_input || h->param.b_pulldown) )
    {
        h->param.i_timebase_num = h->param.i_fps_den;
        h->param.i_timebase_den = h->param.i_fps_num;
    }

    h->param.rc.f_qcompress = x264_clip3f( h->param.rc.f_qcompress, 0.0, 1.0 );
    if( h->param.i_keyint_max == 1 || h->param.rc.f_qcompress == 1 )
        h->param.rc.b_mb_tree = 0;
    if( (!h->param.b_intra_refresh && h->param.i_keyint_max != X264_KEYINT_MAX_INFINITE) &&
        !h->param.rc.i_lookahead && h->param.rc.b_mb_tree )
    {
        x264_log( h, X264_LOG_WARNING, "lookaheadless mb-tree requires intra refresh or infinite keyint\n" );
        h->param.rc.b_mb_tree = 0;
    }
    if( b_open && h->param.rc.b_stat_read )
        h->param.rc.i_lookahead = 0;
#if HAVE_THREAD
    if( h->param.i_sync_lookahead < 0 )
        h->param.i_sync_lookahead = h->param.i_bframe + 1;
    h->param.i_sync_lookahead = X264_MIN( h->param.i_sync_lookahead, X264_LOOKAHEAD_MAX );
    if( h->param.rc.b_stat_read || h->i_thread_frames == 1 )
        h->param.i_sync_lookahead = 0;
#else
    h->param.i_sync_lookahead = 0;
#endif

    h->param.i_deblocking_filter_alphac0 = x264_clip3( h->param.i_deblocking_filter_alphac0, -6, 6 );
    h->param.i_deblocking_filter_beta    = x264_clip3( h->param.i_deblocking_filter_beta, -6, 6 );
    h->param.analyse.i_luma_deadzone[0] = x264_clip3( h->param.analyse.i_luma_deadzone[0], 0, 32 );
    h->param.analyse.i_luma_deadzone[1] = x264_clip3( h->param.analyse.i_luma_deadzone[1], 0, 32 );

    h->param.i_cabac_init_idc = x264_clip3( h->param.i_cabac_init_idc, 0, 2 );

    if( h->param.i_cqm_preset < X264_CQM_FLAT || h->param.i_cqm_preset > X264_CQM_CUSTOM )
        h->param.i_cqm_preset = X264_CQM_FLAT;

    if( h->param.analyse.i_me_method < X264_ME_DIA ||
        h->param.analyse.i_me_method > X264_ME_TESA )
        h->param.analyse.i_me_method = X264_ME_HEX;
    h->param.analyse.i_me_range = x264_clip3( h->param.analyse.i_me_range, 4, 1024 );
    if( h->param.analyse.i_me_range > 16 && h->param.analyse.i_me_method <= X264_ME_HEX )
        h->param.analyse.i_me_range = 16;
    if( h->param.analyse.i_me_method == X264_ME_TESA &&
        (h->mb.b_lossless || h->param.analyse.i_subpel_refine <= 1) )
        h->param.analyse.i_me_method = X264_ME_ESA;
    h->param.analyse.b_mixed_references = h->param.analyse.b_mixed_references && h->param.i_frame_reference > 1;
    h->param.analyse.inter &= X264_ANALYSE_PSUB16x16|X264_ANALYSE_PSUB8x8|X264_ANALYSE_BSUB16x16|
                              X264_ANALYSE_I4x4|X264_ANALYSE_I8x8;
    h->param.analyse.intra &= X264_ANALYSE_I4x4|X264_ANALYSE_I8x8;
    if( !(h->param.analyse.inter & X264_ANALYSE_PSUB16x16) )
        h->param.analyse.inter &= ~X264_ANALYSE_PSUB8x8;
    if( !h->param.analyse.b_transform_8x8 )
    {
        h->param.analyse.inter &= ~X264_ANALYSE_I8x8;
        h->param.analyse.intra &= ~X264_ANALYSE_I8x8;
    }
    h->param.analyse.i_trellis = x264_clip3( h->param.analyse.i_trellis, 0, 2 );
    h->param.rc.i_aq_mode = x264_clip3( h->param.rc.i_aq_mode, 0, 3 );
    h->param.rc.f_aq_strength = x264_clip3f( h->param.rc.f_aq_strength, 0, 3 );
    if( h->param.rc.f_aq_strength == 0 )
        h->param.rc.i_aq_mode = 0;

    if( h->param.i_log_level < X264_LOG_INFO )
    {
        h->param.analyse.b_psnr = 0;
        h->param.analyse.b_ssim = 0;
    }
    /* Warn users trying to measure PSNR/SSIM with psy opts on. */
    if( b_open && (h->param.analyse.b_psnr || h->param.analyse.b_ssim) )
    {
        char *s = NULL;

        if( h->param.analyse.b_psy )
        {
            s = h->param.analyse.b_psnr ? "psnr" : "ssim";
            x264_log( h, X264_LOG_WARNING, "--%s used with psy on: results will be invalid!\n", s );
        }
        else if( !h->param.rc.i_aq_mode && h->param.analyse.b_ssim )
        {
            x264_log( h, X264_LOG_WARNING, "--ssim used with AQ off: results will be invalid!\n" );
            s = "ssim";
        }
        else if(  h->param.rc.i_aq_mode && h->param.analyse.b_psnr )
        {
            x264_log( h, X264_LOG_WARNING, "--psnr used with AQ on: results will be invalid!\n" );
            s = "psnr";
        }
        if( s )
            x264_log( h, X264_LOG_WARNING, "--tune %s should be used if attempting to benchmark %s!\n", s, s );
    }

    if( !h->param.analyse.b_psy )
    {
        h->param.analyse.f_psy_rd = 0;
        h->param.analyse.f_psy_trellis = 0;
    }
    h->param.analyse.f_psy_rd = x264_clip3f( h->param.analyse.f_psy_rd, 0, 10 );
    h->param.analyse.f_psy_trellis = x264_clip3f( h->param.analyse.f_psy_trellis, 0, 10 );
    h->mb.i_psy_rd = h->param.analyse.i_subpel_refine >= 6 ? FIX8( h->param.analyse.f_psy_rd ) : 0;
    h->mb.i_psy_trellis = h->param.analyse.i_trellis ? FIX8( h->param.analyse.f_psy_trellis / 4 ) : 0;
    h->param.analyse.i_chroma_qp_offset = x264_clip3(h->param.analyse.i_chroma_qp_offset, -32, 32);
    /* In 4:4:4 mode, chroma gets twice as much resolution, so we can halve its quality. */
    if( b_open && i_csp >= X264_CSP_I444 && i_csp < X264_CSP_BGR && h->param.analyse.b_psy )
        h->param.analyse.i_chroma_qp_offset += 6;
    /* Psy RDO increases overall quantizers to improve the quality of luma--this indirectly hurts chroma quality */
    /* so we lower the chroma QP offset to compensate */
    if( b_open && h->mb.i_psy_rd && !h->param.i_avcintra_class )
        h->param.analyse.i_chroma_qp_offset -= h->param.analyse.f_psy_rd < 0.25 ? 1 : 2;
    /* Psy trellis has a similar effect. */
    if( b_open && h->mb.i_psy_trellis && !h->param.i_avcintra_class )
        h->param.analyse.i_chroma_qp_offset -= h->param.analyse.f_psy_trellis < 0.25 ? 1 : 2;
    h->param.analyse.i_chroma_qp_offset = x264_clip3(h->param.analyse.i_chroma_qp_offset, -12, 12);
    /* MB-tree requires AQ to be on, even if the strength is zero. */
    if( !h->param.rc.i_aq_mode && h->param.rc.b_mb_tree )
    {
        h->param.rc.i_aq_mode = 1;
        h->param.rc.f_aq_strength = 0;
    }
    h->param.analyse.i_noise_reduction = x264_clip3( h->param.analyse.i_noise_reduction, 0, 1<<16 );
    if( h->param.analyse.i_subpel_refine >= 10 && (h->param.analyse.i_trellis != 2 || !h->param.rc.i_aq_mode) )
        h->param.analyse.i_subpel_refine = 9;

    if( b_open )
    {
        const x264_level_t *l = x264_levels;
        if( h->param.i_level_idc < 0 )
        {
            int maxrate_bak = h->param.rc.i_vbv_max_bitrate;
            if( h->param.rc.i_rc_method == X264_RC_ABR && h->param.rc.i_vbv_buffer_size <= 0 )
                h->param.rc.i_vbv_max_bitrate = h->param.rc.i_bitrate * 2;
            x264_sps_init( h->sps, h->param.i_sps_id, &h->param );
            do h->param.i_level_idc = l->level_idc;
                while( l[1].level_idc && x264_validate_levels( h, 0 ) && l++ );
            h->param.rc.i_vbv_max_bitrate = maxrate_bak;
        }
        else
        {
            while( l->level_idc && l->level_idc != h->param.i_level_idc )
                l++;
            if( l->level_idc == 0 )
            {
                x264_log( h, X264_LOG_ERROR, "invalid level_idc: %d\n", h->param.i_level_idc );
                return -1;
            }
        }
        if( h->param.analyse.i_mv_range <= 0 )
            h->param.analyse.i_mv_range = l->mv_range >> PARAM_INTERLACED;
        else
            h->param.analyse.i_mv_range = x264_clip3(h->param.analyse.i_mv_range, 32, 8192 >> PARAM_INTERLACED);
    }

    h->param.analyse.i_weighted_pred = x264_clip3( h->param.analyse.i_weighted_pred, X264_WEIGHTP_NONE, X264_WEIGHTP_SMART );

    if( h->param.i_lookahead_threads == X264_THREADS_AUTO )
    {
        if( h->param.b_sliced_threads )
            h->param.i_lookahead_threads = h->param.i_threads;
        else
        {
            /* If we're using much slower lookahead settings than encoding settings, it helps a lot to use
             * more lookahead threads.  This typically happens in the first pass of a two-pass encode, so
             * try to guess at this sort of case.
             *
             * Tuned by a little bit of real encoding with the various presets. */
            int badapt = h->param.i_bframe_adaptive == X264_B_ADAPT_TRELLIS;
            int subme = X264_MIN( h->param.analyse.i_subpel_refine / 3, 3 ) + (h->param.analyse.i_subpel_refine > 1);
            int bframes = X264_MIN( (h->param.i_bframe - 1) / 3, 3 );

            /* [b-adapt 0/1 vs 2][quantized subme][quantized bframes] */
            static const uint8_t lookahead_thread_div[2][5][4] =
            {{{6,6,6,6}, {3,3,3,3}, {4,4,4,4}, {6,6,6,6}, {12,12,12,12}},
             {{3,2,1,1}, {2,1,1,1}, {4,3,2,1}, {6,4,3,2}, {12, 9, 6, 4}}};

            h->param.i_lookahead_threads = h->param.i_threads / lookahead_thread_div[badapt][subme][bframes];
            /* Since too many lookahead threads significantly degrades lookahead accuracy, limit auto
             * lookahead threads to about 8 macroblock rows high each at worst.  This number is chosen
             * pretty much arbitrarily. */
            h->param.i_lookahead_threads = X264_MIN( h->param.i_lookahead_threads, h->param.i_height / 128 );
        }
    }
    h->param.i_lookahead_threads = x264_clip3( h->param.i_lookahead_threads, 1, X264_MIN( max_sliced_threads, X264_LOOKAHEAD_THREAD_MAX ) );

    if( PARAM_INTERLACED )
    {
        if( h->param.analyse.i_me_method >= X264_ME_ESA )
        {
            x264_log( h, X264_LOG_WARNING, "interlace + me=esa is not implemented\n" );
            h->param.analyse.i_me_method = X264_ME_UMH;
        }
        if( h->param.analyse.i_weighted_pred > 0 )
        {
            x264_log( h, X264_LOG_WARNING, "interlace + weightp is not implemented\n" );
            h->param.analyse.i_weighted_pred = X264_WEIGHTP_NONE;
        }
    }

    if( !h->param.analyse.i_weighted_pred && h->param.rc.b_mb_tree && h->param.analyse.b_psy )
        h->param.analyse.i_weighted_pred = X264_WEIGHTP_FAKE;

    if( h->i_thread_frames > 1 )
    {
        int r = h->param.analyse.i_mv_range_thread;
        int r2;
        if( r <= 0 )
        {
            // half of the available space is reserved and divided evenly among the threads,
            // the rest is allocated to whichever thread is far enough ahead to use it.
            // reserving more space increases quality for some videos, but costs more time
            // in thread synchronization.
            int max_range = (h->param.i_height + X264_THREAD_HEIGHT) / h->i_thread_frames - X264_THREAD_HEIGHT;
            r = max_range / 2;
        }
        r = X264_MAX( r, h->param.analyse.i_me_range );
        r = X264_MIN( r, h->param.analyse.i_mv_range );
        // round up to use the whole mb row
        r2 = (r & ~15) + ((-X264_THREAD_HEIGHT) & 15);
        if( r2 < r )
            r2 += 16;
        x264_log( h, X264_LOG_DEBUG, "using mv_range_thread = %d\n", r2 );
        h->param.analyse.i_mv_range_thread = r2;
    }

    if( h->param.rc.f_rate_tolerance < 0 )
        h->param.rc.f_rate_tolerance = 0;
    if( h->param.rc.f_qblur < 0 )
        h->param.rc.f_qblur = 0;
    if( h->param.rc.f_complexity_blur < 0 )
        h->param.rc.f_complexity_blur = 0;

    h->param.i_sps_id &= 31;

    h->param.i_nal_hrd = x264_clip3( h->param.i_nal_hrd, X264_NAL_HRD_NONE, X264_NAL_HRD_CBR );

    if( h->param.i_nal_hrd && !h->param.rc.i_vbv_buffer_size )
    {
        x264_log( h, X264_LOG_WARNING, "NAL HRD parameters require VBV parameters\n" );
        h->param.i_nal_hrd = X264_NAL_HRD_NONE;
    }

    if( h->param.i_nal_hrd == X264_NAL_HRD_CBR &&
       (h->param.rc.i_bitrate != h->param.rc.i_vbv_max_bitrate || !h->param.rc.i_vbv_max_bitrate) )
    {
        x264_log( h, X264_LOG_WARNING, "CBR HRD requires constant bitrate\n" );
        h->param.i_nal_hrd = X264_NAL_HRD_VBR;
    }

    if( h->param.i_nal_hrd == X264_NAL_HRD_CBR )
        h->param.rc.b_filler = 1;

    /* ensure the booleans are 0 or 1 so they can be used in math */
#define BOOLIFY(x) h->param.x = !!h->param.x
    BOOLIFY( b_cabac );
    BOOLIFY( b_constrained_intra );
    BOOLIFY( b_deblocking_filter );
    BOOLIFY( b_deterministic );
    BOOLIFY( b_sliced_threads );
    BOOLIFY( b_interlaced );
    BOOLIFY( b_intra_refresh );
    BOOLIFY( b_aud );
    BOOLIFY( b_repeat_headers );
    BOOLIFY( b_annexb );
    BOOLIFY( b_vfr_input );
    BOOLIFY( b_pulldown );
    BOOLIFY( b_tff );
    BOOLIFY( b_pic_struct );
    BOOLIFY( b_fake_interlaced );
    BOOLIFY( b_open_gop );
    BOOLIFY( b_bluray_compat );
    BOOLIFY( b_stitchable );
    BOOLIFY( b_full_recon );
    BOOLIFY( b_opencl );
    BOOLIFY( analyse.b_transform_8x8 );
    BOOLIFY( analyse.b_weighted_bipred );
    BOOLIFY( analyse.b_chroma_me );
    BOOLIFY( analyse.b_mixed_references );
    BOOLIFY( analyse.b_fast_pskip );
    BOOLIFY( analyse.b_dct_decimate );
    BOOLIFY( analyse.b_psy );
    BOOLIFY( analyse.b_psnr );
    BOOLIFY( analyse.b_ssim );
    BOOLIFY( rc.b_stat_write );
    BOOLIFY( rc.b_stat_read );
    BOOLIFY( rc.b_mb_tree );
    BOOLIFY( rc.b_filler );
#undef BOOLIFY

    return 0;
}

static void mbcmp_init( x264_t *h )
{
    int satd = !h->mb.b_lossless && h->param.analyse.i_subpel_refine > 1;
    memcpy( h->pixf.mbcmp, satd ? h->pixf.satd : h->pixf.sad_aligned, sizeof(h->pixf.mbcmp) );
    memcpy( h->pixf.mbcmp_unaligned, satd ? h->pixf.satd : h->pixf.sad, sizeof(h->pixf.mbcmp_unaligned) );
    h->pixf.intra_mbcmp_x3_16x16 = satd ? h->pixf.intra_satd_x3_16x16 : h->pixf.intra_sad_x3_16x16;
    h->pixf.intra_mbcmp_x3_8x16c = satd ? h->pixf.intra_satd_x3_8x16c : h->pixf.intra_sad_x3_8x16c;
    h->pixf.intra_mbcmp_x3_8x8c  = satd ? h->pixf.intra_satd_x3_8x8c  : h->pixf.intra_sad_x3_8x8c;
    h->pixf.intra_mbcmp_x3_8x8 = satd ? h->pixf.intra_sa8d_x3_8x8 : h->pixf.intra_sad_x3_8x8;
    h->pixf.intra_mbcmp_x3_4x4 = satd ? h->pixf.intra_satd_x3_4x4 : h->pixf.intra_sad_x3_4x4;
    h->pixf.intra_mbcmp_x9_4x4 = h->param.b_cpu_independent || h->mb.b_lossless ? NULL
                               : satd ? h->pixf.intra_satd_x9_4x4 : h->pixf.intra_sad_x9_4x4;
    h->pixf.intra_mbcmp_x9_8x8 = h->param.b_cpu_independent || h->mb.b_lossless ? NULL
                               : satd ? h->pixf.intra_sa8d_x9_8x8 : h->pixf.intra_sad_x9_8x8;
    satd &= h->param.analyse.i_me_method == X264_ME_TESA;
    memcpy( h->pixf.fpelcmp, satd ? h->pixf.satd : h->pixf.sad, sizeof(h->pixf.fpelcmp) );
    memcpy( h->pixf.fpelcmp_x3, satd ? h->pixf.satd_x3 : h->pixf.sad_x3, sizeof(h->pixf.fpelcmp_x3) );
    memcpy( h->pixf.fpelcmp_x4, satd ? h->pixf.satd_x4 : h->pixf.sad_x4, sizeof(h->pixf.fpelcmp_x4) );
}

static void chroma_dsp_init( x264_t *h )
{
    memcpy( h->luma2chroma_pixel, x264_luma2chroma_pixel[CHROMA_FORMAT], sizeof(h->luma2chroma_pixel) );

    switch( CHROMA_FORMAT )
    {
        case CHROMA_400:
            h->mc.prefetch_fenc = h->mc.prefetch_fenc_400;
            break;
        case CHROMA_420:
            memcpy( h->predict_chroma, h->predict_8x8c, sizeof(h->predict_chroma) );
            h->mc.prefetch_fenc = h->mc.prefetch_fenc_420;
            h->loopf.deblock_chroma[0] = h->loopf.deblock_h_chroma_420;
            h->loopf.deblock_chroma_intra[0] = h->loopf.deblock_h_chroma_420_intra;
            h->loopf.deblock_chroma_mbaff = h->loopf.deblock_chroma_420_mbaff;
            h->loopf.deblock_chroma_intra_mbaff = h->loopf.deblock_chroma_420_intra_mbaff;
            h->pixf.intra_mbcmp_x3_chroma = h->pixf.intra_mbcmp_x3_8x8c;
            h->quantf.coeff_last[DCT_CHROMA_DC] = h->quantf.coeff_last4;
            h->quantf.coeff_level_run[DCT_CHROMA_DC] = h->quantf.coeff_level_run4;
            break;
        case CHROMA_422:
            memcpy( h->predict_chroma, h->predict_8x16c, sizeof(h->predict_chroma) );
            h->mc.prefetch_fenc = h->mc.prefetch_fenc_422;
            h->loopf.deblock_chroma[0] = h->loopf.deblock_h_chroma_422;
            h->loopf.deblock_chroma_intra[0] = h->loopf.deblock_h_chroma_422_intra;
            h->loopf.deblock_chroma_mbaff = h->loopf.deblock_chroma_422_mbaff;
            h->loopf.deblock_chroma_intra_mbaff = h->loopf.deblock_chroma_422_intra_mbaff;
            h->pixf.intra_mbcmp_x3_chroma = h->pixf.intra_mbcmp_x3_8x16c;
            h->quantf.coeff_last[DCT_CHROMA_DC] = h->quantf.coeff_last8;
            h->quantf.coeff_level_run[DCT_CHROMA_DC] = h->quantf.coeff_level_run8;
            break;
        case CHROMA_444:
            h->mc.prefetch_fenc = h->mc.prefetch_fenc_422; /* FIXME: doesn't cover V plane */
            h->loopf.deblock_chroma_mbaff = h->loopf.deblock_luma_mbaff;
            h->loopf.deblock_chroma_intra_mbaff = h->loopf.deblock_luma_intra_mbaff;
            break;
    }
}

static void set_aspect_ratio( x264_t *h, x264_param_t *param, int initial )
{
    /* VUI */
    if( param->vui.i_sar_width > 0 && param->vui.i_sar_height > 0 )
    {
        uint32_t i_w = param->vui.i_sar_width;
        uint32_t i_h = param->vui.i_sar_height;
        uint32_t old_w = h->param.vui.i_sar_width;
        uint32_t old_h = h->param.vui.i_sar_height;

        x264_reduce_fraction( &i_w, &i_h );

        while( i_w > 65535 || i_h > 65535 )
        {
            i_w /= 2;
            i_h /= 2;
        }

        x264_reduce_fraction( &i_w, &i_h );

        if( i_w != old_w || i_h != old_h || initial )
        {
            h->param.vui.i_sar_width = 0;
            h->param.vui.i_sar_height = 0;
            if( i_w == 0 || i_h == 0 )
                x264_log( h, X264_LOG_WARNING, "cannot create valid sample aspect ratio\n" );
            else
            {
                x264_log( h, initial?X264_LOG_INFO:X264_LOG_DEBUG, "using SAR=%d/%d\n", i_w, i_h );
                h->param.vui.i_sar_width = i_w;
                h->param.vui.i_sar_height = i_h;
            }
        }
    }
}

/****************************************************************************
 * x264_encoder_open:
 ****************************************************************************/
x264_t *x264_encoder_open( x264_param_t *param, void *api )
{
    x264_t *h;
    char buf[1000], *p;
    int i_slicetype_length;

    CHECKED_MALLOCZERO( h, sizeof(x264_t) );

    /* Create a copy of param */
    memcpy( &h->param, param, sizeof(x264_param_t) );
    h->param.opaque = NULL;
    h->param.param_free = NULL;

    if( h->param.psz_cqm_file )
        CHECKED_PARAM_STRDUP( h->param.psz_cqm_file, &h->param, h->param.psz_cqm_file );
    if( h->param.psz_dump_yuv )
        CHECKED_PARAM_STRDUP( h->param.psz_dump_yuv, &h->param, h->param.psz_dump_yuv );
    if( h->param.rc.psz_stat_out )
        CHECKED_PARAM_STRDUP( h->param.rc.psz_stat_out, &h->param, h->param.rc.psz_stat_out );
    if( h->param.rc.psz_stat_in )
        CHECKED_PARAM_STRDUP( h->param.rc.psz_stat_in, &h->param, h->param.rc.psz_stat_in );
    if( h->param.rc.psz_zones )
        CHECKED_PARAM_STRDUP( h->param.rc.psz_zones, &h->param, h->param.rc.psz_zones );
    if( h->param.psz_clbin_file )
        CHECKED_PARAM_STRDUP( h->param.psz_clbin_file, &h->param, h->param.psz_clbin_file );

    if( param->param_free )
    {
        x264_param_cleanup( param );
        param->param_free( param );
    }

    /* Save pointer to bit depth independent interface */
    h->api = api;

#if HAVE_INTEL_DISPATCHER
    x264_intel_dispatcher_override();
#endif

    if( x264_threading_init() )
    {
        x264_log( h, X264_LOG_ERROR, "unable to initialize threading\n" );
        goto fail;
    }

    if( validate_parameters( h, 1 ) < 0 )
        goto fail;

    if( h->param.psz_cqm_file )
        if( x264_cqm_parse_file( h, h->param.psz_cqm_file ) < 0 )
            goto fail;

    x264_reduce_fraction( &h->param.i_fps_num, &h->param.i_fps_den );
    x264_reduce_fraction( &h->param.i_timebase_num, &h->param.i_timebase_den );

    /* Init x264_t */
    h->i_frame = -1;
    h->i_frame_num = 0;

    if( h->param.i_avcintra_class )
        h->i_idr_pic_id = h->param.i_avcintra_class > 200 ? 4 : 5;
    else
        h->i_idr_pic_id = 0;

    if( (uint64_t)h->param.i_timebase_den * 2 > UINT32_MAX )
    {
        x264_log( h, X264_LOG_ERROR, "Effective timebase denominator %u exceeds H.264 maximum\n", h->param.i_timebase_den );
        goto fail;
    }

    set_aspect_ratio( h, &h->param, 1 );

    x264_sps_init( h->sps, h->param.i_sps_id, &h->param );
    x264_sps_init_scaling_list( h->sps, &h->param );
    x264_pps_init( h->pps, h->param.i_sps_id, &h->param, h->sps );

    x264_validate_levels( h, 1 );

    h->chroma_qp_table = i_chroma_qp_table + 12 + h->pps->i_chroma_qp_index_offset;

    if( x264_cqm_init( h ) < 0 )
        goto fail;

    h->mb.i_mb_width = h->sps->i_mb_width;
    h->mb.i_mb_height = h->sps->i_mb_height;
    h->mb.i_mb_count = h->mb.i_mb_width * h->mb.i_mb_height;

    h->mb.chroma_h_shift = CHROMA_FORMAT == CHROMA_420 || CHROMA_FORMAT == CHROMA_422;
    h->mb.chroma_v_shift = CHROMA_FORMAT == CHROMA_420;

    /* Adaptive MBAFF and subme 0 are not supported as we require halving motion
     * vectors during prediction, resulting in hpel mvs.
     * The chosen solution is to make MBAFF non-adaptive in this case. */
    h->mb.b_adaptive_mbaff = PARAM_INTERLACED && h->param.analyse.i_subpel_refine;

    /* Init frames. */
    if( h->param.i_bframe_adaptive == X264_B_ADAPT_TRELLIS && !h->param.rc.b_stat_read )
        h->frames.i_delay = X264_MAX(h->param.i_bframe,3)*4;
    else
        h->frames.i_delay = h->param.i_bframe;
    if( h->param.rc.b_mb_tree || h->param.rc.i_vbv_buffer_size )
        h->frames.i_delay = X264_MAX( h->frames.i_delay, h->param.rc.i_lookahead );
    i_slicetype_length = h->frames.i_delay;
    h->frames.i_delay += h->i_thread_frames - 1;
    h->frames.i_delay += h->param.i_sync_lookahead;
    h->frames.i_delay += h->param.b_vfr_input;
    h->frames.i_bframe_delay = h->param.i_bframe ? (h->param.i_bframe_pyramid ? 2 : 1) : 0;

    h->frames.i_max_ref0 = h->param.i_frame_reference;
    h->frames.i_max_ref1 = X264_MIN( h->sps->vui.i_num_reorder_frames, h->param.i_frame_reference );
    h->frames.i_max_dpb  = h->sps->vui.i_max_dec_frame_buffering;
    h->frames.b_have_lowres = !h->param.rc.b_stat_read
        && ( h->param.rc.i_rc_method == X264_RC_ABR
          || h->param.rc.i_rc_method == X264_RC_CRF
          || h->param.i_bframe_adaptive
          || h->param.i_scenecut_threshold
          || h->param.rc.b_mb_tree
          || h->param.analyse.i_weighted_pred );
    h->frames.b_have_lowres |= h->param.rc.b_stat_read && h->param.rc.i_vbv_buffer_size > 0;
    h->frames.b_have_sub8x8_esa = !!(h->param.analyse.inter & X264_ANALYSE_PSUB8x8);

    h->frames.i_last_idr =
    h->frames.i_last_keyframe = - h->param.i_keyint_max;
    h->frames.i_input    = 0;
    h->frames.i_largest_pts = h->frames.i_second_largest_pts = -1;
    h->frames.i_poc_last_open_gop = -1;

    CHECKED_MALLOCZERO( h->cost_table, sizeof(*h->cost_table) );
    CHECKED_MALLOCZERO( h->frames.unused[0], (h->frames.i_delay + 3) * sizeof(x264_frame_t *) );
    /* Allocate room for max refs plus a few extra just in case. */
    CHECKED_MALLOCZERO( h->frames.unused[1], (h->i_thread_frames + X264_REF_MAX + 4) * sizeof(x264_frame_t *) );
    CHECKED_MALLOCZERO( h->frames.current, (h->param.i_sync_lookahead + h->param.i_bframe
                        + h->i_thread_frames + 3) * sizeof(x264_frame_t *) );
    if( h->param.analyse.i_weighted_pred > 0 )
        CHECKED_MALLOCZERO( h->frames.blank_unused, h->i_thread_frames * 4 * sizeof(x264_frame_t *) );
    h->i_ref[0] = h->i_ref[1] = 0;
    h->i_cpb_delay = h->i_coded_fields = h->i_disp_fields = 0;
    h->i_prev_duration = ((uint64_t)h->param.i_fps_den * h->sps->vui.i_time_scale) / ((uint64_t)h->param.i_fps_num * h->sps->vui.i_num_units_in_tick);
    h->i_disp_fields_last_frame = -1;
    x264_rdo_init();

    /* init CPU functions */
#if (ARCH_X86 || ARCH_X86_64) && HIGH_BIT_DEPTH
    /* FIXME: Only 8-bit has been optimized for AVX-512 so far. The few AVX-512 functions
     * enabled in high bit-depth are insignificant and just causes potential issues with
     * unnecessary thermal throttling and whatnot, so keep it disabled for now. */
    h->param.cpu &= ~X264_CPU_AVX512;
#endif
    x264_predict_16x16_init( h->param.cpu, h->predict_16x16 );
    x264_predict_8x8c_init( h->param.cpu, h->predict_8x8c );
    x264_predict_8x16c_init( h->param.cpu, h->predict_8x16c );
    x264_predict_8x8_init( h->param.cpu, h->predict_8x8, &h->predict_8x8_filter );
    x264_predict_4x4_init( h->param.cpu, h->predict_4x4 );
    x264_pixel_init( h->param.cpu, &h->pixf );
    x264_dct_init( h->param.cpu, &h->dctf );
    x264_zigzag_init( h->param.cpu, &h->zigzagf_progressive, &h->zigzagf_interlaced );
    memcpy( &h->zigzagf, PARAM_INTERLACED ? &h->zigzagf_interlaced : &h->zigzagf_progressive, sizeof(h->zigzagf) );
    x264_mc_init( h->param.cpu, &h->mc, h->param.b_cpu_independent );
    x264_quant_init( h, h->param.cpu, &h->quantf );
    x264_deblock_init( h->param.cpu, &h->loopf, PARAM_INTERLACED );
    x264_bitstream_init( h->param.cpu, &h->bsf );
    if( h->param.b_cabac )
        x264_cabac_init( h );
    else
        x264_cavlc_init( h );

    mbcmp_init( h );
    chroma_dsp_init( h );

    p = buf + sprintf( buf, "using cpu capabilities:" );
    for( int i = 0; x264_cpu_names[i].flags; i++ )
    {
        if( !strcmp(x264_cpu_names[i].name, "SSE")
            && h->param.cpu & (X264_CPU_SSE2) )
            continue;
        if( !strcmp(x264_cpu_names[i].name, "SSE2")
            && h->param.cpu & (X264_CPU_SSE2_IS_FAST|X264_CPU_SSE2_IS_SLOW) )
            continue;
        if( !strcmp(x264_cpu_names[i].name, "SSE3")
            && (h->param.cpu & X264_CPU_SSSE3 || !(h->param.cpu & X264_CPU_CACHELINE_64)) )
            continue;
        if( !strcmp(x264_cpu_names[i].name, "SSE4.1")
            && (h->param.cpu & X264_CPU_SSE42) )
            continue;
        if( !strcmp(x264_cpu_names[i].name, "LZCNT")
            && (h->param.cpu & X264_CPU_BMI1) )
            continue;
        if( !strcmp(x264_cpu_names[i].name, "BMI1")
            && (h->param.cpu & X264_CPU_BMI2) )
            continue;
        if( !strcmp(x264_cpu_names[i].name, "FMA4")
            && (h->param.cpu & X264_CPU_FMA3) )
            continue;
        if( (h->param.cpu & x264_cpu_names[i].flags) == x264_cpu_names[i].flags
            && (!i || x264_cpu_names[i].flags != x264_cpu_names[i-1].flags) )
            p += sprintf( p, " %s", x264_cpu_names[i].name );
    }
    if( !h->param.cpu )
        p += sprintf( p, " none!" );
    x264_log( h, X264_LOG_INFO, "%s\n", buf );

    if( x264_analyse_init_costs( h ) )
        goto fail;

    /* Must be volatile or else GCC will optimize it out. */
    volatile int temp = 392;
    if( x264_clz( temp ) != 23 )
    {
        x264_log( h, X264_LOG_ERROR, "CLZ test failed: x264 has been miscompiled!\n" );
#if ARCH_X86 || ARCH_X86_64
        x264_log( h, X264_LOG_ERROR, "Are you attempting to run an SSE4a/LZCNT-targeted build on a CPU that\n" );
        x264_log( h, X264_LOG_ERROR, "doesn't support it?\n" );
#endif
        goto fail;
    }

    h->out.i_nal = 0;
    h->out.i_bitstream = x264_clip3f(
        h->param.i_width * h->param.i_height * 4
        * ( h->param.rc.i_rc_method == X264_RC_ABR
            ? pow( 0.95, h->param.rc.i_qp_min )
            : pow( 0.95, h->param.rc.i_qp_constant ) * X264_MAX( 1, h->param.rc.f_ip_factor ) ),
        1000000, INT_MAX/3
    );

    h->nal_buffer_size = h->out.i_bitstream * 3/2 + 4 + 64; /* +4 for startcode, +64 for nal_escape assembly padding */
    CHECKED_MALLOC( h->nal_buffer, h->nal_buffer_size );

    CHECKED_MALLOC( h->reconfig_h, sizeof(x264_t) );

    if( h->param.i_threads > 1 &&
        x264_threadpool_init( &h->threadpool, h->param.i_threads ) )
        goto fail;
    if( h->param.i_lookahead_threads > 1 &&
        x264_threadpool_init( &h->lookaheadpool, h->param.i_lookahead_threads ) )
        goto fail;

#if HAVE_OPENCL
    if( h->param.b_opencl )
    {
        h->opencl.ocl = x264_opencl_load_library();
        if( !h->opencl.ocl )
        {
            x264_log( h, X264_LOG_WARNING, "failed to load OpenCL\n" );
            h->param.b_opencl = 0;
        }
    }
#endif

    h->thread[0] = h;
    for( int i = 1; i < h->param.i_threads + !!h->param.i_sync_lookahead; i++ )
        CHECKED_MALLOC( h->thread[i], sizeof(x264_t) );
    if( h->param.i_lookahead_threads > 1 )
        for( int i = 0; i < h->param.i_lookahead_threads; i++ )
        {
            CHECKED_MALLOC( h->lookahead_thread[i], sizeof(x264_t) );
            *h->lookahead_thread[i] = *h;
        }
    *h->reconfig_h = *h;

    for( int i = 0; i < h->param.i_threads; i++ )
    {
        int init_nal_count = h->param.i_slice_count + 3;
        int allocate_threadlocal_data = !h->param.b_sliced_threads || !i;
        if( i > 0 )
            *h->thread[i] = *h;

        if( x264_pthread_mutex_init( &h->thread[i]->mutex, NULL ) )
            goto fail;
        if( x264_pthread_cond_init( &h->thread[i]->cv, NULL ) )
            goto fail;

        if( allocate_threadlocal_data )
        {
            h->thread[i]->fdec = x264_frame_pop_unused( h, 1 );
            if( !h->thread[i]->fdec )
                goto fail;
        }
        else
            h->thread[i]->fdec = h->thread[0]->fdec;

        CHECKED_MALLOC( h->thread[i]->out.p_bitstream, h->out.i_bitstream );
        /* Start each thread with room for init_nal_count NAL units; it'll realloc later if needed. */
        CHECKED_MALLOC( h->thread[i]->out.nal, init_nal_count*sizeof(x264_nal_t) );
        h->thread[i]->out.i_nals_allocated = init_nal_count;

        if( allocate_threadlocal_data && x264_macroblock_cache_allocate( h->thread[i] ) < 0 )
            goto fail;
    }

#if HAVE_OPENCL
    if( h->param.b_opencl && x264_opencl_lookahead_init( h ) < 0 )
        h->param.b_opencl = 0;
#endif

    if( x264_lookahead_init( h, i_slicetype_length ) )
        goto fail;

    for( int i = 0; i < h->param.i_threads; i++ )
        if( x264_macroblock_thread_allocate( h->thread[i], 0 ) < 0 )
            goto fail;

    if( x264_ratecontrol_new( h ) < 0 )
        goto fail;

    if( h->param.i_nal_hrd )
    {
        x264_log( h, X264_LOG_DEBUG, "HRD bitrate: %i bits/sec\n", h->sps->vui.hrd.i_bit_rate_unscaled );
        x264_log( h, X264_LOG_DEBUG, "CPB size: %i bits\n", h->sps->vui.hrd.i_cpb_size_unscaled );
    }

    if( h->param.psz_dump_yuv )
    {
        /* create or truncate the reconstructed video file */
        FILE *f = x264_fopen( h->param.psz_dump_yuv, "w" );
        if( !f )
        {
            x264_log( h, X264_LOG_ERROR, "dump_yuv: can't write to %s\n", h->param.psz_dump_yuv );
            goto fail;
        }
        else if( !x264_is_regular_file( f ) )
        {
            x264_log( h, X264_LOG_ERROR, "dump_yuv: incompatible with non-regular file %s\n", h->param.psz_dump_yuv );
            fclose( f );
            goto fail;
        }
        fclose( f );
    }

    const char *profile = h->sps->i_profile_idc == PROFILE_BASELINE ? "Constrained Baseline" :
                          h->sps->i_profile_idc == PROFILE_MAIN ? "Main" :
                          h->sps->i_profile_idc == PROFILE_HIGH ? "High" :
                          h->sps->i_profile_idc == PROFILE_HIGH10 ?
                              (h->sps->b_constraint_set3 ? "High 10 Intra" : "High 10") :
                          h->sps->i_profile_idc == PROFILE_HIGH422 ?
                              (h->sps->b_constraint_set3 ? "High 4:2:2 Intra" : "High 4:2:2") :
                          h->sps->b_constraint_set3 ? "High 4:4:4 Intra" : "High 4:4:4 Predictive";
    char level[16];
    if( h->sps->i_level_idc == 9 || ( h->sps->i_level_idc == 11 && h->sps->b_constraint_set3 &&
        (h->sps->i_profile_idc == PROFILE_BASELINE || h->sps->i_profile_idc == PROFILE_MAIN) ) )
        strcpy( level, "1b" );
    else
        snprintf( level, sizeof(level), "%d.%d", h->sps->i_level_idc / 10, h->sps->i_level_idc % 10 );

    static const char * const subsampling[4] = { "4:0:0", "4:2:0", "4:2:2", "4:4:4" };
    x264_log( h, X264_LOG_INFO, "profile %s, level %s, %s, %d-bit\n",
              profile, level, subsampling[CHROMA_FORMAT], BIT_DEPTH );

    return h;
fail:
    x264_free( h );
    return NULL;
}

/****************************************************************************/
static int encoder_try_reconfig( x264_t *h, x264_param_t *param, int *rc_reconfig )
{
    *rc_reconfig = 0;
    set_aspect_ratio( h, param, 0 );
#define COPY(var) h->param.var = param->var
    COPY( i_frame_reference ); // but never uses more refs than initially specified
    COPY( i_bframe_bias );
    if( h->param.i_scenecut_threshold )
        COPY( i_scenecut_threshold ); // can't turn it on or off, only vary the threshold
    COPY( b_deblocking_filter );
    COPY( i_deblocking_filter_alphac0 );
    COPY( i_deblocking_filter_beta );
    COPY( i_frame_packing );
    COPY( mastering_display );
    COPY( content_light_level );
    COPY( i_alternative_transfer );
    COPY( analyse.inter );
    COPY( analyse.intra );
    COPY( analyse.i_direct_mv_pred );
    /* Scratch buffer prevents me_range from being increased for esa/tesa */
    if( h->param.analyse.i_me_method < X264_ME_ESA || param->analyse.i_me_range < h->param.analyse.i_me_range )
        COPY( analyse.i_me_range );
    COPY( analyse.i_noise_reduction );
    /* We can't switch out of subme=0 during encoding. */
    if( h->param.analyse.i_subpel_refine )
        COPY( analyse.i_subpel_refine );
    COPY( analyse.i_trellis );
    COPY( analyse.b_chroma_me );
    COPY( analyse.b_dct_decimate );
    COPY( analyse.b_fast_pskip );
    COPY( analyse.b_mixed_references );
    COPY( analyse.f_psy_rd );
    COPY( analyse.f_psy_trellis );
    COPY( crop_rect );
    // can only twiddle these if they were enabled to begin with:
    if( h->param.analyse.i_me_method >= X264_ME_ESA || param->analyse.i_me_method < X264_ME_ESA )
        COPY( analyse.i_me_method );
    if( h->param.analyse.i_me_method >= X264_ME_ESA && !h->frames.b_have_sub8x8_esa )
        h->param.analyse.inter &= ~X264_ANALYSE_PSUB8x8;
    if( h->pps->b_transform_8x8_mode )
        COPY( analyse.b_transform_8x8 );
    if( h->frames.i_max_ref1 > 1 )
        COPY( i_bframe_pyramid );
    COPY( i_slice_max_size );
    COPY( i_slice_max_mbs );
    COPY( i_slice_min_mbs );
    COPY( i_slice_count );
    COPY( i_slice_count_max );
    COPY( b_tff );

    /* VBV can't be turned on if it wasn't on to begin with */
    if( h->param.rc.i_vbv_max_bitrate > 0 && h->param.rc.i_vbv_buffer_size > 0 &&
          param->rc.i_vbv_max_bitrate > 0 &&   param->rc.i_vbv_buffer_size > 0 )
    {
        *rc_reconfig |= h->param.rc.i_vbv_max_bitrate != param->rc.i_vbv_max_bitrate;
        *rc_reconfig |= h->param.rc.i_vbv_buffer_size != param->rc.i_vbv_buffer_size;
        *rc_reconfig |= h->param.rc.i_bitrate != param->rc.i_bitrate;
        COPY( rc.i_vbv_max_bitrate );
        COPY( rc.i_vbv_buffer_size );
        COPY( rc.i_bitrate );
    }
    *rc_reconfig |= h->param.rc.f_rf_constant != param->rc.f_rf_constant;
    *rc_reconfig |= h->param.rc.f_rf_constant_max != param->rc.f_rf_constant_max;
    COPY( rc.f_rf_constant );
    COPY( rc.f_rf_constant_max );
#undef COPY

    return validate_parameters( h, 0 );
}

int x264_encoder_reconfig_apply( x264_t *h, x264_param_t *param )
{
    int rc_reconfig;
    int ret = encoder_try_reconfig( h, param, &rc_reconfig );

    mbcmp_init( h );
    if( !ret )
        x264_sps_init_reconfigurable( h->sps, &h->param );

    /* Supported reconfiguration options (1-pass only):
     * vbv-maxrate
     * vbv-bufsize
     * crf
     * bitrate (CBR only) */
    if( !ret && rc_reconfig )
        x264_ratecontrol_init_reconfigurable( h, 0 );

    return ret;
}

/****************************************************************************
 * x264_encoder_reconfig:
 ****************************************************************************/
int x264_encoder_reconfig( x264_t *h, x264_param_t *param )
{
    h = h->thread[h->thread[0]->i_thread_phase];
    x264_param_t param_save = h->reconfig_h->param;
    h->reconfig_h->param = h->param;

    int rc_reconfig;
    int ret = encoder_try_reconfig( h->reconfig_h, param, &rc_reconfig );
    if( !ret )
        h->reconfig = 1;
    else
        h->reconfig_h->param = param_save;

    return ret;
}

/****************************************************************************
 * x264_encoder_parameters:
 ****************************************************************************/
void x264_encoder_parameters( x264_t *h, x264_param_t *param )
{
    memcpy( param, &h->thread[h->i_thread_phase]->param, sizeof(x264_param_t) );
    param->opaque = NULL;
}

/* internal usage */
static void nal_start( x264_t *h, int i_type, int i_ref_idc )
{
    x264_nal_t *nal = &h->out.nal[h->out.i_nal];

    nal->i_ref_idc        = i_ref_idc;
    nal->i_type           = i_type;
    nal->b_long_startcode = 1;

    nal->i_payload= 0;
    nal->p_payload= &h->out.p_bitstream[bs_pos( &h->out.bs ) / 8];
    nal->i_padding= 0;
}

/* if number of allocated nals is not enough, re-allocate a larger one. */
static int nal_check_buffer( x264_t *h )
{
    if( h->out.i_nal >= h->out.i_nals_allocated )
    {
        x264_nal_t *new_out = x264_malloc( sizeof(x264_nal_t) * (h->out.i_nals_allocated*2) );
        if( !new_out )
            return -1;
        memcpy( new_out, h->out.nal, sizeof(x264_nal_t) * (h->out.i_nals_allocated) );
        x264_free( h->out.nal );
        h->out.nal = new_out;
        h->out.i_nals_allocated *= 2;
    }
    return 0;
}

static int nal_end( x264_t *h )
{
    x264_nal_t *nal = &h->out.nal[h->out.i_nal];
    uint8_t *end = &h->out.p_bitstream[bs_pos( &h->out.bs ) / 8];
    nal->i_payload = end - nal->p_payload;
    /* Assembly implementation of nal_escape reads past the end of the input.
     * While undefined padding wouldn't actually affect the output, it makes valgrind unhappy. */
    memset( end, 0xff, 64 );
    if( h->param.nalu_process )
        h->param.nalu_process( (x264_t *)h->api, nal, h->fenc->opaque );
    h->out.i_nal++;

    return nal_check_buffer( h );
}

static int check_encapsulated_buffer( x264_t *h, x264_t *h0, int start,
                                      int64_t previous_nal_size, int64_t necessary_size )
{
    if( h0->nal_buffer_size < necessary_size )
    {
        necessary_size *= 2;
        if( necessary_size > INT_MAX )
            return -1;
        uint8_t *buf = x264_malloc( necessary_size );
        if( !buf )
            return -1;
        if( previous_nal_size )
            memcpy( buf, h0->nal_buffer, previous_nal_size );

        intptr_t delta = buf - h0->nal_buffer;
        for( int i = 0; i < start; i++ )
            h->out.nal[i].p_payload += delta;

        x264_free( h0->nal_buffer );
        h0->nal_buffer = buf;
        h0->nal_buffer_size = necessary_size;
    }

    return 0;
}

static int encoder_encapsulate_nals( x264_t *h, int start )
{
    x264_t *h0 = h->thread[0];
    int64_t nal_size = 0, previous_nal_size = 0;

    if( h->param.nalu_process )
    {
        for( int i = start; i < h->out.i_nal; i++ )
            nal_size += h->out.nal[i].i_payload;
        if( nal_size > INT_MAX )
            return -1;
        return nal_size;
    }

    for( int i = 0; i < start; i++ )
        previous_nal_size += h->out.nal[i].i_payload;

    for( int i = start; i < h->out.i_nal; i++ )
        nal_size += h->out.nal[i].i_payload;

    /* Worst-case NAL unit escaping: reallocate the buffer if it's too small. */
    int64_t necessary_size = previous_nal_size + nal_size * 3/2 + h->out.i_nal * 4 + 4 + 64;
    for( int i = start; i < h->out.i_nal; i++ )
        necessary_size += h->out.nal[i].i_padding;
    if( check_encapsulated_buffer( h, h0, start, previous_nal_size, necessary_size ) )
        return -1;

    uint8_t *nal_buffer = h0->nal_buffer + previous_nal_size;

    for( int i = start; i < h->out.i_nal; i++ )
    {
        h->out.nal[i].b_long_startcode = !i || h->out.nal[i].i_type == NAL_SPS || h->out.nal[i].i_type == NAL_PPS ||
                                         h->param.i_avcintra_class;
        x264_nal_encode( h, nal_buffer, &h->out.nal[i] );
        nal_buffer += h->out.nal[i].i_payload;
    }

    x264_emms();

    return nal_buffer - (h0->nal_buffer + previous_nal_size);
}

/****************************************************************************
 * x264_encoder_headers:
 ****************************************************************************/
int x264_encoder_headers( x264_t *h, x264_nal_t **pp_nal, int *pi_nal )
{
    int frame_size = 0;
    /* init bitstream context */
    h->out.i_nal = 0;
    bs_init( &h->out.bs, h->out.p_bitstream, h->out.i_bitstream );

    /* Write SEI, SPS and PPS. */

    /* generate sequence parameters */
    nal_start( h, NAL_SPS, NAL_PRIORITY_HIGHEST );
    x264_sps_write( &h->out.bs, h->sps );
    if( nal_end( h ) )
        return -1;

    /* generate picture parameters */
    nal_start( h, NAL_PPS, NAL_PRIORITY_HIGHEST );
    x264_pps_write( &h->out.bs, h->sps, h->pps );
    if( nal_end( h ) )
        return -1;

    /* identify ourselves */
    nal_start( h, NAL_SEI, NAL_PRIORITY_DISPOSABLE );
    if( x264_sei_version_write( h, &h->out.bs ) )
        return -1;
    if( nal_end( h ) )
        return -1;

    frame_size = encoder_encapsulate_nals( h, 0 );
    if( frame_size < 0 )
        return -1;

    /* now set output*/
    *pi_nal = h->out.i_nal;
    *pp_nal = &h->out.nal[0];
    h->out.i_nal = 0;

    return frame_size;
}

/* Check to see whether we have chosen a reference list ordering different
 * from the standard's default. */
static inline void reference_check_reorder( x264_t *h )
{
    /* The reorder check doesn't check for missing frames, so just
     * force a reorder if one of the reference list is corrupt. */
    for( int i = 0; h->frames.reference[i]; i++ )
        if( h->frames.reference[i]->b_corrupt )
        {
            h->b_ref_reorder[0] = 1;
            return;
        }
    for( int list = 0; list <= (h->sh.i_type == SLICE_TYPE_B); list++ )
        for( int i = 0; i < h->i_ref[list] - 1; i++ )
        {
            int framenum_diff = h->fref[list][i+1]->i_frame_num - h->fref[list][i]->i_frame_num;
            int poc_diff = h->fref[list][i+1]->i_poc - h->fref[list][i]->i_poc;
            /* P and B-frames use different default orders. */
            if( h->sh.i_type == SLICE_TYPE_P ? framenum_diff > 0 : list == 1 ? poc_diff < 0 : poc_diff > 0 )
            {
                h->b_ref_reorder[list] = 1;
                return;
            }
        }
}

/* return -1 on failure, else return the index of the new reference frame */
static int weighted_reference_duplicate( x264_t *h, int i_ref, const x264_weight_t *w )
{
    int i = h->i_ref[0];
    int j = 1;
    x264_frame_t *newframe;
    if( i <= 1 ) /* empty list, definitely can't duplicate frame */
        return -1;

    //Duplication is only used in X264_WEIGHTP_SMART
    if( h->param.analyse.i_weighted_pred != X264_WEIGHTP_SMART )
        return -1;

    /* Duplication is a hack to compensate for crappy rounding in motion compensation.
     * With high bit depth, it's not worth doing, so turn it off except in the case of
     * unweighted dupes. */
    if( BIT_DEPTH > 8 && w != x264_weight_none )
        return -1;

    newframe = x264_frame_pop_blank_unused( h );
    if( !newframe )
        return -1;

    //FIXME: probably don't need to copy everything
    *newframe = *h->fref[0][i_ref];
    newframe->i_reference_count = 1;
    newframe->orig = h->fref[0][i_ref];
    newframe->b_duplicate = 1;
    memcpy( h->fenc->weight[j], w, sizeof(h->fenc->weight[i]) );

    /* shift the frames to make space for the dupe. */
    h->b_ref_reorder[0] = 1;
    if( h->i_ref[0] < X264_REF_MAX )
        ++h->i_ref[0];
    h->fref[0][X264_REF_MAX-1] = NULL;
    x264_frame_unshift( &h->fref[0][j], newframe );

    return j;
}

static void weighted_pred_init( x264_t *h )
{
    /* for now no analysis and set all weights to nothing */
    for( int i_ref = 0; i_ref < h->i_ref[0]; i_ref++ )
        h->fenc->weighted[i_ref] = h->fref[0][i_ref]->filtered[0][0];

    // FIXME: This only supports weighting of one reference frame
    // and duplicates of that frame.
    h->fenc->i_lines_weighted = 0;

    for( int i_ref = 0; i_ref < (h->i_ref[0] << SLICE_MBAFF); i_ref++ )
        for( int i = 0; i < 3; i++ )
            h->sh.weight[i_ref][i].weightfn = NULL;


    if( h->sh.i_type != SLICE_TYPE_P || h->param.analyse.i_weighted_pred <= 0 )
        return;

    int i_padv = PADV << PARAM_INTERLACED;
    int denom = -1;
    int weightplane[2] = { 0, 0 };
    int buffer_next = 0;
    for( int i = 0; i < 3; i++ )
    {
        for( int j = 0; j < h->i_ref[0]; j++ )
        {
            if( h->fenc->weight[j][i].weightfn )
            {
                h->sh.weight[j][i] = h->fenc->weight[j][i];
                // if weight is useless, don't write it to stream
                if( h->sh.weight[j][i].i_scale == 1<<h->sh.weight[j][i].i_denom && h->sh.weight[j][i].i_offset == 0 )
                    h->sh.weight[j][i].weightfn = NULL;
                else
                {
                    if( !weightplane[!!i] )
                    {
                        weightplane[!!i] = 1;
                        h->sh.weight[0][!!i].i_denom = denom = h->sh.weight[j][i].i_denom;
                        assert( x264_clip3( denom, 0, 7 ) == denom );
                    }

                    assert( h->sh.weight[j][i].i_denom == denom );
                    if( !i )
                    {
                        h->fenc->weighted[j] = h->mb.p_weight_buf[buffer_next++] + h->fenc->i_stride[0] * i_padv + PADH_ALIGN;
                        //scale full resolution frame
                        if( h->param.i_threads == 1 )
                        {
                            pixel *src = h->fref[0][j]->filtered[0][0] - h->fref[0][j]->i_stride[0]*i_padv - PADH_ALIGN;
                            pixel *dst = h->fenc->weighted[j] - h->fenc->i_stride[0]*i_padv - PADH_ALIGN;
                            int stride = h->fenc->i_stride[0];
                            int width = h->fenc->i_width[0] + PADH2;
                            int height = h->fenc->i_lines[0] + i_padv*2;
                            x264_weight_scale_plane( h, dst, stride, src, stride, width, height, &h->sh.weight[j][0] );
                            h->fenc->i_lines_weighted = height;
                        }
                    }
                }
            }
        }
    }

    if( weightplane[1] )
        for( int i = 0; i < h->i_ref[0]; i++ )
        {
            if( h->sh.weight[i][1].weightfn && !h->sh.weight[i][2].weightfn )
            {
                h->sh.weight[i][2].i_scale = 1 << h->sh.weight[0][1].i_denom;
                h->sh.weight[i][2].i_offset = 0;
            }
            else if( h->sh.weight[i][2].weightfn && !h->sh.weight[i][1].weightfn )
            {
                h->sh.weight[i][1].i_scale = 1 << h->sh.weight[0][1].i_denom;
                h->sh.weight[i][1].i_offset = 0;
            }
        }

    if( !weightplane[0] )
        h->sh.weight[0][0].i_denom = 0;
    if( !weightplane[1] )
        h->sh.weight[0][1].i_denom = 0;
    h->sh.weight[0][2].i_denom = h->sh.weight[0][1].i_denom;
}

static inline int reference_distance( x264_t *h, x264_frame_t *frame )
{
    if( h->param.i_frame_packing == 5 )
        return abs((h->fenc->i_frame&~1) - (frame->i_frame&~1)) +
                  ((h->fenc->i_frame&1) != (frame->i_frame&1));
    else
        return abs(h->fenc->i_frame - frame->i_frame);
}

static inline void reference_build_list( x264_t *h, int i_poc )
{
    int b_ok;

    /* build ref list 0/1 */
    h->mb.pic.i_fref[0] = h->i_ref[0] = 0;
    h->mb.pic.i_fref[1] = h->i_ref[1] = 0;
    if( h->sh.i_type == SLICE_TYPE_I )
        return;

    for( int i = 0; h->frames.reference[i]; i++ )
    {
        if( h->frames.reference[i]->b_corrupt )
            continue;
        if( h->frames.reference[i]->i_poc < i_poc )
            h->fref[0][h->i_ref[0]++] = h->frames.reference[i];
        else if( h->frames.reference[i]->i_poc > i_poc )
            h->fref[1][h->i_ref[1]++] = h->frames.reference[i];
    }

    if( h->sh.i_mmco_remove_from_end )
    {
        /* Order ref0 for MMCO remove */
        do
        {
            b_ok = 1;
            for( int i = 0; i < h->i_ref[0] - 1; i++ )
            {
                if( h->fref[0][i]->i_frame < h->fref[0][i+1]->i_frame )
                {
                    XCHG( x264_frame_t*, h->fref[0][i], h->fref[0][i+1] );
                    b_ok = 0;
                    break;
                }
            }
        } while( !b_ok );

        for( int i = h->i_ref[0]-1; i >= h->i_ref[0] - h->sh.i_mmco_remove_from_end; i-- )
        {
            int diff = h->i_frame_num - h->fref[0][i]->i_frame_num;
            h->sh.mmco[h->sh.i_mmco_command_count].i_poc = h->fref[0][i]->i_poc;
            h->sh.mmco[h->sh.i_mmco_command_count++].i_difference_of_pic_nums = diff;
        }
    }

    /* Order reference lists by distance from the current frame. */
    for( int list = 0; list < 2; list++ )
    {
        h->fref_nearest[list] = h->fref[list][0];
        do
        {
            b_ok = 1;
            for( int i = 0; i < h->i_ref[list] - 1; i++ )
            {
                if( list ? h->fref[list][i+1]->i_poc < h->fref_nearest[list]->i_poc
                         : h->fref[list][i+1]->i_poc > h->fref_nearest[list]->i_poc )
                    h->fref_nearest[list] = h->fref[list][i+1];
                if( reference_distance( h, h->fref[list][i] ) > reference_distance( h, h->fref[list][i+1] ) )
                {
                    XCHG( x264_frame_t*, h->fref[list][i], h->fref[list][i+1] );
                    b_ok = 0;
                    break;
                }
            }
        } while( !b_ok );
    }

    reference_check_reorder( h );

    h->i_ref[1] = X264_MIN( h->i_ref[1], h->frames.i_max_ref1 );
    h->i_ref[0] = X264_MIN( h->i_ref[0], h->frames.i_max_ref0 );
    h->i_ref[0] = X264_MIN( h->i_ref[0], h->param.i_frame_reference ); // if reconfig() has lowered the limit

    /* For Blu-ray compliance, don't reference frames outside of the minigop. */
    if( IS_X264_TYPE_B( h->fenc->i_type ) && h->param.b_bluray_compat )
        h->i_ref[0] = X264_MIN( h->i_ref[0], IS_X264_TYPE_B( h->fref[0][0]->i_type ) + 1 );

    /* add duplicates */
    if( h->fenc->i_type == X264_TYPE_P )
    {
        int idx = -1;
        if( h->param.analyse.i_weighted_pred >= X264_WEIGHTP_SIMPLE )
        {
            x264_weight_t w[3];
            w[1].weightfn = w[2].weightfn = NULL;
            if( h->param.rc.b_stat_read )
                x264_ratecontrol_set_weights( h, h->fenc );

            if( !h->fenc->weight[0][0].weightfn )
            {
                h->fenc->weight[0][0].i_denom = 0;
                SET_WEIGHT( w[0], 1, 1, 0, -1 );
                idx = weighted_reference_duplicate( h, 0, w );
            }
            else
            {
                if( h->fenc->weight[0][0].i_scale == 1<<h->fenc->weight[0][0].i_denom )
                {
                    SET_WEIGHT( h->fenc->weight[0][0], 1, 1, 0, h->fenc->weight[0][0].i_offset );
                }
                weighted_reference_duplicate( h, 0, x264_weight_none );
                if( h->fenc->weight[0][0].i_offset > -128 )
                {
                    w[0] = h->fenc->weight[0][0];
                    w[0].i_offset--;
                    h->mc.weight_cache( h, &w[0] );
                    idx = weighted_reference_duplicate( h, 0, w );
                }
            }
        }
        h->mb.ref_blind_dupe = idx;
    }

    assert( h->i_ref[0] + h->i_ref[1] <= X264_REF_MAX );
    h->mb.pic.i_fref[0] = h->i_ref[0];
    h->mb.pic.i_fref[1] = h->i_ref[1];
}

static void fdec_filter_row( x264_t *h, int mb_y, int pass )
{
    /* mb_y is the mb to be encoded next, not the mb to be filtered here */
    int b_hpel = h->fdec->b_kept_as_ref;
    int b_deblock = h->sh.i_disable_deblocking_filter_idc != 1;
    int b_end = mb_y == h->i_threadslice_end;
    int b_measure_quality = 1;
    int min_y = mb_y - (1 << SLICE_MBAFF);
    int b_start = min_y == h->i_threadslice_start;
    /* Even in interlaced mode, deblocking never modifies more than 4 pixels
     * above each MB, as bS=4 doesn't happen for the top of interlaced mbpairs. */
    int minpix_y = min_y*16 - 4 * !b_start;
    int maxpix_y = mb_y*16 - 4 * !b_end;
    b_deblock &= b_hpel || h->param.b_full_recon || h->param.psz_dump_yuv;
    if( h->param.b_sliced_threads )
    {
        switch( pass )
        {
            /* During encode: only do deblock if asked for */
            default:
            case 0:
                b_deblock &= h->param.b_full_recon;
                b_hpel = 0;
                break;
            /* During post-encode pass: do deblock if not done yet, do hpel for all
             * rows except those between slices. */
            case 1:
                b_deblock &= !h->param.b_full_recon;
                b_hpel &= !(b_start && min_y > 0);
                b_measure_quality = 0;
                break;
            /* Final pass: do the rows between slices in sequence. */
            case 2:
                b_deblock = 0;
                b_measure_quality = 0;
                break;
        }
    }
    if( mb_y & SLICE_MBAFF )
        return;
    if( min_y < h->i_threadslice_start )
        return;

    if( b_deblock )
        for( int y = min_y; y < mb_y; y += (1 << SLICE_MBAFF) )
            x264_frame_deblock_row( h, y );

    /* FIXME: Prediction requires different borders for interlaced/progressive mc,
     * but the actual image data is equivalent. For now, maintain this
     * consistency by copying deblocked pixels between planes. */
    if( PARAM_INTERLACED && (!h->param.b_sliced_threads || pass == 1) )
        for( int p = 0; p < h->fdec->i_plane; p++ )
            for( int i = minpix_y>>(CHROMA_V_SHIFT && p); i < maxpix_y>>(CHROMA_V_SHIFT && p); i++ )
                memcpy( h->fdec->plane_fld[p] + i*h->fdec->i_stride[p],
                        h->fdec->plane[p]     + i*h->fdec->i_stride[p],
                        h->mb.i_mb_width*16*SIZEOF_PIXEL );

    if( h->fdec->b_kept_as_ref && (!h->param.b_sliced_threads || pass == 1) )
        x264_frame_expand_border( h, h->fdec, min_y );
    if( b_hpel )
    {
        int end = mb_y == h->mb.i_mb_height;
        /* Can't do hpel until the previous slice is done encoding. */
        if( h->param.analyse.i_subpel_refine )
        {
            x264_frame_filter( h, h->fdec, min_y, end );
            x264_frame_expand_border_filtered( h, h->fdec, min_y, end );
        }
    }

    if( SLICE_MBAFF && pass == 0 )
        for( int i = 0; i < 3; i++ )
        {
            XCHG( pixel *, h->intra_border_backup[0][i], h->intra_border_backup[3][i] );
            XCHG( pixel *, h->intra_border_backup[1][i], h->intra_border_backup[4][i] );
        }

    if( h->i_thread_frames > 1 && h->fdec->b_kept_as_ref )
        x264_frame_cond_broadcast( h->fdec, mb_y*16 + (b_end ? 10000 : -(X264_THREAD_HEIGHT << SLICE_MBAFF)) );

    if( b_measure_quality )
    {
        maxpix_y = X264_MIN( maxpix_y, h->param.i_height );
        if( h->param.analyse.b_psnr )
        {
            for( int p = 0; p < (CHROMA444 ? 3 : 1); p++ )
                h->stat.frame.i_ssd[p] += x264_pixel_ssd_wxh( &h->pixf,
                    h->fdec->plane[p] + minpix_y * h->fdec->i_stride[p], h->fdec->i_stride[p],
                    h->fenc->plane[p] + minpix_y * h->fenc->i_stride[p], h->fenc->i_stride[p],
                    h->param.i_width, maxpix_y-minpix_y );
            if( !CHROMA444 )
            {
                uint64_t ssd_u, ssd_v;
                int v_shift = CHROMA_V_SHIFT;
                x264_pixel_ssd_nv12( &h->pixf,
                    h->fdec->plane[1] + (minpix_y>>v_shift) * h->fdec->i_stride[1], h->fdec->i_stride[1],
                    h->fenc->plane[1] + (minpix_y>>v_shift) * h->fenc->i_stride[1], h->fenc->i_stride[1],
                    h->param.i_width>>1, (maxpix_y-minpix_y)>>v_shift, &ssd_u, &ssd_v );
                h->stat.frame.i_ssd[1] += ssd_u;
                h->stat.frame.i_ssd[2] += ssd_v;
            }
        }

        if( h->param.analyse.b_ssim )
        {
            int ssim_cnt;
            x264_emms();
            /* offset by 2 pixels to avoid alignment of ssim blocks with dct blocks,
             * and overlap by 4 */
            minpix_y += b_start ? 2 : -6;
            h->stat.frame.f_ssim +=
                x264_pixel_ssim_wxh( &h->pixf,
                    h->fdec->plane[0] + 2+minpix_y*h->fdec->i_stride[0], h->fdec->i_stride[0],
                    h->fenc->plane[0] + 2+minpix_y*h->fenc->i_stride[0], h->fenc->i_stride[0],
                    h->param.i_width-2, maxpix_y-minpix_y, h->scratch_buffer, &ssim_cnt );
            h->stat.frame.i_ssim_cnt += ssim_cnt;
        }
    }
}

static inline int reference_update( x264_t *h )
{
    if( !h->fdec->b_kept_as_ref )
    {
        if( h->i_thread_frames > 1 )
        {
            x264_frame_push_unused( h, h->fdec );
            h->fdec = x264_frame_pop_unused( h, 1 );
            if( !h->fdec )
                return -1;
        }
        return 0;
    }

    /* apply mmco from previous frame. */
    for( int i = 0; i < h->sh.i_mmco_command_count; i++ )
        for( int j = 0; h->frames.reference[j]; j++ )
            if( h->frames.reference[j]->i_poc == h->sh.mmco[i].i_poc )
                x264_frame_push_unused( h, x264_frame_shift( &h->frames.reference[j] ) );

    /* move frame in the buffer */
    x264_frame_push( h->frames.reference, h->fdec );
    if( h->frames.reference[h->sps->i_num_ref_frames] )
        x264_frame_push_unused( h, x264_frame_shift( h->frames.reference ) );
    h->fdec = x264_frame_pop_unused( h, 1 );
    if( !h->fdec )
        return -1;
    return 0;
}

static inline void reference_reset( x264_t *h )
{
    while( h->frames.reference[0] )
        x264_frame_push_unused( h, x264_frame_pop( h->frames.reference ) );
    h->fdec->i_poc =
    h->fenc->i_poc = 0;
}

static inline void reference_hierarchy_reset( x264_t *h )
{
    int ref;
    int b_hasdelayframe = 0;

    /* look for delay frames -- chain must only contain frames that are disposable */
    for( int i = 0; h->frames.current[i] && IS_DISPOSABLE( h->frames.current[i]->i_type ); i++ )
        b_hasdelayframe |= h->frames.current[i]->i_coded
                        != h->frames.current[i]->i_frame + h->sps->vui.i_num_reorder_frames;

    /* This function must handle b-pyramid and clear frames for open-gop */
    if( h->param.i_bframe_pyramid != X264_B_PYRAMID_STRICT && !b_hasdelayframe && h->frames.i_poc_last_open_gop == -1 )
        return;

    /* Remove last BREF. There will never be old BREFs in the
     * dpb during a BREF decode when pyramid == STRICT */
    for( ref = 0; h->frames.reference[ref]; ref++ )
    {
        if( ( h->param.i_bframe_pyramid == X264_B_PYRAMID_STRICT
            && h->frames.reference[ref]->i_type == X264_TYPE_BREF )
            || ( h->frames.reference[ref]->i_poc < h->frames.i_poc_last_open_gop
            && h->sh.i_type != SLICE_TYPE_B ) )
        {
            int diff = h->i_frame_num - h->frames.reference[ref]->i_frame_num;
            h->sh.mmco[h->sh.i_mmco_command_count].i_difference_of_pic_nums = diff;
            h->sh.mmco[h->sh.i_mmco_command_count++].i_poc = h->frames.reference[ref]->i_poc;
            x264_frame_push_unused( h, x264_frame_shift( &h->frames.reference[ref] ) );
            h->b_ref_reorder[0] = 1;
            ref--;
        }
    }

    /* Prepare room in the dpb for the delayed display time of the later b-frame's */
    if( h->param.i_bframe_pyramid )
        h->sh.i_mmco_remove_from_end = X264_MAX( ref + 2 - h->frames.i_max_dpb, 0 );
}

static inline void slice_init( x264_t *h, int i_nal_type, int i_global_qp )
{
    /* ------------------------ Create slice header  ----------------------- */
    if( i_nal_type == NAL_SLICE_IDR )
    {
        slice_header_init( h, &h->sh, h->sps, h->pps, h->i_idr_pic_id, h->i_frame_num, i_global_qp );

        /* alternate id */
        if( h->param.i_avcintra_class )
        {
            switch( h->i_idr_pic_id )
            {
                case 5:
                    h->i_idr_pic_id = 3;
                    break;
                case 3:
                    h->i_idr_pic_id = 4;
                    break;
                case 4:
                default:
                    h->i_idr_pic_id = 5;
                    break;
            }
        }
        else
            h->i_idr_pic_id ^= 1;
    }
    else
    {
        slice_header_init( h, &h->sh, h->sps, h->pps, -1, h->i_frame_num, i_global_qp );

        h->sh.i_num_ref_idx_l0_active = h->i_ref[0] <= 0 ? 1 : h->i_ref[0];
        h->sh.i_num_ref_idx_l1_active = h->i_ref[1] <= 0 ? 1 : h->i_ref[1];
        if( h->sh.i_num_ref_idx_l0_active != h->pps->i_num_ref_idx_l0_default_active ||
            (h->sh.i_type == SLICE_TYPE_B && h->sh.i_num_ref_idx_l1_active != h->pps->i_num_ref_idx_l1_default_active) )
        {
            h->sh.b_num_ref_idx_override = 1;
        }
    }

    if( h->fenc->i_type == X264_TYPE_BREF && h->param.b_bluray_compat && h->sh.i_mmco_command_count )
    {
        h->b_sh_backup = 1;
        h->sh_backup = h->sh;
    }

    h->fdec->i_frame_num = h->sh.i_frame_num;

    if( h->sps->i_poc_type == 0 )
    {
        h->sh.i_poc = h->fdec->i_poc;
        if( PARAM_INTERLACED )
        {
            h->sh.i_delta_poc_bottom = h->param.b_tff ? 1 : -1;
            h->sh.i_poc += h->sh.i_delta_poc_bottom == -1;
        }
        else
            h->sh.i_delta_poc_bottom = 0;
        h->fdec->i_delta_poc[0] = h->sh.i_delta_poc_bottom == -1;
        h->fdec->i_delta_poc[1] = h->sh.i_delta_poc_bottom ==  1;
    }
    else
    {
        /* Nothing to do ? */
    }

    x264_macroblock_slice_init( h );
}

typedef struct
{
    int skip;
    uint8_t cabac_prevbyte;
    bs_t bs;
    x264_cabac_t cabac;
    x264_frame_stat_t stat;
    int last_qp;
    int last_dqp;
    int field_decoding_flag;
} x264_bs_bak_t;

static ALWAYS_INLINE void bitstream_backup( x264_t *h, x264_bs_bak_t *bak, int i_skip, int full )
{
    if( full )
    {
        bak->stat = h->stat.frame;
        bak->last_qp = h->mb.i_last_qp;
        bak->last_dqp = h->mb.i_last_dqp;
        bak->field_decoding_flag = h->mb.field_decoding_flag;
    }
    else
    {
        bak->stat.i_mv_bits = h->stat.frame.i_mv_bits;
        bak->stat.i_tex_bits = h->stat.frame.i_tex_bits;
    }
    /* In the per-MB backup, we don't need the contexts because flushing the CABAC
     * encoder has no context dependency and in this case, a slice is ended (and
     * thus the content of all contexts are thrown away). */
    if( h->param.b_cabac )
    {
        if( full )
            memcpy( &bak->cabac, &h->cabac, sizeof(x264_cabac_t) );
        else
            memcpy( &bak->cabac, &h->cabac, offsetof(x264_cabac_t, f8_bits_encoded) );
        /* x264's CABAC writer modifies the previous byte during carry, so it has to be
         * backed up. */
        bak->cabac_prevbyte = h->cabac.p[-1];
    }
    else
    {
        bak->bs = h->out.bs;
        bak->skip = i_skip;
    }
}

static ALWAYS_INLINE void bitstream_restore( x264_t *h, x264_bs_bak_t *bak, int *skip, int full )
{
    if( full )
    {
        h->stat.frame = bak->stat;
        h->mb.i_last_qp = bak->last_qp;
        h->mb.i_last_dqp = bak->last_dqp;
        h->mb.field_decoding_flag = bak->field_decoding_flag;
    }
    else
    {
        h->stat.frame.i_mv_bits = bak->stat.i_mv_bits;
        h->stat.frame.i_tex_bits = bak->stat.i_tex_bits;
    }
    if( h->param.b_cabac )
    {
        if( full )
            memcpy( &h->cabac, &bak->cabac, sizeof(x264_cabac_t) );
        else
            memcpy( &h->cabac, &bak->cabac, offsetof(x264_cabac_t, f8_bits_encoded) );
        h->cabac.p[-1] = bak->cabac_prevbyte;
    }
    else
    {
        h->out.bs = bak->bs;
        *skip = bak->skip;
    }
}

static intptr_t slice_write( x264_t *h )
{
    int i_skip;
    int mb_xy, i_mb_x, i_mb_y;
    /* NALUs other than the first use a 3-byte startcode.
     * Add one extra byte for the rbsp, and one more for the final CABAC putbyte.
     * Then add an extra 5 bytes just in case, to account for random NAL escapes and
     * other inaccuracies. */
    int overhead_guess = (NALU_OVERHEAD - (h->param.b_annexb && h->out.i_nal)) + 1 + h->param.b_cabac + 5;
    int slice_max_size = h->param.i_slice_max_size > 0 ? (h->param.i_slice_max_size-overhead_guess)*8 : 0;
    int back_up_bitstream_cavlc = !h->param.b_cabac && h->sps->i_profile_idc < PROFILE_HIGH;
    int back_up_bitstream = slice_max_size || back_up_bitstream_cavlc;
    int starting_bits = bs_pos(&h->out.bs);
    int b_deblock = h->sh.i_disable_deblocking_filter_idc != 1;
    int b_hpel = h->fdec->b_kept_as_ref;
    int orig_last_mb = h->sh.i_last_mb;
    int thread_last_mb = h->i_threadslice_end * h->mb.i_mb_width - 1;
    uint8_t *last_emu_check;
#define BS_BAK_SLICE_MAX_SIZE 0
#define BS_BAK_CAVLC_OVERFLOW 1
#define BS_BAK_SLICE_MIN_MBS  2
#define BS_BAK_ROW_VBV        3
    x264_bs_bak_t bs_bak[4];
    b_deblock &= b_hpel || h->param.b_full_recon || h->param.psz_dump_yuv;
    bs_realign( &h->out.bs );

    /* Slice */
    nal_start( h, h->i_nal_type, h->i_nal_ref_idc );
    h->out.nal[h->out.i_nal].i_first_mb = h->sh.i_first_mb;

    /* Slice header */
    x264_macroblock_thread_init( h );

    /* Set the QP equal to the first QP in the slice for more accurate CABAC initialization. */
    h->mb.i_mb_xy = h->sh.i_first_mb;
    h->sh.i_qp = x264_ratecontrol_mb_qp( h );
    h->sh.i_qp = SPEC_QP( h->sh.i_qp );
    h->sh.i_qp_delta = h->sh.i_qp - h->pps->i_pic_init_qp;

    slice_header_write( &h->out.bs, &h->sh, h->i_nal_ref_idc );
    if( h->param.b_cabac )
    {
        /* alignment needed */
        bs_align_1( &h->out.bs );

        /* init cabac */
        x264_cabac_context_init( h, &h->cabac, h->sh.i_type, x264_clip3( h->sh.i_qp-QP_BD_OFFSET, 0, 51 ), h->sh.i_cabac_init_idc );
        x264_cabac_encode_init ( &h->cabac, h->out.bs.p, h->out.bs.p_end );
        last_emu_check = h->cabac.p;
    }
    else
        last_emu_check = h->out.bs.p;
    h->mb.i_last_qp = h->sh.i_qp;
    h->mb.i_last_dqp = 0;
    h->mb.field_decoding_flag = 0;

    i_mb_y = h->sh.i_first_mb / h->mb.i_mb_width;
    i_mb_x = h->sh.i_first_mb % h->mb.i_mb_width;
    i_skip = 0;

    while( 1 )
    {
        mb_xy = i_mb_x + i_mb_y * h->mb.i_mb_width;
        int mb_spos = bs_pos(&h->out.bs) + x264_cabac_pos(&h->cabac);

        if( i_mb_x == 0 )
        {
            if( bitstream_check_buffer( h ) )
                return -1;
            if( !(i_mb_y & SLICE_MBAFF) && h->param.rc.i_vbv_buffer_size )
                bitstream_backup( h, &bs_bak[BS_BAK_ROW_VBV], i_skip, 1 );
            if( !h->mb.b_reencode_mb )
                fdec_filter_row( h, i_mb_y, 0 );
        }

        if( back_up_bitstream )
        {
            if( back_up_bitstream_cavlc )
                bitstream_backup( h, &bs_bak[BS_BAK_CAVLC_OVERFLOW], i_skip, 0 );
            if( slice_max_size && !(i_mb_y & SLICE_MBAFF) )
            {
                bitstream_backup( h, &bs_bak[BS_BAK_SLICE_MAX_SIZE], i_skip, 0 );
                if( (thread_last_mb+1-mb_xy) == h->param.i_slice_min_mbs )
                    bitstream_backup( h, &bs_bak[BS_BAK_SLICE_MIN_MBS], i_skip, 0 );
            }
        }

        if( PARAM_INTERLACED )
        {
            if( h->mb.b_adaptive_mbaff )
            {
                if( !(i_mb_y&1) )
                {
                    /* FIXME: VSAD is fast but fairly poor at choosing the best interlace type. */
                    h->mb.b_interlaced = x264_field_vsad( h, i_mb_x, i_mb_y );
                    memcpy( &h->zigzagf, MB_INTERLACED ? &h->zigzagf_interlaced : &h->zigzagf_progressive, sizeof(h->zigzagf) );
                    if( !MB_INTERLACED && (i_mb_y+2) == h->mb.i_mb_height )
                        x264_expand_border_mbpair( h, i_mb_x, i_mb_y );
                }
            }
            h->mb.field[mb_xy] = MB_INTERLACED;
        }

        /* load cache */
        if( SLICE_MBAFF )
            x264_macroblock_cache_load_interlaced( h, i_mb_x, i_mb_y );
        else
            x264_macroblock_cache_load_progressive( h, i_mb_x, i_mb_y );

        x264_macroblock_analyse( h );

        /* encode this macroblock -> be careful it can change the mb type to P_SKIP if needed */
reencode:
        x264_macroblock_encode( h );

        if( h->param.b_cabac )
        {
            if( mb_xy > h->sh.i_first_mb && !(SLICE_MBAFF && (i_mb_y&1)) )
                x264_cabac_encode_terminal( &h->cabac );

            if( IS_SKIP( h->mb.i_type ) )
                x264_cabac_mb_skip( h, 1 );
            else
            {
                if( h->sh.i_type != SLICE_TYPE_I )
                    x264_cabac_mb_skip( h, 0 );
                x264_macroblock_write_cabac( h, &h->cabac );
            }
        }
        else
        {
            if( IS_SKIP( h->mb.i_type ) )
                i_skip++;
            else
            {
                if( h->sh.i_type != SLICE_TYPE_I )
                {
                    bs_write_ue( &h->out.bs, i_skip );  /* skip run */
                    i_skip = 0;
                }
                x264_macroblock_write_cavlc( h );
                /* If there was a CAVLC level code overflow, try again at a higher QP. */
                if( h->mb.b_overflow )
                {
                    h->mb.i_chroma_qp = h->chroma_qp_table[++h->mb.i_qp];
                    h->mb.i_skip_intra = 0;
                    h->mb.b_skip_mc = 0;
                    h->mb.b_overflow = 0;
                    bitstream_restore( h, &bs_bak[BS_BAK_CAVLC_OVERFLOW], &i_skip, 0 );
                    goto reencode;
                }
            }
        }

        int total_bits = bs_pos(&h->out.bs) + x264_cabac_pos(&h->cabac);
        int mb_size = total_bits - mb_spos;

        if( slice_max_size && (!SLICE_MBAFF || (i_mb_y&1)) )
        {
            /* Count the skip run, just in case. */
            if( !h->param.b_cabac )
                total_bits += bs_size_ue_big( i_skip );
            /* Check for escape bytes. */
            uint8_t *end = h->param.b_cabac ? h->cabac.p : h->out.bs.p;
            for( ; last_emu_check < end - 2; last_emu_check++ )
                if( last_emu_check[0] == 0 && last_emu_check[1] == 0 && last_emu_check[2] <= 3 )
                {
                    slice_max_size -= 8;
                    last_emu_check++;
                }
            /* We'll just re-encode this last macroblock if we go over the max slice size. */
            if( total_bits - starting_bits > slice_max_size && !h->mb.b_reencode_mb )
            {
                if( !x264_frame_new_slice( h, h->fdec ) )
                {
                    /* Handle the most obnoxious slice-min-mbs edge case: we need to end the slice
                     * because it's gone over the maximum size, but doing so would violate slice-min-mbs.
                     * If possible, roll back to the last checkpoint and try again.
                     * We could try raising QP, but that would break in the case where a slice spans multiple
                     * rows, which the re-encoding infrastructure can't currently handle. */
                    if( mb_xy <= thread_last_mb && (thread_last_mb+1-mb_xy) < h->param.i_slice_min_mbs )
                    {
                        if( thread_last_mb-h->param.i_slice_min_mbs < h->sh.i_first_mb+h->param.i_slice_min_mbs )
                        {
                            x264_log( h, X264_LOG_WARNING, "slice-max-size violated (frame %d, cause: slice-min-mbs)\n", h->i_frame );
                            slice_max_size = 0;
                            goto cont;
                        }
                        bitstream_restore( h, &bs_bak[BS_BAK_SLICE_MIN_MBS], &i_skip, 0 );
                        h->mb.b_reencode_mb = 1;
                        h->sh.i_last_mb = thread_last_mb-h->param.i_slice_min_mbs;
                        break;
                    }
                    if( mb_xy-SLICE_MBAFF*h->mb.i_mb_stride != h->sh.i_first_mb )
                    {
                        bitstream_restore( h, &bs_bak[BS_BAK_SLICE_MAX_SIZE], &i_skip, 0 );
                        h->mb.b_reencode_mb = 1;
                        if( SLICE_MBAFF )
                        {
                            // set to bottom of previous mbpair
                            if( i_mb_x )
                                h->sh.i_last_mb = mb_xy-1+h->mb.i_mb_stride*(!(i_mb_y&1));
                            else
                                h->sh.i_last_mb = (i_mb_y-2+!(i_mb_y&1))*h->mb.i_mb_stride + h->mb.i_mb_width - 1;
                        }
                        else
                            h->sh.i_last_mb = mb_xy-1;
                        break;
                    }
                    else
                        h->sh.i_last_mb = mb_xy;
                }
                else
                    slice_max_size = 0;
            }
        }
cont:
        h->mb.b_reencode_mb = 0;

        /* save cache */
        x264_macroblock_cache_save( h );

        if( x264_ratecontrol_mb( h, mb_size ) < 0 )
        {
            bitstream_restore( h, &bs_bak[BS_BAK_ROW_VBV], &i_skip, 1 );
            h->mb.b_reencode_mb = 1;
            i_mb_x = 0;
            i_mb_y = i_mb_y - SLICE_MBAFF;
            h->mb.i_mb_prev_xy = i_mb_y * h->mb.i_mb_stride - 1;
            h->sh.i_last_mb = orig_last_mb;
            continue;
        }

        /* accumulate mb stats */
        h->stat.frame.i_mb_count[h->mb.i_type]++;

        int b_intra = IS_INTRA( h->mb.i_type );
        int b_skip = IS_SKIP( h->mb.i_type );
        if( h->param.i_log_level >= X264_LOG_INFO || h->param.rc.b_stat_write )
        {
            if( !b_intra && !b_skip && !IS_DIRECT( h->mb.i_type ) )
            {
                if( h->mb.i_partition != D_8x8 )
                        h->stat.frame.i_mb_partition[h->mb.i_partition] += 4;
                    else
                        for( int i = 0; i < 4; i++ )
                            h->stat.frame.i_mb_partition[h->mb.i_sub_partition[i]] ++;
                if( h->param.i_frame_reference > 1 )
                    for( int i_list = 0; i_list <= (h->sh.i_type == SLICE_TYPE_B); i_list++ )
                        for( int i = 0; i < 4; i++ )
                        {
                            int i_ref = h->mb.cache.ref[i_list][ x264_scan8[4*i] ];
                            if( i_ref >= 0 )
                                h->stat.frame.i_mb_count_ref[i_list][i_ref] ++;
                        }
            }
        }

        if( h->param.i_log_level >= X264_LOG_INFO )
        {
            if( h->mb.i_cbp_luma | h->mb.i_cbp_chroma )
            {
                if( CHROMA444 )
                {
                    for( int i = 0; i < 4; i++ )
                        if( h->mb.i_cbp_luma & (1 << i) )
                            for( int p = 0; p < 3; p++ )
                            {
                                int s8 = i*4+p*16;
                                int nnz8x8 = M16( &h->mb.cache.non_zero_count[x264_scan8[s8]+0] )
                                           | M16( &h->mb.cache.non_zero_count[x264_scan8[s8]+8] );
                                h->stat.frame.i_mb_cbp[!b_intra + p*2] += !!nnz8x8;
                            }
                }
                else
                {
                    int cbpsum = (h->mb.i_cbp_luma&1) + ((h->mb.i_cbp_luma>>1)&1)
                               + ((h->mb.i_cbp_luma>>2)&1) + (h->mb.i_cbp_luma>>3);
                    h->stat.frame.i_mb_cbp[!b_intra + 0] += cbpsum;
                    h->stat.frame.i_mb_cbp[!b_intra + 2] += !!h->mb.i_cbp_chroma;
                    h->stat.frame.i_mb_cbp[!b_intra + 4] += h->mb.i_cbp_chroma >> 1;
                }
            }
            if( h->mb.i_cbp_luma && !b_intra )
            {
                h->stat.frame.i_mb_count_8x8dct[0] ++;
                h->stat.frame.i_mb_count_8x8dct[1] += h->mb.b_transform_8x8;
            }
            if( b_intra && h->mb.i_type != I_PCM )
            {
                if( h->mb.i_type == I_16x16 )
                    h->stat.frame.i_mb_pred_mode[0][h->mb.i_intra16x16_pred_mode]++;
                else if( h->mb.i_type == I_8x8 )
                    for( int i = 0; i < 16; i += 4 )
                        h->stat.frame.i_mb_pred_mode[1][h->mb.cache.intra4x4_pred_mode[x264_scan8[i]]]++;
                else //if( h->mb.i_type == I_4x4 )
                    for( int i = 0; i < 16; i++ )
                        h->stat.frame.i_mb_pred_mode[2][h->mb.cache.intra4x4_pred_mode[x264_scan8[i]]]++;
                h->stat.frame.i_mb_pred_mode[3][x264_mb_chroma_pred_mode_fix[h->mb.i_chroma_pred_mode]]++;
            }
            h->stat.frame.i_mb_field[b_intra?0:b_skip?2:1] += MB_INTERLACED;
        }

        /* calculate deblock strength values (actual deblocking is done per-row along with hpel) */
        if( b_deblock )
            x264_macroblock_deblock_strength( h );

        if( mb_xy == h->sh.i_last_mb )
            break;

        if( SLICE_MBAFF )
        {
            i_mb_x += i_mb_y & 1;
            i_mb_y ^= i_mb_x < h->mb.i_mb_width;
        }
        else
            i_mb_x++;
        if( i_mb_x == h->mb.i_mb_width )
        {
            i_mb_y++;
            i_mb_x = 0;
        }
    }
    if( h->sh.i_last_mb < h->sh.i_first_mb )
        return 0;

    h->out.nal[h->out.i_nal].i_last_mb = h->sh.i_last_mb;

    if( h->param.b_cabac )
    {
        x264_cabac_encode_flush( h, &h->cabac );
        h->out.bs.p = h->cabac.p;
    }
    else
    {
        if( i_skip > 0 )
            bs_write_ue( &h->out.bs, i_skip );  /* last skip run */
        /* rbsp_slice_trailing_bits */
        bs_rbsp_trailing( &h->out.bs );
        bs_flush( &h->out.bs );
    }
    if( nal_end( h ) )
        return -1;

    if( h->sh.i_last_mb == (h->i_threadslice_end * h->mb.i_mb_width - 1) )
    {
        h->stat.frame.i_misc_bits = bs_pos( &h->out.bs )
                                  + (h->out.i_nal*NALU_OVERHEAD * 8)
                                  - h->stat.frame.i_tex_bits
                                  - h->stat.frame.i_mv_bits;
        fdec_filter_row( h, h->i_threadslice_end, 0 );

        if( h->param.b_sliced_threads )
        {
            /* Tell the main thread we're done. */
            x264_threadslice_cond_broadcast( h, 1 );
            /* Do hpel now */
            for( int mb_y = h->i_threadslice_start; mb_y <= h->i_threadslice_end; mb_y++ )
                fdec_filter_row( h, mb_y, 1 );
            x264_threadslice_cond_broadcast( h, 2 );
            /* Do the first row of hpel, now that the previous slice is done */
            if( h->i_thread_idx > 0 )
            {
                x264_threadslice_cond_wait( h->thread[h->i_thread_idx-1], 2 );
                fdec_filter_row( h, h->i_threadslice_start + (1 << SLICE_MBAFF), 2 );
            }
        }

        /* Free mb info after the last thread's done using it */
        if( h->fdec->mb_info_free && (!h->param.b_sliced_threads || h->i_thread_idx == (h->param.i_threads-1)) )
        {
            h->fdec->mb_info_free( h->fdec->mb_info );
            h->fdec->mb_info = NULL;
            h->fdec->mb_info_free = NULL;
        }
    }

    return 0;
}

static void thread_sync_context( x264_t *dst, x264_t *src )
{
    if( dst == src )
        return;

    // reference counting
    for( x264_frame_t **f = src->frames.reference; *f; f++ )
        (*f)->i_reference_count++;
    for( x264_frame_t **f = dst->frames.reference; *f; f++ )
        x264_frame_push_unused( src, *f );
    src->fdec->i_reference_count++;
    x264_frame_push_unused( src, dst->fdec );

    // copy everything except the per-thread pointers and the constants.
    memcpy( &dst->i_frame, &src->i_frame, offsetof(x264_t, mb.base) - offsetof(x264_t, i_frame) );
    dst->param = src->param;
    dst->stat = src->stat;
    dst->pixf = src->pixf;
    dst->reconfig = src->reconfig;
}

static void thread_sync_stat( x264_t *dst, x264_t *src )
{
    if( dst != src )
        memcpy( &dst->stat, &src->stat, offsetof(x264_t, stat.frame) - offsetof(x264_t, stat) );
}

static void *slices_write( x264_t *h )
{
    int i_slice_num = 0;
    int last_thread_mb = h->sh.i_last_mb;
    int round_bias = h->param.i_avcintra_class ? 0 : h->param.i_slice_count/2;

    /* init stats */
    memset( &h->stat.frame, 0, sizeof(h->stat.frame) );
    h->mb.b_reencode_mb = 0;
    while( h->sh.i_first_mb + SLICE_MBAFF*h->mb.i_mb_stride <= last_thread_mb )
    {
        h->sh.i_last_mb = last_thread_mb;
        if( !i_slice_num || !x264_frame_new_slice( h, h->fdec ) )
        {
            if( h->param.i_slice_max_mbs )
            {
                if( SLICE_MBAFF )
                {
                    // convert first to mbaff form, add slice-max-mbs, then convert back to normal form
                    int last_mbaff = 2*(h->sh.i_first_mb % h->mb.i_mb_width)
                        + h->mb.i_mb_width*(h->sh.i_first_mb / h->mb.i_mb_width)
                        + h->param.i_slice_max_mbs - 1;
                    int last_x = (last_mbaff % (2*h->mb.i_mb_width))/2;
                    int last_y = (last_mbaff / (2*h->mb.i_mb_width))*2 + 1;
                    h->sh.i_last_mb = last_x + h->mb.i_mb_stride*last_y;
                }
                else
                {
                    h->sh.i_last_mb = h->sh.i_first_mb + h->param.i_slice_max_mbs - 1;
                    if( h->sh.i_last_mb < last_thread_mb && last_thread_mb - h->sh.i_last_mb < h->param.i_slice_min_mbs )
                        h->sh.i_last_mb = last_thread_mb - h->param.i_slice_min_mbs;
                }
                i_slice_num++;
            }
            else if( h->param.i_slice_count && !h->param.b_sliced_threads )
            {
                int height = h->mb.i_mb_height >> PARAM_INTERLACED;
                int width = h->mb.i_mb_width << PARAM_INTERLACED;
                i_slice_num++;
                h->sh.i_last_mb = (height * i_slice_num + round_bias) / h->param.i_slice_count * width - 1;
            }
        }
        h->sh.i_last_mb = X264_MIN( h->sh.i_last_mb, last_thread_mb );
        if( slice_write( h ) )
            goto fail;
        h->sh.i_first_mb = h->sh.i_last_mb + 1;
        // if i_first_mb is not the last mb in a row then go to the next mb in MBAFF order
        if( SLICE_MBAFF && h->sh.i_first_mb % h->mb.i_mb_width )
            h->sh.i_first_mb -= h->mb.i_mb_stride;
    }

    return (void *)0;

fail:
    /* Tell other threads we're done, so they wouldn't wait for it */
    if( h->param.b_sliced_threads )
        x264_threadslice_cond_broadcast( h, 2 );
    return (void *)-1;
}

static int threaded_slices_write( x264_t *h )
{
    int round_bias = h->param.i_avcintra_class ? 0 : h->param.i_slice_count/2;

    /* set first/last mb and sync contexts */
    for( int i = 0; i < h->param.i_threads; i++ )
    {
        x264_t *t = h->thread[i];
        if( i )
        {
            t->param = h->param;
            memcpy( &t->i_frame, &h->i_frame, offsetof(x264_t, rc) - offsetof(x264_t, i_frame) );
        }
        int height = h->mb.i_mb_height >> PARAM_INTERLACED;
        t->i_threadslice_start = ((height *  i    + round_bias) / h->param.i_threads) << PARAM_INTERLACED;
        t->i_threadslice_end   = ((height * (i+1) + round_bias) / h->param.i_threads) << PARAM_INTERLACED;
        t->sh.i_first_mb = t->i_threadslice_start * h->mb.i_mb_width;
        t->sh.i_last_mb  =   t->i_threadslice_end * h->mb.i_mb_width - 1;
    }

    x264_analyse_weight_frame( h, h->mb.i_mb_height*16 + 16 );

    x264_threads_distribute_ratecontrol( h );

    /* setup */
    for( int i = 0; i < h->param.i_threads; i++ )
    {
        h->thread[i]->i_thread_idx = i;
        h->thread[i]->b_thread_active = 1;
        x264_threadslice_cond_broadcast( h->thread[i], 0 );
    }
    /* dispatch */
    for( int i = 0; i < h->param.i_threads; i++ )
        x264_threadpool_run( h->threadpool, (void*)slices_write, h->thread[i] );
    /* wait */
    for( int i = 0; i < h->param.i_threads; i++ )
        x264_threadslice_cond_wait( h->thread[i], 1 );

    x264_threads_merge_ratecontrol( h );

    for( int i = 1; i < h->param.i_threads; i++ )
    {
        x264_t *t = h->thread[i];
        for( int j = 0; j < t->out.i_nal; j++ )
        {
            h->out.nal[h->out.i_nal] = t->out.nal[j];
            h->out.i_nal++;
            nal_check_buffer( h );
        }
        /* All entries in stat.frame are ints except for ssd/ssim. */
        for( size_t j = 0; j < (offsetof(x264_t,stat.frame.i_ssd) - offsetof(x264_t,stat.frame.i_mv_bits)) / sizeof(int); j++ )
            ((int*)&h->stat.frame)[j] += ((int*)&t->stat.frame)[j];
        for( int j = 0; j < 3; j++ )
            h->stat.frame.i_ssd[j] += t->stat.frame.i_ssd[j];
        h->stat.frame.f_ssim += t->stat.frame.f_ssim;
        h->stat.frame.i_ssim_cnt += t->stat.frame.i_ssim_cnt;
    }

    return 0;
}

void x264_encoder_intra_refresh( x264_t *h )
{
    h = h->thread[h->i_thread_phase];
    h->b_queued_intra_refresh = 1;
}

int x264_encoder_invalidate_reference( x264_t *h, int64_t pts )
{
    if( h->param.i_bframe )
    {
        x264_log( h, X264_LOG_ERROR, "x264_encoder_invalidate_reference is not supported with B-frames enabled\n" );
        return -1;
    }
    if( h->param.b_intra_refresh )
    {
        x264_log( h, X264_LOG_ERROR, "x264_encoder_invalidate_reference is not supported with intra refresh enabled\n" );
        return -1;
    }
    h = h->thread[h->i_thread_phase];
    if( pts >= h->i_last_idr_pts )
    {
        for( int i = 0; h->frames.reference[i]; i++ )
            if( pts <= h->frames.reference[i]->i_pts )
                h->frames.reference[i]->b_corrupt = 1;
        if( pts <= h->fdec->i_pts )
            h->fdec->b_corrupt = 1;
    }
    return 0;
}

/****************************************************************************
 * x264_encoder_encode:
 *  XXX: i_poc   : is the poc of the current given picture
 *       i_frame : is the number of the frame being coded
 *  ex:  type frame poc
 *       I      0   2*0
 *       P      1   2*3
 *       B      2   2*1
 *       B      3   2*2
 *       P      4   2*6
 *       B      5   2*4
 *       B      6   2*5
 ****************************************************************************/
int     x264_encoder_encode( x264_t *h,
                             x264_nal_t **pp_nal, int *pi_nal,
                             x264_picture_t *pic_in,
                             x264_picture_t *pic_out )
{
    x264_t *thread_current, *thread_prev, *thread_oldest;
    int i_nal_type, i_nal_ref_idc, i_global_qp;
    int overhead = NALU_OVERHEAD;

#if HAVE_OPENCL
    if( h->opencl.b_fatal_error )
        return -1;
#endif

    if( h->i_thread_frames > 1 )
    {
        thread_prev    = h->thread[ h->i_thread_phase ];
        h->i_thread_phase = (h->i_thread_phase + 1) % h->i_thread_frames;
        thread_current = h->thread[ h->i_thread_phase ];
        thread_oldest  = h->thread[ (h->i_thread_phase + 1) % h->i_thread_frames ];
        thread_sync_context( thread_current, thread_prev );
        x264_thread_sync_ratecontrol( thread_current, thread_prev, thread_oldest );
        h = thread_current;
    }
    else
    {
        thread_current =
        thread_oldest  = h;
    }
    h->i_cpb_delay_pir_offset = h->i_cpb_delay_pir_offset_next;

    /* no data out */
    *pi_nal = 0;
    *pp_nal = NULL;

    /* ------------------- Setup new frame from picture -------------------- */
    if( pic_in != NULL )
    {
        if( h->lookahead->b_exit_thread )
        {
            x264_log( h, X264_LOG_ERROR, "lookahead thread is already stopped\n" );
            return -1;
        }

        /* 1: Copy the picture to a frame and move it to a buffer */
        x264_frame_t *fenc = x264_frame_pop_unused( h, 0 );
        if( !fenc )
            return -1;

        if( x264_frame_copy_picture( h, fenc, pic_in ) < 0 )
            return -1;

        if( h->param.i_width != 16 * h->mb.i_mb_width ||
            h->param.i_height != 16 * h->mb.i_mb_height )
            x264_frame_expand_border_mod16( h, fenc );

        fenc->i_frame = h->frames.i_input++;

        if( fenc->i_frame == 0 )
            h->frames.i_first_pts = fenc->i_pts;
        if( h->frames.i_bframe_delay && fenc->i_frame == h->frames.i_bframe_delay )
            h->frames.i_bframe_delay_time = fenc->i_pts - h->frames.i_first_pts;

        if( h->param.b_vfr_input && fenc->i_pts <= h->frames.i_largest_pts )
            x264_log( h, X264_LOG_WARNING, "non-strictly-monotonic PTS\n" );

        h->frames.i_second_largest_pts = h->frames.i_largest_pts;
        h->frames.i_largest_pts = fenc->i_pts;

        if( (fenc->i_pic_struct < PIC_STRUCT_AUTO) || (fenc->i_pic_struct > PIC_STRUCT_TRIPLE) )
            fenc->i_pic_struct = PIC_STRUCT_AUTO;

        if( fenc->i_pic_struct == PIC_STRUCT_AUTO )
        {
#if HAVE_INTERLACED
            int b_interlaced = fenc->param ? fenc->param->b_interlaced : h->param.b_interlaced;
#else
            int b_interlaced = 0;
#endif
            if( b_interlaced )
            {
                int b_tff = fenc->param ? fenc->param->b_tff : h->param.b_tff;
                fenc->i_pic_struct = b_tff ? PIC_STRUCT_TOP_BOTTOM : PIC_STRUCT_BOTTOM_TOP;
            }
            else
                fenc->i_pic_struct = PIC_STRUCT_PROGRESSIVE;
        }

        if( h->param.rc.b_mb_tree && h->param.rc.b_stat_read )
        {
            if( x264_macroblock_tree_read( h, fenc, pic_in->prop.quant_offsets ) )
                return -1;
        }
        else
            x264_adaptive_quant_frame( h, fenc, pic_in->prop.quant_offsets );

        if( pic_in->prop.quant_offsets_free )
            pic_in->prop.quant_offsets_free( pic_in->prop.quant_offsets );

        if( h->frames.b_have_lowres )
            x264_frame_init_lowres( h, fenc );

        /* 2: Place the frame into the queue for its slice type decision */
        x264_lookahead_put_frame( h, fenc );

        if( h->frames.i_input <= h->frames.i_delay + 1 - h->i_thread_frames )
        {
            /* Nothing yet to encode, waiting for filling of buffers */
            pic_out->i_type = X264_TYPE_AUTO;
            return 0;
        }
    }
    else
    {
        /* signal kills for lookahead thread */
        x264_pthread_mutex_lock( &h->lookahead->ifbuf.mutex );
        h->lookahead->b_exit_thread = 1;
        x264_pthread_cond_broadcast( &h->lookahead->ifbuf.cv_fill );
        x264_pthread_mutex_unlock( &h->lookahead->ifbuf.mutex );
    }

    h->i_frame++;
    /* 3: The picture is analyzed in the lookahead */
    if( !h->frames.current[0] )
        x264_lookahead_get_frames( h );

    if( !h->frames.current[0] && x264_lookahead_is_empty( h ) )
        return encoder_frame_end( thread_oldest, thread_current, pp_nal, pi_nal, pic_out );

    /* ------------------- Get frame to be encoded ------------------------- */
    /* 4: get picture to encode */
    h->fenc = x264_frame_shift( h->frames.current );

    /* If applicable, wait for previous frame reconstruction to finish */
    if( h->param.b_sliced_threads )
        if( threadpool_wait_all( h ) < 0 )
            return -1;

    if( h->i_frame == 0 )
        h->i_reordered_pts_delay = h->fenc->i_reordered_pts;
    if( h->reconfig )
    {
        x264_encoder_reconfig_apply( h, &h->reconfig_h->param );
        h->reconfig = 0;
    }
    if( h->fenc->param )
    {
        x264_encoder_reconfig_apply( h, h->fenc->param );
        if( h->fenc->param->param_free )
        {
            x264_param_cleanup( h->fenc->param );
            h->fenc->param->param_free( h->fenc->param );
            h->fenc->param = NULL;
        }
    }
    x264_ratecontrol_zone_init( h );

    // ok to call this before encoding any frames, since the initial values of fdec have b_kept_as_ref=0
    if( reference_update( h ) )
        return -1;
    h->fdec->i_lines_completed = -1;

    if( !IS_X264_TYPE_I( h->fenc->i_type ) )
    {
        int valid_refs_left = 0;
        for( int i = 0; h->frames.reference[i]; i++ )
            if( !h->frames.reference[i]->b_corrupt )
                valid_refs_left++;
        /* No valid reference frames left: force an IDR. */
        if( !valid_refs_left )
        {
            h->fenc->b_keyframe = 1;
            h->fenc->i_type = X264_TYPE_IDR;
        }
    }

    if( h->fenc->b_keyframe )
    {
        h->frames.i_last_keyframe = h->fenc->i_frame;
        if( h->fenc->i_type == X264_TYPE_IDR )
        {
            h->i_frame_num = 0;
            h->frames.i_last_idr = h->fenc->i_frame;
        }
    }
    h->sh.i_mmco_command_count =
    h->sh.i_mmco_remove_from_end = 0;
    h->b_ref_reorder[0] =
    h->b_ref_reorder[1] = 0;
    h->fdec->i_poc =
    h->fenc->i_poc = 2 * ( h->fenc->i_frame - X264_MAX( h->frames.i_last_idr, 0 ) );

    /* ------------------- Setup frame context ----------------------------- */
    /* 5: Init data dependent of frame type */
    if( h->fenc->i_type == X264_TYPE_IDR )
    {
        /* reset ref pictures */
        i_nal_type    = NAL_SLICE_IDR;
        i_nal_ref_idc = NAL_PRIORITY_HIGHEST;
        h->sh.i_type = SLICE_TYPE_I;
        reference_reset( h );
        h->frames.i_poc_last_open_gop = -1;
    }
    else if( h->fenc->i_type == X264_TYPE_I )
    {
        i_nal_type    = NAL_SLICE;
        i_nal_ref_idc = NAL_PRIORITY_HIGH; /* Not completely true but for now it is (as all I/P are kept as ref)*/
        h->sh.i_type = SLICE_TYPE_I;
        reference_hierarchy_reset( h );
        if( h->param.b_open_gop )
            h->frames.i_poc_last_open_gop = h->fenc->b_keyframe ? h->fenc->i_poc : -1;
    }
    else if( h->fenc->i_type == X264_TYPE_P )
    {
        i_nal_type    = NAL_SLICE;
        i_nal_ref_idc = NAL_PRIORITY_HIGH; /* Not completely true but for now it is (as all I/P are kept as ref)*/
        h->sh.i_type = SLICE_TYPE_P;
        reference_hierarchy_reset( h );
        h->frames.i_poc_last_open_gop = -1;
    }
    else if( h->fenc->i_type == X264_TYPE_BREF )
    {
        i_nal_type    = NAL_SLICE;
        i_nal_ref_idc = h->param.i_bframe_pyramid == X264_B_PYRAMID_STRICT ? NAL_PRIORITY_LOW : NAL_PRIORITY_HIGH;
        h->sh.i_type = SLICE_TYPE_B;
        reference_hierarchy_reset( h );
    }
    else    /* B frame */
    {
        i_nal_type    = NAL_SLICE;
        i_nal_ref_idc = NAL_PRIORITY_DISPOSABLE;
        h->sh.i_type = SLICE_TYPE_B;
    }

    h->fdec->i_type = h->fenc->i_type;
    h->fdec->i_frame = h->fenc->i_frame;
    h->fenc->b_kept_as_ref =
    h->fdec->b_kept_as_ref = i_nal_ref_idc != NAL_PRIORITY_DISPOSABLE && h->param.i_keyint_max > 1;

    h->fdec->mb_info = h->fenc->mb_info;
    h->fdec->mb_info_free = h->fenc->mb_info_free;
    h->fenc->mb_info = NULL;
    h->fenc->mb_info_free = NULL;

    h->fdec->i_pts = h->fenc->i_pts;
    if( h->frames.i_bframe_delay )
    {
        int64_t *prev_reordered_pts = thread_current->frames.i_prev_reordered_pts;
        h->fdec->i_dts = h->i_frame > h->frames.i_bframe_delay
                       ? prev_reordered_pts[ (h->i_frame - h->frames.i_bframe_delay) % h->frames.i_bframe_delay ]
                       : h->fenc->i_reordered_pts - h->frames.i_bframe_delay_time;
        prev_reordered_pts[ h->i_frame % h->frames.i_bframe_delay ] = h->fenc->i_reordered_pts;
    }
    else
        h->fdec->i_dts = h->fenc->i_reordered_pts;
    if( h->fenc->i_type == X264_TYPE_IDR )
        h->i_last_idr_pts = h->fdec->i_pts;

    /* ------------------- Init                ----------------------------- */
    /* build ref list 0/1 */
    reference_build_list( h, h->fdec->i_poc );

    /* ---------------------- Write the bitstream -------------------------- */
    /* Init bitstream context */
    if( h->param.b_sliced_threads )
    {
        for( int i = 0; i < h->param.i_threads; i++ )
        {
            bs_init( &h->thread[i]->out.bs, h->thread[i]->out.p_bitstream, h->thread[i]->out.i_bitstream );
            h->thread[i]->out.i_nal = 0;
        }
    }
    else
    {
        bs_init( &h->out.bs, h->out.p_bitstream, h->out.i_bitstream );
        h->out.i_nal = 0;
    }

    if( h->param.b_aud )
    {
        int pic_type;

        if( h->sh.i_type == SLICE_TYPE_I )
            pic_type = 0;
        else if( h->sh.i_type == SLICE_TYPE_P )
            pic_type = 1;
        else if( h->sh.i_type == SLICE_TYPE_B )
            pic_type = 2;
        else
            pic_type = 7;

        nal_start( h, NAL_AUD, NAL_PRIORITY_DISPOSABLE );
        bs_write( &h->out.bs, 3, pic_type );
        bs_rbsp_trailing( &h->out.bs );
        bs_flush( &h->out.bs );
        if( nal_end( h ) )
            return -1;
        overhead += h->out.nal[h->out.i_nal-1].i_payload + NALU_OVERHEAD;
    }

    h->i_nal_type = i_nal_type;
    h->i_nal_ref_idc = i_nal_ref_idc;

    if( h->param.b_intra_refresh )
    {
        if( IS_X264_TYPE_I( h->fenc->i_type ) )
        {
            h->fdec->i_frames_since_pir = 0;
            h->b_queued_intra_refresh = 0;
            /* PIR is currently only supported with ref == 1, so any intra frame effectively refreshes
             * the whole frame and counts as an intra refresh. */
            h->fdec->f_pir_position = h->mb.i_mb_width;
        }
        else if( h->fenc->i_type == X264_TYPE_P )
        {
            int pocdiff = (h->fdec->i_poc - h->fref[0][0]->i_poc)/2;
            float increment = X264_MAX( ((float)h->mb.i_mb_width-1) / h->param.i_keyint_max, 1 );
            h->fdec->f_pir_position = h->fref[0][0]->f_pir_position;
            h->fdec->i_frames_since_pir = h->fref[0][0]->i_frames_since_pir + pocdiff;
            if( h->fdec->i_frames_since_pir >= h->param.i_keyint_max ||
                (h->b_queued_intra_refresh && h->fdec->f_pir_position + 0.5 >= h->mb.i_mb_width) )
            {
                h->fdec->f_pir_position = 0;
                h->fdec->i_frames_since_pir = 0;
                h->b_queued_intra_refresh = 0;
                h->fenc->b_keyframe = 1;
            }
            h->fdec->i_pir_start_col = h->fdec->f_pir_position+0.5;
            h->fdec->f_pir_position += increment * pocdiff;
            h->fdec->i_pir_end_col = h->fdec->f_pir_position+0.5;
            /* If our intra refresh has reached the right side of the frame, we're done. */
            if( h->fdec->i_pir_end_col >= h->mb.i_mb_width - 1 )
            {
                h->fdec->f_pir_position = h->mb.i_mb_width;
                h->fdec->i_pir_end_col = h->mb.i_mb_width - 1;
            }
        }
    }

    if( h->fenc->b_keyframe )
    {
        /* Write SPS and PPS */
        if( h->param.b_repeat_headers )
        {
            /* generate sequence parameters */
            nal_start( h, NAL_SPS, NAL_PRIORITY_HIGHEST );
            x264_sps_write( &h->out.bs, h->sps );
            if( nal_end( h ) )
                return -1;
            /* Pad AUD/SPS to 256 bytes like Panasonic */
            if( h->param.i_avcintra_class )
                h->out.nal[h->out.i_nal-1].i_padding = 256 - bs_pos( &h->out.bs ) / 8 - 2*NALU_OVERHEAD;
            overhead += h->out.nal[h->out.i_nal-1].i_payload + h->out.nal[h->out.i_nal-1].i_padding + NALU_OVERHEAD;

            /* generate picture parameters */
            nal_start( h, NAL_PPS, NAL_PRIORITY_HIGHEST );
            x264_pps_write( &h->out.bs, h->sps, h->pps );
            if( nal_end( h ) )
                return -1;
            if( h->param.i_avcintra_class )
            {
                int total_len = 256;
                /* Sony XAVC uses an oversized PPS instead of SEI padding */
                if( h->param.i_avcintra_flavor == X264_AVCINTRA_FLAVOR_SONY )
                    total_len += h->param.i_height >= 1080 ? 18*512 : 10*512;
                h->out.nal[h->out.i_nal-1].i_padding = total_len - h->out.nal[h->out.i_nal-1].i_payload - NALU_OVERHEAD;
            }
            overhead += h->out.nal[h->out.i_nal-1].i_payload + h->out.nal[h->out.i_nal-1].i_padding + NALU_OVERHEAD;
        }

        /* when frame threading is used, buffering period sei is written in encoder_frame_end */
        if( h->i_thread_frames == 1 && h->sps->vui.b_nal_hrd_parameters_present )
        {
            x264_hrd_fullness( h );
            nal_start( h, NAL_SEI, NAL_PRIORITY_DISPOSABLE );
            x264_sei_buffering_period_write( h, &h->out.bs );
            if( nal_end( h ) )
               return -1;
            overhead += h->out.nal[h->out.i_nal-1].i_payload + SEI_OVERHEAD;
        }
    }

    /* write extra sei */
    for( int i = 0; i < h->fenc->extra_sei.num_payloads; i++ )
    {
        nal_start( h, NAL_SEI, NAL_PRIORITY_DISPOSABLE );
        x264_sei_write( &h->out.bs, h->fenc->extra_sei.payloads[i].payload, h->fenc->extra_sei.payloads[i].payload_size,
                        h->fenc->extra_sei.payloads[i].payload_type );
        if( nal_end( h ) )
            return -1;
        overhead += h->out.nal[h->out.i_nal-1].i_payload + SEI_OVERHEAD;
        if( h->fenc->extra_sei.sei_free )
        {
            h->fenc->extra_sei.sei_free( h->fenc->extra_sei.payloads[i].payload );
            h->fenc->extra_sei.payloads[i].payload = NULL;
        }
    }

    if( h->fenc->extra_sei.sei_free )
    {
        h->fenc->extra_sei.sei_free( h->fenc->extra_sei.payloads );
        h->fenc->extra_sei.payloads = NULL;
        h->fenc->extra_sei.sei_free = NULL;
    }

    if( h->fenc->b_keyframe )
    {
        /* Avid's decoder strictly wants two SEIs for AVC-Intra so we can't insert the x264 SEI */
        if( h->param.b_repeat_headers && h->fenc->i_frame == 0 && !h->param.i_avcintra_class )
        {
            /* identify ourself */
            nal_start( h, NAL_SEI, NAL_PRIORITY_DISPOSABLE );
            if( x264_sei_version_write( h, &h->out.bs ) )
                return -1;
            if( nal_end( h ) )
                return -1;
            overhead += h->out.nal[h->out.i_nal-1].i_payload + SEI_OVERHEAD;
        }

        if( h->fenc->i_type != X264_TYPE_IDR )
        {
            int time_to_recovery = h->param.b_open_gop ? 0 : X264_MIN( h->mb.i_mb_width - 1, h->param.i_keyint_max ) + h->param.i_bframe - 1;
            nal_start( h, NAL_SEI, NAL_PRIORITY_DISPOSABLE );
            x264_sei_recovery_point_write( h, &h->out.bs, time_to_recovery );
            if( nal_end( h ) )
                return -1;
            overhead += h->out.nal[h->out.i_nal-1].i_payload + SEI_OVERHEAD;
        }

        if( h->param.mastering_display.b_mastering_display )
        {
            nal_start( h, NAL_SEI, NAL_PRIORITY_DISPOSABLE );
            x264_sei_mastering_display_write( h, &h->out.bs );
            if( nal_end( h ) )
                return -1;
            overhead += h->out.nal[h->out.i_nal-1].i_payload + SEI_OVERHEAD;
        }

        if( h->param.content_light_level.b_cll )
        {
            nal_start( h, NAL_SEI, NAL_PRIORITY_DISPOSABLE );
            x264_sei_content_light_level_write( h, &h->out.bs );
            if( nal_end( h ) )
                return -1;
            overhead += h->out.nal[h->out.i_nal-1].i_payload + SEI_OVERHEAD;
        }

        if( h->param.i_alternative_transfer != 2 )
        {
            nal_start( h, NAL_SEI, NAL_PRIORITY_DISPOSABLE );
            x264_sei_alternative_transfer_write( h, &h->out.bs );
            if( nal_end( h ) )
                return -1;
            overhead += h->out.nal[h->out.i_nal-1].i_payload + SEI_OVERHEAD;
        }
    }

    if( h->param.i_frame_packing >= 0 && (h->fenc->b_keyframe || h->param.i_frame_packing == 5) )
    {
        nal_start( h, NAL_SEI, NAL_PRIORITY_DISPOSABLE );
        x264_sei_frame_packing_write( h, &h->out.bs );
        if( nal_end( h ) )
            return -1;
        overhead += h->out.nal[h->out.i_nal-1].i_payload + SEI_OVERHEAD;
    }

    /* generate sei pic timing */
    if( h->sps->vui.b_pic_struct_present || h->sps->vui.b_nal_hrd_parameters_present )
    {
        nal_start( h, NAL_SEI, NAL_PRIORITY_DISPOSABLE );
        x264_sei_pic_timing_write( h, &h->out.bs );
        if( nal_end( h ) )
            return -1;
        overhead += h->out.nal[h->out.i_nal-1].i_payload + SEI_OVERHEAD;
    }

    /* As required by Blu-ray. */
    if( !IS_X264_TYPE_B( h->fenc->i_type ) && h->b_sh_backup )
    {
        h->b_sh_backup = 0;
        nal_start( h, NAL_SEI, NAL_PRIORITY_DISPOSABLE );
        x264_sei_dec_ref_pic_marking_write( h, &h->out.bs );
        if( nal_end( h ) )
            return -1;
        overhead += h->out.nal[h->out.i_nal-1].i_payload + SEI_OVERHEAD;
    }

    if( h->fenc->b_keyframe && h->param.b_intra_refresh )
        h->i_cpb_delay_pir_offset_next = h->fenc->i_cpb_delay;

    /* Filler space: 10 or 18 SEIs' worth of space, depending on resolution */
    if( h->param.i_avcintra_class && h->param.i_avcintra_flavor != X264_AVCINTRA_FLAVOR_SONY )
    {
        /* Write an empty filler NAL to mimic the AUD in the P2 format*/
        nal_start( h, NAL_FILLER, NAL_PRIORITY_DISPOSABLE );
        x264_filler_write( h, &h->out.bs, 0 );
        if( nal_end( h ) )
            return -1;
        overhead += h->out.nal[h->out.i_nal-1].i_payload + NALU_OVERHEAD;

        /* All lengths are magic lengths that decoders expect to see */
        /* "UMID" SEI */
        nal_start( h, NAL_SEI, NAL_PRIORITY_DISPOSABLE );
        if( x264_sei_avcintra_umid_write( h, &h->out.bs ) < 0 )
            return -1;
        if( nal_end( h ) )
            return -1;
        overhead += h->out.nal[h->out.i_nal-1].i_payload + SEI_OVERHEAD;

        int unpadded_len;
        int total_len;
        if( h->param.i_height == 1080 )
        {
            unpadded_len = 5780;
            total_len = 17*512;
        }
        else
        {
            unpadded_len = 2900;
            total_len = 9*512;
        }
        /* "VANC" SEI */
        nal_start( h, NAL_SEI, NAL_PRIORITY_DISPOSABLE );
        if( x264_sei_avcintra_vanc_write( h, &h->out.bs, unpadded_len ) < 0 )
            return -1;
        if( nal_end( h ) )
            return -1;

        h->out.nal[h->out.i_nal-1].i_padding = total_len - h->out.nal[h->out.i_nal-1].i_payload - SEI_OVERHEAD;
        overhead += h->out.nal[h->out.i_nal-1].i_payload + h->out.nal[h->out.i_nal-1].i_padding + SEI_OVERHEAD;
    }

    /* Init the rate control */
    /* FIXME: Include slice header bit cost. */
    x264_ratecontrol_start( h, h->fenc->i_qpplus1, overhead*8 );
    i_global_qp = x264_ratecontrol_qp( h );

    pic_out->i_qpplus1 =
    h->fdec->i_qpplus1 = i_global_qp + 1;

    if( h->param.rc.b_stat_read && h->sh.i_type != SLICE_TYPE_I )
    {
        x264_reference_build_list_optimal( h );
        reference_check_reorder( h );
    }

    if( h->i_ref[0] )
        h->fdec->i_poc_l0ref0 = h->fref[0][0]->i_poc;

    /* ------------------------ Create slice header  ----------------------- */
    slice_init( h, i_nal_type, i_global_qp );

    /*------------------------- Weights -------------------------------------*/
    if( h->sh.i_type == SLICE_TYPE_B )
        x264_macroblock_bipred_init( h );

    weighted_pred_init( h );

    if( i_nal_ref_idc != NAL_PRIORITY_DISPOSABLE )
        h->i_frame_num++;

    /* Write frame */
    h->i_threadslice_start = 0;
    h->i_threadslice_end = h->mb.i_mb_height;
    if( h->i_thread_frames > 1 )
    {
        x264_threadpool_run( h->threadpool, (void*)slices_write, h );
        h->b_thread_active = 1;
    }
    else if( h->param.b_sliced_threads )
    {
        if( threaded_slices_write( h ) )
            return -1;
    }
    else
        if( (intptr_t)slices_write( h ) )
            return -1;

    return encoder_frame_end( thread_oldest, thread_current, pp_nal, pi_nal, pic_out );
}

static int encoder_frame_end( x264_t *h, x264_t *thread_current,
                              x264_nal_t **pp_nal, int *pi_nal,
                              x264_picture_t *pic_out )
{
    char psz_message[80];

    if( !h->param.b_sliced_threads && h->b_thread_active )
    {
        h->b_thread_active = 0;
        if( (intptr_t)x264_threadpool_wait( h->threadpool, h ) )
            return -1;
    }
    if( !h->out.i_nal )
    {
        pic_out->i_type = X264_TYPE_AUTO;
        return 0;
    }

    x264_emms();

    /* generate buffering period sei and insert it into place */
    if( h->i_thread_frames > 1 && h->fenc->b_keyframe && h->sps->vui.b_nal_hrd_parameters_present )
    {
        x264_hrd_fullness( h );
        nal_start( h, NAL_SEI, NAL_PRIORITY_DISPOSABLE );
        x264_sei_buffering_period_write( h, &h->out.bs );
        if( nal_end( h ) )
           return -1;
        /* buffering period sei must follow AUD, SPS and PPS and precede all other SEIs */
        int idx = 0;
        while( h->out.nal[idx].i_type == NAL_AUD ||
               h->out.nal[idx].i_type == NAL_SPS ||
               h->out.nal[idx].i_type == NAL_PPS )
            idx++;
        x264_nal_t nal_tmp = h->out.nal[h->out.i_nal-1];
        memmove( &h->out.nal[idx+1], &h->out.nal[idx], (h->out.i_nal-idx-1)*sizeof(x264_nal_t) );
        h->out.nal[idx] = nal_tmp;
    }

    int frame_size = encoder_encapsulate_nals( h, 0 );
    if( frame_size < 0 )
        return -1;

    /* Set output picture properties */
    pic_out->i_type = h->fenc->i_type;

    pic_out->b_keyframe = h->fenc->b_keyframe;
    pic_out->i_pic_struct = h->fenc->i_pic_struct;

    pic_out->i_pts = h->fdec->i_pts;
    pic_out->i_dts = h->fdec->i_dts;

    if( pic_out->i_pts < pic_out->i_dts )
        x264_log( h, X264_LOG_WARNING, "invalid DTS: PTS is less than DTS\n" );

    pic_out->opaque = h->fenc->opaque;

    pic_out->img.i_csp = h->fdec->i_csp;
#if HIGH_BIT_DEPTH
    pic_out->img.i_csp |= X264_CSP_HIGH_DEPTH;
#endif
    pic_out->img.i_plane = h->fdec->i_plane;
    for( int i = 0; i < pic_out->img.i_plane; i++ )
    {
        pic_out->img.i_stride[i] = h->fdec->i_stride[i] * SIZEOF_PIXEL;
        pic_out->img.plane[i] = (uint8_t*)h->fdec->plane[i];
    }

    x264_frame_push_unused( thread_current, h->fenc );

    /* ---------------------- Update encoder state ------------------------- */

    /* update rc */
    int filler = 0;
    if( x264_ratecontrol_end( h, frame_size * 8, &filler ) < 0 )
        return -1;

    pic_out->hrd_timing = h->fenc->hrd_timing;
    pic_out->prop.f_crf_avg = h->fdec->f_crf_avg;

    /* Filler in AVC-Intra mode is written as zero bytes to the last slice
     * We don't know the size of the last slice until encapsulation so we add filler to the encapsulated NAL */
    if( h->param.i_avcintra_class )
    {
        if( check_encapsulated_buffer( h, h->thread[0], h->out.i_nal, frame_size, (int64_t)frame_size + filler ) < 0 )
            return -1;

        x264_nal_t *nal = &h->out.nal[h->out.i_nal-1];
        memset( nal->p_payload + nal->i_payload, 0, filler );
        nal->i_payload += filler;
        nal->i_padding = filler;
        frame_size += filler;

        /* Fix up the size header for mp4/etc */
        if( !h->param.b_annexb )
        {
            /* Size doesn't include the size of the header we're writing now. */
            uint8_t *nal_data = nal->p_payload;
            int chunk_size = nal->i_payload - 4;
            nal_data[0] = chunk_size >> 24;
            nal_data[1] = chunk_size >> 16;
            nal_data[2] = chunk_size >> 8;
            nal_data[3] = chunk_size >> 0;
        }
    }
    else
    {
        while( filler > 0 )
        {
            int f, overhead = FILLER_OVERHEAD - h->param.b_annexb;
            if( h->param.i_slice_max_size && filler > h->param.i_slice_max_size )
            {
                int next_size = filler - h->param.i_slice_max_size;
                int overflow = X264_MAX( overhead - next_size, 0 );
                f = h->param.i_slice_max_size - overhead - overflow;
            }
            else
                f = X264_MAX( 0, filler - overhead );

            if( bitstream_check_buffer_filler( h, f ) )
                return -1;
            nal_start( h, NAL_FILLER, NAL_PRIORITY_DISPOSABLE );
            x264_filler_write( h, &h->out.bs, f );
            if( nal_end( h ) )
                return -1;
            int total_size = encoder_encapsulate_nals( h, h->out.i_nal-1 );
            if( total_size < 0 )
                return -1;
            frame_size += total_size;
            filler -= total_size;
        }
    }

    /* End bitstream, set output  */
    *pi_nal = h->out.i_nal;
    *pp_nal = h->out.nal;

    h->out.i_nal = 0;

    x264_noise_reduction_update( h );

    /* ---------------------- Compute/Print statistics --------------------- */
    thread_sync_stat( h, h->thread[0] );

    /* Slice stat */
    h->stat.i_frame_count[h->sh.i_type]++;
    h->stat.i_frame_size[h->sh.i_type] += frame_size;
    h->stat.f_frame_qp[h->sh.i_type] += h->fdec->f_qp_avg_aq;

    for( int i = 0; i < X264_MBTYPE_MAX; i++ )
        h->stat.i_mb_count[h->sh.i_type][i] += h->stat.frame.i_mb_count[i];
    for( int i = 0; i < 2; i++ )
        h->stat.i_mb_count_8x8dct[i] += h->stat.frame.i_mb_count_8x8dct[i];
    for( int i = 0; i < 6; i++ )
        h->stat.i_mb_cbp[i] += h->stat.frame.i_mb_cbp[i];
    for( int i = 0; i < 4; i++ )
        for( int j = 0; j < 13; j++ )
            h->stat.i_mb_pred_mode[i][j] += h->stat.frame.i_mb_pred_mode[i][j];
    if( h->sh.i_type != SLICE_TYPE_I )
    {
        for( int i = 0; i < X264_PARTTYPE_MAX; i++ )
            h->stat.i_mb_partition[h->sh.i_type][i] += h->stat.frame.i_mb_partition[i];
        for( int i_list = 0; i_list < 2; i_list++ )
            for( int i = 0; i < X264_REF_MAX*2; i++ )
                h->stat.i_mb_count_ref[h->sh.i_type][i_list][i] += h->stat.frame.i_mb_count_ref[i_list][i];
    }
    for( int i = 0; i < 3; i++ )
        h->stat.i_mb_field[i] += h->stat.frame.i_mb_field[i];
    if( h->sh.i_type == SLICE_TYPE_P && h->param.analyse.i_weighted_pred >= X264_WEIGHTP_SIMPLE )
    {
        h->stat.i_wpred[0] += !!h->sh.weight[0][0].weightfn;
        h->stat.i_wpred[1] += !!h->sh.weight[0][1].weightfn || !!h->sh.weight[0][2].weightfn;
    }
    if( h->sh.i_type == SLICE_TYPE_B )
    {
        h->stat.i_direct_frames[ h->sh.b_direct_spatial_mv_pred ] ++;
        if( h->mb.b_direct_auto_write )
        {
            //FIXME somewhat arbitrary time constants
            if( h->stat.i_direct_score[0] + h->stat.i_direct_score[1] > h->mb.i_mb_count )
                for( int i = 0; i < 2; i++ )
                    h->stat.i_direct_score[i] = h->stat.i_direct_score[i] * 9/10;
            for( int i = 0; i < 2; i++ )
                h->stat.i_direct_score[i] += h->stat.frame.i_direct_score[i];
        }
    }
    else
        h->stat.i_consecutive_bframes[h->fenc->i_bframes]++;

    psz_message[0] = '\0';
    double dur = h->fenc->f_duration;
    h->stat.f_frame_duration[h->sh.i_type] += dur;
    if( h->param.analyse.b_psnr )
    {
        int64_t ssd[3] =
        {
            h->stat.frame.i_ssd[0],
            h->stat.frame.i_ssd[1],
            h->stat.frame.i_ssd[2],
        };
        int luma_size = h->param.i_width * h->param.i_height;
        int chroma_size = CHROMA_SIZE( luma_size );
        pic_out->prop.f_psnr[0] = calc_psnr( ssd[0], luma_size );
        pic_out->prop.f_psnr[1] = calc_psnr( ssd[1], chroma_size );
        pic_out->prop.f_psnr[2] = calc_psnr( ssd[2], chroma_size );
        pic_out->prop.f_psnr_avg = calc_psnr( ssd[0] + ssd[1] + ssd[2], luma_size + chroma_size*2 );

        h->stat.f_ssd_global[h->sh.i_type]   += dur * (ssd[0] + ssd[1] + ssd[2]);
        h->stat.f_psnr_average[h->sh.i_type] += dur * pic_out->prop.f_psnr_avg;
        h->stat.f_psnr_mean_y[h->sh.i_type]  += dur * pic_out->prop.f_psnr[0];
        h->stat.f_psnr_mean_u[h->sh.i_type]  += dur * pic_out->prop.f_psnr[1];
        h->stat.f_psnr_mean_v[h->sh.i_type]  += dur * pic_out->prop.f_psnr[2];

        snprintf( psz_message, 80, " PSNR Y:%5.2f U:%5.2f V:%5.2f", pic_out->prop.f_psnr[0],
                                                                    pic_out->prop.f_psnr[1],
                                                                    pic_out->prop.f_psnr[2] );
    }

    if( h->param.analyse.b_ssim )
    {
        pic_out->prop.f_ssim = h->stat.frame.f_ssim / h->stat.frame.i_ssim_cnt;
        h->stat.f_ssim_mean_y[h->sh.i_type] += pic_out->prop.f_ssim * dur;
        int msg_len = strlen(psz_message);
        snprintf( psz_message + msg_len, 80 - msg_len, " SSIM Y:%.5f", pic_out->prop.f_ssim );
    }
    psz_message[79] = '\0';

    x264_log( h, X264_LOG_DEBUG,
              "frame=%4d QP=%.2f NAL=%d Slice:%c Poc:%-3d I:%-4d P:%-4d SKIP:%-4d size=%d bytes%s\n",
              h->i_frame,
              h->fdec->f_qp_avg_aq,
              h->i_nal_ref_idc,
              h->sh.i_type == SLICE_TYPE_I ? 'I' : (h->sh.i_type == SLICE_TYPE_P ? 'P' : 'B' ),
              h->fdec->i_poc,
              h->stat.frame.i_mb_count_i,
              h->stat.frame.i_mb_count_p,
              h->stat.frame.i_mb_count_skip,
              frame_size,
              psz_message );

    // keep stats all in one place
    thread_sync_stat( h->thread[0], h );
    // for the use of the next frame
    thread_sync_stat( thread_current, h );

#ifdef DEBUG_MB_TYPE
{
    static const char mb_chars[] = { 'i', 'i', 'I', 'C', 'P', '8', 'S',
        'D', '<', 'X', 'B', 'X', '>', 'B', 'B', 'B', 'B', '8', 'S' };
    for( int mb_xy = 0; mb_xy < h->mb.i_mb_width * h->mb.i_mb_height; mb_xy++ )
    {
        if( h->mb.type[mb_xy] < X264_MBTYPE_MAX && h->mb.type[mb_xy] >= 0 )
            fprintf( stderr, "%c ", mb_chars[ h->mb.type[mb_xy] ] );
        else
            fprintf( stderr, "? " );

        if( (mb_xy+1) % h->mb.i_mb_width == 0 )
            fprintf( stderr, "\n" );
    }
}
#endif

    /* Remove duplicates, must be done near the end as breaks h->fref0 array
     * by freeing some of its pointers. */
    for( int i = 0; i < h->i_ref[0]; i++ )
        if( h->fref[0][i] && h->fref[0][i]->b_duplicate )
        {
            x264_frame_push_blank_unused( h, h->fref[0][i] );
            h->fref[0][i] = 0;
        }

    if( h->param.psz_dump_yuv )
        frame_dump( h );
    x264_emms();

    return frame_size;
}

static void print_intra( int64_t *i_mb_count, double i_count, int b_print_pcm, char *intra )
{
    intra += sprintf( intra, "I16..4%s: %4.1f%% %4.1f%% %4.1f%%",
        b_print_pcm ? "..PCM" : "",
        i_mb_count[I_16x16]/ i_count,
        i_mb_count[I_8x8]  / i_count,
        i_mb_count[I_4x4]  / i_count );
    if( b_print_pcm )
        sprintf( intra, " %4.1f%%", i_mb_count[I_PCM]  / i_count );
}

/****************************************************************************
 * x264_encoder_close:
 ****************************************************************************/
void    x264_encoder_close  ( x264_t *h )
{
    int64_t i_yuv_size = FRAME_SIZE( h->param.i_width * h->param.i_height );
    int64_t i_mb_count_size[2][7] = {{0}};
    char buf[200];
    int b_print_pcm = h->stat.i_mb_count[SLICE_TYPE_I][I_PCM]
                   || h->stat.i_mb_count[SLICE_TYPE_P][I_PCM]
                   || h->stat.i_mb_count[SLICE_TYPE_B][I_PCM];

    x264_lookahead_delete( h );

#if HAVE_OPENCL
    x264_opencl_lookahead_delete( h );
    x264_opencl_function_t *ocl = h->opencl.ocl;
#endif

    if( h->param.b_sliced_threads )
        threadpool_wait_all( h );
    if( h->param.i_threads > 1 )
        x264_threadpool_delete( h->threadpool );
    if( h->param.i_lookahead_threads > 1 )
        x264_threadpool_delete( h->lookaheadpool );
    if( h->i_thread_frames > 1 )
    {
        for( int i = 0; i < h->i_thread_frames; i++ )
            if( h->thread[i]->b_thread_active )
            {
                assert( h->thread[i]->fenc->i_reference_count == 1 );
                x264_frame_delete( h->thread[i]->fenc );
            }

        x264_t *thread_prev = h->thread[h->i_thread_phase];
        x264_thread_sync_ratecontrol( h, thread_prev, h );
        x264_thread_sync_ratecontrol( thread_prev, thread_prev, h );
        h->i_frame = thread_prev->i_frame + 1 - h->i_thread_frames;
    }
    h->i_frame++;

    /* Slices used and PSNR */
    for( int i = 0; i < 3; i++ )
    {
        static const uint8_t slice_order[] = { SLICE_TYPE_I, SLICE_TYPE_P, SLICE_TYPE_B };
        int i_slice = slice_order[i];

        if( h->stat.i_frame_count[i_slice] > 0 )
        {
            int i_count = h->stat.i_frame_count[i_slice];
            double dur =  h->stat.f_frame_duration[i_slice];
            if( h->param.analyse.b_psnr )
            {
                x264_log( h, X264_LOG_INFO,
                          "frame %c:%-5d Avg QP:%5.2f  size:%6.0f  PSNR Mean Y:%5.2f U:%5.2f V:%5.2f Avg:%5.2f Global:%5.2f\n",
                          slice_type_to_char[i_slice],
                          i_count,
                          h->stat.f_frame_qp[i_slice] / i_count,
                          (double)h->stat.i_frame_size[i_slice] / i_count,
                          h->stat.f_psnr_mean_y[i_slice] / dur, h->stat.f_psnr_mean_u[i_slice] / dur, h->stat.f_psnr_mean_v[i_slice] / dur,
                          h->stat.f_psnr_average[i_slice] / dur,
                          calc_psnr( h->stat.f_ssd_global[i_slice], dur * i_yuv_size ) );
            }
            else
            {
                x264_log( h, X264_LOG_INFO,
                          "frame %c:%-5d Avg QP:%5.2f  size:%6.0f\n",
                          slice_type_to_char[i_slice],
                          i_count,
                          h->stat.f_frame_qp[i_slice] / i_count,
                          (double)h->stat.i_frame_size[i_slice] / i_count );
            }
        }
    }
    if( h->param.i_bframe && h->stat.i_frame_count[SLICE_TYPE_B] )
    {
        char *p = buf;
        int den = 0;
        // weight by number of frames (including the I/P-frames) that are in a sequence of N B-frames
        for( int i = 0; i <= h->param.i_bframe; i++ )
            den += (i+1) * h->stat.i_consecutive_bframes[i];
        for( int i = 0; i <= h->param.i_bframe; i++ )
            p += sprintf( p, " %4.1f%%", 100. * (i+1) * h->stat.i_consecutive_bframes[i] / den );
        x264_log( h, X264_LOG_INFO, "consecutive B-frames:%s\n", buf );
    }

    for( int i_type = 0; i_type < 2; i_type++ )
        for( int i = 0; i < X264_PARTTYPE_MAX; i++ )
        {
            if( i == D_DIRECT_8x8 ) continue; /* direct is counted as its own type */
            i_mb_count_size[i_type][x264_mb_partition_pixel_table[i]] += h->stat.i_mb_partition[i_type][i];
        }

    /* MB types used */
    if( h->stat.i_frame_count[SLICE_TYPE_I] > 0 )
    {
        int64_t *i_mb_count = h->stat.i_mb_count[SLICE_TYPE_I];
        double i_count = (double)h->stat.i_frame_count[SLICE_TYPE_I] * h->mb.i_mb_count / 100.0;
        print_intra( i_mb_count, i_count, b_print_pcm, buf );
        x264_log( h, X264_LOG_INFO, "mb I  %s\n", buf );
    }
    if( h->stat.i_frame_count[SLICE_TYPE_P] > 0 )
    {
        int64_t *i_mb_count = h->stat.i_mb_count[SLICE_TYPE_P];
        double i_count = (double)h->stat.i_frame_count[SLICE_TYPE_P] * h->mb.i_mb_count / 100.0;
        int64_t *i_mb_size = i_mb_count_size[SLICE_TYPE_P];
        print_intra( i_mb_count, i_count, b_print_pcm, buf );
        x264_log( h, X264_LOG_INFO,
                  "mb P  %s  P16..4: %4.1f%% %4.1f%% %4.1f%% %4.1f%% %4.1f%%    skip:%4.1f%%\n",
                  buf,
                  i_mb_size[PIXEL_16x16] / (i_count*4),
                  (i_mb_size[PIXEL_16x8] + i_mb_size[PIXEL_8x16]) / (i_count*4),
                  i_mb_size[PIXEL_8x8] / (i_count*4),
                  (i_mb_size[PIXEL_8x4] + i_mb_size[PIXEL_4x8]) / (i_count*4),
                  i_mb_size[PIXEL_4x4] / (i_count*4),
                  i_mb_count[P_SKIP] / i_count );
    }
    if( h->stat.i_frame_count[SLICE_TYPE_B] > 0 )
    {
        int64_t *i_mb_count = h->stat.i_mb_count[SLICE_TYPE_B];
        double i_count = (double)h->stat.i_frame_count[SLICE_TYPE_B] * h->mb.i_mb_count / 100.0;
        double i_mb_list_count;
        int64_t *i_mb_size = i_mb_count_size[SLICE_TYPE_B];
        int64_t list_count[3] = {0}; /* 0 == L0, 1 == L1, 2 == BI */
        print_intra( i_mb_count, i_count, b_print_pcm, buf );
        for( int i = 0; i < X264_PARTTYPE_MAX; i++ )
            for( int j = 0; j < 2; j++ )
            {
                int l0 = x264_mb_type_list_table[i][0][j];
                int l1 = x264_mb_type_list_table[i][1][j];
                if( l0 || l1 )
                    list_count[l1+l0*l1] += h->stat.i_mb_count[SLICE_TYPE_B][i] * 2;
            }
        list_count[0] += h->stat.i_mb_partition[SLICE_TYPE_B][D_L0_8x8];
        list_count[1] += h->stat.i_mb_partition[SLICE_TYPE_B][D_L1_8x8];
        list_count[2] += h->stat.i_mb_partition[SLICE_TYPE_B][D_BI_8x8];
        i_mb_count[B_DIRECT] += (h->stat.i_mb_partition[SLICE_TYPE_B][D_DIRECT_8x8]+2)/4;
        i_mb_list_count = (list_count[0] + list_count[1] + list_count[2]) / 100.0;
        sprintf( buf + strlen(buf), "  B16..8: %4.1f%% %4.1f%% %4.1f%%  direct:%4.1f%%  skip:%4.1f%%",
                 i_mb_size[PIXEL_16x16] / (i_count*4),
                 (i_mb_size[PIXEL_16x8] + i_mb_size[PIXEL_8x16]) / (i_count*4),
                 i_mb_size[PIXEL_8x8] / (i_count*4),
                 i_mb_count[B_DIRECT] / i_count,
                 i_mb_count[B_SKIP]   / i_count );
        if( i_mb_list_count != 0 )
            sprintf( buf + strlen(buf), "  L0:%4.1f%% L1:%4.1f%% BI:%4.1f%%",
                     list_count[0] / i_mb_list_count,
                     list_count[1] / i_mb_list_count,
                     list_count[2] / i_mb_list_count );
        x264_log( h, X264_LOG_INFO, "mb B  %s\n", buf );
    }

    x264_ratecontrol_summary( h );

    if( h->stat.i_frame_count[SLICE_TYPE_I] + h->stat.i_frame_count[SLICE_TYPE_P] + h->stat.i_frame_count[SLICE_TYPE_B] > 0 )
    {
#define SUM3(p) (p[SLICE_TYPE_I] + p[SLICE_TYPE_P] + p[SLICE_TYPE_B])
#define SUM3b(p,o) (p[SLICE_TYPE_I][o] + p[SLICE_TYPE_P][o] + p[SLICE_TYPE_B][o])
        int64_t i_i8x8 = SUM3b( h->stat.i_mb_count, I_8x8 );
        int64_t i_intra = i_i8x8 + SUM3b( h->stat.i_mb_count, I_4x4 )
                                 + SUM3b( h->stat.i_mb_count, I_16x16 );
        int64_t i_all_intra = i_intra + SUM3b( h->stat.i_mb_count, I_PCM );
        int64_t i_skip = SUM3b( h->stat.i_mb_count, P_SKIP )
                       + SUM3b( h->stat.i_mb_count, B_SKIP );
        const int i_count = h->stat.i_frame_count[SLICE_TYPE_I] +
                            h->stat.i_frame_count[SLICE_TYPE_P] +
                            h->stat.i_frame_count[SLICE_TYPE_B];
        int64_t i_mb_count = (int64_t)i_count * h->mb.i_mb_count;
        int64_t i_inter = i_mb_count - i_skip - i_all_intra;
        const double duration = h->stat.f_frame_duration[SLICE_TYPE_I] +
                                h->stat.f_frame_duration[SLICE_TYPE_P] +
                                h->stat.f_frame_duration[SLICE_TYPE_B];
        float f_bitrate = SUM3(h->stat.i_frame_size) / duration / 125;

        if( PARAM_INTERLACED )
        {
            char *fieldstats = buf;
            fieldstats[0] = 0;
            if( i_inter )
                fieldstats += sprintf( fieldstats, " inter:%.1f%%", h->stat.i_mb_field[1] * 100.0 / i_inter );
            if( i_skip )
                fieldstats += sprintf( fieldstats, " skip:%.1f%%", h->stat.i_mb_field[2] * 100.0 / i_skip );
            x264_log( h, X264_LOG_INFO, "field mbs: intra: %.1f%%%s\n",
                      h->stat.i_mb_field[0] * 100.0 / i_all_intra, buf );
        }

        if( h->pps->b_transform_8x8_mode )
        {
            buf[0] = 0;
            if( h->stat.i_mb_count_8x8dct[0] )
                sprintf( buf, " inter:%.1f%%", 100. * h->stat.i_mb_count_8x8dct[1] / h->stat.i_mb_count_8x8dct[0] );
            x264_log( h, X264_LOG_INFO, "8x8 transform intra:%.1f%%%s\n", 100. * i_i8x8 / X264_MAX( i_intra, 1 ), buf );
        }

        if( (h->param.analyse.i_direct_mv_pred == X264_DIRECT_PRED_AUTO ||
            (h->stat.i_direct_frames[0] && h->stat.i_direct_frames[1]))
            && h->stat.i_frame_count[SLICE_TYPE_B] )
        {
            x264_log( h, X264_LOG_INFO, "direct mvs  spatial:%.1f%% temporal:%.1f%%\n",
                      h->stat.i_direct_frames[1] * 100. / h->stat.i_frame_count[SLICE_TYPE_B],
                      h->stat.i_direct_frames[0] * 100. / h->stat.i_frame_count[SLICE_TYPE_B] );
        }

        buf[0] = 0;
        if( CHROMA_FORMAT )
        {
            int csize = CHROMA444 ? 4 : 1;
            if( i_mb_count != i_all_intra )
                sprintf( buf, " inter: %.1f%% %.1f%% %.1f%%",
                         h->stat.i_mb_cbp[1] * 100.0 / ((i_mb_count - i_all_intra)*4),
                         h->stat.i_mb_cbp[3] * 100.0 / ((i_mb_count - i_all_intra)*csize),
                         h->stat.i_mb_cbp[5] * 100.0 / ((i_mb_count - i_all_intra)*csize) );
            x264_log( h, X264_LOG_INFO, "coded y,%s,%s intra: %.1f%% %.1f%% %.1f%%%s\n",
                      CHROMA444?"u":"uvDC", CHROMA444?"v":"uvAC",
                      h->stat.i_mb_cbp[0] * 100.0 / (i_all_intra*4),
                      h->stat.i_mb_cbp[2] * 100.0 / (i_all_intra*csize),
                      h->stat.i_mb_cbp[4] * 100.0 / (i_all_intra*csize), buf );
        }
        else
        {
            if( i_mb_count != i_all_intra )
                sprintf( buf, " inter: %.1f%%", h->stat.i_mb_cbp[1] * 100.0 / ((i_mb_count - i_all_intra)*4) );
            x264_log( h, X264_LOG_INFO, "coded y intra: %.1f%%%s\n",
                      h->stat.i_mb_cbp[0] * 100.0 / (i_all_intra*4), buf );
        }

        int64_t fixed_pred_modes[4][9] = {{0}};
        int64_t sum_pred_modes[4] = {0};
        for( int i = 0; i <= I_PRED_16x16_DC_128; i++ )
        {
            fixed_pred_modes[0][x264_mb_pred_mode16x16_fix[i]] += h->stat.i_mb_pred_mode[0][i];
            sum_pred_modes[0] += h->stat.i_mb_pred_mode[0][i];
        }
        if( sum_pred_modes[0] )
            x264_log( h, X264_LOG_INFO, "i16 v,h,dc,p: %2.0f%% %2.0f%% %2.0f%% %2.0f%%\n",
                      fixed_pred_modes[0][0] * 100.0 / sum_pred_modes[0],
                      fixed_pred_modes[0][1] * 100.0 / sum_pred_modes[0],
                      fixed_pred_modes[0][2] * 100.0 / sum_pred_modes[0],
                      fixed_pred_modes[0][3] * 100.0 / sum_pred_modes[0] );
        for( int i = 1; i <= 2; i++ )
        {
            for( int j = 0; j <= I_PRED_8x8_DC_128; j++ )
            {
                fixed_pred_modes[i][x264_mb_pred_mode4x4_fix(j)] += h->stat.i_mb_pred_mode[i][j];
                sum_pred_modes[i] += h->stat.i_mb_pred_mode[i][j];
            }
            if( sum_pred_modes[i] )
                x264_log( h, X264_LOG_INFO, "i%d v,h,dc,ddl,ddr,vr,hd,vl,hu: %2.0f%% %2.0f%% %2.0f%% %2.0f%% %2.0f%% %2.0f%% %2.0f%% %2.0f%% %2.0f%%\n", (3-i)*4,
                          fixed_pred_modes[i][0] * 100.0 / sum_pred_modes[i],
                          fixed_pred_modes[i][1] * 100.0 / sum_pred_modes[i],
                          fixed_pred_modes[i][2] * 100.0 / sum_pred_modes[i],
                          fixed_pred_modes[i][3] * 100.0 / sum_pred_modes[i],
                          fixed_pred_modes[i][4] * 100.0 / sum_pred_modes[i],
                          fixed_pred_modes[i][5] * 100.0 / sum_pred_modes[i],
                          fixed_pred_modes[i][6] * 100.0 / sum_pred_modes[i],
                          fixed_pred_modes[i][7] * 100.0 / sum_pred_modes[i],
                          fixed_pred_modes[i][8] * 100.0 / sum_pred_modes[i] );
        }
        for( int i = 0; i <= I_PRED_CHROMA_DC_128; i++ )
        {
            fixed_pred_modes[3][x264_mb_chroma_pred_mode_fix[i]] += h->stat.i_mb_pred_mode[3][i];
            sum_pred_modes[3] += h->stat.i_mb_pred_mode[3][i];
        }
        if( sum_pred_modes[3] && !CHROMA444 )
            x264_log( h, X264_LOG_INFO, "i8c dc,h,v,p: %2.0f%% %2.0f%% %2.0f%% %2.0f%%\n",
                      fixed_pred_modes[3][0] * 100.0 / sum_pred_modes[3],
                      fixed_pred_modes[3][1] * 100.0 / sum_pred_modes[3],
                      fixed_pred_modes[3][2] * 100.0 / sum_pred_modes[3],
                      fixed_pred_modes[3][3] * 100.0 / sum_pred_modes[3] );

        if( h->param.analyse.i_weighted_pred >= X264_WEIGHTP_SIMPLE && h->stat.i_frame_count[SLICE_TYPE_P] > 0 )
        {
            buf[0] = 0;
            if( CHROMA_FORMAT )
                sprintf( buf, " UV:%.1f%%", h->stat.i_wpred[1] * 100.0 / h->stat.i_frame_count[SLICE_TYPE_P] );
            x264_log( h, X264_LOG_INFO, "Weighted P-Frames: Y:%.1f%%%s\n",
                      h->stat.i_wpred[0] * 100.0 / h->stat.i_frame_count[SLICE_TYPE_P], buf );
        }

        for( int i_list = 0; i_list < 2; i_list++ )
            for( int i_slice = 0; i_slice < 2; i_slice++ )
            {
                char *p = buf;
                int64_t i_den = 0;
                int i_max = 0;
                for( int i = 0; i < X264_REF_MAX*2; i++ )
                    if( h->stat.i_mb_count_ref[i_slice][i_list][i] )
                    {
                        i_den += h->stat.i_mb_count_ref[i_slice][i_list][i];
                        i_max = i;
                    }
                if( i_max == 0 )
                    continue;
                for( int i = 0; i <= i_max; i++ )
                    p += sprintf( p, " %4.1f%%", 100. * h->stat.i_mb_count_ref[i_slice][i_list][i] / i_den );
                x264_log( h, X264_LOG_INFO, "ref %c L%d:%s\n", "PB"[i_slice], i_list, buf );
            }

        if( h->param.analyse.b_ssim )
        {
            float ssim = SUM3( h->stat.f_ssim_mean_y ) / duration;
            x264_log( h, X264_LOG_INFO, "SSIM Mean Y:%.7f (%6.3fdb)\n", ssim, calc_ssim_db( ssim ) );
        }
        if( h->param.analyse.b_psnr )
        {
            x264_log( h, X264_LOG_INFO,
                      "PSNR Mean Y:%6.3f U:%6.3f V:%6.3f Avg:%6.3f Global:%6.3f kb/s:%.2f\n",
                      SUM3( h->stat.f_psnr_mean_y ) / duration,
                      SUM3( h->stat.f_psnr_mean_u ) / duration,
                      SUM3( h->stat.f_psnr_mean_v ) / duration,
                      SUM3( h->stat.f_psnr_average ) / duration,
                      calc_psnr( SUM3( h->stat.f_ssd_global ), duration * i_yuv_size ),
                      f_bitrate );
        }
        else
            x264_log( h, X264_LOG_INFO, "kb/s:%.2f\n", f_bitrate );
    }

    /* rc */
    x264_ratecontrol_delete( h );

    /* param */
    x264_param_cleanup( &h->param );

    x264_cqm_delete( h );
    x264_free( h->nal_buffer );
    x264_free( h->reconfig_h );
    x264_analyse_free_costs( h );
    x264_free( h->cost_table );

    if( h->i_thread_frames > 1 )
        h = h->thread[h->i_thread_phase];

    /* frames */
    x264_frame_delete_list( h->frames.unused[0] );
    x264_frame_delete_list( h->frames.unused[1] );
    x264_frame_delete_list( h->frames.current );
    x264_frame_delete_list( h->frames.blank_unused );

    h = h->thread[0];

    for( int i = 0; i < h->i_thread_frames; i++ )
        if( h->thread[i]->b_thread_active )
            for( int j = 0; j < h->thread[i]->i_ref[0]; j++ )
                if( h->thread[i]->fref[0][j] && h->thread[i]->fref[0][j]->b_duplicate )
                    x264_frame_delete( h->thread[i]->fref[0][j] );

    if( h->param.i_lookahead_threads > 1 )
        for( int i = 0; i < h->param.i_lookahead_threads; i++ )
            x264_free( h->lookahead_thread[i] );

    for( int i = h->param.i_threads - 1; i >= 0; i-- )
    {
        x264_frame_t **frame;

        if( !h->param.b_sliced_threads || i == 0 )
        {
            for( frame = h->thread[i]->frames.reference; *frame; frame++ )
            {
                assert( (*frame)->i_reference_count > 0 );
                (*frame)->i_reference_count--;
                if( (*frame)->i_reference_count == 0 )
                    x264_frame_delete( *frame );
            }
            frame = &h->thread[i]->fdec;
            if( *frame )
            {
                assert( (*frame)->i_reference_count > 0 );
                (*frame)->i_reference_count--;
                if( (*frame)->i_reference_count == 0 )
                    x264_frame_delete( *frame );
            }
            x264_macroblock_cache_free( h->thread[i] );
        }
        x264_macroblock_thread_free( h->thread[i], 0 );
        x264_free( h->thread[i]->out.p_bitstream );
        x264_free( h->thread[i]->out.nal );
        x264_pthread_mutex_destroy( &h->thread[i]->mutex );
        x264_pthread_cond_destroy( &h->thread[i]->cv );
        x264_free( h->thread[i] );
    }
#if HAVE_OPENCL
    x264_opencl_close_library( ocl );
#endif
}

int x264_encoder_delayed_frames( x264_t *h )
{
    int delayed_frames = 0;
    if( h->i_thread_frames > 1 )
    {
        for( int i = 0; i < h->i_thread_frames; i++ )
            delayed_frames += h->thread[i]->b_thread_active;
        h = h->thread[h->i_thread_phase];
    }
    for( int i = 0; h->frames.current[i]; i++ )
        delayed_frames++;
    x264_pthread_mutex_lock( &h->lookahead->ofbuf.mutex );
    x264_pthread_mutex_lock( &h->lookahead->ifbuf.mutex );
    x264_pthread_mutex_lock( &h->lookahead->next.mutex );
    delayed_frames += h->lookahead->ifbuf.i_size + h->lookahead->next.i_size + h->lookahead->ofbuf.i_size;
    x264_pthread_mutex_unlock( &h->lookahead->next.mutex );
    x264_pthread_mutex_unlock( &h->lookahead->ifbuf.mutex );
    x264_pthread_mutex_unlock( &h->lookahead->ofbuf.mutex );
    return delayed_frames;
}

int x264_encoder_maximum_delayed_frames( x264_t *h )
{
    return h->frames.i_delay;
}
