/*-
 * SPDX-License-Identifier: BSD-2-Clause-FreeBSD
 *
 * Copyright (c) 2004 David Schultz <das@FreeBSD.ORG>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * $FreeBSD$
 */

#include "platform_common.h"

#define __FDLIBM_STDC__

#ifndef FLT_EVAL_METHOD
#define FLT_EVAL_METHOD 0
#endif

typedef uint32_t u_int32_t;
typedef uint64_t u_int64_t;

typedef union u32double_tag {
    int *pint;
    double *pdouble;
} U32DOUBLE;

static inline int *
pdouble2pint(double *pdouble)
{
    U32DOUBLE u;
    u.pdouble = pdouble;
    return u.pint;
}

typedef union {
    double value;
    struct {
        u_int32_t lsw;
        u_int32_t msw;
    } parts;
    struct {
        u_int64_t w;
    } xparts;
} ieee_double_shape_type_little;

typedef union {
    double value;
    struct {
        u_int32_t msw;
        u_int32_t lsw;
    } parts;
    struct {
        u_int64_t w;
    } xparts;
} ieee_double_shape_type_big;

typedef union {
    double d;
    struct {
        unsigned int manl : 32;
        unsigned int manh : 20;
        unsigned int exp : 11;
        unsigned int sign : 1;
    } bits;
} IEEEd2bits_L;

typedef union {
    double d;
    struct {
        unsigned int sign : 1;
        unsigned int exp : 11;
        unsigned int manh : 20;
        unsigned int manl : 32;
    } bits;
} IEEEd2bits_B;

typedef union {
    float f;
    struct {
        unsigned int man : 23;
        unsigned int exp : 8;
        unsigned int sign : 1;
    } bits;
} IEEEf2bits_L;

typedef union {
    float f;
    struct {
        unsigned int sign : 1;
        unsigned int exp : 8;
        unsigned int man : 23;
    } bits;
} IEEEf2bits_B;

static union {
    int a;
    char b;
} __ue = { .a = 1 };

#define is_little_endian() (__ue.b == 1)

#define __HIL(x) *(1 + pdouble2pint(&x))
#define __LOL(x) *(pdouble2pint(&x))
#define __HIB(x) *(pdouble2pint(&x))
#define __LOB(x) *(1 + pdouble2pint(&x))

/* Get two 32 bit ints from a double.  */

#define EXTRACT_WORDS_L(ix0, ix1, d)        \
    do {                                    \
        ieee_double_shape_type_little ew_u; \
        ew_u.value = (d);                   \
        (ix0) = ew_u.parts.msw;             \
        (ix1) = ew_u.parts.lsw;             \
    } while (0)

/* Set a double from two 32 bit ints.  */

#define INSERT_WORDS_L(d, ix0, ix1)         \
    do {                                    \
        ieee_double_shape_type_little iw_u; \
        iw_u.parts.msw = (ix0);             \
        iw_u.parts.lsw = (ix1);             \
        (d) = iw_u.value;                   \
    } while (0)

/* Get two 32 bit ints from a double.  */

#define EXTRACT_WORDS_B(ix0, ix1, d)     \
    do {                                 \
        ieee_double_shape_type_big ew_u; \
        ew_u.value = (d);                \
        (ix0) = ew_u.parts.msw;          \
        (ix1) = ew_u.parts.lsw;          \
    } while (0)

/* Set a double from two 32 bit ints.  */

#define INSERT_WORDS_B(d, ix0, ix1)      \
    do {                                 \
        ieee_double_shape_type_big iw_u; \
        iw_u.parts.msw = (ix0);          \
        iw_u.parts.lsw = (ix1);          \
        (d) = iw_u.value;                \
    } while (0)

/* Get the more significant 32 bit int from a double.  */
#define GET_HIGH_WORD_L(i, d)               \
    do {                                    \
        ieee_double_shape_type_little gh_u; \
        gh_u.value = (d);                   \
        (i) = gh_u.parts.msw;               \
    } while (0)

/* Get the more significant 32 bit int from a double.  */
#define GET_HIGH_WORD_B(i, d)            \
    do {                                 \
        ieee_double_shape_type_big gh_u; \
        gh_u.value = (d);                \
        (i) = gh_u.parts.msw;            \
    } while (0)

/* Set the more significant 32 bits of a double from an int.  */
#define SET_HIGH_WORD_L(d, v)               \
    do {                                    \
        ieee_double_shape_type_little sh_u; \
        sh_u.value = (d);                   \
        sh_u.parts.msw = (v);               \
        (d) = sh_u.value;                   \
    } while (0)

/* Set the more significant 32 bits of a double from an int.  */
#define SET_HIGH_WORD_B(d, v)            \
    do {                                 \
        ieee_double_shape_type_big sh_u; \
        sh_u.value = (d);                \
        sh_u.parts.msw = (v);            \
        (d) = sh_u.value;                \
    } while (0)

/* Set the less significant 32 bits of a double from an int.  */
#define SET_LOW_WORD_L(d, v)                \
    do {                                    \
        ieee_double_shape_type_little sh_u; \
        sh_u.value = (d);                   \
        sh_u.parts.lsw = (v);               \
        (d) = sh_u.value;                   \
    } while (0)

/* Set the more significant 32 bits of a double from an int.  */
#define SET_LOW_WORD_B(d, v)             \
    do {                                 \
        ieee_double_shape_type_big sh_u; \
        sh_u.value = (d);                \
        sh_u.parts.lsw = (v);            \
        (d) = sh_u.value;                \
    } while (0)

/* Get the less significant 32 bit int from a double.  */
#define GET_LOW_WORD_L(i, d)                \
    do {                                    \
        ieee_double_shape_type_little gl_u; \
        gl_u.value = (d);                   \
        (i) = gl_u.parts.lsw;               \
    } while (0)

/* Get the less significant 32 bit int from a double.  */
#define GET_LOW_WORD_B(i, d)             \
    do {                                 \
        ieee_double_shape_type_big gl_u; \
        gl_u.value = (d);                \
        (i) = gl_u.parts.lsw;            \
    } while (0)

/*
 * A union which permits us to convert between a float and a 32 bit
 * int.
 */
typedef union {
    float value;
    /* FIXME: Assumes 32 bit int.  */
    unsigned int word;
} ieee_float_shape_type;

/* Get a 32 bit int from a float.  */
#define GET_FLOAT_WORD(i, d)        \
    do {                            \
        ieee_float_shape_type gf_u; \
        gf_u.value = (d);           \
        (i) = gf_u.word;            \
    } while (0)

/* Set a float from a 32 bit int.  */
#define SET_FLOAT_WORD(d, i)        \
    do {                            \
        ieee_float_shape_type sf_u; \
        sf_u.word = (i);            \
        (d) = sf_u.value;           \
    } while (0)

