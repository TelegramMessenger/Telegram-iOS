/*****************************************************************************
 * x264: top-level x264cli functions
 *****************************************************************************
 * Copyright (C) 2003-2022 x264 project
 *
 * Authors: Loren Merritt <lorenm@u.washington.edu>
 *          Laurent Aimar <fenrir@via.ecp.fr>
 *          Steven Walters <kemuri9@gmail.com>
 *          Fiona Glaser <fiona@x264.com>
 *          Kieran Kunhya <kieran@kunhya.com>
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

#ifdef _WIN32
/* The following two defines must be located before the inclusion of any system header files. */
#define WINVER       0x0500
#define _WIN32_WINNT 0x0500
#include <windows.h>
#include <io.h>       /* _setmode() */
#include <fcntl.h>    /* _O_BINARY */
#endif

#include <signal.h>
#include <getopt.h>
#include "x264cli.h"
#include "input/input.h"
#include "output/output.h"
#include "filters/filters.h"

#define QP_MAX_SPEC (51+6*2)
#define QP_MAX (QP_MAX_SPEC+18)

#define FAIL_IF_ERROR( cond, ... ) FAIL_IF_ERR( cond, "x264", __VA_ARGS__ )

#if HAVE_LAVF
#undef DECLARE_ALIGNED
#include <libavformat/avformat.h>
#include <libavutil/pixfmt.h>
#include <libavutil/pixdesc.h>
#endif

#if HAVE_SWSCALE
#undef DECLARE_ALIGNED
#include <libswscale/swscale.h>
#endif

#if HAVE_FFMS
#include <ffms.h>
#endif

#if HAVE_GPAC
#include <gpac/isomedia.h>
#endif

#if HAVE_LSMASH
#include <lsmash.h>
#endif

#ifdef _WIN32
#define CONSOLE_TITLE_SIZE 200
static wchar_t org_console_title[CONSOLE_TITLE_SIZE] = L"";

void x264_cli_set_console_title( const char *title )
{
    wchar_t title_utf16[CONSOLE_TITLE_SIZE];
    if( MultiByteToWideChar( CP_UTF8, MB_ERR_INVALID_CHARS, title, -1, title_utf16, CONSOLE_TITLE_SIZE ) )
        SetConsoleTitleW( title_utf16 );
}

/* Retrieve command line arguments as UTF-8. */
static int get_argv_utf8( int *argc_ptr, char ***argv_ptr )
{
    int ret = 0;
    wchar_t **argv_utf16 = CommandLineToArgvW( GetCommandLineW(), argc_ptr );
    if( argv_utf16 )
    {
        int argc = *argc_ptr;
        int offset = (argc+1) * sizeof(char*);
        int size = offset;

        for( int i = 0; i < argc; i++ )
            size += WideCharToMultiByte( CP_UTF8, 0, argv_utf16[i], -1, NULL, 0, NULL, NULL );

        char **argv = *argv_ptr = malloc( size );
        if( argv )
        {
            for( int i = 0; i < argc; i++ )
            {
                argv[i] = (char*)argv + offset;
                offset += WideCharToMultiByte( CP_UTF8, 0, argv_utf16[i], -1, argv[i], size-offset, NULL, NULL );
            }
            argv[argc] = NULL;
            ret = 1;
        }
        LocalFree( argv_utf16 );
    }
    return ret;
}
#endif

/* Ctrl-C handler */
static volatile int b_ctrl_c = 0;
static void sigint_handler( int a )
{
    b_ctrl_c = 1;
}

typedef struct {
    int b_progress;
    int i_seek;
    hnd_t hin;
    hnd_t hout;
    FILE *qpfile;
    FILE *tcfile_out;
    double timebase_convert_multiplier;
    int i_pulldown;
} cli_opt_t;

/* file i/o operation structs */
cli_input_t cli_input;
static cli_output_t cli_output;

/* video filter operation struct */
static cli_vid_filter_t filter;

const char * const x264_avcintra_class_names[] = { "50", "100", "200", "300", "480", 0 };
const char * const x264_cqm_names[] = { "flat", "jvt", 0 };
const char * const x264_log_level_names[] = { "none", "error", "warning", "info", "debug", 0 };
const char * const x264_partition_names[] = { "p8x8", "p4x4", "b8x8", "i8x8", "i4x4", "none", "all", 0 };
const char * const x264_pulldown_names[] = { "none", "22", "32", "64", "double", "triple", "euro", 0 };
const char * const x264_range_names[] = { "auto", "tv", "pc", 0 };

const char * const x264_output_csp_names[] =
{
#if !X264_CHROMA_FORMAT || X264_CHROMA_FORMAT == X264_CSP_I400
    "i400",
#endif
#if !X264_CHROMA_FORMAT || X264_CHROMA_FORMAT == X264_CSP_I420
    "i420",
#endif
#if !X264_CHROMA_FORMAT || X264_CHROMA_FORMAT == X264_CSP_I422
    "i422",
#endif
#if !X264_CHROMA_FORMAT || X264_CHROMA_FORMAT == X264_CSP_I444
    "i444", "rgb",
#endif
    0
};

const char * const x264_valid_profile_names[] =
{
#if !X264_CHROMA_FORMAT || X264_CHROMA_FORMAT <= X264_CSP_I420
#if HAVE_BITDEPTH8
#if !X264_CHROMA_FORMAT || X264_CHROMA_FORMAT == X264_CSP_I420
    "baseline", "main",
#endif
    "high",
#endif
#if HAVE_BITDEPTH10
   "high10",
#endif
#endif
#if !X264_CHROMA_FORMAT || X264_CHROMA_FORMAT == X264_CSP_I422
   "high422",
#endif
   "high444", 0
};

const char * const x264_demuxer_names[] =
{
    "auto", "raw", "y4m",
#if HAVE_AVS
    "avs",
#endif
#if HAVE_LAVF
    "lavf",
#endif
#if HAVE_FFMS
    "ffms",
#endif
    0
};

const char * const x264_muxer_names[] =
{
    "auto", "raw", "mkv", "flv",
#if HAVE_GPAC || HAVE_LSMASH
    "mp4",
#endif
    0
};

static const char * const chroma_format_names[] =
{
    [0] = "all",
    [X264_CSP_I400] = "i400",
    [X264_CSP_I420] = "i420",
    [X264_CSP_I422] = "i422",
    [X264_CSP_I444] = "i444"
};

typedef struct
{
    int mod;
    uint8_t pattern[24];
    float fps_factor;
} cli_pulldown_t;

enum pulldown_type_e
{
    X264_PULLDOWN_22 = 1,
    X264_PULLDOWN_32,
    X264_PULLDOWN_64,
    X264_PULLDOWN_DOUBLE,
    X264_PULLDOWN_TRIPLE,
    X264_PULLDOWN_EURO
};

#define TB  PIC_STRUCT_TOP_BOTTOM
#define BT  PIC_STRUCT_BOTTOM_TOP
#define TBT PIC_STRUCT_TOP_BOTTOM_TOP
#define BTB PIC_STRUCT_BOTTOM_TOP_BOTTOM

static const cli_pulldown_t pulldown_values[] =
{
    [X264_PULLDOWN_22]     = {1,  {TB},                                   1.0},
    [X264_PULLDOWN_32]     = {4,  {TBT, BT, BTB, TB},                     1.25},
    [X264_PULLDOWN_64]     = {2,  {PIC_STRUCT_DOUBLE, PIC_STRUCT_TRIPLE}, 1.0},
    [X264_PULLDOWN_DOUBLE] = {1,  {PIC_STRUCT_DOUBLE},                    2.0},
    [X264_PULLDOWN_TRIPLE] = {1,  {PIC_STRUCT_TRIPLE},                    3.0},
    [X264_PULLDOWN_EURO]   = {24, {TBT, BT, BT, BT, BT, BT, BT, BT, BT, BT, BT, BT,
                                   BTB, TB, TB, TB, TB, TB, TB, TB, TB, TB, TB, TB}, 25.0/24.0}
};

#undef TB
#undef BT
#undef TBT
#undef BTB

// indexed by pic_struct enum
static const float pulldown_frame_duration[10] = { 0.0, 1, 0.5, 0.5, 1, 1, 1.5, 1.5, 2, 3 };

static void help( x264_param_t *defaults, int longhelp );
static int  parse( int argc, char **argv, x264_param_t *param, cli_opt_t *opt );
static int  encode( x264_param_t *param, cli_opt_t *opt );

/* logging and printing for within the cli system */
static int cli_log_level = X264_LOG_INFO;
void x264_cli_log( const char *name, int i_level, const char *fmt, ... )
{
    if( i_level > cli_log_level )
        return;
    char *s_level;
    switch( i_level )
    {
        case X264_LOG_ERROR:
            s_level = "error";
            break;
        case X264_LOG_WARNING:
            s_level = "warning";
            break;
        case X264_LOG_INFO:
            s_level = "info";
            break;
        case X264_LOG_DEBUG:
            s_level = "debug";
            break;
        default:
            s_level = "unknown";
            break;
    }
    fprintf( stderr, "%s [%s]: ", name, s_level );
    va_list arg;
    va_start( arg, fmt );
    x264_vfprintf( stderr, fmt, arg );
    va_end( arg );
}

void x264_cli_printf( int i_level, const char *fmt, ... )
{
    if( i_level > cli_log_level )
        return;
    va_list arg;
    va_start( arg, fmt );
    x264_vfprintf( stderr, fmt, arg );
    va_end( arg );
}

static void print_version_info( void )
{
#ifdef X264_POINTVER
    printf( "x264 "X264_POINTVER"\n" );
#else
    printf( "x264 0.%d.X\n", X264_BUILD );
#endif
#if HAVE_SWSCALE
    printf( "(libswscale %d.%d.%d)\n", LIBSWSCALE_VERSION_MAJOR, LIBSWSCALE_VERSION_MINOR, LIBSWSCALE_VERSION_MICRO );
#endif
#if HAVE_LAVF
    printf( "(libavformat %d.%d.%d)\n", LIBAVFORMAT_VERSION_MAJOR, LIBAVFORMAT_VERSION_MINOR, LIBAVFORMAT_VERSION_MICRO );
#endif
#if HAVE_FFMS
    printf( "(ffmpegsource %d.%d.%d.%d)\n", FFMS_VERSION >> 24, (FFMS_VERSION & 0xff0000) >> 16, (FFMS_VERSION & 0xff00) >> 8, FFMS_VERSION & 0xff );
#endif
#if HAVE_GPAC
    printf( "(gpac " GPAC_VERSION ")\n" );
#endif
#if HAVE_LSMASH
    printf( "(lsmash %d.%d.%d)\n", LSMASH_VERSION_MAJOR, LSMASH_VERSION_MINOR, LSMASH_VERSION_MICRO );
#endif
    printf( "built on " __DATE__ ", " );
#ifdef __INTEL_COMPILER
    printf( "intel: %.2f (%d)\n", __INTEL_COMPILER / 100.f, __INTEL_COMPILER_BUILD_DATE );
#elif defined(__clang__)
    printf( "clang: " __clang_version__ "\n" );
#elif defined(__GNUC__)
    printf( "gcc: " __VERSION__ "\n" );
#elif defined(_MSC_FULL_VER)
    printf( "msvc: %.2f (%u)\n", _MSC_VER / 100.f, _MSC_FULL_VER );
#else
    printf( "using an unknown compiler\n" );
#endif
    printf( "x264 configuration: --chroma-format=%s\n", chroma_format_names[X264_CHROMA_FORMAT] );
    printf( "libx264 configuration: --chroma-format=%s\n", chroma_format_names[x264_chroma_format] );
    printf( "x264 license: " );
#if HAVE_GPL
    printf( "GPL version 2 or later\n" );
#else
    printf( "Non-GPL commercial\n" );
#endif
#if HAVE_SWSCALE
    const char *license = swscale_license();
    printf( "libswscale%s%s license: %s\n", HAVE_LAVF ? "/libavformat" : "", HAVE_FFMS ? "/ffmpegsource" : "" , license );
    if( !strcmp( license, "nonfree and unredistributable" ) ||
       (!HAVE_GPL && (!strcmp( license, "GPL version 2 or later" )
                  ||  !strcmp( license, "GPL version 3 or later" ))))
        printf( "WARNING: This binary is unredistributable!\n" );
#endif
}

