/*****************************************************************************
 * pixel.S: aarch64 pixel metrics
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

const mask
.rept 16
.byte 0xff
.endr
.rept 16
.byte 0x00
.endr
endconst

const mask_ac_4_8
.short 0, -1, -1, -1,  0, -1, -1, -1
.short 0, -1, -1, -1, -1, -1, -1, -1
endconst

.macro SAD_START_4
    ld1        {v1.s}[0], [x2], x3
    ld1        {v0.s}[0], [x0], x1
    ld1        {v1.s}[1], [x2], x3
    ld1        {v0.s}[1], [x0], x1
    uabdl       v16.8h,  v0.8b,  v1.8b
.endm

.macro SAD_4
    ld1        {v1.s}[0], [x2], x3
    ld1        {v0.s}[0], [x0], x1
    ld1        {v1.s}[1], [x2], x3
    ld1        {v0.s}[1], [x0], x1
    uabal       v16.8h,  v0.8b,  v1.8b
.endm

.macro SAD_START_8
    ld1         {v1.8b}, [x2], x3
    ld1         {v0.8b}, [x0], x1
    ld1         {v3.8b}, [x2], x3
    ld1         {v2.8b}, [x0], x1
    uabdl       v16.8h,  v0.8b,  v1.8b
    uabdl       v17.8h,  v2.8b,  v3.8b
.endm

.macro SAD_8
    ld1         {v1.8b}, [x2], x3
    ld1         {v0.8b}, [x0], x1
    ld1         {v3.8b}, [x2], x3
    ld1         {v2.8b}, [x0], x1
    uabal       v16.8h,  v0.8b,  v1.8b
    uabal       v17.8h,  v2.8b,  v3.8b
.endm

.macro SAD_START_16
    ld1         {v1.16b}, [x2], x3
    ld1         {v0.16b}, [x0], x1
    ld1         {v3.16b}, [x2], x3
    ld1         {v2.16b}, [x0], x1
    uabdl       v16.8h,  v0.8b,  v1.8b
    uabdl2      v17.8h,  v0.16b, v1.16b
    uabal       v16.8h,  v2.8b,  v3.8b
    uabal2      v17.8h,  v2.16b, v3.16b
.endm

.macro SAD_16
    ld1         {v1.16b}, [x2], x3
    ld1         {v0.16b}, [x0], x1
    ld1         {v3.16b}, [x2], x3
    ld1         {v2.16b}, [x0], x1
    uabal       v16.8h,  v0.8b,  v1.8b
    uabal2      v17.8h,  v0.16b, v1.16b
    uabal       v16.8h,  v2.8b,  v3.8b
    uabal2      v17.8h,  v2.16b, v3.16b
.endm

.macro SAD_FUNC w, h, name
function pixel_sad\name\()_\w\()x\h\()_neon, export=1
    SAD_START_\w

.rept \h / 2 - 1
    SAD_\w
.endr
.if \w > 4
    add         v16.8h,  v16.8h,  v17.8h
.endif
    uaddlv      s0,  v16.8h
    fmov        w0,  s0
    ret
endfunc
.endm

SAD_FUNC  4,  4
SAD_FUNC  4,  8
SAD_FUNC  4,  16
SAD_FUNC  8,  4
SAD_FUNC  8,  8
SAD_FUNC  8,  16
SAD_FUNC  16, 8
SAD_FUNC  16, 16

.macro SAD_X_4 x, first=uabal
    ld1        {v0.s}[0], [x0], x7
    ld1        {v1.s}[0], [x1], x5
    ld1        {v0.s}[1], [x0], x7
    ld1        {v1.s}[1], [x1], x5
    \first      v16.8h,  v1.8b,  v0.8b
    ld1        {v2.s}[0], [x2], x5
    ld1        {v2.s}[1], [x2], x5
    \first      v17.8h,  v2.8b,  v0.8b
    ld1        {v3.s}[0], [x3], x5
    ld1        {v3.s}[1], [x3], x5
    \first      v18.8h,  v3.8b,  v0.8b
.if \x == 4
    ld1        {v4.s}[0], [x4], x5
    ld1        {v4.s}[1], [x4], x5
    \first      v19.8h,  v4.8b,  v0.8b
.endif
.endm

.macro SAD_X_8 x, first=uabal
    ld1        {v0.8b}, [x0], x7
    ld1        {v1.8b}, [x1], x5
    \first      v16.8h,  v1.8b,  v0.8b
    ld1        {v2.8b}, [x2], x5
    ld1        {v5.8b}, [x0], x7
    \first      v17.8h,  v2.8b,  v0.8b
    ld1        {v3.8b}, [x3], x5
    ld1        {v1.8b}, [x1], x5
    \first      v18.8h,  v3.8b,  v0.8b
    uabal       v16.8h,  v1.8b,  v5.8b
    ld1        {v2.8b}, [x2], x5
    ld1        {v3.8b}, [x3], x5
    uabal       v17.8h,  v2.8b,  v5.8b
    uabal       v18.8h,  v3.8b,  v5.8b
.if \x == 4
    ld1        {v4.8b}, [x4], x5
    \first      v19.8h,  v4.8b,  v0.8b
    ld1        {v4.8b}, [x4], x5
    uabal       v19.8h,  v4.8b,  v5.8b
.endif
.endm

.macro SAD_X_16 x, first=uabal
    ld1        {v0.16b}, [x0], x7
    ld1        {v1.16b}, [x1], x5
    \first      v16.8h,  v1.8b,  v0.8b
    \first\()2  v20.8h,  v1.16b, v0.16b
    ld1        {v2.16b}, [x2], x5
    ld1        {v5.16b}, [x0], x7
    \first      v17.8h,  v2.8b,  v0.8b
    \first\()2  v21.8h,  v2.16b, v0.16b
    ld1        {v3.16b}, [x3], x5
    ld1        {v1.16b}, [x1], x5
    \first      v18.8h,  v3.8b,  v0.8b
    \first\()2  v22.8h,  v3.16b, v0.16b
    uabal       v16.8h,  v1.8b,  v5.8b
    uabal2      v20.8h,  v1.16b, v5.16b
    ld1        {v2.16b}, [x2], x5
    ld1        {v3.16b}, [x3], x5
    uabal       v17.8h,  v2.8b,  v5.8b
    uabal2      v21.8h,  v2.16b, v5.16b
    uabal       v18.8h,  v3.8b,  v5.8b
    uabal2      v22.8h,  v3.16b, v5.16b
.if \x == 4
    ld1        {v4.16b}, [x4], x5
    \first      v19.8h,  v4.8b,  v0.8b
    \first\()2  v23.8h,  v4.16b, v0.16b
    ld1        {v4.16b}, [x4], x5
    uabal       v19.8h,  v4.8b,  v5.8b
    uabal2      v23.8h,  v4.16b, v5.16b
.endif
.endm

.macro SAD_X_FUNC x, w, h
function pixel_sad_x\x\()_\w\()x\h\()_neon, export=1
.if \x == 3
    mov         x6,  x5
    mov         x5,  x4
.endif
    mov         x7,  #FENC_STRIDE

    SAD_X_\w \x, uabdl

.rept \h / 2 - 1
    SAD_X_\w \x
.endr

.if \w > 8
    add         v16.8h, v16.8h, v20.8h
    add         v17.8h, v17.8h, v21.8h
    add         v18.8h, v18.8h, v22.8h
.if \x == 4
    add         v19.8h, v19.8h, v23.8h
.endif
.endif
// add up the sads
    uaddlv      s0,  v16.8h
    uaddlv      s1,  v17.8h
    uaddlv      s2,  v18.8h

    stp         s0,  s1,  [x6], #8
.if \x == 3
    str         s2,  [x6]
.else
    uaddlv      s3,  v19.8h
    stp         s2,  s3,  [x6]
.endif
    ret
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


function pixel_vsad_neon, export=1
    subs        w2,  w2,  #2
    ld1        {v0.16b},  [x0],  x1
    ld1        {v1.16b},  [x0],  x1
    uabdl       v6.8h,  v0.8b,  v1.8b
    uabdl2      v7.8h,  v0.16b, v1.16b
    b.le        2f
1:
    subs        w2,  w2,  #2
    ld1        {v0.16b},  [x0],  x1
    uabal       v6.8h,  v1.8b,  v0.8b
    uabal2      v7.8h,  v1.16b, v0.16b
    ld1        {v1.16b},  [x0],  x1
    b.lt        2f
    uabal       v6.8h,  v0.8b,  v1.8b
    uabal2      v7.8h,  v0.16b, v1.16b
    b.gt        1b
2:
    add         v5.8h,  v6.8h,  v7.8h
    uaddlv      s0,  v5.8h
    fmov        w0,  s0
    ret
endfunc

function pixel_asd8_neon, export=1
    sub         w4,  w4,  #2
    ld1        {v0.8b}, [x0], x1
    ld1        {v1.8b}, [x2], x3
    ld1        {v2.8b}, [x0], x1
    ld1        {v3.8b}, [x2], x3
    usubl       v16.8h, v0.8b,  v1.8b
1:
    subs        w4,  w4,  #2
    ld1        {v4.8b}, [x0], x1
    ld1        {v5.8b}, [x2], x3
    usubl       v17.8h, v2.8b,  v3.8b
    usubl       v18.8h, v4.8b,  v5.8b
    add         v16.8h, v16.8h, v17.8h
    ld1        {v2.8b}, [x0], x1
    ld1        {v3.8b}, [x2], x3
    add         v16.8h, v16.8h, v18.8h
    b.gt        1b
    usubl       v17.8h, v2.8b,  v3.8b
    add         v16.8h, v16.8h, v17.8h
    saddlv      s0,  v16.8h
    abs         v0.2s,  v0.2s
    fmov        w0,  s0
    ret
endfunc

.macro SSD_START_4
    ld1        {v16.s}[0], [x0], x1
    ld1        {v17.s}[0], [x2], x3
    usubl       v2.8h,  v16.8b,  v17.8b
    ld1        {v16.s}[0], [x0], x1
    ld1        {v17.s}[0], [x2], x3
    smull       v0.4s,  v2.4h,   v2.4h
.endm

.macro SSD_4
    usubl       v2.8h,  v16.8b,  v17.8b
    ld1        {v16.s}[0], [x0], x1
    ld1        {v17.s}[0], [x2], x3
    smlal       v0.4s,  v2.4h,   v2.4h
.endm

.macro SSD_END_4
    usubl       v2.8h,  v16.8b,  v17.8b
    smlal       v0.4s,  v2.4h,   v2.4h
.endm

.macro SSD_START_8
    ld1        {v16.8b}, [x0], x1
    ld1        {v17.8b}, [x2], x3
    usubl       v2.8h,  v16.8b,  v17.8b
    ld1        {v16.8b}, [x0], x1
    smull       v0.4s,  v2.4h,   v2.4h
    ld1        {v17.8b}, [x2], x3
    smlal2      v0.4s,  v2.8h,   v2.8h
.endm

.macro SSD_8
    usubl       v2.8h,  v16.8b,  v17.8b
    ld1        {v16.8b}, [x0], x1
    smlal       v0.4s,  v2.4h,   v2.4h
    ld1        {v17.8b}, [x2], x3
    smlal2      v0.4s,  v2.8h,   v2.8h
.endm

.macro SSD_END_8
    usubl       v2.8h,  v16.8b,  v17.8b
    smlal       v0.4s,  v2.4h,   v2.4h
    smlal2      v0.4s,  v2.8h,   v2.8h
.endm

.macro SSD_START_16
    ld1        {v16.16b}, [x0], x1
    ld1        {v17.16b}, [x2], x3
    usubl       v2.8h,  v16.8b,  v17.8b
    usubl2      v3.8h,  v16.16b, v17.16b
    ld1         {v16.16b}, [x0], x1
    smull       v0.4s,  v2.4h,   v2.4h
    smull2      v1.4s,  v2.8h,   v2.8h
    ld1         {v17.16b}, [x2], x3
    smlal       v0.4s,  v3.4h,   v3.4h
    smlal2      v1.4s,  v3.8h,   v3.8h
.endm

.macro SSD_16
    usubl       v2.8h,  v16.8b,  v17.8b
    usubl2      v3.8h,  v16.16b, v17.16b
    ld1         {v16.16b}, [x0], x1
    smlal       v0.4s,  v2.4h,   v2.4h
    smlal2      v1.4s,  v2.8h,   v2.8h
    ld1         {v17.16b}, [x2], x3
    smlal       v0.4s,  v3.4h,   v3.4h
    smlal2      v1.4s,  v3.8h,   v3.8h
.endm

.macro SSD_END_16
    usubl       v2.8h,  v16.8b,  v17.8b
    usubl2      v3.8h,  v16.16b, v17.16b
    smlal       v0.4s,  v2.4h,   v2.4h
    smlal2      v1.4s,  v2.8h,   v2.8h
    smlal       v0.4s,  v3.4h,   v3.4h
    smlal2      v1.4s,  v3.8h,   v3.8h
    add         v0.4s,  v0.4s,   v1.4s
.endm

.macro SSD_FUNC w h
function pixel_ssd_\w\()x\h\()_neon, export=1
    SSD_START_\w
.rept \h-2
    SSD_\w
.endr
    SSD_END_\w

    addv        s0,  v0.4s
    mov         w0,  v0.s[0]
    ret
endfunc
.endm

SSD_FUNC   4, 4
SSD_FUNC   4, 8
SSD_FUNC   4, 16
SSD_FUNC   8, 4
SSD_FUNC   8, 8
SSD_FUNC   8, 16
SSD_FUNC  16, 8
SSD_FUNC  16, 16


function pixel_ssd_nv12_core_neon, export=1
    sxtw        x8,  w4
    add         x8,  x8,  #8
    and         x8,  x8,  #~15
    movi        v6.2d,  #0
    movi        v7.2d,  #0
    sub         x1,  x1,  x8, lsl #1
    sub         x3,  x3,  x8, lsl #1
1:
    subs        w8,  w4,  #16
    ld2        {v0.8b,v1.8b},   [x0],  #16
    ld2        {v2.8b,v3.8b},   [x2],  #16
    ld2        {v24.8b,v25.8b}, [x0],  #16
    ld2        {v26.8b,v27.8b}, [x2],  #16

    usubl       v16.8h, v0.8b,  v2.8b
    usubl       v17.8h, v1.8b,  v3.8b
    smull       v20.4s, v16.4h, v16.4h
    smull       v21.4s, v17.4h, v17.4h
    usubl       v18.8h, v24.8b, v26.8b
    usubl       v19.8h, v25.8b, v27.8b
    smlal2      v20.4s, v16.8h, v16.8h
    smlal2      v21.4s, v17.8h, v17.8h

    b.lt        4f
    b.eq        3f
2:
    smlal       v20.4s, v18.4h, v18.4h
    smlal       v21.4s, v19.4h, v19.4h
    ld2        {v0.8b,v1.8b}, [x0],  #16
    ld2        {v2.8b,v3.8b}, [x2],  #16
    smlal2      v20.4s, v18.8h, v18.8h
    smlal2      v21.4s, v19.8h, v19.8h

    subs        w8,  w8,  #16
    usubl       v16.8h, v0.8b,  v2.8b
    usubl       v17.8h, v1.8b,  v3.8b
    smlal       v20.4s, v16.4h, v16.4h
    smlal       v21.4s, v17.4h, v17.4h
    ld2        {v24.8b,v25.8b}, [x0],  #16
    ld2        {v26.8b,v27.8b}, [x2],  #16
    smlal2      v20.4s, v16.8h, v16.8h
    smlal2      v21.4s, v17.8h, v17.8h
    b.lt        4f

    usubl       v18.8h, v24.8b, v26.8b
    usubl       v19.8h, v25.8b, v27.8b
    b.gt        2b
3:
    smlal       v20.4s, v18.4h, v18.4h
    smlal       v21.4s, v19.4h, v19.4h
    smlal2      v20.4s, v18.8h, v18.8h
    smlal2      v21.4s, v19.8h, v19.8h
4:
    subs        w5,  w5,  #1
    uaddw       v6.2d,  v6.2d,  v20.2s
    uaddw       v7.2d,  v7.2d,  v21.2s
    add         x0,  x0,  x1
    add         x2,  x2,  x3
    uaddw2      v6.2d,  v6.2d,  v20.4s
    uaddw2      v7.2d,  v7.2d,  v21.4s
    b.gt        1b

    addp        v6.2d,  v6.2d,  v7.2d
    st1        {v6.d}[0], [x6]
    st1        {v6.d}[1], [x7]

    ret
endfunc

.macro pixel_var_8 h
function pixel_var_8x\h\()_neon, export=1
    ld1            {v16.8b}, [x0], x1
    ld1            {v17.8b}, [x0], x1
    mov             x2,  \h - 4
    umull           v1.8h,  v16.8b, v16.8b
    uxtl            v0.8h,  v16.8b
    umull           v2.8h,  v17.8b, v17.8b
    uaddw           v0.8h,  v0.8h,  v17.8b
    ld1            {v18.8b}, [x0], x1
    uaddlp          v1.4s,  v1.8h
    uaddlp          v2.4s,  v2.8h
    ld1            {v19.8b}, [x0], x1

1:  subs            x2,  x2,  #4
    uaddw           v0.8h,  v0.8h,  v18.8b
    umull           v24.8h, v18.8b, v18.8b
    ld1            {v20.8b}, [x0], x1
    uaddw           v0.8h,  v0.8h,  v19.8b
    umull           v25.8h, v19.8b, v19.8b
    uadalp          v1.4s,  v24.8h
    ld1            {v21.8b}, [x0], x1
    uaddw           v0.8h,  v0.8h,  v20.8b
    umull           v26.8h, v20.8b, v20.8b
    uadalp          v2.4s,  v25.8h
    ld1            {v18.8b}, [x0], x1
    uaddw           v0.8h,  v0.8h,  v21.8b
    umull           v27.8h, v21.8b, v21.8b
    uadalp          v1.4s,  v26.8h
    ld1            {v19.8b}, [x0], x1
    uadalp          v2.4s,  v27.8h
    b.gt            1b

    uaddw           v0.8h,  v0.8h,  v18.8b
    umull           v28.8h, v18.8b, v18.8b
    uaddw           v0.8h,  v0.8h,  v19.8b
    umull           v29.8h, v19.8b, v19.8b
    uadalp          v1.4s,  v28.8h
    uadalp          v2.4s,  v29.8h

    b               var_end
endfunc
.endm

pixel_var_8  8
pixel_var_8 16

function pixel_var_16x16_neon, export=1
    ld1            {v16.16b}, [x0],  x1
    ld1            {v17.16b}, [x0],  x1
    mov             x2,  #14
    umull           v1.8h,  v16.8b,  v16.8b
    umull2          v2.8h,  v16.16b, v16.16b
    uxtl            v0.8h,  v16.8b
    uaddlp          v1.4s,  v1.8h
    uaddlp          v2.4s,  v2.8h
    uaddw2          v0.8h,  v0.8h,   v16.16b

1:  subs            x2,  x2,  #2
    ld1            {v18.16b}, [x0],  x1
    uaddw           v0.8h,  v0.8h,   v17.8b
    umull           v3.8h,  v17.8b,  v17.8b
    uaddw2          v0.8h,  v0.8h,   v17.16b
    umull2          v4.8h,  v17.16b, v17.16b
    uadalp          v1.4s,  v3.8h
    uadalp          v2.4s,  v4.8h

    ld1            {v17.16b}, [x0],  x1
    uaddw           v0.8h,  v0.8h,   v18.8b
    umull           v5.8h,  v18.8b,  v18.8b
    uaddw2          v0.8h,  v0.8h,   v18.16b
    umull2          v6.8h,  v18.16b, v18.16b
    uadalp          v1.4s,  v5.8h
    uadalp          v2.4s,  v6.8h
    b.gt            1b

    uaddw           v0.8h,  v0.8h,   v17.8b
    umull           v3.8h,  v17.8b,  v17.8b
    uaddw2          v0.8h,  v0.8h,   v17.16b
    umull2          v4.8h,  v17.16b, v17.16b
    uadalp          v1.4s,  v3.8h
    uadalp          v2.4s,  v4.8h
endfunc

function var_end
    add             v1.4s,  v1.4s,  v2.4s
    uaddlv          s0,  v0.8h
    uaddlv          d1,  v1.4s
    mov             w0,  v0.s[0]
    mov             x1,  v1.d[0]
    orr             x0,  x0,  x1,  lsl #32
    ret
endfunc


.macro pixel_var2_8 h
function pixel_var2_8x\h\()_neon, export=1
    mov             x3,  #16
    ld1            {v16.8b}, [x0], #8
    ld1            {v18.8b}, [x1], x3
    ld1            {v17.8b}, [x0], #8
    ld1            {v19.8b}, [x1], x3
    mov             x5,  \h - 2
    usubl           v0.8h,  v16.8b, v18.8b
    usubl           v1.8h,  v17.8b, v19.8b
    ld1            {v16.8b}, [x0], #8
    ld1            {v18.8b}, [x1], x3
    smull           v2.4s,  v0.4h,  v0.4h
    smull2          v3.4s,  v0.8h,  v0.8h
    smull           v4.4s,  v1.4h,  v1.4h
    smull2          v5.4s,  v1.8h,  v1.8h

    usubl           v6.8h,  v16.8b, v18.8b

1:  subs            x5,  x5,  #1
    ld1            {v17.8b}, [x0], #8
    ld1            {v19.8b}, [x1], x3
    smlal           v2.4s,  v6.4h,  v6.4h
    smlal2          v3.4s,  v6.8h,  v6.8h
    usubl           v7.8h,  v17.8b, v19.8b
    add             v0.8h,  v0.8h,  v6.8h
    ld1            {v16.8b}, [x0], #8
    ld1            {v18.8b}, [x1], x3
    smlal           v4.4s,  v7.4h,  v7.4h
    smlal2          v5.4s,  v7.8h,  v7.8h
    usubl           v6.8h,  v16.8b, v18.8b
    add             v1.8h,  v1.8h,  v7.8h
    b.gt            1b

    ld1            {v17.8b}, [x0], #8
    ld1            {v19.8b}, [x1], x3
    smlal           v2.4s,  v6.4h,  v6.4h
    smlal2          v3.4s,  v6.8h,  v6.8h
    usubl           v7.8h,  v17.8b, v19.8b
    add             v0.8h,  v0.8h,  v6.8h
    smlal           v4.4s,  v7.4h,  v7.4h
    add             v1.8h,  v1.8h,  v7.8h
    smlal2          v5.4s,  v7.8h,  v7.8h

    saddlv          s0,  v0.8h
    saddlv          s1,  v1.8h
    add             v2.4s,  v2.4s,  v3.4s
    add             v4.4s,  v4.4s,  v5.4s
    mov             w0,  v0.s[0]
    mov             w1,  v1.s[0]
    addv            s2,  v2.4s
    addv            s4,  v4.4s
    mul             w0,  w0,  w0
    mul             w1,  w1,  w1
    mov             w3,  v2.s[0]
    mov             w4,  v4.s[0]
    sub             w0,  w3,  w0,  lsr # 6 + (\h >> 4)
    sub             w1,  w4,  w1,  lsr # 6 + (\h >> 4)
    str             w3,  [x2]
    add             w0,  w0,  w1
    str             w4,  [x2, #4]

    ret
endfunc
.endm

pixel_var2_8  8
pixel_var2_8 16


function pixel_satd_4x4_neon, export=1
    ld1        {v1.s}[0],  [x2], x3
    ld1        {v0.s}[0],  [x0], x1
    ld1        {v3.s}[0],  [x2], x3
    ld1        {v2.s}[0],  [x0], x1
    ld1        {v1.s}[1],  [x2], x3
    ld1        {v0.s}[1],  [x0], x1
    ld1        {v3.s}[1],  [x2], x3
    ld1        {v2.s}[1],  [x0], x1

    usubl       v0.8h,  v0.8b,  v1.8b
    usubl       v1.8h,  v2.8b,  v3.8b
    SUMSUB_AB   v2.8h,  v3.8h,  v0.8h,  v1.8h

    zip1        v0.2d,  v2.2d,  v3.2d
    zip2        v1.2d,  v2.2d,  v3.2d
    SUMSUB_AB   v2.8h,  v3.8h,  v0.8h,  v1.8h

    trn1        v0.8h,  v2.8h,  v3.8h
    trn2        v1.8h,  v2.8h,  v3.8h
    SUMSUB_AB   v2.8h,  v3.8h,  v0.8h,  v1.8h

    trn1        v0.4s,  v2.4s,  v3.4s
    trn2        v1.4s,  v2.4s,  v3.4s
    abs         v0.8h,  v0.8h
    abs         v1.8h,  v1.8h
    umax        v0.8h,  v0.8h,  v1.8h

    uaddlv      s0,  v0.8h
    mov         w0,  v0.s[0]
    ret
endfunc

function pixel_satd_4x8_neon, export=1
    ld1        {v1.s}[0],  [x2], x3
    ld1        {v0.s}[0],  [x0], x1
    ld1        {v3.s}[0],  [x2], x3
    ld1        {v2.s}[0],  [x0], x1
    ld1        {v5.s}[0],  [x2], x3
    ld1        {v4.s}[0],  [x0], x1
    ld1        {v7.s}[0],  [x2], x3
    ld1        {v6.s}[0],  [x0], x1
    ld1        {v1.s}[1],  [x2], x3
    ld1        {v0.s}[1],  [x0], x1
    ld1        {v3.s}[1],  [x2], x3
    ld1        {v2.s}[1],  [x0], x1
    ld1        {v5.s}[1],  [x2], x3
    ld1        {v4.s}[1],  [x0], x1
    ld1        {v7.s}[1],  [x2], x3
    ld1        {v6.s}[1],  [x0], x1
    b           satd_4x8_8x4_end_neon
endfunc

function pixel_satd_8x4_neon, export=1
    ld1        {v1.8b},  [x2], x3
    ld1        {v0.8b},  [x0], x1
    ld1        {v3.8b},  [x2], x3
    ld1        {v2.8b},  [x0], x1
    ld1        {v5.8b},  [x2], x3
    ld1        {v4.8b},  [x0], x1
    ld1        {v7.8b},  [x2], x3
    ld1        {v6.8b},  [x0], x1
endfunc

function satd_4x8_8x4_end_neon
    usubl       v0.8h,  v0.8b,  v1.8b
    usubl       v1.8h,  v2.8b,  v3.8b
    usubl       v2.8h,  v4.8b,  v5.8b
    usubl       v3.8h,  v6.8b,  v7.8b

    SUMSUB_AB   v16.8h, v17.8h, v0.8h,  v1.8h
    SUMSUB_AB   v18.8h, v19.8h, v2.8h,  v3.8h

    SUMSUB_AB   v4.8h,  v6.8h,  v16.8h, v18.8h
    SUMSUB_AB   v5.8h,  v7.8h,  v17.8h, v19.8h

    trn1        v0.8h,  v4.8h,  v5.8h
    trn2        v1.8h,  v4.8h,  v5.8h
    trn1        v2.8h,  v6.8h,  v7.8h
    trn2        v3.8h,  v6.8h,  v7.8h

    SUMSUB_AB   v16.8h, v17.8h, v0.8h,  v1.8h
    SUMSUB_AB   v18.8h, v19.8h, v2.8h,  v3.8h

    trn1        v0.4s,  v16.4s, v18.4s
    trn2        v1.4s,  v16.4s, v18.4s
    trn1        v2.4s,  v17.4s, v19.4s
    trn2        v3.4s,  v17.4s, v19.4s
    abs         v0.8h,  v0.8h
    abs         v1.8h,  v1.8h
    abs         v2.8h,  v2.8h
    abs         v3.8h,  v3.8h
    umax        v0.8h,  v0.8h,  v1.8h
    umax        v1.8h,  v2.8h,  v3.8h
    add         v0.8h,  v0.8h,  v1.8h
    uaddlv      s0,  v0.8h
    mov         w0,  v0.s[0]
    ret
endfunc

function pixel_satd_8x8_neon, export=1
    mov         x4,  x30

    bl satd_8x8_neon
    add         v0.8h,  v0.8h,  v1.8h
    add         v1.8h,  v2.8h,  v3.8h
    add         v0.8h,  v0.8h,  v1.8h
    uaddlv      s0,  v0.8h
    mov         w0,  v0.s[0]
    ret         x4
endfunc

function pixel_satd_8x16_neon, export=1
    mov         x4,  x30

    bl satd_8x8_neon
    add         v0.8h,  v0.8h,  v1.8h
    add         v1.8h,  v2.8h,  v3.8h
    add         v30.8h, v0.8h,  v1.8h

    bl satd_8x8_neon
    add         v0.8h,  v0.8h,  v1.8h
    add         v1.8h,  v2.8h,  v3.8h
    add         v31.8h, v0.8h,  v1.8h
    add         v0.8h,  v30.8h, v31.8h
    uaddlv      s0,  v0.8h
    mov         w0,  v0.s[0]
    ret         x4
endfunc

.macro SUMSUBL_AB  sum, sub, a, b
    uaddl      \sum,  \a,  \b
    usubl      \sub,  \a,  \b
.endm

.macro load_diff_fly_8x8
    ld1        {v1.8b},  [x2], x3
    ld1        {v0.8b},  [x0], x1
    ld1        {v3.8b},  [x2], x3
    ld1        {v2.8b},  [x0], x1
    usubl       v16.8h, v0.8b,  v1.8b
    ld1        {v5.8b},  [x2], x3
    ld1        {v4.8b},  [x0], x1
    usubl       v17.8h, v2.8b,  v3.8b
    ld1        {v7.8b},  [x2], x3
    ld1        {v6.8b},  [x0], x1
    usubl       v18.8h, v4.8b,  v5.8b
    ld1        {v1.8b},  [x2], x3
    ld1        {v0.8b},  [x0], x1
    usubl       v19.8h, v6.8b,  v7.8b
    ld1        {v3.8b},  [x2], x3
    ld1        {v2.8b},  [x0], x1
    usubl       v20.8h, v0.8b,  v1.8b
    ld1        {v5.8b},  [x2], x3
    ld1        {v4.8b},  [x0], x1
    usubl       v21.8h, v2.8b,  v3.8b
    ld1        {v7.8b},  [x2], x3
    ld1        {v6.8b},  [x0], x1

    SUMSUB_AB   v0.8h,  v1.8h,  v16.8h, v17.8h
    SUMSUB_AB   v2.8h,  v3.8h,  v18.8h, v19.8h

    usubl       v22.8h, v4.8b,  v5.8b
    usubl       v23.8h, v6.8b,  v7.8b
.endm

.macro SUMSUB_ABCD s1, d1, s2, d2, a, b, c, d
    SUMSUB_AB   \s1, \d1, \a, \b
    SUMSUB_AB   \s2, \d2, \c, \d
.endm

.macro HADAMARD4_V r1, r2, r3, r4, t1, t2, t3, t4
    SUMSUB_ABCD \t1, \t2, \t3, \t4, \r1, \r2, \r3, \r4
    SUMSUB_ABCD \r1, \r3, \r2, \r4, \t1, \t3, \t2, \t4
.endm

function satd_8x8_neon
    load_diff_fly_8x8
endfunc

// one vertical hadamard pass and two horizontal
function satd_8x4v_8x8h_neon
    SUMSUB_AB   v16.8h, v18.8h, v0.8h,  v2.8h
    SUMSUB_AB   v17.8h, v19.8h, v1.8h,  v3.8h

    HADAMARD4_V v20.8h, v21.8h, v22.8h, v23.8h, v0.8h,  v1.8h, v2.8h, v3.8h

    transpose   v0.8h,  v1.8h,  v16.8h, v17.8h
    transpose   v2.8h,  v3.8h,  v18.8h, v19.8h
    transpose   v4.8h,  v5.8h,  v20.8h, v21.8h
    transpose   v6.8h,  v7.8h,  v22.8h, v23.8h

    SUMSUB_AB   v16.8h, v17.8h, v0.8h,  v1.8h
    SUMSUB_AB   v18.8h, v19.8h, v2.8h,  v3.8h
    SUMSUB_AB   v20.8h, v21.8h, v4.8h,  v5.8h
    SUMSUB_AB   v22.8h, v23.8h, v6.8h,  v7.8h

    transpose   v0.4s,  v2.4s,  v16.4s, v18.4s
    transpose   v1.4s,  v3.4s,  v17.4s, v19.4s
    transpose   v4.4s,  v6.4s,  v20.4s, v22.4s
    transpose   v5.4s,  v7.4s,  v21.4s, v23.4s

    abs         v0.8h,  v0.8h
    abs         v1.8h,  v1.8h
    abs         v2.8h,  v2.8h
    abs         v3.8h,  v3.8h
    abs         v4.8h,  v4.8h
    abs         v5.8h,  v5.8h
    abs         v6.8h,  v6.8h
    abs         v7.8h,  v7.8h

    umax        v0.8h,  v0.8h,  v2.8h
    umax        v1.8h,  v1.8h,  v3.8h
    umax        v2.8h,  v4.8h,  v6.8h
    umax        v3.8h,  v5.8h,  v7.8h

    ret
endfunc

function pixel_satd_16x8_neon, export=1
    mov         x4,  x30

    bl          satd_16x4_neon
    add         v30.8h, v0.8h,  v1.8h
    add         v31.8h, v2.8h,  v3.8h

    bl          satd_16x4_neon
    add         v0.8h,  v0.8h,  v1.8h
    add         v1.8h,  v2.8h,  v3.8h
    add         v30.8h, v30.8h, v0.8h
    add         v31.8h, v31.8h, v1.8h

    add         v0.8h,  v30.8h, v31.8h
    uaddlv      s0,  v0.8h
    mov         w0,  v0.s[0]
    ret         x4
endfunc

function pixel_satd_16x16_neon, export=1
    mov         x4,  x30

    bl          satd_16x4_neon
    add         v30.8h, v0.8h,  v1.8h
    add         v31.8h, v2.8h,  v3.8h

    bl          satd_16x4_neon
    add         v0.8h,  v0.8h,  v1.8h
    add         v1.8h,  v2.8h,  v3.8h
    add         v30.8h, v30.8h, v0.8h
    add         v31.8h, v31.8h, v1.8h

    bl          satd_16x4_neon
    add         v0.8h,  v0.8h,  v1.8h
    add         v1.8h,  v2.8h,  v3.8h
    add         v30.8h, v30.8h, v0.8h
    add         v31.8h, v31.8h, v1.8h

    bl          satd_16x4_neon
    add         v0.8h,  v0.8h,  v1.8h
    add         v1.8h,  v2.8h,  v3.8h
    add         v30.8h, v30.8h, v0.8h
    add         v31.8h, v31.8h, v1.8h

    add         v0.8h,  v30.8h, v31.8h
    uaddlv      s0,  v0.8h
    mov         w0,  v0.s[0]
    ret         x4
endfunc

function satd_16x4_neon
    ld1        {v1.16b},  [x2], x3
    ld1        {v0.16b},  [x0], x1
    ld1        {v3.16b},  [x2], x3
    ld1        {v2.16b},  [x0], x1
    usubl       v16.8h, v0.8b,  v1.8b
    usubl2      v20.8h, v0.16b, v1.16b
    ld1        {v5.16b},  [x2], x3
    ld1        {v4.16b},  [x0], x1
    usubl       v17.8h, v2.8b,  v3.8b
    usubl2      v21.8h, v2.16b, v3.16b
    ld1        {v7.16b},  [x2], x3
    ld1        {v6.16b},  [x0], x1

    usubl       v18.8h, v4.8b,  v5.8b
    usubl2      v22.8h, v4.16b, v5.16b
    usubl       v19.8h, v6.8b,  v7.8b
    usubl2      v23.8h, v6.16b, v7.16b

    SUMSUB_AB   v0.8h,  v1.8h,  v16.8h, v17.8h
    SUMSUB_AB   v2.8h,  v3.8h,  v18.8h, v19.8h

    b           satd_8x4v_8x8h_neon
endfunc

function pixel_satd_4x16_neon, export=1
    mov         x4,  x30
    ld1        {v1.s}[0],  [x2], x3
    ld1        {v0.s}[0],  [x0], x1
    ld1        {v3.s}[0],  [x2], x3
    ld1        {v2.s}[0],  [x0], x1
    ld1        {v5.s}[0],  [x2], x3
    ld1        {v4.s}[0],  [x0], x1
    ld1        {v7.s}[0],  [x2], x3
    ld1        {v6.s}[0],  [x0], x1
    ld1        {v1.s}[1],  [x2], x3
    ld1        {v0.s}[1],  [x0], x1
    ld1        {v3.s}[1],  [x2], x3
    ld1        {v2.s}[1],  [x0], x1
    ld1        {v5.s}[1],  [x2], x3
    ld1        {v4.s}[1],  [x0], x1
    ld1        {v7.s}[1],  [x2], x3
    ld1        {v6.s}[1],  [x0], x1
    usubl       v16.8h, v0.8b,  v1.8b
    usubl       v17.8h, v2.8b,  v3.8b
    usubl       v18.8h, v4.8b,  v5.8b
    usubl       v19.8h, v6.8b,  v7.8b
    ld1        {v1.s}[0],  [x2], x3
    ld1        {v0.s}[0],  [x0], x1
    ld1        {v3.s}[0],  [x2], x3
    ld1        {v2.s}[0],  [x0], x1
    ld1        {v5.s}[0],  [x2], x3
    ld1        {v4.s}[0],  [x0], x1
    ld1        {v7.s}[0],  [x2], x3
    ld1        {v6.s}[0],  [x0], x1
    ld1        {v1.s}[1],  [x2], x3
    ld1        {v0.s}[1],  [x0], x1
    ld1        {v3.s}[1],  [x2], x3
    ld1        {v2.s}[1],  [x0], x1
    ld1        {v5.s}[1],  [x2], x3
    ld1        {v4.s}[1],  [x0], x1
    ld1        {v7.s}[1],  [x2], x3
    ld1        {v6.s}[1],  [x0], x1
    usubl       v20.8h, v0.8b,  v1.8b
    usubl       v21.8h, v2.8b,  v3.8b
    usubl       v22.8h, v4.8b,  v5.8b
    usubl       v23.8h, v6.8b,  v7.8b

    SUMSUB_AB   v0.8h,  v1.8h,  v16.8h, v17.8h
    SUMSUB_AB   v2.8h,  v3.8h,  v18.8h, v19.8h

    bl          satd_8x4v_8x8h_neon

    add         v30.8h, v0.8h,  v1.8h
    add         v31.8h, v2.8h,  v3.8h
    add         v0.8h,  v30.8h, v31.8h
    uaddlv      s0,  v0.8h
    mov         w0,  v0.s[0]
    ret         x4
endfunc

function pixel_sa8d_8x8_neon, export=1
    mov         x4,  x30
    bl          pixel_sa8d_8x8_neon
    add         v0.8h,  v0.8h,  v1.8h
    uaddlv      s0,  v0.8h
    mov         w0,  v0.s[0]
    add         w0,  w0,  #1
    lsr         w0,  w0,  #1
    ret         x4
endfunc

function pixel_sa8d_16x16_neon, export=1
    mov         x4,  x30
    bl          pixel_sa8d_8x8_neon
    uaddlp      v30.4s, v0.8h
    uaddlp      v31.4s, v1.8h
    bl          pixel_sa8d_8x8_neon
    uadalp      v30.4s, v0.8h
    uadalp      v31.4s, v1.8h
    sub         x0,  x0,  x1,  lsl #4
    sub         x2,  x2,  x3,  lsl #4
    add         x0,  x0,  #8
    add         x2,  x2,  #8
    bl          pixel_sa8d_8x8_neon
    uadalp      v30.4s, v0.8h
    uadalp      v31.4s, v1.8h
    bl          pixel_sa8d_8x8_neon
    uadalp      v30.4s, v0.8h
    uadalp      v31.4s, v1.8h
    add         v0.4s,  v30.4s, v31.4s
    addv        s0,  v0.4s
    mov         w0,  v0.s[0]
    add         w0,  w0,  #1
    lsr         w0,  w0,  #1
    ret         x4
endfunc

.macro sa8d_satd_8x8 satd=
function pixel_sa8d_\satd\()8x8_neon
    load_diff_fly_8x8

    SUMSUB_AB   v16.8h, v18.8h, v0.8h,  v2.8h
    SUMSUB_AB   v17.8h, v19.8h, v1.8h,  v3.8h

    HADAMARD4_V v20.8h, v21.8h, v22.8h, v23.8h, v0.8h,  v1.8h, v2.8h, v3.8h
.ifc \satd, satd_
    transpose   v0.8h,  v1.8h,  v16.8h, v17.8h
    transpose   v2.8h,  v3.8h,  v18.8h, v19.8h
    transpose   v4.8h,  v5.8h,  v20.8h, v21.8h
    transpose   v6.8h,  v7.8h,  v22.8h, v23.8h

    SUMSUB_AB   v24.8h, v25.8h, v0.8h,  v1.8h
    SUMSUB_AB   v26.8h, v27.8h, v2.8h,  v3.8h
    SUMSUB_AB   v0.8h,  v1.8h,  v4.8h,  v5.8h
    SUMSUB_AB   v2.8h,  v3.8h,  v6.8h,  v7.8h

    transpose   v4.4s,  v6.4s,  v24.4s, v26.4s
    transpose   v5.4s,  v7.4s,  v25.4s, v27.4s
    transpose   v24.4s, v26.4s, v0.4s,  v2.4s
    transpose   v25.4s, v27.4s, v1.4s,  v3.4s

    abs         v0.8h,  v4.8h
    abs         v1.8h,  v5.8h
    abs         v2.8h,  v6.8h
    abs         v3.8h,  v7.8h
    abs         v4.8h,  v24.8h
    abs         v5.8h,  v25.8h
    abs         v6.8h,  v26.8h
    abs         v7.8h,  v27.8h

    umax        v0.8h,  v0.8h,  v2.8h
    umax        v1.8h,  v1.8h,  v3.8h
    umax        v2.8h,  v4.8h,  v6.8h
    umax        v3.8h,  v5.8h,  v7.8h

    add         v26.8h, v0.8h,  v1.8h
    add         v27.8h, v2.8h,  v3.8h
.endif

    SUMSUB_AB   v0.8h,  v16.8h, v16.8h, v20.8h
    SUMSUB_AB   v1.8h,  v17.8h, v17.8h, v21.8h
    SUMSUB_AB   v2.8h,  v18.8h, v18.8h, v22.8h
    SUMSUB_AB   v3.8h,  v19.8h, v19.8h, v23.8h

    transpose   v20.8h, v21.8h, v16.8h, v17.8h
    transpose   v4.8h,  v5.8h,  v0.8h,  v1.8h
    transpose   v22.8h, v23.8h, v18.8h, v19.8h
    transpose   v6.8h,  v7.8h,  v2.8h,  v3.8h

    SUMSUB_AB   v2.8h,  v3.8h,  v20.8h, v21.8h
    SUMSUB_AB   v24.8h, v25.8h, v4.8h,  v5.8h
    SUMSUB_AB   v0.8h,  v1.8h,  v22.8h, v23.8h
    SUMSUB_AB   v4.8h,  v5.8h,  v6.8h,  v7.8h

    transpose   v20.4s, v22.4s, v2.4s,  v0.4s
    transpose   v21.4s, v23.4s, v3.4s,  v1.4s
    transpose   v16.4s, v18.4s, v24.4s, v4.4s
    transpose   v17.4s, v19.4s, v25.4s, v5.4s

    SUMSUB_AB   v0.8h,  v2.8h,  v20.8h, v22.8h
    SUMSUB_AB   v1.8h,  v3.8h,  v21.8h, v23.8h
    SUMSUB_AB   v4.8h,  v6.8h,  v16.8h, v18.8h
    SUMSUB_AB   v5.8h,  v7.8h,  v17.8h, v19.8h

    transpose   v16.2d, v20.2d,  v0.2d,  v4.2d
    transpose   v17.2d, v21.2d,  v1.2d,  v5.2d
    transpose   v18.2d, v22.2d,  v2.2d,  v6.2d
    transpose   v19.2d, v23.2d,  v3.2d,  v7.2d

    abs         v16.8h, v16.8h
    abs         v20.8h, v20.8h
    abs         v17.8h, v17.8h
    abs         v21.8h, v21.8h
    abs         v18.8h, v18.8h
    abs         v22.8h, v22.8h
    abs         v19.8h, v19.8h
    abs         v23.8h, v23.8h

    umax        v16.8h, v16.8h, v20.8h
    umax        v17.8h, v17.8h, v21.8h
    umax        v18.8h, v18.8h, v22.8h
    umax        v19.8h, v19.8h, v23.8h

    add         v0.8h,  v16.8h, v17.8h
    add         v1.8h,  v18.8h, v19.8h

    ret
endfunc
.endm

sa8d_satd_8x8
sa8d_satd_8x8 satd_

function pixel_sa8d_satd_16x16_neon, export=1
    mov         x4,  x30
    bl          pixel_sa8d_satd_8x8_neon
    uaddlp      v30.4s, v0.8h
    uaddlp      v31.4s, v1.8h
    uaddlp      v28.4s, v26.8h
    uaddlp      v29.4s, v27.8h
    bl          pixel_sa8d_satd_8x8_neon
    uadalp      v30.4s, v0.8h
    uadalp      v31.4s, v1.8h
    uadalp      v28.4s, v26.8h
    uadalp      v29.4s, v27.8h
    sub         x0,  x0,  x1,  lsl #4
    sub         x2,  x2,  x3,  lsl #4
    add         x0,  x0,  #8
    add         x2,  x2,  #8
    bl          pixel_sa8d_satd_8x8_neon
    uadalp      v30.4s, v0.8h
    uadalp      v31.4s, v1.8h
    uadalp      v28.4s, v26.8h
    uadalp      v29.4s, v27.8h
    bl          pixel_sa8d_satd_8x8_neon
    uadalp      v30.4s, v0.8h
    uadalp      v31.4s, v1.8h
    uadalp      v28.4s, v26.8h
    uadalp      v29.4s, v27.8h
    add         v0.4s,  v30.4s, v31.4s  // sa8d
    add         v1.4s,  v28.4s, v29.4s  // satd
    addv        s0,  v0.4s
    addv        s1,  v1.4s
    urshr       v0.4s,  v0.4s,  #1
    fmov        w0,  s0
    fmov        w1,  s1
    add         x0,  x0,  x1, lsl #32
    ret         x4
endfunc

.macro HADAMARD_AC w h
function pixel_hadamard_ac_\w\()x\h\()_neon, export=1
    movrel      x5, mask_ac_4_8
    mov         x4,  x30
    ld1         {v30.8h,v31.8h}, [x5]
    movi        v28.16b, #0
    movi        v29.16b, #0

    bl          hadamard_ac_8x8_neon
.if \h > 8
    bl          hadamard_ac_8x8_neon
.endif
.if \w > 8
    sub         x0,  x0,  x1,  lsl #3
    add         x0,  x0,  #8
    bl          hadamard_ac_8x8_neon
.endif
.if \w * \h == 256
    sub         x0,  x0,  x1,  lsl #4
    bl          hadamard_ac_8x8_neon
.endif

    addv        s1,  v29.4s
    addv        s0,  v28.4s
    mov         w1,  v1.s[0]
    mov         w0,  v0.s[0]
    lsr         w1,  w1,  #2
    lsr         w0,  w0,  #1
    orr         x0,  x0,  x1, lsl #32
    ret         x4
endfunc
.endm

HADAMARD_AC  8, 8
HADAMARD_AC  8, 16
HADAMARD_AC 16, 8
HADAMARD_AC 16, 16

// v28: satd  v29: sa8d  v30: mask_ac4  v31: mask_ac8
function hadamard_ac_8x8_neon
    ld1         {v16.8b}, [x0], x1
    ld1         {v17.8b}, [x0], x1
    ld1         {v18.8b}, [x0], x1
    ld1         {v19.8b}, [x0], x1
    SUMSUBL_AB  v0.8h,  v1.8h, v16.8b, v17.8b
    ld1         {v20.8b}, [x0], x1
    ld1         {v21.8b}, [x0], x1
    SUMSUBL_AB  v2.8h,  v3.8h, v18.8b, v19.8b
    ld1         {v22.8b}, [x0], x1
    ld1         {v23.8b}, [x0], x1
    SUMSUBL_AB  v4.8h,  v5.8h, v20.8b, v21.8b
    SUMSUBL_AB  v6.8h,  v7.8h, v22.8b, v23.8b

    SUMSUB_ABCD v16.8h, v18.8h, v17.8h, v19.8h, v0.8h,  v2.8h,  v1.8h,  v3.8h
    SUMSUB_ABCD v20.8h, v22.8h, v21.8h, v23.8h, v4.8h,  v6.8h,  v5.8h,  v7.8h

    transpose   v0.8h,  v1.8h,  v16.8h,  v17.8h
    transpose   v2.8h,  v3.8h,  v18.8h,  v19.8h
    transpose   v4.8h,  v5.8h,  v20.8h,  v21.8h
    transpose   v6.8h,  v7.8h,  v22.8h,  v23.8h

    SUMSUB_AB   v16.8h, v17.8h, v0.8h,  v1.8h
    SUMSUB_AB   v18.8h, v19.8h, v2.8h,  v3.8h
    SUMSUB_AB   v20.8h, v21.8h, v4.8h,  v5.8h
    SUMSUB_AB   v22.8h, v23.8h, v6.8h,  v7.8h

    transpose   v0.4s,  v2.4s,  v16.4s, v18.4s
    transpose   v1.4s,  v3.4s,  v17.4s, v19.4s
    transpose   v4.4s,  v6.4s,  v20.4s, v22.4s
    transpose   v5.4s,  v7.4s,  v21.4s, v23.4s

    SUMSUB_AB   v16.8h, v18.8h, v0.8h,  v2.8h
    SUMSUB_AB   v17.8h, v19.8h, v1.8h,  v3.8h
    SUMSUB_ABCD v20.8h, v22.8h, v21.8h, v23.8h, v4.8h,  v6.8h,  v5.8h,  v7.8h

    abs         v0.8h,  v16.8h
    abs         v4.8h,  v20.8h
    abs         v1.8h,  v17.8h
    abs         v5.8h,  v21.8h
    abs         v2.8h,  v18.8h
    abs         v6.8h,  v22.8h
    abs         v3.8h,  v19.8h
    abs         v7.8h,  v23.8h

    add         v0.8h,  v0.8h,  v4.8h
    add         v1.8h,  v1.8h,  v5.8h
    and         v0.16b, v0.16b, v30.16b
    add         v2.8h,  v2.8h,  v6.8h
    add         v3.8h,  v3.8h,  v7.8h
    add         v0.8h,  v0.8h,  v2.8h
    add         v1.8h,  v1.8h,  v3.8h
    uadalp      v28.4s, v0.8h
    uadalp      v28.4s, v1.8h

    SUMSUB_AB   v6.8h,  v7.8h,  v23.8h, v19.8h
    SUMSUB_AB   v4.8h,  v5.8h,  v22.8h, v18.8h
    SUMSUB_AB   v2.8h,  v3.8h,  v21.8h, v17.8h
    SUMSUB_AB   v1.8h,  v0.8h,  v16.8h,  v20.8h

    transpose   v16.2d, v17.2d,  v6.2d,  v7.2d
    transpose   v18.2d, v19.2d,  v4.2d,  v5.2d
    transpose   v20.2d, v21.2d,  v2.2d,  v3.2d

    abs         v16.8h,  v16.8h
    abs         v17.8h,  v17.8h
    abs         v18.8h,  v18.8h
    abs         v19.8h,  v19.8h
    abs         v20.8h,  v20.8h
    abs         v21.8h,  v21.8h

    transpose   v7.2d,  v6.2d,  v1.2d,  v0.2d

    umax        v3.8h,  v16.8h,  v17.8h
    umax        v2.8h,  v18.8h,  v19.8h
    umax        v1.8h,  v20.8h,  v21.8h

    SUMSUB_AB   v4.8h,  v5.8h,  v7.8h,  v6.8h

    add         v2.8h,  v2.8h,  v3.8h
    add         v2.8h,  v2.8h,  v1.8h
    and         v4.16b, v4.16b, v31.16b
    add         v2.8h,  v2.8h,  v2.8h
    abs         v5.8h,  v5.8h
    abs         v4.8h,  v4.8h
    add         v2.8h,  v2.8h,  v5.8h
    add         v2.8h,  v2.8h,  v4.8h
    uadalp      v29.4s, v2.8h
    ret
endfunc


function pixel_ssim_4x4x2_core_neon, export=1
    ld1        {v0.8b},  [x0], x1
    ld1        {v2.8b},  [x2], x3
    umull       v16.8h, v0.8b,  v0.8b
    umull       v17.8h, v0.8b,  v2.8b
    umull       v18.8h, v2.8b,  v2.8b

    ld1        {v28.8b}, [x0], x1
    ld1        {v29.8b}, [x2], x3
    umull       v20.8h, v28.8b, v28.8b
    umull       v21.8h, v28.8b, v29.8b
    umull       v22.8h, v29.8b, v29.8b

    uaddlp      v16.4s, v16.8h
    uaddlp      v17.4s, v17.8h
    uaddl       v0.8h,  v0.8b,  v28.8b
    uadalp      v16.4s, v18.8h
    uaddl       v1.8h,  v2.8b,  v29.8b

    ld1        {v26.8b}, [x0], x1
    ld1        {v27.8b}, [x2], x3
    umull       v23.8h, v26.8b, v26.8b
    umull       v24.8h, v26.8b, v27.8b
    umull       v25.8h, v27.8b, v27.8b

    uadalp      v16.4s, v20.8h
    uaddw       v0.8h,  v0.8h,  v26.8b
    uadalp      v17.4s, v21.8h
    uaddw       v1.8h,  v1.8h,  v27.8b
    uadalp      v16.4s, v22.8h

    ld1        {v28.8b}, [x0], x1
    ld1        {v29.8b}, [x2], x3
    umull       v20.8h, v28.8b, v28.8b
    umull       v21.8h, v28.8b, v29.8b
    umull       v22.8h, v29.8b, v29.8b

    uadalp      v16.4s, v23.8h
    uaddw       v0.8h,  v0.8h,  v28.8b
    uadalp      v17.4s, v24.8h
    uaddw       v1.8h,  v1.8h,  v29.8b
    uadalp      v16.4s, v25.8h

    uadalp      v16.4s, v20.8h
    uadalp      v17.4s, v21.8h
    uadalp      v16.4s, v22.8h

    uaddlp      v0.4s,  v0.8h
    uaddlp      v1.4s,  v1.8h

    addp        v0.4s,  v0.4s,  v0.4s
    addp        v1.4s,  v1.4s,  v1.4s
    addp        v2.4s,  v16.4s, v16.4s
    addp        v3.4s,  v17.4s, v17.4s

    st4        {v0.2s,v1.2s,v2.2s,v3.2s}, [x4]
    ret
endfunc

function pixel_ssim_end4_neon, export=1
    mov         x5,  #4
    ld1        {v16.4s,v17.4s}, [x0], #32
    ld1        {v18.4s,v19.4s}, [x1], #32
    mov         w4,  #0x99bb
    subs        x2,  x5,  w2, uxtw
    mov         w3,  #416                       // ssim_c1 = .01*.01*255*255*64
    movk        w4,  #0x03, lsl #16             // ssim_c2 = .03*.03*255*255*64*63
    add         v0.4s,  v16.4s,  v18.4s
    add         v1.4s,  v17.4s,  v19.4s
    add         v0.4s,  v0.4s,  v1.4s
    ld1        {v20.4s,v21.4s}, [x0], #32
    ld1        {v22.4s,v23.4s}, [x1], #32
    add         v2.4s,  v20.4s, v22.4s
    add         v3.4s,  v21.4s, v23.4s
    add         v1.4s,  v1.4s,  v2.4s
    ld1        {v16.4s}, [x0], #16
    ld1        {v18.4s}, [x1], #16
    add         v16.4s, v16.4s, v18.4s
    add         v2.4s,  v2.4s,  v3.4s
    add         v3.4s,  v3.4s,  v16.4s

    dup         v30.4s, w3
    dup         v31.4s, w4

    transpose   v4.4s,  v5.4s,  v0.4s,  v1.4s
    transpose   v6.4s,  v7.4s,  v2.4s,  v3.4s
    transpose   v0.2d,  v2.2d,  v4.2d,  v6.2d
    transpose   v1.2d,  v3.2d,  v5.2d,  v7.2d

    mul         v16.4s, v0.4s, v1.4s    // s1*s2
    mul         v0.4s,  v0.4s, v0.4s
    mla         v0.4s,  v1.4s, v1.4s    // s1*s1 + s2*s2

    shl         v3.4s,  v3.4s,  #7
    shl         v2.4s,  v2.4s,  #6
    add         v1.4s,  v16.4s, v16.4s

    sub         v2.4s,  v2.4s,  v0.4s    // vars
    sub         v3.4s,  v3.4s,  v1.4s    // covar*2
    add         v0.4s,  v0.4s,  v30.4s
    add         v2.4s,  v2.4s,  v31.4s
    add         v1.4s,  v1.4s,  v30.4s
    add         v3.4s,  v3.4s,  v31.4s

    scvtf       v0.4s,  v0.4s
    scvtf       v2.4s,  v2.4s
    scvtf       v1.4s,  v1.4s
    scvtf       v3.4s,  v3.4s

    fmul        v0.4s,  v0.4s,  v2.4s
    fmul        v1.4s,  v1.4s,  v3.4s

    fdiv        v0.4s,  v1.4s,  v0.4s

    b.eq        1f
    movrel      x3,  mask
    add         x3,  x3,  x2,  lsl #2
    ld1        {v29.4s}, [x3]
    and         v0.16b, v0.16b, v29.16b
1:
    faddp       v0.4s,  v0.4s,  v0.4s
    faddp       s0,  v0.2s
    ret
endfunc
