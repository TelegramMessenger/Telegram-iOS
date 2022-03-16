/*****************************************************************************
 * bitstream.h: bitstream writing
 *****************************************************************************
 * Copyright (C) 2003-2022 x264 project
 *
 * Authors: Loren Merritt <lorenm@u.washington.edu>
 *          Fiona Glaser <fiona@x264.com>
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

#ifndef X264_BS_H
#define X264_BS_H

typedef struct
{
    uint16_t i_bits;
    uint8_t  i_size;
    /* Next level table to use */
    uint8_t  i_next;
} vlc_large_t;

typedef struct bs_s
{
    uint8_t *p_start;
    uint8_t *p;
    uint8_t *p_end;

    uintptr_t cur_bits;
    int     i_left;    /* i_count number of available bits */
    int     i_bits_encoded; /* RD only */
} bs_t;

typedef struct
{
    int32_t last;
    int32_t mask;
    ALIGNED_16( dctcoef level[18] );
} x264_run_level_t;

typedef struct
{
    uint8_t *(*nal_escape)( uint8_t *dst, uint8_t *src, uint8_t *end );
    void (*cabac_block_residual_internal)( dctcoef *l, int b_interlaced,
                                           intptr_t ctx_block_cat, x264_cabac_t *cb );
    void (*cabac_block_residual_rd_internal)( dctcoef *l, int b_interlaced,
                                              intptr_t ctx_block_cat, x264_cabac_t *cb );
    void (*cabac_block_residual_8x8_rd_internal)( dctcoef *l, int b_interlaced,
                                                  intptr_t ctx_block_cat, x264_cabac_t *cb );
} x264_bitstream_function_t;

#define x264_bitstream_init x264_template(bitstream_init)
void x264_bitstream_init( uint32_t cpu, x264_bitstream_function_t *pf );

/* A larger level table size theoretically could help a bit at extremely
 * high bitrates, but the cost in cache is usually too high for it to be
 * useful.
 * This size appears to be optimal for QP18 encoding on a Nehalem CPU.
 * FIXME: Do further testing? */
#define LEVEL_TABLE_SIZE 128
#define x264_level_token x264_template(level_token)
extern vlc_large_t x264_level_token[7][LEVEL_TABLE_SIZE];

/* The longest possible set of zero run codes sums to 25 bits.  This leaves
 * plenty of room for both the code (25 bits) and size (5 bits) in a uint32_t. */

#define x264_run_before x264_template(run_before)
extern uint32_t x264_run_before[1<<16];

static inline void bs_init( bs_t *s, void *p_data, int i_data )
{
    int offset = ((intptr_t)p_data & 3);
    s->p       = s->p_start = (uint8_t*)p_data - offset;
    s->p_end   = (uint8_t*)p_data + i_data;
    s->i_left  = (WORD_SIZE - offset)*8;
    if( offset )
    {
        s->cur_bits = endian_fix32( M32(s->p) );
        s->cur_bits >>= (4-offset)*8;
    }
    else
        s->cur_bits = 0;
}
static inline int bs_pos( bs_t *s )
{
    return( 8 * (s->p - s->p_start) + (WORD_SIZE*8) - s->i_left );
}

/* Write the rest of cur_bits to the bitstream; results in a bitstream no longer 32-bit aligned. */
static inline void bs_flush( bs_t *s )
{
    M32( s->p ) = endian_fix32( s->cur_bits << (s->i_left&31) );
    s->p += WORD_SIZE - (s->i_left >> 3);
    s->i_left = WORD_SIZE*8;
}
/* The inverse of bs_flush: prepare the bitstream to be written to again. */
static inline void bs_realign( bs_t *s )
{
    int offset = ((intptr_t)s->p & 3);
    if( offset )
    {
        s->p       = (uint8_t*)s->p - offset;
        s->i_left  = (WORD_SIZE - offset)*8;
        s->cur_bits = endian_fix32( M32(s->p) );
        s->cur_bits >>= (4-offset)*8;
    }
}

static inline void bs_write( bs_t *s, int i_count, uint32_t i_bits )
{
    if( WORD_SIZE == 8 )
    {
        s->cur_bits = (s->cur_bits << i_count) | i_bits;
        s->i_left -= i_count;
        if( s->i_left <= 32 )
        {
#if WORDS_BIGENDIAN
            M32( s->p ) = s->cur_bits >> (32 - s->i_left);
#else
            M32( s->p ) = endian_fix( s->cur_bits << s->i_left );
#endif
            s->i_left += 32;
            s->p += 4;
        }
    }
    else
    {
        if( i_count < s->i_left )
        {
            s->cur_bits = (s->cur_bits << i_count) | i_bits;
            s->i_left -= i_count;
        }
        else
        {
            i_count -= s->i_left;
            s->cur_bits = (s->cur_bits << s->i_left) | (i_bits >> i_count);
            M32( s->p ) = endian_fix( s->cur_bits );
            s->p += 4;
            s->cur_bits = i_bits;
            s->i_left = 32 - i_count;
        }
    }
}

