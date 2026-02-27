#include "SkiaCanvasImpl.h"

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

#include <cfloat>

namespace lottie {

namespace {

SkColor skColor(Color const &color) {
    return SkColorSetARGB((uint8_t)(color.a * 255.0), (uint8_t)(color.r * 255.0), (uint8_t)(color.g * 255.0), (uint8_t)(color.b * 255.0));
}

void skPath(CanvasPathEnumerator const &enumeratePath, SkPath &nativePath) {
    enumeratePath([&](PathCommand const &command) {
        switch (command.type) {
            case PathCommandType::MoveTo: {
                nativePath.moveTo(command.points[0].x, command.points[0].y);
                break;
            }
            case PathCommandType::LineTo: {
                nativePath.lineTo(command.points[0].x, command.points[0].y);
                break;
            }
            case PathCommandType::CurveTo: {
                nativePath.cubicTo(command.points[0].x, command.points[0].y, command.points[1].x, command.points[1].y, command.points[2].x, command.points[2].y);
                break;
            }
            case PathCommandType::Close: {
                nativePath.close();
                break;
            }
        }
    });
}

SkMatrix skMatrix(Transform2D const &transform) {
    SkScalar m9[9] = {
        transform.rows().columns[0][0], transform.rows().columns[1][0], transform.rows().columns[2][0],
        transform.rows().columns[0][1], transform.rows().columns[1][1], transform.rows().columns[2][1],
        transform.rows().columns[0][2], transform.rows().columns[1][2], transform.rows().columns[2][2]
    };
    SkMatrix matrix;
    matrix.set9(m9);
    return matrix;
}

}

SkiaCanvasImpl::SkiaCanvasImpl(int width, int height) {
    int bytesPerRow = width * 4;
    _pixelData = malloc(bytesPerRow * height);
    _ownsPixelData = true;
    
    _surface = SkSurfaces::WrapPixels(
        SkImageInfo::MakeN32Premul(width, height),
        _pixelData,
        bytesPerRow,
        nullptr
    );
    
    _canvas = _surface->getCanvas();
    _canvas->resetMatrix();
    _canvas->clear(SkColorSetARGB(0, 0, 0, 0));
}

SkiaCanvasImpl::SkiaCanvasImpl(int width, int height, int bytesPerRow, void *pixelData) {
    _pixelData = pixelData;
    _ownsPixelData = false;
    
    _surface = SkSurfaces::WrapPixels(
        SkImageInfo::MakeN32Premul(width, height),
        _pixelData,
        bytesPerRow,
        nullptr
    );
    
    _canvas = _surface->getCanvas();
    _canvas->resetMatrix();
    _canvas->clear(SkColorSetARGB(0, 0, 0, 0));
}

SkiaCanvasImpl::~SkiaCanvasImpl() {
    if (_ownsPixelData) {
        free(_pixelData);
    }
}

void SkiaCanvasImpl::saveState() {
    _canvas->save();
}

void SkiaCanvasImpl::restoreState() {
    _canvas->restore();
}

void SkiaCanvasImpl::fillPath(CanvasPathEnumerator const &enumeratePath, lottie::FillRule fillRule, lottie::Color const &color) {
    SkPaint paint;
    paint.setColor(skColor(color));
    paint.setAntiAlias(true);
    
    SkPath nativePath;
    skPath(enumeratePath, nativePath);
    nativePath.setFillType(fillRule == FillRule::EvenOdd ? SkPathFillType::kEvenOdd : SkPathFillType::kWinding);
    
    _canvas->drawPath(nativePath, paint);
}

void SkiaCanvasImpl::linearGradientFillPath(CanvasPathEnumerator const &enumeratePath, lottie::FillRule fillRule, lottie::Gradient const &gradient, lottie::Vector2D const &start, lottie::Vector2D const &end) {
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setDither(false);
    paint.setStyle(SkPaint::Style::kFill_Style);
    
    SkPoint linearPoints[2] = {
        SkPoint::Make(start.x, start.y),
        SkPoint::Make(end.x, end.y)
    };
    
    std::vector<SkColor> colors;
    for (const auto &color : gradient.colors()) {
        colors.push_back(skColor(Color(color.r, color.g, color.b, color.a)));
    }
    
    std::vector<SkScalar> locations;
    for (auto location : gradient.locations()) {
        locations.push_back(location);
    }
    
    paint.setShader(SkGradientShader::MakeLinear(linearPoints, colors.data(), locations.data(), (int)colors.size(), SkTileMode::kClamp));
    
    SkPath nativePath;
    skPath(enumeratePath, nativePath);
    nativePath.setFillType(fillRule == FillRule::EvenOdd ? SkPathFillType::kEvenOdd : SkPathFillType::kWinding);
    
    _canvas->drawPath(nativePath, paint);
}

void SkiaCanvasImpl::radialGradientFillPath(CanvasPathEnumerator const &enumeratePath, lottie::FillRule fillRule, lottie::Gradient const &gradient, Vector2D const &center, float radius) {
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setStyle(SkPaint::Style::kFill_Style);
    
    std::vector<SkColor> colors;
    for (const auto &color : gradient.colors()) {
        colors.push_back(skColor(Color(color.r, color.g, color.b, color.a)));
    }
    
    std::vector<SkScalar> locations;
    for (auto location : gradient.locations()) {
        locations.push_back(location);
    }
    
    paint.setShader(SkGradientShader::MakeRadial(SkPoint::Make(center.x, center.y), radius, colors.data(), locations.data(), (int)colors.size(), SkTileMode::kClamp));
    
    SkPath nativePath;
    skPath(enumeratePath, nativePath);
    nativePath.setFillType(fillRule == FillRule::EvenOdd ? SkPathFillType::kEvenOdd : SkPathFillType::kWinding);
    
    _canvas->drawPath(nativePath, paint);
}

void SkiaCanvasImpl::strokePath(CanvasPathEnumerator const &enumeratePath, float lineWidth, lottie::LineJoin lineJoin, lottie::LineCap lineCap, float dashPhase, std::vector<float> const &dashPattern, lottie::Color const &color) {
    if (lineWidth <= FLT_EPSILON) {
        return;
    }
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setColor(skColor(color));
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
        if (intervals.size() == 1) {
            intervals.push_back(intervals[0]);
        }
        paint.setPathEffect(SkDashPathEffect::Make(intervals.data(), (int)intervals.size(), dashPhase));
    }
    
