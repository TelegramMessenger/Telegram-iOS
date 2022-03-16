/*****************************************************************************
 * resize.c: resize video filter
 *****************************************************************************
 * Copyright (C) 2010-2022 x264 project
 *
 * Authors: Steven Walters <kemuri9@gmail.com>
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

#include "video.h"

#define NAME "resize"
#define FAIL_IF_ERROR( cond, ... ) FAIL_IF_ERR( cond, NAME, __VA_ARGS__ )

cli_vid_filter_t resize_filter;

static int full_check( video_info_t *info, x264_param_t *param )
{
    int required = 0;
    required |= info->csp       != param->i_csp;
    required |= info->width     != param->i_width;
    required |= info->height    != param->i_height;
    required |= info->fullrange != param->vui.b_fullrange;
    return required;
}

#if HAVE_SWSCALE
#undef DECLARE_ALIGNED
#include <libswscale/swscale.h>
#include <libavutil/opt.h>
#include <libavutil/pixdesc.h>

#ifndef AV_PIX_FMT_BGRA64
#define AV_PIX_FMT_BGRA64 AV_PIX_FMT_NONE
#endif

typedef struct
{
    int width;
    int height;
    int pix_fmt;
    int range;
} frame_prop_t;

typedef struct
{
    hnd_t prev_hnd;
    cli_vid_filter_t prev_filter;

    cli_pic_t buffer;
    int buffer_allocated;
    int dst_csp;
    int input_range;
    struct SwsContext *ctx;
    uint32_t ctx_flags;
    /* state of swapping chroma planes pre and post resize */
    int pre_swap_chroma;
    int post_swap_chroma;
    int fast_mono;      /* yuv with planar luma can be "converted" to monochrome by simply ignoring chroma */
    int variable_input; /* input is capable of changing properties */
    int working;        /* we have already started working with frames */
    frame_prop_t dst;   /* desired output properties */
    frame_prop_t scale; /* properties of the SwsContext input */
} resizer_hnd_t;

static void help( int longhelp )
{
    printf( "      "NAME":[width,height][,sar][,fittobox][,csp][,method]\n" );
    if( !longhelp )
        return;
    printf( "            resizes frames based on the given criteria:\n"
            "            - resolution only: resizes and adapts sar to avoid stretching\n"
            "            - sar only: sets the sar and resizes to avoid stretching\n"
            "            - resolution and sar: resizes to given resolution and sets the sar\n"
            "            - fittobox: resizes the video based on the desired constraints\n"
            "               - width, height, both\n"
            "            - fittobox and sar: same as above except with specified sar\n"
            "            - csp: convert to the given csp. syntax: [name][:depth]\n"
            "               - valid csp names [keep current]: " );

    for( int i = X264_CSP_NONE+1; i < X264_CSP_CLI_MAX; i++ )
    {
        if( x264_cli_csps[i].name )
        {
            printf( "%s", x264_cli_csps[i].name );
            if( i+1 < X264_CSP_CLI_MAX )
                printf( ", " );
        }
    }
    printf( "\n"
            "               - depth: 8 or 16 bits per pixel [keep current]\n"
            "            note: not all depths are supported by all csps.\n"
            "            - method: use resizer method [\"bicubic\"]\n"
            "               - fastbilinear, bilinear, bicubic, experimental, point,\n"
            "               - area, bicublin, gauss, sinc, lanczos, spline\n" );
}

