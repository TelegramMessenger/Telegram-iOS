#include "LottieRenderTree.h"

#include <LottieCpp/CGPath.h>
#include <LottieCpp/CGPathCocoa.h>
#import <LottieCpp/Color.h>
#include "Lottie/Public/Primitives/CALayer.hpp"
#include <LottieCpp/VectorsCocoa.h>

namespace {

}

@interface LottiePath () {
    std::vector<lottie::BezierPath> _paths;
    NSData *_customData;
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

- (instancetype _Nonnull)initWithCustomData:(NSData * _Nonnull)customData __attribute__((objc_direct)) {
    self = [super init];
    if (self != nil) {
        _customData = customData;
    }
    return self;
}

- (void)enumerateItems:(void (^ _Nonnull)(LottiePathItem * _Nonnull))iterate {
    LottiePathItem item;
    
    if (_customData != nil) {
        int dataOffset = 0;
        int dataLength = (int)_customData.length;
        uint8_t const *dataBytes = (uint8_t const *)_customData.bytes;
        while (dataOffset < dataLength) {
            uint8_t itemType = dataBytes[dataOffset];
            dataOffset += 1;
            
            switch (itemType) {
                case 0: {
                    Float32 px;
                    memcpy(&px, dataBytes + dataOffset, 4);
                    dataOffset += 4;
                    
                    Float32 py;
                    memcpy(&py, dataBytes + dataOffset, 4);
                    dataOffset += 4;
                    
                    item.type = LottiePathItemTypeMoveTo;
                    item.points[0] = CGPointMake(px, py);
                    iterate(&item);
                    
                    break;
                }
                case 1: {
                    Float32 px;
                    memcpy(&px, dataBytes + dataOffset, 4);
                    dataOffset += 4;
                    
                    Float32 py;
                    memcpy(&py, dataBytes + dataOffset, 4);
                    dataOffset += 4;
                    
                    item.type = LottiePathItemTypeLineTo;
                    item.points[0] = CGPointMake(px, py);
                    iterate(&item);
                    
                    break;
                }
                case 2: {
                    Float32 p1x;
                    memcpy(&p1x, dataBytes + dataOffset, 4);
                    dataOffset += 4;
                    
                    Float32 p1y;
                    memcpy(&p1y, dataBytes + dataOffset, 4);
                    dataOffset += 4;
                    
                    Float32 p2x;
                    memcpy(&p2x, dataBytes + dataOffset, 4);
                    dataOffset += 4;
                    
                    Float32 p2y;
                    memcpy(&p2y, dataBytes + dataOffset, 4);
                    dataOffset += 4;
                    
                    Float32 px;
                    memcpy(&px, dataBytes + dataOffset, 4);
                    dataOffset += 4;
                    
                    Float32 py;
                    memcpy(&py, dataBytes + dataOffset, 4);
                    dataOffset += 4;
                    
                    item.type = LottiePathItemTypeCurveTo;
                    item.points[0] = CGPointMake(p1x, p1y);
                    item.points[1] = CGPointMake(p2x, p2y);
                    item.points[2] = CGPointMake(px, py);
                    iterate(&item);
                    
                    break;
                }
                case 3: {
                    item.type = LottiePathItemTypeClose;
                    iterate(&item);
                    break;
                }
                default: {
                    break;
                }
            }
        }
    } else {
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
    }
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

- (instancetype _Nonnull)initWithSolidShading:(lottie::RenderTreeNodeContentItem::SolidShading *)solidShading __attribute__((objc_direct)) {
    self = [super init];
    if (self != nil) {
        _color = lottieColorFromColor(solidShading->color);
        _opacity = solidShading->opacity;
    }
    return self;
}

- (instancetype _Nonnull)initWithColor:(LottieColor)color opacity:(CGFloat)opacity {
    self = [super init];
    if (self != nil) {
        _color = color;
        _opacity = opacity;
    }
    return self;
}

@end

@implementation LottieRenderContentGradientShading

- (instancetype _Nonnull)initWithGradientShading:(lottie::RenderTreeNodeContentItem::GradientShading *)gradientShading __attribute__((objc_direct)) {
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

- (instancetype _Nonnull)initWithOpacity:(CGFloat)opacity gradientType:(LottieGradientType)gradientType colorStops:(NSArray<LottieColorStop *> * _Nonnull)colorStops start:(CGPoint)start end:(CGPoint)end __attribute__((objc_direct)) {
    self = [super init];
    if (self != nil) {
        _opacity = opacity;
        _gradientType = gradientType;
        _colorStops = colorStops;
        _start = start;
        _end = end;
    }
    return self;
}

@end

@implementation LottieRenderContentFill

- (instancetype _Nonnull)initWithFill:(std::shared_ptr<lottie::RenderTreeNodeContentItem::Fill> const &)fill __attribute__((objc_direct)) {
    self = [super init];
    if (self != nil) {
        switch (fill->shading->type()) {
            case lottie::RenderTreeNodeContentItem::ShadingType::Solid: {
                _shading = [[LottieRenderContentSolidShading alloc] initWithSolidShading:(lottie::RenderTreeNodeContentItem::SolidShading *)fill->shading.get()];
                break;
            }
            case lottie::RenderTreeNodeContentItem::ShadingType::Gradient: {
                _shading = [[LottieRenderContentGradientShading alloc] initWithGradientShading:(lottie::RenderTreeNodeContentItem::GradientShading *)fill->shading.get()];
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

- (instancetype _Nonnull)initWithShading:(LottieRenderContentShading * _Nonnull)shading fillRule:(LottieFillRule)fillRule __attribute__((objc_direct)) {
    self = [super init];
    if (self != nil) {
        _shading = shading;
        _fillRule = fillRule;
    }
    return self;
}

@end

@implementation LottieRenderContentStroke

- (instancetype _Nonnull)initWithStroke:(std::shared_ptr<lottie::RenderTreeNodeContentItem::Stroke> const &)stroke __attribute__((objc_direct)) {
    self = [super init];
    if (self != nil) {
        switch (stroke->shading->type()) {
            case lottie::RenderTreeNodeContentItem::ShadingType::Solid: {
                _shading = [[LottieRenderContentSolidShading alloc] initWithSolidShading:(lottie::RenderTreeNodeContentItem::SolidShading *)stroke->shading.get()];
                break;
            }
            case lottie::RenderTreeNodeContentItem::ShadingType::Gradient: {
                _shading = [[LottieRenderContentGradientShading alloc] initWithGradientShading:(lottie::RenderTreeNodeContentItem::GradientShading *)stroke->shading.get()];
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

- (instancetype _Nonnull)initWithShading:(LottieRenderContentShading * _Nonnull)shading lineWidth:(CGFloat)lineWidth lineJoin:(CGLineJoin)lineJoin lineCap:(CGLineCap)lineCap miterLimit:(CGFloat)miterLimit dashPhase:(CGFloat)dashPhase dashPattern:(NSArray<NSNumber *> * _Nullable)dashPattern __attribute__((objc_direct)) {
    self = [super init];
    if (self != nil) {
        _shading = shading;
        _lineWidth = lineWidth;
        _lineJoin = lineJoin;
        _lineCap = lineCap;
        _miterLimit = miterLimit;
        _dashPhase = dashPhase;
        _dashPattern = dashPattern;
    }
    return self;
}

@end

@implementation LottieRenderContent

- (instancetype _Nonnull)initWithPath:(LottiePath * _Nonnull)path stroke:(LottieRenderContentStroke * _Nullable)stroke fill:(LottieRenderContentFill * _Nullable)fill __attribute__((objc_direct)) {
    self = [super init];
    if (self != nil) {
        _path = path;
        _stroke = stroke;
        _fill = fill;
    }
    return self;
}

@end

@implementation LottieRenderNode

- (instancetype _Nonnull)initWithPosition:(CGPoint)position bounds:(CGRect)bounds transform:(CATransform3D)transform opacity:(CGFloat)opacity masksToBounds:(bool)masksToBounds isHidden:(bool)isHidden globalRect:(CGRect)globalRect globalTransform:(CATransform3D)globalTransform renderContent:(LottieRenderContent * _Nullable)renderContent hasSimpleContents:(bool)hasSimpleContents isInvertedMatte:(bool)isInvertedMatte subnodes:(NSArray<LottieRenderNode *> * _Nonnull)subnodes mask:(LottieRenderNode * _Nullable)mask __attribute__((objc_direct)) {
    self = [super init];
    if (self != nil) {
        _position = position;
        _bounds = bounds;
        _transform = transform;
        _opacity = opacity;
        _masksToBounds = masksToBounds;
        _isHidden = isHidden;
        _globalRect = globalRect;
        _globalTransform= globalTransform;
        _renderContent = renderContent;
        _hasSimpleContents = hasSimpleContents;
        _isInvertedMatte = isInvertedMatte;
        _subnodes = subnodes;
        _mask = mask;
    }
    return self;
}

@end
