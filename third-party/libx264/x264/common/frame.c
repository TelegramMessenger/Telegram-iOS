/*****************************************************************************
 * frame.c: frame handling
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

#include "common.h"

static int align_stride( int x, int align, int disalign )
{
    x = ALIGN( x, align );
    if( !(x&(disalign-1)) )
        x += align;
    return x;
}

static int align_plane_size( int x, int disalign )
{
    if( !(x&(disalign-1)) )
        x += X264_MAX( 128, NATIVE_ALIGN ) / SIZEOF_PIXEL;
    return x;
}

static int frame_internal_csp( int external_csp )
{
    int csp = external_csp & X264_CSP_MASK;
    if( csp == X264_CSP_I400 )
        return X264_CSP_I400;
    if( csp >= X264_CSP_I420 && csp < X264_CSP_I422 )
        return X264_CSP_NV12;
    if( csp >= X264_CSP_I422 && csp < X264_CSP_I444 )
        return X264_CSP_NV16;
    if( csp >= X264_CSP_I444 && csp <= X264_CSP_RGB )
        return X264_CSP_I444;
    return X264_CSP_NONE;
}

static x264_frame_t *frame_new( x264_t *h, int b_fdec )
{
    x264_frame_t *frame;
    int i_csp = frame_internal_csp( h->param.i_csp );
    int i_mb_count = h->mb.i_mb_count;
    int i_stride, i_width, i_lines, luma_plane_count;
    int i_padv = PADV << PARAM_INTERLACED;
    int align = NATIVE_ALIGN / SIZEOF_PIXEL;
#if ARCH_X86 || ARCH_X86_64
    if( h->param.cpu&X264_CPU_CACHELINE_64 || h->param.cpu&X264_CPU_AVX512 )
        align = 64 / SIZEOF_PIXEL;
    else if( h->param.cpu&X264_CPU_CACHELINE_32 || h->param.cpu&X264_CPU_AVX )
        align = 32 / SIZEOF_PIXEL;
    else
        align = 16 / SIZEOF_PIXEL;
#endif
#if ARCH_PPC
    int disalign = (1<<9) / SIZEOF_PIXEL;
#else
    int disalign = (1<<10) / SIZEOF_PIXEL;
#endif

    CHECKED_MALLOCZERO( frame, sizeof(x264_frame_t) );
    PREALLOC_INIT

    /* allocate frame data (+64 for extra data for me) */
    i_width  = h->mb.i_mb_width*16;
    i_lines  = h->mb.i_mb_height*16;
    i_stride = align_stride( i_width + PADH2, align, disalign );

    if( i_csp == X264_CSP_NV12 || i_csp == X264_CSP_NV16 )
    {
        luma_plane_count = 1;
        frame->i_plane = 2;
        for( int i = 0; i < 2; i++ )
        {
            frame->i_width[i] = i_width >> i;
            frame->i_lines[i] = i_lines >> (i && i_csp == X264_CSP_NV12);
            frame->i_stride[i] = i_stride;
        }
    }
    else if( i_csp == X264_CSP_I444 )
    {
        luma_plane_count = 3;
        frame->i_plane = 3;
        for( int i = 0; i < 3; i++ )
        {
            frame->i_width[i] = i_width;
            frame->i_lines[i] = i_lines;
            frame->i_stride[i] = i_stride;
        }
    }
    else if( i_csp == X264_CSP_I400 )
    {
        luma_plane_count = 1;
        frame->i_plane = 1;
        frame->i_width[0] = i_width;
        frame->i_lines[0] = i_lines;
        frame->i_stride[0] = i_stride;
    }
    else
        goto fail;

    frame->i_csp = i_csp;
    frame->i_width_lowres = frame->i_width[0]/2;
    frame->i_lines_lowres = frame->i_lines[0]/2;
    frame->i_stride_lowres = align_stride( frame->i_width_lowres + PADH2, align, disalign<<1 );

    for( int i = 0; i < h->param.i_bframe + 2; i++ )
        for( int j = 0; j < h->param.i_bframe + 2; j++ )
            PREALLOC( frame->i_row_satds[i][j], i_lines/16 * sizeof(int) );

    frame->i_poc = -1;
    frame->i_type = X264_TYPE_AUTO;
    frame->i_qpplus1 = X264_QP_AUTO;
    frame->i_pts = -1;
    frame->i_frame = -1;
    frame->i_frame_num = -1;
    frame->i_lines_completed = -1;
    frame->b_fdec = b_fdec;
    frame->i_pic_struct = PIC_STRUCT_AUTO;
    frame->i_field_cnt = -1;
    frame->i_duration =
    frame->i_cpb_duration =
    frame->i_dpb_output_delay =
    frame->i_cpb_delay = 0;
    frame->i_coded_fields_lookahead =
    frame->i_cpb_delay_lookahead = -1;

    frame->orig = frame;

    if( i_csp == X264_CSP_NV12 || i_csp == X264_CSP_NV16 )
    {
        int chroma_padv = i_padv >> (i_csp == X264_CSP_NV12);
        int chroma_plane_size = (frame->i_stride[1] * (frame->i_lines[1] + 2*chroma_padv));
        PREALLOC( frame->buffer[1], chroma_plane_size * SIZEOF_PIXEL );
        if( PARAM_INTERLACED )
            PREALLOC( frame->buffer_fld[1], chroma_plane_size * SIZEOF_PIXEL );
    }

    /* all 4 luma planes allocated together, since the cacheline split code
     * requires them to be in-phase wrt cacheline alignment. */

    for( int p = 0; p < luma_plane_count; p++ )
    {
        int64_t luma_plane_size = align_plane_size( frame->i_stride[p] * (frame->i_lines[p] + 2*i_padv), disalign );
        if( h->param.analyse.i_subpel_refine && b_fdec )
            luma_plane_size *= 4;

        /* FIXME: Don't allocate both buffers in non-adaptive MBAFF. */
        PREALLOC( frame->buffer[p], luma_plane_size * SIZEOF_PIXEL );
        if( PARAM_INTERLACED )
            PREALLOC( frame->buffer_fld[p], luma_plane_size * SIZEOF_PIXEL );
    }

    frame->b_duplicate = 0;

    if( b_fdec ) /* fdec frame */
    {
        PREALLOC( frame->mb_type, i_mb_count * sizeof(int8_t) );
        PREALLOC( frame->mb_partition, i_mb_count * sizeof(uint8_t) );
        PREALLOC( frame->mv[0], 2*16 * i_mb_count * sizeof(int16_t) );
        PREALLOC( frame->mv16x16, 2*(i_mb_count+1) * sizeof(int16_t) );
        PREALLOC( frame->ref[0], 4 * i_mb_count * sizeof(int8_t) );
        if( h->param.i_bframe )
        {
            PREALLOC( frame->mv[1], 2*16 * i_mb_count * sizeof(int16_t) );
            PREALLOC( frame->ref[1], 4 * i_mb_count * sizeof(int8_t) );
        }
        else
        {
            frame->mv[1]  = NULL;
            frame->ref[1] = NULL;
        }
        PREALLOC( frame->i_row_bits, i_lines/16 * sizeof(int) );
        PREALLOC( frame->f_row_qp, i_lines/16 * sizeof(float) );
        PREALLOC( frame->f_row_qscale, i_lines/16 * sizeof(float) );
        if( h->param.analyse.i_me_method >= X264_ME_ESA )
            PREALLOC( frame->buffer[3], frame->i_stride[0] * (frame->i_lines[0] + 2*i_padv) * sizeof(uint16_t) << h->frames.b_have_sub8x8_esa );
        if( PARAM_INTERLACED )
            PREALLOC( frame->field, i_mb_count * sizeof(uint8_t) );
        if( h->param.analyse.b_mb_info )
            PREALLOC( frame->effective_qp, i_mb_count * sizeof(uint8_t) );
    }
    else /* fenc frame */
    {
        if( h->frames.b_have_lowres )
        {
            int64_t luma_plane_size = align_plane_size( frame->i_stride_lowres * (frame->i_lines[0]/2 + 2*PADV), disalign );

            PREALLOC( frame->buffer_lowres, 4 * luma_plane_size * SIZEOF_PIXEL );

            for( int j = 0; j <= !!h->param.i_bframe; j++ )
                for( int i = 0; i <= h->param.i_bframe; i++ )
                {
                    PREALLOC( frame->lowres_mvs[j][i], 2*h->mb.i_mb_count*sizeof(int16_t) );
                    PREALLOC( frame->lowres_mv_costs[j][i], h->mb.i_mb_count*sizeof(int) );
                }
            PREALLOC( frame->i_propagate_cost, i_mb_count * sizeof(uint16_t) );
            for( int j = 0; j <= h->param.i_bframe+1; j++ )
                for( int i = 0; i <= h->param.i_bframe+1; i++ )
                    PREALLOC( frame->lowres_costs[j][i], i_mb_count * sizeof(uint16_t) );

            /* mbtree asm can overread the input buffers, make sure we don't read outside of allocated memory. */
            prealloc_size += NATIVE_ALIGN;
        }
        if( h->param.rc.i_aq_mode )
        {
            PREALLOC( frame->f_qp_offset, h->mb.i_mb_count * sizeof(float) );
            PREALLOC( frame->f_qp_offset_aq, h->mb.i_mb_count * sizeof(float) );
            if( h->frames.b_have_lowres )
                PREALLOC( frame->i_inv_qscale_factor, (h->mb.i_mb_count+3) * sizeof(uint16_t) );
        }
    }

    PREALLOC_END( frame->base );

    if( i_csp == X264_CSP_NV12 || i_csp == X264_CSP_NV16 )
    {
        int chroma_padv = i_padv >> (i_csp == X264_CSP_NV12);
        frame->plane[1] = frame->buffer[1] + frame->i_stride[1] * chroma_padv + PADH_ALIGN;
        if( PARAM_INTERLACED )
            frame->plane_fld[1] = frame->buffer_fld[1] + frame->i_stride[1] * chroma_padv + PADH_ALIGN;
    }

    for( int p = 0; p < luma_plane_count; p++ )
    {
        int64_t luma_plane_size = align_plane_size( frame->i_stride[p] * (frame->i_lines[p] + 2*i_padv), disalign );
        if( h->param.analyse.i_subpel_refine && b_fdec )
        {
            for( int i = 0; i < 4; i++ )
            {
                frame->filtered[p][i] = frame->buffer[p] + i*luma_plane_size + frame->i_stride[p] * i_padv + PADH_ALIGN;
                if( PARAM_INTERLACED )
                    frame->filtered_fld[p][i] = frame->buffer_fld[p] + i*luma_plane_size + frame->i_stride[p] * i_padv + PADH_ALIGN;
            }
            frame->plane[p] = frame->filtered[p][0];
            frame->plane_fld[p] = frame->filtered_fld[p][0];
        }
        else
        {
            frame->filtered[p][0] = frame->plane[p] = frame->buffer[p] + frame->i_stride[p] * i_padv + PADH_ALIGN;
            if( PARAM_INTERLACED )
                frame->filtered_fld[p][0] = frame->plane_fld[p] = frame->buffer_fld[p] + frame->i_stride[p] * i_padv + PADH_ALIGN;
        }
    }

    if( b_fdec )
    {
        M32( frame->mv16x16[0] ) = 0;
        frame->mv16x16++;

        if( h->param.analyse.i_me_method >= X264_ME_ESA )
            frame->integral = (uint16_t*)frame->buffer[3] + frame->i_stride[0] * i_padv + PADH_ALIGN;
    }
    else
    {
        if( h->frames.b_have_lowres )
        {
            int64_t luma_plane_size = align_plane_size( frame->i_stride_lowres * (frame->i_lines[0]/2 + 2*PADV), disalign );
            for( int i = 0; i < 4; i++ )
                frame->lowres[i] = frame->buffer_lowres + frame->i_stride_lowres * PADV + PADH_ALIGN + i * luma_plane_size;

            for( int j = 0; j <= !!h->param.i_bframe; j++ )
                for( int i = 0; i <= h->param.i_bframe; i++ )
                    memset( frame->lowres_mvs[j][i], 0, 2*h->mb.i_mb_count*sizeof(int16_t) );

            frame->i_intra_cost = frame->lowres_costs[0][0];
            memset( frame->i_intra_cost, -1, (i_mb_count+3) * sizeof(uint16_t) );

            if( h->param.rc.i_aq_mode )
                /* shouldn't really be initialized, just silences a valgrind false-positive in x264_mbtree_propagate_cost_sse2 */
                memset( frame->i_inv_qscale_factor, 0, (h->mb.i_mb_count+3) * sizeof(uint16_t) );
        }
    }

    if( x264_pthread_mutex_init( &frame->mutex, NULL ) )
        goto fail;
    if( x264_pthread_cond_init( &frame->cv, NULL ) )
        goto fail;

