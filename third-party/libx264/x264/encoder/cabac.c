/*****************************************************************************
 * cabac.c: cabac bitstream writing
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

static inline void cabac_mb_type_intra( x264_t *h, x264_cabac_t *cb, int i_mb_type,
                                        int ctx0, int ctx1, int ctx2, int ctx3, int ctx4, int ctx5 )
{
    if( i_mb_type == I_4x4 || i_mb_type == I_8x8 )
    {
        x264_cabac_encode_decision_noup( cb, ctx0, 0 );
    }
#if !RDO_SKIP_BS
    else if( i_mb_type == I_PCM )
    {
        x264_cabac_encode_decision_noup( cb, ctx0, 1 );
        x264_cabac_encode_flush( h, cb );
    }
#endif
    else
    {
        int i_pred = x264_mb_pred_mode16x16_fix[h->mb.i_intra16x16_pred_mode];

        x264_cabac_encode_decision_noup( cb, ctx0, 1 );
        x264_cabac_encode_terminal( cb );

        x264_cabac_encode_decision_noup( cb, ctx1, !!h->mb.i_cbp_luma );
        if( h->mb.i_cbp_chroma == 0 )
            x264_cabac_encode_decision_noup( cb, ctx2, 0 );
        else
        {
            x264_cabac_encode_decision( cb, ctx2, 1 );
            x264_cabac_encode_decision_noup( cb, ctx3, h->mb.i_cbp_chroma>>1 );
        }
        x264_cabac_encode_decision( cb, ctx4, i_pred>>1 );
        x264_cabac_encode_decision_noup( cb, ctx5, i_pred&1 );
    }
}

#if !RDO_SKIP_BS
static void cabac_field_decoding_flag( x264_t *h, x264_cabac_t *cb )
{
    int ctx = 0;
    ctx += h->mb.field_decoding_flag & !!h->mb.i_mb_x;
    ctx += (h->mb.i_mb_top_mbpair_xy >= 0
            && h->mb.slice_table[h->mb.i_mb_top_mbpair_xy] == h->sh.i_first_mb
            && h->mb.field[h->mb.i_mb_top_mbpair_xy]);

    x264_cabac_encode_decision_noup( cb, 70 + ctx, MB_INTERLACED );
    h->mb.field_decoding_flag = MB_INTERLACED;
}
#endif

static void cabac_intra4x4_pred_mode( x264_cabac_t *cb, int i_pred, int i_mode )
{
    if( i_pred == i_mode )
        x264_cabac_encode_decision( cb, 68, 1 );
    else
    {
        x264_cabac_encode_decision( cb, 68, 0 );
        if( i_mode > i_pred  )
            i_mode--;
        x264_cabac_encode_decision( cb, 69, (i_mode     )&0x01 );
        x264_cabac_encode_decision( cb, 69, (i_mode >> 1)&0x01 );
        x264_cabac_encode_decision( cb, 69, (i_mode >> 2)      );
    }
}

static void cabac_intra_chroma_pred_mode( x264_t *h, x264_cabac_t *cb )
{
    int i_mode = x264_mb_chroma_pred_mode_fix[h->mb.i_chroma_pred_mode];
    int ctx = 0;

    /* No need to test for I4x4 or I_16x16 as cache_save handle that */
    if( (h->mb.i_neighbour & MB_LEFT) && h->mb.chroma_pred_mode[h->mb.i_mb_left_xy[0]] != 0 )
        ctx++;
    if( (h->mb.i_neighbour & MB_TOP) && h->mb.chroma_pred_mode[h->mb.i_mb_top_xy] != 0 )
        ctx++;

    x264_cabac_encode_decision_noup( cb, 64 + ctx, i_mode > 0 );
    if( i_mode > 0 )
    {
        x264_cabac_encode_decision( cb, 64 + 3, i_mode > 1 );
        if( i_mode > 1 )
            x264_cabac_encode_decision_noup( cb, 64 + 3, i_mode > 2 );
    }
}

static void cabac_cbp_luma( x264_t *h, x264_cabac_t *cb )
{
    int cbp = h->mb.i_cbp_luma;
    int cbp_l = h->mb.cache.i_cbp_left;
    int cbp_t = h->mb.cache.i_cbp_top;
    x264_cabac_encode_decision     ( cb, 76 - ((cbp_l >> 1) & 1) - ((cbp_t >> 1) & 2), (cbp >> 0) & 1 );
    x264_cabac_encode_decision     ( cb, 76 - ((cbp   >> 0) & 1) - ((cbp_t >> 2) & 2), (cbp >> 1) & 1 );
    x264_cabac_encode_decision     ( cb, 76 - ((cbp_l >> 3) & 1) - ((cbp   << 1) & 2), (cbp >> 2) & 1 );
    x264_cabac_encode_decision_noup( cb, 76 - ((cbp   >> 2) & 1) - ((cbp   >> 0) & 2), (cbp >> 3) & 1 );
}

static void cabac_cbp_chroma( x264_t *h, x264_cabac_t *cb )
{
    int cbp_a = h->mb.cache.i_cbp_left & 0x30;
    int cbp_b = h->mb.cache.i_cbp_top  & 0x30;
    int ctx = 0;

    if( cbp_a && h->mb.cache.i_cbp_left != -1 ) ctx++;
    if( cbp_b && h->mb.cache.i_cbp_top  != -1 ) ctx+=2;
    if( h->mb.i_cbp_chroma == 0 )
        x264_cabac_encode_decision_noup( cb, 77 + ctx, 0 );
    else
    {
        x264_cabac_encode_decision_noup( cb, 77 + ctx, 1 );

        ctx = 4;
        if( cbp_a == 0x20 ) ctx++;
        if( cbp_b == 0x20 ) ctx += 2;
        x264_cabac_encode_decision_noup( cb, 77 + ctx, h->mb.i_cbp_chroma >> 1 );
    }
}

static void cabac_qp_delta( x264_t *h, x264_cabac_t *cb )
{
    int i_dqp = h->mb.i_qp - h->mb.i_last_qp;
    int ctx;

    /* Avoid writing a delta quant if we have an empty i16x16 block, e.g. in a completely
     * flat background area. Don't do this if it would raise the quantizer, since that could
     * cause unexpected deblocking artifacts. */
    if( h->mb.i_type == I_16x16 && !h->mb.cbp[h->mb.i_mb_xy] && h->mb.i_qp > h->mb.i_last_qp )
    {
#if !RDO_SKIP_BS
        h->mb.i_qp = h->mb.i_last_qp;
#endif
        i_dqp = 0;
    }

    ctx = h->mb.i_last_dqp && (h->mb.type[h->mb.i_mb_prev_xy] == I_16x16 || (h->mb.cbp[h->mb.i_mb_prev_xy]&0x3f));

    if( i_dqp != 0 )
    {
        /* Faster than (i_dqp <= 0 ? (-2*i_dqp) : (2*i_dqp-1)).
         * If you so much as sneeze on these lines, gcc will compile this suboptimally. */
        i_dqp *= 2;
        int val = 1 - i_dqp;
        if( val < 0 ) val = i_dqp;
        val--;
        /* dqp is interpreted modulo (QP_MAX_SPEC+1) */
        if( val >= QP_MAX_SPEC && val != QP_MAX_SPEC+1 )
            val = 2*QP_MAX_SPEC+1 - val;
        do
        {
            x264_cabac_encode_decision( cb, 60 + ctx, 1 );
            ctx = 2+(ctx>>1);
        } while( --val );
    }
    x264_cabac_encode_decision_noup( cb, 60 + ctx, 0 );
}

