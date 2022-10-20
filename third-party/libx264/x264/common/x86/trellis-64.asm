;*****************************************************************************
;* trellis-64.asm: x86_64 trellis quantization
;*****************************************************************************
;* Copyright (C) 2012-2022 x264 project
;*
;* Authors: Loren Merritt <lorenm@u.washington.edu>
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

; This is a pretty straight-forward translation of the C code, except:
; * simd ssd and psy: 2x parallel, handling the 2 candidate values of abs_level.
; * simd trellis_coef0, ZERO_LEVEL_IDX, and the coef0 part of the main loop:
;   4x parallel, handling 4 node_ctxs of the same coef (even if some of those
;   nodes are invalid).
; * Interprocedural register allocation. Eliminates argument-passing overhead
;   to trellis_coef* subroutines. Also reduces codesize.

; Optimizations that I tried, and rejected because they were not faster:
; * Separate loops for node_ctx [4..7] or smaller subsets of [0..3].
;   Costs too much icache compared to the negligible speedup.
; * There are only 21 possible sets of live node_ctxs; we could keep track of
;   exactly which set we're in and feed that (along with abs_level) into a jump
;   table instead of the switch to select a trellis_coef subroutine. This would
;   eliminate all branches about which node_ctxs are live, but costs either a
;   bunch of icache or a bunch of call/ret, and the jump table itself is
;   unpredictable.
; * Separate versions of trellis_coef* depending on whether we're doing the 1st
;   or the 2nd of the two abs_level candidates. This would eliminate some
;   branches about if(score is better).
; * Special case more values of coef. I had a coef2 at some intermediate point
;   in the optimization process, but it didn't end up worthwhile in conjunction
;   with all the other optimizations.
; * Unroll or simd writeback. I don't know why this didn't help.

%include "x86inc.asm"
%include "x86util.asm"

SECTION_RODATA

pd_m16: times 4 dd -16
sq_1: dq 1, 0
pq_128: times 2 dq 128
pq_ffffffff: times 2 dq 0xffffffff

cextern pd_8
cextern pd_0123
cextern pd_4567
cextern_common cabac_entropy
cextern_common cabac_transition
cextern cabac_size_unary
cextern cabac_transition_unary
cextern_common dct4_weight_tab
cextern_common dct8_weight_tab
cextern_common dct4_weight2_tab
cextern_common dct8_weight2_tab
cextern_common last_coeff_flag_offset_8x8
cextern_common significant_coeff_flag_offset_8x8
cextern_common coeff_flag_offset_chroma_422_dc

SECTION .text

%define TRELLIS_SCORE_BIAS 1<<60
%define SIZEOF_NODE 16
%define CABAC_SIZE_BITS 8
%define LAMBDA_BITS 4

%macro SQUARE 2 ; dst, tmp
    ; could use pmuldq here, to eliminate the abs. but that would involve
    ; templating a sse4 version of all of trellis, for negligible speedup.
%if cpuflag(ssse3)
    pabsd   m%1, m%1
    pmuludq m%1, m%1
%elif HIGH_BIT_DEPTH
    ABSD    m%2, m%1
    SWAP     %1, %2
    pmuludq m%1, m%1
%else
    pmuludq m%1, m%1
    pand    m%1, [pq_ffffffff]
%endif
%endmacro

%macro LOAD_DUP 2 ; dst, src
%if cpuflag(ssse3)
    movddup    %1, %2
%else
    movd       %1, %2
    punpcklqdq %1, %1
%endif
%endmacro

;-----------------------------------------------------------------------------
; int trellis_cabac_4x4_psy(
;     const int *unquant_mf, const uint8_t *zigzag, int lambda2,
;     int last_nnz, dctcoef *orig_coefs, dctcoef *quant_coefs, dctcoef *dct,
;     uint8_t *cabac_state_sig, uint8_t *cabac_state_last,
;     uint64_t level_state0, uint16_t level_state1,
;     int b_ac, dctcoef *fenc_dct, int psy_trellis )
;-----------------------------------------------------------------------------
%macro TRELLIS 4
%define num_coefs %2
%define dc %3
%define psy %4
cglobal %1, 4,15,9
    %assign level_tree_size 64*8*2*4 ; could depend on num_coefs, but nonuniform stack size would prevent accessing args from trellis_coef*
    %assign pad 96 + level_tree_size + 16*SIZEOF_NODE + 16-gprsize-(stack_offset&15)
    SUB  rsp, pad
    DEFINE_ARGS unquant_mf, zigzag, lambda2, ii, orig_coefs, quant_coefs, dct, cabac_state_sig, cabac_state_last
