/*****************************************************************************
 * ppccommon.h: ppc utility macros
 *****************************************************************************
 * Copyright (C) 2003-2022 x264 project
 *
 * Authors: Eric Petit <eric.petit@lapsus.org>
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

#if HAVE_ALTIVEC_H
#include <altivec.h>
#endif

/***********************************************************************
 * For constant vectors, use parentheses on OS X and braces on Linux
 **********************************************************************/
#if defined(__APPLE__) && __GNUC__ < 4
#define CV(a...) (a)
#else
#define CV(a...) {a}
#endif

/***********************************************************************
 * Vector types
 **********************************************************************/
#define vec_u8_t  vector unsigned char
#define vec_s8_t  vector signed char
#define vec_u16_t vector unsigned short
#define vec_s16_t vector signed short
#define vec_u32_t vector unsigned int
#define vec_s32_t vector signed int
#if HAVE_VSX
#define vec_u64_t vector unsigned long long
#define vec_s64_t vector signed long long

typedef union {
  uint64_t s[2];
  vec_u64_t v;
} vec_u64_u;

typedef union {
  int64_t s[2];
  vec_s64_t v;
} vec_s64_u;
#endif

typedef union {
  uint32_t s[4];
  vec_u32_t v;
} vec_u32_u;

typedef union {
  int32_t s[4];
  vec_s32_t v;
} vec_s32_u;

typedef union {
  uint16_t s[8];
  vec_u16_t v;
} vec_u16_u;

typedef union {
  int16_t s[8];
  vec_s16_t v;
} vec_s16_u;

typedef union {
  uint8_t s[16];
  vec_u8_t v;
} vec_u8_u;

typedef union {
  int8_t s[16];
  vec_s8_t v;
} vec_s8_u;

/***********************************************************************
 * Null vector
 **********************************************************************/
#define LOAD_ZERO const vec_u8_t zerov = vec_splat_u8( 0 )

#define zero_u8v  (vec_u8_t)  zerov
#define zero_s8v  (vec_s8_t)  zerov
#define zero_u16v (vec_u16_t) zerov
#define zero_s16v (vec_s16_t) zerov
#define zero_u32v (vec_u32_t) zerov
#define zero_s32v (vec_s32_t) zerov

/***********************************************************************
 * 8 <-> 16 bits conversions
 **********************************************************************/
#ifdef WORDS_BIGENDIAN
#define vec_u8_to_u16_h(v) (vec_u16_t) vec_mergeh( zero_u8v, (vec_u8_t) v )
#define vec_u8_to_u16_l(v) (vec_u16_t) vec_mergel( zero_u8v, (vec_u8_t) v )
#define vec_u8_to_s16_h(v) (vec_s16_t) vec_mergeh( zero_u8v, (vec_u8_t) v )
#define vec_u8_to_s16_l(v) (vec_s16_t) vec_mergel( zero_u8v, (vec_u8_t) v )
#else
#define vec_u8_to_u16_h(v) (vec_u16_t) vec_mergeh( (vec_u8_t) v, zero_u8v )
#define vec_u8_to_u16_l(v) (vec_u16_t) vec_mergel( (vec_u8_t) v, zero_u8v )
#define vec_u8_to_s16_h(v) (vec_s16_t) vec_mergeh( (vec_u8_t) v, zero_u8v )
#define vec_u8_to_s16_l(v) (vec_s16_t) vec_mergel( (vec_u8_t) v, zero_u8v )
#endif

#define vec_u8_to_u16(v) vec_u8_to_u16_h(v)
#define vec_u8_to_s16(v) vec_u8_to_s16_h(v)

#define vec_u16_to_u8(v) vec_pack( v, zero_u16v )
#define vec_s16_to_u8(v) vec_packsu( v, zero_s16v )


/***********************************************************************
 * 16 <-> 32 bits conversions
 **********************************************************************/
#ifdef WORDS_BIGENDIAN
#define vec_u16_to_u32_h(v) (vec_u32_t) vec_mergeh( zero_u16v, (vec_u16_t) v )
#define vec_u16_to_u32_l(v) (vec_u32_t) vec_mergel( zero_u16v, (vec_u16_t) v )
#define vec_u16_to_s32_h(v) (vec_s32_t) vec_mergeh( zero_u16v, (vec_u16_t) v )
#define vec_u16_to_s32_l(v) (vec_s32_t) vec_mergel( zero_u16v, (vec_u16_t) v )
#else
#define vec_u16_to_u32_h(v) (vec_u32_t) vec_mergeh( (vec_u16_t) v, zero_u16v )
#define vec_u16_to_u32_l(v) (vec_u32_t) vec_mergel( (vec_u16_t) v, zero_u16v )
#define vec_u16_to_s32_h(v) (vec_s32_t) vec_mergeh( (vec_u16_t) v, zero_u16v )
#define vec_u16_to_s32_l(v) (vec_s32_t) vec_mergel( (vec_u16_t) v, zero_u16v )
#endif

