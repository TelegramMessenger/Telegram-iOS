/*****************************************************************************
 * opencl.h: OpenCL structures and defines
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

#ifndef X264_OPENCL_H
#define X264_OPENCL_H

#define CL_USE_DEPRECATED_OPENCL_1_1_APIS
#include "extras/cl.h"

#define OCL_API(ret, attr, name) typedef ret (attr *name##_func)

/* Platform API */
OCL_API(cl_int, CL_API_CALL, clGetPlatformIDs)
(   cl_uint          /* num_entries */,
    cl_platform_id * /* platforms */,
    cl_uint *        /* num_platforms */);

OCL_API(cl_int, CL_API_CALL, clGetPlatformInfo)
(   cl_platform_id   /* platform */,
    cl_platform_info /* param_name */,
    size_t           /* param_value_size */,
    void *           /* param_value */,
    size_t *         /* param_value_size_ret */);

/* Device APIs */
OCL_API(cl_int, CL_API_CALL, clGetDeviceIDs)
(   cl_platform_id   /* platform */,
    cl_device_type   /* device_type */,
    cl_uint          /* num_entries */,
    cl_device_id *   /* devices */,
    cl_uint *        /* num_devices */);

OCL_API(cl_int, CL_API_CALL, clGetDeviceInfo)
(   cl_device_id    /* device */,
    cl_device_info  /* param_name */,
    size_t          /* param_value_size */,
    void *          /* param_value */,
    size_t *        /* param_value_size_ret */);

OCL_API(cl_int, CL_API_CALL, clCreateSubDevices)
(   cl_device_id                         /* in_device */,
    const cl_device_partition_property * /* properties */,
    cl_uint                              /* num_devices */,
    cl_device_id *                       /* out_devices */,
    cl_uint *                            /* num_devices_ret */);

OCL_API(cl_int, CL_API_CALL, clRetainDevice)
(   cl_device_id /* device */);

OCL_API(cl_int, CL_API_CALL, clReleaseDevice)
(   cl_device_id /* device */);

/* Context APIs  */
OCL_API(cl_context, CL_API_CALL, clCreateContext)
(   const cl_context_properties * /* properties */,
    cl_uint                 /* num_devices */,
    const cl_device_id *    /* devices */,
    void (CL_CALLBACK * /* pfn_notify */)(const char *, const void *, size_t, void *),
    void *                  /* user_data */,
    cl_int *                /* errcode_ret */);

OCL_API(cl_context, CL_API_CALL, clCreateContextFromType)
(   const cl_context_properties * /* properties */,
    cl_device_type          /* device_type */,
    void (CL_CALLBACK *     /* pfn_notify*/ )(const char *, const void *, size_t, void *),
    void *                  /* user_data */,
    cl_int *                /* errcode_ret */);

OCL_API(cl_int, CL_API_CALL, clRetainContext)
(   cl_context /* context */);

OCL_API(cl_int, CL_API_CALL, clReleaseContext)
(   cl_context /* context */);

OCL_API(cl_int, CL_API_CALL, clGetContextInfo)
(   cl_context         /* context */,
    cl_context_info    /* param_name */,
    size_t             /* param_value_size */,
    void *             /* param_value */,
    size_t *           /* param_value_size_ret */);

/* Command Queue APIs */
OCL_API(cl_command_queue, CL_API_CALL, clCreateCommandQueue)
(   cl_context                     /* context */,
    cl_device_id                   /* device */,
    cl_command_queue_properties    /* properties */,
    cl_int *                       /* errcode_ret */);

OCL_API(cl_int, CL_API_CALL, clRetainCommandQueue)
(   cl_command_queue /* command_queue */);

OCL_API(cl_int, CL_API_CALL, clReleaseCommandQueue)
(   cl_command_queue /* command_queue */);

OCL_API(cl_int, CL_API_CALL, clGetCommandQueueInfo)
(   cl_command_queue      /* command_queue */,
    cl_command_queue_info /* param_name */,
    size_t                /* param_value_size */,
    void *                /* param_value */,
    size_t *              /* param_value_size_ret */);