#if !RDO_SKIP_BS
void x264_cabac_mb_skip( x264_t *h, int b_skip )
{
    int ctx = h->mb.cache.i_neighbour_skip + 11;
    if( h->sh.i_type != SLICE_TYPE_P )
       ctx += 13;
    x264_cabac_encode_decision( &h->cabac, ctx, b_skip );
}
#endif

static inline void cabac_subpartition_p( x264_cabac_t *cb, int i_sub )
{
    if( i_sub == D_L0_8x8 )
    {
        x264_cabac_encode_decision( cb, 21, 1 );
        return;
    }
    x264_cabac_encode_decision( cb, 21, 0 );
    if( i_sub == D_L0_8x4 )
        x264_cabac_encode_decision( cb, 22, 0 );
    else
    {
        x264_cabac_encode_decision( cb, 22, 1 );
        x264_cabac_encode_decision( cb, 23, i_sub == D_L0_4x8 );
    }
}

static ALWAYS_INLINE void cabac_subpartition_b( x264_cabac_t *cb, int i_sub )
{
    if( i_sub == D_DIRECT_8x8 )
    {
        x264_cabac_encode_decision( cb, 36, 0 );
        return;
    }
    x264_cabac_encode_decision( cb, 36, 1 );
    if( i_sub == D_BI_8x8 )
    {
        x264_cabac_encode_decision( cb, 37, 1 );
        x264_cabac_encode_decision( cb, 38, 0 );
        x264_cabac_encode_decision( cb, 39, 0 );
        x264_cabac_encode_decision( cb, 39, 0 );
        return;
    }
    x264_cabac_encode_decision( cb, 37, 0 );
    x264_cabac_encode_decision( cb, 39, i_sub == D_L1_8x8 );
}

static ALWAYS_INLINE void cabac_transform_size( x264_t *h, x264_cabac_t *cb )
{
    int ctx = 399 + h->mb.cache.i_neighbour_transform_size;
    x264_cabac_encode_decision_noup( cb, ctx, h->mb.b_transform_8x8 );
}

static ALWAYS_INLINE void cabac_ref_internal( x264_t *h, x264_cabac_t *cb, int i_list, int idx, int bframe )
{
    const int i8 = x264_scan8[idx];
    const int i_refa = h->mb.cache.ref[i_list][i8 - 1];
    const int i_refb = h->mb.cache.ref[i_list][i8 - 8];
    int ctx = 0;

    if( i_refa > 0 && (!bframe || !h->mb.cache.skip[i8 - 1]) )
        ctx++;
    if( i_refb > 0 && (!bframe || !h->mb.cache.skip[i8 - 8]) )
        ctx += 2;

    for( int i_ref = h->mb.cache.ref[i_list][i8]; i_ref > 0; i_ref-- )
    {
        x264_cabac_encode_decision( cb, 54 + ctx, 1 );
        ctx = (ctx>>2)+4;
    }
    x264_cabac_encode_decision( cb, 54 + ctx, 0 );
}

static NOINLINE void cabac_ref_p( x264_t *h, x264_cabac_t *cb, int idx )
{
    cabac_ref_internal( h, cb, 0, idx, 0 );
}
static NOINLINE void cabac_ref_b( x264_t *h, x264_cabac_t *cb, int i_list, int idx )
{
    cabac_ref_internal( h, cb, i_list, idx, 1 );
}

static ALWAYS_INLINE int cabac_mvd_cpn( x264_t *h, x264_cabac_t *cb, int i_list, int idx, int l, int mvd, int ctx )
{
    int ctxbase = l ? 47 : 40;

    if( mvd == 0 )
    {
        x264_cabac_encode_decision( cb, ctxbase + ctx, 0 );
        return 0;
    }

    int i_abs = abs( mvd );
    x264_cabac_encode_decision( cb, ctxbase + ctx, 1 );
#if RDO_SKIP_BS
    if( i_abs <= 3 )
    {
        for( int i = 1; i < i_abs; i++ )
            x264_cabac_encode_decision( cb, ctxbase + i + 2, 1 );
        x264_cabac_encode_decision( cb, ctxbase + i_abs + 2, 0 );
        x264_cabac_encode_bypass( cb, mvd >> 31 );
    }
    else
    {
        x264_cabac_encode_decision( cb, ctxbase + 3, 1 );
        x264_cabac_encode_decision( cb, ctxbase + 4, 1 );
        x264_cabac_encode_decision( cb, ctxbase + 5, 1 );
        if( i_abs < 9 )
        {
            cb->f8_bits_encoded += x264_cabac_size_unary[i_abs - 3][cb->state[ctxbase+6]];
            cb->state[ctxbase+6] = x264_cabac_transition_unary[i_abs - 3][cb->state[ctxbase+6]];
        }
        else
        {
            cb->f8_bits_encoded += cabac_size_5ones[cb->state[ctxbase+6]];
            cb->state[ctxbase+6] = cabac_transition_5ones[cb->state[ctxbase+6]];
            x264_cabac_encode_ue_bypass( cb, 3, i_abs - 9 );
        }
    }
#else
    static const uint8_t ctxes[8] = { 3,4,5,6,6,6,6,6 };

    if( i_abs < 9 )
    {
        for( int i = 1; i < i_abs; i++ )
            x264_cabac_encode_decision( cb, ctxbase + ctxes[i-1], 1 );
        x264_cabac_encode_decision( cb, ctxbase + ctxes[i_abs-1], 0 );
    }
    else
    {
        for( int i = 1; i < 9; i++ )
            x264_cabac_encode_decision( cb, ctxbase + ctxes[i-1], 1 );
        x264_cabac_encode_ue_bypass( cb, 3, i_abs - 9 );
    }
    x264_cabac_encode_bypass( cb, mvd >> 31 );
#endif
    /* Since we don't need to keep track of MVDs larger than 66, just cap the value.
     * This lets us store MVDs as 8-bit values instead of 16-bit. */
    return X264_MIN( i_abs, 66 );
}

static NOINLINE uint16_t cabac_mvd( x264_t *h, x264_cabac_t *cb, int i_list, int idx, int width )
{
    ALIGNED_4( int16_t mvp[2] );
    int mdx, mdy;

    /* Calculate mvd */
    x264_mb_predict_mv( h, i_list, idx, width, mvp );
    mdx = h->mb.cache.mv[i_list][x264_scan8[idx]][0] - mvp[0];
    mdy = h->mb.cache.mv[i_list][x264_scan8[idx]][1] - mvp[1];
    uint16_t amvd = x264_cabac_mvd_sum(h->mb.cache.mvd[i_list][x264_scan8[idx] - 1],
                                       h->mb.cache.mvd[i_list][x264_scan8[idx] - 8]);

    /* encode */
    mdx = cabac_mvd_cpn( h, cb, i_list, idx, 0, mdx, amvd&0xFF );
    mdy = cabac_mvd_cpn( h, cb, i_list, idx, 1, mdy, amvd>>8 );

    return pack8to16(mdx,mdy);
}

#define cabac_mvd(h,cb,i_list,idx,width,height)\
do\
{\
    uint16_t mvd = cabac_mvd(h,cb,i_list,idx,width);\
    x264_macroblock_cache_mvd( h, block_idx_x[idx], block_idx_y[idx], width, height, i_list, mvd );\
} while( 0 )

