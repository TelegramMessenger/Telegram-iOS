/* 
 * h264bitstream - a library for reading and writing H.264 video
 * Copyright (C) 2005-2007 Auroras Entertainment, LLC
 * Copyright (C) 2008-2011 Avail-TVN
 * Copyright (C) 2012 Alex Izvorski
 * 
 * Written by Alex Izvorski <aizvorski@gmail.com> and Alex Giladi <alex.giladi@gmail.com>
 * 
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 * 
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 */

#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>

#include "h264_stream.h"
#include "h264_slice_data.h"



void read_slice_data( h264_stream_t* h, bs_t* b );
void read_macroblock_layer( h264_stream_t* h, bs_t* b );
void read_mb_pred( h264_stream_t* h, bs_t* b, int mb_type );
void read_sub_mb_pred( h264_stream_t* h, bs_t* b, int mb_type );
void read_residual( h264_stream_t* h, bs_t* b );
void read_residual_block_cavlc( bs_t* b, int* coeffLevel, int maxNumCoeff );
void read_residual_block_cabac( bs_t* b, int* coeffLevel, int maxNumCoeff );


//7.3.4 Slice data syntax
void read_slice_data( h264_stream_t* h, bs_t* b )
{
    macroblock_t* mb;
    if( h->pps->entropy_coding_mode_flag )
    {
        while( !bs_byte_aligned(b) )
        {
            /* cabac_alignment_one_bit */ bs_skip_u(b, 1);
        }
    }
    int CurrMbAddr = h->sh->first_mb_in_slice * ( 1 + MbaffFrameFlag );
    int moreDataFlag = 1;
    int prevMbSkipped = 0;
    do
    {
        int mb_skip_flag;
        int mb_skip_run;
        if( h->sh->slice_type != SH_SLICE_TYPE_I && h->sh->slice_type != SH_SLICE_TYPE_SI )
        {
            if( !h->pps->entropy_coding_mode_flag )
            {
                mb_skip_run = bs_read_ue(b);
                prevMbSkipped = ( mb_skip_run > 0 );
                for( int i=0; i<mb_skip_run; i++ )
                {
                    CurrMbAddr = NextMbAddress( CurrMbAddr );
                }
                moreDataFlag = more_rbsp_data( );
            }
            else
            {
                mb_skip_flag = bs_read_ae(b);
                moreDataFlag = !mb_skip_flag;
            }
        }
        if( moreDataFlag )
        {
            if( MbaffFrameFlag && ( CurrMbAddr % 2 == 0 ||
                                    ( CurrMbAddr % 2 == 1 && prevMbSkipped ) ) )
            {
                if (cabac) { mb->mb_field_decoding_flag = bs_read_ae(b); }
                else { mb->mb_field_decoding_flag = bs_read_u(b, 1); }
            }
            read_macroblock_layer( h, b );
        }
        if( !h->pps->entropy_coding_mode_flag )
        {
            moreDataFlag = more_rbsp_data( );
        }
        else
        {
        if( h->sh->slice_type != SH_SLICE_TYPE_I && h->sh->slice_type != SH_SLICE_TYPE_SI )
            {
                prevMbSkipped = mb_skip_flag;
            }
            if( MbaffFrameFlag && CurrMbAddr % 2 == 0 )
            {
                moreDataFlag = 1;
            }
            else
            {
                int end_of_slice_flag;
                end_of_slice_flag = bs_read_ae(b);
                moreDataFlag = !end_of_slice_flag;
            }
        }
        CurrMbAddr = NextMbAddress( CurrMbAddr );
    } while( moreDataFlag );
}


//7.3.5 Macroblock layer syntax
void read_macroblock_layer( h264_stream_t* h, bs_t* b )
{
    macroblock_t* mb;
    if (cabac) { mb->mb_type = bs_read_ae(b); }
    else { mb->mb_type = bs_read_ue(b); }
    if( mb->mb_type == I_PCM )
    {
        while( !bs_byte_aligned(b) )
        {
            // ERROR: value( pcm_alignment_zero_bit, f(1) );
        }
        for( int i = 0; i < 256; i++ )
        {
            mb->pcm_sample_luma[ i ] = bs_read_u8(b);
        }
        for( int i = 0; i < 2 * MbWidthC * MbHeightC; i++ )
        {
            mb->pcm_sample_chroma[ i ] = bs_read_u8(b);
        }
    }
    else
    {
        int noSubMbPartSizeLessThan8x8Flag = 1;
        if( mb->mb_type != I_NxN &&
            MbPartPredMode( mb->mb_type, 0 ) != Intra_16x16 &&
            NumMbPart( mb->mb_type ) == 4 )
        {
            read_sub_mb_pred( h, b, mb->mb_type );
            for( int mbPartIdx = 0; mbPartIdx < 4; mbPartIdx++ )
            {
                if( mb->sub_mb_type[ mbPartIdx ] != B_Direct_8x8 )
                {
                    if( NumSubMbPart( mb->sub_mb_type[ mbPartIdx ] ) > 1 )
                    {
                        noSubMbPartSizeLessThan8x8Flag = 0;
                    }
                }
                else if( !h->sps->direct_8x8_inference_flag )
                {
                    noSubMbPartSizeLessThan8x8Flag = 0;
                }
            }
        }
        else
        {
            if( h->pps->transform_8x8_mode_flag && mb->mb_type == I_NxN )
            {
                if (cabac) { mb->transform_size_8x8_flag = bs_read_ae(b); }
                else { mb->transform_size_8x8_flag = bs_read_u(b, 1); }
            }
            read_mb_pred( h, b, mb->mb_type );
        }
        if( MbPartPredMode( mb->mb_type, 0 ) != Intra_16x16 )
        {
            if (cabac) { mb->coded_block_pattern = bs_read_ae(b); }
            else { mb->coded_block_pattern = bs_read_me(b); }
            if( CodedBlockPatternLuma > 0 &&
                h->pps->transform_8x8_mode_flag && mb->mb_type != I_NxN &&
                noSubMbPartSizeLessThan8x8Flag &&
                ( mb->mb_type != B_Direct_16x16 || h->sps->direct_8x8_inference_flag ) )
            {
                if (cabac) { mb->transform_size_8x8_flag = bs_read_ae(b); }
                else { mb->transform_size_8x8_flag = bs_read_u(b, 1); }
            }
        }
        if( CodedBlockPatternLuma > 0 || CodedBlockPatternChroma > 0 ||
            MbPartPredMode( mb->mb_type, 0 ) == Intra_16x16 )
        {
            if (cabac) { mb->mb_qp_delta = bs_read_ae(b); }
            else { mb->mb_qp_delta = bs_read_se(b); }
            read_residual( h, b );
        }
    }
}

//7.3.5.1 Macroblock prediction syntax
void read_mb_pred( h264_stream_t* h, bs_t* b, int mb_type )
{
    macroblock_t* mb;

    if( MbPartPredMode( mb->mb_type, 0 ) == Intra_4x4 ||
        MbPartPredMode( mb->mb_type, 0 ) == Intra_8x8 ||
        MbPartPredMode( mb->mb_type, 0 ) == Intra_16x16 )
    {
        if( MbPartPredMode( mb->mb_type, 0 ) == Intra_4x4 )
        {
            for( int luma4x4BlkIdx=0; luma4x4BlkIdx<16; luma4x4BlkIdx++ )
            {
                if (cabac) { mb->prev_intra4x4_pred_mode_flag[ luma4x4BlkIdx ] = bs_read_ae(b); }
                else { mb->prev_intra4x4_pred_mode_flag[ luma4x4BlkIdx ] = bs_read_u(b, 1); }
                if( !mb->prev_intra4x4_pred_mode_flag[ luma4x4BlkIdx ] )
                {
                    if (cabac) { mb->rem_intra4x4_pred_mode[ luma4x4BlkIdx ] = bs_read_ae(b); }
                    else { mb->rem_intra4x4_pred_mode[ luma4x4BlkIdx ] = bs_read_u(b, 3); }
                }
            }
        }
        if( MbPartPredMode( mb->mb_type, 0 ) == Intra_8x8 )
        {
            for( int luma8x8BlkIdx=0; luma8x8BlkIdx<4; luma8x8BlkIdx++ )
            {
                if (cabac) { mb->prev_intra8x8_pred_mode_flag[ luma8x8BlkIdx ] = bs_read_ae(b); }
                else { mb->prev_intra8x8_pred_mode_flag[ luma8x8BlkIdx ] = bs_read_u(b, 1); }
                if( !mb->prev_intra8x8_pred_mode_flag[ luma8x8BlkIdx ] )
                {
                    if (cabac) { mb->rem_intra8x8_pred_mode[ luma8x8BlkIdx ] = bs_read_ae(b); }
                    else { mb->rem_intra8x8_pred_mode[ luma8x8BlkIdx ] = bs_read_u(b, 3); }
                }
            }
        }
        if( h->sps->chroma_format_idc != 0 )
        {
            if (cabac) { mb->intra_chroma_pred_mode = bs_read_ae(b); }
            else { mb->intra_chroma_pred_mode = bs_read_ue(b); }
        }
    }
    else if( MbPartPredMode( mb->mb_type, 0 ) != Direct )
    {
        for( int mbPartIdx = 0; mbPartIdx < NumMbPart( mb->mb_type ); mbPartIdx++)
        {
            if( ( h->pps->num_ref_idx_l0_active_minus1 > 0 ||
                  mb->mb_field_decoding_flag ) &&
                MbPartPredMode( mb->mb_type, mbPartIdx ) != Pred_L1 )
            {
                if (cabac) { mb->ref_idx_l0[ mbPartIdx ] = bs_read_ae(b); }
                else { mb->ref_idx_l0[ mbPartIdx ] = bs_read_te(b); }
            }
        }
        for( int mbPartIdx = 0; mbPartIdx < NumMbPart( mb->mb_type ); mbPartIdx++)
        {
            if( ( h->pps->num_ref_idx_l1_active_minus1 > 0 ||
                  mb->mb_field_decoding_flag ) &&
                MbPartPredMode( mb->mb_type, mbPartIdx ) != Pred_L0 )
            {
                if (cabac) { mb->ref_idx_l1[ mbPartIdx ] = bs_read_ae(b); }
                else { mb->ref_idx_l1[ mbPartIdx ] = bs_read_te(b); }
            }
        }
        for( int mbPartIdx = 0; mbPartIdx < NumMbPart( mb->mb_type ); mbPartIdx++)
        {
            if( MbPartPredMode ( mb->mb_type, mbPartIdx ) != Pred_L1 )
            {
                for( int compIdx = 0; compIdx < 2; compIdx++ )
                {
                    if (cabac) { mb->mvd_l0[ mbPartIdx ][ 0 ][ compIdx ] = bs_read_ae(b); }
                    else { mb->mvd_l0[ mbPartIdx ][ 0 ][ compIdx ] = bs_read_se(b); }
                }
            }
        }
        for( int mbPartIdx = 0; mbPartIdx < NumMbPart( mb->mb_type ); mbPartIdx++)
        {
            if( MbPartPredMode( mb->mb_type, mbPartIdx ) != Pred_L0 )
            {
                for( int compIdx = 0; compIdx < 2; compIdx++ )
                {
                    if (cabac) { mb->mvd_l1[ mbPartIdx ][ 0 ][ compIdx ] = bs_read_ae(b); }
                    else { mb->mvd_l1[ mbPartIdx ][ 0 ][ compIdx ] = bs_read_se(b); }
                }
            }
        }
    }
}

