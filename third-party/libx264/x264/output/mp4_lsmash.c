/*****************************************************************************
 * mp4_lsmash.c: mp4 muxer using L-SMASH
 *****************************************************************************
 * Copyright (C) 2003-2022 x264 project
 *
 * Authors: Laurent Aimar <fenrir@via.ecp.fr>
 *          Loren Merritt <lorenm@u.washington.edu>
 *          Yusuke Nakamura <muken.the.vfrmaniac@gmail.com>
 *          Takashi Hirata <silverfilain@gmail.com>
 *          golgol7777 <golgol7777@gmail.com>
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
#include <lsmash.h>

#define H264_NALU_LENGTH_SIZE 4

/*******************/

#define MP4_LOG_ERROR( ... )                x264_cli_log( "mp4", X264_LOG_ERROR, __VA_ARGS__ )
#define MP4_LOG_WARNING( ... )              x264_cli_log( "mp4", X264_LOG_WARNING, __VA_ARGS__ )
#define MP4_LOG_INFO( ... )                 x264_cli_log( "mp4", X264_LOG_INFO, __VA_ARGS__ )
#define MP4_FAIL_IF_ERR( cond, ... )        FAIL_IF_ERR( cond, "mp4", __VA_ARGS__ )

/* For close_file() */
#define MP4_LOG_IF_ERR( cond, ... )\
do\
{\
    if( cond )\
    {\
        MP4_LOG_ERROR( __VA_ARGS__ );\
    }\
} while( 0 )

/* For open_file() */
#define MP4_FAIL_IF_ERR_EX( cond, ... )\
do\
{\
    if( cond )\
    {\
        remove_mp4_hnd( p_mp4 );\
        MP4_LOG_ERROR( __VA_ARGS__ );\
        return -1;\
    }\
} while( 0 )

/*******************/

typedef struct
{
    lsmash_root_t *p_root;
    lsmash_video_summary_t *summary;
    int b_stdout;
    uint32_t i_movie_timescale;
    uint32_t i_video_timescale;
    uint32_t i_track;
    uint32_t i_sample_entry;
    uint64_t i_time_inc;
    int64_t i_start_offset;
    uint64_t i_first_cts;
    uint64_t i_prev_dts;
    uint32_t i_sei_size;
    uint8_t *p_sei_buffer;
    int i_numframe;
    int64_t i_init_delta;
    int i_delay_frames;
    int b_dts_compress;
    int i_dts_compress_multiplier;
    int b_use_recovery;
    int b_fragments;
    lsmash_file_parameters_t file_param;
} mp4_hnd_t;

/*******************/

static void remove_mp4_hnd( hnd_t handle )
{
    mp4_hnd_t *p_mp4 = handle;
    if( !p_mp4 )
        return;
    lsmash_cleanup_summary( (lsmash_summary_t *)p_mp4->summary );
    lsmash_close_file( &p_mp4->file_param );
    lsmash_destroy_root( p_mp4->p_root );
    free( p_mp4->p_sei_buffer );
    free( p_mp4 );
}

/*******************/

