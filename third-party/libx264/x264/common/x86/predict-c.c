/*****************************************************************************
 * predict-c.c: intra prediction
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
#include "predict.h"
#include "pixel.h"

#define PREDICT_P_SUM(j,i)\
    H += i * ( src[j+i - FDEC_STRIDE ]  - src[j-i - FDEC_STRIDE ] );\
    V += i * ( src[(j+i)*FDEC_STRIDE -1] - src[(j-i)*FDEC_STRIDE -1] );

#if HAVE_X86_INLINE_ASM
#if HIGH_BIT_DEPTH
ALIGNED_16( static const int16_t pw_12345678[8] ) = {1,2,3,4,5,6,7,8};
ALIGNED_16( static const int16_t pw_m87654321[8] ) = {-8,-7,-6,-5,-4,-3,-2,-1};
ALIGNED_16( static const int16_t pw_m32101234[8] ) = {-3,-2,-1,0,1,2,3,4};
#else // !HIGH_BIT_DEPTH
ALIGNED_8( static const int8_t pb_12345678[8] ) = {1,2,3,4,5,6,7,8};
ALIGNED_8( static const int8_t pb_m87654321[8] ) = {-8,-7,-6,-5,-4,-3,-2,-1};
ALIGNED_8( static const int8_t pb_m32101234[8] ) = {-3,-2,-1,0,1,2,3,4};
#endif // HIGH_BIT_DEPTH
#endif // HAVE_X86_INLINE_ASM

#define PREDICT_16x16_P_CORE\
    int H = 0;\
    int V = 0;\
    PREDICT_P_SUM(7,1)\
    PREDICT_P_SUM(7,2)\
    PREDICT_P_SUM(7,3)\
    PREDICT_P_SUM(7,4)\
    PREDICT_P_SUM(7,5)\
    PREDICT_P_SUM(7,6)\
    PREDICT_P_SUM(7,7)\
    PREDICT_P_SUM(7,8)

#define PREDICT_16x16_P_END(name)\
    int a = 16 * ( src[15*FDEC_STRIDE -1] + src[15 - FDEC_STRIDE] );\
    int b = ( 5 * H + 32 ) >> 6;\
    int c = ( 5 * V + 32 ) >> 6;\
    int i00 = a - b * 7 - c * 7 + 16;\
    /* b*15 + c*15 can overflow: it's easier to just branch away in this rare case\
     * than to try to consider it in the asm. */\
    if( BIT_DEPTH > 8 && (i00 > 0x7fff || abs(b) > 1092 || abs(c) > 1092) )\
        x264_predict_16x16_p_c( src );\
    else\
        x264_predict_16x16_p_core_##name( src, i00, b, c );

#define PREDICT_16x16_P(name, name2)\
static void predict_16x16_p_##name( pixel *src )\
{\
    PREDICT_16x16_P_CORE\
    PREDICT_16x16_P_END(name2)\
}

#if HAVE_X86_INLINE_ASM
#if HIGH_BIT_DEPTH
#define PREDICT_16x16_P_ASM\
    asm (\
        "movdqu           %1, %%xmm1 \n"\
        "movdqa           %2, %%xmm0 \n"\
        "pmaddwd          %3, %%xmm0 \n"\
        "pmaddwd          %4, %%xmm1 \n"\
        "paddd        %%xmm1, %%xmm0 \n"\
        "movhlps      %%xmm0, %%xmm1 \n"\
        "paddd        %%xmm1, %%xmm0 \n"\
        "pshuflw $14, %%xmm0, %%xmm1 \n"\
        "paddd        %%xmm1, %%xmm0 \n"\
        "movd         %%xmm0, %0     \n"\
        :"=r"(H)\
        :"m"(MEM_FIX(&src[-FDEC_STRIDE-1], const pixel, 8)),\
         "m"(MEM_FIX(&src[-FDEC_STRIDE+8], const pixel, 8)),\
         "m"(MEM_FIX(pw_12345678, const int16_t, 8)),\
         "m"(MEM_FIX(pw_m87654321, const int16_t, 8))\
        :"xmm0", "xmm1"\
    );
