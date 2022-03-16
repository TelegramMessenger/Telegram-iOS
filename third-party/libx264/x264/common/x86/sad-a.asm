;*****************************************************************************
;* sad-a.asm: x86 sad functions
;*****************************************************************************
;* Copyright (C) 2003-2022 x264 project
;*
;* Authors: Loren Merritt <lorenm@u.washington.edu>
;*          Fiona Glaser <fiona@x264.com>
;*          Laurent Aimar <fenrir@via.ecp.fr>
;*          Alex Izvorski <aizvorksi@gmail.com>
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

SECTION_RODATA 32

pb_shuf8x8c2: times 2 db 0,0,0,0,8,8,8,8,-1,-1,-1,-1,-1,-1,-1,-1
hpred_shuf: db 0,0,2,2,8,8,10,10,1,1,3,3,9,9,11,11

SECTION .text

cextern pb_3
cextern pb_shuf8x8c
cextern pw_8
cextern sw_64

;=============================================================================
; SAD MMX
;=============================================================================

%macro SAD_INC_2x16P 0
    movq    mm1,    [r0]
    movq    mm2,    [r0+8]
    movq    mm3,    [r0+r1]
    movq    mm4,    [r0+r1+8]
    psadbw  mm1,    [r2]
    psadbw  mm2,    [r2+8]
    psadbw  mm3,    [r2+r3]
    psadbw  mm4,    [r2+r3+8]
    lea     r0,     [r0+2*r1]
    paddw   mm1,    mm2
    paddw   mm3,    mm4
    lea     r2,     [r2+2*r3]
    paddw   mm0,    mm1
    paddw   mm0,    mm3
%endmacro

%macro SAD_INC_2x8P 0
    movq    mm1,    [r0]
    movq    mm2,    [r0+r1]
    psadbw  mm1,    [r2]
    psadbw  mm2,    [r2+r3]
    lea     r0,     [r0+2*r1]
    paddw   mm0,    mm1
    paddw   mm0,    mm2
    lea     r2,     [r2+2*r3]
%endmacro

%macro SAD_INC_2x4P 0
    movd    mm1,    [r0]
    movd    mm2,    [r2]
    punpckldq mm1,  [r0+r1]
    punpckldq mm2,  [r2+r3]
    psadbw  mm1,    mm2
    paddw   mm0,    mm1
    lea     r0,     [r0+2*r1]
    lea     r2,     [r2+2*r3]
%endmacro

;-----------------------------------------------------------------------------
; int pixel_sad_16x16( uint8_t *, intptr_t, uint8_t *, intptr_t )
;-----------------------------------------------------------------------------
%macro SAD 2
cglobal pixel_sad_%1x%2_mmx2, 4,4
    pxor    mm0, mm0
%rep %2/2
    SAD_INC_2x%1P
%endrep
    movd    eax, mm0
    RET
%endmacro

SAD 16, 16
SAD 16,  8
SAD  8, 16
SAD  8,  8
SAD  8,  4
SAD  4, 16
SAD  4,  8
SAD  4,  4

;=============================================================================
; SAD XMM
;=============================================================================

%macro SAD_END_SSE2 0
    MOVHL   m1, m0
    paddw   m0, m1
    movd   eax, m0
    RET
%endmacro

;-----------------------------------------------------------------------------
; int pixel_sad_16x16( uint8_t *, intptr_t, uint8_t *, intptr_t )
;-----------------------------------------------------------------------------
%macro SAD_W16 1 ; h
cglobal pixel_sad_16x%1, 4,4
%ifidn cpuname, sse2
.skip_prologue:
%endif
%assign %%i 0
%if ARCH_X86_64
    lea  r6, [3*r1] ; r6 results in fewer REX prefixes than r4 and both are volatile
    lea  r5, [3*r3]
%rep %1/4
    movu     m1, [r2]
    psadbw   m1, [r0]
    movu     m3, [r2+r3]
    psadbw   m3, [r0+r1]
    movu     m2, [r2+2*r3]
    psadbw   m2, [r0+2*r1]
    movu     m4, [r2+r5]
    psadbw   m4, [r0+r6]
%if %%i != %1/4-1
    lea      r2, [r2+4*r3]
    lea      r0, [r0+4*r1]
%endif
    paddw    m1, m3
    paddw    m2, m4
    ACCUM paddw, 0, 1, %%i
    paddw    m0, m2
    %assign %%i %%i+1
%endrep
%else     ; The cost of having to save and restore registers on x86-32
%rep %1/2 ; nullifies the benefit of having 3*stride in registers.
    movu     m1, [r2]
    psadbw   m1, [r0]
    movu     m2, [r2+r3]
    psadbw   m2, [r0+r1]
%if %%i != %1/2-1
    lea      r2, [r2+2*r3]
    lea      r0, [r0+2*r1]
%endif
    ACCUM paddw, 0, 1, %%i
    paddw    m0, m2
    %assign %%i %%i+1
%endrep
%endif
    SAD_END_SSE2
%endmacro

INIT_XMM sse2
SAD_W16 16
SAD_W16 8
INIT_XMM sse3
SAD_W16 16
SAD_W16 8
INIT_XMM sse2, aligned
SAD_W16 16
SAD_W16 8

%macro SAD_INC_4x8P_SSE 1
    movq    m1, [r0]
    movq    m2, [r0+r1]
    lea     r0, [r0+2*r1]
    movq    m3, [r2]
    movq    m4, [r2+r3]
    lea     r2, [r2+2*r3]
    movhps  m1, [r0]
    movhps  m2, [r0+r1]
    movhps  m3, [r2]
    movhps  m4, [r2+r3]
    lea     r0, [r0+2*r1]
    psadbw  m1, m3
    psadbw  m2, m4
    lea     r2, [r2+2*r3]
    ACCUM paddw, 0, 1, %1
    paddw   m0, m2
%endmacro

INIT_XMM
;Even on Nehalem, no sizes other than 8x16 benefit from this method.
cglobal pixel_sad_8x16_sse2, 4,4
    SAD_INC_4x8P_SSE 0
    SAD_INC_4x8P_SSE 1
    SAD_INC_4x8P_SSE 1
    SAD_INC_4x8P_SSE 1
    SAD_END_SSE2

%macro SAD_W48_AVX512 3 ; w, h, d/q
cglobal pixel_sad_%1x%2, 4,4
    kxnorb        k1, k1, k1
    kaddb         k1, k1, k1
%assign %%i 0
%if ARCH_X86_64 && %2 != 4
    lea           r6, [3*r1]
    lea           r5, [3*r3]
%rep %2/4
    mov%3         m1,      [r0]
    vpbroadcast%3 m1 {k1}, [r0+r1]
    mov%3         m3,      [r2]
    vpbroadcast%3 m3 {k1}, [r2+r3]
    mov%3         m2,      [r0+2*r1]
    vpbroadcast%3 m2 {k1}, [r0+r6]
    mov%3         m4,      [r2+2*r3]
    vpbroadcast%3 m4 {k1}, [r2+r5]
%if %%i != %2/4-1
    lea           r0, [r0+4*r1]
    lea           r2, [r2+4*r3]
%endif
    psadbw        m1, m3
    psadbw        m2, m4
    ACCUM      paddd, 0, 1, %%i
    paddd         m0, m2
    %assign %%i %%i+1
%endrep
%else
%rep %2/2
    mov%3         m1,      [r0]
    vpbroadcast%3 m1 {k1}, [r0+r1]
    mov%3         m2,      [r2]
    vpbroadcast%3 m2 {k1}, [r2+r3]
%if %%i != %2/2-1
    lea           r0, [r0+2*r1]
    lea           r2, [r2+2*r3]
%endif
    psadbw        m1, m2
    ACCUM      paddd, 0, 1, %%i
    %assign %%i %%i+1
%endrep
%endif
%if %1 == 8
    punpckhqdq    m1, m0, m0
    paddd         m0, m1
%endif
    movd         eax, m0
    RET
%endmacro

INIT_XMM avx512
SAD_W48_AVX512 4,  4, d
SAD_W48_AVX512 4,  8, d
SAD_W48_AVX512 4, 16, d
SAD_W48_AVX512 8,  4, q
SAD_W48_AVX512 8,  8, q
SAD_W48_AVX512 8, 16, q

%macro SAD_W16_AVX512_START 1 ; h
    cmp  r1d, FENC_STRIDE                  ; optimized for the most common fenc case, which
    jne pixel_sad_16x%1_sse2.skip_prologue ; has the rows laid out contiguously in memory
    lea   r1, [3*r3]
%endmacro

%macro SAD_W16_AVX512_END 0
    paddd          m0, m1
    paddd          m0, m2
    paddd          m0, m3
%if mmsize == 64
    vextracti32x8 ym1, m0, 1
    paddd         ym0, ym1
%endif
    vextracti128  xm1, ym0, 1
    paddd        xmm0, xm0, xm1
    punpckhqdq   xmm1, xmm0, xmm0
    paddd        xmm0, xmm1
    movd          eax, xmm0
    RET
%endmacro

INIT_YMM avx512
cglobal pixel_sad_16x8, 4,4
    SAD_W16_AVX512_START 8
    movu         xm0, [r2]
    vinserti128   m0, [r2+r3], 1
    psadbw        m0, [r0+0*32]
    movu         xm1, [r2+2*r3]
    vinserti128   m1, [r2+r1], 1
    lea           r2, [r2+4*r3]
    psadbw        m1, [r0+1*32]
    movu         xm2, [r2]
    vinserti128   m2, [r2+r3], 1
    psadbw        m2, [r0+2*32]
    movu         xm3, [r2+2*r3]
    vinserti128   m3, [r2+r1], 1
    psadbw        m3, [r0+3*32]
    SAD_W16_AVX512_END