/* Special case to eliminate branch in normal bs_write. */
/* Golomb never writes an even-size code, so this is only used in slice headers. */
static inline void bs_write32( bs_t *s, uint32_t i_bits )
{
    bs_write( s, 16, i_bits >> 16 );
    bs_write( s, 16, i_bits );
}

static inline void bs_write1( bs_t *s, uint32_t i_bit )
{
    s->cur_bits <<= 1;
    s->cur_bits |= i_bit;
    s->i_left--;
    if( s->i_left == WORD_SIZE*8-32 )
    {
        M32( s->p ) = endian_fix32( s->cur_bits );
        s->p += 4;
        s->i_left = WORD_SIZE*8;
    }
}

static inline void bs_align_0( bs_t *s )
{
    bs_write( s, s->i_left&7, 0 );
    bs_flush( s );
}
static inline void bs_align_1( bs_t *s )
{
    bs_write( s, s->i_left&7, (1 << (s->i_left&7)) - 1 );
    bs_flush( s );
}
static inline void bs_align_10( bs_t *s )
{
    if( s->i_left&7 )
        bs_write( s, s->i_left&7, 1 << ( (s->i_left&7) - 1 ) );
    bs_flush( s );
}

/* golomb functions */

static const uint8_t x264_ue_size_tab[256] =
{
     1, 1, 3, 3, 5, 5, 5, 5, 7, 7, 7, 7, 7, 7, 7, 7,
     9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9,
    11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,
    11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,
    13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,
    13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,
    13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,
    13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,
    15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,
    15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,
    15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,
    15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,
    15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,
    15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,
    15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,
    15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,
};

static inline void bs_write_ue_big( bs_t *s, unsigned int val )
{
    int size = 0;
    int tmp = ++val;
    if( tmp >= 0x10000 )
    {
        size = 32;
        tmp >>= 16;
    }
    if( tmp >= 0x100 )
    {
        size += 16;
        tmp >>= 8;
    }
    size += x264_ue_size_tab[tmp];
    bs_write( s, size>>1, 0 );
    bs_write( s, (size>>1)+1, val );
}

/* Only works on values under 255. */
static inline void bs_write_ue( bs_t *s, int val )
{
    bs_write( s, x264_ue_size_tab[val+1], val+1 );
}

static inline void bs_write_se( bs_t *s, int val )
{
    int size = 0;
    /* Faster than (val <= 0 ? -val*2+1 : val*2) */
    /* 4 instructions on x86, 3 on ARM */
    int tmp = 1 - val*2;
    if( tmp < 0 ) tmp = val*2;
    val = tmp;

    if( tmp >= 0x100 )
    {
        size = 16;
        tmp >>= 8;
    }
    size += x264_ue_size_tab[tmp];
    bs_write( s, size, val );
}

static inline void bs_write_te( bs_t *s, int x, int val )
{
    if( x == 1 )
        bs_write1( s, 1^val );
    else //if( x > 1 )
        bs_write_ue( s, val );
}

static inline void bs_rbsp_trailing( bs_t *s )
{
    bs_write1( s, 1 );
    bs_write( s, s->i_left&7, 0  );
}

static ALWAYS_INLINE int bs_size_ue( unsigned int val )
{
    return x264_ue_size_tab[val+1];
}

static ALWAYS_INLINE int bs_size_ue_big( unsigned int val )
{
    if( val < 255 )
        return x264_ue_size_tab[val+1];
    else
        return x264_ue_size_tab[(val+1)>>8] + 16;
}

static ALWAYS_INLINE int bs_size_se( int val )
{
    int tmp = 1 - val*2;
    if( tmp < 0 ) tmp = val*2;
    if( tmp < 256 )
        return x264_ue_size_tab[tmp];
    else
        return x264_ue_size_tab[tmp>>8]+16;
}

static ALWAYS_INLINE int bs_size_te( int x, int val )
{
    if( x == 1 )
        return 1;
    else //if( x > 1 )
        return x264_ue_size_tab[val+1];
}

#endif
