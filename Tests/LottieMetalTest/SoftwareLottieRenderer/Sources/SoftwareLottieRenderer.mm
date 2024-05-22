#import <SoftwareLottieRenderer/SoftwareLottieRenderer.h>

#import "Canvas.h"
#import "CoreGraphicsCanvasImpl.h"
#import "ThorVGCanvasImpl.h"
#import "NullCanvasImpl.h"

#include <LottieCpp/RenderTreeNode.h>

namespace {

static constexpr float minVisibleAlpha = 0.5f / 255.0f;

static constexpr float minGlobalRectCalculationSize = 200.0f;

struct TransformedPath {
    lottie::BezierPath path;
    lottie::Transform2D transform;
    
    TransformedPath(lottie::BezierPath const &path_, lottie::Transform2D const &transform_) :
    path(path_),
    transform(transform_) {
    }
};

static lottie::CGRect collectPathBoundingBoxes(std::shared_ptr<lottie::RenderTreeNodeContentItem> item, size_t subItemLimit, lottie::Transform2D const &parentTransform, bool skipApplyTransform, lottie::BezierPathsBoundingBoxContext &bezierPathsBoundingBoxContext) {
    //TODO:remove skipApplyTransform
    lottie::Transform2D effectiveTransform = parentTransform;
    if (!skipApplyTransform && item->isGroup) {
        effectiveTransform = item->transform * effectiveTransform;
    }
    
    size_t maxSubitem = std::min(item->subItems.size(), subItemLimit);
    
    lottie::CGRect boundingBox(0.0, 0.0, 0.0, 0.0);
    if (item->path) {
        if (item->path->needsBoundsRecalculation) {
            item->path->bounds = lottie::bezierPathsBoundingBoxParallel(bezierPathsBoundingBoxContext, item->path->path);
            item->path->needsBoundsRecalculation = false;
        }
        boundingBox = item->path->bounds.applyingTransform(effectiveTransform);
    }
    
    for (size_t i = 0; i < maxSubitem; i++) {
        auto &subItem = item->subItems[i];
        
        lottie::CGRect subItemBoundingBox = collectPathBoundingBoxes(subItem, INT32_MAX, effectiveTransform, false, bezierPathsBoundingBoxContext);
        
        if (boundingBox.empty()) {
            boundingBox = subItemBoundingBox;
        } else {
            boundingBox = boundingBox.unionWith(subItemBoundingBox);
        }
    }
    
    return boundingBox;
}

static void enumeratePaths(std::shared_ptr<lottie::RenderTreeNodeContentItem> item, size_t subItemLimit, lottie::Transform2D const &parentTransform, bool skipApplyTransform, std::function<void(lottie::BezierPath const &path, lottie::Transform2D const &transform)> const &onPath) {
    //TODO:remove skipApplyTransform
    lottie::Transform2D effectiveTransform = parentTransform;
    if (!skipApplyTransform && item->isGroup) {
        effectiveTransform = item->transform * effectiveTransform;
    }
    
    size_t maxSubitem = std::min(item->subItems.size(), subItemLimit);
    
    if (item->path) {
        onPath(item->path->path, effectiveTransform);
    }
    
    for (size_t i = 0; i < maxSubitem; i++) {
        auto &subItem = item->subItems[i];
        
        enumeratePaths(subItem, INT32_MAX, effectiveTransform, false, onPath);
    }
}

}