REALIGN_STACK int main( int argc, char **argv )
{
    if( argc == 4 && !strcmp( argv[1], "--autocomplete" ) )
        return x264_cli_autocomplete( argv[2], argv[3] );

    x264_param_t param;
    cli_opt_t opt = {0};
    int ret = 0;

    FAIL_IF_ERROR( x264_threading_init(), "unable to initialize threading\n" );

#ifdef _WIN32
    FAIL_IF_ERROR( !get_argv_utf8( &argc, &argv ), "unable to convert command line to UTF-8\n" );

    GetConsoleTitleW( org_console_title, CONSOLE_TITLE_SIZE );
    _setmode( _fileno( stdin ),  _O_BINARY );
    _setmode( _fileno( stdout ), _O_BINARY );
    _setmode( _fileno( stderr ), _O_BINARY );
#endif

    x264_param_default( &param );
    /* Parse command line */
    if( parse( argc, argv, &param, &opt ) < 0 )
        ret = -1;

#ifdef _WIN32
    /* Restore title; it can be changed by input modules */
    SetConsoleTitleW( org_console_title );
#endif

    /* Control-C handler */
    signal( SIGINT, sigint_handler );

    if( !ret )
        ret = encode( &param, &opt );

    /* clean up handles */
    if( filter.free )
        filter.free( opt.hin );
    else if( opt.hin )
        cli_input.close_file( opt.hin );
    if( opt.hout )
        cli_output.close_file( opt.hout, 0, 0 );
    if( opt.tcfile_out )
        fclose( opt.tcfile_out );
    if( opt.qpfile )
        fclose( opt.qpfile );
    x264_param_cleanup( &param );

#ifdef _WIN32
    SetConsoleTitleW( org_console_title );
    free( argv );
#endif

    return ret;
}

static char const *strtable_lookup( const char * const table[], int idx )
{
    int i = 0; while( table[i] ) i++;
    return ( idx >= 0 && idx < i && *table[idx] ) ? table[idx] : "???";
}

static char *stringify_names( char *buf, const char * const names[] )
{
    int i = 0;
    char *p = buf;
    for( p[0] = 0; names[i]; i++ )
        if( *names[i] )
        {
            if( p != buf )
                p += sprintf( p, ", " );
            p += sprintf( p, "%s", names[i] );
        }
    return buf;
}

#define INDENT "                                "
#define INDENT_LEN 32 // strlen( INDENT )
#define SEPARATOR ", "
#define SEPARATOR_LEN 2 // strlen( SEPARATOR )

static void print_csp_name_internal( const char *name, size_t *line_len, int last )
{
    if( name )
    {
        size_t name_len = strlen( name );
        if( *line_len + name_len > (80 - SEPARATOR_LEN) )
        {
            printf( "\n" INDENT );
            *line_len = INDENT_LEN;
        }
        printf( "%s", name );
        *line_len += name_len;
        if( !last )
        {
            printf( SEPARATOR );
            *line_len += SEPARATOR_LEN;
        }
    }
}

static void print_csp_names( int longhelp )
{
    if( longhelp < 2 )
        return;
    printf( "                              - valid csps for `raw' demuxer:\n" );
    printf( INDENT );
    size_t line_len = INDENT_LEN;
    for( int i = X264_CSP_NONE+1; i < X264_CSP_CLI_MAX; i++ )
        print_csp_name_internal( x264_cli_csps[i].name, &line_len, i == X264_CSP_CLI_MAX-1 );
#if HAVE_LAVF
    printf( "\n" );
    printf( "                              - valid csps for `lavf' demuxer:\n" );
    printf( INDENT );
    line_len = INDENT_LEN;
    for( enum AVPixelFormat i = AV_PIX_FMT_NONE+1; i < AV_PIX_FMT_NB; i++ )
        print_csp_name_internal( av_get_pix_fmt_name( i ), &line_len, i == AV_PIX_FMT_NB-1 );
#endif
    printf( "\n" );
}

