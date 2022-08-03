#import "DCTCommon.h"

#include <stdlib.h>

#if defined(__aarch64__)

typedef long JLONG;

#define GETJSAMPLE(value)  ((int)(value))

#define MAXJSAMPLE      255
#define CENTERJSAMPLE   128

typedef unsigned int JDIMENSION;

#define JPEG_MAX_DIMENSION  65500L  /* a tad under 64K to prevent overflows */

#define MULTIPLIER  short       /* prefer 16-bit with SIMD for parellelism */
typedef MULTIPLIER IFAST_MULT_TYPE;  /* 16 bits is OK, use short if faster */

#define IFAST_SCALE_BITS  2          /* fractional bits in scale factors */

/* Various constants determining the sizes of things.
 * All of these are specified by the JPEG standard, so don't change them
 * if you want to be compatible.
 */

#define DCTSIZE             8   /* The basic DCT block is 8x8 samples */
#define DCTSIZE2            64  /* DCTSIZE squared; # of elements in a block */
#define NUM_QUANT_TBLS      4   /* Quantization tables are numbered 0..3 */
#define NUM_HUFF_TBLS       4   /* Huffman tables are numbered 0..3 */
#define NUM_ARITH_TBLS      16  /* Arith-coding tables are numbered 0..15 */
#define MAX_COMPS_IN_SCAN   4   /* JPEG limit on # of components in one scan */
#define MAX_SAMP_FACTOR     4   /* JPEG limit on sampling factors */
/* Unfortunately, some bozo at Adobe saw no reason to be bound by the standard;
 * the PostScript DCT filter can emit files with many more than 10 blocks/MCU.
 * If you happen to run across such a file, you can up D_MAX_BLOCKS_IN_MCU
 * to handle it.  We even let you do this from the jconfig.h file.  However,
 * we strongly discourage changing C_MAX_BLOCKS_IN_MCU; just because Adobe
 * sometimes emits noncompliant files doesn't mean you should too.
 */
#define C_MAX_BLOCKS_IN_MCU   10 /* compressor's limit on blocks per MCU */
#ifndef D_MAX_BLOCKS_IN_MCU
#define D_MAX_BLOCKS_IN_MCU   10 /* decompressor's limit on blocks per MCU */
#endif


/* Data structures for images (arrays of samples and of DCT coefficients).
 */

typedef JSAMPROW *JSAMPARRAY;   /* ptr to some rows (a 2-D sample array) */
typedef JSAMPARRAY *JSAMPIMAGE; /* a 3-D sample array: top index is color */

typedef JCOEF JBLOCK[DCTSIZE2]; /* one block of coefficients */
typedef JBLOCK *JBLOCKROW;      /* pointer to one row of coefficient blocks */
typedef JBLOCKROW *JBLOCKARRAY;         /* a 2-D array of coefficient blocks */
typedef JBLOCKARRAY *JBLOCKIMAGE;       /* a 3-D array of coefficient blocks */

#include <arm_neon.h>

/* jsimd_idct_ifast_neon() performs dequantization and a fast, not so accurate
 * inverse DCT (Discrete Cosine Transform) on one block of coefficients.  It
 * uses the same calculations and produces exactly the same output as IJG's
 * original jpeg_idct_ifast() function, which can be found in jidctfst.c.
 *
 * Scaled integer constants are used to avoid floating-point arithmetic:
 *    0.082392200 =  2688 * 2^-15
 *    0.414213562 = 13568 * 2^-15
 *    0.847759065 = 27776 * 2^-15
 *    0.613125930 = 20096 * 2^-15
 *
 * See jidctfst.c for further details of the IDCT algorithm.  Where possible,
 * the variable names and comments here in jsimd_idct_ifast_neon() match up
 * with those in jpeg_idct_ifast().
 */

#define PASS1_BITS  2

#define F_0_082  2688
#define F_0_414  13568
#define F_0_847  27776
#define F_0_613  20096


__attribute__((aligned(16))) static const int16_t jsimd_idct_ifast_neon_consts[] = {
    F_0_082, F_0_414, F_0_847, F_0_613
};

#define F_0_382  12544
#define F_0_541  17792
#define F_0_707  23168
#define F_0_306  9984


__attribute__((aligned(16))) static const int16_t jsimd_fdct_ifast_neon_consts[] = {
    F_0_382, F_0_541, F_0_707, F_0_306
};

#define FIX_0_382683433  ((JLONG)98)            /* FIX(0.382683433) */
#define FIX_0_541196100  ((JLONG)139)           /* FIX(0.541196100) */
#define FIX_0_707106781  ((JLONG)181)           /* FIX(0.707106781) */
#define FIX_1_306562965  ((JLONG)334)           /* FIX(1.306562965) */

#define FIX_1_082392200  ((JLONG)277)           /* FIX(1.082392200) */
#define FIX_1_414213562  ((JLONG)362)           /* FIX(1.414213562) */
#define FIX_1_847759065  ((JLONG)473)           /* FIX(1.847759065) */
#define FIX_2_613125930  ((JLONG)669)           /* FIX(2.613125930) */

#define CONST_BITS  8
#define RIGHT_SHIFT(x, shft)    ((x) >> (shft))
#define IRIGHT_SHIFT(x, shft)   ((x) >> (shft))
#define DESCALE(x, n)  RIGHT_SHIFT(x, n)
#define IDESCALE(x, n)  ((int)IRIGHT_SHIFT(x, n))
#define MULTIPLY(var, const)  ((DCTELEM)DESCALE((var) * (const), CONST_BITS))

