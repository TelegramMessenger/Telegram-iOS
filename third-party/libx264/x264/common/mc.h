/*****************************************************************************
 * mc.h: motion compensation
 *****************************************************************************
 * Copyright (C) 2004-2022 x264 project
 *
 * Authors: Loren Merritt <lorenm@u.washington.edu>
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

#ifndef X264_MC_H
#define X264_MC_H

#define MC_CLIP_ADD(s,x) (s) = X264_MIN((s)+(x),(1<<15)-1)
#define MC_CLIP_ADD2(s,x)\
do\
{\
    MC_CLIP_ADD((s)[0], (x)[0]);\
    MC_CLIP_ADD((s)[1], (x)[1]);\
} while( 0 )

#define x264_mbtree_propagate_list_internal_neon x264_template(mbtree_propagate_list_internal_neon)
#define PROPAGATE_LIST(cpu)\
void x264_mbtree_propagate_list_internal_##cpu( int16_t (*mvs)[2], int16_t *propagate_amount,\
                                                uint16_t *lowres_costs, int16_t *output,\
                                                int bipred_weight, int mb_y, int len );\
\
static void mbtree_propagate_list_##cpu( x264_t *h, uint16_t *ref_costs, int16_t (*mvs)[2],\
                                         int16_t *propagate_amount, uint16_t *lowres_costs,\
                                         int bipred_weight, int mb_y, int len, int list )\
{\
    int16_t *current = h->scratch_buffer2;\
\
    x264_mbtree_propagate_list_internal_##cpu( mvs, propagate_amount, lowres_costs,\
                                               current, bipred_weight, mb_y, len );\
\
    unsigned stride = h->mb.i_mb_stride;\
    unsigned width = h->mb.i_mb_width;\
    unsigned height = h->mb.i_mb_height;\
\
    for( int i = 0; i < len; current += 32 )\
    {\
        int end = X264_MIN( i+8, len );\
        for( ; i < end; i++, current += 2 )\
        {\
            if( !(lowres_costs[i] & (1 << (list+LOWRES_COST_SHIFT))) )\
                continue;\
\
            unsigned mbx = (unsigned)current[0];\
            unsigned mby = (unsigned)current[1];\
            unsigned idx0 = mbx + mby * stride;\
            unsigned idx2 = idx0 + stride;\
\
            /* Shortcut for the simple/common case of zero MV */\
            if( !M32( mvs[i] ) )\
            {\
                MC_CLIP_ADD( ref_costs[idx0], current[16] );\
                continue;\
            }\
\
            if( mbx < width-1 && mby < height-1 )\
            {\
                MC_CLIP_ADD2( ref_costs+idx0, current+16 );\
                MC_CLIP_ADD2( ref_costs+idx2, current+32 );\
            }\
            else\
            {\
                /* Note: this takes advantage of unsigned representation to\
                 * catch negative mbx/mby. */\
                if( mby < height )\
                {\
                    if( mbx < width )\
                        MC_CLIP_ADD( ref_costs[idx0+0], current[16] );\
                    if( mbx+1 < width )\
                        MC_CLIP_ADD( ref_costs[idx0+1], current[17] );\
                }\
                if( mby+1 < height )\
                {\
                    if( mbx < width )\
                        MC_CLIP_ADD( ref_costs[idx2+0], current[32] );\
                    if( mbx+1 < width )\
                        MC_CLIP_ADD( ref_costs[idx2+1], current[33] );\
                }\
            }\
        }\
    }\
}

#define x264_plane_copy_c x264_template(plane_copy_c)
void x264_plane_copy_c( pixel *, intptr_t, pixel *, intptr_t, int w, int h );

#define PLANE_COPY(align, cpu)\
static void plane_copy_##cpu( pixel *dst, intptr_t i_dst, pixel *src, intptr_t i_src, int w, int h )\
{\
    int c_w = (align) / SIZEOF_PIXEL - 1;\
    if( w < 256 ) /* tiny resolutions don't want non-temporal hints. dunno the exact threshold. */\
        x264_plane_copy_c( dst, i_dst, src, i_src, w, h );\
    else if( !(w&c_w) )\
        x264_plane_copy_core_##cpu( dst, i_dst, src, i_src, w, h );\
    else\
    {\
        if( --h > 0 )\
        {\
            if( i_src > 0 )\
            {\
                x264_plane_copy_core_##cpu( dst, i_dst, src, i_src, (w+c_w)&~c_w, h );\
                dst += i_dst * h;\
                src += i_src * h;\
            }\
            else\
                x264_plane_copy_core_##cpu( dst+i_dst, i_dst, src+i_src, i_src, (w+c_w)&~c_w, h );\
        }\
        /* use plain memcpy on the last line (in memory order) to avoid overreading src. */\
        memcpy( dst, src, w*SIZEOF_PIXEL );\
    }\
}

