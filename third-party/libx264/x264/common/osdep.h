/*****************************************************************************
 * osdep.h: platform-specific code
 *****************************************************************************
 * Copyright (C) 2007-2022 x264 project
 *
 * Authors: Loren Merritt <lorenm@u.washington.edu>
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

#ifndef X264_OSDEP_H
#define X264_OSDEP_H

#define _LARGEFILE_SOURCE 1
#define _FILE_OFFSET_BITS 64
#include <stdio.h>
#include <sys/stat.h>
#include <inttypes.h>
#include <stdarg.h>
#include <stdlib.h>

#include "config.h"

#ifdef __INTEL_COMPILER
#include <mathimf.h>
#else
#include <math.h>
#endif

#ifdef _WIN32
#include <windows.h>
#include <io.h>
#endif

#include "x264.h"

#if !HAVE_LOG2F
#define log2f(x) (logf(x)/0.693147180559945f)
#define log2(x) (log(x)/0.693147180559945)
#endif

#ifdef _MSC_VER
#define inline __inline
#define strcasecmp _stricmp
#define strncasecmp _strnicmp
#define strtok_r strtok_s
#define S_ISREG(x) (((x) & S_IFMT) == S_IFREG)
#else
#include <strings.h>
#endif

#if !defined(va_copy) && defined(__INTEL_COMPILER)
#define va_copy(dst, src) ((dst) = (src))
#endif

#if !defined(isfinite) && (SYS_OPENBSD || SYS_SunOS)
#define isfinite finite
#endif

#if !HAVE_STRTOK_R && !defined(strtok_r)
#define strtok_r(str,delim,save) strtok(str,delim)
#endif

#if defined(_MSC_VER) && _MSC_VER < 1900
/* MSVC pre-VS2015 has broken snprintf/vsnprintf implementations which are incompatible with C99. */
static inline int x264_vsnprintf( char *s, size_t n, const char *fmt, va_list arg )
{
    int length = -1;

    if( n )
    {
        va_list arg2;
        va_copy( arg2, arg );
        length = _vsnprintf( s, n, fmt, arg2 );
        va_end( arg2 );

        /* _(v)snprintf adds a null-terminator only if the length is less than the buffer size. */
        if( length < 0 || length >= n )
            s[n-1] = '\0';
    }

    /* _(v)snprintf returns a negative number if the length is greater than the buffer size. */
    if( length < 0 )
        return _vscprintf( fmt, arg );

    return length;
}

static inline int x264_snprintf( char *s, size_t n, const char *fmt, ... )
{
    va_list arg;
    va_start( arg, fmt );
    int length = x264_vsnprintf( s, n, fmt, arg );
    va_end( arg );
    return length;
}

#define snprintf  x264_snprintf
#define vsnprintf x264_vsnprintf
#endif

#ifdef _WIN32
/* Functions for dealing with Unicode on Windows. */
static inline wchar_t *x264_utf8_to_utf16( const char *utf8 )
{
    int len = MultiByteToWideChar( CP_UTF8, MB_ERR_INVALID_CHARS, utf8, -1, NULL, 0 );
    if( len )
    {
        wchar_t *utf16 = malloc( len * sizeof( wchar_t ) );
        if( utf16 )
        {
            if( MultiByteToWideChar( CP_UTF8, MB_ERR_INVALID_CHARS, utf8, -1, utf16, len ) )
                return utf16;
            free( utf16 );
        }
    }
    return NULL;
}

static inline wchar_t *x264_utf8_to_utf16_try_buf( const char *utf8, wchar_t *buf_utf16, int buf_len ) {
    if( MultiByteToWideChar( CP_UTF8, MB_ERR_INVALID_CHARS, utf8, -1, buf_utf16, buf_len ) )
        return buf_utf16;
    return x264_utf8_to_utf16( utf8 );
}

