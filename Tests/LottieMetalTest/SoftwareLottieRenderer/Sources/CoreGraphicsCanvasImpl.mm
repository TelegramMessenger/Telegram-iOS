#include "CoreGraphicsCanvasImpl.h"

#include <LottieCpp/CGPathCocoa.h>
#include <LottieCpp/VectorsCocoa.h>

namespace lottie {

namespace {

int alignUp(int size, int align) {
    assert(((align - 1) & align) == 0);
    
    int alignmentMask = align - 1;
    return (size + alignmentMask) & ~alignmentMask;
}

bool addEnumeratedPath(CGContextRef context, CanvasPathEnumerator const &enumeratePath) {
    bool isEmpty = true;
    
    enumeratePath([&](PathCommand const &command) {
        switch (command.type) {
            case PathCommandType::MoveTo: {
                if (isEmpty) {
                    isEmpty = false;
                    CGContextBeginPath(context);
                }
                CGContextMoveToPoint(context, command.points[0].x, command.points[0].y);
                break;
            }
            case PathCommandType::LineTo: {
                if (isEmpty) {
                    isEmpty = false;
                    CGContextBeginPath(context);
                }
                CGContextAddLineToPoint(context, command.points[0].x, command.points[0].y);
                break;
            }
            case PathCommandType::CurveTo: {
                if (isEmpty) {
                    isEmpty = false;
                    CGContextBeginPath(context);
                }
                CGContextAddCurveToPoint(context, command.points[0].x, command.points[0].y, command.points[1].x, command.points[1].y, command.points[2].x, command.points[2].y);
                break;
            }
            case PathCommandType::Close: {
                if (isEmpty) {
                    isEmpty = false;
                    CGContextBeginPath(context);
                }
                CGContextClosePath(context);
                break;
            }
            default: {
                break;
            }
        }
    });
    
    return !isEmpty;
}

}

class CoreGraphicsCanvasImpl::Layer {
public:
    struct Composition {
        CGRect rect;
        float alpha;
        Transform2D transform;
        std::optional<Canvas::MaskMode> maskMode;
        
        Composition(CGRect rect_, float alpha_, Transform2D transform_, std::optional<Canvas::MaskMode> maskMode_) :
        rect(rect_), alpha(alpha_), transform(transform_), maskMode(maskMode_) {
        }
    };
    
public:
    explicit Layer(int width, int height, std::optional<Composition> composition) {
        _width = width;
        _height = height;
        _composition = composition;
        
        _bytesPerRow = alignUp(width * 4, 16);
        _backingData.resize(_bytesPerRow * _height);
        memset(_backingData.data(), 0, _backingData.size());
        
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGBitmapInfo bitmapInfo = kCGBitmapByteOrder32Host | kCGImageAlphaPremultipliedFirst;
        _context = CGBitmapContextCreate(_backingData.data(), _width, _height, 8, _bytesPerRow, colorSpace, bitmapInfo);
        CFRelease(colorSpace);
        
        CGContextClearRect(_context, CGRectMake(0.0, 0.0, _width, _height));
    }
    
    ~Layer() {
        CGContextRelease(_context);
    }
    
    CGContextRef context() const {
        return _context;
    }
    
    std::optional<Composition> composition() const {
        return _composition;
    }
    
    std::shared_ptr<CoreGraphicsCanvasImpl::Image> makeImage() {
        ::CGImageRef nativeImage = CGBitmapContextCreateImage(_context);
        if (nativeImage) {
            auto image = std::make_shared<CoreGraphicsCanvasImpl::Image>(nativeImage);
            CFRelease(nativeImage);
            return image;
        } else {
            return nil;
        }
    }
    
public:
    CGContextRef _context = nil;
    int _width = 0;
    int _height = 0;
    int _bytesPerRow = 0;
    std::vector<uint8_t> _backingData;
    
