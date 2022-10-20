;*****************************************************************************
;* x86util.asm: x86 utility macros
;*****************************************************************************
;* Copyright (C) 2008-2022 x264 project
;*
;* Authors: Holger Lubitz <holger@lubitz.org>
;*          Loren Merritt <lorenm@u.washington.edu>
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

; like cextern, but with a plain x264 prefix instead of a bitdepth-specific one
%macro cextern_common 1
    %xdefine %1 mangle(x264 %+ _ %+ %1)
    CAT_XDEFINE cglobaled_, %1, 1
    extern %1
%endmacro

%ifndef BIT_DEPTH
    %assign BIT_DEPTH 0
%endif

%if BIT_DEPTH > 8
    %assign HIGH_BIT_DEPTH 1
%else
    %assign HIGH_BIT_DEPTH 0
%endif

%assign FENC_STRIDE 16
%assign FDEC_STRIDE 32

%assign SIZEOF_PIXEL 1
%assign SIZEOF_DCTCOEF 2
%define pixel byte
%define vpbroadcastdct vpbroadcastw
%define vpbroadcastpix vpbroadcastb
%if HIGH_BIT_DEPTH
    %assign SIZEOF_PIXEL 2
    %assign SIZEOF_DCTCOEF 4
    %define pixel word
    %define vpbroadcastdct vpbroadcastd
    %define vpbroadcastpix vpbroadcastw
%endif

%assign FENC_STRIDEB SIZEOF_PIXEL*FENC_STRIDE
%assign FDEC_STRIDEB SIZEOF_PIXEL*FDEC_STRIDE

%assign PIXEL_MAX ((1 << BIT_DEPTH)-1)

%macro FIX_STRIDES 1-*
%if HIGH_BIT_DEPTH
%rep %0
    add %1, %1
    %rotate 1
%endrep
%endif
%endmacro

%macro SBUTTERFLY 4
%ifidn %1, dqqq
    vperm2i128  m%4, m%2, m%3, q0301 ; punpckh
    vinserti128 m%2, m%2, xm%3, 1    ; punpckl
%elif avx_enabled && mmsize >= 16
    punpckh%1 m%4, m%2, m%3
    punpckl%1 m%2, m%3
%else
    mova      m%4, m%2
    punpckl%1 m%2, m%3
    punpckh%1 m%4, m%3
%endif
    SWAP %3, %4
%endmacro

%macro SBUTTERFLY2 4
    punpckl%1 m%4, m%2, m%3
    punpckh%1 m%2, m%2, m%3
    SWAP %2, %4, %3
%endmacro

%macro TRANSPOSE4x4W 5
    SBUTTERFLY wd, %1, %2, %5
    SBUTTERFLY wd, %3, %4, %5
    SBUTTERFLY dq, %1, %3, %5
    SBUTTERFLY dq, %2, %4, %5
    SWAP %2, %3
%endmacro

%macro TRANSPOSE2x4x4W 5
    SBUTTERFLY wd,  %1, %2, %5
    SBUTTERFLY wd,  %3, %4, %5
    SBUTTERFLY dq,  %1, %3, %5
    SBUTTERFLY dq,  %2, %4, %5
    SBUTTERFLY qdq, %1, %2, %5
    SBUTTERFLY qdq, %3, %4, %5
%endmacro

%macro TRANSPOSE4x4D 5
    SBUTTERFLY dq,  %1, %2, %5
    SBUTTERFLY dq,  %3, %4, %5
    SBUTTERFLY qdq, %1, %3, %5
    SBUTTERFLY qdq, %2, %4, %5
    SWAP %2, %3
%endmacro

%macro TRANSPOSE8x8W 9-11
%if ARCH_X86_64
    SBUTTERFLY wd,  %1, %2, %9
    SBUTTERFLY wd,  %3, %4, %9
    SBUTTERFLY wd,  %5, %6, %9
    SBUTTERFLY wd,  %7, %8, %9
    SBUTTERFLY dq,  %1, %3, %9
    SBUTTERFLY dq,  %2, %4, %9
    SBUTTERFLY dq,  %5, %7, %9
    SBUTTERFLY dq,  %6, %8, %9
    SBUTTERFLY qdq, %1, %5, %9
    SBUTTERFLY qdq, %2, %6, %9
    SBUTTERFLY qdq, %3, %7, %9
    SBUTTERFLY qdq, %4, %8, %9
    SWAP %2, %5
    SWAP %4, %7