INIT_ZMM avx512
cglobal pixel_sad_16x16, 4,4
    SAD_W16_AVX512_START 16
    movu          xm0, [r2]
    vinserti128   ym0, [r2+r3],   1
    movu          xm1, [r2+4*r3]
    vinserti32x4   m0, [r2+2*r3], 2
    vinserti32x4   m1, [r2+2*r1], 2
    vinserti32x4   m0, [r2+r1],   3
    lea            r2, [r2+4*r3]
    vinserti32x4   m1, [r2+r3],   1
    psadbw         m0, [r0+0*64]
    vinserti32x4   m1, [r2+r1],   3
    lea            r2, [r2+4*r3]
    psadbw         m1, [r0+1*64]
    movu          xm2, [r2]
    vinserti128   ym2, [r2+r3],   1
    movu          xm3, [r2+4*r3]
    vinserti32x4   m2, [r2+2*r3], 2
    vinserti32x4   m3, [r2+2*r1], 2
    vinserti32x4   m2, [r2+r1],   3
    lea            r2, [r2+4*r3]
    vinserti32x4   m3, [r2+r3],   1
    psadbw         m2, [r0+2*64]
    vinserti32x4   m3, [r2+r1],   3
    psadbw         m3, [r0+3*64]
    SAD_W16_AVX512_END

;-----------------------------------------------------------------------------
; void pixel_vsad( pixel *src, intptr_t stride );
;-----------------------------------------------------------------------------

%if ARCH_X86_64 == 0
INIT_MMX
cglobal pixel_vsad_mmx2, 3,3
    mova      m0, [r0]
    mova      m1, [r0+8]
    mova      m2, [r0+r1]
    mova      m3, [r0+r1+8]
    lea       r0, [r0+r1*2]
    psadbw    m0, m2
    psadbw    m1, m3
    paddw     m0, m1
    sub      r2d, 2
    je .end
.loop:
    mova      m4, [r0]
    mova      m5, [r0+8]
    mova      m6, [r0+r1]
    mova      m7, [r0+r1+8]
    lea       r0, [r0+r1*2]
    psadbw    m2, m4
    psadbw    m3, m5
    psadbw    m4, m6
    psadbw    m5, m7
    ;max sum: 31*16*255(pixel_max)=126480
    paddd     m0, m2
    paddd     m0, m3
    paddd     m0, m4
    paddd     m0, m5
    mova      m2, m6
    mova      m3, m7
    sub      r2d, 2
    jg .loop
.end:
    movd     eax, m0
    RET
%endif

INIT_XMM
cglobal pixel_vsad_sse2, 3,3
    mova      m0, [r0]
    mova      m1, [r0+r1]
    lea       r0, [r0+r1*2]
    psadbw    m0, m1
    sub      r2d, 2
    je .end
.loop:
    mova      m2, [r0]
    mova      m3, [r0+r1]
    lea       r0, [r0+r1*2]
    psadbw    m1, m2
    psadbw    m2, m3
    paddw     m0, m1
    paddw     m0, m2
    mova      m1, m3
    sub      r2d, 2
    jg .loop
.end:
    MOVHL     m1, m0
    ;max sum: 31*16*255(pixel_max)=126480
    paddd     m0, m1
    movd     eax, m0
    RET

;-----------------------------------------------------------------------------
; void intra_sad_x3_4x4( uint8_t *fenc, uint8_t *fdec, int res[3] );
;-----------------------------------------------------------------------------

cglobal intra_sad_x3_4x4_mmx2, 3,3
    pxor      mm7, mm7
    movd      mm0, [r1-FDEC_STRIDE]
    movd      mm1, [r0+FENC_STRIDE*0]
    movd      mm2, [r0+FENC_STRIDE*2]
    punpckldq mm0, mm0
    punpckldq mm1, [r0+FENC_STRIDE*1]
    punpckldq mm2, [r0+FENC_STRIDE*3]
    movq      mm6, mm0
    movq      mm3, mm1
    psadbw    mm3, mm0
    psadbw    mm0, mm2
    paddw     mm0, mm3
    movd     [r2], mm0 ;V prediction cost
    movd      mm3, [r1+FDEC_STRIDE*0-4]
    movd      mm0, [r1+FDEC_STRIDE*1-4]
    movd      mm4, [r1+FDEC_STRIDE*2-4]
    movd      mm5, [r1+FDEC_STRIDE*3-4]
    punpcklbw mm3, mm0
    punpcklbw mm4, mm5
    movq      mm5, mm3
    punpckhwd mm5, mm4
    punpckhdq mm5, mm6
    psadbw    mm5, mm7
    punpckhbw mm3, mm3
    punpckhbw mm4, mm4
    punpckhwd mm3, mm3
    punpckhwd mm4, mm4
    psraw     mm5, 2
    pavgw     mm5, mm7
    punpcklbw mm5, mm5
    pshufw    mm5, mm5, 0 ;DC prediction
    movq      mm6, mm5
    psadbw    mm5, mm1
    psadbw    mm6, mm2
    psadbw    mm1, mm3
    psadbw    mm2, mm4
    paddw     mm5, mm6
    paddw     mm1, mm2
    movd   [r2+8], mm5 ;DC prediction cost
    movd   [r2+4], mm1 ;H prediction cost
    RET

;-----------------------------------------------------------------------------
; void intra_sad_x3_8x8( uint8_t *fenc, uint8_t edge[36], int res[3]);
;-----------------------------------------------------------------------------

;m0 = DC
;m6 = V
;m7 = H
;m1 = DC score
;m2 = V score
;m3 = H score
;m5 = pixel row
;m4 = temp

%macro INTRA_SAD_HVDC_ITER 2
    movq      m5, [r0+FENC_STRIDE*%1]
    movq      m4, m5
    psadbw    m4, m0
    ACCUM  paddw, 1, 4, %1
    movq      m4, m5
    psadbw    m4, m6
    ACCUM  paddw, 2, 4, %1
    pshufw    m4, m7, %2
    psadbw    m5, m4
    ACCUM  paddw, 3, 5, %1
%endmacro

INIT_MMX
cglobal intra_sad_x3_8x8_mmx2, 3,3
    movq      m7, [r1+7]
    pxor      m0, m0
    movq      m6, [r1+16]  ;V prediction
    pxor      m1, m1
    psadbw    m0, m7
    psadbw    m1, m6
    paddw     m0, m1
    paddw     m0, [pw_8]
    psrlw     m0, 4
    punpcklbw m0, m0
    pshufw    m0, m0, q0000 ;DC prediction
    punpckhbw m7, m7
    INTRA_SAD_HVDC_ITER 0, q3333
    INTRA_SAD_HVDC_ITER 1, q2222
    INTRA_SAD_HVDC_ITER 2, q1111
    INTRA_SAD_HVDC_ITER 3, q0000
    movq      m7, [r1+7]
    punpcklbw m7, m7
    INTRA_SAD_HVDC_ITER 4, q3333
    INTRA_SAD_HVDC_ITER 5, q2222
    INTRA_SAD_HVDC_ITER 6, q1111
    INTRA_SAD_HVDC_ITER 7, q0000
    movd  [r2+0], m2
    movd  [r2+4], m3
    movd  [r2+8], m1
    RET

;-----------------------------------------------------------------------------
; void intra_sad_x3_8x8c( uint8_t *fenc, uint8_t *fdec, int res[3] );
;-----------------------------------------------------------------------------

%macro INTRA_SAD_HV_ITER 1
%if cpuflag(ssse3)
    movd        m1, [r1 + FDEC_STRIDE*(%1-4) - 4]
    movd        m3, [r1 + FDEC_STRIDE*(%1-3) - 4]
    pshufb      m1, m7
    pshufb      m3, m7
%else
    movq        m1, [r1 + FDEC_STRIDE*(%1-4) - 8]
    movq        m3, [r1 + FDEC_STRIDE*(%1-3) - 8]
    punpckhbw   m1, m1
    punpckhbw   m3, m3
    pshufw      m1, m1, q3333
    pshufw      m3, m3, q3333
%endif
    movq        m4, [r0 + FENC_STRIDE*(%1+0)]
    movq        m5, [r0 + FENC_STRIDE*(%1+1)]
    psadbw      m1, m4
    psadbw      m3, m5
    psadbw      m4, m6
    psadbw      m5, m6
    paddw       m1, m3
    paddw       m4, m5
    ACCUM    paddw, 0, 1, %1
    ACCUM    paddw, 2, 4, %1
%endmacro

%macro INTRA_SAD_8x8C 0
cglobal intra_sad_x3_8x8c, 3,3
    movq        m6, [r1 - FDEC_STRIDE]
    add         r1, FDEC_STRIDE*4
%if cpuflag(ssse3)
    movq        m7, [pb_3]
%endif
    INTRA_SAD_HV_ITER 0
    INTRA_SAD_HV_ITER 2
    INTRA_SAD_HV_ITER 4
    INTRA_SAD_HV_ITER 6
    movd    [r2+4], m0
    movd    [r2+8], m2
    pxor        m7, m7
    movq        m2, [r1 + FDEC_STRIDE*-4 - 8]
    movq        m4, [r1 + FDEC_STRIDE*-2 - 8]
    movq        m3, [r1 + FDEC_STRIDE* 0 - 8]
    movq        m5, [r1 + FDEC_STRIDE* 2 - 8]
    punpckhbw   m2, [r1 + FDEC_STRIDE*-3 - 8]
    punpckhbw   m4, [r1 + FDEC_STRIDE*-1 - 8]
    punpckhbw   m3, [r1 + FDEC_STRIDE* 1 - 8]
    punpckhbw   m5, [r1 + FDEC_STRIDE* 3 - 8]
    punpckhbw   m2, m4
    punpckhbw   m3, m5
    psrlq       m2, 32
    psrlq       m3, 32
    psadbw      m2, m7 ; s2
    psadbw      m3, m7 ; s3
    movq        m1, m6
    SWAP        0, 6
    punpckldq   m0, m7
    punpckhdq   m1, m7
    psadbw      m0, m7 ; s0
    psadbw      m1, m7 ; s1
    punpcklwd   m0, m1
    punpcklwd   m2, m3
    punpckldq   m0, m2 ;s0 s1 s2 s3
    pshufw      m3, m0, q3312 ;s2,s1,s3,s3
    pshufw      m0, m0, q1310 ;s0,s1,s3,s1
    paddw       m0, m3
    psrlw       m0, 2
    pavgw       m0, m7 ; s0+s2, s1, s3, s1+s3
