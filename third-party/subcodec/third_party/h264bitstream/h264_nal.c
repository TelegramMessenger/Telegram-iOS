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
#include <stdlib.h>
#include <stdio.h>

#include "bs.h"
#include "h264_stream.h"
#include "h264_sei.h"

/**
 Create a new H264 stream object.  Allocates all structures contained within it.
 @return    the stream object
 */
h264_stream_t* h264_new()
{
    h264_stream_t* h = (h264_stream_t*)calloc(1, sizeof(h264_stream_t));

    h->nal = (nal_t*)calloc(1, sizeof(nal_t));
    h->nal->nal_svc_ext = (nal_svc_ext_t*) calloc(1, sizeof(nal_svc_ext_t));
    h->nal->prefix_nal_svc = (prefix_nal_svc_t*) calloc(1, sizeof(prefix_nal_svc_t));
    
    // initialize tables
    for ( int i = 0; i < 32; i++ ) { h->sps_table[i] = (sps_t*)calloc(1, sizeof(sps_t)); }
    for ( int i = 0; i < 64; i++ )
    {
        h->sps_subset_table[i] = (sps_subset_t*)calloc(1, sizeof(sps_subset_t));
        h->sps_subset_table[i]->sps = (sps_t*)calloc(1, sizeof(sps_t));
        h->sps_subset_table[i]->sps_svc_ext = (sps_svc_ext_t*) calloc(1, sizeof(sps_svc_ext_t));
    }
    for ( int i = 0; i < 256; i++ ) { h->pps_table[i] = (pps_t*)calloc(1, sizeof(pps_t)); }

    h->sps = (sps_t*)calloc(1, sizeof(sps_t));
    h->sps_subset = (sps_subset_t*)calloc(1, sizeof(sps_subset_t));
    h->sps_subset->sps = (sps_t*)calloc(1, sizeof(sps_t));
    h->sps_subset->sps_svc_ext = (sps_svc_ext_t*)calloc(1, sizeof(sps_svc_ext_t));
    h->pps = (pps_t*)calloc(1, sizeof(pps_t));
    h->aud = (aud_t*)calloc(1, sizeof(aud_t));
    h->num_seis = 0;
    h->seis = NULL;
    h->sei = NULL;  //This is a TEMP pointer at whats in h->seis...
    h->sh = (slice_header_t*)calloc(1, sizeof(slice_header_t));
    h->sh_svc_ext = (slice_header_svc_ext_t*) calloc(1, sizeof(slice_header_svc_ext_t));
    h->slice_data = (slice_data_rbsp_t*)calloc(1, sizeof(slice_data_rbsp_t));

    return h;
}


/**
 Free an existing H264 stream object.  Frees all contained structures.
 @param[in,out] h   the stream object
 */
void h264_free(h264_stream_t* h)
{
    free(h->nal->nal_svc_ext);
    free(h->nal->prefix_nal_svc);
    free(h->nal);

    for ( int i = 0; i < 32; i++ ) { free( h->sps_table[i] ); }
    for ( int i = 0; i < 64; i++ )
    {
        if( h->sps_subset_table[i]->sps != NULL )
            free( h->sps_subset_table[i]->sps );
        if( h->sps_subset_table[i]->sps_svc_ext != NULL )
            free( h->sps_subset_table[i]->sps_svc_ext );
        free( h->sps_subset_table[i] );
    }
    for ( int i = 0; i < 256; i++ ) { free( h->pps_table[i] ); }

    free(h->pps);
    free(h->aud);
    if(h->seis != NULL)
    {
        for( int i = 0; i < h->num_seis; i++ )
        {
            sei_t* sei = h->seis[i];
            sei_free(sei);
        }
        free(h->seis);
    }
    free(h->sh);
    
    if (h->sh_svc_ext != NULL) free(h->sh_svc_ext);

    if (h->slice_data != NULL)
    {
        if (h->slice_data->rbsp_buf != NULL)
        {
            free(h->slice_data->rbsp_buf);
        }

        free(h->slice_data);
    }

    free(h->sps);

    free(h->sps_subset->sps);
    free(h->sps_subset->sps_svc_ext);
    free(h->sps_subset);

    free(h);
}