static inline void cabac_8x8_mvd( x264_t *h, x264_cabac_t *cb, int i )
{
    switch( h->mb.i_sub_partition[i] )
    {
        case D_L0_8x8:
            cabac_mvd( h, cb, 0, 4*i, 2, 2 );
            break;
        case D_L0_8x4:
            cabac_mvd( h, cb, 0, 4*i+0, 2, 1 );
            cabac_mvd( h, cb, 0, 4*i+2, 2, 1 );
            break;
        case D_L0_4x8:
            cabac_mvd( h, cb, 0, 4*i+0, 1, 2 );
            cabac_mvd( h, cb, 0, 4*i+1, 1, 2 );
            break;
        case D_L0_4x4:
            cabac_mvd( h, cb, 0, 4*i+0, 1, 1 );
            cabac_mvd( h, cb, 0, 4*i+1, 1, 1 );
            cabac_mvd( h, cb, 0, 4*i+2, 1, 1 );
            cabac_mvd( h, cb, 0, 4*i+3, 1, 1 );
            break;
        default:
            assert(0);
    }
}

static ALWAYS_INLINE void cabac_mb_header_i( x264_t *h, x264_cabac_t *cb, int i_mb_type, int slice_type, int chroma )
{
    if( slice_type == SLICE_TYPE_I )
    {
        int ctx = 0;
        if( (h->mb.i_neighbour & MB_LEFT) && h->mb.i_mb_type_left[0] != I_4x4 )
            ctx++;
        if( (h->mb.i_neighbour & MB_TOP) && h->mb.i_mb_type_top != I_4x4 )
            ctx++;

        cabac_mb_type_intra( h, cb, i_mb_type, 3+ctx, 3+3, 3+4, 3+5, 3+6, 3+7 );
    }
    else if( slice_type == SLICE_TYPE_P )
    {
        /* prefix */
        x264_cabac_encode_decision_noup( cb, 14, 1 );

        /* suffix */
        cabac_mb_type_intra( h, cb, i_mb_type, 17+0, 17+1, 17+2, 17+2, 17+3, 17+3 );
    }
    else if( slice_type == SLICE_TYPE_B )
    {
        /* prefix */
        x264_cabac_encode_decision_noup( cb, 27+3,   1 );
        x264_cabac_encode_decision_noup( cb, 27+4,   1 );
        x264_cabac_encode_decision( cb, 27+5,   1 );
        x264_cabac_encode_decision( cb, 27+5,   0 );
        x264_cabac_encode_decision( cb, 27+5,   1 );

        /* suffix */
        cabac_mb_type_intra( h, cb, i_mb_type, 32+0, 32+1, 32+2, 32+2, 32+3, 32+3 );
    }

    if( i_mb_type == I_PCM )
        return;

    if( i_mb_type != I_16x16 )
    {
        if( h->pps->b_transform_8x8_mode )
            cabac_transform_size( h, cb );

        int di = h->mb.b_transform_8x8 ? 4 : 1;
        for( int i = 0; i < 16; i += di )
        {
            const int i_pred = x264_mb_predict_intra4x4_mode( h, i );
            const int i_mode = x264_mb_pred_mode4x4_fix( h->mb.cache.intra4x4_pred_mode[x264_scan8[i]] );
            cabac_intra4x4_pred_mode( cb, i_pred, i_mode );
        }
    }

    if( chroma )
        cabac_intra_chroma_pred_mode( h, cb );
}

static ALWAYS_INLINE void cabac_mb_header_p( x264_t *h, x264_cabac_t *cb, int i_mb_type, int chroma )
{
    if( i_mb_type == P_L0 )
    {
        x264_cabac_encode_decision_noup( cb, 14, 0 );
        if( h->mb.i_partition == D_16x16 )
        {
            x264_cabac_encode_decision_noup( cb, 15, 0 );
            x264_cabac_encode_decision_noup( cb, 16, 0 );
            if( h->mb.pic.i_fref[0] > 1 )
                cabac_ref_p( h, cb, 0 );
            cabac_mvd( h, cb, 0, 0, 4, 4 );
        }
        else if( h->mb.i_partition == D_16x8 )
        {
            x264_cabac_encode_decision_noup( cb, 15, 1 );
            x264_cabac_encode_decision_noup( cb, 17, 1 );
            if( h->mb.pic.i_fref[0] > 1 )
            {
                cabac_ref_p( h, cb, 0 );
                cabac_ref_p( h, cb, 8 );
            }
            cabac_mvd( h, cb, 0, 0, 4, 2 );
            cabac_mvd( h, cb, 0, 8, 4, 2 );
        }
        else //if( h->mb.i_partition == D_8x16 )
        {
            x264_cabac_encode_decision_noup( cb, 15, 1 );
            x264_cabac_encode_decision_noup( cb, 17, 0 );
            if( h->mb.pic.i_fref[0] > 1 )
            {
                cabac_ref_p( h, cb, 0 );
                cabac_ref_p( h, cb, 4 );
            }
            cabac_mvd( h, cb, 0, 0, 2, 4 );
            cabac_mvd( h, cb, 0, 4, 2, 4 );
        }
    }
    else if( i_mb_type == P_8x8 )
    {
        x264_cabac_encode_decision_noup( cb, 14, 0 );
        x264_cabac_encode_decision_noup( cb, 15, 0 );
        x264_cabac_encode_decision_noup( cb, 16, 1 );

        /* sub mb type */
        for( int i = 0; i < 4; i++ )
            cabac_subpartition_p( cb, h->mb.i_sub_partition[i] );

        /* ref 0 */
        if( h->mb.pic.i_fref[0] > 1 )
        {
            cabac_ref_p( h, cb,  0 );
            cabac_ref_p( h, cb,  4 );
            cabac_ref_p( h, cb,  8 );
            cabac_ref_p( h, cb, 12 );
        }

        for( int i = 0; i < 4; i++ )
            cabac_8x8_mvd( h, cb, i );
    }
    else /* intra */
        cabac_mb_header_i( h, cb, i_mb_type, SLICE_TYPE_P, chroma );
}

