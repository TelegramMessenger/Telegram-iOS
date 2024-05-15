#import <SoftwareLottieRenderer/SoftwareLottieRenderer.h>

#import "Canvas.h"
#import "CoreGraphicsCanvasImpl.h"
#import "ThorVGCanvasImpl.h"

#include <LottieCpp/RenderTreeNode.h>

namespace lottie {

static void processRenderContentItem(std::shared_ptr<RenderTreeNodeContentItem> const &contentItem, Vector2D const &globalSize, CATransform3D const &parentTransform, BezierPathsBoundingBoxContext &bezierPathsBoundingBoxContext) {
    auto currentTransform = parentTransform;
    
    CATransform3D localTransform = contentItem->transform;
    currentTransform = localTransform * currentTransform;
    
    if (!currentTransform.isInvertible()) {
        contentItem->renderData.isValid = false;
        return;
    }
    
    std::optional<CGRect> effectiveLocalBounds;
    
    int drawContentDescendants = 0;
    
    for (const auto &shadingVariant : contentItem->shadings) {
        drawContentDescendants += 1;
        
        CGRect shapeBounds = bezierPathsBoundingBoxParallel(bezierPathsBoundingBoxContext, shadingVariant->explicitPath.value());
        if (shadingVariant->stroke) {
            shapeBounds = shapeBounds.insetBy(-shadingVariant->stroke->lineWidth / 2.0, -shadingVariant->stroke->lineWidth / 2.0);
            if (effectiveLocalBounds) {
                effectiveLocalBounds = effectiveLocalBounds->unionWith(shapeBounds);
            } else {
                effectiveLocalBounds = shapeBounds;
            }
        } else if (shadingVariant->fill) {
            if (effectiveLocalBounds) {
                effectiveLocalBounds = effectiveLocalBounds->unionWith(shapeBounds);
            } else {
                effectiveLocalBounds = shapeBounds;
            }
        }
    }
    
    std::optional<CGRect> effectiveLocalRect;
    if (effectiveLocalBounds.has_value()) {
        effectiveLocalRect = effectiveLocalBounds;
    }
    
    std::optional<CGRect> subnodesGlobalRect;
    
    for (const auto &subItem : contentItem->subItems) {
        processRenderContentItem(subItem, globalSize, currentTransform, bezierPathsBoundingBoxContext);
        
        drawContentDescendants += subItem->renderData.drawContentDescendants;
        
        if (!subItem->renderData.localRect.empty()) {
            if (effectiveLocalRect.has_value()) {
                effectiveLocalRect = effectiveLocalRect->unionWith(subItem->renderData.localRect);
            } else {
                effectiveLocalRect = subItem->renderData.localRect;
            }
        }
        
        if (subnodesGlobalRect) {
            subnodesGlobalRect = subnodesGlobalRect->unionWith(subItem->renderData.globalRect);
        } else {
            subnodesGlobalRect = subItem->renderData.globalRect;
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
        contentItem->renderData.isValid = false;
        return;
    }
    
    CGRect globalRect(
        std::floor(fuzzyGlobalRect->x),
        std::floor(fuzzyGlobalRect->y),
        std::ceil(fuzzyGlobalRect->width + fuzzyGlobalRect->x - floor(fuzzyGlobalRect->x)),
        std::ceil(fuzzyGlobalRect->height + fuzzyGlobalRect->y - floor(fuzzyGlobalRect->y))
    );
    
    if (!CGRect(0.0, 0.0, globalSize.x, globalSize.y).intersects(globalRect)) {
        contentItem->renderData.isValid = false;
        return;
    }
    
    CGRect localRect = effectiveLocalRect.value_or(CGRect(0.0, 0.0, 0.0, 0.0)).applyingTransform(localTransform);
    
    contentItem->renderData.isValid = true;
    
    contentItem->renderData.layer._bounds = CGRect(0.0, 0.0, 0.0, 0.0);
    contentItem->renderData.layer._position = Vector2D(0.0, 0.0);
    contentItem->renderData.layer._transform = contentItem->transform;
    contentItem->renderData.layer._opacity = contentItem->alpha;
    contentItem->renderData.layer._masksToBounds = false;
    contentItem->renderData.layer._isHidden = false;
    
    contentItem->renderData.globalRect = globalRect;
    contentItem->renderData.localRect = localRect;
    contentItem->renderData.globalTransform = currentTransform;
    contentItem->renderData.drawsContent = effectiveLocalBounds.has_value();
    contentItem->renderData.drawContentDescendants = drawContentDescendants;
    contentItem->renderData.isInvertedMatte = false;
}

static void processRenderTree(std::shared_ptr<RenderTreeNode> const &node, Vector2D const &globalSize, CATransform3D const &parentTransform, bool isInvertedMask, BezierPathsBoundingBoxContext &bezierPathsBoundingBoxContext) {
    if (node->isHidden() || node->alpha() == 0.0f) {
        node->renderData.isValid = false;
        return;
    }
    
    if (node->masksToBounds()) {
        if (node->bounds().empty()) {
            node->renderData.isValid = false;
            return;
        }
    }
    
    auto currentTransform = parentTransform;
    
    Vector2D localTranslation(node->position().x + -node->bounds().x, node->position().y + -node->bounds().y);
    CATransform3D localTransform = node->transform();
    localTransform = localTransform.translated(localTranslation);
    
    currentTransform = localTransform * currentTransform;
    
    if (!currentTransform.isInvertible()) {
        node->renderData.isValid = false;
        return;
    }
    
    if (node->_contentItem) {
        processRenderContentItem(node->_contentItem, globalSize, currentTransform, bezierPathsBoundingBoxContext);
    }
    
    std::optional<CGRect> effectiveLocalBounds;
    
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
    
    std::optional<CGRect> subnodesGlobalRect;
    bool masksToBounds = node->masksToBounds();
    
    int drawContentDescendants = 0;
    
    for (const auto &item : node->subnodes()) {
        processRenderTree(item, globalSize, currentTransform, false, bezierPathsBoundingBoxContext);
        if (item->renderData.isValid) {
            drawContentDescendants += item->renderData.drawContentDescendants;
            
            if (item->_contentItem) {
                drawContentDescendants += 1;
            }
            
            if (!item->renderData.localRect.empty()) {
                if (effectiveLocalRect.has_value()) {
                    effectiveLocalRect = effectiveLocalRect->unionWith(item->renderData.localRect);
                } else {
                    effectiveLocalRect = item->renderData.localRect;
                }
            }
            
            if (subnodesGlobalRect) {
                subnodesGlobalRect = subnodesGlobalRect->unionWith(item->renderData.globalRect);
            } else {
                subnodesGlobalRect = item->renderData.globalRect;
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
        node->renderData.isValid = false;
        return;
    }
    
    CGRect globalRect(
        std::floor(fuzzyGlobalRect->x),
        std::floor(fuzzyGlobalRect->y),
        std::ceil(fuzzyGlobalRect->width + fuzzyGlobalRect->x - floor(fuzzyGlobalRect->x)),
        std::ceil(fuzzyGlobalRect->height + fuzzyGlobalRect->y - floor(fuzzyGlobalRect->y))
    );
    
    if (!CGRect(0.0, 0.0, globalSize.x, globalSize.y).intersects(globalRect)) {
        node->renderData.isValid = false;
        return;
    }
    
    if (masksToBounds && effectiveLocalBounds) {
        CGRect effectiveGlobalBounds = effectiveLocalBounds->applyingTransform(currentTransform);
        if (effectiveGlobalBounds.contains(CGRect(0.0, 0.0, globalSize.x, globalSize.y))) {
            masksToBounds = false;
        }
    }
    
    if (node->mask()) {
        processRenderTree(node->mask(), globalSize, currentTransform, node->invertMask(), bezierPathsBoundingBoxContext);
        if (node->mask()->renderData.isValid) {
            if (!node->mask()->renderData.globalRect.intersects(globalRect)) {
                node->renderData.isValid = false;
                return;
            }
        } else {
            node->renderData.isValid = false;
            return;
        }
    }
    
    CGRect localRect = effectiveLocalRect.value_or(CGRect(0.0, 0.0, 0.0, 0.0)).applyingTransform(localTransform);
    
    node->renderData.isValid = true;
    
    node->renderData.layer._bounds = node->bounds();
    node->renderData.layer._position = node->position();
    node->renderData.layer._transform = node->transform();
    node->renderData.layer._opacity = node->alpha();
    node->renderData.layer._masksToBounds = masksToBounds;
    node->renderData.layer._isHidden = node->isHidden();
    
    node->renderData.globalRect = globalRect;
    node->renderData.localRect = localRect;
    node->renderData.globalTransform = currentTransform;
    node->renderData.drawsContent = effectiveLocalBounds.has_value();
    node->renderData.drawContentDescendants = drawContentDescendants;
    node->renderData.isInvertedMatte = isInvertedMatte;
}

}

namespace {

static void drawLottieContentItem(std::shared_ptr<lottieRendering::Canvas> context, std::shared_ptr<lottie::RenderTreeNodeContentItem> item) {
    context->saveState();
    context->concatenate(item->transform);
    
    for (const auto &shading : item->shadings) {
        if (shading->explicitPath->empty()) {
            continue;
        }
        
        std::shared_ptr<lottie::CGPath> path = lottie::CGPath::makePath();
        
        const auto iterate = [&](LottiePathItem const *pathItem) {
            switch (pathItem->type) {
                case LottiePathItemTypeMoveTo: {
                    path->moveTo(lottie::Vector2D(pathItem->points[0].x, pathItem->points[0].y));
                    break;
                }
                case LottiePathItemTypeLineTo: {
                    path->addLineTo(lottie::Vector2D(pathItem->points[0].x, pathItem->points[0].y));
                    break;
                }
                case LottiePathItemTypeCurveTo: {
                    path->addCurveTo(lottie::Vector2D(pathItem->points[2].x, pathItem->points[2].y), lottie::Vector2D(pathItem->points[0].x, pathItem->points[0].y), lottie::Vector2D(pathItem->points[1].x, pathItem->points[1].y));
                    break;
                }
                case LottiePathItemTypeClose: {
                    path->closeSubpath();
                    break;
                }
                default: {
                    break;
                }
            }
        };
        
        LottiePathItem pathItem;
        for (const auto &path : shading->explicitPath.value()) {
            std::optional<lottie::PathElement> previousElement;
            for (const auto &element : path.elements()) {
                if (previousElement.has_value()) {
                    if (previousElement->vertex.outTangentRelative().isZero() && element.vertex.inTangentRelative().isZero()) {
                        pathItem.type = LottiePathItemTypeLineTo;
                        pathItem.points[0] = CGPointMake(element.vertex.point.x, element.vertex.point.y);
                        iterate(&pathItem);
                    } else {
                        pathItem.type = LottiePathItemTypeCurveTo;
                        pathItem.points[2] = CGPointMake(element.vertex.point.x, element.vertex.point.y);
                        pathItem.points[1] = CGPointMake(element.vertex.inTangent.x, element.vertex.inTangent.y);
                        pathItem.points[0] = CGPointMake(previousElement->vertex.outTangent.x, previousElement->vertex.outTangent.y);
                        iterate(&pathItem);
                    }
                } else {
                    pathItem.type = LottiePathItemTypeMoveTo;
                    pathItem.points[0] = CGPointMake(element.vertex.point.x, element.vertex.point.y);
                    iterate(&pathItem);
                }
                previousElement = element;
            }
            if (path.closed().value_or(true)) {
                pathItem.type = LottiePathItemTypeClose;
                iterate(&pathItem);
            }
        }
        
        if (shading->stroke) {
            if (shading->stroke->shading->type() == lottie::RenderTreeNodeContentItem::ShadingType::Solid) {
                lottie::RenderTreeNodeContentItem::SolidShading *solidShading = (lottie::RenderTreeNodeContentItem::SolidShading *)shading->stroke->shading.get();
                
                if (solidShading->opacity != 0.0) {
                    lottieRendering::LineJoin lineJoin = lottieRendering::LineJoin::Bevel;
                    switch (shading->stroke->lineJoin) {
                        case lottie::LineJoin::Bevel: {
                            lineJoin = lottieRendering::LineJoin::Bevel;
                            break;
                        }
                        case lottie::LineJoin::Round: {
                            lineJoin = lottieRendering::LineJoin::Round;
                            break;
                        }
                        case lottie::LineJoin::Miter: {
                            lineJoin = lottieRendering::LineJoin::Miter;
                            break;
                        }
                        default: {
                            break;
                        }
                    }
                    
                    lottieRendering::LineCap lineCap = lottieRendering::LineCap::Square;
                    switch (shading->stroke->lineCap) {
                        case lottie::LineCap::Butt: {
                            lineCap = lottieRendering::LineCap::Butt;
                            break;
                        }
                        case lottie::LineCap::Round: {
                            lineCap = lottieRendering::LineCap::Round;
                            break;
                        }
                        case lottie::LineCap::Square: {
                            lineCap = lottieRendering::LineCap::Square;
                            break;
                        }
                        default: {
                            break;
                        }
                    }
                    
                    std::vector<double> dashPattern;
                    if (!shading->stroke->dashPattern.empty()) {
                        dashPattern = shading->stroke->dashPattern;
                    }
                    
                    context->strokePath(path, shading->stroke->lineWidth, lineJoin, lineCap, shading->stroke->dashPhase, dashPattern, lottieRendering::Color(solidShading->color.r, solidShading->color.g, solidShading->color.b, solidShading->color.a * solidShading->opacity));
                } else if (shading->stroke->shading->type() == lottie::RenderTreeNodeContentItem::ShadingType::Gradient) {
                    //TODO:gradient stroke
                }
            }
        } else if (shading->fill) {
            lottieRendering::FillRule rule = lottieRendering::FillRule::NonZeroWinding;
            switch (shading->fill->rule) {
                case lottie::FillRule::EvenOdd: {
                    rule = lottieRendering::FillRule::EvenOdd;
                    break;
                }
                case lottie::FillRule::NonZeroWinding: {
                    rule = lottieRendering::FillRule::NonZeroWinding;
                    break;
                }
                default: {
                    break;
                }
            }
            
            if (shading->fill->shading->type() == lottie::RenderTreeNodeContentItem::ShadingType::Solid) {
                lottie::RenderTreeNodeContentItem::SolidShading *solidShading = (lottie::RenderTreeNodeContentItem::SolidShading *)shading->fill->shading.get();
                if (solidShading->opacity != 0.0) {
                    context->fillPath(path, rule, lottieRendering::Color(solidShading->color.r, solidShading->color.g, solidShading->color.b, solidShading->color.a * solidShading->opacity));
                }
            } else if (shading->fill->shading->type() == lottie::RenderTreeNodeContentItem::ShadingType::Gradient) {
                lottie::RenderTreeNodeContentItem::GradientShading *gradientShading = (lottie::RenderTreeNodeContentItem::GradientShading *)shading->fill->shading.get();
                
                if (gradientShading->opacity != 0.0) {
                    std::vector<lottieRendering::Color> colors;
                    std::vector<double> locations;
                    for (const auto &color : gradientShading->colors) {
                        colors.push_back(lottieRendering::Color(color.r, color.g, color.b, color.a * gradientShading->opacity));
                    }
                    locations = gradientShading->locations;
                    
                    lottieRendering::Gradient gradient(colors, locations);
                    lottie::Vector2D start(gradientShading->start.x, gradientShading->start.y);
                    lottie::Vector2D end(gradientShading->end.x, gradientShading->end.y);
                    
                    switch (gradientShading->gradientType) {
                        case lottie::GradientType::Linear: {
                            context->linearGradientFillPath(path, rule, gradient, start, end);
                            break;
                        }
                        case lottie::GradientType::Radial: {
                            context->radialGradientFillPath(path, rule, gradient, start, 0.0, start, start.distanceTo(end));
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
    
    for (const auto &subItem : item->subItems) {
        drawLottieContentItem(context, subItem);
    }
    
    context->restoreState();
}

static void renderLottieRenderNode(std::shared_ptr<lottie::RenderTreeNode> node, std::shared_ptr<lottieRendering::Canvas> parentContext, lottie::Vector2D const &globalSize, double parentAlpha) {
    if (!node->renderData.isValid) {
        return;
    }
    float normalizedOpacity = node->renderData.layer.opacity();
    double layerAlpha = ((double)normalizedOpacity) * parentAlpha;
    
    if (node->renderData.layer.isHidden() || normalizedOpacity == 0.0f) {
        return;
    }
    
    parentContext->saveState();
    
    std::shared_ptr<lottieRendering::Canvas> maskContext;
    std::shared_ptr<lottieRendering::Canvas> currentContext;
    std::shared_ptr<lottieRendering::Canvas> tempContext;
    
    bool needsTempContext = false;
    if (node->mask() && node->mask()->renderData.isValid) {
        needsTempContext = true;
    } else {
        needsTempContext = layerAlpha != 1.0 || node->renderData.layer.masksToBounds();
    }
    
    if (needsTempContext) {
        if ((node->mask() && node->mask()->renderData.isValid) || node->renderData.layer.masksToBounds()) {
            auto maskBackingStorage = parentContext->makeLayer((int)(node->renderData.globalRect.width), (int)(node->renderData.globalRect.height));
            
            maskBackingStorage->concatenate(lottie::CATransform3D::identity().translated(lottie::Vector2D(-node->renderData.globalRect.x, -node->renderData.globalRect.y)));
            maskBackingStorage->concatenate(node->renderData.globalTransform);
            
            if (node->renderData.layer.masksToBounds()) {
                maskBackingStorage->fill(lottie::CGRect(node->renderData.layer.bounds().x, node->renderData.layer.bounds().y, node->renderData.layer.bounds().width, node->renderData.layer.bounds().height), lottieRendering::Color(1.0, 1.0, 1.0, 1.0));
            }
            if (node->mask() && node->mask()->renderData.isValid) {
                renderLottieRenderNode(node->mask(), maskBackingStorage, globalSize, 1.0);
            }
            
            maskContext = maskBackingStorage;
        }
        
        auto tempContextValue = parentContext->makeLayer((int)(node->renderData.globalRect.width), (int)(node->renderData.globalRect.height));
        tempContext = tempContextValue;
        
        currentContext = tempContextValue;
        currentContext->concatenate(lottie::CATransform3D::identity().translated(lottie::Vector2D(-node->renderData.globalRect.x, -node->renderData.globalRect.y)));
        
        currentContext->saveState();
        currentContext->concatenate(node->renderData.globalTransform);
    } else {
        currentContext = parentContext;
    }
    
    parentContext->concatenate(lottie::CATransform3D::identity().translated(lottie::Vector2D(node->renderData.layer.position().x, node->renderData.layer.position().y)));
    parentContext->concatenate(lottie::CATransform3D::identity().translated(lottie::Vector2D(-node->renderData.layer.bounds().x, -node->renderData.layer.bounds().y)));
    parentContext->concatenate(node->renderData.layer.transform());
    
    double renderAlpha = 1.0;
    if (tempContext) {
        renderAlpha = 1.0;
    } else {
        renderAlpha = layerAlpha;
    }
    
    currentContext->setAlpha(renderAlpha);
    
    if (node->_contentItem) {
        drawLottieContentItem(currentContext, node->_contentItem);
    }
    
    if (node->renderData.isInvertedMatte) {
        currentContext->fill(lottie::CGRect(node->renderData.layer.bounds().x, node->renderData.layer.bounds().y, node->renderData.layer.bounds().width, node->renderData.layer.bounds().height), lottieRendering::Color(0.0, 0.0, 0.0, 1.0));
        currentContext->setBlendMode(lottieRendering::BlendMode::DestinationOut);
    }
    
    for (const auto &subnode : node->subnodes()) {
        if (subnode->renderData.isValid) {
            renderLottieRenderNode(subnode, currentContext, globalSize, renderAlpha);
        }
    }
    
    if (tempContext) {
        tempContext->restoreState();
        
        if (maskContext) {
            tempContext->setBlendMode(lottieRendering::BlendMode::DestinationIn);
            tempContext->draw(maskContext, lottie::CGRect(node->renderData.globalRect.x, node->renderData.globalRect.y, node->renderData.globalRect.width, node->renderData.globalRect.height));
        }
        
        parentContext->concatenate(node->renderData.globalTransform.inverted());
        parentContext->setAlpha(layerAlpha);
        parentContext->draw(tempContext, node->renderData.globalRect);
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
    
    processRenderTree(renderNode, lottie::Vector2D((int)size.width, (int)size.height), lottie::CATransform3D::identity().scaled(lottie::Vector2D(size.width / (double)animation.size.width, size.height / (double)animation.size.height)), false, *_bezierPathsBoundingBoxContext.get());
    
    if (useReferenceRendering) {
        auto context = std::make_shared<lottieRendering::CanvasImpl>((int)size.width, (int)size.height);
        
        CGPoint scale = CGPointMake(size.width / (CGFloat)animation.size.width, size.height / (CGFloat)animation.size.height);
        context->concatenate(lottie::CATransform3D::makeScale(scale.x, scale.y, 1.0));
        
        renderLottieRenderNode(renderNode, context, lottie::Vector2D(context->width(), context->height()), 1.0);
        
        auto image = context->makeImage();
        
        return [[UIImage alloc] initWithCGImage:std::static_pointer_cast<lottieRendering::ImageImpl>(image)->nativeImage()];
    } else {
        /*auto context = std::make_shared<lottieRendering::ThorVGCanvasImpl>((int)size.width, (int)size.height);
        
        CGPoint scale = CGPointMake(size.width / (CGFloat)animation.size.width, size.height / (CGFloat)animation.size.height);
        context->concatenate(lottie::CATransform3D::makeScale(scale.x, scale.y, 1.0));
        
        renderLottieRenderNode(renderNode, context, lottie::Vector2D(context->width(), context->height()), 1.0);*/
        
        return nil;
    }
}

@end