/**
 Find the beginning and end of a NAL (Network Abstraction Layer) unit in a byte buffer containing H264 bitstream data.
 @param[in]   buf        the buffer
 @param[in]   size       the size of the buffer
 @param[out]  nal_start  the beginning offset of the nal
 @param[out]  nal_end    the end offset of the nal
 @return                 the length of the nal, or 0 if did not find start of nal, or -1 if did not find end of nal
 */
// DEPRECATED - this will be replaced by a similar function with a slightly different API
int find_nal_unit(uint8_t* buf, int size, int* nal_start, int* nal_end)
{
    int i;
    // find start
    *nal_start = 0;
    *nal_end = 0;
    
    i = 0;
    while (   //( next_bits( 24 ) != 0x000001 && next_bits( 32 ) != 0x00000001 )
        (buf[i] != 0 || buf[i+1] != 0 || buf[i+2] != 0x01) && 
        (buf[i] != 0 || buf[i+1] != 0 || buf[i+2] != 0 || buf[i+3] != 0x01) 
        )
    {
        i++; // skip leading zero
        if (i+4 >= size) { return 0; } // did not find nal start
    }

    if  (buf[i] != 0 || buf[i+1] != 0 || buf[i+2] != 0x01) // ( next_bits( 24 ) != 0x000001 )
    {
        i++;
    }

    if  (buf[i] != 0 || buf[i+1] != 0 || buf[i+2] != 0x01) { /* error, should never happen */ return 0; }
    i+= 3;
    *nal_start = i;
    
    while (   //( next_bits( 24 ) != 0x000000 && next_bits( 24 ) != 0x000001 )
        (buf[i] != 0 || buf[i+1] != 0 || buf[i+2] != 0) && 
        (buf[i] != 0 || buf[i+1] != 0 || buf[i+2] != 0x01) 
        )
    {
        i++;
        // FIXME the next line fails when reading a nal that ends exactly at the end of the data
        if (i+3 >= size) { *nal_end = size; return -1; } // did not find nal end, stream ended first
    }
    
    *nal_end = i;
    return (*nal_end - *nal_start);
}


/**
   Convert RBSP data to NAL data (Annex B format).
   The size of nal_buf must be 3/2 * the size of the rbsp_buf (rounded up) to guarantee the output will fit.
   If that is not true, output may be truncated and an error will be returned.
   If that is true, there is no possible error during this conversion.
   @param[in] rbsp_buf   the rbsp data
   @param[in] rbsp_size  pointer to the size of the rbsp data
   @param[in,out] nal_buf   allocated memory in which to put the nal data
   @param[in,out] nal_size  as input, pointer to the maximum size of the nal data; as output, filled in with the actual size of the nal data
   @return  actual size of nal data, or -1 on error
 */
// 7.3.1 NAL unit syntax
// 7.4.1.1 Encapsulation of an SODB within an RBSP
int rbsp_to_nal(const uint8_t* rbsp_buf, const int* rbsp_size, uint8_t* nal_buf, int* nal_size)
{
    int i;
    int j     = 1;
    int count = 0;

    if (*nal_size > 0) { nal_buf[0] = 0x00; } // zero out first byte since we start writing from second byte

    for ( i = 0; i < *rbsp_size ; )
    {
        if ( j >= *nal_size ) 
        {
            // error, not enough space
            return -1;
        }

        if ( ( count == 2 ) && !(rbsp_buf[i] & 0xFC) ) // HACK 0xFC
        {
            nal_buf[j] = 0x03;
            j++;
            count = 0;
            continue;
        }
        nal_buf[j] = rbsp_buf[i];
        if ( rbsp_buf[i] == 0x00 )
        {
            count++;
        }
        else
        {
            count = 0;
        }
        i++;
        j++;
    }

    *nal_size = j;
    return j;
}

