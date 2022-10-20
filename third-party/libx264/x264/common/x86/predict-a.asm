;*****************************************************************************
;* predict-a.asm: x86 intra prediction
;*****************************************************************************
;* Copyright (C) 2005-2022 x264 project
;*
;* Authors: Loren Merritt <lorenm@u.washington.edu>
;*          Holger Lubitz <holger@lubitz.org>
;*          Fiona Glaser <fiona@x264.com>
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

SECTION_RODATA 32

pw_43210123: times 2 dw -3, -2, -1, 0, 1, 2, 3, 4
pw_m3:       times 16 dw -3
pw_m7:       times 16 dw -7
pb_00s_ff:   times 8 db 0
pb_0s_ff:    times 7 db 0
             db 0xff
shuf_fixtr:  db 0, 1, 2, 3, 4, 5, 6, 7, 7, 7, 7, 7, 7, 7, 7, 7
shuf_nop:    db 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
shuf_hu:     db 7,6,5,4,3,2,1,0,0,0,0,0,0,0,0,0
shuf_vr:     db 2,4,6,8,9,10,11,12,13,14,15,0,1,3,5,7
pw_reverse:  db 14,15,12,13,10,11,8,9,6,7,4,5,2,3,0,1

SECTION .text

cextern pb_0
cextern pb_1
cextern pb_3
cextern pw_1
cextern pw_2
cextern pw_4
cextern pw_8
cextern pw_16
cextern pw_00ff
cextern pw_pixel_max
cextern pw_0to15

%macro STORE8 1
    mova [r0+0*FDEC_STRIDEB], %1
    mova [r0+1*FDEC_STRIDEB], %1
    add  r0, 4*FDEC_STRIDEB
    mova [r0-2*FDEC_STRIDEB], %1
    mova [r0-1*FDEC_STRIDEB], %1
    mova [r0+0*FDEC_STRIDEB], %1
    mova [r0+1*FDEC_STRIDEB], %1
    mova [r0+2*FDEC_STRIDEB], %1
    mova [r0+3*FDEC_STRIDEB], %1
%endmacro

%macro STORE16 1-4
%if %0 > 1
    mov  r1d, 2*%0
.loop:
    mova [r0+0*FDEC_STRIDEB+0*mmsize], %1
    mova [r0+0*FDEC_STRIDEB+1*mmsize], %2
    mova [r0+1*FDEC_STRIDEB+0*mmsize], %1
    mova [r0+1*FDEC_STRIDEB+1*mmsize], %2
%ifidn %0, 4
    mova [r0+0*FDEC_STRIDEB+2*mmsize], %3
    mova [r0+0*FDEC_STRIDEB+3*mmsize], %4
    mova [r0+1*FDEC_STRIDEB+2*mmsize], %3
    mova [r0+1*FDEC_STRIDEB+3*mmsize], %4
    add  r0, 2*FDEC_STRIDEB
%else ; %0 == 2
    add  r0, 4*FDEC_STRIDEB
    mova [r0-2*FDEC_STRIDEB+0*mmsize], %1
    mova [r0-2*FDEC_STRIDEB+1*mmsize], %2
    mova [r0-1*FDEC_STRIDEB+0*mmsize], %1
    mova [r0-1*FDEC_STRIDEB+1*mmsize], %2
%endif
    dec  r1d
    jg .loop
%else ; %0 == 1
    STORE8 %1
%if HIGH_BIT_DEPTH ; Different code paths to reduce code size
    add  r0, 6*FDEC_STRIDEB
    mova [r0-2*FDEC_STRIDEB], %1
    mova [r0-1*FDEC_STRIDEB], %1
    mova [r0+0*FDEC_STRIDEB], %1
    mova [r0+1*FDEC_STRIDEB], %1
    add  r0, 4*FDEC_STRIDEB
    mova [r0-2*FDEC_STRIDEB], %1
    mova [r0-1*FDEC_STRIDEB], %1
    mova [r0+0*FDEC_STRIDEB], %1
    mova [r0+1*FDEC_STRIDEB], %1
%else
    add  r0, 8*FDEC_STRIDE
    mova [r0-4*FDEC_STRIDE], %1
    mova [r0-3*FDEC_STRIDE], %1
    mova [r0-2*FDEC_STRIDE], %1
    mova [r0-1*FDEC_STRIDE], %1
    mova [r0+0*FDEC_STRIDE], %1
    mova [r0+1*FDEC_STRIDE], %1
    mova [r0+2*FDEC_STRIDE], %1
    mova [r0+3*FDEC_STRIDE], %1
%endif ; HIGH_BIT_DEPTH
%endif
%endmacro

%macro PRED_H_LOAD 2 ; reg, offset
%if cpuflag(avx2)
    vpbroadcastpix %1, [r0+(%2)*FDEC_STRIDEB-SIZEOF_PIXEL]
%elif HIGH_BIT_DEPTH
    movd           %1, [r0+(%2)*FDEC_STRIDEB-4]
    SPLATW         %1, %1, 1
%else
    SPLATB_LOAD    %1, r0+(%2)*FDEC_STRIDE-1, m2
%endif
%endmacro

%macro PRED_H_STORE 3 ; reg, offset, width
%assign %%w %3*SIZEOF_PIXEL
%if %%w == 8
    movq [r0+(%2)*FDEC_STRIDEB], %1
%else
    %assign %%i 0
    %rep %%w/mmsize
        mova [r0+(%2)*FDEC_STRIDEB+%%i], %1
    %assign %%i %%i+mmsize
    %endrep
%endif
%endmacro

%macro PRED_H_4ROWS 2 ; width, inc_ptr
    PRED_H_LOAD  m0, 0
    PRED_H_LOAD  m1, 1
    PRED_H_STORE m0, 0, %1
    PRED_H_STORE m1, 1, %1
    PRED_H_LOAD  m0, 2
%if %2
    add          r0, 4*FDEC_STRIDEB
%endif
    PRED_H_LOAD  m1, 3-4*%2
    PRED_H_STORE m0, 2-4*%2, %1
    PRED_H_STORE m1, 3-4*%2, %1
%endmacro

; dest, left, right, src, tmp
; output: %1 = (t[n-1] + t[n]*2 + t[n+1] + 2) >> 2
%macro PRED8x8_LOWPASS 4-5
%if HIGH_BIT_DEPTH
    paddw       %2, %3
    psrlw       %2, 1
    pavgw       %1, %4, %2
%else
    mova        %5, %2
    pavgb       %2, %3
    pxor        %3, %5
    pand        %3, [pb_1]
    psubusb     %2, %3
    pavgb       %1, %4, %2
%endif
%endmacro

;-----------------------------------------------------------------------------
; void predict_4x4_h( pixel *src )
;-----------------------------------------------------------------------------
%if HIGH_BIT_DEPTH
INIT_XMM avx2
cglobal predict_4x4_h, 1,1
    PRED_H_4ROWS 4, 0
    RET
%endif

;-----------------------------------------------------------------------------
; void predict_4x4_ddl( pixel *src )
;-----------------------------------------------------------------------------
%macro PREDICT_4x4_DDL 0
cglobal predict_4x4_ddl, 1,1
    movu    m1, [r0-FDEC_STRIDEB]
    PSLLPIX m2, m1, 1
    mova    m0, m1
%if HIGH_BIT_DEPTH
    PSRLPIX m1, m1, 1
    pshufhw m1, m1, q2210
%else
    pxor    m1, m2
    PSRLPIX m1, m1, 1
    pxor    m1, m0
%endif
    PRED8x8_LOWPASS m0, m2, m1, m0, m3

%assign Y 0
%rep 4
    PSRLPIX m0, m0, 1
    movh   [r0+Y*FDEC_STRIDEB], m0
%assign Y (Y+1)
%endrep

    RET
%endmacro

%if HIGH_BIT_DEPTH
INIT_XMM sse2
PREDICT_4x4_DDL
INIT_XMM avx
PREDICT_4x4_DDL
INIT_MMX mmx2
cglobal predict_4x4_ddl, 1,2
    movu    m1, [r0-FDEC_STRIDEB+4]
    PRED8x8_LOWPASS m0, m1, [r0-FDEC_STRIDEB+0], [r0-FDEC_STRIDEB+2]
    mova    m3, [r0-FDEC_STRIDEB+8]
    mova    [r0+0*FDEC_STRIDEB], m0
    pshufw  m4, m3, q3321
    PRED8x8_LOWPASS m2, m4, [r0-FDEC_STRIDEB+6], m3
    mova    [r0+3*FDEC_STRIDEB], m2
    pshufw  m1, m0, q0021
    punpckldq m1, m2
    mova    [r0+1*FDEC_STRIDEB], m1
    psllq   m0, 16
    PALIGNR m2, m0, 6, m0
    mova    [r0+2*FDEC_STRIDEB], m2
    RET
%else ; !HIGH_BIT_DEPTH
INIT_MMX mmx2
PREDICT_4x4_DDL
%endif

;-----------------------------------------------------------------------------
; void predict_4x4_vr( pixel *src )
;-----------------------------------------------------------------------------
%if HIGH_BIT_DEPTH == 0
INIT_MMX ssse3
cglobal predict_4x4_vr, 1,1
    movd    m1, [r0-1*FDEC_STRIDEB]        ; ........t3t2t1t0
    mova    m4, m1
    palignr m1, [r0-1*FDEC_STRIDEB-8], 7   ; ......t3t2t1t0lt
    pavgb   m4, m1
    palignr m1, [r0+0*FDEC_STRIDEB-8], 7   ; ....t3t2t1t0ltl0
    mova    m0, m1
    palignr m1, [r0+1*FDEC_STRIDEB-8], 7   ; ..t3t2t1t0ltl0l1
    mova    m2, m1
    palignr m1, [r0+2*FDEC_STRIDEB-8], 7   ; t3t2t1t0ltl0l1l2
    PRED8x8_LOWPASS m2, m0, m1, m2, m3
    pshufw  m0, m2, 0
    psrlq   m2, 16
    movd    [r0+0*FDEC_STRIDEB], m4
    palignr m4, m0, 7
    movd    [r0+1*FDEC_STRIDEB], m2
    psllq   m0, 8
    movd    [r0+2*FDEC_STRIDEB], m4
    palignr m2, m0, 7
    movd    [r0+3*FDEC_STRIDEB], m2
    RET
%endif ; !HIGH_BIT_DEPTH

;-----------------------------------------------------------------------------
; void predict_4x4_ddr( pixel *src )
;-----------------------------------------------------------------------------
%macro PREDICT_4x4 4
cglobal predict_4x4_ddr, 1,1
%if HIGH_BIT_DEPTH
    movu      m2, [r0-1*FDEC_STRIDEB-8]
    pinsrw    m2, [r0+0*FDEC_STRIDEB-2], 2
    pinsrw    m2, [r0+1*FDEC_STRIDEB-2], 1
    pinsrw    m2, [r0+2*FDEC_STRIDEB-2], 0
    movhps    m3, [r0+3*FDEC_STRIDEB-8]