#define x264_fopen( filename, mode ) x264_fopen_internal( filename, L##mode )
static inline FILE *x264_fopen_internal( const char *filename, const wchar_t *mode_utf16 )
{
    FILE *f = NULL;
    wchar_t filename_buf[MAX_PATH];
    wchar_t *filename_utf16 = x264_utf8_to_utf16_try_buf( filename, filename_buf, MAX_PATH );
    if( filename_utf16 )
    {
        f = _wfopen( filename_utf16, mode_utf16 );
        if( filename_utf16 != filename_buf )
            free( filename_utf16 );
    }
    return f;
}

static inline int x264_rename( const char *oldname, const char *newname )
{
    int ret = -1;
    wchar_t oldname_buf[MAX_PATH];
    wchar_t *oldname_utf16 = x264_utf8_to_utf16_try_buf( oldname, oldname_buf, MAX_PATH );
    if( oldname_utf16 )
    {
        wchar_t newname_buf[MAX_PATH];
        wchar_t *newname_utf16 = x264_utf8_to_utf16_try_buf( newname, newname_buf, MAX_PATH );
        if( newname_utf16 )
        {
            /* POSIX says that rename() removes the destination, but Win32 doesn't. */
            _wunlink( newname_utf16 );
            ret = _wrename( oldname_utf16, newname_utf16 );
            if( newname_utf16 != newname_buf )
                free( newname_utf16 );
        }
        if( oldname_utf16 != oldname_buf )
            free( oldname_utf16 );
    }
    return ret;
}

#define x264_struct_stat struct _stati64
#define x264_fstat _fstati64

static inline int x264_stat( const char *path, x264_struct_stat *buf )
{
    int ret = -1;
    wchar_t path_buf[MAX_PATH];
    wchar_t *path_utf16 = x264_utf8_to_utf16_try_buf( path, path_buf, MAX_PATH );
    if( path_utf16 )
    {
        ret = _wstati64( path_utf16, buf );
        if( path_utf16 != path_buf )
            free( path_utf16 );
    }
    return ret;
}
#else
#define x264_fopen       fopen
#define x264_rename      rename
#define x264_struct_stat struct stat
#define x264_fstat       fstat
#define x264_stat        stat
#endif

/* mdate: return the current date in microsecond */
X264_API int64_t x264_mdate( void );

#if defined(_WIN32) && !HAVE_WINRT
static inline int x264_vfprintf( FILE *stream, const char *format, va_list arg )
{
    HANDLE console = NULL;
    DWORD mode;

    if( stream == stdout )
        console = GetStdHandle( STD_OUTPUT_HANDLE );
    else if( stream == stderr )
        console = GetStdHandle( STD_ERROR_HANDLE );

    /* Only attempt to convert to UTF-16 when writing to a non-redirected console screen buffer. */
    if( GetConsoleMode( console, &mode ) )
    {
        char buf[4096];
        wchar_t buf_utf16[4096];
        va_list arg2;

        va_copy( arg2, arg );
        int length = vsnprintf( buf, sizeof(buf), format, arg2 );
        va_end( arg2 );

        if( length > 0 && (unsigned)length < sizeof(buf) )
        {
            /* WriteConsoleW is the most reliable way to output Unicode to a console. */
            int length_utf16 = MultiByteToWideChar( CP_UTF8, 0, buf, length, buf_utf16, sizeof(buf_utf16)/sizeof(wchar_t) );
            DWORD written;
            WriteConsoleW( console, buf_utf16, length_utf16, &written, NULL );
            return length;
        }
    }
    return vfprintf( stream, format, arg );
}

static inline int x264_is_regular_file_path( const char *path )
{
    int ret = -1;
    wchar_t path_buf[MAX_PATH];
    wchar_t *path_utf16 = x264_utf8_to_utf16_try_buf( path, path_buf, MAX_PATH );
    if( path_utf16 )
    {
        x264_struct_stat buf;
        if( _wstati64( path_utf16, &buf ) )
            ret = !WaitNamedPipeW( path_utf16, 0 );
        else
            ret = S_ISREG( buf.st_mode );
        if( path_utf16 != path_buf )
            free( path_utf16 );
    }
    return ret;
}
#else
#define x264_vfprintf vfprintf

static inline int x264_is_regular_file_path( const char *filename )
{
    x264_struct_stat file_stat;
    if( x264_stat( filename, &file_stat ) )
        return 1;
    return S_ISREG( file_stat.st_mode );
}
#endif