/**
   Convert NAL data (Annex B format) to RBSP data.
   The size of rbsp_buf must be the same as size of the nal_buf to guarantee the output will fit.
   If that is not true, output may be truncated and an error will be returned. 
   Additionally, certain byte sequences in the input nal_buf are not allowed in the spec and also cause the conversion to fail and an error to be returned.
   @param[in] nal_buf   the nal data
   @param[in,out] nal_size  as input, pointer to the size of the nal data; as output, filled in with the actual size of the nal data
   @param[in,out] rbsp_buf   allocated memory in which to put the rbsp data
   @param[in,out] rbsp_size  as input, pointer to the maximum size of the rbsp data; as output, filled in with the actual size of rbsp data
   @return  actual size of rbsp data, or -1 on error
 */
// 7.3.1 NAL unit syntax
// 7.4.1.1 Encapsulation of an SODB within an RBSP
int nal_to_rbsp(const uint8_t* nal_buf, int* nal_size, uint8_t* rbsp_buf, int* rbsp_size)
{
    int i;
    int j     = 0;
    int count = 0;
  
    for( i = 0; i < *nal_size; i++ )
    { 
        // in NAL unit, 0x000000, 0x000001 or 0x000002 shall not occur at any byte-aligned position
        if( ( count == 2 ) && ( nal_buf[i] < 0x03) ) 
        {
            return -1;
        }

        if( ( count == 2 ) && ( nal_buf[i] == 0x03) )
        {
            // check the 4th byte after 0x000003, except when cabac_zero_word is used, in which case the last three bytes of this NAL unit must be 0x000003
            if((i < *nal_size - 1) && (nal_buf[i+1] > 0x03))
            {
                return -1;
            }

            // if cabac_zero_word is used, the final byte of this NAL unit(0x03) is discarded, and the last two bytes of RBSP must be 0x0000
            if(i == *nal_size - 1)
            {
                break;
            }

            i++;
            count = 0;
        }

        if ( j >= *rbsp_size ) 
        {
            // error, not enough space
            return -1;
        }

        rbsp_buf[j] = nal_buf[i];
        if(nal_buf[i] == 0x00)
        {
            count++;
        }
        else
        {
            count = 0;
        }
        j++;
    }

    *nal_size = i;
    *rbsp_size = j;
    return j;
}


/**
 Read only the NAL headers (enough to determine unit type) from a byte buffer.
 @return unit type if read successfully, or -1 if this doesn't look like a nal
*/
int peek_nal_unit(h264_stream_t* h, uint8_t* buf, int size)
{
    nal_t* nal = h->nal;

    bs_t* b = bs_new(buf, size);

    nal->forbidden_zero_bit = bs_read_f(b,1);
    nal->nal_ref_idc = bs_read_u(b,2);
    nal->nal_unit_type = bs_read_u(b,5);

    bs_free(b);

    // basic verification, per 7.4.1
    if ( nal->forbidden_zero_bit ) { return -1; }
    if ( nal->nal_unit_type <= 0 || nal->nal_unit_type > 20 ) { return -1; }
    if ( nal->nal_unit_type > 15 && nal->nal_unit_type < 19 ) { return -1; }

    if ( nal->nal_ref_idc == 0 )
    {
        if ( nal->nal_unit_type == NAL_UNIT_TYPE_CODED_SLICE_IDR )
        {
            return -1;
        }
    }
    else 
    {
        if ( nal->nal_unit_type ==  NAL_UNIT_TYPE_SEI || 
             nal->nal_unit_type == NAL_UNIT_TYPE_AUD || 
             nal->nal_unit_type == NAL_UNIT_TYPE_END_OF_SEQUENCE || 
             nal->nal_unit_type == NAL_UNIT_TYPE_END_OF_STREAM || 
             nal->nal_unit_type == NAL_UNIT_TYPE_FILLER ) 
        {
            return -1;
        }
    }

    return nal->nal_unit_type;
}