#if HAVE_OPENCL
    frame->opencl.ocl = h->opencl.ocl;
#endif

    return frame;

fail:
    x264_free( frame );
    return NULL;
}

void x264_frame_delete( x264_frame_t *frame )
{
    /* Duplicate frames are blank copies of real frames (including pointers),
     * so freeing those pointers would cause a double free later. */
    if( !frame->b_duplicate )
    {
        x264_free( frame->base );

        if( frame->param && frame->param->param_free )
        {
            x264_param_cleanup( frame->param );
            frame->param->param_free( frame->param );
        }
        if( frame->mb_info_free )
            frame->mb_info_free( frame->mb_info );
        if( frame->extra_sei.sei_free )
        {
            for( int i = 0; i < frame->extra_sei.num_payloads; i++ )
                frame->extra_sei.sei_free( frame->extra_sei.payloads[i].payload );
            frame->extra_sei.sei_free( frame->extra_sei.payloads );
        }
        x264_pthread_mutex_destroy( &frame->mutex );
        x264_pthread_cond_destroy( &frame->cv );
#if HAVE_OPENCL
        x264_opencl_frame_delete( frame );
#endif
    }
    x264_free( frame );
}

static int get_plane_ptr( x264_t *h, x264_picture_t *src, uint8_t **pix, int *stride, int plane, int xshift, int yshift )
{
    int width = h->param.i_width >> xshift;
    int height = h->param.i_height >> yshift;
    *pix = src->img.plane[plane];
    *stride = src->img.i_stride[plane];
    if( src->img.i_csp & X264_CSP_VFLIP )
    {
        *pix += (height-1) * *stride;
        *stride = -*stride;
    }
    if( width > abs(*stride) )
    {
        x264_log( h, X264_LOG_ERROR, "Input picture width (%d) is greater than stride (%d)\n", width, *stride );
        return -1;
    }
    return 0;
}

