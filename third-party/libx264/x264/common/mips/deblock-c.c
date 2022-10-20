/*****************************************************************************
 * deblock-c.c: msa deblocking
 *****************************************************************************
 * Copyright (C) 2015-2022 x264 project
 *
 * Authors: Neha Rana <neha.rana@imgtec.com>
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
#include "deblock.h"

#if !HIGH_BIT_DEPTH
#define AVC_LPF_P0P1P2_OR_Q0Q1Q2( p3_or_q3_org_in, p0_or_q0_org_in,           \
                                  q3_or_p3_org_in, p1_or_q1_org_in,           \
                                  p2_or_q2_org_in, q1_or_p1_org_in,           \
                                  p0_or_q0_out, p1_or_q1_out, p2_or_q2_out )  \
{                                                                             \
    v8i16 threshold;                                                          \
    v8i16 const3 = __msa_ldi_h( 3 );                                          \
                                                                              \
    threshold = p0_or_q0_org_in + q3_or_p3_org_in;                            \
    threshold += p1_or_q1_org_in;                                             \
                                                                              \
    p0_or_q0_out = threshold << 1;                                            \
    p0_or_q0_out += p2_or_q2_org_in;                                          \
    p0_or_q0_out += q1_or_p1_org_in;                                          \
    p0_or_q0_out = __msa_srari_h( p0_or_q0_out, 3 );                          \
                                                                              \
    p1_or_q1_out = p2_or_q2_org_in + threshold;                               \
    p1_or_q1_out = __msa_srari_h( p1_or_q1_out, 2 );                          \
                                                                              \
    p2_or_q2_out = p2_or_q2_org_in * const3;                                  \
    p2_or_q2_out += p3_or_q3_org_in;                                          \
    p2_or_q2_out += p3_or_q3_org_in;                                          \
    p2_or_q2_out += threshold;                                                \
    p2_or_q2_out = __msa_srari_h( p2_or_q2_out, 3 );                          \
}

/* data[-u32_u_img_width] = ( uint8_t )( ( 2 * p1 + p0 + q1 + 2 ) >> 2 ); */
#define AVC_LPF_P0_OR_Q0( p0_or_q0_org_in, q1_or_p1_org_in,  \
                          p1_or_q1_org_in, p0_or_q0_out )    \
{                                                            \
    p0_or_q0_out = p0_or_q0_org_in + q1_or_p1_org_in;        \
    p0_or_q0_out += p1_or_q1_org_in;                         \
    p0_or_q0_out += p1_or_q1_org_in;                         \
    p0_or_q0_out = __msa_srari_h( p0_or_q0_out, 2 );         \
}

#define AVC_LPF_P1_OR_Q1( p0_or_q0_org_in, q0_or_p0_org_in,          \
                          p1_or_q1_org_in, p2_or_q2_org_in,          \
                          negate_tc_in, tc_in, p1_or_q1_out )        \
{                                                                    \
    v8i16 clip3, temp;                                               \
                                                                     \
    clip3 = ( v8i16 ) __msa_aver_u_h( ( v8u16 ) p0_or_q0_org_in,     \
                                      ( v8u16 ) q0_or_p0_org_in );   \
    temp = p1_or_q1_org_in << 1;                                     \
    clip3 -= temp;                                                   \
    clip3 = __msa_ave_s_h( p2_or_q2_org_in, clip3 );                 \
    clip3 = CLIP_SH( clip3, negate_tc_in, tc_in );                   \
    p1_or_q1_out = p1_or_q1_org_in + clip3;                          \
}

#define AVC_LPF_P0Q0( q0_or_p0_org_in, p0_or_q0_org_in,           \
                      p1_or_q1_org_in, q1_or_p1_org_in,           \
                      negate_threshold_in, threshold_in,          \
                      p0_or_q0_out, q0_or_p0_out )                \
{                                                                 \
    v8i16 q0_sub_p0, p1_sub_q1, delta;                            \
                                                                  \
    q0_sub_p0 = q0_or_p0_org_in - p0_or_q0_org_in;                \
    p1_sub_q1 = p1_or_q1_org_in - q1_or_p1_org_in;                \
    q0_sub_p0 <<= 2;                                              \
    p1_sub_q1 += 4;                                               \
    delta = q0_sub_p0 + p1_sub_q1;                                \
    delta >>= 3;                                                  \
                                                                  \
    delta = CLIP_SH( delta, negate_threshold_in, threshold_in );  \
                                                                  \
    p0_or_q0_out = p0_or_q0_org_in + delta;                       \
    q0_or_p0_out = q0_or_p0_org_in - delta;                       \
                                                                  \
    CLIP_SH2_0_255( p0_or_q0_out, q0_or_p0_out );                 \
}

static void avc_loopfilter_luma_intra_edge_hor_msa( uint8_t *p_data,
                                                    uint8_t u_alpha_in,
                                                    uint8_t u_beta_in,
                                                    uint32_t u_img_width )
{
    v16u8 p2_asub_p0, q2_asub_q0, p0_asub_q0;
    v16u8 alpha, beta;
    v16u8 is_less_than, is_less_than_beta, negate_is_less_than_beta;
    v16u8 p2, p1, p0, q0, q1, q2;
    v16u8 p3_org, p2_org, p1_org, p0_org, q0_org, q1_org, q2_org, q3_org;
    v8i16 p1_org_r, p0_org_r, q0_org_r, q1_org_r;
    v8i16 p1_org_l, p0_org_l, q0_org_l, q1_org_l;
    v8i16 p2_r = { 0 };
    v8i16 p1_r = { 0 };
    v8i16 p0_r = { 0 };
    v8i16 q0_r = { 0 };
    v8i16 q1_r = { 0 };
    v8i16 q2_r = { 0 };
    v8i16 p2_l = { 0 };
    v8i16 p1_l = { 0 };
    v8i16 p0_l = { 0 };
    v8i16 q0_l = { 0 };
    v8i16 q1_l = { 0 };
    v8i16 q2_l = { 0 };
    v16u8 tmp_flag;
    v16i8 zero = { 0 };

    alpha = ( v16u8 ) __msa_fill_b( u_alpha_in );
    beta = ( v16u8 ) __msa_fill_b( u_beta_in );

    LD_UB4( p_data - ( u_img_width << 1 ), u_img_width,
            p1_org, p0_org, q0_org, q1_org );

    {
        v16u8 p1_asub_p0, q1_asub_q0, is_less_than_alpha;

        p0_asub_q0 = __msa_asub_u_b( p0_org, q0_org );
        p1_asub_p0 = __msa_asub_u_b( p1_org, p0_org );
        q1_asub_q0 = __msa_asub_u_b( q1_org, q0_org );

        is_less_than_alpha = ( p0_asub_q0 < alpha );
        is_less_than_beta = ( p1_asub_p0 < beta );
        is_less_than = is_less_than_beta & is_less_than_alpha;
        is_less_than_beta = ( q1_asub_q0 < beta );
        is_less_than = is_less_than_beta & is_less_than;
    }

    if( !__msa_test_bz_v( is_less_than ) )
    {
        q2_org = LD_UB( p_data + ( 2 * u_img_width ) );
        p3_org = LD_UB( p_data - ( u_img_width << 2 ) );
        p2_org = LD_UB( p_data - ( 3 * u_img_width ) );

        UNPCK_UB_SH( p1_org, p1_org_r, p1_org_l );
        UNPCK_UB_SH( p0_org, p0_org_r, p0_org_l );
        UNPCK_UB_SH( q0_org, q0_org_r, q0_org_l );

        tmp_flag = alpha >> 2;
        tmp_flag = tmp_flag + 2;
        tmp_flag = ( p0_asub_q0 < tmp_flag );

        p2_asub_p0 = __msa_asub_u_b( p2_org, p0_org );
        is_less_than_beta = ( p2_asub_p0 < beta );
        is_less_than_beta = is_less_than_beta & tmp_flag;
        negate_is_less_than_beta = __msa_xori_b( is_less_than_beta, 0xff );
        is_less_than_beta = is_less_than_beta & is_less_than;
        negate_is_less_than_beta = negate_is_less_than_beta & is_less_than;
        {
            v8u16 is_less_than_beta_l, is_less_than_beta_r;

            q1_org_r = ( v8i16 ) __msa_ilvr_b( zero, ( v16i8 ) q1_org );

            is_less_than_beta_r =
                ( v8u16 ) __msa_sldi_b( ( v16i8 ) is_less_than_beta, zero, 8 );
            if( !__msa_test_bz_v( ( v16u8 ) is_less_than_beta_r ) )
            {
                v8i16 p3_org_r;

                ILVR_B2_SH( zero, p3_org, zero, p2_org, p3_org_r, p2_r );
                AVC_LPF_P0P1P2_OR_Q0Q1Q2( p3_org_r, p0_org_r,
                                          q0_org_r, p1_org_r,
                                          p2_r, q1_org_r, p0_r, p1_r, p2_r );
            }

            q1_org_l = ( v8i16 ) __msa_ilvl_b( zero, ( v16i8 ) q1_org );

            is_less_than_beta_l =
                ( v8u16 ) __msa_sldi_b( zero, ( v16i8 ) is_less_than_beta, 8 );

            if( !__msa_test_bz_v( ( v16u8 ) is_less_than_beta_l ) )
            {
                v8i16 p3_org_l;

                ILVL_B2_SH( zero, p3_org, zero, p2_org, p3_org_l, p2_l );
                AVC_LPF_P0P1P2_OR_Q0Q1Q2( p3_org_l, p0_org_l,
                                          q0_org_l, p1_org_l,
                                          p2_l, q1_org_l, p0_l, p1_l, p2_l );
            }
        }
        /* combine and store */
        if( !__msa_test_bz_v( is_less_than_beta ) )
        {
            PCKEV_B3_UB( p0_l, p0_r, p1_l, p1_r, p2_l, p2_r, p0, p1, p2 );

            p0_org = __msa_bmnz_v( p0_org, p0, is_less_than_beta );
            p1_org = __msa_bmnz_v( p1_org, p1, is_less_than_beta );
            p2_org = __msa_bmnz_v( p2_org, p2, is_less_than_beta );

            ST_UB( p1_org, p_data - ( 2 * u_img_width ) );
            ST_UB( p2_org, p_data - ( 3 * u_img_width ) );
        }
        {
            v8u16 negate_is_less_than_beta_r, negate_is_less_than_beta_l;

            negate_is_less_than_beta_r =
                ( v8u16 ) __msa_sldi_b( ( v16i8 ) negate_is_less_than_beta,
                                        zero, 8 );
            if( !__msa_test_bz_v( ( v16u8 ) negate_is_less_than_beta_r ) )
            {
                AVC_LPF_P0_OR_Q0( p0_org_r, q1_org_r, p1_org_r, p0_r );
            }

            negate_is_less_than_beta_l =
                ( v8u16 ) __msa_sldi_b( zero,
                                        ( v16i8 ) negate_is_less_than_beta, 8 );
            if( !__msa_test_bz_v( ( v16u8 ) negate_is_less_than_beta_l ) )
            {
                AVC_LPF_P0_OR_Q0( p0_org_l, q1_org_l, p1_org_l, p0_l );
            }
        }
        if( !__msa_test_bz_v( negate_is_less_than_beta ) )
        {
            p0 = ( v16u8 ) __msa_pckev_b( ( v16i8 ) p0_l, ( v16i8 ) p0_r );
            p0_org = __msa_bmnz_v( p0_org, p0, negate_is_less_than_beta );
        }

        ST_UB( p0_org, p_data - u_img_width );

        q3_org = LD_UB( p_data + ( 3 * u_img_width ) );
        q2_asub_q0 = __msa_asub_u_b( q2_org, q0_org );
        is_less_than_beta = ( q2_asub_q0 < beta );
        is_less_than_beta = is_less_than_beta & tmp_flag;
        negate_is_less_than_beta = __msa_xori_b( is_less_than_beta, 0xff );
        is_less_than_beta = is_less_than_beta & is_less_than;
        negate_is_less_than_beta = negate_is_less_than_beta & is_less_than;

        {
            v8u16 is_less_than_beta_l, is_less_than_beta_r;
            is_less_than_beta_r =
                ( v8u16 ) __msa_sldi_b( ( v16i8 ) is_less_than_beta, zero, 8 );
            if( !__msa_test_bz_v( ( v16u8 ) is_less_than_beta_r ) )
            {
                v8i16 q3_org_r;

                ILVR_B2_SH( zero, q3_org, zero, q2_org, q3_org_r, q2_r );
                AVC_LPF_P0P1P2_OR_Q0Q1Q2( q3_org_r, q0_org_r,
                                          p0_org_r, q1_org_r,
                                          q2_r, p1_org_r, q0_r, q1_r, q2_r );
            }
            is_less_than_beta_l =
                ( v8u16 ) __msa_sldi_b( zero, ( v16i8 ) is_less_than_beta, 8 );
            if( !__msa_test_bz_v( ( v16u8 ) is_less_than_beta_l ) )
            {
                v8i16 q3_org_l;

                ILVL_B2_SH( zero, q3_org, zero, q2_org, q3_org_l, q2_l );
                AVC_LPF_P0P1P2_OR_Q0Q1Q2( q3_org_l, q0_org_l,
                                          p0_org_l, q1_org_l,
                                          q2_l, p1_org_l, q0_l, q1_l, q2_l );
            }
        }

        if( !__msa_test_bz_v( is_less_than_beta ) )
        {
            PCKEV_B3_UB( q0_l, q0_r, q1_l, q1_r, q2_l, q2_r, q0, q1, q2 );
            q0_org = __msa_bmnz_v( q0_org, q0, is_less_than_beta );
            q1_org = __msa_bmnz_v( q1_org, q1, is_less_than_beta );
            q2_org = __msa_bmnz_v( q2_org, q2, is_less_than_beta );

            ST_UB( q1_org, p_data + u_img_width );
            ST_UB( q2_org, p_data + 2 * u_img_width );
        }
        {
            v8u16 negate_is_less_than_beta_r, negate_is_less_than_beta_l;
            negate_is_less_than_beta_r =
                ( v8u16 ) __msa_sldi_b( ( v16i8 ) negate_is_less_than_beta,
                                        zero, 8 );
            if( !__msa_test_bz_v( ( v16u8 ) negate_is_less_than_beta_r ) )
            {
                AVC_LPF_P0_OR_Q0( q0_org_r, p1_org_r, q1_org_r, q0_r );
            }

            negate_is_less_than_beta_l =
                ( v8u16 ) __msa_sldi_b( zero,
                                        ( v16i8 ) negate_is_less_than_beta, 8 );
            if( !__msa_test_bz_v( ( v16u8 ) negate_is_less_than_beta_l ) )
            {
                AVC_LPF_P0_OR_Q0( q0_org_l, p1_org_l, q1_org_l, q0_l );
            }
        }
        if( !__msa_test_bz_v( negate_is_less_than_beta ) )
        {
            q0 = ( v16u8 ) __msa_pckev_b( ( v16i8 ) q0_l, ( v16i8 ) q0_r );
            q0_org = __msa_bmnz_v( q0_org, q0, negate_is_less_than_beta );
        }

        ST_UB( q0_org, p_data );
    }
}

