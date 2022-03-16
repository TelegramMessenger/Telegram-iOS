;*****************************************************************************
;* quant-a.asm: x86 quantization and level-run
;*****************************************************************************
;* Copyright (C) 2005-2022 x264 project
;*
;* Authors: Loren Merritt <lorenm@u.washington.edu>
;*          Fiona Glaser <fiona@x264.com>
;*          Christian Heine <sennindemokrit@gmx.net>
;*          Oskar Arvidsson <oskar@irock.se>
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

SECTION_RODATA 64

%if HIGH_BIT_DEPTH
decimate_shuf_avx512: dd 0, 4, 8,12, 1, 5, 9,13, 2, 6,10,14, 3, 7,11,15
%else
dequant_shuf_avx512: dw  0, 2, 4, 6, 8,10,12,14,16,18,20,22,24,26,28,30
                     dw 32,34,36,38,40,42,44,46,48,50,52,54,56,58,60,62
%endif

%macro DQM4 3
    dw %1, %2, %1, %2, %2, %3, %2, %3
%endmacro
%macro DQM8 6
    dw %1, %4, %5, %4, %1, %4, %5, %4
    dw %4, %2, %6, %2, %4, %2, %6, %2
    dw %5, %6, %3, %6, %5, %6, %3, %6
    dw %4, %2, %6, %2, %4, %2, %6, %2
%endmacro

dequant8_scale:
    DQM8 20, 18, 32, 19, 25, 24
    DQM8 22, 19, 35, 21, 28, 26
    DQM8 26, 23, 42, 24, 33, 31
    DQM8 28, 25, 45, 26, 35, 33
    DQM8 32, 28, 51, 30, 40, 38
    DQM8 36, 32, 58, 34, 46, 43

dequant4_scale:
    DQM4 10, 13, 16
    DQM4 11, 14, 18
    DQM4 13, 16, 20
    DQM4 14, 18, 23
    DQM4 16, 20, 25
    DQM4 18, 23, 29

decimate_mask_table4:
    db  0,3,2,6,2,5,5,9,1,5,4,8,5,8,8,12,1,4,4,8,4,7,7,11,4,8,7,11,8,11,11,15,1,4
    db  3,7,4,7,7,11,3,7,6,10,7,10,10,14,4,7,7,11,7,10,10,14,7,11,10,14,11,14,14
    db 18,0,4,3,7,3,6,6,10,3,7,6,10,7,10,10,14,3,6,6,10,6,9,9,13,6,10,9,13,10,13
    db 13,17,4,7,6,10,7,10,10,14,6,10,9,13,10,13,13,17,7,10,10,14,10,13,13,17,10
    db 14,13,17,14,17,17,21,0,3,3,7,3,6,6,10,2,6,5,9,6,9,9,13,3,6,6,10,6,9,9,13
    db  6,10,9,13,10,13,13,17,3,6,5,9,6,9,9,13,5,9,8,12,9,12,12,16,6,9,9,13,9,12
    db 12,16,9,13,12,16,13,16,16,20,3,7,6,10,6,9,9,13,6,10,9,13,10,13,13,17,6,9
    db  9,13,9,12,12,16,9,13,12,16,13,16,16,20,7,10,9,13,10,13,13,17,9,13,12,16
    db 13,16,16,20,10,13,13,17,13,16,16,20,13,17,16,20,17,20,20,24

chroma_dc_dct_mask_mmx: dw 0, 0,-1,-1, 0, 0,-1,-1
chroma_dc_dmf_mask_mmx: dw 0, 0,-1,-1, 0,-1,-1, 0
chroma_dc_dct_mask:     dw 1, 1,-1,-1, 1, 1,-1,-1
chroma_dc_dmf_mask:     dw 1, 1,-1,-1, 1,-1,-1, 1

%if HIGH_BIT_DEPTH==0
dct_coef_shuffle:
%macro DCT_COEF_SHUFFLE 8
    %assign y x
    %rep 8
        %rep 7
            %rotate (~(y>>7))&1
            %assign y y<<((~(y>>7))&1)
        %endrep
        db %1*2
        %rotate 1
        %assign y y<<1
    %endrep
%endmacro
%assign x 0
%rep 256
    DCT_COEF_SHUFFLE 7, 6, 5, 4, 3, 2, 1, 0
%assign x x+1
%endrep
%endif

SECTION .text

cextern pb_1
cextern pw_1
cextern pw_2
cextern pw_256
cextern pd_1
cextern pb_01
cextern pd_1024
cextern deinterleave_shufd
cextern popcnt_table

%macro QUANT_DC_START 2
    movd      xm%1, r1m     ; mf
    movd      xm%2, r2m     ; bias
%if cpuflag(avx2)
    vpbroadcastdct m%1, xm%1
    vpbroadcastdct m%2, xm%2
%elif HIGH_BIT_DEPTH
    SPLATD     m%1, m%1
    SPLATD     m%2, m%2
%elif cpuflag(sse4) ; ssse3, but not faster on conroe
    mova       m5, [pb_01]
    pshufb     m%1, m5
    pshufb     m%2, m5
%else
    SPLATW     m%1, m%1
    SPLATW     m%2, m%2
%endif
%endmacro

%macro QUANT_END 0
    xor      eax, eax
%if cpuflag(sse4)
    ptest     m5, m5
%else ; !sse4
%if ARCH_X86_64
%if mmsize == 16
    packsswb  m5, m5
%endif
    movq     rcx, m5
    test     rcx, rcx
%else
%if mmsize == 16
    pxor      m4, m4
    pcmpeqb   m5, m4
    pmovmskb ecx, m5
    cmp      ecx, (1<<mmsize)-1
%else
    packsswb  m5, m5
    movd     ecx, m5
    test     ecx, ecx
%endif
%endif
%endif ; cpuflag
    setne     al
%endmacro

%if HIGH_BIT_DEPTH
%macro QUANT_ONE_DC 4
%if cpuflag(sse4)
    mova        m0, [%1]
    ABSD        m1, m0
    paddd       m1, %3
    pmulld      m1, %2
    psrld       m1, 16
%else ; !sse4
    mova        m0, [%1]
    ABSD        m1, m0
    paddd       m1, %3
    mova        m2, m1
    psrlq       m2, 32
    pmuludq     m1, %2
    pmuludq     m2, %2
    psllq       m2, 32
    paddd       m1, m2
    psrld       m1, 16
%endif ; cpuflag
    PSIGND      m1, m0
    mova      [%1], m1
    ACCUM     por, 5, 1, %4
%endmacro

%macro QUANT_TWO_DC 4
%if cpuflag(sse4)
    mova        m0, [%1       ]
    mova        m1, [%1+mmsize]
    ABSD        m2, m0
    ABSD        m3, m1
    paddd       m2, %3
    paddd       m3, %3
    pmulld      m2, %2
    pmulld      m3, %2
    psrld       m2, 16
    psrld       m3, 16
    PSIGND      m2, m0
    PSIGND      m3, m1
    mova [%1       ], m2
    mova [%1+mmsize], m3
    ACCUM      por, 5, 2, %4
    por         m5, m3
%else ; !sse4
    QUANT_ONE_DC %1, %2, %3, %4
    QUANT_ONE_DC %1+mmsize, %2, %3, %4+mmsize
%endif ; cpuflag
%endmacro

%macro QUANT_ONE_AC_MMX 5
    mova        m0, [%1]
    mova        m2, [%2]
    ABSD        m1, m0
    mova        m4, m2
    paddd       m1, [%3]
    mova        m3, m1
    psrlq       m4, 32
    psrlq       m3, 32
    pmuludq     m1, m2
    pmuludq     m3, m4
    psllq       m3, 32
    paddd       m1, m3
    psrld       m1, 16
    PSIGND      m1, m0
    mova      [%1], m1
    ACCUM      por, %5, 1, %4
%endmacro

%macro QUANT_TWO_AC 5
%if cpuflag(sse4)
    mova        m0, [%1       ]
    mova        m1, [%1+mmsize]
    ABSD        m2, m0
    ABSD        m3, m1
    paddd       m2, [%3       ]
    paddd       m3, [%3+mmsize]
    pmulld      m2, [%2       ]
    pmulld      m3, [%2+mmsize]
    psrld       m2, 16
    psrld       m3, 16
    PSIGND      m2, m0
    PSIGND      m3, m1
    mova [%1       ], m2
    mova [%1+mmsize], m3
    ACCUM      por, %5, 2, %4
    por        m%5, m3
%else ; !sse4
    QUANT_ONE_AC_MMX %1, %2, %3, %4, %5
    QUANT_ONE_AC_MMX %1+mmsize, %2+mmsize, %3+mmsize, 1, %5
%endif ; cpuflag
%endmacro

;-----------------------------------------------------------------------------
; int quant_2x2( int32_t dct[M*N], int mf, int bias )
;-----------------------------------------------------------------------------
%macro QUANT_DC 2
cglobal quant_%1x%2_dc, 3,3,8
    QUANT_DC_START 6,7
%if %1*%2 <= mmsize/4
    QUANT_ONE_DC r0, m6, m7, 0
%else
%assign x 0
%rep %1*%2/(mmsize/2)
    QUANT_TWO_DC r0+x, m6, m7, x
%assign x x+mmsize*2
%endrep
%endif
    QUANT_END
    RET
%endmacro