static void help( x264_param_t *defaults, int longhelp )
{
    char buf[200];
#define H0 printf
#define H1 if( longhelp >= 1 ) printf
#define H2 if( longhelp == 2 ) printf
    H0( "x264 core:%d%s\n"
        "Syntax: x264 [options] -o outfile infile\n"
        "\n"
        "Infile can be raw (in which case resolution is required),\n"
        "  or YUV4MPEG (*.y4m),\n"
        "  or Avisynth if compiled with support (%s).\n"
        "  or libav* formats if compiled with lavf support (%s) or ffms support (%s).\n"
        "Outfile type is selected by filename:\n"
        " .264 -> Raw bytestream\n"
        " .mkv -> Matroska\n"
        " .flv -> Flash Video\n"
        " .mp4 -> MP4 if compiled with GPAC or L-SMASH support (%s)\n"
        "Output bit depth: %s\n"
        "\n"
        "Options:\n"
        "\n"
        "  -h, --help                  List basic options\n"
        "      --longhelp              List more options\n"
        "      --fullhelp              List all options\n"
        "\n",
        X264_BUILD, X264_VERSION,
#if HAVE_AVS
        "yes",
#else
        "no",
#endif
#if HAVE_LAVF
        "yes",
#else
        "no",
#endif
#if HAVE_FFMS
        "yes",
#else
        "no",
#endif
#if HAVE_GPAC
        "gpac",
#elif HAVE_LSMASH
        "lsmash",
#else
        "no",
#endif
#if HAVE_BITDEPTH8 && HAVE_BITDEPTH10
        "8/10"
#elif HAVE_BITDEPTH8
        "8"
#elif HAVE_BITDEPTH10
        "10"
#else
        "none"
#endif
      );
    H0( "Example usage:\n" );
    H0( "\n" );
    H0( "      Constant quality mode:\n" );
    H0( "            x264 --crf 24 -o <output> <input>\n" );
    H0( "\n" );
    H0( "      Two-pass with a bitrate of 1000kbps:\n" );
    H0( "            x264 --pass 1 --bitrate 1000 -o <output> <input>\n" );
    H0( "            x264 --pass 2 --bitrate 1000 -o <output> <input>\n" );
    H0( "\n" );
    H0( "      Lossless:\n" );
    H0( "            x264 --qp 0 -o <output> <input>\n" );
    H0( "\n" );
    H0( "      Maximum PSNR at the cost of speed and visual quality:\n" );
    H0( "            x264 --preset placebo --tune psnr -o <output> <input>\n" );
    H0( "\n" );
    H0( "      Constant bitrate at 1000kbps with a 2 second-buffer:\n");
    H0( "            x264 --vbv-bufsize 2000 --bitrate 1000 -o <output> <input>\n" );
    H0( "\n" );
    H0( "Presets:\n" );
    H0( "\n" );
    H0( "      --profile <string>      Force the limits of an H.264 profile\n"
        "                                  Overrides all settings.\n" );
    H2(
#if !X264_CHROMA_FORMAT || X264_CHROMA_FORMAT <= X264_CSP_I420
#if HAVE_BITDEPTH8
#if !X264_CHROMA_FORMAT || X264_CHROMA_FORMAT == X264_CSP_I420
        "                                  - baseline:\n"
        "                                    --no-8x8dct --bframes 0 --no-cabac\n"
        "                                    --cqm flat --weightp 0\n"
        "                                    No interlaced.\n"
        "                                    No lossless.\n"
        "                                  - main:\n"
        "                                    --no-8x8dct --cqm flat\n"
        "                                    No lossless.\n"
#endif
        "                                  - high:\n"
        "                                    No lossless.\n"
#endif
#if HAVE_BITDEPTH10
        "                                  - high10:\n"
        "                                    No lossless.\n"
        "                                    Support for bit depth 8-10.\n"
#endif
#endif
#if !X264_CHROMA_FORMAT || X264_CHROMA_FORMAT == X264_CSP_I422
        "                                  - high422:\n"
        "                                    No lossless.\n"
        "                                    Support for bit depth 8-10.\n"
        "                                    Support for 4:2:0/4:2:2 chroma subsampling.\n"
#endif
        "                                  - high444:\n"
        "                                    Support for bit depth 8-10.\n"
        "                                    Support for 4:2:0/4:2:2/4:4:4 chroma subsampling.\n" );
    else H0( "                                  - %s\n", stringify_names( buf, x264_valid_profile_names ) );
    H0( "      --preset <string>       Use a preset to select encoding settings [medium]\n"
        "                                  Overridden by user settings.\n" );
    H2( "                                  - ultrafast:\n"
        "                                    --no-8x8dct --aq-mode 0 --b-adapt 0\n"
        "                                    --bframes 0 --no-cabac --no-deblock\n"
        "                                    --no-mbtree --me dia --no-mixed-refs\n"
        "                                    --partitions none --rc-lookahead 0 --ref 1\n"
        "                                    --scenecut 0 --subme 0 --trellis 0\n"
        "                                    --no-weightb --weightp 0\n"
        "                                  - superfast:\n"
        "                                    --no-mbtree --me dia --no-mixed-refs\n"
        "                                    --partitions i8x8,i4x4 --rc-lookahead 0\n"
        "                                    --ref 1 --subme 1 --trellis 0 --weightp 1\n"
        "                                  - veryfast:\n"
        "                                    --no-mixed-refs --rc-lookahead 10\n"
        "                                    --ref 1 --subme 2 --trellis 0 --weightp 1\n"
        "                                  - faster:\n"
        "                                    --no-mixed-refs --rc-lookahead 20\n"
        "                                    --ref 2 --subme 4 --weightp 1\n"
        "                                  - fast:\n"
        "                                    --rc-lookahead 30 --ref 2 --subme 6\n"
        "                                    --weightp 1\n"
        "                                  - medium:\n"
        "                                    Default settings apply.\n"
        "                                  - slow:\n"
        "                                    --direct auto --rc-lookahead 50 --ref 5\n"
        "                                    --subme 8 --trellis 2\n"
        "                                  - slower:\n"
        "                                    --b-adapt 2 --direct auto --me umh\n"
        "                                    --partitions all --rc-lookahead 60\n"
        "                                    --ref 8 --subme 9 --trellis 2\n"
        "                                  - veryslow:\n"
        "                                    --b-adapt 2 --bframes 8 --direct auto\n"
        "                                    --me umh --merange 24 --partitions all\n"
        "                                    --ref 16 --subme 10 --trellis 2\n"
        "                                    --rc-lookahead 60\n"
        "                                  - placebo:\n"
        "                                    --bframes 16 --b-adapt 2 --direct auto\n"
        "                                    --slow-firstpass --no-fast-pskip\n"
        "                                    --me tesa --merange 24 --partitions all\n"
        "                                    --rc-lookahead 60 --ref 16 --subme 11\n"
        "                                    --trellis 2\n" );
    else H0( "                                  - ultrafast,superfast,veryfast,faster,fast\n"
             "                                  - medium,slow,slower,veryslow,placebo\n" );
    H0( "      --tune <string>         Tune the settings for a particular type of source\n"
        "                              or situation\n"
        "                                  Overridden by user settings.\n"
        "                                  Multiple tunings are separated by commas.\n"
        "                                  Only one psy tuning can be used at a time.\n" );
    H2( "                                  - film (psy tuning):\n"
        "                                    --deblock -1:-1 --psy-rd <unset>:0.15\n"
        "                                  - animation (psy tuning):\n"
        "                                    --bframes {+2} --deblock 1:1\n"
        "                                    --psy-rd 0.4:<unset> --aq-strength 0.6\n"
        "                                    --ref {Double if >1 else 1}\n"
        "                                  - grain (psy tuning):\n"
        "                                    --aq-strength 0.5 --no-dct-decimate\n"
        "                                    --deadzone-inter 6 --deadzone-intra 6\n"
        "                                    --deblock -2:-2 --ipratio 1.1\n"
        "                                    --pbratio 1.1 --psy-rd <unset>:0.25\n"
        "                                    --qcomp 0.8\n"
        "                                  - stillimage (psy tuning):\n"
        "                                    --aq-strength 1.2 --deblock -3:-3\n"
        "                                    --psy-rd 2.0:0.7\n"
        "                                  - psnr (psy tuning):\n"
        "                                    --aq-mode 0 --no-psy\n"
        "                                  - ssim (psy tuning):\n"
        "                                    --aq-mode 2 --no-psy\n"
        "                                  - fastdecode:\n"
        "                                    --no-cabac --no-deblock --no-weightb\n"
        "                                    --weightp 0\n"
        "                                  - zerolatency:\n"
        "                                    --bframes 0 --force-cfr --no-mbtree\n"
        "                                    --sync-lookahead 0 --sliced-threads\n"
        "                                    --rc-lookahead 0\n" );
    else H0( "                                  - psy tunings: film,animation,grain,\n"
             "                                                 stillimage,psnr,ssim\n"
             "                                  - other tunings: fastdecode,zerolatency\n" );
    H2( "      --slow-firstpass        Don't force these faster settings with --pass 1:\n"
        "                                  --no-8x8dct --me dia --partitions none\n"
        "                                  --ref 1 --subme {2 if >2 else unchanged}\n"
        "                                  --trellis 0 --fast-pskip\n" );
    else H1( "      --slow-firstpass        Don't force faster settings with --pass 1\n" );
    H0( "\n" );
    H0( "Frame-type options:\n" );
    H0( "\n" );
    H0( "  -I, --keyint <integer or \"infinite\"> Maximum GOP size [%d]\n", defaults->i_keyint_max );
    H2( "  -i, --min-keyint <integer>  Minimum GOP size [auto]\n" );
    H2( "      --no-scenecut           Disable adaptive I-frame decision\n" );
    H2( "      --scenecut <integer>    How aggressively to insert extra I-frames [%d]\n", defaults->i_scenecut_threshold );
    H2( "      --intra-refresh         Use Periodic Intra Refresh instead of IDR frames\n" );
    H1( "  -b, --bframes <integer>     Number of B-frames between I and P [%d]\n", defaults->i_bframe );
    H1( "      --b-adapt <integer>     Adaptive B-frame decision method [%d]\n"
        "                                  Higher values may lower threading efficiency.\n"
        "                                  - 0: Disabled\n"
        "                                  - 1: Fast\n"
        "                                  - 2: Optimal (slow with high --bframes)\n", defaults->i_bframe_adaptive );
    H2( "      --b-bias <integer>      Influences how often B-frames are used [%d]\n", defaults->i_bframe_bias );
    H1( "      --b-pyramid <string>    Keep some B-frames as references [%s]\n"
        "                                  - none: Disabled\n"
        "                                  - strict: Strictly hierarchical pyramid\n"
        "                                  - normal: Non-strict (not Blu-ray compatible)\n",
        strtable_lookup( x264_b_pyramid_names, defaults->i_bframe_pyramid ) );
    H1( "      --open-gop              Use recovery points to close GOPs\n"
        "                              Only available with b-frames\n" );
    H1( "      --no-cabac              Disable CABAC\n" );
    H1( "  -r, --ref <integer>         Number of reference frames [%d]\n", defaults->i_frame_reference );
    H1( "      --no-deblock            Disable loop filter\n" );
    H1( "  -f, --deblock <alpha:beta>  Loop filter parameters [%d:%d]\n",
                                       defaults->i_deblocking_filter_alphac0, defaults->i_deblocking_filter_beta );
    H2( "      --slices <integer>      Number of slices per frame; forces rectangular\n"
        "                              slices and is overridden by other slicing options\n" );
    else H1( "      --slices <integer>      Number of slices per frame\n" );
    H2( "      --slices-max <integer>  Absolute maximum slices per frame; overrides\n"
        "                              slice-max-size/slice-max-mbs when necessary\n" );
    H2( "      --slice-max-size <integer> Limit the size of each slice in bytes\n");
    H2( "      --slice-max-mbs <integer> Limit the size of each slice in macroblocks (max)\n");
    H2( "      --slice-min-mbs <integer> Limit the size of each slice in macroblocks (min)\n");
    H0( "      --tff                   Enable interlaced mode (top field first)\n" );
    H0( "      --bff                   Enable interlaced mode (bottom field first)\n" );
    H2( "      --constrained-intra     Enable constrained intra prediction.\n" );
    H0( "      --pulldown <string>     Use soft pulldown to change frame rate\n"
        "                                  - %s (requires cfr input)\n", stringify_names( buf, x264_pulldown_names ) );
    H2( "      --fake-interlaced       Flag stream as interlaced but encode progressive.\n"
        "                              Makes it possible to encode 25p and 30p Blu-Ray\n"
        "                              streams. Ignored in interlaced mode.\n" );
    H2( "      --frame-packing <integer> For stereoscopic videos define frame arrangement\n"
        "                                  - 0: checkerboard - pixels are alternatively from L and R\n"
        "                                  - 1: column alternation - L and R are interlaced by column\n"
        "                                  - 2: row alternation - L and R are interlaced by row\n"
        "                                  - 3: side by side - L is on the left, R on the right\n"
        "                                  - 4: top bottom - L is on top, R on bottom\n"
        "                                  - 5: frame alternation - one view per frame\n"
        "                                  - 6: mono - 2D frame without any frame packing\n"
        "                                  - 7: tile format - L is on top-left, R split across\n" );
    H0( "\n" );
    H0( "Ratecontrol:\n" );
    H0( "\n" );
    H1( "  -q, --qp <integer>          Force constant QP (0-%d, 0=lossless)\n", QP_MAX );
    H0( "  -B, --bitrate <integer>     Set bitrate (kbit/s)\n" );
    H0( "      --crf <float>           Quality-based VBR (%d-51) [%.1f]\n", 51 - QP_MAX_SPEC, defaults->rc.f_rf_constant );
    H1( "      --rc-lookahead <integer> Number of frames for frametype lookahead [%d]\n", defaults->rc.i_lookahead );
    H0( "      --vbv-maxrate <integer> Max local bitrate (kbit/s) [%d]\n", defaults->rc.i_vbv_max_bitrate );
    H0( "      --vbv-bufsize <integer> Set size of the VBV buffer (kbit) [%d]\n", defaults->rc.i_vbv_buffer_size );
    H2( "      --vbv-init <float>      Initial VBV buffer occupancy [%.1f]\n", defaults->rc.f_vbv_buffer_init );
    H2( "      --crf-max <float>       With CRF+VBV, limit RF to this value\n"
        "                                  May cause VBV underflows!\n" );
    H2( "      --qpmin <integer>       Set min QP [%d]\n", defaults->rc.i_qp_min );
    H2( "      --qpmax <integer>       Set max QP [%d]\n", X264_MIN( defaults->rc.i_qp_max, QP_MAX ) );
    H2( "      --qpstep <integer>      Set max QP step [%d]\n", defaults->rc.i_qp_step );
    H2( "      --ratetol <float>       Tolerance of ABR ratecontrol and VBV [%.1f]\n", defaults->rc.f_rate_tolerance );
    H2( "      --ipratio <float>       QP factor between I and P [%.2f]\n", defaults->rc.f_ip_factor );
    H2( "      --pbratio <float>       QP factor between P and B [%.2f]\n", defaults->rc.f_pb_factor );
    H2( "      --chroma-qp-offset <integer>  QP difference between chroma and luma [%d]\n", defaults->analyse.i_chroma_qp_offset );
    H2( "      --aq-mode <integer>     AQ method [%d]\n"
        "                                  - 0: Disabled\n"
        "                                  - 1: Variance AQ (complexity mask)\n"
        "                                  - 2: Auto-variance AQ\n"
        "                                  - 3: Auto-variance AQ with bias to dark scenes\n", defaults->rc.i_aq_mode );
    H1( "      --aq-strength <float>   Reduces blocking and blurring in flat and\n"
        "                              textured areas. [%.1f]\n", defaults->rc.f_aq_strength );
    H1( "\n" );
    H0( "  -p, --pass <integer>        Enable multipass ratecontrol\n"
        "                                  - 1: First pass, creates stats file\n"
        "                                  - 2: Last pass, does not overwrite stats file\n" );
    H2( "                                  - 3: Nth pass, overwrites stats file\n" );
    H1( "      --stats <string>        Filename for 2 pass stats [\"%s\"]\n", defaults->rc.psz_stat_out );
    H2( "      --no-mbtree             Disable mb-tree ratecontrol.\n");
    H2( "      --qcomp <float>         QP curve compression [%.2f]\n", defaults->rc.f_qcompress );
    H2( "      --cplxblur <float>      Reduce fluctuations in QP (before curve compression) [%.1f]\n", defaults->rc.f_complexity_blur );
    H2( "      --qblur <float>         Reduce fluctuations in QP (after curve compression) [%.1f]\n", defaults->rc.f_qblur );
    H2( "      --zones <zone0>/<zone1>/...  Tweak the bitrate of regions of the video\n" );
    H2( "                              Each zone is of the form\n"
        "                                  <start frame>,<end frame>,<option>\n"
        "                                  where <option> is either\n"
        "                                      q=<integer> (force QP)\n"
        "                                  or  b=<float> (bitrate multiplier)\n" );
    H2( "      --qpfile <string>       Force frametypes and QPs for some or all frames\n"
        "                              Format of each line: framenumber frametype QP\n"
        "                              QP is optional (none lets x264 choose). Frametypes: I,i,K,P,B,b.\n"
        "                                  K=<I or i> depending on open-gop setting\n"
        "                              QPs are restricted by qpmin/qpmax.\n" );
    H1( "\n" );
    H1( "Analysis:\n" );
    H1( "\n" );
    H1( "  -A, --partitions <string>   Partitions to consider [\"p8x8,b8x8,i8x8,i4x4\"]\n"
        "                                  - %s\n"
        "                                  (p4x4 requires p8x8. i8x8 requires --8x8dct.)\n", stringify_names( buf, x264_partition_names ) );
    H1( "      --direct <string>       Direct MV prediction mode [\"%s\"]\n"
        "                                  - none, spatial, temporal, auto\n",
                                       strtable_lookup( x264_direct_pred_names, defaults->analyse.i_direct_mv_pred ) );
    H2( "      --no-weightb            Disable weighted prediction for B-frames\n" );
    H1( "      --weightp <integer>     Weighted prediction for P-frames [%d]\n"
        "                                  - 0: Disabled\n"
        "                                  - 1: Weighted refs\n"
        "                                  - 2: Weighted refs + Duplicates\n", defaults->analyse.i_weighted_pred );
    H1( "      --me <string>           Integer pixel motion estimation method [\"%s\"]\n",
                                       strtable_lookup( x264_motion_est_names, defaults->analyse.i_me_method ) );
    H2( "                                  - dia: diamond search, radius 1 (fast)\n"
        "                                  - hex: hexagonal search, radius 2\n"
        "                                  - umh: uneven multi-hexagon search\n"
        "                                  - esa: exhaustive search\n"
        "                                  - tesa: hadamard exhaustive search (slow)\n" );
    else H1( "                                  - dia, hex, umh\n" );
    H2( "      --merange <integer>     Maximum motion vector search range [%d]\n", defaults->analyse.i_me_range );
    H2( "      --mvrange <integer>     Maximum motion vector length [-1 (auto)]\n" );
    H2( "      --mvrange-thread <int>  Minimum buffer between threads [-1 (auto)]\n" );
    H1( "  -m, --subme <integer>       Subpixel motion estimation and mode decision [%d]\n", defaults->analyse.i_subpel_refine );
    H2( "                                  - 0: fullpel only (not recommended)\n"
        "                                  - 1: SAD mode decision, one qpel iteration\n"
        "                                  - 2: SATD mode decision\n"
        "                                  - 3-5: Progressively more qpel\n"
        "                                  - 6: RD mode decision for I/P-frames\n"
        "                                  - 7: RD mode decision for all frames\n"
        "                                  - 8: RD refinement for I/P-frames\n"
        "                                  - 9: RD refinement for all frames\n"
        "                                  - 10: QP-RD - requires trellis=2, aq-mode>0\n"
        "                                  - 11: Full RD: disable all early terminations\n" );
    else H1( "                                  decision quality: 1=fast, 11=best\n" );
    H1( "      --psy-rd <float:float>  Strength of psychovisual optimization [\"%.1f:%.1f\"]\n"
        "                                  #1: RD (requires subme>=6)\n"
        "                                  #2: Trellis (requires trellis, experimental)\n",
                                       defaults->analyse.f_psy_rd, defaults->analyse.f_psy_trellis );
    H2( "      --no-psy                Disable all visual optimizations that worsen\n"
        "                              both PSNR and SSIM.\n" );
    H2( "      --no-mixed-refs         Don't decide references on a per partition basis\n" );
    H2( "      --no-chroma-me          Ignore chroma in motion estimation\n" );
    H1( "      --no-8x8dct             Disable adaptive spatial transform size\n" );
    H1( "  -t, --trellis <integer>     Trellis RD quantization. [%d]\n"
        "                                  - 0: disabled\n"
        "                                  - 1: enabled only on the final encode of a MB\n"
        "                                  - 2: enabled on all mode decisions\n", defaults->analyse.i_trellis );
    H2( "      --no-fast-pskip         Disables early SKIP detection on P-frames\n" );
    H2( "      --no-dct-decimate       Disables coefficient thresholding on P-frames\n" );
    H1( "      --nr <integer>          Noise reduction [%d]\n", defaults->analyse.i_noise_reduction );
    H2( "\n" );
    H2( "      --deadzone-inter <int>  Set the size of the inter luma quantization deadzone [%d]\n", defaults->analyse.i_luma_deadzone[0] );
    H2( "      --deadzone-intra <int>  Set the size of the intra luma quantization deadzone [%d]\n", defaults->analyse.i_luma_deadzone[1] );
    H2( "                                  Deadzones should be in the range 0 - 32.\n" );
    H2( "      --cqm <string>          Preset quant matrices [\"%s\"]\n"
        "                                  - %s\n", x264_cqm_names[0], stringify_names( buf, x264_cqm_names ) );
    H1( "      --cqmfile <string>      Read custom quant matrices from a JM-compatible file\n" );
    H2( "                                  Overrides any other --cqm* options.\n" );
    H2( "      --cqm4 <list>           Set all 4x4 quant matrices\n"
        "                                  Takes a comma-separated list of 16 integers.\n" );
    H2( "      --cqm8 <list>           Set all 8x8 quant matrices\n"
        "                                  Takes a comma-separated list of 64 integers.\n" );
    H2( "      --cqm4i, --cqm4p, --cqm8i, --cqm8p <list>\n"
        "                              Set both luma and chroma quant matrices\n" );
    H2( "      --cqm4iy, --cqm4ic, --cqm4py, --cqm4pc <list>\n"
        "                              Set individual quant matrices\n" );
    H2( "\n" );
    H2( "Video Usability Info (Annex E):\n" );
    H2( "The VUI settings are not used by the encoder but are merely suggestions to\n" );
    H2( "the playback equipment. See doc/vui.txt for details. Use at your own risk.\n" );
    H2( "\n" );
    H2( "      --overscan <string>     Specify crop overscan setting [\"%s\"]\n"
        "                                  - undef, show, crop\n",
                                       strtable_lookup( x264_overscan_names, defaults->vui.i_overscan ) );
    H2( "      --videoformat <string>  Specify video format [\"%s\"]\n"
        "                                  - component, pal, ntsc, secam, mac, undef\n",
                                       strtable_lookup( x264_vidformat_names, defaults->vui.i_vidformat ) );
    H2( "      --range <string>        Specify color range [\"%s\"]\n"
        "                                  - %s\n", x264_range_names[0], stringify_names( buf, x264_range_names ) );
    H2( "      --colorprim <string>    Specify color primaries [\"%s\"]\n"
        "                                  - undef, bt709, bt470m, bt470bg, smpte170m,\n"
        "                                    smpte240m, film, bt2020, smpte428,\n"
        "                                    smpte431, smpte432\n",
                                       strtable_lookup( x264_colorprim_names, defaults->vui.i_colorprim ) );
    H2( "      --transfer <string>     Specify transfer characteristics [\"%s\"]\n"
        "                                  - undef, bt709, bt470m, bt470bg, smpte170m,\n"
        "                                    smpte240m, linear, log100, log316,\n"
        "                                    iec61966-2-4, bt1361e, iec61966-2-1,\n"
        "                                    bt2020-10, bt2020-12, smpte2084, smpte428,\n"
        "                                    arib-std-b67\n",
                                       strtable_lookup( x264_transfer_names, defaults->vui.i_transfer ) );
    H2( "      --colormatrix <string>  Specify color matrix setting [\"%s\"]\n"
        "                                  - undef, bt709, fcc, bt470bg, smpte170m,\n"
        "                                    smpte240m, GBR, YCgCo, bt2020nc, bt2020c,\n"
        "                                    smpte2085, chroma-derived-nc,\n"
        "                                    chroma-derived-c, ICtCp\n",
                                       strtable_lookup( x264_colmatrix_names, defaults->vui.i_colmatrix ) );
    H2( "      --chromaloc <integer>   Specify chroma sample location (0 to 5) [%d]\n",
                                       defaults->vui.i_chroma_loc );
    H2( "      --mastering-display <string> Specify 'G(x,y)B(x,y)R(x,y)WP(x,y)L(max,min)'\n"
        "                              for primaries, white point, and display brightness\n" );
    H2( "      --cll <string>          Specify 'max_content,max_frame_average' content\n"
        "                              light levels\n" );
    H2( "      --alternative-transfer <string> Specify an alternative transfer\n"
        "                              characteristics [\"%s\"]\n"
        "                                  - same values as --transfer\n",
                                       strtable_lookup( x264_transfer_names, defaults->i_alternative_transfer ) );
    H2( "      --nal-hrd <string>      Signal HRD information (requires vbv-bufsize)\n"
        "                                  - none, vbr, cbr (cbr not allowed in .mp4)\n" );
    H2( "      --filler                Force hard-CBR and generate filler (implied by\n"
        "                              --nal-hrd cbr)\n" );
    H2( "      --pic-struct            Force pic_struct in Picture Timing SEI\n" );
    H2( "      --crop-rect <string>    Add 'left,top,right,bottom' to the bitstream-level\n"
        "                              cropping rectangle\n" );

    H0( "\n" );
    H0( "Input/Output:\n" );
    H0( "\n" );
    H0( "  -o, --output <string>       Specify output file\n" );
    H1( "      --muxer <string>        Specify output container format [\"%s\"]\n"
        "                                  - %s\n", x264_muxer_names[0], stringify_names( buf, x264_muxer_names ) );
    H1( "      --demuxer <string>      Specify input container format [\"%s\"]\n"
        "                                  - %s\n", x264_demuxer_names[0], stringify_names( buf, x264_demuxer_names ) );
    H1( "      --input-fmt <string>    Specify input file format (requires lavf support)\n" );
    H1( "      --input-csp <string>    Specify input colorspace format for raw input\n" );
    print_csp_names( longhelp );
    H1( "      --output-csp <string>   Specify output colorspace [\"%s\"]\n"
        "                                  - %s\n",
#if X264_CHROMA_FORMAT
        x264_output_csp_names[0],
#else
        "i420",
#endif
        stringify_names( buf, x264_output_csp_names ) );
    H1( "      --input-depth <integer> Specify input bit depth for raw input\n" );
    H1( "      --output-depth <integer> Specify output bit depth\n" );
    H1( "      --input-range <string>  Specify input color range [\"%s\"]\n"
        "                                  - %s\n", x264_range_names[0], stringify_names( buf, x264_range_names ) );
    H1( "      --input-res <intxint>   Specify input resolution (width x height)\n" );
    H1( "      --index <string>        Filename for input index file\n" );
    H0( "      --sar width:height      Specify Sample Aspect Ratio\n" );
    H0( "      --fps <float|rational>  Specify framerate\n" );
    H0( "      --seek <integer>        First frame to encode\n" );
    H0( "      --frames <integer>      Maximum number of frames to encode\n" );
    H0( "      --level <string>        Specify level (as defined by Annex A)\n" );
    H1( "      --bluray-compat         Enable compatibility hacks for Blu-ray support\n" );
    H1( "      --avcintra-class <integer> Use compatibility hacks for AVC-Intra class\n"
        "                                  - %s\n", stringify_names( buf, x264_avcintra_class_names ) );
    H1( "      --avcintra-flavor <string> AVC-Intra flavor [\"%s\"]\n"
        "                                  - %s\n", x264_avcintra_flavor_names[0], stringify_names( buf, x264_avcintra_flavor_names ) );
    H1( "      --stitchable            Don't optimize headers based on video content\n"
        "                              Ensures ability to recombine a segmented encode\n" );
    H1( "\n" );
    H1( "  -v, --verbose               Print stats for each frame\n" );
    H1( "      --no-progress           Don't show the progress indicator while encoding\n" );
    H0( "      --quiet                 Quiet Mode\n" );
    H1( "      --log-level <string>    Specify the maximum level of logging [\"%s\"]\n"
        "                                  - %s\n", strtable_lookup( x264_log_level_names, cli_log_level - X264_LOG_NONE ),
                                       stringify_names( buf, x264_log_level_names ) );
    H1( "      --psnr                  Enable PSNR computation\n" );
    H1( "      --ssim                  Enable SSIM computation\n" );
    H1( "      --threads <integer>     Force a specific number of threads\n" );
    H2( "      --lookahead-threads <integer> Force a specific number of lookahead threads\n" );
    H2( "      --sliced-threads        Low-latency but lower-efficiency threading\n" );
    H2( "      --thread-input          Run Avisynth in its own thread\n" );
    H2( "      --sync-lookahead <integer> Number of buffer frames for threaded lookahead\n" );
    H2( "      --non-deterministic     Slightly improve quality of SMP, at the cost of repeatability\n" );
    H2( "      --cpu-independent       Ensure exact reproducibility across different cpus,\n"
        "                                  as opposed to letting them select different algorithms\n" );
    H2( "      --asm <integer>         Override CPU detection\n" );
    H2( "      --no-asm                Disable all CPU optimizations\n" );
    H2( "      --opencl                Enable use of OpenCL\n" );
    H2( "      --opencl-clbin <string> Specify path of compiled OpenCL kernel cache\n" );
    H2( "      --opencl-device <integer> Specify OpenCL device ordinal\n" );
    H2( "      --dump-yuv <string>     Save reconstructed frames\n" );
    H2( "      --sps-id <integer>      Set SPS and PPS id numbers [%d]\n", defaults->i_sps_id );
    H2( "      --aud                   Use access unit delimiters\n" );
    H2( "      --force-cfr             Force constant framerate timestamp generation\n" );
    H2( "      --tcfile-in <string>    Force timestamp generation with timecode file\n" );
    H2( "      --tcfile-out <string>   Output timecode v2 file from input timestamps\n" );
    H2( "      --timebase <int/int>    Specify timebase numerator and denominator\n"
        "                 <integer>    Specify timebase numerator for input timecode file\n"
        "                              or specify timebase denominator for other input\n" );
    H2( "      --dts-compress          Eliminate initial delay with container DTS hack\n" );
    H0( "\n" );
    H0( "Filtering:\n" );
    H0( "\n" );
    H0( "      --vf, --video-filter <filter0>/<filter1>/... Apply video filtering to the input file\n" );
    H0( "\n" );
    H0( "      Filter options may be specified in <filter>:<option>=<value> format.\n" );
    H0( "\n" );
    H0( "      Available filters:\n" );
    x264_register_vid_filters();
    x264_vid_filter_help( longhelp );
    H0( "\n" );
}