%else ; !HIGH_BIT_DEPTH
    movd      m0, [r0+2*FDEC_STRIDEB-4]
    movd      m1, [r0+0*FDEC_STRIDEB-4]
    punpcklbw m0, [r0+1*FDEC_STRIDEB-4]
    punpcklbw m1, [r0-1*FDEC_STRIDEB-4]
    punpckhwd m0, m1
    movd      m2, [r0-1*FDEC_STRIDEB]
%if cpuflag(ssse3)
    palignr   m2, m0, 4
%else
    psllq     m2, 32
    punpckhdq m0, m2
    SWAP       2, 0
%endif
    movd      m3, [r0+3*FDEC_STRIDEB-4]
    psllq     m3, 32
%endif ; !HIGH_BIT_DEPTH

    PSRLPIX   m1, m2, 1
    mova      m0, m2
    PALIGNR   m2, m3, 7*SIZEOF_PIXEL, m3
    PRED8x8_LOWPASS m0, m2, m1, m0, m3
%assign Y 3
    movh      [r0+Y*FDEC_STRIDEB], m0
%rep 3
%assign Y (Y-1)
    PSRLPIX   m0, m0, 1
    movh      [r0+Y*FDEC_STRIDEB], m0
%endrep
    RET

;-----------------------------------------------------------------------------
; void predict_4x4_vr( pixel *src )
;-----------------------------------------------------------------------------
cglobal predict_4x4_vr, 1,1
%if HIGH_BIT_DEPTH
    movu      m1, [r0-1*FDEC_STRIDEB-8]
    pinsrw    m1, [r0+0*FDEC_STRIDEB-2], 2
    pinsrw    m1, [r0+1*FDEC_STRIDEB-2], 1
    pinsrw    m1, [r0+2*FDEC_STRIDEB-2], 0
%else ; !HIGH_BIT_DEPTH
    movd      m0, [r0+2*FDEC_STRIDEB-4]
    movd      m1, [r0+0*FDEC_STRIDEB-4]
    punpcklbw m0, [r0+1*FDEC_STRIDEB-4]
    punpcklbw m1, [r0-1*FDEC_STRIDEB-4]
    punpckhwd m0, m1
    movd      m1, [r0-1*FDEC_STRIDEB]
%if cpuflag(ssse3)
    palignr   m1, m0, 4
%else
    psllq     m1, 32
    punpckhdq m0, m1
    SWAP       1, 0
%endif
%endif ; !HIGH_BIT_DEPTH
    PSRLPIX   m2, m1, 1
    PSRLPIX   m0, m1, 2
    pavg%1    m4, m1, m2
    PSRLPIX   m4, m4, 3
    PRED8x8_LOWPASS m2, m0, m1, m2, m3
    PSLLPIX   m0, m2, 6
    PSRLPIX   m2, m2, 2
    movh      [r0+0*FDEC_STRIDEB], m4
    PALIGNR   m4, m0, 7*SIZEOF_PIXEL, m3
    movh      [r0+1*FDEC_STRIDEB], m2
    PSLLPIX   m0, m0, 1
    movh      [r0+2*FDEC_STRIDEB], m4
    PALIGNR   m2, m0, 7*SIZEOF_PIXEL, m0
    movh      [r0+3*FDEC_STRIDEB], m2
    RET

;-----------------------------------------------------------------------------
; void predict_4x4_hd( pixel *src )
;-----------------------------------------------------------------------------
cglobal predict_4x4_hd, 1,1
%if HIGH_BIT_DEPTH
    movu      m1, [r0-1*FDEC_STRIDEB-8]
    PSLLPIX   m1, m1, 1
    pinsrw    m1, [r0+0*FDEC_STRIDEB-2], 3
    pinsrw    m1, [r0+1*FDEC_STRIDEB-2], 2
    pinsrw    m1, [r0+2*FDEC_STRIDEB-2], 1
    pinsrw    m1, [r0+3*FDEC_STRIDEB-2], 0
%else
    movd      m0, [r0-1*FDEC_STRIDEB-4] ; lt ..
    punpckldq m0, [r0-1*FDEC_STRIDEB]   ; t3 t2 t1 t0 lt .. .. ..
    PSLLPIX   m0, m0, 1                 ; t2 t1 t0 lt .. .. .. ..
    movd      m1, [r0+3*FDEC_STRIDEB-4] ; l3
    punpcklbw m1, [r0+2*FDEC_STRIDEB-4] ; l2 l3
    movd      m2, [r0+1*FDEC_STRIDEB-4] ; l1
    punpcklbw m2, [r0+0*FDEC_STRIDEB-4] ; l0 l1
    punpckh%3 m1, m2                    ; l0 l1 l2 l3
    punpckh%4 m1, m0                    ; t2 t1 t0 lt l0 l1 l2 l3
%endif
    PSRLPIX   m2, m1, 1                 ; .. t2 t1 t0 lt l0 l1 l2
    PSRLPIX   m0, m1, 2                 ; .. .. t2 t1 t0 lt l0 l1
    pavg%1    m5, m1, m2
    PRED8x8_LOWPASS m3, m1, m0, m2, m4
    punpckl%2 m5, m3
    PSRLPIX   m3, m3, 4
    PALIGNR   m3, m5, 6*SIZEOF_PIXEL, m4
%assign Y 3
    movh      [r0+Y*FDEC_STRIDEB], m5
%rep 2
%assign Y (Y-1)
    PSRLPIX   m5, m5, 2
    movh      [r0+Y*FDEC_STRIDEB], m5
%endrep
    movh      [r0+0*FDEC_STRIDEB], m3
    RET
%endmacro ; PREDICT_4x4

;-----------------------------------------------------------------------------
; void predict_4x4_ddr( pixel *src )
;-----------------------------------------------------------------------------
%if HIGH_BIT_DEPTH
INIT_MMX mmx2
cglobal predict_4x4_ddr, 1,1
    mova      m0, [r0+1*FDEC_STRIDEB-8]
    punpckhwd m0, [r0+0*FDEC_STRIDEB-8]
    mova      m3, [r0+3*FDEC_STRIDEB-8]
    punpckhwd m3, [r0+2*FDEC_STRIDEB-8]
    punpckhdq m3, m0

    pshufw  m0, m3, q3321
    pinsrw  m0, [r0-1*FDEC_STRIDEB-2], 3
    pshufw  m1, m0, q3321
    PRED8x8_LOWPASS m0, m1, m3, m0
    movq    [r0+3*FDEC_STRIDEB], m0

    movq    m2, [r0-1*FDEC_STRIDEB-0]
    pshufw  m4, m2, q2100
    pinsrw  m4, [r0-1*FDEC_STRIDEB-2], 0
    movq    m1, m4
    PALIGNR m4, m3, 6, m3
    PRED8x8_LOWPASS m1, m4, m2, m1
    movq    [r0+0*FDEC_STRIDEB], m1

    pshufw  m2, m0, q3321
    punpckldq m2, m1
    psllq   m0, 16
    PALIGNR m1, m0, 6, m0
    movq    [r0+1*FDEC_STRIDEB], m1
    movq    [r0+2*FDEC_STRIDEB], m2
    movd    [r0+3*FDEC_STRIDEB+4], m1
    RET

;-----------------------------------------------------------------------------
; void predict_4x4_hd( pixel *src )
;-----------------------------------------------------------------------------
cglobal predict_4x4_hd, 1,1
    mova      m0, [r0+1*FDEC_STRIDEB-8]
    punpckhwd m0, [r0+0*FDEC_STRIDEB-8]
    mova      m1, [r0+3*FDEC_STRIDEB-8]
    punpckhwd m1, [r0+2*FDEC_STRIDEB-8]
    punpckhdq m1, m0
    mova      m0, m1

    movu      m3, [r0-1*FDEC_STRIDEB-2]
    pshufw    m4, m1, q0032
    mova      m7, m3
    punpckldq m4, m3
    PALIGNR   m3, m1, 2, m2
    PRED8x8_LOWPASS m2, m4, m1, m3

    pavgw     m0, m3
    punpcklwd m5, m0, m2
    punpckhwd m4, m0, m2
    mova      [r0+3*FDEC_STRIDEB], m5
    mova      [r0+1*FDEC_STRIDEB], m4
    psrlq     m5, 32
    punpckldq m5, m4
    mova      [r0+2*FDEC_STRIDEB], m5

    pshufw    m4, m7, q2100
    mova      m6, [r0-1*FDEC_STRIDEB+0]
    pinsrw    m4, [r0+0*FDEC_STRIDEB-2], 0
    PRED8x8_LOWPASS m3, m4, m6, m7
    PALIGNR   m3, m0, 6, m0
    mova      [r0+0*FDEC_STRIDEB], m3
    RET

INIT_XMM sse2
PREDICT_4x4 w, wd, dq, qdq
INIT_XMM ssse3
PREDICT_4x4 w, wd, dq, qdq
INIT_XMM avx
PREDICT_4x4 w, wd, dq, qdq
%else ; !HIGH_BIT_DEPTH
INIT_MMX mmx2
PREDICT_4x4 b, bw, wd, dq
INIT_MMX ssse3
%define predict_4x4_vr_ssse3 predict_4x4_vr_cache64_ssse3
PREDICT_4x4 b, bw, wd, dq
%endif

;-----------------------------------------------------------------------------
; void predict_4x4_hu( pixel *src )
;-----------------------------------------------------------------------------
%if HIGH_BIT_DEPTH
INIT_MMX
cglobal predict_4x4_hu_mmx2, 1,1
    movq      m0, [r0+0*FDEC_STRIDEB-8]
    punpckhwd m0, [r0+1*FDEC_STRIDEB-8]
    movq      m1, [r0+2*FDEC_STRIDEB-8]
    punpckhwd m1, [r0+3*FDEC_STRIDEB-8]
    punpckhdq m0, m1
    pshufw    m1, m1, q3333
    movq      [r0+3*FDEC_STRIDEB], m1
    pshufw    m3, m0, q3321
    pshufw    m4, m0, q3332
    pavgw     m2, m0, m3
    PRED8x8_LOWPASS m3, m0, m4, m3
    punpcklwd m4, m2, m3
    mova      [r0+0*FDEC_STRIDEB], m4
    psrlq     m2, 16
    psrlq     m3, 16
    punpcklwd m2, m3
    mova      [r0+1*FDEC_STRIDEB], m2
    punpckhdq m2, m1
    mova      [r0+2*FDEC_STRIDEB], m2
    RET

%else ; !HIGH_BIT_DEPTH
INIT_MMX
cglobal predict_4x4_hu_mmx2, 1,1
    movd      m1, [r0+0*FDEC_STRIDEB-4]
    punpcklbw m1, [r0+1*FDEC_STRIDEB-4]
    movd      m0, [r0+2*FDEC_STRIDEB-4]
    punpcklbw m0, [r0+3*FDEC_STRIDEB-4]
    punpckhwd m1, m0
    movq      m0, m1
    punpckhbw m1, m1
    pshufw    m1, m1, q3333
    punpckhdq m0, m1
    movq      m2, m0
    movq      m3, m0
    movq      m5, m0
    psrlq     m3, 8
    psrlq     m2, 16
    pavgb     m5, m3
    PRED8x8_LOWPASS m3, m0, m2, m3, m4
    movd      [r0+3*FDEC_STRIDEB], m1
    punpcklbw m5, m3
    movd      [r0+0*FDEC_STRIDEB], m5
    psrlq     m5, 16
    movd      [r0+1*FDEC_STRIDEB], m5
    psrlq     m5, 16
    movd      [r0+2*FDEC_STRIDEB], m5
    RET