#define vec_u16_to_u32(v) vec_u16_to_u32_h(v)
#define vec_u16_to_s32(v) vec_u16_to_s32_h(v)

#define vec_u32_to_u16(v) vec_pack( v, zero_u32v )
#define vec_s32_to_u16(v) vec_packsu( v, zero_s32v )

/***********************************************************************
 * VEC_STORE##n:  stores n bytes from vector v to address p
 **********************************************************************/
#ifndef __POWER9_VECTOR__
#define VEC_STORE8( v, p ) \
    vec_vsx_st( vec_xxpermdi( v, vec_vsx_ld( 0, p ), 1 ), 0, p )
#else
#define VEC_STORE8( v, p ) vec_xst_len( v, p, 8 )
#endif

/***********************************************************************
 * VEC_TRANSPOSE_8
 ***********************************************************************
 * Transposes a 8x8 matrix of s16 vectors
 **********************************************************************/
#define VEC_TRANSPOSE_8(a0,a1,a2,a3,a4,a5,a6,a7,b0,b1,b2,b3,b4,b5,b6,b7) \
    b0 = vec_mergeh( a0, a4 ); \
    b1 = vec_mergel( a0, a4 ); \
    b2 = vec_mergeh( a1, a5 ); \
    b3 = vec_mergel( a1, a5 ); \
    b4 = vec_mergeh( a2, a6 ); \
    b5 = vec_mergel( a2, a6 ); \
    b6 = vec_mergeh( a3, a7 ); \
    b7 = vec_mergel( a3, a7 ); \
    a0 = vec_mergeh( b0, b4 ); \
    a1 = vec_mergel( b0, b4 ); \
    a2 = vec_mergeh( b1, b5 ); \
    a3 = vec_mergel( b1, b5 ); \
    a4 = vec_mergeh( b2, b6 ); \
    a5 = vec_mergel( b2, b6 ); \
    a6 = vec_mergeh( b3, b7 ); \
    a7 = vec_mergel( b3, b7 ); \
    b0 = vec_mergeh( a0, a4 ); \
    b1 = vec_mergel( a0, a4 ); \
    b2 = vec_mergeh( a1, a5 ); \
    b3 = vec_mergel( a1, a5 ); \
    b4 = vec_mergeh( a2, a6 ); \
    b5 = vec_mergel( a2, a6 ); \
    b6 = vec_mergeh( a3, a7 ); \
    b7 = vec_mergel( a3, a7 )

/***********************************************************************
 * VEC_TRANSPOSE_4
 ***********************************************************************
 * Transposes a 4x4 matrix of s16 vectors.
 * Actually source and destination are 8x4. The low elements of the
 * source are discarded and the low elements of the destination mustn't
 * be used.
 **********************************************************************/
#define VEC_TRANSPOSE_4(a0,a1,a2,a3,b0,b1,b2,b3) \
    b0 = vec_mergeh( a0, a0 ); \
    b1 = vec_mergeh( a1, a0 ); \
    b2 = vec_mergeh( a2, a0 ); \
    b3 = vec_mergeh( a3, a0 ); \
    a0 = vec_mergeh( b0, b2 ); \
    a1 = vec_mergel( b0, b2 ); \
    a2 = vec_mergeh( b1, b3 ); \
    a3 = vec_mergel( b1, b3 ); \
    b0 = vec_mergeh( a0, a2 ); \
    b1 = vec_mergel( a0, a2 ); \
    b2 = vec_mergeh( a1, a3 ); \
    b3 = vec_mergel( a1, a3 )

/***********************************************************************
 * VEC_DIFF_H
 ***********************************************************************
 * p1, p2:    u8 *
 * i1, i2, n: int
 * d:         s16v
 *
 * Loads n bytes from p1 and p2, do the diff of the high elements into
 * d, increments p1 and p2 by i1 and i2 into known offset g
 **********************************************************************/
#define PREP_DIFF           \
    LOAD_ZERO;              \
    vec_s16_t pix1v, pix2v;

#define VEC_DIFF_H(p1,i1,p2,i2,n,d)                 \
    pix1v = vec_vsx_ld( 0, (int16_t *)p1 );         \
    pix1v = vec_u8_to_s16( pix1v );                 \
    pix2v = vec_vsx_ld( 0, (int16_t *)p2 );         \
    pix2v = vec_u8_to_s16( pix2v );                 \
    d     = vec_sub( pix1v, pix2v );                \
    p1   += i1;                                     \
    p2   += i2

/***********************************************************************
 * VEC_DIFF_HL
 ***********************************************************************
 * p1, p2: u8 *
 * i1, i2: int
 * dh, dl: s16v
 *
 * Loads 16 bytes from p1 and p2, do the diff of the high elements into
 * dh, the diff of the low elements into dl, increments p1 and p2 by i1
 * and i2
 **********************************************************************/
