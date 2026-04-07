/* 
 * h264bitstream - a library for reading and writing H.264 video
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

typedef struct
{
    int mb_type;
    int sub_mb_type[4]; // [ mbPartIdx ]

    // pcm mb only
    int pcm_sample_luma[256];
    int pcm_sample_chroma[512];

    int transform_size_8x8_flag;
    int mb_qp_delta;
    int mb_field_decoding_flag;
    int mb_skip_flag;

    // intra mb only
    int prev_intra4x4_pred_mode_flag[16]; // [ luma4x4BlkIdx ]
    int rem_intra4x4_pred_mode[16]; // [ luma4x4BlkIdx ]
    int prev_intra8x8_pred_mode_flag[4]; // [ luma8x8BlkIdx ]
    int rem_intra8x8_pred_mode[4]; // [ luma8x8BlkIdx ]
    int intra_chroma_pred_mode;

    // inter mb only
    int ref_idx_l0[4]; // [ mbPartIdx ]
    int ref_idx_l1[4]; // [ mbPartIdx ]
    int mvd_l0[4][4][2]; // [ mbPartIdx ][ subMbPartIdx ][ compIdx ]
    int mvd_l1[4][4][2]; // [ mbPartIdx ][ subMbPartIdx ][ compIdx ]

    // residuals
    int coded_block_pattern;

    int Intra16x16DCLevel[16]; // [ 16 ]
    int Intra16x16ACLevel[16][15]; // [ i8x8 * 4 + i4x4 ][ 15 ]
    int LumaLevel[16][16]; // [ i8x8 * 4 + i4x4 ][ 16 ]
    int LumaLevel8x8[4][64]; // [ i8x8 ][ 64 ]
    int ChromaDCLevel[2][16]; // [ iCbCr ][ 4 * NumC8x8 ]
    int ChromaACLevel[2][16][15]; // [ iCbCr ][ i8x8*4+i4x4 ][ 15 ]

} macroblock_t;


typedef struct 
{
    macroblock_t* mbs;
} slice_t;


/****** bitstream functions - not already implemented ******/

uint32_t bs_read_te(bs_t* b);
void bs_write_te(bs_t* b, uint32_t v);
uint32_t bs_read_me(bs_t* b);
void bs_write_me(bs_t* b, uint32_t v);

// CABAC
// 9.3 CABAC parsing process for slice data
// NOTE: these functions will need more arguments, since how they work depends on *what* is being encoded/decoded
// for now, just a placeholder for places that we will need to call this from
uint32_t bs_read_ae(bs_t* b);
void bs_write_ae(bs_t* b, uint32_t v);

// CALVC
// 9.2 CAVLC parsing process for transform coefficient levels
uint32_t bs_read_ce(bs_t* b);
void bs_write_ce(bs_t* b, uint32_t v);

/****** dummy defines *****/

#define cabac 0

// values for mb_type
#define I_PCM 0
#define I_NxN 0
#define P_8x8ref0 0


// values for MbPartPredMode (and SubMbPredMode)
#define Intra_4x4 0
#define Intra_8x8 0
#define Intra_16x16 0
#define Direct 0
#define Pred_L0 0
#define Pred_L1 0

// values for sub_mb_type
#define B_Direct_8x8 0
#define B_Direct_16x16 0

#define MbWidthC 8
#define MbHeightC 8
#define SubWidthC 2
#define SubHeightC 2

int NextMbAddress( int CurrMbAddr );
int MbPartPredMode( int mb_type, int mbPartIdx );
int NumMbPart( int mb_type );
int NumSubMbPart( int sub_mb_type );
int SubMbPredMode( int sub_mb_type );
int TotalCoeff( int x );
int TrailingOnes( int x );
int Min( int a, int b );
int Abs( int x );

#define CodedBlockPatternLuma (mb->coded_block_pattern % 16)
#define CodedBlockPatternChroma (mb->coded_block_pattern / 16)

//7.4.3 Slice header semantics, Eq 7-23
#define MbaffFrameFlag ( h->sps->mb_adaptive_frame_field_flag && !h->sh->field_pic_flag )