%if cpuflag(ssse3)
    movq2dq   xmm0, m0
    pshufb    xmm0, [pb_shuf8x8c]
    movq      xmm1, [r0+FENC_STRIDE*0]
    movq      xmm2, [r0+FENC_STRIDE*1]
    movq      xmm3, [r0+FENC_STRIDE*2]
    movq      xmm4, [r0+FENC_STRIDE*3]
    movhps    xmm1, [r0+FENC_STRIDE*4]
    movhps    xmm2, [r0+FENC_STRIDE*5]
    movhps    xmm3, [r0+FENC_STRIDE*6]
    movhps    xmm4, [r0+FENC_STRIDE*7]
    psadbw    xmm1, xmm0
    psadbw    xmm2, xmm0
    psadbw    xmm3, xmm0
    psadbw    xmm4, xmm0
    paddw     xmm1, xmm2
    paddw     xmm1, xmm3
    paddw     xmm1, xmm4
    MOVHL     xmm0, xmm1
    paddw     xmm1, xmm0
    movd      [r2], xmm1
%else
    packuswb    m0, m0
    punpcklbw   m0, m0
    movq        m1, m0
    punpcklbw   m0, m0 ; 4x dc0 4x dc1
    punpckhbw   m1, m1 ; 4x dc2 4x dc3
    movq        m2, [r0+FENC_STRIDE*0]
    movq        m3, [r0+FENC_STRIDE*1]
    movq        m4, [r0+FENC_STRIDE*2]
    movq        m5, [r0+FENC_STRIDE*3]
    movq        m6, [r0+FENC_STRIDE*4]
    movq        m7, [r0+FENC_STRIDE*5]
    psadbw      m2, m0
    psadbw      m3, m0
    psadbw      m4, m0
    psadbw      m5, m0
    movq        m0, [r0+FENC_STRIDE*6]
    psadbw      m6, m1
    psadbw      m7, m1
    psadbw      m0, m1
    psadbw      m1, [r0+FENC_STRIDE*7]
    paddw       m2, m3
    paddw       m4, m5
    paddw       m6, m7
    paddw       m0, m1
    paddw       m2, m4
    paddw       m6, m0
    paddw       m2, m6
    movd      [r2], m2
%endif
    RET
%endmacro

INIT_MMX mmx2
INTRA_SAD_8x8C
INIT_MMX ssse3
INTRA_SAD_8x8C

INIT_YMM avx2
cglobal intra_sad_x3_8x8c, 3,3,7
    vpbroadcastq m2, [r1 - FDEC_STRIDE]         ; V pred
    add          r1, FDEC_STRIDE*4-1
    pxor        xm5, xm5
    punpckldq   xm3, xm2, xm5                   ; V0 _ V1 _
    movd        xm0, [r1 + FDEC_STRIDE*-1 - 3]
    movd        xm1, [r1 + FDEC_STRIDE* 3 - 3]
    pinsrb      xm0, [r1 + FDEC_STRIDE*-4], 0
    pinsrb      xm1, [r1 + FDEC_STRIDE* 0], 0
    pinsrb      xm0, [r1 + FDEC_STRIDE*-3], 1
    pinsrb      xm1, [r1 + FDEC_STRIDE* 1], 1
    pinsrb      xm0, [r1 + FDEC_STRIDE*-2], 2
    pinsrb      xm1, [r1 + FDEC_STRIDE* 2], 2
    punpcklqdq  xm0, xm1                        ; H0 _ H1 _
    vinserti128  m3, m3, xm0, 1                 ; V0 V1 H0 H1
    pshufb      xm0, [hpred_shuf]               ; H00224466 H11335577
    psadbw       m3, m5                         ; s0 s1 s2 s3
    vpermq       m4, m3, q3312                  ; s2 s1 s3 s3
    vpermq       m3, m3, q1310                  ; s0 s1 s3 s1
    paddw        m3, m4
    psrlw        m3, 2
    pavgw        m3, m5                         ; s0+s2 s1 s3 s1+s3
    pshufb       m3, [pb_shuf8x8c2]             ; DC0 _ DC1 _
    vpblendd     m3, m3, m2, 11001100b          ; DC0 V DC1 V
    vinserti128  m1, m3, xm3, 1                 ; DC0 V DC0 V
    vperm2i128   m6, m3, m3, q0101              ; DC1 V DC1 V
    vpermq       m0, m0, q3120                  ; H00224466 _ H11335577 _
    movddup      m2, [r0+FENC_STRIDE*0]
    movddup      m4, [r0+FENC_STRIDE*2]
    pshuflw      m3, m0, q0000
    psadbw       m3, m2
    psadbw       m2, m1
    pshuflw      m5, m0, q1111
    psadbw       m5, m4
    psadbw       m4, m1
    paddw        m2, m4
    paddw        m3, m5
    movddup      m4, [r0+FENC_STRIDE*4]
    pshuflw      m5, m0, q2222
    psadbw       m5, m4
    psadbw       m4, m6
    paddw        m2, m4
    paddw        m3, m5
    movddup      m4, [r0+FENC_STRIDE*6]
    pshuflw      m5, m0, q3333
    psadbw       m5, m4
    psadbw       m4, m6
    paddw        m2, m4
    paddw        m3, m5
    vextracti128 xm0, m2, 1
    vextracti128 xm1, m3, 1
    paddw       xm2, xm0 ; DC V
    paddw       xm3, xm1 ; H
    pextrd   [r2+8], xm2, 2 ; V
    movd     [r2+4], xm3    ; H
    movd     [r2+0], xm2    ; DC
    RET


;-----------------------------------------------------------------------------
; void intra_sad_x3_16x16( uint8_t *fenc, uint8_t *fdec, int res[3] );
;-----------------------------------------------------------------------------

;xmm7: DC prediction    xmm6: H prediction  xmm5: V prediction
;xmm4: DC pred score    xmm3: H pred score  xmm2: V pred score
%macro INTRA_SAD16 0
cglobal intra_sad_x3_16x16, 3,5,8
    pxor    mm0, mm0
    pxor    mm1, mm1
    psadbw  mm0, [r1-FDEC_STRIDE+0]
    psadbw  mm1, [r1-FDEC_STRIDE+8]
    paddw   mm0, mm1
    movd    r3d, mm0
%if cpuflag(ssse3)
    mova  m1, [pb_3]
%endif
%assign x 0
%rep 16
    movzx   r4d, byte [r1-1+FDEC_STRIDE*(x&3)]
%if (x&3)==3 && x!=15
    add      r1, FDEC_STRIDE*4
%endif
    add     r3d, r4d
%assign x x+1
%endrep
    sub      r1, FDEC_STRIDE*12
    add     r3d, 16
    shr     r3d, 5
    imul    r3d, 0x01010101
    movd    m7, r3d
    mova    m5, [r1-FDEC_STRIDE]
%if mmsize==16
    pshufd  m7, m7, 0
%else
    mova    m1, [r1-FDEC_STRIDE+8]
    punpckldq m7, m7
%endif
    pxor    m4, m4
    pxor    m3, m3
    pxor    m2, m2
    mov     r3d, 15*FENC_STRIDE
.vloop:
    SPLATB_LOAD m6, r1+r3*2-1, m1
    mova    m0, [r0+r3]
    psadbw  m0, m7
    paddw   m4, m0
    mova    m0, [r0+r3]
    psadbw  m0, m5
    paddw   m2, m0
%if mmsize==8
    mova    m0, [r0+r3]
    psadbw  m0, m6
    paddw   m3, m0
    mova    m0, [r0+r3+8]
    psadbw  m0, m7
    paddw   m4, m0
    mova    m0, [r0+r3+8]
    psadbw  m0, m1
    paddw   m2, m0
    psadbw  m6, [r0+r3+8]
    paddw   m3, m6
%else
    psadbw  m6, [r0+r3]
    paddw   m3, m6
%endif
    add     r3d, -FENC_STRIDE
    jge .vloop
%if mmsize==16
    pslldq  m3, 4
    por     m3, m2
    MOVHL   m1, m3
    paddw   m3, m1
    movq  [r2+0], m3
    MOVHL   m1, m4
    paddw   m4, m1
%else
    movd  [r2+0], m2
    movd  [r2+4], m3
%endif
    movd  [r2+8], m4
    RET
%endmacro

INIT_MMX mmx2
INTRA_SAD16
INIT_XMM sse2
INTRA_SAD16
INIT_XMM ssse3
INTRA_SAD16

INIT_YMM avx2
cglobal intra_sad_x3_16x16, 3,5,6
    pxor   xm0, xm0
    psadbw xm0, [r1-FDEC_STRIDE]
    MOVHL  xm1, xm0
    paddw  xm0, xm1
    movd   r3d, xm0
%assign x 0
%rep 16
    movzx  r4d, byte [r1-1+FDEC_STRIDE*(x&3)]
%if (x&3)==3 && x!=15
    add     r1, FDEC_STRIDE*4
%endif
    add    r3d, r4d
%assign x x+1
%endrep
    sub     r1, FDEC_STRIDE*12
    add    r3d, 16
    shr    r3d, 5
    movd   xm5, r3d
    vpbroadcastb xm5, xm5
    vinserti128 m5, m5, [r1-FDEC_STRIDE], 1 ; m5 contains DC and V prediction

    pxor    m4, m4  ; DC / V accumulator
    pxor   xm3, xm3 ; H accumulator
    mov    r3d, 15*FENC_STRIDE
.vloop:
    vpbroadcastb  xm2, [r1+r3*2-1]
    vbroadcasti128 m0, [r0+r3]
    psadbw  m1, m0, m5
    psadbw xm0, xm2
    paddw   m4, m1
    paddw  xm3, xm0
    add    r3d, -FENC_STRIDE
    jge .vloop
    punpckhqdq m5, m4, m4
    MOVHL  xm2, xm3
    paddw   m4, m5      ; DC / V
    paddw  xm3, xm2     ; H
    vextracti128 xm2, m4, 1
    movd  [r2+0], xm2
    movd  [r2+4], xm3
    movd  [r2+8], xm4
    RET

