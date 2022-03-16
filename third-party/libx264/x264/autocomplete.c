/*****************************************************************************
 * autocomplete: x264cli shell autocomplete
 *****************************************************************************
 * Copyright (C) 2018-2022 x264 project
 *
 * Authors: Henrik Gramner <henrik@gramner.com>
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

#include "x264cli.h"
#include "input/input.h"

#if HAVE_LAVF
#undef DECLARE_ALIGNED
#include <libavformat/avformat.h>
#include <libavutil/pixdesc.h>
#endif

static const char * const level_names[] =
{
    "1", "1.1", "1.2", "1.3", "1b",
    "2", "2.1", "2.2",
    "3", "3.1", "3.2",
    "4", "4.1", "4.2",
    "5", "5.1", "5.2",
    "6", "6.1", "6.2",
    NULL
};

/* Options requiring a value for which we provide suggestions. */
static const char * const opts_suggest[] =
{
    "--alternative-transfer",
    "--aq-mode",
    "--asm",
    "--avcintra-class",
    "--avcintra-flavor",
    "--b-adapt",
    "--b-pyramid",
    "--colormatrix",
    "--colorprim",
    "--cqm",
    "--demuxer",
    "--direct",
    "--frame-packing",
    "--input-csp",
    "--input-fmt",
    "--input-range",
    "--level",
    "--log-level",
    "--me",
    "--muxer",
    "--nal-hrd",
    "--output-csp",
    "--overscan",
    "--pass", "-p",
    "--preset",
    "--profile",
    "--pulldown",
    "--range",
    "--subme", "-m",
    "--transfer",
    "--trellis", "-t",
    "--tune",
    "--videoformat",
    "--weightp",
    NULL
};

/* Options requiring a value for which we don't provide suggestions. */
static const char * const opts_nosuggest[] =
{
    "--b-bias",
    "--bframes", "-b",
    "--deblock", "-f",
    "--bitrate", "-B",
    "--chroma-qp-offset",
    "--chromaloc",
    "--cplxblur",
    "--cqm4",
    "--cqm4i",
    "--cqm4ic",
    "--cqm4iy",
    "--cqm4p",
    "--cqm4pc",
    "--cqm4py",
    "--cqm8",
    "--cqm8i",
    "--cqm8p",
    "--crf",
    "--crf-max",
    "--crop-rect",
    "--deadzone-inter",
    "--deadzone-intra",
    "--fps",
    "--frames",
    "--input-depth",
    "--input-res",
    "--ipratio",
    "--keyint", "-I",
    "--lookahead-threads",
    "--mastering-display",
    "--cll",
    "--merange",
    "--min-keyint", "-i",
    "--mvrange",
    "--mvrange-thread",
    "--nr",
    "--opencl-device",
    "--output-depth",
    "--partitions", "-A",
    "--pbratio",
    "--psy-rd",
    "--qblur",
    "--qcomp",
    "--qp", "-q",
    "--qpmax",
    "--qpmin",
    "--qpstep",
    "--ratetol",
    "--ref", "-r",
    "--rc-lookahead",
    "--sar",
    "--scenecut",
    "--seek",
    "--slices",
    "--slices-max",
    "--slice-max-size",
    "--slice-max-mbs",
    "--slice-min-mbs",
    "--sps-id",
    "--sync-lookahead",
    "--threads",
    "--timebase",
    "--vbv-bufsize",
    "--vbv-init",
    "--vbv-maxrate",
    "--video-filter", "--vf",
    "--zones",
    NULL
};

/* Options requiring a filename. */
static const char * const opts_filename[] =
{
    "--cqmfile",
    "--dump-yuv",
    "--index",
    "--opencl-clbin",
    "--output", "-o",
    "--qpfile",
    "--stats",
    "--tcfile-in",
    "--tcfile-out",
    NULL
};

/* Options without an associated value. */
static const char * const opts_standalone[] =
{
    "--8x8dct",
    "--aud",
    "--bff",
    "--bluray-compat",
    "--cabac",
    "--constrained-intra",
    "--cpu-independent",
    "--dts-compress",
    "--fake-interlaced",
    "--fast-pskip",
    "--filler",
    "--force-cfr",
    "--mbtree",
    "--mixed-refs",
    "--no-8x8dct",
    "--no-asm",
    "--no-cabac",
    "--no-chroma-me",
    "--no-dct-decimate",
    "--no-deblock",
    "--no-fast-pskip",
    "--no-mbtree",
    "--no-mixed-refs",
    "--no-progress",
    "--no-psy",
    "--no-scenecut",
    "--no-weightb",
    "--non-deterministic",
    "--open-gop",
    "--opencl",
    "--pic-struct",
    "--psnr",
    "--quiet",
    "--sliced-threads",
    "--slow-firstpass",
    "--ssim",
    "--stitchable",
    "--tff",
    "--thread-input",
    "--verbose", "-v",
    "--weightb",
    NULL
};

/* Options which shouldn't be suggested in combination with other options. */
static const char * const opts_special[] =
{
    "--fullhelp",
    "--help", "-h",
    "--longhelp",
    "--version",
    NULL
};

static int list_contains( const char * const *list, const char *s )
{
    if( *s )
        for( ; *list; list++ )
            if( !strcmp( *list, s ) )
                return 1;
    return 0;
}

static void suggest( const char *s, const char *cur, int cur_len )
{
    if( s && *s && !strncmp( s, cur, cur_len ) )
        printf( "%s\n", s );
}

static void suggest_lower( const char *s, const char *cur, int cur_len )
{
    if( s && *s && !strncasecmp( s, cur, cur_len ) )
    {
        for( ; *s; s++ )
            putchar( *s < 'A' || *s > 'Z' ? *s : *s | 0x20 );
        putchar( '\n' );
    }
}