%if WIN64
    %define level_statem rsp+stack_offset+80 ; r9m, except that we need to index into it (and r10m) as an array
%else
    %define level_statem rsp+stack_offset+32
%endif
    %define b_acm r11m ; 4x4 only
    %define b_interlacedm r11m ; 8x8 only
    %define i_coefsm1 r11m ; dc only
    %define fenc_dctm r12m
    %define psy_trellism r13m
%if num_coefs == 64
    shl dword b_interlacedm, 6
    %define dct_weight1_tab dct8_weight_tab
    %define dct_weight2_tab dct8_weight2_tab
%else
    %define dct_weight1_tab dct4_weight_tab
    %define dct_weight2_tab dct4_weight2_tab
%endif

    %define stack rsp
    %define last_nnzm [stack+0]
    %define zigzagm   [stack+8]
    mov     last_nnzm, iid
    mov     zigzagm,   zigzagq
%if WIN64 == 0
    %define orig_coefsm  [stack+16]
    %define quant_coefsm [stack+24]
    mov     orig_coefsm,  orig_coefsq
    mov     quant_coefsm, quant_coefsq
%endif
    %define unquant_mfm   [stack+32]
    %define levelgt1_ctxm [stack+40]
    %define ssd            stack+48
    %define cost_siglast   stack+80
    %define level_tree     stack+96

    ; trellis_node_t is laid out differently than C.
    ; struct-of-arrays rather than array-of-structs, for simd.
    %define nodes_curq r7
    %define nodes_prevq r8
    %define node_score(x) x*8
    %define node_level_idx(x) 64+x*4
    %define node_cabac_state(x) 96+x*4
    lea nodes_curq, [level_tree + level_tree_size]
    lea nodes_prevq, [nodes_curq + 8*SIZEOF_NODE]
    mov        r6, TRELLIS_SCORE_BIAS
    mov       [nodes_curq + node_score(0)], r6
    mov dword [nodes_curq + node_level_idx(0)], 0
    movd      mm0, [level_statem + 0]
    punpcklbw mm0, [level_statem + 4]
    punpcklwd mm0, [level_statem + 8]
    %define level_state_packed mm0 ; version for copying into node.cabac_state
    pcmpeqb    m7, m7 ; TRELLIS_SCORE_MAX
    movq [nodes_curq + node_score(1)], m7
    mova [nodes_curq + node_score(2)], m7

    %define levels_usedq r4
    %define levels_usedd r4d
    mov dword [level_tree], 0
    mov       levels_usedd, 1

    %define abs_levelq r9
    %define abs_leveld r9d
    %define abs_coefq r14
    %define zigzagiq r5
    %define zigzagid r5d

%if num_coefs == 8
    mov dword levelgt1_ctxm, 8
%else
    mov dword levelgt1_ctxm, 9
%endif
%if psy
    LOAD_DUP m6, psy_trellism
    %define psy_trellis m6
%elif dc
    LOAD_DUP   m6, [unquant_mfq]
    paddd      m6, m6
    %define unquant_mf m6
%endif
%if dc == 0
    mov unquant_mfm, unquant_mfq
%endif
    ; Keep a single offset register to PICify all global constants.
    ; They're all relative to "beginning of this asm file's .text section",
    ; even tables that aren't in this file.
    ; (Any address in .text would work, this one was just convenient.)
    lea r0, [$$]
    %define GLOBAL +r0-$$

    TRELLIS_LOOP 0 ; node_ctx 0..3
    TRELLIS_LOOP 1 ; node_ctx 1..7

.writeback:
    ; int level = bnode->level_idx;
    ; for( int i = b_ac; i <= last_nnz; i++ )
    ;     dct[zigzag[i]] = SIGN(level_tree[level].abs_level, orig_coefs[zigzag[i]]);
    ;     level = level_tree[level].next;
    mov    iid, last_nnzm
    add zigzagq, iiq
    neg    iiq
%if num_coefs == 16 && dc == 0
    mov    r2d, b_acm
    add    iiq, r2
