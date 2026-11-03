/* 
 * h264bitstream - a library for reading and writing H.264 video
 * Copyright (C) 2005-2007 Auroras Entertainment, LLC
 * Copyright (C) 2008-2011 Avail-TVN
 * Copyright (C) 2012 Alex Izvorski
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
#include <stdlib.h>
#include <stdio.h>

#include "bs.h"
#include "h264_stream.h"
#include "h264_sei.h"

FILE* h264_dbgfile = NULL;

#define printf(...) fprintf((h264_dbgfile == NULL ? stdout : h264_dbgfile), __VA_ARGS__)

/** 
 Calculate the log base 2 of the argument, rounded up. 
 Zero or negative arguments return zero 
 Idea from http://www.southwindsgames.com/blog/2009/01/19/fast-integer-log2-function-in-cc/
 */
int intlog2(int x)
{
    int log = 0;
    if (x < 0) { x = 0; }
    while ((x >> log) > 0)
    {
        log++;
    }
    if (log > 0 && x == 1<<(log-1)) { log--; }
    return log;
}

int is_slice_type(int slice_type, int cmp_type)
{
    if (slice_type >= 5) { slice_type -= 5; }
    if (cmp_type >= 5) { cmp_type -= 5; }
    if (slice_type == cmp_type) { return 1; }
    else { return 0; }
}

int more_rbsp_data(bs_t* bs)
{
    // TODO this version handles reading only. writing version?

    // no more data
    if (bs_eof(bs)) { return 0; }

    // no rbsp_stop_bit yet
    if (bs_peek_u1(bs) == 0) { return 1; }

    // next bit is 1, is it the rsbp_stop_bit? only if the rest of bits are 0
    bs_t bs_tmp;
    bs_clone(&bs_tmp, bs);
    bs_skip_u1(&bs_tmp);
    while(!bs_eof(&bs_tmp))
    {
        // A later bit was 1, it wasn't the rsbp_stop_bit
        if (bs_read_u1(&bs_tmp) == 1) { return 1; }
    }

    // All following bits were 0, it was the rsbp_stop_bit
    return 0;
}

int more_rbsp_trailing_data(h264_stream_t* h, bs_t* b) { return !bs_eof(b); }

int _read_ff_coded_number(bs_t* b)
{
    int n1 = 0;
    int n2;
    do 
    {
        n2 = bs_read_u8(b);
        n1 += n2;
    } while (n2 == 0xff);
    return n1;
}

void _write_ff_coded_number(bs_t* b, int n)
{
    while (1)
    {
        if (n > 0xff)
        {
            bs_write_u8(b, 0xff);
            n -= 0xff;
        }
        else
        {
            bs_write_u8(b, n);
            break;
        }
    }
}

void debug_bytes(uint8_t* buf, int len)
{
    int i;
    for (i = 0; i < len; i++)
    {
        printf("%02X ", buf[i]);
        if ((i+1) % 16 == 0) { printf ("\n"); }
    }
    printf("\n");
}



void read_nal_unit_header_svc_extension(nal_svc_ext_t* nal_svc_ext, bs_t* b);
void read_prefix_nal_unit_svc(nal_t* nal, bs_t* b);
void read_prefix_nal_unit_rbsp(nal_t* nal, bs_t* b);
void read_seq_parameter_set_rbsp(sps_t* sps, bs_t* b);
void read_scaling_list(bs_t* b, int* scalingList, int sizeOfScalingList, int* useDefaultScalingMatrixFlag );
void read_subset_seq_parameter_set_rbsp(sps_subset_t* sps_subset, bs_t* b);
void read_seq_parameter_set_svc_extension(sps_subset_t* sps_subset, bs_t* b);
void read_svc_vui_parameters_extension(sps_svc_ext_t* sps_svc_ext, bs_t* b);
void read_vui_parameters(sps_t* sps, bs_t* b);
void read_hrd_parameters(hrd_t* hrd, bs_t* b);
void read_pic_parameter_set_rbsp(h264_stream_t* h, bs_t* b);
void read_sei_rbsp(h264_stream_t* h, bs_t* b);
void read_sei_message(h264_stream_t* h, bs_t* b);
void read_access_unit_delimiter_rbsp(h264_stream_t* h, bs_t* b);
void read_end_of_seq_rbsp(h264_stream_t* h, bs_t* b);
void read_end_of_stream_rbsp(h264_stream_t* h, bs_t* b);
void read_filler_data_rbsp(h264_stream_t* h, bs_t* b);
void read_slice_layer_rbsp(h264_stream_t* h,  bs_t* b);
void read_rbsp_slice_trailing_bits(h264_stream_t* h, bs_t* b);
void read_rbsp_trailing_bits(bs_t* b);
void read_slice_header(h264_stream_t* h, bs_t* b);
void read_ref_pic_list_reordering(h264_stream_t* h, bs_t* b);
void read_pred_weight_table(h264_stream_t* h, bs_t* b);
void read_dec_ref_pic_marking(h264_stream_t* h, bs_t* b);
void read_slice_header_in_scalable_extension(h264_stream_t* h, bs_t* b);
void read_dec_ref_base_pic_marking(nal_t* nal, bs_t* b);



//7.3.1 NAL unit syntax
int read_nal_unit(h264_stream_t* h, uint8_t* buf, int size)
{
    nal_t* nal = h->nal;

    int nal_size = size;
    int rbsp_size = size;
    uint8_t* rbsp_buf = (uint8_t*)calloc(1, rbsp_size);

    if( 1 )
    {
        int rc = nal_to_rbsp(buf, &nal_size, rbsp_buf, &rbsp_size);

        if (rc < 0) { free(rbsp_buf); return -1; } // handle conversion error
    }

    if( 0 )
    {
        rbsp_size = size*3/4; // NOTE this may have to be slightly smaller (3/4 smaller, worst case) in order to be guaranteed to fit
    }

    bs_t* b = bs_new(rbsp_buf, rbsp_size);
    /* forbidden_zero_bit */ bs_skip_u(b, 1);
    nal->nal_ref_idc = bs_read_u(b, 2);
    nal->nal_unit_type = bs_read_u(b, 5);
    
    if( nal->nal_unit_type == 14 || nal->nal_unit_type == 21 || nal->nal_unit_type == 20 )
    {
        if( nal->nal_unit_type != 21 )
        {
            nal->svc_extension_flag = bs_read_u1(b);
        }
        else
        {
            nal->avc_3d_extension_flag = bs_read_u1(b);
        }
        
        if( nal->svc_extension_flag )
        {
            read_nal_unit_header_svc_extension(nal->nal_svc_ext, b);
        }
    }

    switch ( nal->nal_unit_type )
    {
        case NAL_UNIT_TYPE_CODED_SLICE_IDR:
        case NAL_UNIT_TYPE_CODED_SLICE_NON_IDR:  
        case NAL_UNIT_TYPE_CODED_SLICE_AUX:
            read_slice_layer_rbsp(h, b);
            break;

#ifdef HAVE_SEI
        case NAL_UNIT_TYPE_SEI:
            read_sei_rbsp(h, b);
            read_rbsp_trailing_bits(b);
            break;
#endif

        case NAL_UNIT_TYPE_SPS: 
            read_seq_parameter_set_rbsp(h->sps, b);
            read_rbsp_trailing_bits(b);
            
            if( 1 )
            {
                memcpy(h->sps_table[h->sps->seq_parameter_set_id], h->sps, sizeof(sps_t));
            }

            break;

        case NAL_UNIT_TYPE_PPS:   
            read_pic_parameter_set_rbsp(h, b);
            read_rbsp_trailing_bits(b);
            break;

        case NAL_UNIT_TYPE_AUD:     
            read_access_unit_delimiter_rbsp(h, b); 
            read_rbsp_trailing_bits(b);
            break;

        case NAL_UNIT_TYPE_END_OF_SEQUENCE: 
            read_end_of_seq_rbsp(h, b);
            read_rbsp_trailing_bits(b);
            break;

        case NAL_UNIT_TYPE_END_OF_STREAM: 
            read_end_of_stream_rbsp(h, b);
            read_rbsp_trailing_bits(b);
            break;

        //SVC support
        case NAL_UNIT_TYPE_SUBSET_SPS:
            read_subset_seq_parameter_set_rbsp(h->sps_subset, b);
            read_rbsp_trailing_bits(b);
            
            if( 1 )
            {
                memcpy(h->sps_subset_table[h->sps_subset->sps->seq_parameter_set_id], h->sps_subset, sizeof(sps_subset_t));
                //memcpy(h->sps_subset_table[h->sps_subset->sps->seq_parameter_set_id]->sps, h->sps_subset->sps, sizeof(sps_t));
                //memcpy(h->sps_subset_table[h->sps_subset->sps->seq_parameter_set_id]->sps_svc_ext, h->sps_subset->sps_svc_ext, sizeof(sps_svc_ext_t));
                //h->sps_subset_table[h->sps_subset->sps->seq_parameter_set_id]->additional_extension2_flag = h->sps_subset->additional_extension2_flag;
            }

            break;
            
        //prefix NAL
        case NAL_UNIT_TYPE_PREFIX_NAL:
            read_prefix_nal_unit_rbsp(h->nal, b);
            read_rbsp_trailing_bits(b);
            break;
            
        //SVC support
        case NAL_UNIT_TYPE_CODED_SLICE_SVC_EXTENSION:            
            read_slice_layer_rbsp(h, b);
            
            break;
            
        case NAL_UNIT_TYPE_FILLER:
        case NAL_UNIT_TYPE_SPS_EXT:
        case NAL_UNIT_TYPE_UNSPECIFIED:
        case NAL_UNIT_TYPE_CODED_SLICE_DATA_PARTITION_A:  
        case NAL_UNIT_TYPE_CODED_SLICE_DATA_PARTITION_B: 
        case NAL_UNIT_TYPE_CODED_SLICE_DATA_PARTITION_C:
        default:
            bs_free(b);
            free(rbsp_buf);
            return -1;
    }

    if (bs_overrun(b)) { bs_free(b); free(rbsp_buf); return -1; }

    if( 0 )
    {
        // now get the actual size used
        rbsp_size = bs_pos(b);

        int rc = rbsp_to_nal(rbsp_buf, &rbsp_size, buf, &nal_size);
        if (rc < 0) { bs_free(b); free(rbsp_buf); return -1; }
    }

    bs_free(b);
    free(rbsp_buf);

    return nal_size;
}

//G.7.3.1.1 NAL unit header SVC extension syntax
void read_nal_unit_header_svc_extension(nal_svc_ext_t* nal_svc_ext, bs_t* b)
{
    nal_svc_ext->idr_flag = bs_read_u1(b);
    nal_svc_ext->priority_id = bs_read_u(b, 6);
    nal_svc_ext->no_inter_layer_pred_flag = bs_read_u1(b);
    nal_svc_ext->dependency_id = bs_read_u(b, 3);
    nal_svc_ext->quality_id = bs_read_u(b, 4);
    nal_svc_ext->temporal_id = bs_read_u(b, 3);
    nal_svc_ext->use_ref_base_pic_flag = bs_read_u1(b);
    nal_svc_ext->discardable_flag = bs_read_u1(b);
    nal_svc_ext->output_flag = bs_read_u1(b);
    nal_svc_ext->reserved_three_2bits = bs_read_u(b, 2);
}

//G.7.3.2.12.1 Prefix NAL unit SVC syntax
void read_prefix_nal_unit_svc(nal_t* nal, bs_t* b)
{
    if( nal->nal_ref_idc != 0 )
    {
        nal->prefix_nal_svc->store_ref_base_pic_flag = bs_read_u1(b);
        if( ( nal->nal_svc_ext->use_ref_base_pic_flag || nal->prefix_nal_svc->store_ref_base_pic_flag ) &&
             !nal->nal_svc_ext->idr_flag )
        {
            read_dec_ref_base_pic_marking( nal, b );
        }
        nal->prefix_nal_svc->additional_prefix_nal_unit_extension_flag = bs_read_u1(b);
        if( nal->prefix_nal_svc->additional_prefix_nal_unit_extension_flag )
        {
            while( more_rbsp_data( b ) )
            {
                nal->prefix_nal_svc->additional_prefix_nal_unit_extension_data_flag = bs_read_u1(b);
            }
        }
    }
    else if( more_rbsp_data( b ) )
    {
        while( more_rbsp_data( b ) )
        {
            nal->prefix_nal_svc->additional_prefix_nal_unit_extension_data_flag = bs_read_u1(b);
        }
    }
}

//7.3.2.12 Prefix NAL unit RBSP syntax
void read_prefix_nal_unit_rbsp(nal_t* nal, bs_t* b)
{
    if( nal->svc_extension_flag )
    {
        read_prefix_nal_unit_svc(nal, b);
    }
}

//7.3.2.1 Sequence parameter set RBSP syntax
void read_seq_parameter_set_rbsp(sps_t* sps, bs_t* b)
{
    int i;

    if( 1 )
    {
        memset(sps, 0, sizeof(sps_t));
        sps->chroma_format_idc = 1; 
    }
 
    sps->profile_idc = bs_read_u8(b);
    sps->constraint_set0_flag = bs_read_u1(b);
    sps->constraint_set1_flag = bs_read_u1(b);
    sps->constraint_set2_flag = bs_read_u1(b);
    sps->constraint_set3_flag = bs_read_u1(b);
    sps->constraint_set4_flag = bs_read_u1(b);
    sps->constraint_set5_flag = bs_read_u1(b);
    /* reserved_zero_2bits */ bs_skip_u(b, 2);
    sps->level_idc = bs_read_u8(b);
    sps->seq_parameter_set_id = bs_read_ue(b);

    if( sps->profile_idc == 100 || sps->profile_idc == 110 ||
        sps->profile_idc == 122 || sps->profile_idc == 244 ||
        sps->profile_idc == 44 || sps->profile_idc == 83 ||
        sps->profile_idc == 86 || sps->profile_idc == 118 ||
        sps->profile_idc == 128 || sps->profile_idc == 138 ||
        sps->profile_idc == 139 || sps->profile_idc == 134
       )
    {
        sps->chroma_format_idc = bs_read_ue(b);
        if( sps->chroma_format_idc == 3 )
        {
            sps->residual_colour_transform_flag = bs_read_u1(b);
        }
        sps->bit_depth_luma_minus8 = bs_read_ue(b);
        sps->bit_depth_chroma_minus8 = bs_read_ue(b);
        sps->qpprime_y_zero_transform_bypass_flag = bs_read_u1(b);
        sps->seq_scaling_matrix_present_flag = bs_read_u1(b);
        if( sps->seq_scaling_matrix_present_flag )
        {
            for( i = 0; i < ((sps->chroma_format_idc != 3) ? 8 : 12); i++ )
            {
                sps->seq_scaling_list_present_flag[ i ] = bs_read_u1(b);
                if( sps->seq_scaling_list_present_flag[ i ] )
                {
                    if( i < 6 )
                    {
                        read_scaling_list( b, sps->ScalingList4x4[ i ], 16,
                                                 &( sps->UseDefaultScalingMatrix4x4Flag[ i ] ) );
                    }
                    else
                    {
                        read_scaling_list( b, sps->ScalingList8x8[ i - 6 ], 64,
                                                 &( sps->UseDefaultScalingMatrix8x8Flag[ i - 6 ] ) );
                    }
                }
            }
        }
    }
    sps->log2_max_frame_num_minus4 = bs_read_ue(b);
    sps->pic_order_cnt_type = bs_read_ue(b);
    if( sps->pic_order_cnt_type == 0 )
    {
        sps->log2_max_pic_order_cnt_lsb_minus4 = bs_read_ue(b);
    }
    else if( sps->pic_order_cnt_type == 1 )
    {
        sps->delta_pic_order_always_zero_flag = bs_read_u1(b);
        sps->offset_for_non_ref_pic = bs_read_se(b);
        sps->offset_for_top_to_bottom_field = bs_read_se(b);
        sps->num_ref_frames_in_pic_order_cnt_cycle = bs_read_ue(b);
        for( i = 0; i < sps->num_ref_frames_in_pic_order_cnt_cycle; i++ )
        {
            sps->offset_for_ref_frame[ i ] = bs_read_se(b);
        }
    }
    sps->num_ref_frames = bs_read_ue(b);
    sps->gaps_in_frame_num_value_allowed_flag = bs_read_u1(b);
    sps->pic_width_in_mbs_minus1 = bs_read_ue(b);
    sps->pic_height_in_map_units_minus1 = bs_read_ue(b);
    sps->frame_mbs_only_flag = bs_read_u1(b);
    if( !sps->frame_mbs_only_flag )
    {
        sps->mb_adaptive_frame_field_flag = bs_read_u1(b);
    }
    sps->direct_8x8_inference_flag = bs_read_u1(b);
    sps->frame_cropping_flag = bs_read_u1(b);
    if( sps->frame_cropping_flag )
    {
        sps->frame_crop_left_offset = bs_read_ue(b);
        sps->frame_crop_right_offset = bs_read_ue(b);
        sps->frame_crop_top_offset = bs_read_ue(b);
        sps->frame_crop_bottom_offset = bs_read_ue(b);
    }
    sps->vui_parameters_present_flag = bs_read_u1(b);
    if( sps->vui_parameters_present_flag )
    {
        read_vui_parameters(sps, b);
    }
}

//7.3.2.1.1 Scaling list syntax
void read_scaling_list(bs_t* b, int* scalingList, int sizeOfScalingList, int* useDefaultScalingMatrixFlag )
{
    // NOTE need to be able to set useDefaultScalingMatrixFlag when reading, hence passing as pointer
    int lastScale = 8;
    int nextScale = 8;
    int delta_scale;
    for( int j = 0; j < sizeOfScalingList; j++ )
    {
        if( nextScale != 0 )
        {
            if( 0 )
            {
                nextScale = scalingList[ j ];
                if (useDefaultScalingMatrixFlag[0]) { nextScale = 0; }
                delta_scale = (nextScale - lastScale) % 256 ;
            }

            delta_scale = bs_read_se(b);

            if( 1 )
            {
                nextScale = ( lastScale + delta_scale + 256 ) % 256;
                useDefaultScalingMatrixFlag[0] = ( j == 0 && nextScale == 0 );
            }
        }
        if( 1 )
        {
            scalingList[ j ] = ( nextScale == 0 ) ? lastScale : nextScale;
        }
        lastScale = scalingList[ j ];
    }
}

//7.3.2.1.3 Subset sequence parameter set RBSP syntax
void read_subset_seq_parameter_set_rbsp(sps_subset_t* sps_subset, bs_t* b)
{
    read_seq_parameter_set_rbsp(sps_subset->sps, b);
    
    switch( sps_subset->sps->profile_idc )
    {
        case 83:
        case 86:
            read_seq_parameter_set_svc_extension(sps_subset, b); /* specified in Annex G */
            
            sps_svc_ext_t* sps_svc_ext = sps_subset->sps_svc_ext;
            sps_svc_ext->svc_vui_parameters_present_flag = bs_read_u1(b);
            
            if( sps_svc_ext->svc_vui_parameters_present_flag )
            {
                read_svc_vui_parameters_extension(sps_svc_ext,b); /* specified in Annex G */
            }
            break;
        default:
            break;
    }
    sps_subset->additional_extension2_flag = bs_read_u1(b);
    if( sps_subset->additional_extension2_flag )
    {
        while( more_rbsp_data( b ) )
        {
            sps_subset->additional_extension2_flag = bs_read_u1(b);
        }
    }
    
}

//Appendix G.7.3.2.1.4 Sequence parameter set SVC extension syntax
void read_seq_parameter_set_svc_extension(sps_subset_t* sps_subset, bs_t* b)
{
    sps_svc_ext_t* sps_svc_ext = sps_subset->sps_svc_ext;
    sps_svc_ext->inter_layer_deblocking_filter_control_present_flag = bs_read_u1(b);
    sps_svc_ext->extended_spatial_scalability_idc = bs_read_u(b, 2);
    if( sps_subset->sps->chroma_format_idc == 1 || sps_subset->sps->chroma_format_idc == 2 )
    {
        sps_svc_ext->chroma_phase_x_plus1_flag = bs_read_u1(b);
    }
    if( sps_subset->sps->chroma_format_idc == 1 )
    {
        sps_svc_ext->chroma_phase_y_plus1 = bs_read_u(b, 2);
    }
    if( sps_svc_ext->extended_spatial_scalability_idc )
    {
        if( sps_subset->sps->chroma_format_idc > 0 )
        {
            sps_svc_ext->seq_ref_layer_chroma_phase_x_plus1_flag = bs_read_u1(b);
            sps_svc_ext->seq_ref_layer_chroma_phase_y_plus1 = bs_read_u(b, 2);
        }
        sps_svc_ext->seq_scaled_ref_layer_left_offset = bs_read_se(b);
        sps_svc_ext->seq_scaled_ref_layer_top_offset = bs_read_se(b);
        sps_svc_ext->seq_scaled_ref_layer_right_offset = bs_read_se(b);
        sps_svc_ext->seq_scaled_ref_layer_bottom_offset = bs_read_se(b);
    }
    sps_svc_ext->seq_tcoeff_level_prediction_flag = bs_read_u1(b);
    if( sps_svc_ext->seq_tcoeff_level_prediction_flag )
    {
        sps_svc_ext->adaptive_tcoeff_level_prediction_flag = bs_read_u1(b);
    }
    sps_svc_ext->slice_header_restriction_flag = bs_read_u1(b);
}

//Appendix G.14.1 SVC VUI parameters extension syntax
void read_svc_vui_parameters_extension(sps_svc_ext_t* sps_svc_ext, bs_t* b)
{
    sps_svc_ext->vui.vui_ext_num_entries_minus1 = bs_read_ue(b);
    for( int i = 0; i <= sps_svc_ext->vui.vui_ext_num_entries_minus1; i++ )
    {
        sps_svc_ext->vui.vui_ext_dependency_id[i] = bs_read_u(b, 3);
        sps_svc_ext->vui.vui_ext_quality_id[i] = bs_read_u(b, 4);
        sps_svc_ext->vui.vui_ext_temporal_id[i] = bs_read_u(b, 3);
        sps_svc_ext->vui.vui_ext_timing_info_present_flag[i] = bs_read_u1(b);
        if( sps_svc_ext->vui.vui_ext_timing_info_present_flag[i] )
        {
            sps_svc_ext->vui.vui_ext_num_units_in_tick[i] = bs_read_u(b, 32);
            sps_svc_ext->vui.vui_ext_time_scale[i] = bs_read_u(b, 32);
            sps_svc_ext->vui.vui_ext_fixed_frame_rate_flag[i] = bs_read_u1(b);
        }

        sps_svc_ext->vui.vui_ext_nal_hrd_parameters_present_flag[i] = bs_read_u1(b);
        if( sps_svc_ext->vui.vui_ext_nal_hrd_parameters_present_flag[i] )
        {
            read_hrd_parameters(&sps_svc_ext->hrd_vcl[i], b);
        }
        sps_svc_ext->vui.vui_ext_vcl_hrd_parameters_present_flag[i] = bs_read_u1(b);
        if( sps_svc_ext->vui.vui_ext_vcl_hrd_parameters_present_flag[i] )
        {
            read_hrd_parameters(&sps_svc_ext->hrd_nal[i], b);
        }
        
        if( sps_svc_ext->vui.vui_ext_nal_hrd_parameters_present_flag[i] ||
            sps_svc_ext->vui.vui_ext_vcl_hrd_parameters_present_flag[i] )
        {
            sps_svc_ext->vui.vui_ext_low_delay_hrd_flag[i] = bs_read_u1(b);
        }
        sps_svc_ext->vui.vui_ext_pic_struct_present_flag[i] = bs_read_u1(b);
    }
}

//Appendix E.1.1 VUI parameters syntax
void read_vui_parameters(sps_t* sps, bs_t* b)
{
    sps->vui.aspect_ratio_info_present_flag = bs_read_u1(b);
    if( sps->vui.aspect_ratio_info_present_flag )
    {
        sps->vui.aspect_ratio_idc = bs_read_u8(b);
        if( sps->vui.aspect_ratio_idc == SAR_Extended )
        {
            sps->vui.sar_width = bs_read_u(b, 16);
            sps->vui.sar_height = bs_read_u(b, 16);
        }
    }
    sps->vui.overscan_info_present_flag = bs_read_u1(b);
    if( sps->vui.overscan_info_present_flag )
    {
        sps->vui.overscan_appropriate_flag = bs_read_u1(b);
    }
    sps->vui.video_signal_type_present_flag = bs_read_u1(b);
    if( sps->vui.video_signal_type_present_flag )
    {
        sps->vui.video_format = bs_read_u(b, 3);
        sps->vui.video_full_range_flag = bs_read_u1(b);
        sps->vui.colour_description_present_flag = bs_read_u1(b);
        if( sps->vui.colour_description_present_flag )
        {
            sps->vui.colour_primaries = bs_read_u8(b);
            sps->vui.transfer_characteristics = bs_read_u8(b);
            sps->vui.matrix_coefficients = bs_read_u8(b);
        }
    }
    sps->vui.chroma_loc_info_present_flag = bs_read_u1(b);
    if( sps->vui.chroma_loc_info_present_flag )
    {
        sps->vui.chroma_sample_loc_type_top_field = bs_read_ue(b);
        sps->vui.chroma_sample_loc_type_bottom_field = bs_read_ue(b);
    }
    sps->vui.timing_info_present_flag = bs_read_u1(b);
    if( sps->vui.timing_info_present_flag )
    {
        sps->vui.num_units_in_tick = bs_read_u(b, 32);
        sps->vui.time_scale = bs_read_u(b, 32);
        sps->vui.fixed_frame_rate_flag = bs_read_u1(b);
    }
    sps->vui.nal_hrd_parameters_present_flag = bs_read_u1(b);
    if( sps->vui.nal_hrd_parameters_present_flag )
    {
        read_hrd_parameters(&sps->hrd_nal, b);
    }
    sps->vui.vcl_hrd_parameters_present_flag = bs_read_u1(b);
    if( sps->vui.vcl_hrd_parameters_present_flag )
    {
        read_hrd_parameters(&sps->hrd_vcl, b);
    }
    if( sps->vui.nal_hrd_parameters_present_flag || sps->vui.vcl_hrd_parameters_present_flag )
    {
        sps->vui.low_delay_hrd_flag = bs_read_u1(b);
    }
    sps->vui.pic_struct_present_flag = bs_read_u1(b);
    sps->vui.bitstream_restriction_flag = bs_read_u1(b);
    if( sps->vui.bitstream_restriction_flag )
    {
        sps->vui.motion_vectors_over_pic_boundaries_flag = bs_read_u1(b);
        sps->vui.max_bytes_per_pic_denom = bs_read_ue(b);
        sps->vui.max_bits_per_mb_denom = bs_read_ue(b);
        sps->vui.log2_max_mv_length_horizontal = bs_read_ue(b);
        sps->vui.log2_max_mv_length_vertical = bs_read_ue(b);
        sps->vui.num_reorder_frames = bs_read_ue(b);
        sps->vui.max_dec_frame_buffering = bs_read_ue(b);
    }
}


