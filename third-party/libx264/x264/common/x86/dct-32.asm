;*****************************************************************************
;* dct-32.asm: x86_32 transform and zigzag
;*****************************************************************************
;* Copyright (C) 2003-2022 x264 project
;*
;* Authors: Loren Merritt <lorenm@u.washington.edu>
;*          Holger Lubitz <holger@lubitz.org>
;*          Laurent Aimar <fenrir@via.ecp.fr>
;*          Min Chen <chenm001.163.com>
;*          Christian Heine <sennindemokrit@gmx.net>
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

cextern pd_32
cextern pw_pixel_max
cextern pw_2
cextern pw_m2
cextern pw_32
cextern hsub_mul

%macro SPILL_SHUFFLE 3-* ; ptr, list of regs, list of memory offsets
    %xdefine %%base %1
    %rep %0/2
    %xdefine %%tmp m%2
    %rotate %0/2
    mova [%%base + %2*16], %%tmp
    %rotate 1-%0/2
    %endrep
%endmacro

%macro UNSPILL_SHUFFLE 3-*
    %xdefine %%base %1
    %rep %0/2
    %xdefine %%tmp m%2
    %rotate %0/2
    mova %%tmp, [%%base + %2*16]
    %rotate 1-%0/2
    %endrep
%endmacro

%macro SPILL 2+ ; assume offsets are the same as reg numbers
    SPILL_SHUFFLE %1, %2, %2
%endmacro

%macro UNSPILL 2+
    UNSPILL_SHUFFLE %1, %2, %2
%endmacro

; in: size, m0..m7
; out: 0,4,6 in memory at %10,%11,%12, rest in regs
%macro DCT8_1D 12
    SUMSUB_BA %1, %9, %2      ; %9 = s07,  %2 = d07
    SUMSUB_BA %1, %8, %3      ; %8 = s16,  %3 = d16
    SUMSUB_BA %1, %7, %4      ; %7 = s25,  %4 = d25
    SUMSUB_BA %1, %6, %5      ; %6 = s34,  %5 = d34
    SUMSUB_BA %1, %6, %9      ; %6 = a0,   %9 = a2
    SUMSUB_BA %1, %7, %8      ; %7 = a1,   %8 = a3
    SUMSUB_BA %1, %7, %6      ; %7 = dst0, %6 = dst4
    mova     %10, m%7
    mova     %11, m%6
    psra%1   m%7, m%8, 1      ; a3>>1
    padd%1   m%7, m%9         ; a2 + (a3>>1)
    psra%1   m%9, 1           ; a2>>1
    psub%1   m%9, m%8         ; (a2>>1) - a3
    mova     %12, m%9
    psra%1   m%6, m%4, 1
    padd%1   m%6, m%4         ; d25+(d25>>1)
    psub%1   m%8, m%2, m%5    ; a5 = d07-d34-(d25+(d25>>1))
    psub%1   m%8, m%6
    psra%1   m%6, m%3, 1
    padd%1   m%6, m%3         ; d16+(d16>>1)
    padd%1   m%9, m%2, m%5
    psub%1   m%9, m%6         ; a6 = d07+d34-(d16+(d16>>1))
    psra%1   m%6, m%2, 1
    padd%1   m%6, m%2         ; d07+(d07>>1)
    padd%1   m%6, m%3
    padd%1   m%6, m%4         ; a4 = d16+d25+(d07+(d07>>1))
    psra%1   m%2, m%5, 1
    padd%1   m%2, m%5         ; d34+(d34>>1)
    padd%1   m%2, m%3
    psub%1   m%2, m%4         ; a7 = d16-d25+(d34+(d34>>1))
    psra%1   m%5, m%2, 2
    padd%1   m%5, m%6         ; a4 + (a7>>2)
    psra%1   m%4, m%9, 2
    padd%1   m%4, m%8         ; a5 + (a6>>2)
    psra%1   m%6, 2
    psra%1   m%8, 2
    psub%1   m%6, m%2         ; (a4>>2) - a7
    psub%1   m%9, m%8         ; a6 - (a5>>2)
    SWAP %3, %5, %4, %7, %9, %6
%endmacro

