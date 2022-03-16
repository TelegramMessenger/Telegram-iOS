;*****************************************************************************
;* pixel-32.asm: x86_32 pixel metrics
;*****************************************************************************
;* Copyright (C) 2003-2022 x264 project
;*
;* Authors: Loren Merritt <lorenm@u.washington.edu>
;*          Laurent Aimar <fenrir@via.ecp.fr>
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

cextern pw_ppmmppmm
cextern pw_pmpmpmpm

SECTION .text
INIT_MMX mmx2

%if HIGH_BIT_DEPTH == 0

%macro LOAD_DIFF_4x8P 1 ; dx
    LOAD_DIFF  m0, m7, none, [r0+%1],      [r2+%1]
    LOAD_DIFF  m1, m6, none, [r0+%1+r1],   [r2+%1+r3]
    LOAD_DIFF  m2, m7, none, [r0+%1+r1*2], [r2+%1+r3*2]
    LOAD_DIFF  m3, m6, none, [r0+%1+r4],   [r2+%1+r5]
    lea  r0, [r0+4*r1]
    lea  r2, [r2+4*r3]
    LOAD_DIFF  m4, m7, none, [r0+%1],      [r2+%1]
    LOAD_DIFF  m5, m6, none, [r0+%1+r1],   [r2+%1+r3]
    LOAD_DIFF  m6, m7, none, [r0+%1+r1*2], [r2+%1+r3*2]
    movq [spill], m5
    LOAD_DIFF  m7, m5, none, [r0+%1+r4],   [r2+%1+r5]
    movq m5, [spill]
%endmacro

%macro SUM4x8_MM 0
    movq [spill],   m6
    movq [spill+8], m7
    ABSW2    m0, m1, m0, m1, m6, m7
    ABSW2    m2, m3, m2, m3, m6, m7
    paddw    m0, m2
    paddw    m1, m3
    movq     m6, [spill]
    movq     m7, [spill+8]
    ABSW2    m4, m5, m4, m5, m2, m3
    ABSW2    m6, m7, m6, m7, m2, m3
    paddw    m4, m6
    paddw    m5, m7
    paddw    m0, m4
    paddw    m1, m5
    paddw    m0, m1
%endmacro

;-----------------------------------------------------------------------------
; int pixel_sa8d_8x8( uint8_t *, intptr_t, uint8_t *, intptr_t )
;-----------------------------------------------------------------------------
cglobal pixel_sa8d_8x8_internal
    push   r0
    push   r2
    sub    esp, 0x74
%define args  esp+0x74
%define spill esp+0x60 ; +16
%define trans esp+0    ; +96
    LOAD_DIFF_4x8P 0
    HADAMARD8_V 0, 1, 2, 3, 4, 5, 6, 7

    movq   [spill], m1
    TRANSPOSE4x4W 4, 5, 6, 7, 1
    movq   [trans+0x00], m4
    movq   [trans+0x08], m5
    movq   [trans+0x10], m6
    movq   [trans+0x18], m7
    movq   m1, [spill]
    TRANSPOSE4x4W 0, 1, 2, 3, 4
    movq   [trans+0x20], m0
    movq   [trans+0x28], m1
    movq   [trans+0x30], m2
    movq   [trans+0x38], m3

    mov    r0, [args+4]
    mov    r2, [args]
    LOAD_DIFF_4x8P 4
    HADAMARD8_V 0, 1, 2, 3, 4, 5, 6, 7

    movq   [spill], m7
    TRANSPOSE4x4W 0, 1, 2, 3, 7
    movq   [trans+0x40], m0
    movq   [trans+0x48], m1
    movq   [trans+0x50], m2
    movq   [trans+0x58], m3
    movq   m7, [spill]
    TRANSPOSE4x4W 4, 5, 6, 7, 1
    movq   m0, [trans+0x00]
    movq   m1, [trans+0x08]
    movq   m2, [trans+0x10]
    movq   m3, [trans+0x18]

    HADAMARD8_V 0, 1, 2, 3, 4, 5, 6, 7
    SUM4x8_MM
    movq   [trans], m0

    movq   m0, [trans+0x20]
    movq   m1, [trans+0x28]
    movq   m2, [trans+0x30]
    movq   m3, [trans+0x38]
    movq   m4, [trans+0x40]
    movq   m5, [trans+0x48]
    movq   m6, [trans+0x50]
    movq   m7, [trans+0x58]

    HADAMARD8_V 0, 1, 2, 3, 4, 5, 6, 7
    SUM4x8_MM

    pavgw  m0, [trans]
    add   esp, 0x7c
    ret
%undef args
%undef spill
%undef trans

