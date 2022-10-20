/*****************************************************************************
 * flv_bytestream.h: flv muxer utilities
 *****************************************************************************
 * Copyright (C) 2009-2022 x264 project
 *
 * Authors: Kieran Kunhya <kieran@kunhya.com>
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

#ifndef X264_FLV_BYTESTREAM_H
#define X264_FLV_BYTESTREAM_H

/* offsets for packed values */
#define FLV_AUDIO_SAMPLESSIZE_OFFSET 1
#define FLV_AUDIO_SAMPLERATE_OFFSET  2
#define FLV_AUDIO_CODECID_OFFSET     4

#define FLV_VIDEO_FRAMETYPE_OFFSET   4

/* bitmasks to isolate specific values */
#define FLV_AUDIO_CHANNEL_MASK    0x01
#define FLV_AUDIO_SAMPLESIZE_MASK 0x02
#define FLV_AUDIO_SAMPLERATE_MASK 0x0c
#define FLV_AUDIO_CODECID_MASK    0xf0

#define FLV_VIDEO_CODECID_MASK    0x0f
#define FLV_VIDEO_FRAMETYPE_MASK  0xf0

#define AMF_END_OF_OBJECT         0x09

enum
{
    FLV_HEADER_FLAG_HASVIDEO = 1,
    FLV_HEADER_FLAG_HASAUDIO = 4,
};

enum
{
    FLV_TAG_TYPE_AUDIO = 0x08,
    FLV_TAG_TYPE_VIDEO = 0x09,
    FLV_TAG_TYPE_META  = 0x12,
};

enum
{
    FLV_MONO   = 0,
    FLV_STEREO = 1,
};

enum
{
    FLV_SAMPLESSIZE_8BIT  = 0,
    FLV_SAMPLESSIZE_16BIT = 1 << FLV_AUDIO_SAMPLESSIZE_OFFSET,
};

enum
{
    FLV_SAMPLERATE_SPECIAL = 0, /**< signifies 5512Hz and 8000Hz in the case of NELLYMOSER */
    FLV_SAMPLERATE_11025HZ = 1 << FLV_AUDIO_SAMPLERATE_OFFSET,
    FLV_SAMPLERATE_22050HZ = 2 << FLV_AUDIO_SAMPLERATE_OFFSET,
    FLV_SAMPLERATE_44100HZ = 3 << FLV_AUDIO_SAMPLERATE_OFFSET,
};

enum
{
    FLV_CODECID_MP3 = 2 << FLV_AUDIO_CODECID_OFFSET,
    FLV_CODECID_AAC = 10<< FLV_AUDIO_CODECID_OFFSET,
};

enum
{
    FLV_CODECID_H264 = 7,
};

enum
{
    FLV_FRAME_KEY   = 1 << FLV_VIDEO_FRAMETYPE_OFFSET,
    FLV_FRAME_INTER = 2 << FLV_VIDEO_FRAMETYPE_OFFSET,
};

typedef enum
{
    AMF_DATA_TYPE_NUMBER      = 0x00,
    AMF_DATA_TYPE_BOOL        = 0x01,
    AMF_DATA_TYPE_STRING      = 0x02,
    AMF_DATA_TYPE_OBJECT      = 0x03,
    AMF_DATA_TYPE_NULL        = 0x05,
    AMF_DATA_TYPE_UNDEFINED   = 0x06,
    AMF_DATA_TYPE_REFERENCE   = 0x07,
    AMF_DATA_TYPE_MIXEDARRAY  = 0x08,
    AMF_DATA_TYPE_OBJECT_END  = 0x09,
    AMF_DATA_TYPE_ARRAY       = 0x0a,
    AMF_DATA_TYPE_DATE        = 0x0b,
    AMF_DATA_TYPE_LONG_STRING = 0x0c,
    AMF_DATA_TYPE_UNSUPPORTED = 0x0d,
} AMFDataType;

typedef struct flv_buffer
{
    uint8_t *data;
    unsigned d_cur;
    unsigned d_max;
    FILE *fp;
    uint64_t d_total;
} flv_buffer;

flv_buffer *flv_create_writer( const char *filename );
int flv_append_data( flv_buffer *c, uint8_t *data, unsigned size );
int flv_write_byte( flv_buffer *c, uint8_t *byte );
int flv_flush_data( flv_buffer *c );
void flv_rewrite_amf_be24( flv_buffer *c, unsigned length, unsigned start );

uint64_t flv_dbl2int( double value );
void flv_put_byte( flv_buffer *c, uint8_t b );
void flv_put_be32( flv_buffer *c, uint32_t val );
void flv_put_be64( flv_buffer *c, uint64_t val );
void flv_put_be16( flv_buffer *c, uint16_t val );
void flv_put_be24( flv_buffer *c, uint32_t val );
void flv_put_tag( flv_buffer *c, const char *tag );
void flv_put_amf_string( flv_buffer *c, const char *str );
void flv_put_amf_double( flv_buffer *c, double d );

#endif
