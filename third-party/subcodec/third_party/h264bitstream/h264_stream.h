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

#ifndef _H264_STREAM_H
#define _H264_STREAM_H        1

#include <stdint.h>
#include <stdio.h>
#include <assert.h>

#include "bs.h"
#include "h264_sei.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct
{
    int cpb_cnt_minus1;
    int bit_rate_scale;
    int cpb_size_scale;
    int bit_rate_value_minus1[32]; // up to cpb_cnt_minus1, which is <= 31
    int cpb_size_value_minus1[32];
    int cbr_flag[32];
    int initial_cpb_removal_delay_length_minus1;
    int cpb_removal_delay_length_minus1;
    int dpb_output_delay_length_minus1;
    int time_offset_length;
} hrd_t;


/**
   Sequence Parameter Set
   @see 7.3.2.1 Sequence parameter set RBSP syntax
   @see read_seq_parameter_set_rbsp
   @see write_seq_parameter_set_rbsp
   @see debug_sps
*/
typedef struct
{
    int profile_idc;
    int constraint_set0_flag;
    int constraint_set1_flag;
    int constraint_set2_flag;
    int constraint_set3_flag;
    int constraint_set4_flag;
    int constraint_set5_flag;
    int reserved_zero_2bits;
    int level_idc;
    int seq_parameter_set_id;
    int chroma_format_idc;
    int residual_colour_transform_flag;
    int bit_depth_luma_minus8;
    int bit_depth_chroma_minus8;
    int qpprime_y_zero_transform_bypass_flag;
    int seq_scaling_matrix_present_flag;
      int seq_scaling_list_present_flag[12];
      int ScalingList4x4[6][16];
      int UseDefaultScalingMatrix4x4Flag[6];
      int ScalingList8x8[6][64];
      int UseDefaultScalingMatrix8x8Flag[6];
    int log2_max_frame_num_minus4;
    int pic_order_cnt_type;
    int log2_max_pic_order_cnt_lsb_minus4;
    int delta_pic_order_always_zero_flag;
    int offset_for_non_ref_pic;
    int offset_for_top_to_bottom_field;
    int num_ref_frames_in_pic_order_cnt_cycle;
    int offset_for_ref_frame[256];
    int num_ref_frames;
    int gaps_in_frame_num_value_allowed_flag;
    int pic_width_in_mbs_minus1;
    int pic_height_in_map_units_minus1;
    int frame_mbs_only_flag;
    int mb_adaptive_frame_field_flag;
    int direct_8x8_inference_flag;
    int frame_cropping_flag;
    int frame_crop_left_offset;
    int frame_crop_right_offset;
    int frame_crop_top_offset;
    int frame_crop_bottom_offset;
    int vui_parameters_present_flag;
    
    struct
    {
        int aspect_ratio_info_present_flag;
        int aspect_ratio_idc;
        int sar_width;
        int sar_height;
        int overscan_info_present_flag;
        int overscan_appropriate_flag;
        int video_signal_type_present_flag;
        int video_format;
        int video_full_range_flag;
        int colour_description_present_flag;
        int colour_primaries;
        int transfer_characteristics;
        int matrix_coefficients;
        int chroma_loc_info_present_flag;
        int chroma_sample_loc_type_top_field;
        int chroma_sample_loc_type_bottom_field;
        int timing_info_present_flag;
        int num_units_in_tick;
        int time_scale;
        int fixed_frame_rate_flag;
        int nal_hrd_parameters_present_flag;
        int vcl_hrd_parameters_present_flag;
        int low_delay_hrd_flag;
        int pic_struct_present_flag;
        int bitstream_restriction_flag;
        int motion_vectors_over_pic_boundaries_flag;
        int max_bytes_per_pic_denom;
        int max_bits_per_mb_denom;
        int log2_max_mv_length_horizontal;
        int log2_max_mv_length_vertical;
        int num_reorder_frames;
        int max_dec_frame_buffering;
    } vui;
    
    hrd_t hrd_nal;
    hrd_t hrd_vcl;

} sps_t;

