/*****************************************************************************
 * opencl.c: OpenCL initialization and kernel compilation
 *****************************************************************************
 * Copyright (C) 2012-2022 x264 project
 *
 * Authors: Steve Borho <sborho@multicorewareinc.com>
 *          Anton Mitrofanov <BugMaster@narod.ru>
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

#ifdef _WIN32
#include <windows.h>
#define ocl_open LoadLibraryW( L"OpenCL" )
#define ocl_close FreeLibrary
#define ocl_address GetProcAddress
#else
#include <dlfcn.h> //dlopen, dlsym, dlclose
#if SYS_MACOSX
#define ocl_open dlopen( "/System/Library/Frameworks/OpenCL.framework/OpenCL", RTLD_NOW )
#else
#define ocl_open dlopen( "libOpenCL.so", RTLD_NOW )
#endif
#define ocl_close dlclose
#define ocl_address dlsym
#endif

#define LOAD_OCL_FUNC(name, continue_on_fail)\
{\
    ocl->name = (void*)ocl_address( ocl->library, #name );\
    if( !continue_on_fail && !ocl->name )\
        goto fail;\
}

/* load the library and functions we require from it */
x264_opencl_function_t *x264_opencl_load_library( void )
{
    x264_opencl_function_t *ocl;
#undef fail
#define fail fail0
    CHECKED_MALLOCZERO( ocl, sizeof(x264_opencl_function_t) );
#undef fail
#define fail fail1
    ocl->library = ocl_open;
    if( !ocl->library )
        goto fail;
#undef fail
#define fail fail2
    LOAD_OCL_FUNC( clBuildProgram, 0 );
    LOAD_OCL_FUNC( clCreateBuffer, 0 );
    LOAD_OCL_FUNC( clCreateCommandQueue, 0 );
    LOAD_OCL_FUNC( clCreateContext, 0 );
    LOAD_OCL_FUNC( clCreateImage2D, 0 );
    LOAD_OCL_FUNC( clCreateKernel, 0 );
    LOAD_OCL_FUNC( clCreateProgramWithBinary, 0 );
    LOAD_OCL_FUNC( clCreateProgramWithSource, 0 );
    LOAD_OCL_FUNC( clEnqueueCopyBuffer, 0 );
    LOAD_OCL_FUNC( clEnqueueMapBuffer, 0 );
    LOAD_OCL_FUNC( clEnqueueNDRangeKernel, 0 );
    LOAD_OCL_FUNC( clEnqueueReadBuffer, 0 );
    LOAD_OCL_FUNC( clEnqueueWriteBuffer, 0 );
    LOAD_OCL_FUNC( clFinish, 0 );
    LOAD_OCL_FUNC( clGetCommandQueueInfo, 0 );
    LOAD_OCL_FUNC( clGetDeviceIDs, 0 );
    LOAD_OCL_FUNC( clGetDeviceInfo, 0 );
    LOAD_OCL_FUNC( clGetKernelWorkGroupInfo, 0 );
    LOAD_OCL_FUNC( clGetPlatformIDs, 0 );
    LOAD_OCL_FUNC( clGetProgramBuildInfo, 0 );
    LOAD_OCL_FUNC( clGetProgramInfo, 0 );
    LOAD_OCL_FUNC( clGetSupportedImageFormats, 0 );
    LOAD_OCL_FUNC( clReleaseCommandQueue, 0 );
    LOAD_OCL_FUNC( clReleaseContext, 0 );
    LOAD_OCL_FUNC( clReleaseKernel, 0 );
    LOAD_OCL_FUNC( clReleaseMemObject, 0 );
    LOAD_OCL_FUNC( clReleaseProgram, 0 );
    LOAD_OCL_FUNC( clSetKernelArg, 0 );
    return ocl;
#undef fail
fail2:
    ocl_close( ocl->library );
fail1:
    x264_free( ocl );
fail0:
    return NULL;
}

void x264_opencl_close_library( x264_opencl_function_t *ocl )
{
    if( !ocl )
        return;
    ocl_close( ocl->library );
    x264_free( ocl );
}

/* define from recent cl_ext.h, copied here in case headers are old */
#define CL_DEVICE_SIMD_INSTRUCTION_WIDTH_AMD        0x4042

/* Requires full include path in case of out-of-tree builds */
#include "common/oclobj.h"

