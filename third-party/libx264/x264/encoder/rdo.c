/*****************************************************************************
 * rdo.c: rate-distortion optimization
 *****************************************************************************
 * Copyright (C) 2005-2022 x264 project
 *
 * Authors: Loren Merritt <lorenm@u.washington.edu>
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

/* duplicate all the writer functions, just calculating bit cost
 * instead of writing the bitstream.
 * TODO: use these for fast 1st pass too. */

#define RDO_SKIP_BS 1

/* Transition and size tables for abs<9 MVD and residual coding */
/* Consist of i_prefix-2 1s, one zero, and a bypass sign bit */
#define x264_cabac_transition_unary x264_template(cabac_transition_unary)
uint8_t x264_cabac_transition_unary[15][128];
#define x264_cabac_size_unary x264_template(cabac_size_unary)
uint16_t x264_cabac_size_unary[15][128];
/* Transition and size tables for abs>9 MVD */
/* Consist of 5 1s and a bypass sign bit */
static uint8_t cabac_transition_5ones[128];
static uint16_t cabac_size_5ones[128];

/* CAVLC: produces exactly the same bit count as a normal encode */
/* this probably still leaves some unnecessary computations */
#define bs_write1(s,v)     ((s)->i_bits_encoded += 1)
#define bs_write(s,n,v)    ((s)->i_bits_encoded += (n))
#define bs_write_ue(s,v)   ((s)->i_bits_encoded += bs_size_ue(v))
#define bs_write_se(s,v)   ((s)->i_bits_encoded += bs_size_se(v))
#define bs_write_te(s,v,l) ((s)->i_bits_encoded += bs_size_te(v,l))
#undef  x264_macroblock_write_cavlc
#define x264_macroblock_write_cavlc  static macroblock_size_cavlc
#include "cavlc.c"

/* CABAC: not exactly the same. x264_cabac_size_decision() keeps track of
 * fractional bits, but only finite precision. */
#undef  x264_cabac_encode_decision
#undef  x264_cabac_encode_decision_noup
#undef  x264_cabac_encode_bypass
#undef  x264_cabac_encode_terminal
#undef  x264_cabac_encode_ue_bypass
#define x264_cabac_encode_decision(c,x,v) x264_cabac_size_decision(c,x,v)
#define x264_cabac_encode_decision_noup(c,x,v) x264_cabac_size_decision_noup(c,x,v)
#define x264_cabac_encode_terminal(c)     ((c)->f8_bits_encoded += 7)
#define x264_cabac_encode_bypass(c,v)     ((c)->f8_bits_encoded += 256)
#define x264_cabac_encode_ue_bypass(c,e,v) ((c)->f8_bits_encoded += (bs_size_ue_big(v+(1<<e)-1)-e)<<8)
#undef  x264_macroblock_write_cabac
#define x264_macroblock_write_cabac  static macroblock_size_cabac
#include "cabac.c"

#define COPY_CABAC h->mc.memcpy_aligned( &cabac_tmp.f8_bits_encoded, &h->cabac.f8_bits_encoded, \
        sizeof(int) + (CHROMA444 ? 1024+12 : 460) )
#define COPY_CABAC_PART( pos, size ) memcpy( &cb->state[pos], &h->cabac.state[pos], size )

static ALWAYS_INLINE uint64_t cached_hadamard( x264_t *h, int size, int x, int y )
{
    static const uint8_t hadamard_shift_x[4] = {4,   4,   3,   3};
    static const uint8_t hadamard_shift_y[4] = {4-0, 3-0, 4-1, 3-1};
    static const uint8_t  hadamard_offset[4] = {0,   1,   3,   5};
    int cache_index = (x >> hadamard_shift_x[size]) + (y >> hadamard_shift_y[size])
                    + hadamard_offset[size];
    uint64_t res = h->mb.pic.fenc_hadamard_cache[cache_index];
    if( res )
        return res - 1;
    else
    {
        pixel *fenc = h->mb.pic.p_fenc[0] + x + y*FENC_STRIDE;
        res = h->pixf.hadamard_ac[size]( fenc, FENC_STRIDE );
        h->mb.pic.fenc_hadamard_cache[cache_index] = res + 1;
        return res;
    }
}

static ALWAYS_INLINE int cached_satd( x264_t *h, int size, int x, int y )
{
    static const uint8_t satd_shift_x[3] = {3,   2,   2};
    static const uint8_t satd_shift_y[3] = {2-1, 3-2, 2-2};
    static const uint8_t  satd_offset[3] = {0,   8,   16};
    int cache_index = (x >> satd_shift_x[size - PIXEL_8x4]) + (y >> satd_shift_y[size - PIXEL_8x4])
                    + satd_offset[size - PIXEL_8x4];
    int res = h->mb.pic.fenc_satd_cache[cache_index];
    if( res )
        return res - 1;
    else
    {
        pixel *fenc = h->mb.pic.p_fenc[0] + x + y*FENC_STRIDE;
        int dc = h->pixf.sad[size]( fenc, FENC_STRIDE, (pixel*)x264_zero, 0 ) >> 1;
        res = h->pixf.satd[size]( fenc, FENC_STRIDE, (pixel*)x264_zero, 0 ) - dc;
        h->mb.pic.fenc_satd_cache[cache_index] = res + 1;
        return res;
    }
}

/* Psy RD distortion metric: SSD plus "Absolute Difference of Complexities" */
/* SATD and SA8D are used to measure block complexity. */
/* The difference between SATD and SA8D scores are both used to avoid bias from the DCT size.  Using SATD */
/* only, for example, results in overusage of 8x8dct, while the opposite occurs when using SA8D. */

/* FIXME:  Is there a better metric than averaged SATD/SA8D difference for complexity difference? */
/* Hadamard transform is recursive, so a SATD+SA8D can be done faster by taking advantage of this fact. */
/* This optimization can also be used in non-RD transform decision. */

static inline int ssd_plane( x264_t *h, int size, int p, int x, int y )
{
    int satd = 0;
    pixel *fdec = h->mb.pic.p_fdec[p] + x + y*FDEC_STRIDE;
    pixel *fenc = h->mb.pic.p_fenc[p] + x + y*FENC_STRIDE;
    if( p == 0 && h->mb.i_psy_rd )
    {
        /* If the plane is smaller than 8x8, we can't do an SA8D; this probably isn't a big problem. */
        if( size <= PIXEL_8x8 )
        {
            uint64_t fdec_acs = h->pixf.hadamard_ac[size]( fdec, FDEC_STRIDE );
            uint64_t fenc_acs = cached_hadamard( h, size, x, y );
            satd = abs((int32_t)fdec_acs - (int32_t)fenc_acs)
                 + abs((int32_t)(fdec_acs>>32) - (int32_t)(fenc_acs>>32));
            satd >>= 1;
        }
        else
        {
            int dc = h->pixf.sad[size]( fdec, FDEC_STRIDE, (pixel*)x264_zero, 0 ) >> 1;
            satd = abs(h->pixf.satd[size]( fdec, FDEC_STRIDE, (pixel*)x264_zero, 0 ) - dc - cached_satd( h, size, x, y ));
        }
        int64_t tmp = ((int64_t)satd * h->mb.i_psy_rd * h->mb.i_psy_rd_lambda + 128) >> 8;
        satd = X264_MIN( tmp, COST_MAX );
    }
    return h->pixf.ssd[size](fenc, FENC_STRIDE, fdec, FDEC_STRIDE) + satd;
}

