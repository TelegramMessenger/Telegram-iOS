/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

    .text
    .align 2
    .globl invokeNative
    .ent invokeNative
    .type invokeNative, @function

/**
 * On function entry parameters:
 * $4 = func_ptr
 * $5 = args
 * $6 = arg_num
 */

invokeNative:
    .frame $fp, 8, $0
    .mask 0x00000000, 0
    .fmask 0x00000000, 0

    /* Fixed part of frame */
    subu $sp, 8

    /* save registers */
    sw $31, 4($sp)
    sw $fp, 0($sp)

    /* set frame pointer to bottom of fixed frame */
    move $fp, $sp

    /* allocate enough stack space */
    sll $11, $6, 2  /* $11 == arg_num * 4 */
    subu $sp, $11

    /* make 8-byte aligned */
    and $sp, ~7

    move $9, $sp
    move $25, $4    /* $25 = func_ptr */

push_args:
    beq $6, 0, done /* arg_num == 0 ? */
    lw $8, 0($5)    /* $8 = *args */
    sw $8, 0($9)    /* store $8 to stack */
    addu $5, 4      /* args++ */
    addu $9, 4      /* sp++ */
    subu $6, 1      /* arg_num-- */
    j push_args

done:
    lw $4, 0($sp)   /* Load $4..$7 from stack */
    lw $5, 4($sp)
    lw $6, 8($sp)
    lw $7, 12($sp)
    ldc1 $f12, 0($sp) /* Load $f12, $f13, $f14, $f15 */
    ldc1 $f14, 8($sp)

    jalr $25       /* call function */

    nop

    /* restore saved registers */
    move $sp, $fp
    lw $31, 4($sp)
    lw $fp, 0($sp)

    /* pop frame */
    addu $sp, $sp, 8

    j $31
    .end invokeNative
