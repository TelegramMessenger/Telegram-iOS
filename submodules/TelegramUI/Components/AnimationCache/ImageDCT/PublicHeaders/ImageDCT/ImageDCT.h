#ifndef DctImageTransform_h
#define DctImageTransform_h

#import <Foundation/Foundation.h>

#import <ImageDCT/YuvConversion.h>

@interface ImageDCT : NSObject

- (instancetype _Nonnull)initWithQuality:(NSInteger)quality;

- (void)forwardWithPixels:(uint8_t const * _Nonnull)pixels coefficients:(int16_t * _Nonnull)coefficients width:(NSInteger)width height:(NSInteger)height bytesPerRow:(NSInteger)bytesPerRow __attribute__((objc_direct));
- (void)inverseWithCoefficients:(int16_t const * _Nonnull)coefficients pixels:(uint8_t * _Nonnull)pixels width:(NSInteger)width height:(NSInteger)height coefficientsPerRow:(NSInteger)coefficientsPerRow bytesPerRow:(NSInteger)bytesPerRow __attribute__((objc_direct));

@end

#endif /* DctImageTransform_h */