#define get_plane_ptr(...) do { if( get_plane_ptr(__VA_ARGS__) < 0 ) return -1; } while( 0 )

int x264_frame_copy_picture( x264_t *h, x264_frame_t *dst, x264_picture_t *src )
{
    int i_csp = src->img.i_csp & X264_CSP_MASK;
    if( dst->i_csp != frame_internal_csp( i_csp ) )
    {
        x264_log( h, X264_LOG_ERROR, "Invalid input colorspace\n" );
        return -1;
    }

#if HIGH_BIT_DEPTH
    if( !(src->img.i_csp & X264_CSP_HIGH_DEPTH) )
    {
        x264_log( h, X264_LOG_ERROR, "This build of x264 requires high depth input. Rebuild to support 8-bit input.\n" );
        return -1;
    }
#else
    if( src->img.i_csp & X264_CSP_HIGH_DEPTH )
    {
        x264_log( h, X264_LOG_ERROR, "This build of x264 requires 8-bit input. Rebuild to support high depth input.\n" );
        return -1;
    }
#endif

    if( BIT_DEPTH != 10 && i_csp == X264_CSP_V210 )
    {
        x264_log( h, X264_LOG_ERROR, "v210 input is only compatible with bit-depth of 10 bits\n" );
        return -1;
    }

    if( src->i_type < X264_TYPE_AUTO || src->i_type > X264_TYPE_KEYFRAME )
    {
        x264_log( h, X264_LOG_WARNING, "forced frame type (%d) at %d is unknown\n", src->i_type, h->frames.i_input );
        dst->i_forced_type = X264_TYPE_AUTO;
    }
    else
        dst->i_forced_type = src->i_type;

    dst->i_type     = dst->i_forced_type;
    dst->i_qpplus1  = src->i_qpplus1;
    dst->i_pts      = dst->i_reordered_pts = src->i_pts;
    dst->param      = src->param;
    dst->i_pic_struct = src->i_pic_struct;
    dst->extra_sei  = src->extra_sei;
    dst->opaque     = src->opaque;
    dst->mb_info    = h->param.analyse.b_mb_info ? src->prop.mb_info : NULL;
    dst->mb_info_free = h->param.analyse.b_mb_info ? src->prop.mb_info_free : NULL;

    uint8_t *pix[3];
    int stride[3];
    if( i_csp == X264_CSP_YUYV || i_csp == X264_CSP_UYVY )
    {
        int p = i_csp == X264_CSP_UYVY;
        h->mc.plane_copy_deinterleave_yuyv( dst->plane[p], dst->i_stride[p], dst->plane[p^1], dst->i_stride[p^1],
                                            (pixel*)src->img.plane[0], src->img.i_stride[0], h->param.i_width, h->param.i_height );
    }
    else if( i_csp == X264_CSP_V210 )
    {
         stride[0] = src->img.i_stride[0];
         pix[0] = src->img.plane[0];

         h->mc.plane_copy_deinterleave_v210( dst->plane[0], dst->i_stride[0],
                                             dst->plane[1], dst->i_stride[1],
                                             (uint32_t *)pix[0], stride[0]/(int)sizeof(uint32_t), h->param.i_width, h->param.i_height );
    }
    else if( i_csp >= X264_CSP_BGR )
    {
         stride[0] = src->img.i_stride[0];
         pix[0] = src->img.plane[0];
         if( src->img.i_csp & X264_CSP_VFLIP )
         {
             pix[0] += (h->param.i_height-1) * stride[0];
             stride[0] = -stride[0];
         }
         int b = i_csp==X264_CSP_RGB;
         h->mc.plane_copy_deinterleave_rgb( dst->plane[1+b], dst->i_stride[1+b],
                                            dst->plane[0], dst->i_stride[0],
                                            dst->plane[2-b], dst->i_stride[2-b],
                                            (pixel*)pix[0], stride[0]/SIZEOF_PIXEL, i_csp==X264_CSP_BGRA ? 4 : 3, h->param.i_width, h->param.i_height );
    }
    else
    {
        int v_shift = CHROMA_V_SHIFT;
        get_plane_ptr( h, src, &pix[0], &stride[0], 0, 0, 0 );
        h->mc.plane_copy( dst->plane[0], dst->i_stride[0], (pixel*)pix[0],
                          stride[0]/SIZEOF_PIXEL, h->param.i_width, h->param.i_height );
        if( i_csp == X264_CSP_NV12 || i_csp == X264_CSP_NV16 )
        {
            get_plane_ptr( h, src, &pix[1], &stride[1], 1, 0, v_shift );
            h->mc.plane_copy( dst->plane[1], dst->i_stride[1], (pixel*)pix[1],
                              stride[1]/SIZEOF_PIXEL, h->param.i_width, h->param.i_height>>v_shift );
        }
        else if( i_csp == X264_CSP_NV21 )
        {
            get_plane_ptr( h, src, &pix[1], &stride[1], 1, 0, v_shift );
            h->mc.plane_copy_swap( dst->plane[1], dst->i_stride[1], (pixel*)pix[1],
                                   stride[1]/SIZEOF_PIXEL, h->param.i_width>>1, h->param.i_height>>v_shift );
        }
        else if( i_csp == X264_CSP_I420 || i_csp == X264_CSP_I422 || i_csp == X264_CSP_YV12 || i_csp == X264_CSP_YV16 )
        {
            int uv_swap = i_csp == X264_CSP_YV12 || i_csp == X264_CSP_YV16;
            get_plane_ptr( h, src, &pix[1], &stride[1], uv_swap ? 2 : 1, 1, v_shift );
            get_plane_ptr( h, src, &pix[2], &stride[2], uv_swap ? 1 : 2, 1, v_shift );
            h->mc.plane_copy_interleave( dst->plane[1], dst->i_stride[1],
                                         (pixel*)pix[1], stride[1]/SIZEOF_PIXEL,
                                         (pixel*)pix[2], stride[2]/SIZEOF_PIXEL,
                                         h->param.i_width>>1, h->param.i_height>>v_shift );
        }
        else if( i_csp == X264_CSP_I444 || i_csp == X264_CSP_YV24 )
        {
            get_plane_ptr( h, src, &pix[1], &stride[1], i_csp==X264_CSP_I444 ? 1 : 2, 0, 0 );
            get_plane_ptr( h, src, &pix[2], &stride[2], i_csp==X264_CSP_I444 ? 2 : 1, 0, 0 );
            h->mc.plane_copy( dst->plane[1], dst->i_stride[1], (pixel*)pix[1],
                              stride[1]/SIZEOF_PIXEL, h->param.i_width, h->param.i_height );
            h->mc.plane_copy( dst->plane[2], dst->i_stride[2], (pixel*)pix[2],
                              stride[2]/SIZEOF_PIXEL, h->param.i_width, h->param.i_height );
        }
    }
    return 0;
}

