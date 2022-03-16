/*****************************************************************************
 * cabac-a.S: aarch64 cabac
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
#include "asm-offsets.h"

// w11 holds x264_cabac_t.i_low
// w12 holds x264_cabac_t.i_range

function cabac_encode_decision_asm, export=1
    add         w10, w1,  #CABAC_STATE
    ldrb        w3,  [x0,  w10, uxtw]           // i_state
    ldr         w12, [x0,  #CABAC_I_RANGE]
    movrel      x8,  X264(cabac_range_lps), -4
    movrel      x9,  X264(cabac_transition)
    ubfx        x4,  x3,  #1,  #7
    asr         w5,  w12, #6
    add         x8,  x8,  x4, lsl #2
    orr         w14, w2,  w3, lsl #1
    ldrb        w4,  [x8,  w5,  uxtw]           // i_range_lps
    ldr         w11, [x0,  #CABAC_I_LOW]
    eor         w6,  w2,  w3                    // b ^ i_state
    ldrb        w9,  [x9,  w14, uxtw]
    sub         w12, w12, w4
    add         w7,  w11, w12
    tst         w6,  #1                         // (b ^ i_state) & 1
    csel        w12, w4, w12, ne
    csel        w11, w7, w11, ne
    strb        w9,  [x0,  w10, uxtw]           // i_state

cabac_encode_renorm:
    ldr         w2,  [x0, #CABAC_I_QUEUE]
    clz         w5,  w12
    sub         w5,  w5,  #23
    lsl         w11, w11, w5
    lsl         w12, w12, w5
    adds        w2,  w2,  w5
    b.ge        cabac_putbyte

    stp         w11, w12, [x0, #CABAC_I_LOW]    // store i_low, i_range
    str         w2,  [x0, #CABAC_I_QUEUE]
    ret

.align 5
cabac_putbyte:
    ldr         w6,  [x0, #CABAC_I_BYTES_OUTSTANDING]
    add         w14, w2,  #10
    mov         w13, #-1
    sub         w2,  w2,  #8
    asr         w4,  w11, w14           // out
    lsl         w13, w13, w14
    subs        w5,  w4,  #0xff
    bic         w11, w11, w13
    cinc        w6,  w6,  eq
    b.eq        0f

1:
    ldr         x7,  [x0, #CABAC_P]
    asr         w5,  w4,  #8            // carry
    ldurb       w8,  [x7, #-1]
    add         w8,  w8,  w5
    sub         w5,  w5,  #1
    sturb       w8,  [x7, #-1]
    cbz         w6,  3f
2:
    subs        w6,  w6,  #1
    strb        w5,  [x7],  #1
    b.gt        2b
3:
    strb        w4,  [x7],  #1
    str         x7,  [x0, #CABAC_P]
0:
    stp         w11, w12, [x0, #CABAC_I_LOW]    // store i_low, i_range
    stp         w2,  w6,  [x0, #CABAC_I_QUEUE]  // store i_queue, i_bytes_outstanding
    ret
endfunc

function cabac_encode_bypass_asm, export=1, align=5
    ldr         w12, [x0, #CABAC_I_RANGE]
    ldr         w11, [x0, #CABAC_I_LOW]
    ldr         w2,  [x0, #CABAC_I_QUEUE]
    and         w1,  w1,  w12
    add         w11, w1,  w11, lsl #1
    adds        w2,  w2,  #1
    b.ge        cabac_putbyte
    str         w11, [x0, #CABAC_I_LOW]
    str         w2,  [x0, #CABAC_I_QUEUE]
    ret
endfunc

function cabac_encode_terminal_asm, export=1, align=5
    ldr         w12, [x0, #CABAC_I_RANGE]
    sub         w12, w12, #2
    tbz         w12, #8, 1f

    str         w12, [x0, #CABAC_I_RANGE]
    ret
1:
    ldr         w2,  [x0, #CABAC_I_QUEUE]
    ldr         w11, [x0, #CABAC_I_LOW]
    lsl         w12, w12, #1
    adds        w2,  w2,  #1
    lsl         w11, w11, #1
    b.ge        cabac_putbyte

    stp         w11, w12, [x0, #CABAC_I_LOW]    // store i_low, i_range
    str         w2,  [x0, #CABAC_I_QUEUE]
    ret
endfunc
