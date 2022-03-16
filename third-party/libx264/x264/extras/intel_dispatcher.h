/*****************************************************************************
 * intel_dispatcher.h: intel compiler cpu dispatcher override
 *****************************************************************************
 * Copyright (C) 2014-2022 x264 project
 *
 * Authors: Anton Mitrofanov <BugMaster@narod.ru>
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

#ifndef X264_INTEL_DISPATCHER_H
#define X264_INTEL_DISPATCHER_H

/* Feature flags using _FEATURE_* defines from immintrin.h */
extern unsigned long long __intel_cpu_feature_indicator;
extern unsigned long long __intel_cpu_feature_indicator_x;

/* CPU vendor independent version of dispatcher */
void __intel_cpu_features_init_x( void );

static void x264_intel_dispatcher_override( void )
{
    if( __intel_cpu_feature_indicator & ~1ULL )
        return;
    __intel_cpu_feature_indicator = 0;
    __intel_cpu_feature_indicator_x = 0;
    __intel_cpu_features_init_x();
    __intel_cpu_feature_indicator = __intel_cpu_feature_indicator_x;
}

#endif
