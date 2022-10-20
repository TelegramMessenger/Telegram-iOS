/*****************************************************************************
 * deblock.c: ppc deblocking
 *****************************************************************************
 * Copyright (C) 2007-2022 x264 project
 *
 * Authors: Guillaume Poirier <gpoirier@mplayerhq.hu>
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

#include "common/common.h"
#include "ppccommon.h"
#include "deblock.h"

#if !HIGH_BIT_DEPTH
#define transpose4x16(r0, r1, r2, r3)        \
{                                            \
    register vec_u8_t r4;                    \
    register vec_u8_t r5;                    \
    register vec_u8_t r6;                    \
    register vec_u8_t r7;                    \
                                             \
    r4 = vec_mergeh(r0, r2);  /*0, 2 set 0*/ \
    r5 = vec_mergel(r0, r2);  /*0, 2 set 1*/ \
    r6 = vec_mergeh(r1, r3);  /*1, 3 set 0*/ \
    r7 = vec_mergel(r1, r3);  /*1, 3 set 1*/ \
                                             \
    r0 = vec_mergeh(r4, r6);  /*all set 0*/  \
    r1 = vec_mergel(r4, r6);  /*all set 1*/  \
    r2 = vec_mergeh(r5, r7);  /*all set 2*/  \
    r3 = vec_mergel(r5, r7);  /*all set 3*/  \
}

static inline void write16x4( uint8_t *dst, int dst_stride,
                              register vec_u8_t r0, register vec_u8_t r1,
                              register vec_u8_t r2, register vec_u8_t r3 )
{
    ALIGNED_16(unsigned char result[64]);
    uint32_t *src_int = (uint32_t *)result, *dst_int = (uint32_t *)dst;
    int int_dst_stride = dst_stride >> 2;

    vec_st(r0, 0, result);
    vec_st(r1, 16, result);
    vec_st(r2, 32, result);
    vec_st(r3, 48, result);
    /* FIXME: there has to be a better way!!!! */
    *dst_int = *src_int;
    *(dst_int+   int_dst_stride) = *(src_int + 1);
    *(dst_int+ 2*int_dst_stride) = *(src_int + 2);
    *(dst_int+ 3*int_dst_stride) = *(src_int + 3);
    *(dst_int+ 4*int_dst_stride) = *(src_int + 4);
    *(dst_int+ 5*int_dst_stride) = *(src_int + 5);
    *(dst_int+ 6*int_dst_stride) = *(src_int + 6);
    *(dst_int+ 7*int_dst_stride) = *(src_int + 7);
    *(dst_int+ 8*int_dst_stride) = *(src_int + 8);
    *(dst_int+ 9*int_dst_stride) = *(src_int + 9);
    *(dst_int+10*int_dst_stride) = *(src_int + 10);
    *(dst_int+11*int_dst_stride) = *(src_int + 11);
    *(dst_int+12*int_dst_stride) = *(src_int + 12);
    *(dst_int+13*int_dst_stride) = *(src_int + 13);
    *(dst_int+14*int_dst_stride) = *(src_int + 14);
    *(dst_int+15*int_dst_stride) = *(src_int + 15);
}

