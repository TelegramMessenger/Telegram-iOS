#import "DCTCommon.h"

#if !defined(__aarch64__)

#include <string.h>
#include <stdlib.h>

typedef long JLONG;

#define CONST_BITS  8
#define PASS1_BITS  2

#define DCTSIZE             8   /* The basic DCT block is 8x8 samples */
#define DCTSIZE2            64  /* DCTSIZE squared; # of elements in a block */

#define FIX_0_382683433  ((JLONG)98)            /* FIX(0.382683433) */
#define FIX_0_541196100  ((JLONG)139)           /* FIX(0.541196100) */
#define FIX_0_707106781  ((JLONG)181)           /* FIX(0.707106781) */
#define FIX_1_306562965  ((JLONG)334)           /* FIX(1.306562965) */

#define FIX_1_082392200  ((JLONG)277)           /* FIX(1.082392200) */
#define FIX_1_414213562  ((JLONG)362)           /* FIX(1.414213562) */
#define FIX_1_847759065  ((JLONG)473)           /* FIX(1.847759065) */
#define FIX_2_613125930  ((JLONG)669)           /* FIX(2.613125930) */

#define RIGHT_SHIFT(x, shft)    ((x) >> (shft))
#define IRIGHT_SHIFT(x, shft)   ((x) >> (shft))
#define DESCALE(x, n)  RIGHT_SHIFT(x, n)
#define IDESCALE(x, n)  ((int)IRIGHT_SHIFT(x, n))

#define MULTIPLY(var, const)  ((DCTELEM)DESCALE((var) * (const), CONST_BITS))

#define MULTIPLIER  short       /* prefer 16-bit with SIMD for parellelism */
typedef MULTIPLIER IFAST_MULT_TYPE;  /* 16 bits is OK, use short if faster */

#define DEQUANTIZE(coef, quantval)  (((IFAST_MULT_TYPE)(coef)) * (quantval))

#define RANGE_MASK  (MAXJSAMPLE * 4 + 3) /* 2 bits wider than legal samples */

#define MAXJSAMPLE      255
#define CENTERJSAMPLE   128

typedef JSAMPROW *JSAMPARRAY;   /* ptr to some rows (a 2-D sample array) */
typedef JSAMPARRAY *JSAMPIMAGE; /* a 3-D sample array: top index is color */

#define IDCT_range_limit(cinfo)  ((cinfo)->sample_range_limit + CENTERJSAMPLE)

