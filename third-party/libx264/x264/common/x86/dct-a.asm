;*****************************************************************************
;* dct-a.asm: x86 transform and zigzag
;*****************************************************************************
;* Copyright (C) 2003-2022 x264 project
;*
;* Authors: Holger Lubitz <holger@lubitz.org>
;*          Loren Merritt <lorenm@u.washington.edu>
;*          Laurent Aimar <fenrir@via.ecp.fr>
;*          Min Chen <chenm001.163.com>
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
%include "x86util.asm"

SECTION_RODATA 64
; AVX-512 permutation indices are bit-packed to save cache
%if HIGH_BIT_DEPTH
scan_frame_avx512: dd 0x00bf0200, 0x00fd7484, 0x0033a611, 0x0069d822 ; bits 0-3:   4x4_frame
                   dd 0x00a3ca95, 0x00dd8d08, 0x00e75b8c, 0x00a92919 ; bits 4-8:   8x8_frame1
                   dd 0x0072f6a6, 0x003c8433, 0x007e5247, 0x00b6a0ba ; bits 9-13:  8x8_frame2
                   dd 0x00ecf12d, 0x00f3239e, 0x00b9540b, 0x00ff868f ; bits 14-18: 8x8_frame3
                                                                     ; bits 19-23: 8x8_frame4
scan_field_avx512: dd 0x0006b240, 0x000735a1, 0x0007b9c2, 0x0009bde8 ; bits 0-4:   8x8_field1
                   dd 0x000c4e69, 0x000ce723, 0x000a0004, 0x000aeb4a ; bits 5-9:   8x8_field2
                   dd 0x000b5290, 0x000bd6ab, 0x000d5ac5, 0x000ddee6 ; bits 10-14: 8x8_field3
                   dd 0x000e6f67, 0x000e842c, 0x000f0911, 0x000ff058 ; bits 15-19: 8x8_field4
cavlc_shuf_avx512: dd 0x00018820, 0x000398a4, 0x0005a928, 0x0007b9ac ; bits 0-4:   interleave1
                   dd 0x0009ca30, 0x000bdab4, 0x000deb38, 0x000ffbbc ; bits 5-9:   interleave2
                   dd 0x00010c01, 0x00031c85, 0x00052d09, 0x00073d8d ; bits 10-14: interleave3
                   dd 0x00094e11, 0x000b5e95, 0x000d6f19, 0x000f7f9d ; bits 15-19: interleave4
%else
dct_avx512:        dd 0x10000000, 0x00021104, 0x3206314c, 0x60042048 ; bits    0-4:   dct8x8_fenc    bits    5-9:   dct8x8_fdec
                   dd 0x98008a10, 0x20029b14, 0xba06bb5c, 0x4004aa58 ; bits    10-13: dct16x16_fenc  bits    14-18: dct16x16_fdec
                   dd 0x54004421, 0x80025525, 0x7606756d, 0xe0046469 ; bits(e) 24-27: idct8x8_idct1  bits(e) 28-31: idct8x8_idct2
                   dd 0xdc00ce31, 0xa002df35, 0xfe06ff7d, 0xc004ee79 ; bits(o) 24-31: idct8x8_gather
scan_frame_avx512: dw 0x7000, 0x5484, 0x3811, 0x1c22, 0x3c95, 0x5908, 0x758c, 0x9119 ; bits 0-3:   4x4_frame
                   dw 0xaca6, 0xc833, 0xe447, 0xe8ba, 0xcd2d, 0xb19e, 0x960b, 0x7a8f ; bits 4-9:   8x8_frame1
                   dw 0x5e10, 0x7da0, 0x9930, 0xb4c0, 0xd050, 0xec60, 0xf0d0, 0xd540 ; bits 10-15: 8x8_frame2
                   dw 0xb9b0, 0x9e20, 0xbe90, 0xdb00, 0xf780, 0xfb10, 0xdea0, 0xfe30
scan_field_avx512: dw 0x0700, 0x0741, 0x0782, 0x07c8, 0x08c9, 0x0a43, 0x0c04, 0x0a8a ; bits 0-5:   8x8_field1
                   dw 0x0910, 0x094b, 0x0985, 0x09c6, 0x0ac7, 0x0c4c, 0x0c91, 0x0b18 ; bits 6-11:  8x8_field2
                   dw 0x0b52, 0x0b8d, 0x0bce, 0x0ccf, 0x0e13, 0x0e59, 0x0d20, 0x0d5a
                   dw 0x0d94, 0x0dd5, 0x0e96, 0x0ed7, 0x0f1b, 0x0f61, 0x0fa8, 0x0fe2
cavlc_shuf_avx512: dw 0x0080, 0x0184, 0x0288, 0x038c, 0x0490, 0x0594, 0x0698, 0x079c ; bits 0-5:   interleave1
                   dw 0x08a0, 0x09a4, 0x0aa8, 0x0bac, 0x0cb0, 0x0db4, 0x0eb8, 0x0fbc ; bits 6-11:  interleave2
                   dw 0x00c1, 0x01c5, 0x02c9, 0x03cd, 0x04d1, 0x05d5, 0x06d9, 0x07dd
                   dw 0x08e1, 0x09e5, 0x0ae9, 0x0bed, 0x0cf1, 0x0df5, 0x0ef9, 0x0ffd
%endif

pw_ppmmmmpp:    dw 1,1,-1,-1,-1,-1,1,1
pb_sub4frame:   db 0,1,4,8,5,2,3,6,9,12,13,10,7,11,14,15
pb_sub4field:   db 0,4,1,8,12,5,9,13,2,6,10,14,3,7,11,15
pb_subacmask:   dw 0,-1,-1,-1,-1,-1,-1,-1
pb_scan4framea: SHUFFLE_MASK_W 6,3,7,0,4,1,2,5
pb_scan4frameb: SHUFFLE_MASK_W 0,4,1,2,5,6,3,7
pb_scan4frame2a: SHUFFLE_MASK_W 0,4,1,2,5,8,12,9
pb_scan4frame2b: SHUFFLE_MASK_W 6,3,7,10,13,14,11,15

pb_scan8framet1: SHUFFLE_MASK_W 0,  1,  6,  7,  8,  9, 13, 14
pb_scan8framet2: SHUFFLE_MASK_W 2 , 3,  4,  7,  9, 15, 10, 14
pb_scan8framet3: SHUFFLE_MASK_W 0,  1,  5,  6,  8, 11, 12, 13
pb_scan8framet4: SHUFFLE_MASK_W 0,  3,  4,  5,  8, 11, 12, 15
pb_scan8framet5: SHUFFLE_MASK_W 1,  2,  6,  7,  9, 10, 13, 14
pb_scan8framet6: SHUFFLE_MASK_W 0,  3,  4,  5, 10, 11, 12, 15
pb_scan8framet7: SHUFFLE_MASK_W 1,  2,  6,  7,  8,  9, 14, 15
pb_scan8framet8: SHUFFLE_MASK_W 0,  1,  2,  7,  8, 10, 11, 14
pb_scan8framet9: SHUFFLE_MASK_W 1,  4,  5,  7,  8, 13, 14, 15

pb_scan8frame1: SHUFFLE_MASK_W  0,  8,  1,  2,  9, 12,  4, 13
pb_scan8frame2: SHUFFLE_MASK_W  4,  0,  1,  5,  8, 10, 12, 14
pb_scan8frame3: SHUFFLE_MASK_W 12, 10,  8,  6,  2,  3,  7,  9
pb_scan8frame4: SHUFFLE_MASK_W  0,  1,  8, 12,  4, 13,  9,  2
pb_scan8frame5: SHUFFLE_MASK_W  5, 14, 10,  3, 11, 15,  6,  7
pb_scan8frame6: SHUFFLE_MASK_W  6,  8, 12, 13,  9,  7,  5,  3
pb_scan8frame7: SHUFFLE_MASK_W  1,  3,  5,  7, 10, 14, 15, 11
pb_scan8frame8: SHUFFLE_MASK_W  10, 3, 11, 14,  5,  6, 15,  7

pb_scan8field1 : SHUFFLE_MASK_W    0,   1,   2,   8,   9,   3,   4,  10
pb_scan8field2a: SHUFFLE_MASK_W 0x80,  11,   5,   6,   7,  12,0x80,0x80
pb_scan8field2b: SHUFFLE_MASK_W    0,0x80,0x80,0x80,0x80,0x80,   1,   8
pb_scan8field3a: SHUFFLE_MASK_W   10,   5,   6,   7,  11,0x80,0x80,0x80
pb_scan8field3b: SHUFFLE_MASK_W 0x80,0x80,0x80,0x80,0x80,   1,   8,   2
pb_scan8field4a: SHUFFLE_MASK_W    4,   5,   6,   7,  11,0x80,0x80,0x80
pb_scan8field6 : SHUFFLE_MASK_W    4,   5,   6,   7,  11,0x80,0x80,  12
pb_scan8field7 : SHUFFLE_MASK_W    5,   6,   7,  11,0x80,0x80,  12,  13

SECTION .text

cextern pw_32_0
cextern pw_32
cextern pw_512
cextern pw_8000
cextern pw_pixel_max
cextern hsub_mul
cextern pb_1
cextern pw_1
cextern pd_1
cextern pd_32
cextern pw_ppppmmmm
cextern pw_pmpmpmpm
cextern deinterleave_shufd
cextern pb_unpackbd1
cextern pb_unpackbd2

%macro WALSH4_1D 6
    SUMSUB_BADC %1, %5, %4, %3, %2, %6
    SUMSUB_BADC %1, %5, %3, %4, %2, %6
    SWAP %2, %5, %4
%endmacro

%macro SUMSUB_17BIT 4 ; a, b, tmp, 0x8000
    movq  m%3, m%4
    pxor  m%1, m%4
    psubw m%3, m%2
    pxor  m%2, m%4
    pavgw m%3, m%1
    pavgw m%2, m%1
    pxor  m%3, m%4
    pxor  m%2, m%4
    SWAP %1, %2, %3
%endmacro

%macro DCT_UNPACK 3
    punpcklwd %3, %1
    punpckhwd %2, %1
    psrad     %3, 16
    psrad     %2, 16
    SWAP      %1, %3
%endmacro

%if HIGH_BIT_DEPTH
;-----------------------------------------------------------------------------
; void dct4x4dc( dctcoef d[4][4] )
;-----------------------------------------------------------------------------
%macro DCT4x4_DC 0
cglobal dct4x4dc, 1,1,5
    mova   m0, [r0+ 0]
    mova   m1, [r0+16]
    mova   m2, [r0+32]
    mova   m3, [r0+48]
    WALSH4_1D  d, 0,1,2,3,4
    TRANSPOSE4x4D 0,1,2,3,4
    paddd  m0, [pd_1]
    WALSH4_1D  d, 0,1,2,3,4
    psrad  m0, 1
    psrad  m1, 1
    psrad  m2, 1
    psrad  m3, 1
    mova [r0+ 0], m0
    mova [r0+16], m1
    mova [r0+32], m2
    mova [r0+48], m3
    RET
%endmacro ; DCT4x4_DC

INIT_XMM sse2
DCT4x4_DC
INIT_XMM avx
DCT4x4_DC
%else

INIT_MMX mmx2
cglobal dct4x4dc, 1,1
    movq   m3, [r0+24]
    movq   m2, [r0+16]
    movq   m1, [r0+ 8]
    movq   m0, [r0+ 0]
    movq   m7, [pw_8000] ; convert to unsigned and back, so that pavgw works
    WALSH4_1D  w, 0,1,2,3,4
    TRANSPOSE4x4W 0,1,2,3,4
    SUMSUB_BADC w, 1, 0, 3, 2, 4
    SWAP 0, 1
    SWAP 2, 3
    SUMSUB_17BIT 0,2,4,7
    SUMSUB_17BIT 1,3,5,7
    movq  [r0+0], m0
    movq  [r0+8], m2
    movq [r0+16], m3
    movq [r0+24], m1
    RET
%endif ; HIGH_BIT_DEPTH

%if HIGH_BIT_DEPTH
;-----------------------------------------------------------------------------
; void idct4x4dc( int32_t d[4][4] )
;-----------------------------------------------------------------------------
%macro IDCT4x4DC 0
cglobal idct4x4dc, 1,1
    mova   m3, [r0+48]
    mova   m2, [r0+32]
    mova   m1, [r0+16]
    mova   m0, [r0+ 0]
    WALSH4_1D  d,0,1,2,3,4
    TRANSPOSE4x4D 0,1,2,3,4
    WALSH4_1D  d,0,1,2,3,4
    mova  [r0+ 0], m0
    mova  [r0+16], m1
    mova  [r0+32], m2
    mova  [r0+48], m3
    RET
%endmacro ; IDCT4x4DC

INIT_XMM sse2
IDCT4x4DC
INIT_XMM avx
IDCT4x4DC
%else

;-----------------------------------------------------------------------------
; void idct4x4dc( int16_t d[4][4] )
;-----------------------------------------------------------------------------
INIT_MMX mmx
cglobal idct4x4dc, 1,1
    movq   m3, [r0+24]
    movq   m2, [r0+16]
    movq   m1, [r0+ 8]
    movq   m0, [r0+ 0]
    WALSH4_1D  w,0,1,2,3,4
    TRANSPOSE4x4W 0,1,2,3,4
    WALSH4_1D  w,0,1,2,3,4
    movq  [r0+ 0], m0
    movq  [r0+ 8], m1
    movq  [r0+16], m2
    movq  [r0+24], m3
    RET