//Appendix E.1.2 HRD parameters syntax
void read_hrd_parameters(hrd_t* hrd, bs_t* b)
{
    hrd->cpb_cnt_minus1 = bs_read_ue(b);
    hrd->bit_rate_scale = bs_read_u(b, 4);
    hrd->cpb_size_scale = bs_read_u(b, 4);
    for( int SchedSelIdx = 0; SchedSelIdx <= hrd->cpb_cnt_minus1; SchedSelIdx++ )
    {
        hrd->bit_rate_value_minus1[ SchedSelIdx ] = bs_read_ue(b);
        hrd->cpb_size_value_minus1[ SchedSelIdx ] = bs_read_ue(b);
        hrd->cbr_flag[ SchedSelIdx ] = bs_read_u1(b);
    }
    hrd->initial_cpb_removal_delay_length_minus1 = bs_read_u(b, 5);
    hrd->cpb_removal_delay_length_minus1 = bs_read_u(b, 5);
    hrd->dpb_output_delay_length_minus1 = bs_read_u(b, 5);
    hrd->time_offset_length = bs_read_u(b, 5);
}


/*
UNIMPLEMENTED
//7.3.2.1.2 Sequence parameter set extension RBSP syntax
int read_seq_parameter_set_extension_rbsp(bs_t* b, sps_ext_t* sps_ext) {
    seq_parameter_set_id = bs_read_ue(b);
    aux_format_idc = bs_read_ue(b);
    if( aux_format_idc != 0 ) {
        bit_depth_aux_minus8 = bs_read_ue(b);
        alpha_incr_flag = bs_read_u1(b);
        alpha_opaque_value = bs_read_u(v);
        alpha_transparent_value = bs_read_u(v);
    }
    additional_extension_flag = bs_read_u1(b);
    read_rbsp_trailing_bits();
}
*/

//7.3.2.2 Picture parameter set RBSP syntax
void read_pic_parameter_set_rbsp(h264_stream_t* h, bs_t* b)
{
    pps_t* pps = h->pps;
    if( 1 )
    {
        memset(pps, 0, sizeof(pps_t));
    }

    pps->pic_parameter_set_id = bs_read_ue(b);
    pps->seq_parameter_set_id = bs_read_ue(b);
    pps->entropy_coding_mode_flag = bs_read_u1(b);
    pps->pic_order_present_flag = bs_read_u1(b);
    pps->num_slice_groups_minus1 = bs_read_ue(b);

    if( pps->num_slice_groups_minus1 > 0 )
    {
        pps->slice_group_map_type = bs_read_ue(b);
        if( pps->slice_group_map_type == 0 )
        {
            for( int i_group = 0; i_group <= pps->num_slice_groups_minus1; i_group++ )
            {
                pps->run_length_minus1[ i_group ] = bs_read_ue(b);
            }
        }
        else if( pps->slice_group_map_type == 2 )
        {
            for( int i_group = 0; i_group < pps->num_slice_groups_minus1; i_group++ )
            {
                pps->top_left[ i_group ] = bs_read_ue(b);
                pps->bottom_right[ i_group ] = bs_read_ue(b);
            }
        }
        else if( pps->slice_group_map_type == 3 ||
                 pps->slice_group_map_type == 4 ||
                 pps->slice_group_map_type == 5 )
        {
            pps->slice_group_change_direction_flag = bs_read_u1(b);
            pps->slice_group_change_rate_minus1 = bs_read_ue(b);
        }
        else if( pps->slice_group_map_type == 6 )
        {
            pps->pic_size_in_map_units_minus1 = bs_read_ue(b);
            for( int i = 0; i <= pps->pic_size_in_map_units_minus1; i++ )
            {
                int v = intlog2( pps->num_slice_groups_minus1 + 1 );
                pps->slice_group_id[ i ] = bs_read_u(b, v);
            }
        }
    }
    pps->num_ref_idx_l0_active_minus1 = bs_read_ue(b);
    pps->num_ref_idx_l1_active_minus1 = bs_read_ue(b);
    pps->weighted_pred_flag = bs_read_u1(b);
    pps->weighted_bipred_idc = bs_read_u(b, 2);
    pps->pic_init_qp_minus26 = bs_read_se(b);
    pps->pic_init_qs_minus26 = bs_read_se(b);
    pps->chroma_qp_index_offset = bs_read_se(b);
    pps->deblocking_filter_control_present_flag = bs_read_u1(b);
    pps->constrained_intra_pred_flag = bs_read_u1(b);
    pps->redundant_pic_cnt_present_flag = bs_read_u1(b);

    int have_more_data = 0;
    if( 1 ) { have_more_data = more_rbsp_data(b); }
    if( 0 )
    {
        have_more_data = pps->transform_8x8_mode_flag | pps->pic_scaling_matrix_present_flag | pps->second_chroma_qp_index_offset != 0;
    }

    if( have_more_data )
    {
        pps->transform_8x8_mode_flag = bs_read_u1(b);
        pps->pic_scaling_matrix_present_flag = bs_read_u1(b);
        if( pps->pic_scaling_matrix_present_flag )
        {
            for( int i = 0; i < 6 + 2* pps->transform_8x8_mode_flag; i++ )
            {
                pps->pic_scaling_list_present_flag[ i ] = bs_read_u1(b);
                if( pps->pic_scaling_list_present_flag[ i ] )
                {
                    if( i < 6 )
                    {
                        read_scaling_list( b, pps->ScalingList4x4[ i ], 16,
                                                 &( pps->UseDefaultScalingMatrix4x4Flag[ i ] ) );
                    }
                    else
                    {
                        read_scaling_list( b, pps->ScalingList8x8[ i - 6 ], 64,
                                                 &( pps->UseDefaultScalingMatrix8x8Flag[ i - 6 ] ) );
                    }
                }
            }
        }
        pps->second_chroma_qp_index_offset = bs_read_se(b);
    }

    if( 1 )
    {
        memcpy(h->pps_table[pps->pic_parameter_set_id], h->pps, sizeof(pps_t));
    }
}

#ifdef HAVE_SEI
//7.3.2.3 Supplemental enhancement information RBSP syntax
void read_sei_rbsp(h264_stream_t* h, bs_t* b)
{
    if( 1 )
    {
        for( int i = 0; i < h->num_seis; i++ )
        {
            sei_free(h->seis[i]);
        }
    
        h->num_seis = 0;
        do {
            h->num_seis++;
            h->seis = (sei_t**)realloc(h->seis, h->num_seis * sizeof(sei_t*));
            h->seis[h->num_seis - 1] = sei_new();
            h->sei = h->seis[h->num_seis - 1];
            read_sei_message(h, b);
        } while( more_rbsp_data(b) );
    }

    if( 0 )
    {
        for (int i = 0; i < h->num_seis; i++)
        {
            h->sei = h->seis[i];
            read_sei_message(h, b);
        }
        h->sei = NULL;
    }
}

//7.3.2.3.1 Supplemental enhancement information message syntax
void read_sei_message(h264_stream_t* h, bs_t* b)
{
    if( 0 )
    {
        _write_ff_coded_number(b, h->sei->payloadType);
        _write_ff_coded_number(b, h->sei->payloadSize);
    }
    if( 1 )
    {
        h->sei->payloadType = _read_ff_coded_number(b);
        h->sei->payloadSize = _read_ff_coded_number(b);
    }
    read_sei_payload( h, b );
}
#endif

//7.3.2.4 Access unit delimiter RBSP syntax
void read_access_unit_delimiter_rbsp(h264_stream_t* h, bs_t* b)
{
    h->aud->primary_pic_type = bs_read_u(b, 3);
}

//7.3.2.5 End of sequence RBSP syntax
void read_end_of_seq_rbsp(h264_stream_t* h, bs_t* b)
{
}

//7.3.2.6 End of stream RBSP syntax
void read_end_of_stream_rbsp(h264_stream_t* h, bs_t* b)
{
}

//7.3.2.7 Filler data RBSP syntax
void read_filler_data_rbsp(h264_stream_t* h, bs_t* b)
{
    while( bs_next_bits(b, 8) == 0xFF )
    {
        /* ff_byte */ bs_skip_u(b, 8);
    }
}

//7.3.2.8 Slice layer without partitioning RBSP syntax
void read_slice_layer_rbsp(h264_stream_t* h,  bs_t* b)
{
    if (h->nal->nal_unit_type != NAL_UNIT_TYPE_CODED_SLICE_SVC_EXTENSION)
        read_slice_header(h, b);
    else
        read_slice_header_in_scalable_extension(h, b);
    
    slice_data_rbsp_t* slice_data = h->slice_data;

    if ( slice_data != NULL )
    {
        if ( slice_data->rbsp_buf != NULL ) free( slice_data->rbsp_buf ); 
        uint8_t *sptr = b->p + (!!b->bits_left); // CABAC-specific: skip alignment bits, if there are any
        slice_data->rbsp_size = b->end - sptr;
        
        slice_data->rbsp_buf = (uint8_t*)malloc(slice_data->rbsp_size);
        memcpy( slice_data->rbsp_buf, sptr, slice_data->rbsp_size );
        // ugly hack: since next NALU starts at byte border, we are going to be padded by trailing_bits;
        return;
    }

    // FIXME should read or skip data
    //slice_data( ); /* all categories of slice_data( ) syntax */
    read_rbsp_slice_trailing_bits(h, b);
}

/*
// UNIMPLEMENTED
//7.3.2.9.1 Slice data partition A RBSP syntax
slice_data_partition_a_layer_rbsp( ) {
    read_slice_header( );             // only category 2
    slice_id = bs_read_ue(b)
    read_slice_data( );               // only category 2
    read_rbsp_slice_trailing_bits( ); // only category 2
}

//7.3.2.9.2 Slice data partition B RBSP syntax
slice_data_partition_b_layer_rbsp( ) {
    slice_id = bs_read_ue(b);    // only category 3
    if( redundant_pic_cnt_present_flag )
        redundant_pic_cnt = bs_read_ue(b);
    read_slice_data( );               // only category 3
    read_rbsp_slice_trailing_bits( ); // only category 3
}

//7.3.2.9.3 Slice data partition C RBSP syntax
slice_data_partition_c_layer_rbsp( ) {
    slice_id = bs_read_ue(b);    // only category 4
    if( redundant_pic_cnt_present_flag )
        redundant_pic_cnt = bs_read_ue(b);
    read_slice_data( );               // only category 4
    rbsp_slice_trailing_bits( ); // only category 4
}
*/

//7.3.2.10 RBSP slice trailing bits syntax
void read_rbsp_slice_trailing_bits(h264_stream_t* h, bs_t* b)
{
    read_rbsp_trailing_bits(b);
    if( h->pps->entropy_coding_mode_flag )
    {
        while( more_rbsp_trailing_data(h, b) )
        {
            /* cabac_zero_word */ bs_skip_u(b, 16);
        }
    }
}

//7.3.2.11 RBSP trailing bits syntax
void read_rbsp_trailing_bits(bs_t* b)
{
    /* rbsp_stop_one_bit */ bs_skip_u(b, 1);

    while( !bs_byte_aligned(b) )
    {
        /* rbsp_alignment_zero_bit */ bs_skip_u(b, 1);
    }
}

//7.3.3 Slice header syntax
void read_slice_header(h264_stream_t* h, bs_t* b)
{
    slice_header_t* sh = h->sh;
    if( 1 )
    {
        memset(sh, 0, sizeof(slice_header_t));
    }

    nal_t* nal = h->nal;

    sh->first_mb_in_slice = bs_read_ue(b);
    sh->slice_type = bs_read_ue(b);
    sh->pic_parameter_set_id = bs_read_ue(b);

    // TODO check existence, otherwise fail
    pps_t* pps = h->pps;
    sps_t* sps = h->sps;
    memcpy(h->pps, h->pps_table[sh->pic_parameter_set_id], sizeof(pps_t));
    memcpy(h->sps, h->sps_table[pps->seq_parameter_set_id], sizeof(sps_t));

    if (sps->residual_colour_transform_flag)
    {
        sh->colour_plane_id = bs_read_u(b, 2);
    }
    
    sh->frame_num = bs_read_u(b, sps->log2_max_frame_num_minus4 + 4 ); // was u(v)
    if( !sps->frame_mbs_only_flag )
    {
        sh->field_pic_flag = bs_read_u1(b);
        if( sh->field_pic_flag )
        {
            sh->bottom_field_flag = bs_read_u1(b);
        }
    }
    if( nal->nal_unit_type == 5 )
    {
        sh->idr_pic_id = bs_read_ue(b);
    }
    if( sps->pic_order_cnt_type == 0 )
    {
        sh->pic_order_cnt_lsb = bs_read_u(b, sps->log2_max_pic_order_cnt_lsb_minus4 + 4 ); // was u(v)
        if( pps->pic_order_present_flag && !sh->field_pic_flag )
        {
            sh->delta_pic_order_cnt_bottom = bs_read_se(b);
        }
    }
    if( sps->pic_order_cnt_type == 1 && !sps->delta_pic_order_always_zero_flag )
    {
        sh->delta_pic_order_cnt[ 0 ] = bs_read_se(b);
        if( pps->pic_order_present_flag && !sh->field_pic_flag )
        {
            sh->delta_pic_order_cnt[ 1 ] = bs_read_se(b);
        }
    }
    if( pps->redundant_pic_cnt_present_flag )
    {
        sh->redundant_pic_cnt = bs_read_ue(b);
    }
    if( is_slice_type( sh->slice_type, SH_SLICE_TYPE_B ) )
    {
        sh->direct_spatial_mv_pred_flag = bs_read_u1(b);
    }
    if( is_slice_type( sh->slice_type, SH_SLICE_TYPE_P ) || is_slice_type( sh->slice_type, SH_SLICE_TYPE_SP ) || is_slice_type( sh->slice_type, SH_SLICE_TYPE_B ) )
    {
        sh->num_ref_idx_active_override_flag = bs_read_u1(b);
        if( sh->num_ref_idx_active_override_flag )
        {
            sh->num_ref_idx_l0_active_minus1 = bs_read_ue(b); // FIXME does this modify the pps?
            if( is_slice_type( sh->slice_type, SH_SLICE_TYPE_B ) )
            {
                sh->num_ref_idx_l1_active_minus1 = bs_read_ue(b);
            }
        }
    }
    read_ref_pic_list_reordering(h, b);
    if( ( pps->weighted_pred_flag && ( is_slice_type( sh->slice_type, SH_SLICE_TYPE_P ) || is_slice_type( sh->slice_type, SH_SLICE_TYPE_SP ) ) ) ||
        ( pps->weighted_bipred_idc == 1 && is_slice_type( sh->slice_type, SH_SLICE_TYPE_B ) ) )
    {
        read_pred_weight_table(h, b);
    }
    if( nal->nal_ref_idc != 0 )
    {
        read_dec_ref_pic_marking(h, b);
    }
    if( pps->entropy_coding_mode_flag && ! is_slice_type( sh->slice_type, SH_SLICE_TYPE_I ) && ! is_slice_type( sh->slice_type, SH_SLICE_TYPE_SI ) )
    {
        sh->cabac_init_idc = bs_read_ue(b);
    }
    sh->slice_qp_delta = bs_read_se(b);
    if( is_slice_type( sh->slice_type, SH_SLICE_TYPE_SP ) || is_slice_type( sh->slice_type, SH_SLICE_TYPE_SI ) )
    {
        if( is_slice_type( sh->slice_type, SH_SLICE_TYPE_SP ) )
        {
            sh->sp_for_switch_flag = bs_read_u1(b);
        }
        sh->slice_qs_delta = bs_read_se(b);
    }
    if( pps->deblocking_filter_control_present_flag )
    {
        sh->disable_deblocking_filter_idc = bs_read_ue(b);
        if( sh->disable_deblocking_filter_idc != 1 )
        {
            sh->slice_alpha_c0_offset_div2 = bs_read_se(b);
            sh->slice_beta_offset_div2 = bs_read_se(b);
        }
    }
    if( pps->num_slice_groups_minus1 > 0 &&
        pps->slice_group_map_type >= 3 && pps->slice_group_map_type <= 5)
    {
        int v = intlog2( pps->pic_size_in_map_units_minus1 +  pps->slice_group_change_rate_minus1 + 1 );
        sh->slice_group_change_cycle = bs_read_u(b, v); // FIXME add 2?
    }
}

//7.3.3.1 Reference picture list reordering syntax
void read_ref_pic_list_reordering(h264_stream_t* h, bs_t* b)
{
    slice_header_t* sh = h->sh;
    // FIXME should be an array

    if( ! is_slice_type( sh->slice_type, SH_SLICE_TYPE_I ) && ! is_slice_type( sh->slice_type, SH_SLICE_TYPE_SI ) )
    {
        sh->rplr.ref_pic_list_reordering_flag_l0 = bs_read_u1(b);
        if( sh->rplr.ref_pic_list_reordering_flag_l0 )
        {
            int n = -1;
            do
            {
                n++;
                sh->rplr.reorder_l0.reordering_of_pic_nums_idc[ n ] = bs_read_ue(b);
                if( sh->rplr.reorder_l0.reordering_of_pic_nums_idc[ n ] == 0 ||
                    sh->rplr.reorder_l0.reordering_of_pic_nums_idc[ n ] == 1 )
                {
                    sh->rplr.reorder_l0.abs_diff_pic_num_minus1[ n ] = bs_read_ue(b);
                }
                else if( sh->rplr.reorder_l0.reordering_of_pic_nums_idc[ n ] == 2 )
                {
                    sh->rplr.reorder_l0.long_term_pic_num[ n ] = bs_read_ue(b);
                }
            } while( sh->rplr.reorder_l0.reordering_of_pic_nums_idc[ n ] != 3 && ! bs_eof(b) );
        }
    }
    if( is_slice_type( sh->slice_type, SH_SLICE_TYPE_B ) )
    {
        sh->rplr.ref_pic_list_reordering_flag_l1 = bs_read_u1(b);
        if( sh->rplr.ref_pic_list_reordering_flag_l1 )
        {
            int n = -1;
            do
            {
                n++;
                sh->rplr.reorder_l1.reordering_of_pic_nums_idc[ n ] = bs_read_ue(b);
                if( sh->rplr.reorder_l1.reordering_of_pic_nums_idc[ n ] == 0 ||
                    sh->rplr.reorder_l1.reordering_of_pic_nums_idc[ n ] == 1 )
                {
                    sh->rplr.reorder_l1.abs_diff_pic_num_minus1[ n ] = bs_read_ue(b);
                }
                else if( sh->rplr.reorder_l1.reordering_of_pic_nums_idc[ n ] == 2 )
                {
                    sh->rplr.reorder_l1.long_term_pic_num[ n ] = bs_read_ue(b);
                }
            } while( sh->rplr.reorder_l1.reordering_of_pic_nums_idc[ n ] != 3 && ! bs_eof(b) );
        }
    }
}

//7.3.3.2 Prediction weight table syntax
void read_pred_weight_table(h264_stream_t* h, bs_t* b)
{
    slice_header_t* sh = h->sh;
    sps_t* sps = h->sps;
    pps_t* pps = h->pps;

    int i, j;

    sh->pwt.luma_log2_weight_denom = bs_read_ue(b);
    if( sps->chroma_format_idc != 0 )
    {
        sh->pwt.chroma_log2_weight_denom = bs_read_ue(b);
    }
    for( i = 0; i <= pps->num_ref_idx_l0_active_minus1; i++ )
    {
        sh->pwt.luma_weight_l0_flag[i] = bs_read_u1(b);
        if( sh->pwt.luma_weight_l0_flag[i] )
        {
            sh->pwt.luma_weight_l0[ i ] = bs_read_se(b);
            sh->pwt.luma_offset_l0[ i ] = bs_read_se(b);
        }
        if ( sps->chroma_format_idc != 0 )
        {
            sh->pwt.chroma_weight_l0_flag[i] = bs_read_u1(b);
            if( sh->pwt.chroma_weight_l0_flag[i] )
            {
                for( j =0; j < 2; j++ )
                {
                    sh->pwt.chroma_weight_l0[ i ][ j ] = bs_read_se(b);
                    sh->pwt.chroma_offset_l0[ i ][ j ] = bs_read_se(b);
                }
            }
        }
    }
    if( is_slice_type( sh->slice_type, SH_SLICE_TYPE_B ) )
    {
        for( i = 0; i <= pps->num_ref_idx_l1_active_minus1; i++ )
        {
            sh->pwt.luma_weight_l1_flag[i] = bs_read_u1(b);
            if( sh->pwt.luma_weight_l1_flag[i] )
            {
                sh->pwt.luma_weight_l1[ i ] = bs_read_se(b);
                sh->pwt.luma_offset_l1[ i ] = bs_read_se(b);
            }
            if( sps->chroma_format_idc != 0 )
            {
                sh->pwt.chroma_weight_l1_flag[i] = bs_read_u1(b);
                if( sh->pwt.chroma_weight_l1_flag[i] )
                {
                    for( j = 0; j < 2; j++ )
                    {
                        sh->pwt.chroma_weight_l1[ i ][ j ] = bs_read_se(b);
                        sh->pwt.chroma_offset_l1[ i ][ j ] = bs_read_se(b);
                    }
                }
            }
        }
    }
}

//7.3.3.3 Decoded reference picture marking syntax
void read_dec_ref_pic_marking(h264_stream_t* h, bs_t* b)
{
    slice_header_t* sh = h->sh;
    // FIXME should be an array

    if( h->nal->nal_unit_type == 5 )
    {
        sh->drpm.no_output_of_prior_pics_flag = bs_read_u1(b);
        sh->drpm.long_term_reference_flag = bs_read_u1(b);
    }
    else
    {
        sh->drpm.adaptive_ref_pic_marking_mode_flag = bs_read_u1(b);
        if( sh->drpm.adaptive_ref_pic_marking_mode_flag )
        {
            int n = -1;
            do
            {
                n++;
                sh->drpm.memory_management_control_operation[ n ] = bs_read_ue(b);
                if( sh->drpm.memory_management_control_operation[ n ] == 1 ||
                    sh->drpm.memory_management_control_operation[ n ] == 3 )
                {
                    sh->drpm.difference_of_pic_nums_minus1[ n ] = bs_read_ue(b);
                }
                if(sh->drpm.memory_management_control_operation[ n ] == 2 )
                {
                    sh->drpm.long_term_pic_num[ n ] = bs_read_ue(b);
                }
                if( sh->drpm.memory_management_control_operation[ n ] == 3 ||
                    sh->drpm.memory_management_control_operation[ n ] == 6 )
                {
                    sh->drpm.long_term_frame_idx[ n ] = bs_read_ue(b);
                }
                if( sh->drpm.memory_management_control_operation[ n ] == 4 )
                {
                    sh->drpm.max_long_term_frame_idx_plus1[ n ] = bs_read_ue(b);
                }
            } while( sh->drpm.memory_management_control_operation[ n ] != 0 && ! bs_eof(b) );
        }
    }
}