static uint32_t convert_method_to_flag( const char *name )
{
    uint32_t flag = 0;
    if( !strcasecmp( name, "fastbilinear" ) )
        flag = SWS_FAST_BILINEAR;
    else if( !strcasecmp( name, "bilinear" ) )
        flag = SWS_BILINEAR;
    else if( !strcasecmp( name, "bicubic" ) )
        flag = SWS_BICUBIC;
    else if( !strcasecmp( name, "experimental" ) )
        flag = SWS_X;
    else if( !strcasecmp( name, "point" ) )
        flag = SWS_POINT;
    else if( !strcasecmp( name, "area" ) )
        flag = SWS_AREA;
    else if( !strcasecmp( name, "bicublin" ) )
        flag = SWS_BICUBLIN;
    else if( !strcasecmp( name, "gauss" ) )
        flag = SWS_GAUSS;
    else if( !strcasecmp( name, "sinc" ) )
        flag = SWS_SINC;
    else if( !strcasecmp( name, "lanczos" ) )
        flag = SWS_LANCZOS;
    else if( !strcasecmp( name, "spline" ) )
        flag = SWS_SPLINE;
    else // default
        flag = SWS_BICUBIC;
    return flag;
}

static int convert_csp_to_pix_fmt( int csp )
{
    if( csp&X264_CSP_OTHER )
        return csp&X264_CSP_MASK;
    switch( csp&X264_CSP_MASK )
    {
        case X264_CSP_I400: return csp&X264_CSP_HIGH_DEPTH ? AV_PIX_FMT_GRAY16    : AV_PIX_FMT_GRAY8;
        case X264_CSP_YV12: /* specially handled via swapping chroma */
        case X264_CSP_I420: return csp&X264_CSP_HIGH_DEPTH ? AV_PIX_FMT_YUV420P16 : AV_PIX_FMT_YUV420P;
        case X264_CSP_YV16: /* specially handled via swapping chroma */
        case X264_CSP_I422: return csp&X264_CSP_HIGH_DEPTH ? AV_PIX_FMT_YUV422P16 : AV_PIX_FMT_YUV422P;
        case X264_CSP_YV24: /* specially handled via swapping chroma */
        case X264_CSP_I444: return csp&X264_CSP_HIGH_DEPTH ? AV_PIX_FMT_YUV444P16 : AV_PIX_FMT_YUV444P;
        case X264_CSP_RGB:  return csp&X264_CSP_HIGH_DEPTH ? AV_PIX_FMT_RGB48     : AV_PIX_FMT_RGB24;
        case X264_CSP_BGR:  return csp&X264_CSP_HIGH_DEPTH ? AV_PIX_FMT_BGR48     : AV_PIX_FMT_BGR24;
        case X264_CSP_BGRA: return csp&X264_CSP_HIGH_DEPTH ? AV_PIX_FMT_BGRA64    : AV_PIX_FMT_BGRA;
        /* the following has no equivalent 16-bit depth in swscale */
        case X264_CSP_NV12: return csp&X264_CSP_HIGH_DEPTH ? AV_PIX_FMT_NONE      : AV_PIX_FMT_NV12;
        case X264_CSP_NV21: return csp&X264_CSP_HIGH_DEPTH ? AV_PIX_FMT_NONE      : AV_PIX_FMT_NV21;
        case X264_CSP_YUYV: return csp&X264_CSP_HIGH_DEPTH ? AV_PIX_FMT_NONE      : AV_PIX_FMT_YUYV422;
        case X264_CSP_UYVY: return csp&X264_CSP_HIGH_DEPTH ? AV_PIX_FMT_NONE      : AV_PIX_FMT_UYVY422;
        /* the following is not supported by swscale at all */
        case X264_CSP_NV16:
        default:            return AV_PIX_FMT_NONE;
    }
}

static int pix_number_of_planes( const AVPixFmtDescriptor *pix_desc )
{
    int num_planes = 0;
    for( int i = 0; i < pix_desc->nb_components; i++ )
    {
        int plane_plus1 = pix_desc->comp[i].plane + 1;
        num_planes = X264_MAX( plane_plus1, num_planes );
    }
    return num_planes;
}