static int close_file( hnd_t handle, int64_t largest_pts, int64_t second_largest_pts )
{
    mp4_hnd_t *p_mp4 = handle;

    if( !p_mp4 )
        return 0;

    if( p_mp4->p_root )
    {
        double actual_duration = 0;
        if( p_mp4->i_track )
        {
            /* Flush the rest of samples and add the last sample_delta. */
            uint32_t last_delta = largest_pts - second_largest_pts;
            MP4_LOG_IF_ERR( lsmash_flush_pooled_samples( p_mp4->p_root, p_mp4->i_track, (last_delta ? last_delta : 1) * p_mp4->i_time_inc ),
                            "failed to flush the rest of samples.\n" );

            if( p_mp4->i_movie_timescale != 0 && p_mp4->i_video_timescale != 0 )    /* avoid zero division */
                actual_duration = ((double)((largest_pts + last_delta) * p_mp4->i_time_inc) / p_mp4->i_video_timescale) * p_mp4->i_movie_timescale;
            else
                MP4_LOG_ERROR( "timescale is broken.\n" );

            /*
             * Declare the explicit time-line mapping.
             * A segment_duration is given by movie timescale, while a media_time that is the start time of this segment
             * is given by not the movie timescale but rather the media timescale.
             * The reason is that ISO media have two time-lines, presentation and media time-line,
             * and an edit maps the presentation time-line to the media time-line.
             * According to QuickTime file format specification and the actual playback in QuickTime Player,
             * if the Edit Box doesn't exist in the track, the ratio of the summation of sample durations and track's duration becomes
             * the track's media_rate so that the entire media can be used by the track.
             * So, we add Edit Box here to avoid this implicit media_rate could distort track's presentation timestamps slightly.
             * Note: Any demuxers should follow the Edit List Box if it exists.
             */
            lsmash_edit_t edit;
            edit.duration   = actual_duration;
            edit.start_time = p_mp4->i_first_cts;
            edit.rate       = ISOM_EDIT_MODE_NORMAL;
            if( !p_mp4->b_fragments )
            {
                MP4_LOG_IF_ERR( lsmash_create_explicit_timeline_map( p_mp4->p_root, p_mp4->i_track, edit ),
                                "failed to set timeline map for video.\n" );
            }
            else if( !p_mp4->b_stdout )
                MP4_LOG_IF_ERR( lsmash_modify_explicit_timeline_map( p_mp4->p_root, p_mp4->i_track, 1, edit ),
                                "failed to update timeline map for video.\n" );
        }

        MP4_LOG_IF_ERR( lsmash_finish_movie( p_mp4->p_root, NULL ), "failed to finish movie.\n" );
    }

    remove_mp4_hnd( p_mp4 ); /* including lsmash_destroy_root( p_mp4->p_root ); */

    return 0;
}

static int open_file( char *psz_filename, hnd_t *p_handle, cli_output_opt_t *opt )
{
    *p_handle = NULL;

    int b_regular = strcmp( psz_filename, "-" );
    b_regular = b_regular && x264_is_regular_file_path( psz_filename );
    if( b_regular )
    {
        FILE *fh = x264_fopen( psz_filename, "wb" );
        MP4_FAIL_IF_ERR( !fh, "cannot open output file `%s'.\n", psz_filename );
        b_regular = x264_is_regular_file( fh );
        fclose( fh );
    }

    mp4_hnd_t *p_mp4 = calloc( 1, sizeof(mp4_hnd_t) );
    MP4_FAIL_IF_ERR( !p_mp4, "failed to allocate memory for muxer information.\n" );

    p_mp4->b_dts_compress = opt->use_dts_compress;
    p_mp4->b_use_recovery = 0; // we don't really support recovery
    p_mp4->b_fragments    = !b_regular;
    p_mp4->b_stdout       = !strcmp( psz_filename, "-" );

    p_mp4->p_root = lsmash_create_root();
    MP4_FAIL_IF_ERR_EX( !p_mp4->p_root, "failed to create root.\n" );

    MP4_FAIL_IF_ERR_EX( lsmash_open_file( psz_filename, 0, &p_mp4->file_param ) < 0, "failed to open an output file.\n" );
    if( p_mp4->b_fragments )
        p_mp4->file_param.mode |= LSMASH_FILE_MODE_FRAGMENTED;

    p_mp4->summary = (lsmash_video_summary_t *)lsmash_create_summary( LSMASH_SUMMARY_TYPE_VIDEO );
    MP4_FAIL_IF_ERR_EX( !p_mp4->summary,
                        "failed to allocate memory for summary information of video.\n" );
    p_mp4->summary->sample_type = ISOM_CODEC_TYPE_AVC1_VIDEO;

    *p_handle = p_mp4;

    return 0;
}