static inline int ssd_mb( x264_t *h )
{
    int i_ssd = ssd_plane( h, PIXEL_16x16, 0, 0, 0 );
    if( CHROMA_FORMAT )
    {
        int chroma_size = h->luma2chroma_pixel[PIXEL_16x16];
        int chroma_ssd = ssd_plane( h, chroma_size, 1, 0, 0 ) + ssd_plane( h, chroma_size, 2, 0, 0 );
        i_ssd += ((uint64_t)chroma_ssd * h->mb.i_chroma_lambda2_offset + 128) >> 8;
    }
    return i_ssd;
}

static int rd_cost_mb( x264_t *h, int i_lambda2 )
{
    int b_transform_bak = h->mb.b_transform_8x8;
    int i_ssd;
    int i_bits;
    int type_bak = h->mb.i_type;

    x264_macroblock_encode( h );

    if( h->mb.b_deblock_rdo )
        x264_macroblock_deblock( h );

    i_ssd = ssd_mb( h );

    if( IS_SKIP( h->mb.i_type ) )
    {
        i_bits = (1 * i_lambda2 + 128) >> 8;
    }
    else if( h->param.b_cabac )
    {
        x264_cabac_t cabac_tmp;
        COPY_CABAC;
        macroblock_size_cabac( h, &cabac_tmp );
        i_bits = ( (uint64_t)cabac_tmp.f8_bits_encoded * i_lambda2 + 32768 ) >> 16;
    }
    else
    {
        macroblock_size_cavlc( h );
        i_bits = ( (uint64_t)h->out.bs.i_bits_encoded * i_lambda2 + 128 ) >> 8;
    }

    h->mb.b_transform_8x8 = b_transform_bak;
    h->mb.i_type = type_bak;

    return X264_MIN( i_ssd + i_bits, COST_MAX );
}

/* partition RD functions use 8 bits more precision to avoid large rounding errors at low QPs */

static uint64_t rd_cost_subpart( x264_t *h, int i_lambda2, int i4, int i_pixel )
{
    uint64_t i_ssd, i_bits;

    x264_macroblock_encode_p4x4( h, i4 );
    if( i_pixel == PIXEL_8x4 )
        x264_macroblock_encode_p4x4( h, i4+1 );
    if( i_pixel == PIXEL_4x8 )
        x264_macroblock_encode_p4x4( h, i4+2 );

    i_ssd = ssd_plane( h, i_pixel, 0, block_idx_x[i4]*4, block_idx_y[i4]*4 );
    if( CHROMA444 )
    {
        int chromassd = ssd_plane( h, i_pixel, 1, block_idx_x[i4]*4, block_idx_y[i4]*4 )
                      + ssd_plane( h, i_pixel, 2, block_idx_x[i4]*4, block_idx_y[i4]*4 );
        chromassd = ((uint64_t)chromassd * h->mb.i_chroma_lambda2_offset + 128) >> 8;
        i_ssd += chromassd;
    }

    if( h->param.b_cabac )
    {
        x264_cabac_t cabac_tmp;
        COPY_CABAC;
        subpartition_size_cabac( h, &cabac_tmp, i4, i_pixel );
        i_bits = ( (uint64_t)cabac_tmp.f8_bits_encoded * i_lambda2 + 128 ) >> 8;
    }
    else
        i_bits = subpartition_size_cavlc( h, i4, i_pixel );

    return (i_ssd<<8) + i_bits;
}

uint64_t x264_rd_cost_part( x264_t *h, int i_lambda2, int i4, int i_pixel )
{
    uint64_t i_ssd, i_bits;
    int i8 = i4 >> 2;

    if( i_pixel == PIXEL_16x16 )
    {
        int i_cost = rd_cost_mb( h, i_lambda2 );
        return i_cost;
    }

    if( i_pixel > PIXEL_8x8 )
        return rd_cost_subpart( h, i_lambda2, i4, i_pixel );

    h->mb.i_cbp_luma = 0;

    x264_macroblock_encode_p8x8( h, i8 );
    if( i_pixel == PIXEL_16x8 )
        x264_macroblock_encode_p8x8( h, i8+1 );
    if( i_pixel == PIXEL_8x16 )
        x264_macroblock_encode_p8x8( h, i8+2 );

    int ssd_x = 8*(i8&1);
    int ssd_y = 8*(i8>>1);
    i_ssd = ssd_plane( h, i_pixel, 0, ssd_x, ssd_y );
    if( CHROMA_FORMAT )
    {
        int chroma_size = h->luma2chroma_pixel[i_pixel];
        int chroma_ssd = ssd_plane( h, chroma_size, 1, ssd_x>>CHROMA_H_SHIFT, ssd_y>>CHROMA_V_SHIFT )
                       + ssd_plane( h, chroma_size, 2, ssd_x>>CHROMA_H_SHIFT, ssd_y>>CHROMA_V_SHIFT );
        i_ssd += ((uint64_t)chroma_ssd * h->mb.i_chroma_lambda2_offset + 128) >> 8;
    }

    if( h->param.b_cabac )
    {
        x264_cabac_t cabac_tmp;
        COPY_CABAC;
        partition_size_cabac( h, &cabac_tmp, i8, i_pixel );
        i_bits = ( (uint64_t)cabac_tmp.f8_bits_encoded * i_lambda2 + 128 ) >> 8;
    }
    else
        i_bits = (uint64_t)partition_size_cavlc( h, i8, i_pixel ) * i_lambda2;

    return (i_ssd<<8) + i_bits;
}

static uint64_t rd_cost_i8x8( x264_t *h, int i_lambda2, int i8, int i_mode, pixel edge[4][32] )
{
    uint64_t i_ssd, i_bits;
    int plane_count = CHROMA444 ? 3 : 1;
    int i_qp = h->mb.i_qp;
    h->mb.i_cbp_luma &= ~(1<<i8);
    h->mb.b_transform_8x8 = 1;

    for( int p = 0; p < plane_count; p++ )
    {
        x264_mb_encode_i8x8( h, p, i8, i_qp, i_mode, edge[p], 1 );
        i_qp = h->mb.i_chroma_qp;
    }

    i_ssd = ssd_plane( h, PIXEL_8x8, 0, (i8&1)*8, (i8>>1)*8 );
    if( CHROMA444 )
    {
        int chromassd = ssd_plane( h, PIXEL_8x8, 1, (i8&1)*8, (i8>>1)*8 )
                      + ssd_plane( h, PIXEL_8x8, 2, (i8&1)*8, (i8>>1)*8 );
        chromassd = ((uint64_t)chromassd * h->mb.i_chroma_lambda2_offset + 128) >> 8;
        i_ssd += chromassd;
    }

    if( h->param.b_cabac )
    {
        x264_cabac_t cabac_tmp;
        COPY_CABAC;
        partition_i8x8_size_cabac( h, &cabac_tmp, i8, i_mode );
        i_bits = ( (uint64_t)cabac_tmp.f8_bits_encoded * i_lambda2 + 128 ) >> 8;
    }
    else
        i_bits = (uint64_t)partition_i8x8_size_cavlc( h, i8, i_mode ) * i_lambda2;

    return (i_ssd<<8) + i_bits;
}

