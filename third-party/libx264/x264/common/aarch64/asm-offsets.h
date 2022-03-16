/*****************************************************************************
 * asm-offsets.h: asm offsets for aarch64
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

#ifndef X264_AARCH64_ASM_OFFSETS_H
#define X264_AARCH64_ASM_OFFSETS_H

#define CABAC_I_LOW                 0x00
#define CABAC_I_RANGE               0x04
#define CABAC_I_QUEUE               0x08
#define CABAC_I_BYTES_OUTSTANDING   0x0c
#define CABAC_P_START               0x10
#define CABAC_P                     0x18
#define CABAC_P_END                 0x20
#define CABAC_F8_BITS_ENCODED       0x30
#define CABAC_STATE                 0x34

#endif
