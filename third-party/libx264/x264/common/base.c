/*****************************************************************************
 * base.c: misc common functions (bit depth independent)
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

#include "base.h"

#include <ctype.h>

#if HAVE_MALLOC_H
#include <malloc.h>
#endif
#if HAVE_THP
#include <sys/mman.h>
#endif

/****************************************************************************
 * x264_reduce_fraction:
 ****************************************************************************/
#define REDUCE_FRACTION( name, type )\
void name( type *n, type *d )\
{                   \
    type a = *n;    \
    type b = *d;    \
    type c;         \
    if( !a || !b )  \
        return;     \
    c = a % b;      \
    while( c )      \
    {               \
        a = b;      \
        b = c;      \
        c = a % b;  \
    }               \
    *n /= b;        \
    *d /= b;        \
}

REDUCE_FRACTION( x264_reduce_fraction  , uint32_t )
REDUCE_FRACTION( x264_reduce_fraction64, uint64_t )

/****************************************************************************
 * x264_log:
 ****************************************************************************/
void x264_log_default( void *p_unused, int i_level, const char *psz_fmt, va_list arg )
{
    char *psz_prefix;
    switch( i_level )
    {
        case X264_LOG_ERROR:
            psz_prefix = "error";
            break;
        case X264_LOG_WARNING:
            psz_prefix = "warning";
            break;
        case X264_LOG_INFO:
            psz_prefix = "info";
            break;
        case X264_LOG_DEBUG:
            psz_prefix = "debug";
            break;
        default:
            psz_prefix = "unknown";
            break;
    }
    fprintf( stderr, "x264 [%s]: ", psz_prefix );
    x264_vfprintf( stderr, psz_fmt, arg );
}

void x264_log_internal( int i_level, const char *psz_fmt, ... )
{
    va_list arg;
    va_start( arg, psz_fmt );
    x264_log_default( NULL, i_level, psz_fmt, arg );
    va_end( arg );
}

/****************************************************************************
 * x264_malloc:
 ****************************************************************************/
void *x264_malloc( int64_t i_size )
{
#define HUGE_PAGE_SIZE 2*1024*1024
#define HUGE_PAGE_THRESHOLD HUGE_PAGE_SIZE*7/8 /* FIXME: Is this optimal? */
    if( i_size < 0 || (uint64_t)i_size > (SIZE_MAX - HUGE_PAGE_SIZE) /*|| (uint64_t)i_size > (SIZE_MAX - NATIVE_ALIGN - sizeof(void **))*/ )
    {
        x264_log_internal( X264_LOG_ERROR, "invalid size of malloc: %"PRId64"\n", i_size );
        return NULL;
    }
    uint8_t *align_buf = NULL;
#if HAVE_MALLOC_H
#if HAVE_THP
    /* Attempt to allocate huge pages to reduce TLB misses. */
    if( i_size >= HUGE_PAGE_THRESHOLD )
    {
        align_buf = memalign( HUGE_PAGE_SIZE, i_size );
        if( align_buf )
        {
            /* Round up to the next huge page boundary if we are close enough. */
            size_t madv_size = (i_size + HUGE_PAGE_SIZE - HUGE_PAGE_THRESHOLD) & ~(HUGE_PAGE_SIZE-1);
            madvise( align_buf, madv_size, MADV_HUGEPAGE );
        }
    }
    else
#endif
        align_buf = memalign( NATIVE_ALIGN, i_size );
#else
    uint8_t *buf = malloc( i_size + (NATIVE_ALIGN-1) + sizeof(void **) );
    if( buf )
    {
        align_buf = buf + (NATIVE_ALIGN-1) + sizeof(void **);
        align_buf -= (intptr_t) align_buf & (NATIVE_ALIGN-1);
        *( (void **) ( align_buf - sizeof(void **) ) ) = buf;
    }
#endif
    if( !align_buf )
        x264_log_internal( X264_LOG_ERROR, "malloc of size %"PRId64" failed\n", i_size );
    return align_buf;
#undef HUGE_PAGE_SIZE
#undef HUGE_PAGE_THRESHOLD
}

/****************************************************************************
 * x264_free:
 ****************************************************************************/
void x264_free( void *p )
{
    if( p )
    {
#if HAVE_MALLOC_H
        free( p );
#else
        free( *( ( ( void **) p ) - 1 ) );
#endif
    }
}

/****************************************************************************
 * x264_slurp_file:
 ****************************************************************************/
char *x264_slurp_file( const char *filename )
{
    int b_error = 0;
    int64_t i_size;
    char *buf;
    FILE *fh = x264_fopen( filename, "rb" );
    if( !fh )
        return NULL;

    b_error |= fseek( fh, 0, SEEK_END ) < 0;
    b_error |= ( i_size = ftell( fh ) ) <= 0;
    if( WORD_SIZE == 4 )
        b_error |= i_size > INT32_MAX;
    b_error |= fseek( fh, 0, SEEK_SET ) < 0;
    if( b_error )
        goto error;

    buf = x264_malloc( i_size+2 );
    if( !buf )
        goto error;

    b_error |= fread( buf, 1, i_size, fh ) != (uint64_t)i_size;
    fclose( fh );
    if( b_error )
    {
        x264_free( buf );
        return NULL;
    }

    if( buf[i_size-1] != '\n' )
        buf[i_size++] = '\n';
    buf[i_size] = '\0';

    return buf;
error:
    fclose( fh );
    return NULL;
}

/****************************************************************************
 * x264_param_strdup:
 ****************************************************************************/
typedef struct {
    int size;
    int count;
    void *ptr[];
} strdup_buffer;

#define BUFFER_OFFSET (int)offsetof(strdup_buffer, ptr)
#define BUFFER_DEFAULT_SIZE 16

char *x264_param_strdup( x264_param_t *param, const char *src )
{
    strdup_buffer *buf = param->opaque;
    if( !buf )
    {
        buf = malloc( BUFFER_OFFSET + BUFFER_DEFAULT_SIZE * sizeof(void *) );
        if( !buf )
            goto fail;
        buf->size = BUFFER_DEFAULT_SIZE;
        buf->count = 0;
        param->opaque = buf;
    }
    else if( buf->count == buf->size )
    {
        if( buf->size > (INT_MAX - BUFFER_OFFSET) / 2 / (int)sizeof(void *) )
            goto fail;
        int new_size = buf->size * 2;
        buf = realloc( buf, BUFFER_OFFSET + new_size * sizeof(void *) );
        if( !buf )
            goto fail;
        buf->size = new_size;
        param->opaque = buf;
    }
    char *res = strdup( src );
    if( !res )
        goto fail;
    buf->ptr[buf->count++] = res;
    return res;
fail:
    x264_log_internal( X264_LOG_ERROR, "x264_param_strdup failed\n" );
    return NULL;
}

/****************************************************************************
 * x264_param_cleanup:
 ****************************************************************************/
REALIGN_STACK void x264_param_cleanup( x264_param_t *param )
{
    strdup_buffer *buf = param->opaque;
    if( buf )
    {
        for( int i = 0; i < buf->count; i++ )
            free( buf->ptr[i] );
        free( buf );
        param->opaque = NULL;
    }
}

/****************************************************************************
 * x264_picture_init:
 ****************************************************************************/
REALIGN_STACK void x264_picture_init( x264_picture_t *pic )
{
    memset( pic, 0, sizeof( x264_picture_t ) );
    pic->i_type = X264_TYPE_AUTO;
    pic->i_qpplus1 = X264_QP_AUTO;
    pic->i_pic_struct = PIC_STRUCT_AUTO;
}

/****************************************************************************
 * x264_picture_alloc:
 ****************************************************************************/
