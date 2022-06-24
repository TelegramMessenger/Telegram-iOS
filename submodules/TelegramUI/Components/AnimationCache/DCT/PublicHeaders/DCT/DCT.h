#ifndef DctImageTransform_h
#define DctImageTransform_h

#import <Foundation/Foundation.h>

#import <DCT/YuvConversion.h>

NSData *generateForwardDctData(int quality);
void performForwardDct(uint8_t const *pixels, int16_t *coefficients, int width, int height, int bytesPerRow, NSData *dctData);

NSData *generateInverseDctData(int quality);
void performInverseDct(int16_t const *coefficients, uint8_t *pixels, int width, int height, int coefficientsPerRow, int bytesPerRow, NSData *idctData);

#endif /* DctImageTransform_h */