static int detect_switchable_graphics( void );

/* Try to load the cached compiled program binary, verify the device context is
 * still valid before reuse */
static cl_program opencl_cache_load( x264_t *h, const char *dev_name, const char *dev_vendor, const char *driver_version )
{
    /* try to load cached program binary */
    FILE *fp = x264_fopen( h->param.psz_clbin_file, "rb" );
    if( !fp )
        return NULL;

    x264_opencl_function_t *ocl = h->opencl.ocl;
    cl_program program = NULL;
    uint8_t *binary = NULL;

    fseek( fp, 0, SEEK_END );
    int64_t file_size = ftell( fp );
    fseek( fp, 0, SEEK_SET );
    if( file_size < 0 || (uint64_t)file_size > SIZE_MAX )
        goto fail;
    size_t size = file_size;
    CHECKED_MALLOC( binary, size );

    if( fread( binary, 1, size, fp ) != size )
        goto fail;
    const uint8_t *ptr = (const uint8_t*)binary;

#define CHECK_STRING( STR )\
    do {\
        size_t len = strlen( STR );\
        if( size <= len || strncmp( (char*)ptr, STR, len ) )\
            goto fail;\
        else {\
            size -= (len+1); ptr += (len+1);\
        }\
    } while( 0 )

    CHECK_STRING( dev_name );
    CHECK_STRING( dev_vendor );
    CHECK_STRING( driver_version );
    CHECK_STRING( x264_opencl_source_hash );
#undef CHECK_STRING

    cl_int status;
    program = ocl->clCreateProgramWithBinary( h->opencl.context, 1, &h->opencl.device, &size, &ptr, NULL, &status );
    if( status != CL_SUCCESS )
        program = NULL;

fail:
    fclose( fp );
    x264_free( binary );
    return program;
}

/* Save the compiled program binary to a file for later reuse.  Device context
 * is also saved in the cache file so we do not reuse stale binaries */
static void opencl_cache_save( x264_t *h, cl_program program, const char *dev_name, const char *dev_vendor, const char *driver_version )
{
    FILE *fp = x264_fopen( h->param.psz_clbin_file, "wb" );
    if( !fp )
    {
        x264_log( h, X264_LOG_INFO, "OpenCL: unable to open clbin file for write\n" );
        return;
    }

    x264_opencl_function_t *ocl = h->opencl.ocl;
    uint8_t *binary = NULL;

    size_t size = 0;
    cl_int status = ocl->clGetProgramInfo( program, CL_PROGRAM_BINARY_SIZES, sizeof(size_t), &size, NULL );
    if( status != CL_SUCCESS || !size )
    {
        x264_log( h, X264_LOG_INFO, "OpenCL: Unable to query program binary size, no cache file generated\n" );
        goto fail;
    }

    CHECKED_MALLOC( binary, size );
    status = ocl->clGetProgramInfo( program, CL_PROGRAM_BINARIES, sizeof(uint8_t *), &binary, NULL );
    if( status != CL_SUCCESS )
    {
        x264_log( h, X264_LOG_INFO, "OpenCL: Unable to query program binary, no cache file generated\n" );
        goto fail;
    }

    fputs( dev_name, fp );
    fputc( '\n', fp );
    fputs( dev_vendor, fp );
    fputc( '\n', fp );
    fputs( driver_version, fp );
    fputc( '\n', fp );
    fputs( x264_opencl_source_hash, fp );
    fputc( '\n', fp );
    fwrite( binary, 1, size, fp );

fail:
    fclose( fp );
    x264_free( binary );
    return;
}

/* The OpenCL source under common/opencl will be merged into common/oclobj.h by
 * the Makefile. It defines a x264_opencl_source byte array which we will pass
 * to clCreateProgramWithSource().  We also attempt to use a cache file for the
 * compiled binary, stored in the current working folder. */