namespace lottie {

static std::optional<CGRect> getRenderContentItemGlobalRect(std::shared_ptr<RenderTreeNodeContentItem> const &contentItem, lottie::Vector2D const &globalSize, lottie::Transform2D const &parentTransform, BezierPathsBoundingBoxContext &bezierPathsBoundingBoxContext) {
    auto currentTransform = parentTransform;
    Transform2D localTransform = contentItem->transform;
    currentTransform = localTransform * currentTransform;
    
    std::optional<CGRect> globalRect;
    for (const auto &shadingVariant : contentItem->shadings) {
        lottie::CGRect shapeBounds = collectPathBoundingBoxes(contentItem, shadingVariant->subItemLimit, lottie::Transform2D::identity(), true, bezierPathsBoundingBoxContext);
        
        if (shadingVariant->stroke) {
            shapeBounds = shapeBounds.insetBy(-shadingVariant->stroke->lineWidth / 2.0, -shadingVariant->stroke->lineWidth / 2.0);
        } else if (shadingVariant->fill) {
        } else {
            continue;
        }
        
        CGRect shapeGlobalBounds = shapeBounds.applyingTransform(currentTransform);
        if (globalRect) {
            globalRect = globalRect->unionWith(shapeGlobalBounds);
        } else {
            globalRect = shapeGlobalBounds;
        }
    }
    
    for (const auto &subItem : contentItem->subItems) {
        auto subGlobalRect = getRenderContentItemGlobalRect(subItem, globalSize, currentTransform, bezierPathsBoundingBoxContext);
        if (subGlobalRect) {
            if (globalRect) {
                globalRect = globalRect->unionWith(subGlobalRect.value());
            } else {
                globalRect = subGlobalRect.value();
            }
        }
    }
    
    if (globalRect) {
        CGRect integralGlobalRect(
            std::floor(globalRect->x),
            std::floor(globalRect->y),
            std::ceil(globalRect->width + globalRect->x - floor(globalRect->x)),
            std::ceil(globalRect->height + globalRect->y - floor(globalRect->y))
        );
        return integralGlobalRect.intersection(CGRect(0.0, 0.0, globalSize.x, globalSize.y));
    } else {
        return std::nullopt;
    }
}

static std::optional<CGRect> getRenderNodeGlobalRect(std::shared_ptr<RenderTreeNode> const &node, lottie::Vector2D const &globalSize, lottie::Transform2D const &parentTransform, bool isInvertedMatte, BezierPathsBoundingBoxContext &bezierPathsBoundingBoxContext) {
    if (node->isHidden() || node->alpha() < minVisibleAlpha) {
        return std::nullopt;
    }
    
    auto currentTransform = parentTransform;
    Transform2D localTransform = node->transform();
    currentTransform = localTransform * currentTransform;
    
    std::optional<CGRect> globalRect;
    if (node->_contentItem) {
        globalRect = getRenderContentItemGlobalRect(node->_contentItem, globalSize, currentTransform, bezierPathsBoundingBoxContext);
    }
    
    if (isInvertedMatte) {
        CGRect globalBounds = CGRect(0.0f, 0.0f, node->size().x, node->size().y).applyingTransform(currentTransform);
        if (globalRect) {
            globalRect = globalRect->unionWith(globalBounds);
        } else {
            globalRect = globalBounds;
        }
    }
    
    for (const auto &subNode : node->subnodes()) {
        auto subGlobalRect = getRenderNodeGlobalRect(subNode, globalSize, currentTransform, false, bezierPathsBoundingBoxContext);
        if (subGlobalRect) {
            if (globalRect) {
                globalRect = globalRect->unionWith(subGlobalRect.value());
            } else {
                globalRect = subGlobalRect.value();
            }
        }
    }
    
    if (globalRect) {
        CGRect integralGlobalRect(
            std::floor(globalRect->x),
            std::floor(globalRect->y),
            std::ceil(globalRect->width + globalRect->x - floor(globalRect->x)),
            std::ceil(globalRect->height + globalRect->y - floor(globalRect->y))
        );
        return integralGlobalRect.intersection(CGRect(0.0, 0.0, globalSize.x, globalSize.y));
    } else {
        return std::nullopt;
    }
}

}