%endif ; HIGH_BIT_DEPTH

;-----------------------------------------------------------------------------
; void dct2x4dc( dctcoef dct[8], dctcoef dct4x4[8][16] )
;-----------------------------------------------------------------------------
%if WIN64
    DECLARE_REG_TMP 6 ; Avoid some REX prefixes to reduce code size
%else
    DECLARE_REG_TMP 2
%endif

%macro INSERT_COEFF 3 ; dst, src, imm
    %if %3
        %if HIGH_BIT_DEPTH
            %if cpuflag(sse4)
                pinsrd %1, %2, %3
            %elif %3 == 2
                movd       m2, %2
            %elif %3 == 1
                punpckldq  %1, %2
            %else
                punpckldq  m2, %2
                punpcklqdq %1, m2
            %endif
        %else
            %if %3 == 2
                punpckldq  %1, %2
            %else
                pinsrw %1, %2, %3
            %endif
        %endif
    %else
        movd %1, %2
    %endif
    %if HIGH_BIT_DEPTH
        mov %2, t0d
    %else
        mov %2, t0w
    %endif
%endmacro

%macro DCT2x4DC 2
cglobal dct2x4dc, 2,3
    xor          t0d, t0d
    INSERT_COEFF  m0, [r1+0*16*SIZEOF_DCTCOEF], 0
    INSERT_COEFF  m0, [r1+1*16*SIZEOF_DCTCOEF], 2
    add           r1, 4*16*SIZEOF_DCTCOEF
    INSERT_COEFF  m0, [r1-2*16*SIZEOF_DCTCOEF], 1
    INSERT_COEFF  m0, [r1-1*16*SIZEOF_DCTCOEF], 3
    INSERT_COEFF  m1, [r1+0*16*SIZEOF_DCTCOEF], 0
    INSERT_COEFF  m1, [r1+1*16*SIZEOF_DCTCOEF], 2
    INSERT_COEFF  m1, [r1+2*16*SIZEOF_DCTCOEF], 1
    INSERT_COEFF  m1, [r1+3*16*SIZEOF_DCTCOEF], 3
    SUMSUB_BA     %1, 1, 0, 2
    SBUTTERFLY    %2, 1, 0, 2
    SUMSUB_BA     %1, 0, 1, 2
    SBUTTERFLY    %2, 0, 1, 2
    SUMSUB_BA     %1, 1, 0, 2
    pshuf%1       m0, m0, q1032
    mova        [r0], m1
    mova [r0+mmsize], m0
    RET
%endmacro

%if HIGH_BIT_DEPTH
INIT_XMM sse2
DCT2x4DC d, dq
INIT_XMM avx
DCT2x4DC d, dq
%else
INIT_MMX mmx2
DCT2x4DC w, wd
%endif

%if HIGH_BIT_DEPTH
;-----------------------------------------------------------------------------
; void sub4x4_dct( dctcoef dct[4][4], pixel *pix1, pixel *pix2 )
;-----------------------------------------------------------------------------
INIT_MMX mmx
cglobal sub4x4_dct, 3,3
.skip_prologue:
    LOAD_DIFF  m0, m4, none, [r1+0*FENC_STRIDE], [r2+0*FDEC_STRIDE]
    LOAD_DIFF  m3, m4, none, [r1+6*FENC_STRIDE], [r2+6*FDEC_STRIDE]
    LOAD_DIFF  m1, m4, none, [r1+2*FENC_STRIDE], [r2+2*FDEC_STRIDE]
    LOAD_DIFF  m2, m4, none, [r1+4*FENC_STRIDE], [r2+4*FDEC_STRIDE]
    DCT4_1D 0,1,2,3,4
    TRANSPOSE4x4W 0,1,2,3,4

    SUMSUB_BADC w, 3, 0, 2, 1
    SUMSUB_BA   w, 2, 3, 4
    DCT_UNPACK m2, m4, m5
    DCT_UNPACK m3, m6, m7
    mova  [r0+ 0], m2 ; s03 + s12
    mova  [r0+ 8], m4
    mova  [r0+32], m3 ; s03 - s12
    mova  [r0+40], m6

    DCT_UNPACK m0, m2, m4
    DCT_UNPACK m1, m3, m5
    SUMSUB2_AB  d, 0, 1, 4
    SUMSUB2_AB  d, 2, 3, 5
    mova  [r0+16], m0 ; d03*2 + d12
    mova  [r0+24], m2
    mova  [r0+48], m4 ; d03 - 2*d12
    mova  [r0+56], m5
    RET
%else

%macro SUB_DCT4 0
cglobal sub4x4_dct, 3,3
.skip_prologue:
%if cpuflag(ssse3)
    mova m5, [hsub_mul]
%endif
    LOAD_DIFF8x4 0, 3, 1, 2, 4, 5, r1, r2
    DCT4_1D 0,1,2,3,4
    TRANSPOSE4x4W 0,1,2,3,4
    DCT4_1D 0,1,2,3,4
    movq  [r0+ 0], m0
    movq  [r0+ 8], m1
    movq  [r0+16], m2
    movq  [r0+24], m3
    RET
%endmacro

INIT_MMX mmx
SUB_DCT4
INIT_MMX ssse3
SUB_DCT4
%endif ; HIGH_BIT_DEPTH

%if HIGH_BIT_DEPTH
;-----------------------------------------------------------------------------
; void add4x4_idct( pixel *p_dst, dctcoef dct[4][4] )
;-----------------------------------------------------------------------------
%macro STORE_DIFFx2 6
    psrad     %1, 6
    psrad     %2, 6
    packssdw  %1, %2
    movq      %3, %5
    movhps    %3, %6
    paddsw    %1, %3
    CLIPW     %1, %4, [pw_pixel_max]
    movq      %5, %1
    movhps    %6, %1
%endmacro

%macro ADD4x4_IDCT 0
cglobal add4x4_idct, 2,2,6
    add   r0, 2*FDEC_STRIDEB
.skip_prologue:
    mova  m1, [r1+16]
    mova  m3, [r1+48]
    mova  m2, [r1+32]
    mova  m0, [r1+ 0]
    IDCT4_1D d,0,1,2,3,4,5
    TRANSPOSE4x4D 0,1,2,3,4
    paddd m0, [pd_32]
    IDCT4_1D d,0,1,2,3,4,5
    pxor  m5, m5
    STORE_DIFFx2 m0, m1, m4, m5, [r0-2*FDEC_STRIDEB], [r0-1*FDEC_STRIDEB]
    STORE_DIFFx2 m2, m3, m4, m5, [r0+0*FDEC_STRIDEB], [r0+1*FDEC_STRIDEB]
    RET
%endmacro

INIT_XMM sse2
ADD4x4_IDCT
INIT_XMM avx
ADD4x4_IDCT

%else ; !HIGH_BIT_DEPTH

INIT_MMX mmx
cglobal add4x4_idct, 2,2
    pxor m7, m7
.skip_prologue:
    movq  m1, [r1+ 8]
    movq  m3, [r1+24]
    movq  m2, [r1+16]
    movq  m0, [r1+ 0]
    IDCT4_1D w,0,1,2,3,4,5
    TRANSPOSE4x4W 0,1,2,3,4
    paddw m0, [pw_32]
    IDCT4_1D w,0,1,2,3,4,5
    STORE_DIFF  m0, m4, m7, [r0+0*FDEC_STRIDE]
    STORE_DIFF  m1, m4, m7, [r0+1*FDEC_STRIDE]
    STORE_DIFF  m2, m4, m7, [r0+2*FDEC_STRIDE]
    STORE_DIFF  m3, m4, m7, [r0+3*FDEC_STRIDE]
    RET

%macro ADD4x4 0
cglobal add4x4_idct, 2,2,6
    mova      m1, [r1+0x00]     ; row1/row0
    mova      m3, [r1+0x10]     ; row3/row2
    psraw     m0, m1, 1         ; row1>>1/...
    psraw     m2, m3, 1         ; row3>>1/...
    movsd     m0, m1            ; row1>>1/row0
    movsd     m2, m3            ; row3>>1/row2
    psubw     m0, m3            ; row1>>1-row3/row0-2
    paddw     m2, m1            ; row3>>1+row1/row0+2
    SBUTTERFLY2 wd, 0, 2, 1
    SUMSUB_BA w, 2, 0, 1
    pshuflw   m1, m2, q2301
    pshufhw   m2, m2, q2301
    punpckldq m1, m0
    punpckhdq m2, m0
    SWAP       0, 1

    mova      m1, [pw_32_0]
    paddw     m1, m0            ; row1/row0 corrected
    psraw     m0, 1             ; row1>>1/...
    psraw     m3, m2, 1         ; row3>>1/...
    movsd     m0, m1            ; row1>>1/row0
    movsd     m3, m2            ; row3>>1/row2
    psubw     m0, m2            ; row1>>1-row3/row0-2
    paddw     m3, m1            ; row3>>1+row1/row0+2
    SBUTTERFLY2 qdq, 0, 3, 1
    SUMSUB_BA w, 3, 0, 1

    movd      m4, [r0+FDEC_STRIDE*0]
    movd      m1, [r0+FDEC_STRIDE*1]
    movd      m2, [r0+FDEC_STRIDE*2]
    movd      m5, [r0+FDEC_STRIDE*3]
    punpckldq m1, m4            ; row0/row1
    pxor      m4, m4
    punpckldq m2, m5            ; row3/row2
    punpcklbw m1, m4
    psraw     m3, 6
    punpcklbw m2, m4
    psraw     m0, 6
    paddsw    m3, m1
    paddsw    m0, m2
    packuswb  m0, m3            ; row0/row1/row3/row2
    pextrd   [r0+FDEC_STRIDE*0], m0, 3
    pextrd   [r0+FDEC_STRIDE*1], m0, 2
    movd     [r0+FDEC_STRIDE*2], m0
    pextrd   [r0+FDEC_STRIDE*3], m0, 1
    RET
%endmacro ; ADD4x4

INIT_XMM sse4
ADD4x4
INIT_XMM avx
ADD4x4

%macro STOREx2_AVX2 9
    movq      xm%3, [r0+%5*FDEC_STRIDE]
    vinserti128 m%3, m%3, [r0+%6*FDEC_STRIDE], 1
    movq      xm%4, [r0+%7*FDEC_STRIDE]
    vinserti128 m%4, m%4, [r0+%8*FDEC_STRIDE], 1
    punpcklbw  m%3, m%9
    punpcklbw  m%4, m%9
    psraw      m%1, 6
    psraw      m%2, 6
    paddsw     m%1, m%3
    paddsw     m%2, m%4
    packuswb   m%1, m%2
    vextracti128 xm%2, m%1, 1
    movq   [r0+%5*FDEC_STRIDE], xm%1
    movq   [r0+%6*FDEC_STRIDE], xm%2
    movhps [r0+%7*FDEC_STRIDE], xm%1
    movhps [r0+%8*FDEC_STRIDE], xm%2
%endmacro

INIT_YMM avx2
cglobal add8x8_idct, 2,3,8
    add    r0, 4*FDEC_STRIDE
    pxor   m7, m7
    TAIL_CALL .skip_prologue, 0
cglobal_label .skip_prologue
    ; TRANSPOSE4x4Q
    mova       xm0, [r1+ 0]
    mova       xm1, [r1+32]
    mova       xm2, [r1+16]
    mova       xm3, [r1+48]
    vinserti128 m0, m0, [r1+ 64], 1
    vinserti128 m1, m1, [r1+ 96], 1
    vinserti128 m2, m2, [r1+ 80], 1
    vinserti128 m3, m3, [r1+112], 1
    SBUTTERFLY qdq, 0, 1, 4
    SBUTTERFLY qdq, 2, 3, 4
    IDCT4_1D w,0,1,2,3,4,5
    TRANSPOSE2x4x4W 0,1,2,3,4
    paddw m0, [pw_32]
    IDCT4_1D w,0,1,2,3,4,5
    STOREx2_AVX2 0, 1, 4, 5, -4, 0, -3, 1, 7
    STOREx2_AVX2 2, 3, 4, 5, -2, 2, -1, 3, 7
    ret

; 2xdst, 2xtmp, 4xsrcrow, 1xzero
%macro LOAD_DIFF8x2_AVX2 9
    movq    xm%1, [r1+%5*FENC_STRIDE]
    movq    xm%2, [r1+%6*FENC_STRIDE]
    vinserti128 m%1, m%1, [r1+%7*FENC_STRIDE], 1
    vinserti128 m%2, m%2, [r1+%8*FENC_STRIDE], 1
    punpcklbw m%1, m%9
    punpcklbw m%2, m%9
    movq    xm%3, [r2+(%5-4)*FDEC_STRIDE]
    movq    xm%4, [r2+(%6-4)*FDEC_STRIDE]
    vinserti128 m%3, m%3, [r2+(%7-4)*FDEC_STRIDE], 1
    vinserti128 m%4, m%4, [r2+(%8-4)*FDEC_STRIDE], 1
    punpcklbw m%3, m%9
    punpcklbw m%4, m%9
    psubw    m%1, m%3
    psubw    m%2, m%4