void dct_jpeg_fdct_ifast(DCTELEM *data)
{
    DCTELEM tmp0, tmp1, tmp2, tmp3, tmp4, tmp5, tmp6, tmp7;
    DCTELEM tmp10, tmp11, tmp12, tmp13;
    DCTELEM z1, z2, z3, z4, z5, z11, z13;
    DCTELEM *dataptr;
    int ctr;
    
    /* Pass 1: process rows. */
    
    dataptr = data;
    for (ctr = DCTSIZE - 1; ctr >= 0; ctr--) {
        tmp0 = dataptr[0] + dataptr[7];
        tmp7 = dataptr[0] - dataptr[7];
        tmp1 = dataptr[1] + dataptr[6];
        tmp6 = dataptr[1] - dataptr[6];
        tmp2 = dataptr[2] + dataptr[5];
        tmp5 = dataptr[2] - dataptr[5];
        tmp3 = dataptr[3] + dataptr[4];
        tmp4 = dataptr[3] - dataptr[4];
        
        /* Even part */
        
        tmp10 = tmp0 + tmp3;        /* phase 2 */
        tmp13 = tmp0 - tmp3;
        tmp11 = tmp1 + tmp2;
        tmp12 = tmp1 - tmp2;
        
        dataptr[0] = tmp10 + tmp11; /* phase 3 */
        dataptr[4] = tmp10 - tmp11;
        
        z1 = MULTIPLY(tmp12 + tmp13, FIX_0_707106781); /* c4 */
        dataptr[2] = tmp13 + z1;    /* phase 5 */
        dataptr[6] = tmp13 - z1;
        
        /* Odd part */
        
        tmp10 = tmp4 + tmp5;        /* phase 2 */
        tmp11 = tmp5 + tmp6;
        tmp12 = tmp6 + tmp7;
        
        /* The rotator is modified from fig 4-8 to avoid extra negations. */
        z5 = MULTIPLY(tmp10 - tmp12, FIX_0_382683433); /* c6 */
        z2 = MULTIPLY(tmp10, FIX_0_541196100) + z5; /* c2-c6 */
        z4 = MULTIPLY(tmp12, FIX_1_306562965) + z5; /* c2+c6 */
        z3 = MULTIPLY(tmp11, FIX_0_707106781); /* c4 */
        
        z11 = tmp7 + z3;            /* phase 5 */
        z13 = tmp7 - z3;
        
        dataptr[5] = z13 + z2;      /* phase 6 */
        dataptr[3] = z13 - z2;
        dataptr[1] = z11 + z4;
        dataptr[7] = z11 - z4;
        
        dataptr += DCTSIZE;         /* advance pointer to next row */
    }
    
    /* Pass 2: process columns. */
    
    dataptr = data;
    for (ctr = DCTSIZE - 1; ctr >= 0; ctr--) {
        tmp0 = dataptr[DCTSIZE * 0] + dataptr[DCTSIZE * 7];
        tmp7 = dataptr[DCTSIZE * 0] - dataptr[DCTSIZE * 7];
        tmp1 = dataptr[DCTSIZE * 1] + dataptr[DCTSIZE * 6];
        tmp6 = dataptr[DCTSIZE * 1] - dataptr[DCTSIZE * 6];
        tmp2 = dataptr[DCTSIZE * 2] + dataptr[DCTSIZE * 5];
        tmp5 = dataptr[DCTSIZE * 2] - dataptr[DCTSIZE * 5];
        tmp3 = dataptr[DCTSIZE * 3] + dataptr[DCTSIZE * 4];
        tmp4 = dataptr[DCTSIZE * 3] - dataptr[DCTSIZE * 4];
        
        /* Even part */
        
        tmp10 = tmp0 + tmp3;        /* phase 2 */
        tmp13 = tmp0 - tmp3;
        tmp11 = tmp1 + tmp2;
        tmp12 = tmp1 - tmp2;
        
        dataptr[DCTSIZE * 0] = tmp10 + tmp11; /* phase 3 */
        dataptr[DCTSIZE * 4] = tmp10 - tmp11;
        
        z1 = MULTIPLY(tmp12 + tmp13, FIX_0_707106781); /* c4 */
        dataptr[DCTSIZE * 2] = tmp13 + z1; /* phase 5 */
        dataptr[DCTSIZE * 6] = tmp13 - z1;
        
        /* Odd part */
        
        tmp10 = tmp4 + tmp5;        /* phase 2 */
        tmp11 = tmp5 + tmp6;
        tmp12 = tmp6 + tmp7;
        
        /* The rotator is modified from fig 4-8 to avoid extra negations. */
        z5 = MULTIPLY(tmp10 - tmp12, FIX_0_382683433); /* c6 */
        z2 = MULTIPLY(tmp10, FIX_0_541196100) + z5; /* c2-c6 */
        z4 = MULTIPLY(tmp12, FIX_1_306562965) + z5; /* c2+c6 */
        z3 = MULTIPLY(tmp11, FIX_0_707106781); /* c4 */
        
        z11 = tmp7 + z3;            /* phase 5 */
        z13 = tmp7 - z3;
        
        dataptr[DCTSIZE * 5] = z13 + z2; /* phase 6 */
        dataptr[DCTSIZE * 3] = z13 - z2;
        dataptr[DCTSIZE * 1] = z11 + z4;
        dataptr[DCTSIZE * 7] = z11 - z4;
        
        dataptr++;                  /* advance pointer to next column */
    }
}

struct DctAuxiliaryData {
    JSAMPLE *allocated_sample_range_limit;
    JSAMPLE *sample_range_limit;
};