static ALWAYS_INLINE void pixel_memset( pixel *dst, pixel *src, int len, int size )
{
    uint8_t *dstp = (uint8_t*)dst;
    uint32_t v1 = *src;
    uint32_t v2 = size == 1 ? v1 + (v1 <<  8) : M16( src );
    uint32_t v4 = size <= 2 ? v2 + (v2 << 16) : M32( src );
    int i = 0;
    len *= size;

    /* Align the input pointer if it isn't already */
    if( (intptr_t)dstp & (WORD_SIZE - 1) )
    {
        if( size <= 2 && ((intptr_t)dstp & 3) )
        {
            if( size == 1 && ((intptr_t)dstp & 1) )
                dstp[i++] = v1;
            if( (intptr_t)dstp & 2 )
            {
                M16( dstp+i ) = v2;
                i += 2;
            }
        }
        if( WORD_SIZE == 8 && (intptr_t)dstp & 4 )
        {
            M32( dstp+i ) = v4;
            i += 4;
        }
    }

    /* Main copy loop */
    if( WORD_SIZE == 8 )
    {
        uint64_t v8 = v4 + ((uint64_t)v4<<32);
        for( ; i < len - 7; i+=8 )
            M64( dstp+i ) = v8;
    }
    for( ; i < len - 3; i+=4 )
        M32( dstp+i ) = v4;

    /* Finish up the last few bytes */
    if( size <= 2 )
    {
        if( i < len - 1 )
        {
            M16( dstp+i ) = v2;
            i += 2;
        }
        if( size == 1 && i != len )
            dstp[i] = v1;
    }
}

