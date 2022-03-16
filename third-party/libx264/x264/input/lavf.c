/*****************************************************************************
 * lavf.c: libavformat input
 *****************************************************************************
 * Copyright (C) 2009-2022 x264 project
 *
 * Authors: Mike Gurlitz <mike.gurlitz@gmail.com>
 *          Steven Walters <kemuri9@gmail.com>
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

#include "input.h"

#undef DECLARE_ALIGNED
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/dict.h>
#include <libavutil/error.h>
#include <libavutil/mem.h>
#include <libavutil/pixdesc.h>

#define FAIL_IF_ERROR( cond, ... ) FAIL_IF_ERR( cond, "lavf", __VA_ARGS__ )

typedef struct
{
    AVFormatContext *lavf;
    AVCodecContext *lavc;
    AVFrame *frame;
    AVPacket *pkt;
    int stream_id;
    int next_frame;
    int vfr_input;
    cli_pic_t *first_pic;
} lavf_hnd_t;

/* handle the deprecated jpeg pixel formats */
static int handle_jpeg( int csp, int *fullrange )
{
    switch( csp )
    {
        case AV_PIX_FMT_YUVJ420P: *fullrange = 1; return AV_PIX_FMT_YUV420P;
        case AV_PIX_FMT_YUVJ422P: *fullrange = 1; return AV_PIX_FMT_YUV422P;
        case AV_PIX_FMT_YUVJ444P: *fullrange = 1; return AV_PIX_FMT_YUV444P;
        default:                               return csp;
    }
}

static AVCodecContext *codec_from_stream( AVStream *stream )
{
    AVCodec *codec = avcodec_find_decoder( stream->codecpar->codec_id );
    if( !codec )
        return NULL;

    AVCodecContext *c = avcodec_alloc_context3( codec );
    if( !c )
        return NULL;

    if( avcodec_parameters_to_context( c, stream->codecpar ) < 0 )
    {
        avcodec_free_context( &c );
        return NULL;
    }

    return c;
}

static int read_frame_internal( cli_pic_t *p_pic, lavf_hnd_t *h, int i_frame, video_info_t *info )
{
    if( h->first_pic && !info )
    {
        /* see if the frame we are requesting is the frame we have already read and stored.
         * if so, retrieve the pts and image data before freeing it. */
        if( !i_frame )
        {
            XCHG( cli_image_t, p_pic->img, h->first_pic->img );
            p_pic->pts = h->first_pic->pts;
        }
        lavf_input.picture_clean( h->first_pic, h );
        free( h->first_pic );
        h->first_pic = NULL;
        if( !i_frame )
            return 0;
    }

    AVPacket *pkt = h->pkt;

    while( i_frame >= h->next_frame )
    {
        int ret;

        while( (ret = avcodec_receive_frame( h->lavc, h->frame )) )
        {
            if( ret == AVERROR(EAGAIN) )
            {
                while( !(ret = av_read_frame( h->lavf, pkt )) && pkt->stream_index != h->stream_id )
                    av_packet_unref( pkt );

                if( ret )
                    ret = avcodec_send_packet( h->lavc, NULL );
                else
                {
                    ret = avcodec_send_packet( h->lavc, pkt );
                    av_packet_unref( pkt );
                }
            }
            else if( ret == AVERROR_EOF )
                return -1;

            if( ret )
            {
                x264_cli_log( "lavf", X264_LOG_WARNING, "video decoding failed on frame %d\n", h->next_frame );
                return -1;
            }
        }

        h->next_frame++;
    }

    memcpy( p_pic->img.stride, h->frame->linesize, sizeof(p_pic->img.stride) );
    memcpy( p_pic->img.plane, h->frame->data, sizeof(p_pic->img.plane) );
    int is_fullrange   = 0;
    p_pic->img.width   = h->lavc->width;
    p_pic->img.height  = h->lavc->height;
    p_pic->img.csp     = handle_jpeg( h->lavc->pix_fmt, &is_fullrange ) | X264_CSP_OTHER;

    if( info )
    {
        info->fullrange  = is_fullrange;
        info->interlaced = h->frame->interlaced_frame;
        info->tff        = h->frame->top_field_first;
    }

    if( h->vfr_input )
    {
        p_pic->pts = p_pic->duration = 0;
        if( h->frame->pts != AV_NOPTS_VALUE )
            p_pic->pts = h->frame->pts;
        else if( h->frame->pkt_dts != AV_NOPTS_VALUE )
            p_pic->pts = h->frame->pkt_dts; // for AVI files
        else if( info )
        {
            h->vfr_input = info->vfr = 0;
            return 0;
        }
    }

    return 0;
}

