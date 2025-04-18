#import "DCT.h"

#include "DCTCommon.h"

#include <vector>
#include <Accelerate/Accelerate.h>

#define DCTSIZE             8   /* The basic DCT block is 8x8 samples */
#define DCTSIZE2            64  /* DCTSIZE squared; # of elements in a block */

typedef unsigned short UDCTELEM;
typedef unsigned int UDCTELEM2;

typedef long JLONG;

#define MULTIPLIER  short       /* prefer 16-bit with SIMD for parellelism */
typedef MULTIPLIER IFAST_MULT_TYPE;  /* 16 bits is OK, use short if faster */

#define IFAST_SCALE_BITS  2          /* fractional bits in scale factors */

#define CENTERJSAMPLE   128

namespace {

int flss(uint16_t val) {
    int bit;
    
    bit = 16;
    
    if (!val)
        return 0;
    
    if (!(val & 0xff00)) {
        bit -= 8;
        val <<= 8;
    }
    if (!(val & 0xf000)) {
        bit -= 4;
        val <<= 4;
    }
    if (!(val & 0xc000)) {
        bit -= 2;
        val <<= 2;
    }
    if (!(val & 0x8000)) {
        bit -= 1;
        val <<= 1;
    }
    
    return bit;
}

int compute_reciprocal(uint16_t divisor, DCTELEM *dtbl) {
    UDCTELEM2 fq, fr;
    UDCTELEM c;
    int b, r;
    
    if (divisor == 1) {
        /* divisor == 1 means unquantized, so these reciprocal/correction/shift
         * values will cause the C quantization algorithm to act like the
         * identity function.  Since only the C quantization algorithm is used in
         * these cases, the scale value is irrelevant.
         */
        dtbl[DCTSIZE2 * 0] = (DCTELEM)1;                        /* reciprocal */
        dtbl[DCTSIZE2 * 1] = (DCTELEM)0;                        /* correction */
        dtbl[DCTSIZE2 * 2] = (DCTELEM)1;                        /* scale */
        dtbl[DCTSIZE2 * 3] = -(DCTELEM)(sizeof(DCTELEM) * 8);   /* shift */
        return 0;
    }
    
    b = flss(divisor) - 1;
    r  = sizeof(DCTELEM) * 8 + b;
    
    fq = ((UDCTELEM2)1 << r) / divisor;
    fr = ((UDCTELEM2)1 << r) % divisor;
    
    c = divisor / 2;                      /* for rounding */
    
    if (fr == 0) {                        /* divisor is power of two */
        /* fq will be one bit too large to fit in DCTELEM, so adjust */
        fq >>= 1;
        r--;
    } else if (fr <= (divisor / 2U)) {    /* fractional part is < 0.5 */
        c++;
    } else {                              /* fractional part is > 0.5 */
        fq++;
    }
    
    dtbl[DCTSIZE2 * 0] = (DCTELEM)fq;     /* reciprocal */
    dtbl[DCTSIZE2 * 1] = (DCTELEM)c;      /* correction + roundfactor */
#ifdef WITH_SIMD
    dtbl[DCTSIZE2 * 2] = (DCTELEM)(1 << (sizeof(DCTELEM) * 8 * 2 - r)); /* scale */
#else
    dtbl[DCTSIZE2 * 2] = 1;
#endif
    dtbl[DCTSIZE2 * 3] = (DCTELEM)r - sizeof(DCTELEM) * 8; /* shift */
    
    if (r <= 16) return 0;
    else return 1;
}

#define DESCALE(x, n)  RIGHT_SHIFT(x, n)


/* Multiply a DCTELEM variable by an JLONG constant, and immediately
 * descale to yield a DCTELEM result.
 */

#define MULTIPLY(var, const)  ((DCTELEM)DESCALE((var) * (const), CONST_BITS))
#define MULTIPLY16V16(var1, var2)  ((var1) * (var2))

static DCTELEM std_luminance_quant_tbl[DCTSIZE2] = {
    16,  11,  10,  16,  24,  40,  51,  61,
    12,  12,  14,  19,  26,  58,  60,  55,
    14,  13,  16,  24,  40,  57,  69,  56,
    14,  17,  22,  29,  51,  87,  80,  62,
    18,  22,  37,  56,  68, 109, 103,  77,
    24,  35,  55,  64,  81, 104, 113,  92,
    49,  64,  78,  87, 103, 121, 120, 101,
    72,  92,  95,  98, 112, 100, 103,  99
};
static DCTELEM std_chrominance_quant_tbl[DCTSIZE2] = {
  17,  18,  24,  47,  99,  99,  99,  99,
  18,  21,  26,  66,  99,  99,  99,  99,
  24,  26,  56,  99,  99,  99,  99,  99,
  47,  66,  99,  99,  99,  99,  99,  99,
  99,  99,  99,  99,  99,  99,  99,  99,
  99,  99,  99,  99,  99,  99,  99,  99,
  99,  99,  99,  99,  99,  99,  99,  99,
  99,  99,  99,  99,  99,  99,  99,  99
};
static DCTELEM std_delta_quant_tbl[DCTSIZE2] = {
  16,  16,  16,  16,  16,  16,  16,  16,
  16,  16,  16,  16,  16,  16,  16,  16,
  16,  16,  16,  16,  16,  16,  16,  16,
  16,  16,  16,  16,  16,  16,  16,  16,
  16,  16,  16,  16,  16,  16,  16,  16,
  16,  16,  16,  16,  16,  16,  16,  16,
  16,  16,  16,  16,  16,  16,  16,  16,
  16,  16,  16,  16,  16,  16,  16,  16
};

int jpeg_quality_scaling(int quality)
/* Convert a user-specified quality rating to a percentage scaling factor
 * for an underlying quantization table, using our recommended scaling curve.
 * The input 'quality' factor should be 0 (terrible) to 100 (very good).
 */
{
    /* Safety limit on quality factor.  Convert 0 to 1 to avoid zero divide. */
    if (quality <= 0) quality = 1;
    if (quality > 100) quality = 100;
    
    /* The basic table is used as-is (scaling 100) for a quality of 50.
     * Qualities 50..100 are converted to scaling percentage 200 - 2*Q;
     * note that at Q=100 the scaling is 0, which will cause jpeg_add_quant_table
     * to make all the table entries 1 (hence, minimum quantization loss).
     * Qualities 1..50 are converted to scaling percentage 5000/Q.
     */
    if (quality < 50)
        quality = 5000 / quality;
    else
        quality = 200 - quality * 2;
    
    return quality;
}

void jpeg_add_quant_table(DCTELEM *qtable, DCTELEM const *basicTable, int scale_factor, bool forceBaseline)
/* Define a quantization table equal to the basic_table times
 * a scale factor (given as a percentage).
 * If force_baseline is TRUE, the computed quantization table entries
 * are limited to 1..255 for JPEG baseline compatibility.
 */
{
    int i;
    long temp;
    
    for (i = 0; i < DCTSIZE2; i++) {
        temp = ((long)basicTable[i] * scale_factor + 50L) / 100L;
        /* limit the values to the valid range */
        if (temp <= 0L) temp = 1L;
        if (temp > 32767L) temp = 32767L; /* max quantizer needed for 12 bits */
        if (forceBaseline && temp > 255L)
            temp = 255L;              /* limit to baseline range if requested */
        qtable[i] = (uint16_t)temp;
    }
}

void jpeg_set_quality(DCTELEM *qtable, DCTELEM const *basicTable, int quality)
/* Set or change the 'quality' (quantization) setting, using default tables.
 * This is the standard quality-adjusting entry point for typical user
 * interfaces; only those who want detailed control over quantization tables
 * would use the preceding three routines directly.
 */
{
    /* Convert user 0-100 rating to percentage scaling */
    quality = jpeg_quality_scaling(quality);
    
    /* Set up standard quality tables */
    jpeg_add_quant_table(qtable, basicTable, quality, false);
}

void getDivisors(DCTELEM *dtbl, DCTELEM const *qtable) {
#define CONST_BITS  14
#define RIGHT_SHIFT(x, shft)    ((x) >> (shft))
    
    static const int16_t aanscales[DCTSIZE2] = {
        /* precomputed values scaled up by 14 bits */
        16384, 22725, 21407, 19266, 16384, 12873,  8867,  4520,
        22725, 31521, 29692, 26722, 22725, 17855, 12299,  6270,
        21407, 29692, 27969, 25172, 21407, 16819, 11585,  5906,
        19266, 26722, 25172, 22654, 19266, 15137, 10426,  5315,
        16384, 22725, 21407, 19266, 16384, 12873,  8867,  4520,
        12873, 17855, 16819, 15137, 12873, 10114,  6967,  3552,
        8867, 12299, 11585, 10426,  8867,  6967,  4799,  2446,
        4520,  6270,  5906,  5315,  4520,  3552,  2446,  1247
    };
    
    for (int i = 0; i < DCTSIZE2; i++) {
        if (!compute_reciprocal(
                                DESCALE(MULTIPLY16V16((JLONG)qtable[i],
                                                      (JLONG)aanscales[i]),
                                        CONST_BITS - 3), &dtbl[i])) {
                                        }
    }
}

void quantize(JCOEFPTR coef_block, DCTELEM *divisors, DCTELEM *workspace)
{
    int i;
    DCTELEM temp;
    JCOEFPTR output_ptr = coef_block;
    
    UDCTELEM recip, corr;
    int shift;
    UDCTELEM2 product;
    
    for (i = 0; i < DCTSIZE2; i++) {
        temp = workspace[i];
        recip = divisors[i + DCTSIZE2 * 0];
        corr =  divisors[i + DCTSIZE2 * 1];
        shift = divisors[i + DCTSIZE2 * 3];
        
        if (temp < 0) {
            temp = -temp;
            product = (UDCTELEM2)(temp + corr) * recip;
            product >>= shift + sizeof(DCTELEM) * 8;
            temp = (DCTELEM)product;
            temp = -temp;
        } else {
            product = (UDCTELEM2)(temp + corr) * recip;
            product >>= shift + sizeof(DCTELEM) * 8;
            temp = (DCTELEM)product;
        }
        output_ptr[i] = (JCOEF)temp;
    }
}

void generateForwardDctData(DCTELEM const *qtable, std::vector<uint8_t> &data) {
    data.resize(DCTSIZE2 * 4 * sizeof(DCTELEM));
    getDivisors((DCTELEM *)data.data(), qtable);
}

void generateInverseDctData(DCTELEM const *qtable, std::vector<uint8_t> &data) {
    data.resize(DCTSIZE2 * sizeof(IFAST_MULT_TYPE));
    IFAST_MULT_TYPE *ifmtbl = (IFAST_MULT_TYPE *)data.data();
    
#define CONST_BITS  14
    static const int16_t aanscales[DCTSIZE2] = {
        /* precomputed values scaled up by 14 bits */
        16384, 22725, 21407, 19266, 16384, 12873,  8867,  4520,
        22725, 31521, 29692, 26722, 22725, 17855, 12299,  6270,
        21407, 29692, 27969, 25172, 21407, 16819, 11585,  5906,
        19266, 26722, 25172, 22654, 19266, 15137, 10426,  5315,
        16384, 22725, 21407, 19266, 16384, 12873,  8867,  4520,
        12873, 17855, 16819, 15137, 12873, 10114,  6967,  3552,
        8867, 12299, 11585, 10426,  8867,  6967,  4799,  2446,
        4520,  6270,  5906,  5315,  4520,  3552,  2446,  1247
    };
    
    for (int i = 0; i < DCTSIZE2; i++) {
        ifmtbl[i] = (IFAST_MULT_TYPE)
        DESCALE(MULTIPLY16V16((JLONG)qtable[i],
                              (JLONG)aanscales[i]),
                CONST_BITS - IFAST_SCALE_BITS);
    }
}

static const int zigZagInv[DCTSIZE2] = {
    0,1,8,16,9,2,3,10,
    17,24,32,25,18,11,4,5,
    12,19,26,33,40,48,41,34,
    27,20,13,6,7,14,21,28,
    35,42,49,56,57,50,43,36,
    29,22,15,23,30,37,44,51,
    58,59,52,45,38,31,39,46,
    53,60,61,54,47,55,62,63
};

static const int zigZag4x4Inv[4 * 4] = {
    0, 1, 4, 8, 5, 2, 3, 6, 9, 12, 13, 10, 7, 11, 14, 15
};

void performForwardDct(uint8_t const *pixels, int16_t *coefficients, int width, int height, int bytesPerRow, DCTELEM *divisors) {
    DCTELEM block[DCTSIZE2];
    JCOEF coefBlock[DCTSIZE2];
    
    int acOffset = (width / DCTSIZE) * (height / DCTSIZE);
    
    for (int y = 0; y < height; y += DCTSIZE) {
        for (int x = 0; x < width; x += DCTSIZE) {
            for (int blockY = 0; blockY < DCTSIZE; blockY++) {
                for (int blockX = 0; blockX < DCTSIZE; blockX++) {
                    block[blockY * DCTSIZE + blockX] = ((DCTELEM)pixels[(y + blockY) * bytesPerRow + (x + blockX)]) - CENTERJSAMPLE;
                }
            }
            
            dct_jpeg_fdct_ifast(block);
            
            quantize(coefBlock, divisors, block);
            
            coefficients[(y / DCTSIZE) * (width / DCTSIZE) + x / DCTSIZE] = coefBlock[0];
            
            for (int blockY = 0; blockY < DCTSIZE; blockY++) {
                for (int blockX = 0; blockX < DCTSIZE; blockX++) {
                    if (blockX == 0 && blockY == 0) {
                        continue;
                    }
                    int16_t element = coefBlock[zigZagInv[blockY * DCTSIZE + blockX]];
                    //coefficients[(y + blockY) * bytesPerRow + (x + blockX)] = element;
                    coefficients[acOffset] = element;
                    acOffset++;
                }
            }
        }
    }
}

void performInverseDct(int16_t const * coefficients, uint8_t *pixels, int width, int height, int coefficientsPerRow, int bytesPerRow, DctAuxiliaryData *auxiliaryData, IFAST_MULT_TYPE *ifmtbl) {
    DCTELEM coefficientBlock[DCTSIZE2];
    JSAMPLE pixelBlock[DCTSIZE2];
    
    int acOffset = (width / DCTSIZE) * (height / DCTSIZE);
    
    for (int y = 0; y < height; y += DCTSIZE) {
        for (int x = 0; x < width; x += DCTSIZE) {
            coefficientBlock[0] = coefficients[(y / DCTSIZE) * (width / DCTSIZE) + x / DCTSIZE];
            
            for (int blockY = 0; blockY < DCTSIZE; blockY++) {
                for (int blockX = 0; blockX < DCTSIZE; blockX++) {
                    if (blockX == 0 && blockY == 0) {
                        continue;
                    }
                    int16_t element = coefficients[acOffset];
                    acOffset++;
                    coefficientBlock[zigZagInv[blockY * DCTSIZE + blockX]] = element;
                }
            }
            
            dct_jpeg_idct_ifast(auxiliaryData, ifmtbl, coefficientBlock, pixelBlock);
            
            for (int blockY = 0; blockY < DCTSIZE; blockY++) {
                for (int blockX = 0; blockX < DCTSIZE; blockX++) {
                    pixels[(y + blockY) * bytesPerRow + (x + blockX)] = pixelBlock[blockY * DCTSIZE + blockX];
                }
            }
        }
    }
}

typedef int16_t tran_low_t;
typedef int32_t tran_high_t;
typedef int16_t tran_coef_t;

static const tran_coef_t cospi_1_64 = 16364;
static const tran_coef_t cospi_2_64 = 16305;
static const tran_coef_t cospi_3_64 = 16207;
static const tran_coef_t cospi_4_64 = 16069;
static const tran_coef_t cospi_5_64 = 15893;
static const tran_coef_t cospi_6_64 = 15679;
static const tran_coef_t cospi_7_64 = 15426;
static const tran_coef_t cospi_8_64 = 15137;
static const tran_coef_t cospi_9_64 = 14811;
static const tran_coef_t cospi_10_64 = 14449;
static const tran_coef_t cospi_11_64 = 14053;
static const tran_coef_t cospi_12_64 = 13623;
static const tran_coef_t cospi_13_64 = 13160;
static const tran_coef_t cospi_14_64 = 12665;
static const tran_coef_t cospi_15_64 = 12140;
static const tran_coef_t cospi_16_64 = 11585;
static const tran_coef_t cospi_17_64 = 11003;
static const tran_coef_t cospi_18_64 = 10394;
static const tran_coef_t cospi_19_64 = 9760;
static const tran_coef_t cospi_20_64 = 9102;
static const tran_coef_t cospi_21_64 = 8423;
static const tran_coef_t cospi_22_64 = 7723;
static const tran_coef_t cospi_23_64 = 7005;
static const tran_coef_t cospi_24_64 = 6270;
static const tran_coef_t cospi_25_64 = 5520;
static const tran_coef_t cospi_26_64 = 4756;
static const tran_coef_t cospi_27_64 = 3981;
static const tran_coef_t cospi_28_64 = 3196;
static const tran_coef_t cospi_29_64 = 2404;
static const tran_coef_t cospi_30_64 = 1606;
static const tran_coef_t cospi_31_64 = 804;

//  16384 * sqrt(2) * sin(kPi/9) * 2 / 3
static const tran_coef_t sinpi_1_9 = 5283;
static const tran_coef_t sinpi_2_9 = 9929;
static const tran_coef_t sinpi_3_9 = 13377;
static const tran_coef_t sinpi_4_9 = 15212;

#define DCT_CONST_BITS 14
#define DCT_CONST_ROUNDING (1 << (DCT_CONST_BITS - 1))

#define ROUND_POWER_OF_TWO(value, n) (((value) + (1 << ((n)-1))) >> (n))

static inline tran_high_t fdct_round_shift(tran_high_t input) {
  tran_high_t rv = ROUND_POWER_OF_TWO(input, DCT_CONST_BITS);
  // TODO(debargha, peter.derivaz): Find new bounds for this assert
  // and make the bounds consts.
  // assert(INT16_MIN <= rv && rv <= INT16_MAX);
  return rv;
}

void vpx_fdct4x4_c(const int16_t *input, tran_low_t *output, int stride) {
  // The 2D transform is done with two passes which are actually pretty
  // similar. In the first one, we transform the columns and transpose
  // the results. In the second one, we transform the rows. To achieve that,
  // as the first pass results are transposed, we transpose the columns (that
  // is the transposed rows) and transpose the results (so that it goes back
  // in normal/row positions).
  int pass;
  // We need an intermediate buffer between passes.
  tran_low_t intermediate[4 * 4];
  const tran_low_t *in_low = NULL;
  tran_low_t *out = intermediate;
  // Do the two transform/transpose passes
  for (pass = 0; pass < 2; ++pass) {
    tran_high_t in_high[4];    // canbe16
    tran_high_t step[4];       // canbe16
    tran_high_t temp1, temp2;  // needs32
    int i;
    for (i = 0; i < 4; ++i) {
      // Load inputs.
      if (pass == 0) {
        in_high[0] = input[0 * stride] * 16;
        in_high[1] = input[1 * stride] * 16;
        in_high[2] = input[2 * stride] * 16;
        in_high[3] = input[3 * stride] * 16;
        if (i == 0 && in_high[0]) {
          ++in_high[0];
        }
      } else {
        assert(in_low != NULL);
        in_high[0] = in_low[0 * 4];
        in_high[1] = in_low[1 * 4];
        in_high[2] = in_low[2 * 4];
        in_high[3] = in_low[3 * 4];
        ++in_low;
      }
      // Transform.
      step[0] = in_high[0] + in_high[3];
      step[1] = in_high[1] + in_high[2];
      step[2] = in_high[1] - in_high[2];
      step[3] = in_high[0] - in_high[3];
      temp1 = (step[0] + step[1]) * cospi_16_64;
      temp2 = (step[0] - step[1]) * cospi_16_64;
      out[0] = (tran_low_t)fdct_round_shift(temp1);
      out[2] = (tran_low_t)fdct_round_shift(temp2);
      temp1 = step[2] * cospi_24_64 + step[3] * cospi_8_64;
      temp2 = -step[2] * cospi_8_64 + step[3] * cospi_24_64;
      out[1] = (tran_low_t)fdct_round_shift(temp1);
      out[3] = (tran_low_t)fdct_round_shift(temp2);
      // Do next column (which is a transposed row in second/horizontal pass)
      ++input;
      out += 4;
    }
    // Setup in/out for next pass.
    in_low = intermediate;
    out = output;
  }

  {
    int i, j;
    for (i = 0; i < 4; ++i) {
      for (j = 0; j < 4; ++j) output[j + i * 4] = (output[j + i * 4] + 1) >> 2;
    }
  }
}

#define ROUND_POWER_OF_TWO(value, n) (((value) + (1 << ((n)-1))) >> (n))

static inline tran_high_t dct_const_round_shift(tran_high_t input) {
  tran_high_t rv = ROUND_POWER_OF_TWO(input, DCT_CONST_BITS);
  return (tran_high_t)rv;
}

static inline tran_high_t check_range(tran_high_t input) {
#ifdef CONFIG_COEFFICIENT_RANGE_CHECKING
  // For valid VP9 input streams, intermediate stage coefficients should always
  // stay within the range of a signed 16 bit integer. Coefficients can go out
  // of this range for invalid/corrupt VP9 streams. However, strictly checking
  // this range for every intermediate coefficient can burdensome for a decoder,
  // therefore the following assertion is only enabled when configured with
  // --enable-coefficient-range-checking.
  assert(INT16_MIN <= input);
  assert(input <= INT16_MAX);
#endif  // CONFIG_COEFFICIENT_RANGE_CHECKING
  return input;
}

#define WRAPLOW(x) ((int32_t)check_range(x))

void idct4_c(const tran_low_t *input, tran_low_t *output) {
    int16_t step[4];
    tran_high_t temp1, temp2;
    
    // stage 1
    temp1 = ((int16_t)input[0] + (int16_t)input[2]) * cospi_16_64;
    temp2 = ((int16_t)input[0] - (int16_t)input[2]) * cospi_16_64;
    step[0] = WRAPLOW(dct_const_round_shift(temp1));
    step[1] = WRAPLOW(dct_const_round_shift(temp2));
    temp1 = (int16_t)input[1] * cospi_24_64 - (int16_t)input[3] * cospi_8_64;
    temp2 = (int16_t)input[1] * cospi_8_64 + (int16_t)input[3] * cospi_24_64;
    step[2] = WRAPLOW(dct_const_round_shift(temp1));
    step[3] = WRAPLOW(dct_const_round_shift(temp2));
    
    // stage 2
    output[0] = WRAPLOW(step[0] + step[3]);
    output[1] = WRAPLOW(step[1] + step[2]);
    output[2] = WRAPLOW(step[1] - step[2]);
    output[3] = WRAPLOW(step[0] - step[3]);
}

void vpx_idct4x4_16_add_c(const tran_low_t *input, tran_low_t *dest, int stride) {
    int i, j;
    tran_low_t out[4 * 4];
    tran_low_t *outptr = out;
    tran_low_t temp_in[4], temp_out[4];
    
    // Rows
    for (i = 0; i < 4; ++i) {
        idct4_c(input, outptr);
        input += 4;
        outptr += 4;
    }
    
    // Columns
    for (i = 0; i < 4; ++i) {
        for (j = 0; j < 4; ++j) temp_in[j] = out[j * 4 + i];
        idct4_c(temp_in, temp_out);
        for (j = 0; j < 4; ++j) {
            dest[j * stride + i] = ROUND_POWER_OF_TWO(temp_out[j], 4);
        }
    }
}

#if defined(__aarch64__)

static inline void transpose_s16_4x4q(int16x8_t *a0, int16x8_t *a1) {
  // Swap 32 bit elements. Goes from:
  // a0: 00 01 02 03  10 11 12 13
  // a1: 20 21 22 23  30 31 32 33
  // to:
  // b0.val[0]: 00 01 20 21  10 11 30 31
  // b0.val[1]: 02 03 22 23  12 13 32 33

  const int32x4x2_t b0 =
      vtrnq_s32(vreinterpretq_s32_s16(*a0), vreinterpretq_s32_s16(*a1));

  // Swap 64 bit elements resulting in:
  // c0: 00 01 20 21  02 03 22 23
  // c1: 10 11 30 31  12 13 32 33

  const int32x4_t c0 =
      vcombine_s32(vget_low_s32(b0.val[0]), vget_low_s32(b0.val[1]));
  const int32x4_t c1 =
      vcombine_s32(vget_high_s32(b0.val[0]), vget_high_s32(b0.val[1]));

  // Swap 16 bit elements resulting in:
  // d0.val[0]: 00 10 20 30  02 12 22 32
  // d0.val[1]: 01 11 21 31  03 13 23 33

  const int16x8x2_t d0 =
      vtrnq_s16(vreinterpretq_s16_s32(c0), vreinterpretq_s16_s32(c1));

  *a0 = d0.val[0];
  *a1 = d0.val[1];
}

static inline int16x8_t dct_const_round_shift_low_8(const int32x4_t *const in) {
  return vcombine_s16(vrshrn_n_s32(in[0], DCT_CONST_BITS),
                      vrshrn_n_s32(in[1], DCT_CONST_BITS));
}

static inline void dct_const_round_shift_low_8_dual(const int32x4_t *const t32,
                                                    int16x8_t *const d0,
                                                    int16x8_t *const d1) {
  *d0 = dct_const_round_shift_low_8(t32 + 0);
  *d1 = dct_const_round_shift_low_8(t32 + 2);
}

static const int16_t kCospi[16] = {
  16384 /*  cospi_0_64  */, 15137 /*  cospi_8_64  */,
  11585 /*  cospi_16_64 */, 6270 /*  cospi_24_64 */,
  16069 /*  cospi_4_64  */, 13623 /*  cospi_12_64 */,
  -9102 /* -cospi_20_64 */, 3196 /*  cospi_28_64 */,
  16305 /*  cospi_2_64  */, 1606 /*  cospi_30_64 */,
  14449 /*  cospi_10_64 */, 7723 /*  cospi_22_64 */,
  15679 /*  cospi_6_64  */, -4756 /* -cospi_26_64 */,
  12665 /*  cospi_14_64 */, -10394 /* -cospi_18_64 */
};

static inline void idct4x4_16_kernel_bd8(int16x8_t *const a) {
  const int16x4_t cospis = vld1_s16(kCospi);
  int16x4_t b[4];
  int32x4_t c[4];
  int16x8_t d[2];

  b[0] = vget_low_s16(a[0]);
  b[1] = vget_high_s16(a[0]);
  b[2] = vget_low_s16(a[1]);
  b[3] = vget_high_s16(a[1]);
  c[0] = vmull_lane_s16(b[0], cospis, 2);
  c[2] = vmull_lane_s16(b[1], cospis, 2);
  c[1] = vsubq_s32(c[0], c[2]);
  c[0] = vaddq_s32(c[0], c[2]);
  c[3] = vmull_lane_s16(b[2], cospis, 3);
  c[2] = vmull_lane_s16(b[2], cospis, 1);
  c[3] = vmlsl_lane_s16(c[3], b[3], cospis, 1);
  c[2] = vmlal_lane_s16(c[2], b[3], cospis, 3);
  dct_const_round_shift_low_8_dual(c, &d[0], &d[1]);
  a[0] = vaddq_s16(d[0], d[1]);
  a[1] = vsubq_s16(d[0], d[1]);
}

static inline void transpose_idct4x4_16_bd8(int16x8_t *const a) {
    transpose_s16_4x4q(&a[0], &a[1]);
    idct4x4_16_kernel_bd8(a);
}

inline void vpx_idct4x4_16_add_neon(const int16x8_t &top64, const int16x8_t &bottom64, const int16x4_t &current0, const int16x4_t &current1, const int16x4_t &current2, const int16x4_t &current3, int16_t multiplier, int16_t *dest, int destRowIncrement) {
    int16x8_t a[2];
    
    assert(!((intptr_t)dest % sizeof(uint32_t)));
    
    int16x8_t mul = vdupq_n_s16(multiplier);
    
    // Rows
    a[0] = vmulq_s16(top64, mul);
    a[1] = vmulq_s16(bottom64, mul);
    transpose_idct4x4_16_bd8(a);
    
    // Columns
    a[1] = vcombine_s16(vget_high_s16(a[1]), vget_low_s16(a[1]));
    transpose_idct4x4_16_bd8(a);
    a[0] = vrshrq_n_s16(a[0], 4);
    a[1] = vrshrq_n_s16(a[1], 4);
    
    a[0] = vaddq_s16(a[0], vcombine_s16(current0, current1));
    a[1] = vaddq_s16(a[1], vcombine_s16(current3, current2));
    
    vst1_s16(dest + destRowIncrement * 0, vget_low_s16(a[0]));
    vst1_s16(dest + destRowIncrement * 1, vget_high_s16(a[0]));
    vst1_s16(dest + destRowIncrement * 2, vget_high_s16(a[1]));
    vst1_s16(dest + destRowIncrement * 3, vget_low_s16(a[1]));
}

#endif

static int dct4x4QuantDC = 58;
static int dct4x4QuantAC = 58;

#if defined(__aarch64__)

void performForward4x4Dct(int16_t const *normalizedCoefficients, int16_t *coefficients, int width, int height, DCTELEM *divisors) {
    DCTELEM block[4 * 4];
    DCTELEM coefBlock[4 * 4];
    for (int y = 0; y < height; y += 4) {
        for (int x = 0; x < width; x += 4) {
            for (int blockY = 0; blockY < 4; blockY++) {
                for (int blockX = 0; blockX < 4; blockX++) {
                    block[blockY * 4 + blockX] = normalizedCoefficients[(y + blockY) * width + (x + blockX)];
                }
            }
            
            vpx_fdct4x4_c(block, coefBlock, 4);
            
            coefBlock[0] /= dct4x4QuantDC;
            
            for (int blockY = 0; blockY < 4; blockY++) {
                for (int blockX = 0; blockX < 4; blockX++) {
                    if (blockX == 0 && blockY == 0) {
                        continue;
                    }
                    
                    coefBlock[blockY * 4 + blockX] /= dct4x4QuantAC;
                }
            }
            
            for (int blockY = 0; blockY < 4; blockY++) {
                for (int blockX = 0; blockX < 4; blockX++) {
                    coefficients[(y + blockY) * width + (x + blockX)] = coefBlock[zigZag4x4Inv[blockY * 4 + blockX]];
                }
            }
        }
    }
}

void performInverse4x4DctAdd(int16_t const *coefficients, int16_t *normalizedCoefficients, int width, int height, DctAuxiliaryData *auxiliaryData, IFAST_MULT_TYPE *ifmtbl) {
    for (int y = 0; y < height; y += 4) {
        for (int x = 0; x < width; x += 4) {
            int16x4_t current0 = vld1_s16(&normalizedCoefficients[(y + 0) * width + x]);
            int16x4_t current1 = vld1_s16(&normalizedCoefficients[(y + 1) * width + x]);
            int16x4_t current2 = vld1_s16(&normalizedCoefficients[(y + 2) * width + x]);
            int16x4_t current3 = vld1_s16(&normalizedCoefficients[(y + 3) * width + x]);
            
            uint32x2_t sa = vld1_u32((uint32_t *)&coefficients[(y + 0) * width + x]);
            uint32x2_t sb = vld1_u32((uint32_t *)&coefficients[(y + 1) * width + x]);
            uint32x2_t sc = vld1_u32((uint32_t *)&coefficients[(y + 2) * width + x]);
            uint32x2_t sd = vld1_u32((uint32_t *)&coefficients[(y + 3) * width + x]);
            
            uint8x16_t top = vreinterpretq_u8_u32(vcombine_u32(sa, sb));
            uint8x16_t bottom = vreinterpretq_u8_u32(vcombine_u32(sc, sd));
            uint8x16x2_t quad = vzipq_u8(top, bottom);
            
            uint8_t topReorderIndices[16] = {0, 2, 4, 6, 20, 22, 24, 26, 8, 10, 16, 18, 28, 30, 17, 19};
            uint8_t bottomReorderIndices[16] = {12, 14, 1, 3, 13, 15, 21, 23, 5, 7, 9, 11, 25, 27, 29, 31};
            
            uint8x16_t qtop = vqtbl2q_u8(quad, vld1q_u8(topReorderIndices));
            uint8x16_t qbottom = vqtbl2q_u8(quad, vld1q_u8(bottomReorderIndices));
            
            uint16x8_t qtop16 = vreinterpretq_s16_u8(qtop);
            uint16x8_t qbottom16 = vreinterpretq_s16_u8(qbottom);

            int16x8_t top64 = vreinterpretq_s16_u16(qtop16);
            int16x8_t bottom64 = vreinterpretq_s16_u16(qbottom16);
            
            vpx_idct4x4_16_add_neon(top64, bottom64, current0, current1, current2, current3, dct4x4QuantAC, normalizedCoefficients + y * width + x, width);
        }
    }
}

#endif

}