%endmacro

; 4x src, 1x tmp
%macro STORE8_DCT_AVX2 5
    SBUTTERFLY qdq, %1, %2, %5
    SBUTTERFLY qdq, %3, %4, %5
    mova [r0+  0], xm%1
    mova [r0+ 16], xm%3
    mova [r0+ 32], xm%2
    mova [r0+ 48], xm%4
    vextracti128 [r0+ 64], m%1, 1
    vextracti128 [r0+ 80], m%3, 1
    vextracti128 [r0+ 96], m%2, 1
    vextracti128 [r0+112], m%4, 1
%endmacro

%macro STORE16_DCT_AVX2 5
    SBUTTERFLY qdq, %1, %2, %5
    SBUTTERFLY qdq, %3, %4, %5
    mova [r0+ 0-128], xm%1
    mova [r0+16-128], xm%3
    mova [r0+32-128], xm%2
    mova [r0+48-128], xm%4
    vextracti128 [r0+ 0], m%1, 1
    vextracti128 [r0+16], m%3, 1
    vextracti128 [r0+32], m%2, 1
    vextracti128 [r0+48], m%4, 1
%endmacro

INIT_YMM avx2
cglobal sub8x8_dct, 3,3,7
    pxor m6, m6
    add r2, 4*FDEC_STRIDE
    LOAD_DIFF8x2_AVX2 0, 1, 4, 5, 0, 1, 4, 5, 6
    LOAD_DIFF8x2_AVX2 2, 3, 4, 5, 2, 3, 6, 7, 6
    DCT4_1D 0, 1, 2, 3, 4
    TRANSPOSE2x4x4W 0, 1, 2, 3, 4
    DCT4_1D 0, 1, 2, 3, 4
    STORE8_DCT_AVX2 0, 1, 2, 3, 4
    RET

INIT_YMM avx2
cglobal sub16x16_dct, 3,3,6
    add r0, 128
    add r2, 4*FDEC_STRIDE
    call .sub16x4_dct
    add r0, 64
    add r1, 4*FENC_STRIDE
    add r2, 4*FDEC_STRIDE
    call .sub16x4_dct
    add r0, 256-64
    add r1, 4*FENC_STRIDE
    add r2, 4*FDEC_STRIDE
    call .sub16x4_dct
    add r0, 64
    add r1, 4*FENC_STRIDE
    add r2, 4*FDEC_STRIDE
    call .sub16x4_dct
    RET
.sub16x4_dct:
    LOAD_DIFF16x2_AVX2 0, 1, 4, 5, 0, 1
    LOAD_DIFF16x2_AVX2 2, 3, 4, 5, 2, 3
    DCT4_1D 0, 1, 2, 3, 4
    TRANSPOSE2x4x4W 0, 1, 2, 3, 4
    DCT4_1D 0, 1, 2, 3, 4
    STORE16_DCT_AVX2 0, 1, 2, 3, 4
    ret

%macro DCT4x4_AVX512 0
    psubw      m0, m2            ; 0 1
    psubw      m1, m3            ; 3 2
    SUMSUB_BA   w, 1, 0, 2
    SBUTTERFLY wd, 1, 0, 2
    paddw      m2, m1, m0
    psubw      m3, m1, m0
    vpaddw     m2 {k1}, m1       ; 0+1+2+3 0<<1+1-2-3<<1
    vpsubw     m3 {k1}, m0       ; 0-1-2+3 0-1<<1+2<<1-3
    shufps     m1, m2, m3, q2323 ; a3 b3 a2 b2 c3 d3 c2 d2
    punpcklqdq m2, m3            ; a0 b0 a1 b1 c0 d0 c1 d1
    SUMSUB_BA   w, 1, 2, 3
    shufps     m3, m1, m2, q3131 ; a1+a2 b1+b2 c1+c2 d1+d2 a1-a2 b1-b2 b1-b2 d1-d2
    shufps     m1, m2, q2020     ; a0+a3 b0+b3 c0+c3 d0+d3 a0-a3 b0-b3 c0-c3 d0-d3
    paddw      m2, m1, m3
    psubw      m0, m1, m3
    vpaddw     m2 {k2}, m1       ; 0'+1'+2'+3' 0'<<1+1'-2'-3'<<1
    vpsubw     m0 {k2}, m3       ; 0'-1'-2'+3' 0'-1'<<1+2'<<1-3'
%endmacro

INIT_XMM avx512
cglobal sub4x4_dct
    mov         eax, 0xf0aa
    kmovw        k1, eax
    PROLOGUE 3,3
    movd         m0,      [r1+0*FENC_STRIDE]
    movd         m2,      [r2+0*FDEC_STRIDE]
    vpbroadcastd m0 {k1}, [r1+1*FENC_STRIDE]
    vpbroadcastd m2 {k1}, [r2+1*FDEC_STRIDE]
    movd         m1,      [r1+3*FENC_STRIDE]
    movd         m3,      [r2+3*FDEC_STRIDE]
    vpbroadcastd m1 {k1}, [r1+2*FENC_STRIDE]
    vpbroadcastd m3 {k1}, [r2+2*FDEC_STRIDE]
    kshiftrw     k2, k1, 8
    pxor         m4, m4
    punpcklbw    m0, m4
    punpcklbw    m2, m4
    punpcklbw    m1, m4
    punpcklbw    m3, m4
    DCT4x4_AVX512
    mova       [r0], m2
    mova    [r0+16], m0
    RET

INIT_ZMM avx512
cglobal dct4x4x4_internal
    punpcklbw  m0, m1, m4
    punpcklbw  m2, m3, m4
    punpckhbw  m1, m4
    punpckhbw  m3, m4
    DCT4x4_AVX512
    mova       m1, m2
    vshufi32x4 m2 {k2}, m0, m0, q2200 ; m0
    vshufi32x4 m0 {k3}, m1, m1, q3311 ; m1
    ret

%macro DCT8x8_LOAD_FENC_AVX512 4 ; dst, perm, row1, row2
    movu     %1,     [r1+%3*FENC_STRIDE]
    vpermt2d %1, %2, [r1+%4*FENC_STRIDE]
%endmacro

%macro DCT8x8_LOAD_FDEC_AVX512 5 ; dst, perm, tmp, row1, row2
    movu     %1,      [r2+(%4  )*FDEC_STRIDE]
    vmovddup %1 {k1}, [r2+(%4+2)*FDEC_STRIDE]
    movu     %3,      [r2+(%5  )*FDEC_STRIDE]
    vmovddup %3 {k1}, [r2+(%5+2)*FDEC_STRIDE]
    vpermt2d %1, %2, %3
%endmacro

cglobal sub8x8_dct, 3,3
    mova       m0, [dct_avx512]
    DCT8x8_LOAD_FENC_AVX512 m1, m0, 0, 4 ; 0 2 1 3
    mov       r1d, 0xaaaaaaaa
    kmovd      k1, r1d
    psrld      m0, 5
    DCT8x8_LOAD_FDEC_AVX512 m3, m0, m2, 0, 4
    mov       r1d, 0xf0f0f0f0
    kmovd      k2, r1d
    pxor      xm4, xm4
    knotw      k3, k2
    call dct4x4x4_internal_avx512
    mova     [r0], m0
    mova  [r0+64], m1
    RET

%macro SUB4x16_DCT_AVX512 2 ; dst, src
    vpermd   m1, m5, [r1+1*%2*64]
    mova     m3,     [r2+2*%2*64]
    vpermt2d m3, m6, [r2+2*%2*64+64]
    call dct4x4x4_internal_avx512
    mova [r0+%1*64    ], m0
    mova [r0+%1*64+128], m1
%endmacro

cglobal sub16x16_dct
    psrld    m5, [dct_avx512], 10
    mov     eax, 0xaaaaaaaa
    kmovd    k1, eax
    mov     eax, 0xf0f0f0f0
    kmovd    k2, eax
    PROLOGUE 3,3
    pxor    xm4, xm4
    knotw    k3, k2
    psrld    m6, m5, 4
    SUB4x16_DCT_AVX512 0, 0
    SUB4x16_DCT_AVX512 1, 1
    SUB4x16_DCT_AVX512 4, 2
    SUB4x16_DCT_AVX512 5, 3
    RET

cglobal sub8x8_dct_dc, 3,3
    mova         m3, [dct_avx512]
    DCT8x8_LOAD_FENC_AVX512 m0, m3, 0, 4 ; 0 2 1 3
    mov         r1d, 0xaa
    kmovb        k1, r1d
    psrld        m3, 5
    DCT8x8_LOAD_FDEC_AVX512 m1, m3, m2, 0, 4
    pxor        xm3, xm3
    psadbw       m0, m3
    psadbw       m1, m3
    psubw        m0, m1
    vpmovqw    xmm0, m0
    vprold     xmm1, xmm0, 16
    paddw      xmm0, xmm1       ; 0 0 2 2 1 1 3 3
    punpckhqdq xmm2, xmm0, xmm0
    psubw      xmm1, xmm0, xmm2 ; 0-1 0-1 2-3 2-3
    paddw      xmm0, xmm2       ; 0+1 0+1 2+3 2+3
    punpckldq  xmm0, xmm1       ; 0+1 0+1 0-1 0-1 2+3 2+3 2-3 2-3
    punpcklqdq xmm1, xmm0, xmm0
    vpsubw     xmm0 {k1}, xm3, xmm0
    paddw      xmm0, xmm1       ; 0+1+2+3 0+1-2-3 0-1+2-3 0-1-2+3
    movhps     [r0], xmm0
    RET

cglobal sub8x16_dct_dc, 3,3
    mova         m5, [dct_avx512]
    DCT8x8_LOAD_FENC_AVX512 m0, m5, 0, 8  ; 0 4 1 5
    DCT8x8_LOAD_FENC_AVX512 m1, m5, 4, 12 ; 2 6 3 7
    mov         r1d, 0xaa
    kmovb        k1, r1d
    psrld        m5, 5
    DCT8x8_LOAD_FDEC_AVX512 m2, m5, m4, 0, 8
    DCT8x8_LOAD_FDEC_AVX512 m3, m5, m4, 4, 12
    pxor        xm4, xm4
    psadbw       m0, m4
    psadbw       m1, m4
    psadbw       m2, m4
    psadbw       m3, m4
    psubw        m0, m2
    psubw        m1, m3
    SBUTTERFLY  qdq, 0, 1, 2
    paddw        m0, m1
    vpmovqw    xmm0, m0         ; 0 2 4 6 1 3 5 7
    psrlq      xmm2, xmm0, 32
    psubw      xmm1, xmm0, xmm2 ; 0-4 2-6 1-5 3-7
    paddw      xmm0, xmm2       ; 0+4 2+6 1+5 3+7
    punpckhdq  xmm2, xmm0, xmm1
    punpckldq  xmm0, xmm1
    psubw      xmm1, xmm0, xmm2 ; 0-1+4-5 2-3+6-7 0-1-4+5 2-3-6+7
    paddw      xmm0, xmm2       ; 0+1+4+5 2+3+6+7 0+1-4-5 2+3-6-7
    punpcklwd  xmm0, xmm1
    psrlq      xmm2, xmm0, 32
    psubw      xmm1, xmm0, xmm2 ; 0+1-2-3+4+5-6-7 0-1-2+3+4-5-6+7 0+1-2-3-4-5+6+7 0-1-2+3-4+5+6-7
    paddw      xmm0, xmm2       ; 0+1+2+3+4+5+6+7 0-1+2-3+4-5+6-7 0+1+2+3-4-5-6-7 0-1+2-3-4+5-6+7
    shufps     xmm0, xmm1, q0220
    mova       [r0], xmm0
    RET

%macro SARSUMSUB 3 ; a, b, tmp
    mova    m%3, m%1
    vpsraw  m%1 {k1}, 1
    psubw   m%1, m%2    ; 0-2 1>>1-3
    vpsraw  m%2 {k1}, 1
    paddw   m%2, m%3    ; 0+2 1+3>>1
%endmacro

cglobal add8x8_idct, 2,2
    mova            m1, [r1]
    mova            m2, [r1+64]
    mova            m3, [dct_avx512]
    vbroadcasti32x4 m4, [pw_32]
    mov            r1d, 0xf0f0f0f0
    kxnorb          k2, k2, k2
    kmovd           k1, r1d
    kmovb           k3, k2
    vshufi32x4      m0, m1, m2, q2020 ; 0 1   4 5   8 9   c d
    vshufi32x4      m1, m2, q3131     ; 2 3   6 7   a b   e f
    psrlq           m5, m3, 56        ; {0, 3, 1, 2, 4, 7, 5, 6} * FDEC_STRIDE
    vpgatherqq      m6 {k2}, [r0+m5]
    SARSUMSUB        0, 1, 2
    SBUTTERFLY      wd, 1, 0, 2
    psrlq           m7, m3, 28
    SUMSUB_BA        w, 0, 1, 2       ; 0+1+2+3>>1 0+1>>1-2-3
    vprold          m1, 16            ; 0-1>>1-2+3 0-1+2-3>>1
    SBUTTERFLY      dq, 0, 1, 2
    psrlq           m3, 24
    SARSUMSUB        0, 1, 2
    vpermi2q        m3, m1, m0
    vpermt2q        m1, m7, m0
    paddw           m3, m4            ; += 32
    SUMSUB_BA        w, 1, 3, 0
    psraw           m1, 6             ; 0'+1'+2'+3'>>1 0'+1'>>1-2'-3'
    psraw           m3, 6             ; 0'-1'+2'-3'>>1 0'-1'>>1-2'+3'
    pxor           xm0, xm0
    SBUTTERFLY      bw, 6, 0, 2
    paddsw          m1, m6
    paddsw          m3, m0
    packuswb        m1, m3
    vpscatterqq [r0+m5] {k3}, m1
    RET
