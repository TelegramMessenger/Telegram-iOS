/*****************************************************************************
 * quant.c: ppc quantization
 *****************************************************************************
 * Copyright (C) 2007-2022 x264 project
 *
 * Authors: Guillaume Poirier <gpoirier@mplayerhq.hu>
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
#include "ppccommon.h"
#include "quant.h"

#if !HIGH_BIT_DEPTH
// quant of a whole 4x4 block, unrolled 2x and "pre-scheduled"
#define QUANT_16_U( idx0, idx1 )                                    \
{                                                                   \
    temp1v = vec_ld((idx0), dct);                                   \
    temp2v = vec_ld((idx1), dct);                                   \
    mfvA = vec_ld((idx0), mf);                                      \
    mfvB = vec_ld((idx1), mf);                                      \
    biasvA = vec_ld((idx0), bias);                                  \
    biasvB = vec_ld((idx1), bias);                                  \
    mskA = vec_cmplt(temp1v, zero_s16v);                            \
    mskB = vec_cmplt(temp2v, zero_s16v);                            \
    coefvA = (vec_u16_t)vec_abs( temp1v );                          \
    coefvB = (vec_u16_t)vec_abs( temp2v );                          \
    coefvA = vec_adds(coefvA, biasvA);                              \
    coefvB = vec_adds(coefvB, biasvB);                              \
    multEvenvA = vec_mule(coefvA, mfvA);                            \
    multOddvA = vec_mulo(coefvA, mfvA);                             \
    multEvenvB = vec_mule(coefvB, mfvB);                            \
    multOddvB = vec_mulo(coefvB, mfvB);                             \
    multEvenvA = vec_sr(multEvenvA, i_qbitsv);                      \
    multOddvA = vec_sr(multOddvA, i_qbitsv);                        \
    multEvenvB = vec_sr(multEvenvB, i_qbitsv);                      \
    multOddvB = vec_sr(multOddvB, i_qbitsv);                        \
    temp1v = (vec_s16_t) vec_packs( multEvenvA, multOddvA );        \
    tmpv = xxpermdi( temp1v, temp1v, 2 );                           \
    temp1v = vec_mergeh( temp1v, tmpv );                            \
    temp2v = (vec_s16_t) vec_packs( multEvenvB, multOddvB );        \
    tmpv = xxpermdi( temp2v, temp2v, 2 );                           \
    temp2v = vec_mergeh( temp2v, tmpv );                            \
    temp1v = vec_xor(temp1v, mskA);                                 \
    temp2v = vec_xor(temp2v, mskB);                                 \
    temp1v = vec_adds(temp1v, vec_and(mskA, one));                  \
    vec_st(temp1v, (idx0), dct);                                    \
    temp2v = vec_adds(temp2v, vec_and(mskB, one));                  \
    nz = vec_or(nz, vec_or(temp1v, temp2v));                        \
    vec_st(temp2v, (idx1), dct);                                    \
}

int x264_quant_4x4_altivec( int16_t dct[16], uint16_t mf[16], uint16_t bias[16] )
{
    LOAD_ZERO;
    vector bool short mskA;
    vec_u32_t i_qbitsv = vec_splats( (uint32_t)16 );
    vec_u16_t coefvA;
    vec_u32_t multEvenvA, multOddvA;
    vec_u16_t mfvA;
    vec_u16_t biasvA;
    vec_s16_t one = vec_splat_s16(1);
    vec_s16_t nz = zero_s16v;

    vector bool short mskB;
    vec_u16_t coefvB;
    vec_u32_t multEvenvB, multOddvB;
    vec_u16_t mfvB;
    vec_u16_t biasvB;

    vec_s16_t temp1v, temp2v, tmpv;

    QUANT_16_U( 0, 16 );
    return vec_any_ne(nz, zero_s16v);
}

int x264_quant_4x4x4_altivec( dctcoef dcta[4][16], udctcoef mf[16], udctcoef bias[16] )
{
    LOAD_ZERO;
    vec_u32_t i_qbitsv = vec_splats( (uint32_t)16 );
    vec_s16_t one = vec_splat_s16( 1 );
    vec_s16_t nz0, nz1, nz2, nz3;

    vector bool short mskA0;
    vec_u16_t coefvA0;
    vec_u32_t multEvenvA0, multOddvA0;
    vec_u16_t mfvA0;
    vec_u16_t biasvA0;
    vector bool short mskB0;
    vec_u16_t coefvB0;
    vec_u32_t multEvenvB0, multOddvB0;
    vec_u16_t mfvB0;
    vec_u16_t biasvB0;

    vector bool short mskA1;
    vec_u16_t coefvA1;
    vec_u32_t multEvenvA1, multOddvA1;
    vec_u16_t mfvA1;
    vec_u16_t biasvA1;
    vector bool short mskB1;
    vec_u16_t coefvB1;
    vec_u32_t multEvenvB1, multOddvB1;
    vec_u16_t mfvB1;
    vec_u16_t biasvB1;

    vector bool short mskA2;
    vec_u16_t coefvA2;
    vec_u32_t multEvenvA2, multOddvA2;
    vec_u16_t mfvA2;
    vec_u16_t biasvA2;
    vector bool short mskB2;
    vec_u16_t coefvB2;
    vec_u32_t multEvenvB2, multOddvB2;
    vec_u16_t mfvB2;
    vec_u16_t biasvB2;

    vector bool short mskA3;
    vec_u16_t coefvA3;
    vec_u32_t multEvenvA3, multOddvA3;
    vec_u16_t mfvA3;
    vec_u16_t biasvA3;
    vector bool short mskB3;
    vec_u16_t coefvB3;
    vec_u32_t multEvenvB3, multOddvB3;
    vec_u16_t mfvB3;
    vec_u16_t biasvB3;

    vec_s16_t temp1v, temp2v;
    vec_s16_t tmpv0;
    vec_s16_t tmpv1;

    dctcoef *dct0 = dcta[0];
    dctcoef *dct1 = dcta[1];
    dctcoef *dct2 = dcta[2];
    dctcoef *dct3 = dcta[3];

    temp1v = vec_ld( 0,  dct0 );
    temp2v = vec_ld( 16, dct0 );
    mfvA0 = vec_ld( 0,  mf );
    mfvB0 = vec_ld( 16, mf );
    biasvA0 = vec_ld( 0,  bias );
    biasvB0 = vec_ld( 16, bias );
    mskA0 = vec_cmplt( temp1v, zero_s16v );
    mskB0 = vec_cmplt( temp2v, zero_s16v );
    coefvA0 = (vec_u16_t)vec_abs( temp1v );
    coefvB0 = (vec_u16_t)vec_abs( temp2v );
    temp1v = vec_ld( 0,  dct1 );
    temp2v = vec_ld( 16, dct1 );
    mfvA1 = vec_ld( 0,  mf );
    mfvB1 = vec_ld( 16, mf );
    biasvA1 = vec_ld( 0,  bias );
    biasvB1 = vec_ld( 16, bias );
    mskA1 = vec_cmplt( temp1v, zero_s16v );
    mskB1 = vec_cmplt( temp2v, zero_s16v );
    coefvA1 = (vec_u16_t)vec_abs( temp1v );
    coefvB1 = (vec_u16_t)vec_abs( temp2v );
    temp1v = vec_ld( 0,  dct2 );
    temp2v = vec_ld( 16, dct2 );
    mfvA2 = vec_ld( 0,  mf );
    mfvB2 = vec_ld( 16, mf );
    biasvA2 = vec_ld( 0,  bias );
    biasvB2 = vec_ld( 16, bias );
    mskA2 = vec_cmplt( temp1v, zero_s16v );
    mskB2 = vec_cmplt( temp2v, zero_s16v );
    coefvA2 = (vec_u16_t)vec_abs( temp1v );
    coefvB2 = (vec_u16_t)vec_abs( temp2v );
    temp1v = vec_ld( 0,  dct3 );
    temp2v = vec_ld( 16, dct3 );
    mfvA3 = vec_ld( 0,  mf );
    mfvB3 = vec_ld( 16, mf );
    biasvA3 = vec_ld( 0,  bias );
    biasvB3 = vec_ld( 16, bias );
    mskA3 = vec_cmplt( temp1v, zero_s16v );
    mskB3 = vec_cmplt( temp2v, zero_s16v );
    coefvA3 = (vec_u16_t)vec_abs( temp1v );
    coefvB3 = (vec_u16_t)vec_abs( temp2v );

    coefvA0 = vec_adds( coefvA0, biasvA0 );
    coefvB0 = vec_adds( coefvB0, biasvB0 );
    coefvA1 = vec_adds( coefvA1, biasvA1 );
    coefvB1 = vec_adds( coefvB1, biasvB1 );
    coefvA2 = vec_adds( coefvA2, biasvA2 );
    coefvB2 = vec_adds( coefvB2, biasvB2 );
    coefvA3 = vec_adds( coefvA3, biasvA3 );
    coefvB3 = vec_adds( coefvB3, biasvB3 );

    multEvenvA0 = vec_mule( coefvA0, mfvA0 );
    multOddvA0  = vec_mulo( coefvA0, mfvA0 );
    multEvenvB0 = vec_mule( coefvB0, mfvB0 );
    multOddvB0  = vec_mulo( coefvB0, mfvB0 );
    multEvenvA0 = vec_sr( multEvenvA0, i_qbitsv );
    multOddvA0  = vec_sr( multOddvA0,  i_qbitsv );
    multEvenvB0 = vec_sr( multEvenvB0, i_qbitsv );
    multOddvB0  = vec_sr( multOddvB0,  i_qbitsv );
    temp1v = (vec_s16_t)vec_packs( multEvenvA0, multOddvA0 );
    temp2v = (vec_s16_t)vec_packs( multEvenvB0, multOddvB0 );
    tmpv0 = xxpermdi( temp1v, temp1v, 2 );
    tmpv1 = xxpermdi( temp2v, temp2v, 2 );
    temp1v = vec_mergeh( temp1v, tmpv0 );
    temp2v = vec_mergeh( temp2v, tmpv1 );
    temp1v = vec_xor( temp1v, mskA0 );
    temp2v = vec_xor( temp2v, mskB0 );
    temp1v = vec_adds( temp1v, vec_and( mskA0, one ) );
    temp2v = vec_adds( temp2v, vec_and( mskB0, one ) );
    vec_st( temp1v, 0,  dct0 );
    vec_st( temp2v, 16, dct0 );
    nz0 = vec_or( temp1v, temp2v );

    multEvenvA1 = vec_mule( coefvA1, mfvA1 );
    multOddvA1  = vec_mulo( coefvA1, mfvA1 );
    multEvenvB1 = vec_mule( coefvB1, mfvB1 );
    multOddvB1  = vec_mulo( coefvB1, mfvB1 );
    multEvenvA1 = vec_sr( multEvenvA1, i_qbitsv );
    multOddvA1  = vec_sr( multOddvA1,  i_qbitsv );
    multEvenvB1 = vec_sr( multEvenvB1, i_qbitsv );
    multOddvB1  = vec_sr( multOddvB1,  i_qbitsv );
    temp1v = (vec_s16_t)vec_packs( multEvenvA1, multOddvA1 );
    temp2v = (vec_s16_t)vec_packs( multEvenvB1, multOddvB1 );
    tmpv0 = xxpermdi( temp1v, temp1v, 2 );
    tmpv1 = xxpermdi( temp2v, temp2v, 2 );
    temp1v = vec_mergeh( temp1v, tmpv0 );
    temp2v = vec_mergeh( temp2v, tmpv1 );
    temp1v = vec_xor( temp1v, mskA1 );
    temp2v = vec_xor( temp2v, mskB1 );
    temp1v = vec_adds( temp1v, vec_and( mskA1, one ) );
    temp2v = vec_adds( temp2v, vec_and( mskB1, one ) );
    vec_st( temp1v, 0,  dct1 );
    vec_st( temp2v, 16, dct1 );
    nz1 = vec_or( temp1v, temp2v );

    multEvenvA2 = vec_mule( coefvA2, mfvA2 );
    multOddvA2  = vec_mulo( coefvA2, mfvA2 );
    multEvenvB2 = vec_mule( coefvB2, mfvB2 );
    multOddvB2  = vec_mulo( coefvB2, mfvB2 );
    multEvenvA2 = vec_sr( multEvenvA2, i_qbitsv );
    multOddvA2  = vec_sr( multOddvA2,  i_qbitsv );
    multEvenvB2 = vec_sr( multEvenvB2, i_qbitsv );
    multOddvB2  = vec_sr( multOddvB2,  i_qbitsv );
    temp1v = (vec_s16_t)vec_packs( multEvenvA2, multOddvA2 );
    temp2v = (vec_s16_t)vec_packs( multEvenvB2, multOddvB2 );
    tmpv0 = xxpermdi( temp1v, temp1v, 2 );
    tmpv1 = xxpermdi( temp2v, temp2v, 2 );
    temp1v = vec_mergeh( temp1v, tmpv0 );
    temp2v = vec_mergeh( temp2v, tmpv1 );
    temp1v = vec_xor( temp1v, mskA2 );
    temp2v = vec_xor( temp2v, mskB2 );
    temp1v = vec_adds( temp1v, vec_and( mskA2, one ) );
    temp2v = vec_adds( temp2v, vec_and( mskB2, one ) );
    vec_st( temp1v, 0,  dct2 );
    vec_st( temp2v, 16, dct2 );
    nz2 = vec_or( temp1v, temp2v );

    multEvenvA3 = vec_mule( coefvA3, mfvA3 );
    multOddvA3  = vec_mulo( coefvA3, mfvA3 );
    multEvenvB3 = vec_mule( coefvB3, mfvB3 );
    multOddvB3  = vec_mulo( coefvB3, mfvB3 );
    multEvenvA3 = vec_sr( multEvenvA3, i_qbitsv );
    multOddvA3  = vec_sr( multOddvA3,  i_qbitsv );
    multEvenvB3 = vec_sr( multEvenvB3, i_qbitsv );
    multOddvB3  = vec_sr( multOddvB3,  i_qbitsv );
    temp1v = (vec_s16_t)vec_packs( multEvenvA3, multOddvA3 );
    temp2v = (vec_s16_t)vec_packs( multEvenvB3, multOddvB3 );
    tmpv0 = xxpermdi( temp1v, temp1v, 2 );
    tmpv1 = xxpermdi( temp2v, temp2v, 2 );
    temp1v = vec_mergeh( temp1v, tmpv0 );
    temp2v = vec_mergeh( temp2v, tmpv1 );
    temp1v = vec_xor( temp1v, mskA3 );
    temp2v = vec_xor( temp2v, mskB3 );
    temp1v = vec_adds( temp1v, vec_and( mskA3, one ) );
    temp2v = vec_adds( temp2v, vec_and( mskB3, one ) );
    vec_st( temp1v, 0,  dct3 );
    vec_st( temp2v, 16, dct3 );
    nz3 = vec_or( temp1v, temp2v );

    return (vec_any_ne( nz0, zero_s16v ) << 0) | (vec_any_ne( nz1, zero_s16v ) << 1) |
           (vec_any_ne( nz2, zero_s16v ) << 2) | (vec_any_ne( nz3, zero_s16v ) << 3);
}

// DC quant of a whole 4x4 block, unrolled 2x and "pre-scheduled"
#define QUANT_16_U_DC( idx0, idx1 )                                 \
{                                                                   \
    temp1v = vec_ld((idx0), dct);                                   \
    temp2v = vec_ld((idx1), dct);                                   \
    mskA = vec_cmplt(temp1v, zero_s16v);                            \
    mskB = vec_cmplt(temp2v, zero_s16v);                            \
    coefvA = (vec_u16_t)vec_max(vec_sub(zero_s16v, temp1v), temp1v);\
    coefvB = (vec_u16_t)vec_max(vec_sub(zero_s16v, temp2v), temp2v);\
    coefvA = vec_add(coefvA, biasv);                                \
    coefvB = vec_add(coefvB, biasv);                                \
    multEvenvA = vec_mule(coefvA, mfv);                             \
    multOddvA = vec_mulo(coefvA, mfv);                              \
    multEvenvB = vec_mule(coefvB, mfv);                             \
    multOddvB = vec_mulo(coefvB, mfv);                              \
    multEvenvA = vec_sr(multEvenvA, i_qbitsv);                      \
    multOddvA = vec_sr(multOddvA, i_qbitsv);                        \
    multEvenvB = vec_sr(multEvenvB, i_qbitsv);                      \
    multOddvB = vec_sr(multOddvB, i_qbitsv);                        \
    temp1v = (vec_s16_t) vec_packs(vec_mergeh(multEvenvA, multOddvA), vec_mergel(multEvenvA, multOddvA)); \
    temp2v = (vec_s16_t) vec_packs(vec_mergeh(multEvenvB, multOddvB), vec_mergel(multEvenvB, multOddvB)); \
    temp1v = vec_xor(temp1v, mskA);                                 \
    temp2v = vec_xor(temp2v, mskB);                                 \
    temp1v = vec_add(temp1v, vec_and(mskA, one));                   \
    vec_st(temp1v, (idx0), dct);                                    \
    temp2v = vec_add(temp2v, vec_and(mskB, one));                   \
    nz = vec_or(nz, vec_or(temp1v, temp2v));                        \
    vec_st(temp2v, (idx1), dct);                                    \
}

int x264_quant_4x4_dc_altivec( int16_t dct[16], int mf, int bias )
{
    LOAD_ZERO;
    vector bool short mskA;
    vec_u32_t i_qbitsv;
    vec_u16_t coefvA;
    vec_u32_t multEvenvA, multOddvA;
    vec_s16_t one = vec_splat_s16(1);
    vec_s16_t nz = zero_s16v;

    vector bool short mskB;
    vec_u16_t coefvB;
    vec_u32_t multEvenvB, multOddvB;

    vec_s16_t temp1v, temp2v;

    vec_u16_t mfv;
    vec_u16_t biasv;

    mfv = vec_splats( (uint16_t)mf );
    i_qbitsv = vec_splats( (uint32_t) 16 );
    biasv = vec_splats( (uint16_t)bias );

    QUANT_16_U_DC( 0, 16 );
    return vec_any_ne(nz, zero_s16v);
}

// DC quant of a whole 2x2 block
#define QUANT_4_U_DC( idx0 )                                        \
{                                                                   \
    const vec_u16_t sel = (vec_u16_t) CV(-1,-1,-1,-1,0,0,0,0);      \
    temp1v = vec_ld((idx0), dct);                                   \
    mskA = vec_cmplt(temp1v, zero_s16v);                            \
    coefvA = (vec_u16_t)vec_max(vec_sub(zero_s16v, temp1v), temp1v);\
    coefvA = vec_add(coefvA, biasv);                                \
    multEvenvA = vec_mule(coefvA, mfv);                             \
    multOddvA = vec_mulo(coefvA, mfv);                              \
    multEvenvA = vec_sr(multEvenvA, i_qbitsv);                      \
    multOddvA = vec_sr(multOddvA, i_qbitsv);                        \
    temp2v = (vec_s16_t) vec_packs(vec_mergeh(multEvenvA, multOddvA), vec_mergel(multEvenvA, multOddvA)); \
    temp2v = vec_xor(temp2v, mskA);                                 \
    temp2v = vec_add(temp2v, vec_and(mskA, one));                   \
    temp1v = vec_sel(temp1v, temp2v, sel);                          \
    nz = vec_or(nz, temp1v);                                        \
    vec_st(temp1v, (idx0), dct);                                    \
}

int x264_quant_2x2_dc_altivec( int16_t dct[4], int mf, int bias )
{
    LOAD_ZERO;
    vector bool short mskA;
    vec_u32_t i_qbitsv;
    vec_u16_t coefvA;
    vec_u32_t multEvenvA, multOddvA;
    vec_s16_t one = vec_splat_s16(1);
    vec_s16_t nz = zero_s16v;
    static const vec_s16_t mask2 = CV(-1, -1, -1, -1,  0, 0, 0, 0);

    vec_s16_t temp1v, temp2v;

    vec_u16_t mfv;
    vec_u16_t biasv;

    mfv = vec_splats( (uint16_t)mf );
    i_qbitsv = vec_splats( (uint32_t) 16 );
    biasv = vec_splats( (uint16_t)bias );

    QUANT_4_U_DC(0);
    return vec_any_ne(vec_and(nz, mask2), zero_s16v);
}

int x264_quant_8x8_altivec( int16_t dct[64], uint16_t mf[64], uint16_t bias[64] )
{
    LOAD_ZERO;
    vector bool short mskA;
    vec_u32_t i_qbitsv;
    vec_u16_t coefvA;
    vec_u32_t multEvenvA, multOddvA;
    vec_u16_t mfvA;
    vec_u16_t biasvA;
    vec_s16_t one = vec_splat_s16(1);
    vec_s16_t nz = zero_s16v;

    vector bool short mskB;
    vec_u16_t coefvB;
    vec_u32_t multEvenvB, multOddvB;
    vec_u16_t mfvB;
    vec_u16_t biasvB;

    vec_s16_t temp1v, temp2v, tmpv;

    i_qbitsv = vec_splats( (uint32_t)16 );

    for( int i = 0; i < 4; i++ )
        QUANT_16_U( i*2*16, i*2*16+16 );
    return vec_any_ne(nz, zero_s16v);
}

#define DEQUANT_SHL()                                                \
{                                                                    \
    dctv = vec_ld(8*y, dct);                                         \
    mf1v = vec_ld(16*y, dequant_mf[i_mf]);                           \
    mf2v = vec_ld(16+16*y, dequant_mf[i_mf]);                        \
    mfv  = vec_packs(mf1v, mf2v);                                    \
                                                                     \
    multEvenvA = vec_mule(dctv, mfv);                                \
    multOddvA = vec_mulo(dctv, mfv);                                 \
    dctv = (vec_s16_t) vec_packs( multEvenvA, multOddvA );           \
    tmpv = xxpermdi( dctv, dctv, 2 );                                \
    dctv = vec_mergeh( dctv, tmpv );                                 \
    dctv = vec_sl(dctv, i_qbitsv);                                   \
    vec_st(dctv, 8*y, dct);                                          \
}

#ifdef WORDS_BIGENDIAN
#define VEC_MULE vec_mule
#define VEC_MULO vec_mulo
#else
#define VEC_MULE vec_mulo
#define VEC_MULO vec_mule
#endif

#define DEQUANT_SHR()                                          \
{                                                              \
    dctv = vec_ld(8*y, dct);                                   \
    dct1v = vec_mergeh(dctv, dctv);                            \
    dct2v = vec_mergel(dctv, dctv);                            \
    mf1v = vec_ld(16*y, dequant_mf[i_mf]);                     \
    mf2v = vec_ld(16+16*y, dequant_mf[i_mf]);                  \
                                                               \
    multEvenvA = VEC_MULE(dct1v, (vec_s16_t)mf1v);             \
    multOddvA = VEC_MULO(dct1v, (vec_s16_t)mf1v);              \
    temp1v = vec_add(vec_sl(multEvenvA, sixteenv), multOddvA); \
    temp1v = vec_add(temp1v, fv);                              \
    temp1v = vec_sra(temp1v, i_qbitsv);                        \
                                                               \
    multEvenvA = VEC_MULE(dct2v, (vec_s16_t)mf2v);             \
    multOddvA = VEC_MULO(dct2v, (vec_s16_t)mf2v);              \
    temp2v = vec_add(vec_sl(multEvenvA, sixteenv), multOddvA); \
    temp2v = vec_add(temp2v, fv);                              \
    temp2v = vec_sra(temp2v, i_qbitsv);                        \
                                                               \
    dctv = (vec_s16_t)vec_packs(temp1v, temp2v);               \
    vec_st(dctv, y*8, dct);                                    \
}

void x264_dequant_4x4_altivec( int16_t dct[16], int dequant_mf[6][16], int i_qp )
{
    int i_mf = i_qp%6;
    int i_qbits = i_qp/6 - 4;

    vec_s16_t dctv, tmpv;
    vec_s16_t dct1v, dct2v;
    vec_s32_t mf1v, mf2v;
    vec_s16_t mfv;
    vec_s32_t multEvenvA, multOddvA;
    vec_s32_t temp1v, temp2v;

    if( i_qbits >= 0 )
    {
        vec_u16_t i_qbitsv;
        i_qbitsv = vec_splats( (uint16_t) i_qbits );

        for( int y = 0; y < 4; y+=2 )
            DEQUANT_SHL();
    }
    else
    {
        const int f = 1 << (-i_qbits-1);

        vec_s32_t fv;
        fv = vec_splats( f );

        vec_u32_t i_qbitsv;
        i_qbitsv = vec_splats( (uint32_t)-i_qbits );

        vec_u32_t sixteenv;
        sixteenv = vec_splats( (uint32_t)16 );

        for( int y = 0; y < 4; y+=2 )
            DEQUANT_SHR();
    }
}

void x264_dequant_8x8_altivec( int16_t dct[64], int dequant_mf[6][64], int i_qp )
{
    int i_mf = i_qp%6;
    int i_qbits = i_qp/6 - 6;

    vec_s16_t dctv, tmpv;
    vec_s16_t dct1v, dct2v;
    vec_s32_t mf1v, mf2v;
    vec_s16_t mfv;
    vec_s32_t multEvenvA, multOddvA;
    vec_s32_t temp1v, temp2v;

    if( i_qbits >= 0 )
    {
        vec_u16_t i_qbitsv;
        i_qbitsv = vec_splats((uint16_t)i_qbits );

        for( int y = 0; y < 16; y+=2 )
            DEQUANT_SHL();
    }
    else
    {
        const int f = 1 << (-i_qbits-1);

        vec_s32_t fv;
        fv = vec_splats( f );

        vec_u32_t i_qbitsv;
        i_qbitsv = vec_splats( (uint32_t)-i_qbits );

        vec_u32_t sixteenv;
        sixteenv = vec_splats( (uint32_t)16 );

        for( int y = 0; y < 16; y+=2 )
            DEQUANT_SHR();
    }
}
#endif // !HIGH_BIT_DEPTH