static void avc_loopfilter_luma_intra_edge_ver_msa( uint8_t *p_data,
                                                    uint8_t u_alpha_in,
                                                    uint8_t u_beta_in,
                                                    uint32_t u_img_width )
{
    uint8_t *p_src;
    v16u8 alpha, beta, p0_asub_q0;
    v16u8 is_less_than_alpha, is_less_than;
    v16u8 is_less_than_beta, negate_is_less_than_beta;
    v16u8 p3_org, p2_org, p1_org, p0_org, q0_org, q1_org, q2_org, q3_org;
    v8i16 p1_org_r, p0_org_r, q0_org_r, q1_org_r;
    v8i16 p1_org_l, p0_org_l, q0_org_l, q1_org_l;
    v8i16 p2_r = { 0 };
    v8i16 p1_r = { 0 };
    v8i16 p0_r = { 0 };
    v8i16 q0_r = { 0 };
    v8i16 q1_r = { 0 };
    v8i16 q2_r = { 0 };
    v8i16 p2_l = { 0 };
    v8i16 p1_l = { 0 };
    v8i16 p0_l = { 0 };
    v8i16 q0_l = { 0 };
    v8i16 q1_l = { 0 };
    v8i16 q2_l = { 0 };
    v16i8 zero = { 0 };
    v16u8 tmp_flag;

    p_src = p_data - 4;

    {
        v16u8 row0, row1, row2, row3, row4, row5, row6, row7;
        v16u8 row8, row9, row10, row11, row12, row13, row14, row15;

        LD_UB8( p_src, u_img_width,
                row0, row1, row2, row3, row4, row5, row6, row7 );
        LD_UB8( p_src + ( 8 * u_img_width ), u_img_width,
                row8, row9, row10, row11, row12, row13, row14, row15 );

        TRANSPOSE16x8_UB_UB( row0, row1, row2, row3,
                             row4, row5, row6, row7,
                             row8, row9, row10, row11,
                             row12, row13, row14, row15,
                             p3_org, p2_org, p1_org, p0_org,
                             q0_org, q1_org, q2_org, q3_org );
    }

    UNPCK_UB_SH( p1_org, p1_org_r, p1_org_l );
    UNPCK_UB_SH( p0_org, p0_org_r, p0_org_l );
    UNPCK_UB_SH( q0_org, q0_org_r, q0_org_l );
    UNPCK_UB_SH( q1_org, q1_org_r, q1_org_l );

    {
        v16u8 p1_asub_p0, q1_asub_q0;

        p0_asub_q0 = __msa_asub_u_b( p0_org, q0_org );
        p1_asub_p0 = __msa_asub_u_b( p1_org, p0_org );
        q1_asub_q0 = __msa_asub_u_b( q1_org, q0_org );

        alpha = ( v16u8 ) __msa_fill_b( u_alpha_in );
        beta = ( v16u8 ) __msa_fill_b( u_beta_in );

        is_less_than_alpha = ( p0_asub_q0 < alpha );
        is_less_than_beta = ( p1_asub_p0 < beta );
        is_less_than = is_less_than_beta & is_less_than_alpha;
        is_less_than_beta = ( q1_asub_q0 < beta );
        is_less_than = is_less_than_beta & is_less_than;
    }

    if( !__msa_test_bz_v( is_less_than ) )
    {
        tmp_flag = alpha >> 2;
        tmp_flag = tmp_flag + 2;
        tmp_flag = ( p0_asub_q0 < tmp_flag );

        {
            v16u8 p2_asub_p0;

            p2_asub_p0 = __msa_asub_u_b( p2_org, p0_org );
            is_less_than_beta = ( p2_asub_p0 < beta );
        }
        is_less_than_beta = tmp_flag & is_less_than_beta;
        negate_is_less_than_beta = __msa_xori_b( is_less_than_beta, 0xff );
        is_less_than_beta = is_less_than_beta & is_less_than;
        negate_is_less_than_beta = negate_is_less_than_beta & is_less_than;

        {
            v16u8 is_less_than_beta_r;

            is_less_than_beta_r =
                ( v16u8 ) __msa_sldi_b( ( v16i8 ) is_less_than_beta, zero, 8 );
            if( !__msa_test_bz_v( is_less_than_beta_r ) )
            {
                v8i16 p3_org_r;

                ILVR_B2_SH( zero, p3_org, zero, p2_org, p3_org_r, p2_r );
                AVC_LPF_P0P1P2_OR_Q0Q1Q2( p3_org_r, p0_org_r,
                                          q0_org_r, p1_org_r,
                                          p2_r, q1_org_r, p0_r, p1_r, p2_r );
            }
        }

        {
            v16u8 is_less_than_beta_l;

            is_less_than_beta_l =
                ( v16u8 ) __msa_sldi_b( zero, ( v16i8 ) is_less_than_beta, 8 );
            if( !__msa_test_bz_v( is_less_than_beta_l ) )
            {
                v8i16 p3_org_l;

                ILVL_B2_SH( zero, p3_org, zero, p2_org, p3_org_l, p2_l );
                AVC_LPF_P0P1P2_OR_Q0Q1Q2( p3_org_l, p0_org_l,
                                          q0_org_l, p1_org_l,
                                          p2_l, q1_org_l, p0_l, p1_l, p2_l );
            }
        }
        if( !__msa_test_bz_v( is_less_than_beta ) )
        {
            v16u8 p0, p2, p1;

            PCKEV_B3_UB( p0_l, p0_r, p1_l, p1_r, p2_l, p2_r, p0, p1, p2 );
            p0_org = __msa_bmnz_v( p0_org, p0, is_less_than_beta );
            p1_org = __msa_bmnz_v( p1_org, p1, is_less_than_beta );
            p2_org = __msa_bmnz_v( p2_org, p2, is_less_than_beta );
        }
        {
            v16u8 negate_is_less_than_beta_r;

            negate_is_less_than_beta_r =
                ( v16u8 ) __msa_sldi_b( ( v16i8 ) negate_is_less_than_beta,
                                        zero, 8 );

            if( !__msa_test_bz_v( negate_is_less_than_beta_r ) )
            {
                AVC_LPF_P0_OR_Q0( p0_org_r, q1_org_r, p1_org_r, p0_r );
            }
        }
        {
            v16u8 negate_is_less_than_beta_l;

            negate_is_less_than_beta_l =
                ( v16u8 ) __msa_sldi_b( zero,
                                        ( v16i8 ) negate_is_less_than_beta, 8 );
            if( !__msa_test_bz_v( negate_is_less_than_beta_l ) )
            {
                AVC_LPF_P0_OR_Q0( p0_org_l, q1_org_l, p1_org_l, p0_l );
            }
        }

        if( !__msa_test_bz_v( negate_is_less_than_beta ) )
        {
            v16u8 p0;

            p0 = ( v16u8 ) __msa_pckev_b( ( v16i8 ) p0_l, ( v16i8 ) p0_r );
            p0_org = __msa_bmnz_v( p0_org, p0, negate_is_less_than_beta );
        }

        {
            v16u8 q2_asub_q0;

            q2_asub_q0 = __msa_asub_u_b( q2_org, q0_org );
            is_less_than_beta = ( q2_asub_q0 < beta );
        }

        is_less_than_beta = is_less_than_beta & tmp_flag;
        negate_is_less_than_beta = __msa_xori_b( is_less_than_beta, 0xff );

        is_less_than_beta = is_less_than_beta & is_less_than;
        negate_is_less_than_beta = negate_is_less_than_beta & is_less_than;

        {
            v16u8 is_less_than_beta_r;

            is_less_than_beta_r =
                ( v16u8 ) __msa_sldi_b( ( v16i8 ) is_less_than_beta, zero, 8 );
            if( !__msa_test_bz_v( is_less_than_beta_r ) )
            {
                v8i16 q3_org_r;

                ILVR_B2_SH( zero, q3_org, zero, q2_org, q3_org_r, q2_r );
                AVC_LPF_P0P1P2_OR_Q0Q1Q2( q3_org_r, q0_org_r,
                                          p0_org_r, q1_org_r,
                                          q2_r, p1_org_r, q0_r, q1_r, q2_r );
            }
        }
        {
            v16u8 is_less_than_beta_l;

            is_less_than_beta_l =
                ( v16u8 ) __msa_sldi_b( zero, ( v16i8 ) is_less_than_beta, 8 );
            if( !__msa_test_bz_v( is_less_than_beta_l ) )
            {
                v8i16 q3_org_l;

                ILVL_B2_SH( zero, q3_org, zero, q2_org, q3_org_l, q2_l );
                AVC_LPF_P0P1P2_OR_Q0Q1Q2( q3_org_l, q0_org_l,
                                          p0_org_l, q1_org_l,
                                          q2_l, p1_org_l, q0_l, q1_l, q2_l );
            }
        }
        if( !__msa_test_bz_v( is_less_than_beta ) )
        {
            v16u8 q0, q1, q2;

            PCKEV_B3_UB( q0_l, q0_r, q1_l, q1_r, q2_l, q2_r, q0, q1, q2 );
            q0_org = __msa_bmnz_v( q0_org, q0, is_less_than_beta );
            q1_org = __msa_bmnz_v( q1_org, q1, is_less_than_beta );
            q2_org = __msa_bmnz_v( q2_org, q2, is_less_than_beta );
        }

        {
            v16u8 negate_is_less_than_beta_r;

            negate_is_less_than_beta_r =
                ( v16u8 ) __msa_sldi_b( ( v16i8 ) negate_is_less_than_beta,
                                        zero, 8 );
            if( !__msa_test_bz_v( negate_is_less_than_beta_r ) )
            {
                AVC_LPF_P0_OR_Q0( q0_org_r, p1_org_r, q1_org_r, q0_r );
            }
        }
        {
            v16u8 negate_is_less_than_beta_l;

            negate_is_less_than_beta_l =
                ( v16u8 ) __msa_sldi_b( zero,
                                        ( v16i8 ) negate_is_less_than_beta, 8 );
            if( !__msa_test_bz_v( negate_is_less_than_beta_l ) )
            {
                AVC_LPF_P0_OR_Q0( q0_org_l, p1_org_l, q1_org_l, q0_l );
            }
        }
        if( !__msa_test_bz_v( negate_is_less_than_beta ) )
        {
            v16u8 q0;

            q0 = ( v16u8 ) __msa_pckev_b( ( v16i8 ) q0_l, ( v16i8 ) q0_r );
            q0_org = __msa_bmnz_v( q0_org, q0, negate_is_less_than_beta );
        }
    }
    {
        v8i16 tp0, tp1, tp2, tp3, tmp2, tmp3, tmp4, tmp5, tmp6, tmp7;

        ILVRL_B2_SH( p1_org, p2_org, tp0, tp2 );
        ILVRL_B2_SH( q0_org, p0_org, tp1, tp3 );
        ILVRL_B2_SH( q2_org, q1_org, tmp2, tmp5 );

        ILVRL_H2_SH( tp1, tp0, tmp3, tmp4 );
        ILVRL_H2_SH( tp3, tp2, tmp6, tmp7 );

        p_src = p_data - 3;
        ST4x4_UB( tmp3, tmp3, 0, 1, 2, 3, p_src, u_img_width );
        ST2x4_UB( tmp2, 0, p_src + 4, u_img_width );
        p_src += 4 * u_img_width;
        ST4x4_UB( tmp4, tmp4, 0, 1, 2, 3, p_src, u_img_width );
        ST2x4_UB( tmp2, 4, p_src + 4, u_img_width );
        p_src += 4 * u_img_width;

        ST4x4_UB( tmp6, tmp6, 0, 1, 2, 3, p_src, u_img_width );
        ST2x4_UB( tmp5, 0, p_src + 4, u_img_width );
        p_src += 4 * u_img_width;
        ST4x4_UB( tmp7, tmp7, 0, 1, 2, 3, p_src, u_img_width );
        ST2x4_UB( tmp5, 4, p_src + 4, u_img_width );
    }
}