%endif
    %define dctq r10
    mov    r0d, [nodes_curq + node_level_idx(0) + rax*4]
.writeback_loop:
    movzx   r2, byte [zigzagq + iiq]
%if cpuflag(ssse3)
    movd    m0, [level_tree + r0*4]
    movzx   r0, word [level_tree + r0*4]
    psrld   m0, 16
    movd    m1, [dctq + r2*SIZEOF_DCTCOEF]
%if HIGH_BIT_DEPTH
    psignd  m0, m1
    movd [dctq + r2*SIZEOF_DCTCOEF], m0
%else
    psignw  m0, m1
    movd   r4d, m0
    mov  [dctq + r2*SIZEOF_DCTCOEF], r4w
%endif
%else
    mov    r5d, [level_tree + r0*4]
%if HIGH_BIT_DEPTH
    mov    r4d, dword [dctq + r2*SIZEOF_DCTCOEF]
%else
    movsx  r4d, word [dctq + r2*SIZEOF_DCTCOEF]
%endif
    movzx  r0d, r5w
    sar    r4d, 31
    shr    r5d, 16
    xor    r5d, r4d
    sub    r5d, r4d
%if HIGH_BIT_DEPTH
    mov  [dctq + r2*SIZEOF_DCTCOEF], r5d
%else
    mov  [dctq + r2*SIZEOF_DCTCOEF], r5w
%endif
%endif
    inc    iiq
    jle .writeback_loop

    mov eax, 1
.return:
    ADD rsp, pad
    RET

%if num_coefs == 16 && dc == 0
.return_zero:
    pxor       m0, m0
    mova [r10+ 0], m0
    mova [r10+16], m0
%if HIGH_BIT_DEPTH
    mova [r10+32], m0
    mova [r10+48], m0
%endif
    jmp .return
%endif
%endmacro ; TRELLIS



%macro TRELLIS_LOOP 1 ; ctx_hi
.i_loop%1:
    ; if( !quant_coefs[i] )
    mov   r6, quant_coefsm
%if HIGH_BIT_DEPTH
    mov   abs_leveld, dword [r6 + iiq*SIZEOF_DCTCOEF]
%else
    movsx abs_leveld, word [r6 + iiq*SIZEOF_DCTCOEF]
%endif

    ; int sigindex  = num_coefs == 64 ? significant_coeff_flag_offset_8x8[b_interlaced][i] :
    ;                 num_coefs == 8  ? coeff_flag_offset_chroma_422_dc[i] : i;
    mov    r10, cabac_state_sigm
%if num_coefs == 64
    mov    r6d, b_interlacedm
    add    r6d, iid
    movzx  r6d, byte [significant_coeff_flag_offset_8x8 + r6 GLOBAL]
    movzx  r10, byte [r10 + r6]
%elif num_coefs == 8
    movzx  r13, byte [coeff_flag_offset_chroma_422_dc + iiq GLOBAL]
    movzx  r10, byte [r10 + r13]
%else
    movzx  r10, byte [r10 + iiq]
%endif

    test  abs_leveld, abs_leveld
    jnz %%.nonzero_quant_coef

%if %1 == 0
    ; int cost_sig0 = x264_cabac_size_decision_noup2( &cabac_state_sig[sigindex], 0 )
    ;               * (uint64_t)lambda2 >> ( CABAC_SIZE_BITS - LAMBDA_BITS );
    ; nodes_cur[0].score -= cost_sig0;
    movzx  r10, word [cabac_entropy + r10*2 GLOBAL]
    imul   r10, lambda2q
    shr    r10, CABAC_SIZE_BITS - LAMBDA_BITS
    sub   [nodes_curq + node_score(0)], r10
%endif
    ZERO_LEVEL_IDX %1, cur
    jmp .i_continue%1

%%.nonzero_quant_coef:
    ; int sign_coef = orig_coefs[zigzag[i]];
    ; int abs_coef = abs( sign_coef );
    ; int q = abs( quant_coefs[i] );
    movzx   zigzagid, byte [zigzagq+iiq]
    movd    m0, abs_leveld
    mov     r6, orig_coefsm
%if HIGH_BIT_DEPTH
    LOAD_DUP m1, [r6 + zigzagiq*SIZEOF_DCTCOEF]
