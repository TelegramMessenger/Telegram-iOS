#import <ImageDCT/ImageDCT.h>

#import <memory>

#include "DCT.h"

@interface ImageDCT () {
    std::unique_ptr<dct::DCT> _dct;
}

@end

@implementation ImageDCT

- (instancetype _Nonnull)initWithQuality:(NSInteger)quality {
    self = [super init];
    if (self != nil) {
        _dct = std::unique_ptr<dct::DCT>(new dct::DCT((int)quality));
    }
    return self;
}

- (void)forwardWithPixels:(uint8_t const * _Nonnull)pixels coefficients:(int16_t * _Nonnull)coefficients width:(NSInteger)width height:(NSInteger)height bytesPerRow:(NSInteger)bytesPerRow {
    _dct->forward(pixels, coefficients, (int)width, (int)height, (int)bytesPerRow);
}

- (void)inverseWithCoefficients:(int16_t const * _Nonnull)coefficients pixels:(uint8_t * _Nonnull)pixels width:(NSInteger)width height:(NSInteger)height coefficientsPerRow:(NSInteger)coefficientsPerRow bytesPerRow:(NSInteger)bytesPerRow {
    _dct->inverse(coefficients, pixels, (int)width, (int)height, (int)coefficientsPerRow, (int)bytesPerRow);
}

@end