static void avc_lpf_cbcr_interleaved_intra_edge_hor_msa( uint8_t *p_chroma,
                                                         uint8_t u_alpha_in,
                                                         uint8_t u_beta_in,
                                                         uint32_t u_img_width )
{
    v16u8 alpha, beta, is_less_than;
    v16u8 p0, q0, p1_org, p0_org, q0_org, q1_org;
    v8i16 p0_r = { 0 };
    v8i16 q0_r = { 0 };
    v8i16 p0_l = { 0 };
    v8i16 q0_l = { 0 };

    alpha = ( v16u8 ) __msa_fill_b( u_alpha_in );
    beta = ( v16u8 ) __msa_fill_b( u_beta_in );

    LD_UB4( p_chroma - ( u_img_width << 1 ), u_img_width,
            p1_org, p0_org, q0_org, q1_org );

    {
        v16u8 p0_asub_q0, p1_asub_p0, q1_asub_q0;
        v16u8 is_less_than_alpha, is_less_than_beta;

        p0_asub_q0 = __msa_asub_u_b( p0_org, q0_org );
        p1_asub_p0 = __msa_asub_u_b( p1_org, p0_org );
        q1_asub_q0 = __msa_asub_u_b( q1_org, q0_org );

        is_less_than_alpha = ( p0_asub_q0 < alpha );
        is_less_than_beta = ( p1_asub_p0 < beta );
        is_less_than = is_less_than_beta & is_less_than_alpha;
        is_less_than_beta = ( q1_asub_q0 < beta );
        is_less_than = is_less_than_beta & is_less_than;
    }

    if( !__msa_test_bz_v( is_less_than ) )
    {
        v16i8 zero = { 0 };
        v16u8 is_less_than_r, is_less_than_l;

        is_less_than_r = ( v16u8 ) __msa_sldi_b( ( v16i8 ) is_less_than,
                                                 zero, 8 );
        if( !__msa_test_bz_v( is_less_than_r ) )
        {
            v8i16 p1_org_r, p0_org_r, q0_org_r, q1_org_r;

            ILVR_B4_SH( zero, p1_org, zero, p0_org, zero, q0_org,
                        zero, q1_org, p1_org_r, p0_org_r, q0_org_r,
                        q1_org_r );
            AVC_LPF_P0_OR_Q0( p0_org_r, q1_org_r, p1_org_r, p0_r );
            AVC_LPF_P0_OR_Q0( q0_org_r, p1_org_r, q1_org_r, q0_r );
        }

        is_less_than_l = ( v16u8 ) __msa_sldi_b( zero,
                                                 ( v16i8 ) is_less_than, 8 );
        if( !__msa_test_bz_v( is_less_than_l ) )
        {
            v8i16 p1_org_l, p0_org_l, q0_org_l, q1_org_l;

            ILVL_B4_SH( zero, p1_org, zero, p0_org, zero, q0_org,
                        zero, q1_org, p1_org_l, p0_org_l, q0_org_l,
                        q1_org_l );
            AVC_LPF_P0_OR_Q0( p0_org_l, q1_org_l, p1_org_l, p0_l );
            AVC_LPF_P0_OR_Q0( q0_org_l, p1_org_l, q1_org_l, q0_l );
        }

        PCKEV_B2_UB( p0_l, p0_r, q0_l, q0_r, p0, q0 );

        p0_org = __msa_bmnz_v( p0_org, p0, is_less_than );
        q0_org = __msa_bmnz_v( q0_org, q0, is_less_than );

        ST_UB( p0_org, ( p_chroma - u_img_width ) );
        ST_UB( q0_org, p_chroma );
    }
}

static void avc_lpf_cbcr_interleaved_intra_edge_ver_msa( uint8_t *p_chroma,
                                                         uint8_t u_alpha_in,
                                                         uint8_t u_beta_in,
                                                         uint32_t u_img_width )
{
    v16u8 is_less_than;
    v16u8 p0, q0, p1_org, p0_org, q0_org, q1_org;
    v8i16 p0_r = { 0 };
    v8i16 q0_r = { 0 };
    v8i16 p0_l = { 0 };
    v8i16 q0_l = { 0 };
    v16u8 p1_u_org, p0_u_org, q0_u_org, q1_u_org;
    v16u8 p1_v_org, p0_v_org, q0_v_org, q1_v_org;
    v16i8 tmp0, tmp1, tmp2, tmp3;
    v4i32 vec0, vec1;
    v16u8 row0, row1, row2, row3, row4, row5, row6, row7;

    LD_UB8( ( p_chroma - 4 ), u_img_width,
            row0, row1, row2, row3, row4, row5, row6, row7 );

    TRANSPOSE8x8_UB_UB( row0, row1, row2, row3, row4, row5, row6, row7,
                        p1_u_org, p1_v_org, p0_u_org, p0_v_org,
                        q0_u_org, q0_v_org, q1_u_org, q1_v_org );

    ILVR_D4_UB( p1_v_org, p1_u_org, p0_v_org, p0_u_org, q0_v_org, q0_u_org,
                q1_v_org, q1_u_org, p1_org, p0_org, q0_org, q1_org );

    {
        v16u8 p0_asub_q0, p1_asub_p0, q1_asub_q0;
        v16u8 is_less_than_beta, is_less_than_alpha, alpha, beta;

        p0_asub_q0 = __msa_asub_u_b( p0_org, q0_org );
        p1_asub_p0 = __msa_asub_u_b( p1_org, p0_org );
        q1_asub_q0 = __msa_asub_u_b( q1_org, q0_org );

        alpha = ( v16u8 ) __msa_fill_b( u_alpha_in );
        beta = ( v16u8 ) __msa_fill_b( u_beta_in );

        is_less_than_alpha = ( p0_asub_q0 < alpha );
        is_less_than_beta = ( p1_asub_p0 < beta );
        is_less_than = is_less_than_beta & is_less_than_alpha;
        is_less_than_beta = ( q1_asub_q0 < beta );
        is_less_than = is_less_than_beta & is_less_than;
    }

    if( !__msa_test_bz_v( is_less_than ) )
    {
        v16u8 is_less_than_r, is_less_than_l;
        v16i8 zero = { 0 };

        is_less_than_r = ( v16u8 ) __msa_sldi_b( ( v16i8 ) is_less_than,
                                                 zero, 8 );
        if( !__msa_test_bz_v( is_less_than_r ) )
        {
            v8i16 p1_org_r, p0_org_r, q0_org_r, q1_org_r;

            ILVR_B4_SH( zero, p1_org, zero, p0_org, zero, q0_org,
                        zero, q1_org, p1_org_r, p0_org_r, q0_org_r, q1_org_r );
            AVC_LPF_P0_OR_Q0( p0_org_r, q1_org_r, p1_org_r, p0_r );
            AVC_LPF_P0_OR_Q0( q0_org_r, p1_org_r, q1_org_r, q0_r );
        }

        is_less_than_l = ( v16u8 ) __msa_sldi_b( zero,
                                                 ( v16i8 ) is_less_than, 8 );
        if( !__msa_test_bz_v( is_less_than_l ) )
        {
            v8i16 p1_org_l, p0_org_l, q0_org_l, q1_org_l;

            ILVL_B4_SH( zero, p1_org, zero, p0_org, zero, q0_org,
                        zero, q1_org, p1_org_l, p0_org_l, q0_org_l, q1_org_l );
            AVC_LPF_P0_OR_Q0( p0_org_l, q1_org_l, p1_org_l, p0_l );
            AVC_LPF_P0_OR_Q0( q0_org_l, p1_org_l, q1_org_l, q0_l );
        }

        PCKEV_B2_UB( p0_l, p0_r, q0_l, q0_r, p0, q0 );

        p0_org = __msa_bmnz_v( p0_org, p0, is_less_than );
        q0_org = __msa_bmnz_v( q0_org, q0, is_less_than );

        SLDI_B2_0_UB( p0_org, q0_org, p0_v_org, q0_v_org, 8 );
        ILVR_D2_SB( p0_v_org, p0_org, q0_v_org, q0_org, tmp0, tmp1 );
        ILVRL_B2_SB( tmp1, tmp0, tmp2, tmp3 );
        ILVRL_B2_SW( tmp3, tmp2, vec0, vec1 );

        ST4x8_UB( vec0, vec1, ( p_chroma - 2 ), u_img_width );
    }
}