%else
    LOAD_DUP m1, [r6 + zigzagiq*SIZEOF_DCTCOEF - 2]
    psrad    m1, 16     ; sign_coef
%endif
    punpcklqdq m0, m0 ; quant_coef
%if cpuflag(ssse3)
    pabsd   m0, m0
    pabsd   m2, m1 ; abs_coef
%else
    pxor    m8, m8
    pcmpgtd m8, m1 ; sign_mask
    pxor    m0, m8
    pxor    m2, m1, m8
    psubd   m0, m8
    psubd   m2, m8
%endif
    psubd   m0, [sq_1] ; abs_level
    movd  abs_leveld, m0

    xchg  nodes_curq, nodes_prevq

    ; if( i < num_coefs-1 )
    ;     int lastindex = num_coefs == 64 ? last_coeff_flag_offset_8x8[i] : i;
    ;                     num_coefs == 8  ? coeff_flag_offset_chroma_422_dc[i] : i
    ;     cost_siglast[0] = x264_cabac_size_decision_noup2( &cabac_state_sig[sigindex], 0 );
    ;     cost_sig1       = x264_cabac_size_decision_noup2( &cabac_state_sig[sigindex], 1 );
    ;     cost_siglast[1] = x264_cabac_size_decision_noup2( &cabac_state_last[lastindex], 0 ) + cost_sig1;
    ;     cost_siglast[2] = x264_cabac_size_decision_noup2( &cabac_state_last[lastindex], 1 ) + cost_sig1;
%if %1 == 0
%if dc && num_coefs != 8
    cmp    iid, i_coefsm1
%else
    cmp    iid, num_coefs-1
%endif
    je %%.zero_siglast
%endif
    movzx  r11, word [cabac_entropy + r10*2 GLOBAL]
    xor    r10, 1
    movzx  r12, word [cabac_entropy + r10*2 GLOBAL]
    mov   [cost_siglast+0], r11d
    mov    r10, cabac_state_lastm
%if num_coefs == 64
    movzx  r6d, byte [last_coeff_flag_offset_8x8 + iiq GLOBAL]
    movzx  r10, byte [r10 + r6]
%elif num_coefs == 8
    movzx  r10, byte [r10 + r13]
%else
    movzx  r10, byte [r10 + iiq]
%endif
    movzx  r11, word [cabac_entropy + r10*2 GLOBAL]
    add    r11, r12
    mov   [cost_siglast+4], r11d
%if %1 == 0
    xor    r10, 1
    movzx  r10, word [cabac_entropy + r10*2 GLOBAL]
    add    r10, r12
    mov   [cost_siglast+8], r10d
%endif
%%.skip_siglast:

    ; int unquant_abs_level = ((unquant_mf[zigzag[i]] * abs_level + 128) >> 8);
    ; int d = abs_coef - unquant_abs_level;
    ; uint64_t ssd = (int64_t)d*d * coef_weight[i];
%if dc
    pmuludq m0, unquant_mf
%else
    mov    r10, unquant_mfm
    LOAD_DUP m3, [r10 + zigzagiq*4]
    pmuludq m0, m3
%endif
    paddd   m0, [pq_128]
    psrld   m0, 8 ; unquant_abs_level
%if psy || dc == 0
    mova    m4, m0
%endif
    psubd   m0, m2
    SQUARE   0, 3
%if dc
    psllq   m0, 8
%else
    LOAD_DUP m5, [dct_weight2_tab + zigzagiq*4 GLOBAL]
    pmuludq m0, m5
%endif

%if psy
    test   iid, iid
    jz %%.dc_rounding
    ; int predicted_coef = fenc_dct[zigzag[i]] - sign_coef
    ; int psy_value = abs(unquant_abs_level + SIGN(predicted_coef, sign_coef));
    ; int psy_weight = dct_weight_tab[zigzag[i]] * h->mb.i_psy_trellis;
    ; ssd1[k] -= psy_weight * psy_value;
    mov     r6, fenc_dctm
%if HIGH_BIT_DEPTH
    LOAD_DUP m3, [r6 + zigzagiq*SIZEOF_DCTCOEF]
%else
    LOAD_DUP m3, [r6 + zigzagiq*SIZEOF_DCTCOEF - 2]
    psrad   m3, 16 ; orig_coef
