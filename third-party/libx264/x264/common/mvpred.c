/*****************************************************************************
 * mvpred.c: motion vector prediction
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

#include "common.h"

void x264_mb_predict_mv( x264_t *h, int i_list, int idx, int i_width, int16_t mvp[2] )
{
    const int i8 = x264_scan8[idx];
    const int i_ref= h->mb.cache.ref[i_list][i8];
    int     i_refa = h->mb.cache.ref[i_list][i8 - 1];
    int16_t *mv_a  = h->mb.cache.mv[i_list][i8 - 1];
    int     i_refb = h->mb.cache.ref[i_list][i8 - 8];
    int16_t *mv_b  = h->mb.cache.mv[i_list][i8 - 8];
    int     i_refc = h->mb.cache.ref[i_list][i8 - 8 + i_width];
    int16_t *mv_c  = h->mb.cache.mv[i_list][i8 - 8 + i_width];

    // Partitions not yet reached in scan order are unavailable.
    if( (idx&3) >= 2 + (i_width&1) || i_refc == -2 )
    {
        i_refc = h->mb.cache.ref[i_list][i8 - 8 - 1];
        mv_c   = h->mb.cache.mv[i_list][i8 - 8 - 1];

        if( SLICE_MBAFF
            && h->mb.cache.ref[i_list][x264_scan8[0]-1] != -2
            && MB_INTERLACED != h->mb.field[h->mb.i_mb_left_xy[0]] )
        {
            if( idx == 2 )
            {
                mv_c = h->mb.cache.topright_mv[i_list][0];
                i_refc = h->mb.cache.topright_ref[i_list][0];
            }
            else if( idx == 8 )
            {
                mv_c = h->mb.cache.topright_mv[i_list][1];
                i_refc = h->mb.cache.topright_ref[i_list][1];
            }
            else if( idx == 10 )
            {
                mv_c = h->mb.cache.topright_mv[i_list][2];
                i_refc = h->mb.cache.topright_ref[i_list][2];
            }
        }
    }
    if( h->mb.i_partition == D_16x8 )
    {
        if( idx == 0 )
        {
            if( i_refb == i_ref )
            {
                CP32( mvp, mv_b );
                return;
            }
        }
        else
        {
            if( i_refa == i_ref )
            {
                CP32( mvp, mv_a );
                return;
            }
        }
    }
    else if( h->mb.i_partition == D_8x16 )
    {
        if( idx == 0 )
        {
            if( i_refa == i_ref )
            {
                CP32( mvp, mv_a );
                return;
            }
        }
        else
        {
            if( i_refc == i_ref )
            {
                CP32( mvp, mv_c );
                return;
            }
        }
    }

    int i_count = (i_refa == i_ref) + (i_refb == i_ref) + (i_refc == i_ref);

    if( i_count > 1 )
    {
median:
        x264_median_mv( mvp, mv_a, mv_b, mv_c );
    }
    else if( i_count == 1 )
    {
        if( i_refa == i_ref )
            CP32( mvp, mv_a );
        else if( i_refb == i_ref )
            CP32( mvp, mv_b );
        else
            CP32( mvp, mv_c );
    }
    else if( i_refb == -2 && i_refc == -2 && i_refa != -2 )
        CP32( mvp, mv_a );
    else
        goto median;
}

void x264_mb_predict_mv_16x16( x264_t *h, int i_list, int i_ref, int16_t mvp[2] )
{
    int     i_refa = h->mb.cache.ref[i_list][X264_SCAN8_0 - 1];
    int16_t *mv_a  = h->mb.cache.mv[i_list][X264_SCAN8_0 - 1];
    int     i_refb = h->mb.cache.ref[i_list][X264_SCAN8_0 - 8];
    int16_t *mv_b  = h->mb.cache.mv[i_list][X264_SCAN8_0 - 8];
    int     i_refc = h->mb.cache.ref[i_list][X264_SCAN8_0 - 8 + 4];
    int16_t *mv_c  = h->mb.cache.mv[i_list][X264_SCAN8_0 - 8 + 4];
    if( i_refc == -2 )
    {
        i_refc = h->mb.cache.ref[i_list][X264_SCAN8_0 - 8 - 1];
        mv_c   = h->mb.cache.mv[i_list][X264_SCAN8_0 - 8 - 1];
    }

    int i_count = (i_refa == i_ref) + (i_refb == i_ref) + (i_refc == i_ref);

    if( i_count > 1 )
    {
median:
        x264_median_mv( mvp, mv_a, mv_b, mv_c );
    }
    else if( i_count == 1 )
    {
        if( i_refa == i_ref )
            CP32( mvp, mv_a );
        else if( i_refb == i_ref )
            CP32( mvp, mv_b );
        else
            CP32( mvp, mv_c );
    }
    else if( i_refb == -2 && i_refc == -2 && i_refa != -2 )
        CP32( mvp, mv_a );
    else
        goto median;
}


void x264_mb_predict_mv_pskip( x264_t *h, int16_t mv[2] )
{
    int     i_refa = h->mb.cache.ref[0][X264_SCAN8_0 - 1];
    int     i_refb = h->mb.cache.ref[0][X264_SCAN8_0 - 8];
    int16_t *mv_a  = h->mb.cache.mv[0][X264_SCAN8_0 - 1];
    int16_t *mv_b  = h->mb.cache.mv[0][X264_SCAN8_0 - 8];

    if( i_refa == -2 || i_refb == -2 ||
        !( (uint32_t)i_refa | M32( mv_a ) ) ||
        !( (uint32_t)i_refb | M32( mv_b ) ) )
    {
        M32( mv ) = 0;
    }
    else
        x264_mb_predict_mv_16x16( h, 0, 0, mv );
}

static int mb_predict_mv_direct16x16_temporal( x264_t *h )
{
    int mb_x = h->mb.i_mb_x;
    int mb_y = h->mb.i_mb_y;
    int mb_xy = h->mb.i_mb_xy;
    int type_col[2] = { h->fref[1][0]->mb_type[mb_xy], h->fref[1][0]->mb_type[mb_xy] };
    int partition_col[2] = { h->fref[1][0]->mb_partition[mb_xy], h->fref[1][0]->mb_partition[mb_xy] };
    int preshift = MB_INTERLACED;
    int postshift = MB_INTERLACED;
    int offset = 1;
    int yshift = 1;
    h->mb.i_partition = partition_col[0];
    if( PARAM_INTERLACED && h->fref[1][0]->field[mb_xy] != MB_INTERLACED )
    {
        if( MB_INTERLACED )
        {
            mb_y = h->mb.i_mb_y&~1;
            mb_xy = mb_x + h->mb.i_mb_stride * mb_y;
            type_col[0] = h->fref[1][0]->mb_type[mb_xy];
            type_col[1] = h->fref[1][0]->mb_type[mb_xy + h->mb.i_mb_stride];
            partition_col[0] = h->fref[1][0]->mb_partition[mb_xy];
            partition_col[1] = h->fref[1][0]->mb_partition[mb_xy + h->mb.i_mb_stride];
            preshift = 0;
            yshift = 0;

            if( (IS_INTRA(type_col[0]) || partition_col[0] == D_16x16) &&
                (IS_INTRA(type_col[1]) || partition_col[1] == D_16x16) &&
                partition_col[0] != D_8x8 )
                h->mb.i_partition = D_16x8;
            else
                h->mb.i_partition = D_8x8;
        }
        else
        {
            int cur_poc = h->fdec->i_poc + h->fdec->i_delta_poc[MB_INTERLACED&h->mb.i_mb_y&1];
            int col_parity = abs(h->fref[1][0]->i_poc + h->fref[1][0]->i_delta_poc[0] - cur_poc)
                          >= abs(h->fref[1][0]->i_poc + h->fref[1][0]->i_delta_poc[1] - cur_poc);
            mb_y = (h->mb.i_mb_y&~1) + col_parity;
            mb_xy = mb_x + h->mb.i_mb_stride * mb_y;
            type_col[0] = type_col[1] = h->fref[1][0]->mb_type[mb_xy];
            partition_col[0] = partition_col[1] = h->fref[1][0]->mb_partition[mb_xy];
            preshift = 1;
            yshift = 2;
            h->mb.i_partition = partition_col[0];
        }
        offset = 0;
    }
    int i_mb_4x4 = 16 * h->mb.i_mb_stride * mb_y + 4 * mb_x;
    int i_mb_8x8 =  4 * h->mb.i_mb_stride * mb_y + 2 * mb_x;

    x264_macroblock_cache_ref( h, 0, 0, 4, 4, 1, 0 );

    /* Don't do any checks other than the ones we have to, based
     * on the size of the colocated partitions.
     * Depends on the enum order: D_8x8, D_16x8, D_8x16, D_16x16 */
    int max_i8 = (D_16x16 - h->mb.i_partition) + 1;
    int step = (h->mb.i_partition == D_16x8) + 1;
    int width = 4 >> ((D_16x16 - h->mb.i_partition)&1);
    int height = 4 >> ((D_16x16 - h->mb.i_partition)>>1);
    for( int i8 = 0; i8 < max_i8; i8 += step )
    {
        int x8 = i8&1;
        int y8 = i8>>1;
        int ypart = (SLICE_MBAFF && h->fref[1][0]->field[mb_xy] != MB_INTERLACED) ?
                    MB_INTERLACED ? y8*6 : 2*(h->mb.i_mb_y&1) + y8 :
                    3*y8;

        if( IS_INTRA( type_col[y8] ) )
        {
            x264_macroblock_cache_ref( h, 2*x8, 2*y8, width, height, 0, 0 );
            x264_macroblock_cache_mv(  h, 2*x8, 2*y8, width, height, 0, 0 );
            x264_macroblock_cache_mv(  h, 2*x8, 2*y8, width, height, 1, 0 );
            continue;
        }

        int i_part_8x8 = i_mb_8x8 + x8 + (ypart>>1) * h->mb.i_b8_stride;
        int i_ref1_ref = h->fref[1][0]->ref[0][i_part_8x8];
        int i_ref = (map_col_to_list0(i_ref1_ref>>preshift) * (1 << postshift)) + (offset&i_ref1_ref&MB_INTERLACED);

        if( i_ref >= 0 )
        {
            int dist_scale_factor = h->mb.dist_scale_factor[i_ref][0];
            int16_t *mv_col = h->fref[1][0]->mv[0][i_mb_4x4 + 3*x8 + ypart * h->mb.i_b4_stride];
            int16_t mv_y = (mv_col[1] * (1 << yshift)) / 2;
            int l0x = ( dist_scale_factor * mv_col[0] + 128 ) >> 8;
            int l0y = ( dist_scale_factor * mv_y + 128 ) >> 8;
            if( h->param.i_threads > 1 && (l0y > h->mb.mv_max_spel[1] || l0y-mv_y > h->mb.mv_max_spel[1]) )
                return 0;
            x264_macroblock_cache_ref( h, 2*x8, 2*y8, width, height, 0, i_ref );
            x264_macroblock_cache_mv( h, 2*x8, 2*y8, width, height, 0, pack16to32_mask(l0x, l0y) );
            x264_macroblock_cache_mv( h, 2*x8, 2*y8, width, height, 1, pack16to32_mask(l0x-mv_col[0], l0y-mv_y) );
        }
        else
        {
            /* the collocated ref isn't in the current list0 */
            /* FIXME: we might still be able to use direct_8x8 on some partitions */
            /* FIXME: with B-pyramid + extensive ref list reordering
             *   (not currently used), we would also have to check
             *   l1mv1 like in spatial mode */
            return 0;
        }
    }

    return 1;
}

