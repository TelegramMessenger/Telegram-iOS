/*****************************************************************************
 * y4m.c: y4m input
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

#define FAIL_IF_ERROR( cond, ... ) FAIL_IF_ERR( cond, "y4m", __VA_ARGS__ )

typedef struct
{
    FILE *fh;
    int next_frame;
    int seq_header_len;
    int frame_header_len;
    int64_t frame_size;
    int64_t plane_size[3];
    int bit_depth;
    cli_mmap_t mmap;
    int use_mmap;
} y4m_hnd_t;

#define Y4M_MAGIC "YUV4MPEG2"
#define Y4M_FRAME_MAGIC "FRAME"
#define Y4M_MAX_HEADER 256

static int parse_csp_and_depth( char *csp_name, int *bit_depth )
{
    int csp = X264_CSP_MAX;

    /* Set colorspace from known variants */
    if( !strncmp( "mono", csp_name, 4 ) )
        csp = X264_CSP_I400;
    else if( !strncmp( "420", csp_name, 3 ) )
        csp = X264_CSP_I420;
    else if( !strncmp( "422", csp_name, 3 ) )
        csp = X264_CSP_I422;
    else if( !strncmp( "444", csp_name, 3 ) && strncmp( "444alpha", csp_name, 8 ) ) // only accept alphaless 4:4:4
        csp = X264_CSP_I444;

    /* Set high bit depth from known extensions */
    if( sscanf( csp_name, "mono%d", bit_depth ) != 1 &&
        sscanf( csp_name, "%*d%*[pP]%d", bit_depth ) != 1 )
        *bit_depth = 8;

    return csp;
}

static int open_file( char *psz_filename, hnd_t *p_handle, video_info_t *info, cli_input_opt_t *opt )
{
    y4m_hnd_t *h = calloc( 1, sizeof(y4m_hnd_t) );
    int i;
    uint32_t n, d;
    char header[Y4M_MAX_HEADER+10];
    char *tokend, *header_end;
    int colorspace = X264_CSP_NONE;
    int alt_colorspace = X264_CSP_NONE;
    int alt_bit_depth  = 8;
    if( !h )
        return -1;

    info->vfr = 0;

    if( !strcmp( psz_filename, "-" ) )
        h->fh = stdin;
    else
        h->fh = x264_fopen(psz_filename, "rb");
    if( h->fh == NULL )
        return -1;

    /* Read header */
    for( i = 0; i < Y4M_MAX_HEADER; i++ )
    {
        header[i] = fgetc( h->fh );
        if( header[i] == '\n' )
        {
            /* Add a space after last option. Makes parsing "444" vs
               "444alpha" easier. */
            header[i+1] = 0x20;
            header[i+2] = 0;
            break;
        }
    }
    FAIL_IF_ERROR( strncmp( header, Y4M_MAGIC, sizeof(Y4M_MAGIC)-1 ), "bad sequence header magic\n" );
    FAIL_IF_ERROR( i == Y4M_MAX_HEADER, "bad sequence header length\n" );

    /* Scan properties */
    header_end = &header[i+1]; /* Include space */
    h->seq_header_len = i+1;
    for( char *tokstart = header + sizeof(Y4M_MAGIC); tokstart < header_end; tokstart++ )
    {
        if( *tokstart == 0x20 )
            continue;
        switch( *tokstart++ )
        {
            case 'W': /* Width. Required. */
                info->width = strtol( tokstart, &tokend, 10 );
                tokstart=tokend;
                break;
            case 'H': /* Height. Required. */
                info->height = strtol( tokstart, &tokend, 10 );
                tokstart=tokend;
                break;
            case 'C': /* Color space */
                colorspace = parse_csp_and_depth( tokstart, &h->bit_depth );
                tokstart = strchr( tokstart, 0x20 );
                break;
            case 'I': /* Interlace type */
                switch( *tokstart++ )
                {
                    case 't':
                        info->interlaced = 1;
                        info->tff = 1;
                        break;
                    case 'b':
                        info->interlaced = 1;
                        info->tff = 0;
                        break;
                    case 'm':
                        info->interlaced = 1;
                        break;
                    //case '?':
                    //case 'p':
                    default:
                        break;
                }
                break;
            case 'F': /* Frame rate - 0:0 if unknown */
                if( sscanf( tokstart, "%u:%u", &n, &d ) == 2 && n && d )
                {
                    x264_reduce_fraction( &n, &d );
                    info->fps_num = n;
                    info->fps_den = d;
                }
                tokstart = strchr( tokstart, 0x20 );
                break;
            case 'A': /* Pixel aspect - 0:0 if unknown */
                /* Don't override the aspect ratio if sar has been explicitly set on the commandline. */
                if( sscanf( tokstart, "%u:%u", &n, &d ) == 2 && n && d )
                {
                    x264_reduce_fraction( &n, &d );
                    info->sar_width  = n;
                    info->sar_height = d;
                }
                tokstart = strchr( tokstart, 0x20 );
                break;
            case 'X': /* Vendor extensions */
                if( !strncmp( "YSCSS=", tokstart, 6 ) )
                {
                    /* Older nonstandard pixel format representation */
                    tokstart += 6;
                    alt_colorspace = parse_csp_and_depth( tokstart, &alt_bit_depth );
                }
                else if( !strncmp( "COLORRANGE=", tokstart, 11 ) )
                {
                    /* ffmpeg's color range extension */
                    tokstart += 11;
                    if( !strncmp( "FULL", tokstart, 4 ) )
                        info->fullrange = 1;
                    else if( !strncmp( "LIMITED", tokstart, 7 ) )
                        info->fullrange = 0;
                }
                tokstart = strchr( tokstart, 0x20 );
                break;
        }
    }

    if( colorspace == X264_CSP_NONE )
    {
        colorspace   = alt_colorspace;
        h->bit_depth = alt_bit_depth;
    }

    // default to 8bit 4:2:0 if nothing is specified
    if( colorspace == X264_CSP_NONE )
    {
        colorspace    = X264_CSP_I420;
        h->bit_depth  = 8;
    }

    FAIL_IF_ERROR( colorspace <= X264_CSP_NONE || colorspace >= X264_CSP_MAX, "colorspace unhandled\n" );
    FAIL_IF_ERROR( h->bit_depth < 8 || h->bit_depth > 16, "unsupported bit depth `%d'\n", h->bit_depth );

    info->thread_safe = 1;
    info->num_frames  = 0;
    info->csp         = colorspace;

    if( h->bit_depth > 8 )
        info->csp |= X264_CSP_HIGH_DEPTH;

    const x264_cli_csp_t *csp = x264_cli_get_csp( info->csp );

    for( i = 0; i < csp->planes; i++ )
    {
        h->plane_size[i] = x264_cli_pic_plane_size( info->csp, info->width, info->height, i );
        h->frame_size += h->plane_size[i];
        /* x264_cli_pic_plane_size returns the size in bytes, we need the value in pixels from here on */
        h->plane_size[i] /= x264_cli_csp_depth_factor( info->csp );
    }

    if( x264_is_regular_file( h->fh ) )
    {
        int64_t init_pos = ftell( h->fh );

        /* Find out the length of the frame header */
        size_t len = 1;
        while( len <= Y4M_MAX_HEADER && fgetc( h->fh ) != '\n' )
            len++;
        FAIL_IF_ERROR( len > Y4M_MAX_HEADER || len < sizeof(Y4M_FRAME_MAGIC), "bad frame header length\n" );
        h->frame_header_len = len;
        h->frame_size += len;

        fseek( h->fh, 0, SEEK_END );
        int64_t i_size = ftell( h->fh );
        fseek( h->fh, init_pos, SEEK_SET );
        info->num_frames = (i_size - h->seq_header_len) / h->frame_size;
        FAIL_IF_ERROR( !info->num_frames, "empty input file\n" );

        /* Attempt to use memory-mapped input frames if possible */
        if( !(h->bit_depth & 7) )
            h->use_mmap = !x264_cli_mmap_init( &h->mmap, h->fh );
    }

    *p_handle = h;
    return 0;
}

