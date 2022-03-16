/*****************************************************************************
 * macroblock.h: macroblock common functions
 *****************************************************************************
 * Copyright (C) 2005-2022 x264 project
 *
 * Authors: Loren Merritt <lorenm@u.washington.edu>
 *          Laurent Aimar <fenrir@via.ecp.fr>
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

#ifndef X264_MACROBLOCK_H
#define X264_MACROBLOCK_H

enum macroblock_position_e
{
    MB_LEFT     = 0x01,
    MB_TOP      = 0x02,
    MB_TOPRIGHT = 0x04,
    MB_TOPLEFT  = 0x08,

    MB_PRIVATE  = 0x10,

    ALL_NEIGHBORS = 0xf,
};

static const uint8_t x264_pred_i4x4_neighbors[12] =
{
    MB_TOP,                         // I_PRED_4x4_V
    MB_LEFT,                        // I_PRED_4x4_H
    MB_LEFT | MB_TOP,               // I_PRED_4x4_DC
    MB_TOP  | MB_TOPRIGHT,          // I_PRED_4x4_DDL
    MB_LEFT | MB_TOPLEFT | MB_TOP,  // I_PRED_4x4_DDR
    MB_LEFT | MB_TOPLEFT | MB_TOP,  // I_PRED_4x4_VR
    MB_LEFT | MB_TOPLEFT | MB_TOP,  // I_PRED_4x4_HD
    MB_TOP  | MB_TOPRIGHT,          // I_PRED_4x4_VL
    MB_LEFT,                        // I_PRED_4x4_HU
    MB_LEFT,                        // I_PRED_4x4_DC_LEFT
    MB_TOP,                         // I_PRED_4x4_DC_TOP
    0                               // I_PRED_4x4_DC_128
};


/* XXX mb_type isn't the one written in the bitstream -> only internal usage */
#define IS_INTRA(type) ( (type) == I_4x4 || (type) == I_8x8 || (type) == I_16x16 || (type) == I_PCM )
#define IS_SKIP(type)  ( (type) == P_SKIP || (type) == B_SKIP )
#define IS_DIRECT(type)  ( (type) == B_DIRECT )
enum mb_class_e
{
    I_4x4           = 0,
    I_8x8           = 1,
    I_16x16         = 2,
    I_PCM           = 3,

    P_L0            = 4,
    P_8x8           = 5,
    P_SKIP          = 6,

    B_DIRECT        = 7,
    B_L0_L0         = 8,
    B_L0_L1         = 9,
    B_L0_BI         = 10,
    B_L1_L0         = 11,
    B_L1_L1         = 12,
    B_L1_BI         = 13,
    B_BI_L0         = 14,
    B_BI_L1         = 15,
    B_BI_BI         = 16,
    B_8x8           = 17,
    B_SKIP          = 18,

    X264_MBTYPE_MAX = 19
};
static const uint8_t x264_mb_type_fix[X264_MBTYPE_MAX] =
{
    I_4x4, I_4x4, I_16x16, I_PCM,
    P_L0, P_8x8, P_SKIP,
    B_DIRECT, B_L0_L0, B_L0_L1, B_L0_BI, B_L1_L0, B_L1_L1,
    B_L1_BI, B_BI_L0, B_BI_L1, B_BI_BI, B_8x8, B_SKIP
};
static const uint8_t x264_mb_type_list_table[X264_MBTYPE_MAX][2][2] =
{
    {{0,0},{0,0}}, {{0,0},{0,0}}, {{0,0},{0,0}}, {{0,0},{0,0}}, /* INTRA */
    {{1,1},{0,0}},                                              /* P_L0 */
    {{0,0},{0,0}},                                              /* P_8x8 */
    {{1,1},{0,0}},                                              /* P_SKIP */
    {{0,0},{0,0}},                                              /* B_DIRECT */
    {{1,1},{0,0}}, {{1,0},{0,1}}, {{1,1},{0,1}},                /* B_L0_* */
    {{0,1},{1,0}}, {{0,0},{1,1}}, {{0,1},{1,1}},                /* B_L1_* */
    {{1,1},{1,0}}, {{1,0},{1,1}}, {{1,1},{1,1}},                /* B_BI_* */
    {{0,0},{0,0}},                                              /* B_8x8 */
    {{0,0},{0,0}}                                               /* B_SKIP */
};