%endif ; HIGH_BIT_DEPTH

INIT_MMX
;-----------------------------------------------------------------------------
; void sub8x8_dct( int16_t dct[4][4][4], uint8_t *pix1, uint8_t *pix2 )
;-----------------------------------------------------------------------------
%macro SUB_NxN_DCT 7
cglobal %1, 3,3,%7
%if HIGH_BIT_DEPTH == 0
%if mmsize == 8
    pxor m7, m7
%else
    add r2, 4*FDEC_STRIDE
    mova m7, [hsub_mul]
%endif
%endif ; !HIGH_BIT_DEPTH
.skip_prologue:
    call %2.skip_prologue
    add  r0, %3
    add  r1, %4-%5-%6*FENC_STRIDE
    add  r2, %4-%5-%6*FDEC_STRIDE
    call %2.skip_prologue
    add  r0, %3
    add  r1, (%4-%6)*FENC_STRIDE-%5-%4
    add  r2, (%4-%6)*FDEC_STRIDE-%5-%4
    call %2.skip_prologue
    add  r0, %3
    add  r1, %4-%5-%6*FENC_STRIDE
    add  r2, %4-%5-%6*FDEC_STRIDE
    TAIL_CALL %2.skip_prologue, 1
%endmacro

;-----------------------------------------------------------------------------
; void add8x8_idct( uint8_t *pix, int16_t dct[4][4][4] )
;-----------------------------------------------------------------------------
%macro ADD_NxN_IDCT 6-7
%if HIGH_BIT_DEPTH
cglobal %1, 2,2,%7
%if %3==256
    add r1, 128
%endif
%else
cglobal %1, 2,2,11
    pxor m7, m7
%endif
%if mmsize>=16 && %3!=256
    add  r0, 4*FDEC_STRIDE
%endif
.skip_prologue:
    call %2.skip_prologue
    add  r0, %4-%5-%6*FDEC_STRIDE
    add  r1, %3
    call %2.skip_prologue
    add  r0, (%4-%6)*FDEC_STRIDE-%5-%4
    add  r1, %3
    call %2.skip_prologue
    add  r0, %4-%5-%6*FDEC_STRIDE
    add  r1, %3
    TAIL_CALL %2.skip_prologue, 1
%endmacro

%if HIGH_BIT_DEPTH
INIT_MMX
SUB_NxN_DCT  sub8x8_dct_mmx,     sub4x4_dct_mmx,   64,  8, 0, 0, 0
SUB_NxN_DCT  sub16x16_dct_mmx,   sub8x8_dct_mmx,   64, 16, 8, 8, 0
INIT_XMM
ADD_NxN_IDCT add8x8_idct_sse2,   add4x4_idct_sse2, 64,  8, 0, 0, 6
ADD_NxN_IDCT add16x16_idct_sse2, add8x8_idct_sse2, 64, 16, 8, 8, 6
ADD_NxN_IDCT add8x8_idct_avx,    add4x4_idct_avx,  64,  8, 0, 0, 6
ADD_NxN_IDCT add16x16_idct_avx,  add8x8_idct_avx,  64, 16, 8, 8, 6
cextern add8x8_idct8_sse2.skip_prologue
cextern add8x8_idct8_avx.skip_prologue
ADD_NxN_IDCT add16x16_idct8_sse2, add8x8_idct8_sse2, 256, 16, 0, 0, 16
ADD_NxN_IDCT add16x16_idct8_avx,  add8x8_idct8_avx,  256, 16, 0, 0, 16
cextern sub8x8_dct8_sse2.skip_prologue
cextern sub8x8_dct8_sse4.skip_prologue
cextern sub8x8_dct8_avx.skip_prologue
SUB_NxN_DCT  sub16x16_dct8_sse2, sub8x8_dct8_sse2, 256, 16, 0, 0, 14
SUB_NxN_DCT  sub16x16_dct8_sse4, sub8x8_dct8_sse4, 256, 16, 0, 0, 14
SUB_NxN_DCT  sub16x16_dct8_avx,  sub8x8_dct8_avx,  256, 16, 0, 0, 14
%else ; !HIGH_BIT_DEPTH
%if ARCH_X86_64 == 0
INIT_MMX
SUB_NxN_DCT  sub8x8_dct_mmx,     sub4x4_dct_mmx,   32, 4, 0, 0, 0
ADD_NxN_IDCT add8x8_idct_mmx,    add4x4_idct_mmx,  32, 4, 0, 0
SUB_NxN_DCT  sub16x16_dct_mmx,   sub8x8_dct_mmx,   32, 8, 4, 4, 0
ADD_NxN_IDCT add16x16_idct_mmx,  add8x8_idct_mmx,  32, 8, 4, 4

cextern sub8x8_dct8_mmx.skip_prologue
cextern add8x8_idct8_mmx.skip_prologue
SUB_NxN_DCT  sub16x16_dct8_mmx,  sub8x8_dct8_mmx,  128, 8, 0, 0, 0
ADD_NxN_IDCT add16x16_idct8_mmx, add8x8_idct8_mmx, 128, 8, 0, 0
%endif

INIT_XMM
cextern sub8x8_dct_sse2.skip_prologue
cextern sub8x8_dct_ssse3.skip_prologue
cextern sub8x8_dct_avx.skip_prologue
cextern sub8x8_dct_xop.skip_prologue
SUB_NxN_DCT  sub16x16_dct_sse2,  sub8x8_dct_sse2,  128, 8, 0, 0, 10
SUB_NxN_DCT  sub16x16_dct_ssse3, sub8x8_dct_ssse3, 128, 8, 0, 0, 10
SUB_NxN_DCT  sub16x16_dct_avx,   sub8x8_dct_avx,   128, 8, 0, 0, 10
SUB_NxN_DCT  sub16x16_dct_xop,   sub8x8_dct_xop,   128, 8, 0, 0, 10

cextern add8x8_idct_sse2.skip_prologue
cextern add8x8_idct_avx.skip_prologue
ADD_NxN_IDCT add16x16_idct_sse2, add8x8_idct_sse2, 128, 8, 0, 0
ADD_NxN_IDCT add16x16_idct_avx,  add8x8_idct_avx,  128, 8, 0, 0

cextern add8x8_idct8_sse2.skip_prologue
cextern add8x8_idct8_avx.skip_prologue
ADD_NxN_IDCT add16x16_idct8_sse2, add8x8_idct8_sse2, 128, 8, 0, 0
ADD_NxN_IDCT add16x16_idct8_avx,  add8x8_idct8_avx,  128, 8, 0, 0

cextern sub8x8_dct8_sse2.skip_prologue
cextern sub8x8_dct8_ssse3.skip_prologue
cextern sub8x8_dct8_avx.skip_prologue
SUB_NxN_DCT  sub16x16_dct8_sse2,  sub8x8_dct8_sse2,  128, 8, 0, 0, 11
SUB_NxN_DCT  sub16x16_dct8_ssse3, sub8x8_dct8_ssse3, 128, 8, 0, 0, 11
SUB_NxN_DCT  sub16x16_dct8_avx,   sub8x8_dct8_avx,   128, 8, 0, 0, 11

INIT_YMM
ADD_NxN_IDCT add16x16_idct_avx2, add8x8_idct_avx2, 128, 8, 0, 0
%endif ; HIGH_BIT_DEPTH

%if HIGH_BIT_DEPTH
;-----------------------------------------------------------------------------
; void add8x8_idct_dc( pixel *p_dst, dctcoef *dct2x2 )
;-----------------------------------------------------------------------------
%macro ADD_DC 2
    mova    m0, [%1+FDEC_STRIDEB*0] ; 8pixels
    mova    m1, [%1+FDEC_STRIDEB*1]
    mova    m2, [%1+FDEC_STRIDEB*2]
    paddsw  m0, %2
    paddsw  m1, %2
    paddsw  m2, %2
    paddsw  %2, [%1+FDEC_STRIDEB*3]
    CLIPW   m0, m5, m6
    CLIPW   m1, m5, m6
    CLIPW   m2, m5, m6
    CLIPW   %2, m5, m6
    mova    [%1+FDEC_STRIDEB*0], m0
    mova    [%1+FDEC_STRIDEB*1], m1
    mova    [%1+FDEC_STRIDEB*2], m2
    mova    [%1+FDEC_STRIDEB*3], %2
%endmacro

%macro ADD_IDCT_DC 0
cglobal add8x8_idct_dc, 2,2,7
    mova        m6, [pw_pixel_max]
    pxor        m5, m5
    mova        m3, [r1]
    paddd       m3, [pd_32]
    psrad       m3, 6         ; dc0   0 dc1   0 dc2   0 dc3   0
    pshuflw     m4, m3, q2200 ; dc0 dc0 dc1 dc1   _   _   _   _
    pshufhw     m3, m3, q2200 ;   _   _   _   _ dc2 dc2 dc3 dc3
    pshufd      m4, m4, q1100 ; dc0 dc0 dc0 dc0 dc1 dc1 dc1 dc1
    pshufd      m3, m3, q3322 ; dc2 dc2 dc2 dc2 dc3 dc3 dc3 dc3
    ADD_DC r0+FDEC_STRIDEB*0, m4
    ADD_DC r0+FDEC_STRIDEB*4, m3
    RET

cglobal add16x16_idct_dc, 2,3,8
    mov         r2, 4
    mova        m6, [pw_pixel_max]
    mova        m7, [pd_32]
    pxor        m5, m5
.loop:
    mova        m3, [r1]
    paddd       m3, m7
    psrad       m3, 6         ; dc0   0 dc1   0 dc2   0 dc3   0
    pshuflw     m4, m3, q2200 ; dc0 dc0 dc1 dc1   _   _   _   _
    pshufhw     m3, m3, q2200 ;   _   _   _   _ dc2 dc2 dc3 dc3
    pshufd      m4, m4, q1100 ; dc0 dc0 dc0 dc0 dc1 dc1 dc1 dc1
    pshufd      m3, m3, q3322 ; dc2 dc2 dc2 dc2 dc3 dc3 dc3 dc3
    ADD_DC r0+FDEC_STRIDEB*0, m4
    ADD_DC r0+SIZEOF_PIXEL*8, m3
    add         r1, 16
    add         r0, 4*FDEC_STRIDEB
    dec         r2
    jg .loop
    RET
%endmacro ; ADD_IDCT_DC

INIT_XMM sse2
ADD_IDCT_DC
INIT_XMM avx
ADD_IDCT_DC

%else ;!HIGH_BIT_DEPTH
%macro ADD_DC 3
    mova    m4, [%3+FDEC_STRIDE*0]
    mova    m5, [%3+FDEC_STRIDE*1]
    mova    m6, [%3+FDEC_STRIDE*2]
    paddusb m4, %1
    paddusb m5, %1
    paddusb m6, %1
    paddusb %1, [%3+FDEC_STRIDE*3]
    psubusb m4, %2
    psubusb m5, %2
    psubusb m6, %2
    psubusb %1, %2
    mova [%3+FDEC_STRIDE*0], m4
    mova [%3+FDEC_STRIDE*1], m5
    mova [%3+FDEC_STRIDE*2], m6
    mova [%3+FDEC_STRIDE*3], %1
%endmacro

INIT_MMX mmx2
cglobal add8x8_idct_dc, 2,2
    mova      m0, [r1]
    pxor      m1, m1
    add       r0, FDEC_STRIDE*4
    paddw     m0, [pw_32]
    psraw     m0, 6
    psubw     m1, m0
    packuswb  m0, m0
    packuswb  m1, m1
    punpcklbw m0, m0
    punpcklbw m1, m1
    pshufw    m2, m0, q3322
    pshufw    m3, m1, q3322
    punpcklbw m0, m0
    punpcklbw m1, m1
    ADD_DC    m0, m1, r0-FDEC_STRIDE*4
    ADD_DC    m2, m3, r0
    RET

