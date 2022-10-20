/*****************************************************************************
 * util.h: x86 inline asm
 *****************************************************************************
 * Copyright (C) 2008-2022 x264 project
 *
 * Authors: Fiona Glaser <fiona@x264.com>
 *          Loren Merritt <lorenm@u.washington.edu>
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

#ifndef X264_X86_UTIL_H
#define X264_X86_UTIL_H

#ifdef __SSE__
#include <xmmintrin.h>

#undef M128_ZERO
#define M128_ZERO ((__m128){0,0,0,0})
#define x264_union128_t x264_union128_sse_t
typedef union { __m128 i; uint64_t q[2]; uint32_t d[4]; uint16_t w[8]; uint8_t b[16]; } MAY_ALIAS x264_union128_sse_t;
#if HAVE_VECTOREXT
typedef uint32_t v4si __attribute__((vector_size (16)));
#endif
#endif // __SSE__

#if HAVE_X86_INLINE_ASM && HAVE_MMX

#define x264_median_mv x264_median_mv_mmx2
static ALWAYS_INLINE void x264_median_mv_mmx2( int16_t *dst, int16_t *a, int16_t *b, int16_t *c )
{
    asm(
        "movd   %1,    %%mm0 \n"
        "movd   %2,    %%mm1 \n"
        "movq   %%mm0, %%mm3 \n"
        "movd   %3,    %%mm2 \n"
        "pmaxsw %%mm1, %%mm0 \n"
        "pminsw %%mm3, %%mm1 \n"
        "pminsw %%mm2, %%mm0 \n"
        "pmaxsw %%mm1, %%mm0 \n"
        "movd   %%mm0, %0    \n"
        :"=m"(*(x264_union32_t*)dst)
        :"m"(M32( a )), "m"(M32( b )), "m"(M32( c ))
        :"mm0", "mm1", "mm2", "mm3"
    );
}

#define x264_predictor_difference x264_predictor_difference_mmx2
static ALWAYS_INLINE int x264_predictor_difference_mmx2( int16_t (*mvc)[2], intptr_t i_mvc )
{
    int sum;
    static const uint64_t pw_1 = 0x0001000100010001ULL;

    asm(
        "pxor    %%mm4, %%mm4 \n"
        "test    $1, %1       \n"
        "jnz 3f               \n"
        "movd    -8(%2,%1,4), %%mm0 \n"
        "movd    -4(%2,%1,4), %%mm3 \n"
        "psubw   %%mm3, %%mm0 \n"
        "jmp 2f               \n"
        "3:                   \n"
        "dec     %1           \n"
        "1:                   \n"
        "movq    -8(%2,%1,4), %%mm0 \n"
        "psubw   -4(%2,%1,4), %%mm0 \n"
        "2:                   \n"
        "sub     $2,    %1    \n"
        "pxor    %%mm2, %%mm2 \n"
        "psubw   %%mm0, %%mm2 \n"
        "pmaxsw  %%mm2, %%mm0 \n"
        "paddusw %%mm0, %%mm4 \n"
        "jg 1b                \n"
        "pmaddwd %4, %%mm4    \n"
        "pshufw $14, %%mm4, %%mm0 \n"
        "paddd   %%mm0, %%mm4 \n"
        "movd    %%mm4, %0    \n"
        :"=r"(sum), "+r"(i_mvc)
        :"r"(mvc), "m"(MEM_DYN( mvc, const int16_t )), "m"(pw_1)
        :"mm0", "mm2", "mm3", "mm4", "cc"
    );
    return sum;
}

#define x264_cabac_mvd_sum x264_cabac_mvd_sum_mmx2
static ALWAYS_INLINE uint16_t x264_cabac_mvd_sum_mmx2(uint8_t *mvdleft, uint8_t *mvdtop)
{
    static const uint64_t pb_2    = 0x0202020202020202ULL;
    static const uint64_t pb_32   = 0x2020202020202020ULL;
    static const uint64_t pb_33   = 0x2121212121212121ULL;
    int amvd;
    asm(
        "movd         %1, %%mm0 \n"
        "movd         %2, %%mm1 \n"
        "paddusb   %%mm1, %%mm0 \n"
        "pminub       %5, %%mm0 \n"
        "pxor      %%mm2, %%mm2 \n"
        "movq      %%mm0, %%mm1 \n"
        "pcmpgtb      %3, %%mm0 \n"
        "pcmpgtb      %4, %%mm1 \n"
        "psubb     %%mm0, %%mm2 \n"
        "psubb     %%mm1, %%mm2 \n"
        "movd      %%mm2, %0    \n"
        :"=r"(amvd)
        :"m"(M16( mvdleft )),"m"(M16( mvdtop )),
         "m"(pb_2),"m"(pb_32),"m"(pb_33)
        :"mm0", "mm1", "mm2"
    );
    return (uint16_t)amvd;
}

#define x264_predictor_clip x264_predictor_clip_mmx2
static ALWAYS_INLINE int x264_predictor_clip_mmx2( int16_t (*dst)[2], int16_t (*mvc)[2], int i_mvc, int16_t mv_limit[2][2], uint32_t pmv )
{
    static const uint32_t pd_32 = 0x20;
    intptr_t tmp = (intptr_t)mv_limit, mvc_max = i_mvc, i = 0;

    asm(
        "movq       (%2), %%mm5 \n"
        "movd         %6, %%mm3 \n"
        "psllw        $2, %%mm5 \n" // Convert to subpel
        "pshufw $0xEE, %%mm5, %%mm6 \n"
        "dec         %k3        \n"
        "jz 2f                  \n" // if( i_mvc == 1 ) {do the last iteration}
        "punpckldq %%mm3, %%mm3 \n"
        "punpckldq %%mm5, %%mm5 \n"
        "movd         %7, %%mm4 \n"
        "lea   (%0,%3,4), %3    \n"
        "1:                     \n"
        "movq       (%0), %%mm0 \n"
        "add          $8, %0    \n"
        "movq      %%mm3, %%mm1 \n"
        "pxor      %%mm2, %%mm2 \n"
        "pcmpeqd   %%mm0, %%mm1 \n" // mv == pmv
        "pcmpeqd   %%mm0, %%mm2 \n" // mv == 0
        "por       %%mm1, %%mm2 \n" // (mv == pmv || mv == 0) * -1
        "pmovmskb  %%mm2, %k2   \n" // (mv == pmv || mv == 0) * 0xf
        "pmaxsw    %%mm5, %%mm0 \n"
        "pminsw    %%mm6, %%mm0 \n"
        "pand      %%mm4, %%mm2 \n" // (mv0 == pmv || mv0 == 0) * 32
        "psrlq     %%mm2, %%mm0 \n" // drop mv0 if it's skipped
        "movq      %%mm0, (%5,%4,4) \n"
        "and         $24, %k2   \n"
        "add          $2, %4    \n"
        "add          $8, %k2   \n"
        "shr          $4, %k2   \n" // (4-val)>>1
        "sub          %2, %4    \n" // +1 for each valid motion vector
        "cmp          %3, %0    \n"
        "jl 1b                  \n"
        "jg 3f                  \n" // if( i == i_mvc - 1 ) {do the last iteration}

        /* Do the last iteration */
        "2:                     \n"
        "movd       (%0), %%mm0 \n"
        "pxor      %%mm2, %%mm2 \n"
        "pcmpeqd   %%mm0, %%mm3 \n"
        "pcmpeqd   %%mm0, %%mm2 \n"
        "por       %%mm3, %%mm2 \n"
        "pmovmskb  %%mm2, %k2   \n"
        "pmaxsw    %%mm5, %%mm0 \n"
        "pminsw    %%mm6, %%mm0 \n"
        "movd      %%mm0, (%5,%4,4) \n"
        "inc          %4        \n"
        "and          $1, %k2   \n"
        "sub          %2, %4    \n" // output += !(mv == pmv || mv == 0)
        "3:                     \n"
        :"+r"(mvc), "=m"(MEM_DYN( dst, int16_t )), "+r"(tmp), "+r"(mvc_max), "+r"(i)
        :"r"(dst), "g"(pmv), "m"(pd_32), "m"(MEM_DYN( mvc, const int16_t ))
        :"mm0", "mm1", "mm2", "mm3", "mm4", "mm5", "mm6", "cc"
    );
    return i;
}