%else
; in:  m0..m7, unless %11 in which case m6 is in %9
; out: m0..m7, unless %11 in which case m4 is in %10
; spills into %9 and %10
%if %0<11
    movdqa %9, m%7
%endif
    SBUTTERFLY wd,  %1, %2, %7
    movdqa %10, m%2
    movdqa m%7, %9
    SBUTTERFLY wd,  %3, %4, %2
    SBUTTERFLY wd,  %5, %6, %2
    SBUTTERFLY wd,  %7, %8, %2
    SBUTTERFLY dq,  %1, %3, %2
    movdqa %9, m%3
    movdqa m%2, %10
    SBUTTERFLY dq,  %2, %4, %3
    SBUTTERFLY dq,  %5, %7, %3
    SBUTTERFLY dq,  %6, %8, %3
    SBUTTERFLY qdq, %1, %5, %3
    SBUTTERFLY qdq, %2, %6, %3
    movdqa %10, m%2
    movdqa m%3, %9
    SBUTTERFLY qdq, %3, %7, %2
    SBUTTERFLY qdq, %4, %8, %2
    SWAP %2, %5
    SWAP %4, %7
%if %0<11
    movdqa m%5, %10
%endif
%endif
%endmacro

%macro WIDEN_SXWD 2
    punpckhwd m%2, m%1
    psrad     m%2, 16
%if cpuflag(sse4)
    pmovsxwd  m%1, m%1
%else
    punpcklwd m%1, m%1
    psrad     m%1, 16
%endif
%endmacro

%macro ABSW 2-3 ; dst, src, tmp (tmp used only if dst==src)
%if cpuflag(ssse3)
    pabsw   %1, %2
%elifidn %3, sign ; version for pairing with PSIGNW: modifies src
    pxor    %1, %1
    pcmpgtw %1, %2
    pxor    %2, %1
    psubw   %2, %1
    SWAP    %1, %2
%elifidn %1, %2
    pxor    %3, %3
    psubw   %3, %1
    pmaxsw  %1, %3
%elifid %2
    pxor    %1, %1
    psubw   %1, %2
    pmaxsw  %1, %2
%elif %0 == 2
    pxor    %1, %1
    psubw   %1, %2
    pmaxsw  %1, %2
%else
    mova    %1, %2
    pxor    %3, %3
    psubw   %3, %1
    pmaxsw  %1, %3
%endif
%endmacro

%macro ABSW2 6 ; dst1, dst2, src1, src2, tmp, tmp
%if cpuflag(ssse3)
    pabsw   %1, %3
    pabsw   %2, %4
%elifidn %1, %3
    pxor    %5, %5
    pxor    %6, %6
    psubw   %5, %1
    psubw   %6, %2
    pmaxsw  %1, %5
    pmaxsw  %2, %6
%else
    pxor    %1, %1
    pxor    %2, %2
    psubw   %1, %3
    psubw   %2, %4
    pmaxsw  %1, %3
    pmaxsw  %2, %4
%endif
%endmacro

%macro ABSB 2
%if cpuflag(ssse3)
    pabsb   %1, %1
%else
    pxor    %2, %2
    psubb   %2, %1
    pminub  %1, %2
%endif
%endmacro

%macro ABSD 2-3
%if cpuflag(ssse3)
    pabsd   %1, %2
%else
    %define %%s %2
%if %0 == 3
    mova    %3, %2
    %define %%s %3
%endif
    pxor     %1, %1
    pcmpgtd  %1, %%s
    pxor    %%s, %1
    psubd   %%s, %1
    SWAP     %1, %%s
%endif
%endmacro

%macro PSIGN 3-4
%if cpuflag(ssse3) && %0 == 4
    psign%1 %2, %3, %4
%elif cpuflag(ssse3)
    psign%1 %2, %3