%macro SUM_MM_X3 8 ; 3x sum, 4x tmp, op
    pxor        %7, %7
    pshufw      %4, %1, q1032
    pshufw      %5, %2, q1032
    pshufw      %6, %3, q1032
    paddusw     %1, %4
    paddusw     %2, %5
    paddusw     %3, %6
    punpcklwd   %1, %7
    punpcklwd   %2, %7
    punpcklwd   %3, %7
    pshufw      %4, %1, q1032
    pshufw      %5, %2, q1032
    pshufw      %6, %3, q1032
    %8          %1, %4
    %8          %2, %5
    %8          %3, %6
%endmacro

%macro LOAD_4x8P 1 ; dx
    pxor        m7, m7
    movd        m6, [r0+%1+7*FENC_STRIDE]
    movd        m0, [r0+%1+0*FENC_STRIDE]
    movd        m1, [r0+%1+1*FENC_STRIDE]
    movd        m2, [r0+%1+2*FENC_STRIDE]
    movd        m3, [r0+%1+3*FENC_STRIDE]
    movd        m4, [r0+%1+4*FENC_STRIDE]
    movd        m5, [r0+%1+5*FENC_STRIDE]
    punpcklbw   m6, m7
    punpcklbw   m0, m7
    punpcklbw   m1, m7
    movq   [spill], m6
    punpcklbw   m2, m7
    punpcklbw   m3, m7
    movd        m6, [r0+%1+6*FENC_STRIDE]
    punpcklbw   m4, m7
    punpcklbw   m5, m7
    punpcklbw   m6, m7
    movq        m7, [spill]
%endmacro

%macro HSUMSUB2 4
    pshufw m4, %1, %3
    pshufw m5, %2, %3
    pmullw %1, %4
    pmullw m5, %4
    paddw  %1, m4
    paddw  %2, m5
%endmacro

;-----------------------------------------------------------------------------
; void intra_sa8d_x3_8x8( uint8_t *fenc, uint8_t edge[36], int *res )
;-----------------------------------------------------------------------------
cglobal intra_sa8d_x3_8x8, 2,3
    SUB    esp, 0x94