#else // !HIGH_BIT_DEPTH
#define PREDICT_16x16_P_ASM\
    asm (\
        "movq           %1, %%mm1 \n"\
        "movq           %2, %%mm0 \n"\
        "palignr $7,    %3, %%mm1 \n"\
        "pmaddubsw      %4, %%mm0 \n"\
        "pmaddubsw      %5, %%mm1 \n"\
        "paddw       %%mm1, %%mm0 \n"\
        "pshufw $14, %%mm0, %%mm1 \n"\
        "paddw       %%mm1, %%mm0 \n"\
        "pshufw  $1, %%mm0, %%mm1 \n"\
        "paddw       %%mm1, %%mm0 \n"\
        "movd        %%mm0, %0    \n"\
        "movswl        %w0, %0    \n"\
        :"=r"(H)\
        :"m"(MEM_FIX(&src[-FDEC_STRIDE], const pixel, 8)),\
         "m"(MEM_FIX(&src[-FDEC_STRIDE+8], const pixel, 8)),\
         "m"(MEM_FIX(&src[-FDEC_STRIDE-8], const pixel, 8)),\
         "m"(MEM_FIX(pb_12345678, const int8_t, 8)),\
         "m"(MEM_FIX(pb_m87654321, const int8_t, 8))\
        :"mm0", "mm1"\
    );
#endif // HIGH_BIT_DEPTH

#define PREDICT_16x16_P_CORE_INLINE\
    int H, V;\
    PREDICT_16x16_P_ASM\
    V = 8 * ( src[15*FDEC_STRIDE-1] - src[-1*FDEC_STRIDE-1] )\
      + 7 * ( src[14*FDEC_STRIDE-1] - src[ 0*FDEC_STRIDE-1] )\
      + 6 * ( src[13*FDEC_STRIDE-1] - src[ 1*FDEC_STRIDE-1] )\
      + 5 * ( src[12*FDEC_STRIDE-1] - src[ 2*FDEC_STRIDE-1] )\
      + 4 * ( src[11*FDEC_STRIDE-1] - src[ 3*FDEC_STRIDE-1] )\
      + 3 * ( src[10*FDEC_STRIDE-1] - src[ 4*FDEC_STRIDE-1] )\
      + 2 * ( src[ 9*FDEC_STRIDE-1] - src[ 5*FDEC_STRIDE-1] )\
      + 1 * ( src[ 8*FDEC_STRIDE-1] - src[ 6*FDEC_STRIDE-1] );

#define PREDICT_16x16_P_INLINE(name, name2)\
static void predict_16x16_p_##name( pixel *src )\
{\
    PREDICT_16x16_P_CORE_INLINE\
    PREDICT_16x16_P_END(name2)\
}
#else // !HAVE_X86_INLINE_ASM
#define PREDICT_16x16_P_INLINE(name, name2) PREDICT_16x16_P(name, name2)
#endif // HAVE_X86_INLINE_ASM

#if HIGH_BIT_DEPTH
PREDICT_16x16_P_INLINE( sse2, sse2 )
#else // !HIGH_BIT_DEPTH
#if !ARCH_X86_64
PREDICT_16x16_P( mmx2, mmx2 )
#endif // !ARCH_X86_64
PREDICT_16x16_P( sse2, sse2 )
#if HAVE_X86_INLINE_ASM
PREDICT_16x16_P_INLINE( ssse3, sse2 )
#endif // HAVE_X86_INLINE_ASM
PREDICT_16x16_P_INLINE( avx, avx )
#endif // HIGH_BIT_DEPTH
PREDICT_16x16_P_INLINE( avx2, avx2 )

#define PREDICT_8x16C_P_CORE\
    int H = 0, V = 0;\
    for( int i = 0; i < 4; i++ )\
        H += ( i + 1 ) * ( src[4 + i - FDEC_STRIDE] - src[2 - i - FDEC_STRIDE] );\
    for( int i = 0; i < 8; i++ )\
        V += ( i + 1 ) * ( src[-1 + (i+8)*FDEC_STRIDE] - src[-1 + (6-i)*FDEC_STRIDE] );

#if HIGH_BIT_DEPTH
#define PREDICT_8x16C_P_END(name)\
    int a = 16 * ( src[-1 + 15*FDEC_STRIDE] + src[7 - FDEC_STRIDE] );\
    int b = ( 17 * H + 16 ) >> 5;\
    int c = ( 5 * V + 32 ) >> 6;\
    x264_predict_8x16c_p_core_##name( src, a, b, c );