static ALWAYS_INLINE void cabac_mb_header_b( x264_t *h, x264_cabac_t *cb, int i_mb_type, int chroma )
{
    int ctx = 0;
    if( (h->mb.i_neighbour & MB_LEFT) && h->mb.i_mb_type_left[0] != B_SKIP && h->mb.i_mb_type_left[0] != B_DIRECT )
        ctx++;
    if( (h->mb.i_neighbour & MB_TOP) && h->mb.i_mb_type_top != B_SKIP && h->mb.i_mb_type_top != B_DIRECT )
        ctx++;

    if( i_mb_type == B_DIRECT )
    {
        x264_cabac_encode_decision_noup( cb, 27+ctx, 0 );
        return;
    }
    x264_cabac_encode_decision_noup( cb, 27+ctx, 1 );

    if( i_mb_type == B_8x8 )
    {
        x264_cabac_encode_decision_noup( cb, 27+3,   1 );
        x264_cabac_encode_decision_noup( cb, 27+4,   1 );
        x264_cabac_encode_decision( cb, 27+5,   1 );
        x264_cabac_encode_decision( cb, 27+5,   1 );
        x264_cabac_encode_decision_noup( cb, 27+5,   1 );

        /* sub mb type */
        for( int i = 0; i < 4; i++ )
            cabac_subpartition_b( cb, h->mb.i_sub_partition[i] );

        /* ref */
        if( h->mb.pic.i_fref[0] > 1 )
            for( int i = 0; i < 4; i++ )
                if( x264_mb_partition_listX_table[0][ h->mb.i_sub_partition[i] ] )
                    cabac_ref_b( h, cb, 0, 4*i );

        if( h->mb.pic.i_fref[1] > 1 )
            for( int i = 0; i < 4; i++ )
                if( x264_mb_partition_listX_table[1][ h->mb.i_sub_partition[i] ] )
                    cabac_ref_b( h, cb, 1, 4*i );

        for( int i = 0; i < 4; i++ )
            if( x264_mb_partition_listX_table[0][ h->mb.i_sub_partition[i] ] )
                cabac_mvd( h, cb, 0, 4*i, 2, 2 );

        for( int i = 0; i < 4; i++ )
            if( x264_mb_partition_listX_table[1][ h->mb.i_sub_partition[i] ] )
                cabac_mvd( h, cb, 1, 4*i, 2, 2 );
    }
    else if( i_mb_type >= B_L0_L0 && i_mb_type <= B_BI_BI )
    {
        /* All B modes */
        static const uint8_t i_mb_bits[9*3] =
        {
            0x31, 0x29, 0x4, /* L0 L0 */
            0x35, 0x2d, 0,   /* L0 L1 */
            0x43, 0x63, 0,   /* L0 BI */
            0x3d, 0x2f, 0,   /* L1 L0 */
            0x39, 0x25, 0x6, /* L1 L1 */
            0x53, 0x73, 0,   /* L1 BI */
            0x4b, 0x6b, 0,   /* BI L0 */
            0x5b, 0x7b, 0,   /* BI L1 */
            0x47, 0x67, 0x21 /* BI BI */
        };

        const int idx = (i_mb_type - B_L0_L0) * 3 + (h->mb.i_partition - D_16x8);
        int bits = i_mb_bits[idx];

        x264_cabac_encode_decision_noup( cb, 27+3, bits&1 );
        x264_cabac_encode_decision( cb, 27+5-(bits&1), (bits>>1)&1 ); bits >>= 2;
        if( bits != 1 )
        {
            x264_cabac_encode_decision( cb, 27+5, bits&1 ); bits >>= 1;
            x264_cabac_encode_decision( cb, 27+5, bits&1 ); bits >>= 1;
            x264_cabac_encode_decision( cb, 27+5, bits&1 ); bits >>= 1;
            if( bits != 1 )
                x264_cabac_encode_decision_noup( cb, 27+5, bits&1 );
        }

        const uint8_t (*b_list)[2] = x264_mb_type_list_table[i_mb_type];
        if( h->mb.pic.i_fref[0] > 1 )
        {
            if( b_list[0][0] )
                cabac_ref_b( h, cb, 0, 0 );
            if( b_list[0][1] && h->mb.i_partition != D_16x16 )
                cabac_ref_b( h, cb, 0, 8 >> (h->mb.i_partition == D_8x16) );
        }
        if( h->mb.pic.i_fref[1] > 1 )
        {
            if( b_list[1][0] )
                cabac_ref_b( h, cb, 1, 0 );
            if( b_list[1][1] && h->mb.i_partition != D_16x16 )
                cabac_ref_b( h, cb, 1, 8 >> (h->mb.i_partition == D_8x16) );
        }
        for( int i_list = 0; i_list < 2; i_list++ )
        {
            if( h->mb.i_partition == D_16x16 )
            {
                if( b_list[i_list][0] ) cabac_mvd( h, cb, i_list, 0, 4, 4 );
            }
            else if( h->mb.i_partition == D_16x8 )
            {
                if( b_list[i_list][0] ) cabac_mvd( h, cb, i_list, 0, 4, 2 );
                if( b_list[i_list][1] ) cabac_mvd( h, cb, i_list, 8, 4, 2 );
            }
            else //if( h->mb.i_partition == D_8x16 )
            {
                if( b_list[i_list][0] ) cabac_mvd( h, cb, i_list, 0, 2, 4 );
                if( b_list[i_list][1] ) cabac_mvd( h, cb, i_list, 4, 2, 4 );
            }
        }
    }
    else /* intra */
        cabac_mb_header_i( h, cb, i_mb_type, SLICE_TYPE_B, chroma );
}

static ALWAYS_INLINE int cabac_cbf_ctxidxinc( x264_t *h, int i_cat, int i_idx, int b_intra, int b_dc )
{
    static const uint16_t base_ctx[14] = {85,89,93,97,101,1012,460,464,468,1016,472,476,480,1020};

    if( b_dc )
    {
        i_idx -= LUMA_DC;
        if( i_cat == DCT_CHROMA_DC )
        {
            int i_nza = h->mb.cache.i_cbp_left != -1 ? (h->mb.cache.i_cbp_left >> (8 + i_idx)) & 1 : b_intra;
            int i_nzb = h->mb.cache.i_cbp_top  != -1 ? (h->mb.cache.i_cbp_top  >> (8 + i_idx)) & 1 : b_intra;
            return base_ctx[i_cat] + 2*i_nzb + i_nza;
        }
        else
        {
            int i_nza = (h->mb.cache.i_cbp_left >> (8 + i_idx)) & 1;
            int i_nzb = (h->mb.cache.i_cbp_top  >> (8 + i_idx)) & 1;
            return base_ctx[i_cat] + 2*i_nzb + i_nza;
        }
    }
    else
    {
        int i_nza = h->mb.cache.non_zero_count[x264_scan8[i_idx] - 1];
        int i_nzb = h->mb.cache.non_zero_count[x264_scan8[i_idx] - 8];
        if( x264_constant_p(b_intra) && !b_intra )
            return base_ctx[i_cat] + ((2*i_nzb + i_nza)&0x7f);
        else
        {
            i_nza &= 0x7f + (b_intra << 7);
            i_nzb &= 0x7f + (b_intra << 7);
            return base_ctx[i_cat] + 2*!!i_nzb + !!i_nza;
        }
    }
}

// node ctx: 0..3: abslevel1 (with abslevelgt1 == 0).
//           4..7: abslevelgt1 + 3 (and abslevel1 doesn't matter).
/* map node ctx => cabac ctx for level=1 */
static const uint8_t coeff_abs_level1_ctx[8] = { 1, 2, 3, 4, 0, 0, 0, 0 };
/* map node ctx => cabac ctx for level>1 */
static const uint8_t coeff_abs_levelgt1_ctx[8] = { 5, 5, 5, 5, 6, 7, 8, 9 };
/* 4:2:2 chroma dc uses a slightly different state machine for some reason, also note that
 * 4:2:0 chroma dc doesn't use the last state so it has identical output with both arrays. */
static const uint8_t coeff_abs_levelgt1_ctx_chroma_dc[8] = { 5, 5, 5, 5, 6, 7, 8, 8 };

static const uint8_t coeff_abs_level_transition[2][8] = {
/* update node ctx after coding a level=1 */
    { 1, 2, 3, 3, 4, 5, 6, 7 },
/* update node ctx after coding a level>1 */
    { 4, 4, 4, 4, 5, 6, 7, 7 }
};