%define edge  esp+0x70 ; +32
%define spill esp+0x60 ; +16
%define trans esp+0    ; +96
%define sum   esp+0    ; +32

    pxor      m7, m7
    movq      m0, [r1+7]
    movq      m2, [r1+16]
    movq      m1, m0
    movq      m3, m2
    punpcklbw m0, m7
    punpckhbw m1, m7
    punpcklbw m2, m7
    punpckhbw m3, m7
    movq      m6, [pw_ppmmppmm]
    HSUMSUB2  m0, m2, q1032, m6
    HSUMSUB2  m1, m3, q1032, m6
    movq      m6, [pw_pmpmpmpm]
    HSUMSUB2  m0, m2, q2301, m6
    HSUMSUB2  m1, m3, q2301, m6
    movq      m4, m0
    movq      m5, m2
    paddw     m0, m1
    paddw     m2, m3
    psubw     m4, m1
    psubw     m3, m5
    movq [edge+0], m0
    movq [edge+8], m4
    movq [edge+16], m2
    movq [edge+24], m3

    LOAD_4x8P 0
    HADAMARD8_V 0, 1, 2, 3, 4, 5, 6, 7

    movq   [spill], m0
    TRANSPOSE4x4W 4, 5, 6, 7, 0
    movq   [trans+0x00], m4
    movq   [trans+0x08], m5
    movq   [trans+0x10], m6
    movq   [trans+0x18], m7
    movq   m0, [spill]
    TRANSPOSE4x4W 0, 1, 2, 3, 4
    movq   [trans+0x20], m0
    movq   [trans+0x28], m1
    movq   [trans+0x30], m2
    movq   [trans+0x38], m3

    LOAD_4x8P 4
    HADAMARD8_V 0, 1, 2, 3, 4, 5, 6, 7

    movq   [spill], m7
    TRANSPOSE4x4W 0, 1, 2, 3, 7
    movq   [trans+0x40], m0
    movq   [trans+0x48], m1
    movq   [trans+0x50], m2
    movq   [trans+0x58], m3
    movq   m7, [spill]
    TRANSPOSE4x4W 4, 5, 6, 7, 0
    movq   m0, [trans+0x00]
    movq   m1, [trans+0x08]
    movq   m2, [trans+0x10]
    movq   m3, [trans+0x18]

    HADAMARD8_V 0, 1, 2, 3, 4, 5, 6, 7

    movq [spill+0], m0
    movq [spill+8], m1
    ABSW2    m2, m3, m2, m3, m0, m1
    ABSW2    m4, m5, m4, m5, m0, m1
    paddw    m2, m4
    paddw    m3, m5
    ABSW2    m6, m7, m6, m7, m4, m5
    movq     m0, [spill+0]
    movq     m1, [spill+8]
    paddw    m2, m6
    paddw    m3, m7
    paddw    m2, m3
    ABSW     m1, m1, m4
    paddw    m2, m1 ; 7x4 sum
    movq     m7, m0
    movq     m1, [edge+8] ; left bottom
    psllw    m1, 3
    psubw    m7, m1
    ABSW2    m0, m7, m0, m7, m5, m3
    paddw    m0, m2
    paddw    m7, m2
    movq [sum+0], m0 ; dc
    movq [sum+8], m7 ; left

    movq   m0, [trans+0x20]
    movq   m1, [trans+0x28]
    movq   m2, [trans+0x30]
    movq   m3, [trans+0x38]
    movq   m4, [trans+0x40]
    movq   m5, [trans+0x48]
    movq   m6, [trans+0x50]
    movq   m7, [trans+0x58]

    HADAMARD8_V 0, 1, 2, 3, 4, 5, 6, 7

    movd   [sum+0x10], m0
    movd   [sum+0x12], m1
    movd   [sum+0x14], m2
    movd   [sum+0x16], m3
    movd   [sum+0x18], m4
    movd   [sum+0x1a], m5
    movd   [sum+0x1c], m6
    movd   [sum+0x1e], m7

    movq [spill],   m0
    movq [spill+8], m1
    ABSW2    m2, m3, m2, m3, m0, m1
    ABSW2    m4, m5, m4, m5, m0, m1
    paddw    m2, m4
    paddw    m3, m5
    paddw    m2, m3
    movq     m0, [spill]
    movq     m1, [spill+8]
    ABSW2    m6, m7, m6, m7, m4, m5
    ABSW     m1, m1, m3
    paddw    m2, m7
    paddw    m1, m6
    paddw    m2, m1 ; 7x4 sum
    movq     m1, m0

    movq     m7, [edge+0]
    psllw    m7, 3   ; left top

    mov      r2, [edge+0]
    add      r2, [edge+16]
    lea      r2, [4*r2+32]
    and      r2, 0xffc0
    movd     m6, r2 ; dc

    psubw    m1, m7
    psubw    m0, m6
    ABSW2    m0, m1, m0, m1, m5, m6
    movq     m3, [sum+0] ; dc
    paddw    m0, m2
    paddw    m1, m2
    movq     m2, m0
    paddw    m0, m3
    paddw    m1, [sum+8] ; h
    psrlq    m2, 16
    paddw    m2, m3

    movq     m3, [edge+16] ; top left
    movq     m4, [edge+24] ; top right
    psllw    m3, 3
    psllw    m4, 3
    psubw    m3, [sum+16]
    psubw    m4, [sum+24]
    ABSW2    m3, m4, m3, m4, m5, m6
    paddw    m2, m3
    paddw    m2, m4 ; v

    SUM_MM_X3 m0, m1, m2, m3, m4, m5, m6, pavgw
    mov      r2, r2m
    pxor      m7, m7
    punpckldq m2, m1
    pavgw     m0, m7
    pavgw     m2, m7
    movd  [r2+8], m0 ; dc
    movq  [r2+0], m2 ; v, h
    ADD     esp, 0x94
    RET
%undef edge
%undef spill
%undef trans
%undef sum



;-----------------------------------------------------------------------------
; void pixel_ssim_4x4x2_core( const uint8_t *pix1, intptr_t stride1,
;                             const uint8_t *pix2, intptr_t stride2, int sums[2][4] )
;-----------------------------------------------------------------------------
cglobal pixel_ssim_4x4x2_core, 0,5
    mov       r1, r1m
    mov       r3, r3m
    mov       r4, 4
    pxor      m0, m0
.loop:
    mov       r0, r0m
    mov       r2, r2m
    add       r0, r4
    add       r2, r4
    pxor      m1, m1
    pxor      m2, m2
    pxor      m3, m3
    pxor      m4, m4
%rep 4
    movd      m5, [r0]
    movd      m6, [r2]
    punpcklbw m5, m0
    punpcklbw m6, m0
    paddw     m1, m5
    paddw     m2, m6
    movq      m7, m5
    pmaddwd   m5, m5
    pmaddwd   m7, m6
    pmaddwd   m6, m6
    paddd     m3, m5
    paddd     m4, m7
    paddd     m3, m6
    add       r0, r1
    add       r2, r3
%endrep
    mov       r0, r4m
    lea       r0, [r0+r4*4]
    pshufw    m5, m1, q0032
    pshufw    m6, m2, q0032
    paddusw   m1, m5
    paddusw   m2, m6
    punpcklwd m1, m2
    pshufw    m2, m1, q0032
    pshufw    m5, m3, q0032
    pshufw    m6, m4, q0032
    paddusw   m1, m2
    paddd     m3, m5
    paddd     m4, m6
    punpcklwd m1, m0
    punpckldq m3, m4
    movq  [r0+0], m1
    movq  [r0+8], m3
    sub       r4, 4
    jge .loop
    emms
    RET

%endif ; !HIGH_BIT_DEPTH