typedef enum
{
    OPT_FRAMES = 256,
    OPT_SEEK,
    OPT_QPFILE,
    OPT_THREAD_INPUT,
    OPT_QUIET,
    OPT_NOPROGRESS,
    OPT_LONGHELP,
    OPT_PROFILE,
    OPT_PRESET,
    OPT_TUNE,
    OPT_SLOWFIRSTPASS,
    OPT_FULLHELP,
    OPT_FPS,
    OPT_MUXER,
    OPT_DEMUXER,
    OPT_INDEX,
    OPT_INTERLACED,
    OPT_TCFILE_IN,
    OPT_TCFILE_OUT,
    OPT_TIMEBASE,
    OPT_PULLDOWN,
    OPT_LOG_LEVEL,
    OPT_VIDEO_FILTER,
    OPT_INPUT_FMT,
    OPT_INPUT_RES,
    OPT_INPUT_CSP,
    OPT_INPUT_DEPTH,
    OPT_OUTPUT_DEPTH,
    OPT_DTS_COMPRESSION,
    OPT_OUTPUT_CSP,
    OPT_INPUT_RANGE,
    OPT_RANGE
} OptionsOPT;

static char short_options[] = "8A:B:b:f:hI:i:m:o:p:q:r:t:Vvw";
static struct option long_options[] =
{
    { "help",                 no_argument,       NULL, 'h' },
    { "longhelp",             no_argument,       NULL, OPT_LONGHELP },
    { "fullhelp",             no_argument,       NULL, OPT_FULLHELP },
    { "version",              no_argument,       NULL, 'V' },
    { "profile",              required_argument, NULL, OPT_PROFILE },
    { "preset",               required_argument, NULL, OPT_PRESET },
    { "tune",                 required_argument, NULL, OPT_TUNE },
    { "slow-firstpass",       no_argument,       NULL, OPT_SLOWFIRSTPASS },
    { "bitrate",              required_argument, NULL, 'B' },
    { "bframes",              required_argument, NULL, 'b' },
    { "b-adapt",              required_argument, NULL, 0 },
    { "no-b-adapt",           no_argument,       NULL, 0 },
    { "b-bias",               required_argument, NULL, 0 },
    { "b-pyramid",            required_argument, NULL, 0 },
    { "open-gop",             no_argument,       NULL, 0 },
    { "bluray-compat",        no_argument,       NULL, 0 },
    { "avcintra-class",       required_argument, NULL, 0 },
    { "avcintra-flavor",      required_argument, NULL, 0 },
    { "min-keyint",           required_argument, NULL, 'i' },
    { "keyint",               required_argument, NULL, 'I' },
    { "intra-refresh",        no_argument,       NULL, 0 },
    { "scenecut",             required_argument, NULL, 0 },
    { "no-scenecut",          no_argument,       NULL, 0 },
    { "nf",                   no_argument,       NULL, 0 },
    { "no-deblock",           no_argument,       NULL, 0 },
    { "filter",               required_argument, NULL, 0 },
    { "deblock",              required_argument, NULL, 'f' },
    { "interlaced",           no_argument,       NULL, OPT_INTERLACED },
    { "tff",                  no_argument,       NULL, OPT_INTERLACED },
    { "bff",                  no_argument,       NULL, OPT_INTERLACED },
    { "no-interlaced",        no_argument,       NULL, OPT_INTERLACED },
    { "constrained-intra",    no_argument,       NULL, 0 },
    { "cabac",                no_argument,       NULL, 0 },
    { "no-cabac",             no_argument,       NULL, 0 },
    { "qp",                   required_argument, NULL, 'q' },
    { "qpmin",                required_argument, NULL, 0 },
    { "qpmax",                required_argument, NULL, 0 },
    { "qpstep",               required_argument, NULL, 0 },
    { "crf",                  required_argument, NULL, 0 },
    { "rc-lookahead",         required_argument, NULL, 0 },
    { "ref",                  required_argument, NULL, 'r' },
    { "asm",                  required_argument, NULL, 0 },
    { "no-asm",               no_argument,       NULL, 0 },
    { "opencl",               no_argument,       NULL, 1 },
    { "opencl-clbin",         required_argument, NULL, 0 },
    { "opencl-device",        required_argument, NULL, 0 },
    { "sar",                  required_argument, NULL, 0 },
    { "fps",                  required_argument, NULL, OPT_FPS },
    { "frames",               required_argument, NULL, OPT_FRAMES },
    { "seek",                 required_argument, NULL, OPT_SEEK },
    { "output",               required_argument, NULL, 'o' },
    { "muxer",                required_argument, NULL, OPT_MUXER },
    { "demuxer",              required_argument, NULL, OPT_DEMUXER },
    { "stdout",               required_argument, NULL, OPT_MUXER },
    { "stdin",                required_argument, NULL, OPT_DEMUXER },
    { "index",                required_argument, NULL, OPT_INDEX },
    { "analyse",              required_argument, NULL, 0 },
    { "partitions",           required_argument, NULL, 'A' },
    { "direct",               required_argument, NULL, 0 },
    { "weightb",              no_argument,       NULL, 'w' },
    { "no-weightb",           no_argument,       NULL, 0 },
    { "weightp",              required_argument, NULL, 0 },
    { "me",                   required_argument, NULL, 0 },
    { "merange",              required_argument, NULL, 0 },
    { "mvrange",              required_argument, NULL, 0 },
    { "mvrange-thread",       required_argument, NULL, 0 },
    { "subme",                required_argument, NULL, 'm' },
    { "psy-rd",               required_argument, NULL, 0 },
    { "no-psy",               no_argument,       NULL, 0 },
    { "psy",                  no_argument,       NULL, 0 },
    { "mixed-refs",           no_argument,       NULL, 0 },
    { "no-mixed-refs",        no_argument,       NULL, 0 },
    { "no-chroma-me",         no_argument,       NULL, 0 },
    { "8x8dct",               no_argument,       NULL, '8' },
    { "no-8x8dct",            no_argument,       NULL, 0 },
    { "trellis",              required_argument, NULL, 't' },
    { "fast-pskip",           no_argument,       NULL, 0 },
    { "no-fast-pskip",        no_argument,       NULL, 0 },
    { "no-dct-decimate",      no_argument,       NULL, 0 },
    { "aq-strength",          required_argument, NULL, 0 },
    { "aq-mode",              required_argument, NULL, 0 },
    { "deadzone-inter",       required_argument, NULL, 0 },
    { "deadzone-intra",       required_argument, NULL, 0 },
    { "level",                required_argument, NULL, 0 },
    { "ratetol",              required_argument, NULL, 0 },
    { "vbv-maxrate",          required_argument, NULL, 0 },
    { "vbv-bufsize",          required_argument, NULL, 0 },
    { "vbv-init",             required_argument, NULL, 0 },
    { "crf-max",              required_argument, NULL, 0 },
    { "ipratio",              required_argument, NULL, 0 },
    { "pbratio",              required_argument, NULL, 0 },
    { "chroma-qp-offset",     required_argument, NULL, 0 },
    { "pass",                 required_argument, NULL, 'p' },
    { "stats",                required_argument, NULL, 0 },
    { "qcomp",                required_argument, NULL, 0 },
    { "mbtree",               no_argument,       NULL, 0 },
    { "no-mbtree",            no_argument,       NULL, 0 },
    { "qblur",                required_argument, NULL, 0 },
    { "cplxblur",             required_argument, NULL, 0 },
    { "zones",                required_argument, NULL, 0 },
    { "qpfile",               required_argument, NULL, OPT_QPFILE },
    { "threads",              required_argument, NULL, 0 },
    { "lookahead-threads",    required_argument, NULL, 0 },
    { "sliced-threads",       no_argument,       NULL, 0 },
    { "no-sliced-threads",    no_argument,       NULL, 0 },
    { "slice-max-size",       required_argument, NULL, 0 },
    { "slice-max-mbs",        required_argument, NULL, 0 },
    { "slice-min-mbs",        required_argument, NULL, 0 },
    { "slices",               required_argument, NULL, 0 },
    { "slices-max",           required_argument, NULL, 0 },
    { "thread-input",         no_argument,       NULL, OPT_THREAD_INPUT },
    { "sync-lookahead",       required_argument, NULL, 0 },
    { "non-deterministic",    no_argument,       NULL, 0 },
    { "cpu-independent",      no_argument,       NULL, 0 },
    { "psnr",                 no_argument,       NULL, 0 },
    { "ssim",                 no_argument,       NULL, 0 },
    { "quiet",                no_argument,       NULL, OPT_QUIET },
    { "verbose",              no_argument,       NULL, 'v' },
    { "log-level",            required_argument, NULL, OPT_LOG_LEVEL },
    { "no-progress",          no_argument,       NULL, OPT_NOPROGRESS },
    { "dump-yuv",             required_argument, NULL, 0 },
    { "sps-id",               required_argument, NULL, 0 },
    { "aud",                  no_argument,       NULL, 0 },
    { "nr",                   required_argument, NULL, 0 },
    { "cqm",                  required_argument, NULL, 0 },
    { "cqmfile",              required_argument, NULL, 0 },
    { "cqm4",                 required_argument, NULL, 0 },
    { "cqm4i",                required_argument, NULL, 0 },
    { "cqm4iy",               required_argument, NULL, 0 },
    { "cqm4ic",               required_argument, NULL, 0 },
    { "cqm4p",                required_argument, NULL, 0 },
    { "cqm4py",               required_argument, NULL, 0 },
    { "cqm4pc",               required_argument, NULL, 0 },
    { "cqm8",                 required_argument, NULL, 0 },
    { "cqm8i",                required_argument, NULL, 0 },
    { "cqm8p",                required_argument, NULL, 0 },
    { "overscan",             required_argument, NULL, 0 },
    { "videoformat",          required_argument, NULL, 0 },
    { "range",                required_argument, NULL, OPT_RANGE },
    { "colorprim",            required_argument, NULL, 0 },
    { "transfer",             required_argument, NULL, 0 },
    { "colormatrix",          required_argument, NULL, 0 },
    { "chromaloc",            required_argument, NULL, 0 },
    { "force-cfr",            no_argument,       NULL, 0 },
    { "tcfile-in",            required_argument, NULL, OPT_TCFILE_IN },
    { "tcfile-out",           required_argument, NULL, OPT_TCFILE_OUT },
    { "timebase",             required_argument, NULL, OPT_TIMEBASE },
    { "pic-struct",           no_argument,       NULL, 0 },
    { "crop-rect",            required_argument, NULL, 0 },
    { "nal-hrd",              required_argument, NULL, 0 },
    { "pulldown",             required_argument, NULL, OPT_PULLDOWN },
    { "fake-interlaced",      no_argument,       NULL, 0 },
    { "frame-packing",        required_argument, NULL, 0 },
    { "mastering-display",    required_argument, NULL, 0 },
    { "cll",                  required_argument, NULL, 0 },
    { "alternative-transfer", required_argument, NULL, 0 },
    { "vf",                   required_argument, NULL, OPT_VIDEO_FILTER },
    { "video-filter",         required_argument, NULL, OPT_VIDEO_FILTER },
    { "input-fmt",            required_argument, NULL, OPT_INPUT_FMT },
    { "input-res",            required_argument, NULL, OPT_INPUT_RES },
    { "input-csp",            required_argument, NULL, OPT_INPUT_CSP },
    { "input-depth",          required_argument, NULL, OPT_INPUT_DEPTH },
    { "output-depth",         required_argument, NULL, OPT_OUTPUT_DEPTH },
    { "dts-compress",         no_argument,       NULL, OPT_DTS_COMPRESSION },
    { "output-csp",           required_argument, NULL, OPT_OUTPUT_CSP },
    { "input-range",          required_argument, NULL, OPT_INPUT_RANGE },
    { "stitchable",           no_argument,       NULL, 0 },
    { "filler",               no_argument,       NULL, 0 },
    { NULL,                   0,                 NULL, 0 }
};