INIT_XMM ssse3
cglobal add8x8_idct_dc, 2,2
    movh     m0, [r1]
    pxor     m1, m1
    add      r0, FDEC_STRIDE*4
    pmulhrsw m0, [pw_512]
    psubw    m1, m0
    mova     m5, [pb_unpackbd1]
    packuswb m0, m0
    packuswb m1, m1
    pshufb   m0, m5
    pshufb   m1, m5
    movh     m2, [r0+FDEC_STRIDE*-4]
    movh     m3, [r0+FDEC_STRIDE*-3]
    movh     m4, [r0+FDEC_STRIDE*-2]
    movh     m5, [r0+FDEC_STRIDE*-1]
    movhps   m2, [r0+FDEC_STRIDE* 0]
    movhps   m3, [r0+FDEC_STRIDE* 1]
    movhps   m4, [r0+FDEC_STRIDE* 2]
    movhps   m5, [r0+FDEC_STRIDE* 3]
    paddusb  m2, m0
    paddusb  m3, m0
    paddusb  m4, m0
    paddusb  m5, m0
    psubusb  m2, m1
    psubusb  m3, m1
    psubusb  m4, m1
    psubusb  m5, m1
    movh   [r0+FDEC_STRIDE*-4], m2
    movh   [r0+FDEC_STRIDE*-3], m3
    movh   [r0+FDEC_STRIDE*-2], m4
    movh   [r0+FDEC_STRIDE*-1], m5
    movhps [r0+FDEC_STRIDE* 0], m2
    movhps [r0+FDEC_STRIDE* 1], m3
    movhps [r0+FDEC_STRIDE* 2], m4
    movhps [r0+FDEC_STRIDE* 3], m5
    RET

INIT_MMX mmx2
cglobal add16x16_idct_dc, 2,3
    mov       r2, 4
.loop:
    mova      m0, [r1]
    pxor      m1, m1
    paddw     m0, [pw_32]
    psraw     m0, 6
    psubw     m1, m0
    packuswb  m0, m0
    packuswb  m1, m1
    punpcklbw m0, m0
    punpcklbw m1, m1
    pshufw    m2, m0, q3322
    pshufw    m3, m1, q3322
    punpcklbw m0, m0
    punpcklbw m1, m1
    ADD_DC    m0, m1, r0
    ADD_DC    m2, m3, r0+8
    add       r1, 8
    add       r0, FDEC_STRIDE*4
    dec       r2
    jg .loop
    RET

INIT_XMM sse2
cglobal add16x16_idct_dc, 2,2,8
    call .loop
    add       r0, FDEC_STRIDE*4
    TAIL_CALL .loop, 0
.loop:
    add       r0, FDEC_STRIDE*4
    movq      m0, [r1+0]
    movq      m2, [r1+8]
    add       r1, 16
    punpcklwd m0, m0
    punpcklwd m2, m2
    pxor      m3, m3
    paddw     m0, [pw_32]
    paddw     m2, [pw_32]
    psraw     m0, 6
    psraw     m2, 6
    psubw     m1, m3, m0
    packuswb  m0, m1
    psubw     m3, m2
    punpckhbw m1, m0, m0
    packuswb  m2, m3
    punpckhbw m3, m2, m2
    punpcklbw m0, m0
    punpcklbw m2, m2
    ADD_DC    m0, m1, r0+FDEC_STRIDE*-4
    ADD_DC    m2, m3, r0
    ret

%macro ADD16x16 0
cglobal add16x16_idct_dc, 2,2,8
    call .loop
    add      r0, FDEC_STRIDE*4
    TAIL_CALL .loop, 0
.loop:
    add      r0, FDEC_STRIDE*4
    mova     m0, [r1]
    add      r1, 16
    pxor     m1, m1
    pmulhrsw m0, [pw_512]
    psubw    m1, m0
    mova     m5, [pb_unpackbd1]
    mova     m6, [pb_unpackbd2]
    packuswb m0, m0
    packuswb m1, m1
    pshufb   m2, m0, m6
    pshufb   m0, m5
    pshufb   m3, m1, m6
    pshufb   m1, m5
    ADD_DC   m0, m1, r0+FDEC_STRIDE*-4
    ADD_DC   m2, m3, r0
    ret
%endmacro ; ADD16x16

INIT_XMM ssse3
ADD16x16
INIT_XMM avx
ADD16x16

%macro ADD_DC_AVX2 3
    mova   xm4, [r0+FDEC_STRIDE*0+%3]
    mova   xm5, [r0+FDEC_STRIDE*1+%3]
    vinserti128 m4, m4, [r2+FDEC_STRIDE*0+%3], 1
    vinserti128 m5, m5, [r2+FDEC_STRIDE*1+%3], 1
    paddusb m4, %1
    paddusb m5, %1
    psubusb m4, %2
    psubusb m5, %2
    mova [r0+FDEC_STRIDE*0+%3], xm4
    mova [r0+FDEC_STRIDE*1+%3], xm5
    vextracti128 [r2+FDEC_STRIDE*0+%3], m4, 1
    vextracti128 [r2+FDEC_STRIDE*1+%3], m5, 1
%endmacro

INIT_YMM avx2
cglobal add16x16_idct_dc, 2,3,6
    add      r0, FDEC_STRIDE*4
    mova     m0, [r1]
    pxor     m1, m1
    pmulhrsw m0, [pw_512]
    psubw    m1, m0
    mova     m4, [pb_unpackbd1]
    mova     m5, [pb_unpackbd2]
    packuswb m0, m0
    packuswb m1, m1
    pshufb   m2, m0, m4      ; row0, row2
    pshufb   m3, m1, m4      ; row0, row2
    pshufb   m0, m5          ; row1, row3
    pshufb   m1, m5          ; row1, row3
    lea      r2, [r0+FDEC_STRIDE*8]
    ADD_DC_AVX2 m2, m3, FDEC_STRIDE*-4
    ADD_DC_AVX2 m2, m3, FDEC_STRIDE*-2
    ADD_DC_AVX2 m0, m1, FDEC_STRIDE* 0
    ADD_DC_AVX2 m0, m1, FDEC_STRIDE* 2
    RET

%endif ; HIGH_BIT_DEPTH

;-----------------------------------------------------------------------------
; void sub8x8_dct_dc( int16_t dct[2][2], uint8_t *pix1, uint8_t *pix2 )
;-----------------------------------------------------------------------------

%macro DCTDC_2ROW_MMX 4
    mova      %1, [r1+FENC_STRIDE*(0+%3)]
    mova      m1, [r1+FENC_STRIDE*(1+%3)]
    mova      m2, [r2+FDEC_STRIDE*(0+%4)]
    mova      m3, [r2+FDEC_STRIDE*(1+%4)]
    mova      %2, %1
    punpckldq %1, m1
    punpckhdq %2, m1
    mova      m1, m2
    punpckldq m2, m3
    punpckhdq m1, m3
    pxor      m3, m3
    psadbw    %1, m3
    psadbw    %2, m3
    psadbw    m2, m3
    psadbw    m1, m3
    psubw     %1, m2
    psubw     %2, m1
%endmacro

%macro DCT2x2 2 ; reg s1/s0, reg s3/s2 (!=m0/m1)
    PSHUFLW   m1, %1, q2200  ;  s1  s1  s0  s0
    PSHUFLW   m0, %2, q2301  ;  s3  __  s2  __
    paddw     m1, %2         ;  s1 s13  s0 s02
    psubw     m1, m0         ; d13 s13 d02 s02
    PSHUFLW   m0, m1, q1010  ; d02 s02 d02 s02
    psrlq     m1, 32         ;  __  __ d13 s13
    paddw     m0, m1         ; d02 s02 d02+d13 s02+s13
    psllq     m1, 32         ; d13 s13
    psubw     m0, m1         ; d02-d13 s02-s13 d02+d13 s02+s13
%endmacro

%if HIGH_BIT_DEPTH == 0
INIT_MMX mmx2
cglobal sub8x8_dct_dc, 3,3
    DCTDC_2ROW_MMX m0, m4, 0, 0
    DCTDC_2ROW_MMX m5, m6, 2, 2
    paddw     m0, m5
    paddw     m4, m6
    punpckldq m0, m4
    add       r2, FDEC_STRIDE*4
    DCTDC_2ROW_MMX m7, m4, 4, 0
    DCTDC_2ROW_MMX m5, m6, 6, 2
    paddw     m7, m5
    paddw     m4, m6
    punpckldq m7, m4
    DCT2x2    m0, m7
    mova    [r0], m0
    ret

%macro DCTDC_2ROW_SSE2 4
    movh      m1, [r1+FENC_STRIDE*(0+%1)]
    movh      m2, [r1+FENC_STRIDE*(1+%1)]
    punpckldq m1, m2
    movh      m2, [r2+FDEC_STRIDE*(0+%2)]
    punpckldq m2, [r2+FDEC_STRIDE*(1+%2)]
    psadbw    m1, m0
    psadbw    m2, m0
    ACCUM  paddd, %4, 1, %3
    psubd    m%4, m2
%endmacro

INIT_XMM sse2
cglobal sub8x8_dct_dc, 3,3
    pxor     m0, m0
    DCTDC_2ROW_SSE2 0, 0, 0, 3
    DCTDC_2ROW_SSE2 2, 2, 1, 3
    add      r2, FDEC_STRIDE*4
    DCTDC_2ROW_SSE2 4, 0, 0, 4
    DCTDC_2ROW_SSE2 6, 2, 1, 4
    packssdw m3, m3
    packssdw m4, m4
    DCT2x2   m3, m4
    movq   [r0], m0
    RET

%macro SUB8x16_DCT_DC 0
cglobal sub8x16_dct_dc, 3,3
    pxor       m0, m0
    DCTDC_2ROW_SSE2 0, 0, 0, 3
    DCTDC_2ROW_SSE2 2, 2, 1, 3
    add        r1, FENC_STRIDE*8
    add        r2, FDEC_STRIDE*8
    DCTDC_2ROW_SSE2 -4, -4, 0, 4
    DCTDC_2ROW_SSE2 -2, -2, 1, 4
    shufps     m3, m4, q2020
    DCTDC_2ROW_SSE2 0, 0, 0, 5
    DCTDC_2ROW_SSE2 2, 2, 1, 5
    add        r2, FDEC_STRIDE*4
    DCTDC_2ROW_SSE2 4, 0, 0, 4
    DCTDC_2ROW_SSE2 6, 2, 1, 4
    shufps     m5, m4, q2020
%if cpuflag(ssse3)
    %define %%sign psignw
%else
    %define %%sign pmullw
%endif
    SUMSUB_BA d, 5, 3, 0
    packssdw   m5, m3
    pshuflw    m0, m5, q2301
    pshufhw    m0, m0, q2301
    %%sign     m5, [pw_pmpmpmpm]
    paddw      m0, m5
    pshufd     m1, m0, q1320
    pshufd     m0, m0, q0231
    %%sign     m1, [pw_ppppmmmm]
    paddw      m0, m1
    mova     [r0], m0
    RET
%endmacro ; SUB8x16_DCT_DC

INIT_XMM sse2
SUB8x16_DCT_DC
INIT_XMM ssse3
SUB8x16_DCT_DC

%endif ; !HIGH_BIT_DEPTH

%macro DCTDC_4ROW_SSE2 2
    mova       %1, [r1+FENC_STRIDEB*%2]
    mova       m0, [r2+FDEC_STRIDEB*%2]
%assign Y (%2+1)
%rep 3
    paddw      %1, [r1+FENC_STRIDEB*Y]
    paddw      m0, [r2+FDEC_STRIDEB*Y]
%assign Y (Y+1)
%endrep
    psubw      %1, m0
    pshufd     m0, %1, q2301
    paddw      %1, m0
%endmacro

%if HIGH_BIT_DEPTH
%macro SUB8x8_DCT_DC_10 0
cglobal sub8x8_dct_dc, 3,3,3
    DCTDC_4ROW_SSE2 m1, 0
    DCTDC_4ROW_SSE2 m2, 4
    mova       m0, [pw_ppmmmmpp]
    pmaddwd    m1, m0
    pmaddwd    m2, m0
    pshufd     m0, m1, q2200      ; -1 -1 +0 +0
    pshufd     m1, m1, q0033      ; +0 +0 +1 +1
    paddd      m1, m0
    pshufd     m0, m2, q1023      ; -2 +2 -3 +3
    paddd      m1, m2
    paddd      m1, m0
    mova     [r0], m1
    RET
%endmacro
INIT_XMM sse2
SUB8x8_DCT_DC_10

%macro SUB8x16_DCT_DC_10 0
cglobal sub8x16_dct_dc, 3,3,6
    DCTDC_4ROW_SSE2 m1, 0
    DCTDC_4ROW_SSE2 m2, 4
    DCTDC_4ROW_SSE2 m3, 8
    DCTDC_4ROW_SSE2 m4, 12
    mova       m0, [pw_ppmmmmpp]
    pmaddwd    m1, m0
    pmaddwd    m2, m0
    pshufd     m5, m1, q2200      ; -1 -1 +0 +0
    pshufd     m1, m1, q0033      ; +0 +0 +1 +1
    paddd      m1, m5
    pshufd     m5, m2, q1023      ; -2 +2 -3 +3
    paddd      m1, m2
    paddd      m1, m5             ; a6 a2 a4 a0
    pmaddwd    m3, m0
    pmaddwd    m4, m0
    pshufd     m5, m3, q2200
    pshufd     m3, m3, q0033
    paddd      m3, m5
    pshufd     m5, m4, q1023
    paddd      m3, m4
    paddd      m3, m5             ; a7 a3 a5 a1
    paddd      m0, m1, m3
    psubd      m1, m3
    pshufd     m0, m0, q3120
    pshufd     m1, m1, q3120
    punpcklqdq m2, m0, m1
    punpckhqdq m1, m0
    mova  [r0+ 0], m2
    mova  [r0+16], m1
    RET
