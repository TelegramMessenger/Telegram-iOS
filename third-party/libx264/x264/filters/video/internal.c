/*****************************************************************************
 * internal.c: video filter utilities
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

#include "internal.h"

#define FAIL_IF_ERROR( cond, ... ) FAIL_IF_ERR( cond, "x264", __VA_ARGS__ )

void x264_cli_plane_copy( uint8_t *dst, int i_dst, uint8_t *src, int i_src, int w, int h )
{
    while( h-- )
    {
        memcpy( dst, src, w );
        dst += i_dst;
        src += i_src;
    }
}

int x264_cli_pic_copy( cli_pic_t *out, cli_pic_t *in )
{
    int csp = in->img.csp & X264_CSP_MASK;
    FAIL_IF_ERROR( x264_cli_csp_is_invalid( in->img.csp ), "invalid colorspace arg %d\n", in->img.csp );
    FAIL_IF_ERROR( in->img.csp != out->img.csp || in->img.height != out->img.height
                || in->img.width != out->img.width, "incompatible frame properties\n" );
    /* copy data */
    out->duration = in->duration;
    out->pts = in->pts;
    out->opaque = in->opaque;

    for( int i = 0; i < out->img.planes; i++ )
    {
        int height = in->img.height * x264_cli_csps[csp].height[i];
        int width =  in->img.width  * x264_cli_csps[csp].width[i];
        width *= x264_cli_csp_depth_factor( in->img.csp );
        x264_cli_plane_copy( out->img.plane[i], out->img.stride[i], in->img.plane[i],
                             in->img.stride[i], width, height );
    }
    return 0;
}
