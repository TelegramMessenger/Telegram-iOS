#import <SoftwareLottieRenderer/SoftwareLottieRenderer.h>

#import "Canvas.h"
#import "CoreGraphicsCanvasImpl.h"

namespace {

static void drawLottieRenderableItem(std::shared_ptr<lottieRendering::Canvas> context, LottieRenderContent * _Nonnull item) {
    if (item.path == nil) {
        return;
    }
    
    std::shared_ptr<lottie::CGPath> path = lottie::CGPath::makePath();
    [item.path enumerateItems:^(LottiePathItem * _Nonnull pathItem) {
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
    }];
    
    if (item.stroke != nil) {
        if ([item.stroke.shading isKindOfClass:[LottieRenderContentSolidShading class]]) {
            LottieRenderContentSolidShading *solidShading = (LottieRenderContentSolidShading *)item.stroke.shading;
            
            lottieRendering::LineJoin lineJoin = lottieRendering::LineJoin::Bevel;
            switch (item.stroke.lineJoin) {
                case kCGLineJoinBevel: {
                    lineJoin = lottieRendering::LineJoin::Bevel;
                    break;
                }
                case kCGLineJoinRound: {
                    lineJoin = lottieRendering::LineJoin::Round;
                    break;
                }
                case kCGLineJoinMiter: {
                    lineJoin = lottieRendering::LineJoin::Miter;
                    break;
                }
                default: {
                    break;
                }
            }
            
            lottieRendering::LineCap lineCap = lottieRendering::LineCap::Square;
            switch (item.stroke.lineCap) {
                case kCGLineCapButt: {
                    lineCap = lottieRendering::LineCap::Butt;
                    break;
                }
                case kCGLineCapRound: {
                    lineCap = lottieRendering::LineCap::Round;
                    break;
                }
                case kCGLineCapSquare: {
                    lineCap = lottieRendering::LineCap::Square;
                    break;
                }
                default: {
                    break;
                }
            }
            
            std::vector<double> dashPattern;
            if (item.stroke.dashPattern != nil) {
                for (NSNumber *value in item.stroke.dashPattern) {
                    dashPattern.push_back([value doubleValue]);
                }
            }
            
            context->strokePath(path, item.stroke.lineWidth, lineJoin, lineCap, item.stroke.dashPhase, dashPattern, lottieRendering::Color(solidShading.color.r, solidShading.color.g, solidShading.color.b, solidShading.color.a));
        } else if ([item.stroke.shading isKindOfClass:[LottieRenderContentGradientShading class]]) {
            __unused LottieRenderContentGradientShading *gradientShading = (LottieRenderContentGradientShading *)item.stroke.shading;
        }
    } else if (item.fill != nil) {
        lottieRendering::FillRule rule = lottieRendering::FillRule::NonZeroWinding;
        switch (item.fill.fillRule) {
            case LottieFillRuleEvenOdd: {
                rule = lottieRendering::FillRule::EvenOdd;
                break;
            }
            case LottieFillRuleWinding: {
                rule = lottieRendering::FillRule::NonZeroWinding;
                break;
            }
            default: {
                break;
            }
        }
        
        if ([item.fill.shading isKindOfClass:[LottieRenderContentSolidShading class]]) {
            LottieRenderContentSolidShading *solidShading = (LottieRenderContentSolidShading *)item.fill.shading;
            
            context->fillPath(path, rule, lottieRendering::Color(solidShading.color.r, solidShading.color.g, solidShading.color.b, solidShading.color.a));
        } else if ([item.fill.shading isKindOfClass:[LottieRenderContentGradientShading class]]) {
            LottieRenderContentGradientShading *gradientShading = (LottieRenderContentGradientShading *)item.fill.shading;
            
            std::vector<lottieRendering::Color> colors;
            std::vector<double> locations;
            for (LottieColorStop *colorStop in gradientShading.colorStops) {
                colors.push_back(lottieRendering::Color(colorStop.color.r, colorStop.color.g, colorStop.color.b, colorStop.color.a));
                locations.push_back(colorStop.location);
            }
            
            lottieRendering::Gradient gradient(colors, locations);
            lottie::Vector2D start(gradientShading.start.x, gradientShading.start.y);
            lottie::Vector2D end(gradientShading.end.x, gradientShading.end.y);
            
            switch (gradientShading.gradientType) {
                case LottieGradientTypeLinear: {
                    context->linearGradientFillPath(path, rule, gradient, start, end);
                    break;
                }
                case LottieGradientTypeRadial: {
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

static void renderLottieRenderNode(LottieRenderNode * _Nonnull node, std::shared_ptr<lottieRendering::Canvas> parentContext, lottie::Vector2D const &globalSize, double parentAlpha) {
    float normalizedOpacity = node.opacity;
    double layerAlpha = ((double)normalizedOpacity) * parentAlpha;
    
    if (node.isHidden || normalizedOpacity == 0.0f) {
        return;
    }
    
    parentContext->saveState();
    
    std::shared_ptr<lottieRendering::Canvas> maskContext;
    std::shared_ptr<lottieRendering::Canvas> currentContext;
    std::shared_ptr<lottieRendering::Canvas> tempContext;
    
    bool needsTempContext = false;
    if (node.mask != nil) {
        needsTempContext = true;
    } else {
        needsTempContext = layerAlpha != 1.0 || node.masksToBounds;
    }
    
    if (needsTempContext) {
        if (node.mask != nil || node.masksToBounds) {
            auto maskBackingStorage = parentContext->makeLayer((int)(node.globalRect.size.width), (int)(node.globalRect.size.height));
            
            maskBackingStorage->concatenate(lottie::CATransform3D::identity().translated(lottie::Vector2D(-node.globalRect.origin.x, -node.globalRect.origin.y)));
            maskBackingStorage->concatenate(lottie::fromNativeTransform(node.globalTransform));
            
            if (node.masksToBounds) {
                maskBackingStorage->fill(lottie::CGRect(node.bounds.origin.x, node.bounds.origin.y, node.bounds.size.width, node.bounds.size.height), lottieRendering::Color(1.0, 1.0, 1.0, 1.0));
            }
            if (node.mask != nil) {
                renderLottieRenderNode(node.mask, maskBackingStorage, globalSize, 1.0);
            }
            
            maskContext = maskBackingStorage;
        }
        
        auto tempContextValue = parentContext->makeLayer((int)(node.globalRect.size.width), (int)(node.globalRect.size.height));
        tempContext = tempContextValue;
        
        currentContext = tempContextValue;
        currentContext->concatenate(lottie::CATransform3D::identity().translated(lottie::Vector2D(-node.globalRect.origin.x, -node.globalRect.origin.y)));
        
        currentContext->saveState();
        currentContext->concatenate(lottie::fromNativeTransform(node.globalTransform));
    } else {
        currentContext = parentContext;
    }
    
    parentContext->concatenate(lottie::CATransform3D::identity().translated(lottie::Vector2D(node.position.x, node.position.y)));
    parentContext->concatenate(lottie::CATransform3D::identity().translated(lottie::Vector2D(-node.bounds.origin.x, -node.bounds.origin.y)));
    parentContext->concatenate(lottie::fromNativeTransform(node.transform));
    
    double renderAlpha = 1.0;
    if (tempContext) {
        renderAlpha = 1.0;
    } else {
        renderAlpha = layerAlpha;
    }
    
    currentContext->setAlpha(renderAlpha);
    
    if (node.renderContent != nil) {
        drawLottieRenderableItem(currentContext, node.renderContent);
    }
    
    if (node.isInvertedMatte) {
        currentContext->fill(lottie::CGRect(node.bounds.origin.x, node.bounds.origin.y, node.bounds.size.width, node.bounds.size.height), lottieRendering::Color(0.0, 0.0, 0.0, 1.0));
        currentContext->setBlendMode(lottieRendering::BlendMode::DestinationOut);
    }
    
    for (LottieRenderNode *subnode in node.subnodes) {
        renderLottieRenderNode(subnode, currentContext, globalSize, renderAlpha);
    }
    
    if (tempContext) {
        tempContext->restoreState();
        
        if (maskContext) {
            tempContext->setBlendMode(lottieRendering::BlendMode::DestinationIn);
            tempContext->draw(maskContext, lottie::CGRect(node.globalRect.origin.x, node.globalRect.origin.y, node.globalRect.size.width, node.globalRect.size.height));
        }
        
        parentContext->concatenate(lottie::fromNativeTransform(node.globalTransform).inverted());
        parentContext->setAlpha(layerAlpha);
        parentContext->draw(tempContext, lottie::CGRect(node.globalRect.origin.x, node.globalRect.origin.y, node.globalRect.size.width, node.globalRect.size.height));
    }
    
    parentContext->restoreState();
}

}

CGRect getPathNativeBoundingBox(CGPathRef _Nonnull path) {
    auto rect = calculatePathBoundingBox(path);
    return CGRectMake(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
}

UIImage * _Nullable renderLottieAnimationContainer(LottieAnimationContainer * _Nonnull animationContainer, CGSize size, bool useReferenceRendering) {
    LottieAnimation *animation = animationContainer.animation;
    LottieRenderNode *lottieNode = [animationContainer getCurrentRenderTreeForSize:size];
    
    if (useReferenceRendering) {
        auto context = std::make_shared<lottieRendering::CanvasImpl>((int)size.width, (int)size.height);
        
        if (lottieNode) {
            CGPoint scale = CGPointMake(size.width / (CGFloat)animation.size.width, size.height / (CGFloat)animation.size.height);
            context->concatenate(lottie::CATransform3D::makeScale(scale.x, scale.y, 1.0));
            
            renderLottieRenderNode(lottieNode, context, lottie::Vector2D(context->width(), context->height()), 1.0);
        }
        
        auto image = context->makeImage();
        
        return [[UIImage alloc] initWithCGImage:std::static_pointer_cast<lottieRendering::ImageImpl>(image)->nativeImage()];
    } else {
        return nil;
    }
}
