#import "DCT.h"

#include "DCTCommon.h"

#include <vector>

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

static const int zigZag[DCTSIZE2] = {
    0, 1, 8, 16, 9, 2, 3, 10, 17, 24, 32, 25, 18, 11, 4, 5, 12, 19, 26, 33, 40, 48, 41, 34, 27, 20, 13, 6, 7, 14, 21, 28, 35, 42, 49, 56, 57, 50, 43, 36, 29, 22, 15, 23, 30, 37, 44, 51, 58, 59, 52, 45, 38, 31, 39, 46, 53, 60, 61, 54, 47, 55, 62, 63
};

void performForwardDct(uint8_t const *pixels, int16_t *coefficients, int width, int height, int bytesPerRow, DCTELEM *divisors) {
    DCTELEM block[DCTSIZE2];
    JCOEF coefBlock[DCTSIZE2];
    
    for (int y = 0; y < height; y += DCTSIZE) {
        for (int x = 0; x < width; x += DCTSIZE) {
            for (int blockY = 0; blockY < DCTSIZE; blockY++) {
                for (int blockX = 0; blockX < DCTSIZE; blockX++) {
                    block[blockY * DCTSIZE + blockX] = ((DCTELEM)pixels[(y + blockY) * bytesPerRow + (x + blockX)]) - CENTERJSAMPLE;
                }
            }
            
            dct_jpeg_fdct_ifast(block);
            
            quantize(coefBlock, divisors, block);
            
            for (int blockY = 0; blockY < DCTSIZE; blockY++) {
                for (int blockX = 0; blockX < DCTSIZE; blockX++) {
                    coefficients[(y + blockY) * bytesPerRow + (x + blockX)] = coefBlock[zigZagInv[blockY * DCTSIZE + blockX]];
                }
            }
        }
    }
}

void performInverseDct(int16_t const * coefficients, uint8_t *pixels, int width, int height, int coefficientsPerRow, int bytesPerRow, DctAuxiliaryData *auxiliaryData, IFAST_MULT_TYPE *ifmtbl) {
    DCTELEM coefficientBlock[DCTSIZE2];
    JSAMPLE pixelBlock[DCTSIZE2];
    
    for (int y = 0; y < height; y += DCTSIZE) {
        for (int x = 0; x < width; x += DCTSIZE) {
            for (int blockY = 0; blockY < DCTSIZE; blockY++) {
                for (int blockX = 0; blockX < DCTSIZE; blockX++) {
                    coefficientBlock[zigZag[blockY * DCTSIZE + blockX]] = coefficients[(y + blockY) * coefficientsPerRow + (x + blockX)];
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

}

namespace dct {

DCTTable DCTTable::generate(int quality, bool isChroma) {
    DCTTable result;
    result.table.resize(DCTSIZE2);
    
    if (isChroma) {
        jpeg_set_quality(result.table.data(), std_chrominance_quant_tbl, quality);
    } else {
        jpeg_set_quality(result.table.data(), std_luminance_quant_tbl, quality);
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

}