;-----------------------------------------------------------------------------
; int quant_MxN( int32_t dct[M*N], uint32_t mf[M*N], uint32_t bias[M*N] )
;-----------------------------------------------------------------------------
%macro QUANT_AC 2
cglobal quant_%1x%2, 3,3,8
%assign x 0
%rep %1*%2/(mmsize/2)
    QUANT_TWO_AC r0+x, r1+x, r2+x, x, 5
%assign x x+mmsize*2
%endrep
    QUANT_END
    RET
%endmacro

%macro QUANT_4x4 2
    QUANT_TWO_AC r0+%1+mmsize*0, r1+mmsize*0, r2+mmsize*0, 0, %2
    QUANT_TWO_AC r0+%1+mmsize*2, r1+mmsize*2, r2+mmsize*2, 1, %2
%endmacro

%macro QUANT_4x4x4 0
cglobal quant_4x4x4, 3,3,8
    QUANT_4x4  0, 5
    QUANT_4x4 64, 6
    add       r0, 128
    packssdw  m5, m6
    QUANT_4x4  0, 6
    QUANT_4x4 64, 7
    packssdw  m6, m7
    packssdw  m5, m6  ; AAAA BBBB CCCC DDDD
    pxor      m4, m4
    pcmpeqd   m5, m4
    movmskps eax, m5
    xor      eax, 0xf
    RET
%endmacro

INIT_XMM sse2
QUANT_DC 2, 2
QUANT_DC 4, 4
QUANT_AC 4, 4
QUANT_AC 8, 8
QUANT_4x4x4

INIT_XMM ssse3
QUANT_DC 2, 2
QUANT_DC 4, 4
QUANT_AC 4, 4
QUANT_AC 8, 8
QUANT_4x4x4

INIT_XMM sse4
QUANT_DC 2, 2
QUANT_DC 4, 4
QUANT_AC 4, 4
QUANT_AC 8, 8
QUANT_4x4x4

INIT_YMM avx2
QUANT_DC 4, 4
QUANT_AC 4, 4
QUANT_AC 8, 8

INIT_YMM avx2
cglobal quant_4x4x4, 3,3,6
    QUANT_TWO_AC r0,    r1, r2, 0, 4
    QUANT_TWO_AC r0+64, r1, r2, 0, 5
    add       r0, 128
    packssdw  m4, m5
    QUANT_TWO_AC r0,    r1, r2, 0, 5
    QUANT_TWO_AC r0+64, r1, r2, 0, 1
    packssdw  m5, m1
    packssdw  m4, m5
    pxor      m3, m3
    pcmpeqd   m4, m3
    movmskps eax, m4
    mov      edx, eax
    shr      eax, 4
    and      eax, edx
    xor      eax, 0xf
    RET

%endif ; HIGH_BIT_DEPTH

%if HIGH_BIT_DEPTH == 0
%macro QUANT_ONE 5
;;; %1      (m64)       dct[y][x]
;;; %2      (m64/mmx)   mf[y][x] or mf[0][0] (as uint16_t)
;;; %3      (m64/mmx)   bias[y][x] or bias[0][0] (as uint16_t)
    mova       m1, %1   ; load dct coeffs
    ABSW       m0, m1, sign
    paddusw    m0, %3   ; round
    pmulhuw    m0, %2   ; divide
    PSIGNW     m0, m1   ; restore sign
    mova       %1, m0   ; store
    ACCUM     por, %5, 0, %4
%endmacro

%macro QUANT_TWO 8
    mova       m1, %1
    mova       m3, %2
    ABSW       m0, m1, sign
    ABSW       m2, m3, sign
    paddusw    m0, %5
    paddusw    m2, %6
    pmulhuw    m0, %3
    pmulhuw    m2, %4
    PSIGNW     m0, m1
    PSIGNW     m2, m3
    mova       %1, m0
    mova       %2, m2
    ACCUM     por, %8, 0, %7
    ACCUM     por, %8, 2, %7+mmsize
%endmacro

;-----------------------------------------------------------------------------
; void quant_4x4_dc( int16_t dct[16], int mf, int bias )
;-----------------------------------------------------------------------------
%macro QUANT_DC 2-3 0
cglobal %1, 1,1,%3
%if %2==1
    QUANT_DC_START 2,3
    QUANT_ONE [r0], m2, m3, 0, 5
%else
    QUANT_DC_START 4,6
%assign x 0
%rep %2/2
    QUANT_TWO [r0+x], [r0+x+mmsize], m4, m4, m6, m6, x, 5
%assign x x+mmsize*2
%endrep
%endif
    QUANT_END
    RET
%endmacro

;-----------------------------------------------------------------------------
; int quant_4x4( int16_t dct[16], uint16_t mf[16], uint16_t bias[16] )
;-----------------------------------------------------------------------------
%macro QUANT_AC 2
cglobal %1, 3,3
%if %2==1
    QUANT_ONE [r0], [r1], [r2], 0, 5
%else
%assign x 0
%rep %2/2
    QUANT_TWO [r0+x], [r0+x+mmsize], [r1+x], [r1+x+mmsize], [r2+x], [r2+x+mmsize], x, 5
%assign x x+mmsize*2
%endrep
%endif
    QUANT_END
    RET
%endmacro

%macro QUANT_4x4 2
%if UNIX64
    QUANT_TWO [r0+%1+mmsize*0], [r0+%1+mmsize*1], m8, m9, m10, m11, mmsize*0, %2
%else
    QUANT_TWO [r0+%1+mmsize*0], [r0+%1+mmsize*1], [r1+mmsize*0], [r1+mmsize*1], [r2+mmsize*0], [r2+mmsize*1], mmsize*0, %2
%if mmsize==8
    QUANT_TWO [r0+%1+mmsize*2], [r0+%1+mmsize*3], [r1+mmsize*2], [r1+mmsize*3], [r2+mmsize*2], [r2+mmsize*3], mmsize*2, %2
%endif
%endif
%endmacro

%macro QUANT_4x4x4 0
cglobal quant_4x4x4, 3,3,7
%if UNIX64
    mova      m8, [r1+mmsize*0]
    mova      m9, [r1+mmsize*1]
    mova     m10, [r2+mmsize*0]
    mova     m11, [r2+mmsize*1]
%endif
    QUANT_4x4  0, 4
    QUANT_4x4 32, 5
    packssdw  m4, m5
    QUANT_4x4 64, 5
    QUANT_4x4 96, 6
    packssdw  m5, m6
    packssdw  m4, m5  ; AAAA BBBB CCCC DDDD
    pxor      m3, m3
    pcmpeqd   m4, m3
    movmskps eax, m4
    xor      eax, 0xf
    RET
%endmacro

INIT_MMX mmx2
QUANT_DC quant_2x2_dc, 1
%if ARCH_X86_64 == 0 ; not needed because sse2 is faster
QUANT_DC quant_4x4_dc, 4
INIT_MMX mmx2
QUANT_AC quant_4x4, 4
QUANT_AC quant_8x8, 16
%endif

INIT_XMM sse2
QUANT_DC quant_4x4_dc, 2, 7
QUANT_AC quant_4x4, 2
QUANT_AC quant_8x8, 8
QUANT_4x4x4

INIT_XMM ssse3
QUANT_DC quant_4x4_dc, 2, 7
QUANT_AC quant_4x4, 2
QUANT_AC quant_8x8, 8
QUANT_4x4x4

INIT_MMX ssse3
QUANT_DC quant_2x2_dc, 1

INIT_XMM sse4
;Not faster on Conroe, so only used in SSE4 versions
QUANT_DC quant_4x4_dc, 2, 7
QUANT_AC quant_4x4, 2
QUANT_AC quant_8x8, 8

INIT_YMM avx2
QUANT_AC quant_4x4, 1
QUANT_AC quant_8x8, 4
QUANT_DC quant_4x4_dc, 1, 6

INIT_YMM avx2
cglobal quant_4x4x4, 3,3,6
    mova      m2, [r1]
    mova      m3, [r2]
    QUANT_ONE [r0+ 0], m2, m3, 0, 4
    QUANT_ONE [r0+32], m2, m3, 0, 5
    packssdw  m4, m5
    QUANT_ONE [r0+64], m2, m3, 0, 5
    QUANT_ONE [r0+96], m2, m3, 0, 1
    packssdw  m5, m1
    packssdw  m4, m5
    pxor      m3, m3
    pcmpeqd   m4, m3
    movmskps eax, m4
    mov      edx, eax
    shr      eax, 4
    and      eax, edx
    xor      eax, 0xf
    RET
%endif ; !HIGH_BIT_DEPTH



;=============================================================================
; dequant
;=============================================================================

%macro DEQUANT16_L 4
;;; %1      dct[y][x]
;;; %2,%3   dequant_mf[i_mf][y][x]
;;; m2      i_qbits
%if HIGH_BIT_DEPTH
    mova     m0, %1
    mova     m1, %4
    pmaddwd  m0, %2
    pmaddwd  m1, %3
    pslld    m0, xm2
    pslld    m1, xm2
    mova     %1, m0
    mova     %4, m1
%else
    mova     m0, %2
    packssdw m0, %3
%if mmsize==32
    vpermq   m0, m0, q3120
%endif
    pmullw   m0, %1
    psllw    m0, xm2
    mova     %1, m0
%endif
%endmacro

%macro DEQUANT32_R 4
;;; %1      dct[y][x]
;;; %2,%3   dequant_mf[i_mf][y][x]
;;; m2      -i_qbits
;;; m3      f
;;; m4      0
%if HIGH_BIT_DEPTH
    mova      m0, %1
    mova      m1, %4
    pmadcswd  m0, m0, %2, m3
    pmadcswd  m1, m1, %3, m3
    psrad     m0, xm2
    psrad     m1, xm2
    mova      %1, m0
    mova      %4, m1
