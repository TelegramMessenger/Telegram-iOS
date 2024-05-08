#include <LottieCpp/LottieAnimationContainer.h>

#include "Lottie/Private/MainThread/LayerContainers/MainThreadAnimationLayer.hpp"
#include "LottieAnimationInternal.h"
#include "RenderNode.hpp"
#include "LottieRenderTreeInternal.h"

namespace lottie {

struct RenderNodeDesc {
    struct LayerParams {
        CGRect _bounds;
        Vector2D _position;
        CATransform3D _transform;
        double _opacity;
        bool _masksToBounds;
        bool _isHidden;
        
        LayerParams(
            CGRect bounds_,
            Vector2D position_,
            CATransform3D transform_,
            double opacity_,
            bool masksToBounds_,
            bool isHidden_
        ) :
        _bounds(bounds_),
        _position(position_),
        _transform(transform_),
        _opacity(opacity_),
        _masksToBounds(masksToBounds_),
        _isHidden(isHidden_) {
        }
        
        LayerParams(std::shared_ptr<CALayer> const &layer) :
        _bounds(layer->bounds()),
        _position(layer->position()),
        _transform(layer->transform()),
        _opacity(layer->opacity()),
        _masksToBounds(layer->masksToBounds()),
        _isHidden(layer->isHidden()) {
        }
        
        CGRect bounds() const {
            return _bounds;
        }
        
        Vector2D position() const {
            return _position;
        }
        
        CATransform3D transform() const {
            return _transform;
        }
        
        double opacity() const {
            return _opacity;
        }
        
        bool masksToBounds() const {
            return _masksToBounds;
        }
        
        bool isHidden() const {
            return _isHidden;
        }
    };
    
    LayerParams layer;
    CGRect globalRect;
    CGRect localRect;
    CATransform3D globalTransform;
    bool drawsContent;
    bool renderContent;
    int drawContentDescendants;
    bool isInvertedMatte;
    std::shared_ptr<OutputRenderNode> mask;
    
