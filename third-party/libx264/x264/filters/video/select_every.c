/*****************************************************************************
 * select_every.c: select-every video filter
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

#define NAME "select_every"
#define FAIL_IF_ERROR( cond, ... ) FAIL_IF_ERR( cond, NAME, __VA_ARGS__ )

#define MAX_PATTERN_SIZE 100 /* arbitrary */

typedef struct
{
    hnd_t prev_hnd;
    cli_vid_filter_t prev_filter;

    int *pattern;
    int pattern_len;
    int step_size;
    int vfr;
    int64_t pts;
} selvry_hnd_t;

cli_vid_filter_t select_every_filter;

static void help( int longhelp )
{
    printf( "      "NAME":step,offset1[,...]\n" );
    if( !longhelp )
        return;
    printf( "            apply a selection pattern to input frames\n"
            "            step: the number of frames in the pattern\n"
            "            offsets: the offset into the step to select a frame\n"
            "            see: http://avisynth.nl/index.php/Select#SelectEvery\n" );
}

static int init( hnd_t *handle, cli_vid_filter_t *filter, video_info_t *info, x264_param_t *param, char *opt_string )
{
    selvry_hnd_t *h = malloc( sizeof(selvry_hnd_t) );
    if( !h )
        return -1;
    h->pattern_len = 0;
    h->step_size = 0;
    int offsets[MAX_PATTERN_SIZE];
    for( char *tok, *p = opt_string, UNUSED *saveptr = NULL; (tok = strtok_r( p, ",", &saveptr )); p = NULL )
    {
        int val = x264_otoi( tok, -1 );
        if( p )
        {
            FAIL_IF_ERROR( val <= 0, "invalid step `%s'\n", tok );
            h->step_size = val;
            continue;
        }
        FAIL_IF_ERROR( val < 0 || val >= h->step_size, "invalid offset `%s'\n", tok );
        FAIL_IF_ERROR( h->pattern_len >= MAX_PATTERN_SIZE, "max pattern size %d reached\n", MAX_PATTERN_SIZE );
        offsets[h->pattern_len++] = val;
    }
    FAIL_IF_ERROR( !h->step_size, "no step size provided\n" );
    FAIL_IF_ERROR( !h->pattern_len, "no offsets supplied\n" );

    h->pattern = malloc( h->pattern_len * sizeof(int) );
    if( !h->pattern )
        return -1;
    memcpy( h->pattern, offsets, h->pattern_len * sizeof(int) );

    /* determine required cache size to maintain pattern. */
    intptr_t max_rewind = 0;
    int min = h->step_size;
    for( int i = h->pattern_len-1; i >= 0; i-- )
    {
         min = X264_MIN( min, offsets[i] );
         if( i )
             max_rewind = X264_MAX( max_rewind, offsets[i-1] - min + 1 );
         /* reached maximum rewind size */
         if( max_rewind == h->step_size )
             break;
    }
    char name[20];
    sprintf( name, "cache_%d", param->i_bitdepth );
    if( x264_init_vid_filter( name, handle, filter, info, param, (void*)max_rewind ) )
        return -1;

    /* done initing, overwrite properties */
    if( h->step_size != h->pattern_len )
    {
        info->num_frames = (uint64_t)info->num_frames * h->pattern_len / h->step_size;
        info->fps_den *= h->step_size;
        info->fps_num *= h->pattern_len;
        x264_reduce_fraction( &info->fps_num, &info->fps_den );
        if( info->vfr )
        {
            info->timebase_den *= h->pattern_len;
            info->timebase_num *= h->step_size;
            x264_reduce_fraction( &info->timebase_num, &info->timebase_den );
        }
    }

    h->pts = 0;
    h->vfr = info->vfr;
    h->prev_filter = *filter;
    h->prev_hnd = *handle;
    *filter = select_every_filter;
    *handle = h;

    return 0;
}

static int get_frame( hnd_t handle, cli_pic_t *output, int frame )
{
    selvry_hnd_t *h = handle;
    int pat_frame = h->pattern[frame % h->pattern_len] + frame / h->pattern_len * h->step_size;
    if( h->prev_filter.get_frame( h->prev_hnd, output, pat_frame ) )
        return -1;
    if( h->vfr )
    {
        output->pts = h->pts;
        h->pts += output->duration;
    }
    return 0;
}

static int release_frame( hnd_t handle, cli_pic_t *pic, int frame )
{
    selvry_hnd_t *h = handle;
    int pat_frame = h->pattern[frame % h->pattern_len] + frame / h->pattern_len * h->step_size;
    return h->prev_filter.release_frame( h->prev_hnd, pic, pat_frame );
}

static void free_filter( hnd_t handle )
{
    selvry_hnd_t *h = handle;
    h->prev_filter.free( h->prev_hnd );
    free( h->pattern );
    free( h );
}

cli_vid_filter_t select_every_filter = { NAME, help, init, get_frame, release_frame, free_filter, NULL };