; in: size, m[1,2,3,5,6,7], 0,4 in mem at %10,%11
; out: m0..m7
%macro IDCT8_1D 11
    psra%1   m%2, m%4, 1
    psra%1   m%6, m%8, 1
    psub%1   m%2, m%8
    padd%1   m%6, m%4
    psra%1   m%8, m%3, 1
    padd%1   m%8, m%3
    padd%1   m%8, m%5
    padd%1   m%8, m%7
    psra%1   m%4, m%7, 1
    padd%1   m%4, m%7
    padd%1   m%4, m%9
    psub%1   m%4, m%3
    psub%1   m%3, m%5
    psub%1   m%7, m%5
    padd%1   m%3, m%9
    psub%1   m%7, m%9
    psra%1   m%5, 1
    psra%1   m%9, 1
    psub%1   m%3, m%5
    psub%1   m%7, m%9
    psra%1   m%5, m%8, 2
    psra%1   m%9, m%4, 2
    padd%1   m%5, m%7
    padd%1   m%9, m%3
    psra%1   m%7, 2
    psra%1   m%3, 2
    psub%1   m%8, m%7
    psub%1   m%3, m%4
    mova     m%4, %10
    mova     m%7, %11
    SUMSUB_BA %1, %7, %4
    SUMSUB_BA %1, %6, %7
    SUMSUB_BA %1, %2, %4
    SUMSUB_BA %1, %8, %6
    SUMSUB_BA %1, %3, %2
    SUMSUB_BA %1, %9, %4
    SUMSUB_BA %1, %5, %7
    SWAP %2, %4
    SWAP %6, %8
    SWAP %2, %6, %7
    SWAP %4, %9, %8
%endmacro

%if HIGH_BIT_DEPTH

%macro SUB8x8_DCT8 0
cglobal sub8x8_dct8, 3,3,8
cglobal_label .skip_prologue
    LOAD_DIFF8x4 0,1,2,3, none,none, r1, r2
    LOAD_DIFF8x4 4,5,6,7, none,none, r1, r2

    DCT8_1D w, 0,1,2,3,4,5,6,7, [r0],[r0+0x10],[r0+0x50]
    mova  m0, [r0]

    mova  [r0+0x30], m5
    mova  [r0+0x70], m7
    TRANSPOSE4x4W 0,1,2,3,4
    WIDEN_SXWD 0,4
    WIDEN_SXWD 1,5
    WIDEN_SXWD 2,6
    WIDEN_SXWD 3,7
    DCT8_1D d, 0,4,1,5,2,6,3,7, [r0],[r0+0x80],[r0+0xC0]
    mova  [r0+0x20], m4
    mova  [r0+0x40], m1
    mova  [r0+0x60], m5
    mova  [r0+0xA0], m6
    mova  [r0+0xE0], m7
    mova  m4, [r0+0x10]
    mova  m5, [r0+0x30]
    mova  m6, [r0+0x50]
    mova  m7, [r0+0x70]

    TRANSPOSE4x4W 4,5,6,7,0
    WIDEN_SXWD 4,0
    WIDEN_SXWD 5,1
    WIDEN_SXWD 6,2
    WIDEN_SXWD 7,3
    DCT8_1D d,4,0,5,1,6,2,7,3, [r0+0x10],[r0+0x90],[r0+0xD0]
    mova  [r0+0x30], m0
    mova  [r0+0x50], m5
    mova  [r0+0x70], m1
    mova  [r0+0xB0], m2
    mova  [r0+0xF0], m3
    ret
%endmacro ; SUB8x8_DCT8

INIT_XMM sse2
SUB8x8_DCT8
INIT_XMM sse4
SUB8x8_DCT8
INIT_XMM avx
SUB8x8_DCT8

%macro ADD8x8_IDCT8 0
cglobal add8x8_idct8, 2,2
    add r1, 128