    SkPath nativePath;
    skPath(enumeratePath, nativePath);
    
    _canvas->drawPath(nativePath, paint);
}

void SkiaCanvasImpl::linearGradientStrokePath(CanvasPathEnumerator const &enumeratePath, float lineWidth, lottie::LineJoin lineJoin, lottie::LineCap lineCap, float dashPhase, std::vector<float> const &dashPattern, Gradient const &gradient, lottie::Vector2D const &start, lottie::Vector2D const &end) {
    assert(false);
}

void SkiaCanvasImpl::radialGradientStrokePath(CanvasPathEnumerator const &enumeratePath, float lineWidth, lottie::LineJoin lineJoin, lottie::LineCap lineCap, float dashPhase, std::vector<float> const &dashPattern, Gradient const &gradient, lottie::Vector2D const &startCenter, float startRadius, lottie::Vector2D const &endCenter, float endRadius) {
    assert(false);
}

void SkiaCanvasImpl::clip(CGRect const &rect) {
    _canvas->clipRect(SkRect::MakeXYWH(rect.x, rect.y, rect.width, rect.height), true);
}

bool SkiaCanvasImpl::clipPath(CanvasPathEnumerator const &enumeratePath, FillRule fillRule, Transform2D const &transform) {
    SkPath nativePath;
    skPath(enumeratePath, nativePath);
    nativePath.setFillType(fillRule == FillRule::EvenOdd ? SkPathFillType::kEvenOdd : SkPathFillType::kWinding);
    if (!transform.isIdentity()) {
        nativePath.transform(skMatrix(transform));
    }
    _canvas->clipPath(nativePath, true);
    
    return true;
}

void SkiaCanvasImpl::concatenate(lottie::Transform2D const &transform) {
    _canvas->concat(skMatrix(transform));
}

bool SkiaCanvasImpl::pushLayer(CGRect const &rect, float alpha, std::optional<MaskMode> maskMode) {
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setAlphaf(alpha);
    if (maskMode) {
        switch (maskMode.value()) {
            case Canvas::MaskMode::Normal: {
                paint.setBlendMode(SkBlendMode::kDstIn);
                break;
            }
            case Canvas::MaskMode::Inverse: {
                paint.setBlendMode(SkBlendMode::kDstOut);
                break;
            }
            default: {
                break;
            }
        }
    }
    
    _canvas->saveLayer(SkRect::MakeXYWH(rect.x, rect.y, rect.width, rect.height), &paint);
    return true;
}

void SkiaCanvasImpl::popLayer() {
    _canvas->restore();
}

void SkiaCanvasImpl::flush() {
}

sk_sp<SkSurface> SkiaCanvasImpl::surface() const {
    return _surface;
}

}