static int select_output( const char *muxer, char *filename, x264_param_t *param )
{
    const char *ext = get_filename_extension( filename );
    if( !strcmp( filename, "-" ) || strcasecmp( muxer, "auto" ) )
        ext = muxer;

    if( !strcasecmp( ext, "mp4" ) )
    {
#if HAVE_GPAC || HAVE_LSMASH
        cli_output = mp4_output;
        param->b_annexb = 0;
        param->b_repeat_headers = 0;
        if( param->i_nal_hrd == X264_NAL_HRD_CBR )
        {
            x264_cli_log( "x264", X264_LOG_WARNING, "cbr nal-hrd is not compatible with mp4\n" );
            param->i_nal_hrd = X264_NAL_HRD_VBR;
        }
#else
        x264_cli_log( "x264", X264_LOG_ERROR, "not compiled with MP4 output support\n" );
        return -1;
#endif
    }
    else if( !strcasecmp( ext, "mkv" ) )
    {
        cli_output = mkv_output;
        param->b_annexb = 0;
        param->b_repeat_headers = 0;
    }
    else if( !strcasecmp( ext, "flv" ) )
    {
        cli_output = flv_output;
        param->b_annexb = 0;
        param->b_repeat_headers = 0;
    }
    else
        cli_output = raw_output;
    return 0;
}