cglobal_label .skip_prologue
    UNSPILL_SHUFFLE r1, 1,2,3,5,6,7, -6,-4,-2,2,4,6
    IDCT8_1D d,0,1,2,3,4,5,6,7,[r1-128],[r1+0]
    mova   [r1+0], m4
    TRANSPOSE4x4D 0,1,2,3,4
    paddd      m0, [pd_32]
    mova       m4, [r1+0]
    SPILL_SHUFFLE   r1, 0,1,2,3, -8,-6,-4,-2
    TRANSPOSE4x4D 4,5,6,7,3
    paddd      m4, [pd_32]
    SPILL_SHUFFLE   r1, 4,5,6,7, 0,2,4,6
    UNSPILL_SHUFFLE r1, 1,2,3,5,6,7, -5,-3,-1,3,5,7
    IDCT8_1D d,0,1,2,3,4,5,6,7,[r1-112],[r1+16]
    mova  [r1+16], m4
    TRANSPOSE4x4D 0,1,2,3,4
    mova       m4, [r1+16]
    mova [r1-112], m0
    TRANSPOSE4x4D 4,5,6,7,0
    SPILL_SHUFFLE   r1, 4,5,6,7, 1,3,5,7
    UNSPILL_SHUFFLE r1, 5,6,7, -6,-4,-2
    IDCT8_1D d,4,5,6,7,0,1,2,3,[r1-128],[r1-112]
    SPILL_SHUFFLE   r1, 4,5,6,7,0,1,2,3, -8,-7,-6,-5,-4,-3,-2,-1
    UNSPILL_SHUFFLE r1, 1,2,3,5,6,7, 2,4,6,3,5,7
    IDCT8_1D d,0,1,2,3,4,5,6,7,[r1+0],[r1+16]
    SPILL_SHUFFLE   r1, 7,6,5, 7,6,5
    mova       m7, [pw_pixel_max]
    pxor       m6, m6
    mova       m5, [r1-128]
    STORE_DIFF m5, m0, m6, m7, [r0+0*FDEC_STRIDEB]
    mova       m0, [r1-112]
    STORE_DIFF m0, m1, m6, m7, [r0+1*FDEC_STRIDEB]
    mova       m0, [r1-96]
    STORE_DIFF m0, m2, m6, m7, [r0+2*FDEC_STRIDEB]
    mova       m0, [r1-80]
    STORE_DIFF m0, m3, m6, m7, [r0+3*FDEC_STRIDEB]
    mova       m0, [r1-64]
    STORE_DIFF m0, m4, m6, m7, [r0+4*FDEC_STRIDEB]
    mova       m0, [r1-48]
    mova       m1, [r1+80]
    STORE_DIFF m0, m1, m6, m7, [r0+5*FDEC_STRIDEB]
    mova       m0, [r1-32]
    mova       m1, [r1+96]
    STORE_DIFF m0, m1, m6, m7, [r0+6*FDEC_STRIDEB]
    mova       m0, [r1-16]
    mova       m1, [r1+112]
    STORE_DIFF m0, m1, m6, m7, [r0+7*FDEC_STRIDEB]
    RET
%endmacro ; ADD8x8_IDCT8

INIT_XMM sse2
ADD8x8_IDCT8
INIT_XMM avx
ADD8x8_IDCT8

%else ; !HIGH_BIT_DEPTH

INIT_MMX
ALIGN 16
load_diff_4x8_mmx:
    LOAD_DIFF m0, m7, none, [r1+0*FENC_STRIDE], [r2+0*FDEC_STRIDE]
    LOAD_DIFF m1, m7, none, [r1+1*FENC_STRIDE], [r2+1*FDEC_STRIDE]
    LOAD_DIFF m2, m7, none, [r1+2*FENC_STRIDE], [r2+2*FDEC_STRIDE]
    LOAD_DIFF m3, m7, none, [r1+3*FENC_STRIDE], [r2+3*FDEC_STRIDE]
    LOAD_DIFF m4, m7, none, [r1+4*FENC_STRIDE], [r2+4*FDEC_STRIDE]
    LOAD_DIFF m5, m7, none, [r1+5*FENC_STRIDE], [r2+5*FDEC_STRIDE]
    movq  [r0], m0
    LOAD_DIFF m6, m7, none, [r1+6*FENC_STRIDE], [r2+6*FDEC_STRIDE]
    LOAD_DIFF m7, m0, none, [r1+7*FENC_STRIDE], [r2+7*FDEC_STRIDE]
    movq  m0, [r0]
    ret

cglobal dct8_mmx
    DCT8_1D w,0,1,2,3,4,5,6,7,[r0],[r0+0x40],[r0+0x60]
    SAVE_MM_PERMUTATION
    ret

