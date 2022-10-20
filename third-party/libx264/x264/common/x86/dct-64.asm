;*****************************************************************************
;* dct-64.asm: x86_64 transform and zigzag
;*****************************************************************************
;* Copyright (C) 2003-2022 x264 project
;*
;* Authors: Loren Merritt <lorenm@u.washington.edu>
;*          Holger Lubitz <holger@lubitz.org>
;*          Laurent Aimar <fenrir@via.ecp.fr>
;*          Min Chen <chenm001.163.com>
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

; in: size, m0..m7, temp, temp
; out: m0..m7
%macro DCT8_1D 11
    SUMSUB_BA %1, %6, %5, %11 ; %6=s34, %5=d34
    SUMSUB_BA %1, %7, %4, %11 ; %7=s25, %4=d25
    SUMSUB_BA %1, %8, %3, %11 ; %8=s16, %3=d16
    SUMSUB_BA %1, %9, %2, %11 ; %9=s07, %2=d07

    SUMSUB_BA %1, %7, %8, %11 ; %7=a1, %8=a3
    SUMSUB_BA %1, %6, %9, %11 ; %6=a0, %9=a2

    psra%1   m%10, m%2, 1
    padd%1   m%10, m%2
    padd%1   m%10, m%3
    padd%1   m%10, m%4 ; %10=a4

    psra%1   m%11, m%5, 1
    padd%1   m%11, m%5
    padd%1   m%11, m%3
    psub%1   m%11, m%4 ; %11=a7

    SUMSUB_BA %1, %5, %2
    psub%1   m%2, m%4
    psub%1   m%5, m%3
    psra%1   m%4, 1
    psra%1   m%3, 1
    psub%1   m%2, m%4 ; %2=a5
    psub%1   m%5, m%3 ; %5=a6

    psra%1   m%3, m%11, 2
    padd%1   m%3, m%10 ; %3=b1
    psra%1   m%10, 2
    psub%1   m%10, m%11 ; %10=b7

    SUMSUB_BA %1, %7, %6, %11 ; %7=b0, %6=b4

    psra%1   m%4, m%8, 1
    padd%1   m%4, m%9 ; %4=b2
    psra%1   m%9, 1
    psub%1   m%9, m%8 ; %9=b6

    psra%1   m%8, m%5, 2
    padd%1   m%8, m%2 ; %8=b3
    psra%1   m%2, 2
    psub%1   m%5, m%2 ; %5=b5

    SWAP %2, %7, %5, %8, %9, %10
%endmacro

%macro IDCT8_1D 11
    SUMSUB_BA %1, %6, %2, %10 ; %5=a0, %1=a2

    psra%1   m%10, m%3, 1
    padd%1   m%10, m%3
    padd%1   m%10, m%5
    padd%1   m%10, m%7  ; %9=a7

    psra%1   m%11, m%4, 1
    psub%1   m%11, m%8 ; %10=a4
    psra%1   m%8, 1
    padd%1   m%8, m%4  ; %7=a6

    psra%1   m%4, m%7, 1
    padd%1   m%4, m%7
    padd%1   m%4, m%9
    psub%1   m%4, m%3  ; %3=a5

    psub%1   m%3, m%5
    psub%1   m%7, m%5
    padd%1   m%3, m%9
    psub%1   m%7, m%9
    psra%1   m%5, 1
    psra%1   m%9, 1
    psub%1   m%3, m%5  ; %2=a3
    psub%1   m%7, m%9  ; %6=a1

    psra%1   m%5, m%10, 2
    padd%1   m%5, m%7  ; %4=b1
    psra%1   m%7, 2
    psub%1   m%10, m%7  ; %9=b7

    SUMSUB_BA %1, %8, %6, %7  ;  %7=b0, %5=b6
    SUMSUB_BA %1, %11, %2, %7 ; %10=b2, %1=b4

    psra%1   m%9, m%4, 2
    padd%1   m%9, m%3 ; %8=b3
    psra%1   m%3, 2
    psub%1   m%3, m%4 ; %2=b5

    SUMSUB_BA %1, %10, %8, %7  ; %9=c0,  %7=c7
    SUMSUB_BA %1, %3, %11, %7 ; %2=c1, %10=c6
    SUMSUB_BA %1, %9, %2, %7  ; %8=c2,  %1=c5
    SUMSUB_BA %1, %5, %6, %7  ; %4=c3,  %5=c4

    SWAP %11, %4
    SWAP  %2, %10, %7
    SWAP  %4, %9, %8