/** \brief performs a 6x16 transpose of data in src, and stores it to dst */
#define read_and_transpose16x6(src, src_stride, r8, r9, r10, r11, r12, r13)\
{\
    register vec_u8_t r0, r1, r2, r3, r4, r5, r6, r7, r14, r15;\
    r0 = vec_vsx_ld(0, src);                                   \
    r1 = vec_vsx_ld(src_stride, src);                          \
    r2 = vec_vsx_ld(2*src_stride, src);                        \
    r3 = vec_vsx_ld(3*src_stride, src);                        \
    r4 = vec_vsx_ld(4*src_stride, src);                        \
    r5 = vec_vsx_ld(5*src_stride, src);                        \
    r6 = vec_vsx_ld(6*src_stride, src);                        \
    r7 = vec_vsx_ld(7*src_stride, src);                        \
    r8 = vec_vsx_ld(8*src_stride, src);                        \
    r9 = vec_vsx_ld(9*src_stride, src);                        \
    r10 = vec_vsx_ld(10*src_stride, src);                      \
    r11 = vec_vsx_ld(11*src_stride, src);                      \
    r12 = vec_vsx_ld(12*src_stride, src);                      \
    r13 = vec_vsx_ld(13*src_stride, src);                      \
    r14 = vec_vsx_ld(14*src_stride, src);                      \
    r15 = vec_vsx_ld(15*src_stride, src);                      \
                                                               \
    /*Merge first pairs*/                                      \
    r0 = vec_mergeh(r0, r8);    /*0, 8*/                       \
    r1 = vec_mergeh(r1, r9);    /*1, 9*/                       \
    r2 = vec_mergeh(r2, r10);   /*2,10*/                       \
    r3 = vec_mergeh(r3, r11);   /*3,11*/                       \
    r4 = vec_mergeh(r4, r12);   /*4,12*/                       \
    r5 = vec_mergeh(r5, r13);   /*5,13*/                       \
    r6 = vec_mergeh(r6, r14);   /*6,14*/                       \
    r7 = vec_mergeh(r7, r15);   /*7,15*/                       \
                                                               \
    /*Merge second pairs*/                                     \
    r8  = vec_mergeh(r0, r4);   /*0,4, 8,12 set 0*/            \
    r9  = vec_mergel(r0, r4);   /*0,4, 8,12 set 1*/            \
    r10 = vec_mergeh(r1, r5);   /*1,5, 9,13 set 0*/            \
    r11 = vec_mergel(r1, r5);   /*1,5, 9,13 set 1*/            \
    r12 = vec_mergeh(r2, r6);   /*2,6,10,14 set 0*/            \
    r13 = vec_mergel(r2, r6);   /*2,6,10,14 set 1*/            \
    r14 = vec_mergeh(r3, r7);   /*3,7,11,15 set 0*/            \
    r15 = vec_mergel(r3, r7);   /*3,7,11,15 set 1*/            \
                                                               \
    /*Third merge*/                                            \
    r0 = vec_mergeh(r8, r12);   /*0,2,4,6,8,10,12,14 set 0*/   \
    r1 = vec_mergel(r8, r12);   /*0,2,4,6,8,10,12,14 set 1*/   \
    r2 = vec_mergeh(r9, r13);   /*0,2,4,6,8,10,12,14 set 2*/   \
    r4 = vec_mergeh(r10, r14);  /*1,3,5,7,9,11,13,15 set 0*/   \
    r5 = vec_mergel(r10, r14);  /*1,3,5,7,9,11,13,15 set 1*/   \
    r6 = vec_mergeh(r11, r15);  /*1,3,5,7,9,11,13,15 set 2*/   \
    /* Don't need to compute 3 and 7*/                         \
                                                               \
    /*Final merge*/                                            \
    r8  = vec_mergeh(r0, r4);   /*all set 0*/                  \
    r9  = vec_mergel(r0, r4);   /*all set 1*/                  \
    r10 = vec_mergeh(r1, r5);   /*all set 2*/                  \
    r11 = vec_mergel(r1, r5);   /*all set 3*/                  \
    r12 = vec_mergeh(r2, r6);   /*all set 4*/                  \
    r13 = vec_mergel(r2, r6);   /*all set 5*/                  \
    /* Don't need to compute 14 and 15*/                       \
                                                               \
}

// out: o = |x-y| < a
static inline vec_u8_t diff_lt_altivec( register vec_u8_t x, register vec_u8_t y, register vec_u8_t a )
{
    return (vec_u8_t)vec_cmplt(vec_absd(x, y), a);
}

static inline vec_u8_t h264_deblock_mask( register vec_u8_t p0, register vec_u8_t p1, register vec_u8_t q0,
                                          register vec_u8_t q1, register vec_u8_t alpha, register vec_u8_t beta )
{
    register vec_u8_t mask;
    register vec_u8_t tempmask;

    mask = diff_lt_altivec(p0, q0, alpha);
    tempmask = diff_lt_altivec(p1, p0, beta);
    mask = vec_and(mask, tempmask);
    tempmask = diff_lt_altivec(q1, q0, beta);
    mask = vec_and(mask, tempmask);

    return mask;
}