;=============================================================================
; SAD x3/x4 MMX
;=============================================================================

%macro SAD_X3_START_1x8P 0
    movq    mm3,    [r0]
    movq    mm0,    [r1]
    movq    mm1,    [r2]
    movq    mm2,    [r3]
    psadbw  mm0,    mm3
    psadbw  mm1,    mm3
    psadbw  mm2,    mm3
%endmacro

%macro SAD_X3_1x8P 2
    movq    mm3,    [r0+%1]
    movq    mm4,    [r1+%2]
    movq    mm5,    [r2+%2]
    movq    mm6,    [r3+%2]
    psadbw  mm4,    mm3
    psadbw  mm5,    mm3
    psadbw  mm6,    mm3
    paddw   mm0,    mm4
    paddw   mm1,    mm5
    paddw   mm2,    mm6
%endmacro

%macro SAD_X3_START_2x4P 3
    movd      mm3,  [r0]
    movd      %1,   [r1]
    movd      %2,   [r2]
    movd      %3,   [r3]
    punpckldq mm3,  [r0+FENC_STRIDE]
    punpckldq %1,   [r1+r4]
    punpckldq %2,   [r2+r4]
    punpckldq %3,   [r3+r4]
    psadbw    %1,   mm3
    psadbw    %2,   mm3
    psadbw    %3,   mm3
%endmacro

%macro SAD_X3_2x16P 1
%if %1
    SAD_X3_START_1x8P
%else
    SAD_X3_1x8P 0, 0
%endif
    SAD_X3_1x8P 8, 8
    SAD_X3_1x8P FENC_STRIDE, r4
    SAD_X3_1x8P FENC_STRIDE+8, r4+8
    add     r0, 2*FENC_STRIDE
    lea     r1, [r1+2*r4]
    lea     r2, [r2+2*r4]
    lea     r3, [r3+2*r4]
%endmacro

%macro SAD_X3_2x8P 1
%if %1
    SAD_X3_START_1x8P
%else
    SAD_X3_1x8P 0, 0
%endif
    SAD_X3_1x8P FENC_STRIDE, r4
    add     r0, 2*FENC_STRIDE
    lea     r1, [r1+2*r4]
    lea     r2, [r2+2*r4]
    lea     r3, [r3+2*r4]
%endmacro

%macro SAD_X3_2x4P 1
%if %1
    SAD_X3_START_2x4P mm0, mm1, mm2
%else
    SAD_X3_START_2x4P mm4, mm5, mm6
    paddw     mm0,  mm4
    paddw     mm1,  mm5
    paddw     mm2,  mm6
%endif
    add     r0, 2*FENC_STRIDE
    lea     r1, [r1+2*r4]
    lea     r2, [r2+2*r4]
    lea     r3, [r3+2*r4]
%endmacro

%macro SAD_X4_START_1x8P 0
    movq    mm7,    [r0]
    movq    mm0,    [r1]
    movq    mm1,    [r2]
    movq    mm2,    [r3]
    movq    mm3,    [r4]
    psadbw  mm0,    mm7
    psadbw  mm1,    mm7
    psadbw  mm2,    mm7
    psadbw  mm3,    mm7
%endmacro

%macro SAD_X4_1x8P 2
    movq    mm7,    [r0+%1]
    movq    mm4,    [r1+%2]
    movq    mm5,    [r2+%2]
    movq    mm6,    [r3+%2]
    psadbw  mm4,    mm7
    psadbw  mm5,    mm7
    psadbw  mm6,    mm7
    psadbw  mm7,    [r4+%2]
    paddw   mm0,    mm4
    paddw   mm1,    mm5
    paddw   mm2,    mm6
    paddw   mm3,    mm7
%endmacro

%macro SAD_X4_START_2x4P 0
    movd      mm7,  [r0]
    movd      mm0,  [r1]
    movd      mm1,  [r2]
    movd      mm2,  [r3]
    movd      mm3,  [r4]
    punpckldq mm7,  [r0+FENC_STRIDE]
    punpckldq mm0,  [r1+r5]
    punpckldq mm1,  [r2+r5]
    punpckldq mm2,  [r3+r5]
    punpckldq mm3,  [r4+r5]
    psadbw    mm0,  mm7
    psadbw    mm1,  mm7
    psadbw    mm2,  mm7
    psadbw    mm3,  mm7
%endmacro

%macro SAD_X4_INC_2x4P 0
    movd      mm7,  [r0]
    movd      mm4,  [r1]
    movd      mm5,  [r2]
    punpckldq mm7,  [r0+FENC_STRIDE]
    punpckldq mm4,  [r1+r5]
    punpckldq mm5,  [r2+r5]
    psadbw    mm4,  mm7
    psadbw    mm5,  mm7
    paddw     mm0,  mm4
    paddw     mm1,  mm5
    movd      mm4,  [r3]
    movd      mm5,  [r4]
    punpckldq mm4,  [r3+r5]
    punpckldq mm5,  [r4+r5]
    psadbw    mm4,  mm7
    psadbw    mm5,  mm7
    paddw     mm2,  mm4
    paddw     mm3,  mm5
%endmacro

%macro SAD_X4_2x16P 1
%if %1
    SAD_X4_START_1x8P
%else
    SAD_X4_1x8P 0, 0
%endif
    SAD_X4_1x8P 8, 8
    SAD_X4_1x8P FENC_STRIDE, r5
    SAD_X4_1x8P FENC_STRIDE+8, r5+8
    add     r0, 2*FENC_STRIDE
    lea     r1, [r1+2*r5]
    lea     r2, [r2+2*r5]
    lea     r3, [r3+2*r5]
    lea     r4, [r4+2*r5]
%endmacro

%macro SAD_X4_2x8P 1
%if %1
    SAD_X4_START_1x8P
%else
    SAD_X4_1x8P 0, 0
%endif
    SAD_X4_1x8P FENC_STRIDE, r5
    add     r0, 2*FENC_STRIDE
    lea     r1, [r1+2*r5]
    lea     r2, [r2+2*r5]
    lea     r3, [r3+2*r5]
    lea     r4, [r4+2*r5]
%endmacro

%macro SAD_X4_2x4P 1
%if %1
    SAD_X4_START_2x4P
%else
    SAD_X4_INC_2x4P
%endif
    add     r0, 2*FENC_STRIDE
    lea     r1, [r1+2*r5]
    lea     r2, [r2+2*r5]
    lea     r3, [r3+2*r5]
    lea     r4, [r4+2*r5]
%endmacro

%macro SAD_X3_END 0
%if UNIX64
    movd    [r5+0], mm0
    movd    [r5+4], mm1
    movd    [r5+8], mm2
%else
    mov     r0, r5mp
    movd    [r0+0], mm0
    movd    [r0+4], mm1
    movd    [r0+8], mm2
%endif
    RET
%endmacro

%macro SAD_X4_END 0
    mov     r0, r6mp
    movd    [r0+0], mm0
    movd    [r0+4], mm1
    movd    [r0+8], mm2
    movd    [r0+12], mm3
    RET
%endmacro

;-----------------------------------------------------------------------------
; void pixel_sad_x3_16x16( uint8_t *fenc, uint8_t *pix0, uint8_t *pix1,
;                          uint8_t *pix2, intptr_t i_stride, int scores[3] )
;-----------------------------------------------------------------------------
%macro SAD_X 3
cglobal pixel_sad_x%1_%2x%3_mmx2, %1+2, %1+2
    SAD_X%1_2x%2P 1
%rep %3/2-1
    SAD_X%1_2x%2P 0
%endrep
    SAD_X%1_END
%endmacro

INIT_MMX
SAD_X 3, 16, 16
SAD_X 3, 16,  8
SAD_X 3,  8, 16
SAD_X 3,  8,  8
SAD_X 3,  8,  4
SAD_X 3,  4,  8
SAD_X 3,  4,  4
SAD_X 4, 16, 16
SAD_X 4, 16,  8
SAD_X 4,  8, 16
SAD_X 4,  8,  8
SAD_X 4,  8,  4
SAD_X 4,  4,  8
SAD_X 4,  4,  4



;=============================================================================
; SAD x3/x4 XMM
;=============================================================================

%macro SAD_X3_START_1x16P_SSE2 0
    mova     m2, [r0]
%if cpuflag(avx)
    psadbw   m0, m2, [r1]
    psadbw   m1, m2, [r2]
    psadbw   m2, [r3]
%else
    movu     m0, [r1]
    movu     m1, [r2]
    movu     m3, [r3]
    psadbw   m0, m2
    psadbw   m1, m2
    psadbw   m2, m3
%endif
%endmacro

%macro SAD_X3_1x16P_SSE2 2
    mova     m3, [r0+%1]
%if cpuflag(avx)
    psadbw   m4, m3, [r1+%2]
    psadbw   m5, m3, [r2+%2]
    psadbw   m3, [r3+%2]
%else
    movu     m4, [r1+%2]
    movu     m5, [r2+%2]
    movu     m6, [r3+%2]
    psadbw   m4, m3
    psadbw   m5, m3
    psadbw   m3, m6
%endif
    paddw    m0, m4
    paddw    m1, m5
    paddw    m2, m3
%endmacro

%if ARCH_X86_64
    DECLARE_REG_TMP 6
%else
    DECLARE_REG_TMP 5
%endif

%macro SAD_X3_4x16P_SSE2 2
%if %1==0
    lea  t0, [r4*3]
    SAD_X3_START_1x16P_SSE2
%else
    SAD_X3_1x16P_SSE2 FENC_STRIDE*(0+(%1&1)*4), r4*0
%endif
    SAD_X3_1x16P_SSE2 FENC_STRIDE*(1+(%1&1)*4), r4*1
    SAD_X3_1x16P_SSE2 FENC_STRIDE*(2+(%1&1)*4), r4*2
    SAD_X3_1x16P_SSE2 FENC_STRIDE*(3+(%1&1)*4), t0
%if %1 != %2-1
%if (%1&1) != 0
    add  r0, 8*FENC_STRIDE
