/*****************************************************************************
 * rectangle.c: rectangle filling
 *****************************************************************************
 * Copyright (C) 2010-2022 x264 project
 *
 * Authors: Fiona Glaser <fiona@x264.com>
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

#include "common.h"

#define CACHE_FUNC(name,size,width,height)\
static void macroblock_cache_##name##_##width##_##height( void *target, uint32_t val )\
{\
    x264_macroblock_cache_rect( target, width*size, height, size, val );\
}

#define CACHE_FUNCS(name,size)\
CACHE_FUNC(name,size,4,4)\
CACHE_FUNC(name,size,2,4)\
CACHE_FUNC(name,size,4,2)\
CACHE_FUNC(name,size,2,2)\
CACHE_FUNC(name,size,2,1)\
CACHE_FUNC(name,size,1,2)\
CACHE_FUNC(name,size,1,1)\
void (*x264_cache_##name##_func_table[10])(void *, uint32_t) =\
{\
    macroblock_cache_##name##_1_1,\
    macroblock_cache_##name##_2_1,\
    macroblock_cache_##name##_1_2,\
    macroblock_cache_##name##_2_2,\
    NULL,\
    macroblock_cache_##name##_4_2,\
    NULL,\
    macroblock_cache_##name##_2_4,\
    NULL,\
    macroblock_cache_##name##_4_4\
};\

CACHE_FUNCS(mv, 4)
CACHE_FUNCS(mvd, 2)
CACHE_FUNCS(ref, 1)