/* Memory Object APIs */
OCL_API(cl_mem, CL_API_CALL, clCreateBuffer)
(   cl_context   /* context */,
    cl_mem_flags /* flags */,
    size_t       /* size */,
    void *       /* host_ptr */,
    cl_int *     /* errcode_ret */);

OCL_API(cl_mem, CL_API_CALL, clCreateSubBuffer)
(   cl_mem                   /* buffer */,
    cl_mem_flags             /* flags */,
    cl_buffer_create_type    /* buffer_create_type */,
    const void *             /* buffer_create_info */,
    cl_int *                 /* errcode_ret */);

OCL_API(cl_mem, CL_API_CALL, clCreateImage)
(   cl_context              /* context */,
    cl_mem_flags            /* flags */,
    const cl_image_format * /* image_format */,
    const cl_image_desc *   /* image_desc */,
    void *                  /* host_ptr */,
    cl_int *                /* errcode_ret */);

OCL_API(cl_int, CL_API_CALL, clRetainMemObject)
(   cl_mem /* memobj */);

OCL_API(cl_int, CL_API_CALL, clReleaseMemObject)
(   cl_mem /* memobj */);

OCL_API(cl_int, CL_API_CALL, clGetSupportedImageFormats)
(   cl_context           /* context */,
    cl_mem_flags         /* flags */,
    cl_mem_object_type   /* image_type */,
    cl_uint              /* num_entries */,
    cl_image_format *    /* image_formats */,
    cl_uint *            /* num_image_formats */);

OCL_API(cl_int, CL_API_CALL, clGetMemObjectInfo)
(   cl_mem           /* memobj */,
    cl_mem_info      /* param_name */,
    size_t           /* param_value_size */,
    void *           /* param_value */,
    size_t *         /* param_value_size_ret */);

OCL_API(cl_int, CL_API_CALL, clGetImageInfo)
(   cl_mem           /* image */,
    cl_image_info    /* param_name */,
    size_t           /* param_value_size */,
    void *           /* param_value */,
    size_t *         /* param_value_size_ret */);

OCL_API(cl_int, CL_API_CALL, clSetMemObjectDestructorCallback)
(   cl_mem /* memobj */,
    void (CL_CALLBACK * /*pfn_notify*/)( cl_mem /* memobj */, void* /*user_data*/),
    void * /*user_data */ );

/* Sampler APIs */
OCL_API(cl_sampler, CL_API_CALL, clCreateSampler)
(   cl_context          /* context */,
    cl_bool             /* normalized_coords */,
    cl_addressing_mode  /* addressing_mode */,
    cl_filter_mode      /* filter_mode */,
    cl_int *            /* errcode_ret */);

OCL_API(cl_int, CL_API_CALL, clRetainSampler)
(   cl_sampler /* sampler */);

OCL_API(cl_int, CL_API_CALL, clReleaseSampler)
(   cl_sampler /* sampler */);

OCL_API(cl_int, CL_API_CALL, clGetSamplerInfo)
(   cl_sampler         /* sampler */,
    cl_sampler_info    /* param_name */,
    size_t             /* param_value_size */,
    void *             /* param_value */,
    size_t *           /* param_value_size_ret */);

/* Program Object APIs  */
OCL_API(cl_program, CL_API_CALL, clCreateProgramWithSource)
(   cl_context        /* context */,
    cl_uint           /* count */,
    const char **     /* strings */,
    const size_t *    /* lengths */,
    cl_int *          /* errcode_ret */);

OCL_API(cl_program, CL_API_CALL, clCreateProgramWithBinary)
(   cl_context                     /* context */,
    cl_uint                        /* num_devices */,
    const cl_device_id *           /* device_list */,
    const size_t *                 /* lengths */,
    const unsigned char **         /* binaries */,
    cl_int *                       /* binary_status */,
    cl_int *                       /* errcode_ret */);