static int pick_closest_supported_csp( int csp )
{
    int pix_fmt = convert_csp_to_pix_fmt( csp );
    // first determine the base csp
    int ret = X264_CSP_NONE;
    const AVPixFmtDescriptor *pix_desc = av_pix_fmt_desc_get( pix_fmt );
    if( !pix_desc || !pix_desc->name )
        return ret;

    const char *pix_fmt_name = pix_desc->name;
    int is_rgb = pix_desc->flags & (AV_PIX_FMT_FLAG_RGB | AV_PIX_FMT_FLAG_PAL);
    int is_bgr = !!strstr( pix_fmt_name, "bgr" );
    if( is_bgr || is_rgb )
    {
        if( pix_desc->nb_components == 4 ) // has alpha
            ret = X264_CSP_BGRA;
        else if( is_bgr )
            ret = X264_CSP_BGR;
        else
            ret = X264_CSP_RGB;
    }
    else
    {
        // yuv-based
        if( pix_desc->nb_components == 1 || pix_desc->nb_components == 2 ) // no chroma
            ret = X264_CSP_I400;
        else if( pix_desc->log2_chroma_w && pix_desc->log2_chroma_h ) // reduced chroma width & height
            ret = (pix_number_of_planes( pix_desc ) == 2) ? X264_CSP_NV12 : X264_CSP_I420;
        else if( pix_desc->log2_chroma_w ) // reduced chroma width only
            ret = X264_CSP_I422; // X264_CSP_NV16 is not supported by swscale so don't use it
        else
            ret = X264_CSP_I444;
    }
    // now determine high depth
    for( int i = 0; i < pix_desc->nb_components; i++ )
        if( pix_desc->comp[i].depth > 8 )
            ret |= X264_CSP_HIGH_DEPTH;
    return ret;
}