%endif ; HIGH_BIT_DEPTH

;-----------------------------------------------------------------------------
; void predict_4x4_vl( pixel *src )
;-----------------------------------------------------------------------------
%macro PREDICT_4x4_V1 1
cglobal predict_4x4_vl, 1,1
    movu        m1, [r0-FDEC_STRIDEB]
    PSRLPIX     m3, m1, 1
    PSRLPIX     m2, m1, 2
    pavg%1      m4, m3, m1
    PRED8x8_LOWPASS m0, m1, m2, m3, m5

    movh        [r0+0*FDEC_STRIDEB], m4
    movh        [r0+1*FDEC_STRIDEB], m0
    PSRLPIX     m4, m4, 1
    PSRLPIX     m0, m0, 1
    movh        [r0+2*FDEC_STRIDEB], m4
    movh        [r0+3*FDEC_STRIDEB], m0
    RET
%endmacro

%if HIGH_BIT_DEPTH
INIT_XMM sse2
PREDICT_4x4_V1 w
INIT_XMM avx
PREDICT_4x4_V1 w

INIT_MMX mmx2
cglobal predict_4x4_vl, 1,4
    mova    m1, [r0-FDEC_STRIDEB+0]
    mova    m2, [r0-FDEC_STRIDEB+8]
    mova    m0, m2
    PALIGNR m2, m1, 4, m4
    PALIGNR m0, m1, 2, m4
    mova    m3, m0
    pavgw   m3, m1
    mova    [r0+0*FDEC_STRIDEB], m3
    psrlq   m3, 16
    mova    [r0+2*FDEC_STRIDEB], m3
    PRED8x8_LOWPASS m0, m1, m2, m0
    mova    [r0+1*FDEC_STRIDEB], m0
    psrlq   m0, 16
    mova    [r0+3*FDEC_STRIDEB], m0

    movzx   r1d, word [r0-FDEC_STRIDEB+ 8]
    movzx   r2d, word [r0-FDEC_STRIDEB+10]
    movzx   r3d, word [r0-FDEC_STRIDEB+12]
    lea     r1d, [r1+r2+1]
    add     r3d, r2d
    lea     r3d, [r3+r1+1]
    shr     r1d, 1
    shr     r3d, 2
    mov     [r0+2*FDEC_STRIDEB+6], r1w
    mov     [r0+3*FDEC_STRIDEB+6], r3w
    RET
%else ; !HIGH_BIT_DEPTH
INIT_MMX mmx2
PREDICT_4x4_V1 b
%endif

;-----------------------------------------------------------------------------
; void predict_4x4_dc( pixel *src )
;-----------------------------------------------------------------------------
INIT_MMX mmx2
%if HIGH_BIT_DEPTH
cglobal predict_4x4_dc, 1,1
    mova   m2, [r0+0*FDEC_STRIDEB-4*SIZEOF_PIXEL]
    paddw  m2, [r0+1*FDEC_STRIDEB-4*SIZEOF_PIXEL]
    paddw  m2, [r0+2*FDEC_STRIDEB-4*SIZEOF_PIXEL]
    paddw  m2, [r0+3*FDEC_STRIDEB-4*SIZEOF_PIXEL]
    psrlq  m2, 48
    mova   m0, [r0-FDEC_STRIDEB]
    HADDW  m0, m1
    paddw  m0, [pw_4]
    paddw  m0, m2
    psrlw  m0, 3
    SPLATW m0, m0
    mova   [r0+0*FDEC_STRIDEB], m0
    mova   [r0+1*FDEC_STRIDEB], m0
    mova   [r0+2*FDEC_STRIDEB], m0
    mova   [r0+3*FDEC_STRIDEB], m0
    RET

%else ; !HIGH_BIT_DEPTH
cglobal predict_4x4_dc, 1,4
    pxor   mm7, mm7
    movd   mm0, [r0-FDEC_STRIDEB]
    psadbw mm0, mm7
    movd   r3d, mm0
    movzx  r1d, byte [r0-1]
%assign Y 1
%rep 3
    movzx  r2d, byte [r0+FDEC_STRIDEB*Y-1]
    add    r1d, r2d
%assign Y Y+1
%endrep
    lea    r1d, [r1+r3+4]
    shr    r1d, 3
    imul   r1d, 0x01010101
    mov   [r0+FDEC_STRIDEB*0], r1d
    mov   [r0+FDEC_STRIDEB*1], r1d
    mov   [r0+FDEC_STRIDEB*2], r1d
    mov   [r0+FDEC_STRIDEB*3], r1d
    RET
%endif ; HIGH_BIT_DEPTH

%macro PREDICT_FILTER 4
;-----------------------------------------------------------------------------
;void predict_8x8_filter( pixel *src, pixel edge[36], int i_neighbor, int i_filters )
;-----------------------------------------------------------------------------
cglobal predict_8x8_filter, 4,6,6
    add          r0, 0x58*SIZEOF_PIXEL
%define src r0-0x58*SIZEOF_PIXEL
%if ARCH_X86_64 == 0
    mov          r4, r1
%define t1 r4
%define t4 r1
%else
%define t1 r1
%define t4 r4
%endif
    test       r3b, 1
    je .check_top
    mov        t4d, r2d
    and        t4d, 8
    neg         t4
    mova        m0, [src+0*FDEC_STRIDEB-8*SIZEOF_PIXEL]
    punpckh%1%2 m0, [src+0*FDEC_STRIDEB-8*SIZEOF_PIXEL+t4*(FDEC_STRIDEB/8)]
    mova        m1, [src+2*FDEC_STRIDEB-8*SIZEOF_PIXEL]
    punpckh%1%2 m1, [src+1*FDEC_STRIDEB-8*SIZEOF_PIXEL]
    punpckh%2%3 m1, m0
    mova        m2, [src+4*FDEC_STRIDEB-8*SIZEOF_PIXEL]
    punpckh%1%2 m2, [src+3*FDEC_STRIDEB-8*SIZEOF_PIXEL]
    mova        m3, [src+6*FDEC_STRIDEB-8*SIZEOF_PIXEL]
    punpckh%1%2 m3, [src+5*FDEC_STRIDEB-8*SIZEOF_PIXEL]
    punpckh%2%3 m3, m2
    punpckh%3%4 m3, m1
    mova        m0, [src+7*FDEC_STRIDEB-8*SIZEOF_PIXEL]
    mova        m1, [src-1*FDEC_STRIDEB]
    PALIGNR     m4, m3, m0, 7*SIZEOF_PIXEL, m0
    PALIGNR     m1, m1, m3, 1*SIZEOF_PIXEL, m2
    PRED8x8_LOWPASS m3, m1, m4, m3, m5
    mova        [t1+8*SIZEOF_PIXEL], m3
    movzx      t4d, pixel [src+7*FDEC_STRIDEB-1*SIZEOF_PIXEL]
    movzx      r5d, pixel [src+6*FDEC_STRIDEB-1*SIZEOF_PIXEL]
    lea        t4d, [t4*3+2]
    add        t4d, r5d
    shr        t4d, 2
    mov         [t1+7*SIZEOF_PIXEL], t4%1
    mov         [t1+6*SIZEOF_PIXEL], t4%1
    test       r3b, 2
    je .done
.check_top:
%if SIZEOF_PIXEL==1 && cpuflag(ssse3)
INIT_XMM cpuname
    movu        m3, [src-1*FDEC_STRIDEB]
    movhps      m0, [src-1*FDEC_STRIDEB-8]
    test       r2b, 8
    je .fix_lt_2
.do_top:
    and        r2d, 4
%if ARCH_X86_64
    lea         r3, [shuf_fixtr]
    pshufb      m3, [r3+r2*4]
%else
    pshufb      m3, [shuf_fixtr+r2*4] ; neighbor&MB_TOPRIGHT ? shuf_nop : shuf_fixtr
%endif
    psrldq      m1, m3, 15
    PALIGNR     m2, m3, m0, 15, m0
    PALIGNR     m1, m3, 1, m5
    PRED8x8_LOWPASS m0, m2, m1, m3, m5
    mova        [t1+16*SIZEOF_PIXEL], m0
    psrldq      m0, 15
    movd        [t1+32*SIZEOF_PIXEL], m0
.done:
    REP_RET
.fix_lt_2:
    pslldq      m0, m3, 15
    jmp .do_top

%else
    mova        m0, [src-1*FDEC_STRIDEB-8*SIZEOF_PIXEL]
    mova        m3, [src-1*FDEC_STRIDEB]
    mova        m1, [src-1*FDEC_STRIDEB+8*SIZEOF_PIXEL]
    test       r2b, 8
    je .fix_lt_2
    test       r2b, 4
    je .fix_tr_1
.do_top:
    PALIGNR     m2, m3, m0, 7*SIZEOF_PIXEL, m0
    PALIGNR     m0, m1, m3, 1*SIZEOF_PIXEL, m5
    PRED8x8_LOWPASS m4, m2, m0, m3, m5
    mova        [t1+16*SIZEOF_PIXEL], m4
    test       r3b, 4
    je .done
    PSRLPIX     m5, m1, 7
    PALIGNR     m2, m1, m3, 7*SIZEOF_PIXEL, m3
    PALIGNR     m5, m1, 1*SIZEOF_PIXEL, m4
    PRED8x8_LOWPASS m0, m2, m5, m1, m4
    mova        [t1+24*SIZEOF_PIXEL], m0
    PSRLPIX     m0, m0, 7
    movd        [t1+32*SIZEOF_PIXEL], m0
.done:
    REP_RET
.fix_lt_2:
    PSLLPIX     m0, m3, 7
    test       r2b, 4
    jne .do_top
.fix_tr_1:
    punpckh%1%2 m1, m3, m3
    pshuf%2     m1, m1, q3333
    jmp .do_top
%endif
%endmacro

%if HIGH_BIT_DEPTH
INIT_XMM sse2
PREDICT_FILTER w, d, q, dq
INIT_XMM ssse3
PREDICT_FILTER w, d, q, dq
INIT_XMM avx
PREDICT_FILTER w, d, q, dq
%else
INIT_MMX mmx2
PREDICT_FILTER b, w, d, q
INIT_MMX ssse3
PREDICT_FILTER b, w, d, q
%endif

;-----------------------------------------------------------------------------
; void predict_8x8_v( pixel *src, pixel *edge )
;-----------------------------------------------------------------------------
%macro PREDICT_8x8_V 0
cglobal predict_8x8_v, 2,2
    mova        m0, [r1+16*SIZEOF_PIXEL]
    STORE8      m0
    RET
%endmacro