#define x264_plane_copy_swap_c x264_template(plane_copy_swap_c)
void x264_plane_copy_swap_c( pixel *, intptr_t, pixel *, intptr_t, int w, int h );

#define PLANE_COPY_SWAP(align, cpu)\
static void plane_copy_swap_##cpu( pixel *dst, intptr_t i_dst, pixel *src, intptr_t i_src, int w, int h )\
{\
    int c_w = (align>>1) / SIZEOF_PIXEL - 1;\
    if( !(w&c_w) )\
        x264_plane_copy_swap_core_##cpu( dst, i_dst, src, i_src, w, h );\
    else if( w > c_w )\
    {\
        if( --h > 0 )\
        {\
            if( i_src > 0 )\
            {\
                x264_plane_copy_swap_core_##cpu( dst, i_dst, src, i_src, (w+c_w)&~c_w, h );\
                dst += i_dst * h;\
                src += i_src * h;\
            }\
            else\
                x264_plane_copy_swap_core_##cpu( dst+i_dst, i_dst, src+i_src, i_src, (w+c_w)&~c_w, h );\
        }\
        x264_plane_copy_swap_core_##cpu( dst, 0, src, 0, w&~c_w, 1 );\
        for( int x = 2*(w&~c_w); x < 2*w; x += 2 )\
        {\
            dst[x]   = src[x+1];\
            dst[x+1] = src[x];\
        }\
    }\
    else\
        x264_plane_copy_swap_c( dst, i_dst, src, i_src, w, h );\
}

#define x264_plane_copy_deinterleave_c x264_template(plane_copy_deinterleave_c)
void x264_plane_copy_deinterleave_c( pixel *dsta, intptr_t i_dsta, pixel *dstb, intptr_t i_dstb,
                                     pixel *src, intptr_t i_src, int w, int h );

/* We can utilize existing plane_copy_deinterleave() functions for YUYV/UYUV
 * input with the additional constraint that we cannot overread src. */
#define PLANE_COPY_YUYV(align, cpu)\
static void plane_copy_deinterleave_yuyv_##cpu( pixel *dsta, intptr_t i_dsta, pixel *dstb, intptr_t i_dstb,\
                                                pixel *src, intptr_t i_src, int w, int h )\
{\
    int c_w = (align>>1) / SIZEOF_PIXEL - 1;\
    if( !(w&c_w) )\
        x264_plane_copy_deinterleave_##cpu( dsta, i_dsta, dstb, i_dstb, src, i_src, w, h );\
    else if( w > c_w )\
    {\
        if( --h > 0 )\
        {\
            if( i_src > 0 )\
            {\
                x264_plane_copy_deinterleave_##cpu( dsta, i_dsta, dstb, i_dstb, src, i_src, w, h );\
                dsta += i_dsta * h;\
                dstb += i_dstb * h;\
                src  += i_src  * h;\
            }\
            else\
                x264_plane_copy_deinterleave_##cpu( dsta+i_dsta, i_dsta, dstb+i_dstb, i_dstb,\
                                                    src+i_src, i_src, w, h );\
        }\
        x264_plane_copy_deinterleave_c( dsta, 0, dstb, 0, src, 0, w, 1 );\
    }\
    else\
        x264_plane_copy_deinterleave_c( dsta, i_dsta, dstb, i_dstb, src, i_src, w, h );\
}

#define x264_plane_copy_interleave_c x264_template(plane_copy_interleave_c)
void x264_plane_copy_interleave_c( pixel *dst,  intptr_t i_dst,
                                   pixel *srcu, intptr_t i_srcu,
                                   pixel *srcv, intptr_t i_srcv, int w, int h );

