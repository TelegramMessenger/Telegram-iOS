/*****************************************************************************
 * output.h: x264 file output modules
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

#ifndef X264_OUTPUT_H
#define X264_OUTPUT_H

#include "x264cli.h"

typedef struct
{
    int use_dts_compress;
} cli_output_opt_t;

typedef struct
{
    int (*open_file)( char *psz_filename, hnd_t *p_handle, cli_output_opt_t *opt );
    int (*set_param)( hnd_t handle, x264_param_t *p_param );
    int (*write_headers)( hnd_t handle, x264_nal_t *p_nal );
    int (*write_frame)( hnd_t handle, uint8_t *p_nal, int i_size, x264_picture_t *p_picture );
    int (*close_file)( hnd_t handle, int64_t largest_pts, int64_t second_largest_pts );
} cli_output_t;

extern const cli_output_t raw_output;
extern const cli_output_t mkv_output;
extern const cli_output_t mp4_output;
extern const cli_output_t flv_output;

#endif