%else
%if mmsize == 32
    pmovzxwd  m0, %1
    pmovzxwd  m1, %4
%else
    mova      m0, %1
    punpckhwd m1, m0, m4
    punpcklwd m0, m4
%endif
    pmadcswd  m0, m0, %2, m3
    pmadcswd  m1, m1, %3, m3
    psrad     m0, xm2
    psrad     m1, xm2
    packssdw  m0, m1
%if mmsize == 32
    vpermq    m0, m0, q3120
%endif
    mova      %1, m0
%endif
%endmacro

%macro DEQUANT_LOOP 3
%if 8*(%2-2*%3) > 0
    mov t0d, 8*(%2-2*%3)
%%loop:
    %1 [r0+(t0     )*SIZEOF_PIXEL], [r1+t0*2      ], [r1+t0*2+ 8*%3], [r0+(t0+ 4*%3)*SIZEOF_PIXEL]
    %1 [r0+(t0+8*%3)*SIZEOF_PIXEL], [r1+t0*2+16*%3], [r1+t0*2+24*%3], [r0+(t0+12*%3)*SIZEOF_PIXEL]
    sub t0d, 16*%3
    jge %%loop
    RET
%else
%if mmsize < 32
    %1 [r0+(8*%3)*SIZEOF_PIXEL], [r1+16*%3], [r1+24*%3], [r0+(12*%3)*SIZEOF_PIXEL]
%endif
    %1 [r0+(0   )*SIZEOF_PIXEL], [r1+0    ], [r1+ 8*%3], [r0+( 4*%3)*SIZEOF_PIXEL]
    RET
%endif
%endmacro

%macro DEQUANT16_FLAT 2-5
    mova   m0, %1
    psllw  m0, m4
%assign i %0-2
%rep %0-1
%if i
    mova   m %+ i, [r0+%2]
    pmullw m %+ i, m0
%else
    pmullw m0, [r0+%2]
%endif
    mova   [r0+%2], m %+ i
    %assign i i-1
    %rotate 1
%endrep
%endmacro

%if ARCH_X86_64
    DECLARE_REG_TMP 6,3,2
%else
    DECLARE_REG_TMP 2,0,1
%endif

%macro DEQUANT_START 2
    movifnidn t2d, r2m
    imul t0d, t2d, 0x2b
    shr  t0d, 8     ; i_qbits = i_qp / 6
    lea  t1d, [t0*5]
    sub  t2d, t0d
    sub  t2d, t1d   ; i_mf = i_qp % 6
    shl  t2d, %1
%if ARCH_X86_64
    add  r1, t2     ; dequant_mf[i_mf]
%else
    add  r1, r1mp   ; dequant_mf[i_mf]
    mov  r0, r0mp   ; dct
%endif
    sub  t0d, %2
    jl   .rshift32  ; negative qbits => rightshift
%endmacro

;-----------------------------------------------------------------------------
; void dequant_4x4( dctcoef dct[4][4], int dequant_mf[6][4][4], int i_qp )
;-----------------------------------------------------------------------------
%macro DEQUANT 3
cglobal dequant_%1x%1, 0,3,6
.skip_prologue:
    DEQUANT_START %2+2, %2

.lshift:
    movd xm2, t0d
    DEQUANT_LOOP DEQUANT16_L, %1*%1/4, %3

.rshift32:
    neg   t0d
    mova  m3, [pd_1]
    movd xm2, t0d
    pslld m3, xm2
    pxor  m4, m4
    psrld m3, 1
    DEQUANT_LOOP DEQUANT32_R, %1*%1/4, %3

%if HIGH_BIT_DEPTH == 0 && (notcpuflag(avx) || mmsize == 32)
cglobal dequant_%1x%1_flat16, 0,3
    movifnidn t2d, r2m
%if %1 == 8
    cmp  t2d, 12
    jl dequant_%1x%1 %+ SUFFIX %+ .skip_prologue
    sub  t2d, 12
%endif
    imul t0d, t2d, 0x2b
    shr  t0d, 8     ; i_qbits = i_qp / 6
    lea  t1d, [t0*5]
    sub  t2d, t0d
    sub  t2d, t1d   ; i_mf = i_qp % 6
    shl  t2d, %2
%if ARCH_X86_64
    lea  r1, [dequant%1_scale]
    add  r1, t2
%else
    lea  r1, [dequant%1_scale + t2]
%endif
    movifnidn r0, r0mp
    movd xm4, t0d
%if %1 == 4
%if mmsize == 8
    DEQUANT16_FLAT [r1], 0, 16
    DEQUANT16_FLAT [r1+8], 8, 24
%elif mmsize == 16
    DEQUANT16_FLAT [r1], 0, 16
%else
    vbroadcasti128 m0, [r1]
    psllw  m0, xm4
    pmullw m0, [r0]
    mova [r0], m0
%endif
%elif mmsize == 8
    DEQUANT16_FLAT [r1], 0, 8, 64, 72
    DEQUANT16_FLAT [r1+16], 16, 24, 48, 56
    DEQUANT16_FLAT [r1+16], 80, 88, 112, 120
    DEQUANT16_FLAT [r1+32], 32, 40, 96, 104
%elif mmsize == 16
    DEQUANT16_FLAT [r1], 0, 64
    DEQUANT16_FLAT [r1+16], 16, 48, 80, 112
    DEQUANT16_FLAT [r1+32], 32, 96
%else
    mova   m1, [r1+ 0]
    mova   m2, [r1+32]
    psllw  m1, xm4
    psllw  m2, xm4
    pmullw m0, m1, [r0+ 0]
    pmullw m3, m2, [r0+32]
    pmullw m4, m1, [r0+64]
    pmullw m5, m2, [r0+96]
    mova [r0+ 0], m0
    mova [r0+32], m3
    mova [r0+64], m4
    mova [r0+96], m5
%endif
    RET
%endif ; !HIGH_BIT_DEPTH && !AVX
%endmacro ; DEQUANT

%if HIGH_BIT_DEPTH
INIT_XMM sse2
DEQUANT 4, 4, 2
DEQUANT 8, 6, 2
INIT_XMM xop
DEQUANT 4, 4, 2
DEQUANT 8, 6, 2
INIT_YMM avx2
DEQUANT 4, 4, 4
DEQUANT 8, 6, 4
%else
%if ARCH_X86_64 == 0
INIT_MMX mmx
DEQUANT 4, 4, 1
DEQUANT 8, 6, 1
%endif
INIT_XMM sse2
DEQUANT 4, 4, 2
DEQUANT 8, 6, 2
INIT_XMM avx
DEQUANT 4, 4, 2
DEQUANT 8, 6, 2
INIT_XMM xop
DEQUANT 4, 4, 2
DEQUANT 8, 6, 2
INIT_YMM avx2
DEQUANT 4, 4, 4
DEQUANT 8, 6, 4
%endif

%macro DEQUANT_START_AVX512 1-2 0 ; shift, flat
%if %2 == 0
    movifnidn t2d, r2m
%endif
    imul t0d, t2d, 0x2b
    shr  t0d, 8     ; i_qbits = i_qp / 6
    lea  t1d, [t0*5]
    sub  t2d, t0d
    sub  t2d, t1d   ; i_mf = i_qp % 6
    shl  t2d, %1
%if %2
%if ARCH_X86_64
%define dmf r1+t2
    lea   r1, [dequant8_scale]
%else
%define dmf t2+dequant8_scale
%endif
%elif ARCH_X86_64
%define dmf r1+t2
%else
%define dmf r1
    add  r1, r1mp   ; dequant_mf[i_mf]
%endif
    movifnidn r0, r0mp
%endmacro

INIT_ZMM avx512
cglobal dequant_4x4, 0,3
    DEQUANT_START_AVX512 6
    mova          m0, [dmf]
%if HIGH_BIT_DEPTH
    pmaddwd       m0, [r0]
%endif
    sub          t0d, 4
    jl .rshift
%if HIGH_BIT_DEPTH
    vpbroadcastd  m1, t0d
    vpsllvd       m0, m1
    mova        [r0], m0
%else
    vpbroadcastw ym1, t0d
    vpmovsdw     ym0, m0
    pmullw       ym0, [r0]
    vpsllvw      ym0, ym1
    mova        [r0], ym0
%endif
    RET
.rshift:
%if HIGH_BIT_DEPTH == 0
    pmovzxwd      m1, [r0]
    pmaddwd       m0, m1
%endif
    mov          r1d, 1<<31
    shrx         r1d, r1d, t0d ; 1 << (-i_qbits-1)
    neg          t0d
    vpbroadcastd  m1, r1d
    vpbroadcastd  m2, t0d
    paddd         m0, m1
    vpsravd       m0, m2
%if HIGH_BIT_DEPTH
    mova        [r0], m0
%else
    vpmovsdw    [r0], m0
%endif
    RET

cglobal dequant_8x8, 0,3
    DEQUANT_START_AVX512 8
    mova          m0, [dmf+0*64]
    mova          m1, [dmf+1*64]
    mova          m2, [dmf+2*64]
    mova          m3, [dmf+3*64]
%if HIGH_BIT_DEPTH
    pmaddwd       m0, [r0+0*64]
    pmaddwd       m1, [r0+1*64]
    pmaddwd       m2, [r0+2*64]
    pmaddwd       m3, [r0+3*64]
%else
    mova          m6, [dequant_shuf_avx512]
