/*
 * h264bitstream - a library for reading and writing H.264 video
 * Copyright (C) 2005-2007 Auroras Entertainment, LLC
 * Copyright (C) 2008-2011 Avail-TVN
 * Copyright (C) 2012 Alex Izvorski
 *
 * This file is written by Leslie Wang <wqyuwss@gmail.com>
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

#include <stdio.h>
#include <stdlib.h> // malloc
#include <string.h> // memset

sei_t* sei_new()
{
    sei_t* s = (sei_t*)calloc(1, sizeof(sei_t));
    memset(s, 0, sizeof(sei_t));
    s->data = NULL;
    return s;
}

void sei_free(sei_t* s)
{
    switch( s->payloadType ) {
        case SEI_TYPE_SCALABILITY_INFO:
            if ( s->sei_svc != NULL ) free(s->sei_svc);
            break;
        default:
            if ( s->data != NULL ) free(s->data);
    }
    free(s);
}

void read_sei_end_bits(h264_stream_t* h, bs_t* b )
{
    // if the message doesn't end at a byte border
    if ( !bs_byte_aligned( b ) )
    {
        if ( !bs_read_u1( b ) ) fprintf(stderr, "WARNING: bit_equal_to_one is 0!!!!\n");
        while ( ! bs_byte_aligned( b ) )
        {
            if ( bs_read_u1( b ) ) fprintf(stderr, "WARNING: bit_equal_to_zero is 1!!!!\n");
        }
    }
    
    read_rbsp_trailing_bits(b);
}

#end_preamble

#function_declarations

// Appendix G.13.1.1 Scalability information SEI message syntax
void structure(sei_scalability_info)( h264_stream_t* h, bs_t* b )
{
    sei_scalability_info_t* sei_svc = h->sei->sei_svc;
    
    value( sei_svc->temporal_id_nesting_flag, u1 );
    value( sei_svc->priority_layer_info_present_flag, u1 );
    value( sei_svc->priority_id_setting_flag, u1 );
    value( sei_svc->num_layers_minus1, ue );
    
    for( int i = 0; i <= sei_svc->num_layers_minus1; i++ ) {
        value( sei_svc->layers[i].layer_id, ue );
        value( sei_svc->layers[i].priority_id, u(6) );
        value( sei_svc->layers[i].discardable_flag, u1 );
        value( sei_svc->layers[i].dependency_id, u(3) );
        value( sei_svc->layers[i].quality_id, u(4) );
        value( sei_svc->layers[i].temporal_id, u(3) );
        value( sei_svc->layers[i].sub_pic_layer_flag, u1 );
        value( sei_svc->layers[i].sub_region_layer_flag, u1 );
        value( sei_svc->layers[i].iroi_division_info_present_flag, u1 );
        value( sei_svc->layers[i].profile_level_info_present_flag, u1 );
        value( sei_svc->layers[i].bitrate_info_present_flag, u1 );
        value( sei_svc->layers[i].frm_rate_info_present_flag, u1 );
        value( sei_svc->layers[i].frm_size_info_present_flag, u1 );
        value( sei_svc->layers[i].layer_dependency_info_present_flag, u1 );
        value( sei_svc->layers[i].parameter_sets_info_present_flag, u1 );
        value( sei_svc->layers[i].bitstream_restriction_info_present_flag, u1 );
        value( sei_svc->layers[i].exact_inter_layer_pred_flag, u1 );
        if( sei_svc->layers[i].sub_pic_layer_flag ||
            sei_svc->layers[i].iroi_division_info_present_flag )
        {
            value( sei_svc->layers[i].exact_sample_value_match_flag, u1 );
        }
        value( sei_svc->layers[i].layer_conversion_flag, u1 );
        value( sei_svc->layers[i].layer_output_flag, u1 );
        if( sei_svc->layers[i].profile_level_info_present_flag )
        {
            value( sei_svc->layers[i].layer_profile_level_idc, u(24) );
        }
        if( sei_svc->layers[i].bitrate_info_present_flag )
        {
            value( sei_svc->layers[i].avg_bitrate, u(16) );
            value( sei_svc->layers[i].max_bitrate_layer, u(16) );
            value( sei_svc->layers[i].max_bitrate_layer_representation, u(16) );
            value( sei_svc->layers[i].max_bitrate_calc_window, u(16) );
        }
        if( sei_svc->layers[i].frm_rate_info_present_flag )
        {
            value( sei_svc->layers[i].constant_frm_rate_idc, u(2) );
            value( sei_svc->layers[i].avg_frm_rate, u(16) );
        }
        if( sei_svc->layers[i].frm_size_info_present_flag ||
            sei_svc->layers[i].iroi_division_info_present_flag )
        {
            value( sei_svc->layers[i].frm_width_in_mbs_minus1, ue );
            value( sei_svc->layers[i].frm_height_in_mbs_minus1, ue );
        }
        if( sei_svc->layers[i].sub_region_layer_flag )
        {
            value( sei_svc->layers[i].base_region_layer_id, ue );
            value( sei_svc->layers[i].dynamic_rect_flag, u1 );
            if( sei_svc->layers[i].dynamic_rect_flag )
            {
                value( sei_svc->layers[i].horizontal_offset, u(16) );
                value( sei_svc->layers[i].vertical_offset, u(16) );
                value( sei_svc->layers[i].region_width, u(16) );
                value( sei_svc->layers[i].region_height, u(16) );
            }
        }
        if( sei_svc->layers[i].sub_pic_layer_flag )
        {
            value( sei_svc->layers[i].roi_id, ue );
        }
        if( sei_svc->layers[i].iroi_division_info_present_flag )
        {
            value( sei_svc->layers[i].iroi_grid_flag, u1 );
            if( sei_svc->layers[i].iroi_grid_flag )
            {
                value( sei_svc->layers[i].grid_width_in_mbs_minus1, ue );
                value( sei_svc->layers[i].grid_height_in_mbs_minus1, ue );
            }
            else
            {
                value( sei_svc->layers[i].num_rois_minus1, ue );
                
                for( int j = 0; j <= sei_svc->layers[i].num_rois_minus1; j++ )
                {
                    value( sei_svc->layers[i].roi[j].first_mb_in_roi, ue );
                    value( sei_svc->layers[i].roi[j].roi_width_in_mbs_minus1, ue );
                    value( sei_svc->layers[i].roi[j].roi_height_in_mbs_minus1, ue );
                }
            }
        }
        if( sei_svc->layers[i].layer_dependency_info_present_flag )
        {
            value( sei_svc->layers[i].num_directly_dependent_layers, ue );
            for( int j = 0; j < sei_svc->layers[i].num_directly_dependent_layers; j++ )
            {
                value( sei_svc->layers[i].directly_dependent_layer_id_delta_minus1[j], ue );
            }
        }
        else
        {
            value( sei_svc->layers[i].layer_dependency_info_src_layer_id_delta, ue );
        }
        if( sei_svc->layers[i].parameter_sets_info_present_flag )
        {
            value( sei_svc->layers[i].num_seq_parameter_sets, ue );
            for( int j = 0; j < sei_svc->layers[i].num_seq_parameter_sets; j++ )
            {
                value( sei_svc->layers[i].seq_parameter_set_id_delta[j], ue );
            }
            value( sei_svc->layers[i].num_subset_seq_parameter_sets, ue );
            for( int j = 0; j < sei_svc->layers[i].num_subset_seq_parameter_sets; j++ )
            {
                value( sei_svc->layers[i].subset_seq_parameter_set_id_delta[j], ue );
            }
            value( sei_svc->layers[i].num_pic_parameter_sets_minus1, ue );
            for( int j = 0; j < sei_svc->layers[i].num_pic_parameter_sets_minus1; j++ )
            {
                value( sei_svc->layers[i].pic_parameter_set_id_delta[j], ue );
            }
        }
        else
        {
            value( sei_svc->layers[i].parameter_sets_info_src_layer_id_delta, ue );
        }
        if( sei_svc->layers[i].bitstream_restriction_info_present_flag )
        {
            value( sei_svc->layers[i].motion_vectors_over_pic_boundaries_flag, u1 );
            value( sei_svc->layers[i].max_bytes_per_pic_denom, ue );
            value( sei_svc->layers[i].max_bits_per_mb_denom, ue );
            value( sei_svc->layers[i].log2_max_mv_length_horizontal, ue );
            value( sei_svc->layers[i].log2_max_mv_length_vertical, ue );
            value( sei_svc->layers[i].max_num_reorder_frames, ue );
            value( sei_svc->layers[i].max_dec_frame_buffering, ue );
        }
        if( sei_svc->layers[i].layer_conversion_flag )
        {
            value( sei_svc->layers[i].conversion_type_idc, ue );
            for( int j = 0; j < 2; j++ )
            {
                value( sei_svc->layers[i].rewriting_info_flag[j], u(1) );
                if( sei_svc->layers[i].rewriting_info_flag[j] )
                {
                    value( sei_svc->layers[i].rewriting_profile_level_idc[j], u(24) );
                    value( sei_svc->layers[i].rewriting_avg_bitrate[j], u(16) );
                    value( sei_svc->layers[i].rewriting_max_bitrate[j], u(16) );
                }
            }
        }
    }

    if( sei_svc->priority_layer_info_present_flag )
    {
        value( sei_svc->pr_num_dIds_minus1, ue );
        
        for( int i = 0; i <= sei_svc->pr_num_dIds_minus1; i++ ) {
            value( sei_svc->pr[i].pr_dependency_id, u(3) );
            value( sei_svc->pr[i].pr_num_minus1, ue );
            for( int j = 0; j <= sei_svc->pr[i].pr_num_minus1; j++ )
            {
                value( sei_svc->pr[i].pr_info[j].pr_id, ue );
                value( sei_svc->pr[i].pr_info[j].pr_profile_level_idc, u(24) );
                value( sei_svc->pr[i].pr_info[j].pr_avg_bitrate, u(16) );
                value( sei_svc->pr[i].pr_info[j].pr_max_bitrate, u(16) );
            }
        }
        
    }

}

// D.1 SEI payload syntax
void structure(sei_payload)( h264_stream_t* h, bs_t* b )
{
    sei_t* s = h->sei;
    
    int i;
    switch( s->payloadType )
    {
        case SEI_TYPE_SCALABILITY_INFO:
            if( is_reading )
            {
                s->sei_svc = (uint8_t*)calloc( 1, sizeof(sei_scalability_info_t) );
            }
            structure(sei_scalability_info)( h, b );
            break;
        default:
            if( is_reading )
            {
                s->data = (uint8_t*)calloc(1, s->payloadSize);
            }
            
            for ( i = 0; i < s->payloadSize; i++ )
                value( s->data[i], u8 );
    }
    
    //if( is_reading )
    //    read_sei_end_bits(h, b);
}
