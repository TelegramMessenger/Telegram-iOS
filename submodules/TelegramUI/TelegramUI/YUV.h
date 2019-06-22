#import <Foundation/Foundation.h>

void encodeRGBAToBRGR422A(uint8_t * _Nonnull bgrg422, uint8_t * _Nonnull a, uint8_t const * _Nonnull argb, int width, int height);
void encodeBRGR422AToRGBA(uint8_t const * _Nonnull bgrg422, uint8_t const * _Nonnull a, uint8_t * _Nonnull argb, int width, int height);

NSData * _Nonnull encodeSparseBuffer(uint8_t const * _Nonnull bytes, int length);
void decodeSparseeBuffer(uint8_t * _Nonnull bytes, uint8_t const * _Nonnull buffer);