//7.3.5.2  Sub-macroblock prediction syntax
void read_sub_mb_pred( h264_stream_t* h, bs_t* b, int mb_type )
{
    macroblock_t* mb;

    for( int mbPartIdx = 0; mbPartIdx < 4; mbPartIdx++ )
    {
        if (cabac) { mb->sub_mb_type[ mbPartIdx ] = bs_read_ae(b); }
        else { mb->sub_mb_type[ mbPartIdx ] = bs_read_ue(b); }
    }
    for( int mbPartIdx = 0; mbPartIdx < 4; mbPartIdx++ )
    {
        if( ( h->pps->num_ref_idx_l0_active_minus1 > 0 || mb->mb_field_decoding_flag ) &&
            mb->mb_type != P_8x8ref0 &&
            mb->sub_mb_type[ mbPartIdx ] != B_Direct_8x8 &&
            SubMbPredMode( mb->sub_mb_type[ mbPartIdx ] ) != Pred_L1 )
        {
            if (cabac) { mb->ref_idx_l0[ mbPartIdx ] = bs_read_ae(b); }
            else { mb->ref_idx_l0[ mbPartIdx ] = bs_read_te(b); }
        }
    }
    for( int mbPartIdx = 0; mbPartIdx < 4; mbPartIdx++ )
    {
        if( (h->pps->num_ref_idx_l1_active_minus1 > 0 || mb->mb_field_decoding_flag ) &&
            mb->sub_mb_type[ mbPartIdx ] != B_Direct_8x8 &&
            SubMbPredMode( mb->sub_mb_type[ mbPartIdx ] ) != Pred_L0 )
        {
            if (cabac) { mb->ref_idx_l1[ mbPartIdx ] = bs_read_ae(b); }
            else { mb->ref_idx_l1[ mbPartIdx ] = bs_read_te(b); }
        }
    }
    for( int mbPartIdx = 0; mbPartIdx < 4; mbPartIdx++ )
    {
        if( mb->sub_mb_type[ mbPartIdx ] != B_Direct_8x8 &&
            SubMbPredMode( mb->sub_mb_type[ mbPartIdx ] ) != Pred_L1 )
        {
            for( int subMbPartIdx = 0;
                 subMbPartIdx < NumSubMbPart( mb->sub_mb_type[ mbPartIdx ] );
                 subMbPartIdx++)
            {
                for( int compIdx = 0; compIdx < 2; compIdx++ )
                {
                    if (cabac) { mb->mvd_l0[ mbPartIdx ][ subMbPartIdx ][ compIdx ] = bs_read_ae(b); }
                    else { mb->mvd_l0[ mbPartIdx ][ subMbPartIdx ][ compIdx ] = bs_read_se(b); }
                }
            }
        }
    }
    for( int mbPartIdx = 0; mbPartIdx < 4; mbPartIdx++ )
    {
        if( mb->sub_mb_type[ mbPartIdx ] != B_Direct_8x8 &&
            SubMbPredMode( mb->sub_mb_type[ mbPartIdx ] ) != Pred_L0 )
        {
            for( int subMbPartIdx = 0;
                 subMbPartIdx < NumSubMbPart( mb->sub_mb_type[ mbPartIdx ] );
                 subMbPartIdx++)
            {
                for( int compIdx = 0; compIdx < 2; compIdx++ )
                {
                    if (cabac) { mb->mvd_l1[ mbPartIdx ][ subMbPartIdx ][ compIdx ] = bs_read_ae(b); }
                    else { mb->mvd_l1[ mbPartIdx ][ subMbPartIdx ][ compIdx ] = bs_read_se(b); }
                }
            }
        }
    }
}

//7.3.5.3 Residual data syntax
void read_residual( h264_stream_t* h, bs_t* b )
{
    macroblock_t* mb;

/*
    if( !h->pps->entropy_coding_mode_flag )
    {
        residual_block = residual_block_cavlc;
    }
    else
    {
        residual_block = residual_block_cabac;
    }
*/
    // FIXME
#define read_residual_block read_residual_block_cavlc

    if( MbPartPredMode( mb->mb_type, 0 ) == Intra_16x16 )
    {
        read_residual_block( b, mb->Intra16x16DCLevel, 16 );
    }
    for( int i8x8 = 0; i8x8 < 4; i8x8++ ) // each luma 8x8 block
    {
        if( !mb->transform_size_8x8_flag || !h->pps->entropy_coding_mode_flag )
        {
            for( int i4x4 = 0; i4x4 < 4; i4x4++ ) // each 4x4 sub-block of block
            {
                if( CodedBlockPatternLuma & ( 1 << i8x8 ) )
                {
                    if( MbPartPredMode( mb->mb_type, 0 ) == Intra_16x16 )
                    {
                        read_residual_block( b, mb->Intra16x16ACLevel[ i8x8 * 4 + i4x4 ], 15 );
                    }
                    else
                    {
                        read_residual_block( b, mb->LumaLevel[ i8x8 * 4 + i4x4 ], 16 );
                    }
                }
                else if( MbPartPredMode( mb->mb_type, 0 ) == Intra_16x16 )
                {
                    for( int i = 0; i < 15; i++ )
                    {
                        mb->Intra16x16ACLevel[ i8x8 * 4 + i4x4 ][ i ] = 0;
                    }
                }
                else
                {
                    for( int i = 0; i < 16; i++ )
                    {
                        mb->LumaLevel[ i8x8 * 4 + i4x4 ][ i ] = 0;
                    }
                }
                if( !h->pps->entropy_coding_mode_flag && mb->transform_size_8x8_flag )
                {
                    for( int i = 0; i < 16; i++ )
                    {
                        mb->LumaLevel8x8[ i8x8 ][ 4 * i + i4x4 ] = mb->LumaLevel[ i8x8 * 4 + i4x4 ][ i ];
                    }
                }
            }
        }
        else if( CodedBlockPatternLuma & ( 1 << i8x8 ) )
        {
            read_residual_block( b, mb->LumaLevel8x8[ i8x8 ], 64 );
        }
        else
        {
            for( int i = 0; i < 64; i++ )
            {
                mb->LumaLevel8x8[ i8x8 ][ i ] = 0;
            }
        }
    }
    if( h->sps->chroma_format_idc != 0 )
    {
        int NumC8x8 = 4 / ( SubWidthC * SubHeightC );
        for( int iCbCr = 0; iCbCr < 2; iCbCr++ )
        {
            if( CodedBlockPatternChroma & 3 ) // chroma DC residual present
            {
                read_residual_block( b, mb->ChromaDCLevel[ iCbCr ], 4 * NumC8x8 );
            }
            else
            {
                for( int i = 0; i < 4 * NumC8x8; i++ )
                {
                    mb->ChromaDCLevel[ iCbCr ][ i ] = 0;
                }
            }
        }
        for( int iCbCr = 0; iCbCr < 2; iCbCr++ )
        {
            for( int i8x8 = 0; i8x8 < NumC8x8; i8x8++ )
            {
                for( int i4x4 = 0; i4x4 < 4; i4x4++ )
                {
                    if( CodedBlockPatternChroma & 2 )  // chroma AC residual present
                    {
                        read_residual_block( b, mb->ChromaACLevel[ iCbCr ][ i8x8*4+i4x4 ], 15);
                    }
                    else
                    {
                        for( int i = 0; i < 15; i++ )
                        {
                            mb->ChromaACLevel[ iCbCr ][ i8x8*4+i4x4 ][ i ] = 0;
                        }
                    }
                }
            }
        }
    }

}


