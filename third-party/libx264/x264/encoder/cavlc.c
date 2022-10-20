/*****************************************************************************
 * cavlc.c: cavlc bitstream writing
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

#include "common/common.h"
#include "macroblock.h"

#ifndef RDO_SKIP_BS
#define RDO_SKIP_BS 0
#endif

/* [400,420][inter,intra] */
static const uint8_t cbp_to_golomb[2][2][48] =
{
    {{ 0,  1,  2,  5,  3,  6, 14, 10,  4, 15,  7, 11,  8, 12, 13,  9 },
     { 1, 10, 11,  6, 12,  7, 14,  2, 13, 15,  8,  3,  9,  4,  5,  0 }},
    {{ 0,  2,  3,  7,  4,  8, 17, 13,  5, 18,  9, 14, 10, 15, 16, 11,
       1, 32, 33, 36, 34, 37, 44, 40, 35, 45, 38, 41, 39, 42, 43, 19,
       6, 24, 25, 20, 26, 21, 46, 28, 27, 47, 22, 29, 23, 30, 31, 12 },
     { 3, 29, 30, 17, 31, 18, 37,  8, 32, 38, 19,  9, 20, 10, 11,  2,
      16, 33, 34, 21, 35, 22, 39,  4, 36, 40, 23,  5, 24,  6,  7,  1,
      41, 42, 43, 25, 44, 26, 46, 12, 45, 47, 27, 13, 28, 14, 15,  0 }}
};

static const uint8_t mb_type_b_to_golomb[3][9]=
{
    { 4,  8, 12, 10,  6, 14, 16, 18, 20 }, /* D_16x8 */
    { 5,  9, 13, 11,  7, 15, 17, 19, 21 }, /* D_8x16 */
    { 1, -1, -1, -1,  2, -1, -1, -1,  3 }  /* D_16x16 */
};

static const uint8_t subpartition_p_to_golomb[4]=
{
    3, 1, 2, 0
};

static const uint8_t subpartition_b_to_golomb[13]=
{
    10,  4,  5,  1, 11,  6,  7,  2, 12,  8,  9,  3,  0
};

#define bs_write_vlc(s,v) bs_write( s, (v).i_size, (v).i_bits )

/****************************************************************************
 * x264_cavlc_block_residual:
 ****************************************************************************/
static inline int cavlc_block_residual_escape( x264_t *h, int i_suffix_length, int level )
{
    bs_t *s = &h->out.bs;
    static const uint16_t next_suffix[7] = { 0, 3, 6, 12, 24, 48, 0xffff };
    int i_level_prefix = 15;
    int mask = level >> 31;
    int abs_level = (level^mask)-mask;
    int i_level_code = abs_level*2-mask-2;
    if( ( i_level_code >> i_suffix_length ) < 15 )
    {
        bs_write( s, (i_level_code >> i_suffix_length) + 1 + i_suffix_length,
                 (1<<i_suffix_length) + (i_level_code & ((1<<i_suffix_length)-1)) );
    }
    else
    {
        i_level_code -= 15 << i_suffix_length;
        if( i_suffix_length == 0 )
            i_level_code -= 15;

        /* If the prefix size exceeds 15, High Profile is required. */
        if( i_level_code >= 1<<12 )
        {
            if( h->sps->i_profile_idc >= PROFILE_HIGH )
            {
                while( i_level_code >= 1<<(i_level_prefix-3) )
                {
                    i_level_code -= 1<<(i_level_prefix-3);
                    i_level_prefix++;
                }
            }
            else
            {
#if RDO_SKIP_BS
                /* Weight highly against overflows. */
                s->i_bits_encoded += 2000;
#else
                /* We've had an overflow; note it down and re-encode the MB later. */
                h->mb.b_overflow = 1;
#endif
            }
        }
        bs_write( s, i_level_prefix + 1, 1 );
        bs_write( s, i_level_prefix - 3, i_level_code & ((1<<(i_level_prefix-3))-1) );
    }
    if( i_suffix_length == 0 )
        i_suffix_length++;
    if( abs_level > next_suffix[i_suffix_length] )
        i_suffix_length++;
    return i_suffix_length;
}