%endif
%if cpuflag(ssse3)
    psignd  m4, m1 ; SIGN(unquant_abs_level, sign_coef)
%else
    PSIGN d, m4, m8
%endif
    psubd   m3, m1 ; predicted_coef
    paddd   m4, m3
%if cpuflag(ssse3)
    pabsd   m4, m4
%else
    ABSD    m3, m4
    SWAP     4, 3
%endif
    LOAD_DUP m1, [dct_weight1_tab + zigzagiq*4 GLOBAL]
    pmuludq m1, psy_trellis
    pmuludq m4, m1
    psubq   m0, m4
%if %1
%%.dc_rounding:
%endif
%endif
%if %1 == 0
    mova [ssd], m0
%endif

%if dc == 0 && %1 == 0
    test   iid, iid
    jnz %%.skip_dc_rounding
%%.dc_rounding:
    ; Optimize rounding for DC coefficients in DC-only luma 4x4/8x8 blocks.
    ; int d = abs_coef - ((unquant_abs_level + (sign_coef>>31) + 8)&~15);
    ; uint64_t ssd = (int64_t)d*d * coef_weight[i];
    psrad   m1, 31 ; sign_coef>>31
    paddd   m4, [pd_8]
    paddd   m4, m1
    pand    m4, [pd_m16] ; (unquant_abs_level + (sign_coef>>31) + 8)&~15
    psubd   m4, m2 ; d
    SQUARE   4, 3
    pmuludq m4, m5
    mova [ssd], m4
%%.skip_dc_rounding:
%endif
    mova [ssd+16], m0

    %assign stack_offset_bak stack_offset
    cmp abs_leveld, 1
    jl %%.switch_coef0
%if %1 == 0
    mov    r10, [ssd] ; trellis_coef* args
%endif
    movq   r12, m0
    ; for( int j = 0; j < 8; j++ )
    ;     nodes_cur[j].score = TRELLIS_SCORE_MAX;
%if cpuflag(ssse3)
    mova [nodes_curq + node_score(0)], m7
    mova [nodes_curq + node_score(2)], m7
%else ; avoid store-forwarding stalls on k8/k10
%if %1 == 0
    movq [nodes_curq + node_score(0)], m7
%endif
    movq [nodes_curq + node_score(1)], m7
    movq [nodes_curq + node_score(2)], m7
    movq [nodes_curq + node_score(3)], m7
%endif
    mova [nodes_curq + node_score(4)], m7
    mova [nodes_curq + node_score(6)], m7
    je %%.switch_coef1
%%.switch_coefn:
    call trellis_coefn.entry%1
    call trellis_coefn.entry%1b
    jmp .i_continue1
%%.switch_coef1:
    call trellis_coef1.entry%1
    call trellis_coefn.entry%1b
    jmp .i_continue1
%%.switch_coef0:
    call trellis_coef0_%1
    call trellis_coef1.entry%1b

.i_continue%1:
    dec iid
%if num_coefs == 16 && dc == 0
    cmp iid, b_acm
%endif
    jge .i_loop%1

    call trellis_bnode_%1
%if %1 == 0
%if num_coefs == 16 && dc == 0
    jz .return_zero
%else
    jz .return
%endif
    jmp .writeback

%%.zero_siglast:
    xor  r6d, r6d
    mov [cost_siglast+0], r6
    mov [cost_siglast+8], r6d
    jmp %%.skip_siglast
%endif
%endmacro ; TRELLIS_LOOP

; just a synonym for %if
%macro IF0 1+
%endmacro
%macro IF1 1+
    %1
%endmacro

%macro ZERO_LEVEL_IDX 2 ; ctx_hi, prev
    ; for( int j = 0; j < 8; j++ )
    ;     nodes_cur[j].level_idx = levels_used;
    ;     level_tree[levels_used].next = (trellis_level_t){ .next = nodes_cur[j].level_idx, .abs_level = 0 };
    ;     levels_used++;
    add  levels_usedd, 3
    and  levels_usedd, ~3 ; allow aligned stores
    movd       m0, levels_usedd
    pshufd     m0, m0, 0
    IF%1 mova  m1, m0
         paddd m0, [pd_0123]
    IF%1 paddd m1, [pd_4567]
         mova  m2, [nodes_%2q + node_level_idx(0)]
    IF%1 mova  m3, [nodes_%2q + node_level_idx(4)]
         mova [nodes_curq + node_level_idx(0)], m0
    IF%1 mova [nodes_curq + node_level_idx(4)], m1
         mova [level_tree + (levels_usedq+0)*4], m2
    IF%1 mova [level_tree + (levels_usedq+4)*4], m3
    add  levels_usedd, (1+%1)*4
