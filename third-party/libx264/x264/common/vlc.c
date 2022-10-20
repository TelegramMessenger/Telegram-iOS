/*****************************************************************************
 * vlc.c : vlc tables
 *****************************************************************************
 * Copyright (C) 2003-2022 x264 project
 *
 * Authors: Laurent Aimar <fenrir@via.ecp.fr>
 *          Fiona Glaser <fiona@x264.com>
 *          Henrik Gramner <henrik@gramner.com>
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

vlc_large_t x264_level_token[7][LEVEL_TABLE_SIZE];
uint32_t x264_run_before[1<<16];

void x264_cavlc_init( x264_t *h )
{
    for( int i_suffix = 0; i_suffix < 7; i_suffix++ )
        for( int16_t level = -LEVEL_TABLE_SIZE/2; level < LEVEL_TABLE_SIZE/2; level++ )
        {
            int mask = level >> 15;
            int abs_level = (level^mask)-mask;
            int i_level_code = abs_level ? abs_level*2-mask-2 : 0;
            int i_next = i_suffix;
            vlc_large_t *vlc = &x264_level_token[i_suffix][level+LEVEL_TABLE_SIZE/2];

            if( ( i_level_code >> i_suffix ) < 14 )
            {
                vlc->i_size = (i_level_code >> i_suffix) + 1 + i_suffix;
                vlc->i_bits = (1<<i_suffix) + (i_level_code & ((1<<i_suffix)-1));
            }
            else if( i_suffix == 0 && i_level_code < 30 )
            {
                vlc->i_size = 19;
                vlc->i_bits = (1<<4) + (i_level_code - 14);
            }
            else if( i_suffix > 0 && ( i_level_code >> i_suffix ) == 14 )
            {
                vlc->i_size = 15 + i_suffix;
                vlc->i_bits = (1<<i_suffix) + (i_level_code & ((1<<i_suffix)-1));
            }
            else
            {
                i_level_code -= 15 << i_suffix;
                if( i_suffix == 0 )
                    i_level_code -= 15;
                vlc->i_size = 28;
                vlc->i_bits = (1<<12) + i_level_code;
            }
            if( i_next == 0 )
                i_next++;
            if( abs_level > (3 << (i_next-1)) && i_next < 6 )
                i_next++;
            vlc->i_next = i_next;
        }

    x264_run_before[0] = 0;
    x264_run_before[1] = 0;
    for( uint32_t i = 2; i < (1<<16); i++ )
    {
        x264_run_level_t runlevel;
        ALIGNED_ARRAY_16( dctcoef, dct, [16] );
        int size = 0;
        int bits = 0;
        for( int j = 0; j < 16; j++ )
            dct[j] = i&(1<<j);
        int total = h->quantf.coeff_level_run[DCT_LUMA_4x4]( dct, &runlevel );
        int zeros = runlevel.last + 1 - total;
        uint32_t mask = i << (x264_clz( i ) + 1);
        for( int j = 0; j < total-1 && zeros > 0; j++ )
        {
            int idx = X264_MIN(zeros, 7) - 1;
            int run = x264_clz( mask );
            int len = x264_run_before_init[idx][run].i_size;
            size += len;
            bits <<= len;
            bits |= x264_run_before_init[idx][run].i_bits;
            zeros -= run;
            mask <<= run + 1;
        }
        x264_run_before[i] = (bits << 5) + size;
    }
}