// out: newp1 = clip((p2 + ((p0 + q0 + 1) >> 1)) >> 1, p1-tc0, p1+tc0)
static inline vec_u8_t h264_deblock_q1( register vec_u8_t p0, register vec_u8_t p1, register vec_u8_t p2,
                                        register vec_u8_t q0, register vec_u8_t tc0 )
{

    register vec_u8_t average = vec_avg(p0, q0);
    register vec_u8_t temp;
    register vec_u8_t uncliped;
    register vec_u8_t ones;
    register vec_u8_t max;
    register vec_u8_t min;
    register vec_u8_t newp1;

    temp = vec_xor(average, p2);
    average = vec_avg(average, p2);     /*avg(p2, avg(p0, q0)) */
    ones = vec_splat_u8(1);
    temp = vec_and(temp, ones);         /*(p2^avg(p0, q0)) & 1 */
    uncliped = vec_subs(average, temp); /*(p2+((p0+q0+1)>>1))>>1 */
    max = vec_adds(p1, tc0);
    min = vec_subs(p1, tc0);
    newp1 = vec_max(min, uncliped);
    newp1 = vec_min(max, newp1);
    return newp1;
}

#define h264_deblock_p0_q0(p0, p1, q0, q1, tc0masked)                                           \
{                                                                                               \
    const vec_u8_t A0v = vec_sl(vec_splat_u8(10), vec_splat_u8(4));                             \
                                                                                                \
    register vec_u8_t pq0bit = vec_xor(p0,q0);                                                  \
    register vec_u8_t q1minus;                                                                  \
    register vec_u8_t p0minus;                                                                  \
    register vec_u8_t stage1;                                                                   \
    register vec_u8_t stage2;                                                                   \
    register vec_u8_t vec160;                                                                   \
    register vec_u8_t delta;                                                                    \
    register vec_u8_t deltaneg;                                                                 \
                                                                                                \
    q1minus = vec_nor(q1, q1);                /* 255 - q1 */                                    \
    stage1 = vec_avg(p1, q1minus);            /* (p1 - q1 + 256)>>1 */                          \
    stage2 = vec_sr(stage1, vec_splat_u8(1)); /* (p1 - q1 + 256)>>2 = 64 + (p1 - q1) >> 2 */    \
    p0minus = vec_nor(p0, p0);                /* 255 - p0 */                                    \
    stage1 = vec_avg(q0, p0minus);            /* (q0 - p0 + 256)>>1 */                          \
    pq0bit = vec_and(pq0bit, vec_splat_u8(1));                                                  \
    stage2 = vec_avg(stage2, pq0bit);         /* 32 + ((q0 - p0)&1 + (p1 - q1) >> 2 + 1) >> 1 */\
    stage2 = vec_adds(stage2, stage1);        /* 160 + ((p0 - q0) + (p1 - q1) >> 2 + 1) >> 1 */ \
    vec160 = vec_ld(0, &A0v);                                                                   \
    deltaneg = vec_subs(vec160, stage2);      /* -d */                                          \
    delta = vec_subs(stage2, vec160);         /*  d */                                          \
    deltaneg = vec_min(tc0masked, deltaneg);                                                    \
    delta = vec_min(tc0masked, delta);                                                          \
    p0 = vec_subs(p0, deltaneg);                                                                \
    q0 = vec_subs(q0, delta);                                                                   \
    p0 = vec_adds(p0, delta);                                                                   \
    q0 = vec_adds(q0, deltaneg);                                                                \
}