/* Macro wrappers.  */
#define EXTRACT_WORDS(ix0, ix1, d)        \
    do {                                  \
        if (is_little_endian())           \
            EXTRACT_WORDS_L(ix0, ix1, d); \
        else                              \
            EXTRACT_WORDS_B(ix0, ix1, d); \
    } while (0)

#define INSERT_WORDS(d, ix0, ix1)        \
    do {                                 \
        if (is_little_endian())          \
            INSERT_WORDS_L(d, ix0, ix1); \
        else                             \
            INSERT_WORDS_B(d, ix0, ix1); \
    } while (0)

#define GET_HIGH_WORD(i, d)        \
    do {                           \
        if (is_little_endian())    \
            GET_HIGH_WORD_L(i, d); \
        else                       \
            GET_HIGH_WORD_B(i, d); \
    } while (0)

#define SET_HIGH_WORD(d, v)        \
    do {                           \
        if (is_little_endian())    \
            SET_HIGH_WORD_L(d, v); \
        else                       \
            SET_HIGH_WORD_B(d, v); \
    } while (0)

#define GET_LOW_WORD(d, v)        \
    do {                          \
        if (is_little_endian())   \
            GET_LOW_WORD_L(d, v); \
        else                      \
            GET_LOW_WORD_B(d, v); \
    } while (0)

#define SET_LOW_WORD(d, v)        \
    do {                          \
        if (is_little_endian())   \
            SET_LOW_WORD_L(d, v); \
        else                      \
            SET_LOW_WORD_B(d, v); \
    } while (0)

#define __HI(x) (is_little_endian() ? __HIL(x) : __HIB(x))

#define __LO(x) (is_little_endian() ? __LOL(x) : __LOB(x))

/*
 * Attempt to get strict C99 semantics for assignment with non-C99 compilers.
 */
#if FLT_EVAL_METHOD == 0 || __GNUC__ == 0
#define STRICT_ASSIGN(type, lval, rval) ((lval) = (rval))
#else
#define STRICT_ASSIGN(type, lval, rval)          \
    do {                                         \
        volatile type __lval;                    \
                                                 \
        if (sizeof(type) >= sizeof(long double)) \
            (lval) = (rval);                     \
        else {                                   \
            __lval = (rval);                     \
            (lval) = __lval;                     \
        }                                        \
    } while (0)
#endif

#ifdef __FDLIBM_STDC__
static const double huge = 1.0e300;
#else
static double huge = 1.0e300;
#endif

#ifdef __STDC__
static const double
#else
static double
#endif
    tiny = 1.0e-300;

#ifdef __STDC__
static const double
#else
static double
#endif
    one = 1.00000000000000000000e+00; /* 0x3FF00000, 0x00000000 */

#ifdef __STDC__
static const double
#else
static double
#endif
    TWO52[2] = {
        4.50359962737049600000e+15,  /* 0x43300000, 0x00000000 */
        -4.50359962737049600000e+15, /* 0xC3300000, 0x00000000 */
    };

#ifdef __STDC__
static const double
#else
static double
#endif
    atanhi[] = {
        4.63647609000806093515e-01, /* atan(0.5)hi 0x3FDDAC67, 0x0561BB4F */
        7.85398163397448278999e-01, /* atan(1.0)hi 0x3FE921FB, 0x54442D18 */
        9.82793723247329054082e-01, /* atan(1.5)hi 0x3FEF730B, 0xD281F69B */
        1.57079632679489655800e+00, /* atan(inf)hi 0x3FF921FB, 0x54442D18 */
    };

#ifdef __STDC__
static const double
#else
static double
#endif
    atanlo[] = {
        2.26987774529616870924e-17, /* atan(0.5)lo 0x3C7A2B7F, 0x222F65E2 */
        3.06161699786838301793e-17, /* atan(1.0)lo 0x3C81A626, 0x33145C07 */
        1.39033110312309984516e-17, /* atan(1.5)lo 0x3C700788, 0x7AF0CBBD */
        6.12323399573676603587e-17, /* atan(inf)lo 0x3C91A626, 0x33145C07 */
    };

#ifdef __STDC__
static const double
#else
static double
#endif
    aT[] = {
        3.33333333333329318027e-01,  /* 0x3FD55555, 0x5555550D */
        -1.99999999998764832476e-01, /* 0xBFC99999, 0x9998EBC4 */
        1.42857142725034663711e-01,  /* 0x3FC24924, 0x920083FF */
        -1.11111104054623557880e-01, /* 0xBFBC71C6, 0xFE231671 */
        9.09088713343650656196e-02,  /* 0x3FB745CD, 0xC54C206E */
        -7.69187620504482999495e-02, /* 0xBFB3B0F2, 0xAF749A6D */
        6.66107313738753120669e-02,  /* 0x3FB10D66, 0xA0D03D51 */
        -5.83357013379057348645e-02, /* 0xBFADDE2D, 0x52DEFD9A */
        4.97687799461593236017e-02,  /* 0x3FA97B4B, 0x24760DEB */
        -3.65315727442169155270e-02, /* 0xBFA2B444, 0x2C6A6C2F */
        1.62858201153657823623e-02,  /* 0x3F90AD3A, 0xE322DA11 */
    };

#ifdef __STDC__
static const double
#else
static double
#endif
    zero = 0.0,
    pi_o_4 = 7.8539816339744827900E-01, /* 0x3FE921FB, 0x54442D18 */
    pi_o_2 = 1.5707963267948965580E+00, /* 0x3FF921FB, 0x54442D18 */
    pi = 3.1415926535897931160E+00,     /* 0x400921FB, 0x54442D18 */
    pi_lo = 1.2246467991473531772E-16;  /* 0x3CA1A626, 0x33145C07 */

#ifdef __STDC__
static const double
#else
static double
#endif
bp[] = {1.0, 1.5,},
dp_h[] = { 0.0, 5.84962487220764160156e-01,}, /* 0x3FE2B803, 0x40000000 */
dp_l[] = { 0.0, 1.35003920212974897128e-08,}, /* 0x3E4CFDEB, 0x43CFD006 */
two	=  2.0,
two53	=  9007199254740992.0,	/* 0x43400000, 0x00000000 */
two54   =  1.80143985094819840000e+16, /* 0x43500000, 0x00000000 */
twom54  =  5.55111512312578270212e-17, /* 0x3C900000, 0x00000000 */
	/* poly coefs for (3/2)*(log(x)-2s-2/3*s**3 */
