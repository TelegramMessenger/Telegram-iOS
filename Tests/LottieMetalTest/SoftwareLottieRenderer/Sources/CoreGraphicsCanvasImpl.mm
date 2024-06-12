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
    explicit Layer(int width, int height) {
        _width = width;
        _height = height;
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
    
public:
    CGContextRef _context = nil;
    int _width = 0;
    int _height = 0;
    int _bytesPerRow = 0;
    std::vector<uint8_t> _backingData;
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

CoreGraphicsCanvasImpl::CoreGraphicsCanvasImpl(int width, int height) {
    _layerStack.push_back(std::make_shared<Layer>(width, height));
    _topContext = CGContextRetain(currentLayer()->context());
}

CoreGraphicsCanvasImpl::CoreGraphicsCanvasImpl(CGContextRef context, int width, int height) {
    _layerStack.push_back(std::make_shared<Layer>(width, height));
    _topContext = CGContextRetain(context);
}

CoreGraphicsCanvasImpl::~CoreGraphicsCanvasImpl() {
    if (_topContext) {
        CFRelease(_topContext);
    }
}

std::shared_ptr<Canvas> CoreGraphicsCanvasImpl::makeLayer(int width, int height) {
    return std::make_shared<CoreGraphicsCanvasImpl>(_topContext, width, height);
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
    CGColorRef nativeColor = CGColorCreate(CGBitmapContextGetColorSpace(_topContext), components);
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
    
    CGGradientRef nativeGradient = CGGradientCreateWithColorComponents(CGBitmapContextGetColorSpace(_topContext), components.data(), locations.data(), locations.size());
    if (nativeGradient) {
        CGContextDrawLinearGradient(currentLayer()->context(), nativeGradient, CGPointMake(start.x, start.y), CGPointMake(end.x, end.y), kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
        CFRelease(nativeGradient);
    }
    
    CGContextResetClip(currentLayer()->context());
    CGContextRestoreGState(currentLayer()->context());
}

void CoreGraphicsCanvasImpl::radialGradientFillPath(CanvasPathEnumerator const &enumeratePath, lottie::FillRule fillRule, Gradient const &gradient, lottie::Vector2D const &startCenter, float startRadius, lottie::Vector2D const &endCenter, float endRadius) {
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
    
    CGGradientRef nativeGradient = CGGradientCreateWithColorComponents(CGBitmapContextGetColorSpace(_topContext), components.data(), locations.data(), locations.size());
    if (nativeGradient) {
        CGContextDrawRadialGradient(currentLayer()->context(), nativeGradient, CGPointMake(startCenter.x, startCenter.y), startRadius, CGPointMake(endCenter.x, endCenter.y), endRadius, kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
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
    CGColorRef nativeColor = CGColorCreate(CGBitmapContextGetColorSpace(_topContext), components);
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
    
    CGGradientRef nativeGradient = CGGradientCreateWithColorComponents(CGBitmapContextGetColorSpace(_topContext), components.data(), locations.data(), locations.size());
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
    
    CGGradientRef nativeGradient = CGGradientCreateWithColorComponents(CGBitmapContextGetColorSpace(_topContext), components.data(), locations.data(), locations.size());
    if (nativeGradient) {
        CGContextDrawRadialGradient(currentLayer()->context(), nativeGradient, CGPointMake(startCenter.x, startCenter.y), startRadius, CGPointMake(endCenter.x, endCenter.y), endRadius, kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
        CFRelease(nativeGradient);
    }
    
    CGContextResetClip(currentLayer()->context());
    CGContextRestoreGState(currentLayer()->context());
}

void CoreGraphicsCanvasImpl::fill(lottie::CGRect const &rect, lottie::Color const &fillColor) {
    CGFloat components[4] = { fillColor.r, fillColor.g, fillColor.b, fillColor.a };
    CGColorRef nativeColor = CGColorCreate(CGBitmapContextGetColorSpace(_topContext), components);
    CGContextSetFillColorWithColor(currentLayer()->context(), nativeColor);
    CFRelease(nativeColor);
    
    CGContextFillRect(currentLayer()->context(), CGRectMake(rect.x, rect.y, rect.width, rect.height));
}

void CoreGraphicsCanvasImpl::setBlendMode(BlendMode blendMode) {
    ::CGBlendMode nativeMode = kCGBlendModeNormal;
    switch (blendMode) {
        case BlendMode::Normal: {
            nativeMode = kCGBlendModeNormal;
            break;
        }
        case BlendMode::DestinationIn: {
            nativeMode = kCGBlendModeDestinationIn;
            break;
        }
        case BlendMode::DestinationOut: {
            nativeMode = kCGBlendModeDestinationOut;
            break;
        }
    }
    CGContextSetBlendMode(currentLayer()->context(), nativeMode);
}

void CoreGraphicsCanvasImpl::concatenate(lottie::Transform2D const &transform) {
    CGContextConcatCTM(currentLayer()->context(), CATransform3DGetAffineTransform(nativeTransform(transform)));
}

std::shared_ptr<CoreGraphicsCanvasImpl::Image> CoreGraphicsCanvasImpl::makeImage() {
    ::CGImageRef nativeImage = CGBitmapContextCreateImage(currentLayer()->context());
    if (nativeImage) {
        auto image = std::make_shared<CoreGraphicsCanvasImpl::Image>(nativeImage);
        CFRelease(nativeImage);
        return image;
    } else {
        return nil;
    }
}

void CoreGraphicsCanvasImpl::draw(std::shared_ptr<Canvas> const &other, float alpha, lottie::CGRect const &rect) {
    CGContextSetAlpha(currentLayer()->context(), alpha);
    CoreGraphicsCanvasImpl *impl = (CoreGraphicsCanvasImpl *)other.get();
    auto image = impl->makeImage();
    CGContextDrawImage(currentLayer()->context(), CGRectMake(rect.x, rect.y, rect.width, rect.height), ((CoreGraphicsCanvasImpl::Image *)image.get())->nativeImage());
    CGContextSetAlpha(currentLayer()->context(), 1.0);
}

void CoreGraphicsCanvasImpl::pushLayer(CGRect const &rect) {
}

void CoreGraphicsCanvasImpl::popLayer() {
    
}

std::shared_ptr<CoreGraphicsCanvasImpl::Layer> &CoreGraphicsCanvasImpl::currentLayer() {
    return _layerStack[_layerStack.size() - 1];
}

}
