/*****************************************************************************
 * timecode.c: timecode file input
 *****************************************************************************
 * Copyright (C) 2010-2022 x264 project
 *
 * Authors: Yusuke Nakamura <muken.the.vfrmaniac@gmail.com>
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

#define FAIL_IF_ERROR( cond, ... ) FAIL_IF_ERR( cond, "timecode", __VA_ARGS__ )

typedef struct
{
    cli_input_t input;
    hnd_t p_handle;
    int auto_timebase_num;
    int auto_timebase_den;
    uint64_t timebase_num;
    uint64_t timebase_den;
    int stored_pts_num;
    int64_t *pts;
    double assume_fps;
    double last_timecode;
} timecode_hnd_t;

static inline double sigexp10( double value, double *exponent )
{
    /* This function separates significand and exp10 from double floating point. */
    *exponent = pow( 10, floor( log10( value ) ) );
    return value / *exponent;
}

#define DOUBLE_EPSILON 5e-6
#define MKV_TIMEBASE_DEN 1000000000

static double correct_fps( double fps, timecode_hnd_t *h )
{
    int i = 1;
    uint64_t fps_num, fps_den;
    double exponent;
    double fps_sig = sigexp10( fps, &exponent );
    while( 1 )
    {
        fps_den = i * h->timebase_num;
        fps_num = round( fps_den * fps_sig ) * exponent;
        FAIL_IF_ERROR( fps_num > UINT32_MAX, "tcfile fps correction failed.\n"
                       "                  Specify an appropriate timebase manually or remake tcfile.\n" );
        if( fabs( ((double)fps_num / fps_den) / exponent - fps_sig ) < DOUBLE_EPSILON )
            break;
        ++i;
    }
    if( h->auto_timebase_den )
    {
        h->timebase_den = h->timebase_den ? lcm( h->timebase_den, fps_num ) : fps_num;
        if( h->timebase_den > UINT32_MAX )
            h->auto_timebase_den = 0;
    }
    return (double)fps_num / fps_den;
}

static int try_mkv_timebase_den( double *fpss, timecode_hnd_t *h, int loop_num )
{
    h->timebase_num = 0;
    h->timebase_den = MKV_TIMEBASE_DEN;
    for( int num = 0; num < loop_num; num++ )
    {
        uint64_t fps_den;
        double exponent;
        double fps_sig = sigexp10( fpss[num], &exponent );
        fps_den = round( MKV_TIMEBASE_DEN / fps_sig ) / exponent;
        h->timebase_num = fps_den && h->timebase_num ? gcd( h->timebase_num, fps_den ) : fps_den;
        FAIL_IF_ERROR( h->timebase_num > UINT32_MAX || !h->timebase_num, "automatic timebase generation failed.\n"
                       "                  Specify timebase manually.\n" );
    }
    return 0;
}

