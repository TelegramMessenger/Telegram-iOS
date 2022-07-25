#ifndef DCT_H
#define DCT_H

#include "DCTCommon.h"

#include <vector>
#include <stdint.h>

namespace dct {

class DCTInternal;

struct DCTTable {
    static DCTTable generate(int quality, bool isChroma);
    static DCTTable initializeEmpty();
    
    std::vector<int16_t> table;
};

class DCT {
public:
    DCT(DCTTable const &dctTable);
    ~DCT();

    void forward(uint8_t const *pixels, int16_t *coefficients, int width, int height, int bytesPerRow);
    void inverse(int16_t const *coefficients, uint8_t *pixels, int width, int height, int coefficientsPerRow, int bytesPerRow);

private:
    DCTInternal *_internal;
};

}

#endif
