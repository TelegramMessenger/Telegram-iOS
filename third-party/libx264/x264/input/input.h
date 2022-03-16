/*****************************************************************************
 * input.h: file input
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

#ifndef X264_INPUT_H
#define X264_INPUT_H

#include "x264cli.h"

#ifdef _WIN32
#include <windows.h>
#endif

/* options that are used by only some demuxers */
typedef struct
{
    char *index_file;
    char *format;
    char *resolution;
    char *colorspace;
    int bit_depth;
    char *timebase;
    int seek;
    int progress;
    int output_csp; /* convert to this csp, if applicable */
    int output_range; /* user desired output range */
    int input_range; /* user override input range */
} cli_input_opt_t;

/* properties of the source given by the demuxer */
typedef struct
{
    int csp;         /* colorspace of the input */
    uint32_t fps_num;
    uint32_t fps_den;
    int fullrange;   /* has 2^bit_depth-1 instead of 219*2^(bit_depth-8) ranges (YUV only) */
    int width;
    int height;
    int interlaced;
    int num_frames;
    uint32_t sar_width;
    uint32_t sar_height;
    int tff;
    int thread_safe; /* demuxer is thread_input safe */
    uint32_t timebase_num;
    uint32_t timebase_den;
    int vfr;
} video_info_t;

/* image data type used by x264cli */
typedef struct
{
    int     csp;       /* colorspace */
    int     width;     /* width of the picture */
    int     height;    /* height of the picture */
    int     planes;    /* number of planes */
    uint8_t *plane[4]; /* pointers for each plane */
    int     stride[4]; /* strides for each plane */
} cli_image_t;

typedef struct
{
    cli_image_t img;
    int64_t pts;       /* input pts */
    int64_t duration;  /* frame duration - used for vfr */
    void    *opaque;   /* opaque handle */
} cli_pic_t;

typedef struct
{
    int (*open_file)( char *psz_filename, hnd_t *p_handle, video_info_t *info, cli_input_opt_t *opt );
    int (*picture_alloc)( cli_pic_t *pic, hnd_t handle, int csp, int width, int height );
    int (*read_frame)( cli_pic_t *pic, hnd_t handle, int i_frame );
    int (*release_frame)( cli_pic_t *pic, hnd_t handle );
    void (*picture_clean)( cli_pic_t *pic, hnd_t handle );
    int (*close_file)( hnd_t handle );
} cli_input_t;

extern const cli_input_t raw_input;
extern const cli_input_t y4m_input;
extern const cli_input_t avs_input;
extern const cli_input_t thread_8_input;
extern const cli_input_t thread_10_input;
extern const cli_input_t lavf_input;
extern const cli_input_t ffms_input;
extern const cli_input_t timecode_input;

extern cli_input_t cli_input;

/* extended colorspace list that isn't supported by libx264 but by the cli */
#define X264_CSP_CLI_MAX        X264_CSP_MAX     /* end of list         */
#define X264_CSP_OTHER          0x4000           /* non x264 colorspace */

typedef struct
{
    const char *name;
    int planes;
    float width[4];
    float height[4];
    int mod_width;
    int mod_height;
} x264_cli_csp_t;

extern const x264_cli_csp_t x264_cli_csps[];

int      x264_cli_csp_is_invalid( int csp );
int      x264_cli_csp_depth_factor( int csp );
int      x264_cli_pic_alloc( cli_pic_t *pic, int csp, int width, int height );
int      x264_cli_pic_alloc_aligned( cli_pic_t *pic, int csp, int width, int height );
int      x264_cli_pic_init_noalloc( cli_pic_t *pic, int csp, int width, int height );
void     x264_cli_pic_clean( cli_pic_t *pic );
int64_t  x264_cli_pic_plane_size( int csp, int width, int height, int plane );
int64_t  x264_cli_pic_size( int csp, int width, int height );
const x264_cli_csp_t *x264_cli_get_csp( int csp );

typedef struct
{
    int64_t file_size;
    int align_mask;
#ifdef _WIN32
    int page_mask;
    BOOL (WINAPI *prefetch_virtual_memory)( HANDLE, ULONG_PTR, PVOID, ULONG );
    HANDLE process_handle;
    HANDLE map_handle;
#elif HAVE_MMAP
    int fd;
#endif
} cli_mmap_t;

int x264_cli_mmap_init( cli_mmap_t *h, FILE *fh );
void *x264_cli_mmap( cli_mmap_t *h, int64_t offset, int64_t size );
int x264_cli_munmap( cli_mmap_t *h, void *addr, int64_t size );
void x264_cli_mmap_close( cli_mmap_t *h );

#endif