/**
 Subset Sequence Parameter Set for SVC
 @see G.7.3.2.1.4 Sequence parameter set SVC extension RBSP syntax
 @see read_seq_parameter_set_svc_extension_rbsp
 @see write_seq_parameter_set_svc_extension_rbsp
 @see debug_sps
 */
typedef struct
{
    bool inter_layer_deblocking_filter_control_present_flag;
    unsigned char extended_spatial_scalability_idc;
    bool chroma_phase_x_plus1_flag;
    unsigned char chroma_phase_y_plus1;
    bool seq_ref_layer_chroma_phase_x_plus1_flag;
    unsigned char seq_ref_layer_chroma_phase_y_plus1;
    int seq_scaled_ref_layer_left_offset;
    int seq_scaled_ref_layer_top_offset;
    int seq_scaled_ref_layer_right_offset;
    int seq_scaled_ref_layer_bottom_offset;
    bool seq_tcoeff_level_prediction_flag;
    bool adaptive_tcoeff_level_prediction_flag;
    bool slice_header_restriction_flag;
    bool svc_vui_parameters_present_flag;
    
    struct {
        unsigned short vui_ext_num_entries_minus1;
        unsigned char vui_ext_dependency_id[MAX_J];
        unsigned char vui_ext_quality_id[MAX_J];
        unsigned char vui_ext_temporal_id[MAX_J];
        unsigned char vui_ext_timing_info_present_flag[MAX_J];
        unsigned int vui_ext_num_units_in_tick[MAX_J];
        unsigned int vui_ext_time_scale[MAX_J];
        bool vui_ext_fixed_frame_rate_flag[MAX_J];
        bool vui_ext_nal_hrd_parameters_present_flag[MAX_J];
        bool vui_ext_vcl_hrd_parameters_present_flag[MAX_J];
        bool vui_ext_low_delay_hrd_flag[MAX_J];
        bool vui_ext_pic_struct_present_flag[MAX_J];
    } vui;
    hrd_t hrd_nal[MAX_J];
    hrd_t hrd_vcl[MAX_J];
} sps_svc_ext_t;

/**
 Subset Sequence Parameter Set for SVC
 @see G.7.3.2.1.4 Sequence parameter set SVC extension RBSP syntax
 @see read_seq_parameter_set_svc_extension_rbsp
 @see write_seq_parameter_set_svc_extension_rbsp
 @see debug_sps
 */
typedef struct
{
    sps_t *sps;
    union {
        sps_svc_ext_t* sps_svc_ext;
    };
    bool additional_extension2_flag;
} sps_subset_t;


/**
   Picture Parameter Set
   @see 7.3.2.2 Picture parameter set RBSP syntax
   @see read_pic_parameter_set_rbsp
   @see write_pic_parameter_set_rbsp
   @see debug_pps
*/
typedef struct 
{
    int pic_parameter_set_id;
    int seq_parameter_set_id;
    int entropy_coding_mode_flag;
    int pic_order_present_flag;
    int num_slice_groups_minus1;
    int slice_group_map_type;
    int run_length_minus1[8]; // up to num_slice_groups_minus1, which is <= 7 in Baseline and Extended, 0 otheriwse
    int top_left[8];
    int bottom_right[8];
    int slice_group_change_direction_flag;
    int slice_group_change_rate_minus1;
    int pic_size_in_map_units_minus1;
    int slice_group_id[256]; // FIXME what size?
    int num_ref_idx_l0_active_minus1;
    int num_ref_idx_l1_active_minus1;
    int weighted_pred_flag;
    int weighted_bipred_idc;
    int pic_init_qp_minus26;
    int pic_init_qs_minus26;
    int chroma_qp_index_offset;
    int deblocking_filter_control_present_flag;
    int constrained_intra_pred_flag;
    int redundant_pic_cnt_present_flag;

    // set iff we carry any of the optional headers
    int _more_rbsp_data_present;

    int transform_8x8_mode_flag;
    int pic_scaling_matrix_present_flag;
       int pic_scaling_list_present_flag[8];
       int ScalingList4x4[6][16];
       int UseDefaultScalingMatrix4x4Flag[6];
       int ScalingList8x8[2][64];
       int UseDefaultScalingMatrix8x8Flag[2];
    int second_chroma_qp_index_offset;
} pps_t;


