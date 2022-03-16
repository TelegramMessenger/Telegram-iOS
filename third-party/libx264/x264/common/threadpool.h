/*****************************************************************************
 * threadpool.h: thread pooling
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

#ifndef X264_THREADPOOL_H
#define X264_THREADPOOL_H

typedef struct x264_threadpool_t x264_threadpool_t;

#if HAVE_THREAD
#define x264_threadpool_init x264_template(threadpool_init)
X264_API int   x264_threadpool_init( x264_threadpool_t **p_pool, int threads );
#define x264_threadpool_run x264_template(threadpool_run)
X264_API void  x264_threadpool_run( x264_threadpool_t *pool, void *(*func)(void *), void *arg );
#define x264_threadpool_wait x264_template(threadpool_wait)
X264_API void *x264_threadpool_wait( x264_threadpool_t *pool, void *arg );
#define x264_threadpool_delete x264_template(threadpool_delete)
X264_API void  x264_threadpool_delete( x264_threadpool_t *pool );
#else
#define x264_threadpool_init(p,t) -1
#define x264_threadpool_run(p,f,a)
#define x264_threadpool_wait(p,a)     NULL
#define x264_threadpool_delete(p)
#endif

#endif
