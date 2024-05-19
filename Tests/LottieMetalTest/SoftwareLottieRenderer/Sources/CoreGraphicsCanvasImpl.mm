#include "CoreGraphicsCanvasImpl.h"

namespace lottieRendering {

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

ImageImpl::ImageImpl(::CGImageRef image) {
    _image = CGImageRetain(image);
}

ImageImpl::~ImageImpl() {
    CFRelease(_image);
}

::CGImageRef ImageImpl::nativeImage() const {
    return _image;
}


CanvasImpl::CanvasImpl(int width, int height) {
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

CanvasImpl::CanvasImpl(CGContextRef context, int width, int height) {
    _topContext = CGContextRetain(context);
    _layer = CGLayerCreateWithContext(context, CGSizeMake(width, height), nil);
    _context = CGContextRetain(CGLayerGetContext(_layer));
    _width = width;
    _height = height;
}

CanvasImpl::~CanvasImpl() {
    CFRelease(_context);
    if (_topContext) {
        CFRelease(_topContext);
    }
    if (_layer) {
        CFRelease(_layer);
    }
}

int CanvasImpl::width() const {
    return _width;
}

int CanvasImpl::height() const {
    return _height;
}

std::shared_ptr<Canvas> CanvasImpl::makeLayer(int width, int height) {
    return std::make_shared<CanvasImpl>(_topContext, width, height);
}

void CanvasImpl::saveState() {
    CGContextSaveGState(_context);
}

void CanvasImpl::restoreState() {
    CGContextRestoreGState(_context);
}

void CanvasImpl::fillPath(CanvasPathEnumerator const &enumeratePath, lottie::FillRule fillRule, lottie::Color const &color) {
    if (!addEnumeratedPath(_context, enumeratePath)) {
        return;
    }
    
    CGFloat components[4] = { color.r, color.g, color.b, color.a };
    CGColorRef nativeColor = CGColorCreate(CGBitmapContextGetColorSpace(_topContext), components);
    CGContextSetFillColorWithColor(_context, nativeColor);
    CFRelease(nativeColor);
    
    switch (fillRule) {
        case lottie::FillRule::EvenOdd: {
            CGContextEOFillPath(_context);
            break;
        }
        default: {
            CGContextFillPath(_context);
            break;
        }
    }
}

void CanvasImpl::linearGradientFillPath(CanvasPathEnumerator const &enumeratePath, lottie::FillRule fillRule, Gradient const &gradient, lottie::Vector2D const &start, lottie::Vector2D const &end) {
    CGContextSaveGState(_context);
    
    if (!addEnumeratedPath(_context, enumeratePath)) {
        CGContextRestoreGState(_context);
        return;
    }
    
    switch (fillRule) {
        case lottie::FillRule::EvenOdd: {
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
    
    std::vector<double> locations;
    for (const auto location : gradient.locations()) {
        locations.push_back(location);
    }
    
    CGGradientRef nativeGradient = CGGradientCreateWithColorComponents(CGBitmapContextGetColorSpace(_topContext), components.data(), locations.data(), locations.size());
    if (nativeGradient) {
        CGContextDrawLinearGradient(_context, nativeGradient, CGPointMake(start.x, start.y), CGPointMake(end.x, end.y), kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
        CFRelease(nativeGradient);
    }
    
    CGContextResetClip(_context);
    CGContextRestoreGState(_context);
}

void CanvasImpl::radialGradientFillPath(CanvasPathEnumerator const &enumeratePath, lottie::FillRule fillRule, Gradient const &gradient, lottie::Vector2D const &startCenter, float startRadius, lottie::Vector2D const &endCenter, float endRadius) {
    CGContextSaveGState(_context);
    
    if (!addEnumeratedPath(_context, enumeratePath)) {
        CGContextRestoreGState(_context);
        return;
    }
    
    switch (fillRule) {
        case lottie::FillRule::EvenOdd: {
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
    
    std::vector<double> locations;
    for (const auto location : gradient.locations()) {
        locations.push_back(location);
    }
    
    CGGradientRef nativeGradient = CGGradientCreateWithColorComponents(CGBitmapContextGetColorSpace(_topContext), components.data(), locations.data(), locations.size());
    if (nativeGradient) {
        CGContextDrawRadialGradient(_context, nativeGradient, CGPointMake(startCenter.x, startCenter.y), startRadius, CGPointMake(endCenter.x, endCenter.y), endRadius, kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
        CFRelease(nativeGradient);
    }
    
    CGContextResetClip(_context);
    CGContextRestoreGState(_context);
}

void CanvasImpl::strokePath(CanvasPathEnumerator const &enumeratePath, float lineWidth, lottie::LineJoin lineJoin, lottie::LineCap lineCap, float dashPhase, std::vector<float> const &dashPattern, lottie::Color const &color) {
    if (!addEnumeratedPath(_context, enumeratePath)) {
        return;
    }
    
    CGFloat components[4] = { color.r, color.g, color.b, color.a };
    CGColorRef nativeColor = CGColorCreate(CGBitmapContextGetColorSpace(_topContext), components);
    CGContextSetStrokeColorWithColor(_context, nativeColor);
    CFRelease(nativeColor);
    
    CGContextSetLineWidth(_context, lineWidth);
    
    switch (lineJoin) {
        case lottie::LineJoin::Miter: {
            CGContextSetLineJoin(_context, kCGLineJoinMiter);
            break;
        }
        case lottie::LineJoin::Round: {
            CGContextSetLineJoin(_context, kCGLineJoinRound);
            break;
        }
        case lottie::LineJoin::Bevel: {
            CGContextSetLineJoin(_context, kCGLineJoinBevel);
            break;
        }
        default: {
            CGContextSetLineJoin(_context, kCGLineJoinBevel);
            break;
        }
    }
    
    switch (lineCap) {
        case lottie::LineCap::Butt: {
            CGContextSetLineCap(_context, kCGLineCapButt);
            break;
        }
        case lottie::LineCap::Round: {
            CGContextSetLineCap(_context, kCGLineCapRound);
            break;
        }
        case lottie::LineCap::Square: {
            CGContextSetLineCap(_context, kCGLineCapSquare);
            break;
        }
        default: {
            CGContextSetLineCap(_context, kCGLineCapSquare);
            break;
        }
    }
    
    if (!dashPattern.empty()) {
        std::vector<double> mappedDashPattern;
        for (const auto value : dashPattern) {
            mappedDashPattern.push_back(value);
        }
        CGContextSetLineDash(_context, dashPhase, mappedDashPattern.data(), mappedDashPattern.size());
    }
    CGContextStrokePath(_context);
}

void CanvasImpl::linearGradientStrokePath(CanvasPathEnumerator const &enumeratePath, float lineWidth, lottie::LineJoin lineJoin, lottie::LineCap lineCap, float dashPhase, std::vector<float> const &dashPattern, Gradient const &gradient, lottie::Vector2D const &start, lottie::Vector2D const &end) {
    CGContextSaveGState(_context);
    if (!addEnumeratedPath(_context, enumeratePath)) {
        CGContextRestoreGState(_context);
        return;
    }
    
    CGContextSetLineWidth(_context, lineWidth);
    
    switch (lineJoin) {
        case lottie::LineJoin::Miter: {
            CGContextSetLineJoin(_context, kCGLineJoinMiter);
            break;
        }
        case lottie::LineJoin::Round: {
            CGContextSetLineJoin(_context, kCGLineJoinRound);
            break;
        }
        case lottie::LineJoin::Bevel: {
            CGContextSetLineJoin(_context, kCGLineJoinBevel);
            break;
        }
        default: {
            CGContextSetLineJoin(_context, kCGLineJoinBevel);
            break;
        }
    }
    
    switch (lineCap) {
        case lottie::LineCap::Butt: {
            CGContextSetLineCap(_context, kCGLineCapButt);
            break;
        }
        case lottie::LineCap::Round: {
            CGContextSetLineCap(_context, kCGLineCapRound);
            break;
        }
        case lottie::LineCap::Square: {
            CGContextSetLineCap(_context, kCGLineCapSquare);
            break;
        }
        default: {
            CGContextSetLineCap(_context, kCGLineCapSquare);
            break;
        }
    }
    
    if (!dashPattern.empty()) {
        std::vector<double> mappedDashPattern;
        for (const auto value : dashPattern) {
            mappedDashPattern.push_back(value);
        }
        CGContextSetLineDash(_context, dashPhase, mappedDashPattern.data(), mappedDashPattern.size());
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
    
    std::vector<double> locations;
    for (const auto location : gradient.locations()) {
        locations.push_back(location);
    }
    
    CGGradientRef nativeGradient = CGGradientCreateWithColorComponents(CGBitmapContextGetColorSpace(_topContext), components.data(), locations.data(), locations.size());
    if (nativeGradient) {
        CGContextDrawLinearGradient(_context, nativeGradient, CGPointMake(start.x, start.y), CGPointMake(end.x, end.y), kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
        CFRelease(nativeGradient);
    }
    
    CGContextResetClip(_context);
    CGContextRestoreGState(_context);
}

void CanvasImpl::radialGradientStrokePath(CanvasPathEnumerator const &enumeratePath, float lineWidth, lottie::LineJoin lineJoin, lottie::LineCap lineCap, float dashPhase, std::vector<float> const &dashPattern, Gradient const &gradient, lottie::Vector2D const &startCenter, float startRadius, lottie::Vector2D const &endCenter, float endRadius) {
    CGContextSaveGState(_context);
    if (!addEnumeratedPath(_context, enumeratePath)) {
        CGContextRestoreGState(_context);
        return;
    }
    
    CGContextSetLineWidth(_context, lineWidth);
    
    switch (lineJoin) {
        case lottie::LineJoin::Miter: {
            CGContextSetLineJoin(_context, kCGLineJoinMiter);
            break;
        }
        case lottie::LineJoin::Round: {
            CGContextSetLineJoin(_context, kCGLineJoinRound);
            break;
        }
        case lottie::LineJoin::Bevel: {
            CGContextSetLineJoin(_context, kCGLineJoinBevel);
            break;
        }
        default: {
            CGContextSetLineJoin(_context, kCGLineJoinBevel);
            break;
        }
    }
    
    switch (lineCap) {
        case lottie::LineCap::Butt: {
            CGContextSetLineCap(_context, kCGLineCapButt);
            break;
        }
        case lottie::LineCap::Round: {
            CGContextSetLineCap(_context, kCGLineCapRound);
            break;
        }
        case lottie::LineCap::Square: {
            CGContextSetLineCap(_context, kCGLineCapSquare);
            break;
        }
        default: {
            CGContextSetLineCap(_context, kCGLineCapSquare);
            break;
        }
    }
    
    if (!dashPattern.empty()) {
        std::vector<double> mappedDashPattern;
        for (const auto value : dashPattern) {
            mappedDashPattern.push_back(value);
        }
        CGContextSetLineDash(_context, dashPhase, mappedDashPattern.data(), mappedDashPattern.size());
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
    
    std::vector<double> locations;
    for (const auto location : gradient.locations()) {
        locations.push_back(location);
    }
    
    CGGradientRef nativeGradient = CGGradientCreateWithColorComponents(CGBitmapContextGetColorSpace(_topContext), components.data(), locations.data(), locations.size());
    if (nativeGradient) {
        CGContextDrawRadialGradient(_context, nativeGradient, CGPointMake(startCenter.x, startCenter.y), startRadius, CGPointMake(endCenter.x, endCenter.y), endRadius, kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
        CFRelease(nativeGradient);
    }
    
    CGContextResetClip(_context);
    CGContextRestoreGState(_context);
}

void CanvasImpl::fill(lottie::CGRect const &rect, lottie::Color const &fillColor) {
    CGFloat components[4] = { fillColor.r, fillColor.g, fillColor.b, fillColor.a };
    CGColorRef nativeColor = CGColorCreate(CGBitmapContextGetColorSpace(_topContext), components);
    CGContextSetFillColorWithColor(_context, nativeColor);
    CFRelease(nativeColor);
    
    CGContextFillRect(_context, CGRectMake(rect.x, rect.y, rect.width, rect.height));
}

void CanvasImpl::setBlendMode(BlendMode blendMode) {
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
    CGContextSetBlendMode(_context, nativeMode);
}

void CanvasImpl::setAlpha(float alpha) {
    CGContextSetAlpha(_context, alpha);
}

void CanvasImpl::concatenate(lottie::Transform2D const &transform) {
    CGContextConcatCTM(_context, CATransform3DGetAffineTransform(nativeTransform(transform)));
}

std::shared_ptr<Image> CanvasImpl::makeImage() const {
    ::CGImageRef nativeImage = CGBitmapContextCreateImage(_context);
    if (nativeImage) {
        auto image = std::make_shared<ImageImpl>(nativeImage);
        CFRelease(nativeImage);
        return image;
    } else {
        return nil;
    }
}

void CanvasImpl::draw(std::shared_ptr<Canvas> const &other, lottie::CGRect const &rect) {
    CanvasImpl *impl = (CanvasImpl *)other.get();
    if (impl->_layer) {
        CGContextDrawLayerInRect(_context, CGRectMake(rect.x, rect.y, rect.width, rect.height), impl->_layer);
    } else {
        auto image = impl->makeImage();
        CGContextDrawImage(_context, CGRectMake(rect.x, rect.y, rect.width, rect.height), ((ImageImpl *)image.get())->nativeImage());
    }
}

}

