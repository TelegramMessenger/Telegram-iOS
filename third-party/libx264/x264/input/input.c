/*****************************************************************************
 * input.c: common input functions
 *****************************************************************************
 * Copyright (C) 2010-2022 x264 project
 *
 * Authors: Steven Walters <kemuri9@gmail.com>
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

#include "input.h"

#ifdef _WIN32
#include <io.h>
#elif HAVE_MMAP
#include <sys/mman.h>
#include <unistd.h>
#endif

const x264_cli_csp_t x264_cli_csps[] = {
    [X264_CSP_I400] = { "i400", 1, { 1 },         { 1 },         1, 1 },
    [X264_CSP_I420] = { "i420", 3, { 1, .5, .5 }, { 1, .5, .5 }, 2, 2 },
    [X264_CSP_I422] = { "i422", 3, { 1, .5, .5 }, { 1,  1,  1 }, 2, 1 },
    [X264_CSP_I444] = { "i444", 3, { 1,  1,  1 }, { 1,  1,  1 }, 1, 1 },
    [X264_CSP_YV12] = { "yv12", 3, { 1, .5, .5 }, { 1, .5, .5 }, 2, 2 },
    [X264_CSP_YV16] = { "yv16", 3, { 1, .5, .5 }, { 1,  1,  1 }, 2, 1 },
    [X264_CSP_YV24] = { "yv24", 3, { 1,  1,  1 }, { 1,  1,  1 }, 1, 1 },
    [X264_CSP_NV12] = { "nv12", 2, { 1,  1 },     { 1, .5 },     2, 2 },
    [X264_CSP_NV21] = { "nv21", 2, { 1,  1 },     { 1, .5 },     2, 2 },
    [X264_CSP_NV16] = { "nv16", 2, { 1,  1 },     { 1,  1 },     2, 1 },
    [X264_CSP_YUYV] = { "yuyv", 1, { 2 },         { 1 },         2, 1 },
    [X264_CSP_UYVY] = { "uyvy", 1, { 2 },         { 1 },         2, 1 },
    [X264_CSP_BGR]  = { "bgr",  1, { 3 },         { 1 },         1, 1 },
    [X264_CSP_BGRA] = { "bgra", 1, { 4 },         { 1 },         1, 1 },
    [X264_CSP_RGB]  = { "rgb",  1, { 3 },         { 1 },         1, 1 },
};

int x264_cli_csp_is_invalid( int csp )
{
    int csp_mask = csp & X264_CSP_MASK;
    return csp_mask <= X264_CSP_NONE || csp_mask >= X264_CSP_CLI_MAX ||
           csp_mask == X264_CSP_V210 || csp & X264_CSP_OTHER;
}

int x264_cli_csp_depth_factor( int csp )
{
    if( x264_cli_csp_is_invalid( csp ) )
        return 0;
    return (csp & X264_CSP_HIGH_DEPTH) ? 2 : 1;
}

int64_t x264_cli_pic_plane_size( int csp, int width, int height, int plane )
{
    int csp_mask = csp & X264_CSP_MASK;
    if( x264_cli_csp_is_invalid( csp ) || plane < 0 || plane >= x264_cli_csps[csp_mask].planes )
        return 0;
    int64_t size = (int64_t)width * height;
    size *= x264_cli_csps[csp_mask].width[plane] * x264_cli_csps[csp_mask].height[plane];
    size *= x264_cli_csp_depth_factor( csp );
    return size;
}

int64_t x264_cli_pic_size( int csp, int width, int height )
{
    if( x264_cli_csp_is_invalid( csp ) )
        return 0;
    int64_t size = 0;
    int csp_mask = csp & X264_CSP_MASK;
    for( int i = 0; i < x264_cli_csps[csp_mask].planes; i++ )
        size += x264_cli_pic_plane_size( csp, width, height, i );
    return size;
}

static int cli_pic_init_internal( cli_pic_t *pic, int csp, int width, int height, int align, int alloc )
{
    memset( pic, 0, sizeof(cli_pic_t) );
    int csp_mask = csp & X264_CSP_MASK;
    if( x264_cli_csp_is_invalid( csp ) )
        pic->img.planes = 0;
    else
        pic->img.planes = x264_cli_csps[csp_mask].planes;
    pic->img.csp    = csp;
    pic->img.width  = width;
    pic->img.height = height;
    for( int i = 0; i < pic->img.planes; i++ )
    {
        int stride = width * x264_cli_csps[csp_mask].width[i];
        stride *= x264_cli_csp_depth_factor( csp );
        stride = ALIGN( stride, align );
        pic->img.stride[i] = stride;

        if( alloc )
        {
            int64_t size = (int64_t)(height * x264_cli_csps[csp_mask].height[i]) * stride;
            pic->img.plane[i] = x264_malloc( size );
            if( !pic->img.plane[i] )
                return -1;
        }
    }

    return 0;
}

int x264_cli_pic_alloc( cli_pic_t *pic, int csp, int width, int height )
{
    return cli_pic_init_internal( pic, csp, width, height, 1, 1 );
}

int x264_cli_pic_alloc_aligned( cli_pic_t *pic, int csp, int width, int height )
{
    return cli_pic_init_internal( pic, csp, width, height, NATIVE_ALIGN, 1 );
}

int x264_cli_pic_init_noalloc( cli_pic_t *pic, int csp, int width, int height )
{
    return cli_pic_init_internal( pic, csp, width, height, 1, 0 );
}

void x264_cli_pic_clean( cli_pic_t *pic )
{
    for( int i = 0; i < pic->img.planes; i++ )
        x264_free( pic->img.plane[i] );
    memset( pic, 0, sizeof(cli_pic_t) );
}

const x264_cli_csp_t *x264_cli_get_csp( int csp )
{
    if( x264_cli_csp_is_invalid( csp ) )
        return NULL;
    return x264_cli_csps + (csp&X264_CSP_MASK);
}

/* Functions for handling memory-mapped input frames */
int x264_cli_mmap_init( cli_mmap_t *h, FILE *fh )
{
#if defined(_WIN32) || HAVE_MMAP
    int fd = fileno( fh );
    x264_struct_stat file_stat;
    if( !x264_fstat( fd, &file_stat ) )
    {
        h->file_size = file_stat.st_size;
#ifdef _WIN32
        HANDLE osfhandle = (HANDLE)_get_osfhandle( fd );
        if( osfhandle != INVALID_HANDLE_VALUE )
        {
            SYSTEM_INFO si;
            GetSystemInfo( &si );
            h->page_mask = si.dwPageSize - 1;
            h->align_mask = si.dwAllocationGranularity - 1;
            h->prefetch_virtual_memory = (void*)GetProcAddress( GetModuleHandleW( L"kernel32.dll" ), "PrefetchVirtualMemory" );
            h->process_handle = GetCurrentProcess();
            h->map_handle = CreateFileMappingW( osfhandle, NULL, PAGE_READONLY, 0, 0, NULL );
            return !h->map_handle;
        }
#elif HAVE_MMAP && defined(_SC_PAGESIZE)
        h->align_mask = sysconf( _SC_PAGESIZE ) - 1;
        h->fd = fd;
        return h->align_mask < 0 || fd < 0;
#endif
    }
#endif
    return -1;
}

