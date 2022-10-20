/*****************************************************************************
 * filters.c: common filter functions
 *****************************************************************************
 * Copyright (C) 2010-2022 x264 project
 *
 * Authors: Diogo Franco <diogomfranco@gmail.com>
 *          Steven Walters <kemuri9@gmail.com>
 *          Henrik Gramner <henrik@gramner.com>
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

#include "filters.h"

#define RETURN_IF_ERROR( cond, ... ) RETURN_IF_ERR( cond, "options", NULL, __VA_ARGS__ )

char **x264_split_options( const char *opt_str, const char * const *options )
{
    int opt_count = 0, options_count = 0, found_named = 0;
    size_t size = 0;
    const char *opt = opt_str;

    if( !opt_str )
        return NULL;

    while( options[options_count] )
        options_count++;

    do
    {
        size_t length = strcspn( opt, "=," );
        if( opt[length] == '=' )
        {
            const char * const *option = options;
            while( *option && (strlen( *option ) != length || strncmp( opt, *option, length )) )
                option++;

            RETURN_IF_ERROR( !*option, "Invalid option '%.*s'\n", length, opt );
            found_named = 1;
            length += strcspn( opt + length, "," );
        }
        else
        {
            RETURN_IF_ERROR( opt_count >= options_count, "Too many options given\n" );
            RETURN_IF_ERROR( found_named, "Ordered option given after named\n" );
            size += strlen( options[opt_count] ) + 1;
        }
        opt_count++;
        opt += length;
    } while( *opt++ );

    size_t offset = 2 * (opt_count+1) * sizeof(char*);
    size += offset + (opt - opt_str);
    char **opts = calloc( 1, size );
    RETURN_IF_ERROR( !opts, "malloc failed\n" );

#define insert_opt( src, length )\
do {\
    opts[i++] = memcpy( (char*)opts + offset, src, length );\
    offset += length + 1;\
    src    += length + 1;\
} while( 0 )

    for( int i = 0; i < 2*opt_count; )
    {
        size_t length = strcspn( opt_str, "=," );
        if( opt_str[length] == '=' )
        {
            insert_opt( opt_str, length );
            length = strcspn( opt_str, "," );
        }
        else
        {
            const char *option = options[i/2];
            size_t option_length = strlen( option );
            insert_opt( option, option_length );
        }
        insert_opt( opt_str, length );
    }

    assert( offset == size );
    return opts;
}

char *x264_get_option( const char *name, char **split_options )
{
    if( split_options )
    {
        int last_i = -1;
        for( int i = 0; split_options[i]; i += 2 )
            if( !strcmp( split_options[i], name ) )
                last_i = i;
        if( last_i >= 0 && split_options[last_i+1][0] )
            return split_options[last_i+1];
    }
    return NULL;
}

int x264_otob( const char *str, int def )
{
   if( str )
       return !strcasecmp( str, "true" ) || !strcmp( str, "1" ) || !strcasecmp( str, "yes" );
   return def;
}

double x264_otof( const char *str, double def )
{
   double ret = def;
   if( str )
   {
       char *end;
       ret = strtod( str, &end );
       if( end == str || *end != '\0' )
           ret = def;
   }
   return ret;
}

int x264_otoi( const char *str, int def )
{
    int ret = def;
    if( str )
    {
        char *end;
        ret = strtol( str, &end, 0 );
        if( end == str || *end != '\0' )
            ret = def;
    }
    return ret;
}

char *x264_otos( char *str, char *def )
{
    return str ? str : def;
}