static cl_program opencl_compile( x264_t *h )
{
    x264_opencl_function_t *ocl = h->opencl.ocl;
    cl_program program = NULL;
    char *build_log = NULL;

    char dev_name[64];
    char dev_vendor[64];
    char driver_version[64];
    cl_int status;
    status  = ocl->clGetDeviceInfo( h->opencl.device, CL_DEVICE_NAME,    sizeof(dev_name), dev_name, NULL );
    status |= ocl->clGetDeviceInfo( h->opencl.device, CL_DEVICE_VENDOR,  sizeof(dev_vendor), dev_vendor, NULL );
    status |= ocl->clGetDeviceInfo( h->opencl.device, CL_DRIVER_VERSION, sizeof(driver_version), driver_version, NULL );
    if( status != CL_SUCCESS )
        return NULL;

    // Most AMD GPUs have vector registers
    int vectorize = !strcmp( dev_vendor, "Advanced Micro Devices, Inc." );
    h->opencl.b_device_AMD_SI = 0;

    if( vectorize )
    {
        /* Disable OpenCL on Intel/AMD switchable graphics devices */
        if( detect_switchable_graphics() )
        {
            x264_log( h, X264_LOG_INFO, "OpenCL acceleration disabled, switchable graphics detected\n" );
            return NULL;
        }

        /* Detect AMD SouthernIsland or newer device (single-width registers) */
        cl_uint simdwidth = 4;
        status = ocl->clGetDeviceInfo( h->opencl.device, CL_DEVICE_SIMD_INSTRUCTION_WIDTH_AMD, sizeof(cl_uint), &simdwidth, NULL );
        if( status == CL_SUCCESS && simdwidth == 1 )
        {
            vectorize = 0;
            h->opencl.b_device_AMD_SI = 1;
        }
    }

    x264_log( h, X264_LOG_INFO, "OpenCL acceleration enabled with %s %s %s\n", dev_vendor, dev_name, h->opencl.b_device_AMD_SI ? "(SI)" : "" );

    program = opencl_cache_load( h, dev_name, dev_vendor, driver_version );
    if( !program )
    {
        /* clCreateProgramWithSource() requires a pointer variable, you cannot just use &x264_opencl_source */
        x264_log( h, X264_LOG_INFO, "Compiling OpenCL kernels...\n" );
        const char *strptr = (const char*)x264_opencl_source;
        size_t size = sizeof(x264_opencl_source);
        program = ocl->clCreateProgramWithSource( h->opencl.context, 1, &strptr, &size, &status );
        if( status != CL_SUCCESS || !program )
        {
            x264_log( h, X264_LOG_WARNING, "OpenCL: unable to create program\n" );
            return NULL;
        }
    }

    /* Build the program binary for the OpenCL device */
    const char *buildopts = vectorize ? "-DVECTORIZE=1" : "";
    status = ocl->clBuildProgram( program, 1, &h->opencl.device, buildopts, NULL, NULL );
    if( status == CL_SUCCESS )
    {
        opencl_cache_save( h, program, dev_name, dev_vendor, driver_version );
        return program;
    }

    /* Compile failure, should not happen with production code. */

    size_t build_log_len = 0;
    status = ocl->clGetProgramBuildInfo( program, h->opencl.device, CL_PROGRAM_BUILD_LOG, 0, NULL, &build_log_len );
    if( status != CL_SUCCESS || !build_log_len )
    {
        x264_log( h, X264_LOG_WARNING, "OpenCL: Compilation failed, unable to query build log\n" );
        goto fail;
    }

    build_log = x264_malloc( build_log_len );
    if( !build_log )
    {
        x264_log( h, X264_LOG_WARNING, "OpenCL: Compilation failed, unable to alloc build log\n" );
        goto fail;
    }

    status = ocl->clGetProgramBuildInfo( program, h->opencl.device, CL_PROGRAM_BUILD_LOG, build_log_len, build_log, NULL );
    if( status != CL_SUCCESS )
    {
        x264_log( h, X264_LOG_WARNING, "OpenCL: Compilation failed, unable to get build log\n" );
        goto fail;
    }

    FILE *log_file = x264_fopen( "x264_kernel_build_log.txt", "w" );
    if( !log_file )
    {
        x264_log( h, X264_LOG_WARNING, "OpenCL: Compilation failed, unable to create file x264_kernel_build_log.txt\n" );
        goto fail;
    }
    fwrite( build_log, 1, build_log_len, log_file );
    fclose( log_file );
    x264_log( h, X264_LOG_WARNING, "OpenCL: kernel build errors written to x264_kernel_build_log.txt\n" );

fail:
    x264_free( build_log );
    if( program )
        ocl->clReleaseProgram( program );
    return NULL;
}

