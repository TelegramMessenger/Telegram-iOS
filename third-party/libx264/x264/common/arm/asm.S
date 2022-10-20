/*****************************************************************************
 * asm.S: arm utility macros
 *****************************************************************************
 * Copyright (C) 2008-2022 x264 project
 *
 * Authors: Mans Rullgard <mans@mansr.com>
 *          David Conrad <lessen42@gmail.com>
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

#include "config.h"

.syntax unified

#ifdef __ELF__
.arch armv7-a
.fpu neon
#endif

#define GLUE(a, b) a ## b
#define JOIN(a, b) GLUE(a, b)

#ifdef PREFIX
#   define BASE _x264_
#   define SYM_PREFIX _
#else
#   define BASE x264_
#   define SYM_PREFIX
#endif

#ifdef BIT_DEPTH
#   define EXTERN_ASM JOIN(JOIN(BASE, BIT_DEPTH), _)
#else
#   define EXTERN_ASM BASE
#endif

#define X(s) JOIN(EXTERN_ASM, s)
#define X264(s) JOIN(BASE, s)
#define EXT(s) JOIN(SYM_PREFIX, s)

#ifdef __ELF__
#   define ELF
#else
#   define ELF @
#endif

#ifdef __MACH__
#   define MACH
#   define NONMACH @
#else
#   define MACH @
#   define NONMACH
#endif

#if HAVE_AS_FUNC
#   define FUNC
#else
#   define FUNC @
#endif

#if SYS_LINUX || SYS_OPENBSD
#define HAVE_SECTION_DATA_REL_RO 1
#else
#define HAVE_SECTION_DATA_REL_RO 0
#endif

.macro require8, val=1
ELF     .eabi_attribute 24, \val
.endm

.macro preserve8, val=1
ELF     .eabi_attribute 25, \val
.endm

.macro function name, export=1
    .macro endfunc
.if \export
ELF     .size   EXTERN_ASM\name, . - EXTERN_ASM\name
.else
ELF     .size   \name, . - \name
.endif
FUNC    .endfunc
        .purgem endfunc
    .endm
        .text
        .align  2
.if \export == 1
        .global EXTERN_ASM\name
ELF     .hidden EXTERN_ASM\name
ELF     .type   EXTERN_ASM\name, %function
FUNC    .func   EXTERN_ASM\name
EXTERN_ASM\name:
.else
ELF     .hidden \name
ELF     .type   \name, %function
FUNC    .func   \name
\name:
.endif
.endm

.macro const name, align=2, relocate=0
    .macro endconst
ELF     .size   \name, . - \name
        .purgem endconst
    .endm
.if HAVE_SECTION_DATA_REL_RO && \relocate
        .section        .data.rel.ro
.else
NONMACH .section        .rodata
MACH    .const_data
.endif
        .align          \align
\name:
.endm

.macro movrel rd, val
#if defined(PIC)
        ldr             \rd,  1f
        b               2f
1:
@ FIXME: thumb
        .word           \val - (2f + 8)
2:
        add             \rd,  \rd,  pc
#elif HAVE_ARMV6T2
        movw            \rd, #:lower16:\val
        movt            \rd, #:upper16:\val
#else
        ldr             \rd, =\val
#endif
.endm

.macro movrelx rd, val, got
#if defined(PIC) && defined(__ELF__)
        ldr             \got, 2f
        ldr             \rd,  1f
        b               3f
1:
@ FIXME: thumb
        .word \val(GOT)
2:
        .word _GLOBAL_OFFSET_TABLE_ - (3f + 8)
3:
        add             \got, \got, pc
        ldr             \rd, [\got, \rd]
#elif defined(PIC) && defined(__APPLE__)
        ldr             \rd,  1f
        b               2f
1:
@ FIXME: thumb
        .word           3f - (2f + 8)
2:
        ldr             \rd, [pc, \rd]
        .non_lazy_symbol_pointer
3:
        .indirect_symbol \val
        .word           0
        .text
#else
        movrel          \rd, \val
#endif
.endm

.macro movconst rd, val
#if HAVE_ARMV6T2
    movw        \rd, #:lower16:\val
.if \val >> 16
    movt        \rd, #:upper16:\val
.endif
#else
    ldr         \rd, =\val
#endif
.endm

#define FENC_STRIDE 16
#define FDEC_STRIDE 32

.macro HORIZ_ADD dest, a, b
.ifnb \b
    vadd.u16    \a, \a, \b
.endif
    vpaddl.u16  \a, \a
    vpaddl.u32  \dest, \a
.endm

.macro SUMSUB_AB sum, diff, a, b
    vadd.s16    \sum,  \a, \b
    vsub.s16    \diff, \a, \b
.endm

.macro SUMSUB_ABCD s1, d1, s2, d2, a, b, c, d
    SUMSUB_AB   \s1, \d1, \a, \b
    SUMSUB_AB   \s2, \d2, \c, \d
.endm

.macro ABS2 a b
    vabs.s16 \a, \a
    vabs.s16 \b, \b
.endm

// dist = distance in elements (0 for vertical pass, 1/2 for horizontal passes)
// op = sumsub/amax (sum and diff / maximum of absolutes)
// d1/2 = destination registers
// s1/2 = source registers
.macro HADAMARD dist, op, d1, d2, s1, s2
.if \dist == 1
    vtrn.16     \s1, \s2
.else
    vtrn.32     \s1, \s2
.endif
.ifc \op, sumsub
    SUMSUB_AB   \d1, \d2, \s1, \s2
.else
    vabs.s16    \s1, \s1
    vabs.s16    \s2, \s2
    vmax.s16    \d1, \s1, \s2
.endif
.endm

.macro TRANSPOSE8x8 r0 r1 r2 r3 r4 r5 r6 r7
    vtrn.32         \r0, \r4
    vtrn.32         \r1, \r5
    vtrn.32         \r2, \r6
    vtrn.32         \r3, \r7
    vtrn.16         \r0, \r2
    vtrn.16         \r1, \r3
    vtrn.16         \r4, \r6
    vtrn.16         \r5, \r7
    vtrn.8          \r0, \r1
    vtrn.8          \r2, \r3
    vtrn.8          \r4, \r5
    vtrn.8          \r6, \r7
.endm

.macro TRANSPOSE4x4 r0 r1 r2 r3
    vtrn.16         \r0, \r2
    vtrn.16         \r1, \r3
    vtrn.8          \r0, \r1
    vtrn.8          \r2, \r3
.endm

.macro TRANSPOSE4x4_16  d0 d1 d2 d3
    vtrn.32     \d0, \d2
    vtrn.32     \d1, \d3
    vtrn.16     \d0, \d1
    vtrn.16     \d2, \d3
.endm