static int handle_opts( const char * const *optlist, char **opts, video_info_t *info, resizer_hnd_t *h )
{
    uint32_t out_sar_w, out_sar_h;

    char *str_width  = x264_get_option( optlist[0], opts );
    char *str_height = x264_get_option( optlist[1], opts );
    char *str_sar    = x264_get_option( optlist[2], opts );
    char *fittobox   = x264_get_option( optlist[3], opts );
    char *str_csp    = x264_get_option( optlist[4], opts );
    int width        = x264_otoi( str_width, -1 );
    int height       = x264_otoi( str_height, -1 );

    int csp_only = 0;
    uint32_t in_sar_w = info->sar_width;
    uint32_t in_sar_h = info->sar_height;

    if( str_csp )
    {
        /* output csp was specified, first check if optional depth was provided */
        char *str_depth = strchr( str_csp, ':' );
        int depth = x264_cli_csp_depth_factor( info->csp ) * 8;
        if( str_depth )
        {
            /* csp bit depth was specified */
            *str_depth++ = '\0';
            depth = x264_otoi( str_depth, -1 );
            FAIL_IF_ERROR( depth != 8 && depth != 16, "unsupported bit depth %d\n", depth );
        }
        /* now lookup against the list of valid csps */
        int csp;
        if( strlen( str_csp ) == 0 )
            csp = info->csp & X264_CSP_MASK;
        else
            for( csp = X264_CSP_CLI_MAX-1; csp > X264_CSP_NONE; csp-- )
            {
                if( x264_cli_csps[csp].name && !strcasecmp( x264_cli_csps[csp].name, str_csp ) )
                    break;
            }
        FAIL_IF_ERROR( csp == X264_CSP_NONE, "unsupported colorspace `%s'\n", str_csp );
        h->dst_csp = csp;
        if( depth == 16 )
            h->dst_csp |= X264_CSP_HIGH_DEPTH;
    }

    /* if the input sar is currently invalid, set it to 1:1 so it can be used in math */
    if( !in_sar_w || !in_sar_h )
        in_sar_w = in_sar_h = 1;
    if( str_sar )
    {
        FAIL_IF_ERROR( 2 != sscanf( str_sar, "%u:%u", &out_sar_w, &out_sar_h ) &&
                       2 != sscanf( str_sar, "%u/%u", &out_sar_w, &out_sar_h ),
                       "invalid sar `%s'\n", str_sar );
    }
    else
        out_sar_w = out_sar_h = 1;
    if( fittobox )
    {
        /* resize the video to fit the box as much as possible */
        if( !strcasecmp( fittobox, "both" ) )
        {
            FAIL_IF_ERROR( width <= 0 || height <= 0, "invalid box resolution %sx%s\n",
                           x264_otos( str_width, "<unset>" ), x264_otos( str_height, "<unset>" ) );
        }
        else if( !strcasecmp( fittobox, "width" ) )
        {
            FAIL_IF_ERROR( width <= 0, "invalid box width `%s'\n", x264_otos( str_width, "<unset>" ) );
            height = INT_MAX;
        }
        else if( !strcasecmp( fittobox, "height" ) )
        {
            FAIL_IF_ERROR( height <= 0, "invalid box height `%s'\n", x264_otos( str_height, "<unset>" ) );
            width = INT_MAX;
        }
        else FAIL_IF_ERROR( 1, "invalid fittobox mode `%s'\n", fittobox );

        /* maximally fit the new coded resolution to the box */
        const x264_cli_csp_t *csp = x264_cli_get_csp( h->dst_csp );
        double width_units = (double)info->height * in_sar_h * out_sar_w;
        double height_units = (double)info->width * in_sar_w * out_sar_h;
        width = width / csp->mod_width * csp->mod_width;
        height = height / csp->mod_height * csp->mod_height;
        if( width * width_units > height * height_units )
        {
            int new_width = round( height * height_units / (width_units * csp->mod_width) );
            new_width *= csp->mod_width;
            width = X264_MIN( new_width, width );
        }
        else
        {
            int new_height = round( width * width_units / (height_units * csp->mod_height) );
            new_height *= csp->mod_height;
            height = X264_MIN( new_height, height );
        }
    }
    else
    {
        if( str_width || str_height )
        {
            FAIL_IF_ERROR( width <= 0 || height <= 0, "invalid resolution %sx%s\n",
                           x264_otos( str_width, "<unset>" ), x264_otos( str_height, "<unset>" ) );
            if( !str_sar ) /* res only -> adjust sar */
            {
                /* new_sar = (new_h * old_w * old_sar_w) / (old_h * new_w * old_sar_h) */
                uint64_t num = (uint64_t)info->width  * height;
                uint64_t den = (uint64_t)info->height * width;
                x264_reduce_fraction64( &num, &den );
                out_sar_w = num * in_sar_w;
                out_sar_h = den * in_sar_h;
                x264_reduce_fraction( &out_sar_w, &out_sar_h );
            }
        }
        else if( str_sar ) /* sar only -> adjust res */
        {
             const x264_cli_csp_t *csp = x264_cli_get_csp( h->dst_csp );
             double width_units = (double)in_sar_h * out_sar_w;
             double height_units = (double)in_sar_w * out_sar_h;
             width  = info->width;
             height = info->height;
             if( width_units > height_units ) // SAR got wider, decrease width
             {
                 width = round( info->width * height_units / (width_units * csp->mod_width) );
                 width *= csp->mod_width;
             }
             else // SAR got thinner, decrease height
             {
                 height = round( info->height * width_units / (height_units * csp->mod_height) );
                 height *= csp->mod_height;
             }
        }
        else /* csp only */
        {
            h->dst.width  = info->width;
            h->dst.height = info->height;
            csp_only = 1;
        }
    }
    if( !csp_only )
    {
        info->sar_width  = out_sar_w;
        info->sar_height = out_sar_h;
        h->dst.width  = width;
        h->dst.height = height;
    }
    return 0;
}

