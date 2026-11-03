;
; Copyright (C) 2019 Intel Corporation.  All rights reserved.
; SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
;

_TEXT  SEGMENT
    ; rcx func_ptr
    ; rdx argv
    ; r8 n_stacks

invokeNative PROC
    push rbp
    mov rbp, rsp

    mov r10, rcx    ; func_ptr
    mov rax, rdx    ; argv
    mov rcx, r8     ; n_stacks

; fill all fp args
    movdqu xmm0, xmmword ptr [rax + 0]
    movdqu xmm1, xmmword ptr [rax + 16]
    movdqu xmm2, xmmword ptr [rax + 32]
    movdqu xmm3, xmmword ptr [rax + 48]

; check for stack args
    cmp rcx, 0
    jz cycle_end

    mov rdx, rsp
    and rdx, 15
    jz no_abort
    int 3
no_abort:
    mov rdx, rcx
    and rdx, 1
    shl rdx, 3
    sub rsp, rdx

; store stack args
    lea r9, qword ptr [rax + rcx * 8 + 88]
    sub r9, rsp ; offset
cycle:
    push qword ptr [rsp + r9]
    loop cycle

cycle_end:
    mov rcx, [rax + 64]
    mov rdx, [rax + 72]
    mov r8,  [rax + 80]
    mov r9,  [rax + 88]

    sub rsp, 32 ; shadow space

    call r10
    leave
    ret

invokeNative ENDP

_TEXT   ENDS

END
