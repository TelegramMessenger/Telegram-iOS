/****************************************************************************
 * checkasm-arm.S: assembly check tool
 *****************************************************************************
 * Copyright (C) 2015-2022 x264 project
 *
 * Authors: Martin Storsjo <martin@martin.st>
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

#include "../common/arm/asm.S"

const register_init, align=4
.quad 0x21f86d66c8ca00ce
.quad 0x75b6ba21077c48ad
.quad 0xed56bb2dcb3c7736
.quad 0x8bda43d3fd1a7e06
.quad 0xb64a9c9e5d318408
.quad 0xdf9a54b303f1d3a3
.quad 0x4a75479abd64e097
.quad 0x249214109d5d1c88
endconst

const error_message
.asciz "failed to preserve register"
endconst

.text

@ max number of args used by any x264 asm function.
#define MAX_ARGS 15

#define ARG_STACK 4*(MAX_ARGS - 4)

@ align the used stack space to 8 to preserve the stack alignment
#define ARG_STACK_A (((ARG_STACK + pushed + 7) & ~7) - pushed)

.macro clobbercheck variant
.equ pushed, 4*10
function checkasm_call_\variant
    push        {r4-r11, lr}
.ifc \variant, neon
    vpush       {q4-q7}
.equ pushed, pushed + 16*4
.endif

    movrel      r12, register_init
.ifc \variant, neon
    vldm        r12, {q4-q7}
.endif
    ldm         r12, {r4-r11}

    push        {r1}

    sub         sp,  sp,  #ARG_STACK_A
.equ pos, 0
.rept MAX_ARGS-4
    ldr         r12, [sp, #ARG_STACK_A + pushed + 8 + pos]
    str         r12, [sp, #pos]
.equ pos, pos + 4
.endr

    mov         r12, r0
    mov         r0,  r2
    mov         r1,  r3
    ldrd        r2,  r3,  [sp, #ARG_STACK_A + pushed]
    blx         r12
    add         sp,  sp,  #ARG_STACK_A
    pop         {r2}

    push        {r0, r1}
    movrel      r12, register_init
.ifc \variant, neon
    vldm        r12, {q0-q3}
    veor        q0,  q0,  q4
    veor        q1,  q1,  q5
    veor        q2,  q2,  q6
    veor        q3,  q3,  q7
    vorr        q0,  q0,  q1
    vorr        q0,  q0,  q2
    vorr        q0,  q0,  q3
    vorr        d0,  d0,  d1
    vrev64.32   d1,  d0
    vorr        d0,  d0,  d1
    vmov.32     r3,  d0[0]
.else
    mov         r3,  #0
.endif

.macro check_reg reg1, reg2=
    ldrd        r0,  r1,  [r12], #8
    eor         r0,  r0, \reg1
    orr         r3,  r3, r0
.ifnb \reg2
    eor         r1,  r1, \reg2
    orr         r3,  r3, r1
.endif
.endm
    check_reg   r4,  r5
    check_reg   r6,  r7
@ r9 is a volatile register in the ios ABI
#if SYS_MACOSX
    check_reg   r8
#else
    check_reg   r8,  r9
#endif
    check_reg   r10, r11
.purgem check_reg

    cmp         r3,  #0
    beq         0f

    mov         r12, #0
    str         r12, [r2]
    movrel      r0, error_message
    blx         EXT(puts)
0:
    pop         {r0, r1}
.ifc \variant, neon
    vpop        {q4-q7}
.endif
    pop         {r4-r11, pc}
endfunc
.endm

clobbercheck neon
clobbercheck noneon