namespace {

static void drawLottieContentItem(std::shared_ptr<lottieRendering::Canvas> const &parentContext, std::shared_ptr<lottie::RenderTreeNodeContentItem> item, float parentAlpha, lottie::Vector2D const &globalSize, lottie::Transform2D const &parentTransform, lottie::BezierPathsBoundingBoxContext &bezierPathsBoundingBoxContext) {
    auto currentTransform = parentTransform;
    lottie::Transform2D localTransform = item->transform;
    currentTransform = localTransform * currentTransform;
    
    float normalizedOpacity = item->alpha;
    float layerAlpha = ((float)normalizedOpacity) * parentAlpha;
    
    if (normalizedOpacity == 0.0f) {
        return;
    }
    
    parentContext->saveState();
    
    std::shared_ptr<lottieRendering::Canvas> const *currentContext;
    std::shared_ptr<lottieRendering::Canvas> tempContext;
    
    bool needsTempContext = false;
    needsTempContext = layerAlpha != 1.0 && item->drawContentCount > 1;
    
    std::optional<lottie::CGRect> globalRect;
    if (needsTempContext) {
        if (globalSize.x <= minGlobalRectCalculationSize && globalSize.y <= minGlobalRectCalculationSize) {
            globalRect = lottie::CGRect(0.0, 0.0, globalSize.x, globalSize.y);
        } else {
            globalRect = lottie::getRenderContentItemGlobalRect(item, globalSize, parentTransform, bezierPathsBoundingBoxContext);
        }
        if (!globalRect || globalRect->width <= 0.0f || globalRect->height <= 0.0f) {
            parentContext->restoreState();
            return;
        }
        
        auto tempContextValue = parentContext->makeLayer((int)(globalRect->width), (int)(globalRect->height));
        tempContext = tempContextValue;
        
        currentContext = &tempContext;
        (*currentContext)->concatenate(lottie::Transform2D::identity().translated(lottie::Vector2D(-globalRect->x, -globalRect->y)));
        
        (*currentContext)->saveState();
        (*currentContext)->concatenate(currentTransform);
    } else {
        currentContext = &parentContext;
    }
    
    parentContext->concatenate(item->transform);
    
    float renderAlpha = 1.0;
    if (tempContext) {
        renderAlpha = 1.0;
    } else {
        renderAlpha = layerAlpha;
    }
    
    for (const auto &shading : item->shadings) {
        lottieRendering::CanvasPathEnumerator iteratePaths;
        if (shading->explicitPath) {
            auto itemPaths = shading->explicitPath.value();
            iteratePaths = [itemPaths = itemPaths](std::function<void(lottieRendering::PathCommand const &)> iterate) -> void {
                lottieRendering::PathCommand pathCommand;
                for (const auto &path : itemPaths) {
                    std::optional<lottie::PathElement> previousElement;
                    for (const auto &element : path.elements()) {
                        if (previousElement.has_value()) {
                            if (previousElement->vertex.outTangentRelative().isZero() && element.vertex.inTangentRelative().isZero()) {
                                pathCommand.type = lottieRendering::PathCommandType::LineTo;
                                pathCommand.points[0] = CGPointMake(element.vertex.point.x, element.vertex.point.y);
                                iterate(pathCommand);
                            } else {
                                pathCommand.type = lottieRendering::PathCommandType::CurveTo;
                                pathCommand.points[2] = CGPointMake(element.vertex.point.x, element.vertex.point.y);
                                pathCommand.points[1] = CGPointMake(element.vertex.inTangent.x, element.vertex.inTangent.y);
                                pathCommand.points[0] = CGPointMake(previousElement->vertex.outTangent.x, previousElement->vertex.outTangent.y);
                                iterate(pathCommand);
                            }
                        } else {
                            pathCommand.type = lottieRendering::PathCommandType::MoveTo;
                            pathCommand.points[0] = CGPointMake(element.vertex.point.x, element.vertex.point.y);
                            iterate(pathCommand);
                        }
                        previousElement = element;
                    }
                    if (path.closed().value_or(true)) {
                        pathCommand.type = lottieRendering::PathCommandType::Close;
                        iterate(pathCommand);
                    }
                }
            };
        } else {
            iteratePaths = [&](std::function<void(lottieRendering::PathCommand const &)> iterate) {
                enumeratePaths(item, shading->subItemLimit, lottie::Transform2D::identity(), true, [&](lottie::BezierPath const &sourcePath, lottie::Transform2D const &transform) {
                    auto path = sourcePath.copyUsingTransform(transform);
                    
                    lottieRendering::PathCommand pathCommand;
                    std::optional<lottie::PathElement> previousElement;
                    for (const auto &element : path.elements()) {
                        if (previousElement.has_value()) {
                            if (previousElement->vertex.outTangentRelative().isZero() && element.vertex.inTangentRelative().isZero()) {
                                pathCommand.type = lottieRendering::PathCommandType::LineTo;
                                pathCommand.points[0] = CGPointMake(element.vertex.point.x, element.vertex.point.y);
                                iterate(pathCommand);
                            } else {
                                pathCommand.type = lottieRendering::PathCommandType::CurveTo;
                                pathCommand.points[2] = CGPointMake(element.vertex.point.x, element.vertex.point.y);
                                pathCommand.points[1] = CGPointMake(element.vertex.inTangent.x, element.vertex.inTangent.y);
                                pathCommand.points[0] = CGPointMake(previousElement->vertex.outTangent.x, previousElement->vertex.outTangent.y);
                                iterate(pathCommand);
                            }
                        } else {
                            pathCommand.type = lottieRendering::PathCommandType::MoveTo;
                            pathCommand.points[0] = CGPointMake(element.vertex.point.x, element.vertex.point.y);
                            iterate(pathCommand);
                        }
                        previousElement = element;
                    }
                    if (path.closed().value_or(true)) {
                        pathCommand.type = lottieRendering::PathCommandType::Close;
                        iterate(pathCommand);
                    }
                });
            };
        }
        
        /*auto iteratePaths = [&](std::function<void(lottieRendering::PathCommand const &)> iterate) -> void {
            lottieRendering::PathCommand pathCommand;
            for (const auto &path : itemPaths) {
                std::optional<lottie::PathElement> previousElement;
                for (const auto &element : path.elements()) {
                    if (previousElement.has_value()) {
                        if (previousElement->vertex.outTangentRelative().isZero() && element.vertex.inTangentRelative().isZero()) {
                            pathCommand.type = lottieRendering::PathCommandType::LineTo;
                            pathCommand.points[0] = CGPointMake(element.vertex.point.x, element.vertex.point.y);
                            iterate(pathCommand);
                        } else {
                            pathCommand.type = lottieRendering::PathCommandType::CurveTo;
                            pathCommand.points[2] = CGPointMake(element.vertex.point.x, element.vertex.point.y);
                            pathCommand.points[1] = CGPointMake(element.vertex.inTangent.x, element.vertex.inTangent.y);
                            pathCommand.points[0] = CGPointMake(previousElement->vertex.outTangent.x, previousElement->vertex.outTangent.y);
                            iterate(pathCommand);
                        }
                    } else {
                        pathCommand.type = lottieRendering::PathCommandType::MoveTo;
                        pathCommand.points[0] = CGPointMake(element.vertex.point.x, element.vertex.point.y);
                        iterate(pathCommand);
                    }
                    previousElement = element;
                }
                if (path.closed().value_or(true)) {
                    pathCommand.type = lottieRendering::PathCommandType::Close;
                    iterate(pathCommand);
                }
            }
        };*/
        
        if (shading->stroke) {
            if (shading->stroke->shading->type() == lottie::RenderTreeNodeContentItem::ShadingType::Solid) {
                lottie::RenderTreeNodeContentItem::SolidShading *solidShading = (lottie::RenderTreeNodeContentItem::SolidShading *)shading->stroke->shading.get();
                
                if (solidShading->opacity != 0.0) {
                    lottie::LineJoin lineJoin = lottie::LineJoin::Bevel;
                    switch (shading->stroke->lineJoin) {
                        case lottie::LineJoin::Bevel: {
                            lineJoin = lottie::LineJoin::Bevel;
                            break;
                        }
                        case lottie::LineJoin::Round: {
                            lineJoin = lottie::LineJoin::Round;
                            break;
                        }
                        case lottie::LineJoin::Miter: {
                            lineJoin = lottie::LineJoin::Miter;
                            break;
                        }
                        default: {
                            break;
                        }
                    }
                    
                    lottie::LineCap lineCap = lottie::LineCap::Square;
                    switch (shading->stroke->lineCap) {
                        case lottie::LineCap::Butt: {
                            lineCap = lottie::LineCap::Butt;
                            break;
                        }
                        case lottie::LineCap::Round: {
                            lineCap = lottie::LineCap::Round;
                            break;
                        }
                        case lottie::LineCap::Square: {
                            lineCap = lottie::LineCap::Square;
                            break;
                        }
                        default: {
                            break;
                        }
                    }
                    
                    std::vector<float> dashPattern;
                    if (!shading->stroke->dashPattern.empty()) {
                        dashPattern = shading->stroke->dashPattern;
                    }
                    
                    (*currentContext)->strokePath(iteratePaths, shading->stroke->lineWidth, lineJoin, lineCap, shading->stroke->dashPhase, dashPattern, lottie::Color(solidShading->color.r, solidShading->color.g, solidShading->color.b, solidShading->color.a * solidShading->opacity * renderAlpha));
                } else if (shading->stroke->shading->type() == lottie::RenderTreeNodeContentItem::ShadingType::Gradient) {
                    //TODO:gradient stroke
                }
            }
        } else if (shading->fill) {
            lottie::FillRule rule = lottie::FillRule::NonZeroWinding;
            switch (shading->fill->rule) {
                case lottie::FillRule::EvenOdd: {
                    rule = lottie::FillRule::EvenOdd;
                    break;
                }
                case lottie::FillRule::NonZeroWinding: {
                    rule = lottie::FillRule::NonZeroWinding;
                    break;
                }
                default: {
                    break;
                }
            }
            
            if (shading->fill->shading->type() == lottie::RenderTreeNodeContentItem::ShadingType::Solid) {
                lottie::RenderTreeNodeContentItem::SolidShading *solidShading = (lottie::RenderTreeNodeContentItem::SolidShading *)shading->fill->shading.get();
                if (solidShading->opacity != 0.0) {
                    (*currentContext)->fillPath(iteratePaths, rule, lottie::Color(solidShading->color.r, solidShading->color.g, solidShading->color.b, solidShading->color.a * solidShading->opacity * renderAlpha));
                }
            } else if (shading->fill->shading->type() == lottie::RenderTreeNodeContentItem::ShadingType::Gradient) {
                lottie::RenderTreeNodeContentItem::GradientShading *gradientShading = (lottie::RenderTreeNodeContentItem::GradientShading *)shading->fill->shading.get();
                
                if (gradientShading->opacity != 0.0) {
                    std::vector<lottie::Color> colors;
                    std::vector<float> locations;
                    for (const auto &color : gradientShading->colors) {
                        colors.push_back(lottie::Color(color.r, color.g, color.b, color.a * gradientShading->opacity * renderAlpha));
                    }
                    locations = gradientShading->locations;
                    
                    lottieRendering::Gradient gradient(colors, locations);
                    lottie::Vector2D start(gradientShading->start.x, gradientShading->start.y);
                    lottie::Vector2D end(gradientShading->end.x, gradientShading->end.y);
                    
                    switch (gradientShading->gradientType) {
                        case lottie::GradientType::Linear: {
                            (*currentContext)->linearGradientFillPath(iteratePaths, rule, gradient, start, end);
                            break;
                        }
                        case lottie::GradientType::Radial: {
                            (*currentContext)->radialGradientFillPath(iteratePaths, rule, gradient, start, 0.0, start, start.distanceTo(end));
                            break;
                        }
                        default: {
                            break;
                        }
                    }
                }
            }
        }
    }
    
    for (auto it = item->subItems.rbegin(); it != item->subItems.rend(); it++) {
        const auto &subItem = *it;
        drawLottieContentItem(*currentContext, subItem, renderAlpha, globalSize, currentTransform, bezierPathsBoundingBoxContext);
    }
    
    if (tempContext) {
        tempContext->restoreState();
        
        parentContext->concatenate(currentTransform.inverted());
        parentContext->setAlpha(layerAlpha);
        parentContext->draw(tempContext, globalRect.value());
        parentContext->setAlpha(1.0);
    }
    
    parentContext->restoreState();
}

static void renderLottieRenderNode(std::shared_ptr<lottie::RenderTreeNode> node, std::shared_ptr<lottieRendering::Canvas> const &parentContext, lottie::Vector2D const &globalSize, lottie::Transform2D const &parentTransform, float parentAlpha, bool isInvertedMatte, lottie::BezierPathsBoundingBoxContext &bezierPathsBoundingBoxContext) {
    float normalizedOpacity = node->alpha();
    float layerAlpha = ((float)normalizedOpacity) * parentAlpha;
    
    if (node->isHidden() || normalizedOpacity < minVisibleAlpha) {
        return;
    }
    
    auto currentTransform = parentTransform;
    lottie::Transform2D localTransform = node->transform();
    currentTransform = localTransform * currentTransform;
    
    std::shared_ptr<lottieRendering::Canvas> maskContext;
    std::shared_ptr<lottieRendering::Canvas> currentContext;
    std::shared_ptr<lottieRendering::Canvas> tempContext;
    
    bool masksToBounds = node->masksToBounds();
    if (masksToBounds) {
        lottie::CGRect effectiveGlobalBounds = lottie::CGRect(0.0f, 0.0f, node->size().x, node->size().y).applyingTransform(currentTransform);
        if (effectiveGlobalBounds.width <= 0.0f || effectiveGlobalBounds.height <= 0.0f) {
            return;
        }
        if (effectiveGlobalBounds.contains(lottie::CGRect(0.0, 0.0, globalSize.x, globalSize.y))) {
            masksToBounds = false;
        }
    }
    
    parentContext->saveState();
    
    bool needsTempContext = false;
    if (node->mask() && !node->mask()->isHidden() && node->mask()->alpha() >= minVisibleAlpha) {
        needsTempContext = true;
    } else {
        needsTempContext = layerAlpha != 1.0 || masksToBounds;
    }
    
    std::optional<lottie::CGRect> globalRect;
    if (needsTempContext) {
        if (globalSize.x <= minGlobalRectCalculationSize && globalSize.y <= minGlobalRectCalculationSize) {
            globalRect = lottie::CGRect(0.0, 0.0, globalSize.x, globalSize.y);
        } else {
            globalRect = lottie::getRenderNodeGlobalRect(node, globalSize, parentTransform, false, bezierPathsBoundingBoxContext);
        }
        if (!globalRect || globalRect->width <= 0.0f || globalRect->height <= 0.0f) {
            parentContext->restoreState();
            return;
        }
        
        if ((node->mask() && !node->mask()->isHidden() && node->mask()->alpha() >= minVisibleAlpha) || masksToBounds) {
            auto maskBackingStorage = parentContext->makeLayer((int)(globalRect->width), (int)(globalRect->height));
            
            maskBackingStorage->concatenate(lottie::Transform2D::identity().translated(lottie::Vector2D(-globalRect->x, -globalRect->y)));
            maskBackingStorage->concatenate(currentTransform);
            
            if (masksToBounds) {
                maskBackingStorage->fill(lottie::CGRect(0.0f, 0.0f, node->size().x, node->size().y), lottie::Color(1.0f, 1.0f, 1.0f, 1.0f));
            }
            if (node->mask() && !node->mask()->isHidden() && node->mask()->alpha() >= minVisibleAlpha) {
                renderLottieRenderNode(node->mask(), maskBackingStorage, globalSize, currentTransform, 1.0, node->invertMask(), bezierPathsBoundingBoxContext);
            }
            
            maskContext = maskBackingStorage;
        }
        
        auto tempContextValue = parentContext->makeLayer((int)(globalRect->width), (int)(globalRect->height));
        tempContext = tempContextValue;
        
        currentContext = tempContextValue;
        currentContext->concatenate(lottie::Transform2D::identity().translated(lottie::Vector2D(-globalRect->x, -globalRect->y)));
        
        currentContext->saveState();
        currentContext->concatenate(currentTransform);
    } else {
        currentContext = parentContext;
    }
    
    parentContext->concatenate(node->transform());
    
    float renderAlpha = 1.0f;
    if (tempContext) {
        renderAlpha = 1.0f;
    } else {
        renderAlpha = layerAlpha;
    }
    
    if (node->_contentItem) {
        drawLottieContentItem(currentContext, node->_contentItem, renderAlpha, globalSize, currentTransform, bezierPathsBoundingBoxContext);
    }
    
    if (isInvertedMatte) {
        currentContext->fill(lottie::CGRect(0.0f, 0.0f, node->size().x, node->size().y), lottie::Color(0.0f, 0.0f, 0.0f, 1.0f));
        currentContext->setBlendMode(lottieRendering::BlendMode::DestinationOut);
    }
    
    for (const auto &subnode : node->subnodes()) {
        renderLottieRenderNode(subnode, currentContext, globalSize, currentTransform, renderAlpha, false, bezierPathsBoundingBoxContext);
    }
    
    if (tempContext) {
        tempContext->restoreState();
        
        if (maskContext) {
            tempContext->setBlendMode(lottieRendering::BlendMode::DestinationIn);
            tempContext->draw(maskContext, lottie::CGRect(globalRect->x, globalRect->y, globalRect->width, globalRect->height));
        }
        
        parentContext->concatenate(currentTransform.inverted());
        parentContext->setAlpha(layerAlpha);
        parentContext->draw(tempContext, globalRect.value());
    }
    
    parentContext->restoreState();
}

}