%elif %0 == 4
    pxor    %2, %3, %4
    psub%1  %2, %4
%else
    pxor    %2, %3
    psub%1  %2, %3
%endif
%endmacro

%define PSIGNW PSIGN w,
%define PSIGND PSIGN d,

%macro SPLATB_LOAD 3
%if cpuflag(ssse3)
    movd      %1, [%2-3]
    pshufb    %1, %3
%else
    movd      %1, [%2-3] ;to avoid crossing a cacheline
    punpcklbw %1, %1
    SPLATW    %1, %1, 3
%endif
%endmacro

%imacro SPLATW 2-3 0
%if cpuflag(avx2) && %3 == 0
    vpbroadcastw %1, %2
%else
    %define %%s %2
%ifid %2
    %define %%s xmm%2
%elif %3 == 0
    movd      xmm%1, %2
    %define %%s xmm%1
%endif
    PSHUFLW   xmm%1, %%s, (%3)*q1111
%if mmsize >= 32
    vpbroadcastq %1, xmm%1
%elif mmsize == 16
    punpcklqdq   %1, %1
%endif
%endif
%endmacro

%imacro SPLATD 2-3 0
%if cpuflag(avx2) && %3 == 0
    vpbroadcastd %1, %2
%else
    %define %%s %2
%ifid %2
    %define %%s xmm%2
%elif %3 == 0
    movd      xmm%1, %2
    %define %%s xmm%1
%endif
%if mmsize == 8 && %3 == 0
%ifidn %1, %%s
    punpckldq    %1, %1
%else
    pshufw       %1, %%s, q1010
%endif
%elif mmsize == 8 && %3 == 1
%ifidn %1, %%s
    punpckhdq    %1, %1
%else
    pshufw       %1, %%s, q3232
%endif
%else
    pshufd    xmm%1, %%s, (%3)*q1111
%endif
%if mmsize >= 32
    vpbroadcastq %1, xmm%1
%endif
%endif
%endmacro

%macro CLIPW 3 ;(dst, min, max)
    pmaxsw %1, %2
    pminsw %1, %3
%endmacro

%macro MOVHL 2 ; dst, src
%ifidn %1, %2
    punpckhqdq %1, %2
%elif cpuflag(avx)
    punpckhqdq %1, %2, %2
%elif cpuflag(sse4)
    pshufd     %1, %2, q3232 ; pshufd is slow on some older CPUs, so only use it on more modern ones
%else
    movhlps    %1, %2        ; may cause an int/float domain transition and has a dependency on dst
%endif
%endmacro

%macro HADDD 2 ; sum junk
%if sizeof%1 >= 64
    vextracti32x8 ymm%2, zmm%1, 1
    paddd         ymm%1, ymm%2
%endif
%if sizeof%1 >= 32
    vextracti128  xmm%2, ymm%1, 1
    paddd         xmm%1, xmm%2
%endif
%if sizeof%1 >= 16
    MOVHL         xmm%2, xmm%1
    paddd         xmm%1, xmm%2
%endif
%if cpuflag(xop) && sizeof%1 == 16
    vphadddq      xmm%1, xmm%1
%else
    PSHUFLW       xmm%2, xmm%1, q1032
    paddd         xmm%1, xmm%2
%endif
%endmacro

%macro HADDW 2 ; reg, tmp
%if cpuflag(xop) && sizeof%1 == 16
    vphaddwq  %1, %1
    MOVHL     %2, %1
    paddd     %1, %2
%else
    pmaddwd   %1, [pw_1]
    HADDD     %1, %2
%endif
%endmacro

%macro HADDUWD 2
%if cpuflag(xop) && sizeof%1 == 16
    vphadduwd %1, %1
%else
    psrld %2, %1, 16
    pslld %1, 16
    psrld %1, 16
    paddd %1, %2
%endif
%endmacro

%macro HADDUW 2
%if cpuflag(xop) && sizeof%1 == 16
    vphadduwq %1, %1
    MOVHL     %2, %1
    paddd     %1, %2
%else
    HADDUWD   %1, %2
    HADDD     %1, %2
%endif
%endmacro

