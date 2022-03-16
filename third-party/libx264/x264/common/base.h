/*****************************************************************************
 * base.h: misc common functions (bit depth independent)
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

#ifndef X264_BASE_H
#define X264_BASE_H

/****************************************************************************
 * Macros (can be used in osdep.h)
 ****************************************************************************/
#define X264_MIN(a,b) ( (a)<(b) ? (a) : (b) )
#define X264_MAX(a,b) ( (a)>(b) ? (a) : (b) )
#define X264_MIN3(a,b,c) X264_MIN((a),X264_MIN((b),(c)))
#define X264_MAX3(a,b,c) X264_MAX((a),X264_MAX((b),(c)))
#define X264_MIN4(a,b,c,d) X264_MIN((a),X264_MIN3((b),(c),(d)))
#define X264_MAX4(a,b,c,d) X264_MAX((a),X264_MAX3((b),(c),(d)))

/****************************************************************************
 * System includes
 ****************************************************************************/
#include "osdep.h"
#include <stdarg.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <limits.h>

/****************************************************************************
 * Macros
 ****************************************************************************/
#define XCHG(type,a,b) do { type t = a; a = b; b = t; } while( 0 )
#define FIX8(f) ((int)(f*(1<<8)+.5))
#define ARRAY_ELEMS(a) ((int)((sizeof(a))/(sizeof(a[0]))))
#define ALIGN(x,a) (((x)+((a)-1))&~((a)-1))
#define IS_DISPOSABLE(type) ( type == X264_TYPE_B )

/* Unions for type-punning.
 * Mn: load or store n bits, aligned, native-endian
 * CPn: copy n bits, aligned, native-endian
 * we don't use memcpy for CPn because memcpy's args aren't assumed to be aligned */
typedef union { uint16_t i; uint8_t  b[2]; } MAY_ALIAS x264_union16_t;
typedef union { uint32_t i; uint16_t w[2]; uint8_t  b[4]; } MAY_ALIAS x264_union32_t;
typedef union { uint64_t i; uint32_t d[2]; uint16_t w[4]; uint8_t b[8]; } MAY_ALIAS x264_union64_t;
typedef struct { uint64_t i[2]; } x264_uint128_t;
typedef union { x264_uint128_t i; uint64_t q[2]; uint32_t d[4]; uint16_t w[8]; uint8_t b[16]; } MAY_ALIAS x264_union128_t;
#define M16(src) (((x264_union16_t*)(src))->i)
#define M32(src) (((x264_union32_t*)(src))->i)
#define M64(src) (((x264_union64_t*)(src))->i)
#define M128(src) (((x264_union128_t*)(src))->i)
#define M128_ZERO ((x264_uint128_t){{0,0}})
#define CP16(dst,src) M16(dst) = M16(src)
#define CP32(dst,src) M32(dst) = M32(src)
#define CP64(dst,src) M64(dst) = M64(src)
#define CP128(dst,src) M128(dst) = M128(src)

/* Macros for memory constraints of inline asm */
#if defined(__GNUC__) && __GNUC__ >= 8 && !defined(__clang__) && !defined(__INTEL_COMPILER)
#define MEM_FIX(x, t, s) (*(t (*)[s])(x))
#define MEM_DYN(x, t) (*(t (*)[])(x))
#else
//older versions of gcc prefer casting to structure instead of array
#define MEM_FIX(x, t, s) (*(struct { t a[s]; } (*))(x))
//let's set an arbitrary large constant size
#define MEM_DYN(x, t) MEM_FIX(x, t, 4096)
#endif

/****************************************************************************
 * Constants
 ****************************************************************************/
enum profile_e
{
    PROFILE_BASELINE = 66,
    PROFILE_MAIN     = 77,
    PROFILE_HIGH    = 100,
    PROFILE_HIGH10  = 110,
    PROFILE_HIGH422 = 122,
    PROFILE_HIGH444_PREDICTIVE = 244,
};

enum chroma_format_e
{
    CHROMA_400 = 0,
    CHROMA_420 = 1,
    CHROMA_422 = 2,
    CHROMA_444 = 3,
};

enum slice_type_e
{
    SLICE_TYPE_P  = 0,
    SLICE_TYPE_B  = 1,
    SLICE_TYPE_I  = 2,
};

static const char slice_type_to_char[] = { 'P', 'B', 'I' };

