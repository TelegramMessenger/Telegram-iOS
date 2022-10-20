/*****************************************************************************
 * checkasm.c: assembly check tool
 *****************************************************************************
 * Copyright (C) 2003-2022 x264 project
 *
 * Authors: Loren Merritt <lorenm@u.washington.edu>
 *          Laurent Aimar <fenrir@via.ecp.fr>
 *          Fiona Glaser <fiona@x264.com>
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

#include <ctype.h>
#include "common/common.h"
#include "encoder/macroblock.h"

#ifdef _WIN32
#include <windows.h>
#endif

// GCC doesn't align stack variables on ARM, so use .bss
#if ARCH_ARM
#undef ALIGNED_16
#define ALIGNED_16( var ) DECLARE_ALIGNED( static var, 16 )
#endif

/* buf1, buf2: initialised to random data and shouldn't write into them */
static uint8_t *buf1, *buf2;
/* buf3, buf4: used to store output */
static uint8_t *buf3, *buf4;
/* pbuf1, pbuf2: initialised to random pixel data and shouldn't write into them. */
static pixel *pbuf1, *pbuf2;
/* pbuf3, pbuf4: point to buf3, buf4, just for type convenience */
static pixel *pbuf3, *pbuf4;

#if BIT_DEPTH > 8
#define FMT_PIXEL "%04x"
#else
#define FMT_PIXEL "%02x"
#endif

static int quiet = 0;

#define report( name ) { \
    if( used_asm && !quiet ) \
        fprintf( stderr, " - %-21s [%s]\n", name, ok ? "OK" : "FAILED" ); \
    if( !ok ) ret = -1; \
}

#define BENCH_RUNS 2000 // tradeoff between accuracy and speed
#define MAX_FUNCS 1000  // just has to be big enough to hold all the existing functions
#define MAX_CPUS 30     // number of different combinations of cpu flags

// RAND_MAX is guaranteed to be at least 32767, to get 30 bits of random data, we'll call rand() twice
#define rand30() (((rand() & 0x7fff) << 15) + (rand() & 0x7fff))

typedef struct
{
    void *pointer; // just for detecting duplicates
    uint32_t cpu;
    uint64_t cycles;
    uint32_t den;
} bench_t;

typedef struct
{
    char *name;
    bench_t vers[MAX_CPUS];
} bench_func_t;

static int do_bench = 0;
static int bench_pattern_len = 0;
static const char *bench_pattern = "";
static char func_name[100];
static bench_func_t benchs[MAX_FUNCS];

static const char *pixel_names[12] = { "16x16", "16x8", "8x16", "8x8", "8x4", "4x8", "4x4", "4x16", "4x2", "2x8", "2x4", "2x2" };
static const char *intra_predict_16x16_names[7] = { "v", "h", "dc", "p", "dcl", "dct", "dc8" };
static const char *intra_predict_8x8c_names[7] = { "dc", "h", "v", "p", "dcl", "dct", "dc8" };
static const char *intra_predict_4x4_names[12] = { "v", "h", "dc", "ddl", "ddr", "vr", "hd", "vl", "hu", "dcl", "dct", "dc8" };
static const char **intra_predict_8x8_names = intra_predict_4x4_names;
static const char **intra_predict_8x16c_names = intra_predict_8x8c_names;

#define set_func_name(...) snprintf( func_name, sizeof(func_name), __VA_ARGS__ )

static inline uint32_t read_time(void)
{
    uint32_t a = 0;
#if HAVE_X86_INLINE_ASM
    asm volatile( "lfence \n"
                  "rdtsc  \n"
                  : "=a"(a) :: "edx", "memory" );
#elif ARCH_PPC
    asm volatile( "mftb %0" : "=r"(a) :: "memory" );
#elif HAVE_ARM_INLINE_ASM    // ARMv7 only
    asm volatile( "mrc p15, 0, %0, c9, c13, 0" : "=r"(a) :: "memory" );
#elif ARCH_AARCH64
    uint64_t b = 0;
    asm volatile( "mrs %0, pmccntr_el0" : "=r"(b) :: "memory" );
    a = b;
#elif ARCH_MIPS
    asm volatile( "rdhwr %0, $2" : "=r"(a) :: "memory" );
#endif
    return a;
}

static bench_t* get_bench( const char *name, uint32_t cpu )
{
    int i, j;
    for( i = 0; benchs[i].name && strcmp(name, benchs[i].name); i++ )
        assert( i < MAX_FUNCS );
    if( !benchs[i].name )
        benchs[i].name = strdup( name );
    if( !cpu )
        return &benchs[i].vers[0];
    for( j = 1; benchs[i].vers[j].cpu && benchs[i].vers[j].cpu != cpu; j++ )
        assert( j < MAX_CPUS );
    benchs[i].vers[j].cpu = cpu;
    return &benchs[i].vers[j];
}

static int cmp_nop( const void *a, const void *b )
{
    return *(uint16_t*)a - *(uint16_t*)b;
}

static int cmp_bench( const void *a, const void *b )
{
    // asciibetical sort except preserving numbers
    const char *sa = ((bench_func_t*)a)->name;
    const char *sb = ((bench_func_t*)b)->name;
    for( ;; sa++, sb++ )
    {
        if( !*sa && !*sb )
            return 0;
        if( isdigit( *sa ) && isdigit( *sb ) && isdigit( sa[1] ) != isdigit( sb[1] ) )
            return isdigit( sa[1] ) - isdigit( sb[1] );
        if( *sa != *sb )
            return *sa - *sb;
    }
}

static void print_bench(void)
{
    uint16_t nops[10000];
    int nfuncs, nop_time=0;

    for( int i = 0; i < 10000; i++ )
    {
        uint32_t t = read_time();
        nops[i] = read_time() - t;
    }
    qsort( nops, 10000, sizeof(uint16_t), cmp_nop );
    for( int i = 500; i < 9500; i++ )
        nop_time += nops[i];
    nop_time /= 900;
    printf( "nop: %d\n", nop_time );

    for( nfuncs = 0; nfuncs < MAX_FUNCS && benchs[nfuncs].name; nfuncs++ );
    qsort( benchs, nfuncs, sizeof(bench_func_t), cmp_bench );
    for( int i = 0; i < nfuncs; i++ )
        for( int j = 0; j < MAX_CPUS && (!j || benchs[i].vers[j].cpu); j++ )
        {
            int k;
            bench_t *b = &benchs[i].vers[j];
            if( !b->den )
                continue;
            for( k = 0; k < j && benchs[i].vers[k].pointer != b->pointer; k++ );
            if( k < j )
                continue;
            printf( "%s_%s%s: %"PRId64"\n", benchs[i].name,
#if ARCH_X86 || ARCH_X86_64
                    b->cpu&X264_CPU_AVX512 ? "avx512" :
                    b->cpu&X264_CPU_AVX2 ? "avx2" :
                    b->cpu&X264_CPU_BMI2 ? "bmi2" :
                    b->cpu&X264_CPU_BMI1 ? "bmi1" :
                    b->cpu&X264_CPU_FMA3 ? "fma3" :
                    b->cpu&X264_CPU_FMA4 ? "fma4" :
                    b->cpu&X264_CPU_XOP ? "xop" :
                    b->cpu&X264_CPU_AVX ? "avx" :
                    b->cpu&X264_CPU_SSE42 ? "sse42" :
                    b->cpu&X264_CPU_SSE4 ? "sse4" :
                    b->cpu&X264_CPU_SSSE3 ? "ssse3" :
                    b->cpu&X264_CPU_SSE3 ? "sse3" :
                    b->cpu&X264_CPU_LZCNT ? "lzcnt" :
                    /* print sse2slow only if there's also a sse2fast version of the same func */
                    b->cpu&X264_CPU_SSE2_IS_SLOW && j<MAX_CPUS-1 && b[1].cpu&X264_CPU_SSE2_IS_FAST && !(b[1].cpu&X264_CPU_SSE3) ? "sse2slow" :
                    b->cpu&X264_CPU_SSE2 ? "sse2" :
                    b->cpu&X264_CPU_SSE ? "sse" :
                    b->cpu&X264_CPU_MMX ? "mmx" :
#elif ARCH_PPC
                    b->cpu&X264_CPU_ALTIVEC ? "altivec" :
#elif ARCH_ARM
                    b->cpu&X264_CPU_NEON ? "neon" :
                    b->cpu&X264_CPU_ARMV6 ? "armv6" :
#elif ARCH_AARCH64
                    b->cpu&X264_CPU_NEON ? "neon" :
                    b->cpu&X264_CPU_ARMV8 ? "armv8" :
#elif ARCH_MIPS
                    b->cpu&X264_CPU_MSA ? "msa" :
#endif
                    "c",
#if ARCH_X86 || ARCH_X86_64
                    b->cpu&X264_CPU_CACHELINE_32 ? "_c32" :
                    b->cpu&X264_CPU_SLOW_ATOM && b->cpu&X264_CPU_CACHELINE_64 ? "_c64_atom" :
                    b->cpu&X264_CPU_CACHELINE_64 ? "_c64" :
                    b->cpu&X264_CPU_SLOW_SHUFFLE ? "_slowshuffle" :
                    b->cpu&X264_CPU_LZCNT && b->cpu&X264_CPU_SSE3 && !(b->cpu&X264_CPU_BMI1) ? "_lzcnt" :
                    b->cpu&X264_CPU_SLOW_ATOM ? "_atom" :
#elif ARCH_ARM
                    b->cpu&X264_CPU_FAST_NEON_MRC ? "_fast_mrc" :
#endif
                    "",
                    (int64_t)(10*b->cycles/b->den - nop_time)/4 );
        }
}

/* YMM and ZMM registers on x86 are turned off to save power when they haven't been
 * used for some period of time. When they are used there will be a "warmup" period
 * during which performance will be reduced and inconsistent which is problematic when
 * trying to benchmark individual functions. We can work around this by periodically
 * issuing "dummy" instructions that uses those registers to keep them powered on. */
static void (*simd_warmup_func)( void ) = NULL;
#define simd_warmup() do { if( simd_warmup_func ) simd_warmup_func(); } while( 0 )

#if HAVE_MMX
int x264_stack_pagealign( int (*func)(), int align );
void x264_checkasm_warmup_avx( void );
void x264_checkasm_warmup_avx512( void );

/* detect when callee-saved regs aren't saved
 * needs an explicit asm check because it only sometimes crashes in normal use. */
intptr_t x264_checkasm_call( intptr_t (*func)(), int *ok, ... );
#else
#define x264_stack_pagealign( func, align ) func()
#endif

#if HAVE_AARCH64
intptr_t x264_checkasm_call( intptr_t (*func)(), int *ok, ... );
#endif

#if HAVE_ARMV6
intptr_t x264_checkasm_call_neon( intptr_t (*func)(), int *ok, ... );
intptr_t x264_checkasm_call_noneon( intptr_t (*func)(), int *ok, ... );
intptr_t (*x264_checkasm_call)( intptr_t (*func)(), int *ok, ... ) = x264_checkasm_call_noneon;
#endif

#define call_c1(func,...) func(__VA_ARGS__)

#if HAVE_MMX && ARCH_X86_64
/* Evil hack: detect incorrect assumptions that 32-bit ints are zero-extended to 64-bit.
 * This is done by clobbering the stack with junk around the stack pointer and calling the
 * assembly function through x264_checkasm_call with added dummy arguments which forces all
 * real arguments to be passed on the stack and not in registers. For 32-bit argument the
 * upper half of the 64-bit register location on the stack will now contain junk. Note that
 * this is dependent on compiler behaviour and that interrupts etc. at the wrong time may
 * overwrite the junk written to the stack so there's no guarantee that it will always
 * detect all functions that assumes zero-extension.
 */
void x264_checkasm_stack_clobber( uint64_t clobber, ... );
#define call_a1(func,...) ({ \
    uint64_t r = (rand() & 0xffff) * 0x0001000100010001ULL; \
    x264_checkasm_stack_clobber( r,r,r,r,r,r,r,r,r,r,r,r,r,r,r,r,r,r,r,r,r ); /* max_args+6 */ \
    simd_warmup(); \
    x264_checkasm_call(( intptr_t(*)())func, &ok, 0, 0, 0, 0, __VA_ARGS__ ); })
#elif HAVE_AARCH64 && !defined(__APPLE__)
void x264_checkasm_stack_clobber( uint64_t clobber, ... );
#define call_a1(func,...) ({ \
    uint64_t r = (rand() & 0xffff) * 0x0001000100010001ULL; \
    x264_checkasm_stack_clobber( r,r,r,r,r,r,r,r,r,r,r,r,r,r,r,r,r,r,r,r,r,r,r ); /* max_args+8 */ \
    x264_checkasm_call(( intptr_t(*)())func, &ok, 0, 0, 0, 0, 0, 0, __VA_ARGS__ ); })
#elif HAVE_MMX || HAVE_ARMV6
#define call_a1(func,...) x264_checkasm_call( (intptr_t(*)())func, &ok, __VA_ARGS__ )
#else
#define call_a1 call_c1
#endif

#if HAVE_ARMV6
#define call_a1_64(func,...) ((uint64_t (*)(intptr_t(*)(), int*, ...))x264_checkasm_call)( (intptr_t(*)())func, &ok, __VA_ARGS__ )
#else
#define call_a1_64 call_a1
#endif

#define call_bench(func,cpu,...)\
    if( do_bench && !strncmp(func_name, bench_pattern, bench_pattern_len) )\
    {\
        uint64_t tsum = 0;\
        int tcount = 0;\
        call_a1(func, __VA_ARGS__);\
        for( int ti = 0; ti < (cpu?BENCH_RUNS:BENCH_RUNS/4); ti++ )\
        {\
            simd_warmup();\
            uint32_t t = read_time();\
            func(__VA_ARGS__);\
            func(__VA_ARGS__);\
            func(__VA_ARGS__);\
            func(__VA_ARGS__);\
            t = read_time() - t;\
            if( (uint64_t)t*tcount <= tsum*4 && ti > 0 )\
            {\
                tsum += t;\
                tcount++;\
            }\
        }\
        bench_t *b = get_bench( func_name, cpu );\
        b->cycles += tsum;\
        b->den += tcount;\
        b->pointer = func;\
    }

/* for most functions, run benchmark and correctness test at the same time.
 * for those that modify their inputs, run the above macros separately */
#define call_a(func,...) ({ call_a2(func,__VA_ARGS__); call_a1(func,__VA_ARGS__); })
#define call_c(func,...) ({ call_c2(func,__VA_ARGS__); call_c1(func,__VA_ARGS__); })
#define call_a2(func,...) ({ call_bench(func,cpu_new,__VA_ARGS__); })
#define call_c2(func,...) ({ call_bench(func,0,__VA_ARGS__); })
#define call_a64(func,...) ({ call_a2(func,__VA_ARGS__); call_a1_64(func,__VA_ARGS__); })