static void prepare_range_limit_table(struct DctAuxiliaryData *data)
/* Allocate and fill in the sample_range_limit table */
{
    JSAMPLE *table;
    int i;
    
    table = (JSAMPLE *)malloc((5 * (MAXJSAMPLE + 1) + CENTERJSAMPLE) * sizeof(JSAMPLE));
    data->allocated_sample_range_limit = table;
    table += (MAXJSAMPLE + 1);    /* allow negative subscripts of simple table */
    data->sample_range_limit = table;
    /* First segment of "simple" table: limit[x] = 0 for x < 0 */
    memset(table - (MAXJSAMPLE + 1), 0, (MAXJSAMPLE + 1) * sizeof(JSAMPLE));
    /* Main part of "simple" table: limit[x] = x */
    for (i = 0; i <= MAXJSAMPLE; i++)
        table[i] = (JSAMPLE)i;
    table += CENTERJSAMPLE;       /* Point to where post-IDCT table starts */
    /* End of simple table, rest of first half of post-IDCT table */
    for (i = CENTERJSAMPLE; i < 2 * (MAXJSAMPLE + 1); i++)
        table[i] = MAXJSAMPLE;
    /* Second half of post-IDCT table */
    memset(table + (2 * (MAXJSAMPLE + 1)), 0,
           (2 * (MAXJSAMPLE + 1) - CENTERJSAMPLE) * sizeof(JSAMPLE));
    memcpy(table + (4 * (MAXJSAMPLE + 1) - CENTERJSAMPLE),
           data->sample_range_limit, CENTERJSAMPLE * sizeof(JSAMPLE));
}

struct DctAuxiliaryData *createDctAuxiliaryData() {
    struct DctAuxiliaryData *result = malloc(sizeof(struct DctAuxiliaryData));
    memset(result, 0, sizeof(struct DctAuxiliaryData));
    
    prepare_range_limit_table(result);
    
    return result;
}

void freeDctAuxiliaryData(struct DctAuxiliaryData *data) {
    if (data) {
        free(data->allocated_sample_range_limit);
        free(data);
    }
}

