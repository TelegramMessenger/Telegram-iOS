#ifndef YuvConversion_h
#define YuvConversion_h

#import <Foundation/Foundation.h>

#ifdef __cplusplus__
extern "C" {
#endif

void splitRGBAIntoYUVAPlanes(uint8_t const *argb, uint8_t *outY, uint8_t *outU, uint8_t *outV, uint8_t *outA, int width, int height, int bytesPerRow);
void combineYUVAPlanesIntoARGB(uint8_t *argb, uint8_t const *inY, uint8_t const *inU, uint8_t const *inV, uint8_t const *inA, int width, int height, int bytesPerRow);
void scaleImagePlane(uint8_t *outPlane, int outWidth, int outHeight, int outBytesPerRow, uint8_t const *inPlane, int inWidth, int inHeight, int inBytesPerRow);

void convertUInt8toInt16(uint8_t const *source, int16_t *dest, int length);
void convertInt16toUInt8(int16_t const *source, uint8_t *dest, int length);
void subtractArraysInt16(int16_t const *a, int16_t const *b, int16_t *dest, int length);
void addArraysInt16(int16_t const *a, int16_t const *b, int16_t *dest, int length);
void subtractArraysUInt8Int16(uint8_t const *a, int16_t const *b, uint8_t *dest, int length);
void addArraysUInt8Int16(uint8_t const *a, int16_t const *b, uint8_t *dest, int length);

#ifdef __cplusplus__
}
#endif

#endif /* YuvConversion_h */