//7.3.5.3.1 Residual block CAVLC syntax
void read_residual_block_cavlc( bs_t* b, int* coeffLevel, int maxNumCoeff )
{
    int level[256];
    int run[256];
    for( int i = 0; i < maxNumCoeff; i++ )
    {
        coeffLevel[ i ] = 0;
    }
    int coeff_token;
    coeff_token = bs_read_ce(b);
    int suffixLength;
    if( TotalCoeff( coeff_token ) > 0 )
    {
        if( TotalCoeff( coeff_token ) > 10 && TrailingOnes( coeff_token ) < 3 )
        {
            suffixLength = 1;
        }
        else
        {
            suffixLength = 0;
        }
        for( int i = 0; i < TotalCoeff( coeff_token ); i++ )
        {
            if( i < TrailingOnes( coeff_token ) )
            {
                int trailing_ones_sign_flag;
                trailing_ones_sign_flag = bs_read_u(b, 1);
                level[ i ] = 1 - 2 * trailing_ones_sign_flag;
            }
            else
            {
                int level_prefix;
                level_prefix = bs_read_ce(b);
                int levelCode;
                levelCode = ( Min( 15, level_prefix ) << suffixLength );
                if( suffixLength > 0 || level_prefix >= 14 )
                {
                    int level_suffix;
                    // ERROR: value( level_suffix, u ); // FIXME
                    levelCode += level_suffix;
                }
                if( level_prefix >= 15 && suffixLength == 0 )
                {
                    levelCode += 15;
                }
                if( level_prefix >= 16 )
                {
                    levelCode += ( 1 << ( level_prefix - 3 ) ) - 4096;
                }
                if( i == TrailingOnes( coeff_token ) &&
                    TrailingOnes( coeff_token ) < 3 )
                {
                    levelCode += 2;
                }
                if( levelCode % 2 == 0 )
                {
                    level[ i ] = ( levelCode + 2 ) >> 1;
                }
                else
                {
                    level[ i ] = ( -levelCode - 1 ) >> 1;
                }
                if( suffixLength == 0 )
                {
                    suffixLength = 1;
                }
                if( Abs( level[ i ] ) > ( 3 << ( suffixLength - 1 ) ) &&
                    suffixLength < 6 )
                {
                    suffixLength++;
                }
            }
        }
    int zerosLeft;
        if( TotalCoeff( coeff_token ) < maxNumCoeff )
        {
            int total_zeros;
            total_zeros = bs_read_ce(b);
            zerosLeft = total_zeros;
        } else
        {
            zerosLeft = 0;
        }
        for( int i = 0; i < TotalCoeff( coeff_token ) - 1; i++ )
        {
            if( zerosLeft > 0 )
            {
                int run_before;
                run_before = bs_read_ce(b);
                run[ i ] = run_before;
            } else
            {
                run[ i ] = 0;
            }
            zerosLeft = zerosLeft - run[ i ];
        }
        run[ TotalCoeff( coeff_token ) - 1 ] = zerosLeft;
        int coeffNum = -1;

        for( int i = TotalCoeff( coeff_token ) - 1; i >= 0; i-- )
        {
            coeffNum += run[ i ] + 1;
            coeffLevel[ coeffNum ] = level[ i ];
        }
    }
}


#ifdef HAVE_CABAC
//7.3.5.3.2 Residual block CABAC syntax
void read_residual_block_cabac( bs_t* b, int* coeffLevel, int maxNumCoeff )
{
    if( maxNumCoeff == 64 )
    {
        coded_block_flag = 1;
    }
    else
    {
        coded_block_flag = bs_read_ae(b);
    }
    if( coded_block_flag )
    {
        numCoeff = maxNumCoeff;
        int i=0;
        do
        {
            significant_coeff_flag[ i ] = bs_read_ae(b);
            if( significant_coeff_flag[ i ] )
            {
                last_significant_coeff_flag[ i ] = bs_read_ae(b);
                if( last_significant_coeff_flag[ i ] )
                {
                    numCoeff = i + 1;
                    for( int j = numCoeff; j < maxNumCoeff; j++ )
                    {
                        coeffLevel[ j ] = 0;
                    }
                }
            }
            i++;
        } while( i < numCoeff - 1 );

        coeff_abs_level_minus1[ numCoeff - 1 ] = bs_read_ae(b);
        coeff_sign_flag[ numCoeff - 1 ] = bs_read_ae(b);
        coeffLevel[ numCoeff - 1 ] =
            ( coeff_abs_level_minus1[ numCoeff - 1 ] + 1 ) *
            ( 1 - 2 * coeff_sign_flag[ numCoeff - 1 ] );
        for( int i = numCoeff - 2; i >= 0; i-- )
        {
            if( significant_coeff_flag[ i ] )
            {
                coeff_abs_level_minus1[ i ] = bs_read_ae(b);
                coeff_sign_flag[ i ] = bs_read_ae(b);
                coeffLevel[ i ] = ( coeff_abs_level_minus1[ i ] + 1 ) *
                    ( 1 - 2 * coeff_sign_flag[ i ] );
            }
            else
            {
                coeffLevel[ i ] = 0;
            }
        }
    }
    else
    {
        for( int i = 0; i < maxNumCoeff; i++ )
        {
            coeffLevel[ i ] = 0;
        }
    }
}

#endif


void write_slice_data( h264_stream_t* h, bs_t* b );
void write_macroblock_layer( h264_stream_t* h, bs_t* b );
void write_mb_pred( h264_stream_t* h, bs_t* b, int mb_type );
void write_sub_mb_pred( h264_stream_t* h, bs_t* b, int mb_type );
void write_residual( h264_stream_t* h, bs_t* b );
void write_residual_block_cavlc( bs_t* b, int* coeffLevel, int maxNumCoeff );
void write_residual_block_cabac( bs_t* b, int* coeffLevel, int maxNumCoeff );


//7.3.4 Slice data syntax
void write_slice_data( h264_stream_t* h, bs_t* b )
{
    macroblock_t* mb;
    if( h->pps->entropy_coding_mode_flag )
    {
        while( !bs_byte_aligned(b) )
        {
            /* cabac_alignment_one_bit */ bs_write_u(b, 1, 1);
        }
    }
    int CurrMbAddr = h->sh->first_mb_in_slice * ( 1 + MbaffFrameFlag );
    int moreDataFlag = 1;
    int prevMbSkipped = 0;
    do
    {
        int mb_skip_flag;
        int mb_skip_run;
        if( h->sh->slice_type != SH_SLICE_TYPE_I && h->sh->slice_type != SH_SLICE_TYPE_SI )
        {
            if( !h->pps->entropy_coding_mode_flag )
            {
                bs_write_ue(b, mb_skip_run);
                prevMbSkipped = ( mb_skip_run > 0 );
                for( int i=0; i<mb_skip_run; i++ )
                {
                    CurrMbAddr = NextMbAddress( CurrMbAddr );
                }
                moreDataFlag = more_rbsp_data( );
            }
            else
            {
                bs_write_ae(b, mb_skip_flag);
                moreDataFlag = !mb_skip_flag;
            }
        }
        if( moreDataFlag )
        {
            if( MbaffFrameFlag && ( CurrMbAddr % 2 == 0 ||
                                    ( CurrMbAddr % 2 == 1 && prevMbSkipped ) ) )
            {
                if (cabac) { bs_write_ae(b, mb->mb_field_decoding_flag); }
                else { bs_write_u(b, 1, mb->mb_field_decoding_flag); }
            }
            write_macroblock_layer( h, b );
        }
        if( !h->pps->entropy_coding_mode_flag )
        {
            moreDataFlag = more_rbsp_data( );
        }
        else
        {
        if( h->sh->slice_type != SH_SLICE_TYPE_I && h->sh->slice_type != SH_SLICE_TYPE_SI )
            {
                prevMbSkipped = mb_skip_flag;
            }
            if( MbaffFrameFlag && CurrMbAddr % 2 == 0 )
            {
                moreDataFlag = 1;
            }
            else
            {
                int end_of_slice_flag;
                bs_write_ae(b, end_of_slice_flag);
                moreDataFlag = !end_of_slice_flag;
            }
        }
        CurrMbAddr = NextMbAddress( CurrMbAddr );
    } while( moreDataFlag );
}


//7.3.5 Macroblock layer syntax
void write_macroblock_layer( h264_stream_t* h, bs_t* b )
{
    macroblock_t* mb;
    if (cabac) { bs_write_ae(b, mb->mb_type); }
    else { bs_write_ue(b, mb->mb_type); }
    if( mb->mb_type == I_PCM )
    {
        while( !bs_byte_aligned(b) )
        {
            // ERROR: value( pcm_alignment_zero_bit, f(1) );
        }
        for( int i = 0; i < 256; i++ )
        {
            bs_write_u8(b, mb->pcm_sample_luma[ i ]);
        }
        for( int i = 0; i < 2 * MbWidthC * MbHeightC; i++ )
        {
            bs_write_u8(b, mb->pcm_sample_chroma[ i ]);
        }
    }
    else
    {
        int noSubMbPartSizeLessThan8x8Flag = 1;
        if( mb->mb_type != I_NxN &&
            MbPartPredMode( mb->mb_type, 0 ) != Intra_16x16 &&
            NumMbPart( mb->mb_type ) == 4 )
        {
            write_sub_mb_pred( h, b, mb->mb_type );
            for( int mbPartIdx = 0; mbPartIdx < 4; mbPartIdx++ )
            {
                if( mb->sub_mb_type[ mbPartIdx ] != B_Direct_8x8 )
                {
                    if( NumSubMbPart( mb->sub_mb_type[ mbPartIdx ] ) > 1 )
                    {
                        noSubMbPartSizeLessThan8x8Flag = 0;
                    }
                }
                else if( !h->sps->direct_8x8_inference_flag )
                {
                    noSubMbPartSizeLessThan8x8Flag = 0;
                }
            }
        }
        else
        {
            if( h->pps->transform_8x8_mode_flag && mb->mb_type == I_NxN )
            {
                if (cabac) { bs_write_ae(b, mb->transform_size_8x8_flag); }
                else { bs_write_u(b, 1, mb->transform_size_8x8_flag); }
            }
            write_mb_pred( h, b, mb->mb_type );
        }
        if( MbPartPredMode( mb->mb_type, 0 ) != Intra_16x16 )
        {
            if (cabac) { bs_write_ae(b, mb->coded_block_pattern); }
            else { bs_write_me(b, mb->coded_block_pattern); }
            if( CodedBlockPatternLuma > 0 &&
                h->pps->transform_8x8_mode_flag && mb->mb_type != I_NxN &&
                noSubMbPartSizeLessThan8x8Flag &&
                ( mb->mb_type != B_Direct_16x16 || h->sps->direct_8x8_inference_flag ) )
            {
                if (cabac) { bs_write_ae(b, mb->transform_size_8x8_flag); }
                else { bs_write_u(b, 1, mb->transform_size_8x8_flag); }
            }
        }
        if( CodedBlockPatternLuma > 0 || CodedBlockPatternChroma > 0 ||
            MbPartPredMode( mb->mb_type, 0 ) == Intra_16x16 )
        {
            if (cabac) { bs_write_ae(b, mb->mb_qp_delta); }
            else { bs_write_se(b, mb->mb_qp_delta); }
            write_residual( h, b );
        }
    }
}

