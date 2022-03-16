/*****************************************************************************
 * slicetype-cl.c: OpenCL slicetype decision code (lowres lookahead)
 *****************************************************************************
 * Copyright (C) 2012-2022 x264 project
 *
 * Authors: Steve Borho <sborho@multicorewareinc.com>
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
#include "macroblock.h"
#include "me.h"
#include "slicetype-cl.h"

#if HAVE_OPENCL
#ifdef _WIN32
#include <windows.h>
#endif

#define x264_weights_analyse x264_template(weights_analyse)
void x264_weights_analyse( x264_t *h, x264_frame_t *fenc, x264_frame_t *ref, int b_lookahead );

/* We define CL_QUEUE_THREAD_HANDLE_AMD here because it is not defined
 * in the OpenCL headers shipped with NVIDIA drivers.  We need to be
 * able to compile on an NVIDIA machine and run optimally on an AMD GPU. */
#define CL_QUEUE_THREAD_HANDLE_AMD 0x403E

#define OCLCHECK( method, ... )\
do\
{\
    if( h->opencl.b_fatal_error )\
        return -1;\
    status = ocl->method( __VA_ARGS__ );\
    if( status != CL_SUCCESS ) {\
        h->param.b_opencl = 0;\
        h->opencl.b_fatal_error = 1;\
        x264_log( h, X264_LOG_ERROR, # method " error '%d'\n", status );\
        return -1;\
    }\
} while( 0 )

void x264_opencl_flush( x264_t *h )
{
    x264_opencl_function_t *ocl = h->opencl.ocl;

    ocl->clFinish( h->opencl.queue );

    /* Finish copies from the GPU by copying from the page-locked buffer to
     * their final destination */
    for( int i = 0; i < h->opencl.num_copies; i++ )
        memcpy( h->opencl.copies[i].dest, h->opencl.copies[i].src, h->opencl.copies[i].bytes );
    h->opencl.num_copies = 0;
    h->opencl.pl_occupancy = 0;
}

static void *opencl_alloc_locked( x264_t *h, int bytes )
{
    if( h->opencl.pl_occupancy + bytes >= PAGE_LOCKED_BUF_SIZE )
        x264_opencl_flush( h );
    assert( bytes < PAGE_LOCKED_BUF_SIZE );
    char *ptr = h->opencl.page_locked_ptr + h->opencl.pl_occupancy;
    h->opencl.pl_occupancy += bytes;
    return ptr;
}

int x264_opencl_lowres_init( x264_t *h, x264_frame_t *fenc, int lambda )
{
    if( fenc->b_intra_calculated )
        return 0;
    fenc->b_intra_calculated = 1;

    x264_opencl_function_t *ocl = h->opencl.ocl;
    int luma_length = fenc->i_stride[0] * fenc->i_lines[0];

#define CREATEBUF( out, flags, size )\
    out = ocl->clCreateBuffer( h->opencl.context, (flags), (size), NULL, &status );\
    if( status != CL_SUCCESS ) { h->param.b_opencl = 0; x264_log( h, X264_LOG_ERROR, "clCreateBuffer error '%d'\n", status ); return -1; }
#define CREATEIMAGE( out, flags, pf, width, height )\
    out = ocl->clCreateImage2D( h->opencl.context, (flags), &pf, width, height, 0, NULL, &status );\
    if( status != CL_SUCCESS ) { h->param.b_opencl = 0; x264_log( h, X264_LOG_ERROR, "clCreateImage2D error '%d'\n", status ); return -1; }

    int mb_count = h->mb.i_mb_count;
    cl_int status;

    if( !h->opencl.lowres_mv_costs )
    {
        /* Allocate shared memory buffers */
        int width = h->mb.i_mb_width * 8 * SIZEOF_PIXEL;
        int height = h->mb.i_mb_height * 8 * SIZEOF_PIXEL;

        cl_image_format pixel_format;
        pixel_format.image_channel_order = CL_R;
        pixel_format.image_channel_data_type = CL_UNSIGNED_INT32;
        CREATEIMAGE( h->opencl.weighted_luma_hpel, CL_MEM_READ_WRITE, pixel_format, width, height );

        for( int i = 0; i < NUM_IMAGE_SCALES; i++ )
        {
            pixel_format.image_channel_order = CL_RGBA;
            pixel_format.image_channel_data_type = CL_UNSIGNED_INT8;
            CREATEIMAGE( h->opencl.weighted_scaled_images[i], CL_MEM_READ_WRITE, pixel_format, width, height );
            width >>= 1;
            height >>= 1;
        }

        CREATEBUF( h->opencl.lowres_mv_costs,     CL_MEM_READ_WRITE, mb_count * sizeof(int16_t) );
        CREATEBUF( h->opencl.lowres_costs[0],     CL_MEM_READ_WRITE, mb_count * sizeof(int16_t) );
        CREATEBUF( h->opencl.lowres_costs[1],     CL_MEM_READ_WRITE, mb_count * sizeof(int16_t) );
        CREATEBUF( h->opencl.mv_buffers[0],       CL_MEM_READ_WRITE, mb_count * sizeof(int16_t) * 2 );
        CREATEBUF( h->opencl.mv_buffers[1],       CL_MEM_READ_WRITE, mb_count * sizeof(int16_t) * 2 );
        CREATEBUF( h->opencl.mvp_buffer,          CL_MEM_READ_WRITE, mb_count * sizeof(int16_t) * 2 );
        CREATEBUF( h->opencl.frame_stats[0],      CL_MEM_WRITE_ONLY, 4 * sizeof(int) );
        CREATEBUF( h->opencl.frame_stats[1],      CL_MEM_WRITE_ONLY, 4 * sizeof(int) );
        CREATEBUF( h->opencl.row_satds[0],        CL_MEM_WRITE_ONLY, h->mb.i_mb_height * sizeof(int) );
        CREATEBUF( h->opencl.row_satds[1],        CL_MEM_WRITE_ONLY, h->mb.i_mb_height * sizeof(int) );
        CREATEBUF( h->opencl.luma_16x16_image[0], CL_MEM_READ_ONLY,  luma_length );
        CREATEBUF( h->opencl.luma_16x16_image[1], CL_MEM_READ_ONLY,  luma_length );
    }

    if( !fenc->opencl.intra_cost )
    {
        /* Allocate per-frame buffers */
        int width = h->mb.i_mb_width * 8 * SIZEOF_PIXEL;
        int height = h->mb.i_mb_height * 8 * SIZEOF_PIXEL;

        cl_image_format pixel_format;
        pixel_format.image_channel_order = CL_R;
        pixel_format.image_channel_data_type = CL_UNSIGNED_INT32;
        CREATEIMAGE( fenc->opencl.luma_hpel, CL_MEM_READ_WRITE, pixel_format, width, height );

        for( int i = 0; i < NUM_IMAGE_SCALES; i++ )
        {
            pixel_format.image_channel_order = CL_RGBA;
            pixel_format.image_channel_data_type = CL_UNSIGNED_INT8;
            CREATEIMAGE( fenc->opencl.scaled_image2Ds[i], CL_MEM_READ_WRITE, pixel_format, width, height );
            width >>= 1;
            height >>= 1;
        }
        CREATEBUF( fenc->opencl.inv_qscale_factor, CL_MEM_READ_ONLY,  mb_count * sizeof(int16_t) );
        CREATEBUF( fenc->opencl.intra_cost,        CL_MEM_WRITE_ONLY, mb_count * sizeof(int16_t) );
        CREATEBUF( fenc->opencl.lowres_mvs0,       CL_MEM_READ_WRITE, mb_count * 2 * sizeof(int16_t) * (h->param.i_bframe + 1) );
        CREATEBUF( fenc->opencl.lowres_mvs1,       CL_MEM_READ_WRITE, mb_count * 2 * sizeof(int16_t) * (h->param.i_bframe + 1) );
        CREATEBUF( fenc->opencl.lowres_mv_costs0,  CL_MEM_READ_WRITE, mb_count * sizeof(int16_t) * (h->param.i_bframe + 1) );
        CREATEBUF( fenc->opencl.lowres_mv_costs1,  CL_MEM_READ_WRITE, mb_count * sizeof(int16_t) * (h->param.i_bframe + 1) );
    }
#undef CREATEBUF
#undef CREATEIMAGE

    /* Copy image to the GPU, downscale to unpadded 8x8, then continue for all scales */

    char *locked = opencl_alloc_locked( h, luma_length );
    memcpy( locked, fenc->plane[0], luma_length );
    OCLCHECK( clEnqueueWriteBuffer, h->opencl.queue,  h->opencl.luma_16x16_image[h->opencl.last_buf], CL_FALSE, 0, luma_length, locked, 0, NULL, NULL );

    size_t gdim[2];
    if( h->param.rc.i_aq_mode && fenc->i_inv_qscale_factor )
    {
        int size = h->mb.i_mb_count * sizeof(int16_t);
        locked = opencl_alloc_locked( h, size );
        memcpy( locked, fenc->i_inv_qscale_factor, size );
        OCLCHECK( clEnqueueWriteBuffer, h->opencl.queue, fenc->opencl.inv_qscale_factor, CL_FALSE, 0, size, locked, 0, NULL, NULL );
    }
    else
    {
        /* Fill fenc->opencl.inv_qscale_factor with NOP (256) */
        cl_uint arg = 0;
        int16_t value = 256;
        OCLCHECK( clSetKernelArg, h->opencl.memset_kernel, arg++, sizeof(cl_mem), &fenc->opencl.inv_qscale_factor );
        OCLCHECK( clSetKernelArg, h->opencl.memset_kernel, arg++, sizeof(int16_t), &value );
        gdim[0] = h->mb.i_mb_count;
        OCLCHECK( clEnqueueNDRangeKernel, h->opencl.queue, h->opencl.memset_kernel, 1, NULL, gdim, NULL, 0, NULL, NULL );
    }

    int stride = fenc->i_stride[0];
    cl_uint arg = 0;
    OCLCHECK( clSetKernelArg, h->opencl.downscale_hpel_kernel, arg++, sizeof(cl_mem), &h->opencl.luma_16x16_image[h->opencl.last_buf] );
    OCLCHECK( clSetKernelArg, h->opencl.downscale_hpel_kernel, arg++, sizeof(cl_mem), &fenc->opencl.scaled_image2Ds[0] );
    OCLCHECK( clSetKernelArg, h->opencl.downscale_hpel_kernel, arg++, sizeof(cl_mem), &fenc->opencl.luma_hpel );
    OCLCHECK( clSetKernelArg, h->opencl.downscale_hpel_kernel, arg++, sizeof(int), &stride );
    gdim[0] = 8 * h->mb.i_mb_width;
    gdim[1] = 8 * h->mb.i_mb_height;
    OCLCHECK( clEnqueueNDRangeKernel, h->opencl.queue, h->opencl.downscale_hpel_kernel, 2, NULL, gdim, NULL, 0, NULL, NULL );

    for( int i = 0; i < NUM_IMAGE_SCALES - 1; i++ )
    {
        /* Workaround for AMD Southern Island:
         *
         * Alternate kernel instances.  No perf impact to this, so we do it for
         * all GPUs.  It prevents the same kernel from being enqueued
         * back-to-back, avoiding a dependency calculation bug in the driver.
         */
        cl_kernel kern = i & 1 ? h->opencl.downscale_kernel1 : h->opencl.downscale_kernel2;

        arg = 0;
        OCLCHECK( clSetKernelArg, kern, arg++, sizeof(cl_mem), &fenc->opencl.scaled_image2Ds[i] );
        OCLCHECK( clSetKernelArg, kern, arg++, sizeof(cl_mem), &fenc->opencl.scaled_image2Ds[i+1] );
        gdim[0] >>= 1;
        gdim[1] >>= 1;
        if( gdim[0] < 16 || gdim[1] < 16 )
            break;
        OCLCHECK( clEnqueueNDRangeKernel, h->opencl.queue, kern, 2, NULL, gdim, NULL, 0, NULL, NULL );
    }

    size_t ldim[2];
    gdim[0] = ((h->mb.i_mb_width + 31)>>5)<<5;
    gdim[1] = 8*h->mb.i_mb_height;
    ldim[0] = 32;
    ldim[1] = 8;
    arg = 0;

    /* For presets slow, slower, and placebo, check all 10 intra modes that the
     * C lookahead supports.  For faster presets, only check the most frequent 8
     * modes
     */
    int slow = h->param.analyse.i_subpel_refine > 7;
    OCLCHECK( clSetKernelArg, h->opencl.intra_kernel, arg++, sizeof(cl_mem), &fenc->opencl.scaled_image2Ds[0] );
    OCLCHECK( clSetKernelArg, h->opencl.intra_kernel, arg++, sizeof(cl_mem), &fenc->opencl.intra_cost );
    OCLCHECK( clSetKernelArg, h->opencl.intra_kernel, arg++, sizeof(cl_mem), &h->opencl.frame_stats[h->opencl.last_buf] );
    OCLCHECK( clSetKernelArg, h->opencl.intra_kernel, arg++, sizeof(int), &lambda );
    OCLCHECK( clSetKernelArg, h->opencl.intra_kernel, arg++, sizeof(int), &h->mb.i_mb_width );
    OCLCHECK( clSetKernelArg, h->opencl.intra_kernel, arg++, sizeof(int), &slow );
    OCLCHECK( clEnqueueNDRangeKernel, h->opencl.queue, h->opencl.intra_kernel, 2, NULL, gdim, ldim, 0, NULL, NULL );

    gdim[0] = 256;
    gdim[1] = h->mb.i_mb_height;
    ldim[0] = 256;
    ldim[1] = 1;
    arg = 0;
    OCLCHECK( clSetKernelArg, h->opencl.rowsum_intra_kernel, arg++, sizeof(cl_mem), &fenc->opencl.intra_cost );
    OCLCHECK( clSetKernelArg, h->opencl.rowsum_intra_kernel, arg++, sizeof(cl_mem), &fenc->opencl.inv_qscale_factor );
    OCLCHECK( clSetKernelArg, h->opencl.rowsum_intra_kernel, arg++, sizeof(cl_mem), &h->opencl.row_satds[h->opencl.last_buf] );
    OCLCHECK( clSetKernelArg, h->opencl.rowsum_intra_kernel, arg++, sizeof(cl_mem), &h->opencl.frame_stats[h->opencl.last_buf] );
    OCLCHECK( clSetKernelArg, h->opencl.rowsum_intra_kernel, arg++, sizeof(int), &h->mb.i_mb_width );
    OCLCHECK( clEnqueueNDRangeKernel, h->opencl.queue, h->opencl.rowsum_intra_kernel, 2, NULL, gdim, ldim, 0, NULL, NULL );

    if( h->opencl.num_copies >= MAX_FINISH_COPIES - 4 )
        x264_opencl_flush( h );

    int size = h->mb.i_mb_count * sizeof(int16_t);
    locked = opencl_alloc_locked( h, size );
    OCLCHECK( clEnqueueReadBuffer, h->opencl.queue, fenc->opencl.intra_cost, CL_FALSE, 0, size, locked, 0, NULL, NULL );
    h->opencl.copies[h->opencl.num_copies].dest = fenc->lowres_costs[0][0];
    h->opencl.copies[h->opencl.num_copies].src = locked;
    h->opencl.copies[h->opencl.num_copies].bytes = size;
    h->opencl.num_copies++;

    size = h->mb.i_mb_height * sizeof(int);
    locked = opencl_alloc_locked( h, size );
    OCLCHECK( clEnqueueReadBuffer, h->opencl.queue, h->opencl.row_satds[h->opencl.last_buf], CL_FALSE, 0, size, locked, 0, NULL, NULL );
    h->opencl.copies[h->opencl.num_copies].dest = fenc->i_row_satds[0][0];
    h->opencl.copies[h->opencl.num_copies].src = locked;
    h->opencl.copies[h->opencl.num_copies].bytes = size;
    h->opencl.num_copies++;

    size = sizeof(int) * 4;
    locked = opencl_alloc_locked( h, size );
    OCLCHECK( clEnqueueReadBuffer, h->opencl.queue, h->opencl.frame_stats[h->opencl.last_buf], CL_FALSE, 0, size, locked, 0, NULL, NULL );
    h->opencl.copies[h->opencl.num_copies].dest = &fenc->i_cost_est[0][0];
    h->opencl.copies[h->opencl.num_copies].src = locked;
    h->opencl.copies[h->opencl.num_copies].bytes = sizeof(int);
    h->opencl.num_copies++;
    h->opencl.copies[h->opencl.num_copies].dest = &fenc->i_cost_est_aq[0][0];
    h->opencl.copies[h->opencl.num_copies].src = locked + sizeof(int);
    h->opencl.copies[h->opencl.num_copies].bytes = sizeof(int);
    h->opencl.num_copies++;

    h->opencl.last_buf = !h->opencl.last_buf;
    return 0;
}

/* This function was tested empirically on a number of AMD and NV GPUs.  Making a
 * function which returns perfect launch dimensions is impossible; some
 * applications will have self-tuning code to try many possible variables and
 * measure the runtime.  Here we simply make an educated guess based on what we
 * know GPUs typically prefer.  */
static void optimal_launch_dims( x264_t *h, size_t *gdims, size_t *ldims, const cl_kernel kernel, const cl_device_id device )
{
    x264_opencl_function_t *ocl = h->opencl.ocl;
    size_t max_work_group = 256;    /* reasonable defaults for OpenCL 1.0 devices, below APIs may fail */
    size_t preferred_multiple = 64;
    cl_uint num_cus = 6;

    ocl->clGetKernelWorkGroupInfo( kernel, device, CL_KERNEL_WORK_GROUP_SIZE, sizeof(size_t), &max_work_group, NULL );
    ocl->clGetKernelWorkGroupInfo( kernel, device, CL_KERNEL_PREFERRED_WORK_GROUP_SIZE_MULTIPLE, sizeof(size_t), &preferred_multiple, NULL );
    ocl->clGetDeviceInfo( device, CL_DEVICE_MAX_COMPUTE_UNITS, sizeof(cl_uint), &num_cus, NULL );

    ldims[0] = preferred_multiple;
    ldims[1] = 8;

    /* make ldims[1] an even divisor of gdims[1] */
    while( gdims[1] & (ldims[1] - 1) )
    {
        ldims[0] <<= 1;
        ldims[1] >>= 1;
    }
    /* make total ldims fit under the max work-group dimensions for the device */
    while( ldims[0] * ldims[1] > max_work_group )
    {
        if( (ldims[0] <= preferred_multiple) && (ldims[1] > 1) )
            ldims[1] >>= 1;
        else
            ldims[0] >>= 1;
    }

    if( ldims[0] > gdims[0] )
    {
        /* remove preferred multiples until we're close to gdims[0] */
        while( gdims[0] + preferred_multiple < ldims[0] )
            ldims[0] -= preferred_multiple;
        gdims[0] = ldims[0];
    }
    else
    {
        /* make gdims an even multiple of ldims */
        gdims[0] = (gdims[0]+ldims[0]-1)/ldims[0];
        gdims[0] *= ldims[0];
    }

    /* make ldims smaller to spread work across compute units */
    while( (gdims[0]/ldims[0]) * (gdims[1]/ldims[1]) * 2 <= num_cus )
    {
        if( ldims[0] > preferred_multiple )
            ldims[0] >>= 1;
        else if( ldims[1] > 1 )
            ldims[1] >>= 1;
        else
            break;
    }
    /* for smaller GPUs, try not to abuse their texture cache */
    if( num_cus == 6 && ldims[0] == 64 && ldims[1] == 4 )
        ldims[0] = 32;
}

int x264_opencl_motionsearch( x264_t *h, x264_frame_t **frames, int b, int ref, int b_islist1, int lambda, const x264_weight_t *w )
{
    x264_opencl_function_t *ocl = h->opencl.ocl;
    x264_frame_t *fenc = frames[b];
    x264_frame_t *fref = frames[ref];

    cl_mem ref_scaled_images[NUM_IMAGE_SCALES];
    cl_mem ref_luma_hpel;
    cl_int status;

    if( w && w->weightfn )
    {
        size_t gdims[2];

        gdims[0] = 8 * h->mb.i_mb_width;
        gdims[1] = 8 * h->mb.i_mb_height;

        /* WeightP: Perform a filter on fref->opencl.scaled_image2Ds[] and fref->opencl.luma_hpel */
        for( int i = 0; i < NUM_IMAGE_SCALES; i++ )
        {
            cl_uint arg = 0;
            OCLCHECK( clSetKernelArg, h->opencl.weightp_scaled_images_kernel, arg++, sizeof(cl_mem), &fref->opencl.scaled_image2Ds[i] );
            OCLCHECK( clSetKernelArg, h->opencl.weightp_scaled_images_kernel, arg++, sizeof(cl_mem), &h->opencl.weighted_scaled_images[i] );
            OCLCHECK( clSetKernelArg, h->opencl.weightp_scaled_images_kernel, arg++, sizeof(int32_t), &w->i_offset );
            OCLCHECK( clSetKernelArg, h->opencl.weightp_scaled_images_kernel, arg++, sizeof(int32_t), &w->i_scale );
            OCLCHECK( clSetKernelArg, h->opencl.weightp_scaled_images_kernel, arg++, sizeof(int32_t), &w->i_denom );
            OCLCHECK( clEnqueueNDRangeKernel, h->opencl.queue, h->opencl.weightp_scaled_images_kernel, 2, NULL, gdims, NULL, 0, NULL, NULL );

            gdims[0] >>= 1;
            gdims[1] >>= 1;
            if( gdims[0] < 16 || gdims[1] < 16 )
                break;
        }

        cl_uint arg = 0;
        gdims[0] = 8 * h->mb.i_mb_width;
        gdims[1] = 8 * h->mb.i_mb_height;

        OCLCHECK( clSetKernelArg, h->opencl.weightp_hpel_kernel, arg++, sizeof(cl_mem), &fref->opencl.luma_hpel );
        OCLCHECK( clSetKernelArg, h->opencl.weightp_hpel_kernel, arg++, sizeof(cl_mem), &h->opencl.weighted_luma_hpel );
        OCLCHECK( clSetKernelArg, h->opencl.weightp_hpel_kernel, arg++, sizeof(int32_t), &w->i_offset );
        OCLCHECK( clSetKernelArg, h->opencl.weightp_hpel_kernel, arg++, sizeof(int32_t), &w->i_scale );
        OCLCHECK( clSetKernelArg, h->opencl.weightp_hpel_kernel, arg++, sizeof(int32_t), &w->i_denom );
        OCLCHECK( clEnqueueNDRangeKernel, h->opencl.queue, h->opencl.weightp_hpel_kernel, 2, NULL, gdims, NULL, 0, NULL, NULL );

        /* Use weighted reference planes for motion search */
        for( int i = 0; i < NUM_IMAGE_SCALES; i++ )
            ref_scaled_images[i] = h->opencl.weighted_scaled_images[i];
        ref_luma_hpel = h->opencl.weighted_luma_hpel;
    }
    else
    {
        /* Use unweighted reference planes for motion search */
        for( int i = 0; i < NUM_IMAGE_SCALES; i++ )
            ref_scaled_images[i] = fref->opencl.scaled_image2Ds[i];
        ref_luma_hpel = fref->opencl.luma_hpel;
    }

    const int num_iterations[NUM_IMAGE_SCALES] = { 1, 1, 2, 3 };
    int b_first_iteration = 1;
    int b_reverse_references = 1;
    int A = 1;


    int mb_per_group = 0;
    int cost_local_size = 0;
    int mvc_local_size = 0;
    int mb_width;

    size_t gdims[2];
    size_t ldims[2];

    /* scale 0 is 8x8 */
    for( int scale = NUM_IMAGE_SCALES-1; scale >= 0; scale-- )
    {
        mb_width = h->mb.i_mb_width >> scale;
        gdims[0] = mb_width;
        gdims[1] = h->mb.i_mb_height >> scale;
        if( gdims[0] < 2 || gdims[1] < 2 )
            continue;
        gdims[0] <<= 2;
        optimal_launch_dims( h, gdims, ldims, h->opencl.hme_kernel, h->opencl.device );

        mb_per_group = (ldims[0] >> 2) * ldims[1];
        cost_local_size = 4 * mb_per_group * sizeof(int16_t);
        mvc_local_size = 4 * mb_per_group * sizeof(int16_t) * 2;
        int scaled_me_range = h->param.analyse.i_me_range >> scale;
        int b_shift_index = 1;

        cl_uint arg = 0;
        OCLCHECK( clSetKernelArg, h->opencl.hme_kernel, arg++, sizeof(cl_mem), &fenc->opencl.scaled_image2Ds[scale] );
        OCLCHECK( clSetKernelArg, h->opencl.hme_kernel, arg++, sizeof(cl_mem), &ref_scaled_images[scale] );
        OCLCHECK( clSetKernelArg, h->opencl.hme_kernel, arg++, sizeof(cl_mem), &h->opencl.mv_buffers[A] );
        OCLCHECK( clSetKernelArg, h->opencl.hme_kernel, arg++, sizeof(cl_mem), &h->opencl.mv_buffers[!A] );
        OCLCHECK( clSetKernelArg, h->opencl.hme_kernel, arg++, sizeof(cl_mem), &h->opencl.lowres_mv_costs );
        OCLCHECK( clSetKernelArg, h->opencl.hme_kernel, arg++, sizeof(cl_mem), (void*)&h->opencl.mvp_buffer );
        OCLCHECK( clSetKernelArg, h->opencl.hme_kernel, arg++, cost_local_size, NULL );
        OCLCHECK( clSetKernelArg, h->opencl.hme_kernel, arg++, mvc_local_size, NULL );
        OCLCHECK( clSetKernelArg, h->opencl.hme_kernel, arg++, sizeof(int), &mb_width );
        OCLCHECK( clSetKernelArg, h->opencl.hme_kernel, arg++, sizeof(int), &lambda );
        OCLCHECK( clSetKernelArg, h->opencl.hme_kernel, arg++, sizeof(int), &scaled_me_range );
        OCLCHECK( clSetKernelArg, h->opencl.hme_kernel, arg++, sizeof(int), &scale );
        OCLCHECK( clSetKernelArg, h->opencl.hme_kernel, arg++, sizeof(int), &b_shift_index );
        OCLCHECK( clSetKernelArg, h->opencl.hme_kernel, arg++, sizeof(int), &b_first_iteration );
        OCLCHECK( clSetKernelArg, h->opencl.hme_kernel, arg++, sizeof(int), &b_reverse_references );

        for( int iter = 0; iter < num_iterations[scale]; iter++ )
        {
            OCLCHECK( clEnqueueNDRangeKernel, h->opencl.queue, h->opencl.hme_kernel, 2, NULL, gdims, ldims, 0, NULL, NULL );

            b_shift_index = 0;
            b_first_iteration = 0;

            /* alternate top-left vs bot-right MB references at lower scales, so
             * motion field smooths more quickly.  */
            if( scale > 2 )
                b_reverse_references ^= 1;
            else
                b_reverse_references = 0;
            A = !A;
            OCLCHECK( clSetKernelArg, h->opencl.hme_kernel, 2, sizeof(cl_mem), &h->opencl.mv_buffers[A] );
            OCLCHECK( clSetKernelArg, h->opencl.hme_kernel, 3, sizeof(cl_mem), &h->opencl.mv_buffers[!A] );
            OCLCHECK( clSetKernelArg, h->opencl.hme_kernel, arg - 3, sizeof(int), &b_shift_index );
            OCLCHECK( clSetKernelArg, h->opencl.hme_kernel, arg - 2, sizeof(int), &b_first_iteration );
            OCLCHECK( clSetKernelArg, h->opencl.hme_kernel, arg - 1, sizeof(int), &b_reverse_references );
        }
    }

    int satd_local_size = mb_per_group * sizeof(uint32_t) * 16;
    cl_uint arg = 0;
    OCLCHECK( clSetKernelArg, h->opencl.subpel_refine_kernel, arg++, sizeof(cl_mem), &fenc->opencl.scaled_image2Ds[0] );
    OCLCHECK( clSetKernelArg, h->opencl.subpel_refine_kernel, arg++, sizeof(cl_mem), &ref_luma_hpel );
    OCLCHECK( clSetKernelArg, h->opencl.subpel_refine_kernel, arg++, sizeof(cl_mem), &h->opencl.mv_buffers[A] );
    OCLCHECK( clSetKernelArg, h->opencl.subpel_refine_kernel, arg++, sizeof(cl_mem), &h->opencl.lowres_mv_costs );
    OCLCHECK( clSetKernelArg, h->opencl.subpel_refine_kernel, arg++, cost_local_size, NULL );
    OCLCHECK( clSetKernelArg, h->opencl.subpel_refine_kernel, arg++, satd_local_size, NULL );
    OCLCHECK( clSetKernelArg, h->opencl.subpel_refine_kernel, arg++, mvc_local_size, NULL );

    if( b_islist1 )
    {
        OCLCHECK( clSetKernelArg, h->opencl.subpel_refine_kernel, arg++, sizeof(cl_mem), &fenc->opencl.lowres_mvs1 );
        OCLCHECK( clSetKernelArg, h->opencl.subpel_refine_kernel, arg++, sizeof(cl_mem), &fenc->opencl.lowres_mv_costs1 );
    }
    else
    {
        OCLCHECK( clSetKernelArg, h->opencl.subpel_refine_kernel, arg++, sizeof(cl_mem), &fenc->opencl.lowres_mvs0 );
        OCLCHECK( clSetKernelArg, h->opencl.subpel_refine_kernel, arg++, sizeof(cl_mem), &fenc->opencl.lowres_mv_costs0 );
    }

    OCLCHECK( clSetKernelArg, h->opencl.subpel_refine_kernel, arg++, sizeof(int), &mb_width );
    OCLCHECK( clSetKernelArg, h->opencl.subpel_refine_kernel, arg++, sizeof(int), &lambda );
    OCLCHECK( clSetKernelArg, h->opencl.subpel_refine_kernel, arg++, sizeof(int), &b );
    OCLCHECK( clSetKernelArg, h->opencl.subpel_refine_kernel, arg++, sizeof(int), &ref );
    OCLCHECK( clSetKernelArg, h->opencl.subpel_refine_kernel, arg++, sizeof(int), &b_islist1 );

    if( h->opencl.b_device_AMD_SI )
    {
        /* workaround for AMD Southern Island driver scheduling bug (fixed in
         * July 2012), perform meaningless small copy to add a data dependency */
        OCLCHECK( clEnqueueCopyBuffer, h->opencl.queue, h->opencl.mv_buffers[A], h->opencl.mv_buffers[!A], 0, 0, 20, 0, NULL, NULL );
    }

    OCLCHECK( clEnqueueNDRangeKernel, h->opencl.queue, h->opencl.subpel_refine_kernel, 2, NULL, gdims, ldims, 0, NULL, NULL );

    int mvlen = 2 * sizeof(int16_t) * h->mb.i_mb_count;

    if( h->opencl.num_copies >= MAX_FINISH_COPIES - 1 )
        x264_opencl_flush( h );

    char *locked = opencl_alloc_locked( h, mvlen );
    h->opencl.copies[h->opencl.num_copies].src = locked;
    h->opencl.copies[h->opencl.num_copies].bytes = mvlen;

    if( b_islist1 )
    {
        int mvs_offset = mvlen * (ref - b - 1);
        OCLCHECK( clEnqueueReadBuffer, h->opencl.queue, fenc->opencl.lowres_mvs1, CL_FALSE, mvs_offset, mvlen, locked, 0, NULL, NULL );
        h->opencl.copies[h->opencl.num_copies].dest = fenc->lowres_mvs[1][ref - b - 1];
    }
    else
    {
        int mvs_offset = mvlen * (b - ref - 1);
        OCLCHECK( clEnqueueReadBuffer, h->opencl.queue, fenc->opencl.lowres_mvs0, CL_FALSE, mvs_offset, mvlen, locked, 0, NULL, NULL );
        h->opencl.copies[h->opencl.num_copies].dest = fenc->lowres_mvs[0][b - ref - 1];
    }

    h->opencl.num_copies++;

    return 0;
}

int x264_opencl_finalize_cost( x264_t *h, int lambda, x264_frame_t **frames, int p0, int p1, int b, int dist_scale_factor )
{
    x264_opencl_function_t *ocl = h->opencl.ocl;
    cl_int status;
    x264_frame_t *fenc = frames[b];
    x264_frame_t *fref0 = frames[p0];
    x264_frame_t *fref1 = frames[p1];

    int bipred_weight = h->param.analyse.b_weighted_bipred ? 64 - (dist_scale_factor >> 2) : 32;

    /* Tasks for this kernel:
     * 1. Select least cost mode (intra, ref0, ref1)
     *    list_used 0, 1, 2, or 3.  if B frame, do not allow intra
     * 2. if B frame, try bidir predictions.
     * 3. lowres_costs[i_mb_xy] = X264_MIN( bcost, LOWRES_COST_MASK ) + (list_used << LOWRES_COST_SHIFT); */
    size_t gdims[2] = { h->mb.i_mb_width, h->mb.i_mb_height };
    size_t ldim_bidir[2];
    size_t *ldims = NULL;
    int cost_local_size = 4;
    int satd_local_size = 4;
    if( b < p1 )
    {
        /* For B frames, use 4 threads per MB for BIDIR checks */
        ldims = ldim_bidir;
        gdims[0] <<= 2;
        optimal_launch_dims( h, gdims, ldims, h->opencl.mode_select_kernel, h->opencl.device );
        int mb_per_group = (ldims[0] >> 2) * ldims[1];
        cost_local_size = 4 * mb_per_group * sizeof(int16_t);
        satd_local_size = 16 * mb_per_group * sizeof(uint32_t);
    }

    cl_uint arg = 0;
    OCLCHECK( clSetKernelArg, h->opencl.mode_select_kernel, arg++, sizeof(cl_mem), &fenc->opencl.scaled_image2Ds[0] );
    OCLCHECK( clSetKernelArg, h->opencl.mode_select_kernel, arg++, sizeof(cl_mem), &fref0->opencl.luma_hpel );
    OCLCHECK( clSetKernelArg, h->opencl.mode_select_kernel, arg++, sizeof(cl_mem), &fref1->opencl.luma_hpel );
    OCLCHECK( clSetKernelArg, h->opencl.mode_select_kernel, arg++, sizeof(cl_mem), &fenc->opencl.lowres_mvs0 );
    OCLCHECK( clSetKernelArg, h->opencl.mode_select_kernel, arg++, sizeof(cl_mem), &fenc->opencl.lowres_mvs1 );
    OCLCHECK( clSetKernelArg, h->opencl.mode_select_kernel, arg++, sizeof(cl_mem), &fref1->opencl.lowres_mvs0 );
    OCLCHECK( clSetKernelArg, h->opencl.mode_select_kernel, arg++, sizeof(cl_mem), &fenc->opencl.lowres_mv_costs0 );
    OCLCHECK( clSetKernelArg, h->opencl.mode_select_kernel, arg++, sizeof(cl_mem), &fenc->opencl.lowres_mv_costs1 );
    OCLCHECK( clSetKernelArg, h->opencl.mode_select_kernel, arg++, sizeof(cl_mem), &fenc->opencl.intra_cost );
    OCLCHECK( clSetKernelArg, h->opencl.mode_select_kernel, arg++, sizeof(cl_mem), &h->opencl.lowres_costs[h->opencl.last_buf] );
    OCLCHECK( clSetKernelArg, h->opencl.mode_select_kernel, arg++, sizeof(cl_mem), &h->opencl.frame_stats[h->opencl.last_buf] );
    OCLCHECK( clSetKernelArg, h->opencl.mode_select_kernel, arg++, cost_local_size, NULL );
    OCLCHECK( clSetKernelArg, h->opencl.mode_select_kernel, arg++, satd_local_size, NULL );
    OCLCHECK( clSetKernelArg, h->opencl.mode_select_kernel, arg++, sizeof(int), &h->mb.i_mb_width );
    OCLCHECK( clSetKernelArg, h->opencl.mode_select_kernel, arg++, sizeof(int), &bipred_weight );
    OCLCHECK( clSetKernelArg, h->opencl.mode_select_kernel, arg++, sizeof(int), &dist_scale_factor );
    OCLCHECK( clSetKernelArg, h->opencl.mode_select_kernel, arg++, sizeof(int), &b );
    OCLCHECK( clSetKernelArg, h->opencl.mode_select_kernel, arg++, sizeof(int), &p0 );
    OCLCHECK( clSetKernelArg, h->opencl.mode_select_kernel, arg++, sizeof(int), &p1 );
    OCLCHECK( clSetKernelArg, h->opencl.mode_select_kernel, arg++, sizeof(int), &lambda );
    OCLCHECK( clEnqueueNDRangeKernel, h->opencl.queue, h->opencl.mode_select_kernel, 2, NULL, gdims, ldims, 0, NULL, NULL );

    /* Sum costs across rows, atomicAdd down frame */
    size_t gdim[2] = { 256, h->mb.i_mb_height };
    size_t ldim[2] = { 256, 1 };

    arg = 0;
    OCLCHECK( clSetKernelArg, h->opencl.rowsum_inter_kernel, arg++, sizeof(cl_mem), &h->opencl.lowres_costs[h->opencl.last_buf] );
    OCLCHECK( clSetKernelArg, h->opencl.rowsum_inter_kernel, arg++, sizeof(cl_mem), &fenc->opencl.inv_qscale_factor );
    OCLCHECK( clSetKernelArg, h->opencl.rowsum_inter_kernel, arg++, sizeof(cl_mem), &h->opencl.row_satds[h->opencl.last_buf] );
    OCLCHECK( clSetKernelArg, h->opencl.rowsum_inter_kernel, arg++, sizeof(cl_mem), &h->opencl.frame_stats[h->opencl.last_buf] );
    OCLCHECK( clSetKernelArg, h->opencl.rowsum_inter_kernel, arg++, sizeof(int), &h->mb.i_mb_width );
    OCLCHECK( clSetKernelArg, h->opencl.rowsum_inter_kernel, arg++, sizeof(int), &h->param.i_bframe_bias );
    OCLCHECK( clSetKernelArg, h->opencl.rowsum_inter_kernel, arg++, sizeof(int), &b );
    OCLCHECK( clSetKernelArg, h->opencl.rowsum_inter_kernel, arg++, sizeof(int), &p0 );
    OCLCHECK( clSetKernelArg, h->opencl.rowsum_inter_kernel, arg++, sizeof(int), &p1 );
    OCLCHECK( clEnqueueNDRangeKernel, h->opencl.queue, h->opencl.rowsum_inter_kernel, 2, NULL, gdim, ldim, 0, NULL, NULL );

    if( h->opencl.num_copies >= MAX_FINISH_COPIES - 4 )
        x264_opencl_flush( h );

    int size =  h->mb.i_mb_count * sizeof(int16_t);
    char *locked = opencl_alloc_locked( h, size );
    h->opencl.copies[h->opencl.num_copies].src = locked;
    h->opencl.copies[h->opencl.num_copies].dest = fenc->lowres_costs[b - p0][p1 - b];
    h->opencl.copies[h->opencl.num_copies].bytes = size;
    OCLCHECK( clEnqueueReadBuffer, h->opencl.queue, h->opencl.lowres_costs[h->opencl.last_buf], CL_FALSE, 0, size, locked, 0, NULL, NULL );
    h->opencl.num_copies++;

    size =  h->mb.i_mb_height * sizeof(int);
    locked = opencl_alloc_locked( h, size );
    h->opencl.copies[h->opencl.num_copies].src = locked;
    h->opencl.copies[h->opencl.num_copies].dest = fenc->i_row_satds[b - p0][p1 - b];
    h->opencl.copies[h->opencl.num_copies].bytes = size;
    OCLCHECK( clEnqueueReadBuffer, h->opencl.queue, h->opencl.row_satds[h->opencl.last_buf], CL_FALSE, 0, size, locked, 0, NULL, NULL );
    h->opencl.num_copies++;

    size =  4 * sizeof(int);
    locked = opencl_alloc_locked( h, size );
    OCLCHECK( clEnqueueReadBuffer, h->opencl.queue, h->opencl.frame_stats[h->opencl.last_buf], CL_FALSE, 0, size, locked, 0, NULL, NULL );
    h->opencl.last_buf = !h->opencl.last_buf;

    h->opencl.copies[h->opencl.num_copies].src = locked;
    h->opencl.copies[h->opencl.num_copies].dest = &fenc->i_cost_est[b - p0][p1 - b];
    h->opencl.copies[h->opencl.num_copies].bytes = sizeof(int);
    h->opencl.num_copies++;
    h->opencl.copies[h->opencl.num_copies].src = locked + sizeof(int);
    h->opencl.copies[h->opencl.num_copies].dest = &fenc->i_cost_est_aq[b - p0][p1 - b];
    h->opencl.copies[h->opencl.num_copies].bytes = sizeof(int);
    h->opencl.num_copies++;

    if( b == p1 ) // P frames only
    {
        h->opencl.copies[h->opencl.num_copies].src = locked + 2 * sizeof(int);
        h->opencl.copies[h->opencl.num_copies].dest = &fenc->i_intra_mbs[b - p0];
        h->opencl.copies[h->opencl.num_copies].bytes = sizeof(int);
        h->opencl.num_copies++;
    }
    return 0;
}

void x264_opencl_slicetype_prep( x264_t *h, x264_frame_t **frames, int num_frames, int lambda )
{
    if( h->param.b_opencl )
    {
#ifdef _WIN32
        /* Temporarily boost priority of this lookahead thread and the OpenCL
         * driver's thread until the end of this function.  On AMD GPUs this
         * greatly reduces the latency of enqueuing kernels and getting results
         * on Windows. */
        HANDLE id = GetCurrentThread();
        h->opencl.lookahead_thread_pri = GetThreadPriority( id );
        SetThreadPriority( id, THREAD_PRIORITY_ABOVE_NORMAL );
        x264_opencl_function_t *ocl = h->opencl.ocl;
        cl_int status = ocl->clGetCommandQueueInfo( h->opencl.queue, CL_QUEUE_THREAD_HANDLE_AMD, sizeof(HANDLE), &id, NULL );
        if( status == CL_SUCCESS )
        {
            h->opencl.opencl_thread_pri = GetThreadPriority( id );
            SetThreadPriority( id, THREAD_PRIORITY_ABOVE_NORMAL );
        }
#endif

        /* precalculate intra and I frames */
        for( int i = 0; i <= num_frames; i++ )
            x264_opencl_lowres_init( h, frames[i], lambda );
        x264_opencl_flush( h );

        if( h->param.i_bframe_adaptive == X264_B_ADAPT_TRELLIS && h->param.i_bframe )
        {
            /* For trellis B-Adapt, precompute exhaustive motion searches */
            for( int b = 0; b <= num_frames; b++ )
            {
                for( int j = 1; j < h->param.i_bframe; j++ )
                {
                    int p0 = b - j;
                    if( p0 >= 0 && frames[b]->lowres_mvs[0][b-p0-1][0][0] == 0x7FFF )
                    {
                        const x264_weight_t *w = x264_weight_none;

                        if( h->param.analyse.i_weighted_pred )
                        {
                            x264_emms();
                            x264_weights_analyse( h, frames[b], frames[p0], 1 );
                            w = frames[b]->weight[0];
                        }
                        frames[b]->lowres_mvs[0][b-p0-1][0][0] = 0;
                        x264_opencl_motionsearch( h, frames, b, p0, 0, lambda, w );
                    }
                    int p1 = b + j;
                    if( p1 <= num_frames && frames[b]->lowres_mvs[1][p1-b-1][0][0] == 0x7FFF )
                    {
                        frames[b]->lowres_mvs[1][p1-b-1][0][0] = 0;
                        x264_opencl_motionsearch( h, frames, b, p1, 1, lambda, NULL );
                    }
                }
            }

            x264_opencl_flush( h );
        }
    }
}


void x264_opencl_slicetype_end( x264_t *h )
{
#ifdef _WIN32
    if( h->param.b_opencl )
    {
        HANDLE id = GetCurrentThread();
        SetThreadPriority( id, h->opencl.lookahead_thread_pri );
        x264_opencl_function_t *ocl = h->opencl.ocl;
        cl_int status = ocl->clGetCommandQueueInfo( h->opencl.queue, CL_QUEUE_THREAD_HANDLE_AMD, sizeof(HANDLE), &id, NULL );
        if( status == CL_SUCCESS )
            SetThreadPriority( id, h->opencl.opencl_thread_pri );
    }
#endif
}

int x264_opencl_precalculate_frame_cost( x264_t *h, x264_frame_t **frames, int lambda, int p0, int p1, int b )
{
    if( (frames[b]->i_cost_est[b-p0][p1-b] >= 0) || (b == p0 && b == p1) )
        return 0;
    else
    {
        int do_search[2];
        int dist_scale_factor = 128;
        const x264_weight_t *w = x264_weight_none;

        // avoid duplicating work
        frames[b]->i_cost_est[b-p0][p1-b] = 0;

        do_search[0] = b != p0 && frames[b]->lowres_mvs[0][b-p0-1][0][0] == 0x7FFF;
        do_search[1] = b != p1 && frames[b]->lowres_mvs[1][p1-b-1][0][0] == 0x7FFF;
        if( do_search[0] )
        {
            if( h->param.analyse.i_weighted_pred && b == p1 )
            {
                x264_emms();
                x264_weights_analyse( h, frames[b], frames[p0], 1 );
                w = frames[b]->weight[0];
            }
            frames[b]->lowres_mvs[0][b-p0-1][0][0] = 0;
        }
        if( do_search[1] )
            frames[b]->lowres_mvs[1][p1-b-1][0][0] = 0;
        if( b == p1 )
            frames[b]->i_intra_mbs[b-p0] = 0;
        if( p1 != p0 )
            dist_scale_factor = ( ((b-p0) << 8) + ((p1-p0) >> 1) ) / (p1-p0);

        frames[b]->i_cost_est[b-p0][p1-b] = 0;
        frames[b]->i_cost_est_aq[b-p0][p1-b] = 0;

        x264_opencl_lowres_init( h, frames[b], lambda );

        if( do_search[0] )
        {
            x264_opencl_lowres_init( h, frames[p0], lambda );
            x264_opencl_motionsearch( h, frames, b, p0, 0, lambda, w );
        }
        if( do_search[1] )
        {
            x264_opencl_lowres_init( h, frames[p1], lambda );
            x264_opencl_motionsearch( h, frames, b, p1, 1, lambda, NULL );
        }
        x264_opencl_finalize_cost( h, lambda, frames, p0, p1, b, dist_scale_factor );
        return 1;
    }
}

#endif