/* Third-party filters such as swscale can overread the input buffer which may result
 * in segfaults. We have to pad the buffer size as a workaround to avoid that. */
#define MMAP_PADDING 64

void *x264_cli_mmap( cli_mmap_t *h, int64_t offset, int64_t size )
{
#if defined(_WIN32) || HAVE_MMAP
    uint8_t *base;
    int align = offset & h->align_mask;
    if( offset < 0 || size < 0 || (uint64_t)size > (SIZE_MAX - MMAP_PADDING - align) )
        return NULL;
    offset -= align;
    size   += align;
#ifdef _WIN32
    /* If the padding crosses a page boundary we need to increase the mapping size. */
    size_t padded_size = (-size & h->page_mask) < MMAP_PADDING ? size + MMAP_PADDING : size;
    if( (uint64_t)offset + padded_size > (uint64_t)h->file_size )
    {
        /* It's not possible to do the POSIX mmap() remapping trick on Windows, so if the padding crosses a
         * page boundary past the end of the file we have to copy the entire frame into a padded buffer. */
        if( (base = MapViewOfFile( h->map_handle, FILE_MAP_READ, (uint64_t)offset >> 32, offset, size )) )
        {
            uint8_t *buf = NULL;
            HANDLE anon_map = CreateFileMappingW( INVALID_HANDLE_VALUE, NULL, PAGE_READWRITE, (uint64_t)padded_size >> 32, padded_size, NULL );
            if( anon_map )
            {
                if( (buf = MapViewOfFile( anon_map, FILE_MAP_WRITE, 0, 0, 0 )) )
                {
                    buf += align;
                    memcpy( buf, base + align, size - align );
                }
                CloseHandle( anon_map );
            }
            UnmapViewOfFile( base );
            return buf;
        }
    }
    else if( (base = MapViewOfFile( h->map_handle, FILE_MAP_READ, (uint64_t)offset >> 32, offset, padded_size )) )
    {
        /* PrefetchVirtualMemory() is only available on Windows 8 and newer. */
        if( h->prefetch_virtual_memory )
        {
            struct { void *addr; size_t size; } mem_range = { base, size };
            h->prefetch_virtual_memory( h->process_handle, 1, &mem_range, 0 );
        }
        return base + align;
    }
#else
    size_t padded_size = size + MMAP_PADDING;
    if( (base = mmap( NULL, padded_size, PROT_READ, MAP_PRIVATE, h->fd, offset )) != MAP_FAILED )
    {
        /* Ask the OS to readahead pages. This improves performance whereas
         * forcing page faults by manually accessing every page does not.
         * Some systems have implemented madvise() but not posix_madvise()
         * and vice versa, so check both to see if either is available. */
#ifdef MADV_WILLNEED
        madvise( base, size, MADV_WILLNEED );
#elif defined(POSIX_MADV_WILLNEED)
        posix_madvise( base, size, POSIX_MADV_WILLNEED );
#endif
        /* Remap the file mapping of any padding that crosses a page boundary past the end of
         * the file into a copy of the last valid page to prevent reads from invalid memory. */
        size_t aligned_size = (padded_size - 1) & ~h->align_mask;
        if( offset + aligned_size >= h->file_size )
            mmap( base + aligned_size, padded_size - aligned_size, PROT_READ, MAP_PRIVATE|MAP_FIXED, h->fd, (offset + size - 1) & ~h->align_mask );

        return base + align;
    }
#endif
#endif
    return NULL;
}

int x264_cli_munmap( cli_mmap_t *h, void *addr, int64_t size )
{
#if defined(_WIN32) || HAVE_MMAP
    void *base = (void*)((intptr_t)addr & ~h->align_mask);
#ifdef _WIN32
    return !UnmapViewOfFile( base );
#else
    if( size < 0 || size > (SIZE_MAX - MMAP_PADDING - ((intptr_t)addr - (intptr_t)base)) )
        return -1;
    return munmap( base, size + MMAP_PADDING + (intptr_t)addr - (intptr_t)base );
#endif
#endif
    return -1;
}

void x264_cli_mmap_close( cli_mmap_t *h )
{
#ifdef _WIN32
    CloseHandle( h->map_handle );
#endif
}
