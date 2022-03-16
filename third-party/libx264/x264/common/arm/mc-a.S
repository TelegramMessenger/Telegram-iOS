/*****************************************************************************
 * mc.S: arm motion compensation
 *****************************************************************************
 * Copyright (C) 2009-2022 x264 project
 *
 * Authors: David Conrad <lessen42@gmail.com>
 *          Mans Rullgard <mans@mansr.com>
 *          Stefan Groenroos <stefan.gronroos@gmail.com>
 *          Janne Grunau <janne-x264@jannau.net>
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

#include "asm.S"

const pw_0to15, align=4
.short 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
endconst

.text

// note: prefetch stuff assumes 64-byte cacheline, true for the Cortex-A8
// They also use nothing above armv5te, but we don't care about pre-armv6

// void prefetch_ref( uint8_t *pix, intptr_t stride, int parity )
function prefetch_ref_arm
    sub         r2, r2, #1
    add         r0, r0, #64
    and         r2, r2, r1
    add         r0, r0, r2, lsl #3
    add         r2, r1, r1, lsl #1
    pld         [r0]
    pld         [r0, r1]
    pld         [r0, r1, lsl #1]
    add         r3, r0, r1, lsl #2
    pld         [r0, r2]
    pld         [r3]
    pld         [r3, r1]
    pld         [r3, r1, lsl #1]
    pld         [r3, r2]
    bx          lr
endfunc

// void prefetch_fenc( uint8_t *pix_y,  intptr_t stride_y,
//                     uint8_t *pix_uv, intptr_t stride_uv, int mb_x )
function prefetch_fenc_arm
    ldr         ip, [sp]
    push        {lr}
    and         lr, ip, #3
    smulbb      lr, lr, r1      // note: this assumes stride_y is <= 16 bits signed
    and         ip, ip, #6
    smulbb      ip, ip, r3
    add         r0, r0, #64
    add         r2, r2, #64
    add         r0, r0, lr, lsl #2
    pld         [r0]
    add         lr, r0, r1, lsl #1
    pld         [r0, r1]
    pld         [lr]
    add         r2, r2, ip, lsl #2
    pld         [lr, r1]
    pld         [r2]
    add         ip, r2, r3, lsl #1
    pld         [r2, r3]
    pld         [ip]
    pld         [ip, r3]
    pop         {pc}
endfunc


// void *memcpy_aligned( void *dst, const void *src, size_t n )
function memcpy_aligned_neon
    orr         r3,  r0,  r1,  lsr #1
    movrel      ip,  memcpy_table
    and         r3,  r3,  #0xc
    ldr         pc,  [ip, r3]
endfunc

.macro MEMCPY_ALIGNED srcalign dstalign
function memcpy_aligned_\dstalign\()_\srcalign\()_neon, export=0
    mov         r3, r0
.if \srcalign == 8 && \dstalign == 8
    sub         r2, #16
    vld1.64     {d0}, [r1,:64]!
    vst1.64     {d0}, [r3,:64]!
    .set r1align, 128
    .set r3align, 128
.else
    .set r1align, \srcalign * 8
    .set r3align, \dstalign * 8
.endif
    tst         r2, #16
    beq         32f
    sub         r2, #16
    vld1.64     {d0-d1}, [r1,:r1align]!
    vst1.64     {d0-d1}, [r3,:r3align]!
32: // n is a multiple of 32
    tst         r2, #32
    beq         640f
    sub         r2, #32
    vld1.64     {d0-d3}, [r1,:r1align]!
    vst1.64     {d0-d3}, [r3,:r3align]!
640: // n is a multiple of 64
    cmp         r2, #0
    beq         1f
64:
    subs        r2, #64
    vld1.64     {d0-d3}, [r1,:r1align]!
    vld1.64     {d4-d7}, [r1,:r1align]!
    vst1.64     {d0-d3}, [r3,:r3align]!
    vst1.64     {d4-d7}, [r3,:r3align]!
    bgt         64b
1:   // end
.if \srcalign == 8 && \dstalign == 8
    vld1.64     {d0}, [r1,:64]!
    vst1.64     {d0}, [r3,:64]!
.endif
    bx          lr
endfunc
.endm

MEMCPY_ALIGNED 16, 16
MEMCPY_ALIGNED 16, 8
MEMCPY_ALIGNED  8, 16
MEMCPY_ALIGNED  8, 8

const memcpy_table, align=2, relocate=1
.word memcpy_aligned_16_16_neon
.word memcpy_aligned_16_8_neon
.word memcpy_aligned_8_16_neon
.word memcpy_aligned_8_8_neon
endconst

.text

.ltorg

// void memzero_aligned( void *dst, size_t n )
function memzero_aligned_neon
    vmov.i8     q0, #0
    vmov.i8     q1, #0
memzero_loop:
    subs        r1, #128
.rept 4
    vst1.64     {d0-d3}, [r0,:128]!
.endr
    bgt         memzero_loop
    bx          lr
endfunc


// void pixel_avg( uint8_t *dst,  intptr_t dst_stride,
//                 uint8_t *src1, intptr_t src1_stride,
//                 uint8_t *src2, intptr_t src2_stride, int weight );
.macro AVGH w h
function pixel_avg_\w\()x\h\()_neon
    ldr         ip, [sp, #8]
    push        {r4-r6,lr}
    cmp         ip, #32
    ldrd        r4, r5, [sp, #16]
    mov         lr, #\h
    beq         pixel_avg_w\w\()_neon
    rsbs        r6,  ip,  #64
    blt         pixel_avg_weight_w\w\()_add_sub_neon     // weight > 64
    cmp         ip,  #0
    bge         pixel_avg_weight_w\w\()_add_add_neon
    b           pixel_avg_weight_w\w\()_sub_add_neon     // weight < 0
endfunc
.endm

AVGH  4, 2
AVGH  4, 4
AVGH  4, 8
AVGH  4, 16
AVGH  8, 4
AVGH  8, 8
AVGH  8, 16
AVGH 16, 8
AVGH 16, 16

// 0 < weight < 64
.macro load_weights_add_add
    vdup.8      d30, ip
    vdup.8      d31, r6
.endm

.macro load_add_add d1 d2
    vld1.32     {\d1}, [r2], r3
    vld1.32     {\d2}, [r4], r5
.endm

.macro weight_add_add dst s1 s2
    vmull.u8    \dst, \s1, d30
    vmlal.u8    \dst, \s2, d31
.endm

// weight > 64
.macro load_weights_add_sub
    rsb         r6,  #0
    vdup.8      d30, ip
    vdup.8      d31, r6
.endm

.macro load_add_sub d1 d2
    vld1.32     {\d1}, [r2], r3
    vld1.32     {\d2}, [r4], r5
.endm

.macro weight_add_sub dst s1 s2
    vmull.u8    \dst, \s1, d30
    vmlsl.u8    \dst, \s2, d31
.endm

// weight < 0
.macro load_weights_sub_add
    rsb         ip,  #0
    vdup.8      d31, r6
    vdup.8      d30, ip
.endm

.macro load_sub_add d1 d2
    vld1.32     {\d2}, [r4], r5
    vld1.32     {\d1}, [r2], r3
.endm

.macro weight_sub_add dst s1 s2
    vmull.u8    \dst, \s2, d31
    vmlsl.u8    \dst, \s1, d30
.endm

.macro AVG_WEIGHT ext
function pixel_avg_weight_w4_\ext\()_neon, export=0
    load_weights_\ext
1:  // height loop
    subs            lr,  lr,  #2
    load_\ext       d0[], d1[]
    weight_\ext     q8,  d0,  d1
    load_\ext       d2[], d3[]
    vqrshrun.s16    d0,  q8,  #6
    weight_\ext     q9,  d2,  d3
    vst1.32         {d0[0]}, [r0,:32], r1
    vqrshrun.s16    d1,  q9,  #6
    vst1.32         {d1[0]}, [r0,:32], r1
    bgt             1b
    pop             {r4-r6,pc}
endfunc

function pixel_avg_weight_w8_\ext\()_neon, export=0
    load_weights_\ext
1:  // height loop
    subs            lr,  lr,  #4
    load_\ext       d0,  d1
    weight_\ext     q8,  d0,  d1
    load_\ext       d2,  d3
    weight_\ext     q9,  d2,  d3
    load_\ext       d4,  d5
    weight_\ext     q10, d4,  d5
    load_\ext       d6,  d7
    weight_\ext     q11, d6,  d7
    vqrshrun.s16    d0,  q8,  #6
    vqrshrun.s16    d1,  q9,  #6
    vqrshrun.s16    d2,  q10, #6
    vqrshrun.s16    d3,  q11, #6
    vst1.64         {d0}, [r0,:64], r1
    vst1.64         {d1}, [r0,:64], r1
    vst1.64         {d2}, [r0,:64], r1
    vst1.64         {d3}, [r0,:64], r1
    bgt             1b
    pop             {r4-r6,pc}
endfunc

function pixel_avg_weight_w16_\ext\()_neon, export=0
    load_weights_\ext
1:  // height loop
    subs            lr,  lr,  #2
    load_\ext       d0-d1, d2-d3
    weight_\ext     q8,  d0,  d2
    weight_\ext     q9,  d1,  d3
    load_\ext       d4-d5, d6-d7
    weight_\ext     q10, d4,  d6
    weight_\ext     q11, d5,  d7
    vqrshrun.s16    d0,  q8,  #6
    vqrshrun.s16    d1,  q9,  #6
    vqrshrun.s16    d2,  q10, #6
    vqrshrun.s16    d3,  q11, #6
    vst1.64         {d0-d1}, [r0,:128], r1
    vst1.64         {d2-d3}, [r0,:128], r1
    bgt             1b
    pop             {r4-r6,pc}
endfunc
.endm

AVG_WEIGHT add_add
AVG_WEIGHT add_sub
AVG_WEIGHT sub_add

function pixel_avg_w4_neon, export=0
    subs        lr,  lr,  #2
    vld1.32     {d0[]}, [r2], r3
    vld1.32     {d2[]}, [r4], r5
    vrhadd.u8   d0,  d0,  d2
    vld1.32     {d1[]}, [r2], r3
    vld1.32     {d3[]}, [r4], r5
    vrhadd.u8   d1,  d1,  d3
    vst1.32     {d0[0]}, [r0,:32], r1
    vst1.32     {d1[0]}, [r0,:32], r1
    bgt         pixel_avg_w4_neon
    pop         {r4-r6,pc}
endfunc

function pixel_avg_w8_neon, export=0
    subs        lr,  lr,  #4
    vld1.64     {d0}, [r2], r3
    vld1.64     {d2}, [r4], r5
    vrhadd.u8   d0,  d0,  d2
    vld1.64     {d1}, [r2], r3
    vld1.64     {d3}, [r4], r5
    vrhadd.u8   d1,  d1,  d3
    vst1.64     {d0}, [r0,:64], r1
    vld1.64     {d2}, [r2], r3
    vld1.64     {d4}, [r4], r5
    vrhadd.u8   d2,  d2,  d4
    vst1.64     {d1}, [r0,:64], r1
    vld1.64     {d3}, [r2], r3
    vld1.64     {d5}, [r4], r5
    vrhadd.u8   d3,  d3,  d5
    vst1.64     {d2}, [r0,:64], r1
    vst1.64     {d3}, [r0,:64], r1
    bgt         pixel_avg_w8_neon
    pop         {r4-r6,pc}
endfunc

function pixel_avg_w16_neon, export=0
    subs        lr,  lr,  #4
    vld1.64     {d0-d1}, [r2], r3
    vld1.64     {d2-d3}, [r4], r5
    vrhadd.u8   q0,  q0,  q1
    vld1.64     {d2-d3}, [r2], r3
    vld1.64     {d4-d5}, [r4], r5
    vrhadd.u8   q1,  q1,  q2
    vst1.64     {d0-d1}, [r0,:128], r1
    vld1.64     {d4-d5}, [r2], r3
    vld1.64     {d6-d7}, [r4], r5
    vrhadd.u8   q2,  q2,  q3
    vst1.64     {d2-d3}, [r0,:128], r1
    vld1.64     {d6-d7}, [r2], r3
    vld1.64     {d0-d1}, [r4], r5
    vrhadd.u8   q3,  q3,  q0
    vst1.64     {d4-d5}, [r0,:128], r1
    vst1.64     {d6-d7}, [r0,:128], r1
    bgt         pixel_avg_w16_neon
    pop         {r4-r6,pc}
endfunc


function pixel_avg2_w4_neon
    ldr         ip,  [sp, #4]
    push        {lr}
    ldr         lr,  [sp, #4]
avg2_w4_loop:
    subs        ip,  ip,  #2
    vld1.32     {d0[]},  [r2], r3
    vld1.32     {d2[]},  [lr], r3
    vrhadd.u8   d0,  d0,  d2
    vld1.32     {d1[]},  [r2], r3
    vld1.32     {d3[]},  [lr], r3
    vrhadd.u8   d1,  d1,  d3
    vst1.32     {d0[0]}, [r0,:32], r1
    vst1.32     {d1[0]}, [r0,:32], r1
    bgt         avg2_w4_loop
    pop         {pc}
endfunc

function pixel_avg2_w8_neon
    ldr         ip,  [sp, #4]
    push        {lr}
    ldr         lr,  [sp, #4]
avg2_w8_loop:
    subs        ip,  ip,  #2
    vld1.64     {d0}, [r2], r3
    vld1.64     {d2}, [lr], r3
    vrhadd.u8   d0,  d0,  d2
    vld1.64     {d1}, [r2], r3
    vld1.64     {d3}, [lr], r3
    vrhadd.u8   d1,  d1,  d3
    vst1.64     {d0}, [r0,:64], r1
    vst1.64     {d1}, [r0,:64], r1
    bgt         avg2_w8_loop
    pop         {pc}
endfunc

function pixel_avg2_w16_neon
    ldr         ip,  [sp, #4]
    push        {lr}
    ldr         lr,  [sp, #4]
avg2_w16_loop:
    subs        ip,  ip,  #2
    vld1.64     {d0-d1}, [r2], r3
    vld1.64     {d2-d3}, [lr], r3
    vrhadd.u8   q0,  q0,  q1
    vld1.64     {d4-d5}, [r2], r3
    vld1.64     {d6-d7}, [lr], r3
    vrhadd.u8   q2,  q2,  q3
    vst1.64     {d0-d1}, [r0,:128], r1
    vst1.64     {d4-d5}, [r0,:128], r1
    bgt         avg2_w16_loop
    pop         {pc}
endfunc

function pixel_avg2_w20_neon
    ldr         ip,  [sp, #4]
    push        {lr}
    sub         r1,  r1,  #16
    ldr         lr,  [sp, #4]
avg2_w20_loop:
    subs        ip,  ip,  #2
    vld1.64     {d0-d2},  [r2], r3
    vld1.64     {d4-d6},  [lr], r3
    vrhadd.u8   q0,  q0,  q2
    vrhadd.u8   d2,  d2,  d6
    vld1.64     {d4-d6},  [r2], r3
    vld1.64     {d16-d18},[lr], r3
    vrhadd.u8   q2,  q2,  q8
    vst1.64     {d0-d1},  [r0,:128]!
    vrhadd.u8   d6,  d6,  d18
    vst1.32     {d2[0]},  [r0,:32], r1
    vst1.64     {d4-d5},  [r0,:128]!
    vst1.32     {d6[0]},  [r0,:32], r1
    bgt         avg2_w20_loop
    pop         {pc}
endfunc


.macro weight_prologue type
    push        {r4-r5,lr}
    ldr         r4,  [sp, #4*3]     // weight_t
    ldr         ip,  [sp, #4*3+4]   // h
.ifc \type, full
    ldr         lr,  [r4, #32]      // denom
.endif
    ldrd        r4,  r5,  [r4, #32+4]    // scale, offset
    vdup.8      d0,  r4
    vdup.16     q1,  r5
.ifc \type, full
    rsb         lr,  lr,  #0
    vdup.16     q2,  lr
.endif
.endm

// void mc_weight( uint8_t *src, intptr_t src_stride, uint8_t *dst, intptr_t dst_stride,
//                 const x264_weight_t *weight, int height )
function mc_weight_w20_neon
    weight_prologue full
    sub         r1, #16
weight20_loop:
    subs        ip,  #2
    vld1.8      {d17-d19}, [r2], r3
    vmull.u8    q10, d17, d0
    vmull.u8    q11, d18, d0
    vld1.8      {d16-d18}, [r2], r3
    vmull.u8    q12, d16, d0
    vmull.u8    q13, d17, d0
    vtrn.32     d19, d18
    vmull.u8    q14, d19, d0
    vrshl.s16   q10, q10, q2
    vrshl.s16   q11, q11, q2
    vrshl.s16   q12, q12, q2
    vrshl.s16   q13, q13, q2
    vrshl.s16   q14, q14, q2
    vadd.s16    q10, q10, q1
    vadd.s16    q11, q11, q1
    vadd.s16    q12, q12, q1
    vadd.s16    q13, q13, q1
    vadd.s16    q14, q14, q1
    vqmovun.s16 d16, q10
    vqmovun.s16 d17, q11
    vqmovun.s16 d18, q12
    vqmovun.s16 d19, q13
    vqmovun.s16 d20, q14
    vst1.8      {d16-d17}, [r0,:128]!
    vst1.32     {d20[0]},  [r0,:32], r1
    vst1.8      {d18-d19}, [r0,:128]!
    vst1.32     {d20[1]},  [r0,:32], r1
    bgt         weight20_loop
    pop         {r4-r5,pc}
endfunc

function mc_weight_w16_neon
    weight_prologue full
weight16_loop:
    subs        ip,  #2
    vld1.8      {d16-d17}, [r2], r3
    vld1.8      {d18-d19}, [r2], r3
    vmull.u8    q10, d16, d0
    vmull.u8    q11, d17, d0
    vmull.u8    q12, d18, d0
    vmull.u8    q13, d19, d0
    vrshl.s16   q10, q10, q2
    vrshl.s16   q11, q11, q2
    vrshl.s16   q12, q12, q2
    vrshl.s16   q13, q13, q2
    vadd.s16    q10, q10, q1
    vadd.s16    q11, q11, q1
    vadd.s16    q12, q12, q1
    vadd.s16    q13, q13, q1
    vqmovun.s16 d16, q10
    vqmovun.s16 d17, q11
    vqmovun.s16 d18, q12
    vqmovun.s16 d19, q13
    vst1.8      {d16-d17}, [r0,:128], r1
    vst1.8      {d18-d19}, [r0,:128], r1
    bgt         weight16_loop
    pop         {r4-r5,pc}
endfunc

function mc_weight_w8_neon
    weight_prologue full
weight8_loop:
    subs        ip,  #2
    vld1.8      {d16}, [r2], r3
    vld1.8      {d18}, [r2], r3
    vmull.u8    q8,  d16, d0
    vmull.u8    q9,  d18, d0
    vrshl.s16   q8,  q8,  q2
    vrshl.s16   q9,  q9,  q2
    vadd.s16    q8,  q8,  q1
    vadd.s16    q9,  q9,  q1
    vqmovun.s16 d16, q8
    vqmovun.s16 d18, q9
    vst1.8      {d16}, [r0,:64], r1
    vst1.8      {d18}, [r0,:64], r1
    bgt         weight8_loop
    pop         {r4-r5,pc}
endfunc

function mc_weight_w4_neon
    weight_prologue full
weight4_loop:
    subs        ip,  #2
    vld1.32     {d16[0]}, [r2], r3
    vld1.32     {d16[1]}, [r2], r3
    vmull.u8    q8,  d16, d0
    vrshl.s16   q8,  q8,  q2
    vadd.s16    q8,  q8,  q1
    vqmovun.s16 d16, q8
    vst1.32     {d16[0]}, [r0], r1
    vst1.32     {d16[1]}, [r0], r1
    bgt         weight4_loop
    pop         {r4-r5,pc}
endfunc

function mc_weight_w20_nodenom_neon
    weight_prologue nodenom
    sub         r1, #16
weight20_nodenom_loop:
    subs        ip,  #2
    vld1.8      {d26-d28}, [r2], r3
    vmov        q8,  q1
    vmov        q9,  q1
    vld1.8      {d29-d31}, [r2], r3
    vmov        q10, q1
    vmov        q11, q1
    vmov        q12, q1
    vtrn.32     d28, d31
    vmlal.u8    q8,  d26, d0
    vmlal.u8    q9,  d27, d0
    vmlal.u8    q10, d29, d0
    vmlal.u8    q11, d30, d0
    vmlal.u8    q12, d28, d0
    vqmovun.s16 d16, q8
    vqmovun.s16 d17, q9
    vqmovun.s16 d18, q10
    vqmovun.s16 d19, q11
    vqmovun.s16 d20, q12
    vst1.8      {d16-d17}, [r0,:128]!
    vst1.32     {d20[0]},  [r0,:32], r1
    vst1.8      {d18-d19}, [r0,:128]!
    vst1.32     {d20[1]},  [r0,:32], r1
    bgt         weight20_nodenom_loop
    pop         {r4-r5,pc}
endfunc

function mc_weight_w16_nodenom_neon
    weight_prologue nodenom
weight16_nodenom_loop:
    subs        ip,  #2
    vld1.8      {d16-d17}, [r2], r3
    vld1.8      {d18-d19}, [r2], r3
    vmov        q12, q1
    vmov        q13, q1
    vmov        q14, q1
    vmov        q15, q1
    vmlal.u8    q12, d16, d0
    vmlal.u8    q13, d17, d0
    vmlal.u8    q14, d18, d0
    vmlal.u8    q15, d19, d0
    vqmovun.s16 d16, q12
    vqmovun.s16 d17, q13
    vqmovun.s16 d18, q14
    vqmovun.s16 d19, q15
    vst1.8      {d16-d17}, [r0,:128], r1
    vst1.8      {d18-d19}, [r0,:128], r1
    bgt         weight16_nodenom_loop
    pop         {r4-r5,pc}
endfunc

function mc_weight_w8_nodenom_neon
    weight_prologue nodenom
weight8_nodenom_loop:
    subs        ip,  #2
    vld1.8      {d16}, [r2], r3
    vld1.8      {d18}, [r2], r3
    vmov        q10, q1
    vmov        q11, q1
    vmlal.u8    q10, d16, d0
    vmlal.u8    q11, d18, d0
    vqmovun.s16 d16, q10
    vqmovun.s16 d17, q11
    vst1.8      {d16}, [r0,:64], r1
    vst1.8      {d17}, [r0,:64], r1
    bgt         weight8_nodenom_loop
    pop         {r4-r5,pc}
endfunc

function mc_weight_w4_nodenom_neon
    weight_prologue nodenom
weight4_nodenom_loop:
    subs        ip,  #2
    vld1.32     {d16[0]}, [r2], r3
    vld1.32     {d16[1]}, [r2], r3
    vmov        q10, q1
    vmlal.u8    q10, d16, d0
    vqmovun.s16 d16, q10
    vst1.32     {d16[0]}, [r0], r1
    vst1.32     {d16[1]}, [r0], r1
    bgt         weight4_nodenom_loop
    pop         {r4-r5,pc}
endfunc

.macro weight_simple_prologue
    push        {lr}
    ldr         lr,  [sp, #4]       // weight_t
    ldr         ip,  [sp, #8]       // h
    ldr         lr,  [lr]           // offset
    vdup.8      q1,  lr
.endm

.macro weight_simple name op
function mc_weight_w20_\name\()_neon
    weight_simple_prologue
weight20_\name\()_loop:
    subs        ip,  #2
    vld1.8      {d16-d18}, [r2], r3
    vld1.8      {d19-d21}, [r2], r3
    \op         q8,  q8,  q1
    \op         q9,  q9,  q1
    \op         q10, q10, q1
    vst1.8      {d16-d18}, [r0,:64], r1
    vst1.8      {d19-d21}, [r0,:64], r1
    bgt         weight20_\name\()_loop
    pop         {pc}
endfunc

function mc_weight_w16_\name\()_neon
    weight_simple_prologue
weight16_\name\()_loop:
    subs        ip,  #2
    vld1.8      {d16-d17}, [r2], r3
    vld1.8      {d18-d19}, [r2], r3
    \op         q8,  q8,  q1
    \op         q9,  q9,  q1
    vst1.8      {d16-d17}, [r0,:128], r1
    vst1.8      {d18-d19}, [r0,:128], r1
    bgt         weight16_\name\()_loop
    pop         {pc}
endfunc

function mc_weight_w8_\name\()_neon
    weight_simple_prologue
weight8_\name\()_loop:
    subs        ip,  #2
    vld1.8      {d16}, [r2], r3
    vld1.8      {d17}, [r2], r3
    \op         q8,  q8,  q1
    vst1.8      {d16}, [r0,:64], r1
    vst1.8      {d17}, [r0,:64], r1
    bgt         weight8_\name\()_loop
    pop         {pc}
endfunc

function mc_weight_w4_\name\()_neon
    weight_simple_prologue
weight4_\name\()_loop:
    subs        ip,  #2
    vld1.32     {d16[]}, [r2], r3
    vld1.32     {d17[]}, [r2], r3
    \op         q8,  q8,  q1
    vst1.32     {d16[0]}, [r0], r1
    vst1.32     {d17[0]}, [r0], r1
    bgt         weight4_\name\()_loop
    pop         {pc}
endfunc
.endm

weight_simple offsetadd, vqadd.u8
weight_simple offsetsub, vqsub.u8


// void mc_copy( uint8_t *dst, intptr_t dst_stride, uint8_t *src, intptr_t src_stride, int height )
function mc_copy_w4_neon
    ldr         ip,  [sp]
copy_w4_loop:
    subs        ip,  ip,  #4
    vld1.32     {d0[]},  [r2], r3
    vld1.32     {d1[]},  [r2], r3
    vld1.32     {d2[]},  [r2], r3
    vld1.32     {d3[]},  [r2], r3
    vst1.32     {d0[0]}, [r0,:32], r1
    vst1.32     {d1[0]}, [r0,:32], r1
    vst1.32     {d2[0]}, [r0,:32], r1
    vst1.32     {d3[0]}, [r0,:32], r1
    bgt         copy_w4_loop
    bx          lr
endfunc

function mc_copy_w8_neon
    ldr         ip,  [sp]
copy_w8_loop:
    subs        ip,  ip,  #4
    vld1.32     {d0}, [r2], r3
    vld1.32     {d1}, [r2], r3
    vld1.32     {d2}, [r2], r3
    vld1.32     {d3}, [r2], r3
    vst1.32     {d0}, [r0,:64], r1
    vst1.32     {d1}, [r0,:64], r1
    vst1.32     {d2}, [r0,:64], r1
    vst1.32     {d3}, [r0,:64], r1
    bgt         copy_w8_loop
    bx          lr
endfunc

function mc_copy_w16_neon
    ldr         ip,  [sp]
copy_w16_loop:
    subs        ip,  ip,  #4
    vld1.32     {d0-d1}, [r2], r3
    vld1.32     {d2-d3}, [r2], r3
    vld1.32     {d4-d5}, [r2], r3
    vld1.32     {d6-d7}, [r2], r3
    vst1.32     {d0-d1}, [r0,:128], r1
    vst1.32     {d2-d3}, [r0,:128], r1
    vst1.32     {d4-d5}, [r0,:128], r1
    vst1.32     {d6-d7}, [r0,:128], r1
    bgt         copy_w16_loop
    bx          lr
endfunc

function mc_copy_w16_aligned_neon
    ldr         ip,  [sp]
copy_w16_aligned_loop:
    subs        ip,  ip,  #4
    vld1.32     {d0-d1}, [r2,:128], r3
    vld1.32     {d2-d3}, [r2,:128], r3
    vld1.32     {d4-d5}, [r2,:128], r3
    vld1.32     {d6-d7}, [r2,:128], r3
    vst1.32     {d0-d1}, [r0,:128], r1
    vst1.32     {d2-d3}, [r0,:128], r1
    vst1.32     {d4-d5}, [r0,:128], r1
    vst1.32     {d6-d7}, [r0,:128], r1
    bgt         copy_w16_aligned_loop
    bx          lr
endfunc


// void mc_chroma( uint8_t *dst, intptr_t i_dst_stride,
//                 uint8_t *src, intptr_t i_src_stride,
//                 int dx, int dy, int i_width, int i_height );
function mc_chroma_neon
    push            {r4-r8, lr}
    vpush           {d8-d11}
    ldrd            r4, r5, [sp, #56]
    ldrd            r6, r7, [sp, #64]

    asr             lr, r6, #3
    mul             lr, r4, lr
    add             r3, r3, r5, asr #2
    cmp             r7, #4

    and             r5, r5, #7
    and             r6, r6, #7

    add             r3, r3, lr
    bic             r3, r3, #0x1

    pld             [r3]
    pld             [r3, r4]

    bgt             mc_chroma_w8
    beq             mc_chroma_w4

.macro CHROMA_MC_START r00, r01, r10, r11
    muls            lr, r5, r6
    rsb             r7, lr, r6, lsl #3
    rsb             ip, lr, r5, lsl #3
    sub             r5, lr, r5, lsl #3
    sub             r5, r5, r6, lsl #3
    add             r5, r5, #64

    beq             2f
    vld2.8          {\r00-\r01}, [r3], r4

    vdup.8          d0,    r5
    vdup.8          d1,    ip

    vdup.8          d2,    r7
    vld2.8          {\r10-\r11}, [r3], r4
    vdup.8          d3,    lr
    ldr             r5,    [sp, #72]
.endm

.macro CHROMA_MC width, align
mc_chroma_w\width:
    CHROMA_MC_START d4, d5,  d8, d9
    vext.8          d6,  d4,  d6,  #1
    vext.8          d7,  d5,  d7,  #1
    vext.8          d10, d8,  d10, #1
    vext.8          d11, d9,  d11, #1
// since the element size varies, there's a different index for the 2nd store
.if \width == 4
    .set st2, 1
.else
    .set st2, 2
.endif

    vtrn.32         d4, d6
    vtrn.32         d5, d7
    vtrn.32         d8, d10
    vtrn.32         d9, d11

    vtrn.32         d0, d1
    vtrn.32         d2, d3

1:  // height loop, interpolate xy

    vmull.u8        q8,  d4,  d0
    vmlal.u8        q8,  d8,  d2
    vmull.u8        q9,  d5,  d0
    vmlal.u8        q9,  d9,  d2

    vld2.8          {d4-d5},  [r3], r4

    vext.8          d6,  d4,  d6,  #1
    vext.8          d7,  d5,  d7,  #1

    vadd.i16        d16, d16, d17
    vadd.i16        d17, d18, d19

    vtrn.32         d4,  d6
    vtrn.32         d5,  d7

    vmull.u8        q10, d8,  d0
    vmlal.u8        q10, d4,  d2
    vmull.u8        q11, d9,  d0
    vmlal.u8        q11, d5,  d2

    vld2.8          {d8-d9},  [r3], r4

    vrshrn.u16      d16, q8,  #6

    vext.8          d10, d8,  d10,  #1
    vext.8          d11, d9,  d11,  #1

    vadd.i16        d18, d20, d21
    vadd.i16        d19, d22, d23

    vtrn.32         d8, d10
    vtrn.32         d9, d11

    vrshrn.u16      d18, q9,  #6

    subs            r5,  r5,  #2

    pld             [r3]
    pld             [r3, r4]

    vst1.\align     {d16[0]},   [r0,:\align], r2
    vst1.\align     {d16[st2]}, [r1,:\align], r2
    vst1.\align     {d18[0]},   [r0,:\align], r2
    vst1.\align     {d18[st2]}, [r1,:\align], r2
    bgt             1b

    vpop            {d8-d11}
    pop             {r4-r8, pc}

2:  // dx or dy are 0
    tst             r7,  r7
    add             ip,  ip,  r7
    vdup.8          d0,  r5
    ldr             r5,  [sp, #72]
    vdup.8          d1,  ip

    beq             4f

    vld1.64          {d4}, [r3], r4
    vld1.64          {d6}, [r3], r4

3:  // vertical interpolation loop

    vmull.u8        q8,  d4,  d0
    vmlal.u8        q8,  d6,  d1
    vmull.u8        q9,  d6,  d0
    vld1.64         {d4}, [r3], r4
    vmlal.u8        q9,  d4,  d1
    vld1.64         {d6}, [r3], r4

    vrshrn.u16      d16, q8,  #6 // uvuvuvuv
    vrshrn.u16      d17, q9,  #6 // uvuvuvuv
    subs            r5,  r5,  #2
    vuzp.8          d16, d17 // d16=uuuu|uuuu, d17=vvvv|vvvv

    pld             [r3]
    pld             [r3, r4]

    vst1.\align     {d16[0]},   [r0,:\align], r2
    vst1.\align     {d16[st2]}, [r0,:\align], r2
    vst1.\align     {d17[0]},   [r1,:\align], r2
    vst1.\align     {d17[st2]}, [r1,:\align], r2
    bgt             3b

    vpop            {d8-d11}
    pop             {r4-r8, pc}

4:  // dy is 0

    vld1.64         {d4-d5},  [r3], r4
    vld1.64         {d6-d7},  [r3], r4

    vext.8          d5,  d4,  d5,  #2
    vext.8          d7,  d6,  d7,  #2

5:  // horizontal interpolation loop

    vmull.u8        q8,  d4,  d0
    vmlal.u8        q8,  d5,  d1
    vmull.u8        q9,  d6,  d0
    vmlal.u8        q9,  d7,  d1

    subs            r5,  r5,  #2
    vld1.64         {d4-d5},  [r3], r4
    vld1.64         {d6-d7},  [r3], r4
    vext.8          d5,  d4,  d5,  #2
    vrshrn.u16      d16, q8,  #6
    vrshrn.u16      d17, q9,  #6
    vext.8          d7,  d6,  d7,  #2
    vuzp.8          d16, d17

    pld             [r3]
    pld             [r3, r4]

    vst1.\align     {d16[0]},   [r0,:\align], r2
    vst1.\align     {d16[st2]}, [r0,:\align], r2
    vst1.\align     {d17[0]},   [r1,:\align], r2
    vst1.\align     {d17[st2]}, [r1,:\align], r2
    bgt             5b

    vpop            {d8-d11}
    pop             {r4-r8, pc}
.endm

   CHROMA_MC 2, 16
   CHROMA_MC 4, 32

mc_chroma_w8:
    CHROMA_MC_START d4, d7, d8, d11
    vext.8          d5,  d4,  d5,  #1
    vext.8          d9,  d8,  d9,  #1
    vext.8          d7,  d6,  d7,  #1
    vext.8          d11, d10, d11,  #1

1:  // height loop, interpolate xy
    vmull.u8        q8,  d4,  d0
    vmlal.u8        q8,  d5,  d1
    vmlal.u8        q8,  d8,  d2
    vmlal.u8        q8,  d9,  d3

    vmull.u8        q9,  d6,  d0
    vmlal.u8        q9,  d7,  d1
    vmlal.u8        q9,  d10,  d2
    vmlal.u8        q9,  d11,  d3

    vld2.8          {d4-d7}, [r3], r4

    vext.8          d5,  d4,  d5,  #1
    vext.8          d7,  d6,  d7,  #1

    vmull.u8        q10, d8,   d0
    vmlal.u8        q10, d9,   d1
    vmlal.u8        q10, d4,   d2
    vmlal.u8        q10, d5,   d3

    vmull.u8        q11, d10,  d0
    vmlal.u8        q11, d11,  d1
    vmlal.u8        q11, d6,   d2
    vmlal.u8        q11, d7,   d3

    subs            r5,  r5,   #2
    vld2.8          {d8-d11}, [r3], r4

    vrshrn.u16      d16, q8,  #6
    vrshrn.u16      d17, q9,  #6
    vrshrn.u16      d18, q10, #6
    vext.8          d9,  d8,  d9,  #1
    vrshrn.u16      d19, q11, #6
    vext.8          d11, d10, d11,  #1

    pld             [r3]
    pld             [r3, r4]

    vst1.64         {d16}, [r0,:64], r2
    vst1.64         {d17}, [r1,:64], r2
    vst1.64         {d18}, [r0,:64], r2
    vst1.64         {d19}, [r1,:64], r2

    bgt             1b

    vpop            {d8-d11}
    pop             {r4-r8, pc}

2:  // dx or dy are 0
    tst             r7,  r7
    add             ip,  ip,  r7
    vdup.8          d0,  r5
    ldr             r5,  [sp, #72]
    vdup.8          d1,  ip

    beq             4f

    vld2.8          {d4-d5}, [r3], r4
    vld2.8          {d6-d7}, [r3], r4

3:  // vertical interpolation loop
    vmull.u8        q8,  d4,  d0 //U
    vmlal.u8        q8,  d6,  d1
    vmull.u8        q9,  d5,  d0 //V
    vmlal.u8        q9,  d7,  d1

    vld2.8          {d4-d5}, [r3], r4

    vmull.u8        q10, d6,  d0
    vmlal.u8        q10, d4,  d1
    vmull.u8        q11, d7,  d0
    vmlal.u8        q11, d5,  d1

    vld2.8          {d6-d7}, [r3], r4

    vrshrn.u16      d16, q8,  #6
    vrshrn.u16      d17, q9,  #6
    vrshrn.u16      d18, q10, #6
    vrshrn.u16      d19, q11, #6
    subs            r5,  r5,  #2

    pld             [r3]
    pld             [r3, r4]

    vst1.64         {d16}, [r0,:64], r2
    vst1.64         {d17}, [r1,:64], r2
    vst1.64         {d18}, [r0,:64], r2
    vst1.64         {d19}, [r1,:64], r2

    bgt             3b

    vpop            {d8-d11}
    pop             {r4-r8, pc}

4:  // dy is 0

    vld2.8          {d4-d7},  [r3], r4
    vld2.8          {d8-d11}, [r3], r4
    vext.8          d5,  d4,  d5,  #1
    vext.8          d7,  d6,  d7,  #1
    vext.8          d9,  d8,  d9,  #1
    vext.8          d11, d10, d11, #1

5:  // horizontal interpolation loop
    subs            r5,  r5,  #2
    vmull.u8        q8,  d4,  d0 //U
    vmlal.u8        q8,  d5,  d1
    vmull.u8        q9,  d6,  d0 //V
    vmlal.u8        q9,  d7,  d1

    vld2.8          {d4-d7}, [r3], r4

    vmull.u8        q10, d8,  d0
    vmlal.u8        q10, d9,  d1
    vmull.u8        q11, d10, d0
    vmlal.u8        q11, d11, d1

    vld2.8          {d8-d11}, [r3], r4

    vext.8          d5,  d4,  d5,  #1
    vrshrn.u16      d16, q8,  #6
    vext.8          d7,  d6,  d7,  #1
    vrshrn.u16      d17, q9,  #6
    vext.8          d9,  d8,  d9,  #1
    vrshrn.u16      d18, q10, #6
    vext.8          d11, d10, d11, #1
    vrshrn.u16      d19, q11, #6

    pld             [r3]
    pld             [r3, r4]

    vst1.64         {d16}, [r0,:64], r2
    vst1.64         {d17}, [r1,:64], r2
    vst1.64         {d18}, [r0,:64], r2
    vst1.64         {d19}, [r1,:64], r2
    bgt             5b

    vpop            {d8-d11}
    pop             {r4-r8, pc}

endfunc


// hpel_filter_v( uint8_t *dst, uint8_t *src, int16_t *buf, intptr_t stride, int width )
function hpel_filter_v_neon
    ldr             ip,  [sp]
    sub             r1,  r1,  r3,  lsl #1
    push            {lr}
    add             lr,  r1,  ip
    vmov.u8         d30, #5
    vmov.u8         d31, #20

filter_v_loop:
    subs            ip,  ip,  #16
    vld1.64         {d0-d1},   [r1,:128], r3
    vld1.64         {d2-d3},   [r1,:128], r3
    vld1.64         {d4-d5},   [r1,:128], r3
    vld1.64         {d6-d7},   [r1,:128], r3
    vld1.64         {d16-d17}, [r1,:128], r3
    vld1.64         {d18-d19}, [r1,:128], r3
    sub             r1,  lr,  ip

    vaddl.u8        q10, d0,  d18
    vmlsl.u8        q10, d2,  d30
    vmlal.u8        q10, d4,  d31
    vmlal.u8        q10, d6,  d31
    vmlsl.u8        q10, d16, d30

    vaddl.u8        q11, d1,  d19
    vmlsl.u8        q11, d3,  d30
    vmlal.u8        q11, d5,  d31
    vmlal.u8        q11, d7,  d31
    vmlsl.u8        q11, d17, d30

    vqrshrun.s16    d0,  q10, #5
    vst1.64         {d20-d21}, [r2,:128]!
    vqrshrun.s16    d1,  q11, #5
    vst1.64         {d22-d23}, [r2,:128]!
    vst1.64         {d0-d1},   [r0,:128]!
    bgt             filter_v_loop
    pop             {pc}
endfunc

// hpel_filter_c( uint8_t *dst, int16_t *buf, int width );
function hpel_filter_c_neon
    sub             r1,  #16
    vld1.64         {d0-d3}, [r1,:128]!

    // unrolled 2x: 4% faster
filter_c_loop:
    subs            r2,  r2,  #16
    vld1.64         {d4-d7}, [r1,:128]!
    vext.16         q8,  q0,  q1,  #6
    vext.16         q12, q1,  q2,  #3
    vadd.s16        q8,  q8,  q12
    vext.16         q9,  q0,  q1,  #7
    vext.16         q11, q1,  q2,  #2
    vadd.s16        q9,  q9,  q11
    vext.16         q10, q1,  q2,  #1
    vext.16         q11, q1,  q2,  #6
    vadd.s16        q10, q1,  q10
    vsub.s16        q8,  q8,  q9    // a-b
    vext.16         q15, q2,  q3,  #3
    vsub.s16        q9,  q9,  q10   // b-c

    vext.16         q12, q1,  q2,  #7
    vshr.s16        q8,  q8,  #2    // (a-b)/4
    vadd.s16        q11, q11, q15
    vext.16         q14, q2,  q3,  #2
    vsub.s16        q8,  q8,  q9    // (a-b)/4-b+c
    vadd.s16        q12, q12, q14
    vext.16         q13, q2,  q3,  #1

    vshr.s16        q8,  q8,  #2    // ((a-b)/4-b+c)/4
    vadd.s16        q13, q2,  q13
    vadd.s16        q8,  q8,  q10   // ((a-b)/4-b+c)/4+c = (a-5*b+20*c)/16
    vsub.s16        q11, q11, q12   // a-b
    vsub.s16        q12, q12, q13   // b-c
    vshr.s16        q11, q11, #2    // (a-b)/4
    vqrshrun.s16    d30, q8,  #6
    vsub.s16        q11, q11, q12   // (a-b)/4-b+c
    vshr.s16        q11, q11, #2    // ((a-b)/4-b+c)/4
    vld1.64         {d0-d3}, [r1,:128]!
    vadd.s16        q11, q11, q13   // ((a-b)/4-b+c)/4+c = (a-5*b+20*c)/16

    vext.16         q8,  q2,  q3,  #6
    vqrshrun.s16    d31, q11,  #6
    vext.16         q12, q3,  q0,  #3
    vadd.s16        q8,  q8,  q12
    vext.16         q9,  q2,  q3,  #7
    vst1.64         {d30-d31}, [r0,:128]!
    bxle            lr
    subs            r2,  r2,  #16

    vext.16         q11, q3,  q0,  #2
    vadd.s16        q9,  q9,  q11
    vext.16         q10, q3,  q0,  #1
    vext.16         q11, q3,  q0,  #6
    vadd.s16        q10, q3,  q10
    vsub.s16        q8,  q8,  q9    // a-b
    vext.16         q15, q0,  q1,  #3
    vsub.s16        q9,  q9,  q10   // b-c

    vext.16         q12, q3,  q0,  #7
    vshr.s16        q8,  q8,  #2    // (a-b)/4
    vadd.s16        q11, q11, q15
    vext.16         q14, q0,  q1,  #2
    vsub.s16        q8,  q8,  q9    // (a-b)/4-b+c
    vadd.s16        q12, q12, q14
    vext.16         q13, q0,  q1,  #1

    vshr.s16        q8,  q8,  #2    // ((a-b)/4-b+c)/4
    vadd.s16        q13, q0,  q13
    vadd.s16        q8,  q8,  q10   // ((a-b)/4-b+c)/4+c = (a-5*b+20*c)/16
    vsub.s16        q11, q11, q12   // a-b
    vsub.s16        q12, q12, q13   // b-c
    vshr.s16        q11, q11, #2    // (a-b)/4
    vqrshrun.s16    d30, q8,  #6
    vsub.s16        q11, q11, q12   // (a-b)/4-b+c
    vshr.s16        q11, q11, #2    // ((a-b)/4-b+c)/4
    vadd.s16        q11, q11, q13   // ((a-b)/4-b+c)/4+c = (a-5*b+20*c)/16

    vqrshrun.s16    d31, q11,  #6
    vst1.64         {d30-d31}, [r0,:128]!
    bgt             filter_c_loop
    bx              lr
endfunc

// hpel_filter_h( uint8_t *dst, uint8_t *src, int width );
function hpel_filter_h_neon
    sub             r1,  #16
    vmov.u8         d30, #5
    vld1.64         {d0-d3}, [r1,:128]!
    vmov.u8         d31, #20

    // unrolled 3x because it's 5% faster, due to mitigating
    // the high latency of multiplication and vqrshrun
filter_h_loop:
    subs            r2,  r2,  #16
    vld1.64         {d4-d5}, [r1,:128]!
    vext.8          q8,  q0,  q1,  #14
    vext.8          q12, q1,  q2,  #3
    vaddl.u8        q13, d16, d24
    vext.8          q9,  q0,  q1,  #15
    vaddl.u8        q14, d17, d25

    vext.8          q10, q1,  q2,  #1
    vmlal.u8        q13, d2,  d31
    vmlsl.u8        q13, d18, d30
    vext.8          q11, q1,  q2,  #2
    vmlal.u8        q13, d20, d31
    vmlsl.u8        q13, d22, d30

    vmlsl.u8        q14, d19, d30
    vmlal.u8        q14, d3,  d31
    vmlal.u8        q14, d21, d31
    vmlsl.u8        q14, d23, d30
    vqrshrun.s16    d6,  q13, #5

    vld1.64         {d0-d1}, [r1,:128]!
    vext.8          q8,  q1,  q2,  #14
    vext.8          q12, q2,  q0,  #3
    vaddl.u8        q13, d16, d24
    vqrshrun.s16    d7,  q14, #5
    vext.8          q9,  q1,  q2,  #15
    vaddl.u8        q14, d17, d25

    vst1.64         {d6-d7}, [r0,:128]!
    bxle            lr
    subs            r2,  r2,  #16

    vext.8          q10, q2,  q0,  #1
    vmlal.u8        q13, d4,  d31
    vmlsl.u8        q13, d18, d30
    vext.8          q11, q2,  q0,  #2
    vmlal.u8        q13, d20, d31
    vmlsl.u8        q13, d22, d30

    vmlsl.u8        q14, d19, d30
    vmlal.u8        q14, d5,  d31
    vmlal.u8        q14, d21, d31
    vmlsl.u8        q14, d23, d30
    vqrshrun.s16    d6,  q13, #5

    vld1.64         {d2-d3}, [r1,:128]!
    vext.8          q8,  q2,  q0,  #14
    vext.8          q12, q0,  q1,  #3
    vaddl.u8        q13, d16, d24
    vqrshrun.s16    d7,  q14, #5
    vext.8          q9,  q2,  q0,  #15
    vaddl.u8        q14, d17, d25

    vst1.64         {d6-d7}, [r0,:128]!
    bxle            lr
    subs            r2,  r2,  #16

    vext.8          q10, q0,  q1,  #1
    vmlal.u8        q13, d0,  d31
    vmlsl.u8        q13, d18, d30
    vext.8          q11, q0,  q1,  #2
    vmlal.u8        q13, d20, d31
    vmlsl.u8        q13, d22, d30

    vmlsl.u8        q14, d19, d30
    vmlal.u8        q14, d1,  d31
    vmlal.u8        q14, d21, d31
    vmlsl.u8        q14, d23, d30

    vqrshrun.s16    d6, q13, #5
    vqrshrun.s16    d7, q14, #5
    vst1.64         {d6-d7}, [r0,:128]!
    bgt             filter_h_loop
    bx              lr
endfunc


// frame_init_lowres_core( uint8_t *src0, uint8_t *dst0, uint8_t *dsth, uint8_t *dstv,
//                         uint8_t *dstc, intptr_t src_stride, intptr_t dst_stride, int width,
//                         int height )
function frame_init_lowres_core_neon
    push            {r4-r10,lr}
    vpush           {d8-d15}
    ldrd            r4,  r5,  [sp, #96]
    ldrd            r6,  r7,  [sp, #104]
    ldr             lr,  [sp, #112]
    sub             r10, r6,  r7            // dst_stride - width
    and             r10, r10, #~15

lowres_yloop:
    mov             ip,  r7                 // width
    mov             r6,  r0                 // src0
    add             r8,  r0,  r5            // src1 = src0 + src_stride
    add             r9,  r0,  r5,  lsl #1   // src2 = src1 + src_stride

    vld2.8          {d8, d10}, [r6,:128]!
    vld2.8          {d12,d14}, [r8,:128]!
    vld2.8          {d16,d18}, [r9,:128]!

lowres_xloop:
    subs            ip,  ip,  #16

    vld2.8          {d9, d11}, [r6,:128]!
    vld2.8          {d13,d15}, [r8,:128]!
    vrhadd.u8       q0,  q4,  q6
    vld2.8          {d17,d19}, [r9,:128]!
    vrhadd.u8       q5,  q5,  q7
    vld2.8          {d20,d22}, [r6,:128]!
    vrhadd.u8       q1,  q6,  q8
    vld2.8          {d24,d26}, [r8,:128]!
    vrhadd.u8       q7,  q7,  q9
    vext.8          q4,  q4,  q10, #1
    vrhadd.u8       q0,  q0,  q5
    vext.8          q6,  q6,  q12, #1
    vrhadd.u8       q1,  q1,  q7
    vld2.8          {d28,d30}, [r9,:128]!
    vrhadd.u8       q4,  q4,  q6
    vext.8          q8,  q8,  q14, #1
    vrhadd.u8       q6,  q6,  q8
    vst1.64         {d0-d1},   [r1,:128]!
    vrhadd.u8       q2,  q4,  q5
    vst1.64         {d2-d3},   [r3,:128]!
    vrhadd.u8       q3,  q6,  q7
    vst1.64         {d4-d5},   [r2,:128]!
    vst1.64         {d6-d7},   [r4,:128]!

    ble             lowres_xloop_end
    subs            ip,  ip,  #16

    vld2.8          {d21,d23}, [r6,:128]!
    vld2.8          {d25,d27}, [r8,:128]!
    vrhadd.u8       q0,  q10, q12
    vld2.8          {d29,d31}, [r9,:128]!
    vrhadd.u8       q11, q11, q13
    vld2.8          {d8, d10}, [r6,:128]!
    vrhadd.u8       q1,  q12, q14
    vld2.8          {d12,d14}, [r8,:128]!
    vrhadd.u8       q13, q13, q15
    vext.8          q10, q10, q4,  #1
    vrhadd.u8       q0,  q0,  q11
    vext.8          q12, q12, q6,  #1
    vrhadd.u8       q1,  q1,  q13
    vld2.8          {d16,d18}, [r9,:128]!
    vrhadd.u8       q10, q10, q12
    vext.8          q14, q14, q8,  #1
    vrhadd.u8       q12, q12, q14
    vst1.64         {d0-d1},   [r1,:128]!
    vrhadd.u8       q2,  q10, q11
    vst1.64         {d2-d3},   [r3,:128]!
    vrhadd.u8       q3,  q12, q13
    vst1.64         {d4-d5},   [r2,:128]!
    vst1.64         {d6-d7},   [r4,:128]!

    bgt             lowres_xloop

lowres_xloop_end:
    subs            lr,  lr,  #1
    add             r0,  r0,  r5,  lsl #1
    add             r1,  r1,  r10
    add             r2,  r2,  r10
    add             r3,  r3,  r10
    add             r4,  r4,  r10
    bgt             lowres_yloop

    vpop            {d8-d15}
    pop             {r4-r10,pc}
endfunc

function load_deinterleave_chroma_fdec_neon
    mov             ip,  #FDEC_STRIDE/2
1:
    vld2.8          {d0-d1}, [r1,:128], r2
    subs            r3,  r3,  #1
    pld             [r1]
    vst1.8          {d0},    [r0,:64], ip
    vst1.8          {d1},    [r0,:64], ip
    bgt             1b

    bx              lr
endfunc

function load_deinterleave_chroma_fenc_neon
    mov             ip,  #FENC_STRIDE/2
1:
    vld2.8          {d0-d1}, [r1,:128], r2
    subs            r3,  r3,  #1
    pld             [r1]
    vst1.8          {d0},    [r0,:64], ip
    vst1.8          {d1},    [r0,:64], ip
    bgt             1b

    bx              lr
endfunc

function plane_copy_core_neon
    push            {r4,lr}
    ldr             r4,  [sp, #8]
    ldr             lr,  [sp, #12]
    add             r12, r4,  #15
    bic             r4,  r12, #15
    sub             r1,  r1,  r4
    sub             r3,  r3,  r4
1:
    mov             r12, r4
16:
    tst             r12, #16
    beq             32f
    subs            r12, r12, #16
    vld1.8          {q0}, [r2]!
    vst1.8          {q0}, [r0]!
    beq             0f
32:
    subs            r12, r12, #32
    vld1.8          {q0, q1}, [r2]!
    vst1.8          {q0, q1}, [r0]!
    bgt             32b
0:
    subs            lr,  lr,  #1
    add             r2,  r2,  r3
    add             r0,  r0,  r1
    bgt             1b

    pop             {r4,pc}
endfunc

function plane_copy_deinterleave_neon
    push            {r4-r7, lr}
    ldrd            r6, r7, [sp, #28]
    ldrd            r4, r5, [sp, #20]
    add             lr,  r6,  #15
    bic             lr,  lr,  #15
    sub             r1,  r1,  lr
    sub             r3,  r3,  lr
    sub             r5,  r5,  lr, lsl #1
block:
    vld2.8          {d0-d3}, [r4,:128]!
    subs            lr,  lr,  #16
    vst1.8          {q0},    [r0]!
    vst1.8          {q1},    [r2]!
    bgt             block

    add             r4,  r4,  r5
    subs            r7,  r7,  #1
    add             r0,  r0,  r1
    add             r2,  r2,  r3
    mov             lr,  r6
    bgt             block

    pop             {r4-r7, pc}
endfunc

function plane_copy_deinterleave_rgb_neon
    push            {r4-r8, r10, r11, lr}
    ldrd            r4,  r5,  [sp, #32]
    ldrd            r6,  r7,  [sp, #40]
    ldr             r8,  [sp, #48]
    ldrd            r10, r11, [sp, #52]
    add             lr,  r10, #7
    subs            r8,  r8,  #3
    bic             lr,  lr,  #7
    sub             r7,  r7,  lr, lsl #1
    sub             r1,  r1,  lr
    sub             r3,  r3,  lr
    sub             r5,  r5,  lr
    subne           r7,  r7,  lr, lsl #1
    subeq           r7,  r7,  lr
    bne             block4
block3:
    vld3.8          {d0,d1,d2}, [r6]!
    subs            lr,  lr,  #8
    vst1.8          {d0},    [r0]!
    vst1.8          {d1},    [r2]!
    vst1.8          {d2},    [r4]!
    bgt             block3

    subs            r11, r11, #1
    add             r0,  r0,  r1
    add             r2,  r2,  r3
    add             r4,  r4,  r5
    add             r6,  r6,  r7
    mov             lr,  r10
    bgt             block3

    pop             {r4-r8, r10, r11, pc}
block4:
    vld4.8          {d0,d1,d2,d3}, [r6]!
    subs            lr,  lr,  #8
    vst1.8          {d0},    [r0]!
    vst1.8          {d1},    [r2]!
    vst1.8          {d2},    [r4]!
    bgt             block4

    subs            r11, r11, #1
    add             r0,  r0,  r1
    add             r2,  r2,  r3
    add             r4,  r4,  r5
    add             r6,  r6,  r7
    mov             lr,  r10
    bgt             block4

    pop             {r4-r8, r10, r11, pc}
endfunc

function plane_copy_interleave_core_neon
    push            {r4-r7, lr}
    ldrd            r6, r7, [sp, #28]
    ldrd            r4, r5, [sp, #20]
    add             lr,  r6,  #15
    bic             lr,  lr,  #15
    sub             r1,  r1,  lr, lsl #1
    sub             r3,  r3,  lr
    sub             r5,  r5,  lr
blocki:
    vld1.8          {q0}, [r2]!
    vld1.8          {q1}, [r4]!
    subs            lr,  lr,  #16
    vst2.8          {d0,d2}, [r0]!
    vst2.8          {d1,d3}, [r0]!
    bgt             blocki

    subs            r7,  r7,  #1
    add             r0,  r0,  r1
    add             r2,  r2,  r3
    add             r4,  r4,  r5
    mov             lr,  r6
    bgt             blocki

    pop             {r4-r7, pc}
endfunc

function plane_copy_swap_core_neon
    push            {r4-r5, lr}
    ldrd            r4, r5, [sp, #12]
    add             lr,  r4,  #15
    bic             lr,  lr,  #15
    sub             r1,  r1,  lr, lsl #1
    sub             r3,  r3,  lr, lsl #1
1:
    vld1.8          {q0, q1}, [r2]!
    subs            lr,  lr,  #16
    vrev16.8        q0,  q0
    vrev16.8        q1,  q1
    vst1.8          {q0, q1}, [r0]!
    bgt             1b

    subs            r5,  r5,  #1
    add             r0,  r0,  r1
    add             r2,  r2,  r3
    mov             lr,  r4
    bgt             1b

    pop             {r4-r5, pc}
endfunc

function store_interleave_chroma_neon
    push            {lr}
    ldr             lr,  [sp, #4]
    mov             ip,  #FDEC_STRIDE
1:
    vld1.8          {d0}, [r2], ip
    vld1.8          {d1}, [r3], ip
    subs            lr,  lr,  #1
    vst2.8          {d0,d1}, [r0,:128], r1
    bgt             1b

    pop             {pc}
endfunc

.macro integral4h p1, p2
    vext.8          d1,  \p1, \p2,  #1
    vext.8          d2,  \p1, \p2,  #2
    vext.8          d3,  \p1, \p2,  #3
    vaddl.u8        q0,  \p1, d1
    vaddl.u8        q1,  d2,  d3
    vadd.u16        q0,  q0,  q1
    vadd.u16        q0,  q0,  q2
.endm

function integral_init4h_neon
    sub             r3,  r0,  r2, lsl #1
    vld1.8          {d6, d7}, [r1, :128]!
1:
    subs            r2,  r2,  #16
    vld1.16         {q2},  [r3, :128]!
    integral4h      d6, d7
    vld1.8          {d6},  [r1, :64]!
    vld1.16         {q2},  [r3, :128]!
    vst1.16         {q0},  [r0, :128]!
    integral4h      d7, d6
    vld1.8          {d7},  [r1, :64]!
    vst1.16         {q0},  [r0, :128]!
    bgt             1b
    bx              lr
endfunc

.macro integral8h p1, p2, s
    vext.8          d1,  \p1,  \p2,  #1
    vext.8          d2,  \p1,  \p2,  #2
    vext.8          d3,  \p1,  \p2,  #3
    vext.8          d4,  \p1,  \p2,  #4
    vext.8          d5,  \p1,  \p2,  #5
    vext.8          d6,  \p1,  \p2,  #6
    vext.8          d7,  \p1,  \p2,  #7
    vaddl.u8        q0,  \p1,  d1
    vaddl.u8        q1,  d2,   d3
    vaddl.u8        q2,  d4,   d5
    vaddl.u8        q3,  d6,   d7
    vadd.u16        q0,  q0,   q1
    vadd.u16        q2,  q2,   q3
    vadd.u16        q0,  q0,   q2
    vadd.u16        q0,  q0,   \s
.endm

function integral_init8h_neon
    sub             r3,  r0,  r2, lsl #1
    vld1.8          {d16, d17}, [r1, :128]!
1:
    subs            r2,  r2,  #16
    vld1.16         {q9},  [r3, :128]!
    integral8h      d16, d17, q9
    vld1.8          {d16}, [r1, :64]!
    vld1.16         {q9},  [r3, :128]!
    vst1.16         {q0},  [r0, :128]!
    integral8h      d17, d16, q9
    vld1.8          {d17}, [r1, :64]!
    vst1.16         {q0},  [r0, :128]!
    bgt             1b
    bx              lr
endfunc

function integral_init4v_neon
    push            {r4-r5}
    mov             r3,   r0
    add             r4,   r0,   r2,  lsl #3
    add             r5,   r0,   r2,  lsl #4
    sub             r2,   r2,   #8
    vld1.16         {q11, q12}, [r3]!
    vld1.16         {q8,  q9},  [r5]!
    vld1.16         {q13}, [r3]!
    vld1.16         {q10}, [r5]!
1:
    subs            r2,   r2,   #16
    vld1.16         {q14, q15}, [r4]!
    vext.8          q0,   q11,  q12, #8
    vext.8          q1,   q12,  q13, #8
    vext.8          q2,   q8,   q9,  #8
    vext.8          q3,   q9,   q10, #8
    vsub.u16        q14,  q14,  q11
    vsub.u16        q15,  q15,  q12
    vadd.u16        q0,   q0,   q11
    vadd.u16        q1,   q1,   q12
    vadd.u16        q2,   q2,   q8
    vadd.u16        q3,   q3,   q9
    vst1.16         {q14},  [r1]!
    vst1.16         {q15},  [r1]!
    vmov            q11,  q13
    vmov            q8,   q10
    vsub.u16        q0,   q2,   q0
    vsub.u16        q1,   q3,   q1
    vld1.16         {q12, q13}, [r3]!
    vld1.16         {q9,  q10}, [r5]!
    vst1.16         {q0}, [r0]!
    vst1.16         {q1}, [r0]!
    bgt             1b
2:
    pop             {r4-r5}
    bx              lr
endfunc

function integral_init8v_neon
    add             r2,  r0,  r1,  lsl #4
    sub             r1,  r1,  #8
    ands            r3,  r1,  #16 - 1
    beq             1f
    subs            r1,  r1,  #8
    vld1.16         {q0}, [r0]
    vld1.16         {q2}, [r2]!
    vsub.u16        q8,  q2,  q0
    vst1.16         {q8}, [r0]!
    ble             2f
1:
    subs            r1,  r1,  #16
    vld1.16         {q0, q1}, [r0]
    vld1.16         {q2, q3}, [r2]!
    vsub.u16        q8,  q2,  q0
    vsub.u16        q9,  q3,  q1
    vst1.16         {q8},  [r0]!
    vst1.16         {q9},  [r0]!
    bgt             1b
2:
    bx              lr
endfunc

function mbtree_propagate_cost_neon
    push            {r4-r5,lr}
    ldrd            r4, r5, [sp, #12]
    ldr             lr, [sp, #20]
    vld1.32         {d6[], d7[]},  [r5]
8:
    subs            lr,  lr,  #8
    vld1.16         {q8},  [r1]!
    vld1.16         {q9},  [r2]!
    vld1.16         {q10}, [r3]!
    vld1.16         {q11}, [r4]!
    vbic.u16        q10, #0xc000
    vmin.u16        q10, q9,  q10
    vmull.u16       q12, d18, d22           @ propagate_intra
    vmull.u16       q13, d19, d23           @ propagate_intra
    vsubl.u16       q14, d18, d20           @ propagate_num
    vsubl.u16       q15, d19, d21           @ propagate_num
    vmovl.u16       q10, d18                @ propagate_denom
    vmovl.u16       q11, d19                @ propagate_denom
    vmovl.u16       q9,  d17
    vmovl.u16       q8,  d16
    vcvt.f32.s32    q12, q12
    vcvt.f32.s32    q13, q13
    vcvt.f32.s32    q14, q14
    vcvt.f32.s32    q15, q15
    vcvt.f32.s32    q10, q10
    vcvt.f32.s32    q11, q11
    vrecpe.f32      q0,  q10
    vrecpe.f32      q1,  q11
    vcvt.f32.s32    q8,  q8
    vcvt.f32.s32    q9,  q9
    vrecps.f32      q10, q0,  q10
    vrecps.f32      q11, q1,  q11
    vmla.f32        q8,  q12, q3            @ propagate_amount
    vmla.f32        q9,  q13, q3            @ propagate_amount
    vmul.f32        q0,  q0,  q10
    vmul.f32        q1,  q1,  q11
    vmul.f32        q8,  q8,  q14
    vmul.f32        q9,  q9,  q15
    vmul.f32        q0,  q8,  q0
    vmul.f32        q1,  q9,  q1
    vcvt.s32.f32    q0,  q0
    vcvt.s32.f32    q1,  q1
    vqmovn.s32      d0,  q0
    vqmovn.s32      d1,  q1
    vst1.16         {q0},  [r0]!
    bgt             8b
    pop             {r4-r5,pc}
endfunc

function mbtree_propagate_list_internal_neon
    vld1.16         {d4[]}, [sp]            @ bipred_weight
    movrel          r12, pw_0to15
    vmov.u16        q10, #0xc000
    vld1.16         {q0},  [r12, :128]      @h->mb.i_mb_x,h->mb.i_mb_y
    ldrh            r12,  [sp, #4]
    vmov.u32        q11, #4
    vmov.u8         q3,  #32
    vdup.u16        q8,  r12                @ mb_y
    vzip.u16        q0,  q8
    ldr             r12, [sp, #8]
8:
    subs            r12, r12,  #8
    vld1.16         {q14},  [r1, :128]!      @ propagate_amount
    vld1.16         {q15},  [r2]!            @ lowres_cost
    vld1.16         {q8, q9},  [r0]!
    vand            q15, q15, q10
    vceq.u16        q1,  q15, q10
    vmull.u16       q12, d28, d4
    vmull.u16       q13, d29, d4
    vrshrn.u32      d30, q12, #6
    vrshrn.u32      d31, q13, #6
    vbsl            q1,  q15, q14           @ if( lists_used == 3 )
    @ propagate_amount = (propagate_amount * bipred_weight + 32) >> 6
    vshr.s16        q12, q8,  #5
    vshr.s16        q13, q9,  #5
    vuzp.16         q8,  q9                 @ x & 31, y & 31
    vadd.s16        q12, q12, q0
    vadd.s16        q0,  q0,  q11
    vmovn.i16       d16, q8
    vmovn.i16       d17, q9
    vadd.s16        q13, q13, q0
    vbic.i16        q8,  #128+64+32
    vadd.s16        q0,  q0,  q11
    vbic.i16        q8,  #(128+64+32)<<8
    vst1.16         {q12, q13},  [r3, :128]!
    vsub.i8         q9,  q3,  q8
    vmull.u8        q12, d17, d16           @ idx3weight = y*x
    vmull.u8        q14, d19, d16           @ idx1weight = (32-y)*x
    vmull.u8        q15, d19, d18           @ idx0weight = (32-y)*(32-x)
    vmull.u8        q13, d17, d18           @ idx2weight = y*(32-x)
    vmull.u16       q9,  d28, d2            @ idx1weight
    vmull.u16       q8,  d29, d3
    vmull.u16       q14, d30, d2            @ idx0weight
    vmull.u16       q15, d31, d3
    vrshrn.u32      d18, q9,  #10           @ idx1weight
    vrshrn.u32      d19, q8,  #10
    vrshrn.u32      d16, q14, #10           @ idx0weight
    vrshrn.u32      d17, q15, #10
    vmull.u16       q14, d24, d2            @ idx3weight
    vmull.u16       q15, d25, d3
    vzip.16         q8,  q9
    vmull.u16       q12, d26, d2            @ idx2weight
    vmull.u16       q13, d27, d3
    vst1.16         {q8, q9},   [r3, :128]!
    vrshrn.u32      d19, q15, #10           @ idx3weight
    vrshrn.u32      d18, q14, #10
    vrshrn.u32      d16, q12, #10           @ idx2weight
    vrshrn.u32      d17, q13, #10
    vzip.16         q8,  q9
    vst1.16         {q8, q9},   [r3, :128]!
    bge             8b
    bx              lr
endfunc

@ void mbtree_fix8_pack( int16_t *dst, float *src, int count )
function mbtree_fix8_pack_neon, export=1
    subs            r3,  r2,  #8
    blt             2f
1:
    subs            r3,  r3,  #8
    vld1.32         {q0,q1}, [r1,:128]!
    vcvt.s32.f32    q0,  q0,  #8
    vcvt.s32.f32    q1,  q1,  #8
    vqmovn.s32      d4,  q0
    vqmovn.s32      d5,  q1
    vrev16.8        q3,  q2
    vst1.16         {q3}, [r0,:128]!
    bge             1b
2:
    adds            r3,  r3,  #8
    bxeq            lr
3:
    subs            r3,  r3,  #1
    vld1.32         {d0[0]}, [r1]!
    vcvt.s32.f32    s0,  s0,  #8
    vrev16.8        d0,  d0
    vst1.16         {d0[0]}, [r0]!
    bgt             3b

    bx              lr
endfunc

@ void mbtree_fix8_unpack( float *dst, int16_t *src, int count )
function mbtree_fix8_unpack_neon, export=1
    subs            r3,  r2,  #8
    blt             2f
1:
    subs            r3,  r3,  #8
    vld1.16         {q0}, [r1,:128]!
    vrev16.8        q1,  q0
    vmovl.s16       q0,  d2
    vmovl.s16       q1,  d3
    vcvt.f32.s32    q0,  q0,  #8
    vcvt.f32.s32    q1,  q1,  #8
    vst1.32         {q0,q1}, [r0,:128]!
    bge             1b
2:
    adds            r3,  r3,  #8
    bxeq            lr
3:
    subs            r3,  r3,  #1
    vld1.16         {d0[0]}, [r1]!
    vrev16.8        d0,  d0
    vmovl.s16       q0,  d0
    vcvt.f32.s32    d0,  d0,  #8
    vst1.32         {d0[0]}, [r0]!
    bgt             3b

    bx              lr
endfunc
