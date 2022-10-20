/*****************************************************************************
 * cabac.h: arithmetic coder
 *****************************************************************************
 * Copyright (C) 2003-2022 x264 project
 *
 * Authors: Loren Merritt <lorenm@u.washington.edu>
 *          Laurent Aimar <fenrir@via.ecp.fr>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02111, USA.
 *
 * This program is also available under a commercial proprietary license.
 * For more information, contact us at licensing@x264.com.
 *****************************************************************************/

#ifndef X264_CABAC_H
#define X264_CABAC_H

typedef struct
{
    /* state */
    int i_low;
    int i_range;

    /* bit stream */
    int i_queue; //stored with an offset of -8 for faster asm
    int i_bytes_outstanding;

    uint8_t *p_start;
    uint8_t *p;
    uint8_t *p_end;

    /* aligned for memcpy_aligned starting here */
    ALIGNED_64( int f8_bits_encoded ); // only if using x264_cabac_size_decision()

    /* context */
    uint8_t state[1024];

    /* for 16-byte alignment */
    uint8_t padding[12];
} x264_cabac_t;

/* init the contexts given i_slice_type, the quantif and the model */
#define x264_cabac_context_init x264_template(cabac_context_init)
void x264_cabac_context_init( x264_t *h, x264_cabac_t *cb, int i_slice_type, int i_qp, int i_model );

#define x264_cabac_encode_init_core x264_template(cabac_encode_init_core)
void x264_cabac_encode_init_core( x264_cabac_t *cb );
#define x264_cabac_encode_init x264_template(cabac_encode_init)
void x264_cabac_encode_init( x264_cabac_t *cb, uint8_t *p_data, uint8_t *p_end );
#define x264_cabac_encode_decision_c x264_template(cabac_encode_decision_c)
void x264_cabac_encode_decision_c( x264_cabac_t *cb, int i_ctx, int b );
#define x264_cabac_encode_decision_asm x264_template(cabac_encode_decision_asm)
void x264_cabac_encode_decision_asm( x264_cabac_t *cb, int i_ctx, int b );
#define x264_cabac_encode_bypass_c x264_template(cabac_encode_bypass_c)
void x264_cabac_encode_bypass_c( x264_cabac_t *cb, int b );
#define x264_cabac_encode_bypass_asm x264_template(cabac_encode_bypass_asm)
void x264_cabac_encode_bypass_asm( x264_cabac_t *cb, int b );
#define x264_cabac_encode_terminal_c x264_template(cabac_encode_terminal_c)
void x264_cabac_encode_terminal_c( x264_cabac_t *cb );
#define x264_cabac_encode_terminal_asm x264_template(cabac_encode_terminal_asm)
void x264_cabac_encode_terminal_asm( x264_cabac_t *cb );
#define x264_cabac_encode_ue_bypass x264_template(cabac_encode_ue_bypass)
void x264_cabac_encode_ue_bypass( x264_cabac_t *cb, int exp_bits, int val );
#define x264_cabac_encode_flush x264_template(cabac_encode_flush)
void x264_cabac_encode_flush( x264_t *h, x264_cabac_t *cb );

#if HAVE_MMX
#define x264_cabac_encode_decision x264_cabac_encode_decision_asm
#define x264_cabac_encode_bypass x264_cabac_encode_bypass_asm
#define x264_cabac_encode_terminal x264_cabac_encode_terminal_asm
#elif HAVE_AARCH64
#define x264_cabac_encode_decision x264_cabac_encode_decision_asm
#define x264_cabac_encode_bypass x264_cabac_encode_bypass_asm
#define x264_cabac_encode_terminal x264_cabac_encode_terminal_asm
#else
#define x264_cabac_encode_decision x264_cabac_encode_decision_c
#define x264_cabac_encode_bypass x264_cabac_encode_bypass_c
#define x264_cabac_encode_terminal x264_cabac_encode_terminal_c
#endif
#define x264_cabac_encode_decision_noup x264_cabac_encode_decision

static ALWAYS_INLINE int x264_cabac_pos( x264_cabac_t *cb )
{
    return (cb->p - cb->p_start + cb->i_bytes_outstanding) * 8 + cb->i_queue;
}

/* internal only. these don't write the bitstream, just calculate bit cost: */

static ALWAYS_INLINE void x264_cabac_size_decision( x264_cabac_t *cb, long i_ctx, long b )
{
    int i_state = cb->state[i_ctx];
    cb->state[i_ctx] = x264_cabac_transition[i_state][b];
    cb->f8_bits_encoded += x264_cabac_entropy[i_state^b];
}

static ALWAYS_INLINE int x264_cabac_size_decision2( uint8_t *state, long b )
{
    int i_state = *state;
    *state = x264_cabac_transition[i_state][b];
    return x264_cabac_entropy[i_state^b];
}

static ALWAYS_INLINE void x264_cabac_size_decision_noup( x264_cabac_t *cb, long i_ctx, long b )
{
    int i_state = cb->state[i_ctx];
    cb->f8_bits_encoded += x264_cabac_entropy[i_state^b];
}

static ALWAYS_INLINE int x264_cabac_size_decision_noup2( uint8_t *state, long b )
{
    return x264_cabac_entropy[*state^b];
}

#endif
