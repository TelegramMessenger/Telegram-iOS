#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import <Lottie/LOTComposition.h>

@interface LOTAnimationLayerContainer : NSObject

@property (nonatomic, readonly) CALayer *layer;

- (instancetype)initWithModel:(LOTComposition *)model size:(CGSize)size;

- (void)renderFrame:(int32_t)frame inContext:(CGContextRef)context;

@end
