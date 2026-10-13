#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, FFMpegAVFrameColorRange) {
    FFMpegAVFrameColorRangeRestricted,
    FFMpegAVFrameColorRangeFull
};

typedef NS_ENUM(NSUInteger, FFMpegAVFramePixelFormat) {
    FFMpegAVFramePixelFormatYUV,
    FFMpegAVFramePixelFormatYUVA,
    // Chroma layouts decoders emit but the CVPixelBuffer paths cannot take directly:
    // half-width/full-height (4:2:2, H.264 High 4:2:2 Predictive) and full-resolution
    // (4:4:4, H.264 High 4:4:4 Predictive). Never a valid argument to
    // `initWithPixelFormat:`, which only allocates the 420 layouts.
    FFMpegAVFramePixelFormatYUV422,
    FFMpegAVFramePixelFormatYUVA422,
    FFMpegAVFramePixelFormatYUV444,
    FFMpegAVFramePixelFormatYUVA444,
    FFMpegAVFramePixelFormatUnsupported
};

typedef NS_ENUM(NSUInteger, FFMpegAVFrameNativePixelFormat) {
    FFMpegAVFrameNativePixelFormatUnknown,
    FFMpegAVFrameNativePixelFormatVideoToolbox
};

@interface FFMpegAVFrame : NSObject

@property (nonatomic, readonly) int32_t width;
@property (nonatomic, readonly) int32_t height;
@property (nonatomic, readonly) uint8_t * _Nullable * _Nonnull data;
@property (nonatomic, readonly) int * _Nonnull lineSize;
@property (nonatomic, readonly) int64_t pts;
@property (nonatomic, readonly) int64_t duration;
@property (nonatomic, readonly) FFMpegAVFrameColorRange colorRange;
@property (nonatomic, readonly) FFMpegAVFramePixelFormat pixelFormat;

- (instancetype)init;
- (instancetype _Nullable)initWithPixelFormat:(FFMpegAVFramePixelFormat)pixelFormat width:(int32_t)width height:(int32_t)height;

- (void *)impl;
- (FFMpegAVFrameNativePixelFormat)nativePixelFormat;
// Adopts another frame's colour range. A frame from `initWithPixelFormat:` starts at
// AVCOL_RANGE_UNSPECIFIED, which `colorRange` reports as restricted — so a scratch
// frame built from a full-range source (YUVJ*) would otherwise be converted with the
// wrong coefficients.
- (void)copyColorRangeFrom:(FFMpegAVFrame *)other;

@end

NS_ASSUME_NONNULL_END