;-----------------------------------------------------------------------------
; void sub8x8_dct8( int16_t dct[8][8], uint8_t *pix1, uint8_t *pix2 )
;-----------------------------------------------------------------------------
cglobal sub8x8_dct8_mmx, 3,3
global sub8x8_dct8_mmx.skip_prologue
.skip_prologue:
    RESET_MM_PERMUTATION
    call load_diff_4x8_mmx
    call dct8_mmx
    UNSPILL r0, 0
    TRANSPOSE4x4W 0,1,2,3,4
    SPILL r0, 0,1,2,3
    UNSPILL r0, 4,6
    TRANSPOSE4x4W 4,5,6,7,0
    SPILL r0, 4,5,6,7
    RESET_MM_PERMUTATION
    add   r1, 4
    add   r2, 4
    add   r0, 8
    call load_diff_4x8_mmx
    sub   r1, 4
    sub   r2, 4
    call dct8_mmx
    sub   r0, 8
    UNSPILL r0+8, 4,6
    TRANSPOSE4x4W 4,5,6,7,0
    SPILL r0+8, 4,5,6,7
    UNSPILL r0+8, 0
    TRANSPOSE4x4W 0,1,2,3,5
    UNSPILL r0, 4,5,6,7
    SPILL_SHUFFLE r0, 0,1,2,3, 4,5,6,7
    movq  mm4, m6 ; depends on the permutation to not produce conflicts
    movq  mm0, m4
    movq  mm1, m5
    movq  mm2, mm4
    movq  mm3, m7
    RESET_MM_PERMUTATION
    UNSPILL r0+8, 4,5,6,7
    add   r0, 8
    call dct8_mmx
    sub   r0, 8
    SPILL r0+8, 1,2,3,5,7
    RESET_MM_PERMUTATION
    UNSPILL r0, 0,1,2,3,4,5,6,7
    call dct8_mmx
    SPILL r0, 1,2,3,5,7
    ret

cglobal idct8_mmx
    IDCT8_1D w,0,1,2,3,4,5,6,7,[r1+0],[r1+64]
    SAVE_MM_PERMUTATION
    ret

%macro ADD_STORE_ROW 3
    movq  m1, [r0+%1*FDEC_STRIDE]
    punpckhbw m2, m1, m0
    punpcklbw m1, m0
    paddw m1, %2
    paddw m2, %3
    packuswb m1, m2
    movq  [r0+%1*FDEC_STRIDE], m1
%endmacro

;-----------------------------------------------------------------------------
; void add8x8_idct8( uint8_t *dst, int16_t dct[8][8] )
;-----------------------------------------------------------------------------
cglobal add8x8_idct8_mmx, 2,2
global add8x8_idct8_mmx.skip_prologue
.skip_prologue:
    INIT_MMX
    add word [r1], 32
    UNSPILL r1, 1,2,3,5,6,7
    call idct8_mmx
    SPILL r1, 7
    TRANSPOSE4x4W 0,1,2,3,7
    SPILL r1, 0,1,2,3
    UNSPILL r1, 7
    TRANSPOSE4x4W 4,5,6,7,0
    SPILL r1, 4,5,6,7
    INIT_MMX
    UNSPILL r1+8, 1,2,3,5,6,7
    add r1, 8
    call idct8_mmx
    sub r1, 8
    SPILL r1+8, 7
    TRANSPOSE4x4W 0,1,2,3,7
    SPILL r1+8, 0,1,2,3
    UNSPILL r1+8, 7
    TRANSPOSE4x4W 4,5,6,7,0
    SPILL r1+8, 4,5,6,7
    INIT_MMX
    movq  m3, [r1+0x08]
    movq  m0, [r1+0x40]
    movq  [r1+0x40], m3
    movq  [r1+0x08], m0
    ; memory layout at this time:
    ; A0------ A1------
    ; B0------ F0------
    ; C0------ G0------
    ; D0------ H0------
    ; E0------ E1------
    ; B1------ F1------
    ; C1------ G1------
    ; D1------ H1------
    UNSPILL_SHUFFLE r1, 1,2,3, 5,6,7
    UNSPILL r1+8, 5,6,7
    add r1, 8
    call idct8_mmx
    sub r1, 8
    psraw m0, 6
    psraw m1, 6
    psraw m2, 6
    psraw m3, 6
    psraw m4, 6
    psraw m5, 6
    psraw m6, 6
    psraw m7, 6
    movq  [r1+0x08], m0 ; mm4
    movq  [r1+0x48], m4 ; mm5
    movq  [r1+0x58], m5 ; mm0
    movq  [r1+0x68], m6 ; mm2
    movq  [r1+0x78], m7 ; mm6
    movq  mm5, [r1+0x18]
    movq  mm6, [r1+0x28]
    movq  [r1+0x18], m1 ; mm1
    movq  [r1+0x28], m2 ; mm7
    movq  mm7, [r1+0x38]
    movq  [r1+0x38], m3 ; mm3
    movq  mm1, [r1+0x10]
    movq  mm2, [r1+0x20]
    movq  mm3, [r1+0x30]
    call idct8_mmx
    psraw m0, 6
    psraw m1, 6
    psraw m2, 6
    psraw m3, 6
    psraw m4, 6
    psraw m5, 6
    psraw m6, 6
    psraw m7, 6
    SPILL r1, 0,1,2
    pxor  m0, m0
    ADD_STORE_ROW 0, [r1+0x00], [r1+0x08]
    ADD_STORE_ROW 1, [r1+0x10], [r1+0x18]
    ADD_STORE_ROW 2, [r1+0x20], [r1+0x28]
    ADD_STORE_ROW 3, m3, [r1+0x38]
    ADD_STORE_ROW 4, m4, [r1+0x48]
    ADD_STORE_ROW 5, m5, [r1+0x58]
    ADD_STORE_ROW 6, m6, [r1+0x68]
    ADD_STORE_ROW 7, m7, [r1+0x78]
    ret