#else // !HIGH_BIT_DEPTH
#define PREDICT_8x16C_P_END(name)\
    int a = 16 * ( src[-1 + 15*FDEC_STRIDE] + src[7 - FDEC_STRIDE] );\
    int b = ( 17 * H + 16 ) >> 5;\
    int c = ( 5 * V + 32 ) >> 6;\
    int i00 = a -3*b -7*c + 16;\
    x264_predict_8x16c_p_core_##name( src, i00, b, c );
#endif // HIGH_BIT_DEPTH

#define PREDICT_8x16C_P(name)\
static void predict_8x16c_p_##name( pixel *src )\
{\
    PREDICT_8x16C_P_CORE\
    PREDICT_8x16C_P_END(name)\
}

#if !ARCH_X86_64 && !HIGH_BIT_DEPTH
PREDICT_8x16C_P( mmx2 )
#endif // !ARCH_X86_64 && !HIGH_BIT_DEPTH
PREDICT_8x16C_P( sse2 )
PREDICT_8x16C_P( avx )
PREDICT_8x16C_P( avx2 )

#define PREDICT_8x8C_P_CORE\
    int H = 0;\
    int V = 0;\
    PREDICT_P_SUM(3,1)\
    PREDICT_P_SUM(3,2)\
    PREDICT_P_SUM(3,3)\
    PREDICT_P_SUM(3,4)

#if HIGH_BIT_DEPTH
#define PREDICT_8x8C_P_END(name)\
    int a = 16 * ( src[7*FDEC_STRIDE -1] + src[7 - FDEC_STRIDE] );\
    int b = ( 17 * H + 16 ) >> 5;\
    int c = ( 17 * V + 16 ) >> 5;\
    x264_predict_8x8c_p_core_##name( src, a, b, c );
#else // !HIGH_BIT_DEPTH
#define PREDICT_8x8C_P_END(name)\
    int a = 16 * ( src[7*FDEC_STRIDE -1] + src[7 - FDEC_STRIDE] );\
    int b = ( 17 * H + 16 ) >> 5;\
    int c = ( 17 * V + 16 ) >> 5;\
    int i00 = a -3*b -3*c + 16;\
    x264_predict_8x8c_p_core_##name( src, i00, b, c );
#endif // HIGH_BIT_DEPTH

#define PREDICT_8x8C_P(name, name2)\
static void predict_8x8c_p_##name( pixel *src )\
{\
    PREDICT_8x8C_P_CORE\
    PREDICT_8x8C_P_END(name2)\
}

#if HAVE_X86_INLINE_ASM
#if HIGH_BIT_DEPTH
#define PREDICT_8x8C_P_ASM\
    asm (\
        "movdqa           %1, %%xmm0 \n"\
        "pmaddwd          %2, %%xmm0 \n"\
        "movhlps      %%xmm0, %%xmm1 \n"\
        "paddd        %%xmm1, %%xmm0 \n"\
        "pshuflw $14, %%xmm0, %%xmm1 \n"\
        "paddd        %%xmm1, %%xmm0 \n"\
        "movd         %%xmm0, %0     \n"\
        :"=r"(H)\
        :"m"(MEM_FIX(&src[-FDEC_STRIDE], const pixel, 8)),\
         "m"(MEM_FIX(pw_m32101234, const int16_t, 8))\
        :"xmm0", "xmm1"\
    );
#else // !HIGH_BIT_DEPTH
#define PREDICT_8x8C_P_ASM\
    asm (\
        "movq           %1, %%mm0 \n"\
        "pmaddubsw      %2, %%mm0 \n"\
        "pshufw $14, %%mm0, %%mm1 \n"\
        "paddw       %%mm1, %%mm0 \n"\
        "pshufw  $1, %%mm0, %%mm1 \n"\
        "paddw       %%mm1, %%mm0 \n"\
        "movd        %%mm0, %0    \n"\
        "movswl        %w0, %0    \n"\
        :"=r"(H)\
        :"m"(MEM_FIX(&src[-FDEC_STRIDE], const pixel, 8)),\
         "m"(MEM_FIX(pb_m32101234, const int8_t, 8))\
        :"mm0", "mm1"\
    );