static void avc_loopfilter_luma_inter_edge_ver_msa( uint8_t *p_data,
                                                    uint8_t u_bs0,
                                                    uint8_t u_bs1,
                                                    uint8_t u_bs2,
                                                    uint8_t u_bs3,
                                                    uint8_t u_tc0,
                                                    uint8_t u_tc1,
                                                    uint8_t u_tc2,
                                                    uint8_t u_tc3,
                                                    uint8_t u_alpha_in,
                                                    uint8_t u_beta_in,
                                                    uint32_t u_img_width )
{
    uint8_t *p_src;
    v16u8 beta, tmp_vec, bs = { 0 };
    v16u8 tc = { 0 };
    v16u8 is_less_than, is_less_than_beta;
    v16u8 p1, p0, q0, q1;
    v8i16 p0_r, q0_r, p1_r = { 0 };
    v8i16 q1_r = { 0 };
    v8i16 p0_l, q0_l, p1_l = { 0 };
    v8i16 q1_l = { 0 };
    v16u8 p3_org, p2_org, p1_org, p0_org, q0_org, q1_org, q2_org, q3_org;
    v8i16 p2_org_r, p1_org_r, p0_org_r, q0_org_r, q1_org_r, q2_org_r;
    v8i16 p2_org_l, p1_org_l, p0_org_l, q0_org_l, q1_org_l, q2_org_l;
    v8i16 tc_r, tc_l;
    v16i8 zero = { 0 };
    v16u8 is_bs_greater_than0;

    tmp_vec = ( v16u8 ) __msa_fill_b( u_bs0 );
    bs = ( v16u8 ) __msa_insve_w( ( v4i32 ) bs, 0, ( v4i32 ) tmp_vec );
    tmp_vec = ( v16u8 ) __msa_fill_b( u_bs1 );
    bs = ( v16u8 ) __msa_insve_w( ( v4i32 ) bs, 1, ( v4i32 ) tmp_vec );
    tmp_vec = ( v16u8 ) __msa_fill_b( u_bs2 );
    bs = ( v16u8 ) __msa_insve_w( ( v4i32 ) bs, 2, ( v4i32 ) tmp_vec );
    tmp_vec = ( v16u8 ) __msa_fill_b( u_bs3 );
    bs = ( v16u8 ) __msa_insve_w( ( v4i32 ) bs, 3, ( v4i32 ) tmp_vec );

    if( !__msa_test_bz_v( bs ) )
    {
        tmp_vec = ( v16u8 ) __msa_fill_b( u_tc0 );
        tc = ( v16u8 ) __msa_insve_w( ( v4i32 ) tc, 0, ( v4i32 ) tmp_vec );
        tmp_vec = ( v16u8 ) __msa_fill_b( u_tc1 );
        tc = ( v16u8 ) __msa_insve_w( ( v4i32 ) tc, 1, ( v4i32 ) tmp_vec );
        tmp_vec = ( v16u8 ) __msa_fill_b( u_tc2 );
        tc = ( v16u8 ) __msa_insve_w( ( v4i32 ) tc, 2, ( v4i32 ) tmp_vec );
        tmp_vec = ( v16u8 ) __msa_fill_b( u_tc3 );
        tc = ( v16u8 ) __msa_insve_w( ( v4i32 ) tc, 3, ( v4i32 ) tmp_vec );

        is_bs_greater_than0 = ( zero < bs );

        {
            v16u8 row0, row1, row2, row3, row4, row5, row6, row7;
            v16u8 row8, row9, row10, row11, row12, row13, row14, row15;

            p_src = p_data;
            p_src -= 4;

            LD_UB8( p_src, u_img_width,
                    row0, row1, row2, row3, row4, row5, row6, row7 );
            p_src += ( 8 * u_img_width );
            LD_UB8( p_src, u_img_width,
                    row8, row9, row10, row11, row12, row13, row14, row15 );

            TRANSPOSE16x8_UB_UB( row0, row1, row2, row3, row4, row5, row6, row7,
                                 row8, row9, row10, row11,
                                 row12, row13, row14, row15,
                                 p3_org, p2_org, p1_org, p0_org,
                                 q0_org, q1_org, q2_org, q3_org );
        }
        {
            v16u8 p0_asub_q0, p1_asub_p0, q1_asub_q0, alpha;
            v16u8 is_less_than_alpha;

            p0_asub_q0 = __msa_asub_u_b( p0_org, q0_org );
            p1_asub_p0 = __msa_asub_u_b( p1_org, p0_org );
            q1_asub_q0 = __msa_asub_u_b( q1_org, q0_org );

            alpha = ( v16u8 ) __msa_fill_b( u_alpha_in );
            beta = ( v16u8 ) __msa_fill_b( u_beta_in );

            is_less_than_alpha = ( p0_asub_q0 < alpha );
            is_less_than_beta = ( p1_asub_p0 < beta );
            is_less_than = is_less_than_beta & is_less_than_alpha;
            is_less_than_beta = ( q1_asub_q0 < beta );
            is_less_than = is_less_than_beta & is_less_than;
            is_less_than = is_less_than & is_bs_greater_than0;
        }
        if( !__msa_test_bz_v( is_less_than ) )
        {
            v16i8 negate_tc, sign_negate_tc;
            v8i16 negate_tc_r, i16_negatetc_l;

            negate_tc = zero - ( v16i8 ) tc;
            sign_negate_tc = __msa_clti_s_b( negate_tc, 0 );

            ILVRL_B2_SH( sign_negate_tc, negate_tc, negate_tc_r,
                         i16_negatetc_l );

            UNPCK_UB_SH( tc, tc_r, tc_l );
            UNPCK_UB_SH( p1_org, p1_org_r, p1_org_l );
            UNPCK_UB_SH( p0_org, p0_org_r, p0_org_l );
            UNPCK_UB_SH( q0_org, q0_org_r, q0_org_l );

            {
                v16u8 p2_asub_p0;
                v16u8 is_less_than_beta_r, is_less_than_beta_l;

                p2_asub_p0 = __msa_asub_u_b( p2_org, p0_org );
                is_less_than_beta = ( p2_asub_p0 < beta );
                is_less_than_beta = is_less_than_beta & is_less_than;

                is_less_than_beta_r =
                    ( v16u8 ) __msa_sldi_b( ( v16i8 ) is_less_than_beta,
                                            zero, 8 );
                if( !__msa_test_bz_v( is_less_than_beta_r ) )
                {
                    p2_org_r = ( v8i16 ) __msa_ilvr_b( zero, ( v16i8 ) p2_org );

                    AVC_LPF_P1_OR_Q1( p0_org_r, q0_org_r, p1_org_r, p2_org_r,
                                      negate_tc_r, tc_r, p1_r );
                }

                is_less_than_beta_l =
                    ( v16u8 ) __msa_sldi_b( zero,
                                            ( v16i8 ) is_less_than_beta, 8 );
                if( !__msa_test_bz_v( is_less_than_beta_l ) )
                {
                    p2_org_l = ( v8i16 ) __msa_ilvl_b( zero, ( v16i8 ) p2_org );

                    AVC_LPF_P1_OR_Q1( p0_org_l, q0_org_l, p1_org_l, p2_org_l,
                                      i16_negatetc_l, tc_l, p1_l );
                }
            }

            if( !__msa_test_bz_v( is_less_than_beta ) )
            {
                p1 = ( v16u8 ) __msa_pckev_b( ( v16i8 ) p1_l, ( v16i8 ) p1_r );
                p1_org = __msa_bmnz_v( p1_org, p1, is_less_than_beta );

                is_less_than_beta = __msa_andi_b( is_less_than_beta, 1 );
                tc = tc + is_less_than_beta;
            }

            {
                v16u8 u8_q2asub_q0;
                v16u8 is_less_than_beta_l, is_less_than_beta_r;

                u8_q2asub_q0 = __msa_asub_u_b( q2_org, q0_org );
                is_less_than_beta = ( u8_q2asub_q0 < beta );
                is_less_than_beta = is_less_than_beta & is_less_than;

                q1_org_r = ( v8i16 ) __msa_ilvr_b( zero, ( v16i8 ) q1_org );

                is_less_than_beta_r =
                    ( v16u8 ) __msa_sldi_b( ( v16i8 ) is_less_than_beta,
                                            zero, 8 );
                if( !__msa_test_bz_v( is_less_than_beta_r ) )
                {
                    q2_org_r = ( v8i16 ) __msa_ilvr_b( zero, ( v16i8 ) q2_org );
                    AVC_LPF_P1_OR_Q1( p0_org_r, q0_org_r, q1_org_r, q2_org_r,
                                      negate_tc_r, tc_r, q1_r );
                }

                q1_org_l = ( v8i16 ) __msa_ilvl_b( zero, ( v16i8 ) q1_org );

                is_less_than_beta_l =
                    ( v16u8 ) __msa_sldi_b( zero,
                                            ( v16i8 ) is_less_than_beta, 8 );
                if( !__msa_test_bz_v( is_less_than_beta_l ) )
                {
                    q2_org_l = ( v8i16 ) __msa_ilvl_b( zero, ( v16i8 ) q2_org );
                    AVC_LPF_P1_OR_Q1( p0_org_l, q0_org_l, q1_org_l, q2_org_l,
                                      i16_negatetc_l, tc_l, q1_l );
                }
            }

            if( !__msa_test_bz_v( is_less_than_beta ) )
            {
                q1 = ( v16u8 ) __msa_pckev_b( ( v16i8 ) q1_l, ( v16i8 ) q1_r );
                q1_org = __msa_bmnz_v( q1_org, q1, is_less_than_beta );

                is_less_than_beta = __msa_andi_b( is_less_than_beta, 1 );
                tc = tc + is_less_than_beta;
            }

            {
                v8i16 threshold_r, negate_thresh_r;
                v8i16 threshold_l, negate_thresh_l;
                v16i8 negate_thresh, sign_negate_thresh;

                negate_thresh = zero - ( v16i8 ) tc;
                sign_negate_thresh = __msa_clti_s_b( negate_thresh, 0 );

                ILVR_B2_SH( zero, tc, sign_negate_thresh, negate_thresh,
                            threshold_r, negate_thresh_r );

                AVC_LPF_P0Q0( q0_org_r, p0_org_r, p1_org_r, q1_org_r,
                              negate_thresh_r, threshold_r, p0_r, q0_r );

                threshold_l = ( v8i16 ) __msa_ilvl_b( zero, ( v16i8 ) tc );
                negate_thresh_l = ( v8i16 ) __msa_ilvl_b( sign_negate_thresh,
                                                          negate_thresh );

                AVC_LPF_P0Q0( q0_org_l, p0_org_l, p1_org_l, q1_org_l,
                              negate_thresh_l, threshold_l, p0_l, q0_l );
            }

            PCKEV_B2_UB( p0_l, p0_r, q0_l, q0_r, p0, q0 );

            p0_org = __msa_bmnz_v( p0_org, p0, is_less_than );
            q0_org = __msa_bmnz_v( q0_org, q0, is_less_than );
        }
        {
            v16i8 tp0, tp1, tp2, tp3;
            v8i16 tmp2, tmp5;
            v4i32 tmp3, tmp4, tmp6, tmp7;
            uint32_t u_out0, u_out2;
            uint16_t u_out1, u_out3;

            p_src = p_data - 3;

            ILVRL_B2_SB( p1_org, p2_org, tp0, tp2 );
            ILVRL_B2_SB( q0_org, p0_org, tp1, tp3 );
            ILVRL_B2_SH( q2_org, q1_org, tmp2, tmp5 );

            ILVRL_H2_SW( tp1, tp0, tmp3, tmp4 );
            ILVRL_H2_SW( tp3, tp2, tmp6, tmp7 );

            u_out0 = __msa_copy_u_w( tmp3, 0 );
            u_out1 = __msa_copy_u_h( tmp2, 0 );
            u_out2 = __msa_copy_u_w( tmp3, 1 );
            u_out3 = __msa_copy_u_h( tmp2, 1 );

            SW( u_out0, p_src );
            SH( u_out1, ( p_src + 4 ) );
            p_src += u_img_width;
            SW( u_out2, p_src );
            SH( u_out3, ( p_src + 4 ) );

            u_out0 = __msa_copy_u_w( tmp3, 2 );
            u_out1 = __msa_copy_u_h( tmp2, 2 );
            u_out2 = __msa_copy_u_w( tmp3, 3 );
            u_out3 = __msa_copy_u_h( tmp2, 3 );

            p_src += u_img_width;
            SW( u_out0, p_src );
            SH( u_out1, ( p_src + 4 ) );
            p_src += u_img_width;
            SW( u_out2, p_src );
            SH( u_out3, ( p_src + 4 ) );

            u_out0 = __msa_copy_u_w( tmp4, 0 );
            u_out1 = __msa_copy_u_h( tmp2, 4 );
            u_out2 = __msa_copy_u_w( tmp4, 1 );
            u_out3 = __msa_copy_u_h( tmp2, 5 );

            p_src += u_img_width;
            SW( u_out0, p_src );
            SH( u_out1, ( p_src + 4 ) );
            p_src += u_img_width;
            SW( u_out2, p_src );
            SH( u_out3, ( p_src + 4 ) );

            u_out0 = __msa_copy_u_w( tmp4, 2 );
            u_out1 = __msa_copy_u_h( tmp2, 6 );
            u_out2 = __msa_copy_u_w( tmp4, 3 );
            u_out3 = __msa_copy_u_h( tmp2, 7 );

            p_src += u_img_width;
            SW( u_out0, p_src );
            SH( u_out1, ( p_src + 4 ) );
            p_src += u_img_width;
            SW( u_out2, p_src );
            SH( u_out3, ( p_src + 4 ) );

            u_out0 = __msa_copy_u_w( tmp6, 0 );
            u_out1 = __msa_copy_u_h( tmp5, 0 );
            u_out2 = __msa_copy_u_w( tmp6, 1 );
            u_out3 = __msa_copy_u_h( tmp5, 1 );

            p_src += u_img_width;
            SW( u_out0, p_src );
            SH( u_out1, ( p_src + 4 ) );
            p_src += u_img_width;
            SW( u_out2, p_src );
            SH( u_out3, ( p_src + 4 ) );

            u_out0 = __msa_copy_u_w( tmp6, 2 );
            u_out1 = __msa_copy_u_h( tmp5, 2 );
            u_out2 = __msa_copy_u_w( tmp6, 3 );
            u_out3 = __msa_copy_u_h( tmp5, 3 );

            p_src += u_img_width;
            SW( u_out0, p_src );
            SH( u_out1, ( p_src + 4 ) );
            p_src += u_img_width;
            SW( u_out2, p_src );
            SH( u_out3, ( p_src + 4 ) );

            u_out0 = __msa_copy_u_w( tmp7, 0 );
            u_out1 = __msa_copy_u_h( tmp5, 4 );
            u_out2 = __msa_copy_u_w( tmp7, 1 );
            u_out3 = __msa_copy_u_h( tmp5, 5 );

            p_src += u_img_width;
            SW( u_out0, p_src );
            SH( u_out1, ( p_src + 4 ) );
            p_src += u_img_width;
            SW( u_out2, p_src );
            SH( u_out3, ( p_src + 4 ) );

            u_out0 = __msa_copy_u_w( tmp7, 2 );
            u_out1 = __msa_copy_u_h( tmp5, 6 );
            u_out2 = __msa_copy_u_w( tmp7, 3 );
            u_out3 = __msa_copy_u_h( tmp5, 7 );

            p_src += u_img_width;
            SW( u_out0, p_src );
            SH( u_out1, ( p_src + 4 ) );
            p_src += u_img_width;
            SW( u_out2, p_src );
            SH( u_out3, ( p_src + 4 ) );
        }
    }
}