//7.3.5.1 Macroblock prediction syntax
void write_mb_pred( h264_stream_t* h, bs_t* b, int mb_type )
{
    macroblock_t* mb;

    if( MbPartPredMode( mb->mb_type, 0 ) == Intra_4x4 ||
        MbPartPredMode( mb->mb_type, 0 ) == Intra_8x8 ||
        MbPartPredMode( mb->mb_type, 0 ) == Intra_16x16 )
    {
        if( MbPartPredMode( mb->mb_type, 0 ) == Intra_4x4 )
        {
            for( int luma4x4BlkIdx=0; luma4x4BlkIdx<16; luma4x4BlkIdx++ )
            {
                if (cabac) { bs_write_ae(b, mb->prev_intra4x4_pred_mode_flag[ luma4x4BlkIdx ]); }
                else { bs_write_u(b, 1, mb->prev_intra4x4_pred_mode_flag[ luma4x4BlkIdx ]); }
                if( !mb->prev_intra4x4_pred_mode_flag[ luma4x4BlkIdx ] )
                {
                    if (cabac) { bs_write_ae(b, mb->rem_intra4x4_pred_mode[ luma4x4BlkIdx ]); }
                    else { bs_write_u(b, 3, mb->rem_intra4x4_pred_mode[ luma4x4BlkIdx ]); }
                }
            }
        }
        if( MbPartPredMode( mb->mb_type, 0 ) == Intra_8x8 )
        {
            for( int luma8x8BlkIdx=0; luma8x8BlkIdx<4; luma8x8BlkIdx++ )
            {
                if (cabac) { bs_write_ae(b, mb->prev_intra8x8_pred_mode_flag[ luma8x8BlkIdx ]); }
                else { bs_write_u(b, 1, mb->prev_intra8x8_pred_mode_flag[ luma8x8BlkIdx ]); }
                if( !mb->prev_intra8x8_pred_mode_flag[ luma8x8BlkIdx ] )
                {
                    if (cabac) { bs_write_ae(b, mb->rem_intra8x8_pred_mode[ luma8x8BlkIdx ]); }
                    else { bs_write_u(b, 3, mb->rem_intra8x8_pred_mode[ luma8x8BlkIdx ]); }
                }
            }
        }
        if( h->sps->chroma_format_idc != 0 )
        {
            if (cabac) { bs_write_ae(b, mb->intra_chroma_pred_mode); }
            else { bs_write_ue(b, mb->intra_chroma_pred_mode); }
        }
    }
    else if( MbPartPredMode( mb->mb_type, 0 ) != Direct )
    {
        for( int mbPartIdx = 0; mbPartIdx < NumMbPart( mb->mb_type ); mbPartIdx++)
        {
            if( ( h->pps->num_ref_idx_l0_active_minus1 > 0 ||
                  mb->mb_field_decoding_flag ) &&
                MbPartPredMode( mb->mb_type, mbPartIdx ) != Pred_L1 )
            {
                if (cabac) { bs_write_ae(b, mb->ref_idx_l0[ mbPartIdx ]); }
                else { bs_write_te(b, mb->ref_idx_l0[ mbPartIdx ]); }
            }
        }
        for( int mbPartIdx = 0; mbPartIdx < NumMbPart( mb->mb_type ); mbPartIdx++)
        {
            if( ( h->pps->num_ref_idx_l1_active_minus1 > 0 ||
                  mb->mb_field_decoding_flag ) &&
                MbPartPredMode( mb->mb_type, mbPartIdx ) != Pred_L0 )
            {
                if (cabac) { bs_write_ae(b, mb->ref_idx_l1[ mbPartIdx ]); }
                else { bs_write_te(b, mb->ref_idx_l1[ mbPartIdx ]); }
            }
        }
        for( int mbPartIdx = 0; mbPartIdx < NumMbPart( mb->mb_type ); mbPartIdx++)
        {
            if( MbPartPredMode ( mb->mb_type, mbPartIdx ) != Pred_L1 )
            {
                for( int compIdx = 0; compIdx < 2; compIdx++ )
                {
                    if (cabac) { bs_write_ae(b, mb->mvd_l0[ mbPartIdx ][ 0 ][ compIdx ]); }
                    else { bs_write_se(b, mb->mvd_l0[ mbPartIdx ][ 0 ][ compIdx ]); }
                }
            }
        }
        for( int mbPartIdx = 0; mbPartIdx < NumMbPart( mb->mb_type ); mbPartIdx++)
        {
            if( MbPartPredMode( mb->mb_type, mbPartIdx ) != Pred_L0 )
            {
                for( int compIdx = 0; compIdx < 2; compIdx++ )
                {
                    if (cabac) { bs_write_ae(b, mb->mvd_l1[ mbPartIdx ][ 0 ][ compIdx ]); }
                    else { bs_write_se(b, mb->mvd_l1[ mbPartIdx ][ 0 ][ compIdx ]); }
                }
            }
        }
    }
}

//7.3.5.2  Sub-macroblock prediction syntax
void write_sub_mb_pred( h264_stream_t* h, bs_t* b, int mb_type )
{
    macroblock_t* mb;

    for( int mbPartIdx = 0; mbPartIdx < 4; mbPartIdx++ )
    {
        if (cabac) { bs_write_ae(b, mb->sub_mb_type[ mbPartIdx ]); }
        else { bs_write_ue(b, mb->sub_mb_type[ mbPartIdx ]); }
    }
    for( int mbPartIdx = 0; mbPartIdx < 4; mbPartIdx++ )
    {
        if( ( h->pps->num_ref_idx_l0_active_minus1 > 0 || mb->mb_field_decoding_flag ) &&
            mb->mb_type != P_8x8ref0 &&
            mb->sub_mb_type[ mbPartIdx ] != B_Direct_8x8 &&
            SubMbPredMode( mb->sub_mb_type[ mbPartIdx ] ) != Pred_L1 )
        {
            if (cabac) { bs_write_ae(b, mb->ref_idx_l0[ mbPartIdx ]); }
            else { bs_write_te(b, mb->ref_idx_l0[ mbPartIdx ]); }
        }
    }
    for( int mbPartIdx = 0; mbPartIdx < 4; mbPartIdx++ )
    {
        if( (h->pps->num_ref_idx_l1_active_minus1 > 0 || mb->mb_field_decoding_flag ) &&
            mb->sub_mb_type[ mbPartIdx ] != B_Direct_8x8 &&
            SubMbPredMode( mb->sub_mb_type[ mbPartIdx ] ) != Pred_L0 )
        {
            if (cabac) { bs_write_ae(b, mb->ref_idx_l1[ mbPartIdx ]); }
            else { bs_write_te(b, mb->ref_idx_l1[ mbPartIdx ]); }
        }
    }
    for( int mbPartIdx = 0; mbPartIdx < 4; mbPartIdx++ )
    {
        if( mb->sub_mb_type[ mbPartIdx ] != B_Direct_8x8 &&
            SubMbPredMode( mb->sub_mb_type[ mbPartIdx ] ) != Pred_L1 )
        {
            for( int subMbPartIdx = 0;
                 subMbPartIdx < NumSubMbPart( mb->sub_mb_type[ mbPartIdx ] );
                 subMbPartIdx++)
            {
                for( int compIdx = 0; compIdx < 2; compIdx++ )
                {
                    if (cabac) { bs_write_ae(b, mb->mvd_l0[ mbPartIdx ][ subMbPartIdx ][ compIdx ]); }
                    else { bs_write_se(b, mb->mvd_l0[ mbPartIdx ][ subMbPartIdx ][ compIdx ]); }
                }
            }
        }
    }
    for( int mbPartIdx = 0; mbPartIdx < 4; mbPartIdx++ )
    {
        if( mb->sub_mb_type[ mbPartIdx ] != B_Direct_8x8 &&
            SubMbPredMode( mb->sub_mb_type[ mbPartIdx ] ) != Pred_L0 )
        {
            for( int subMbPartIdx = 0;
                 subMbPartIdx < NumSubMbPart( mb->sub_mb_type[ mbPartIdx ] );
                 subMbPartIdx++)
            {
                for( int compIdx = 0; compIdx < 2; compIdx++ )
                {
                    if (cabac) { bs_write_ae(b, mb->mvd_l1[ mbPartIdx ][ subMbPartIdx ][ compIdx ]); }
                    else { bs_write_se(b, mb->mvd_l1[ mbPartIdx ][ subMbPartIdx ][ compIdx ]); }
                }
            }
        }
    }
}