%if HIGH_BIT_DEPTH
INIT_XMM sse
PREDICT_8x8_V
%else
INIT_MMX mmx2
PREDICT_8x8_V
%endif

;-----------------------------------------------------------------------------
; void predict_8x8_h( pixel *src, pixel edge[36] )
;-----------------------------------------------------------------------------
%macro PREDICT_8x8_H 2
cglobal predict_8x8_h, 2,2
    movu      m1, [r1+7*SIZEOF_PIXEL]
    add       r0, 4*FDEC_STRIDEB
    punpckl%1 m2, m1, m1
    punpckh%1 m1, m1
%assign Y 0
%rep 8
%assign i 1+Y/4
    SPLAT%2 m0, m %+ i, (3-Y)&3
    mova [r0+(Y-4)*FDEC_STRIDEB], m0
%assign Y Y+1
%endrep
    RET
%endmacro

%if HIGH_BIT_DEPTH
INIT_XMM sse2
PREDICT_8x8_H wd, D
%else
INIT_MMX mmx2
PREDICT_8x8_H bw, W
%endif

;-----------------------------------------------------------------------------
; void predict_8x8_dc( pixel *src, pixel *edge );
;-----------------------------------------------------------------------------
%if HIGH_BIT_DEPTH
INIT_XMM sse2
cglobal predict_8x8_dc, 2,2
    movu        m0, [r1+14]
    paddw       m0, [r1+32]
    HADDW       m0, m1
    paddw       m0, [pw_8]
    psrlw       m0, 4
    SPLATW      m0, m0
    STORE8      m0
    RET

%else ; !HIGH_BIT_DEPTH
INIT_MMX mmx2
cglobal predict_8x8_dc, 2,2
    pxor        mm0, mm0
    pxor        mm1, mm1
    psadbw      mm0, [r1+7]
    psadbw      mm1, [r1+16]
    paddw       mm0, [pw_8]
    paddw       mm0, mm1
    psrlw       mm0, 4
    pshufw      mm0, mm0, 0
    packuswb    mm0, mm0
    STORE8      mm0
    RET
%endif ; HIGH_BIT_DEPTH

;-----------------------------------------------------------------------------
; void predict_8x8_dc_top ( pixel *src, pixel *edge );
; void predict_8x8_dc_left( pixel *src, pixel *edge );
;-----------------------------------------------------------------------------
%if HIGH_BIT_DEPTH
%macro PREDICT_8x8_DC 3
cglobal %1, 2,2
    %3          m0, [r1+%2]
    HADDW       m0, m1
    paddw       m0, [pw_4]
    psrlw       m0, 3
    SPLATW      m0, m0
    STORE8      m0
    RET
%endmacro
INIT_XMM sse2
PREDICT_8x8_DC predict_8x8_dc_top , 32, mova
PREDICT_8x8_DC predict_8x8_dc_left, 14, movu

%else ; !HIGH_BIT_DEPTH
%macro PREDICT_8x8_DC 2
cglobal %1, 2,2
    pxor        mm0, mm0
    psadbw      mm0, [r1+%2]
    paddw       mm0, [pw_4]
    psrlw       mm0, 3
    pshufw      mm0, mm0, 0
    packuswb    mm0, mm0
    STORE8      mm0
    RET
%endmacro
INIT_MMX
PREDICT_8x8_DC predict_8x8_dc_top_mmx2, 16
PREDICT_8x8_DC predict_8x8_dc_left_mmx2, 7
%endif ; HIGH_BIT_DEPTH

; sse2 is faster even on amd for 8-bit, so there's no sense in spending exe
; size on the 8-bit mmx functions below if we know sse2 is available.
%macro PREDICT_8x8_DDLR 0
;-----------------------------------------------------------------------------
; void predict_8x8_ddl( pixel *src, pixel *edge )
;-----------------------------------------------------------------------------
cglobal predict_8x8_ddl, 2,2,7
    mova        m0, [r1+16*SIZEOF_PIXEL]
    mova        m1, [r1+24*SIZEOF_PIXEL]
%if cpuflag(cache64)
    movd        m5, [r1+32*SIZEOF_PIXEL]
    palignr     m3, m1, m0, 1*SIZEOF_PIXEL
    palignr     m5, m5, m1, 1*SIZEOF_PIXEL
    palignr     m4, m1, m0, 7*SIZEOF_PIXEL
%else
    movu        m3, [r1+17*SIZEOF_PIXEL]
    movu        m4, [r1+23*SIZEOF_PIXEL]
    movu        m5, [r1+25*SIZEOF_PIXEL]
%endif
    PSLLPIX     m2, m0, 1
    add         r0, FDEC_STRIDEB*4
    PRED8x8_LOWPASS m0, m2, m3, m0, m6
    PRED8x8_LOWPASS m1, m4, m5, m1, m6
    mova        [r0+3*FDEC_STRIDEB], m1
%assign Y 2
%rep 6
    PALIGNR     m1, m0, 7*SIZEOF_PIXEL, m2
    PSLLPIX     m0, m0, 1
    mova        [r0+Y*FDEC_STRIDEB], m1
%assign Y (Y-1)
%endrep
    PALIGNR     m1, m0, 7*SIZEOF_PIXEL, m0
    mova        [r0+Y*FDEC_STRIDEB], m1
    RET

;-----------------------------------------------------------------------------
; void predict_8x8_ddr( pixel *src, pixel *edge )
;-----------------------------------------------------------------------------
cglobal predict_8x8_ddr, 2,2,7
    add         r0, FDEC_STRIDEB*4
    mova        m0, [r1+ 8*SIZEOF_PIXEL]
    mova        m1, [r1+16*SIZEOF_PIXEL]
    ; edge[] is 32byte aligned, so some of the unaligned loads are known to be not cachesplit
    movu        m2, [r1+ 7*SIZEOF_PIXEL]
    movu        m5, [r1+17*SIZEOF_PIXEL]
%if cpuflag(cache64)
    palignr     m3, m1, m0, 1*SIZEOF_PIXEL
    palignr     m4, m1, m0, 7*SIZEOF_PIXEL
%else
    movu        m3, [r1+ 9*SIZEOF_PIXEL]
    movu        m4, [r1+15*SIZEOF_PIXEL]
%endif
    PRED8x8_LOWPASS m0, m2, m3, m0, m6
    PRED8x8_LOWPASS m1, m4, m5, m1, m6
    mova        [r0+3*FDEC_STRIDEB], m0
%assign Y -4
%rep 6
    PALIGNR     m1, m0, 7*SIZEOF_PIXEL, m2
    PSLLPIX     m0, m0, 1
    mova        [r0+Y*FDEC_STRIDEB], m1
%assign Y (Y+1)
%endrep
    PALIGNR     m1, m0, 7*SIZEOF_PIXEL, m0
    mova        [r0+Y*FDEC_STRIDEB], m1
    RET
%endmacro ; PREDICT_8x8_DDLR

%if HIGH_BIT_DEPTH
INIT_XMM sse2
PREDICT_8x8_DDLR
INIT_XMM ssse3
PREDICT_8x8_DDLR
INIT_XMM cache64, ssse3
PREDICT_8x8_DDLR
%elif ARCH_X86_64 == 0
INIT_MMX mmx2
PREDICT_8x8_DDLR
%endif

;-----------------------------------------------------------------------------
; void predict_8x8_hu( pixel *src, pixel *edge )
;-----------------------------------------------------------------------------
%macro PREDICT_8x8_HU 2
cglobal predict_8x8_hu, 2,2,8
    add       r0, 4*FDEC_STRIDEB
%if HIGH_BIT_DEPTH
%if cpuflag(ssse3)
    movu      m5, [r1+7*SIZEOF_PIXEL]
    pshufb    m5, [pw_reverse]
%else
    movq      m6, [r1+7*SIZEOF_PIXEL]
    movq      m5, [r1+11*SIZEOF_PIXEL]
    pshuflw   m6, m6, q0123
    pshuflw   m5, m5, q0123
    movlhps   m5, m6
%endif ; cpuflag
    psrldq    m2, m5, 2
    pshufd    m3, m5, q0321
    pshufhw   m2, m2, q2210
    pshufhw   m3, m3, q1110
    pavgw     m4, m5, m2
%else ; !HIGH_BIT_DEPTH
    movu      m1, [r1+7*SIZEOF_PIXEL] ; l0 l1 l2 l3 l4 l5 l6 l7
    pshufw    m0, m1, q0123           ; l6 l7 l4 l5 l2 l3 l0 l1
    psllq     m1, 56                  ; l7 .. .. .. .. .. .. ..
    mova      m2, m0
    psllw     m0, 8
    psrlw     m2, 8
    por       m2, m0
    mova      m3, m2
    mova      m4, m2
    mova      m5, m2                  ; l7 l6 l5 l4 l3 l2 l1 l0
    psrlq     m3, 16
    psrlq     m2, 8
    por       m2, m1                  ; l7 l7 l6 l5 l4 l3 l2 l1
    punpckhbw m1, m1
    por       m3, m1                  ; l7 l7 l7 l6 l5 l4 l3 l2
    pavgb     m4, m2
%endif ; !HIGH_BIT_DEPTH
    PRED8x8_LOWPASS m2, m3, m5, m2, m6
    punpckh%2 m0, m4, m2              ; p8 p7 p6 p5
    punpckl%2 m4, m2                  ; p4 p3 p2 p1
    PALIGNR   m5, m0, m4, 2*SIZEOF_PIXEL, m3
    pshuf%1   m1, m0, q3321
    PALIGNR   m6, m0, m4, 4*SIZEOF_PIXEL, m3
    pshuf%1   m2, m0, q3332
    PALIGNR   m7, m0, m4, 6*SIZEOF_PIXEL, m3
    pshuf%1   m3, m0, q3333
    mova      [r0-4*FDEC_STRIDEB], m4
    mova      [r0-3*FDEC_STRIDEB], m5
    mova      [r0-2*FDEC_STRIDEB], m6
    mova      [r0-1*FDEC_STRIDEB], m7
    mova      [r0+0*FDEC_STRIDEB], m0
    mova      [r0+1*FDEC_STRIDEB], m1
    mova      [r0+2*FDEC_STRIDEB], m2
    mova      [r0+3*FDEC_STRIDEB], m3
    RET
%endmacro

%if HIGH_BIT_DEPTH
INIT_XMM sse2
PREDICT_8x8_HU d, wd
INIT_XMM ssse3
PREDICT_8x8_HU d, wd
INIT_XMM avx
PREDICT_8x8_HU d, wd
%elif ARCH_X86_64 == 0
INIT_MMX mmx2
PREDICT_8x8_HU w, bw
%endif

;-----------------------------------------------------------------------------
; void predict_8x8_vr( pixel *src, pixel *edge )
;-----------------------------------------------------------------------------
%macro PREDICT_8x8_VR 1
cglobal predict_8x8_vr, 2,3
    mova        m2, [r1+16*SIZEOF_PIXEL]
%ifidn cpuname, ssse3
    mova        m0, [r1+8*SIZEOF_PIXEL]
    palignr     m3, m2, m0, 7*SIZEOF_PIXEL
    palignr     m1, m2, m0, 6*SIZEOF_PIXEL