static uint64_t rd_cost_i4x4( x264_t *h, int i_lambda2, int i4, int i_mode )
{
    uint64_t i_ssd, i_bits;
    int plane_count = CHROMA444 ? 3 : 1;
    int i_qp = h->mb.i_qp;

    for( int p = 0; p < plane_count; p++ )
    {
        x264_mb_encode_i4x4( h, p, i4, i_qp, i_mode, 1 );
        i_qp = h->mb.i_chroma_qp;
    }

    i_ssd = ssd_plane( h, PIXEL_4x4, 0, block_idx_x[i4]*4, block_idx_y[i4]*4 );
    if( CHROMA444 )
    {
        int chromassd = ssd_plane( h, PIXEL_4x4, 1, block_idx_x[i4]*4, block_idx_y[i4]*4 )
                      + ssd_plane( h, PIXEL_4x4, 2, block_idx_x[i4]*4, block_idx_y[i4]*4 );
        chromassd = ((uint64_t)chromassd * h->mb.i_chroma_lambda2_offset + 128) >> 8;
        i_ssd += chromassd;
    }

    if( h->param.b_cabac )
    {
        x264_cabac_t cabac_tmp;
        COPY_CABAC;
        partition_i4x4_size_cabac( h, &cabac_tmp, i4, i_mode );
        i_bits = ( (uint64_t)cabac_tmp.f8_bits_encoded * i_lambda2 + 128 ) >> 8;
    }
    else
        i_bits = (uint64_t)partition_i4x4_size_cavlc( h, i4, i_mode ) * i_lambda2;

    return (i_ssd<<8) + i_bits;
}

static uint64_t rd_cost_chroma( x264_t *h, int i_lambda2, int i_mode, int b_dct )
{
    uint64_t i_ssd, i_bits;

    if( b_dct )
        x264_mb_encode_chroma( h, 0, h->mb.i_chroma_qp );

    int chromapix = h->luma2chroma_pixel[PIXEL_16x16];
    i_ssd = ssd_plane( h, chromapix, 1, 0, 0 )
          + ssd_plane( h, chromapix, 2, 0, 0 );

    h->mb.i_chroma_pred_mode = i_mode;

    if( h->param.b_cabac )
    {
        x264_cabac_t cabac_tmp;
        COPY_CABAC;
        chroma_size_cabac( h, &cabac_tmp );
        i_bits = ( (uint64_t)cabac_tmp.f8_bits_encoded * i_lambda2 + 128 ) >> 8;
    }
    else
        i_bits = (uint64_t)chroma_size_cavlc( h ) * i_lambda2;

    return (i_ssd<<8) + i_bits;
}
/****************************************************************************
 * Trellis RD quantization
 ****************************************************************************/

#define TRELLIS_SCORE_MAX  (~0ULL) // marks the node as invalid
#define TRELLIS_SCORE_BIAS (1ULL<<60) // bias so that all valid scores are positive, even after negative contributions from psy
#define CABAC_SIZE_BITS 8
#define LAMBDA_BITS 4

/* precalculate the cost of coding various combinations of bits in a single context */
void x264_rdo_init( void )
{
    for( int i_prefix = 0; i_prefix < 15; i_prefix++ )
    {
        for( int i_ctx = 0; i_ctx < 128; i_ctx++ )
        {
            int f8_bits = 0;
            uint8_t ctx = i_ctx;

            for( int i = 1; i < i_prefix; i++ )
                f8_bits += x264_cabac_size_decision2( &ctx, 1 );
            if( i_prefix > 0 && i_prefix < 14 )
                f8_bits += x264_cabac_size_decision2( &ctx, 0 );
            f8_bits += 1 << CABAC_SIZE_BITS; //sign

            x264_cabac_size_unary[i_prefix][i_ctx] = f8_bits;
            x264_cabac_transition_unary[i_prefix][i_ctx] = ctx;
        }
    }
    for( int i_ctx = 0; i_ctx < 128; i_ctx++ )
    {
        int f8_bits = 0;
        uint8_t ctx = i_ctx;

        for( int i = 0; i < 5; i++ )
            f8_bits += x264_cabac_size_decision2( &ctx, 1 );
        f8_bits += 1 << CABAC_SIZE_BITS; //sign

        cabac_size_5ones[i_ctx] = f8_bits;
        cabac_transition_5ones[i_ctx] = ctx;
    }
}

typedef struct
{
    uint64_t score;
    int level_idx; // index into level_tree[]
    uint8_t cabac_state[4]; // just contexts 0,4,8,9 of the 10 relevant to coding abs_level_m1
} trellis_node_t;

typedef struct
{
    uint16_t next;
    uint16_t abs_level;
} trellis_level_t;

// TODO:
// save cabac state between blocks?
// use trellis' RD score instead of x264_mb_decimate_score?
// code 8x8 sig/last flags forwards with deadzone and save the contexts at
//   each position?
// change weights when using CQMs?

// possible optimizations:
// make scores fit in 32bit
// save quantized coefs during rd, to avoid a duplicate trellis in the final encode
// if trellissing all MBRD modes, finish SSD calculation so we can skip all of
//   the normal dequant/idct/ssd/cabac

// the unquant_mf here is not the same as dequant_mf:
// in normal operation (dct->quant->dequant->idct) the dct and idct are not
// normalized. quant/dequant absorb those scaling factors.
// in this function, we just do (quant->unquant) and want the output to be
// comparable to the input. so unquant is the direct inverse of quant,
// and uses the dct scaling factors, not the idct ones.

#define SIGN(x,y) ((x^(y >> 31))-(y >> 31))

#define SET_LEVEL(ndst, nsrc, l) {\
    if( sizeof(trellis_level_t) == sizeof(uint32_t) )\
        M32( &level_tree[levels_used] ) = pack16to32( nsrc.level_idx, l );\
    else\
        level_tree[levels_used] = (trellis_level_t){ nsrc.level_idx, l };\
    ndst.level_idx = levels_used;\
    levels_used++;\
}

// encode all values of the dc coef in a block which is known to have no ac
static NOINLINE
int trellis_dc_shortcut( int sign_coef, int quant_coef, int unquant_mf, int coef_weight, int lambda2, uint8_t *cabac_state, int cost_sig )
{
    uint64_t bscore = TRELLIS_SCORE_MAX;
    int ret = 0;
    int q = abs( quant_coef );
    for( int abs_level = q-1; abs_level <= q; abs_level++ )
    {
        int unquant_abs_level = (unquant_mf * abs_level + 128) >> 8;

        /* Optimize rounding for DC coefficients in DC-only luma 4x4/8x8 blocks. */
        int d = sign_coef - ((SIGN(unquant_abs_level, sign_coef) + 8)&~15);
        uint64_t score = (int64_t)d*d * coef_weight;

        /* code the proposed level, and count how much entropy it would take */
        if( abs_level )
        {
            unsigned f8_bits = cost_sig;
            int prefix = X264_MIN( abs_level - 1, 14 );
            f8_bits += x264_cabac_size_decision_noup2( cabac_state+1, prefix > 0 );
            f8_bits += x264_cabac_size_unary[prefix][cabac_state[5]];
            if( abs_level >= 15 )
                f8_bits += bs_size_ue_big( abs_level - 15 ) << CABAC_SIZE_BITS;
            score += (uint64_t)f8_bits * lambda2 >> ( CABAC_SIZE_BITS - LAMBDA_BITS );
        }

        COPY2_IF_LT( bscore, score, ret, abs_level );
    }
    return SIGN(ret, sign_coef);
}