static ALWAYS_INLINE void plane_expand_border( pixel *pix, int i_stride, int i_width, int i_height, int i_padh, int i_padv, int b_pad_top, int b_pad_bottom, int b_chroma )
{
#define PPIXEL(x, y) ( pix + (x) + (y)*i_stride )
    for( int y = 0; y < i_height; y++ )
    {
        /* left band */
        pixel_memset( PPIXEL(-i_padh, y), PPIXEL(0, y), i_padh>>b_chroma, SIZEOF_PIXEL<<b_chroma );
        /* right band */
        pixel_memset( PPIXEL(i_width, y), PPIXEL(i_width-1-b_chroma, y), i_padh>>b_chroma, SIZEOF_PIXEL<<b_chroma );
    }
    /* upper band */
    if( b_pad_top )
        for( int y = 0; y < i_padv; y++ )
            memcpy( PPIXEL(-i_padh, -y-1), PPIXEL(-i_padh, 0), (i_width+2*i_padh) * SIZEOF_PIXEL );
    /* lower band */
    if( b_pad_bottom )
        for( int y = 0; y < i_padv; y++ )
            memcpy( PPIXEL(-i_padh, i_height+y), PPIXEL(-i_padh, i_height-1), (i_width+2*i_padh) * SIZEOF_PIXEL );
#undef PPIXEL
}

