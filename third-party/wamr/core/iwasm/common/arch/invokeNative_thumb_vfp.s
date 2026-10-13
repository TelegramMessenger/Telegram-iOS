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
 *
 * r0 function ptr
 * r1 argv
 * r2 nstacks
 */

        push    {r4, r5, r6, r7}
        push    {lr}
        sub     sp, sp, #4      /* make sp 8 byte aligned */
        mov     ip, r0          /* ip = function ptr */
        mov     r4, r1          /* r4 = argv */
        mov     r5, r2          /* r5 = nstacks */
        mov     r7, sp

        /* Fill all int args */
        ldr     r0, [r4, #0]    /* r0 = *(int*)&argv[0] = exec_env */
        ldr     r1, [r4, #4]    /* r1 = *(int*)&argv[1] */
        ldr     r2, [r4, #8]    /* r2 = *(int*)&argv[2] */
        ldr     r3, [r4, #12]   /* r3 = *(int*)&argv[3] */
        add     r4, r4, #16     /* r4 points to float args */

        /* Fill all float/double args to 16 single-precision registers, s0-s15, */
        /* which may also be accessed as 8 double-precision registers, d0-d7 (with */
        /* d0 overlapping s0, s1; d1 overlapping s2, s3; etc). */
        vldr    s0, [r4, #0]    /* s0 = *(float*)&argv[4] */
        vldr    s1, [r4, #4]
        vldr    s2, [r4, #8]
        vldr    s3, [r4, #12]
        vldr    s4, [r4, #16]
        vldr    s5, [r4, #20]
        vldr    s6, [r4, #24]
        vldr    s7, [r4, #28]
        vldr    s8, [r4, #32]
        vldr    s9, [r4, #36]
        vldr    s10, [r4, #40]
        vldr    s11, [r4, #44]
        vldr    s12, [r4, #48]
        vldr    s13, [r4, #52]
        vldr    s14, [r4, #56]
        vldr    s15, [r4, #60]
        /* Directly call the function if no args in stack */
        cmp     r5, #0
        beq     call_func

        mov     lr, r2          /* save r2 */

        /* Fill all stack args: reserve stack space and fill ony by one */
        add     r4, r4, #64     /* r4 points to stack args */
        mov     r6, sp
        mov     r7, #7
        bic     r6, r6, r7      /* Ensure stack is 8 byte aligned */
        lsl     r2, r5, #2      /* r2 = nstacks * 4 */
        add     r2, r2, #7      /* r2 = (r2 + 7) & ~7 */
        bic     r2, r2, r7
        sub     r6, r6, r2      /* reserved stack space for stack arguments */
        mov     r7, sp
        mov     sp, r6

loop_stack_args:                /* copy stack arguments to stack */
        cmp     r5, #0
        beq     call_func1
        ldr     r2, [r4]         /* Note: caller should insure int64 and */
        add     r4, r4, #4       /* double are placed in 8 bytes aligned address */
        str     r2, [r6]
        add     r6, r6, #4

        sub     r5, r5, #1
        b       loop_stack_args

call_func1:
        mov     r2, lr          /* restore r2 */

call_func:
        blx     ip
        mov     sp, r7          /* restore sp */

return:
        add     sp, sp, #4      /* make sp 8 byte aligned */
        pop     {r3}
        pop     {r4, r5, r6, r7}
        mov     lr, r3
        bx      lr

