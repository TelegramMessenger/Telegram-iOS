/*****************************************************************************
 * raw.c: raw input
 *****************************************************************************
 * Copyright (C) 2003-2022 x264 project
 *
 * Authors: Laurent Aimar <fenrir@via.ecp.fr>
 *          Loren Merritt <lorenm@u.washington.edu>
 *          Steven Walters <kemuri9@gmail.com>
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

#define FAIL_IF_ERROR( cond, ... ) FAIL_IF_ERR( cond, "raw", __VA_ARGS__ )

typedef struct
{
    FILE *fh;
    int next_frame;
    int64_t plane_size[4];
    int64_t frame_size;
    int bit_depth;
    cli_mmap_t mmap;
    int use_mmap;
} raw_hnd_t;

static int open_file( char *psz_filename, hnd_t *p_handle, video_info_t *info, cli_input_opt_t *opt )
{
    raw_hnd_t *h = calloc( 1, sizeof(raw_hnd_t) );
    if( !h )
        return -1;

    if( !opt->resolution )
    {
        /* try to parse the file name */
        for( char *p = psz_filename; *p; p++ )
            if( *p >= '0' && *p <= '9' && sscanf( p, "%dx%d", &info->width, &info->height ) == 2 )
                break;
    }
    else
        sscanf( opt->resolution, "%dx%d", &info->width, &info->height );
    FAIL_IF_ERROR( !info->width || !info->height, "raw input requires a resolution.\n" );
    if( opt->colorspace )
    {
        for( info->csp = X264_CSP_CLI_MAX-1; info->csp > X264_CSP_NONE; info->csp-- )
        {
            if( x264_cli_csps[info->csp].name && !strcasecmp( x264_cli_csps[info->csp].name, opt->colorspace ) )
                break;
        }
        FAIL_IF_ERROR( info->csp == X264_CSP_NONE, "unsupported colorspace `%s'\n", opt->colorspace );
    }
    else /* default */
        info->csp = X264_CSP_I420;

    h->bit_depth = opt->bit_depth;
    FAIL_IF_ERROR( h->bit_depth < 8 || h->bit_depth > 16, "unsupported bit depth `%d'\n", h->bit_depth );
    if( h->bit_depth > 8 )
        info->csp |= X264_CSP_HIGH_DEPTH;

    if( !strcmp( psz_filename, "-" ) )
        h->fh = stdin;
    else
        h->fh = x264_fopen( psz_filename, "rb" );
    if( h->fh == NULL )
        return -1;

    info->thread_safe = 1;
    info->num_frames  = 0;
    info->vfr         = 0;

    const x264_cli_csp_t *csp = x264_cli_get_csp( info->csp );
    for( int i = 0; i < csp->planes; i++ )
    {
        h->plane_size[i] = x264_cli_pic_plane_size( info->csp, info->width, info->height, i );
        h->frame_size += h->plane_size[i];
        /* x264_cli_pic_plane_size returns the size in bytes, we need the value in pixels from here on */
        h->plane_size[i] /= x264_cli_csp_depth_factor( info->csp );
    }

    if( x264_is_regular_file( h->fh ) )
    {
        fseek( h->fh, 0, SEEK_END );
        int64_t size = ftell( h->fh );
        fseek( h->fh, 0, SEEK_SET );
        info->num_frames = size / h->frame_size;
        FAIL_IF_ERROR( !info->num_frames, "empty input file\n" );

        /* Attempt to use memory-mapped input frames if possible */
        if( !(h->bit_depth & 7) )
            h->use_mmap = !x264_cli_mmap_init( &h->mmap, h->fh );
    }

    *p_handle = h;
    return 0;
}

static int read_frame_internal( cli_pic_t *pic, raw_hnd_t *h, int bit_depth_uc )
{
    int pixel_depth = x264_cli_csp_depth_factor( pic->img.csp );

    for( int i = 0; i < pic->img.planes; i++ )
    {
        if( h->use_mmap )
        {
            if( i )
                pic->img.plane[i] = pic->img.plane[i-1] + pixel_depth * h->plane_size[i-1];
        }
        else if( fread( pic->img.plane[i], pixel_depth, h->plane_size[i], h->fh ) != (uint64_t)h->plane_size[i] )
            return -1;

        if( bit_depth_uc )
        {
            /* upconvert non 16bit high depth planes to 16bit using the same
             * algorithm as used in the depth filter. */
            uint16_t *plane = (uint16_t*)pic->img.plane[i];
            int64_t pixel_count = h->plane_size[i];
            int lshift = 16 - h->bit_depth;
            for( int64_t j = 0; j < pixel_count; j++ )
                plane[j] = plane[j] << lshift;
        }
    }
    return 0;
}

static int read_frame( cli_pic_t *pic, hnd_t handle, int i_frame )
{
    raw_hnd_t *h = handle;

    if( h->use_mmap )
    {
        pic->img.plane[0] = x264_cli_mmap( &h->mmap, i_frame * h->frame_size, h->frame_size );
        if( !pic->img.plane[0] )
            return -1;
    }
    else if( i_frame > h->next_frame )
    {
        if( x264_is_regular_file( h->fh ) )
            fseek( h->fh, i_frame * h->frame_size, SEEK_SET );
        else
            while( i_frame > h->next_frame )
            {
                if( read_frame_internal( pic, h, 0 ) )
                    return -1;
                h->next_frame++;
            }
    }

    if( read_frame_internal( pic, h, h->bit_depth & 7 ) )
        return -1;

    h->next_frame = i_frame+1;
    return 0;
}

static int release_frame( cli_pic_t *pic, hnd_t handle )
{
    raw_hnd_t *h = handle;
    if( h->use_mmap )
        return x264_cli_munmap( &h->mmap, pic->img.plane[0], h->frame_size );
    return 0;
}

static int picture_alloc( cli_pic_t *pic, hnd_t handle, int csp, int width, int height )
{
    raw_hnd_t *h = handle;
    return (h->use_mmap ? x264_cli_pic_init_noalloc : x264_cli_pic_alloc)( pic, csp, width, height );
}

static void picture_clean( cli_pic_t *pic, hnd_t handle )
{
    raw_hnd_t *h = handle;
    if( h->use_mmap )
        memset( pic, 0, sizeof(cli_pic_t) );
    else
        x264_cli_pic_clean( pic );
}

static int close_file( hnd_t handle )
{
    raw_hnd_t *h = handle;
    if( !h || !h->fh )
        return 0;
    if( h->use_mmap )
        x264_cli_mmap_close( &h->mmap );
    fclose( h->fh );
    free( h );
    return 0;
}

const cli_input_t raw_input = { open_file, picture_alloc, read_frame, release_frame, picture_clean, close_file };