//7.3.5.3 Residual data syntax
void write_residual( h264_stream_t* h, bs_t* b )
{
    macroblock_t* mb;

/*
    if( !h->pps->entropy_coding_mode_flag )
    {
        residual_block = residual_block_cavlc;
    }
    else
    {
        residual_block = residual_block_cabac;
    }
*/
    // FIXME
#define read_residual_block read_residual_block_cavlc

    if( MbPartPredMode( mb->mb_type, 0 ) == Intra_16x16 )
    {
        write_residual_block( b, mb->Intra16x16DCLevel, 16 );
    }
    for( int i8x8 = 0; i8x8 < 4; i8x8++ ) // each luma 8x8 block
    {
        if( !mb->transform_size_8x8_flag || !h->pps->entropy_coding_mode_flag )
        {
            for( int i4x4 = 0; i4x4 < 4; i4x4++ ) // each 4x4 sub-block of block
            {
                if( CodedBlockPatternLuma & ( 1 << i8x8 ) )
                {
                    if( MbPartPredMode( mb->mb_type, 0 ) == Intra_16x16 )
                    {
                        write_residual_block( b, mb->Intra16x16ACLevel[ i8x8 * 4 + i4x4 ], 15 );
                    }
                    else
                    {
                        write_residual_block( b, mb->LumaLevel[ i8x8 * 4 + i4x4 ], 16 );
                    }
                }
                else if( MbPartPredMode( mb->mb_type, 0 ) == Intra_16x16 )
                {
                    for( int i = 0; i < 15; i++ )
                    {
                        mb->Intra16x16ACLevel[ i8x8 * 4 + i4x4 ][ i ] = 0;
                    }
                }
                else
                {
                    for( int i = 0; i < 16; i++ )
                    {
                        mb->LumaLevel[ i8x8 * 4 + i4x4 ][ i ] = 0;
                    }
                }
                if( !h->pps->entropy_coding_mode_flag && mb->transform_size_8x8_flag )
                {
                    for( int i = 0; i < 16; i++ )
                    {
                        mb->LumaLevel8x8[ i8x8 ][ 4 * i + i4x4 ] = mb->LumaLevel[ i8x8 * 4 + i4x4 ][ i ];
                    }
                }
            }
        }
        else if( CodedBlockPatternLuma & ( 1 << i8x8 ) )
        {
            write_residual_block( b, mb->LumaLevel8x8[ i8x8 ], 64 );
        }
        else
        {
            for( int i = 0; i < 64; i++ )
            {
                mb->LumaLevel8x8[ i8x8 ][ i ] = 0;
            }
        }
    }
    if( h->sps->chroma_format_idc != 0 )
    {
        int NumC8x8 = 4 / ( SubWidthC * SubHeightC );
        for( int iCbCr = 0; iCbCr < 2; iCbCr++ )
        {
            if( CodedBlockPatternChroma & 3 ) // chroma DC residual present
            {
                write_residual_block( b, mb->ChromaDCLevel[ iCbCr ], 4 * NumC8x8 );
            }
            else
            {
                for( int i = 0; i < 4 * NumC8x8; i++ )
                {
                    mb->ChromaDCLevel[ iCbCr ][ i ] = 0;
                }
            }
        }
        for( int iCbCr = 0; iCbCr < 2; iCbCr++ )
        {
            for( int i8x8 = 0; i8x8 < NumC8x8; i8x8++ )
            {
                for( int i4x4 = 0; i4x4 < 4; i4x4++ )
                {
                    if( CodedBlockPatternChroma & 2 )  // chroma AC residual present
                    {
                        write_residual_block( b, mb->ChromaACLevel[ iCbCr ][ i8x8*4+i4x4 ], 15);
                    }
                    else
                    {
                        for( int i = 0; i < 15; i++ )
                        {
                            mb->ChromaACLevel[ iCbCr ][ i8x8*4+i4x4 ][ i ] = 0;
                        }
                    }
                }
            }
        }
    }

}


//7.3.5.3.1 Residual block CAVLC syntax
void write_residual_block_cavlc( bs_t* b, int* coeffLevel, int maxNumCoeff )
{
    int level[256];
    int run[256];
    for( int i = 0; i < maxNumCoeff; i++ )
    {
        coeffLevel[ i ] = 0;
    }
    int coeff_token;
    bs_write_ce(b, coeff_token);
    int suffixLength;
    if( TotalCoeff( coeff_token ) > 0 )
    {
        if( TotalCoeff( coeff_token ) > 10 && TrailingOnes( coeff_token ) < 3 )
        {
            suffixLength = 1;
        }
        else
        {
            suffixLength = 0;
        }
        for( int i = 0; i < TotalCoeff( coeff_token ); i++ )
        {
            if( i < TrailingOnes( coeff_token ) )
            {
                int trailing_ones_sign_flag;
                bs_write_u(b, 1, trailing_ones_sign_flag);
                level[ i ] = 1 - 2 * trailing_ones_sign_flag;
            }
            else
            {
                int level_prefix;
                bs_write_ce(b, level_prefix);
                int levelCode;
                levelCode = ( Min( 15, level_prefix ) << suffixLength );
                if( suffixLength > 0 || level_prefix >= 14 )
                {
                    int level_suffix;
                    // ERROR: value( level_suffix, u ); // FIXME
                    levelCode += level_suffix;
                }
                if( level_prefix >= 15 && suffixLength == 0 )
                {
                    levelCode += 15;
                }
                if( level_prefix >= 16 )
                {
                    levelCode += ( 1 << ( level_prefix - 3 ) ) - 4096;
                }
                if( i == TrailingOnes( coeff_token ) &&
                    TrailingOnes( coeff_token ) < 3 )
                {
                    levelCode += 2;
                }
                if( levelCode % 2 == 0 )
                {
                    level[ i ] = ( levelCode + 2 ) >> 1;
                }
                else
                {
                    level[ i ] = ( -levelCode - 1 ) >> 1;
                }
                if( suffixLength == 0 )
                {
                    suffixLength = 1;
                }
                if( Abs( level[ i ] ) > ( 3 << ( suffixLength - 1 ) ) &&
                    suffixLength < 6 )
                {
                    suffixLength++;
                }
            }
        }
    int zerosLeft;
        if( TotalCoeff( coeff_token ) < maxNumCoeff )
        {
            int total_zeros;
            bs_write_ce(b, total_zeros);
            zerosLeft = total_zeros;
        } else
        {
            zerosLeft = 0;
        }
        for( int i = 0; i < TotalCoeff( coeff_token ) - 1; i++ )
        {
            if( zerosLeft > 0 )
            {
                int run_before;
                bs_write_ce(b, run_before);
                run[ i ] = run_before;
            } else
            {
                run[ i ] = 0;
            }
            zerosLeft = zerosLeft - run[ i ];
        }
        run[ TotalCoeff( coeff_token ) - 1 ] = zerosLeft;
        int coeffNum = -1;

        for( int i = TotalCoeff( coeff_token ) - 1; i >= 0; i-- )
        {
            coeffNum += run[ i ] + 1;
            coeffLevel[ coeffNum ] = level[ i ];
        }
    }
}


#ifdef HAVE_CABAC
//7.3.5.3.2 Residual block CABAC syntax
void write_residual_block_cabac( bs_t* b, int* coeffLevel, int maxNumCoeff )
{
    if( maxNumCoeff == 64 )
    {
        coded_block_flag = 1;
    }
    else
    {
        bs_write_ae(b, coded_block_flag);
    }
    if( coded_block_flag )
    {
        numCoeff = maxNumCoeff;
        int i=0;
        do
        {
            bs_write_ae(b, significant_coeff_flag[ i ]);
            if( significant_coeff_flag[ i ] )
            {
                bs_write_ae(b, last_significant_coeff_flag[ i ]);
                if( last_significant_coeff_flag[ i ] )
                {
                    numCoeff = i + 1;
                    for( int j = numCoeff; j < maxNumCoeff; j++ )
                    {
                        coeffLevel[ j ] = 0;
                    }
                }
            }
            i++;
        } while( i < numCoeff - 1 );

        bs_write_ae(b, coeff_abs_level_minus1[ numCoeff - 1 ]);
        bs_write_ae(b, coeff_sign_flag[ numCoeff - 1 ]);
        coeffLevel[ numCoeff - 1 ] =
            ( coeff_abs_level_minus1[ numCoeff - 1 ] + 1 ) *
            ( 1 - 2 * coeff_sign_flag[ numCoeff - 1 ] );
        for( int i = numCoeff - 2; i >= 0; i-- )
        {
            if( significant_coeff_flag[ i ] )
            {
                bs_write_ae(b, coeff_abs_level_minus1[ i ]);
                bs_write_ae(b, coeff_sign_flag[ i ]);
                coeffLevel[ i ] = ( coeff_abs_level_minus1[ i ] + 1 ) *
                    ( 1 - 2 * coeff_sign_flag[ i ] );
            }
            else
            {
                coeffLevel[ i ] = 0;
            }
        }
    }
    else
    {
        for( int i = 0; i < maxNumCoeff; i++ )
        {
            coeffLevel[ i ] = 0;
        }
    }
}

#endif


void read_debug_slice_data( h264_stream_t* h, bs_t* b );
void read_debug_macroblock_layer( h264_stream_t* h, bs_t* b );
void read_debug_mb_pred( h264_stream_t* h, bs_t* b, int mb_type );
void read_debug_sub_mb_pred( h264_stream_t* h, bs_t* b, int mb_type );
void read_debug_residual( h264_stream_t* h, bs_t* b );
void read_debug_residual_block_cavlc( bs_t* b, int* coeffLevel, int maxNumCoeff );
void read_debug_residual_block_cabac( bs_t* b, int* coeffLevel, int maxNumCoeff );


