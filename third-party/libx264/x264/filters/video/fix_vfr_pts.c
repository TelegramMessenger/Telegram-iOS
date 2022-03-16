/*****************************************************************************
 * fix_vfr_pts.c: vfr pts fixing video filter
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

/* This filter calculates and store the frame's duration to the frame data
 * (if it is not already calculated when the frame arrives to this point)
 * so it can be used by filters that will need to reconstruct pts due to
 * out-of-order frame requests */

typedef struct
{
    hnd_t prev_hnd;
    cli_vid_filter_t prev_filter;

    /* we need 1 buffer picture and 1 place holder */
    cli_pic_t buffer;
    cli_pic_t holder;
    int buffer_allocated;
    int holder_frame;
    int holder_ret;
    int64_t pts;
    int64_t last_duration;
} fix_vfr_pts_hnd_t;

cli_vid_filter_t fix_vfr_pts_filter;

static int init( hnd_t *handle, cli_vid_filter_t *filter, video_info_t *info, x264_param_t *param, char *opt_string )
{
    /* if the input is not vfr, we don't do anything */
    if( !info->vfr )
        return 0;
    fix_vfr_pts_hnd_t *h = calloc( 1, sizeof(fix_vfr_pts_hnd_t) );
    if( !h )
        return -1;

    h->holder_frame = -1;
    h->prev_hnd = *handle;
    h->prev_filter = *filter;
    *handle = h;
    *filter = fix_vfr_pts_filter;

    return 0;
}

static int get_frame( hnd_t handle, cli_pic_t *output, int frame )
{
    fix_vfr_pts_hnd_t *h = handle;
    /* if we want the holder picture and it errored, return the error. */
    if( frame == h->holder_frame )
    {
        if( h->holder_ret )
            return h->holder_ret;
    }
    else
    {
        /* if we have a holder frame and we don't want it, release the frame */
        if( h->holder_frame > 0 && h->holder_frame < frame && h->prev_filter.release_frame( h->prev_hnd, &h->holder, h->holder_frame ) )
            return -1;
        h->holder_frame = -1;
        if( h->prev_filter.get_frame( h->prev_hnd, &h->holder, frame ) )
            return -1;
    }

    /* if the frame's duration is not set already, read the next frame to set it. */
    if( !h->holder.duration )
    {
        /* allocate a buffer picture if we didn't already */
        if( !h->buffer_allocated )
        {
            if( x264_cli_pic_alloc( &h->buffer, h->holder.img.csp, h->holder.img.width, h->holder.img.height ) )
                return -1;
            h->buffer_allocated = 1;
        }
        h->holder_frame = frame+1;
        /* copy the current frame to the buffer, release it, and then read in the next frame to the placeholder */
        if( x264_cli_pic_copy( &h->buffer, &h->holder ) || h->prev_filter.release_frame( h->prev_hnd, &h->holder, frame ) )
            return -1;
        h->holder_ret = h->prev_filter.get_frame( h->prev_hnd, &h->holder, h->holder_frame );
        /* suppress non-monotonic pts warnings by setting the duration to be at least 1 */
        if( !h->holder_ret )
            h->last_duration = X264_MAX( h->holder.pts - h->buffer.pts, 1 );
        h->buffer.duration = h->last_duration;
        *output = h->buffer;
    }
    else
        *output = h->holder;

    output->pts = h->pts;
    h->pts += output->duration;

    return 0;
}

static int release_frame( hnd_t handle, cli_pic_t *pic, int frame )
{
    fix_vfr_pts_hnd_t *h = handle;
    /* if the frame is the buffered one, it's already been released */
    if( frame == (h->holder_frame - 1) )
        return 0;
    return h->prev_filter.release_frame( h->prev_hnd, pic, frame );
}

static void free_filter( hnd_t handle )
{
    fix_vfr_pts_hnd_t *h = handle;
    h->prev_filter.free( h->prev_hnd );
    if( h->buffer_allocated )
        x264_cli_pic_clean( &h->buffer );
    free( h );
}

cli_vid_filter_t fix_vfr_pts_filter = { "fix_vfr_pts", NULL, init, get_frame, release_frame, free_filter, NULL };
