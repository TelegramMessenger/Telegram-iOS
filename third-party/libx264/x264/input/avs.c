/*****************************************************************************
 * avs.c: avisynth input
 *****************************************************************************
 * Copyright (C) 2009-2022 x264 project
 *
 * Authors: Steven Walters <kemuri9@gmail.com>
 *          Anton Mitrofanov <BugMaster@narod.ru>
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

#include "input.h"

#if USE_AVXSYNTH
#include <dlfcn.h>
#if SYS_MACOSX
#define avs_open() dlopen( "libavxsynth.dylib", RTLD_NOW )
#else
#define avs_open() dlopen( "libavxsynth.so", RTLD_NOW )
#endif
#define avs_close dlclose
#define avs_address dlsym
#else
#define avs_open() LoadLibraryW( L"avisynth" )
#define avs_close FreeLibrary
#define avs_address GetProcAddress
#endif

#define AVSC_NO_DECLSPEC
#undef EXTERN_C
#if USE_AVXSYNTH
#include "extras/avxsynth_c.h"
#else
#include "extras/avisynth_c.h"
#endif
#define AVSC_DECLARE_FUNC(name) name##_func name

#define FAIL_IF_ERROR( cond, ... ) FAIL_IF_ERR( cond, "avs", __VA_ARGS__ )

/* AVS uses a versioned interface to control backwards compatibility */
/* YV12 support is required, which was added in 2.5 */
#define AVS_INTERFACE_25 2

#if HAVE_SWSCALE
#include <libavutil/pixfmt.h>
#endif

/* maximum size of the sequence of filters to try on non script files */
#define AVS_MAX_SEQUENCE 5