#define PLANE_INTERLEAVE(cpu) \
static void plane_copy_interleave_##cpu( pixel *dst,  intptr_t i_dst,\
                                         pixel *srcu, intptr_t i_srcu,\
                                         pixel *srcv, intptr_t i_srcv, int w, int h )\
{\
    int c_w = 16 / SIZEOF_PIXEL - 1;\
    if( !(w&c_w) )\
        x264_plane_copy_interleave_core_##cpu( dst, i_dst, srcu, i_srcu, srcv, i_srcv, w, h );\
    else if( w > c_w && (i_srcu ^ i_srcv) >= 0 ) /* only works correctly for strides with identical signs */\
    {\
        if( --h > 0 )\
        {\
            if( i_srcu > 0 )\
            {\
                x264_plane_copy_interleave_core_##cpu( dst, i_dst, srcu, i_srcu, srcv, i_srcv, (w+c_w)&~c_w, h );\
                dst  += i_dst  * h;\
                srcu += i_srcu * h;\
                srcv += i_srcv * h;\
            }\
            else\
                x264_plane_copy_interleave_core_##cpu( dst+i_dst, i_dst, srcu+i_srcu, i_srcu, srcv+i_srcv, i_srcv, (w+c_w)&~c_w, h );\
        }\
        x264_plane_copy_interleave_c( dst, 0, srcu, 0, srcv, 0, w, 1 );\
    }\
    else\
        x264_plane_copy_interleave_c( dst, i_dst, srcu, i_srcu, srcv, i_srcv, w, h );\
}

struct x264_weight_t;
typedef void (* weight_fn_t)( pixel *, intptr_t, pixel *,intptr_t, const struct x264_weight_t *, int );
typedef struct x264_weight_t
{
    /* aligning the first member is a gcc hack to force the struct to be
     * 16 byte aligned, as well as force sizeof(struct) to be a multiple of 16 */
    ALIGNED_16( int16_t cachea[8] );
    int16_t cacheb[8];
    int32_t i_denom;
    int32_t i_scale;
    int32_t i_offset;
    weight_fn_t *weightfn;
} ALIGNED_16( x264_weight_t );

#define x264_weight_none ((const x264_weight_t*)x264_zero)

#define SET_WEIGHT( w, b, s, d, o )\
{\
    (w).i_scale = (s);\
    (w).i_denom = (d);\
    (w).i_offset = (o);\
    if( b )\
        h->mc.weight_cache( h, &w );\
    else\
        w.weightfn = NULL;\
}

/* Do the MC
 * XXX: Only width = 4, 8 or 16 are valid
 * width == 4 -> height == 4 or 8
 * width == 8 -> height == 4 or 8 or 16
 * width == 16-> height == 8 or 16
 * */

