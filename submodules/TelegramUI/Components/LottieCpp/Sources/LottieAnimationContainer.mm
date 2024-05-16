#include <LottieCpp/LottieAnimationContainer.h>

#include "Lottie/Private/MainThread/LayerContainers/MainThreadAnimationLayer.hpp"
#include "LottieAnimationInternal.h"
#include <LottieCpp/VectorsCocoa.h>

@interface LottieAnimationContainer () {
@public
    std::shared_ptr<lottie::MainThreadAnimationLayer> _layer;
    std::shared_ptr<lottie::BezierPathsBoundingBoxContext> _bezierPathsBoundingBoxContext;
}

@end

@implementation LottieAnimationContainer

- (instancetype _Nonnull)initWithAnimation:(LottieAnimation * _Nonnull)animation {
    self = [super init];
    if (self != nil) {
        _bezierPathsBoundingBoxContext = std::make_shared<lottie::BezierPathsBoundingBoxContext>();
        
        _animation = animation;
        
        _layer = std::make_shared<lottie::MainThreadAnimationLayer>(
            *[animation animationImpl].get(),
            std::make_shared<lottie::BlankImageProvider>(),
            std::make_shared<lottie::DefaultTextProvider>(),
            std::make_shared<lottie::DefaultFontProvider>()
        );
    }
    return self;
}

- (void)update:(NSInteger)frame {
    _layer->setCurrentFrame(frame);
}

- (LottieRenderNode * _Nullable)getCurrentRenderTreeForSize:(CGSize)size {
    return nil;
}

- (std::shared_ptr<lottie::RenderTreeNode>)internalGetRootRenderTreeNode {
    auto renderNode = _layer->renderTreeNode();
    return renderNode;
}

- (int64_t)getRootRenderNodeProxy {
    std::shared_ptr<lottie::RenderTreeNode> renderNode = [self internalGetRootRenderTreeNode];
    return (int64_t)renderNode.get();
}

- (LottieRenderNodeProxy)getRenderNodeProxyById:(int64_t)nodeId __attribute__((objc_direct)) {
    lottie::RenderTreeNode *node = (lottie::RenderTreeNode *)nodeId;
    
    LottieRenderNodeProxy result;
    
    result.internalId = nodeId;
    result.isValid = node->renderData.isValid;
    
    result.layer.bounds = CGRectMake(node->renderData.layer._bounds.x, node->renderData.layer._bounds.y, node->renderData.layer._bounds.width, node->renderData.layer._bounds.height);
    result.layer.position = CGPointMake(node->renderData.layer._position.x, node->renderData.layer._position.y);
    result.layer.transform = lottie::nativeTransform(node->renderData.layer._transform);
    result.layer.opacity = node->renderData.layer._opacity;
    result.layer.masksToBounds = node->renderData.layer._masksToBounds;
    result.layer.isHidden = node->renderData.layer._isHidden;
    
    result.globalRect = CGRectMake(node->renderData.globalRect.x, node->renderData.globalRect.y, node->renderData.globalRect.width, node->renderData.globalRect.height);
    result.globalTransform = lottie::nativeTransform(node->renderData.globalTransform);
    result.hasSimpleContents = node->renderData.drawContentDescendants <= 1;
    result.drawContentDescendants = node->renderData.drawContentDescendants;
    result.isInvertedMatte = node->renderData.isInvertedMatte;
    if (node->mask()) {
        result.maskId = (int64_t)node->mask().get();
    } else {
        result.maskId = 0;
    }
    result.subnodeCount = (int)node->subnodes().size();
    
    return result;
}

- (LottieRenderNodeProxy)getRenderNodeSubnodeProxyById:(int64_t)nodeId index:(int)index __attribute__((objc_direct)) {
    lottie::RenderTreeNode *node = (lottie::RenderTreeNode *)nodeId;
    return [self getRenderNodeProxyById:(int64_t)node->subnodes()[index].get()];
}

@end

@implementation LottieAnimationContainer (Internal)

- (std::shared_ptr<lottie::MainThreadAnimationLayer>)layer {
    return _layer;
}

@end