// encode one value of one coef in one context
static ALWAYS_INLINE
int trellis_coef( int j, int const_level, int abs_level, int prefix, int suffix_cost,
                  int node_ctx, int level1_ctx, int levelgt1_ctx, uint64_t ssd, int cost_siglast[3],
                  trellis_node_t *nodes_cur, trellis_node_t *nodes_prev,
                  trellis_level_t *level_tree, int levels_used, int lambda2, uint8_t *level_state )
{
    uint64_t score = nodes_prev[j].score + ssd;
    /* code the proposed level, and count how much entropy it would take */
    unsigned f8_bits = cost_siglast[ j ? 1 : 2 ];
    uint8_t level1_state = (j >= 3) ? nodes_prev[j].cabac_state[level1_ctx>>2] : level_state[level1_ctx];
    f8_bits += x264_cabac_entropy[level1_state ^ (const_level > 1)];
    uint8_t levelgt1_state;
    if( const_level > 1 )
    {
        levelgt1_state = j >= 6 ? nodes_prev[j].cabac_state[levelgt1_ctx-6] : level_state[levelgt1_ctx];
        f8_bits += x264_cabac_size_unary[prefix][levelgt1_state] + suffix_cost;
    }
    else
        f8_bits += 1 << CABAC_SIZE_BITS;
    score += (uint64_t)f8_bits * lambda2 >> ( CABAC_SIZE_BITS - LAMBDA_BITS );

    /* save the node if it's better than any existing node with the same cabac ctx */
    if( score < nodes_cur[node_ctx].score )
    {
        nodes_cur[node_ctx].score = score;
        if( j == 2 || (j <= 3 && node_ctx == 4) ) // init from input state
            M32(nodes_cur[node_ctx].cabac_state) = M32(level_state+12);
        else if( j >= 3 )
            M32(nodes_cur[node_ctx].cabac_state) = M32(nodes_prev[j].cabac_state);
        if( j >= 3 ) // skip the transition if we're not going to reuse the context
            nodes_cur[node_ctx].cabac_state[level1_ctx>>2] = x264_cabac_transition[level1_state][const_level > 1];
        if( const_level > 1 && node_ctx == 7 )
            nodes_cur[node_ctx].cabac_state[levelgt1_ctx-6] = x264_cabac_transition_unary[prefix][levelgt1_state];
        nodes_cur[node_ctx].level_idx = nodes_prev[j].level_idx;
        SET_LEVEL( nodes_cur[node_ctx], nodes_prev[j], abs_level );
    }
    return levels_used;
}

// encode one value of one coef in all contexts, templated by which value that is.
// in ctx_lo, the set of live nodes is contiguous and starts at ctx0, so return as soon as we've seen one failure.
// in ctx_hi, they're contiguous within each block of 4 ctxs, but not necessarily starting at the beginning,
// so exploiting that would be more complicated.
static NOINLINE
int trellis_coef0_0( uint64_t ssd0, trellis_node_t *nodes_cur, trellis_node_t *nodes_prev,
                     trellis_level_t *level_tree, int levels_used )
{
    nodes_cur[0].score = nodes_prev[0].score + ssd0;
    nodes_cur[0].level_idx = nodes_prev[0].level_idx;
    for( int j = 1; j < 4 && (int64_t)nodes_prev[j].score >= 0; j++ )
    {
        nodes_cur[j].score = nodes_prev[j].score;
        if( j >= 3 )
            M32(nodes_cur[j].cabac_state) = M32(nodes_prev[j].cabac_state);
        SET_LEVEL( nodes_cur[j], nodes_prev[j], 0 );
    }
    return levels_used;
}

static NOINLINE
int trellis_coef0_1( uint64_t ssd0, trellis_node_t *nodes_cur, trellis_node_t *nodes_prev,
                     trellis_level_t *level_tree, int levels_used )
{
    for( int j = 1; j < 8; j++ )
        // this branch only affects speed, not function; there's nothing wrong with updating invalid nodes in coef0.
        if( (int64_t)nodes_prev[j].score >= 0 )
        {
            nodes_cur[j].score = nodes_prev[j].score;
            if( j >= 3 )
                M32(nodes_cur[j].cabac_state) = M32(nodes_prev[j].cabac_state);
            SET_LEVEL( nodes_cur[j], nodes_prev[j], 0 );
        }
    return levels_used;
}

#define COEF(const_level, ctx_hi, j, ...)\
    if( !j || (int64_t)nodes_prev[j].score >= 0 )\
        levels_used = trellis_coef( j, const_level, abs_level, prefix, suffix_cost, __VA_ARGS__,\
                                    j?ssd1:ssd0, cost_siglast, nodes_cur, nodes_prev,\
                                    level_tree, levels_used, lambda2, level_state );\
    else if( !ctx_hi )\
        return levels_used;

static NOINLINE
int trellis_coef1_0( uint64_t ssd0, uint64_t ssd1, int cost_siglast[3],
                     trellis_node_t *nodes_cur, trellis_node_t *nodes_prev,
                     trellis_level_t *level_tree, int levels_used, int lambda2,
                     uint8_t *level_state )
{
    int abs_level = 1, prefix = 1, suffix_cost = 0;
    COEF( 1, 0, 0, 1, 1, 0 );
    COEF( 1, 0, 1, 2, 2, 0 );
    COEF( 1, 0, 2, 3, 3, 0 );
    COEF( 1, 0, 3, 3, 4, 0 );
    return levels_used;
}

static NOINLINE
int trellis_coef1_1( uint64_t ssd0, uint64_t ssd1, int cost_siglast[3],
                     trellis_node_t *nodes_cur, trellis_node_t *nodes_prev,
                     trellis_level_t *level_tree, int levels_used, int lambda2,
                     uint8_t *level_state )
{
    int abs_level = 1, prefix = 1, suffix_cost = 0;
    COEF( 1, 1, 1, 2, 2, 0 );
    COEF( 1, 1, 2, 3, 3, 0 );
    COEF( 1, 1, 3, 3, 4, 0 );
    COEF( 1, 1, 4, 4, 0, 0 );
    COEF( 1, 1, 5, 5, 0, 0 );
    COEF( 1, 1, 6, 6, 0, 0 );
    COEF( 1, 1, 7, 7, 0, 0 );
    return levels_used;
}

static NOINLINE
int trellis_coefn_0( int abs_level, uint64_t ssd0, uint64_t ssd1, int cost_siglast[3],
                     trellis_node_t *nodes_cur, trellis_node_t *nodes_prev,
                     trellis_level_t *level_tree, int levels_used, int lambda2,
                     uint8_t *level_state, int levelgt1_ctx )
{
    int prefix = X264_MIN( abs_level-1, 14 );
    int suffix_cost = abs_level >= 15 ? bs_size_ue_big( abs_level - 15 ) << CABAC_SIZE_BITS : 0;
    COEF( 2, 0, 0, 4, 1, 5 );
    COEF( 2, 0, 1, 4, 2, 5 );
    COEF( 2, 0, 2, 4, 3, 5 );
    COEF( 2, 0, 3, 4, 4, 5 );
    return levels_used;
}

