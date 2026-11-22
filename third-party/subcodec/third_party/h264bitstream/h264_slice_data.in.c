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

#end_preamble

#function_declarations

//7.3.4 Slice data syntax
void structure(slice_data)( h264_stream_t* h, bs_t* b )
{
    macroblock_t* mb;
    if( h->pps->entropy_coding_mode_flag )
    {
        while( !bs_byte_aligned(b) )
        {
            value( cabac_alignment_one_bit, f(1, 1) );
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
                value( mb_skip_run, ue );
                prevMbSkipped = ( mb_skip_run > 0 );
                for( int i=0; i<mb_skip_run; i++ )
                {
                    CurrMbAddr = NextMbAddress( CurrMbAddr );
                }
                moreDataFlag = more_rbsp_data( );
            }
            else
            {
                value( mb_skip_flag, ae );
                moreDataFlag = !mb_skip_flag;
            }
        }
        if( moreDataFlag )
        {
            if( MbaffFrameFlag && ( CurrMbAddr % 2 == 0 ||
                                    ( CurrMbAddr % 2 == 1 && prevMbSkipped ) ) )
            {
                value( mb->mb_field_decoding_flag, u(1), ae );
            }
            structure(macroblock_layer)( h, b );
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
                value( end_of_slice_flag, ae );
                moreDataFlag = !end_of_slice_flag;
            }
        }
        CurrMbAddr = NextMbAddress( CurrMbAddr );
    } while( moreDataFlag );
}


//7.3.5 Macroblock layer syntax
void structure(macroblock_layer)( h264_stream_t* h, bs_t* b )
{
    macroblock_t* mb;
    value( mb->mb_type, ue, ae );
    if( mb->mb_type == I_PCM )
    {
        while( !bs_byte_aligned(b) )
        {
            value( pcm_alignment_zero_bit, f(1) );
        }
        for( int i = 0; i < 256; i++ )
        {
            value( mb->pcm_sample_luma[ i ], u8 );
        }
        for( int i = 0; i < 2 * MbWidthC * MbHeightC; i++ )
        {
            value( mb->pcm_sample_chroma[ i ], u8 );
        }
    }
    else
    {
        int noSubMbPartSizeLessThan8x8Flag = 1;
        if( mb->mb_type != I_NxN &&
            MbPartPredMode( mb->mb_type, 0 ) != Intra_16x16 &&
            NumMbPart( mb->mb_type ) == 4 )
        {
            structure(sub_mb_pred)( h, b, mb->mb_type );
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
                value( mb->transform_size_8x8_flag, u(1), ae );
            }
            structure(mb_pred)( h, b, mb->mb_type );
        }
        if( MbPartPredMode( mb->mb_type, 0 ) != Intra_16x16 )
        {
            value( mb->coded_block_pattern, me, ae );
            if( CodedBlockPatternLuma > 0 &&
                h->pps->transform_8x8_mode_flag && mb->mb_type != I_NxN &&
                noSubMbPartSizeLessThan8x8Flag &&
                ( mb->mb_type != B_Direct_16x16 || h->sps->direct_8x8_inference_flag ) )
            {
                value( mb->transform_size_8x8_flag, u(1), ae );
            }
        }
        if( CodedBlockPatternLuma > 0 || CodedBlockPatternChroma > 0 ||
            MbPartPredMode( mb->mb_type, 0 ) == Intra_16x16 )
        {
            value( mb->mb_qp_delta, se, ae );
            structure(residual)( h, b );
        }
    }
}

//7.3.5.1 Macroblock prediction syntax
void structure(mb_pred)( h264_stream_t* h, bs_t* b, int mb_type )
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
                value( mb->prev_intra4x4_pred_mode_flag[ luma4x4BlkIdx ], u(1), ae );
                if( !mb->prev_intra4x4_pred_mode_flag[ luma4x4BlkIdx ] )
                {
                    value( mb->rem_intra4x4_pred_mode[ luma4x4BlkIdx ], u(3), ae );
                }
            }
        }
        if( MbPartPredMode( mb->mb_type, 0 ) == Intra_8x8 )
        {
            for( int luma8x8BlkIdx=0; luma8x8BlkIdx<4; luma8x8BlkIdx++ )
            {
                value( mb->prev_intra8x8_pred_mode_flag[ luma8x8BlkIdx ], u(1), ae );
                if( !mb->prev_intra8x8_pred_mode_flag[ luma8x8BlkIdx ] )
                {
                    value( mb->rem_intra8x8_pred_mode[ luma8x8BlkIdx ], u(3), ae );
                }
            }
        }
        if( h->sps->chroma_format_idc != 0 )
        {
            value( mb->intra_chroma_pred_mode, ue, ae );
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
                value( mb->ref_idx_l0[ mbPartIdx ], te, ae );
            }
        }
        for( int mbPartIdx = 0; mbPartIdx < NumMbPart( mb->mb_type ); mbPartIdx++)
        {
            if( ( h->pps->num_ref_idx_l1_active_minus1 > 0 ||
                  mb->mb_field_decoding_flag ) &&
                MbPartPredMode( mb->mb_type, mbPartIdx ) != Pred_L0 )
            {
                value( mb->ref_idx_l1[ mbPartIdx ], te, ae );
            }
        }
        for( int mbPartIdx = 0; mbPartIdx < NumMbPart( mb->mb_type ); mbPartIdx++)
        {
            if( MbPartPredMode ( mb->mb_type, mbPartIdx ) != Pred_L1 )
            {
                for( int compIdx = 0; compIdx < 2; compIdx++ )
                {
                    value( mb->mvd_l0[ mbPartIdx ][ 0 ][ compIdx ], se, ae );
                }
            }
        }
        for( int mbPartIdx = 0; mbPartIdx < NumMbPart( mb->mb_type ); mbPartIdx++)
        {
            if( MbPartPredMode( mb->mb_type, mbPartIdx ) != Pred_L0 )
            {
                for( int compIdx = 0; compIdx < 2; compIdx++ )
                {
                    value( mb->mvd_l1[ mbPartIdx ][ 0 ][ compIdx ], se, ae );
                }
            }
        }
    }
}

