#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

/// Thin wrapper around `rlottie::Animation`. Holds one parsed lottie animation in memory.
/// rlottie's internal cache (keyed by `cacheKey`) keeps parsed paths warm across frames.
///
/// Defensive caps mirroring telegram-iOS: rejects animations with width/height > 1536px,
/// frameRate > 360, or duration > 9 seconds — these are typically malformed/abusive inputs.
@interface LottieInstance : NSObject

@property (nonatomic, readonly) int32_t frameCount;
@property (nonatomic, readonly) int32_t frameRate;
@property (nonatomic, readonly) CGSize dimensions;

/// Initializes from inflated lottie JSON bytes (TGS files are gzipped; gunzip first).
/// `cacheKey` is used by rlottie to share parsed paths across frames; pass a unique
/// stable string (e.g. the file's last path component).
- (instancetype _Nullable)initWithData:(NSData *)data cacheKey:(NSString *)cacheKey;

/// Renders `index` into `buffer`, which must be at least `bytesPerRow * height` bytes.
/// Pixel format is BGRA-premultiplied (rlottie::Surface's native layout).
- (void)renderFrameWithIndex:(int32_t)index
                        into:(uint8_t *)buffer
                       width:(int32_t)width
                      height:(int32_t)height
                 bytesPerRow:(int32_t)bytesPerRow;

@end

NS_ASSUME_NONNULL_END
