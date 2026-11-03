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



void read_sei_scalability_info( h264_stream_t* h, bs_t* b );
void read_sei_payload( h264_stream_t* h, bs_t* b );


// Appendix G.13.1.1 Scalability information SEI message syntax
void read_sei_scalability_info( h264_stream_t* h, bs_t* b )
{
    sei_scalability_info_t* sei_svc = h->sei->sei_svc;
    
    sei_svc->temporal_id_nesting_flag = bs_read_u1(b);
    sei_svc->priority_layer_info_present_flag = bs_read_u1(b);
    sei_svc->priority_id_setting_flag = bs_read_u1(b);
    sei_svc->num_layers_minus1 = bs_read_ue(b);
    
    for( int i = 0; i <= sei_svc->num_layers_minus1; i++ ) {
        sei_svc->layers[i].layer_id = bs_read_ue(b);
        sei_svc->layers[i].priority_id = bs_read_u(b, 6);
        sei_svc->layers[i].discardable_flag = bs_read_u1(b);
        sei_svc->layers[i].dependency_id = bs_read_u(b, 3);
        sei_svc->layers[i].quality_id = bs_read_u(b, 4);
        sei_svc->layers[i].temporal_id = bs_read_u(b, 3);
        sei_svc->layers[i].sub_pic_layer_flag = bs_read_u1(b);
        sei_svc->layers[i].sub_region_layer_flag = bs_read_u1(b);
        sei_svc->layers[i].iroi_division_info_present_flag = bs_read_u1(b);
        sei_svc->layers[i].profile_level_info_present_flag = bs_read_u1(b);
        sei_svc->layers[i].bitrate_info_present_flag = bs_read_u1(b);
        sei_svc->layers[i].frm_rate_info_present_flag = bs_read_u1(b);
        sei_svc->layers[i].frm_size_info_present_flag = bs_read_u1(b);
        sei_svc->layers[i].layer_dependency_info_present_flag = bs_read_u1(b);
        sei_svc->layers[i].parameter_sets_info_present_flag = bs_read_u1(b);
        sei_svc->layers[i].bitstream_restriction_info_present_flag = bs_read_u1(b);
        sei_svc->layers[i].exact_inter_layer_pred_flag = bs_read_u1(b);
        if( sei_svc->layers[i].sub_pic_layer_flag ||
            sei_svc->layers[i].iroi_division_info_present_flag )
        {
            sei_svc->layers[i].exact_sample_value_match_flag = bs_read_u1(b);
        }
        sei_svc->layers[i].layer_conversion_flag = bs_read_u1(b);
        sei_svc->layers[i].layer_output_flag = bs_read_u1(b);
        if( sei_svc->layers[i].profile_level_info_present_flag )
        {
            sei_svc->layers[i].layer_profile_level_idc = bs_read_u(b, 24);
        }
        if( sei_svc->layers[i].bitrate_info_present_flag )
        {
            sei_svc->layers[i].avg_bitrate = bs_read_u(b, 16);
            sei_svc->layers[i].max_bitrate_layer = bs_read_u(b, 16);
            sei_svc->layers[i].max_bitrate_layer_representation = bs_read_u(b, 16);
            sei_svc->layers[i].max_bitrate_calc_window = bs_read_u(b, 16);
        }
        if( sei_svc->layers[i].frm_rate_info_present_flag )
        {
            sei_svc->layers[i].constant_frm_rate_idc = bs_read_u(b, 2);
            sei_svc->layers[i].avg_frm_rate = bs_read_u(b, 16);
        }
        if( sei_svc->layers[i].frm_size_info_present_flag ||
            sei_svc->layers[i].iroi_division_info_present_flag )
        {
            sei_svc->layers[i].frm_width_in_mbs_minus1 = bs_read_ue(b);
            sei_svc->layers[i].frm_height_in_mbs_minus1 = bs_read_ue(b);
        }
        if( sei_svc->layers[i].sub_region_layer_flag )
        {
            sei_svc->layers[i].base_region_layer_id = bs_read_ue(b);
            sei_svc->layers[i].dynamic_rect_flag = bs_read_u1(b);
            if( sei_svc->layers[i].dynamic_rect_flag )
            {
                sei_svc->layers[i].horizontal_offset = bs_read_u(b, 16);
                sei_svc->layers[i].vertical_offset = bs_read_u(b, 16);
                sei_svc->layers[i].region_width = bs_read_u(b, 16);
                sei_svc->layers[i].region_height = bs_read_u(b, 16);
            }
        }
        if( sei_svc->layers[i].sub_pic_layer_flag )
        {
            sei_svc->layers[i].roi_id = bs_read_ue(b);
        }
        if( sei_svc->layers[i].iroi_division_info_present_flag )
        {
            sei_svc->layers[i].iroi_grid_flag = bs_read_u1(b);
            if( sei_svc->layers[i].iroi_grid_flag )
            {
                sei_svc->layers[i].grid_width_in_mbs_minus1 = bs_read_ue(b);
                sei_svc->layers[i].grid_height_in_mbs_minus1 = bs_read_ue(b);
            }
            else
            {
                sei_svc->layers[i].num_rois_minus1 = bs_read_ue(b);
                
                for( int j = 0; j <= sei_svc->layers[i].num_rois_minus1; j++ )
                {
                    sei_svc->layers[i].roi[j].first_mb_in_roi = bs_read_ue(b);
                    sei_svc->layers[i].roi[j].roi_width_in_mbs_minus1 = bs_read_ue(b);
                    sei_svc->layers[i].roi[j].roi_height_in_mbs_minus1 = bs_read_ue(b);
                }
            }
        }
        if( sei_svc->layers[i].layer_dependency_info_present_flag )
        {
            sei_svc->layers[i].num_directly_dependent_layers = bs_read_ue(b);
            for( int j = 0; j < sei_svc->layers[i].num_directly_dependent_layers; j++ )
            {
                sei_svc->layers[i].directly_dependent_layer_id_delta_minus1[j] = bs_read_ue(b);
            }
        }
        else
        {
            sei_svc->layers[i].layer_dependency_info_src_layer_id_delta = bs_read_ue(b);
        }
        if( sei_svc->layers[i].parameter_sets_info_present_flag )
        {
            sei_svc->layers[i].num_seq_parameter_sets = bs_read_ue(b);
            for( int j = 0; j < sei_svc->layers[i].num_seq_parameter_sets; j++ )
            {
                sei_svc->layers[i].seq_parameter_set_id_delta[j] = bs_read_ue(b);
            }
            sei_svc->layers[i].num_subset_seq_parameter_sets = bs_read_ue(b);
            for( int j = 0; j < sei_svc->layers[i].num_subset_seq_parameter_sets; j++ )
            {
                sei_svc->layers[i].subset_seq_parameter_set_id_delta[j] = bs_read_ue(b);
            }
            sei_svc->layers[i].num_pic_parameter_sets_minus1 = bs_read_ue(b);
            for( int j = 0; j < sei_svc->layers[i].num_pic_parameter_sets_minus1; j++ )
            {
                sei_svc->layers[i].pic_parameter_set_id_delta[j] = bs_read_ue(b);
            }
        }
        else
        {
            sei_svc->layers[i].parameter_sets_info_src_layer_id_delta = bs_read_ue(b);
        }
        if( sei_svc->layers[i].bitstream_restriction_info_present_flag )
        {
            sei_svc->layers[i].motion_vectors_over_pic_boundaries_flag = bs_read_u1(b);
            sei_svc->layers[i].max_bytes_per_pic_denom = bs_read_ue(b);
            sei_svc->layers[i].max_bits_per_mb_denom = bs_read_ue(b);
            sei_svc->layers[i].log2_max_mv_length_horizontal = bs_read_ue(b);
            sei_svc->layers[i].log2_max_mv_length_vertical = bs_read_ue(b);
            sei_svc->layers[i].max_num_reorder_frames = bs_read_ue(b);
            sei_svc->layers[i].max_dec_frame_buffering = bs_read_ue(b);
        }
        if( sei_svc->layers[i].layer_conversion_flag )
        {
            sei_svc->layers[i].conversion_type_idc = bs_read_ue(b);
            for( int j = 0; j < 2; j++ )
            {
                sei_svc->layers[i].rewriting_info_flag[j] = bs_read_u(b, 1);
                if( sei_svc->layers[i].rewriting_info_flag[j] )
                {
                    sei_svc->layers[i].rewriting_profile_level_idc[j] = bs_read_u(b, 24);
                    sei_svc->layers[i].rewriting_avg_bitrate[j] = bs_read_u(b, 16);
                    sei_svc->layers[i].rewriting_max_bitrate[j] = bs_read_u(b, 16);
                }
            }
        }
    }

    if( sei_svc->priority_layer_info_present_flag )
    {
        sei_svc->pr_num_dIds_minus1 = bs_read_ue(b);
        
        for( int i = 0; i <= sei_svc->pr_num_dIds_minus1; i++ ) {
            sei_svc->pr[i].pr_dependency_id = bs_read_u(b, 3);
            sei_svc->pr[i].pr_num_minus1 = bs_read_ue(b);
            for( int j = 0; j <= sei_svc->pr[i].pr_num_minus1; j++ )
            {
                sei_svc->pr[i].pr_info[j].pr_id = bs_read_ue(b);
                sei_svc->pr[i].pr_info[j].pr_profile_level_idc = bs_read_u(b, 24);
                sei_svc->pr[i].pr_info[j].pr_avg_bitrate = bs_read_u(b, 16);
                sei_svc->pr[i].pr_info[j].pr_max_bitrate = bs_read_u(b, 16);
            }
        }
        
    }

}