static int cavlc_block_residual_internal( x264_t *h, int ctx_block_cat, dctcoef *l, int nC )
{
    bs_t *s = &h->out.bs;
    static const uint8_t ctz_index[8] = {3,0,1,0,2,0,1,0};
    static const uint8_t count_cat[14] = {16, 15, 16, 0, 15, 64, 16, 15, 16, 64, 16, 15, 16, 64};
    x264_run_level_t runlevel;
    int i_total, i_trailing, i_total_zero, i_suffix_length;
    unsigned int i_sign;

    /* level and run and total */
    i_total = h->quantf.coeff_level_run[ctx_block_cat]( l, &runlevel );
    x264_prefetch( &x264_run_before[runlevel.mask] );
    i_total_zero = runlevel.last + 1 - i_total;

    /* branchless i_trailing calculation */
    runlevel.level[i_total+0] = 2;
    runlevel.level[i_total+1] = 2;
    i_trailing = ((((runlevel.level[0]+1) | (1-runlevel.level[0])) >> 31) & 1) // abs(runlevel.level[0])>1
               | ((((runlevel.level[1]+1) | (1-runlevel.level[1])) >> 31) & 2)
               | ((((runlevel.level[2]+1) | (1-runlevel.level[2])) >> 31) & 4);
    i_trailing = ctz_index[i_trailing];
    i_sign = ((runlevel.level[2] >> 31) & 1)
           | ((runlevel.level[1] >> 31) & 2)
           | ((runlevel.level[0] >> 31) & 4);
    i_sign >>= 3-i_trailing;

    /* total/trailing */
    bs_write_vlc( s, x264_coeff_token[nC][i_total-1][i_trailing] );

    i_suffix_length = i_total > 10 && i_trailing < 3;
    bs_write( s, i_trailing, i_sign );

    if( i_trailing < i_total )
    {
        int val = runlevel.level[i_trailing];
        int val_original = runlevel.level[i_trailing]+LEVEL_TABLE_SIZE/2;
        val -= ((val>>31)|1) & -(i_trailing < 3); /* as runlevel.level[i] can't be 1 for the first one if i_trailing < 3 */
        val += LEVEL_TABLE_SIZE/2;

        if( (unsigned)val_original < LEVEL_TABLE_SIZE )
        {
            bs_write_vlc( s, x264_level_token[i_suffix_length][val] );
            i_suffix_length = x264_level_token[i_suffix_length][val_original].i_next;
        }
        else
            i_suffix_length = cavlc_block_residual_escape( h, i_suffix_length, val-LEVEL_TABLE_SIZE/2 );
        for( int i = i_trailing+1; i < i_total; i++ )
        {
            val = runlevel.level[i] + LEVEL_TABLE_SIZE/2;
            if( (unsigned)val < LEVEL_TABLE_SIZE )
            {
                bs_write_vlc( s, x264_level_token[i_suffix_length][val] );
                i_suffix_length = x264_level_token[i_suffix_length][val].i_next;
            }
            else
                i_suffix_length = cavlc_block_residual_escape( h, i_suffix_length, val-LEVEL_TABLE_SIZE/2 );
        }
    }

    if( ctx_block_cat == DCT_CHROMA_DC )
    {
        if( i_total < 8>>CHROMA_V_SHIFT )
        {
            vlc_t total_zeros = CHROMA_FORMAT == CHROMA_420 ? x264_total_zeros_2x2_dc[i_total-1][i_total_zero]
                                                            : x264_total_zeros_2x4_dc[i_total-1][i_total_zero];
            bs_write_vlc( s, total_zeros );
        }
    }
    else if( (uint8_t)i_total < count_cat[ctx_block_cat] )
        bs_write_vlc( s, x264_total_zeros[i_total-1][i_total_zero] );

    int zero_run_code = x264_run_before[runlevel.mask];
    bs_write( s, zero_run_code&0x1f, zero_run_code>>5 );

    return i_total;
}

static const uint8_t ct_index[17] = {0,0,1,1,2,2,2,2,3,3,3,3,3,3,3,3,3};

#define x264_cavlc_block_residual(h,cat,idx,l)\
{\
    int nC = cat == DCT_CHROMA_DC ? 5 - CHROMA_V_SHIFT\
                                  : ct_index[x264_mb_predict_non_zero_code( h, cat == DCT_LUMA_DC ? (idx - LUMA_DC)*16 : idx )];\
    uint8_t *nnz = &h->mb.cache.non_zero_count[x264_scan8[idx]];\
    if( !*nnz )\
        bs_write_vlc( &h->out.bs, x264_coeff0_token[nC] );\
    else\
        *nnz = cavlc_block_residual_internal(h,cat,l,nC);\
}