#define VEC_DIFF_HL(p1,i1,p2,i2,dh,dl)       \
    pix1v = (vec_s16_t)vec_ld(0, p1);        \
    temp0v = vec_u8_to_s16_h( pix1v );       \
    temp1v = vec_u8_to_s16_l( pix1v );       \
    pix2v = vec_vsx_ld( 0, (int16_t *)p2 );  \
    temp2v = vec_u8_to_s16_h( pix2v );       \
    temp3v = vec_u8_to_s16_l( pix2v );       \
    dh     = vec_sub( temp0v, temp2v );      \
    dl     = vec_sub( temp1v, temp3v );      \
    p1    += i1;                             \
    p2    += i2

/***********************************************************************
* VEC_DIFF_H_8BYTE_ALIGNED
***********************************************************************
* p1, p2:    u8 *
* i1, i2, n: int
* d:         s16v
*
* Loads n bytes from p1 and p2, do the diff of the high elements into
* d, increments p1 and p2 by i1 and i2
* Slightly faster when we know we are loading/diffing 8bytes which
* are 8 byte aligned. Reduces need for two loads and two vec_lvsl()'s
**********************************************************************/
#define PREP_DIFF_8BYTEALIGNED \
LOAD_ZERO;                     \
vec_s16_t pix1v, pix2v;        \
vec_u8_t pix1v8, pix2v8;       \

#define VEC_DIFF_H_8BYTE_ALIGNED(p1,i1,p2,i2,n,d)     \
pix1v8 = vec_vsx_ld( 0, p1 );                         \
pix2v8 = vec_vsx_ld( 0, p2 );                         \
pix1v = vec_u8_to_s16( pix1v8 );                      \
pix2v = vec_u8_to_s16( pix2v8 );                      \
d = vec_sub( pix1v, pix2v);                           \
p1 += i1;                                             \
p2 += i2;

#if !HAVE_VSX
#undef vec_vsx_ld
#define vec_vsx_ld(off, src) \
    vec_perm(vec_ld(off, src), vec_ld(off + 15, src), vec_lvsl(off, src))

#undef vec_vsx_st
#define vec_vsx_st(v, off, dst)                            \
    do {                                                   \
        uint8_t *_dst = (uint8_t*)(dst);                   \
        vec_u8_t _v = (vec_u8_t)(v);                       \
        vec_u8_t _a = vec_ld(off, _dst);                   \
        vec_u8_t _b = vec_ld(off + 15, _dst);              \
        vec_u8_t _e = vec_perm(_b, _a, vec_lvsl(0, _dst)); \
        vec_u8_t _m = vec_lvsr(0, _dst);                   \
                                                           \
        vec_st(vec_perm(_v, _e, _m), off + 15, _dst);      \
        vec_st(vec_perm(_e, _v, _m), off, _dst);           \
    } while( 0 )
#endif

#ifndef __POWER9_VECTOR__
#define vec_absd( a, b ) vec_sub( vec_max( a, b ), vec_min( a, b ) )
#endif

// vec_xxpermdi is quite useful but some version of clang do not expose it
#if !HAVE_VSX || (defined(__clang__) && __clang_major__ < 6)
static const vec_u8_t xxpermdi0_perm = { 0x00, 0x01, 0x02, 0x03, 0x04, 0x05,
                                         0x06, 0x07, 0x10, 0x11, 0x12, 0x13,
                                         0x14, 0x15, 0x16, 0x17 };
static const vec_u8_t xxpermdi1_perm = { 0x00, 0x01, 0x02, 0x03, 0x04, 0x05,
                                         0x06, 0x07, 0x18, 0x19, 0x1A, 0x1B,
                                         0x1C, 0x1D, 0x1E, 0x1F };
static const vec_u8_t xxpermdi2_perm = { 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D,
                                         0x0E, 0x0F, 0x10, 0x11, 0x12, 0x13,
                                         0x14, 0x15, 0x16, 0x17 };
static const vec_u8_t xxpermdi3_perm = { 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D,
                                         0x0E, 0x0F, 0x18, 0x19, 0x1A, 0x1B,
                                         0x1C, 0x1D, 0x1E, 0x1F };
#define xxpermdi(a, b, c) vec_perm(a, b, xxpermdi##c##_perm)
#elif (defined(__GNUC__) && (__GNUC__ > 6 || (__GNUC__ == 6 && __GNUC_MINOR__ >= 3))) || \
      (defined(__clang__) && __clang_major__ >= 7)
#define xxpermdi(a, b, c) vec_xxpermdi(a, b, c)
#endif

// vec_xxpermdi has its endianness bias exposed in early gcc and clang
#ifdef WORDS_BIGENDIAN
#ifndef xxpermdi
#define xxpermdi(a, b, c) vec_xxpermdi(a, b, c)
#endif
#else
#ifndef xxpermdi
#define xxpermdi(a, b, c) vec_xxpermdi(b, a, ((c >> 1) | (c & 1) << 1) ^ 3)
#endif
#endif