#endif // HIGH_BIT_DEPTH

#define PREDICT_8x8C_P_CORE_INLINE\
    int H, V;\
    PREDICT_8x8C_P_ASM\
    V = 1 * ( src[4*FDEC_STRIDE -1] - src[ 2*FDEC_STRIDE -1] )\
      + 2 * ( src[5*FDEC_STRIDE -1] - src[ 1*FDEC_STRIDE -1] )\
      + 3 * ( src[6*FDEC_STRIDE -1] - src[ 0*FDEC_STRIDE -1] )\
      + 4 * ( src[7*FDEC_STRIDE -1] - src[-1*FDEC_STRIDE -1] );\
    H += -4 * src[-1*FDEC_STRIDE -1];

#define PREDICT_8x8C_P_INLINE(name, name2)\
static void predict_8x8c_p_##name( pixel *src )\
{\
    PREDICT_8x8C_P_CORE_INLINE\
    PREDICT_8x8C_P_END(name2)\
}
#else // !HAVE_X86_INLINE_ASM
#define PREDICT_8x8C_P_INLINE(name, name2) PREDICT_8x8C_P(name, name2)
#endif // HAVE_X86_INLINE_ASM

#if HIGH_BIT_DEPTH
PREDICT_8x8C_P_INLINE( sse2, sse2 )
#else  //!HIGH_BIT_DEPTH
#if !ARCH_X86_64
PREDICT_8x8C_P( mmx2, mmx2 )
#endif // !ARCH_X86_64
PREDICT_8x8C_P( sse2, sse2 )
#if HAVE_X86_INLINE_ASM
PREDICT_8x8C_P_INLINE( ssse3, sse2 )
#endif // HAVE_X86_INLINE_ASM
#endif // HIGH_BIT_DEPTH
PREDICT_8x8C_P_INLINE( avx, avx )
PREDICT_8x8C_P_INLINE( avx2, avx2 )

#if ARCH_X86_64 && !HIGH_BIT_DEPTH
static void predict_8x8c_dc_left( uint8_t *src )
{
    int y;
    uint32_t s0 = 0, s1 = 0;
    uint64_t dc0, dc1;

    for( y = 0; y < 4; y++ )
    {
        s0 += src[y * FDEC_STRIDE     - 1];
        s1 += src[(y+4) * FDEC_STRIDE - 1];
    }
    dc0 = (( s0 + 2 ) >> 2) * 0x0101010101010101ULL;
    dc1 = (( s1 + 2 ) >> 2) * 0x0101010101010101ULL;

    for( y = 0; y < 4; y++ )
    {
        M64( src ) = dc0;
        src += FDEC_STRIDE;
    }
    for( y = 0; y < 4; y++ )
    {
        M64( src ) = dc1;
        src += FDEC_STRIDE;
    }
}
#endif // ARCH_X86_64 && !HIGH_BIT_DEPTH

/****************************************************************************
 * Exported functions:
 ****************************************************************************/