OCL_API(cl_program, CL_API_CALL, clCreateProgramWithBuiltInKernels)
(   cl_context            /* context */,
    cl_uint               /* num_devices */,
    const cl_device_id *  /* device_list */,
    const char *          /* kernel_names */,
    cl_int *              /* errcode_ret */);

OCL_API(cl_int, CL_API_CALL, clRetainProgram)
(   cl_program /* program */);

OCL_API(cl_int, CL_API_CALL, clReleaseProgram)
(   cl_program /* program */);

OCL_API(cl_int, CL_API_CALL, clBuildProgram)
(   cl_program           /* program */,
    cl_uint              /* num_devices */,
    const cl_device_id * /* device_list */,
    const char *         /* options */,
    void (CL_CALLBACK *  /* pfn_notify */)(cl_program /* program */, void * /* user_data */),
    void *               /* user_data */);

OCL_API(cl_int, CL_API_CALL, clCompileProgram)
(   cl_program           /* program */,
    cl_uint              /* num_devices */,
    const cl_device_id * /* device_list */,
    const char *         /* options */,
    cl_uint              /* num_input_headers */,
    const cl_program *   /* input_headers */,
    const char **        /* header_include_names */,
    void (CL_CALLBACK *  /* pfn_notify */)(cl_program /* program */, void * /* user_data */),
    void *               /* user_data */);

OCL_API(cl_program, CL_API_CALL, clLinkProgram)
(   cl_context           /* context */,
    cl_uint              /* num_devices */,
    const cl_device_id * /* device_list */,
    const char *         /* options */,
    cl_uint              /* num_input_programs */,
    const cl_program *   /* input_programs */,
    void (CL_CALLBACK *  /* pfn_notify */)(cl_program /* program */, void * /* user_data */),
    void *               /* user_data */,
    cl_int *             /* errcode_ret */ );


OCL_API(cl_int, CL_API_CALL, clUnloadPlatformCompiler)
(   cl_platform_id /* platform */);

OCL_API(cl_int, CL_API_CALL, clGetProgramInfo)
(   cl_program         /* program */,
    cl_program_info    /* param_name */,
    size_t             /* param_value_size */,
    void *             /* param_value */,
    size_t *           /* param_value_size_ret */);

OCL_API(cl_int, CL_API_CALL, clGetProgramBuildInfo)
(   cl_program            /* program */,
    cl_device_id          /* device */,
    cl_program_build_info /* param_name */,
    size_t                /* param_value_size */,
    void *                /* param_value */,
    size_t *              /* param_value_size_ret */);

/* Kernel Object APIs */
OCL_API(cl_kernel, CL_API_CALL, clCreateKernel)
(   cl_program      /* program */,
    const char *    /* kernel_name */,
    cl_int *        /* errcode_ret */);

OCL_API(cl_int, CL_API_CALL, clCreateKernelsInProgram)
(   cl_program     /* program */,
    cl_uint        /* num_kernels */,
    cl_kernel *    /* kernels */,
    cl_uint *      /* num_kernels_ret */);

OCL_API(cl_int, CL_API_CALL, clRetainKernel)
(   cl_kernel    /* kernel */);

OCL_API(cl_int, CL_API_CALL, clReleaseKernel)
(   cl_kernel   /* kernel */);

OCL_API(cl_int, CL_API_CALL, clSetKernelArg)
(   cl_kernel    /* kernel */,
    cl_uint      /* arg_index */,
    size_t       /* arg_size */,
    const void * /* arg_value */);

OCL_API(cl_int, CL_API_CALL, clGetKernelInfo)
(   cl_kernel       /* kernel */,
    cl_kernel_info  /* param_name */,
    size_t          /* param_value_size */,
    void *          /* param_value */,
    size_t *        /* param_value_size_ret */);

OCL_API(cl_int, CL_API_CALL, clGetKernelArgInfo)
(   cl_kernel       /* kernel */,
    cl_uint         /* arg_indx */,
    cl_kernel_arg_info  /* param_name */,
    size_t          /* param_value_size */,
    void *          /* param_value */,
    size_t *        /* param_value_size_ret */);