static ALWAYS_INLINE int mb_predict_mv_direct16x16_spatial( x264_t *h, int b_interlaced )
{
    int8_t ref[2];
    ALIGNED_ARRAY_8( int16_t, mv,[2],[2] );
    for( int i_list = 0; i_list < 2; i_list++ )
    {
        int     i_refa = h->mb.cache.ref[i_list][X264_SCAN8_0 - 1];
        int16_t *mv_a  = h->mb.cache.mv[i_list][X264_SCAN8_0 - 1];
        int     i_refb = h->mb.cache.ref[i_list][X264_SCAN8_0 - 8];
        int16_t *mv_b  = h->mb.cache.mv[i_list][X264_SCAN8_0 - 8];
        int     i_refc = h->mb.cache.ref[i_list][X264_SCAN8_0 - 8 + 4];
        int16_t *mv_c  = h->mb.cache.mv[i_list][X264_SCAN8_0 - 8 + 4];
        if( i_refc == -2 )
        {
            i_refc = h->mb.cache.ref[i_list][X264_SCAN8_0 - 8 - 1];
            mv_c   = h->mb.cache.mv[i_list][X264_SCAN8_0 - 8 - 1];
        }

        int i_ref = (int)X264_MIN3( (unsigned)i_refa, (unsigned)i_refb, (unsigned)i_refc );
        if( i_ref < 0 )
        {
            i_ref = -1;
            M32( mv[i_list] ) = 0;
        }
        else
        {
            /* Same as x264_mb_predict_mv_16x16, but simplified to eliminate cases
             * not relevant to spatial direct. */
            int i_count = (i_refa == i_ref) + (i_refb == i_ref) + (i_refc == i_ref);

            if( i_count > 1 )
                x264_median_mv( mv[i_list], mv_a, mv_b, mv_c );
            else
            {
                if( i_refa == i_ref )
                    CP32( mv[i_list], mv_a );
                else if( i_refb == i_ref )
                    CP32( mv[i_list], mv_b );
                else
                    CP32( mv[i_list], mv_c );
            }
        }

        x264_macroblock_cache_ref( h, 0, 0, 4, 4, i_list, i_ref );
        x264_macroblock_cache_mv_ptr( h, 0, 0, 4, 4, i_list, mv[i_list] );
        ref[i_list] = i_ref;
    }

    int mb_x = h->mb.i_mb_x;
    int mb_y = h->mb.i_mb_y;
    int mb_xy = h->mb.i_mb_xy;
    int type_col[2] = { h->fref[1][0]->mb_type[mb_xy], h->fref[1][0]->mb_type[mb_xy] };
    int partition_col[2] = { h->fref[1][0]->mb_partition[mb_xy], h->fref[1][0]->mb_partition[mb_xy] };
    h->mb.i_partition = partition_col[0];
    if( b_interlaced && h->fref[1][0]->field[mb_xy] != MB_INTERLACED )
    {
        if( MB_INTERLACED )
        {
            mb_y = h->mb.i_mb_y&~1;
            mb_xy = mb_x + h->mb.i_mb_stride * mb_y;
            type_col[0] = h->fref[1][0]->mb_type[mb_xy];
            type_col[1] = h->fref[1][0]->mb_type[mb_xy + h->mb.i_mb_stride];
            partition_col[0] = h->fref[1][0]->mb_partition[mb_xy];
            partition_col[1] = h->fref[1][0]->mb_partition[mb_xy + h->mb.i_mb_stride];

            if( (IS_INTRA(type_col[0]) || partition_col[0] == D_16x16) &&
                (IS_INTRA(type_col[1]) || partition_col[1] == D_16x16) &&
                partition_col[0] != D_8x8 )
                h->mb.i_partition = D_16x8;
            else
                h->mb.i_partition = D_8x8;
        }
        else
        {
            int cur_poc = h->fdec->i_poc + h->fdec->i_delta_poc[MB_INTERLACED&h->mb.i_mb_y&1];
            int col_parity = abs(h->fref[1][0]->i_poc + h->fref[1][0]->i_delta_poc[0] - cur_poc)
                          >= abs(h->fref[1][0]->i_poc + h->fref[1][0]->i_delta_poc[1] - cur_poc);
            mb_y = (h->mb.i_mb_y&~1) + col_parity;
            mb_xy = mb_x + h->mb.i_mb_stride * mb_y;
            type_col[0] = type_col[1] = h->fref[1][0]->mb_type[mb_xy];
            partition_col[0] = partition_col[1] = h->fref[1][0]->mb_partition[mb_xy];
            h->mb.i_partition = partition_col[0];
        }
    }
    int i_mb_4x4 = b_interlaced ? 4 * (h->mb.i_b4_stride*mb_y + mb_x) : h->mb.i_b4_xy;
    int i_mb_8x8 = b_interlaced ? 2 * (h->mb.i_b8_stride*mb_y + mb_x) : h->mb.i_b8_xy;

    int8_t *l1ref0 = &h->fref[1][0]->ref[0][i_mb_8x8];
    int8_t *l1ref1 = &h->fref[1][0]->ref[1][i_mb_8x8];
    int16_t (*l1mv[2])[2] = { (int16_t (*)[2]) &h->fref[1][0]->mv[0][i_mb_4x4],
                              (int16_t (*)[2]) &h->fref[1][0]->mv[1][i_mb_4x4] };

    if( (M16( ref ) & 0x8080) == 0x8080 ) /* if( ref[0] < 0 && ref[1] < 0 ) */
    {
        x264_macroblock_cache_ref( h, 0, 0, 4, 4, 0, 0 );
        x264_macroblock_cache_ref( h, 0, 0, 4, 4, 1, 0 );
        return 1;
    }

    if( h->param.i_threads > 1
        && ( mv[0][1] > h->mb.mv_max_spel[1]
          || mv[1][1] > h->mb.mv_max_spel[1] ) )
    {
#if 0
        fprintf(stderr, "direct_spatial: (%d,%d) (%d,%d) > %d \n",
                mv[0][0], mv[0][1], mv[1][0], mv[1][1],
                h->mb.mv_max_spel[1]);
#endif
        return 0;
    }

    if( !M64( mv ) || (!b_interlaced && IS_INTRA( type_col[0] )) || (ref[0]&&ref[1]) )
        return 1;

    /* Don't do any checks other than the ones we have to, based
     * on the size of the colocated partitions.
     * Depends on the enum order: D_8x8, D_16x8, D_8x16, D_16x16 */
    int max_i8 = (D_16x16 - h->mb.i_partition) + 1;
    int step = (h->mb.i_partition == D_16x8) + 1;
    int width = 4 >> ((D_16x16 - h->mb.i_partition)&1);
    int height = 4 >> ((D_16x16 - h->mb.i_partition)>>1);

    /* col_zero_flag */
    for( int i8 = 0; i8 < max_i8; i8 += step )
    {
        const int x8 = i8&1;
        const int y8 = i8>>1;
        int ypart = (b_interlaced && h->fref[1][0]->field[mb_xy] != MB_INTERLACED) ?
                    MB_INTERLACED ? y8*6 : 2*(h->mb.i_mb_y&1) + y8 :
                    3*y8;
        int o8 = x8 + (ypart>>1) * h->mb.i_b8_stride;
        int o4 = 3*x8 + ypart * h->mb.i_b4_stride;

        if( b_interlaced && IS_INTRA( type_col[y8] ) )
            continue;

        int idx;
        if( l1ref0[o8] == 0 )
            idx = 0;
        else if( l1ref0[o8] < 0 && l1ref1[o8] == 0 )
            idx = 1;
        else
            continue;

        if( abs( l1mv[idx][o4][0] ) <= 1 && abs( l1mv[idx][o4][1] ) <= 1 )
        {
            if( ref[0] == 0 ) x264_macroblock_cache_mv( h, 2*x8, 2*y8, width, height, 0, 0 );
            if( ref[1] == 0 ) x264_macroblock_cache_mv( h, 2*x8, 2*y8, width, height, 1, 0 );
        }
    }

    return 1;
}