//G.7.3.3.4 Slice header in scalable extension syntax
void read_slice_header_in_scalable_extension(h264_stream_t* h, bs_t* b)
{
    slice_header_t* sh = h->sh;
    slice_header_svc_ext_t* sh_svc_ext = h->sh_svc_ext;
    if( 1 )
    {
        memset(sh, 0, sizeof(slice_header_t));
        memset(sh_svc_ext, 0, sizeof(slice_header_svc_ext_t));
    }
    
    nal_t* nal = h->nal;
    
    sh->first_mb_in_slice = bs_read_ue(b);
    sh->slice_type = bs_read_ue(b);
    sh->pic_parameter_set_id = bs_read_ue(b);
    
    // TODO check existence, otherwise fail
    pps_t* pps = h->pps;
    sps_subset_t* sps_subset = h->sps_subset;
    memcpy(h->pps, h->pps_table[sh->pic_parameter_set_id], sizeof(pps_t));
    memcpy(sps_subset, h->sps_subset_table[pps->seq_parameter_set_id], sizeof(sps_subset_t));
    //memcpy(h->sps_subset->sps, h->sps_subset_table[pps->seq_parameter_set_id]->sps, sizeof(sps_t));
    //memcpy(h->sps_subset->sps_svc_ext, h->sps_subset_table[pps->seq_parameter_set_id]->sps_svc_ext, sizeof(sps_svc_ext_t));
    
    if (sps_subset->sps->residual_colour_transform_flag)
    {
        sh->colour_plane_id = bs_read_u(b, 2);
    }
    
    sh->frame_num = bs_read_u(b, sps_subset->sps->log2_max_frame_num_minus4 + 4 ); // was u(v)
    if( !sps_subset->sps->frame_mbs_only_flag )
    {
        sh->field_pic_flag = bs_read_u1(b);
        if( sh->field_pic_flag )
        {
            sh->bottom_field_flag = bs_read_u1(b);
        }
    }
    if( nal->nal_unit_type == 5 )
    {
        sh->idr_pic_id = bs_read_ue(b);
    }
    if( sps_subset->sps->pic_order_cnt_type == 0 )
    {
        sh->pic_order_cnt_lsb = bs_read_u(b, sps_subset->sps->log2_max_pic_order_cnt_lsb_minus4 + 4 ); // was u(v)
        if( pps->pic_order_present_flag && !sh->field_pic_flag )
        {
            sh->delta_pic_order_cnt_bottom = bs_read_se(b);
        }
    }
    if( sps_subset->sps->pic_order_cnt_type == 1 && !sps_subset->sps->delta_pic_order_always_zero_flag )
    {
        sh->delta_pic_order_cnt[ 0 ] = bs_read_se(b);
        if( pps->pic_order_present_flag && !sh->field_pic_flag )
        {
            sh->delta_pic_order_cnt[ 1 ] = bs_read_se(b);
        }
    }
    if( pps->redundant_pic_cnt_present_flag )
    {
        sh->redundant_pic_cnt = bs_read_ue(b);
    }
    if( nal->nal_svc_ext->quality_id == 0)
    {
        if( is_slice_type( sh->slice_type, SH_SLICE_TYPE_EB ) )
        {
            sh->direct_spatial_mv_pred_flag = bs_read_u1(b);
        }
        if( is_slice_type( sh->slice_type, SH_SLICE_TYPE_EP ) ||
            is_slice_type( sh->slice_type, SH_SLICE_TYPE_EB ) )
        {
            sh->num_ref_idx_active_override_flag = bs_read_u1(b);
            if( sh->num_ref_idx_active_override_flag )
            {
                sh->num_ref_idx_l0_active_minus1 = bs_read_ue(b); // FIXME does this modify the pps?
                if( is_slice_type( sh->slice_type, SH_SLICE_TYPE_EB ) )
                {
                    sh->num_ref_idx_l1_active_minus1 = bs_read_ue(b);
                }
            }
        }
        read_ref_pic_list_reordering(h, b);
        if( ( pps->weighted_pred_flag       && is_slice_type( sh->slice_type, SH_SLICE_TYPE_EP ) ) ||
            ( pps->weighted_bipred_idc == 1 && is_slice_type( sh->slice_type, SH_SLICE_TYPE_EB ) ) )
        {
            //svc specific
            if( !nal->nal_svc_ext->no_inter_layer_pred_flag )
            {
                sh_svc_ext->base_pred_weight_table_flag = bs_read_u1(b);
            }
            if( nal->nal_svc_ext->no_inter_layer_pred_flag || !sh_svc_ext->base_pred_weight_table_flag )
            {
                read_pred_weight_table(h, b);
            }
        }
        if( nal->nal_ref_idc != 0 )
        {
            read_dec_ref_pic_marking(h, b);
            
            //svc specific
            if( !sps_subset->sps_svc_ext->slice_header_restriction_flag )
            {
                sh_svc_ext->store_ref_base_pic_flag = bs_read_u1(b);
                if( ( nal->nal_svc_ext->use_ref_base_pic_flag || sh_svc_ext->store_ref_base_pic_flag ) &&
                   ( nal->nal_unit_type != 5 ) )
                {
                    read_dec_ref_base_pic_marking(nal, b);
                }
            }
        }
    }
    
    if( pps->entropy_coding_mode_flag && ! is_slice_type( sh->slice_type, SH_SLICE_TYPE_EI ) )
    {
        sh->cabac_init_idc = bs_read_ue(b);
    }
    sh->slice_qp_delta = bs_read_se(b);
    if( pps->deblocking_filter_control_present_flag )
    {
        sh->disable_deblocking_filter_idc = bs_read_ue(b);
        if( sh->disable_deblocking_filter_idc != 1 )
        {
            sh->slice_alpha_c0_offset_div2 = bs_read_se(b);
            sh->slice_beta_offset_div2 = bs_read_se(b);
        }
    }
    if( pps->num_slice_groups_minus1 > 0 &&
       pps->slice_group_map_type >= 3 && pps->slice_group_map_type <= 5)
    {
        int v = intlog2( pps->pic_size_in_map_units_minus1 +  pps->slice_group_change_rate_minus1 + 1 );
        sh->slice_group_change_cycle = bs_read_u(b, v); // FIXME add 2?
    }
    
    //svc specific
    if( !nal->nal_svc_ext->no_inter_layer_pred_flag && nal->nal_svc_ext->quality_id == 0 )
    {
        sh_svc_ext->ref_layer_dq_id = bs_read_ue(b);
        if( sps_subset->sps_svc_ext->inter_layer_deblocking_filter_control_present_flag )
        {
            sh_svc_ext->disable_inter_layer_deblocking_filter_idc = bs_read_ue(b);
            if( sh_svc_ext->disable_inter_layer_deblocking_filter_idc != 1 )
            {
                sh_svc_ext->inter_layer_slice_alpha_c0_offset_div2 = bs_read_se(b);
                sh_svc_ext->inter_layer_slice_beta_offset_div2 = bs_read_se(b);
            }
        }
        
        sh_svc_ext->constrained_intra_resampling_flag = bs_read_u1(b);
        if( sps_subset->sps_svc_ext->extended_spatial_scalability_idc == 2 )
        {
            if( sps_subset->sps->chroma_format_idc > 0 )
            {
                sh_svc_ext->ref_layer_chroma_phase_x_plus1_flag = bs_read_u1(b);
                sh_svc_ext->ref_layer_chroma_phase_y_plus1 = bs_read_u(b, 2);
            }
            
            sh_svc_ext->scaled_ref_layer_left_offset = bs_read_se(b);
            sh_svc_ext->scaled_ref_layer_top_offset = bs_read_se(b);
            sh_svc_ext->scaled_ref_layer_right_offset = bs_read_se(b);
            sh_svc_ext->scaled_ref_layer_bottom_offset = bs_read_se(b);
        }
    }
    
    if( !nal->nal_svc_ext->no_inter_layer_pred_flag )
    {
        sh_svc_ext->slice_skip_flag = bs_read_u1(b);
        if( sh_svc_ext->slice_skip_flag )
        {
            sh_svc_ext->num_mbs_in_slice_minus1 = bs_read_ue(b);
        }
        else
        {
            sh_svc_ext->adaptive_base_mode_flag = bs_read_u1(b);
            if( !sh_svc_ext->adaptive_base_mode_flag )
            {
                sh_svc_ext->default_base_mode_flag = bs_read_u1(b);
            }
            if( !sh_svc_ext->default_base_mode_flag )
            {
                sh_svc_ext->adaptive_motion_prediction_flag = bs_read_u1(b);
                if( !sh_svc_ext->adaptive_motion_prediction_flag )
                {
                    sh_svc_ext->default_motion_prediction_flag = bs_read_u1(b);
                }
            }
            sh_svc_ext->adaptive_residual_prediction_flag = bs_read_u1(b);
            if( !sh_svc_ext->adaptive_residual_prediction_flag )
            {
                sh_svc_ext->default_residual_prediction_flag = bs_read_u1(b);
            }
        }
        if( sps_subset->sps_svc_ext->adaptive_tcoeff_level_prediction_flag )
        {
            sh_svc_ext->tcoeff_level_prediction_flag = bs_read_u1(b);
        }
    }
    
    if( !sps_subset->sps_svc_ext->slice_header_restriction_flag && !sh_svc_ext->slice_skip_flag )
    {
        sh_svc_ext->scan_idx_start = bs_read_u(b, 4);
        sh_svc_ext->scan_idx_end = bs_read_u(b, 4);
    }
}

//G.7.3.3.5 Decoded reference base picture marking syntax
void read_dec_ref_base_pic_marking(nal_t* nal, bs_t* b)
{
    nal->prefix_nal_svc->adaptive_ref_base_pic_marking_mode_flag = bs_read_u1(b);
    if( nal->prefix_nal_svc->adaptive_ref_base_pic_marking_mode_flag )
    {
        do {
            nal->prefix_nal_svc->memory_management_base_control_operation = bs_read_ue(b);
            
            if( nal->prefix_nal_svc->memory_management_base_control_operation == 1 )
            {
                nal->prefix_nal_svc->difference_of_base_pic_nums_minus1 = bs_read_ue(b);
            }
            if( nal->prefix_nal_svc->memory_management_base_control_operation == 2 )
            {
                nal->prefix_nal_svc->long_term_base_pic_num = bs_read_ue(b);
            }
        } while( nal->prefix_nal_svc->memory_management_base_control_operation != 0 );
    }
}



void write_nal_unit_header_svc_extension(nal_svc_ext_t* nal_svc_ext, bs_t* b);
void write_prefix_nal_unit_svc(nal_t* nal, bs_t* b);
void write_prefix_nal_unit_rbsp(nal_t* nal, bs_t* b);
void write_seq_parameter_set_rbsp(sps_t* sps, bs_t* b);
void write_scaling_list(bs_t* b, int* scalingList, int sizeOfScalingList, int* useDefaultScalingMatrixFlag );
void write_subset_seq_parameter_set_rbsp(sps_subset_t* sps_subset, bs_t* b);
void write_seq_parameter_set_svc_extension(sps_subset_t* sps_subset, bs_t* b);
void write_svc_vui_parameters_extension(sps_svc_ext_t* sps_svc_ext, bs_t* b);
void write_vui_parameters(sps_t* sps, bs_t* b);
void write_hrd_parameters(hrd_t* hrd, bs_t* b);
void write_pic_parameter_set_rbsp(h264_stream_t* h, bs_t* b);
void write_sei_rbsp(h264_stream_t* h, bs_t* b);
void write_sei_message(h264_stream_t* h, bs_t* b);
void write_access_unit_delimiter_rbsp(h264_stream_t* h, bs_t* b);
void write_end_of_seq_rbsp(h264_stream_t* h, bs_t* b);
void write_end_of_stream_rbsp(h264_stream_t* h, bs_t* b);
void write_filler_data_rbsp(h264_stream_t* h, bs_t* b);
void write_slice_layer_rbsp(h264_stream_t* h,  bs_t* b);
void write_rbsp_slice_trailing_bits(h264_stream_t* h, bs_t* b);
void write_rbsp_trailing_bits(bs_t* b);
void write_slice_header(h264_stream_t* h, bs_t* b);
void write_ref_pic_list_reordering(h264_stream_t* h, bs_t* b);
void write_pred_weight_table(h264_stream_t* h, bs_t* b);
void write_dec_ref_pic_marking(h264_stream_t* h, bs_t* b);
void write_slice_header_in_scalable_extension(h264_stream_t* h, bs_t* b);
void write_dec_ref_base_pic_marking(nal_t* nal, bs_t* b);



//7.3.1 NAL unit syntax
int write_nal_unit(h264_stream_t* h, uint8_t* buf, int size)
{
    nal_t* nal = h->nal;

    int nal_size = size;
    int rbsp_size = size;
    uint8_t* rbsp_buf = (uint8_t*)calloc(1, rbsp_size);

    if( 0 )
    {
        int rc = nal_to_rbsp(buf, &nal_size, rbsp_buf, &rbsp_size);

        if (rc < 0) { free(rbsp_buf); return -1; } // handle conversion error
    }

    if( 1 )
    {
        rbsp_size = size*3/4; // NOTE this may have to be slightly smaller (3/4 smaller, worst case) in order to be guaranteed to fit
    }

    bs_t* b = bs_new(rbsp_buf, rbsp_size);
    /* forbidden_zero_bit */ bs_write_u(b, 1, 0);
    bs_write_u(b, 2, nal->nal_ref_idc);
    bs_write_u(b, 5, nal->nal_unit_type);
    
    if( nal->nal_unit_type == 14 || nal->nal_unit_type == 21 || nal->nal_unit_type == 20 )
    {
        if( nal->nal_unit_type != 21 )
        {
            bs_write_u1(b, nal->svc_extension_flag);
        }
        else
        {
            bs_write_u1(b, nal->avc_3d_extension_flag);
        }
        
        if( nal->svc_extension_flag )
        {
            write_nal_unit_header_svc_extension(nal->nal_svc_ext, b);
        }
    }

    switch ( nal->nal_unit_type )
    {
        case NAL_UNIT_TYPE_CODED_SLICE_IDR:
        case NAL_UNIT_TYPE_CODED_SLICE_NON_IDR:  
        case NAL_UNIT_TYPE_CODED_SLICE_AUX:
            write_slice_layer_rbsp(h, b);
            break;

#ifdef HAVE_SEI
        case NAL_UNIT_TYPE_SEI:
            write_sei_rbsp(h, b);
            write_rbsp_trailing_bits(b);
            break;
#endif

        case NAL_UNIT_TYPE_SPS: 
            write_seq_parameter_set_rbsp(h->sps, b);
            write_rbsp_trailing_bits(b);
            
            if( 0 )
            {
                memcpy(h->sps_table[h->sps->seq_parameter_set_id], h->sps, sizeof(sps_t));
            }

            break;

        case NAL_UNIT_TYPE_PPS:   
            write_pic_parameter_set_rbsp(h, b);
            write_rbsp_trailing_bits(b);
            break;

        case NAL_UNIT_TYPE_AUD:     
            write_access_unit_delimiter_rbsp(h, b); 
            write_rbsp_trailing_bits(b);
            break;

        case NAL_UNIT_TYPE_END_OF_SEQUENCE: 
            write_end_of_seq_rbsp(h, b);
            write_rbsp_trailing_bits(b);
            break;

        case NAL_UNIT_TYPE_END_OF_STREAM: 
            write_end_of_stream_rbsp(h, b);
            write_rbsp_trailing_bits(b);
            break;

        //SVC support
        case NAL_UNIT_TYPE_SUBSET_SPS:
            write_subset_seq_parameter_set_rbsp(h->sps_subset, b);
            write_rbsp_trailing_bits(b);
            
            if( 0 )
            {
                memcpy(h->sps_subset_table[h->sps_subset->sps->seq_parameter_set_id], h->sps_subset, sizeof(sps_subset_t));
                //memcpy(h->sps_subset_table[h->sps_subset->sps->seq_parameter_set_id]->sps, h->sps_subset->sps, sizeof(sps_t));
                //memcpy(h->sps_subset_table[h->sps_subset->sps->seq_parameter_set_id]->sps_svc_ext, h->sps_subset->sps_svc_ext, sizeof(sps_svc_ext_t));
                //h->sps_subset_table[h->sps_subset->sps->seq_parameter_set_id]->additional_extension2_flag = h->sps_subset->additional_extension2_flag;
            }

            break;
            
        //prefix NAL
        case NAL_UNIT_TYPE_PREFIX_NAL:
            write_prefix_nal_unit_rbsp(h->nal, b);
            write_rbsp_trailing_bits(b);
            break;
            
        //SVC support
        case NAL_UNIT_TYPE_CODED_SLICE_SVC_EXTENSION:            
            write_slice_layer_rbsp(h, b);
            
            break;
            
        case NAL_UNIT_TYPE_FILLER:
        case NAL_UNIT_TYPE_SPS_EXT:
        case NAL_UNIT_TYPE_UNSPECIFIED:
        case NAL_UNIT_TYPE_CODED_SLICE_DATA_PARTITION_A:  
        case NAL_UNIT_TYPE_CODED_SLICE_DATA_PARTITION_B: 
        case NAL_UNIT_TYPE_CODED_SLICE_DATA_PARTITION_C:
        default:
            return -1;
    }

    if (bs_overrun(b)) { bs_free(b); free(rbsp_buf); return -1; }

    if( 1 )
    {
        // now get the actual size used
        rbsp_size = bs_pos(b);

        int rc = rbsp_to_nal(rbsp_buf, &rbsp_size, buf, &nal_size);
        if (rc < 0) { bs_free(b); free(rbsp_buf); return -1; }
    }

    bs_free(b);
    free(rbsp_buf);

    return nal_size;
}

//G.7.3.1.1 NAL unit header SVC extension syntax
void write_nal_unit_header_svc_extension(nal_svc_ext_t* nal_svc_ext, bs_t* b)
{
    bs_write_u1(b, nal_svc_ext->idr_flag);
    bs_write_u(b, 6, nal_svc_ext->priority_id);
    bs_write_u1(b, nal_svc_ext->no_inter_layer_pred_flag);
    bs_write_u(b, 3, nal_svc_ext->dependency_id);
    bs_write_u(b, 4, nal_svc_ext->quality_id);
    bs_write_u(b, 3, nal_svc_ext->temporal_id);
    bs_write_u1(b, nal_svc_ext->use_ref_base_pic_flag);
    bs_write_u1(b, nal_svc_ext->discardable_flag);
    bs_write_u1(b, nal_svc_ext->output_flag);
    bs_write_u(b, 2, nal_svc_ext->reserved_three_2bits);
}

//G.7.3.2.12.1 Prefix NAL unit SVC syntax
void write_prefix_nal_unit_svc(nal_t* nal, bs_t* b)
{
    if( nal->nal_ref_idc != 0 )
    {
        bs_write_u1(b, nal->prefix_nal_svc->store_ref_base_pic_flag);
        if( ( nal->nal_svc_ext->use_ref_base_pic_flag || nal->prefix_nal_svc->store_ref_base_pic_flag ) &&
             !nal->nal_svc_ext->idr_flag )
        {
            write_dec_ref_base_pic_marking( nal, b );
        }
        bs_write_u1(b, nal->prefix_nal_svc->additional_prefix_nal_unit_extension_flag);
        if( nal->prefix_nal_svc->additional_prefix_nal_unit_extension_flag )
        {
            while( more_rbsp_data( b ) )
            {
                bs_write_u1(b, nal->prefix_nal_svc->additional_prefix_nal_unit_extension_data_flag);
            }
        }
    }
    else if( more_rbsp_data( b ) )
    {
        while( more_rbsp_data( b ) )
        {
            bs_write_u1(b, nal->prefix_nal_svc->additional_prefix_nal_unit_extension_data_flag);
        }
    }
}

//7.3.2.12 Prefix NAL unit RBSP syntax
void write_prefix_nal_unit_rbsp(nal_t* nal, bs_t* b)
{
    if( nal->svc_extension_flag )
    {
        write_prefix_nal_unit_svc(nal, b);
    }
}

//7.3.2.1 Sequence parameter set RBSP syntax
void write_seq_parameter_set_rbsp(sps_t* sps, bs_t* b)
{
    int i;

    if( 0 )
    {
        memset(sps, 0, sizeof(sps_t));
        sps->chroma_format_idc = 1; 
    }
 
    bs_write_u8(b, sps->profile_idc);
    bs_write_u1(b, sps->constraint_set0_flag);
    bs_write_u1(b, sps->constraint_set1_flag);
    bs_write_u1(b, sps->constraint_set2_flag);
    bs_write_u1(b, sps->constraint_set3_flag);
    bs_write_u1(b, sps->constraint_set4_flag);
    bs_write_u1(b, sps->constraint_set5_flag);
    /* reserved_zero_2bits */ bs_write_u(b, 2, 0);
    bs_write_u8(b, sps->level_idc);
    bs_write_ue(b, sps->seq_parameter_set_id);

    if( sps->profile_idc == 100 || sps->profile_idc == 110 ||
        sps->profile_idc == 122 || sps->profile_idc == 244 ||
        sps->profile_idc == 44 || sps->profile_idc == 83 ||
        sps->profile_idc == 86 || sps->profile_idc == 118 ||
        sps->profile_idc == 128 || sps->profile_idc == 138 ||
        sps->profile_idc == 139 || sps->profile_idc == 134
       )
    {
        bs_write_ue(b, sps->chroma_format_idc);
        if( sps->chroma_format_idc == 3 )
        {
            bs_write_u1(b, sps->residual_colour_transform_flag);
        }
        bs_write_ue(b, sps->bit_depth_luma_minus8);
        bs_write_ue(b, sps->bit_depth_chroma_minus8);
        bs_write_u1(b, sps->qpprime_y_zero_transform_bypass_flag);
        bs_write_u1(b, sps->seq_scaling_matrix_present_flag);
        if( sps->seq_scaling_matrix_present_flag )
        {
            for( i = 0; i < 8; i++ )
            {
                bs_write_u1(b, sps->seq_scaling_list_present_flag[ i ]);
                if( sps->seq_scaling_list_present_flag[ i ] )
                {
                    if( i < 6 )
                    {
                        write_scaling_list( b, sps->ScalingList4x4[ i ], 16,
                                                 &( sps->UseDefaultScalingMatrix4x4Flag[ i ] ) );
                    }
                    else
                    {
                        write_scaling_list( b, sps->ScalingList8x8[ i - 6 ], 64,
                                                 &( sps->UseDefaultScalingMatrix8x8Flag[ i - 6 ] ) );
                    }
                }
            }
        }
    }
    bs_write_ue(b, sps->log2_max_frame_num_minus4);
    bs_write_ue(b, sps->pic_order_cnt_type);
    if( sps->pic_order_cnt_type == 0 )
    {
        bs_write_ue(b, sps->log2_max_pic_order_cnt_lsb_minus4);
    }
    else if( sps->pic_order_cnt_type == 1 )
    {
        bs_write_u1(b, sps->delta_pic_order_always_zero_flag);
        bs_write_se(b, sps->offset_for_non_ref_pic);
        bs_write_se(b, sps->offset_for_top_to_bottom_field);
        bs_write_ue(b, sps->num_ref_frames_in_pic_order_cnt_cycle);
        for( i = 0; i < sps->num_ref_frames_in_pic_order_cnt_cycle; i++ )
        {
            bs_write_se(b, sps->offset_for_ref_frame[ i ]);
        }
    }
    bs_write_ue(b, sps->num_ref_frames);
    bs_write_u1(b, sps->gaps_in_frame_num_value_allowed_flag);
    bs_write_ue(b, sps->pic_width_in_mbs_minus1);
    bs_write_ue(b, sps->pic_height_in_map_units_minus1);
    bs_write_u1(b, sps->frame_mbs_only_flag);
    if( !sps->frame_mbs_only_flag )
    {
        bs_write_u1(b, sps->mb_adaptive_frame_field_flag);
    }
    bs_write_u1(b, sps->direct_8x8_inference_flag);
    bs_write_u1(b, sps->frame_cropping_flag);
    if( sps->frame_cropping_flag )
    {
        bs_write_ue(b, sps->frame_crop_left_offset);
        bs_write_ue(b, sps->frame_crop_right_offset);
        bs_write_ue(b, sps->frame_crop_top_offset);
        bs_write_ue(b, sps->frame_crop_bottom_offset);
    }
    bs_write_u1(b, sps->vui_parameters_present_flag);
    if( sps->vui_parameters_present_flag )
    {
        write_vui_parameters(sps, b);
    }
}

//7.3.2.1.1 Scaling list syntax
void write_scaling_list(bs_t* b, int* scalingList, int sizeOfScalingList, int* useDefaultScalingMatrixFlag )
{
    // NOTE need to be able to set useDefaultScalingMatrixFlag when reading, hence passing as pointer
    int lastScale = 8;
    int nextScale = 8;
    int delta_scale;
    for( int j = 0; j < sizeOfScalingList; j++ )
    {
        if( nextScale != 0 )
        {
            if( 1 )
            {
                nextScale = scalingList[ j ];
                if (useDefaultScalingMatrixFlag[0]) { nextScale = 0; }
                delta_scale = (nextScale - lastScale) % 256 ;
            }

            bs_write_se(b, delta_scale);

            if( 0 )
            {
                nextScale = ( lastScale + delta_scale + 256 ) % 256;
                useDefaultScalingMatrixFlag[0] = ( j == 0 && nextScale == 0 );
            }
        }
        if( 0 )
        {
            scalingList[ j ] = ( nextScale == 0 ) ? lastScale : nextScale;
        }
        lastScale = scalingList[ j ];
    }
}

//7.3.2.1.3 Subset sequence parameter set RBSP syntax
void write_subset_seq_parameter_set_rbsp(sps_subset_t* sps_subset, bs_t* b)
{
    write_seq_parameter_set_rbsp(sps_subset->sps, b);
    
    switch( sps_subset->sps->profile_idc )
    {
        case 83:
        case 86:
            write_seq_parameter_set_svc_extension(sps_subset, b); /* specified in Annex G */
            
            sps_svc_ext_t* sps_svc_ext = sps_subset->sps_svc_ext;
            bs_write_u1(b, sps_svc_ext->svc_vui_parameters_present_flag);
            
            if( sps_svc_ext->svc_vui_parameters_present_flag )
            {
                write_svc_vui_parameters_extension(sps_svc_ext,b); /* specified in Annex G */
            }
            break;
        default:
            break;
    }
    bs_write_u1(b, sps_subset->additional_extension2_flag);
    if( sps_subset->additional_extension2_flag )
    {
        while( more_rbsp_data( b ) )
        {
            bs_write_u1(b, sps_subset->additional_extension2_flag);
        }
    }
    
}

