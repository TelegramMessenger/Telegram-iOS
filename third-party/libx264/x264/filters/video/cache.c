/*****************************************************************************
 * cache.c: cache video filter
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
#include "internal.h"
#include "common/common.h"

#define cache_filter x264_glue3(cache, BIT_DEPTH, filter)
#if BIT_DEPTH == 8
#define NAME "cache_8"
#else
#define NAME "cache_10"
#endif

#define LAST_FRAME (h->first_frame + h->cur_size - 1)

typedef struct
{
    hnd_t prev_hnd;
    cli_vid_filter_t prev_filter;

    int max_size;
    int first_frame; /* first cached frame */
    cli_pic_t **cache;
    int cur_size;
    int eof;         /* frame beyond end of the file */
} cache_hnd_t;

cli_vid_filter_t cache_filter;

static int init( hnd_t *handle, cli_vid_filter_t *filter, video_info_t *info, x264_param_t *param, char *opt_string )
{
    intptr_t size = (intptr_t)opt_string;
    /* upon a <= 0 cache request, do nothing */
    if( size <= 0 )
        return 0;
    cache_hnd_t *h = calloc( 1, sizeof(cache_hnd_t) );
    if( !h )
        return -1;

    h->max_size = size;
    h->cache = malloc( (h->max_size+1) * sizeof(cli_pic_t*) );
    if( !h->cache )
        return -1;

    for( int i = 0; i < h->max_size; i++ )
    {
        h->cache[i] = malloc( sizeof(cli_pic_t) );
        if( !h->cache[i] || x264_cli_pic_alloc( h->cache[i], info->csp, info->width, info->height ) )
            return -1;
    }
    h->cache[h->max_size] = NULL; /* require null terminator for list methods */

    h->prev_filter = *filter;
    h->prev_hnd = *handle;
    *handle = h;
    *filter = cache_filter;

    return 0;
}

static void fill_cache( cache_hnd_t *h, int frame )
{
    /* shift frames out of the cache as the frame request is beyond the filled cache */
    int shift = frame - LAST_FRAME;
    /* no frames to shift or no frames left to read */
    if( shift <= 0 || h->eof )
        return;
    /* the next frames to read are either
     * A) starting at the end of the current cache, or
     * B) starting at a new frame that has the end of the cache at the desired frame
     * and proceeding to fill the entire cache */
    int cur_frame = X264_MAX( h->first_frame + h->cur_size, frame - h->max_size + 1 );
    /* the new starting point is either
     * A) the current one shifted the number of frames entering/leaving the cache, or
     * B) at a new frame that has the end of the cache at the desired frame. */
    h->first_frame = X264_MIN( h->first_frame + shift, cur_frame );
    h->cur_size = X264_MAX( h->cur_size - shift, 0 );
    while( h->cur_size < h->max_size )
    {
        cli_pic_t temp;
        /* the old front frame is going to shift off, overwrite it with the new frame */
        cli_pic_t *cache = h->cache[0];
        if( h->prev_filter.get_frame( h->prev_hnd, &temp, cur_frame ) ||
            x264_cli_pic_copy( cache, &temp ) ||
            h->prev_filter.release_frame( h->prev_hnd, &temp, cur_frame ) )
        {
            h->eof = cur_frame;
            return;
        }
        /* the read was successful, shift the frame off the front to the end */
        x264_frame_push( (void*)h->cache, x264_frame_shift( (void*)h->cache ) );
        cur_frame++;
        h->cur_size++;
    }
}

static int get_frame( hnd_t handle, cli_pic_t *output, int frame )
{
    cache_hnd_t *h = handle;
    FAIL_IF_ERR( frame < h->first_frame, NAME, "frame %d is before first cached frame %d \n", frame, h->first_frame );
    fill_cache( h, frame );
    if( frame > LAST_FRAME ) /* eof */
        return -1;
    int idx = frame - (h->eof ? h->eof - h->max_size : h->first_frame);
    *output = *h->cache[idx];
    return 0;
}

static int release_frame( hnd_t handle, cli_pic_t *pic, int frame )
{
    /* the parent filter's frame has already been released so do nothing here */
    return 0;
}

static void free_filter( hnd_t handle )
{
    cache_hnd_t *h = handle;
    h->prev_filter.free( h->prev_hnd );
    for( int i = 0; i < h->max_size; i++ )
    {
        x264_cli_pic_clean( h->cache[i] );
        free( h->cache[i] );
    }
    free( h->cache );
    free( h );
}

cli_vid_filter_t cache_filter = { NAME, NULL, init, get_frame, release_frame, free_filter, NULL };
