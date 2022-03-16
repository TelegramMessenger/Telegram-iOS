/*****************************************************************************
 * filters.h: common filter functions
 *****************************************************************************
 * Copyright (C) 2010-2022 x264 project
 *
 * Authors: Diogo Franco <diogomfranco@gmail.com>
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

#ifndef X264_FILTERS_H
#define X264_FILTERS_H

#include "x264cli.h"
#include "filters/video/video.h"

char **x264_split_options( const char *opt_str, const char * const *options );
char  *x264_get_option( const char *name, char **split_options );
int    x264_otob( const char *str, int def );    // option to bool
double x264_otof( const char *str, double def ); // option to float/double
int    x264_otoi( const char *str, int def );    // option to int
char  *x264_otos( char *str, char *def );        // option to string

#endif