%endif
    sub          t0d, 6
    jl .rshift
%if HIGH_BIT_DEPTH
    vpbroadcastd  m4, t0d
    vpsllvd       m0, m4
    vpsllvd       m1, m4
    vpsllvd       m2, m4
    vpsllvd       m3, m4
    jmp .end
.rshift:
%else
    vpbroadcastw  m4, t0d
    vpermt2w      m0, m6, m1
    vpermt2w      m2, m6, m3
    pmullw        m0, [r0]
    pmullw        m2, [r0+64]
    vpsllvw       m0, m4
    vpsllvw       m2, m4
    mova        [r0], m0
    mova     [r0+64], m2
    RET
.rshift:
    pmovzxwd      m4, [r0+0*32]
    pmovzxwd      m5, [r0+1*32]
    pmaddwd       m0, m4
    pmaddwd       m1, m5
    pmovzxwd      m4, [r0+2*32]
    pmovzxwd      m5, [r0+3*32]
    pmaddwd       m2, m4
    pmaddwd       m3, m5
%endif
    mov          r1d, 1<<31
    shrx         r1d, r1d, t0d ; 1 << (-i_qbits-1)
    neg          t0d
    vpbroadcastd  m4, r1d
    vpbroadcastd  m5, t0d
    paddd         m0, m4
    paddd         m1, m4
    vpsravd       m0, m5
    vpsravd       m1, m5
    paddd         m2, m4
    paddd         m3, m4
    vpsravd       m2, m5
    vpsravd       m3, m5
%if HIGH_BIT_DEPTH
.end:
    mova   [r0+0*64], m0
    mova   [r0+1*64], m1
    mova   [r0+2*64], m2
    mova   [r0+3*64], m3
%else
    vpermt2w      m0, m6, m1
    vpermt2w      m2, m6, m3
    mova        [r0], m0
    mova     [r0+64], m2
%endif
    RET

%if HIGH_BIT_DEPTH == 0
cglobal dequant_8x8_flat16, 0,3
    movifnidn    t2d, r2m
    cmp          t2d, 12
    jl dequant_8x8_avx512
    sub          t2d, 12
    DEQUANT_START_AVX512 6, 1
    vpbroadcastw  m0, t0d
    mova          m1, [dmf]
    vpsllvw       m1, m0
    pmullw        m0, m1, [r0]
    pmullw        m1, [r0+64]
    mova        [r0], m0
    mova     [r0+64], m1
    RET
%endif

%undef dmf

%macro DEQUANT_DC 2
cglobal dequant_4x4dc, 0,3,6
    DEQUANT_START 6, 6

.lshift:
%if cpuflag(avx2)
    vpbroadcastdct m3, [r1]
%else
    movd    xm3, [r1]
    SPLAT%1  m3, xm3
%endif
    movd    xm2, t0d
    pslld    m3, xm2
%assign %%x 0
%rep SIZEOF_PIXEL*32/mmsize
    %2       m0, m3, [r0+%%x]
    mova     [r0+%%x], m0
%assign %%x %%x+mmsize
%endrep
    RET

.rshift32:
    neg      t0d
%if cpuflag(avx2)
    vpbroadcastdct m2, [r1]
%else
    movd     xm2, [r1]
%endif
    mova      m5, [p%1_1]
    movd     xm3, t0d
    pslld     m4, m5, xm3
    psrld     m4, 1
%if HIGH_BIT_DEPTH
%if notcpuflag(avx2)
    pshufd    m2, m2, 0
%endif
%assign %%x 0
%rep SIZEOF_PIXEL*32/mmsize
    pmadcswd  m0, m2, [r0+%%x], m4
    psrad     m0, xm3
    mova      [r0+%%x], m0
%assign %%x %%x+mmsize
%endrep

%else ; !HIGH_BIT_DEPTH
%if notcpuflag(avx2)
    PSHUFLW   m2, m2, 0
%endif
    punpcklwd m2, m4
%assign %%x 0
%rep SIZEOF_PIXEL*32/mmsize
    mova      m0, [r0+%%x]
    punpckhwd m1, m0, m5
    punpcklwd m0, m5
    pmaddwd   m0, m2
    pmaddwd   m1, m2
    psrad     m0, xm3
    psrad     m1, xm3
    packssdw  m0, m1
    mova      [r0+%%x], m0
%assign %%x %%x+mmsize
%endrep
%endif ; !HIGH_BIT_DEPTH
    RET
%endmacro

%if HIGH_BIT_DEPTH
INIT_XMM sse2
DEQUANT_DC d, pmaddwd
INIT_XMM xop
DEQUANT_DC d, pmaddwd
INIT_YMM avx2
DEQUANT_DC d, pmaddwd
%else
%if ARCH_X86_64 == 0
INIT_MMX mmx2
DEQUANT_DC w, pmullw
%endif
INIT_XMM sse2
DEQUANT_DC w, pmullw
INIT_XMM avx
DEQUANT_DC w, pmullw
INIT_YMM avx2
DEQUANT_DC w, pmullw
%endif

%macro PEXTRW 4
    %if cpuflag(sse4)
        pextrw %1, %2, %3
    %else
        ; pextrw with a memory destination requires SSE4.1, go through a GPR as a fallback
        %if %3
            pextrw %4d, %2, %3
        %else
            movd %4d, %2
        %endif
        mov %1, %4w
    %endif
%endmacro

;-----------------------------------------------------------------------------
; void idct_dequant_2x4_dc( dctcoef dct[8], dctcoef dct4x4[8][16], int dequant_mf[6][16], int i_qp )
; void idct_dequant_2x4_dconly( dctcoef dct[8], int dequant_mf[6][16], int i_qp )
;-----------------------------------------------------------------------------

%macro DEQUANT_2x4_DC 1
%ifidn %1, dconly
    DECLARE_REG_TMP 6,3,2
    %define %%args dct, dmf, qp
%else
    DECLARE_REG_TMP 6,4,3
    %define %%args dct, dct4x4, dmf, qp
%endif

%if ARCH_X86_64 == 0
    DECLARE_REG_TMP 2,0,1
%endif

cglobal idct_dequant_2x4_%1, 0,3,5, %%args
    movifnidn  t2d, qpm
    imul       t0d, t2d, 0x2b
    shr        t0d, 8         ; qp / 6
    lea        t1d, [t0*5]
    sub        t2d, t0d
    sub        t2d, t1d       ; qp % 6
    shl        t2d, 6         ; 16 * sizeof(int)
%if ARCH_X86_64
    imul       t2d, [dmfq+t2], -0xffff ; (-dmf) << 16 | dmf
%else
    mov       dctq, dctmp
    add         t2, dmfmp
    imul       t2d, [t2], -0xffff
%endif
%if HIGH_BIT_DEPTH
    mova        m0, [dctq]
    mova        m1, [dctq+16]
    SUMSUB_BA    d, 1, 0, 2   ; 16-bit intermediate precision is enough for the first two sumsub steps,
    packssdw    m1, m0        ; and by packing to words we can use pmaddwd instead of pmulld later.
%else
    movq        m0, [dctq]
    movq        m1, [dctq+8]
    SUMSUB_BA    w, 1, 0, 2
    punpcklqdq  m1, m0        ; a0 a1 a2 a3 a4 a5 a6 a7
%endif
    pshufd      m0, m1, q2301 ; a2 a3 a0 a1 a6 a7 a4 a5
    movd        m3, t2d
    pshuflw     m3, m3, q1000 ; +  +  +  -
    SUMSUB_BA    w, 0, 1, 2
    punpcklqdq  m3, m3        ; +  +  +  -  +  +  +  -
    pshufd      m1, m1, q0022
    sub        t0d, 6
    jl .rshift
    movd        m2, t0d
    psllw       m3, m2
    pmaddwd     m0, m3
    pmaddwd     m1, m3
    jmp .end
.rshift:
    neg        t0d
    movd        m2, t0d
    pcmpeqd     m4, m4
    pmaddwd     m0, m3
    pmaddwd     m1, m3
    pslld       m4, m2
    psrad       m4, 1
    psubd       m0, m4 ; + 1 << (qp/6-1)
    psubd       m1, m4
    psrad       m0, m2
    psrad       m1, m2
.end:
%ifidn %1, dconly
%if HIGH_BIT_DEPTH
    mova    [dctq], m0
    mova [dctq+16], m1
%else
    packssdw    m0, m1
    mova    [dctq], m0
%endif
%else
    movifnidn dct4x4q, dct4x4mp
%if HIGH_BIT_DEPTH
    movd   [dct4x4q+0*64], m0
%if cpuflag(sse4)
    pextrd [dct4x4q+1*64], m0, 1
    add    dct4x4q, 4*64
    pextrd [dct4x4q-2*64], m0, 2
    pextrd [dct4x4q-1*64], m0, 3
    movd   [dct4x4q+0*64], m1
    pextrd [dct4x4q+1*64], m1, 1
    pextrd [dct4x4q+2*64], m1, 2
    pextrd [dct4x4q+3*64], m1, 3
%else
    MOVHL       m2, m0
    psrlq       m0, 32
    movd   [dct4x4q+1*64], m0
    add    dct4x4q, 4*64
    movd   [dct4x4q-2*64], m2
    psrlq       m2, 32
    movd   [dct4x4q-1*64], m2
    movd   [dct4x4q+0*64], m1
    MOVHL       m2, m1
    psrlq       m1, 32
    movd   [dct4x4q+1*64], m1
    movd   [dct4x4q+2*64], m2
    psrlq       m2, 32
    movd   [dct4x4q+3*64], m2