%endmacro
INIT_XMM sse2
SUB8x16_DCT_DC_10
INIT_XMM avx
SUB8x16_DCT_DC_10
%endif

;-----------------------------------------------------------------------------
; void zigzag_scan_8x8_frame( int16_t level[64], int16_t dct[8][8] )
;-----------------------------------------------------------------------------
%macro SCAN_8x8 0
cglobal zigzag_scan_8x8_frame, 2,2,8
    movdqa    xmm0, [r1]
    movdqa    xmm1, [r1+16]
    movdq2q    mm0, xmm0
    PALIGNR   xmm1, xmm1, 14, xmm2
    movdq2q    mm1, xmm1

    movdqa    xmm2, [r1+32]
    movdqa    xmm3, [r1+48]
    PALIGNR   xmm2, xmm2, 12, xmm4
    movdq2q    mm2, xmm2
    PALIGNR   xmm3, xmm3, 10, xmm4
    movdq2q    mm3, xmm3

    punpckhwd xmm0, xmm1
    punpckhwd xmm2, xmm3

    movq       mm4, mm1
    movq       mm5, mm1
    movq       mm6, mm2
    movq       mm7, mm3
    punpckhwd  mm1, mm0
    psllq      mm0, 16
    psrlq      mm3, 16
    punpckhdq  mm1, mm1
    punpckhdq  mm2, mm0
    punpcklwd  mm0, mm4
    punpckhwd  mm4, mm3
    punpcklwd  mm4, mm2
    punpckhdq  mm0, mm2
    punpcklwd  mm6, mm3
    punpcklwd  mm5, mm7
    punpcklwd  mm5, mm6

    movdqa    xmm4, [r1+64]
    movdqa    xmm5, [r1+80]
    movdqa    xmm6, [r1+96]
    movdqa    xmm7, [r1+112]

    movq [r0+2*00], mm0
    movq [r0+2*04], mm4
    movd [r0+2*08], mm1
    movq [r0+2*36], mm5
    movq [r0+2*46], mm6

    PALIGNR   xmm4, xmm4, 14, xmm3
    movdq2q    mm4, xmm4
    PALIGNR   xmm5, xmm5, 12, xmm3
    movdq2q    mm5, xmm5
    PALIGNR   xmm6, xmm6, 10, xmm3
    movdq2q    mm6, xmm6
%if cpuflag(ssse3)
    PALIGNR   xmm7, xmm7, 8, xmm3
    movdq2q    mm7, xmm7
%else
    movhlps   xmm3, xmm7
    punpcklqdq xmm7, xmm7
    movdq2q    mm7, xmm3
%endif

    punpckhwd xmm4, xmm5
    punpckhwd xmm6, xmm7

    movq       mm0, mm4
    movq       mm1, mm5
    movq       mm3, mm7
    punpcklwd  mm7, mm6
    psrlq      mm6, 16
    punpcklwd  mm4, mm6
    punpcklwd  mm5, mm4
    punpckhdq  mm4, mm3
    punpcklwd  mm3, mm6
    punpckhwd  mm3, mm4
    punpckhwd  mm0, mm1
    punpckldq  mm4, mm0
    punpckhdq  mm0, mm6
    pshufw     mm4, mm4, q1230

    movq [r0+2*14], mm4
    movq [r0+2*25], mm0
    movd [r0+2*54], mm7
    movq [r0+2*56], mm5
    movq [r0+2*60], mm3

    punpckhdq xmm3, xmm0, xmm2
    punpckldq xmm0, xmm2
    punpckhdq xmm7, xmm4, xmm6
    punpckldq xmm4, xmm6
    pshufhw   xmm0, xmm0, q0123
    pshuflw   xmm4, xmm4, q0123
    pshufhw   xmm3, xmm3, q0123
    pshuflw   xmm7, xmm7, q0123

    movlps [r0+2*10], xmm0
    movhps [r0+2*17], xmm0
    movlps [r0+2*21], xmm3
    movlps [r0+2*28], xmm4
    movhps [r0+2*32], xmm3
    movhps [r0+2*39], xmm4
    movlps [r0+2*43], xmm7
    movhps [r0+2*50], xmm7

    RET
%endmacro

%if HIGH_BIT_DEPTH == 0
INIT_XMM sse2
SCAN_8x8
INIT_XMM ssse3
SCAN_8x8
%endif

;-----------------------------------------------------------------------------
; void zigzag_scan_8x8_frame( dctcoef level[64], dctcoef dct[8][8] )
;-----------------------------------------------------------------------------
; Output order:
;  0  8  1  2  9 16 24 17
; 10  3  4 11 18 25 32 40
; 33 26 19 12  5  6 13 20
; 27 34 41 48 56 49 42 35
; 28 21 14  7 15 22 29 36
; 43 50 57 58 51 44 37 30
; 23 31 38 45 52 59 60 53
; 46 39 47 54 61 62 55 63
%macro SCAN_8x8_FRAME 5
cglobal zigzag_scan_8x8_frame, 2,2,8
    mova        m0, [r1]
    mova        m1, [r1+ 8*SIZEOF_DCTCOEF]
    movu        m2, [r1+14*SIZEOF_DCTCOEF]
    movu        m3, [r1+21*SIZEOF_DCTCOEF]
    mova        m4, [r1+28*SIZEOF_DCTCOEF]
    punpckl%4   m5, m0, m1
    psrl%2      m0, %1
    punpckh%4   m6, m1, m0
    punpckl%3   m5, m0
    punpckl%3   m1, m1
    punpckh%4   m1, m3
    mova        m7, [r1+52*SIZEOF_DCTCOEF]
    mova        m0, [r1+60*SIZEOF_DCTCOEF]
    punpckh%4   m1, m2
    punpckl%4   m2, m4
    punpckh%4   m4, m3
    punpckl%3   m3, m3
    punpckh%4   m3, m2
    mova      [r0], m5
    mova  [r0+ 4*SIZEOF_DCTCOEF], m1
    mova  [r0+ 8*SIZEOF_DCTCOEF], m6
    punpckl%4   m6, m0
    punpckl%4   m6, m7
    mova        m1, [r1+32*SIZEOF_DCTCOEF]
    movu        m5, [r1+39*SIZEOF_DCTCOEF]
    movu        m2, [r1+46*SIZEOF_DCTCOEF]
    movu [r0+35*SIZEOF_DCTCOEF], m3
    movu [r0+47*SIZEOF_DCTCOEF], m4
    punpckh%4   m7, m0
    psll%2      m0, %1
    punpckh%3   m3, m5, m5
    punpckl%4   m5, m1
    punpckh%4   m1, m2
    mova [r0+52*SIZEOF_DCTCOEF], m6
    movu [r0+13*SIZEOF_DCTCOEF], m5
    movu        m4, [r1+11*SIZEOF_DCTCOEF]
    movu        m6, [r1+25*SIZEOF_DCTCOEF]
    punpckl%4   m5, m7
    punpckl%4   m1, m3
    punpckh%3   m0, m7
    mova        m3, [r1+ 4*SIZEOF_DCTCOEF]
    movu        m7, [r1+18*SIZEOF_DCTCOEF]
    punpckl%4   m2, m5
    movu [r0+25*SIZEOF_DCTCOEF], m1
    mova        m1, m4
    mova        m5, m6
    punpckl%4   m4, m3
    punpckl%4   m6, m7
    punpckh%4   m1, m3
    punpckh%4   m5, m7
    punpckh%3   m3, m6, m4
    punpckh%3   m7, m5, m1
    punpckl%3   m6, m4
    punpckl%3   m5, m1
    movu        m4, [r1+35*SIZEOF_DCTCOEF]
    movu        m1, [r1+49*SIZEOF_DCTCOEF]
    pshuf%5     m6, m6, q0123
    pshuf%5     m5, m5, q0123
    mova [r0+60*SIZEOF_DCTCOEF], m0
    mova [r0+56*SIZEOF_DCTCOEF], m2
    movu        m0, [r1+42*SIZEOF_DCTCOEF]
    mova        m2, [r1+56*SIZEOF_DCTCOEF]
    movu [r0+17*SIZEOF_DCTCOEF], m3
    mova [r0+32*SIZEOF_DCTCOEF], m7
    movu [r0+10*SIZEOF_DCTCOEF], m6
    movu [r0+21*SIZEOF_DCTCOEF], m5
    punpckh%4   m3, m0, m4
    punpckh%4   m7, m2, m1
    punpckl%4   m0, m4
    punpckl%4   m2, m1
    punpckl%3   m4, m2, m0
    punpckl%3   m1, m7, m3
    punpckh%3   m2, m0
    punpckh%3   m7, m3
    pshuf%5     m2, m2, q0123
    pshuf%5     m7, m7, q0123
    mova [r0+28*SIZEOF_DCTCOEF], m4
    movu [r0+43*SIZEOF_DCTCOEF], m1
    movu [r0+39*SIZEOF_DCTCOEF], m2
    movu [r0+50*SIZEOF_DCTCOEF], m7
    RET
%endmacro

%if HIGH_BIT_DEPTH
INIT_XMM sse2
SCAN_8x8_FRAME 4 , dq, qdq, dq, d
INIT_XMM avx
SCAN_8x8_FRAME 4 , dq, qdq, dq, d
%else
INIT_MMX mmx2
SCAN_8x8_FRAME 16, q , dq , wd, w
%endif

;-----------------------------------------------------------------------------
; void zigzag_scan_4x4_frame( dctcoef level[16], dctcoef dct[4][4] )
;-----------------------------------------------------------------------------
%macro SCAN_4x4 4
cglobal zigzag_scan_4x4_frame, 2,2,6
    mova      m0, [r1+ 0*SIZEOF_DCTCOEF]
    mova      m1, [r1+ 4*SIZEOF_DCTCOEF]
    mova      m2, [r1+ 8*SIZEOF_DCTCOEF]
    mova      m3, [r1+12*SIZEOF_DCTCOEF]
    punpckl%4 m4, m0, m1
    psrl%2    m0, %1
    punpckl%3 m4, m0
    mova  [r0+ 0*SIZEOF_DCTCOEF], m4
    punpckh%4 m0, m2
    punpckh%4 m4, m2, m3
    psll%2    m3, %1
    punpckl%3 m2, m2
    punpckl%4 m5, m1, m3
    punpckh%3 m1, m1
    punpckh%4 m5, m2
    punpckl%4 m1, m0
    punpckh%3 m3, m4
    mova [r0+ 4*SIZEOF_DCTCOEF], m5
    mova [r0+ 8*SIZEOF_DCTCOEF], m1
    mova [r0+12*SIZEOF_DCTCOEF], m3
    RET
%endmacro

%if HIGH_BIT_DEPTH
INIT_XMM sse2
SCAN_4x4  4, dq, qdq, dq
INIT_XMM avx
SCAN_4x4  4, dq, qdq, dq
%else
INIT_MMX mmx
SCAN_4x4 16, q , dq , wd

;-----------------------------------------------------------------------------
; void zigzag_scan_4x4_frame( int16_t level[16], int16_t dct[4][4] )
;-----------------------------------------------------------------------------
%macro SCAN_4x4_FRAME 0
cglobal zigzag_scan_4x4_frame, 2,2
    mova    m1, [r1+16]
    mova    m0, [r1+ 0]
    pshufb  m1, [pb_scan4frameb]
    pshufb  m0, [pb_scan4framea]
    psrldq  m2, m1, 6
    palignr m1, m0, 6
    pslldq  m0, 10
    palignr m2, m0, 10
    mova [r0+ 0], m1
    mova [r0+16], m2
    RET
%endmacro

INIT_XMM ssse3
SCAN_4x4_FRAME
INIT_XMM avx
SCAN_4x4_FRAME

INIT_XMM xop
cglobal zigzag_scan_4x4_frame, 2,2
    mova   m0, [r1+ 0]
    mova   m1, [r1+16]
    vpperm m2, m0, m1, [pb_scan4frame2a]
    vpperm m1, m0, m1, [pb_scan4frame2b]
    mova [r0+ 0], m2
    mova [r0+16], m1
    RET
%endif ; !HIGH_BIT_DEPTH

%if HIGH_BIT_DEPTH
;-----------------------------------------------------------------------------
; void zigzag_scan_4x4_field( int32_t level[16], int32_t dct[4][4] )
;-----------------------------------------------------------------------------
INIT_XMM sse2
cglobal zigzag_scan_4x4_field, 2,2
    movu       m0, [r1+ 8]
    pshufd     m0, m0, q3102
    mova       m1, [r1+32]
    mova       m2, [r1+48]
    movu  [r0+ 8], m0
    mova  [r0+32], m1
    mova  [r0+48], m2
    movq      mm0, [r1]
    movq     [r0], mm0
    movq      mm0, [r1+24]
    movq  [r0+24], mm0
    RET
%else
;-----------------------------------------------------------------------------
; void zigzag_scan_4x4_field( int16_t level[16], int16_t dct[4][4] )
;-----------------------------------------------------------------------------
INIT_XMM sse
cglobal zigzag_scan_4x4_field, 2,2
    mova       m0, [r1]
    mova       m1, [r1+16]
    pshufw    mm0, [r1+4], q3102
    mova     [r0], m0
    mova  [r0+16], m1
    movq   [r0+4], mm0
    RET