%endif
    lea  r1, [r1+4*r4]
    lea  r2, [r2+4*r4]
    lea  r3, [r3+4*r4]
%endif
%endmacro

%macro SAD_X3_START_2x8P_SSE2 0
    movq     m3, [r0]
    movq     m0, [r1]
    movq     m1, [r2]
    movq     m2, [r3]
    movhps   m3, [r0+FENC_STRIDE]
    movhps   m0, [r1+r4]
    movhps   m1, [r2+r4]
    movhps   m2, [r3+r4]
    psadbw   m0, m3
    psadbw   m1, m3
    psadbw   m2, m3
%endmacro

%macro SAD_X3_2x8P_SSE2 4
    movq     m6, [r0+%1]
    movq     m3, [r1+%2]
    movq     m4, [r2+%2]
    movq     m5, [r3+%2]
    movhps   m6, [r0+%3]
    movhps   m3, [r1+%4]
    movhps   m4, [r2+%4]
    movhps   m5, [r3+%4]
    psadbw   m3, m6
    psadbw   m4, m6
    psadbw   m5, m6
    paddw    m0, m3
    paddw    m1, m4
    paddw    m2, m5
%endmacro

%macro SAD_X4_START_2x8P_SSE2 0
    movq     m4, [r0]
    movq     m0, [r1]
    movq     m1, [r2]
    movq     m2, [r3]
    movq     m3, [r4]
    movhps   m4, [r0+FENC_STRIDE]
    movhps   m0, [r1+r5]
    movhps   m1, [r2+r5]
    movhps   m2, [r3+r5]
    movhps   m3, [r4+r5]
    psadbw   m0, m4
    psadbw   m1, m4
    psadbw   m2, m4
    psadbw   m3, m4
%endmacro

%macro SAD_X4_2x8P_SSE2 4
    movq     m6, [r0+%1]
    movq     m4, [r1+%2]
    movq     m5, [r2+%2]
    movhps   m6, [r0+%3]
    movhps   m4, [r1+%4]
    movhps   m5, [r2+%4]
    psadbw   m4, m6
    psadbw   m5, m6
    paddw    m0, m4
    paddw    m1, m5
    movq     m4, [r3+%2]
    movq     m5, [r4+%2]
    movhps   m4, [r3+%4]
    movhps   m5, [r4+%4]
    psadbw   m4, m6
    psadbw   m5, m6
    paddw    m2, m4
    paddw    m3, m5
%endmacro

%macro SAD_X4_START_1x16P_SSE2 0
    mova     m3, [r0]
%if cpuflag(avx)
    psadbw   m0, m3, [r1]
    psadbw   m1, m3, [r2]
    psadbw   m2, m3, [r3]
    psadbw   m3, [r4]
%else
    movu     m0, [r1]
    movu     m1, [r2]
    movu     m2, [r3]
    movu     m4, [r4]
    psadbw   m0, m3
    psadbw   m1, m3
    psadbw   m2, m3
    psadbw   m3, m4
%endif
%endmacro

%macro SAD_X4_1x16P_SSE2 2
    mova     m6, [r0+%1]
%if cpuflag(avx)
    psadbw   m4, m6, [r1+%2]
    psadbw   m5, m6, [r2+%2]
%else
    movu     m4, [r1+%2]
    movu     m5, [r2+%2]
    psadbw   m4, m6
    psadbw   m5, m6
%endif
    paddw    m0, m4
    paddw    m1, m5
%if cpuflag(avx)
    psadbw   m4, m6, [r3+%2]
    psadbw   m5, m6, [r4+%2]
%else
    movu     m4, [r3+%2]
    movu     m5, [r4+%2]
    psadbw   m4, m6
    psadbw   m5, m6
%endif
    paddw    m2, m4
    paddw    m3, m5
%endmacro

%macro SAD_X4_4x16P_SSE2 2
%if %1==0
    lea  r6, [r5*3]
    SAD_X4_START_1x16P_SSE2
%else
    SAD_X4_1x16P_SSE2 FENC_STRIDE*(0+(%1&1)*4), r5*0
%endif
    SAD_X4_1x16P_SSE2 FENC_STRIDE*(1+(%1&1)*4), r5*1
    SAD_X4_1x16P_SSE2 FENC_STRIDE*(2+(%1&1)*4), r5*2
    SAD_X4_1x16P_SSE2 FENC_STRIDE*(3+(%1&1)*4), r6
%if %1 != %2-1
%if (%1&1) != 0
    add  r0, 8*FENC_STRIDE
%endif
    lea  r1, [r1+4*r5]
    lea  r2, [r2+4*r5]
    lea  r3, [r3+4*r5]
    lea  r4, [r4+4*r5]
%endif
%endmacro

%macro SAD_X3_4x8P_SSE2 2
%if %1==0
    lea  t0, [r4*3]
    SAD_X3_START_2x8P_SSE2
%else
    SAD_X3_2x8P_SSE2 FENC_STRIDE*(0+(%1&1)*4), r4*0, FENC_STRIDE*(1+(%1&1)*4), r4*1
%endif
    SAD_X3_2x8P_SSE2 FENC_STRIDE*(2+(%1&1)*4), r4*2, FENC_STRIDE*(3+(%1&1)*4), t0
%if %1 != %2-1
%if (%1&1) != 0
    add  r0, 8*FENC_STRIDE
%endif
    lea  r1, [r1+4*r4]
    lea  r2, [r2+4*r4]
    lea  r3, [r3+4*r4]
%endif
%endmacro

%macro SAD_X4_4x8P_SSE2 2
%if %1==0
    lea    r6, [r5*3]
    SAD_X4_START_2x8P_SSE2
%else
    SAD_X4_2x8P_SSE2 FENC_STRIDE*(0+(%1&1)*4), r5*0, FENC_STRIDE*(1+(%1&1)*4), r5*1
%endif
    SAD_X4_2x8P_SSE2 FENC_STRIDE*(2+(%1&1)*4), r5*2, FENC_STRIDE*(3+(%1&1)*4), r6
%if %1 != %2-1
%if (%1&1) != 0
    add  r0, 8*FENC_STRIDE
%endif
    lea  r1, [r1+4*r5]
    lea  r2, [r2+4*r5]
    lea  r3, [r3+4*r5]
    lea  r4, [r4+4*r5]
%endif
%endmacro

%macro SAD_X3_END_SSE2 0
    movifnidn r5, r5mp
%if cpuflag(ssse3)
    packssdw m0, m1
    packssdw m2, m2
    phaddd   m0, m2
    mova   [r5], m0
%else
    movhlps  m3, m0
    movhlps  m4, m1
    movhlps  m5, m2
    paddw    m0, m3
    paddw    m1, m4
    paddw    m2, m5
    movd [r5+0], m0
    movd [r5+4], m1
    movd [r5+8], m2
%endif
    RET
%endmacro

%macro SAD_X4_END_SSE2 0
    mov      r0, r6mp
%if cpuflag(ssse3)
    packssdw m0, m1
    packssdw m2, m3
    phaddd   m0, m2
    mova   [r0], m0
%else
    psllq    m1, 32
    psllq    m3, 32
    paddw    m0, m1
    paddw    m2, m3
    movhlps  m1, m0
    movhlps  m3, m2
    paddw    m0, m1
    paddw    m2, m3
    movq [r0+0], m0
    movq [r0+8], m2
%endif
    RET
%endmacro

%macro SAD_X4_START_2x8P_SSSE3 0
    movddup  m4, [r0]
    movq     m0, [r1]
    movq     m1, [r3]
    movhps   m0, [r2]
    movhps   m1, [r4]
    movddup  m5, [r0+FENC_STRIDE]
    movq     m2, [r1+r5]
    movq     m3, [r3+r5]
    movhps   m2, [r2+r5]
    movhps   m3, [r4+r5]
    psadbw   m0, m4
    psadbw   m1, m4
    psadbw   m2, m5
    psadbw   m3, m5
    paddw    m0, m2
    paddw    m1, m3
%endmacro

%macro SAD_X4_2x8P_SSSE3 4
    movddup  m6, [r0+%1]
    movq     m2, [r1+%2]
    movq     m3, [r3+%2]
    movhps   m2, [r2+%2]
    movhps   m3, [r4+%2]
    movddup  m7, [r0+%3]
    movq     m4, [r1+%4]
    movq     m5, [r3+%4]
    movhps   m4, [r2+%4]
    movhps   m5, [r4+%4]
    psadbw   m2, m6
    psadbw   m3, m6
    psadbw   m4, m7
    psadbw   m5, m7
    paddw    m0, m2
    paddw    m1, m3
    paddw    m0, m4
    paddw    m1, m5
%endmacro

%macro SAD_X4_4x8P_SSSE3 2
%if %1==0
    lea    r6, [r5*3]
    SAD_X4_START_2x8P_SSSE3
%else
    SAD_X4_2x8P_SSSE3 FENC_STRIDE*(0+(%1&1)*4), r5*0, FENC_STRIDE*(1+(%1&1)*4), r5*1
%endif
    SAD_X4_2x8P_SSSE3 FENC_STRIDE*(2+(%1&1)*4), r5*2, FENC_STRIDE*(3+(%1&1)*4), r6
%if %1 != %2-1
%if (%1&1) != 0
    add  r0, 8*FENC_STRIDE
%endif
    lea  r1, [r1+4*r5]
    lea  r2, [r2+4*r5]
    lea  r3, [r3+4*r5]
    lea  r4, [r4+4*r5]
%endif
%endmacro

%macro SAD_X4_END_SSSE3 0
    mov      r0, r6mp
    packssdw m0, m1
    mova   [r0], m0
    RET
%endmacro

%macro SAD_X3_START_2x16P_AVX2 0
    movu    m3, [r0] ; assumes FENC_STRIDE == 16
    movu   xm0, [r1]
    movu   xm1, [r2]
    movu   xm2, [r3]
    vinserti128  m0, m0, [r1+r4], 1
    vinserti128  m1, m1, [r2+r4], 1
    vinserti128  m2, m2, [r3+r4], 1
    psadbw  m0, m3
    psadbw  m1, m3
    psadbw  m2, m3
