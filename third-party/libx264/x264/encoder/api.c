/*****************************************************************************
 * api.c: bit depth independent interface
 *****************************************************************************
 * Copyright (C) 2003-2022 x264 project
 *
 * Authors: Vittorio Giovara <vittorio.giovara@gmail.com>
 *          Luca Barbato <lu_zero@gentoo.org>
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

#include "common/base.h"

/****************************************************************************
 * global symbols
 ****************************************************************************/
const int x264_chroma_format = X264_CHROMA_FORMAT;

x264_t *x264_8_encoder_open( x264_param_t *, void * );
void x264_8_nal_encode( x264_t *h, uint8_t *dst, x264_nal_t *nal );
int  x264_8_encoder_reconfig( x264_t *, x264_param_t * );
void x264_8_encoder_parameters( x264_t *, x264_param_t * );
int  x264_8_encoder_headers( x264_t *, x264_nal_t **pp_nal, int *pi_nal );
int  x264_8_encoder_encode( x264_t *, x264_nal_t **pp_nal, int *pi_nal, x264_picture_t *pic_in, x264_picture_t *pic_out );
void x264_8_encoder_close( x264_t * );
int  x264_8_encoder_delayed_frames( x264_t * );
int  x264_8_encoder_maximum_delayed_frames( x264_t * );
void x264_8_encoder_intra_refresh( x264_t * );
int  x264_8_encoder_invalidate_reference( x264_t *, int64_t pts );

x264_t *x264_10_encoder_open( x264_param_t *, void * );
void x264_10_nal_encode( x264_t *h, uint8_t *dst, x264_nal_t *nal );
int  x264_10_encoder_reconfig( x264_t *, x264_param_t * );
void x264_10_encoder_parameters( x264_t *, x264_param_t * );
int  x264_10_encoder_headers( x264_t *, x264_nal_t **pp_nal, int *pi_nal );
int  x264_10_encoder_encode( x264_t *, x264_nal_t **pp_nal, int *pi_nal, x264_picture_t *pic_in, x264_picture_t *pic_out );
void x264_10_encoder_close( x264_t * );
int  x264_10_encoder_delayed_frames( x264_t * );
int  x264_10_encoder_maximum_delayed_frames( x264_t * );
void x264_10_encoder_intra_refresh( x264_t * );
int  x264_10_encoder_invalidate_reference( x264_t *, int64_t pts );

typedef struct x264_api_t
{
    /* Internal reference to x264_t data */
    x264_t *x264;

    /* API entry points */
    void (*nal_encode)( x264_t *h, uint8_t *dst, x264_nal_t *nal );
    int  (*encoder_reconfig)( x264_t *, x264_param_t * );
    void (*encoder_parameters)( x264_t *, x264_param_t * );
    int  (*encoder_headers)( x264_t *, x264_nal_t **pp_nal, int *pi_nal );
    int  (*encoder_encode)( x264_t *, x264_nal_t **pp_nal, int *pi_nal, x264_picture_t *pic_in, x264_picture_t *pic_out );
    void (*encoder_close)( x264_t * );
    int  (*encoder_delayed_frames)( x264_t * );
    int  (*encoder_maximum_delayed_frames)( x264_t * );
    void (*encoder_intra_refresh)( x264_t * );
    int  (*encoder_invalidate_reference)( x264_t *, int64_t pts );
} x264_api_t;

