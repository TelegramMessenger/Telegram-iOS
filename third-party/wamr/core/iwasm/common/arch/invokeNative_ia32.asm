;
; Copyright (C) 2019 Intel Corporation.  All rights reserved.
; SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
;

    .386
    .model flat
    .code
_invokeNative PROC
    push    ebp
    mov     ebp,esp
    mov     ecx, [ebp+16]          ; ecx = argc */
    mov     edx, [ebp+12]          ; edx = argv */
    test    ecx, ecx
    jz      skip_push_args          ; if ecx == 0, skip pushing arguments */
    lea     edx, [edx+ecx*4-4]   ; edx = edx + ecx * 4 - 4 */
    sub     edx,esp              ; edx = edx - esp */
loop_push:
    push    [esp+edx]
    loop    loop_push                      ; loop ecx counts */
skip_push_args:
    mov     edx, [ebp+8]           ; edx = func_ptr */
    call    edx
    leave
    ret
_invokeNative ENDP
END