static void avc_loopfilter_luma_inter_edge_hor_msa( uint8_t *p_data,
                                                    uint8_t u_bs0,
                                                    uint8_t u_bs1,
                                                    uint8_t u_bs2,
                                                    uint8_t u_bs3,
                                                    uint8_t u_tc0,
                                                    uint8_t u_tc1,
                                                    uint8_t u_tc2,
                                                    uint8_t u_tc3,
                                                    uint8_t u_alpha_in,
                                                    uint8_t u_beta_in,
                                                    uint32_t u_image_width )
{
    v16u8 p2_asub_p0, u8_q2asub_q0;
    v16u8 alpha, beta, is_less_than, is_less_than_beta;
    v16u8 p1, p0, q0, q1;
    v8i16 p1_r = { 0 };
    v8i16 p0_r, q0_r, q1_r = { 0 };
    v8i16 p1_l = { 0 };
    v8i16 p0_l, q0_l, q1_l = { 0 };
    v16u8 p2_org, p1_org, p0_org, q0_org, q1_org, q2_org;
    v8i16 p2_org_r, p1_org_r, p0_org_r, q0_org_r, q1_org_r, q2_org_r;
    v8i16 p2_org_l, p1_org_l, p0_org_l, q0_org_l, q1_org_l, q2_org_l;
    v16i8 zero = { 0 };
    v16u8 tmp_vec;
    v16u8 bs = { 0 };
    v16i8 tc = { 0 };

    tmp_vec = ( v16u8 ) __msa_fill_b( u_bs0 );
    bs = ( v16u8 ) __msa_insve_w( ( v4i32 ) bs, 0, ( v4i32 ) tmp_vec );
    tmp_vec = ( v16u8 ) __msa_fill_b( u_bs1 );
    bs = ( v16u8 ) __msa_insve_w( ( v4i32 ) bs, 1, ( v4i32 ) tmp_vec );
    tmp_vec = ( v16u8 ) __msa_fill_b( u_bs2 );
    bs = ( v16u8 ) __msa_insve_w( ( v4i32 ) bs, 2, ( v4i32 ) tmp_vec );
    tmp_vec = ( v16u8 ) __msa_fill_b( u_bs3 );
    bs = ( v16u8 ) __msa_insve_w( ( v4i32 ) bs, 3, ( v4i32 ) tmp_vec );

    if( !__msa_test_bz_v( bs ) )
    {
        tmp_vec = ( v16u8 ) __msa_fill_b( u_tc0 );
        tc = ( v16i8 ) __msa_insve_w( ( v4i32 ) tc, 0, ( v4i32 ) tmp_vec );
        tmp_vec = ( v16u8 ) __msa_fill_b( u_tc1 );
        tc = ( v16i8 ) __msa_insve_w( ( v4i32 ) tc, 1, ( v4i32 ) tmp_vec );
        tmp_vec = ( v16u8 ) __msa_fill_b( u_tc2 );
        tc = ( v16i8 ) __msa_insve_w( ( v4i32 ) tc, 2, ( v4i32 ) tmp_vec );
        tmp_vec = ( v16u8 ) __msa_fill_b( u_tc3 );
        tc = ( v16i8 ) __msa_insve_w( ( v4i32 ) tc, 3, ( v4i32 ) tmp_vec );

        alpha = ( v16u8 ) __msa_fill_b( u_alpha_in );
        beta = ( v16u8 ) __msa_fill_b( u_beta_in );

        LD_UB5( p_data - ( 3 * u_image_width ), u_image_width,
                p2_org, p1_org, p0_org, q0_org, q1_org );

        {
            v16u8 p0_asub_q0, p1_asub_p0, q1_asub_q0;
            v16u8 is_less_than_alpha, is_bs_greater_than0;

            is_bs_greater_than0 = ( ( v16u8 ) zero < bs );
            p0_asub_q0 = __msa_asub_u_b( p0_org, q0_org );
            p1_asub_p0 = __msa_asub_u_b( p1_org, p0_org );
            q1_asub_q0 = __msa_asub_u_b( q1_org, q0_org );

            is_less_than_alpha = ( p0_asub_q0 < alpha );
            is_less_than_beta = ( p1_asub_p0 < beta );
            is_less_than = is_less_than_beta & is_less_than_alpha;
            is_less_than_beta = ( q1_asub_q0 < beta );
            is_less_than = is_less_than_beta & is_less_than;
            is_less_than = is_less_than & is_bs_greater_than0;
        }

        if( !__msa_test_bz_v( is_less_than ) )
        {
            v16i8 sign_negate_tc, negate_tc;
            v8i16 negate_tc_r, i16_negatetc_l, tc_l, tc_r;

            q2_org = LD_UB( p_data + ( 2 * u_image_width ) );
            negate_tc = zero - tc;
            sign_negate_tc = __msa_clti_s_b( negate_tc, 0 );

            ILVRL_B2_SH( sign_negate_tc, negate_tc,
                         negate_tc_r, i16_negatetc_l );

            UNPCK_UB_SH( tc, tc_r, tc_l );
            UNPCK_UB_SH( p1_org, p1_org_r, p1_org_l );
            UNPCK_UB_SH( p0_org, p0_org_r, p0_org_l );
            UNPCK_UB_SH( q0_org, q0_org_r, q0_org_l );

            p2_asub_p0 = __msa_asub_u_b( p2_org, p0_org );
            is_less_than_beta = ( p2_asub_p0 < beta );
            is_less_than_beta = is_less_than_beta & is_less_than;
            {
                v8u16 is_less_than_beta_r, is_less_than_beta_l;

                is_less_than_beta_r =
                    ( v8u16 ) __msa_sldi_b( ( v16i8 ) is_less_than_beta,
                                            zero, 8 );
                if( !__msa_test_bz_v( ( v16u8 ) is_less_than_beta_r ) )
                {
                    p2_org_r = ( v8i16 ) __msa_ilvr_b( zero, ( v16i8 ) p2_org );

                    AVC_LPF_P1_OR_Q1( p0_org_r, q0_org_r, p1_org_r, p2_org_r,
                                      negate_tc_r, tc_r, p1_r );
                }

                is_less_than_beta_l =
                    ( v8u16 ) __msa_sldi_b( zero,
                                            ( v16i8 ) is_less_than_beta, 8 );
                if( !__msa_test_bz_v( ( v16u8 ) is_less_than_beta_l ) )
                {
                    p2_org_l = ( v8i16 ) __msa_ilvl_b( zero, ( v16i8 ) p2_org );

                    AVC_LPF_P1_OR_Q1( p0_org_l, q0_org_l, p1_org_l, p2_org_l,
                                      i16_negatetc_l, tc_l, p1_l );
                }
            }
            if( !__msa_test_bz_v( is_less_than_beta ) )
            {
                p1 = ( v16u8 ) __msa_pckev_b( ( v16i8 ) p1_l, ( v16i8 ) p1_r );
                p1_org = __msa_bmnz_v( p1_org, p1, is_less_than_beta );
                ST_UB( p1_org, p_data - ( 2 * u_image_width ) );

                is_less_than_beta = __msa_andi_b( is_less_than_beta, 1 );
                tc = tc + ( v16i8 ) is_less_than_beta;
            }

            u8_q2asub_q0 = __msa_asub_u_b( q2_org, q0_org );
            is_less_than_beta = ( u8_q2asub_q0 < beta );
            is_less_than_beta = is_less_than_beta & is_less_than;

            {
                v8u16 is_less_than_beta_r, is_less_than_beta_l;
                is_less_than_beta_r =
                    ( v8u16 ) __msa_sldi_b( ( v16i8 ) is_less_than_beta,
                                            zero, 8 );

                q1_org_r = ( v8i16 ) __msa_ilvr_b( zero, ( v16i8 ) q1_org );
                if( !__msa_test_bz_v( ( v16u8 ) is_less_than_beta_r ) )
                {
                    q2_org_r = ( v8i16 ) __msa_ilvr_b( zero, ( v16i8 ) q2_org );

                    AVC_LPF_P1_OR_Q1( p0_org_r, q0_org_r, q1_org_r, q2_org_r,
                                      negate_tc_r, tc_r, q1_r );
                }
                is_less_than_beta_l =
                    ( v8u16 ) __msa_sldi_b( zero,
                                            ( v16i8 ) is_less_than_beta, 8 );

                q1_org_l = ( v8i16 ) __msa_ilvl_b( zero, ( v16i8 ) q1_org );
                if( !__msa_test_bz_v( ( v16u8 ) is_less_than_beta_l ) )
                {
                    q2_org_l = ( v8i16 ) __msa_ilvl_b( zero, ( v16i8 ) q2_org );

                    AVC_LPF_P1_OR_Q1( p0_org_l, q0_org_l, q1_org_l, q2_org_l,
                                      i16_negatetc_l, tc_l, q1_l );
                }
            }
            if( !__msa_test_bz_v( is_less_than_beta ) )
            {
                q1 = ( v16u8 ) __msa_pckev_b( ( v16i8 ) q1_l, ( v16i8 ) q1_r );
                q1_org = __msa_bmnz_v( q1_org, q1, is_less_than_beta );
                ST_UB( q1_org, p_data + u_image_width );

                is_less_than_beta = __msa_andi_b( is_less_than_beta, 1 );
                tc = tc + ( v16i8 ) is_less_than_beta;
            }
            {
                v16i8 negate_thresh, sign_negate_thresh;
                v8i16 threshold_r, threshold_l;
                v8i16 negate_thresh_l, negate_thresh_r;

                negate_thresh = zero - tc;
                sign_negate_thresh = __msa_clti_s_b( negate_thresh, 0 );

                ILVR_B2_SH( zero, tc, sign_negate_thresh, negate_thresh,
                            threshold_r, negate_thresh_r );
                AVC_LPF_P0Q0( q0_org_r, p0_org_r, p1_org_r, q1_org_r,
                              negate_thresh_r, threshold_r, p0_r, q0_r );

                threshold_l = ( v8i16 ) __msa_ilvl_b( zero, tc );
                negate_thresh_l = ( v8i16 ) __msa_ilvl_b( sign_negate_thresh,
                                                          negate_thresh );
                AVC_LPF_P0Q0( q0_org_l, p0_org_l, p1_org_l, q1_org_l,
                              negate_thresh_l, threshold_l, p0_l, q0_l );
            }

            PCKEV_B2_UB( p0_l, p0_r, q0_l, q0_r, p0, q0 );

            p0_org = __msa_bmnz_v( p0_org, p0, is_less_than );
            q0_org = __msa_bmnz_v( q0_org, q0, is_less_than );

            ST_UB( p0_org, ( p_data - u_image_width ) );
            ST_UB( q0_org, p_data );
        }
    }
}