static NOINLINE
int trellis_coefn_1( int abs_level, uint64_t ssd0, uint64_t ssd1, int cost_siglast[3],
                     trellis_node_t *nodes_cur, trellis_node_t *nodes_prev,
                     trellis_level_t *level_tree, int levels_used, int lambda2,
                     uint8_t *level_state, int levelgt1_ctx )
{
    int prefix = X264_MIN( abs_level-1, 14 );
    int suffix_cost = abs_level >= 15 ? bs_size_ue_big( abs_level - 15 ) << CABAC_SIZE_BITS : 0;
    COEF( 2, 1, 1, 4, 2, 5 );
    COEF( 2, 1, 2, 4, 3, 5 );
    COEF( 2, 1, 3, 4, 4, 5 );
    COEF( 2, 1, 4, 5, 0, 6 );
    COEF( 2, 1, 5, 6, 0, 7 );
    COEF( 2, 1, 6, 7, 0, 8 );
    COEF( 2, 1, 7, 7, 0, levelgt1_ctx );
    return levels_used;
}

static ALWAYS_INLINE
int quant_trellis_cabac( x264_t *h, dctcoef *dct,
                         udctcoef *quant_mf, udctcoef *quant_bias, const int *unquant_mf,
                         const uint8_t *zigzag, int ctx_block_cat, int lambda2, int b_ac,
                         int b_chroma, int dc, int num_coefs, int idx )
{
    ALIGNED_ARRAY_64( dctcoef, orig_coefs, [64] );
    ALIGNED_ARRAY_64( dctcoef, quant_coefs, [64] );
    const uint32_t *coef_weight1 = num_coefs == 64 ? x264_dct8_weight_tab : x264_dct4_weight_tab;
    const uint32_t *coef_weight2 = num_coefs == 64 ? x264_dct8_weight2_tab : x264_dct4_weight2_tab;
    const int b_interlaced = MB_INTERLACED;
    uint8_t *cabac_state_sig = &h->cabac.state[ x264_significant_coeff_flag_offset[b_interlaced][ctx_block_cat] ];
    uint8_t *cabac_state_last = &h->cabac.state[ x264_last_coeff_flag_offset[b_interlaced][ctx_block_cat] ];
    int levelgt1_ctx = b_chroma && dc ? 8 : 9;

    if( dc )
    {
        if( num_coefs == 16 )
        {
            memcpy( orig_coefs, dct, sizeof(dctcoef)*16 );
            if( !h->quantf.quant_4x4_dc( dct, quant_mf[0] >> 1, quant_bias[0] << 1 ) )
                return 0;
            h->zigzagf.scan_4x4( quant_coefs, dct );
        }
        else
        {
            memcpy( orig_coefs, dct, sizeof(dctcoef)*num_coefs );
            int nz = h->quantf.quant_2x2_dc( &dct[0], quant_mf[0] >> 1, quant_bias[0] << 1 );
            if( num_coefs == 8 )
                nz |= h->quantf.quant_2x2_dc( &dct[4], quant_mf[0] >> 1, quant_bias[0] << 1 );
            if( !nz )
                return 0;
            for( int i = 0; i < num_coefs; i++ )
                quant_coefs[i] = dct[zigzag[i]];
        }
    }
    else
    {
        if( num_coefs == 64 )
        {
            h->mc.memcpy_aligned( orig_coefs, dct, sizeof(dctcoef)*64 );
            if( !h->quantf.quant_8x8( dct, quant_mf, quant_bias ) )
                return 0;
            h->zigzagf.scan_8x8( quant_coefs, dct );
        }
        else //if( num_coefs == 16 )
        {
            memcpy( orig_coefs, dct, sizeof(dctcoef)*16 );
            if( !h->quantf.quant_4x4( dct, quant_mf, quant_bias ) )
                return 0;
            h->zigzagf.scan_4x4( quant_coefs, dct );
        }
    }

    int last_nnz = h->quantf.coeff_last[ctx_block_cat]( quant_coefs+b_ac )+b_ac;
    uint8_t *cabac_state = &h->cabac.state[ x264_coeff_abs_level_m1_offset[ctx_block_cat] ];

    /* shortcut for dc-only blocks.
     * this doesn't affect the output, but saves some unnecessary computation. */
    if( last_nnz == 0 && !dc )
    {
        int cost_sig = x264_cabac_size_decision_noup2( &cabac_state_sig[0], 1 )
                     + x264_cabac_size_decision_noup2( &cabac_state_last[0], 1 );
        dct[0] = trellis_dc_shortcut( orig_coefs[0], quant_coefs[0], unquant_mf[0], coef_weight2[0], lambda2, cabac_state, cost_sig );
        return !!dct[0];
    }

#if HAVE_MMX && ARCH_X86_64
    uint64_t level_state0;
    memcpy( &level_state0, cabac_state, sizeof(uint64_t) );
    uint16_t level_state1;
    memcpy( &level_state1, cabac_state+8, sizeof(uint16_t) );
#define TRELLIS_ARGS unquant_mf, zigzag, lambda2, last_nnz, orig_coefs, quant_coefs, dct,\
                     cabac_state_sig, cabac_state_last, level_state0, level_state1
    if( num_coefs == 16 && !dc )
        if( b_chroma || !h->mb.i_psy_trellis )
            return h->quantf.trellis_cabac_4x4( TRELLIS_ARGS, b_ac );
        else
            return h->quantf.trellis_cabac_4x4_psy( TRELLIS_ARGS, b_ac, h->mb.pic.fenc_dct4[idx&15], h->mb.i_psy_trellis );
    else if( num_coefs == 64 && !dc )
        if( b_chroma || !h->mb.i_psy_trellis )
            return h->quantf.trellis_cabac_8x8( TRELLIS_ARGS, b_interlaced );
        else
            return h->quantf.trellis_cabac_8x8_psy( TRELLIS_ARGS, b_interlaced, h->mb.pic.fenc_dct8[idx&3], h->mb.i_psy_trellis);
    else if( num_coefs == 8 && dc )
        return h->quantf.trellis_cabac_chroma_422_dc( TRELLIS_ARGS );
    else if( dc )
        return h->quantf.trellis_cabac_dc( TRELLIS_ARGS, num_coefs-1 );
#endif

    // (# of coefs) * (# of ctx) * (# of levels tried) = 1024
    // we don't need to keep all of those: (# of coefs) * (# of ctx) would be enough,
    // but it takes more time to remove dead states than you gain in reduced memory.
    trellis_level_t level_tree[64*8*2];
    int levels_used = 1;
    /* init trellis */
    trellis_node_t nodes[2][8] = {0};
    trellis_node_t *nodes_cur = nodes[0];
    trellis_node_t *nodes_prev = nodes[1];
    trellis_node_t *bnode;
    for( int j = 1; j < 8; j++ )
        nodes_cur[j].score = TRELLIS_SCORE_MAX;
    nodes_cur[0].score = TRELLIS_SCORE_BIAS;
    nodes_cur[0].level_idx = 0;
    level_tree[0].abs_level = 0;
    level_tree[0].next = 0;
    ALIGNED_4( uint8_t level_state[16] );
    memcpy( level_state, cabac_state, 10 );
    level_state[12] = cabac_state[0]; // packed subset for copying into trellis_node_t
    level_state[13] = cabac_state[4];
    level_state[14] = cabac_state[8];
    level_state[15] = cabac_state[9];

    idx &= num_coefs == 64 ? 3 : 15;

    // coefs are processed in reverse order, because that's how the abs value is coded.
    // last_coef and significant_coef flags are normally coded in forward order, but
    // we have to reverse them to match the levels.
    // in 4x4 blocks, last_coef and significant_coef use a separate context for each
    // position, so the order doesn't matter, and we don't even have to update their contexts.
    // in 8x8 blocks, some positions share contexts, so we'll just have to hope that
    // cabac isn't too sensitive.
    int i = last_nnz;
#define TRELLIS_LOOP(ctx_hi)\
    for( ; i >= b_ac; i-- )\
    {\
        /* skip 0s: this doesn't affect the output, but saves some unnecessary computation. */\
        if( !quant_coefs[i] )\
        {\
            /* no need to calculate ssd of 0s: it's the same in all nodes.\
             * no need to modify level_tree for ctx=0: it starts with an infinite loop of 0s.\
             * subtracting from one score is equivalent to adding to the rest. */\
            if( !ctx_hi )\
            {\
                int sigindex = !dc && num_coefs == 64 ? x264_significant_coeff_flag_offset_8x8[b_interlaced][i] :\
                               b_chroma && dc && num_coefs == 8 ? x264_coeff_flag_offset_chroma_422_dc[i] : i;\
                uint64_t cost_sig0 = x264_cabac_size_decision_noup2( &cabac_state_sig[sigindex], 0 )\
                                   * (uint64_t)lambda2 >> ( CABAC_SIZE_BITS - LAMBDA_BITS );\
                nodes_cur[0].score -= cost_sig0;\
            }\
            for( int j = 1; j < (ctx_hi?8:4); j++ )\
                SET_LEVEL( nodes_cur[j], nodes_cur[j], 0 );\
            continue;\
        }\
\
        int sign_coef = orig_coefs[zigzag[i]];\
        int abs_coef = abs( sign_coef );\
        int q = abs( quant_coefs[i] );\
        int cost_siglast[3]; /* { zero, nonzero, nonzero-and-last } */\
        XCHG( trellis_node_t*, nodes_cur, nodes_prev );\
        for( int j = ctx_hi; j < 8; j++ )\
            nodes_cur[j].score = TRELLIS_SCORE_MAX;\
\
        if( i < num_coefs-1 || ctx_hi )\
        {\
            int sigindex  = !dc && num_coefs == 64 ? x264_significant_coeff_flag_offset_8x8[b_interlaced][i] :\
                            b_chroma && dc && num_coefs == 8 ? x264_coeff_flag_offset_chroma_422_dc[i] : i;\
            int lastindex = !dc && num_coefs == 64 ? x264_last_coeff_flag_offset_8x8[i] :\
                            b_chroma && dc && num_coefs == 8 ? x264_coeff_flag_offset_chroma_422_dc[i] : i;\
            cost_siglast[0] = x264_cabac_size_decision_noup2( &cabac_state_sig[sigindex], 0 );\
            int cost_sig1   = x264_cabac_size_decision_noup2( &cabac_state_sig[sigindex], 1 );\
            cost_siglast[1] = x264_cabac_size_decision_noup2( &cabac_state_last[lastindex], 0 ) + cost_sig1;\
            if( !ctx_hi )\
                cost_siglast[2] = x264_cabac_size_decision_noup2( &cabac_state_last[lastindex], 1 ) + cost_sig1;\
        }\
        else\
        {\
            cost_siglast[0] = cost_siglast[1] = cost_siglast[2] = 0;\
        }\
\
        /* there are a few cases where increasing the coeff magnitude helps,\
         * but it's only around .003 dB, and skipping them ~doubles the speed of trellis.\
         * could also try q-2: that sometimes helps, but also sometimes decimates blocks\
         * that are better left coded, especially at QP > 40. */\
        uint64_t ssd0[2], ssd1[2];\
        for( int k = 0; k < 2; k++ )\
        {\
            int abs_level = q-1+k;\
            int unquant_abs_level = (((dc?unquant_mf[0]<<1:unquant_mf[zigzag[i]]) * abs_level + 128) >> 8);\
            int d = abs_coef - unquant_abs_level;\
            /* Psy trellis: bias in favor of higher AC coefficients in the reconstructed frame. */\
            if( h->mb.i_psy_trellis && i && !dc && !b_chroma )\
            {\
                int orig_coef = (num_coefs == 64) ? h->mb.pic.fenc_dct8[idx][zigzag[i]] : h->mb.pic.fenc_dct4[idx][zigzag[i]];\
                int predicted_coef = orig_coef - sign_coef;\
                int psy_value = abs(unquant_abs_level + SIGN(predicted_coef, sign_coef));\
                int psy_weight = coef_weight1[zigzag[i]] * h->mb.i_psy_trellis;\
                int64_t tmp = (int64_t)d*d * coef_weight2[zigzag[i]] - (int64_t)psy_weight * psy_value;\
                ssd1[k] = (uint64_t)tmp;\
            }\
            else\
            /* FIXME: for i16x16 dc is this weight optimal? */\
                ssd1[k] = (int64_t)d*d * (dc?256:coef_weight2[zigzag[i]]);\
            ssd0[k] = ssd1[k];\
            if( !i && !dc && !ctx_hi )\
            {\
                /* Optimize rounding for DC coefficients in DC-only luma 4x4/8x8 blocks. */\
                d = sign_coef - ((SIGN(unquant_abs_level, sign_coef) + 8)&~15);\
                ssd0[k] = (int64_t)d*d * coef_weight2[zigzag[i]];\
            }\
        }\
\
        /* argument passing imposes some significant overhead here. gcc's interprocedural register allocation isn't up to it. */\
        switch( q )\
        {\
        case 1:\
            ssd1[0] += (uint64_t)cost_siglast[0] * lambda2 >> ( CABAC_SIZE_BITS - LAMBDA_BITS );\
            levels_used = trellis_coef0_##ctx_hi( ssd0[0]-ssd1[0], nodes_cur, nodes_prev, level_tree, levels_used );\
            levels_used = trellis_coef1_##ctx_hi( ssd0[1]-ssd1[0], ssd1[1]-ssd1[0], cost_siglast, nodes_cur, nodes_prev, level_tree, levels_used, lambda2, level_state );\
            goto next##ctx_hi;\
        case 2:\
            levels_used = trellis_coef1_##ctx_hi( ssd0[0], ssd1[0], cost_siglast, nodes_cur, nodes_prev, level_tree, levels_used, lambda2, level_state );\
            levels_used = trellis_coefn_##ctx_hi( q, ssd0[1], ssd1[1], cost_siglast, nodes_cur, nodes_prev, level_tree, levels_used, lambda2, level_state, levelgt1_ctx );\
            goto next1;\
        default:\
            levels_used = trellis_coefn_##ctx_hi( q-1, ssd0[0], ssd1[0], cost_siglast, nodes_cur, nodes_prev, level_tree, levels_used, lambda2, level_state, levelgt1_ctx );\
            levels_used = trellis_coefn_##ctx_hi( q, ssd0[1], ssd1[1], cost_siglast, nodes_cur, nodes_prev, level_tree, levels_used, lambda2, level_state, levelgt1_ctx );\
            goto next1;\
        }\
        next##ctx_hi:;\
    }\
    /* output levels from the best path through the trellis */\
    bnode = &nodes_cur[ctx_hi];\
    for( int j = ctx_hi+1; j < (ctx_hi?8:4); j++ )\
        if( nodes_cur[j].score < bnode->score )\
            bnode = &nodes_cur[j];

    // keep 2 versions of the main quantization loop, depending on which subsets of the node_ctxs are live
    // node_ctx 0..3, i.e. having not yet encountered any coefs that might be quantized to >1
    TRELLIS_LOOP(0);

    if( bnode == &nodes_cur[0] )
    {
        /* We only need to zero an empty 4x4 block. 8x8 can be
           implicitly emptied via zero nnz, as can dc. */
        if( num_coefs == 16 && !dc )
            memset( dct, 0, 16 * sizeof(dctcoef) );
        return 0;
    }

    if( 0 ) // accessible only by goto, not fallthrough
    {
        // node_ctx 1..7 (ctx0 ruled out because we never try both level0 and level2+ on the same coef)
        TRELLIS_LOOP(1);
    }

    int level = bnode->level_idx;
    for( i = b_ac; i <= last_nnz; i++ )
    {
        dct[zigzag[i]] = SIGN(level_tree[level].abs_level, dct[zigzag[i]]);
        level = level_tree[level].next;
    }

    return 1;
}

