/*****************************************************************************
 * video.c: video filters
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

static cli_vid_filter_t *first_filter = NULL;

static void register_vid_filter( cli_vid_filter_t *new_filter )
{
    cli_vid_filter_t *filter_i = first_filter;
    while( filter_i->next )
        filter_i = filter_i->next;
    filter_i->next = new_filter;
    new_filter->next = NULL;
}

#define REGISTER_VFILTER(name)\
{\
    extern cli_vid_filter_t name##_filter;\
    register_vid_filter( &name##_filter );\
}

void x264_register_vid_filters( void )
{
    extern cli_vid_filter_t source_filter;
    first_filter = &source_filter;
#if HAVE_BITDEPTH8
    REGISTER_VFILTER( cache_8 );
    REGISTER_VFILTER( depth_8 );
#endif
#if HAVE_BITDEPTH10
    REGISTER_VFILTER( cache_10 );
    REGISTER_VFILTER( depth_10 );
#endif
    REGISTER_VFILTER( crop );
    REGISTER_VFILTER( fix_vfr_pts );
    REGISTER_VFILTER( resize );
    REGISTER_VFILTER( select_every );
#if HAVE_GPL
#endif
}

int x264_init_vid_filter( const char *name, hnd_t *handle, cli_vid_filter_t *filter,
                          video_info_t *info, x264_param_t *param, char *opt_string )
{
    cli_vid_filter_t *filter_i = first_filter;
    while( filter_i && strcasecmp( name, filter_i->name ) )
        filter_i = filter_i->next;
    FAIL_IF_ERR( !filter_i, "x264", "invalid filter `%s'\n", name );
    if( filter_i->init( handle, filter, info, param, opt_string ) )
        return -1;

    return 0;
}

void x264_vid_filter_help( int longhelp )
{
    for( cli_vid_filter_t *filter_i = first_filter; filter_i; filter_i = filter_i->next )
        if( filter_i->help )
            filter_i->help( longhelp );
}