%endif
%else
    PEXTRW [dct4x4q+0*32], m0, 0, eax
    PEXTRW [dct4x4q+1*32], m0, 2, eax
    PEXTRW [dct4x4q+2*32], m0, 4, eax
    PEXTRW [dct4x4q+3*32], m0, 6, eax
    add    dct4x4q, 4*32
    PEXTRW [dct4x4q+0*32], m1, 0, eax
    PEXTRW [dct4x4q+1*32], m1, 2, eax
    PEXTRW [dct4x4q+2*32], m1, 4, eax
    PEXTRW [dct4x4q+3*32], m1, 6, eax
%endif
%endif
    RET
%endmacro

; sse4 reduces code size compared to sse2 but isn't any faster, so just go with sse2+avx
INIT_XMM sse2
DEQUANT_2x4_DC dc
DEQUANT_2x4_DC dconly
INIT_XMM avx
DEQUANT_2x4_DC dc
DEQUANT_2x4_DC dconly

; t4 is eax for return value.
%if ARCH_X86_64
    DECLARE_REG_TMP 0,1,2,3,6,4  ; Identical for both Windows and *NIX
%else
    DECLARE_REG_TMP 4,1,2,3,0,5
%endif

;-----------------------------------------------------------------------------
; x264_optimize_chroma_2x2_dc( dctcoef dct[4], int dequant_mf )
;-----------------------------------------------------------------------------

%macro OPTIMIZE_CHROMA_2x2_DC 0
cglobal optimize_chroma_2x2_dc, 0,6-cpuflag(sse4),7
    movifnidn t0, r0mp
    movd      m2, r1m
    movq      m1, [t0]
%if cpuflag(sse4)
    pcmpeqb   m4, m4
    pslld     m4, 11
%else
    pxor      m4, m4
%endif
%if cpuflag(ssse3)
    mova      m3, [chroma_dc_dct_mask]
    mova      m5, [chroma_dc_dmf_mask]
%else
    mova      m3, [chroma_dc_dct_mask_mmx]
    mova      m5, [chroma_dc_dmf_mask_mmx]
%endif
    pshuflw   m2, m2, 0
    pshufd    m0, m1, q0101      ;  1  0  3  2  1  0  3  2
    punpcklqdq m2, m2
    punpcklqdq m1, m1            ;  3  2  1  0  3  2  1  0
    mova      m6, [pd_1024]      ; 32<<5, elements are shifted 5 bits to the left
    PSIGNW    m0, m3             ; -1 -0  3  2 -1 -0  3  2
    PSIGNW    m2, m5             ;  +  -  -  +  -  -  +  +
    paddw     m0, m1             ; -1+3 -0+2  1+3  0+2 -1+3 -0+2  1+3  0+2
    pmaddwd   m0, m2             ;  0-1-2+3  0-1+2-3  0+1-2-3  0+1+2+3  * dmf
    punpcklwd m1, m1
    psrad     m2, 16             ;  +  -  -  +
    mov      t1d, 3
    paddd     m0, m6
    xor      t4d, t4d
%if notcpuflag(ssse3)
    psrad     m1, 31             ; has to be 0 or -1 in order for PSIGND_MMX to work correctly
%endif
%if cpuflag(sse4)
    ptest     m0, m4
%else
    mova      m6, m0
    SWAP       0, 6
    psrad     m6, 11
    pcmpeqd   m6, m4
    pmovmskb t5d, m6
    cmp      t5d, 0xffff
%endif
    jz .ret                      ; if the DC coefficients already round to zero, terminate early
    mova      m3, m0
.outer_loop:
    movsx    t3d, word [t0+2*t1] ; dct[coeff]
    pshufd    m6, m1, q3333
    pshufd    m1, m1, q2100      ; move the next element to high dword
    PSIGND    m5, m2, m6
    test     t3d, t3d
    jz .loop_end
.outer_loop_0:
    mov      t2d, t3d
    sar      t3d, 31
    or       t3d, 1
.inner_loop:
    psubd     m3, m5             ; coeff -= sign
    pxor      m6, m0, m3
%if cpuflag(sse4)
    ptest     m6, m4
%else
    psrad     m6, 11
    pcmpeqd   m6, m4
    pmovmskb t5d, m6
    cmp      t5d, 0xffff
%endif
    jz .round_coeff
    paddd     m3, m5             ; coeff += sign
    mov      t4d, 1
.loop_end:
    dec      t1d
    jz .last_coeff
    pshufd    m2, m2, q1320      ;  -  +  -  +  /  -  -  +  +
    jg .outer_loop
.ret:
    REP_RET
.round_coeff:
    sub      t2d, t3d
    mov [t0+2*t1], t2w
    jnz .inner_loop
    jmp .loop_end
.last_coeff:
    movsx    t3d, word [t0]
    punpcklqdq m2, m2            ;  +  +  +  +
    PSIGND    m5, m2, m1
    test     t3d, t3d
    jnz .outer_loop_0
    RET
%endmacro

%if HIGH_BIT_DEPTH == 0
INIT_XMM sse2
OPTIMIZE_CHROMA_2x2_DC
INIT_XMM ssse3
OPTIMIZE_CHROMA_2x2_DC
INIT_XMM sse4
OPTIMIZE_CHROMA_2x2_DC
INIT_XMM avx
OPTIMIZE_CHROMA_2x2_DC
%endif ; !HIGH_BIT_DEPTH

%if HIGH_BIT_DEPTH
;-----------------------------------------------------------------------------
; void denoise_dct( int32_t *dct, uint32_t *sum, uint32_t *offset, int size )
;-----------------------------------------------------------------------------
%macro DENOISE_DCT 0
cglobal denoise_dct, 4,4,6
    pxor      m5, m5
    movsxdifnidn r3, r3d
.loop:
    mova      m2, [r0+r3*4-2*mmsize]
    mova      m3, [r0+r3*4-1*mmsize]
    ABSD      m0, m2
    ABSD      m1, m3
    paddd     m4, m0, [r1+r3*4-2*mmsize]
    psubd     m0, [r2+r3*4-2*mmsize]
    mova      [r1+r3*4-2*mmsize], m4
    paddd     m4, m1, [r1+r3*4-1*mmsize]
    psubd     m1, [r2+r3*4-1*mmsize]
    mova      [r1+r3*4-1*mmsize], m4
    pcmpgtd   m4, m0, m5
    pand      m0, m4
    pcmpgtd   m4, m1, m5
    pand      m1, m4
    PSIGND    m0, m2
    PSIGND    m1, m3
    mova      [r0+r3*4-2*mmsize], m0
    mova      [r0+r3*4-1*mmsize], m1
    sub      r3d, mmsize/2
    jg .loop
    RET
%endmacro

%if ARCH_X86_64 == 0
INIT_MMX mmx
DENOISE_DCT
%endif
INIT_XMM sse2
DENOISE_DCT
INIT_XMM ssse3
DENOISE_DCT
INIT_XMM avx
DENOISE_DCT
INIT_YMM avx2
DENOISE_DCT

%else ; !HIGH_BIT_DEPTH

;-----------------------------------------------------------------------------
; void denoise_dct( int16_t *dct, uint32_t *sum, uint16_t *offset, int size )
;-----------------------------------------------------------------------------
%macro DENOISE_DCT 0
cglobal denoise_dct, 4,4,7
    pxor      m6, m6
    movsxdifnidn r3, r3d
.loop:
    mova      m2, [r0+r3*2-2*mmsize]
    mova      m3, [r0+r3*2-1*mmsize]
    ABSW      m0, m2, sign
    ABSW      m1, m3, sign
    psubusw   m4, m0, [r2+r3*2-2*mmsize]
    psubusw   m5, m1, [r2+r3*2-1*mmsize]
    PSIGNW    m4, m2
    PSIGNW    m5, m3
    mova      [r0+r3*2-2*mmsize], m4
    mova      [r0+r3*2-1*mmsize], m5
    punpcklwd m2, m0, m6
    punpcklwd m3, m1, m6
    punpckhwd m0, m6
    punpckhwd m1, m6
    paddd     m2, [r1+r3*4-4*mmsize]
    paddd     m0, [r1+r3*4-3*mmsize]
    paddd     m3, [r1+r3*4-2*mmsize]
    paddd     m1, [r1+r3*4-1*mmsize]
    mova      [r1+r3*4-4*mmsize], m2
    mova      [r1+r3*4-3*mmsize], m0
    mova      [r1+r3*4-2*mmsize], m3
    mova      [r1+r3*4-1*mmsize], m1
    sub       r3, mmsize
    jg .loop
    RET
%endmacro

%if ARCH_X86_64 == 0
INIT_MMX mmx
DENOISE_DCT
%endif
INIT_XMM sse2
DENOISE_DCT
INIT_XMM ssse3
DENOISE_DCT
INIT_XMM avx
DENOISE_DCT

INIT_YMM avx2
cglobal denoise_dct, 4,4,4
    pxor      m3, m3
    movsxdifnidn r3, r3d
.loop:
    mova      m1, [r0+r3*2-mmsize]
    pabsw     m0, m1
    psubusw   m2, m0, [r2+r3*2-mmsize]
    vpermq    m0, m0, q3120
    psignw    m2, m1
    mova [r0+r3*2-mmsize], m2
    punpcklwd m1, m0, m3
    punpckhwd m0, m3
    paddd     m1, [r1+r3*4-2*mmsize]
    paddd     m0, [r1+r3*4-1*mmsize]
    mova      [r1+r3*4-2*mmsize], m1
    mova      [r1+r3*4-1*mmsize], m0
    sub       r3, mmsize/2
    jg .loop
    RET

