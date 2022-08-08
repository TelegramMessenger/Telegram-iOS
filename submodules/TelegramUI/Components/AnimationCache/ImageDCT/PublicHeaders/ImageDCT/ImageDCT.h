#ifndef DctImageTransform_h
#define DctImageTransform_h

#import <Foundation/Foundation.h>

#import <ImageDCT/YuvConversion.h>

typedef NS_ENUM(NSUInteger, ImageDCTTableType) {
    ImageDCTTableTypeLuma,
    ImageDCTTableTypeChroma,
    ImageDCTTableTypeDelta
};

@interface ImageDCTTable : NSObject

- (instancetype _Nonnull)initWithQuality:(NSInteger)quality type:(ImageDCTTableType)type;
- (instancetype _Nullable)initWithData:(NSData * _Nonnull)data;

- (NSData * _Nonnull)serializedData;

@end

@interface ImageDCT : NSObject

- (instancetype _Nonnull)initWithTable:(ImageDCTTable * _Nonnull)table;

- (void)forwardWithPixels:(uint8_t const * _Nonnull)pixels coefficients:(int16_t * _Nonnull)coefficients width:(NSInteger)width height:(NSInteger)height bytesPerRow:(NSInteger)bytesPerRow __attribute__((objc_direct));
- (void)inverseWithCoefficients:(int16_t const * _Nonnull)coefficients pixels:(uint8_t * _Nonnull)pixels width:(NSInteger)width height:(NSInteger)height coefficientsPerRow:(NSInteger)coefficientsPerRow bytesPerRow:(NSInteger)bytesPerRow __attribute__((objc_direct));

#if defined(__aarch64__)
- (void)forward4x4:(int16_t const * _Nonnull)normalizedCoefficients coefficients:(int16_t * _Nonnull)coefficients width:(NSInteger)width height:(NSInteger)height __attribute__((objc_direct));
- (void)inverse4x4Add:(int16_t const * _Nonnull)coefficients normalizedCoefficients:(int16_t * _Nonnull)normalizedCoefficients width:(NSInteger)width height:(NSInteger)height __attribute__((objc_direct));
#endif

@end

#endif /* DctImageTransform_h */
