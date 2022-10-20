;*****************************************************************************
;* deblock-a.asm: x86 deblocking
;*****************************************************************************
;* Copyright (C) 2005-2022 x264 project
;*
;* Authors: Loren Merritt <lorenm@u.washington.edu>
;*          Fiona Glaser <fiona@x264.com>
;*          Oskar Arvidsson <oskar@irock.se>
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

SECTION_RODATA 64

load_bytes_zmm_shuf: dd 0x50404032, 0x70606053, 0xd0c0c0b4, 0xf0e0e0d5
                     dd 0x50404036, 0x70606057, 0xd0c0c0b8, 0xf0e0e0d9
                     dd 0x50104001, 0x70306023, 0xd090c083, 0xf0b0e0a5
                     dd 0x50104005, 0x70306027, 0xd090c087, 0xf0b0e0a9
load_bytes_ymm_shuf: dd 0x06050403, 0x0e0d0c1b, 0x07060544, 0x0f0e0d5c
                     dd 0x06050473, 0x0e0d0c2b, 0x07060534, 0x0f0e0d6c
transpose_shuf: db 0,4,8,12,1,5,9,13,2,6,10,14,3,7,11,15

SECTION .text

cextern pb_0
cextern pb_1
cextern pb_3
cextern pb_a1
cextern pw_2
cextern pw_4
cextern pw_00ff
cextern pw_pixel_max
cextern pb_unpackbd1

%if HIGH_BIT_DEPTH
; out: %4 = |%1-%2|-%3
; clobbers: %5
%macro ABS_SUB 5
    psubusw %5, %2, %1
    psubusw %4, %1, %2
    por     %4, %5
    psubw   %4, %3
%endmacro

; out: %4 = |%1-%2|<%3
%macro DIFF_LT   5
    psubusw %4, %2, %1
    psubusw %5, %1, %2
    por     %5, %4 ; |%1-%2|
    pxor    %4, %4
    psubw   %5, %3 ; |%1-%2|-%3
    pcmpgtw %4, %5 ; 0 > |%1-%2|-%3
%endmacro

%macro LOAD_AB 4
    movd       %1, %3
    movd       %2, %4
    SPLATW     %1, %1
    SPLATW     %2, %2
%endmacro

; in:  %2=tc reg
; out: %1=splatted tc
%macro LOAD_TC 2
%if mmsize == 8
    pshufw      %1, [%2-1], 0
%else
    movd        %1, [%2]
    punpcklbw   %1, %1
    pshuflw     %1, %1, q1100
    pshufd      %1, %1, q1100
%endif
    psraw       %1, 8
%endmacro

; in: %1=p1, %2=p0, %3=q0, %4=q1
;     %5=alpha, %6=beta, %7-%9=tmp
; out: %7=mask
%macro LOAD_MASK 9
    ABS_SUB     %2, %3, %5, %8, %7 ; |p0-q0| - alpha
    ABS_SUB     %1, %2, %6, %9, %7 ; |p1-p0| - beta
    pand        %8, %9
    ABS_SUB     %3, %4, %6, %9, %7 ; |q1-q0| - beta
    pxor        %7, %7
    pand        %8, %9
    pcmpgtw     %7, %8
%endmacro

; in: %1=p0, %2=q0, %3=p1, %4=q1, %5=mask, %6=tmp, %7=tmp
; out: %1=p0', m2=q0'
%macro DEBLOCK_P0_Q0 7
    psubw   %3, %4
    pxor    %7, %7
    paddw   %3, [pw_4]
    psubw   %7, %5
    psubw   %6, %2, %1
    psllw   %6, 2
    paddw   %3, %6
    psraw   %3, 3
    mova    %6, [pw_pixel_max]
    CLIPW   %3, %7, %5
    pxor    %7, %7
    paddw   %1, %3
    psubw   %2, %3
    CLIPW   %1, %7, %6
    CLIPW   %2, %7, %6
%endmacro

; in: %1=x2, %2=x1, %3=p0, %4=q0 %5=mask&tc, %6=tmp
%macro LUMA_Q1 6
    pavgw       %6, %3, %4      ; (p0+q0+1)>>1
    paddw       %1, %6
    pxor        %6, %6
    psraw       %1, 1
    psubw       %6, %5
    psubw       %1, %2
    CLIPW       %1, %6, %5
    paddw       %1, %2
%endmacro

%macro LUMA_DEBLOCK_ONE 3
    DIFF_LT     m5, %1, bm, m4, m6
    pxor        m6, m6
    mova        %3, m4
    pcmpgtw     m6, tcm
    pand        m4, tcm
    pandn       m6, m7
    pand        m4, m6
    LUMA_Q1 m5, %2, m1, m2, m4, m6
%endmacro

%macro LUMA_H_STORE 2
%if mmsize == 8
    movq        [r0-4], m0
    movq        [r0+r1-4], m1
    movq        [r0+r1*2-4], m2
    movq        [r0+%2-4], m3
%else
    movq        [r0-4], m0
    movhps      [r0+r1-4], m0
    movq        [r0+r1*2-4], m1
    movhps      [%1-4], m1
    movq        [%1+r1-4], m2
    movhps      [%1+r1*2-4], m2
    movq        [%1+%2-4], m3
    movhps      [%1+r1*4-4], m3
%endif
%endmacro

%macro DEBLOCK_LUMA 0
;-----------------------------------------------------------------------------
; void deblock_v_luma( uint16_t *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 )
;-----------------------------------------------------------------------------
cglobal deblock_v_luma, 5,5,8,0-5*mmsize
    %define tcm [rsp]
    %define ms1 [rsp+mmsize]
    %define ms2 [rsp+mmsize*2]
    %define am  [rsp+mmsize*3]
    %define bm  [rsp+mmsize*4]
    add         r1, r1
    LOAD_AB     m4, m5, r2d, r3d
    mov         r3, 32/mmsize
    mov         r2, r0
    sub         r0, r1
    mova        am, m4
    sub         r0, r1
    mova        bm, m5
    sub         r0, r1
.loop:
    mova        m0, [r0+r1]
    mova        m1, [r0+r1*2]
    mova        m2, [r2]
    mova        m3, [r2+r1]

    LOAD_MASK   m0, m1, m2, m3, am, bm, m7, m4, m6
    LOAD_TC     m6, r4
    mova       tcm, m6

    mova        m5, [r0]
    LUMA_DEBLOCK_ONE m1, m0, ms1
    mova   [r0+r1], m5

    mova        m5, [r2+r1*2]
    LUMA_DEBLOCK_ONE m2, m3, ms2
    mova   [r2+r1], m5

    pxor        m5, m5
    mova        m6, tcm
    pcmpgtw     m5, tcm
    psubw       m6, ms1
    pandn       m5, m7
    psubw       m6, ms2
    pand        m5, m6
    DEBLOCK_P0_Q0 m1, m2, m0, m3, m5, m7, m6
    mova [r0+r1*2], m1
    mova      [r2], m2

    add         r0, mmsize
    add         r2, mmsize
    add         r4, mmsize/8
    dec         r3
    jg .loop
    RET

cglobal deblock_h_luma, 5,6,8,0-7*mmsize
    %define tcm [rsp]
    %define ms1 [rsp+mmsize]
    %define ms2 [rsp+mmsize*2]
    %define p1m [rsp+mmsize*3]
    %define p2m [rsp+mmsize*4]
    %define am  [rsp+mmsize*5]
    %define bm  [rsp+mmsize*6]
    add         r1, r1
    LOAD_AB     m4, m5, r2d, r3d
    mov         r3, r1
    mova        am, m4
    add         r3, r1
    mov         r5, 32/mmsize
    mova        bm, m5
    add         r3, r1
%if mmsize == 16
    mov         r2, r0
    add         r2, r3
%endif
.loop:
%if mmsize == 8
    movq        m2, [r0-8]     ; y q2 q1 q0
    movq        m7, [r0+0]
    movq        m5, [r0+r1-8]
    movq        m3, [r0+r1+0]
    movq        m0, [r0+r1*2-8]
    movq        m6, [r0+r1*2+0]
    movq        m1, [r0+r3-8]
    TRANSPOSE4x4W 2, 5, 0, 1, 4
    SWAP         2, 7
    movq        m7, [r0+r3]
    TRANSPOSE4x4W 2, 3, 6, 7, 4
%else
    movu        m5, [r0-8]     ; y q2 q1 q0 p0 p1 p2 x
    movu        m0, [r0+r1-8]
    movu        m2, [r0+r1*2-8]
    movu        m3, [r2-8]
    TRANSPOSE4x4W 5, 0, 2, 3, 6
    mova       tcm, m3

    movu        m4, [r2+r1-8]
    movu        m1, [r2+r1*2-8]
    movu        m3, [r2+r3-8]
    movu        m7, [r2+r1*4-8]
    TRANSPOSE4x4W 4, 1, 3, 7, 6

    mova        m6, tcm
    punpcklqdq  m6, m7
    punpckhqdq  m5, m4
    SBUTTERFLY qdq, 0, 1, 7
    SBUTTERFLY qdq, 2, 3, 7
%endif

    mova       p2m, m6
    LOAD_MASK   m0, m1, m2, m3, am, bm, m7, m4, m6
    LOAD_TC     m6, r4
    mova       tcm, m6

    LUMA_DEBLOCK_ONE m1, m0, ms1
    mova       p1m, m5

    mova        m5, p2m
    LUMA_DEBLOCK_ONE m2, m3, ms2
    mova       p2m, m5

    pxor        m5, m5
    mova        m6, tcm
    pcmpgtw     m5, tcm
    psubw       m6, ms1
    pandn       m5, m7
    psubw       m6, ms2
    pand        m5, m6
    DEBLOCK_P0_Q0 m1, m2, m0, m3, m5, m7, m6
    mova        m0, p1m
    mova        m3, p2m
    TRANSPOSE4x4W 0, 1, 2, 3, 4
    LUMA_H_STORE r2, r3

    add         r4, mmsize/8
    lea         r0, [r0+r1*(mmsize/2)]
    lea         r2, [r2+r1*(mmsize/2)]
    dec         r5
    jg .loop
    RET
%endmacro

%if ARCH_X86_64
; in:  m0=p1, m1=p0, m2=q0, m3=q1, m8=p2, m9=q2
;      m12=alpha, m13=beta
; out: m0=p1', m3=q1', m1=p0', m2=q0'
; clobbers: m4, m5, m6, m7, m10, m11, m14
%macro DEBLOCK_LUMA_INTER_SSE2 0
    LOAD_MASK   m0, m1, m2, m3, m12, m13, m7, m4, m6
    LOAD_TC     m6, r4
    DIFF_LT     m8, m1, m13, m10, m4
    DIFF_LT     m9, m2, m13, m11, m4
    pand        m6, m7

    mova       m14, m6
    pxor        m4, m4
    pcmpgtw     m6, m4
    pand        m6, m14

    mova        m5, m10
    pand        m5, m6
    LUMA_Q1 m8, m0, m1, m2, m5, m4

    mova        m5, m11
    pand        m5, m6
    LUMA_Q1 m9, m3, m1, m2, m5, m4

    pxor        m4, m4
    psubw       m6, m10
    pcmpgtw     m4, m14
    pandn       m4, m7
    psubw       m6, m11
    pand        m4, m6
    DEBLOCK_P0_Q0 m1, m2, m0, m3, m4, m5, m6

    SWAP         0, 8
    SWAP         3, 9