enum sei_payload_type_e
{
    SEI_BUFFERING_PERIOD       = 0,
    SEI_PIC_TIMING             = 1,
    SEI_PAN_SCAN_RECT          = 2,
    SEI_FILLER                 = 3,
    SEI_USER_DATA_REGISTERED   = 4,
    SEI_USER_DATA_UNREGISTERED = 5,
    SEI_RECOVERY_POINT         = 6,
    SEI_DEC_REF_PIC_MARKING    = 7,
    SEI_FRAME_PACKING          = 45,
    SEI_MASTERING_DISPLAY      = 137,
    SEI_CONTENT_LIGHT_LEVEL    = 144,
    SEI_ALTERNATIVE_TRANSFER   = 147,
};

#define X264_BFRAME_MAX 16
#define X264_REF_MAX 16
#define X264_THREAD_MAX 128
#define X264_LOOKAHEAD_THREAD_MAX 16
#define X264_LOOKAHEAD_MAX 250

// number of pixels (per thread) in progress at any given time.
// 16 for the macroblock in progress + 3 for deblocking + 3 for motion compensation filter + 2 for extra safety
#define X264_THREAD_HEIGHT 24

/* WEIGHTP_FAKE is set when mb_tree & psy are enabled, but normal weightp is disabled
 * (such as in baseline). It checks for fades in lookahead and adjusts qp accordingly
 * to increase quality. Defined as (-1) so that if(i_weighted_pred > 0) is true only when
 * real weights are being used. */

#define X264_WEIGHTP_FAKE (-1)

#define X264_SCAN8_LUMA_SIZE (5*8)
#define X264_SCAN8_SIZE (X264_SCAN8_LUMA_SIZE*3)
#define X264_SCAN8_0 (4+1*8)

/* Scan8 organization:
 *    0 1 2 3 4 5 6 7
 * 0  DY    y y y y y
 * 1        y Y Y Y Y
 * 2        y Y Y Y Y
 * 3        y Y Y Y Y
 * 4        y Y Y Y Y
 * 5  DU    u u u u u
 * 6        u U U U U
 * 7        u U U U U
 * 8        u U U U U
 * 9        u U U U U
 * 10 DV    v v v v v
 * 11       v V V V V
 * 12       v V V V V
 * 13       v V V V V
 * 14       v V V V V
 * DY/DU/DV are for luma/chroma DC.
 */

#define LUMA_DC   48
#define CHROMA_DC 49

static const uint8_t x264_scan8[16*3 + 3] =
{
    4+ 1*8, 5+ 1*8, 4+ 2*8, 5+ 2*8,
    6+ 1*8, 7+ 1*8, 6+ 2*8, 7+ 2*8,
    4+ 3*8, 5+ 3*8, 4+ 4*8, 5+ 4*8,
    6+ 3*8, 7+ 3*8, 6+ 4*8, 7+ 4*8,
    4+ 6*8, 5+ 6*8, 4+ 7*8, 5+ 7*8,
    6+ 6*8, 7+ 6*8, 6+ 7*8, 7+ 7*8,
    4+ 8*8, 5+ 8*8, 4+ 9*8, 5+ 9*8,
    6+ 8*8, 7+ 8*8, 6+ 9*8, 7+ 9*8,
    4+11*8, 5+11*8, 4+12*8, 5+12*8,
    6+11*8, 7+11*8, 6+12*8, 7+12*8,
    4+13*8, 5+13*8, 4+14*8, 5+14*8,
    6+13*8, 7+13*8, 6+14*8, 7+14*8,
    0+ 0*8, 0+ 5*8, 0+10*8
};

/****************************************************************************
 * Includes
 ****************************************************************************/
#include "cpu.h"
#include "tables.h"

/****************************************************************************
 * Inline functions
 ****************************************************************************/
static ALWAYS_INLINE int x264_clip3( int v, int i_min, int i_max )
{
    return ( (v < i_min) ? i_min : (v > i_max) ? i_max : v );
}

static ALWAYS_INLINE double x264_clip3f( double v, double f_min, double f_max )
{
    return ( (v < f_min) ? f_min : (v > f_max) ? f_max : v );
}

/* Not a general-purpose function; multiplies input by -1/6 to convert
 * qp to qscale. */
static ALWAYS_INLINE int x264_exp2fix8( float x )
{
    int i = x*(-64.f/6.f) + 512.5f;
    if( i < 0 ) return 0;
    if( i > 1023 ) return 0xffff;
    return (x264_exp2_lut[i&63]+256) << (i>>6) >> 8;
}