//Appendix G.7.3.2.1.4 Sequence parameter set SVC extension syntax
void write_seq_parameter_set_svc_extension(sps_subset_t* sps_subset, bs_t* b)
{
    sps_svc_ext_t* sps_svc_ext = sps_subset->sps_svc_ext;
    bs_write_u1(b, sps_svc_ext->inter_layer_deblocking_filter_control_present_flag);
    bs_write_u(b, 2, sps_svc_ext->extended_spatial_scalability_idc);
    if( sps_subset->sps->chroma_format_idc == 1 || sps_subset->sps->chroma_format_idc == 2 )
    {
        bs_write_u1(b, sps_svc_ext->chroma_phase_x_plus1_flag);
    }
    if( sps_subset->sps->chroma_format_idc == 1 )
    {
        bs_write_u(b, 2, sps_svc_ext->chroma_phase_y_plus1);
    }
    if( sps_svc_ext->extended_spatial_scalability_idc )
    {
        if( sps_subset->sps->chroma_format_idc > 0 )
        {
            bs_write_u1(b, sps_svc_ext->seq_ref_layer_chroma_phase_x_plus1_flag);
            bs_write_u(b, 2, sps_svc_ext->seq_ref_layer_chroma_phase_y_plus1);
        }
        bs_write_se(b, sps_svc_ext->seq_scaled_ref_layer_left_offset);
        bs_write_se(b, sps_svc_ext->seq_scaled_ref_layer_top_offset);
        bs_write_se(b, sps_svc_ext->seq_scaled_ref_layer_right_offset);
        bs_write_se(b, sps_svc_ext->seq_scaled_ref_layer_bottom_offset);
    }
    bs_write_u1(b, sps_svc_ext->seq_tcoeff_level_prediction_flag);
    if( sps_svc_ext->seq_tcoeff_level_prediction_flag )
    {
        bs_write_u1(b, sps_svc_ext->adaptive_tcoeff_level_prediction_flag);
    }
    bs_write_u1(b, sps_svc_ext->slice_header_restriction_flag);
}

//Appendix G.14.1 SVC VUI parameters extension syntax
void write_svc_vui_parameters_extension(sps_svc_ext_t* sps_svc_ext, bs_t* b)
{
    bs_write_ue(b, sps_svc_ext->vui.vui_ext_num_entries_minus1);
    for( int i = 0; i <= sps_svc_ext->vui.vui_ext_num_entries_minus1; i++ )
    {
        bs_write_u(b, 3, sps_svc_ext->vui.vui_ext_dependency_id[i]);
        bs_write_u(b, 4, sps_svc_ext->vui.vui_ext_quality_id[i]);
        bs_write_u(b, 3, sps_svc_ext->vui.vui_ext_temporal_id[i]);
        bs_write_u1(b, sps_svc_ext->vui.vui_ext_timing_info_present_flag[i]);
        if( sps_svc_ext->vui.vui_ext_timing_info_present_flag[i] )
        {
            bs_write_u(b, 32, sps_svc_ext->vui.vui_ext_num_units_in_tick[i]);
            bs_write_u(b, 32, sps_svc_ext->vui.vui_ext_time_scale[i]);
            bs_write_u1(b, sps_svc_ext->vui.vui_ext_fixed_frame_rate_flag[i]);
        }

        bs_write_u1(b, sps_svc_ext->vui.vui_ext_nal_hrd_parameters_present_flag[i]);
        if( sps_svc_ext->vui.vui_ext_nal_hrd_parameters_present_flag[i] )
        {
            write_hrd_parameters(&sps_svc_ext->hrd_vcl[i], b);
        }
        bs_write_u1(b, sps_svc_ext->vui.vui_ext_vcl_hrd_parameters_present_flag[i]);
        if( sps_svc_ext->vui.vui_ext_vcl_hrd_parameters_present_flag[i] )
        {
            write_hrd_parameters(&sps_svc_ext->hrd_nal[i], b);
        }
        
        if( sps_svc_ext->vui.vui_ext_nal_hrd_parameters_present_flag[i] ||
            sps_svc_ext->vui.vui_ext_vcl_hrd_parameters_present_flag[i] )
        {
            bs_write_u1(b, sps_svc_ext->vui.vui_ext_low_delay_hrd_flag[i]);
        }
        bs_write_u1(b, sps_svc_ext->vui.vui_ext_pic_struct_present_flag[i]);
    }
}

//Appendix E.1.1 VUI parameters syntax
void write_vui_parameters(sps_t* sps, bs_t* b)
{
    bs_write_u1(b, sps->vui.aspect_ratio_info_present_flag);
    if( sps->vui.aspect_ratio_info_present_flag )
    {
        bs_write_u8(b, sps->vui.aspect_ratio_idc);
        if( sps->vui.aspect_ratio_idc == SAR_Extended )
        {
            bs_write_u(b, 16, sps->vui.sar_width);
            bs_write_u(b, 16, sps->vui.sar_height);
        }
    }
    bs_write_u1(b, sps->vui.overscan_info_present_flag);
    if( sps->vui.overscan_info_present_flag )
    {
        bs_write_u1(b, sps->vui.overscan_appropriate_flag);
    }
    bs_write_u1(b, sps->vui.video_signal_type_present_flag);
    if( sps->vui.video_signal_type_present_flag )
    {
        bs_write_u(b, 3, sps->vui.video_format);
        bs_write_u1(b, sps->vui.video_full_range_flag);
        bs_write_u1(b, sps->vui.colour_description_present_flag);
        if( sps->vui.colour_description_present_flag )
        {
            bs_write_u8(b, sps->vui.colour_primaries);
            bs_write_u8(b, sps->vui.transfer_characteristics);
            bs_write_u8(b, sps->vui.matrix_coefficients);
        }
    }
    bs_write_u1(b, sps->vui.chroma_loc_info_present_flag);
    if( sps->vui.chroma_loc_info_present_flag )
    {
        bs_write_ue(b, sps->vui.chroma_sample_loc_type_top_field);
        bs_write_ue(b, sps->vui.chroma_sample_loc_type_bottom_field);
    }
    bs_write_u1(b, sps->vui.timing_info_present_flag);
    if( sps->vui.timing_info_present_flag )
    {
        bs_write_u(b, 32, sps->vui.num_units_in_tick);
        bs_write_u(b, 32, sps->vui.time_scale);
        bs_write_u1(b, sps->vui.fixed_frame_rate_flag);
    }
    bs_write_u1(b, sps->vui.nal_hrd_parameters_present_flag);
    if( sps->vui.nal_hrd_parameters_present_flag )
    {
        write_hrd_parameters(&sps->hrd_nal, b);
    }
    bs_write_u1(b, sps->vui.vcl_hrd_parameters_present_flag);
    if( sps->vui.vcl_hrd_parameters_present_flag )
    {
        write_hrd_parameters(&sps->hrd_vcl, b);
    }
    if( sps->vui.nal_hrd_parameters_present_flag || sps->vui.vcl_hrd_parameters_present_flag )
    {
        bs_write_u1(b, sps->vui.low_delay_hrd_flag);
    }
    bs_write_u1(b, sps->vui.pic_struct_present_flag);
    bs_write_u1(b, sps->vui.bitstream_restriction_flag);
    if( sps->vui.bitstream_restriction_flag )
    {
        bs_write_u1(b, sps->vui.motion_vectors_over_pic_boundaries_flag);
        bs_write_ue(b, sps->vui.max_bytes_per_pic_denom);
        bs_write_ue(b, sps->vui.max_bits_per_mb_denom);
        bs_write_ue(b, sps->vui.log2_max_mv_length_horizontal);
        bs_write_ue(b, sps->vui.log2_max_mv_length_vertical);
        bs_write_ue(b, sps->vui.num_reorder_frames);
        bs_write_ue(b, sps->vui.max_dec_frame_buffering);
    }
}


//Appendix E.1.2 HRD parameters syntax
void write_hrd_parameters(hrd_t* hrd, bs_t* b)
{
    bs_write_ue(b, hrd->cpb_cnt_minus1);
    bs_write_u(b, 4, hrd->bit_rate_scale);
    bs_write_u(b, 4, hrd->cpb_size_scale);
    for( int SchedSelIdx = 0; SchedSelIdx <= hrd->cpb_cnt_minus1; SchedSelIdx++ )
    {
        bs_write_ue(b, hrd->bit_rate_value_minus1[ SchedSelIdx ]);
        bs_write_ue(b, hrd->cpb_size_value_minus1[ SchedSelIdx ]);
        bs_write_u1(b, hrd->cbr_flag[ SchedSelIdx ]);
    }
    bs_write_u(b, 5, hrd->initial_cpb_removal_delay_length_minus1);
    bs_write_u(b, 5, hrd->cpb_removal_delay_length_minus1);
    bs_write_u(b, 5, hrd->dpb_output_delay_length_minus1);
    bs_write_u(b, 5, hrd->time_offset_length);
}


/*
UNIMPLEMENTED
//7.3.2.1.2 Sequence parameter set extension RBSP syntax
int write_seq_parameter_set_extension_rbsp(bs_t* b, sps_ext_t* sps_ext) {
    bs_write_ue(b, seq_parameter_set_id);
    bs_write_ue(b, aux_format_idc);
    if( aux_format_idc != 0 ) {
        bs_write_ue(b, bit_depth_aux_minus8);
        bs_write_u1(b, alpha_incr_flag);
        alpha_opaque_value = bs_write_u(v);
        alpha_transparent_value = bs_write_u(v);
    }
    bs_write_u1(b, additional_extension_flag);
    write_rbsp_trailing_bits();
}
*/

//7.3.2.2 Picture parameter set RBSP syntax
void write_pic_parameter_set_rbsp(h264_stream_t* h, bs_t* b)
{
    pps_t* pps = h->pps;
    if( 0 )
    {
        memset(pps, 0, sizeof(pps_t));
    }

    bs_write_ue(b, pps->pic_parameter_set_id);
    bs_write_ue(b, pps->seq_parameter_set_id);
    bs_write_u1(b, pps->entropy_coding_mode_flag);
    bs_write_u1(b, pps->pic_order_present_flag);
    bs_write_ue(b, pps->num_slice_groups_minus1);

    if( pps->num_slice_groups_minus1 > 0 )
    {
        bs_write_ue(b, pps->slice_group_map_type);
        if( pps->slice_group_map_type == 0 )
        {
            for( int i_group = 0; i_group <= pps->num_slice_groups_minus1; i_group++ )
            {
                bs_write_ue(b, pps->run_length_minus1[ i_group ]);
            }
        }
        else if( pps->slice_group_map_type == 2 )
        {
            for( int i_group = 0; i_group < pps->num_slice_groups_minus1; i_group++ )
            {
                bs_write_ue(b, pps->top_left[ i_group ]);
                bs_write_ue(b, pps->bottom_right[ i_group ]);
            }
        }
        else if( pps->slice_group_map_type == 3 ||
                 pps->slice_group_map_type == 4 ||
                 pps->slice_group_map_type == 5 )
        {
            bs_write_u1(b, pps->slice_group_change_direction_flag);
            bs_write_ue(b, pps->slice_group_change_rate_minus1);
        }
        else if( pps->slice_group_map_type == 6 )
        {
            bs_write_ue(b, pps->pic_size_in_map_units_minus1);
            for( int i = 0; i <= pps->pic_size_in_map_units_minus1; i++ )
            {
                int v = intlog2( pps->num_slice_groups_minus1 + 1 );
                bs_write_u(b, v, pps->slice_group_id[ i ]);
            }
        }
    }
    bs_write_ue(b, pps->num_ref_idx_l0_active_minus1);
    bs_write_ue(b, pps->num_ref_idx_l1_active_minus1);
    bs_write_u1(b, pps->weighted_pred_flag);
    bs_write_u(b, 2, pps->weighted_bipred_idc);
    bs_write_se(b, pps->pic_init_qp_minus26);
    bs_write_se(b, pps->pic_init_qs_minus26);
    bs_write_se(b, pps->chroma_qp_index_offset);
    bs_write_u1(b, pps->deblocking_filter_control_present_flag);
    bs_write_u1(b, pps->constrained_intra_pred_flag);
    bs_write_u1(b, pps->redundant_pic_cnt_present_flag);

    int have_more_data = 0;
    if( 0 ) { have_more_data = more_rbsp_data(b); }
    if( 1 )
    {
        have_more_data = pps->transform_8x8_mode_flag | pps->pic_scaling_matrix_present_flag | pps->second_chroma_qp_index_offset != 0;
    }

    if( have_more_data )
    {
        bs_write_u1(b, pps->transform_8x8_mode_flag);
        bs_write_u1(b, pps->pic_scaling_matrix_present_flag);
        if( pps->pic_scaling_matrix_present_flag )
        {
            for( int i = 0; i < 6 + 2* pps->transform_8x8_mode_flag; i++ )
            {
                bs_write_u1(b, pps->pic_scaling_list_present_flag[ i ]);
                if( pps->pic_scaling_list_present_flag[ i ] )
                {
                    if( i < 6 )
                    {
                        write_scaling_list( b, pps->ScalingList4x4[ i ], 16,
                                                 &( pps->UseDefaultScalingMatrix4x4Flag[ i ] ) );
                    }
                    else
                    {
                        write_scaling_list( b, pps->ScalingList8x8[ i - 6 ], 64,
                                                 &( pps->UseDefaultScalingMatrix8x8Flag[ i - 6 ] ) );
                    }
                }
            }
        }
        bs_write_se(b, pps->second_chroma_qp_index_offset);
    }

    if( 0 )
    {
        memcpy(h->pps_table[pps->pic_parameter_set_id], h->pps, sizeof(pps_t));
    }
}

#ifdef HAVE_SEI
//7.3.2.3 Supplemental enhancement information RBSP syntax
void write_sei_rbsp(h264_stream_t* h, bs_t* b)
{
    if( 0 )
    {
        for( int i = 0; i < h->num_seis; i++ )
        {
            sei_free(h->seis[i]);
        }
    
        h->num_seis = 0;
        do {
            h->num_seis++;
            h->seis = (sei_t**)realloc(h->seis, h->num_seis * sizeof(sei_t*));
            h->seis[h->num_seis - 1] = sei_new();
            h->sei = h->seis[h->num_seis - 1];
            write_sei_message(h, b);
        } while( more_rbsp_data(b) );
    }

    if( 1 )
    {
        for (int i = 0; i < h->num_seis; i++)
        {
            h->sei = h->seis[i];
            write_sei_message(h, b);
        }
        h->sei = NULL;
    }
}

//7.3.2.3.1 Supplemental enhancement information message syntax
void write_sei_message(h264_stream_t* h, bs_t* b)
{
    if( 1 )
    {
        _write_ff_coded_number(b, h->sei->payloadType);
        _write_ff_coded_number(b, h->sei->payloadSize);
    }
    if( 0 )
    {
        h->sei->payloadType = _read_ff_coded_number(b);
        h->sei->payloadSize = _read_ff_coded_number(b);
    }
    write_sei_payload( h, b );
}
#endif

//7.3.2.4 Access unit delimiter RBSP syntax
void write_access_unit_delimiter_rbsp(h264_stream_t* h, bs_t* b)
{
    bs_write_u(b, 3, h->aud->primary_pic_type);
}

//7.3.2.5 End of sequence RBSP syntax
void write_end_of_seq_rbsp(h264_stream_t* h, bs_t* b)
{
}

//7.3.2.6 End of stream RBSP syntax
void write_end_of_stream_rbsp(h264_stream_t* h, bs_t* b)
{
}

//7.3.2.7 Filler data RBSP syntax
void write_filler_data_rbsp(h264_stream_t* h, bs_t* b)
{
    while( bs_next_bits(b, 8) == 0xFF )
    {
        /* ff_byte */ bs_write_u(b, 8, 0xFF);
    }
}

//7.3.2.8 Slice layer without partitioning RBSP syntax
void write_slice_layer_rbsp(h264_stream_t* h,  bs_t* b)
{
    if (h->nal->nal_unit_type != NAL_UNIT_TYPE_CODED_SLICE_SVC_EXTENSION)
        write_slice_header(h, b);
    else
        write_slice_header_in_scalable_extension(h, b);
    
    slice_data_rbsp_t* slice_data = h->slice_data;

    if ( slice_data != NULL )
    {
        if ( slice_data->rbsp_buf != NULL ) free( slice_data->rbsp_buf ); 
        uint8_t *sptr = b->p + (!!b->bits_left); // CABAC-specific: skip alignment bits, if there are any
        slice_data->rbsp_size = b->end - sptr;
        
        slice_data->rbsp_buf = (uint8_t*)malloc(slice_data->rbsp_size);
        memcpy( slice_data->rbsp_buf, sptr, slice_data->rbsp_size );
        // ugly hack: since next NALU starts at byte border, we are going to be padded by trailing_bits;
        return;
    }

    // FIXME should read or skip data
    //slice_data( ); /* all categories of slice_data( ) syntax */
    write_rbsp_slice_trailing_bits(h, b);
}

/*
// UNIMPLEMENTED
//7.3.2.9.1 Slice data partition A RBSP syntax
slice_data_partition_a_layer_rbsp( ) {
    write_slice_header( );             // only category 2
    slice_id = bs_write_ue(b)
    write_slice_data( );               // only category 2
    write_rbsp_slice_trailing_bits( ); // only category 2
}

//7.3.2.9.2 Slice data partition B RBSP syntax
slice_data_partition_b_layer_rbsp( ) {
    bs_write_ue(b, slice_id);    // only category 3
    if( redundant_pic_cnt_present_flag )
        bs_write_ue(b, redundant_pic_cnt);
    write_slice_data( );               // only category 3
    write_rbsp_slice_trailing_bits( ); // only category 3
}

//7.3.2.9.3 Slice data partition C RBSP syntax
slice_data_partition_c_layer_rbsp( ) {
    bs_write_ue(b, slice_id);    // only category 4
    if( redundant_pic_cnt_present_flag )
        bs_write_ue(b, redundant_pic_cnt);
    write_slice_data( );               // only category 4
    rbsp_slice_trailing_bits( ); // only category 4
}
*/

//7.3.2.10 RBSP slice trailing bits syntax
void write_rbsp_slice_trailing_bits(h264_stream_t* h, bs_t* b)
{
    write_rbsp_trailing_bits(b);
    if( h->pps->entropy_coding_mode_flag )
    {
        while( more_rbsp_trailing_data(h, b) )
        {
            /* cabac_zero_word */ bs_write_u(b, 16, 0x0000);
        }
    }
}

//7.3.2.11 RBSP trailing bits syntax
void write_rbsp_trailing_bits(bs_t* b)
{
    /* rbsp_stop_one_bit */ bs_write_u(b, 1, 1);

    while( !bs_byte_aligned(b) )
    {
        /* rbsp_alignment_zero_bit */ bs_write_u(b, 1, 0);
    }
}

//7.3.3 Slice header syntax
void write_slice_header(h264_stream_t* h, bs_t* b)
{
    slice_header_t* sh = h->sh;
    if( 0 )
    {
        memset(sh, 0, sizeof(slice_header_t));
    }

    nal_t* nal = h->nal;

    bs_write_ue(b, sh->first_mb_in_slice);
    bs_write_ue(b, sh->slice_type);
    bs_write_ue(b, sh->pic_parameter_set_id);

    // TODO check existence, otherwise fail
    pps_t* pps = h->pps;
    sps_t* sps = h->sps;
    memcpy(h->pps, h->pps_table[sh->pic_parameter_set_id], sizeof(pps_t));
    memcpy(h->sps, h->sps_table[pps->seq_parameter_set_id], sizeof(sps_t));

    if (sps->residual_colour_transform_flag)
    {
        bs_write_u(b, 2, sh->colour_plane_id);
    }
    
    bs_write_u(b, sps->log2_max_frame_num_minus4 + 4 , sh->frame_num); // was u(v)
    if( !sps->frame_mbs_only_flag )
    {
        bs_write_u1(b, sh->field_pic_flag);
        if( sh->field_pic_flag )
        {
            bs_write_u1(b, sh->bottom_field_flag);
        }
    }
    if( nal->nal_unit_type == 5 )
    {
        bs_write_ue(b, sh->idr_pic_id);
    }
    if( sps->pic_order_cnt_type == 0 )
    {
        bs_write_u(b, sps->log2_max_pic_order_cnt_lsb_minus4 + 4 , sh->pic_order_cnt_lsb); // was u(v)
        if( pps->pic_order_present_flag && !sh->field_pic_flag )
        {
            bs_write_se(b, sh->delta_pic_order_cnt_bottom);
        }
    }
    if( sps->pic_order_cnt_type == 1 && !sps->delta_pic_order_always_zero_flag )
    {
        bs_write_se(b, sh->delta_pic_order_cnt[ 0 ]);
        if( pps->pic_order_present_flag && !sh->field_pic_flag )
        {
            bs_write_se(b, sh->delta_pic_order_cnt[ 1 ]);
        }
    }
    if( pps->redundant_pic_cnt_present_flag )
    {
        bs_write_ue(b, sh->redundant_pic_cnt);
    }
    if( is_slice_type( sh->slice_type, SH_SLICE_TYPE_B ) )
    {
        bs_write_u1(b, sh->direct_spatial_mv_pred_flag);
    }
    if( is_slice_type( sh->slice_type, SH_SLICE_TYPE_P ) || is_slice_type( sh->slice_type, SH_SLICE_TYPE_SP ) || is_slice_type( sh->slice_type, SH_SLICE_TYPE_B ) )
    {
        bs_write_u1(b, sh->num_ref_idx_active_override_flag);
        if( sh->num_ref_idx_active_override_flag )
        {
            bs_write_ue(b, sh->num_ref_idx_l0_active_minus1); // FIXME does this modify the pps?
            if( is_slice_type( sh->slice_type, SH_SLICE_TYPE_B ) )
            {
                bs_write_ue(b, sh->num_ref_idx_l1_active_minus1);
            }
        }
    }
    write_ref_pic_list_reordering(h, b);
    if( ( pps->weighted_pred_flag && ( is_slice_type( sh->slice_type, SH_SLICE_TYPE_P ) || is_slice_type( sh->slice_type, SH_SLICE_TYPE_SP ) ) ) ||
        ( pps->weighted_bipred_idc == 1 && is_slice_type( sh->slice_type, SH_SLICE_TYPE_B ) ) )
    {
        write_pred_weight_table(h, b);
    }
    if( nal->nal_ref_idc != 0 )
    {
        write_dec_ref_pic_marking(h, b);
    }
    if( pps->entropy_coding_mode_flag && ! is_slice_type( sh->slice_type, SH_SLICE_TYPE_I ) && ! is_slice_type( sh->slice_type, SH_SLICE_TYPE_SI ) )
    {
        bs_write_ue(b, sh->cabac_init_idc);
    }
    bs_write_se(b, sh->slice_qp_delta);
    if( is_slice_type( sh->slice_type, SH_SLICE_TYPE_SP ) || is_slice_type( sh->slice_type, SH_SLICE_TYPE_SI ) )
    {
        if( is_slice_type( sh->slice_type, SH_SLICE_TYPE_SP ) )
        {
            bs_write_u1(b, sh->sp_for_switch_flag);
        }
        bs_write_se(b, sh->slice_qs_delta);
    }
    if( pps->deblocking_filter_control_present_flag )
    {
        bs_write_ue(b, sh->disable_deblocking_filter_idc);
        if( sh->disable_deblocking_filter_idc != 1 )
        {
            bs_write_se(b, sh->slice_alpha_c0_offset_div2);
            bs_write_se(b, sh->slice_beta_offset_div2);
        }
    }
    if( pps->num_slice_groups_minus1 > 0 &&
        pps->slice_group_map_type >= 3 && pps->slice_group_map_type <= 5)
    {
        int v = intlog2( pps->pic_size_in_map_units_minus1 +  pps->slice_group_change_rate_minus1 + 1 );
        bs_write_u(b, v, sh->slice_group_change_cycle); // FIXME add 2?
    }
}

//7.3.3.1 Reference picture list reordering syntax
void write_ref_pic_list_reordering(h264_stream_t* h, bs_t* b)
{
    slice_header_t* sh = h->sh;
    // FIXME should be an array

    if( ! is_slice_type( sh->slice_type, SH_SLICE_TYPE_I ) && ! is_slice_type( sh->slice_type, SH_SLICE_TYPE_SI ) )
    {
        bs_write_u1(b, sh->rplr.ref_pic_list_reordering_flag_l0);
        if( sh->rplr.ref_pic_list_reordering_flag_l0 )
        {
            int n = -1;
            do
            {
                n++;
                bs_write_ue(b, sh->rplr.reorder_l0.reordering_of_pic_nums_idc[ n ]);
                if( sh->rplr.reorder_l0.reordering_of_pic_nums_idc[ n ] == 0 ||
                    sh->rplr.reorder_l0.reordering_of_pic_nums_idc[ n ] == 1 )
                {
                    bs_write_ue(b, sh->rplr.reorder_l0.abs_diff_pic_num_minus1[ n ]);
                }
                else if( sh->rplr.reorder_l0.reordering_of_pic_nums_idc[ n ] == 2 )
                {
                    bs_write_ue(b, sh->rplr.reorder_l0.long_term_pic_num[ n ]);
                }
            } while( sh->rplr.reorder_l0.reordering_of_pic_nums_idc[ n ] != 3 && ! bs_eof(b) );
        }
    }
    if( is_slice_type( sh->slice_type, SH_SLICE_TYPE_B ) )
    {
        bs_write_u1(b, sh->rplr.ref_pic_list_reordering_flag_l1);
        if( sh->rplr.ref_pic_list_reordering_flag_l1 )
        {
            int n = -1;
            do
            {
                n++;
                bs_write_ue(b, sh->rplr.reorder_l1.reordering_of_pic_nums_idc[ n ]);
                if( sh->rplr.reorder_l1.reordering_of_pic_nums_idc[ n ] == 0 ||
                    sh->rplr.reorder_l1.reordering_of_pic_nums_idc[ n ] == 1 )
                {
                    bs_write_ue(b, sh->rplr.reorder_l1.abs_diff_pic_num_minus1[ n ]);
                }
                else if( sh->rplr.reorder_l1.reordering_of_pic_nums_idc[ n ] == 2 )
                {
                    bs_write_ue(b, sh->rplr.reorder_l1.long_term_pic_num[ n ]);
                }
            } while( sh->rplr.reorder_l1.reordering_of_pic_nums_idc[ n ] != 3 && ! bs_eof(b) );
        }
    }
}