#if !RDO_SKIP_BS
static ALWAYS_INLINE void cabac_block_residual_internal( x264_t *h, x264_cabac_t *cb, int ctx_block_cat, dctcoef *l, int chroma422dc )
{
    int ctx_sig = x264_significant_coeff_flag_offset[MB_INTERLACED][ctx_block_cat];
    int ctx_last = x264_last_coeff_flag_offset[MB_INTERLACED][ctx_block_cat];
    int ctx_level = x264_coeff_abs_level_m1_offset[ctx_block_cat];
    int coeff_idx = -1, node_ctx = 0;
    int last = h->quantf.coeff_last[ctx_block_cat]( l );
    const uint8_t *levelgt1_ctx = chroma422dc ? coeff_abs_levelgt1_ctx_chroma_dc : coeff_abs_levelgt1_ctx;
    dctcoef coeffs[64];

#define WRITE_SIGMAP( sig_off, last_off )\
{\
    int i = 0;\
    while( 1 )\
    {\
        if( l[i] )\
        {\
            coeffs[++coeff_idx] = l[i];\
            x264_cabac_encode_decision( cb, ctx_sig + sig_off, 1 );\
            if( i == last )\
            {\
                x264_cabac_encode_decision( cb, ctx_last + last_off, 1 );\
                break;\
            }\
            else\
                x264_cabac_encode_decision( cb, ctx_last + last_off, 0 );\
        }\
        else\
            x264_cabac_encode_decision( cb, ctx_sig + sig_off, 0 );\
        if( ++i == count_m1 )\
        {\
            coeffs[++coeff_idx] = l[i];\
            break;\
        }\
    }\
}

    if( chroma422dc )
    {
        int count_m1 = 7;
        WRITE_SIGMAP( x264_coeff_flag_offset_chroma_422_dc[i], x264_coeff_flag_offset_chroma_422_dc[i] )
    }
    else
    {
        int count_m1 = x264_count_cat_m1[ctx_block_cat];
        if( count_m1 == 63 )
        {
            const uint8_t *sig_offset = x264_significant_coeff_flag_offset_8x8[MB_INTERLACED];
            WRITE_SIGMAP( sig_offset[i], x264_last_coeff_flag_offset_8x8[i] )
        }
        else
            WRITE_SIGMAP( i, i )
    }

    do
    {
        /* write coeff_abs - 1 */
        int coeff = coeffs[coeff_idx];
        int abs_coeff = abs(coeff);
        int coeff_sign = coeff >> 31;
        int ctx = coeff_abs_level1_ctx[node_ctx] + ctx_level;

        if( abs_coeff > 1 )
        {
            x264_cabac_encode_decision( cb, ctx, 1 );
            ctx = levelgt1_ctx[node_ctx] + ctx_level;
            for( int i = X264_MIN( abs_coeff, 15 ) - 2; i > 0; i-- )
                x264_cabac_encode_decision( cb, ctx, 1 );
            if( abs_coeff < 15 )
                x264_cabac_encode_decision( cb, ctx, 0 );
            else
                x264_cabac_encode_ue_bypass( cb, 0, abs_coeff - 15 );

            node_ctx = coeff_abs_level_transition[1][node_ctx];
        }
        else
        {
            x264_cabac_encode_decision( cb, ctx, 0 );
            node_ctx = coeff_abs_level_transition[0][node_ctx];
        }

        x264_cabac_encode_bypass( cb, coeff_sign );
    } while( --coeff_idx >= 0 );
}

void x264_cabac_block_residual_c( x264_t *h, x264_cabac_t *cb, int ctx_block_cat, dctcoef *l )
{
    cabac_block_residual_internal( h, cb, ctx_block_cat, l, 0 );
}

static ALWAYS_INLINE void cabac_block_residual( x264_t *h, x264_cabac_t *cb, int ctx_block_cat, dctcoef *l )
{
#if ARCH_X86_64 && HAVE_MMX
    h->bsf.cabac_block_residual_internal( l, MB_INTERLACED, ctx_block_cat, cb );
#else
    x264_cabac_block_residual_c( h, cb, ctx_block_cat, l );
#endif
}
static void cabac_block_residual_422_dc( x264_t *h, x264_cabac_t *cb, int ctx_block_cat, dctcoef *l )
{
    /* Template a version specifically for chroma 4:2:2 DC in order to avoid
     * slowing down everything else due to the added complexity. */
    cabac_block_residual_internal( h, cb, DCT_CHROMA_DC, l, 1 );
}
#define cabac_block_residual_8x8( h, cb, cat, l ) cabac_block_residual( h, cb, cat, l )
#else

/* Faster RDO by merging sigmap and level coding. Note that for 8x8dct and chroma 4:2:2 dc this is
 * slightly incorrect because the sigmap is not reversible (contexts are repeated). However, there
 * is nearly no quality penalty for this (~0.001db) and the speed boost (~30%) is worth it. */
static ALWAYS_INLINE void cabac_block_residual_internal( x264_t *h, x264_cabac_t *cb, int ctx_block_cat, dctcoef *l, int b_8x8, int chroma422dc )
{
    const uint8_t *sig_offset = x264_significant_coeff_flag_offset_8x8[MB_INTERLACED];
    int ctx_sig = x264_significant_coeff_flag_offset[MB_INTERLACED][ctx_block_cat];
    int ctx_last = x264_last_coeff_flag_offset[MB_INTERLACED][ctx_block_cat];
    int ctx_level = x264_coeff_abs_level_m1_offset[ctx_block_cat];
    int last = h->quantf.coeff_last[ctx_block_cat]( l );
    int coeff_abs = abs(l[last]);
    int ctx = coeff_abs_level1_ctx[0] + ctx_level;
    int node_ctx;
    const uint8_t *levelgt1_ctx = chroma422dc ? coeff_abs_levelgt1_ctx_chroma_dc : coeff_abs_levelgt1_ctx;

    if( last != (b_8x8 ? 63 : chroma422dc ? 7 : x264_count_cat_m1[ctx_block_cat]) )
    {
        x264_cabac_encode_decision( cb, ctx_sig + (b_8x8 ? sig_offset[last] :
                                    chroma422dc ? x264_coeff_flag_offset_chroma_422_dc[last] : last), 1 );
        x264_cabac_encode_decision( cb, ctx_last + (b_8x8 ? x264_last_coeff_flag_offset_8x8[last] :
                                    chroma422dc ? x264_coeff_flag_offset_chroma_422_dc[last] : last), 1 );
    }

    if( coeff_abs > 1 )
    {
        x264_cabac_encode_decision( cb, ctx, 1 );
        ctx = levelgt1_ctx[0] + ctx_level;
        if( coeff_abs < 15 )
        {
            cb->f8_bits_encoded += x264_cabac_size_unary[coeff_abs-1][cb->state[ctx]];
            cb->state[ctx] = x264_cabac_transition_unary[coeff_abs-1][cb->state[ctx]];
        }
        else
        {
            cb->f8_bits_encoded += x264_cabac_size_unary[14][cb->state[ctx]];
            cb->state[ctx] = x264_cabac_transition_unary[14][cb->state[ctx]];
            x264_cabac_encode_ue_bypass( cb, 0, coeff_abs - 15 );
        }
        node_ctx = coeff_abs_level_transition[1][0];
    }
    else
    {
        x264_cabac_encode_decision( cb, ctx, 0 );
        node_ctx = coeff_abs_level_transition[0][0];
        x264_cabac_encode_bypass( cb, 0 ); // sign
    }

    for( int i = last-1; i >= 0; i-- )
    {
        if( l[i] )
        {
            coeff_abs = abs(l[i]);
            x264_cabac_encode_decision( cb, ctx_sig + (b_8x8 ? sig_offset[i] :
                                        chroma422dc ? x264_coeff_flag_offset_chroma_422_dc[i] : i), 1 );
            x264_cabac_encode_decision( cb, ctx_last + (b_8x8 ? x264_last_coeff_flag_offset_8x8[i] :
                                        chroma422dc ? x264_coeff_flag_offset_chroma_422_dc[i] : i), 0 );
            ctx = coeff_abs_level1_ctx[node_ctx] + ctx_level;

            if( coeff_abs > 1 )
            {
                x264_cabac_encode_decision( cb, ctx, 1 );
                ctx = levelgt1_ctx[node_ctx] + ctx_level;
                if( coeff_abs < 15 )
                {
                    cb->f8_bits_encoded += x264_cabac_size_unary[coeff_abs-1][cb->state[ctx]];
                    cb->state[ctx] = x264_cabac_transition_unary[coeff_abs-1][cb->state[ctx]];
                }
                else
                {
                    cb->f8_bits_encoded += x264_cabac_size_unary[14][cb->state[ctx]];
                    cb->state[ctx] = x264_cabac_transition_unary[14][cb->state[ctx]];
                    x264_cabac_encode_ue_bypass( cb, 0, coeff_abs - 15 );
                }
                node_ctx = coeff_abs_level_transition[1][node_ctx];
            }
            else
            {
                x264_cabac_encode_decision( cb, ctx, 0 );
                node_ctx = coeff_abs_level_transition[0][node_ctx];
                x264_cabac_encode_bypass( cb, 0 );
            }
        }
        else
            x264_cabac_encode_decision( cb, ctx_sig + (b_8x8 ? sig_offset[i] :
                                        chroma422dc ? x264_coeff_flag_offset_chroma_422_dc[i] : i), 0 );
    }
}