static int opencl_lookahead_alloc( x264_t *h )
{
    if( !h->param.rc.i_lookahead )
        return -1;

    static const char *kernelnames[] = {
        "mb_intra_cost_satd_8x8",
        "sum_intra_cost",
        "downscale_hpel",
        "downscale1",
        "downscale2",
        "memset_int16",
        "weightp_scaled_images",
        "weightp_hpel",
        "hierarchical_motion",
        "subpel_refine",
        "mode_selection",
        "sum_inter_cost"
    };

    cl_kernel *kernels[] = {
        &h->opencl.intra_kernel,
        &h->opencl.rowsum_intra_kernel,
        &h->opencl.downscale_hpel_kernel,
        &h->opencl.downscale_kernel1,
        &h->opencl.downscale_kernel2,
        &h->opencl.memset_kernel,
        &h->opencl.weightp_scaled_images_kernel,
        &h->opencl.weightp_hpel_kernel,
        &h->opencl.hme_kernel,
        &h->opencl.subpel_refine_kernel,
        &h->opencl.mode_select_kernel,
        &h->opencl.rowsum_inter_kernel
    };

    x264_opencl_function_t *ocl = h->opencl.ocl;
    cl_int status;

    h->opencl.lookahead_program = opencl_compile( h );
    if( !h->opencl.lookahead_program )
        goto fail;

    for( int i = 0; i < ARRAY_ELEMS(kernelnames); i++ )
    {
        *kernels[i] = ocl->clCreateKernel( h->opencl.lookahead_program, kernelnames[i], &status );
        if( status != CL_SUCCESS )
        {
            x264_log( h, X264_LOG_WARNING, "OpenCL: Unable to compile kernel '%s' (%d)\n", kernelnames[i], status );
            goto fail;
        }
    }

    h->opencl.page_locked_buffer = ocl->clCreateBuffer( h->opencl.context, CL_MEM_WRITE_ONLY|CL_MEM_ALLOC_HOST_PTR, PAGE_LOCKED_BUF_SIZE, NULL, &status );
    if( status != CL_SUCCESS )
    {
        x264_log( h, X264_LOG_WARNING, "OpenCL: Unable to allocate page-locked buffer, error '%d'\n", status );
        goto fail;
    }
    h->opencl.page_locked_ptr = ocl->clEnqueueMapBuffer( h->opencl.queue, h->opencl.page_locked_buffer, CL_TRUE, CL_MAP_READ | CL_MAP_WRITE,
                                                         0, PAGE_LOCKED_BUF_SIZE, 0, NULL, NULL, &status );
    if( status != CL_SUCCESS )
    {
        x264_log( h, X264_LOG_WARNING, "OpenCL: Unable to map page-locked buffer, error '%d'\n", status );
        goto fail;
    }

    return 0;
fail:
    x264_opencl_lookahead_delete( h );
    return -1;
}

static void CL_CALLBACK opencl_error_notify( const char *errinfo, const void *private_info, size_t cb, void *user_data )
{
    /* Any error notification can be assumed to be fatal to the OpenCL context.
     * We need to stop using it immediately to prevent further damage. */
    x264_t *h = (x264_t*)user_data;
    h->param.b_opencl = 0;
    h->opencl.b_fatal_error = 1;
    x264_log( h, X264_LOG_ERROR, "OpenCL: %s\n", errinfo );
    x264_log( h, X264_LOG_ERROR, "OpenCL: fatal error, aborting encode\n" );
}