%endmacro

%macro DEBLOCK_LUMA_64 0
cglobal deblock_v_luma, 5,5,15
    %define p2 m8
    %define p1 m0
    %define p0 m1
    %define q0 m2
    %define q1 m3
    %define q2 m9
    %define mask0 m7
    %define mask1 m10
    %define mask2 m11
    add         r1, r1
    LOAD_AB    m12, m13, r2d, r3d
    mov         r2, r0
    sub         r0, r1
    sub         r0, r1
    sub         r0, r1
    mov         r3, 2
.loop:
    mova        p2, [r0]
    mova        p1, [r0+r1]
    mova        p0, [r0+r1*2]
    mova        q0, [r2]
    mova        q1, [r2+r1]
    mova        q2, [r2+r1*2]
    DEBLOCK_LUMA_INTER_SSE2
    mova   [r0+r1], p1
    mova [r0+r1*2], p0
    mova      [r2], q0
    mova   [r2+r1], q1
    add         r0, mmsize
    add         r2, mmsize
    add         r4, 2
    dec         r3
    jg .loop
    RET

cglobal deblock_h_luma, 5,7,15
    add         r1, r1
    LOAD_AB    m12, m13, r2d, r3d
    mov         r2, r1
    add         r2, r1
    add         r2, r1
    mov         r5, r0
    add         r5, r2
    mov         r6, 2
.loop:
    movu        m8, [r0-8]     ; y q2 q1 q0 p0 p1 p2 x
    movu        m0, [r0+r1-8]
    movu        m2, [r0+r1*2-8]
    movu        m9, [r5-8]
    movu        m5, [r5+r1-8]
    movu        m1, [r5+r1*2-8]
    movu        m3, [r5+r2-8]
    movu        m7, [r5+r1*4-8]

    TRANSPOSE4x4W 8, 0, 2, 9, 10
    TRANSPOSE4x4W 5, 1, 3, 7, 10

    punpckhqdq  m8, m5
    SBUTTERFLY qdq, 0, 1, 10
    SBUTTERFLY qdq, 2, 3, 10
    punpcklqdq  m9, m7

    DEBLOCK_LUMA_INTER_SSE2

    TRANSPOSE4x4W 0, 1, 2, 3, 4
    LUMA_H_STORE r5, r2
    add         r4, 2
    lea         r0, [r0+r1*8]
    lea         r5, [r5+r1*8]
    dec         r6
    jg .loop
    RET
%endmacro

INIT_XMM sse2
DEBLOCK_LUMA_64
INIT_XMM avx
DEBLOCK_LUMA_64
%endif

%macro SWAPMOVA 2
%ifnum sizeof%1
    SWAP %1, %2
%else
    mova %1, %2
%endif
%endmacro

; in: t0-t2: tmp registers
;     %1=p0 %2=p1 %3=p2 %4=p3 %5=q0 %6=q1 %7=mask0
;     %8=mask1p %9=2 %10=p0' %11=p1' %12=p2'
%macro LUMA_INTRA_P012 12 ; p0..p3 in memory
%if ARCH_X86_64
    paddw     t0, %3, %2
    mova      t2, %4
    paddw     t2, %3
%else
    mova      t0, %3
    mova      t2, %4
    paddw     t0, %2
    paddw     t2, %3
%endif
    paddw     t0, %1
    paddw     t2, t2
    paddw     t0, %5
    paddw     t2, %9
    paddw     t0, %9    ; (p2 + p1 + p0 + q0 + 2)
    paddw     t2, t0    ; (2*p3 + 3*p2 + p1 + p0 + q0 + 4)

    psrlw     t2, 3
    psrlw     t1, t0, 2
    psubw     t2, %3
    psubw     t1, %2
    pand      t2, %8
    pand      t1, %8
    paddw     t2, %3
    paddw     t1, %2
    SWAPMOVA %11, t1

    psubw     t1, t0, %3
    paddw     t0, t0
    psubw     t1, %5
    psubw     t0, %3
    paddw     t1, %6
    paddw     t1, %2
    paddw     t0, %6
    psrlw     t1, 2     ; (2*p1 + p0 + q1 + 2)/4
    psrlw     t0, 3     ; (p2 + 2*p1 + 2*p0 + 2*q0 + q1 + 4)>>3

    pxor      t0, t1
    pxor      t1, %1
    pand      t0, %8
    pand      t1, %7
    pxor      t0, t1
    pxor      t0, %1
    SWAPMOVA %10, t0
    SWAPMOVA %12, t2
%endmacro

%macro LUMA_INTRA_INIT 1
    %define t0 m4
    %define t1 m5
    %define t2 m6
    %define t3 m7
    %assign i 4
%rep %1
    CAT_XDEFINE t, i, [rsp+mmsize*(i-4)]
    %assign i i+1
%endrep
    add     r1, r1
%endmacro

; in: %1-%3=tmp, %4=p2, %5=q2
%macro LUMA_INTRA_INTER 5
    LOAD_AB t0, t1, r2d, r3d
    mova    %1, t0
    LOAD_MASK m0, m1, m2, m3, %1, t1, t0, t2, t3
%if ARCH_X86_64
    mova    %2, t0        ; mask0
    psrlw   t3, %1, 2
%else
    mova    t3, %1
    mova    %2, t0        ; mask0
    psrlw   t3, 2
%endif
    paddw   t3, [pw_2]    ; alpha/4+2
    DIFF_LT m1, m2, t3, t2, t0 ; t2 = |p0-q0| < alpha/4+2
    pand    t2, %2
    mova    t3, %5        ; q2
    mova    %1, t2        ; mask1
    DIFF_LT t3, m2, t1, t2, t0 ; t2 = |q2-q0| < beta
    pand    t2, %1
    mova    t3, %4        ; p2
    mova    %3, t2        ; mask1q
    DIFF_LT t3, m1, t1, t2, t0 ; t2 = |p2-p0| < beta
    pand    t2, %1
    mova    %1, t2        ; mask1p
%endmacro

%macro LUMA_H_INTRA_LOAD 0
%if mmsize == 8
    movu    t0, [r0-8]
    movu    t1, [r0+r1-8]
    movu    m0, [r0+r1*2-8]
    movu    m1, [r0+r4-8]
    TRANSPOSE4x4W 4, 5, 0, 1, 2
    mova    t4, t0        ; p3
    mova    t5, t1        ; p2

    movu    m2, [r0]
    movu    m3, [r0+r1]
    movu    t0, [r0+r1*2]
    movu    t1, [r0+r4]
    TRANSPOSE4x4W 2, 3, 4, 5, 6
    mova    t6, t0        ; q2
    mova    t7, t1        ; q3
%else
    movu    t0, [r0-8]
    movu    t1, [r0+r1-8]
    movu    m0, [r0+r1*2-8]
    movu    m1, [r0+r5-8]
    movu    m2, [r4-8]
    movu    m3, [r4+r1-8]
    movu    t2, [r4+r1*2-8]
    movu    t3, [r4+r5-8]
    TRANSPOSE8x8W 4, 5, 0, 1, 2, 3, 6, 7, t4, t5
    mova    t4, t0        ; p3
    mova    t5, t1        ; p2
    mova    t6, t2        ; q2
    mova    t7, t3        ; q3
%endif
%endmacro

; in: %1=q3 %2=q2' %3=q1' %4=q0' %5=p0' %6=p1' %7=p2' %8=p3 %9=tmp
%macro LUMA_H_INTRA_STORE 9
%if mmsize == 8
    TRANSPOSE4x4W %1, %2, %3, %4, %9
    movq       [r0-8], m%1
    movq       [r0+r1-8], m%2
    movq       [r0+r1*2-8], m%3
    movq       [r0+r4-8], m%4
    movq       m%1, %8
    TRANSPOSE4x4W %5, %6, %7, %1, %9
    movq       [r0], m%5
    movq       [r0+r1], m%6
    movq       [r0+r1*2], m%7
    movq       [r0+r4], m%1
%else
    TRANSPOSE2x4x4W %1, %2, %3, %4, %9
    movq       [r0-8], m%1
    movq       [r0+r1-8], m%2
    movq       [r0+r1*2-8], m%3
    movq       [r0+r5-8], m%4
    movhps     [r4-8], m%1
    movhps     [r4+r1-8], m%2
    movhps     [r4+r1*2-8], m%3
    movhps     [r4+r5-8], m%4
%ifnum %8
    SWAP       %1, %8
%else
    mova       m%1, %8
%endif
    TRANSPOSE2x4x4W %5, %6, %7, %1, %9
    movq       [r0], m%5
    movq       [r0+r1], m%6
    movq       [r0+r1*2], m%7
    movq       [r0+r5], m%1
    movhps     [r4], m%5
    movhps     [r4+r1], m%6
    movhps     [r4+r1*2], m%7
    movhps     [r4+r5], m%1
%endif
%endmacro

%if ARCH_X86_64
;-----------------------------------------------------------------------------
; void deblock_v_luma_intra( uint16_t *pix, intptr_t stride, int alpha, int beta )
;-----------------------------------------------------------------------------
%macro DEBLOCK_LUMA_INTRA_64 0
cglobal deblock_v_luma_intra, 4,7,16
    %define t0 m1
    %define t1 m2
    %define t2 m4
    %define p2 m8
    %define p1 m9
    %define p0 m10
    %define q0 m11
    %define q1 m12
    %define q2 m13
    %define aa m5
    %define bb m14
    add     r1, r1
    lea     r4, [r1*4]
    lea     r5, [r1*3] ; 3*stride
    neg     r4
    add     r4, r0     ; pix-4*stride
    mov     r6, 2
    mova    m0, [pw_2]
    LOAD_AB aa, bb, r2d, r3d
.loop:
    mova    p2, [r4+r1]
    mova    p1, [r4+2*r1]
    mova    p0, [r4+r5]
    mova    q0, [r0]
    mova    q1, [r0+r1]
    mova    q2, [r0+2*r1]

    LOAD_MASK p1, p0, q0, q1, aa, bb, m3, t0, t1
    mova    t2, aa
    psrlw   t2, 2
    paddw   t2, m0 ; alpha/4+2
    DIFF_LT p0, q0, t2, m6, t0 ; m6 = |p0-q0| < alpha/4+2
    DIFF_LT p2, p0, bb, t1, t0 ; m7 = |p2-p0| < beta
    DIFF_LT q2, q0, bb, m7, t0 ; t1 = |q2-q0| < beta
    pand    m6, m3
    pand    m7, m6
    pand    m6, t1
    LUMA_INTRA_P012 p0, p1, p2, [r4], q0, q1, m3, m6, m0, [r4+r5], [r4+2*r1], [r4+r1]
    LUMA_INTRA_P012 q0, q1, q2, [r0+r5], p0, p1, m3, m7, m0, [r0], [r0+r1], [r0+2*r1]
    add     r0, mmsize
    add     r4, mmsize
    dec     r6
    jg .loop
    RET

;-----------------------------------------------------------------------------
; void deblock_h_luma_intra( uint16_t *pix, intptr_t stride, int alpha, int beta )
;-----------------------------------------------------------------------------
cglobal deblock_h_luma_intra, 4,7,16
    %define t0 m15
    %define t1 m14
    %define t2 m2
    %define q3 m5
    %define q2 m8
    %define q1 m9
    %define q0 m10
    %define p0 m11
    %define p1 m12
    %define p2 m13
    %define p3 m4
    %define spill [rsp]
    %assign pad 24-(stack_offset&15)
    SUB     rsp, pad
    add     r1, r1
    lea     r4, [r1*4]
    lea     r5, [r1*3] ; 3*stride
    add     r4, r0     ; pix+4*stride
    mov     r6, 2
    mova    m0, [pw_2]
