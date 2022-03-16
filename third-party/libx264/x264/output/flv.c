/*****************************************************************************
 * flv.c: flv muxer
 *****************************************************************************
 * Copyright (C) 2009-2022 x264 project
 *
 * Authors: Kieran Kunhya <kieran@kunhya.com>
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
#include "flv_bytestream.h"

#define CHECK(x)\
do {\
    if( (x) < 0 )\
        return -1;\
} while( 0 )

typedef struct
{
    flv_buffer *c;

    uint8_t *sei;
    int sei_len;

    int64_t i_fps_num;
    int64_t i_fps_den;
    int64_t i_framenum;

    uint64_t i_framerate_pos;
    uint64_t i_duration_pos;
    uint64_t i_filesize_pos;
    uint64_t i_bitrate_pos;

    uint8_t b_write_length;
    int64_t i_prev_dts;
    int64_t i_prev_cts;
    int64_t i_delay_time;
    int64_t i_init_delta;
    int i_delay_frames;

    double d_timebase;
    int b_vfr_input;
    int b_dts_compress;

    unsigned start;
} flv_hnd_t;

static int write_header( flv_buffer *c )
{
    flv_put_tag( c, "FLV" ); // Signature
    flv_put_byte( c, 1 );    // Version
    flv_put_byte( c, 1 );    // Video Only
    flv_put_be32( c, 9 );    // DataOffset
    flv_put_be32( c, 0 );    // PreviousTagSize0

    return flv_flush_data( c );
}

static int open_file( char *psz_filename, hnd_t *p_handle, cli_output_opt_t *opt )
{
    flv_hnd_t *p_flv = calloc( 1, sizeof(flv_hnd_t) );
    if( p_flv )
    {
        flv_buffer *c = flv_create_writer( psz_filename );
        if( c )
        {
            if( !write_header( c ) )
            {
                p_flv->c = c;
                p_flv->b_dts_compress = opt->use_dts_compress;
                *p_handle = p_flv;
                return 0;
            }

            fclose( c->fp );
            free( c->data );
            free( c );
        }
        free( p_flv );
    }

    *p_handle = NULL;
    return -1;
}

static int set_param( hnd_t handle, x264_param_t *p_param )
{
    flv_hnd_t *p_flv = handle;
    flv_buffer *c = p_flv->c;

    flv_put_byte( c, FLV_TAG_TYPE_META ); // Tag Type "script data"

    int start = c->d_cur;
    flv_put_be24( c, 0 ); // data length
    flv_put_be24( c, 0 ); // timestamp
    flv_put_be32( c, 0 ); // reserved

    flv_put_byte( c, AMF_DATA_TYPE_STRING );
    flv_put_amf_string( c, "onMetaData" );

    flv_put_byte( c, AMF_DATA_TYPE_MIXEDARRAY );
    flv_put_be32( c, 7 );

    flv_put_amf_string( c, "width" );
    flv_put_amf_double( c, p_param->i_width );

    flv_put_amf_string( c, "height" );
    flv_put_amf_double( c, p_param->i_height );

    flv_put_amf_string( c, "framerate" );

    if( !p_param->b_vfr_input )
        flv_put_amf_double( c, (double)p_param->i_fps_num / p_param->i_fps_den );
    else
    {
        p_flv->i_framerate_pos = c->d_cur + c->d_total + 1;
        flv_put_amf_double( c, 0 ); // written at end of encoding
    }

    flv_put_amf_string( c, "videocodecid" );
    flv_put_amf_double( c, FLV_CODECID_H264 );

    flv_put_amf_string( c, "duration" );
    p_flv->i_duration_pos = c->d_cur + c->d_total + 1;
    flv_put_amf_double( c, 0 ); // written at end of encoding

    flv_put_amf_string( c, "filesize" );
    p_flv->i_filesize_pos = c->d_cur + c->d_total + 1;
    flv_put_amf_double( c, 0 ); // written at end of encoding

    flv_put_amf_string( c, "videodatarate" );
    p_flv->i_bitrate_pos = c->d_cur + c->d_total + 1;
    flv_put_amf_double( c, 0 ); // written at end of encoding

    flv_put_amf_string( c, "" );
    flv_put_byte( c, AMF_END_OF_OBJECT );

    unsigned length = c->d_cur - start;
    flv_rewrite_amf_be24( c, length - 10, start );

    flv_put_be32( c, length + 1 ); // tag length

    p_flv->i_fps_num = p_param->i_fps_num;
    p_flv->i_fps_den = p_param->i_fps_den;
    p_flv->d_timebase = (double)p_param->i_timebase_num / p_param->i_timebase_den;
    p_flv->b_vfr_input = p_param->b_vfr_input;
    p_flv->i_delay_frames = p_param->i_bframe ? (p_param->i_bframe_pyramid ? 2 : 1) : 0;

    return 0;
}

static int write_headers( hnd_t handle, x264_nal_t *p_nal )
{
    flv_hnd_t *p_flv = handle;
    flv_buffer *c = p_flv->c;

    int sps_size = p_nal[0].i_payload;
    int pps_size = p_nal[1].i_payload;
    int sei_size = p_nal[2].i_payload;

    // SEI
    /* It is within the spec to write this as-is but for
     * mplayer/ffmpeg playback this is deferred until before the first frame */

    p_flv->sei = malloc( sei_size );
    if( !p_flv->sei )
        return -1;
    p_flv->sei_len = sei_size;

    memcpy( p_flv->sei, p_nal[2].p_payload, sei_size );

    // SPS
    uint8_t *sps = p_nal[0].p_payload + 4;

    flv_put_byte( c, FLV_TAG_TYPE_VIDEO );
    flv_put_be24( c, 0 ); // rewrite later
    flv_put_be24( c, 0 ); // timestamp
    flv_put_byte( c, 0 ); // timestamp extended
    flv_put_be24( c, 0 ); // StreamID - Always 0
    p_flv->start = c->d_cur; // needed for overwriting length

    flv_put_byte( c, FLV_FRAME_KEY | FLV_CODECID_H264 ); // FrameType and CodecID
    flv_put_byte( c, 0 ); // AVC sequence header
    flv_put_be24( c, 0 ); // composition time

    flv_put_byte( c, 1 );      // version
    flv_put_byte( c, sps[1] ); // profile
    flv_put_byte( c, sps[2] ); // profile
    flv_put_byte( c, sps[3] ); // level
    flv_put_byte( c, 0xff );   // 6 bits reserved (111111) + 2 bits nal size length - 1 (11)
    flv_put_byte( c, 0xe1 );   // 3 bits reserved (111) + 5 bits number of sps (00001)

    flv_put_be16( c, sps_size - 4 );
    flv_append_data( c, sps, sps_size - 4 );

    // PPS
    flv_put_byte( c, 1 ); // number of pps
    flv_put_be16( c, pps_size - 4 );
    flv_append_data( c, p_nal[1].p_payload + 4, pps_size - 4 );

    // rewrite data length info
    unsigned length = c->d_cur - p_flv->start;
    flv_rewrite_amf_be24( c, length, p_flv->start - 10 );
    flv_put_be32( c, length + 11 ); // Last tag size
    CHECK( flv_flush_data( c ) );

    return sei_size + sps_size + pps_size;
}