L1  =  5.99999999999994648725e-01, /* 0x3FE33333, 0x33333303 */
L2  =  4.28571428578550184252e-01, /* 0x3FDB6DB6, 0xDB6FABFF */
L3  =  3.33333329818377432918e-01, /* 0x3FD55555, 0x518F264D */
L4  =  2.72728123808534006489e-01, /* 0x3FD17460, 0xA91D4101 */
L5  =  2.30660745775561754067e-01, /* 0x3FCD864A, 0x93C9DB65 */
L6  =  2.06975017800338417784e-01, /* 0x3FCA7E28, 0x4A454EEF */
P1   =  1.66666666666666019037e-01, /* 0x3FC55555, 0x5555553E */
P2   = -2.77777777770155933842e-03, /* 0xBF66C16C, 0x16BEBD93 */
P3   =  6.61375632143793436117e-05, /* 0x3F11566A, 0xAF25DE2C */
P4   = -1.65339022054652515390e-06, /* 0xBEBBBD41, 0xC5D26BF1 */
P5   =  4.13813679705723846039e-08, /* 0x3E663769, 0x72BEA4D0 */
lg2  =  6.93147180559945286227e-01, /* 0x3FE62E42, 0xFEFA39EF */
lg2_h  =  6.93147182464599609375e-01, /* 0x3FE62E43, 0x00000000 */
lg2_l  = -1.90465429995776804525e-09, /* 0xBE205C61, 0x0CA86C39 */
ovt =  8.0085662595372944372e-0017, /* -(1024-log2(ovfl+.5ulp)) */
cp    =  9.61796693925975554329e-01, /* 0x3FEEC709, 0xDC3A03FD =2/(3ln2) */
cp_h  =  9.61796700954437255859e-01, /* 0x3FEEC709, 0xE0000000 =(float)cp */
cp_l  = -7.02846165095275826516e-09, /* 0xBE3E2FE0, 0x145B01F5 =tail of cp_h*/
ivln2    =  1.44269504088896338700e+00, /* 0x3FF71547, 0x652B82FE =1/ln2 */
ivln2_h  =  1.44269502162933349609e+00, /* 0x3FF71547, 0x60000000 =24b 1/ln2*/
ivln2_l  =  1.92596299112661746887e-08; /* 0x3E54AE0B, 0xF85DDF44 =1/ln2 tail*/

static double
freebsd_floor(double x);
static double
freebsd_ceil(double x);
static double
freebsd_fabs(double x);
static double
freebsd_rint(double x);
static int
freebsd_isnan(double x);
static double
freebsd_atan(double x);
static double
freebsd_atan2(double y, double x);

static double
freebsd_atan(double x)
{
    double w, s1, s2, z;
    int32_t ix, hx, id;

    GET_HIGH_WORD(hx, x);
    ix = hx & 0x7fffffff;
    if (ix >= 0x44100000) { /* if |x| >= 2^66 */
        u_int32_t low;
        GET_LOW_WORD(low, x);
        if (ix > 0x7ff00000 || (ix == 0x7ff00000 && (low != 0)))
            return x + x; /* NaN */
        if (hx > 0)
            return atanhi[3] + *(volatile double *)&atanlo[3];
        else
            return -atanhi[3] - *(volatile double *)&atanlo[3];
    }
    if (ix < 0x3fdc0000) {     /* |x| < 0.4375 */
        if (ix < 0x3e400000) { /* |x| < 2^-27 */
            if (huge + x > one)
                return x; /* raise inexact */
        }
        id = -1;
    }
    else {
        x = freebsd_fabs(x);
        if (ix < 0x3ff30000) {     /* |x| < 1.1875 */
            if (ix < 0x3fe60000) { /* 7/16 <=|x|<11/16 */
                id = 0;
                x = (2.0 * x - one) / (2.0 + x);
            }
            else { /* 11/16<=|x|< 19/16 */
                id = 1;
                x = (x - one) / (x + one);
            }
        }
        else {
            if (ix < 0x40038000) { /* |x| < 2.4375 */
                id = 2;
                x = (x - 1.5) / (one + 1.5 * x);
            }
            else { /* 2.4375 <= |x| < 2^66 */
                id = 3;
                x = -1.0 / x;
            }
        }
    }
    /* end of argument reduction */
    z = x * x;
    w = z * z;
    /* break sum from i=0 to 10 aT[i]z**(i+1) into odd and even poly */
    s1 = z
         * (aT[0]
            + w
                  * (aT[2]
                     + w * (aT[4] + w * (aT[6] + w * (aT[8] + w * aT[10])))));
    s2 = w * (aT[1] + w * (aT[3] + w * (aT[5] + w * (aT[7] + w * aT[9]))));
    if (id < 0)
        return x - x * (s1 + s2);
    else {
        z = atanhi[id] - ((x * (s1 + s2) - atanlo[id]) - x);
        return (hx < 0) ? -z : z;
    }
}

static double
freebsd_atan2(double y, double x)
{
    double z;
    int32_t k, m, hx, hy, ix, iy;
    u_int32_t lx, ly;

    EXTRACT_WORDS(hx, lx, x);
    ix = hx & 0x7fffffff;
    EXTRACT_WORDS(hy, ly, y);
    iy = hy & 0x7fffffff;
    if (((ix | ((lx | -lx) >> 31)) > 0x7ff00000)
        || ((iy | ((ly | -ly) >> 31)) > 0x7ff00000)) /* x or y is NaN */
        return x + y;
    if (hx == 0x3ff00000 && lx == 0)
        return freebsd_atan(y);              /* x=1.0 */
    m = ((hy >> 31) & 1) | ((hx >> 30) & 2); /* 2*sign(x)+sign(y) */

    /* when y = 0 */
    if ((iy | ly) == 0) {
        switch (m) {
            case 0:
            case 1:
                return y; /* atan(+-0,+anything)=+-0 */
            case 2:
                return pi + tiny; /* atan(+0,-anything) = pi */
            case 3:
            default:
                return -pi - tiny; /* atan(-0,-anything) =-pi */
        }
    }
    /* when x = 0 */
    if ((ix | lx) == 0)
        return (hy < 0) ? -pi_o_2 - tiny : pi_o_2 + tiny;

    /* when x is INF */
    if (ix == 0x7ff00000) {
        if (iy == 0x7ff00000) {
            switch (m) {
                case 0:
                    return pi_o_4 + tiny; /* atan(+INF,+INF) */
                case 1:
                    return -pi_o_4 - tiny; /* atan(-INF,+INF) */
                case 2:
                    return 3.0 * pi_o_4 + tiny; /*atan(+INF,-INF)*/
                case 3:
                default:
                    return -3.0 * pi_o_4 - tiny; /*atan(-INF,-INF)*/
            }
        }
        else {
            switch (m) {
                case 0:
                    return zero; /* atan(+...,+INF) */
                case 1:
                    return -zero; /* atan(-...,+INF) */
                case 2:
                    return pi + tiny; /* atan(+...,-INF) */
                case 3:
                default:
                    return -pi - tiny; /* atan(-...,-INF) */
            }
        }
    }
    /* when y is INF */
    if (iy == 0x7ff00000)
        return (hy < 0) ? -pi_o_2 - tiny : pi_o_2 + tiny;

    /* compute y/x */
    k = (iy - ix) >> 20;
    if (k > 60) { /* |y/x| >  2**60 */
        z = pi_o_2 + 0.5 * pi_lo;
        m &= 1;
    }
    else if (hx < 0 && k < -60)
        z = 0.0; /* 0 > |y|/x > -2**-60 */
    else
        z = freebsd_atan(fabs(y / x)); /* safe to do y/x */
    switch (m) {
        case 0:
            return z; /* atan(+,+) */
        case 1:
            return -z; /* atan(-,+) */
        case 2:
            return pi - (z - pi_lo); /* atan(+,-) */
        default:                     /* case 3 */
            return (z - pi_lo) - pi; /* atan(-,-) */
    }
}