REALIGN_STACK int x264_picture_alloc( x264_picture_t *pic, int i_csp, int i_width, int i_height )
{
    typedef struct
    {
        int planes;
        int width_fix8[3];
        int height_fix8[3];
    } x264_csp_tab_t;

    static const x264_csp_tab_t csp_tab[] =
    {
        [X264_CSP_I400] = { 1, { 256*1 },               { 256*1 }               },
        [X264_CSP_I420] = { 3, { 256*1, 256/2, 256/2 }, { 256*1, 256/2, 256/2 } },
        [X264_CSP_YV12] = { 3, { 256*1, 256/2, 256/2 }, { 256*1, 256/2, 256/2 } },
        [X264_CSP_NV12] = { 2, { 256*1, 256*1 },        { 256*1, 256/2 },       },
        [X264_CSP_NV21] = { 2, { 256*1, 256*1 },        { 256*1, 256/2 },       },
        [X264_CSP_I422] = { 3, { 256*1, 256/2, 256/2 }, { 256*1, 256*1, 256*1 } },
        [X264_CSP_YV16] = { 3, { 256*1, 256/2, 256/2 }, { 256*1, 256*1, 256*1 } },
        [X264_CSP_NV16] = { 2, { 256*1, 256*1 },        { 256*1, 256*1 },       },
        [X264_CSP_YUYV] = { 1, { 256*2 },               { 256*1 },              },
        [X264_CSP_UYVY] = { 1, { 256*2 },               { 256*1 },              },
        [X264_CSP_I444] = { 3, { 256*1, 256*1, 256*1 }, { 256*1, 256*1, 256*1 } },
        [X264_CSP_YV24] = { 3, { 256*1, 256*1, 256*1 }, { 256*1, 256*1, 256*1 } },
        [X264_CSP_BGR]  = { 1, { 256*3 },               { 256*1 },              },
        [X264_CSP_BGRA] = { 1, { 256*4 },               { 256*1 },              },
        [X264_CSP_RGB]  = { 1, { 256*3 },               { 256*1 },              },
    };

    int csp = i_csp & X264_CSP_MASK;
    if( csp <= X264_CSP_NONE || csp >= X264_CSP_MAX || csp == X264_CSP_V210 )
        return -1;
    x264_picture_init( pic );
    pic->img.i_csp = i_csp;
    pic->img.i_plane = csp_tab[csp].planes;
    int depth_factor = i_csp & X264_CSP_HIGH_DEPTH ? 2 : 1;
    int64_t plane_offset[3] = {0};
    int64_t frame_size = 0;
    for( int i = 0; i < pic->img.i_plane; i++ )
    {
        int stride = (((int64_t)i_width * csp_tab[csp].width_fix8[i]) >> 8) * depth_factor;
        int64_t plane_size = (((int64_t)i_height * csp_tab[csp].height_fix8[i]) >> 8) * stride;
        pic->img.i_stride[i] = stride;
        plane_offset[i] = frame_size;
        frame_size += plane_size;
    }
    pic->img.plane[0] = x264_malloc( frame_size );
    if( !pic->img.plane[0] )
        return -1;
    for( int i = 1; i < pic->img.i_plane; i++ )
        pic->img.plane[i] = pic->img.plane[0] + plane_offset[i];
    return 0;
}

/****************************************************************************
 * x264_picture_clean:
 ****************************************************************************/
REALIGN_STACK void x264_picture_clean( x264_picture_t *pic )
{
    x264_free( pic->img.plane[0] );

    /* just to be safe */
    memset( pic, 0, sizeof( x264_picture_t ) );
}

/****************************************************************************
 * x264_param_default:
 ****************************************************************************/
REALIGN_STACK void x264_param_default( x264_param_t *param )
{
    /* */
    memset( param, 0, sizeof( x264_param_t ) );

    /* CPU autodetect */
    param->cpu = x264_cpu_detect();
    param->i_threads = X264_THREADS_AUTO;
    param->i_lookahead_threads = X264_THREADS_AUTO;
    param->b_deterministic = 1;
    param->i_sync_lookahead = X264_SYNC_LOOKAHEAD_AUTO;

    /* Video properties */
    param->i_csp           = X264_CHROMA_FORMAT ? X264_CHROMA_FORMAT : X264_CSP_I420;
    param->i_width         = 0;
    param->i_height        = 0;
    param->vui.i_sar_width = 0;
    param->vui.i_sar_height= 0;
    param->vui.i_overscan  = 0;  /* undef */
    param->vui.i_vidformat = 5;  /* undef */
    param->vui.b_fullrange = -1; /* default depends on input */
    param->vui.i_colorprim = 2;  /* undef */
    param->vui.i_transfer  = 2;  /* undef */
    param->vui.i_colmatrix = -1; /* default depends on input */
    param->vui.i_chroma_loc= 0;  /* left center */
    param->i_fps_num       = 25;
    param->i_fps_den       = 1;
    param->i_level_idc     = -1;
    param->i_slice_max_size = 0;
    param->i_slice_max_mbs = 0;
    param->i_slice_count = 0;
#if HAVE_BITDEPTH8
    param->i_bitdepth = 8;
#elif HAVE_BITDEPTH10
    param->i_bitdepth = 10;
#else
    param->i_bitdepth = 8;
#endif

    /* Encoder parameters */
    param->i_frame_reference = 3;
    param->i_keyint_max = 250;
    param->i_keyint_min = X264_KEYINT_MIN_AUTO;
    param->i_bframe = 3;
    param->i_scenecut_threshold = 40;
    param->i_bframe_adaptive = X264_B_ADAPT_FAST;
    param->i_bframe_bias = 0;
    param->i_bframe_pyramid = X264_B_PYRAMID_NORMAL;
    param->b_interlaced = 0;
    param->b_constrained_intra = 0;

    param->b_deblocking_filter = 1;
    param->i_deblocking_filter_alphac0 = 0;
    param->i_deblocking_filter_beta = 0;

    param->b_cabac = 1;
    param->i_cabac_init_idc = 0;

    param->rc.i_rc_method = X264_RC_CRF;
    param->rc.i_bitrate = 0;
    param->rc.f_rate_tolerance = 1.0;
    param->rc.i_vbv_max_bitrate = 0;
    param->rc.i_vbv_buffer_size = 0;
    param->rc.f_vbv_buffer_init = 0.9;
    param->rc.i_qp_constant = -1;
    param->rc.f_rf_constant = 23;
    param->rc.i_qp_min = 0;
    param->rc.i_qp_max = INT_MAX;
    param->rc.i_qp_step = 4;
    param->rc.f_ip_factor = 1.4;
    param->rc.f_pb_factor = 1.3;
    param->rc.i_aq_mode = X264_AQ_VARIANCE;
    param->rc.f_aq_strength = 1.0;
    param->rc.i_lookahead = 40;

    param->rc.b_stat_write = 0;
    param->rc.psz_stat_out = "x264_2pass.log";
    param->rc.b_stat_read = 0;
    param->rc.psz_stat_in = "x264_2pass.log";
    param->rc.f_qcompress = 0.6;
    param->rc.f_qblur = 0.5;
    param->rc.f_complexity_blur = 20;
    param->rc.i_zones = 0;
    param->rc.b_mb_tree = 1;

    /* Log */
    param->pf_log = x264_log_default;
    param->p_log_private = NULL;
    param->i_log_level = X264_LOG_INFO;

    /* */
    param->analyse.intra = X264_ANALYSE_I4x4 | X264_ANALYSE_I8x8;
    param->analyse.inter = X264_ANALYSE_I4x4 | X264_ANALYSE_I8x8
                         | X264_ANALYSE_PSUB16x16 | X264_ANALYSE_BSUB16x16;
    param->analyse.i_direct_mv_pred = X264_DIRECT_PRED_SPATIAL;
    param->analyse.i_me_method = X264_ME_HEX;
    param->analyse.f_psy_rd = 1.0;
    param->analyse.b_psy = 1;
    param->analyse.f_psy_trellis = 0;
    param->analyse.i_me_range = 16;
    param->analyse.i_subpel_refine = 7;
    param->analyse.b_mixed_references = 1;
    param->analyse.b_chroma_me = 1;
    param->analyse.i_mv_range_thread = -1;
    param->analyse.i_mv_range = -1; // set from level_idc
    param->analyse.i_chroma_qp_offset = 0;
    param->analyse.b_fast_pskip = 1;
    param->analyse.b_weighted_bipred = 1;
    param->analyse.i_weighted_pred = X264_WEIGHTP_SMART;
    param->analyse.b_dct_decimate = 1;
    param->analyse.b_transform_8x8 = 1;
    param->analyse.i_trellis = 1;
    param->analyse.i_luma_deadzone[0] = 21;
    param->analyse.i_luma_deadzone[1] = 11;
    param->analyse.b_psnr = 0;
    param->analyse.b_ssim = 0;

    param->i_cqm_preset = X264_CQM_FLAT;
    memset( param->cqm_4iy, 16, sizeof( param->cqm_4iy ) );
    memset( param->cqm_4py, 16, sizeof( param->cqm_4py ) );
    memset( param->cqm_4ic, 16, sizeof( param->cqm_4ic ) );
    memset( param->cqm_4pc, 16, sizeof( param->cqm_4pc ) );
    memset( param->cqm_8iy, 16, sizeof( param->cqm_8iy ) );
    memset( param->cqm_8py, 16, sizeof( param->cqm_8py ) );
    memset( param->cqm_8ic, 16, sizeof( param->cqm_8ic ) );
    memset( param->cqm_8pc, 16, sizeof( param->cqm_8pc ) );

    param->b_repeat_headers = 1;
    param->b_annexb = 1;
    param->b_aud = 0;
    param->b_vfr_input = 1;
    param->i_nal_hrd = X264_NAL_HRD_NONE;
    param->b_tff = 1;
    param->b_pic_struct = 0;
    param->b_fake_interlaced = 0;
    param->i_frame_packing = -1;
    param->i_alternative_transfer = 2; /* undef */
    param->b_opencl = 0;
    param->i_opencl_device = 0;
    param->opencl_device_id = NULL;
    param->psz_clbin_file = NULL;
    param->i_avcintra_class = 0;
    param->i_avcintra_flavor = X264_AVCINTRA_FLAVOR_PANASONIC;
}