static int parse_tcfile( FILE *tcfile_in, timecode_hnd_t *h, video_info_t *info )
{
    char buff[256];
    int ret, tcfv, num, seq_num, timecodes_num;
    double *timecodes = NULL;
    double *fpss = NULL;

    ret = fgets( buff, sizeof(buff), tcfile_in ) != NULL && 
          (sscanf( buff, "# timecode format v%d", &tcfv ) == 1 || sscanf( buff, "# timestamp format v%d", &tcfv ) == 1);
    FAIL_IF_ERROR( !ret || (tcfv != 1 && tcfv != 2), "unsupported timecode format\n" );
#define NO_TIMECODE_LINE (buff[0] == '#' || buff[0] == '\n' || buff[0] == '\r')
    if( tcfv == 1 )
    {
        int64_t file_pos;
        double assume_fps, seq_fps;
        int start, end = -1;
        int prev_start = -1, prev_end = -1;

        h->assume_fps = 0;
        for( num = 2; fgets( buff, sizeof(buff), tcfile_in ) != NULL; num++ )
        {
            if( NO_TIMECODE_LINE )
                continue;
            FAIL_IF_ERROR( sscanf( buff, "assume %lf", &h->assume_fps ) != 1 && sscanf( buff, "Assume %lf", &h->assume_fps ) != 1,
                           "tcfile parsing error: assumed fps not found\n" );
            break;
        }
        FAIL_IF_ERROR( h->assume_fps <= 0, "invalid assumed fps %.6f\n", h->assume_fps );

        file_pos = ftell( tcfile_in );
        h->stored_pts_num = 0;
        for( seq_num = 0; fgets( buff, sizeof(buff), tcfile_in ) != NULL; num++ )
        {
            if( NO_TIMECODE_LINE )
            {
                if( sscanf( buff, "# TDecimate Mode 3:  Last Frame = %d", &end ) == 1 )
                    h->stored_pts_num = end + 1;
                continue;
            }
            ret = sscanf( buff, "%d,%d,%lf", &start, &end, &seq_fps );
            FAIL_IF_ERROR( ret != 3 && ret != EOF, "invalid input tcfile\n" );
            FAIL_IF_ERROR( start > end || start <= prev_start || end <= prev_end || seq_fps <= 0,
                           "invalid input tcfile at line %d: %s\n", num, buff );
            prev_start = start;
            prev_end = end;
            if( h->auto_timebase_den || h->auto_timebase_num )
                ++seq_num;
        }
        if( !h->stored_pts_num )
            h->stored_pts_num = end + 2;
        timecodes_num = h->stored_pts_num;
        fseek( tcfile_in, file_pos, SEEK_SET );

        timecodes = malloc( timecodes_num * sizeof(double) );
        if( !timecodes )
            return -1;
        if( h->auto_timebase_den || h->auto_timebase_num )
        {
            fpss = malloc( (seq_num + 1) * sizeof(double) );
            if( !fpss )
                goto fail;
        }

        assume_fps = correct_fps( h->assume_fps, h );
        if( assume_fps < 0 )
            goto fail;
        timecodes[0] = 0;
        for( num = seq_num = 0; num < timecodes_num - 1 && fgets( buff, sizeof(buff), tcfile_in ) != NULL; )
        {
            if( NO_TIMECODE_LINE )
                continue;
            ret = sscanf( buff, "%d,%d,%lf", &start, &end, &seq_fps );
            if( ret != 3 )
                start = end = timecodes_num - 1;
            for( ; num < start && num < timecodes_num - 1; num++ )
                timecodes[num + 1] = timecodes[num] + 1 / assume_fps;
            if( num < timecodes_num - 1 )
            {
                if( h->auto_timebase_den || h->auto_timebase_num )
                    fpss[seq_num++] = seq_fps;
                seq_fps = correct_fps( seq_fps, h );
                if( seq_fps < 0 )
                    goto fail;
                for( num = start; num <= end && num < timecodes_num - 1; num++ )
                    timecodes[num + 1] = timecodes[num] + 1 / seq_fps;
            }
        }
        for( ; num < timecodes_num - 1; num++ )
            timecodes[num + 1] = timecodes[num] + 1 / assume_fps;
        if( h->auto_timebase_den || h->auto_timebase_num )
            fpss[seq_num] = h->assume_fps;

        if( h->auto_timebase_num && !h->auto_timebase_den )
        {
            double exponent;
            double assume_fps_sig, seq_fps_sig;
            if( try_mkv_timebase_den( fpss, h, seq_num + 1 ) < 0 )
                goto fail;
            fseek( tcfile_in, file_pos, SEEK_SET );
            assume_fps_sig = sigexp10( h->assume_fps, &exponent );
            assume_fps = MKV_TIMEBASE_DEN / ( round( MKV_TIMEBASE_DEN / assume_fps_sig ) / exponent );
            for( num = 0; num < timecodes_num - 1 && fgets( buff, sizeof(buff), tcfile_in ) != NULL; )
            {
                if( NO_TIMECODE_LINE )
                    continue;
                ret = sscanf( buff, "%d,%d,%lf", &start, &end, &seq_fps );
                if( ret != 3 )
                    start = end = timecodes_num - 1;
                seq_fps_sig = sigexp10( seq_fps, &exponent );
                seq_fps = MKV_TIMEBASE_DEN / ( round( MKV_TIMEBASE_DEN / seq_fps_sig ) / exponent );
                for( ; num < start && num < timecodes_num - 1; num++ )
                    timecodes[num + 1] = timecodes[num] + 1 / assume_fps;
                for( num = start; num <= end && num < timecodes_num - 1; num++ )
                    timecodes[num + 1] = timecodes[num] + 1 / seq_fps;
            }
            for( ; num < timecodes_num - 1; num++ )
                timecodes[num + 1] = timecodes[num] + 1 / assume_fps;
        }
        if( fpss )
        {
            free( fpss );
            fpss = NULL;
        }

        h->assume_fps = assume_fps;
        h->last_timecode = timecodes[timecodes_num - 1];
    }
    else    /* tcfv == 2 */
    {
        int64_t file_pos = ftell( tcfile_in );

        h->stored_pts_num = 0;
        while( fgets( buff, sizeof(buff), tcfile_in ) != NULL )
        {
            if( NO_TIMECODE_LINE )
            {
                if( !h->stored_pts_num )
                    file_pos = ftell( tcfile_in );
                continue;
            }
            h->stored_pts_num++;
        }
        timecodes_num = h->stored_pts_num;
        FAIL_IF_ERROR( !timecodes_num, "input tcfile doesn't have any timecodes!\n" );
        fseek( tcfile_in, file_pos, SEEK_SET );

        timecodes = malloc( timecodes_num * sizeof(double) );
        if( !timecodes )
            return -1;

        num = 0;
        if( fgets( buff, sizeof(buff), tcfile_in ) != NULL )
        {
            ret = sscanf( buff, "%lf", &timecodes[0] );
            timecodes[0] *= 1e-3;         /* Timecode format v2 is expressed in milliseconds. */
            FAIL_IF_ERROR( ret != 1, "invalid input tcfile for frame 0\n" );
            for( num = 1; num < timecodes_num && fgets( buff, sizeof(buff), tcfile_in ) != NULL; )
            {
                if( NO_TIMECODE_LINE )
                    continue;
                ret = sscanf( buff, "%lf", &timecodes[num] );
                timecodes[num] *= 1e-3;         /* Timecode format v2 is expressed in milliseconds. */
                FAIL_IF_ERROR( ret != 1 || timecodes[num] <= timecodes[num - 1],
                               "invalid input tcfile for frame %d\n", num );
                ++num;
            }
        }
        FAIL_IF_ERROR( num < timecodes_num, "failed to read input tcfile for frame %d", num );

        if( timecodes_num == 1 )
            h->timebase_den = info->fps_num;
        else if( h->auto_timebase_den )
        {
            fpss = malloc( (timecodes_num - 1) * sizeof(double) );
            if( !fpss )
                goto fail;
            for( num = 0; num < timecodes_num - 1; num++ )
            {
                fpss[num] = 1 / (timecodes[num + 1] - timecodes[num]);
                if( h->auto_timebase_den )
                {
                    int i = 1;
                    uint64_t fps_num, fps_den;
                    double exponent;
                    double fps_sig = sigexp10( fpss[num], &exponent );
                    while( 1 )
                    {
                        fps_den = i * h->timebase_num;
                        fps_num = round( fps_den * fps_sig ) * exponent;
                        if( fps_num > UINT32_MAX || fabs( ((double)fps_num / fps_den) / exponent - fps_sig ) < DOUBLE_EPSILON )
                            break;
                        ++i;
                    }
                    h->timebase_den = fps_num && h->timebase_den ? lcm( h->timebase_den, fps_num ) : fps_num;
                    if( h->timebase_den > UINT32_MAX )
                    {
                        h->auto_timebase_den = 0;
                        continue;
                    }
                }
            }
            if( h->auto_timebase_num && !h->auto_timebase_den )
                if( try_mkv_timebase_den( fpss, h, timecodes_num - 1 ) < 0 )
                    goto fail;
            free( fpss );
            fpss = NULL;
        }

        if( timecodes_num > 1 )
            h->assume_fps = 1 / (timecodes[timecodes_num - 1] - timecodes[timecodes_num - 2]);
        else
            h->assume_fps = (double)info->fps_num / info->fps_den;
        h->last_timecode = timecodes[timecodes_num - 1];
    }
#undef NO_TIMECODE_LINE
    if( h->auto_timebase_den || h->auto_timebase_num )
    {
        uint64_t i = gcd( h->timebase_num, h->timebase_den );
        h->timebase_num /= i;
        h->timebase_den /= i;
        x264_cli_log( "timecode", X264_LOG_INFO, "automatic timebase generation %"PRIu64"/%"PRIu64"\n", h->timebase_num, h->timebase_den );
    }
    else FAIL_IF_ERROR( h->timebase_den > UINT32_MAX || !h->timebase_den, "automatic timebase generation failed.\n"
                        "                  Specify an appropriate timebase manually.\n" );

    h->pts = malloc( h->stored_pts_num * sizeof(int64_t) );
    if( !h->pts )
        goto fail;
    for( num = 0; num < h->stored_pts_num; num++ )
    {
        h->pts[num] = timecodes[num] * ((double)h->timebase_den / h->timebase_num) + 0.5;
        FAIL_IF_ERROR( num > 0 && h->pts[num] <= h->pts[num - 1], "invalid timebase or timecode for frame %d\n", num );
    }

    free( timecodes );
    return 0;

fail:
    if( timecodes )
        free( timecodes );
    if( fpss )
        free( fpss );
    return -1;
}