.loop:
    movu    q3, [r0-8]
    movu    q2, [r0+r1-8]
    movu    q1, [r0+r1*2-8]
    movu    q0, [r0+r5-8]
    movu    p0, [r4-8]
    movu    p1, [r4+r1-8]
    movu    p2, [r4+r1*2-8]
    movu    p3, [r4+r5-8]
    TRANSPOSE8x8W 5, 8, 9, 10, 11, 12, 13, 4, 1

    LOAD_AB m1, m2, r2d, r3d
    LOAD_MASK q1, q0, p0, p1, m1, m2, m3, t0, t1
    psrlw   m1, 2
    paddw   m1, m0 ; alpha/4+2
    DIFF_LT p0, q0, m1, m6, t0 ; m6 = |p0-q0| < alpha/4+2
    DIFF_LT q2, q0, m2, t1, t0 ; t1 = |q2-q0| < beta
    DIFF_LT p0, p2, m2, m7, t0 ; m7 = |p2-p0| < beta
    pand    m6, m3
    pand    m7, m6
    pand    m6, t1

    mova spill, q3
    LUMA_INTRA_P012 q0, q1, q2, q3, p0, p1, m3, m6, m0, m5, m1, q2
    LUMA_INTRA_P012 p0, p1, p2, p3, q0, q1, m3, m7, m0, p0, m6, p2
    mova    m7, spill

    LUMA_H_INTRA_STORE 7, 8, 1, 5, 11, 6, 13, 4, 14

    lea     r0, [r0+r1*8]
    lea     r4, [r4+r1*8]
    dec     r6
    jg .loop
    ADD    rsp, pad
    RET
%endmacro

INIT_XMM sse2
DEBLOCK_LUMA_INTRA_64
INIT_XMM avx
DEBLOCK_LUMA_INTRA_64

%endif

%macro DEBLOCK_LUMA_INTRA 0
;-----------------------------------------------------------------------------
; void deblock_v_luma_intra( uint16_t *pix, intptr_t stride, int alpha, int beta )
;-----------------------------------------------------------------------------
cglobal deblock_v_luma_intra, 4,7,8,0-3*mmsize
    LUMA_INTRA_INIT 3
    lea     r4, [r1*4]
    lea     r5, [r1*3]
    neg     r4
    add     r4, r0
    mov     r6, 32/mmsize
.loop:
    mova    m0, [r4+r1*2] ; p1
    mova    m1, [r4+r5]   ; p0
    mova    m2, [r0]      ; q0
    mova    m3, [r0+r1]   ; q1
    LUMA_INTRA_INTER t4, t5, t6, [r4+r1], [r0+r1*2]
    LUMA_INTRA_P012 m1, m0, t3, [r4], m2, m3, t5, t4, [pw_2], [r4+r5], [r4+2*r1], [r4+r1]
    mova    t3, [r0+r1*2] ; q2
    LUMA_INTRA_P012 m2, m3, t3, [r0+r5], m1, m0, t5, t6, [pw_2], [r0], [r0+r1], [r0+2*r1]
    add     r0, mmsize
    add     r4, mmsize
    dec     r6
    jg .loop
    RET

;-----------------------------------------------------------------------------
; void deblock_h_luma_intra( uint16_t *pix, intptr_t stride, int alpha, int beta )
;-----------------------------------------------------------------------------
cglobal deblock_h_luma_intra, 4,7,8,0-8*mmsize
    LUMA_INTRA_INIT 8
%if mmsize == 8
    lea     r4, [r1*3]
    mov     r5, 32/mmsize
%else
    lea     r4, [r1*4]
    lea     r5, [r1*3] ; 3*stride
    add     r4, r0     ; pix+4*stride
    mov     r6, 32/mmsize
%endif
.loop:
    LUMA_H_INTRA_LOAD
    LUMA_INTRA_INTER t8, t9, t10, t5, t6

    LUMA_INTRA_P012 m1, m0, t3, t4, m2, m3, t9, t8, [pw_2], t8, t5, t11
    mova    t3, t6     ; q2
    LUMA_INTRA_P012 m2, m3, t3, t7, m1, m0, t9, t10, [pw_2], m4, t6, m5

    mova    m2, t4
    mova    m0, t11
    mova    m1, t5
    mova    m3, t8
    mova    m6, t6

    LUMA_H_INTRA_STORE 2, 0, 1, 3, 4, 6, 5, t7, 7

    lea     r0, [r0+r1*(mmsize/2)]
%if mmsize == 8
    dec     r5
%else
    lea     r4, [r4+r1*(mmsize/2)]
    dec     r6
%endif
    jg .loop
    RET
%endmacro

%if ARCH_X86_64 == 0
INIT_MMX mmx2
DEBLOCK_LUMA
DEBLOCK_LUMA_INTRA
INIT_XMM sse2
DEBLOCK_LUMA
DEBLOCK_LUMA_INTRA
INIT_XMM avx
DEBLOCK_LUMA
DEBLOCK_LUMA_INTRA
%endif
%endif ; HIGH_BIT_DEPTH

%if HIGH_BIT_DEPTH == 0
; expands to [base],...,[base+7*stride]
%define PASS8ROWS(base, base3, stride, stride3) \
    [base], [base+stride], [base+stride*2], [base3], \
    [base3+stride], [base3+stride*2], [base3+stride3], [base3+stride*4]

%define PASS8ROWS(base, base3, stride, stride3, offset) \
    PASS8ROWS(base+offset, base3+offset, stride, stride3)

; in: 4 rows of 8 bytes in m0..m3
; out: 8 rows of 4 bytes in %1..%8
%macro TRANSPOSE8x4B_STORE 8
    punpckhdq  m4, m0, m0
    punpckhdq  m5, m1, m1
    punpckhdq  m6, m2, m2

    punpcklbw  m0, m1
    punpcklbw  m2, m3
    punpcklwd  m1, m0, m2
    punpckhwd  m0, m2
    movd       %1, m1
    punpckhdq  m1, m1
    movd       %2, m1
    movd       %3, m0
    punpckhdq  m0, m0
    movd       %4, m0

    punpckhdq  m3, m3
    punpcklbw  m4, m5
    punpcklbw  m6, m3
    punpcklwd  m5, m4, m6
    punpckhwd  m4, m6
    movd       %5, m5
    punpckhdq  m5, m5
    movd       %6, m5
    movd       %7, m4
    punpckhdq  m4, m4
    movd       %8, m4
%endmacro

; in: 8 rows of 4 bytes in %9..%10
; out: 8 rows of 4 bytes in %1..%8
%macro STORE_8x4B 10
    movd   %1, %9
    pextrd %2, %9, 1
    pextrd %3, %9, 2
    pextrd %4, %9, 3
    movd   %5, %10
    pextrd %6, %10, 1
    pextrd %7, %10, 2
    pextrd %8, %10, 3
%endmacro

; in: 4 rows of 4 words in %1..%4
; out: 4 rows of 4 word in m0..m3
; clobbers: m4
%macro TRANSPOSE4x4W_LOAD 4-8
%if mmsize==8
    SWAP  1, 4, 2, 3
    movq  m0, %1
    movq  m1, %2
    movq  m2, %3
    movq  m3, %4
    TRANSPOSE4x4W 0, 1, 2, 3, 4
%else
    movq       m0, %1
    movq       m2, %2
    movq       m1, %3
    movq       m3, %4
    punpcklwd  m0, m2
    punpcklwd  m1, m3
    mova       m2, m0
    punpckldq  m0, m1
    punpckhdq  m2, m1
    MOVHL      m1, m0
    MOVHL      m3, m2
%endif
%endmacro

; in: 2 rows of 4 words in m1..m2
; out: 4 rows of 2 words in %1..%4
; clobbers: m0, m1
%macro TRANSPOSE4x2W_STORE 4-8
%if mmsize==8
    punpckhwd  m0, m1, m2
    punpcklwd  m1, m2
%else
    punpcklwd  m1, m2
    MOVHL      m0, m1
%endif
    movd       %3, m0
    movd       %1, m1
    psrlq      m1, 32
    psrlq      m0, 32
    movd       %2, m1
    movd       %4, m0
%endmacro

; in: 4/8 rows of 4 words in %1..%8
; out: 4 rows of 4/8 word in m0..m3
; clobbers: m4, m5, m6, m7
%macro TRANSPOSE4x8W_LOAD 8
%if mmsize==8
    TRANSPOSE4x4W_LOAD %1, %2, %3, %4
%else
    movq       m0, %1
    movq       m2, %2
    movq       m1, %3
    movq       m3, %4
    punpcklwd  m0, m2
    punpcklwd  m1, m3
    punpckhdq  m2, m0, m1
    punpckldq  m0, m1

    movq       m4, %5
    movq       m6, %6
    movq       m5, %7
    movq       m7, %8
    punpcklwd  m4, m6
    punpcklwd  m5, m7
    punpckhdq  m6, m4, m5
    punpckldq  m4, m5

    punpckhqdq m1, m0, m4
    punpckhqdq m3, m2, m6
    punpcklqdq m0, m4
    punpcklqdq m2, m6
%endif
%endmacro

; in: 2 rows of 4/8 words in m1..m2
; out: 4/8 rows of 2 words in %1..%8
; clobbers: m0, m1
%macro TRANSPOSE8x2W_STORE 8
%if mmsize==8
    TRANSPOSE4x2W_STORE %1, %2, %3, %4
%else
    punpckhwd  m0, m1, m2
    punpcklwd  m1, m2
    movd       %5, m0
    movd       %1, m1
    psrldq     m1, 4
    psrldq     m0, 4
    movd       %2, m1
    movd       %6, m0
    psrldq     m1, 4
    psrldq     m0, 4
    movd       %3, m1
    movd       %7, m0
    psrldq     m1, 4
    psrldq     m0, 4
    movd       %4, m1
    movd       %8, m0
%endif
%endmacro

%macro SBUTTERFLY3 4
    punpckh%1  %4, %2, %3
    punpckl%1  %2, %3
%endmacro

; in: 8 rows of 8 (only the middle 6 pels are used) in %1..%8
; out: 6 rows of 8 in [%9+0*16] .. [%9+5*16]
%macro TRANSPOSE6x8_MEM 9
    RESET_MM_PERMUTATION
%if cpuflag(avx)
    ; input:
    ; _ABCDEF_
    ; _GHIJKL_
    ; _MNOPQR_
    ; _STUVWX_
    ; _YZabcd_
    ; _efghij_
    ; _klmnop_
    ; _qrstuv_

    movh      m0, %1
    movh      m2, %2
    movh      m1, %3
    movh      m3, %4
    punpcklbw m0, m2       ; __ AG BH CI DJ EK FL __
    punpcklbw m1, m3       ; __ MS NT OU PV QW RX __
    movh      m2, %5
    movh      m3, %6
    punpcklbw m2, m3       ; __ Ye Zf ag bh ci dj __
    movh      m3, %7
    movh      m4, %8
    punpcklbw m3, m4       ; __ kq lr ms nt ou pv __

    SBUTTERFLY wd, 0, 1, 4 ; __ __ AG MS BH NT CI OU
                           ; DJ PV EK QW FL RX __ __
    SBUTTERFLY wd, 2, 3, 4 ; __ __ Ye kq Zf lr ag ms
                           ; bh nt ci ou dj pv __ __
    SBUTTERFLY dq, 0, 2, 4 ; __ __ __ __ AG MS Ye kq
                           ; BH NT Zf lr CI FL OU RX
    SBUTTERFLY dq, 1, 3, 4 ; DJ PV bh nt EK QW Zf lr
                           ; FL RX dj pv __ __ __ __
    movhps [%9+0x00], m0
    movh   [%9+0x10], m2
    movhps [%9+0x20], m2
    movh   [%9+0x30], m1
    movhps [%9+0x40], m1
    movh   [%9+0x50], m3