REALIGN_STACK x264_t *x264_encoder_open( x264_param_t *param )
{
    x264_api_t *api = calloc( 1, sizeof( x264_api_t ) );
    if( !api )
        return NULL;

    if( HAVE_BITDEPTH8 && param->i_bitdepth == 8 )
    {
        api->nal_encode = x264_8_nal_encode;
        api->encoder_reconfig = x264_8_encoder_reconfig;
        api->encoder_parameters = x264_8_encoder_parameters;
        api->encoder_headers = x264_8_encoder_headers;
        api->encoder_encode = x264_8_encoder_encode;
        api->encoder_close = x264_8_encoder_close;
        api->encoder_delayed_frames = x264_8_encoder_delayed_frames;
        api->encoder_maximum_delayed_frames = x264_8_encoder_maximum_delayed_frames;
        api->encoder_intra_refresh = x264_8_encoder_intra_refresh;
        api->encoder_invalidate_reference = x264_8_encoder_invalidate_reference;

        api->x264 = x264_8_encoder_open( param, api );
    }
    else if( HAVE_BITDEPTH10 && param->i_bitdepth == 10 )
    {
        api->nal_encode = x264_10_nal_encode;
        api->encoder_reconfig = x264_10_encoder_reconfig;
        api->encoder_parameters = x264_10_encoder_parameters;
        api->encoder_headers = x264_10_encoder_headers;
        api->encoder_encode = x264_10_encoder_encode;
        api->encoder_close = x264_10_encoder_close;
        api->encoder_delayed_frames = x264_10_encoder_delayed_frames;
        api->encoder_maximum_delayed_frames = x264_10_encoder_maximum_delayed_frames;
        api->encoder_intra_refresh = x264_10_encoder_intra_refresh;
        api->encoder_invalidate_reference = x264_10_encoder_invalidate_reference;

        api->x264 = x264_10_encoder_open( param, api );
    }
    else
        x264_log_internal( X264_LOG_ERROR, "not compiled with %d bit depth support\n", param->i_bitdepth );

    if( !api->x264 )
    {
        free( api );
        return NULL;
    }

    /* x264_t is opaque */
    return (x264_t *)api;
}

REALIGN_STACK void x264_encoder_close( x264_t *h )
{
    x264_api_t *api = (x264_api_t *)h;

    api->encoder_close( api->x264 );
    free( api );
}

REALIGN_STACK void x264_nal_encode( x264_t *h, uint8_t *dst, x264_nal_t *nal )
{
    x264_api_t *api = (x264_api_t *)h;

    api->nal_encode( api->x264, dst, nal );
}

REALIGN_STACK int x264_encoder_reconfig( x264_t *h, x264_param_t *param)
{
    x264_api_t *api = (x264_api_t *)h;

    return api->encoder_reconfig( api->x264, param );
}

REALIGN_STACK void x264_encoder_parameters( x264_t *h, x264_param_t *param )
{
    x264_api_t *api = (x264_api_t *)h;

    api->encoder_parameters( api->x264, param );
}

REALIGN_STACK int x264_encoder_headers( x264_t *h, x264_nal_t **pp_nal, int *pi_nal )
{
    x264_api_t *api = (x264_api_t *)h;

    return api->encoder_headers( api->x264, pp_nal, pi_nal );
}

REALIGN_STACK int x264_encoder_encode( x264_t *h, x264_nal_t **pp_nal, int *pi_nal, x264_picture_t *pic_in, x264_picture_t *pic_out )
{
    x264_api_t *api = (x264_api_t *)h;

    return api->encoder_encode( api->x264, pp_nal, pi_nal, pic_in, pic_out );
}

REALIGN_STACK int x264_encoder_delayed_frames( x264_t *h )
{
    x264_api_t *api = (x264_api_t *)h;

    return api->encoder_delayed_frames( api->x264 );
}

REALIGN_STACK int x264_encoder_maximum_delayed_frames( x264_t *h )
{
    x264_api_t *api = (x264_api_t *)h;

    return api->encoder_maximum_delayed_frames( api->x264 );
}

REALIGN_STACK void x264_encoder_intra_refresh( x264_t *h )
{
    x264_api_t *api = (x264_api_t *)h;

    api->encoder_intra_refresh( api->x264 );
}

REALIGN_STACK int x264_encoder_invalidate_reference( x264_t *h, int64_t pts )
{
    x264_api_t *api = (x264_api_t *)h;

    return api->encoder_invalidate_reference( api->x264, pts );
}