%endmacro

%if HIGH_BIT_DEPTH

%macro SUB8x8_DCT8 0
cglobal sub8x8_dct8, 3,3,14
    TAIL_CALL .skip_prologue, 0
cglobal_label .skip_prologue
    LOAD_DIFF8x4 0,1,2,3, none,none, r1, r2
    LOAD_DIFF8x4 4,5,6,7, none,none, r1, r2

    DCT8_1D w, 0,1,2,3,4,5,6,7, 8,9

    TRANSPOSE4x4W 0,1,2,3,8
    WIDEN_SXWD 0,8
    WIDEN_SXWD 1,9
    WIDEN_SXWD 2,10
    WIDEN_SXWD 3,11
    DCT8_1D d, 0,8,1,9,2,10,3,11, 12,13
    mova  [r0+0x00], m0
    mova  [r0+0x20], m8
    mova  [r0+0x40], m1
    mova  [r0+0x60], m9
    mova  [r0+0x80], m2
    mova  [r0+0xA0], m10
    mova  [r0+0xC0], m3
    mova  [r0+0xE0], m11

    TRANSPOSE4x4W 4,5,6,7,0
    WIDEN_SXWD 4,0
    WIDEN_SXWD 5,1
    WIDEN_SXWD 6,2
    WIDEN_SXWD 7,3
    DCT8_1D d,4,0,5,1,6,2,7,3, 8,9
    mova  [r0+0x10], m4
    mova  [r0+0x30], m0
    mova  [r0+0x50], m5
    mova  [r0+0x70], m1
    mova  [r0+0x90], m6
    mova  [r0+0xB0], m2
    mova  [r0+0xD0], m7
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
cglobal add8x8_idct8, 2,2,16
    add r1, 128
    TAIL_CALL .skip_prologue, 0
cglobal_label .skip_prologue
    mova     m0, [r1-128]
    mova     m1, [r1-96]
    mova     m2, [r1-64]
    mova     m3, [r1-32]
    mova     m4, [r1+ 0]
    mova     m5, [r1+32]
    mova     m6, [r1+64]
    mova     m7, [r1+96]
    IDCT8_1D d,0,1,2,3,4,5,6,7,8,9
    TRANSPOSE4x4D 0,1,2,3,8
    TRANSPOSE4x4D 4,5,6,7,8
    paddd     m0, [pd_32]
    paddd     m4, [pd_32]
    mova [r1+64], m6
    mova [r1+96], m7
    mova      m8, [r1-112]
    mova      m9, [r1-80]
    mova     m10, [r1-48]
    mova     m11, [r1-16]
    mova     m12, [r1+16]
    mova     m13, [r1+48]
    mova     m14, [r1+80]
    mova     m15, [r1+112]
    IDCT8_1D d,8,9,10,11,12,13,14,15,6,7
    TRANSPOSE4x4D 8,9,10,11,6
    TRANSPOSE4x4D 12,13,14,15,6
    IDCT8_1D d,0,1,2,3,8,9,10,11,6,7
    mova [r1-112], m8
    mova  [r1-80], m9
    mova       m6, [r1+64]
    mova       m7, [r1+96]
    IDCT8_1D d,4,5,6,7,12,13,14,15,8,9
    pxor       m8, m8
    mova       m9, [pw_pixel_max]
    STORE_DIFF m0, m4, m8, m9, [r0+0*FDEC_STRIDEB]
    STORE_DIFF m1, m5, m8, m9, [r0+1*FDEC_STRIDEB]
    STORE_DIFF m2, m6, m8, m9, [r0+2*FDEC_STRIDEB]
    STORE_DIFF m3, m7, m8, m9, [r0+3*FDEC_STRIDEB]
    mova       m0, [r1-112]
    mova       m1, [r1-80]
    STORE_DIFF  m0, m12, m8, m9, [r0+4*FDEC_STRIDEB]
    STORE_DIFF  m1, m13, m8, m9, [r0+5*FDEC_STRIDEB]
    STORE_DIFF m10, m14, m8, m9, [r0+6*FDEC_STRIDEB]
    STORE_DIFF m11, m15, m8, m9, [r0+7*FDEC_STRIDEB]
    ret
