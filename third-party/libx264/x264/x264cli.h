/*****************************************************************************
 * x264cli.h: x264cli common
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

#ifndef X264_CLI_H
#define X264_CLI_H

#include "common/base.h"

/* In microseconds */
#define UPDATE_INTERVAL 250000

#define MAX_RESOLUTION 16384

typedef void *hnd_t;

extern const char * const x264_avcintra_class_names[];
extern const char * const x264_cqm_names[];
extern const char * const x264_log_level_names[];
extern const char * const x264_partition_names[];
extern const char * const x264_pulldown_names[];
extern const char * const x264_range_names[];
extern const char * const x264_output_csp_names[];
extern const char * const x264_valid_profile_names[];
extern const char * const x264_demuxer_names[];
extern const char * const x264_muxer_names[];

static inline uint64_t gcd( uint64_t a, uint64_t b )
{
    while( 1 )
    {
        int64_t c = a % b;
        if( !c )
            return b;
        a = b;
        b = c;
    }
}

static inline uint64_t lcm( uint64_t a, uint64_t b )
{
    return ( a / gcd( a, b ) ) * b;
}

static inline char *get_filename_extension( char *filename )
{
    char *ext = filename + strlen( filename );
    while( *ext != '.' && ext > filename )
        ext--;
    ext += *ext == '.';
    return ext;
}

void x264_cli_log( const char *name, int i_level, const char *fmt, ... );
void x264_cli_printf( int i_level, const char *fmt, ... );
int x264_cli_autocomplete( const char *prev, const char *cur );

#ifdef _WIN32
void x264_cli_set_console_title( const char *title );
int x264_ansi_filename( const char *filename, char *ansi_filename, int size, int create_file );
#else
#define x264_cli_set_console_title( title )
#endif

#define RETURN_IF_ERR( cond, name, ret, ... )\
do\
{\
    if( cond )\
    {\
        x264_cli_log( name, X264_LOG_ERROR, __VA_ARGS__ );\
        return ret;\
    }\
} while( 0 )

#define FAIL_IF_ERR( cond, name, ... ) RETURN_IF_ERR( cond, name, -1, __VA_ARGS__ )

typedef enum
{
    RANGE_AUTO = -1,
    RANGE_TV,
    RANGE_PC
} range_enum;

#endif