#ifndef BH_HAS_SQRTF
static float
freebsd_sqrtf(float x)
{
    float z;
    int32_t sign = (int)0x80000000;
    int32_t ix, s, q, m, t, i;
    u_int32_t r;

    GET_FLOAT_WORD(ix, x);

    /* take care of Inf and NaN */
    if ((ix & 0x7f800000) == 0x7f800000) {
        return x * x + x; /* sqrt(NaN)=NaN, sqrt(+inf)=+inf
                     sqrt(-inf)=sNaN */
    }
    /* take care of zero */
    if (ix <= 0) {
        if ((ix & (~sign)) == 0)
            return x; /* sqrt(+-0) = +-0 */
        else if (ix < 0)
            return (x - x) / (x - x); /* sqrt(-ve) = sNaN */
    }
    /* normalize x */
    m = (ix >> 23);
    if (m == 0) { /* subnormal x */
        for (i = 0; (ix & 0x00800000) == 0; i++)
            ix <<= 1;
        m -= i - 1;
    }
    m -= 127; /* unbias exponent */
    ix = (ix & 0x007fffff) | 0x00800000;
    if (m & 1) /* odd m, double x to make it even */
        ix += ix;
    m >>= 1; /* m = [m/2] */

    /* generate sqrt(x) bit by bit */
    ix += ix;
    q = s = 0;      /* q = sqrt(x) */
    r = 0x01000000; /* r = moving bit from right to left */

    while (r != 0) {
        t = s + r;
        if (t <= ix) {
            s = t + r;
            ix -= t;
            q += r;
        }
        ix += ix;
        r >>= 1;
    }

    /* use floating add to find out rounding direction */
    if (ix != 0) {
        z = one - tiny; /* trigger inexact flag */
        if (z >= one) {
            z = one + tiny;
            if (z > one)
                q += 2;
            else
                q += (q & 1);
        }
    }
    ix = (q >> 1) + 0x3f000000;
    ix += (m << 23);
    SET_FLOAT_WORD(z, ix);
    return z;
}
#endif /* end of BH_HAS_SQRTF */

#ifndef BH_HAS_SQRT
static double
freebsd_sqrt(double x) /* wrapper sqrt */
{
    double z;
    int32_t sign = (int)0x80000000;
    int32_t ix0, s0, q, m, t, i;
    u_int32_t r, t1, s1, ix1, q1;

    EXTRACT_WORDS(ix0, ix1, x);

    /* take care of Inf and NaN */
    if ((ix0 & 0x7ff00000) == 0x7ff00000) {
        return x * x + x; /* sqrt(NaN)=NaN, sqrt(+inf)=+inf
                     sqrt(-inf)=sNaN */
    }
    /* take care of zero */
    if (ix0 <= 0) {
        if (((ix0 & (~sign)) | ix1) == 0)
            return x; /* sqrt(+-0) = +-0 */
        else if (ix0 < 0)
            return (x - x) / (x - x); /* sqrt(-ve) = sNaN */
    }
    /* normalize x */
    m = (ix0 >> 20);
    if (m == 0) { /* subnormal x */
        while (ix0 == 0) {
            m -= 21;
            ix0 |= (ix1 >> 11);
            ix1 <<= 21;
        }
        for (i = 0; (ix0 & 0x00100000) == 0; i++)
            ix0 <<= 1;
        m -= i - 1;
        ix0 |= (ix1 >> (32 - i));
        ix1 <<= i;
    }
    m -= 1023; /* unbias exponent */
    ix0 = (ix0 & 0x000fffff) | 0x00100000;
    if (m & 1) { /* odd m, double x to make it even */
        ix0 += ix0 + ((ix1 & sign) >> 31);
        ix1 += ix1;
    }
    m >>= 1; /* m = [m/2] */

    /* generate sqrt(x) bit by bit */
    ix0 += ix0 + ((ix1 & sign) >> 31);
    ix1 += ix1;
    q = q1 = s0 = s1 = 0; /* [q,q1] = sqrt(x) */
    r = 0x00200000;       /* r = moving bit from right to left */

    while (r != 0) {
        t = s0 + r;
        if (t <= ix0) {
            s0 = t + r;
            ix0 -= t;
            q += r;
        }
        ix0 += ix0 + ((ix1 & sign) >> 31);
        ix1 += ix1;
        r >>= 1;
    }

    r = sign;
    while (r != 0) {
        t1 = s1 + r;
        t = s0;
        if ((t < ix0) || ((t == ix0) && (t1 <= ix1))) {
            s1 = t1 + r;
            if (((t1 & sign) == sign) && (s1 & sign) == 0)
                s0 += 1;
            ix0 -= t;
            if (ix1 < t1)
                ix0 -= 1;
            ix1 -= t1;
            q1 += r;
        }
        ix0 += ix0 + ((ix1 & sign) >> 31);
        ix1 += ix1;
        r >>= 1;
    }

    /* use floating add to find out rounding direction */
    if ((ix0 | ix1) != 0) {
        z = one - tiny; /* trigger inexact flag */
        if (z >= one) {
            z = one + tiny;
            if (q1 == (u_int32_t)0xffffffff) {
                q1 = 0;
                q += 1;
            }
            else if (z > one) {
                if (q1 == (u_int32_t)0xfffffffe)
                    q += 1;
                q1 += 2;
            }
            else
                q1 += (q1 & 1);
        }
    }
    ix0 = (q >> 1) + 0x3fe00000;
    ix1 = q1 >> 1;
    if ((q & 1) == 1)
        ix1 |= sign;
    ix0 += (m << 20);

    INSERT_WORDS(z, ix0, ix1);

    return z;
}
#endif /* end of BH_HAS_SQRT */