static int set_param( hnd_t handle, x264_param_t *p_param )
{
    mp4_hnd_t *p_mp4 = handle;
    uint64_t i_media_timescale;

    p_mp4->i_delay_frames = p_param->i_bframe ? (p_param->i_bframe_pyramid ? 2 : 1) : 0;
    p_mp4->i_dts_compress_multiplier = p_mp4->b_dts_compress * p_mp4->i_delay_frames + 1;

    i_media_timescale = (uint64_t)p_param->i_timebase_den * p_mp4->i_dts_compress_multiplier;
    p_mp4->i_time_inc = (uint64_t)p_param->i_timebase_num * p_mp4->i_dts_compress_multiplier;
    MP4_FAIL_IF_ERR( i_media_timescale > UINT32_MAX, "MP4 media timescale %"PRIu64" exceeds maximum\n", i_media_timescale );

    /* Select brands. */
    lsmash_brand_type brands[6] = { 0 };
    uint32_t brand_count = 0;
    brands[brand_count++] = ISOM_BRAND_TYPE_MP42;
    brands[brand_count++] = ISOM_BRAND_TYPE_MP41;
    brands[brand_count++] = ISOM_BRAND_TYPE_ISOM;
    if( p_mp4->b_use_recovery )
    {
        brands[brand_count++] = ISOM_BRAND_TYPE_AVC1;   /* sdtp, sgpd, sbgp and visual roll recovery grouping */
        if( p_param->b_open_gop )
            brands[brand_count++] = ISOM_BRAND_TYPE_ISO6;   /* cslg and visual random access grouping */
    }

    /* Set file */
    lsmash_file_parameters_t *file_param = &p_mp4->file_param;
    file_param->major_brand   = brands[0];
    file_param->brands        = brands;
    file_param->brand_count   = brand_count;
    file_param->minor_version = 0;
    MP4_FAIL_IF_ERR( !lsmash_set_file( p_mp4->p_root, file_param ), "failed to add an output file into a ROOT.\n" );

    /* Set movie parameters. */
    lsmash_movie_parameters_t movie_param;
    lsmash_initialize_movie_parameters( &movie_param );
    MP4_FAIL_IF_ERR( lsmash_set_movie_parameters( p_mp4->p_root, &movie_param ),
                     "failed to set movie parameters.\n" );
    p_mp4->i_movie_timescale = lsmash_get_movie_timescale( p_mp4->p_root );
    MP4_FAIL_IF_ERR( !p_mp4->i_movie_timescale, "movie timescale is broken.\n" );

    /* Create a video track. */
    p_mp4->i_track = lsmash_create_track( p_mp4->p_root, ISOM_MEDIA_HANDLER_TYPE_VIDEO_TRACK );
    MP4_FAIL_IF_ERR( !p_mp4->i_track, "failed to create a video track.\n" );

    p_mp4->summary->width = p_param->i_width;
    p_mp4->summary->height = p_param->i_height;
    uint32_t i_display_width = p_param->i_width << 16;
    uint32_t i_display_height = p_param->i_height << 16;
    if( p_param->vui.i_sar_width && p_param->vui.i_sar_height )
    {
        double sar = (double)p_param->vui.i_sar_width / p_param->vui.i_sar_height;
        if( sar > 1.0 )
            i_display_width *= sar;
        else
            i_display_height /= sar;
        p_mp4->summary->par_h = p_param->vui.i_sar_width;
        p_mp4->summary->par_v = p_param->vui.i_sar_height;
    }
    p_mp4->summary->color.primaries_index = p_param->vui.i_colorprim;
    p_mp4->summary->color.transfer_index  = p_param->vui.i_transfer;
    p_mp4->summary->color.matrix_index    = p_param->vui.i_colmatrix >= 0 ? p_param->vui.i_colmatrix : ISOM_MATRIX_INDEX_UNSPECIFIED;
    p_mp4->summary->color.full_range      = p_param->vui.b_fullrange >= 0 ? p_param->vui.b_fullrange : 0;

    /* Set video track parameters. */
    lsmash_track_parameters_t track_param;
    lsmash_initialize_track_parameters( &track_param );
    lsmash_track_mode track_mode = ISOM_TRACK_ENABLED | ISOM_TRACK_IN_MOVIE | ISOM_TRACK_IN_PREVIEW;
    track_param.mode = track_mode;
    track_param.display_width = i_display_width;
    track_param.display_height = i_display_height;
    MP4_FAIL_IF_ERR( lsmash_set_track_parameters( p_mp4->p_root, p_mp4->i_track, &track_param ),
                     "failed to set track parameters for video.\n" );

    /* Set video media parameters. */
    lsmash_media_parameters_t media_param;
    lsmash_initialize_media_parameters( &media_param );
    media_param.timescale = i_media_timescale;
    media_param.media_handler_name = "L-SMASH Video Media Handler";
    if( p_mp4->b_use_recovery )
    {
        media_param.roll_grouping = p_param->b_intra_refresh;
        media_param.rap_grouping = p_param->b_open_gop;
    }
    MP4_FAIL_IF_ERR( lsmash_set_media_parameters( p_mp4->p_root, p_mp4->i_track, &media_param ),
                     "failed to set media parameters for video.\n" );
    p_mp4->i_video_timescale = lsmash_get_media_timescale( p_mp4->p_root, p_mp4->i_track );
    MP4_FAIL_IF_ERR( !p_mp4->i_video_timescale, "media timescale for video is broken.\n" );

    return 0;
}