void x264_frame_expand_border( x264_t *h, x264_frame_t *frame, int mb_y )
{
    int pad_top = mb_y == 0;
    int pad_bot = mb_y == h->mb.i_mb_height - (1 << SLICE_MBAFF);
    int b_start = mb_y == h->i_threadslice_start;
    int b_end   = mb_y == h->i_threadslice_end - (1 << SLICE_MBAFF);
    if( mb_y & SLICE_MBAFF )
        return;
    for( int i = 0; i < frame->i_plane; i++ )
    {
        int h_shift = i && CHROMA_H_SHIFT;
        int v_shift = i && CHROMA_V_SHIFT;
        int stride = frame->i_stride[i];
        int width = 16*h->mb.i_mb_width;
        int height = (pad_bot ? 16*(h->mb.i_mb_height - mb_y) >> SLICE_MBAFF : 16) >> v_shift;
        int padh = PADH;
        int padv = PADV >> v_shift;
        // buffer: 2 chroma, 3 luma (rounded to 4) because deblocking goes beyond the top of the mb
        if( b_end && !b_start )
            height += 4 >> (v_shift + SLICE_MBAFF);
        pixel *pix;
        int starty = 16*mb_y - 4*!b_start;
        if( SLICE_MBAFF )
        {
            // border samples for each field are extended separately
            pix = frame->plane_fld[i] + (starty*stride >> v_shift);
            plane_expand_border( pix, stride*2, width, height, padh, padv, pad_top, pad_bot, h_shift );
            plane_expand_border( pix+stride, stride*2, width, height, padh, padv, pad_top, pad_bot, h_shift );

            height = (pad_bot ? 16*(h->mb.i_mb_height - mb_y) : 32) >> v_shift;
            if( b_end && !b_start )
                height += 4 >> v_shift;
            pix = frame->plane[i] + (starty*stride >> v_shift);
            plane_expand_border( pix, stride, width, height, padh, padv, pad_top, pad_bot, h_shift );
        }
        else
        {
            pix = frame->plane[i] + (starty*stride >> v_shift);
            plane_expand_border( pix, stride, width, height, padh, padv, pad_top, pad_bot, h_shift );
        }
    }
}

void x264_frame_expand_border_filtered( x264_t *h, x264_frame_t *frame, int mb_y, int b_end )
{
    /* during filtering, 8 extra pixels were filtered on each edge,
     * but up to 3 of the horizontal ones may be wrong.
       we want to expand border from the last filtered pixel */
    int b_start = !mb_y;
    int width = 16*h->mb.i_mb_width + 8;
    int height = b_end ? (16*(h->mb.i_mb_height - mb_y) >> SLICE_MBAFF) + 16 : 16;
    int padh = PADH - 4;
    int padv = PADV - 8;
    for( int p = 0; p < (CHROMA444 ? 3 : 1); p++ )
        for( int i = 1; i < 4; i++ )
        {
            int stride = frame->i_stride[p];
            // buffer: 8 luma, to match the hpel filter
            pixel *pix;
            if( SLICE_MBAFF )
            {
                pix = frame->filtered_fld[p][i] + (16*mb_y - 16) * stride - 4;
                plane_expand_border( pix, stride*2, width, height, padh, padv, b_start, b_end, 0 );
                plane_expand_border( pix+stride, stride*2, width, height, padh, padv, b_start, b_end, 0 );
            }

            pix = frame->filtered[p][i] + (16*mb_y - 8) * stride - 4;
            plane_expand_border( pix, stride, width, height << SLICE_MBAFF, padh, padv, b_start, b_end, 0 );
        }
}

void x264_frame_expand_border_lowres( x264_frame_t *frame )
{
    for( int i = 0; i < 4; i++ )
        plane_expand_border( frame->lowres[i], frame->i_stride_lowres, frame->i_width_lowres, frame->i_lines_lowres, PADH, PADV, 1, 1, 0 );
}

void x264_frame_expand_border_chroma( x264_t *h, x264_frame_t *frame, int plane )
{
    int v_shift = CHROMA_V_SHIFT;
    plane_expand_border( frame->plane[plane], frame->i_stride[plane], 16*h->mb.i_mb_width, 16*h->mb.i_mb_height>>v_shift,
                         PADH, PADV>>v_shift, 1, 1, CHROMA_H_SHIFT );
}