#define DEQUANTIZE(coef, quantval)  (((IFAST_MULT_TYPE)(coef)) * (quantval))

#define NO_ZERO_ROW_TEST

void dct_jpeg_fdct_ifast(DCTELEM *data) {
    /* Load an 8x8 block of samples into Neon registers.  De-interleaving loads
     * are used, followed by vuzp to transpose the block such that we have a
     * column of samples per vector - allowing all rows to be processed at once.
     */
    int16x8x4_t data1 = vld4q_s16(data);
    int16x8x4_t data2 = vld4q_s16(data + 4 * DCTSIZE);
    
    int16x8x2_t cols_04 = vuzpq_s16(data1.val[0], data2.val[0]);
    int16x8x2_t cols_15 = vuzpq_s16(data1.val[1], data2.val[1]);
    int16x8x2_t cols_26 = vuzpq_s16(data1.val[2], data2.val[2]);
    int16x8x2_t cols_37 = vuzpq_s16(data1.val[3], data2.val[3]);
    
    int16x8_t col0 = cols_04.val[0];
    int16x8_t col1 = cols_15.val[0];
    int16x8_t col2 = cols_26.val[0];
    int16x8_t col3 = cols_37.val[0];
    int16x8_t col4 = cols_04.val[1];
    int16x8_t col5 = cols_15.val[1];
    int16x8_t col6 = cols_26.val[1];
    int16x8_t col7 = cols_37.val[1];
    
    /* Pass 1: process rows. */
    
    /* Load DCT conversion constants. */
    const int16x4_t consts = vld1_s16(jsimd_fdct_ifast_neon_consts);
    
    int16x8_t tmp0 = vaddq_s16(col0, col7);
    int16x8_t tmp7 = vsubq_s16(col0, col7);
    int16x8_t tmp1 = vaddq_s16(col1, col6);
    int16x8_t tmp6 = vsubq_s16(col1, col6);
    int16x8_t tmp2 = vaddq_s16(col2, col5);
    int16x8_t tmp5 = vsubq_s16(col2, col5);
    int16x8_t tmp3 = vaddq_s16(col3, col4);
    int16x8_t tmp4 = vsubq_s16(col3, col4);
    
    /* Even part */
    int16x8_t tmp10 = vaddq_s16(tmp0, tmp3);    /* phase 2 */
    int16x8_t tmp13 = vsubq_s16(tmp0, tmp3);
    int16x8_t tmp11 = vaddq_s16(tmp1, tmp2);
    int16x8_t tmp12 = vsubq_s16(tmp1, tmp2);
    
    col0 = vaddq_s16(tmp10, tmp11);             /* phase 3 */
    col4 = vsubq_s16(tmp10, tmp11);
    
    int16x8_t z1 = vqdmulhq_lane_s16(vaddq_s16(tmp12, tmp13), consts, 2);
    col2 = vaddq_s16(tmp13, z1);                /* phase 5 */
    col6 = vsubq_s16(tmp13, z1);
    
    /* Odd part */
    tmp10 = vaddq_s16(tmp4, tmp5);              /* phase 2 */
    tmp11 = vaddq_s16(tmp5, tmp6);
    tmp12 = vaddq_s16(tmp6, tmp7);
    
    int16x8_t z5 = vqdmulhq_lane_s16(vsubq_s16(tmp10, tmp12), consts, 0);
    int16x8_t z2 = vqdmulhq_lane_s16(tmp10, consts, 1);
    z2 = vaddq_s16(z2, z5);
    int16x8_t z4 = vqdmulhq_lane_s16(tmp12, consts, 3);
    z5 = vaddq_s16(tmp12, z5);
    z4 = vaddq_s16(z4, z5);
    int16x8_t z3 = vqdmulhq_lane_s16(tmp11, consts, 2);
    
    int16x8_t z11 = vaddq_s16(tmp7, z3);        /* phase 5 */
    int16x8_t z13 = vsubq_s16(tmp7, z3);
    
    col5 = vaddq_s16(z13, z2);                  /* phase 6 */
    col3 = vsubq_s16(z13, z2);
    col1 = vaddq_s16(z11, z4);
    col7 = vsubq_s16(z11, z4);
    
    /* Transpose to work on columns in pass 2. */
    int16x8x2_t cols_01 = vtrnq_s16(col0, col1);
    int16x8x2_t cols_23 = vtrnq_s16(col2, col3);
    int16x8x2_t cols_45 = vtrnq_s16(col4, col5);
    int16x8x2_t cols_67 = vtrnq_s16(col6, col7);
    
    int32x4x2_t cols_0145_l = vtrnq_s32(vreinterpretq_s32_s16(cols_01.val[0]),
                                        vreinterpretq_s32_s16(cols_45.val[0]));
    int32x4x2_t cols_0145_h = vtrnq_s32(vreinterpretq_s32_s16(cols_01.val[1]),
                                        vreinterpretq_s32_s16(cols_45.val[1]));
    int32x4x2_t cols_2367_l = vtrnq_s32(vreinterpretq_s32_s16(cols_23.val[0]),
                                        vreinterpretq_s32_s16(cols_67.val[0]));
    int32x4x2_t cols_2367_h = vtrnq_s32(vreinterpretq_s32_s16(cols_23.val[1]),
                                        vreinterpretq_s32_s16(cols_67.val[1]));
    
    int32x4x2_t rows_04 = vzipq_s32(cols_0145_l.val[0], cols_2367_l.val[0]);
    int32x4x2_t rows_15 = vzipq_s32(cols_0145_h.val[0], cols_2367_h.val[0]);
    int32x4x2_t rows_26 = vzipq_s32(cols_0145_l.val[1], cols_2367_l.val[1]);
    int32x4x2_t rows_37 = vzipq_s32(cols_0145_h.val[1], cols_2367_h.val[1]);
    
    int16x8_t row0 = vreinterpretq_s16_s32(rows_04.val[0]);
    int16x8_t row1 = vreinterpretq_s16_s32(rows_15.val[0]);
    int16x8_t row2 = vreinterpretq_s16_s32(rows_26.val[0]);
    int16x8_t row3 = vreinterpretq_s16_s32(rows_37.val[0]);
    int16x8_t row4 = vreinterpretq_s16_s32(rows_04.val[1]);
    int16x8_t row5 = vreinterpretq_s16_s32(rows_15.val[1]);
    int16x8_t row6 = vreinterpretq_s16_s32(rows_26.val[1]);
    int16x8_t row7 = vreinterpretq_s16_s32(rows_37.val[1]);
    
    /* Pass 2: process columns. */
    
    tmp0 = vaddq_s16(row0, row7);
    tmp7 = vsubq_s16(row0, row7);
    tmp1 = vaddq_s16(row1, row6);
    tmp6 = vsubq_s16(row1, row6);
    tmp2 = vaddq_s16(row2, row5);
    tmp5 = vsubq_s16(row2, row5);
    tmp3 = vaddq_s16(row3, row4);
    tmp4 = vsubq_s16(row3, row4);
    
    /* Even part */
    tmp10 = vaddq_s16(tmp0, tmp3);              /* phase 2 */
    tmp13 = vsubq_s16(tmp0, tmp3);
    tmp11 = vaddq_s16(tmp1, tmp2);
    tmp12 = vsubq_s16(tmp1, tmp2);
    
    row0 = vaddq_s16(tmp10, tmp11);             /* phase 3 */
    row4 = vsubq_s16(tmp10, tmp11);
    
    z1 = vqdmulhq_lane_s16(vaddq_s16(tmp12, tmp13), consts, 2);
    row2 = vaddq_s16(tmp13, z1);                /* phase 5 */
    row6 = vsubq_s16(tmp13, z1);
    
    /* Odd part */
    tmp10 = vaddq_s16(tmp4, tmp5);              /* phase 2 */
    tmp11 = vaddq_s16(tmp5, tmp6);
    tmp12 = vaddq_s16(tmp6, tmp7);
    
    z5 = vqdmulhq_lane_s16(vsubq_s16(tmp10, tmp12), consts, 0);
    z2 = vqdmulhq_lane_s16(tmp10, consts, 1);
    z2 = vaddq_s16(z2, z5);
    z4 = vqdmulhq_lane_s16(tmp12, consts, 3);
    z5 = vaddq_s16(tmp12, z5);
    z4 = vaddq_s16(z4, z5);
    z3 = vqdmulhq_lane_s16(tmp11, consts, 2);
    
    z11 = vaddq_s16(tmp7, z3);                  /* phase 5 */
    z13 = vsubq_s16(tmp7, z3);
    
    row5 = vaddq_s16(z13, z2);                  /* phase 6 */
    row3 = vsubq_s16(z13, z2);
    row1 = vaddq_s16(z11, z4);
    row7 = vsubq_s16(z11, z4);
    
    vst1q_s16(data + 0 * DCTSIZE, row0);
    vst1q_s16(data + 1 * DCTSIZE, row1);
    vst1q_s16(data + 2 * DCTSIZE, row2);
    vst1q_s16(data + 3 * DCTSIZE, row3);
    vst1q_s16(data + 4 * DCTSIZE, row4);
    vst1q_s16(data + 5 * DCTSIZE, row5);
    vst1q_s16(data + 6 * DCTSIZE, row6);
    vst1q_s16(data + 7 * DCTSIZE, row7);
}