%else
    movq  m0, %1
    movq  m1, %2
    movq  m2, %3
    movq  m3, %4
    movq  m4, %5
    movq  m5, %6
    movq  m6, %7
    SBUTTERFLY bw, 0, 1, 7
    SBUTTERFLY bw, 2, 3, 7
    SBUTTERFLY bw, 4, 5, 7
    movq  [%9+0x10], m3
    SBUTTERFLY3 bw, m6, %8, m7
    SBUTTERFLY wd, 0, 2, 3
    SBUTTERFLY wd, 4, 6, 3
    punpckhdq m0, m4
    movq  [%9+0x00], m0
    SBUTTERFLY3 wd, m1, [%9+0x10], m3
    SBUTTERFLY wd, 5, 7, 0
    SBUTTERFLY dq, 1, 5, 0
    SBUTTERFLY dq, 2, 6, 0
    punpckldq m3, m7
    movq  [%9+0x10], m2
    movq  [%9+0x20], m6
    movq  [%9+0x30], m1
    movq  [%9+0x40], m5
    movq  [%9+0x50], m3
%endif
    RESET_MM_PERMUTATION
%endmacro


; in: 8 rows of 8 in %1..%8
; out: 8 rows of 8 in %9..%16
%macro TRANSPOSE8x8_MEM 16
    RESET_MM_PERMUTATION
%if cpuflag(avx)
    movh      m0, %1
    movh      m4, %2
    movh      m1, %3
    movh      m5, %4
    movh      m2, %5
    movh      m3, %7
    punpcklbw m0, m4
    punpcklbw m1, m5
    movh      m4, %6
    movh      m5, %8
    punpcklbw m2, m4
    punpcklbw m3, m5
    SBUTTERFLY wd, 0, 1, 4
    SBUTTERFLY wd, 2, 3, 4
    SBUTTERFLY dq, 0, 2, 4
    SBUTTERFLY dq, 1, 3, 4
    movh    %9, m0
    movhps %10, m0
    movh   %11, m2
    movhps %12, m2
    movh   %13, m1
    movhps %14, m1
    movh   %15, m3
    movhps %16, m3
%else
    movq  m0, %1
    movq  m1, %2
    movq  m2, %3
    movq  m3, %4
    movq  m4, %5
    movq  m5, %6
    movq  m6, %7
    SBUTTERFLY bw, 0, 1, 7
    SBUTTERFLY bw, 2, 3, 7
    SBUTTERFLY bw, 4, 5, 7
    SBUTTERFLY3 bw, m6, %8, m7
    movq  %9,  m5
    SBUTTERFLY wd, 0, 2, 5
    SBUTTERFLY wd, 4, 6, 5
    SBUTTERFLY wd, 1, 3, 5
    movq  %11, m6
    movq  m6,  %9
    SBUTTERFLY wd, 6, 7, 5
    SBUTTERFLY dq, 0, 4, 5
    SBUTTERFLY dq, 1, 6, 5
    movq  %9,  m0
    movq  %10, m4
    movq  %13, m1
    movq  %14, m6
    SBUTTERFLY3 dq, m2, %11, m0
    SBUTTERFLY dq, 3, 7, 4
    movq  %11, m2
    movq  %12, m0
    movq  %15, m3
    movq  %16, m7
%endif
    RESET_MM_PERMUTATION
%endmacro

; out: %4 = |%1-%2|>%3
; clobbers: %5
%macro DIFF_GT 5
%if avx_enabled == 0
    mova    %5, %2
    mova    %4, %1
    psubusb %5, %1
    psubusb %4, %2
%else
    psubusb %5, %2, %1
    psubusb %4, %1, %2
%endif
    por     %4, %5
    psubusb %4, %3
%endmacro

; out: %4 = |%1-%2|>%3
; clobbers: %5
%macro DIFF_GT2 5-6
%if %0<6
    psubusb %4, %1, %2
    psubusb %5, %2, %1
%else
    mova    %4, %1
    mova    %5, %2
    psubusb %4, %2
    psubusb %5, %1
%endif
    psubusb %5, %3
    psubusb %4, %3
    pcmpeqb %4, %5
%endmacro

; in: m0=p1 m1=p0 m2=q0 m3=q1 %1=alpha %2=beta
; out: m5=beta-1, m7=mask, %3=alpha-1
; clobbers: m4,m6
%macro LOAD_MASK 2-3
%if cpuflag(ssse3)
    movd     m4, %1
    movd     m5, %2
    pxor     m6, m6
    pshufb   m4, m6
    pshufb   m5, m6
%else
    movd     m4, %1
    movd     m5, %2
    punpcklbw m4, m4
    punpcklbw m5, m5
    SPLATW   m4, m4
    SPLATW   m5, m5
%endif
    mova     m6, [pb_1]
    psubusb  m4, m6              ; alpha - 1
    psubusb  m5, m6              ; beta - 1
%if %0>2
    mova     %3, m4
%endif
    DIFF_GT  m1, m2, m4, m7, m6 ; |p0-q0| > alpha-1
    DIFF_GT  m0, m1, m5, m4, m6 ; |p1-p0| > beta-1
    por      m7, m4
    DIFF_GT  m3, m2, m5, m4, m6 ; |q1-q0| > beta-1
    por      m7, m4
    pxor     m6, m6
    pcmpeqb  m7, m6
%endmacro

; in: m0=p1 m1=p0 m2=q0 m3=q1 m7=(tc&mask)
; out: m1=p0' m2=q0'
; clobbers: m0,3-6
%macro DEBLOCK_P0_Q0 0
    pxor    m5, m1, m2   ; p0^q0
    pand    m5, [pb_1]   ; (p0^q0)&1
    pcmpeqb m4, m4
    pxor    m3, m4
    pavgb   m3, m0       ; (p1 - q1 + 256)>>1
    pavgb   m3, [pb_3]   ; (((p1 - q1 + 256)>>1)+4)>>1 = 64+2+(p1-q1)>>2
    pxor    m4, m1
    pavgb   m4, m2       ; (q0 - p0 + 256)>>1
    pavgb   m3, m5
    paddusb m3, m4       ; d+128+33
    mova    m6, [pb_a1]
    psubusb m6, m3
    psubusb m3, [pb_a1]
    pminub  m6, m7
    pminub  m3, m7
    psubusb m1, m6
    psubusb m2, m3
    paddusb m1, m3
    paddusb m2, m6
%endmacro

; in: m1=p0 m2=q0
;     %1=p1 %2=q2 %3=[q2] %4=[q1] %5=tc0 %6=tmp
; out: [q1] = clip( (q2+((p0+q0+1)>>1))>>1, q1-tc0, q1+tc0 )
; clobbers: q2, tmp, tc0
%macro LUMA_Q1 6
    pavgb   %6, m1, m2
    pavgb   %2, %6       ; avg(p2,avg(p0,q0))
    pxor    %6, %3
    pand    %6, [pb_1]   ; (p2^avg(p0,q0))&1
    psubusb %2, %6       ; (p2+((p0+q0+1)>>1))>>1
    psubusb %6, %1, %5
    paddusb %5, %1
    pmaxub  %2, %6
    pminub  %2, %5
    mova    %4, %2
%endmacro

%if ARCH_X86_64
;-----------------------------------------------------------------------------
; void deblock_v_luma( uint8_t *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 )
;-----------------------------------------------------------------------------
%macro DEBLOCK_LUMA 0
cglobal deblock_v_luma, 5,5,10
    movd    m8, [r4] ; tc0
    lea     r4, [r1*3]
    neg     r4
    add     r4, r0     ; pix-3*stride

    mova    m0, [r4+r1]   ; p1
    mova    m1, [r4+2*r1] ; p0
    mova    m2, [r0]      ; q0
    mova    m3, [r0+r1]   ; q1
    LOAD_MASK r2d, r3d

%if cpuflag(avx)
    pshufb   m8, [pb_unpackbd1]
    pblendvb m9, m7, m6, m8
%else
    punpcklbw m8, m8
    punpcklbw m8, m8 ; tc = 4x tc0[3], 4x tc0[2], 4x tc0[1], 4x tc0[0]
    pcmpeqb m9, m9
    pcmpeqb m9, m8
    pandn   m9, m7
%endif
    pand    m8, m9

    mova    m3, [r4] ; p2
    DIFF_GT2 m1, m3, m5, m6, m7 ; |p2-p0| > beta-1
    pand    m6, m9
    psubb   m7, m8, m6 ; tc++
    pand    m6, m8
    LUMA_Q1 m0, m3, [r4], [r4+r1], m6, m4

    mova    m4, [r0+2*r1] ; q2
    DIFF_GT2 m2, m4, m5, m6, m3 ; |q2-q0| > beta-1
    pand    m6, m9
    pand    m8, m6
    psubb   m7, m6
    mova    m3, [r0+r1]
    LUMA_Q1 m3, m4, [r0+2*r1], [r0+r1], m8, m6

    DEBLOCK_P0_Q0
    mova    [r4+2*r1], m1
    mova    [r0], m2
    RET

;-----------------------------------------------------------------------------
; void deblock_h_luma( uint8_t *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 )
;-----------------------------------------------------------------------------

%if cpuflag(avx)
INIT_XMM cpuname
%else
INIT_MMX cpuname
%endif
cglobal deblock_h_luma, 5,9,0,0x60+16*WIN64
    lea    r8, [r1*3]
    lea    r6, [r0-4]
    lea    r5, [r0-4+r8]
    %xdefine pix_tmp rsp+0x30*WIN64 ; shadow space + r4

    ; transpose 6x16 -> tmp space
    TRANSPOSE6x8_MEM  PASS8ROWS(r6, r5, r1, r8), pix_tmp
    lea    r6, [r6+r1*8]
    lea    r5, [r5+r1*8]
    TRANSPOSE6x8_MEM  PASS8ROWS(r6, r5, r1, r8), pix_tmp+8

    ; vertical filter
    ; alpha, beta, tc0 are still in r2d, r3d, r4
    ; don't backup r6, r5, r7, r8 because deblock_v_luma_sse2 doesn't use them
    mov    r7, r1
    lea    r0, [pix_tmp+0x30]
    mov    r1d, 0x10
%if WIN64
    mov    [rsp+0x20], r4
%endif
    call   deblock_v_luma

    ; transpose 16x4 -> original space  (only the middle 4 rows were changed by the filter)
    add    r6, 2
    add    r5, 2