#define h264_loop_filter_luma_altivec(p2, p1, p0, q0, q1, q2, alpha, beta, tc0)              \
{                                                                                            \
    ALIGNED_16(unsigned char temp[16]);                                                      \
    register vec_u8_t alphavec;                                                              \
    register vec_u8_t betavec;                                                               \
    register vec_u8_t mask;                                                                  \
    register vec_u8_t p1mask;                                                                \
    register vec_u8_t q1mask;                                                                \
    register vec_s8_t tc0vec;                                                                \
    register vec_u8_t finaltc0;                                                              \
    register vec_u8_t tc0masked;                                                             \
    register vec_u8_t newp1;                                                                 \
    register vec_u8_t newq1;                                                                 \
                                                                                             \
    temp[0] = alpha;                                                                         \
    temp[1] = beta;                                                                          \
    alphavec = vec_ld(0, temp);                                                              \
    betavec = vec_splat(alphavec, 0x1);                                                      \
    alphavec = vec_splat(alphavec, 0x0);                                                     \
    mask = h264_deblock_mask(p0, p1, q0, q1, alphavec, betavec); /*if in block */            \
                                                                                             \
    M32( temp ) = M32( tc0 );                                                                \
    tc0vec = vec_ld(0, (signed char*)temp);                                                  \
    tc0vec = vec_mergeh(tc0vec, tc0vec);                                                     \
    tc0vec = vec_mergeh(tc0vec, tc0vec);                                                     \
    mask = vec_and(mask, vec_cmpgt(tc0vec, vec_splat_s8(-1)));  /* if tc0[i] >= 0 */         \
    finaltc0 = vec_and((vec_u8_t)tc0vec, mask);                 /* tc = tc0 */               \
                                                                                             \
    p1mask = diff_lt_altivec(p2, p0, betavec);                                               \
    p1mask = vec_and(p1mask, mask);                             /* if( |p2 - p0| < beta ) */ \
    tc0masked = vec_and(p1mask, (vec_u8_t)tc0vec);                                           \
    finaltc0 = vec_sub(finaltc0, p1mask);                       /* tc++ */                   \
    newp1 = h264_deblock_q1(p0, p1, p2, q0, tc0masked);                                      \
    /*end if*/                                                                               \
                                                                                             \
    q1mask = diff_lt_altivec(q2, q0, betavec);                                               \
    q1mask = vec_and(q1mask, mask);                             /* if( |q2 - q0| < beta ) */ \
    tc0masked = vec_and(q1mask, (vec_u8_t)tc0vec);                                           \
    finaltc0 = vec_sub(finaltc0, q1mask);                       /* tc++ */                   \
    newq1 = h264_deblock_q1(p0, q1, q2, q0, tc0masked);                                      \
    /*end if*/                                                                               \
                                                                                             \
    h264_deblock_p0_q0(p0, p1, q0, q1, finaltc0);                                            \
    p1 = newp1;                                                                              \
    q1 = newq1;                                                                              \
}

void x264_deblock_v_luma_altivec( uint8_t *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 )
{
    if( (tc0[0] & tc0[1] & tc0[2] & tc0[3]) >= 0 )
    {
        register vec_u8_t p2 = vec_ld(-3*stride, pix);
        register vec_u8_t p1 = vec_ld(-2*stride, pix);
        register vec_u8_t p0 = vec_ld(-1*stride, pix);
        register vec_u8_t q0 = vec_ld(0, pix);
        register vec_u8_t q1 = vec_ld(stride, pix);
        register vec_u8_t q2 = vec_ld(2*stride, pix);
        h264_loop_filter_luma_altivec(p2, p1, p0, q0, q1, q2, alpha, beta, tc0);
        vec_st(p1, -2*stride, pix);
        vec_st(p0, -1*stride, pix);
        vec_st(q0, 0, pix);
        vec_st(q1, stride, pix);
    }
}

void x264_deblock_h_luma_altivec( uint8_t *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 )
{

    register vec_u8_t line0, line1, line2, line3, line4, line5;
    if( (tc0[0] & tc0[1] & tc0[2] & tc0[3]) < 0 )
        return;
    read_and_transpose16x6(pix-3, stride, line0, line1, line2, line3, line4, line5);
    h264_loop_filter_luma_altivec(line0, line1, line2, line3, line4, line5, alpha, beta, tc0);
    transpose4x16(line1, line2, line3, line4);
    write16x4(pix-2, stride, line1, line2, line3, line4);
}
#endif // !HIGH_BIT_DEPTH
