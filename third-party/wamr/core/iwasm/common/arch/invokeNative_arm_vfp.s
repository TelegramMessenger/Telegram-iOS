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

        stmfd   sp!, {r4, r5, r6, r7, lr}
        sub     sp, sp, #4      /* make sp 8 byte aligned */
        mov     ip, r0          /* ip = function ptr */
        mov     r4, r1          /* r4 = argv */
        mov     r5, r2          /* r5 = nstacks */
        mov     r6, sp

        /* Fill all int args */
        ldr     r0, [r4], #4    /* r0 = *(int*)&argv[0] = exec_env */
        ldr     r1, [r4], #4    /* r1 = *(int*)&argv[1] */
        ldr     r2, [r4], #4    /* r2 = *(int*)&argv[2] */
        ldr     r3, [r4], #4    /* r3 = *(int*)&argv[3] */

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


        /* Fill all stack args: reserve stack space and fill one by one */
        add     r4, r4, #64     /* r4 points to stack args */
        bic     sp, sp, #7      /* Ensure stack is 8 byte aligned */
        mov     r7, r5, lsl#2   /* r7 = nstacks * 4 */
        add     r7, r7, #7      /* r7 = (r7 + 7) & ~7 */
        bic     r7, r7, #7
        sub     sp, sp, r7      /* reserved stack space for stack arguments */
        mov     r7, sp

loop_stack_args:                /* copy stack arguments to stack */
        cmp     r5, #0
        beq     call_func
        ldr     lr, [r4], #4    /* Note: caller should insure int64 and */
        str     lr, [r7], #4    /* double are placed in 8 bytes aligned address */
        sub     r5, r5, #1
        b       loop_stack_args

call_func:
        blx     ip
        mov     sp, r6          /* restore sp */

return:
        add     sp, sp, #4      /* make sp 8 byte aligned */
        ldmfd   sp!, {r4, r5, r6, r7, lr}
        bx      lr