%macro DCT_SUB8 0
cglobal sub8x8_dct, 3,3
    add r2, 4*FDEC_STRIDE
cglobal_label .skip_prologue
%if cpuflag(ssse3)
    mova m7, [hsub_mul]
%endif
    LOAD_DIFF8x4 0, 1, 2, 3, 6, 7, r1, r2-4*FDEC_STRIDE
    SPILL r0, 1,2
    SWAP 2, 7
    LOAD_DIFF8x4 4, 5, 6, 7, 1, 2, r1, r2-4*FDEC_STRIDE
    UNSPILL r0, 1
    SPILL r0, 7
    SWAP 2, 7
    UNSPILL r0, 2
    DCT4_1D 0, 1, 2, 3, 7
    TRANSPOSE2x4x4W 0, 1, 2, 3, 7
    UNSPILL r0, 7
    SPILL r0, 2
    DCT4_1D 4, 5, 6, 7, 2
    TRANSPOSE2x4x4W 4, 5, 6, 7, 2
    UNSPILL r0, 2
    SPILL r0, 6
    DCT4_1D 0, 1, 2, 3, 6
    UNSPILL r0, 6
    STORE_DCT 0, 1, 2, 3, r0, 0
    DCT4_1D 4, 5, 6, 7, 3
    STORE_DCT 4, 5, 6, 7, r0, 64
    ret

;-----------------------------------------------------------------------------
; void sub8x8_dct8( int16_t dct[8][8], uint8_t *pix1, uint8_t *pix2 )
;-----------------------------------------------------------------------------
cglobal sub8x8_dct8, 3,3
    add r2, 4*FDEC_STRIDE
cglobal_label .skip_prologue
%if cpuflag(ssse3)
    mova m7, [hsub_mul]
    LOAD_DIFF8x4 0, 1, 2, 3, 4, 7, r1, r2-4*FDEC_STRIDE
    SPILL r0, 0,1
    SWAP 1, 7
    LOAD_DIFF8x4 4, 5, 6, 7, 0, 1, r1, r2-4*FDEC_STRIDE
    UNSPILL r0, 0,1
%else
    LOAD_DIFF m0, m7, none, [r1+0*FENC_STRIDE], [r2-4*FDEC_STRIDE]
    LOAD_DIFF m1, m7, none, [r1+1*FENC_STRIDE], [r2-3*FDEC_STRIDE]
    LOAD_DIFF m2, m7, none, [r1+2*FENC_STRIDE], [r2-2*FDEC_STRIDE]
    LOAD_DIFF m3, m7, none, [r1+3*FENC_STRIDE], [r2-1*FDEC_STRIDE]
    LOAD_DIFF m4, m7, none, [r1+4*FENC_STRIDE], [r2+0*FDEC_STRIDE]
    LOAD_DIFF m5, m7, none, [r1+5*FENC_STRIDE], [r2+1*FDEC_STRIDE]
    SPILL r0, 0
    LOAD_DIFF m6, m7, none, [r1+6*FENC_STRIDE], [r2+2*FDEC_STRIDE]
    LOAD_DIFF m7, m0, none, [r1+7*FENC_STRIDE], [r2+3*FDEC_STRIDE]
    UNSPILL r0, 0
%endif
    DCT8_1D w,0,1,2,3,4,5,6,7,[r0],[r0+0x40],[r0+0x60]
    UNSPILL r0, 0,4
    TRANSPOSE8x8W 0,1,2,3,4,5,6,7,[r0+0x60],[r0+0x40],1
    UNSPILL r0, 4
    DCT8_1D w,0,1,2,3,4,5,6,7,[r0],[r0+0x40],[r0+0x60]
    SPILL r0, 1,2,3,5,7
    ret
