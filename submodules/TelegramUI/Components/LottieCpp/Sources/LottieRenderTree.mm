#include <LottieCpp/LottieRenderTree.h>
#include "LottieRenderTreeInternal.h"

#include "Lottie/Public/Primitives/CGPath.hpp"
#include "Lottie/Public/Primitives/CGPathCocoa.h"
#include "Lottie/Public/Primitives/Color.hpp"
#include "Lottie/Public/Primitives/CALayer.hpp"
#include "Lottie/Public/Primitives/VectorsCocoa.h"

#include "RenderNode.hpp"

namespace {

}

@interface LottiePath () {
    std::vector<lottie::BezierPath> _paths;
}

@end

@implementation LottiePath

- (instancetype)initWithPaths:(std::vector<lottie::BezierPath>)paths __attribute__((objc_direct)) {
    self = [super init];
    if (self != nil) {
        _paths = paths;
    }
    return self;
}

/*- (instancetype _Nonnull)initWithCGPath:(CGPathRef _Nonnull)cgPath {
    self = [super init];
    if (self != nil) {
        CGMutablePathRef mutableCopy = CGPathCreateMutableCopy(cgPath);
        _path = std::make_shared<lottie::CGPathCocoaImpl>(mutableCopy);
        CFRelease(mutableCopy);
    }
    return self;
}*/

- (CGRect)boundingBox {
    lottie::CGRect result = bezierPathsBoundingBox(_paths);
    return CGRectMake(result.x, result.y, result.width, result.height);
}

- (void)enumerateItems:(void (^ _Nonnull)(LottiePathItem * _Nonnull))iterate {
    LottiePathItem item;
    
    for (const auto &path : _paths) {
        std::optional<lottie::PathElement> previousElement;
        for (const auto &element : path.elements()) {
            if (previousElement.has_value()) {
                if (previousElement->vertex.outTangentRelative().isZero() && element.vertex.inTangentRelative().isZero()) {
                    item.type = LottiePathItemTypeLineTo;
                    item.points[0] = CGPointMake(element.vertex.point.x, element.vertex.point.y);
                    iterate(&item);
                } else {
                    item.type = LottiePathItemTypeCurveTo;
                    item.points[2] = CGPointMake(element.vertex.point.x, element.vertex.point.y);
                    item.points[1] = CGPointMake(element.vertex.inTangent.x, element.vertex.inTangent.y);
                    item.points[0] = CGPointMake(previousElement->vertex.outTangent.x, previousElement->vertex.outTangent.y);
                    iterate(&item);
                }
            } else {
                item.type = LottiePathItemTypeMoveTo;
                item.points[0] = CGPointMake(element.vertex.point.x, element.vertex.point.y);
                iterate(&item);
            }
            previousElement = element;
        }
        if (path.closed().value_or(true)) {
            item.type = LottiePathItemTypeClose;
            iterate(&item);
        }
    }
    
    /*_path->enumerate([iterate](lottie::CGPathItem const &element) {
        LottiePathItem item;
        
        switch (element.type) {
            case lottie::CGPathItem::Type::MoveTo: {
                item.type = LottiePathItemTypeMoveTo;
                item.points[0] = CGPointMake(element.points[0].x, element.points[0].y);
                iterate(&item);
                break;
            }
            case lottie::CGPathItem::Type::LineTo: {
                item.type = LottiePathItemTypeLineTo;
                item.points[0] = CGPointMake(element.points[0].x, element.points[0].y);
                iterate(&item);
                break;
            }
            case lottie::CGPathItem::Type::CurveTo: {
                item.type = LottiePathItemTypeCurveTo;
                item.points[0] = CGPointMake(element.points[0].x, element.points[0].y);
                item.points[1] = CGPointMake(element.points[1].x, element.points[1].y);
                item.points[2] = CGPointMake(element.points[2].x, element.points[2].y);
                iterate(&item);
                break;
            }
            case lottie::CGPathItem::Type::Close: {
                item.type = LottiePathItemTypeClose;
                iterate(&item);
                break;
            }
        }
    });*/
}

@end

@implementation LottieColorStop : NSObject