CGRect getPathNativeBoundingBox(CGPathRef _Nonnull path) {
    auto rect = calculatePathBoundingBox(path);
    return CGRectMake(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
}

@interface SoftwareLottieRenderer() {
    LottieAnimationContainer *_animationContainer;
    std::shared_ptr<lottie::BezierPathsBoundingBoxContext> _bezierPathsBoundingBoxContext;
}

@end

@implementation SoftwareLottieRenderer

- (instancetype _Nonnull)initWithAnimationContainer:(LottieAnimationContainer * _Nonnull)animationContainer {
    self = [super init];
    if (self != nil) {
        _animationContainer = animationContainer;
        _bezierPathsBoundingBoxContext = std::make_shared<lottie::BezierPathsBoundingBoxContext>();
    }
    return self;
}

- (UIImage * _Nullable)renderForSize:(CGSize)size useReferenceRendering:(bool)useReferenceRendering {
    LottieAnimation *animation = _animationContainer.animation;
    std::shared_ptr<lottie::RenderTreeNode> renderNode = [_animationContainer internalGetRootRenderTreeNode];
    if (!renderNode) {
        return nil;
    }
    
    lottie::Transform2D rootTransform = lottie::Transform2D::identity().scaled(lottie::Vector2D(size.width / (float)animation.size.width, size.height / (float)animation.size.height));
    
    if (useReferenceRendering) {
        auto context = std::make_shared<lottieRendering::CanvasImpl>((int)size.width, (int)size.height);
        
        CGPoint scale = CGPointMake(size.width / (CGFloat)animation.size.width, size.height / (CGFloat)animation.size.height);
        context->concatenate(lottie::Transform2D::makeScale(scale.x, scale.y));
        
        renderLottieRenderNode(renderNode, context, lottie::Vector2D(context->width(), context->height()), rootTransform, 1.0, false, *_bezierPathsBoundingBoxContext.get());
        
        auto image = context->makeImage();
        
        return [[UIImage alloc] initWithCGImage:std::static_pointer_cast<lottieRendering::ImageImpl>(image)->nativeImage()];
    } else {
        //auto context = std::make_shared<lottieRendering::ThorVGCanvasImpl>((int)size.width, (int)size.height);
        auto context = std::make_shared<lottieRendering::NullCanvasImpl>((int)size.width, (int)size.height);
        
        CGPoint scale = CGPointMake(size.width / (CGFloat)animation.size.width, size.height / (CGFloat)animation.size.height);
        context->concatenate(lottie::Transform2D::makeScale(scale.x, scale.y));
        
        //renderLottieRenderNode(renderNode, context, lottie::Vector2D(context->width(), context->height()), rootTransform, 1.0, false, *_bezierPathsBoundingBoxContext.get());
        
        return nil;
    }
}

@end
