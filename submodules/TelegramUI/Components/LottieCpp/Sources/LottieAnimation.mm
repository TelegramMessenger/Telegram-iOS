#include <LottieCpp/LottieAnimation.h>

#include "Lottie/Private/Model/Animation.hpp"

#include <memory>

@interface LottieAnimation () {
@public
    std::shared_ptr<lottie::Animation> _animation;
}

@end

@implementation LottieAnimation

- (instancetype _Nullable)initWithData:(NSData * _Nonnull)data {
    self = [super init];
    if (self != nil) {
        std::string errorText;
        auto json = lottiejson11::Json::parse(std::string((uint8_t const *)data.bytes, ((uint8_t const *)data.bytes) + data.length), errorText);
        if (!json.is_object()) {
            return nil;
        }
        
        try {
            _animation = lottie::Animation::fromJson(json.object_items());
        } catch(...) {
            return nil;
        }
    }
    return self;
}

- (NSInteger)frameCount {
    return (NSInteger)(_animation->endFrame - _animation->startFrame);
}

- (NSInteger)framesPerSecond {
    return (NSInteger)(_animation->framerate);
}

- (CGSize)size {
    return CGSizeMake(_animation->width, _animation->height);
}

- (NSData * _Nonnull)toJson {
    lottiejson11::Json::object json = _animation->toJson();
    std::string jsonString = lottiejson11::Json(json).dump();
    return [[NSData alloc] initWithBytes:jsonString.data() length:jsonString.size()];
}

@end

@implementation LottieAnimation (Internal)

- (std::shared_ptr<lottie::Animation>)animationImpl {
    return _animation;
}

@end