void x264_frame_expand_border_mod16( x264_t *h, x264_frame_t *frame )
{
    for( int i = 0; i < frame->i_plane; i++ )
    {
        int i_width = h->param.i_width;
        int h_shift = i && CHROMA_H_SHIFT;
        int v_shift = i && CHROMA_V_SHIFT;
        int i_height = h->param.i_height >> v_shift;
        int i_padx = (h->mb.i_mb_width * 16 - h->param.i_width);
        int i_pady = (h->mb.i_mb_height * 16 - h->param.i_height) >> v_shift;

        if( i_padx )
        {
            for( int y = 0; y < i_height; y++ )
                pixel_memset( &frame->plane[i][y*frame->i_stride[i] + i_width],
                              &frame->plane[i][y*frame->i_stride[i] + i_width - 1-h_shift],
                              i_padx>>h_shift, SIZEOF_PIXEL<<h_shift );
        }
        if( i_pady )
        {
            for( int y = i_height; y < i_height + i_pady; y++ )
                memcpy( &frame->plane[i][y*frame->i_stride[i]],
                        &frame->plane[i][(i_height-(~y&PARAM_INTERLACED)-1)*frame->i_stride[i]],
                        (i_width + i_padx) * SIZEOF_PIXEL );
        }
    }
}

void x264_expand_border_mbpair( x264_t *h, int mb_x, int mb_y )
{
    for( int i = 0; i < h->fenc->i_plane; i++ )
    {
        int v_shift = i && CHROMA_V_SHIFT;
        int stride = h->fenc->i_stride[i];
        int height = h->param.i_height >> v_shift;
        int pady = (h->mb.i_mb_height * 16 - h->param.i_height) >> v_shift;
        pixel *fenc = h->fenc->plane[i] + 16*mb_x;
        for( int y = height; y < height + pady; y++ )
            memcpy( fenc + y*stride, fenc + (height-1)*stride, 16*SIZEOF_PIXEL );
    }
}

/* threading */
void x264_frame_cond_broadcast( x264_frame_t *frame, int i_lines_completed )
{
    x264_pthread_mutex_lock( &frame->mutex );
    frame->i_lines_completed = i_lines_completed;
    x264_pthread_cond_broadcast( &frame->cv );
    x264_pthread_mutex_unlock( &frame->mutex );
}

int x264_frame_cond_wait( x264_frame_t *frame, int i_lines_completed )
{
    int completed;
    x264_pthread_mutex_lock( &frame->mutex );
    while( (completed = frame->i_lines_completed) < i_lines_completed && i_lines_completed >= 0 )
        x264_pthread_cond_wait( &frame->cv, &frame->mutex );
    x264_pthread_mutex_unlock( &frame->mutex );
    return completed;
}

void x264_threadslice_cond_broadcast( x264_t *h, int pass )
{
    x264_pthread_mutex_lock( &h->mutex );
    h->i_threadslice_pass = pass;
    if( pass > 0 )
        x264_pthread_cond_broadcast( &h->cv );
    x264_pthread_mutex_unlock( &h->mutex );
}

void x264_threadslice_cond_wait( x264_t *h, int pass )
{
    x264_pthread_mutex_lock( &h->mutex );
    while( h->i_threadslice_pass < pass )
        x264_pthread_cond_wait( &h->cv, &h->mutex );
    x264_pthread_mutex_unlock( &h->mutex );
}

int x264_frame_new_slice( x264_t *h, x264_frame_t *frame )
{
    if( h->param.i_slice_count_max )
    {
        int slice_count;
        if( h->param.b_sliced_threads )
            slice_count = x264_pthread_fetch_and_add( &frame->i_slice_count, 1, &frame->mutex );
        else
            slice_count = frame->i_slice_count++;
        if( slice_count >= h->param.i_slice_count_max )
            return -1;
    }
    return 0;
}

/* list operators */

void x264_frame_push( x264_frame_t **list, x264_frame_t *frame )
{
    int i = 0;
    while( list[i] ) i++;
    list[i] = frame;
}

x264_frame_t *x264_frame_pop( x264_frame_t **list )
{
    x264_frame_t *frame;
    int i = 0;
    assert( list[0] );
    while( list[i+1] ) i++;
    frame = list[i];
    list[i] = NULL;
    return frame;
}

void x264_frame_unshift( x264_frame_t **list, x264_frame_t *frame )
{
    int i = 0;
    while( list[i] ) i++;
    while( i-- )
        list[i+1] = list[i];
    list[0] = frame;
}

x264_frame_t *x264_frame_shift( x264_frame_t **list )
{
    x264_frame_t *frame = list[0];
    int i;
    for( i = 0; list[i]; i++ )
        list[i] = list[i+1];
    assert(frame);
    return frame;
}

