/*****************************************************************************
 * set.h: header writing
 *****************************************************************************
 * Copyright (C) 2003-2022 x264 project
 *
 * Authors: Laurent Aimar <fenrir@via.ecp.fr>
 *          Loren Merritt <lorenm@u.washington.edu>
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

#ifndef X264_ENCODER_SET_H
#define X264_ENCODER_SET_H

#define x264_sps_init x264_template(sps_init)
void x264_sps_init( x264_sps_t *sps, int i_id, x264_param_t *param );
#define x264_sps_init_reconfigurable x264_template(sps_init_reconfigurable)
void x264_sps_init_reconfigurable( x264_sps_t *sps, x264_param_t *param );
#define x264_sps_init_scaling_list x264_template(sps_init_scaling_list)
void x264_sps_init_scaling_list( x264_sps_t *sps, x264_param_t *param );
#define x264_sps_write x264_template(sps_write)
void x264_sps_write( bs_t *s, x264_sps_t *sps );
#define x264_pps_init x264_template(pps_init)
void x264_pps_init( x264_pps_t *pps, int i_id, x264_param_t *param, x264_sps_t *sps );
#define x264_pps_write x264_template(pps_write)
void x264_pps_write( bs_t *s, x264_sps_t *sps, x264_pps_t *pps );
#define x264_sei_recovery_point_write x264_template(sei_recovery_point_write)
void x264_sei_recovery_point_write( x264_t *h, bs_t *s, int recovery_frame_cnt );
#define x264_sei_version_write x264_template(sei_version_write)
int  x264_sei_version_write( x264_t *h, bs_t *s );
#define x264_validate_levels x264_template(validate_levels)
int  x264_validate_levels( x264_t *h, int verbose );
#define x264_sei_buffering_period_write x264_template(sei_buffering_period_write)
void x264_sei_buffering_period_write( x264_t *h, bs_t *s );
#define x264_sei_pic_timing_write x264_template(sei_pic_timing_write)
void x264_sei_pic_timing_write( x264_t *h, bs_t *s );
#define x264_sei_dec_ref_pic_marking_write x264_template(sei_dec_ref_pic_marking_write)
void x264_sei_dec_ref_pic_marking_write( x264_t *h, bs_t *s );
#define x264_sei_frame_packing_write x264_template(sei_frame_packing_write)
void x264_sei_frame_packing_write( x264_t *h, bs_t *s );
#define x264_sei_mastering_display_write x264_template(sei_mastering_display_write)
void x264_sei_mastering_display_write( x264_t *h, bs_t *s );
#define x264_sei_content_light_level_write x264_template(sei_content_light_level_write)
void x264_sei_content_light_level_write( x264_t *h, bs_t *s );
#define x264_sei_alternative_transfer_write x264_template(sei_alternative_transfer_write)
void x264_sei_alternative_transfer_write( x264_t *h, bs_t *s );
#define x264_sei_avcintra_umid_write x264_template(sei_avcintra_umid_write)
int  x264_sei_avcintra_umid_write( x264_t *h, bs_t *s );
#define x264_sei_avcintra_vanc_write x264_template(sei_avcintra_vanc_write)
int  x264_sei_avcintra_vanc_write( x264_t *h, bs_t *s, int len );
#define x264_sei_write x264_template(sei_write)
void x264_sei_write( bs_t *s, uint8_t *payload, int payload_size, int payload_type );
#define x264_filler_write x264_template(filler_write)
void x264_filler_write( x264_t *h, bs_t *s, int filler );

#endif