struct DctAuxiliaryData {
};

struct DctAuxiliaryData *createDctAuxiliaryData() {
    struct DctAuxiliaryData *result = malloc(sizeof(struct DctAuxiliaryData));
    return result;
}

void freeDctAuxiliaryData(struct DctAuxiliaryData *data) {
    if (data) {
        free(data);
    }
}

void dct_jpeg_idct_ifast(struct DctAuxiliaryData *auxiliaryData, void *dct_table, JCOEFPTR coef_block, JSAMPROW output_buf)
{
    IFAST_MULT_TYPE *quantptr = dct_table;
    
    /* Load DCT coefficients. */
    int16x8_t row0 = vld1q_s16(coef_block + 0 * DCTSIZE);
    int16x8_t row1 = vld1q_s16(coef_block + 1 * DCTSIZE);
    int16x8_t row2 = vld1q_s16(coef_block + 2 * DCTSIZE);
    int16x8_t row3 = vld1q_s16(coef_block + 3 * DCTSIZE);
    int16x8_t row4 = vld1q_s16(coef_block + 4 * DCTSIZE);
    int16x8_t row5 = vld1q_s16(coef_block + 5 * DCTSIZE);
    int16x8_t row6 = vld1q_s16(coef_block + 6 * DCTSIZE);
    int16x8_t row7 = vld1q_s16(coef_block + 7 * DCTSIZE);
    
    /* Load quantization table values for DC coefficients. */
    int16x8_t quant_row0 = vld1q_s16(quantptr + 0 * DCTSIZE);
    /* Dequantize DC coefficients. */
    row0 = vmulq_s16(row0, quant_row0);
    
    /* Construct bitmap to test if all AC coefficients are 0. */
    int16x8_t bitmap = vorrq_s16(row1, row2);
    bitmap = vorrq_s16(bitmap, row3);
    bitmap = vorrq_s16(bitmap, row4);
    bitmap = vorrq_s16(bitmap, row5);
    bitmap = vorrq_s16(bitmap, row6);
    bitmap = vorrq_s16(bitmap, row7);
    
    int64_t left_ac_bitmap = vgetq_lane_s64(vreinterpretq_s64_s16(bitmap), 0);
    int64_t right_ac_bitmap = vgetq_lane_s64(vreinterpretq_s64_s16(bitmap), 1);
    
    /* Load IDCT conversion constants. */
    const int16x4_t consts = vld1_s16(jsimd_idct_ifast_neon_consts);
    
    if (left_ac_bitmap == 0 && right_ac_bitmap == 0) {
        /* All AC coefficients are zero.
         * Compute DC values and duplicate into vectors.
         */
        int16x8_t dcval = row0;
        row1 = dcval;
        row2 = dcval;
        row3 = dcval;
        row4 = dcval;
        row5 = dcval;
        row6 = dcval;
        row7 = dcval;
    } else if (left_ac_bitmap == 0) {
        /* AC coefficients are zero for columns 0, 1, 2, and 3.
         * Use DC values for these columns.
         */
        int16x4_t dcval = vget_low_s16(row0);
        
        /* Commence regular fast IDCT computation for columns 4, 5, 6, and 7. */
        
        /* Load quantization table. */
        int16x4_t quant_row1 = vld1_s16(quantptr + 1 * DCTSIZE + 4);
        int16x4_t quant_row2 = vld1_s16(quantptr + 2 * DCTSIZE + 4);
        int16x4_t quant_row3 = vld1_s16(quantptr + 3 * DCTSIZE + 4);
        int16x4_t quant_row4 = vld1_s16(quantptr + 4 * DCTSIZE + 4);
        int16x4_t quant_row5 = vld1_s16(quantptr + 5 * DCTSIZE + 4);
        int16x4_t quant_row6 = vld1_s16(quantptr + 6 * DCTSIZE + 4);
        int16x4_t quant_row7 = vld1_s16(quantptr + 7 * DCTSIZE + 4);
        
        /* Even part: dequantize DCT coefficients. */
        int16x4_t tmp0 = vget_high_s16(row0);
        int16x4_t tmp1 = vmul_s16(vget_high_s16(row2), quant_row2);
        int16x4_t tmp2 = vmul_s16(vget_high_s16(row4), quant_row4);
        int16x4_t tmp3 = vmul_s16(vget_high_s16(row6), quant_row6);
        
        int16x4_t tmp10 = vadd_s16(tmp0, tmp2);   /* phase 3 */
        int16x4_t tmp11 = vsub_s16(tmp0, tmp2);
        
        int16x4_t tmp13 = vadd_s16(tmp1, tmp3);   /* phases 5-3 */
        int16x4_t tmp1_sub_tmp3 = vsub_s16(tmp1, tmp3);
        int16x4_t tmp12 = vqdmulh_lane_s16(tmp1_sub_tmp3, consts, 1);
        tmp12 = vadd_s16(tmp12, tmp1_sub_tmp3);
        tmp12 = vsub_s16(tmp12, tmp13);
        
        tmp0 = vadd_s16(tmp10, tmp13);            /* phase 2 */
        tmp3 = vsub_s16(tmp10, tmp13);
        tmp1 = vadd_s16(tmp11, tmp12);
        tmp2 = vsub_s16(tmp11, tmp12);
        
        /* Odd part: dequantize DCT coefficients. */
        int16x4_t tmp4 = vmul_s16(vget_high_s16(row1), quant_row1);
        int16x4_t tmp5 = vmul_s16(vget_high_s16(row3), quant_row3);
        int16x4_t tmp6 = vmul_s16(vget_high_s16(row5), quant_row5);
        int16x4_t tmp7 = vmul_s16(vget_high_s16(row7), quant_row7);
        
        int16x4_t z13 = vadd_s16(tmp6, tmp5);     /* phase 6 */
        int16x4_t neg_z10 = vsub_s16(tmp5, tmp6);
        int16x4_t z11 = vadd_s16(tmp4, tmp7);
        int16x4_t z12 = vsub_s16(tmp4, tmp7);
        
        tmp7 = vadd_s16(z11, z13);                /* phase 5 */
        int16x4_t z11_sub_z13 = vsub_s16(z11, z13);
        tmp11 = vqdmulh_lane_s16(z11_sub_z13, consts, 1);
        tmp11 = vadd_s16(tmp11, z11_sub_z13);
        
        int16x4_t z10_add_z12 = vsub_s16(z12, neg_z10);
        int16x4_t z5 = vqdmulh_lane_s16(z10_add_z12, consts, 2);
        z5 = vadd_s16(z5, z10_add_z12);
        tmp10 = vqdmulh_lane_s16(z12, consts, 0);
        tmp10 = vadd_s16(tmp10, z12);
        tmp10 = vsub_s16(tmp10, z5);
        tmp12 = vqdmulh_lane_s16(neg_z10, consts, 3);
        tmp12 = vadd_s16(tmp12, vadd_s16(neg_z10, neg_z10));
        tmp12 = vadd_s16(tmp12, z5);
        
        tmp6 = vsub_s16(tmp12, tmp7);             /* phase 2 */
        tmp5 = vsub_s16(tmp11, tmp6);
        tmp4 = vadd_s16(tmp10, tmp5);
        
        row0 = vcombine_s16(dcval, vadd_s16(tmp0, tmp7));
        row7 = vcombine_s16(dcval, vsub_s16(tmp0, tmp7));
        row1 = vcombine_s16(dcval, vadd_s16(tmp1, tmp6));
        row6 = vcombine_s16(dcval, vsub_s16(tmp1, tmp6));
        row2 = vcombine_s16(dcval, vadd_s16(tmp2, tmp5));
        row5 = vcombine_s16(dcval, vsub_s16(tmp2, tmp5));
        row4 = vcombine_s16(dcval, vadd_s16(tmp3, tmp4));
        row3 = vcombine_s16(dcval, vsub_s16(tmp3, tmp4));
    } else if (right_ac_bitmap == 0) {
        /* AC coefficients are zero for columns 4, 5, 6, and 7.
         * Use DC values for these columns.
         */
        int16x4_t dcval = vget_high_s16(row0);
        
        /* Commence regular fast IDCT computation for columns 0, 1, 2, and 3. */
        
        /* Load quantization table. */
        int16x4_t quant_row1 = vld1_s16(quantptr + 1 * DCTSIZE);
        int16x4_t quant_row2 = vld1_s16(quantptr + 2 * DCTSIZE);
        int16x4_t quant_row3 = vld1_s16(quantptr + 3 * DCTSIZE);
        int16x4_t quant_row4 = vld1_s16(quantptr + 4 * DCTSIZE);
        int16x4_t quant_row5 = vld1_s16(quantptr + 5 * DCTSIZE);
        int16x4_t quant_row6 = vld1_s16(quantptr + 6 * DCTSIZE);
        int16x4_t quant_row7 = vld1_s16(quantptr + 7 * DCTSIZE);
        
        /* Even part: dequantize DCT coefficients. */
        int16x4_t tmp0 = vget_low_s16(row0);
        int16x4_t tmp1 = vmul_s16(vget_low_s16(row2), quant_row2);
        int16x4_t tmp2 = vmul_s16(vget_low_s16(row4), quant_row4);
        int16x4_t tmp3 = vmul_s16(vget_low_s16(row6), quant_row6);
        
        int16x4_t tmp10 = vadd_s16(tmp0, tmp2);   /* phase 3 */
        int16x4_t tmp11 = vsub_s16(tmp0, tmp2);
        
        int16x4_t tmp13 = vadd_s16(tmp1, tmp3);   /* phases 5-3 */
        int16x4_t tmp1_sub_tmp3 = vsub_s16(tmp1, tmp3);
        int16x4_t tmp12 = vqdmulh_lane_s16(tmp1_sub_tmp3, consts, 1);
        tmp12 = vadd_s16(tmp12, tmp1_sub_tmp3);
        tmp12 = vsub_s16(tmp12, tmp13);
        
        tmp0 = vadd_s16(tmp10, tmp13);            /* phase 2 */
        tmp3 = vsub_s16(tmp10, tmp13);
        tmp1 = vadd_s16(tmp11, tmp12);
        tmp2 = vsub_s16(tmp11, tmp12);
        
        /* Odd part: dequantize DCT coefficients. */
        int16x4_t tmp4 = vmul_s16(vget_low_s16(row1), quant_row1);
        int16x4_t tmp5 = vmul_s16(vget_low_s16(row3), quant_row3);
        int16x4_t tmp6 = vmul_s16(vget_low_s16(row5), quant_row5);
        int16x4_t tmp7 = vmul_s16(vget_low_s16(row7), quant_row7);
        
        int16x4_t z13 = vadd_s16(tmp6, tmp5);     /* phase 6 */
        int16x4_t neg_z10 = vsub_s16(tmp5, tmp6);
        int16x4_t z11 = vadd_s16(tmp4, tmp7);
        int16x4_t z12 = vsub_s16(tmp4, tmp7);
        
        tmp7 = vadd_s16(z11, z13);                /* phase 5 */
        int16x4_t z11_sub_z13 = vsub_s16(z11, z13);
        tmp11 = vqdmulh_lane_s16(z11_sub_z13, consts, 1);
        tmp11 = vadd_s16(tmp11, z11_sub_z13);
        
        int16x4_t z10_add_z12 = vsub_s16(z12, neg_z10);
        int16x4_t z5 = vqdmulh_lane_s16(z10_add_z12, consts, 2);
        z5 = vadd_s16(z5, z10_add_z12);
        tmp10 = vqdmulh_lane_s16(z12, consts, 0);
        tmp10 = vadd_s16(tmp10, z12);
        tmp10 = vsub_s16(tmp10, z5);
        tmp12 = vqdmulh_lane_s16(neg_z10, consts, 3);
        tmp12 = vadd_s16(tmp12, vadd_s16(neg_z10, neg_z10));
        tmp12 = vadd_s16(tmp12, z5);
        
        tmp6 = vsub_s16(tmp12, tmp7);             /* phase 2 */
        tmp5 = vsub_s16(tmp11, tmp6);
        tmp4 = vadd_s16(tmp10, tmp5);
        
        row0 = vcombine_s16(vadd_s16(tmp0, tmp7), dcval);
        row7 = vcombine_s16(vsub_s16(tmp0, tmp7), dcval);
        row1 = vcombine_s16(vadd_s16(tmp1, tmp6), dcval);
        row6 = vcombine_s16(vsub_s16(tmp1, tmp6), dcval);
        row2 = vcombine_s16(vadd_s16(tmp2, tmp5), dcval);
        row5 = vcombine_s16(vsub_s16(tmp2, tmp5), dcval);
        row4 = vcombine_s16(vadd_s16(tmp3, tmp4), dcval);
        row3 = vcombine_s16(vsub_s16(tmp3, tmp4), dcval);
    } else {
        /* Some AC coefficients are non-zero; full IDCT calculation required. */
        
        /* Load quantization table. */
        int16x8_t quant_row1 = vld1q_s16(quantptr + 1 * DCTSIZE);
        int16x8_t quant_row2 = vld1q_s16(quantptr + 2 * DCTSIZE);
        int16x8_t quant_row3 = vld1q_s16(quantptr + 3 * DCTSIZE);
        int16x8_t quant_row4 = vld1q_s16(quantptr + 4 * DCTSIZE);
        int16x8_t quant_row5 = vld1q_s16(quantptr + 5 * DCTSIZE);
        int16x8_t quant_row6 = vld1q_s16(quantptr + 6 * DCTSIZE);
        int16x8_t quant_row7 = vld1q_s16(quantptr + 7 * DCTSIZE);
        
        /* Even part: dequantize DCT coefficients. */
        int16x8_t tmp0 = row0;
        int16x8_t tmp1 = vmulq_s16(row2, quant_row2);
        int16x8_t tmp2 = vmulq_s16(row4, quant_row4);
        int16x8_t tmp3 = vmulq_s16(row6, quant_row6);
        
        int16x8_t tmp10 = vaddq_s16(tmp0, tmp2);   /* phase 3 */
        int16x8_t tmp11 = vsubq_s16(tmp0, tmp2);
        
        int16x8_t tmp13 = vaddq_s16(tmp1, tmp3);   /* phases 5-3 */
        int16x8_t tmp1_sub_tmp3 = vsubq_s16(tmp1, tmp3);
        int16x8_t tmp12 = vqdmulhq_lane_s16(tmp1_sub_tmp3, consts, 1);
        tmp12 = vaddq_s16(tmp12, tmp1_sub_tmp3);
        tmp12 = vsubq_s16(tmp12, tmp13);
        
        tmp0 = vaddq_s16(tmp10, tmp13);            /* phase 2 */
        tmp3 = vsubq_s16(tmp10, tmp13);
        tmp1 = vaddq_s16(tmp11, tmp12);
        tmp2 = vsubq_s16(tmp11, tmp12);
        
        /* Odd part: dequantize DCT coefficients. */
        int16x8_t tmp4 = vmulq_s16(row1, quant_row1);
        int16x8_t tmp5 = vmulq_s16(row3, quant_row3);
        int16x8_t tmp6 = vmulq_s16(row5, quant_row5);
        int16x8_t tmp7 = vmulq_s16(row7, quant_row7);
        
        int16x8_t z13 = vaddq_s16(tmp6, tmp5);     /* phase 6 */
        int16x8_t neg_z10 = vsubq_s16(tmp5, tmp6);
        int16x8_t z11 = vaddq_s16(tmp4, tmp7);
        int16x8_t z12 = vsubq_s16(tmp4, tmp7);
        
        tmp7 = vaddq_s16(z11, z13);                /* phase 5 */
        int16x8_t z11_sub_z13 = vsubq_s16(z11, z13);
        tmp11 = vqdmulhq_lane_s16(z11_sub_z13, consts, 1);
        tmp11 = vaddq_s16(tmp11, z11_sub_z13);
        
        int16x8_t z10_add_z12 = vsubq_s16(z12, neg_z10);
        int16x8_t z5 = vqdmulhq_lane_s16(z10_add_z12, consts, 2);
        z5 = vaddq_s16(z5, z10_add_z12);
        tmp10 = vqdmulhq_lane_s16(z12, consts, 0);
        tmp10 = vaddq_s16(tmp10, z12);
        tmp10 = vsubq_s16(tmp10, z5);
        tmp12 = vqdmulhq_lane_s16(neg_z10, consts, 3);
        tmp12 = vaddq_s16(tmp12, vaddq_s16(neg_z10, neg_z10));
        tmp12 = vaddq_s16(tmp12, z5);
        
        tmp6 = vsubq_s16(tmp12, tmp7);             /* phase 2 */
        tmp5 = vsubq_s16(tmp11, tmp6);
        tmp4 = vaddq_s16(tmp10, tmp5);
        
        row0 = vaddq_s16(tmp0, tmp7);
        row7 = vsubq_s16(tmp0, tmp7);
        row1 = vaddq_s16(tmp1, tmp6);
        row6 = vsubq_s16(tmp1, tmp6);
        row2 = vaddq_s16(tmp2, tmp5);
        row5 = vsubq_s16(tmp2, tmp5);
        row4 = vaddq_s16(tmp3, tmp4);
        row3 = vsubq_s16(tmp3, tmp4);
    }
    
    /* Transpose rows to work on columns in pass 2. */
    int16x8x2_t rows_01 = vtrnq_s16(row0, row1);
    int16x8x2_t rows_23 = vtrnq_s16(row2, row3);
    int16x8x2_t rows_45 = vtrnq_s16(row4, row5);
    int16x8x2_t rows_67 = vtrnq_s16(row6, row7);
    
    int32x4x2_t rows_0145_l = vtrnq_s32(vreinterpretq_s32_s16(rows_01.val[0]),
                                        vreinterpretq_s32_s16(rows_45.val[0]));
    int32x4x2_t rows_0145_h = vtrnq_s32(vreinterpretq_s32_s16(rows_01.val[1]),
                                        vreinterpretq_s32_s16(rows_45.val[1]));
    int32x4x2_t rows_2367_l = vtrnq_s32(vreinterpretq_s32_s16(rows_23.val[0]),
                                        vreinterpretq_s32_s16(rows_67.val[0]));
    int32x4x2_t rows_2367_h = vtrnq_s32(vreinterpretq_s32_s16(rows_23.val[1]),
                                        vreinterpretq_s32_s16(rows_67.val[1]));
    
    int32x4x2_t cols_04 = vzipq_s32(rows_0145_l.val[0], rows_2367_l.val[0]);
    int32x4x2_t cols_15 = vzipq_s32(rows_0145_h.val[0], rows_2367_h.val[0]);
    int32x4x2_t cols_26 = vzipq_s32(rows_0145_l.val[1], rows_2367_l.val[1]);
    int32x4x2_t cols_37 = vzipq_s32(rows_0145_h.val[1], rows_2367_h.val[1]);
    
    int16x8_t col0 = vreinterpretq_s16_s32(cols_04.val[0]);
    int16x8_t col1 = vreinterpretq_s16_s32(cols_15.val[0]);
    int16x8_t col2 = vreinterpretq_s16_s32(cols_26.val[0]);
    int16x8_t col3 = vreinterpretq_s16_s32(cols_37.val[0]);
    int16x8_t col4 = vreinterpretq_s16_s32(cols_04.val[1]);
    int16x8_t col5 = vreinterpretq_s16_s32(cols_15.val[1]);
    int16x8_t col6 = vreinterpretq_s16_s32(cols_26.val[1]);
    int16x8_t col7 = vreinterpretq_s16_s32(cols_37.val[1]);
    
    /* 1-D IDCT, pass 2 */
    
    /* Even part */
    int16x8_t tmp10 = vaddq_s16(col0, col4);
    int16x8_t tmp11 = vsubq_s16(col0, col4);
    
    int16x8_t tmp13 = vaddq_s16(col2, col6);
    int16x8_t col2_sub_col6 = vsubq_s16(col2, col6);
    int16x8_t tmp12 = vqdmulhq_lane_s16(col2_sub_col6, consts, 1);
    tmp12 = vaddq_s16(tmp12, col2_sub_col6);
    tmp12 = vsubq_s16(tmp12, tmp13);
    
    int16x8_t tmp0 = vaddq_s16(tmp10, tmp13);
    int16x8_t tmp3 = vsubq_s16(tmp10, tmp13);
    int16x8_t tmp1 = vaddq_s16(tmp11, tmp12);
    int16x8_t tmp2 = vsubq_s16(tmp11, tmp12);
    
    /* Odd part */
    int16x8_t z13 = vaddq_s16(col5, col3);
    int16x8_t neg_z10 = vsubq_s16(col3, col5);
    int16x8_t z11 = vaddq_s16(col1, col7);
    int16x8_t z12 = vsubq_s16(col1, col7);
    
    int16x8_t tmp7 = vaddq_s16(z11, z13);      /* phase 5 */
    int16x8_t z11_sub_z13 = vsubq_s16(z11, z13);
    tmp11 = vqdmulhq_lane_s16(z11_sub_z13, consts, 1);
    tmp11 = vaddq_s16(tmp11, z11_sub_z13);
    
    int16x8_t z10_add_z12 = vsubq_s16(z12, neg_z10);
    int16x8_t z5 = vqdmulhq_lane_s16(z10_add_z12, consts, 2);
    z5 = vaddq_s16(z5, z10_add_z12);
    tmp10 = vqdmulhq_lane_s16(z12, consts, 0);
    tmp10 = vaddq_s16(tmp10, z12);
    tmp10 = vsubq_s16(tmp10, z5);
    tmp12 = vqdmulhq_lane_s16(neg_z10, consts, 3);
    tmp12 = vaddq_s16(tmp12, vaddq_s16(neg_z10, neg_z10));
    tmp12 = vaddq_s16(tmp12, z5);
    
    int16x8_t tmp6 = vsubq_s16(tmp12, tmp7);   /* phase 2 */
    int16x8_t tmp5 = vsubq_s16(tmp11, tmp6);
    int16x8_t tmp4 = vaddq_s16(tmp10, tmp5);
    
    col0 = vaddq_s16(tmp0, tmp7);
    col7 = vsubq_s16(tmp0, tmp7);
    col1 = vaddq_s16(tmp1, tmp6);
    col6 = vsubq_s16(tmp1, tmp6);
    col2 = vaddq_s16(tmp2, tmp5);
    col5 = vsubq_s16(tmp2, tmp5);
    col4 = vaddq_s16(tmp3, tmp4);
    col3 = vsubq_s16(tmp3, tmp4);
    
    /* Scale down by a factor of 8, narrowing to 8-bit. */
    int8x16_t cols_01_s8 = vcombine_s8(vqshrn_n_s16(col0, PASS1_BITS + 3),
                                       vqshrn_n_s16(col1, PASS1_BITS + 3));
    int8x16_t cols_45_s8 = vcombine_s8(vqshrn_n_s16(col4, PASS1_BITS + 3),
                                       vqshrn_n_s16(col5, PASS1_BITS + 3));
    int8x16_t cols_23_s8 = vcombine_s8(vqshrn_n_s16(col2, PASS1_BITS + 3),
                                       vqshrn_n_s16(col3, PASS1_BITS + 3));
    int8x16_t cols_67_s8 = vcombine_s8(vqshrn_n_s16(col6, PASS1_BITS + 3),
                                       vqshrn_n_s16(col7, PASS1_BITS + 3));
    /* Clamp to range [0-255]. */
    uint8x16_t cols_01 =
    vreinterpretq_u8_s8
    (vaddq_s8(cols_01_s8, vreinterpretq_s8_u8(vdupq_n_u8(CENTERJSAMPLE))));
    uint8x16_t cols_45 =
    vreinterpretq_u8_s8
    (vaddq_s8(cols_45_s8, vreinterpretq_s8_u8(vdupq_n_u8(CENTERJSAMPLE))));
    uint8x16_t cols_23 =
    vreinterpretq_u8_s8
    (vaddq_s8(cols_23_s8, vreinterpretq_s8_u8(vdupq_n_u8(CENTERJSAMPLE))));
    uint8x16_t cols_67 =
    vreinterpretq_u8_s8
    (vaddq_s8(cols_67_s8, vreinterpretq_s8_u8(vdupq_n_u8(CENTERJSAMPLE))));
    
    /* Transpose block to prepare for store. */
    uint32x4x2_t cols_0415 = vzipq_u32(vreinterpretq_u32_u8(cols_01),
                                       vreinterpretq_u32_u8(cols_45));
    uint32x4x2_t cols_2637 = vzipq_u32(vreinterpretq_u32_u8(cols_23),
                                       vreinterpretq_u32_u8(cols_67));
    
    uint8x16x2_t cols_0145 = vtrnq_u8(vreinterpretq_u8_u32(cols_0415.val[0]),
                                      vreinterpretq_u8_u32(cols_0415.val[1]));
    uint8x16x2_t cols_2367 = vtrnq_u8(vreinterpretq_u8_u32(cols_2637.val[0]),
                                      vreinterpretq_u8_u32(cols_2637.val[1]));
    uint16x8x2_t rows_0426 = vtrnq_u16(vreinterpretq_u16_u8(cols_0145.val[0]),
                                       vreinterpretq_u16_u8(cols_2367.val[0]));
    uint16x8x2_t rows_1537 = vtrnq_u16(vreinterpretq_u16_u8(cols_0145.val[1]),
                                       vreinterpretq_u16_u8(cols_2367.val[1]));
    
    uint8x16_t rows_04 = vreinterpretq_u8_u16(rows_0426.val[0]);
    uint8x16_t rows_15 = vreinterpretq_u8_u16(rows_1537.val[0]);
    uint8x16_t rows_26 = vreinterpretq_u8_u16(rows_0426.val[1]);
    uint8x16_t rows_37 = vreinterpretq_u8_u16(rows_1537.val[1]);
    
    JSAMPROW outptr0 = output_buf + DCTSIZE * 0;
    JSAMPROW outptr1 = output_buf + DCTSIZE * 1;
    JSAMPROW outptr2 = output_buf + DCTSIZE * 2;
    JSAMPROW outptr3 = output_buf + DCTSIZE * 3;
    JSAMPROW outptr4 = output_buf + DCTSIZE * 4;
    JSAMPROW outptr5 = output_buf + DCTSIZE * 5;
    JSAMPROW outptr6 = output_buf + DCTSIZE * 6;
    JSAMPROW outptr7 = output_buf + DCTSIZE * 7;
    
    /* Store DCT block to memory. */
    vst1q_lane_u64((uint64_t *)outptr0, vreinterpretq_u64_u8(rows_04), 0);
    vst1q_lane_u64((uint64_t *)outptr1, vreinterpretq_u64_u8(rows_15), 0);
    vst1q_lane_u64((uint64_t *)outptr2, vreinterpretq_u64_u8(rows_26), 0);
    vst1q_lane_u64((uint64_t *)outptr3, vreinterpretq_u64_u8(rows_37), 0);
    vst1q_lane_u64((uint64_t *)outptr4, vreinterpretq_u64_u8(rows_04), 1);
    vst1q_lane_u64((uint64_t *)outptr5, vreinterpretq_u64_u8(rows_15), 1);
    vst1q_lane_u64((uint64_t *)outptr6, vreinterpretq_u64_u8(rows_26), 1);
    vst1q_lane_u64((uint64_t *)outptr7, vreinterpretq_u64_u8(rows_37), 1);
}

#endif