void x264_predict_16x16_init_mmx( uint32_t cpu, x264_predict_t pf[7] )
{
    if( !(cpu&X264_CPU_MMX2) )
        return;
    pf[I_PRED_16x16_V]       = x264_predict_16x16_v_mmx2;
    pf[I_PRED_16x16_H]       = x264_predict_16x16_h_mmx2;
#if HIGH_BIT_DEPTH
    if( !(cpu&X264_CPU_SSE) )
        return;
    pf[I_PRED_16x16_V]       = x264_predict_16x16_v_sse;
    if( !(cpu&X264_CPU_SSE2) )
        return;
    pf[I_PRED_16x16_DC]      = x264_predict_16x16_dc_sse2;
    pf[I_PRED_16x16_DC_TOP]  = x264_predict_16x16_dc_top_sse2;
    pf[I_PRED_16x16_DC_LEFT] = x264_predict_16x16_dc_left_sse2;
    pf[I_PRED_16x16_H]       = x264_predict_16x16_h_sse2;
    pf[I_PRED_16x16_P]       = predict_16x16_p_sse2;
    if( !(cpu&X264_CPU_AVX) )
        return;
    pf[I_PRED_16x16_V]       = x264_predict_16x16_v_avx;
    if( !(cpu&X264_CPU_AVX2) )
        return;
    pf[I_PRED_16x16_H]       = x264_predict_16x16_h_avx2;
#else
#if !ARCH_X86_64
    pf[I_PRED_16x16_P]       = predict_16x16_p_mmx2;
#endif
    if( !(cpu&X264_CPU_SSE) )
        return;
    pf[I_PRED_16x16_V]       = x264_predict_16x16_v_sse;
    if( !(cpu&X264_CPU_SSE2) )
        return;
    pf[I_PRED_16x16_DC]      = x264_predict_16x16_dc_sse2;
    if( cpu&X264_CPU_SSE2_IS_SLOW )
        return;
    pf[I_PRED_16x16_DC_TOP]  = x264_predict_16x16_dc_top_sse2;
    pf[I_PRED_16x16_DC_LEFT] = x264_predict_16x16_dc_left_sse2;
    pf[I_PRED_16x16_P]       = predict_16x16_p_sse2;
    if( !(cpu&X264_CPU_SSSE3) )
        return;
    if( !(cpu&X264_CPU_SLOW_PSHUFB) )
        pf[I_PRED_16x16_H]       = x264_predict_16x16_h_ssse3;
#if HAVE_X86_INLINE_ASM
    pf[I_PRED_16x16_P]       = predict_16x16_p_ssse3;
#endif
    if( !(cpu&X264_CPU_AVX) )
        return;
    pf[I_PRED_16x16_P]       = predict_16x16_p_avx;
#endif // HIGH_BIT_DEPTH

    if( cpu&X264_CPU_AVX2 )
    {
        pf[I_PRED_16x16_P]       = predict_16x16_p_avx2;
        pf[I_PRED_16x16_DC]      = x264_predict_16x16_dc_avx2;
        pf[I_PRED_16x16_DC_TOP]  = x264_predict_16x16_dc_top_avx2;
        pf[I_PRED_16x16_DC_LEFT] = x264_predict_16x16_dc_left_avx2;
    }
}

void x264_predict_8x8c_init_mmx( uint32_t cpu, x264_predict_t pf[7] )
{
    if( !(cpu&X264_CPU_MMX) )
        return;
#if HIGH_BIT_DEPTH
    pf[I_PRED_CHROMA_V]       = x264_predict_8x8c_v_mmx;
    if( !(cpu&X264_CPU_MMX2) )
        return;
    pf[I_PRED_CHROMA_DC]      = x264_predict_8x8c_dc_mmx2;
    pf[I_PRED_CHROMA_H]       = x264_predict_8x8c_h_mmx2;
    if( !(cpu&X264_CPU_SSE) )
        return;
    pf[I_PRED_CHROMA_V]       = x264_predict_8x8c_v_sse;
    if( !(cpu&X264_CPU_SSE2) )
        return;
    pf[I_PRED_CHROMA_DC]      = x264_predict_8x8c_dc_sse2;
    pf[I_PRED_CHROMA_DC_TOP]  = x264_predict_8x8c_dc_top_sse2;
    pf[I_PRED_CHROMA_H]       = x264_predict_8x8c_h_sse2;
    pf[I_PRED_CHROMA_P]       = predict_8x8c_p_sse2;
    if( !(cpu&X264_CPU_AVX) )
        return;
    pf[I_PRED_CHROMA_P]       = predict_8x8c_p_avx;
    if( !(cpu&X264_CPU_AVX2) )
        return;
    pf[I_PRED_CHROMA_H]   = x264_predict_8x8c_h_avx2;
#else
#if ARCH_X86_64
    pf[I_PRED_CHROMA_DC_LEFT] = predict_8x8c_dc_left;
#endif
    pf[I_PRED_CHROMA_V]       = x264_predict_8x8c_v_mmx;
    if( !(cpu&X264_CPU_MMX2) )
        return;
    pf[I_PRED_CHROMA_DC_TOP]  = x264_predict_8x8c_dc_top_mmx2;
    pf[I_PRED_CHROMA_H]       = x264_predict_8x8c_h_mmx2;
#if !ARCH_X86_64
    pf[I_PRED_CHROMA_P]       = predict_8x8c_p_mmx2;
#endif
    pf[I_PRED_CHROMA_DC]      = x264_predict_8x8c_dc_mmx2;
    if( !(cpu&X264_CPU_SSE2) )
        return;
    pf[I_PRED_CHROMA_P]       = predict_8x8c_p_sse2;
    if( !(cpu&X264_CPU_SSSE3) )
        return;
    pf[I_PRED_CHROMA_H]       = x264_predict_8x8c_h_ssse3;
#if HAVE_X86_INLINE_ASM
    pf[I_PRED_CHROMA_P]       = predict_8x8c_p_ssse3;
#endif
    if( !(cpu&X264_CPU_AVX) )
        return;
    pf[I_PRED_CHROMA_P]       = predict_8x8c_p_avx;
#endif // HIGH_BIT_DEPTH

    if( cpu&X264_CPU_AVX2 )
    {
        pf[I_PRED_CHROMA_P]   = predict_8x8c_p_avx2;
    }
}