    explicit RenderNodeDesc(
        LayerParams const &layer_,
        CGRect const &globalRect_,
        CGRect const &localRect_,
        CATransform3D const &globalTransform_,
        bool drawsContent_,
        bool renderContent_,
        int drawContentDescendants_,
        bool isInvertedMatte_
    ) :
    layer(layer_),
    globalRect(globalRect_),
    localRect(localRect_),
    globalTransform(globalTransform_),
    drawsContent(drawsContent_),
    renderContent(renderContent_),
    drawContentDescendants(drawContentDescendants_),
    isInvertedMatte(isInvertedMatte_) {
    }
};

static std::shared_ptr<OutputRenderNode> convertRenderTree(std::shared_ptr<RenderTreeNode> const &node, Vector2D const &globalSize, CATransform3D const &parentTransform, bool isInvertedMask, BezierPathsBoundingBoxContext &bezierPathsBoundingBoxContext) {
    if (node->isHidden() || node->alpha() == 0.0f) {
        return nullptr;
    }
    
    if (node->masksToBounds()) {
        if (node->bounds().empty()) {
            return nullptr;
        }
    }
    
    auto currentTransform = parentTransform;
    
    Vector2D localTranslation(node->position().x + -node->bounds().x, node->position().y + -node->bounds().y);
    CATransform3D localTransform = node->transform();
    localTransform = localTransform.translated(localTranslation);
    
    currentTransform = localTransform * currentTransform;
    
    if (!currentTransform.isInvertible()) {
        return nullptr;
    }
    
    std::optional<CGRect> effectiveLocalBounds;
    
    double alpha = node->alpha();
    
    if (node->content()) {
        RenderTreeNodeContent *shapeContent = node->content().get();
        
        CGRect shapeBounds = bezierPathsBoundingBoxParallel(bezierPathsBoundingBoxContext, shapeContent->paths);
        
        if (shapeContent->stroke) {
            shapeBounds = shapeBounds.insetBy(-shapeContent->stroke->lineWidth / 2.0, -shapeContent->stroke->lineWidth / 2.0);
            effectiveLocalBounds = shapeBounds;
            
            switch (shapeContent->stroke->shading->type()) {
                case RenderTreeNodeContent::ShadingType::Solid: {
                    RenderTreeNodeContent::SolidShading *solidShading = (RenderTreeNodeContent::SolidShading *)shapeContent->stroke->shading.get();
                    
                    alpha *= solidShading->opacity;
                    
                    break;
                }
                case RenderTreeNodeContent::ShadingType::Gradient: {
                    
                    break;
                }
                default:
                    break;
            }
        } else if (shapeContent->fill) {
            effectiveLocalBounds = shapeBounds;
            
            switch (shapeContent->fill->shading->type()) {
                case RenderTreeNodeContent::ShadingType::Solid: {
                    RenderTreeNodeContent::SolidShading *solidShading = (RenderTreeNodeContent::SolidShading *)shapeContent->fill->shading.get();
                    
                    alpha *= solidShading->opacity;
                    
                    break;
                }
                case RenderTreeNodeContent::ShadingType::Gradient: {
                    RenderTreeNodeContent::GradientShading *gradientShading = (RenderTreeNodeContent::GradientShading *)shapeContent->fill->shading.get();
                    
                    alpha *= gradientShading->opacity;
                    
                    break;
                }
                default:
                    break;
            }
        }
    }
    
    bool isInvertedMatte = isInvertedMask;
    if (isInvertedMatte) {
        effectiveLocalBounds = node->bounds();
    }
    
    if (effectiveLocalBounds && effectiveLocalBounds->empty()) {
        effectiveLocalBounds = std::nullopt;
    }
    
    std::optional<CGRect> effectiveLocalRect;
    if (effectiveLocalBounds.has_value()) {
        effectiveLocalRect = effectiveLocalBounds;
    }
    
    std::vector<std::shared_ptr<OutputRenderNode>> subnodes;
    std::optional<CGRect> subnodesGlobalRect;
    bool masksToBounds = node->masksToBounds();
    
    int drawContentDescendants = 0;
    
    for (const auto &item : node->subnodes()) {
        if (const auto subnode = convertRenderTree(item, globalSize, currentTransform, false, bezierPathsBoundingBoxContext)) {
            subnodes.push_back(subnode);
            
            drawContentDescendants += subnode->drawContentDescendants;
            
            if (subnode->renderContent) {
                drawContentDescendants += 1;
            }
            
            if (!subnode->localRect.empty()) {
                if (effectiveLocalRect.has_value()) {
                    effectiveLocalRect = effectiveLocalRect->unionWith(subnode->localRect);
                } else {
                    effectiveLocalRect = subnode->localRect;
                }
            }
            
            if (subnodesGlobalRect) {
                subnodesGlobalRect = subnodesGlobalRect->unionWith(subnode->globalRect);
            } else {
                subnodesGlobalRect = subnode->globalRect;
            }
        }
    }
    
    if (masksToBounds && effectiveLocalRect.has_value()) {
        if (node->bounds().contains(effectiveLocalRect.value())) {
            masksToBounds = false;
        }
    }
    
    std::optional<CGRect> fuzzyGlobalRect;
    
    if (effectiveLocalBounds) {
        CGRect effectiveGlobalBounds = effectiveLocalBounds->applyingTransform(currentTransform);
        if (fuzzyGlobalRect) {
            fuzzyGlobalRect = fuzzyGlobalRect->unionWith(effectiveGlobalBounds);
        } else {
            fuzzyGlobalRect = effectiveGlobalBounds;
        }
    }
    
    if (subnodesGlobalRect) {
        if (fuzzyGlobalRect) {
            fuzzyGlobalRect = fuzzyGlobalRect->unionWith(subnodesGlobalRect.value());
        } else {
            fuzzyGlobalRect = subnodesGlobalRect;
        }
    }
    
    if (!fuzzyGlobalRect) {
        return nullptr;
    }
    
    CGRect globalRect(
        std::floor(fuzzyGlobalRect->x),
        std::floor(fuzzyGlobalRect->y),
        std::ceil(fuzzyGlobalRect->width + fuzzyGlobalRect->x - floor(fuzzyGlobalRect->x)),
        std::ceil(fuzzyGlobalRect->height + fuzzyGlobalRect->y - floor(fuzzyGlobalRect->y))
    );
    
    if (!CGRect(0.0, 0.0, globalSize.x, globalSize.y).intersects(globalRect)) {
        return nullptr;
    }
    
    if (masksToBounds && effectiveLocalBounds) {
        CGRect effectiveGlobalBounds = effectiveLocalBounds->applyingTransform(currentTransform);
        if (effectiveGlobalBounds.contains(CGRect(0.0, 0.0, globalSize.x, globalSize.y))) {
            masksToBounds = false;
        }
    }
    
    std::shared_ptr<OutputRenderNode> maskNode;
    if (node->mask()) {
        if (const auto maskNodeValue = convertRenderTree(node->mask(), globalSize, currentTransform, node->invertMask(), bezierPathsBoundingBoxContext)) {
            if (!maskNodeValue->globalRect.intersects(globalRect)) {
                return nullptr;
            }
            maskNode = maskNodeValue;
        } else {
            return nullptr;
        }
    }
    
    CGRect localRect = effectiveLocalRect.value_or(CGRect(0.0, 0.0, 0.0, 0.0)).applyingTransform(localTransform);
    
    return std::make_shared<OutputRenderNode>(
        OutputRenderNode::LayerParams(
            node->bounds(),
            node->position(),
            node->transform(),
            alpha,
            masksToBounds,
            node->isHidden()
        ),
        globalRect,
        localRect,
        currentTransform,
        effectiveLocalBounds.has_value(),
        node->content(),
        drawContentDescendants,
        isInvertedMatte,
        subnodes,
        maskNode
    );
}

/*static void visitRenderTree(std::shared_ptr<RenderTreeNode> const &node, Vector2D const &globalSize, CATransform3D const &parentTransform, bool isInvertedMask, BezierPathsBoundingBoxContext &bezierPathsBoundingBoxContext) {
    if (node->isHidden() || node->alpha() == 0.0f) {
        return nullptr;
    }
    
    if (node->masksToBounds()) {
        if (node->bounds().empty()) {
            return nullptr;
        }
    }
    
    auto currentTransform = parentTransform;
    
    Vector2D localTranslation(node->position().x - node->bounds().x, node->position().y - node->bounds().y);
    CATransform3D localTransform = node->transform();
    localTransform = localTransform.translated(localTranslation);
    
    currentTransform = localTransform * currentTransform;
    
    if (!currentTransform.isInvertible()) {
        return nullptr;
    }
    
    std::optional<CGRect> effectiveLocalBounds;
    
    double alpha = node->alpha();
    
    if (node->content()) {
        RenderTreeNodeContent *shapeContent = node->content().get();
        
        CGRect shapeBounds = bezierPathsBoundingBoxParallel(bezierPathsBoundingBoxContext, shapeContent->paths);
        
        if (shapeContent->stroke) {
            shapeBounds = shapeBounds.insetBy(-shapeContent->stroke->lineWidth / 2.0, -shapeContent->stroke->lineWidth / 2.0);
            effectiveLocalBounds = shapeBounds;
            
            switch (shapeContent->stroke->shading->type()) {
                case RenderTreeNodeContent::ShadingType::Solid: {
                    RenderTreeNodeContent::SolidShading *solidShading = (RenderTreeNodeContent::SolidShading *)shapeContent->stroke->shading.get();
                    
                    alpha *= solidShading->opacity;
                    
                    break;
                }
                case RenderTreeNodeContent::ShadingType::Gradient: {
                    
                    break;
                }
                default:
                    break;
            }
        } else if (shapeContent->fill) {
            effectiveLocalBounds = shapeBounds;
            
            switch (shapeContent->fill->shading->type()) {
                case RenderTreeNodeContent::ShadingType::Solid: {
                    RenderTreeNodeContent::SolidShading *solidShading = (RenderTreeNodeContent::SolidShading *)shapeContent->fill->shading.get();
                    
                    alpha *= solidShading->opacity;
                    
                    break;
                }
                case RenderTreeNodeContent::ShadingType::Gradient: {
                    RenderTreeNodeContent::GradientShading *gradientShading = (RenderTreeNodeContent::GradientShading *)shapeContent->fill->shading.get();
                    
                    alpha *= gradientShading->opacity;
                    
                    break;
                }
                default:
                    break;
            }
        }
    }
    
    bool isInvertedMatte = isInvertedMask;
    if (isInvertedMatte) {
        effectiveLocalBounds = node->bounds();
    }
    
    if (effectiveLocalBounds && effectiveLocalBounds->empty()) {
        effectiveLocalBounds = std::nullopt;
    }
    
    std::optional<CGRect> effectiveLocalRect;
    if (effectiveLocalBounds.has_value()) {
        effectiveLocalRect = effectiveLocalBounds;
    }
    
    std::vector<std::shared_ptr<OutputRenderNode>> subnodes;
    std::optional<CGRect> subnodesGlobalRect;
    bool masksToBounds = node->masksToBounds();
    
    int drawContentDescendants = 0;
    
    for (const auto &item : node->subnodes()) {
        if (const auto subnode = convertRenderTree(item, globalSize, currentTransform, false, bezierPathsBoundingBoxContext)) {
            subnodes.push_back(subnode);
            
            drawContentDescendants += subnode->drawContentDescendants;
            
            if (subnode->renderContent) {
                drawContentDescendants += 1;
            }
            
            if (!subnode->localRect.empty()) {
                if (effectiveLocalRect.has_value()) {
                    effectiveLocalRect = effectiveLocalRect->unionWith(subnode->localRect);
                } else {
                    effectiveLocalRect = subnode->localRect;
                }
            }
            
            if (subnodesGlobalRect) {
                subnodesGlobalRect = subnodesGlobalRect->unionWith(subnode->globalRect);
            } else {
                subnodesGlobalRect = subnode->globalRect;
            }
        }
    }
    
    if (masksToBounds && effectiveLocalRect.has_value()) {
        if (node->bounds().contains(effectiveLocalRect.value())) {
            masksToBounds = false;
        }
    }
    
    std::optional<CGRect> fuzzyGlobalRect;
    
    if (effectiveLocalBounds) {
        CGRect effectiveGlobalBounds = effectiveLocalBounds->applyingTransform(currentTransform);
        if (fuzzyGlobalRect) {
            fuzzyGlobalRect = fuzzyGlobalRect->unionWith(effectiveGlobalBounds);
        } else {
            fuzzyGlobalRect = effectiveGlobalBounds;
        }
    }
    
    if (subnodesGlobalRect) {
        if (fuzzyGlobalRect) {
            fuzzyGlobalRect = fuzzyGlobalRect->unionWith(subnodesGlobalRect.value());
        } else {
            fuzzyGlobalRect = subnodesGlobalRect;
        }
    }
    
    if (!fuzzyGlobalRect) {
        return nullptr;
    }
    
    CGRect globalRect(
        std::floor(fuzzyGlobalRect->x),
        std::floor(fuzzyGlobalRect->y),
        std::ceil(fuzzyGlobalRect->width + fuzzyGlobalRect->x - floor(fuzzyGlobalRect->x)),
        std::ceil(fuzzyGlobalRect->height + fuzzyGlobalRect->y - floor(fuzzyGlobalRect->y))
    );
    
    if (!CGRect(0.0, 0.0, globalSize.x, globalSize.y).intersects(globalRect)) {
        return nullptr;
    }
    
    if (masksToBounds && effectiveLocalBounds) {
        CGRect effectiveGlobalBounds = effectiveLocalBounds->applyingTransform(currentTransform);
        if (effectiveGlobalBounds.contains(CGRect(0.0, 0.0, globalSize.x, globalSize.y))) {
            masksToBounds = false;
        }
    }
    
    std::shared_ptr<OutputRenderNode> maskNode;
    if (node->mask()) {
        if (const auto maskNodeValue = convertRenderTree(node->mask(), globalSize, currentTransform, node->invertMask(), bezierPathsBoundingBoxContext)) {
            if (!maskNodeValue->globalRect.intersects(globalRect)) {
                return nullptr;
            }
            maskNode = maskNodeValue;
        } else {
            return nullptr;
        }
    }
    
    CGRect localRect = effectiveLocalRect.value_or(CGRect(0.0, 0.0, 0.0, 0.0)).applyingTransform(localTransform);
    
    return std::make_shared<OutputRenderNode>(
        OutputRenderNode::LayerParams(
            node->bounds(),
            node->position(),
            node->transform(),
            alpha,
            masksToBounds,
            node->isHidden()
        ),
        globalRect,
        localRect,
        currentTransform,
        effectiveLocalBounds.has_value(),
        node->content(),
        drawContentDescendants,
        isInvertedMatte,
        subnodes,
        maskNode
    );
}*/

}

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
    auto renderNode = _layer->renderTreeNode();
    if (!renderNode) {
        return nil;
    }
    
    if (size.width < 0.0) {
        return nil;
    }
    
    auto node = convertRenderTree(renderNode, lottie::Vector2D((int)size.width, (int)size.height), lottie::CATransform3D::identity().scaled(lottie::Vector2D(size.width / (double)_animation.size.width, size.height / (double)_animation.size.height)), false, *_bezierPathsBoundingBoxContext.get());
    
    if (node) {
        return [[LottieRenderNode alloc] initWithRenderNode:node];
    } else {
        node = std::make_shared<lottie::OutputRenderNode>(
            lottie::OutputRenderNode::LayerParams(
                lottie::CGRect(0.0, 0.0, size.width, size.height),
                lottie::Vector2D(0.0, 0.0),
                lottie::CATransform3D::identity(),
                1.0,
                false,
                false
            ),
            lottie::CGRect(0.0, 0.0, size.width, size.height),
            lottie::CGRect(0.0, 0.0, size.width, size.height),
            lottie::CATransform3D::identity(),
            false,
            nullptr,
            true,
            false,
            std::vector<std::shared_ptr<lottie::OutputRenderNode>>(),
            nullptr
        );
        return [[LottieRenderNode alloc] initWithRenderNode:node];
    }
}

@end

@implementation LottieAnimationContainer (Internal)

- (std::shared_ptr<lottie::MainThreadAnimationLayer>)layer {
    return _layer;
}

@end
