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

}

SkiaCanvasImpl::SkiaCanvasImpl(int width, int height) :
_width(width), _height(height) {
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

int SkiaCanvasImpl::width() const {
    return _width;
}

int SkiaCanvasImpl::height() const {
    return _height;
}

std::shared_ptr<Canvas> SkiaCanvasImpl::makeLayer(int width, int height) {
    return std::make_shared<SkiaCanvasImpl>(width, height);
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
    paint.setAlphaf(_alpha);
    paint.setAntiAlias(true);
    paint.setBlendMode(_blendMode);
    
    SkPath nativePath;
    skPath(enumeratePath, nativePath);
    nativePath.setFillType(fillRule == FillRule::EvenOdd ? SkPathFillType::kEvenOdd : SkPathFillType::kWinding);
    
    _canvas->drawPath(nativePath, paint);
}

void SkiaCanvasImpl::linearGradientFillPath(CanvasPathEnumerator const &enumeratePath, lottie::FillRule fillRule, lottie::Gradient const &gradient, lottie::Vector2D const &start, lottie::Vector2D const &end) {
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
    skPath(enumeratePath, nativePath);
    nativePath.setFillType(fillRule == FillRule::EvenOdd ? SkPathFillType::kEvenOdd : SkPathFillType::kWinding);
    
    _canvas->drawPath(nativePath, paint);
}

void SkiaCanvasImpl::radialGradientFillPath(CanvasPathEnumerator const &enumeratePath, lottie::FillRule fillRule, lottie::Gradient const &gradient, lottie::Vector2D const &startCenter, float startRadius, lottie::Vector2D const &endCenter, float endRadius) {
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
    skPath(enumeratePath, nativePath);
    nativePath.setFillType(fillRule == FillRule::EvenOdd ? SkPathFillType::kEvenOdd : SkPathFillType::kWinding);
    
    _canvas->drawPath(nativePath, paint);
}

void SkiaCanvasImpl::strokePath(CanvasPathEnumerator const &enumeratePath, float lineWidth, lottie::LineJoin lineJoin, lottie::LineCap lineCap, float dashPhase, std::vector<float> const &dashPattern, lottie::Color const &color) {
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
    skPath(enumeratePath, nativePath);
    
    _canvas->drawPath(nativePath, paint);
}

void SkiaCanvasImpl::linearGradientStrokePath(CanvasPathEnumerator const &enumeratePath, float lineWidth, lottie::LineJoin lineJoin, lottie::LineCap lineCap, float dashPhase, std::vector<float> const &dashPattern, Gradient const &gradient, lottie::Vector2D const &start, lottie::Vector2D const &end) {
    assert(false);
}

void SkiaCanvasImpl::radialGradientStrokePath(CanvasPathEnumerator const &enumeratePath, float lineWidth, lottie::LineJoin lineJoin, lottie::LineCap lineCap, float dashPhase, std::vector<float> const &dashPattern, Gradient const &gradient, lottie::Vector2D const &startCenter, float startRadius, lottie::Vector2D const &endCenter, float endRadius) {
    assert(false);
}

void SkiaCanvasImpl::fill(lottie::CGRect const &rect, lottie::Color const &fillColor) {
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setColor(skColor(fillColor));
    paint.setAlphaf(_alpha);
    paint.setBlendMode(_blendMode);
    
    _canvas->drawRect(SkRect::MakeXYWH(rect.x, rect.y, rect.width, rect.height), paint);
}

void SkiaCanvasImpl::setBlendMode(BlendMode blendMode) {
    switch (blendMode) {
        case BlendMode::Normal: {
            _blendMode = SkBlendMode::kSrcOver;
            break;
        }
        case BlendMode::DestinationIn: {
            _blendMode = SkBlendMode::kDstIn;
            break;
        }
        case BlendMode::DestinationOut: {
            _blendMode = SkBlendMode::kDstOut;
            break;
        }
        default: {
            _blendMode = SkBlendMode::kSrcOver;
            break;
        }
    }
}

void SkiaCanvasImpl::setAlpha(float alpha) {
    _alpha = alpha;
}

void SkiaCanvasImpl::concatenate(lottie::Transform2D const &transform) {
    SkScalar m9[9] = {
        transform.rows().columns[0][0], transform.rows().columns[1][0], transform.rows().columns[2][0],
        transform.rows().columns[0][1], transform.rows().columns[1][1], transform.rows().columns[2][1],
        transform.rows().columns[0][2], transform.rows().columns[1][2], transform.rows().columns[2][2]
    };
    SkMatrix matrix;
    matrix.set9(m9);
    _canvas->concat(matrix);
}

void SkiaCanvasImpl::draw(std::shared_ptr<Canvas> const &other, lottie::CGRect const &rect) {
    SkiaCanvasImpl *impl = (SkiaCanvasImpl *)other.get();
    auto image = impl->surface()->makeImageSnapshot();
    SkPaint paint;
    paint.setBlendMode(_blendMode);
    paint.setAlphaf(_alpha);
    _canvas->drawImageRect(image.get(), SkRect::MakeXYWH(rect.x, rect.y, rect.width, rect.height), SkSamplingOptions(SkFilterMode::kLinear), &paint);
}

void SkiaCanvasImpl::flush() {
}

sk_sp<SkSurface> SkiaCanvasImpl::surface() const {
    return _surface;
}

}