static void cavlc_qp_delta( x264_t *h )
{
    bs_t *s = &h->out.bs;
    int i_dqp = h->mb.i_qp - h->mb.i_last_qp;

    /* Avoid writing a delta quant if we have an empty i16x16 block, e.g. in a completely
     * flat background area. Don't do this if it would raise the quantizer, since that could
     * cause unexpected deblocking artifacts. */
    if( h->mb.i_type == I_16x16 && !(h->mb.i_cbp_luma | h->mb.i_cbp_chroma)
        && !h->mb.cache.non_zero_count[x264_scan8[LUMA_DC]]
        && !h->mb.cache.non_zero_count[x264_scan8[CHROMA_DC+0]]
        && !h->mb.cache.non_zero_count[x264_scan8[CHROMA_DC+1]]
        && h->mb.i_qp > h->mb.i_last_qp )
    {
#if !RDO_SKIP_BS
        h->mb.i_qp = h->mb.i_last_qp;
#endif
        i_dqp = 0;
    }

    if( i_dqp )
    {
        if( i_dqp < -(QP_MAX_SPEC+1)/2 )
            i_dqp += QP_MAX_SPEC+1;
        else if( i_dqp > QP_MAX_SPEC/2 )
            i_dqp -= QP_MAX_SPEC+1;
    }
    bs_write_se( s, i_dqp );
}

static void cavlc_mvd( x264_t *h, int i_list, int idx, int width )
{
    bs_t *s = &h->out.bs;
    ALIGNED_4( int16_t mvp[2] );
    x264_mb_predict_mv( h, i_list, idx, width, mvp );
    bs_write_se( s, h->mb.cache.mv[i_list][x264_scan8[idx]][0] - mvp[0] );
    bs_write_se( s, h->mb.cache.mv[i_list][x264_scan8[idx]][1] - mvp[1] );
}

static inline void cavlc_8x8_mvd( x264_t *h, int i )
{
    switch( h->mb.i_sub_partition[i] )
    {
        case D_L0_8x8:
            cavlc_mvd( h, 0, 4*i, 2 );
            break;
        case D_L0_8x4:
            cavlc_mvd( h, 0, 4*i+0, 2 );
            cavlc_mvd( h, 0, 4*i+2, 2 );
            break;
        case D_L0_4x8:
            cavlc_mvd( h, 0, 4*i+0, 1 );
            cavlc_mvd( h, 0, 4*i+1, 1 );
            break;
        case D_L0_4x4:
            cavlc_mvd( h, 0, 4*i+0, 1 );
            cavlc_mvd( h, 0, 4*i+1, 1 );
            cavlc_mvd( h, 0, 4*i+2, 1 );
            cavlc_mvd( h, 0, 4*i+3, 1 );
            break;
    }
}

static ALWAYS_INLINE void cavlc_macroblock_luma_residual( x264_t *h, int plane_count )
{
    if( h->mb.b_transform_8x8 )
    {
        /* shuffle 8x8 dct coeffs into 4x4 lists */
        for( int p = 0; p < plane_count; p++ )
            for( int i8 = 0; i8 < 4; i8++ )
                if( h->mb.cache.non_zero_count[x264_scan8[p*16+i8*4]] )
                    h->zigzagf.interleave_8x8_cavlc( h->dct.luma4x4[p*16+i8*4], h->dct.luma8x8[p*4+i8],
                                                     &h->mb.cache.non_zero_count[x264_scan8[p*16+i8*4]] );
    }

    for( int p = 0; p < plane_count; p++ )
        FOREACH_BIT( i8, 0, h->mb.i_cbp_luma )
            for( int i4 = 0; i4 < 4; i4++ )
                x264_cavlc_block_residual( h, DCT_LUMA_4x4, i4+i8*4+p*16, h->dct.luma4x4[i4+i8*4+p*16] );
}