static int param_apply_preset( x264_param_t *param, const char *preset )
{
    char *end;
    int i = strtol( preset, &end, 10 );
    if( *end == 0 && i >= 0 && i < ARRAY_ELEMS(x264_preset_names)-1 )
        preset = x264_preset_names[i];

    if( !strcasecmp( preset, "ultrafast" ) )
    {
        param->i_frame_reference = 1;
        param->i_scenecut_threshold = 0;
        param->b_deblocking_filter = 0;
        param->b_cabac = 0;
        param->i_bframe = 0;
        param->analyse.intra = 0;
        param->analyse.inter = 0;
        param->analyse.b_transform_8x8 = 0;
        param->analyse.i_me_method = X264_ME_DIA;
        param->analyse.i_subpel_refine = 0;
        param->rc.i_aq_mode = 0;
        param->analyse.b_mixed_references = 0;
        param->analyse.i_trellis = 0;
        param->i_bframe_adaptive = X264_B_ADAPT_NONE;
        param->rc.b_mb_tree = 0;
        param->analyse.i_weighted_pred = X264_WEIGHTP_NONE;
        param->analyse.b_weighted_bipred = 0;
        param->rc.i_lookahead = 0;
    }
    else if( !strcasecmp( preset, "superfast" ) )
    {
        param->analyse.inter = X264_ANALYSE_I8x8|X264_ANALYSE_I4x4;
        param->analyse.i_me_method = X264_ME_DIA;
        param->analyse.i_subpel_refine = 1;
        param->i_frame_reference = 1;
        param->analyse.b_mixed_references = 0;
        param->analyse.i_trellis = 0;
        param->rc.b_mb_tree = 0;
        param->analyse.i_weighted_pred = X264_WEIGHTP_SIMPLE;
        param->rc.i_lookahead = 0;
    }
    else if( !strcasecmp( preset, "veryfast" ) )
    {
        param->analyse.i_subpel_refine = 2;
        param->i_frame_reference = 1;
        param->analyse.b_mixed_references = 0;
        param->analyse.i_trellis = 0;
        param->analyse.i_weighted_pred = X264_WEIGHTP_SIMPLE;
        param->rc.i_lookahead = 10;
    }
    else if( !strcasecmp( preset, "faster" ) )
    {
        param->analyse.b_mixed_references = 0;
        param->i_frame_reference = 2;
        param->analyse.i_subpel_refine = 4;
        param->analyse.i_weighted_pred = X264_WEIGHTP_SIMPLE;
        param->rc.i_lookahead = 20;
    }
    else if( !strcasecmp( preset, "fast" ) )
    {
        param->i_frame_reference = 2;
        param->analyse.i_subpel_refine = 6;
        param->analyse.i_weighted_pred = X264_WEIGHTP_SIMPLE;
        param->rc.i_lookahead = 30;
    }
    else if( !strcasecmp( preset, "medium" ) )
    {
        /* Default is medium */
    }
    else if( !strcasecmp( preset, "slow" ) )
    {
        param->analyse.i_subpel_refine = 8;
        param->i_frame_reference = 5;
        param->analyse.i_direct_mv_pred = X264_DIRECT_PRED_AUTO;
        param->analyse.i_trellis = 2;
        param->rc.i_lookahead = 50;
    }
    else if( !strcasecmp( preset, "slower" ) )
    {
        param->analyse.i_me_method = X264_ME_UMH;
        param->analyse.i_subpel_refine = 9;
        param->i_frame_reference = 8;
        param->i_bframe_adaptive = X264_B_ADAPT_TRELLIS;
        param->analyse.i_direct_mv_pred = X264_DIRECT_PRED_AUTO;
        param->analyse.inter |= X264_ANALYSE_PSUB8x8;
        param->analyse.i_trellis = 2;
        param->rc.i_lookahead = 60;
    }
    else if( !strcasecmp( preset, "veryslow" ) )
    {
        param->analyse.i_me_method = X264_ME_UMH;
        param->analyse.i_subpel_refine = 10;
        param->analyse.i_me_range = 24;
        param->i_frame_reference = 16;
        param->i_bframe_adaptive = X264_B_ADAPT_TRELLIS;
        param->analyse.i_direct_mv_pred = X264_DIRECT_PRED_AUTO;
        param->analyse.inter |= X264_ANALYSE_PSUB8x8;
        param->analyse.i_trellis = 2;
        param->i_bframe = 8;
        param->rc.i_lookahead = 60;
    }
    else if( !strcasecmp( preset, "placebo" ) )
    {
        param->analyse.i_me_method = X264_ME_TESA;
        param->analyse.i_subpel_refine = 11;
        param->analyse.i_me_range = 24;
        param->i_frame_reference = 16;
        param->i_bframe_adaptive = X264_B_ADAPT_TRELLIS;
        param->analyse.i_direct_mv_pred = X264_DIRECT_PRED_AUTO;
        param->analyse.inter |= X264_ANALYSE_PSUB8x8;
        param->analyse.b_fast_pskip = 0;
        param->analyse.i_trellis = 2;
        param->i_bframe = 16;
        param->rc.i_lookahead = 60;
    }
    else
    {
        x264_log_internal( X264_LOG_ERROR, "invalid preset '%s'\n", preset );
        return -1;
    }
    return 0;
}

