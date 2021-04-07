#import <RLottieBinding/LottieInstance.h>

#include "rlottie.h"

@interface LottieInstance () {
    std::unique_ptr<rlottie::Animation> _animation;
}

@end

@implementation LottieInstance

- (instancetype _Nullable)initWithData:(NSData * _Nonnull)data cacheKey:(NSString * _Nonnull)cacheKey {
    self = [super init];
    if (self != nil) {
        _animation = rlottie::Animation::loadFromData(std::string(reinterpret_cast<const char *>(data.bytes), data.length), std::string([cacheKey UTF8String]));
        if (_animation == nullptr) {
            return nil;
        }
        
        _frameCount = (int32_t)_animation->totalFrame();
        _frameRate = (int32_t)_animation->frameRate();
        
        size_t width = 0;
        size_t height = 0;
        _animation->size(width, height);
        
        if (width > 1024 || height > 1024) {
            return nil;
        }
        
        _dimensions = CGSizeMake(width, height);
        
        if ((_frameRate > 60) || _animation->duration() > 7.0) {
            return nil;
        }
    }
    return self;
}

- (void)renderFrameWithIndex:(int32_t)index into:(uint8_t * _Nonnull)buffer width:(int32_t)width height:(int32_t)height bytesPerRow:(int32_t) bytesPerRow{
    rlottie::Surface surface((uint32_t *)buffer, width, height, bytesPerRow);
    _animation->renderSync(index, surface);
}

@end