#if RDO_SKIP_BS
static ALWAYS_INLINE void cavlc_partition_luma_residual( x264_t *h, int i8, int p )
{
    if( h->mb.b_transform_8x8 && h->mb.cache.non_zero_count[x264_scan8[i8*4+p*16]] )
        h->zigzagf.interleave_8x8_cavlc( h->dct.luma4x4[i8*4+p*16], h->dct.luma8x8[i8+p*4],
                                         &h->mb.cache.non_zero_count[x264_scan8[i8*4+p*16]] );

    if( h->mb.i_cbp_luma & (1 << i8) )
        for( int i4 = 0; i4 < 4; i4++ )
            x264_cavlc_block_residual( h, DCT_LUMA_4x4, i4+i8*4+p*16, h->dct.luma4x4[i4+i8*4+p*16] );
}
#endif

static void cavlc_mb_header_i( x264_t *h, int i_mb_type, int i_mb_i_offset, int chroma )
{
    bs_t *s = &h->out.bs;
    if( i_mb_type == I_16x16 )
    {
        bs_write_ue( s, i_mb_i_offset + 1 + x264_mb_pred_mode16x16_fix[h->mb.i_intra16x16_pred_mode] +
                        h->mb.i_cbp_chroma * 4 + ( h->mb.i_cbp_luma == 0 ? 0 : 12 ) );
    }
    else //if( i_mb_type == I_4x4 || i_mb_type == I_8x8 )
    {
        int di = i_mb_type == I_8x8 ? 4 : 1;
        bs_write_ue( s, i_mb_i_offset + 0 );
        if( h->pps->b_transform_8x8_mode )
            bs_write1( s, h->mb.b_transform_8x8 );

        /* Prediction: Luma */
        for( int i = 0; i < 16; i += di )
        {
            int i_pred = x264_mb_predict_intra4x4_mode( h, i );
            int i_mode = x264_mb_pred_mode4x4_fix( h->mb.cache.intra4x4_pred_mode[x264_scan8[i]] );

            if( i_pred == i_mode )
                bs_write1( s, 1 );  /* b_prev_intra4x4_pred_mode */
            else
                bs_write( s, 4, i_mode - (i_mode > i_pred) );
        }

    }
    if( chroma )
        bs_write_ue( s, x264_mb_chroma_pred_mode_fix[h->mb.i_chroma_pred_mode] );
}

static ALWAYS_INLINE void cavlc_mb_header_p( x264_t *h, int i_mb_type, int chroma )
{
    bs_t *s = &h->out.bs;
    if( i_mb_type == P_L0 )
    {
        if( h->mb.i_partition == D_16x16 )
        {
            bs_write1( s, 1 );

            if( h->mb.pic.i_fref[0] > 1 )
                bs_write_te( s, h->mb.pic.i_fref[0] - 1, h->mb.cache.ref[0][x264_scan8[0]] );
            cavlc_mvd( h, 0, 0, 4 );
        }
        else if( h->mb.i_partition == D_16x8 )
        {
            bs_write_ue( s, 1 );
            if( h->mb.pic.i_fref[0] > 1 )
            {
                bs_write_te( s, h->mb.pic.i_fref[0] - 1, h->mb.cache.ref[0][x264_scan8[0]] );
                bs_write_te( s, h->mb.pic.i_fref[0] - 1, h->mb.cache.ref[0][x264_scan8[8]] );
            }
            cavlc_mvd( h, 0, 0, 4 );
            cavlc_mvd( h, 0, 8, 4 );
        }
        else if( h->mb.i_partition == D_8x16 )
        {
            bs_write_ue( s, 2 );
            if( h->mb.pic.i_fref[0] > 1 )
            {
                bs_write_te( s, h->mb.pic.i_fref[0] - 1, h->mb.cache.ref[0][x264_scan8[0]] );
                bs_write_te( s, h->mb.pic.i_fref[0] - 1, h->mb.cache.ref[0][x264_scan8[4]] );
            }
            cavlc_mvd( h, 0, 0, 2 );
            cavlc_mvd( h, 0, 4, 2 );
        }
    }
    else if( i_mb_type == P_8x8 )
    {
        int b_sub_ref;
        if( (h->mb.cache.ref[0][x264_scan8[0]] | h->mb.cache.ref[0][x264_scan8[ 4]] |
             h->mb.cache.ref[0][x264_scan8[8]] | h->mb.cache.ref[0][x264_scan8[12]]) == 0 )
        {
            bs_write_ue( s, 4 );
            b_sub_ref = 0;
        }
        else
        {
            bs_write_ue( s, 3 );
            b_sub_ref = 1;
        }

        /* sub mb type */
        if( h->param.analyse.inter & X264_ANALYSE_PSUB8x8 )
            for( int i = 0; i < 4; i++ )
                bs_write_ue( s, subpartition_p_to_golomb[ h->mb.i_sub_partition[i] ] );
        else
            bs_write( s, 4, 0xf );

        /* ref0 */
        if( b_sub_ref )
        {
            bs_write_te( s, h->mb.pic.i_fref[0] - 1, h->mb.cache.ref[0][x264_scan8[0]] );
            bs_write_te( s, h->mb.pic.i_fref[0] - 1, h->mb.cache.ref[0][x264_scan8[4]] );
            bs_write_te( s, h->mb.pic.i_fref[0] - 1, h->mb.cache.ref[0][x264_scan8[8]] );
            bs_write_te( s, h->mb.pic.i_fref[0] - 1, h->mb.cache.ref[0][x264_scan8[12]] );
        }

        for( int i = 0; i < 4; i++ )
            cavlc_8x8_mvd( h, i );
    }
    else //if( IS_INTRA( i_mb_type ) )
        cavlc_mb_header_i( h, i_mb_type, 5, chroma );
}