int x264_opencl_lookahead_init( x264_t *h )
{
    x264_opencl_function_t *ocl = h->opencl.ocl;
    cl_platform_id *platforms = NULL;
    cl_device_id *devices = NULL;
    cl_image_format *imageType = NULL;
    cl_context context = NULL;
    int ret = -1;

    cl_uint numPlatforms = 0;
    cl_int status = ocl->clGetPlatformIDs( 0, NULL, &numPlatforms );
    if( status != CL_SUCCESS || !numPlatforms )
    {
        x264_log( h, X264_LOG_WARNING, "OpenCL: Unable to query installed platforms\n" );
        goto fail;
    }
    platforms = (cl_platform_id*)x264_malloc( sizeof(cl_platform_id) * numPlatforms );
    if( !platforms )
    {
        x264_log( h, X264_LOG_WARNING, "OpenCL: malloc of installed platforms buffer failed\n" );
        goto fail;
    }
    status = ocl->clGetPlatformIDs( numPlatforms, platforms, NULL );
    if( status != CL_SUCCESS )
    {
        x264_log( h, X264_LOG_WARNING, "OpenCL: Unable to query installed platforms\n" );
        goto fail;
    }

    /* Select the first OpenCL platform with a GPU device that supports our
     * required image (texture) formats */
    for( cl_uint i = 0; i < numPlatforms; i++ )
    {
        cl_uint gpu_count = 0;
        status = ocl->clGetDeviceIDs( platforms[i], CL_DEVICE_TYPE_GPU, 0, NULL, &gpu_count );
        if( status != CL_SUCCESS || !gpu_count )
            continue;

        x264_free( devices );
        devices = x264_malloc( sizeof(cl_device_id) * gpu_count );
        if( !devices )
            continue;

        status = ocl->clGetDeviceIDs( platforms[i], CL_DEVICE_TYPE_GPU, gpu_count, devices, NULL );
        if( status != CL_SUCCESS )
            continue;

        /* Find a GPU device that supports our image formats */
        for( cl_uint gpu = 0; gpu < gpu_count; gpu++ )
        {
            h->opencl.device = devices[gpu];

            /* if the user has specified an exact device ID, skip all other
             * GPUs.  If this device matches, allow it to continue through the
             * checks for supported images, etc.  */
            if( h->param.opencl_device_id && devices[gpu] != (cl_device_id)h->param.opencl_device_id )
                continue;

            cl_bool image_support = 0;
            status = ocl->clGetDeviceInfo( h->opencl.device, CL_DEVICE_IMAGE_SUPPORT, sizeof(cl_bool), &image_support, NULL );
            if( status != CL_SUCCESS || !image_support )
                continue;

            if( context )
                ocl->clReleaseContext( context );
            context = ocl->clCreateContext( NULL, 1, &h->opencl.device, (void*)opencl_error_notify, (void*)h, &status );
            if( status != CL_SUCCESS || !context )
                continue;

            cl_uint imagecount = 0;
            status = ocl->clGetSupportedImageFormats( context, CL_MEM_READ_WRITE, CL_MEM_OBJECT_IMAGE2D, 0, NULL, &imagecount );
            if( status != CL_SUCCESS || !imagecount )
                continue;

            x264_free( imageType );
            imageType = x264_malloc( sizeof(cl_image_format) * imagecount );
            if( !imageType )
                continue;

            status = ocl->clGetSupportedImageFormats( context, CL_MEM_READ_WRITE, CL_MEM_OBJECT_IMAGE2D, imagecount, imageType, NULL );
            if( status != CL_SUCCESS )
                continue;

            int b_has_r = 0;
            int b_has_rgba = 0;
            for( cl_uint j = 0; j < imagecount; j++ )
            {
                if( imageType[j].image_channel_order == CL_R &&
                    imageType[j].image_channel_data_type == CL_UNSIGNED_INT32 )
                    b_has_r = 1;
                else if( imageType[j].image_channel_order == CL_RGBA &&
                         imageType[j].image_channel_data_type == CL_UNSIGNED_INT8 )
                    b_has_rgba = 1;
            }
            if( !b_has_r || !b_has_rgba )
            {
                char dev_name[64];
                status = ocl->clGetDeviceInfo( h->opencl.device, CL_DEVICE_NAME, sizeof(dev_name), dev_name, NULL );
                if( status == CL_SUCCESS )
                {
                    /* emit warning if we are discarding the user's explicit choice */
                    int level = h->param.opencl_device_id ? X264_LOG_WARNING : X264_LOG_DEBUG;
                    x264_log( h, level, "OpenCL: %s does not support required image formats\n", dev_name );
                }
                continue;
            }

            /* user selection of GPU device, skip N first matches */
            if( h->param.i_opencl_device )
            {
                h->param.i_opencl_device--;
                continue;
            }

            h->opencl.queue = ocl->clCreateCommandQueue( context, h->opencl.device, 0, &status );
            if( status != CL_SUCCESS || !h->opencl.queue )
                continue;

            h->opencl.context = context;
            context = NULL;

            ret = 0;
            break;
        }

        if( !ret )
            break;
    }

    if( !h->param.psz_clbin_file )
        h->param.psz_clbin_file = "x264_lookahead.clbin";

    if( ret )
        x264_log( h, X264_LOG_WARNING, "OpenCL: Unable to find a compatible device\n" );
    else
        ret = opencl_lookahead_alloc( h );

fail:
    if( context )
        ocl->clReleaseContext( context );
    x264_free( imageType );
    x264_free( devices );
    x264_free( platforms );
    return ret;
}

