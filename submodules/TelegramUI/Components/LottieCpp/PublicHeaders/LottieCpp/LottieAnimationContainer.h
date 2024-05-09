#ifndef LottieAnimationContainer_h
#define LottieAnimationContainer_h

#ifdef __cplusplus

#import "LottieAnimation.h"
#import "LottieRenderTree.h"
#import "LottieAnimationContainer.h"

#include <memory>

namespace lottie {

class RenderTreeNode;

}

#endif

#ifdef __cplusplus
extern "C" {
#endif

@interface LottieAnimationContainer : NSObject

@property (nonatomic, strong, readonly) LottieAnimation * _Nonnull animation;

- (instancetype _Nonnull)initWithAnimation:(LottieAnimation * _Nonnull)animation;

- (void)update:(NSInteger)frame;
- (LottieRenderNode * _Nullable)getCurrentRenderTreeForSize:(CGSize)size;

#ifdef __cplusplus
- (std::shared_ptr<lottie::RenderTreeNode>)internalGetRootRenderTreeNode;
#endif

@end

#ifdef __cplusplus
}
#endif

#endif /* LottieAnimationContainer_h */