static int param_apply_tune( x264_param_t *param, const char *tune )
{
    int psy_tuning_used = 0;
    for( int len; tune += strspn( tune, ",./-+" ), (len = strcspn( tune, ",./-+" )); tune += len )
    {
        if( len == 4 && !strncasecmp( tune, "film", 4 ) )
        {
            if( psy_tuning_used++ ) goto psy_failure;
            param->i_deblocking_filter_alphac0 = -1;
            param->i_deblocking_filter_beta = -1;
            param->analyse.f_psy_trellis = 0.15;
        }
        else if( len == 9 && !strncasecmp( tune, "animation", 9 ) )
        {
            if( psy_tuning_used++ ) goto psy_failure;
            param->i_frame_reference = param->i_frame_reference > 1 ? param->i_frame_reference*2 : 1;
            param->i_deblocking_filter_alphac0 = 1;
            param->i_deblocking_filter_beta = 1;
            param->analyse.f_psy_rd = 0.4;
            param->rc.f_aq_strength = 0.6;
            param->i_bframe += 2;
        }
        else if( len == 5 && !strncasecmp( tune, "grain", 5 ) )
        {
            if( psy_tuning_used++ ) goto psy_failure;
            param->i_deblocking_filter_alphac0 = -2;
            param->i_deblocking_filter_beta = -2;
            param->analyse.f_psy_trellis = 0.25;
            param->analyse.b_dct_decimate = 0;
            param->rc.f_pb_factor = 1.1;
            param->rc.f_ip_factor = 1.1;
            param->rc.f_aq_strength = 0.5;
            param->analyse.i_luma_deadzone[0] = 6;
            param->analyse.i_luma_deadzone[1] = 6;
            param->rc.f_qcompress = 0.8;
        }
        else if( len == 10 && !strncasecmp( tune, "stillimage", 10 ) )
        {
            if( psy_tuning_used++ ) goto psy_failure;
            param->i_deblocking_filter_alphac0 = -3;
            param->i_deblocking_filter_beta = -3;
            param->analyse.f_psy_rd = 2.0;
            param->analyse.f_psy_trellis = 0.7;
            param->rc.f_aq_strength = 1.2;
        }
        else if( len == 4 && !strncasecmp( tune, "psnr", 4 ) )
        {
            if( psy_tuning_used++ ) goto psy_failure;
            param->rc.i_aq_mode = X264_AQ_NONE;
            param->analyse.b_psy = 0;
        }
        else if( len == 4 && !strncasecmp( tune, "ssim", 4 ) )
        {
            if( psy_tuning_used++ ) goto psy_failure;
            param->rc.i_aq_mode = X264_AQ_AUTOVARIANCE;
            param->analyse.b_psy = 0;
        }
        else if( len == 10 && !strncasecmp( tune, "fastdecode", 10 ) )
        {
            param->b_deblocking_filter = 0;
            param->b_cabac = 0;
            param->analyse.b_weighted_bipred = 0;
            param->analyse.i_weighted_pred = X264_WEIGHTP_NONE;
        }
        else if( len == 11 && !strncasecmp( tune, "zerolatency", 11 ) )
        {
            param->rc.i_lookahead = 0;
            param->i_sync_lookahead = 0;
            param->i_bframe = 0;
            param->b_sliced_threads = 1;
            param->b_vfr_input = 0;
            param->rc.b_mb_tree = 0;
        }
        else if( len == 6 && !strncasecmp( tune, "touhou", 6 ) )
        {
            if( psy_tuning_used++ ) goto psy_failure;
            param->i_frame_reference = param->i_frame_reference > 1 ? param->i_frame_reference*2 : 1;
            param->i_deblocking_filter_alphac0 = -1;
            param->i_deblocking_filter_beta = -1;
            param->analyse.f_psy_trellis = 0.2;
            param->rc.f_aq_strength = 1.3;
            if( param->analyse.inter & X264_ANALYSE_PSUB16x16 )
                param->analyse.inter |= X264_ANALYSE_PSUB8x8;
        }
        else
        {
            x264_log_internal( X264_LOG_ERROR, "invalid tune '%.*s'\n", len, tune );
            return -1;
    psy_failure:
            x264_log_internal( X264_LOG_WARNING, "only 1 psy tuning can be used: ignoring tune %.*s\n", len, tune );
        }
    }
    return 0;
}

REALIGN_STACK int x264_param_default_preset( x264_param_t *param, const char *preset, const char *tune )
{
    x264_param_default( param );

    if( preset && param_apply_preset( param, preset ) < 0 )
        return -1;
    if( tune && param_apply_tune( param, tune ) < 0 )
        return -1;
    return 0;
}

REALIGN_STACK void x264_param_apply_fastfirstpass( x264_param_t *param )
{
    /* Set faster options in case of turbo firstpass. */
    if( param->rc.b_stat_write && !param->rc.b_stat_read )
    {
        param->i_frame_reference = 1;
        param->analyse.b_transform_8x8 = 0;
        param->analyse.inter = 0;
        param->analyse.i_me_method = X264_ME_DIA;
        param->analyse.i_subpel_refine = X264_MIN( 2, param->analyse.i_subpel_refine );
        param->analyse.i_trellis = 0;
        param->analyse.b_fast_pskip = 1;
    }
}

static int profile_string_to_int( const char *str )
{
    if( !strcasecmp( str, "baseline" ) )
        return PROFILE_BASELINE;
    if( !strcasecmp( str, "main" ) )
        return PROFILE_MAIN;
    if( !strcasecmp( str, "high" ) )
        return PROFILE_HIGH;
    if( !strcasecmp( str, "high10" ) )
        return PROFILE_HIGH10;
    if( !strcasecmp( str, "high422" ) )
        return PROFILE_HIGH422;
    if( !strcasecmp( str, "high444" ) )
        return PROFILE_HIGH444_PREDICTIVE;
    return -1;
}

REALIGN_STACK int x264_param_apply_profile( x264_param_t *param, const char *profile )
{
    if( !profile )
        return 0;

    const int qp_bd_offset = 6 * (param->i_bitdepth-8);
    int p = profile_string_to_int( profile );
    if( p < 0 )
    {
        x264_log_internal( X264_LOG_ERROR, "invalid profile: %s\n", profile );
        return -1;
    }
    if( p < PROFILE_HIGH444_PREDICTIVE && ((param->rc.i_rc_method == X264_RC_CQP && param->rc.i_qp_constant <= 0) ||
        (param->rc.i_rc_method == X264_RC_CRF && (int)(param->rc.f_rf_constant + qp_bd_offset) <= 0)) )
    {
        x264_log_internal( X264_LOG_ERROR, "%s profile doesn't support lossless\n", profile );
        return -1;
    }
    if( p < PROFILE_HIGH444_PREDICTIVE && (param->i_csp & X264_CSP_MASK) >= X264_CSP_I444 )
    {
        x264_log_internal( X264_LOG_ERROR, "%s profile doesn't support 4:4:4\n", profile );
        return -1;
    }
    if( p < PROFILE_HIGH422 && (param->i_csp & X264_CSP_MASK) >= X264_CSP_I422 )
    {
        x264_log_internal( X264_LOG_ERROR, "%s profile doesn't support 4:2:2\n", profile );
        return -1;
    }
    if( p < PROFILE_HIGH10 && param->i_bitdepth > 8 )
    {
        x264_log_internal( X264_LOG_ERROR, "%s profile doesn't support a bit depth of %d\n", profile, param->i_bitdepth );
        return -1;
    }
    if( p < PROFILE_HIGH && (param->i_csp & X264_CSP_MASK) == X264_CSP_I400 )
    {
        x264_log_internal( X264_LOG_ERROR, "%s profile doesn't support 4:0:0\n", profile );
        return -1;
    }

    if( p == PROFILE_BASELINE )
    {
        param->analyse.b_transform_8x8 = 0;
        param->b_cabac = 0;
        param->i_cqm_preset = X264_CQM_FLAT;
        param->psz_cqm_file = NULL;
        param->i_bframe = 0;
        param->analyse.i_weighted_pred = X264_WEIGHTP_NONE;
        if( param->b_interlaced )
        {
            x264_log_internal( X264_LOG_ERROR, "baseline profile doesn't support interlacing\n" );
            return -1;
        }
        if( param->b_fake_interlaced )
        {
            x264_log_internal( X264_LOG_ERROR, "baseline profile doesn't support fake interlacing\n" );
            return -1;
        }
    }
    else if( p == PROFILE_MAIN )
    {
        param->analyse.b_transform_8x8 = 0;
        param->i_cqm_preset = X264_CQM_FLAT;
        param->psz_cqm_file = NULL;
    }
    return 0;
}

static int parse_enum( const char *arg, const char * const *names, int *dst )
{
    for( int i = 0; names[i]; i++ )
        if( *names[i] && !strcasecmp( arg, names[i] ) )
        {
            *dst = i;
            return 0;
        }
    return -1;
}