//7.3.5.2  Sub-macroblock prediction syntax
void structure(sub_mb_pred)( h264_stream_t* h, bs_t* b, int mb_type )
{
    macroblock_t* mb;

    for( int mbPartIdx = 0; mbPartIdx < 4; mbPartIdx++ )
    {
        value( mb->sub_mb_type[ mbPartIdx ], ue, ae );
    }
    for( int mbPartIdx = 0; mbPartIdx < 4; mbPartIdx++ )
    {
        if( ( h->pps->num_ref_idx_l0_active_minus1 > 0 || mb->mb_field_decoding_flag ) &&
            mb->mb_type != P_8x8ref0 &&
            mb->sub_mb_type[ mbPartIdx ] != B_Direct_8x8 &&
            SubMbPredMode( mb->sub_mb_type[ mbPartIdx ] ) != Pred_L1 )
        {
            value( mb->ref_idx_l0[ mbPartIdx ], te, ae );
        }
    }
    for( int mbPartIdx = 0; mbPartIdx < 4; mbPartIdx++ )
    {
        if( (h->pps->num_ref_idx_l1_active_minus1 > 0 || mb->mb_field_decoding_flag ) &&
            mb->sub_mb_type[ mbPartIdx ] != B_Direct_8x8 &&
            SubMbPredMode( mb->sub_mb_type[ mbPartIdx ] ) != Pred_L0 )
        {
            value( mb->ref_idx_l1[ mbPartIdx ], te, ae );
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
                    value( mb->mvd_l0[ mbPartIdx ][ subMbPartIdx ][ compIdx ], se, ae );
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
                    value( mb->mvd_l1[ mbPartIdx ][ subMbPartIdx ][ compIdx ], se, ae );
                }
            }
        }
    }
}

//7.3.5.3 Residual data syntax
void structure(residual)( h264_stream_t* h, bs_t* b )
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
        structure(residual_block)( b, mb->Intra16x16DCLevel, 16 );
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
                        structure(residual_block)( b, mb->Intra16x16ACLevel[ i8x8 * 4 + i4x4 ], 15 );
                    }
                    else
                    {
                        structure(residual_block)( b, mb->LumaLevel[ i8x8 * 4 + i4x4 ], 16 );
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
            structure(residual_block)( b, mb->LumaLevel8x8[ i8x8 ], 64 );
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
                structure(residual_block)( b, mb->ChromaDCLevel[ iCbCr ], 4 * NumC8x8 );
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
                        structure(residual_block)( b, mb->ChromaACLevel[ iCbCr ][ i8x8*4+i4x4 ], 15);
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
void structure(residual_block_cavlc)( bs_t* b, int* coeffLevel, int maxNumCoeff )
{
    int level[256];
    int run[256];
    for( int i = 0; i < maxNumCoeff; i++ )
    {
        coeffLevel[ i ] = 0;
    }
    int coeff_token;
    value( coeff_token, ce );
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
                value( trailing_ones_sign_flag, u(1) );
                level[ i ] = 1 - 2 * trailing_ones_sign_flag;
            }
            else
            {
                int level_prefix;
                value( level_prefix, ce );
                int levelCode;
                levelCode = ( Min( 15, level_prefix ) << suffixLength );
                if( suffixLength > 0 || level_prefix >= 14 )
                {
                    int level_suffix;
                    value( level_suffix, u ); // FIXME
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
            value( total_zeros, ce );
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
                value( run_before, ce );
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
void structure(residual_block_cabac)( bs_t* b, int* coeffLevel, int maxNumCoeff )
{
    if( maxNumCoeff == 64 )
    {
        coded_block_flag = 1;
    }
    else
    {
        value( coded_block_flag, ae);
    }
    if( coded_block_flag )
    {
        numCoeff = maxNumCoeff;
        int i=0;
        do
        {
            value( significant_coeff_flag[ i ], ae );
            if( significant_coeff_flag[ i ] )
            {
                value( last_significant_coeff_flag[ i ], ae );
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

        value( coeff_abs_level_minus1[ numCoeff - 1 ], ae );
        value( coeff_sign_flag[ numCoeff - 1 ], ae );
        coeffLevel[ numCoeff - 1 ] =
            ( coeff_abs_level_minus1[ numCoeff - 1 ] + 1 ) *
            ( 1 - 2 * coeff_sign_flag[ numCoeff - 1 ] );
        for( int i = numCoeff - 2; i >= 0; i-- )
        {
            if( significant_coeff_flag[ i ] )
            {
                value( coeff_abs_level_minus1[ i ], ae );
                value( coeff_sign_flag[ i ], ae );
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