static inline int x264_is_regular_file( FILE *filehandle )
{
    x264_struct_stat file_stat;
    if( x264_fstat( fileno( filehandle ), &file_stat ) )
        return 1;
    return S_ISREG( file_stat.st_mode );
}

#define x264_glue3_expand(x,y,z) x##_##y##_##z
#define x264_glue3(x,y,z) x264_glue3_expand(x,y,z)

#ifdef _MSC_VER
#define DECLARE_ALIGNED( var, n ) __declspec(align(n)) var
#else
#define DECLARE_ALIGNED( var, n ) var __attribute__((aligned(n)))
#endif

#define ALIGNED_4( var )  DECLARE_ALIGNED( var, 4 )
#define ALIGNED_8( var )  DECLARE_ALIGNED( var, 8 )
#define ALIGNED_16( var ) DECLARE_ALIGNED( var, 16 )

// ARM compilers don't reliably align stack variables
// - EABI requires only 8 byte stack alignment to be maintained
// - gcc can't align stack variables to more even if the stack were to be correctly aligned outside the function
// - armcc can't either, but is nice enough to actually tell you so
// - Apple gcc only maintains 4 byte alignment
// - llvm can align the stack, but only in svn and (unrelated) it exposes bugs in all released GNU binutils...

#define ALIGNED_ARRAY_EMU( mask, type, name, sub1, ... )\
    uint8_t name##_u [sizeof(type sub1 __VA_ARGS__) + mask]; \
    type (*name) __VA_ARGS__ = (void*)((intptr_t)(name##_u+mask) & ~mask)

#if ARCH_ARM && SYS_MACOSX
#define ALIGNED_ARRAY_8( ... ) EXPAND( ALIGNED_ARRAY_EMU( 7, __VA_ARGS__ ) )
#else
#define ALIGNED_ARRAY_8( type, name, sub1, ... ) ALIGNED_8( type name sub1 __VA_ARGS__ )
#endif

#if ARCH_ARM
#define ALIGNED_ARRAY_16( ... ) EXPAND( ALIGNED_ARRAY_EMU( 15, __VA_ARGS__ ) )
#else
#define ALIGNED_ARRAY_16( type, name, sub1, ... ) ALIGNED_16( type name sub1 __VA_ARGS__ )
#endif

#define EXPAND(x) x

#if ARCH_X86 || ARCH_X86_64
#define NATIVE_ALIGN 64
#define ALIGNED_32( var ) DECLARE_ALIGNED( var, 32 )
#define ALIGNED_64( var ) DECLARE_ALIGNED( var, 64 )
#if STACK_ALIGNMENT >= 32
#define ALIGNED_ARRAY_32( type, name, sub1, ... ) ALIGNED_32( type name sub1 __VA_ARGS__ )
#else
#define ALIGNED_ARRAY_32( ... ) EXPAND( ALIGNED_ARRAY_EMU( 31, __VA_ARGS__ ) )
#endif
#if STACK_ALIGNMENT >= 64
#define ALIGNED_ARRAY_64( type, name, sub1, ... ) ALIGNED_64( type name sub1 __VA_ARGS__ )
#else
#define ALIGNED_ARRAY_64( ... ) EXPAND( ALIGNED_ARRAY_EMU( 63, __VA_ARGS__ ) )
#endif
#else
#define NATIVE_ALIGN 16
#define ALIGNED_32 ALIGNED_16
#define ALIGNED_64 ALIGNED_16
#define ALIGNED_ARRAY_32 ALIGNED_ARRAY_16
#define ALIGNED_ARRAY_64 ALIGNED_ARRAY_16
#endif

#if STACK_ALIGNMENT > 16 || (ARCH_X86 && STACK_ALIGNMENT > 4)
#define REALIGN_STACK __attribute__((force_align_arg_pointer))
#else
#define REALIGN_STACK
#endif

#if defined(__GNUC__) && (__GNUC__ > 3 || __GNUC__ == 3 && __GNUC_MINOR__ > 0)
#define UNUSED __attribute__((unused))
#define ALWAYS_INLINE __attribute__((always_inline)) inline
#define NOINLINE __attribute__((noinline))
#define MAY_ALIAS __attribute__((may_alias))
#define x264_constant_p(x) __builtin_constant_p(x)
#define x264_nonconstant_p(x) (!__builtin_constant_p(x))
#else
#ifdef _MSC_VER
#define ALWAYS_INLINE __forceinline
#define NOINLINE __declspec(noinline)
#else
#define ALWAYS_INLINE inline
#define NOINLINE
#endif
#define UNUSED
#define MAY_ALIAS
#define x264_constant_p(x) 0
#define x264_nonconstant_p(x) 0
#endif

/* threads */
#if HAVE_BEOSTHREAD
#include <kernel/OS.h>
#define x264_pthread_t               thread_id
static inline int x264_pthread_create( x264_pthread_t *t, void *a, void *(*f)(void *), void *d )
{
     *t = spawn_thread( f, "", 10, d );
     if( *t < B_NO_ERROR )
         return -1;
     resume_thread( *t );
     return 0;
}
#define x264_pthread_join(t,s)       { long tmp; \
                                       wait_for_thread(t,(s)?(long*)(s):&tmp); }

#elif HAVE_POSIXTHREAD
#include <pthread.h>
#define x264_pthread_t               pthread_t
#define x264_pthread_create          pthread_create
#define x264_pthread_join            pthread_join
#define x264_pthread_mutex_t         pthread_mutex_t
#define x264_pthread_mutex_init      pthread_mutex_init
#define x264_pthread_mutex_destroy   pthread_mutex_destroy
#define x264_pthread_mutex_lock      pthread_mutex_lock
#define x264_pthread_mutex_unlock    pthread_mutex_unlock
#define x264_pthread_cond_t          pthread_cond_t
#define x264_pthread_cond_init       pthread_cond_init
#define x264_pthread_cond_destroy    pthread_cond_destroy
#define x264_pthread_cond_broadcast  pthread_cond_broadcast
#define x264_pthread_cond_wait       pthread_cond_wait
#define x264_pthread_attr_t          pthread_attr_t
#define x264_pthread_attr_init       pthread_attr_init
#define x264_pthread_attr_destroy    pthread_attr_destroy
#define x264_pthread_num_processors_np pthread_num_processors_np
#define X264_PTHREAD_MUTEX_INITIALIZER PTHREAD_MUTEX_INITIALIZER

#elif HAVE_WIN32THREAD
#include "win32thread.h"

#else
#define x264_pthread_t               int
#define x264_pthread_create(t,u,f,d) 0
#define x264_pthread_join(t,s)
#endif //HAVE_*THREAD

#if !HAVE_POSIXTHREAD && !HAVE_WIN32THREAD
#define x264_pthread_mutex_t         int
#define x264_pthread_mutex_init(m,f) 0
#define x264_pthread_mutex_destroy(m)
#define x264_pthread_mutex_lock(m)
#define x264_pthread_mutex_unlock(m)
#define x264_pthread_cond_t          int
#define x264_pthread_cond_init(c,f)  0
#define x264_pthread_cond_destroy(c)
#define x264_pthread_cond_broadcast(c)
#define x264_pthread_cond_wait(c,m)
#define x264_pthread_attr_t          int
#define x264_pthread_attr_init(a)    0
#define x264_pthread_attr_destroy(a)
#define X264_PTHREAD_MUTEX_INITIALIZER 0
#endif

#if HAVE_WIN32THREAD || PTW32_STATIC_LIB
X264_API int x264_threading_init( void );
#else
#define x264_threading_init() 0
#endif

static ALWAYS_INLINE int x264_pthread_fetch_and_add( int *val, int add, x264_pthread_mutex_t *mutex )
{
#if HAVE_THREAD
#if defined(__GNUC__) && (__GNUC__ > 4 || __GNUC__ == 4 && __GNUC_MINOR__ > 0) && (ARCH_X86 || ARCH_X86_64)
    return __sync_fetch_and_add( val, add );
#else
    x264_pthread_mutex_lock( mutex );
    int res = *val;
    *val += add;
    x264_pthread_mutex_unlock( mutex );
    return res;
#endif
#else
    int res = *val;
    *val += add;
    return res;
#endif
}

#define WORD_SIZE sizeof(void*)

#define asm __asm__

#if WORDS_BIGENDIAN
#define endian_fix(x) (x)
#define endian_fix64(x) (x)
#define endian_fix32(x) (x)
#define endian_fix16(x) (x)
#else
#if HAVE_X86_INLINE_ASM && HAVE_MMX
static ALWAYS_INLINE uint32_t endian_fix32( uint32_t x )
{
    asm("bswap %0":"+r"(x));
    return x;
}
#elif defined(__GNUC__) && HAVE_ARMV6
static ALWAYS_INLINE uint32_t endian_fix32( uint32_t x )
{
    asm("rev %0, %0":"+r"(x));
    return x;
}
#else
static ALWAYS_INLINE uint32_t endian_fix32( uint32_t x )
{
    return (x<<24) + ((x<<8)&0xff0000) + ((x>>8)&0xff00) + (x>>24);
}
#endif
#if HAVE_X86_INLINE_ASM && ARCH_X86_64
static ALWAYS_INLINE uint64_t endian_fix64( uint64_t x )
{
    asm("bswap %0":"+r"(x));
    return x;
}
#else
static ALWAYS_INLINE uint64_t endian_fix64( uint64_t x )
{
    return endian_fix32(x>>32) + ((uint64_t)endian_fix32(x)<<32);
}
#endif
static ALWAYS_INLINE uintptr_t endian_fix( uintptr_t x )
{
    return WORD_SIZE == 8 ? endian_fix64(x) : endian_fix32(x);
}
static ALWAYS_INLINE uint16_t endian_fix16( uint16_t x )
{
    return (uint16_t)((x<<8)|(x>>8));
}
#endif

/* For values with 4 bits or less. */
static ALWAYS_INLINE int x264_ctz_4bit( uint32_t x )
{
    static uint8_t lut[16] = {4,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0};
    return lut[x];
}

#if defined(__GNUC__) && (__GNUC__ > 3 || __GNUC__ == 3 && __GNUC_MINOR__ > 3)
#define x264_clz(x) __builtin_clz(x)
#define x264_ctz(x) __builtin_ctz(x)
#else
static ALWAYS_INLINE int x264_clz( uint32_t x )
{
    static uint8_t lut[16] = {4,3,2,2,1,1,1,1,0,0,0,0,0,0,0,0};
    int y, z = (((x >> 16) - 1) >> 27) & 16;
    x >>= z^16;
    z += y = ((x - 0x100) >> 28) & 8;
    x >>= y^8;
    z += y = ((x - 0x10) >> 29) & 4;
    x >>= y^4;
    return z + lut[x];
}

static ALWAYS_INLINE int x264_ctz( uint32_t x )
{
    static uint8_t lut[16] = {4,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0};
    int y, z = (((x & 0xffff) - 1) >> 27) & 16;
    x >>= z;
    z += y = (((x & 0xff) - 1) >> 28) & 8;
    x >>= y;
    z += y = (((x & 0xf) - 1) >> 29) & 4;
    x >>= y;
    return z + lut[x&0xf];
}
#endif

#if HAVE_X86_INLINE_ASM && HAVE_MMX
/* Don't use __builtin_prefetch; even as recent as 4.3.4, GCC seems incapable of
 * using complex address modes properly unless we use inline asm. */
static ALWAYS_INLINE void x264_prefetch( void *p )
{
    asm volatile( "prefetcht0 %0"::"m"(*(uint8_t*)p) );
}
/* We require that prefetch not fault on invalid reads, so we only enable it on
 * known architectures. */
#elif defined(__GNUC__) && (__GNUC__ > 3 || __GNUC__ == 3 && __GNUC_MINOR__ > 1) &&\
      (ARCH_X86 || ARCH_X86_64 || ARCH_ARM || ARCH_PPC)
#define x264_prefetch(x) __builtin_prefetch(x)
#else
#define x264_prefetch(x)
#endif

#endif /* X264_OSDEP_H */