%endif ; HIGH_BIT_DEPTH

;-----------------------------------------------------------------------------
; void zigzag_scan_8x8_field( int16_t level[64], int16_t dct[8][8] )
;-----------------------------------------------------------------------------
; Output order:
;  0  1  2  8  9  3  4 10
; 16 11  5  6  7 12 17 24
; 18 13 14 15 19 25 32 26
; 20 21 22 23 27 33 40 34
; 28 29 30 31 35 41 48 42
; 36 37 38 39 43 49 50 44
; 45 46 47 51 56 57 52 53
; 54 55 58 59 60 61 62 63
%undef SCAN_8x8
%macro SCAN_8x8 5
cglobal zigzag_scan_8x8_field, 2,3,8
    mova       m0, [r1+ 0*SIZEOF_DCTCOEF]       ; 03 02 01 00
    mova       m1, [r1+ 4*SIZEOF_DCTCOEF]       ; 07 06 05 04
    mova       m2, [r1+ 8*SIZEOF_DCTCOEF]       ; 11 10 09 08
    pshuf%1    m3, m0, q3333                    ; 03 03 03 03
    movd      r2d, m2                           ; 09 08
    pshuf%1    m2, m2, q0321                    ; 08 11 10 09
    punpckl%2  m3, m1                           ; 05 03 04 03
    pinsr%1    m0, r2d, 3                       ; 08 02 01 00
    punpckl%2  m4, m2, m3                       ; 04 10 03 09
    pshuf%1    m4, m4, q2310                    ; 10 04 03 09
    mova  [r0+ 0*SIZEOF_DCTCOEF], m0            ; 08 02 01 00
    mova  [r0+ 4*SIZEOF_DCTCOEF], m4            ; 10 04 03 09
    mova       m3, [r1+12*SIZEOF_DCTCOEF]       ; 15 14 13 12
    mova       m5, [r1+16*SIZEOF_DCTCOEF]       ; 19 18 17 16
    punpckl%3  m6, m5                           ; 17 16 XX XX
    psrl%4     m1, %5                           ; XX 07 06 05
    punpckh%2  m6, m2                           ; 08 17 11 16
    punpckl%3  m6, m1                           ; 06 05 11 16
    mova  [r0+ 8*SIZEOF_DCTCOEF], m6            ; 06 05 11 16
    psrl%4     m1, %5                           ; XX XX 07 06
    punpckl%2  m1, m5                           ; 17 07 16 06
    mova       m0, [r1+20*SIZEOF_DCTCOEF]       ; 23 22 21 20
    mova       m2, [r1+24*SIZEOF_DCTCOEF]       ; 27 26 25 24
    punpckh%3  m1, m1                           ; 17 07 17 07
    punpckl%2  m6, m3, m2                       ; 25 13 24 12
    pextr%1    r2d, m5, 2
    mova [r0+24*SIZEOF_DCTCOEF], m0             ; 23 22 21 20
    punpckl%2  m1, m6                           ; 24 17 12 07
    mova [r0+12*SIZEOF_DCTCOEF], m1
    pinsr%1    m3, r2d, 0                       ; 15 14 13 18
    mova [r0+16*SIZEOF_DCTCOEF], m3             ; 15 14 13 18
    mova       m7, [r1+28*SIZEOF_DCTCOEF]
    mova       m0, [r1+32*SIZEOF_DCTCOEF]       ; 35 34 33 32
    psrl%4     m5, %5*3                         ; XX XX XX 19
    pshuf%1    m1, m2, q3321                    ; 27 27 26 25
    punpckl%2  m5, m0                           ; 33 XX 32 19
    psrl%4     m2, %5*3                         ; XX XX XX 27
    punpckl%2  m5, m1                           ; 26 32 25 19
    mova [r0+32*SIZEOF_DCTCOEF], m7
    mova [r0+20*SIZEOF_DCTCOEF], m5             ; 26 32 25 19
    mova       m7, [r1+36*SIZEOF_DCTCOEF]
    mova       m1, [r1+40*SIZEOF_DCTCOEF]       ; 43 42 41 40
    pshuf%1    m3, m0, q3321                    ; 35 35 34 33
    punpckl%2  m2, m1                           ; 41 XX 40 27
    mova [r0+40*SIZEOF_DCTCOEF], m7
    punpckl%2  m2, m3                           ; 34 40 33 27
    mova [r0+28*SIZEOF_DCTCOEF], m2
    mova       m7, [r1+44*SIZEOF_DCTCOEF]       ; 47 46 45 44
    mova       m2, [r1+48*SIZEOF_DCTCOEF]       ; 51 50 49 48
    psrl%4     m0, %5*3                         ; XX XX XX 35
    punpckl%2  m0, m2                           ; 49 XX 48 35
    pshuf%1    m3, m1, q3321                    ; 43 43 42 41
    punpckl%2  m0, m3                           ; 42 48 41 35
    mova [r0+36*SIZEOF_DCTCOEF], m0
    pextr%1     r2d, m2, 3                      ; 51
    psrl%4      m1, %5*3                        ; XX XX XX 43
    punpckl%2   m1, m7                          ; 45 XX 44 43
    psrl%4      m2, %5                          ; XX 51 50 49
    punpckl%2   m1, m2                          ; 50 44 49 43
    pshuf%1     m1, m1, q2310                   ; 44 50 49 43
    mova [r0+44*SIZEOF_DCTCOEF], m1
    psrl%4      m7, %5                          ; XX 47 46 45
    pinsr%1     m7, r2d, 3                      ; 51 47 46 45
    mova [r0+48*SIZEOF_DCTCOEF], m7
    mova        m0, [r1+56*SIZEOF_DCTCOEF]      ; 59 58 57 56
    mova        m1, [r1+52*SIZEOF_DCTCOEF]      ; 55 54 53 52
    mova        m7, [r1+60*SIZEOF_DCTCOEF]
    punpckl%3   m2, m0, m1                      ; 53 52 57 56
    punpckh%3   m1, m0                          ; 59 58 55 54
    mova [r0+52*SIZEOF_DCTCOEF], m2
    mova [r0+56*SIZEOF_DCTCOEF], m1
    mova [r0+60*SIZEOF_DCTCOEF], m7
    RET
%endmacro
%if HIGH_BIT_DEPTH
INIT_XMM sse4
SCAN_8x8 d, dq, qdq, dq, 4
INIT_XMM avx
SCAN_8x8 d, dq, qdq, dq, 4
%else
INIT_MMX mmx2
SCAN_8x8 w, wd, dq , q , 16
%endif

;-----------------------------------------------------------------------------
; void zigzag_sub_4x4_frame( int16_t level[16], const uint8_t *src, uint8_t *dst )
;-----------------------------------------------------------------------------
%macro ZIGZAG_SUB_4x4 2
%ifidn %1, ac
cglobal zigzag_sub_4x4%1_%2, 4,4,8
%else
cglobal zigzag_sub_4x4%1_%2, 3,3,8
%endif
    movd      m0, [r1+0*FENC_STRIDE]
    movd      m1, [r1+1*FENC_STRIDE]
    movd      m2, [r1+2*FENC_STRIDE]
    movd      m3, [r1+3*FENC_STRIDE]
    movd      m4, [r2+0*FDEC_STRIDE]
    movd      m5, [r2+1*FDEC_STRIDE]
    movd      m6, [r2+2*FDEC_STRIDE]
    movd      m7, [r2+3*FDEC_STRIDE]
    movd [r2+0*FDEC_STRIDE], m0
    movd [r2+1*FDEC_STRIDE], m1
    movd [r2+2*FDEC_STRIDE], m2
    movd [r2+3*FDEC_STRIDE], m3
    punpckldq  m0, m1
    punpckldq  m2, m3
    punpckldq  m4, m5
    punpckldq  m6, m7
    punpcklqdq m0, m2
    punpcklqdq m4, m6
    mova      m7, [pb_sub4%2]
    pshufb    m0, m7
    pshufb    m4, m7
    mova      m7, [hsub_mul]
    punpckhbw m1, m0, m4
    punpcklbw m0, m4
    pmaddubsw m1, m7
    pmaddubsw m0, m7
%ifidn %1, ac
    movd     r2d, m0
    pand      m0, [pb_subacmask]
%endif
    mova [r0+ 0], m0
    por       m0, m1
    pxor      m2, m2
    mova [r0+16], m1
    pcmpeqb   m0, m2
    pmovmskb eax, m0
%ifidn %1, ac
    mov     [r3], r2w
%endif
    sub      eax, 0xffff
    shr      eax, 31
    RET
%endmacro

%if HIGH_BIT_DEPTH == 0
INIT_XMM ssse3
ZIGZAG_SUB_4x4   , frame
ZIGZAG_SUB_4x4 ac, frame
ZIGZAG_SUB_4x4   , field
ZIGZAG_SUB_4x4 ac, field
INIT_XMM avx
ZIGZAG_SUB_4x4   , frame
ZIGZAG_SUB_4x4 ac, frame
ZIGZAG_SUB_4x4   , field
ZIGZAG_SUB_4x4 ac, field
%endif ; !HIGH_BIT_DEPTH

%if HIGH_BIT_DEPTH == 0
INIT_XMM xop
cglobal zigzag_scan_8x8_field, 2,3,7
    lea        r2, [pb_scan8field1]
    %define off(m) (r2+m-pb_scan8field1)
    mova       m0, [r1+  0]
    mova       m1, [r1+ 16]
    vpperm     m5, m0, m1, [off(pb_scan8field1)]
    mova [r0+  0], m5
    vpperm     m0, m0, m1, [off(pb_scan8field2a)]
    mova       m2, [r1+ 32]
    mova       m3, [r1+ 48]
    vpperm     m5, m2, m3, [off(pb_scan8field2b)]
    por        m5, m0
    mova [r0+ 16], m5
    mova       m4, [off(pb_scan8field3b)]
    vpperm     m1, m1, m2, [off(pb_scan8field3a)]
    mova       m0, [r1+ 64]
    vpperm     m5, m3, m0, m4
    por        m5, m1
    mova [r0+ 32], m5
    ; 4b, 5b are the same as pb_scan8field3b.
    ; 5a is the same as pb_scan8field4a.
    mova       m5, [off(pb_scan8field4a)]
    vpperm     m2, m2, m3, m5
    mova       m1, [r1+ 80]
    vpperm     m6, m0, m1, m4
    por        m6, m2
    mova [r0+ 48], m6
    vpperm     m3, m3, m0, m5
    mova       m2, [r1+ 96]
    vpperm     m5, m1, m2, m4
    por        m5, m3
    mova [r0+ 64], m5
    vpperm     m5, m0, m1, [off(pb_scan8field6)]
    mova [r0+ 80], m5
    vpperm     m5, m1, m2, [off(pb_scan8field7)]
    mov       r2d, [r1+ 98]
    mov  [r0+ 90], r2d
    mova [r0+ 96], m5
    mova       m3, [r1+112]
    movd [r0+104], m3
    mov       r2d, [r1+108]
    mova [r0+112], m3
    mov  [r0+112], r2d
    %undef off
    RET

cglobal zigzag_scan_8x8_frame, 2,3,8
    lea        r2, [pb_scan8frame1]
    %define off(m) (r2+m-pb_scan8frame1)
    mova       m7, [r1+ 16]
    mova       m3, [r1+ 32]
    vpperm     m7, m7, m3, [off(pb_scan8framet1)] ;  8  9 14 15 16 17 21 22
    mova       m2, [r1+ 48]
    vpperm     m0, m3, m2, [off(pb_scan8framet2)] ; 18 19 20 23 25 31 26 30
    mova       m1, [r1+ 80]
    mova       m4, [r1+ 64]
    vpperm     m3, m4, m1, [off(pb_scan8framet3)] ; 32 33 37 38 40 43 44 45
    vpperm     m6, m0, m3, [off(pb_scan8framet4)] ; 18 23 25 31 32 38 40 45
    vpperm     m5, m0, m3, [off(pb_scan8framet5)] ; 19 20 26 30 33 37 43 44
    vpperm     m3, m2, m4, [off(pb_scan8framet6)] ; 24 27 28 29 34 35 36 39
    mova       m4, [r1+ 96]
    vpperm     m4, m1, m4, [off(pb_scan8framet7)] ; 41 42 46 47 48 49 54 55
    mova       m1, [r1+  0]
    vpperm     m2, m1, m3, [off(pb_scan8framet8)] ;  0  1  2  7 24 28 29 36
    vpperm     m1, m2, m7, [off(pb_scan8frame1)]  ;  0  8  1  2  9 16 24 17
    mova [r0+  0], m1
    movh       m0, [r1+  6]
    movhps     m0, [r1+ 20]                       ;  3  4  5  6 10 11 12 13
    vpperm     m1, m0, m6, [off(pb_scan8frame2)]  ; 10  3  4 11 18 25 32 40
    mova [r0+ 16], m1
    vpperm     m1, m0, m5, [off(pb_scan8frame3)]  ; 33 26 19 12  5  6 13 20
    mova [r0+ 32], m1
    vpperm     m1, m2, m7, [off(pb_scan8frame5)]  ; 28 21 14  7 15 22 29 36
    mova [r0+ 64], m1
    movh       m0, [r1+100]
    movhps     m0, [r1+114]                       ; 50 51 52 53 57 58 59 60
    vpperm     m1, m5, m0, [off(pb_scan8frame6)]  ; 43 50 57 58 51 44 37 30
    mova [r0+ 80], m1
    vpperm     m1, m6, m0, [off(pb_scan8frame7)]  ; 23 31 38 45 52 59 60 53
    mova [r0+ 96], m1
    mova       m1, [r1+112]
    vpperm     m0, m3, m1, [off(pb_scan8framet9)] ; 27 34 35 39 56 61 62 63
    vpperm     m1, m0, m4, [off(pb_scan8frame4)]  ; 27 34 41 48 56 49 42 35
    mova [r0+ 48], m1
    vpperm     m1, m0, m4, [off(pb_scan8frame8)]  ; 46 39 47 54 61 62 55 63
    mova [r0+112], m1
    %undef off
    RET