#define IS_SUB4x4(type) ( (type == D_L0_4x4)||(type == D_L1_4x4)||(type == D_BI_4x4) )
#define IS_SUB4x8(type) ( (type == D_L0_4x8)||(type == D_L1_4x8)||(type == D_BI_4x8) )
#define IS_SUB8x4(type) ( (type == D_L0_8x4)||(type == D_L1_8x4)||(type == D_BI_8x4) )
#define IS_SUB8x8(type) ( (type == D_L0_8x8)||(type == D_L1_8x8)||(type == D_BI_8x8)||(type == D_DIRECT_8x8) )
enum mb_partition_e
{
    /* sub partition type for P_8x8 and B_8x8 */
    D_L0_4x4          = 0,
    D_L0_8x4          = 1,
    D_L0_4x8          = 2,
    D_L0_8x8          = 3,

    /* sub partition type for B_8x8 only */
    D_L1_4x4          = 4,
    D_L1_8x4          = 5,
    D_L1_4x8          = 6,
    D_L1_8x8          = 7,

    D_BI_4x4          = 8,
    D_BI_8x4          = 9,
    D_BI_4x8          = 10,
    D_BI_8x8          = 11,
    D_DIRECT_8x8      = 12,

    /* partition */
    D_8x8             = 13,
    D_16x8            = 14,
    D_8x16            = 15,
    D_16x16           = 16,
    X264_PARTTYPE_MAX = 17,
};

static const uint8_t x264_mb_partition_listX_table[2][17] =
{{
    1, 1, 1, 1, /* D_L0_* */
    0, 0, 0, 0, /* D_L1_* */
    1, 1, 1, 1, /* D_BI_* */
    0,          /* D_DIRECT_8x8 */
    0, 0, 0, 0  /* 8x8 .. 16x16 */
},
{
    0, 0, 0, 0, /* D_L0_* */
    1, 1, 1, 1, /* D_L1_* */
    1, 1, 1, 1, /* D_BI_* */
    0,          /* D_DIRECT_8x8 */
    0, 0, 0, 0  /* 8x8 .. 16x16 */
}};
static const uint8_t x264_mb_partition_count_table[17] =
{
    /* sub L0 */
    4, 2, 2, 1,
    /* sub L1 */
    4, 2, 2, 1,
    /* sub BI */
    4, 2, 2, 1,
    /* Direct */
    1,
    /* Partition */
    4, 2, 2, 1
};
static const uint8_t x264_mb_partition_pixel_table[17] =
{
    PIXEL_4x4, PIXEL_8x4,  PIXEL_4x8,  PIXEL_8x8,   /* D_L0_* */
    PIXEL_4x4, PIXEL_8x4,  PIXEL_4x8,  PIXEL_8x8,   /* D_L1_* */
    PIXEL_4x4, PIXEL_8x4,  PIXEL_4x8,  PIXEL_8x8,   /* D_BI_* */
    PIXEL_8x8,                                      /* D_DIRECT_8x8 */
    PIXEL_8x8, PIXEL_16x8, PIXEL_8x16, PIXEL_16x16, /* 8x8 .. 16x16 */
};

/* zigzags are transposed with respect to the tables in the standard */
static const uint8_t x264_zigzag_scan4[2][16] =
{{ // frame
    0,  4,  1,  2,  5,  8, 12,  9,  6,  3,  7, 10, 13, 14, 11, 15
},
{  // field
    0,  1,  4,  2,  3,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15
}};
static const uint8_t x264_zigzag_scan8[2][64] =
{{
    0,  8,  1,  2,  9, 16, 24, 17, 10,  3,  4, 11, 18, 25, 32, 40,
   33, 26, 19, 12,  5,  6, 13, 20, 27, 34, 41, 48, 56, 49, 42, 35,
   28, 21, 14,  7, 15, 22, 29, 36, 43, 50, 57, 58, 51, 44, 37, 30,
   23, 31, 38, 45, 52, 59, 60, 53, 46, 39, 47, 54, 61, 62, 55, 63
},
{
    0,  1,  2,  8,  9,  3,  4, 10, 16, 11,  5,  6,  7, 12, 17, 24,
   18, 13, 14, 15, 19, 25, 32, 26, 20, 21, 22, 23, 27, 33, 40, 34,
   28, 29, 30, 31, 35, 41, 48, 42, 36, 37, 38, 39, 43, 49, 50, 44,
   45, 46, 47, 51, 56, 57, 52, 53, 54, 55, 58, 59, 60, 61, 62, 63
}};