%endmacro ; ADD8x8_IDCT8

INIT_XMM sse2
ADD8x8_IDCT8
INIT_XMM avx
ADD8x8_IDCT8

%else ; !HIGH_BIT_DEPTH

%macro DCT_SUB8 0
cglobal sub8x8_dct, 3,3,10
    add r2, 4*FDEC_STRIDE
%if cpuflag(ssse3)
    mova m7, [hsub_mul]
%endif
    TAIL_CALL .skip_prologue, 0
cglobal_label .skip_prologue
    SWAP 7, 9
    LOAD_DIFF8x4 0, 1, 2, 3, 8, 9, r1, r2-4*FDEC_STRIDE
    LOAD_DIFF8x4 4, 5, 6, 7, 8, 9, r1, r2-4*FDEC_STRIDE
    DCT4_1D 0, 1, 2, 3, 8
    TRANSPOSE2x4x4W 0, 1, 2, 3, 8
    DCT4_1D 4, 5, 6, 7, 8
    TRANSPOSE2x4x4W 4, 5, 6, 7, 8
    DCT4_1D 0, 1, 2, 3, 8
    STORE_DCT 0, 1, 2, 3, r0, 0
    DCT4_1D 4, 5, 6, 7, 8
    STORE_DCT 4, 5, 6, 7, r0, 64
    ret

;-----------------------------------------------------------------------------
; void sub8x8_dct8( int16_t dct[8][8], uint8_t *pix1, uint8_t *pix2 )
;-----------------------------------------------------------------------------
cglobal sub8x8_dct8, 3,3,11
    add r2, 4*FDEC_STRIDE
%if cpuflag(ssse3)
    mova m7, [hsub_mul]
%endif
    TAIL_CALL .skip_prologue, 0
cglobal_label .skip_prologue
    SWAP 7, 10
    LOAD_DIFF8x4  0, 1, 2, 3, 4, 10, r1, r2-4*FDEC_STRIDE
    LOAD_DIFF8x4  4, 5, 6, 7, 8, 10, r1, r2-4*FDEC_STRIDE
    DCT8_1D    w, 0,1,2,3,4,5,6,7,8,9
    TRANSPOSE8x8W 0,1,2,3,4,5,6,7,8
    DCT8_1D    w, 0,1,2,3,4,5,6,7,8,9
    movdqa  [r0+0x00], m0
    movdqa  [r0+0x10], m1
    movdqa  [r0+0x20], m2
    movdqa  [r0+0x30], m3
    movdqa  [r0+0x40], m4
    movdqa  [r0+0x50], m5
    movdqa  [r0+0x60], m6
    movdqa  [r0+0x70], m7
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

INIT_YMM avx2
cglobal sub16x16_dct8, 3,3,10
    add  r0, 128
    add  r2, 4*FDEC_STRIDE
    call .sub16x8_dct8
    add  r0, 256
    add  r1, FENC_STRIDE*8
    add  r2, FDEC_STRIDE*8
    call .sub16x8_dct8
    RET
.sub16x8_dct8:
    LOAD_DIFF16x2_AVX2 0, 1, 2, 3, 0, 1
    LOAD_DIFF16x2_AVX2 2, 3, 4, 5, 2, 3
    LOAD_DIFF16x2_AVX2 4, 5, 6, 7, 4, 5
    LOAD_DIFF16x2_AVX2 6, 7, 8, 9, 6, 7
    DCT8_1D    w, 0,1,2,3,4,5,6,7,8,9
    TRANSPOSE8x8W 0,1,2,3,4,5,6,7,8
    DCT8_1D    w, 0,1,2,3,4,5,6,7,8,9
    mova    [r0-0x80+0x00], xm0
    vextracti128 [r0+0x00], m0, 1
    mova    [r0-0x80+0x10], xm1
    vextracti128 [r0+0x10], m1, 1
    mova    [r0-0x80+0x20], xm2
    vextracti128 [r0+0x20], m2, 1
    mova    [r0-0x80+0x30], xm3
    vextracti128 [r0+0x30], m3, 1
    mova    [r0-0x80+0x40], xm4
    vextracti128 [r0+0x40], m4, 1
    mova    [r0-0x80+0x50], xm5
    vextracti128 [r0+0x50], m5, 1
    mova    [r0-0x80+0x60], xm6
    vextracti128 [r0+0x60], m6, 1
    mova    [r0-0x80+0x70], xm7
    vextracti128 [r0+0x70], m7, 1
    ret