%else
    movu        m3, [r1+15*SIZEOF_PIXEL]
    movu        m1, [r1+14*SIZEOF_PIXEL]
%endif
    pavg%1      m4, m3, m2
    add         r0, FDEC_STRIDEB*4
    PRED8x8_LOWPASS m3, m1, m2, m3, m5
    mova        [r0-4*FDEC_STRIDEB], m4
    mova        [r0-3*FDEC_STRIDEB], m3
    mova        m1, [r1+8*SIZEOF_PIXEL]
    PSLLPIX     m0, m1, 1
    PSLLPIX     m2, m1, 2
    PRED8x8_LOWPASS m0, m1, m2, m0, m6

%assign Y -2
%rep 5
    PALIGNR     m4, m0, 7*SIZEOF_PIXEL, m5
    mova        [r0+Y*FDEC_STRIDEB], m4
    PSLLPIX     m0, m0, 1
    SWAP 3, 4
%assign Y (Y+1)
%endrep
    PALIGNR     m4, m0, 7*SIZEOF_PIXEL, m0
    mova        [r0+Y*FDEC_STRIDEB], m4
    RET
%endmacro

%if HIGH_BIT_DEPTH
INIT_XMM sse2
PREDICT_8x8_VR w
INIT_XMM ssse3
PREDICT_8x8_VR w
INIT_XMM avx
PREDICT_8x8_VR w
%elif ARCH_X86_64 == 0
INIT_MMX mmx2
PREDICT_8x8_VR b
%endif

%macro LOAD_PLANE_ARGS 0
%if cpuflag(avx2) && ARCH_X86_64 == 0
    vpbroadcastw m0, r1m
    vpbroadcastw m2, r2m
    vpbroadcastw m4, r3m
%elif mmsize == 8 ; MMX is only used on x86_32
    SPLATW       m0, r1m
    SPLATW       m2, r2m
    SPLATW       m4, r3m
%else
    movd        xm0, r1m
    movd        xm2, r2m
    movd        xm4, r3m
    SPLATW       m0, xm0
    SPLATW       m2, xm2
    SPLATW       m4, xm4
%endif
%endmacro

;-----------------------------------------------------------------------------
; void predict_8x8c_p_core( uint8_t *src, int i00, int b, int c )
;-----------------------------------------------------------------------------
%if ARCH_X86_64 == 0 && HIGH_BIT_DEPTH == 0
%macro PREDICT_CHROMA_P_MMX 1
cglobal predict_8x%1c_p_core, 1,2
    LOAD_PLANE_ARGS
    movq        m1, m2
    pmullw      m2, [pw_0to15]
    psllw       m1, 2
    paddsw      m0, m2        ; m0 = {i+0*b, i+1*b, i+2*b, i+3*b}
    paddsw      m1, m0        ; m1 = {i+4*b, i+5*b, i+6*b, i+7*b}
    mov         r1d, %1
ALIGN 4
.loop:
    movq        m5, m0
    movq        m6, m1
    psraw       m5, 5
    psraw       m6, 5
    packuswb    m5, m6
    movq        [r0], m5

    paddsw      m0, m4
    paddsw      m1, m4
    add         r0, FDEC_STRIDE
    dec         r1d
    jg .loop
    RET
%endmacro ; PREDICT_CHROMA_P_MMX

INIT_MMX mmx2
PREDICT_CHROMA_P_MMX 8
PREDICT_CHROMA_P_MMX 16
%endif ; !ARCH_X86_64 && !HIGH_BIT_DEPTH

%macro PREDICT_CHROMA_P 1
%if HIGH_BIT_DEPTH
cglobal predict_8x%1c_p_core, 1,2,7
    LOAD_PLANE_ARGS
    mova        m3, [pw_pixel_max]
    pxor        m1, m1
    pmullw      m2, [pw_43210123] ; b
%if %1 == 16
    pmullw      m5, m4, [pw_m7]   ; c
%else
    pmullw      m5, m4, [pw_m3]
%endif
    paddw       m5, [pw_16]
%if mmsize == 32
    mova       xm6, xm4
    paddw       m4, m4
    paddw       m5, m6
%endif
    mov        r1d, %1/(mmsize/16)
.loop:
    paddsw      m6, m2, m5
    paddsw      m6, m0
    psraw       m6, 5
    CLIPW       m6, m1, m3
    paddw       m5, m4
%if mmsize == 32
    vextracti128 [r0], m6, 1
    mova [r0+FDEC_STRIDEB], xm6
    add         r0, 2*FDEC_STRIDEB
%else
    mova      [r0], m6
    add         r0, FDEC_STRIDEB
%endif
    dec        r1d
    jg .loop
    RET
%else ; !HIGH_BIT_DEPTH
cglobal predict_8x%1c_p_core, 1,2
    LOAD_PLANE_ARGS
%if mmsize == 32
    vbroadcasti128 m1, [pw_0to15]   ; 0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7
    pmullw      m2, m1
    mova       xm1, xm4             ; zero upper half
    paddsw      m4, m4
    paddsw      m0, m1
%else
    pmullw      m2, [pw_0to15]
%endif
    paddsw      m0, m2              ; m0 = {i+0*b, i+1*b, i+2*b, i+3*b, i+4*b, i+5*b, i+6*b, i+7*b}
    paddsw      m1, m0, m4
    paddsw      m4, m4
    mov        r1d, %1/(mmsize/8)
.loop:
    psraw       m2, m0, 5
    psraw       m3, m1, 5
    paddsw      m0, m4
    paddsw      m1, m4
    packuswb    m2, m3
%if mmsize == 32
    movq        [r0+FDEC_STRIDE*1], xm2
    movhps      [r0+FDEC_STRIDE*3], xm2
    vextracti128 xm2, m2, 1
    movq        [r0+FDEC_STRIDE*0], xm2
    movhps      [r0+FDEC_STRIDE*2], xm2
%else
    movq        [r0+FDEC_STRIDE*0], xm2
    movhps      [r0+FDEC_STRIDE*1], xm2
%endif
    add         r0, FDEC_STRIDE*mmsize/8
    dec        r1d
    jg .loop
    RET
%endif ; HIGH_BIT_DEPTH
%endmacro ; PREDICT_CHROMA_P

INIT_XMM sse2
PREDICT_CHROMA_P 8
PREDICT_CHROMA_P 16
INIT_XMM avx
PREDICT_CHROMA_P 8
PREDICT_CHROMA_P 16
INIT_YMM avx2
PREDICT_CHROMA_P 8
PREDICT_CHROMA_P 16

;-----------------------------------------------------------------------------
; void predict_16x16_p_core( uint8_t *src, int i00, int b, int c )
;-----------------------------------------------------------------------------
%if HIGH_BIT_DEPTH == 0 && ARCH_X86_64 == 0
INIT_MMX mmx2
cglobal predict_16x16_p_core, 1,2
    LOAD_PLANE_ARGS
    movq        mm5, mm2
    movq        mm1, mm2
    pmullw      mm5, [pw_0to15]
    psllw       mm2, 3
    psllw       mm1, 2
    movq        mm3, mm2
    paddsw      mm0, mm5        ; mm0 = {i+ 0*b, i+ 1*b, i+ 2*b, i+ 3*b}
    paddsw      mm1, mm0        ; mm1 = {i+ 4*b, i+ 5*b, i+ 6*b, i+ 7*b}
    paddsw      mm2, mm0        ; mm2 = {i+ 8*b, i+ 9*b, i+10*b, i+11*b}
    paddsw      mm3, mm1        ; mm3 = {i+12*b, i+13*b, i+14*b, i+15*b}

    mov         r1d, 16
ALIGN 4
.loop:
    movq        mm5, mm0
    movq        mm6, mm1
    psraw       mm5, 5
    psraw       mm6, 5
    packuswb    mm5, mm6
    movq        [r0], mm5

    movq        mm5, mm2
    movq        mm6, mm3
    psraw       mm5, 5
    psraw       mm6, 5
    packuswb    mm5, mm6
    movq        [r0+8], mm5

    paddsw      mm0, mm4
    paddsw      mm1, mm4
    paddsw      mm2, mm4
    paddsw      mm3, mm4
    add         r0, FDEC_STRIDE
    dec         r1d
    jg          .loop
    RET
%endif ; !HIGH_BIT_DEPTH && !ARCH_X86_64

%macro PREDICT_16x16_P 0
cglobal predict_16x16_p_core, 1,2,8
    movd     m0, r1m
    movd     m1, r2m
    movd     m2, r3m
    SPLATW   m0, m0, 0
    SPLATW   m1, m1, 0
    SPLATW   m2, m2, 0
    pmullw   m3, m1, [pw_0to15]
    psllw    m1, 3
%if HIGH_BIT_DEPTH
    pxor     m6, m6
    mov     r1d, 16
.loop:
    mova     m4, m0
    mova     m5, m0
    mova     m7, m3
    paddsw   m7, m6
    paddsw   m4, m7
    paddsw   m7, m1
    paddsw   m5, m7
    psraw    m4, 5
    psraw    m5, 5
    CLIPW    m4, [pb_0], [pw_pixel_max]
    CLIPW    m5, [pb_0], [pw_pixel_max]
    mova   [r0], m4
    mova [r0+16], m5
    add      r0, FDEC_STRIDEB
    paddw    m6, m2
%else ; !HIGH_BIT_DEPTH
    paddsw   m0, m3  ; m0 = {i+ 0*b, i+ 1*b, i+ 2*b, i+ 3*b, i+ 4*b, i+ 5*b, i+ 6*b, i+ 7*b}
    paddsw   m1, m0  ; m1 = {i+ 8*b, i+ 9*b, i+10*b, i+11*b, i+12*b, i+13*b, i+14*b, i+15*b}
    paddsw   m7, m2, m2
    mov     r1d, 8
ALIGN 4
.loop:
    psraw    m3, m0, 5
    psraw    m4, m1, 5
    paddsw   m5, m0, m2
    paddsw   m6, m1, m2
    psraw    m5, 5
    psraw    m6, 5
    packuswb m3, m4
    packuswb m5, m6
    mova [r0+FDEC_STRIDE*0], m3
    mova [r0+FDEC_STRIDE*1], m5
    paddsw   m0, m7
    paddsw   m1, m7
    add      r0, FDEC_STRIDE*2
%endif ; !HIGH_BIT_DEPTH
    dec     r1d
    jg .loop
    RET
%endmacro ; PREDICT_16x16_P

INIT_XMM sse2
PREDICT_16x16_P
%if HIGH_BIT_DEPTH == 0
INIT_XMM avx
PREDICT_16x16_P
%endif

INIT_YMM avx2
cglobal predict_16x16_p_core, 1,2,8*HIGH_BIT_DEPTH
    LOAD_PLANE_ARGS
%if HIGH_BIT_DEPTH
    pmullw       m2, [pw_0to15]
    pxor         m5, m5
    pxor         m6, m6
    mova         m7, [pw_pixel_max]
    mov         r1d, 8