static int mb_predict_mv_direct16x16_spatial_interlaced( x264_t *h )
{
    return mb_predict_mv_direct16x16_spatial( h, 1 );
}

static int mb_predict_mv_direct16x16_spatial_progressive( x264_t *h )
{
    return mb_predict_mv_direct16x16_spatial( h, 0 );
}

int x264_mb_predict_mv_direct16x16( x264_t *h, int *b_changed )
{
    int b_available;
    if( h->param.analyse.i_direct_mv_pred == X264_DIRECT_PRED_NONE )
        return 0;
    else if( h->sh.b_direct_spatial_mv_pred )
    {
        if( SLICE_MBAFF )
            b_available = mb_predict_mv_direct16x16_spatial_interlaced( h );
        else
            b_available = mb_predict_mv_direct16x16_spatial_progressive( h );
    }
    else
        b_available = mb_predict_mv_direct16x16_temporal( h );

    if( b_changed != NULL && b_available )
    {
        int changed;

        changed  = (int)(M32( h->mb.cache.direct_mv[0][0] ) ^ M32( h->mb.cache.mv[0][x264_scan8[0]] ));
        changed |= (int)(M32( h->mb.cache.direct_mv[1][0] ) ^ M32( h->mb.cache.mv[1][x264_scan8[0]] ));
        changed |= h->mb.cache.direct_ref[0][0] ^ h->mb.cache.ref[0][x264_scan8[0]];
        changed |= h->mb.cache.direct_ref[1][0] ^ h->mb.cache.ref[1][x264_scan8[0]];
        if( !changed && h->mb.i_partition != D_16x16 )
        {
            changed |= (int)(M32( h->mb.cache.direct_mv[0][3] ) ^ M32( h->mb.cache.mv[0][x264_scan8[12]] ));
            changed |= (int)(M32( h->mb.cache.direct_mv[1][3] ) ^ M32( h->mb.cache.mv[1][x264_scan8[12]] ));
            changed |= h->mb.cache.direct_ref[0][3] ^ h->mb.cache.ref[0][x264_scan8[12]];
            changed |= h->mb.cache.direct_ref[1][3] ^ h->mb.cache.ref[1][x264_scan8[12]];
        }
        if( !changed && h->mb.i_partition == D_8x8 )
        {
            changed |= (int)(M32( h->mb.cache.direct_mv[0][1] ) ^ M32( h->mb.cache.mv[0][x264_scan8[4]] ));
            changed |= (int)(M32( h->mb.cache.direct_mv[1][1] ) ^ M32( h->mb.cache.mv[1][x264_scan8[4]] ));
            changed |= (int)(M32( h->mb.cache.direct_mv[0][2] ) ^ M32( h->mb.cache.mv[0][x264_scan8[8]] ));
            changed |= (int)(M32( h->mb.cache.direct_mv[1][2] ) ^ M32( h->mb.cache.mv[1][x264_scan8[8]] ));
            changed |= h->mb.cache.direct_ref[0][1] ^ h->mb.cache.ref[0][x264_scan8[4]];
            changed |= h->mb.cache.direct_ref[1][1] ^ h->mb.cache.ref[1][x264_scan8[4]];
            changed |= h->mb.cache.direct_ref[0][2] ^ h->mb.cache.ref[0][x264_scan8[8]];
            changed |= h->mb.cache.direct_ref[1][2] ^ h->mb.cache.ref[1][x264_scan8[8]];
        }
        *b_changed = changed;
        if( !changed )
            return b_available;
    }

    /* cache ref & mv */
    if( b_available )
        for( int l = 0; l < 2; l++ )
        {
            CP32( h->mb.cache.direct_mv[l][0], h->mb.cache.mv[l][x264_scan8[ 0]] );
            CP32( h->mb.cache.direct_mv[l][1], h->mb.cache.mv[l][x264_scan8[ 4]] );
            CP32( h->mb.cache.direct_mv[l][2], h->mb.cache.mv[l][x264_scan8[ 8]] );
            CP32( h->mb.cache.direct_mv[l][3], h->mb.cache.mv[l][x264_scan8[12]] );
            h->mb.cache.direct_ref[l][0] = h->mb.cache.ref[l][x264_scan8[ 0]];
            h->mb.cache.direct_ref[l][1] = h->mb.cache.ref[l][x264_scan8[ 4]];
            h->mb.cache.direct_ref[l][2] = h->mb.cache.ref[l][x264_scan8[ 8]];
            h->mb.cache.direct_ref[l][3] = h->mb.cache.ref[l][x264_scan8[12]];
            h->mb.cache.direct_partition = h->mb.i_partition;
        }

    return b_available;
}