static int select_input( const char *demuxer, char *used_demuxer, char *filename,
                         hnd_t *p_handle, video_info_t *info, cli_input_opt_t *opt )
{
    int b_auto = !strcasecmp( demuxer, "auto" );
    const char *ext = b_auto ? get_filename_extension( filename ) : "";
    int b_regular = strcmp( filename, "-" );
    if( !b_regular && b_auto )
        ext = "raw";
    b_regular = b_regular && x264_is_regular_file_path( filename );
    if( b_regular )
    {
        FILE *f = x264_fopen( filename, "r" );
        if( f )
        {
            b_regular = x264_is_regular_file( f );
            fclose( f );
        }
    }
    const char *module = b_auto ? ext : demuxer;

    if( !strcasecmp( module, "avs" ) || !strcasecmp( ext, "d2v" ) || !strcasecmp( ext, "dga" ) )
    {
#if HAVE_AVS
        cli_input = avs_input;
        module = "avs";
#else
        x264_cli_log( "x264", X264_LOG_ERROR, "not compiled with AVS input support\n" );
        return -1;
#endif
    }
    else if( !strcasecmp( module, "y4m" ) )
        cli_input = y4m_input;
    else if( !strcasecmp( module, "raw" ) || !strcasecmp( ext, "yuv" ) )
        cli_input = raw_input;
    else
    {
#if HAVE_FFMS
        if( b_regular && (b_auto || !strcasecmp( demuxer, "ffms" )) &&
            !ffms_input.open_file( filename, p_handle, info, opt ) )
        {
            module = "ffms";
            b_auto = 0;
            cli_input = ffms_input;
        }
#endif
#if HAVE_LAVF
        if( (b_auto || !strcasecmp( demuxer, "lavf" )) &&
            !lavf_input.open_file( filename, p_handle, info, opt ) )
        {
            module = "lavf";
            b_auto = 0;
            cli_input = lavf_input;
        }
#endif
#if HAVE_AVS
        if( b_regular && (b_auto || !strcasecmp( demuxer, "avs" )) &&
            !avs_input.open_file( filename, p_handle, info, opt ) )
        {
            module = "avs";
            b_auto = 0;
            cli_input = avs_input;
        }
#endif
        if( b_auto && !raw_input.open_file( filename, p_handle, info, opt ) )
        {
            module = "raw";
            b_auto = 0;
            cli_input = raw_input;
        }

        FAIL_IF_ERROR( !(*p_handle), "could not open input file `%s' via any method!\n", filename );
    }
    strcpy( used_demuxer, module );

    return 0;
}

static int init_vid_filters( char *sequence, hnd_t *handle, video_info_t *info, x264_param_t *param, int output_csp )
{
    x264_register_vid_filters();

    /* initialize baseline filters */
    if( x264_init_vid_filter( "source", handle, &filter, info, param, NULL ) ) /* wrap demuxer into a filter */
        return -1;
    if( x264_init_vid_filter( "resize", handle, &filter, info, param, "normcsp" ) ) /* normalize csps to be of a known/supported format */
        return -1;
    if( x264_init_vid_filter( "fix_vfr_pts", handle, &filter, info, param, NULL ) ) /* fix vfr pts */
        return -1;

    /* parse filter chain */
    for( char *p = sequence; p && *p; )
    {
        int tok_len = strcspn( p, "/" );
        int p_len = strlen( p );
        p[tok_len] = 0;
        int name_len = strcspn( p, ":" );
        p[name_len] = 0;
        name_len += name_len != tok_len;
        if( x264_init_vid_filter( p, handle, &filter, info, param, p + name_len ) )
            return -1;
        p += X264_MIN( tok_len+1, p_len );
    }

    /* force end result resolution */
    if( !param->i_width && !param->i_height )
    {
        param->i_height = info->height;
        param->i_width  = info->width;
    }
    /* force the output csp to what the user specified (or the default) */
    param->i_csp = info->csp;
    int csp = info->csp & X264_CSP_MASK;
    if( output_csp == X264_CSP_I400 && csp != X264_CSP_I400 )
        param->i_csp = X264_CSP_I400;
    else if( output_csp == X264_CSP_I420 && (csp < X264_CSP_I420 || csp >= X264_CSP_I422) )
        param->i_csp = X264_CSP_I420;
    else if( output_csp == X264_CSP_I422 && (csp < X264_CSP_I422 || csp >= X264_CSP_I444) )
        param->i_csp = X264_CSP_I422;
    else if( output_csp == X264_CSP_I444 && (csp < X264_CSP_I444 || csp >= X264_CSP_BGR) )
        param->i_csp = X264_CSP_I444;
    else if( output_csp == X264_CSP_RGB && (csp < X264_CSP_BGR || csp > X264_CSP_RGB) )
        param->i_csp = X264_CSP_RGB;
    param->i_csp |= info->csp & X264_CSP_HIGH_DEPTH;
    /* if the output range is not forced, assign it to the input one now */
    if( param->vui.b_fullrange == RANGE_AUTO )
        param->vui.b_fullrange = info->fullrange;

    if( x264_init_vid_filter( "resize", handle, &filter, info, param, NULL ) )
        return -1;

    char args[20], name[20];
    sprintf( args, "bit_depth=%d", param->i_bitdepth );
    sprintf( name, "depth_%d", param->i_bitdepth );

    if( x264_init_vid_filter( name, handle, &filter, info, param, args ) )
        return -1;

    return 0;
}

static int parse_enum_name( const char *arg, const char * const *names, const char **dst )
{
    for( int i = 0; names[i]; i++ )
        if( *names[i] && !strcasecmp( arg, names[i] ) )
        {
            *dst = names[i];
            return 0;
        }
    return -1;
}

static int parse_enum_value( const char *arg, const char * const *names, int *dst )
{
    for( int i = 0; names[i]; i++ )
        if( *names[i] && !strcasecmp( arg, names[i] ) )
        {
            *dst = i;
            return 0;
        }
    return -1;
}