static void avc_lpf_cbcr_interleaved_inter_edge_hor_msa( uint8_t *p_chroma,
                                                         uint8_t u_bs0,
                                                         uint8_t u_bs1,
                                                         uint8_t u_bs2,
                                                         uint8_t u_bs3,
                                                         uint8_t u_tc0,
                                                         uint8_t u_tc1,
                                                         uint8_t u_tc2,
                                                         uint8_t u_tc3,
                                                         uint8_t u_alpha_in,
                                                         uint8_t u_beta_in,
                                                         uint32_t u_img_width )
{
    v16u8 alpha, beta;
    v4i32 tmp_vec, bs = { 0 };
    v4i32 tc = { 0 };
    v16u8 p0_asub_q0, p1_asub_p0, q1_asub_q0;
    v16u8 is_less_than;
    v8i16 is_less_than_r, is_less_than_l;
    v16u8 is_less_than_beta, is_less_than_alpha, is_bs_greater_than0;
    v16u8 p0, q0;
    v8i16 p0_r = { 0 };
    v8i16 q0_r = { 0 };
    v8i16 p0_l = { 0 };
    v8i16 q0_l = { 0 };
    v16u8 p1_org, p0_org, q0_org, q1_org;
    v8i16 p1_org_r, p0_org_r, q0_org_r, q1_org_r;
    v16i8 negate_tc, sign_negate_tc;
    v8i16 negate_tc_r, i16_negatetc_l;
    v8i16 tc_r, tc_l;
    v16i8 zero = { 0 };
    v8i16 p1_org_l, p0_org_l, q0_org_l, q1_org_l;

    tmp_vec = ( v4i32 ) __msa_fill_b( u_bs0 );
    bs = __msa_insve_w( bs, 0, tmp_vec );
    tmp_vec = ( v4i32 ) __msa_fill_b( u_bs1 );
    bs = __msa_insve_w( bs, 1, tmp_vec );
    tmp_vec = ( v4i32 ) __msa_fill_b( u_bs2 );
    bs = __msa_insve_w( bs, 2, tmp_vec );
    tmp_vec = ( v4i32 ) __msa_fill_b( u_bs3 );
    bs = __msa_insve_w( bs, 3, tmp_vec );

    if( !__msa_test_bz_v( ( v16u8 ) bs ) )
    {
        tmp_vec = ( v4i32 ) __msa_fill_b( u_tc0 );
        tc = __msa_insve_w( tc, 0, tmp_vec );
        tmp_vec = ( v4i32 ) __msa_fill_b( u_tc1 );
        tc = __msa_insve_w( tc, 1, tmp_vec );
        tmp_vec = ( v4i32 ) __msa_fill_b( u_tc2 );
        tc = __msa_insve_w( tc, 2, tmp_vec );
        tmp_vec = ( v4i32 ) __msa_fill_b( u_tc3 );
        tc = __msa_insve_w( tc, 3, tmp_vec );

        is_bs_greater_than0 = ( v16u8 ) ( zero < ( v16i8 ) bs );

        alpha = ( v16u8 ) __msa_fill_b( u_alpha_in );
        beta = ( v16u8 ) __msa_fill_b( u_beta_in );

        LD_UB4( p_chroma - ( u_img_width << 1 ), u_img_width,
                p1_org, p0_org, q0_org, q1_org );

        p0_asub_q0 = __msa_asub_u_b( p0_org, q0_org );
        p1_asub_p0 = __msa_asub_u_b( p1_org, p0_org );
        q1_asub_q0 = __msa_asub_u_b( q1_org, q0_org );

        is_less_than_alpha = ( p0_asub_q0 < alpha );
        is_less_than_beta = ( p1_asub_p0 < beta );
        is_less_than = is_less_than_beta & is_less_than_alpha;
        is_less_than_beta = ( q1_asub_q0 < beta );
        is_less_than = is_less_than_beta & is_less_than;

        is_less_than = is_less_than & is_bs_greater_than0;

        if( !__msa_test_bz_v( is_less_than ) )
        {
            negate_tc = zero - ( v16i8 ) tc;
            sign_negate_tc = __msa_clti_s_b( negate_tc, 0 );

            ILVRL_B2_SH( sign_negate_tc, negate_tc, negate_tc_r,
                         i16_negatetc_l );

            UNPCK_UB_SH( tc, tc_r, tc_l );
            UNPCK_UB_SH( p1_org, p1_org_r, p1_org_l );
            UNPCK_UB_SH( p0_org, p0_org_r, p0_org_l );
            UNPCK_UB_SH( q0_org, q0_org_r, q0_org_l );
            UNPCK_UB_SH( q1_org, q1_org_r, q1_org_l );

            is_less_than_r =
                ( v8i16 ) __msa_sldi_b( ( v16i8 ) is_less_than, zero, 8 );
            if( !__msa_test_bz_v( ( v16u8 ) is_less_than_r ) )
            {
                AVC_LPF_P0Q0( q0_org_r, p0_org_r, p1_org_r, q1_org_r,
                              negate_tc_r, tc_r, p0_r, q0_r );
            }

            is_less_than_l =
                ( v8i16 ) __msa_sldi_b( zero, ( v16i8 ) is_less_than, 8 );
            if( !__msa_test_bz_v( ( v16u8 ) is_less_than_l ) )
            {
                AVC_LPF_P0Q0( q0_org_l, p0_org_l, p1_org_l, q1_org_l,
                              i16_negatetc_l, tc_l, p0_l, q0_l );
            }

            PCKEV_B2_UB( p0_l, p0_r, q0_l, q0_r, p0, q0 );

            p0_org = __msa_bmnz_v( p0_org, p0, is_less_than );
            q0_org = __msa_bmnz_v( q0_org, q0, is_less_than );

            ST_UB( p0_org, p_chroma - u_img_width );
            ST_UB( q0_org, p_chroma );
        }
    }
}

static void avc_lpf_cbcr_interleaved_inter_edge_ver_msa( uint8_t *p_chroma,
                                                         uint8_t u_bs0,
                                                         uint8_t u_bs1,
                                                         uint8_t u_bs2,
                                                         uint8_t u_bs3,
                                                         uint8_t u_tc0,
                                                         uint8_t u_tc1,
                                                         uint8_t u_tc2,
                                                         uint8_t u_tc3,
                                                         uint8_t u_alpha_in,
                                                         uint8_t u_beta_in,
                                                         uint32_t u_img_width )
{
    v16u8 alpha, beta;
    v16u8 p0, q0, p0_asub_q0, p1_asub_p0, q1_asub_q0;
    v16u8 is_less_than, is_less_than1;
    v8i16 is_less_than_r, is_less_than_l;
    v16u8 is_less_than_beta, is_less_than_alpha;
    v8i16 p0_r = { 0 };
    v8i16 q0_r = { 0 };
    v8i16 p0_l = { 0 };
    v8i16 q0_l = { 0 };
    v16u8 p1_org, p0_org, q0_org, q1_org;
    v8i16 p1_org_r, p0_org_r, q0_org_r, q1_org_r;
    v8i16 p1_org_l, p0_org_l, q0_org_l, q1_org_l;
    v16u8 is_bs_less_than4, is_bs_greater_than0;
    v8i16 tc_r, tc_l, negate_tc_r, i16_negatetc_l;
    v16u8 const4;
    v16i8 zero = { 0 };
    v8i16 tmp_vec, bs = { 0 };
    v8i16 tc = { 0 };
    v16u8 p1_u_org, p0_u_org, q0_u_org, q1_u_org;
    v16u8 p1_v_org, p0_v_org, q0_v_org, q1_v_org;
    v16i8 tmp0, tmp1, tmp2, tmp3;
    v4i32 vec0, vec1;
    v16u8 row0, row1, row2, row3, row4, row5, row6, row7;
    v16i8 negate_tc, sign_negate_tc;

    const4 = ( v16u8 ) __msa_ldi_b( 4 );

    tmp_vec = ( v8i16 ) __msa_fill_b( u_bs0 );
    bs = __msa_insve_h( bs, 0, tmp_vec );
    bs = __msa_insve_h( bs, 4, tmp_vec );

    tmp_vec = ( v8i16 ) __msa_fill_b( u_bs1 );
    bs = __msa_insve_h( bs, 1, tmp_vec );
    bs = __msa_insve_h( bs, 5, tmp_vec );

    tmp_vec = ( v8i16 ) __msa_fill_b( u_bs2 );
    bs = __msa_insve_h( bs, 2, tmp_vec );
    bs = __msa_insve_h( bs, 6, tmp_vec );

    tmp_vec = ( v8i16 ) __msa_fill_b( u_bs3 );
    bs = __msa_insve_h( bs, 3, tmp_vec );
    bs = __msa_insve_h( bs, 7, tmp_vec );

    if( !__msa_test_bz_v( ( v16u8 ) bs ) )
    {
        tmp_vec = ( v8i16 ) __msa_fill_b( u_tc0 );
        tc = __msa_insve_h( tc, 0, tmp_vec );
        tc = __msa_insve_h( tc, 4, tmp_vec );

        tmp_vec = ( v8i16 ) __msa_fill_b( u_tc1 );
        tc = __msa_insve_h( tc, 1, tmp_vec );
        tc = __msa_insve_h( tc, 5, tmp_vec );

        tmp_vec = ( v8i16 ) __msa_fill_b( u_tc2 );
        tc = __msa_insve_h( tc, 2, tmp_vec );
        tc = __msa_insve_h( tc, 6, tmp_vec );

        tmp_vec = ( v8i16 ) __msa_fill_b( u_tc3 );
        tc = __msa_insve_h( tc, 3, tmp_vec );
        tc = __msa_insve_h( tc, 7, tmp_vec );

        is_bs_greater_than0 = ( v16u8 ) ( zero < ( v16i8 ) bs );

        LD_UB8( ( p_chroma - 4 ), u_img_width,
                row0, row1, row2, row3, row4, row5, row6, row7 );

        TRANSPOSE8x8_UB_UB( row0, row1, row2, row3,
                            row4, row5, row6, row7,
                            p1_u_org, p1_v_org, p0_u_org, p0_v_org,
                            q0_u_org, q0_v_org, q1_u_org, q1_v_org );

        ILVR_D4_UB( p1_v_org, p1_u_org, p0_v_org, p0_u_org, q0_v_org, q0_u_org,
                    q1_v_org, q1_u_org, p1_org, p0_org, q0_org, q1_org );

        p0_asub_q0 = __msa_asub_u_b( p0_org, q0_org );
        p1_asub_p0 = __msa_asub_u_b( p1_org, p0_org );
        q1_asub_q0 = __msa_asub_u_b( q1_org, q0_org );

        alpha = ( v16u8 ) __msa_fill_b( u_alpha_in );
        beta = ( v16u8 ) __msa_fill_b( u_beta_in );

        is_less_than_alpha = ( p0_asub_q0 < alpha );
        is_less_than_beta = ( p1_asub_p0 < beta );
        is_less_than = is_less_than_beta & is_less_than_alpha;
        is_less_than_beta = ( q1_asub_q0 < beta );
        is_less_than = is_less_than_beta & is_less_than;
        is_less_than = is_bs_greater_than0 & is_less_than;

        if( !__msa_test_bz_v( is_less_than ) )
        {
            UNPCK_UB_SH( p1_org, p1_org_r, p1_org_l );
            UNPCK_UB_SH( p0_org, p0_org_r, p0_org_l );
            UNPCK_UB_SH( q0_org, q0_org_r, q0_org_l );
            UNPCK_UB_SH( q1_org, q1_org_r, q1_org_l );

            is_bs_less_than4 = ( ( v16u8 ) bs < const4 );

            is_less_than1 = is_less_than & is_bs_less_than4;
            if( !__msa_test_bz_v( ( v16u8 ) is_less_than1 ) )
            {
                negate_tc = zero - ( v16i8 ) tc;
                sign_negate_tc = __msa_clti_s_b( negate_tc, 0 );

                ILVRL_B2_SH( sign_negate_tc, negate_tc, negate_tc_r,
                             i16_negatetc_l );

                UNPCK_UB_SH( tc, tc_r, tc_l );

                is_less_than_r =
                    ( v8i16 ) __msa_sldi_b( ( v16i8 ) is_less_than1, zero, 8 );
                if( !__msa_test_bz_v( ( v16u8 ) is_less_than_r ) )
                {
                    AVC_LPF_P0Q0( q0_org_r, p0_org_r, p1_org_r, q1_org_r,
                                  negate_tc_r, tc_r, p0_r, q0_r );
                }

                is_less_than_l =
                    ( v8i16 ) __msa_sldi_b( zero, ( v16i8 ) is_less_than1, 8 );
                if( !__msa_test_bz_v( ( v16u8 ) is_less_than_l ) )
                {
                    AVC_LPF_P0Q0( q0_org_l, p0_org_l, p1_org_l, q1_org_l,
                                  i16_negatetc_l, tc_l, p0_l, q0_l );
                }

                PCKEV_B2_UB( p0_l, p0_r, q0_l, q0_r, p0, q0 );

                p0_org = __msa_bmnz_v( p0_org, p0, is_less_than1 );
                q0_org = __msa_bmnz_v( q0_org, q0, is_less_than1 );
            }

            SLDI_B2_0_UB( p0_org, q0_org, p0_v_org, q0_v_org, 8 );
            ILVR_D2_SB( p0_v_org, p0_org, q0_v_org, q0_org, tmp0, tmp1 );
            ILVRL_B2_SB( tmp1, tmp0, tmp2, tmp3 );
            ILVRL_B2_SW( tmp3, tmp2, vec0, vec1 );
            ST4x8_UB( vec0, vec1, ( p_chroma - 2 ), u_img_width );
        }
    }
}