%endmacro

%macro SAD_X3_2x16P_AVX2 3
    movu    m3, [r0+%1] ; assumes FENC_STRIDE == 16
    movu   xm4, [r1+%2]
    movu   xm5, [r2+%2]
    movu   xm6, [r3+%2]
    vinserti128  m4, m4, [r1+%3], 1
    vinserti128  m5, m5, [r2+%3], 1
    vinserti128  m6, m6, [r3+%3], 1
    psadbw  m4, m3
    psadbw  m5, m3
    psadbw  m6, m3
    paddw   m0, m4
    paddw   m1, m5
    paddw   m2, m6
%endmacro

%macro SAD_X3_4x16P_AVX2 2
%if %1==0
    lea  t0, [r4*3]
    SAD_X3_START_2x16P_AVX2
%else
    SAD_X3_2x16P_AVX2 FENC_STRIDE*(0+(%1&1)*4), r4*0, r4*1
%endif
    SAD_X3_2x16P_AVX2 FENC_STRIDE*(2+(%1&1)*4), r4*2, t0
%if %1 != %2-1
%if (%1&1) != 0
    add  r0, 8*FENC_STRIDE
%endif
    lea  r1, [r1+4*r4]
    lea  r2, [r2+4*r4]
    lea  r3, [r3+4*r4]
%endif
%endmacro

%macro SAD_X4_START_2x16P_AVX2 0
    vbroadcasti128 m4, [r0]
    vbroadcasti128 m5, [r0+FENC_STRIDE]
    movu   xm0, [r1]
    movu   xm1, [r2]
    movu   xm2, [r1+r5]
    movu   xm3, [r2+r5]
    vinserti128 m0, m0, [r3], 1
    vinserti128 m1, m1, [r4], 1
    vinserti128 m2, m2, [r3+r5], 1
    vinserti128 m3, m3, [r4+r5], 1
    psadbw  m0, m4
    psadbw  m1, m4
    psadbw  m2, m5
    psadbw  m3, m5
    paddw   m0, m2
    paddw   m1, m3
%endmacro

%macro SAD_X4_2x16P_AVX2 4
    vbroadcasti128 m6, [r0+%1]
    vbroadcasti128 m7, [r0+%3]
    movu   xm2, [r1+%2]
    movu   xm3, [r2+%2]
    movu   xm4, [r1+%4]
    movu   xm5, [r2+%4]
    vinserti128 m2, m2, [r3+%2], 1
    vinserti128 m3, m3, [r4+%2], 1
    vinserti128 m4, m4, [r3+%4], 1
    vinserti128 m5, m5, [r4+%4], 1
    psadbw  m2, m6
    psadbw  m3, m6
    psadbw  m4, m7
    psadbw  m5, m7
    paddw   m0, m2
    paddw   m1, m3
    paddw   m0, m4
    paddw   m1, m5
%endmacro

%macro SAD_X4_4x16P_AVX2 2
%if %1==0
    lea  r6, [r5*3]
    SAD_X4_START_2x16P_AVX2
%else
    SAD_X4_2x16P_AVX2 FENC_STRIDE*(0+(%1&1)*4), r5*0, FENC_STRIDE*(1+(%1&1)*4), r5*1
%endif
    SAD_X4_2x16P_AVX2 FENC_STRIDE*(2+(%1&1)*4), r5*2, FENC_STRIDE*(3+(%1&1)*4), r6
%if %1 != %2-1
%if (%1&1) != 0
    add  r0, 8*FENC_STRIDE
%endif
    lea  r1, [r1+4*r5]
    lea  r2, [r2+4*r5]
    lea  r3, [r3+4*r5]
    lea  r4, [r4+4*r5]
%endif
%endmacro

%macro SAD_X3_END_AVX2 0
    movifnidn r5, r5mp
    packssdw  m0, m1        ; 0 0 1 1 0 0 1 1
    packssdw  m2, m2        ; 2 2 _ _ 2 2 _ _
    phaddd    m0, m2        ; 0 1 2 _ 0 1 2 _
    vextracti128 xm1, m0, 1
    paddd    xm0, xm1       ; 0 1 2 _
    mova    [r5], xm0
    RET
%endmacro

%macro SAD_X4_END_AVX2 0
    mov       r0, r6mp
    packssdw  m0, m1        ; 0 0 1 1 2 2 3 3
    vextracti128 xm1, m0, 1
    phaddd   xm0, xm1       ; 0 1 2 3
    mova    [r0], xm0
    RET
%endmacro

;-----------------------------------------------------------------------------
; void pixel_sad_x3_16x16( uint8_t *fenc, uint8_t *pix0, uint8_t *pix1,
;                          uint8_t *pix2, intptr_t i_stride, int scores[3] )
;-----------------------------------------------------------------------------
%macro SAD_X_SSE2 4
cglobal pixel_sad_x%1_%2x%3, 2+%1,3+%1,%4
%assign x 0
%rep %3/4
    SAD_X%1_4x%2P_SSE2 x, %3/4
%assign x x+1
%endrep
    SAD_X%1_END_SSE2
%endmacro

INIT_XMM sse2
SAD_X_SSE2 3, 16, 16, 7
SAD_X_SSE2 3, 16,  8, 7
SAD_X_SSE2 3,  8, 16, 7
SAD_X_SSE2 3,  8,  8, 7
SAD_X_SSE2 3,  8,  4, 7
SAD_X_SSE2 4, 16, 16, 7
SAD_X_SSE2 4, 16,  8, 7
SAD_X_SSE2 4,  8, 16, 7
SAD_X_SSE2 4,  8,  8, 7
SAD_X_SSE2 4,  8,  4, 7

INIT_XMM sse3
SAD_X_SSE2 3, 16, 16, 7
SAD_X_SSE2 3, 16,  8, 7
SAD_X_SSE2 4, 16, 16, 7
SAD_X_SSE2 4, 16,  8, 7

%macro SAD_X_SSSE3 3
cglobal pixel_sad_x%1_%2x%3, 2+%1,3+%1,8
%assign x 0
%rep %3/4
    SAD_X%1_4x%2P_SSSE3 x, %3/4
%assign x x+1
%endrep
    SAD_X%1_END_SSSE3
%endmacro

INIT_XMM ssse3
SAD_X_SSE2  3, 16, 16, 7
SAD_X_SSE2  3, 16,  8, 7
SAD_X_SSE2  4, 16, 16, 7
SAD_X_SSE2  4, 16,  8, 7
SAD_X_SSSE3 4,  8, 16
SAD_X_SSSE3 4,  8,  8
SAD_X_SSSE3 4,  8,  4

INIT_XMM avx
SAD_X_SSE2 3, 16, 16, 6
SAD_X_SSE2 3, 16,  8, 6
SAD_X_SSE2 4, 16, 16, 7
SAD_X_SSE2 4, 16,  8, 7

%macro SAD_X_AVX2 4
cglobal pixel_sad_x%1_%2x%3, 2+%1,3+%1,%4
%assign x 0
%rep %3/4
    SAD_X%1_4x%2P_AVX2 x, %3/4
%assign x x+1
%endrep
    SAD_X%1_END_AVX2
%endmacro

INIT_YMM avx2
SAD_X_AVX2 3, 16, 16, 7
SAD_X_AVX2 3, 16,  8, 7
SAD_X_AVX2 4, 16, 16, 8
SAD_X_AVX2 4, 16,  8, 8

%macro SAD_X_W4_AVX512 2 ; x, h
cglobal pixel_sad_x%1_4x%2, %1+2,%1+3
    mov           t1d, 0xa
    kmovb          k1, t1d
    lea            t1, [3*t0]
    kaddb          k2, k1, k1
    kshiftlb       k3, k1, 2
%assign %%i 0
%rep %2/4
    movu           m6,      [r0+%%i*64]
    vmovddup       m6 {k1}, [r0+%%i*64+32]
    movd         xmm2,      [r1]
    movd         xmm4,      [r1+t0]
    vpbroadcastd xmm2 {k1}, [r1+2*t0]
    vpbroadcastd xmm4 {k1}, [r1+t1]
    vpbroadcastd xmm2 {k2}, [r2+t0]
    vpbroadcastd xmm4 {k2}, [r2]
    vpbroadcastd xmm2 {k3}, [r2+t1]   ; a0 a2 b1 b3
    vpbroadcastd xmm4 {k3}, [r2+2*t0] ; a1 a3 b0 b2
    vpmovqd        s1, m6             ; s0 s2 s1 s3
    movd         xmm3,      [r3]
    movd         xmm5,      [r3+t0]
    vpbroadcastd xmm3 {k1}, [r3+2*t0]
    vpbroadcastd xmm5 {k1}, [r3+t1]
%if %1 == 4
    vpbroadcastd xmm3 {k2}, [r4+t0]
    vpbroadcastd xmm5 {k2}, [r4]
    vpbroadcastd xmm3 {k3}, [r4+t1]   ; c0 c2 d1 d3
    vpbroadcastd xmm5 {k3}, [r4+2*t0] ; c1 c3 d0 d2
%endif
%if %%i != %2/4-1
%assign %%j 1
%rep %1
    lea        r%+%%j, [r%+%%j+4*t0]
    %assign %%j %%j+1
%endrep
%endif
    pshufd         s2, s1, q1032
    psadbw       xmm2, s1
    psadbw       xmm4, s2
    psadbw       xmm3, s1
    psadbw       xmm5, s2
%if %%i
    paddd        xmm0, xmm2
    paddd        xmm1, xmm3
    paddd        xmm0, xmm4
    paddd        xmm1, xmm5
%else
    paddd        xmm0, xmm2, xmm4
    paddd        xmm1, xmm3, xmm5
%endif
    %assign %%i %%i+1
%endrep
%if %1 == 4
    movifnidn      t2, r6mp
%else
    movifnidn      t2, r5mp
%endif
    packusdw     xmm0, xmm1
    mova         [t2], xmm0
    RET
%endmacro