// D.1 SEI payload syntax
void read_sei_payload( h264_stream_t* h, bs_t* b )
{
    sei_t* s = h->sei;
    
    int i;
    switch( s->payloadType )
    {
        case SEI_TYPE_SCALABILITY_INFO:
            if( 1 )
            {
                s->sei_svc = (sei_scalability_info_t*)calloc( 1, sizeof(sei_scalability_info_t) );
            }
            read_sei_scalability_info( h, b );
            break;
        default:
            if( 1 )
            {
                s->data = (uint8_t*)calloc(1, s->payloadSize);
            }
            
            for ( i = 0; i < s->payloadSize; i++ )
                s->data[i] = bs_read_u8(b);
    }
    
    //if( 1 )
    //    read_sei_end_bits(h, b);
}


void write_sei_scalability_info( h264_stream_t* h, bs_t* b );
void write_sei_payload( h264_stream_t* h, bs_t* b );


// Appendix G.13.1.1 Scalability information SEI message syntax
void write_sei_scalability_info( h264_stream_t* h, bs_t* b )
{
    sei_scalability_info_t* sei_svc = h->sei->sei_svc;
    
    bs_write_u1(b, sei_svc->temporal_id_nesting_flag);
    bs_write_u1(b, sei_svc->priority_layer_info_present_flag);
    bs_write_u1(b, sei_svc->priority_id_setting_flag);
    bs_write_ue(b, sei_svc->num_layers_minus1);
    
    for( int i = 0; i <= sei_svc->num_layers_minus1; i++ ) {
        bs_write_ue(b, sei_svc->layers[i].layer_id);
        bs_write_u(b, 6, sei_svc->layers[i].priority_id);
        bs_write_u1(b, sei_svc->layers[i].discardable_flag);
        bs_write_u(b, 3, sei_svc->layers[i].dependency_id);
        bs_write_u(b, 4, sei_svc->layers[i].quality_id);
        bs_write_u(b, 3, sei_svc->layers[i].temporal_id);
        bs_write_u1(b, sei_svc->layers[i].sub_pic_layer_flag);
        bs_write_u1(b, sei_svc->layers[i].sub_region_layer_flag);
        bs_write_u1(b, sei_svc->layers[i].iroi_division_info_present_flag);
        bs_write_u1(b, sei_svc->layers[i].profile_level_info_present_flag);
        bs_write_u1(b, sei_svc->layers[i].bitrate_info_present_flag);
        bs_write_u1(b, sei_svc->layers[i].frm_rate_info_present_flag);
        bs_write_u1(b, sei_svc->layers[i].frm_size_info_present_flag);
        bs_write_u1(b, sei_svc->layers[i].layer_dependency_info_present_flag);
        bs_write_u1(b, sei_svc->layers[i].parameter_sets_info_present_flag);
        bs_write_u1(b, sei_svc->layers[i].bitstream_restriction_info_present_flag);
        bs_write_u1(b, sei_svc->layers[i].exact_inter_layer_pred_flag);
        if( sei_svc->layers[i].sub_pic_layer_flag ||
            sei_svc->layers[i].iroi_division_info_present_flag )
        {
            bs_write_u1(b, sei_svc->layers[i].exact_sample_value_match_flag);
        }
        bs_write_u1(b, sei_svc->layers[i].layer_conversion_flag);
        bs_write_u1(b, sei_svc->layers[i].layer_output_flag);
        if( sei_svc->layers[i].profile_level_info_present_flag )
        {
            bs_write_u(b, 24, sei_svc->layers[i].layer_profile_level_idc);
        }
        if( sei_svc->layers[i].bitrate_info_present_flag )
        {
            bs_write_u(b, 16, sei_svc->layers[i].avg_bitrate);
            bs_write_u(b, 16, sei_svc->layers[i].max_bitrate_layer);
            bs_write_u(b, 16, sei_svc->layers[i].max_bitrate_layer_representation);
            bs_write_u(b, 16, sei_svc->layers[i].max_bitrate_calc_window);
        }
        if( sei_svc->layers[i].frm_rate_info_present_flag )
        {
            bs_write_u(b, 2, sei_svc->layers[i].constant_frm_rate_idc);
            bs_write_u(b, 16, sei_svc->layers[i].avg_frm_rate);
        }
        if( sei_svc->layers[i].frm_size_info_present_flag ||
            sei_svc->layers[i].iroi_division_info_present_flag )
        {
            bs_write_ue(b, sei_svc->layers[i].frm_width_in_mbs_minus1);
            bs_write_ue(b, sei_svc->layers[i].frm_height_in_mbs_minus1);
        }
        if( sei_svc->layers[i].sub_region_layer_flag )
        {
            bs_write_ue(b, sei_svc->layers[i].base_region_layer_id);
            bs_write_u1(b, sei_svc->layers[i].dynamic_rect_flag);
            if( sei_svc->layers[i].dynamic_rect_flag )
            {
                bs_write_u(b, 16, sei_svc->layers[i].horizontal_offset);
                bs_write_u(b, 16, sei_svc->layers[i].vertical_offset);
                bs_write_u(b, 16, sei_svc->layers[i].region_width);
                bs_write_u(b, 16, sei_svc->layers[i].region_height);
            }
        }
        if( sei_svc->layers[i].sub_pic_layer_flag )
        {
            bs_write_ue(b, sei_svc->layers[i].roi_id);
        }
        if( sei_svc->layers[i].iroi_division_info_present_flag )
        {
            bs_write_u1(b, sei_svc->layers[i].iroi_grid_flag);
            if( sei_svc->layers[i].iroi_grid_flag )
            {
                bs_write_ue(b, sei_svc->layers[i].grid_width_in_mbs_minus1);
                bs_write_ue(b, sei_svc->layers[i].grid_height_in_mbs_minus1);
            }
            else
            {
                bs_write_ue(b, sei_svc->layers[i].num_rois_minus1);
                
                for( int j = 0; j <= sei_svc->layers[i].num_rois_minus1; j++ )
                {
                    bs_write_ue(b, sei_svc->layers[i].roi[j].first_mb_in_roi);
                    bs_write_ue(b, sei_svc->layers[i].roi[j].roi_width_in_mbs_minus1);
                    bs_write_ue(b, sei_svc->layers[i].roi[j].roi_height_in_mbs_minus1);
                }
            }
        }
        if( sei_svc->layers[i].layer_dependency_info_present_flag )
        {
            bs_write_ue(b, sei_svc->layers[i].num_directly_dependent_layers);
            for( int j = 0; j < sei_svc->layers[i].num_directly_dependent_layers; j++ )
            {
                bs_write_ue(b, sei_svc->layers[i].directly_dependent_layer_id_delta_minus1[j]);
            }
        }
        else
        {
            bs_write_ue(b, sei_svc->layers[i].layer_dependency_info_src_layer_id_delta);
        }
        if( sei_svc->layers[i].parameter_sets_info_present_flag )
        {
            bs_write_ue(b, sei_svc->layers[i].num_seq_parameter_sets);
            for( int j = 0; j < sei_svc->layers[i].num_seq_parameter_sets; j++ )
            {
                bs_write_ue(b, sei_svc->layers[i].seq_parameter_set_id_delta[j]);
            }
            bs_write_ue(b, sei_svc->layers[i].num_subset_seq_parameter_sets);
            for( int j = 0; j < sei_svc->layers[i].num_subset_seq_parameter_sets; j++ )
            {
                bs_write_ue(b, sei_svc->layers[i].subset_seq_parameter_set_id_delta[j]);
            }
            bs_write_ue(b, sei_svc->layers[i].num_pic_parameter_sets_minus1);
            for( int j = 0; j < sei_svc->layers[i].num_pic_parameter_sets_minus1; j++ )
            {
                bs_write_ue(b, sei_svc->layers[i].pic_parameter_set_id_delta[j]);
            }
        }
        else
        {
            bs_write_ue(b, sei_svc->layers[i].parameter_sets_info_src_layer_id_delta);
        }
        if( sei_svc->layers[i].bitstream_restriction_info_present_flag )
        {
            bs_write_u1(b, sei_svc->layers[i].motion_vectors_over_pic_boundaries_flag);
            bs_write_ue(b, sei_svc->layers[i].max_bytes_per_pic_denom);
            bs_write_ue(b, sei_svc->layers[i].max_bits_per_mb_denom);
            bs_write_ue(b, sei_svc->layers[i].log2_max_mv_length_horizontal);
            bs_write_ue(b, sei_svc->layers[i].log2_max_mv_length_vertical);
            bs_write_ue(b, sei_svc->layers[i].max_num_reorder_frames);
            bs_write_ue(b, sei_svc->layers[i].max_dec_frame_buffering);
        }
        if( sei_svc->layers[i].layer_conversion_flag )
        {
            bs_write_ue(b, sei_svc->layers[i].conversion_type_idc);
            for( int j = 0; j < 2; j++ )
            {
                bs_write_u(b, 1, sei_svc->layers[i].rewriting_info_flag[j]);
                if( sei_svc->layers[i].rewriting_info_flag[j] )
                {
                    bs_write_u(b, 24, sei_svc->layers[i].rewriting_profile_level_idc[j]);
                    bs_write_u(b, 16, sei_svc->layers[i].rewriting_avg_bitrate[j]);
                    bs_write_u(b, 16, sei_svc->layers[i].rewriting_max_bitrate[j]);
                }
            }
        }
    }

    if( sei_svc->priority_layer_info_present_flag )
    {
        bs_write_ue(b, sei_svc->pr_num_dIds_minus1);
        
        for( int i = 0; i <= sei_svc->pr_num_dIds_minus1; i++ ) {
            bs_write_u(b, 3, sei_svc->pr[i].pr_dependency_id);
            bs_write_ue(b, sei_svc->pr[i].pr_num_minus1);
            for( int j = 0; j <= sei_svc->pr[i].pr_num_minus1; j++ )
            {
                bs_write_ue(b, sei_svc->pr[i].pr_info[j].pr_id);
                bs_write_u(b, 24, sei_svc->pr[i].pr_info[j].pr_profile_level_idc);
                bs_write_u(b, 16, sei_svc->pr[i].pr_info[j].pr_avg_bitrate);
                bs_write_u(b, 16, sei_svc->pr[i].pr_info[j].pr_max_bitrate);
            }
        }
        
    }

}