/**
  Slice Header
  @see 7.3.3 Slice header syntax
  @see read_slice_header_rbsp
  @see write_slice_header_rbsp
  @see debug_slice_header_rbsp
*/
typedef struct
{
    int first_mb_in_slice;
    int slice_type;
    int pic_parameter_set_id;
    int colour_plane_id;
    int frame_num;
    int field_pic_flag;
    int bottom_field_flag;
    int idr_pic_id;
    int pic_order_cnt_lsb;
    int delta_pic_order_cnt_bottom;
    int delta_pic_order_cnt[ 2 ];
    int redundant_pic_cnt;
    int direct_spatial_mv_pred_flag;
    int num_ref_idx_active_override_flag;
    int num_ref_idx_l0_active_minus1;
    int num_ref_idx_l1_active_minus1;
    int cabac_init_idc;
    int slice_qp_delta;
    int sp_for_switch_flag;
    int slice_qs_delta;
    int disable_deblocking_filter_idc;
    int slice_alpha_c0_offset_div2;
    int slice_beta_offset_div2;
    int slice_group_change_cycle;


    struct
    {
        int luma_log2_weight_denom;
        int chroma_log2_weight_denom;
        int luma_weight_l0_flag[64];
        int luma_weight_l0[64];
        int luma_offset_l0[64];
        int chroma_weight_l0_flag[64];
        int chroma_weight_l0[64][2];
        int chroma_offset_l0[64][2];
        int luma_weight_l1_flag[64];
        int luma_weight_l1[64];
        int luma_offset_l1[64];
        int chroma_weight_l1_flag[64];
        int chroma_weight_l1[64][2];
        int chroma_offset_l1[64][2];
    } pwt; // predictive weight table

    // TODO check max index
    // TODO array of structs instead of struct of arrays
    struct
    {
        int ref_pic_list_reordering_flag_l0;
        struct
        {
            int reordering_of_pic_nums_idc[64];
            int abs_diff_pic_num_minus1[64];
            int long_term_pic_num[64];
        } reorder_l0;
        int ref_pic_list_reordering_flag_l1;
        struct
        {
            int reordering_of_pic_nums_idc[64];
            int abs_diff_pic_num_minus1[64];
            int long_term_pic_num[64];
        } reorder_l1;
    } rplr; // ref pic list reorder

    struct
    {
        int no_output_of_prior_pics_flag;
        int long_term_reference_flag;
        int adaptive_ref_pic_marking_mode_flag;
        int memory_management_control_operation[64];
        int difference_of_pic_nums_minus1[64];
        int long_term_pic_num[64];
        int long_term_frame_idx[64];
        int max_long_term_frame_idx_plus1[64];
    } drpm; // decoded ref pic marking

} slice_header_t;