static const uint8_t block_idx_x[16] =
{
    0, 1, 0, 1, 2, 3, 2, 3, 0, 1, 0, 1, 2, 3, 2, 3
};
static const uint8_t block_idx_y[16] =
{
    0, 0, 1, 1, 0, 0, 1, 1, 2, 2, 3, 3, 2, 2, 3, 3
};
static const uint8_t block_idx_xy[4][4] =
{
    { 0, 2, 8,  10 },
    { 1, 3, 9,  11 },
    { 4, 6, 12, 14 },
    { 5, 7, 13, 15 }
};
static const uint8_t block_idx_xy_1d[16] =
{
    0, 1, 4, 5, 2, 3, 6, 7, 8, 9, 12, 13, 10, 11, 14, 15
};
static const uint8_t block_idx_yx_1d[16] =
{
    0, 4, 1, 5, 8, 12, 9, 13, 2, 6, 3, 7, 10, 14, 11, 15
};
static const uint8_t block_idx_xy_fenc[16] =
{
    0*4 + 0*4*FENC_STRIDE, 1*4 + 0*4*FENC_STRIDE,
    0*4 + 1*4*FENC_STRIDE, 1*4 + 1*4*FENC_STRIDE,
    2*4 + 0*4*FENC_STRIDE, 3*4 + 0*4*FENC_STRIDE,
    2*4 + 1*4*FENC_STRIDE, 3*4 + 1*4*FENC_STRIDE,
    0*4 + 2*4*FENC_STRIDE, 1*4 + 2*4*FENC_STRIDE,
    0*4 + 3*4*FENC_STRIDE, 1*4 + 3*4*FENC_STRIDE,
    2*4 + 2*4*FENC_STRIDE, 3*4 + 2*4*FENC_STRIDE,
    2*4 + 3*4*FENC_STRIDE, 3*4 + 3*4*FENC_STRIDE
};
static const uint16_t block_idx_xy_fdec[16] =
{
    0*4 + 0*4*FDEC_STRIDE, 1*4 + 0*4*FDEC_STRIDE,
    0*4 + 1*4*FDEC_STRIDE, 1*4 + 1*4*FDEC_STRIDE,
    2*4 + 0*4*FDEC_STRIDE, 3*4 + 0*4*FDEC_STRIDE,
    2*4 + 1*4*FDEC_STRIDE, 3*4 + 1*4*FDEC_STRIDE,
    0*4 + 2*4*FDEC_STRIDE, 1*4 + 2*4*FDEC_STRIDE,
    0*4 + 3*4*FDEC_STRIDE, 1*4 + 3*4*FDEC_STRIDE,
    2*4 + 2*4*FDEC_STRIDE, 3*4 + 2*4*FDEC_STRIDE,
    2*4 + 3*4*FDEC_STRIDE, 3*4 + 3*4*FDEC_STRIDE
};

#define QP(qP) ( (qP)+QP_BD_OFFSET )
static const uint8_t i_chroma_qp_table[QP_MAX+1+12*2] =
{
         0,      0,      0,      0,      0,      0,
         0,      0,      0,      0,      0,      0,
#if BIT_DEPTH > 9
   QP(-12),QP(-11),QP(-10), QP(-9), QP(-8), QP(-7),
#endif
#if BIT_DEPTH > 8
    QP(-6), QP(-5), QP(-4), QP(-3), QP(-2), QP(-1),
#endif
     QP(0),  QP(1),  QP(2),  QP(3),  QP(4),  QP(5),
     QP(6),  QP(7),  QP(8),  QP(9), QP(10), QP(11),
    QP(12), QP(13), QP(14), QP(15), QP(16), QP(17),
    QP(18), QP(19), QP(20), QP(21), QP(22), QP(23),
    QP(24), QP(25), QP(26), QP(27), QP(28), QP(29),
    QP(29), QP(30), QP(31), QP(32), QP(32), QP(33),
    QP(34), QP(34), QP(35), QP(35), QP(36), QP(36),
    QP(37), QP(37), QP(37), QP(38), QP(38), QP(38),
    QP(39), QP(39), QP(39), QP(39),
    QP(39), QP(39), QP(39), QP(39), QP(39), QP(39),
    QP(39), QP(39), QP(39), QP(39), QP(39), QP(39),
};
#undef QP

