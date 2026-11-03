#ifndef RLottieInstance_h
#define RLottieInstance_h

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

typedef NS_ENUM(int32_t, RLottieFitzModifier) {
    RLottieFitzModifierNone,
    RLottieFitzModifierType12,
    RLottieFitzModifierType3,
    RLottieFitzModifierType4,
    RLottieFitzModifierType5,
    RLottieFitzModifierType6
};

/// A Lottie animation rendered by rlottie (C++).
///
/// This class applies no size, frame-rate or duration policy. Those limits are
/// Telegram's, not a renderer's, and live in makeLottieInstance so that both
/// backends enforce them identically.
@interface RLottieInstance : NSObject

@property (nonatomic, readonly) int32_t frameCount;
@property (nonatomic, readonly) int32_t frameRate;
@property (nonatomic, readonly) double duration;
@property (nonatomic, readonly) CGSize dimensions;

- (instancetype _Nullable)initWithData:(NSData * _Nonnull)data
                          fitzModifier:(RLottieFitzModifier)fitzModifier
                     colorReplacements:(NSDictionary * _Nullable)colorReplacements
                              cacheKey:(NSString * _Nonnull)cacheKey;

- (void)renderFrameWithIndex:(int32_t)index
                        into:(uint8_t * _Nonnull)buffer
                       width:(int32_t)width
                      height:(int32_t)height
                 bytesPerRow:(int32_t)bytesPerRow;

@end

#endif /* RLottieInstance_h */