static ALWAYS_INLINE void cavlc_mb_header_b( x264_t *h, int i_mb_type, int chroma )
{
    bs_t *s = &h->out.bs;
    if( i_mb_type == B_8x8 )
    {
        bs_write_ue( s, 22 );

        /* sub mb type */
        for( int i = 0; i < 4; i++ )
            bs_write_ue( s, subpartition_b_to_golomb[ h->mb.i_sub_partition[i] ] );

        /* ref */
        if( h->mb.pic.i_fref[0] > 1 )
            for( int i = 0; i < 4; i++ )
                if( x264_mb_partition_listX_table[0][ h->mb.i_sub_partition[i] ] )
                    bs_write_te( s, h->mb.pic.i_fref[0] - 1, h->mb.cache.ref[0][x264_scan8[i*4]] );
        if( h->mb.pic.i_fref[1] > 1 )
            for( int i = 0; i < 4; i++ )
                if( x264_mb_partition_listX_table[1][ h->mb.i_sub_partition[i] ] )
                    bs_write_te( s, h->mb.pic.i_fref[1] - 1, h->mb.cache.ref[1][x264_scan8[i*4]] );

        /* mvd */
        for( int i = 0; i < 4; i++ )
            if( x264_mb_partition_listX_table[0][ h->mb.i_sub_partition[i] ] )
                cavlc_mvd( h, 0, 4*i, 2 );
        for( int i = 0; i < 4; i++ )
            if( x264_mb_partition_listX_table[1][ h->mb.i_sub_partition[i] ] )
                cavlc_mvd( h, 1, 4*i, 2 );
    }
    else if( i_mb_type >= B_L0_L0 && i_mb_type <= B_BI_BI )
    {
        /* All B mode */
        /* Motion Vector */
        const uint8_t (*b_list)[2] = x264_mb_type_list_table[i_mb_type];
        const int i_ref0_max = h->mb.pic.i_fref[0] - 1;
        const int i_ref1_max = h->mb.pic.i_fref[1] - 1;

        bs_write_ue( s, mb_type_b_to_golomb[ h->mb.i_partition - D_16x8 ][ i_mb_type - B_L0_L0 ] );
        if( h->mb.i_partition == D_16x16 )
        {
            if( i_ref0_max && b_list[0][0] ) bs_write_te( s, i_ref0_max, h->mb.cache.ref[0][x264_scan8[0]] );
            if( i_ref1_max && b_list[1][0] ) bs_write_te( s, i_ref1_max, h->mb.cache.ref[1][x264_scan8[0]] );
            if( b_list[0][0] ) cavlc_mvd( h, 0, 0, 4 );
            if( b_list[1][0] ) cavlc_mvd( h, 1, 0, 4 );
        }
        else
        {
            if( i_ref0_max && b_list[0][0] ) bs_write_te( s, i_ref0_max, h->mb.cache.ref[0][x264_scan8[ 0]] );
            if( i_ref0_max && b_list[0][1] ) bs_write_te( s, i_ref0_max, h->mb.cache.ref[0][x264_scan8[12]] );
            if( i_ref1_max && b_list[1][0] ) bs_write_te( s, i_ref1_max, h->mb.cache.ref[1][x264_scan8[ 0]] );
            if( i_ref1_max && b_list[1][1] ) bs_write_te( s, i_ref1_max, h->mb.cache.ref[1][x264_scan8[12]] );
            if( h->mb.i_partition == D_16x8 )
            {
                if( b_list[0][0] ) cavlc_mvd( h, 0, 0, 4 );
                if( b_list[0][1] ) cavlc_mvd( h, 0, 8, 4 );
                if( b_list[1][0] ) cavlc_mvd( h, 1, 0, 4 );
                if( b_list[1][1] ) cavlc_mvd( h, 1, 8, 4 );
            }
            else //if( h->mb.i_partition == D_8x16 )
            {
                if( b_list[0][0] ) cavlc_mvd( h, 0, 0, 2 );
                if( b_list[0][1] ) cavlc_mvd( h, 0, 4, 2 );
                if( b_list[1][0] ) cavlc_mvd( h, 1, 0, 2 );
                if( b_list[1][1] ) cavlc_mvd( h, 1, 4, 2 );
            }
        }
    }
    else if( i_mb_type == B_DIRECT )
        bs_write1( s, 1 );
    else //if( IS_INTRA( i_mb_type ) )
        cavlc_mb_header_i( h, i_mb_type, 23, chroma );
}

