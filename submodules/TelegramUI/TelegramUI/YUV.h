#import <Foundation/Foundation.h>

void encodeRGBAToYUVA(uint8_t *yuva, uint8_t const *argb, int width, int height, int bytesPerRow);
void decodeYUVAToRGBA(uint8_t const *yuva, uint8_t *argb, int width, int height, int bytesPerRow);