/* FIXME: This is a gigantic hack.  See below.
 *
 * CAVLC is much more difficult to trellis than CABAC.
 *
 * CABAC has only three states to track: significance map, last, and the
 * level state machine.
 * CAVLC, by comparison, has five: coeff_token (trailing + total),
 * total_zeroes, zero_run, and the level state machine.
 *
 * I know of no paper that has managed to design a close-to-optimal trellis
 * that covers all five of these and isn't exponential-time.  As a result, this
 * "trellis" isn't: it's just a QNS search.  Patches welcome for something better.
 * It's actually surprisingly fast, albeit not quite optimal.  It's pretty close
 * though; since CAVLC only has 2^16 possible rounding modes (assuming only two
 * roundings as options), a bruteforce search is feasible.  Testing shows
 * that this QNS is reasonably close to optimal in terms of compression.
 *
 * TODO:
 *  Don't bother changing large coefficients when it wouldn't affect bit cost
 *  (e.g. only affecting bypassed suffix bits).
 *  Don't re-run all parts of CAVLC bit cost calculation when not necessary.
 *  e.g. when changing a coefficient from one non-zero value to another in
 *  such a way that trailing ones and suffix length isn't affected. */
static ALWAYS_INLINE
int quant_trellis_cavlc( x264_t *h, dctcoef *dct,
                         const udctcoef *quant_mf, const int *unquant_mf,
                         const uint8_t *zigzag, int ctx_block_cat, int lambda2, int b_ac,
                         int b_chroma, int dc, int num_coefs, int idx, int b_8x8 )
{
    ALIGNED_ARRAY_16( dctcoef, quant_coefs,[2],[16] );
    ALIGNED_ARRAY_16( dctcoef, coefs,[16] );
    const uint32_t *coef_weight1 = b_8x8 ? x264_dct8_weight_tab : x264_dct4_weight_tab;
    const uint32_t *coef_weight2 = b_8x8 ? x264_dct8_weight2_tab : x264_dct4_weight2_tab;
    int64_t delta_distortion[16];
    int64_t score = 1ULL<<62;
    int i, j;
    const int f = 1<<15;
    int nC = b_chroma && dc ? 3 + (num_coefs>>2)
                            : ct_index[x264_mb_predict_non_zero_code( h, !b_chroma && dc ? (idx - LUMA_DC)*16 : idx )];

    for( i = 0; i < 16; i += 16/sizeof(*coefs) )
        M128( &coefs[i] ) = M128_ZERO;

    /* Code for handling 8x8dct -> 4x4dct CAVLC munging.  Input/output use a different
     * step/start/end than internal processing. */
    int step = 1;
    int start = b_ac;
    int end = num_coefs - 1;
    if( b_8x8 )
    {
        start = idx&3;
        end = 60 + start;
        step = 4;
    }
    idx &= 15;

    lambda2 <<= LAMBDA_BITS;

    /* Find last non-zero coefficient. */
    for( i = end; i >= start; i -= step )
        if( abs(dct[zigzag[i]]) * (dc?quant_mf[0]>>1:quant_mf[zigzag[i]]) >= f )
            break;

    if( i < start )
        goto zeroblock;

    /* Prepare for QNS search: calculate distortion caused by each DCT coefficient
     * rounding to be searched.
     *
     * We only search two roundings (nearest and nearest-1) like in CABAC trellis,
     * so we just store the difference in distortion between them. */
    int last_nnz = b_8x8 ? i >> 2 : i;
    int coef_mask = 0;
    int round_mask = 0;
    for( i = b_ac, j = start; i <= last_nnz; i++, j += step )
    {
        int coef = dct[zigzag[j]];
        int abs_coef = abs(coef);
        int sign = coef < 0 ? -1 : 1;
        int nearest_quant = ( f + abs_coef * (dc?quant_mf[0]>>1:quant_mf[zigzag[j]]) ) >> 16;
        quant_coefs[1][i] = quant_coefs[0][i] = sign * nearest_quant;
        coefs[i] = quant_coefs[1][i];
        if( nearest_quant )
        {
            /* We initialize the trellis with a deadzone halfway between nearest rounding
             * and always-round-down.  This gives much better results than initializing to either
             * extreme.
             * FIXME: should we initialize to the deadzones used by deadzone quant? */
            int deadzone_quant = ( f/2 + abs_coef * (dc?quant_mf[0]>>1:quant_mf[zigzag[j]]) ) >> 16;
            int unquant1 = (((dc?unquant_mf[0]<<1:unquant_mf[zigzag[j]]) * (nearest_quant-0) + 128) >> 8);
            int unquant0 = (((dc?unquant_mf[0]<<1:unquant_mf[zigzag[j]]) * (nearest_quant-1) + 128) >> 8);
            int d1 = abs_coef - unquant1;
            int d0 = abs_coef - unquant0;
            delta_distortion[i] = (int64_t)(d0*d0 - d1*d1) * (dc?256:coef_weight2[zigzag[j]]);

            /* Psy trellis: bias in favor of higher AC coefficients in the reconstructed frame. */
            if( h->mb.i_psy_trellis && j && !dc && !b_chroma )
            {
                int orig_coef = b_8x8 ? h->mb.pic.fenc_dct8[idx>>2][zigzag[j]] : h->mb.pic.fenc_dct4[idx][zigzag[j]];
                int predicted_coef = orig_coef - coef;
                int psy_weight = coef_weight1[zigzag[j]];
                int psy_value0 = h->mb.i_psy_trellis * abs(predicted_coef + unquant0 * sign);
                int psy_value1 = h->mb.i_psy_trellis * abs(predicted_coef + unquant1 * sign);
                delta_distortion[i] += (psy_value0 - psy_value1) * psy_weight;
            }

            quant_coefs[0][i] = sign * (nearest_quant-1);
            if( deadzone_quant != nearest_quant )
                coefs[i] = quant_coefs[0][i];
            else
                round_mask |= 1 << i;
        }
        else
            delta_distortion[i] = 0;
        coef_mask |= (!!coefs[i]) << i;
    }

    /* Calculate the cost of the starting state. */
    h->out.bs.i_bits_encoded = 0;
    if( !coef_mask )
        bs_write_vlc( &h->out.bs, x264_coeff0_token[nC] );
    else
        cavlc_block_residual_internal( h, ctx_block_cat, coefs + b_ac, nC );
    score = (int64_t)h->out.bs.i_bits_encoded * lambda2;

    /* QNS loop: pick the change that improves RD the most, apply it, repeat.
     * coef_mask and round_mask are used to simplify tracking of nonzeroness
     * and rounding modes chosen. */
    while( 1 )
    {
        int64_t iter_score = score;
        int64_t iter_distortion_delta = 0;
        int iter_coef = -1;
        int iter_mask = coef_mask;
        int iter_round = round_mask;
        for( i = b_ac; i <= last_nnz; i++ )
        {
            if( !delta_distortion[i] )
                continue;

            /* Set up all the variables for this iteration. */
            int cur_round = round_mask ^ (1 << i);
            int round_change = (cur_round >> i)&1;
            int old_coef = coefs[i];
            int new_coef = quant_coefs[round_change][i];
            int cur_mask = (coef_mask&~(1 << i))|(!!new_coef << i);
            int64_t cur_distortion_delta = delta_distortion[i] * (round_change ? -1 : 1);
            int64_t cur_score = cur_distortion_delta;
            coefs[i] = new_coef;

            /* Count up bits. */
            h->out.bs.i_bits_encoded = 0;
            if( !cur_mask )
                bs_write_vlc( &h->out.bs, x264_coeff0_token[nC] );
            else
                cavlc_block_residual_internal( h, ctx_block_cat, coefs + b_ac, nC );
            cur_score += (int64_t)h->out.bs.i_bits_encoded * lambda2;

            coefs[i] = old_coef;
            if( cur_score < iter_score )
            {
                iter_score = cur_score;
                iter_coef = i;
                iter_mask = cur_mask;
                iter_round = cur_round;
                iter_distortion_delta = cur_distortion_delta;
            }
        }
        if( iter_coef >= 0 )
        {
            score = iter_score - iter_distortion_delta;
            coef_mask = iter_mask;
            round_mask = iter_round;
            coefs[iter_coef] = quant_coefs[((round_mask >> iter_coef)&1)][iter_coef];
            /* Don't try adjusting coefficients we've already adjusted.
             * Testing suggests this doesn't hurt results -- and sometimes actually helps. */
            delta_distortion[iter_coef] = 0;
        }
        else
            break;
    }

    if( coef_mask )
    {
        for( i = b_ac, j = start; i < num_coefs; i++, j += step )
            dct[zigzag[j]] = coefs[i];
        return 1;
    }

zeroblock:
    if( !dc )
    {
        if( b_8x8 )
            for( i = start; i <= end; i+=step )
                dct[zigzag[i]] = 0;
        else
            memset( dct, 0, 16*sizeof(dctcoef) );
    }
    return 0;
}

