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
 * r2 argc
 */

        stmfd   sp!, {r4, r5, r6, r7, lr}
        sub     sp, sp, #4      /* make sp 8 byte aligned */
        mov     ip, r0          /* ip = function ptr */
        mov     r4, r1          /* r4 = argv */
        mov     r5, r2          /* r5 = argc */

        cmp     r5, #1          /* at least one argument required: exec_env */
        blt     return

        mov     r6, #0          /* increased stack size */

        ldr     r0, [r4], #4    /* r0 = argv[0] = exec_env */
        cmp     r5, #1
        beq     call_func

        ldr     r1, [r4], #4    /* r1 = argv[1] */
        cmp     r5, #2
        beq     call_func

        ldr     r2, [r4], #4    /* r2 = argv[2] */
        cmp     r5, #3
        beq     call_func

        ldr     r3, [r4], #4    /* r3 = argv[3] */
        cmp     r5, #4
        beq     call_func

        sub    r5, r5, #4       /* argc -= 4, now we have r0 ~ r3 */

        /* Ensure address is 8 byte aligned */
        mov     r6, r5, lsl#2   /* r6 = argc * 4 */
        add     r6, r6, #7      /* r6 = (r6 + 7) & ~7 */
        bic     r6, r6, #7
        sub     sp, sp, r6      /* reserved stack space for left arguments */
        mov     r7, sp

loop_args:                      /* copy left arguments to stack */
        cmp     r5, #0
        beq     call_func
        ldr     lr, [r4], #4
        str     lr, [r7], #4
        sub     r5, r5, #1
        b       loop_args

call_func:
        blx     ip
        add     sp, sp, r6       /* restore sp */

return:
        add     sp, sp, #4
        ldmfd   sp!, {r4, r5, r6, r7, lr}
        bx      lr