static int init_sws_context( resizer_hnd_t *h )
{
    if( h->ctx )
        sws_freeContext( h->ctx );
    h->ctx = sws_alloc_context();
    if( !h->ctx )
        return -1;

    av_opt_set_int( h->ctx, "sws_flags",  h->ctx_flags,   0 );
    av_opt_set_int( h->ctx, "dstw",       h->dst.width,   0 );
    av_opt_set_int( h->ctx, "dsth",       h->dst.height,  0 );
    av_opt_set_int( h->ctx, "dst_format", h->dst.pix_fmt, 0 );
    av_opt_set_int( h->ctx, "dst_range",  h->dst.range,   0 );

    av_opt_set_int( h->ctx, "srcw",       h->scale.width,   0 );
    av_opt_set_int( h->ctx, "srch",       h->scale.height,  0 );
    av_opt_set_int( h->ctx, "src_format", h->scale.pix_fmt, 0 );
    av_opt_set_int( h->ctx, "src_range",  h->scale.range,   0 );

    /* FIXME: use the correct matrix coefficients (only YUV -> RGB conversions are supported) */
    sws_setColorspaceDetails( h->ctx,
                              sws_getCoefficients( SWS_CS_DEFAULT ), h->scale.range,
                              sws_getCoefficients( SWS_CS_DEFAULT ), h->dst.range,
                              0, 1<<16, 1<<16 );

    return sws_init_context( h->ctx, NULL, NULL ) < 0;
}

static int check_resizer( resizer_hnd_t *h, cli_pic_t *in )
{
    frame_prop_t input_prop = { in->img.width, in->img.height, convert_csp_to_pix_fmt( in->img.csp ), h->input_range };
    if( !memcmp( &input_prop, &h->scale, sizeof(frame_prop_t) ) )
        return 0;
    /* also warn if the resizer was initialized after the first frame */
    if( h->ctx || h->working )
    {
        x264_cli_log( NAME, X264_LOG_WARNING, "stream properties changed at pts %"PRId64"\n", in->pts );
        h->fast_mono = 0;
    }
    h->scale = input_prop;
    if( !h->buffer_allocated && !h->fast_mono )
    {
        if( x264_cli_pic_alloc_aligned( &h->buffer, h->dst_csp, h->dst.width, h->dst.height ) )
            return -1;
        h->buffer_allocated = 1;
    }
    FAIL_IF_ERROR( init_sws_context( h ), "swscale init failed\n" );
    return 0;
}

