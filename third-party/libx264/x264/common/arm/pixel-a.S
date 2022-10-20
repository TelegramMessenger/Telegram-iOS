/*****************************************************************************
 * pixel.S: arm pixel metrics
 *****************************************************************************
 * Copyright (C) 2009-2022 x264 project
 *
 * Authors: David Conrad <lessen42@gmail.com>
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

const mask_array, align=4
.rept 16
        .byte 0xff
.endr
mask_ff:
.rept 16
        .byte 0
.endr
endconst

const mask_ac4, align=4
.short 0, -1, -1, -1,  0, -1, -1, -1
endconst
const mask_ac8, align=4
.short 0, -1, -1, -1, -1, -1, -1, -1
endconst

.text

.macro SAD4_ARMV6 h
function pixel_sad_4x\h\()_armv6
    push        {r4-r6,lr}
    ldr         r4, [r2], r3
    ldr         r5, [r0], r1
    ldr         r6, [r2], r3
    ldr         lr, [r0], r1
    usad8       ip, r4, r5
.rept (\h - 2)/2
    ldr         r4, [r2], r3
    ldr         r5, [r0], r1
    usada8      ip, r6, lr, ip
    ldr         r6, [r2], r3
    ldr         lr, [r0], r1
    usada8      ip, r4, r5, ip
.endr
    usada8      r0, r6, lr, ip
    pop         {r4-r6,pc}
endfunc
.endm

SAD4_ARMV6 4
SAD4_ARMV6 8


.macro SAD_START_4 align:vararg
    vld1.32     {d1[]}, [r2\align], r3
    vld1.32     {d0[]}, [r0,:32], r1
    vabdl.u8    q8,  d0,  d1
.endm

.macro SAD_4 align:vararg
    vld1.32     {d1[]}, [r2\align], r3
    vld1.32     {d0[]}, [r0,:32], r1
    vabal.u8    q8,  d0,  d1
.endm

.macro SAD_START_8 align:vararg
    vld1.64     {d1}, [r2\align], r3
    vld1.64     {d0}, [r0,:64], r1
    vabdl.u8    q8,  d0,  d1
.endm

.macro SAD_8 align:vararg
    vld1.64     {d1}, [r2\align], r3
    vld1.64     {d0}, [r0,:64], r1
    vabal.u8    q8,  d0,  d1
.endm

.macro SAD_START_16 align:vararg
    vld1.64     {d2-d3}, [r2\align], r3
    vld1.64     {d0-d1}, [r0,:128], r1
    vabdl.u8    q8,  d0,  d2
    vld1.64     {d6-d7}, [r2\align], r3
    vabdl.u8    q9,  d1,  d3
    vld1.64     {d4-d5}, [r0,:128], r1
.endm

.macro SAD_16 align:vararg
    vabal.u8    q8,  d4,  d6
    vld1.64     {d2-d3}, [r2\align], r3
    vabal.u8    q9,  d5,  d7
    vld1.64     {d0-d1}, [r0,:128], r1
    vabal.u8    q8,  d0,  d2
    vld1.64     {d6-d7}, [r2\align], r3
    vabal.u8    q9,  d1,  d3
    vld1.64     {d4-d5}, [r0,:128], r1
.endm

.macro SAD_FUNC w, h, name, align:vararg
function pixel_sad\name\()_\w\()x\h\()_neon
    SAD_START_\w \align

.if \w == 16
.rept \h / 2 - 1
    SAD_\w \align
.endr
.else
.rept \h - 1
    SAD_\w \align
.endr
.endif

.if \w > 8
    vabal.u8    q8,  d4,  d6
    vabal.u8    q9,  d5,  d7
    vadd.u16    q8,  q8,  q9
.endif
.if \w > 4
    vadd.u16    d16, d16, d17
.endif
    vpadd.u16   d0,  d16, d16
    vpaddl.u16  d0,  d0
    vmov.u32    r0,  d0[0]
    bx          lr
endfunc
.endm

SAD_FUNC  4,  4
SAD_FUNC  4,  8
SAD_FUNC  8,  4
SAD_FUNC  8,  8
SAD_FUNC  8,  16
SAD_FUNC  16, 8
SAD_FUNC  16, 16

SAD_FUNC  4,  4,  _aligned, ,:32
SAD_FUNC  4,  8,  _aligned, ,:32
SAD_FUNC  8,  4,  _aligned, ,:64
SAD_FUNC  8,  8,  _aligned, ,:64
SAD_FUNC  8,  16, _aligned, ,:64
SAD_FUNC  16, 8,  _aligned, ,:128
SAD_FUNC  16, 16, _aligned, ,:128

// If dual issue is possible, use additional accumulators to avoid
// stalls from vadal's latency. This only matters for aligned.
.macro SAD_DUAL_START_8
    SAD_START_8 ,:64
    vld1.64     {d3}, [r2,:64], r3
    vld1.64     {d2}, [r0,:64], r1
    vabdl.u8    q9,  d2,  d3
.endm

.macro SAD_DUAL_8 align:vararg
    vld1.64     {d1}, [r2,:64], r3
    vld1.64     {d0}, [r0,:64], r1
    vabal.u8    q8,  d0,  d1
    vld1.64     {d3}, [r2,:64], r3
    vld1.64     {d2}, [r0,:64], r1
    vabal.u8    q9,  d2,  d3
.endm

.macro SAD_DUAL_START_16
    SAD_START_16 ,:128
    vabdl.u8    q10, d4,  d6
    vld1.64     {d2-d3}, [r2,:128], r3
    vabdl.u8    q11, d5,  d7
    vld1.64     {d0-d1}, [r0,:128], r1
.endm

.macro SAD_DUAL_16
    vabal.u8    q8,  d0,  d2
    vld1.64     {d6-d7}, [r2,:128], r3
    vabal.u8    q9,  d1,  d3
    vld1.64     {d4-d5}, [r0,:128], r1
    vabal.u8    q10, d4,  d6
    vld1.64     {d2-d3}, [r2,:128], r3
    vabal.u8    q11, d5,  d7
    vld1.64     {d0-d1}, [r0,:128], r1
.endm

.macro SAD_DUAL_END_16
    vabal.u8    q8,  d0,  d2
    vld1.64     {d6-d7}, [r2,:128], r3
    vabal.u8    q9,  d1,  d3
    vld1.64     {d4-d5}, [r0,:128], r1
    vabal.u8    q10, d4,  d6
    vabal.u8    q11, d5,  d7
.endm

.macro SAD_FUNC_DUAL w, h
function pixel_sad_aligned_\w\()x\h\()_neon_dual
    SAD_DUAL_START_\w
.rept \h / 2 - \w / 8
    SAD_DUAL_\w
.endr

.if \w > 8
    SAD_DUAL_END_16
    vadd.u16    q8,  q8,  q9
    vadd.u16    q9,  q10, q11
.endif
.if \w > 4
    vadd.u16    q8,  q8,  q9
    vadd.u16    d16, d16, d17
.endif
    vpadd.u16   d0,  d16, d16
    vpaddl.u16  d0,  d0
    vmov.u32    r0,  d0[0]
    bx          lr
endfunc
.endm

SAD_FUNC_DUAL  8,  4
SAD_FUNC_DUAL  8,  8
SAD_FUNC_DUAL  8,  16
SAD_FUNC_DUAL  16, 8
SAD_FUNC_DUAL  16, 16


.macro SAD_X_START_4 x
    vld1.32     {d0[]}, [r0,:32], lr
    vld1.32     {d1[]}, [r1], r6
    vabdl.u8    q8,  d1,  d0
    vld1.32     {d2[]}, [r2], r6
    vabdl.u8    q9,  d2,  d0
    vld1.32     {d3[]}, [r3], r6
    vabdl.u8    q10, d3,  d0
.if \x == 4
    vld1.32     {d4[]}, [r12], r6
    vabdl.u8    q11, d4,  d0
.endif
.endm

.macro SAD_X_4 x
    vld1.32     {d0[]}, [r0,:32], lr
    vld1.32     {d1[]}, [r1], r6
    vabal.u8    q8,  d1,  d0
    vld1.32     {d2[]}, [r2], r6
    vabal.u8    q9,  d2,  d0
    vld1.32     {d3[]}, [r3], r6
    vabal.u8    q10, d3,  d0
.if \x == 4
    vld1.32     {d4[]}, [r12], r6
    vabal.u8    q11, d4,  d0
.endif
.endm

.macro SAD_X_START_8 x
    vld1.64     {d0}, [r0,:64], lr
    vld1.64     {d1}, [r1], r6
    vabdl.u8    q8,  d1,  d0
    vld1.64     {d2}, [r2], r6
    vabdl.u8    q9,  d2,  d0
    vld1.64     {d3}, [r3], r6
    vabdl.u8    q10, d3,  d0
.if \x == 4
    vld1.64     {d4}, [r12], r6
    vabdl.u8    q11, d4,  d0
.endif
.endm

.macro SAD_X_8 x
    vld1.64     {d0}, [r0,:64], lr
    vld1.64     {d1}, [r1], r6
    vabal.u8    q8,  d1,  d0
    vld1.64     {d2}, [r2], r6
    vabal.u8    q9,  d2,  d0
    vld1.64     {d3}, [r3], r6
    vabal.u8    q10, d3,  d0
.if \x == 4
    vld1.64     {d4}, [r12], r6
    vabal.u8    q11, d4,  d0
.endif
.endm

.macro SAD_X_START_16 x
    vld1.64     {d0-d1}, [r0,:128], lr
    vld1.64     {d2-d3}, [r1], r6
    vabdl.u8    q8,  d2,  d0
    vabdl.u8    q12, d3,  d1
    vld1.64     {d4-d5}, [r2], r6
    vabdl.u8    q9,  d4,  d0
    vabdl.u8    q13, d5,  d1
    vld1.64     {d6-d7}, [r3], r6
    vabdl.u8    q10, d6,  d0
    vabdl.u8    q14, d7,  d1
.if \x == 4
    vld1.64     {d2-d3}, [r12], r6
    vabdl.u8    q11, d2,  d0
    vabdl.u8    q15, d3,  d1
.endif
.endm

.macro SAD_X_16 x
    vld1.64     {d0-d1}, [r0,:128], lr
    vld1.64     {d2-d3}, [r1], r6
    vabal.u8    q8,  d2,  d0
    vabal.u8    q12, d3,  d1
    vld1.64     {d4-d5}, [r2], r6
    vabal.u8    q9,  d4,  d0
    vabal.u8    q13, d5,  d1
    vld1.64     {d6-d7}, [r3], r6
    vabal.u8    q10, d6,  d0
    vabal.u8    q14, d7,  d1
.if \x == 4
    vld1.64     {d2-d3}, [r12], r6
    vabal.u8    q11, d2,  d0
    vabal.u8    q15, d3,  d1
.endif
.endm

.macro SAD_X_FUNC x, w, h
function pixel_sad_x\x\()_\w\()x\h\()_neon
    push        {r6-r7,lr}
.if \x == 3
    ldrd        r6,  r7,  [sp, #12]
.else
    ldrd        r6,  r7,  [sp, #16]
    ldr         r12, [sp, #12]
.endif
    mov         lr,  #FENC_STRIDE

    SAD_X_START_\w \x
.rept \h - 1
    SAD_X_\w \x
.endr

// add up the sads
.if \w > 8
    vadd.u16    q8,  q8,  q12
    vadd.u16    q9,  q9,  q13
    vadd.u16    q10, q10, q14
.if \x == 4
    vadd.u16    q11, q11, q15
.endif
.endif
.if \w > 4
    vadd.u16    d16, d16, d17
    vadd.u16    d18, d18, d19
    vadd.u16    d20, d20, d21
.if \x == 4
    vadd.u16    d22, d22, d23
.endif
.endif
    vpadd.u16   d0,  d16, d18
    vpadd.u16   d1,  d20, d22
    vpaddl.u16  q0,  q0

.if \x == 3
    vst1.32     {d0},    [r7]!
    vst1.32     {d1[0]}, [r7,:32]
.else
    vst1.32     {d0-d1}, [r7]
.endif
    pop         {r6-r7,pc}
endfunc
.endm

SAD_X_FUNC  3, 4,  4
SAD_X_FUNC  3, 4,  8
SAD_X_FUNC  3, 8,  4
SAD_X_FUNC  3, 8,  8
SAD_X_FUNC  3, 8,  16
SAD_X_FUNC  3, 16, 8
SAD_X_FUNC  3, 16, 16

SAD_X_FUNC  4, 4,  4
SAD_X_FUNC  4, 4,  8
SAD_X_FUNC  4, 8,  4
SAD_X_FUNC  4, 8,  8
SAD_X_FUNC  4, 8,  16
SAD_X_FUNC  4, 16, 8
SAD_X_FUNC  4, 16, 16

function pixel_vsad_neon
    subs        r2,  r2,    #2
    vld1.8     {q0}, [r0],  r1
    vld1.8     {q1}, [r0],  r1
    vabdl.u8    q2,  d0,    d2
    vabdl.u8    q3,  d1,    d3
    ble         2f
1:
    subs        r2,  r2,    #2
    vld1.8     {q0}, [r0],  r1
    vabal.u8    q2,  d2,    d0
    vabal.u8    q3,  d3,    d1
    vld1.8     {q1}, [r0],  r1
    blt         2f
    vabal.u8    q2,  d0,    d2
    vabal.u8    q3,  d1,    d3
    bgt         1b
2:
    vadd.u16    q0,  q2,    q3
    HORIZ_ADD   d0,  d0,    d1
    vmov.32     r0,  d0[0]
    bx          lr
endfunc

function pixel_asd8_neon
    ldr         r12, [sp,  #0]
    sub         r12,  r12, #2
    vld1.8     {d0}, [r0], r1
    vld1.8     {d1}, [r2], r3
    vld1.8     {d2}, [r0], r1
    vld1.8     {d3}, [r2], r3
    vsubl.u8    q8,   d0,  d1
1:
    subs        r12,  r12,  #2
    vld1.8     {d4}, [r0], r1
    vld1.8     {d5}, [r2], r3
    vsubl.u8    q9,   d2,  d3
    vsubl.u8    q10,  d4,  d5
    vadd.s16    q8,   q9
    vld1.8     {d2}, [r0], r1
    vld1.8     {d3}, [r2], r3
    vadd.s16    q8,   q10
    bgt         1b
    vsubl.u8    q9,   d2,  d3
    vadd.s16    q8,   q9
    vpaddl.s16  q8,   q8
    vpadd.s32   d16,  d16, d17
    vpadd.s32   d16,  d16, d17
    vabs.s32    d16,  d16
    vmov.32     r0,   d16[0]
    bx          lr
endfunc


.macro SSD_START_4
    vld1.32     {d16[]}, [r0,:32], r1
    vld1.32     {d17[]}, [r2,:32], r3
    vsubl.u8    q2, d16, d17
    vld1.32     {d16[]}, [r0,:32], r1
    vmull.s16   q0, d4, d4
    vld1.32     {d17[]}, [r2,:32], r3
.endm

.macro SSD_4
    vsubl.u8    q2, d16, d17
    vld1.32     {d16[]}, [r0,:32], r1
    vmlal.s16   q0, d4, d4
    vld1.32     {d17[]}, [r2,:32], r3
.endm

.macro SSD_END_4
    vsubl.u8    q2, d16, d17
    vmlal.s16   q0, d4, d4
.endm

.macro SSD_START_8
    vld1.64     {d16}, [r0,:64], r1
    vld1.64     {d17}, [r2,:64], r3
    vsubl.u8    q2, d16, d17
    vld1.64     {d16}, [r0,:64], r1
    vmull.s16   q0, d4, d4
    vmlal.s16   q0, d5, d5
    vld1.64     {d17}, [r2,:64], r3
.endm

.macro SSD_8
    vsubl.u8    q2, d16, d17
    vld1.64     {d16}, [r0,:64], r1
    vmlal.s16   q0, d4, d4
    vmlal.s16   q0, d5, d5
    vld1.64     {d17}, [r2,:64], r3
.endm

.macro SSD_END_8
    vsubl.u8    q2, d16, d17
    vmlal.s16   q0, d4, d4
    vmlal.s16   q0, d5, d5
.endm

.macro SSD_START_16
    vld1.64     {d16-d17}, [r0,:128], r1
    vld1.64     {d18-d19}, [r2,:128], r3
    vsubl.u8    q2, d16, d18
    vsubl.u8    q3, d17, d19
    vld1.64     {d16-d17}, [r0,:128], r1
    vmull.s16   q0, d4, d4
    vmlal.s16   q0, d5, d5
    vld1.64     {d18-d19}, [r2,:128], r3
    vmlal.s16   q0, d6, d6
    vmlal.s16   q0, d7, d7
.endm

.macro SSD_16
    vsubl.u8    q2, d16, d18
    vsubl.u8    q3, d17, d19
    vld1.64     {d16-d17}, [r0,:128], r1
    vmlal.s16   q0, d4, d4
    vmlal.s16   q0, d5, d5
    vld1.64     {d18-d19}, [r2,:128], r3
    vmlal.s16   q0, d6, d6
    vmlal.s16   q0, d7, d7
.endm

.macro SSD_END_16
    vsubl.u8    q2, d16, d18
    vsubl.u8    q3, d17, d19
    vmlal.s16   q0, d4, d4
    vmlal.s16   q0, d5, d5
    vmlal.s16   q0, d6, d6
    vmlal.s16   q0, d7, d7
.endm

.macro SSD_FUNC w h
function pixel_ssd_\w\()x\h\()_neon
    SSD_START_\w
.rept \h-2
    SSD_\w
.endr
    SSD_END_\w
    vadd.s32    d0, d0, d1
    vpadd.s32   d0, d0, d0
    vmov.32     r0, d0[0]
    bx          lr
endfunc
.endm

SSD_FUNC   4, 4
SSD_FUNC   4, 8
SSD_FUNC   8, 4
SSD_FUNC   8, 8
SSD_FUNC   8, 16
SSD_FUNC  16, 8
SSD_FUNC  16, 16

function pixel_ssd_nv12_core_neon
    push       {r4-r5}
    ldrd        r4,  r5,  [sp, #8]
    add         r12, r4,  #8
    bic         r12, r12, #15
    vmov.u64    q8,  #0
    vmov.u64    q9,  #0
    sub         r1,  r1,  r12, lsl #1
    sub         r3,  r3,  r12, lsl #1
1:
    subs        r12, r4,  #16
    vld2.8     {d0,d1},   [r0]!
    vld2.8     {d2,d3},   [r2]!
    vld2.8     {d4,d5},   [r0]!
    vld2.8     {d6,d7},   [r2]!

    vsubl.u8    q10, d0,  d2
    vsubl.u8    q11, d1,  d3
    vmull.s16   q14, d20, d20
    vmull.s16   q15, d22, d22
    vsubl.u8    q12, d4,  d6
    vsubl.u8    q13, d5,  d7
    vmlal.s16   q14, d21, d21
    vmlal.s16   q15, d23, d23

    blt         4f
    beq         3f
2:
    vmlal.s16   q14, d24, d24
    vmlal.s16   q15, d26, d26
    vld2.8     {d0,d1},   [r0]!
    vld2.8     {d2,d3},   [r2]!
    vmlal.s16   q14, d25, d25
    vmlal.s16   q15, d27, d27

    subs        r12, r12, #16
    vsubl.u8    q10, d0,  d2
    vsubl.u8    q11, d1,  d3
    vmlal.s16   q14, d20, d20
    vmlal.s16   q15, d22, d22
    vld2.8     {d4,d5},   [r0]!
    vld2.8     {d6,d7},   [r2]!
    vmlal.s16   q14, d21, d21
    vmlal.s16   q15, d23, d23
    blt         4f

    vsubl.u8    q12, d4,  d6
    vsubl.u8    q13, d5,  d7
    bgt         2b
3:
    vmlal.s16   q14, d24, d24
    vmlal.s16   q15, d26, d26
    vmlal.s16   q14, d25, d25
    vmlal.s16   q15, d27, d27
4:
    subs        r5,  r5,  #1
    vaddw.s32   q8,  q8,  d28
    vaddw.s32   q9,  q9,  d30
    add         r0,  r0,  r1
    add         r2,  r2,  r3
    vaddw.s32   q8,  q8,  d29
    vaddw.s32   q9,  q9,  d31
    bgt         1b

    vadd.u64    d16, d16, d17
    vadd.u64    d18, d18, d19
    ldrd        r4,  r5, [sp, #16]
    vst1.64    {d16}, [r4]
    vst1.64    {d18}, [r5]

    pop        {r4-r5}
    bx          lr
endfunc

.macro VAR_SQR_SUM qsqr_sum qsqr_last qsqr dsrc vpadal=vpadal.u16
    vmull.u8        \qsqr, \dsrc, \dsrc
    vaddw.u8        q0, q0, \dsrc
    \vpadal         \qsqr_sum, \qsqr_last
.endm

function pixel_var_8x8_neon
    vld1.64         {d16}, [r0,:64], r1
    vmull.u8        q1,  d16, d16
    vmovl.u8        q0,  d16
    vld1.64         {d18}, [r0,:64], r1
    vmull.u8        q2,  d18, d18
    vaddw.u8        q0,  q0,  d18

    vld1.64         {d20}, [r0,:64], r1
    VAR_SQR_SUM     q1,  q1,   q3,  d20, vpaddl.u16
    vld1.64         {d22}, [r0,:64], r1
    VAR_SQR_SUM     q2,  q2,   q8,  d22, vpaddl.u16

    vld1.64         {d24}, [r0,:64], r1
    VAR_SQR_SUM     q1,  q3,   q9,  d24
    vld1.64         {d26}, [r0,:64], r1
    VAR_SQR_SUM     q2,  q8,   q10, d26
    vld1.64         {d24}, [r0,:64], r1
    VAR_SQR_SUM     q1,  q9,   q14, d24
    vld1.64         {d26}, [r0,:64], r1
    VAR_SQR_SUM     q2,  q10,  q15, d26
    b               var_end
endfunc

function pixel_var_8x16_neon
    vld1.64         {d16}, [r0,:64], r1
    vld1.64         {d18}, [r0,:64], r1
    vmull.u8        q1,  d16, d16
    vmovl.u8        q0,  d16
    vld1.64         {d20}, [r0,:64], r1
    vmull.u8        q2,  d18, d18
    vaddw.u8        q0,  q0,  d18

    mov             ip,  #12

    vld1.64         {d22}, [r0,:64], r1
    VAR_SQR_SUM     q1,  q1,   q14,  d20, vpaddl.u16
    vld1.64         {d16}, [r0,:64], r1
    VAR_SQR_SUM     q2,  q2,   q15,  d22, vpaddl.u16

1:  subs            ip,  ip,  #4
    vld1.64         {d18}, [r0,:64], r1
    VAR_SQR_SUM     q1,  q14,  q12, d16
    vld1.64         {d20}, [r0,:64], r1
    VAR_SQR_SUM     q2,  q15,  q13, d18
    vld1.64         {d22}, [r0,:64], r1
    VAR_SQR_SUM     q1,  q12,  q14, d20
    beq             2f
    vld1.64         {d16}, [r0,:64], r1
    VAR_SQR_SUM     q2,  q13,  q15, d22
    b               1b
2:
    VAR_SQR_SUM     q2,  q13,  q15, d22
    b               var_end
endfunc

function pixel_var_16x16_neon
    vld1.64         {d16-d17}, [r0,:128], r1
    vmull.u8        q12, d16, d16
    vmovl.u8        q0,  d16
    vmull.u8        q13, d17, d17
    vaddw.u8        q0,  q0,  d17

    vld1.64         {d18-d19}, [r0,:128], r1
    VAR_SQR_SUM     q1,  q12,  q14, d18, vpaddl.u16
    VAR_SQR_SUM     q2,  q13,  q15, d19, vpaddl.u16

    mov             ip,  #7
var16_loop:
    subs            ip,  ip,  #1
    vld1.64         {d16-d17}, [r0,:128], r1
    VAR_SQR_SUM     q1,  q14,  q12, d16
    VAR_SQR_SUM     q2,  q15,  q13, d17

    vld1.64         {d18-d19}, [r0,:128], r1
    VAR_SQR_SUM     q1,  q12,  q14, d18
    VAR_SQR_SUM     q2,  q13,  q15, d19
    bgt             var16_loop
endfunc

function var_end, export=0
    vpaddl.u16      q8,  q14
    vpaddl.u16      q9,  q15
    vadd.u32        q1,  q1,  q8
    vadd.u16        d0,  d0,  d1
    vadd.u32        q1,  q1,  q9
    vadd.u32        q1,  q1,  q2
    vpaddl.u16      d0,  d0
    vadd.u32        d2,  d2,  d3
    vpadd.u32       d0,  d0,  d2

    vmov            r0,  r1,  d0
    bx              lr
endfunc

.macro DIFF_SUM diff1 diff2 da1 db1 da2 db2 lastdiff1 lastdiff2 acc1 acc2
    vld1.64         {\da1}, [r0,:64]!
    vld1.64         {\db1}, [r1,:64], r3
.ifnb \lastdiff1
    vadd.s16        \acc1, \acc1, \lastdiff1
    vadd.s16        \acc2, \acc2, \lastdiff2
.endif
    vld1.64         {\da2}, [r0,:64]!
    vld1.64         {\db2}, [r1,:64], r3
    vsubl.u8        \diff1, \da1, \db1
    vsubl.u8        \diff2, \da2, \db2
.endm

.macro SQR_ACC_DOUBLE acc1 acc2 d0 d1 d2 d3 vmlal=vmlal.s16
    \vmlal          \acc1, \d0, \d0
    vmlal.s16       \acc1, \d1, \d1
    \vmlal          \acc2, \d2, \d2
    vmlal.s16       \acc2, \d3, \d3
.endm

.macro SQR_ACC acc d0 d1 vmlal=vmlal.s16
    \vmlal          \acc, \d0, \d0
    vmlal.s16       \acc, \d1, \d1
.endm

function pixel_var2_8x8_neon
    mov             r3,  #16
    DIFF_SUM        q0,  q10, d0,  d1,  d20, d21
    DIFF_SUM        q8,  q11, d16, d17, d22, d23
    SQR_ACC_DOUBLE  q1,  q13, d0,  d1,  d20, d21, vmull.s16
    DIFF_SUM        q9,  q12, d18, d19, d24, d25, q8,  q11, q0,  q10
    SQR_ACC_DOUBLE  q2,  q14, d16, d17, d22, d23, vmull.s16
.rept 2
    DIFF_SUM        q8,  q11, d16, d17, d22, d23, q9,  q12, q0,  q10
    SQR_ACC_DOUBLE  q1,  q13, d18, d19, d24, d25
    DIFF_SUM        q9,  q12, d18, d19, d24, d25, q8,  q11, q0,  q10
    SQR_ACC_DOUBLE  q2,  q14, d16, d17, d22, d23
.endr
    DIFF_SUM        q8,  q11, d16, d17, d22, d23, q9,  q12, q0,  q10
    SQR_ACC_DOUBLE  q1,  q13, d18, d19, d24, d25
    vadd.s16        q0,  q0,  q8
    vadd.s16        q10, q10, q11
    SQR_ACC_DOUBLE  q2,  q14, d16, d17, d22, d23

    vadd.s16        d0,  d0,  d1
    vadd.s16        d20, d20, d21
    vadd.s32        q1,  q1,  q2
    vadd.s32        q13, q13, q14
    vpaddl.s16      d0,  d0
    vpaddl.s16      d20, d20
    vadd.s32        d1,  d2,  d3
    vadd.s32        d26, d26, d27
    vpadd.s32       d0,  d0,  d20 @ sum
    vpadd.s32       d1,  d1,  d26 @ sqr
    vmul.s32        d0,  d0,  d0  @ sum*sum
    vshr.s32        d0,  d0,  #6
    vsub.s32        d0,  d1,  d0
    vpadd.s32       d0,  d0,  d0

    vmov            r0,  r1,  d0
    vst1.32         {d1}, [r2,:64]
    bx              lr
endfunc

function pixel_var2_8x16_neon
    mov             r3,  #16
    vld1.64         {d16}, [r0,:64]!
    vld1.64         {d17}, [r1,:64], r3
    vld1.64         {d18}, [r0,:64]!
    vld1.64         {d19}, [r1,:64], r3
    vsubl.u8        q0,  d16, d17
    vsubl.u8        q3,  d18, d19
    SQR_ACC         q1,  d0,  d1,   vmull.s16
    vld1.64         {d16}, [r0,:64]!
    mov             ip,  #15
    vld1.64         {d17}, [r1,:64], r3
    SQR_ACC         q2,  d6,  d7,   vmull.s16
1:  subs            ip,  ip,  #1
    vld1.64         {d18}, [r0,:64]!
    vsubl.u8        q10, d16, d17
    vld1.64         {d19}, [r1,:64], r3
    vadd.s16        q0,  q0,  q10
    SQR_ACC         q1,  d20, d21
    vsubl.u8        q11, d18, d19
    beq             2f
    vld1.64         {d16}, [r0,:64]!
    vadd.s16        q3,  q3,  q11
    vld1.64         {d17}, [r1,:64], r3
    SQR_ACC         q2,  d22, d23
    b               1b
2:
    vadd.s16        q3,  q3,  q11
    SQR_ACC         q2,  d22, d23

    vadd.s16        d0,  d0,  d1
    vadd.s16        d6,  d6,  d7
    vpaddl.s16      d0,  d0
    vpaddl.s16      d6,  d6
    vadd.s32        d2,  d2,  d3
    vadd.s32        d4,  d4,  d5
    vpadd.s32       d0,  d0,  d6 @ sum
    vpadd.s32       d2,  d2,  d4 @ sqr
    vmul.s32        d0,  d0,  d0 @ sum*sum
    vshr.s32        d0,  d0,  #7
    vsub.s32        d0,  d2,  d0
    vpadd.s32       d0,  d0,  d0

    vmov            r0,  r1,  d0
    vst1.32         {d2}, [r2,:64]
    bx              lr
endfunc

.macro LOAD_DIFF_8x4 q0 q1 q2 q3
    vld1.32     {d1}, [r2], r3
    vld1.32     {d0}, [r0,:64], r1
    vsubl.u8    \q0, d0,  d1
    vld1.32     {d3}, [r2], r3
    vld1.32     {d2}, [r0,:64], r1
    vsubl.u8    \q1, d2,  d3
    vld1.32     {d5}, [r2], r3
    vld1.32     {d4}, [r0,:64], r1
    vsubl.u8    \q2, d4,  d5
    vld1.32     {d7}, [r2], r3
    vld1.32     {d6}, [r0,:64], r1
    vsubl.u8    \q3, d6,  d7
.endm

function pixel_satd_4x4_neon
    vld1.32     {d1[]},  [r2], r3
    vld1.32     {d0[]},  [r0,:32], r1
    vld1.32     {d3[]},  [r2], r3
    vld1.32     {d2[]},  [r0,:32], r1
    vld1.32     {d1[1]}, [r2], r3
    vld1.32     {d0[1]}, [r0,:32], r1
    vld1.32     {d3[1]}, [r2], r3
    vld1.32     {d2[1]}, [r0,:32], r1
    vsubl.u8    q0,  d0,  d1
    vsubl.u8    q1,  d2,  d3

    SUMSUB_AB   q2, q3, q0, q1
    SUMSUB_ABCD d0, d2, d1, d3, d4, d5, d6, d7
    HADAMARD    1, sumsub, q2, q3, q0, q1
    HADAMARD    2, amax,   q0,,    q2, q3

    HORIZ_ADD   d0,  d0,  d1
    vmov.32     r0,  d0[0]
    bx          lr
endfunc

function pixel_satd_4x8_neon
    vld1.32     {d1[]},  [r2], r3
    vld1.32     {d0[]},  [r0,:32], r1
    vld1.32     {d3[]},  [r2], r3
    vld1.32     {d2[]},  [r0,:32], r1
    vld1.32     {d5[]},  [r2], r3
    vld1.32     {d4[]},  [r0,:32], r1
    vld1.32     {d7[]},  [r2], r3
    vld1.32     {d6[]},  [r0,:32], r1

    vld1.32     {d1[1]}, [r2], r3
    vld1.32     {d0[1]}, [r0,:32], r1
    vsubl.u8    q0,  d0,  d1
    vld1.32     {d3[1]}, [r2], r3
    vld1.32     {d2[1]}, [r0,:32], r1
    vsubl.u8    q1,  d2,  d3
    vld1.32     {d5[1]}, [r2], r3
    vld1.32     {d4[1]}, [r0,:32], r1
    vsubl.u8    q2,  d4,  d5
    vld1.32     {d7[1]}, [r2], r3
    SUMSUB_AB   q8,  q9,  q0,  q1
    vld1.32     {d6[1]}, [r0,:32], r1
    vsubl.u8    q3,  d6,  d7
    SUMSUB_AB   q10, q11, q2,  q3
    b           satd_4x8_8x4_end_neon
endfunc

function pixel_satd_8x4_neon
    vld1.64     {d1}, [r2], r3
    vld1.64     {d0}, [r0,:64], r1
    vsubl.u8    q0,  d0,  d1
    vld1.64     {d3}, [r2], r3
    vld1.64     {d2}, [r0,:64], r1
    vsubl.u8    q1,  d2,  d3
    vld1.64     {d5}, [r2], r3
    vld1.64     {d4}, [r0,:64], r1
    vsubl.u8    q2,  d4,  d5
    vld1.64     {d7}, [r2], r3
    SUMSUB_AB   q8,  q9,  q0,  q1
    vld1.64     {d6}, [r0,:64], r1
    vsubl.u8    q3,  d6,  d7
    SUMSUB_AB   q10, q11, q2,  q3
endfunc

function satd_4x8_8x4_end_neon, export=0
    vadd.s16    q0,  q8,  q10
    vadd.s16    q1,  q9,  q11
    vsub.s16    q2,  q8,  q10
    vsub.s16    q3,  q9,  q11

    vtrn.16     q0,  q1
    vadd.s16    q8,  q0,  q1
    vtrn.16     q2,  q3
    vsub.s16    q9,  q0,  q1
    vadd.s16    q10, q2,  q3
    vsub.s16    q11, q2,  q3
    vtrn.32     q8,  q10
    vabs.s16    q8,  q8
    vtrn.32     q9,  q11
    vabs.s16    q10, q10
    vabs.s16    q9,  q9
    vabs.s16    q11, q11
    vmax.u16    q0,  q8,  q10
    vmax.u16    q1,  q9,  q11

    vadd.u16    q0,  q0,  q1
    HORIZ_ADD   d0,  d0,  d1
    vmov.32     r0,  d0[0]
    bx          lr
endfunc

function pixel_satd_8x8_neon
    mov         ip,  lr

    bl satd_8x8_neon
    vadd.u16    q0,  q12, q13
    vadd.u16    q1,  q14, q15

    vadd.u16    q0,  q0,  q1
    HORIZ_ADD   d0,  d0,  d1
    mov         lr,  ip
    vmov.32     r0,  d0[0]
    bx          lr
endfunc

function pixel_satd_8x16_neon
    vpush       {d8-d11}
    mov         ip,  lr

    bl satd_8x8_neon
    vadd.u16    q4,  q12, q13
    vadd.u16    q5,  q14, q15

    bl satd_8x8_neon
    vadd.u16    q4,  q4,  q12
    vadd.u16    q5,  q5,  q13
    vadd.u16    q4,  q4,  q14
    vadd.u16    q5,  q5,  q15

    vadd.u16    q0,  q4,  q5
    HORIZ_ADD   d0,  d0,  d1
    vpop        {d8-d11}
    mov         lr,  ip
    vmov.32     r0,  d0[0]
    bx          lr
endfunc

function satd_8x8_neon, export=0
    LOAD_DIFF_8x4 q8,  q9,  q10, q11
    vld1.64     {d7}, [r2], r3
    SUMSUB_AB   q0,  q1,  q8,  q9
    vld1.64     {d6}, [r0,:64], r1
    vsubl.u8    q12, d6,  d7
    vld1.64     {d17}, [r2], r3
    SUMSUB_AB   q2,  q3,  q10, q11
    vld1.64     {d16}, [r0,:64], r1
    vsubl.u8    q13, d16, d17
    vld1.64     {d19}, [r2], r3
    SUMSUB_AB   q8,  q10, q0,  q2
    vld1.64     {d18}, [r0,:64], r1
    vsubl.u8    q14, d18, d19
    vld1.64     {d1}, [r2], r3
    SUMSUB_AB   q9,  q11, q1,  q3
    vld1.64     {d0}, [r0,:64], r1
    vsubl.u8    q15, d0,  d1
endfunc

// one vertical hadamard pass and two horizontal
function satd_8x4v_8x8h_neon, export=0
    SUMSUB_ABCD q0, q1, q2, q3, q12, q13, q14, q15
    vtrn.16     q8,  q9
    SUMSUB_AB   q12, q14, q0,  q2
    vtrn.16     q10, q11
    SUMSUB_AB   q13, q15, q1,  q3
    SUMSUB_AB   q0,  q1,  q8,  q9
    vtrn.16     q12, q13
    SUMSUB_AB   q2,  q3,  q10, q11
    vtrn.16     q14, q15
    SUMSUB_AB   q8,  q9,  q12, q13
    vtrn.32     q0,  q2
    SUMSUB_AB   q10, q11, q14, q15

    vtrn.32     q1,  q3
    ABS2        q0,  q2
    vtrn.32     q8,  q10
    ABS2        q1,  q3
    vtrn.32     q9,  q11
    ABS2        q8,  q10
    ABS2        q9,  q11
    vmax.s16    q12, q0,  q2
    vmax.s16    q13, q1,  q3
    vmax.s16    q14, q8,  q10
    vmax.s16    q15, q9,  q11
    bx          lr
endfunc

function pixel_satd_16x8_neon
    vpush       {d8-d11}
    mov         ip, lr

    bl          satd_16x4_neon
    vadd.u16    q4,  q12, q13
    vadd.u16    q5,  q14, q15

    bl          satd_16x4_neon
    vadd.u16    q4,  q4,  q12
    vadd.u16    q5,  q5,  q13
    vadd.u16    q4,  q4,  q14
    vadd.u16    q5,  q5,  q15

    vadd.u16    q0,  q4,  q5
    HORIZ_ADD   d0,  d0,  d1
    vpop        {d8-d11}
    mov         lr,  ip
    vmov.32     r0,  d0[0]
    bx          lr
endfunc

function pixel_satd_16x16_neon
    vpush       {d8-d11}
    mov         ip, lr

    bl          satd_16x4_neon
    vadd.u16    q4,  q12, q13
    vadd.u16    q5,  q14, q15

    bl          satd_16x4_neon
    vadd.u16    q4,  q4,  q12
    vadd.u16    q5,  q5,  q13
    vadd.u16    q4,  q4,  q14
    vadd.u16    q5,  q5,  q15

    bl          satd_16x4_neon
    vadd.u16    q4,  q4,  q12
    vadd.u16    q5,  q5,  q13
    vadd.u16    q4,  q4,  q14
    vadd.u16    q5,  q5,  q15

    bl          satd_16x4_neon
    vadd.u16    q4,  q4,  q12
    vadd.u16    q5,  q5,  q13
    vadd.u16    q4,  q4,  q14
    vadd.u16    q5,  q5,  q15

    vadd.u16    q0,  q4,  q5
    HORIZ_ADD   d0,  d0,  d1
    vpop        {d8-d11}
    mov         lr,  ip
    vmov.32     r0,  d0[0]
    bx          lr
endfunc

function satd_16x4_neon, export=0
    vld1.64     {d2-d3}, [r2], r3
    vld1.64     {d0-d1}, [r0,:128], r1
    vsubl.u8    q8,  d0,  d2
    vld1.64     {d6-d7}, [r2], r3
    vsubl.u8    q12, d1,  d3
    vld1.64     {d4-d5}, [r0,:128], r1
    vsubl.u8    q9,  d4,  d6
    vld1.64     {d2-d3}, [r2], r3
    vsubl.u8    q13, d5,  d7
    vld1.64     {d0-d1}, [r0,:128], r1
    vsubl.u8    q10, d0,  d2
    vld1.64     {d6-d7}, [r2], r3
    vsubl.u8    q14, d1,  d3
    vadd.s16    q0,  q8,  q9
    vld1.64     {d4-d5}, [r0,:128], r1
    vsub.s16    q1,  q8,  q9
    vsubl.u8    q11, d4,  d6
    vsubl.u8    q15, d5,  d7
    SUMSUB_AB   q2,  q3,  q10, q11
    SUMSUB_ABCD q8,  q10, q9,  q11, q0,  q2,  q1,  q3
    b           satd_8x4v_8x8h_neon
endfunc


function pixel_sa8d_8x8_neon
    mov             ip,  lr
    bl              sa8d_8x8_neon
    vadd.u16        q0,  q8,  q9
    HORIZ_ADD       d0,  d0,  d1
    mov             lr,  ip
    vmov.32         r0,  d0[0]
    add             r0,  r0,  #1
    lsr             r0,  r0,  #1
    bx              lr
endfunc

function pixel_sa8d_16x16_neon
    vpush           {d8-d11}
    mov             ip,  lr
    bl              sa8d_8x8_neon
    vpaddl.u16      q4,  q8
    vpaddl.u16      q5,  q9
    bl              sa8d_8x8_neon
    vpadal.u16      q4,  q8
    vpadal.u16      q5,  q9
    sub             r0,  r0,  r1,  lsl #4
    sub             r2,  r2,  r3,  lsl #4
    add             r0,  r0,  #8
    add             r2,  r2,  #8
    bl              sa8d_8x8_neon
    vpadal.u16      q4,  q8
    vpadal.u16      q5,  q9
    bl              sa8d_8x8_neon
    vpaddl.u16      q8,  q8
    vpaddl.u16      q9,  q9
    vadd.u32        q0,  q4,  q8
    vadd.u32        q1,  q5,  q9
    vadd.u32        q0,  q0,  q1
    vadd.u32        d0,  d0,  d1
    vpadd.u32       d0,  d0,  d0
    vpop            {d8-d11}
    mov             lr,  ip
    vmov.32         r0,  d0[0]
    add             r0,  r0,  #1
    lsr             r0,  r0,  #1
    bx              lr
endfunc

.macro HADAMARD4_V r1, r2, r3, r4, t1, t2, t3, t4
    SUMSUB_ABCD \t1, \t2, \t3, \t4, \r1, \r2, \r3, \r4
    SUMSUB_ABCD \r1, \r3, \r2, \r4, \t1, \t3, \t2, \t4
.endm

.macro integrated_satd dst, s0, s1, s2, s3
    vmov            q0,  \s0
    vmov            q1,  \s1
    vmov            q2,  \s2
    vmov            q3,  \s3

    vtrn.16         q0,  q1
    vtrn.16         q2,  q3

    SUMSUB_AB       q6,  q7,  q0,  q1
    SUMSUB_AB       q0,  q1,  q2,  q3

    vtrn.32         q6,  q0
    vtrn.32         q7,  q1

    vabs.s16        q6,  q6
    vabs.s16        q0,  q0
    vabs.s16        q7,  q7
    vabs.s16        q1,  q1

    vmax.u16        q6,  q6,  q0
    vmax.u16        q7,  q7,  q1

    vadd.i16        q6,  q6,  q7
    vpadal.u16      \dst,  q6
.endm

.macro sa8d_satd_8x8 satd=
function sa8d_\satd\()8x8_neon, export=0
    LOAD_DIFF_8x4   q8,  q9,  q10, q11
    vld1.64         {d7}, [r2], r3
    SUMSUB_AB       q0,  q1,  q8,  q9
    vld1.64         {d6}, [r0,:64], r1
    vsubl.u8        q12, d6,  d7
    vld1.64         {d17}, [r2], r3
    SUMSUB_AB       q2,  q3,  q10, q11
    vld1.64         {d16}, [r0,:64], r1
    vsubl.u8        q13, d16, d17
    vld1.64         {d19}, [r2], r3
    SUMSUB_AB       q8,  q10, q0,  q2
    vld1.64         {d18}, [r0,:64], r1
    vsubl.u8        q14, d18, d19
    vld1.64         {d1}, [r2], r3
    SUMSUB_AB       q9,  q11, q1,  q3
    vld1.64         {d0}, [r0,:64], r1
    vsubl.u8        q15, d0,  d1

    HADAMARD4_V     q12, q13, q14, q15,  q0,  q1,  q2,  q3

.ifc \satd, satd_
    integrated_satd q4,  q8,  q9,  q10, q11
    integrated_satd q4,  q12, q13, q14, q15
.endif

    SUMSUB_ABCD     q0,  q8,  q1,  q9,   q8,  q12, q9,  q13
    SUMSUB_AB       q2,  q10, q10, q14
    vtrn.16         q8,  q9
    SUMSUB_AB       q3,  q11, q11, q15
    vtrn.16         q0,  q1
    SUMSUB_AB       q12, q13, q8,  q9
    vtrn.16         q10, q11
    SUMSUB_AB       q8,  q9,  q0,  q1
    vtrn.16         q2,  q3
    SUMSUB_AB       q14, q15, q10, q11
    vadd.i16        q10, q2,  q3
    vtrn.32         q12, q14
    vsub.i16        q11, q2,  q3
    vtrn.32         q13, q15
    SUMSUB_AB       q0,  q2,  q12, q14
    vtrn.32         q8,  q10
    SUMSUB_AB       q1,  q3,  q13, q15
    vtrn.32         q9,  q11
    SUMSUB_AB       q12, q14, q8,  q10
    SUMSUB_AB       q13, q15, q9,  q11

    vswp            d1,  d24
    ABS2            q0,  q12
    vswp            d3,  d26
    ABS2            q1,  q13
    vswp            d5,  d28
    ABS2            q2,  q14
    vswp            d7,  d30
    ABS2            q3,  q15
    vmax.s16        q8,  q0,  q12
    vmax.s16        q9,  q1,  q13
    vmax.s16        q10, q2,  q14
    vmax.s16        q11, q3,  q15
    vadd.i16        q8,  q8,  q9
    vadd.i16        q9,  q10, q11
.ifc \satd, satd_
    vpadal.u16      q5,  q8
    vpadal.u16      q5,  q9
.endif
    bx              lr
endfunc
.endm

sa8d_satd_8x8
sa8d_satd_8x8 satd_

function pixel_sa8d_satd_16x16_neon
    push            {lr}
    vpush           {q4-q7}
    vmov.u32        q4,  #0
    vmov.u32        q5,  #0
    bl              sa8d_satd_8x8_neon
    bl              sa8d_satd_8x8_neon
    sub             r0,  r0,  r1,  lsl #4
    sub             r2,  r2,  r3,  lsl #4
    add             r0,  r0,  #8
    add             r2,  r2,  #8
    bl              sa8d_satd_8x8_neon
    bl              sa8d_satd_8x8_neon
    vadd.u32        d1,  d10, d11
    vadd.u32        d0,  d8,  d9
    vpadd.u32       d1,  d1,  d1
    vpadd.u32       d0,  d0,  d0
    vrshr.u32       d1,  d1,  #1
    vmov.32         r1,  d0[0]
    vmov.32         r0,  d1[0]
    vpop            {q4-q7}
    pop             {pc}
endfunc


.macro HADAMARD_AC w h
function pixel_hadamard_ac_\w\()x\h\()_neon
    vpush           {d8-d15}
    movrel          ip, mask_ac4
    vmov.i8         q4, #0
    // note: this assumes mask_ac8 is after mask_ac4 (so don't move it)
    vld1.64         {d12-d15}, [ip,:128]
    vmov.i8         q5, #0

    mov             ip,  lr
    bl              hadamard_ac_8x8_neon
.if \h > 8
    bl              hadamard_ac_8x8_neon
.endif
.if \w > 8
    sub             r0,  r0,  r1,  lsl #3
    add             r0,  r0,  #8
    bl              hadamard_ac_8x8_neon
.endif
.if \w * \h == 256
    sub             r0,  r0,  r1,  lsl #4
    bl              hadamard_ac_8x8_neon
.endif

    vadd.s32        d8,  d8,  d9
    vadd.s32        d10, d10, d11
    vpadd.s32       d0,  d8,  d10
    vpop            {d8-d15}
    mov             lr,  ip
    vmov            r0,  r1,  d0
    lsr             r0,  r0,  #1
    lsr             r1,  r1,  #2
    bx              lr
endfunc
.endm

HADAMARD_AC  8, 8
HADAMARD_AC  8, 16
HADAMARD_AC 16, 8
HADAMARD_AC 16, 16

// q4: satd  q5: sa8d  q6: mask_ac4  q7: mask_ac8
function hadamard_ac_8x8_neon, export=0
    vld1.64         {d2},  [r0,:64], r1
    vld1.64         {d3},  [r0,:64], r1
    vaddl.u8        q0,  d2,  d3
    vld1.64         {d6},  [r0,:64], r1
    vsubl.u8        q1,  d2,  d3
    vld1.64         {d7},  [r0,:64], r1
    vaddl.u8        q2,  d6,  d7
    vld1.64         {d18}, [r0,:64], r1
    vsubl.u8        q3,  d6,  d7
    vld1.64         {d19}, [r0,:64], r1
    vaddl.u8        q8,  d18, d19
    vld1.64         {d22}, [r0,:64], r1
    vsubl.u8        q9,  d18, d19
    vld1.64         {d23}, [r0,:64], r1

    SUMSUB_ABCD     q12, q14, q13, q15, q0,  q2,  q1,  q3
    vaddl.u8        q10, d22, d23
    vsubl.u8        q11, d22, d23
    vtrn.16         q12, q13
    SUMSUB_ABCD     q0,  q2,  q1,  q3,  q8,  q10, q9,  q11

    vtrn.16         q14, q15
    SUMSUB_AB       q8,  q9,  q12, q13
    vtrn.16         q0,  q1
    SUMSUB_AB       q10, q11, q14, q15
    vtrn.16         q2,  q3
    SUMSUB_AB       q12, q13, q0,  q1
    vtrn.32         q8,  q10
    SUMSUB_AB       q14, q15, q2,  q3
    vtrn.32         q9,  q11
    SUMSUB_AB       q0,  q2,  q8,  q10
    vtrn.32         q12, q14
    SUMSUB_AB       q1,  q3,  q9,  q11
    vtrn.32         q13, q15
    SUMSUB_ABCD     q8,  q10, q9,  q11, q12, q14, q13, q15

    vabs.s16        q12, q0
    vabs.s16        q13, q8
    vabs.s16        q15, q1
    vadd.s16        q12, q12, q13
    vabs.s16        q14, q2
    vand.s16        q12, q12, q6
    vabs.s16        q13, q3
    vadd.s16        q12, q12, q15
    vabs.s16        q15, q9
    vadd.s16        q12, q12, q14
    vabs.s16        q14, q10
    vadd.s16        q12, q12, q13
    vabs.s16        q13, q11
    vadd.s16        q12, q12, q15
    vsub.s16        q15, q11, q3
    vadd.s16        q12, q12, q14
    vadd.s16        q14, q11, q3
    vadd.s16        q12, q12, q13
    vsub.s16        q13, q10, q2
    vadd.s16        q2,  q10, q2
    vpadal.u16      q4,  q12

    SUMSUB_AB       q10, q11, q9,  q1
    SUMSUB_AB       q9,  q8,  q0,  q8
    vswp            d29, d30
    vabs.s16        q14, q14
    vabs.s16        q15, q15
    vswp            d5,  d26
    vabs.s16        q2,  q2
    vabs.s16        q13, q13
    vswp            d21, d22
    vabs.s16        q10, q10
    vabs.s16        q11, q11
    vmax.s16        q3,  q14, q15
    vmax.s16        q2,  q2,  q13
    vmax.s16        q1,  q10, q11
    vswp            d19, d16
    SUMSUB_AB       q14, q15, q9,  q8

    vadd.s16        q2,  q2,  q3
    vadd.s16        q2,  q2,  q1
    vand            q14, q14, q7
    vadd.s16        q2,  q2,  q2
    vabs.s16        q15, q15
    vabs.s16        q14, q14
    vadd.s16        q2,  q2,  q15
    vadd.s16        q2,  q2,  q14
    vpadal.u16      q5,  q2
    bx              lr
endfunc


.macro SSIM_ITER n ssa s12 ssb lastssa lasts12 lastssb da db dnext
    vld1.64     {\db}, [r2], r3
    vmull.u8    \ssa,  \da, \da
    vmull.u8    \s12,  \da, \db
.if \n == 1
    vpaddl.u16  q2,  \lastssa
    vpaddl.u16  q3,  \lasts12
    vaddl.u8    q0,  d0,  \da
.else
    vpadal.u16  q2,  \lastssa
    vpadal.u16  q3,  \lasts12
    vaddw.u8    q0,  q0,  \da
.endif
    vpadal.u16  q2,  \lastssb
.if \n < 3
    vld1.64     {\dnext}, [r0], r1
.endif
.if \n == 1
    vaddl.u8    q1,  d2,  \db
.else
    vaddw.u8    q1,  q1,  \db
.endif
    vmull.u8    \ssb, \db, \db
.endm

function pixel_ssim_4x4x2_core_neon
    ldr         ip, [sp]
    vld1.64     {d0}, [r0], r1
    vld1.64     {d2}, [r2], r3
    vmull.u8    q2,  d0,  d0
    vmull.u8    q3,  d0,  d2
    vld1.64     {d28}, [r0], r1
    vmull.u8    q15, d2,  d2

    SSIM_ITER 1, q8, q9, q14,  q2, q3, q15,  d28, d29, d26
    SSIM_ITER 2, q10,q11,q13,  q8, q9, q14,  d26, d27, d28
    SSIM_ITER 3, q8, q9, q15,  q10,q11,q13,  d28, d29

    vpadal.u16  q2,  q8
    vpaddl.u16  q0,  q0
    vpaddl.u16  q1,  q1
    vpadal.u16  q2,  q15
    vpadal.u16  q3,  q9

    vpadd.u32   d0,  d0,  d1
    vpadd.u32   d1,  d2,  d3
    vpadd.u32   d2,  d4,  d5
    vpadd.u32   d3,  d6,  d7

    vst4.32     {d0-d3}, [ip]
    bx          lr
endfunc

// FIXME: see about doing 16x16 -> 32 bit multiplies for s1/s2
function pixel_ssim_end4_neon
    vld1.32     {d16-d19}, [r0,:128]!
    vld1.32     {d20-d23}, [r1,:128]!
    vadd.s32    q0,  q8,  q10
    vadd.s32    q1,  q9,  q11
    vld1.32     {d24-d27}, [r0,:128]!
    vadd.s32    q0,  q0,  q1
    vld1.32     {d28-d31}, [r1,:128]!
    vadd.s32    q2,  q12, q14
    vadd.s32    q3,  q13, q15
    vld1.32     {d16-d17}, [r0,:128]
    vadd.s32    q1,  q1,  q2
    vld1.32     {d18-d19}, [r1,:128]
    vadd.s32    q8,  q8,  q9
    vadd.s32    q2,  q2,  q3
    vadd.s32    q3,  q3,  q8

    vtrn.32     q0,  q1
    vtrn.32     q2,  q3
    vswp        d1,  d4
    vswp        d3,  d6

//  s1=q0, s2=q1, ss=q2, s12=q3
    vmul.s32    q8,  q0,  q1    // s1*s2
    vmul.s32    q0,  q0,  q0
    vmla.s32    q0,  q1,  q1    // s1*s1 + s2*s2

    vshl.s32    q3,  q3,  #7
    vshl.s32    q2,  q2,  #6
    vadd.s32    q1,  q8,  q8

    mov         r3, #416        // ssim_c1 = .01*.01*255*255*64
    movconst    ip, 235963      // ssim_c2 = .03*.03*255*255*64*63
    vdup.32     q14, r3
    vdup.32     q15, ip

    vsub.s32    q2,  q2,  q0    // vars
    vsub.s32    q3,  q3,  q1    // covar*2
    vadd.s32    q0,  q0,  q14
    vadd.s32    q2,  q2,  q15
    vadd.s32    q1,  q1,  q14
    vadd.s32    q3,  q3,  q15

    vcvt.f32.s32    q0,  q0
    vcvt.f32.s32    q2,  q2
    vcvt.f32.s32    q1,  q1
    vcvt.f32.s32    q3,  q3

    vmul.f32    q0,  q0,  q2
    vmul.f32    q1,  q1,  q3

    cmp         r2,  #4

    vdiv.f32    s0,  s4,  s0
    vdiv.f32    s1,  s5,  s1
    vdiv.f32    s2,  s6,  s2
    vdiv.f32    s3,  s7,  s3

    beq         ssim_skip
    movrel      r3,  mask_ff
    sub         r3,  r3,  r2,  lsl #2
    vld1.64     {d6-d7}, [r3]
    vand        q0,  q0,  q3
ssim_skip:
    vadd.f32    d0,  d0,  d1
    vpadd.f32   d0,  d0,  d0
    vmov.32     r0,  d0[0]
    bx          lr
endfunc