static double
freebsd_floor(double x)
{
    int32_t i0, i1, j0;
    u_int32_t i, j;

    EXTRACT_WORDS(i0, i1, x);

    j0 = ((i0 >> 20) & 0x7ff) - 0x3ff;
    if (j0 < 20) {
        if (j0 < 0) {             /* raise inexact if x != 0 */
            if (huge + x > 0.0) { /* return 0*sign(x) if |x|<1 */
                if (i0 >= 0) {
                    i0 = i1 = 0;
                }
                else if (((i0 & 0x7fffffff) | i1) != 0) {
                    i0 = 0xbff00000;
                    i1 = 0;
                }
            }
        }
        else {
            i = (0x000fffff) >> j0;
            if (((i0 & i) | i1) == 0)
                return x;         /* x is integral */
            if (huge + x > 0.0) { /* raise inexact flag */
                if (i0 < 0)
                    i0 += (0x00100000) >> j0;
                i0 &= (~i);
                i1 = 0;
            }
        }
    }
    else if (j0 > 51) {
        if (j0 == 0x400)
            return x + x; /* inf or NaN */
        else
            return x; /* x is integral */
    }
    else {
        i = ((u_int32_t)(0xffffffff)) >> (j0 - 20);
        if ((i1 & i) == 0)
            return x;         /* x is integral */
        if (huge + x > 0.0) { /* raise inexact flag */
            if (i0 < 0) {
                if (j0 == 20)
                    i0 += 1;
                else {
                    j = i1 + (1 << (52 - j0));
                    if (j < i1)
                        i0 += 1; /* got a carry */
                    i1 = j;
                }
            }
            i1 &= (~i);
        }
    }

    INSERT_WORDS(x, i0, i1);

    return x;
}

static double
freebsd_ceil(double x)
{
    int32_t i0, i1, j0;
    u_int32_t i, j;
    EXTRACT_WORDS(i0, i1, x);
    j0 = ((i0 >> 20) & 0x7ff) - 0x3ff;
    if (j0 < 20) {
        if (j0 < 0) {             /* raise inexact if x != 0 */
            if (huge + x > 0.0) { /* return 0*sign(x) if |x|<1 */
                if (i0 < 0) {
                    i0 = 0x80000000;
                    i1 = 0;
                }
                else if ((i0 | i1) != 0) {
                    i0 = 0x3ff00000;
                    i1 = 0;
                }
            }
        }
        else {
            i = (0x000fffff) >> j0;
            if (((i0 & i) | i1) == 0)
                return x;         /* x is integral */
            if (huge + x > 0.0) { /* raise inexact flag */
                if (i0 > 0)
                    i0 += (0x00100000) >> j0;
                i0 &= (~i);
                i1 = 0;
            }
        }
    }
    else if (j0 > 51) {
        if (j0 == 0x400)
            return x + x; /* inf or NaN */
        else
            return x; /* x is integral */
    }
    else {
        i = ((u_int32_t)(0xffffffff)) >> (j0 - 20);
        if ((i1 & i) == 0)
            return x;         /* x is integral */
        if (huge + x > 0.0) { /* raise inexact flag */
            if (i0 > 0) {
                if (j0 == 20)
                    i0 += 1;
                else {
                    j = i1 + (1 << (52 - j0));
                    if (j < i1)
                        i0 += 1; /* got a carry */
                    i1 = j;
                }
            }
            i1 &= (~i);
        }
    }
    INSERT_WORDS(x, i0, i1);
    return x;
}

static double
freebsd_rint(double x)
{
    int32_t i0, j0, sx;
    u_int32_t i, i1;
    double w, t;
    EXTRACT_WORDS(i0, i1, x);
    sx = (i0 >> 31) & 1;
    j0 = ((i0 >> 20) & 0x7ff) - 0x3ff;
    if (j0 < 20) {
        if (j0 < 0) {
            if (((i0 & 0x7fffffff) | i1) == 0)
                return x;
            i1 |= (i0 & 0x0fffff);
            i0 &= 0xfffe0000;
            i0 |= ((i1 | -i1) >> 12) & 0x80000;
            SET_HIGH_WORD(x, i0);
            STRICT_ASSIGN(double, w, TWO52[sx] + x);
            t = w - TWO52[sx];
            GET_HIGH_WORD(i0, t);
            SET_HIGH_WORD(t, (i0 & 0x7fffffff) | (sx << 31));
            return t;
        }
        else {
            i = (0x000fffff) >> j0;
            if (((i0 & i) | i1) == 0)
                return x; /* x is integral */
            i >>= 1;
            if (((i0 & i) | i1) != 0) {
                /*
                 * Some bit is set after the 0.5 bit.  To avoid the
                 * possibility of errors from double rounding in
                 * w = TWO52[sx]+x, adjust the 0.25 bit to a lower
                 * guard bit.  We do this for all j0<=51.  The
                 * adjustment is trickiest for j0==18 and j0==19
                 * since then it spans the word boundary.
                 */
                if (j0 == 19)
                    i1 = 0x40000000;
                else if (j0 == 18)
                    i1 = 0x80000000;
                else
                    i0 = (i0 & (~i)) | ((0x20000) >> j0);
            }
        }
    }
    else if (j0 > 51) {
        if (j0 == 0x400)
            return x + x; /* inf or NaN */
        else
            return x; /* x is integral */
    }
    else {
        i = ((u_int32_t)(0xffffffff)) >> (j0 - 20);
        if ((i1 & i) == 0)
            return x; /* x is integral */
        i >>= 1;
        if ((i1 & i) != 0)
            i1 = (i1 & (~i)) | ((0x40000000) >> (j0 - 20));
    }
    INSERT_WORDS(x, i0, i1);
    STRICT_ASSIGN(double, w, TWO52[sx] + x);
    return w - TWO52[sx];
}

static int
freebsd_isnan(double d)
{
    if (is_little_endian()) {
        IEEEd2bits_L u;
        u.d = d;
        return (u.bits.exp == 2047 && (u.bits.manl != 0 || u.bits.manh != 0));
    }
    else {
        IEEEd2bits_B u;
        u.d = d;
        return (u.bits.exp == 2047 && (u.bits.manl != 0 || u.bits.manh != 0));
    }
}

static float
freebsd_fabsf(float x)
{
    u_int32_t ix;
    GET_FLOAT_WORD(ix, x);
    SET_FLOAT_WORD(x, ix & 0x7fffffff);
    return x;
}

static double
freebsd_fabs(double x)
{
    u_int32_t high;
    GET_HIGH_WORD(high, x);
    SET_HIGH_WORD(x, high & 0x7fffffff);
    return x;
}

