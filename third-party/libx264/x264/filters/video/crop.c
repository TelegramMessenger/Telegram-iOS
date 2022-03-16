/*****************************************************************************
 * crop.c: crop video filter
 *****************************************************************************
 * Copyright (C) 2010-2022 x264 project
 *
 * Authors: Steven Walters <kemuri9@gmail.com>
 *          James Darnley <james.darnley@gmail.com>
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

#define NAME "crop"
#define FAIL_IF_ERROR( cond, ... ) FAIL_IF_ERR( cond, NAME, __VA_ARGS__ )

cli_vid_filter_t crop_filter;

typedef struct
{
    hnd_t prev_hnd;
    cli_vid_filter_t prev_filter;

    int dims[4]; /* left, top, width, height */
    const x264_cli_csp_t *csp;
} crop_hnd_t;

static void help( int longhelp )
{
    printf( "      "NAME":left,top,right,bottom\n" );
    if( !longhelp )
        return;
    printf( "            removes pixels from the edges of the frame\n" );
}

static int handle_opts( crop_hnd_t *h, video_info_t *info, char **opts, const char * const *optlist )
{
    for( int i = 0; i < 4; i++ )
    {
        char *opt = x264_get_option( optlist[i], opts );
        FAIL_IF_ERROR( !opt, "%s crop value not specified\n", optlist[i] );
        h->dims[i] = x264_otoi( opt, -1 );
        FAIL_IF_ERROR( h->dims[i] < 0, "%s crop value `%s' is less than 0\n", optlist[i], opt );
        int dim_mod = i&1 ? (h->csp->mod_height << info->interlaced) : h->csp->mod_width;
        FAIL_IF_ERROR( h->dims[i] % dim_mod, "%s crop value `%s' is not a multiple of %d\n", optlist[i], opt, dim_mod );
    }
    return 0;
}

static int init( hnd_t *handle, cli_vid_filter_t *filter, video_info_t *info, x264_param_t *param, char *opt_string )
{
    FAIL_IF_ERROR( x264_cli_csp_is_invalid( info->csp ), "invalid csp %d\n", info->csp );
    crop_hnd_t *h = calloc( 1, sizeof(crop_hnd_t) );
    if( !h )
        return -1;

    h->csp = x264_cli_get_csp( info->csp );
    static const char * const optlist[] = { "left", "top", "right", "bottom", NULL };
    char **opts = x264_split_options( opt_string, optlist );
    if( !opts )
        return -1;

    int err = handle_opts( h, info, opts, optlist );
    free( opts );
    if( err )
        return -1;

    h->dims[2] = info->width  - h->dims[0] - h->dims[2];
    h->dims[3] = info->height - h->dims[1] - h->dims[3];
    FAIL_IF_ERROR( h->dims[2] <= 0 || h->dims[3] <= 0, "invalid output resolution %dx%d\n", h->dims[2], h->dims[3] );

    if( info->width != h->dims[2] || info->height != h->dims[3] )
        x264_cli_log( NAME, X264_LOG_INFO, "cropping to %dx%d\n", h->dims[2], h->dims[3] );
    else
    {
        /* do nothing as the user supplied 0s for all the values */
        free( h );
        return 0;
    }
    /* done initializing, overwrite values */
    info->width  = h->dims[2];
    info->height = h->dims[3];

    h->prev_filter = *filter;
    h->prev_hnd = *handle;
    *handle = h;
    *filter = crop_filter;

    return 0;
}

static int get_frame( hnd_t handle, cli_pic_t *output, int frame )
{
    crop_hnd_t *h = handle;
    if( h->prev_filter.get_frame( h->prev_hnd, output, frame ) )
        return -1;
    output->img.width  = h->dims[2];
    output->img.height = h->dims[3];
    /* shift the plane pointers down 'top' rows and right 'left' columns. */
    for( int i = 0; i < output->img.planes; i++ )
    {
        intptr_t offset = output->img.stride[i] * h->dims[1] * h->csp->height[i];
        offset += h->dims[0] * h->csp->width[i] * x264_cli_csp_depth_factor( output->img.csp );
        output->img.plane[i] += offset;
    }
    return 0;
}

static int release_frame( hnd_t handle, cli_pic_t *pic, int frame )
{
    crop_hnd_t *h = handle;
    /* NO filter should ever have a dependent release based on the plane pointers,
     * so avoid unnecessary unshifting */
    return h->prev_filter.release_frame( h->prev_hnd, pic, frame );
}

static void free_filter( hnd_t handle )
{
    crop_hnd_t *h = handle;
    h->prev_filter.free( h->prev_hnd );
    free( h );
}

cli_vid_filter_t crop_filter = { NAME, help, init, get_frame, release_frame, free_filter, NULL };
