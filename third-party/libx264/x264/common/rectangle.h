/*****************************************************************************
 * rectangle.h: rectangle filling
 *****************************************************************************
 * Copyright (C) 2003-2022 x264 project
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

/* This function should only be called with constant w / h / s arguments! */
static ALWAYS_INLINE void x264_macroblock_cache_rect( void *dst, int w, int h, int s, uint32_t v )
{
    uint8_t *d = dst;
    uint16_t v2 = s >= 2 ? v : v * 0x101;
    uint32_t v4 = s >= 4 ? v : s >= 2 ? v * 0x10001 : v * 0x1010101;
    uint64_t v8 = v4 + ((uint64_t)v4 << 32);
    s *= 8;

    if( w == 2 )
    {
        M16( d+s*0 ) = v2;
        if( h == 1 ) return;
        M16( d+s*1 ) = v2;
        if( h == 2 ) return;
        M16( d+s*2 ) = v2;
        M16( d+s*3 ) = v2;
    }
    else if( w == 4 )
    {
        M32( d+s*0 ) = v4;
        if( h == 1 ) return;
        M32( d+s*1 ) = v4;
        if( h == 2 ) return;
        M32( d+s*2 ) = v4;
        M32( d+s*3 ) = v4;
    }
    else if( w == 8 )
    {
        if( WORD_SIZE == 8 )
        {
            M64( d+s*0 ) = v8;
            if( h == 1 ) return;
            M64( d+s*1 ) = v8;
            if( h == 2 ) return;
            M64( d+s*2 ) = v8;
            M64( d+s*3 ) = v8;
        }
        else
        {
            M32( d+s*0+0 ) = v4;
            M32( d+s*0+4 ) = v4;
            if( h == 1 ) return;
            M32( d+s*1+0 ) = v4;
            M32( d+s*1+4 ) = v4;
            if( h == 2 ) return;
            M32( d+s*2+0 ) = v4;
            M32( d+s*2+4 ) = v4;
            M32( d+s*3+0 ) = v4;
            M32( d+s*3+4 ) = v4;
        }
    }
    else if( w == 16 )
    {
        /* height 1, width 16 doesn't occur */
        assert( h != 1 );
#if HAVE_VECTOREXT && defined(__SSE__)
        v4si v16 = {v,v,v,v};

        M128( d+s*0+0 ) = (__m128)v16;
        M128( d+s*1+0 ) = (__m128)v16;
        if( h == 2 ) return;
        M128( d+s*2+0 ) = (__m128)v16;
        M128( d+s*3+0 ) = (__m128)v16;
#else
        if( WORD_SIZE == 8 )
        {
            do
            {
                M64( d+s*0+0 ) = v8;
                M64( d+s*0+8 ) = v8;
                M64( d+s*1+0 ) = v8;
                M64( d+s*1+8 ) = v8;
                h -= 2;
                d += s*2;
            } while( h );
        }
        else
        {
            do
            {
                M32( d+ 0 ) = v4;
                M32( d+ 4 ) = v4;
                M32( d+ 8 ) = v4;
                M32( d+12 ) = v4;
                d += s;
            } while( --h );
        }
#endif
    }
    else
        assert(0);
}

#define x264_cache_mv_func_table x264_template(cache_mv_func_table)
extern void (*x264_cache_mv_func_table[10])(void *, uint32_t);
#define x264_cache_mvd_func_table x264_template(cache_mvd_func_table)
extern void (*x264_cache_mvd_func_table[10])(void *, uint32_t);
#define x264_cache_ref_func_table x264_template(cache_ref_func_table)
extern void (*x264_cache_ref_func_table[10])(void *, uint32_t);

#define x264_macroblock_cache_mv_ptr( a, x, y, w, h, l, mv ) x264_macroblock_cache_mv( a, x, y, w, h, l, M32( mv ) )
static ALWAYS_INLINE void x264_macroblock_cache_mv( x264_t *h, int x, int y, int width, int height, int i_list, uint32_t mv )
{
    void *mv_cache = &h->mb.cache.mv[i_list][X264_SCAN8_0+x+8*y];
    if( x264_nonconstant_p( width ) || x264_nonconstant_p( height ) )
        x264_cache_mv_func_table[width + (height<<1)-3]( mv_cache, mv );
    else
        x264_macroblock_cache_rect( mv_cache, width*4, height, 4, mv );
}
static ALWAYS_INLINE void x264_macroblock_cache_mvd( x264_t *h, int x, int y, int width, int height, int i_list, uint16_t mvd )
{
    void *mvd_cache = &h->mb.cache.mvd[i_list][X264_SCAN8_0+x+8*y];
    if( x264_nonconstant_p( width ) || x264_nonconstant_p( height ) )
        x264_cache_mvd_func_table[width + (height<<1)-3]( mvd_cache, mvd );
    else
        x264_macroblock_cache_rect( mvd_cache, width*2, height, 2, mvd );
}
static ALWAYS_INLINE void x264_macroblock_cache_ref( x264_t *h, int x, int y, int width, int height, int i_list, int8_t ref )
{
    void *ref_cache = &h->mb.cache.ref[i_list][X264_SCAN8_0+x+8*y];
    if( x264_nonconstant_p( width ) || x264_nonconstant_p( height ) )
        x264_cache_ref_func_table[width + (height<<1)-3]( ref_cache, (uint8_t)ref );
    else
        x264_macroblock_cache_rect( ref_cache, width, height, 1, (uint8_t)ref );
}
static ALWAYS_INLINE void x264_macroblock_cache_skip( x264_t *h, int x, int y, int width, int height, int b_skip )
{
    x264_macroblock_cache_rect( &h->mb.cache.skip[X264_SCAN8_0+x+8*y], width, height, 1, b_skip );
}
static ALWAYS_INLINE void x264_macroblock_cache_intra8x8_pred( x264_t *h, int x, int y, int i_mode )
{
    x264_macroblock_cache_rect( &h->mb.cache.intra4x4_pred_mode[X264_SCAN8_0+x+8*y], 2, 2, 1, i_mode );
}