- (instancetype _Nonnull)initWithColor:(LottieColor)color location:(CGFloat)location __attribute__((objc_direct)) {
    self = [super init];
    if (self != nil) {
        _color = color;
        _location = location;
    }
    return self;
}

@end

@implementation LottieRenderContentShading

- (instancetype _Nonnull)init {
    self = [super init];
    if (self != nil) {
    }
    return self;
}

@end

static LottieColor lottieColorFromColor(lottie::Color color) {
    LottieColor result;
    result.r = color.r;
    result.g = color.g;
    result.b = color.b;
    result.a = color.a;
    
    return result;
}

@implementation LottieRenderContentSolidShading

- (instancetype _Nonnull)initWithSolidShading:(lottie::RenderTreeNodeContent::SolidShading *)solidShading __attribute__((objc_direct)) {
    self = [super init];
    if (self != nil) {
        _color = lottieColorFromColor(solidShading->color);
        _opacity = solidShading->opacity;
    }
    return self;
}

@end

@implementation LottieRenderContentGradientShading

- (instancetype _Nonnull)initWithGradientShading:(lottie::RenderTreeNodeContent::GradientShading *)gradientShading __attribute__((objc_direct)) {
    self = [super init];
    if (self != nil) {
        _opacity = gradientShading->opacity;
        
        switch (gradientShading->gradientType) {
            case lottie::GradientType::Radial: {
                _gradientType = LottieGradientTypeRadial;
                break;
            }
            default: {
                _gradientType = LottieGradientTypeLinear;
                break;
            }
        }
        
        NSMutableArray<LottieColorStop *> *colorStops = [[NSMutableArray alloc] initWithCapacity:gradientShading->colors.size()];
        for (size_t i = 0; i < gradientShading->colors.size(); i++) {
            [colorStops addObject:[[LottieColorStop alloc] initWithColor:lottieColorFromColor(gradientShading->colors[i]) location:gradientShading->locations[i]]];
        }
        _colorStops = colorStops;
        
        _start = CGPointMake(gradientShading->start.x, gradientShading->start.y);
        _end = CGPointMake(gradientShading->end.x, gradientShading->end.y);
    }
    return self;
}

@end

@implementation LottieRenderContentFill

- (instancetype _Nonnull)initWithFill:(std::shared_ptr<lottie::RenderTreeNodeContent::Fill> const &)fill __attribute__((objc_direct)) {
    self = [super init];
    if (self != nil) {
        switch (fill->shading->type()) {
            case lottie::RenderTreeNodeContent::ShadingType::Solid: {
                _shading = [[LottieRenderContentSolidShading alloc] initWithSolidShading:(lottie::RenderTreeNodeContent::SolidShading *)fill->shading.get()];
                break;
            }
            case lottie::RenderTreeNodeContent::ShadingType::Gradient: {
                _shading = [[LottieRenderContentGradientShading alloc] initWithGradientShading:(lottie::RenderTreeNodeContent::GradientShading *)fill->shading.get()];
                break;
            }
            default: {
                abort();
            }
        }
        
        switch (fill->rule) {
            case lottie::FillRule::EvenOdd: {
                _fillRule = LottieFillRuleEvenOdd;
                break;
            }
            default: {
                _fillRule = LottieFillRuleWinding;
                break;
            }
        }
    }
    return self;
}

@end

@implementation LottieRenderContentStroke

