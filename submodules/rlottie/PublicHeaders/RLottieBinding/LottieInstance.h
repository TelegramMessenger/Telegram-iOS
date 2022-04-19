#ifndef Lottie_h
#define Lottie_h

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

typedef NS_ENUM(int32_t, LottieFitzModifier) {
    LottieFitzModifierNone,
    LottieFitzModifierType12,
    LottieFitzModifierType3,
    LottieFitzModifierType4,
    LottieFitzModifierType5,
    LottieFitzModifierType6
};

@interface LottieInstance : NSObject

@property (nonatomic, readonly) int32_t frameCount;
@property (nonatomic, readonly) int32_t frameRate;
@property (nonatomic, readonly) CGSize dimensions;

- (instancetype _Nullable)initWithData:(NSData * _Nonnull)data fitzModifier:(LottieFitzModifier)fitzModifier colorReplacements:(NSDictionary * _Nullable)colorReplacements cacheKey:(NSString * _Nonnull)cacheKey;

- (void)renderFrameWithIndex:(int32_t)index into:(uint8_t * _Nonnull)buffer width:(int32_t)width height:(int32_t)height bytesPerRow:(int32_t)bytesPerRow;

@end

#endif /* Lottie_h */