//7.3.4 Slice data syntax
void read_debug_slice_data( h264_stream_t* h, bs_t* b )
{
    macroblock_t* mb;
    if( h->pps->entropy_coding_mode_flag )
    {
        while( !bs_byte_aligned(b) )
        {
            printf("%d.%d: ", b->p - b->start, b->bits_left); int cabac_alignment_one_bit = bs_read_u(b, 1); printf("cabac_alignment_one_bit: %d \n", cabac_alignment_one_bit); 
        }
    }
    int CurrMbAddr = h->sh->first_mb_in_slice * ( 1 + MbaffFrameFlag );
    int moreDataFlag = 1;
    int prevMbSkipped = 0;
    do
    {
        int mb_skip_flag;
        int mb_skip_run;
        if( h->sh->slice_type != SH_SLICE_TYPE_I && h->sh->slice_type != SH_SLICE_TYPE_SI )
        {
            if( !h->pps->entropy_coding_mode_flag )
            {
                printf("%d.%d: ", b->p - b->start, b->bits_left); mb_skip_run = bs_read_ue(b); printf("mb_skip_run: %d \n", mb_skip_run); 
                prevMbSkipped = ( mb_skip_run > 0 );
                for( int i=0; i<mb_skip_run; i++ )
                {
                    CurrMbAddr = NextMbAddress( CurrMbAddr );
                }
                moreDataFlag = more_rbsp_data( );
            }
            else
            {
                printf("%d.%d: ", b->p - b->start, b->bits_left); mb_skip_flag = bs_read_ae(b); printf("mb_skip_flag: %d \n", mb_skip_flag); 
                moreDataFlag = !mb_skip_flag;
            }
        }
        if( moreDataFlag )
        {
            if( MbaffFrameFlag && ( CurrMbAddr % 2 == 0 ||
                                    ( CurrMbAddr % 2 == 1 && prevMbSkipped ) ) )
            {
                printf("%d.%d: ", b->p - b->start, b->bits_left); if (cabac) { mb->mb_field_decoding_flag = bs_read_ae(b); }
                else { mb->mb_field_decoding_flag = bs_read_u(b, 1); } printf("mb->mb_field_decoding_flag: %d \n", mb->mb_field_decoding_flag); 
            }
            read_debug_macroblock_layer( h, b );
        }
        if( !h->pps->entropy_coding_mode_flag )
        {
            moreDataFlag = more_rbsp_data( );
        }
        else
        {
        if( h->sh->slice_type != SH_SLICE_TYPE_I && h->sh->slice_type != SH_SLICE_TYPE_SI )
            {
                prevMbSkipped = mb_skip_flag;
            }
            if( MbaffFrameFlag && CurrMbAddr % 2 == 0 )
            {
                moreDataFlag = 1;
            }
            else
            {
                int end_of_slice_flag;
                printf("%d.%d: ", b->p - b->start, b->bits_left); end_of_slice_flag = bs_read_ae(b); printf("end_of_slice_flag: %d \n", end_of_slice_flag); 
                moreDataFlag = !end_of_slice_flag;
            }
        }
        CurrMbAddr = NextMbAddress( CurrMbAddr );
    } while( moreDataFlag );
}


//7.3.5 Macroblock layer syntax
void read_debug_macroblock_layer( h264_stream_t* h, bs_t* b )
{
    macroblock_t* mb;
    printf("%d.%d: ", b->p - b->start, b->bits_left); if (cabac) { mb->mb_type = bs_read_ae(b); }
    else { mb->mb_type = bs_read_ue(b); } printf("mb->mb_type: %d \n", mb->mb_type); 
    if( mb->mb_type == I_PCM )
    {
        while( !bs_byte_aligned(b) )
        {
            printf("%d.%d: ", b->p - b->start, b->bits_left); // ERROR: value( pcm_alignment_zero_bit, f(1) ); printf("pcm_alignment_zero_bit: %d \n", pcm_alignment_zero_bit); 
        }
        for( int i = 0; i < 256; i++ )
        {
            printf("%d.%d: ", b->p - b->start, b->bits_left); mb->pcm_sample_luma[ i ] = bs_read_u8(b); printf("mb->pcm_sample_luma[ i ]: %d \n", mb->pcm_sample_luma[ i ]); 
        }
        for( int i = 0; i < 2 * MbWidthC * MbHeightC; i++ )
        {
            printf("%d.%d: ", b->p - b->start, b->bits_left); mb->pcm_sample_chroma[ i ] = bs_read_u8(b); printf("mb->pcm_sample_chroma[ i ]: %d \n", mb->pcm_sample_chroma[ i ]); 
        }
    }
    else
    {
        int noSubMbPartSizeLessThan8x8Flag = 1;
        if( mb->mb_type != I_NxN &&
            MbPartPredMode( mb->mb_type, 0 ) != Intra_16x16 &&
            NumMbPart( mb->mb_type ) == 4 )
        {
            read_debug_sub_mb_pred( h, b, mb->mb_type );
            for( int mbPartIdx = 0; mbPartIdx < 4; mbPartIdx++ )
            {
                if( mb->sub_mb_type[ mbPartIdx ] != B_Direct_8x8 )
                {
                    if( NumSubMbPart( mb->sub_mb_type[ mbPartIdx ] ) > 1 )
                    {
                        noSubMbPartSizeLessThan8x8Flag = 0;
                    }
                }
                else if( !h->sps->direct_8x8_inference_flag )
                {
                    noSubMbPartSizeLessThan8x8Flag = 0;
                }
            }
        }
        else
        {
            if( h->pps->transform_8x8_mode_flag && mb->mb_type == I_NxN )
            {
                printf("%d.%d: ", b->p - b->start, b->bits_left); if (cabac) { mb->transform_size_8x8_flag = bs_read_ae(b); }
                else { mb->transform_size_8x8_flag = bs_read_u(b, 1); } printf("mb->transform_size_8x8_flag: %d \n", mb->transform_size_8x8_flag); 
            }
            read_debug_mb_pred( h, b, mb->mb_type );
        }
        if( MbPartPredMode( mb->mb_type, 0 ) != Intra_16x16 )
        {
            printf("%d.%d: ", b->p - b->start, b->bits_left); if (cabac) { mb->coded_block_pattern = bs_read_ae(b); }
            else { mb->coded_block_pattern = bs_read_me(b); } printf("mb->coded_block_pattern: %d \n", mb->coded_block_pattern); 
            if( CodedBlockPatternLuma > 0 &&
                h->pps->transform_8x8_mode_flag && mb->mb_type != I_NxN &&
                noSubMbPartSizeLessThan8x8Flag &&
                ( mb->mb_type != B_Direct_16x16 || h->sps->direct_8x8_inference_flag ) )
            {
                printf("%d.%d: ", b->p - b->start, b->bits_left); if (cabac) { mb->transform_size_8x8_flag = bs_read_ae(b); }
                else { mb->transform_size_8x8_flag = bs_read_u(b, 1); } printf("mb->transform_size_8x8_flag: %d \n", mb->transform_size_8x8_flag); 
            }
        }
        if( CodedBlockPatternLuma > 0 || CodedBlockPatternChroma > 0 ||
            MbPartPredMode( mb->mb_type, 0 ) == Intra_16x16 )
        {
            printf("%d.%d: ", b->p - b->start, b->bits_left); if (cabac) { mb->mb_qp_delta = bs_read_ae(b); }
            else { mb->mb_qp_delta = bs_read_se(b); } printf("mb->mb_qp_delta: %d \n", mb->mb_qp_delta); 
            read_debug_residual( h, b );
        }
    }
}

