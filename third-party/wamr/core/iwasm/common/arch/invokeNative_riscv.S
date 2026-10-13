/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

/*
 * The float abi macros used below are from risc-v c api:
 * https://github.com/riscv/riscv-c-api-doc/blob/master/riscv-c-api.md
 *
 */

#if defined(__riscv_float_abi_soft)
#define RV_FPREG_SIZE    0
#elif defined(__riscv_float_abi_single)
#define RV_OP_LOADFPREG  flw
#define RV_OP_STROEFPREG fsw
#define RV_FPREG_SIZE    4
#elif defined(__riscv_float_abi_double)
#define RV_OP_LOADFPREG  fld
#define RV_OP_STROEFPREG fsd
#define RV_FPREG_SIZE    8
#endif

#if __riscv_xlen == 32
#define RV_OP_LOADREG  lw
#define RV_OP_STOREREG sw
#define RV_REG_SIZE    4
#define RV_REG_SHIFT   2
#define RV_FP_OFFSET   (8 * RV_REG_SIZE)
#define RV_INT_OFFSET  0
#else
#define RV_OP_LOADREG  ld
#define RV_OP_STOREREG sd
#define RV_REG_SIZE    8
#define RV_REG_SHIFT   3
#define RV_FP_OFFSET   0
#define RV_INT_OFFSET  (8 * RV_FPREG_SIZE)
#endif

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
 * a0 function ptr
 * a1 argv
 * a2 nstacks
 */

/*
 * sp (stack pointer)
 *    |- sd/sw to store 64/32-bit values from register to memory
 *    |- ld/lw to load from stack to register
 * fp/s0 (frame pointer)
 * a0-a7 (8 integer arguments)
 *    |- sd/sw to store
 *    |- ld/lw to load
 * fa0-a7 (8 float arguments)
 *    |- fsd/fsw to store
 *    |- fld/fsw to load
 * t0-t6 (temporaries regisgers)
 *    |- caller saved
 */

        /* reserve space on stack to save return address and frame pointer */
        addi             sp, sp, - 2 * RV_REG_SIZE
        RV_OP_STOREREG   fp, 0 * RV_REG_SIZE(sp)    /* save frame pointer */
        RV_OP_STOREREG   ra, 1 * RV_REG_SIZE(sp)    /* save return address */

        mv               fp, sp                     /* set frame pointer to bottom of fixed frame */

        /* save function ptr, argv & nstacks */
        mv               t0, a0                     /* t0 = function ptr */
        mv               t1, a1                     /* t1 = argv array address */
        mv               t2, a2                     /* t2 = nstack */

#ifndef __riscv_float_abi_soft
        /* fill in fa0-7 float-registers*/
        RV_OP_LOADFPREG  fa0, RV_FP_OFFSET + 0 * RV_FPREG_SIZE(t1) /* fa0 */
        RV_OP_LOADFPREG  fa1, RV_FP_OFFSET + 1 * RV_FPREG_SIZE(t1) /* fa1 */
        RV_OP_LOADFPREG  fa2, RV_FP_OFFSET + 2 * RV_FPREG_SIZE(t1) /* fa2 */
        RV_OP_LOADFPREG  fa3, RV_FP_OFFSET + 3 * RV_FPREG_SIZE(t1) /* fa3 */
        RV_OP_LOADFPREG  fa4, RV_FP_OFFSET + 4 * RV_FPREG_SIZE(t1) /* fa4 */
        RV_OP_LOADFPREG  fa5, RV_FP_OFFSET + 5 * RV_FPREG_SIZE(t1) /* fa5 */
        RV_OP_LOADFPREG  fa6, RV_FP_OFFSET + 6 * RV_FPREG_SIZE(t1) /* fa6 */
        RV_OP_LOADFPREG  fa7, RV_FP_OFFSET + 7 * RV_FPREG_SIZE(t1) /* fa7 */
#endif

        /* fill in a0-7 integer-registers*/
        RV_OP_LOADREG    a0, RV_INT_OFFSET + 0 * RV_REG_SIZE(t1)    /* a0 */
        RV_OP_LOADREG    a1, RV_INT_OFFSET + 1 * RV_REG_SIZE(t1)    /* a1 */
        RV_OP_LOADREG    a2, RV_INT_OFFSET + 2 * RV_REG_SIZE(t1)    /* a2 */
        RV_OP_LOADREG    a3, RV_INT_OFFSET + 3 * RV_REG_SIZE(t1)    /* a3 */
        RV_OP_LOADREG    a4, RV_INT_OFFSET + 4 * RV_REG_SIZE(t1)    /* a4 */
        RV_OP_LOADREG    a5, RV_INT_OFFSET + 5 * RV_REG_SIZE(t1)    /* a5 */
        RV_OP_LOADREG    a6, RV_INT_OFFSET + 6 * RV_REG_SIZE(t1)    /* a6 */
        RV_OP_LOADREG    a7, RV_INT_OFFSET + 7 * RV_REG_SIZE(t1)    /* a7 */

        /* t1 points to stack args */

        /* RV_FPREG_SIZE is zero when __riscv_float_abi_soft defined */
        addi             t1, t1, RV_REG_SIZE * 8 + RV_FPREG_SIZE * 8

        /* directly call the function if no args in stack,
           x0 always holds 0 */
        beq              t2, x0, call_func

        /* reserve enough stack space for function arguments */
        sll              t3, t2, RV_REG_SHIFT       /* shift left 3 bits. t3 = n_stacks * 8 */
        sub              sp, sp, t3

        /* make 16-byte aligned */
        li               t3, 15
        not              t3, t3
        and              sp, sp, t3

        /* save sp in t4 register */
        mv               t4, sp

        /* copy left arguments from caller stack to own frame stack */
loop_stack_args:
        beq              t2, x0, call_func
        RV_OP_LOADREG    t5, 0(t1)                  /* load stack argument, t5 = argv[i] */
        RV_OP_STOREREG   t5, 0(t4)                  /* store t5 to reserved stack, sp[j] = t5 */
        addi             t1, t1, RV_REG_SIZE        /* move to next stack argument */
        addi             t4, t4, RV_REG_SIZE        /* move to next stack pointer */
        addi             t2, t2, -1                 /* decrease t2 every loop, nstacks = nstacks -1 */
        j loop_stack_args

call_func:
        jalr             t0

        /* restore registers pushed in stack or saved in another register */
return:
        mv               sp, fp                     /* restore sp saved in fp before function call */
        RV_OP_LOADREG    fp, 0 * RV_REG_SIZE(sp)    /* load previous frame pointer to fp register */
        RV_OP_LOADREG    ra, 1 * RV_REG_SIZE(sp)    /* load previous return address to ra register */
        addi             sp, sp, 2 * RV_REG_SIZE    /* pop frame, restore sp */
        jr               ra