static int parse_cqm( const char *str, uint8_t *cqm, int length )
{
    int i = 0;
    do {
        int coef;
        if( !sscanf( str, "%d", &coef ) || coef < 1 || coef > 255 )
            return -1;
        cqm[i++] = coef;
    } while( i < length && (str = strchr( str, ',' )) && str++ );
    return (i == length) ? 0 : -1;
}

static int atobool_internal( const char *str, int *b_error )
{
    if( !strcmp(str, "1") ||
        !strcasecmp(str, "true") ||
        !strcasecmp(str, "yes") )
        return 1;
    if( !strcmp(str, "0") ||
        !strcasecmp(str, "false") ||
        !strcasecmp(str, "no") )
        return 0;
    *b_error = 1;
    return 0;
}

static int atoi_internal( const char *str, int *b_error )
{
    char *end;
    int v = strtol( str, &end, 0 );
    if( end == str || *end != '\0' )
        *b_error = 1;
    return v;
}

static double atof_internal( const char *str, int *b_error )
{
    char *end;
    double v = strtod( str, &end );
    if( end == str || *end != '\0' )
        *b_error = 1;
    return v;
}

#define atobool(str) ( name_was_bool = 1, atobool_internal( str, &b_error ) )
#undef atoi
#undef atof
#define atoi(str) atoi_internal( str, &b_error )
#define atof(str) atof_internal( str, &b_error )
#define CHECKED_ERROR_PARAM_STRDUP( var, param, src )\
do {\
    var = x264_param_strdup( param, src );\
    if( !var )\
    {\
        b_error = 1;\
        errortype = X264_PARAM_ALLOC_FAILED;\
    }\
} while( 0 )