static void avc_deblock_strength_msa( uint8_t *nnz,
                                      int8_t pi_ref[2][X264_SCAN8_LUMA_SIZE],
                                      int16_t pi_mv[2][X264_SCAN8_LUMA_SIZE][2],
                                      uint8_t pu_bs[2][8][4],
                                      int32_t i_mvy_limit )
{
    uint32_t u_tmp;
    v16u8 nnz0, nnz1, nnz2, nnz3, nnz4;
    v16u8 nnz_mask, ref_mask, mask, one, two, dst = { 0 };
    v16i8 ref0, ref1, ref2, ref3, ref4;
    v16i8 temp_vec0, temp_vec1, temp_vec4, temp_vec5;
    v8i16 mv0, mv1, mv2, mv3, mv4, mv5, mv6, mv7, mv8, mv9, mv_a, mv_b;
    v8u16 four, mvy_limit_vec, sub0, sub1;

    nnz0 = LD_UB( nnz + 4 );
    nnz2 = LD_UB( nnz + 20 );
    nnz4 = LD_UB( nnz + 36 );

    ref0 = LD_SB( pi_ref[0] + 4 );
    ref2 = LD_SB( pi_ref[0] + 20 );
    ref4 = LD_SB( pi_ref[0] + 36 );

    mv0 = LD_SH( ( pi_mv[0] + 4 )[0] );
    mv1 = LD_SH( ( pi_mv[0] + 12 )[0] );
    mv2 = LD_SH( ( pi_mv[0] + 20 )[0] );
    mv3 = LD_SH( ( pi_mv[0] + 28 )[0] );
    mv4 = LD_SH( ( pi_mv[0] + 36 )[0] );

    mvy_limit_vec = ( v8u16 ) __msa_fill_h( i_mvy_limit );
    four = ( v8u16 ) __msa_fill_h( 4 );
    mask = ( v16u8 ) __msa_ldi_b( 0 );
    one = ( v16u8 ) __msa_ldi_b( 1 );
    two = ( v16u8 ) __msa_ldi_b( 2 );

    mv5 = __msa_pckod_h( mv0, mv0 );
    mv6 = __msa_pckod_h( mv1, mv1 );
    mv_a = __msa_pckev_h( mv0, mv0 );
    mv_b = __msa_pckev_h( mv1, mv1 );
    nnz1 = ( v16u8 ) __msa_splati_w( ( v4i32 ) nnz0, 2 );
    ref1 = ( v16i8 ) __msa_splati_w( ( v4i32 ) ref0, 2 );
    nnz_mask = nnz0 | nnz1;
    nnz_mask = ( v16u8 ) __msa_ceq_b( ( v16i8 ) mask, ( v16i8 ) nnz_mask );
    two = __msa_bmnz_v( two, mask, nnz_mask );

    ref_mask = ( v16u8 ) __msa_ceq_b( ref0, ref1 );
    ref_mask = ref_mask ^ 255;

    sub0 = ( v8u16 ) __msa_asub_s_h( mv_b, mv_a );
    sub1 = ( v8u16 ) __msa_asub_s_h( mv6, mv5 );

    sub0 = ( v8u16 ) __msa_cle_u_h( four, sub0 );
    sub1 = ( v8u16 ) __msa_cle_u_h( mvy_limit_vec, sub1 );

    ref_mask |= ( v16u8 ) __msa_pckev_b( ( v16i8 ) sub0, ( v16i8 ) sub0 );
    ref_mask |= ( v16u8 ) __msa_pckev_b( ( v16i8 ) sub1, ( v16i8 ) sub1 );

    dst = __msa_bmnz_v( dst, one, ref_mask );
    dst = __msa_bmnz_v( two, dst, nnz_mask );

    u_tmp = __msa_copy_u_w( ( v4i32 ) dst, 0 );
    SW( u_tmp, pu_bs[1][0] );

    dst = ( v16u8 ) __msa_ldi_b( 0 );
    two = ( v16u8 ) __msa_ldi_b( 2 );

    mv5 = __msa_pckod_h( mv1, mv1 );
    mv6 = __msa_pckod_h( mv2, mv2 );
    mv_a = __msa_pckev_h( mv1, mv1 );
    mv_b = __msa_pckev_h( mv2, mv2 );

    nnz_mask = nnz2 | nnz1;
    nnz_mask = ( v16u8 ) __msa_ceq_b( ( v16i8 ) mask, ( v16i8 ) nnz_mask );
    two = __msa_bmnz_v( two, mask, nnz_mask );

    ref_mask = ( v16u8 ) __msa_ceq_b( ref1, ref2 );
    ref_mask = ref_mask ^ 255;

    sub0 = ( v8u16 ) __msa_asub_s_h( mv_b, mv_a );
    sub1 = ( v8u16 ) __msa_asub_s_h( mv6, mv5 );
    sub0 = ( v8u16 ) __msa_cle_u_h( four, sub0 );
    sub1 = ( v8u16 ) __msa_cle_u_h( mvy_limit_vec, sub1 );

    ref_mask |= ( v16u8 ) __msa_pckev_b( ( v16i8 ) sub0, ( v16i8 ) sub0 );
    ref_mask |= ( v16u8 ) __msa_pckev_b( ( v16i8 ) sub1, ( v16i8 ) sub1 );

    dst = __msa_bmnz_v( dst, one, ref_mask );
    dst = __msa_bmnz_v( two, dst, nnz_mask );

    u_tmp = __msa_copy_u_w( ( v4i32 ) dst, 0 );
    SW( u_tmp, pu_bs[1][1] );

    dst = ( v16u8 ) __msa_ldi_b( 0 );
    two = ( v16u8 ) __msa_ldi_b( 2 );

    mv5 = __msa_pckod_h( mv2, mv2 );
    mv6 = __msa_pckod_h( mv3, mv3 );
    mv_a = __msa_pckev_h( mv2, mv2 );
    mv_b = __msa_pckev_h( mv3, mv3 );

    nnz3 = ( v16u8 ) __msa_splati_w( ( v4i32 ) nnz2, 2 );
    ref3 = ( v16i8 ) __msa_splati_w( ( v4i32 ) ref2, 2 );

    nnz_mask = nnz3 | nnz2;
    nnz_mask = ( v16u8 ) __msa_ceq_b( ( v16i8 ) mask, ( v16i8 ) nnz_mask );
    two = __msa_bmnz_v( two, mask, nnz_mask );

    ref_mask = ( v16u8 ) __msa_ceq_b( ref2, ref3 );
    ref_mask = ref_mask ^ 255;

    sub0 = ( v8u16 ) __msa_asub_s_h( mv_b, mv_a );
    sub1 = ( v8u16 ) __msa_asub_s_h( mv6, mv5 );

    sub0 = ( v8u16 ) __msa_cle_u_h( four, sub0 );
    sub1 = ( v8u16 ) __msa_cle_u_h( mvy_limit_vec, sub1 );

    ref_mask |= ( v16u8 ) __msa_pckev_b( ( v16i8 ) sub0, ( v16i8 ) sub0 );
    ref_mask |= ( v16u8 ) __msa_pckev_b( ( v16i8 ) sub1, ( v16i8 ) sub1 );

    dst = __msa_bmnz_v( dst, one, ref_mask );
    dst = __msa_bmnz_v( two, dst, nnz_mask );

    u_tmp = __msa_copy_u_w( ( v4i32 ) dst, 0 );
    SW( u_tmp, pu_bs[1][2] );

    dst = ( v16u8 ) __msa_ldi_b( 0 );
    two = ( v16u8 ) __msa_ldi_b( 2 );

    mv5 = __msa_pckod_h( mv3, mv3 );
    mv6 = __msa_pckod_h( mv4, mv4 );
    mv_a = __msa_pckev_h( mv3, mv3 );
    mv_b = __msa_pckev_h( mv4, mv4 );

    nnz_mask = nnz4 | nnz3;
    nnz_mask = ( v16u8 ) __msa_ceq_b( ( v16i8 ) mask, ( v16i8 ) nnz_mask );
    two = __msa_bmnz_v( two, mask, nnz_mask );

    ref_mask = ( v16u8 ) __msa_ceq_b( ref3, ref4 );
    ref_mask = ref_mask ^ 255;

    sub0 = ( v8u16 ) __msa_asub_s_h( mv_b, mv_a );
    sub1 = ( v8u16 ) __msa_asub_s_h( mv6, mv5 );

    sub0 = ( v8u16 ) __msa_cle_u_h( four, sub0 );
    sub1 = ( v8u16 ) __msa_cle_u_h( mvy_limit_vec, sub1 );

    ref_mask |= ( v16u8 ) __msa_pckev_b( ( v16i8 ) sub0, ( v16i8 ) sub0 );
    ref_mask |= ( v16u8 ) __msa_pckev_b( ( v16i8 ) sub1, ( v16i8 ) sub1 );

    dst = __msa_bmnz_v( dst, one, ref_mask );
    dst = __msa_bmnz_v( two, dst, nnz_mask );

    u_tmp = __msa_copy_u_w( ( v4i32 ) dst, 0 );
    SW( u_tmp, pu_bs[1][3] );

    nnz0 = LD_UB( nnz + 8 );
    nnz2 = LD_UB( nnz + 24 );

    ref0 = LD_SB( pi_ref[0] + 8 );
    ref2 = LD_SB( pi_ref[0] + 24 );

    mv0 = LD_SH( ( pi_mv[0] + 8 )[0] );
    mv1 = LD_SH( ( pi_mv[0] + 12 )[0] );
    mv2 = LD_SH( ( pi_mv[0] + 16 )[0] );
    mv3 = LD_SH( ( pi_mv[0] + 20 )[0] );
    mv4 = LD_SH( ( pi_mv[0] + 24 )[0] );
    mv7 = LD_SH( ( pi_mv[0] + 28 )[0] );
    mv8 = LD_SH( ( pi_mv[0] + 32 )[0] );
    mv9 = LD_SH( ( pi_mv[0] + 36 )[0] );

    nnz1 = ( v16u8 ) __msa_splati_d( ( v2i64 ) nnz0, 1 );
    nnz3 = ( v16u8 ) __msa_splati_d( ( v2i64 ) nnz2, 1 );

    ILVR_B2_SB( nnz2, nnz0, nnz3, nnz1, temp_vec0, temp_vec1 );

    ILVRL_B2_SB( temp_vec1, temp_vec0, temp_vec5, temp_vec4 );

    nnz0 = ( v16u8 ) __msa_splati_w( ( v4i32 ) temp_vec5, 3 );
    nnz1 = ( v16u8 ) temp_vec4;
    nnz2 = ( v16u8 ) __msa_splati_w( ( v4i32 ) nnz1, 1 );
    nnz3 = ( v16u8 ) __msa_splati_w( ( v4i32 ) nnz1, 2 );
    nnz4 = ( v16u8 ) __msa_splati_w( ( v4i32 ) nnz1, 3 );

    ref1 = ( v16i8 ) __msa_splati_d( ( v2i64 ) ref0, 1 );
    ref3 = ( v16i8 ) __msa_splati_d( ( v2i64 ) ref2, 1 );

    ILVR_B2_SB( ref2, ref0, ref3, ref1, temp_vec0, temp_vec1 );

    ILVRL_B2_SB( temp_vec1, temp_vec0, temp_vec5, ref1 );

    ref0 = ( v16i8 ) __msa_splati_w( ( v4i32 ) temp_vec5, 3 );

    ref2 = ( v16i8 ) __msa_splati_w( ( v4i32 ) ref1, 1 );
    ref3 = ( v16i8 ) __msa_splati_w( ( v4i32 ) ref1, 2 );
    ref4 = ( v16i8 ) __msa_splati_w( ( v4i32 ) ref1, 3 );

    TRANSPOSE8X4_SH_SH( mv0, mv2, mv4, mv8, mv5, mv5, mv5, mv0 );
    TRANSPOSE8X4_SH_SH( mv1, mv3, mv7, mv9, mv1, mv2, mv3, mv4 );

    mvy_limit_vec = ( v8u16 ) __msa_fill_h( i_mvy_limit );
    four = ( v8u16 ) __msa_fill_h( 4 );
    mask = ( v16u8 ) __msa_ldi_b( 0 );
    one = ( v16u8 ) __msa_ldi_b( 1 );
    two = ( v16u8 ) __msa_ldi_b( 2 );
    dst = ( v16u8 ) __msa_ldi_b( 0 );

    mv5 = ( v8i16 ) __msa_splati_d( ( v2i64 ) mv0, 1 );
    mv6 = ( v8i16 ) __msa_splati_d( ( v2i64 ) mv1, 1 );
    mv_a = mv0;
    mv_b = mv1;

    nnz_mask = nnz0 | nnz1;
    nnz_mask = ( v16u8 ) __msa_ceq_b( ( v16i8 ) mask, ( v16i8 ) nnz_mask );
    two = __msa_bmnz_v( two, mask, nnz_mask );

    ref_mask = ( v16u8 ) __msa_ceq_b( ref0, ref1 );
    ref_mask = ref_mask ^ 255;

    sub0 = ( v8u16 ) __msa_asub_s_h( mv_b, mv_a );
    sub1 = ( v8u16 ) __msa_asub_s_h( mv6, mv5 );

    sub0 = ( v8u16 ) __msa_cle_u_h( four, sub0 );
    sub1 = ( v8u16 ) __msa_cle_u_h( mvy_limit_vec, sub1 );

    ref_mask |= ( v16u8 ) __msa_pckev_b( ( v16i8 ) sub0, ( v16i8 ) sub0 );
    ref_mask |= ( v16u8 ) __msa_pckev_b( ( v16i8 ) sub1, ( v16i8 ) sub1 );

    dst = __msa_bmnz_v( dst, one, ref_mask );
    dst = __msa_bmnz_v( two, dst, nnz_mask );

    u_tmp = __msa_copy_u_w( ( v4i32 ) dst, 0 );
    SW( u_tmp, pu_bs[0][0] );

    two = ( v16u8 ) __msa_ldi_b( 2 );
    dst = ( v16u8 ) __msa_ldi_b( 0 );

    mv5 = ( v8i16 ) __msa_splati_d( ( v2i64 ) mv1, 1 );
    mv6 = ( v8i16 ) __msa_splati_d( ( v2i64 ) mv2, 1 );
    mv_a = mv1;
    mv_b = mv2;

    nnz_mask = nnz1 | nnz2;
    nnz_mask = ( v16u8 ) __msa_ceq_b( ( v16i8 ) mask, ( v16i8 ) nnz_mask );
    two = __msa_bmnz_v( two, mask, nnz_mask );

    ref_mask = ( v16u8 ) __msa_ceq_b( ref1, ref2 );
    ref_mask = ref_mask ^ 255;

    sub0 = ( v8u16 ) __msa_asub_s_h( mv_b, mv_a );
    sub1 = ( v8u16 ) __msa_asub_s_h( mv6, mv5 );
    sub0 = ( v8u16 ) __msa_cle_u_h( four, sub0 );
    sub1 = ( v8u16 ) __msa_cle_u_h( mvy_limit_vec, sub1 );

    ref_mask |= ( v16u8 ) __msa_pckev_b( ( v16i8 ) sub0, ( v16i8 ) sub0 );
    ref_mask |= ( v16u8 ) __msa_pckev_b( ( v16i8 ) sub1, ( v16i8 ) sub1 );

    dst = __msa_bmnz_v( dst, one, ref_mask );
    dst = __msa_bmnz_v( two, dst, nnz_mask );

    u_tmp = __msa_copy_u_w( ( v4i32 ) dst, 0 );
    SW( u_tmp, pu_bs[0][1] );

    two = ( v16u8 ) __msa_ldi_b( 2 );
    dst = ( v16u8 ) __msa_ldi_b( 0 );

    mv5 = ( v8i16 ) __msa_splati_d( ( v2i64 ) mv2, 1 );
    mv6 = ( v8i16 ) __msa_splati_d( ( v2i64 ) mv3, 1 );
    mv_a = mv2;
    mv_b = mv3;

    nnz_mask = nnz2 | nnz3;
    nnz_mask = ( v16u8 ) __msa_ceq_b( ( v16i8 ) mask, ( v16i8 ) nnz_mask );
    two = __msa_bmnz_v( two, mask, nnz_mask );

    ref_mask = ( v16u8 ) __msa_ceq_b( ref2, ref3 );
    ref_mask = ref_mask ^ 255;

    sub0 = ( v8u16 ) __msa_asub_s_h( mv_b, mv_a );
    sub1 = ( v8u16 ) __msa_asub_s_h( mv6, mv5 );
    sub0 = ( v8u16 ) __msa_cle_u_h( four, sub0 );
    sub1 = ( v8u16 ) __msa_cle_u_h( mvy_limit_vec, sub1 );

    ref_mask |= ( v16u8 ) __msa_pckev_b( ( v16i8 ) sub0, ( v16i8 ) sub0 );
    ref_mask |= ( v16u8 ) __msa_pckev_b( ( v16i8 ) sub1, ( v16i8 ) sub1 );

    dst = __msa_bmnz_v( dst, one, ref_mask );
    dst = __msa_bmnz_v( two, dst, nnz_mask );

    u_tmp = __msa_copy_u_w( ( v4i32 ) dst, 0 );
    SW( u_tmp, pu_bs[0][2] );

    two = ( v16u8 ) __msa_ldi_b( 2 );
    dst = ( v16u8 ) __msa_ldi_b( 0 );

    mv5 = ( v8i16 ) __msa_splati_d( ( v2i64 ) mv3, 1 );
    mv6 = ( v8i16 ) __msa_splati_d( ( v2i64 ) mv4, 1 );
    mv_a = mv3;
    mv_b = mv4;

    nnz_mask = nnz3 | nnz4;
    nnz_mask = ( v16u8 ) __msa_ceq_b( ( v16i8 ) mask, ( v16i8 ) nnz_mask );
    two = __msa_bmnz_v( two, mask, nnz_mask );

    ref_mask = ( v16u8 ) __msa_ceq_b( ref3, ref4 );
    ref_mask = ref_mask ^ 255;

    sub0 = ( v8u16 ) __msa_asub_s_h( mv_b, mv_a );
    sub1 = ( v8u16 ) __msa_asub_s_h( mv6, mv5 );
    sub0 = ( v8u16 ) __msa_cle_u_h( four, sub0 );
    sub1 = ( v8u16 ) __msa_cle_u_h( mvy_limit_vec, sub1 );

    ref_mask |= ( v16u8 ) __msa_pckev_b( ( v16i8 ) sub0, ( v16i8 ) sub0 );
    ref_mask |= ( v16u8 ) __msa_pckev_b( ( v16i8 ) sub1, ( v16i8 ) sub1 );

    dst = __msa_bmnz_v( dst, one, ref_mask );
    dst = __msa_bmnz_v( two, dst, nnz_mask );

    u_tmp = __msa_copy_u_w( ( v4i32 ) dst, 0 );
    SW( u_tmp, pu_bs[0][3] );
}