static const float huge_f = 1.0e30F;

static const float TWO23[2] = {
    8.3886080000e+06,  /* 0x4b000000 */
    -8.3886080000e+06, /* 0xcb000000 */
};

static float
freebsd_truncf(float x)
{
    int32_t i0, j0;
    u_int32_t i;
    GET_FLOAT_WORD(i0, x);
    j0 = ((i0 >> 23) & 0xff) - 0x7f;
    if (j0 < 23) {
        if (j0 < 0) {              /* raise inexact if x != 0 */
            if (huge_f + x > 0.0F) /* |x|<1, so return 0*sign(x) */
                i0 &= 0x80000000;
        }
        else {
            i = (0x007fffff) >> j0;
            if ((i0 & i) == 0)
                return x;          /* x is integral */
            if (huge_f + x > 0.0F) /* raise inexact flag */
                i0 &= (~i);
        }
    }
    else {
        if (j0 == 0x80)
            return x + x; /* inf or NaN */
        else
            return x; /* x is integral */
    }
    SET_FLOAT_WORD(x, i0);
    return x;
}

static float
freebsd_rintf(float x)
{
    int32_t i0, j0, sx;
    float w, t;
    GET_FLOAT_WORD(i0, x);
    sx = (i0 >> 31) & 1;
    j0 = ((i0 >> 23) & 0xff) - 0x7f;
    if (j0 < 23) {
        if (j0 < 0) {
            if ((i0 & 0x7fffffff) == 0)
                return x;
            STRICT_ASSIGN(float, w, TWO23[sx] + x);
            t = w - TWO23[sx];
            GET_FLOAT_WORD(i0, t);
            SET_FLOAT_WORD(t, (i0 & 0x7fffffff) | (sx << 31));
            return t;
        }
        STRICT_ASSIGN(float, w, TWO23[sx] + x);
        return w - TWO23[sx];
    }
    if (j0 == 0x80)
        return x + x; /* inf or NaN */
    else
        return x; /* x is integral */
}

static float
freebsd_ceilf(float x)
{
    int32_t i0, j0;
    u_int32_t i;

    GET_FLOAT_WORD(i0, x);
    j0 = ((i0 >> 23) & 0xff) - 0x7f;
    if (j0 < 23) {
        if (j0 < 0) {                      /* raise inexact if x != 0 */
            if (huge_f + x > (float)0.0) { /* return 0*sign(x) if |x|<1 */
                if (i0 < 0) {
                    i0 = 0x80000000;
                }
                else if (i0 != 0) {
                    i0 = 0x3f800000;
                }
            }
        }
        else {
            i = (0x007fffff) >> j0;
            if ((i0 & i) == 0)
                return x;                  /* x is integral */
            if (huge_f + x > (float)0.0) { /* raise inexact flag */
                if (i0 > 0)
                    i0 += (0x00800000) >> j0;
                i0 &= (~i);
            }
        }
    }
    else {
        if (j0 == 0x80)
            return x + x; /* inf or NaN */
        else
            return x; /* x is integral */
    }
    SET_FLOAT_WORD(x, i0);
    return x;
}

static float
freebsd_floorf(float x)
{
    int32_t i0, j0;
    u_int32_t i;
    GET_FLOAT_WORD(i0, x);
    j0 = ((i0 >> 23) & 0xff) - 0x7f;
    if (j0 < 23) {
        if (j0 < 0) {                      /* raise inexact if x != 0 */
            if (huge_f + x > (float)0.0) { /* return 0*sign(x) if |x|<1 */
                if (i0 >= 0) {
                    i0 = 0;
                }
                else if ((i0 & 0x7fffffff) != 0) {
                    i0 = 0xbf800000;
                }
            }
        }
        else {
            i = (0x007fffff) >> j0;
            if ((i0 & i) == 0)
                return x;                  /* x is integral */
            if (huge_f + x > (float)0.0) { /* raise inexact flag */
                if (i0 < 0)
                    i0 += (0x00800000) >> j0;
                i0 &= (~i);
            }
        }
    }
    else {
        if (j0 == 0x80)
            return x + x; /* inf or NaN */
        else
            return x; /* x is integral */
    }
    SET_FLOAT_WORD(x, i0);
    return x;
}

static float
freebsd_fminf(float x, float y)
{
    if (is_little_endian()) {
        IEEEf2bits_L u[2] = { 0 };

        u[0].f = x;
        u[1].f = y;

        /* Check for NaNs to avoid raising spurious exceptions. */
        if (u[0].bits.exp == 255 && u[0].bits.man != 0)
            return (y);
        if (u[1].bits.exp == 255 && u[1].bits.man != 0)
            return (x);

        /* Handle comparisons of signed zeroes. */
        if (u[0].bits.sign != u[1].bits.sign)
            return (u[u[1].bits.sign].f);
    }
    else {
        IEEEf2bits_B u[2] = { 0 };

        u[0].f = x;
        u[1].f = y;

        /* Check for NaNs to avoid raising spurious exceptions. */
        if (u[0].bits.exp == 255 && u[0].bits.man != 0)
            return (y);
        if (u[1].bits.exp == 255 && u[1].bits.man != 0)
            return (x);

        /* Handle comparisons of signed zeroes. */
        if (u[0].bits.sign != u[1].bits.sign)
            return (u[u[1].bits.sign].f);
    }

    return (x < y ? x : y);
}

static float
freebsd_fmaxf(float x, float y)
{
    if (is_little_endian()) {
        IEEEf2bits_L u[2] = { 0 };

        u[0].f = x;
        u[1].f = y;

        /* Check for NaNs to avoid raising spurious exceptions. */
        if (u[0].bits.exp == 255 && u[0].bits.man != 0)
            return (y);
        if (u[1].bits.exp == 255 && u[1].bits.man != 0)
            return (x);

        /* Handle comparisons of signed zeroes. */
        if (u[0].bits.sign != u[1].bits.sign)
            return (u[u[0].bits.sign].f);
    }
    else {
        IEEEf2bits_B u[2] = { 0 };

        u[0].f = x;
        u[1].f = y;

        /* Check for NaNs to avoid raising spurious exceptions. */
        if (u[0].bits.exp == 255 && u[0].bits.man != 0)
            return (y);
        if (u[1].bits.exp == 255 && u[1].bits.man != 0)
            return (x);

        /* Handle comparisons of signed zeroes. */
        if (u[0].bits.sign != u[1].bits.sign)
            return (u[u[0].bits.sign].f);
    }

    return (x > y ? x : y);
}

static double
freebsd_copysign(double x, double y)
{
    u_int32_t hx, hy;
    GET_HIGH_WORD(hx, x);
    GET_HIGH_WORD(hy, y);
    SET_HIGH_WORD(x, (hx & 0x7fffffff) | (hy & 0x80000000));
    return x;
}

