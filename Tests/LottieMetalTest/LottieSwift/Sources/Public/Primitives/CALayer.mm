#include "CALayer.hpp"
#include "Lottie/Public/Primitives/CALayerCocoa.h"

#include "Lottie/Public/Primitives/VectorsCocoa.h"
#include "Lottie/Public/Primitives/CGPathCocoa.h"

#import <QuartzCore/QuartzCore.h>

namespace lottie {

namespace {

int alignUp(int size, int align) {
    assert(((align - 1) & align) == 0);

    int alignmentMask = align - 1;
    return (size + alignmentMask) & ~alignmentMask;
}

}

CGImageImpl::CGImageImpl(::CGImageRef image) {
    _image = CGImageRetain(image);
}
    
CGImageImpl::~CGImageImpl() {
    CFRelease(_image);
}
    
::CGImageRef CGImageImpl::nativeImage() const {
    return _image;
}


CGContextImpl::CGContextImpl(int width, int height) {
    _width = width;
    _height = height;
    _bytesPerRow = alignUp(width * 4, 16);
    _backingData.resize(_bytesPerRow * _height);
    memset(_backingData.data(), 0, _backingData.size());
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrder32Host | kCGImageAlphaPremultipliedFirst;
    _context = CGBitmapContextCreate(_backingData.data(), _width, _height, 8, _bytesPerRow, colorSpace, bitmapInfo);
    
    CGContextClearRect(_context, CGRectMake(0.0, 0.0, _width, _height));
    
    //CGContextSetInterpolationQuality(_context, kCGInterpolationLow);
    //CGContextSetAllowsAntialiasing(_context, true);
    //CGContextSetShouldAntialias(_context, true);
    
    CFRelease(colorSpace);
    
    _topContext = CGContextRetain(_context);
}

CGContextImpl::CGContextImpl(CGContextRef context, int width, int height) {
    _topContext = CGContextRetain(context);
    _layer = CGLayerCreateWithContext(context, CGSizeMake(width, height), nil);
    _context = CGContextRetain(CGLayerGetContext(_layer));
    _width = width;
    _height = height;
}

CGContextImpl::~CGContextImpl() {
    CFRelease(_context);
    if (_topContext) {
        CFRelease(_topContext);
    }
    if (_layer) {
        CFRelease(_layer);
    }
}

int CGContextImpl::width() const {
    return _width;
}

int CGContextImpl::height() const {
    return _height;
}

std::shared_ptr<CGContext> CGContextImpl::makeLayer(int width, int height) {
    return std::make_shared<CGContextImpl>(_topContext, width, height);
}

void CGContextImpl::saveState() {
    CGContextSaveGState(_context);
}

void CGContextImpl::restoreState() {
    CGContextRestoreGState(_context);
}

void CGContextImpl::fillPath(std::shared_ptr<CGPath> const &path, FillRule fillRule, Color const &color) {
    CGContextBeginPath(_context);
    CGPathCocoaImpl::withNativePath(path, [context = _context](CGPathRef nativePath) {
        CGContextAddPath(context, nativePath);
    });
    
    CGFloat components[4] = { color.r, color.g, color.b, color.a };
    CGColorRef nativeColor = CGColorCreate(CGBitmapContextGetColorSpace(_topContext), components);
    CGContextSetFillColorWithColor(_context, nativeColor);
    CFRelease(nativeColor);
    
    switch (fillRule) {
        case FillRule::EvenOdd: {
            CGContextEOFillPath(_context);
            break;
        }
        default: {
            CGContextFillPath(_context);
            break;
        }
    }
}

void CGContextImpl::linearGradientFillPath(std::shared_ptr<CGPath> const &path, FillRule fillRule, CGGradient const &gradient, Vector2D const &start, Vector2D const &end) {
    CGContextSaveGState(_context);
    CGContextBeginPath(_context);
    CGPathCocoaImpl::withNativePath(path, [context = _context](CGPathRef nativePath) {
        CGContextAddPath(context, nativePath);
    });
    
    switch (fillRule) {
        case FillRule::EvenOdd: {
            CGContextEOClip(_context);
            break;
        }
        default: {
            CGContextClip(_context);
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
    
    CGGradientRef nativeGradient = CGGradientCreateWithColorComponents(CGBitmapContextGetColorSpace(_topContext), components.data(), gradient.locations().data(), gradient.locations().size());
    if (nativeGradient) {
        CGContextDrawLinearGradient(_context, nativeGradient, CGPointMake(start.x, start.y), CGPointMake(end.x, end.y), kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
        CFRelease(nativeGradient);
    }
    
    CGContextResetClip(_context);
    CGContextRestoreGState(_context);
}

void CGContextImpl::radialGradientFillPath(std::shared_ptr<CGPath> const &path, FillRule fillRule, CGGradient const &gradient, Vector2D const &startCenter, double startRadius, Vector2D const &endCenter, double endRadius) {
    CGContextSaveGState(_context);
    CGContextBeginPath(_context);
    CGPathCocoaImpl::withNativePath(path, [context = _context](CGPathRef nativePath) {
        CGContextAddPath(context, nativePath);
    });
    
    switch (fillRule) {
        case FillRule::EvenOdd: {
            CGContextEOClip(_context);
            break;
        }
        default: {
            CGContextClip(_context);
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
    
    CGGradientRef nativeGradient = CGGradientCreateWithColorComponents(CGBitmapContextGetColorSpace(_topContext), components.data(), gradient.locations().data(), gradient.locations().size());
    if (nativeGradient) {
        CGContextDrawRadialGradient(_context, nativeGradient, CGPointMake(startCenter.x, startCenter.y), startRadius, CGPointMake(endCenter.x, endCenter.y), endRadius, kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
        CFRelease(nativeGradient);
    }
    
    CGContextResetClip(_context);
    CGContextRestoreGState(_context);
}

void CGContextImpl::strokePath(std::shared_ptr<CGPath> const &path, double lineWidth, LineJoin lineJoin, LineCap lineCap, double dashPhase, std::vector<double> const &dashPattern, Color const &color) {
    CGContextBeginPath(_context);
    CGPathCocoaImpl::withNativePath(path, [context = _context](CGPathRef nativePath) {
        CGContextAddPath(context, nativePath);
    });
    
    CGFloat components[4] = { color.r, color.g, color.b, color.a };
    CGColorRef nativeColor = CGColorCreate(CGBitmapContextGetColorSpace(_topContext), components);
    CGContextSetStrokeColorWithColor(_context, nativeColor);
    CFRelease(nativeColor);
    
    CGContextSetLineWidth(_context, lineWidth);
    
    switch (lineJoin) {
        case LineJoin::Miter: {
            CGContextSetLineJoin(_context, kCGLineJoinMiter);
            break;
        }
        case LineJoin::Round: {
            CGContextSetLineJoin(_context, kCGLineJoinRound);
            break;
        }
        case LineJoin::Bevel: {
            CGContextSetLineJoin(_context, kCGLineJoinBevel);
            break;
        }
        default: {
            CGContextSetLineJoin(_context, kCGLineJoinBevel);
            break;
        }
    }
    
    switch (lineCap) {
        case LineCap::Butt: {
            CGContextSetLineCap(_context, kCGLineCapButt);
            break;
        }
        case LineCap::Round: {
            CGContextSetLineCap(_context, kCGLineCapRound);
            break;
        }
        case LineCap::Square: {
            CGContextSetLineCap(_context, kCGLineCapSquare);
            break;
        }
        default: {
            CGContextSetLineCap(_context, kCGLineCapSquare);
            break;
        }
    }
    
    if (!dashPattern.empty()) {
        CGContextSetLineDash(_context, dashPhase, dashPattern.data(), dashPattern.size());
    }
    CGContextStrokePath(_context);
}

void CGContextImpl::linearGradientStrokePath(std::shared_ptr<CGPath> const &path, double lineWidth, LineJoin lineJoin, LineCap lineCap, double dashPhase, std::vector<double> const &dashPattern, CGGradient const &gradient, Vector2D const &start, Vector2D const &end) {
    CGContextSaveGState(_context);
    CGContextBeginPath(_context);
    CGPathCocoaImpl::withNativePath(path, [context = _context](CGPathRef nativePath) {
        CGContextAddPath(context, nativePath);
    });
    
    CGContextSetLineWidth(_context, lineWidth);
    
    switch (lineJoin) {
        case LineJoin::Miter: {
            CGContextSetLineJoin(_context, kCGLineJoinMiter);
            break;
        }
        case LineJoin::Round: {
            CGContextSetLineJoin(_context, kCGLineJoinRound);
            break;
        }
        case LineJoin::Bevel: {
            CGContextSetLineJoin(_context, kCGLineJoinBevel);
            break;
        }
        default: {
            CGContextSetLineJoin(_context, kCGLineJoinBevel);
            break;
        }
    }
    
    switch (lineCap) {
        case LineCap::Butt: {
            CGContextSetLineCap(_context, kCGLineCapButt);
            break;
        }
        case LineCap::Round: {
            CGContextSetLineCap(_context, kCGLineCapRound);
            break;
        }
        case LineCap::Square: {
            CGContextSetLineCap(_context, kCGLineCapSquare);
            break;
        }
        default: {
            CGContextSetLineCap(_context, kCGLineCapSquare);
            break;
        }
    }
    
    if (!dashPattern.empty()) {
        CGContextSetLineDash(_context, dashPhase, dashPattern.data(), dashPattern.size());
    }
    
    CGContextReplacePathWithStrokedPath(_context);
    CGContextClip(_context);

    std::vector<double> components;
    components.reserve(gradient.colors().size() + 4);
    
    for (const auto &color : gradient.colors()) {
        components.push_back(color.r);
        components.push_back(color.g);
        components.push_back(color.b);
        components.push_back(color.a);
    }
    
    assert(gradient.colors().size() == gradient.locations().size());
    
    CGGradientRef nativeGradient = CGGradientCreateWithColorComponents(CGBitmapContextGetColorSpace(_topContext), components.data(), gradient.locations().data(), gradient.locations().size());
    if (nativeGradient) {
        CGContextDrawLinearGradient(_context, nativeGradient, CGPointMake(start.x, start.y), CGPointMake(end.x, end.y), kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
        CFRelease(nativeGradient);
    }
    
    CGContextResetClip(_context);
    CGContextRestoreGState(_context);
}

void CGContextImpl::radialGradientStrokePath(std::shared_ptr<CGPath> const &path, double lineWidth, LineJoin lineJoin, LineCap lineCap, double dashPhase, std::vector<double> const &dashPattern, CGGradient const &gradient, Vector2D const &startCenter, double startRadius, Vector2D const &endCenter, double endRadius) {
    CGContextSaveGState(_context);
    CGContextBeginPath(_context);
    CGPathCocoaImpl::withNativePath(path, [context = _context](CGPathRef nativePath) {
        CGContextAddPath(context, nativePath);
    });
    
    CGContextSetLineWidth(_context, lineWidth);
    
    switch (lineJoin) {
        case LineJoin::Miter: {
            CGContextSetLineJoin(_context, kCGLineJoinMiter);
            break;
        }
        case LineJoin::Round: {
            CGContextSetLineJoin(_context, kCGLineJoinRound);
            break;
        }
        case LineJoin::Bevel: {
            CGContextSetLineJoin(_context, kCGLineJoinBevel);
            break;
        }
        default: {
            CGContextSetLineJoin(_context, kCGLineJoinBevel);
            break;
        }
    }
    
    switch (lineCap) {
        case LineCap::Butt: {
            CGContextSetLineCap(_context, kCGLineCapButt);
            break;
        }
        case LineCap::Round: {
            CGContextSetLineCap(_context, kCGLineCapRound);
            break;
        }
        case LineCap::Square: {
            CGContextSetLineCap(_context, kCGLineCapSquare);
            break;
        }
        default: {
            CGContextSetLineCap(_context, kCGLineCapSquare);
            break;
        }
    }
    
    if (!dashPattern.empty()) {
        CGContextSetLineDash(_context, dashPhase, dashPattern.data(), dashPattern.size());
    }
    
    CGContextReplacePathWithStrokedPath(_context);
    CGContextClip(_context);

    std::vector<double> components;
    components.reserve(gradient.colors().size() + 4);
    
    for (const auto &color : gradient.colors()) {
        components.push_back(color.r);
        components.push_back(color.g);
        components.push_back(color.b);
        components.push_back(color.a);
    }
    
    assert(gradient.colors().size() == gradient.locations().size());
    
    CGGradientRef nativeGradient = CGGradientCreateWithColorComponents(CGBitmapContextGetColorSpace(_topContext), components.data(), gradient.locations().data(), gradient.locations().size());
    if (nativeGradient) {
        CGContextDrawRadialGradient(_context, nativeGradient, CGPointMake(startCenter.x, startCenter.y), startRadius, CGPointMake(endCenter.x, endCenter.y), endRadius, kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
        CFRelease(nativeGradient);
    }
    
    CGContextResetClip(_context);
    CGContextRestoreGState(_context);
}

void CGContextImpl::fill(CGRect const &rect, Color const &fillColor) {
    CGFloat components[4] = { fillColor.r, fillColor.g, fillColor.b, fillColor.a };
    CGColorRef nativeColor = CGColorCreate(CGBitmapContextGetColorSpace(_topContext), components);
    CGContextSetFillColorWithColor(_context, nativeColor);
    CFRelease(nativeColor);
    
    CGContextFillRect(_context, CGRectMake(rect.x, rect.y, rect.width, rect.height));
}

void CGContextImpl::setBlendMode(CGBlendMode blendMode) {
    ::CGBlendMode nativeMode = kCGBlendModeNormal;
    switch (blendMode) {
        case CGBlendMode::Normal: {
            nativeMode = kCGBlendModeNormal;
            break;
        }
        case CGBlendMode::DestinationIn: {
            nativeMode = kCGBlendModeDestinationIn;
            break;
        }
        case CGBlendMode::DestinationOut: {
            nativeMode = kCGBlendModeDestinationOut;
            break;
        }
    }
    CGContextSetBlendMode(_context, nativeMode);
}

void CGContextImpl::setAlpha(double alpha) {
    CGContextSetAlpha(_context, alpha);
}

void CGContextImpl::concatenate(CATransform3D const &transform) {
    CGContextConcatCTM(_context, CATransform3DGetAffineTransform(nativeTransform(transform)));
}

std::shared_ptr<CGImage> CGContextImpl::makeImage() const {
    ::CGImageRef nativeImage = CGBitmapContextCreateImage(_context);
    if (nativeImage) {
        auto image = std::make_shared<CGImageImpl>(nativeImage);
        CFRelease(nativeImage);
        return image;
    } else {
        return nil;
    }
}

void CGContextImpl::draw(std::shared_ptr<CGContext> const &other, CGRect const &rect) {
    CGContextImpl *impl = (CGContextImpl *)other.get();
    if (impl->_layer) {
        CGContextDrawLayerInRect(_context, CGRectMake(rect.x, rect.y, rect.width, rect.height), impl->_layer);
    } else {
        auto image = impl->makeImage();
        CGContextDrawImage(_context, CGRectMake(rect.x, rect.y, rect.width, rect.height), ((CGImageImpl *)image.get())->nativeImage());
    }
}

std::shared_ptr<RenderableItem> CAShapeLayer::renderableItem() {
    if (!_path) {
        return nullptr;
    }
    
    std::optional<ShapeRenderableItem::Fill> fill;
    if (_fillColor) {
        fill = ShapeRenderableItem::Fill(
            _fillColor.value(),
            _fillRule
        );
    }
    
    std::optional<ShapeRenderableItem::Stroke> stroke;
    if (_strokeColor) {
        stroke = ShapeRenderableItem::Stroke(
            _strokeColor.value(),
            _lineWidth,
            _lineJoin,
            _lineCap,
            _lineDashPhase,
            _dashPattern
        );
    }
    
    return std::make_shared<ShapeRenderableItem>(
        _path,
        fill,
        stroke
    );
}

}