static ALWAYS_INLINE float x264_log2( uint32_t x )
{
    int lz = x264_clz( x );
    return x264_log2_lut[(x<<lz>>24)&0x7f] + x264_log2_lz_lut[lz];
}

static ALWAYS_INLINE int x264_median( int a, int b, int c )
{
    int t = (a-b)&((a-b)>>31);
    a -= t;
    b += t;
    b -= (b-c)&((b-c)>>31);
    b += (a-b)&((a-b)>>31);
    return b;
}

static ALWAYS_INLINE void x264_median_mv( int16_t *dst, int16_t *a, int16_t *b, int16_t *c )
{
    dst[0] = x264_median( a[0], b[0], c[0] );
    dst[1] = x264_median( a[1], b[1], c[1] );
}

static ALWAYS_INLINE int x264_predictor_difference( int16_t (*mvc)[2], intptr_t i_mvc )
{
    int sum = 0;
    for( int i = 0; i < i_mvc-1; i++ )
    {
        sum += abs( mvc[i][0] - mvc[i+1][0] )
             + abs( mvc[i][1] - mvc[i+1][1] );
    }
    return sum;
}

static ALWAYS_INLINE uint16_t x264_cabac_mvd_sum( uint8_t *mvdleft, uint8_t *mvdtop )
{
    int amvd0 = mvdleft[0] + mvdtop[0];
    int amvd1 = mvdleft[1] + mvdtop[1];
    amvd0 = (amvd0 > 2) + (amvd0 > 32);
    amvd1 = (amvd1 > 2) + (amvd1 > 32);
    return amvd0 + (amvd1<<8);
}

/****************************************************************************
 * General functions
 ****************************************************************************/
X264_API void x264_reduce_fraction( uint32_t *n, uint32_t *d );
X264_API void x264_reduce_fraction64( uint64_t *n, uint64_t *d );

X264_API void x264_log_default( void *p_unused, int i_level, const char *psz_fmt, va_list arg );
X264_API void x264_log_internal( int i_level, const char *psz_fmt, ... );

/* x264_malloc: will do or emulate a memalign
 * you have to use x264_free for buffers allocated with x264_malloc */
X264_API void *x264_malloc( int64_t );
X264_API void  x264_free( void * );

/* x264_slurp_file: malloc space for the whole file and read it */
X264_API char *x264_slurp_file( const char *filename );

/* x264_param_strdup: will do strdup and save returned pointer inside
 * x264_param_t for later freeing during x264_param_cleanup */
char *x264_param_strdup( x264_param_t *param, const char *src );

/* x264_param2string: return a (malloced) string containing most of
 * the encoding options */
X264_API char *x264_param2string( x264_param_t *p, int b_res );

/****************************************************************************
 * Macros
 ****************************************************************************/
#define CHECKED_MALLOC( var, size )\
do {\
    var = x264_malloc( size );\
    if( !var )\
        goto fail;\
} while( 0 )
#define CHECKED_MALLOCZERO( var, size )\
do {\
    CHECKED_MALLOC( var, size );\
    memset( var, 0, size );\
} while( 0 )
#define CHECKED_PARAM_STRDUP( var, param, src )\
do {\
    var = x264_param_strdup( param, src );\
    if( !var )\
        goto fail;\
} while( 0 )

/* Macros for merging multiple allocations into a single large malloc, for improved
 * use with huge pages. */

/* Needs to be enough to contain any set of buffers that use combined allocations */
#define PREALLOC_BUF_SIZE 1024

#define PREALLOC_INIT\
    int    prealloc_idx = 0;\
    int64_t prealloc_size = 0;\
    uint8_t **preallocs[PREALLOC_BUF_SIZE];

#define PREALLOC( var, size )\
do {\
    var = (void*)(intptr_t)prealloc_size;\
    preallocs[prealloc_idx++] = (uint8_t**)&var;\
    prealloc_size += ALIGN((int64_t)(size), NATIVE_ALIGN);\
} while( 0 )

#define PREALLOC_END( ptr )\
do {\
    CHECKED_MALLOC( ptr, prealloc_size );\
    while( prealloc_idx-- )\
        *preallocs[prealloc_idx] = (uint8_t*)((intptr_t)(*preallocs[prealloc_idx]) + (intptr_t)ptr);\
} while( 0 )

#endif
