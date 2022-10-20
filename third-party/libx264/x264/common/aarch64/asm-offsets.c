/*****************************************************************************
 * asm-offsets.c: check asm offsets for aarch64
 *****************************************************************************
 * Copyright (C) 2014-2022 x264 project
 *
 * Authors: Janne Grunau <janne-x264@jannau.net>
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

#include "common/common.h"
#include "asm-offsets.h"

#define STATIC_ASSERT(name, x) int assert_##name[2 * !!(x) - 1]

#define X264_CHECK_OFFSET(s, m, o) struct check_##s##_##m \
{ \
    STATIC_ASSERT(offset_##m, offsetof(s, m) == o); \
}

#define X264_CHECK_REL_OFFSET(s, a, type, b) struct check_##s##_##a##_##b \
{ \
    STATIC_ASSERT(rel_offset_##a##_##b, offsetof(s, a) + sizeof(type) == offsetof(s, b)); \
}


X264_CHECK_OFFSET(x264_cabac_t, i_low,               CABAC_I_LOW);
X264_CHECK_OFFSET(x264_cabac_t, i_range,             CABAC_I_RANGE);
X264_CHECK_OFFSET(x264_cabac_t, i_queue,             CABAC_I_QUEUE);
X264_CHECK_OFFSET(x264_cabac_t, i_bytes_outstanding, CABAC_I_BYTES_OUTSTANDING);
X264_CHECK_OFFSET(x264_cabac_t, p_start,             CABAC_P_START);
X264_CHECK_OFFSET(x264_cabac_t, p,                   CABAC_P);
X264_CHECK_OFFSET(x264_cabac_t, p_end,               CABAC_P_END);
X264_CHECK_OFFSET(x264_cabac_t, f8_bits_encoded,     CABAC_F8_BITS_ENCODED);
X264_CHECK_OFFSET(x264_cabac_t, state,               CABAC_STATE);

// the aarch64 asm makes following additional assumptions about the x264_cabac_t
// memory layout

X264_CHECK_REL_OFFSET(x264_cabac_t, i_low,    int, i_range);
X264_CHECK_REL_OFFSET(x264_cabac_t, i_queue,  int, i_bytes_outstanding);