/* Same as the above, except we do (mv + 2) >> 2 on the input. */
#define x264_predictor_roundclip x264_predictor_roundclip_mmx2
static ALWAYS_INLINE int x264_predictor_roundclip_mmx2( int16_t (*dst)[2], int16_t (*mvc)[2], int i_mvc, int16_t mv_limit[2][2], uint32_t pmv )
{
    static const uint64_t pw_2 = 0x0002000200020002ULL;
    static const uint32_t pd_32 = 0x20;
    intptr_t tmp = (intptr_t)mv_limit, mvc_max = i_mvc, i = 0;

    asm(
        "movq       (%2), %%mm5 \n"
        "movq         %6, %%mm7 \n"
        "movd         %7, %%mm3 \n"
        "pshufw $0xEE, %%mm5, %%mm6 \n"
        "dec         %k3        \n"
        "jz 2f                  \n"
        "punpckldq %%mm3, %%mm3 \n"
        "punpckldq %%mm5, %%mm5 \n"
        "movd         %8, %%mm4 \n"
        "lea   (%0,%3,4), %3    \n"
        "1:                     \n"
        "movq       (%0), %%mm0 \n"
        "add          $8, %0    \n"
        "paddw     %%mm7, %%mm0 \n"
        "psraw        $2, %%mm0 \n"
        "movq      %%mm3, %%mm1 \n"
        "pxor      %%mm2, %%mm2 \n"
        "pcmpeqd   %%mm0, %%mm1 \n"
        "pcmpeqd   %%mm0, %%mm2 \n"
        "por       %%mm1, %%mm2 \n"
        "pmovmskb  %%mm2, %k2   \n"
        "pmaxsw    %%mm5, %%mm0 \n"
        "pminsw    %%mm6, %%mm0 \n"
        "pand      %%mm4, %%mm2 \n"
        "psrlq     %%mm2, %%mm0 \n"
        "movq      %%mm0, (%5,%4,4) \n"
        "and         $24, %k2   \n"
        "add          $2, %4    \n"
        "add          $8, %k2   \n"
        "shr          $4, %k2   \n"
        "sub          %2, %4    \n"
        "cmp          %3, %0    \n"
        "jl 1b                  \n"
        "jg 3f                  \n"

        /* Do the last iteration */
        "2:                     \n"
        "movd       (%0), %%mm0 \n"
        "paddw     %%mm7, %%mm0 \n"
        "psraw        $2, %%mm0 \n"
        "pxor      %%mm2, %%mm2 \n"
        "pcmpeqd   %%mm0, %%mm3 \n"
        "pcmpeqd   %%mm0, %%mm2 \n"
        "por       %%mm3, %%mm2 \n"
        "pmovmskb  %%mm2, %k2   \n"
        "pmaxsw    %%mm5, %%mm0 \n"
        "pminsw    %%mm6, %%mm0 \n"
        "movd      %%mm0, (%5,%4,4) \n"
        "inc          %4        \n"
        "and          $1, %k2   \n"
        "sub          %2, %4    \n"
        "3:                     \n"
        :"+r"(mvc), "=m"(MEM_DYN( dst, int16_t )), "+r"(tmp), "+r"(mvc_max), "+r"(i)
        :"r"(dst), "m"(pw_2), "g"(pmv), "m"(pd_32), "m"(MEM_DYN( mvc, const int16_t ))
        :"mm0", "mm1", "mm2", "mm3", "mm4", "mm5", "mm6", "mm7", "cc"
    );
    return i;
}

#endif

#endif
