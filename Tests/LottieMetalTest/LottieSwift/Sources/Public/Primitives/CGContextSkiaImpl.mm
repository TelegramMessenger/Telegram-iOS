#include "Lottie/Public/Primitives/CGContextSkiaImpl.h"

#include "include/core/SkCanvas.h"
#include "include/core/SkColor.h"
#include "include/core/SkFont.h"
#include "include/core/SkFontTypes.h"
#include "include/core/SkGraphics.h"
#include "include/core/SkPaint.h"
#include "include/core/SkPoint.h"
#include "include/core/SkRect.h"
#include "include/core/SkShader.h"
#include "include/core/SkString.h"
#include "include/core/SkSurface.h"
#include "include/core/SkTileMode.h"
#include "include/core/SkPath.h"
#include "include/core/SkPathEffect.h"
#include "include/effects/SkDashPathEffect.h"
#include "include/effects/SkGradientShader.h"

#include "Lottie/Public/Primitives/CALayerCocoa.h"
#include "Lottie/Public/Primitives/CGPathCocoa.h"

namespace lottie {

namespace {

SkColor skColor(Color const &color) {
    return SkColorSetARGB((uint8_t)(color.a * 255.0), (uint8_t)(color.r * 255.0), (uint8_t)(color.g * 255.0), (uint8_t)(color.b * 255.0));
}

void skPath(std::shared_ptr<CGPath> const &path, SkPath &nativePath) {
    path->enumerate([&nativePath](CGPathItem const &item) {
        switch (item.type) {
            case CGPathItem::Type::MoveTo: {
                nativePath.moveTo(item.points[0].x, item.points[0].y);
                break;
            }
            case CGPathItem::Type::LineTo: {
                nativePath.lineTo(item.points[0].x, item.points[0].y);
                break;
            }
            case CGPathItem::Type::CurveTo: {
                nativePath.cubicTo(item.points[0].x, item.points[0].y, item.points[1].x, item.points[1].y, item.points[2].x, item.points[2].y);
                break;
            }
            case CGPathItem::Type::Close: {
                nativePath.close();
                break;
            }
        }
    });
}

}

CGContextSkiaImpl::CGContextSkiaImpl(int width, int height) :
_width(width), _height(height) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SkGraphics::Init();
    });
    
    //static sk_sp<SkSurface> sharedSurface = SkSurface::MakeRasterN32Premul(width, height);
    //_surface = sharedSurface;
    
    _surface = SkSurface::MakeRasterN32Premul(width, height);
    
    _canvas = _surface->getCanvas();
    _canvas->resetMatrix();
    _canvas->clear(SkColorSetARGB(0, 0, 0, 0));
}

CGContextSkiaImpl::~CGContextSkiaImpl() {
}

int CGContextSkiaImpl::width() const {
    return _width;
}

int CGContextSkiaImpl::height() const {
    return _height;
}

std::shared_ptr<CGContext> CGContextSkiaImpl::makeLayer(int width, int height) {
    return std::make_shared<CGContextSkiaImpl>(width, height);
}

void CGContextSkiaImpl::saveState() {
    _canvas->save();
}

void CGContextSkiaImpl::restoreState() {
    _canvas->restore();
}

void CGContextSkiaImpl::fillPath(std::shared_ptr<CGPath> const &path, FillRule fillRule, Color const &color) {
    SkPaint paint;
    paint.setColor(skColor(color));
    paint.setAlphaf(_alpha);
    paint.setAntiAlias(true);
    paint.setBlendMode(_blendMode);
    
    SkPath nativePath;
    skPath(path, nativePath);
    nativePath.setFillType(fillRule == FillRule::EvenOdd ? SkPathFillType::kEvenOdd : SkPathFillType::kWinding);
    
    _canvas->drawPath(nativePath, paint);
}

void CGContextSkiaImpl::linearGradientFillPath(std::shared_ptr<CGPath> const &path, FillRule fillRule, CGGradient const &gradient, Vector2D const &start, Vector2D const &end) {
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setBlendMode(_blendMode);
    paint.setDither(false);
    paint.setStyle(SkPaint::Style::kFill_Style);
    
    SkPoint linearPoints[2] = {
        SkPoint::Make(start.x, start.y),
        SkPoint::Make(end.x, end.y)
    };
    
    std::vector<SkColor> colors;
    for (const auto &color : gradient.colors()) {
        colors.push_back(skColor(Color(color.r, color.g, color.b, color.a * _alpha)));
    }
    
    std::vector<SkScalar> locations;
    for (auto location : gradient.locations()) {
        locations.push_back(location);
    }
    
    paint.setShader(SkGradientShader::MakeLinear(linearPoints, colors.data(), locations.data(), (int)colors.size(), SkTileMode::kMirror));
    
    SkPath nativePath;
    skPath(path, nativePath);
    nativePath.setFillType(fillRule == FillRule::EvenOdd ? SkPathFillType::kEvenOdd : SkPathFillType::kWinding);
    
    _canvas->drawPath(nativePath, paint);
}

