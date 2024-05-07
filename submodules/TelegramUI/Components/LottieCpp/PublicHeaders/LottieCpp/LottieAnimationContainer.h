#ifndef LottieAnimationContainer_h
#define LottieAnimationContainer_h

#import "LottieAnimation.h"
#import "LottieRenderTree.h"
#import "LottieAnimationContainer.h"

#ifdef __cplusplus
extern "C" {
#endif

@interface LottieAnimationContainer : NSObject

@property (nonatomic, strong, readonly) LottieAnimation * _Nonnull animation;

- (instancetype _Nonnull)initWithAnimation:(LottieAnimation * _Nonnull)animation;

- (void)update:(NSInteger)frame;
- (LottieRenderNode * _Nonnull)getCurrentRenderTreeForSize:(CGSize)size;

@end

#ifdef __cplusplus
}
#endif

#endif /* LottieAnimationContainer_h */