%endif ; !HIGH_BIT_DEPTH

;-----------------------------------------------------------------------------
; int decimate_score( dctcoef *dct )
;-----------------------------------------------------------------------------

%macro DECIMATE_MASK 4
%if HIGH_BIT_DEPTH
    mova      m0, [%3+0*16]
    packssdw  m0, [%3+1*16]
    mova      m1, [%3+2*16]
    packssdw  m1, [%3+3*16]
    ABSW2     m0, m1, m0, m1, m3, m4
%else
    ABSW      m0, [%3+ 0], m3
    ABSW      m1, [%3+16], m4
%endif
    packsswb  m0, m1
    pxor      m2, m2
    pcmpeqb   m2, m0
    pcmpgtb   m0, %4
    pmovmskb  %1, m2
    pmovmskb  %2, m0
%endmacro

%macro DECIMATE_MASK16_AVX512 0
    mova      m0, [r0]
%if HIGH_BIT_DEPTH
    vptestmd  k0, m0, m0
    pabsd     m0, m0
    vpcmpud   k1, m0, [pd_1] {1to16}, 6
%else
    vptestmw  k0, m0, m0
    pabsw     m0, m0
    vpcmpuw   k1, m0, [pw_1], 6
%endif
%endmacro

%macro SHRX 2
%if cpuflag(bmi2)
    shrx %1, %1, %2
%else
    shr  %1, %2b ; %2 has to be rcx/ecx
%endif
%endmacro

%macro BLSR 2
%if cpuflag(bmi1)
    blsr   %1, %2
%else
    lea    %1, [%2-1]
    and    %1, %2
%endif
%endmacro

cextern_common decimate_table4
cextern_common decimate_table8

%macro DECIMATE4x4 1

cglobal decimate_score%1, 1,3
%if cpuflag(avx512)
    DECIMATE_MASK16_AVX512
    xor   eax, eax
    kmovw edx, k0
%if %1 == 15
    shr   edx, 1
%else
    test  edx, edx
%endif
    jz .ret
    ktestw k1, k1
    jnz .ret9
%else
    DECIMATE_MASK edx, eax, r0, [pb_1]
    xor   edx, 0xffff
    jz .ret
    test  eax, eax
    jnz .ret9
%if %1 == 15
    shr   edx, 1
%endif
%endif
%if ARCH_X86_64
    lea    r4, [decimate_mask_table4]
    %define mask_table r4
%else
    %define mask_table decimate_mask_table4
%endif
    movzx ecx, dl
    movzx eax, byte [mask_table + rcx]
%if ARCH_X86_64
    xor   edx, ecx
    jz .ret
%if cpuflag(lzcnt)
    lzcnt ecx, ecx
    lea    r5, [decimate_table4-32]
    add    r5, rcx
%else
    bsr   ecx, ecx
    lea    r5, [decimate_table4-1]
    sub    r5, rcx
%endif
    %define table r5
%else
    cmp   edx, ecx
    jz .ret
    bsr   ecx, ecx
    shr   edx, 1
    SHRX  edx, ecx
    %define table decimate_table4
%endif
    tzcnt ecx, edx
    shr   edx, 1
    SHRX  edx, ecx
    add    al, byte [table + rcx]
    add    al, byte [mask_table + rdx]
.ret:
    REP_RET
.ret9:
    mov   eax, 9
    RET
%endmacro

%macro DECIMATE_MASK64_AVX2 2 ; nz_low, nz_high
    mova      m0, [r0+0*32]
    packsswb  m0, [r0+1*32]
    mova      m1, [r0+2*32]
    packsswb  m1, [r0+3*32]
    mova      m4, [pb_1]
    pabsb     m2, m0
    pabsb     m3, m1
    por       m2, m3 ; the > 1 checks don't care about order, so
    ptest     m4, m2 ; we can save latency by doing them here
    jnc .ret9
    vpermq    m0, m0, q3120
    vpermq    m1, m1, q3120
    pxor      m4, m4
    pcmpeqb   m0, m4
    pcmpeqb   m1, m4
    pmovmskb  %1, m0
    pmovmskb  %2, m1
%endmacro

%macro DECIMATE_MASK64_AVX512 0
    mova            m0, [r0]
%if HIGH_BIT_DEPTH
    packssdw        m0, [r0+1*64]
    mova            m1, [r0+2*64]
    packssdw        m1, [r0+3*64]
    packsswb        m0, m1
    vbroadcasti32x4 m1, [pb_1]
    pabsb           m2, m0
    vpcmpub         k0, m2, m1, 6
    ktestq          k0, k0
    jnz .ret9
    mova            m1, [decimate_shuf_avx512]
    vpermd          m0, m1, m0
    vptestmb        k1, m0, m0
%else
    mova            m1, [r0+64]
    vbroadcasti32x4 m3, [pb_1]
    packsswb        m2, m0, m1
    pabsb           m2, m2
    vpcmpub         k0, m2, m3, 6
    ktestq          k0, k0
    jnz .ret9
    vptestmw        k1, m0, m0
    vptestmw        k2, m1, m1
%endif
%endmacro

%macro DECIMATE8x8 0
%if ARCH_X86_64
cglobal decimate_score64, 1,5
%if mmsize == 64
    DECIMATE_MASK64_AVX512
    xor     eax, eax
%if HIGH_BIT_DEPTH
    kmovq    r1, k1
    test     r1, r1
    jz .ret
%else
    kortestd k1, k2
    jz .ret
    kunpckdq k1, k2, k1
    kmovq    r1, k1
%endif
%elif mmsize == 32
    DECIMATE_MASK64_AVX2 r1d, eax
    not    r1
    shl   rax, 32
    xor    r1, rax
    jz .ret
%else
    mova   m5, [pb_1]
    DECIMATE_MASK r1d, eax, r0+SIZEOF_DCTCOEF* 0, m5
    test  eax, eax
    jnz .ret9
    DECIMATE_MASK r2d, eax, r0+SIZEOF_DCTCOEF*16, m5
    shl   r2d, 16
    or    r1d, r2d
    DECIMATE_MASK r2d, r3d, r0+SIZEOF_DCTCOEF*32, m5
    shl    r2, 32
    or    eax, r3d
    or     r1, r2
    DECIMATE_MASK r2d, r3d, r0+SIZEOF_DCTCOEF*48, m5
    not    r1
    shl    r2, 48
    xor    r1, r2
    jz .ret
    add   eax, r3d
    jnz .ret9
%endif
    lea    r4, [decimate_table8]
    mov    al, -6
.loop:
    tzcnt rcx, r1
    add    al, byte [r4 + rcx]
    jge .ret9
    shr    r1, 1
    SHRX   r1, rcx
%if cpuflag(bmi2)
    test   r1, r1
%endif
    jnz .loop
    add    al, 6
.ret:
    REP_RET
.ret9:
    mov   eax, 9
    RET

%else ; ARCH
cglobal decimate_score64, 1,4
%if mmsize == 64
    DECIMATE_MASK64_AVX512
    xor     eax, eax
%if HIGH_BIT_DEPTH
    kshiftrq k2, k1, 32
%endif
    kmovd    r2, k1
    kmovd    r3, k2
    test     r2, r2
    jz .tryret
%elif mmsize == 32
    DECIMATE_MASK64_AVX2 r2, r3
    xor   eax, eax
    not    r3
    xor    r2, -1
    jz .tryret
%else
    mova   m5, [pb_1]
    DECIMATE_MASK r2, r1, r0+SIZEOF_DCTCOEF* 0, m5
    test   r1, r1
    jnz .ret9
    DECIMATE_MASK r3, r1, r0+SIZEOF_DCTCOEF*16, m5
    not    r2
    shl    r3, 16
    xor    r2, r3
    mov   r0m, r2
    DECIMATE_MASK r3, r2, r0+SIZEOF_DCTCOEF*32, m5
    or     r2, r1
    DECIMATE_MASK r1, r0, r0+SIZEOF_DCTCOEF*48, m5
    add    r0, r2
    jnz .ret9
    mov    r2, r0m
    not    r3
    shl    r1, 16
    xor    r3, r1
    test   r2, r2
    jz .tryret
%endif
    mov    al, -6
.loop:
    tzcnt ecx, r2
    add    al, byte [decimate_table8 + ecx]
    jge .ret9
    sub   ecx, 31 ; increase the shift count by one to shift away the lowest set bit as well
    jz .run31     ; only bits 0-4 are used so we have to explicitly handle the case of 1<<31
    shrd   r2, r3, cl
    SHRX   r3, ecx
%if notcpuflag(bmi2)
    test   r2, r2
%endif
    jnz .loop
    BLSR   r2, r3
    jz .end
.largerun:
    tzcnt ecx, r3
    shr    r3, 1
    SHRX   r3, ecx
.loop2:
    tzcnt ecx, r3
    add    al, byte [decimate_table8 + ecx]
    jge .ret9
    shr    r3, 1
    SHRX   r3, ecx
.run31:
    test   r3, r3
    jnz .loop2
.end:
    add    al, 6
    RET
.tryret:
    BLSR   r2, r3
    jz .ret
    mov    al, -6
    jmp .largerun
.ret9:
    mov   eax, 9
.ret:
    REP_RET
%endif ; ARCH
%endmacro