%if cpuflag(sse4)
    mova   m0, [pix_tmp+0x10]
    mova   m1, [pix_tmp+0x20]
    mova   m2, [pix_tmp+0x30]
    mova   m3, [pix_tmp+0x40]
    SBUTTERFLY bw, 0, 1, 4
    SBUTTERFLY bw, 2, 3, 4
    SBUTTERFLY wd, 0, 2, 4
    SBUTTERFLY wd, 1, 3, 4
    STORE_8x4B PASS8ROWS(r6, r5, r7, r8), m1, m3
    shl    r7, 3
    sub    r6, r7
    sub    r5, r7
    shr    r7, 3
    STORE_8x4B PASS8ROWS(r6, r5, r7, r8), m0, m2
%else
    movq   m0, [pix_tmp+0x18]
    movq   m1, [pix_tmp+0x28]
    movq   m2, [pix_tmp+0x38]
    movq   m3, [pix_tmp+0x48]
    TRANSPOSE8x4B_STORE  PASS8ROWS(r6, r5, r7, r8)

    shl    r7, 3
    sub    r6, r7
    sub    r5, r7
    shr    r7, 3
    movq   m0, [pix_tmp+0x10]
    movq   m1, [pix_tmp+0x20]
    movq   m2, [pix_tmp+0x30]
    movq   m3, [pix_tmp+0x40]
    TRANSPOSE8x4B_STORE  PASS8ROWS(r6, r5, r7, r8)
%endif

    RET
%endmacro

INIT_XMM sse2
DEBLOCK_LUMA
INIT_XMM avx
DEBLOCK_LUMA

%else

%macro DEBLOCK_LUMA 2
;-----------------------------------------------------------------------------
; void deblock_v8_luma( uint8_t *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 )
;-----------------------------------------------------------------------------
cglobal deblock_%1_luma, 5,5,8,2*%2
    lea     r4, [r1*3]
    neg     r4
    add     r4, r0 ; pix-3*stride

    mova    m0, [r4+r1]   ; p1
    mova    m1, [r4+2*r1] ; p0
    mova    m2, [r0]      ; q0
    mova    m3, [r0+r1]   ; q1
    LOAD_MASK r2d, r3d

    mov     r3, r4mp
    movd    m4, [r3] ; tc0
%if cpuflag(avx)
    pshufb   m4, [pb_unpackbd1]
    mova   [esp+%2], m4 ; tc
    pblendvb m4, m7, m6, m4
%else
    punpcklbw m4, m4
    punpcklbw m4, m4 ; tc = 4x tc0[3], 4x tc0[2], 4x tc0[1], 4x tc0[0]
    mova   [esp+%2], m4 ; tc
    pcmpeqb m3, m3
    pcmpgtb m4, m3
    pand    m4, m7
%endif
    mova   [esp], m4 ; mask

    mova    m3, [r4] ; p2
    DIFF_GT2 m1, m3, m5, m6, m7 ; |p2-p0| > beta-1
    pand    m6, m4
    pand    m4, [esp+%2] ; tc
    psubb   m7, m4, m6
    pand    m6, m4
    LUMA_Q1 m0, m3, [r4], [r4+r1], m6, m4

    mova    m4, [r0+2*r1] ; q2
    DIFF_GT2 m2, m4, m5, m6, m3 ; |q2-q0| > beta-1
    mova    m5, [esp] ; mask
    pand    m6, m5
    mova    m5, [esp+%2] ; tc
    pand    m5, m6
    psubb   m7, m6
    mova    m3, [r0+r1]
    LUMA_Q1 m3, m4, [r0+2*r1], [r0+r1], m5, m6

    DEBLOCK_P0_Q0
    mova    [r4+2*r1], m1
    mova    [r0], m2
    RET

;-----------------------------------------------------------------------------
; void deblock_h_luma( uint8_t *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 )
;-----------------------------------------------------------------------------
%if cpuflag(avx)
INIT_XMM cpuname
%else
INIT_MMX cpuname
%endif
cglobal deblock_h_luma, 1,5,8,0x60+12
    mov    r3, r1m
    lea    r4, [r3*3]
    sub    r0, 4
    lea    r1, [r0+r4]
    %define pix_tmp esp+12
    ; esp is intentionally misaligned to make it aligned after pushing the arguments for deblock_%1_luma.

    ; transpose 6x16 -> tmp space
    TRANSPOSE6x8_MEM  PASS8ROWS(r0, r1, r3, r4), pix_tmp
    lea    r0, [r0+r3*8]
    lea    r1, [r1+r3*8]
    TRANSPOSE6x8_MEM  PASS8ROWS(r0, r1, r3, r4), pix_tmp+8

    ; vertical filter
    lea    r0, [pix_tmp+0x30]
    PUSH   dword r4m
    PUSH   dword r3m
    PUSH   dword r2m
    PUSH   dword 16
    PUSH   dword r0
    call   deblock_%1_luma
%ifidn %1, v8
    add    dword [esp   ], 8 ; pix_tmp+0x38
    add    dword [esp+16], 2 ; tc0+2
    call   deblock_%1_luma
%endif
    ADD    esp, 20

    ; transpose 16x4 -> original space  (only the middle 4 rows were changed by the filter)
    mov    r0, r0mp
    sub    r0, 2
    lea    r1, [r0+r4]

%if cpuflag(avx)
    mova   m0, [pix_tmp+0x10]
    mova   m1, [pix_tmp+0x20]
    mova   m2, [pix_tmp+0x30]
    mova   m3, [pix_tmp+0x40]
    SBUTTERFLY bw, 0, 1, 4
    SBUTTERFLY bw, 2, 3, 4
    SBUTTERFLY wd, 0, 2, 4
    SBUTTERFLY wd, 1, 3, 4
    STORE_8x4B PASS8ROWS(r0, r1, r3, r4), m0, m2
    lea    r0, [r0+r3*8]
    lea    r1, [r1+r3*8]
    STORE_8x4B PASS8ROWS(r0, r1, r3, r4), m1, m3
%else
    movq   m0, [pix_tmp+0x10]
    movq   m1, [pix_tmp+0x20]
    movq   m2, [pix_tmp+0x30]
    movq   m3, [pix_tmp+0x40]
    TRANSPOSE8x4B_STORE  PASS8ROWS(r0, r1, r3, r4)

    lea    r0, [r0+r3*8]
    lea    r1, [r1+r3*8]
    movq   m0, [pix_tmp+0x18]
    movq   m1, [pix_tmp+0x28]
    movq   m2, [pix_tmp+0x38]
    movq   m3, [pix_tmp+0x48]
    TRANSPOSE8x4B_STORE  PASS8ROWS(r0, r1, r3, r4)
%endif

    RET
%endmacro ; DEBLOCK_LUMA

INIT_MMX mmx2
DEBLOCK_LUMA v8, 8
INIT_XMM sse2
DEBLOCK_LUMA v, 16
INIT_XMM avx
DEBLOCK_LUMA v, 16

%endif ; ARCH



%macro LUMA_INTRA_P012 4 ; p0..p3 in memory
%if ARCH_X86_64
    pavgb t0, p2, p1
    pavgb t1, p0, q0
%else
    mova  t0, p2
    mova  t1, p0
    pavgb t0, p1
    pavgb t1, q0
%endif
    pavgb t0, t1 ; ((p2+p1+1)/2 + (p0+q0+1)/2 + 1)/2
    mova  t5, t1
%if ARCH_X86_64
    paddb t2, p2, p1
    paddb t3, p0, q0
%else
    mova  t2, p2
    mova  t3, p0
    paddb t2, p1
    paddb t3, q0
%endif
    paddb t2, t3
    mova  t3, t2
    mova  t4, t2
    psrlw t2, 1
    pavgb t2, mpb_0
    pxor  t2, t0
    pand  t2, mpb_1
    psubb t0, t2 ; p1' = (p2+p1+p0+q0+2)/4;

%if ARCH_X86_64
    pavgb t1, p2, q1
    psubb t2, p2, q1
%else
    mova  t1, p2
    mova  t2, p2
    pavgb t1, q1
    psubb t2, q1
%endif
    paddb t3, t3
    psubb t3, t2 ; p2+2*p1+2*p0+2*q0+q1
    pand  t2, mpb_1
    psubb t1, t2
    pavgb t1, p1
    pavgb t1, t5 ; (((p2+q1)/2 + p1+1)/2 + (p0+q0+1)/2 + 1)/2
    psrlw t3, 2
    pavgb t3, mpb_0
    pxor  t3, t1
    pand  t3, mpb_1
    psubb t1, t3 ; p0'a = (p2+2*p1+2*p0+2*q0+q1+4)/8

    pxor  t3, p0, q1
    pavgb t2, p0, q1
    pand  t3, mpb_1
    psubb t2, t3
    pavgb t2, p1 ; p0'b = (2*p1+p0+q0+2)/4

    pxor  t1, t2
    pxor  t2, p0
    pand  t1, mask1p
    pand  t2, mask0
    pxor  t1, t2
    pxor  t1, p0
    mova  %1, t1 ; store p0

    mova  t1, %4 ; p3
    paddb t2, t1, p2
    pavgb t1, p2
    pavgb t1, t0 ; (p3+p2+1)/2 + (p2+p1+p0+q0+2)/4
    paddb t2, t2
    paddb t2, t4 ; 2*p3+3*p2+p1+p0+q0
    psrlw t2, 2
    pavgb t2, mpb_0
    pxor  t2, t1
    pand  t2, mpb_1
    psubb t1, t2 ; p2' = (2*p3+3*p2+p1+p0+q0+4)/8

    pxor  t0, p1
    pxor  t1, p2
    pand  t0, mask1p
    pand  t1, mask1p
    pxor  t0, p1
    pxor  t1, p2
    mova  %2, t0 ; store p1
    mova  %3, t1 ; store p2
%endmacro

%macro LUMA_INTRA_SWAP_PQ 0
    %define q1 m0
    %define q0 m1
    %define p0 m2
    %define p1 m3
    %define p2 q2
    %define mask1p mask1q
%endmacro

%macro DEBLOCK_LUMA_INTRA 1
    %define p1 m0
    %define p0 m1
    %define q0 m2
    %define q1 m3
    %define t0 m4
    %define t1 m5
    %define t2 m6
    %define t3 m7
%if ARCH_X86_64
    %define p2 m8
    %define q2 m9
    %define t4 m10
    %define t5 m11
    %define mask0 m12
    %define mask1p m13
%if WIN64
    %define mask1q [rsp]
%else
    %define mask1q [rsp-24]
%endif
    %define mpb_0 m14
    %define mpb_1 m15
%else
    %define spill(x) [esp+16*x]
    %define p2 [r4+r1]
    %define q2 [r0+2*r1]
    %define t4 spill(0)
    %define t5 spill(1)
    %define mask0 spill(2)
    %define mask1p spill(3)
    %define mask1q spill(4)
    %define mpb_0 [pb_0]
    %define mpb_1 [pb_1]
%endif

;-----------------------------------------------------------------------------
; void deblock_v_luma_intra( uint8_t *pix, intptr_t stride, int alpha, int beta )
;-----------------------------------------------------------------------------
cglobal deblock_%1_luma_intra, 4,6,16,0-(1-ARCH_X86_64)*0x50-WIN64*0x10
    lea     r4, [r1*4]
    lea     r5, [r1*3] ; 3*stride
    neg     r4
    add     r4, r0     ; pix-4*stride
    mova    p1, [r4+2*r1]
    mova    p0, [r4+r5]
    mova    q0, [r0]
    mova    q1, [r0+r1]