    std::optional<Composition> _composition;
};

CoreGraphicsCanvasImpl::Image::Image(::CGImageRef image) {
    _image = CGImageRetain(image);
}

CoreGraphicsCanvasImpl::Image::~Image() {
    CFRelease(_image);
}

::CGImageRef CoreGraphicsCanvasImpl::Image::nativeImage() const {
    return _image;
}

CoreGraphicsCanvasImpl::CoreGraphicsCanvasImpl(int width, int height) :
_width(width),
_height(height) {
    _layerStack.push_back(std::make_shared<Layer>(width, height, std::nullopt));
}

CoreGraphicsCanvasImpl::~CoreGraphicsCanvasImpl() {
}

void CoreGraphicsCanvasImpl::saveState() {
    CGContextSaveGState(currentLayer()->context());
}

void CoreGraphicsCanvasImpl::restoreState() {
    CGContextRestoreGState(currentLayer()->context());
}

void CoreGraphicsCanvasImpl::fillPath(CanvasPathEnumerator const &enumeratePath, lottie::FillRule fillRule, lottie::Color const &color) {
    if (!addEnumeratedPath(currentLayer()->context(), enumeratePath)) {
        return;
    }
    
    CGFloat components[4] = { color.r, color.g, color.b, color.a };
    CGColorRef nativeColor = CGColorCreate(CGBitmapContextGetColorSpace(currentLayer()->context()), components);
    CGContextSetFillColorWithColor(currentLayer()->context(), nativeColor);
    CFRelease(nativeColor);
    
    switch (fillRule) {
        case lottie::FillRule::EvenOdd: {
            CGContextEOFillPath(currentLayer()->context());
            break;
        }
        default: {
            CGContextFillPath(currentLayer()->context());
            break;
        }
    }
}

void CoreGraphicsCanvasImpl::linearGradientFillPath(CanvasPathEnumerator const &enumeratePath, lottie::FillRule fillRule, Gradient const &gradient, lottie::Vector2D const &start, lottie::Vector2D const &end) {
    CGContextSaveGState(currentLayer()->context());
    
    if (!addEnumeratedPath(currentLayer()->context(), enumeratePath)) {
        CGContextRestoreGState(currentLayer()->context());
        return;
    }
    
    switch (fillRule) {
        case lottie::FillRule::EvenOdd: {
            CGContextEOClip(currentLayer()->context());
            break;
        }
        default: {
            CGContextClip(currentLayer()->context());
            break;
        }
    }
    
    std::vector<double> components;
    components.reserve(gradient.colors().size() + 4);
    
    for (const auto &color : gradient.colors()) {
        components.push_back(color.r);
        components.push_back(color.g);
        components.push_back(color.b);
        components.push_back(color.a);
    }
    
    assert(gradient.colors().size() == gradient.locations().size());
    
    std::vector<double> locations;
    for (const auto location : gradient.locations()) {
        locations.push_back(location);
    }
    
    CGGradientRef nativeGradient = CGGradientCreateWithColorComponents(CGBitmapContextGetColorSpace(currentLayer()->context()), components.data(), locations.data(), locations.size());
    if (nativeGradient) {
        CGContextDrawLinearGradient(currentLayer()->context(), nativeGradient, CGPointMake(start.x, start.y), CGPointMake(end.x, end.y), kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
        CFRelease(nativeGradient);
    }
    
    CGContextResetClip(currentLayer()->context());
    CGContextRestoreGState(currentLayer()->context());
}

void CoreGraphicsCanvasImpl::radialGradientFillPath(CanvasPathEnumerator const &enumeratePath, lottie::FillRule fillRule, Gradient const &gradient, Vector2D const &center, float radius) {
    CGContextSaveGState(currentLayer()->context());
    
    if (!addEnumeratedPath(currentLayer()->context(), enumeratePath)) {
        CGContextRestoreGState(currentLayer()->context());
        return;
    }
    
    switch (fillRule) {
        case lottie::FillRule::EvenOdd: {
            CGContextEOClip(currentLayer()->context());
            break;
        }
        default: {
            CGContextClip(currentLayer()->context());
            break;
        }
    }
    
    std::vector<double> components;
    components.reserve(gradient.colors().size() + 4);
    
    for (const auto &color : gradient.colors()) {
        components.push_back(color.r);
        components.push_back(color.g);
        components.push_back(color.b);
        components.push_back(color.a);
    }
    
    assert(gradient.colors().size() == gradient.locations().size());
    
    std::vector<double> locations;
    for (const auto location : gradient.locations()) {
        locations.push_back(location);
    }
    
    CGGradientRef nativeGradient = CGGradientCreateWithColorComponents(CGBitmapContextGetColorSpace(currentLayer()->context()), components.data(), locations.data(), locations.size());
    if (nativeGradient) {
        CGContextDrawRadialGradient(currentLayer()->context(), nativeGradient, CGPointMake(center.x, center.y), 0.0, CGPointMake(center.x, center.y), radius, kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
        CFRelease(nativeGradient);
    }
    
    CGContextResetClip(currentLayer()->context());
    CGContextRestoreGState(currentLayer()->context());
}

void CoreGraphicsCanvasImpl::strokePath(CanvasPathEnumerator const &enumeratePath, float lineWidth, lottie::LineJoin lineJoin, lottie::LineCap lineCap, float dashPhase, std::vector<float> const &dashPattern, lottie::Color const &color) {
    if (!addEnumeratedPath(currentLayer()->context(), enumeratePath)) {
        return;
    }
    
    CGFloat components[4] = { color.r, color.g, color.b, color.a };
    CGColorRef nativeColor = CGColorCreate(CGBitmapContextGetColorSpace(currentLayer()->context()), components);
    CGContextSetStrokeColorWithColor(currentLayer()->context(), nativeColor);
    CFRelease(nativeColor);
    
    CGContextSetLineWidth(currentLayer()->context(), lineWidth);
    
    switch (lineJoin) {
        case lottie::LineJoin::Miter: {
            CGContextSetLineJoin(currentLayer()->context(), kCGLineJoinMiter);
            break;
        }
        case lottie::LineJoin::Round: {
            CGContextSetLineJoin(currentLayer()->context(), kCGLineJoinRound);
            break;
        }
        case lottie::LineJoin::Bevel: {
            CGContextSetLineJoin(currentLayer()->context(), kCGLineJoinBevel);
            break;
        }
        default: {
            CGContextSetLineJoin(currentLayer()->context(), kCGLineJoinBevel);
            break;
        }
    }
    
    switch (lineCap) {
        case lottie::LineCap::Butt: {
            CGContextSetLineCap(currentLayer()->context(), kCGLineCapButt);
            break;
        }
        case lottie::LineCap::Round: {
            CGContextSetLineCap(currentLayer()->context(), kCGLineCapRound);
            break;
        }
        case lottie::LineCap::Square: {
            CGContextSetLineCap(currentLayer()->context(), kCGLineCapSquare);
            break;
        }
        default: {
            CGContextSetLineCap(currentLayer()->context(), kCGLineCapSquare);
            break;
        }
    }
    
    if (!dashPattern.empty()) {
        std::vector<double> mappedDashPattern;
        for (const auto value : dashPattern) {
            mappedDashPattern.push_back(value);
        }
        CGContextSetLineDash(currentLayer()->context(), dashPhase, mappedDashPattern.data(), mappedDashPattern.size());
    }
    CGContextStrokePath(currentLayer()->context());
}

void CoreGraphicsCanvasImpl::linearGradientStrokePath(CanvasPathEnumerator const &enumeratePath, float lineWidth, lottie::LineJoin lineJoin, lottie::LineCap lineCap, float dashPhase, std::vector<float> const &dashPattern, Gradient const &gradient, lottie::Vector2D const &start, lottie::Vector2D const &end) {
    CGContextSaveGState(currentLayer()->context());
    if (!addEnumeratedPath(currentLayer()->context(), enumeratePath)) {
        CGContextRestoreGState(currentLayer()->context());
        return;
    }
    
    CGContextSetLineWidth(currentLayer()->context(), lineWidth);
    
    switch (lineJoin) {
        case lottie::LineJoin::Miter: {
            CGContextSetLineJoin(currentLayer()->context(), kCGLineJoinMiter);
            break;
        }
        case lottie::LineJoin::Round: {
            CGContextSetLineJoin(currentLayer()->context(), kCGLineJoinRound);
            break;
        }
        case lottie::LineJoin::Bevel: {
            CGContextSetLineJoin(currentLayer()->context(), kCGLineJoinBevel);
            break;
        }
        default: {
            CGContextSetLineJoin(currentLayer()->context(), kCGLineJoinBevel);
            break;
        }
    }
    
    switch (lineCap) {
        case lottie::LineCap::Butt: {
            CGContextSetLineCap(currentLayer()->context(), kCGLineCapButt);
            break;
        }
        case lottie::LineCap::Round: {
            CGContextSetLineCap(currentLayer()->context(), kCGLineCapRound);
            break;
        }
        case lottie::LineCap::Square: {
            CGContextSetLineCap(currentLayer()->context(), kCGLineCapSquare);
            break;
        }
        default: {
            CGContextSetLineCap(currentLayer()->context(), kCGLineCapSquare);
            break;
        }
    }
    
    if (!dashPattern.empty()) {
        std::vector<double> mappedDashPattern;
        for (const auto value : dashPattern) {
            mappedDashPattern.push_back(value);
        }
        CGContextSetLineDash(currentLayer()->context(), dashPhase, mappedDashPattern.data(), mappedDashPattern.size());
    }
    
    CGContextReplacePathWithStrokedPath(currentLayer()->context());
    CGContextClip(currentLayer()->context());
    
    std::vector<double> components;
    components.reserve(gradient.colors().size() + 4);
    
    for (const auto &color : gradient.colors()) {
        components.push_back(color.r);
        components.push_back(color.g);
        components.push_back(color.b);
        components.push_back(color.a);
    }
    
    assert(gradient.colors().size() == gradient.locations().size());
    
    std::vector<double> locations;
    for (const auto location : gradient.locations()) {
        locations.push_back(location);
    }
    
    CGGradientRef nativeGradient = CGGradientCreateWithColorComponents(CGBitmapContextGetColorSpace(currentLayer()->context()), components.data(), locations.data(), locations.size());
    if (nativeGradient) {
        CGContextDrawLinearGradient(currentLayer()->context(), nativeGradient, CGPointMake(start.x, start.y), CGPointMake(end.x, end.y), kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
        CFRelease(nativeGradient);
    }
    
    CGContextResetClip(currentLayer()->context());
    CGContextRestoreGState(currentLayer()->context());
}

void CoreGraphicsCanvasImpl::radialGradientStrokePath(CanvasPathEnumerator const &enumeratePath, float lineWidth, lottie::LineJoin lineJoin, lottie::LineCap lineCap, float dashPhase, std::vector<float> const &dashPattern, Gradient const &gradient, lottie::Vector2D const &startCenter, float startRadius, lottie::Vector2D const &endCenter, float endRadius) {
    CGContextSaveGState(currentLayer()->context());
    if (!addEnumeratedPath(currentLayer()->context(), enumeratePath)) {
        CGContextRestoreGState(currentLayer()->context());
        return;
    }
    
    CGContextSetLineWidth(currentLayer()->context(), lineWidth);
    
    switch (lineJoin) {
        case lottie::LineJoin::Miter: {
            CGContextSetLineJoin(currentLayer()->context(), kCGLineJoinMiter);
            break;
        }
        case lottie::LineJoin::Round: {
            CGContextSetLineJoin(currentLayer()->context(), kCGLineJoinRound);
            break;
        }
        case lottie::LineJoin::Bevel: {
            CGContextSetLineJoin(currentLayer()->context(), kCGLineJoinBevel);
            break;
        }
        default: {
            CGContextSetLineJoin(currentLayer()->context(), kCGLineJoinBevel);
            break;
        }
    }
    
    switch (lineCap) {
        case lottie::LineCap::Butt: {
            CGContextSetLineCap(currentLayer()->context(), kCGLineCapButt);
            break;
        }
        case lottie::LineCap::Round: {
            CGContextSetLineCap(currentLayer()->context(), kCGLineCapRound);
            break;
        }
        case lottie::LineCap::Square: {
            CGContextSetLineCap(currentLayer()->context(), kCGLineCapSquare);
            break;
        }
        default: {
            CGContextSetLineCap(currentLayer()->context(), kCGLineCapSquare);
            break;
        }
    }
    
    if (!dashPattern.empty()) {
        std::vector<double> mappedDashPattern;
        for (const auto value : dashPattern) {
            mappedDashPattern.push_back(value);
        }
        CGContextSetLineDash(currentLayer()->context(), dashPhase, mappedDashPattern.data(), mappedDashPattern.size());
    }
    
    CGContextReplacePathWithStrokedPath(currentLayer()->context());
    CGContextClip(currentLayer()->context());
    
    std::vector<double> components;
    components.reserve(gradient.colors().size() + 4);
    
    for (const auto &color : gradient.colors()) {
        components.push_back(color.r);
        components.push_back(color.g);
        components.push_back(color.b);
        components.push_back(color.a);
    }
    
    assert(gradient.colors().size() == gradient.locations().size());
    
    std::vector<double> locations;
    for (const auto location : gradient.locations()) {
        locations.push_back(location);
    }
    
    CGGradientRef nativeGradient = CGGradientCreateWithColorComponents(CGBitmapContextGetColorSpace(currentLayer()->context()), components.data(), locations.data(), locations.size());
    if (nativeGradient) {
        CGContextDrawRadialGradient(currentLayer()->context(), nativeGradient, CGPointMake(startCenter.x, startCenter.y), startRadius, CGPointMake(endCenter.x, endCenter.y), endRadius, kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
        CFRelease(nativeGradient);
    }
    
    CGContextResetClip(currentLayer()->context());
    CGContextRestoreGState(currentLayer()->context());
}

void CoreGraphicsCanvasImpl::clip(CGRect const &rect) {
    CGContextClipToRect(currentLayer()->context(), CGRectMake(rect.x, rect.y, rect.width, rect.height));
}

bool CoreGraphicsCanvasImpl::clipPath(CanvasPathEnumerator const &enumeratePath, FillRule fillRule, Transform2D const &transform) {
    CGContextSaveGState(currentLayer()->context());
    concatenate(transform);
    
    if (!addEnumeratedPath(currentLayer()->context(), enumeratePath)) {
        CGContextRestoreGState(currentLayer()->context());
        return false;
    }
    CGContextRestoreGState(currentLayer()->context());
    switch (fillRule) {
        case lottie::FillRule::EvenOdd: {
            CGContextEOClip(currentLayer()->context());
            break;
        }
        default: {
            CGContextClip(currentLayer()->context());
            break;
        }
    }
    
    return true;
}

void CoreGraphicsCanvasImpl::concatenate(lottie::Transform2D const &transform) {
    CGContextConcatCTM(currentLayer()->context(), CATransform3DGetAffineTransform(nativeTransform(transform)));
}

std::shared_ptr<CoreGraphicsCanvasImpl::Image> CoreGraphicsCanvasImpl::makeImage() {
    return currentLayer()->makeImage();
}

bool CoreGraphicsCanvasImpl::pushLayer(CGRect const &rect, float alpha, std::optional<Canvas::MaskMode> maskMode) {
    auto currentTransform = fromNativeTransform(CATransform3DMakeAffineTransform(CGContextGetCTM(currentLayer()->context())));
    
    CGRect globalRect(0.0f, 0.0f, 0.0f, 0.0f);
    if (rect == CGRect::veryLarge()) {
        globalRect = CGRect(0.0f, 0.0f, (float)_width, (float)_height);
    } else {
        CGRect transformedRect = rect.applyingTransform(currentTransform);
        
        CGRect integralTransformedRect(
            std::floor(transformedRect.x),
            std::floor(transformedRect.y),
            std::ceil(transformedRect.width + transformedRect.x - floor(transformedRect.x)),
            std::ceil(transformedRect.height + transformedRect.y - floor(transformedRect.y))
        );
        globalRect = integralTransformedRect.intersection(CGRect(0.0, 0.0, (CGFloat)_width, (CGFloat)_height));
    }
    if (globalRect.width <= 0.0f || globalRect.height <= 0.0f) {
        return false;
    }
    
    _layerStack.push_back(std::make_shared<Layer>(globalRect.width, globalRect.height, Layer::Composition(globalRect, alpha, currentTransform, maskMode)));
    concatenate(Transform2D::identity().translated(Vector2D(-globalRect.x, -globalRect.y)));
    concatenate(currentTransform);
    
    return true;
}

void CoreGraphicsCanvasImpl::popLayer() {
    auto layer = _layerStack[_layerStack.size() - 1];
    _layerStack.pop_back();
    
    if (const auto composition = layer->composition()) {
        saveState();
        concatenate(composition->transform.inverted());
        
        CGContextSetAlpha(currentLayer()->context(), composition->alpha);
        
        if (composition->maskMode) {
            switch (composition->maskMode.value()) {
                case Canvas::MaskMode::Normal: {
                    CGContextSetBlendMode(currentLayer()->context(), kCGBlendModeDestinationIn);
                    break;
                }
                case Canvas::MaskMode::Inverse: {
                    CGContextSetBlendMode(currentLayer()->context(), kCGBlendModeDestinationOut);
                    break;
                }
                default: {
                    break;
                }
            }
        }
        
        auto image = layer->makeImage();
        CGContextDrawImage(currentLayer()->context(), CGRectMake(composition->rect.x, composition->rect.y, composition->rect.width, composition->rect.height), ((CoreGraphicsCanvasImpl::Image *)image.get())->nativeImage());
        CGContextSetAlpha(currentLayer()->context(), 1.0);
        CGContextSetBlendMode(currentLayer()->context(), kCGBlendModeNormal);
        
        restoreState();
    }
}

std::shared_ptr<CoreGraphicsCanvasImpl::Layer> &CoreGraphicsCanvasImpl::currentLayer() {
    return _layerStack[_layerStack.size() - 1];
}

}