static void suggest_num_range( int start, int end, const char *cur, int cur_len )
{
    char buf[16];
    for( int i = start; i <= end; i++ )
    {
        snprintf( buf, sizeof( buf ), "%d", i );
        suggest( buf, cur, cur_len );
    }
}

#if HAVE_LAVF
/* Suggest each token in a string separated by delimiters. */
static void suggest_token( const char *s, int delim, const char *cur, int cur_len )
{
    if( s && *s )
    {
        for( const char *tok_end; (tok_end = strchr( s, delim )); s = tok_end + 1 )
        {
            int tok_len = tok_end - s;
            if( tok_len && tok_len >= cur_len && !strncmp( s, cur, cur_len ) )
                printf( "%.*s\n", tok_len, s );
        }
        suggest( s, cur, cur_len );
    }
}
#endif

#define OPT( opt ) else if( !strcmp( prev, opt ) )
#define OPT2( opt1, opt2 ) else if( !strcmp( prev, opt1 ) || !strcmp( prev, opt2 ) )
#define OPT_TYPE( type ) list_contains( opts_##type, prev )

#define suggest( s ) suggest( s, cur, cur_len )
#define suggest_lower( s ) suggest_lower( s, cur, cur_len )
#define suggest_list( list ) for( const char * const *s = list; *s; s++ ) suggest( *s )
#define suggest_num_range( start, end ) suggest_num_range( start, end, cur, cur_len )
#define suggest_token( s, delim ) suggest_token( s, delim, cur, cur_len )

int x264_cli_autocomplete( const char *prev, const char *cur )
{
    int cur_len = strlen( cur );
    if( 0 );
    OPT( "--alternative-transfer" )
        suggest_list( x264_transfer_names );
    OPT( "--aq-mode" )
        suggest_num_range( 0, 3 );
    OPT( "--asm" )
        for( const x264_cpu_name_t *cpu = x264_cpu_names; cpu->flags; cpu++ )
            suggest_lower( cpu->name );
    OPT( "--avcintra-class" )
        suggest_list( x264_avcintra_class_names );
    OPT( "--avcintra-flavor" )
        suggest_list( x264_avcintra_flavor_names );
    OPT( "--b-adapt" )
        suggest_num_range( 0, 2 );
    OPT( "--b-pyramid" )
        suggest_list( x264_b_pyramid_names );
    OPT( "--colormatrix" )
        suggest_list( x264_colmatrix_names );
    OPT( "--colorprim" )
        suggest_list( x264_colorprim_names );
    OPT( "--cqm" )
        suggest_list( x264_cqm_names );
    OPT( "--demuxer" )
        suggest_list( x264_demuxer_names );
    OPT( "--direct" )
        suggest_list( x264_direct_pred_names );
    OPT( "--frame-packing" )
        suggest_num_range( 0, 7 );
    OPT( "--input-csp" )
    {
        for( int i = X264_CSP_NONE+1; i < X264_CSP_CLI_MAX; i++ )
            suggest( x264_cli_csps[i].name );
#if HAVE_LAVF
        for( const AVPixFmtDescriptor *d = NULL; (d = av_pix_fmt_desc_next( d )); )
            suggest( d->name );
#endif
    }
    OPT( "--input-fmt" )
    {
#if HAVE_LAVF
        void *i = NULL;
        for( const AVInputFormat *f; (f = av_demuxer_iterate( &i )); )
            suggest_token( f->name, ',' );
#endif
    }
    OPT( "--input-range" )
        suggest_list( x264_range_names );
    OPT( "--level" )
        suggest_list( level_names );
    OPT( "--log-level" )
        suggest_list( x264_log_level_names );
    OPT( "--me" )
        suggest_list( x264_motion_est_names );
    OPT( "--muxer" )
        suggest_list( x264_muxer_names );
    OPT( "--nal-hrd" )
        suggest_list( x264_nal_hrd_names );
    OPT( "--output-csp" )
        suggest_list( x264_output_csp_names );
    OPT( "--output-depth" )
    {
#if HAVE_BITDEPTH8
        suggest( "8" );
#endif
#if HAVE_BITDEPTH10
        suggest( "10" );
#endif
    }
    OPT( "--overscan" )
        suggest_list( x264_overscan_names );
    OPT2( "--partitions", "-A" )
        suggest_list( x264_partition_names );
    OPT2( "--pass", "-p" )
        suggest_num_range( 1, 3 );
    OPT( "--preset" )
        suggest_list( x264_preset_names );
    OPT( "--profile" )
        suggest_list( x264_valid_profile_names );
    OPT( "--pulldown" )
        suggest_list( x264_pulldown_names );
    OPT( "--range" )
        suggest_list( x264_range_names );
    OPT2( "--subme", "-m" )
        suggest_num_range( 0, 11 );
    OPT( "--transfer" )
        suggest_list( x264_transfer_names );
    OPT2( "--trellis", "-t" )
        suggest_num_range( 0, 2 );
    OPT( "--tune" )
        suggest_list( x264_tune_names );
    OPT( "--videoformat" )
        suggest_list( x264_vidformat_names );
    OPT( "--weightp" )
        suggest_num_range( 0, 2 );
    else if( !OPT_TYPE( nosuggest ) && !OPT_TYPE( special ) )
    {
        if( OPT_TYPE( filename ) || strncmp( cur, "--", 2 ) )
            return 1; /* Fall back to default shell filename autocomplete. */

        /* Suggest options. */
        suggest_list( opts_suggest );
        suggest_list( opts_nosuggest );
        suggest_list( opts_filename );
        suggest_list( opts_standalone );

        /* Only suggest special options if no other options have been specified. */
        if( !*prev )
            suggest_list( opts_special );
    }

    return 0;
}
