#ifndef astc_h
#define astc_h

#include "bgra.h"
#include "compressed.h"

void compress_astc(const BgraImage& image, CompressedImage* compressed);

#endif /* astc_h */