INIT_XMM sse2
DECIMATE4x4 15
DECIMATE4x4 16
DECIMATE8x8
INIT_XMM ssse3
DECIMATE4x4 15
DECIMATE4x4 16
DECIMATE8x8
%if HIGH_BIT_DEPTH
INIT_ZMM avx512
%else
INIT_YMM avx2
DECIMATE8x8
INIT_YMM avx512
%endif
DECIMATE4x4 15
DECIMATE4x4 16
INIT_ZMM avx512
DECIMATE8x8

;-----------------------------------------------------------------------------
; int coeff_last( dctcoef *dct )
;-----------------------------------------------------------------------------

%macro BSR 3
%if cpuflag(lzcnt)
    lzcnt %1, %2
    xor %1, %3
%else
    bsr %1, %2
%endif
%endmacro

%macro LZCOUNT 3
%if cpuflag(lzcnt)
    lzcnt %1, %2
%else
    bsr %1, %2
    xor %1, %3
%endif
%endmacro

%if HIGH_BIT_DEPTH
%macro LAST_MASK 3-4
%if %1 == 4
    movq     mm0, [%3]
    packssdw mm0, [%3+8]
    packsswb mm0, mm0
    pcmpeqb  mm0, mm2
    pmovmskb  %2, mm0
%elif mmsize == 16
    movdqa   xmm0, [%3+ 0]
%if %1 == 8
    packssdw xmm0, [%3+16]
    packsswb xmm0, xmm0
%else
    movdqa   xmm1, [%3+32]
    packssdw xmm0, [%3+16]
    packssdw xmm1, [%3+48]
    packsswb xmm0, xmm1
%endif
    pcmpeqb  xmm0, xmm2
    pmovmskb   %2, xmm0
%elif %1 == 8
    movq     mm0, [%3+ 0]
    movq     mm1, [%3+16]
    packssdw mm0, [%3+ 8]
    packssdw mm1, [%3+24]
    packsswb mm0, mm1
    pcmpeqb  mm0, mm2
    pmovmskb  %2, mm0
%else
    movq     mm0, [%3+ 0]
    movq     mm1, [%3+16]
    packssdw mm0, [%3+ 8]
    packssdw mm1, [%3+24]
    movq     mm3, [%3+32]
    movq     mm4, [%3+48]
    packssdw mm3, [%3+40]
    packssdw mm4, [%3+56]
    packsswb mm0, mm1
    packsswb mm3, mm4
    pcmpeqb  mm0, mm2
    pcmpeqb  mm3, mm2
    pmovmskb  %2, mm0
    pmovmskb  %4, mm3
    shl       %4, 8
    or        %2, %4
%endif
%endmacro

%macro COEFF_LAST4 0
cglobal coeff_last4, 1,3
    pxor mm2, mm2
    LAST_MASK 4, r1d, r0
    xor  r1d, 0xff
    shr  r1d, 4
    BSR  eax, r1d, 0x1f
    RET
%endmacro

INIT_MMX mmx2
COEFF_LAST4
INIT_MMX lzcnt
COEFF_LAST4

%macro COEFF_LAST8 0
cglobal coeff_last8, 1,3
    pxor m2, m2
    LAST_MASK 8, r1d, r0
%if mmsize == 16
    xor r1d, 0xffff
    shr r1d, 8
%else
    xor r1d, 0xff
%endif
    BSR eax, r1d, 0x1f
    RET
%endmacro

%if ARCH_X86_64 == 0
INIT_MMX mmx2
COEFF_LAST8
%endif
INIT_XMM sse2
COEFF_LAST8
INIT_XMM lzcnt
COEFF_LAST8

%else ; !HIGH_BIT_DEPTH
%macro LAST_MASK 3-4
%if %1 <= 8
    movq     mm0, [%3+ 0]
%if %1 == 4
    packsswb mm0, mm0
%else
    packsswb mm0, [%3+ 8]
%endif
    pcmpeqb  mm0, mm2
    pmovmskb  %2, mm0
%elif mmsize == 16
    movdqa   xmm0, [%3+ 0]
    packsswb xmm0, [%3+16]
    pcmpeqb  xmm0, xmm2
    pmovmskb   %2, xmm0
%else
    movq     mm0, [%3+ 0]
    movq     mm1, [%3+16]
    packsswb mm0, [%3+ 8]
    packsswb mm1, [%3+24]
    pcmpeqb  mm0, mm2
    pcmpeqb  mm1, mm2
    pmovmskb  %2, mm0
    pmovmskb  %4, mm1
    shl       %4, 8
    or        %2, %4
%endif
%endmacro

%macro COEFF_LAST48 0
%if ARCH_X86_64
cglobal coeff_last4, 1,1
    BSR  rax, [r0], 0x3f
    shr  eax, 4
    RET
%else
cglobal coeff_last4, 0,3
    mov   edx, r0mp
    mov   eax, [edx+4]
    xor   ecx, ecx
    test  eax, eax
    cmovz eax, [edx]
    setnz cl
    BSR   eax, eax, 0x1f
    shr   eax, 4
    lea   eax, [eax+ecx*2]
    RET
%endif

cglobal coeff_last8, 1,3
    pxor m2, m2
    LAST_MASK 8, r1d, r0, r2d
    xor r1d, 0xff
    BSR eax, r1d, 0x1f
    RET
%endmacro

INIT_MMX mmx2
COEFF_LAST48
INIT_MMX lzcnt
COEFF_LAST48
%endif ; HIGH_BIT_DEPTH

%macro COEFF_LAST 0
cglobal coeff_last15, 1,3
    pxor m2, m2
    LAST_MASK 15, r1d, r0-SIZEOF_DCTCOEF, r2d
    xor r1d, 0xffff
    BSR eax, r1d, 0x1f
    dec eax
    RET

cglobal coeff_last16, 1,3
    pxor m2, m2
    LAST_MASK 16, r1d, r0, r2d
    xor r1d, 0xffff
    BSR eax, r1d, 0x1f
    RET

%if ARCH_X86_64 == 0
cglobal coeff_last64, 1, 4-mmsize/16
    pxor m2, m2
    LAST_MASK 16, r1d, r0+SIZEOF_DCTCOEF* 32, r3d
    LAST_MASK 16, r2d, r0+SIZEOF_DCTCOEF* 48, r3d
    shl r2d, 16
    or  r1d, r2d
    xor r1d, -1
    jne .secondhalf
    LAST_MASK 16, r1d, r0+SIZEOF_DCTCOEF* 0, r3d
    LAST_MASK 16, r2d, r0+SIZEOF_DCTCOEF*16, r3d
    shl r2d, 16
    or  r1d, r2d
    not r1d
    BSR eax, r1d, 0x1f
    RET
.secondhalf:
    BSR eax, r1d, 0x1f
    add eax, 32
    RET
%else
cglobal coeff_last64, 1,3
    pxor m2, m2
    LAST_MASK 16, r1d, r0+SIZEOF_DCTCOEF* 0
    LAST_MASK 16, r2d, r0+SIZEOF_DCTCOEF*16
    shl r2d, 16
    or  r1d, r2d
    LAST_MASK 16, r2d, r0+SIZEOF_DCTCOEF*32
    LAST_MASK 16, r0d, r0+SIZEOF_DCTCOEF*48
    shl r0d, 16
    or  r2d, r0d
    shl  r2, 32
    or   r1, r2
    not  r1
    BSR rax, r1, 0x3f
    RET
%endif
%endmacro

%if ARCH_X86_64 == 0
INIT_MMX mmx2
COEFF_LAST
%endif
INIT_XMM sse2
COEFF_LAST
INIT_XMM lzcnt
COEFF_LAST

%macro LAST_MASK_AVX2 2
%if HIGH_BIT_DEPTH
    mova     m0, [%2+ 0]
    packssdw m0, [%2+32]
    mova     m1, [%2+64]
    packssdw m1, [%2+96]
    packsswb m0, m1
    mova     m1, [deinterleave_shufd]
    vpermd   m0, m1, m0
%else
    mova     m0, [%2+ 0]
    packsswb m0, [%2+32]
    vpermq   m0, m0, q3120
%endif
    pcmpeqb  m0, m2
    pmovmskb %1, m0
%endmacro

%if ARCH_X86_64 == 0
INIT_YMM avx2
cglobal coeff_last64, 1,2
    pxor m2, m2
    LAST_MASK_AVX2 r1d, r0+SIZEOF_DCTCOEF*32
    xor r1d, -1
    jne .secondhalf
    LAST_MASK_AVX2 r1d, r0+SIZEOF_DCTCOEF* 0
    not r1d
    BSR eax, r1d, 0x1f
    RET
.secondhalf:
    BSR eax, r1d, 0x1f
    add eax, 32
    RET
%else
INIT_YMM avx2
cglobal coeff_last64, 1,3
    pxor m2, m2
    LAST_MASK_AVX2 r1d, r0+SIZEOF_DCTCOEF* 0
    LAST_MASK_AVX2 r2d, r0+SIZEOF_DCTCOEF*32
    shl  r2, 32
    or   r1, r2
    not  r1
    BSR rax, r1, 0x3f
    RET
%endif

%macro COEFF_LAST_AVX512 2 ; num, w/d
cglobal coeff_last%1, 1,2
    mova         m0, [r0-(%1&1)*SIZEOF_DCTCOEF]
    vptestm%2    k0, m0, m0
%if %1 == 15
    mov         eax, 30
    kmovw       r1d, k0
    lzcnt       r1d, r1d
    sub         eax, r1d
%else
    kmovw       eax, k0
    lzcnt       eax, eax
    xor         eax, 31