namespace dct {

DCTTable DCTTable::generate(int quality, DCTTable::Type type) {
    DCTTable result;
    result.table.resize(DCTSIZE2);
    
    switch (type) {
        case DCTTable::Type::Luma:
            jpeg_set_quality(result.table.data(), std_luminance_quant_tbl, quality);
            break;
        case DCTTable::Type::Chroma:
            jpeg_set_quality(result.table.data(), std_chrominance_quant_tbl, quality);
            break;
        case DCTTable::Type::Delta:
            jpeg_set_quality(result.table.data(), std_delta_quant_tbl, quality);
            break;
        default:
            jpeg_set_quality(result.table.data(), std_luminance_quant_tbl, quality);
            break;
    }
    
    return result;
}

DCTTable DCTTable::initializeEmpty() {
    DCTTable result;
    result.table.resize(DCTSIZE2);
    return result;
}

class DCTInternal {
public:
    DCTInternal(DCTTable const &dctTable) {
        auxiliaryData = createDctAuxiliaryData();
        
        generateForwardDctData(dctTable.table.data(), forwardDctData);
        generateInverseDctData(dctTable.table.data(), inverseDctData);
    }
    
    ~DCTInternal() {
        freeDctAuxiliaryData(auxiliaryData);
    }
    
public:
    struct DctAuxiliaryData *auxiliaryData = nullptr;
    std::vector<uint8_t> forwardDctData;
    std::vector<uint8_t> inverseDctData;
};

DCT::DCT(DCTTable const &dctTable) {
    _internal = new DCTInternal(dctTable);
}

DCT::~DCT() {
    delete _internal;
}

void DCT::forward(uint8_t const *pixels, int16_t *coefficients, int width, int height, int bytesPerRow) {
    performForwardDct(pixels, coefficients, width, height, bytesPerRow, (DCTELEM *)_internal->forwardDctData.data());
}

void DCT::inverse(int16_t const *coefficients, uint8_t *pixels, int width, int height, int coefficientsPerRow, int bytesPerRow) {
    performInverseDct(coefficients, pixels, width, height, coefficientsPerRow, bytesPerRow, _internal->auxiliaryData, (IFAST_MULT_TYPE *)_internal->inverseDctData.data());
}

#if defined(__aarch64__)

void DCT::forward4x4(int16_t const *normalizedCoefficients, int16_t *coefficients, int width, int height) {
    performForward4x4Dct(normalizedCoefficients, coefficients, width, height, (DCTELEM *)_internal->forwardDctData.data());
}

void DCT::inverse4x4Add(int16_t const *coefficients, int16_t *normalizedCoefficients, int width, int height) {
    performInverse4x4DctAdd(coefficients, normalizedCoefficients, width, height, _internal->auxiliaryData, (IFAST_MULT_TYPE *)_internal->inverseDctData.data());
}

#endif

}
