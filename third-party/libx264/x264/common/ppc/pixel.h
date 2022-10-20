/*****************************************************************************
 * pixel.h: ppc pixel metrics
 *****************************************************************************
 * Copyright (C) 2003-2022 x264 project
 *
 * Authors: Eric Petit <eric.petit@lapsus.org>
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

#ifndef X264_PPC_PIXEL_H
#define X264_PPC_PIXEL_H

#define x264_pixel_init_altivec x264_template(pixel_init_altivec)
void x264_pixel_init_altivec( x264_pixel_function_t *pixf );

#endif
