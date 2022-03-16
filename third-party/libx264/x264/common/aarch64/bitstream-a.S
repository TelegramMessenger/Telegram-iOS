/*****************************************************************************
 * bitstream-a.S: aarch64 bitstream functions
 *****************************************************************************
 * Copyright (C) 2014-2022 x264 project
 *
 * Authors: Janne Grunau <janne-x264@jannau.net>
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

function nal_escape_neon, export=1
    movi        v0.16b,  #0xff
    movi        v4.16b,  #4
    mov         w3,  #3
    subs        x6,  x1,  x2
    cbz         x6,  99f
0:
    cmn         x6,  #15
    b.lt        16f
    mov         x1,  x2
    b           100f
16:
    ld1         {v1.16b}, [x1], #16
    ext         v2.16b, v0.16b, v1.16b, #14
    ext         v3.16b, v0.16b, v1.16b, #15
    cmhi        v7.16b, v4.16b, v1.16b
    cmeq        v5.16b, v2.16b, #0
    cmeq        v6.16b, v3.16b, #0
    and         v5.16b, v5.16b, v7.16b
    and         v5.16b, v5.16b, v6.16b
    shrn        v7.8b,  v5.8h,  #4
    mov         x7,  v7.d[0]
    cbz         x7,  16f
    mov         x6,  #-16
100:
    umov        w5,  v0.b[14]
    umov        w4,  v0.b[15]
    orr         w5,  w4,  w5, lsl #8
101:
    ldrb        w4,  [x1, x6]
    orr         w9,  w4,  w5, lsl #16
    cmp         w9,  #3
    b.hi        102f
    strb        w3,  [x0], #1
    orr         w5,  w3,  w5, lsl #8
102:
    adds        x6,  x6,  #1
    strb        w4,  [x0], #1
    orr         w5,  w4,  w5, lsl #8
    b.lt        101b
    subs        x6,  x1,  x2
    lsr         w9,  w5,  #8
    mov         v0.b[14],  w9
    mov         v0.b[15],  w5
    b.lt        0b

    ret
16:
    subs        x6,  x1,  x2
    st1         {v1.16b}, [x0], #16
    mov         v0.16b, v1.16b
    b.lt        0b
99:
    ret
endfunc
