#ifndef DCT_H
#define DCT_H

#include "DCTCommon.h"

#include <stdint.h>

namespace dct {

class DCTInternal;

class DCT {
public:
    DCT(int quality);
    ~DCT();

    void forward(uint8_t const *pixels, int16_t *coefficients, int width, int height, int bytesPerRow);
    void inverse(int16_t const *coefficients, uint8_t *pixels, int width, int height, int coefficientsPerRow, int bytesPerRow);

private:
    DCTInternal *_internal;
};

}

#endif