int x264_quant_luma_dc_trellis( x264_t *h, dctcoef *dct, int i_quant_cat, int i_qp, int ctx_block_cat, int b_intra, int idx )
{
    if( h->param.b_cabac )
        return quant_trellis_cabac( h, dct,
            h->quant4_mf[i_quant_cat][i_qp], h->quant4_bias0[i_quant_cat][i_qp],
            h->unquant4_mf[i_quant_cat][i_qp], x264_zigzag_scan4[MB_INTERLACED],
            ctx_block_cat, h->mb.i_trellis_lambda2[0][b_intra], 0, 0, 1, 16, idx );

    return quant_trellis_cavlc( h, dct,
        h->quant4_mf[i_quant_cat][i_qp], h->unquant4_mf[i_quant_cat][i_qp], x264_zigzag_scan4[MB_INTERLACED],
        DCT_LUMA_DC, h->mb.i_trellis_lambda2[0][b_intra], 0, 0, 1, 16, idx, 0 );
}

static const uint8_t zigzag_scan2x2[4] = { 0, 1, 2, 3 };
static const uint8_t zigzag_scan2x4[8] = { 0, 2, 1, 4, 6, 3, 5, 7 };

int x264_quant_chroma_dc_trellis( x264_t *h, dctcoef *dct, int i_qp, int b_intra, int idx )
{
    const uint8_t *zigzag;
    int num_coefs;
    int quant_cat = CQM_4IC+1 - b_intra;

    if( CHROMA_FORMAT == CHROMA_422 )
    {
        zigzag = zigzag_scan2x4;
        num_coefs = 8;
    }
    else
    {
        zigzag = zigzag_scan2x2;
        num_coefs = 4;
    }

    if( h->param.b_cabac )
        return quant_trellis_cabac( h, dct,
            h->quant4_mf[quant_cat][i_qp], h->quant4_bias0[quant_cat][i_qp],
            h->unquant4_mf[quant_cat][i_qp], zigzag,
            DCT_CHROMA_DC, h->mb.i_trellis_lambda2[1][b_intra], 0, 1, 1, num_coefs, idx );

    return quant_trellis_cavlc( h, dct,
        h->quant4_mf[quant_cat][i_qp], h->unquant4_mf[quant_cat][i_qp], zigzag,
        DCT_CHROMA_DC, h->mb.i_trellis_lambda2[1][b_intra], 0, 1, 1, num_coefs, idx, 0 );
}