/**
  Slice Header scalable extension
  @see G.7.3.3.4 Slice header in scalable extension syntax
  @see read_slice_header_in_scalable_extension
  @see write_slice_header_in_scalable_extension
  @see debug_slice_header_in_scalable_extension
*/
typedef struct
{
    bool base_pred_weight_table_flag;
    bool store_ref_base_pic_flag;
    int slice_group_change_cycle;
    int ref_layer_dq_id;
    int disable_inter_layer_deblocking_filter_idc;
    int inter_layer_slice_alpha_c0_offset_div2;
    int inter_layer_slice_beta_offset_div2;
    bool constrained_intra_resampling_flag;
    bool ref_layer_chroma_phase_x_plus1_flag;
    unsigned char ref_layer_chroma_phase_y_plus1;
    int scaled_ref_layer_left_offset;
    int scaled_ref_layer_top_offset;
    int scaled_ref_layer_right_offset;
    int scaled_ref_layer_bottom_offset;
    bool slice_skip_flag;
    int num_mbs_in_slice_minus1;
    bool adaptive_base_mode_flag;
    bool default_base_mode_flag;
    bool adaptive_motion_prediction_flag;
    bool default_motion_prediction_flag;
    bool adaptive_residual_prediction_flag;
    bool default_residual_prediction_flag;
    bool tcoeff_level_prediction_flag;
    unsigned char scan_idx_start;
    unsigned char scan_idx_end;
    
    //dec_ref_base_pic_marking
    bool adaptive_ref_base_pic_marking_mode_flag;
    int memory_management_base_control_operation;
    int difference_of_base_pic_nums_minus1;
    int long_term_base_pic_num;
} slice_header_svc_ext_t;


/**
   Access unit delimiter
   @see 7.3.1 NAL unit syntax
   @see read_nal_unit
   @see write_nal_unit
   @see debug_nal
*/
typedef struct
{
    int primary_pic_type;
} aud_t;

/**
   Network Abstraction Layer (NAL) unit header SVC extension
   @see G.7.3.1.1 NAL unit header SVC extension syntax
   @see read_nal_unit_header_svc_extension
   @see write_nal_unit_header_svc_extension
   @see debug_nal_unit_header_svc_extension
*/
typedef struct
{
    bool idr_flag;
    unsigned char priority_id;
    bool no_inter_layer_pred_flag;
    unsigned char dependency_id;
    unsigned char quality_id;
    unsigned char temporal_id;
    bool use_ref_base_pic_flag;
    bool discardable_flag;
    bool output_flag;
    unsigned char reserved_three_2bits;
} nal_svc_ext_t;

/**
    Prefix NAL unit SVC
    @see G.7.3.2.12.1 Prefix NAL unit SVC
    @see read_prefix_nal_unit_svc
    @see write_prefix_nal_unit_svc
*/
typedef struct
{
    bool store_ref_base_pic_flag;
    bool additional_prefix_nal_unit_extension_flag;
    bool additional_prefix_nal_unit_extension_data_flag;
    //dec_ref_base_pic_marking
    bool adaptive_ref_base_pic_marking_mode_flag;
    int memory_management_base_control_operation;
    int difference_of_base_pic_nums_minus1;
    int long_term_base_pic_num;
} prefix_nal_svc_t;
    
/**
   Network Abstraction Layer (NAL) unit
   @see 7.3.1 NAL unit syntax
   @see read_nal_unit
   @see write_nal_unit
   @see debug_nal
*/
typedef struct
{
    int forbidden_zero_bit;
    int nal_ref_idc;
    int nal_unit_type;
    bool svc_extension_flag;
    bool avc_3d_extension_flag;
    nal_svc_ext_t* nal_svc_ext;
    prefix_nal_svc_t* prefix_nal_svc;
    void* parsed; // FIXME
    int sizeof_parsed;

    //uint8_t* rbsp_buf;
    //int rbsp_size;
} nal_t;

typedef struct
{
    int _is_initialized;
    int sps_id;
    int initial_cpb_removal_delay;
    int initial_cpb_delay_offset;
} sei_buffering_t;

typedef struct
{
    int clock_timestamp_flag;
    int ct_type;
    int nuit_field_based_flag;
    int counting_type;
    int full_timestamp_flag;
    int discontinuity_flag;
    int cnt_dropped_flag;
    int n_frames;

    int seconds_value;
    int minutes_value;
    int hours_value;

    int seconds_flag;
    int minutes_flag;
    int hours_flag;

    int time_offset;
} picture_timestamp_t;

typedef struct
{
    int _is_initialized;
    int cpb_removal_delay;
    int dpb_output_delay;
    int pic_struct;
    picture_timestamp_t clock_timestamps[3]; // 3 is the maximum possible value
} sei_picture_timing_t;