%macro PALIGNR 4-5 ; [dst,] src1, src2, imm, tmp
; AVX2 version uses a precalculated extra input that
; can be re-used across calls
%if sizeof%1==32
                                 ; %3 = abcdefgh ijklmnop (lower address)
                                 ; %2 = ABCDEFGH IJKLMNOP (higher address)
;   vperm2i128 %5, %2, %3, q0003 ; %5 = ijklmnop ABCDEFGH
%if %4 < 16
    palignr    %1, %5, %3, %4    ; %1 = bcdefghi jklmnopA
%else
    palignr    %1, %2, %5, %4-16 ; %1 = pABCDEFG HIJKLMNO
%endif
%elif cpuflag(ssse3)
    %if %0==5
        palignr %1, %2, %3, %4
    %else
        palignr %1, %2, %3
    %endif
%else
    %define %%dst %1
    %if %0==5
        %ifnidn %1, %2
            mova %%dst, %2
        %endif
        %rotate 1
    %endif
    %ifnidn %4, %2
        mova %4, %2
    %endif
    %if mmsize==8
        psllq  %%dst, (8-%3)*8
        psrlq  %4, %3*8
    %else
        pslldq %%dst, 16-%3
        psrldq %4, %3
    %endif
    por %%dst, %4
%endif
%endmacro

%macro PSHUFLW 1+
    %if mmsize == 8
        pshufw %1
    %else
        pshuflw %1
    %endif
%endmacro

; shift a mmxreg by n bytes, or a xmmreg by 2*n bytes
; values shifted in are undefined
; faster if dst==src
%define PSLLPIX PSXLPIX l, -1, ;dst, src, shift
%define PSRLPIX PSXLPIX r,  1, ;dst, src, shift
%macro PSXLPIX 5
    %if mmsize == 8
        %if %5&1
            ps%1lq %3, %4, %5*8
        %else
            pshufw %3, %4, (q3210<<8>>(8+%2*%5))&0xff
        %endif
    %else
        ps%1ldq %3, %4, %5*2
    %endif
%endmacro

%macro DEINTB 5 ; mask, reg1, mask, reg2, optional src to fill masks from
%ifnum %5
    pand   m%3, m%5, m%4 ; src .. y6 .. y4
    pand   m%1, m%5, m%2 ; dst .. y6 .. y4
%else
    mova   m%1, %5
    pand   m%3, m%1, m%4 ; src .. y6 .. y4
    pand   m%1, m%1, m%2 ; dst .. y6 .. y4
%endif
    psrlw  m%2, 8        ; dst .. y7 .. y5
    psrlw  m%4, 8        ; src .. y7 .. y5
%endmacro

%macro SUMSUB_BA 3-4
%if %0==3
    padd%1  m%2, m%3
    padd%1  m%3, m%3
    psub%1  m%3, m%2
%elif avx_enabled
    padd%1  m%4, m%2, m%3
    psub%1  m%3, m%2
    SWAP    %2, %4
%else
    mova    m%4, m%2
    padd%1  m%2, m%3
    psub%1  m%3, m%4
%endif
%endmacro

%macro SUMSUB_BADC 5-6
%if %0==6
    SUMSUB_BA %1, %2, %3, %6
    SUMSUB_BA %1, %4, %5, %6
%else
    padd%1  m%2, m%3
    padd%1  m%4, m%5
    padd%1  m%3, m%3
    padd%1  m%5, m%5
    psub%1  m%3, m%2
    psub%1  m%5, m%4
%endif
%endmacro

%macro HADAMARD4_V 4+
    SUMSUB_BADC w, %1, %2, %3, %4
    SUMSUB_BADC w, %1, %3, %2, %4
%endmacro

%macro HADAMARD8_V 8+
    SUMSUB_BADC w, %1, %2, %3, %4
    SUMSUB_BADC w, %5, %6, %7, %8
    SUMSUB_BADC w, %1, %3, %2, %4
    SUMSUB_BADC w, %5, %7, %6, %8
    SUMSUB_BADC w, %1, %5, %2, %6
    SUMSUB_BADC w, %3, %7, %4, %8
