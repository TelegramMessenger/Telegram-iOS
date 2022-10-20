/*****************************************************************************
 * cpu.h: cpu detection
 *****************************************************************************
 * Copyright (C) 2004-2022 x264 project
 *
 * Authors: Loren Merritt <lorenm@u.washington.edu>
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

#ifndef X264_CPU_H
#define X264_CPU_H

X264_API uint32_t x264_cpu_detect( void );
X264_API int      x264_cpu_num_processors( void );
void     x264_cpu_emms( void );
void     x264_cpu_sfence( void );
#if HAVE_MMX
/* There is no way to forbid the compiler from using float instructions
 * before the emms so miscompilation could theoretically occur in the
 * unlikely event that the compiler reorders emms and float instructions. */
#if HAVE_X86_INLINE_ASM
/* Clobbering memory makes the compiler less likely to reorder code. */
#define x264_emms() asm volatile( "emms":::"memory","st","st(1)","st(2)", \
                                  "st(3)","st(4)","st(5)","st(6)","st(7)" )
#else
#define x264_emms() x264_cpu_emms()
#endif
#else
#define x264_emms()
#endif
#define x264_sfence x264_cpu_sfence

typedef struct
{
    const char *name;
    uint32_t flags;
} x264_cpu_name_t;
X264_API extern const x264_cpu_name_t x264_cpu_names[];

#endif
