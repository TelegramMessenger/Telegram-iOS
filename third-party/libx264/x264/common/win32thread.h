/*****************************************************************************
 * win32thread.h: windows threading
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

#ifndef X264_WIN32THREAD_H
#define X264_WIN32THREAD_H

#include <windows.h>
/* the following macro is used within x264 */
#undef ERROR

typedef struct
{
    void *handle;
    void *(*func)( void* arg );
    void *arg;
    void **p_ret;
    void *ret;
} x264_pthread_t;
#define x264_pthread_attr_t int

/* the conditional variable api for windows 6.0+ uses critical sections and not mutexes */
typedef CRITICAL_SECTION x264_pthread_mutex_t;
#define X264_PTHREAD_MUTEX_INITIALIZER {0}
#define x264_pthread_mutexattr_t int

#if HAVE_WINRT
typedef CONDITION_VARIABLE x264_pthread_cond_t;
#else
typedef struct
{
    void *Ptr;
} x264_pthread_cond_t;
#endif
#define x264_pthread_condattr_t int

int x264_pthread_create( x264_pthread_t *thread, const x264_pthread_attr_t *attr,
                         void *(*start_routine)( void* ), void *arg );
int x264_pthread_join( x264_pthread_t thread, void **value_ptr );

int x264_pthread_mutex_init( x264_pthread_mutex_t *mutex, const x264_pthread_mutexattr_t *attr );
int x264_pthread_mutex_destroy( x264_pthread_mutex_t *mutex );
int x264_pthread_mutex_lock( x264_pthread_mutex_t *mutex );
int x264_pthread_mutex_unlock( x264_pthread_mutex_t *mutex );

int x264_pthread_cond_init( x264_pthread_cond_t *cond, const x264_pthread_condattr_t *attr );
int x264_pthread_cond_destroy( x264_pthread_cond_t *cond );
int x264_pthread_cond_broadcast( x264_pthread_cond_t *cond );
int x264_pthread_cond_wait( x264_pthread_cond_t *cond, x264_pthread_mutex_t *mutex );
int x264_pthread_cond_signal( x264_pthread_cond_t *cond );

#define x264_pthread_attr_init(a) 0
#define x264_pthread_attr_destroy(a) 0

int  x264_win32_threading_init( void );
void x264_win32_threading_destroy( void );

int x264_pthread_num_processors_np( void );

#endif