%endmacro

%macro TRANS_SSE2 5-6
; TRANSPOSE2x2
; %1: transpose width (d/q) - use SBUTTERFLY qdq for dq
; %2: ord/unord (for compat with sse4, unused)
; %3/%4: source regs
; %5/%6: tmp regs
%ifidn %1, d
%define mask [mask_10]
%define shift 16
%elifidn %1, q
%define mask [mask_1100]
%define shift 32
%endif
%if %0==6 ; less dependency if we have two tmp
    mova   m%5, mask   ; ff00
    mova   m%6, m%4    ; x5x4
    psll%1 m%4, shift  ; x4..
    pand   m%6, m%5    ; x5..
    pandn  m%5, m%3    ; ..x0
    psrl%1 m%3, shift  ; ..x1
    por    m%4, m%5    ; x4x0
    por    m%3, m%6    ; x5x1
%else ; more dependency, one insn less. sometimes faster, sometimes not
    mova   m%5, m%4    ; x5x4
    psll%1 m%4, shift  ; x4..
    pxor   m%4, m%3    ; (x4^x1)x0
    pand   m%4, mask   ; (x4^x1)..
    pxor   m%3, m%4    ; x4x0
    psrl%1 m%4, shift  ; ..(x1^x4)
    pxor   m%5, m%4    ; x5x1
    SWAP   %4, %3, %5
%endif
%endmacro

%macro TRANS_SSE4 5-6 ; see above
%ifidn %1, d
%ifidn %2, ord
    psrl%1  m%5, m%3, 16
    pblendw m%5, m%4, q2222
    psll%1  m%4, 16
    pblendw m%4, m%3, q1111
    SWAP     %3, %5
%else
%if avx_enabled
    pblendw m%5, m%3, m%4, q2222
    SWAP     %3, %5
%else
    mova    m%5, m%3
    pblendw m%3, m%4, q2222
%endif
    psll%1  m%4, 16
    psrl%1  m%5, 16
    por     m%4, m%5
%endif
%elifidn %1, q
    shufps m%5, m%3, m%4, q3131
    shufps m%3, m%3, m%4, q2020
    SWAP    %4, %5
%endif
%endmacro

%macro TRANS_XOP 5-6
%ifidn %1, d
    vpperm m%5, m%3, m%4, [transd_shuf1]
    vpperm m%3, m%3, m%4, [transd_shuf2]
%elifidn %1, q
    shufps m%5, m%3, m%4, q3131
    shufps m%3, m%4, q2020
%endif
    SWAP    %4, %5
%endmacro

%macro HADAMARD 5-6
; %1=distance in words (0 for vertical pass, 1/2/4 for horizontal passes)
; %2=sumsub/max/amax (sum and diff / maximum / maximum of absolutes)
; %3/%4: regs
; %5(%6): tmpregs
%if %1!=0 ; have to reorder stuff for horizontal op
    %ifidn %2, sumsub
        %define ORDER ord
        ; sumsub needs order because a-b != b-a unless a=b
    %else
        %define ORDER unord
        ; if we just max, order doesn't matter (allows pblendw+or in sse4)
    %endif
    %if %1==1
        TRANS d, ORDER, %3, %4, %5, %6
    %elif %1==2
        %if mmsize==8
            SBUTTERFLY dq, %3, %4, %5
        %elif %0==6
            TRANS q, ORDER, %3, %4, %5, %6
        %else
            TRANS q, ORDER, %3, %4, %5
        %endif
    %elif %1==4
        SBUTTERFLY qdq, %3, %4, %5
    %elif %1==8
        SBUTTERFLY dqqq, %3, %4, %5
    %endif
%endif
%ifidn %2, sumsub
    SUMSUB_BA w, %3, %4, %5
%else
    %ifidn %2, amax
        %if %0==6
            ABSW2 m%3, m%4, m%3, m%4, m%5, m%6
        %else
            ABSW m%3, m%3, m%5
            ABSW m%4, m%4, m%5
        %endif
    %endif
    pmaxsw m%3, m%4
%endif
%endmacro