#undef DOUBLE_EPSILON
#undef MKV_TIMEBASE_DEN

static int open_file( char *psz_filename, hnd_t *p_handle, video_info_t *info, cli_input_opt_t *opt )
{
    int ret = 0;
    FILE *tcfile_in;
    timecode_hnd_t *h = malloc( sizeof(timecode_hnd_t) );
    FAIL_IF_ERROR( !h, "malloc failed\n" );
    h->input = cli_input;
    h->p_handle = *p_handle;
    h->pts = NULL;
    if( opt->timebase )
    {
        ret = sscanf( opt->timebase, "%"SCNu64"/%"SCNu64, &h->timebase_num, &h->timebase_den );
        if( ret == 1 )
        {
            h->timebase_num = strtoul( opt->timebase, NULL, 10 );
            h->timebase_den = 0; /* set later by auto timebase generation */
        }
        FAIL_IF_ERROR( h->timebase_num > UINT32_MAX || h->timebase_den > UINT32_MAX,
                       "timebase you specified exceeds H.264 maximum\n" );
    }
    h->auto_timebase_num = !ret;
    h->auto_timebase_den = ret < 2;
    if( h->auto_timebase_num )
        h->timebase_num = info->fps_den; /* can be changed later by auto timebase generation */
    if( h->auto_timebase_den )
        h->timebase_den = 0;             /* set later by auto timebase generation */

    tcfile_in = x264_fopen( psz_filename, "rb" );
    FAIL_IF_ERROR( !tcfile_in, "can't open `%s'\n", psz_filename );
    if( !x264_is_regular_file( tcfile_in ) )
    {
        x264_cli_log( "timecode", X264_LOG_ERROR, "tcfile input incompatible with non-regular file `%s'\n", psz_filename );
        fclose( tcfile_in );
        return -1;
    }

    if( parse_tcfile( tcfile_in, h, info ) < 0 )
    {
        if( h->pts )
            free( h->pts );
        fclose( tcfile_in );
        return -1;
    }
    fclose( tcfile_in );

    info->timebase_num = h->timebase_num;
    info->timebase_den = h->timebase_den;
    info->vfr = 1;

    *p_handle = h;
    return 0;
}