void x264_frame_push_unused( x264_t *h, x264_frame_t *frame )
{
    assert( frame->i_reference_count > 0 );
    frame->i_reference_count--;
    if( frame->i_reference_count == 0 )
        x264_frame_push( h->frames.unused[frame->b_fdec], frame );
}

x264_frame_t *x264_frame_pop_unused( x264_t *h, int b_fdec )
{
    x264_frame_t *frame;
    if( h->frames.unused[b_fdec][0] )
        frame = x264_frame_pop( h->frames.unused[b_fdec] );
    else
        frame = frame_new( h, b_fdec );
    if( !frame )
        return NULL;
    frame->b_last_minigop_bframe = 0;
    frame->i_reference_count = 1;
    frame->b_intra_calculated = 0;
    frame->b_scenecut = 1;
    frame->b_keyframe = 0;
    frame->b_corrupt = 0;
    frame->i_slice_count = h->param.b_sliced_threads ? h->param.i_threads : 1;

    memset( frame->weight, 0, sizeof(frame->weight) );
    memset( frame->f_weighted_cost_delta, 0, sizeof(frame->f_weighted_cost_delta) );

    return frame;
}

void x264_frame_push_blank_unused( x264_t *h, x264_frame_t *frame )
{
    assert( frame->i_reference_count > 0 );
    frame->i_reference_count--;
    if( frame->i_reference_count == 0 )
        x264_frame_push( h->frames.blank_unused, frame );
}

x264_frame_t *x264_frame_pop_blank_unused( x264_t *h )
{
    x264_frame_t *frame;
    if( h->frames.blank_unused[0] )
        frame = x264_frame_pop( h->frames.blank_unused );
    else
        frame = x264_malloc( sizeof(x264_frame_t) );
    if( !frame )
        return NULL;
    frame->b_duplicate = 1;
    frame->i_reference_count = 1;
    return frame;
}

void x264_weight_scale_plane( x264_t *h, pixel *dst, intptr_t i_dst_stride, pixel *src, intptr_t i_src_stride,
                              int i_width, int i_height, x264_weight_t *w )
{
    /* Weight horizontal strips of height 16. This was found to be the optimal height
     * in terms of the cache loads. */
    while( i_height > 0 )
    {
        int x;
        for( x = 0; x < i_width-8; x += 16 )
            w->weightfn[16>>2]( dst+x, i_dst_stride, src+x, i_src_stride, w, X264_MIN( i_height, 16 ) );
        if( x < i_width )
            w->weightfn[ 8>>2]( dst+x, i_dst_stride, src+x, i_src_stride, w, X264_MIN( i_height, 16 ) );
        i_height -= 16;
        dst += 16 * i_dst_stride;
        src += 16 * i_src_stride;
    }
}

void x264_frame_delete_list( x264_frame_t **list )
{
    int i = 0;
    if( !list )
        return;
    while( list[i] )
        x264_frame_delete( list[i++] );
    x264_free( list );
}

int x264_sync_frame_list_init( x264_sync_frame_list_t *slist, int max_size )
{
    if( max_size < 0 )
        return -1;
    slist->i_max_size = max_size;
    slist->i_size = 0;
    CHECKED_MALLOCZERO( slist->list, (max_size+1) * sizeof(x264_frame_t*) );
    if( x264_pthread_mutex_init( &slist->mutex, NULL ) ||
        x264_pthread_cond_init( &slist->cv_fill, NULL ) ||
        x264_pthread_cond_init( &slist->cv_empty, NULL ) )
        return -1;
    return 0;
fail:
    return -1;
}

void x264_sync_frame_list_delete( x264_sync_frame_list_t *slist )
{
    x264_pthread_mutex_destroy( &slist->mutex );
    x264_pthread_cond_destroy( &slist->cv_fill );
    x264_pthread_cond_destroy( &slist->cv_empty );
    x264_frame_delete_list( slist->list );
}

void x264_sync_frame_list_push( x264_sync_frame_list_t *slist, x264_frame_t *frame )
{
    x264_pthread_mutex_lock( &slist->mutex );
    while( slist->i_size == slist->i_max_size )
        x264_pthread_cond_wait( &slist->cv_empty, &slist->mutex );
    slist->list[ slist->i_size++ ] = frame;
    x264_pthread_mutex_unlock( &slist->mutex );
    x264_pthread_cond_broadcast( &slist->cv_fill );
}

x264_frame_t *x264_sync_frame_list_pop( x264_sync_frame_list_t *slist )
{
    x264_frame_t *frame;
    x264_pthread_mutex_lock( &slist->mutex );
    while( !slist->i_size )
        x264_pthread_cond_wait( &slist->cv_fill, &slist->mutex );
    frame = slist->list[ --slist->i_size ];
    slist->list[ slist->i_size ] = NULL;
    x264_pthread_cond_broadcast( &slist->cv_empty );
    x264_pthread_mutex_unlock( &slist->mutex );
    return frame;
}