typedef struct
{
    int rbsp_size;
    uint8_t* rbsp_buf;
} slice_data_rbsp_t;

/**
   H264 stream
   Contains data structures for all NAL types that can be handled by this library.  
   When reading, data is read into those, and when writing it is written from those.  
   The reason why they are all contained in one place is that some of them depend on others, we need to 
   have all of them available to read or write correctly.
 */
typedef struct
{
    nal_t* nal;
    sps_t* sps;
    sps_subset_t* sps_subset;  // refer to subset
    pps_t* pps;
    aud_t* aud;
    sei_t* sei; //This is a TEMP pointer at whats in h->seis...    
    int num_seis;
    slice_header_t* sh;
    slice_header_svc_ext_t* sh_svc_ext;
    
    slice_data_rbsp_t* slice_data;
    
    sps_t* sps_table[32];
    sps_subset_t* sps_subset_table[64];  //refer to base SPS
    pps_t* pps_table[256];
    sei_t** seis;

} h264_stream_t;

h264_stream_t* h264_new();
void h264_free(h264_stream_t* h);

int find_nal_unit(uint8_t* buf, int size, int* nal_start, int* nal_end);

int rbsp_to_nal(const uint8_t* rbsp_buf, const int* rbsp_size, uint8_t* nal_buf, int* nal_size);
int nal_to_rbsp(const uint8_t* nal_buf, int* nal_size, uint8_t* rbsp_buf, int* rbsp_size);

int read_nal_unit(h264_stream_t* h, uint8_t* buf, int size);
int peek_nal_unit(h264_stream_t* h, uint8_t* buf, int size);

void read_seq_parameter_set_rbsp(sps_t* sps, bs_t* b);
void read_scaling_list(bs_t* b, int* scalingList, int sizeOfScalingList, int* useDefaultScalingMatrixFlag );
void read_vui_parameters(sps_t* sps, bs_t* b);
void read_hrd_parameters(hrd_t* hrd, bs_t* b);

void read_pic_parameter_set_rbsp(h264_stream_t* h, bs_t* b);

void read_sei_rbsp(h264_stream_t* h, bs_t* b);
void read_sei_message(h264_stream_t* h, bs_t* b);
void read_access_unit_delimiter_rbsp(h264_stream_t* h, bs_t* b);
void read_end_of_seq_rbsp(h264_stream_t* h, bs_t* b);
void read_end_of_stream_rbsp(h264_stream_t* h, bs_t* b);
void read_filler_data_rbsp(h264_stream_t* h, bs_t* b);

void read_slice_layer_rbsp(h264_stream_t* h, bs_t* b);
void read_rbsp_slice_trailing_bits(h264_stream_t* h, bs_t* b);
void read_rbsp_trailing_bits(bs_t* b);
void read_slice_header(h264_stream_t* h, bs_t* b);
void read_ref_pic_list_reordering(h264_stream_t* h, bs_t* b);
void read_pred_weight_table(h264_stream_t* h, bs_t* b);
void read_dec_ref_pic_marking(h264_stream_t* h, bs_t* b);

int more_rbsp_trailing_data(h264_stream_t* h, bs_t* b);

int write_nal_unit(h264_stream_t* h, uint8_t* buf, int size);

void write_seq_parameter_set_rbsp(sps_t* sps, bs_t* b);
void write_scaling_list(bs_t* b, int* scalingList, int sizeOfScalingList, int* useDefaultScalingMatrixFlag );
void write_vui_parameters(sps_t* sps, bs_t* b);
void write_hrd_parameters(hrd_t* hrd, bs_t* b);

void write_pic_parameter_set_rbsp(h264_stream_t* h, bs_t* b);

void write_sei_rbsp(h264_stream_t* h, bs_t* b);
void write_sei_message(h264_stream_t* h, bs_t* b);
void write_access_unit_delimiter_rbsp(h264_stream_t* h, bs_t* b);
void write_end_of_seq_rbsp(h264_stream_t* h, bs_t* b);
void write_end_of_stream_rbsp(h264_stream_t* h, bs_t* b);
void write_filler_data_rbsp(h264_stream_t* h, bs_t* b);