static int64_t get_frame_pts( timecode_hnd_t *h, int frame, int real_frame )
{
    if( frame < h->stored_pts_num )
        return h->pts[frame];
    else
    {
        if( h->pts && real_frame )
        {
            x264_cli_log( "timecode", X264_LOG_INFO, "input timecode file missing data for frame %d and later\n"
                          "                 assuming constant fps %.6f\n", frame, h->assume_fps );
            free( h->pts );
            h->pts = NULL;
        }
        double timecode = h->last_timecode + 1 / h->assume_fps;
        if( real_frame )
            h->last_timecode = timecode;
        return timecode * ((double)h->timebase_den / h->timebase_num) + 0.5;
    }
}

static int read_frame( cli_pic_t *pic, hnd_t handle, int frame )
{
    timecode_hnd_t *h = handle;
    if( h->input.read_frame( pic, h->p_handle, frame ) )
        return -1;

    pic->pts = get_frame_pts( h, frame, 1 );
    pic->duration = get_frame_pts( h, frame + 1, 0 ) - pic->pts;

    return 0;
}

static int release_frame( cli_pic_t *pic, hnd_t handle )
{
    timecode_hnd_t *h = handle;
    if( h->input.release_frame )
        return h->input.release_frame( pic, h->p_handle );
    return 0;
}

static int picture_alloc( cli_pic_t *pic, hnd_t handle, int csp, int width, int height )
{
    timecode_hnd_t *h = handle;
    return h->input.picture_alloc( pic, h->p_handle, csp, width, height );
}

static void picture_clean( cli_pic_t *pic, hnd_t handle )
{
    timecode_hnd_t *h = handle;
    h->input.picture_clean( pic, h->p_handle );
}

static int close_file( hnd_t handle )
{
    timecode_hnd_t *h = handle;
    if( h->pts )
        free( h->pts );
    h->input.close_file( h->p_handle );
    free( h );
    return 0;
}

const cli_input_t timecode_input = { open_file, picture_alloc, read_frame, release_frame, picture_clean, close_file };
