#import <Foundation/Foundation.h>

void encodeRGBAToYUVA(uint8_t *yuva, uint8_t const *argb, int width, int height, int bytesPerRow, bool unpremultiply);
void resizeAndEncodeRGBAToYUVA(uint8_t *yuva, uint8_t const *argb, int width, int height, int bytesPerRow, int originalWidth, int originalHeight, int originalBytesPerRow, bool unpremultiply);

void decodeYUVAToRGBA(uint8_t const *yuva, uint8_t *argb, int width, int height, int bytesPerRow);
void decodeYUVAPlanesToRGBA(uint8_t const *srcYpData, int srcYpBytesPerRow, uint8_t const *srcCbData, int srcCbBytesPerRow, uint8_t const *srcCrData, int srcCrBytesPerRow, bool hasAlpha, uint8_t const *alphaData, uint8_t *argb, int width, int height, int bytesPerRow);