void x264_cabac_block_residual_8x8_rd_c( x264_t *h, x264_cabac_t *cb, int ctx_block_cat, dctcoef *l )
{
    cabac_block_residual_internal( h, cb, ctx_block_cat, l, 1, 0 );
}
void x264_cabac_block_residual_rd_c( x264_t *h, x264_cabac_t *cb, int ctx_block_cat, dctcoef *l )
{
    cabac_block_residual_internal( h, cb, ctx_block_cat, l, 0, 0 );
}

static ALWAYS_INLINE void cabac_block_residual_8x8( x264_t *h, x264_cabac_t *cb, int ctx_block_cat, dctcoef *l )
{
#if ARCH_X86_64 && HAVE_MMX
    h->bsf.cabac_block_residual_8x8_rd_internal( l, MB_INTERLACED, ctx_block_cat, cb );
#else
    x264_cabac_block_residual_8x8_rd_c( h, cb, ctx_block_cat, l );
#endif
}
static ALWAYS_INLINE void cabac_block_residual( x264_t *h, x264_cabac_t *cb, int ctx_block_cat, dctcoef *l )
{
#if ARCH_X86_64 && HAVE_MMX
    h->bsf.cabac_block_residual_rd_internal( l, MB_INTERLACED, ctx_block_cat, cb );
#else
    x264_cabac_block_residual_rd_c( h, cb, ctx_block_cat, l );
#endif
}

static void cabac_block_residual_422_dc( x264_t *h, x264_cabac_t *cb, int ctx_block_cat, dctcoef *l )
{
    cabac_block_residual_internal( h, cb, DCT_CHROMA_DC, l, 0, 1 );
}
#endif

#define cabac_block_residual_cbf_internal( h, cb, ctx_block_cat, i_idx, l, b_intra, b_dc, name )\
do\
{\
    int ctxidxinc = cabac_cbf_ctxidxinc( h, ctx_block_cat, i_idx, b_intra, b_dc );\
    if( h->mb.cache.non_zero_count[x264_scan8[i_idx]] )\
    {\
        x264_cabac_encode_decision( cb, ctxidxinc, 1 );\
        cabac_block_residual##name( h, cb, ctx_block_cat, l );\
    }\
    else\
        x264_cabac_encode_decision( cb, ctxidxinc, 0 );\
} while( 0 )

#define cabac_block_residual_dc_cbf( h, cb, ctx_block_cat, i_idx, l, b_intra )\
    cabac_block_residual_cbf_internal( h, cb, ctx_block_cat, i_idx, l, b_intra, 1, )

#define cabac_block_residual_cbf( h, cb, ctx_block_cat, i_idx, l, b_intra )\
    cabac_block_residual_cbf_internal( h, cb, ctx_block_cat, i_idx, l, b_intra, 0, )

#define cabac_block_residual_8x8_cbf( h, cb, ctx_block_cat, i_idx, l, b_intra )\
    cabac_block_residual_cbf_internal( h, cb, ctx_block_cat, i_idx, l, b_intra, 0, _8x8 )

#define cabac_block_residual_422_dc_cbf( h, cb, ch, b_intra )\
    cabac_block_residual_cbf_internal( h, cb, DCT_CHROMA_DC, CHROMA_DC+(ch), h->dct.chroma_dc[ch], b_intra, 1, _422_dc )