%endmacro

INIT_XMM sse2
%define movdqa movaps
%define punpcklqdq movlhps
DCT_SUB8
%undef movdqa
%undef punpcklqdq
INIT_XMM ssse3
DCT_SUB8
INIT_XMM avx
DCT_SUB8
INIT_XMM xop
DCT_SUB8

;-----------------------------------------------------------------------------
; void add8x8_idct( uint8_t *pix, int16_t dct[4][4][4] )
;-----------------------------------------------------------------------------
%macro ADD8x8 0
cglobal add8x8_idct, 2,2
    add r0, 4*FDEC_STRIDE
cglobal_label .skip_prologue
    UNSPILL_SHUFFLE r1, 0,2,1,3, 0,1,2,3
    SBUTTERFLY qdq, 0, 1, 4
    SBUTTERFLY qdq, 2, 3, 4
    UNSPILL_SHUFFLE r1, 4,6,5,7, 4,5,6,7
    SPILL r1, 0
    SBUTTERFLY qdq, 4, 5, 0
    SBUTTERFLY qdq, 6, 7, 0
    UNSPILL r1,0
    IDCT4_1D w,0,1,2,3,r1
    SPILL r1, 4
    TRANSPOSE2x4x4W 0,1,2,3,4
    UNSPILL r1, 4
    IDCT4_1D w,4,5,6,7,r1
    SPILL r1, 0
    TRANSPOSE2x4x4W 4,5,6,7,0
    UNSPILL r1, 0
    paddw m0, [pw_32]
    IDCT4_1D w,0,1,2,3,r1
    paddw m4, [pw_32]
    IDCT4_1D w,4,5,6,7,r1
    SPILL r1, 6,7
    pxor m7, m7
    DIFFx2 m0, m1, m6, m7, [r0-4*FDEC_STRIDE], [r0-3*FDEC_STRIDE]; m5
    DIFFx2 m2, m3, m6, m7, [r0-2*FDEC_STRIDE], [r0-1*FDEC_STRIDE]; m5
    UNSPILL_SHUFFLE r1, 0,2, 6,7
    DIFFx2 m4, m5, m6, m7, [r0+0*FDEC_STRIDE], [r0+1*FDEC_STRIDE]; m5
    DIFFx2 m0, m2, m6, m7, [r0+2*FDEC_STRIDE], [r0+3*FDEC_STRIDE]; m5
    STORE_IDCT m1, m3, m5, m2
    ret
%endmacro ; ADD8x8

INIT_XMM sse2
ADD8x8
INIT_XMM avx
ADD8x8

;-----------------------------------------------------------------------------
; void add8x8_idct8( uint8_t *p_dst, int16_t dct[8][8] )
;-----------------------------------------------------------------------------
%macro ADD8x8_IDCT8 0
cglobal add8x8_idct8, 2,2
    add r0, 4*FDEC_STRIDE
cglobal_label .skip_prologue
    UNSPILL r1, 1,2,3,5,6,7
    IDCT8_1D   w,0,1,2,3,4,5,6,7,[r1+0],[r1+64]
    SPILL r1, 6
    TRANSPOSE8x8W 0,1,2,3,4,5,6,7,[r1+0x60],[r1+0x40],1
    paddw      m0, [pw_32]
    SPILL r1, 0
    IDCT8_1D   w,0,1,2,3,4,5,6,7,[r1+0],[r1+64]
    SPILL r1, 6,7
    pxor       m7, m7
    DIFFx2 m0, m1, m6, m7, [r0-4*FDEC_STRIDE], [r0-3*FDEC_STRIDE]; m5
    DIFFx2 m2, m3, m6, m7, [r0-2*FDEC_STRIDE], [r0-1*FDEC_STRIDE]; m5
    UNSPILL_SHUFFLE r1, 0,2, 6,7
    DIFFx2 m4, m5, m6, m7, [r0+0*FDEC_STRIDE], [r0+1*FDEC_STRIDE]; m5
    DIFFx2 m0, m2, m6, m7, [r0+2*FDEC_STRIDE], [r0+3*FDEC_STRIDE]; m5
    STORE_IDCT m1, m3, m5, m2
    ret
%endmacro ; ADD8x8_IDCT8

INIT_XMM sse2
ADD8x8_IDCT8
INIT_XMM avx
ADD8x8_IDCT8
%endif ; !HIGH_BIT_DEPTH