.loop:
    paddsw       m1, m2, m5
    paddw        m5, m4
    paddsw       m1, m0
    paddsw       m3, m2, m5
    psraw        m1, 5
    paddsw       m3, m0
    psraw        m3, 5
    CLIPW        m1, m6, m7
    mova [r0+0*FDEC_STRIDEB], m1
    CLIPW        m3, m6, m7
    mova [r0+1*FDEC_STRIDEB], m3
    paddw        m5, m4
    add          r0, 2*FDEC_STRIDEB
%else ; !HIGH_BIT_DEPTH
    vbroadcasti128 m1, [pw_0to15]
    mova        xm3, xm4    ; zero high bits
    pmullw       m1, m2
    psllw        m2, 3
    paddsw       m0, m3
    paddsw       m0, m1     ; X+1*C X+0*C
    paddsw       m1, m0, m2 ; Y+1*C Y+0*C
    paddsw       m4, m4
    mov         r1d, 4
.loop:
    psraw        m2, m0, 5
    psraw        m3, m1, 5
    paddsw       m0, m4
    paddsw       m1, m4
    packuswb     m2, m3     ; X+1*C Y+1*C X+0*C Y+0*C
    vextracti128 [r0+0*FDEC_STRIDE], m2, 1
    mova         [r0+1*FDEC_STRIDE], xm2
    psraw        m2, m0, 5
    psraw        m3, m1, 5
    paddsw       m0, m4
    paddsw       m1, m4
    packuswb     m2, m3     ; X+3*C Y+3*C X+2*C Y+2*C
    vextracti128 [r0+2*FDEC_STRIDE], m2, 1
    mova         [r0+3*FDEC_STRIDE], xm2
    add          r0, FDEC_STRIDE*4
%endif ; !HIGH_BIT_DEPTH
    dec         r1d
    jg .loop
    RET

%if HIGH_BIT_DEPTH == 0
%macro PREDICT_8x8 0
;-----------------------------------------------------------------------------
; void predict_8x8_ddl( uint8_t *src, uint8_t *edge )
;-----------------------------------------------------------------------------
cglobal predict_8x8_ddl, 2,2
    mova        m0, [r1+16]
%ifidn cpuname, ssse3
    movd        m2, [r1+32]
    palignr     m2, m0, 1
%else
    movu        m2, [r1+17]
%endif
    pslldq      m1, m0, 1
    add        r0, FDEC_STRIDE*4
    PRED8x8_LOWPASS m0, m1, m2, m0, m3

%assign Y -4
%rep 8
    psrldq      m0, 1
    movq        [r0+Y*FDEC_STRIDE], m0
%assign Y (Y+1)
%endrep
    RET

%ifnidn cpuname, ssse3
;-----------------------------------------------------------------------------
; void predict_8x8_ddr( uint8_t *src, uint8_t *edge )
;-----------------------------------------------------------------------------
cglobal predict_8x8_ddr, 2,2
    movu        m0, [r1+8]
    movu        m1, [r1+7]
    psrldq      m2, m0, 1
    add         r0, FDEC_STRIDE*4
    PRED8x8_LOWPASS m0, m1, m2, m0, m3

    psrldq      m1, m0, 1
%assign Y 3
%rep 3
    movq        [r0+Y*FDEC_STRIDE], m0
    movq        [r0+(Y-1)*FDEC_STRIDE], m1
    psrldq      m0, 2
    psrldq      m1, 2
%assign Y (Y-2)
%endrep
    movq        [r0-3*FDEC_STRIDE], m0
    movq        [r0-4*FDEC_STRIDE], m1
    RET

;-----------------------------------------------------------------------------
; void predict_8x8_vl( uint8_t *src, uint8_t *edge )
;-----------------------------------------------------------------------------
cglobal predict_8x8_vl, 2,2
    mova        m0, [r1+16]
    pslldq      m1, m0, 1
    psrldq      m2, m0, 1
    pavgb       m3, m0, m2
    add         r0, FDEC_STRIDE*4
    PRED8x8_LOWPASS m0, m1, m2, m0, m5
; m0: (t0 + 2*t1 + t2 + 2) >> 2
; m3: (t0 + t1 + 1) >> 1

%assign Y -4
%rep 3
    psrldq      m0, 1
    movq        [r0+ Y   *FDEC_STRIDE], m3
    movq        [r0+(Y+1)*FDEC_STRIDE], m0
    psrldq      m3, 1
%assign Y (Y+2)
%endrep
    psrldq      m0, 1
    movq        [r0+ Y   *FDEC_STRIDE], m3
    movq        [r0+(Y+1)*FDEC_STRIDE], m0
    RET
%endif ; !ssse3

;-----------------------------------------------------------------------------
; void predict_8x8_vr( uint8_t *src, uint8_t *edge )
;-----------------------------------------------------------------------------
cglobal predict_8x8_vr, 2,2
    movu        m2, [r1+8]
    add         r0, 4*FDEC_STRIDE
    pslldq      m1, m2, 2
    pslldq      m0, m2, 1
    pavgb       m3, m2, m0
    PRED8x8_LOWPASS m0, m2, m1, m0, m4
    movhps      [r0-4*FDEC_STRIDE], m3
    movhps      [r0-3*FDEC_STRIDE], m0
%if cpuflag(ssse3)
    punpckhqdq  m3, m3
    pshufb      m0, [shuf_vr]
    palignr     m3, m0, 13
%else
    mova        m2, m0
    mova        m1, [pw_00ff]
    pand        m1, m0
    psrlw       m0, 8
    packuswb    m1, m0
    pslldq      m1, 4
    movhlps     m3, m1
    shufps      m1, m2, q3210
    psrldq      m3, 5
    psrldq      m1, 5
    SWAP         0, 1
%endif
    movq        [r0+3*FDEC_STRIDE], m0
    movq        [r0+2*FDEC_STRIDE], m3
    psrldq      m0, 1
    psrldq      m3, 1
    movq        [r0+1*FDEC_STRIDE], m0
    movq        [r0+0*FDEC_STRIDE], m3
    psrldq      m0, 1
    psrldq      m3, 1
    movq        [r0-1*FDEC_STRIDE], m0
    movq        [r0-2*FDEC_STRIDE], m3
    RET
%endmacro ; PREDICT_8x8

INIT_XMM sse2
PREDICT_8x8
INIT_XMM ssse3
PREDICT_8x8
INIT_XMM avx
PREDICT_8x8

%endif ; !HIGH_BIT_DEPTH

;-----------------------------------------------------------------------------
; void predict_8x8_vl( pixel *src, pixel *edge )
;-----------------------------------------------------------------------------
%macro PREDICT_8x8_VL_10 1
cglobal predict_8x8_vl, 2,2,8
    mova         m0, [r1+16*SIZEOF_PIXEL]
    mova         m1, [r1+24*SIZEOF_PIXEL]
    PALIGNR      m2, m1, m0, SIZEOF_PIXEL*1, m4
    PSRLPIX      m4, m1, 1
    pavg%1       m6, m0, m2
    pavg%1       m7, m1, m4
    add          r0, FDEC_STRIDEB*4
    mova         [r0-4*FDEC_STRIDEB], m6
    PALIGNR      m3, m7, m6, SIZEOF_PIXEL*1, m5
    mova         [r0-2*FDEC_STRIDEB], m3
    PALIGNR      m3, m7, m6, SIZEOF_PIXEL*2, m5
    mova         [r0+0*FDEC_STRIDEB], m3
    PALIGNR      m7, m7, m6, SIZEOF_PIXEL*3, m5
    mova         [r0+2*FDEC_STRIDEB], m7
    PALIGNR      m3, m1, m0, SIZEOF_PIXEL*7, m6
    PSLLPIX      m5, m0, 1
    PRED8x8_LOWPASS m0, m5, m2, m0, m7
    PRED8x8_LOWPASS m1, m3, m4, m1, m7
    PALIGNR      m4, m1, m0, SIZEOF_PIXEL*1, m2
    mova         [r0-3*FDEC_STRIDEB], m4
    PALIGNR      m4, m1, m0, SIZEOF_PIXEL*2, m2
    mova         [r0-1*FDEC_STRIDEB], m4
    PALIGNR      m4, m1, m0, SIZEOF_PIXEL*3, m2
    mova         [r0+1*FDEC_STRIDEB], m4
    PALIGNR      m1, m1, m0, SIZEOF_PIXEL*4, m2
    mova         [r0+3*FDEC_STRIDEB], m1
    RET
%endmacro
%if HIGH_BIT_DEPTH
INIT_XMM sse2
PREDICT_8x8_VL_10 w
INIT_XMM ssse3
PREDICT_8x8_VL_10 w
INIT_XMM avx
PREDICT_8x8_VL_10 w
%else
INIT_MMX mmx2
PREDICT_8x8_VL_10 b
%endif

;-----------------------------------------------------------------------------
; void predict_8x8_hd( pixel *src, pixel *edge )
;-----------------------------------------------------------------------------
%macro PREDICT_8x8_HD 2
cglobal predict_8x8_hd, 2,2
    add       r0, 4*FDEC_STRIDEB
    mova      m0, [r1+ 8*SIZEOF_PIXEL]     ; lt l0 l1 l2 l3 l4 l5 l6
    movu      m1, [r1+ 7*SIZEOF_PIXEL]     ; l0 l1 l2 l3 l4 l5 l6 l7
%ifidn cpuname, ssse3
    mova      m2, [r1+16*SIZEOF_PIXEL]     ; t7 t6 t5 t4 t3 t2 t1 t0
    mova      m4, m2                       ; t7 t6 t5 t4 t3 t2 t1 t0
    palignr   m2, m0, 7*SIZEOF_PIXEL       ; t6 t5 t4 t3 t2 t1 t0 lt
    palignr   m4, m0, 1*SIZEOF_PIXEL       ; t0 lt l0 l1 l2 l3 l4 l5
%else
    movu      m2, [r1+15*SIZEOF_PIXEL]
    movu      m4, [r1+ 9*SIZEOF_PIXEL]
%endif ; cpuflag
    pavg%1    m3, m0, m1
    PRED8x8_LOWPASS m0, m4, m1, m0, m5
    PSRLPIX   m4, m2, 2                    ; .. .. t6 t5 t4 t3 t2 t1
    PSRLPIX   m1, m2, 1                    ; .. t6 t5 t4 t3 t2 t1 t0
    PRED8x8_LOWPASS m1, m4, m2, m1, m5
                                           ; .. p11 p10 p9
    punpckh%2 m2, m3, m0                   ; p8 p7 p6 p5
    punpckl%2 m3, m0                       ; p4 p3 p2 p1
    mova      [r0+3*FDEC_STRIDEB], m3
    PALIGNR   m0, m2, m3, 2*SIZEOF_PIXEL, m5
    mova      [r0+2*FDEC_STRIDEB], m0
    PALIGNR   m0, m2, m3, 4*SIZEOF_PIXEL, m5
    mova      [r0+1*FDEC_STRIDEB], m0
    PALIGNR   m0, m2, m3, 6*SIZEOF_PIXEL, m3
    mova      [r0+0*FDEC_STRIDEB], m0
    mova      [r0-1*FDEC_STRIDEB], m2
    PALIGNR   m0, m1, m2, 2*SIZEOF_PIXEL, m5
    mova      [r0-2*FDEC_STRIDEB], m0
    PALIGNR   m0, m1, m2, 4*SIZEOF_PIXEL, m5
    mova      [r0-3*FDEC_STRIDEB], m0
    PALIGNR   m1, m1, m2, 6*SIZEOF_PIXEL, m2
    mova      [r0-4*FDEC_STRIDEB], m1
    RET
