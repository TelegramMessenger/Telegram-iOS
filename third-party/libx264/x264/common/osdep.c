/*****************************************************************************
 * osdep.c: platform-specific code
 *****************************************************************************
 * Copyright (C) 2003-2022 x264 project
 *
 * Authors: Steven Walters <kemuri9@gmail.com>
 *          Laurent Aimar <fenrir@via.ecp.fr>
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

#include "osdep.h"

#if SYS_WINDOWS
#include <sys/types.h>
#include <sys/timeb.h>
#else
#include <sys/time.h>
#endif
#include <time.h>

#if PTW32_STATIC_LIB
/* this is a global in pthread-win32 to indicate if it has been initialized or not */
extern int ptw32_processInitialized;
#endif

int64_t x264_mdate( void )
{
#if SYS_WINDOWS
    struct timeb tb;
    ftime( &tb );
    return ((int64_t)tb.time * 1000 + (int64_t)tb.millitm) * 1000;
#elif HAVE_CLOCK_GETTIME
    struct timespec ts;
    clock_gettime( CLOCK_MONOTONIC, &ts );
    return (int64_t)ts.tv_sec * 1000000 + (int64_t)ts.tv_nsec / 1000;
#else
    struct timeval tv_date;
    gettimeofday( &tv_date, NULL );
    return (int64_t)tv_date.tv_sec * 1000000 + (int64_t)tv_date.tv_usec;
#endif
}

#if HAVE_WIN32THREAD || PTW32_STATIC_LIB
/* state of the threading library being initialized */
static volatile LONG threading_is_init = 0;

static void threading_destroy( void )
{
#if PTW32_STATIC_LIB
    pthread_win32_thread_detach_np();
    pthread_win32_process_detach_np();
#else
    x264_win32_threading_destroy();
#endif
}

static int threading_init( void )
{
#if PTW32_STATIC_LIB
    /* if static pthread-win32 is already initialized, then do nothing */
    if( ptw32_processInitialized )
        return 0;
    if( !pthread_win32_process_attach_np() )
        return -1;
#else
    if( x264_win32_threading_init() )
        return -1;
#endif
    /* register cleanup to run at process termination */
    atexit( threading_destroy );
    return 0;
}

int x264_threading_init( void )
{
    LONG state;
    while( (state = InterlockedCompareExchange( &threading_is_init, -1, 0 )) != 0 )
    {
        /* if already init, then do nothing */
        if( state > 0 )
            return 0;
    }
    if( threading_init() < 0 )
    {
        InterlockedExchange( &threading_is_init, 0 );
        return -1;
    }
    InterlockedExchange( &threading_is_init, 1 );
    return 0;
}
#endif