int x264_quant_4x4_trellis( x264_t *h, dctcoef *dct, int i_quant_cat,
                            int i_qp, int ctx_block_cat, int b_intra, int b_chroma, int idx )
{
    static const uint8_t ctx_ac[14] = {0,1,0,0,1,0,0,1,0,0,0,1,0,0};
    int b_ac = ctx_ac[ctx_block_cat];
    if( h->param.b_cabac )
        return quant_trellis_cabac( h, dct,
            h->quant4_mf[i_quant_cat][i_qp], h->quant4_bias0[i_quant_cat][i_qp],
            h->unquant4_mf[i_quant_cat][i_qp], x264_zigzag_scan4[MB_INTERLACED],
            ctx_block_cat, h->mb.i_trellis_lambda2[b_chroma][b_intra], b_ac, b_chroma, 0, 16, idx );

    return quant_trellis_cavlc( h, dct,
            h->quant4_mf[i_quant_cat][i_qp], h->unquant4_mf[i_quant_cat][i_qp],
            x264_zigzag_scan4[MB_INTERLACED],
            ctx_block_cat, h->mb.i_trellis_lambda2[b_chroma][b_intra], b_ac, b_chroma, 0, 16, idx, 0 );
}

int x264_quant_8x8_trellis( x264_t *h, dctcoef *dct, int i_quant_cat,
                            int i_qp, int ctx_block_cat, int b_intra, int b_chroma, int idx )
{
    if( h->param.b_cabac )
    {
        return quant_trellis_cabac( h, dct,
            h->quant8_mf[i_quant_cat][i_qp], h->quant8_bias0[i_quant_cat][i_qp],
            h->unquant8_mf[i_quant_cat][i_qp], x264_zigzag_scan8[MB_INTERLACED],
            ctx_block_cat, h->mb.i_trellis_lambda2[b_chroma][b_intra], 0, b_chroma, 0, 64, idx );
    }

    /* 8x8 CAVLC is split into 4 4x4 blocks */
    int nzaccum = 0;
    for( int i = 0; i < 4; i++ )
    {
        int nz = quant_trellis_cavlc( h, dct,
            h->quant8_mf[i_quant_cat][i_qp], h->unquant8_mf[i_quant_cat][i_qp],
            x264_zigzag_scan8[MB_INTERLACED],
            DCT_LUMA_4x4, h->mb.i_trellis_lambda2[b_chroma][b_intra], 0, b_chroma, 0, 16, idx*4+i, 1 );
        /* Set up nonzero count for future calls */
        h->mb.cache.non_zero_count[x264_scan8[idx*4+i]] = nz;
        nzaccum |= nz;
    }
    STORE_8x8_NNZ( 0, idx, 0 );
    return nzaccum;
}