%endmacro

INIT_XMM sse2
TRELLIS trellis_cabac_4x4, 16, 0, 0
TRELLIS trellis_cabac_8x8, 64, 0, 0
TRELLIS trellis_cabac_4x4_psy, 16, 0, 1
TRELLIS trellis_cabac_8x8_psy, 64, 0, 1
TRELLIS trellis_cabac_dc, 16, 1, 0
TRELLIS trellis_cabac_chroma_422_dc, 8, 1, 0
INIT_XMM ssse3
TRELLIS trellis_cabac_4x4, 16, 0, 0
TRELLIS trellis_cabac_8x8, 64, 0, 0
TRELLIS trellis_cabac_4x4_psy, 16, 0, 1
TRELLIS trellis_cabac_8x8_psy, 64, 0, 1
TRELLIS trellis_cabac_dc, 16, 1, 0
TRELLIS trellis_cabac_chroma_422_dc, 8, 1, 0



%define stack rsp+gprsize
%define scoreq r14
%define bitsq r13
%define bitsd r13d

INIT_XMM
%macro clocal 1
    ALIGN 16
    global mangle(private_prefix %+ _%1)
    mangle(private_prefix %+ _%1):
    %1:
    %assign stack_offset stack_offset_bak+gprsize
%endmacro

%macro TRELLIS_BNODE 1 ; ctx_hi
clocal trellis_bnode_%1
    ; int j = ctx_hi?1:0;
    ; trellis_node_t *bnode = &nodes_cur[j];
    ; while( ++j < (ctx_hi?8:4) )
    ;     if( nodes_cur[j].score < bnode->score )
    ;         bnode = &nodes_cur[j];
%assign j %1
    mov   rax, [nodes_curq + node_score(j)]
    lea   rax, [rax*8 + j]
%rep 3+3*%1
%assign j j+1
    mov   r11, [nodes_curq + node_score(j)]
    lea   r11, [r11*8 + j]
    cmp   rax, r11
    cmova rax, r11
%endrep
    mov   r10, dctm
    and   eax, 7
    ret
%endmacro ; TRELLIS_BNODE
TRELLIS_BNODE 0
TRELLIS_BNODE 1


%macro TRELLIS_COEF0 1 ; ctx_hi
clocal trellis_coef0_%1
    ; ssd1 += (uint64_t)cost_sig * lambda2 >> ( CABAC_SIZE_BITS - LAMBDA_BITS );
    mov  r11d, [cost_siglast+0]
    imul  r11, lambda2q
    shr   r11, CABAC_SIZE_BITS - LAMBDA_BITS
    add   r11, [ssd+16]
%if %1 == 0
    ; nodes_cur[0].score = nodes_prev[0].score + ssd - ssd1;
    mov  scoreq, [nodes_prevq + node_score(0)]
    add  scoreq, [ssd]
    sub  scoreq, r11
    mov  [nodes_curq + node_score(0)], scoreq
%endif
    ; memcpy
    mov  scoreq, [nodes_prevq + node_score(1)]
    mov  [nodes_curq + node_score(1)], scoreq
    mova m1, [nodes_prevq + node_score(2)]
    mova [nodes_curq + node_score(2)], m1
%if %1
    mova m1, [nodes_prevq + node_score(4)]
    mova [nodes_curq + node_score(4)], m1
    mova m1, [nodes_prevq + node_score(6)]
    mova [nodes_curq + node_score(6)], m1
%endif
    mov  r6d, [nodes_prevq + node_cabac_state(3)]
    mov  [nodes_curq + node_cabac_state(3)], r6d
%if %1
    mova m1, [nodes_prevq + node_cabac_state(4)]
    mova [nodes_curq + node_cabac_state(4)], m1
%endif
    ZERO_LEVEL_IDX %1, prev
    ret
%endmacro ; TRELLIS_COEF0
TRELLIS_COEF0 0
TRELLIS_COEF0 1