%macro HADAMARD2_2D 6-7 sumsub
    HADAMARD 0, sumsub, %1, %2, %5
    HADAMARD 0, sumsub, %3, %4, %5
    SBUTTERFLY %6, %1, %2, %5
%ifnum %7
    HADAMARD 0, amax, %1, %2, %5, %7
%else
    HADAMARD 0, %7, %1, %2, %5
%endif
    SBUTTERFLY %6, %3, %4, %5
%ifnum %7
    HADAMARD 0, amax, %3, %4, %5, %7
%else
    HADAMARD 0, %7, %3, %4, %5
%endif
%endmacro

%macro HADAMARD4_2D 5-6 sumsub
    HADAMARD2_2D %1, %2, %3, %4, %5, wd
    HADAMARD2_2D %1, %3, %2, %4, %5, dq, %6
    SWAP %2, %3
%endmacro

%macro HADAMARD4_2D_SSE 5-6 sumsub
    HADAMARD  0, sumsub, %1, %2, %5 ; 1st V row 0 + 1
    HADAMARD  0, sumsub, %3, %4, %5 ; 1st V row 2 + 3
    SBUTTERFLY   wd, %1, %2, %5     ; %1: m0 1+0 %2: m1 1+0
    SBUTTERFLY   wd, %3, %4, %5     ; %3: m0 3+2 %4: m1 3+2
    HADAMARD2_2D %1, %3, %2, %4, %5, dq
    SBUTTERFLY  qdq, %1, %2, %5
    HADAMARD  0, %6, %1, %2, %5     ; 2nd H m1/m0 row 0+1
    SBUTTERFLY  qdq, %3, %4, %5
    HADAMARD  0, %6, %3, %4, %5     ; 2nd H m1/m0 row 2+3
%endmacro

%macro HADAMARD8_2D 9-10 sumsub
    HADAMARD2_2D %1, %2, %3, %4, %9, wd
    HADAMARD2_2D %5, %6, %7, %8, %9, wd
    HADAMARD2_2D %1, %3, %2, %4, %9, dq
    HADAMARD2_2D %5, %7, %6, %8, %9, dq
    HADAMARD2_2D %1, %5, %3, %7, %9, qdq, %10
    HADAMARD2_2D %2, %6, %4, %8, %9, qdq, %10
%ifnidn %10, amax
    SWAP %2, %5
    SWAP %4, %7
%endif
%endmacro

; doesn't include the "pmaddubsw hmul_8p" pass
%macro HADAMARD8_2D_HMUL 10
    HADAMARD4_V %1, %2, %3, %4, %9
    HADAMARD4_V %5, %6, %7, %8, %9
    SUMSUB_BADC w, %1, %5, %2, %6, %9
    HADAMARD 2, sumsub, %1, %5, %9, %10
    HADAMARD 2, sumsub, %2, %6, %9, %10
    SUMSUB_BADC w, %3, %7, %4, %8, %9
    HADAMARD 2, sumsub, %3, %7, %9, %10
    HADAMARD 2, sumsub, %4, %8, %9, %10
    HADAMARD 1, amax, %1, %5, %9, %10
    HADAMARD 1, amax, %2, %6, %9, %5
    HADAMARD 1, amax, %3, %7, %9, %5
    HADAMARD 1, amax, %4, %8, %9, %5
%endmacro

%macro SUMSUB2_AB 4
%if cpuflag(xop)
    pmacs%1%1 m%4, m%3, [p%1_m2], m%2
    pmacs%1%1 m%2, m%2, [p%1_2], m%3
%elifnum %3
    psub%1  m%4, m%2, m%3
    psub%1  m%4, m%3
    padd%1  m%2, m%2
    padd%1  m%2, m%3
%else
    mova    m%4, m%2
    padd%1  m%2, m%2
    padd%1  m%2, %3
    psub%1  m%4, %3
    psub%1  m%4, %3
%endif
%endmacro

%macro SUMSUBD2_AB 5
%ifnum %4
    psra%1  m%5, m%2, 1  ; %3: %3>>1
    psra%1  m%4, m%3, 1  ; %2: %2>>1
    padd%1  m%4, m%2     ; %3: %3>>1+%2
    psub%1  m%5, m%3     ; %2: %2>>1-%3
    SWAP     %2, %5
    SWAP     %3, %4
