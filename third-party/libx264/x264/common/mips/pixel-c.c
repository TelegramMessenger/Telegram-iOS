/*****************************************************************************
 * pixel-c.c: msa pixel metrics
 *****************************************************************************
 * Copyright (C) 2015-2022 x264 project
 *
 * Authors: Mandar Sahastrabuddhe <mandar.sahastrabuddhe@imgtec.com>
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
#include "macros.h"
#include "pixel.h"
#include "predict.h"

#if !HIGH_BIT_DEPTH
#define CALC_MSE_B( src, ref, var )                                    \
{                                                                      \
    v16u8 src_l0_m, src_l1_m;                                          \
    v8i16 res_l0_m, res_l1_m;                                          \
                                                                       \
    ILVRL_B2_UB( src, ref, src_l0_m, src_l1_m );                       \
    HSUB_UB2_SH( src_l0_m, src_l1_m, res_l0_m, res_l1_m );             \
    DPADD_SH2_SW( res_l0_m, res_l1_m, res_l0_m, res_l1_m, var, var );  \
}

#define CALC_MSE_AVG_B( src, ref, var, sub )                           \
{                                                                      \
    v16u8 src_l0_m, src_l1_m;                                          \
    v8i16 res_l0_m, res_l1_m;                                          \
                                                                       \
    ILVRL_B2_UB( src, ref, src_l0_m, src_l1_m );                       \
    HSUB_UB2_SH( src_l0_m, src_l1_m, res_l0_m, res_l1_m );             \
    DPADD_SH2_SW( res_l0_m, res_l1_m, res_l0_m, res_l1_m, var, var );  \
                                                                       \
    sub += res_l0_m + res_l1_m;                                        \
}

#define VARIANCE_WxH( sse, diff, shift )                                \
    ( ( sse ) - ( ( ( uint32_t )( diff ) * ( diff ) ) >> ( shift ) ) )

static uint32_t sad_4width_msa( uint8_t *p_src, int32_t i_src_stride,
                                uint8_t *p_ref, int32_t i_ref_stride,
                                int32_t i_height )
{
    int32_t i_ht_cnt;
    uint32_t u_src0, u_src1, u_src2, u_src3, u_ref0, u_ref1, u_ref2, u_ref3;
    v16u8 src = { 0 };
    v16u8 ref = { 0 };
    v16u8 diff;
    v8u16 sad = { 0 };

    for( i_ht_cnt = ( i_height >> 2 ); i_ht_cnt--; )
    {
        LW4( p_src, i_src_stride, u_src0, u_src1, u_src2, u_src3 );
        p_src += ( 4 * i_src_stride );
        LW4( p_ref, i_ref_stride, u_ref0, u_ref1, u_ref2, u_ref3 );
        p_ref += ( 4 * i_ref_stride );

        INSERT_W4_UB( u_src0, u_src1, u_src2, u_src3, src );
        INSERT_W4_UB( u_ref0, u_ref1, u_ref2, u_ref3, ref );

        diff = __msa_asub_u_b( src, ref );
        sad += __msa_hadd_u_h( diff, diff );
    }

    return ( HADD_UH_U32( sad ) );
}

static uint32_t sad_8width_msa( uint8_t *p_src, int32_t i_src_stride,
                                uint8_t *p_ref, int32_t i_ref_stride,
                                int32_t i_height )
{
    int32_t i_ht_cnt;
    v16u8 src0, src1, src2, src3, ref0, ref1, ref2, ref3;
    v8u16 sad = { 0 };

    for( i_ht_cnt = ( i_height >> 2 ); i_ht_cnt--; )
    {
        LD_UB4( p_src, i_src_stride, src0, src1, src2, src3 );
        p_src += ( 4 * i_src_stride );
        LD_UB4( p_ref, i_ref_stride, ref0, ref1, ref2, ref3 );
        p_ref += ( 4 * i_ref_stride );

        PCKEV_D4_UB( src1, src0, src3, src2, ref1, ref0, ref3, ref2,
                     src0, src1, ref0, ref1 );
        sad += SAD_UB2_UH( src0, src1, ref0, ref1 );
    }

    return ( HADD_UH_U32( sad ) );
}

static uint32_t sad_16width_msa( uint8_t *p_src, int32_t i_src_stride,
                                 uint8_t *p_ref, int32_t i_ref_stride,
                                 int32_t i_height )
{
    int32_t i_ht_cnt;
    v16u8 src0, src1, ref0, ref1;
    v8u16 sad = { 0 };

    for( i_ht_cnt = ( i_height >> 2 ); i_ht_cnt--; )
    {
        LD_UB2( p_src, i_src_stride, src0, src1 );
        p_src += ( 2 * i_src_stride );
        LD_UB2( p_ref, i_ref_stride, ref0, ref1 );
        p_ref += ( 2 * i_ref_stride );
        sad += SAD_UB2_UH( src0, src1, ref0, ref1 );

        LD_UB2( p_src, i_src_stride, src0, src1 );
        p_src += ( 2 * i_src_stride );
        LD_UB2( p_ref, i_ref_stride, ref0, ref1 );
        p_ref += ( 2 * i_ref_stride );
        sad += SAD_UB2_UH( src0, src1, ref0, ref1 );
    }

    return ( HADD_UH_U32( sad ) );
}

static void sad_4width_x3d_msa( uint8_t *p_src, int32_t i_src_stride,
                                uint8_t *p_ref0, uint8_t *p_ref1,
                                uint8_t *p_ref2, int32_t i_ref_stride,
                                int32_t i_height, uint32_t *pu_sad_array )
{
    int32_t i_ht_cnt;
    v16u8 src = { 0 };
    uint32_t src0, src1, src2, src3, load0, load1, load2, load3;
    v16u8 ref0 = { 0 };
    v16u8 ref1 = { 0 };
    v16u8 ref2 = { 0 };
    v16u8 diff;
    v8u16 sad0 = { 0 };
    v8u16 sad1 = { 0 };
    v8u16 sad2 = { 0 };

    for( i_ht_cnt = ( i_height >> 2 ); i_ht_cnt--; )
    {
        LW4( p_src, i_src_stride, src0, src1, src2, src3 );
        INSERT_W4_UB( src0, src1, src2, src3, src );
        p_src += ( 4 * i_src_stride );

        LW4( p_ref0, i_ref_stride, load0, load1, load2, load3 );
        INSERT_W4_UB( load0, load1, load2, load3, ref0 );
        p_ref0 += ( 4 * i_ref_stride );

        LW4( p_ref1, i_ref_stride, load0, load1, load2, load3 );
        INSERT_W4_UB( load0, load1, load2, load3, ref1 );
        p_ref1 += ( 4 * i_ref_stride );

        LW4( p_ref2, i_ref_stride, load0, load1, load2, load3 );
        INSERT_W4_UB( load0, load1, load2, load3, ref2 );
        p_ref2 += ( 4 * i_ref_stride );

        diff = __msa_asub_u_b( src, ref0 );
        sad0 += __msa_hadd_u_h( diff, diff );

        diff = __msa_asub_u_b( src, ref1 );
        sad1 += __msa_hadd_u_h( diff, diff );

        diff = __msa_asub_u_b( src, ref2 );
        sad2 += __msa_hadd_u_h( diff, diff );
    }

    pu_sad_array[0] = HADD_UH_U32( sad0 );
    pu_sad_array[1] = HADD_UH_U32( sad1 );
    pu_sad_array[2] = HADD_UH_U32( sad2 );
}

static void sad_8width_x3d_msa( uint8_t *p_src, int32_t i_src_stride,
                                uint8_t *p_ref0, uint8_t *p_ref1,
                                uint8_t *p_ref2, int32_t i_ref_stride,
                                int32_t i_height, uint32_t *pu_sad_array )
{
    int32_t i_ht_cnt;
    v16u8 src0, src1, src2, src3;
    v16u8 ref0, ref1, ref00, ref11, ref22, ref33;
    v8u16 sad0 = { 0 };
    v8u16 sad1 = { 0 };
    v8u16 sad2 = { 0 };

    for( i_ht_cnt = ( i_height >> 2 ); i_ht_cnt--; )
    {
        LD_UB4( p_src, i_src_stride, src0, src1, src2, src3 );
        p_src += ( 4 * i_src_stride );
        LD_UB4( p_ref0, i_ref_stride, ref00, ref11, ref22, ref33 );
        p_ref0 += ( 4 * i_ref_stride );

        PCKEV_D4_UB( src1, src0, src3, src2, ref11, ref00, ref33, ref22,
                     src0, src1, ref0, ref1 );
        sad0 += SAD_UB2_UH( src0, src1, ref0, ref1 );

        LD_UB4( p_ref1, i_ref_stride, ref00, ref11, ref22, ref33 );
        p_ref1 += ( 4 * i_ref_stride );

        PCKEV_D2_UB( ref11, ref00, ref33, ref22, ref0, ref1 );
        sad1 += SAD_UB2_UH( src0, src1, ref0, ref1 );

        LD_UB4( p_ref2, i_ref_stride, ref00, ref11, ref22, ref33 );
        p_ref2 += ( 4 * i_ref_stride );

        PCKEV_D2_UB( ref11, ref00, ref33, ref22, ref0, ref1 );
        sad2 += SAD_UB2_UH( src0, src1, ref0, ref1 );
    }

    pu_sad_array[0] = HADD_UH_U32( sad0 );
    pu_sad_array[1] = HADD_UH_U32( sad1 );
    pu_sad_array[2] = HADD_UH_U32( sad2 );
}

static void sad_16width_x3d_msa( uint8_t *p_src, int32_t i_src_stride,
                                 uint8_t *p_ref0, uint8_t *p_ref1,
                                 uint8_t *p_ref2, int32_t i_ref_stride,
                                 int32_t i_height, uint32_t *pu_sad_array )
{
    int32_t i_ht_cnt;
    v16u8 src, ref;
    v16u8 diff;
    v8u16 sad0 = { 0 };
    v8u16 sad1 = { 0 };
    v8u16 sad2 = { 0 };

    for( i_ht_cnt = ( i_height >> 1 ); i_ht_cnt--; )
    {
        src = LD_UB( p_src );
        p_src += i_src_stride;

        ref = LD_UB( p_ref0 );
        p_ref0 += i_ref_stride;
        diff = __msa_asub_u_b( src, ref );
        sad0 += __msa_hadd_u_h( diff, diff );

        ref = LD_UB( p_ref1 );
        p_ref1 += i_ref_stride;
        diff = __msa_asub_u_b( src, ref );
        sad1 += __msa_hadd_u_h( diff, diff );

        ref = LD_UB( p_ref2 );
        p_ref2 += i_ref_stride;
        diff = __msa_asub_u_b( src, ref );
        sad2 += __msa_hadd_u_h( diff, diff );

        src = LD_UB( p_src );
        p_src += i_src_stride;

        ref = LD_UB( p_ref0 );
        p_ref0 += i_ref_stride;
        diff = __msa_asub_u_b( src, ref );
        sad0 += __msa_hadd_u_h( diff, diff );

        ref = LD_UB( p_ref1 );
        p_ref1 += i_ref_stride;
        diff = __msa_asub_u_b( src, ref );
        sad1 += __msa_hadd_u_h( diff, diff );

        ref = LD_UB( p_ref2 );
        p_ref2 += i_ref_stride;
        diff = __msa_asub_u_b( src, ref );
        sad2 += __msa_hadd_u_h( diff, diff );
    }

    pu_sad_array[0] = HADD_UH_U32( sad0 );
    pu_sad_array[1] = HADD_UH_U32( sad1 );
    pu_sad_array[2] = HADD_UH_U32( sad2 );
}

static void sad_4width_x4d_msa( uint8_t *p_src, int32_t i_src_stride,
                                uint8_t *p_aref[], int32_t i_ref_stride,
                                int32_t i_height, uint32_t *pu_sad_array )
{
    uint8_t *p_ref0, *p_ref1, *p_ref2, *p_ref3;
    int32_t i_ht_cnt;
    uint32_t src0, src1, src2, src3;
    uint32_t ref0, ref1, ref2, ref3;
    v16u8 src = { 0 };
    v16u8 ref = { 0 };
    v16u8 diff;
    v8u16 sad0 = { 0 };
    v8u16 sad1 = { 0 };
    v8u16 sad2 = { 0 };
    v8u16 sad3 = { 0 };

    p_ref0 = p_aref[0];
    p_ref1 = p_aref[1];
    p_ref2 = p_aref[2];
    p_ref3 = p_aref[3];

    for( i_ht_cnt = ( i_height >> 2 ); i_ht_cnt--; )
    {
        LW4( p_src, i_src_stride, src0, src1, src2, src3 );
        INSERT_W4_UB( src0, src1, src2, src3, src );
        p_src += ( 4 * i_src_stride );

        LW4( p_ref0, i_ref_stride, ref0, ref1, ref2, ref3 );
        INSERT_W4_UB( ref0, ref1, ref2, ref3, ref );
        p_ref0 += ( 4 * i_ref_stride );

        diff = __msa_asub_u_b( src, ref );
        sad0 += __msa_hadd_u_h( diff, diff );

        LW4( p_ref1, i_ref_stride, ref0, ref1, ref2, ref3 );
        INSERT_W4_UB( ref0, ref1, ref2, ref3, ref );
        p_ref1 += ( 4 * i_ref_stride );

        diff = __msa_asub_u_b( src, ref );
        sad1 += __msa_hadd_u_h( diff, diff );

        LW4( p_ref2, i_ref_stride, ref0, ref1, ref2, ref3 );
        INSERT_W4_UB( ref0, ref1, ref2, ref3, ref );
        p_ref2 += ( 4 * i_ref_stride );

        diff = __msa_asub_u_b( src, ref );
        sad2 += __msa_hadd_u_h( diff, diff );

        LW4( p_ref3, i_ref_stride, ref0, ref1, ref2, ref3 );
        INSERT_W4_UB( ref0, ref1, ref2, ref3, ref );
        p_ref3 += ( 4 * i_ref_stride );

        diff = __msa_asub_u_b( src, ref );
        sad3 += __msa_hadd_u_h( diff, diff );
    }

    pu_sad_array[0] = HADD_UH_U32( sad0 );
    pu_sad_array[1] = HADD_UH_U32( sad1 );
    pu_sad_array[2] = HADD_UH_U32( sad2 );
    pu_sad_array[3] = HADD_UH_U32( sad3 );
}

static void sad_8width_x4d_msa( uint8_t *p_src, int32_t i_src_stride,
                                uint8_t *p_aref[], int32_t i_ref_stride,
                                int32_t i_height, uint32_t *pu_sad_array )
{
    int32_t i_ht_cnt;
    uint8_t *p_ref0, *p_ref1, *p_ref2, *p_ref3;
    v16u8 src0, src1, src2, src3;
    v16u8 ref0, ref1, ref2, ref3, ref4, ref5, ref6, ref7;
    v16u8 ref8, ref9, ref10, ref11, ref12, ref13, ref14, ref15;
    v8u16 sad0 = { 0 };
    v8u16 sad1 = { 0 };
    v8u16 sad2 = { 0 };
    v8u16 sad3 = { 0 };

    p_ref0 = p_aref[0];
    p_ref1 = p_aref[1];
    p_ref2 = p_aref[2];
    p_ref3 = p_aref[3];

    for( i_ht_cnt = ( i_height >> 2 ); i_ht_cnt--; )
    {
        LD_UB4( p_src, i_src_stride, src0, src1, src2, src3 );
        p_src += ( 4 * i_src_stride );
        LD_UB4( p_ref0, i_ref_stride, ref0, ref1, ref2, ref3 );
        p_ref0 += ( 4 * i_ref_stride );
        LD_UB4( p_ref1, i_ref_stride, ref4, ref5, ref6, ref7 );
        p_ref1 += ( 4 * i_ref_stride );
        LD_UB4( p_ref2, i_ref_stride, ref8, ref9, ref10, ref11 );
        p_ref2 += ( 4 * i_ref_stride );
        LD_UB4( p_ref3, i_ref_stride, ref12, ref13, ref14, ref15 );
        p_ref3 += ( 4 * i_ref_stride );

        PCKEV_D2_UB( src1, src0, src3, src2, src0, src1 );
        PCKEV_D2_UB( ref1, ref0, ref3, ref2, ref0, ref1 );
        sad0 += SAD_UB2_UH( src0, src1, ref0, ref1 );

        PCKEV_D2_UB( ref5, ref4, ref7, ref6, ref0, ref1 );
        sad1 += SAD_UB2_UH( src0, src1, ref0, ref1 );

        PCKEV_D2_UB( ref9, ref8, ref11, ref10, ref0, ref1 );
        sad2 += SAD_UB2_UH( src0, src1, ref0, ref1 );

        PCKEV_D2_UB( ref13, ref12, ref15, ref14, ref0, ref1 );
        sad3 += SAD_UB2_UH( src0, src1, ref0, ref1 );
    }

    pu_sad_array[0] = HADD_UH_U32( sad0 );
    pu_sad_array[1] = HADD_UH_U32( sad1 );
    pu_sad_array[2] = HADD_UH_U32( sad2 );
    pu_sad_array[3] = HADD_UH_U32( sad3 );
}

static void sad_16width_x4d_msa( uint8_t *p_src, int32_t i_src_stride,
                                 uint8_t *p_aref[], int32_t i_ref_stride,
                                 int32_t i_height, uint32_t *pu_sad_array )
{
    int32_t i_ht_cnt;
    uint8_t *p_ref0, *p_ref1, *p_ref2, *p_ref3;
    v16u8 src, ref0, ref1, ref2, ref3, diff;
    v8u16 sad0 = { 0 };
    v8u16 sad1 = { 0 };
    v8u16 sad2 = { 0 };
    v8u16 sad3 = { 0 };

    p_ref0 = p_aref[0];
    p_ref1 = p_aref[1];
    p_ref2 = p_aref[2];
    p_ref3 = p_aref[3];

    for( i_ht_cnt = ( i_height >> 1 ); i_ht_cnt--; )
    {
        src = LD_UB( p_src );
        p_src += i_src_stride;
        ref0 = LD_UB( p_ref0 );
        p_ref0 += i_ref_stride;
        ref1 = LD_UB( p_ref1 );
        p_ref1 += i_ref_stride;
        ref2 = LD_UB( p_ref2 );
        p_ref2 += i_ref_stride;
        ref3 = LD_UB( p_ref3 );
        p_ref3 += i_ref_stride;

        diff = __msa_asub_u_b( src, ref0 );
        sad0 += __msa_hadd_u_h( diff, diff );
        diff = __msa_asub_u_b( src, ref1 );
        sad1 += __msa_hadd_u_h( diff, diff );
        diff = __msa_asub_u_b( src, ref2 );
        sad2 += __msa_hadd_u_h( diff, diff );
        diff = __msa_asub_u_b( src, ref3 );
        sad3 += __msa_hadd_u_h( diff, diff );

        src = LD_UB( p_src );
        p_src += i_src_stride;
        ref0 = LD_UB( p_ref0 );
        p_ref0 += i_ref_stride;
        ref1 = LD_UB( p_ref1 );
        p_ref1 += i_ref_stride;
        ref2 = LD_UB( p_ref2 );
        p_ref2 += i_ref_stride;
        ref3 = LD_UB( p_ref3 );
        p_ref3 += i_ref_stride;

        diff = __msa_asub_u_b( src, ref0 );
        sad0 += __msa_hadd_u_h( diff, diff );
        diff = __msa_asub_u_b( src, ref1 );
        sad1 += __msa_hadd_u_h( diff, diff );
        diff = __msa_asub_u_b( src, ref2 );
        sad2 += __msa_hadd_u_h( diff, diff );
        diff = __msa_asub_u_b( src, ref3 );
        sad3 += __msa_hadd_u_h( diff, diff );
    }

    pu_sad_array[0] = HADD_UH_U32( sad0 );
    pu_sad_array[1] = HADD_UH_U32( sad1 );
    pu_sad_array[2] = HADD_UH_U32( sad2 );
    pu_sad_array[3] = HADD_UH_U32( sad3 );
}

static uint64_t avc_pixel_var16width_msa( uint8_t *p_pix, int32_t i_stride,
                                          uint8_t i_height )
{
    uint32_t u_sum = 0, u_sqr_out = 0, u_cnt;
    v16i8 pix, zero = { 0 };
    v8u16 add, pix_r, pix_l;
    v4u32 sqr = { 0 };

    for( u_cnt = i_height; u_cnt--; )
    {
        pix = LD_SB( p_pix );
        p_pix += i_stride;
        add = __msa_hadd_u_h( ( v16u8 ) pix, ( v16u8 ) pix );
        u_sum += HADD_UH_U32( add );
        ILVRL_B2_UH( zero, pix, pix_r, pix_l );
        sqr = __msa_dpadd_u_w( sqr, pix_r, pix_r );
        sqr = __msa_dpadd_u_w( sqr, pix_l, pix_l );
    }

    u_sqr_out = HADD_SW_S32( sqr );

    return ( u_sum + ( ( uint64_t ) u_sqr_out << 32 ) );
}

static uint64_t avc_pixel_var8width_msa( uint8_t *p_pix, int32_t i_stride,
                                         uint8_t i_height )
{
    uint32_t u_sum = 0, u_sqr_out = 0, u_cnt;
    v16i8 pix, zero = { 0 };
    v8u16 add, pix_r;
    v4u32 sqr = { 0 };

    for( u_cnt = i_height; u_cnt--; )
    {
        pix = LD_SB( p_pix );
        p_pix += i_stride;
        pix_r = ( v8u16 ) __msa_ilvr_b( zero, pix );
        add = __msa_hadd_u_h( ( v16u8 ) pix_r, ( v16u8 ) pix_r );
        u_sum += HADD_UH_U32( add );
        sqr = __msa_dpadd_u_w( sqr, pix_r, pix_r );
    }

    u_sqr_out = HADD_SW_S32( sqr );

    return ( u_sum + ( ( uint64_t ) u_sqr_out << 32 ) );
}

static uint32_t sse_diff_8width_msa( uint8_t *p_src, int32_t i_src_stride,
                                     uint8_t *p_ref, int32_t i_ref_stride,
                                     int32_t i_height, int32_t *p_diff )
{
    int32_t i_ht_cnt;
    uint32_t u_sse;
    v16u8 src0, src1, src2, src3;
    v16u8 ref0, ref1, ref2, ref3;
    v8i16 avg = { 0 };
    v4i32 vec, var = { 0 };

    for( i_ht_cnt = ( i_height >> 2 ); i_ht_cnt--; )
    {
        LD_UB4( p_src, i_src_stride, src0, src1, src2, src3 );
        p_src += ( 4 * i_src_stride );
        LD_UB4( p_ref, i_ref_stride, ref0, ref1, ref2, ref3 );
        p_ref += ( 4 * i_ref_stride );

        PCKEV_D4_UB( src1, src0, src3, src2, ref1, ref0, ref3, ref2,
                     src0, src1, ref0, ref1 );
        CALC_MSE_AVG_B( src0, ref0, var, avg );
        CALC_MSE_AVG_B( src1, ref1, var, avg );
    }

    vec = __msa_hadd_s_w( avg, avg );
    *p_diff = HADD_SW_S32( vec );
    u_sse = HADD_SW_S32( var );

    return u_sse;
}

static uint32_t sse_4width_msa( uint8_t *p_src, int32_t i_src_stride,
                                uint8_t *p_ref, int32_t i_ref_stride,
                                int32_t i_height )
{
    int32_t i_ht_cnt;
    uint32_t u_sse;
    uint32_t u_src0, u_src1, u_src2, u_src3;
    uint32_t u_ref0, u_ref1, u_ref2, u_ref3;
    v16u8 src = { 0 };
    v16u8 ref = { 0 };
    v4i32 var = { 0 };

    for( i_ht_cnt = ( i_height >> 2 ); i_ht_cnt--; )
    {
        LW4( p_src, i_src_stride, u_src0, u_src1, u_src2, u_src3 );
        p_src += ( 4 * i_src_stride );
        LW4( p_ref, i_ref_stride, u_ref0, u_ref1, u_ref2, u_ref3 );
        p_ref += ( 4 * i_ref_stride );

        INSERT_W4_UB( u_src0, u_src1, u_src2, u_src3, src );
        INSERT_W4_UB( u_ref0, u_ref1, u_ref2, u_ref3, ref );
        CALC_MSE_B( src, ref, var );
    }

    u_sse = HADD_SW_S32( var );

    return u_sse;
}

static uint32_t sse_8width_msa( uint8_t *p_src, int32_t i_src_stride,
                                uint8_t *p_ref, int32_t i_ref_stride,
                                int32_t i_height )
{
    int32_t i_ht_cnt;
    uint32_t u_sse;
    v16u8 src0, src1, src2, src3;
    v16u8 ref0, ref1, ref2, ref3;
    v4i32 var = { 0 };

    for( i_ht_cnt = ( i_height >> 2 ); i_ht_cnt--; )
    {
        LD_UB4( p_src, i_src_stride, src0, src1, src2, src3 );
        p_src += ( 4 * i_src_stride );
        LD_UB4( p_ref, i_ref_stride, ref0, ref1, ref2, ref3 );
        p_ref += ( 4 * i_ref_stride );

        PCKEV_D4_UB( src1, src0, src3, src2, ref1, ref0, ref3, ref2,
                     src0, src1, ref0, ref1 );
        CALC_MSE_B( src0, ref0, var );
        CALC_MSE_B( src1, ref1, var );
    }

    u_sse = HADD_SW_S32( var );

    return u_sse;
}

static uint32_t sse_16width_msa( uint8_t *p_src, int32_t i_src_stride,
                                 uint8_t *p_ref, int32_t i_ref_stride,
                                 int32_t i_height )
{
    int32_t i_ht_cnt;
    uint32_t u_sse;
    v16u8 src, ref;
    v4i32 var = { 0 };

    for( i_ht_cnt = ( i_height >> 2 ); i_ht_cnt--; )
    {
        src = LD_UB( p_src );
        p_src += i_src_stride;
        ref = LD_UB( p_ref );
        p_ref += i_ref_stride;
        CALC_MSE_B( src, ref, var );

        src = LD_UB( p_src );
        p_src += i_src_stride;
        ref = LD_UB( p_ref );
        p_ref += i_ref_stride;
        CALC_MSE_B( src, ref, var );

        src = LD_UB( p_src );
        p_src += i_src_stride;
        ref = LD_UB( p_ref );
        p_ref += i_ref_stride;
        CALC_MSE_B( src, ref, var );

        src = LD_UB( p_src );
        p_src += i_src_stride;
        ref = LD_UB( p_ref );
        p_ref += i_ref_stride;
        CALC_MSE_B( src, ref, var );
    }

    u_sse = HADD_SW_S32( var );

    return u_sse;
}

static void ssim_4x4x2_core_msa( const uint8_t *p_src, int32_t i_src_stride,
                                 const uint8_t *p_ref, int32_t i_ref_stride,
                                 int32_t pi_sum_array[2][4] )
{
    v16i8 zero = { 0 };
    v16u8 src0, src1, src2, src3, ref0, ref1, ref2, ref3;
    v8u16 temp0, temp1, temp2, temp3;
    v8u16 vec0, vec1, vec2, vec3, vec4, vec5, vec6, vec7;
    v4u32 tmp0;
    v4i32 tmp2, tmp3;

    LD_UB4( p_src, i_src_stride, src0, src1, src2, src3 );
    p_src += ( 4 * i_src_stride );
    LD_UB4( p_ref, i_ref_stride, ref0, ref1, ref2, ref3 );
    p_ref += ( 4 * i_ref_stride );

    ILVR_D2_UB( src1, src0, src3, src2, src0, src2 );
    ILVR_D2_UB( ref1, ref0, ref3, ref2, ref0, ref2 );
    HADD_UB2_UH( src0, src2, temp0, temp1 );

    temp2 = ( v8u16 ) __msa_ilvev_w( ( v4i32 ) temp1, ( v4i32 ) temp0 );
    temp3 = ( v8u16 ) __msa_ilvod_w( ( v4i32 ) temp1, ( v4i32 ) temp0 );

    pi_sum_array[0][0] = ( int32_t ) HADD_UH_U32( temp2 );
    pi_sum_array[1][0] = ( int32_t ) HADD_UH_U32( temp3 );

    HADD_UB2_UH( ref0, ref2, temp0, temp1 );

    temp2 = ( v8u16 ) __msa_ilvev_w( ( v4i32 ) temp1, ( v4i32 ) temp0 );
    temp3 = ( v8u16 ) __msa_ilvod_w( ( v4i32 ) temp1, ( v4i32 ) temp0 );

    pi_sum_array[0][1] = ( int32_t ) HADD_UH_U32( temp2 );
    pi_sum_array[1][1] = ( int32_t ) HADD_UH_U32( temp3 );

    ILVR_B4_UH( zero, src0, zero, src2, zero, ref0, zero, ref2, vec0, vec2,
                vec4, vec6 );
    ILVL_B4_UH( zero, src0, zero, src2, zero, ref0, zero, ref2, vec1, vec3,
                vec5, vec7 );

    tmp0 = __msa_dotp_u_w( vec0, vec0 );
    tmp0 = __msa_dpadd_u_w( tmp0, vec1, vec1 );
    tmp0 = __msa_dpadd_u_w( tmp0, vec2, vec2 );
    tmp0 = __msa_dpadd_u_w( tmp0, vec3, vec3 );
    tmp0 = __msa_dpadd_u_w( tmp0, vec4, vec4 );
    tmp0 = __msa_dpadd_u_w( tmp0, vec5, vec5 );
    tmp0 = __msa_dpadd_u_w( tmp0, vec6, vec6 );
    tmp0 = __msa_dpadd_u_w( tmp0, vec7, vec7 );

    tmp2 = ( v4i32 ) __msa_ilvev_d( ( v2i64 ) tmp0, ( v2i64 ) tmp0 );
    tmp3 = ( v4i32 ) __msa_ilvod_d( ( v2i64 ) tmp0, ( v2i64 ) tmp0 );
    tmp2 = ( v4i32 ) __msa_hadd_u_d( ( v4u32 ) tmp2, ( v4u32 ) tmp2 );
    tmp3 = ( v4i32 ) __msa_hadd_u_d( ( v4u32 ) tmp3, ( v4u32 ) tmp3 );

    pi_sum_array[0][2] = __msa_copy_u_w( tmp2, 0 );
    pi_sum_array[1][2] = __msa_copy_u_w( tmp3, 0 );

    tmp0 = __msa_dotp_u_w( vec4, vec0 );
    tmp0 = __msa_dpadd_u_w( tmp0, vec5, vec1 );
    tmp0 = __msa_dpadd_u_w( tmp0, vec6, vec2 );
    tmp0 = __msa_dpadd_u_w( tmp0, vec7, vec3 );

    tmp2 = ( v4i32 ) __msa_ilvev_d( ( v2i64 ) tmp0, ( v2i64 ) tmp0 );
    tmp3 = ( v4i32 ) __msa_ilvod_d( ( v2i64 ) tmp0, ( v2i64 ) tmp0 );
    tmp2 = ( v4i32 ) __msa_hadd_u_d( ( v4u32 ) tmp2, ( v4u32 ) tmp2 );
    tmp3 = ( v4i32 ) __msa_hadd_u_d( ( v4u32 ) tmp3, ( v4u32 ) tmp3 );

    pi_sum_array[0][3] = __msa_copy_u_w( tmp2, 0 );
    pi_sum_array[1][3] = __msa_copy_u_w( tmp3, 0 );
}

static int32_t pixel_satd_4width_msa( uint8_t *p_src, int32_t i_src_stride,
                                      uint8_t *p_ref, int32_t i_ref_stride,
                                      uint8_t i_height )
{
    int32_t cnt;
    uint32_t u_sum = 0;
    v16i8 src0, src1, src2, src3;
    v16i8 ref0, ref1, ref2, ref3;
    v8i16 zero = { 0 };
    v8i16 diff0, diff1, diff2, diff3;
    v8i16 temp0, temp1, temp2, temp3;

    for( cnt = i_height >> 2; cnt--; )
    {
        LD_SB4( p_src, i_src_stride, src0, src1, src2, src3 );
        p_src += 4 * i_src_stride;
        LD_SB4( p_ref, i_ref_stride, ref0, ref1, ref2, ref3 );
        p_ref += 4 * i_ref_stride;

        ILVR_B4_SH( src0, ref0, src1, ref1, src2, ref2, src3, ref3,
                    diff0, diff1, diff2, diff3 );
        HSUB_UB4_SH( diff0, diff1, diff2, diff3, diff0, diff1, diff2, diff3 );
        TRANSPOSE4x4_SH_SH( diff0, diff1, diff2, diff3,
                            diff0, diff1, diff2, diff3 );
        BUTTERFLY_4( diff0, diff2, diff3, diff1, temp0, temp2, temp3, temp1 );
        BUTTERFLY_4( temp0, temp1, temp3, temp2, diff0, diff1, diff3, diff2 );
        TRANSPOSE4x4_SH_SH( diff0, diff1, diff2, diff3,
                            diff0, diff1, diff2, diff3 );
        BUTTERFLY_4( diff0, diff2, diff3, diff1, temp0, temp2, temp3, temp1 );
        BUTTERFLY_4( temp0, temp1, temp3, temp2, diff0, diff1, diff3, diff2 );

        diff0 = __msa_add_a_h( diff0, zero );
        diff1 = __msa_add_a_h( diff1, zero );
        diff2 = __msa_add_a_h( diff2, zero );
        diff3 = __msa_add_a_h( diff3, zero );
        diff0 = ( diff0 + diff1 + diff2 + diff3 );
        diff0 = ( v8i16 ) __msa_hadd_u_w( ( v8u16 ) diff0, ( v8u16 ) diff0 );
        diff0 = ( v8i16 ) __msa_hadd_u_d( ( v4u32 ) diff0, ( v4u32 ) diff0 );
        u_sum += __msa_copy_u_w( ( v4i32 ) diff0, 0 );
    }

    return ( u_sum >> 1 );
}

static int32_t pixel_satd_8width_msa( uint8_t *p_src, int32_t i_src_stride,
                                      uint8_t *p_ref, int32_t i_ref_stride,
                                      uint8_t i_height )
{
    int32_t cnt;
    uint32_t u_sum = 0;
    v16i8 src0, src1, src2, src3;
    v16i8 ref0, ref1, ref2, ref3;
    v8i16 zero = { 0 };
    v8i16 diff0, diff1, diff2, diff3, diff4, diff5, diff6, diff7;
    v8i16 temp0, temp1, temp2, temp3;

    for( cnt = i_height >> 2; cnt--; )
    {
        LD_SB4( p_src, i_src_stride, src0, src1, src2, src3 );
        p_src += 4 * i_src_stride;
        LD_SB4( p_ref, i_ref_stride, ref0, ref1, ref2, ref3 );
        p_ref += 4 * i_ref_stride;

        ILVR_B4_SH( src0, ref0, src1, ref1, src2, ref2, src3, ref3,
                    diff0, diff1, diff2, diff3 );
        HSUB_UB4_SH( diff0, diff1, diff2, diff3, diff0, diff1, diff2, diff3 );
        TRANSPOSE8X4_SH_SH( diff0, diff1, diff2, diff3,
                            diff0, diff2, diff4, diff6 );

        diff1 = ( v8i16 ) __msa_splati_d( ( v2i64 ) diff0, 1 );
        diff3 = ( v8i16 ) __msa_splati_d( ( v2i64 ) diff2, 1 );
        diff5 = ( v8i16 ) __msa_splati_d( ( v2i64 ) diff4, 1 );
        diff7 = ( v8i16 ) __msa_splati_d( ( v2i64 ) diff6, 1 );

        BUTTERFLY_4( diff0, diff2, diff3, diff1, temp0, temp2, temp3, temp1 );
        BUTTERFLY_4( temp0, temp1, temp3, temp2, diff0, diff1, diff3, diff2 );
        BUTTERFLY_4( diff4, diff6, diff7, diff5, temp0, temp2, temp3, temp1 );
        BUTTERFLY_4( temp0, temp1, temp3, temp2, diff4, diff5, diff7, diff6 );
        TRANSPOSE4X8_SH_SH( diff0, diff1, diff2, diff3, diff4, diff5, diff6,
                            diff7, diff0, diff1, diff2, diff3, diff4, diff5,
                            diff6, diff7 );
        BUTTERFLY_4( diff0, diff2, diff3, diff1, temp0, temp2, temp3, temp1 );
        BUTTERFLY_4( temp0, temp1, temp3, temp2, diff0, diff1, diff3, diff2 );

        diff0 = __msa_add_a_h( diff0, zero );
        diff1 = __msa_add_a_h( diff1, zero );
        diff2 = __msa_add_a_h( diff2, zero );
        diff3 = __msa_add_a_h( diff3, zero );
        diff0 = ( diff0 + diff1 + diff2 + diff3 );
        u_sum += HADD_UH_U32( diff0 );
    }

    return ( u_sum >> 1 );
}

static int32_t sa8d_8x8_msa( uint8_t *p_src, int32_t i_src_stride,
                             uint8_t *p_ref, int32_t i_ref_stride )
{
    uint32_t u_sum = 0;
    v16i8 src0, src1, src2, src3, src4, src5, src6, src7;
    v16i8 ref0, ref1, ref2, ref3, ref4, ref5, ref6, ref7;
    v8i16 zero = { 0 };
    v8i16 diff0, diff1, diff2, diff3, diff4, diff5, diff6, diff7;
    v8i16 sub0, sub1, sub2, sub3, sub4, sub5, sub6, sub7;
    v8i16 temp0, temp1, temp2, temp3;

    LD_SB8( p_src, i_src_stride, src0, src1, src2, src3, src4, src5, src6, src7 );
    LD_SB8( p_ref, i_ref_stride, ref0, ref1, ref2, ref3, ref4, ref5, ref6, ref7 );
    ILVR_B4_SH( src0, ref0, src1, ref1, src2, ref2, src3, ref3, sub0, sub1,
                sub2, sub3 );
    ILVR_B4_SH( src4, ref4, src5, ref5, src6, ref6, src7, ref7, sub4, sub5,
               sub6, sub7 );
    HSUB_UB4_SH( sub0, sub1, sub2, sub3, sub0, sub1, sub2, sub3 );
    HSUB_UB4_SH( sub4, sub5, sub6, sub7, sub4, sub5, sub6, sub7 );
    TRANSPOSE8x8_SH_SH( sub0, sub1, sub2, sub3, sub4, sub5, sub6, sub7,
                        sub0, sub1, sub2, sub3, sub4, sub5, sub6, sub7 );
    BUTTERFLY_4( sub0, sub2, sub3, sub1, diff0, diff1, diff4, diff5 );
    BUTTERFLY_4( sub4, sub6, sub7, sub5, diff2, diff3, diff7, diff6 );
    BUTTERFLY_4( diff0, diff2, diff3, diff1, temp0, temp2, temp3, temp1 );
    BUTTERFLY_4( temp0, temp1, temp3, temp2, diff0, diff1, diff3, diff2 );
    BUTTERFLY_4( diff4, diff6, diff7, diff5, temp0, temp2, temp3, temp1 );
    BUTTERFLY_4( temp0, temp1, temp3, temp2, diff4, diff5, diff7, diff6 );
    TRANSPOSE8x8_SH_SH( diff0, diff1, diff2, diff3, diff4, diff5, diff6, diff7,
                        diff0, diff1, diff2, diff3, diff4, diff5, diff6, diff7 );
    BUTTERFLY_4( diff0, diff2, diff3, diff1, temp0, temp2, temp3, temp1 );
    BUTTERFLY_4( temp0, temp1, temp3, temp2, diff0, diff1, diff3, diff2 );
    BUTTERFLY_4( diff4, diff6, diff7, diff5, temp0, temp2, temp3, temp1 );
    BUTTERFLY_4( temp0, temp1, temp3, temp2, diff4, diff5, diff7, diff6 );

    temp0 = diff0 + diff4;
    temp1 = diff1 + diff5;
    temp2 = diff2 + diff6;
    temp3 = diff3 + diff7;

    temp0 = __msa_add_a_h( temp0, zero );
    temp1 = __msa_add_a_h( temp1, zero );
    temp2 = __msa_add_a_h( temp2, zero );
    temp3 = __msa_add_a_h( temp3, zero );

    diff0 = temp0 + __msa_asub_s_h( diff0, diff4 );
    diff1 = temp1 + __msa_asub_s_h( diff1, diff5 );
    diff2 = temp2 + __msa_asub_s_h( diff2, diff6 );
    diff3 = temp3 + __msa_asub_s_h( diff3, diff7 );
    diff0 = ( diff0 + diff1 + diff2 + diff3 );

    u_sum = HADD_UH_U32( diff0 );

    return u_sum;
}

static uint64_t pixel_hadamard_ac_8x8_msa( uint8_t *p_pix, int32_t i_stride )
{
    int16_t tmp0, tmp1, tmp2, tmp3;
    uint32_t u_sum4 = 0, u_sum8 = 0, u_dc;
    v16u8 src0, src1, src2, src3, src4, src5, src6, src7;
    v8i16 zero = { 0 };
    v8i16 diff0, diff1, diff2, diff3, diff4, diff5, diff6, diff7;
    v8i16 sub0, sub1, sub2, sub3, sub4, sub5, sub6, sub7;
    v8i16 temp0, temp1, temp2, temp3;

    LD_UB8( p_pix, i_stride, src0, src1, src2, src3, src4, src5, src6, src7 );

    ILVR_B4_SH( zero, src0, zero, src1, zero, src2, zero, src3, diff0, diff1,
                diff2, diff3 );
    ILVR_B4_SH( zero, src4, zero, src5, zero, src6, zero, src7, diff4, diff5,
                diff6, diff7 );
    TRANSPOSE8x8_SH_SH( diff0, diff1, diff2, diff3,
                        diff4, diff5, diff6, diff7,
                        diff0, diff1, diff2, diff3,
                        diff4, diff5, diff6, diff7 );
    BUTTERFLY_4( diff0, diff2, diff3, diff1,
                 temp0, temp2, temp3, temp1 );
    BUTTERFLY_4( temp0, temp1, temp3, temp2,
                 diff0, diff1, diff3, diff2 );
    BUTTERFLY_4( diff4, diff6, diff7, diff5,
                 temp0, temp2, temp3, temp1 );
    BUTTERFLY_4( temp0, temp1, temp3, temp2,
                 diff4, diff5, diff7, diff6 );
    TRANSPOSE8x8_SH_SH( diff0, diff1, diff2, diff3,
                        diff4, diff5, diff6, diff7,
                        diff0, diff1, diff2, diff3,
                        diff4, diff5, diff6, diff7 );
    BUTTERFLY_4( diff0, diff2, diff3, diff1, temp0, temp2, temp3, temp1 );
    BUTTERFLY_4( temp0, temp1, temp3, temp2, diff0, diff1, diff3, diff2 );
    BUTTERFLY_4( diff4, diff6, diff7, diff5, temp0, temp2, temp3, temp1 );
    BUTTERFLY_4( temp0, temp1, temp3, temp2, diff4, diff5, diff7, diff6 );

    tmp0 = diff0[0];
    tmp1 = diff0[4];
    tmp2 = diff4[0];
    tmp3 = diff4[4];

    sub0 = __msa_add_a_h( diff0, zero );
    sub1 = __msa_add_a_h( diff1, zero );
    sub2 = __msa_add_a_h( diff2, zero );
    sub3 = __msa_add_a_h( diff3, zero );
    sub4 = __msa_add_a_h( diff4, zero );
    sub5 = __msa_add_a_h( diff5, zero );
    sub6 = __msa_add_a_h( diff6, zero );
    sub7 = __msa_add_a_h( diff7, zero );

    sub0 = ( sub0 + sub1 + sub2 + sub3 );
    sub1 = ( sub4 + sub5 + sub6 + sub7 );
    sub0 += sub1;

    u_sum4 += HADD_UH_U32( sub0 );

    TRANSPOSE8x8_SH_SH( diff0, diff1, diff2, diff3, diff4, diff5, diff6, diff7,
                        sub0, sub1, sub2, sub3, sub4, sub5, sub6, sub7 );

    ILVR_D2_SH( sub2, sub0, sub6, sub4, diff0, diff1 );
    ILVR_D2_SH( sub3, sub1, sub7, sub5, diff4, diff6 );

    diff2 = ( v8i16 ) __msa_ilvl_d( ( v2i64 ) sub2, ( v2i64 ) sub0 );
    diff3 = ( v8i16 ) __msa_ilvl_d( ( v2i64 ) sub6, ( v2i64 ) sub4 );
    diff5 = ( v8i16 ) __msa_ilvl_d( ( v2i64 ) sub3, ( v2i64 ) sub1 );
    diff7 = ( v8i16 ) __msa_ilvl_d( ( v2i64 ) sub7, ( v2i64 ) sub5 );

    BUTTERFLY_4( diff0, diff2, diff3, diff1, temp0, temp2, temp3, temp1 );
    BUTTERFLY_4( temp0, temp1, temp3, temp2, diff0, diff1, diff3, diff2 );
    BUTTERFLY_4( diff4, diff6, diff7, diff5, temp0, temp2, temp3, temp1 );
    BUTTERFLY_4( temp0, temp1, temp3, temp2, diff4, diff5, diff7, diff6 );

    sub0 = __msa_add_a_h( diff0, zero );
    sub1 = __msa_add_a_h( diff1, zero );
    sub2 = __msa_add_a_h( diff2, zero );
    sub3 = __msa_add_a_h( diff3, zero );
    sub4 = __msa_add_a_h( diff4, zero );
    sub5 = __msa_add_a_h( diff5, zero );
    sub6 = __msa_add_a_h( diff6, zero );
    sub7 = __msa_add_a_h( diff7, zero );

    sub0 = ( sub0 + sub1 + sub2 + sub3 );
    sub1 = ( sub4 + sub5 + sub6 + sub7 );
    sub0 += sub1;

    u_sum8 += HADD_UH_U32( sub0 );

    u_dc = ( uint16_t ) ( tmp0 + tmp1 + tmp2 + tmp3 );
    u_sum4 = u_sum4 - u_dc;
    u_sum8 = u_sum8 - u_dc;

    return ( ( uint64_t ) u_sum8 << 32 ) + u_sum4;
}

int32_t x264_pixel_sad_16x16_msa( uint8_t *p_src, intptr_t i_src_stride,
                                  uint8_t *p_ref, intptr_t i_ref_stride )
{
    return sad_16width_msa( p_src, i_src_stride, p_ref, i_ref_stride, 16 );
}

int32_t x264_pixel_sad_16x8_msa( uint8_t *p_src, intptr_t i_src_stride,
                                 uint8_t *p_ref, intptr_t i_ref_stride )
{
    return sad_16width_msa( p_src, i_src_stride, p_ref, i_ref_stride, 8 );
}

int32_t x264_pixel_sad_8x16_msa( uint8_t *p_src, intptr_t i_src_stride,
                                 uint8_t *p_ref, intptr_t i_ref_stride )
{
    return sad_8width_msa( p_src, i_src_stride, p_ref, i_ref_stride, 16 );
}

int32_t x264_pixel_sad_8x8_msa( uint8_t *p_src, intptr_t i_src_stride,
                                uint8_t *p_ref, intptr_t i_ref_stride )
{
    return sad_8width_msa( p_src, i_src_stride, p_ref, i_ref_stride, 8 );
}

int32_t x264_pixel_sad_8x4_msa( uint8_t *p_src, intptr_t i_src_stride,
                                uint8_t *p_ref, intptr_t i_ref_stride )
{
    return sad_8width_msa( p_src, i_src_stride, p_ref, i_ref_stride, 4 );
}

int32_t x264_pixel_sad_4x16_msa( uint8_t *p_src, intptr_t i_src_stride,
                                 uint8_t *p_ref, intptr_t i_ref_stride )
{
    return sad_4width_msa( p_src, i_src_stride, p_ref, i_ref_stride, 16 );
}

int32_t x264_pixel_sad_4x8_msa( uint8_t *p_src, intptr_t i_src_stride,
                                uint8_t *p_ref, intptr_t i_ref_stride )
{
    return sad_4width_msa( p_src, i_src_stride, p_ref, i_ref_stride, 8 );
}

int32_t x264_pixel_sad_4x4_msa( uint8_t *p_src, intptr_t i_src_stride,
                                uint8_t *p_ref, intptr_t i_ref_stride )
{
    return sad_4width_msa( p_src, i_src_stride, p_ref, i_ref_stride, 4 );
}

void x264_pixel_sad_x4_16x16_msa( uint8_t *p_src, uint8_t *p_ref0,
                                  uint8_t *p_ref1, uint8_t *p_ref2,
                                  uint8_t *p_ref3, intptr_t i_ref_stride,
                                  int32_t p_sad_array[4] )
{
    uint8_t *p_aref[4] = { p_ref0, p_ref1, p_ref2, p_ref3 };

    sad_16width_x4d_msa( p_src, FENC_STRIDE, p_aref, i_ref_stride, 16,
                         ( uint32_t * ) p_sad_array );
}

void x264_pixel_sad_x4_16x8_msa( uint8_t *p_src, uint8_t *p_ref0,
                                 uint8_t *p_ref1, uint8_t *p_ref2,
                                 uint8_t *p_ref3, intptr_t i_ref_stride,
                                 int32_t p_sad_array[4] )
{
    uint8_t *p_aref[4] = { p_ref0, p_ref1, p_ref2, p_ref3 };

    sad_16width_x4d_msa( p_src, FENC_STRIDE, p_aref, i_ref_stride, 8,
                         ( uint32_t * ) p_sad_array );
}

void x264_pixel_sad_x4_8x16_msa( uint8_t *p_src, uint8_t *p_ref0,
                                 uint8_t *p_ref1, uint8_t *p_ref2,
                                 uint8_t *p_ref3, intptr_t i_ref_stride,
                                 int32_t p_sad_array[4] )
{
    uint8_t *p_aref[4] = { p_ref0, p_ref1, p_ref2, p_ref3 };

    sad_8width_x4d_msa( p_src, FENC_STRIDE, p_aref, i_ref_stride, 16,
                        ( uint32_t * ) p_sad_array );
}

void x264_pixel_sad_x4_8x8_msa( uint8_t *p_src, uint8_t *p_ref0,
                                uint8_t *p_ref1, uint8_t *p_ref2,
                                uint8_t *p_ref3, intptr_t i_ref_stride,
                                int32_t p_sad_array[4] )
{
    uint8_t *p_aref[4] = { p_ref0, p_ref1, p_ref2, p_ref3 };

    sad_8width_x4d_msa( p_src, FENC_STRIDE, p_aref, i_ref_stride, 8,
                        ( uint32_t * ) p_sad_array );
}

void x264_pixel_sad_x4_8x4_msa( uint8_t *p_src, uint8_t *p_ref0,
                                uint8_t *p_ref1, uint8_t *p_ref2,
                                uint8_t *p_ref3, intptr_t i_ref_stride,
                                int32_t p_sad_array[4] )
{
    uint8_t *p_aref[4] = { p_ref0, p_ref1, p_ref2, p_ref3 };

    sad_8width_x4d_msa( p_src, FENC_STRIDE, p_aref, i_ref_stride, 4,
                        ( uint32_t * ) p_sad_array );
}

void x264_pixel_sad_x4_4x8_msa( uint8_t *p_src, uint8_t *p_ref0,
                                uint8_t *p_ref1, uint8_t *p_ref2,
                                uint8_t *p_ref3, intptr_t i_ref_stride,
                                int32_t p_sad_array[4] )
{
    uint8_t *p_aref[4] = { p_ref0, p_ref1, p_ref2, p_ref3 };

    sad_4width_x4d_msa( p_src, FENC_STRIDE, p_aref, i_ref_stride, 8,
                        ( uint32_t * ) p_sad_array );
}

void x264_pixel_sad_x4_4x4_msa( uint8_t *p_src, uint8_t *p_ref0,
                                uint8_t *p_ref1, uint8_t *p_ref2,
                                uint8_t *p_ref3, intptr_t i_ref_stride,
                                int32_t p_sad_array[4] )
{
    uint8_t *p_aref[4] = { p_ref0, p_ref1, p_ref2, p_ref3 };

    sad_4width_x4d_msa( p_src, FENC_STRIDE, p_aref, i_ref_stride, 4,
                        ( uint32_t * ) p_sad_array );
}

void x264_pixel_sad_x3_16x16_msa( uint8_t *p_src, uint8_t *p_ref0,
                                  uint8_t *p_ref1, uint8_t *p_ref2,
                                  intptr_t i_ref_stride,
                                  int32_t p_sad_array[3] )
{
    sad_16width_x3d_msa( p_src, FENC_STRIDE, p_ref0, p_ref1, p_ref2,
                         i_ref_stride, 16, ( uint32_t * ) p_sad_array );
}

void x264_pixel_sad_x3_16x8_msa( uint8_t *p_src, uint8_t *p_ref0,
                                 uint8_t *p_ref1, uint8_t *p_ref2,
                                 intptr_t i_ref_stride,
                                 int32_t p_sad_array[3] )
{
    sad_16width_x3d_msa( p_src, FENC_STRIDE, p_ref0, p_ref1, p_ref2,
                         i_ref_stride, 8, ( uint32_t * ) p_sad_array );
}

void x264_pixel_sad_x3_8x16_msa( uint8_t *p_src, uint8_t *p_ref0,
                                 uint8_t *p_ref1, uint8_t *p_ref2,
                                 intptr_t i_ref_stride,
                                 int32_t p_sad_array[3] )
{
    sad_8width_x3d_msa( p_src, FENC_STRIDE, p_ref0, p_ref1, p_ref2,
                        i_ref_stride, 16, ( uint32_t * ) p_sad_array );
}

void x264_pixel_sad_x3_8x8_msa( uint8_t *p_src, uint8_t *p_ref0,
                                uint8_t *p_ref1, uint8_t *p_ref2,
                                intptr_t i_ref_stride,
                                int32_t p_sad_array[3] )
{
    sad_8width_x3d_msa( p_src, FENC_STRIDE, p_ref0, p_ref1, p_ref2,
                        i_ref_stride, 8, ( uint32_t * ) p_sad_array );
}

void x264_pixel_sad_x3_8x4_msa( uint8_t *p_src, uint8_t *p_ref0,
                                uint8_t *p_ref1, uint8_t *p_ref2,
                                intptr_t i_ref_stride,
                                int32_t p_sad_array[3] )
{
    sad_8width_x3d_msa( p_src, FENC_STRIDE, p_ref0, p_ref1, p_ref2,
                        i_ref_stride, 4, ( uint32_t * ) p_sad_array );
}

void x264_pixel_sad_x3_4x8_msa( uint8_t *p_src, uint8_t *p_ref0,
                                uint8_t *p_ref1, uint8_t *p_ref2,
                                intptr_t i_ref_stride,
                                int32_t p_sad_array[3] )
{
    sad_4width_x3d_msa( p_src, FENC_STRIDE, p_ref0, p_ref1, p_ref2,
                        i_ref_stride, 8, ( uint32_t * ) p_sad_array );
}

void x264_pixel_sad_x3_4x4_msa( uint8_t *p_src, uint8_t *p_ref0,
                                uint8_t *p_ref1, uint8_t *p_ref2,
                                intptr_t i_ref_stride,
                                int32_t p_sad_array[3] )
{
    sad_4width_x3d_msa( p_src, FENC_STRIDE, p_ref0, p_ref1, p_ref2,
                        i_ref_stride, 4, ( uint32_t * ) p_sad_array );
}

int32_t x264_pixel_ssd_16x16_msa( uint8_t *p_src, intptr_t i_src_stride,
                                  uint8_t *p_ref, intptr_t i_ref_stride )
{
    return sse_16width_msa( p_src, i_src_stride, p_ref, i_ref_stride, 16 );
}

int32_t x264_pixel_ssd_16x8_msa( uint8_t *p_src, intptr_t i_src_stride,
                                 uint8_t *p_ref, intptr_t i_ref_stride )
{
    return sse_16width_msa( p_src, i_src_stride, p_ref, i_ref_stride, 8 );
}

int32_t x264_pixel_ssd_8x16_msa( uint8_t *p_src, intptr_t i_src_stride,
                                 uint8_t *p_ref, intptr_t i_ref_stride )
{
    return sse_8width_msa( p_src, i_src_stride, p_ref, i_ref_stride, 16 );
}

int32_t x264_pixel_ssd_8x8_msa( uint8_t *p_src, intptr_t i_src_stride,
                                uint8_t *p_ref, intptr_t i_ref_stride )
{
    return sse_8width_msa( p_src, i_src_stride, p_ref, i_ref_stride, 8 );
}

int32_t x264_pixel_ssd_8x4_msa( uint8_t *p_src, intptr_t i_src_stride,
                                uint8_t *p_ref, intptr_t i_ref_stride )
{
    return sse_8width_msa( p_src, i_src_stride, p_ref, i_ref_stride, 4 );
}

int32_t x264_pixel_ssd_4x16_msa( uint8_t *p_src, intptr_t i_src_stride,
                                 uint8_t *p_ref, intptr_t i_ref_stride )
{
    return sse_4width_msa( p_src, i_src_stride, p_ref, i_ref_stride, 16 );
}

int32_t x264_pixel_ssd_4x8_msa( uint8_t *p_src, intptr_t i_src_stride,
                                uint8_t *p_ref, intptr_t i_ref_stride )
{
    return sse_4width_msa( p_src, i_src_stride, p_ref, i_ref_stride, 8 );
}

int32_t x264_pixel_ssd_4x4_msa( uint8_t *p_src, intptr_t i_src_stride,
                                uint8_t *p_ref, intptr_t i_ref_stride )
{
    return sse_4width_msa( p_src, i_src_stride, p_ref, i_ref_stride, 4 );
}

void x264_intra_sad_x3_4x4_msa( uint8_t *p_enc, uint8_t *p_dec,
                                int32_t p_sad_array[3] )
{
    x264_intra_predict_vert_4x4_msa( p_dec );
    p_sad_array[0] = x264_pixel_sad_4x4_msa( p_dec, FDEC_STRIDE,
                                             p_enc, FENC_STRIDE );

    x264_intra_predict_hor_4x4_msa( p_dec );
    p_sad_array[1] = x264_pixel_sad_4x4_msa( p_dec, FDEC_STRIDE,
                                             p_enc, FENC_STRIDE );

    x264_intra_predict_dc_4x4_msa( p_dec );
    p_sad_array[2] = x264_pixel_sad_4x4_msa( p_dec, FDEC_STRIDE,
                                             p_enc, FENC_STRIDE );
}

void x264_intra_sad_x3_16x16_msa( uint8_t *p_enc, uint8_t *p_dec,
                                  int32_t p_sad_array[3] )
{
    x264_intra_predict_vert_16x16_msa( p_dec );
    p_sad_array[0] = x264_pixel_sad_16x16_msa( p_dec, FDEC_STRIDE,
                                               p_enc, FENC_STRIDE );

    x264_intra_predict_hor_16x16_msa( p_dec );
    p_sad_array[1] = x264_pixel_sad_16x16_msa( p_dec, FDEC_STRIDE,
                                               p_enc, FENC_STRIDE );

    x264_intra_predict_dc_16x16_msa( p_dec );
    p_sad_array[2] = x264_pixel_sad_16x16_msa( p_dec, FDEC_STRIDE,
                                               p_enc, FENC_STRIDE );
}

void x264_intra_sad_x3_8x8_msa( uint8_t *p_enc, uint8_t p_edge[36],
                                int32_t p_sad_array[3] )
{
    ALIGNED_ARRAY_16( uint8_t, pix, [8 * FDEC_STRIDE] );

    x264_intra_predict_v_8x8_msa( pix, p_edge );
    p_sad_array[0] = x264_pixel_sad_8x8_msa( pix, FDEC_STRIDE,
                                             p_enc, FENC_STRIDE );

    x264_intra_predict_h_8x8_msa( pix, p_edge );
    p_sad_array[1] = x264_pixel_sad_8x8_msa( pix, FDEC_STRIDE,
                                             p_enc, FENC_STRIDE );

    x264_intra_predict_dc_8x8_msa( pix, p_edge );
    p_sad_array[2] = x264_pixel_sad_8x8_msa( pix, FDEC_STRIDE,
                                             p_enc, FENC_STRIDE );
}

void x264_intra_sad_x3_8x8c_msa( uint8_t *p_enc, uint8_t *p_dec,
                                 int32_t p_sad_array[3] )
{
    x264_intra_predict_dc_4blk_8x8_msa( p_dec );
    p_sad_array[0] = x264_pixel_sad_8x8_msa( p_dec, FDEC_STRIDE,
                                             p_enc, FENC_STRIDE );

    x264_intra_predict_hor_8x8_msa( p_dec );
    p_sad_array[1] = x264_pixel_sad_8x8_msa( p_dec, FDEC_STRIDE,
                                             p_enc, FENC_STRIDE );

    x264_intra_predict_vert_8x8_msa( p_dec );
    p_sad_array[2] = x264_pixel_sad_8x8_msa( p_dec, FDEC_STRIDE,
                                             p_enc, FENC_STRIDE );
}

void x264_ssim_4x4x2_core_msa( const uint8_t *p_pix1, intptr_t i_stride1,
                               const uint8_t *p_pix2, intptr_t i_stride2,
                               int32_t i_sums[2][4] )
{
    ssim_4x4x2_core_msa( p_pix1, i_stride1, p_pix2, i_stride2, i_sums );
}

uint64_t x264_pixel_hadamard_ac_8x8_msa( uint8_t *p_pix, intptr_t i_stride )
{
    uint64_t u_sum;

    u_sum = pixel_hadamard_ac_8x8_msa( p_pix, i_stride );

    return ( ( u_sum >> 34 ) << 32 ) + ( ( uint32_t ) u_sum >> 1 );
}

uint64_t x264_pixel_hadamard_ac_8x16_msa( uint8_t *p_pix, intptr_t i_stride )
{
    uint64_t u_sum;

    u_sum = pixel_hadamard_ac_8x8_msa( p_pix, i_stride );
    u_sum += pixel_hadamard_ac_8x8_msa( p_pix + 8 * i_stride, i_stride );

    return ( ( u_sum >> 34 ) << 32 ) + ( ( uint32_t ) u_sum >> 1 );
}

uint64_t x264_pixel_hadamard_ac_16x8_msa( uint8_t *p_pix, intptr_t i_stride )
{
    uint64_t u_sum;

    u_sum = pixel_hadamard_ac_8x8_msa( p_pix, i_stride );
    u_sum += pixel_hadamard_ac_8x8_msa( p_pix + 8, i_stride );

    return ( ( u_sum >> 34 ) << 32 ) + ( ( uint32_t ) u_sum >> 1 );
}

uint64_t x264_pixel_hadamard_ac_16x16_msa( uint8_t *p_pix, intptr_t i_stride )
{
    uint64_t u_sum;

    u_sum = pixel_hadamard_ac_8x8_msa( p_pix, i_stride );
    u_sum += pixel_hadamard_ac_8x8_msa( p_pix + 8, i_stride );
    u_sum += pixel_hadamard_ac_8x8_msa( p_pix + 8 * i_stride, i_stride );
    u_sum += pixel_hadamard_ac_8x8_msa( p_pix + 8 * i_stride + 8, i_stride );

    return ( ( u_sum >> 34 ) << 32 ) + ( ( uint32_t ) u_sum >> 1 );
}

int32_t x264_pixel_satd_4x4_msa( uint8_t *p_pix1, intptr_t i_stride,
                                 uint8_t *p_pix2, intptr_t i_stride2 )
{
    return pixel_satd_4width_msa( p_pix1, i_stride, p_pix2, i_stride2, 4 );
}

int32_t x264_pixel_satd_4x8_msa( uint8_t *p_pix1, intptr_t i_stride,
                                 uint8_t *p_pix2, intptr_t i_stride2 )
{
    return pixel_satd_4width_msa( p_pix1, i_stride, p_pix2, i_stride2, 8 );
}

int32_t x264_pixel_satd_4x16_msa( uint8_t *p_pix1, intptr_t i_stride,
                                  uint8_t *p_pix2, intptr_t i_stride2 )
{
    return pixel_satd_4width_msa( p_pix1, i_stride, p_pix2, i_stride2, 16 );
}

int32_t x264_pixel_satd_8x4_msa( uint8_t *p_pix1, intptr_t i_stride,
                                 uint8_t *p_pix2, intptr_t i_stride2 )
{
    return pixel_satd_8width_msa( p_pix1, i_stride, p_pix2, i_stride2, 4 );
}

int32_t x264_pixel_satd_8x8_msa( uint8_t *p_pix1, intptr_t i_stride,
                                 uint8_t *p_pix2, intptr_t i_stride2 )
{
    return pixel_satd_8width_msa( p_pix1, i_stride, p_pix2, i_stride2, 8 );
}

int32_t x264_pixel_satd_8x16_msa( uint8_t *p_pix1, intptr_t i_stride,
                                  uint8_t *p_pix2, intptr_t i_stride2 )
{
    return pixel_satd_8width_msa( p_pix1, i_stride, p_pix2, i_stride2, 16 );
}

int32_t x264_pixel_satd_16x8_msa( uint8_t *p_pix1, intptr_t i_stride,
                                  uint8_t *p_pix2, intptr_t i_stride2 )
{
    uint32_t u32Sum = 0;

    u32Sum = pixel_satd_8width_msa( p_pix1, i_stride, p_pix2, i_stride2, 8 );
    u32Sum += pixel_satd_8width_msa( p_pix1 + 8, i_stride,
                                     p_pix2 + 8, i_stride2, 8 );

    return u32Sum;
}

int32_t x264_pixel_satd_16x16_msa( uint8_t *p_pix1, intptr_t i_stride,
                                   uint8_t *p_pix2, intptr_t i_stride2 )
{
    uint32_t u32Sum = 0;

    u32Sum = pixel_satd_8width_msa( p_pix1, i_stride, p_pix2, i_stride2, 16 );
    u32Sum += pixel_satd_8width_msa( p_pix1 + 8, i_stride,
                                     p_pix2 + 8, i_stride2, 16 );

    return u32Sum;
}

int32_t x264_pixel_sa8d_8x8_msa( uint8_t *p_pix1, intptr_t i_stride,
                                 uint8_t *p_pix2, intptr_t i_stride2 )
{
    int32_t i32Sum = sa8d_8x8_msa( p_pix1, i_stride, p_pix2, i_stride2 );

    return ( i32Sum + 2 ) >> 2;
}

int32_t x264_pixel_sa8d_16x16_msa( uint8_t *p_pix1, intptr_t i_stride,
                                   uint8_t *p_pix2, intptr_t i_stride2 )
{
    int32_t i32Sum = sa8d_8x8_msa( p_pix1, i_stride, p_pix2, i_stride2 ) +
                     sa8d_8x8_msa( p_pix1 + 8, i_stride,
                                   p_pix2 + 8, i_stride2 ) +
                     sa8d_8x8_msa( p_pix1 + 8 * i_stride, i_stride,
                                   p_pix2 + 8 * i_stride2, i_stride2 ) +
                     sa8d_8x8_msa( p_pix1 + 8 + 8 * i_stride, i_stride,
                                   p_pix2 + 8 + 8 * i_stride2, i_stride2 );

    return ( i32Sum + 2 ) >> 2;
}

void x264_intra_satd_x3_4x4_msa( uint8_t *p_enc, uint8_t *p_dec,
                                 int32_t p_sad_array[3] )
{
    x264_intra_predict_vert_4x4_msa( p_dec );
    p_sad_array[0] = x264_pixel_satd_4x4_msa( p_dec, FDEC_STRIDE,
                                              p_enc, FENC_STRIDE );

    x264_intra_predict_hor_4x4_msa( p_dec );
    p_sad_array[1] = x264_pixel_satd_4x4_msa( p_dec, FDEC_STRIDE,
                                              p_enc, FENC_STRIDE );

    x264_intra_predict_dc_4x4_msa( p_dec );
    p_sad_array[2] = x264_pixel_satd_4x4_msa( p_dec, FDEC_STRIDE,
                                              p_enc, FENC_STRIDE );
}

void x264_intra_satd_x3_16x16_msa( uint8_t *p_enc, uint8_t *p_dec,
                                   int32_t p_sad_array[3] )
{
    x264_intra_predict_vert_16x16_msa( p_dec );
    p_sad_array[0] = x264_pixel_satd_16x16_msa( p_dec, FDEC_STRIDE,
                                                p_enc, FENC_STRIDE );

    x264_intra_predict_hor_16x16_msa( p_dec );
    p_sad_array[1] = x264_pixel_satd_16x16_msa( p_dec, FDEC_STRIDE,
                                                p_enc, FENC_STRIDE );

    x264_intra_predict_dc_16x16_msa( p_dec );
    p_sad_array[2] = x264_pixel_satd_16x16_msa( p_dec, FDEC_STRIDE,
                                                p_enc, FENC_STRIDE );
}

void x264_intra_sa8d_x3_8x8_msa( uint8_t *p_enc, uint8_t p_edge[36],
                                 int32_t p_sad_array[3] )
{
    ALIGNED_ARRAY_16( uint8_t, pix, [8 * FDEC_STRIDE] );

    x264_intra_predict_v_8x8_msa( pix, p_edge );
    p_sad_array[0] = x264_pixel_sa8d_8x8_msa( pix, FDEC_STRIDE,
                                              p_enc, FENC_STRIDE );

    x264_intra_predict_h_8x8_msa( pix, p_edge );
    p_sad_array[1] = x264_pixel_sa8d_8x8_msa( pix, FDEC_STRIDE,
                                              p_enc, FENC_STRIDE );

    x264_intra_predict_dc_8x8_msa( pix, p_edge );
    p_sad_array[2] = x264_pixel_sa8d_8x8_msa( pix, FDEC_STRIDE,
                                              p_enc, FENC_STRIDE );
}

void x264_intra_satd_x3_8x8c_msa( uint8_t *p_enc, uint8_t *p_dec,
                                  int32_t p_sad_array[3] )
{
    x264_intra_predict_dc_4blk_8x8_msa( p_dec );
    p_sad_array[0] = x264_pixel_satd_8x8_msa( p_dec, FDEC_STRIDE,
                                              p_enc, FENC_STRIDE );

    x264_intra_predict_hor_8x8_msa( p_dec );
    p_sad_array[1] = x264_pixel_satd_8x8_msa( p_dec, FDEC_STRIDE,
                                              p_enc, FENC_STRIDE );

    x264_intra_predict_vert_8x8_msa( p_dec );
    p_sad_array[2] = x264_pixel_satd_8x8_msa( p_dec, FDEC_STRIDE,
                                              p_enc, FENC_STRIDE );
}

uint64_t x264_pixel_var_16x16_msa( uint8_t *p_pix, intptr_t i_stride )
{
    return avc_pixel_var16width_msa( p_pix, i_stride, 16 );
}

uint64_t x264_pixel_var_8x16_msa( uint8_t *p_pix, intptr_t i_stride )
{
    return avc_pixel_var8width_msa( p_pix, i_stride, 16 );
}

uint64_t x264_pixel_var_8x8_msa( uint8_t *p_pix, intptr_t i_stride )
{
    return avc_pixel_var8width_msa( p_pix, i_stride, 8 );
}

int32_t x264_pixel_var2_8x16_msa( uint8_t *p_pix1, intptr_t i_stride1,
                                  uint8_t *p_pix2, intptr_t i_stride2,
                                  int32_t *p_ssd )
{
    int32_t i_var = 0, i_diff = 0, i_sqr = 0;

    i_sqr = sse_diff_8width_msa( p_pix1, i_stride1, p_pix2, i_stride2, 16,
                                 &i_diff );
    i_var = VARIANCE_WxH( i_sqr, i_diff, 7 );
    *p_ssd = i_sqr;

    return i_var;
}

int32_t x264_pixel_var2_8x8_msa( uint8_t *p_pix1, intptr_t i_stride1,
                                 uint8_t *p_pix2, intptr_t i_stride2,
                                 int32_t *p_ssd )
{
    int32_t i_var = 0, i_diff = 0, i_sqr = 0;

    i_sqr = sse_diff_8width_msa( p_pix1, i_stride1,
                                 p_pix2, i_stride2, 8, &i_diff );
    i_var = VARIANCE_WxH( i_sqr, i_diff, 6 );
    *p_ssd = i_sqr;

    return i_var;
}
#endif