enum cabac_ctx_block_cat_e
{
    DCT_LUMA_DC     = 0,
    DCT_LUMA_AC     = 1,
    DCT_LUMA_4x4    = 2,
    DCT_CHROMA_DC   = 3,
    DCT_CHROMA_AC   = 4,
    DCT_LUMA_8x8    = 5,
    DCT_CHROMAU_DC  = 6,
    DCT_CHROMAU_AC  = 7,
    DCT_CHROMAU_4x4 = 8,
    DCT_CHROMAU_8x8 = 9,
    DCT_CHROMAV_DC  = 10,
    DCT_CHROMAV_AC  = 11,
    DCT_CHROMAV_4x4 = 12,
    DCT_CHROMAV_8x8 = 13,
};

static const uint8_t ctx_cat_plane[6][3] =
{
    { DCT_LUMA_DC,  DCT_CHROMAU_DC,  DCT_CHROMAV_DC},
    { DCT_LUMA_AC,  DCT_CHROMAU_AC,  DCT_CHROMAV_AC},
    {DCT_LUMA_4x4, DCT_CHROMAU_4x4, DCT_CHROMAV_4x4},
    {0},
    {0},
    {DCT_LUMA_8x8, DCT_CHROMAU_8x8, DCT_CHROMAV_8x8}
};

/* Per-frame allocation: is allocated per-thread only in frame-threads mode. */
#define x264_macroblock_cache_allocate x264_template(macroblock_cache_allocate)
int  x264_macroblock_cache_allocate( x264_t *h );
#define x264_macroblock_cache_free x264_template(macroblock_cache_free)
void x264_macroblock_cache_free( x264_t *h );

/* Per-thread allocation: is allocated per-thread even in sliced-threads mode. */
#define x264_macroblock_thread_allocate x264_template(macroblock_thread_allocate)
int  x264_macroblock_thread_allocate( x264_t *h, int b_lookahead );
#define x264_macroblock_thread_free x264_template(macroblock_thread_free)
void x264_macroblock_thread_free( x264_t *h, int b_lookahead );

#define x264_macroblock_slice_init x264_template(macroblock_slice_init)
void x264_macroblock_slice_init( x264_t *h );
#define x264_macroblock_thread_init x264_template(macroblock_thread_init)
void x264_macroblock_thread_init( x264_t *h );
#define x264_macroblock_cache_load_interlaced x264_template(macroblock_cache_load_interlaced)
void x264_macroblock_cache_load_progressive( x264_t *h, int mb_x, int mb_y );
#define x264_macroblock_cache_load_progressive x264_template(macroblock_cache_load_progressive)
void x264_macroblock_cache_load_interlaced( x264_t *h, int mb_x, int mb_y );
#define x264_macroblock_deblock_strength x264_template(macroblock_deblock_strength)
void x264_macroblock_deblock_strength( x264_t *h );
#define x264_macroblock_cache_save x264_template(macroblock_cache_save)
void x264_macroblock_cache_save( x264_t *h );

#define x264_macroblock_bipred_init x264_template(macroblock_bipred_init)
void x264_macroblock_bipred_init( x264_t *h );

#define x264_prefetch_fenc x264_template(prefetch_fenc)
void x264_prefetch_fenc( x264_t *h, x264_frame_t *fenc, int i_mb_x, int i_mb_y );

#define x264_copy_column8 x264_template(copy_column8)
void x264_copy_column8( pixel *dst, pixel *src );

/* x264_mb_predict_mv_16x16:
 *      set mvp with predicted mv for D_16x16 block
 *      h->mb. need only valid values from other blocks */
#define x264_mb_predict_mv_16x16 x264_template(mb_predict_mv_16x16)
void x264_mb_predict_mv_16x16( x264_t *h, int i_list, int i_ref, int16_t mvp[2] );
/* x264_mb_predict_mv_pskip:
 *      set mvp with predicted mv for P_SKIP
 *      h->mb. need only valid values from other blocks */
#define x264_mb_predict_mv_pskip x264_template(mb_predict_mv_pskip)
void x264_mb_predict_mv_pskip( x264_t *h, int16_t mv[2] );
/* x264_mb_predict_mv:
 *      set mvp with predicted mv for all blocks except SKIP and DIRECT
 *      h->mb. need valid ref/partition/sub of current block to be valid
 *      and valid mv/ref from other blocks. */
#define x264_mb_predict_mv x264_template(mb_predict_mv)
void x264_mb_predict_mv( x264_t *h, int i_list, int idx, int i_width, int16_t mvp[2] );
/* x264_mb_predict_mv_direct16x16:
 *      set h->mb.cache.mv and h->mb.cache.ref for B_SKIP or B_DIRECT
 *      h->mb. need only valid values from other blocks.
 *      return 1 on success, 0 on failure.
 *      if b_changed != NULL, set it to whether refs or mvs differ from
 *      before this functioncall. */
