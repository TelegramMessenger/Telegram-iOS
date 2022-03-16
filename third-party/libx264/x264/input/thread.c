/*****************************************************************************
 * thread.c: threaded input
 *****************************************************************************
 * Copyright (C) 2003-2022 x264 project
 *
 * Authors: Laurent Aimar <fenrir@via.ecp.fr>
 *          Loren Merritt <lorenm@u.washington.edu>
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
#include "common/common.h"

#define thread_input x264_glue3(thread, BIT_DEPTH, input)

typedef struct
{
    cli_input_t input;
    hnd_t p_handle;
    cli_pic_t pic;
    x264_threadpool_t *pool;
    int next_frame;
    int frame_total;
    struct thread_input_arg_t *next_args;
} thread_hnd_t;

typedef struct thread_input_arg_t
{
    thread_hnd_t *h;
    cli_pic_t *pic;
    int i_frame;
    int status;
} thread_input_arg_t;

static int open_file( char *psz_filename, hnd_t *p_handle, video_info_t *info, cli_input_opt_t *opt )
{
    thread_hnd_t *h = malloc( sizeof(thread_hnd_t) );
    FAIL_IF_ERR( !h || cli_input.picture_alloc( &h->pic, *p_handle, info->csp, info->width, info->height ),
                 "x264", "malloc failed\n" );
    h->input = cli_input;
    h->p_handle = *p_handle;
    h->next_frame = -1;
    h->next_args = malloc( sizeof(thread_input_arg_t) );
    if( !h->next_args )
        return -1;
    h->next_args->h = h;
    h->next_args->status = 0;
    h->frame_total = info->num_frames;

    if( x264_threadpool_init( &h->pool, 1 ) )
        return -1;

    *p_handle = h;
    return 0;
}

static void read_frame_thread_int( thread_input_arg_t *i )
{
    i->status = i->h->input.read_frame( i->pic, i->h->p_handle, i->i_frame );
}

static int read_frame( cli_pic_t *p_pic, hnd_t handle, int i_frame )
{
    thread_hnd_t *h = handle;
    int ret = 0;

    if( h->next_frame >= 0 )
    {
        x264_threadpool_wait( h->pool, h->next_args );
        ret |= h->next_args->status;
    }

    if( h->next_frame == i_frame )
        XCHG( cli_pic_t, *p_pic, h->pic );
    else
    {
        if( h->next_frame >= 0 )
            thread_input.release_frame( &h->pic, handle );
        ret |= h->input.read_frame( p_pic, h->p_handle, i_frame );
    }

    if( !h->frame_total || i_frame+1 < h->frame_total )
    {
        h->next_frame =
        h->next_args->i_frame = i_frame+1;
        h->next_args->pic = &h->pic;
        x264_threadpool_run( h->pool, (void*)read_frame_thread_int, h->next_args );
    }
    else
        h->next_frame = -1;

    return ret;
}

static int release_frame( cli_pic_t *pic, hnd_t handle )
{
    thread_hnd_t *h = handle;
    if( h->input.release_frame )
        return h->input.release_frame( pic, h->p_handle );
    return 0;
}

static int picture_alloc( cli_pic_t *pic, hnd_t handle, int csp, int width, int height )
{
    thread_hnd_t *h = handle;
    return h->input.picture_alloc( pic, h->p_handle, csp, width, height );
}

static void picture_clean( cli_pic_t *pic, hnd_t handle )
{
    thread_hnd_t *h = handle;
    h->input.picture_clean( pic, h->p_handle );
}

static int close_file( hnd_t handle )
{
    thread_hnd_t *h = handle;
    x264_threadpool_delete( h->pool );
    h->input.picture_clean( &h->pic, h->p_handle );
    h->input.close_file( h->p_handle );
    free( h->next_args );
    free( h );
    return 0;
}

const cli_input_t thread_input = { open_file, picture_alloc, read_frame, release_frame, picture_clean, close_file };