static int check_pixel( uint32_t cpu_ref, uint32_t cpu_new )
{
    x264_pixel_function_t pixel_c;
    x264_pixel_function_t pixel_ref;
    x264_pixel_function_t pixel_asm;
    x264_predict_t predict_4x4[12];
    x264_predict8x8_t predict_8x8[12];
    x264_predict_8x8_filter_t predict_8x8_filter;
    ALIGNED_16( pixel edge[36] );
    uint16_t cost_mv[32];
    int ret = 0, ok, used_asm;

    x264_pixel_init( 0, &pixel_c );
    x264_pixel_init( cpu_ref, &pixel_ref );
    x264_pixel_init( cpu_new, &pixel_asm );
    x264_predict_4x4_init( 0, predict_4x4 );
    x264_predict_8x8_init( 0, predict_8x8, &predict_8x8_filter );
    predict_8x8_filter( pbuf2+40, edge, ALL_NEIGHBORS, ALL_NEIGHBORS );

    // maximize sum
    for( int i = 0; i < 256; i++ )
    {
        int z = i|(i>>4);
        z ^= z>>2;
        z ^= z>>1;
        pbuf4[i] = -(z&1) & PIXEL_MAX;
        pbuf3[i] = ~pbuf4[i] & PIXEL_MAX;
    }
    // random pattern made of maxed pixel differences, in case an intermediate value overflows
    for( int i = 256; i < 0x1000; i++ )
    {
        pbuf4[i] = -(pbuf1[i&~0x88]&1) & PIXEL_MAX;
        pbuf3[i] = ~(pbuf4[i]) & PIXEL_MAX;
    }

#define TEST_PIXEL( name, align ) \
    ok = 1, used_asm = 0; \
    for( int i = 0; i < ARRAY_ELEMS(pixel_c.name); i++ ) \
    { \
        int res_c, res_asm; \
        if( pixel_asm.name[i] != pixel_ref.name[i] ) \
        { \
            set_func_name( "%s_%s", #name, pixel_names[i] ); \
            used_asm = 1; \
            for( int j = 0; j < 64; j++ ) \
            { \
                intptr_t stride1 = (j&31) == 31 ? 32 : FENC_STRIDE; \
                res_c   = call_c( pixel_c.name[i],   pbuf1, stride1, pbuf2+j*!align, (intptr_t)64 ); \
                res_asm = call_a( pixel_asm.name[i], pbuf1, stride1, pbuf2+j*!align, (intptr_t)64 ); \
                if( res_c != res_asm ) \
                { \
                    ok = 0; \
                    fprintf( stderr, #name "[%d]: %d != %d [FAILED]\n", i, res_c, res_asm ); \
                    break; \
                } \
            } \
            for( int j = 0; j < 0x1000 && ok; j += 256 ) \
            { \
                res_c   = pixel_c  .name[i]( pbuf3+j, 16, pbuf4+j, 16 ); \
                res_asm = pixel_asm.name[i]( pbuf3+j, 16, pbuf4+j, 16 ); \
                if( res_c != res_asm ) \
                { \
                    ok = 0; \
                    fprintf( stderr, #name "[%d]: overflow %d != %d\n", i, res_c, res_asm ); \
                } \
            } \
        } \
    } \
    report( "pixel " #name " :" );

    TEST_PIXEL( sad, 0 );
    TEST_PIXEL( sad_aligned, 1 );
    TEST_PIXEL( ssd, 1 );
    TEST_PIXEL( satd, 0 );
    TEST_PIXEL( sa8d, 1 );

    ok = 1, used_asm = 0;
    if( pixel_asm.sa8d_satd[PIXEL_16x16] != pixel_ref.sa8d_satd[PIXEL_16x16] )
    {
        set_func_name( "sa8d_satd_%s", pixel_names[PIXEL_16x16] );
        used_asm = 1;
        for( int j = 0; j < 64; j++ )
        {
            uint32_t cost8_c = pixel_c.sa8d[PIXEL_16x16]( pbuf1, 16, pbuf2, 64 );
            uint32_t cost4_c = pixel_c.satd[PIXEL_16x16]( pbuf1, 16, pbuf2, 64 );
            uint64_t res_a = call_a64( pixel_asm.sa8d_satd[PIXEL_16x16], pbuf1, (intptr_t)16, pbuf2, (intptr_t)64 );
            uint32_t cost8_a = res_a;
            uint32_t cost4_a = res_a >> 32;
            if( cost8_a != cost8_c || cost4_a != cost4_c )
            {
                ok = 0;
                fprintf( stderr, "sa8d_satd [%d]: (%d,%d) != (%d,%d) [FAILED]\n", PIXEL_16x16,
                         cost8_c, cost4_c, cost8_a, cost4_a );
                break;
            }
        }
        for( int j = 0; j < 0x1000 && ok; j += 256 ) \
        {
            uint32_t cost8_c = pixel_c.sa8d[PIXEL_16x16]( pbuf3+j, 16, pbuf4+j, 16 );
            uint32_t cost4_c = pixel_c.satd[PIXEL_16x16]( pbuf3+j, 16, pbuf4+j, 16 );
            uint64_t res_a = pixel_asm.sa8d_satd[PIXEL_16x16]( pbuf3+j, 16, pbuf4+j, 16 );
            uint32_t cost8_a = res_a;
            uint32_t cost4_a = res_a >> 32;
            if( cost8_a != cost8_c || cost4_a != cost4_c )
            {
                ok = 0;
                fprintf( stderr, "sa8d_satd [%d]: overflow (%d,%d) != (%d,%d) [FAILED]\n", PIXEL_16x16,
                         cost8_c, cost4_c, cost8_a, cost4_a );
            }
        }
    }
    report( "pixel sa8d_satd :" );

#define TEST_PIXEL_X( N ) \
    ok = 1; used_asm = 0; \
    for( int i = 0; i < 7; i++ ) \
    { \
        ALIGNED_16( int res_c[4] ) = {0}; \
        ALIGNED_16( int res_asm[4] ) = {0}; \
        if( pixel_asm.sad_x##N[i] && pixel_asm.sad_x##N[i] != pixel_ref.sad_x##N[i] ) \
        { \
            set_func_name( "sad_x%d_%s", N, pixel_names[i] ); \
            used_asm = 1; \
            for( int j = 0; j < 64; j++ ) \
            { \
                pixel *pix2 = pbuf2+j; \
                res_c[0] = pixel_c.sad[i]( pbuf1, 16, pix2,   64 ); \
                res_c[1] = pixel_c.sad[i]( pbuf1, 16, pix2+6, 64 ); \
                res_c[2] = pixel_c.sad[i]( pbuf1, 16, pix2+1, 64 ); \
                if( N == 4 ) \
                { \
                    res_c[3] = pixel_c.sad[i]( pbuf1, 16, pix2+10, 64 ); \
                    call_a( pixel_asm.sad_x4[i], pbuf1, pix2, pix2+6, pix2+1, pix2+10, (intptr_t)64, res_asm ); \
                } \
                else \
                    call_a( pixel_asm.sad_x3[i], pbuf1, pix2, pix2+6, pix2+1, (intptr_t)64, res_asm ); \
                if( memcmp(res_c, res_asm, N*sizeof(int)) ) \
                { \
                    ok = 0; \
                    fprintf( stderr, "sad_x"#N"[%d]: %d,%d,%d,%d != %d,%d,%d,%d [FAILED]\n", \
                             i, res_c[0], res_c[1], res_c[2], res_c[3], \
                             res_asm[0], res_asm[1], res_asm[2], res_asm[3] ); \
                } \
                if( N == 4 ) \
                    call_c2( pixel_c.sad_x4[i], pbuf1, pix2, pix2+6, pix2+1, pix2+10, (intptr_t)64, res_asm ); \
                else \
                    call_c2( pixel_c.sad_x3[i], pbuf1, pix2, pix2+6, pix2+1, (intptr_t)64, res_asm ); \
            } \
        } \
    } \
    report( "pixel sad_x"#N" :" );

    TEST_PIXEL_X(3);
    TEST_PIXEL_X(4);

#define TEST_PIXEL_VAR( i ) \
    if( pixel_asm.var[i] != pixel_ref.var[i] ) \
    { \
        set_func_name( "%s_%s", "var", pixel_names[i] ); \
        used_asm = 1; \
        /* abi-check wrapper can't return uint64_t, so separate it from return value check */ \
        call_c1( pixel_c.var[i],   pbuf1,           16 ); \
        call_a1( pixel_asm.var[i], pbuf1, (intptr_t)16 ); \
        uint64_t res_c   = pixel_c.var[i]( pbuf1, 16 ); \
        uint64_t res_asm = pixel_asm.var[i]( pbuf1, 16 ); \
        if( res_c != res_asm ) \
        { \
            ok = 0; \
            fprintf( stderr, "var[%d]: %d %d != %d %d [FAILED]\n", i, (int)res_c, (int)(res_c>>32), (int)res_asm, (int)(res_asm>>32) ); \
        } \
        call_c2( pixel_c.var[i],   pbuf1, (intptr_t)16 ); \
        call_a2( pixel_asm.var[i], pbuf1, (intptr_t)16 ); \
    }

    ok = 1; used_asm = 0;
    TEST_PIXEL_VAR( PIXEL_16x16 );
    TEST_PIXEL_VAR( PIXEL_8x16 );
    TEST_PIXEL_VAR( PIXEL_8x8 );
    report( "pixel var :" );

#define TEST_PIXEL_VAR2( i ) \
    if( pixel_asm.var2[i] != pixel_ref.var2[i] ) \
    { \
        int res_c, res_asm; \
        ALIGNED_ARRAY_8( int, ssd_c,  [2] ); \
        ALIGNED_ARRAY_8( int, ssd_asm,[2] ); \
        set_func_name( "%s_%s", "var2", pixel_names[i] ); \
        used_asm = 1; \
        res_c   = call_c( pixel_c.var2[i],   pbuf1, pbuf2, ssd_c   ); \
        res_asm = call_a( pixel_asm.var2[i], pbuf1, pbuf2, ssd_asm ); \
        if( res_c != res_asm || memcmp( ssd_c, ssd_asm, 2*sizeof(int) ) ) \
        { \
            ok = 0; \
            fprintf( stderr, "var2[%d]: {%d, %d, %d} != {%d, %d, %d} [FAILED]\n", i, res_c, ssd_c[0], ssd_c[1], res_asm, ssd_asm[0], ssd_asm[1] ); \
        } \
    }

    ok = 1; used_asm = 0;
    TEST_PIXEL_VAR2( PIXEL_8x16 );
    TEST_PIXEL_VAR2( PIXEL_8x8 );
    report( "pixel var2 :" );

    ok = 1; used_asm = 0;
    for( int i = 0; i < 4; i++ )
        if( pixel_asm.hadamard_ac[i] != pixel_ref.hadamard_ac[i] )
        {
            set_func_name( "hadamard_ac_%s", pixel_names[i] );
            used_asm = 1;
            for( int j = 0; j < 32; j++ )
            {
                pixel *pix = (j&16 ? pbuf1 : pbuf3) + (j&15)*256;
                call_c1( pixel_c.hadamard_ac[i],   pbuf1, (intptr_t)16 );
                call_a1( pixel_asm.hadamard_ac[i], pbuf1, (intptr_t)16 );
                uint64_t rc = pixel_c.hadamard_ac[i]( pix, 16 );
                uint64_t ra = pixel_asm.hadamard_ac[i]( pix, 16 );
                if( rc != ra )
                {
                    ok = 0;
                    fprintf( stderr, "hadamard_ac[%d]: %d,%d != %d,%d\n", i, (int)rc, (int)(rc>>32), (int)ra, (int)(ra>>32) );
                    break;
                }
            }
            call_c2( pixel_c.hadamard_ac[i],   pbuf1, (intptr_t)16 );
            call_a2( pixel_asm.hadamard_ac[i], pbuf1, (intptr_t)16 );
        }
    report( "pixel hadamard_ac :" );

    // maximize sum
    for( int i = 0; i < 32; i++ )
        for( int j = 0; j < 16; j++ )
            pbuf4[16*i+j] = -((i+j)&1) & PIXEL_MAX;
    ok = 1; used_asm = 0;
    if( pixel_asm.vsad != pixel_ref.vsad )
    {
        for( int h = 2; h <= 32; h += 2 )
        {
            int res_c, res_asm;
            set_func_name( "vsad" );
            used_asm = 1;
            for( int j = 0; j < 2 && ok; j++ )
            {
                pixel *p = j ? pbuf4 : pbuf1;
                res_c   = call_c( pixel_c.vsad,   p, (intptr_t)16, h );
                res_asm = call_a( pixel_asm.vsad, p, (intptr_t)16, h );
                if( res_c != res_asm )
                {
                    ok = 0;
                    fprintf( stderr, "vsad: height=%d, %d != %d\n", h, res_c, res_asm );
                    break;
                }
            }
        }
    }
    report( "pixel vsad :" );

    ok = 1; used_asm = 0;
    if( pixel_asm.asd8 != pixel_ref.asd8 )
    {
        set_func_name( "asd8" );
        used_asm = 1;
        int res_c = call_c( pixel_c.asd8,   pbuf1, (intptr_t)8, pbuf2, (intptr_t)8, 16 );
        int res_a = call_a( pixel_asm.asd8, pbuf1, (intptr_t)8, pbuf2, (intptr_t)8, 16 );
        if( res_c != res_a )
        {
            ok = 0;
            fprintf( stderr, "asd: %d != %d\n", res_c, res_a );
        }
    }
    report( "pixel asd :" );

#define TEST_INTRA_X3( name, i8x8, ... ) \
    if( pixel_asm.name && pixel_asm.name != pixel_ref.name ) \
    { \
        ALIGNED_16( int res_c[4] ); \
        ALIGNED_16( int res_asm[4] ); \
        set_func_name( #name ); \
        used_asm = 1; \
        call_c( pixel_c.name, pbuf1+48, i8x8 ? edge : pbuf3+48, res_c ); \
        call_a( pixel_asm.name, pbuf1+48, i8x8 ? edge : pbuf3+48, res_asm ); \
        if( memcmp(res_c, res_asm, 3 * sizeof(*res_c)) ) \
        { \
            ok = 0; \
            fprintf( stderr, #name": %d,%d,%d != %d,%d,%d [FAILED]\n", \
                     res_c[0], res_c[1], res_c[2], \
                     res_asm[0], res_asm[1], res_asm[2] ); \
        } \
    }

#define TEST_INTRA_X9( name, cmp ) \
    if( pixel_asm.name && pixel_asm.name != pixel_ref.name ) \
    { \
        set_func_name( #name ); \
        used_asm = 1; \
        ALIGNED_ARRAY_64( uint16_t, bitcosts,[17] ); \
        for( int i=0; i<17; i++ ) \
            bitcosts[i] = 9*(i!=8); \
        memcpy( pbuf3, pbuf2, 20*FDEC_STRIDE*SIZEOF_PIXEL ); \
        memcpy( pbuf4, pbuf2, 20*FDEC_STRIDE*SIZEOF_PIXEL ); \
        for( int i=0; i<32; i++ ) \
        { \
            pixel *fenc = pbuf1+48+i*12; \
            pixel *fdec1 = pbuf3+48+i*12; \
            pixel *fdec2 = pbuf4+48+i*12; \
            int pred_mode = i%9; \
            int res_c = INT_MAX; \
            for( int j=0; j<9; j++ ) \
            { \
                predict_4x4[j]( fdec1 ); \
                int cost = pixel_c.cmp[PIXEL_4x4]( fenc, FENC_STRIDE, fdec1, FDEC_STRIDE ) + 9*(j!=pred_mode); \
                if( cost < (uint16_t)res_c ) \
                    res_c = cost + (j<<16); \
            } \
            predict_4x4[res_c>>16]( fdec1 ); \
            int res_a = call_a( pixel_asm.name, fenc, fdec2, bitcosts+8-pred_mode ); \
            if( res_c != res_a ) \
            { \
                ok = 0; \
                fprintf( stderr, #name": %d,%d != %d,%d [FAILED]\n", res_c>>16, res_c&0xffff, res_a>>16, res_a&0xffff ); \
                break; \
            } \
            if( memcmp(fdec1, fdec2, 4*FDEC_STRIDE*SIZEOF_PIXEL) ) \
            { \
                ok = 0; \
                fprintf( stderr, #name" [FAILED]\n" ); \
                for( int j=0; j<16; j++ ) \
                    fprintf( stderr, FMT_PIXEL" ", fdec1[(j&3)+(j>>2)*FDEC_STRIDE] ); \
                fprintf( stderr, "\n" ); \
                for( int j=0; j<16; j++ ) \
                    fprintf( stderr, FMT_PIXEL" ", fdec2[(j&3)+(j>>2)*FDEC_STRIDE] ); \
                fprintf( stderr, "\n" ); \
                break; \
            } \
        } \
    }

#define TEST_INTRA8_X9( name, cmp ) \
    if( pixel_asm.name && pixel_asm.name != pixel_ref.name ) \
    { \
        set_func_name( #name ); \
        used_asm = 1; \
        ALIGNED_ARRAY_64( uint16_t, bitcosts,[17] ); \
        ALIGNED_ARRAY_16( uint16_t, satds_c,[16] ); \
        ALIGNED_ARRAY_16( uint16_t, satds_a,[16] ); \
        memset( satds_c, 0, 16 * sizeof(*satds_c) ); \
        memset( satds_a, 0, 16 * sizeof(*satds_a) ); \
        for( int i=0; i<17; i++ ) \
            bitcosts[i] = 9*(i!=8); \
        for( int i=0; i<32; i++ ) \
        { \
            pixel *fenc = pbuf1+48+i*12; \
            pixel *fdec1 = pbuf3+48+i*12; \
            pixel *fdec2 = pbuf4+48+i*12; \
            int pred_mode = i%9; \
            int res_c = INT_MAX; \
            predict_8x8_filter( fdec1, edge, ALL_NEIGHBORS, ALL_NEIGHBORS ); \
            for( int j=0; j<9; j++ ) \
            { \
                predict_8x8[j]( fdec1, edge ); \
                satds_c[j] = pixel_c.cmp[PIXEL_8x8]( fenc, FENC_STRIDE, fdec1, FDEC_STRIDE ) + 9*(j!=pred_mode); \
                if( satds_c[j] < (uint16_t)res_c ) \
                    res_c = satds_c[j] + (j<<16); \
            } \
            predict_8x8[res_c>>16]( fdec1, edge ); \
            int res_a = call_a( pixel_asm.name, fenc, fdec2, edge, bitcosts+8-pred_mode, satds_a ); \
            if( res_c != res_a || memcmp(satds_c, satds_a, 16 * sizeof(*satds_c)) ) \
            { \
                ok = 0; \
                fprintf( stderr, #name": %d,%d != %d,%d [FAILED]\n", res_c>>16, res_c&0xffff, res_a>>16, res_a&0xffff ); \
                for( int j = 0; j < 9; j++ ) \
                    fprintf( stderr, "%5d ", satds_c[j]); \
                fprintf( stderr, "\n" ); \
                for( int j = 0; j < 9; j++ ) \
                    fprintf( stderr, "%5d ", satds_a[j]); \
                fprintf( stderr, "\n" ); \
                break; \
            } \
            for( int j=0; j<8; j++ ) \
                if( memcmp(fdec1+j*FDEC_STRIDE, fdec2+j*FDEC_STRIDE, 8*SIZEOF_PIXEL) ) \
                    ok = 0; \
            if( !ok ) \
            { \
                fprintf( stderr, #name" [FAILED]\n" ); \
                for( int j=0; j<8; j++ ) \
                { \
                    for( int k=0; k<8; k++ ) \
                        fprintf( stderr, FMT_PIXEL" ", fdec1[k+j*FDEC_STRIDE] ); \
                    fprintf( stderr, "\n" ); \
                } \
                fprintf( stderr, "\n" ); \
                for( int j=0; j<8; j++ ) \
                { \
                    for( int k=0; k<8; k++ ) \
                        fprintf( stderr, FMT_PIXEL" ", fdec2[k+j*FDEC_STRIDE] ); \
                    fprintf( stderr, "\n" ); \
                } \
                fprintf( stderr, "\n" ); \
                break; \
            } \
        } \
    }

    memcpy( pbuf3, pbuf2, 20*FDEC_STRIDE*SIZEOF_PIXEL );
    ok = 1; used_asm = 0;
    TEST_INTRA_X3( intra_satd_x3_16x16, 0 );
    TEST_INTRA_X3( intra_satd_x3_8x16c, 0 );
    TEST_INTRA_X3( intra_satd_x3_8x8c, 0 );
    TEST_INTRA_X3( intra_sa8d_x3_8x8, 1, edge );
    TEST_INTRA_X3( intra_satd_x3_4x4, 0 );
    report( "intra satd_x3 :" );
    ok = 1; used_asm = 0;
    TEST_INTRA_X3( intra_sad_x3_16x16, 0 );
    TEST_INTRA_X3( intra_sad_x3_8x16c, 0 );
    TEST_INTRA_X3( intra_sad_x3_8x8c, 0 );
    TEST_INTRA_X3( intra_sad_x3_8x8, 1, edge );
    TEST_INTRA_X3( intra_sad_x3_4x4, 0 );
    report( "intra sad_x3 :" );
    ok = 1; used_asm = 0;
    TEST_INTRA_X9( intra_satd_x9_4x4, satd );
    TEST_INTRA8_X9( intra_sa8d_x9_8x8, sa8d );
    report( "intra satd_x9 :" );
    ok = 1; used_asm = 0;
    TEST_INTRA_X9( intra_sad_x9_4x4, sad );
    TEST_INTRA8_X9( intra_sad_x9_8x8, sad );
    report( "intra sad_x9 :" );

    ok = 1; used_asm = 0;
    if( pixel_asm.ssd_nv12_core != pixel_ref.ssd_nv12_core )
    {
        used_asm = 1;
        set_func_name( "ssd_nv12" );
        uint64_t res_u_c, res_v_c, res_u_a, res_v_a;
        for( int w = 8; w <= 360; w += 8 )
        {
            pixel_c.ssd_nv12_core(   pbuf1, 368, pbuf2, 368, w, 8, &res_u_c, &res_v_c );
            pixel_asm.ssd_nv12_core( pbuf1, 368, pbuf2, 368, w, 8, &res_u_a, &res_v_a );
            if( res_u_c != res_u_a || res_v_c != res_v_a )
            {
                ok = 0;
                fprintf( stderr, "ssd_nv12: %"PRIu64",%"PRIu64" != %"PRIu64",%"PRIu64"\n",
                         res_u_c, res_v_c, res_u_a, res_v_a );
            }
        }
        call_c( pixel_c.ssd_nv12_core,   pbuf1, (intptr_t)368, pbuf2, (intptr_t)368, 360, 8, &res_u_c, &res_v_c );
        call_a( pixel_asm.ssd_nv12_core, pbuf1, (intptr_t)368, pbuf2, (intptr_t)368, 360, 8, &res_u_a, &res_v_a );
    }
    report( "ssd_nv12 :" );

    if( pixel_asm.ssim_4x4x2_core != pixel_ref.ssim_4x4x2_core ||
        pixel_asm.ssim_end4 != pixel_ref.ssim_end4 )
    {
        int cnt;
        float res_c, res_a;
        ALIGNED_16( int sums[5][4] ) = {{0}};
        used_asm = ok = 1;
        x264_emms();
        res_c = x264_pixel_ssim_wxh( &pixel_c,   pbuf1+2, 32, pbuf2+2, 32, 32, 28, pbuf3, &cnt );
        res_a = x264_pixel_ssim_wxh( &pixel_asm, pbuf1+2, 32, pbuf2+2, 32, 32, 28, pbuf3, &cnt );
        if( fabs( res_c - res_a ) > 1e-5 )
        {
            ok = 0;
            fprintf( stderr, "ssim: %.7f != %.7f [FAILED]\n", res_c, res_a );
        }
        set_func_name( "ssim_core" );
        call_c( pixel_c.ssim_4x4x2_core,   pbuf1+2, (intptr_t)32, pbuf2+2, (intptr_t)32, sums );
        call_a( pixel_asm.ssim_4x4x2_core, pbuf1+2, (intptr_t)32, pbuf2+2, (intptr_t)32, sums );
        set_func_name( "ssim_end" );
        call_c2( pixel_c.ssim_end4,   sums, sums, 4 );
        call_a2( pixel_asm.ssim_end4, sums, sums, 4 );
        /* check incorrect assumptions that 32-bit ints are zero-extended to 64-bit */
        call_c1( pixel_c.ssim_end4,   sums, sums, 3 );
        call_a1( pixel_asm.ssim_end4, sums, sums, 3 );
        report( "ssim :" );
    }

    ok = 1; used_asm = 0;
    for( int i = 0; i < 32; i++ )
        cost_mv[i] = rand30() & 0xffff;
    for( int i = 0; i < 100 && ok; i++ )
        if( pixel_asm.ads[i&3] != pixel_ref.ads[i&3] )
        {
            ALIGNED_16( uint16_t sums[72] );
            ALIGNED_16( int dc[4] );
            ALIGNED_16( int16_t mvs_a[48] );
            ALIGNED_16( int16_t mvs_c[48] );
            int mvn_a, mvn_c;
            int thresh = (rand() % 257) * PIXEL_MAX + (rand30() & 0xffff);
            set_func_name( "esa_ads_%s", pixel_names[i&3] );
            if( i < 40 )
            {
                for( int j = 0; j < 72; j++ )
                    sums[j] = (rand() % 9) * 8 * PIXEL_MAX;
                for( int j = 0; j < 4; j++ )
                    dc[j]   = (rand() % 9) * 8 * PIXEL_MAX;
            }
            else
            {
#if BIT_DEPTH + 6 > 15
                for( int j = 0; j < 72; j++ )
                    sums[j] = rand30() & ((1 << (BIT_DEPTH + 6))-1);
                for( int j = 0; j < 4; j++ )
                    dc[j]   = rand30() & ((1 << (BIT_DEPTH + 6))-1);
#else
                for( int j = 0; j < 72; j++ )
                    sums[j] = rand() & ((1 << (BIT_DEPTH + 6))-1);
                for( int j = 0; j < 4; j++ )
                    dc[j]   = rand() & ((1 << (BIT_DEPTH + 6))-1);
#endif
            }
            used_asm = 1;
            mvn_c = call_c( pixel_c.ads[i&3], dc, sums, 32, cost_mv, mvs_c, 28, thresh );
            mvn_a = call_a( pixel_asm.ads[i&3], dc, sums, 32, cost_mv, mvs_a, 28, thresh );
            if( mvn_c != mvn_a || memcmp( mvs_c, mvs_a, mvn_c*sizeof(*mvs_c) ) )
            {
                ok = 0;
                fprintf( stderr, "thresh: %d\n", thresh );
                fprintf( stderr, "c%d: ", i&3 );
                for( int j = 0; j < mvn_c; j++ )
                    fprintf( stderr, "%d ", mvs_c[j] );
                fprintf( stderr, "\na%d: ", i&3 );
                for( int j = 0; j < mvn_a; j++ )
                    fprintf( stderr, "%d ", mvs_a[j] );
                fprintf( stderr, "\n\n" );
            }
        }
    report( "esa ads:" );

    return ret;
}

static int check_dct( uint32_t cpu_ref, uint32_t cpu_new )
{
    x264_dct_function_t dct_c;
    x264_dct_function_t dct_ref;
    x264_dct_function_t dct_asm;
    x264_quant_function_t qf;
    int ret = 0, ok, used_asm, interlace = 0;
    ALIGNED_ARRAY_64( dctcoef, dct1, [16],[16] );
    ALIGNED_ARRAY_64( dctcoef, dct2, [16],[16] );
    ALIGNED_ARRAY_64( dctcoef, dct4, [16],[16] );
    ALIGNED_ARRAY_64( dctcoef, dct8, [4],[64] );
    ALIGNED_16( dctcoef dctdc[2][8] );
    x264_t h_buf;
    x264_t *h = &h_buf;

    x264_dct_init( 0, &dct_c );
    x264_dct_init( cpu_ref, &dct_ref);
    x264_dct_init( cpu_new, &dct_asm );

    memset( h, 0, sizeof(*h) );
    x264_param_default( &h->param );
    h->sps->i_chroma_format_idc = 1;
    h->chroma_qp_table = i_chroma_qp_table + 12;
    h->param.analyse.i_luma_deadzone[0] = 0;
    h->param.analyse.i_luma_deadzone[1] = 0;
    h->param.analyse.b_transform_8x8 = 1;
    for( int i = 0; i < 8; i++ )
        h->sps->scaling_list[i] = x264_cqm_flat16;
    x264_cqm_init( h );
    x264_quant_init( h, 0, &qf );

    /* overflow test cases */
    for( int i = 0; i < 5; i++ )
    {
        pixel *enc = &pbuf3[16*i*FENC_STRIDE];
        pixel *dec = &pbuf4[16*i*FDEC_STRIDE];

        for( int j = 0; j < 16; j++ )
        {
            int cond_a = (i < 2) ? 1 : ((j&3) == 0 || (j&3) == (i-1));
            int cond_b = (i == 0) ? 1 : !cond_a;
            enc[0] = enc[1] = enc[4] = enc[5] = enc[8] = enc[9] = enc[12] = enc[13] = cond_a ? PIXEL_MAX : 0;
            enc[2] = enc[3] = enc[6] = enc[7] = enc[10] = enc[11] = enc[14] = enc[15] = cond_b ? PIXEL_MAX : 0;

            for( int k = 0; k < 4; k++ )
                dec[k] = PIXEL_MAX - enc[k];

            enc += FENC_STRIDE;
            dec += FDEC_STRIDE;
        }
    }

#define TEST_DCT( name, t1, t2, size ) \
    if( dct_asm.name != dct_ref.name ) \
    { \
        set_func_name( #name ); \
        used_asm = 1; \
        pixel *enc = pbuf3; \
        pixel *dec = pbuf4; \
        for( int j = 0; j < 5; j++) \
        { \
            call_c( dct_c.name, t1, &pbuf1[j*64], &pbuf2[j*64] ); \
            call_a( dct_asm.name, t2, &pbuf1[j*64], &pbuf2[j*64] ); \
            if( memcmp( t1, t2, size*sizeof(dctcoef) ) ) \
            { \
                ok = 0; \
                fprintf( stderr, #name " [FAILED]\n" ); \
                for( int k = 0; k < size; k++ )\
                    fprintf( stderr, "%d ", ((dctcoef*)t1)[k] );\
                fprintf( stderr, "\n" );\
                for( int k = 0; k < size; k++ )\
                    fprintf( stderr, "%d ", ((dctcoef*)t2)[k] );\
                fprintf( stderr, "\n" );\
                break; \
            } \
            call_c( dct_c.name, t1, enc, dec ); \
            call_a( dct_asm.name, t2, enc, dec ); \
            if( memcmp( t1, t2, size*sizeof(dctcoef) ) ) \
            { \
                ok = 0; \
                fprintf( stderr, #name " [FAILED] (overflow)\n" ); \
                break; \
            } \
            enc += 16*FENC_STRIDE; \
            dec += 16*FDEC_STRIDE; \
        } \
    }
    ok = 1; used_asm = 0;
    TEST_DCT( sub4x4_dct, dct1[0], dct2[0], 16 );
    TEST_DCT( sub8x8_dct, dct1, dct2, 16*4 );
    TEST_DCT( sub8x8_dct_dc, dctdc[0], dctdc[1], 4 );
    TEST_DCT( sub8x16_dct_dc, dctdc[0], dctdc[1], 8 );
    TEST_DCT( sub16x16_dct, dct1, dct2, 16*16 );
    report( "sub_dct4 :" );

    ok = 1; used_asm = 0;
    TEST_DCT( sub8x8_dct8, (void*)dct1[0], (void*)dct2[0], 64 );
    TEST_DCT( sub16x16_dct8, (void*)dct1, (void*)dct2, 64*4 );
    report( "sub_dct8 :" );
#undef TEST_DCT

    // fdct and idct are denormalized by different factors, so quant/dequant
    // is needed to force the coefs into the right range.
    dct_c.sub16x16_dct( dct4, pbuf1, pbuf2 );
    dct_c.sub16x16_dct8( dct8, pbuf1, pbuf2 );
    for( int i = 0; i < 16; i++ )
    {
        qf.quant_4x4( dct4[i], h->quant4_mf[CQM_4IY][20], h->quant4_bias[CQM_4IY][20] );
        qf.dequant_4x4( dct4[i], h->dequant4_mf[CQM_4IY], 20 );
    }
    for( int i = 0; i < 4; i++ )
    {
        qf.quant_8x8( dct8[i], h->quant8_mf[CQM_8IY][20], h->quant8_bias[CQM_8IY][20] );
        qf.dequant_8x8( dct8[i], h->dequant8_mf[CQM_8IY], 20 );
    }
    x264_cqm_delete( h );

#define TEST_IDCT( name, src ) \
    if( dct_asm.name != dct_ref.name ) \
    { \
        set_func_name( #name ); \
        used_asm = 1; \
        memcpy( pbuf3, pbuf1, 32*32 * SIZEOF_PIXEL ); \
        memcpy( pbuf4, pbuf1, 32*32 * SIZEOF_PIXEL ); \
        memcpy( dct1, src, 256 * sizeof(dctcoef) ); \
        memcpy( dct2, src, 256 * sizeof(dctcoef) ); \
        call_c1( dct_c.name, pbuf3, (void*)dct1 ); \
        call_a1( dct_asm.name, pbuf4, (void*)dct2 ); \
        if( memcmp( pbuf3, pbuf4, 32*32 * SIZEOF_PIXEL ) ) \
        { \
            ok = 0; \
            fprintf( stderr, #name " [FAILED]\n" ); \
        } \
        call_c2( dct_c.name, pbuf3, (void*)dct1 ); \
        call_a2( dct_asm.name, pbuf4, (void*)dct2 ); \
    }
    ok = 1; used_asm = 0;
    TEST_IDCT( add4x4_idct, dct4 );
    TEST_IDCT( add8x8_idct, dct4 );
    TEST_IDCT( add8x8_idct_dc, dct4 );
    TEST_IDCT( add16x16_idct, dct4 );
    TEST_IDCT( add16x16_idct_dc, dct4 );
    report( "add_idct4 :" );

    ok = 1; used_asm = 0;
    TEST_IDCT( add8x8_idct8, dct8 );
    TEST_IDCT( add16x16_idct8, dct8 );
    report( "add_idct8 :" );
#undef TEST_IDCT

#define TEST_DCTDC( name )\
    ok = 1; used_asm = 0;\
    if( dct_asm.name != dct_ref.name )\
    {\
        set_func_name( #name );\
        used_asm = 1;\
        uint16_t *p = (uint16_t*)buf1;\
        for( int i = 0; i < 16 && ok; i++ )\
        {\
            for( int j = 0; j < 16; j++ )\
                dct1[0][j] = !i ? (j^j>>1^j>>2^j>>3)&1 ? PIXEL_MAX*16 : -PIXEL_MAX*16 /* max dc */\
                           : i<8 ? (*p++)&1 ? PIXEL_MAX*16 : -PIXEL_MAX*16 /* max elements */\
                           : ((*p++)&0x1fff)-0x1000; /* general case */\
            memcpy( dct2, dct1, 16 * sizeof(dctcoef) );\
            call_c1( dct_c.name, dct1[0] );\
            call_a1( dct_asm.name, dct2[0] );\
            if( memcmp( dct1, dct2, 16 * sizeof(dctcoef) ) )\
                ok = 0;\
        }\
        call_c2( dct_c.name, dct1[0] );\
        call_a2( dct_asm.name, dct2[0] );\
    }\
    report( #name " :" );

    TEST_DCTDC(  dct4x4dc );
    TEST_DCTDC( idct4x4dc );
#undef TEST_DCTDC

#define TEST_DCTDC_CHROMA( name )\
    ok = 1; used_asm = 0;\
    if( dct_asm.name != dct_ref.name )\
    {\
        set_func_name( #name );\
        used_asm = 1;\
        uint16_t *p = (uint16_t*)buf1;\
        for( int i = 0; i < 16 && ok; i++ )\
        {\
            for( int j = 0; j < 8; j++ )\
                dct1[j][0] = !i ? (j^j>>1^j>>2)&1 ? PIXEL_MAX*16 : -PIXEL_MAX*16 /* max dc */\
                           : i<8 ? (*p++)&1 ? PIXEL_MAX*16 : -PIXEL_MAX*16 /* max elements */\
                           : ((*p++)&0x1fff)-0x1000; /* general case */\
            memcpy( dct2, dct1, 8*16 * sizeof(dctcoef) );\
            call_c1( dct_c.name, dctdc[0], dct1 );\
            call_a1( dct_asm.name, dctdc[1], dct2 );\
            if( memcmp( dctdc[0], dctdc[1], 8 * sizeof(dctcoef) ) || memcmp( dct1, dct2, 8*16 * sizeof(dctcoef) ) )\
            {\
                ok = 0;\
                fprintf( stderr, #name " [FAILED]\n" ); \
            }\
        }\
        call_c2( dct_c.name, dctdc[0], dct1 );\
        call_a2( dct_asm.name, dctdc[1], dct2 );\
    }\
    report( #name " :" );

    TEST_DCTDC_CHROMA( dct2x4dc );
#undef TEST_DCTDC_CHROMA

    x264_zigzag_function_t zigzag_c[2];
    x264_zigzag_function_t zigzag_ref[2];
    x264_zigzag_function_t zigzag_asm[2];

    ALIGNED_ARRAY_64( dctcoef, level1,[64] );
    ALIGNED_ARRAY_64( dctcoef, level2,[64] );

#define TEST_ZIGZAG_SCAN( name, t1, t2, dct, size ) \
    if( zigzag_asm[interlace].name != zigzag_ref[interlace].name ) \
    { \
        set_func_name( "zigzag_"#name"_%s", interlace?"field":"frame" ); \
        used_asm = 1; \
        for( int i = 0; i < size*size; i++ ) \
            dct[i] = i; \
        call_c( zigzag_c[interlace].name, t1, dct ); \
        call_a( zigzag_asm[interlace].name, t2, dct ); \
        if( memcmp( t1, t2, size*size*sizeof(dctcoef) ) ) \
        { \
            ok = 0; \
            for( int i = 0; i < 2; i++ ) \
            { \
                dctcoef *d = (dctcoef*)(i ? t2 : t1); \
                for( int j = 0; j < size; j++ ) \
                { \
                    for( int k = 0; k < size; k++ ) \
                        fprintf( stderr, "%2d ", d[k+j*8] ); \
                    fprintf( stderr, "\n" ); \
                } \
                fprintf( stderr, "\n" ); \
            } \
            fprintf( stderr, #name " [FAILED]\n" ); \
        } \
    }

#define TEST_ZIGZAG_SUB( name, t1, t2, size ) \
    if( zigzag_asm[interlace].name != zigzag_ref[interlace].name ) \
    { \
        int nz_a, nz_c; \
        set_func_name( "zigzag_"#name"_%s", interlace?"field":"frame" ); \
        used_asm = 1; \
        memcpy( pbuf3, pbuf1, 16*FDEC_STRIDE * SIZEOF_PIXEL ); \
        memcpy( pbuf4, pbuf1, 16*FDEC_STRIDE * SIZEOF_PIXEL ); \
        nz_c = call_c1( zigzag_c[interlace].name, t1, pbuf2, pbuf3 ); \
        nz_a = call_a1( zigzag_asm[interlace].name, t2, pbuf2, pbuf4 ); \
        if( memcmp( t1, t2, size*sizeof(dctcoef) ) || memcmp( pbuf3, pbuf4, 16*FDEC_STRIDE*SIZEOF_PIXEL ) || nz_c != nz_a ) \
        { \
            ok = 0; \
            fprintf( stderr, #name " [FAILED]\n" ); \
        } \
        call_c2( zigzag_c[interlace].name, t1, pbuf2, pbuf3 ); \
        call_a2( zigzag_asm[interlace].name, t2, pbuf2, pbuf4 ); \
    }

#define TEST_ZIGZAG_SUBAC( name, t1, t2 ) \
    if( zigzag_asm[interlace].name != zigzag_ref[interlace].name ) \
    { \
        int nz_a, nz_c; \
        dctcoef dc_a, dc_c; \
        set_func_name( "zigzag_"#name"_%s", interlace?"field":"frame" ); \
        used_asm = 1; \
        for( int i = 0; i < 2; i++ ) \
        { \
            memcpy( pbuf3, pbuf2, 16*FDEC_STRIDE * SIZEOF_PIXEL ); \
            memcpy( pbuf4, pbuf2, 16*FDEC_STRIDE * SIZEOF_PIXEL ); \
            for( int j = 0; j < 4; j++ ) \
            { \
                memcpy( pbuf3 + j*FDEC_STRIDE, (i?pbuf1:pbuf2) + j*FENC_STRIDE, 4 * SIZEOF_PIXEL ); \
                memcpy( pbuf4 + j*FDEC_STRIDE, (i?pbuf1:pbuf2) + j*FENC_STRIDE, 4 * SIZEOF_PIXEL ); \
            } \
            nz_c = call_c1( zigzag_c[interlace].name, t1, pbuf2, pbuf3, &dc_c ); \
            nz_a = call_a1( zigzag_asm[interlace].name, t2, pbuf2, pbuf4, &dc_a ); \
            if( memcmp( t1+1, t2+1, 15*sizeof(dctcoef) ) || memcmp( pbuf3, pbuf4, 16*FDEC_STRIDE * SIZEOF_PIXEL ) || nz_c != nz_a || dc_c != dc_a ) \
            { \
                ok = 0; \
                fprintf( stderr, #name " [FAILED]\n" ); \
                break; \
            } \
        } \
        call_c2( zigzag_c[interlace].name, t1, pbuf2, pbuf3, &dc_c ); \
        call_a2( zigzag_asm[interlace].name, t2, pbuf2, pbuf4, &dc_a ); \
    }

#define TEST_INTERLEAVE( name, t1, t2, dct, size ) \
    if( zigzag_asm[interlace].name != zigzag_ref[interlace].name ) \
    { \
        for( int j = 0; j < 100; j++ ) \
        { \
            set_func_name( "zigzag_"#name"_%s", interlace?"field":"frame" ); \
            used_asm = 1; \
            memcpy(dct, buf1, size*sizeof(dctcoef)); \
            for( int i = 0; i < size; i++ ) \
                dct[i] = rand()&0x1F ? 0 : dct[i]; \
            memcpy(buf3, buf4, 10); \
            call_c( zigzag_c[interlace].name, t1, dct, buf3 ); \
            call_a( zigzag_asm[interlace].name, t2, dct, buf4 ); \
            if( memcmp( t1, t2, size*sizeof(dctcoef) ) || memcmp( buf3, buf4, 10 ) ) \
            { \
                ok = 0; \
                fprintf( stderr, "%d: %d %d %d %d\n%d %d %d %d\n\n", memcmp( t1, t2, size*sizeof(dctcoef) ), buf3[0], buf3[1], buf3[8], buf3[9], buf4[0], buf4[1], buf4[8], buf4[9] ); \
                break; \
            } \
        } \
    }

    x264_zigzag_init( 0, &zigzag_c[0], &zigzag_c[1] );
    x264_zigzag_init( cpu_ref, &zigzag_ref[0], &zigzag_ref[1] );
    x264_zigzag_init( cpu_new, &zigzag_asm[0], &zigzag_asm[1] );

    ok = 1; used_asm = 0;
    TEST_INTERLEAVE( interleave_8x8_cavlc, level1, level2, dct8[0], 64 );
    report( "zigzag_interleave :" );

    for( interlace = 0; interlace <= 1; interlace++ )
    {
        ok = 1; used_asm = 0;
        TEST_ZIGZAG_SCAN( scan_8x8, level1, level2, dct8[0], 8 );
        TEST_ZIGZAG_SCAN( scan_4x4, level1, level2, dct1[0], 4 );
        TEST_ZIGZAG_SUB( sub_4x4, level1, level2, 16 );
        TEST_ZIGZAG_SUB( sub_8x8, level1, level2, 64 );
        TEST_ZIGZAG_SUBAC( sub_4x4ac, level1, level2 );
        report( interlace ? "zigzag_field :" : "zigzag_frame :" );
    }
#undef TEST_ZIGZAG_SCAN
#undef TEST_ZIGZAG_SUB

    return ret;
}

static int check_mc( uint32_t cpu_ref, uint32_t cpu_new )
{
    x264_mc_functions_t mc_c;
    x264_mc_functions_t mc_ref;
    x264_mc_functions_t mc_a;
    x264_pixel_function_t pixf;

    pixel *src     = &(pbuf1)[2*64+2];
    pixel *src2[4] = { &(pbuf1)[3*64+2], &(pbuf1)[5*64+2],
                       &(pbuf1)[7*64+2], &(pbuf1)[9*64+2] };
    pixel *dst1    = pbuf3;
    pixel *dst2    = pbuf4;

    int ret = 0, ok, used_asm;

    x264_mc_init( 0, &mc_c, 0 );
    x264_mc_init( cpu_ref, &mc_ref, 0 );
    x264_mc_init( cpu_new, &mc_a, 0 );
    x264_pixel_init( 0, &pixf );

#define MC_TEST_LUMA( w, h ) \
        if( mc_a.mc_luma != mc_ref.mc_luma && !(w&(w-1)) && h<=16 ) \
        { \
            const x264_weight_t *weight = x264_weight_none; \
            set_func_name( "mc_luma_%dx%d", w, h ); \
            used_asm = 1; \
            for( int i = 0; i < 1024; i++ ) \
                pbuf3[i] = pbuf4[i] = 0xCD; \
            call_c( mc_c.mc_luma, dst1, (intptr_t)32, src2, (intptr_t)64, dx, dy, w, h, weight ); \
            call_a( mc_a.mc_luma, dst2, (intptr_t)32, src2, (intptr_t)64, dx, dy, w, h, weight ); \
            if( memcmp( pbuf3, pbuf4, 1024 * SIZEOF_PIXEL ) ) \
            { \
                fprintf( stderr, "mc_luma[mv(%d,%d) %2dx%-2d]     [FAILED]\n", dx, dy, w, h ); \
                ok = 0; \
            } \
        } \
        if( mc_a.get_ref != mc_ref.get_ref ) \
        { \
            pixel *ref = dst2; \
            intptr_t ref_stride = 32; \
            int w_checked = ( ( SIZEOF_PIXEL == 2 && (w == 12 || w == 20)) ? w-2 : w ); \
            const x264_weight_t *weight = x264_weight_none; \
            set_func_name( "get_ref_%dx%d", w_checked, h ); \
            used_asm = 1; \
            for( int i = 0; i < 1024; i++ ) \
                pbuf3[i] = pbuf4[i] = 0xCD; \
            call_c( mc_c.mc_luma, dst1, (intptr_t)32, src2, (intptr_t)64, dx, dy, w, h, weight ); \
            ref = (pixel*)call_a( mc_a.get_ref, ref, &ref_stride, src2, (intptr_t)64, dx, dy, w, h, weight ); \
            for( int i = 0; i < h; i++ ) \
                if( memcmp( dst1+i*32, ref+i*ref_stride, w_checked * SIZEOF_PIXEL ) ) \
                { \
                    fprintf( stderr, "get_ref[mv(%d,%d) %2dx%-2d]     [FAILED]\n", dx, dy, w_checked, h ); \
                    ok = 0; \
                    break; \
                } \
        }

#define MC_TEST_CHROMA( w, h ) \
        if( mc_a.mc_chroma != mc_ref.mc_chroma ) \
        { \
            set_func_name( "mc_chroma_%dx%d", w, h ); \
            used_asm = 1; \
            for( int i = 0; i < 1024; i++ ) \
                pbuf3[i] = pbuf4[i] = 0xCD; \
            call_c( mc_c.mc_chroma, dst1, dst1+8, (intptr_t)16, src, (intptr_t)64, dx, dy, w, h ); \
            call_a( mc_a.mc_chroma, dst2, dst2+8, (intptr_t)16, src, (intptr_t)64, dx, dy, w, h ); \
            /* mc_chroma width=2 may write garbage to the right of dst. ignore that. */ \
            for( int j = 0; j < h; j++ ) \
                for( int i = w; i < 8; i++ ) \
                { \
                    dst2[i+j*16+8] = dst1[i+j*16+8]; \
                    dst2[i+j*16  ] = dst1[i+j*16  ]; \
                } \
            if( memcmp( pbuf3, pbuf4, 1024 * SIZEOF_PIXEL ) ) \
            { \
                fprintf( stderr, "mc_chroma[mv(%d,%d) %2dx%-2d]     [FAILED]\n", dx, dy, w, h ); \
                ok = 0; \
            } \
        }
    ok = 1; used_asm = 0;
    for( int dy = -8; dy < 8; dy++ )
        for( int dx = -128; dx < 128; dx++ )
        {
            if( rand()&15 ) continue; // running all of them is too slow
            MC_TEST_LUMA( 20, 18 );
            MC_TEST_LUMA( 16, 16 );
            MC_TEST_LUMA( 16, 8 );
            MC_TEST_LUMA( 12, 10 );
            MC_TEST_LUMA( 8, 16 );
            MC_TEST_LUMA( 8, 8 );
            MC_TEST_LUMA( 8, 4 );
            MC_TEST_LUMA( 4, 8 );
            MC_TEST_LUMA( 4, 4 );
        }
    report( "mc luma :" );

    ok = 1; used_asm = 0;
    for( int dy = -1; dy < 9; dy++ )
        for( int dx = -128; dx < 128; dx++ )
        {
            if( rand()&15 ) continue;
            MC_TEST_CHROMA( 8, 8 );
            MC_TEST_CHROMA( 8, 4 );
            MC_TEST_CHROMA( 4, 8 );
            MC_TEST_CHROMA( 4, 4 );
            MC_TEST_CHROMA( 4, 2 );
            MC_TEST_CHROMA( 2, 4 );
            MC_TEST_CHROMA( 2, 2 );
        }
    report( "mc chroma :" );
#undef MC_TEST_LUMA
#undef MC_TEST_CHROMA

#define MC_TEST_AVG( name, weight ) \
{ \
    for( int i = 0; i < 12; i++ ) \
    { \
        memcpy( pbuf3, pbuf1+320, 320 * SIZEOF_PIXEL ); \
        memcpy( pbuf4, pbuf1+320, 320 * SIZEOF_PIXEL ); \
        if( mc_a.name[i] != mc_ref.name[i] ) \
        { \
            set_func_name( "%s_%s", #name, pixel_names[i] ); \
            used_asm = 1; \
            call_c1( mc_c.name[i], pbuf3, (intptr_t)16, pbuf2+1, (intptr_t)16, pbuf1+18, (intptr_t)16, weight ); \
            call_a1( mc_a.name[i], pbuf4, (intptr_t)16, pbuf2+1, (intptr_t)16, pbuf1+18, (intptr_t)16, weight ); \
            if( memcmp( pbuf3, pbuf4, 320 * SIZEOF_PIXEL ) ) \
            { \
                ok = 0; \
                fprintf( stderr, #name "[%d]: [FAILED]\n", i ); \
            } \
            call_c2( mc_c.name[i], pbuf3, (intptr_t)16, pbuf2+1, (intptr_t)16, pbuf1+18, (intptr_t)16, weight ); \
            call_a2( mc_a.name[i], pbuf4, (intptr_t)16, pbuf2+1, (intptr_t)16, pbuf1+18, (intptr_t)16, weight ); \
        } \
    } \
}

    ok = 1, used_asm = 0;
    for( int w = -63; w <= 127 && ok; w++ )
        MC_TEST_AVG( avg, w );
    report( "mc wpredb :" );

#define MC_TEST_WEIGHT( name, weight, aligned ) \
    int align_off = (aligned ? 0 : rand()%16); \
    for( int i = 1; i <= 5; i++ ) \
    { \
        ALIGNED_16( pixel buffC[640] ); \
        ALIGNED_16( pixel buffA[640] ); \
        int j = X264_MAX( i*4, 2 ); \
        memset( buffC, 0, 640 * SIZEOF_PIXEL ); \
        memset( buffA, 0, 640 * SIZEOF_PIXEL ); \
        x264_t ha; \
        ha.mc = mc_a; \
        /* w12 is the same as w16 in some cases */ \
        if( i == 3 && mc_a.name[i] == mc_a.name[i+1] ) \
            continue; \
        if( mc_a.name[i] != mc_ref.name[i] ) \
        { \
            set_func_name( "%s_w%d", #name, j ); \
            used_asm = 1; \
            call_c1( mc_c.weight[i],     buffC, (intptr_t)32, pbuf2+align_off, (intptr_t)32, &weight, 16 ); \
            mc_a.weight_cache(&ha, &weight); \
            call_a1( weight.weightfn[i], buffA, (intptr_t)32, pbuf2+align_off, (intptr_t)32, &weight, 16 ); \
            for( int k = 0; k < 16; k++ ) \
                if( memcmp( &buffC[k*32], &buffA[k*32], j * SIZEOF_PIXEL ) ) \
                { \
                    ok = 0; \
                    fprintf( stderr, #name "[%d]: [FAILED] s:%d o:%d d%d\n", i, s, o, d ); \
                    break; \
                } \
            /* omit unlikely high scales for benchmarking */ \
            if( (s << (8-d)) < 512 ) \
            { \
                call_c2( mc_c.weight[i],     buffC, (intptr_t)32, pbuf2+align_off, (intptr_t)32, &weight, 16 ); \
                call_a2( weight.weightfn[i], buffA, (intptr_t)32, pbuf2+align_off, (intptr_t)32, &weight, 16 ); \
            } \
        } \
    }

    ok = 1; used_asm = 0;

    int align_cnt = 0;
    for( int s = 0; s <= 127 && ok; s++ )
    {
        for( int o = -128; o <= 127 && ok; o++ )
        {
            if( rand() & 2047 ) continue;
            for( int d = 0; d <= 7 && ok; d++ )
            {
                if( s == 1<<d )
                    continue;
                x264_weight_t weight = { .i_scale = s, .i_denom = d, .i_offset = o };
                MC_TEST_WEIGHT( weight, weight, (align_cnt++ % 4) );
            }
        }

    }
    report( "mc weight :" );

    ok = 1; used_asm = 0;
    for( int o = 0; o <= 127 && ok; o++ )
    {
        int s = 1, d = 0;
        if( rand() & 15 ) continue;
        x264_weight_t weight = { .i_scale = 1, .i_denom = 0, .i_offset = o };
        MC_TEST_WEIGHT( offsetadd, weight, (align_cnt++ % 4) );
    }
    report( "mc offsetadd :" );
    ok = 1; used_asm = 0;
    for( int o = -128; o < 0 && ok; o++ )
    {
        int s = 1, d = 0;
        if( rand() & 15 ) continue;
        x264_weight_t weight = { .i_scale = 1, .i_denom = 0, .i_offset = o };
        MC_TEST_WEIGHT( offsetsub, weight, (align_cnt++ % 4) );
    }
    report( "mc offsetsub :" );

    memset( pbuf3, 0, 64*16 );
    memset( pbuf4, 0, 64*16 );
    ok = 1; used_asm = 0;
    for( int height = 8; height <= 16; height += 8 )
    {
        if( mc_a.store_interleave_chroma != mc_ref.store_interleave_chroma )
        {
            set_func_name( "store_interleave_chroma" );
            used_asm = 1;
            call_c( mc_c.store_interleave_chroma, pbuf3, (intptr_t)64, pbuf1, pbuf1+16, height );
            call_a( mc_a.store_interleave_chroma, pbuf4, (intptr_t)64, pbuf1, pbuf1+16, height );
            if( memcmp( pbuf3, pbuf4, 64*height ) )
            {
                ok = 0;
                fprintf( stderr, "store_interleave_chroma FAILED: h=%d\n", height );
                break;
            }
        }
        if( mc_a.load_deinterleave_chroma_fenc != mc_ref.load_deinterleave_chroma_fenc )
        {
            set_func_name( "load_deinterleave_chroma_fenc" );
            used_asm = 1;
            call_c( mc_c.load_deinterleave_chroma_fenc, pbuf3, pbuf1, (intptr_t)64, height );
            call_a( mc_a.load_deinterleave_chroma_fenc, pbuf4, pbuf1, (intptr_t)64, height );
            if( memcmp( pbuf3, pbuf4, FENC_STRIDE*height ) )
            {
                ok = 0;
                fprintf( stderr, "load_deinterleave_chroma_fenc FAILED: h=%d\n", height );
                break;
            }
        }
        if( mc_a.load_deinterleave_chroma_fdec != mc_ref.load_deinterleave_chroma_fdec )
        {
            set_func_name( "load_deinterleave_chroma_fdec" );
            used_asm = 1;
            call_c( mc_c.load_deinterleave_chroma_fdec, pbuf3, pbuf1, (intptr_t)64, height );
            call_a( mc_a.load_deinterleave_chroma_fdec, pbuf4, pbuf1, (intptr_t)64, height );
            if( memcmp( pbuf3, pbuf4, FDEC_STRIDE*height ) )
            {
                ok = 0;
                fprintf( stderr, "load_deinterleave_chroma_fdec FAILED: h=%d\n", height );
                break;
            }
        }
    }
    report( "store_interleave :" );

    struct plane_spec {
        int w, h, src_stride;
    } plane_specs[] = { {2,2,2}, {8,6,8}, {20,31,24}, {32,8,40}, {256,10,272}, {504,7,505}, {528,6,528}, {256,10,-256}, {263,9,-264}, {1904,1,0} };
    ok = 1; used_asm = 0;
    if( mc_a.plane_copy != mc_ref.plane_copy )
    {
        set_func_name( "plane_copy" );
        used_asm = 1;
        for( int i = 0; i < ARRAY_ELEMS(plane_specs); i++ )
        {
            int w = plane_specs[i].w;
            int h = plane_specs[i].h;
            intptr_t src_stride = plane_specs[i].src_stride;
            intptr_t dst_stride = (w + 127) & ~63;
            assert( dst_stride * h <= 0x1000 );
            pixel *src1 = pbuf1 + X264_MAX(0, -src_stride) * (h-1);
            memset( pbuf3, 0, 0x1000*SIZEOF_PIXEL );
            memset( pbuf4, 0, 0x1000*SIZEOF_PIXEL );
            call_c( mc_c.plane_copy, pbuf3, dst_stride, src1, src_stride, w, h );
            call_a( mc_a.plane_copy, pbuf4, dst_stride, src1, src_stride, w, h );
            for( int y = 0; y < h; y++ )
                if( memcmp( pbuf3+y*dst_stride, pbuf4+y*dst_stride, w*SIZEOF_PIXEL ) )
                {
                    ok = 0;
                    fprintf( stderr, "plane_copy FAILED: w=%d h=%d stride=%d\n", w, h, (int)src_stride );
                    break;
                }
        }
    }

    if( mc_a.plane_copy_swap != mc_ref.plane_copy_swap )
    {
        set_func_name( "plane_copy_swap" );
        used_asm = 1;
        for( int i = 0; i < ARRAY_ELEMS(plane_specs); i++ )
        {
            int w = (plane_specs[i].w + 1) >> 1;
            int h = plane_specs[i].h;
            intptr_t src_stride = plane_specs[i].src_stride;
            intptr_t dst_stride = (2*w + 127) & ~63;
            assert( dst_stride * h <= 0x1000 );
            pixel *src1 = pbuf1 + X264_MAX(0, -src_stride) * (h-1);
            memset( pbuf3, 0, 0x1000*SIZEOF_PIXEL );
            memset( pbuf4, 0, 0x1000*SIZEOF_PIXEL );
            call_c( mc_c.plane_copy_swap, pbuf3, dst_stride, src1, src_stride, w, h );
            call_a( mc_a.plane_copy_swap, pbuf4, dst_stride, src1, src_stride, w, h );
            for( int y = 0; y < h; y++ )
                if( memcmp( pbuf3+y*dst_stride, pbuf4+y*dst_stride, 2*w*SIZEOF_PIXEL ) )
                {
                    ok = 0;
                    fprintf( stderr, "plane_copy_swap FAILED: w=%d h=%d stride=%d\n", w, h, (int)src_stride );
                    break;
                }
        }
    }

    if( mc_a.plane_copy_interleave != mc_ref.plane_copy_interleave )
    {
        set_func_name( "plane_copy_interleave" );
        used_asm = 1;
        for( int i = 0; i < ARRAY_ELEMS(plane_specs); i++ )
        {
            int w = (plane_specs[i].w + 1) >> 1;
            int h = plane_specs[i].h;
            intptr_t src_stride = (plane_specs[i].src_stride + 1) >> 1;
            intptr_t dst_stride = (2*w + 127) & ~63;
            assert( dst_stride * h <= 0x1000 );
            pixel *src1 = pbuf1 + X264_MAX(0, -src_stride) * (h-1);
            memset( pbuf3, 0, 0x1000*SIZEOF_PIXEL );
            memset( pbuf4, 0, 0x1000*SIZEOF_PIXEL );
            call_c( mc_c.plane_copy_interleave, pbuf3, dst_stride, src1, src_stride, src1+1024, src_stride+16, w, h );
            call_a( mc_a.plane_copy_interleave, pbuf4, dst_stride, src1, src_stride, src1+1024, src_stride+16, w, h );
            for( int y = 0; y < h; y++ )
                if( memcmp( pbuf3+y*dst_stride, pbuf4+y*dst_stride, 2*w*SIZEOF_PIXEL ) )
                {
                    ok = 0;
                    fprintf( stderr, "plane_copy_interleave FAILED: w=%d h=%d stride=%d\n", w, h, (int)src_stride );
                    break;
                }
        }
    }

    if( mc_a.plane_copy_deinterleave != mc_ref.plane_copy_deinterleave )
    {
        set_func_name( "plane_copy_deinterleave" );
        used_asm = 1;
        for( int i = 0; i < ARRAY_ELEMS(plane_specs); i++ )
        {
            int w = (plane_specs[i].w + 1) >> 1;
            int h = plane_specs[i].h;
            intptr_t dst_stride = w;
            intptr_t src_stride = (2*w + 127) & ~63;
            intptr_t offv = (dst_stride*h + 63) & ~31;
            memset( pbuf3, 0, 0x1000 );
            memset( pbuf4, 0, 0x1000 );
            call_c( mc_c.plane_copy_deinterleave, pbuf3, dst_stride, pbuf3+offv, dst_stride, pbuf1, src_stride, w, h );
            call_a( mc_a.plane_copy_deinterleave, pbuf4, dst_stride, pbuf4+offv, dst_stride, pbuf1, src_stride, w, h );
            for( int y = 0; y < h; y++ )
                if( memcmp( pbuf3+y*dst_stride,      pbuf4+y*dst_stride, w ) ||
                    memcmp( pbuf3+y*dst_stride+offv, pbuf4+y*dst_stride+offv, w ) )
                {
                    ok = 0;
                    fprintf( stderr, "plane_copy_deinterleave FAILED: w=%d h=%d stride=%d\n", w, h, (int)src_stride );
                    break;
                }
        }
    }

    if( mc_a.plane_copy_deinterleave_yuyv != mc_ref.plane_copy_deinterleave_yuyv )
    {
        set_func_name( "plane_copy_deinterleave_yuyv" );
        used_asm = 1;
        for( int i = 0; i < ARRAY_ELEMS(plane_specs); i++ )
        {
            int w = (plane_specs[i].w + 1) >> 1;
            int h = plane_specs[i].h;
            intptr_t dst_stride = ALIGN( w, 32/SIZEOF_PIXEL );
            intptr_t src_stride = (plane_specs[i].src_stride + 1) >> 1;
            intptr_t offv = dst_stride*h;
            pixel *src1 = pbuf1 + X264_MAX(0, -src_stride) * (h-1);
            memset( pbuf3, 0, 0x1000 );
            memset( pbuf4, 0, 0x1000 );
            /* Skip benchmarking since it's the same as plane_copy_deinterleave(), just verify correctness. */
            call_c1( mc_c.plane_copy_deinterleave_yuyv, pbuf3, dst_stride, pbuf3+offv, dst_stride, src1, src_stride, w, h );
            call_a1( mc_a.plane_copy_deinterleave_yuyv, pbuf4, dst_stride, pbuf4+offv, dst_stride, src1, src_stride, w, h );
            for( int y = 0; y < h; y++ )
                if( memcmp( pbuf3+y*dst_stride,      pbuf4+y*dst_stride,      w*SIZEOF_PIXEL ) ||
                    memcmp( pbuf3+y*dst_stride+offv, pbuf4+y*dst_stride+offv, w*SIZEOF_PIXEL ) )
                {
                    fprintf( stderr, "plane_copy_deinterleave_yuyv FAILED: w=%d h=%d stride=%d\n", w, h, (int)src_stride );
                    break;
                }
        }
    }

    if( mc_a.plane_copy_deinterleave_rgb != mc_ref.plane_copy_deinterleave_rgb )
    {
        set_func_name( "plane_copy_deinterleave_rgb" );
        used_asm = 1;
        for( int i = 0; i < ARRAY_ELEMS(plane_specs); i++ )
        {
            int w = (plane_specs[i].w + 2) >> 2;
            int h = plane_specs[i].h;
            intptr_t src_stride = plane_specs[i].src_stride;
            intptr_t dst_stride = ALIGN( w, 16 );
            intptr_t offv = dst_stride*h + 16;
            pixel *src1 = pbuf1 + X264_MAX(0, -src_stride) * (h-1);

            for( int pw = 3; pw <= 4; pw++ )
            {
                memset( pbuf3, 0, 0x1000 );
                memset( pbuf4, 0, 0x1000 );
                call_c( mc_c.plane_copy_deinterleave_rgb, pbuf3, dst_stride, pbuf3+offv, dst_stride, pbuf3+2*offv, dst_stride, src1, src_stride, pw, w, h );
                call_a( mc_a.plane_copy_deinterleave_rgb, pbuf4, dst_stride, pbuf4+offv, dst_stride, pbuf4+2*offv, dst_stride, src1, src_stride, pw, w, h );
                for( int y = 0; y < h; y++ )
                    if( memcmp( pbuf3+y*dst_stride+0*offv, pbuf4+y*dst_stride+0*offv, w ) ||
                        memcmp( pbuf3+y*dst_stride+1*offv, pbuf4+y*dst_stride+1*offv, w ) ||
                        memcmp( pbuf3+y*dst_stride+2*offv, pbuf4+y*dst_stride+2*offv, w ) )
                    {
                        ok = 0;
                        fprintf( stderr, "plane_copy_deinterleave_rgb FAILED: w=%d h=%d stride=%d pw=%d\n", w, h, (int)src_stride, pw );
                        break;
                    }
            }
        }
    }
    report( "plane_copy :" );

    if( mc_a.plane_copy_deinterleave_v210 != mc_ref.plane_copy_deinterleave_v210 )
    {
        set_func_name( "plane_copy_deinterleave_v210" );
        ok = 1; used_asm = 1;
        for( int i = 0; i < ARRAY_ELEMS(plane_specs); i++ )
        {
            int w = (plane_specs[i].w + 1) >> 1;
            int h = plane_specs[i].h;
            intptr_t dst_stride = ALIGN( w, 32 );
            intptr_t src_stride = (w + 47) / 48 * 128 / (int)sizeof(uint32_t);
            intptr_t offv = dst_stride*h + 32;
            memset( pbuf3, 0, 0x1000 );
            memset( pbuf4, 0, 0x1000 );
            call_c( mc_c.plane_copy_deinterleave_v210, pbuf3, dst_stride, pbuf3+offv, dst_stride, (uint32_t *)buf1, src_stride, w, h );
            call_a( mc_a.plane_copy_deinterleave_v210, pbuf4, dst_stride, pbuf4+offv, dst_stride, (uint32_t *)buf1, src_stride, w, h );
            for( int y = 0; y < h; y++ )
                if( memcmp( pbuf3+y*dst_stride,      pbuf4+y*dst_stride,      w*sizeof(uint16_t) ) ||
                    memcmp( pbuf3+y*dst_stride+offv, pbuf4+y*dst_stride+offv, w*sizeof(uint16_t) ) )
                {
                    ok = 0;
                    fprintf( stderr, "plane_copy_deinterleave_v210 FAILED: w=%d h=%d stride=%d\n", w, h, (int)src_stride );
                    break;
                }
        }
        report( "v210 :" );
    }

    if( mc_a.hpel_filter != mc_ref.hpel_filter )
    {
        pixel *srchpel = pbuf1+8+2*64;
        pixel *dstc[3] = { pbuf3+8, pbuf3+8+16*64, pbuf3+8+32*64 };
        pixel *dsta[3] = { pbuf4+8, pbuf4+8+16*64, pbuf4+8+32*64 };
        void *tmp = pbuf3+49*64;
        set_func_name( "hpel_filter" );
        ok = 1; used_asm = 1;
        memset( pbuf3, 0, 4096 * SIZEOF_PIXEL );
        memset( pbuf4, 0, 4096 * SIZEOF_PIXEL );
        call_c( mc_c.hpel_filter, dstc[0], dstc[1], dstc[2], srchpel, (intptr_t)64, 48, 10, tmp );
        call_a( mc_a.hpel_filter, dsta[0], dsta[1], dsta[2], srchpel, (intptr_t)64, 48, 10, tmp );
        for( int i = 0; i < 3; i++ )
            for( int j = 0; j < 10; j++ )
                //FIXME ideally the first pixels would match too, but they aren't actually used
                if( memcmp( dstc[i]+j*64+2, dsta[i]+j*64+2, 43 * SIZEOF_PIXEL ) )
                {
                    ok = 0;
                    fprintf( stderr, "hpel filter differs at plane %c line %d\n", "hvc"[i], j );
                    for( int k = 0; k < 48; k++ )
                        fprintf( stderr, FMT_PIXEL"%s", dstc[i][j*64+k], (k+1)&3 ? "" : " " );
                    fprintf( stderr, "\n" );
                    for( int k = 0; k < 48; k++ )
                        fprintf( stderr, FMT_PIXEL"%s", dsta[i][j*64+k], (k+1)&3 ? "" : " " );
                    fprintf( stderr, "\n" );
                    break;
                }
        report( "hpel filter :" );
    }

    if( mc_a.frame_init_lowres_core != mc_ref.frame_init_lowres_core )
    {
        pixel *dstc[4] = { pbuf3, pbuf3+1024, pbuf3+2048, pbuf3+3072 };
        pixel *dsta[4] = { pbuf4, pbuf4+1024, pbuf4+2048, pbuf4+3072 };
        set_func_name( "lowres_init" );
        ok = 1; used_asm = 1;
        for( int w = 96; w <= 96+24; w += 8 )
        {
            intptr_t stride = (w*2+31)&~31;
            intptr_t stride_lowres = (w+31)&~31;
            call_c( mc_c.frame_init_lowres_core, pbuf1, dstc[0], dstc[1], dstc[2], dstc[3], stride, stride_lowres, w, 8 );
            call_a( mc_a.frame_init_lowres_core, pbuf1, dsta[0], dsta[1], dsta[2], dsta[3], stride, stride_lowres, w, 8 );
            for( int i = 0; i < 8; i++ )
            {
                for( int j = 0; j < 4; j++ )
                    if( memcmp( dstc[j]+i*stride_lowres, dsta[j]+i*stride_lowres, w * SIZEOF_PIXEL ) )
                    {
                        ok = 0;
                        fprintf( stderr, "frame_init_lowres differs at plane %d line %d\n", j, i );
                        for( int k = 0; k < w; k++ )
                            fprintf( stderr, "%d ", dstc[j][k+i*stride_lowres] );
                        fprintf( stderr, "\n" );
                        for( int k = 0; k < w; k++ )
                            fprintf( stderr, "%d ", dsta[j][k+i*stride_lowres] );
                        fprintf( stderr, "\n" );
                        break;
                    }
            }
        }
        report( "lowres init :" );
    }

#define INTEGRAL_INIT( name, size, offset, cmp_len, ... )\
    if( mc_a.name != mc_ref.name )\
    {\
        intptr_t stride = 96;\
        set_func_name( #name );\
        used_asm = 1;\
        memcpy( buf3, buf1, size*2*stride );\
        memcpy( buf4, buf1, size*2*stride );\
        uint16_t *sum = (uint16_t*)buf3;\
        call_c1( mc_c.name, sum+offset, __VA_ARGS__ );\
        sum = (uint16_t*)buf4;\
        call_a1( mc_a.name, sum+offset, __VA_ARGS__ );\
        if( memcmp( buf3+2*offset, buf4+2*offset, cmp_len*2 )\
            || (size>9 && memcmp( buf3+18*stride, buf4+18*stride, (stride-8)*2 )))\
            ok = 0;\
        call_c2( mc_c.name, sum+offset, __VA_ARGS__ );\
        call_a2( mc_a.name, sum+offset, __VA_ARGS__ );\
    }
    ok = 1; used_asm = 0;
    INTEGRAL_INIT( integral_init4h, 2, stride, stride-4, pbuf2, stride );
    INTEGRAL_INIT( integral_init8h, 2, stride, stride-8, pbuf2, stride );
    INTEGRAL_INIT( integral_init4v, 14, 0, stride-8, sum+9*stride, stride );
    INTEGRAL_INIT( integral_init8v, 9, 0, stride-8, stride );
    report( "integral init :" );

    ok = 1; used_asm = 0;
    if( mc_a.mbtree_propagate_cost != mc_ref.mbtree_propagate_cost )
    {
        used_asm = 1;
        x264_emms();
        for( int i = 0; i < 10; i++ )
        {
            float fps_factor = (rand30()&65535) / 65535.0f;
            set_func_name( "mbtree_propagate_cost" );
            int16_t *dsta = (int16_t*)buf3;
            int16_t *dstc = dsta+400;
            uint16_t *prop = (uint16_t*)buf1;
            uint16_t *intra = (uint16_t*)buf4;
            uint16_t *inter = intra+128;
            uint16_t *qscale = inter+128;
            uint16_t *rnd = (uint16_t*)buf2;
            x264_emms();
            for( int j = 0; j < 100; j++ )
            {
                intra[j]  = *rnd++ & 0x7fff;
                intra[j] += !intra[j];
                inter[j]  = *rnd++ & 0x7fff;
                qscale[j] = *rnd++ & 0x7fff;
            }
            call_c( mc_c.mbtree_propagate_cost, dstc, prop, intra, inter, qscale, &fps_factor, 100 );
            call_a( mc_a.mbtree_propagate_cost, dsta, prop, intra, inter, qscale, &fps_factor, 100 );
            // I don't care about exact rounding, this is just how close the floating-point implementation happens to be
            x264_emms();
            for( int j = 0; j < 100 && ok; j++ )
            {
                ok &= abs( dstc[j]-dsta[j] ) <= 1 || fabs( (double)dstc[j]/dsta[j]-1 ) < 1e-4;
                if( !ok )
                    fprintf( stderr, "mbtree_propagate_cost FAILED: %d !~= %d\n", dstc[j], dsta[j] );
            }
        }
    }

    if( mc_a.mbtree_propagate_list != mc_ref.mbtree_propagate_list )
    {
        used_asm = 1;
        for( int i = 0; i < 8; i++ )
        {
            set_func_name( "mbtree_propagate_list" );
            x264_t h;
            int height = 4;
            int width = 128;
            int size = width*height;
            h.mb.i_mb_stride = width;
            h.mb.i_mb_width = width;
            h.mb.i_mb_height = height;

            uint16_t *ref_costsc = (uint16_t*)buf3 + width;
            uint16_t *ref_costsa = (uint16_t*)buf4 + width;
            int16_t (*mvs)[2] = (int16_t(*)[2])(ref_costsc + width + size);
            int16_t *propagate_amount = (int16_t*)(mvs + width);
            uint16_t *lowres_costs = (uint16_t*)(propagate_amount + width);
            h.scratch_buffer2 = (uint8_t*)(ref_costsa + width + size);
            int bipred_weight = (rand()%63)+1;
            int mb_y = rand()&3;
            int list = i&1;
            for( int j = -width; j < size+width; j++ )
                ref_costsc[j] = ref_costsa[j] = rand()&32767;
            for( int j = 0; j < width; j++ )
            {
                static const uint8_t list_dist[2][8] = {{0,1,1,1,1,1,1,1},{1,1,3,3,3,3,3,2}};
                for( int k = 0; k < 2; k++ )
                    mvs[j][k] = (rand()&127) - 64;
                propagate_amount[j] = rand()&32767;
                lowres_costs[j] = list_dist[list][rand()&7] << LOWRES_COST_SHIFT;
            }

            call_c1( mc_c.mbtree_propagate_list, &h, ref_costsc, mvs, propagate_amount, lowres_costs, bipred_weight, mb_y, width, list );
            call_a1( mc_a.mbtree_propagate_list, &h, ref_costsa, mvs, propagate_amount, lowres_costs, bipred_weight, mb_y, width, list );

            for( int j = -width; j < size+width && ok; j++ )
            {
                ok &= abs(ref_costsa[j] - ref_costsc[j]) <= 1;
                if( !ok )
                    fprintf( stderr, "mbtree_propagate_list FAILED at %d: %d !~= %d\n", j, ref_costsc[j], ref_costsa[j] );
            }

            call_c2( mc_c.mbtree_propagate_list, &h, ref_costsc, mvs, propagate_amount, lowres_costs, bipred_weight, mb_y, width, list );
            call_a2( mc_a.mbtree_propagate_list, &h, ref_costsa, mvs, propagate_amount, lowres_costs, bipred_weight, mb_y, width, list );
        }
    }

    static const uint16_t mbtree_fix8_counts[] = { 5, 384, 392, 400, 415 };

    if( mc_a.mbtree_fix8_pack != mc_ref.mbtree_fix8_pack )
    {
        set_func_name( "mbtree_fix8_pack" );
        used_asm = 1;
        float *fix8_src = (float*)(buf3 + 0x800);
        uint16_t *dstc = (uint16_t*)buf3;
        uint16_t *dsta = (uint16_t*)buf4;
        for( int i = 0; i < ARRAY_ELEMS(mbtree_fix8_counts); i++ )
        {
            int count = mbtree_fix8_counts[i];

            for( int j = 0; j < count; j++ )
                fix8_src[j] = (int16_t)(rand()) / 256.0f;
            dsta[count] = 0xAAAA;

            call_c( mc_c.mbtree_fix8_pack, dstc, fix8_src, count );
            call_a( mc_a.mbtree_fix8_pack, dsta, fix8_src, count );

            if( memcmp( dsta, dstc, count * sizeof(uint16_t) ) || dsta[count] != 0xAAAA )
            {
                ok = 0;
                fprintf( stderr, "mbtree_fix8_pack FAILED\n" );
                break;
            }
        }
    }

    if( mc_a.mbtree_fix8_unpack != mc_ref.mbtree_fix8_unpack )
    {
        set_func_name( "mbtree_fix8_unpack" );
        used_asm = 1;
        uint16_t *fix8_src = (uint16_t*)(buf3 + 0x800);
        float *dstc = (float*)buf3;
        float *dsta = (float*)buf4;
        for( int i = 0; i < ARRAY_ELEMS(mbtree_fix8_counts); i++ )
        {
            int count = mbtree_fix8_counts[i];

            for( int j = 0; j < count; j++ )
                fix8_src[j] = rand();
            M32( &dsta[count] ) = 0xAAAAAAAA;

            call_c( mc_c.mbtree_fix8_unpack, dstc, fix8_src, count );
            call_a( mc_a.mbtree_fix8_unpack, dsta, fix8_src, count );

            if( memcmp( dsta, dstc, count * sizeof(float) ) || M32( &dsta[count] ) != 0xAAAAAAAA )
            {
                ok = 0;
                fprintf( stderr, "mbtree_fix8_unpack FAILED\n" );
                break;
            }
        }
    }
    report( "mbtree :" );

    if( mc_a.memcpy_aligned != mc_ref.memcpy_aligned )
    {
        set_func_name( "memcpy_aligned" );
        ok = 1; used_asm = 1;
        for( size_t size = 16; size < 512; size += 16 )
        {
            for( size_t i = 0; i < size; i++ )
                buf1[i] = (uint8_t)rand();
            memset( buf4-1, 0xAA, size + 2 );
            call_c( mc_c.memcpy_aligned, buf3, buf1, size );
            call_a( mc_a.memcpy_aligned, buf4, buf1, size );
            if( memcmp( buf3, buf4, size ) || buf4[-1] != 0xAA || buf4[size] != 0xAA )
            {
                ok = 0;
                fprintf( stderr, "memcpy_aligned FAILED: size=%d\n", (int)size );
                break;
            }
        }
        report( "memcpy aligned :" );
    }

    if( mc_a.memzero_aligned != mc_ref.memzero_aligned )
    {
        set_func_name( "memzero_aligned" );
        ok = 1; used_asm = 1;
        for( size_t size = 128; size < 1024; size += 128 )
        {
            memset( buf4-1, 0xAA, size + 2 );
            call_c( mc_c.memzero_aligned, buf3, size );
            call_a( mc_a.memzero_aligned, buf4, size );
            if( memcmp( buf3, buf4, size ) || buf4[-1] != 0xAA || buf4[size] != 0xAA )
            {
                ok = 0;
                fprintf( stderr, "memzero_aligned FAILED: size=%d\n", (int)size );
                break;
            }
        }
        report( "memzero aligned :" );
    }

    return ret;
}

static int check_deblock( uint32_t cpu_ref, uint32_t cpu_new )
{
    x264_deblock_function_t db_c;
    x264_deblock_function_t db_ref;
    x264_deblock_function_t db_a;
    int ret = 0, ok = 1, used_asm = 0;
    int alphas[36], betas[36];
    int8_t tcs[36][4];

    x264_deblock_init( 0, &db_c, 0 );
    x264_deblock_init( cpu_ref, &db_ref, 0 );
    x264_deblock_init( cpu_new, &db_a, 0 );

    /* not exactly the real values of a,b,tc but close enough */
    for( int i = 35, a = 255, c = 250; i >= 0; i-- )
    {
        alphas[i] = a << (BIT_DEPTH-8);
        betas[i] = (i+1)/2 << (BIT_DEPTH-8);
        tcs[i][0] = tcs[i][3] = (c+6)/10 << (BIT_DEPTH-8);
        tcs[i][1] = (c+7)/15 << (BIT_DEPTH-8);
        tcs[i][2] = (c+9)/20 << (BIT_DEPTH-8);
        a = a*9/10;
        c = c*9/10;
    }

#define TEST_DEBLOCK( name, align, ... ) \
    for( int i = 0; i < 36; i++ ) \
    { \
        intptr_t off = 8*32 + (i&15)*4*!align; /* benchmark various alignments of h filter */ \
        for( int j = 0; j < 1024; j++ ) \
            /* two distributions of random to excersize different failure modes */ \
            pbuf3[j] = rand() & (i&1 ? 0xf : PIXEL_MAX ); \
        memcpy( pbuf4, pbuf3, 1024 * SIZEOF_PIXEL ); \
        if( db_a.name != db_ref.name ) \
        { \
            set_func_name( #name ); \
            used_asm = 1; \
            call_c1( db_c.name, pbuf3+off, (intptr_t)32, alphas[i], betas[i], ##__VA_ARGS__ ); \
            call_a1( db_a.name, pbuf4+off, (intptr_t)32, alphas[i], betas[i], ##__VA_ARGS__ ); \
            if( memcmp( pbuf3, pbuf4, 1024 * SIZEOF_PIXEL ) ) \
            { \
                ok = 0; \
                fprintf( stderr, #name "(a=%d, b=%d): [FAILED]\n", alphas[i], betas[i] ); \
                break; \
            } \
            call_c2( db_c.name, pbuf3+off, (intptr_t)32, alphas[i], betas[i], ##__VA_ARGS__ ); \
            call_a2( db_a.name, pbuf4+off, (intptr_t)32, alphas[i], betas[i], ##__VA_ARGS__ ); \
        } \
    }

    TEST_DEBLOCK( deblock_luma[0], 0, tcs[i] );
    TEST_DEBLOCK( deblock_luma[1], 1, tcs[i] );
    TEST_DEBLOCK( deblock_h_chroma_420, 0, tcs[i] );
    TEST_DEBLOCK( deblock_h_chroma_422, 0, tcs[i] );
    TEST_DEBLOCK( deblock_chroma_420_mbaff, 0, tcs[i] );
    TEST_DEBLOCK( deblock_chroma_422_mbaff, 0, tcs[i] );
    TEST_DEBLOCK( deblock_chroma[1], 1, tcs[i] );
    TEST_DEBLOCK( deblock_luma_intra[0], 0 );
    TEST_DEBLOCK( deblock_luma_intra[1], 1 );
    TEST_DEBLOCK( deblock_h_chroma_420_intra, 0 );
    TEST_DEBLOCK( deblock_h_chroma_422_intra, 0 );
    TEST_DEBLOCK( deblock_chroma_420_intra_mbaff, 0 );
    TEST_DEBLOCK( deblock_chroma_422_intra_mbaff, 0 );
    TEST_DEBLOCK( deblock_chroma_intra[1], 1 );

    if( db_a.deblock_strength != db_ref.deblock_strength )
    {
        set_func_name( "deblock_strength" );
        used_asm = 1;
        for( int i = 0; i < 100; i++ )
        {
            ALIGNED_ARRAY_16( uint8_t, nnz_buf, [X264_SCAN8_SIZE+8] );
            uint8_t *nnz = &nnz_buf[8];
            ALIGNED_4( int8_t ref[2][X264_SCAN8_LUMA_SIZE] );
            ALIGNED_ARRAY_16( int16_t, mv, [2],[X264_SCAN8_LUMA_SIZE][2] );
            ALIGNED_ARRAY_32( uint8_t, bs, [2],[2][8][4] );
            memset( bs, 99, sizeof(uint8_t)*2*4*8*2 );
            for( int j = 0; j < X264_SCAN8_SIZE; j++ )
                nnz[j] = ((rand()&7) == 7) * rand() & 0xf;
            for( int j = 0; j < 2; j++ )
                for( int k = 0; k < X264_SCAN8_LUMA_SIZE; k++ )
                {
                    ref[j][k] = ((rand()&3) != 3) ? 0 : (rand() & 31) - 2;
                    for( int l = 0; l < 2; l++ )
                        mv[j][k][l] = ((rand()&7) != 7) ? (rand()&7) - 3 : (rand()&16383) - 8192;
                }
            call_c( db_c.deblock_strength, nnz, ref, mv, bs[0], 2<<(i&1), ((i>>1)&1) );
            call_a( db_a.deblock_strength, nnz, ref, mv, bs[1], 2<<(i&1), ((i>>1)&1) );
            if( memcmp( bs[0], bs[1], sizeof(uint8_t)*2*4*8 ) )
            {
                ok = 0;
                fprintf( stderr, "deblock_strength: [FAILED]\n" );
                for( int j = 0; j < 2; j++ )
                {
                    for( int k = 0; k < 2; k++ )
                        for( int l = 0; l < 4; l++ )
                        {
                            for( int m = 0; m < 4; m++ )
                                fprintf( stderr, "%d ",bs[j][k][l][m] );
                            fprintf( stderr, "\n" );
                        }
                    fprintf( stderr, "\n" );
                }
                break;
            }
        }
    }

    report( "deblock :" );

    return ret;
}

static int check_quant( uint32_t cpu_ref, uint32_t cpu_new )
{
    x264_quant_function_t qf_c;
    x264_quant_function_t qf_ref;
    x264_quant_function_t qf_a;
    ALIGNED_ARRAY_64( dctcoef, dct1,[64] );
    ALIGNED_ARRAY_64( dctcoef, dct2,[64] );
    ALIGNED_ARRAY_32( dctcoef, dct3,[8],[16] );
    ALIGNED_ARRAY_32( dctcoef, dct4,[8],[16] );
    ALIGNED_ARRAY_32( uint8_t, cqm_buf,[64] );
    int ret = 0, ok, used_asm;
    int oks[3] = {1,1,1}, used_asms[3] = {0,0,0};
    x264_t h_buf;
    x264_t *h = &h_buf;
    memset( h, 0, sizeof(*h) );
    h->sps->i_chroma_format_idc = 1;
    x264_param_default( &h->param );
    h->chroma_qp_table = i_chroma_qp_table + 12;
    h->param.analyse.b_transform_8x8 = 1;

    static const uint8_t cqm_test4[16] =
    {
        6,4,6,4,
        4,3,4,3,
        6,4,6,4,
        4,3,4,3
    };
    static const uint8_t cqm_test8[64] =
    {
        3,3,4,3,3,3,4,3,
        3,3,4,3,3,3,4,3,
        4,4,5,4,4,4,5,4,
        3,3,4,3,3,3,4,3,
        3,3,4,3,3,3,4,3,
        3,3,4,3,3,3,4,3,
        4,4,5,4,4,4,5,4,
        3,3,4,3,3,3,4,3
    };

    for( int i_cqm = 0; i_cqm < 6; i_cqm++ )
    {
        if( i_cqm == 0 )
        {
            for( int i = 0; i < 8; i++ )
                h->sps->scaling_list[i] = x264_cqm_flat16;
            h->param.i_cqm_preset = h->sps->i_cqm_preset = X264_CQM_FLAT;
        }
        else if( i_cqm == 1 )
        {
            for( int i = 0; i < 8; i++ )
                h->sps->scaling_list[i] = x264_cqm_jvt[i];
            h->param.i_cqm_preset = h->sps->i_cqm_preset = X264_CQM_JVT;
        }
        else if( i_cqm == 2 )
        {
            for( int i = 0; i < 4; i++ )
                h->sps->scaling_list[i] = cqm_test4;
            for( int i = 4; i < 8; i++ )
                h->sps->scaling_list[i] = x264_cqm_flat16;
            h->param.i_cqm_preset = h->sps->i_cqm_preset = X264_CQM_CUSTOM;
        }
        else if( i_cqm == 3 )
        {
            for( int i = 0; i < 4; i++ )
                h->sps->scaling_list[i] = x264_cqm_flat16;
            for( int i = 4; i < 8; i++ )
                h->sps->scaling_list[i] = cqm_test8;
            h->param.i_cqm_preset = h->sps->i_cqm_preset = X264_CQM_CUSTOM;
        }
        else
        {
            int max_scale = BIT_DEPTH < 10 ? 255 : 228;
            if( i_cqm == 4 )
                for( int i = 0; i < 64; i++ )
                    cqm_buf[i] = 10 + rand() % (max_scale - 9);
            else
                for( int i = 0; i < 64; i++ )
                    cqm_buf[i] = 1;
            for( int i = 0; i < 8; i++ )
                h->sps->scaling_list[i] = cqm_buf;
            h->param.i_cqm_preset = h->sps->i_cqm_preset = X264_CQM_CUSTOM;
        }

        h->param.rc.i_qp_min = 0;
        h->param.rc.i_qp_max = QP_MAX_SPEC;
        x264_cqm_init( h );
        x264_quant_init( h, 0, &qf_c );
        x264_quant_init( h, cpu_ref, &qf_ref );
        x264_quant_init( h, cpu_new, &qf_a );

#define INIT_QUANT8(j,max) \
        { \
            static const int scale1d[8] = {32,31,24,31,32,31,24,31}; \
            for( int i = 0; i < max; i++ ) \
            { \
                int scale = (PIXEL_MAX*scale1d[(i>>3)&7]*scale1d[i&7])/16; \
                dct1[i] = dct2[i] = (j>>(i>>6))&1 ? (rand30()%(2*scale+1))-scale : 0; \
            } \
        }

#define INIT_QUANT4(j,max) \
        { \
            static const int scale1d[4] = {4,6,4,6}; \
            for( int i = 0; i < max; i++ ) \
            { \
                int scale = PIXEL_MAX*scale1d[(i>>2)&3]*scale1d[i&3]; \
                dct1[i] = dct2[i] = (j>>(i>>4))&1 ? (rand30()%(2*scale+1))-scale : 0; \
            } \
        }

#define TEST_QUANT_DC( name, cqm ) \
        if( qf_a.name != qf_ref.name ) \
        { \
            set_func_name( #name ); \
            used_asms[0] = 1; \
            for( int qp = h->param.rc.i_qp_max; qp >= h->param.rc.i_qp_min; qp-- ) \
            { \
                for( int j = 0; j < 2; j++ ) \
                { \
                    int result_c, result_a; \
                    for( int i = 0; i < 16; i++ ) \
                        dct1[i] = dct2[i] = j ? (rand() & 0x1fff) - 0xfff : 0; \
                    result_c = call_c1( qf_c.name, dct1, h->quant4_mf[CQM_4IY][qp][0], h->quant4_bias[CQM_4IY][qp][0] ); \
                    result_a = call_a1( qf_a.name, dct2, h->quant4_mf[CQM_4IY][qp][0], h->quant4_bias[CQM_4IY][qp][0] ); \
                    if( memcmp( dct1, dct2, 16*sizeof(dctcoef) ) || result_c != result_a ) \
                    { \
                        oks[0] = 0; \
                        fprintf( stderr, #name "(cqm=%d): [FAILED]\n", i_cqm ); \
                        break; \
                    } \
                    call_c2( qf_c.name, dct1, h->quant4_mf[CQM_4IY][qp][0], h->quant4_bias[CQM_4IY][qp][0] ); \
                    call_a2( qf_a.name, dct2, h->quant4_mf[CQM_4IY][qp][0], h->quant4_bias[CQM_4IY][qp][0] ); \
                } \
            } \
        }

#define TEST_QUANT( qname, block, type, w, maxj ) \
        if( qf_a.qname != qf_ref.qname ) \
        { \
            set_func_name( #qname ); \
            used_asms[0] = 1; \
            for( int qp = h->param.rc.i_qp_max; qp >= h->param.rc.i_qp_min; qp-- ) \
            { \
                for( int j = 0; j < maxj; j++ ) \
                { \
                    INIT_QUANT##type(j, w*w) \
                    int result_c = call_c1( qf_c.qname, (void*)dct1, h->quant##type##_mf[block][qp], h->quant##type##_bias[block][qp] ); \
                    int result_a = call_a1( qf_a.qname, (void*)dct2, h->quant##type##_mf[block][qp], h->quant##type##_bias[block][qp] ); \
                    if( memcmp( dct1, dct2, w*w*sizeof(dctcoef) ) || result_c != result_a ) \
                    { \
                        oks[0] = 0; \
                        fprintf( stderr, #qname "(qp=%d, cqm=%d, block="#block"): [FAILED]\n", qp, i_cqm ); \
                        break; \
                    } \
                    call_c2( qf_c.qname, (void*)dct1, h->quant##type##_mf[block][qp], h->quant##type##_bias[block][qp] ); \
                    call_a2( qf_a.qname, (void*)dct2, h->quant##type##_mf[block][qp], h->quant##type##_bias[block][qp] ); \
                } \
            } \
        }

        TEST_QUANT( quant_8x8, CQM_8IY, 8, 8, 2 );
        TEST_QUANT( quant_8x8, CQM_8PY, 8, 8, 2 );
        TEST_QUANT( quant_4x4, CQM_4IY, 4, 4, 2 );
        TEST_QUANT( quant_4x4, CQM_4PY, 4, 4, 2 );
        TEST_QUANT( quant_4x4x4, CQM_4IY, 4, 8, 16 );
        TEST_QUANT( quant_4x4x4, CQM_4PY, 4, 8, 16 );
        TEST_QUANT_DC( quant_4x4_dc, **h->quant4_mf[CQM_4IY] );
        TEST_QUANT_DC( quant_2x2_dc, **h->quant4_mf[CQM_4IC] );

#define TEST_DEQUANT( qname, dqname, block, w ) \
        if( qf_a.dqname != qf_ref.dqname ) \
        { \
            set_func_name( "%s_%s", #dqname, i_cqm?"cqm":"flat" ); \
            used_asms[1] = 1; \
            for( int qp = h->param.rc.i_qp_max; qp >= h->param.rc.i_qp_min; qp-- ) \
            { \
                INIT_QUANT##w(1, w*w) \
                qf_c.qname( dct1, h->quant##w##_mf[block][qp], h->quant##w##_bias[block][qp] ); \
                memcpy( dct2, dct1, w*w*sizeof(dctcoef) ); \
                call_c1( qf_c.dqname, dct1, h->dequant##w##_mf[block], qp ); \
                call_a1( qf_a.dqname, dct2, h->dequant##w##_mf[block], qp ); \
                if( memcmp( dct1, dct2, w*w*sizeof(dctcoef) ) ) \
                { \
                    oks[1] = 0; \
                    fprintf( stderr, #dqname "(qp=%d, cqm=%d, block="#block"): [FAILED]\n", qp, i_cqm ); \
                    break; \
                } \
                call_c2( qf_c.dqname, dct1, h->dequant##w##_mf[block], qp ); \
                call_a2( qf_a.dqname, dct2, h->dequant##w##_mf[block], qp ); \
            } \
        }

        TEST_DEQUANT( quant_8x8, dequant_8x8, CQM_8IY, 8 );
        TEST_DEQUANT( quant_8x8, dequant_8x8, CQM_8PY, 8 );
        TEST_DEQUANT( quant_4x4, dequant_4x4, CQM_4IY, 4 );
        TEST_DEQUANT( quant_4x4, dequant_4x4, CQM_4PY, 4 );

#define TEST_DEQUANT_DC( qname, dqname, block, w ) \
        if( qf_a.dqname != qf_ref.dqname ) \
        { \
            set_func_name( "%s_%s", #dqname, i_cqm?"cqm":"flat" ); \
            used_asms[1] = 1; \
            for( int qp = h->param.rc.i_qp_max; qp >= h->param.rc.i_qp_min; qp-- ) \
            { \
                for( int i = 0; i < 16; i++ ) \
                    dct1[i] = rand()%(PIXEL_MAX*16*2+1) - PIXEL_MAX*16; \
                qf_c.qname( dct1, h->quant##w##_mf[block][qp][0]>>1, h->quant##w##_bias[block][qp][0]>>1 ); \
                memcpy( dct2, dct1, w*w*sizeof(dctcoef) ); \
                call_c1( qf_c.dqname, dct1, h->dequant##w##_mf[block], qp ); \
                call_a1( qf_a.dqname, dct2, h->dequant##w##_mf[block], qp ); \
                if( memcmp( dct1, dct2, w*w*sizeof(dctcoef) ) ) \
                { \
                    oks[1] = 0; \
                    fprintf( stderr, #dqname "(qp=%d, cqm=%d, block="#block"): [FAILED]\n", qp, i_cqm ); \
                } \
                call_c2( qf_c.dqname, dct1, h->dequant##w##_mf[block], qp ); \
                call_a2( qf_a.dqname, dct2, h->dequant##w##_mf[block], qp ); \
            } \
        }

        TEST_DEQUANT_DC( quant_4x4_dc, dequant_4x4_dc, CQM_4IY, 4 );

        if( qf_a.idct_dequant_2x4_dc != qf_ref.idct_dequant_2x4_dc )
        {
            set_func_name( "idct_dequant_2x4_dc_%s", i_cqm?"cqm":"flat" );
            used_asms[1] = 1;
            for( int qp = h->chroma_qp_table[h->param.rc.i_qp_max]; qp >= h->chroma_qp_table[h->param.rc.i_qp_min]; qp-- )
            {
                for( int i = 0; i < 8; i++ )
                    dct1[i] = rand()%(PIXEL_MAX*16*2+1) - PIXEL_MAX*16;
                qf_c.quant_2x2_dc( &dct1[0], h->quant4_mf[CQM_4IC][qp+3][0]>>1, h->quant4_bias[CQM_4IC][qp+3][0]>>1 );
                qf_c.quant_2x2_dc( &dct1[4], h->quant4_mf[CQM_4IC][qp+3][0]>>1, h->quant4_bias[CQM_4IC][qp+3][0]>>1 );
                call_c( qf_c.idct_dequant_2x4_dc, dct1, dct3, h->dequant4_mf[CQM_4IC], qp+3 );
                call_a( qf_a.idct_dequant_2x4_dc, dct1, dct4, h->dequant4_mf[CQM_4IC], qp+3 );
                for( int i = 0; i < 8; i++ )
                    if( dct3[i][0] != dct4[i][0] )
                    {
                        oks[1] = 0;
                        fprintf( stderr, "idct_dequant_2x4_dc (qp=%d, cqm=%d): [FAILED]\n", qp, i_cqm );
                        break;
                    }
            }
        }

        if( qf_a.idct_dequant_2x4_dconly != qf_ref.idct_dequant_2x4_dconly )
        {
            set_func_name( "idct_dequant_2x4_dconly_%s", i_cqm?"cqm":"flat" );
            used_asms[1] = 1;
            for( int qp = h->chroma_qp_table[h->param.rc.i_qp_max]; qp >= h->chroma_qp_table[h->param.rc.i_qp_min]; qp-- )
            {
                for( int i = 0; i < 8; i++ )
                    dct1[i] = rand()%(PIXEL_MAX*16*2+1) - PIXEL_MAX*16;
                qf_c.quant_2x2_dc( &dct1[0], h->quant4_mf[CQM_4IC][qp+3][0]>>1, h->quant4_bias[CQM_4IC][qp+3][0]>>1 );
                qf_c.quant_2x2_dc( &dct1[4], h->quant4_mf[CQM_4IC][qp+3][0]>>1, h->quant4_bias[CQM_4IC][qp+3][0]>>1 );
                memcpy( dct2, dct1, 8*sizeof(dctcoef) );
                call_c1( qf_c.idct_dequant_2x4_dconly, dct1, h->dequant4_mf[CQM_4IC], qp+3 );
                call_a1( qf_a.idct_dequant_2x4_dconly, dct2, h->dequant4_mf[CQM_4IC], qp+3 );
                if( memcmp( dct1, dct2, 8*sizeof(dctcoef) ) )
                {
                    oks[1] = 0;
                    fprintf( stderr, "idct_dequant_2x4_dconly (qp=%d, cqm=%d): [FAILED]\n", qp, i_cqm );
                    break;
                }
                call_c2( qf_c.idct_dequant_2x4_dconly, dct1, h->dequant4_mf[CQM_4IC], qp+3 );
                call_a2( qf_a.idct_dequant_2x4_dconly, dct2, h->dequant4_mf[CQM_4IC], qp+3 );
            }
        }

#define TEST_OPTIMIZE_CHROMA_DC( optname, size ) \
        if( qf_a.optname != qf_ref.optname ) \
        { \
            set_func_name( #optname ); \
            used_asms[2] = 1; \
            for( int qp = h->param.rc.i_qp_max; qp >= h->param.rc.i_qp_min; qp-- ) \
            { \
                int qpdc = qp + (size == 8 ? 3 : 0); \
                int dmf = h->dequant4_mf[CQM_4IC][qpdc%6][0] << qpdc/6; \
                if( dmf > 32*64 ) \
                    continue; \
                for( int i = 16;; i <<= 1 ) \
                { \
                    int res_c, res_asm; \
                    int max = X264_MIN( i, PIXEL_MAX*16 ); \
                    for( int j = 0; j < size; j++ ) \
                        dct1[j] = rand()%(max*2+1) - max; \
                    for( int j = 0; j <= size; j += 4 ) \
                        qf_c.quant_2x2_dc( &dct1[j], h->quant4_mf[CQM_4IC][qpdc][0]>>1, h->quant4_bias[CQM_4IC][qpdc][0]>>1 ); \
                    memcpy( dct2, dct1, size*sizeof(dctcoef) ); \
                    res_c   = call_c1( qf_c.optname, dct1, dmf ); \
                    res_asm = call_a1( qf_a.optname, dct2, dmf ); \
                    if( res_c != res_asm || memcmp( dct1, dct2, size*sizeof(dctcoef) ) ) \
                    { \
                        oks[2] = 0; \
                        fprintf( stderr, #optname "(qp=%d, res_c=%d, res_asm=%d): [FAILED]\n", qp, res_c, res_asm ); \
                    } \
                    call_c2( qf_c.optname, dct1, dmf ); \
                    call_a2( qf_a.optname, dct2, dmf ); \
                    if( i >= PIXEL_MAX*16 ) \
                        break; \
                } \
            } \
        }

        TEST_OPTIMIZE_CHROMA_DC( optimize_chroma_2x2_dc, 4 );
        TEST_OPTIMIZE_CHROMA_DC( optimize_chroma_2x4_dc, 8 );

        x264_cqm_delete( h );
    }

    ok = oks[0]; used_asm = used_asms[0];
    report( "quant :" );

    ok = oks[1]; used_asm = used_asms[1];
    report( "dequant :" );

    ok = oks[2]; used_asm = used_asms[2];
    report( "optimize chroma dc :" );

    ok = 1; used_asm = 0;
    if( qf_a.denoise_dct != qf_ref.denoise_dct )
    {
        used_asm = 1;
        for( int size = 16; size <= 64; size += 48 )
        {
            set_func_name( "denoise_dct" );
            memcpy( dct1, buf1, size*sizeof(dctcoef) );
            memcpy( dct2, buf1, size*sizeof(dctcoef) );
            memcpy( buf3+256, buf3, 256 );
            call_c1( qf_c.denoise_dct, dct1, (uint32_t*)buf3,       (udctcoef*)buf2, size );
            call_a1( qf_a.denoise_dct, dct2, (uint32_t*)(buf3+256), (udctcoef*)buf2, size );
            if( memcmp( dct1, dct2, size*sizeof(dctcoef) ) || memcmp( buf3+4, buf3+256+4, (size-1)*sizeof(uint32_t) ) )
                ok = 0;
            call_c2( qf_c.denoise_dct, dct1, (uint32_t*)buf3,       (udctcoef*)buf2, size );
            call_a2( qf_a.denoise_dct, dct2, (uint32_t*)(buf3+256), (udctcoef*)buf2, size );
        }
    }
    report( "denoise dct :" );

#define TEST_DECIMATE( decname, w, ac, thresh ) \
    if( qf_a.decname != qf_ref.decname ) \
    { \
        set_func_name( #decname ); \
        used_asm = 1; \
        for( int i = 0; i < 100; i++ ) \
        { \
            static const int distrib[16] = {1,1,1,1,1,1,1,1,1,1,1,1,2,3,4};\
            static const int zerorate_lut[4] = {3,7,15,31};\
            int zero_rate = zerorate_lut[i&3];\
            for( int idx = 0; idx < w*w; idx++ ) \
            { \
                int sign = (rand()&1) ? -1 : 1; \
                int abs_level = distrib[rand()&15]; \
                if( abs_level == 4 ) abs_level = rand()&0x3fff; \
                int zero = !(rand()&zero_rate); \
                dct1[idx] = zero * abs_level * sign; \
            } \
            if( ac ) \
                dct1[0] = 0; \
            int result_c = call_c( qf_c.decname, dct1 ); \
            int result_a = call_a( qf_a.decname, dct1 ); \
            if( X264_MIN(result_c,thresh) != X264_MIN(result_a,thresh) ) \
            { \
                ok = 0; \
                fprintf( stderr, #decname ": [FAILED]\n" ); \
                break; \
            } \
        } \
    }

    ok = 1; used_asm = 0;
    TEST_DECIMATE( decimate_score64, 8, 0, 6 );
    TEST_DECIMATE( decimate_score16, 4, 0, 6 );
    TEST_DECIMATE( decimate_score15, 4, 1, 7 );
    report( "decimate_score :" );

#define TEST_LAST( last, lastname, size, ac ) \
    if( qf_a.last != qf_ref.last ) \
    { \
        set_func_name( #lastname ); \
        used_asm = 1; \
        for( int i = 0; i < 100; i++ ) \
        { \
            int nnz = 0; \
            int max = rand() & (size-1); \
            memset( dct1, 0, 64*sizeof(dctcoef) ); \
            for( int idx = ac; idx < max; idx++ ) \
                nnz |= dct1[idx] = !(rand()&3) + (!(rand()&15))*rand(); \
            if( !nnz ) \
                dct1[ac] = 1; \
            int result_c = call_c( qf_c.last, dct1+ac ); \
            int result_a = call_a( qf_a.last, dct1+ac ); \
            if( result_c != result_a ) \
            { \
                ok = 0; \
                fprintf( stderr, #lastname ": [FAILED]\n" ); \
                break; \
            } \
        } \
    }

    ok = 1; used_asm = 0;
    TEST_LAST( coeff_last4              , coeff_last4,   4, 0 );
    TEST_LAST( coeff_last8              , coeff_last8,   8, 0 );
    TEST_LAST( coeff_last[  DCT_LUMA_AC], coeff_last15, 16, 1 );
    TEST_LAST( coeff_last[ DCT_LUMA_4x4], coeff_last16, 16, 0 );
    TEST_LAST( coeff_last[ DCT_LUMA_8x8], coeff_last64, 64, 0 );
    report( "coeff_last :" );

#define TEST_LEVELRUN( lastname, name, size, ac ) \
    if( qf_a.lastname != qf_ref.lastname ) \
    { \
        set_func_name( #name ); \
        used_asm = 1; \
        for( int i = 0; i < 100; i++ ) \
        { \
            x264_run_level_t runlevel_c, runlevel_a; \
            int nnz = 0; \
            int max = rand() & (size-1); \
            memset( dct1, 0, 64*sizeof(dctcoef) ); \
            memcpy( &runlevel_a, buf1+i, sizeof(x264_run_level_t) ); \
            memcpy( &runlevel_c, buf1+i, sizeof(x264_run_level_t) ); \
            for( int idx = ac; idx < max; idx++ ) \
                nnz |= dct1[idx] = !(rand()&3) + (!(rand()&15))*rand(); \
            if( !nnz ) \
                dct1[ac] = 1; \
            int result_c = call_c( qf_c.lastname, dct1+ac, &runlevel_c ); \
            int result_a = call_a( qf_a.lastname, dct1+ac, &runlevel_a ); \
            if( result_c != result_a || runlevel_c.last != runlevel_a.last || \
                runlevel_c.mask != runlevel_a.mask || \
                memcmp(runlevel_c.level, runlevel_a.level, sizeof(dctcoef)*result_c)) \
            { \
                ok = 0; \
                fprintf( stderr, #name ": [FAILED]\n" ); \
                break; \
            } \
        } \
    }

    ok = 1; used_asm = 0;
    TEST_LEVELRUN( coeff_level_run4              , coeff_level_run4,   4, 0 );
    TEST_LEVELRUN( coeff_level_run8              , coeff_level_run8,   8, 0 );
    TEST_LEVELRUN( coeff_level_run[  DCT_LUMA_AC], coeff_level_run15, 16, 1 );
    TEST_LEVELRUN( coeff_level_run[ DCT_LUMA_4x4], coeff_level_run16, 16, 0 );
    report( "coeff_level_run :" );

    return ret;
}

static int check_intra( uint32_t cpu_ref, uint32_t cpu_new )
{
    int ret = 0, ok = 1, used_asm = 0;
    ALIGNED_ARRAY_32( pixel, edge,[36] );
    ALIGNED_ARRAY_32( pixel, edge2,[36] );
    ALIGNED_ARRAY_32( pixel, fdec,[FDEC_STRIDE*20] );
    struct
    {
        x264_predict_t      predict_16x16[4+3];
        x264_predict_t      predict_8x8c[4+3];
        x264_predict_t      predict_8x16c[4+3];
        x264_predict8x8_t   predict_8x8[9+3];
        x264_predict_t      predict_4x4[9+3];
        x264_predict_8x8_filter_t predict_8x8_filter;
    } ip_c, ip_ref, ip_a;

    x264_predict_16x16_init( 0, ip_c.predict_16x16 );
    x264_predict_8x8c_init( 0, ip_c.predict_8x8c );
    x264_predict_8x16c_init( 0, ip_c.predict_8x16c );
    x264_predict_8x8_init( 0, ip_c.predict_8x8, &ip_c.predict_8x8_filter );
    x264_predict_4x4_init( 0, ip_c.predict_4x4 );

    x264_predict_16x16_init( cpu_ref, ip_ref.predict_16x16 );
    x264_predict_8x8c_init( cpu_ref, ip_ref.predict_8x8c );
    x264_predict_8x16c_init( cpu_ref, ip_ref.predict_8x16c );
    x264_predict_8x8_init( cpu_ref, ip_ref.predict_8x8, &ip_ref.predict_8x8_filter );
    x264_predict_4x4_init( cpu_ref, ip_ref.predict_4x4 );

    x264_predict_16x16_init( cpu_new, ip_a.predict_16x16 );
    x264_predict_8x8c_init( cpu_new, ip_a.predict_8x8c );
    x264_predict_8x16c_init( cpu_new, ip_a.predict_8x16c );
    x264_predict_8x8_init( cpu_new, ip_a.predict_8x8, &ip_a.predict_8x8_filter );
    x264_predict_4x4_init( cpu_new, ip_a.predict_4x4 );

    memcpy( fdec, pbuf1, 32*20 * SIZEOF_PIXEL );\

    ip_c.predict_8x8_filter( fdec+48, edge, ALL_NEIGHBORS, ALL_NEIGHBORS );

#define INTRA_TEST( name, dir, w, h, align, bench, ... )\
    if( ip_a.name[dir] != ip_ref.name[dir] )\
    {\
        set_func_name( "intra_%s_%s", #name, intra_##name##_names[dir] );\
        used_asm = 1;\
        memcpy( pbuf3, fdec, FDEC_STRIDE*20 * SIZEOF_PIXEL );\
        memcpy( pbuf4, fdec, FDEC_STRIDE*20 * SIZEOF_PIXEL );\
        for( int a = 0; a < (do_bench ? 64/SIZEOF_PIXEL : 1); a += align )\
        {\
            call_c##bench( ip_c.name[dir], pbuf3+48+a, ##__VA_ARGS__ );\
            call_a##bench( ip_a.name[dir], pbuf4+48+a, ##__VA_ARGS__ );\
            if( memcmp( pbuf3, pbuf4, FDEC_STRIDE*20 * SIZEOF_PIXEL ) )\
            {\
                fprintf( stderr, #name "[%d] :  [FAILED]\n", dir );\
                ok = 0;\
                if( ip_c.name == (void *)ip_c.predict_8x8 )\
                {\
                    for( int k = -1; k < 16; k++ )\
                        fprintf( stderr, FMT_PIXEL" ", edge[16+k] );\
                    fprintf( stderr, "\n" );\
                }\
                for( int j = 0; j < h; j++ )\
                {\
                    if( ip_c.name == (void *)ip_c.predict_8x8 )\
                        fprintf( stderr, FMT_PIXEL" ", edge[14-j] );\
                    for( int k = 0; k < w; k++ )\
                        fprintf( stderr, FMT_PIXEL" ", pbuf4[48+k+j*FDEC_STRIDE] );\
                    fprintf( stderr, "\n" );\
                }\
                fprintf( stderr, "\n" );\
                for( int j = 0; j < h; j++ )\
                {\
                    if( ip_c.name == (void *)ip_c.predict_8x8 )\
                        fprintf( stderr, "   " );\
                    for( int k = 0; k < w; k++ )\
                        fprintf( stderr, FMT_PIXEL" ", pbuf3[48+k+j*FDEC_STRIDE] );\
                    fprintf( stderr, "\n" );\
                }\
                break;\
            }\
        }\
    }

    for( int i = 0; i < 12; i++ )
        INTRA_TEST(   predict_4x4, i,  4,  4,  4, );
    for( int i = 0; i < 7; i++ )
        INTRA_TEST(  predict_8x8c, i,  8,  8, 16, );
    for( int i = 0; i < 7; i++ )
        INTRA_TEST( predict_8x16c, i,  8, 16, 16, );
    for( int i = 0; i < 7; i++ )
        INTRA_TEST( predict_16x16, i, 16, 16, 16, );
    for( int i = 0; i < 12; i++ )
        INTRA_TEST(   predict_8x8, i,  8,  8,  8, , edge );

    set_func_name("intra_predict_8x8_filter");
    if( ip_a.predict_8x8_filter != ip_ref.predict_8x8_filter )
    {
        used_asm = 1;
        for( int i = 0; i < 32; i++ )
        {
            if( !(i&7) || ((i&MB_TOPRIGHT) && !(i&MB_TOP)) )
                continue;
            int neighbor = (i&24)>>1;
            memset( edge,  0, 36*SIZEOF_PIXEL );
            memset( edge2, 0, 36*SIZEOF_PIXEL );
            call_c( ip_c.predict_8x8_filter, pbuf1+48, edge,  neighbor, i&7 );
            call_a( ip_a.predict_8x8_filter, pbuf1+48, edge2, neighbor, i&7 );
            if( !(neighbor&MB_TOPLEFT) )
                edge[15] = edge2[15] = 0;
            if( memcmp( edge+7, edge2+7, (i&MB_TOPRIGHT ? 26 : i&MB_TOP ? 17 : 8) * SIZEOF_PIXEL ) )
            {
                fprintf( stderr, "predict_8x8_filter :  [FAILED] %d %d\n", (i&24)>>1, i&7);
                ok = 0;
            }
        }
    }

#define EXTREMAL_PLANE( w, h ) \
    { \
        int max[7]; \
        for( int j = 0; j < 7; j++ ) \
            max[j] = test ? rand()&PIXEL_MAX : PIXEL_MAX; \
        fdec[48-1-FDEC_STRIDE] = (i&1)*max[0]; \
        for( int j = 0; j < w/2; j++ ) \
            fdec[48+j-FDEC_STRIDE] = (!!(i&2))*max[1]; \
        for( int j = w/2; j < w-1; j++ ) \
            fdec[48+j-FDEC_STRIDE] = (!!(i&4))*max[2]; \
        fdec[48+(w-1)-FDEC_STRIDE] = (!!(i&8))*max[3]; \
        for( int j = 0; j < h/2; j++ ) \
            fdec[48+j*FDEC_STRIDE-1] = (!!(i&16))*max[4]; \
        for( int j = h/2; j < h-1; j++ ) \
            fdec[48+j*FDEC_STRIDE-1] = (!!(i&32))*max[5]; \
        fdec[48+(h-1)*FDEC_STRIDE-1] = (!!(i&64))*max[6]; \
    }
    /* Extremal test case for planar prediction. */
    for( int test = 0; test < 100 && ok; test++ )
        for( int i = 0; i < 128 && ok; i++ )
        {
            EXTREMAL_PLANE(  8,  8 );
            INTRA_TEST(  predict_8x8c, I_PRED_CHROMA_P,  8,  8, 64, 1 );
            EXTREMAL_PLANE(  8, 16 );
            INTRA_TEST( predict_8x16c, I_PRED_CHROMA_P,  8, 16, 64, 1 );
            EXTREMAL_PLANE( 16, 16 );
            INTRA_TEST( predict_16x16,  I_PRED_16x16_P, 16, 16, 64, 1 );
        }
    report( "intra pred :" );
    return ret;
}

#define DECL_CABAC(cpu) \
static void run_cabac_decision_##cpu( x264_t *h, uint8_t *dst )\
{\
    x264_cabac_t cb;\
    x264_cabac_context_init( h, &cb, SLICE_TYPE_P, 26, 0 );\
    x264_cabac_encode_init( &cb, dst, dst+0xff0 );\
    for( int i = 0; i < 0x1000; i++ )\
        x264_cabac_encode_decision_##cpu( &cb, buf1[i]>>1, buf1[i]&1 );\
}\
static void run_cabac_bypass_##cpu( x264_t *h, uint8_t *dst )\
{\
    x264_cabac_t cb;\
    x264_cabac_context_init( h, &cb, SLICE_TYPE_P, 26, 0 );\
    x264_cabac_encode_init( &cb, dst, dst+0xff0 );\
    for( int i = 0; i < 0x1000; i++ )\
        x264_cabac_encode_bypass_##cpu( &cb, buf1[i]&1 );\
}\
static void run_cabac_terminal_##cpu( x264_t *h, uint8_t *dst )\
{\
    x264_cabac_t cb;\
    x264_cabac_context_init( h, &cb, SLICE_TYPE_P, 26, 0 );\
    x264_cabac_encode_init( &cb, dst, dst+0xff0 );\
    for( int i = 0; i < 0x1000; i++ )\
        x264_cabac_encode_terminal_##cpu( &cb );\
}
DECL_CABAC(c)
#if HAVE_MMX
DECL_CABAC(asm)
#elif HAVE_AARCH64
DECL_CABAC(asm)
#else
#define run_cabac_decision_asm run_cabac_decision_c
#define run_cabac_bypass_asm run_cabac_bypass_c
#define run_cabac_terminal_asm run_cabac_terminal_c
#endif

extern const uint8_t x264_count_cat_m1[14];

static int check_cabac( uint32_t cpu_ref, uint32_t cpu_new )
{
    int ret = 0, ok = 1, used_asm = 0;
    x264_t h;
    h.sps->i_chroma_format_idc = 3;

    x264_bitstream_function_t bs_ref;
    x264_bitstream_function_t bs_a;
    x264_bitstream_init( cpu_ref, &bs_ref );
    x264_bitstream_init( cpu_new, &bs_a );
    x264_quant_init( &h, cpu_new, &h.quantf );
    h.quantf.coeff_last[DCT_CHROMA_DC] = h.quantf.coeff_last4;

/* Reset cabac state to avoid buffer overruns in do_bench() with large BENCH_RUNS values. */
#define GET_CB( i ) (\
    x264_cabac_encode_init( &cb[i], bitstream[i], bitstream[i]+0xfff0 ),\
    cb[i].f8_bits_encoded = 0, &cb[i] )

#define CABAC_RESIDUAL(name, start, end, rd)\
{\
    if( bs_a.name##_internal && (bs_a.name##_internal != bs_ref.name##_internal || (cpu_new&X264_CPU_SSE2_IS_SLOW)) )\
    {\
        used_asm = 1;\
        set_func_name( #name );\
        for( int i = 0; i < 2; i++ )\
        {\
            for( intptr_t ctx_block_cat = start; ctx_block_cat <= end; ctx_block_cat++ )\
            {\
                for( int j = 0; j < 256; j++ )\
                {\
                    ALIGNED_ARRAY_64( dctcoef, dct, [2],[64] );\
                    uint8_t bitstream[2][1<<16];\
                    static const uint8_t ctx_ac[14] = {0,1,0,0,1,0,0,1,0,0,0,1,0,0};\
                    int ac = ctx_ac[ctx_block_cat];\
                    int nz = 0;\
                    while( !nz )\
                    {\
                        for( int k = 0; k <= x264_count_cat_m1[ctx_block_cat]; k++ )\
                        {\
                            /* Very rough distribution that covers possible inputs */\
                            int rnd = rand();\
                            int coef = !(rnd&3);\
                            coef += !(rnd&  15) * (rand()&0x0006);\
                            coef += !(rnd&  63) * (rand()&0x0008);\
                            coef += !(rnd& 255) * (rand()&0x00F0);\
                            coef += !(rnd&1023) * (rand()&0x7F00);\
                            nz |= dct[0][ac+k] = dct[1][ac+k] = coef * ((rand()&1) ? 1 : -1);\
                        }\
                    }\
                    h.mb.b_interlaced = i;\
                    x264_cabac_t cb[2];\
                    x264_cabac_context_init( &h, &cb[0], SLICE_TYPE_P, 26, 0 );\
                    x264_cabac_context_init( &h, &cb[1], SLICE_TYPE_P, 26, 0 );\
                    if( !rd ) memcpy( bitstream[1], bitstream[0], 0x400 );\
                    call_c1( x264_##name##_c, &h, GET_CB( 0 ), ctx_block_cat, dct[0]+ac );\
                    call_a1( bs_a.name##_internal, dct[1]+ac, i, ctx_block_cat, GET_CB( 1 ) );\
                    ok = cb[0].f8_bits_encoded == cb[1].f8_bits_encoded && !memcmp(cb[0].state, cb[1].state, 1024);\
                    if( !rd ) ok |= !memcmp( bitstream[1], bitstream[0], 0x400 ) && !memcmp( &cb[1], &cb[0], offsetof(x264_cabac_t, p_start) );\
                    if( !ok )\
                    {\
                        fprintf( stderr, #name " :  [FAILED] ctx_block_cat %d", (int)ctx_block_cat );\
                        if( rd && cb[0].f8_bits_encoded != cb[1].f8_bits_encoded )\
                            fprintf( stderr, " (%d != %d)", cb[0].f8_bits_encoded, cb[1].f8_bits_encoded );\
                        fprintf( stderr, "\n");\
                        goto name##fail;\
                    }\
                    if( (j&15) == 0 )\
                    {\
                        call_c2( x264_##name##_c, &h, GET_CB( 0 ), ctx_block_cat, dct[0]+ac );\
                        call_a2( bs_a.name##_internal, dct[1]+ac, i, ctx_block_cat, GET_CB( 1 ) );\
                    }\
                }\
            }\
        }\
    }\
}\
name##fail:

    CABAC_RESIDUAL( cabac_block_residual, 0, DCT_LUMA_8x8, 0 )
    report( "cabac residual:" );

    ok = 1; used_asm = 0;
    CABAC_RESIDUAL( cabac_block_residual_rd, 0, DCT_LUMA_8x8-1, 1 )
    CABAC_RESIDUAL( cabac_block_residual_8x8_rd, DCT_LUMA_8x8, DCT_LUMA_8x8, 1 )
    report( "cabac residual rd:" );

    if( cpu_ref || run_cabac_decision_c == run_cabac_decision_asm )
        return ret;
    ok = 1; used_asm = 0;
    x264_cabac_init( &h );

    set_func_name( "cabac_encode_decision" );
    memcpy( buf4, buf3, 0x1000 );
    call_c( run_cabac_decision_c, &h, buf3 );
    call_a( run_cabac_decision_asm, &h, buf4 );
    ok = !memcmp( buf3, buf4, 0x1000 );
    report( "cabac decision:" );

    set_func_name( "cabac_encode_bypass" );
    memcpy( buf4, buf3, 0x1000 );
    call_c( run_cabac_bypass_c, &h, buf3 );
    call_a( run_cabac_bypass_asm, &h, buf4 );
    ok = !memcmp( buf3, buf4, 0x1000 );
    report( "cabac bypass:" );

    set_func_name( "cabac_encode_terminal" );
    memcpy( buf4, buf3, 0x1000 );
    call_c( run_cabac_terminal_c, &h, buf3 );
    call_a( run_cabac_terminal_asm, &h, buf4 );
    ok = !memcmp( buf3, buf4, 0x1000 );
    report( "cabac terminal:" );

    return ret;
}

static int check_bitstream( uint32_t cpu_ref, uint32_t cpu_new )
{
    x264_bitstream_function_t bs_c;
    x264_bitstream_function_t bs_ref;
    x264_bitstream_function_t bs_a;

    int ret = 0, ok = 1, used_asm = 0;

    x264_bitstream_init( 0, &bs_c );
    x264_bitstream_init( cpu_ref, &bs_ref );
    x264_bitstream_init( cpu_new, &bs_a );
    if( bs_a.nal_escape != bs_ref.nal_escape )
    {
        int size = 0x4000;
        uint8_t *input = malloc(size+100);
        uint8_t *output1 = malloc(size*2);
        uint8_t *output2 = malloc(size*2);
        used_asm = 1;
        set_func_name( "nal_escape" );
        for( int i = 0; i < 100; i++ )
        {
            /* Test corner-case sizes */
            int test_size = i < 10 ? i+1 : rand() & 0x3fff;
            /* Test 8 different probability distributions of zeros */
            for( int j = 0; j < test_size+32; j++ )
                input[j] = (uint8_t)((rand()&((1 << ((i&7)+1)) - 1)) * rand());
            uint8_t *end_c = (uint8_t*)call_c1( bs_c.nal_escape, output1, input, input+test_size );
            uint8_t *end_a = (uint8_t*)call_a1( bs_a.nal_escape, output2, input, input+test_size );
            int size_c = end_c-output1;
            int size_a = end_a-output2;
            if( size_c != size_a || memcmp( output1, output2, size_c ) )
            {
                fprintf( stderr, "nal_escape :  [FAILED] %d %d\n", size_c, size_a );
                ok = 0;
                break;
            }
        }
        for( int j = 0; j < size+32; j++ )
            input[j] = (uint8_t)rand();
        call_c2( bs_c.nal_escape, output1, input, input+size );
        call_a2( bs_a.nal_escape, output2, input, input+size );
        free(input);
        free(output1);
        free(output2);
    }
    report( "nal escape:" );

    return ret;
}

static int check_all_funcs( uint32_t cpu_ref, uint32_t cpu_new )
{
    return check_pixel( cpu_ref, cpu_new )
         + check_dct( cpu_ref, cpu_new )
         + check_mc( cpu_ref, cpu_new )
         + check_intra( cpu_ref, cpu_new )
         + check_deblock( cpu_ref, cpu_new )
         + check_quant( cpu_ref, cpu_new )
         + check_cabac( cpu_ref, cpu_new )
         + check_bitstream( cpu_ref, cpu_new );
}

static int add_flags( uint32_t *cpu_ref, uint32_t *cpu_new, uint32_t flags, const char *name )
{
    *cpu_ref = *cpu_new;
    *cpu_new |= flags;
#if STACK_ALIGNMENT < 16
    *cpu_new |= X264_CPU_STACK_MOD4;
#endif
    if( *cpu_new & X264_CPU_SSE2_IS_FAST )
        *cpu_new &= ~X264_CPU_SSE2_IS_SLOW;
    if( !quiet )
        fprintf( stderr, "x264: %s\n", name );
    return check_all_funcs( *cpu_ref, *cpu_new );
}

static int check_all_flags( void )
{
    int ret = 0;
    uint32_t cpu0 = 0, cpu1 = 0;
    uint32_t cpu_detect = x264_cpu_detect();
#if HAVE_MMX
    if( cpu_detect & X264_CPU_AVX512 )
        simd_warmup_func = x264_checkasm_warmup_avx512;
    else if( cpu_detect & X264_CPU_AVX )
        simd_warmup_func = x264_checkasm_warmup_avx;
#endif
    simd_warmup();

#if ARCH_X86 || ARCH_X86_64
    if( cpu_detect & X264_CPU_MMX2 )
    {
        ret |= add_flags( &cpu0, &cpu1, X264_CPU_MMX | X264_CPU_MMX2, "MMX" );
        ret |= add_flags( &cpu0, &cpu1, X264_CPU_CACHELINE_64, "MMX Cache64" );
        cpu1 &= ~X264_CPU_CACHELINE_64;
#if ARCH_X86
        ret |= add_flags( &cpu0, &cpu1, X264_CPU_CACHELINE_32, "MMX Cache32" );
        cpu1 &= ~X264_CPU_CACHELINE_32;
#endif
    }
    if( cpu_detect & X264_CPU_SSE )
        ret |= add_flags( &cpu0, &cpu1, X264_CPU_SSE, "SSE" );
    if( cpu_detect & X264_CPU_SSE2 )
    {
        ret |= add_flags( &cpu0, &cpu1, X264_CPU_SSE2 | X264_CPU_SSE2_IS_SLOW, "SSE2Slow" );
        ret |= add_flags( &cpu0, &cpu1, X264_CPU_SSE2_IS_FAST, "SSE2Fast" );
        ret |= add_flags( &cpu0, &cpu1, X264_CPU_CACHELINE_64, "SSE2Fast Cache64" );
        cpu1 &= ~X264_CPU_CACHELINE_64;
        ret |= add_flags( &cpu0, &cpu1, X264_CPU_SLOW_SHUFFLE, "SSE2 SlowShuffle" );
        cpu1 &= ~X264_CPU_SLOW_SHUFFLE;
    }
    if( cpu_detect & X264_CPU_LZCNT )
    {
        ret |= add_flags( &cpu0, &cpu1, X264_CPU_LZCNT, "LZCNT" );
        cpu1 &= ~X264_CPU_LZCNT;
    }
    if( cpu_detect & X264_CPU_SSE3 )
    {
        ret |= add_flags( &cpu0, &cpu1, X264_CPU_SSE3 | X264_CPU_CACHELINE_64, "SSE3" );
        cpu1 &= ~X264_CPU_CACHELINE_64;
    }
    if( cpu_detect & X264_CPU_SSSE3 )
    {
        ret |= add_flags( &cpu0, &cpu1, X264_CPU_SSSE3, "SSSE3" );
        ret |= add_flags( &cpu0, &cpu1, X264_CPU_CACHELINE_64, "SSSE3 Cache64" );
        cpu1 &= ~X264_CPU_CACHELINE_64;
        ret |= add_flags( &cpu0, &cpu1, X264_CPU_SLOW_SHUFFLE, "SSSE3 SlowShuffle" );
        cpu1 &= ~X264_CPU_SLOW_SHUFFLE;
        ret |= add_flags( &cpu0, &cpu1, X264_CPU_SLOW_ATOM, "SSSE3 SlowAtom" );
        ret |= add_flags( &cpu0, &cpu1, X264_CPU_CACHELINE_64, "SSSE3 Cache64 SlowAtom" );
        cpu1 &= ~X264_CPU_CACHELINE_64;
        cpu1 &= ~X264_CPU_SLOW_ATOM;
        if( cpu_detect & X264_CPU_LZCNT )
        {
            ret |= add_flags( &cpu0, &cpu1, X264_CPU_LZCNT, "SSSE3 LZCNT" );
            cpu1 &= ~X264_CPU_LZCNT;
        }
    }
    if( cpu_detect & X264_CPU_SSE4 )
        ret |= add_flags( &cpu0, &cpu1, X264_CPU_SSE4, "SSE4" );
    if( cpu_detect & X264_CPU_SSE42 )
        ret |= add_flags( &cpu0, &cpu1, X264_CPU_SSE42, "SSE4.2" );
    if( cpu_detect & X264_CPU_AVX )
        ret |= add_flags( &cpu0, &cpu1, X264_CPU_AVX, "AVX" );
    if( cpu_detect & X264_CPU_XOP )
        ret |= add_flags( &cpu0, &cpu1, X264_CPU_XOP, "XOP" );
    if( cpu_detect & X264_CPU_FMA4 )
    {
        ret |= add_flags( &cpu0, &cpu1, X264_CPU_FMA4, "FMA4" );
        cpu1 &= ~X264_CPU_FMA4;
    }
    if( cpu_detect & X264_CPU_FMA3 )
        ret |= add_flags( &cpu0, &cpu1, X264_CPU_FMA3, "FMA3" );
    if( cpu_detect & X264_CPU_BMI1 )
        ret |= add_flags( &cpu0, &cpu1, X264_CPU_BMI1, "BMI1" );
    if( cpu_detect & X264_CPU_BMI2 )
        ret |= add_flags( &cpu0, &cpu1, X264_CPU_BMI2, "BMI2" );
    if( cpu_detect & X264_CPU_AVX2 )
        ret |= add_flags( &cpu0, &cpu1, X264_CPU_AVX2, "AVX2" );
    if( cpu_detect & X264_CPU_AVX512 )
        ret |= add_flags( &cpu0, &cpu1, X264_CPU_AVX512, "AVX512" );
#elif ARCH_PPC
    if( cpu_detect & X264_CPU_ALTIVEC )
    {
        fprintf( stderr, "x264: ALTIVEC against C\n" );
        ret = check_all_funcs( 0, X264_CPU_ALTIVEC );
    }
#elif ARCH_ARM
    if( cpu_detect & X264_CPU_NEON )
        x264_checkasm_call = x264_checkasm_call_neon;
    if( cpu_detect & X264_CPU_ARMV6 )
        ret |= add_flags( &cpu0, &cpu1, X264_CPU_ARMV6, "ARMv6" );
    if( cpu_detect & X264_CPU_NEON )
        ret |= add_flags( &cpu0, &cpu1, X264_CPU_NEON, "NEON" );
    if( cpu_detect & X264_CPU_FAST_NEON_MRC )
        ret |= add_flags( &cpu0, &cpu1, X264_CPU_FAST_NEON_MRC, "Fast NEON MRC" );
#elif ARCH_AARCH64
    if( cpu_detect & X264_CPU_ARMV8 )
        ret |= add_flags( &cpu0, &cpu1, X264_CPU_ARMV8, "ARMv8" );
    if( cpu_detect & X264_CPU_NEON )
        ret |= add_flags( &cpu0, &cpu1, X264_CPU_NEON, "NEON" );
#elif ARCH_MIPS
    if( cpu_detect & X264_CPU_MSA )
        ret |= add_flags( &cpu0, &cpu1, X264_CPU_MSA, "MSA" );
#endif
    return ret;
}

REALIGN_STACK int main( int argc, char **argv )
{
#ifdef _WIN32
    /* Disable the Windows Error Reporting dialog */
    SetErrorMode( SEM_NOGPFAULTERRORBOX );
#endif

    if( argc > 1 && !strncmp( argv[1], "--bench", 7 ) )
    {
#if !ARCH_X86 && !ARCH_X86_64 && !ARCH_PPC && !ARCH_ARM && !ARCH_AARCH64 && !ARCH_MIPS
        fprintf( stderr, "no --bench for your cpu until you port rdtsc\n" );
        return 1;
#endif
        do_bench = 1;
        if( argv[1][7] == '=' )
        {
            bench_pattern = argv[1]+8;
            bench_pattern_len = strlen(bench_pattern);
        }
        argc--;
        argv++;
    }

    unsigned seed = ( argc > 1 ) ? strtoul(argv[1], NULL, 0) : (unsigned)x264_mdate();
    fprintf( stderr, "x264: using random seed %u\n", seed );
    srand( seed );

    buf1 = x264_malloc( 0x1e00 + 0x2000*SIZEOF_PIXEL );
    pbuf1 = x264_malloc( 0x1e00*SIZEOF_PIXEL );
    if( !buf1 || !pbuf1 )
    {
        fprintf( stderr, "malloc failed, unable to initiate tests!\n" );
        return -1;
    }
#define INIT_POINTER_OFFSETS\
    buf2 = buf1 + 0xf00;\
    buf3 = buf2 + 0xf00;\
    buf4 = buf3 + 0x1000*SIZEOF_PIXEL;\
    pbuf2 = pbuf1 + 0xf00;\
    pbuf3 = (pixel*)buf3;\
    pbuf4 = (pixel*)buf4;
    INIT_POINTER_OFFSETS;
    for( int i = 0; i < 0x1e00; i++ )
    {
        buf1[i] = rand() & 0xFF;
        pbuf1[i] = rand() & PIXEL_MAX;
    }
    memset( buf1+0x1e00, 0, 0x2000*SIZEOF_PIXEL );

    if( x264_stack_pagealign( check_all_flags, 0 ) )
    {
        fprintf( stderr, "x264: at least one test has failed. Go and fix that Right Now!\n" );
        return -1;
    }
    fprintf( stderr, "x264: All tests passed Yeah :)\n" );
    if( do_bench )
        print_bench();
    return 0;
}