#define x264_mb_predict_mv_direct16x16 x264_template(mb_predict_mv_direct16x16)
int x264_mb_predict_mv_direct16x16( x264_t *h, int *b_changed );
/* x264_mb_predict_mv_ref16x16:
 *      set mvc with D_16x16 prediction.
 *      uses all neighbors, even those that didn't end up using this ref.
 *      h->mb. need only valid values from other blocks */
#define x264_mb_predict_mv_ref16x16 x264_template(mb_predict_mv_ref16x16)
void x264_mb_predict_mv_ref16x16( x264_t *h, int i_list, int i_ref, int16_t (*mvc)[2], int *i_mvc );

#define x264_mb_mc x264_template(mb_mc)
void x264_mb_mc( x264_t *h );
#define x264_mb_mc_8x8 x264_template(mb_mc_8x8)
void x264_mb_mc_8x8( x264_t *h, int i8 );

static ALWAYS_INLINE uint32_t pack16to32( uint32_t a, uint32_t b )
{
#if WORDS_BIGENDIAN
   return b + (a<<16);
#else
   return a + (b<<16);
#endif
}
static ALWAYS_INLINE uint32_t pack8to16( uint32_t a, uint32_t b )
{
#if WORDS_BIGENDIAN
   return b + (a<<8);
#else
   return a + (b<<8);
#endif
}
static ALWAYS_INLINE uint32_t pack8to32( uint32_t a, uint32_t b, uint32_t c, uint32_t d )
{
#if WORDS_BIGENDIAN
   return d + (c<<8) + (b<<16) + (a<<24);
#else
   return a + (b<<8) + (c<<16) + (d<<24);
#endif
}
static ALWAYS_INLINE uint32_t pack16to32_mask( int a, int b )
{
#if WORDS_BIGENDIAN
   return (b&0xFFFF) + ((uint32_t)a<<16);
#else
   return (a&0xFFFF) + ((uint32_t)b<<16);
#endif
}
static ALWAYS_INLINE uint64_t pack32to64( uint32_t a, uint32_t b )
{
#if WORDS_BIGENDIAN
   return b + ((uint64_t)a<<32);
#else
   return a + ((uint64_t)b<<32);
#endif
}

#if HIGH_BIT_DEPTH
#   define pack_pixel_1to2 pack16to32
#   define pack_pixel_2to4 pack32to64
#else
#   define pack_pixel_1to2 pack8to16
#   define pack_pixel_2to4 pack16to32
#endif

static ALWAYS_INLINE int x264_mb_predict_intra4x4_mode( x264_t *h, int idx )
{
    const int ma = h->mb.cache.intra4x4_pred_mode[x264_scan8[idx] - 1];
    const int mb = h->mb.cache.intra4x4_pred_mode[x264_scan8[idx] - 8];
    const int m  = X264_MIN( x264_mb_pred_mode4x4_fix(ma),
                             x264_mb_pred_mode4x4_fix(mb) );

    if( m < 0 )
        return I_PRED_4x4_DC;

    return m;
}
static ALWAYS_INLINE int x264_mb_predict_non_zero_code( x264_t *h, int idx )
{
    const int za = h->mb.cache.non_zero_count[x264_scan8[idx] - 1];
    const int zb = h->mb.cache.non_zero_count[x264_scan8[idx] - 8];

    int i_ret = za + zb;

    if( i_ret < 0x80 )
        i_ret = ( i_ret + 1 ) >> 1;
    return i_ret & 0x7f;
}

/* intra and skip are disallowed, p8x8 is conditional. */
static const uint8_t x264_transform_allowed[X264_MBTYPE_MAX] =
{
    0,0,0,0,1,2,0,1,1,1,1,1,1,1,1,1,1,1,0
};

/* x264_mb_transform_8x8_allowed:
 *      check whether any partition is smaller than 8x8 (or at least
 *      might be, according to just partition type.)
 *      doesn't check for cbp */
static ALWAYS_INLINE int x264_mb_transform_8x8_allowed( x264_t *h )
{
    if( !h->pps->b_transform_8x8_mode )
        return 0;
    if( h->mb.i_type != P_8x8 )
        return x264_transform_allowed[h->mb.i_type];
    return M32( h->mb.i_sub_partition ) == D_L0_8x8*0x01010101;
}

#endif
