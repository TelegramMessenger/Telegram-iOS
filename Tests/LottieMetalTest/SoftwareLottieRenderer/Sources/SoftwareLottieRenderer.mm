#import <SoftwareLottieRenderer/SoftwareLottieRenderer.h>

#import "Canvas.h"
#import "CoreGraphicsCanvasImpl.h"
#import "ThorVGCanvasImpl.h"

#include <LottieCpp/RenderTreeNode.h>

namespace {

struct TransformedPath {
    lottie::BezierPath path;
    lottie::CATransform3D transform;
    
    TransformedPath(lottie::BezierPath const &path_, lottie::CATransform3D const &transform_) :
    path(path_),
    transform(transform_) {
    }
};

static lottie::CGRect collectPathBoundingBoxes(std::shared_ptr<lottie::RenderTreeNodeContentItem> item, size_t subItemLimit, lottie::CATransform3D const &parentTransform, bool skipApplyTransform, lottie::BezierPathsBoundingBoxContext &bezierPathsBoundingBoxContext) {
    //TODO:remove skipApplyTransform
    lottie::CATransform3D effectiveTransform = parentTransform;
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

static std::vector<TransformedPath> collectPaths(std::shared_ptr<lottie::RenderTreeNodeContentItem> item, size_t subItemLimit, lottie::CATransform3D const &parentTransform, bool skipApplyTransform) {
    std::vector<TransformedPath> mappedPaths;
    
    //TODO:remove skipApplyTransform
    lottie::CATransform3D effectiveTransform = parentTransform;
    if (!skipApplyTransform && item->isGroup) {
        effectiveTransform = item->transform * effectiveTransform;
    }
    
    size_t maxSubitem = std::min(item->subItems.size(), subItemLimit);
    
    if (item->path) {
        mappedPaths.emplace_back(item->path->path, effectiveTransform);
    }
    assert(!item->trimParams);
    
    for (size_t i = 0; i < maxSubitem; i++) {
        auto &subItem = item->subItems[i];
        
        auto subItemPaths = collectPaths(subItem, INT32_MAX, effectiveTransform, false);
        
        for (auto &path : subItemPaths) {
            mappedPaths.emplace_back(path.path, path.transform);
        }
    }
    
    return mappedPaths;
}

}

namespace lottie {

static std::optional<CGRect> getRenderContentItemGlobalRect(std::shared_ptr<RenderTreeNodeContentItem> const &contentItem, lottie::Vector2D const &globalSize, BezierPathsBoundingBoxContext &bezierPathsBoundingBoxContext) {
    if (!contentItem->renderData.isValid) {
        return std::nullopt;
    }
    
    auto currentTransform = contentItem->renderData.globalTransform;
    
    std::optional<CGRect> globalRect;
    for (const auto &shadingVariant : contentItem->shadings) {
        lottie::CGRect shapeBounds = collectPathBoundingBoxes(contentItem, shadingVariant->subItemLimit, lottie::CATransform3D::identity(), true, bezierPathsBoundingBoxContext);
        
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
        auto subGlobalRect = getRenderContentItemGlobalRect(subItem, globalSize, bezierPathsBoundingBoxContext);
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

static std::optional<CGRect> getRenderNodeGlobalRect(std::shared_ptr<RenderTreeNode> const &node, lottie::Vector2D const &globalSize, BezierPathsBoundingBoxContext &bezierPathsBoundingBoxContext) {
    if (!node->renderData.isValid) {
        return std::nullopt;
    }
    auto currentTransform = node->renderData.globalTransform;
    
    std::optional<CGRect> globalRect;
    if (node->_contentItem) {
        globalRect = getRenderContentItemGlobalRect(node->_contentItem, globalSize, bezierPathsBoundingBoxContext);
    }
    
    if (node->renderData.isInvertedMatte) {
        CGRect globalBounds = node->bounds().applyingTransform(currentTransform);
        if (globalRect) {
            globalRect = globalRect->unionWith(globalBounds);
        } else {
            globalRect = globalBounds;
        }
    }
    
    for (const auto &subNode : node->subnodes()) {
        auto subGlobalRect = getRenderNodeGlobalRect(subNode, globalSize, bezierPathsBoundingBoxContext);
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

static void processRenderContentItem(std::shared_ptr<RenderTreeNodeContentItem> const &contentItem, Vector2D const &globalSize, CATransform3D const &parentTransform, BezierPathsBoundingBoxContext &bezierPathsBoundingBoxContext) {
    auto currentTransform = parentTransform;
    
    CATransform3D localTransform = contentItem->transform;
    currentTransform = localTransform * currentTransform;
    
    if (!currentTransform.isInvertible()) {
        contentItem->renderData.isValid = false;
        return;
    }
    
    int drawContentDescendants = 0;
    for (const auto &shadingVariant : contentItem->shadings) {
        if (shadingVariant->stroke) {
        } else if (shadingVariant->fill) {
        } else {
            continue;
        }
        
        drawContentDescendants += 1;
    }
    
    if (contentItem->isGroup) {
        for (auto it = contentItem->subItems.rbegin(); it != contentItem->subItems.rend(); it++) {
            const auto &subItem = *it;
            processRenderContentItem(subItem, globalSize, currentTransform, bezierPathsBoundingBoxContext);
            
            if (subItem->renderData.isValid) {
                drawContentDescendants += subItem->renderData.drawContentDescendants;
            }
        }
    } else {
        for (const auto &subItem : contentItem->subItems) {
            subItem->renderData.isValid = false;
        }
    }
    
    contentItem->renderData.isValid = true;
    
    contentItem->renderData.layer._bounds = CGRect(0.0, 0.0, 0.0, 0.0);
    contentItem->renderData.layer._position = Vector2D(0.0, 0.0);
    contentItem->renderData.layer._transform = contentItem->transform;
    contentItem->renderData.layer._opacity = contentItem->alpha;
    contentItem->renderData.layer._masksToBounds = false;
    contentItem->renderData.layer._isHidden = false;
    
    contentItem->renderData.globalTransform = currentTransform;
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
    
    int drawContentDescendants = 0;
    if (node->_contentItem) {
        processRenderContentItem(node->_contentItem, globalSize, currentTransform, bezierPathsBoundingBoxContext);
        if (node->_contentItem->renderData.isValid) {
            drawContentDescendants += node->_contentItem->renderData.drawContentDescendants;
        }
    }
    
    bool isInvertedMatte = isInvertedMask;
    
    for (const auto &item : node->subnodes()) {
        processRenderTree(item, globalSize, currentTransform, false, bezierPathsBoundingBoxContext);
        if (item->renderData.isValid) {
            drawContentDescendants += item->renderData.drawContentDescendants;
        }
    }
    
    bool masksToBounds = node->masksToBounds();
    if (masksToBounds) {
        CGRect effectiveGlobalBounds = node->bounds().applyingTransform(currentTransform);
        if (effectiveGlobalBounds.contains(CGRect(0.0, 0.0, globalSize.x, globalSize.y))) {
            masksToBounds = false;
        }
    }
    
    if (node->mask()) {
        processRenderTree(node->mask(), globalSize, currentTransform, node->invertMask(), bezierPathsBoundingBoxContext);
        if (!node->mask()->renderData.isValid) {
            node->renderData.isValid = false;
            return;
        }
    }
    
    node->renderData.isValid = true;
    
    node->renderData.layer._bounds = node->bounds();
    node->renderData.layer._position = node->position();
    node->renderData.layer._transform = node->transform();
    node->renderData.layer._opacity = node->alpha();
    node->renderData.layer._masksToBounds = masksToBounds;
    node->renderData.layer._isHidden = node->isHidden();
    
    node->renderData.globalTransform = currentTransform;
    node->renderData.drawContentDescendants = drawContentDescendants;
    node->renderData.isInvertedMatte = isInvertedMatte;
}

}

namespace {

static void drawLottieContentItem(std::shared_ptr<lottieRendering::Canvas> parentContext, std::shared_ptr<lottie::RenderTreeNodeContentItem> item, float parentAlpha, lottie::Vector2D const &globalSize, lottie::BezierPathsBoundingBoxContext &bezierPathsBoundingBoxContext) {
    if (!item->renderData.isValid) {
        return;
    }
    
    float normalizedOpacity = item->renderData.layer.opacity();
    float layerAlpha = ((float)normalizedOpacity) * parentAlpha;
    
    if (item->renderData.layer.isHidden() || normalizedOpacity == 0.0f) {
        return;
    }
    
    parentContext->saveState();
    
    std::shared_ptr<lottieRendering::Canvas> currentContext;
    std::shared_ptr<lottieRendering::Canvas> tempContext;
    
    bool needsTempContext = false;
    needsTempContext = layerAlpha != 1.0 && item->renderData.drawContentDescendants > 1;
    
    std::optional<lottie::CGRect> globalRect;
    if (needsTempContext) {
        globalRect = lottie::getRenderContentItemGlobalRect(item, globalSize, bezierPathsBoundingBoxContext);
        if (!globalRect || globalRect->width <= 0.0f || globalRect->height <= 0.0f) {
            parentContext->restoreState();
            return;
        }
        
        auto tempContextValue = parentContext->makeLayer((int)(globalRect->width), (int)(globalRect->height));
        tempContext = tempContextValue;
        
        currentContext = tempContextValue;
        currentContext->concatenate(lottie::CATransform3D::identity().translated(lottie::Vector2D(-globalRect->x, -globalRect->y)));
        
        currentContext->saveState();
        currentContext->concatenate(item->renderData.globalTransform);
    } else {
        currentContext = parentContext;
    }
    
    parentContext->concatenate(lottie::CATransform3D::identity().translated(lottie::Vector2D(item->renderData.layer.position().x, item->renderData.layer.position().y)));
    parentContext->concatenate(lottie::CATransform3D::identity().translated(lottie::Vector2D(-item->renderData.layer.bounds().x, -item->renderData.layer.bounds().y)));
    parentContext->concatenate(item->renderData.layer.transform());
    
    float renderAlpha = 1.0;
    if (tempContext) {
        renderAlpha = 1.0;
    } else {
        renderAlpha = layerAlpha;
    }
    
    for (const auto &shading : item->shadings) {
        std::vector<lottie::BezierPath> itemPaths;
        if (shading->explicitPath) {
            itemPaths = shading->explicitPath.value();
        } else {
            auto rawPaths = collectPaths(item, shading->subItemLimit, lottie::CATransform3D::identity(), true);
            for (const auto &rawPath : rawPaths) {
                itemPaths.push_back(rawPath.path.copyUsingTransform(rawPath.transform));
            }
        }
        
        if (itemPaths.empty()) {
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
        for (const auto &path : itemPaths) {
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
                    
                    currentContext->strokePath(path, shading->stroke->lineWidth, lineJoin, lineCap, shading->stroke->dashPhase, dashPattern, lottie::Color(solidShading->color.r, solidShading->color.g, solidShading->color.b, solidShading->color.a * solidShading->opacity * renderAlpha));
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
                    currentContext->fillPath(path, rule, lottie::Color(solidShading->color.r, solidShading->color.g, solidShading->color.b, solidShading->color.a * solidShading->opacity * renderAlpha));
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
                            currentContext->linearGradientFillPath(path, rule, gradient, start, end);
                            break;
                        }
                        case lottie::GradientType::Radial: {
                            currentContext->radialGradientFillPath(path, rule, gradient, start, 0.0, start, start.distanceTo(end));
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
        drawLottieContentItem(currentContext, subItem, renderAlpha, globalSize, bezierPathsBoundingBoxContext);
    }
    
    if (tempContext) {
        tempContext->restoreState();
        
        parentContext->concatenate(item->renderData.globalTransform.inverted());
        parentContext->setAlpha(layerAlpha);
        parentContext->draw(tempContext, globalRect.value());
        parentContext->setAlpha(1.0);
    }
    
    parentContext->restoreState();
}

static void renderLottieRenderNode(std::shared_ptr<lottie::RenderTreeNode> node, std::shared_ptr<lottieRendering::Canvas> parentContext, lottie::Vector2D const &globalSize, float parentAlpha, lottie::BezierPathsBoundingBoxContext &bezierPathsBoundingBoxContext) {
    if (!node->renderData.isValid) {
        return;
    }
    float normalizedOpacity = node->renderData.layer.opacity();
    float layerAlpha = ((float)normalizedOpacity) * parentAlpha;
    
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
    
    std::optional<lottie::CGRect> globalRect;
    if (needsTempContext) {
        globalRect = lottie::getRenderNodeGlobalRect(node, globalSize, bezierPathsBoundingBoxContext);
        if (!globalRect || globalRect->width <= 0.0f || globalRect->height <= 0.0f) {
            parentContext->restoreState();
            return;
        }
        
        if ((node->mask() && node->mask()->renderData.isValid) || node->renderData.layer.masksToBounds()) {
            auto maskBackingStorage = parentContext->makeLayer((int)(globalRect->width), (int)(globalRect->height));
            
            maskBackingStorage->concatenate(lottie::CATransform3D::identity().translated(lottie::Vector2D(-globalRect->x, -globalRect->y)));
            maskBackingStorage->concatenate(node->renderData.globalTransform);
            
            if (node->renderData.layer.masksToBounds()) {
                maskBackingStorage->fill(lottie::CGRect(node->renderData.layer.bounds().x, node->renderData.layer.bounds().y, node->renderData.layer.bounds().width, node->renderData.layer.bounds().height), lottie::Color(1.0, 1.0, 1.0, 1.0));
            }
            if (node->mask() && node->mask()->renderData.isValid) {
                renderLottieRenderNode(node->mask(), maskBackingStorage, globalSize, 1.0, bezierPathsBoundingBoxContext);
            }
            
            maskContext = maskBackingStorage;
        }
        
        auto tempContextValue = parentContext->makeLayer((int)(globalRect->width), (int)(globalRect->height));
        tempContext = tempContextValue;
        
        currentContext = tempContextValue;
        currentContext->concatenate(lottie::CATransform3D::identity().translated(lottie::Vector2D(-globalRect->x, -globalRect->y)));
        
        currentContext->saveState();
        currentContext->concatenate(node->renderData.globalTransform);
    } else {
        currentContext = parentContext;
    }
    
    parentContext->concatenate(lottie::CATransform3D::identity().translated(lottie::Vector2D(node->renderData.layer.position().x, node->renderData.layer.position().y)));
    parentContext->concatenate(lottie::CATransform3D::identity().translated(lottie::Vector2D(-node->renderData.layer.bounds().x, -node->renderData.layer.bounds().y)));
    parentContext->concatenate(node->renderData.layer.transform());
    
    float renderAlpha = 1.0;
    if (tempContext) {
        renderAlpha = 1.0;
    } else {
        renderAlpha = layerAlpha;
    }
    
    if (node->_contentItem) {
        drawLottieContentItem(currentContext, node->_contentItem, renderAlpha, globalSize, bezierPathsBoundingBoxContext);
    }
    
    if (node->renderData.isInvertedMatte) {
        currentContext->fill(lottie::CGRect(node->renderData.layer.bounds().x, node->renderData.layer.bounds().y, node->renderData.layer.bounds().width, node->renderData.layer.bounds().height), lottie::Color(0.0, 0.0, 0.0, 1.0));
        currentContext->setBlendMode(lottieRendering::BlendMode::DestinationOut);
    }
    
    for (const auto &subnode : node->subnodes()) {
        if (subnode->renderData.isValid) {
            renderLottieRenderNode(subnode, currentContext, globalSize, renderAlpha, bezierPathsBoundingBoxContext);
        }
    }
    
    if (tempContext) {
        tempContext->restoreState();
        
        if (maskContext) {
            tempContext->setBlendMode(lottieRendering::BlendMode::DestinationIn);
            tempContext->draw(maskContext, lottie::CGRect(globalRect->x, globalRect->y, globalRect->width, globalRect->height));
        }
        
        parentContext->concatenate(node->renderData.globalTransform.inverted());
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
    if (!useReferenceRendering) {
        return nil;
    }
    
    LottieAnimation *animation = _animationContainer.animation;
    std::shared_ptr<lottie::RenderTreeNode> renderNode = [_animationContainer internalGetRootRenderTreeNode];
    if (!renderNode) {
        return nil;
    }
    
    processRenderTree(renderNode, lottie::Vector2D((int)size.width, (int)size.height), lottie::CATransform3D::identity().scaled(lottie::Vector2D(size.width / (float)animation.size.width, size.height / (float)animation.size.height)), false, *_bezierPathsBoundingBoxContext.get());
    
    if (useReferenceRendering) {
        auto context = std::make_shared<lottieRendering::CanvasImpl>((int)size.width, (int)size.height);
        
        CGPoint scale = CGPointMake(size.width / (CGFloat)animation.size.width, size.height / (CGFloat)animation.size.height);
        context->concatenate(lottie::CATransform3D::makeScale(scale.x, scale.y, 1.0));
        
        renderLottieRenderNode(renderNode, context, lottie::Vector2D(context->width(), context->height()), 1.0, *_bezierPathsBoundingBoxContext.get());
        
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
