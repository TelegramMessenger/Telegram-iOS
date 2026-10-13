#ifndef TLottieAnimation_h
#define TLottieAnimation_h

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

typedef NS_ENUM(int32_t, TLottieFitzModifier) {
    TLottieFitzModifierNone,
    TLottieFitzModifierType12,
    TLottieFitzModifierType3,
    TLottieFitzModifierType4,
    TLottieFitzModifierType5,
    TLottieFitzModifierType6
};

/// A Lottie animation rendered by tlottie (Rust).
///
/// Named TLottieAnimation, not TLottieInstance, because tlottie.h already
/// declares `struct TLottieInstance` for its opaque handle. ObjC++ rejects an
/// ObjC class and a C struct sharing an identifier in either include order, and
/// upstream owns that name.
///
/// tlottie is documented single-threaded with no internal locks; an instance
/// must be used from one queue at a time, matching how LottieInstance is used
/// throughout this project.
///
/// This class applies no size, frame-rate or duration policy. Those limits are
/// Telegram's, not a renderer's, and live in makeLottieInstance so that both
/// backends enforce them identically.
@interface TLottieAnimation : NSObject

@property (nonatomic, readonly) int32_t frameCount;
@property (nonatomic, readonly) int32_t frameRate;
@property (nonatomic, readonly) double duration;
@property (nonatomic, readonly) CGSize dimensions;

/// colorReplacements maps source colour to target colour, both NSNumber-wrapped
/// 0xAARRGGBB, matching RLottieInstance's dictionary exactly.
- (instancetype _Nullable)initWithData:(NSData * _Nonnull)data
                          fitzModifier:(TLottieFitzModifier)fitzModifier
                     colorReplacements:(NSDictionary * _Nullable)colorReplacements;

/// Writes premultiplied 0xAARRGGBB words, i.e. B,G,R,A bytes on little-endian —
/// the layout DrawingContext's transparentBitmapInfo describes.
- (void)renderFrameWithIndex:(int32_t)index
                        into:(uint8_t * _Nonnull)buffer
                       width:(int32_t)width
                      height:(int32_t)height
                 bytesPerRow:(int32_t)bytesPerRow;

@end

#endif /* TLottieAnimation_h */