void write_slice_layer_rbsp(h264_stream_t* h, bs_t* b);
void write_rbsp_slice_trailing_bits(h264_stream_t* h, bs_t* b);
void write_rbsp_trailing_bits(bs_t* b);
void write_slice_header(h264_stream_t* h, bs_t* b);
void write_ref_pic_list_reordering(h264_stream_t* h, bs_t* b);
void write_pred_weight_table(h264_stream_t* h, bs_t* b);
void write_dec_ref_pic_marking(h264_stream_t* h, bs_t* b);

int read_debug_nal_unit(h264_stream_t* h, uint8_t* buf, int size);

void debug_sps(sps_t* sps);
void debug_pps(pps_t* pps);
void debug_slice_header(slice_header_t* sh);
void debug_nal(h264_stream_t* h, nal_t* nal);

void debug_bytes(uint8_t* buf, int len);

void read_sei_payload( h264_stream_t* h, bs_t* b);
void read_debug_sei_payload( h264_stream_t* h, bs_t* b);
void write_sei_payload( h264_stream_t* h, bs_t* b);

//NAL ref idc codes
#define NAL_REF_IDC_PRIORITY_HIGHEST    3
#define NAL_REF_IDC_PRIORITY_HIGH       2
#define NAL_REF_IDC_PRIORITY_LOW        1
#define NAL_REF_IDC_PRIORITY_DISPOSABLE 0

//Table 7-1 NAL unit type codes
#define NAL_UNIT_TYPE_UNSPECIFIED                    0    // Unspecified
#define NAL_UNIT_TYPE_CODED_SLICE_NON_IDR            1    // Coded slice of a non-IDR picture
#define NAL_UNIT_TYPE_CODED_SLICE_DATA_PARTITION_A   2    // Coded slice data partition A
#define NAL_UNIT_TYPE_CODED_SLICE_DATA_PARTITION_B   3    // Coded slice data partition B
#define NAL_UNIT_TYPE_CODED_SLICE_DATA_PARTITION_C   4    // Coded slice data partition C
#define NAL_UNIT_TYPE_CODED_SLICE_IDR                5    // Coded slice of an IDR picture
#define NAL_UNIT_TYPE_SEI                            6    // Supplemental enhancement information (SEI)
#define NAL_UNIT_TYPE_SPS                            7    // Sequence parameter set
#define NAL_UNIT_TYPE_PPS                            8    // Picture parameter set
#define NAL_UNIT_TYPE_AUD                            9    // Access unit delimiter
#define NAL_UNIT_TYPE_END_OF_SEQUENCE               10    // End of sequence
#define NAL_UNIT_TYPE_END_OF_STREAM                 11    // End of stream
#define NAL_UNIT_TYPE_FILLER                        12    // Filler data
#define NAL_UNIT_TYPE_SPS_EXT                       13    // Sequence parameter set extension
#define NAL_UNIT_TYPE_PREFIX_NAL                    14    // Prefix NAL unit
#define NAL_UNIT_TYPE_SUBSET_SPS                    15    // Subset Sequence parameter set
#define NAL_UNIT_TYPE_DPS                           16    // Depth Parameter Set
                                             // 17..18    // Reserved
#define NAL_UNIT_TYPE_CODED_SLICE_AUX               19    // Coded slice of an auxiliary coded picture without partitioning
#define NAL_UNIT_TYPE_CODED_SLICE_SVC_EXTENSION     20    // Coded slice of SVC extension
                                             // 20..23    // Reserved
                                             // 24..31    // Unspecified

 