static int parse( int argc, char **argv, x264_param_t *param, cli_opt_t *opt )
{
    char *input_filename = NULL;
    const char *demuxer = x264_demuxer_names[0];
    char *output_filename = NULL;
    const char *muxer = x264_muxer_names[0];
    char *tcfile_name = NULL;
    x264_param_t defaults;
    char *profile = NULL;
    char *vid_filters = NULL;
    int b_thread_input = 0;
    int b_turbo = 1;
    int b_user_ref = 0;
    int b_user_fps = 0;
    int b_user_interlaced = 0;
    cli_input_opt_t input_opt;
    cli_output_opt_t output_opt;
    char *preset = NULL;
    char *tune = NULL;

    /* Presets are applied before all other options. */
    for( optind = 0;; )
    {
        int c = getopt_long( argc, argv, short_options, long_options, NULL );
        if( c == -1 )
            break;
        if( c == OPT_PRESET )
            preset = optarg;
        if( c == OPT_TUNE )
            tune = optarg;
        else if( c == '?' )
            return -1;
    }

    if( preset && !strcasecmp( preset, "placebo" ) )
        b_turbo = 0;

    if( (preset || tune) && x264_param_default_preset( param, preset, tune ) < 0 )
        return -1;

    x264_param_default( &defaults );
    cli_log_level = defaults.i_log_level;

    memset( &input_opt, 0, sizeof(cli_input_opt_t) );
    memset( &output_opt, 0, sizeof(cli_output_opt_t) );
    input_opt.bit_depth = 8;
    input_opt.input_range = input_opt.output_range = param->vui.b_fullrange = RANGE_AUTO;
    int output_csp = defaults.i_csp;
    opt->b_progress = 1;

    /* Parse command line options */
    for( optind = 0;; )
    {
        int b_error = 0;
        int long_options_index = -1;

        int c = getopt_long( argc, argv, short_options, long_options, &long_options_index );

        if( c == -1 )
        {
            break;
        }

        switch( c )
        {
            case 'h':
                help( &defaults, 0 );
                exit(0);
            case OPT_LONGHELP:
                help( &defaults, 1 );
                exit(0);
            case OPT_FULLHELP:
                help( &defaults, 2 );
                exit(0);
            case 'V':
                print_version_info();
                exit(0);
            case OPT_FRAMES:
                param->i_frame_total = X264_MAX( atoi( optarg ), 0 );
                break;
            case OPT_SEEK:
                opt->i_seek = X264_MAX( atoi( optarg ), 0 );
                break;
            case 'o':
                output_filename = optarg;
                break;
            case OPT_MUXER:
                FAIL_IF_ERROR( parse_enum_name( optarg, x264_muxer_names, &muxer ), "Unknown muxer `%s'\n", optarg );
                break;
            case OPT_DEMUXER:
                FAIL_IF_ERROR( parse_enum_name( optarg, x264_demuxer_names, &demuxer ), "Unknown demuxer `%s'\n", optarg );
                break;
            case OPT_INDEX:
                input_opt.index_file = optarg;
                break;
            case OPT_QPFILE:
                opt->qpfile = x264_fopen( optarg, "rb" );
                FAIL_IF_ERROR( !opt->qpfile, "can't open qpfile `%s'\n", optarg );
                if( !x264_is_regular_file( opt->qpfile ) )
                {
                    x264_cli_log( "x264", X264_LOG_ERROR, "qpfile incompatible with non-regular file `%s'\n", optarg );
                    fclose( opt->qpfile );
                    return -1;
                }
                break;
            case OPT_THREAD_INPUT:
                b_thread_input = 1;
                break;
            case OPT_QUIET:
                cli_log_level = param->i_log_level = X264_LOG_NONE;
                break;
            case 'v':
                cli_log_level = param->i_log_level = X264_LOG_DEBUG;
                break;
            case OPT_LOG_LEVEL:
                if( !parse_enum_value( optarg, x264_log_level_names, &cli_log_level ) )
                    cli_log_level += X264_LOG_NONE;
                else
                    cli_log_level = atoi( optarg );
                param->i_log_level = cli_log_level;
                break;
            case OPT_NOPROGRESS:
                opt->b_progress = 0;
                break;
            case OPT_TUNE:
            case OPT_PRESET:
                break;
            case OPT_PROFILE:
                profile = optarg;
                break;
            case OPT_SLOWFIRSTPASS:
                b_turbo = 0;
                break;
            case 'r':
                b_user_ref = 1;
                goto generic_option;
            case OPT_FPS:
                b_user_fps = 1;
                param->b_vfr_input = 0;
                goto generic_option;
            case OPT_INTERLACED:
                b_user_interlaced = 1;
                goto generic_option;
            case OPT_TCFILE_IN:
                tcfile_name = optarg;
                break;
            case OPT_TCFILE_OUT:
                opt->tcfile_out = x264_fopen( optarg, "wb" );
                FAIL_IF_ERROR( !opt->tcfile_out, "can't open `%s'\n", optarg );
                break;
            case OPT_TIMEBASE:
                input_opt.timebase = optarg;
                break;
            case OPT_PULLDOWN:
                FAIL_IF_ERROR( parse_enum_value( optarg, x264_pulldown_names, &opt->i_pulldown ), "Unknown pulldown `%s'\n", optarg );
                break;
            case OPT_VIDEO_FILTER:
                vid_filters = optarg;
                break;
            case OPT_INPUT_FMT:
                input_opt.format = optarg;
                break;
            case OPT_INPUT_RES:
                input_opt.resolution = optarg;
                break;
            case OPT_INPUT_CSP:
                input_opt.colorspace = optarg;
                break;
            case OPT_INPUT_DEPTH:
                input_opt.bit_depth = atoi( optarg );
                break;
            case OPT_OUTPUT_DEPTH:
                param->i_bitdepth = atoi( optarg );
                break;
            case OPT_DTS_COMPRESSION:
                output_opt.use_dts_compress = 1;
                break;
            case OPT_OUTPUT_CSP:
                FAIL_IF_ERROR( parse_enum_value( optarg, x264_output_csp_names, &output_csp ), "Unknown output csp `%s'\n", optarg );
                // correct the parsed value to the libx264 csp value
#if X264_CHROMA_FORMAT
                static const uint8_t output_csp_fix[] = { X264_CHROMA_FORMAT, X264_CSP_RGB };
#else
                static const uint8_t output_csp_fix[] = { X264_CSP_I400, X264_CSP_I420, X264_CSP_I422, X264_CSP_I444, X264_CSP_RGB };
#endif
                param->i_csp = output_csp = output_csp_fix[output_csp];
                break;
            case OPT_INPUT_RANGE:
                FAIL_IF_ERROR( parse_enum_value( optarg, x264_range_names, &input_opt.input_range ), "Unknown input range `%s'\n", optarg );
                input_opt.input_range += RANGE_AUTO;
                break;
            case OPT_RANGE:
                FAIL_IF_ERROR( parse_enum_value( optarg, x264_range_names, &param->vui.b_fullrange ), "Unknown range `%s'\n", optarg );
                input_opt.output_range = param->vui.b_fullrange += RANGE_AUTO;
                break;
            default:
generic_option:
            {
                if( long_options_index < 0 )
                {
                    for( int i = 0; long_options[i].name; i++ )
                        if( long_options[i].val == c )
                        {
                            long_options_index = i;
                            break;
                        }
                    if( long_options_index < 0 )
                    {
                        /* getopt_long already printed an error message */
                        return -1;
                    }
                }

                b_error |= x264_param_parse( param, long_options[long_options_index].name, optarg );
            }
        }

        if( b_error )
        {
            const char *name = long_options_index > 0 ? long_options[long_options_index].name : argv[optind-2];
            x264_cli_log( "x264", X264_LOG_ERROR, "invalid argument: %s = %s\n", name, optarg );
            return -1;
        }
    }

    /* If first pass mode is used, apply faster settings. */
    if( b_turbo )
        x264_param_apply_fastfirstpass( param );

    /* Apply profile restrictions. */
    if( x264_param_apply_profile( param, profile ) < 0 )
        return -1;

    /* Get the file name */
    FAIL_IF_ERROR( optind > argc - 1 || !output_filename, "No %s file. Run x264 --help for a list of options.\n",
                   optind > argc - 1 ? "input" : "output" );

    if( select_output( muxer, output_filename, param ) )
        return -1;
    FAIL_IF_ERROR( cli_output.open_file( output_filename, &opt->hout, &output_opt ), "could not open output file `%s'\n", output_filename );

    input_filename = argv[optind++];
    video_info_t info = {0};
    char demuxername[5];

    /* set info flags to be overwritten by demuxer as necessary. */
    info.csp        = param->i_csp;
    info.fps_num    = param->i_fps_num;
    info.fps_den    = param->i_fps_den;
    info.fullrange  = input_opt.input_range == RANGE_PC;
    info.interlaced = param->b_interlaced;
    if( param->vui.i_sar_width > 0 && param->vui.i_sar_height > 0 )
    {
        info.sar_width  = param->vui.i_sar_width;
        info.sar_height = param->vui.i_sar_height;
    }
    info.tff        = param->b_tff;
    info.vfr        = param->b_vfr_input;

    input_opt.seek = opt->i_seek;
    input_opt.progress = opt->b_progress;
    input_opt.output_csp = output_csp;

    if( select_input( demuxer, demuxername, input_filename, &opt->hin, &info, &input_opt ) )
        return -1;

    FAIL_IF_ERROR( !opt->hin && cli_input.open_file( input_filename, &opt->hin, &info, &input_opt ),
                   "could not open input file `%s'\n", input_filename );

    x264_reduce_fraction( &info.sar_width, &info.sar_height );
    x264_reduce_fraction( &info.fps_num, &info.fps_den );
    x264_cli_log( demuxername, X264_LOG_INFO, "%dx%d%c %u:%u @ %u/%u fps (%cfr)\n", info.width,
                  info.height, info.interlaced ? 'i' : 'p', info.sar_width, info.sar_height,
                  info.fps_num, info.fps_den, info.vfr ? 'v' : 'c' );

    FAIL_IF_ERROR( info.width <= 0 || info.height <= 0 ||
                   info.width > MAX_RESOLUTION || info.height > MAX_RESOLUTION,
                   "invalid width x height (%dx%d)\n", info.width, info.height );

    if( tcfile_name )
    {
        FAIL_IF_ERROR( b_user_fps, "--fps + --tcfile-in is incompatible.\n" );
        FAIL_IF_ERROR( timecode_input.open_file( tcfile_name, &opt->hin, &info, &input_opt ), "timecode input failed\n" );
        cli_input = timecode_input;
    }
    else FAIL_IF_ERROR( !info.vfr && input_opt.timebase, "--timebase is incompatible with cfr input\n" );

    /* init threaded input while the information about the input video is unaltered by filtering */
#if HAVE_THREAD
    const cli_input_t *thread_input;
    if( HAVE_BITDEPTH8 && param->i_bitdepth == 8 )
        thread_input = &thread_8_input;
    else if( HAVE_BITDEPTH10 && param->i_bitdepth == 10 )
        thread_input = &thread_10_input;
    else
        thread_input = NULL;

    if( thread_input && info.thread_safe && (b_thread_input || param->i_threads > 1
        || (param->i_threads == X264_THREADS_AUTO && x264_cpu_num_processors() > 1)) )
    {
        if( thread_input->open_file( NULL, &opt->hin, &info, NULL ) )
        {
            fprintf( stderr, "x264 [error]: threaded input failed\n" );
            return -1;
        }
        cli_input = *thread_input;
    }
#endif

    /* override detected values by those specified by the user */
    if( param->vui.i_sar_width > 0 && param->vui.i_sar_height > 0 )
    {
        info.sar_width  = param->vui.i_sar_width;
        info.sar_height = param->vui.i_sar_height;
    }
    if( b_user_fps )
    {
        info.fps_num = param->i_fps_num;
        info.fps_den = param->i_fps_den;
    }
    if( !info.vfr )
    {
        info.timebase_num = info.fps_den;
        info.timebase_den = info.fps_num;
    }
    if( !tcfile_name && input_opt.timebase )
    {
        uint64_t i_user_timebase_num;
        uint64_t i_user_timebase_den;
        int ret = sscanf( input_opt.timebase, "%"SCNu64"/%"SCNu64, &i_user_timebase_num, &i_user_timebase_den );
        FAIL_IF_ERROR( !ret, "invalid argument: timebase = %s\n", input_opt.timebase );
        if( ret == 1 )
        {
            i_user_timebase_num = info.timebase_num;
            i_user_timebase_den = strtoul( input_opt.timebase, NULL, 10 );
        }
        FAIL_IF_ERROR( i_user_timebase_num > UINT32_MAX || i_user_timebase_den > UINT32_MAX,
                       "timebase you specified exceeds H.264 maximum\n" );
        opt->timebase_convert_multiplier = ((double)i_user_timebase_den / info.timebase_den)
                                         * ((double)info.timebase_num / i_user_timebase_num);
        info.timebase_num = i_user_timebase_num;
        info.timebase_den = i_user_timebase_den;
        info.vfr = 1;
    }
    if( b_user_interlaced )
    {
        info.interlaced = param->b_interlaced;
        info.tff = param->b_tff;
    }
    if( input_opt.input_range != RANGE_AUTO )
        info.fullrange = input_opt.input_range;

    if( init_vid_filters( vid_filters, &opt->hin, &info, param, output_csp ) )
        return -1;

    /* set param flags from the post-filtered video */
    param->b_vfr_input = info.vfr;
    param->i_fps_num = info.fps_num;
    param->i_fps_den = info.fps_den;
    param->i_timebase_num = info.timebase_num;
    param->i_timebase_den = info.timebase_den;
    param->vui.i_sar_width  = info.sar_width;
    param->vui.i_sar_height = info.sar_height;

    info.num_frames = X264_MAX( info.num_frames - opt->i_seek, 0 );
    if( (!info.num_frames || param->i_frame_total < info.num_frames)
        && param->i_frame_total > 0 )
        info.num_frames = param->i_frame_total;
    param->i_frame_total = info.num_frames;

    if( !b_user_interlaced && info.interlaced )
    {
#if HAVE_INTERLACED
        x264_cli_log( "x264", X264_LOG_WARNING, "input appears to be interlaced, enabling %cff interlaced mode.\n"
                      "                If you want otherwise, use --no-interlaced or --%cff\n",
                      info.tff ? 't' : 'b', info.tff ? 'b' : 't' );
        param->b_interlaced = 1;
        param->b_tff = !!info.tff;
#else
        x264_cli_log( "x264", X264_LOG_WARNING, "input appears to be interlaced, but not compiled with interlaced support\n" );
#endif
    }
    /* if the user never specified the output range and the input is now rgb, default it to pc */
    int csp = param->i_csp & X264_CSP_MASK;
    if( csp >= X264_CSP_BGR && csp <= X264_CSP_RGB )
    {
        if( input_opt.output_range == RANGE_AUTO )
            param->vui.b_fullrange = RANGE_PC;
        /* otherwise fail if they specified tv */
        FAIL_IF_ERROR( !param->vui.b_fullrange, "RGB must be PC range" );
    }

    /* Automatically reduce reference frame count to match the user's target level
     * if the user didn't explicitly set a reference frame count. */
    if( !b_user_ref )
    {
        int mbs = (((param->i_width)+15)>>4) * (((param->i_height)+15)>>4);
        for( int i = 0; x264_levels[i].level_idc != 0; i++ )
            if( param->i_level_idc == x264_levels[i].level_idc )
            {
                while( mbs * param->i_frame_reference > x264_levels[i].dpb && param->i_frame_reference > 1 )
                    param->i_frame_reference--;
                break;
            }
    }


    return 0;
}