/*****************************************************************************
 * x264_macroblock_write:
 *****************************************************************************/
void x264_macroblock_write_cavlc( x264_t *h )
{
    bs_t *s = &h->out.bs;
    const int i_mb_type = h->mb.i_type;
    int plane_count = CHROMA444 ? 3 : 1;
    int chroma = CHROMA_FORMAT == CHROMA_420 || CHROMA_FORMAT == CHROMA_422;

#if RDO_SKIP_BS
    s->i_bits_encoded = 0;
#else
    const int i_mb_pos_start = bs_pos( s );
    int       i_mb_pos_tex;
#endif

    if( SLICE_MBAFF
        && (!(h->mb.i_mb_y & 1) || IS_SKIP(h->mb.type[h->mb.i_mb_xy - h->mb.i_mb_stride])) )
    {
        bs_write1( s, MB_INTERLACED );
#if !RDO_SKIP_BS
        h->mb.field_decoding_flag = MB_INTERLACED;
#endif
    }

#if !RDO_SKIP_BS
    if( i_mb_type == I_PCM )
    {
        static const uint8_t i_offsets[3] = {5,23,0};
        uint8_t *p_start = s->p_start;
        bs_write_ue( s, i_offsets[h->sh.i_type] + 25 );
        i_mb_pos_tex = bs_pos( s );
        h->stat.frame.i_mv_bits += i_mb_pos_tex - i_mb_pos_start;

        bs_align_0( s );

        for( int p = 0; p < plane_count; p++ )
            for( int i = 0; i < 256; i++ )
                bs_write( s, BIT_DEPTH, h->mb.pic.p_fenc[p][i] );
        if( chroma )
            for( int ch = 1; ch < 3; ch++ )
                for( int i = 0; i < 16>>CHROMA_V_SHIFT; i++ )
                    for( int j = 0; j < 8; j++ )
                        bs_write( s, BIT_DEPTH, h->mb.pic.p_fenc[ch][i*FENC_STRIDE+j] );

        bs_init( s, s->p, s->p_end - s->p );
        s->p_start = p_start;

        h->stat.frame.i_tex_bits += bs_pos(s) - i_mb_pos_tex;
        return;
    }
#endif

    if( h->sh.i_type == SLICE_TYPE_P )
        cavlc_mb_header_p( h, i_mb_type, chroma );
    else if( h->sh.i_type == SLICE_TYPE_B )
        cavlc_mb_header_b( h, i_mb_type, chroma );
    else //if( h->sh.i_type == SLICE_TYPE_I )
        cavlc_mb_header_i( h, i_mb_type, 0, chroma );

#if !RDO_SKIP_BS
    i_mb_pos_tex = bs_pos( s );
    h->stat.frame.i_mv_bits += i_mb_pos_tex - i_mb_pos_start;
#endif

    /* Coded block pattern */
    if( i_mb_type != I_16x16 )
        bs_write_ue( s, cbp_to_golomb[chroma][IS_INTRA(i_mb_type)][(h->mb.i_cbp_chroma << 4)|h->mb.i_cbp_luma] );

    /* transform size 8x8 flag */
    if( x264_mb_transform_8x8_allowed( h ) && h->mb.i_cbp_luma )
        bs_write1( s, h->mb.b_transform_8x8 );

    if( i_mb_type == I_16x16 )
    {
        cavlc_qp_delta( h );

        /* DC Luma */
        for( int p = 0; p < plane_count; p++ )
        {
            x264_cavlc_block_residual( h, DCT_LUMA_DC, LUMA_DC+p, h->dct.luma16x16_dc[p] );

            /* AC Luma */
            if( h->mb.i_cbp_luma )
                for( int i = p*16; i < p*16+16; i++ )
                    x264_cavlc_block_residual( h, DCT_LUMA_AC, i, h->dct.luma4x4[i]+1 );
        }
    }
    else if( h->mb.i_cbp_luma | h->mb.i_cbp_chroma )
    {
        cavlc_qp_delta( h );
        cavlc_macroblock_luma_residual( h, plane_count );
    }
    if( h->mb.i_cbp_chroma )
    {
        /* Chroma DC residual present */
        x264_cavlc_block_residual( h, DCT_CHROMA_DC, CHROMA_DC+0, h->dct.chroma_dc[0] );
        x264_cavlc_block_residual( h, DCT_CHROMA_DC, CHROMA_DC+1, h->dct.chroma_dc[1] );
        if( h->mb.i_cbp_chroma == 2 ) /* Chroma AC residual present */
        {
            int step = 8 << CHROMA_V_SHIFT;
            for( int i = 16; i < 3*16; i += step )
                for( int j = i; j < i+4; j++ )
                    x264_cavlc_block_residual( h, DCT_CHROMA_AC, j, h->dct.luma4x4[j]+1 );
        }
    }

#if !RDO_SKIP_BS
    h->stat.frame.i_tex_bits += bs_pos(s) - i_mb_pos_tex;
#endif
}