void dct_jpeg_idct_ifast(struct DctAuxiliaryData *auxiliaryData, void *dct_table, JCOEFPTR coef_block, JSAMPROW output_buf) {
    DCTELEM tmp0, tmp1, tmp2, tmp3, tmp4, tmp5, tmp6, tmp7;
    DCTELEM tmp10, tmp11, tmp12, tmp13;
    DCTELEM z5, z10, z11, z12, z13;
    JCOEFPTR inptr;
    IFAST_MULT_TYPE *quantptr;
    int *wsptr;
    JSAMPROW outptr;
    JSAMPLE *range_limit = IDCT_range_limit(auxiliaryData);
    int ctr;
    int workspace[DCTSIZE2];      /* buffers data between passes */
    
    /* Pass 1: process columns from input, store into work array. */
    
    inptr = coef_block;
    quantptr = dct_table;
    wsptr = workspace;
    for (ctr = DCTSIZE; ctr > 0; ctr--) {
        /* Due to quantization, we will usually find that many of the input
         * coefficients are zero, especially the AC terms.  We can exploit this
         * by short-circuiting the IDCT calculation for any column in which all
         * the AC terms are zero.  In that case each output is equal to the
         * DC coefficient (with scale factor as needed).
         * With typical images and quantization tables, half or more of the
         * column DCT calculations can be simplified this way.
         */
        
        if (inptr[DCTSIZE * 1] == 0 && inptr[DCTSIZE * 2] == 0 &&
            inptr[DCTSIZE * 3] == 0 && inptr[DCTSIZE * 4] == 0 &&
            inptr[DCTSIZE * 5] == 0 && inptr[DCTSIZE * 6] == 0 &&
            inptr[DCTSIZE * 7] == 0) {
            /* AC terms all zero */
            int dcval = (int)DEQUANTIZE(inptr[DCTSIZE * 0], quantptr[DCTSIZE * 0]);
            
            wsptr[DCTSIZE * 0] = dcval;
            wsptr[DCTSIZE * 1] = dcval;
            wsptr[DCTSIZE * 2] = dcval;
            wsptr[DCTSIZE * 3] = dcval;
            wsptr[DCTSIZE * 4] = dcval;
            wsptr[DCTSIZE * 5] = dcval;
            wsptr[DCTSIZE * 6] = dcval;
            wsptr[DCTSIZE * 7] = dcval;
            
            inptr++;                  /* advance pointers to next column */
            quantptr++;
            wsptr++;
            continue;
        }
        
        /* Even part */
        
        tmp0 = DEQUANTIZE(inptr[DCTSIZE * 0], quantptr[DCTSIZE * 0]);
        tmp1 = DEQUANTIZE(inptr[DCTSIZE * 2], quantptr[DCTSIZE * 2]);
        tmp2 = DEQUANTIZE(inptr[DCTSIZE * 4], quantptr[DCTSIZE * 4]);
        tmp3 = DEQUANTIZE(inptr[DCTSIZE * 6], quantptr[DCTSIZE * 6]);
        
        tmp10 = tmp0 + tmp2;        /* phase 3 */
        tmp11 = tmp0 - tmp2;
        
        tmp13 = tmp1 + tmp3;        /* phases 5-3 */
        tmp12 = MULTIPLY(tmp1 - tmp3, FIX_1_414213562) - tmp13; /* 2*c4 */
        
        tmp0 = tmp10 + tmp13;       /* phase 2 */
        tmp3 = tmp10 - tmp13;
        tmp1 = tmp11 + tmp12;
        tmp2 = tmp11 - tmp12;
        
        /* Odd part */
        
        tmp4 = DEQUANTIZE(inptr[DCTSIZE * 1], quantptr[DCTSIZE * 1]);
        tmp5 = DEQUANTIZE(inptr[DCTSIZE * 3], quantptr[DCTSIZE * 3]);
        tmp6 = DEQUANTIZE(inptr[DCTSIZE * 5], quantptr[DCTSIZE * 5]);
        tmp7 = DEQUANTIZE(inptr[DCTSIZE * 7], quantptr[DCTSIZE * 7]);
        
        z13 = tmp6 + tmp5;          /* phase 6 */
        z10 = tmp6 - tmp5;
        z11 = tmp4 + tmp7;
        z12 = tmp4 - tmp7;
        
        tmp7 = z11 + z13;           /* phase 5 */
        tmp11 = MULTIPLY(z11 - z13, FIX_1_414213562); /* 2*c4 */
        
        z5 = MULTIPLY(z10 + z12, FIX_1_847759065); /* 2*c2 */
        tmp10 = MULTIPLY(z12, FIX_1_082392200) - z5; /* 2*(c2-c6) */
        tmp12 = MULTIPLY(z10, -FIX_2_613125930) + z5; /* -2*(c2+c6) */
        
        tmp6 = tmp12 - tmp7;        /* phase 2 */
        tmp5 = tmp11 - tmp6;
        tmp4 = tmp10 + tmp5;
        
        wsptr[DCTSIZE * 0] = (int)(tmp0 + tmp7);
        wsptr[DCTSIZE * 7] = (int)(tmp0 - tmp7);
        wsptr[DCTSIZE * 1] = (int)(tmp1 + tmp6);
        wsptr[DCTSIZE * 6] = (int)(tmp1 - tmp6);
        wsptr[DCTSIZE * 2] = (int)(tmp2 + tmp5);
        wsptr[DCTSIZE * 5] = (int)(tmp2 - tmp5);
        wsptr[DCTSIZE * 4] = (int)(tmp3 + tmp4);
        wsptr[DCTSIZE * 3] = (int)(tmp3 - tmp4);
        
        inptr++;                    /* advance pointers to next column */
        quantptr++;
        wsptr++;
    }
    
    /* Pass 2: process rows from work array, store into output array. */
    /* Note that we must descale the results by a factor of 8 == 2**3, */
    /* and also undo the PASS1_BITS scaling. */
    
    wsptr = workspace;
    for (ctr = 0; ctr < DCTSIZE; ctr++) {
        outptr = output_buf + ctr * DCTSIZE;
        /* Rows of zeroes can be exploited in the same way as we did with columns.
         * However, the column calculation has created many nonzero AC terms, so
         * the simplification applies less often (typically 5% to 10% of the time).
         * On machines with very fast multiplication, it's possible that the
         * test takes more time than it's worth.  In that case this section
         * may be commented out.
         */
        
#ifndef NO_ZERO_ROW_TEST
        if (wsptr[1] == 0 && wsptr[2] == 0 && wsptr[3] == 0 && wsptr[4] == 0 &&
            wsptr[5] == 0 && wsptr[6] == 0 && wsptr[7] == 0) {
            /* AC terms all zero */
            JSAMPLE dcval =
            range_limit[IDESCALE(wsptr[0], PASS1_BITS + 3) & RANGE_MASK];
            
            outptr[0] = dcval;
            outptr[1] = dcval;
            outptr[2] = dcval;
            outptr[3] = dcval;
            outptr[4] = dcval;
            outptr[5] = dcval;
            outptr[6] = dcval;
            outptr[7] = dcval;
            
            wsptr += DCTSIZE;         /* advance pointer to next row */
            continue;
        }
#endif
        
        /* Even part */
        
        tmp10 = ((DCTELEM)wsptr[0] + (DCTELEM)wsptr[4]);
        tmp11 = ((DCTELEM)wsptr[0] - (DCTELEM)wsptr[4]);
        
        tmp13 = ((DCTELEM)wsptr[2] + (DCTELEM)wsptr[6]);
        tmp12 =
        MULTIPLY((DCTELEM)wsptr[2] - (DCTELEM)wsptr[6], FIX_1_414213562) - tmp13;
        
        tmp0 = tmp10 + tmp13;
        tmp3 = tmp10 - tmp13;
        tmp1 = tmp11 + tmp12;
        tmp2 = tmp11 - tmp12;
        
        /* Odd part */
        
        z13 = (DCTELEM)wsptr[5] + (DCTELEM)wsptr[3];
        z10 = (DCTELEM)wsptr[5] - (DCTELEM)wsptr[3];
        z11 = (DCTELEM)wsptr[1] + (DCTELEM)wsptr[7];
        z12 = (DCTELEM)wsptr[1] - (DCTELEM)wsptr[7];
        
        tmp7 = z11 + z13;           /* phase 5 */
        tmp11 = MULTIPLY(z11 - z13, FIX_1_414213562); /* 2*c4 */
        
        z5 = MULTIPLY(z10 + z12, FIX_1_847759065); /* 2*c2 */
        tmp10 = MULTIPLY(z12, FIX_1_082392200) - z5; /* 2*(c2-c6) */
        tmp12 = MULTIPLY(z10, -FIX_2_613125930) + z5; /* -2*(c2+c6) */
        
        tmp6 = tmp12 - tmp7;        /* phase 2 */
        tmp5 = tmp11 - tmp6;
        tmp4 = tmp10 + tmp5;
        
        /* Final output stage: scale down by a factor of 8 and range-limit */
        
        outptr[0] =
        range_limit[IDESCALE(tmp0 + tmp7, PASS1_BITS + 3) & RANGE_MASK];
        outptr[7] =
        range_limit[IDESCALE(tmp0 - tmp7, PASS1_BITS + 3) & RANGE_MASK];
        outptr[1] =
        range_limit[IDESCALE(tmp1 + tmp6, PASS1_BITS + 3) & RANGE_MASK];
        outptr[6] =
        range_limit[IDESCALE(tmp1 - tmp6, PASS1_BITS + 3) & RANGE_MASK];
        outptr[2] =
        range_limit[IDESCALE(tmp2 + tmp5, PASS1_BITS + 3) & RANGE_MASK];
        outptr[5] =
        range_limit[IDESCALE(tmp2 - tmp5, PASS1_BITS + 3) & RANGE_MASK];
        outptr[4] =
        range_limit[IDESCALE(tmp3 + tmp4, PASS1_BITS + 3) & RANGE_MASK];
        outptr[3] =
        range_limit[IDESCALE(tmp3 - tmp4, PASS1_BITS + 3) & RANGE_MASK];
        
        wsptr += DCTSIZE;           /* advance pointer to next row */
    }
}

#endif
