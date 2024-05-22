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

typedef struct {
    CGRect bounds;
    CGPoint position;
    CATransform3D transform;
    float opacity;
    bool masksToBounds;
    bool isHidden;
} LottieRenderNodeLayerData;

typedef struct {
    int64_t internalId;
    bool isValid;
    LottieRenderNodeLayerData layer;
    CGRect globalRect;
    CGRect localRect;
    CATransform3D globalTransform;
    bool drawsContent;
    bool hasSimpleContents;
    int drawContentDescendants;
    bool isInvertedMatte;
    int64_t maskId;
    int subnodeCount;
} LottieRenderNodeProxy;

@interface LottieAnimationContainer : NSObject

@property (nonatomic, strong, readonly) LottieAnimation * _Nonnull animation;

- (instancetype _Nonnull)initWithAnimation:(LottieAnimation * _Nonnull)animation;

- (void)update:(NSInteger)frame;
- (LottieRenderNode * _Nullable)getCurrentRenderTreeForSize:(CGSize)size;

#ifdef __cplusplus
- (std::shared_ptr<lottie::RenderTreeNode>)internalGetRootRenderTreeNode;
#endif

- (int64_t)getRootRenderNodeProxy;
- (LottieRenderNodeProxy)getRenderNodeProxyById:(int64_t)nodeId __attribute__((objc_direct));
- (LottieRenderNodeProxy)getRenderNodeSubnodeProxyById:(int64_t)nodeId index:(int)index __attribute__((objc_direct));

@end

#ifdef __cplusplus
}
#endif

#endif /* LottieAnimationContainer_h */