static int write_frame( hnd_t handle, uint8_t *p_nalu, int i_size, x264_picture_t *p_picture )
{
    flv_hnd_t *p_flv = handle;
    flv_buffer *c = p_flv->c;

#define convert_timebase_ms( timestamp, timebase ) (int64_t)((timestamp) * (timebase) * 1000 + 0.5)

    if( !p_flv->i_framenum )
    {
        p_flv->i_delay_time = p_picture->i_dts * -1;
        if( !p_flv->b_dts_compress && p_flv->i_delay_time )
            x264_cli_log( "flv", X264_LOG_INFO, "initial delay %"PRId64" ms\n",
                          convert_timebase_ms( p_picture->i_pts + p_flv->i_delay_time, p_flv->d_timebase ) );
    }

    int64_t dts;
    int64_t cts;
    int64_t offset;

    if( p_flv->b_dts_compress )
    {
        if( p_flv->i_framenum == 1 )
            p_flv->i_init_delta = convert_timebase_ms( p_picture->i_dts + p_flv->i_delay_time, p_flv->d_timebase );
        dts = p_flv->i_framenum > p_flv->i_delay_frames
            ? convert_timebase_ms( p_picture->i_dts, p_flv->d_timebase )
            : p_flv->i_framenum * p_flv->i_init_delta / (p_flv->i_delay_frames + 1);
        cts = convert_timebase_ms( p_picture->i_pts, p_flv->d_timebase );
    }
    else
    {
        dts = convert_timebase_ms( p_picture->i_dts + p_flv->i_delay_time, p_flv->d_timebase );
        cts = convert_timebase_ms( p_picture->i_pts + p_flv->i_delay_time, p_flv->d_timebase );
    }
    offset = cts - dts;

    if( p_flv->i_framenum )
    {
        if( p_flv->i_prev_dts == dts )
            x264_cli_log( "flv", X264_LOG_WARNING, "duplicate DTS %"PRId64" generated by rounding\n"
                          "               decoding framerate cannot exceed 1000fps\n", dts );
        if( p_flv->i_prev_cts == cts )
            x264_cli_log( "flv", X264_LOG_WARNING, "duplicate CTS %"PRId64" generated by rounding\n"
                          "               composition framerate cannot exceed 1000fps\n", cts );
    }
    p_flv->i_prev_dts = dts;
    p_flv->i_prev_cts = cts;

    // A new frame - write packet header
    flv_put_byte( c, FLV_TAG_TYPE_VIDEO );
    flv_put_be24( c, 0 ); // calculated later
    flv_put_be24( c, dts );
    flv_put_byte( c, dts >> 24 );
    flv_put_be24( c, 0 );

    p_flv->start = c->d_cur;
    flv_put_byte( c, (p_picture->b_keyframe ? FLV_FRAME_KEY : FLV_FRAME_INTER) | FLV_CODECID_H264 );
    flv_put_byte( c, 1 ); // AVC NALU
    flv_put_be24( c, offset );

    if( p_flv->sei )
    {
        flv_append_data( c, p_flv->sei, p_flv->sei_len );
        free( p_flv->sei );
        p_flv->sei = NULL;
    }
    flv_append_data( c, p_nalu, i_size );

    unsigned length = c->d_cur - p_flv->start;
    flv_rewrite_amf_be24( c, length, p_flv->start - 10 );
    flv_put_be32( c, 11 + length ); // Last tag size
    CHECK( flv_flush_data( c ) );

    p_flv->i_framenum++;

    return i_size;
}

