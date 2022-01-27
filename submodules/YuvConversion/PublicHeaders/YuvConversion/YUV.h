#import <Foundation/Foundation.h>

void encodeRGBAToYUVA(uint8_t *yuva, uint8_t const *argb, int width, int height, int bytesPerRow);
void resizeAndEncodeRGBAToYUVA(uint8_t *yuva, uint8_t const *argb, int width, int height, int bytesPerRow, int originalWidth, int originalHeight, int originalBytesPerRow);

void decodeYUVAToRGBA(uint8_t const *yuva, uint8_t *argb, int width, int height, int bytesPerRow);
void decodeYUVAPlanesToRGBA(uint8_t const *yPlane, uint8_t const *uvPlane, uint8_t const *alphaPlane, uint8_t *argb, int width, int height, int bytesPerRow);