//7.3.3.2 Prediction weight table syntax
void write_pred_weight_table(h264_stream_t* h, bs_t* b)
{
    slice_header_t* sh = h->sh;
    sps_t* sps = h->sps;
    pps_t* pps = h->pps;

    int i, j;

    bs_write_ue(b, sh->pwt.luma_log2_weight_denom);
    if( sps->chroma_format_idc != 0 )
    {
        bs_write_ue(b, sh->pwt.chroma_log2_weight_denom);
    }
    for( i = 0; i <= pps->num_ref_idx_l0_active_minus1; i++ )
    {
        bs_write_u1(b, sh->pwt.luma_weight_l0_flag[i]);
        if( sh->pwt.luma_weight_l0_flag[i] )
        {
            bs_write_se(b, sh->pwt.luma_weight_l0[ i ]);
            bs_write_se(b, sh->pwt.luma_offset_l0[ i ]);
        }
        if ( sps->chroma_format_idc != 0 )
        {
            bs_write_u1(b, sh->pwt.chroma_weight_l0_flag[i]);
            if( sh->pwt.chroma_weight_l0_flag[i] )
            {
                for( j =0; j < 2; j++ )
                {
                    bs_write_se(b, sh->pwt.chroma_weight_l0[ i ][ j ]);
                    bs_write_se(b, sh->pwt.chroma_offset_l0[ i ][ j ]);
                }
            }
        }
    }
    if( is_slice_type( sh->slice_type, SH_SLICE_TYPE_B ) )
    {
        for( i = 0; i <= pps->num_ref_idx_l1_active_minus1; i++ )
        {
            bs_write_u1(b, sh->pwt.luma_weight_l1_flag[i]);
            if( sh->pwt.luma_weight_l1_flag[i] )
            {
                bs_write_se(b, sh->pwt.luma_weight_l1[ i ]);
                bs_write_se(b, sh->pwt.luma_offset_l1[ i ]);
            }
            if( sps->chroma_format_idc != 0 )
            {
                bs_write_u1(b, sh->pwt.chroma_weight_l1_flag[i]);
                if( sh->pwt.chroma_weight_l1_flag[i] )
                {
                    for( j = 0; j < 2; j++ )
                    {
                        bs_write_se(b, sh->pwt.chroma_weight_l1[ i ][ j ]);
                        bs_write_se(b, sh->pwt.chroma_offset_l1[ i ][ j ]);
                    }
                }
            }
        }
    }
}

//7.3.3.3 Decoded reference picture marking syntax
void write_dec_ref_pic_marking(h264_stream_t* h, bs_t* b)
{
    slice_header_t* sh = h->sh;
    // FIXME should be an array

    if( h->nal->nal_unit_type == 5 )
    {
        bs_write_u1(b, sh->drpm.no_output_of_prior_pics_flag);
        bs_write_u1(b, sh->drpm.long_term_reference_flag);
    }
    else
    {
        bs_write_u1(b, sh->drpm.adaptive_ref_pic_marking_mode_flag);
        if( sh->drpm.adaptive_ref_pic_marking_mode_flag )
        {
            int n = -1;
            do
            {
                n++;
                bs_write_ue(b, sh->drpm.memory_management_control_operation[ n ]);
                if( sh->drpm.memory_management_control_operation[ n ] == 1 ||
                    sh->drpm.memory_management_control_operation[ n ] == 3 )
                {
                    bs_write_ue(b, sh->drpm.difference_of_pic_nums_minus1[ n ]);
                }
                if(sh->drpm.memory_management_control_operation[ n ] == 2 )
                {
                    bs_write_ue(b, sh->drpm.long_term_pic_num[ n ]);
                }
                if( sh->drpm.memory_management_control_operation[ n ] == 3 ||
                    sh->drpm.memory_management_control_operation[ n ] == 6 )
                {
                    bs_write_ue(b, sh->drpm.long_term_frame_idx[ n ]);
                }
                if( sh->drpm.memory_management_control_operation[ n ] == 4 )
                {
                    bs_write_ue(b, sh->drpm.max_long_term_frame_idx_plus1[ n ]);
                }
            } while( sh->drpm.memory_management_control_operation[ n ] != 0 && ! bs_eof(b) );
        }
    }
}

//G.7.3.3.4 Slice header in scalable extension syntax
void write_slice_header_in_scalable_extension(h264_stream_t* h, bs_t* b)
{
    slice_header_t* sh = h->sh;
    slice_header_svc_ext_t* sh_svc_ext = h->sh_svc_ext;
    if( 0 )
    {
        memset(sh, 0, sizeof(slice_header_t));
        memset(sh_svc_ext, 0, sizeof(slice_header_svc_ext_t));
    }
    
    nal_t* nal = h->nal;
    
    bs_write_ue(b, sh->first_mb_in_slice);
    bs_write_ue(b, sh->slice_type);
    bs_write_ue(b, sh->pic_parameter_set_id);
    
    // TODO check existence, otherwise fail
    pps_t* pps = h->pps;
    sps_subset_t* sps_subset = h->sps_subset;
    memcpy(h->pps, h->pps_table[sh->pic_parameter_set_id], sizeof(pps_t));
    memcpy(sps_subset, h->sps_subset_table[pps->seq_parameter_set_id], sizeof(sps_subset_t));
    //memcpy(h->sps_subset->sps, h->sps_subset_table[pps->seq_parameter_set_id]->sps, sizeof(sps_t));
    //memcpy(h->sps_subset->sps_svc_ext, h->sps_subset_table[pps->seq_parameter_set_id]->sps_svc_ext, sizeof(sps_svc_ext_t));
    
    if (sps_subset->sps->residual_colour_transform_flag)
    {
        bs_write_u(b, 2, sh->colour_plane_id);
    }
    
    bs_write_u(b, sps_subset->sps->log2_max_frame_num_minus4 + 4 , sh->frame_num); // was u(v)
    if( !sps_subset->sps->frame_mbs_only_flag )
    {
        bs_write_u1(b, sh->field_pic_flag);
        if( sh->field_pic_flag )
        {
            bs_write_u1(b, sh->bottom_field_flag);
        }
    }
    if( nal->nal_unit_type == 5 )
    {
        bs_write_ue(b, sh->idr_pic_id);
    }
    if( sps_subset->sps->pic_order_cnt_type == 0 )
    {
        bs_write_u(b, sps_subset->sps->log2_max_pic_order_cnt_lsb_minus4 + 4 , sh->pic_order_cnt_lsb); // was u(v)
        if( pps->pic_order_present_flag && !sh->field_pic_flag )
        {
            bs_write_se(b, sh->delta_pic_order_cnt_bottom);
        }
    }
    if( sps_subset->sps->pic_order_cnt_type == 1 && !sps_subset->sps->delta_pic_order_always_zero_flag )
    {
        bs_write_se(b, sh->delta_pic_order_cnt[ 0 ]);
        if( pps->pic_order_present_flag && !sh->field_pic_flag )
        {
            bs_write_se(b, sh->delta_pic_order_cnt[ 1 ]);
        }
    }
    if( pps->redundant_pic_cnt_present_flag )
    {
        bs_write_ue(b, sh->redundant_pic_cnt);
    }
    if( nal->nal_svc_ext->quality_id == 0)
    {
        if( is_slice_type( sh->slice_type, SH_SLICE_TYPE_EB ) )
        {
            bs_write_u1(b, sh->direct_spatial_mv_pred_flag);
        }
        if( is_slice_type( sh->slice_type, SH_SLICE_TYPE_EP ) ||
            is_slice_type( sh->slice_type, SH_SLICE_TYPE_EB ) )
        {
            bs_write_u1(b, sh->num_ref_idx_active_override_flag);
            if( sh->num_ref_idx_active_override_flag )
            {
                bs_write_ue(b, sh->num_ref_idx_l0_active_minus1); // FIXME does this modify the pps?
                if( is_slice_type( sh->slice_type, SH_SLICE_TYPE_EB ) )
                {
                    bs_write_ue(b, sh->num_ref_idx_l1_active_minus1);
                }
            }
        }
        write_ref_pic_list_reordering(h, b);
        if( ( pps->weighted_pred_flag       && is_slice_type( sh->slice_type, SH_SLICE_TYPE_EP ) ) ||
            ( pps->weighted_bipred_idc == 1 && is_slice_type( sh->slice_type, SH_SLICE_TYPE_EB ) ) )
        {
            //svc specific
            if( !nal->nal_svc_ext->no_inter_layer_pred_flag )
            {
                bs_write_u1(b, sh_svc_ext->base_pred_weight_table_flag);
            }
            if( nal->nal_svc_ext->no_inter_layer_pred_flag || !sh_svc_ext->base_pred_weight_table_flag )
            {
                write_pred_weight_table(h, b);
            }
        }
        if( nal->nal_ref_idc != 0 )
        {
            write_dec_ref_pic_marking(h, b);
            
            //svc specific
            if( !sps_subset->sps_svc_ext->slice_header_restriction_flag )
            {
                bs_write_u1(b, sh_svc_ext->store_ref_base_pic_flag);
                if( ( nal->nal_svc_ext->use_ref_base_pic_flag || sh_svc_ext->store_ref_base_pic_flag ) &&
                   ( nal->nal_unit_type != 5 ) )
                {
                    write_dec_ref_base_pic_marking(nal, b);
                }
            }
        }
    }
    
    if( pps->entropy_coding_mode_flag && ! is_slice_type( sh->slice_type, SH_SLICE_TYPE_EI ) )
    {
        bs_write_ue(b, sh->cabac_init_idc);
    }
    bs_write_se(b, sh->slice_qp_delta);
    if( pps->deblocking_filter_control_present_flag )
    {
        bs_write_ue(b, sh->disable_deblocking_filter_idc);
        if( sh->disable_deblocking_filter_idc != 1 )
        {
            bs_write_se(b, sh->slice_alpha_c0_offset_div2);
            bs_write_se(b, sh->slice_beta_offset_div2);
        }
    }
    if( pps->num_slice_groups_minus1 > 0 &&
       pps->slice_group_map_type >= 3 && pps->slice_group_map_type <= 5)
    {
        int v = intlog2( pps->pic_size_in_map_units_minus1 +  pps->slice_group_change_rate_minus1 + 1 );
        bs_write_u(b, v, sh->slice_group_change_cycle); // FIXME add 2?
    }
    
    //svc specific
    if( !nal->nal_svc_ext->no_inter_layer_pred_flag && nal->nal_svc_ext->quality_id == 0 )
    {
        bs_write_ue(b, sh_svc_ext->ref_layer_dq_id);
        if( sps_subset->sps_svc_ext->inter_layer_deblocking_filter_control_present_flag )
        {
            bs_write_ue(b, sh_svc_ext->disable_inter_layer_deblocking_filter_idc);
            if( sh_svc_ext->disable_inter_layer_deblocking_filter_idc != 1 )
            {
                bs_write_se(b, sh_svc_ext->inter_layer_slice_alpha_c0_offset_div2);
                bs_write_se(b, sh_svc_ext->inter_layer_slice_beta_offset_div2);
            }
        }
        
        bs_write_u1(b, sh_svc_ext->constrained_intra_resampling_flag);
        if( sps_subset->sps_svc_ext->extended_spatial_scalability_idc == 2 )
        {
            if( sps_subset->sps->chroma_format_idc > 0 )
            {
                bs_write_u1(b, sh_svc_ext->ref_layer_chroma_phase_x_plus1_flag);
                bs_write_u(b, 2, sh_svc_ext->ref_layer_chroma_phase_y_plus1);
            }
            
            bs_write_se(b, sh_svc_ext->scaled_ref_layer_left_offset);
            bs_write_se(b, sh_svc_ext->scaled_ref_layer_top_offset);
            bs_write_se(b, sh_svc_ext->scaled_ref_layer_right_offset);
            bs_write_se(b, sh_svc_ext->scaled_ref_layer_bottom_offset);
        }
    }
    
    if( !nal->nal_svc_ext->no_inter_layer_pred_flag )
    {
        bs_write_u1(b, sh_svc_ext->slice_skip_flag);
        if( sh_svc_ext->slice_skip_flag )
        {
            bs_write_ue(b, sh_svc_ext->num_mbs_in_slice_minus1);
        }
        else
        {
            bs_write_u1(b, sh_svc_ext->adaptive_base_mode_flag);
            if( !sh_svc_ext->adaptive_base_mode_flag )
            {
                bs_write_u1(b, sh_svc_ext->default_base_mode_flag);
            }
            if( !sh_svc_ext->default_base_mode_flag )
            {
                bs_write_u1(b, sh_svc_ext->adaptive_motion_prediction_flag);
                if( !sh_svc_ext->adaptive_motion_prediction_flag )
                {
                    bs_write_u1(b, sh_svc_ext->default_motion_prediction_flag);
                }
            }
            bs_write_u1(b, sh_svc_ext->adaptive_residual_prediction_flag);
            if( !sh_svc_ext->adaptive_residual_prediction_flag )
            {
                bs_write_u1(b, sh_svc_ext->default_residual_prediction_flag);
            }
        }
        if( sps_subset->sps_svc_ext->adaptive_tcoeff_level_prediction_flag )
        {
            bs_write_u1(b, sh_svc_ext->tcoeff_level_prediction_flag);
        }
    }
    
    if( !sps_subset->sps_svc_ext->slice_header_restriction_flag && !sh_svc_ext->slice_skip_flag )
    {
        bs_write_u(b, 4, sh_svc_ext->scan_idx_start);
        bs_write_u(b, 4, sh_svc_ext->scan_idx_end);
    }
}

//G.7.3.3.5 Decoded reference base picture marking syntax
void write_dec_ref_base_pic_marking(nal_t* nal, bs_t* b)
{
    bs_write_u1(b, nal->prefix_nal_svc->adaptive_ref_base_pic_marking_mode_flag);
    if( nal->prefix_nal_svc->adaptive_ref_base_pic_marking_mode_flag )
    {
        do {
            bs_write_ue(b, nal->prefix_nal_svc->memory_management_base_control_operation);
            
            if( nal->prefix_nal_svc->memory_management_base_control_operation == 1 )
            {
                bs_write_ue(b, nal->prefix_nal_svc->difference_of_base_pic_nums_minus1);
            }
            if( nal->prefix_nal_svc->memory_management_base_control_operation == 2 )
            {
                bs_write_ue(b, nal->prefix_nal_svc->long_term_base_pic_num);
            }
        } while( nal->prefix_nal_svc->memory_management_base_control_operation != 0 );
    }
}



void read_debug_nal_unit_header_svc_extension(nal_svc_ext_t* nal_svc_ext, bs_t* b);
void read_debug_prefix_nal_unit_svc(nal_t* nal, bs_t* b);
void read_debug_prefix_nal_unit_rbsp(nal_t* nal, bs_t* b);
void read_debug_seq_parameter_set_rbsp(sps_t* sps, bs_t* b);
void read_debug_scaling_list(bs_t* b, int* scalingList, int sizeOfScalingList, int* useDefaultScalingMatrixFlag );
void read_debug_subset_seq_parameter_set_rbsp(sps_subset_t* sps_subset, bs_t* b);
void read_debug_seq_parameter_set_svc_extension(sps_subset_t* sps_subset, bs_t* b);
void read_debug_svc_vui_parameters_extension(sps_svc_ext_t* sps_svc_ext, bs_t* b);
void read_debug_vui_parameters(sps_t* sps, bs_t* b);
void read_debug_hrd_parameters(hrd_t* hrd, bs_t* b);
void read_debug_pic_parameter_set_rbsp(h264_stream_t* h, bs_t* b);
void read_debug_sei_rbsp(h264_stream_t* h, bs_t* b);
void read_debug_sei_message(h264_stream_t* h, bs_t* b);
void read_debug_access_unit_delimiter_rbsp(h264_stream_t* h, bs_t* b);
void read_debug_end_of_seq_rbsp(h264_stream_t* h, bs_t* b);
void read_debug_end_of_stream_rbsp(h264_stream_t* h, bs_t* b);
void read_debug_filler_data_rbsp(h264_stream_t* h, bs_t* b);
void read_debug_slice_layer_rbsp(h264_stream_t* h,  bs_t* b);
void read_debug_rbsp_slice_trailing_bits(h264_stream_t* h, bs_t* b);
void read_debug_rbsp_trailing_bits(bs_t* b);
void read_debug_slice_header(h264_stream_t* h, bs_t* b);
void read_debug_ref_pic_list_reordering(h264_stream_t* h, bs_t* b);
void read_debug_pred_weight_table(h264_stream_t* h, bs_t* b);
void read_debug_dec_ref_pic_marking(h264_stream_t* h, bs_t* b);
void read_debug_slice_header_in_scalable_extension(h264_stream_t* h, bs_t* b);
void read_debug_dec_ref_base_pic_marking(nal_t* nal, bs_t* b);



//7.3.1 NAL unit syntax
int read_debug_nal_unit(h264_stream_t* h, uint8_t* buf, int size)
{
    nal_t* nal = h->nal;

    int nal_size = size;
    int rbsp_size = size;
    uint8_t* rbsp_buf = (uint8_t*)calloc(1, rbsp_size);

    if( 1 )
    {
        int rc = nal_to_rbsp(buf, &nal_size, rbsp_buf, &rbsp_size);

        if (rc < 0) { free(rbsp_buf); return -1; } // handle conversion error
    }

    if( 0 )
    {
        rbsp_size = size*3/4; // NOTE this may have to be slightly smaller (3/4 smaller, worst case) in order to be guaranteed to fit
    }

    bs_t* b = bs_new(rbsp_buf, rbsp_size);
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); int forbidden_zero_bit = bs_read_u(b, 1); printf("forbidden_zero_bit: %d \n", forbidden_zero_bit); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); nal->nal_ref_idc = bs_read_u(b, 2); printf("nal->nal_ref_idc: %d \n", nal->nal_ref_idc); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); nal->nal_unit_type = bs_read_u(b, 5); printf("nal->nal_unit_type: %d \n", nal->nal_unit_type); 
    
    if( nal->nal_unit_type == 14 || nal->nal_unit_type == 21 || nal->nal_unit_type == 20 )
    {
        if( nal->nal_unit_type != 21 )
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); nal->svc_extension_flag = bs_read_u1(b); printf("nal->svc_extension_flag: %d \n", nal->svc_extension_flag); 
        }
        else
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); nal->avc_3d_extension_flag = bs_read_u1(b); printf("nal->avc_3d_extension_flag: %d \n", nal->avc_3d_extension_flag); 
        }
        
        if( nal->svc_extension_flag )
        {
            read_debug_nal_unit_header_svc_extension(nal->nal_svc_ext, b);
        }
    }

    switch ( nal->nal_unit_type )
    {
        case NAL_UNIT_TYPE_CODED_SLICE_IDR:
        case NAL_UNIT_TYPE_CODED_SLICE_NON_IDR:  
        case NAL_UNIT_TYPE_CODED_SLICE_AUX:
            read_debug_slice_layer_rbsp(h, b);
            break;

#ifdef HAVE_SEI
        case NAL_UNIT_TYPE_SEI:
            read_debug_sei_rbsp(h, b);
            read_debug_rbsp_trailing_bits(b);
            break;
#endif

        case NAL_UNIT_TYPE_SPS: 
            read_debug_seq_parameter_set_rbsp(h->sps, b);
            read_debug_rbsp_trailing_bits(b);
            
            if( 1 )
            {
                memcpy(h->sps_table[h->sps->seq_parameter_set_id], h->sps, sizeof(sps_t));
            }

            break;

        case NAL_UNIT_TYPE_PPS:   
            read_debug_pic_parameter_set_rbsp(h, b);
            read_debug_rbsp_trailing_bits(b);
            break;

        case NAL_UNIT_TYPE_AUD:     
            read_debug_access_unit_delimiter_rbsp(h, b); 
            read_debug_rbsp_trailing_bits(b);
            break;

        case NAL_UNIT_TYPE_END_OF_SEQUENCE: 
            read_debug_end_of_seq_rbsp(h, b);
            read_debug_rbsp_trailing_bits(b);
            break;

        case NAL_UNIT_TYPE_END_OF_STREAM: 
            read_debug_end_of_stream_rbsp(h, b);
            read_debug_rbsp_trailing_bits(b);
            break;

        //SVC support
        case NAL_UNIT_TYPE_SUBSET_SPS:
            read_debug_subset_seq_parameter_set_rbsp(h->sps_subset, b);
            read_debug_rbsp_trailing_bits(b);
            
            if( 1 )
            {
                //memcpy(h->sps_subset_table[h->sps_subset->sps->seq_parameter_set_id], h->sps_subset, sizeof(sps_subset_t));
                memcpy(h->sps_subset_table[h->sps_subset->sps->seq_parameter_set_id]->sps, h->sps_subset->sps, sizeof(sps_t));
                memcpy(h->sps_subset_table[h->sps_subset->sps->seq_parameter_set_id]->sps_svc_ext, h->sps_subset->sps_svc_ext, sizeof(sps_svc_ext_t));
                h->sps_subset_table[h->sps_subset->sps->seq_parameter_set_id]->additional_extension2_flag = h->sps_subset->additional_extension2_flag;
            }

            break;
            
        //prefix NAL
        case NAL_UNIT_TYPE_PREFIX_NAL:
            read_debug_prefix_nal_unit_rbsp(h->nal, b);
            read_debug_rbsp_trailing_bits(b);
            break;
            
        //SVC support
        case NAL_UNIT_TYPE_CODED_SLICE_SVC_EXTENSION:            
            read_debug_slice_layer_rbsp(h, b);
            
            break;
            
        case NAL_UNIT_TYPE_FILLER:
        case NAL_UNIT_TYPE_SPS_EXT:
        case NAL_UNIT_TYPE_UNSPECIFIED:
        case NAL_UNIT_TYPE_CODED_SLICE_DATA_PARTITION_A:  
        case NAL_UNIT_TYPE_CODED_SLICE_DATA_PARTITION_B: 
        case NAL_UNIT_TYPE_CODED_SLICE_DATA_PARTITION_C:
        default:
            return -1;
    }

    if (bs_overrun(b)) { bs_free(b); free(rbsp_buf); return -1; }

    if( 0 )
    {
        // now get the actual size used
        rbsp_size = bs_pos(b);

        int rc = rbsp_to_nal(rbsp_buf, &rbsp_size, buf, &nal_size);
        if (rc < 0) { bs_free(b); free(rbsp_buf); return -1; }
    }

    bs_free(b);
    free(rbsp_buf);

    return nal_size;
}

//G.7.3.1.1 NAL unit header SVC extension syntax
void read_debug_nal_unit_header_svc_extension(nal_svc_ext_t* nal_svc_ext, bs_t* b)
{
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); nal_svc_ext->idr_flag = bs_read_u1(b); printf("nal_svc_ext->idr_flag: %d \n", nal_svc_ext->idr_flag); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); nal_svc_ext->priority_id = bs_read_u(b, 6); printf("nal_svc_ext->priority_id: %d \n", nal_svc_ext->priority_id); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); nal_svc_ext->no_inter_layer_pred_flag = bs_read_u1(b); printf("nal_svc_ext->no_inter_layer_pred_flag: %d \n", nal_svc_ext->no_inter_layer_pred_flag); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); nal_svc_ext->dependency_id = bs_read_u(b, 3); printf("nal_svc_ext->dependency_id: %d \n", nal_svc_ext->dependency_id); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); nal_svc_ext->quality_id = bs_read_u(b, 4); printf("nal_svc_ext->quality_id: %d \n", nal_svc_ext->quality_id); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); nal_svc_ext->temporal_id = bs_read_u(b, 3); printf("nal_svc_ext->temporal_id: %d \n", nal_svc_ext->temporal_id); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); nal_svc_ext->use_ref_base_pic_flag = bs_read_u1(b); printf("nal_svc_ext->use_ref_base_pic_flag: %d \n", nal_svc_ext->use_ref_base_pic_flag); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); nal_svc_ext->discardable_flag = bs_read_u1(b); printf("nal_svc_ext->discardable_flag: %d \n", nal_svc_ext->discardable_flag); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); nal_svc_ext->output_flag = bs_read_u1(b); printf("nal_svc_ext->output_flag: %d \n", nal_svc_ext->output_flag); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); nal_svc_ext->reserved_three_2bits = bs_read_u(b, 2); printf("nal_svc_ext->reserved_three_2bits: %d \n", nal_svc_ext->reserved_three_2bits); 
}

//G.7.3.2.12.1 Prefix NAL unit SVC syntax
void read_debug_prefix_nal_unit_svc(nal_t* nal, bs_t* b)
{
    if( nal->nal_ref_idc != 0 )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); nal->prefix_nal_svc->store_ref_base_pic_flag = bs_read_u1(b); printf("nal->prefix_nal_svc->store_ref_base_pic_flag: %d \n", nal->prefix_nal_svc->store_ref_base_pic_flag); 
        if( ( nal->nal_svc_ext->use_ref_base_pic_flag || nal->prefix_nal_svc->store_ref_base_pic_flag ) &&
             !nal->nal_svc_ext->idr_flag )
        {
            read_debug_dec_ref_base_pic_marking( nal, b );
        }
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); nal->prefix_nal_svc->additional_prefix_nal_unit_extension_flag = bs_read_u1(b); printf("nal->prefix_nal_svc->additional_prefix_nal_unit_extension_flag: %d \n", nal->prefix_nal_svc->additional_prefix_nal_unit_extension_flag); 
        if( nal->prefix_nal_svc->additional_prefix_nal_unit_extension_flag )
        {
            while( more_rbsp_data( b ) )
            {
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); nal->prefix_nal_svc->additional_prefix_nal_unit_extension_data_flag = bs_read_u1(b); printf("nal->prefix_nal_svc->additional_prefix_nal_unit_extension_data_flag: %d \n", nal->prefix_nal_svc->additional_prefix_nal_unit_extension_data_flag); 
            }
        }
    }
    else if( more_rbsp_data( b ) )
    {
        while( more_rbsp_data( b ) )
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); nal->prefix_nal_svc->additional_prefix_nal_unit_extension_data_flag = bs_read_u1(b); printf("nal->prefix_nal_svc->additional_prefix_nal_unit_extension_data_flag: %d \n", nal->prefix_nal_svc->additional_prefix_nal_unit_extension_data_flag); 
        }
    }
}

