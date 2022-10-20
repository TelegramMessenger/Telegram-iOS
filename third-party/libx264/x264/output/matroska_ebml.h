/*****************************************************************************
 * matroska_ebml.h: matroska muxer utilities
 *****************************************************************************
 * Copyright (C) 2005-2022 x264 project
 *
 * Authors: Mike Matsnev <mike@haali.su>
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

#ifndef X264_MATROSKA_EBML_H
#define X264_MATROSKA_EBML_H

/* Matroska display size units from the spec */
#define DS_PIXELS        0
#define DS_CM            1
#define DS_INCHES        2
#define DS_ASPECT_RATIO  3

typedef struct mk_writer mk_writer;

mk_writer *mk_create_writer( const char *filename );

int mk_write_header( mk_writer *w, const char *writing_app,
                     const char *codec_id,
                     const void *codec_private, unsigned codec_private_size,
                     int64_t default_frame_duration,
                     int64_t timescale,
                     unsigned width, unsigned height,
                     unsigned d_width, unsigned d_height, int display_size_units, int stereo_mode );

int mk_start_frame( mk_writer *w );
int mk_add_frame_data( mk_writer *w, const void *data, unsigned size );
int mk_set_frame_flags( mk_writer *w, int64_t timestamp, int keyframe, int skippable );
int mk_close( mk_writer *w, int64_t last_delta );

#endif
