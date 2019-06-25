#import <inttypes.h>

#ifdef __cplusplus
extern "C" {
#endif
 
void compressRGBAToBC1(uint8_t const * _Nonnull argb, int width, int height, uint8_t * _Nonnull bc1);
void decompressBC1ToRGBA(uint8_t const * _Nonnull bc1, int width, int height, uint8_t * _Nonnull argb);
void compressRGBAToETC2(uint8_t const * _Nonnull argb, int width, int height, uint8_t * _Nonnull etc2);
    
#ifdef __cplusplus
}
#endif