%macro SAD_X_W8_AVX512 2 ; x, h
cglobal pixel_sad_x%1_8x%2, %1+2,%1+3
    kxnorb        k3, k3, k3
    lea           t1, [3*t0]
    kaddb         k1, k3, k3
    kshiftlb      k2, k3, 2
    kshiftlb      k3, k3, 3
%assign %%i 0
%rep %2/4
    movddup       m6, [r0+%%i*64]    ; s0 s0 s1 s1
    movq         xm2,      [r1]
    movq         xm4,      [r1+2*t0]
    vpbroadcastq xm2 {k1}, [r2]
    vpbroadcastq xm4 {k1}, [r2+2*t0]
    vpbroadcastq  m2 {k2}, [r1+t0]
    vpbroadcastq  m4 {k2}, [r1+t1]
    vpbroadcastq  m2 {k3}, [r2+t0]   ; a0 b0 a1 b1
    vpbroadcastq  m4 {k3}, [r2+t1]   ; a2 b2 a3 b3
    movddup       m7, [r0+%%i*64+32] ; s2 s2 s3 s3
    movq         xm3,      [r3]
    movq         xm5,      [r3+2*t0]
%if %1 == 4
    vpbroadcastq xm3 {k1}, [r4]
    vpbroadcastq xm5 {k1}, [r4+2*t0]
%endif
    vpbroadcastq  m3 {k2}, [r3+t0]
    vpbroadcastq  m5 {k2}, [r3+t1]
%if %1 == 4
    vpbroadcastq  m3 {k3}, [r4+t0]   ; c0 d0 c1 d1
    vpbroadcastq  m5 {k3}, [r4+t1]   ; c2 d2 c3 d3
%endif
%if %%i != %2/4-1
%assign %%j 1
%rep %1
    lea       r%+%%j, [r%+%%j+4*t0]
    %assign %%j %%j+1
%endrep
%endif
    psadbw        m2, m6
    psadbw        m4, m7
    psadbw        m3, m6
    psadbw        m5, m7
    ACCUM      paddd, 0, 2, %%i
    ACCUM      paddd, 1, 3, %%i
    paddd         m0, m4
    paddd         m1, m5
    %assign %%i %%i+1
%endrep
%if %1 == 4
    movifnidn     t2, r6mp
%else
    movifnidn     t2, r5mp
%endif
    packusdw      m0, m1
    vextracti128 xm1, m0, 1
    paddd        xm0, xm1
    mova        [t2], xm0
    RET
%endmacro

%macro SAD_X_W16_AVX512 2 ; x, h
cglobal pixel_sad_x%1_16x%2, %1+2,%1+3
    lea           t1, [3*t0]
%assign %%i 0
%rep %2/4
    mova          m6, [r0+%%i*64]  ; s0 s1 s2 s3
    movu         xm2, [r3]
    movu         xm4, [r3+t0]
%if %1 == 4
    vinserti128  ym2, [r4+t0],   1
    vinserti128  ym4, [r4],      1
%endif
    vinserti32x4  m2, [r1+2*t0], 2
    vinserti32x4  m4, [r1+t1],   2
    vinserti32x4  m2, [r2+t1],   3 ; c0 d1 a2 b3
    vinserti32x4  m4, [r2+2*t0], 3 ; c1 d0 a3 b2
    vpermq        m7, m6, q1032    ; s1 s0 s3 s2
    movu         xm3, [r1]
    movu         xm5, [r1+t0]
    vinserti128  ym3, [r2+t0],   1
    vinserti128  ym5, [r2],      1
    vinserti32x4  m3, [r3+2*t0], 2
    vinserti32x4  m5, [r3+t1],   2
%if %1 == 4
    vinserti32x4  m3, [r4+t1],   3 ; a0 b1 c2 d3
    vinserti32x4  m5, [r4+2*t0], 3 ; a1 b0 c3 d2
%endif
%if %%i != %2/4-1
%assign %%j 1
%rep %1
    lea       r%+%%j, [r%+%%j+4*t0]
    %assign %%j %%j+1
%endrep
%endif
    psadbw        m2, m6
    psadbw        m4, m7
    psadbw        m3, m6
    psadbw        m5, m7
    ACCUM      paddd, 0, 2, %%i
    ACCUM      paddd, 1, 3, %%i
    paddd         m0, m4
    paddd         m1, m5
    %assign %%i %%i+1
%endrep
%if %1 == 4
    movifnidn     t2, r6mp
%else
    movifnidn     t2, r5mp
%endif
    mov          t1d, 0x1111
    kmovw         k1, t1d
    vshufi32x4    m0, m0, q1032
    paddd         m0, m1
    punpckhqdq    m1, m0, m0
    paddd         m0, m1
    vpcompressd   m0 {k1}{z}, m0
    mova        [t2], xm0
    RET
%endmacro

; t0 = stride, t1 = tmp/stride3, t2 = scores
%if WIN64
    %define s1 xmm16 ; xmm6 and xmm7 reduces code size, but
    %define s2 xmm17 ; they're callee-saved on win64
    DECLARE_REG_TMP 4, 6, 0
%else
    %define s1 xmm6
    %define s2 xmm7
%if ARCH_X86_64
    DECLARE_REG_TMP 4, 6, 5 ; scores is passed in a register on unix64
%else
    DECLARE_REG_TMP 4, 5, 0
%endif
%endif

INIT_YMM avx512
SAD_X_W4_AVX512  3, 4  ; x3_4x4
SAD_X_W4_AVX512  3, 8  ; x3_4x8
SAD_X_W8_AVX512  3, 4  ; x3_8x4
SAD_X_W8_AVX512  3, 8  ; x3_8x8
SAD_X_W8_AVX512  3, 16 ; x3_8x16
INIT_ZMM avx512
SAD_X_W16_AVX512 3, 8  ; x3_16x8
SAD_X_W16_AVX512 3, 16 ; x3_16x16

DECLARE_REG_TMP 5, 6, 0
INIT_YMM avx512
SAD_X_W4_AVX512  4, 4  ; x4_4x4
SAD_X_W4_AVX512  4, 8  ; x4_4x8
SAD_X_W8_AVX512  4, 4  ; x4_8x4
SAD_X_W8_AVX512  4, 8  ; x4_8x8
SAD_X_W8_AVX512  4, 16 ; x4_8x16
INIT_ZMM avx512
SAD_X_W16_AVX512 4, 8  ; x4_16x8
SAD_X_W16_AVX512 4, 16 ; x4_16x16

;=============================================================================
; SAD cacheline split
;=============================================================================

; Core2 (Conroe) can load unaligned data just as quickly as aligned data...
; unless the unaligned data spans the border between 2 cachelines, in which
; case it's really slow. The exact numbers may differ, but all Intel cpus prior
; to Nehalem have a large penalty for cacheline splits.
; (8-byte alignment exactly half way between two cachelines is ok though.)
; LDDQU was supposed to fix this, but it only works on Pentium 4.
; So in the split case we load aligned data and explicitly perform the
; alignment between registers. Like on archs that have only aligned loads,
; except complicated by the fact that PALIGNR takes only an immediate, not
; a variable alignment.
; It is also possible to hoist the realignment to the macroblock level (keep
; 2 copies of the reference frame, offset by 32 bytes), but the extra memory
; needed for that method makes it often slower.

; sad 16x16 costs on Core2:
; good offsets: 49 cycles (50/64 of all mvs)
; cacheline split: 234 cycles (14/64 of all mvs. ammortized: +40 cycles)
; page split: 3600 cycles (14/4096 of all mvs. ammortized: +11.5 cycles)
; cache or page split with palignr: 57 cycles (ammortized: +2 cycles)

; computed jump assumes this loop is exactly 80 bytes
%macro SAD16_CACHELINE_LOOP_SSE2 1 ; alignment
ALIGN 16
sad_w16_align%1_sse2:
    movdqa  xmm1, [r2+16]
    movdqa  xmm2, [r2+r3+16]
    movdqa  xmm3, [r2]
    movdqa  xmm4, [r2+r3]
    pslldq  xmm1, 16-%1
    pslldq  xmm2, 16-%1
    psrldq  xmm3, %1
    psrldq  xmm4, %1
    por     xmm1, xmm3
    por     xmm2, xmm4
    psadbw  xmm1, [r0]
    psadbw  xmm2, [r0+r1]
    paddw   xmm0, xmm1
    paddw   xmm0, xmm2
    lea     r0,   [r0+2*r1]
    lea     r2,   [r2+2*r3]
    dec     r4
    jg sad_w16_align%1_sse2
    ret
%endmacro

; computed jump assumes this loop is exactly 64 bytes
%macro SAD16_CACHELINE_LOOP_SSSE3 1 ; alignment
ALIGN 16
sad_w16_align%1_ssse3:
    movdqa  xmm1, [r2+16]
    movdqa  xmm2, [r2+r3+16]
    palignr xmm1, [r2], %1
    palignr xmm2, [r2+r3], %1
    psadbw  xmm1, [r0]
    psadbw  xmm2, [r0+r1]
    paddw   xmm0, xmm1
    paddw   xmm0, xmm2
    lea     r0,   [r0+2*r1]
    lea     r2,   [r2+2*r3]
    dec     r4
    jg sad_w16_align%1_ssse3
    ret
%endmacro

%macro SAD16_CACHELINE_FUNC 2 ; cpu, height
cglobal pixel_sad_16x%2_cache64_%1
    mov     eax, r2m
    and     eax, 0x37
    cmp     eax, 0x30
    jle pixel_sad_16x%2_sse2
    PROLOGUE 4,6
    mov     r4d, r2d
    and     r4d, 15
%ifidn %1, ssse3
    shl     r4d, 6  ; code size = 64
%else
    lea     r4, [r4*5]
    shl     r4d, 4  ; code size = 80
%endif
%define sad_w16_addr (sad_w16_align1_%1 + (sad_w16_align1_%1 - sad_w16_align2_%1))
%if ARCH_X86_64
    lea     r5, [sad_w16_addr]
    add     r5, r4
%else
    lea     r5, [sad_w16_addr + r4]
