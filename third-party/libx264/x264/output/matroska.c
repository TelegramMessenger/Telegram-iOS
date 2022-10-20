/*****************************************************************************
 * matroska.c: matroska muxer
 *****************************************************************************
 * Copyright (C) 2005-2022 x264 project
 *
 * Authors: Mike Matsnev <mike@haali.su>
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

#include "output.h"
#include "matroska_ebml.h"

typedef struct
{
    mk_writer *w;

    int width, height, d_width, d_height;

    int display_size_units;
    int stereo_mode;

    int64_t frame_duration;

    char b_writing_frame;
    uint32_t i_timebase_num;
    uint32_t i_timebase_den;

} mkv_hnd_t;

static int open_file( char *psz_filename, hnd_t *p_handle, cli_output_opt_t *opt )
{
    *p_handle = NULL;
    mkv_hnd_t *p_mkv = calloc( 1, sizeof(mkv_hnd_t) );
    if( !p_mkv )
        return -1;

    p_mkv->w = mk_create_writer( psz_filename );
    if( !p_mkv->w )
    {
        free( p_mkv );
        return -1;
    }

    *p_handle = p_mkv;

    return 0;
}

#define STEREO_COUNT 7
static const uint8_t stereo_modes[STEREO_COUNT] = {5,9,7,1,3,13,0};
static const uint8_t stereo_w_div[STEREO_COUNT] = {1,2,1,2,1,1,1};
static const uint8_t stereo_h_div[STEREO_COUNT] = {1,1,2,1,2,1,1};

static int set_param( hnd_t handle, x264_param_t *p_param )
{
    mkv_hnd_t *p_mkv = handle;
    int64_t dw, dh;

    if( p_param->i_fps_num > 0 && !p_param->b_vfr_input )
    {
        p_mkv->frame_duration = (int64_t)p_param->i_fps_den *
                                (int64_t)1000000000 / p_param->i_fps_num;
    }
    else
    {
        p_mkv->frame_duration = 0;
    }

    dw = p_mkv->width = p_param->i_width;
    dh = p_mkv->height = p_param->i_height;
    p_mkv->display_size_units = DS_PIXELS;
    p_mkv->stereo_mode = -1;
    if( p_param->i_frame_packing >= 0 && p_param->i_frame_packing < STEREO_COUNT )
    {
        p_mkv->stereo_mode = stereo_modes[p_param->i_frame_packing];
        dw /= stereo_w_div[p_param->i_frame_packing];
        dh /= stereo_h_div[p_param->i_frame_packing];
    }
    if( p_param->vui.i_sar_width && p_param->vui.i_sar_height
        && p_param->vui.i_sar_width != p_param->vui.i_sar_height )
    {
        if( p_param->vui.i_sar_width > p_param->vui.i_sar_height )
        {
            dw = dw * p_param->vui.i_sar_width / p_param->vui.i_sar_height;
        }
        else
        {
            dh = dh * p_param->vui.i_sar_height / p_param->vui.i_sar_width;
        }
    }
    p_mkv->d_width = (int)dw;
    p_mkv->d_height = (int)dh;

    p_mkv->i_timebase_num = p_param->i_timebase_num;
    p_mkv->i_timebase_den = p_param->i_timebase_den;

    return 0;
}

static int write_headers( hnd_t handle, x264_nal_t *p_nal )
{
    mkv_hnd_t *p_mkv = handle;

    int sps_size = p_nal[0].i_payload - 4;
    int pps_size = p_nal[1].i_payload - 4;
    int sei_size = p_nal[2].i_payload;

    uint8_t *sps = p_nal[0].p_payload + 4;
    uint8_t *pps = p_nal[1].p_payload + 4;
    uint8_t *sei = p_nal[2].p_payload;

    int ret;
    uint8_t *avcC;
    int avcC_len;

    if( !p_mkv->width || !p_mkv->height ||
        !p_mkv->d_width || !p_mkv->d_height )
        return -1;

    avcC_len = 5 + 1 + 2 + sps_size + 1 + 2 + pps_size;
    avcC = malloc( avcC_len );
    if( !avcC )
        return -1;

    avcC[0] = 1;
    avcC[1] = sps[1];
    avcC[2] = sps[2];
    avcC[3] = sps[3];
    avcC[4] = 0xff; // nalu size length is four bytes
    avcC[5] = 0xe1; // one sps

    avcC[6] = sps_size >> 8;
    avcC[7] = sps_size;

    memcpy( avcC+8, sps, sps_size );

    avcC[8+sps_size] = 1; // one pps
    avcC[9+sps_size] = pps_size >> 8;
    avcC[10+sps_size] = pps_size;

    memcpy( avcC+11+sps_size, pps, pps_size );

    ret = mk_write_header( p_mkv->w, "x264" X264_VERSION, "V_MPEG4/ISO/AVC",
                           avcC, avcC_len, p_mkv->frame_duration, 50000,
                           p_mkv->width, p_mkv->height,
                           p_mkv->d_width, p_mkv->d_height, p_mkv->display_size_units, p_mkv->stereo_mode );
    free( avcC );

    if( ret < 0 )
        return ret;

    // SEI

    if( !p_mkv->b_writing_frame )
    {
        if( mk_start_frame( p_mkv->w ) < 0 )
            return -1;
        p_mkv->b_writing_frame = 1;
    }
    if( mk_add_frame_data( p_mkv->w, sei, sei_size ) < 0 )
        return -1;

    return sei_size + sps_size + pps_size;
}

static int write_frame( hnd_t handle, uint8_t *p_nalu, int i_size, x264_picture_t *p_picture )
{
    mkv_hnd_t *p_mkv = handle;

    if( !p_mkv->b_writing_frame )
    {
        if( mk_start_frame( p_mkv->w ) < 0 )
            return -1;
        p_mkv->b_writing_frame = 1;
    }

    if( mk_add_frame_data( p_mkv->w, p_nalu, i_size ) < 0 )
        return -1;

    int64_t i_stamp = (int64_t)((p_picture->i_pts * 1e9 * p_mkv->i_timebase_num / p_mkv->i_timebase_den) + 0.5);

    p_mkv->b_writing_frame = 0;

    if( mk_set_frame_flags( p_mkv->w, i_stamp, p_picture->b_keyframe, p_picture->i_type == X264_TYPE_B ) < 0 )
        return -1;

    return i_size;
}

static int close_file( hnd_t handle, int64_t largest_pts, int64_t second_largest_pts )
{
    mkv_hnd_t *p_mkv = handle;
    int ret;
    int64_t i_last_delta;

    i_last_delta = p_mkv->i_timebase_den ? (int64_t)(((largest_pts - second_largest_pts) * p_mkv->i_timebase_num / p_mkv->i_timebase_den) + 0.5) : 0;

    ret = mk_close( p_mkv->w, i_last_delta );

    free( p_mkv );

    return ret;
}

const cli_output_t mkv_output = { open_file, set_param, write_headers, write_frame, close_file };
