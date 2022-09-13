#import <ImageDCT/ImageDCT.h>

#import <memory>

#include "DCT.h"

@interface ImageDCTTable () {
@public
    dct::DCTTable _table;
}

@end

@implementation ImageDCTTable

- (instancetype _Nonnull)initWithQuality:(NSInteger)quality type:(ImageDCTTableType)type; {
    self = [super init];
    if (self != nil) {
        dct::DCTTable::Type mappedType;
        switch (type) {
            case ImageDCTTableTypeLuma:
                mappedType = dct::DCTTable::Type::Luma;
                break;
            case ImageDCTTableTypeChroma:
                mappedType = dct::DCTTable::Type::Chroma;
                break;
            case ImageDCTTableTypeDelta:
                mappedType = dct::DCTTable::Type::Delta;
                break;
            default:
                mappedType = dct::DCTTable::Type::Luma;
                break;
        }
        _table = dct::DCTTable::generate((int)quality, mappedType);
    }
    return self;
}

- (instancetype _Nullable)initWithData:(NSData * _Nonnull)data {
    self = [super init];
    if (self != nil) {
        _table = dct::DCTTable::initializeEmpty();
        if (data.length != _table.table.size() * 2) {
            return nil;
        }
        memcpy(_table.table.data(), data.bytes, data.length);
    }
    return self;
}

- (NSData * _Nonnull)serializedData {
    return [[NSData alloc] initWithBytes:_table.table.data() length:_table.table.size() * 2];
}

@end

@interface ImageDCT () {
    std::unique_ptr<dct::DCT> _dct;
}

@end

@implementation ImageDCT

- (instancetype _Nonnull)initWithTable:(ImageDCTTable * _Nonnull)table {
    self = [super init];
    if (self != nil) {
        _dct = std::unique_ptr<dct::DCT>(new dct::DCT(table->_table));
    }
    return self;
}

- (void)forwardWithPixels:(uint8_t const * _Nonnull)pixels coefficients:(int16_t * _Nonnull)coefficients width:(NSInteger)width height:(NSInteger)height bytesPerRow:(NSInteger)bytesPerRow {
    _dct->forward(pixels, coefficients, (int)width, (int)height, (int)bytesPerRow);
}

- (void)inverseWithCoefficients:(int16_t const * _Nonnull)coefficients pixels:(uint8_t * _Nonnull)pixels width:(NSInteger)width height:(NSInteger)height coefficientsPerRow:(NSInteger)coefficientsPerRow bytesPerRow:(NSInteger)bytesPerRow {
    _dct->inverse(coefficients, pixels, (int)width, (int)height, (int)coefficientsPerRow, (int)bytesPerRow);
}

#if defined(__aarch64__)

- (void)forward4x4:(int16_t const * _Nonnull)normalizedCoefficients coefficients:(int16_t * _Nonnull)coefficients width:(NSInteger)width height:(NSInteger)height {
    _dct->forward4x4(normalizedCoefficients, coefficients, (int)width, (int)height);
}

- (void)inverse4x4Add:(int16_t const * _Nonnull)coefficients normalizedCoefficients:(int16_t * _Nonnull)normalizedCoefficients width:(NSInteger)width height:(NSInteger)height {
    _dct->inverse4x4Add(coefficients, normalizedCoefficients, (int)width, (int)height);
}

#endif

@end
