/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
        .text
        .align  2
        .global invokeNative
        .type   invokeNative,function

/*
 * Arguments passed in:
 *
 * a2 function pntr
 * a3 argv
 * a4 argc
 */

invokeNative:
        entry   a1, 256

        blti    a4, 1, return   /* at least one argument required: exec_env */

        /* register a10 ~ a15 are used to pass first 6 arguments */

        l32i.n  a10, a3, 0
        beqi    a4, 1, call_func

        l32i.n  a11, a3, 4
        beqi    a4, 2, call_func

        l32i.n  a12, a3, 8
        beqi    a4, 3, call_func

        l32i.n  a13, a3, 12
        beqi    a4, 4, call_func

        l32i.n  a14, a3, 16
        beqi    a4, 5, call_func

        l32i.n  a15, a3, 20
        beqi    a4, 6, call_func

        /* left arguments are passed through stack */

        addi    a4, a4, -6
        addi    a3, a3, 24  /* move argv pointer */
        mov.n   a6, a1      /* store stack pointer */
        addi    a7, a1, 256 /* stack boundary */

loop_args:
        beqi    a4, 0,  call_func
        bge     a6, a7, call_func  /* reach stack boundary */

        l32i.n  a5, a3, 0   /* load argument to a5 */
        s32i.n  a5, a6, 0   /* push data to stack */

        addi    a4, a4, -1  /* decrease argc */
        addi    a3, a3, 4   /* move argv pointer */
        addi    a6, a6, 4   /* move stack pointer */

        j       loop_args

call_func:
        mov.n   a8, a2
        callx8  a8

        /* the result returned from callee is stored in a2
           mov the result to a10 so the caller of this function
           can receive the value */
        mov.n   a2, a10
        mov.n   a3, a11

return:
        retw.n