//7.4.3 Table 7-6. Name association to slice_type
#define SH_SLICE_TYPE_P        0        // P (P slice)
#define SH_SLICE_TYPE_B        1        // B (B slice)
#define SH_SLICE_TYPE_I        2        // I (I slice)
#define SH_SLICE_TYPE_EP       0        // EP (EP slice)
#define SH_SLICE_TYPE_EB       1        // EB (EB slice)
#define SH_SLICE_TYPE_EI       2        // EI (EI slice)
#define SH_SLICE_TYPE_SP       3        // SP (SP slice)
#define SH_SLICE_TYPE_SI       4        // SI (SI slice)
//as per footnote to Table 7-6, the *_ONLY slice types indicate that all other slices in that picture are of the same type
#define SH_SLICE_TYPE_P_ONLY    5        // P (P slice)
#define SH_SLICE_TYPE_B_ONLY    6        // B (B slice)
#define SH_SLICE_TYPE_I_ONLY    7        // I (I slice)
#define SH_SLICE_TYPE_EP_ONLY   5        // EP (EP slice)
#define SH_SLICE_TYPE_EB_ONLY   6        // EB (EB slice)
#define SH_SLICE_TYPE_EI_ONLY   7        // EI (EI slice)
#define SH_SLICE_TYPE_SP_ONLY   8        // SP (SP slice)
#define SH_SLICE_TYPE_SI_ONLY   9        // SI (SI slice)

//Appendix E. Table E-1  Meaning of sample aspect ratio indicator
#define SAR_Unspecified  0           // Unspecified
#define SAR_1_1        1             //  1:1
#define SAR_12_11      2             // 12:11
#define SAR_10_11      3             // 10:11
#define SAR_16_11      4             // 16:11
#define SAR_40_33      5             // 40:33
#define SAR_24_11      6             // 24:11
#define SAR_20_11      7             // 20:11
#define SAR_32_11      8             // 32:11
#define SAR_80_33      9             // 80:33
#define SAR_18_11     10             // 18:11
#define SAR_15_11     11             // 15:11
#define SAR_64_33     12             // 64:33
#define SAR_160_99    13             // 160:99
                                     // 14..254           Reserved
#define SAR_Extended      255        // Extended_SAR

//7.4.3.1 Table 7-7 reordering_of_pic_nums_idc operations for reordering of reference picture lists
#define RPLR_IDC_ABS_DIFF_ADD       0
#define RPLR_IDC_ABS_DIFF_SUBTRACT  1
#define RPLR_IDC_LONG_TERM          2
#define RPLR_IDC_END                3

//7.4.3.3 Table 7-9 Memory management control operation (memory_management_control_operation) values
#define MMCO_END                     0
#define MMCO_SHORT_TERM_UNUSED       1
#define MMCO_LONG_TERM_UNUSED        2
#define MMCO_SHORT_TERM_TO_LONG_TERM 3
#define MMCO_LONG_TERM_MAX_INDEX     4
#define MMCO_ALL_UNUSED              5
#define MMCO_CURRENT_TO_LONG_TERM    6

//7.4.2.4 Table 7-5 Meaning of primary_pic_type
#define AUD_PRIMARY_PIC_TYPE_I       0                // I
#define AUD_PRIMARY_PIC_TYPE_IP      1                // I, P
#define AUD_PRIMARY_PIC_TYPE_IPB     2                // I, P, B
#define AUD_PRIMARY_PIC_TYPE_SI      3                // SI
#define AUD_PRIMARY_PIC_TYPE_SISP    4                // SI, SP
#define AUD_PRIMARY_PIC_TYPE_ISI     5                // I, SI
#define AUD_PRIMARY_PIC_TYPE_ISIPSP  6                // I, SI, P, SP
#define AUD_PRIMARY_PIC_TYPE_ISIPSPB 7                // I, SI, P, SP, B

#define H264_PROFILE_BASELINE  66
#define H264_PROFILE_MAIN      77
#define H264_PROFILE_EXTENDED  88
#define H264_PROFILE_HIGH     100

// file handle for debug output
extern FILE* h264_dbgfile;

#ifdef __cplusplus
}
#endif

#endif