static ALWAYS_INLINE void macroblock_write_cabac_internal( x264_t *h, x264_cabac_t *cb, int plane_count, int chroma )
{
    const int i_mb_type = h->mb.i_type;

#if !RDO_SKIP_BS
    const int i_mb_pos_start = x264_cabac_pos( cb );
    int       i_mb_pos_tex;

    if( SLICE_MBAFF &&
        (!(h->mb.i_mb_y & 1) || IS_SKIP(h->mb.type[h->mb.i_mb_xy - h->mb.i_mb_stride])) )
    {
        cabac_field_decoding_flag( h, cb );
    }
#endif

    if( h->sh.i_type == SLICE_TYPE_P )
        cabac_mb_header_p( h, cb, i_mb_type, chroma );
    else if( h->sh.i_type == SLICE_TYPE_B )
        cabac_mb_header_b( h, cb, i_mb_type, chroma );
    else //if( h->sh.i_type == SLICE_TYPE_I )
        cabac_mb_header_i( h, cb, i_mb_type, SLICE_TYPE_I, chroma );

#if !RDO_SKIP_BS
    i_mb_pos_tex = x264_cabac_pos( cb );
    h->stat.frame.i_mv_bits += i_mb_pos_tex - i_mb_pos_start;

    if( i_mb_type == I_PCM )
    {
        bs_t s;
        bs_init( &s, cb->p, cb->p_end - cb->p );

        for( int p = 0; p < plane_count; p++ )
            for( int i = 0; i < 256; i++ )
                bs_write( &s, BIT_DEPTH, h->mb.pic.p_fenc[p][i] );
        if( chroma )
            for( int ch = 1; ch < 3; ch++ )
                for( int i = 0; i < 16>>CHROMA_V_SHIFT; i++ )
                    for( int j = 0; j < 8; j++ )
                        bs_write( &s, BIT_DEPTH, h->mb.pic.p_fenc[ch][i*FENC_STRIDE+j] );

        bs_flush( &s );
        cb->p = s.p;
        x264_cabac_encode_init_core( cb );

        h->stat.frame.i_tex_bits += x264_cabac_pos( cb ) - i_mb_pos_tex;
        return;
    }
#endif

    if( i_mb_type != I_16x16 )
    {
        cabac_cbp_luma( h, cb );
        if( chroma )
            cabac_cbp_chroma( h, cb );
    }

    if( x264_mb_transform_8x8_allowed( h ) && h->mb.i_cbp_luma )
    {
        cabac_transform_size( h, cb );
    }

    if( h->mb.i_cbp_luma || (chroma && h->mb.i_cbp_chroma) || i_mb_type == I_16x16 )
    {
        const int b_intra = IS_INTRA( i_mb_type );
        cabac_qp_delta( h, cb );

        /* write residual */
        if( i_mb_type == I_16x16 )
        {
            /* DC Luma */
            for( int p = 0; p < plane_count; p++ )
            {
                cabac_block_residual_dc_cbf( h, cb, ctx_cat_plane[DCT_LUMA_DC][p], LUMA_DC+p, h->dct.luma16x16_dc[p], 1 );

                /* AC Luma */
                if( h->mb.i_cbp_luma )
                    for( int i = p*16; i < p*16+16; i++ )
                        cabac_block_residual_cbf( h, cb, ctx_cat_plane[DCT_LUMA_AC][p], i, h->dct.luma4x4[i]+1, 1 );
            }
        }
        else if( h->mb.b_transform_8x8 )
        {
            if( plane_count == 3 )
            {
                ALIGNED_4( uint8_t nnzbak[3][8] );

/* Stupid nnz munging in the case that neighbors don't have
 * 8x8 transform enabled. */
#define BACKUP( dst, src, res )\
    dst = src;\
    src = res;

#define RESTORE( dst, src, res )\
    src = dst;

#define MUNGE_8x8_NNZ( MUNGE )\
if( (h->mb.i_neighbour & MB_LEFT) && !h->mb.mb_transform_size[h->mb.i_mb_left_xy[0]] && !(h->mb.cbp[h->mb.i_mb_left_xy[0]] & 0x1000) )\
{\
    MUNGE( nnzbak[0][0], h->mb.cache.non_zero_count[x264_scan8[16*0+ 0] - 1], 0x00 )\
    MUNGE( nnzbak[0][1], h->mb.cache.non_zero_count[x264_scan8[16*0+ 2] - 1], 0x00 )\
    MUNGE( nnzbak[1][0], h->mb.cache.non_zero_count[x264_scan8[16*1+ 0] - 1], 0x00 )\
    MUNGE( nnzbak[1][1], h->mb.cache.non_zero_count[x264_scan8[16*1+ 2] - 1], 0x00 )\
    MUNGE( nnzbak[2][0], h->mb.cache.non_zero_count[x264_scan8[16*2+ 0] - 1], 0x00 )\
    MUNGE( nnzbak[2][1], h->mb.cache.non_zero_count[x264_scan8[16*2+ 2] - 1], 0x00 )\
}\
if( (h->mb.i_neighbour & MB_LEFT) && !h->mb.mb_transform_size[h->mb.i_mb_left_xy[1]] && !(h->mb.cbp[h->mb.i_mb_left_xy[1]] & 0x1000) )\
{\
    MUNGE( nnzbak[0][2], h->mb.cache.non_zero_count[x264_scan8[16*0+ 8] - 1], 0x00 )\
    MUNGE( nnzbak[0][3], h->mb.cache.non_zero_count[x264_scan8[16*0+10] - 1], 0x00 )\
    MUNGE( nnzbak[1][2], h->mb.cache.non_zero_count[x264_scan8[16*1+ 8] - 1], 0x00 )\
    MUNGE( nnzbak[1][3], h->mb.cache.non_zero_count[x264_scan8[16*1+10] - 1], 0x00 )\
    MUNGE( nnzbak[2][2], h->mb.cache.non_zero_count[x264_scan8[16*2+ 8] - 1], 0x00 )\
    MUNGE( nnzbak[2][3], h->mb.cache.non_zero_count[x264_scan8[16*2+10] - 1], 0x00 )\
}\
if( (h->mb.i_neighbour & MB_TOP) && !h->mb.mb_transform_size[h->mb.i_mb_top_xy] && !(h->mb.cbp[h->mb.i_mb_top_xy] & 0x1000) )\
{\
    MUNGE( M32( &nnzbak[0][4] ), M32( &h->mb.cache.non_zero_count[x264_scan8[16*0] - 8] ), 0x00000000U )\
    MUNGE( M32( &nnzbak[1][4] ), M32( &h->mb.cache.non_zero_count[x264_scan8[16*1] - 8] ), 0x00000000U )\
    MUNGE( M32( &nnzbak[2][4] ), M32( &h->mb.cache.non_zero_count[x264_scan8[16*2] - 8] ), 0x00000000U )\
}

                MUNGE_8x8_NNZ( BACKUP )

                for( int p = 0; p < 3; p++ )
                    FOREACH_BIT( i, 0, h->mb.i_cbp_luma )
                        cabac_block_residual_8x8_cbf( h, cb, ctx_cat_plane[DCT_LUMA_8x8][p], i*4+p*16, h->dct.luma8x8[i+p*4], b_intra );

                MUNGE_8x8_NNZ( RESTORE )
            }
            else
            {
                FOREACH_BIT( i, 0, h->mb.i_cbp_luma )
                    cabac_block_residual_8x8( h, cb, DCT_LUMA_8x8, h->dct.luma8x8[i] );
            }
        }
        else
        {
            for( int p = 0; p < plane_count; p++ )
                FOREACH_BIT( i8x8, 0, h->mb.i_cbp_luma )
                    for( int i = 0; i < 4; i++ )
                        cabac_block_residual_cbf( h, cb, ctx_cat_plane[DCT_LUMA_4x4][p], i+i8x8*4+p*16, h->dct.luma4x4[i+i8x8*4+p*16], b_intra );
        }

        if( chroma && h->mb.i_cbp_chroma ) /* Chroma DC residual present */
        {
            if( CHROMA_FORMAT == CHROMA_422 )
            {
                cabac_block_residual_422_dc_cbf( h, cb, 0, b_intra );
                cabac_block_residual_422_dc_cbf( h, cb, 1, b_intra );
            }
            else
            {
                cabac_block_residual_dc_cbf( h, cb, DCT_CHROMA_DC, CHROMA_DC+0, h->dct.chroma_dc[0], b_intra );
                cabac_block_residual_dc_cbf( h, cb, DCT_CHROMA_DC, CHROMA_DC+1, h->dct.chroma_dc[1], b_intra );
            }

            if( h->mb.i_cbp_chroma == 2 ) /* Chroma AC residual present */
            {
                int step = 8 << CHROMA_V_SHIFT;
                for( int i = 16; i < 3*16; i += step )
                    for( int j = i; j < i+4; j++ )
                        cabac_block_residual_cbf( h, cb, DCT_CHROMA_AC, j, h->dct.luma4x4[j]+1, b_intra );
            }
        }
    }

#if !RDO_SKIP_BS
    h->stat.frame.i_tex_bits += x264_cabac_pos( cb ) - i_mb_pos_tex;
#endif
}

void x264_macroblock_write_cabac( x264_t *h, x264_cabac_t *cb )
{
    if( CHROMA444 )
        macroblock_write_cabac_internal( h, cb, 3, 0 );
    else if( CHROMA_FORMAT )
        macroblock_write_cabac_internal( h, cb, 1, 1 );
    else
        macroblock_write_cabac_internal( h, cb, 1, 0 );
}

#if RDO_SKIP_BS
/*****************************************************************************
 * RD only; doesn't generate a valid bitstream
 * doesn't write cbp or chroma dc (I don't know how much this matters)
 * doesn't write ref (never varies between calls, so no point in doing so)
 * only writes subpartition for p8x8, needed for sub-8x8 mode decision RDO
 * works on all partition sizes except 16x16
 *****************************************************************************/
