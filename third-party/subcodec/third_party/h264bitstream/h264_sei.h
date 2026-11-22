/* 
 * h264bitstream - a library for reading and writing H.264 video
 * Copyright (C) 2005-2007 Auroras Entertainment, LLC
 * Copyright (C) 2008-2011 Avail-TVN
 * 
 * Written by Alex Izvorski <aizvorski@gmail.com> and Alex Giladi <alex.giladi@gmail.com>
 * 
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 * 
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 */

#include <stdint.h>

#ifndef _H264_SEI_H
#define _H264_SEI_H        1

#include <stdint.h>
#include <stdbool.h>

#include "bs.h"

#ifdef __cplusplus
extern "C" {
#endif

#define MAX_J 128
    
typedef struct
{
    unsigned short layer_id; //TBD: is layer_id possible to larger than 65535
    unsigned char priority_id;
    bool discardable_flag;
    unsigned char dependency_id;
    unsigned char quality_id;
    unsigned char temporal_id;
    bool sub_pic_layer_flag;
    bool sub_region_layer_flag;
    bool iroi_division_info_present_flag;
    bool profile_level_info_present_flag;
    bool bitrate_info_present_flag;
    bool frm_rate_info_present_flag;
    bool frm_size_info_present_flag;
    bool layer_dependency_info_present_flag;
    bool parameter_sets_info_present_flag;
    bool bitstream_restriction_info_present_flag;
    bool exact_inter_layer_pred_flag;
    bool exact_sample_value_match_flag;
    bool layer_conversion_flag;
    bool layer_output_flag;
    int layer_profile_level_idc;
    unsigned short avg_bitrate;
    unsigned short max_bitrate_layer;
    unsigned short max_bitrate_layer_representation;
    unsigned short max_bitrate_calc_window;
    unsigned char constant_frm_rate_idc;
    unsigned short avg_frm_rate;
    unsigned short frm_width_in_mbs_minus1;
    unsigned short frm_height_in_mbs_minus1;
    unsigned short base_region_layer_id;
    bool dynamic_rect_flag;
    unsigned short horizontal_offset;
    unsigned short vertical_offset;
    unsigned short region_width;
    unsigned short region_height;
    unsigned short roi_id;
    bool iroi_grid_flag;
    unsigned short grid_width_in_mbs_minus1;
    unsigned short grid_height_in_mbs_minus1;
    unsigned short num_rois_minus1;
    struct
    {
        unsigned short first_mb_in_roi;
        unsigned short roi_width_in_mbs_minus1;
        unsigned short roi_height_in_mbs_minus1;
    } roi[MAX_J];
    unsigned short num_directly_dependent_layers;
    unsigned short directly_dependent_layer_id_delta_minus1[MAX_J];
    unsigned short layer_dependency_info_src_layer_id_delta;
    unsigned short num_seq_parameter_sets;
    unsigned short seq_parameter_set_id_delta[MAX_J];
    unsigned short num_subset_seq_parameter_sets;
    unsigned short subset_seq_parameter_set_id_delta[MAX_J];
    unsigned short num_pic_parameter_sets_minus1;
    unsigned short pic_parameter_set_id_delta[MAX_J];
    unsigned short parameter_sets_info_src_layer_id_delta;
    bool motion_vectors_over_pic_boundaries_flag;
    unsigned short max_bytes_per_pic_denom;
    unsigned short max_bits_per_mb_denom;
    unsigned short log2_max_mv_length_horizontal;
    unsigned short log2_max_mv_length_vertical;
    unsigned short max_num_reorder_frames;
    unsigned short max_dec_frame_buffering;
    unsigned short conversion_type_idc;
    bool rewriting_info_flag[2];
    int rewriting_profile_level_idc[2];
    unsigned short rewriting_avg_bitrate[2];
    unsigned short rewriting_max_bitrate[2];
} sei_scalability_layer_info_t;

#define MAX_LENGTH 128

typedef struct
{
    bool temporal_id_nesting_flag;
    bool priority_layer_info_present_flag;
    bool priority_id_setting_flag;
    unsigned short num_layers_minus1;
    sei_scalability_layer_info_t layers[MAX_J];
    unsigned short pr_num_dIds_minus1;
    struct
    {
        unsigned char pr_dependency_id;
        unsigned short pr_num_minus1;
        struct
        {
            unsigned short pr_id;
            int pr_profile_level_idc;
            unsigned short pr_avg_bitrate;
            unsigned short pr_max_bitrate;
        } pr_info[MAX_J];
        unsigned char priority_id_setting_uri[MAX_LENGTH];
    } pr[MAX_J];
} sei_scalability_info_t;
    
typedef struct
{
    int payloadType;
    int payloadSize;
    
    union
    {
        sei_scalability_info_t* sei_svc;
        uint8_t* data;
    };
} sei_t;

sei_t* sei_new();
void sei_free(sei_t* s);

//D.1 SEI payload syntax
#define SEI_TYPE_BUFFERING_PERIOD 0
#define SEI_TYPE_PIC_TIMING       1
#define SEI_TYPE_PAN_SCAN_RECT    2
#define SEI_TYPE_FILLER_PAYLOAD   3
#define SEI_TYPE_USER_DATA_REGISTERED_ITU_T_T35  4
#define SEI_TYPE_USER_DATA_UNREGISTERED  5
#define SEI_TYPE_RECOVERY_POINT   6
#define SEI_TYPE_DEC_REF_PIC_MARKING_REPETITION 7
#define SEI_TYPE_SPARE_PIC        8
#define SEI_TYPE_SCENE_INFO       9
#define SEI_TYPE_SUB_SEQ_INFO    10
#define SEI_TYPE_SUB_SEQ_LAYER_CHARACTERISTICS  11
#define SEI_TYPE_SUB_SEQ_CHARACTERISTICS  12
#define SEI_TYPE_FULL_FRAME_FREEZE  13
#define SEI_TYPE_FULL_FRAME_FREEZE_RELEASE  14
#define SEI_TYPE_FULL_FRAME_SNAPSHOT  15
#define SEI_TYPE_PROGRESSIVE_REFINEMENT_SEGMENT_START  16
#define SEI_TYPE_PROGRESSIVE_REFINEMENT_SEGMENT_END  17
#define SEI_TYPE_MOTION_CONSTRAINED_SLICE_GROUP_SET  18
#define SEI_TYPE_FILM_GRAIN_CHARACTERISTICS  19
#define SEI_TYPE_DEBLOCKING_FILTER_DISPLAY_PREFERENCE  20
#define SEI_TYPE_STEREO_VIDEO_INFO  21
#define SEI_TYPE_SCALABILITY_INFO  24

#ifdef __cplusplus
}
#endif

#endif