void x264_predict_8x16c_init_mmx( uint32_t cpu, x264_predict_t pf[7] )
{
    if( !(cpu&X264_CPU_MMX) )
        return;
#if HIGH_BIT_DEPTH
    if( !(cpu&X264_CPU_MMX2) )
        return;
    pf[I_PRED_CHROMA_DC]      = x264_predict_8x16c_dc_mmx2;
    pf[I_PRED_CHROMA_H]       = x264_predict_8x16c_h_mmx2;
    if( !(cpu&X264_CPU_SSE) )
        return;
    pf[I_PRED_CHROMA_V]       = x264_predict_8x16c_v_sse;
    if( !(cpu&X264_CPU_SSE2) )
        return;
    pf[I_PRED_CHROMA_DC_TOP]  = x264_predict_8x16c_dc_top_sse2;
    pf[I_PRED_CHROMA_DC]      = x264_predict_8x16c_dc_sse2;
    pf[I_PRED_CHROMA_H]       = x264_predict_8x16c_h_sse2;
    pf[I_PRED_CHROMA_P]       = predict_8x16c_p_sse2;
    if( !(cpu&X264_CPU_AVX) )
        return;
    pf[I_PRED_CHROMA_P]       = predict_8x16c_p_avx;
    if( !(cpu&X264_CPU_AVX2) )
        return;
    pf[I_PRED_CHROMA_H]   = x264_predict_8x16c_h_avx2;
#else
    pf[I_PRED_CHROMA_V]       = x264_predict_8x16c_v_mmx;
    if( !(cpu&X264_CPU_MMX2) )
        return;
    pf[I_PRED_CHROMA_DC_TOP]  = x264_predict_8x16c_dc_top_mmx2;
    pf[I_PRED_CHROMA_DC]      = x264_predict_8x16c_dc_mmx2;
    pf[I_PRED_CHROMA_H]       = x264_predict_8x16c_h_mmx2;
#if !ARCH_X86_64
    pf[I_PRED_CHROMA_P]       = predict_8x16c_p_mmx2;
#endif
    if( !(cpu&X264_CPU_SSE2) )
        return;
    pf[I_PRED_CHROMA_P]       = predict_8x16c_p_sse2;
    if( !(cpu&X264_CPU_SSSE3) )
        return;
    pf[I_PRED_CHROMA_H]       = x264_predict_8x16c_h_ssse3;
    if( !(cpu&X264_CPU_AVX) )
        return;
    pf[I_PRED_CHROMA_P]       = predict_8x16c_p_avx;
#endif // HIGH_BIT_DEPTH

    if( cpu&X264_CPU_AVX2 )
    {
        pf[I_PRED_CHROMA_P]   = predict_8x16c_p_avx2;
    }
}

