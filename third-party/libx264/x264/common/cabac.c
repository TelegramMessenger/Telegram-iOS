/*****************************************************************************
 * cabac.c: arithmetic coder
 *****************************************************************************
 * Copyright (C) 2003-2022 x264 project
 *
 * Authors: Laurent Aimar <fenrir@via.ecp.fr>
 *          Loren Merritt <lorenm@u.washington.edu>
 *          Fiona Glaser <fiona@x264.com>
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

#include "common.h"

static uint8_t cabac_contexts[4][QP_MAX_SPEC+1][1024];

void x264_cabac_init( x264_t *h )
{
    int ctx_count = CHROMA444 ? 1024 : 460;
    for( int i = 0; i < 4; i++ )
    {
        const int8_t (*cabac_context_init)[1024][2] = i == 0 ? &x264_cabac_context_init_I
                                                             : &x264_cabac_context_init_PB[i-1];
        for( int qp = 0; qp <= QP_MAX_SPEC; qp++ )
            for( int j = 0; j < ctx_count; j++ )
            {
                int state = x264_clip3( (((*cabac_context_init)[j][0] * qp) >> 4) + (*cabac_context_init)[j][1], 1, 126 );
                cabac_contexts[i][qp][j] = (X264_MIN( state, 127-state ) << 1) | (state >> 6);
            }
    }
}

void x264_cabac_context_init( x264_t *h, x264_cabac_t *cb, int i_slice_type, int i_qp, int i_model )
{
    memcpy( cb->state, cabac_contexts[i_slice_type == SLICE_TYPE_I ? 0 : i_model + 1][i_qp], CHROMA444 ? 1024 : 460 );
}

void x264_cabac_encode_init_core( x264_cabac_t *cb )
{
    cb->i_low   = 0;
    cb->i_range = 0x01FE;
    cb->i_queue = -9; // the first bit will be shifted away and not written
    cb->i_bytes_outstanding = 0;
}

void x264_cabac_encode_init( x264_cabac_t *cb, uint8_t *p_data, uint8_t *p_end )
{
    x264_cabac_encode_init_core( cb );
    cb->p_start = p_data;
    cb->p       = p_data;
    cb->p_end   = p_end;
}

static inline void cabac_putbyte( x264_cabac_t *cb )
{
    if( cb->i_queue >= 0 )
    {
        int out = cb->i_low >> (cb->i_queue+10);
        cb->i_low &= (0x400<<cb->i_queue)-1;
        cb->i_queue -= 8;

        if( (out & 0xff) == 0xff )
            cb->i_bytes_outstanding++;
        else
        {
            int carry = out >> 8;
            int bytes_outstanding = cb->i_bytes_outstanding;
            // this can't modify before the beginning of the stream because
            // that would correspond to a probability > 1.
            // it will write before the beginning of the stream, which is ok
            // because a slice header always comes before cabac data.
            // this can't carry beyond the one byte, because any 0xff bytes
            // are in bytes_outstanding and thus not written yet.
            cb->p[-1] += carry;
            while( bytes_outstanding > 0 )
            {
                *(cb->p++) = (uint8_t)(carry-1);
                bytes_outstanding--;
            }
            *(cb->p++) = (uint8_t)out;
            cb->i_bytes_outstanding = 0;
        }
    }
}

static inline void cabac_encode_renorm( x264_cabac_t *cb )
{
    int shift = x264_cabac_renorm_shift[cb->i_range>>3];
    cb->i_range <<= shift;
    cb->i_low   <<= shift;
    cb->i_queue  += shift;
    cabac_putbyte( cb );
}

/* Making custom versions of this function, even in asm, for the cases where
 * b is known to be 0 or 1, proved to be somewhat useful on x86_32 with GCC 3.4
 * but nearly useless with GCC 4.3 and worse than useless on x86_64. */
void x264_cabac_encode_decision_c( x264_cabac_t *cb, int i_ctx, int b )
{
    int i_state = cb->state[i_ctx];
    int i_range_lps = x264_cabac_range_lps[i_state>>1][(cb->i_range>>6)-4];
    cb->i_range -= i_range_lps;
    if( b != (i_state & 1) )
    {
        cb->i_low += cb->i_range;
        cb->i_range = i_range_lps;
    }
    cb->state[i_ctx] = x264_cabac_transition[i_state][b];
    cabac_encode_renorm( cb );
}

/* Note: b is negated for this function */
void x264_cabac_encode_bypass_c( x264_cabac_t *cb, int b )
{
    cb->i_low <<= 1;
    cb->i_low += b & cb->i_range;
    cb->i_queue += 1;
    cabac_putbyte( cb );
}

static const int bypass_lut[16] =
{
    -1,      0x2,     0x14,     0x68,     0x1d0,     0x7a0,     0x1f40,     0x7e80,
    0x1fd00, 0x7fa00, 0x1ff400, 0x7fe800, 0x1ffd000, 0x7ffa000, 0x1fff4000, 0x7ffe8000
};

void x264_cabac_encode_ue_bypass( x264_cabac_t *cb, int exp_bits, int val )
{
    uint32_t v = val + (1<<exp_bits);
    int k = 31 - x264_clz( v );
    uint32_t x = ((uint32_t)bypass_lut[k-exp_bits]<<exp_bits) + v;
    k = 2*k+1-exp_bits;
    int i = ((k-1)&7)+1;
    do {
        k -= i;
        cb->i_low <<= i;
        cb->i_low += ((x>>k)&0xff) * cb->i_range;
        cb->i_queue += i;
        cabac_putbyte( cb );
        i = 8;
    } while( k > 0 );
}

void x264_cabac_encode_terminal_c( x264_cabac_t *cb )
{
    cb->i_range -= 2;
    cabac_encode_renorm( cb );
}

void x264_cabac_encode_flush( x264_t *h, x264_cabac_t *cb )
{
    cb->i_low += cb->i_range - 2;
    cb->i_low |= 1;
    cb->i_low <<= 9;
    cb->i_queue += 9;
    cabac_putbyte( cb );
    cabac_putbyte( cb );
    cb->i_low <<= -cb->i_queue;
    cb->i_low |= (0x35a4e4f5 >> (h->i_frame & 31) & 1) << 10;
    cb->i_queue = 0;
    cabac_putbyte( cb );

    while( cb->i_bytes_outstanding > 0 )
    {
        *(cb->p++) = 0xff;
        cb->i_bytes_outstanding--;
    }
}

