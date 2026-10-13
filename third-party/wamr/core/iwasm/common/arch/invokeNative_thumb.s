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

        push    {r4, r5, r6, r7}
        push    {lr}
        sub     sp, sp, #4      /* make sp 8 byte aligned */
        mov     ip, r0          /* ip = function ptr */
        mov     r4, r1          /* r4 = argv */
        mov     r5, r2          /* r5 = argc */

        cmp     r5, #1          /* at least one argument required: exec_env */
        blt     return

        mov     r6, #0          /* increased stack size */

        ldr     r0, [r4]        /* r0 = argv[0] = exec_env */
        add     r4, r4, #4      /* r4 += 4 */
        cmp     r5, #1
        beq     call_func

        ldr     r1, [r4]        /* r1 = argv[1] */
        add     r4, r4, #4
        cmp     r5, #2
        beq     call_func

        ldr     r2, [r4]        /* r2 = argv[2] */
        add     r4, r4, #4
        cmp     r5, #3
        beq     call_func

        ldr     r3, [r4]        /* r3 = argv[3] */
        add     r4, r4, #4
        cmp     r5, #4
        beq     call_func

        sub    r5, r5, #4       /* argc -= 4, now we have r0 ~ r3 */

        /* Ensure address is 8 byte aligned */
        lsl     r6, r5, #2      /* r6 = argc * 4 */
        mov     r7, #7
        add     r6, r6, r7      /* r6 = (r6 + 7) & ~7 */
        bic     r6, r6, r7
        add     r6, r6, #4      /* +4 because odd(5) registers are in stack */
        mov     r7, sp
        sub     r7, r7, r6      /* reserved stack space for left arguments */
        mov     sp, r7

        mov     lr, r2          /* save r2 */
loop_args:                      /* copy left arguments to stack */
        cmp     r5, #0
        beq     call_func1
        ldr     r2, [r4]
        add     r4, r4, #4
        str     r2, [r7]
        add     r7, r7, #4
        sub     r5, r5, #1
        b       loop_args

call_func1:
        mov     r2, lr          /* restore r2 */

call_func:
        blx     ip
        add     sp, sp, r6       /* restore sp */

return:
        add     sp, sp, #4      /* make sp 8 byte aligned */
        pop     {r3}
        pop     {r4, r5, r6, r7}
        mov     lr, r3
        bx      lr