OCL_API(cl_int, CL_API_CALL, clGetKernelWorkGroupInfo)
(   cl_kernel                  /* kernel */,
    cl_device_id               /* device */,
    cl_kernel_work_group_info  /* param_name */,
    size_t                     /* param_value_size */,
    void *                     /* param_value */,
    size_t *                   /* param_value_size_ret */);

/* Event Object APIs */
OCL_API(cl_int, CL_API_CALL, clWaitForEvents)
(   cl_uint             /* num_events */,
    const cl_event *    /* event_list */);

OCL_API(cl_int, CL_API_CALL, clGetEventInfo)
(   cl_event         /* event */,
    cl_event_info    /* param_name */,
    size_t           /* param_value_size */,
    void *           /* param_value */,
    size_t *         /* param_value_size_ret */);

OCL_API(cl_event, CL_API_CALL, clCreateUserEvent)
(   cl_context    /* context */,
    cl_int *      /* errcode_ret */);

OCL_API(cl_int, CL_API_CALL, clRetainEvent)
(   cl_event /* event */);

OCL_API(cl_int, CL_API_CALL, clReleaseEvent)
(   cl_event /* event */);

OCL_API(cl_int, CL_API_CALL, clSetUserEventStatus)
(   cl_event   /* event */,
    cl_int     /* execution_status */);

OCL_API(cl_int, CL_API_CALL, clSetEventCallback)
(   cl_event    /* event */,
    cl_int      /* command_exec_callback_type */,
    void (CL_CALLBACK * /* pfn_notify */)(cl_event, cl_int, void *),
    void *      /* user_data */);

/* Profiling APIs */
OCL_API(cl_int, CL_API_CALL, clGetEventProfilingInfo)
(   cl_event            /* event */,
    cl_profiling_info   /* param_name */,
    size_t              /* param_value_size */,
    void *              /* param_value */,
    size_t *            /* param_value_size_ret */);

/* Flush and Finish APIs */
OCL_API(cl_int, CL_API_CALL, clFlush)
(   cl_command_queue /* command_queue */);

OCL_API(cl_int, CL_API_CALL, clFinish)
(   cl_command_queue /* command_queue */);

/* Enqueued Commands APIs */
OCL_API(cl_int, CL_API_CALL, clEnqueueReadBuffer)
(   cl_command_queue    /* command_queue */,
    cl_mem              /* buffer */,
    cl_bool             /* blocking_read */,
    size_t              /* offset */,
    size_t              /* size */,
    void *              /* ptr */,
    cl_uint             /* num_events_in_wait_list */,
    const cl_event *    /* event_wait_list */,
    cl_event *          /* event */);

OCL_API(cl_int, CL_API_CALL, clEnqueueReadBufferRect)
(   cl_command_queue    /* command_queue */,
    cl_mem              /* buffer */,
    cl_bool             /* blocking_read */,
    const size_t *      /* buffer_offset */,
    const size_t *      /* host_offset */,
    const size_t *      /* region */,
    size_t              /* buffer_row_pitch */,
    size_t              /* buffer_slice_pitch */,
    size_t              /* host_row_pitch */,
    size_t              /* host_slice_pitch */,
    void *              /* ptr */,
    cl_uint             /* num_events_in_wait_list */,
    const cl_event *    /* event_wait_list */,
    cl_event *          /* event */);

OCL_API(cl_int, CL_API_CALL, clEnqueueWriteBuffer)
(   cl_command_queue   /* command_queue */,
    cl_mem             /* buffer */,
    cl_bool            /* blocking_write */,
    size_t             /* offset */,
    size_t             /* size */,
    const void *       /* ptr */,
    cl_uint            /* num_events_in_wait_list */,
    const cl_event *   /* event_wait_list */,
    cl_event *         /* event */);