;-----------------------------------------------------------------------------
; void add8x8_idct8( uint8_t *p_dst, int16_t dct[8][8] )
;-----------------------------------------------------------------------------
%macro ADD8x8_IDCT8 0
cglobal add8x8_idct8, 2,2,11
    add r0, 4*FDEC_STRIDE
    pxor m7, m7
    TAIL_CALL .skip_prologue, 0
cglobal_label .skip_prologue
    SWAP 7, 9
    movdqa  m0, [r1+0x00]
    movdqa  m1, [r1+0x10]
    movdqa  m2, [r1+0x20]
    movdqa  m3, [r1+0x30]
    movdqa  m4, [r1+0x40]
    movdqa  m5, [r1+0x50]
    movdqa  m6, [r1+0x60]
    movdqa  m7, [r1+0x70]
    IDCT8_1D      w,0,1,2,3,4,5,6,7,8,10
    TRANSPOSE8x8W 0,1,2,3,4,5,6,7,8
    paddw         m0, [pw_32] ; rounding for the >>6 at the end
    IDCT8_1D      w,0,1,2,3,4,5,6,7,8,10
    DIFFx2 m0, m1, m8, m9, [r0-4*FDEC_STRIDE], [r0-3*FDEC_STRIDE]
    DIFFx2 m2, m3, m8, m9, [r0-2*FDEC_STRIDE], [r0-1*FDEC_STRIDE]
    DIFFx2 m4, m5, m8, m9, [r0+0*FDEC_STRIDE], [r0+1*FDEC_STRIDE]
    DIFFx2 m6, m7, m8, m9, [r0+2*FDEC_STRIDE], [r0+3*FDEC_STRIDE]
    STORE_IDCT m1, m3, m5, m7
    ret
%endmacro ; ADD8x8_IDCT8

INIT_XMM sse2
ADD8x8_IDCT8
INIT_XMM avx
ADD8x8_IDCT8

;-----------------------------------------------------------------------------
; void add8x8_idct( uint8_t *pix, int16_t dct[4][4][4] )
;-----------------------------------------------------------------------------
%macro ADD8x8 0
cglobal add8x8_idct, 2,2,11
    add  r0, 4*FDEC_STRIDE
    pxor m7, m7
    TAIL_CALL .skip_prologue, 0
cglobal_label .skip_prologue
    SWAP 7, 9
    mova   m0, [r1+ 0]
    mova   m2, [r1+16]
    mova   m1, [r1+32]
    mova   m3, [r1+48]
    SBUTTERFLY qdq, 0, 1, 4
    SBUTTERFLY qdq, 2, 3, 4
    mova   m4, [r1+64]
    mova   m6, [r1+80]
    mova   m5, [r1+96]
    mova   m7, [r1+112]
    SBUTTERFLY qdq, 4, 5, 8
    SBUTTERFLY qdq, 6, 7, 8
    IDCT4_1D w,0,1,2,3,8,10
    TRANSPOSE2x4x4W 0,1,2,3,8
    IDCT4_1D w,4,5,6,7,8,10
    TRANSPOSE2x4x4W 4,5,6,7,8
    paddw m0, [pw_32]
    IDCT4_1D w,0,1,2,3,8,10
    paddw m4, [pw_32]
    IDCT4_1D w,4,5,6,7,8,10
    DIFFx2 m0, m1, m8, m9, [r0-4*FDEC_STRIDE], [r0-3*FDEC_STRIDE]
    DIFFx2 m2, m3, m8, m9, [r0-2*FDEC_STRIDE], [r0-1*FDEC_STRIDE]
    DIFFx2 m4, m5, m8, m9, [r0+0*FDEC_STRIDE], [r0+1*FDEC_STRIDE]
    DIFFx2 m6, m7, m8, m9, [r0+2*FDEC_STRIDE], [r0+3*FDEC_STRIDE]
    STORE_IDCT m1, m3, m5, m7
    ret
%endmacro ; ADD8x8

INIT_XMM sse2
ADD8x8
INIT_XMM avx
ADD8x8

%endif ; !HIGH_BIT_DEPTH
