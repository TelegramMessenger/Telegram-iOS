/*****************************************************************************
 * predict.S: aarch64 intra prediction
 *****************************************************************************
 * Copyright (C) 2009-2022 x264 project
 *
 * Authors: David Conrad <lessen42@gmail.com>
 *          Mans Rullgard <mans@mansr.com>
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

const p8weight, align=4
    .short      1, 2, 3, 4, 1, 2, 3, 4
endconst
const p16weight, align=4
    .short      1, 2, 3, 4, 5, 6, 7, 8
endconst

.macro ldcol.8  vd,  xn,  xm,  n=8,  hi=0
.if \n == 8 || \hi == 0
    ld1        {\vd\().b}[0], [\xn], \xm
    ld1        {\vd\().b}[1], [\xn], \xm
    ld1        {\vd\().b}[2], [\xn], \xm
    ld1        {\vd\().b}[3], [\xn], \xm
.endif
.if \n == 8 || \hi == 1
    ld1        {\vd\().b}[4], [\xn], \xm
    ld1        {\vd\().b}[5], [\xn], \xm
    ld1        {\vd\().b}[6], [\xn], \xm
    ld1        {\vd\().b}[7], [\xn], \xm
.endif
.endm

.macro ldcol.16  vd,  xn,  xm
    ldcol.8     \vd, \xn, \xm
    ld1        {\vd\().b}[ 8], [\xn], \xm
    ld1        {\vd\().b}[ 9], [\xn], \xm
    ld1        {\vd\().b}[10], [\xn], \xm
    ld1        {\vd\().b}[11], [\xn], \xm
    ld1        {\vd\().b}[12], [\xn], \xm
    ld1        {\vd\().b}[13], [\xn], \xm
    ld1        {\vd\().b}[14], [\xn], \xm
    ld1        {\vd\().b}[15], [\xn], \xm
.endm


function predict_4x4_h_aarch64, export=1
    ldurb   w1,  [x0, #0*FDEC_STRIDE-1]
    mov     w5,  #0x01010101
    ldrb    w2,  [x0, #1*FDEC_STRIDE-1]
    ldrb    w3,  [x0, #2*FDEC_STRIDE-1]
    mul     w1,  w1,  w5
    ldrb    w4,  [x0, #3*FDEC_STRIDE-1]
    mul     w2,  w2,  w5
    str     w1,  [x0, #0*FDEC_STRIDE]
    mul     w3,  w3,  w5
    str     w2,  [x0, #1*FDEC_STRIDE]
    mul     w4,  w4,  w5
    str     w3,  [x0, #2*FDEC_STRIDE]
    str     w4,  [x0, #3*FDEC_STRIDE]
    ret
endfunc

function predict_4x4_v_aarch64, export=1
    ldur    w1,  [x0, #0 - 1 * FDEC_STRIDE]
    str     w1,  [x0, #0 + 0 * FDEC_STRIDE]
    str     w1,  [x0, #0 + 1 * FDEC_STRIDE]
    str     w1,  [x0, #0 + 2 * FDEC_STRIDE]
    str     w1,  [x0, #0 + 3 * FDEC_STRIDE]
    ret
endfunc

function predict_4x4_dc_neon, export=1
    sub         x1,  x0,  #FDEC_STRIDE
    ldurb       w4,  [x0, #-1 + 0 * FDEC_STRIDE]
    ldrb        w5,  [x0, #-1 + 1 * FDEC_STRIDE]
    ldrb        w6,  [x0, #-1 + 2 * FDEC_STRIDE]
    ldrb        w7,  [x0, #-1 + 3 * FDEC_STRIDE]
    add         w4,  w4,  w5
    ldr         s0, [x1]
    add         w6,  w6,  w7
    uaddlv      h0,  v0.8b
    add         w4,  w4,  w6
    dup         v0.4h,  v0.h[0]
    dup         v1.4h,  w4
    add         v0.4h,  v0.4h,  v1.4h
    rshrn       v0.8b,  v0.8h,  #3
    str         s0,  [x0]
    str         s0,  [x0, #1 * FDEC_STRIDE]
    str         s0,  [x0, #2 * FDEC_STRIDE]
    str         s0,  [x0, #3 * FDEC_STRIDE]
    ret
endfunc

function predict_4x4_dc_top_neon, export=1
    sub         x1,  x0,  #FDEC_STRIDE
    ldr         s0, [x1]
    uaddlv      h0,  v0.8b
    dup         v0.4h,  v0.h[0]
    rshrn       v0.8b,  v0.8h,  #2
    str         s0,  [x0]
    str         s0,  [x0, #1 * FDEC_STRIDE]
    str         s0,  [x0, #2 * FDEC_STRIDE]
    str         s0,  [x0, #3 * FDEC_STRIDE]
    ret
    ret
endfunc

function predict_4x4_ddr_neon, export=1
    sub         x1,  x0,  #FDEC_STRIDE+1
    mov         x7,  #FDEC_STRIDE
    ld1        {v0.8b}, [x1], x7            // # -FDEC_STRIDE-1
    ld1r       {v1.8b}, [x1], x7            // #0*FDEC_STRIDE-1
    ld1r       {v2.8b}, [x1], x7            // #1*FDEC_STRIDE-1
    ext         v0.8b,  v1.8b,  v0.8b,  #7
    ld1r       {v3.8b}, [x1], x7            // #2*FDEC_STRIDE-1
    ext         v0.8b,  v2.8b,  v0.8b,  #7  // a
    ld1r       {v4.8b}, [x1], x7            // #3*FDEC_STRIDE-1
    ext         v1.8b,  v3.8b,  v0.8b,  #7  // b
    ext         v2.8b,  v4.8b,  v1.8b,  #7  // c
    uaddl       v0.8h,  v0.8b,  v1.8b
    uaddl       v1.8h,  v1.8b,  v2.8b
    add         v0.8h,  v0.8h,  v1.8h
    rshrn       v0.8b,  v0.8h,  #2

    ext         v3.8b,  v0.8b, v0.8b,  #3
    ext         v2.8b,  v0.8b, v0.8b,  #2
    ext         v1.8b,  v0.8b, v0.8b,  #1

    str         s3,  [x0], #FDEC_STRIDE
    str         s2,  [x0], #FDEC_STRIDE
    str         s1,  [x0], #FDEC_STRIDE
    str         s0,  [x0]
    ret
endfunc

function predict_4x4_ddl_neon, export=1
    sub         x0,  x0,  #FDEC_STRIDE
    mov         x7,  #FDEC_STRIDE
    ld1        {v0.8b}, [x0],  x7
    dup         v3.8b,  v0.b[7]
    ext         v1.8b,  v0.8b,  v0.8b,  #1
    ext         v2.8b,  v0.8b,  v3.8b,  #2
    uhadd       v0.8b,  v0.8b,  v2.8b
    urhadd      v0.8b,  v0.8b,  v1.8b
    str         s0,  [x0], #FDEC_STRIDE
    ext         v1.8b,  v0.8b,  v0.8b,  #1
    ext         v2.8b,  v0.8b,  v0.8b,  #2
    str         s1,  [x0], #FDEC_STRIDE
    ext         v3.8b,  v0.8b,  v0.8b,  #3
    str         s2,  [x0], #FDEC_STRIDE
    str         s3,  [x0]
    ret
endfunc

function predict_8x8_dc_neon, export=1
    mov         x7,  #FDEC_STRIDE
    ld1        {v0.16b}, [x1], #16
    ld1        {v1.8b},  [x1]
    ext         v0.16b, v0.16b, v0.16b, #7
    uaddlv      h1,  v1.8b
    uaddlv      h0,  v0.8b
    add         v0.8h,  v0.8h,  v1.8h
    dup         v0.8h,  v0.h[0]
    rshrn       v0.8b,  v0.8h,  #4
.rept 8
    st1        {v0.8b}, [x0], x7
.endr
    ret
endfunc

function predict_8x8_h_neon, export=1
    mov         x7,  #FDEC_STRIDE
    ld1        {v16.16b}, [x1]
    dup         v0.8b, v16.b[14]
    dup         v1.8b, v16.b[13]
    st1        {v0.8b}, [x0], x7
    dup         v2.8b, v16.b[12]
    st1        {v1.8b}, [x0], x7
    dup         v3.8b, v16.b[11]
    st1        {v2.8b}, [x0], x7
    dup         v4.8b, v16.b[10]
    st1        {v3.8b}, [x0], x7
    dup         v5.8b, v16.b[9]
    st1        {v4.8b}, [x0], x7
    dup         v6.8b, v16.b[8]
    st1        {v5.8b}, [x0], x7
    dup         v7.8b, v16.b[7]
    st1        {v6.8b}, [x0], x7
    st1        {v7.8b}, [x0], x7
    ret
endfunc

function predict_8x8_v_neon, export=1
    add         x1,  x1,  #16
    mov         x7,  #FDEC_STRIDE
    ld1        {v0.8b}, [x1]
.rept 8
    st1        {v0.8b}, [x0], x7
.endr
    ret
endfunc

function predict_8x8_ddl_neon, export=1
    add         x1,  x1,  #16
    mov         x7,  #FDEC_STRIDE
    ld1        {v0.16b}, [x1]
    movi        v3.16b, #0
    dup         v2.16b, v0.b[15]
    ext         v4.16b, v3.16b, v0.16b, #15
    ext         v2.16b, v0.16b, v2.16b, #1
    uhadd       v4.16b, v4.16b, v2.16b
    urhadd      v0.16b, v0.16b, v4.16b
    ext         v1.16b, v0.16b, v0.16b, #1
    ext         v2.16b, v0.16b, v0.16b, #2
    st1        {v1.8b}, [x0], x7
    ext         v3.16b, v0.16b, v0.16b, #3
    st1        {v2.8b}, [x0], x7
    ext         v4.16b, v0.16b, v0.16b, #4
    st1        {v3.8b}, [x0], x7
    ext         v5.16b, v0.16b, v0.16b, #5
    st1        {v4.8b}, [x0], x7
    ext         v6.16b, v0.16b, v0.16b, #6
    st1        {v5.8b}, [x0], x7
    ext         v7.16b, v0.16b, v0.16b, #7
    st1        {v6.8b}, [x0], x7
    ext         v0.16b, v0.16b, v0.16b, #8
    st1        {v7.8b}, [x0], x7
    st1        {v0.8b}, [x0], x7
    ret
endfunc

function predict_8x8_ddr_neon, export=1
    ld1        {v0.16b,v1.16b}, [x1]
    ext         v2.16b, v0.16b, v1.16b, #7
    ext         v4.16b, v0.16b, v1.16b, #9
    ext         v3.16b, v0.16b, v1.16b, #8

    uhadd       v2.16b, v2.16b, v4.16b
    urhadd      v7.16b, v3.16b, v2.16b

    add         x0,  x0,  #7*FDEC_STRIDE
    mov         x7,  #-1*FDEC_STRIDE

    ext         v6.16b, v7.16b, v7.16b, #1
    st1        {v7.8b},  [x0], x7
    ext         v5.16b, v7.16b, v7.16b, #2
    st1        {v6.8b},  [x0], x7
    ext         v4.16b, v7.16b, v7.16b, #3
    st1        {v5.8b},  [x0], x7
    ext         v3.16b, v7.16b, v7.16b, #4
    st1        {v4.8b},  [x0], x7
    ext         v2.16b, v7.16b, v7.16b, #5
    st1        {v3.8b},  [x0], x7
    ext         v1.16b, v7.16b, v7.16b, #6
    st1        {v2.8b},  [x0], x7
    ext         v0.16b, v7.16b, v7.16b, #7
    st1        {v1.8b},  [x0], x7
    st1        {v0.8b},  [x0], x7
    ret
endfunc

function predict_8x8_vl_neon, export=1
    add         x1,  x1,  #16
    mov         x7, #FDEC_STRIDE

    ld1        {v0.16b}, [x1]
    ext         v1.16b, v1.16b, v0.16b, #15
    ext         v2.16b, v0.16b, v2.16b, #1

    uhadd       v1.16b, v1.16b, v2.16b
    urhadd      v3.16b, v0.16b, v2.16b

    urhadd      v0.16b, v0.16b, v1.16b

    ext        v4.16b, v0.16b, v0.16b, #1
    st1        {v3.8b}, [x0], x7
    ext        v5.16b, v3.16b, v3.16b, #1
    st1        {v4.8b}, [x0], x7
    ext        v6.16b, v0.16b, v0.16b, #2
    st1        {v5.8b}, [x0], x7
    ext        v7.16b, v3.16b, v3.16b, #2
    st1        {v6.8b}, [x0], x7
    ext        v4.16b, v0.16b, v0.16b, #3
    st1        {v7.8b}, [x0], x7
    ext        v5.16b, v3.16b, v3.16b, #3
    st1        {v4.8b}, [x0], x7
    ext        v6.16b, v0.16b, v0.16b, #4
    st1        {v5.8b}, [x0], x7
    st1        {v6.8b}, [x0], x7
    ret
endfunc

function predict_8x8_vr_neon, export=1
    add         x1,  x1,  #8
    mov         x7,  #FDEC_STRIDE
    ld1        {v2.16b}, [x1]

    ext         v1.16b, v2.16b, v2.16b, #14
    ext         v0.16b, v2.16b, v2.16b, #15

    uhadd       v3.16b, v2.16b, v1.16b
    urhadd      v2.16b, v2.16b, v0.16b
    urhadd      v0.16b, v0.16b, v3.16b

    ext         v1.16b, v2.16b, v2.16b, #8
    uzp1        v2.8b,  v0.8b,  v0.8b
    uzp2        v3.8b,  v0.8b,  v0.8b
    ext         v0.16b, v0.16b, v0.16b, #8

    st1        {v1.8b}, [x0], x7
    st1        {v0.8b}, [x0], x7
    ext         v4.8b, v3.8b, v1.8b, #7
    ext         v5.8b, v2.8b, v0.8b, #7
    st1        {v4.8b}, [x0], x7
    st1        {v5.8b}, [x0], x7
    ext         v6.8b, v3.8b, v1.8b, #6
    ext         v7.8b, v2.8b, v0.8b, #6
    st1        {v6.8b}, [x0], x7
    st1        {v7.8b}, [x0], x7
    ext         v1.8b, v3.8b, v1.8b, #5
    ext         v0.8b, v2.8b, v0.8b, #5
    st1        {v1.8b}, [x0], x7
    st1        {v0.8b}, [x0], x7
    ret
endfunc

function predict_8x8_hd_neon, export=1
    add         x1,  x1,  #7
    mov         x7, #FDEC_STRIDE

    ld1        {v1.16b}, [x1]
    ext         v3.16b, v1.16b, v1.16b, #1
    ext         v2.16b, v1.16b, v1.16b, #2

    urhadd      v4.16b, v1.16b, v3.16b

    uhadd       v1.16b, v1.16b, v2.16b
    urhadd      v0.16b, v1.16b, v3.16b

    zip1        v16.8b, v4.8b,  v0.8b
    zip2        v17.8b, v4.8b,  v0.8b
    ext         v7.16b, v0.16b, v0.16b, #8

    ext         v0.8b,  v17.8b, v7.8b,  #6
    ext         v1.8b,  v17.8b, v7.8b,  #4
    st1        {v0.8b},  [x0], x7
    ext         v2.8b,  v17.8b, v7.8b,  #2
    st1        {v1.8b},  [x0], x7
    st1        {v2.8b},  [x0], x7
    ext         v3.8b,  v16.8b, v17.8b, #6
    st1        {v17.8b}, [x0], x7
    ext         v4.8b,  v16.8b, v17.8b, #4
    st1        {v3.8b},  [x0], x7
    ext         v5.8b,  v16.8b, v17.8b, #2
    st1        {v4.8b},  [x0], x7
    st1        {v5.8b},  [x0], x7
    st1        {v16.8b}, [x0], x7

    ret
endfunc

function predict_8x8_hu_neon, export=1
    add         x1,  x1,  #7
    mov         x7,  #FDEC_STRIDE
    ld1        {v7.8b}, [x1]
    dup         v6.8b,  v7.b[0]
    rev64       v7.8b,  v7.8b

    ext         v4.8b,  v7.8b,  v6.8b,  #2
    ext         v2.8b,  v7.8b,  v6.8b,  #1

    uhadd       v5.8b,  v7.8b,  v4.8b
    urhadd      v0.8b,  v2.8b,  v7.8b
    urhadd      v1.8b,  v5.8b,  v2.8b

    zip1        v16.8b, v0.8b,  v1.8b
    zip2        v17.8b, v0.8b,  v1.8b

    dup         v18.4h, v17.h[3]

    ext         v0.8b,  v16.8b, v17.8b, #2
    ext         v1.8b,  v16.8b, v17.8b, #4
    ext         v2.8b,  v16.8b, v17.8b, #6
    st1        {v16.8b}, [x0], x7
    st1        {v0.8b},  [x0], x7
    st1        {v1.8b},  [x0], x7
    st1        {v2.8b},  [x0], x7

    ext         v4.8b,  v17.8b, v18.8b, #2
    ext         v5.8b,  v17.8b, v18.8b, #4
    ext         v6.8b,  v17.8b, v18.8b, #6
    st1        {v17.8b}, [x0], x7
    st1        {v4.8b},  [x0], x7
    st1        {v5.8b},  [x0], x7
    st1        {v6.8b},  [x0]
    ret
endfunc


function predict_8x8c_dc_top_neon, export=1
    sub         x2,  x0,  #FDEC_STRIDE
    mov         x1,  #FDEC_STRIDE
    ld1        {v0.8b},  [x2]
    uaddlp      v0.4h,  v0.8b
    addp        v0.4h,  v0.4h,  v0.4h
    rshrn       v0.8b,  v0.8h,  #2
    dup         v3.8b,  v0.b[1]
    dup         v2.8b,  v0.b[0]
    transpose   v0.2s,  v1.2s,  v2.2s,  v3.2s
    b           pred8x8c_dc_end
endfunc

function predict_8x8c_dc_left_neon, export=1
    ldurb       w2,  [x0, #0 * FDEC_STRIDE - 1]
    ldrb        w3,  [x0, #1 * FDEC_STRIDE - 1]
    ldrb        w4,  [x0, #2 * FDEC_STRIDE - 1]
    ldrb        w5,  [x0, #3 * FDEC_STRIDE - 1]
    mov         x1,  #FDEC_STRIDE
    add         w2,  w2,  w3
    add         w3,  w4,  w5
    ldrb        w6,  [x0, #4 * FDEC_STRIDE - 1]
    ldrb        w7,  [x0, #5 * FDEC_STRIDE - 1]
    ldrb        w8,  [x0, #6 * FDEC_STRIDE - 1]
    ldrb        w9,  [x0, #7 * FDEC_STRIDE - 1]
    add         w6,  w6,  w7
    add         w7,  w8,  w9
    add         w2,  w2,  w3
    add         w6,  w6,  w7
    dup         v0.8h,  w2
    dup         v1.8h,  w6
    rshrn       v0.8b,  v0.8h,  #2
    rshrn       v1.8b,  v1.8h,  #2
    b           pred8x8c_dc_end
endfunc

function predict_8x8c_dc_neon, export=1
    mov         x1,  #FDEC_STRIDE
    sub         x2,  x0,  #FDEC_STRIDE
    ldurb       w10, [x0, #0 * FDEC_STRIDE - 1]
    ldrb        w11, [x0, #1 * FDEC_STRIDE - 1]
    ldrb        w12, [x0, #2 * FDEC_STRIDE - 1]
    ldrb        w13, [x0, #3 * FDEC_STRIDE - 1]
    add         w10, w10, w11
    ldrb        w4,  [x0, #4 * FDEC_STRIDE - 1]
    ldrb        w5,  [x0, #5 * FDEC_STRIDE - 1]
    add         w12, w12, w13
    ldrb        w6,  [x0, #6 * FDEC_STRIDE - 1]
    ldrb        w7,  [x0, #7 * FDEC_STRIDE - 1]
    add         w4,  w4,  w5
    add         w6,  w6,  w7
    add         w10, w10, w12, lsl #16
    add         w4,  w4,  w6,  lsl #16
    ld1        {v0.8b},  [x2]
    add         x10, x10, x4,  lsl #32
    uaddlp      v0.4h,  v0.8b  // s0, s1
    mov         v1.d[0],  x10  // s2, s3
    add         v3.4h,  v0.4h,  v1.4h
    addp        v0.4h,  v0.4h,  v1.4h // s0, s1, s2, s3
    addp        v1.4h,  v3.4h,  v3.4h // s0+s2, s1+s3, s0+s2, s1+s3
    uzp2        v0.4h,  v0.4h,  v0.4h // s1,    s3,    s1,    s3
    uzp1        v1.2d,  v1.2d,  v1.2d
    uzp1        v0.2d,  v0.2d,  v0.2d
    rshrn       v3.8b,  v1.8h,  #3
    rshrn       v2.8b,  v0.8h,  #2
    uzp1        v0.8b,  v3.8b,  v2.8b
    uzp2        v1.8b,  v2.8b,  v3.8b
pred8x8c_dc_end:
    add         x2,  x0,  #2 * FDEC_STRIDE
    add         x4,  x0,  #4 * FDEC_STRIDE
    add         x5,  x0,  #6 * FDEC_STRIDE
    st1        {v0.8b}, [x0], x1
    st1        {v0.8b}, [x2], x1
    st1        {v0.8b}, [x0]
    st1        {v0.8b}, [x2]
    st1        {v1.8b}, [x4], x1
    st1        {v1.8b}, [x5], x1
    st1        {v1.8b}, [x4]
    st1        {v1.8b}, [x5]
    ret
endfunc

function predict_8x8c_h_neon, export=1
    sub         x1,  x0,  #1
    mov         x7,  #FDEC_STRIDE
.rept 4
    ld1r       {v0.8b}, [x1], x7
    ld1r       {v1.8b}, [x1], x7
    st1        {v0.8b}, [x0], x7
    st1        {v1.8b}, [x0], x7
.endr
    ret
endfunc

function predict_8x8c_v_aarch64, export=1
    ldur        x1,  [x0, #-FDEC_STRIDE]
.irp c, 0,1,2,3,4,5,6,7
    str         x1,  [x0, #\c * FDEC_STRIDE]
.endr
    ret
endfunc

function predict_8x8c_p_neon, export=1
    sub         x3,  x0,  #FDEC_STRIDE
    mov         x1,  #FDEC_STRIDE
    add         x2,  x3,  #4
    sub         x3,  x3,  #1
    ld1        {v0.s}[0], [x3]
    ld1        {v2.s}[0], [x2], x1
    ldcol.8     v0,  x3,  x1,  4,  hi=1
    add         x3,  x3,  x1
    ldcol.8     v3,  x3,  x1,  4
    movrel      x4,  p8weight
    movrel      x5,  p16weight
    uaddl       v4.8h,  v2.8b,  v3.8b
    rev32       v0.8b,  v0.8b
    trn1        v2.2s,  v2.2s,  v3.2s
    ld1        {v7.8h}, [x4]
    usubl       v2.8h,  v2.8b,  v0.8b
    mul         v2.8h,  v2.8h,  v7.8h
    ld1        {v0.8h}, [x5]
    saddlp      v2.4s,  v2.8h
    addp        v2.4s,  v2.4s,  v2.4s
    shl         v3.2s,  v2.2s,  #4
    add         v2.2s,  v2.2s,  v3.2s
    rshrn       v5.4h,  v2.4s,  #5    // b, c, x, x
    addp        v2.4h,  v5.4h,  v5.4h
    shl         v3.4h,  v2.4h,  #2
    sub         v3.4h,  v3.4h,  v2.4h // 3 * (b + c)
    rev64       v4.4h,  v4.4h
    add         v4.4h,  v4.4h,  v0.4h
    shl         v2.4h,  v4.4h,  #4              // a
    sub         v2.4h,  v2.4h,  v3.4h           // a - 3 * (b + c) + 16
    ext         v0.16b, v0.16b, v0.16b, #14
    sub         v6.4h,  v5.4h,  v3.4h
    mov         v0.h[0],  wzr
    mul         v0.8h,  v0.8h,  v5.h[0]         // 0,1,2,3,4,5,6,7 * b
    dup         v1.8h,  v2.h[0]                 // pix
    dup         v2.8h,  v5.h[1]                 // c
    add         v1.8h,  v1.8h,  v0.8h           // pix + x*b
    mov         x3,  #8
1:
    subs        x3,  x3,  #1
    sqshrun     v0.8b,  v1.8h,  #5
    add         v1.8h,  v1.8h,  v2.8h
    st1        {v0.8b}, [x0], x1
    b.ne        1b
    ret
endfunc


.macro loadsum4 wd, t1, t2, t3, x, idx
  .if \idx == 0
    ldurb       \wd,  [\x, #(\idx + 0) * FDEC_STRIDE - 1]
  .else
    ldrb        \wd,  [\x, #(\idx + 0) * FDEC_STRIDE - 1]
  .endif
    ldrb        \t1,  [\x, #(\idx + 1) * FDEC_STRIDE - 1]
    ldrb        \t2,  [\x, #(\idx + 2) * FDEC_STRIDE - 1]
    ldrb        \t3,  [\x, #(\idx + 3) * FDEC_STRIDE - 1]
    add         \wd,  \wd,  \t1
    add         \t1,  \t2,  \t3
    add         \wd,  \wd,  \t1
.endm

function predict_8x16c_h_neon, export=1
    sub         x2,  x0,  #1
    add         x3,  x0,  #FDEC_STRIDE - 1
    mov         x7,  #2 * FDEC_STRIDE
    add         x1,  x0,  #FDEC_STRIDE
.rept 4
    ld1r       {v0.8b}, [x2], x7
    ld1r       {v1.8b}, [x3], x7
    ld1r       {v2.8b}, [x2], x7
    ld1r       {v3.8b}, [x3], x7
    st1        {v0.8b}, [x0], x7
    st1        {v1.8b}, [x1], x7
    st1        {v2.8b}, [x0], x7
    st1        {v3.8b}, [x1], x7
.endr
    ret
endfunc

function predict_8x16c_v_neon, export=1
    sub         x1,  x0,  #FDEC_STRIDE
    mov         x2,  #2 * FDEC_STRIDE
    ld1        {v0.8b}, [x1], x2
.rept 8
    st1        {v0.8b}, [x0], x2
    st1        {v0.8b}, [x1], x2
.endr
    ret
endfunc

function predict_8x16c_p_neon, export=1
    movrel      x4,  p16weight
    ld1        {v17.8h}, [x4]
    sub         x3,  x0,  #FDEC_STRIDE
    mov         x1,  #FDEC_STRIDE
    add         x2,  x3,  #4
    sub         x3,  x3,  #1

    ld1        {v0.8b}, [x3]
    ld1        {v2.8b}, [x2], x1
    ldcol.8     v1,  x3,  x1
    add         x3,  x3,  x1
    ldcol.8     v3,  x3,  x1
    ext         v4.8b,  v2.8b,  v2.8b,  #3
    ext         v5.8b,  v3.8b,  v3.8b,  #7
    rev32       v0.8b,  v0.8b
    rev64       v1.8b,  v1.8b

    uaddl       v4.8h,  v5.8b,  v4.8b // a * 1/16

    usubl       v2.8h,  v2.8b,  v0.8b
    mul         v2.8h,  v2.8h,  v17.8h
    saddlp      v2.4s,  v2.8h
    addp        v2.4s,  v2.4s,  v2.4s  // H

    usubl       v3.8h,  v3.8b,  v1.8b
    mul         v3.8h,  v3.8h,  v17.8h
    saddlp      v3.4s,  v3.8h
    addp        v3.4s,  v3.4s,  v3.4s
    addp        v3.4s,  v3.4s,  v3.4s  // V

    ext         v17.16b, v17.16b, v17.16b, #14

    shl         v4.4h,  v4.4h,  #4     // a
    shl         v6.2s,  v2.2s,  #4     // 16 * H
    shl         v7.2s,  v3.2s,  #2     // 4 * V
    add         v2.2s,  v2.2s,  v6.2s  // 17 * H
    add         v3.2s,  v3.2s,  v7.2s  // 5 * V
    rshrn       v2.4h,  v2.4s,  #5     // b
    rshrn       v3.4h,  v3.4s,  #6     // c

    mov         v17.h[0],  wzr

    sub         v4.4h,  v4.4h,  v2.4h  // a - b
    shl         v6.4h,  v2.4h,  #1     // 2 * b
    add         v4.4h,  v4.4h,  v3.4h  // a - b + c
    shl         v7.4h,  v3.4h,  #3     // 8 * c
    sub         v4.4h,  v4.4h,  v6.4h  // a - 3b + c
    sub         v4.4h,  v4.4h,  v7.4h  // a - 3b - 7c

    mul         v0.8h,  v17.8h, v2.h[0]         // 0,1,2,3,4,5,6,7 * b
    dup         v1.8h,  v4.h[0]                 // i00
    dup         v2.8h,  v3.h[0]                 // c
    add         v1.8h,  v1.8h,  v0.8h           // pix + {0..7}*b
    mov         x3,  #16
1:
    subs        x3,  x3,  #2
    sqrshrun    v4.8b,  v1.8h,  #5
    add         v1.8h,  v1.8h,  v2.8h
    sqrshrun    v5.8b,  v1.8h,  #5
    st1        {v4.8b}, [x0], x1
    add         v1.8h,  v1.8h,  v2.8h
    st1        {v5.8b}, [x0], x1
    b.ne        1b
    ret
endfunc

function predict_8x16c_dc_neon, export=1
    mov         x1,  #FDEC_STRIDE
    sub         x10, x0,  #FDEC_STRIDE
    loadsum4    w2, w3, w4, w5, x0, 0
    ld1        {v6.8b}, [x10]
    loadsum4    w6, w7, w8, w9, x0, 4
    uaddlp      v6.4h,  v6.8b
    dup         v22.8h, w2              // s2
    dup         v23.8h, w6              // s3
    loadsum4    w2, w3, w4, w5, x0, 8
    addp        v6.4h,  v6.4h,  v6.4h   // s0, s1
    loadsum4    w6, w7, w8, w9, x0, 12
    dup         v20.8h, v6.h[0]         // s0
    dup         v21.8h, v6.h[1]         // s1
    dup         v24.8h, w2              // s4
    dup         v25.8h, w6              // s5

    ext         v16.16b, v20.16b, v21.16b, #8
    ext         v17.16b, v22.16b, v21.16b, #8
    ext         v1.16b,  v23.16b, v21.16b, #8
    ext         v2.16b,  v24.16b, v21.16b, #8
    ext         v3.16b,  v25.16b, v21.16b, #8

    add         v0.8h,  v16.8h, v17.8h
    add         v1.8h,  v1.8h,  v23.8h
    add         v2.8h,  v2.8h,  v24.8h
    add         v3.8h,  v3.8h,  v25.8h

    rshrn       v0.8b,  v0.8h,  #3
    rshrn       v1.8b,  v1.8h,  #3
    rshrn       v2.8b,  v2.8h,  #3
    rshrn       v3.8b,  v3.8h,  #3

    add         x11, x0,  #4  * FDEC_STRIDE
    add         x12, x0,  #8  * FDEC_STRIDE
    add         x13, x0,  #12 * FDEC_STRIDE
.rept 4
    st1        {v0.8b}, [x0],  x1
    st1        {v1.8b}, [x11], x1
    st1        {v2.8b}, [x12], x1
    st1        {v3.8b}, [x13], x1
.endr
    ret
endfunc

function predict_8x16c_dc_left_neon, export=1
    mov         x1,  #FDEC_STRIDE
    ldurb       w2,  [x0, # 0 * FDEC_STRIDE - 1]
    ldrb        w3,  [x0, # 1 * FDEC_STRIDE - 1]
    ldrb        w4,  [x0, # 2 * FDEC_STRIDE - 1]
    ldrb        w5,  [x0, # 3 * FDEC_STRIDE - 1]
    add         w2,  w2,  w3

    ldrb        w6,  [x0, # 4 * FDEC_STRIDE - 1]
    add         w4,  w4,  w5
    ldrb        w7,  [x0, # 5 * FDEC_STRIDE - 1]
    add         w2,  w2,  w4
    ldrb        w8,  [x0, # 6 * FDEC_STRIDE - 1]
    ldrb        w9,  [x0, # 7 * FDEC_STRIDE - 1]
    dup         v0.8h,  w2
    add         w6,  w6,  w7
    rshrn       v0.8b,  v0.8h,  #2
    add         w8,  w8,  w9

    ldrb        w10, [x0, # 8 * FDEC_STRIDE - 1]
    ldrb        w11, [x0, # 9 * FDEC_STRIDE - 1]
    add         w6,  w6,  w8
    ldrb        w12, [x0, #10 * FDEC_STRIDE - 1]
    ldrb        w13, [x0, #11 * FDEC_STRIDE - 1]
    dup         v1.8h,  w6
    add         w10,  w10,  w11
    rshrn       v1.8b,  v1.8h,  #2
    add         w12,  w12,  w13

    ldrb        w2,  [x0, #12 * FDEC_STRIDE - 1]
    ldrb        w3,  [x0, #13 * FDEC_STRIDE - 1]
    add         w10,  w10,  w12
    ldrb        w4,  [x0, #14 * FDEC_STRIDE - 1]
    ldrb        w5,  [x0, #15 * FDEC_STRIDE - 1]
    dup         v2.8h,  w10
    add         w2,  w2,  w3
    rshrn       v2.8b,  v2.8h,  #2
    add         w4,  w4,  w5
    st1        {v0.8b}, [x0], x1
    st1        {v0.8b}, [x0], x1
    add         w2,  w2,  w4
    st1        {v0.8b}, [x0], x1
    dup         v3.8h,  w2
    st1        {v0.8b}, [x0], x1
    rshrn       v3.8b,  v3.8h,  #2

.irp  idx, 1, 2, 3
.rept 4
    st1        {v\idx\().8b}, [x0], x1
.endr
.endr
    ret
endfunc

function predict_8x16c_dc_top_neon, export=1
    sub         x2,  x0,  #FDEC_STRIDE
    mov         x1,  #FDEC_STRIDE
    ld1        {v0.8b}, [x2]
    uaddlp      v0.4h,  v0.8b
    addp        v0.4h,  v0.4h,  v0.4h
    rshrn       v4.8b,  v0.8h,  #2
    dup         v0.8b,  v4.b[0]
    dup         v1.8b,  v4.b[1]
    ext         v0.8b,  v0.8b,  v1.8b,  #4
.rept 16
    st1        {v0.8b}, [x0], x1
.endr
    ret
endfunc


function predict_16x16_dc_top_neon, export=1
    sub         x2,  x0,  #FDEC_STRIDE
    mov         x1,  #FDEC_STRIDE
    ld1        {v0.16b}, [x2]
    uaddlv      h0,     v0.16b
    rshrn       v0.8b,  v0.8h,  #4
    dup         v0.16b, v0.b[0]
    b           pred16x16_dc_end
endfunc

function predict_16x16_dc_left_neon, export=1
    sub         x2,  x0,  #1
    mov         x1,  #FDEC_STRIDE
    ldcol.16    v0,  x2,  x1
    uaddlv      h0,     v0.16b
    rshrn       v0.8b,  v0.8h,  #4
    dup         v0.16b, v0.b[0]
    b           pred16x16_dc_end
endfunc

function predict_16x16_dc_neon, export=1
    sub         x3,  x0,  #FDEC_STRIDE
    sub         x2,  x0,  #1
    mov         x1,  #FDEC_STRIDE
    ld1        {v0.16b}, [x3]
    ldcol.16    v1,  x2,  x1
    uaddlv      h0,     v0.16b
    uaddlv      h1,     v1.16b
    add         v0.4h,  v0.4h,  v1.4h
    rshrn       v0.8b,  v0.8h,  #5
    dup         v0.16b, v0.b[0]
pred16x16_dc_end:
.rept 16
    st1        {v0.16b}, [x0], x1
.endr
    ret
endfunc

function predict_16x16_h_neon, export=1
    sub         x1,  x0,  #1
    mov         x7, #FDEC_STRIDE
.rept 8
    ld1r       {v0.16b}, [x1], x7
    ld1r       {v1.16b}, [x1], x7
    st1        {v0.16b}, [x0], x7
    st1        {v1.16b}, [x0], x7
.endr
    ret
endfunc

function predict_16x16_v_neon, export=1
    sub         x0,  x0,  #FDEC_STRIDE
    mov         x7,  #FDEC_STRIDE
    ld1        {v0.16b}, [x0], x7
.rept 16
    st1        {v0.16b}, [x0], x7
.endr
    ret
endfunc

function predict_16x16_p_neon, export=1
    sub         x3,  x0,  #FDEC_STRIDE
    mov         x1,  #FDEC_STRIDE
    add         x2,  x3,  #8
    sub         x3,  x3,  #1
    ld1        {v0.8b}, [x3]
    ld1        {v2.8b}, [x2], x1
    ldcol.8     v1,  x3,  x1
    add         x3,  x3,  x1
    ldcol.8     v3,  x3,  x1
    rev64       v0.8b,  v0.8b
    rev64       v1.8b,  v1.8b
    movrel      x4,  p16weight
    uaddl       v4.8h,  v2.8b,  v3.8b
    ld1        {v7.8h}, [x4]
    usubl       v2.8h,  v2.8b,  v0.8b
    usubl       v3.8h,  v3.8b,  v1.8b
    mul         v2.8h,  v2.8h,  v7.8h
    mul         v3.8h,  v3.8h,  v7.8h
    saddlp      v2.4s,  v2.8h
    saddlp      v3.4s,  v3.8h
    addp        v2.4s,  v2.4s,  v3.4s
    addp        v2.4s,  v2.4s,  v2.4s
    shl         v3.2s,  v2.2s,  #2
    add         v2.2s,  v2.2s,  v3.2s
    rshrn       v5.4h,  v2.4s,  #6    // b, c, x, x
    addp        v2.4h,  v5.4h,  v5.4h
    shl         v3.4h,  v2.4h,  #3
    sub         v3.4h,  v3.4h,  v2.4h // 7 * (b + c)
    ext         v4.16b, v4.16b, v4.16b, #14
    add         v4.4h,  v4.4h,  v7.4h
    shl         v2.4h,  v4.4h,  #4              // a
    sub         v2.4h,  v2.4h,  v3.4h           // a - 7 * (b + c) + 16
    ext         v7.16b, v7.16b, v7.16b, #14
    mov         v7.h[0],  wzr
    dup         v3.8h,  v5.h[0]
    mul         v0.8h,  v7.8h,  v5.h[0]         // 0,1,2,3,4,5,6,7 * b
    dup         v1.8h,  v2.h[0]                 // pix
    dup         v2.8h,  v5.h[1]                 // c
    shl         v3.8h,  v3.8h,  #3
    add         v1.8h,  v1.8h,  v0.8h           // pix + x*b
    add         v3.8h,  v3.8h,  v1.8h           // pix + x{8-15}*b
    mov         x3,  #16
1:
    subs        x3,  x3,  #1
    sqshrun     v0.8b,  v1.8h,  #5
    add         v1.8h,  v1.8h,  v2.8h
    sqshrun2    v0.16b, v3.8h,  #5
    add         v3.8h,  v3.8h,  v2.8h
    st1        {v0.16b}, [x0], x1
    b.ne        1b
    ret
endfunc