//7.3.2.12 Prefix NAL unit RBSP syntax
void read_debug_prefix_nal_unit_rbsp(nal_t* nal, bs_t* b)
{
    if( nal->svc_extension_flag )
    {
        read_debug_prefix_nal_unit_svc(nal, b);
    }
}

//7.3.2.1 Sequence parameter set RBSP syntax
void read_debug_seq_parameter_set_rbsp(sps_t* sps, bs_t* b)
{
    int i;

    if( 1 )
    {
        memset(sps, 0, sizeof(sps_t));
        sps->chroma_format_idc = 1; 
    }
 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->profile_idc = bs_read_u8(b); printf("sps->profile_idc: %d \n", sps->profile_idc); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->constraint_set0_flag = bs_read_u1(b); printf("sps->constraint_set0_flag: %d \n", sps->constraint_set0_flag); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->constraint_set1_flag = bs_read_u1(b); printf("sps->constraint_set1_flag: %d \n", sps->constraint_set1_flag); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->constraint_set2_flag = bs_read_u1(b); printf("sps->constraint_set2_flag: %d \n", sps->constraint_set2_flag); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->constraint_set3_flag = bs_read_u1(b); printf("sps->constraint_set3_flag: %d \n", sps->constraint_set3_flag); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->constraint_set4_flag = bs_read_u1(b); printf("sps->constraint_set4_flag: %d \n", sps->constraint_set4_flag); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->constraint_set5_flag = bs_read_u1(b); printf("sps->constraint_set5_flag: %d \n", sps->constraint_set5_flag); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); int reserved_zero_2bits = bs_read_u(b, 2); printf("reserved_zero_2bits: %d \n", reserved_zero_2bits); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->level_idc = bs_read_u8(b); printf("sps->level_idc: %d \n", sps->level_idc); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->seq_parameter_set_id = bs_read_ue(b); printf("sps->seq_parameter_set_id: %d \n", sps->seq_parameter_set_id); 

    if( sps->profile_idc == 100 || sps->profile_idc == 110 ||
        sps->profile_idc == 122 || sps->profile_idc == 244 ||
        sps->profile_idc == 44 || sps->profile_idc == 83 ||
        sps->profile_idc == 86 || sps->profile_idc == 118 ||
        sps->profile_idc == 128 || sps->profile_idc == 138 ||
        sps->profile_idc == 139 || sps->profile_idc == 134
       )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->chroma_format_idc = bs_read_ue(b); printf("sps->chroma_format_idc: %d \n", sps->chroma_format_idc); 
        if( sps->chroma_format_idc == 3 )
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->residual_colour_transform_flag = bs_read_u1(b); printf("sps->residual_colour_transform_flag: %d \n", sps->residual_colour_transform_flag); 
        }
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->bit_depth_luma_minus8 = bs_read_ue(b); printf("sps->bit_depth_luma_minus8: %d \n", sps->bit_depth_luma_minus8); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->bit_depth_chroma_minus8 = bs_read_ue(b); printf("sps->bit_depth_chroma_minus8: %d \n", sps->bit_depth_chroma_minus8); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->qpprime_y_zero_transform_bypass_flag = bs_read_u1(b); printf("sps->qpprime_y_zero_transform_bypass_flag: %d \n", sps->qpprime_y_zero_transform_bypass_flag); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->seq_scaling_matrix_present_flag = bs_read_u1(b); printf("sps->seq_scaling_matrix_present_flag: %d \n", sps->seq_scaling_matrix_present_flag); 
        if( sps->seq_scaling_matrix_present_flag )
        {
            for( i = 0; i < 8; i++ )
            {
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->seq_scaling_list_present_flag[ i ] = bs_read_u1(b); printf("sps->seq_scaling_list_present_flag[ i ]: %d \n", sps->seq_scaling_list_present_flag[ i ]); 
                if( sps->seq_scaling_list_present_flag[ i ] )
                {
                    if( i < 6 )
                    {
                        read_debug_scaling_list( b, sps->ScalingList4x4[ i ], 16,
                                                 &( sps->UseDefaultScalingMatrix4x4Flag[ i ] ) );
                    }
                    else
                    {
                        read_debug_scaling_list( b, sps->ScalingList8x8[ i - 6 ], 64,
                                                 &( sps->UseDefaultScalingMatrix8x8Flag[ i - 6 ] ) );
                    }
                }
            }
        }
    }
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->log2_max_frame_num_minus4 = bs_read_ue(b); printf("sps->log2_max_frame_num_minus4: %d \n", sps->log2_max_frame_num_minus4); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->pic_order_cnt_type = bs_read_ue(b); printf("sps->pic_order_cnt_type: %d \n", sps->pic_order_cnt_type); 
    if( sps->pic_order_cnt_type == 0 )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->log2_max_pic_order_cnt_lsb_minus4 = bs_read_ue(b); printf("sps->log2_max_pic_order_cnt_lsb_minus4: %d \n", sps->log2_max_pic_order_cnt_lsb_minus4); 
    }
    else if( sps->pic_order_cnt_type == 1 )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->delta_pic_order_always_zero_flag = bs_read_u1(b); printf("sps->delta_pic_order_always_zero_flag: %d \n", sps->delta_pic_order_always_zero_flag); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->offset_for_non_ref_pic = bs_read_se(b); printf("sps->offset_for_non_ref_pic: %d \n", sps->offset_for_non_ref_pic); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->offset_for_top_to_bottom_field = bs_read_se(b); printf("sps->offset_for_top_to_bottom_field: %d \n", sps->offset_for_top_to_bottom_field); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->num_ref_frames_in_pic_order_cnt_cycle = bs_read_ue(b); printf("sps->num_ref_frames_in_pic_order_cnt_cycle: %d \n", sps->num_ref_frames_in_pic_order_cnt_cycle); 
        for( i = 0; i < sps->num_ref_frames_in_pic_order_cnt_cycle; i++ )
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->offset_for_ref_frame[ i ] = bs_read_se(b); printf("sps->offset_for_ref_frame[ i ]: %d \n", sps->offset_for_ref_frame[ i ]); 
        }
    }
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->num_ref_frames = bs_read_ue(b); printf("sps->num_ref_frames: %d \n", sps->num_ref_frames); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->gaps_in_frame_num_value_allowed_flag = bs_read_u1(b); printf("sps->gaps_in_frame_num_value_allowed_flag: %d \n", sps->gaps_in_frame_num_value_allowed_flag); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->pic_width_in_mbs_minus1 = bs_read_ue(b); printf("sps->pic_width_in_mbs_minus1: %d \n", sps->pic_width_in_mbs_minus1); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->pic_height_in_map_units_minus1 = bs_read_ue(b); printf("sps->pic_height_in_map_units_minus1: %d \n", sps->pic_height_in_map_units_minus1); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->frame_mbs_only_flag = bs_read_u1(b); printf("sps->frame_mbs_only_flag: %d \n", sps->frame_mbs_only_flag); 
    if( !sps->frame_mbs_only_flag )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->mb_adaptive_frame_field_flag = bs_read_u1(b); printf("sps->mb_adaptive_frame_field_flag: %d \n", sps->mb_adaptive_frame_field_flag); 
    }
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->direct_8x8_inference_flag = bs_read_u1(b); printf("sps->direct_8x8_inference_flag: %d \n", sps->direct_8x8_inference_flag); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->frame_cropping_flag = bs_read_u1(b); printf("sps->frame_cropping_flag: %d \n", sps->frame_cropping_flag); 
    if( sps->frame_cropping_flag )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->frame_crop_left_offset = bs_read_ue(b); printf("sps->frame_crop_left_offset: %d \n", sps->frame_crop_left_offset); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->frame_crop_right_offset = bs_read_ue(b); printf("sps->frame_crop_right_offset: %d \n", sps->frame_crop_right_offset); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->frame_crop_top_offset = bs_read_ue(b); printf("sps->frame_crop_top_offset: %d \n", sps->frame_crop_top_offset); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->frame_crop_bottom_offset = bs_read_ue(b); printf("sps->frame_crop_bottom_offset: %d \n", sps->frame_crop_bottom_offset); 
    }
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->vui_parameters_present_flag = bs_read_u1(b); printf("sps->vui_parameters_present_flag: %d \n", sps->vui_parameters_present_flag); 
    if( sps->vui_parameters_present_flag )
    {
        read_debug_vui_parameters(sps, b);
    }
}

//7.3.2.1.1 Scaling list syntax
void read_debug_scaling_list(bs_t* b, int* scalingList, int sizeOfScalingList, int* useDefaultScalingMatrixFlag )
{
    // NOTE need to be able to set useDefaultScalingMatrixFlag when reading, hence passing as pointer
    int lastScale = 8;
    int nextScale = 8;
    int delta_scale;
    for( int j = 0; j < sizeOfScalingList; j++ )
    {
        if( nextScale != 0 )
        {
            if( 0 )
            {
                nextScale = scalingList[ j ];
                if (useDefaultScalingMatrixFlag[0]) { nextScale = 0; }
                delta_scale = (nextScale - lastScale) % 256 ;
            }

            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); delta_scale = bs_read_se(b); printf("delta_scale: %d \n", delta_scale); 

            if( 1 )
            {
                nextScale = ( lastScale + delta_scale + 256 ) % 256;
                useDefaultScalingMatrixFlag[0] = ( j == 0 && nextScale == 0 );
            }
        }
        if( 1 )
        {
            scalingList[ j ] = ( nextScale == 0 ) ? lastScale : nextScale;
        }
        lastScale = scalingList[ j ];
    }
}

//7.3.2.1.3 Subset sequence parameter set RBSP syntax
void read_debug_subset_seq_parameter_set_rbsp(sps_subset_t* sps_subset, bs_t* b)
{
    read_debug_seq_parameter_set_rbsp(sps_subset->sps, b);
    
    switch( sps_subset->sps->profile_idc )
    {
        case 83:
        case 86:
            read_debug_seq_parameter_set_svc_extension(sps_subset, b); /* specified in Annex G */
            
            sps_svc_ext_t* sps_svc_ext = sps_subset->sps_svc_ext;
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps_svc_ext->svc_vui_parameters_present_flag = bs_read_u1(b); printf("sps_svc_ext->svc_vui_parameters_present_flag: %d \n", sps_svc_ext->svc_vui_parameters_present_flag); 
            
            if( sps_svc_ext->svc_vui_parameters_present_flag )
            {
                read_debug_svc_vui_parameters_extension(sps_svc_ext,b); /* specified in Annex G */
            }
            break;
        default:
            break;
    }
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps_subset->additional_extension2_flag = bs_read_u1(b); printf("sps_subset->additional_extension2_flag: %d \n", sps_subset->additional_extension2_flag); 
    if( sps_subset->additional_extension2_flag )
    {
        while( more_rbsp_data( b ) )
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps_subset->additional_extension2_flag = bs_read_u1(b); printf("sps_subset->additional_extension2_flag: %d \n", sps_subset->additional_extension2_flag); 
        }
    }
    
}

//Appendix G.7.3.2.1.4 Sequence parameter set SVC extension syntax
void read_debug_seq_parameter_set_svc_extension(sps_subset_t* sps_subset, bs_t* b)
{
    sps_svc_ext_t* sps_svc_ext = sps_subset->sps_svc_ext;
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps_svc_ext->inter_layer_deblocking_filter_control_present_flag = bs_read_u1(b); printf("sps_svc_ext->inter_layer_deblocking_filter_control_present_flag: %d \n", sps_svc_ext->inter_layer_deblocking_filter_control_present_flag); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps_svc_ext->extended_spatial_scalability_idc = bs_read_u(b, 2); printf("sps_svc_ext->extended_spatial_scalability_idc: %d \n", sps_svc_ext->extended_spatial_scalability_idc); 
    if( sps_subset->sps->chroma_format_idc == 1 || sps_subset->sps->chroma_format_idc == 2 )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps_svc_ext->chroma_phase_x_plus1_flag = bs_read_u1(b); printf("sps_svc_ext->chroma_phase_x_plus1_flag: %d \n", sps_svc_ext->chroma_phase_x_plus1_flag); 
    }
    if( sps_subset->sps->chroma_format_idc == 1 )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps_svc_ext->chroma_phase_y_plus1 = bs_read_u(b, 2); printf("sps_svc_ext->chroma_phase_y_plus1: %d \n", sps_svc_ext->chroma_phase_y_plus1); 
    }
    if( sps_svc_ext->extended_spatial_scalability_idc )
    {
        if( sps_subset->sps->chroma_format_idc > 0 )
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps_svc_ext->seq_ref_layer_chroma_phase_x_plus1_flag = bs_read_u1(b); printf("sps_svc_ext->seq_ref_layer_chroma_phase_x_plus1_flag: %d \n", sps_svc_ext->seq_ref_layer_chroma_phase_x_plus1_flag); 
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps_svc_ext->seq_ref_layer_chroma_phase_y_plus1 = bs_read_u(b, 2); printf("sps_svc_ext->seq_ref_layer_chroma_phase_y_plus1: %d \n", sps_svc_ext->seq_ref_layer_chroma_phase_y_plus1); 
        }
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps_svc_ext->seq_scaled_ref_layer_left_offset = bs_read_se(b); printf("sps_svc_ext->seq_scaled_ref_layer_left_offset: %d \n", sps_svc_ext->seq_scaled_ref_layer_left_offset); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps_svc_ext->seq_scaled_ref_layer_top_offset = bs_read_se(b); printf("sps_svc_ext->seq_scaled_ref_layer_top_offset: %d \n", sps_svc_ext->seq_scaled_ref_layer_top_offset); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps_svc_ext->seq_scaled_ref_layer_right_offset = bs_read_se(b); printf("sps_svc_ext->seq_scaled_ref_layer_right_offset: %d \n", sps_svc_ext->seq_scaled_ref_layer_right_offset); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps_svc_ext->seq_scaled_ref_layer_bottom_offset = bs_read_se(b); printf("sps_svc_ext->seq_scaled_ref_layer_bottom_offset: %d \n", sps_svc_ext->seq_scaled_ref_layer_bottom_offset); 
    }
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps_svc_ext->seq_tcoeff_level_prediction_flag = bs_read_u1(b); printf("sps_svc_ext->seq_tcoeff_level_prediction_flag: %d \n", sps_svc_ext->seq_tcoeff_level_prediction_flag); 
    if( sps_svc_ext->seq_tcoeff_level_prediction_flag )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps_svc_ext->adaptive_tcoeff_level_prediction_flag = bs_read_u1(b); printf("sps_svc_ext->adaptive_tcoeff_level_prediction_flag: %d \n", sps_svc_ext->adaptive_tcoeff_level_prediction_flag); 
    }
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps_svc_ext->slice_header_restriction_flag = bs_read_u1(b); printf("sps_svc_ext->slice_header_restriction_flag: %d \n", sps_svc_ext->slice_header_restriction_flag); 
}

//Appendix G.14.1 SVC VUI parameters extension syntax
void read_debug_svc_vui_parameters_extension(sps_svc_ext_t* sps_svc_ext, bs_t* b)
{
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps_svc_ext->vui.vui_ext_num_entries_minus1 = bs_read_ue(b); printf("sps_svc_ext->vui.vui_ext_num_entries_minus1: %d \n", sps_svc_ext->vui.vui_ext_num_entries_minus1); 
    for( int i = 0; i <= sps_svc_ext->vui.vui_ext_num_entries_minus1; i++ )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps_svc_ext->vui.vui_ext_dependency_id[i] = bs_read_u(b, 3); printf("sps_svc_ext->vui.vui_ext_dependency_id[i]: %d \n", sps_svc_ext->vui.vui_ext_dependency_id[i]); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps_svc_ext->vui.vui_ext_quality_id[i] = bs_read_u(b, 4); printf("sps_svc_ext->vui.vui_ext_quality_id[i]: %d \n", sps_svc_ext->vui.vui_ext_quality_id[i]); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps_svc_ext->vui.vui_ext_temporal_id[i] = bs_read_u(b, 3); printf("sps_svc_ext->vui.vui_ext_temporal_id[i]: %d \n", sps_svc_ext->vui.vui_ext_temporal_id[i]); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps_svc_ext->vui.vui_ext_timing_info_present_flag[i] = bs_read_u1(b); printf("sps_svc_ext->vui.vui_ext_timing_info_present_flag[i]: %d \n", sps_svc_ext->vui.vui_ext_timing_info_present_flag[i]); 
        if( sps_svc_ext->vui.vui_ext_timing_info_present_flag[i] )
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps_svc_ext->vui.vui_ext_num_units_in_tick[i] = bs_read_u(b, 32); printf("sps_svc_ext->vui.vui_ext_num_units_in_tick[i]: %d \n", sps_svc_ext->vui.vui_ext_num_units_in_tick[i]); 
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps_svc_ext->vui.vui_ext_time_scale[i] = bs_read_u(b, 32); printf("sps_svc_ext->vui.vui_ext_time_scale[i]: %d \n", sps_svc_ext->vui.vui_ext_time_scale[i]); 
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps_svc_ext->vui.vui_ext_fixed_frame_rate_flag[i] = bs_read_u1(b); printf("sps_svc_ext->vui.vui_ext_fixed_frame_rate_flag[i]: %d \n", sps_svc_ext->vui.vui_ext_fixed_frame_rate_flag[i]); 
        }

        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps_svc_ext->vui.vui_ext_nal_hrd_parameters_present_flag[i] = bs_read_u1(b); printf("sps_svc_ext->vui.vui_ext_nal_hrd_parameters_present_flag[i]: %d \n", sps_svc_ext->vui.vui_ext_nal_hrd_parameters_present_flag[i]); 
        if( sps_svc_ext->vui.vui_ext_nal_hrd_parameters_present_flag[i] )
        {
            read_debug_hrd_parameters(&sps_svc_ext->hrd_vcl[i], b);
        }
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps_svc_ext->vui.vui_ext_vcl_hrd_parameters_present_flag[i] = bs_read_u1(b); printf("sps_svc_ext->vui.vui_ext_vcl_hrd_parameters_present_flag[i]: %d \n", sps_svc_ext->vui.vui_ext_vcl_hrd_parameters_present_flag[i]); 
        if( sps_svc_ext->vui.vui_ext_vcl_hrd_parameters_present_flag[i] )
        {
            read_debug_hrd_parameters(&sps_svc_ext->hrd_nal[i], b);
        }
        
        if( sps_svc_ext->vui.vui_ext_nal_hrd_parameters_present_flag[i] ||
            sps_svc_ext->vui.vui_ext_vcl_hrd_parameters_present_flag[i] )
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps_svc_ext->vui.vui_ext_low_delay_hrd_flag[i] = bs_read_u1(b); printf("sps_svc_ext->vui.vui_ext_low_delay_hrd_flag[i]: %d \n", sps_svc_ext->vui.vui_ext_low_delay_hrd_flag[i]); 
        }
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps_svc_ext->vui.vui_ext_pic_struct_present_flag[i] = bs_read_u1(b); printf("sps_svc_ext->vui.vui_ext_pic_struct_present_flag[i]: %d \n", sps_svc_ext->vui.vui_ext_pic_struct_present_flag[i]); 
    }
}

//Appendix E.1.1 VUI parameters syntax
void read_debug_vui_parameters(sps_t* sps, bs_t* b)
{
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->vui.aspect_ratio_info_present_flag = bs_read_u1(b); printf("sps->vui.aspect_ratio_info_present_flag: %d \n", sps->vui.aspect_ratio_info_present_flag); 
    if( sps->vui.aspect_ratio_info_present_flag )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->vui.aspect_ratio_idc = bs_read_u8(b); printf("sps->vui.aspect_ratio_idc: %d \n", sps->vui.aspect_ratio_idc); 
        if( sps->vui.aspect_ratio_idc == SAR_Extended )
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->vui.sar_width = bs_read_u(b, 16); printf("sps->vui.sar_width: %d \n", sps->vui.sar_width); 
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->vui.sar_height = bs_read_u(b, 16); printf("sps->vui.sar_height: %d \n", sps->vui.sar_height); 
        }
    }
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->vui.overscan_info_present_flag = bs_read_u1(b); printf("sps->vui.overscan_info_present_flag: %d \n", sps->vui.overscan_info_present_flag); 
    if( sps->vui.overscan_info_present_flag )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->vui.overscan_appropriate_flag = bs_read_u1(b); printf("sps->vui.overscan_appropriate_flag: %d \n", sps->vui.overscan_appropriate_flag); 
    }
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->vui.video_signal_type_present_flag = bs_read_u1(b); printf("sps->vui.video_signal_type_present_flag: %d \n", sps->vui.video_signal_type_present_flag); 
    if( sps->vui.video_signal_type_present_flag )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->vui.video_format = bs_read_u(b, 3); printf("sps->vui.video_format: %d \n", sps->vui.video_format); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->vui.video_full_range_flag = bs_read_u1(b); printf("sps->vui.video_full_range_flag: %d \n", sps->vui.video_full_range_flag); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->vui.colour_description_present_flag = bs_read_u1(b); printf("sps->vui.colour_description_present_flag: %d \n", sps->vui.colour_description_present_flag); 
        if( sps->vui.colour_description_present_flag )
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->vui.colour_primaries = bs_read_u8(b); printf("sps->vui.colour_primaries: %d \n", sps->vui.colour_primaries); 
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->vui.transfer_characteristics = bs_read_u8(b); printf("sps->vui.transfer_characteristics: %d \n", sps->vui.transfer_characteristics); 
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->vui.matrix_coefficients = bs_read_u8(b); printf("sps->vui.matrix_coefficients: %d \n", sps->vui.matrix_coefficients); 
        }
    }
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->vui.chroma_loc_info_present_flag = bs_read_u1(b); printf("sps->vui.chroma_loc_info_present_flag: %d \n", sps->vui.chroma_loc_info_present_flag); 
    if( sps->vui.chroma_loc_info_present_flag )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->vui.chroma_sample_loc_type_top_field = bs_read_ue(b); printf("sps->vui.chroma_sample_loc_type_top_field: %d \n", sps->vui.chroma_sample_loc_type_top_field); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->vui.chroma_sample_loc_type_bottom_field = bs_read_ue(b); printf("sps->vui.chroma_sample_loc_type_bottom_field: %d \n", sps->vui.chroma_sample_loc_type_bottom_field); 
    }
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->vui.timing_info_present_flag = bs_read_u1(b); printf("sps->vui.timing_info_present_flag: %d \n", sps->vui.timing_info_present_flag); 
    if( sps->vui.timing_info_present_flag )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->vui.num_units_in_tick = bs_read_u(b, 32); printf("sps->vui.num_units_in_tick: %d \n", sps->vui.num_units_in_tick); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->vui.time_scale = bs_read_u(b, 32); printf("sps->vui.time_scale: %d \n", sps->vui.time_scale); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->vui.fixed_frame_rate_flag = bs_read_u1(b); printf("sps->vui.fixed_frame_rate_flag: %d \n", sps->vui.fixed_frame_rate_flag); 
    }
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->vui.nal_hrd_parameters_present_flag = bs_read_u1(b); printf("sps->vui.nal_hrd_parameters_present_flag: %d \n", sps->vui.nal_hrd_parameters_present_flag); 
    if( sps->vui.nal_hrd_parameters_present_flag )
    {
        read_debug_hrd_parameters(&sps->hrd_nal, b);
    }
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->vui.vcl_hrd_parameters_present_flag = bs_read_u1(b); printf("sps->vui.vcl_hrd_parameters_present_flag: %d \n", sps->vui.vcl_hrd_parameters_present_flag); 
    if( sps->vui.vcl_hrd_parameters_present_flag )
    {
        read_debug_hrd_parameters(&sps->hrd_vcl, b);
    }
    if( sps->vui.nal_hrd_parameters_present_flag || sps->vui.vcl_hrd_parameters_present_flag )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->vui.low_delay_hrd_flag = bs_read_u1(b); printf("sps->vui.low_delay_hrd_flag: %d \n", sps->vui.low_delay_hrd_flag); 
    }
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->vui.pic_struct_present_flag = bs_read_u1(b); printf("sps->vui.pic_struct_present_flag: %d \n", sps->vui.pic_struct_present_flag); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->vui.bitstream_restriction_flag = bs_read_u1(b); printf("sps->vui.bitstream_restriction_flag: %d \n", sps->vui.bitstream_restriction_flag); 
    if( sps->vui.bitstream_restriction_flag )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->vui.motion_vectors_over_pic_boundaries_flag = bs_read_u1(b); printf("sps->vui.motion_vectors_over_pic_boundaries_flag: %d \n", sps->vui.motion_vectors_over_pic_boundaries_flag); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->vui.max_bytes_per_pic_denom = bs_read_ue(b); printf("sps->vui.max_bytes_per_pic_denom: %d \n", sps->vui.max_bytes_per_pic_denom); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->vui.max_bits_per_mb_denom = bs_read_ue(b); printf("sps->vui.max_bits_per_mb_denom: %d \n", sps->vui.max_bits_per_mb_denom); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->vui.log2_max_mv_length_horizontal = bs_read_ue(b); printf("sps->vui.log2_max_mv_length_horizontal: %d \n", sps->vui.log2_max_mv_length_horizontal); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->vui.log2_max_mv_length_vertical = bs_read_ue(b); printf("sps->vui.log2_max_mv_length_vertical: %d \n", sps->vui.log2_max_mv_length_vertical); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->vui.num_reorder_frames = bs_read_ue(b); printf("sps->vui.num_reorder_frames: %d \n", sps->vui.num_reorder_frames); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sps->vui.max_dec_frame_buffering = bs_read_ue(b); printf("sps->vui.max_dec_frame_buffering: %d \n", sps->vui.max_dec_frame_buffering); 
    }
}