static int open_file( char *psz_filename, hnd_t *p_handle, video_info_t *info, cli_input_opt_t *opt )
{
    lavf_hnd_t *h = calloc( 1, sizeof(lavf_hnd_t) );
    if( !h )
        return -1;
    if( !strcmp( psz_filename, "-" ) )
        psz_filename = "pipe:";

    h->frame = av_frame_alloc();
    if( !h->frame )
        return -1;
    h->pkt = av_packet_alloc();
    if( !h->pkt )
        return -1;

    /* if resolution was passed in, place it and colorspace into options. this allows raw video support */
    AVDictionary *options = NULL;
    if( opt->resolution )
    {
        av_dict_set( &options, "video_size", opt->resolution, 0 );
        const char *csp = opt->colorspace ? opt->colorspace : av_get_pix_fmt_name( AV_PIX_FMT_YUV420P );
        av_dict_set( &options, "pixel_format", csp, 0 );
    }

    /* specify the input format. this is helpful when lavf fails to guess */
    AVInputFormat *format = NULL;
    if( opt->format )
        FAIL_IF_ERROR( !(format = av_find_input_format( opt->format )), "unknown file format: %s\n", opt->format );

    FAIL_IF_ERROR( avformat_open_input( &h->lavf, psz_filename, format, &options ), "could not open input file\n" );
    if( options )
        av_dict_free( &options );
    FAIL_IF_ERROR( avformat_find_stream_info( h->lavf, NULL ) < 0, "could not find input stream info\n" );

    int i = 0;
    while( i < h->lavf->nb_streams && h->lavf->streams[i]->codecpar->codec_type != AVMEDIA_TYPE_VIDEO )
        i++;
    FAIL_IF_ERROR( i == h->lavf->nb_streams, "could not find video stream\n" );
    h->stream_id       = i;
    h->next_frame      = 0;
    h->lavc            = codec_from_stream( h->lavf->streams[i] );
    if( !h->lavc )
        return -1;

    info->fps_num      = h->lavf->streams[i]->avg_frame_rate.num;
    info->fps_den      = h->lavf->streams[i]->avg_frame_rate.den;
    info->timebase_num = h->lavf->streams[i]->time_base.num;
    info->timebase_den = h->lavf->streams[i]->time_base.den;
    /* lavf is thread unsafe as calling av_read_frame invalidates previously read AVPackets */
    info->thread_safe  = 0;
    h->vfr_input       = info->vfr;
    FAIL_IF_ERROR( avcodec_open2( h->lavc, avcodec_find_decoder( h->lavc->codec_id ), NULL ),
                   "could not find decoder for video stream\n" );

    /* prefetch the first frame and set/confirm flags */
    h->first_pic = malloc( sizeof(cli_pic_t) );
    FAIL_IF_ERROR( !h->first_pic || lavf_input.picture_alloc( h->first_pic, h, X264_CSP_OTHER, info->width, info->height ),
                   "malloc failed\n" );
    if( read_frame_internal( h->first_pic, h, 0, info ) )
        return -1;

    info->width      = h->lavc->width;
    info->height     = h->lavc->height;
    info->csp        = h->first_pic->img.csp;
    info->num_frames = h->lavf->streams[i]->nb_frames;
    info->sar_height = h->lavc->sample_aspect_ratio.den;
    info->sar_width  = h->lavc->sample_aspect_ratio.num;
    info->fullrange |= h->lavc->color_range == AVCOL_RANGE_JPEG;

    /* avisynth stores rgb data vertically flipped. */
    if( !strcasecmp( get_filename_extension( psz_filename ), "avs" ) &&
        (h->lavc->pix_fmt == AV_PIX_FMT_BGRA || h->lavc->pix_fmt == AV_PIX_FMT_BGR24) )
        info->csp |= X264_CSP_VFLIP;

    *p_handle = h;

    return 0;
}

static int picture_alloc( cli_pic_t *pic, hnd_t handle, int csp, int width, int height )
{
    if( x264_cli_pic_alloc( pic, X264_CSP_NONE, width, height ) )
        return -1;
    pic->img.csp = csp;
    pic->img.planes = 4;
    return 0;
}

static int read_frame( cli_pic_t *pic, hnd_t handle, int i_frame )
{
    return read_frame_internal( pic, handle, i_frame, NULL );
}

static void picture_clean( cli_pic_t *pic, hnd_t handle )
{
    memset( pic, 0, sizeof(cli_pic_t) );
}

static int close_file( hnd_t handle )
{
    lavf_hnd_t *h = handle;
    avcodec_free_context( &h->lavc );
    avformat_close_input( &h->lavf );
    av_packet_free( &h->pkt );
    av_frame_free( &h->frame );
    free( h );
    return 0;
}

const cli_input_t lavf_input = { open_file, picture_alloc, read_frame, NULL, picture_clean, close_file };