%endmacro

%if HIGH_BIT_DEPTH
INIT_XMM sse2
PREDICT_8x8_HD w, wd
INIT_XMM ssse3
PREDICT_8x8_HD w, wd
INIT_XMM avx
PREDICT_8x8_HD w, wd
%else
INIT_MMX mmx2
PREDICT_8x8_HD b, bw

;-----------------------------------------------------------------------------
; void predict_8x8_hd( uint8_t *src, uint8_t *edge )
;-----------------------------------------------------------------------------
%macro PREDICT_8x8_HD 0
cglobal predict_8x8_hd, 2,2
    add     r0, 4*FDEC_STRIDE
    movu    m1, [r1+7]
    movu    m3, [r1+8]
    movu    m2, [r1+9]
    pavgb   m4, m1, m3
    PRED8x8_LOWPASS m0, m1, m2, m3, m5
    punpcklbw m4, m0
    movhlps m0, m4

%assign Y 3
%rep 3
    movq   [r0+(Y)*FDEC_STRIDE], m4
    movq   [r0+(Y-4)*FDEC_STRIDE], m0
    psrldq m4, 2
    psrldq m0, 2
%assign Y (Y-1)
%endrep
    movq   [r0+(Y)*FDEC_STRIDE], m4
    movq   [r0+(Y-4)*FDEC_STRIDE], m0
    RET
%endmacro

INIT_XMM sse2
PREDICT_8x8_HD
INIT_XMM avx
PREDICT_8x8_HD
%endif ; HIGH_BIT_DEPTH

%if HIGH_BIT_DEPTH == 0
;-----------------------------------------------------------------------------
; void predict_8x8_hu( uint8_t *src, uint8_t *edge )
;-----------------------------------------------------------------------------
INIT_MMX
cglobal predict_8x8_hu_sse2, 2,2
    add        r0, 4*FDEC_STRIDE
    movq      mm1, [r1+7]           ; l0 l1 l2 l3 l4 l5 l6 l7
    pshufw    mm0, mm1, q0123       ; l6 l7 l4 l5 l2 l3 l0 l1
    movq      mm2, mm0
    psllw     mm0, 8
    psrlw     mm2, 8
    por       mm2, mm0              ; l7 l6 l5 l4 l3 l2 l1 l0
    psllq     mm1, 56               ; l7 .. .. .. .. .. .. ..
    movq      mm3, mm2
    movq      mm4, mm2
    movq      mm5, mm2
    psrlq     mm2, 8
    psrlq     mm3, 16
    por       mm2, mm1              ; l7 l7 l6 l5 l4 l3 l2 l1
    punpckhbw mm1, mm1
    por       mm3, mm1              ; l7 l7 l7 l6 l5 l4 l3 l2
    pavgb     mm4, mm2
    PRED8x8_LOWPASS mm1, mm3, mm5, mm2, mm6

    movq2dq   xmm0, mm4
    movq2dq   xmm1, mm1
    punpcklbw xmm0, xmm1
    punpckhbw  mm4, mm1
%assign Y -4
%rep 3
    movq     [r0+Y*FDEC_STRIDE], xmm0
    psrldq    xmm0, 2
%assign Y (Y+1)
%endrep
    pshufw     mm5, mm4, q3321
    pshufw     mm6, mm4, q3332
    pshufw     mm7, mm4, q3333
    movq     [r0+Y*FDEC_STRIDE], xmm0
    movq     [r0+0*FDEC_STRIDE], mm4
    movq     [r0+1*FDEC_STRIDE], mm5
    movq     [r0+2*FDEC_STRIDE], mm6
    movq     [r0+3*FDEC_STRIDE], mm7
    RET

INIT_XMM
cglobal predict_8x8_hu_ssse3, 2,2
    add       r0, 4*FDEC_STRIDE
    movq      m3, [r1+7]
    pshufb    m3, [shuf_hu]
    psrldq    m1, m3, 1
    psrldq    m2, m3, 2
    pavgb     m0, m1, m3
    PRED8x8_LOWPASS m1, m3, m2, m1, m4
    punpcklbw m0, m1
%assign Y -4
%rep 3
    movq   [r0+ Y   *FDEC_STRIDE], m0
    movhps [r0+(Y+4)*FDEC_STRIDE], m0
    psrldq    m0, 2
    pshufhw   m0, m0, q2210
%assign Y (Y+1)
%endrep
    movq   [r0+ Y   *FDEC_STRIDE], m0
    movhps [r0+(Y+4)*FDEC_STRIDE], m0
    RET
%endif ; !HIGH_BIT_DEPTH

;-----------------------------------------------------------------------------
; void predict_8x8c_v( uint8_t *src )
;-----------------------------------------------------------------------------

%macro PREDICT_8x8C_V 0
cglobal predict_8x8c_v, 1,1
    mova        m0, [r0 - FDEC_STRIDEB]
    STORE8      m0
    RET
%endmacro

%if HIGH_BIT_DEPTH
INIT_XMM sse
PREDICT_8x8C_V
%else
INIT_MMX mmx
PREDICT_8x8C_V
%endif

%if HIGH_BIT_DEPTH

INIT_MMX
cglobal predict_8x8c_v_mmx, 1,1
    mova        m0, [r0 - FDEC_STRIDEB]
    mova        m1, [r0 - FDEC_STRIDEB + 8]
%assign Y 0
%rep 8
    mova        [r0 + (Y&1)*FDEC_STRIDEB], m0
    mova        [r0 + (Y&1)*FDEC_STRIDEB + 8], m1
%if (Y&1) && (Y!=7)
    add         r0, FDEC_STRIDEB*2
%endif
%assign Y Y+1
%endrep
    RET

%endif

%macro PREDICT_8x16C_V 0
cglobal predict_8x16c_v, 1,1
    mova        m0, [r0 - FDEC_STRIDEB]
    STORE16     m0
    RET
%endmacro

%if HIGH_BIT_DEPTH
INIT_XMM sse
PREDICT_8x16C_V
%else
INIT_MMX mmx
PREDICT_8x16C_V
%endif

;-----------------------------------------------------------------------------
; void predict_8x8c_h( uint8_t *src )
;-----------------------------------------------------------------------------
%macro PREDICT_C_H 0
cglobal predict_8x8c_h, 1,1
%if cpuflag(ssse3) && notcpuflag(avx2)
    mova  m2, [pb_3]
%endif
    PRED_H_4ROWS 8, 1
    PRED_H_4ROWS 8, 0
    RET

cglobal predict_8x16c_h, 1,2
%if cpuflag(ssse3) && notcpuflag(avx2)
    mova  m2, [pb_3]
%endif
    mov  r1d, 4
.loop:
    PRED_H_4ROWS 8, 1
    dec  r1d
    jg .loop
    RET
%endmacro

INIT_MMX mmx2
PREDICT_C_H
%if HIGH_BIT_DEPTH
INIT_XMM sse2
PREDICT_C_H
INIT_XMM avx2
PREDICT_C_H
%else
INIT_MMX ssse3
PREDICT_C_H
%endif

;-----------------------------------------------------------------------------
; void predict_8x8c_dc( pixel *src )
;-----------------------------------------------------------------------------
%macro LOAD_LEFT 1
    movzx    r1d, pixel [r0+FDEC_STRIDEB*(%1-4)-SIZEOF_PIXEL]
    movzx    r2d, pixel [r0+FDEC_STRIDEB*(%1-3)-SIZEOF_PIXEL]
    add      r1d, r2d
    movzx    r2d, pixel [r0+FDEC_STRIDEB*(%1-2)-SIZEOF_PIXEL]
    add      r1d, r2d
    movzx    r2d, pixel [r0+FDEC_STRIDEB*(%1-1)-SIZEOF_PIXEL]
    add      r1d, r2d
%endmacro

%macro PREDICT_8x8C_DC 0
cglobal predict_8x8c_dc, 1,3
    pxor      m7, m7
%if HIGH_BIT_DEPTH
    movq      m0, [r0-FDEC_STRIDEB+0]
    movq      m1, [r0-FDEC_STRIDEB+8]
    HADDW     m0, m2
    HADDW     m1, m2
%else ; !HIGH_BIT_DEPTH
    movd      m0, [r0-FDEC_STRIDEB+0]
    movd      m1, [r0-FDEC_STRIDEB+4]
    psadbw    m0, m7            ; s0
    psadbw    m1, m7            ; s1
%endif
    add       r0, FDEC_STRIDEB*4

    LOAD_LEFT 0                 ; s2
    movd      m2, r1d
    LOAD_LEFT 4                 ; s3
    movd      m3, r1d

    punpcklwd m0, m1
    punpcklwd m2, m3
    punpckldq m0, m2            ; s0, s1, s2, s3
    pshufw    m3, m0, q3312     ; s2, s1, s3, s3
    pshufw    m0, m0, q1310     ; s0, s1, s3, s1
    paddw     m0, m3
    psrlw     m0, 2
    pavgw     m0, m7            ; s0+s2, s1, s3, s1+s3
%if HIGH_BIT_DEPTH
%if cpuflag(sse2)
    movq2dq   xmm0, m0
    punpcklwd xmm0, xmm0
    pshufd    xmm1, xmm0, q3322
    punpckldq xmm0, xmm0
%assign Y 0
%rep 8
%assign i (0 + (Y/4))
    movdqa [r0+FDEC_STRIDEB*(Y-4)+0], xmm %+ i
%assign Y Y+1
%endrep
%else ; !sse2
    pshufw    m1, m0, q0000
    pshufw    m2, m0, q1111
    pshufw    m3, m0, q2222
    pshufw    m4, m0, q3333
%assign Y 0
%rep 8
%assign i (1 + (Y/4)*2)
%assign j (2 + (Y/4)*2)
    movq [r0+FDEC_STRIDEB*(Y-4)+0], m %+ i
    movq [r0+FDEC_STRIDEB*(Y-4)+8], m %+ j
%assign Y Y+1
%endrep
%endif
%else ; !HIGH_BIT_DEPTH
    packuswb  m0, m0
    punpcklbw m0, m0
    movq      m1, m0
    punpcklbw m0, m0
    punpckhbw m1, m1
%assign Y 0
%rep 8
%assign i (0 + (Y/4))
    movq [r0+FDEC_STRIDEB*(Y-4)], m %+ i
%assign Y Y+1
%endrep
%endif
    RET
%endmacro

INIT_MMX mmx2
PREDICT_8x8C_DC
%if HIGH_BIT_DEPTH
INIT_MMX sse2
PREDICT_8x8C_DC
%endif