//Appendix E.1.2 HRD parameters syntax
void read_debug_hrd_parameters(hrd_t* hrd, bs_t* b)
{
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); hrd->cpb_cnt_minus1 = bs_read_ue(b); printf("hrd->cpb_cnt_minus1: %d \n", hrd->cpb_cnt_minus1); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); hrd->bit_rate_scale = bs_read_u(b, 4); printf("hrd->bit_rate_scale: %d \n", hrd->bit_rate_scale); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); hrd->cpb_size_scale = bs_read_u(b, 4); printf("hrd->cpb_size_scale: %d \n", hrd->cpb_size_scale); 
    for( int SchedSelIdx = 0; SchedSelIdx <= hrd->cpb_cnt_minus1; SchedSelIdx++ )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); hrd->bit_rate_value_minus1[ SchedSelIdx ] = bs_read_ue(b); printf("hrd->bit_rate_value_minus1[ SchedSelIdx ]: %d \n", hrd->bit_rate_value_minus1[ SchedSelIdx ]); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); hrd->cpb_size_value_minus1[ SchedSelIdx ] = bs_read_ue(b); printf("hrd->cpb_size_value_minus1[ SchedSelIdx ]: %d \n", hrd->cpb_size_value_minus1[ SchedSelIdx ]); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); hrd->cbr_flag[ SchedSelIdx ] = bs_read_u1(b); printf("hrd->cbr_flag[ SchedSelIdx ]: %d \n", hrd->cbr_flag[ SchedSelIdx ]); 
    }
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); hrd->initial_cpb_removal_delay_length_minus1 = bs_read_u(b, 5); printf("hrd->initial_cpb_removal_delay_length_minus1: %d \n", hrd->initial_cpb_removal_delay_length_minus1); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); hrd->cpb_removal_delay_length_minus1 = bs_read_u(b, 5); printf("hrd->cpb_removal_delay_length_minus1: %d \n", hrd->cpb_removal_delay_length_minus1); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); hrd->dpb_output_delay_length_minus1 = bs_read_u(b, 5); printf("hrd->dpb_output_delay_length_minus1: %d \n", hrd->dpb_output_delay_length_minus1); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); hrd->time_offset_length = bs_read_u(b, 5); printf("hrd->time_offset_length: %d \n", hrd->time_offset_length); 
}


/*
UNIMPLEMENTED
//7.3.2.1.2 Sequence parameter set extension RBSP syntax
int read_debug_seq_parameter_set_extension_rbsp(bs_t* b, sps_ext_t* sps_ext) {
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); seq_parameter_set_id = bs_read_ue(b); printf("seq_parameter_set_id: %d \n", seq_parameter_set_id); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); aux_format_idc = bs_read_ue(b); printf("aux_format_idc: %d \n", aux_format_idc); 
    if( aux_format_idc != 0 ) {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); bit_depth_aux_minus8 = bs_read_ue(b); printf("bit_depth_aux_minus8: %d \n", bit_depth_aux_minus8); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); alpha_incr_flag = bs_read_u1(b); printf("alpha_incr_flag: %d \n", alpha_incr_flag); 
        alpha_opaque_value = bs_read_debug_u(v);
        alpha_transparent_value = bs_read_debug_u(v);
    }
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); additional_extension_flag = bs_read_u1(b); printf("additional_extension_flag: %d \n", additional_extension_flag); 
    read_debug_rbsp_trailing_bits();
}
*/

//7.3.2.2 Picture parameter set RBSP syntax
void read_debug_pic_parameter_set_rbsp(h264_stream_t* h, bs_t* b)
{
    pps_t* pps = h->pps;
    if( 1 )
    {
        memset(pps, 0, sizeof(pps_t));
    }

    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); pps->pic_parameter_set_id = bs_read_ue(b); printf("pps->pic_parameter_set_id: %d \n", pps->pic_parameter_set_id); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); pps->seq_parameter_set_id = bs_read_ue(b); printf("pps->seq_parameter_set_id: %d \n", pps->seq_parameter_set_id); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); pps->entropy_coding_mode_flag = bs_read_u1(b); printf("pps->entropy_coding_mode_flag: %d \n", pps->entropy_coding_mode_flag); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); pps->pic_order_present_flag = bs_read_u1(b); printf("pps->pic_order_present_flag: %d \n", pps->pic_order_present_flag); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); pps->num_slice_groups_minus1 = bs_read_ue(b); printf("pps->num_slice_groups_minus1: %d \n", pps->num_slice_groups_minus1); 

    if( pps->num_slice_groups_minus1 > 0 )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); pps->slice_group_map_type = bs_read_ue(b); printf("pps->slice_group_map_type: %d \n", pps->slice_group_map_type); 
        if( pps->slice_group_map_type == 0 )
        {
            for( int i_group = 0; i_group <= pps->num_slice_groups_minus1; i_group++ )
            {
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); pps->run_length_minus1[ i_group ] = bs_read_ue(b); printf("pps->run_length_minus1[ i_group ]: %d \n", pps->run_length_minus1[ i_group ]); 
            }
        }
        else if( pps->slice_group_map_type == 2 )
        {
            for( int i_group = 0; i_group < pps->num_slice_groups_minus1; i_group++ )
            {
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); pps->top_left[ i_group ] = bs_read_ue(b); printf("pps->top_left[ i_group ]: %d \n", pps->top_left[ i_group ]); 
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); pps->bottom_right[ i_group ] = bs_read_ue(b); printf("pps->bottom_right[ i_group ]: %d \n", pps->bottom_right[ i_group ]); 
            }
        }
        else if( pps->slice_group_map_type == 3 ||
                 pps->slice_group_map_type == 4 ||
                 pps->slice_group_map_type == 5 )
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); pps->slice_group_change_direction_flag = bs_read_u1(b); printf("pps->slice_group_change_direction_flag: %d \n", pps->slice_group_change_direction_flag); 
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); pps->slice_group_change_rate_minus1 = bs_read_ue(b); printf("pps->slice_group_change_rate_minus1: %d \n", pps->slice_group_change_rate_minus1); 
        }
        else if( pps->slice_group_map_type == 6 )
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); pps->pic_size_in_map_units_minus1 = bs_read_ue(b); printf("pps->pic_size_in_map_units_minus1: %d \n", pps->pic_size_in_map_units_minus1); 
            for( int i = 0; i <= pps->pic_size_in_map_units_minus1; i++ )
            {
                int v = intlog2( pps->num_slice_groups_minus1 + 1 );
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); pps->slice_group_id[ i ] = bs_read_u(b, v); printf("pps->slice_group_id[ i ]: %d \n", pps->slice_group_id[ i ]); 
            }
        }
    }
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); pps->num_ref_idx_l0_active_minus1 = bs_read_ue(b); printf("pps->num_ref_idx_l0_active_minus1: %d \n", pps->num_ref_idx_l0_active_minus1); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); pps->num_ref_idx_l1_active_minus1 = bs_read_ue(b); printf("pps->num_ref_idx_l1_active_minus1: %d \n", pps->num_ref_idx_l1_active_minus1); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); pps->weighted_pred_flag = bs_read_u1(b); printf("pps->weighted_pred_flag: %d \n", pps->weighted_pred_flag); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); pps->weighted_bipred_idc = bs_read_u(b, 2); printf("pps->weighted_bipred_idc: %d \n", pps->weighted_bipred_idc); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); pps->pic_init_qp_minus26 = bs_read_se(b); printf("pps->pic_init_qp_minus26: %d \n", pps->pic_init_qp_minus26); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); pps->pic_init_qs_minus26 = bs_read_se(b); printf("pps->pic_init_qs_minus26: %d \n", pps->pic_init_qs_minus26); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); pps->chroma_qp_index_offset = bs_read_se(b); printf("pps->chroma_qp_index_offset: %d \n", pps->chroma_qp_index_offset); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); pps->deblocking_filter_control_present_flag = bs_read_u1(b); printf("pps->deblocking_filter_control_present_flag: %d \n", pps->deblocking_filter_control_present_flag); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); pps->constrained_intra_pred_flag = bs_read_u1(b); printf("pps->constrained_intra_pred_flag: %d \n", pps->constrained_intra_pred_flag); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); pps->redundant_pic_cnt_present_flag = bs_read_u1(b); printf("pps->redundant_pic_cnt_present_flag: %d \n", pps->redundant_pic_cnt_present_flag); 

    int have_more_data = 0;
    if( 1 ) { have_more_data = more_rbsp_data(b); }
    if( 0 )
    {
        have_more_data = pps->transform_8x8_mode_flag | pps->pic_scaling_matrix_present_flag | pps->second_chroma_qp_index_offset != 0;
    }

    if( have_more_data )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); pps->transform_8x8_mode_flag = bs_read_u1(b); printf("pps->transform_8x8_mode_flag: %d \n", pps->transform_8x8_mode_flag); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); pps->pic_scaling_matrix_present_flag = bs_read_u1(b); printf("pps->pic_scaling_matrix_present_flag: %d \n", pps->pic_scaling_matrix_present_flag); 
        if( pps->pic_scaling_matrix_present_flag )
        {
            for( int i = 0; i < 6 + 2* pps->transform_8x8_mode_flag; i++ )
            {
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); pps->pic_scaling_list_present_flag[ i ] = bs_read_u1(b); printf("pps->pic_scaling_list_present_flag[ i ]: %d \n", pps->pic_scaling_list_present_flag[ i ]); 
                if( pps->pic_scaling_list_present_flag[ i ] )
                {
                    if( i < 6 )
                    {
                        read_debug_scaling_list( b, pps->ScalingList4x4[ i ], 16,
                                                 &( pps->UseDefaultScalingMatrix4x4Flag[ i ] ) );
                    }
                    else
                    {
                        read_debug_scaling_list( b, pps->ScalingList8x8[ i - 6 ], 64,
                                                 &( pps->UseDefaultScalingMatrix8x8Flag[ i - 6 ] ) );
                    }
                }
            }
        }
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); pps->second_chroma_qp_index_offset = bs_read_se(b); printf("pps->second_chroma_qp_index_offset: %d \n", pps->second_chroma_qp_index_offset); 
    }

    if( 1 )
    {
        memcpy(h->pps_table[pps->pic_parameter_set_id], h->pps, sizeof(pps_t));
    }
}

#ifdef HAVE_SEI
//7.3.2.3 Supplemental enhancement information RBSP syntax
void read_debug_sei_rbsp(h264_stream_t* h, bs_t* b)
{
    if( 1 )
    {
        for( int i = 0; i < h->num_seis; i++ )
        {
            sei_free(h->seis[i]);
        }
    
        h->num_seis = 0;
        do {
            h->num_seis++;
            h->seis = (sei_t**)realloc(h->seis, h->num_seis * sizeof(sei_t*));
            h->seis[h->num_seis - 1] = sei_new();
            h->sei = h->seis[h->num_seis - 1];
            read_debug_sei_message(h, b);
        } while( more_rbsp_data(b) );
    }

    if( 0 )
    {
        for (int i = 0; i < h->num_seis; i++)
        {
            h->sei = h->seis[i];
            read_debug_sei_message(h, b);
        }
        h->sei = NULL;
    }
}

//7.3.2.3.1 Supplemental enhancement information message syntax
void read_debug_sei_message(h264_stream_t* h, bs_t* b)
{
    if( 0 )
    {
        _write_ff_coded_number(b, h->sei->payloadType);
        _write_ff_coded_number(b, h->sei->payloadSize);
    }
    if( 1 )
    {
        h->sei->payloadType = _read_ff_coded_number(b);
        h->sei->payloadSize = _read_ff_coded_number(b);
    }
    read_debug_sei_payload( h, b );
}
#endif

//7.3.2.4 Access unit delimiter RBSP syntax
void read_debug_access_unit_delimiter_rbsp(h264_stream_t* h, bs_t* b)
{
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); h->aud->primary_pic_type = bs_read_u(b, 3); printf("h->aud->primary_pic_type: %d \n", h->aud->primary_pic_type); 
}

//7.3.2.5 End of sequence RBSP syntax
void read_debug_end_of_seq_rbsp(h264_stream_t* h, bs_t* b)
{
}

//7.3.2.6 End of stream RBSP syntax
void read_debug_end_of_stream_rbsp(h264_stream_t* h, bs_t* b)
{
}

//7.3.2.7 Filler data RBSP syntax
void read_debug_filler_data_rbsp(h264_stream_t* h, bs_t* b)
{
    while( bs_next_bits(b, 8) == 0xFF )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); int ff_byte = bs_read_u(b, 8); printf("ff_byte: %d \n", ff_byte); 
    }
}

//7.3.2.8 Slice layer without partitioning RBSP syntax
void read_debug_slice_layer_rbsp(h264_stream_t* h,  bs_t* b)
{
    if (h->nal->nal_unit_type != NAL_UNIT_TYPE_CODED_SLICE_SVC_EXTENSION)
        read_debug_slice_header(h, b);
    else
        read_debug_slice_header_in_scalable_extension(h, b);
    
    slice_data_rbsp_t* slice_data = h->slice_data;

    if ( slice_data != NULL )
    {
        if ( slice_data->rbsp_buf != NULL ) free( slice_data->rbsp_buf ); 
        uint8_t *sptr = b->p + (!!b->bits_left); // CABAC-specific: skip alignment bits, if there are any
        slice_data->rbsp_size = b->end - sptr;

        if ( slice_data->rbsp_size > 0 )
        {
            slice_data->rbsp_buf = (uint8_t*)malloc(slice_data->rbsp_size);
            memcpy( slice_data->rbsp_buf, sptr, slice_data->rbsp_size );
            // ugly hack: since next NALU starts at byte border, we are going to be padded by trailing_bits;
            return;
        }
        else
        {
            slice_data->rbsp_buf = NULL;
            slice_data->rbsp_size = 0;
        }
    }

    // FIXME should read or skip data
    //slice_data( ); /* all categories of slice_data( ) syntax */
    read_debug_rbsp_slice_trailing_bits(h, b);
}

/*
// UNIMPLEMENTED
//7.3.2.9.1 Slice data partition A RBSP syntax
slice_data_partition_a_layer_rbsp( ) {
    read_debug_slice_header( );             // only category 2
    slice_id = bs_read_debug_ue(b)
    read_debug_slice_data( );               // only category 2
    read_debug_rbsp_slice_trailing_bits( ); // only category 2
}

//7.3.2.9.2 Slice data partition B RBSP syntax
slice_data_partition_b_layer_rbsp( ) {
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); slice_id = bs_read_ue(b); printf("slice_id: %d \n", slice_id);     // only category 3
    if( redundant_pic_cnt_present_flag )
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); redundant_pic_cnt = bs_read_ue(b); printf("redundant_pic_cnt: %d \n", redundant_pic_cnt); 
    read_debug_slice_data( );               // only category 3
    read_debug_rbsp_slice_trailing_bits( ); // only category 3
}

//7.3.2.9.3 Slice data partition C RBSP syntax
slice_data_partition_c_layer_rbsp( ) {
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); slice_id = bs_read_ue(b); printf("slice_id: %d \n", slice_id);     // only category 4
    if( redundant_pic_cnt_present_flag )
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); redundant_pic_cnt = bs_read_ue(b); printf("redundant_pic_cnt: %d \n", redundant_pic_cnt); 
    read_debug_slice_data( );               // only category 4
    rbsp_slice_trailing_bits( ); // only category 4
}
*/

//7.3.2.10 RBSP slice trailing bits syntax
void read_debug_rbsp_slice_trailing_bits(h264_stream_t* h, bs_t* b)
{
    read_debug_rbsp_trailing_bits(b);
    if( h->pps->entropy_coding_mode_flag )
    {
        while( more_rbsp_trailing_data(h, b) )
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); int cabac_zero_word = bs_read_u(b, 16); printf("cabac_zero_word: %d \n", cabac_zero_word); 
        }
    }
}

//7.3.2.11 RBSP trailing bits syntax
void read_debug_rbsp_trailing_bits(bs_t* b)
{
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); int rbsp_stop_one_bit = bs_read_u(b, 1); printf("rbsp_stop_one_bit: %d \n", rbsp_stop_one_bit); 

    while( !bs_byte_aligned(b) )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); int rbsp_alignment_zero_bit = bs_read_u(b, 1); printf("rbsp_alignment_zero_bit: %d \n", rbsp_alignment_zero_bit); 
    }
}

//7.3.3 Slice header syntax
void read_debug_slice_header(h264_stream_t* h, bs_t* b)
{
    slice_header_t* sh = h->sh;
    if( 1 )
    {
        memset(sh, 0, sizeof(slice_header_t));
    }

    nal_t* nal = h->nal;

    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->first_mb_in_slice = bs_read_ue(b); printf("sh->first_mb_in_slice: %d \n", sh->first_mb_in_slice); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->slice_type = bs_read_ue(b); printf("sh->slice_type: %d \n", sh->slice_type); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->pic_parameter_set_id = bs_read_ue(b); printf("sh->pic_parameter_set_id: %d \n", sh->pic_parameter_set_id); 

    // TODO check existence, otherwise fail
    pps_t* pps = h->pps;
    sps_t* sps = h->sps;
    memcpy(h->pps, h->pps_table[sh->pic_parameter_set_id], sizeof(pps_t));
    memcpy(h->sps, h->sps_table[pps->seq_parameter_set_id], sizeof(sps_t));

    if (sps->residual_colour_transform_flag)
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->colour_plane_id = bs_read_u(b, 2); printf("sh->colour_plane_id: %d \n", sh->colour_plane_id); 
    }

    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->frame_num = bs_read_u(b, sps->log2_max_frame_num_minus4 + 4 ); printf("sh->frame_num: %d \n", sh->frame_num);  // was u(v)
    if( !sps->frame_mbs_only_flag )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->field_pic_flag = bs_read_u1(b); printf("sh->field_pic_flag: %d \n", sh->field_pic_flag); 
        if( sh->field_pic_flag )
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->bottom_field_flag = bs_read_u1(b); printf("sh->bottom_field_flag: %d \n", sh->bottom_field_flag); 
        }
    }
    if( nal->nal_unit_type == 5 )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->idr_pic_id = bs_read_ue(b); printf("sh->idr_pic_id: %d \n", sh->idr_pic_id); 
    }
    if( sps->pic_order_cnt_type == 0 )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->pic_order_cnt_lsb = bs_read_u(b, sps->log2_max_pic_order_cnt_lsb_minus4 + 4 ); printf("sh->pic_order_cnt_lsb: %d \n", sh->pic_order_cnt_lsb);  // was u(v)
        if( pps->pic_order_present_flag && !sh->field_pic_flag )
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->delta_pic_order_cnt_bottom = bs_read_se(b); printf("sh->delta_pic_order_cnt_bottom: %d \n", sh->delta_pic_order_cnt_bottom); 
        }
    }
    if( sps->pic_order_cnt_type == 1 && !sps->delta_pic_order_always_zero_flag )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->delta_pic_order_cnt[ 0 ] = bs_read_se(b); printf("sh->delta_pic_order_cnt[ 0 ]: %d \n", sh->delta_pic_order_cnt[ 0 ]); 
        if( pps->pic_order_present_flag && !sh->field_pic_flag )
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->delta_pic_order_cnt[ 1 ] = bs_read_se(b); printf("sh->delta_pic_order_cnt[ 1 ]: %d \n", sh->delta_pic_order_cnt[ 1 ]); 
        }
    }
    if( pps->redundant_pic_cnt_present_flag )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->redundant_pic_cnt = bs_read_ue(b); printf("sh->redundant_pic_cnt: %d \n", sh->redundant_pic_cnt); 
    }
    if( is_slice_type( sh->slice_type, SH_SLICE_TYPE_B ) )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->direct_spatial_mv_pred_flag = bs_read_u1(b); printf("sh->direct_spatial_mv_pred_flag: %d \n", sh->direct_spatial_mv_pred_flag); 
    }
    if( is_slice_type( sh->slice_type, SH_SLICE_TYPE_P ) || is_slice_type( sh->slice_type, SH_SLICE_TYPE_SP ) || is_slice_type( sh->slice_type, SH_SLICE_TYPE_B ) )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->num_ref_idx_active_override_flag = bs_read_u1(b); printf("sh->num_ref_idx_active_override_flag: %d \n", sh->num_ref_idx_active_override_flag); 
        if( sh->num_ref_idx_active_override_flag )
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->num_ref_idx_l0_active_minus1 = bs_read_ue(b); printf("sh->num_ref_idx_l0_active_minus1: %d \n", sh->num_ref_idx_l0_active_minus1);  // FIXME does this modify the pps?
            if( is_slice_type( sh->slice_type, SH_SLICE_TYPE_B ) )
            {
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->num_ref_idx_l1_active_minus1 = bs_read_ue(b); printf("sh->num_ref_idx_l1_active_minus1: %d \n", sh->num_ref_idx_l1_active_minus1); 
            }
        }
    }
    read_debug_ref_pic_list_reordering(h, b);
    if( ( pps->weighted_pred_flag && ( is_slice_type( sh->slice_type, SH_SLICE_TYPE_P ) || is_slice_type( sh->slice_type, SH_SLICE_TYPE_SP ) ) ) ||
        ( pps->weighted_bipred_idc == 1 && is_slice_type( sh->slice_type, SH_SLICE_TYPE_B ) ) )
    {
        read_debug_pred_weight_table(h, b);
    }
    if( nal->nal_ref_idc != 0 )
    {
        read_debug_dec_ref_pic_marking(h, b);
    }
    if( pps->entropy_coding_mode_flag && ! is_slice_type( sh->slice_type, SH_SLICE_TYPE_I ) && ! is_slice_type( sh->slice_type, SH_SLICE_TYPE_SI ) )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->cabac_init_idc = bs_read_ue(b); printf("sh->cabac_init_idc: %d \n", sh->cabac_init_idc); 
    }
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->slice_qp_delta = bs_read_se(b); printf("sh->slice_qp_delta: %d \n", sh->slice_qp_delta); 
    if( is_slice_type( sh->slice_type, SH_SLICE_TYPE_SP ) || is_slice_type( sh->slice_type, SH_SLICE_TYPE_SI ) )
    {
        if( is_slice_type( sh->slice_type, SH_SLICE_TYPE_SP ) )
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->sp_for_switch_flag = bs_read_u1(b); printf("sh->sp_for_switch_flag: %d \n", sh->sp_for_switch_flag); 
        }
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->slice_qs_delta = bs_read_se(b); printf("sh->slice_qs_delta: %d \n", sh->slice_qs_delta); 
    }
    if( pps->deblocking_filter_control_present_flag )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->disable_deblocking_filter_idc = bs_read_ue(b); printf("sh->disable_deblocking_filter_idc: %d \n", sh->disable_deblocking_filter_idc); 
        if( sh->disable_deblocking_filter_idc != 1 )
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->slice_alpha_c0_offset_div2 = bs_read_se(b); printf("sh->slice_alpha_c0_offset_div2: %d \n", sh->slice_alpha_c0_offset_div2); 
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->slice_beta_offset_div2 = bs_read_se(b); printf("sh->slice_beta_offset_div2: %d \n", sh->slice_beta_offset_div2); 
        }
    }
    if( pps->num_slice_groups_minus1 > 0 &&
        pps->slice_group_map_type >= 3 && pps->slice_group_map_type <= 5)
    {
        int v = intlog2( pps->pic_size_in_map_units_minus1 +  pps->slice_group_change_rate_minus1 + 1 );
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->slice_group_change_cycle = bs_read_u(b, v); printf("sh->slice_group_change_cycle: %d \n", sh->slice_group_change_cycle);  // FIXME add 2?
    }
}