#define LOAD_AVS_FUNC(name, continue_on_fail)\
{\
    h->func.name = (void*)avs_address( h->library, #name );\
    if( !continue_on_fail && !h->func.name )\
        goto fail;\
}

#define LOAD_AVS_FUNC_ALIAS(name, alias, continue_on_fail)\
{\
    if( !h->func.name )\
        h->func.name = (void*)avs_address( h->library, alias );\
    if( !continue_on_fail && !h->func.name )\
        goto fail;\
}

typedef struct
{
    AVS_Clip *clip;
    AVS_ScriptEnvironment *env;
    void *library;
    int num_frames;
    struct
    {
        AVSC_DECLARE_FUNC( avs_clip_get_error );
        AVSC_DECLARE_FUNC( avs_create_script_environment );
        AVSC_DECLARE_FUNC( avs_delete_script_environment );
        AVSC_DECLARE_FUNC( avs_get_error );
        AVSC_DECLARE_FUNC( avs_get_frame );
        AVSC_DECLARE_FUNC( avs_get_video_info );
        AVSC_DECLARE_FUNC( avs_function_exists );
        AVSC_DECLARE_FUNC( avs_invoke );
        AVSC_DECLARE_FUNC( avs_release_clip );
        AVSC_DECLARE_FUNC( avs_release_value );
        AVSC_DECLARE_FUNC( avs_release_video_frame );
        AVSC_DECLARE_FUNC( avs_take_clip );
#if !USE_AVXSYNTH
        // AviSynth+ extension
        AVSC_DECLARE_FUNC( avs_is_rgb48 );
        AVSC_DECLARE_FUNC( avs_is_rgb64 );
        AVSC_DECLARE_FUNC( avs_is_yuv444p16 );
        AVSC_DECLARE_FUNC( avs_is_yuv422p16 );
        AVSC_DECLARE_FUNC( avs_is_yuv420p16 );
        AVSC_DECLARE_FUNC( avs_is_y16 );
        AVSC_DECLARE_FUNC( avs_is_yuv444ps );
        AVSC_DECLARE_FUNC( avs_is_yuv422ps );
        AVSC_DECLARE_FUNC( avs_is_yuv420ps );
        AVSC_DECLARE_FUNC( avs_is_y32 );
        AVSC_DECLARE_FUNC( avs_is_444 );
        AVSC_DECLARE_FUNC( avs_is_422 );
        AVSC_DECLARE_FUNC( avs_is_420 );
        AVSC_DECLARE_FUNC( avs_is_y );
        AVSC_DECLARE_FUNC( avs_is_yuva );
        AVSC_DECLARE_FUNC( avs_is_planar_rgb );
        AVSC_DECLARE_FUNC( avs_is_planar_rgba );
        AVSC_DECLARE_FUNC( avs_num_components );
        AVSC_DECLARE_FUNC( avs_component_size );
        AVSC_DECLARE_FUNC( avs_bits_per_component );
#endif
    } func;
} avs_hnd_t;

/* load the library and functions we require from it */
static int custom_avs_load_library( avs_hnd_t *h )
{
    h->library = avs_open();
    if( !h->library )
        return -1;
    LOAD_AVS_FUNC( avs_clip_get_error, 0 );
    LOAD_AVS_FUNC( avs_create_script_environment, 0 );
    LOAD_AVS_FUNC( avs_delete_script_environment, 1 );
    LOAD_AVS_FUNC( avs_get_error, 1 );
    LOAD_AVS_FUNC( avs_get_frame, 0 );
    LOAD_AVS_FUNC( avs_get_video_info, 0 );
    LOAD_AVS_FUNC( avs_function_exists, 0 );
    LOAD_AVS_FUNC( avs_invoke, 0 );
    LOAD_AVS_FUNC( avs_release_clip, 0 );
    LOAD_AVS_FUNC( avs_release_value, 0 );
    LOAD_AVS_FUNC( avs_release_video_frame, 0 );
    LOAD_AVS_FUNC( avs_take_clip, 0 );
#if !USE_AVXSYNTH
    // AviSynth+ extension
    LOAD_AVS_FUNC( avs_is_rgb48, 1 );
    LOAD_AVS_FUNC_ALIAS( avs_is_rgb48, "_avs_is_rgb48@4", 1 );
    LOAD_AVS_FUNC( avs_is_rgb64, 1 );
    LOAD_AVS_FUNC_ALIAS( avs_is_rgb64, "_avs_is_rgb64@4", 1 );
    LOAD_AVS_FUNC( avs_is_yuv444p16, 1 );
    LOAD_AVS_FUNC( avs_is_yuv422p16, 1 );
    LOAD_AVS_FUNC( avs_is_yuv420p16, 1 );
    LOAD_AVS_FUNC( avs_is_y16, 1 );
    LOAD_AVS_FUNC( avs_is_yuv444ps, 1 );
    LOAD_AVS_FUNC( avs_is_yuv422ps, 1 );
    LOAD_AVS_FUNC( avs_is_yuv420ps, 1 );
    LOAD_AVS_FUNC( avs_is_y32, 1 );
    LOAD_AVS_FUNC( avs_is_444, 1 );
    LOAD_AVS_FUNC( avs_is_422, 1 );
    LOAD_AVS_FUNC( avs_is_420, 1 );
    LOAD_AVS_FUNC( avs_is_y, 1 );
    LOAD_AVS_FUNC( avs_is_yuva, 1 );
    LOAD_AVS_FUNC( avs_is_planar_rgb, 1 );
    LOAD_AVS_FUNC( avs_is_planar_rgba, 1 );
    LOAD_AVS_FUNC( avs_num_components, 1 );
    LOAD_AVS_FUNC( avs_component_size, 1 );
    LOAD_AVS_FUNC( avs_bits_per_component, 1 );
#endif
    return 0;
fail:
    avs_close( h->library );
    h->library = NULL;
    return -1;
}

/* AvxSynth doesn't have yv24, yv16, yv411, or y8, so disable them. */
#if USE_AVXSYNTH
#define avs_is_yv24( vi ) (0)
#define avs_is_yv16( vi ) (0)
#define avs_is_yv411( vi ) (0)
#define avs_is_y8( vi ) (0)
/* AvxSynth doesn't support AviSynth+ pixel types. */
#define AVS_IS_AVISYNTHPLUS (0)
#define AVS_IS_420( vi ) (0)
#define AVS_IS_422( vi ) (0)
#define AVS_IS_444( vi ) (0)
#define AVS_IS_RGB48( vi ) (0)
#define AVS_IS_RGB64( vi ) (0)
#define AVS_IS_YUV420P16( vi ) (0)
#define AVS_IS_YUV422P16( vi ) (0)
#define AVS_IS_YUV444P16( vi ) (0)
#define AVS_IS_Y( vi ) (0)
#define AVS_IS_Y16( vi ) (0)
#else
#define AVS_IS_AVISYNTHPLUS (h->func.avs_is_420 && h->func.avs_is_422 && h->func.avs_is_444)
#define AVS_IS_420( vi ) (h->func.avs_is_420 ? h->func.avs_is_420( vi ) : avs_is_yv12( vi ))
#define AVS_IS_422( vi ) (h->func.avs_is_422 ? h->func.avs_is_422( vi ) : avs_is_yv16( vi ))
#define AVS_IS_444( vi ) (h->func.avs_is_444 ? h->func.avs_is_444( vi ) : avs_is_yv24( vi ))
#define AVS_IS_RGB48( vi ) (h->func.avs_is_rgb48 && h->func.avs_is_rgb48( vi ))
#define AVS_IS_RGB64( vi ) (h->func.avs_is_rgb64 && h->func.avs_is_rgb64( vi ))
#define AVS_IS_YUV420P16( vi ) (h->func.avs_is_yuv420p16 && h->func.avs_is_yuv420p16( vi ))
#define AVS_IS_YUV422P16( vi ) (h->func.avs_is_yuv422p16 && h->func.avs_is_yuv422p16( vi ))
#define AVS_IS_YUV444P16( vi ) (h->func.avs_is_yuv444p16 && h->func.avs_is_yuv444p16( vi ))
#define AVS_IS_Y( vi ) (h->func.avs_is_y ? h->func.avs_is_y( vi ) : avs_is_y8( vi ))
#define AVS_IS_Y16( vi ) (h->func.avs_is_y16 && h->func.avs_is_y16( vi ))
#endif

/* generate a filter sequence to try based on the filename extension */
static void avs_build_filter_sequence( char *filename_ext, const char *filter[AVS_MAX_SEQUENCE+1] )
{
    int i = 0;
#if USE_AVXSYNTH
    const char *all_purpose[] = { "FFVideoSource", 0 };
#else
    const char *all_purpose[] = { "FFmpegSource2", "DSS2", "DirectShowSource", 0 };
    if( !strcasecmp( filename_ext, "avi" ) )
        filter[i++] = "AVISource";
    if( !strcasecmp( filename_ext, "d2v" ) )
        filter[i++] = "MPEG2Source";
    if( !strcasecmp( filename_ext, "dga" ) )
        filter[i++] = "AVCSource";
#endif
    for( int j = 0; all_purpose[j] && i < AVS_MAX_SEQUENCE; j++ )
        filter[i++] = all_purpose[j];
}

static AVS_Value update_clip( avs_hnd_t *h, const AVS_VideoInfo **vi, AVS_Value res, AVS_Value release )
{
    h->func.avs_release_clip( h->clip );
    h->clip = h->func.avs_take_clip( res, h->env );
    h->func.avs_release_value( release );
    *vi = h->func.avs_get_video_info( h->clip );
    return res;
}

static float get_avs_version( avs_hnd_t *h )
{
/* AvxSynth has its version defined starting at 4.0, even though it's based on
   AviSynth 2.5.8. This is troublesome for get_avs_version and working around
   the new colorspaces in 2.6.  So if AvxSynth is detected, explicitly define
   the version as 2.58. */
#if USE_AVXSYNTH
    return 2.58f;
#else
    FAIL_IF_ERROR( !h->func.avs_function_exists( h->env, "VersionNumber" ), "VersionNumber does not exist\n" );
    AVS_Value ver = h->func.avs_invoke( h->env, "VersionNumber", avs_new_value_array( NULL, 0 ), NULL );
    FAIL_IF_ERROR( avs_is_error( ver ), "unable to determine avisynth version: %s\n", avs_as_error( ver ) );
    FAIL_IF_ERROR( !avs_is_float( ver ), "VersionNumber did not return a float value\n" );
    float ret = avs_as_float( ver );
    h->func.avs_release_value( ver );
    return ret;
#endif
}

#ifdef _WIN32
static char *utf16_to_ansi( const wchar_t *utf16 )
{
    BOOL invalid;
    int len = WideCharToMultiByte( CP_ACP, WC_NO_BEST_FIT_CHARS, utf16, -1, NULL, 0, NULL, &invalid );
    if( len && !invalid )
    {
        char *ansi = malloc( len * sizeof( char ) );
        if( ansi )
        {
            if( WideCharToMultiByte( CP_ACP, WC_NO_BEST_FIT_CHARS, utf16, -1, ansi, len, NULL, &invalid ) && !invalid )
                return ansi;
            free( ansi );
        }
    }
    return NULL;
}

static char *utf8_to_ansi( const char *filename )
{
    char *ansi = NULL;
    wchar_t *filename_utf16 = x264_utf8_to_utf16( filename );
    if( filename_utf16 )
    {
        /* Check if the filename already is valid ANSI. */
        if( !(ansi = utf16_to_ansi( filename_utf16 )) )
        {
            /* Check for a legacy 8.3 short filename. */
            int len = GetShortPathNameW( filename_utf16, NULL, 0 );
            if( len )
            {
                wchar_t *short_utf16 = malloc( len * sizeof( wchar_t ) );
                if( short_utf16 )
                {
                    if( GetShortPathNameW( filename_utf16, short_utf16, len ) )
                        ansi = utf16_to_ansi( short_utf16 );
                    free( short_utf16 );
                }
            }
        }
        free( filename_utf16 );
    }
    return ansi;
}
#endif

static int open_file( char *psz_filename, hnd_t *p_handle, video_info_t *info, cli_input_opt_t *opt )
{
    FILE *fh = x264_fopen( psz_filename, "r" );
    if( !fh )
        return -1;
    int b_regular = x264_is_regular_file( fh );
    fclose( fh );
    FAIL_IF_ERROR( !b_regular, "AVS input is incompatible with non-regular file `%s'\n", psz_filename );

    avs_hnd_t *h = calloc( 1, sizeof(avs_hnd_t) );
    if( !h )
        return -1;
    FAIL_IF_ERROR( custom_avs_load_library( h ), "failed to load avisynth\n" );
    h->env = h->func.avs_create_script_environment( AVS_INTERFACE_25 );
    if( h->func.avs_get_error )
    {
        const char *error = h->func.avs_get_error( h->env );
        FAIL_IF_ERROR( error, "%s\n", error );
    }
    float avs_version = get_avs_version( h );
    if( avs_version <= 0 )
        return -1;
    x264_cli_log( "avs", X264_LOG_DEBUG, "using avisynth version %.2f\n", avs_version );

#ifdef _WIN32
    /* Avisynth doesn't support Unicode filenames. */
    char *ansi_filename = utf8_to_ansi( psz_filename );
    FAIL_IF_ERROR( !ansi_filename, "invalid ansi filename\n" );
    AVS_Value arg = avs_new_value_string( ansi_filename );
#else
    AVS_Value arg = avs_new_value_string( psz_filename );
#endif

    AVS_Value res;
    char *filename_ext = get_filename_extension( psz_filename );

    if( !strcasecmp( filename_ext, "avs" ) )
    {
        res = h->func.avs_invoke( h->env, "Import", arg, NULL );
#ifdef _WIN32
        free( ansi_filename );
#endif
        FAIL_IF_ERROR( avs_is_error( res ), "%s\n", avs_as_error( res ) );
        /* check if the user is using a multi-threaded script and apply distributor if necessary.
           adapted from avisynth's vfw interface */
        AVS_Value mt_test = h->func.avs_invoke( h->env, "GetMTMode", avs_new_value_bool( 0 ), NULL );
        int mt_mode = avs_is_int( mt_test ) ? avs_as_int( mt_test ) : 0;
        h->func.avs_release_value( mt_test );
        if( mt_mode > 0 && mt_mode < 5 )
        {
            AVS_Value temp = h->func.avs_invoke( h->env, "Distributor", res, NULL );
            h->func.avs_release_value( res );
            res = temp;
        }
    }
    else /* non script file */
    {
        /* cycle through known source filters to find one that works */
        const char *filter[AVS_MAX_SEQUENCE+1] = { 0 };
        avs_build_filter_sequence( filename_ext, filter );
        int i;
        for( i = 0; filter[i]; i++ )
        {
            x264_cli_log( "avs", X264_LOG_INFO, "trying %s... ", filter[i] );
            if( !h->func.avs_function_exists( h->env, filter[i] ) )
            {
                x264_cli_printf( X264_LOG_INFO, "not found\n" );
                continue;
            }
            if( !strncasecmp( filter[i], "FFmpegSource", 12 ) )
            {
                x264_cli_printf( X264_LOG_INFO, "indexing... " );
                fflush( stderr );
            }
            res = h->func.avs_invoke( h->env, filter[i], arg, NULL );
            if( !avs_is_error( res ) )
            {
                x264_cli_printf( X264_LOG_INFO, "succeeded\n" );
                break;
            }
            x264_cli_printf( X264_LOG_INFO, "failed\n" );
        }
#ifdef _WIN32
        free( ansi_filename );
#endif
        FAIL_IF_ERROR( !filter[i], "unable to find source filter to open `%s'\n", psz_filename );
    }
    FAIL_IF_ERROR( !avs_is_clip( res ), "`%s' didn't return a video clip\n", psz_filename );
    h->clip = h->func.avs_take_clip( res, h->env );
    const AVS_VideoInfo *vi = h->func.avs_get_video_info( h->clip );
    FAIL_IF_ERROR( !avs_has_video( vi ), "`%s' has no video data\n", psz_filename );
    /* if the clip is made of fields instead of frames, call weave to make them frames */
    if( avs_is_field_based( vi ) )
    {
        x264_cli_log( "avs", X264_LOG_WARNING, "detected fieldbased (separated) input, weaving to frames\n" );
        AVS_Value tmp = h->func.avs_invoke( h->env, "Weave", res, NULL );
        FAIL_IF_ERROR( avs_is_error( tmp ), "couldn't weave fields into frames: %s\n", avs_as_error( tmp ) );
        res = update_clip( h, &vi, tmp, res );
        info->interlaced = 1;
        info->tff = avs_is_tff( vi );
    }
#if !HAVE_SWSCALE
    /* if swscale is not available, convert the CSP if necessary */
    FAIL_IF_ERROR( avs_version < 2.6f && (opt->output_csp == X264_CSP_I400 || opt->output_csp == X264_CSP_I422 || opt->output_csp == X264_CSP_I444),
                   "avisynth >= 2.6 is required for i400/i422/i444 output\n" );
    if( (opt->output_csp == X264_CSP_I400 && !AVS_IS_Y( vi )) ||
        (opt->output_csp == X264_CSP_I420 && !AVS_IS_420( vi )) ||
        (opt->output_csp == X264_CSP_I422 && !AVS_IS_422( vi )) ||
        (opt->output_csp == X264_CSP_I444 && !AVS_IS_444( vi )) ||
        (opt->output_csp == X264_CSP_RGB && !avs_is_rgb( vi )) )
    {
        const char *csp;
        if( AVS_IS_AVISYNTHPLUS )
        {
            csp = opt->output_csp == X264_CSP_I400 ? "Y" :
                  opt->output_csp == X264_CSP_I420 ? "YUV420" :
                  opt->output_csp == X264_CSP_I422 ? "YUV422" :
                  opt->output_csp == X264_CSP_I444 ? "YUV444" :
                  "RGB";
        }
        else
        {
            csp = opt->output_csp == X264_CSP_I400 ? "Y8" :
                  opt->output_csp == X264_CSP_I420 ? "YV12" :
                  opt->output_csp == X264_CSP_I422 ? "YV16" :
                  opt->output_csp == X264_CSP_I444 ? "YV24" :
                  "RGB";
        }
        x264_cli_log( "avs", X264_LOG_WARNING, "converting input clip to %s\n", csp );
        if( opt->output_csp != X264_CSP_I400 )
        {
            FAIL_IF_ERROR( opt->output_csp < X264_CSP_I444 && (vi->width&1),
                           "input clip width not divisible by 2 (%dx%d)\n", vi->width, vi->height );
            FAIL_IF_ERROR( opt->output_csp == X264_CSP_I420 && info->interlaced && (vi->height&3),
                           "input clip height not divisible by 4 (%dx%d)\n", vi->width, vi->height );
            FAIL_IF_ERROR( (opt->output_csp == X264_CSP_I420 || info->interlaced) && (vi->height&1),
                           "input clip height not divisible by 2 (%dx%d)\n", vi->width, vi->height );
        }
        char conv_func[16];
        snprintf( conv_func, sizeof(conv_func), "ConvertTo%s", csp );
        AVS_Value arg_arr[3];
        const char *arg_name[3];
        int arg_count = 1;
        arg_arr[0] = res;
        arg_name[0] = NULL;
        if( opt->output_csp != X264_CSP_I400 )
        {
            arg_arr[arg_count] = avs_new_value_bool( info->interlaced );
            arg_name[arg_count] = "interlaced";
            arg_count++;
        }
        /* if doing a rgb <-> yuv conversion then range is handled via 'matrix'. though it's only supported in 2.56+ */
        char matrix[7];
        if( avs_version >= 2.56f && ((opt->output_csp == X264_CSP_RGB && avs_is_yuv( vi )) || (opt->output_csp != X264_CSP_RGB && avs_is_rgb( vi ))) )
        {
            // if converting from yuv, then we specify the matrix for the input, otherwise use the output's.
            int use_pc_matrix = avs_is_yuv( vi ) ? opt->input_range == RANGE_PC : opt->output_range == RANGE_PC;
            snprintf( matrix, sizeof(matrix), "%s601", use_pc_matrix ? "PC." : "Rec" ); /* FIXME: use correct coefficients */
            arg_arr[arg_count] = avs_new_value_string( matrix );
            arg_name[arg_count] = "matrix";
            arg_count++;
            // notification that the input range has changed to the desired one
            opt->input_range = opt->output_range;
        }
        AVS_Value res2 = h->func.avs_invoke( h->env, conv_func, avs_new_value_array( arg_arr, arg_count ), arg_name );
        FAIL_IF_ERROR( avs_is_error( res2 ), "couldn't convert input clip to %s: %s\n", csp, avs_as_error( res2 ) );
        res = update_clip( h, &vi, res2, res );
    }
    /* if swscale is not available, change the range if necessary. This only applies to YUV-based CSPs however */
    if( avs_is_yuv( vi ) && opt->output_range != RANGE_AUTO && ((opt->input_range == RANGE_PC) != opt->output_range) )
    {
        const char *levels = opt->output_range ? "TV->PC" : "PC->TV";
        x264_cli_log( "avs", X264_LOG_WARNING, "performing %s conversion\n", levels );
        AVS_Value arg_arr[2];
        arg_arr[0] = res;
        arg_arr[1] = avs_new_value_string( levels );
        const char *arg_name[] = { NULL, "levels" };
        AVS_Value res2 = h->func.avs_invoke( h->env, "ColorYUV", avs_new_value_array( arg_arr, 2 ), arg_name );
        FAIL_IF_ERROR( avs_is_error( res2 ), "couldn't convert range: %s\n", avs_as_error( res2 ) );
        res = update_clip( h, &vi, res2, res );
        // notification that the input range has changed to the desired one
        opt->input_range = opt->output_range;
    }
#endif

    h->func.avs_release_value( res );

    info->width   = vi->width;
    info->height  = vi->height;
    info->fps_num = vi->fps_numerator;
    info->fps_den = vi->fps_denominator;
    h->num_frames = info->num_frames = vi->num_frames;
    info->thread_safe = 1;
    if( AVS_IS_RGB64( vi ) )
        info->csp = X264_CSP_BGRA | X264_CSP_VFLIP | X264_CSP_HIGH_DEPTH;
    else if( avs_is_rgb32( vi ) )
        info->csp = X264_CSP_BGRA | X264_CSP_VFLIP;
    else if( AVS_IS_RGB48( vi ) )
        info->csp = X264_CSP_BGR | X264_CSP_VFLIP | X264_CSP_HIGH_DEPTH;
    else if( avs_is_rgb24( vi ) )
        info->csp = X264_CSP_BGR | X264_CSP_VFLIP;
    else if( AVS_IS_YUV444P16( vi ) )
        info->csp = X264_CSP_I444 | X264_CSP_HIGH_DEPTH;
    else if( avs_is_yv24( vi ) )
        info->csp = X264_CSP_I444;
    else if( AVS_IS_YUV422P16( vi ) )
        info->csp = X264_CSP_I422 | X264_CSP_HIGH_DEPTH;
    else if( avs_is_yv16( vi ) )
        info->csp = X264_CSP_I422;
    else if( AVS_IS_YUV420P16( vi ) )
        info->csp = X264_CSP_I420 | X264_CSP_HIGH_DEPTH;
    else if( avs_is_yv12( vi ) )
        info->csp = X264_CSP_I420;
    else if( AVS_IS_Y16( vi ) )
        info->csp = X264_CSP_I400 | X264_CSP_HIGH_DEPTH;
    else if( avs_is_y8( vi ) )
        info->csp = X264_CSP_I400;
    else if( avs_is_yuy2( vi ) )
        info->csp = X264_CSP_YUYV;
#if HAVE_SWSCALE
    else if( avs_is_yv411( vi ) )
        info->csp = AV_PIX_FMT_YUV411P | X264_CSP_OTHER;
#endif
    else
    {
        AVS_Value pixel_type = h->func.avs_invoke( h->env, "PixelType", res, NULL );
        const char *pixel_type_name = avs_is_string( pixel_type ) ? avs_as_string( pixel_type ) : "unknown";
        FAIL_IF_ERROR( 1, "not supported pixel type: %s\n", pixel_type_name );
    }
    info->vfr = 0;

    *p_handle = h;
    return 0;
}

static int picture_alloc( cli_pic_t *pic, hnd_t handle, int csp, int width, int height )
{
    if( x264_cli_pic_alloc( pic, X264_CSP_NONE, width, height ) )
        return -1;
    pic->img.csp = csp;
    const x264_cli_csp_t *cli_csp = x264_cli_get_csp( csp );
    if( cli_csp )
        pic->img.planes = cli_csp->planes;
#if HAVE_SWSCALE
    else if( csp == (AV_PIX_FMT_YUV411P | X264_CSP_OTHER) )
        pic->img.planes = 3;
    else
        pic->img.planes = 1; //y8 and yuy2 are one plane
#endif
    return 0;
}

static int read_frame( cli_pic_t *pic, hnd_t handle, int i_frame )
{
    static const int plane[3] = { AVS_PLANAR_Y, AVS_PLANAR_U, AVS_PLANAR_V };
    avs_hnd_t *h = handle;
    if( i_frame >= h->num_frames )
        return -1;
    AVS_VideoFrame *frm = pic->opaque = h->func.avs_get_frame( h->clip, i_frame );
    const char *err = h->func.avs_clip_get_error( h->clip );
    FAIL_IF_ERROR( err, "%s occurred while reading frame %d\n", err, i_frame );
    for( int i = 0; i < pic->img.planes; i++ )
    {
        /* explicitly cast away the const attribute to avoid a warning */
        pic->img.plane[i] = (uint8_t*)avs_get_read_ptr_p( frm, plane[i] );
        pic->img.stride[i] = avs_get_pitch_p( frm, plane[i] );
    }
    return 0;
}

static int release_frame( cli_pic_t *pic, hnd_t handle )
{
    avs_hnd_t *h = handle;
    h->func.avs_release_video_frame( pic->opaque );
    return 0;
}

static void picture_clean( cli_pic_t *pic, hnd_t handle )
{
    memset( pic, 0, sizeof(cli_pic_t) );
}

static int close_file( hnd_t handle )
{
    avs_hnd_t *h = handle;
    if( h->func.avs_release_clip && h->clip )
        h->func.avs_release_clip( h->clip );
    if( h->func.avs_delete_script_environment && h->env )
        h->func.avs_delete_script_environment( h->env );
    if( h->library )
        avs_close( h->library );
    free( h );
    return 0;
}

const cli_input_t avs_input = { open_file, picture_alloc, read_frame, release_frame, picture_clean, close_file };