static int write_headers( hnd_t handle, x264_nal_t *p_nal )
{
    mp4_hnd_t *p_mp4 = handle;

    uint32_t sps_size = p_nal[0].i_payload - H264_NALU_LENGTH_SIZE;
    uint32_t pps_size = p_nal[1].i_payload - H264_NALU_LENGTH_SIZE;
    uint32_t sei_size = p_nal[2].i_payload;

    uint8_t *sps = p_nal[0].p_payload + H264_NALU_LENGTH_SIZE;
    uint8_t *pps = p_nal[1].p_payload + H264_NALU_LENGTH_SIZE;
    uint8_t *sei = p_nal[2].p_payload;

    lsmash_codec_specific_t *cs = lsmash_create_codec_specific_data( LSMASH_CODEC_SPECIFIC_DATA_TYPE_ISOM_VIDEO_H264,
                                                                     LSMASH_CODEC_SPECIFIC_FORMAT_STRUCTURED );

    lsmash_h264_specific_parameters_t *param = (lsmash_h264_specific_parameters_t *)cs->data.structured;
    param->lengthSizeMinusOne = H264_NALU_LENGTH_SIZE - 1;

    /* SPS
     * The remaining parameters are automatically set by SPS. */
    if( lsmash_append_h264_parameter_set( param, H264_PARAMETER_SET_TYPE_SPS, sps, sps_size ) )
    {
        MP4_LOG_ERROR( "failed to append SPS.\n" );
        return -1;
    }

    /* PPS */
    if( lsmash_append_h264_parameter_set( param, H264_PARAMETER_SET_TYPE_PPS, pps, pps_size ) )
    {
        MP4_LOG_ERROR( "failed to append PPS.\n" );
        return -1;
    }

    if( lsmash_add_codec_specific_data( (lsmash_summary_t *)p_mp4->summary, cs ) )
    {
        MP4_LOG_ERROR( "failed to add H.264 specific info.\n" );
        return -1;
    }

    lsmash_destroy_codec_specific_data( cs );

    /* Additional extensions */
    /* Bitrate info */
    cs = lsmash_create_codec_specific_data( LSMASH_CODEC_SPECIFIC_DATA_TYPE_ISOM_VIDEO_H264_BITRATE,
                                            LSMASH_CODEC_SPECIFIC_FORMAT_STRUCTURED );
    if( cs )
        lsmash_add_codec_specific_data( (lsmash_summary_t *)p_mp4->summary, cs );
    lsmash_destroy_codec_specific_data( cs );

    p_mp4->i_sample_entry = lsmash_add_sample_entry( p_mp4->p_root, p_mp4->i_track, p_mp4->summary );
    MP4_FAIL_IF_ERR( !p_mp4->i_sample_entry,
                     "failed to add sample entry for video.\n" );

    /* SEI */
    p_mp4->p_sei_buffer = malloc( sei_size );
    MP4_FAIL_IF_ERR( !p_mp4->p_sei_buffer,
                     "failed to allocate sei transition buffer.\n" );
    memcpy( p_mp4->p_sei_buffer, sei, sei_size );
    p_mp4->i_sei_size = sei_size;

    return sei_size + sps_size + pps_size;
}