//7.3.3.1 Reference picture list reordering syntax
void read_debug_ref_pic_list_reordering(h264_stream_t* h, bs_t* b)
{
    slice_header_t* sh = h->sh;
    // FIXME should be an array

    if( ! is_slice_type( sh->slice_type, SH_SLICE_TYPE_I ) && ! is_slice_type( sh->slice_type, SH_SLICE_TYPE_SI ) )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->rplr.ref_pic_list_reordering_flag_l0 = bs_read_u1(b); printf("sh->rplr.ref_pic_list_reordering_flag_l0: %d \n", sh->rplr.ref_pic_list_reordering_flag_l0); 
        if( sh->rplr.ref_pic_list_reordering_flag_l0 )
        {
            int n = -1;
            do
            {
                n++;
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->rplr.reorder_l0.reordering_of_pic_nums_idc[ n ] = bs_read_ue(b); printf("sh->rplr.reorder_l0.reordering_of_pic_nums_idc[ n ]: %d \n", sh->rplr.reorder_l0.reordering_of_pic_nums_idc[ n ]); 
                if( sh->rplr.reorder_l0.reordering_of_pic_nums_idc[ n ] == 0 ||
                    sh->rplr.reorder_l0.reordering_of_pic_nums_idc[ n ] == 1 )
                {
                    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->rplr.reorder_l0.abs_diff_pic_num_minus1[ n ] = bs_read_ue(b); printf("sh->rplr.reorder_l0.abs_diff_pic_num_minus1[ n ]: %d \n", sh->rplr.reorder_l0.abs_diff_pic_num_minus1[ n ]); 
                }
                else if( sh->rplr.reorder_l0.reordering_of_pic_nums_idc[ n ] == 2 )
                {
                    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->rplr.reorder_l0.long_term_pic_num[ n ] = bs_read_ue(b); printf("sh->rplr.reorder_l0.long_term_pic_num[ n ]: %d \n", sh->rplr.reorder_l0.long_term_pic_num[ n ]); 
                }
            } while( sh->rplr.reorder_l0.reordering_of_pic_nums_idc[ n ] != 3 && ! bs_eof(b) );
        }
    }
    if( is_slice_type( sh->slice_type, SH_SLICE_TYPE_B ) )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->rplr.ref_pic_list_reordering_flag_l1 = bs_read_u1(b); printf("sh->rplr.ref_pic_list_reordering_flag_l1: %d \n", sh->rplr.ref_pic_list_reordering_flag_l1); 
        if( sh->rplr.ref_pic_list_reordering_flag_l1 )
        {
            int n = -1;
            do
            {
                n++;
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->rplr.reorder_l1.reordering_of_pic_nums_idc[ n ] = bs_read_ue(b); printf("sh->rplr.reorder_l1.reordering_of_pic_nums_idc[ n ]: %d \n", sh->rplr.reorder_l1.reordering_of_pic_nums_idc[ n ]); 
                if( sh->rplr.reorder_l1.reordering_of_pic_nums_idc[ n ] == 0 ||
                    sh->rplr.reorder_l1.reordering_of_pic_nums_idc[ n ] == 1 )
                {
                    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->rplr.reorder_l1.abs_diff_pic_num_minus1[ n ] = bs_read_ue(b); printf("sh->rplr.reorder_l1.abs_diff_pic_num_minus1[ n ]: %d \n", sh->rplr.reorder_l1.abs_diff_pic_num_minus1[ n ]); 
                }
                else if( sh->rplr.reorder_l1.reordering_of_pic_nums_idc[ n ] == 2 )
                {
                    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->rplr.reorder_l1.long_term_pic_num[ n ] = bs_read_ue(b); printf("sh->rplr.reorder_l1.long_term_pic_num[ n ]: %d \n", sh->rplr.reorder_l1.long_term_pic_num[ n ]); 
                }
            } while( sh->rplr.reorder_l1.reordering_of_pic_nums_idc[ n ] != 3 && ! bs_eof(b) );
        }
    }
}

//7.3.3.2 Prediction weight table syntax
void read_debug_pred_weight_table(h264_stream_t* h, bs_t* b)
{
    slice_header_t* sh = h->sh;
    sps_t* sps = h->sps;
    pps_t* pps = h->pps;

    int i, j;

    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->pwt.luma_log2_weight_denom = bs_read_ue(b); printf("sh->pwt.luma_log2_weight_denom: %d \n", sh->pwt.luma_log2_weight_denom); 
    if( sps->chroma_format_idc != 0 ) //FIXME ChromaArrayType may differ from chroma_format_idc
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->pwt.chroma_log2_weight_denom = bs_read_ue(b); printf("sh->pwt.chroma_log2_weight_denom: %d \n", sh->pwt.chroma_log2_weight_denom); 
    }
    for( i = 0; i <= pps->num_ref_idx_l0_active_minus1; i++ )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->pwt.luma_weight_l0_flag[i] = bs_read_u1(b); printf("sh->pwt.luma_weight_l0_flag[i]: %d \n", sh->pwt.luma_weight_l0_flag[i]); 
        if( sh->pwt.luma_weight_l0_flag[i] )
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->pwt.luma_weight_l0[ i ] = bs_read_se(b); printf("sh->pwt.luma_weight_l0[ i ]: %d \n", sh->pwt.luma_weight_l0[ i ]); 
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->pwt.luma_offset_l0[ i ] = bs_read_se(b); printf("sh->pwt.luma_offset_l0[ i ]: %d \n", sh->pwt.luma_offset_l0[ i ]); 
        }
        if ( sps->chroma_format_idc != 0 ) //FIXME ChromaArrayType may differ from chroma_format_idc
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->pwt.chroma_weight_l0_flag[i] = bs_read_u1(b); printf("sh->pwt.chroma_weight_l0_flag[i]: %d \n", sh->pwt.chroma_weight_l0_flag[i]); 
            if( sh->pwt.chroma_weight_l0_flag[i] )
            {
                for( j =0; j < 2; j++ )
                {
                    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->pwt.chroma_weight_l0[ i ][ j ] = bs_read_se(b); printf("sh->pwt.chroma_weight_l0[ i ][ j ]: %d \n", sh->pwt.chroma_weight_l0[ i ][ j ]); 
                    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->pwt.chroma_offset_l0[ i ][ j ] = bs_read_se(b); printf("sh->pwt.chroma_offset_l0[ i ][ j ]: %d \n", sh->pwt.chroma_offset_l0[ i ][ j ]); 
                }
            }
        }
    }
    if( is_slice_type( sh->slice_type, SH_SLICE_TYPE_B ) )
    {
        for( i = 0; i <= pps->num_ref_idx_l1_active_minus1; i++ )
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->pwt.luma_weight_l1_flag[i] = bs_read_u1(b); printf("sh->pwt.luma_weight_l1_flag[i]: %d \n", sh->pwt.luma_weight_l1_flag[i]); 
            if( sh->pwt.luma_weight_l1_flag[i] )
            {
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->pwt.luma_weight_l1[ i ] = bs_read_se(b); printf("sh->pwt.luma_weight_l1[ i ]: %d \n", sh->pwt.luma_weight_l1[ i ]); 
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->pwt.luma_offset_l1[ i ] = bs_read_se(b); printf("sh->pwt.luma_offset_l1[ i ]: %d \n", sh->pwt.luma_offset_l1[ i ]); 
            }
            if( sps->chroma_format_idc != 0 )
            {
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->pwt.chroma_weight_l1_flag[i] = bs_read_u1(b); printf("sh->pwt.chroma_weight_l1_flag[i]: %d \n", sh->pwt.chroma_weight_l1_flag[i]); 
                if( sh->pwt.chroma_weight_l1_flag[i] )
                {
                    for( j = 0; j < 2; j++ )
                    {
                        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->pwt.chroma_weight_l1[ i ][ j ] = bs_read_se(b); printf("sh->pwt.chroma_weight_l1[ i ][ j ]: %d \n", sh->pwt.chroma_weight_l1[ i ][ j ]); 
                        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->pwt.chroma_offset_l1[ i ][ j ] = bs_read_se(b); printf("sh->pwt.chroma_offset_l1[ i ][ j ]: %d \n", sh->pwt.chroma_offset_l1[ i ][ j ]); 
                    }
                }
            }
        }
    }
}

//7.3.3.3 Decoded reference picture marking syntax
void read_debug_dec_ref_pic_marking(h264_stream_t* h, bs_t* b)
{
    slice_header_t* sh = h->sh;
    // FIXME should be an array

    if( h->nal->nal_unit_type == 5 )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->drpm.no_output_of_prior_pics_flag = bs_read_u1(b); printf("sh->drpm.no_output_of_prior_pics_flag: %d \n", sh->drpm.no_output_of_prior_pics_flag); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->drpm.long_term_reference_flag = bs_read_u1(b); printf("sh->drpm.long_term_reference_flag: %d \n", sh->drpm.long_term_reference_flag); 
    }
    else
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->drpm.adaptive_ref_pic_marking_mode_flag = bs_read_u1(b); printf("sh->drpm.adaptive_ref_pic_marking_mode_flag: %d \n", sh->drpm.adaptive_ref_pic_marking_mode_flag); 
        if( sh->drpm.adaptive_ref_pic_marking_mode_flag )
        {
            int n = -1;
            do
            {
                n++;
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->drpm.memory_management_control_operation[ n ] = bs_read_ue(b); printf("sh->drpm.memory_management_control_operation[ n ]: %d \n", sh->drpm.memory_management_control_operation[ n ]); 
                if( sh->drpm.memory_management_control_operation[ n ] == 1 ||
                    sh->drpm.memory_management_control_operation[ n ] == 3 )
                {
                    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->drpm.difference_of_pic_nums_minus1[ n ] = bs_read_ue(b); printf("sh->drpm.difference_of_pic_nums_minus1[ n ]: %d \n", sh->drpm.difference_of_pic_nums_minus1[ n ]); 
                }
                if(sh->drpm.memory_management_control_operation[ n ] == 2 )
                {
                    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->drpm.long_term_pic_num[ n ] = bs_read_ue(b); printf("sh->drpm.long_term_pic_num[ n ]: %d \n", sh->drpm.long_term_pic_num[ n ]); 
                }
                if( sh->drpm.memory_management_control_operation[ n ] == 3 ||
                    sh->drpm.memory_management_control_operation[ n ] == 6 )
                {
                    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->drpm.long_term_frame_idx[ n ] = bs_read_ue(b); printf("sh->drpm.long_term_frame_idx[ n ]: %d \n", sh->drpm.long_term_frame_idx[ n ]); 
                }
                if( sh->drpm.memory_management_control_operation[ n ] == 4 )
                {
                    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->drpm.max_long_term_frame_idx_plus1[ n ] = bs_read_ue(b); printf("sh->drpm.max_long_term_frame_idx_plus1[ n ]: %d \n", sh->drpm.max_long_term_frame_idx_plus1[ n ]); 
                }
            } while( sh->drpm.memory_management_control_operation[ n ] != 0 && ! bs_eof(b) );
        }
    }
}

//G.7.3.3.4 Slice header in scalable extension syntax
void read_debug_slice_header_in_scalable_extension(h264_stream_t* h, bs_t* b)
{
    slice_header_t* sh = h->sh;
    slice_header_svc_ext_t* sh_svc_ext = h->sh_svc_ext;
    if( 1 )
    {
        memset(sh, 0, sizeof(slice_header_t));
        memset(sh_svc_ext, 0, sizeof(slice_header_svc_ext_t));
    }
    
    nal_t* nal = h->nal;
    
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->first_mb_in_slice = bs_read_ue(b); printf("sh->first_mb_in_slice: %d \n", sh->first_mb_in_slice); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->slice_type = bs_read_ue(b); printf("sh->slice_type: %d \n", sh->slice_type); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->pic_parameter_set_id = bs_read_ue(b); printf("sh->pic_parameter_set_id: %d \n", sh->pic_parameter_set_id); 
    
    // TODO check existence, otherwise fail
    pps_t* pps = h->pps;
    sps_subset_t* sps_subset = h->sps_subset;
    memcpy(h->pps, h->pps_table[sh->pic_parameter_set_id], sizeof(pps_t));
    //memcpy(sps_subset, h->sps_subset_table[pps->seq_parameter_set_id], sizeof(sps_subset_t));
    memcpy(sps_subset->sps, h->sps_subset_table[pps->seq_parameter_set_id]->sps, sizeof(sps_t));
    memcpy(sps_subset->sps_svc_ext, h->sps_subset_table[pps->seq_parameter_set_id]->sps_svc_ext, sizeof(sps_svc_ext_t));
    
    if (sps_subset->sps->residual_colour_transform_flag)
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->colour_plane_id = bs_read_u(b, 2); printf("sh->colour_plane_id: %d \n", sh->colour_plane_id); 
    }
    
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->frame_num = bs_read_u(b, sps_subset->sps->log2_max_frame_num_minus4 + 4 ); printf("sh->frame_num: %d \n", sh->frame_num);  // was u(v)
    if( !sps_subset->sps->frame_mbs_only_flag )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->field_pic_flag = bs_read_u1(b); printf("sh->field_pic_flag: %d \n", sh->field_pic_flag); 
        if( sh->field_pic_flag )
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->bottom_field_flag = bs_read_u1(b); printf("sh->bottom_field_flag: %d \n", sh->bottom_field_flag); 
        }
    }
    if( nal->nal_unit_type == 5 )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->idr_pic_id = bs_read_ue(b); printf("sh->idr_pic_id: %d \n", sh->idr_pic_id); 
    }
    if( sps_subset->sps->pic_order_cnt_type == 0 )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->pic_order_cnt_lsb = bs_read_u(b, sps_subset->sps->log2_max_pic_order_cnt_lsb_minus4 + 4 ); printf("sh->pic_order_cnt_lsb: %d \n", sh->pic_order_cnt_lsb);  // was u(v)
        if( pps->pic_order_present_flag && !sh->field_pic_flag )
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->delta_pic_order_cnt_bottom = bs_read_se(b); printf("sh->delta_pic_order_cnt_bottom: %d \n", sh->delta_pic_order_cnt_bottom); 
        }
    }
    if( sps_subset->sps->pic_order_cnt_type == 1 && !sps_subset->sps->delta_pic_order_always_zero_flag )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->delta_pic_order_cnt[ 0 ] = bs_read_se(b); printf("sh->delta_pic_order_cnt[ 0 ]: %d \n", sh->delta_pic_order_cnt[ 0 ]); 
        if( pps->pic_order_present_flag && !sh->field_pic_flag )
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->delta_pic_order_cnt[ 1 ] = bs_read_se(b); printf("sh->delta_pic_order_cnt[ 1 ]: %d \n", sh->delta_pic_order_cnt[ 1 ]); 
        }
    }
    if( pps->redundant_pic_cnt_present_flag )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->redundant_pic_cnt = bs_read_ue(b); printf("sh->redundant_pic_cnt: %d \n", sh->redundant_pic_cnt); 
    }
    if( nal->nal_svc_ext->quality_id == 0)
    {
        if( is_slice_type( sh->slice_type, SH_SLICE_TYPE_EB ) )
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->direct_spatial_mv_pred_flag = bs_read_u1(b); printf("sh->direct_spatial_mv_pred_flag: %d \n", sh->direct_spatial_mv_pred_flag); 
        }
        if( is_slice_type( sh->slice_type, SH_SLICE_TYPE_EP ) ||
            is_slice_type( sh->slice_type, SH_SLICE_TYPE_EB ) )
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->num_ref_idx_active_override_flag = bs_read_u1(b); printf("sh->num_ref_idx_active_override_flag: %d \n", sh->num_ref_idx_active_override_flag); 
            if( sh->num_ref_idx_active_override_flag )
            {
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->num_ref_idx_l0_active_minus1 = bs_read_ue(b); printf("sh->num_ref_idx_l0_active_minus1: %d \n", sh->num_ref_idx_l0_active_minus1);  // FIXME does this modify the pps?
                if( is_slice_type( sh->slice_type, SH_SLICE_TYPE_EB ) )
                {
                    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->num_ref_idx_l1_active_minus1 = bs_read_ue(b); printf("sh->num_ref_idx_l1_active_minus1: %d \n", sh->num_ref_idx_l1_active_minus1); 
                }
            }
        }
        read_debug_ref_pic_list_reordering(h, b);
        if( ( pps->weighted_pred_flag       && is_slice_type( sh->slice_type, SH_SLICE_TYPE_EP ) ) ||
            ( pps->weighted_bipred_idc == 1 && is_slice_type( sh->slice_type, SH_SLICE_TYPE_EB ) ) )
        {
            //svc specific
            if( !nal->nal_svc_ext->no_inter_layer_pred_flag )
            {
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh_svc_ext->base_pred_weight_table_flag = bs_read_u1(b); printf("sh_svc_ext->base_pred_weight_table_flag: %d \n", sh_svc_ext->base_pred_weight_table_flag); 
            }
            if( nal->nal_svc_ext->no_inter_layer_pred_flag || !sh_svc_ext->base_pred_weight_table_flag )
            {
                read_debug_pred_weight_table(h, b);
            }
        }
        if( nal->nal_ref_idc != 0 )
        {
            read_debug_dec_ref_pic_marking(h, b);
            
            //svc specific
            if( !sps_subset->sps_svc_ext->slice_header_restriction_flag )
            {
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh_svc_ext->store_ref_base_pic_flag = bs_read_u1(b); printf("sh_svc_ext->store_ref_base_pic_flag: %d \n", sh_svc_ext->store_ref_base_pic_flag); 
                if( ( nal->nal_svc_ext->use_ref_base_pic_flag || sh_svc_ext->store_ref_base_pic_flag ) &&
                   ( nal->nal_unit_type != 5 ) )
                {
                    read_debug_dec_ref_base_pic_marking(nal, b);
                }
            }
        }
    }
    
    if( pps->entropy_coding_mode_flag && ! is_slice_type( sh->slice_type, SH_SLICE_TYPE_EI ) )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->cabac_init_idc = bs_read_ue(b); printf("sh->cabac_init_idc: %d \n", sh->cabac_init_idc); 
    }
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->slice_qp_delta = bs_read_se(b); printf("sh->slice_qp_delta: %d \n", sh->slice_qp_delta); 
    if( pps->deblocking_filter_control_present_flag )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->disable_deblocking_filter_idc = bs_read_ue(b); printf("sh->disable_deblocking_filter_idc: %d \n", sh->disable_deblocking_filter_idc); 
        if( sh->disable_deblocking_filter_idc != 1 )
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->slice_alpha_c0_offset_div2 = bs_read_se(b); printf("sh->slice_alpha_c0_offset_div2: %d \n", sh->slice_alpha_c0_offset_div2); 
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->slice_beta_offset_div2 = bs_read_se(b); printf("sh->slice_beta_offset_div2: %d \n", sh->slice_beta_offset_div2); 
        }
    }
    if( pps->num_slice_groups_minus1 > 0 &&
       pps->slice_group_map_type >= 3 && pps->slice_group_map_type <= 5)
    {
        int v = intlog2( pps->pic_size_in_map_units_minus1 +  pps->slice_group_change_rate_minus1 + 1 );
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh->slice_group_change_cycle = bs_read_u(b, v); printf("sh->slice_group_change_cycle: %d \n", sh->slice_group_change_cycle);  // FIXME add 2?
    }
    
    //svc specific
    if( !nal->nal_svc_ext->no_inter_layer_pred_flag && nal->nal_svc_ext->quality_id == 0 )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh_svc_ext->ref_layer_dq_id = bs_read_ue(b); printf("sh_svc_ext->ref_layer_dq_id: %d \n", sh_svc_ext->ref_layer_dq_id); 
        if( sps_subset->sps_svc_ext->inter_layer_deblocking_filter_control_present_flag )
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh_svc_ext->disable_inter_layer_deblocking_filter_idc = bs_read_ue(b); printf("sh_svc_ext->disable_inter_layer_deblocking_filter_idc: %d \n", sh_svc_ext->disable_inter_layer_deblocking_filter_idc); 
            if( sh_svc_ext->disable_inter_layer_deblocking_filter_idc != 1 )
            {
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh_svc_ext->inter_layer_slice_alpha_c0_offset_div2 = bs_read_se(b); printf("sh_svc_ext->inter_layer_slice_alpha_c0_offset_div2: %d \n", sh_svc_ext->inter_layer_slice_alpha_c0_offset_div2); 
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh_svc_ext->inter_layer_slice_beta_offset_div2 = bs_read_se(b); printf("sh_svc_ext->inter_layer_slice_beta_offset_div2: %d \n", sh_svc_ext->inter_layer_slice_beta_offset_div2); 
            }
        }
        
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh_svc_ext->constrained_intra_resampling_flag = bs_read_u1(b); printf("sh_svc_ext->constrained_intra_resampling_flag: %d \n", sh_svc_ext->constrained_intra_resampling_flag); 
        if( sps_subset->sps_svc_ext->extended_spatial_scalability_idc == 2 )
        {
            if( sps_subset->sps->chroma_format_idc > 0 )
            {
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh_svc_ext->ref_layer_chroma_phase_x_plus1_flag = bs_read_u1(b); printf("sh_svc_ext->ref_layer_chroma_phase_x_plus1_flag: %d \n", sh_svc_ext->ref_layer_chroma_phase_x_plus1_flag); 
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh_svc_ext->ref_layer_chroma_phase_y_plus1 = bs_read_u(b, 2); printf("sh_svc_ext->ref_layer_chroma_phase_y_plus1: %d \n", sh_svc_ext->ref_layer_chroma_phase_y_plus1); 
            }
            
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh_svc_ext->scaled_ref_layer_left_offset = bs_read_se(b); printf("sh_svc_ext->scaled_ref_layer_left_offset: %d \n", sh_svc_ext->scaled_ref_layer_left_offset); 
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh_svc_ext->scaled_ref_layer_top_offset = bs_read_se(b); printf("sh_svc_ext->scaled_ref_layer_top_offset: %d \n", sh_svc_ext->scaled_ref_layer_top_offset); 
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh_svc_ext->scaled_ref_layer_right_offset = bs_read_se(b); printf("sh_svc_ext->scaled_ref_layer_right_offset: %d \n", sh_svc_ext->scaled_ref_layer_right_offset); 
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh_svc_ext->scaled_ref_layer_bottom_offset = bs_read_se(b); printf("sh_svc_ext->scaled_ref_layer_bottom_offset: %d \n", sh_svc_ext->scaled_ref_layer_bottom_offset); 
        }
    }
    
    if( !nal->nal_svc_ext->no_inter_layer_pred_flag )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh_svc_ext->slice_skip_flag = bs_read_u1(b); printf("sh_svc_ext->slice_skip_flag: %d \n", sh_svc_ext->slice_skip_flag); 
        if( sh_svc_ext->slice_skip_flag )
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh_svc_ext->num_mbs_in_slice_minus1 = bs_read_ue(b); printf("sh_svc_ext->num_mbs_in_slice_minus1: %d \n", sh_svc_ext->num_mbs_in_slice_minus1); 
        }
        else
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh_svc_ext->adaptive_base_mode_flag = bs_read_u1(b); printf("sh_svc_ext->adaptive_base_mode_flag: %d \n", sh_svc_ext->adaptive_base_mode_flag); 
            if( !sh_svc_ext->adaptive_base_mode_flag )
            {
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh_svc_ext->default_base_mode_flag = bs_read_u1(b); printf("sh_svc_ext->default_base_mode_flag: %d \n", sh_svc_ext->default_base_mode_flag); 
            }
            if( !sh_svc_ext->default_base_mode_flag )
            {
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh_svc_ext->adaptive_motion_prediction_flag = bs_read_u1(b); printf("sh_svc_ext->adaptive_motion_prediction_flag: %d \n", sh_svc_ext->adaptive_motion_prediction_flag); 
                if( !sh_svc_ext->adaptive_motion_prediction_flag )
                {
                    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh_svc_ext->default_motion_prediction_flag = bs_read_u1(b); printf("sh_svc_ext->default_motion_prediction_flag: %d \n", sh_svc_ext->default_motion_prediction_flag); 
                }
            }
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh_svc_ext->adaptive_residual_prediction_flag = bs_read_u1(b); printf("sh_svc_ext->adaptive_residual_prediction_flag: %d \n", sh_svc_ext->adaptive_residual_prediction_flag); 
            if( !sh_svc_ext->adaptive_residual_prediction_flag )
            {
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh_svc_ext->default_residual_prediction_flag = bs_read_u1(b); printf("sh_svc_ext->default_residual_prediction_flag: %d \n", sh_svc_ext->default_residual_prediction_flag); 
            }
        }
        if( sps_subset->sps_svc_ext->adaptive_tcoeff_level_prediction_flag )
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh_svc_ext->tcoeff_level_prediction_flag = bs_read_u1(b); printf("sh_svc_ext->tcoeff_level_prediction_flag: %d \n", sh_svc_ext->tcoeff_level_prediction_flag); 
        }
    }
    
    if( !sps_subset->sps_svc_ext->slice_header_restriction_flag && !sh_svc_ext->slice_skip_flag )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh_svc_ext->scan_idx_start = bs_read_u(b, 4); printf("sh_svc_ext->scan_idx_start: %d \n", sh_svc_ext->scan_idx_start); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sh_svc_ext->scan_idx_end = bs_read_u(b, 4); printf("sh_svc_ext->scan_idx_end: %d \n", sh_svc_ext->scan_idx_end); 
    }
}

//G.7.3.3.5 Decoded reference base picture marking syntax
void read_debug_dec_ref_base_pic_marking(nal_t* nal, bs_t* b)
{
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); nal->prefix_nal_svc->adaptive_ref_base_pic_marking_mode_flag = bs_read_u1(b); printf("nal->prefix_nal_svc->adaptive_ref_base_pic_marking_mode_flag: %d \n", nal->prefix_nal_svc->adaptive_ref_base_pic_marking_mode_flag); 
    if( nal->prefix_nal_svc->adaptive_ref_base_pic_marking_mode_flag )
    {
        do {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); nal->prefix_nal_svc->memory_management_base_control_operation = bs_read_ue(b); printf("nal->prefix_nal_svc->memory_management_base_control_operation: %d \n", nal->prefix_nal_svc->memory_management_base_control_operation); 
            
            if( nal->prefix_nal_svc->memory_management_base_control_operation == 1 )
            {
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); nal->prefix_nal_svc->difference_of_base_pic_nums_minus1 = bs_read_ue(b); printf("nal->prefix_nal_svc->difference_of_base_pic_nums_minus1: %d \n", nal->prefix_nal_svc->difference_of_base_pic_nums_minus1); 
            }
            if( nal->prefix_nal_svc->memory_management_base_control_operation == 2 )
            {
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); nal->prefix_nal_svc->long_term_base_pic_num = bs_read_ue(b); printf("nal->prefix_nal_svc->long_term_base_pic_num: %d \n", nal->prefix_nal_svc->long_term_base_pic_num); 
            }
        } while( nal->prefix_nal_svc->memory_management_base_control_operation != 0 );
    }
}