//7.3.5.1 Macroblock prediction syntax
void read_debug_mb_pred( h264_stream_t* h, bs_t* b, int mb_type )
{
    macroblock_t* mb;

    if( MbPartPredMode( mb->mb_type, 0 ) == Intra_4x4 ||
        MbPartPredMode( mb->mb_type, 0 ) == Intra_8x8 ||
        MbPartPredMode( mb->mb_type, 0 ) == Intra_16x16 )
    {
        if( MbPartPredMode( mb->mb_type, 0 ) == Intra_4x4 )
        {
            for( int luma4x4BlkIdx=0; luma4x4BlkIdx<16; luma4x4BlkIdx++ )
            {
                printf("%d.%d: ", b->p - b->start, b->bits_left); if (cabac) { mb->prev_intra4x4_pred_mode_flag[ luma4x4BlkIdx ] = bs_read_ae(b); }
                else { mb->prev_intra4x4_pred_mode_flag[ luma4x4BlkIdx ] = bs_read_u(b, 1); } printf("mb->prev_intra4x4_pred_mode_flag[ luma4x4BlkIdx ]: %d \n", mb->prev_intra4x4_pred_mode_flag[ luma4x4BlkIdx ]); 
                if( !mb->prev_intra4x4_pred_mode_flag[ luma4x4BlkIdx ] )
                {
                    printf("%d.%d: ", b->p - b->start, b->bits_left); if (cabac) { mb->rem_intra4x4_pred_mode[ luma4x4BlkIdx ] = bs_read_ae(b); }
                    else { mb->rem_intra4x4_pred_mode[ luma4x4BlkIdx ] = bs_read_u(b, 3); } printf("mb->rem_intra4x4_pred_mode[ luma4x4BlkIdx ]: %d \n", mb->rem_intra4x4_pred_mode[ luma4x4BlkIdx ]); 
                }
            }
        }
        if( MbPartPredMode( mb->mb_type, 0 ) == Intra_8x8 )
        {
            for( int luma8x8BlkIdx=0; luma8x8BlkIdx<4; luma8x8BlkIdx++ )
            {
                printf("%d.%d: ", b->p - b->start, b->bits_left); if (cabac) { mb->prev_intra8x8_pred_mode_flag[ luma8x8BlkIdx ] = bs_read_ae(b); }
                else { mb->prev_intra8x8_pred_mode_flag[ luma8x8BlkIdx ] = bs_read_u(b, 1); } printf("mb->prev_intra8x8_pred_mode_flag[ luma8x8BlkIdx ]: %d \n", mb->prev_intra8x8_pred_mode_flag[ luma8x8BlkIdx ]); 
                if( !mb->prev_intra8x8_pred_mode_flag[ luma8x8BlkIdx ] )
                {
                    printf("%d.%d: ", b->p - b->start, b->bits_left); if (cabac) { mb->rem_intra8x8_pred_mode[ luma8x8BlkIdx ] = bs_read_ae(b); }
                    else { mb->rem_intra8x8_pred_mode[ luma8x8BlkIdx ] = bs_read_u(b, 3); } printf("mb->rem_intra8x8_pred_mode[ luma8x8BlkIdx ]: %d \n", mb->rem_intra8x8_pred_mode[ luma8x8BlkIdx ]); 
                }
            }
        }
        if( h->sps->chroma_format_idc != 0 )
        {
            printf("%d.%d: ", b->p - b->start, b->bits_left); if (cabac) { mb->intra_chroma_pred_mode = bs_read_ae(b); }
            else { mb->intra_chroma_pred_mode = bs_read_ue(b); } printf("mb->intra_chroma_pred_mode: %d \n", mb->intra_chroma_pred_mode); 
        }
    }
    else if( MbPartPredMode( mb->mb_type, 0 ) != Direct )
    {
        for( int mbPartIdx = 0; mbPartIdx < NumMbPart( mb->mb_type ); mbPartIdx++)
        {
            if( ( h->pps->num_ref_idx_l0_active_minus1 > 0 ||
                  mb->mb_field_decoding_flag ) &&
                MbPartPredMode( mb->mb_type, mbPartIdx ) != Pred_L1 )
            {
                printf("%d.%d: ", b->p - b->start, b->bits_left); if (cabac) { mb->ref_idx_l0[ mbPartIdx ] = bs_read_ae(b); }
                else { mb->ref_idx_l0[ mbPartIdx ] = bs_read_te(b); } printf("mb->ref_idx_l0[ mbPartIdx ]: %d \n", mb->ref_idx_l0[ mbPartIdx ]); 
            }
        }
        for( int mbPartIdx = 0; mbPartIdx < NumMbPart( mb->mb_type ); mbPartIdx++)
        {
            if( ( h->pps->num_ref_idx_l1_active_minus1 > 0 ||
                  mb->mb_field_decoding_flag ) &&
                MbPartPredMode( mb->mb_type, mbPartIdx ) != Pred_L0 )
            {
                printf("%d.%d: ", b->p - b->start, b->bits_left); if (cabac) { mb->ref_idx_l1[ mbPartIdx ] = bs_read_ae(b); }
                else { mb->ref_idx_l1[ mbPartIdx ] = bs_read_te(b); } printf("mb->ref_idx_l1[ mbPartIdx ]: %d \n", mb->ref_idx_l1[ mbPartIdx ]); 
            }
        }
        for( int mbPartIdx = 0; mbPartIdx < NumMbPart( mb->mb_type ); mbPartIdx++)
        {
            if( MbPartPredMode ( mb->mb_type, mbPartIdx ) != Pred_L1 )
            {
                for( int compIdx = 0; compIdx < 2; compIdx++ )
                {
                    printf("%d.%d: ", b->p - b->start, b->bits_left); if (cabac) { mb->mvd_l0[ mbPartIdx ][ 0 ][ compIdx ] = bs_read_ae(b); }
                    else { mb->mvd_l0[ mbPartIdx ][ 0 ][ compIdx ] = bs_read_se(b); } printf("mb->mvd_l0[ mbPartIdx ][ 0 ][ compIdx ]: %d \n", mb->mvd_l0[ mbPartIdx ][ 0 ][ compIdx ]); 
                }
            }
        }
        for( int mbPartIdx = 0; mbPartIdx < NumMbPart( mb->mb_type ); mbPartIdx++)
        {
            if( MbPartPredMode( mb->mb_type, mbPartIdx ) != Pred_L0 )
            {
                for( int compIdx = 0; compIdx < 2; compIdx++ )
                {
                    printf("%d.%d: ", b->p - b->start, b->bits_left); if (cabac) { mb->mvd_l1[ mbPartIdx ][ 0 ][ compIdx ] = bs_read_ae(b); }
                    else { mb->mvd_l1[ mbPartIdx ][ 0 ][ compIdx ] = bs_read_se(b); } printf("mb->mvd_l1[ mbPartIdx ][ 0 ][ compIdx ]: %d \n", mb->mvd_l1[ mbPartIdx ][ 0 ][ compIdx ]); 
                }
            }
        }
    }
}

//7.3.5.2  Sub-macroblock prediction syntax
void read_debug_sub_mb_pred( h264_stream_t* h, bs_t* b, int mb_type )
{
    macroblock_t* mb;

    for( int mbPartIdx = 0; mbPartIdx < 4; mbPartIdx++ )
    {
        printf("%d.%d: ", b->p - b->start, b->bits_left); if (cabac) { mb->sub_mb_type[ mbPartIdx ] = bs_read_ae(b); }
        else { mb->sub_mb_type[ mbPartIdx ] = bs_read_ue(b); } printf("mb->sub_mb_type[ mbPartIdx ]: %d \n", mb->sub_mb_type[ mbPartIdx ]); 
    }
    for( int mbPartIdx = 0; mbPartIdx < 4; mbPartIdx++ )
    {
        if( ( h->pps->num_ref_idx_l0_active_minus1 > 0 || mb->mb_field_decoding_flag ) &&
            mb->mb_type != P_8x8ref0 &&
            mb->sub_mb_type[ mbPartIdx ] != B_Direct_8x8 &&
            SubMbPredMode( mb->sub_mb_type[ mbPartIdx ] ) != Pred_L1 )
        {
            printf("%d.%d: ", b->p - b->start, b->bits_left); if (cabac) { mb->ref_idx_l0[ mbPartIdx ] = bs_read_ae(b); }
            else { mb->ref_idx_l0[ mbPartIdx ] = bs_read_te(b); } printf("mb->ref_idx_l0[ mbPartIdx ]: %d \n", mb->ref_idx_l0[ mbPartIdx ]); 
        }
    }
    for( int mbPartIdx = 0; mbPartIdx < 4; mbPartIdx++ )
    {
        if( (h->pps->num_ref_idx_l1_active_minus1 > 0 || mb->mb_field_decoding_flag ) &&
            mb->sub_mb_type[ mbPartIdx ] != B_Direct_8x8 &&
            SubMbPredMode( mb->sub_mb_type[ mbPartIdx ] ) != Pred_L0 )
        {
            printf("%d.%d: ", b->p - b->start, b->bits_left); if (cabac) { mb->ref_idx_l1[ mbPartIdx ] = bs_read_ae(b); }
            else { mb->ref_idx_l1[ mbPartIdx ] = bs_read_te(b); } printf("mb->ref_idx_l1[ mbPartIdx ]: %d \n", mb->ref_idx_l1[ mbPartIdx ]); 
        }
    }
    for( int mbPartIdx = 0; mbPartIdx < 4; mbPartIdx++ )
    {
        if( mb->sub_mb_type[ mbPartIdx ] != B_Direct_8x8 &&
            SubMbPredMode( mb->sub_mb_type[ mbPartIdx ] ) != Pred_L1 )
        {
            for( int subMbPartIdx = 0;
                 subMbPartIdx < NumSubMbPart( mb->sub_mb_type[ mbPartIdx ] );
                 subMbPartIdx++)
            {
                for( int compIdx = 0; compIdx < 2; compIdx++ )
                {
                    printf("%d.%d: ", b->p - b->start, b->bits_left); if (cabac) { mb->mvd_l0[ mbPartIdx ][ subMbPartIdx ][ compIdx ] = bs_read_ae(b); }
                    else { mb->mvd_l0[ mbPartIdx ][ subMbPartIdx ][ compIdx ] = bs_read_se(b); } printf("mb->mvd_l0[ mbPartIdx ][ subMbPartIdx ][ compIdx ]: %d \n", mb->mvd_l0[ mbPartIdx ][ subMbPartIdx ][ compIdx ]); 
                }
            }
        }
    }
    for( int mbPartIdx = 0; mbPartIdx < 4; mbPartIdx++ )
    {
        if( mb->sub_mb_type[ mbPartIdx ] != B_Direct_8x8 &&
            SubMbPredMode( mb->sub_mb_type[ mbPartIdx ] ) != Pred_L0 )
        {
            for( int subMbPartIdx = 0;
                 subMbPartIdx < NumSubMbPart( mb->sub_mb_type[ mbPartIdx ] );
                 subMbPartIdx++)
            {
                for( int compIdx = 0; compIdx < 2; compIdx++ )
                {
                    printf("%d.%d: ", b->p - b->start, b->bits_left); if (cabac) { mb->mvd_l1[ mbPartIdx ][ subMbPartIdx ][ compIdx ] = bs_read_ae(b); }
                    else { mb->mvd_l1[ mbPartIdx ][ subMbPartIdx ][ compIdx ] = bs_read_se(b); } printf("mb->mvd_l1[ mbPartIdx ][ subMbPartIdx ][ compIdx ]: %d \n", mb->mvd_l1[ mbPartIdx ][ subMbPartIdx ][ compIdx ]); 
                }
            }
        }
    }
}