%endif
    and     r2, ~15
    mov     r4d, %2/2
    pxor    xmm0, xmm0
    call    r5
    MOVHL   xmm1, xmm0
    paddw   xmm0, xmm1
    movd    eax,  xmm0
    RET
%endmacro

%macro SAD_CACHELINE_START_MMX2 4 ; width, height, iterations, cacheline
    mov    eax, r2m
    and    eax, 0x17|%1|(%4>>1)
    cmp    eax, 0x10|%1|(%4>>1)
    jle pixel_sad_%1x%2_mmx2
    and    eax, 7
    shl    eax, 3
    movd   mm6, [sw_64]
    movd   mm7, eax
    psubw  mm6, mm7
    PROLOGUE 4,5
    and    r2, ~7
    mov    r4d, %3
    pxor   mm0, mm0
%endmacro

%macro SAD16_CACHELINE_FUNC_MMX2 2 ; height, cacheline
cglobal pixel_sad_16x%1_cache%2_mmx2
    SAD_CACHELINE_START_MMX2 16, %1, %1, %2
.loop:
    movq   mm1, [r2]
    movq   mm2, [r2+8]
    movq   mm3, [r2+16]
    movq   mm4, mm2
    psrlq  mm1, mm7
    psllq  mm2, mm6
    psllq  mm3, mm6
    psrlq  mm4, mm7
    por    mm1, mm2
    por    mm3, mm4
    psadbw mm1, [r0]
    psadbw mm3, [r0+8]
    paddw  mm0, mm1
    paddw  mm0, mm3
    add    r2, r3
    add    r0, r1
    dec    r4
    jg .loop
    movd   eax, mm0
    RET
%endmacro

%macro SAD8_CACHELINE_FUNC_MMX2 2 ; height, cacheline
cglobal pixel_sad_8x%1_cache%2_mmx2
    SAD_CACHELINE_START_MMX2 8, %1, %1/2, %2
.loop:
    movq   mm1, [r2+8]
    movq   mm2, [r2+r3+8]
    movq   mm3, [r2]
    movq   mm4, [r2+r3]
    psllq  mm1, mm6
    psllq  mm2, mm6
    psrlq  mm3, mm7
    psrlq  mm4, mm7
    por    mm1, mm3
    por    mm2, mm4
    psadbw mm1, [r0]
    psadbw mm2, [r0+r1]
    paddw  mm0, mm1
    paddw  mm0, mm2
    lea    r2, [r2+2*r3]
    lea    r0, [r0+2*r1]
    dec    r4
    jg .loop
    movd   eax, mm0
    RET
%endmacro

; sad_x3/x4_cache64: check each mv.
; if they're all within a cacheline, use normal sad_x3/x4.
; otherwise, send them individually to sad_cache64.
%macro CHECK_SPLIT 3 ; pix, width, cacheline
    mov  eax, %1
    and  eax, 0x17|%2|(%3>>1)
    cmp  eax, 0x10|%2|(%3>>1)
    jg .split
%endmacro

%macro SADX3_CACHELINE_FUNC 6 ; width, height, cacheline, normal_ver, split_ver, name
cglobal pixel_sad_x3_%1x%2_cache%3_%6
    CHECK_SPLIT r1m, %1, %3
    CHECK_SPLIT r2m, %1, %3
    CHECK_SPLIT r3m, %1, %3
    jmp pixel_sad_x3_%1x%2_%4
.split:
%if ARCH_X86_64
    PROLOGUE 6,9
    push r3
    push r2
%if WIN64
    movsxd r4, r4d
    sub rsp, 40 ; shadow space and alignment
%endif
    mov  r2, r1
    mov  r1, FENC_STRIDE
    mov  r3, r4
    mov  r7, r0
    mov  r8, r5
    call pixel_sad_%1x%2_cache%3_%5
    mov  [r8], eax
%if WIN64
    mov  r2, [rsp+40+0*8]
%else
    pop  r2
%endif
    mov  r0, r7
    call pixel_sad_%1x%2_cache%3_%5
    mov  [r8+4], eax
%if WIN64
    mov  r2, [rsp+40+1*8]
%else
    pop  r2
%endif
    mov  r0, r7
    call pixel_sad_%1x%2_cache%3_%5
    mov  [r8+8], eax
%if WIN64
    add  rsp, 40+2*8
%endif
    RET
%else
    push edi
    mov  edi, [esp+28]
    push dword [esp+24]
    push dword [esp+16]
    push dword 16
    push dword [esp+20]
    call pixel_sad_%1x%2_cache%3_%5
    mov  ecx, [esp+32]
    mov  [edi], eax
    mov  [esp+8], ecx
    call pixel_sad_%1x%2_cache%3_%5
    mov  ecx, [esp+36]
    mov  [edi+4], eax
    mov  [esp+8], ecx
    call pixel_sad_%1x%2_cache%3_%5
    mov  [edi+8], eax
    add  esp, 16
    pop  edi
    ret
%endif
%endmacro

%macro SADX4_CACHELINE_FUNC 6 ; width, height, cacheline, normal_ver, split_ver, name
cglobal pixel_sad_x4_%1x%2_cache%3_%6
    CHECK_SPLIT r1m, %1, %3
    CHECK_SPLIT r2m, %1, %3
    CHECK_SPLIT r3m, %1, %3
    CHECK_SPLIT r4m, %1, %3
    jmp pixel_sad_x4_%1x%2_%4
.split:
%if ARCH_X86_64
    PROLOGUE 6,9
    mov  r8,  r6mp
    push r4
    push r3
    push r2
%if WIN64
    sub rsp, 32 ; shadow space
%endif
    mov  r2, r1
    mov  r1, FENC_STRIDE
    mov  r3, r5
    mov  r7, r0
    call pixel_sad_%1x%2_cache%3_%5
    mov  [r8], eax
%if WIN64
    mov  r2, [rsp+32+0*8]
%else
    pop  r2
%endif
    mov  r0, r7
    call pixel_sad_%1x%2_cache%3_%5
    mov  [r8+4], eax
%if WIN64
    mov  r2, [rsp+32+1*8]
%else
    pop  r2
%endif
    mov  r0, r7
    call pixel_sad_%1x%2_cache%3_%5
    mov  [r8+8], eax
%if WIN64
    mov  r2, [rsp+32+2*8]
%else
    pop  r2
%endif
    mov  r0, r7
    call pixel_sad_%1x%2_cache%3_%5
    mov  [r8+12], eax
%if WIN64
    add  rsp, 32+3*8
%endif
    RET
%else
    push edi
    mov  edi, [esp+32]
    push dword [esp+28]
    push dword [esp+16]
    push dword 16
    push dword [esp+20]
    call pixel_sad_%1x%2_cache%3_%5
    mov  ecx, [esp+32]
    mov  [edi], eax
    mov  [esp+8], ecx
    call pixel_sad_%1x%2_cache%3_%5
    mov  ecx, [esp+36]
    mov  [edi+4], eax
    mov  [esp+8], ecx
    call pixel_sad_%1x%2_cache%3_%5
    mov  ecx, [esp+40]
    mov  [edi+8], eax
    mov  [esp+8], ecx
    call pixel_sad_%1x%2_cache%3_%5
    mov  [edi+12], eax
    add  esp, 16
    pop  edi
    ret
%endif
%endmacro

%macro SADX34_CACHELINE_FUNC 1+
    SADX3_CACHELINE_FUNC %1
    SADX4_CACHELINE_FUNC %1
%endmacro


; instantiate the aligned sads

INIT_MMX
%if ARCH_X86_64 == 0
SAD16_CACHELINE_FUNC_MMX2  8, 32
SAD16_CACHELINE_FUNC_MMX2 16, 32
SAD8_CACHELINE_FUNC_MMX2   4, 32
SAD8_CACHELINE_FUNC_MMX2   8, 32
SAD8_CACHELINE_FUNC_MMX2  16, 32
SAD16_CACHELINE_FUNC_MMX2  8, 64
SAD16_CACHELINE_FUNC_MMX2 16, 64
%endif ; !ARCH_X86_64
SAD8_CACHELINE_FUNC_MMX2   4, 64
SAD8_CACHELINE_FUNC_MMX2   8, 64
SAD8_CACHELINE_FUNC_MMX2  16, 64

%if ARCH_X86_64 == 0
SADX34_CACHELINE_FUNC 16, 16, 32, mmx2, mmx2, mmx2
SADX34_CACHELINE_FUNC 16,  8, 32, mmx2, mmx2, mmx2
SADX34_CACHELINE_FUNC  8, 16, 32, mmx2, mmx2, mmx2
SADX34_CACHELINE_FUNC  8,  8, 32, mmx2, mmx2, mmx2
SADX34_CACHELINE_FUNC 16, 16, 64, mmx2, mmx2, mmx2
SADX34_CACHELINE_FUNC 16,  8, 64, mmx2, mmx2, mmx2
%endif ; !ARCH_X86_64
SADX34_CACHELINE_FUNC  8, 16, 64, mmx2, mmx2, mmx2
SADX34_CACHELINE_FUNC  8,  8, 64, mmx2, mmx2, mmx2

%if ARCH_X86_64 == 0
SAD16_CACHELINE_FUNC sse2, 8
SAD16_CACHELINE_FUNC sse2, 16
%assign i 1
%rep 15
SAD16_CACHELINE_LOOP_SSE2 i
%assign i i+1
%endrep
SADX34_CACHELINE_FUNC 16, 16, 64, sse2, sse2, sse2
SADX34_CACHELINE_FUNC 16,  8, 64, sse2, sse2, sse2
%endif ; !ARCH_X86_64
SADX34_CACHELINE_FUNC  8, 16, 64, sse2, mmx2, sse2

SAD16_CACHELINE_FUNC ssse3, 8
SAD16_CACHELINE_FUNC ssse3, 16
%assign i 1
%rep 15
SAD16_CACHELINE_LOOP_SSSE3 i
%assign i i+1
%endrep
SADX34_CACHELINE_FUNC 16, 16, 64, sse2, ssse3, ssse3
SADX34_CACHELINE_FUNC 16,  8, 64, sse2, ssse3, ssse3