static void parse_qpfile( cli_opt_t *opt, x264_picture_t *pic, int i_frame )
{
    int num = -1;
    char type;
    while( num < i_frame )
    {
        int64_t file_pos = ftell( opt->qpfile );
        int qp = -1;
        int ret = fscanf( opt->qpfile, "%d %c%*[ \t]%d\n", &num, &type, &qp );
        pic->i_type = X264_TYPE_AUTO;
        pic->i_qpplus1 = X264_QP_AUTO;
        if( num > i_frame || ret == EOF )
        {
            if( file_pos < 0 || fseek( opt->qpfile, file_pos, SEEK_SET ) )
            {
                x264_cli_log( "x264", X264_LOG_ERROR, "qpfile seeking failed\n" );
                fclose( opt->qpfile );
                opt->qpfile = NULL;
            }
            break;
        }
        if( num < i_frame && ret >= 2 )
            continue;
        if( ret == 3 && qp >= 0 )
            pic->i_qpplus1 = qp+1;
        if     ( type == 'I' ) pic->i_type = X264_TYPE_IDR;
        else if( type == 'i' ) pic->i_type = X264_TYPE_I;
        else if( type == 'K' ) pic->i_type = X264_TYPE_KEYFRAME;
        else if( type == 'P' ) pic->i_type = X264_TYPE_P;
        else if( type == 'B' ) pic->i_type = X264_TYPE_BREF;
        else if( type == 'b' ) pic->i_type = X264_TYPE_B;
        else ret = 0;
        if( ret < 2 || qp < -1 || qp > QP_MAX )
        {
            x264_cli_log( "x264", X264_LOG_ERROR, "can't parse qpfile for frame %d\n", i_frame );
            fclose( opt->qpfile );
            opt->qpfile = NULL;
            break;
        }
    }
}

static int encode_frame( x264_t *h, hnd_t hout, x264_picture_t *pic, int64_t *last_dts )
{
    x264_picture_t pic_out;
    x264_nal_t *nal;
    int i_nal;
    int i_frame_size = 0;

    i_frame_size = x264_encoder_encode( h, &nal, &i_nal, pic, &pic_out );

    FAIL_IF_ERROR( i_frame_size < 0, "x264_encoder_encode failed\n" );

    if( i_frame_size )
    {
        i_frame_size = cli_output.write_frame( hout, nal[0].p_payload, i_frame_size, &pic_out );
        *last_dts = pic_out.i_dts;
    }

    return i_frame_size;
}

static int64_t print_status( int64_t i_start, int64_t i_previous, int i_frame, int i_frame_total, int64_t i_file, x264_param_t *param, int64_t last_ts )
{
    char buf[200];
    int64_t i_time = x264_mdate();
    if( i_previous && i_time - i_previous < UPDATE_INTERVAL )
        return i_previous;
    int64_t i_elapsed = i_time - i_start;
    double fps = i_elapsed > 0 ? i_frame * 1000000. / i_elapsed : 0;
    double bitrate;
    if( last_ts )
        bitrate = (double) i_file * 8 / ( (double) last_ts * 1000 * param->i_timebase_num / param->i_timebase_den );
    else
        bitrate = (double) i_file * 8 / ( (double) 1000 * param->i_fps_den / param->i_fps_num );
    if( i_frame_total )
    {
        int eta = i_elapsed * (i_frame_total - i_frame) / ((int64_t)i_frame * 1000000);
        sprintf( buf, "x264 [%.1f%%] %d/%d frames, %.2f fps, %.2f kb/s, eta %d:%02d:%02d",
                 100. * i_frame / i_frame_total, i_frame, i_frame_total, fps, bitrate,
                 eta/3600, (eta/60)%60, eta%60 );
    }
    else
        sprintf( buf, "x264 %d frames: %.2f fps, %.2f kb/s", i_frame, fps, bitrate );
    fprintf( stderr, "%s  \r", buf+5 );
    x264_cli_set_console_title( buf );
    fflush( stderr ); // needed in windows
    return i_time;
}

static void convert_cli_to_lib_pic( x264_picture_t *lib, cli_pic_t *cli )
{
    memcpy( lib->img.i_stride, cli->img.stride, sizeof(cli->img.stride) );
    memcpy( lib->img.plane, cli->img.plane, sizeof(cli->img.plane) );
    lib->img.i_plane = cli->img.planes;
    lib->img.i_csp = cli->img.csp;
    lib->i_pts = cli->pts;
}

#define FAIL_IF_ERROR2( cond, ... )\
do\
{\
    if( cond )\
    {\
        x264_cli_log( "x264", X264_LOG_ERROR, __VA_ARGS__ );\
        retval = -1;\
        goto fail;\
    }\
} while( 0 )

static int encode( x264_param_t *param, cli_opt_t *opt )
{
    x264_t *h = NULL;
    x264_picture_t pic;
    cli_pic_t cli_pic;
    const cli_pulldown_t *pulldown = NULL; // shut up gcc

    int     i_frame = 0;
    int     i_frame_output = 0;
    int64_t i_end, i_previous = 0, i_start = 0;
    int64_t i_file = 0;
    int     i_frame_size;
    int64_t last_dts = 0;
    int64_t prev_dts = 0;
    int64_t first_dts = 0;
#   define  MAX_PTS_WARNING 3 /* arbitrary */
    int     pts_warning_cnt = 0;
    int64_t largest_pts = -1;
    int64_t second_largest_pts = -1;
    int64_t ticks_per_frame;
    double  duration;
    double  pulldown_pts = 0;
    int     retval = 0;

    opt->b_progress &= param->i_log_level < X264_LOG_DEBUG;

    /* set up pulldown */
    if( opt->i_pulldown && !param->b_vfr_input )
    {
        param->b_pulldown = 1;
        param->b_pic_struct = 1;
        pulldown = &pulldown_values[opt->i_pulldown];
        param->i_timebase_num = param->i_fps_den;
        FAIL_IF_ERROR2( fmod( param->i_fps_num * pulldown->fps_factor, 1 ),
                        "unsupported framerate for chosen pulldown\n" );
        param->i_timebase_den = param->i_fps_num * pulldown->fps_factor;
    }

    h = x264_encoder_open( param );
    FAIL_IF_ERROR2( !h, "x264_encoder_open failed\n" );

    x264_encoder_parameters( h, param );

    FAIL_IF_ERROR2( cli_output.set_param( opt->hout, param ), "can't set outfile param\n" );

    i_start = x264_mdate();

    /* ticks/frame = ticks/second / frames/second */
    ticks_per_frame = (int64_t)param->i_timebase_den * param->i_fps_den / param->i_timebase_num / param->i_fps_num;
    FAIL_IF_ERROR2( ticks_per_frame < 1 && !param->b_vfr_input, "ticks_per_frame invalid: %"PRId64"\n", ticks_per_frame );
    ticks_per_frame = X264_MAX( ticks_per_frame, 1 );

    if( !param->b_repeat_headers )
    {
        // Write SPS/PPS/SEI
        x264_nal_t *headers;
        int i_nal;

        FAIL_IF_ERROR2( x264_encoder_headers( h, &headers, &i_nal ) < 0, "x264_encoder_headers failed\n" );
        FAIL_IF_ERROR2( (i_file = cli_output.write_headers( opt->hout, headers )) < 0, "error writing headers to output file\n" );
    }

    if( opt->tcfile_out )
        fprintf( opt->tcfile_out, "# timecode format v2\n" );

    /* Encode frames */
    for( ; !b_ctrl_c && (i_frame < param->i_frame_total || !param->i_frame_total); i_frame++ )
    {
        if( filter.get_frame( opt->hin, &cli_pic, i_frame + opt->i_seek ) )
            break;
        x264_picture_init( &pic );
        convert_cli_to_lib_pic( &pic, &cli_pic );

        if( !param->b_vfr_input )
            pic.i_pts = i_frame;

        if( opt->i_pulldown && !param->b_vfr_input )
        {
            pic.i_pic_struct = pulldown->pattern[ i_frame % pulldown->mod ];
            pic.i_pts = (int64_t)( pulldown_pts + 0.5 );
            pulldown_pts += pulldown_frame_duration[pic.i_pic_struct];
        }
        else if( opt->timebase_convert_multiplier )
            pic.i_pts = (int64_t)( pic.i_pts * opt->timebase_convert_multiplier + 0.5 );

        if( pic.i_pts <= largest_pts )
        {
            if( cli_log_level >= X264_LOG_DEBUG || pts_warning_cnt < MAX_PTS_WARNING )
                x264_cli_log( "x264", X264_LOG_WARNING, "non-strictly-monotonic pts at frame %d (%"PRId64" <= %"PRId64")\n",
                             i_frame, pic.i_pts, largest_pts );
            else if( pts_warning_cnt == MAX_PTS_WARNING )
                x264_cli_log( "x264", X264_LOG_WARNING, "too many nonmonotonic pts warnings, suppressing further ones\n" );
            pts_warning_cnt++;
            pic.i_pts = largest_pts + ticks_per_frame;
        }

        second_largest_pts = largest_pts;
        largest_pts = pic.i_pts;
        if( opt->tcfile_out )
            fprintf( opt->tcfile_out, "%.6f\n", pic.i_pts * ((double)param->i_timebase_num / param->i_timebase_den) * 1e3 );

        if( opt->qpfile )
            parse_qpfile( opt, &pic, i_frame + opt->i_seek );

        prev_dts = last_dts;
        i_frame_size = encode_frame( h, opt->hout, &pic, &last_dts );
        if( i_frame_size < 0 )
        {
            b_ctrl_c = 1; /* lie to exit the loop */
            retval = -1;
        }
        else if( i_frame_size )
        {
            i_file += i_frame_size;
            i_frame_output++;
            if( i_frame_output == 1 )
                first_dts = prev_dts = last_dts;
        }

        if( filter.release_frame( opt->hin, &cli_pic, i_frame + opt->i_seek ) )
            break;

        /* update status line (up to 1000 times per input file) */
        if( opt->b_progress && i_frame_output )
            i_previous = print_status( i_start, i_previous, i_frame_output, param->i_frame_total, i_file, param, 2 * last_dts - prev_dts - first_dts );
    }
    /* Flush delayed frames */
    while( !b_ctrl_c && x264_encoder_delayed_frames( h ) )
    {
        prev_dts = last_dts;
        i_frame_size = encode_frame( h, opt->hout, NULL, &last_dts );
        if( i_frame_size < 0 )
        {
            b_ctrl_c = 1; /* lie to exit the loop */
            retval = -1;
        }
        else if( i_frame_size )
        {
            i_file += i_frame_size;
            i_frame_output++;
            if( i_frame_output == 1 )
                first_dts = prev_dts = last_dts;
        }
        if( opt->b_progress && i_frame_output )
            i_previous = print_status( i_start, i_previous, i_frame_output, param->i_frame_total, i_file, param, 2 * last_dts - prev_dts - first_dts );
    }
fail:
    if( pts_warning_cnt >= MAX_PTS_WARNING && cli_log_level < X264_LOG_DEBUG )
        x264_cli_log( "x264", X264_LOG_WARNING, "%d suppressed nonmonotonic pts warnings\n", pts_warning_cnt-MAX_PTS_WARNING );

    /* duration algorithm fails when only 1 frame is output */
    if( i_frame_output == 1 )
        duration = (double)param->i_fps_den / param->i_fps_num;
    else if( b_ctrl_c )
        duration = (double)(2 * last_dts - prev_dts - first_dts) * param->i_timebase_num / param->i_timebase_den;
    else
        duration = (double)(2 * largest_pts - second_largest_pts) * param->i_timebase_num / param->i_timebase_den;

    i_end = x264_mdate();
    /* Erase progress indicator before printing encoding stats. */
    if( opt->b_progress )
        fprintf( stderr, "                                                                               \r" );
    if( h )
        x264_encoder_close( h );
    fprintf( stderr, "\n" );

    if( b_ctrl_c )
        fprintf( stderr, "aborted at input frame %d, output frame %d\n", opt->i_seek + i_frame, i_frame_output );

    cli_output.close_file( opt->hout, largest_pts, second_largest_pts );
    opt->hout = NULL;

    if( i_frame_output > 0 )
    {
        double fps = (double)i_frame_output * (double)1000000 /
                     (double)( i_end - i_start );

        fprintf( stderr, "encoded %d frames, %.2f fps, %.2f kb/s\n", i_frame_output, fps,
                 (double) i_file * 8 / ( 1000 * duration ) );
    }

    return retval;
}
