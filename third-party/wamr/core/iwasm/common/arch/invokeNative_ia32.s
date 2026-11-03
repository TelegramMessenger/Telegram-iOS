/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

    .text
    .align 2
#ifndef BH_PLATFORM_DARWIN
.globl invokeNative
    .type   invokeNative, @function
invokeNative:
#else
.globl _invokeNative
_invokeNative:
#endif /* end of BH_PLATFORM_DARWIN */
    push    %ebp
    movl    %esp, %ebp
    movl    16(%ebp), %ecx          /* ecx = argc */
    leal    2(%ecx), %edx           /* edx = ecx + 2 (count return address and saved ebp) */
    andl    $3, %edx                /* edx = edx % 4 */
    jz   stack_aligned              /* if edx == 0, stack is already 16 bytes aligned */
    leal    -16(%esp, %edx, 4), %esp /* esp = esp - 16 + edx * 4 */
stack_aligned:
    test    %ecx, %ecx
    jz      skip_push_args          /* if ecx == 0, skip pushing arguments */
    movl    12(%ebp), %edx          /* edx = argv */
    leal    -4(%edx,%ecx,4), %edx   /* edx = edx + ecx * 4 - 4 */
    subl    %esp, %edx              /* edx = edx - esp */
1:
    push    0(%esp,%edx)
    loop    1b                      /* loop ecx counts */
skip_push_args:
    movl    8(%ebp), %edx           /* edx = func_ptr */
    call    *%edx
    leave
    ret