void x264_predict_8x8_init_mmx( uint32_t cpu, x264_predict8x8_t pf[12], x264_predict_8x8_filter_t *predict_8x8_filter )
{
    if( !(cpu&X264_CPU_MMX2) )
        return;
#if HIGH_BIT_DEPTH
    if( !(cpu&X264_CPU_SSE) )
        return;
    pf[I_PRED_8x8_V]      = x264_predict_8x8_v_sse;
    if( !(cpu&X264_CPU_SSE2) )
        return;
    pf[I_PRED_8x8_H]      = x264_predict_8x8_h_sse2;
    pf[I_PRED_8x8_DC]     = x264_predict_8x8_dc_sse2;
    pf[I_PRED_8x8_DC_TOP] = x264_predict_8x8_dc_top_sse2;
    pf[I_PRED_8x8_DC_LEFT]= x264_predict_8x8_dc_left_sse2;
    pf[I_PRED_8x8_DDL]    = x264_predict_8x8_ddl_sse2;
    pf[I_PRED_8x8_DDR]    = x264_predict_8x8_ddr_sse2;
    pf[I_PRED_8x8_VL]     = x264_predict_8x8_vl_sse2;
    pf[I_PRED_8x8_VR]     = x264_predict_8x8_vr_sse2;
    pf[I_PRED_8x8_HD]     = x264_predict_8x8_hd_sse2;
    pf[I_PRED_8x8_HU]     = x264_predict_8x8_hu_sse2;
    *predict_8x8_filter   = x264_predict_8x8_filter_sse2;
    if( !(cpu&X264_CPU_SSSE3) )
        return;
    pf[I_PRED_8x8_DDL]    = x264_predict_8x8_ddl_ssse3;
    pf[I_PRED_8x8_DDR]    = x264_predict_8x8_ddr_ssse3;
    pf[I_PRED_8x8_HD]     = x264_predict_8x8_hd_ssse3;
    pf[I_PRED_8x8_HU]     = x264_predict_8x8_hu_ssse3;
    pf[I_PRED_8x8_VL]     = x264_predict_8x8_vl_ssse3;
    pf[I_PRED_8x8_VR]     = x264_predict_8x8_vr_ssse3;
    *predict_8x8_filter   = x264_predict_8x8_filter_ssse3;
    if( cpu&X264_CPU_CACHELINE_64 )
    {
        pf[I_PRED_8x8_DDL]= x264_predict_8x8_ddl_cache64_ssse3;
        pf[I_PRED_8x8_DDR]= x264_predict_8x8_ddr_cache64_ssse3;
    }
    if( !(cpu&X264_CPU_AVX) )
        return;
    pf[I_PRED_8x8_HD]     = x264_predict_8x8_hd_avx;
    pf[I_PRED_8x8_HU]     = x264_predict_8x8_hu_avx;
    pf[I_PRED_8x8_VL]     = x264_predict_8x8_vl_avx;
    pf[I_PRED_8x8_VR]     = x264_predict_8x8_vr_avx;
    *predict_8x8_filter   = x264_predict_8x8_filter_avx;
#else
    pf[I_PRED_8x8_V]      = x264_predict_8x8_v_mmx2;
    pf[I_PRED_8x8_H]      = x264_predict_8x8_h_mmx2;
    pf[I_PRED_8x8_DC]     = x264_predict_8x8_dc_mmx2;
    pf[I_PRED_8x8_DC_TOP] = x264_predict_8x8_dc_top_mmx2;
    pf[I_PRED_8x8_DC_LEFT]= x264_predict_8x8_dc_left_mmx2;
    pf[I_PRED_8x8_HD]     = x264_predict_8x8_hd_mmx2;
    pf[I_PRED_8x8_VL]     = x264_predict_8x8_vl_mmx2;
    *predict_8x8_filter   = x264_predict_8x8_filter_mmx2;
#if ARCH_X86
    pf[I_PRED_8x8_DDL]  = x264_predict_8x8_ddl_mmx2;
    pf[I_PRED_8x8_DDR]  = x264_predict_8x8_ddr_mmx2;
    pf[I_PRED_8x8_VR]   = x264_predict_8x8_vr_mmx2;
    pf[I_PRED_8x8_HU]   = x264_predict_8x8_hu_mmx2;
#endif
    if( !(cpu&X264_CPU_SSE2) )
        return;
    pf[I_PRED_8x8_DDL]  = x264_predict_8x8_ddl_sse2;
    pf[I_PRED_8x8_VL]   = x264_predict_8x8_vl_sse2;
    pf[I_PRED_8x8_VR]   = x264_predict_8x8_vr_sse2;
    pf[I_PRED_8x8_DDR]  = x264_predict_8x8_ddr_sse2;
    pf[I_PRED_8x8_HD]   = x264_predict_8x8_hd_sse2;
    pf[I_PRED_8x8_HU]   = x264_predict_8x8_hu_sse2;
    if( !(cpu&X264_CPU_SSSE3) )
        return;
    if( !(cpu&X264_CPU_SLOW_PALIGNR) )
    {
        pf[I_PRED_8x8_DDL]  = x264_predict_8x8_ddl_ssse3;
        pf[I_PRED_8x8_VR]   = x264_predict_8x8_vr_ssse3;
    }
    pf[I_PRED_8x8_HU]   = x264_predict_8x8_hu_ssse3;
    *predict_8x8_filter = x264_predict_8x8_filter_ssse3;
    if( !(cpu&X264_CPU_AVX) )
        return;
    pf[I_PRED_8x8_DDL]  = x264_predict_8x8_ddl_avx;
    pf[I_PRED_8x8_DDR]  = x264_predict_8x8_ddr_avx;
    pf[I_PRED_8x8_VL]   = x264_predict_8x8_vl_avx;
    pf[I_PRED_8x8_VR]   = x264_predict_8x8_vr_avx;
    pf[I_PRED_8x8_HD]   = x264_predict_8x8_hd_avx;
#endif // HIGH_BIT_DEPTH
}

