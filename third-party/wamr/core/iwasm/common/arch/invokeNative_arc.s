/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

    .text
    .align  2
#ifndef BH_PLATFORM_DARWIN
    .globl invokeNative
    .type  invokeNative, function
invokeNative:
#else
    .globl _invokeNative
_invokeNative:
#endif /* end of BH_PLATFORM_DARWIN */

/*
 * Arguments passed in:
 *   r0: function ptr
 *   r1: argv
 *   r2: nstacks
 * ARC ABI:
 *   r0-r7:  function arguments, caller-saved
 *   r8-r12: temp registers, caller-saved
 */

    push_s  blink               /* push return addr */
    st.aw   fp, [sp, -4]        /* push fp */
    mov     fp, sp              /* fp = sp */

    mov     r8, r0              /* r8 = func_ptr */
    mov     r9, r1              /* r9 = argv */
    mov     r10, r2             /* r10 = nstacks */

    ld      r0, [r9, 0]         /* r0 = argv[0] */
    ld      r1, [r9, 4]         /* r1 = argv[1] */
    ld      r2, [r9, 8]         /* r2 = argv[2] */
    ld      r3, [r9, 12]        /* r3 = argv[3] */
    ld      r4, [r9, 16]        /* r4 = argv[4] */
    ld      r5, [r9, 20]        /* r5 = argv[5] */
    ld      r6, [r9, 24]        /* r6 = argv[6] */
    ld      r7, [r9, 28]        /* r7 = argv[7] */

    add     r9, r9, 32          /* r9 = stack_args */
    breq    r10, 0, call_func   /* if (r10 == 0) goto call_func */

    asl     r11, r10, 2         /* r11 = nstacks * 4 */
    sub     sp, sp, r11         /* sp = sp - nstacks * 4 */
    and     sp, sp, ~7          /* make sp 8-byte aligned */
    mov     r11, sp             /* r11 = sp */

loop_stack_args:
    breq    r10, 0, call_func   /* if (r10 == 0) goto call_func */
    ld      r12, [r9]           /* r12 = stack_args[i] */
    st      r12, [r11]          /* stack[i] = r12 */
    add     r9, r9, 4           /* r9 = r9 + 4 */
    add     r11, r11, 4         /* r11 = r11 + 4 */
    sub     r10, r10, 1         /* r10 = r10 + 1 */
    j       loop_stack_args

call_func:
    jl      [r8]                /* call function */

    mov     sp, fp              /* sp = fp */
    ld.ab   fp, [sp, 4]         /* pop fp */
    pop_s   blink               /* pop return addr */
    j_s     [blink]             /* ret */
    nop_s

