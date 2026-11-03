#import <RLottieBinding/RLottieInstance.h>

#include "rlottie.h"

@interface RLottieInstance () {
    std::unique_ptr<rlottie::Animation> _animation;
}

@end

@implementation RLottieInstance

- (instancetype _Nullable)initWithData:(NSData * _Nonnull)data fitzModifier:(RLottieFitzModifier)fitzModifier colorReplacements:(NSDictionary * _Nullable)colorReplacements cacheKey:(NSString * _Nonnull)cacheKey {
    self = [super init];
    if (self != nil) {
        rlottie::FitzModifier modifier;
        switch(fitzModifier) {
            case RLottieFitzModifierNone:
                modifier = rlottie::FitzModifier::None;
                break;
            case RLottieFitzModifierType12:
                modifier = rlottie::FitzModifier::Type12;
                break;
            case RLottieFitzModifierType3:
                modifier = rlottie::FitzModifier::Type3;
                break;
            case RLottieFitzModifierType4:
                modifier = rlottie::FitzModifier::Type4;
                break;
            case RLottieFitzModifierType5:
                modifier = rlottie::FitzModifier::Type5;
                break;
            case RLottieFitzModifierType6:
                modifier = rlottie::FitzModifier::Type6;
                break;
        }

        std::vector<std::pair<std::uint32_t, std::uint32_t>> colorsVector;
        if (colorReplacements != nil) {
            for (NSNumber *color in colorReplacements.allKeys) {
                NSNumber *replacement = colorReplacements[color];
                colorsVector.push_back({ color.unsignedIntValue, replacement.unsignedIntValue });
            }
        }

        _animation = rlottie::Animation::loadFromData(std::string(reinterpret_cast<const char *>(data.bytes), data.length), std::string([cacheKey UTF8String]), "", cacheKey.length != 0, colorsVector, modifier);
        if (_animation == nullptr) {
            return nil;
        }

        _frameCount = (int32_t)_animation->totalFrame();
        _frameCount = MAX(1, _frameCount);
        _frameRate = (int32_t)_animation->frameRate();
        _frameRate = MAX(1, _frameRate);

        // Reported rather than derived from frameCount / frameRate: rlottie
        // computes it from the unclamped, possibly fractional frame rate, and
        // makeLottieInstance's 9-second limit is applied to this value.
        _duration = _animation->duration();

        size_t width = 0;
        size_t height = 0;
        _animation->size(width, height);

        width = MAX(1, width);
        height = MAX(1, height);

        _dimensions = CGSizeMake(width, height);
    }
    return self;
}

- (void)renderFrameWithIndex:(int32_t)index into:(uint8_t * _Nonnull)buffer width:(int32_t)width height:(int32_t)height bytesPerRow:(int32_t) bytesPerRow{
    rlottie::Surface surface((uint32_t *)buffer, width, height, bytesPerRow);
    _animation->renderSync(index, surface);
}

@end