//7.3.5.3 Residual data syntax
void read_debug_residual( h264_stream_t* h, bs_t* b )
{
    macroblock_t* mb;

/*
    if( !h->pps->entropy_coding_mode_flag )
    {
        residual_block = residual_block_cavlc;
    }
    else
    {
        residual_block = residual_block_cabac;
    }
*/
    // FIXME
#define read_residual_block read_residual_block_cavlc

    if( MbPartPredMode( mb->mb_type, 0 ) == Intra_16x16 )
    {
        read_debug_residual_block( b, mb->Intra16x16DCLevel, 16 );
    }
    for( int i8x8 = 0; i8x8 < 4; i8x8++ ) // each luma 8x8 block
    {
        if( !mb->transform_size_8x8_flag || !h->pps->entropy_coding_mode_flag )
        {
            for( int i4x4 = 0; i4x4 < 4; i4x4++ ) // each 4x4 sub-block of block
            {
                if( CodedBlockPatternLuma & ( 1 << i8x8 ) )
                {
                    if( MbPartPredMode( mb->mb_type, 0 ) == Intra_16x16 )
                    {
                        read_debug_residual_block( b, mb->Intra16x16ACLevel[ i8x8 * 4 + i4x4 ], 15 );
                    }
                    else
                    {
                        read_debug_residual_block( b, mb->LumaLevel[ i8x8 * 4 + i4x4 ], 16 );
                    }
                }
                else if( MbPartPredMode( mb->mb_type, 0 ) == Intra_16x16 )
                {
                    for( int i = 0; i < 15; i++ )
                    {
                        mb->Intra16x16ACLevel[ i8x8 * 4 + i4x4 ][ i ] = 0;
                    }
                }
                else
                {
                    for( int i = 0; i < 16; i++ )
                    {
                        mb->LumaLevel[ i8x8 * 4 + i4x4 ][ i ] = 0;
                    }
                }
                if( !h->pps->entropy_coding_mode_flag && mb->transform_size_8x8_flag )
                {
                    for( int i = 0; i < 16; i++ )
                    {
                        mb->LumaLevel8x8[ i8x8 ][ 4 * i + i4x4 ] = mb->LumaLevel[ i8x8 * 4 + i4x4 ][ i ];
                    }
                }
            }
        }
        else if( CodedBlockPatternLuma & ( 1 << i8x8 ) )
        {
            read_debug_residual_block( b, mb->LumaLevel8x8[ i8x8 ], 64 );
        }
        else
        {
            for( int i = 0; i < 64; i++ )
            {
                mb->LumaLevel8x8[ i8x8 ][ i ] = 0;
            }
        }
    }
    if( h->sps->chroma_format_idc != 0 )
    {
        int NumC8x8 = 4 / ( SubWidthC * SubHeightC );
        for( int iCbCr = 0; iCbCr < 2; iCbCr++ )
        {
            if( CodedBlockPatternChroma & 3 ) // chroma DC residual present
            {
                read_debug_residual_block( b, mb->ChromaDCLevel[ iCbCr ], 4 * NumC8x8 );
            }
            else
            {
                for( int i = 0; i < 4 * NumC8x8; i++ )
                {
                    mb->ChromaDCLevel[ iCbCr ][ i ] = 0;
                }
            }
        }
        for( int iCbCr = 0; iCbCr < 2; iCbCr++ )
        {
            for( int i8x8 = 0; i8x8 < NumC8x8; i8x8++ )
            {
                for( int i4x4 = 0; i4x4 < 4; i4x4++ )
                {
                    if( CodedBlockPatternChroma & 2 )  // chroma AC residual present
                    {
                        read_debug_residual_block( b, mb->ChromaACLevel[ iCbCr ][ i8x8*4+i4x4 ], 15);
                    }
                    else
                    {
                        for( int i = 0; i < 15; i++ )
                        {
                            mb->ChromaACLevel[ iCbCr ][ i8x8*4+i4x4 ][ i ] = 0;
                        }
                    }
                }
            }
        }
    }

}


//7.3.5.3.1 Residual block CAVLC syntax
void read_debug_residual_block_cavlc( bs_t* b, int* coeffLevel, int maxNumCoeff )
{
    int level[256];
    int run[256];
    for( int i = 0; i < maxNumCoeff; i++ )
    {
        coeffLevel[ i ] = 0;
    }
    int coeff_token;
    printf("%d.%d: ", b->p - b->start, b->bits_left); coeff_token = bs_read_ce(b); printf("coeff_token: %d \n", coeff_token); 
    int suffixLength;
    if( TotalCoeff( coeff_token ) > 0 )
    {
        if( TotalCoeff( coeff_token ) > 10 && TrailingOnes( coeff_token ) < 3 )
        {
            suffixLength = 1;
        }
        else
        {
            suffixLength = 0;
        }
        for( int i = 0; i < TotalCoeff( coeff_token ); i++ )
        {
            if( i < TrailingOnes( coeff_token ) )
            {
                int trailing_ones_sign_flag;
                printf("%d.%d: ", b->p - b->start, b->bits_left); trailing_ones_sign_flag = bs_read_u(b, 1); printf("trailing_ones_sign_flag: %d \n", trailing_ones_sign_flag); 
                level[ i ] = 1 - 2 * trailing_ones_sign_flag;
            }
            else
            {
                int level_prefix;
                printf("%d.%d: ", b->p - b->start, b->bits_left); level_prefix = bs_read_ce(b); printf("level_prefix: %d \n", level_prefix); 
                int levelCode;
                levelCode = ( Min( 15, level_prefix ) << suffixLength );
                if( suffixLength > 0 || level_prefix >= 14 )
                {
                    int level_suffix;
                    printf("%d.%d: ", b->p - b->start, b->bits_left); // ERROR: value( level_suffix, u ); printf("level_suffix: %d \n", level_suffix);  // FIXME
                    levelCode += level_suffix;
                }
                if( level_prefix >= 15 && suffixLength == 0 )
                {
                    levelCode += 15;
                }
                if( level_prefix >= 16 )
                {
                    levelCode += ( 1 << ( level_prefix - 3 ) ) - 4096;
                }
                if( i == TrailingOnes( coeff_token ) &&
                    TrailingOnes( coeff_token ) < 3 )
                {
                    levelCode += 2;
                }
                if( levelCode % 2 == 0 )
                {
                    level[ i ] = ( levelCode + 2 ) >> 1;
                }
                else
                {
                    level[ i ] = ( -levelCode - 1 ) >> 1;
                }
                if( suffixLength == 0 )
                {
                    suffixLength = 1;
                }
                if( Abs( level[ i ] ) > ( 3 << ( suffixLength - 1 ) ) &&
                    suffixLength < 6 )
                {
                    suffixLength++;
                }
            }
        }
    int zerosLeft;
        if( TotalCoeff( coeff_token ) < maxNumCoeff )
        {
            int total_zeros;
            printf("%d.%d: ", b->p - b->start, b->bits_left); total_zeros = bs_read_ce(b); printf("total_zeros: %d \n", total_zeros); 
            zerosLeft = total_zeros;
        } else
        {
            zerosLeft = 0;
        }
        for( int i = 0; i < TotalCoeff( coeff_token ) - 1; i++ )
        {
            if( zerosLeft > 0 )
            {
                int run_before;
                printf("%d.%d: ", b->p - b->start, b->bits_left); run_before = bs_read_ce(b); printf("run_before: %d \n", run_before); 
                run[ i ] = run_before;
            } else
            {
                run[ i ] = 0;
            }
            zerosLeft = zerosLeft - run[ i ];
        }
        run[ TotalCoeff( coeff_token ) - 1 ] = zerosLeft;
        int coeffNum = -1;

        for( int i = TotalCoeff( coeff_token ) - 1; i >= 0; i-- )
        {
            coeffNum += run[ i ] + 1;
            coeffLevel[ coeffNum ] = level[ i ];
        }
    }
}


#ifdef HAVE_CABAC
//7.3.5.3.2 Residual block CABAC syntax
void read_debug_residual_block_cabac( bs_t* b, int* coeffLevel, int maxNumCoeff )
{
    if( maxNumCoeff == 64 )
    {
        coded_block_flag = 1;
    }
    else
    {
        printf("%d.%d: ", b->p - b->start, b->bits_left); coded_block_flag = bs_read_ae(b); printf("coded_block_flag: %d \n", coded_block_flag); 
    }
    if( coded_block_flag )
    {
        numCoeff = maxNumCoeff;
        int i=0;
        do
        {
            printf("%d.%d: ", b->p - b->start, b->bits_left); significant_coeff_flag[ i ] = bs_read_ae(b); printf("significant_coeff_flag[ i ]: %d \n", significant_coeff_flag[ i ]); 
            if( significant_coeff_flag[ i ] )
            {
                printf("%d.%d: ", b->p - b->start, b->bits_left); last_significant_coeff_flag[ i ] = bs_read_ae(b); printf("last_significant_coeff_flag[ i ]: %d \n", last_significant_coeff_flag[ i ]); 
                if( last_significant_coeff_flag[ i ] )
                {
                    numCoeff = i + 1;
                    for( int j = numCoeff; j < maxNumCoeff; j++ )
                    {
                        coeffLevel[ j ] = 0;
                    }
                }
            }
            i++;
        } while( i < numCoeff - 1 );

        printf("%d.%d: ", b->p - b->start, b->bits_left); coeff_abs_level_minus1[ numCoeff - 1 ] = bs_read_ae(b); printf("coeff_abs_level_minus1[ numCoeff - 1 ]: %d \n", coeff_abs_level_minus1[ numCoeff - 1 ]); 
        printf("%d.%d: ", b->p - b->start, b->bits_left); coeff_sign_flag[ numCoeff - 1 ] = bs_read_ae(b); printf("coeff_sign_flag[ numCoeff - 1 ]: %d \n", coeff_sign_flag[ numCoeff - 1 ]); 
        coeffLevel[ numCoeff - 1 ] =
            ( coeff_abs_level_minus1[ numCoeff - 1 ] + 1 ) *
            ( 1 - 2 * coeff_sign_flag[ numCoeff - 1 ] );
        for( int i = numCoeff - 2; i >= 0; i-- )
        {
            if( significant_coeff_flag[ i ] )
            {
                printf("%d.%d: ", b->p - b->start, b->bits_left); coeff_abs_level_minus1[ i ] = bs_read_ae(b); printf("coeff_abs_level_minus1[ i ]: %d \n", coeff_abs_level_minus1[ i ]); 
                printf("%d.%d: ", b->p - b->start, b->bits_left); coeff_sign_flag[ i ] = bs_read_ae(b); printf("coeff_sign_flag[ i ]: %d \n", coeff_sign_flag[ i ]); 
                coeffLevel[ i ] = ( coeff_abs_level_minus1[ i ] + 1 ) *
                    ( 1 - 2 * coeff_sign_flag[ i ] );
            }
            else
            {
                coeffLevel[ i ] = 0;
            }
        }
    }
    else
    {
        for( int i = 0; i < maxNumCoeff; i++ )
        {
            coeffLevel[ i ] = 0;
        }
    }
}

#endif