%else
    mova    %5, m%2
    mova    %4, m%3
    psra%1  m%3, 1  ; %3: %3>>1
    psra%1  m%2, 1  ; %2: %2>>1
    padd%1  m%3, %5 ; %3: %3>>1+%2
    psub%1  m%2, %4 ; %2: %2>>1-%3
%endif
%endmacro

%macro DCT4_1D 5
%ifnum %5
    SUMSUB_BADC w, %4, %1, %3, %2, %5
    SUMSUB_BA   w, %3, %4, %5
    SUMSUB2_AB  w, %1, %2, %5
    SWAP %1, %3, %4, %5, %2
%else
    SUMSUB_BADC w, %4, %1, %3, %2
    SUMSUB_BA   w, %3, %4
    mova     [%5], m%2
    SUMSUB2_AB  w, %1, [%5], %2
    SWAP %1, %3, %4, %2
%endif
%endmacro

%macro IDCT4_1D 6-7
%ifnum %6
    SUMSUBD2_AB %1, %3, %5, %7, %6
    ; %3: %3>>1-%5 %5: %3+%5>>1
    SUMSUB_BA   %1, %4, %2, %7
    ; %4: %2+%4 %2: %2-%4
    SUMSUB_BADC %1, %5, %4, %3, %2, %7
    ; %5: %2+%4 + (%3+%5>>1)
    ; %4: %2+%4 - (%3+%5>>1)
    ; %3: %2-%4 + (%3>>1-%5)
    ; %2: %2-%4 - (%3>>1-%5)
%else
%ifidn %1, w
    SUMSUBD2_AB %1, %3, %5, [%6], [%6+16]
%else
    SUMSUBD2_AB %1, %3, %5, [%6], [%6+32]
%endif
    SUMSUB_BA   %1, %4, %2
    SUMSUB_BADC %1, %5, %4, %3, %2
%endif
    SWAP %2, %5, %4
    ; %2: %2+%4 + (%3+%5>>1) row0
    ; %3: %2-%4 + (%3>>1-%5) row1
    ; %4: %2-%4 - (%3>>1-%5) row2
    ; %5: %2+%4 - (%3+%5>>1) row3
%endmacro


%macro LOAD_DIFF 5-6 1
%if HIGH_BIT_DEPTH
%if %6 ; %5 aligned?
    mova       %1, %4
    psubw      %1, %5
%elif cpuflag(avx)
    movu       %1, %4
    psubw      %1, %5
%else
    movu       %1, %4
    movu       %2, %5
    psubw      %1, %2
%endif
%else ; !HIGH_BIT_DEPTH
    movh       %1, %4
    movh       %2, %5
%ifidn %3, none
    punpcklbw  %1, %2
    punpcklbw  %2, %2
%else
    punpcklbw  %1, %3
    punpcklbw  %2, %3
%endif
    psubw      %1, %2
%endif ; HIGH_BIT_DEPTH
%endmacro

%macro LOAD_DIFF8x4 8 ; 4x dst, 1x tmp, 1x mul, 2x ptr
%if BIT_DEPTH == 8 && cpuflag(ssse3)
    movh       m%2, [%8+%1*FDEC_STRIDE]
    movh       m%1, [%7+%1*FENC_STRIDE]
    punpcklbw  m%1, m%2
    movh       m%3, [%8+%2*FDEC_STRIDE]
    movh       m%2, [%7+%2*FENC_STRIDE]
    punpcklbw  m%2, m%3
    movh       m%4, [%8+%3*FDEC_STRIDE]
    movh       m%3, [%7+%3*FENC_STRIDE]
    punpcklbw  m%3, m%4
    movh       m%5, [%8+%4*FDEC_STRIDE]
    movh       m%4, [%7+%4*FENC_STRIDE]
    punpcklbw  m%4, m%5
    pmaddubsw  m%1, m%6
    pmaddubsw  m%2, m%6
    pmaddubsw  m%3, m%6
    pmaddubsw  m%4, m%6