REALIGN_STACK int x264_param_parse( x264_param_t *p, const char *name, const char *value )
{
    char *name_buf = NULL;
    int b_error = 0;
    int errortype = X264_PARAM_BAD_VALUE;
    int name_was_bool;
    int value_was_null = !value;

    if( !name )
        return X264_PARAM_BAD_NAME;
    if( !value )
        value = "true";

    if( value[0] == '=' )
        value++;

    if( strchr( name, '_' ) ) // s/_/-/g
    {
        char *c;
        name_buf = strdup(name);
        if( !name_buf )
            return X264_PARAM_ALLOC_FAILED;
        while( (c = strchr( name_buf, '_' )) )
            *c = '-';
        name = name_buf;
    }

    if( !strncmp( name, "no", 2 ) )
    {
        name += 2;
        if( name[0] == '-' )
            name++;
        value = atobool(value) ? "false" : "true";
    }
    name_was_bool = 0;

#define OPT(STR) else if( !strcmp( name, STR ) )
#define OPT2(STR0, STR1) else if( !strcmp( name, STR0 ) || !strcmp( name, STR1 ) )
    if( 0 );
    OPT("asm")
    {
        p->cpu = isdigit(value[0]) ? (uint32_t)atoi(value) :
                 !strcasecmp(value, "auto") || atobool(value) ? x264_cpu_detect() : 0;
        if( b_error )
        {
            char *buf = strdup( value );
            if( buf )
            {
                char *tok, UNUSED *saveptr=NULL, *init;
                b_error = 0;
                p->cpu = 0;
                for( init=buf; (tok=strtok_r(init, ",", &saveptr)); init=NULL )
                {
                    int i = 0;
                    while( x264_cpu_names[i].flags && strcasecmp(tok, x264_cpu_names[i].name) )
                        i++;
                    p->cpu |= x264_cpu_names[i].flags;
                    if( !x264_cpu_names[i].flags )
                        b_error = 1;
                }
                free( buf );
                if( (p->cpu&X264_CPU_SSSE3) && !(p->cpu&X264_CPU_SSE2_IS_SLOW) )
                    p->cpu |= X264_CPU_SSE2_IS_FAST;
            }
            else
                errortype = X264_PARAM_ALLOC_FAILED;
        }
    }
    OPT("threads")
    {
        if( !strcasecmp(value, "auto") )
            p->i_threads = X264_THREADS_AUTO;
        else
            p->i_threads = atoi(value);
    }
    OPT("lookahead-threads")
    {
        if( !strcasecmp(value, "auto") )
            p->i_lookahead_threads = X264_THREADS_AUTO;
        else
            p->i_lookahead_threads = atoi(value);
    }
    OPT("sliced-threads")
        p->b_sliced_threads = atobool(value);
    OPT("sync-lookahead")
    {
        if( !strcasecmp(value, "auto") )
            p->i_sync_lookahead = X264_SYNC_LOOKAHEAD_AUTO;
        else
            p->i_sync_lookahead = atoi(value);
    }
    OPT2("deterministic", "n-deterministic")
        p->b_deterministic = atobool(value);
    OPT("cpu-independent")
        p->b_cpu_independent = atobool(value);
    OPT2("level", "level-idc")
    {
        if( !strcmp(value, "1b") )
            p->i_level_idc = 9;
        else if( atof(value) < 7 )
            p->i_level_idc = (int)(10*atof(value)+.5);
        else
            p->i_level_idc = atoi(value);
    }
    OPT("bluray-compat")
        p->b_bluray_compat = atobool(value);
    OPT("avcintra-class")
        p->i_avcintra_class = atoi(value);
    OPT("avcintra-flavor")
        b_error |= parse_enum( value, x264_avcintra_flavor_names, &p->i_avcintra_flavor );
    OPT("sar")
    {
        b_error = ( 2 != sscanf( value, "%d:%d", &p->vui.i_sar_width, &p->vui.i_sar_height ) &&
                    2 != sscanf( value, "%d/%d", &p->vui.i_sar_width, &p->vui.i_sar_height ) );
    }
    OPT("overscan")
        b_error |= parse_enum( value, x264_overscan_names, &p->vui.i_overscan );
    OPT("videoformat")
        b_error |= parse_enum( value, x264_vidformat_names, &p->vui.i_vidformat );
    OPT("fullrange")
        b_error |= parse_enum( value, x264_fullrange_names, &p->vui.b_fullrange );
    OPT("colorprim")
        b_error |= parse_enum( value, x264_colorprim_names, &p->vui.i_colorprim );
    OPT("transfer")
        b_error |= parse_enum( value, x264_transfer_names, &p->vui.i_transfer );
    OPT("colormatrix")
        b_error |= parse_enum( value, x264_colmatrix_names, &p->vui.i_colmatrix );
    OPT("chromaloc")
    {
        p->vui.i_chroma_loc = atoi(value);
        b_error = ( p->vui.i_chroma_loc < 0 || p->vui.i_chroma_loc > 5 );
    }
    OPT("mastering-display")
    {
        if( strcasecmp( value, "undef" ) )
        {
            b_error |= sscanf( value, "G(%d,%d)B(%d,%d)R(%d,%d)WP(%d,%d)L(%"SCNd64",%"SCNd64")",
                               &p->mastering_display.i_green_x, &p->mastering_display.i_green_y,
                               &p->mastering_display.i_blue_x, &p->mastering_display.i_blue_y,
                               &p->mastering_display.i_red_x, &p->mastering_display.i_red_y,
                               &p->mastering_display.i_white_x, &p->mastering_display.i_white_y,
                               &p->mastering_display.i_display_max, &p->mastering_display.i_display_min ) != 10;
            p->mastering_display.b_mastering_display = !b_error;
        }
        else
            p->mastering_display.b_mastering_display = 0;
    }
    OPT("cll")
    {
        if( strcasecmp( value, "undef" ) )
        {
            b_error |= sscanf( value, "%d,%d",
                               &p->content_light_level.i_max_cll, &p->content_light_level.i_max_fall ) != 2;
            p->content_light_level.b_cll = !b_error;
        }
        else
            p->content_light_level.b_cll = 0;
    }
    OPT("alternative-transfer")
        b_error |= parse_enum( value, x264_transfer_names, &p->i_alternative_transfer );
    OPT("fps")
    {
        if( sscanf( value, "%u/%u", &p->i_fps_num, &p->i_fps_den ) != 2 )
        {
            double fps = atof(value);
            if( fps > 0.0 && fps <= INT_MAX/1000.0 )
            {
                p->i_fps_num = (int)(fps * 1000.0 + .5);
                p->i_fps_den = 1000;
            }
            else
            {
                p->i_fps_num = atoi(value);
                p->i_fps_den = 1;
            }
        }
    }
    OPT2("ref", "frameref")
        p->i_frame_reference = atoi(value);
    OPT("dpb-size")
        p->i_dpb_size = atoi(value);
    OPT("keyint")
    {
        if( strstr( value, "infinite" ) )
            p->i_keyint_max = X264_KEYINT_MAX_INFINITE;
        else
            p->i_keyint_max = atoi(value);
    }
    OPT2("min-keyint", "keyint-min")
    {
        p->i_keyint_min = atoi(value);
        if( p->i_keyint_max < p->i_keyint_min )
            p->i_keyint_max = p->i_keyint_min;
    }
    OPT("scenecut")
    {
        p->i_scenecut_threshold = atobool(value);
        if( b_error || p->i_scenecut_threshold )
        {
            b_error = 0;
            p->i_scenecut_threshold = atoi(value);
        }
    }
    OPT("intra-refresh")
        p->b_intra_refresh = atobool(value);
    OPT("bframes")
        p->i_bframe = atoi(value);
    OPT("b-adapt")
    {
        p->i_bframe_adaptive = atobool(value);
        if( b_error )
        {
            b_error = 0;
            p->i_bframe_adaptive = atoi(value);
        }
    }
    OPT("b-bias")
        p->i_bframe_bias = atoi(value);
    OPT("b-pyramid")
    {
        b_error |= parse_enum( value, x264_b_pyramid_names, &p->i_bframe_pyramid );
        if( b_error )
        {
            b_error = 0;
            p->i_bframe_pyramid = atoi(value);
        }
    }
    OPT("open-gop")
        p->b_open_gop = atobool(value);
    OPT("nf")
        p->b_deblocking_filter = !atobool(value);
    OPT2("filter", "deblock")
    {
        if( 2 == sscanf( value, "%d:%d", &p->i_deblocking_filter_alphac0, &p->i_deblocking_filter_beta ) ||
            2 == sscanf( value, "%d,%d", &p->i_deblocking_filter_alphac0, &p->i_deblocking_filter_beta ) )
        {
            p->b_deblocking_filter = 1;
        }
        else if( sscanf( value, "%d", &p->i_deblocking_filter_alphac0 ) )
        {
            p->b_deblocking_filter = 1;
            p->i_deblocking_filter_beta = p->i_deblocking_filter_alphac0;
        }
        else
            p->b_deblocking_filter = atobool(value);
    }
    OPT("slice-max-size")
        p->i_slice_max_size = atoi(value);
    OPT("slice-max-mbs")
        p->i_slice_max_mbs = atoi(value);
    OPT("slice-min-mbs")
        p->i_slice_min_mbs = atoi(value);
    OPT("slices")
        p->i_slice_count = atoi(value);
    OPT("slices-max")
        p->i_slice_count_max = atoi(value);
    OPT("cabac")
        p->b_cabac = atobool(value);
    OPT("cabac-idc")
        p->i_cabac_init_idc = atoi(value);
    OPT("interlaced")
        p->b_interlaced = atobool(value);
    OPT("tff")
        p->b_interlaced = p->b_tff = atobool(value);
    OPT("bff")
    {
        p->b_interlaced = atobool(value);
        p->b_tff = !p->b_interlaced;
    }
    OPT("constrained-intra")
        p->b_constrained_intra = atobool(value);
    OPT("cqm")
    {
        if( strstr( value, "flat" ) )
            p->i_cqm_preset = X264_CQM_FLAT;
        else if( strstr( value, "jvt" ) )
            p->i_cqm_preset = X264_CQM_JVT;
        else
            CHECKED_ERROR_PARAM_STRDUP( p->psz_cqm_file, p, value );
    }
    OPT("cqmfile")
        CHECKED_ERROR_PARAM_STRDUP( p->psz_cqm_file, p, value );
    OPT("cqm4")
    {
        p->i_cqm_preset = X264_CQM_CUSTOM;
        b_error |= parse_cqm( value, p->cqm_4iy, 16 );
        b_error |= parse_cqm( value, p->cqm_4py, 16 );
        b_error |= parse_cqm( value, p->cqm_4ic, 16 );
        b_error |= parse_cqm( value, p->cqm_4pc, 16 );
    }
    OPT("cqm8")
    {
        p->i_cqm_preset = X264_CQM_CUSTOM;
        b_error |= parse_cqm( value, p->cqm_8iy, 64 );
        b_error |= parse_cqm( value, p->cqm_8py, 64 );
        b_error |= parse_cqm( value, p->cqm_8ic, 64 );
        b_error |= parse_cqm( value, p->cqm_8pc, 64 );
    }
    OPT("cqm4i")
    {
        p->i_cqm_preset = X264_CQM_CUSTOM;
        b_error |= parse_cqm( value, p->cqm_4iy, 16 );
        b_error |= parse_cqm( value, p->cqm_4ic, 16 );
    }
    OPT("cqm4p")
    {
        p->i_cqm_preset = X264_CQM_CUSTOM;
        b_error |= parse_cqm( value, p->cqm_4py, 16 );
        b_error |= parse_cqm( value, p->cqm_4pc, 16 );
    }
    OPT("cqm4iy")
    {
        p->i_cqm_preset = X264_CQM_CUSTOM;
        b_error |= parse_cqm( value, p->cqm_4iy, 16 );
    }
    OPT("cqm4ic")
    {
        p->i_cqm_preset = X264_CQM_CUSTOM;
        b_error |= parse_cqm( value, p->cqm_4ic, 16 );
    }
    OPT("cqm4py")
    {
        p->i_cqm_preset = X264_CQM_CUSTOM;
        b_error |= parse_cqm( value, p->cqm_4py, 16 );
    }
    OPT("cqm4pc")
    {
        p->i_cqm_preset = X264_CQM_CUSTOM;
        b_error |= parse_cqm( value, p->cqm_4pc, 16 );
    }
    OPT("cqm8i")
    {
        p->i_cqm_preset = X264_CQM_CUSTOM;
        b_error |= parse_cqm( value, p->cqm_8iy, 64 );
        b_error |= parse_cqm( value, p->cqm_8ic, 64 );
    }
    OPT("cqm8p")
    {
        p->i_cqm_preset = X264_CQM_CUSTOM;
        b_error |= parse_cqm( value, p->cqm_8py, 64 );
        b_error |= parse_cqm( value, p->cqm_8pc, 64 );
    }
    OPT("log")
        p->i_log_level = atoi(value);
    OPT("dump-yuv")
        CHECKED_ERROR_PARAM_STRDUP( p->psz_dump_yuv, p, value );
    OPT2("analyse", "partitions")
    {
        p->analyse.inter = 0;
        if( strstr( value, "none" ) )  p->analyse.inter =  0;
        if( strstr( value, "all" ) )   p->analyse.inter = ~0;

        if( strstr( value, "i4x4" ) )  p->analyse.inter |= X264_ANALYSE_I4x4;
        if( strstr( value, "i8x8" ) )  p->analyse.inter |= X264_ANALYSE_I8x8;
        if( strstr( value, "p8x8" ) )  p->analyse.inter |= X264_ANALYSE_PSUB16x16;
        if( strstr( value, "p4x4" ) )  p->analyse.inter |= X264_ANALYSE_PSUB8x8;
        if( strstr( value, "b8x8" ) )  p->analyse.inter |= X264_ANALYSE_BSUB16x16;
    }
    OPT("8x8dct")
        p->analyse.b_transform_8x8 = atobool(value);
    OPT2("weightb", "weight-b")
        p->analyse.b_weighted_bipred = atobool(value);
    OPT("weightp")
        p->analyse.i_weighted_pred = atoi(value);
    OPT2("direct", "direct-pred")
        b_error |= parse_enum( value, x264_direct_pred_names, &p->analyse.i_direct_mv_pred );
    OPT("chroma-qp-offset")
        p->analyse.i_chroma_qp_offset = atoi(value);
    OPT("me")
        b_error |= parse_enum( value, x264_motion_est_names, &p->analyse.i_me_method );
    OPT2("merange", "me-range")
        p->analyse.i_me_range = atoi(value);
    OPT2("mvrange", "mv-range")
        p->analyse.i_mv_range = atoi(value);
    OPT2("mvrange-thread", "mv-range-thread")
        p->analyse.i_mv_range_thread = atoi(value);
    OPT2("subme", "subq")
        p->analyse.i_subpel_refine = atoi(value);
    OPT("psy-rd")
    {
        if( 2 == sscanf( value, "%f:%f", &p->analyse.f_psy_rd, &p->analyse.f_psy_trellis ) ||
            2 == sscanf( value, "%f,%f", &p->analyse.f_psy_rd, &p->analyse.f_psy_trellis ) ||
            2 == sscanf( value, "%f|%f", &p->analyse.f_psy_rd, &p->analyse.f_psy_trellis ))
        { }
        else if( sscanf( value, "%f", &p->analyse.f_psy_rd ) )
        {
            p->analyse.f_psy_trellis = 0;
        }
        else
        {
            p->analyse.f_psy_rd = 0;
            p->analyse.f_psy_trellis = 0;
        }
    }
    OPT("psy")
        p->analyse.b_psy = atobool(value);
    OPT("chroma-me")
        p->analyse.b_chroma_me = atobool(value);
    OPT("mixed-refs")
        p->analyse.b_mixed_references = atobool(value);
    OPT("trellis")
        p->analyse.i_trellis = atoi(value);
    OPT("fast-pskip")
        p->analyse.b_fast_pskip = atobool(value);
    OPT("dct-decimate")
        p->analyse.b_dct_decimate = atobool(value);
    OPT("deadzone-inter")
        p->analyse.i_luma_deadzone[0] = atoi(value);
    OPT("deadzone-intra")
        p->analyse.i_luma_deadzone[1] = atoi(value);
    OPT("nr")
        p->analyse.i_noise_reduction = atoi(value);
    OPT("bitrate")
    {
        p->rc.i_bitrate = atoi(value);
        p->rc.i_rc_method = X264_RC_ABR;
    }
    OPT2("qp", "qp_constant")
    {
        p->rc.i_qp_constant = atoi(value);
        p->rc.i_rc_method = X264_RC_CQP;
    }
    OPT("crf")
    {
        p->rc.f_rf_constant = atof(value);
        p->rc.i_rc_method = X264_RC_CRF;
    }
    OPT("crf-max")
        p->rc.f_rf_constant_max = atof(value);
    OPT("rc-lookahead")
        p->rc.i_lookahead = atoi(value);
    OPT2("qpmin", "qp-min")
        p->rc.i_qp_min = atoi(value);
    OPT2("qpmax", "qp-max")
        p->rc.i_qp_max = atoi(value);
    OPT2("qpstep", "qp-step")
        p->rc.i_qp_step = atoi(value);
    OPT("ratetol")
        p->rc.f_rate_tolerance = !strncmp("inf", value, 3) ? 1e9 : atof(value);
    OPT("vbv-maxrate")
        p->rc.i_vbv_max_bitrate = atoi(value);
    OPT("vbv-bufsize")
        p->rc.i_vbv_buffer_size = atoi(value);
    OPT("vbv-init")
        p->rc.f_vbv_buffer_init = atof(value);
    OPT2("ipratio", "ip-factor")
        p->rc.f_ip_factor = atof(value);
    OPT2("pbratio", "pb-factor")
        p->rc.f_pb_factor = atof(value);
    OPT("aq-mode")
        p->rc.i_aq_mode = atoi(value);
    OPT("aq-strength")
        p->rc.f_aq_strength = atof(value);
    OPT("pass")
    {
        int pass = x264_clip3( atoi(value), 0, 3 );
        p->rc.b_stat_write = pass & 1;
        p->rc.b_stat_read = pass & 2;
    }
    OPT("stats")
    {
        CHECKED_ERROR_PARAM_STRDUP( p->rc.psz_stat_in, p, value );
        CHECKED_ERROR_PARAM_STRDUP( p->rc.psz_stat_out, p, value );
    }
    OPT("qcomp")
        p->rc.f_qcompress = atof(value);
    OPT("mbtree")
        p->rc.b_mb_tree = atobool(value);
    OPT("qblur")
        p->rc.f_qblur = atof(value);
    OPT2("cplxblur", "cplx-blur")
        p->rc.f_complexity_blur = atof(value);
    OPT("zones")
        CHECKED_ERROR_PARAM_STRDUP( p->rc.psz_zones, p, value );
    OPT("crop-rect")
        b_error |= sscanf( value, "%d,%d,%d,%d", &p->crop_rect.i_left, &p->crop_rect.i_top,
                                                 &p->crop_rect.i_right, &p->crop_rect.i_bottom ) != 4;
    OPT("psnr")
        p->analyse.b_psnr = atobool(value);
    OPT("ssim")
        p->analyse.b_ssim = atobool(value);
    OPT("aud")
        p->b_aud = atobool(value);
    OPT("sps-id")
        p->i_sps_id = atoi(value);
    OPT("global-header")
        p->b_repeat_headers = !atobool(value);
    OPT("repeat-headers")
        p->b_repeat_headers = atobool(value);
    OPT("annexb")
        p->b_annexb = atobool(value);
    OPT("force-cfr")
        p->b_vfr_input = !atobool(value);
    OPT("nal-hrd")
        b_error |= parse_enum( value, x264_nal_hrd_names, &p->i_nal_hrd );
    OPT("filler")
        p->rc.b_filler = atobool(value);
    OPT("pic-struct")
        p->b_pic_struct = atobool(value);
    OPT("fake-interlaced")
        p->b_fake_interlaced = atobool(value);
    OPT("frame-packing")
        p->i_frame_packing = atoi(value);
    OPT("stitchable")
        p->b_stitchable = atobool(value);
    OPT("opencl")
        p->b_opencl = atobool( value );
    OPT("opencl-clbin")
        CHECKED_ERROR_PARAM_STRDUP( p->psz_clbin_file, p, value );
    OPT("opencl-device")
        p->i_opencl_device = atoi( value );
    else
    {
        b_error = 1;
        errortype = X264_PARAM_BAD_NAME;
    }
#undef OPT
#undef OPT2
#undef atobool
#undef atoi
#undef atof

    if( name_buf )
        free( name_buf );

    b_error |= value_was_null && !name_was_bool;
    return b_error ? errortype : 0;
}