/* This just improves encoder performance, it's not part of the spec */
void x264_mb_predict_mv_ref16x16( x264_t *h, int i_list, int i_ref, int16_t (*mvc)[2], int *i_mvc )
{
    int16_t (*mvr)[2] = h->mb.mvr[i_list][i_ref];
    int i = 0;

#define SET_MVP(mvp) \
    { \
        CP32( mvc[i], mvp ); \
        i++; \
    }

#define SET_IMVP(xy) \
    if( xy >= 0 ) \
    { \
        int shift = 1 + MB_INTERLACED - h->mb.field[xy]; \
        int16_t *mvp = h->mb.mvr[i_list][i_ref<<1>>shift][xy]; \
        mvc[i][0] = mvp[0]; \
        mvc[i][1] = mvp[1]*2>>shift; \
        i++; \
    }

    /* b_direct */
    if( h->sh.i_type == SLICE_TYPE_B
        && h->mb.cache.ref[i_list][x264_scan8[12]] == i_ref )
    {
        SET_MVP( h->mb.cache.mv[i_list][x264_scan8[12]] );
    }

    if( i_ref == 0 && h->frames.b_have_lowres )
    {
        int idx = i_list ? h->fref[1][0]->i_frame-h->fenc->i_frame-1
                         : h->fenc->i_frame-h->fref[0][0]->i_frame-1;
        if( idx <= h->param.i_bframe )
        {
            int16_t (*lowres_mv)[2] = h->fenc->lowres_mvs[i_list][idx];
            if( lowres_mv[0][0] != 0x7fff )
            {
                M32( mvc[i] ) = (M32( lowres_mv[h->mb.i_mb_xy] )*2)&0xfffeffff;
                i++;
            }
        }
    }

    /* spatial predictors */
    if( SLICE_MBAFF )
    {
        SET_IMVP( h->mb.i_mb_left_xy[0] );
        SET_IMVP( h->mb.i_mb_top_xy );
        SET_IMVP( h->mb.i_mb_topleft_xy );
        SET_IMVP( h->mb.i_mb_topright_xy );
    }
    else
    {
        SET_MVP( mvr[h->mb.i_mb_left_xy[0]] );
        SET_MVP( mvr[h->mb.i_mb_top_xy] );
        SET_MVP( mvr[h->mb.i_mb_topleft_xy] );
        SET_MVP( mvr[h->mb.i_mb_topright_xy] );
    }
#undef SET_IMVP
#undef SET_MVP

    /* temporal predictors */
    if( h->fref[0][0]->i_ref[0] > 0 )
    {
        x264_frame_t *l0 = h->fref[0][0];
        int field = h->mb.i_mb_y&1;
        int curpoc = h->fdec->i_poc + h->fdec->i_delta_poc[field];
        int refpoc = h->fref[i_list][i_ref>>SLICE_MBAFF]->i_poc;
        refpoc += l0->i_delta_poc[field^(i_ref&1)];

#define SET_TMVP( dx, dy ) \
        { \
            int mb_index = h->mb.i_mb_xy + dx + dy*h->mb.i_mb_stride; \
            int scale = (curpoc - refpoc) * l0->inv_ref_poc[MB_INTERLACED&field]; \
            mvc[i][0] = x264_clip3( (l0->mv16x16[mb_index][0]*scale + 128) >> 8, INT16_MIN, INT16_MAX ); \
            mvc[i][1] = x264_clip3( (l0->mv16x16[mb_index][1]*scale + 128) >> 8, INT16_MIN, INT16_MAX ); \
            i++; \
        }

        SET_TMVP(0,0);
        if( h->mb.i_mb_x < h->mb.i_mb_width-1 )
            SET_TMVP(1,0);
        if( h->mb.i_mb_y < h->mb.i_mb_height-1 )
            SET_TMVP(0,1);
#undef SET_TMVP
    }

    *i_mvc = i;
}
