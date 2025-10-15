#ifndef DCT_H
#define DCT_H

#include "DCTCommon.h"

#include <vector>
#include <stdint.h>

namespace dct {

class DCTInternal;

struct DCTTable {
    enum class Type {
        Luma,
        Chroma,
        Delta
    };
    
    static DCTTable generate(int quality, Type type);
    static DCTTable initializeEmpty();
    
    std::vector<int16_t> table;
};

class DCT {
public:
    DCT(DCTTable const &dctTable);
    ~DCT();

    void forward(uint8_t const *pixels, int16_t *coefficients, int width, int height, int bytesPerRow);
    void inverse(int16_t const *coefficients, uint8_t *pixels, int width, int height, int coefficientsPerRow, int bytesPerRow);
    
#if defined(__aarch64__)
    void forward4x4(int16_t const *normalizedCoefficients, int16_t *coefficients, int width, int height);
    void inverse4x4Add(int16_t const *coefficients, int16_t *normalizedCoefficients, int width, int height);
#endif

private:
    DCTInternal *_internal;
};

}

#endif