void x264_deblock_v_luma_intra_msa( uint8_t *p_pix, intptr_t i_stride,
                                    int32_t i_alpha, int32_t i_beta )
{
    avc_loopfilter_luma_intra_edge_hor_msa( p_pix, ( uint8_t ) i_alpha,
                                            ( uint8_t ) i_beta, i_stride );
}

void x264_deblock_h_luma_intra_msa( uint8_t *p_pix, intptr_t i_stride,
                                    int32_t i_alpha, int32_t i_beta )
{
    avc_loopfilter_luma_intra_edge_ver_msa( p_pix, ( uint8_t ) i_alpha,
                                            ( uint8_t ) i_beta, i_stride );
}

void x264_deblock_v_chroma_intra_msa( uint8_t *p_pix, intptr_t i_stride,
                                      int32_t i_alpha, int32_t i_beta )
{
    avc_lpf_cbcr_interleaved_intra_edge_hor_msa( p_pix, ( uint8_t ) i_alpha,
                                                 ( uint8_t ) i_beta, i_stride );
}

void x264_deblock_h_chroma_intra_msa( uint8_t *p_pix, intptr_t i_stride,
                                      int32_t i_alpha, int32_t i_beta )
{
    avc_lpf_cbcr_interleaved_intra_edge_ver_msa( p_pix, ( uint8_t ) i_alpha,
                                                 ( uint8_t ) i_beta, i_stride );
}

void x264_deblock_h_luma_msa( uint8_t *p_pix, intptr_t i_stride,
                              int32_t i_alpha, int32_t i_beta, int8_t *p_tc0 )
{
    uint8_t u_bs0 = 1;
    uint8_t u_bs1 = 1;
    uint8_t u_bs2 = 1;
    uint8_t u_bs3 = 1;

    if( p_tc0[0] < 0 ) u_bs0 = 0;
    if( p_tc0[1] < 0 ) u_bs1 = 0;
    if( p_tc0[2] < 0 ) u_bs2 = 0;
    if( p_tc0[3] < 0 ) u_bs3 = 0;

    avc_loopfilter_luma_inter_edge_ver_msa( p_pix,
                                            u_bs0, u_bs1, u_bs2, u_bs3,
                                            p_tc0[0], p_tc0[1], p_tc0[2],
                                            p_tc0[3], i_alpha, i_beta,
                                            i_stride );
}

void x264_deblock_v_luma_msa( uint8_t *p_pix, intptr_t i_stride,
                              int32_t i_alpha, int32_t i_beta, int8_t *p_tc0 )
{
    uint8_t u_bs0 = 1;
    uint8_t u_bs1 = 1;
    uint8_t u_bs2 = 1;
    uint8_t u_bs3 = 1;

    if( p_tc0[0] < 0 ) u_bs0 = 0;
    if( p_tc0[1] < 0 ) u_bs1 = 0;
    if( p_tc0[2] < 0 ) u_bs2 = 0;
    if( p_tc0[3] < 0 ) u_bs3 = 0;

    avc_loopfilter_luma_inter_edge_hor_msa( p_pix,
                                            u_bs0, u_bs1, u_bs2, u_bs3,
                                            p_tc0[0], p_tc0[1], p_tc0[2],
                                            p_tc0[3], i_alpha, i_beta,
                                            i_stride );
}

void x264_deblock_v_chroma_msa( uint8_t *p_pix, intptr_t i_stride,
                                int32_t i_alpha, int32_t i_beta, int8_t *p_tc0 )
{
    uint8_t u_bs0 = 1;
    uint8_t u_bs1 = 1;
    uint8_t u_bs2 = 1;
    uint8_t u_bs3 = 1;

    if( p_tc0[0] < 0 ) u_bs0 = 0;
    if( p_tc0[1] < 0 ) u_bs1 = 0;
    if( p_tc0[2] < 0 ) u_bs2 = 0;
    if( p_tc0[3] < 0 ) u_bs3 = 0;

    avc_lpf_cbcr_interleaved_inter_edge_hor_msa( p_pix,
                                                 u_bs0, u_bs1, u_bs2, u_bs3,
                                                 p_tc0[0], p_tc0[1], p_tc0[2],
                                                 p_tc0[3], i_alpha, i_beta,
                                                 i_stride );
}

void x264_deblock_h_chroma_msa( uint8_t *p_pix, intptr_t i_stride,
                                int32_t i_alpha, int32_t i_beta, int8_t *p_tc0 )
{
    uint8_t u_bs0 = 1;
    uint8_t u_bs1 = 1;
    uint8_t u_bs2 = 1;
    uint8_t u_bs3 = 1;

    if( p_tc0[0] < 0 ) u_bs0 = 0;
    if( p_tc0[1] < 0 ) u_bs1 = 0;
    if( p_tc0[2] < 0 ) u_bs2 = 0;
    if( p_tc0[3] < 0 ) u_bs3 = 0;

    avc_lpf_cbcr_interleaved_inter_edge_ver_msa( p_pix,
                                                 u_bs0, u_bs1, u_bs2, u_bs3,
                                                 p_tc0[0], p_tc0[1], p_tc0[2],
                                                 p_tc0[3], i_alpha, i_beta,
                                                 i_stride );
}

void x264_deblock_strength_msa( uint8_t u_nnz[X264_SCAN8_SIZE],
                                int8_t pi_ref[2][X264_SCAN8_LUMA_SIZE],
                                int16_t pi_mv[2][X264_SCAN8_LUMA_SIZE][2],
                                uint8_t pu_bs[2][8][4], int32_t i_mvy_limit,
                                int32_t i_bframe )
{
    if( i_bframe )
    {
        for( int32_t i_dir = 0; i_dir < 2; i_dir++ )
        {
            int32_t s1 = i_dir ? 1 : 8;
            int32_t s2 = i_dir ? 8 : 1;

            for( int32_t i_edge = 0; i_edge < 4; i_edge++ )
            {
                for( int32_t i = 0, loc = X264_SCAN8_0 + i_edge * s2; i < 4;
                     i++, loc += s1 )
                {
                    int32_t locn = loc - s2;
                    if( u_nnz[loc] || u_nnz[locn] )
                    {
                        pu_bs[i_dir][i_edge][i] = 2;
                    }
                    else if( pi_ref[0][loc] != pi_ref[0][locn] ||
                             abs(  pi_mv[0][loc][0] -
                                   pi_mv[0][locn][0]  ) >= 4 ||
                             abs(  pi_mv[0][loc][1] -
                                   pi_mv[0][locn][1]  ) >= i_mvy_limit ||
                             ( i_bframe &&
                                 ( pi_ref[1][loc] != pi_ref[1][locn] ||
                                   abs(  pi_mv[1][loc][0] -
                                         pi_mv[1][locn][0]  ) >= 4 ||
                                   abs(  pi_mv[1][loc][1] -
                                         pi_mv[1][locn][1]  ) >= i_mvy_limit ) )
                           )
                    {
                        pu_bs[i_dir][i_edge][i] = 1;
                    }
                    else
                    {
                        pu_bs[i_dir][i_edge][i] = 0;
                    }
                }
            }
        }
    }
    else
    {
        avc_deblock_strength_msa( u_nnz, pi_ref, pi_mv, pu_bs, i_mvy_limit );
    }
}
#endif