static int rewrite_amf_double( FILE *fp, uint64_t position, double value )
{
    uint64_t x = endian_fix64( flv_dbl2int( value ) );
    return !fseek( fp, position, SEEK_SET ) && fwrite( &x, 8, 1, fp ) == 1 ? 0 : -1;
}

#undef CHECK
#define CHECK(x)\
do {\
    if( (x) < 0 )\
        goto error;\
} while( 0 )

static int close_file( hnd_t handle, int64_t largest_pts, int64_t second_largest_pts )
{
    int ret = -1;
    flv_hnd_t *p_flv = handle;
    flv_buffer *c = p_flv->c;

    CHECK( flv_flush_data( c ) );

    double total_duration;
    /* duration algorithm fails with one frame */
    if( p_flv->i_framenum == 1 )
        total_duration = p_flv->i_fps_num ? (double)p_flv->i_fps_den / p_flv->i_fps_num : 0;
    else
        total_duration = (2 * largest_pts - second_largest_pts) * p_flv->d_timebase;

    if( x264_is_regular_file( c->fp ) && total_duration > 0 )
    {
        double framerate;
        int64_t filesize = ftell( c->fp );

        if( p_flv->i_framerate_pos )
        {
            framerate = (double)p_flv->i_framenum / total_duration;
            CHECK( rewrite_amf_double( c->fp, p_flv->i_framerate_pos, framerate ) );
        }

        CHECK( rewrite_amf_double( c->fp, p_flv->i_duration_pos, total_duration ) );
        CHECK( rewrite_amf_double( c->fp, p_flv->i_filesize_pos, filesize ) );
        CHECK( rewrite_amf_double( c->fp, p_flv->i_bitrate_pos, filesize * 8.0 / ( total_duration * 1000 ) ) );
    }
    ret = 0;

error:
    fclose( c->fp );
    free( c->data );
    free( c );
    free( p_flv );

    return ret;
}

const cli_output_t flv_output = { open_file, set_param, write_headers, write_frame, close_file };
