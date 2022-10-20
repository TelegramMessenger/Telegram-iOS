/*****************************************************************************
 * threadpool.c: thread pooling
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

#include "common.h"

typedef struct
{
    void *(*func)(void *);
    void *arg;
    void *ret;
} x264_threadpool_job_t;

struct x264_threadpool_t
{
    volatile int   exit;
    int            threads;
    x264_pthread_t *thread_handle;

    /* requires a synchronized list structure and associated methods,
       so use what is already implemented for frames */
    x264_sync_frame_list_t uninit; /* list of jobs that are awaiting use */
    x264_sync_frame_list_t run;    /* list of jobs that are queued for processing by the pool */
    x264_sync_frame_list_t done;   /* list of jobs that have finished processing */
};

REALIGN_STACK static void *threadpool_thread( x264_threadpool_t *pool )
{
    while( !pool->exit )
    {
        x264_threadpool_job_t *job = NULL;
        x264_pthread_mutex_lock( &pool->run.mutex );
        while( !pool->exit && !pool->run.i_size )
            x264_pthread_cond_wait( &pool->run.cv_fill, &pool->run.mutex );
        if( pool->run.i_size )
        {
            job = (void*)x264_frame_shift( pool->run.list );
            pool->run.i_size--;
        }
        x264_pthread_mutex_unlock( &pool->run.mutex );
        if( !job )
            continue;
        job->ret = job->func( job->arg );
        x264_sync_frame_list_push( &pool->done, (void*)job );
    }
    return NULL;
}

int x264_threadpool_init( x264_threadpool_t **p_pool, int threads )
{
    if( threads <= 0 )
        return -1;

    if( x264_threading_init() < 0 )
        return -1;

    x264_threadpool_t *pool;
    CHECKED_MALLOCZERO( pool, sizeof(x264_threadpool_t) );
    *p_pool = pool;

    pool->threads   = threads;

    CHECKED_MALLOC( pool->thread_handle, pool->threads * sizeof(x264_pthread_t) );

    if( x264_sync_frame_list_init( &pool->uninit, pool->threads ) ||
        x264_sync_frame_list_init( &pool->run, pool->threads ) ||
        x264_sync_frame_list_init( &pool->done, pool->threads ) )
        goto fail;

    for( int i = 0; i < pool->threads; i++ )
    {
       x264_threadpool_job_t *job;
       CHECKED_MALLOC( job, sizeof(x264_threadpool_job_t) );
       x264_sync_frame_list_push( &pool->uninit, (void*)job );
    }
    for( int i = 0; i < pool->threads; i++ )
        if( x264_pthread_create( pool->thread_handle+i, NULL, (void*)threadpool_thread, pool ) )
            goto fail;

    return 0;
fail:
    return -1;
}

void x264_threadpool_run( x264_threadpool_t *pool, void *(*func)(void *), void *arg )
{
    x264_threadpool_job_t *job = (void*)x264_sync_frame_list_pop( &pool->uninit );
    job->func = func;
    job->arg  = arg;
    x264_sync_frame_list_push( &pool->run, (void*)job );
}

void *x264_threadpool_wait( x264_threadpool_t *pool, void *arg )
{
    x264_pthread_mutex_lock( &pool->done.mutex );
    while( 1 )
    {
        for( int i = 0; i < pool->done.i_size; i++ )
            if( ((x264_threadpool_job_t*)pool->done.list[i])->arg == arg )
            {
                x264_threadpool_job_t *job = (void*)x264_frame_shift( pool->done.list+i );
                pool->done.i_size--;
                x264_pthread_mutex_unlock( &pool->done.mutex );

                void *ret = job->ret;
                x264_sync_frame_list_push( &pool->uninit, (void*)job );
                return ret;
            }

        x264_pthread_cond_wait( &pool->done.cv_fill, &pool->done.mutex );
    }
}

static void threadpool_list_delete( x264_sync_frame_list_t *slist )
{
    for( int i = 0; slist->list[i]; i++ )
    {
        x264_free( slist->list[i] );
        slist->list[i] = NULL;
    }
    x264_sync_frame_list_delete( slist );
}

void x264_threadpool_delete( x264_threadpool_t *pool )
{
    x264_pthread_mutex_lock( &pool->run.mutex );
    pool->exit = 1;
    x264_pthread_cond_broadcast( &pool->run.cv_fill );
    x264_pthread_mutex_unlock( &pool->run.mutex );
    for( int i = 0; i < pool->threads; i++ )
        x264_pthread_join( pool->thread_handle[i], NULL );

    threadpool_list_delete( &pool->uninit );
    threadpool_list_delete( &pool->run );
    threadpool_list_delete( &pool->done );
    x264_free( pool->thread_handle );
    x264_free( pool );
}