%if HIGH_BIT_DEPTH
%macro STORE_4LINES 3
%if cpuflag(sse2)
    movdqa [r0+FDEC_STRIDEB*(%3-4)], %1
    movdqa [r0+FDEC_STRIDEB*(%3-3)], %1
    movdqa [r0+FDEC_STRIDEB*(%3-2)], %1
    movdqa [r0+FDEC_STRIDEB*(%3-1)], %1
%else
    movq [r0+FDEC_STRIDEB*(%3-4)+0], %1
    movq [r0+FDEC_STRIDEB*(%3-4)+8], %2
    movq [r0+FDEC_STRIDEB*(%3-3)+0], %1
    movq [r0+FDEC_STRIDEB*(%3-3)+8], %2
    movq [r0+FDEC_STRIDEB*(%3-2)+0], %1
    movq [r0+FDEC_STRIDEB*(%3-2)+8], %2
    movq [r0+FDEC_STRIDEB*(%3-1)+0], %1
    movq [r0+FDEC_STRIDEB*(%3-1)+8], %2
%endif
%endmacro
%else
%macro STORE_4LINES 2
    movq [r0+FDEC_STRIDEB*(%2-4)], %1
    movq [r0+FDEC_STRIDEB*(%2-3)], %1
    movq [r0+FDEC_STRIDEB*(%2-2)], %1
    movq [r0+FDEC_STRIDEB*(%2-1)], %1
%endmacro
%endif

%macro PREDICT_8x16C_DC 0
cglobal predict_8x16c_dc, 1,3
    pxor      m7, m7
%if HIGH_BIT_DEPTH
    movq      m0, [r0-FDEC_STRIDEB+0]
    movq      m1, [r0-FDEC_STRIDEB+8]
    HADDW     m0, m2
    HADDW     m1, m2
%else
    movd      m0, [r0-FDEC_STRIDEB+0]
    movd      m1, [r0-FDEC_STRIDEB+4]
    psadbw    m0, m7            ; s0
    psadbw    m1, m7            ; s1
%endif
    punpcklwd m0, m1            ; s0, s1

    add       r0, FDEC_STRIDEB*4
    LOAD_LEFT 0                 ; s2
    pinsrw    m0, r1d, 2
    LOAD_LEFT 4                 ; s3
    pinsrw    m0, r1d, 3        ; s0, s1, s2, s3
    add       r0, FDEC_STRIDEB*8
    LOAD_LEFT 0                 ; s4
    pinsrw    m1, r1d, 2
    LOAD_LEFT 4                 ; s5
    pinsrw    m1, r1d, 3        ; s1, __, s4, s5
    sub       r0, FDEC_STRIDEB*8

    pshufw    m2, m0, q1310     ; s0, s1, s3, s1
    pshufw    m0, m0, q3312     ; s2, s1, s3, s3
    pshufw    m3, m1, q0302     ; s4, s1, s5, s1
    pshufw    m1, m1, q3322     ; s4, s4, s5, s5
    paddw     m0, m2
    paddw     m1, m3
    psrlw     m0, 2
    psrlw     m1, 2
    pavgw     m0, m7
    pavgw     m1, m7
%if HIGH_BIT_DEPTH
%if cpuflag(sse2)
    movq2dq xmm0, m0
    movq2dq xmm1, m1
    punpcklwd xmm0, xmm0
    punpcklwd xmm1, xmm1
    pshufd    xmm2, xmm0, q3322
    pshufd    xmm3, xmm1, q3322
    punpckldq xmm0, xmm0
    punpckldq xmm1, xmm1
    STORE_4LINES xmm0, xmm0, 0
    STORE_4LINES xmm2, xmm2, 4
    STORE_4LINES xmm1, xmm1, 8
    STORE_4LINES xmm3, xmm3, 12
%else
    pshufw    m2, m0, q0000
    pshufw    m3, m0, q1111
    pshufw    m4, m0, q2222
    pshufw    m5, m0, q3333
    STORE_4LINES m2, m3, 0
    STORE_4LINES m4, m5, 4
    pshufw    m2, m1, q0000
    pshufw    m3, m1, q1111
    pshufw    m4, m1, q2222
    pshufw    m5, m1, q3333
    STORE_4LINES m2, m3, 8
    STORE_4LINES m4, m5, 12
%endif
%else
    packuswb  m0, m0            ; dc0, dc1, dc2, dc3
    packuswb  m1, m1            ; dc4, dc5, dc6, dc7
    punpcklbw m0, m0
    punpcklbw m1, m1
    pshufw    m2, m0, q1100
    pshufw    m3, m0, q3322
    pshufw    m4, m1, q1100
    pshufw    m5, m1, q3322
    STORE_4LINES m2, 0
    STORE_4LINES m3, 4
    add       r0, FDEC_STRIDEB*8
    STORE_4LINES m4, 0
    STORE_4LINES m5, 4
%endif
    RET
%endmacro

INIT_MMX mmx2
PREDICT_8x16C_DC
%if HIGH_BIT_DEPTH
INIT_MMX sse2
PREDICT_8x16C_DC
%endif

%macro PREDICT_C_DC_TOP 1
%if HIGH_BIT_DEPTH
INIT_XMM
cglobal predict_8x%1c_dc_top_sse2, 1,1
    pxor        m2, m2
    mova        m0, [r0 - FDEC_STRIDEB]
    pshufd      m1, m0, q2301
    paddw       m0, m1
    pshuflw     m1, m0, q2301
    pshufhw     m1, m1, q2301
    paddw       m0, m1
    psrlw       m0, 1
    pavgw       m0, m2
    STORE%1     m0
    RET
%else ; !HIGH_BIT_DEPTH
INIT_MMX
cglobal predict_8x%1c_dc_top_mmx2, 1,1
    movq        mm0, [r0 - FDEC_STRIDE]
    pxor        mm1, mm1
    pxor        mm2, mm2
    punpckhbw   mm1, mm0
    punpcklbw   mm0, mm2
    psadbw      mm1, mm2        ; s1
    psadbw      mm0, mm2        ; s0
    psrlw       mm1, 1
    psrlw       mm0, 1
    pavgw       mm1, mm2
    pavgw       mm0, mm2
    pshufw      mm1, mm1, 0
    pshufw      mm0, mm0, 0     ; dc0 (w)
    packuswb    mm0, mm1        ; dc0,dc1 (b)
    STORE%1     mm0
    RET
%endif
%endmacro

PREDICT_C_DC_TOP 8
PREDICT_C_DC_TOP 16

;-----------------------------------------------------------------------------
; void predict_16x16_v( pixel *src )
;-----------------------------------------------------------------------------

%macro PREDICT_16x16_V 0
cglobal predict_16x16_v, 1,2
%assign %%i 0
%rep 16*SIZEOF_PIXEL/mmsize
    mova m %+ %%i, [r0-FDEC_STRIDEB+%%i*mmsize]
%assign %%i %%i+1
%endrep
%if 16*SIZEOF_PIXEL/mmsize == 4
    STORE16 m0, m1, m2, m3
%elif 16*SIZEOF_PIXEL/mmsize == 2
    STORE16 m0, m1
%else
    STORE16 m0
%endif
    RET
%endmacro

INIT_MMX mmx2
PREDICT_16x16_V
INIT_XMM sse
PREDICT_16x16_V
%if HIGH_BIT_DEPTH
INIT_YMM avx
PREDICT_16x16_V
%endif

;-----------------------------------------------------------------------------
; void predict_16x16_h( pixel *src )
;-----------------------------------------------------------------------------
%macro PREDICT_16x16_H 0
cglobal predict_16x16_h, 1,2
%if cpuflag(ssse3) && notcpuflag(avx2)
    mova  m2, [pb_3]
%endif
    mov  r1d, 4
.loop:
    PRED_H_4ROWS 16, 1
    dec  r1d
    jg .loop
    RET
%endmacro

INIT_MMX mmx2
PREDICT_16x16_H
%if HIGH_BIT_DEPTH
INIT_XMM sse2
PREDICT_16x16_H
INIT_YMM avx2
PREDICT_16x16_H
%else
;no SSE2 for 8-bit, it's slower than MMX on all systems that don't support SSSE3
INIT_XMM ssse3
PREDICT_16x16_H
%endif

;-----------------------------------------------------------------------------
; void predict_16x16_dc( pixel *src )
;-----------------------------------------------------------------------------
%if WIN64
DECLARE_REG_TMP 6 ; Reduces code size due to fewer REX prefixes
%else
DECLARE_REG_TMP 3
%endif

INIT_XMM
; Returns the sum of the left pixels in r1d+r2d
cglobal predict_16x16_dc_left_internal, 0,4
    movzx r1d, pixel [r0-SIZEOF_PIXEL]
    movzx r2d, pixel [r0+FDEC_STRIDEB-SIZEOF_PIXEL]
%assign i 2*FDEC_STRIDEB
%rep 7
    movzx t0d, pixel [r0+i-SIZEOF_PIXEL]
    add   r1d, t0d
    movzx t0d, pixel [r0+i+FDEC_STRIDEB-SIZEOF_PIXEL]
    add   r2d, t0d
%assign i i+2*FDEC_STRIDEB
%endrep
    RET

%macro PRED16x16_DC 2
%if HIGH_BIT_DEPTH
    mova      xm0, [r0 - FDEC_STRIDEB+ 0]
    paddw     xm0, [r0 - FDEC_STRIDEB+16]
    HADDW     xm0, xm2
    paddw     xm0, %1
    psrlw     xm0, %2
    SPLATW     m0, xm0
%if mmsize == 32
    STORE16    m0
%else
    STORE16    m0, m0
%endif
%else ; !HIGH_BIT_DEPTH
    pxor        m0, m0
    psadbw      m0, [r0 - FDEC_STRIDE]
    MOVHL       m1, m0
    paddw       m0, m1
    paddusw     m0, %1
    psrlw       m0, %2              ; dc
    SPLATW      m0, m0
    packuswb    m0, m0              ; dc in bytes
    STORE16     m0
%endif
%endmacro

%macro PREDICT_16x16_DC 0
cglobal predict_16x16_dc, 1,3
    call predict_16x16_dc_left_internal
    lea          r1d, [r1+r2+16]
    movd         xm3, r1d
    PRED16x16_DC xm3, 5
    RET

cglobal predict_16x16_dc_top, 1,2
    PRED16x16_DC [pw_8], 4
    RET

cglobal predict_16x16_dc_left, 1,3
    call predict_16x16_dc_left_internal
    lea       r1d, [r1+r2+8]
    shr       r1d, 4
    movd      xm0, r1d
    SPLATW     m0, xm0
%if HIGH_BIT_DEPTH && mmsize == 16
    STORE16    m0, m0
%else
%if HIGH_BIT_DEPTH == 0
    packuswb   m0, m0
%endif
    STORE16    m0
%endif
    RET
%endmacro

INIT_XMM sse2
PREDICT_16x16_DC
%if HIGH_BIT_DEPTH
INIT_YMM avx2
PREDICT_16x16_DC
%else
INIT_XMM avx2
PREDICT_16x16_DC
%endif