OCL_API(cl_int, CL_API_CALL, clEnqueueWriteBufferRect)
(   cl_command_queue    /* command_queue */,
    cl_mem              /* buffer */,
    cl_bool             /* blocking_write */,
    const size_t *      /* buffer_offset */,
    const size_t *      /* host_offset */,
    const size_t *      /* region */,
    size_t              /* buffer_row_pitch */,
    size_t              /* buffer_slice_pitch */,
    size_t              /* host_row_pitch */,
    size_t              /* host_slice_pitch */,
    const void *        /* ptr */,
    cl_uint             /* num_events_in_wait_list */,
    const cl_event *    /* event_wait_list */,
    cl_event *          /* event */);

OCL_API(cl_int, CL_API_CALL, clEnqueueFillBuffer)
(   cl_command_queue   /* command_queue */,
    cl_mem             /* buffer */,
    const void *       /* pattern */,
    size_t             /* pattern_size */,
    size_t             /* offset */,
    size_t             /* size */,
    cl_uint            /* num_events_in_wait_list */,
    const cl_event *   /* event_wait_list */,
    cl_event *         /* event */);

OCL_API(cl_int, CL_API_CALL, clEnqueueCopyBuffer)
(   cl_command_queue    /* command_queue */,
    cl_mem              /* src_buffer */,
    cl_mem              /* dst_buffer */,
    size_t              /* src_offset */,
    size_t              /* dst_offset */,
    size_t              /* size */,
    cl_uint             /* num_events_in_wait_list */,
    const cl_event *    /* event_wait_list */,
    cl_event *          /* event */);

OCL_API(cl_int, CL_API_CALL, clEnqueueCopyBufferRect)
(   cl_command_queue    /* command_queue */,
    cl_mem              /* src_buffer */,
    cl_mem              /* dst_buffer */,
    const size_t *      /* src_origin */,
    const size_t *      /* dst_origin */,
    const size_t *      /* region */,
    size_t              /* src_row_pitch */,
    size_t              /* src_slice_pitch */,
    size_t              /* dst_row_pitch */,
    size_t              /* dst_slice_pitch */,
    cl_uint             /* num_events_in_wait_list */,
    const cl_event *    /* event_wait_list */,
    cl_event *          /* event */);

OCL_API(cl_int, CL_API_CALL, clEnqueueReadImage)
(   cl_command_queue     /* command_queue */,
    cl_mem               /* image */,
    cl_bool              /* blocking_read */,
    const size_t *       /* origin[3] */,
    const size_t *       /* region[3] */,
    size_t               /* row_pitch */,
    size_t               /* slice_pitch */,
    void *               /* ptr */,
    cl_uint              /* num_events_in_wait_list */,
    const cl_event *     /* event_wait_list */,
    cl_event *           /* event */);

OCL_API(cl_int, CL_API_CALL, clEnqueueWriteImage)
(   cl_command_queue    /* command_queue */,
    cl_mem              /* image */,
    cl_bool             /* blocking_write */,
    const size_t *      /* origin[3] */,
    const size_t *      /* region[3] */,
    size_t              /* input_row_pitch */,
    size_t              /* input_slice_pitch */,
    const void *        /* ptr */,
    cl_uint             /* num_events_in_wait_list */,
    const cl_event *    /* event_wait_list */,
    cl_event *          /* event */);

OCL_API(cl_int, CL_API_CALL, clEnqueueFillImage)
(   cl_command_queue   /* command_queue */,
    cl_mem             /* image */,
    const void *       /* fill_color */,
    const size_t *     /* origin[3] */,
    const size_t *     /* region[3] */,
    cl_uint            /* num_events_in_wait_list */,
    const cl_event *   /* event_wait_list */,
    cl_event *         /* event */);

OCL_API(cl_int, CL_API_CALL, clEnqueueCopyImage)
(   cl_command_queue     /* command_queue */,
    cl_mem               /* src_image */,
    cl_mem               /* dst_image */,
    const size_t *       /* src_origin[3] */,
    const size_t *       /* dst_origin[3] */,
    const size_t *       /* region[3] */,
    cl_uint              /* num_events_in_wait_list */,
    const cl_event *     /* event_wait_list */,
    cl_event *           /* event */);