static double
freebsd_scalbn(double x, int n)
{
    int32_t k, hx, lx;
    EXTRACT_WORDS(hx, lx, x);
    k = (hx & 0x7ff00000) >> 20; /* extract exponent */
    if (k == 0) {                /* 0 or subnormal x */
        if ((lx | (hx & 0x7fffffff)) == 0)
            return x; /* +-0 */
        x *= two54;
        GET_HIGH_WORD(hx, x);
        k = ((hx & 0x7ff00000) >> 20) - 54;
        if (n < -50000)
            return tiny * x; /*underflow*/
    }
    if (k == 0x7ff)
        return x + x; /* NaN or Inf */
    k = k + n;
    if (k > 0x7fe)
        return huge * freebsd_copysign(huge, x); /* overflow  */
    if (k > 0)                                   /* normal result */
    {
        SET_HIGH_WORD(x, (hx & 0x800fffff) | (k << 20));
        return x;
    }
    if (k <= -54) {
        if (n > 50000) /* in case integer overflow in n+k */
            return huge * freebsd_copysign(huge, x); /*overflow*/
        else
            return tiny * freebsd_copysign(tiny, x); /*underflow*/
    }
    k += 54; /* subnormal result */
    SET_HIGH_WORD(x, (hx & 0x800fffff) | (k << 20));
    return x * twom54;
}

static double
freebsd_pow(double x, double y)
{
    double z, ax, z_h, z_l, p_h, p_l;
    double y1, t1, t2, r, s, t, u, v, w;
    int32_t i, j, k, yisint, n;
    int32_t hx, hy, ix, iy;
    u_int32_t lx, ly;

    EXTRACT_WORDS(hx, lx, x);
    EXTRACT_WORDS(hy, ly, y);
    ix = hx & 0x7fffffff;
    iy = hy & 0x7fffffff;

    /* y==zero: x**0 = 1 */
    if ((iy | ly) == 0)
        return one;

    /* x==1: 1**y = 1, even if y is NaN */
    if (hx == 0x3ff00000 && lx == 0)
        return one;

    /* y!=zero: result is NaN if either arg is NaN */
    if (ix > 0x7ff00000 || ((ix == 0x7ff00000) && (lx != 0)) || iy > 0x7ff00000
        || ((iy == 0x7ff00000) && (ly != 0)))
        return (x + 0.0) + (y + 0.0);

    /* determine if y is an odd int when x < 0
     * yisint = 0	... y is not an integer
     * yisint = 1	... y is an odd int
     * yisint = 2	... y is an even int
     */
    yisint = 0;
    if (hx < 0) {
        if (iy >= 0x43400000)
            yisint = 2; /* even integer y */
        else if (iy >= 0x3ff00000) {
            k = (iy >> 20) - 0x3ff; /* exponent */
            if (k > 20) {
                j = ly >> (52 - k);
                if ((j << (52 - k)) == ly)
                    yisint = 2 - (j & 1);
            }
            else if (ly == 0) {
                j = iy >> (20 - k);
                if ((j << (20 - k)) == iy)
                    yisint = 2 - (j & 1);
            }
        }
    }

    /* special value of y */
    if (ly == 0) {
        if (iy == 0x7ff00000) { /* y is +-inf */
            if (((ix - 0x3ff00000) | lx) == 0)
                return one;            /* (-1)**+-inf is NaN */
            else if (ix >= 0x3ff00000) /* (|x|>1)**+-inf = inf,0 */
                return (hy >= 0) ? y : zero;
            else /* (|x|<1)**-,+inf = inf,0 */
                return (hy < 0) ? -y : zero;
        }
        if (iy == 0x3ff00000) { /* y is  +-1 */
            if (hy < 0)
                return one / x;
            else
                return x;
        }
        if (hy == 0x40000000)
            return x * x; /* y is  2 */
        if (hy == 0x40080000)
            return x * x * x;   /* y is  3 */
        if (hy == 0x40100000) { /* y is  4 */
            u = x * x;
            return u * u;
        }
        if (hy == 0x3fe00000) { /* y is  0.5 */
            if (hx >= 0)        /* x >= +0 */
                return sqrt(x);
        }
    }

    ax = fabs(x);
    /* special value of x */
    if (lx == 0) {
        if (ix == 0x7ff00000 || ix == 0 || ix == 0x3ff00000) {
            z = ax; /*x is +-0,+-inf,+-1*/
            if (hy < 0)
                z = one / z; /* z = (1/|x|) */
            if (hx < 0) {
                if (((ix - 0x3ff00000) | yisint) == 0) {
                    z = (z - z) / (z - z); /* (-1)**non-int is NaN */
                }
                else if (yisint == 1)
                    z = -z; /* (x<0)**odd = -(|x|**odd) */
            }
            return z;
        }
    }

    /* CYGNUS LOCAL + fdlibm-5.3 fix: This used to be
    n = (hx>>31)+1;
       but ANSI C says a right shift of a signed negative quantity is
       implementation defined.  */
    n = ((u_int32_t)hx >> 31) - 1;

    /* (x<0)**(non-int) is NaN */
    if ((n | yisint) == 0)
        return (x - x) / (x - x);

    s = one; /* s (sign of result -ve**odd) = -1 else = 1 */
    if ((n | (yisint - 1)) == 0)
        s = -one; /* (-ve)**(odd int) */

    /* |y| is huge */
    if (iy > 0x41e00000) {     /* if |y| > 2**31 */
        if (iy > 0x43f00000) { /* if |y| > 2**64, must o/uflow */
            if (ix <= 0x3fefffff)
                return (hy < 0) ? huge * huge : tiny * tiny;
            if (ix >= 0x3ff00000)
                return (hy > 0) ? huge * huge : tiny * tiny;
        }
        /* over/underflow if x is not close to one */
        if (ix < 0x3fefffff)
            return (hy < 0) ? s * huge * huge : s * tiny * tiny;
        if (ix > 0x3ff00000)
            return (hy > 0) ? s * huge * huge : s * tiny * tiny;
        /* now |1-x| is tiny <= 2**-20, suffice to compute
           log(x) by x-x^2/2+x^3/3-x^4/4 */
        t = ax - one; /* t has 20 trailing zeros */
        w = (t * t) * (0.5 - t * (0.3333333333333333333333 - t * 0.25));
        u = ivln2_h * t; /* ivln2_h has 21 sig. bits */
        v = t * ivln2_l - w * ivln2;
        t1 = u + v;
        SET_LOW_WORD(t1, 0);
        t2 = v - (t1 - u);
    }
    else {
        double ss, s2, s_h, s_l, t_h, t_l;
        n = 0;
        /* take care subnormal number */
        if (ix < 0x00100000) {
            ax *= two53;
            n -= 53;
            GET_HIGH_WORD(ix, ax);
        }
        n += ((ix) >> 20) - 0x3ff;
        j = ix & 0x000fffff;
        /* determine interval */
        ix = j | 0x3ff00000; /* normalize ix */
        if (j <= 0x3988E)
            k = 0; /* |x|<sqrt(3/2) */
        else if (j < 0xBB67A)
            k = 1; /* |x|<sqrt(3)   */
        else {
            k = 0;
            n += 1;
            ix -= 0x00100000;
        }
        SET_HIGH_WORD(ax, ix);

        /* compute ss = s_h+s_l = (x-1)/(x+1) or (x-1.5)/(x+1.5) */
        u = ax - bp[k]; /* bp[0]=1.0, bp[1]=1.5 */
        v = one / (ax + bp[k]);
        ss = u * v;
        s_h = ss;
        SET_LOW_WORD(s_h, 0);
        /* t_h=ax+bp[k] High */
        t_h = zero;
        SET_HIGH_WORD(t_h, ((ix >> 1) | 0x20000000) + 0x00080000 + (k << 18));
        t_l = ax - (t_h - bp[k]);
        s_l = v * ((u - s_h * t_h) - s_h * t_l);
        /* compute log(ax) */
        s2 = ss * ss;
        r = s2 * s2
            * (L1 + s2 * (L2 + s2 * (L3 + s2 * (L4 + s2 * (L5 + s2 * L6)))));
        r += s_l * (s_h + ss);
        s2 = s_h * s_h;
        t_h = 3.0 + s2 + r;
        SET_LOW_WORD(t_h, 0);
        t_l = r - ((t_h - 3.0) - s2);
        /* u+v = ss*(1+...) */
        u = s_h * t_h;
        v = s_l * t_h + t_l * ss;
        /* 2/(3log2)*(ss+...) */
        p_h = u + v;
        SET_LOW_WORD(p_h, 0);
        p_l = v - (p_h - u);
        z_h = cp_h * p_h; /* cp_h+cp_l = 2/(3*log2) */
        z_l = cp_l * p_h + p_l * cp + dp_l[k];
        /* log2(ax) = (ss+..)*2/(3*log2) = n + dp_h + z_h + z_l */
        t = (double)n;
        t1 = (((z_h + z_l) + dp_h[k]) + t);
        SET_LOW_WORD(t1, 0);
        t2 = z_l - (((t1 - t) - dp_h[k]) - z_h);
    }

    /* split up y into y1+y2 and compute (y1+y2)*(t1+t2) */
    y1 = y;
    SET_LOW_WORD(y1, 0);
    p_l = (y - y1) * t1 + y * t2;
    p_h = y1 * t1;
    z = p_l + p_h;
    EXTRACT_WORDS(j, i, z);
    if (j >= 0x40900000) {               /* z >= 1024 */
        if (((j - 0x40900000) | i) != 0) /* if z > 1024 */
            return s * huge * huge;      /* overflow */
        else {
            if (p_l + ovt > z - p_h)
                return s * huge * huge; /* overflow */
        }
    }
    else if ((j & 0x7fffffff) >= 0x4090cc00) { /* z <= -1075 */
        if (((j - 0xc090cc00) | i) != 0)       /* z < -1075 */
            return s * tiny * tiny;            /* underflow */
        else {
            if (p_l <= z - p_h)
                return s * tiny * tiny; /* underflow */
        }
    }
    /*
     * compute 2**(p_h+p_l)
     */
    i = j & 0x7fffffff;
    k = (i >> 20) - 0x3ff;
    n = 0;
    if (i > 0x3fe00000) { /* if |z| > 0.5, set n = [z+0.5] */
        n = j + (0x00100000 >> (k + 1));
        k = ((n & 0x7fffffff) >> 20) - 0x3ff; /* new k for n */
        t = zero;
        SET_HIGH_WORD(t, n & ~(0x000fffff >> k));
        n = ((n & 0x000fffff) | 0x00100000) >> (20 - k);
        if (j < 0)
            n = -n;
        p_h -= t;
    }
    t = p_l + p_h;
    SET_LOW_WORD(t, 0);
    u = t * lg2_h;
    v = (p_l - (t - p_h)) * lg2 + t * lg2_l;
    z = u + v;
    w = v - (z - u);
    t = z * z;
    t1 = z - t * (P1 + t * (P2 + t * (P3 + t * (P4 + t * P5))));
    r = (z * t1) / (t1 - two) - (w + z * w);
    z = one - (r - z);
    GET_HIGH_WORD(j, z);
    j += (n << 20);
    if ((j >> 20) <= 0)
        z = freebsd_scalbn(z, n); /* subnormal output */
    else
        SET_HIGH_WORD(z, j);
    return s * z;
}