static void opencl_lookahead_free( x264_t *h )
{
    x264_opencl_function_t *ocl = h->opencl.ocl;

#define RELEASE( a, f ) do { if( a ) { ocl->f( a ); a = NULL; } } while( 0 )
    RELEASE( h->opencl.downscale_hpel_kernel, clReleaseKernel );
    RELEASE( h->opencl.downscale_kernel1, clReleaseKernel );
    RELEASE( h->opencl.downscale_kernel2, clReleaseKernel );
    RELEASE( h->opencl.weightp_hpel_kernel, clReleaseKernel );
    RELEASE( h->opencl.weightp_scaled_images_kernel, clReleaseKernel );
    RELEASE( h->opencl.memset_kernel, clReleaseKernel );
    RELEASE( h->opencl.intra_kernel, clReleaseKernel );
    RELEASE( h->opencl.rowsum_intra_kernel, clReleaseKernel );
    RELEASE( h->opencl.hme_kernel, clReleaseKernel );
    RELEASE( h->opencl.subpel_refine_kernel, clReleaseKernel );
    RELEASE( h->opencl.mode_select_kernel, clReleaseKernel );
    RELEASE( h->opencl.rowsum_inter_kernel, clReleaseKernel );

    RELEASE( h->opencl.lookahead_program, clReleaseProgram );

    RELEASE( h->opencl.page_locked_buffer, clReleaseMemObject );
    RELEASE( h->opencl.luma_16x16_image[0], clReleaseMemObject );
    RELEASE( h->opencl.luma_16x16_image[1], clReleaseMemObject );
    for( int i = 0; i < NUM_IMAGE_SCALES; i++ )
        RELEASE( h->opencl.weighted_scaled_images[i], clReleaseMemObject );
    RELEASE( h->opencl.weighted_luma_hpel, clReleaseMemObject );
    RELEASE( h->opencl.row_satds[0], clReleaseMemObject );
    RELEASE( h->opencl.row_satds[1], clReleaseMemObject );
    RELEASE( h->opencl.mv_buffers[0], clReleaseMemObject );
    RELEASE( h->opencl.mv_buffers[1], clReleaseMemObject );
    RELEASE( h->opencl.lowres_mv_costs, clReleaseMemObject );
    RELEASE( h->opencl.mvp_buffer, clReleaseMemObject );
    RELEASE( h->opencl.lowres_costs[0], clReleaseMemObject );
    RELEASE( h->opencl.lowres_costs[1], clReleaseMemObject );
    RELEASE( h->opencl.frame_stats[0], clReleaseMemObject );
    RELEASE( h->opencl.frame_stats[1], clReleaseMemObject );
#undef RELEASE
}

void x264_opencl_lookahead_delete( x264_t *h )
{
    x264_opencl_function_t *ocl = h->opencl.ocl;

    if( !ocl )
        return;

    if( h->opencl.queue )
        ocl->clFinish( h->opencl.queue );

    opencl_lookahead_free( h );

    if( h->opencl.queue )
    {
        ocl->clReleaseCommandQueue( h->opencl.queue );
        h->opencl.queue = NULL;
    }
    if( h->opencl.context )
    {
        ocl->clReleaseContext( h->opencl.context );
        h->opencl.context = NULL;
    }
}

void x264_opencl_frame_delete( x264_frame_t *frame )
{
    x264_opencl_function_t *ocl = frame->opencl.ocl;

    if( !ocl )
        return;

#define RELEASEBUF(mem) do { if( mem ) { ocl->clReleaseMemObject( mem ); mem = NULL; } } while( 0 )
    for( int j = 0; j < NUM_IMAGE_SCALES; j++ )
        RELEASEBUF( frame->opencl.scaled_image2Ds[j] );
    RELEASEBUF( frame->opencl.luma_hpel );
    RELEASEBUF( frame->opencl.inv_qscale_factor );
    RELEASEBUF( frame->opencl.intra_cost );
    RELEASEBUF( frame->opencl.lowres_mvs0 );
    RELEASEBUF( frame->opencl.lowres_mvs1 );
    RELEASEBUF( frame->opencl.lowres_mv_costs0 );
    RELEASEBUF( frame->opencl.lowres_mv_costs1 );
#undef RELEASEBUF
}