%macro START_COEF 1 ; gt1
    ; if( (int64_t)nodes_prev[0].score < 0 ) continue;
    mov  scoreq, [nodes_prevq + node_score(j)]
%if j > 0
    test scoreq, scoreq
    js .ctx %+ nextj_if_invalid
%endif

    ; f8_bits += x264_cabac_size_decision2( &n.cabac_state[coeff_abs_level1_ctx[j]], abs_level > 1 );
%if j >= 3
    movzx r6d, byte [nodes_prevq + node_cabac_state(j) + (coeff_abs_level1_offs>>2)] ; >> because node only stores ctx 0 and 4
    movzx r11, byte [cabac_transition + r6*2 + %1 GLOBAL]
%else
    movzx r6d, byte [level_statem + coeff_abs_level1_offs]
%endif
%if %1
    xor   r6d, 1
%endif
    movzx bitsd, word [cabac_entropy + r6*2 GLOBAL]

    ; n.score += ssd;
    ; unsigned f8_bits = cost_siglast[ j ? 1 : 2 ];
%if j == 0
    add  scoreq, r10
    add  bitsd, [cost_siglast+8]
%else
    add  scoreq, r12
    add  bitsd, [cost_siglast+4]
%endif
%endmacro ; START_COEF

%macro END_COEF 1
    ; n.score += (uint64_t)f8_bits * lambda2 >> ( CABAC_SIZE_BITS - LAMBDA_BITS );
    imul bitsq, lambda2q
    shr  bitsq, CABAC_SIZE_BITS - LAMBDA_BITS
    add  scoreq, bitsq

    ; if( n.score < nodes_cur[node_ctx].score )
    ;     SET_LEVEL( n, abs_level );
    ;     nodes_cur[node_ctx] = n;
    cmp scoreq, [nodes_curq + node_score(node_ctx)]
    jae .ctx %+ nextj_if_valid
    mov [nodes_curq + node_score(node_ctx)], scoreq
%if j == 2 || (j <= 3 && node_ctx == 4)
    ; if this node hasn't previously needed to keep track of abs_level cabac_state, import a pristine copy of the input states
    movd [nodes_curq + node_cabac_state(node_ctx)], level_state_packed
%elif j >= 3
    ; if we have updated before, then copy cabac_state from the parent node
    mov  r6d, [nodes_prevq + node_cabac_state(j)]
    mov [nodes_curq + node_cabac_state(node_ctx)], r6d
%endif
%if j >= 3 ; skip the transition if we're not going to reuse the context
    mov [nodes_curq + node_cabac_state(node_ctx) + (coeff_abs_level1_offs>>2)], r11b ; delayed from x264_cabac_size_decision2
%endif
%if %1 && node_ctx == 7
    mov  r6d, levelgt1_ctxm
    mov [nodes_curq + node_cabac_state(node_ctx) + coeff_abs_levelgt1_offs-6], r10b
%endif
    mov  r6d, [nodes_prevq + node_level_idx(j)]
%if %1
    mov r11d, abs_leveld
    shl r11d, 16
    or   r6d, r11d
%else
    or   r6d, 1<<16
%endif
    mov [level_tree + levels_usedq*4], r6d
    mov [nodes_curq + node_level_idx(node_ctx)], levels_usedd
    inc levels_usedd
%endmacro ; END_COEF



%macro COEF1 2
    %assign j %1
    %assign nextj_if_valid %1+1
    %assign nextj_if_invalid %2
%if j < 4
    %assign coeff_abs_level1_offs j+1
%else
    %assign coeff_abs_level1_offs 0
%endif
%if j < 3
    %assign node_ctx j+1
%else
    %assign node_ctx j
%endif
.ctx %+ j:
    START_COEF 0
    add  bitsd, 1 << CABAC_SIZE_BITS
    END_COEF 0
%endmacro ; COEF1

%macro COEFN 2
    %assign j %1
    %assign nextj_if_valid %2
    %assign nextj_if_invalid %2
%if j < 4
    %assign coeff_abs_level1_offs j+1
    %assign coeff_abs_levelgt1_offs 5
%else
    %assign coeff_abs_level1_offs 0
    %assign coeff_abs_levelgt1_offs j+2 ; this is the one used for all block types except 4:2:2 chroma dc
%endif
%if j < 4
    %assign node_ctx 4