static int write_frame( hnd_t handle, uint8_t *p_nalu, int i_size, x264_picture_t *p_picture )
{
    mp4_hnd_t *p_mp4 = handle;
    uint64_t dts, cts;

    if( !p_mp4->i_numframe )
    {
        p_mp4->i_start_offset = p_picture->i_dts * -1;
        p_mp4->i_first_cts = p_mp4->b_dts_compress ? 0 : p_mp4->i_start_offset * p_mp4->i_time_inc;
        if( p_mp4->b_fragments )
        {
            lsmash_edit_t edit;
            edit.duration   = ISOM_EDIT_DURATION_UNKNOWN32;     /* QuickTime doesn't support 64bit duration. */
            edit.start_time = p_mp4->i_first_cts;
            edit.rate       = ISOM_EDIT_MODE_NORMAL;
            MP4_LOG_IF_ERR( lsmash_create_explicit_timeline_map( p_mp4->p_root, p_mp4->i_track, edit ),
                            "failed to set timeline map for video.\n" );
        }
    }

    lsmash_sample_t *p_sample = lsmash_create_sample( i_size + p_mp4->i_sei_size );
    MP4_FAIL_IF_ERR( !p_sample,
                     "failed to create a video sample data.\n" );

    if( p_mp4->p_sei_buffer )
    {
        memcpy( p_sample->data, p_mp4->p_sei_buffer, p_mp4->i_sei_size );
        free( p_mp4->p_sei_buffer );
        p_mp4->p_sei_buffer = NULL;
    }

    memcpy( p_sample->data + p_mp4->i_sei_size, p_nalu, i_size );
    p_mp4->i_sei_size = 0;

    if( p_mp4->b_dts_compress )
    {
        if( p_mp4->i_numframe == 1 )
            p_mp4->i_init_delta = (p_picture->i_dts + p_mp4->i_start_offset) * p_mp4->i_time_inc;
        dts = p_mp4->i_numframe > p_mp4->i_delay_frames
            ? p_picture->i_dts * p_mp4->i_time_inc
            : p_mp4->i_numframe * (p_mp4->i_init_delta / p_mp4->i_dts_compress_multiplier);
        cts = p_picture->i_pts * p_mp4->i_time_inc;
    }
    else
    {
        dts = (p_picture->i_dts + p_mp4->i_start_offset) * p_mp4->i_time_inc;
        cts = (p_picture->i_pts + p_mp4->i_start_offset) * p_mp4->i_time_inc;
    }

    p_sample->dts = dts;
    p_sample->cts = cts;
    p_sample->index = p_mp4->i_sample_entry;
    p_sample->prop.ra_flags = p_picture->b_keyframe ? ISOM_SAMPLE_RANDOM_ACCESS_FLAG_SYNC : ISOM_SAMPLE_RANDOM_ACCESS_FLAG_NONE;

    if( p_mp4->b_fragments && p_mp4->i_numframe && p_sample->prop.ra_flags != ISOM_SAMPLE_RANDOM_ACCESS_FLAG_NONE )
    {
        MP4_FAIL_IF_ERR( lsmash_flush_pooled_samples( p_mp4->p_root, p_mp4->i_track, p_sample->dts - p_mp4->i_prev_dts ),
                         "failed to flush the rest of samples.\n" );
        MP4_FAIL_IF_ERR( lsmash_create_fragment_movie( p_mp4->p_root ),
                         "failed to create a movie fragment.\n" );
    }

    /* Append data per sample. */
    MP4_FAIL_IF_ERR( lsmash_append_sample( p_mp4->p_root, p_mp4->i_track, p_sample ),
                     "failed to append a video frame.\n" );

    p_mp4->i_prev_dts = dts;
    p_mp4->i_numframe++;

    return i_size;
}

const cli_output_t mp4_output = { open_file, set_param, write_headers, write_frame, close_file };