void CGContextSkiaImpl::radialGradientFillPath(std::shared_ptr<CGPath> const &path, FillRule fillRule, CGGradient const &gradient, Vector2D const &startCenter, double startRadius, Vector2D const &endCenter, double endRadius) {
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setBlendMode(_blendMode);
    paint.setDither(false);
    paint.setStyle(SkPaint::Style::kFill_Style);
    
    std::vector<SkColor> colors;
    for (const auto &color : gradient.colors()) {
        colors.push_back(skColor(Color(color.r, color.g, color.b, color.a * _alpha)));
    }
    
    std::vector<SkScalar> locations;
    for (auto location : gradient.locations()) {
        locations.push_back(location);
    }
    
    paint.setShader(SkGradientShader::MakeRadial(SkPoint::Make(startCenter.x, startCenter.y), endRadius, colors.data(), locations.data(), (int)colors.size(), SkTileMode::kMirror));
    
    SkPath nativePath;
    skPath(path, nativePath);
    nativePath.setFillType(fillRule == FillRule::EvenOdd ? SkPathFillType::kEvenOdd : SkPathFillType::kWinding);
    
    _canvas->drawPath(nativePath, paint);
}

void CGContextSkiaImpl::strokePath(std::shared_ptr<CGPath> const &path, double lineWidth, LineJoin lineJoin, LineCap lineCap, double dashPhase, std::vector<double> const &dashPattern, Color const &color) {
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setBlendMode(_blendMode);
    paint.setColor(skColor(color));
    paint.setAlphaf(_alpha);
    paint.setStyle(SkPaint::Style::kStroke_Style);
    
    paint.setStrokeWidth(lineWidth);
    switch (lineJoin) {
        case LineJoin::Miter: {
            paint.setStrokeJoin(SkPaint::Join::kMiter_Join);
            break;
        }
        case LineJoin::Round: {
            paint.setStrokeJoin(SkPaint::Join::kRound_Join);
            break;
        }
        case LineJoin::Bevel: {
            paint.setStrokeJoin(SkPaint::Join::kBevel_Join);
            break;
        }
        default: {
            paint.setStrokeJoin(SkPaint::Join::kBevel_Join);
            break;
        }
    }
    
    switch (lineCap) {
        case LineCap::Butt: {
            paint.setStrokeCap(SkPaint::Cap::kButt_Cap);
            break;
        }
        case LineCap::Round: {
            paint.setStrokeCap(SkPaint::Cap::kRound_Cap);
            break;
        }
        case LineCap::Square: {
            paint.setStrokeCap(SkPaint::Cap::kSquare_Cap);
            break;
        }
        default: {
            paint.setStrokeCap(SkPaint::Cap::kSquare_Cap);
            break;
        }
    }
    
    if (!dashPattern.empty()) {
        std::vector<SkScalar> intervals;
        intervals.reserve(dashPattern.size());
        for (auto value : dashPattern) {
            intervals.push_back(value);
        }
        paint.setPathEffect(SkDashPathEffect::Make(intervals.data(), (int)intervals.size(), dashPhase));
    }
    
    SkPath nativePath;
    skPath(path, nativePath);
    
    _canvas->drawPath(nativePath, paint);
}

void CGContextSkiaImpl::fill(CGRect const &rect, Color const &fillColor) {
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setColor(skColor(fillColor));
    paint.setAlphaf(_alpha);
    paint.setBlendMode(_blendMode);
    
    _canvas->drawRect(SkRect::MakeXYWH(rect.x, rect.y, rect.width, rect.height), paint);
}

void CGContextSkiaImpl::setBlendMode(CGBlendMode blendMode) {
    switch (blendMode) {
        case CGBlendMode::Normal: {
            _blendMode = SkBlendMode::kSrcOver;
            break;
        }
        case CGBlendMode::DestinationIn: {
            _blendMode = SkBlendMode::kDstIn;
            break;
        }
        case CGBlendMode::DestinationOut: {
            _blendMode = SkBlendMode::kDstOut;
            break;
        }
        default: {
            _blendMode = SkBlendMode::kSrcOver;
            break;
        }
    }
}

void CGContextSkiaImpl::setAlpha(double alpha) {
    _alpha = alpha;
}

void CGContextSkiaImpl::concatenate(CATransform3D const &transform) {
    _canvas->concat(SkM44(
        transform.m11, transform.m21, transform.m31, transform.m41,
        transform.m12, transform.m22, transform.m32, transform.m42,
        transform.m13, transform.m23, transform.m33, transform.m43,
        transform.m14, transform.m24, transform.m34, transform.m44
    ));
}

void CGContextSkiaImpl::draw(std::shared_ptr<CGContext> const &other, CGRect const &rect) {
    CGContextSkiaImpl *impl = (CGContextSkiaImpl *)other.get();
    auto image = impl->surface()->makeImageSnapshot();
    SkPaint paint;
    paint.setBlendMode(_blendMode);
    paint.setAlphaf(_alpha);
    _canvas->drawImageRect(image.get(), SkRect::MakeXYWH(rect.x, rect.y, rect.width, rect.height), SkSamplingOptions(SkFilterMode::kLinear), &paint);
}

sk_sp<SkSurface> CGContextSkiaImpl::surface() const {
    return _surface;
}

}