static void partition_size_cabac( x264_t *h, x264_cabac_t *cb, int i8, int i_pixel )
{
    const int i_mb_type = h->mb.i_type;
    int b_8x16 = h->mb.i_partition == D_8x16;
    int plane_count = CHROMA444 ? 3 : 1;

    if( i_mb_type == P_8x8 )
    {
        cabac_8x8_mvd( h, cb, i8 );
        cabac_subpartition_p( cb, h->mb.i_sub_partition[i8] );
    }
    else if( i_mb_type == P_L0 )
        cabac_mvd( h, cb, 0, 4*i8, 4>>b_8x16, 2<<b_8x16 );
    else if( i_mb_type > B_DIRECT && i_mb_type < B_8x8 )
    {
        if( x264_mb_type_list_table[ i_mb_type ][0][!!i8] ) cabac_mvd( h, cb, 0, 4*i8, 4>>b_8x16, 2<<b_8x16 );
        if( x264_mb_type_list_table[ i_mb_type ][1][!!i8] ) cabac_mvd( h, cb, 1, 4*i8, 4>>b_8x16, 2<<b_8x16 );
    }
    else //if( i_mb_type == B_8x8 )
    {
        if( x264_mb_partition_listX_table[0][ h->mb.i_sub_partition[i8] ] )
            cabac_mvd( h, cb, 0, 4*i8, 2, 2 );
        if( x264_mb_partition_listX_table[1][ h->mb.i_sub_partition[i8] ] )
            cabac_mvd( h, cb, 1, 4*i8, 2, 2 );
    }

    for( int j = (i_pixel < PIXEL_8x8); j >= 0; j-- )
    {
        if( h->mb.i_cbp_luma & (1 << i8) )
        {
            if( h->mb.b_transform_8x8 )
            {
                if( CHROMA444 )
                    for( int p = 0; p < 3; p++ )
                        cabac_block_residual_8x8_cbf( h, cb, ctx_cat_plane[DCT_LUMA_8x8][p], i8*4+p*16, h->dct.luma8x8[i8+p*4], 0 );
                else
                    cabac_block_residual_8x8( h, cb, DCT_LUMA_8x8, h->dct.luma8x8[i8] );
            }
            else
                for( int p = 0; p < plane_count; p++ )
                    for( int i4 = 0; i4 < 4; i4++ )
                        cabac_block_residual_cbf( h, cb, ctx_cat_plane[DCT_LUMA_4x4][p], i4+i8*4+p*16, h->dct.luma4x4[i4+i8*4+p*16], 0 );
        }

        if( h->mb.i_cbp_chroma )
        {
            if( CHROMA_FORMAT == CHROMA_422 )
            {
                int offset = (5*i8) & 0x09;
                cabac_block_residual_cbf( h, cb, DCT_CHROMA_AC, 16+offset, h->dct.luma4x4[16+offset]+1, 0 );
                cabac_block_residual_cbf( h, cb, DCT_CHROMA_AC, 18+offset, h->dct.luma4x4[18+offset]+1, 0 );
                cabac_block_residual_cbf( h, cb, DCT_CHROMA_AC, 32+offset, h->dct.luma4x4[32+offset]+1, 0 );
                cabac_block_residual_cbf( h, cb, DCT_CHROMA_AC, 34+offset, h->dct.luma4x4[34+offset]+1, 0 );
            }
            else
            {
                cabac_block_residual_cbf( h, cb, DCT_CHROMA_AC, 16+i8, h->dct.luma4x4[16+i8]+1, 0 );
                cabac_block_residual_cbf( h, cb, DCT_CHROMA_AC, 32+i8, h->dct.luma4x4[32+i8]+1, 0 );
            }
        }

        i8 += x264_pixel_size[i_pixel].h >> 3;
    }
}

static void subpartition_size_cabac( x264_t *h, x264_cabac_t *cb, int i4, int i_pixel )
{
    int b_8x4 = i_pixel == PIXEL_8x4;
    int plane_count = CHROMA444 ? 3 : 1;
    if( i_pixel == PIXEL_4x4 )
        cabac_mvd( h, cb, 0, i4, 1, 1 );
    else
        cabac_mvd( h, cb, 0, i4, 1+b_8x4, 2-b_8x4 );
    for( int p = 0; p < plane_count; p++ )
    {
        cabac_block_residual_cbf( h, cb, ctx_cat_plane[DCT_LUMA_4x4][p], p*16+i4, h->dct.luma4x4[p*16+i4], 0 );
        if( i_pixel != PIXEL_4x4 )
            cabac_block_residual_cbf( h, cb, ctx_cat_plane[DCT_LUMA_4x4][p], p*16+i4+2-b_8x4, h->dct.luma4x4[p*16+i4+2-b_8x4], 0 );
    }
}

static void partition_i8x8_size_cabac( x264_t *h, x264_cabac_t *cb, int i8, int i_mode )
{
    const int i_pred = x264_mb_predict_intra4x4_mode( h, 4*i8 );
    i_mode = x264_mb_pred_mode4x4_fix( i_mode );
    cabac_intra4x4_pred_mode( cb, i_pred, i_mode );
    cabac_cbp_luma( h, cb );
    if( h->mb.i_cbp_luma & (1 << i8) )
    {
        if( CHROMA444 )
            for( int p = 0; p < 3; p++ )
                cabac_block_residual_8x8_cbf( h, cb, ctx_cat_plane[DCT_LUMA_8x8][p], i8*4+p*16, h->dct.luma8x8[i8+p*4], 1 );
        else
            cabac_block_residual_8x8( h, cb, DCT_LUMA_8x8, h->dct.luma8x8[i8] );
    }
}

static void partition_i4x4_size_cabac( x264_t *h, x264_cabac_t *cb, int i4, int i_mode )
{
    const int i_pred = x264_mb_predict_intra4x4_mode( h, i4 );
    int plane_count = CHROMA444 ? 3 : 1;
    i_mode = x264_mb_pred_mode4x4_fix( i_mode );
    cabac_intra4x4_pred_mode( cb, i_pred, i_mode );
    for( int p = 0; p < plane_count; p++ )
        cabac_block_residual_cbf( h, cb, ctx_cat_plane[DCT_LUMA_4x4][p], i4+p*16, h->dct.luma4x4[i4+p*16], 1 );
}

static void chroma_size_cabac( x264_t *h, x264_cabac_t *cb )
{
    cabac_intra_chroma_pred_mode( h, cb );
    cabac_cbp_chroma( h, cb );
    if( h->mb.i_cbp_chroma )
    {
        if( CHROMA_FORMAT == CHROMA_422 )
        {
            cabac_block_residual_422_dc_cbf( h, cb, 0, 1 );
            cabac_block_residual_422_dc_cbf( h, cb, 1, 1 );
        }
        else
        {
            cabac_block_residual_dc_cbf( h, cb, DCT_CHROMA_DC, CHROMA_DC+0, h->dct.chroma_dc[0], 1 );
            cabac_block_residual_dc_cbf( h, cb, DCT_CHROMA_DC, CHROMA_DC+1, h->dct.chroma_dc[1], 1 );
        }

        if( h->mb.i_cbp_chroma == 2 )
        {
            int step = 8 << CHROMA_V_SHIFT;
            for( int i = 16; i < 3*16; i += step )
                for( int j = i; j < i+4; j++ )
                    cabac_block_residual_cbf( h, cb, DCT_CHROMA_AC, j, h->dct.luma4x4[j]+1, 1 );
        }
    }
}
#endif
