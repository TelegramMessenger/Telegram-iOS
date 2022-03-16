/*****************************************************************************
 * matroska_ebml.c: matroska muxer utilities
 *****************************************************************************
 * Copyright (C) 2005-2022 x264 project
 *
 * Authors: Mike Matsnev <mike@haali.su>
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

#include "output.h"
#include "matroska_ebml.h"

#define CLSIZE 1048576
#define CHECK(x)\
do {\
    if( (x) < 0 )\
        return -1;\
} while( 0 )

struct mk_context
{
    struct mk_context *next, **prev, *parent;
    mk_writer *owner;
    unsigned id;

    void *data;
    unsigned d_cur, d_max;
};

typedef struct mk_context mk_context;

struct mk_writer
{
    FILE *fp;

    unsigned duration_ptr;

    mk_context *root, *cluster, *frame;
    mk_context *freelist;
    mk_context *actlist;

    int64_t def_duration;
    int64_t timescale;
    int64_t cluster_tc_scaled;
    int64_t frame_tc, max_frame_tc;

    int8_t wrote_header, in_frame, keyframe, skippable;
};

static mk_context *mk_create_context( mk_writer *w, mk_context *parent, unsigned id )
{
    mk_context *c;

    if( w->freelist )
    {
        c = w->freelist;
        w->freelist = w->freelist->next;
    }
    else
    {
        c = calloc( 1, sizeof(mk_context) );
        if( !c )
            return NULL;
    }

    c->parent = parent;
    c->owner = w;
    c->id = id;

    if( c->owner->actlist )
        c->owner->actlist->prev = &c->next;
    c->next = c->owner->actlist;
    c->prev = &c->owner->actlist;
    c->owner->actlist = c;

    return c;
}

static int mk_append_context_data( mk_context *c, const void *data, unsigned size )
{
    unsigned ns = c->d_cur + size;

    if( ns > c->d_max )
    {
        void *dp;
        unsigned dn = c->d_max ? c->d_max << 1 : 16;
        while( ns > dn )
            dn <<= 1;

        dp = realloc( c->data, dn );
        if( !dp )
            return -1;

        c->data = dp;
        c->d_max = dn;
    }

    memcpy( (uint8_t*)c->data + c->d_cur, data, size );

    c->d_cur = ns;

    return 0;
}

static int mk_write_id( mk_context *c, unsigned id )
{
    uint8_t c_id[4] = { id >> 24, id >> 16, id >> 8, id };

    if( c_id[0] )
        return mk_append_context_data( c, c_id, 4 );
    if( c_id[1] )
        return mk_append_context_data( c, c_id+1, 3 );
    if( c_id[2] )
        return mk_append_context_data( c, c_id+2, 2 );
    return mk_append_context_data( c, c_id+3, 1 );
}

static int mk_write_size( mk_context *c, unsigned size )
{
    uint8_t c_size[5] = { 0x08, size >> 24, size >> 16, size >> 8, size };

    if( size < 0x7f )
    {
        c_size[4] |= 0x80;
        return mk_append_context_data( c, c_size+4, 1 );
    }
    if( size < 0x3fff )
    {
        c_size[3] |= 0x40;
        return mk_append_context_data( c, c_size+3, 2 );
    }
    if( size < 0x1fffff )
    {
        c_size[2] |= 0x20;
        return mk_append_context_data( c, c_size+2, 3 );
    }
    if( size < 0x0fffffff )
    {
        c_size[1] |= 0x10;
        return mk_append_context_data( c, c_size+1, 4 );
    }
    return mk_append_context_data( c, c_size, 5 );
}

static int mk_flush_context_id( mk_context *c )
{
    uint8_t ff = 0xff;

    if( !c->id )
        return 0;

    CHECK( mk_write_id( c->parent, c->id ) );
    CHECK( mk_append_context_data( c->parent, &ff, 1 ) );

    c->id = 0;

    return 0;
}

static int mk_flush_context_data( mk_context *c )
{
    if( !c->d_cur )
        return 0;

    if( c->parent )
        CHECK( mk_append_context_data( c->parent, c->data, c->d_cur ) );
    else if( fwrite( c->data, c->d_cur, 1, c->owner->fp ) != 1 )
        return -1;

    c->d_cur = 0;

    return 0;
}

static int mk_close_context( mk_context *c, unsigned *off )
{
    if( c->id )
    {
        CHECK( mk_write_id( c->parent, c->id ) );
        CHECK( mk_write_size( c->parent, c->d_cur ) );
    }

    if( c->parent && off )
        *off += c->parent->d_cur;

    CHECK( mk_flush_context_data( c ) );

    if( c->next )
        c->next->prev = c->prev;
    *(c->prev) = c->next;
    c->next = c->owner->freelist;
    c->owner->freelist = c;

    return 0;
}

static void mk_destroy_contexts( mk_writer *w )
{
    mk_context *next;

    for( mk_context *cur = w->freelist; cur; cur = next )
    {
        next = cur->next;
        free( cur->data );
        free( cur );
    }

    for( mk_context *cur = w->actlist; cur; cur = next )
    {
        next = cur->next;
        free( cur->data );
        free( cur );
    }

    w->freelist = w->actlist = w->root = NULL;
}

static int mk_write_string( mk_context *c, unsigned id, const char *str )
{
    size_t len = strlen( str );

    CHECK( mk_write_id( c, id ) );
    CHECK( mk_write_size( c, len ) );
    CHECK( mk_append_context_data( c, str, len ) );
    return 0;
}

static int mk_write_bin( mk_context *c, unsigned id, const void *data, unsigned size )
{
    CHECK( mk_write_id( c, id ) );
    CHECK( mk_write_size( c, size ) );
    CHECK( mk_append_context_data( c, data, size ) );
    return 0;
}

static int mk_write_uint( mk_context *c, unsigned id, uint64_t ui )
{
    uint8_t c_ui[8] = { ui >> 56, ui >> 48, ui >> 40, ui >> 32, ui >> 24, ui >> 16, ui >> 8, ui };
    unsigned i = 0;

    CHECK( mk_write_id( c, id ) );
    while( i < 7 && !c_ui[i] )
        ++i;
    CHECK( mk_write_size( c, 8 - i ) );
    CHECK( mk_append_context_data( c, c_ui+i, 8 - i ) );
    return 0;
}

static int mk_write_float_raw( mk_context *c, float f )
{
    union
    {
        float f;
        uint32_t u;
    } u;
    uint8_t c_f[4];

    u.f = f;
    c_f[0] = u.u >> 24;
    c_f[1] = u.u >> 16;
    c_f[2] = u.u >> 8;
    c_f[3] = u.u;

    return mk_append_context_data( c, c_f, 4 );
}

static int mk_write_float( mk_context *c, unsigned id, float f )
{
    CHECK( mk_write_id( c, id ) );
    CHECK( mk_write_size( c, 4 ) );
    CHECK( mk_write_float_raw( c, f ) );
    return 0;
}

mk_writer *mk_create_writer( const char *filename )
{
    mk_writer *w = calloc( 1, sizeof(mk_writer) );
    if( !w )
        return NULL;

    w->root = mk_create_context( w, NULL, 0 );
    if( !w->root )
    {
        free( w );
        return NULL;
    }

    if( !strcmp( filename, "-" ) )
        w->fp = stdout;
    else
        w->fp = x264_fopen( filename, "wb" );
    if( !w->fp )
    {
        mk_destroy_contexts( w );
        free( w );
        return NULL;
    }

    w->timescale = 1000000;

    return w;
}

int mk_write_header( mk_writer *w, const char *writing_app,
                     const char *codec_id,
                     const void *codec_private, unsigned codec_private_size,
                     int64_t default_frame_duration,
                     int64_t timescale,
                     unsigned width, unsigned height,
                     unsigned d_width, unsigned d_height, int display_size_units, int stereo_mode )
{
    mk_context  *c, *ti, *v;

    if( w->wrote_header )
        return -1;

    w->timescale = timescale;
    w->def_duration = default_frame_duration;

    if( !(c = mk_create_context( w, w->root, 0x1a45dfa3 )) ) // EBML
        return -1;
    CHECK( mk_write_uint( c, 0x4286, 1 ) ); // EBMLVersion
    CHECK( mk_write_uint( c, 0x42f7, 1 ) ); // EBMLReadVersion
    CHECK( mk_write_uint( c, 0x42f2, 4 ) ); // EBMLMaxIDLength
    CHECK( mk_write_uint( c, 0x42f3, 8 ) ); // EBMLMaxSizeLength
    CHECK( mk_write_string( c, 0x4282, "matroska") ); // DocType
    CHECK( mk_write_uint( c, 0x4287, stereo_mode >= 0 ? 3 : 2 ) ); // DocTypeVersion
    CHECK( mk_write_uint( c, 0x4285, 2 ) ); // DocTypeReadVersion
    CHECK( mk_close_context( c, 0 ) );

    if( !(c = mk_create_context( w, w->root, 0x18538067 )) ) // Segment
        return -1;
    CHECK( mk_flush_context_id( c ) );
    CHECK( mk_close_context( c, 0 ) );

    if( !(c = mk_create_context( w, w->root, 0x1549a966 )) ) // SegmentInfo
        return -1;
    CHECK( mk_write_string( c, 0x4d80, "Haali Matroska Writer b0" ) ); // MuxingApp
    CHECK( mk_write_string( c, 0x5741, writing_app ) ); // WritingApp
    CHECK( mk_write_uint( c, 0x2ad7b1, w->timescale ) ); // TimecodeScale
    CHECK( mk_write_float( c, 0x4489, 0) ); // Duration
    w->duration_ptr = c->d_cur - 4;
    CHECK( mk_close_context( c, &w->duration_ptr ) );

    if( !(c = mk_create_context( w, w->root, 0x1654ae6b )) ) // Tracks
        return -1;
    if( !(ti = mk_create_context( w, c, 0xae )) ) // TrackEntry
        return -1;
    CHECK( mk_write_uint( ti, 0xd7, 1 ) ); // TrackNumber
    CHECK( mk_write_uint( ti, 0x73c5, 1 ) ); // TrackUID
    CHECK( mk_write_uint( ti, 0x83, 1 ) ); // TrackType
    CHECK( mk_write_uint( ti, 0x9c, 0 ) ); // FlagLacing
    CHECK( mk_write_string( ti, 0x86, codec_id ) ); // CodecID
    if( codec_private_size )
        CHECK( mk_write_bin( ti, 0x63a2, codec_private, codec_private_size ) ); // CodecPrivate
    if( default_frame_duration )
        CHECK( mk_write_uint( ti, 0x23e383, default_frame_duration ) ); // DefaultDuration

    if( !(v = mk_create_context( w, ti, 0xe0 ) ) ) // Video
        return -1;
    CHECK( mk_write_uint( v, 0xb0, width ) ); // PixelWidth
    CHECK( mk_write_uint( v, 0xba, height ) ); // PixelHeight
    CHECK( mk_write_uint( v, 0x54b2, display_size_units ) ); // DisplayUnit
    CHECK( mk_write_uint( v, 0x54b0, d_width ) ); // DisplayWidth
    CHECK( mk_write_uint( v, 0x54ba, d_height ) ); // DisplayHeight
    if( stereo_mode >= 0 )
        CHECK( mk_write_uint( v, 0x53b8, stereo_mode ) ); // StereoMode
    CHECK( mk_close_context( v, 0 ) );

    CHECK( mk_close_context( ti, 0 ) );

    CHECK( mk_close_context( c, 0 ) );

    CHECK( mk_flush_context_data( w->root ) );

    w->wrote_header = 1;

    return 0;
}

static int mk_close_cluster( mk_writer *w )
{
    if( w->cluster == NULL )
        return 0;
    CHECK( mk_close_context( w->cluster, 0 ) );
    w->cluster = NULL;
    CHECK( mk_flush_context_data( w->root ) );
    return 0;
}

static int mk_flush_frame( mk_writer *w )
{
    int64_t delta;
    unsigned fsize;
    uint8_t c_delta_flags[3];

    if( !w->in_frame )
        return 0;

    delta = w->frame_tc/w->timescale - w->cluster_tc_scaled;
    if( delta > 32767ll || delta < -32768ll )
        CHECK( mk_close_cluster( w ) );

    if( !w->cluster )
    {
        w->cluster_tc_scaled = w->frame_tc / w->timescale;
        w->cluster = mk_create_context( w, w->root, 0x1f43b675 ); // Cluster
        if( !w->cluster )
            return -1;

        CHECK( mk_write_uint( w->cluster, 0xe7, w->cluster_tc_scaled ) ); // Timecode

        delta = 0;
    }

    fsize = w->frame ? w->frame->d_cur : 0;

    CHECK( mk_write_id( w->cluster, 0xa3 ) ); // SimpleBlock
    CHECK( mk_write_size( w->cluster, fsize + 4 ) ); // Size
    CHECK( mk_write_size( w->cluster, 1 ) ); // TrackNumber

    c_delta_flags[0] = (uint8_t)(delta >> 8);
    c_delta_flags[1] = (uint8_t)delta;
    c_delta_flags[2] = (w->keyframe << 7) | w->skippable;
    CHECK( mk_append_context_data( w->cluster, c_delta_flags, 3 ) ); // Timecode, Flags
    if( w->frame )
    {
        CHECK( mk_append_context_data( w->cluster, w->frame->data, w->frame->d_cur ) ); // Data
        w->frame->d_cur = 0;
    }

    w->in_frame = 0;

    if( w->cluster->d_cur > CLSIZE )
        CHECK( mk_close_cluster( w ) );

    return 0;
}

int mk_start_frame( mk_writer *w )
{
    if( mk_flush_frame( w ) < 0 )
        return -1;

    w->in_frame  = 1;
    w->keyframe  = 0;
    w->skippable = 0;

    return 0;
}

int mk_set_frame_flags( mk_writer *w, int64_t timestamp, int keyframe, int skippable )
{
    if( !w->in_frame )
        return -1;

    w->frame_tc  = timestamp;
    w->keyframe  = keyframe  != 0;
    w->skippable = skippable != 0;

    if( w->max_frame_tc < timestamp )
        w->max_frame_tc = timestamp;

    return 0;
}

int mk_add_frame_data( mk_writer *w, const void *data, unsigned size )
{
    if( !w->in_frame )
        return -1;

    if( !w->frame )
        if( !(w->frame = mk_create_context( w, NULL, 0 )) )
        return -1;

    return mk_append_context_data( w->frame, data, size );
}

int mk_close( mk_writer *w, int64_t last_delta )
{
    int ret = 0;
    if( mk_flush_frame( w ) < 0 || mk_close_cluster( w ) < 0 )
        ret = -1;
    if( w->wrote_header && x264_is_regular_file( w->fp ) )
    {
        int64_t last_frametime = w->def_duration ? w->def_duration : last_delta;
        int64_t total_duration = w->max_frame_tc + last_frametime;
        if( fseek( w->fp, w->duration_ptr, SEEK_SET ) ||
            mk_write_float_raw( w->root, (float)((double)total_duration / w->timescale) ) < 0 ||
            mk_flush_context_data( w->root ) < 0 )
            ret = -1;
    }
    mk_destroy_contexts( w );
    fclose( w->fp );
    free( w );
    return ret;
}
