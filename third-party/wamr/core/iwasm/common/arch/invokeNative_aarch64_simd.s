/*
 * Copyright (C) 2020 Intel Corporation Corporation.  All rights reserved.
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
 * x0 function ptr
 * x1 argv
 * x2 nstacks
 */

        sub     sp, sp, #0x30
        stp     x19, x20, [sp, #0x20] /* save the registers */
        stp     x21, x22, [sp, #0x10]
        stp     x23, x24, [sp, #0x0]

        mov     x19, x0          /* x19 = function ptr */
        mov     x20, x1          /* x20 = argv */
        mov     x21, x2          /* x21 = nstacks */
        mov     x22, sp          /* save the sp before call function */

        /* Fill in float-point registers */
        ld1    {v0.2D, v1.2D, v2.2D, v3.2D}, [x20], #64 /* v0 = argv[0], v1 = argv[1], v2 = argv[2], v3 = argv[3]*/
        ld1    {v4.2D, v5.2D, v6.2D, v7.2D}, [x20], #64 /* v4 = argv[4], v5 = argv[5], v6 = argv[6], v7 = argv[7]*/

        /* Fill inteter registers */
        ldp     x0, x1, [x20], #16 /* x0 = argv[8] = exec_env, x1 = argv[9] */
        ldp     x2, x3, [x20], #16 /* x2 = argv[10], x3 = argv[11] */
        ldp     x4, x5, [x20], #16 /* x4 = argv[12], x5 = argv[13] */
        ldp     x6, x7, [x20], #16 /* x6 = argv[14], x7 = argv[15] */

        /* Now x20 points to stack args */

        /* Directly call the function if no args in stack */
        cmp     x21, #0
        beq     call_func

        /* Fill all stack args: reserve stack space and fill one by one */
        mov     x23, sp
        bic     sp,  x23, #15    /* Ensure stack is 16 bytes aligned */
        lsl     x23, x21, #3     /* x23 = nstacks * 8 */
        add     x23, x23, #15    /* x23 = (x23 + 15) & ~15 */
        bic     x23, x23, #15
        sub     sp, sp, x23      /* reserved stack space for stack arguments */
        mov     x23, sp

loop_stack_args:                 /* copy stack arguments to stack */
        cmp     x21, #0
        beq     call_func
        ldr     x24, [x20], #8
        str     x24, [x23], #8
        sub     x21, x21, #1
        b       loop_stack_args

call_func:
        mov     x20, x30         /* save x30(lr) */
        blr     x19
        mov     sp, x22          /* restore sp which is saved before calling function*/

return:
        mov     x30,  x20              /* restore x30(lr) */
        ldp     x19, x20, [sp, #0x20]  /* restore the registers in stack */
        ldp     x21, x22, [sp, #0x10]
        ldp     x23, x24, [sp, #0x0]
        add     sp, sp, #0x30          /* restore sp */
        ret