static int init( hnd_t *handle, cli_vid_filter_t *filter, video_info_t *info, x264_param_t *param, char *opt_string )
{
    /* if called for normalizing the csp to known formats and the format is not unknown, exit */
    if( opt_string && !strcmp( opt_string, "normcsp" ) && !(info->csp&X264_CSP_OTHER) )
        return 0;
    /* if called by x264cli and nothing needs to be done, exit */
    if( !opt_string && !full_check( info, param ) )
        return 0;

    static const char * const optlist[] = { "width", "height", "sar", "fittobox", "csp", "method", NULL };
    char **opts = x264_split_options( opt_string, optlist );
    if( !opts && opt_string )
        return -1;

    resizer_hnd_t *h = calloc( 1, sizeof(resizer_hnd_t) );
    if( !h )
        return -1;

    h->ctx_flags = convert_method_to_flag( x264_otos( x264_get_option( optlist[5], opts ), "" ) );

    if( opts )
    {
        h->dst_csp    = info->csp;
        h->dst.width  = info->width;
        h->dst.height = info->height;
        h->dst.range  = info->fullrange; // maintain input range
        if( !strcmp( opt_string, "normcsp" ) )
        {
            free( opts );
            /* only in normalization scenarios is the input capable of changing properties */
            h->variable_input = 1;
            h->dst_csp = pick_closest_supported_csp( info->csp );
            FAIL_IF_ERROR( h->dst_csp == X264_CSP_NONE,
                           "filter get invalid input pixel format %d (colorspace %d)\n", convert_csp_to_pix_fmt( info->csp ), info->csp );
        }
        else
        {
            int err = handle_opts( optlist, opts, info, h );
            free( opts );
            if( err )
                return -1;
        }
    }
    else
    {
        h->dst_csp    = param->i_csp;
        h->dst.width  = param->i_width;
        h->dst.height = param->i_height;
        h->dst.range  = param->vui.b_fullrange; // change to libx264's range
    }

    if( h->ctx_flags != SWS_FAST_BILINEAR )
        h->ctx_flags |= SWS_FULL_CHR_H_INT | SWS_FULL_CHR_H_INP | SWS_ACCURATE_RND;
    h->dst.pix_fmt = convert_csp_to_pix_fmt( h->dst_csp );
    h->scale = h->dst;
    h->input_range = info->fullrange;

    /* swap chroma planes if YV12/YV16/YV24 is involved, as libswscale works with I420/I422/I444 */
    int src_csp = info->csp & (X264_CSP_MASK | X264_CSP_OTHER);
    int dst_csp = h->dst_csp & (X264_CSP_MASK | X264_CSP_OTHER);
    h->pre_swap_chroma  = src_csp == X264_CSP_YV12 || src_csp == X264_CSP_YV16 || src_csp == X264_CSP_YV24;
    h->post_swap_chroma = dst_csp == X264_CSP_YV12 || dst_csp == X264_CSP_YV16 || dst_csp == X264_CSP_YV24;

    int src_pix_fmt = convert_csp_to_pix_fmt( info->csp );

    int src_pix_fmt_inv = convert_csp_to_pix_fmt( info->csp ^ X264_CSP_HIGH_DEPTH );
    int dst_pix_fmt_inv = convert_csp_to_pix_fmt( h->dst_csp ^ X264_CSP_HIGH_DEPTH );

    FAIL_IF_ERROR( h->dst.width <= 0 || h->dst.height <= 0 ||
                   h->dst.width > MAX_RESOLUTION || h->dst.height > MAX_RESOLUTION,
                   "invalid width x height (%dx%d)\n", h->dst.width, h->dst.height );

    /* confirm swscale can support this conversion */
    FAIL_IF_ERROR( src_pix_fmt == AV_PIX_FMT_NONE && src_pix_fmt_inv != AV_PIX_FMT_NONE,
                   "input colorspace %s with bit depth %d is not supported\n", av_get_pix_fmt_name( src_pix_fmt_inv ),
                   info->csp & X264_CSP_HIGH_DEPTH ? 16 : 8 );
    FAIL_IF_ERROR( !sws_isSupportedInput( src_pix_fmt ), "input colorspace %s is not supported\n", av_get_pix_fmt_name( src_pix_fmt ) );
    FAIL_IF_ERROR( h->dst.pix_fmt == AV_PIX_FMT_NONE && dst_pix_fmt_inv != AV_PIX_FMT_NONE,
                   "input colorspace %s with bit depth %d is not supported\n", av_get_pix_fmt_name( dst_pix_fmt_inv ),
                   h->dst_csp & X264_CSP_HIGH_DEPTH ? 16 : 8 );
    FAIL_IF_ERROR( !sws_isSupportedOutput( h->dst.pix_fmt ), "output colorspace %s is not supported\n", av_get_pix_fmt_name( h->dst.pix_fmt ) );
    FAIL_IF_ERROR( h->dst.height != info->height && info->interlaced,
                   "swscale is not compatible with interlaced vertical resizing\n" );
    /* confirm that the desired resolution meets the colorspace requirements */
    const x264_cli_csp_t *csp = x264_cli_get_csp( h->dst_csp );
    FAIL_IF_ERROR( h->dst.width % csp->mod_width || h->dst.height % csp->mod_height,
                   "resolution %dx%d is not compliant with colorspace %s\n", h->dst.width, h->dst.height, csp->name );

    if( h->dst.width != info->width || h->dst.height != info->height )
        x264_cli_log( NAME, X264_LOG_INFO, "resizing to %dx%d\n", h->dst.width, h->dst.height );
    if( h->dst.pix_fmt != src_pix_fmt )
        x264_cli_log( NAME, X264_LOG_WARNING, "converting from %s to %s\n",
                      av_get_pix_fmt_name( src_pix_fmt ), av_get_pix_fmt_name( h->dst.pix_fmt ) );
    else if( h->dst.range != h->input_range )
        x264_cli_log( NAME, X264_LOG_WARNING, "converting range from %s to %s\n",
                      h->input_range ? "PC" : "TV", h->dst.range ? "PC" : "TV" );
    h->dst_csp |= info->csp & X264_CSP_VFLIP; // preserve vflip

    if( dst_csp == X264_CSP_I400 &&
        ((src_csp >= X264_CSP_I420 && src_csp <= X264_CSP_NV16) || src_csp == X264_CSP_I444 || src_csp == X264_CSP_YV24) &&
        h->dst.width == info->width && h->dst.height == info->height && h->dst.range == h->input_range )
        h->fast_mono = 1; /* use the input luma plane as is */

    /* if the input is not variable, initialize the context */
    if( !h->variable_input )
    {
        cli_pic_t input_pic = {{info->csp, info->width, info->height, 0}, 0};
        if( check_resizer( h, &input_pic ) )
            return -1;
    }

    /* finished initing, overwrite values */
    info->csp       = h->dst_csp;
    info->width     = h->dst.width;
    info->height    = h->dst.height;
    info->fullrange = h->dst.range;

    h->prev_filter = *filter;
    h->prev_hnd = *handle;
    *handle = h;
    *filter = resize_filter;

    return 0;
}