double
atan(double x)
{
    return freebsd_atan(x);
}

double
atan2(double y, double x)
{
    return freebsd_atan2(y, x);
}

#ifndef BH_HAS_SQRT
double
sqrt(double x)
{
    return freebsd_sqrt(x);
}
#endif

double
floor(double x)
{
    return freebsd_floor(x);
}

double
ceil(double x)
{
    return freebsd_ceil(x);
}

double
fmin(double x, double y)
{
    return x < y ? x : y;
}

double
fmax(double x, double y)
{
    return x > y ? x : y;
}

double
rint(double x)
{
    return freebsd_rint(x);
}

double
fabs(double x)
{
    return freebsd_fabs(x);
}

int
isnan(double x)
{
    return freebsd_isnan(x);
}

double
trunc(double x)
{
    return (x > 0) ? freebsd_floor(x) : freebsd_ceil(x);
}

int
signbit(double x)
{
    return ((__HI(x) & 0x80000000) >> 31);
}

float
fabsf(float x)
{
    return freebsd_fabsf(x);
}

float
truncf(float x)
{
    return freebsd_truncf(x);
}

float
rintf(float x)
{
    return freebsd_rintf(x);
}

float
ceilf(float x)
{
    return freebsd_ceilf(x);
}

float
floorf(float x)
{
    return freebsd_floorf(x);
}

float
fminf(float x, float y)
{
    return freebsd_fminf(x, y);
}

float
fmaxf(float x, float y)
{
    return freebsd_fmaxf(x, y);
}

#ifndef BH_HAS_SQRTF
float
sqrtf(float x)
{
    return freebsd_sqrtf(x);
}
#endif

double
pow(double x, double y)
{
    return freebsd_pow(x, y);
}

double
scalbn(double x, int n)
{
    return freebsd_scalbn(x, n);
}