OCL_API(cl_int, CL_API_CALL, clEnqueueCopyImageToBuffer)
(   cl_command_queue /* command_queue */,
    cl_mem           /* src_image */,
    cl_mem           /* dst_buffer */,
    const size_t *   /* src_origin[3] */,
    const size_t *   /* region[3] */,
    size_t           /* dst_offset */,
    cl_uint          /* num_events_in_wait_list */,
    const cl_event * /* event_wait_list */,
    cl_event *       /* event */);

OCL_API(cl_int, CL_API_CALL, clEnqueueCopyBufferToImage)
(   cl_command_queue /* command_queue */,
    cl_mem           /* src_buffer */,
    cl_mem           /* dst_image */,
    size_t           /* src_offset */,
    const size_t *   /* dst_origin[3] */,
    const size_t *   /* region[3] */,
    cl_uint          /* num_events_in_wait_list */,
    const cl_event * /* event_wait_list */,
    cl_event *       /* event */);

OCL_API(void *, CL_API_CALL, clEnqueueMapBuffer)
(   cl_command_queue /* command_queue */,
    cl_mem           /* buffer */,
    cl_bool          /* blocking_map */,
    cl_map_flags     /* map_flags */,
    size_t           /* offset */,
    size_t           /* size */,
    cl_uint          /* num_events_in_wait_list */,
    const cl_event * /* event_wait_list */,
    cl_event *       /* event */,
    cl_int *         /* errcode_ret */);

OCL_API(void *, CL_API_CALL, clEnqueueMapImage)
(   cl_command_queue  /* command_queue */,
    cl_mem            /* image */,
    cl_bool           /* blocking_map */,
    cl_map_flags      /* map_flags */,
    const size_t *    /* origin[3] */,
    const size_t *    /* region[3] */,
    size_t *          /* image_row_pitch */,
    size_t *          /* image_slice_pitch */,
    cl_uint           /* num_events_in_wait_list */,
    const cl_event *  /* event_wait_list */,
    cl_event *        /* event */,
    cl_int *          /* errcode_ret */);

OCL_API(cl_int, CL_API_CALL, clEnqueueUnmapMemObject)
(   cl_command_queue /* command_queue */,
    cl_mem           /* memobj */,
    void *           /* mapped_ptr */,
    cl_uint          /* num_events_in_wait_list */,
    const cl_event *  /* event_wait_list */,
    cl_event *        /* event */);

OCL_API(cl_int, CL_API_CALL, clEnqueueMigrateMemObjects)
(   cl_command_queue       /* command_queue */,
    cl_uint                /* num_mem_objects */,
    const cl_mem *         /* mem_objects */,
    cl_mem_migration_flags /* flags */,
    cl_uint                /* num_events_in_wait_list */,
    const cl_event *       /* event_wait_list */,
    cl_event *             /* event */);

OCL_API(cl_int, CL_API_CALL, clEnqueueNDRangeKernel)
(   cl_command_queue /* command_queue */,
    cl_kernel        /* kernel */,
    cl_uint          /* work_dim */,
    const size_t *   /* global_work_offset */,
    const size_t *   /* global_work_size */,
    const size_t *   /* local_work_size */,
    cl_uint          /* num_events_in_wait_list */,
    const cl_event * /* event_wait_list */,
    cl_event *       /* event */);

OCL_API(cl_int, CL_API_CALL, clEnqueueTask)
(   cl_command_queue  /* command_queue */,
    cl_kernel         /* kernel */,
    cl_uint           /* num_events_in_wait_list */,
    const cl_event *  /* event_wait_list */,
    cl_event *        /* event */);

OCL_API(cl_int, CL_API_CALL, clEnqueueNativeKernel)
(   cl_command_queue  /* command_queue */,
    void (CL_CALLBACK * /*user_func*/)(void *),
    void *            /* args */,
    size_t            /* cb_args */,
    cl_uint           /* num_mem_objects */,
    const cl_mem *    /* mem_list */,
    const void **     /* args_mem_loc */,
    cl_uint           /* num_events_in_wait_list */,
    const cl_event *  /* event_wait_list */,
    cl_event *        /* event */);