static int get_frame( hnd_t handle, cli_pic_t *output, int frame )
{
    resizer_hnd_t *h = handle;
    if( h->prev_filter.get_frame( h->prev_hnd, output, frame ) )
        return -1;
    if( h->variable_input && check_resizer( h, output ) )
        return -1;
    h->working = 1;
    if( h->pre_swap_chroma )
        XCHG( uint8_t*, output->img.plane[1], output->img.plane[2] );
    if( h->ctx && !h->fast_mono )
    {
        sws_scale( h->ctx, (const uint8_t* const*)output->img.plane, output->img.stride,
                   0, output->img.height, h->buffer.img.plane, h->buffer.img.stride );
        output->img = h->buffer.img; /* copy img data */
    }
    else
        output->img.csp = h->dst_csp;
    if( h->post_swap_chroma )
        XCHG( uint8_t*, output->img.plane[1], output->img.plane[2] );

    return 0;
}

static int release_frame( hnd_t handle, cli_pic_t *pic, int frame )
{
    resizer_hnd_t *h = handle;
    return h->prev_filter.release_frame( h->prev_hnd, pic, frame );
}

static void free_filter( hnd_t handle )
{
    resizer_hnd_t *h = handle;
    h->prev_filter.free( h->prev_hnd );
    if( h->ctx )
        sws_freeContext( h->ctx );
    if( h->buffer_allocated )
        x264_cli_pic_clean( &h->buffer );
    free( h );
}

#else /* no swscale */
static int init( hnd_t *handle, cli_vid_filter_t *filter, video_info_t *info, x264_param_t *param, char *opt_string )
{
    int ret = 0;

    if( !opt_string )
        ret = full_check( info, param );
    else
    {
        if( !strcmp( opt_string, "normcsp" ) )
            ret = info->csp & X264_CSP_OTHER;
        else
            ret = -1;
    }

    /* pass if nothing needs to be done, otherwise fail */
    FAIL_IF_ERROR( ret, "not compiled with swscale support\n" );
    return 0;
}

#define help NULL
#define get_frame NULL
#define release_frame NULL
#define free_filter NULL
#define convert_csp_to_pix_fmt(x) (x & X264_CSP_MASK)

#endif

cli_vid_filter_t resize_filter = { NAME, help, init, get_frame, release_frame, free_filter, NULL };
