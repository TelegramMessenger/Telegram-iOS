#import <inttypes.h>

#ifdef __cplusplus
extern "C" {
#endif
 
void compressRGBAToBC1(uint8_t const * _Nonnull argb, int width, int height, uint8_t * _Nonnull bc1);
    
#ifdef __cplusplus
}
#endif