#if RDO_SKIP_BS
/*****************************************************************************
 * RD only; doesn't generate a valid bitstream
 * doesn't write cbp or chroma dc (I don't know how much this matters)
 * doesn't write ref (never varies between calls, so no point in doing so)
 * only writes subpartition for p8x8, needed for sub-8x8 mode decision RDO
 * works on all partition sizes except 16x16
 *****************************************************************************/
static int partition_size_cavlc( x264_t *h, int i8, int i_pixel )
{
    bs_t *s = &h->out.bs;
    const int i_mb_type = h->mb.i_type;
    int b_8x16 = h->mb.i_partition == D_8x16;
    int plane_count = CHROMA444 ? 3 : 1;
    int j;

    h->out.bs.i_bits_encoded = 0;

    if( i_mb_type == P_8x8 )
    {
        cavlc_8x8_mvd( h, i8 );
        bs_write_ue( s, subpartition_p_to_golomb[ h->mb.i_sub_partition[i8] ] );
    }
    else if( i_mb_type == P_L0 )
        cavlc_mvd( h, 0, 4*i8, 4>>b_8x16 );
    else if( i_mb_type > B_DIRECT && i_mb_type < B_8x8 )
    {
        if( x264_mb_type_list_table[ i_mb_type ][0][!!i8] ) cavlc_mvd( h, 0, 4*i8, 4>>b_8x16 );
        if( x264_mb_type_list_table[ i_mb_type ][1][!!i8] ) cavlc_mvd( h, 1, 4*i8, 4>>b_8x16 );
    }
    else //if( i_mb_type == B_8x8 )
    {
        if( x264_mb_partition_listX_table[0][ h->mb.i_sub_partition[i8] ] )
            cavlc_mvd( h, 0, 4*i8, 2 );
        if( x264_mb_partition_listX_table[1][ h->mb.i_sub_partition[i8] ] )
            cavlc_mvd( h, 1, 4*i8, 2 );
    }

    for( j = (i_pixel < PIXEL_8x8); j >= 0; j-- )
    {
        for( int p = 0; p < plane_count; p++ )
            cavlc_partition_luma_residual( h, i8, p );
        if( h->mb.i_cbp_chroma )
        {
            if( CHROMA_FORMAT == CHROMA_422 )
            {
                int offset = (5*i8) & 0x09;
                x264_cavlc_block_residual( h, DCT_CHROMA_AC, 16+offset, h->dct.luma4x4[16+offset]+1 );
                x264_cavlc_block_residual( h, DCT_CHROMA_AC, 18+offset, h->dct.luma4x4[18+offset]+1 );
                x264_cavlc_block_residual( h, DCT_CHROMA_AC, 32+offset, h->dct.luma4x4[32+offset]+1 );
                x264_cavlc_block_residual( h, DCT_CHROMA_AC, 34+offset, h->dct.luma4x4[34+offset]+1 );
            }
            else
            {
                x264_cavlc_block_residual( h, DCT_CHROMA_AC, 16+i8, h->dct.luma4x4[16+i8]+1 );
                x264_cavlc_block_residual( h, DCT_CHROMA_AC, 32+i8, h->dct.luma4x4[32+i8]+1 );
            }
        }
        i8 += x264_pixel_size[i_pixel].h >> 3;
    }

    return h->out.bs.i_bits_encoded;
}

