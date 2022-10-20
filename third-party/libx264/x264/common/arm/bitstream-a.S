/*****************************************************************************
 * bitstream-a.S: arm bitstream functions
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

function nal_escape_neon
    push        {r4-r5,lr}
    vmov.u8     q0,  #0xff
    vmov.u8     q8,  #4
    mov         r3,  #3
    subs        lr,  r1,  r2
    beq         99f
0:
    cmn         lr,  #15
    blt         16f
    mov         r1,  r2
    b           100f
16:
    vld1.8      {q1}, [r1]!
    vext.8      q2,  q0,  q1, #14
    vext.8      q3,  q0,  q1, #15
    vcgt.u8     q11, q8,  q1
    vceq.u8     q9,  q2,  #0
    vceq.u8     q10, q3,  #0
    vand        q9,  q9,  q11
    vand        q9,  q9,  q10
    vshrn.u16   d22, q9,  #4
    vmov        ip,  lr,  d22
    orrs        ip,  ip,  lr
    beq         16f
    mov         lr,  #-16
100:
    vmov.u8     r5,  d1[6]
    vmov.u8     r4,  d1[7]
    orr         r5,  r4,  r5, lsl #8
101:
    ldrb        r4,  [r1, lr]
    orr         ip,  r4,  r5, lsl #16
    cmp         ip,  #3
    bhi         102f
    strb        r3,  [r0], #1
    orr         r5,  r3,  r5, lsl #8
102:
    adds        lr,  lr,  #1
    strb        r4,  [r0], #1
    orr         r5,  r4,  r5, lsl #8
    blt         101b
    subs        lr,  r1,  r2
    lsr         ip,  r5,  #8
    vmov.u8     d1[6],  ip
    vmov.u8     d1[7],  r5
    blt         0b

    pop         {r4-r5,pc}
16:
    subs        lr,  r1,  r2
    vst1.8      {q1}, [r0]!
    vmov        q0, q1
    blt         0b
99:
    pop         {r4-r5,pc}
endfunc