%if ARCH_X86_64
    pxor    mpb_0, mpb_0
    mova    mpb_1, [pb_1]
    LOAD_MASK r2d, r3d, t5 ; m5=beta-1, t5=alpha-1, m7=mask0
    SWAP    7, 12 ; m12=mask0
    pavgb   t5, mpb_0
    pavgb   t5, mpb_1 ; alpha/4+1
    movdqa  p2, [r4+r1]
    movdqa  q2, [r0+2*r1]
    DIFF_GT2 p0, q0, t5, t0, t3    ; t0 = |p0-q0| > alpha/4+1
    DIFF_GT2 p0, p2, m5, t2, t5, 1 ; mask1 = |p2-p0| > beta-1
    DIFF_GT2 q0, q2, m5, t4, t5, 1 ; t4 = |q2-q0| > beta-1
    pand    t0, mask0
    pand    t4, t0
    pand    t2, t0
    mova    mask1q, t4
    mova    mask1p, t2
%else
    LOAD_MASK r2d, r3d, t5 ; m5=beta-1, t5=alpha-1, m7=mask0
    mova    m4, t5
    mova    mask0, m7
    pavgb   m4, [pb_0]
    pavgb   m4, [pb_1] ; alpha/4+1
    DIFF_GT2 p0, q0, m4, m6, m7    ; m6 = |p0-q0| > alpha/4+1
    pand    m6, mask0
    DIFF_GT2 p0, p2, m5, m4, m7, 1 ; m4 = |p2-p0| > beta-1
    pand    m4, m6
    mova    mask1p, m4
    DIFF_GT2 q0, q2, m5, m4, m7, 1 ; m4 = |q2-q0| > beta-1
    pand    m4, m6
    mova    mask1q, m4
%endif
    LUMA_INTRA_P012 [r4+r5], [r4+2*r1], [r4+r1], [r4]
    LUMA_INTRA_SWAP_PQ
    LUMA_INTRA_P012 [r0], [r0+r1], [r0+2*r1], [r0+r5]
.end:
    REP_RET

%if cpuflag(avx)
INIT_XMM cpuname
%else
INIT_MMX cpuname
%endif
%if ARCH_X86_64
;-----------------------------------------------------------------------------
; void deblock_h_luma_intra( uint8_t *pix, intptr_t stride, int alpha, int beta )
;-----------------------------------------------------------------------------
cglobal deblock_h_luma_intra, 4,9,0,0x80
    lea    r8, [r1*3]
    lea    r6, [r0-4]
    lea    r5, [r0-4+r8]
%if WIN64
    %define pix_tmp rsp+0x20 ; shadow space
%else
    %define pix_tmp rsp