%else
    LOAD_DIFF  m%1, m%5, m%6, [%7+%1*FENC_STRIDEB], [%8+%1*FDEC_STRIDEB]
    LOAD_DIFF  m%2, m%5, m%6, [%7+%2*FENC_STRIDEB], [%8+%2*FDEC_STRIDEB]
    LOAD_DIFF  m%3, m%5, m%6, [%7+%3*FENC_STRIDEB], [%8+%3*FDEC_STRIDEB]
    LOAD_DIFF  m%4, m%5, m%6, [%7+%4*FENC_STRIDEB], [%8+%4*FDEC_STRIDEB]
%endif
%endmacro

%macro STORE_DCT 6
    movq   [%5+%6+ 0], m%1
    movq   [%5+%6+ 8], m%2
    movq   [%5+%6+16], m%3
    movq   [%5+%6+24], m%4
    movhps [%5+%6+32], m%1
    movhps [%5+%6+40], m%2
    movhps [%5+%6+48], m%3
    movhps [%5+%6+56], m%4
%endmacro

%macro STORE_IDCT 4
    movhps [r0-4*FDEC_STRIDE], %1
    movh   [r0-3*FDEC_STRIDE], %1
    movhps [r0-2*FDEC_STRIDE], %2
    movh   [r0-1*FDEC_STRIDE], %2
    movhps [r0+0*FDEC_STRIDE], %3
    movh   [r0+1*FDEC_STRIDE], %3
    movhps [r0+2*FDEC_STRIDE], %4
    movh   [r0+3*FDEC_STRIDE], %4
%endmacro

%macro LOAD_DIFF_8x4P 7-11 r0,r2,0,1 ; 4x dest, 2x temp, 2x pointer, increment, aligned?
    LOAD_DIFF m%1, m%5, m%7, [%8],      [%9],      %11
    LOAD_DIFF m%2, m%6, m%7, [%8+r1],   [%9+r3],   %11
    LOAD_DIFF m%3, m%5, m%7, [%8+2*r1], [%9+2*r3], %11
    LOAD_DIFF m%4, m%6, m%7, [%8+r4],   [%9+r5],   %11
%if %10
    lea %8, [%8+4*r1]
    lea %9, [%9+4*r3]
%endif
%endmacro

; 2xdst, 2xtmp, 2xsrcrow
%macro LOAD_DIFF16x2_AVX2 6
    pmovzxbw m%1, [r1+%5*FENC_STRIDE]
    pmovzxbw m%2, [r1+%6*FENC_STRIDE]
    pmovzxbw m%3, [r2+(%5-4)*FDEC_STRIDE]
    pmovzxbw m%4, [r2+(%6-4)*FDEC_STRIDE]
    psubw    m%1, m%3
    psubw    m%2, m%4
%endmacro

%macro DIFFx2 6-7
    movh       %3, %5
    punpcklbw  %3, %4
    psraw      %1, 6
    paddsw     %1, %3
    movh       %3, %6
    punpcklbw  %3, %4
    psraw      %2, 6
    paddsw     %2, %3
    packuswb   %2, %1
%endmacro

; (high depth) in: %1, %2, min to clip, max to clip, mem128
; in: %1, tmp, %3, mem64
%macro STORE_DIFF 4-5
%if HIGH_BIT_DEPTH
    psrad      %1, 6
    psrad      %2, 6
    packssdw   %1, %2
    paddw      %1, %5
    CLIPW      %1, %3, %4
    mova       %5, %1
%else
    movh       %2, %4
    punpcklbw  %2, %3
    psraw      %1, 6
    paddsw     %1, %2
    packuswb   %1, %1
    movh       %4, %1
%endif
%endmacro

%macro SHUFFLE_MASK_W 8
    %rep 8
        %if %1>=0x80
            db %1, %1
        %else
            db %1*2
            db %1*2+1
        %endif
        %rotate 1
    %endrep
%endmacro

; instruction, accum, input, iteration (zero to swap, nonzero to add)
%macro ACCUM 4
%if %4
    %1        m%2, m%3
%else
    SWAP       %2, %3
%endif
%endmacro
