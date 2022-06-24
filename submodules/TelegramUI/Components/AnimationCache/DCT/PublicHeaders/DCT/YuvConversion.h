#ifndef YuvConversion_h
#define YuvConversion_h

#import <Foundation/Foundation.h>

void splitRGBAIntoYUVAPlanes(uint8_t const *argb, uint8_t *outY, uint8_t *outU, uint8_t *outV, uint8_t *outA, int width, int height, int bytesPerRow);
void combineYUVAPlanesIntoARBB(uint8_t *argb, uint8_t const *inY, uint8_t const *inU, uint8_t const *inV, uint8_t const *inA, int width, int height, int bytesPerRow);

#endif /* YuvConversion_h */