OCL_API(cl_int, CL_API_CALL, clEnqueueMarkerWithWaitList)
(   cl_command_queue /* command_queue */,
    cl_uint           /* num_events_in_wait_list */,
    const cl_event *  /* event_wait_list */,
    cl_event *        /* event */);

OCL_API(cl_int, CL_API_CALL, clEnqueueBarrierWithWaitList)
(   cl_command_queue /* command_queue */,
    cl_uint           /* num_events_in_wait_list */,
    const cl_event *  /* event_wait_list */,
    cl_event *        /* event */);


/* Extension function access
*
* Returns the extension function address for the given function name,
* or NULL if a valid function can not be found.  The client must
* check to make sure the address is not NULL, before using or
* calling the returned function address.
*/
OCL_API(void *, CL_API_CALL, clGetExtensionFunctionAddressForPlatform)
(   cl_platform_id /* platform */,
    const char *   /* func_name */);


// Deprecated OpenCL 1.1 APIs
OCL_API(cl_mem, CL_API_CALL, clCreateImage2D)
(   cl_context              /* context */,
    cl_mem_flags            /* flags */,
    const cl_image_format * /* image_format */,
    size_t                  /* image_width */,
    size_t                  /* image_height */,
    size_t                  /* image_row_pitch */,
    void *                  /* host_ptr */,
    cl_int *                /* errcode_ret */);

OCL_API(cl_mem, CL_API_CALL, clCreateImage3D)
(   cl_context              /* context */,
    cl_mem_flags            /* flags */,
    const cl_image_format * /* image_format */,
    size_t                  /* image_width */,
    size_t                  /* image_height */,
    size_t                  /* image_depth */,
    size_t                  /* image_row_pitch */,
    size_t                  /* image_slice_pitch */,
    void *                  /* host_ptr */,
    cl_int *                /* errcode_ret */);

OCL_API(cl_int, CL_API_CALL, clEnqueueMarker)
(   cl_command_queue    /* command_queue */,
    cl_event *          /* event */);

OCL_API(cl_int, CL_API_CALL, clEnqueueWaitForEvents)
(   cl_command_queue /* command_queue */,
    cl_uint          /* num_events */,
    const cl_event * /* event_list */);

OCL_API(cl_int, CL_API_CALL, clEnqueueBarrier)
(   cl_command_queue /* command_queue */);

OCL_API(cl_int, CL_API_CALL, clUnloadCompiler)
(   void);

OCL_API(void *, CL_API_CALL, clGetExtensionFunctionAddress)
(   const char * /* func_name */);

#define OCL_DECLARE_FUNC(name) name##_func name

typedef struct
{
    void *library;

    OCL_DECLARE_FUNC( clBuildProgram );
    OCL_DECLARE_FUNC( clCreateBuffer );
    OCL_DECLARE_FUNC( clCreateCommandQueue );
    OCL_DECLARE_FUNC( clCreateContext );
    OCL_DECLARE_FUNC( clCreateImage2D );
    OCL_DECLARE_FUNC( clCreateKernel );
    OCL_DECLARE_FUNC( clCreateProgramWithBinary );
    OCL_DECLARE_FUNC( clCreateProgramWithSource );
    OCL_DECLARE_FUNC( clEnqueueCopyBuffer );
    OCL_DECLARE_FUNC( clEnqueueMapBuffer );
    OCL_DECLARE_FUNC( clEnqueueNDRangeKernel );
    OCL_DECLARE_FUNC( clEnqueueReadBuffer );
    OCL_DECLARE_FUNC( clEnqueueWriteBuffer );
    OCL_DECLARE_FUNC( clFinish );
    OCL_DECLARE_FUNC( clGetCommandQueueInfo );
    OCL_DECLARE_FUNC( clGetDeviceIDs );
    OCL_DECLARE_FUNC( clGetDeviceInfo );
    OCL_DECLARE_FUNC( clGetKernelWorkGroupInfo );
    OCL_DECLARE_FUNC( clGetPlatformIDs );
    OCL_DECLARE_FUNC( clGetProgramBuildInfo );
    OCL_DECLARE_FUNC( clGetProgramInfo );
    OCL_DECLARE_FUNC( clGetSupportedImageFormats );
    OCL_DECLARE_FUNC( clReleaseCommandQueue );
    OCL_DECLARE_FUNC( clReleaseContext );
    OCL_DECLARE_FUNC( clReleaseKernel );
    OCL_DECLARE_FUNC( clReleaseMemObject );
    OCL_DECLARE_FUNC( clReleaseProgram );
    OCL_DECLARE_FUNC( clSetKernelArg );
} x264_opencl_function_t;

