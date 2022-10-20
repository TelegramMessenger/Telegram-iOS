/*****************************************************************************
 * predict.S: arm intra prediction
 *****************************************************************************
 * Copyright (C) 2009-2022 x264 project
 *
 * Authors: David Conrad <lessen42@gmail.com>
 *          Mans Rullgard <mans@mansr.com>
 *          Martin Storsjo <martin@martin.st>
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

const p16weight, align=4
.short 1,2,3,4,5,6,7,8
endconst

.text

.macro ldcol.8  rd,  rs,  rt,  n=8,  hi=0
.if \n == 8 || \hi == 0
    vld1.8          {\rd[0]}, [\rs], \rt
    vld1.8          {\rd[1]}, [\rs], \rt
    vld1.8          {\rd[2]}, [\rs], \rt
    vld1.8          {\rd[3]}, [\rs], \rt
.endif
.if \n == 8 || \hi == 1
    vld1.8          {\rd[4]}, [\rs], \rt
    vld1.8          {\rd[5]}, [\rs], \rt
    vld1.8          {\rd[6]}, [\rs], \rt
    vld1.8          {\rd[7]}, [\rs], \rt
.endif
.endm

.macro ldcol.16  rd1,  rd2,  rs,  rt,  ru
    add             \ru, \rs, \rt, lsl #3
    vld1.8          {\rd1[0]}, [\rs], \rt
    vld1.8          {\rd2[0]}, [\ru], \rt
    vld1.8          {\rd1[1]}, [\rs], \rt
    vld1.8          {\rd2[1]}, [\ru], \rt
    vld1.8          {\rd1[2]}, [\rs], \rt
    vld1.8          {\rd2[2]}, [\ru], \rt
    vld1.8          {\rd1[3]}, [\rs], \rt
    vld1.8          {\rd2[3]}, [\ru], \rt
    vld1.8          {\rd1[4]}, [\rs], \rt
    vld1.8          {\rd2[4]}, [\ru], \rt
    vld1.8          {\rd1[5]}, [\rs], \rt
    vld1.8          {\rd2[5]}, [\ru], \rt
    vld1.8          {\rd1[6]}, [\rs], \rt
    vld1.8          {\rd2[6]}, [\ru], \rt
    vld1.8          {\rd1[7]}, [\rs], \rt
    vld1.8          {\rd2[7]}, [\ru], \rt
.endm

.macro add16x8  dq,  dl,  dh,  rl,  rh
    vaddl.u8        \dq, \rl, \rh
    vadd.u16        \dl, \dl, \dh
    vpadd.u16       \dl, \dl, \dl
    vpadd.u16       \dl, \dl, \dl
.endm


// because gcc doesn't believe in using the free shift in add
function predict_4x4_h_armv6
    ldrb    r1, [r0, #0*FDEC_STRIDE-1]
    ldrb    r2, [r0, #1*FDEC_STRIDE-1]
    ldrb    r3, [r0, #2*FDEC_STRIDE-1]
    ldrb    ip, [r0, #3*FDEC_STRIDE-1]
    add     r1, r1, r1, lsl #8
    add     r2, r2, r2, lsl #8
    add     r3, r3, r3, lsl #8
    add     ip, ip, ip, lsl #8
    add     r1, r1, r1, lsl #16
    str     r1, [r0, #0*FDEC_STRIDE]
    add     r2, r2, r2, lsl #16
    str     r2, [r0, #1*FDEC_STRIDE]
    add     r3, r3, r3, lsl #16
    str     r3, [r0, #2*FDEC_STRIDE]
    add     ip, ip, ip, lsl #16
    str     ip, [r0, #3*FDEC_STRIDE]
    bx      lr
endfunc

function predict_4x4_v_armv6
    ldr     r1,  [r0, #0 - 1 * FDEC_STRIDE]
    str     r1,  [r0, #0 + 0 * FDEC_STRIDE]
    str     r1,  [r0, #0 + 1 * FDEC_STRIDE]
    str     r1,  [r0, #0 + 2 * FDEC_STRIDE]
    str     r1,  [r0, #0 + 3 * FDEC_STRIDE]
    bx      lr
endfunc

function predict_4x4_dc_armv6
    mov     ip, #0
    ldr     r1, [r0, #-FDEC_STRIDE]
    ldrb    r2, [r0, #0*FDEC_STRIDE-1]
    ldrb    r3, [r0, #1*FDEC_STRIDE-1]
    usad8   r1, r1, ip
    add     r2, r2, #4
    ldrb    ip, [r0, #2*FDEC_STRIDE-1]
    add     r2, r2, r3
    ldrb    r3, [r0, #3*FDEC_STRIDE-1]
    add     r2, r2, ip
    add     r2, r2, r3
    add     r1, r1, r2
    lsr     r1, r1, #3
    add     r1, r1, r1, lsl #8
    add     r1, r1, r1, lsl #16
    str     r1, [r0, #0*FDEC_STRIDE]
    str     r1, [r0, #1*FDEC_STRIDE]
    str     r1, [r0, #2*FDEC_STRIDE]
    str     r1, [r0, #3*FDEC_STRIDE]
    bx      lr
endfunc

function predict_4x4_dc_top_neon
    mov         r12, #FDEC_STRIDE
    sub         r1, r0, #FDEC_STRIDE
    vld1.32     d1[], [r1,:32]
    vpaddl.u8   d1, d1
    vpadd.u16   d1, d1, d1
    vrshr.u16   d1, d1, #2
    vdup.8      d1, d1[0]
    vst1.32     d1[0], [r0,:32], r12
    vst1.32     d1[0], [r0,:32], r12
    vst1.32     d1[0], [r0,:32], r12
    vst1.32     d1[0], [r0,:32], r12
    bx          lr
endfunc

// return a1 = (a1+2*b1+c1+2)>>2  a2 = (a2+2*b2+c2+2)>>2
.macro PRED4x4_LOWPASS a1 b1 c1 a2 b2 c2 pb_1
    uhadd8  \a1, \a1, \c1
    uhadd8  \a2, \a2, \c2
    uhadd8  \c1, \a1, \b1
    uhadd8  \c2, \a2, \b2
    eor     \a1, \a1, \b1
    eor     \a2, \a2, \b2
    and     \a1, \a1, \pb_1
    and     \a2, \a2, \pb_1
    uadd8   \a1, \a1, \c1
    uadd8   \a2, \a2, \c2
.endm

function predict_4x4_ddr_armv6
    ldr     r1, [r0, # -FDEC_STRIDE]
    ldrb    r2, [r0, # -FDEC_STRIDE-1]
    ldrb    r3, [r0, #0*FDEC_STRIDE-1]
    push    {r4-r6,lr}
    add     r2, r2, r1, lsl #8
    ldrb    r4, [r0, #1*FDEC_STRIDE-1]
    add     r3, r3, r2, lsl #8
    ldrb    r5, [r0, #2*FDEC_STRIDE-1]
    ldrb    r6, [r0, #3*FDEC_STRIDE-1]
    add     r4, r4, r3, lsl #8
    add     r5, r5, r4, lsl #8
    add     r6, r6, r5, lsl #8
    ldr     ip, =0x01010101
    PRED4x4_LOWPASS r1, r2, r3, r4, r5, r6, ip
    str     r1, [r0, #0*FDEC_STRIDE]
    lsl     r2, r1, #8
    lsl     r3, r1, #16
    lsl     r4, r4, #8
    lsl     r5, r1, #24
    add     r2, r2, r4, lsr #24
    str     r2, [r0, #1*FDEC_STRIDE]
    add     r3, r3, r4, lsr #16
    str     r3, [r0, #2*FDEC_STRIDE]
    add     r5, r5, r4, lsr #8
    str     r5, [r0, #3*FDEC_STRIDE]
    pop     {r4-r6,pc}
endfunc

function predict_4x4_ddl_neon
    sub         r0, #FDEC_STRIDE
    mov         ip, #FDEC_STRIDE
    vld1.64     {d0}, [r0], ip
    vdup.8      d3, d0[7]
    vext.8      d1, d0, d0, #1
    vext.8      d2, d0, d3, #2
    vhadd.u8    d0, d0, d2
    vrhadd.u8   d0, d0, d1
    vst1.32     {d0[0]}, [r0,:32], ip
    vext.8      d1, d0, d0, #1
    vext.8      d2, d0, d0, #2
    vst1.32     {d1[0]}, [r0,:32], ip
    vext.8      d3, d0, d0, #3
    vst1.32     {d2[0]}, [r0,:32], ip
    vst1.32     {d3[0]}, [r0,:32], ip
    bx          lr
endfunc

function predict_8x8_dc_neon
    mov     ip, #0
    ldrd    r2, r3, [r1, #8]
    push    {r4-r5,lr}
    ldrd    r4, r5, [r1, #16]
    lsl     r3, r3, #8
    ldrb    lr, [r1, #7]
    usad8   r2, r2, ip
    usad8   r3, r3, ip
    usada8  r2, r4, ip, r2
    add     lr, lr, #8
    usada8  r3, r5, ip, r3
    add     r2, r2, lr
    mov     ip, #FDEC_STRIDE
    add     r2, r2, r3
    lsr     r2, r2, #4

    vdup.8   d0, r2
.rept 8
    vst1.64 {d0}, [r0,:64], ip
.endr
    pop    {r4-r5,pc}
endfunc

function predict_8x8_h_neon
    add         r1, r1, #7
    mov         ip, #FDEC_STRIDE
    vld1.64     {d16}, [r1]
    vdup.8      d0, d16[7]
    vdup.8      d1, d16[6]
    vst1.64     {d0}, [r0,:64], ip
    vdup.8      d2, d16[5]
    vst1.64     {d1}, [r0,:64], ip
    vdup.8      d3, d16[4]
    vst1.64     {d2}, [r0,:64], ip
    vdup.8      d4, d16[3]
    vst1.64     {d3}, [r0,:64], ip
    vdup.8      d5, d16[2]
    vst1.64     {d4}, [r0,:64], ip
    vdup.8      d6, d16[1]
    vst1.64     {d5}, [r0,:64], ip
    vdup.8      d7, d16[0]
    vst1.64     {d6}, [r0,:64], ip
    vst1.64     {d7}, [r0,:64], ip
    bx          lr
endfunc

function predict_8x8_v_neon
    add         r1, r1, #16
    mov         r12, #FDEC_STRIDE
    vld1.8      {d0}, [r1,:64]
.rept 8
    vst1.8      {d0}, [r0,:64], r12
.endr
    bx          lr
endfunc

function predict_8x8_ddl_neon
    add         r1, #16
    vld1.8      {d0, d1}, [r1,:128]
    vmov.i8     q3, #0
    vrev64.8    d2, d1
    vext.8      q8, q3, q0, #15
    vext.8      q2, q0, q1, #1
    vhadd.u8    q8, q2
    mov         r12, #FDEC_STRIDE
    vrhadd.u8   q0, q8
    vext.8      d2, d0, d1, #1
    vext.8      d3, d0, d1, #2
    vst1.8      d2, [r0,:64], r12
    vext.8      d2, d0, d1, #3
    vst1.8      d3, [r0,:64], r12
    vext.8      d3, d0, d1, #4
    vst1.8      d2, [r0,:64], r12
    vext.8      d2, d0, d1, #5
    vst1.8      d3, [r0,:64], r12
    vext.8      d3, d0, d1, #6
    vst1.8      d2, [r0,:64], r12
    vext.8      d2, d0, d1, #7
    vst1.8      d3, [r0,:64], r12
    vst1.8      d2, [r0,:64], r12
    vst1.8      d1, [r0,:64], r12
    bx          lr
endfunc

function predict_8x8_ddr_neon
    vld1.8      {d0-d3}, [r1,:128]
    vext.8      q2, q0, q1, #7
    vext.8      q3, q0, q1, #9

    vhadd.u8    q2, q2, q3
    vrhadd.u8   d0, d1, d4
    vrhadd.u8   d1, d2, d5

    add         r0, #7*FDEC_STRIDE
    mov         r12, #-1*FDEC_STRIDE

    vext.8      d2, d0, d1, #1
    vst1.8      {d0}, [r0,:64], r12
    vext.8      d4, d0, d1, #2
    vst1.8      {d2}, [r0,:64], r12
    vext.8      d5, d0, d1, #3
    vst1.8      {d4}, [r0,:64], r12
    vext.8      d4, d0, d1, #4
    vst1.8      {d5}, [r0,:64], r12
    vext.8      d5, d0, d1, #5
    vst1.8      {d4}, [r0,:64], r12
    vext.8      d4, d0, d1, #6
    vst1.8      {d5}, [r0,:64], r12
    vext.8      d5, d0, d1, #7
    vst1.8      {d4}, [r0,:64], r12
    vst1.8      {d5}, [r0,:64], r12
    bx          lr
endfunc

function predict_8x8_vl_neon
    add         r1, #16
    mov         r12, #FDEC_STRIDE

    vld1.8      {d0, d1}, [r1,:128]
    vext.8      q1, q1, q0, #15
    vext.8      q2, q0, q2, #1

    vrhadd.u8   q3, q0, q2

    vhadd.u8    q1, q1, q2
    vrhadd.u8   q0, q0, q1

    vext.8      d2, d0, d1, #1
    vst1.8      {d6}, [r0,:64], r12
    vext.8      d3, d6, d7, #1
    vst1.8      {d2}, [r0,:64], r12
    vext.8      d2, d0, d1, #2
    vst1.8      {d3}, [r0,:64], r12
    vext.8      d3, d6, d7, #2
    vst1.8      {d2}, [r0,:64], r12
    vext.8      d2, d0, d1, #3
    vst1.8      {d3}, [r0,:64], r12
    vext.8      d3, d6, d7, #3
    vst1.8      {d2}, [r0,:64], r12
    vext.8      d2, d0, d1, #4
    vst1.8      {d3}, [r0,:64], r12
    vst1.8      {d2}, [r0,:64], r12
    bx          lr
endfunc

function predict_8x8_vr_neon
    add         r1, #8
    mov         r12, #FDEC_STRIDE
    vld1.8      {d4,d5}, [r1,:64]

    vext.8      q1, q2, q2, #14
    vext.8      q0, q2, q2, #15

    vhadd.u8    q3, q2, q1
    vrhadd.u8   q2, q2, q0
    vrhadd.u8   q0, q0, q3

    vmov        d2, d0

    vst1.8      {d5}, [r0,:64], r12
    vuzp.8      d2, d0
    vst1.8      {d1}, [r0,:64], r12
    vext.8      d6, d0, d5, #7
    vext.8      d3, d2, d1, #7
    vst1.8      {d6}, [r0,:64], r12
    vst1.8      {d3}, [r0,:64], r12
    vext.8      d6, d0, d5, #6
    vext.8      d3, d2, d1, #6
    vst1.8      {d6}, [r0,:64], r12
    vst1.8      {d3}, [r0,:64], r12
    vext.8      d6, d0, d5, #5
    vext.8      d3, d2, d1, #5
    vst1.8      {d6}, [r0,:64], r12
    vst1.8      {d3}, [r0,:64], r12
    bx          lr
endfunc

function predict_8x8_hd_neon
    mov         r12, #FDEC_STRIDE
    add         r1, #7

    vld1.8      {d2,d3}, [r1]
    vext.8      q3, q1, q1, #1
    vext.8      q2, q1, q1, #2

    vrhadd.u8   q8, q1, q3

    vhadd.u8    q1, q2
    vrhadd.u8   q0, q1, q3

    vzip.8      d16, d0

    vext.8      d2, d0, d1, #6
    vext.8      d3, d0, d1, #4
    vst1.8      {d2}, [r0,:64], r12
    vext.8      d2, d0, d1, #2
    vst1.8      {d3}, [r0,:64], r12
    vst1.8      {d2}, [r0,:64], r12
    vext.8      d2, d16, d0, #6
    vst1.8      {d0}, [r0,:64], r12
    vext.8      d3, d16, d0, #4
    vst1.8      {d2}, [r0,:64], r12
    vext.8      d2, d16, d0, #2
    vst1.8      {d3}, [r0,:64], r12
    vst1.8      {d2}, [r0,:64], r12
    vst1.8      {d16}, [r0,:64], r12

    bx          lr
endfunc

function predict_8x8_hu_neon
    mov         r12, #FDEC_STRIDE
    add         r1, #7
    vld1.8      {d7}, [r1]
    vdup.8      d6, d7[0]
    vrev64.8    d7, d7

    vext.8      d4, d7, d6, #2
    vext.8      d2, d7, d6, #1

    vhadd.u8    d16, d7, d4
    vrhadd.u8   d0, d2, d7
    vrhadd.u8   d1, d16, d2

    vzip.8      d0, d1

    vdup.16     q1, d1[3]

    vext.8      q2, q0, q1, #2
    vext.8      q3, q0, q1, #4
    vext.8      q8, q0, q1, #6
    vst1.8      {d0}, [r0,:64], r12
    vst1.8      {d4}, [r0,:64], r12
    vst1.8      {d6}, [r0,:64], r12
    vst1.8      {d16}, [r0,:64], r12

    vst1.8      {d1}, [r0,:64], r12
    vst1.8      {d5}, [r0,:64], r12
    vst1.8      {d7}, [r0,:64], r12
    vst1.8      {d17}, [r0,:64]
    bx          lr
endfunc

function predict_8x8c_dc_top_neon
    sub         r2,  r0,  #FDEC_STRIDE
    mov         r1,  #FDEC_STRIDE
    vld1.8      {d0}, [r2,:64]
    vpaddl.u8   d0,  d0
    vpadd.u16   d0,  d0,  d0
    vrshrn.u16  d0,  q0,  #2
    vdup.8      d1,  d0[1]
    vdup.8      d0,  d0[0]
    vtrn.32     d0,  d1
    b           pred8x8_dc_end
endfunc

function predict_8x8c_dc_left_neon
    mov         r1,  #FDEC_STRIDE
    sub         r2,  r0,  #1
    ldcol.8     d0,  r2,  r1
    vpaddl.u8   d0,  d0
    vpadd.u16   d0,  d0,  d0
    vrshrn.u16  d0,  q0,  #2
    vdup.8      d1,  d0[1]
    vdup.8      d0,  d0[0]
    b           pred8x8_dc_end
endfunc

function predict_8x8c_dc_neon
    sub         r2,  r0,  #FDEC_STRIDE
    mov         r1,  #FDEC_STRIDE
    vld1.8      {d0}, [r2,:64]
    sub         r2,  r0,  #1
    ldcol.8     d1,  r2,  r1
    vtrn.32     d0,  d1
    vpaddl.u8   q0,  q0
    vpadd.u16   d0,  d0,  d1
    vpadd.u16   d1,  d0,  d0
    vrshrn.u16  d2,  q0,  #3
    vrshrn.u16  d3,  q0,  #2
    vdup.8      d0,  d2[4]
    vdup.8      d1,  d3[3]
    vdup.8      d4,  d3[2]
    vdup.8      d5,  d2[5]
    vtrn.32     q0,  q2
pred8x8_dc_end:
    add         r2,  r0,  r1,  lsl #2
.rept 4
    vst1.8      {d0}, [r0,:64], r1
    vst1.8      {d1}, [r2,:64], r1
.endr
    bx          lr
endfunc

function predict_8x8c_h_neon
    sub         r1, r0, #1
    mov         ip, #FDEC_STRIDE
.rept 4
    vld1.8      {d0[]}, [r1], ip
    vld1.8      {d2[]}, [r1], ip
    vst1.64     {d0}, [r0,:64], ip
    vst1.64     {d2}, [r0,:64], ip
.endr
    bx          lr
endfunc

function predict_8x8c_v_neon
    sub         r0, r0, #FDEC_STRIDE
    mov         ip, #FDEC_STRIDE
    vld1.64     {d0}, [r0,:64], ip
.rept 8
    vst1.64     {d0}, [r0,:64], ip
.endr
    bx          lr
endfunc

function predict_8x8c_p_neon
    sub         r3,  r0,  #FDEC_STRIDE
    mov         r1,  #FDEC_STRIDE
    add         r2,  r3,  #4
    sub         r3,  r3,  #1
    vld1.32     {d0[0]}, [r3]
    vld1.32     {d2[0]}, [r2,:32], r1
    ldcol.8     d0,  r3,  r1,  4,  hi=1
    add         r3,  r3,  r1
    ldcol.8     d3,  r3,  r1,  4
    vaddl.u8    q8,  d2,  d3
    vrev32.8    d0,  d0
    vtrn.32     d2,  d3
    vsubl.u8    q2,  d2,  d0
    movrel      r3,  p16weight
    vld1.16     {q0}, [r3,:128]
    vmul.s16    d4,  d4,  d0
    vmul.s16    d5,  d5,  d0
    vpadd.i16   d4,  d4,  d5
    vpaddl.s16  d4,  d4
    vshl.i32    d5,  d4,  #4
    vadd.s32    d4,  d4,  d5
    vrshrn.s32  d4,  q2,  #5
    mov         r3,  #0
    vtrn.16     d4,  d5
    vadd.i16    d2,  d4,  d5
    vshl.i16    d3,  d2,  #2
    vrev64.16   d16, d16
    vsub.i16    d3,  d3,  d2
    vadd.i16    d16, d16, d0
    vshl.i16    d2,  d16, #4
    vsub.i16    d2,  d2,  d3
    vext.16     q0,  q0,  q0,  #7
    vmov.16     d0[0], r3
    vmul.i16    q0,  q0,  d4[0]
    vdup.16     q1,  d2[0]
    vdup.16     q3,  d5[0]
    vadd.i16    q1,  q1,  q0
    mov         r3,  #8
1:
    vqshrun.s16 d0,  q1,  #5
    vadd.i16    q1,  q1,  q3
    vst1.8      {d0}, [r0,:64], r1
    subs        r3,  r3,  #1
    bne         1b
    bx          lr
endfunc


function predict_8x16c_dc_top_neon
    sub         r2,  r0,  #FDEC_STRIDE
    mov         r1,  #FDEC_STRIDE
    vld1.8      {d0}, [r2,:64]
    vpaddl.u8   d0,  d0
    vpadd.u16   d0,  d0,  d0
    vrshrn.u16  d0,  q0,  #2
    vdup.8      d1,  d0[1]
    vdup.8      d0,  d0[0]
    vtrn.32     d0,  d1

    add         r2,  r0,  r1,  lsl #2
.rept 4
    vst1.8      {d0}, [r0,:64], r1
    vst1.8      {d1}, [r2,:64], r1
.endr
    add         r2,  r2,  r1,  lsl #2
    add         r0,  r0,  r1,  lsl #2
.rept 4
    vst1.8      {d0}, [r0,:64], r1
    vst1.8      {d1}, [r2,:64], r1
.endr
    bx          lr
endfunc

function predict_8x16c_h_neon
    sub         r1, r0, #1
    mov         ip, #FDEC_STRIDE
.rept 8
    vld1.8      {d0[]}, [r1], ip
    vld1.8      {d2[]}, [r1], ip
    vst1.64     {d0}, [r0,:64], ip
    vst1.64     {d2}, [r0,:64], ip
.endr
    bx          lr
endfunc

function predict_8x16c_p_neon
    sub         r3,  r0,  #FDEC_STRIDE
    mov         r1,  #FDEC_STRIDE
    add         r2,  r3,  #4
    sub         r3,  r3,  #1
    vld1.32     {d0[0]}, [r3]
    vld1.32     {d2[0]}, [r2,:32], r1
    ldcol.8     d1,  r3,  r1
    add         r3,  r3,  r1
    ldcol.8     d3,  r3,  r1
    vrev64.32   d16, d3
    vaddl.u8    q8,  d2,  d16
    vrev32.8    d0,  d0
    vsubl.u8    q2,  d2,  d0
    vrev64.8    d1,  d1
    vsubl.u8    q3,  d3,  d1
    movrel      r3,  p16weight
    vld1.16     {q0}, [r3,:128]
    vmul.s16    d4,  d4,  d0
    vmul.s16    q3,  q3,  q0
    vpadd.i16   d4,  d4,  d5
    vpadd.i16   d6,  d6,  d7
    vpaddl.s16  d4,  d4        @ d4[0] = H
    vpaddl.s16  d6,  d6
    vpadd.s32   d6,  d6        @ d6[0] = V
    vshl.i32    d5,  d4,  #4
    vadd.s32    d4,  d4,  d5   @ d4[0] = 17*H
    vshl.i32    d7,  d6,  #2
    vrshrn.s32  d4,  q2,  #5   @ d4[0] = b
    vadd.s32    d6,  d6,  d7   @ d6[0] = 5*V
    vrshrn.s32  d6,  q3,  #6   @ d6[0] = c
    mov         r3,  #0
    vshl.i16    d3,  d4,  #2
    vsub.i16    d3,  d3,  d4   @ d2[0] = 3 * b
    vshl.i16    d2,  d6,  #3
    vadd.i16    d3,  d3,  d2   @ d2[0] = 3 * b + 8 * c
    vsub.i16    d3,  d3,  d6   @ d2[0] = 3 * b + 7 * c
    vrev64.16   d16, d16
    vadd.i16    d16, d16, d0   @ d16[0] = src[]+src[] + 1
    vshl.i16    d2,  d16, #4   @ d3[0] = a + 16
    vsub.i16    d2,  d2,  d3   @ i00
    vext.16     q0,  q0,  q0,  #7
    vmov.16     d0[0], r3
    vmul.i16    q0,  q0,  d4[0]
    vdup.16     q1,  d2[0]
    vdup.16     q3,  d6[0]
    vadd.i16    q1,  q1,  q0
    mov         r3,  #16
1:
    vqshrun.s16 d0,  q1,  #5
    vadd.i16    q1,  q1,  q3
    vst1.8      {d0}, [r0,:64], r1
    subs        r3,  r3,  #1
    bne         1b
    bx          lr
endfunc


function predict_16x16_dc_top_neon
    sub         r2,  r0,  #FDEC_STRIDE
    mov         r1,  #FDEC_STRIDE
    vld1.8      {q0}, [r2,:128]
    add16x8     q0,  d0,  d1,  d0,  d1
    vrshrn.u16  d0,  q0,  #4
    vdup.8      q0,  d0[0]
    b           pred16x16_dc_end
endfunc

function predict_16x16_dc_left_neon
    mov         r1,  #FDEC_STRIDE
    sub         r2,  r0,  #1
    ldcol.8     d0,  r2,  r1
    ldcol.8     d1,  r2,  r1
    add16x8     q0,  d0,  d1,  d0,  d1
    vrshrn.u16  d0,  q0,  #4
    vdup.8      q0,  d0[0]
    b           pred16x16_dc_end
endfunc

function predict_16x16_dc_neon
    sub         r3, r0, #FDEC_STRIDE
    sub         r0, r0, #1
    vld1.64     {d0-d1}, [r3,:128]
    ldrb        ip, [r0], #FDEC_STRIDE
    vaddl.u8    q0, d0, d1
    ldrb        r1, [r0], #FDEC_STRIDE
    vadd.u16    d0, d0, d1
    vpadd.u16   d0, d0, d0
    vpadd.u16   d0, d0, d0
.rept 4
    ldrb        r2, [r0], #FDEC_STRIDE
    add         ip, ip, r1
    ldrb        r3, [r0], #FDEC_STRIDE
    add         ip, ip, r2
    ldrb        r1, [r0], #FDEC_STRIDE
    add         ip, ip, r3
.endr
    ldrb        r2, [r0], #FDEC_STRIDE
    add         ip, ip, r1
    ldrb        r3, [r0], #FDEC_STRIDE
    add         ip, ip, r2

    sub         r0, r0, #FDEC_STRIDE*16
    add         ip, ip, r3
    vdup.16     d1, ip
    vadd.u16    d0, d0, d1
    mov         r1, #FDEC_STRIDE
    add         r0, r0, #1
    vrshr.u16   d0, d0, #5
    vdup.8      q0, d0[0]
pred16x16_dc_end:
.rept 16
    vst1.64     {d0-d1}, [r0,:128], r1
.endr
    bx          lr
endfunc

function predict_16x16_h_neon
    sub         r1, r0, #1
    mov         ip, #FDEC_STRIDE
.rept 8
    vld1.8      {d0[]}, [r1], ip
    vmov        d1, d0
    vld1.8      {d2[]}, [r1], ip
    vmov        d3, d2
    vst1.64     {d0-d1}, [r0,:128], ip
    vst1.64     {d2-d3}, [r0,:128], ip
.endr
    bx          lr
endfunc

function predict_16x16_v_neon
    sub         r0, r0, #FDEC_STRIDE
    mov         ip, #FDEC_STRIDE
    vld1.64     {d0-d1}, [r0,:128], ip
.rept 16
    vst1.64     {d0-d1}, [r0,:128], ip
.endr
    bx          lr
endfunc

function predict_16x16_p_neon
    sub         r3,  r0,  #FDEC_STRIDE
    mov         r1,  #FDEC_STRIDE
    add         r2,  r3,  #8
    sub         r3,  r3,  #1
    vld1.8      {d0}, [r3]
    vld1.8      {d2}, [r2,:64], r1
    ldcol.8     d1,  r3,  r1
    add         r3,  r3,  r1
    ldcol.8     d3,  r3,  r1
    vrev64.8    q0,  q0
    vaddl.u8    q8,  d2,  d3
    vsubl.u8    q2,  d2,  d0
    vsubl.u8    q3,  d3,  d1
    movrel      r3,  p16weight
    vld1.8      {q0}, [r3,:128]
    vmul.s16    q2,  q2,  q0
    vmul.s16    q3,  q3,  q0
    vadd.i16    d4,  d4,  d5
    vadd.i16    d5,  d6,  d7
    vpadd.i16   d4,  d4,  d5
    vpadd.i16   d4,  d4,  d4
    vshll.s16   q3,  d4,  #2
    vaddw.s16   q2,  q3,  d4
    vrshrn.s32  d4,  q2,  #6
    mov         r3,  #0
    vtrn.16     d4,  d5
    vadd.i16    d2,  d4,  d5
    vshl.i16    d3,  d2,  #3
    vrev64.16   d16, d17
    vsub.i16    d3,  d3,  d2
    vadd.i16    d16, d16, d0
    vshl.i16    d2,  d16, #4
    vsub.i16    d2,  d2,  d3
    vshl.i16    d3,  d4,  #4
    vext.16     q0,  q0,  q0,  #7
    vsub.i16    d6,  d5,  d3
    vmov.16     d0[0], r3
    vmul.i16    q0,  q0,  d4[0]
    vdup.16     q1,  d2[0]
    vdup.16     q2,  d4[0]
    vdup.16     q3,  d6[0]
    vshl.i16    q2,  q2,  #3
    vadd.i16    q1,  q1,  q0
    vadd.i16    q3,  q3,  q2
    mov         r3,  #16
1:
    vqshrun.s16 d0,  q1,  #5
    vadd.i16    q1,  q1,  q2
    vqshrun.s16 d1,  q1,  #5
    vadd.i16    q1,  q1,  q3
    vst1.8      {q0}, [r0,:128], r1
    subs        r3,  r3,  #1
    bne         1b
    bx          lr
endfunc