%endif
    RET
%endmacro

%macro COEFF_LAST64_AVX512 1 ; w/d
cglobal coeff_last64, 1,2
    pxor        xm0, xm0
    vpcmp%1      k0, m0, [r0+0*64], 4
    vpcmp%1      k1, m0, [r0+1*64], 4
%if HIGH_BIT_DEPTH
    vpcmp%1      k2, m0, [r0+2*64], 4
    vpcmp%1      k3, m0, [r0+3*64], 4
    kunpckwd     k0, k1, k0
    kunpckwd     k1, k3, k2
%endif
%if ARCH_X86_64
    kunpckdq     k0, k1, k0
    kmovq       rax, k0
    lzcnt       rax, rax
    xor         eax, 63
%else
    kmovd       r1d, k1
    kmovd       eax, k0
    lzcnt       r1d, r1d
    lzcnt       eax, eax
    xor         r1d, 32
    cmovnz      eax, r1d
    xor         eax, 31
%endif
    RET
%endmacro

%if HIGH_BIT_DEPTH
INIT_XMM avx512
COEFF_LAST_AVX512  4, d
INIT_YMM avx512
COEFF_LAST_AVX512  8, d
INIT_ZMM avx512
COEFF_LAST_AVX512 15, d
COEFF_LAST_AVX512 16, d
COEFF_LAST64_AVX512 d
%else ; !HIGH_BIT_DEPTH
INIT_XMM avx512
COEFF_LAST_AVX512  8, w
INIT_YMM avx512
COEFF_LAST_AVX512 15, w
COEFF_LAST_AVX512 16, w
INIT_ZMM avx512
COEFF_LAST64_AVX512 w
%endif ; !HIGH_BIT_DEPTH

;-----------------------------------------------------------------------------
; int coeff_level_run( dctcoef *dct, run_level_t *runlevel )
;-----------------------------------------------------------------------------

struc levelrun
    .last: resd 1
    .mask: resd 1
    align 16, resb 1
    .level: resw 16
endstruc

; t6 = eax for return, t3 = ecx for shift, t[01] = r[01] for x86_64 args
%if WIN64
    DECLARE_REG_TMP 3,1,2,0,4,5,6
%elif ARCH_X86_64
    DECLARE_REG_TMP 0,1,2,3,4,5,6
%else
    DECLARE_REG_TMP 6,3,2,1,4,5,0
%endif

%macro COEFF_LEVELRUN 1
cglobal coeff_level_run%1,0,7
    movifnidn t0, r0mp
    movifnidn t1, r1mp
    pxor    m2, m2
    xor    t3d, t3d
    LAST_MASK %1, t5d, t0-(%1&1)*SIZEOF_DCTCOEF, t4d
%if %1==15
    shr    t5d, 1
%elif %1==8
    and    t5d, 0xff
%elif %1==4
    and    t5d, 0xf
%endif
    xor    t5d, (1<<%1)-1
    mov [t1+levelrun.mask], t5d
    shl    t5d, 32-%1
    mov    t4d, %1-1
    LZCOUNT t3d, t5d, 0x1f
    xor    t6d, t6d
    add    t5d, t5d
    sub    t4d, t3d
    shl    t5d, t3b
    mov [t1+levelrun.last], t4d
.loop:
    LZCOUNT t3d, t5d, 0x1f
%if HIGH_BIT_DEPTH
    mov    t2d, [t0+t4*4]
%else
    mov    t2w, [t0+t4*2]
%endif
    inc    t3d
    shl    t5d, t3b
%if HIGH_BIT_DEPTH
    mov   [t1+t6*4+levelrun.level], t2d
%else
    mov   [t1+t6*2+levelrun.level], t2w
%endif
    inc    t6d
    sub    t4d, t3d
    jge .loop
    RET
%endmacro

INIT_MMX mmx2
%if ARCH_X86_64 == 0
COEFF_LEVELRUN 15
COEFF_LEVELRUN 16
%endif
COEFF_LEVELRUN 4
COEFF_LEVELRUN 8
INIT_XMM sse2
%if HIGH_BIT_DEPTH
COEFF_LEVELRUN 8
%endif
COEFF_LEVELRUN 15
COEFF_LEVELRUN 16
INIT_MMX lzcnt
COEFF_LEVELRUN 4
%if HIGH_BIT_DEPTH == 0
COEFF_LEVELRUN 8
%endif
INIT_XMM lzcnt
%if HIGH_BIT_DEPTH
COEFF_LEVELRUN 8
%endif
COEFF_LEVELRUN 15
COEFF_LEVELRUN 16

; Similar to the one above, but saves the DCT
; coefficients in m0/m1 so we don't have to load
; them later.
%macro LAST_MASK_LUT 3
    pxor     xm5, xm5
%if %1 <= 8
    mova      m0, [%3]
    packsswb  m2, m0, m0
%else
    mova     xm0, [%3+ 0]
    mova     xm1, [%3+16]
    packsswb xm2, xm0, xm1
%if mmsize==32
    vinserti128 m0, m0, xm1, 1
%endif
%endif
    pcmpeqb  xm2, xm5
    pmovmskb  %2, xm2
%endmacro

%macro COEFF_LEVELRUN_LUT 1
cglobal coeff_level_run%1,2,4+(%1/9)
%if ARCH_X86_64
    lea       r5, [$$]
    %define GLOBAL +r5-$$
%else
    %define GLOBAL
%endif
    LAST_MASK_LUT %1, eax, r0-(%1&1)*SIZEOF_DCTCOEF
%if %1==15
    shr     eax, 1
%elif %1==8
    and     eax, 0xff
%elif %1==4
    and     eax, 0xf
%endif
    xor     eax, (1<<%1)-1
    mov [r1+levelrun.mask], eax
%if %1==15
    add     eax, eax
%endif
%if %1 > 8
%if ARCH_X86_64
    mov     r4d, eax
    shr     r4d, 8
%else
    movzx   r4d, ah ; first 8 bits
%endif
%endif
    movzx   r2d, al ; second 8 bits
    shl     eax, 32-%1-(%1&1)
    LZCOUNT eax, eax, 0x1f
    mov     r3d, %1-1
    sub     r3d, eax
    mov [r1+levelrun.last], r3d
; Here we abuse pshufb, combined with a lookup table, to do a gather
; operation based on a bitmask. For example:
;
; dct 15-8 (input): 0  0  4  0  0 -2  1  0
; dct  7-0 (input): 0  0 -1  0  0  0  0 15
; bitmask 1:        0  0  1  0  0  1  1  0
; bitmask 2:        0  0  1  0  0  0  0  1
; gather 15-8:      4 -2  1 __ __ __ __ __
; gather  7-0:     -1 15 __ __ __ __ __ __
; levels (output):  4 -2  1 -1 15 __ __ __ __ __ __ __ __ __ __ __
;
; The overlapping, dependent stores almost surely cause a mess of
; forwarding issues, but it's still enormously faster.
%if %1 > 8
    movzx   eax, byte [popcnt_table+r4 GLOBAL]
    movzx   r3d, byte [popcnt_table+r2 GLOBAL]
%if mmsize==16
    movh      m3, [dct_coef_shuffle+r4*8 GLOBAL]
    movh      m2, [dct_coef_shuffle+r2*8 GLOBAL]
    mova      m4, [pw_256]
; Storing 8 bytes of shuffle constant and converting it (unpack + or)
; is neutral to slightly faster in local speed measurements, but it
; cuts the table size in half, which is surely a big cache win.
    punpcklbw m3, m3
    punpcklbw m2, m2
    por       m3, m4
    por       m2, m4
    pshufb    m1, m3
    pshufb    m0, m2
    mova [r1+levelrun.level], m1
; This obnoxious unaligned store messes with store forwarding and
; stalls the CPU to no end, but merging the two registers before
; storing requires a variable 128-bit shift. Emulating this does
; work, but requires a lot of ops and the gain is tiny and
; inconsistent, so we'll err on the side of fewer instructions.
    movu [r1+rax*2+levelrun.level], m0
%else ; mmsize==32
    movq     xm2, [dct_coef_shuffle+r4*8 GLOBAL]
    vinserti128 m2, m2, [dct_coef_shuffle+r2*8 GLOBAL], 1
    punpcklbw m2, m2
    por       m2, [pw_256]
    pshufb    m0, m2
    vextracti128 [r1+levelrun.level], m0, 1
    movu [r1+rax*2+levelrun.level], xm0
%endif
    add     eax, r3d
%else
    movzx   eax, byte [popcnt_table+r2 GLOBAL]
    movh m1, [dct_coef_shuffle+r2*8 GLOBAL]
    punpcklbw m1, m1
    por       m1, [pw_256]
    pshufb    m0, m1
    mova [r1+levelrun.level], m0
%endif
    RET
%endmacro

%if HIGH_BIT_DEPTH==0
INIT_MMX ssse3
COEFF_LEVELRUN_LUT 4
INIT_XMM ssse3
COEFF_LEVELRUN_LUT 8
COEFF_LEVELRUN_LUT 15
COEFF_LEVELRUN_LUT 16
INIT_MMX ssse3, lzcnt
COEFF_LEVELRUN_LUT 4
INIT_XMM ssse3, lzcnt
COEFF_LEVELRUN_LUT 8
COEFF_LEVELRUN_LUT 15
COEFF_LEVELRUN_LUT 16
INIT_XMM avx2
COEFF_LEVELRUN_LUT 15
COEFF_LEVELRUN_LUT 16
%endif