- (instancetype _Nonnull)initWithStroke:(std::shared_ptr<lottie::RenderTreeNodeContent::Stroke> const &)stroke __attribute__((objc_direct)) {
    self = [super init];
    if (self != nil) {
        switch (stroke->shading->type()) {
            case lottie::RenderTreeNodeContent::ShadingType::Solid: {
                _shading = [[LottieRenderContentSolidShading alloc] initWithSolidShading:(lottie::RenderTreeNodeContent::SolidShading *)stroke->shading.get()];
                break;
            }
            case lottie::RenderTreeNodeContent::ShadingType::Gradient: {
                _shading = [[LottieRenderContentGradientShading alloc] initWithGradientShading:(lottie::RenderTreeNodeContent::GradientShading *)stroke->shading.get()];
                break;
            }
            default: {
                abort();
            }
        }
        
        _lineWidth = stroke->lineWidth;
        
        switch (stroke->lineJoin) {
            case lottie::LineJoin::Miter: {
                _lineJoin = kCGLineJoinMiter;
                break;
            }
            case lottie::LineJoin::Round: {
                _lineJoin = kCGLineJoinRound;
                break;
            }
            case lottie::LineJoin::Bevel: {
                _lineJoin = kCGLineJoinBevel;
                break;
            }
            default: {
                _lineJoin = kCGLineJoinBevel;
                break;
            }
        }
        
        switch (stroke->lineCap) {
            case lottie::LineCap::Butt: {
                _lineCap = kCGLineCapButt;
                break;
            }
            case lottie::LineCap::Round: {
                _lineCap = kCGLineCapRound;
                break;
            }
            case lottie::LineCap::Square: {
                _lineCap = kCGLineCapSquare;
                break;
            }
            default: {
                _lineCap = kCGLineCapSquare;
                break;
            }
        }
        
        _miterLimit = stroke->miterLimit;
        
        _dashPhase = stroke->dashPhase;
        
        if (!stroke->dashPattern.empty()) {
            NSMutableArray *dashPattern = [[NSMutableArray alloc] initWithCapacity:stroke->dashPattern.size()];
            for (auto value : stroke->dashPattern) {
                [dashPattern addObject:@(value)];
            }
            _dashPattern = dashPattern;
        }
    }
    return self;
}

@end

@implementation LottieRenderContent

- (instancetype _Nonnull)initWithRenderContent:(std::shared_ptr<lottie::RenderTreeNodeContent> const &)content __attribute__((objc_direct)) {
    self = [super init];
    if (self != nil) {
        _path = [[LottiePath alloc] initWithPaths:content->paths];
        if (content->stroke) {
            _stroke = [[LottieRenderContentStroke alloc] initWithStroke:content->stroke];
        }
        if (content->fill) {
            _fill = [[LottieRenderContentFill alloc] initWithFill:content->fill];
        }
    }
    return self;
}

@end

@implementation LottieRenderNode

@end

@implementation LottieRenderNode (Internal)

- (instancetype _Nonnull)initWithRenderNode:(std::shared_ptr<lottie::OutputRenderNode> const &)renderNode __attribute__((objc_direct)) {
    self = [super init];
    if (self != nil) {
        auto position = renderNode->layer.position();
        _position = CGPointMake(position.x, position.y);
        
        auto bounds = renderNode->layer.bounds();
        _bounds = CGRectMake(bounds.x, bounds.y, bounds.width, bounds.height);
        
        _transform = lottie::nativeTransform(renderNode->layer.transform());
        _opacity = renderNode->layer.opacity();
        _masksToBounds = renderNode->layer.masksToBounds();
        _isHidden = renderNode->layer.isHidden();
        
        auto globalRect = renderNode->globalRect;
        _globalRect = CGRectMake(globalRect.x, globalRect.y, globalRect.width, globalRect.height);
        
        _globalTransform = lottie::nativeTransform(renderNode->globalTransform);
        
        if (renderNode->renderContent) {
            _renderContent = [[LottieRenderContent alloc] initWithRenderContent:renderNode->renderContent];
        }
        
        _hasSimpleContents = renderNode->drawContentDescendants <= 1;
        _isInvertedMatte = renderNode->isInvertedMatte;
        
        if (!renderNode->subnodes.empty()) {
            NSMutableArray<LottieRenderNode *> *subnodes = [[NSMutableArray alloc] init];
            for (const auto &subnode : renderNode->subnodes) {
                [subnodes addObject:[[LottieRenderNode alloc] initWithRenderNode:subnode]];
            }
            _subnodes = subnodes;
        } else {
            _subnodes = [[NSArray alloc] init];
        }
        
        if (renderNode->mask) {
            _mask = [[LottieRenderNode alloc] initWithRenderNode:renderNode->mask];
        }
    }
    return self;
}

@end