void x264_predict_4x4_init_mmx( uint32_t cpu, x264_predict_t pf[12] )
{
    if( !(cpu&X264_CPU_MMX2) )
        return;
    pf[I_PRED_4x4_DC]  = x264_predict_4x4_dc_mmx2;
    pf[I_PRED_4x4_DDL] = x264_predict_4x4_ddl_mmx2;
    pf[I_PRED_4x4_DDR] = x264_predict_4x4_ddr_mmx2;
    pf[I_PRED_4x4_VL]  = x264_predict_4x4_vl_mmx2;
    pf[I_PRED_4x4_HD]  = x264_predict_4x4_hd_mmx2;
    pf[I_PRED_4x4_HU]  = x264_predict_4x4_hu_mmx2;
#if HIGH_BIT_DEPTH
    if( !(cpu&X264_CPU_SSE2) )
        return;
    pf[I_PRED_4x4_DDL] = x264_predict_4x4_ddl_sse2;
    pf[I_PRED_4x4_DDR] = x264_predict_4x4_ddr_sse2;
    pf[I_PRED_4x4_HD]  = x264_predict_4x4_hd_sse2;
    pf[I_PRED_4x4_VL]  = x264_predict_4x4_vl_sse2;
    pf[I_PRED_4x4_VR]  = x264_predict_4x4_vr_sse2;
    if( !(cpu&X264_CPU_SSSE3) )
        return;
    pf[I_PRED_4x4_DDR] = x264_predict_4x4_ddr_ssse3;
    pf[I_PRED_4x4_VR]  = x264_predict_4x4_vr_ssse3;
    pf[I_PRED_4x4_HD]  = x264_predict_4x4_hd_ssse3;
    if( !(cpu&X264_CPU_AVX) )
        return;
    pf[I_PRED_4x4_DDL] = x264_predict_4x4_ddl_avx;
    pf[I_PRED_4x4_DDR] = x264_predict_4x4_ddr_avx;
    pf[I_PRED_4x4_HD]  = x264_predict_4x4_hd_avx;
    pf[I_PRED_4x4_VL]  = x264_predict_4x4_vl_avx;
    pf[I_PRED_4x4_VR]  = x264_predict_4x4_vr_avx;
    if( !(cpu&X264_CPU_AVX2) )
        return;
    pf[I_PRED_4x4_H]  = x264_predict_4x4_h_avx2;
#else
    pf[I_PRED_4x4_VR]  = x264_predict_4x4_vr_mmx2;
    if( !(cpu&X264_CPU_SSSE3) )
        return;
    pf[I_PRED_4x4_DDR] = x264_predict_4x4_ddr_ssse3;
    pf[I_PRED_4x4_VR]  = x264_predict_4x4_vr_ssse3;
    pf[I_PRED_4x4_HD]  = x264_predict_4x4_hd_ssse3;
    if( cpu&X264_CPU_CACHELINE_64 )
        pf[I_PRED_4x4_VR] = x264_predict_4x4_vr_cache64_ssse3;
#endif // HIGH_BIT_DEPTH
}