typedef struct
{
    void (*mc_luma)( pixel *dst, intptr_t i_dst, pixel **src, intptr_t i_src,
                     int mvx, int mvy, int i_width, int i_height, const x264_weight_t *weight );

    /* may round up the dimensions if they're not a power of 2 */
    pixel* (*get_ref)( pixel *dst, intptr_t *i_dst, pixel **src, intptr_t i_src,
                       int mvx, int mvy, int i_width, int i_height, const x264_weight_t *weight );

    /* mc_chroma may write up to 2 bytes of garbage to the right of dst,
     * so it must be run from left to right. */
    void (*mc_chroma)( pixel *dstu, pixel *dstv, intptr_t i_dst, pixel *src, intptr_t i_src,
                       int mvx, int mvy, int i_width, int i_height );

    void (*avg[12])( pixel *dst,  intptr_t dst_stride, pixel *src1, intptr_t src1_stride,
                     pixel *src2, intptr_t src2_stride, int i_weight );

    /* only 16x16, 8x8, and 4x4 defined */
    void (*copy[7])( pixel *dst, intptr_t dst_stride, pixel *src, intptr_t src_stride, int i_height );
    void (*copy_16x16_unaligned)( pixel *dst, intptr_t dst_stride, pixel *src, intptr_t src_stride, int i_height );

    void (*store_interleave_chroma)( pixel *dst, intptr_t i_dst, pixel *srcu, pixel *srcv, int height );
    void (*load_deinterleave_chroma_fenc)( pixel *dst, pixel *src, intptr_t i_src, int height );
    void (*load_deinterleave_chroma_fdec)( pixel *dst, pixel *src, intptr_t i_src, int height );

    void (*plane_copy)( pixel *dst, intptr_t i_dst, pixel *src, intptr_t i_src, int w, int h );
    void (*plane_copy_swap)( pixel *dst, intptr_t i_dst, pixel *src, intptr_t i_src, int w, int h );
    void (*plane_copy_interleave)( pixel *dst,  intptr_t i_dst, pixel *srcu, intptr_t i_srcu,
                                   pixel *srcv, intptr_t i_srcv, int w, int h );
    /* may write up to 15 pixels off the end of each plane */
    void (*plane_copy_deinterleave)( pixel *dstu, intptr_t i_dstu, pixel *dstv, intptr_t i_dstv,
                                     pixel *src,  intptr_t i_src, int w, int h );
    void (*plane_copy_deinterleave_yuyv)( pixel *dsta, intptr_t i_dsta, pixel *dstb, intptr_t i_dstb,
                                          pixel *src,  intptr_t i_src, int w, int h );
    void (*plane_copy_deinterleave_rgb)( pixel *dsta, intptr_t i_dsta, pixel *dstb, intptr_t i_dstb,
                                         pixel *dstc, intptr_t i_dstc, pixel *src,  intptr_t i_src, int pw, int w, int h );
    void (*plane_copy_deinterleave_v210)( pixel *dsty, intptr_t i_dsty,
                                          pixel *dstc, intptr_t i_dstc,
                                          uint32_t *src, intptr_t i_src, int w, int h );
    void (*hpel_filter)( pixel *dsth, pixel *dstv, pixel *dstc, pixel *src,
                         intptr_t i_stride, int i_width, int i_height, int16_t *buf );

    /* prefetch the next few macroblocks of fenc or fdec */
    void (*prefetch_fenc)    ( pixel *pix_y, intptr_t stride_y, pixel *pix_uv, intptr_t stride_uv, int mb_x );
    void (*prefetch_fenc_400)( pixel *pix_y, intptr_t stride_y, pixel *pix_uv, intptr_t stride_uv, int mb_x );
    void (*prefetch_fenc_420)( pixel *pix_y, intptr_t stride_y, pixel *pix_uv, intptr_t stride_uv, int mb_x );
    void (*prefetch_fenc_422)( pixel *pix_y, intptr_t stride_y, pixel *pix_uv, intptr_t stride_uv, int mb_x );
    /* prefetch the next few macroblocks of a hpel reference frame */
    void (*prefetch_ref)( pixel *pix, intptr_t stride, int parity );

    void *(*memcpy_aligned)( void *dst, const void *src, size_t n );
    void (*memzero_aligned)( void *dst, size_t n );

    /* successive elimination prefilter */
    void (*integral_init4h)( uint16_t *sum, pixel *pix, intptr_t stride );
    void (*integral_init8h)( uint16_t *sum, pixel *pix, intptr_t stride );
    void (*integral_init4v)( uint16_t *sum8, uint16_t *sum4, intptr_t stride );
    void (*integral_init8v)( uint16_t *sum8, intptr_t stride );

    void (*frame_init_lowres_core)( pixel *src0, pixel *dst0, pixel *dsth, pixel *dstv, pixel *dstc,
                                    intptr_t src_stride, intptr_t dst_stride, int width, int height );
    weight_fn_t *weight;
    weight_fn_t *offsetadd;
    weight_fn_t *offsetsub;
    void (*weight_cache)( x264_t *, x264_weight_t * );

    void (*mbtree_propagate_cost)( int16_t *dst, uint16_t *propagate_in, uint16_t *intra_costs,
                                   uint16_t *inter_costs, uint16_t *inv_qscales, float *fps_factor, int len );
    void (*mbtree_propagate_list)( x264_t *h, uint16_t *ref_costs, int16_t (*mvs)[2],
                                   int16_t *propagate_amount, uint16_t *lowres_costs,
                                   int bipred_weight, int mb_y, int len, int list );
    void (*mbtree_fix8_pack)( uint16_t *dst, float *src, int count );
    void (*mbtree_fix8_unpack)( float *dst, uint16_t *src, int count );
} x264_mc_functions_t;

#define x264_mc_init x264_template(mc_init)
void x264_mc_init( uint32_t cpu, x264_mc_functions_t *pf, int cpu_independent );

#endif
