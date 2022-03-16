;*****************************************************************************
;* bitstream-a.asm: x86 bitstream functions
;*****************************************************************************
;* Copyright (C) 2010-2022 x264 project
;*
;* Authors: Fiona Glaser <fiona@x264.com>
;*          Henrik Gramner <henrik@gramner.com>
;*
;* This program is free software; you can redistribute it and/or modify
;* it under the terms of the GNU General Public License as published by
;* the Free Software Foundation; either version 2 of the License, or
;* (at your option) any later version.
;*
;* This program is distributed in the hope that it will be useful,
;* but WITHOUT ANY WARRANTY; without even the implied warranty of
;* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;* GNU General Public License for more details.
;*
;* You should have received a copy of the GNU General Public License
;* along with this program; if not, write to the Free Software
;* Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02111, USA.
;*
;* This program is also available under a commercial proprietary license.
;* For more information, contact us at licensing@x264.com.
;*****************************************************************************

%include "x86inc.asm"
%include "x86util.asm"

SECTION .text

;-----------------------------------------------------------------------------
; uint8_t *x264_nal_escape( uint8_t *dst, uint8_t *src, uint8_t *end )
;-----------------------------------------------------------------------------
%macro NAL_LOOP 2
%%escape:
    ; Detect false positive to avoid unnecessary escape loop
    xor      r3d, r3d
    cmp byte [r0+r1-1], 0
    setnz    r3b
    xor       k3, k4
    jnz .escape
    jmp %%continue
ALIGN 16
%1:
    mova [r0+r1+mmsize], m1
    pcmpeqb   m1, m0
    mova [r0+r1], m2
    pcmpeqb   m2, m0
    pmovmskb r3d, m1
    %2        m1, [r1+r2+3*mmsize]
    pmovmskb r4d, m2
    %2        m2, [r1+r2+2*mmsize]
    shl       k3, mmsize
    or        k3, k4
    lea       k4, [2*r3+1]
    and       k4, k3
    jnz %%escape
%%continue:
    add       r1, 2*mmsize
    jl %1
%endmacro

%macro NAL_ESCAPE 0
%if mmsize == 32
    %xdefine k3 r3
    %xdefine k4 r4
%else
    %xdefine k3 r3d
    %xdefine k4 r4d
%endif

cglobal nal_escape, 3,5
    movzx    r3d, byte [r1]
    sub       r1, r2 ; r1 = offset of current src pointer from end of src
    pxor      m0, m0
    mov     [r0], r3b
    sub       r0, r1 ; r0 = projected end of dst, assuming no more escapes
    or       r3d, 0xffffff00 ; ignore data before src

    ; Start off by jumping into the escape loop in case there's an escape at the start.
    ; And do a few more in scalar until dst is aligned.
    jmp .escape_loop

%if mmsize == 16
    NAL_LOOP .loop_aligned, mova
    jmp .ret
%endif
    NAL_LOOP .loop_unaligned, movu
.ret:
    movifnidn rax, r0
    RET

.escape:
    ; Skip bytes that are known to be valid
    and       k4, k3
    tzcnt     k4, k4
    xor      r3d, r3d ; the last two bytes are known to be zero
    add       r1, r4
.escape_loop:
    inc       r1
    jge .ret
    movzx    r4d, byte [r1+r2]
    shl      r3d, 8
    or       r3d, r4d
    test     r3d, 0xfffffc ; if the last two bytes are 0 and the current byte is <=3
    jz .add_escape_byte
.escaped:
    lea      r4d, [r0+r1]
    mov  [r0+r1], r3b
    test     r4d, mmsize-1 ; Do SIMD when dst is aligned
    jnz .escape_loop
    movu      m1, [r1+r2+mmsize]
    movu      m2, [r1+r2]
%if mmsize == 16
    lea      r4d, [r1+r2]
    test     r4d, mmsize-1
    jz .loop_aligned
%endif
    jmp .loop_unaligned

.add_escape_byte:
    mov byte [r0+r1], 3
    inc       r0
    or       r3d, 0x0300
    jmp .escaped
%endmacro

INIT_MMX mmx2
NAL_ESCAPE
INIT_XMM sse2
NAL_ESCAPE
%if ARCH_X86_64
INIT_YMM avx2
NAL_ESCAPE
%endif
