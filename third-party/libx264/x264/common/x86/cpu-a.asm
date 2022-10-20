;*****************************************************************************
;* cpu-a.asm: x86 cpu utilities
;*****************************************************************************
;* Copyright (C) 2003-2022 x264 project
;*
;* Authors: Laurent Aimar <fenrir@via.ecp.fr>
;*          Loren Merritt <lorenm@u.washington.edu>
;*          Fiona Glaser <fiona@x264.com>
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

SECTION .text

;-----------------------------------------------------------------------------
; void cpu_cpuid( int op, int *eax, int *ebx, int *ecx, int *edx )
;-----------------------------------------------------------------------------
cglobal cpu_cpuid, 5,7
    push rbx
    push  r4
    push  r3
    push  r2
    push  r1
    mov  eax, r0d
    xor  ecx, ecx
    cpuid
    pop   r4
    mov [r4], eax
    pop   r4
    mov [r4], ebx
    pop   r4
    mov [r4], ecx
    pop   r4
    mov [r4], edx
    pop  rbx
    RET

;-----------------------------------------------------------------------------
; uint64_t cpu_xgetbv( int xcr )
;-----------------------------------------------------------------------------
cglobal cpu_xgetbv
    movifnidn ecx, r0m
    xgetbv
%if ARCH_X86_64
    shl       rdx, 32
    or        rax, rdx
%endif
    ret

;-----------------------------------------------------------------------------
; void cpu_emms( void )
;-----------------------------------------------------------------------------
cglobal cpu_emms
    emms
    ret

;-----------------------------------------------------------------------------
; void cpu_sfence( void )
;-----------------------------------------------------------------------------
cglobal cpu_sfence
    sfence
    ret

%if ARCH_X86_64 == 0
;-----------------------------------------------------------------------------
; int cpu_cpuid_test( void )
; return 0 if unsupported
;-----------------------------------------------------------------------------
cglobal cpu_cpuid_test
    pushfd
    push    ebx
    push    ebp
    push    esi
    push    edi
    pushfd
    pop     eax
    mov     ebx, eax
    xor     eax, 0x200000
    push    eax
    popfd
    pushfd
    pop     eax
    xor     eax, ebx
    pop     edi
    pop     esi
    pop     ebp
    pop     ebx
    popfd
    ret
%endif