static int subpartition_size_cavlc( x264_t *h, int i4, int i_pixel )
{
    int plane_count = CHROMA444 ? 3 : 1;
    int b_8x4 = i_pixel == PIXEL_8x4;
    h->out.bs.i_bits_encoded = 0;
    cavlc_mvd( h, 0, i4, 1+b_8x4 );
    for( int p = 0; p < plane_count; p++ )
    {
        x264_cavlc_block_residual( h, DCT_LUMA_4x4, p*16+i4, h->dct.luma4x4[p*16+i4] );
        if( i_pixel != PIXEL_4x4 )
            x264_cavlc_block_residual( h, DCT_LUMA_4x4, p*16+i4+2-b_8x4, h->dct.luma4x4[p*16+i4+2-b_8x4] );
    }

    return h->out.bs.i_bits_encoded;
}

static int cavlc_intra4x4_pred_size( x264_t *h, int i4, int i_mode )
{
    if( x264_mb_predict_intra4x4_mode( h, i4 ) == x264_mb_pred_mode4x4_fix( i_mode ) )
        return 1;
    else
        return 4;
}

static int partition_i8x8_size_cavlc( x264_t *h, int i8, int i_mode )
{
    int plane_count = CHROMA444 ? 3 : 1;
    h->out.bs.i_bits_encoded = cavlc_intra4x4_pred_size( h, 4*i8, i_mode );
    bs_write_ue( &h->out.bs, cbp_to_golomb[!CHROMA444][1][(h->mb.i_cbp_chroma << 4)|h->mb.i_cbp_luma] );
    for( int p = 0; p < plane_count; p++ )
        cavlc_partition_luma_residual( h, i8, p );
    return h->out.bs.i_bits_encoded;
}

static int partition_i4x4_size_cavlc( x264_t *h, int i4, int i_mode )
{
    int plane_count = CHROMA444 ? 3 : 1;
    h->out.bs.i_bits_encoded = cavlc_intra4x4_pred_size( h, i4, i_mode );
    for( int p = 0; p < plane_count; p++ )
        x264_cavlc_block_residual( h, DCT_LUMA_4x4, p*16+i4, h->dct.luma4x4[p*16+i4] );
    return h->out.bs.i_bits_encoded;
}

static int chroma_size_cavlc( x264_t *h )
{
    h->out.bs.i_bits_encoded = bs_size_ue( x264_mb_chroma_pred_mode_fix[h->mb.i_chroma_pred_mode] );
    if( h->mb.i_cbp_chroma )
    {
        x264_cavlc_block_residual( h, DCT_CHROMA_DC, CHROMA_DC+0, h->dct.chroma_dc[0] );
        x264_cavlc_block_residual( h, DCT_CHROMA_DC, CHROMA_DC+1, h->dct.chroma_dc[1] );

        if( h->mb.i_cbp_chroma == 2 )
        {
            int step = 8 << CHROMA_V_SHIFT;
            for( int i = 16; i < 3*16; i += step )
                for( int j = i; j < i+4; j++ )
                    x264_cavlc_block_residual( h, DCT_CHROMA_AC, j, h->dct.luma4x4[j]+1 );
        }
    }
    return h->out.bs.i_bits_encoded;
}
#endif