static int read_frame_internal( cli_pic_t *pic, y4m_hnd_t *h, int bit_depth_uc )
{
    static const size_t slen = sizeof(Y4M_FRAME_MAGIC)-1;
    int pixel_depth = x264_cli_csp_depth_factor( pic->img.csp );
    int i = sizeof(Y4M_FRAME_MAGIC);
    char header_buf[16];
    char *header;

    /* Verify that the frame header is valid */
    if( h->use_mmap )
    {
        header = (char*)pic->img.plane[0];
        pic->img.plane[0] += h->frame_header_len;

        /* If the header length has changed between frames the size of the mapping will be invalid.
         * It might be possible to work around it, but I'm not aware of any tool beside fuzzers that
         * produces y4m files with variable-length frame headers so just error out if that happens. */
        while( i <= h->frame_header_len && header[i-1] != '\n' )
            i++;
        FAIL_IF_ERROR( i != h->frame_header_len, "bad frame header length\n" );
    }
    else
    {
        header = header_buf;
        if( fread( header, 1, slen, h->fh ) != slen )
            return -1;
        while( i <= Y4M_MAX_HEADER && fgetc( h->fh ) != '\n' )
            i++;
        FAIL_IF_ERROR( i > Y4M_MAX_HEADER, "bad frame header length\n" );
    }
    FAIL_IF_ERROR( memcmp( header, Y4M_FRAME_MAGIC, slen ), "bad frame header magic\n" );

    for( i = 0; i < pic->img.planes; i++ )
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
    y4m_hnd_t *h = handle;

    if( h->use_mmap )
    {
        pic->img.plane[0] = x264_cli_mmap( &h->mmap, h->frame_size * i_frame + h->seq_header_len, h->frame_size );
        if( !pic->img.plane[0] )
            return -1;
    }
    else if( i_frame > h->next_frame )
    {
        if( x264_is_regular_file( h->fh ) )
            fseek( h->fh, h->frame_size * i_frame + h->seq_header_len, SEEK_SET );
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
    y4m_hnd_t *h = handle;
    if( h->use_mmap )
        return x264_cli_munmap( &h->mmap, pic->img.plane[0] - h->frame_header_len, h->frame_size );
    return 0;
}

static int picture_alloc( cli_pic_t *pic, hnd_t handle, int csp, int width, int height )
{
    y4m_hnd_t *h = handle;
    return (h->use_mmap ? x264_cli_pic_init_noalloc : x264_cli_pic_alloc)( pic, csp, width, height );
}

static void picture_clean( cli_pic_t *pic, hnd_t handle )
{
    y4m_hnd_t *h = handle;
    if( h->use_mmap )
        memset( pic, 0, sizeof(cli_pic_t) );
    else
        x264_cli_pic_clean( pic );
}

static int close_file( hnd_t handle )
{
    y4m_hnd_t *h = handle;
    if( !h || !h->fh )
        return 0;
    if( h->use_mmap )
        x264_cli_mmap_close( &h->mmap );
    fclose( h->fh );
    free( h );
    return 0;
}

const cli_input_t y4m_input = { open_file, picture_alloc, read_frame, release_frame, picture_clean, close_file };