%endif

    ; transpose 8x16 -> tmp space
    TRANSPOSE8x8_MEM  PASS8ROWS(r6, r5, r1, r8), PASS8ROWS(pix_tmp, pix_tmp+0x30, 0x10, 0x30)
    lea    r6, [r6+r1*8]
    lea    r5, [r5+r1*8]
    TRANSPOSE8x8_MEM  PASS8ROWS(r6, r5, r1, r8), PASS8ROWS(pix_tmp+8, pix_tmp+0x38, 0x10, 0x30)

    mov    r7, r1
    lea    r0, [pix_tmp+0x40]
    mov    r1, 0x10
    call   deblock_v_luma_intra

    ; transpose 16x6 -> original space (but we can't write only 6 pixels, so really 16x8)
    lea    r5, [r6+r8]
    TRANSPOSE8x8_MEM  PASS8ROWS(pix_tmp+8, pix_tmp+0x38, 0x10, 0x30), PASS8ROWS(r6, r5, r7, r8)
    shl    r7, 3
    sub    r6, r7
    sub    r5, r7
    shr    r7, 3
    TRANSPOSE8x8_MEM  PASS8ROWS(pix_tmp, pix_tmp+0x30, 0x10, 0x30), PASS8ROWS(r6, r5, r7, r8)
    RET
%else
cglobal deblock_h_luma_intra, 2,4,8,0x80
    lea    r3,  [r1*3]
    sub    r0,  4
    lea    r2,  [r0+r3]
    %define pix_tmp rsp

    ; transpose 8x16 -> tmp space
    TRANSPOSE8x8_MEM  PASS8ROWS(r0, r2, r1, r3), PASS8ROWS(pix_tmp, pix_tmp+0x30, 0x10, 0x30)
    lea    r0,  [r0+r1*8]
    lea    r2,  [r2+r1*8]
    TRANSPOSE8x8_MEM  PASS8ROWS(r0, r2, r1, r3), PASS8ROWS(pix_tmp+8, pix_tmp+0x38, 0x10, 0x30)

    lea    r0,  [pix_tmp+0x40]
    PUSH   dword r3m
    PUSH   dword r2m
    PUSH   dword 16
    PUSH   r0
    call   deblock_%1_luma_intra
%ifidn %1, v8
    add    dword [rsp], 8 ; pix_tmp+8
    call   deblock_%1_luma_intra
%endif
    ADD    esp, 16

    mov    r1,  r1m
    mov    r0,  r0mp
    lea    r3,  [r1*3]
    sub    r0,  4
    lea    r2,  [r0+r3]
    ; transpose 16x6 -> original space (but we can't write only 6 pixels, so really 16x8)
    TRANSPOSE8x8_MEM  PASS8ROWS(pix_tmp, pix_tmp+0x30, 0x10, 0x30), PASS8ROWS(r0, r2, r1, r3)
    lea    r0,  [r0+r1*8]
    lea    r2,  [r2+r1*8]
    TRANSPOSE8x8_MEM  PASS8ROWS(pix_tmp+8, pix_tmp+0x38, 0x10, 0x30), PASS8ROWS(r0, r2, r1, r3)
    RET
%endif ; ARCH_X86_64
%endmacro ; DEBLOCK_LUMA_INTRA

INIT_XMM sse2
DEBLOCK_LUMA_INTRA v
INIT_XMM avx
DEBLOCK_LUMA_INTRA v
%if ARCH_X86_64 == 0
INIT_MMX mmx2
DEBLOCK_LUMA_INTRA v8
%endif
%endif ; !HIGH_BIT_DEPTH

%if HIGH_BIT_DEPTH
; in: %1=p0, %2=q0, %3=p1, %4=q1, %5=mask, %6=tmp, %7=tmp
; out: %1=p0', %2=q0'
%macro CHROMA_DEBLOCK_P0_Q0_INTRA 7
    mova    %6, [pw_2]
    paddw   %6, %3
    paddw   %6, %4
    paddw   %7, %6, %2
    paddw   %6, %1
    paddw   %6, %3
    paddw   %7, %4
    psraw   %6, 2
    psraw   %7, 2
    psubw   %6, %1
    psubw   %7, %2
    pand    %6, %5
    pand    %7, %5
    paddw   %1, %6
    paddw   %2, %7
%endmacro

; out: m0-m3
; clobbers: m4-m7
%macro CHROMA_H_LOAD 0-1
    movq        m0, [r0-8] ; p1 p1 p0 p0
    movq        m2, [r0]   ; q0 q0 q1 q1
    movq        m5, [r0+r1-8]
    movq        m7, [r0+r1]
%if mmsize == 8
    mova        m1, m0
    mova        m3, m2
    punpckldq   m0, m5 ; p1
    punpckhdq   m1, m5 ; p0
    punpckldq   m2, m7 ; q0
    punpckhdq   m3, m7 ; q1
%else
    movq        m4, [r0+r1*2-8]
    movq        m6, [r0+r1*2]
    movq        m1, [r0+%1-8]
    movq        m3, [r0+%1]
    punpckldq   m0, m5 ; p1 ... p0 ...
    punpckldq   m2, m7 ; q0 ... q1 ...
    punpckldq   m4, m1
    punpckldq   m6, m3
    punpckhqdq  m1, m0, m4 ; p0
    punpcklqdq  m0, m4 ; p1
    punpckhqdq  m3, m2, m6 ; q1
    punpcklqdq  m2, m6 ; q0
%endif
%endmacro

%macro CHROMA_V_LOAD 1
    mova        m0, [r0]    ; p1
    mova        m1, [r0+r1] ; p0
    mova        m2, [%1]    ; q0
    mova        m3, [%1+r1] ; q1
%endmacro

; clobbers: m1, m2, m3
%macro CHROMA_H_STORE 0-1
    SBUTTERFLY dq, 1, 2, 3
%if mmsize == 8
    movq      [r0-4], m1
    movq   [r0+r1-4], m2
%else
    movq      [r0-4], m1
    movq [r0+r1*2-4], m2
    movhps [r0+r1-4], m1
    movhps [r0+%1-4], m2
%endif
%endmacro

%macro CHROMA_V_STORE 0
    mova [r0+1*r1], m1
    mova [r0+2*r1], m2
%endmacro

%macro DEBLOCK_CHROMA 0
cglobal deblock_inter_body
    LOAD_AB     m4, m5, r2d, r3d
    LOAD_MASK   m0, m1, m2, m3, m4, m5, m7, m6, m4
    pxor        m4, m4
    LOAD_TC     m6, r4
    pmaxsw      m6, m4
    pand        m7, m6
    DEBLOCK_P0_Q0 m1, m2, m0, m3, m7, m5, m6
    ret

;-----------------------------------------------------------------------------
; void deblock_v_chroma( uint16_t *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 )
;-----------------------------------------------------------------------------
cglobal deblock_v_chroma, 5,7,8
    FIX_STRIDES r1
    mov         r5, r0
    sub         r0, r1
    sub         r0, r1
    mov         r6, 32/mmsize
.loop:
    CHROMA_V_LOAD r5
    call        deblock_inter_body
    CHROMA_V_STORE
    add         r0, mmsize
    add         r5, mmsize
    add         r4, mmsize/8
    dec         r6
    jg .loop
    RET

;-----------------------------------------------------------------------------
; void deblock_h_chroma( uint16_t *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 )
;-----------------------------------------------------------------------------
cglobal deblock_h_chroma, 5,7,8
    add         r1, r1
    mov         r5, 32/mmsize
%if mmsize == 16
    lea         r6, [r1*3]
%endif
.loop:
    CHROMA_H_LOAD r6
    call        deblock_inter_body
    CHROMA_H_STORE r6
    lea         r0, [r0+r1*(mmsize/4)]
    add         r4, mmsize/8
    dec         r5
    jg .loop
    RET


cglobal deblock_intra_body
    LOAD_AB     m4, m5, r2d, r3d
    LOAD_MASK   m0, m1, m2, m3, m4, m5, m7, m6, m4
    CHROMA_DEBLOCK_P0_Q0_INTRA m1, m2, m0, m3, m7, m5, m6
    ret

;-----------------------------------------------------------------------------
; void deblock_v_chroma_intra( uint16_t *pix, intptr_t stride, int alpha, int beta )
;-----------------------------------------------------------------------------
cglobal deblock_v_chroma_intra, 4,6,8
    add         r1, r1
    mov         r5, 32/mmsize
    movd        m5, r3d
    mov         r4, r0
    sub         r0, r1
    sub         r0, r1
    SPLATW      m5, m5
.loop:
    CHROMA_V_LOAD r4
    call        deblock_intra_body
    CHROMA_V_STORE
    add         r0, mmsize
    add         r4, mmsize
    dec         r5
    jg .loop
    RET

;-----------------------------------------------------------------------------
; void deblock_h_chroma_intra( uint16_t *pix, intptr_t stride, int alpha, int beta )
;-----------------------------------------------------------------------------
cglobal deblock_h_chroma_intra, 4,6,8
    add         r1, r1
    mov         r4, 32/mmsize
%if mmsize == 16
    lea         r5, [r1*3]
%endif
.loop:
    CHROMA_H_LOAD r5
    call        deblock_intra_body
    CHROMA_H_STORE r5
    lea         r0, [r0+r1*(mmsize/4)]
    dec         r4
    jg .loop
    RET

;-----------------------------------------------------------------------------
; void deblock_h_chroma_intra_mbaff( uint16_t *pix, intptr_t stride, int alpha, int beta )
;-----------------------------------------------------------------------------
cglobal deblock_h_chroma_intra_mbaff, 4,6,8
    add         r1, r1
%if mmsize == 8
    mov         r4, 16/mmsize
.loop:
%else
    lea         r5, [r1*3]
%endif
    CHROMA_H_LOAD r5
    LOAD_AB     m4, m5, r2d, r3d
    LOAD_MASK   m0, m1, m2, m3, m4, m5, m7, m6, m4
    CHROMA_DEBLOCK_P0_Q0_INTRA m1, m2, m0, m3, m7, m5, m6
    CHROMA_H_STORE r5
%if mmsize == 8
    lea         r0, [r0+r1*(mmsize/4)]
    dec         r4
    jg .loop
%endif
    RET

;-----------------------------------------------------------------------------
; void deblock_h_chroma_mbaff( uint16_t *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 )
;-----------------------------------------------------------------------------
cglobal deblock_h_chroma_mbaff, 5,7,8
    add         r1, r1
    lea         r6, [r1*3]
%if mmsize == 8
    mov         r5, 16/mmsize
.loop:
%endif
    CHROMA_H_LOAD r6
    LOAD_AB     m4, m5, r2d, r3d
    LOAD_MASK   m0, m1, m2, m3, m4, m5, m7, m6, m4
    movd      m6, [r4]
    punpcklbw m6, m6
    psraw m6, 8
    punpcklwd m6, m6
    pand m7, m6
    DEBLOCK_P0_Q0 m1, m2, m0, m3, m7, m5, m6
    CHROMA_H_STORE r6
%if mmsize == 8
    lea         r0, [r0+r1*(mmsize/4)]
    add         r4, mmsize/4
    dec         r5
    jg .loop
%endif
    RET

;-----------------------------------------------------------------------------
; void deblock_h_chroma_422_intra( uint16_t *pix, intptr_t stride, int alpha, int beta )
;-----------------------------------------------------------------------------
cglobal deblock_h_chroma_422_intra, 4,6,8
    add         r1, r1
    mov         r4, 64/mmsize
%if mmsize == 16
    lea         r5, [r1*3]
%endif
.loop:
    CHROMA_H_LOAD r5
    call        deblock_intra_body
    CHROMA_H_STORE r5
    lea         r0, [r0+r1*(mmsize/4)]
    dec         r4
    jg .loop
    RET

;-----------------------------------------------------------------------------
; void deblock_h_chroma_422( uint16_t *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 )
;-----------------------------------------------------------------------------
cglobal deblock_h_chroma_422, 5,7,8
    add         r1, r1
    mov         r5, 64/mmsize
    lea         r6, [r1*3]
.loop:
    CHROMA_H_LOAD r6
    LOAD_AB     m4, m5, r2m, r3d
    LOAD_MASK   m0, m1, m2, m3, m4, m5, m7, m6, m4
    pxor        m4, m4
    movd        m6, [r4-1]
    psraw       m6, 8
    SPLATW      m6, m6
    pmaxsw      m6, m4
    pand        m7, m6
    DEBLOCK_P0_Q0 m1, m2, m0, m3, m7, m5, m6
    CHROMA_H_STORE r6
    lea         r0, [r0+r1*(mmsize/4)]
%if mmsize == 16
    inc         r4
%else
    mov         r2, r5
    and         r2, 1
    add         r4, r2 ; increment once every 2 iterations
%endif
    dec         r5
    jg .loop
    RET
%endmacro ; DEBLOCK_CHROMA

%if ARCH_X86_64 == 0
INIT_MMX mmx2
DEBLOCK_CHROMA
%endif
INIT_XMM sse2
DEBLOCK_CHROMA
INIT_XMM avx
DEBLOCK_CHROMA
%endif ; HIGH_BIT_DEPTH

%if HIGH_BIT_DEPTH == 0
%macro CHROMA_V_START 0
    mov    t5, r0
    sub    t5, r1
    sub    t5, r1
%if mmsize==8
    mov   dword r0m, 2
.loop:
%endif
%endmacro

%macro CHROMA_H_START 0
    sub    r0, 4
    lea    t6, [r1*3]
    mov    t5, r0
    add    r0, t6
%endmacro

%macro CHROMA_V_LOOP 1
%if mmsize==8
    add   r0, 8
    add   t5, 8
%if %1
    add   r4, 2
%endif
    dec   dword r0m
    jg .loop
%endif
%endmacro

%macro CHROMA_H_LOOP 1
%if mmsize==8
    lea   r0, [r0+r1*4]
    lea   t5, [t5+r1*4]
%if %1
    add   r4, 2
%endif
    dec   dword r0m
    jg .loop
%endif
%endmacro

%define t5 r5
%define t6 r6

%macro DEBLOCK_CHROMA 0
cglobal chroma_inter_body
    LOAD_MASK  r2d, r3d
    movd       m6, [r4] ; tc0
    punpcklbw  m6, m6
    punpcklbw  m6, m6
    pand       m7, m6
    DEBLOCK_P0_Q0
    ret

;-----------------------------------------------------------------------------
; void deblock_v_chroma( uint8_t *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 )
;-----------------------------------------------------------------------------
cglobal deblock_v_chroma, 5,6,8
    CHROMA_V_START
    mova  m0, [t5]
    mova  m1, [t5+r1]
    mova  m2, [r0]
    mova  m3, [r0+r1]
    call chroma_inter_body
    mova  [t5+r1], m1
    mova  [r0], m2
    CHROMA_V_LOOP 1
    RET

;-----------------------------------------------------------------------------
; void deblock_h_chroma( uint8_t *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 )
;-----------------------------------------------------------------------------
cglobal deblock_h_chroma, 5,7,8
    CHROMA_H_START
%if mmsize==8
    mov   dword r0m, 2
.loop:
%endif
    TRANSPOSE4x8W_LOAD PASS8ROWS(t5, r0, r1, t6)
    call chroma_inter_body
    TRANSPOSE8x2W_STORE PASS8ROWS(t5, r0, r1, t6, 2)
    CHROMA_H_LOOP 1
    RET
%endmacro ; DEBLOCK_CHROMA

INIT_XMM sse2
DEBLOCK_CHROMA
INIT_XMM avx
DEBLOCK_CHROMA
%if ARCH_X86_64 == 0
INIT_MMX mmx2
DEBLOCK_CHROMA
%endif

;-----------------------------------------------------------------------------
; void deblock_h_chroma_mbaff( uint8_t *pix, intptr_t stride, int alpha, int beta, int8_t *tc0 )
;-----------------------------------------------------------------------------
%macro DEBLOCK_H_CHROMA_420_MBAFF 0
cglobal deblock_h_chroma_mbaff, 5,7,8
    CHROMA_H_START
    TRANSPOSE4x4W_LOAD PASS8ROWS(t5, r0, r1, t6)
    LOAD_MASK  r2d, r3d
    movd       m6, [r4] ; tc0
    punpcklbw  m6, m6
    pand       m7, m6
    DEBLOCK_P0_Q0
    TRANSPOSE4x2W_STORE PASS8ROWS(t5, r0, r1, t6, 2)
    RET
%endmacro

INIT_XMM sse2
DEBLOCK_H_CHROMA_420_MBAFF
%if ARCH_X86_64 == 0
INIT_MMX mmx2
DEBLOCK_H_CHROMA_420_MBAFF
%endif

%macro DEBLOCK_H_CHROMA_422 0
cglobal deblock_h_chroma_422, 5,8,8
%if ARCH_X86_64
    %define cntr r7
%else
    %define cntr dword r0m
%endif
    CHROMA_H_START
    mov  cntr, 32/mmsize
.loop:
    TRANSPOSE4x8W_LOAD PASS8ROWS(t5, r0, r1, t6)
    LOAD_MASK  r2d, r3d
    movd       m6, [r4] ; tc0
    punpcklbw  m6, m6
%if mmsize == 16
    punpcklbw  m6, m6
    punpcklbw  m6, m6
%else
    pshufw     m6, m6, q0000
%endif
    pand       m7, m6
    DEBLOCK_P0_Q0
    TRANSPOSE8x2W_STORE PASS8ROWS(t5, r0, r1, t6, 2)
    lea   r0, [r0+r1*(mmsize/2)]
    lea   t5, [t5+r1*(mmsize/2)]
    add   r4, mmsize/8
    dec   cntr
    jg .loop
    RET
%endmacro

INIT_MMX mmx2
DEBLOCK_H_CHROMA_422
INIT_XMM sse2
DEBLOCK_H_CHROMA_422
INIT_XMM avx
DEBLOCK_H_CHROMA_422

; in: %1=p0 %2=p1 %3=q1
; out: p0 = (p0 + q1 + 2*p1 + 2) >> 2
%macro CHROMA_INTRA_P0 3
    pxor    m4, %1, %3
    pand    m4, [pb_1] ; m4 = (p0^q1)&1
    pavgb   %1, %3
    psubusb %1, m4
    pavgb   %1, %2     ; dst = avg(p1, avg(p0,q1) - ((p0^q1)&1))
%endmacro

%define t5 r4
%define t6 r5

%macro DEBLOCK_CHROMA_INTRA_BODY 0
cglobal chroma_intra_body
    LOAD_MASK r2d, r3d
    mova   m5, m1
    mova   m6, m2
    CHROMA_INTRA_P0  m1, m0, m3
    CHROMA_INTRA_P0  m2, m3, m0
    psubb  m1, m5
    psubb  m2, m6
    pand   m1, m7
    pand   m2, m7
    paddb  m1, m5
    paddb  m2, m6
    ret
%endmacro

%macro DEBLOCK_CHROMA_INTRA 0
;-----------------------------------------------------------------------------
; void deblock_v_chroma_intra( uint8_t *pix, intptr_t stride, int alpha, int beta )
;-----------------------------------------------------------------------------
cglobal deblock_v_chroma_intra, 4,5,8
    CHROMA_V_START
    mova  m0, [t5]
    mova  m1, [t5+r1]
    mova  m2, [r0]
    mova  m3, [r0+r1]
    call chroma_intra_body
    mova  [t5+r1], m1
    mova  [r0], m2
    CHROMA_V_LOOP 0
    RET

;-----------------------------------------------------------------------------
; void deblock_h_chroma_intra( uint8_t *pix, intptr_t stride, int alpha, int beta )
;-----------------------------------------------------------------------------
cglobal deblock_h_chroma_intra, 4,6,8
    CHROMA_H_START
%if mmsize==8
    mov   dword r0m, 2
.loop:
%endif
    TRANSPOSE4x8W_LOAD  PASS8ROWS(t5, r0, r1, t6)
    call chroma_intra_body
    TRANSPOSE8x2W_STORE PASS8ROWS(t5, r0, r1, t6, 2)
    CHROMA_H_LOOP 0
    RET

cglobal deblock_h_chroma_422_intra, 4,7,8
    CHROMA_H_START
    mov   r6d, 32/mmsize
.loop:
    TRANSPOSE4x8W_LOAD  PASS8ROWS(t5, r0, r1, t6)
    call chroma_intra_body
    TRANSPOSE8x2W_STORE PASS8ROWS(t5, r0, r1, t6, 2)
    lea   r0, [r0+r1*(mmsize/2)]
    lea   t5, [t5+r1*(mmsize/2)]
    dec  r6d
    jg .loop
    RET
%endmacro ; DEBLOCK_CHROMA_INTRA

INIT_XMM sse2
DEBLOCK_CHROMA_INTRA_BODY
DEBLOCK_CHROMA_INTRA
INIT_XMM avx
DEBLOCK_CHROMA_INTRA_BODY
DEBLOCK_CHROMA_INTRA
INIT_MMX mmx2
DEBLOCK_CHROMA_INTRA_BODY
%if ARCH_X86_64 == 0
DEBLOCK_CHROMA_INTRA
%endif

;-----------------------------------------------------------------------------
; void deblock_h_chroma_intra_mbaff( uint8_t *pix, intptr_t stride, int alpha, int beta )
;-----------------------------------------------------------------------------
INIT_MMX mmx2
cglobal deblock_h_chroma_intra_mbaff, 4,6,8
    CHROMA_H_START
    TRANSPOSE4x4W_LOAD  PASS8ROWS(t5, r0, r1, t6)
    call chroma_intra_body
    TRANSPOSE4x2W_STORE PASS8ROWS(t5, r0, r1, t6, 2)
    RET
%endif ; !HIGH_BIT_DEPTH

;-----------------------------------------------------------------------------
; static void deblock_strength( uint8_t nnz[48], int8_t ref[2][40], int16_t mv[2][40][2],
;                               uint8_t bs[2][4][4], int mvy_limit, int bframe )
;-----------------------------------------------------------------------------
%define scan8start (4+1*8)
%define nnz r0+scan8start
%define ref r1+scan8start
%define mv  r2+scan8start*4
%define bs0 r3
%define bs1 r3+32

%macro LOAD_BYTES_XMM 2 ; src, aligned
%if %2
    mova      m2, [%1-4]
    mova      m1, [%1+12]
%else
    movu      m2, [%1-4]
    movu      m1, [%1+12]
%endif
    psllq     m0, m2, 8
    shufps    m2, m1, q3131 ; cur nnz, all rows
    psllq     m1, 8
    shufps    m0, m1, q3131 ; left neighbors
%if cpuflag(avx) || (%2 && cpuflag(ssse3))
    palignr   m1, m2, [%1-20], 12
%else
    pslldq    m1, m2, 4
    movd      m3, [%1-8]
    por       m1, m3 ; top neighbors
%endif
%endmacro

%if UNIX64
    DECLARE_REG_TMP 5
%else
    DECLARE_REG_TMP 4
%endif

%macro DEBLOCK_STRENGTH_XMM 0
cglobal deblock_strength, 5,5,7
    ; Prepare mv comparison register
    shl      r4d, 8
    add      r4d, 3 - (1<<8)
    movd      m6, r4d
    movifnidn t0d, r5m
    SPLATW    m6, m6
    pxor      m4, m4 ; bs0
    pxor      m5, m5 ; bs1

.lists:
    ; Check refs
    LOAD_BYTES_XMM ref, 0
    pxor      m0, m2
    pxor      m1, m2
    por       m4, m0
    por       m5, m1

    ; Check mvs
%if cpuflag(ssse3) && notcpuflag(avx)
    mova      m0, [mv+4*8*0]
    mova      m1, [mv+4*8*1]
    palignr   m3, m0, [mv+4*8*0-16], 12
    palignr   m2, m1, [mv+4*8*1-16], 12
    psubw     m0, m3
    psubw     m1, m2
    packsswb  m0, m1

    mova      m2, [mv+4*8*2]
    mova      m1, [mv+4*8*3]
    palignr   m3, m2, [mv+4*8*2-16], 12
    psubw     m2, m3
    palignr   m3, m1, [mv+4*8*3-16], 12
    psubw     m1, m3
    packsswb  m2, m1
%else
    movu      m0, [mv-4+4*8*0]
    movu      m1, [mv-4+4*8*1]
    movu      m2, [mv-4+4*8*2]
    movu      m3, [mv-4+4*8*3]
    psubw     m0, [mv+4*8*0]
    psubw     m1, [mv+4*8*1]
    psubw     m2, [mv+4*8*2]
    psubw     m3, [mv+4*8*3]
    packsswb  m0, m1
    packsswb  m2, m3
%endif
    ABSB      m0, m1
    ABSB      m2, m3
    psubusb   m0, m6
    psubusb   m2, m6
    packsswb  m0, m2
    por       m4, m0

    mova      m0, [mv+4*8*-1]
    mova      m1, [mv+4*8* 0]
    mova      m2, [mv+4*8* 1]
    mova      m3, [mv+4*8* 2]
    psubw     m0, m1
    psubw     m1, m2
    psubw     m2, m3
    psubw     m3, [mv+4*8* 3]
    packsswb  m0, m1
    packsswb  m2, m3
    ABSB      m0, m1
    ABSB      m2, m3
    psubusb   m0, m6
    psubusb   m2, m6
    packsswb  m0, m2
    por       m5, m0
    add       r1, 40
    add       r2, 4*8*5
    dec      t0d
    jge .lists

    ; Check nnz
    LOAD_BYTES_XMM nnz, 1
    por       m0, m2
    por       m1, m2
    mova      m6, [pb_1]
    pminub    m0, m6
    pminub    m1, m6
    pminub    m4, m6 ; mv ? 1 : 0
    pminub    m5, m6
    paddb     m0, m0 ; nnz ? 2 : 0
    paddb     m1, m1
    pmaxub    m4, m0
    pmaxub    m5, m1
%if cpuflag(ssse3)
    pshufb    m4, [transpose_shuf]
%else
    movhlps   m3, m4
    punpcklbw m4, m3
    movhlps   m3, m4
    punpcklbw m4, m3
%endif
    mova   [bs1], m5
    mova   [bs0], m4
    RET
%endmacro

INIT_XMM sse2
DEBLOCK_STRENGTH_XMM
INIT_XMM ssse3
DEBLOCK_STRENGTH_XMM
INIT_XMM avx
DEBLOCK_STRENGTH_XMM

%macro LOAD_BYTES_YMM 1
    movu         m0, [%1-4]       ; ___E FGHI ___J KLMN ___O PQRS ___T UVWX
    pshufb       m0, m6           ; EFGH JKLM FGHI KLMN OPQR TUVW PQRS UVWX
    vpermq       m1, m0, q3131    ; FGHI KLMN PQRS UVWX x2
    vpbroadcastd m2, [%1-8]       ; ABCD ....
    vpblendd     m0, m0, m2, 0x80
    vpermd       m0, m7, m0       ; EFGH JKLM OPQR TUVW ABCD FGHI KLMN PQRS
%endmacro

INIT_YMM avx2
cglobal deblock_strength, 5,5,8
    mova            m6, [load_bytes_ymm_shuf]
    ; Prepare mv comparison register
    shl            r4d, 8
    add            r4d, 3 - (1<<8)
    movd           xm5, r4d
    movifnidn      t0d, r5m
    vpbroadcastw    m5, xm5
    psrld           m7, m6, 4
    pxor            m4, m4 ; bs0,bs1

.lists:
    ; Check refs
    LOAD_BYTES_YMM ref
    pxor            m0, m1
    por             m4, m0

    ; Check mvs
    movu           xm0,     [mv+0*4*8-4]
    vinserti128     m0, m0, [mv-1*4*8  ], 1
    vbroadcasti128  m2,     [mv+0*4*8  ]
    vinserti128     m1, m2, [mv+1*4*8-4], 0
    psubw           m0, m2
    vbroadcasti128  m2,     [mv+1*4*8  ]
    psubw           m1, m2
    packsswb        m0, m1
    vinserti128     m1, m2, [mv+2*4*8-4], 0
    vbroadcasti128  m3,     [mv+2*4*8  ]
    vinserti128     m2, m3, [mv+3*4*8-4], 0
    psubw           m1, m3
    vbroadcasti128  m3,     [mv+3*4*8  ]
    psubw           m2, m3
    packsswb        m1, m2
    pabsb           m0, m0
    pabsb           m1, m1
    psubusb         m0, m5
    psubusb         m1, m5
    packsswb        m0, m1
    por             m4, m0
    add             r1, 40
    add             r2, 4*8*5
    dec            t0d
    jge .lists

    ; Check nnz
    LOAD_BYTES_YMM nnz
    mova            m2, [pb_1]
    por             m0, m1
    pminub          m0, m2
    pminub          m4, m2 ; mv  ? 1 : 0
    paddb           m0, m0 ; nnz ? 2 : 0
    pmaxub          m0, m4
    vextracti128 [bs1], m0, 1
    pshufb         xm0, [transpose_shuf]
    mova         [bs0], xm0
    RET

%macro LOAD_BYTES_ZMM 1
    vpermd m1, m6, [%1-12]
    pshufb m1, m7 ; EF FG GH HI JK KL LM MN OP PQ QR RS TU UV VW WX
%endmacro         ; AF BG CH DI FK GL HM IN KP LQ MR NS PU QV RW SX

INIT_ZMM avx512
cglobal deblock_strength, 5,5
    mova            m6, [load_bytes_zmm_shuf]
    shl            r4d, 8
    add            r4d, 3 - (1<<8)
    vpbroadcastw    m5, r4d
    mov            r4d, 0x34cc34cc ; {1,-1} * 11001100b
    kmovb           k1, r4d
    vpbroadcastd    m4, r4d
    movifnidn      t0d, r5m
    psrld           m7, m6, 4
    pxor           xm3, xm3

.lists:
    vbroadcasti64x2 m2,      [mv+32]
    vinserti64x2    m0, m2,  [mv-32], 2
    vbroadcasti64x2 m1,      [mv+ 0]
    vinserti64x2    m0, m0,  [mv- 4], 0
    vbroadcasti64x2 m1 {k1}, [mv+64]
    vinserti64x2    m0, m0,  [mv+60], 1
    psubw           m0, m1
    vinserti64x2    m1, m1,  [mv+28], 0
    vbroadcasti64x2 m2 {k1}, [mv+96]
    vinserti64x2    m1, m1,  [mv+92], 1
    psubw           m1, m2
    packsswb        m0, m1
    pabsb           m0, m0
    psubusb         m0, m5

    LOAD_BYTES_ZMM ref
    pmaddubsw       m1, m4           ; E-F F-G G-H H-I ...
    vpternlogd      m3, m0, m1, 0xfe ; m3 | m0 | m1
    add             r1, 40
    add             r2, 4*8*5
    dec            t0d
    jge .lists

    LOAD_BYTES_ZMM nnz
    mova           ym2, [pb_1]
    vptestmw        k1, m1, m1
    vptestmw        k2, m3, m3
    vpaddb         ym0 {k1}{z}, ym2, ym2 ; nnz ? 2 : 0
    vpmaxub        ym0 {k2}, ym2         ; mv  ? 1 : 0
    vextracti128 [bs1], ym0, 1
    pshufb         xm0, [transpose_shuf]
    mova         [bs0], xm0
    RET