/* Number of downscale resolutions to use for motion search */
#define NUM_IMAGE_SCALES 4

/* Number of PCIe copies that can be queued before requiring a flush */
#define MAX_FINISH_COPIES 1024

/* Size (in bytes) of the page-locked buffer used for PCIe xfers */
#define PAGE_LOCKED_BUF_SIZE 32 * 1024 * 1024

typedef struct
{
    x264_opencl_function_t *ocl;

    cl_context       context;
    cl_device_id     device;
    cl_command_queue queue;

    cl_program  lookahead_program;
    cl_int      last_buf;

    cl_mem      page_locked_buffer;
    char       *page_locked_ptr;
    int         pl_occupancy;

    struct
    {
        void *src;
        void *dest;
        int   bytes;
    } copies[MAX_FINISH_COPIES];
    int         num_copies;

    int         b_device_AMD_SI;
    int         b_fatal_error;
    int         lookahead_thread_pri;
    int         opencl_thread_pri;

    /* downscale lowres luma */
    cl_kernel   downscale_hpel_kernel;
    cl_kernel   downscale_kernel1;
    cl_kernel   downscale_kernel2;
    cl_mem      luma_16x16_image[2];

    /* weightp filtering */
    cl_kernel   weightp_hpel_kernel;
    cl_kernel   weightp_scaled_images_kernel;
    cl_mem      weighted_scaled_images[NUM_IMAGE_SCALES];
    cl_mem      weighted_luma_hpel;

    /* intra */
    cl_kernel   memset_kernel;
    cl_kernel   intra_kernel;
    cl_kernel   rowsum_intra_kernel;
    cl_mem      row_satds[2];

    /* hierarchical motion estimation */
    cl_kernel   hme_kernel;
    cl_kernel   subpel_refine_kernel;
    cl_mem      mv_buffers[2];
    cl_mem      lowres_mv_costs;
    cl_mem      mvp_buffer;

    /* bidir */
    cl_kernel   mode_select_kernel;
    cl_kernel   rowsum_inter_kernel;
    cl_mem      lowres_costs[2];
    cl_mem      frame_stats[2]; /* cost_est, cost_est_aq, intra_mbs */
} x264_opencl_t;

typedef struct
{
    x264_opencl_function_t *ocl;

    cl_mem scaled_image2Ds[NUM_IMAGE_SCALES];
    cl_mem luma_hpel;
    cl_mem inv_qscale_factor;
    cl_mem intra_cost;
    cl_mem lowres_mvs0;
    cl_mem lowres_mvs1;
    cl_mem lowres_mv_costs0;
    cl_mem lowres_mv_costs1;
} x264_frame_opencl_t;

typedef struct x264_frame x264_frame;

#define x264_opencl_load_library x264_template(opencl_load_library)
x264_opencl_function_t *x264_opencl_load_library( void );
#define x264_opencl_close_library x264_template(opencl_close_library)
void x264_opencl_close_library( x264_opencl_function_t *ocl );

#define x264_opencl_lookahead_init x264_template(opencl_lookahead_init)
int x264_opencl_lookahead_init( x264_t *h );
#define x264_opencl_lookahead_delete x264_template(opencl_lookahead_delete)
void x264_opencl_lookahead_delete( x264_t *h );

#define x264_opencl_frame_delete x264_template(opencl_frame_delete)
void x264_opencl_frame_delete( x264_frame *frame );

#endif