// D.1 SEI payload syntax
void write_sei_payload( h264_stream_t* h, bs_t* b )
{
    sei_t* s = h->sei;
    
    int i;
    switch( s->payloadType )
    {
        case SEI_TYPE_SCALABILITY_INFO:
            if( 0 )
            {
                s->sei_svc = (sei_scalability_info_t*)calloc( 1, sizeof(sei_scalability_info_t) );
            }
            write_sei_scalability_info( h, b );
            break;
        default:
            if( 0 )
            {
                s->data = (uint8_t*)calloc(1, s->payloadSize);
            }
            
            for ( i = 0; i < s->payloadSize; i++ )
                bs_write_u8(b, s->data[i]);
    }
    
    //if( 0 )
    //    read_sei_end_bits(h, b);
}


void read_debug_sei_scalability_info( h264_stream_t* h, bs_t* b );
void read_debug_sei_payload( h264_stream_t* h, bs_t* b );


// Appendix G.13.1.1 Scalability information SEI message syntax
void read_debug_sei_scalability_info( h264_stream_t* h, bs_t* b )
{
    sei_scalability_info_t* sei_svc = h->sei->sei_svc;
    
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->temporal_id_nesting_flag = bs_read_u1(b); printf("sei_svc->temporal_id_nesting_flag: %d \n", sei_svc->temporal_id_nesting_flag); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->priority_layer_info_present_flag = bs_read_u1(b); printf("sei_svc->priority_layer_info_present_flag: %d \n", sei_svc->priority_layer_info_present_flag); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->priority_id_setting_flag = bs_read_u1(b); printf("sei_svc->priority_id_setting_flag: %d \n", sei_svc->priority_id_setting_flag); 
    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->num_layers_minus1 = bs_read_ue(b); printf("sei_svc->num_layers_minus1: %d \n", sei_svc->num_layers_minus1); 
    
    for( int i = 0; i <= sei_svc->num_layers_minus1; i++ ) {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].layer_id = bs_read_ue(b); printf("sei_svc->layers[i].layer_id: %d \n", sei_svc->layers[i].layer_id); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].priority_id = bs_read_u(b, 6); printf("sei_svc->layers[i].priority_id: %d \n", sei_svc->layers[i].priority_id); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].discardable_flag = bs_read_u1(b); printf("sei_svc->layers[i].discardable_flag: %d \n", sei_svc->layers[i].discardable_flag); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].dependency_id = bs_read_u(b, 3); printf("sei_svc->layers[i].dependency_id: %d \n", sei_svc->layers[i].dependency_id); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].quality_id = bs_read_u(b, 4); printf("sei_svc->layers[i].quality_id: %d \n", sei_svc->layers[i].quality_id); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].temporal_id = bs_read_u(b, 3); printf("sei_svc->layers[i].temporal_id: %d \n", sei_svc->layers[i].temporal_id); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].sub_pic_layer_flag = bs_read_u1(b); printf("sei_svc->layers[i].sub_pic_layer_flag: %d \n", sei_svc->layers[i].sub_pic_layer_flag); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].sub_region_layer_flag = bs_read_u1(b); printf("sei_svc->layers[i].sub_region_layer_flag: %d \n", sei_svc->layers[i].sub_region_layer_flag); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].iroi_division_info_present_flag = bs_read_u1(b); printf("sei_svc->layers[i].iroi_division_info_present_flag: %d \n", sei_svc->layers[i].iroi_division_info_present_flag); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].profile_level_info_present_flag = bs_read_u1(b); printf("sei_svc->layers[i].profile_level_info_present_flag: %d \n", sei_svc->layers[i].profile_level_info_present_flag); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].bitrate_info_present_flag = bs_read_u1(b); printf("sei_svc->layers[i].bitrate_info_present_flag: %d \n", sei_svc->layers[i].bitrate_info_present_flag); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].frm_rate_info_present_flag = bs_read_u1(b); printf("sei_svc->layers[i].frm_rate_info_present_flag: %d \n", sei_svc->layers[i].frm_rate_info_present_flag); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].frm_size_info_present_flag = bs_read_u1(b); printf("sei_svc->layers[i].frm_size_info_present_flag: %d \n", sei_svc->layers[i].frm_size_info_present_flag); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].layer_dependency_info_present_flag = bs_read_u1(b); printf("sei_svc->layers[i].layer_dependency_info_present_flag: %d \n", sei_svc->layers[i].layer_dependency_info_present_flag); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].parameter_sets_info_present_flag = bs_read_u1(b); printf("sei_svc->layers[i].parameter_sets_info_present_flag: %d \n", sei_svc->layers[i].parameter_sets_info_present_flag); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].bitstream_restriction_info_present_flag = bs_read_u1(b); printf("sei_svc->layers[i].bitstream_restriction_info_present_flag: %d \n", sei_svc->layers[i].bitstream_restriction_info_present_flag); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].exact_inter_layer_pred_flag = bs_read_u1(b); printf("sei_svc->layers[i].exact_inter_layer_pred_flag: %d \n", sei_svc->layers[i].exact_inter_layer_pred_flag); 
        if( sei_svc->layers[i].sub_pic_layer_flag ||
            sei_svc->layers[i].iroi_division_info_present_flag )
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].exact_sample_value_match_flag = bs_read_u1(b); printf("sei_svc->layers[i].exact_sample_value_match_flag: %d \n", sei_svc->layers[i].exact_sample_value_match_flag); 
        }
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].layer_conversion_flag = bs_read_u1(b); printf("sei_svc->layers[i].layer_conversion_flag: %d \n", sei_svc->layers[i].layer_conversion_flag); 
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].layer_output_flag = bs_read_u1(b); printf("sei_svc->layers[i].layer_output_flag: %d \n", sei_svc->layers[i].layer_output_flag); 
        if( sei_svc->layers[i].profile_level_info_present_flag )
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].layer_profile_level_idc = bs_read_u(b, 24); printf("sei_svc->layers[i].layer_profile_level_idc: %d \n", sei_svc->layers[i].layer_profile_level_idc); 
        }
        if( sei_svc->layers[i].bitrate_info_present_flag )
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].avg_bitrate = bs_read_u(b, 16); printf("sei_svc->layers[i].avg_bitrate: %d \n", sei_svc->layers[i].avg_bitrate); 
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].max_bitrate_layer = bs_read_u(b, 16); printf("sei_svc->layers[i].max_bitrate_layer: %d \n", sei_svc->layers[i].max_bitrate_layer); 
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].max_bitrate_layer_representation = bs_read_u(b, 16); printf("sei_svc->layers[i].max_bitrate_layer_representation: %d \n", sei_svc->layers[i].max_bitrate_layer_representation); 
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].max_bitrate_calc_window = bs_read_u(b, 16); printf("sei_svc->layers[i].max_bitrate_calc_window: %d \n", sei_svc->layers[i].max_bitrate_calc_window); 
        }
        if( sei_svc->layers[i].frm_rate_info_present_flag )
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].constant_frm_rate_idc = bs_read_u(b, 2); printf("sei_svc->layers[i].constant_frm_rate_idc: %d \n", sei_svc->layers[i].constant_frm_rate_idc); 
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].avg_frm_rate = bs_read_u(b, 16); printf("sei_svc->layers[i].avg_frm_rate: %d \n", sei_svc->layers[i].avg_frm_rate); 
        }
        if( sei_svc->layers[i].frm_size_info_present_flag ||
            sei_svc->layers[i].iroi_division_info_present_flag )
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].frm_width_in_mbs_minus1 = bs_read_ue(b); printf("sei_svc->layers[i].frm_width_in_mbs_minus1: %d \n", sei_svc->layers[i].frm_width_in_mbs_minus1); 
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].frm_height_in_mbs_minus1 = bs_read_ue(b); printf("sei_svc->layers[i].frm_height_in_mbs_minus1: %d \n", sei_svc->layers[i].frm_height_in_mbs_minus1); 
        }
        if( sei_svc->layers[i].sub_region_layer_flag )
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].base_region_layer_id = bs_read_ue(b); printf("sei_svc->layers[i].base_region_layer_id: %d \n", sei_svc->layers[i].base_region_layer_id); 
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].dynamic_rect_flag = bs_read_u1(b); printf("sei_svc->layers[i].dynamic_rect_flag: %d \n", sei_svc->layers[i].dynamic_rect_flag); 
            if( sei_svc->layers[i].dynamic_rect_flag )
            {
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].horizontal_offset = bs_read_u(b, 16); printf("sei_svc->layers[i].horizontal_offset: %d \n", sei_svc->layers[i].horizontal_offset); 
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].vertical_offset = bs_read_u(b, 16); printf("sei_svc->layers[i].vertical_offset: %d \n", sei_svc->layers[i].vertical_offset); 
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].region_width = bs_read_u(b, 16); printf("sei_svc->layers[i].region_width: %d \n", sei_svc->layers[i].region_width); 
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].region_height = bs_read_u(b, 16); printf("sei_svc->layers[i].region_height: %d \n", sei_svc->layers[i].region_height); 
            }
        }
        if( sei_svc->layers[i].sub_pic_layer_flag )
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].roi_id = bs_read_ue(b); printf("sei_svc->layers[i].roi_id: %d \n", sei_svc->layers[i].roi_id); 
        }
        if( sei_svc->layers[i].iroi_division_info_present_flag )
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].iroi_grid_flag = bs_read_u1(b); printf("sei_svc->layers[i].iroi_grid_flag: %d \n", sei_svc->layers[i].iroi_grid_flag); 
            if( sei_svc->layers[i].iroi_grid_flag )
            {
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].grid_width_in_mbs_minus1 = bs_read_ue(b); printf("sei_svc->layers[i].grid_width_in_mbs_minus1: %d \n", sei_svc->layers[i].grid_width_in_mbs_minus1); 
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].grid_height_in_mbs_minus1 = bs_read_ue(b); printf("sei_svc->layers[i].grid_height_in_mbs_minus1: %d \n", sei_svc->layers[i].grid_height_in_mbs_minus1); 
            }
            else
            {
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].num_rois_minus1 = bs_read_ue(b); printf("sei_svc->layers[i].num_rois_minus1: %d \n", sei_svc->layers[i].num_rois_minus1); 
                
                for( int j = 0; j <= sei_svc->layers[i].num_rois_minus1; j++ )
                {
                    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].roi[j].first_mb_in_roi = bs_read_ue(b); printf("sei_svc->layers[i].roi[j].first_mb_in_roi: %d \n", sei_svc->layers[i].roi[j].first_mb_in_roi); 
                    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].roi[j].roi_width_in_mbs_minus1 = bs_read_ue(b); printf("sei_svc->layers[i].roi[j].roi_width_in_mbs_minus1: %d \n", sei_svc->layers[i].roi[j].roi_width_in_mbs_minus1); 
                    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].roi[j].roi_height_in_mbs_minus1 = bs_read_ue(b); printf("sei_svc->layers[i].roi[j].roi_height_in_mbs_minus1: %d \n", sei_svc->layers[i].roi[j].roi_height_in_mbs_minus1); 
                }
            }
        }
        if( sei_svc->layers[i].layer_dependency_info_present_flag )
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].num_directly_dependent_layers = bs_read_ue(b); printf("sei_svc->layers[i].num_directly_dependent_layers: %d \n", sei_svc->layers[i].num_directly_dependent_layers); 
            for( int j = 0; j < sei_svc->layers[i].num_directly_dependent_layers; j++ )
            {
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].directly_dependent_layer_id_delta_minus1[j] = bs_read_ue(b); printf("sei_svc->layers[i].directly_dependent_layer_id_delta_minus1[j]: %d \n", sei_svc->layers[i].directly_dependent_layer_id_delta_minus1[j]); 
            }
        }
        else
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].layer_dependency_info_src_layer_id_delta = bs_read_ue(b); printf("sei_svc->layers[i].layer_dependency_info_src_layer_id_delta: %d \n", sei_svc->layers[i].layer_dependency_info_src_layer_id_delta); 
        }
        if( sei_svc->layers[i].parameter_sets_info_present_flag )
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].num_seq_parameter_sets = bs_read_ue(b); printf("sei_svc->layers[i].num_seq_parameter_sets: %d \n", sei_svc->layers[i].num_seq_parameter_sets); 
            for( int j = 0; j < sei_svc->layers[i].num_seq_parameter_sets; j++ )
            {
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].seq_parameter_set_id_delta[j] = bs_read_ue(b); printf("sei_svc->layers[i].seq_parameter_set_id_delta[j]: %d \n", sei_svc->layers[i].seq_parameter_set_id_delta[j]); 
            }
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].num_subset_seq_parameter_sets = bs_read_ue(b); printf("sei_svc->layers[i].num_subset_seq_parameter_sets: %d \n", sei_svc->layers[i].num_subset_seq_parameter_sets); 
            for( int j = 0; j < sei_svc->layers[i].num_subset_seq_parameter_sets; j++ )
            {
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].subset_seq_parameter_set_id_delta[j] = bs_read_ue(b); printf("sei_svc->layers[i].subset_seq_parameter_set_id_delta[j]: %d \n", sei_svc->layers[i].subset_seq_parameter_set_id_delta[j]); 
            }
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].num_pic_parameter_sets_minus1 = bs_read_ue(b); printf("sei_svc->layers[i].num_pic_parameter_sets_minus1: %d \n", sei_svc->layers[i].num_pic_parameter_sets_minus1); 
            for( int j = 0; j < sei_svc->layers[i].num_pic_parameter_sets_minus1; j++ )
            {
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].pic_parameter_set_id_delta[j] = bs_read_ue(b); printf("sei_svc->layers[i].pic_parameter_set_id_delta[j]: %d \n", sei_svc->layers[i].pic_parameter_set_id_delta[j]); 
            }
        }
        else
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].parameter_sets_info_src_layer_id_delta = bs_read_ue(b); printf("sei_svc->layers[i].parameter_sets_info_src_layer_id_delta: %d \n", sei_svc->layers[i].parameter_sets_info_src_layer_id_delta); 
        }
        if( sei_svc->layers[i].bitstream_restriction_info_present_flag )
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].motion_vectors_over_pic_boundaries_flag = bs_read_u1(b); printf("sei_svc->layers[i].motion_vectors_over_pic_boundaries_flag: %d \n", sei_svc->layers[i].motion_vectors_over_pic_boundaries_flag); 
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].max_bytes_per_pic_denom = bs_read_ue(b); printf("sei_svc->layers[i].max_bytes_per_pic_denom: %d \n", sei_svc->layers[i].max_bytes_per_pic_denom); 
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].max_bits_per_mb_denom = bs_read_ue(b); printf("sei_svc->layers[i].max_bits_per_mb_denom: %d \n", sei_svc->layers[i].max_bits_per_mb_denom); 
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].log2_max_mv_length_horizontal = bs_read_ue(b); printf("sei_svc->layers[i].log2_max_mv_length_horizontal: %d \n", sei_svc->layers[i].log2_max_mv_length_horizontal); 
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].log2_max_mv_length_vertical = bs_read_ue(b); printf("sei_svc->layers[i].log2_max_mv_length_vertical: %d \n", sei_svc->layers[i].log2_max_mv_length_vertical); 
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].max_num_reorder_frames = bs_read_ue(b); printf("sei_svc->layers[i].max_num_reorder_frames: %d \n", sei_svc->layers[i].max_num_reorder_frames); 
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].max_dec_frame_buffering = bs_read_ue(b); printf("sei_svc->layers[i].max_dec_frame_buffering: %d \n", sei_svc->layers[i].max_dec_frame_buffering); 
        }
        if( sei_svc->layers[i].layer_conversion_flag )
        {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].conversion_type_idc = bs_read_ue(b); printf("sei_svc->layers[i].conversion_type_idc: %d \n", sei_svc->layers[i].conversion_type_idc); 
            for( int j = 0; j < 2; j++ )
            {
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].rewriting_info_flag[j] = bs_read_u(b, 1); printf("sei_svc->layers[i].rewriting_info_flag[j]: %d \n", sei_svc->layers[i].rewriting_info_flag[j]); 
                if( sei_svc->layers[i].rewriting_info_flag[j] )
                {
                    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].rewriting_profile_level_idc[j] = bs_read_u(b, 24); printf("sei_svc->layers[i].rewriting_profile_level_idc[j]: %d \n", sei_svc->layers[i].rewriting_profile_level_idc[j]); 
                    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].rewriting_avg_bitrate[j] = bs_read_u(b, 16); printf("sei_svc->layers[i].rewriting_avg_bitrate[j]: %d \n", sei_svc->layers[i].rewriting_avg_bitrate[j]); 
                    printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->layers[i].rewriting_max_bitrate[j] = bs_read_u(b, 16); printf("sei_svc->layers[i].rewriting_max_bitrate[j]: %d \n", sei_svc->layers[i].rewriting_max_bitrate[j]); 
                }
            }
        }
    }

    if( sei_svc->priority_layer_info_present_flag )
    {
        printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->pr_num_dIds_minus1 = bs_read_ue(b); printf("sei_svc->pr_num_dIds_minus1: %d \n", sei_svc->pr_num_dIds_minus1); 
        
        for( int i = 0; i <= sei_svc->pr_num_dIds_minus1; i++ ) {
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->pr[i].pr_dependency_id = bs_read_u(b, 3); printf("sei_svc->pr[i].pr_dependency_id: %d \n", sei_svc->pr[i].pr_dependency_id); 
            printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->pr[i].pr_num_minus1 = bs_read_ue(b); printf("sei_svc->pr[i].pr_num_minus1: %d \n", sei_svc->pr[i].pr_num_minus1); 
            for( int j = 0; j <= sei_svc->pr[i].pr_num_minus1; j++ )
            {
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->pr[i].pr_info[j].pr_id = bs_read_ue(b); printf("sei_svc->pr[i].pr_info[j].pr_id: %d \n", sei_svc->pr[i].pr_info[j].pr_id); 
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->pr[i].pr_info[j].pr_profile_level_idc = bs_read_u(b, 24); printf("sei_svc->pr[i].pr_info[j].pr_profile_level_idc: %d \n", sei_svc->pr[i].pr_info[j].pr_profile_level_idc); 
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->pr[i].pr_info[j].pr_avg_bitrate = bs_read_u(b, 16); printf("sei_svc->pr[i].pr_info[j].pr_avg_bitrate: %d \n", sei_svc->pr[i].pr_info[j].pr_avg_bitrate); 
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left); sei_svc->pr[i].pr_info[j].pr_max_bitrate = bs_read_u(b, 16); printf("sei_svc->pr[i].pr_info[j].pr_max_bitrate: %d \n", sei_svc->pr[i].pr_info[j].pr_max_bitrate); 
            }
        }
        
    }

}

// D.1 SEI payload syntax
void read_debug_sei_payload( h264_stream_t* h, bs_t* b )
{
    sei_t* s = h->sei;
    
    int i;
    switch( s->payloadType )
    {
        case SEI_TYPE_SCALABILITY_INFO:
            if( 1 )
            {
                s->sei_svc = (sei_scalability_info_t*)calloc( 1, sizeof(sei_scalability_info_t) );
            }
            read_debug_sei_scalability_info( h, b );
            break;
        default:
            if( 1 )
            {
                s->data = (uint8_t*)calloc(1, s->payloadSize);
            }
            
            for ( i = 0; i < s->payloadSize; i++ )
            {
                printf("%ld.%d: ", (long int)(b->p - b->start), b->bits_left);
                s->data[i] = bs_read_u8(b);
                printf("s->data[i]: %d \n", s->data[i]); 
            }
    }
    
    //if( 1 )
    //    read_sei_end_bits(h, b);
}