%endif

;-----------------------------------------------------------------------------
; void zigzag_interleave_8x8_cavlc( int16_t *dst, int16_t *src, uint8_t *nnz )
;-----------------------------------------------------------------------------
%macro INTERLEAVE 2
    mova     m0, [r1+(%1*4+ 0)*SIZEOF_PIXEL]
    mova     m1, [r1+(%1*4+ 8)*SIZEOF_PIXEL]
    mova     m2, [r1+(%1*4+16)*SIZEOF_PIXEL]
    mova     m3, [r1+(%1*4+24)*SIZEOF_PIXEL]
    TRANSPOSE4x4%2 0,1,2,3,4
    mova     [r0+(%1+ 0)*SIZEOF_PIXEL], m0
    mova     [r0+(%1+32)*SIZEOF_PIXEL], m1
    mova     [r0+(%1+64)*SIZEOF_PIXEL], m2
    mova     [r0+(%1+96)*SIZEOF_PIXEL], m3
    packsswb m0, m1
    ACCUM   por, 6, 2, %1
    ACCUM   por, 7, 3, %1
    ACCUM   por, 5, 0, %1
%endmacro

%macro ZIGZAG_8x8_CAVLC 1
cglobal zigzag_interleave_8x8_cavlc, 3,3,8
    INTERLEAVE  0, %1
    INTERLEAVE  8, %1
    INTERLEAVE 16, %1
    INTERLEAVE 24, %1
    packsswb   m6, m7
    packsswb   m5, m6
    packsswb   m5, m5
    pxor       m0, m0
%if HIGH_BIT_DEPTH
    packsswb   m5, m5
%endif
    pcmpeqb    m5, m0
    paddb      m5, [pb_1]
    movd      r0d, m5
    mov    [r2+0], r0w
    shr       r0d, 16
    mov    [r2+8], r0w
    RET
%endmacro

%if HIGH_BIT_DEPTH
INIT_XMM sse2
ZIGZAG_8x8_CAVLC D
INIT_XMM avx
ZIGZAG_8x8_CAVLC D
%else
INIT_MMX mmx
ZIGZAG_8x8_CAVLC W
%endif

%macro INTERLEAVE_XMM 1
    mova   m0, [r1+%1*4+ 0]
    mova   m1, [r1+%1*4+16]
    mova   m4, [r1+%1*4+32]
    mova   m5, [r1+%1*4+48]
    SBUTTERFLY wd, 0, 1, 6
    SBUTTERFLY wd, 4, 5, 7
    SBUTTERFLY wd, 0, 1, 6
    SBUTTERFLY wd, 4, 5, 7
    movh   [r0+%1+  0], m0
    movhps [r0+%1+ 32], m0
    movh   [r0+%1+ 64], m1
    movhps [r0+%1+ 96], m1
    movh   [r0+%1+  8], m4
    movhps [r0+%1+ 40], m4
    movh   [r0+%1+ 72], m5
    movhps [r0+%1+104], m5
    ACCUM por, 2, 0, %1
    ACCUM por, 3, 1, %1
    por    m2, m4
    por    m3, m5
%endmacro

%if HIGH_BIT_DEPTH == 0
%macro ZIGZAG_8x8_CAVLC 0
cglobal zigzag_interleave_8x8_cavlc, 3,3,8
    INTERLEAVE_XMM  0
    INTERLEAVE_XMM 16
    packsswb m2, m3
    pxor     m5, m5
    packsswb m2, m2
    packsswb m2, m2
    pcmpeqb  m5, m2
    paddb    m5, [pb_1]
    movd    r0d, m5
    mov  [r2+0], r0w
    shr     r0d, 16
    mov  [r2+8], r0w
    RET
%endmacro

INIT_XMM sse2
ZIGZAG_8x8_CAVLC
INIT_XMM avx
ZIGZAG_8x8_CAVLC

INIT_YMM avx2
cglobal zigzag_interleave_8x8_cavlc, 3,3,6
    mova   m0, [r1+ 0]
    mova   m1, [r1+32]
    mova   m2, [r1+64]
    mova   m3, [r1+96]
    mova   m5, [deinterleave_shufd]
    SBUTTERFLY wd, 0, 1, 4
    SBUTTERFLY wd, 2, 3, 4
    SBUTTERFLY wd, 0, 1, 4
    SBUTTERFLY wd, 2, 3, 4
    vpermd m0, m5, m0
    vpermd m1, m5, m1
    vpermd m2, m5, m2
    vpermd m3, m5, m3
    mova [r0+  0], xm0
    mova [r0+ 16], xm2
    vextracti128 [r0+ 32], m0, 1
    vextracti128 [r0+ 48], m2, 1
    mova [r0+ 64], xm1
    mova [r0+ 80], xm3
    vextracti128 [r0+ 96], m1, 1
    vextracti128 [r0+112], m3, 1

    packsswb m0, m2          ; nnz0, nnz1
    packsswb m1, m3          ; nnz2, nnz3
    packsswb m0, m1          ; {nnz0,nnz2}, {nnz1,nnz3}
    vpermq   m0, m0, q3120   ; {nnz0,nnz1}, {nnz2,nnz3}
    pxor     m5, m5
    pcmpeqq  m0, m5
    pmovmskb r0d, m0
    not     r0d
    and     r0d, 0x01010101
    mov  [r2+0], r0w
    shr     r0d, 16
    mov  [r2+8], r0w
    RET
%endif ; !HIGH_BIT_DEPTH

%if HIGH_BIT_DEPTH
INIT_ZMM avx512
cglobal zigzag_scan_4x4_frame, 2,2
    mova        m0, [scan_frame_avx512]
    vpermd      m0, m0, [r1]
    mova      [r0], m0
    RET

cglobal zigzag_scan_4x4_field, 2,2
    mova        m0, [r1]
    pshufd    xmm1, [r1+8], q3102
    mova      [r0], m0
    movu    [r0+8], xmm1
    RET

cglobal zigzag_scan_8x8_frame, 2,2
    psrld       m0, [scan_frame_avx512], 4
    mova        m1, [r1+0*64]
    mova        m2, [r1+1*64]
    mova        m3, [r1+2*64]
    mova        m4, [r1+3*64]
    mov        r1d, 0x01fe7f80
    kmovd       k1, r1d
    kshiftrd    k2, k1, 16
    vpermd      m5, m0, m3  ; __ __ __ __ __ __ __ __ __ __ __ __ __ __ 32 40
    psrld       m6, m0, 5
    vpermi2d    m0, m1, m2  ;  0  8  1  2  9 16 24 17 10  3  4 11 18 25 __ __
    vmovdqa64   m0 {k1}, m5
    mova [r0+0*64], m0
    mova        m5, m1
    vpermt2d    m1, m6, m2  ; __ 26 19 12  5  6 13 20 27 __ __ __ __ __ __ __
    psrld       m0, m6, 5
    vpermi2d    m6, m3, m4  ; 33 __ __ __ __ __ __ __ __ 34 41 48 56 49 42 35
    vmovdqa32   m6 {k2}, m1
    mova [r0+1*64], m6
    vpermt2d    m5, m0, m2  ; 28 21 14  7 15 22 29 __ __ __ __ __ __ __ __ 30
    psrld       m1, m0, 5
    vpermi2d    m0, m3, m4  ; __ __ __ __ __ __ __ 36 43 50 57 58 51 44 37 __
    vmovdqa32   m5 {k1}, m0
    mova [r0+2*64], m5
    vpermt2d    m3, m1, m4  ; __ __ 38 45 52 59 60 53 46 39 47 54 61 62 55 63
    vpermd      m2, m1, m2  ; 23 31 __ __ __ __ __ __ __ __ __ __ __ __ __ __
    vmovdqa64   m2 {k2}, m3
    mova [r0+3*64], m2
    RET

cglobal zigzag_scan_8x8_field, 2,2
    mova        m0, [scan_field_avx512]
    mova        m1, [r1+0*64]
    mova        m2, [r1+1*64]
    mova        m3, [r1+2*64]
    mova        m4, [r1+3*64]
    mov        r1d, 0x3f
    kmovb       k1, r1d
    psrld       m5, m0, 5
    vpermi2d    m0, m1, m2
    vmovdqa64   m1 {k1}, m3 ; 32 33 34 35 36 37 38 39 40 41 42 43 12 13 14 15
    vpermt2d    m1, m5, m2
    psrld       m5, 5
    vmovdqa64   m2 {k1}, m4 ; 48 49 50 51 52 53 54 55 56 57 58 59 28 29 30 31
    vpermt2d    m2, m5, m3
    psrld       m5, 5
    vpermt2d    m3, m5, m4
    mova [r0+0*64], m0
    mova [r0+1*64], m1
    mova [r0+2*64], m2
    mova [r0+3*64], m3
    RET

cglobal zigzag_interleave_8x8_cavlc, 3,3
    mova        m0, [cavlc_shuf_avx512]
    mova        m1, [r1+0*64]
    mova        m2, [r1+1*64]
    mova        m3, [r1+2*64]
    mova        m4, [r1+3*64]
    kxnorb      k1, k1, k1
    por         m7, m1, m2
    psrld       m5, m0, 5
    vpermi2d    m0, m1, m2        ; a0 a1 b0 b1
    vpternlogd  m7, m3, m4, 0xfe  ; m1|m2|m3|m4
    psrld       m6, m5, 5
    vpermi2d    m5, m3, m4        ; b2 b3 a2 a3
    vptestmd    k0, m7, m7
    vpermt2d    m1, m6, m2        ; c0 c1 d0 d1
    psrld       m6, 5
    vpermt2d    m3, m6, m4        ; d2 d3 c2 c3
    vshufi32x4  m2, m0, m5, q1032 ; b0 b1 b2 b3
    vmovdqa32   m5 {k1}, m0       ; a0 a1 a2 a3
    vshufi32x4  m4, m1, m3, q1032 ; d0 d1 d2 d3
    vmovdqa32   m3 {k1}, m1       ; c0 c1 c2 c3
    mova [r0+0*64], m5
    mova [r0+1*64], m2
    mova [r0+2*64], m3
    mova [r0+3*64], m4
    kmovw      r1d, k0
    test       r1d, 0x1111
    setnz     [r2]
    test       r1d, 0x2222
    setnz   [r2+1]
    test       r1d, 0x4444
    setnz   [r2+8]
    test       r1d, 0x8888
    setnz   [r2+9]
    RET

%else ; !HIGH_BIT_DEPTH
INIT_YMM avx512
cglobal zigzag_scan_4x4_frame, 2,2
    mova        m0, [scan_frame_avx512]
    vpermw      m0, m0, [r1]
    mova      [r0], m0
    RET

cglobal zigzag_scan_4x4_field, 2,2
    mova        m0, [r1]
    pshuflw   xmm1, [r1+4], q3102
    mova      [r0], m0
    movq    [r0+4], xmm1
    RET

INIT_ZMM avx512
cglobal zigzag_scan_8x8_frame, 2,2
    psrlw       m0, [scan_frame_avx512], 4
scan8_avx512:
    mova        m1, [r1]
    mova        m2, [r1+64]
    psrlw       m3, m0, 6
    vpermi2w    m0, m1, m2
    vpermt2w    m1, m3, m2
    mova      [r0], m0
    mova   [r0+64], m1
    RET

cglobal zigzag_scan_8x8_field, 2,2
    mova        m0, [scan_field_avx512]
    jmp scan8_avx512

cglobal zigzag_interleave_8x8_cavlc, 3,3
    mova       m0, [cavlc_shuf_avx512]
    mova       m1, [r1]
    mova       m2, [r1+64]
    psrlw      m3, m0, 6
    vpermi2w   m0, m1, m2
    vpermt2w   m1, m3, m2
    kxnorb     k2, k2, k2
    vptestmd   k0, m0, m0
    vptestmd   k1, m1, m1
    mova     [r0], m0
    mova  [r0+64], m1
    ktestw     k2, k0
    setnz    [r2]
    setnc  [r2+1]
    ktestw     k2, k1
    setnz  [r2+8]
    setnc  [r2+9]
    RET
%endif ; !HIGH_BIT_DEPTH
