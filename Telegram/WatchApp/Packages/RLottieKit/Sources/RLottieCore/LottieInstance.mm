#import <RLottieBinding/LottieInstance.h>

#include "rlottie.h"

#include <memory>
#include <string>

@interface LottieInstance () {
    std::unique_ptr<rlottie::Animation> _animation;
}
@end

@implementation LottieInstance

- (instancetype _Nullable)initWithData:(NSData *)data cacheKey:(NSString *)cacheKey {
    self = [super init];
    if (self == nil) { return nil; }

    std::string jsonStr(reinterpret_cast<const char *>(data.bytes), data.length);
    std::string keyStr(cacheKey.UTF8String ?: "");

    // Empty cache key disables rlottie's per-path cache; opt in only when caller
    // provides a real key.
    _animation = rlottie::Animation::loadFromData(
        jsonStr,
        keyStr,
        /* resourcePath */ "",
        /* cachePolicy */ keyStr.length() != 0
    );

    if (_animation == nullptr) {
        return nil;
    }

    int32_t frameCount = static_cast<int32_t>(_animation->totalFrame());
    int32_t frameRate = static_cast<int32_t>(_animation->frameRate());
    if (frameCount < 1) { frameCount = 1; }
    if (frameRate < 1) { frameRate = 1; }
    if (frameRate > 360) { return nil; }
    if (_animation->duration() > 9.0) { return nil; }

    size_t width = 0, height = 0;
    _animation->size(width, height);
    if (width == 0) { width = 1; }
    if (height == 0) { height = 1; }
    if (width > 1536 || height > 1536) { return nil; }

    _frameCount = frameCount;
    _frameRate = frameRate;
    _dimensions = CGSizeMake((CGFloat)width, (CGFloat)height);
    return self;
}

- (void)renderFrameWithIndex:(int32_t)index
                        into:(uint8_t *)buffer
                       width:(int32_t)width
                      height:(int32_t)height
                 bytesPerRow:(int32_t)bytesPerRow {
    if (width <= 0 || height <= 0 || bytesPerRow < width * 4) {
        return;
    }

    rlottie::Surface surface(
        reinterpret_cast<uint32_t *>(buffer),
        static_cast<size_t>(width),
        static_cast<size_t>(height),
        static_cast<size_t>(bytesPerRow)
    );
    _animation->renderSync(static_cast<size_t>(index), surface);
}

@end