%elif j < 7
    %assign node_ctx j+1
%else
    %assign node_ctx 7
%endif
.ctx %+ j:
    START_COEF 1
    ; if( abs_level >= 15 )
    ;     bits += bs_size_ue_big(...)
    add  bitsd, r5d ; bs_size_ue_big from COEFN_SUFFIX
    ; n.cabac_state[levelgt1_ctx]
%if j == 7 ; && compiling support for 4:2:2
    mov    r6d, levelgt1_ctxm
    %define coeff_abs_levelgt1_offs r6
%endif
%if j == 7
    movzx  r10, byte [nodes_prevq + node_cabac_state(j) + coeff_abs_levelgt1_offs-6] ; -6 because node only stores ctx 8 and 9
%else
    movzx  r10, byte [level_statem + coeff_abs_levelgt1_offs]
%endif
    ; f8_bits += cabac_size_unary[abs_level-1][n.cabac_state[levelgt1_ctx[j]]];
    add   r10d, r1d
    movzx  r6d, word [cabac_size_unary + (r10-128)*2 GLOBAL]
    add  bitsd, r6d
%if node_ctx == 7
    movzx  r10, byte [cabac_transition_unary + r10-128 GLOBAL]
%endif
    END_COEF 1
%endmacro ; COEFN



clocal trellis_coef1
.entry0b: ; ctx_lo, larger of the two abs_level candidates
    mov  r10, [ssd+8]
    sub  r10, r11
    mov  r12, [ssd+24]
    sub  r12, r11
.entry0: ; ctx_lo, smaller of the two abs_level candidates
    COEF1 0, 4
    COEF1 1, 4
    COEF1 2, 4
    COEF1 3, 4
.ctx4:
    rep ret
.entry1b: ; ctx_hi, larger of the two abs_level candidates
    mov  r12, [ssd+24]
    sub  r12, r11
.entry1: ; ctx_hi, smaller of the two abs_level candidates
trellis_coef1_hi:
    COEF1 1, 2
    COEF1 2, 3
    COEF1 3, 4
    COEF1 4, 5
    COEF1 5, 6
    COEF1 6, 7
    COEF1 7, 8
.ctx8:
    rep ret

%macro COEFN_PREFIX 1
    ; int prefix = X264_MIN( abs_level - 1, 14 );
    mov  r1d, abs_leveld
    cmp  abs_leveld, 15
    jge .level_suffix%1
    xor  r5d, r5d
.skip_level_suffix%1:
    shl  r1d, 7
%endmacro

%macro COEFN_SUFFIX 1
.level_suffix%1:
    ; bs_size_ue_big( abs_level - 15 ) << CABAC_SIZE_BITS;
    lea  r5d, [abs_levelq-14]
    bsr  r5d, r5d
    shl  r5d, CABAC_SIZE_BITS+1
    add  r5d, 1<<CABAC_SIZE_BITS
    ; int prefix = X264_MIN( abs_level - 1, 14 );
    mov  r1d, 15
    jmp .skip_level_suffix%1
%endmacro

clocal trellis_coefn
.entry0b:
    mov  r10, [ssd+8]
    mov  r12, [ssd+24]
    inc  abs_leveld
.entry0:
    ; I could fully separate the ctx_lo and ctx_hi versions of coefn, and then
    ; apply return-on-first-failure to ctx_lo. Or I can use multiple entrypoints
    ; to merge the common portion of ctx_lo and ctx_hi, and thus reduce codesize.
    ; I can't do both, as return-on-first-failure doesn't work for ctx_hi.
    ; The C version has to be fully separate since C doesn't support multiple
    ; entrypoints. But return-on-first-failure isn't very important here (as
    ; opposed to coef1), so I might as well reduce codesize.
    COEFN_PREFIX 0
    COEFN 0, 1
    COEFN 1, 2
    COEFN 2, 3
    COEFN 3, 8
.ctx8:
    mov zigzagq, zigzagm ; unspill since r1 was clobbered
    ret
.entry1b:
    mov  r12, [ssd+24]
    inc  abs_leveld
.entry1:
    COEFN_PREFIX 1
    COEFN 4, 5
    COEFN 5, 6
    COEFN 6, 7
    COEFN 7, 1
    jmp .ctx1
    COEFN_SUFFIX 0
    COEFN_SUFFIX 1