/* OpenCL misbehaves on hybrid laptops with Intel iGPU and AMD dGPU, so
 * we consult AMD's ADL interface to detect this situation and disable
 * OpenCL on these machines (Linux and Windows) */
#ifdef _WIN32
#define ADL_API_CALL
#define ADL_CALLBACK __stdcall
#define adl_close FreeLibrary
#define adl_address GetProcAddress
#else
#define ADL_API_CALL
#define ADL_CALLBACK
#define adl_close dlclose
#define adl_address dlsym
#endif

typedef void* ( ADL_CALLBACK *ADL_MAIN_MALLOC_CALLBACK )( int );
typedef int   ( ADL_API_CALL *ADL_MAIN_CONTROL_CREATE )( ADL_MAIN_MALLOC_CALLBACK, int );
typedef int   ( ADL_API_CALL *ADL_ADAPTER_NUMBEROFADAPTERS_GET )( int * );
typedef int   ( ADL_API_CALL *ADL_POWERXPRESS_SCHEME_GET )( int, int *, int *, int * );
typedef int   ( ADL_API_CALL *ADL_MAIN_CONTROL_DESTROY )( void );

#define ADL_OK 0
#define ADL_PX_SCHEME_DYNAMIC 2

static void* ADL_CALLBACK adl_malloc_wrapper( int iSize )
{
    return x264_malloc( iSize );
}

static int detect_switchable_graphics( void )
{
    void *hDLL;
    ADL_MAIN_CONTROL_CREATE          ADL_Main_Control_Create;
    ADL_ADAPTER_NUMBEROFADAPTERS_GET ADL_Adapter_NumberOfAdapters_Get;
    ADL_POWERXPRESS_SCHEME_GET       ADL_PowerXpress_Scheme_Get;
    ADL_MAIN_CONTROL_DESTROY         ADL_Main_Control_Destroy;
    int ret = 0;

#ifdef _WIN32
    hDLL = LoadLibraryW( L"atiadlxx.dll" );
    if( !hDLL )
        hDLL = LoadLibraryW( L"atiadlxy.dll" );
#else
    hDLL = dlopen( "libatiadlxx.so", RTLD_LAZY|RTLD_GLOBAL );
#endif
    if( !hDLL )
        goto fail0;

    ADL_Main_Control_Create          = (ADL_MAIN_CONTROL_CREATE)adl_address(hDLL, "ADL_Main_Control_Create");
    ADL_Main_Control_Destroy         = (ADL_MAIN_CONTROL_DESTROY)adl_address(hDLL, "ADL_Main_Control_Destroy");
    ADL_Adapter_NumberOfAdapters_Get = (ADL_ADAPTER_NUMBEROFADAPTERS_GET)adl_address(hDLL, "ADL_Adapter_NumberOfAdapters_Get");
    ADL_PowerXpress_Scheme_Get       = (ADL_POWERXPRESS_SCHEME_GET)adl_address(hDLL, "ADL_PowerXpress_Scheme_Get");
    if( !ADL_Main_Control_Create || !ADL_Main_Control_Destroy || !ADL_Adapter_NumberOfAdapters_Get ||
        !ADL_PowerXpress_Scheme_Get )
        goto fail1;

    if( ADL_OK != ADL_Main_Control_Create( adl_malloc_wrapper, 1 ) )
        goto fail1;

    int numAdapters = 0;
    if( ADL_OK != ADL_Adapter_NumberOfAdapters_Get( &numAdapters ) )
        goto fail2;

    for( int i = 0; i < numAdapters; i++ )
    {
        int PXSchemeRange, PXSchemeCurrentState, PXSchemeDefaultState;
        if( ADL_OK != ADL_PowerXpress_Scheme_Get( i, &PXSchemeRange, &PXSchemeCurrentState, &PXSchemeDefaultState) )
            break;

        if( PXSchemeRange >= ADL_PX_SCHEME_DYNAMIC )
        {
            ret = 1;
            break;
        }
    }

fail2:
    ADL_Main_Control_Destroy();
fail1:
    adl_close( hDLL );
fail0:
    return ret;
}
