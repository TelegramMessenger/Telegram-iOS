/*****************************************************************************
 * video.h: video filters
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

#ifndef X264_FILTER_VIDEO_H
#define X264_FILTER_VIDEO_H

#include "input/input.h"
#include "filters/filters.h"

typedef struct cli_vid_filter_t cli_vid_filter_t;

struct cli_vid_filter_t
{
    /* name of the filter */
    const char *name;
    /* help: a short message on what the filter does and how to use it.
     * this should only be implemented by filters directly accessible by the user */
    void (*help)( int longhelp );
    /* init: initializes the filter given the input clip properties and parameter to adjust them as necessary
     * with the given options provided by the user.
     * returns 0 on success, nonzero on error. */
    int (*init)( hnd_t *handle, cli_vid_filter_t *filter, video_info_t *info, x264_param_t *param, char *opt_string );
    /* get_frame: given the storage for the output frame and desired frame number, generate the frame accordingly.
     * the image data returned by get_frame should be treated as const and not be altered.
     * returns 0 on success, nonzero on error. */
    int (*get_frame)( hnd_t handle, cli_pic_t *output, int frame );
    /* release_frame: frame is done being used and is signaled for cleanup.
     * returns 0 on succeess, nonzero on error. */
    int (*release_frame)( hnd_t handle, cli_pic_t *pic, int frame );
    /* free: run filter cleanup procedures. */
    void (*free)( hnd_t handle );
    /* next registered filter, unused by filters themselves */
    cli_vid_filter_t *next;
};

void x264_register_vid_filters( void );
void x264_vid_filter_help( int longhelp );
int  x264_init_vid_filter( const char *name, hnd_t *handle, cli_vid_filter_t *filter,
                           video_info_t *info, x264_param_t *param, char *opt_string );

#endif