/****************************************************************************
 * x264_param2string:
 ****************************************************************************/
char *x264_param2string( x264_param_t *p, int b_res )
{
    int len = 2000;
    char *buf, *s;
    if( p->rc.psz_zones )
        len += strlen(p->rc.psz_zones);
    buf = s = x264_malloc( len );
    if( !buf )
        return NULL;

    if( b_res )
    {
        s += sprintf( s, "%dx%d ", p->i_width, p->i_height );
        s += sprintf( s, "fps=%u/%u ", p->i_fps_num, p->i_fps_den );
        s += sprintf( s, "timebase=%u/%u ", p->i_timebase_num, p->i_timebase_den );
        s += sprintf( s, "bitdepth=%d ", p->i_bitdepth );
    }

    if( p->b_opencl )
        s += sprintf( s, "opencl=%d ", p->b_opencl );
    s += sprintf( s, "cabac=%d", p->b_cabac );
    s += sprintf( s, " ref=%d", p->i_frame_reference );
    s += sprintf( s, " deblock=%d:%d:%d", p->b_deblocking_filter,
                  p->i_deblocking_filter_alphac0, p->i_deblocking_filter_beta );
    s += sprintf( s, " analyse=%#x:%#x", p->analyse.intra, p->analyse.inter );
    s += sprintf( s, " me=%s", x264_motion_est_names[ p->analyse.i_me_method ] );
    s += sprintf( s, " subme=%d", p->analyse.i_subpel_refine );
    s += sprintf( s, " psy=%d", p->analyse.b_psy );
    if( p->analyse.b_psy )
        s += sprintf( s, " psy_rd=%.2f:%.2f", p->analyse.f_psy_rd, p->analyse.f_psy_trellis );
    s += sprintf( s, " mixed_ref=%d", p->analyse.b_mixed_references );
    s += sprintf( s, " me_range=%d", p->analyse.i_me_range );
    s += sprintf( s, " chroma_me=%d", p->analyse.b_chroma_me );
    s += sprintf( s, " trellis=%d", p->analyse.i_trellis );
    s += sprintf( s, " 8x8dct=%d", p->analyse.b_transform_8x8 );
    s += sprintf( s, " cqm=%d", p->i_cqm_preset );
    s += sprintf( s, " deadzone=%d,%d", p->analyse.i_luma_deadzone[0], p->analyse.i_luma_deadzone[1] );
    s += sprintf( s, " fast_pskip=%d", p->analyse.b_fast_pskip );
    s += sprintf( s, " chroma_qp_offset=%d", p->analyse.i_chroma_qp_offset );
    s += sprintf( s, " threads=%d", p->i_threads );
    s += sprintf( s, " lookahead_threads=%d", p->i_lookahead_threads );
    s += sprintf( s, " sliced_threads=%d", p->b_sliced_threads );
    if( p->i_slice_count )
        s += sprintf( s, " slices=%d", p->i_slice_count );
    if( p->i_slice_count_max )
        s += sprintf( s, " slices_max=%d", p->i_slice_count_max );
    if( p->i_slice_max_size )
        s += sprintf( s, " slice_max_size=%d", p->i_slice_max_size );
    if( p->i_slice_max_mbs )
        s += sprintf( s, " slice_max_mbs=%d", p->i_slice_max_mbs );
    if( p->i_slice_min_mbs )
        s += sprintf( s, " slice_min_mbs=%d", p->i_slice_min_mbs );
    s += sprintf( s, " nr=%d", p->analyse.i_noise_reduction );
    s += sprintf( s, " decimate=%d", p->analyse.b_dct_decimate );
    s += sprintf( s, " interlaced=%s", p->b_interlaced ? p->b_tff ? "tff" : "bff" : p->b_fake_interlaced ? "fake" : "0" );
    s += sprintf( s, " bluray_compat=%d", p->b_bluray_compat );
    if( p->b_stitchable )
        s += sprintf( s, " stitchable=%d", p->b_stitchable );

    s += sprintf( s, " constrained_intra=%d", p->b_constrained_intra );

    s += sprintf( s, " bframes=%d", p->i_bframe );
    if( p->i_bframe )
    {
        s += sprintf( s, " b_pyramid=%d b_adapt=%d b_bias=%d direct=%d weightb=%d open_gop=%d",
                      p->i_bframe_pyramid, p->i_bframe_adaptive, p->i_bframe_bias,
                      p->analyse.i_direct_mv_pred, p->analyse.b_weighted_bipred, p->b_open_gop );
    }
    s += sprintf( s, " weightp=%d", p->analyse.i_weighted_pred > 0 ? p->analyse.i_weighted_pred : 0 );

    if( p->i_keyint_max == X264_KEYINT_MAX_INFINITE )
        s += sprintf( s, " keyint=infinite" );
    else
        s += sprintf( s, " keyint=%d", p->i_keyint_max );
    s += sprintf( s, " keyint_min=%d scenecut=%d intra_refresh=%d",
                  p->i_keyint_min, p->i_scenecut_threshold, p->b_intra_refresh );

    if( p->rc.b_mb_tree || p->rc.i_vbv_buffer_size )
        s += sprintf( s, " rc_lookahead=%d", p->rc.i_lookahead );

    s += sprintf( s, " rc=%s mbtree=%d", p->rc.i_rc_method == X264_RC_ABR ?
                               ( p->rc.b_stat_read ? "2pass" : p->rc.i_vbv_max_bitrate == p->rc.i_bitrate ? "cbr" : "abr" )
                               : p->rc.i_rc_method == X264_RC_CRF ? "crf" : "cqp", p->rc.b_mb_tree );
    if( p->rc.i_rc_method == X264_RC_ABR || p->rc.i_rc_method == X264_RC_CRF )
    {
        if( p->rc.i_rc_method == X264_RC_CRF )
            s += sprintf( s, " crf=%.1f", p->rc.f_rf_constant );
        else
            s += sprintf( s, " bitrate=%d ratetol=%.1f",
                          p->rc.i_bitrate, p->rc.f_rate_tolerance );
        s += sprintf( s, " qcomp=%.2f qpmin=%d qpmax=%d qpstep=%d",
                      p->rc.f_qcompress, p->rc.i_qp_min, p->rc.i_qp_max, p->rc.i_qp_step );
        if( p->rc.b_stat_read )
            s += sprintf( s, " cplxblur=%.1f qblur=%.1f",
                          p->rc.f_complexity_blur, p->rc.f_qblur );
        if( p->rc.i_vbv_buffer_size )
        {
            s += sprintf( s, " vbv_maxrate=%d vbv_bufsize=%d",
                          p->rc.i_vbv_max_bitrate, p->rc.i_vbv_buffer_size );
            if( p->rc.i_rc_method == X264_RC_CRF )
                s += sprintf( s, " crf_max=%.1f", p->rc.f_rf_constant_max );
        }
    }
    else if( p->rc.i_rc_method == X264_RC_CQP )
        s += sprintf( s, " qp=%d", p->rc.i_qp_constant );

    if( p->rc.i_vbv_buffer_size )
        s += sprintf( s, " nal_hrd=%s filler=%d", x264_nal_hrd_names[p->i_nal_hrd], p->rc.b_filler );
    if( p->crop_rect.i_left | p->crop_rect.i_top | p->crop_rect.i_right | p->crop_rect.i_bottom )
        s += sprintf( s, " crop_rect=%d,%d,%d,%d", p->crop_rect.i_left, p->crop_rect.i_top,
                                                   p->crop_rect.i_right, p->crop_rect.i_bottom );
    if( p->mastering_display.b_mastering_display )
        s += sprintf( s, " mastering-display=G(%d,%d)B(%d,%d)R(%d,%d)WP(%d,%d)L(%"PRId64",%"PRId64")",
                      p->mastering_display.i_green_x, p->mastering_display.i_green_y,
                      p->mastering_display.i_blue_x, p->mastering_display.i_blue_y,
                      p->mastering_display.i_red_x, p->mastering_display.i_red_y,
                      p->mastering_display.i_white_x, p->mastering_display.i_white_y,
                      p->mastering_display.i_display_max, p->mastering_display.i_display_min );
    if( p->content_light_level.b_cll )
        s += sprintf( s, " cll=%d,%d",
                      p->content_light_level.i_max_cll, p->content_light_level.i_max_fall );
    if( p->i_frame_packing >= 0 )
        s += sprintf( s, " frame-packing=%d", p->i_frame_packing );

    if( !(p->rc.i_rc_method == X264_RC_CQP && p->rc.i_qp_constant == 0) )
    {
        s += sprintf( s, " ip_ratio=%.2f", p->rc.f_ip_factor );
        if( p->i_bframe && !p->rc.b_mb_tree )
            s += sprintf( s, " pb_ratio=%.2f", p->rc.f_pb_factor );
        s += sprintf( s, " aq=%d", p->rc.i_aq_mode );
        if( p->rc.i_aq_mode )
            s += sprintf( s, ":%.2f", p->rc.f_aq_strength );
        if( p->rc.psz_zones )
            s += sprintf( s, " zones=%s", p->rc.psz_zones );
        else if( p->rc.i_zones )
            s += sprintf( s, " zones" );
    }

    return buf;
}
