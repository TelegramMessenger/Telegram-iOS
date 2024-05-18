#include "ThorVGCanvasImpl.h"

namespace lottieRendering {

namespace {

void tvgPath(std::shared_ptr<lottie::CGPath> const &path, tvg::Shape *shape) {
    path->enumerate([shape](lottie::CGPathItem const &item) {
        switch (item.type) {
            case lottie::CGPathItem::Type::MoveTo: {
                shape->moveTo(item.points[0].x, item.points[0].y);
                break;
            }
            case lottie::CGPathItem::Type::LineTo: {
                shape->lineTo(item.points[0].x, item.points[0].y);
                break;
            }
            case lottie::CGPathItem::Type::CurveTo: {
                shape->cubicTo(item.points[0].x, item.points[0].y, item.points[1].x, item.points[1].y, item.points[2].x, item.points[2].y);
                break;
            }
            case lottie::CGPathItem::Type::Close: {
                shape->close();
                break;
            }
        }
    });
}

tvg::Matrix tvgTransform(lottie::CATransform3D const &transform) {
    CGAffineTransform affineTransform = CATransform3DGetAffineTransform(lottie::nativeTransform(transform));
    tvg::Matrix result;
    result.e11 = affineTransform.a;
    result.e21 = affineTransform.b;
    result.e31 = 0.0f;
    result.e12 = affineTransform.c;
    result.e22 = affineTransform.d;
    result.e32 = 0.0f;
    result.e13 = affineTransform.tx;
    result.e23 = affineTransform.ty;
    result.e33 = 1.0f;
    return result;
}

}

ThorVGCanvasImpl::ThorVGCanvasImpl(int width, int height) :
_width(width), _height(height), _transform(lottie::CATransform3D::identity()) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        tvg::Initializer::init(0);
    });
    
    _canvas = tvg::SwCanvas::gen();
    
    _bytesPerRow = width * 4;
    
    static uint32_t *sharedBackingData = (uint32_t *)malloc(_bytesPerRow * height);
    _backingData = sharedBackingData;
    
    _canvas->target(_backingData, _bytesPerRow / 4, width, height, tvg::SwCanvas::ARGB8888);
}

ThorVGCanvasImpl::~ThorVGCanvasImpl() {
}

int ThorVGCanvasImpl::width() const {
    return _width;
}

int ThorVGCanvasImpl::height() const {
    return _height;
}

std::shared_ptr<Canvas> ThorVGCanvasImpl::makeLayer(int width, int height) {
    return std::make_shared<ThorVGCanvasImpl>(width, height);
}

void ThorVGCanvasImpl::saveState() {
    _stateStack.push_back(_transform);
}

void ThorVGCanvasImpl::restoreState() {
    if (_stateStack.empty()) {
        assert(false);
        return;
    }
    _transform = _stateStack[_stateStack.size() - 1];
    _stateStack.pop_back();
}

void ThorVGCanvasImpl::fillPath(std::shared_ptr<lottie::CGPath> const &path, lottie::FillRule fillRule, lottie::Color const &color) {
    auto shape = tvg::Shape::gen();
    tvgPath(path, shape.get());
    
    shape->transform(tvgTransform(_transform));
    
    shape->fill((int)(color.r * 255.0), (int)(color.g * 255.0), (int)(color.b * 255.0), (int)(color.a * _alpha * 255.0));
    shape->fill(fillRule == lottie::FillRule::EvenOdd ? tvg::FillRule::EvenOdd : tvg::FillRule::Winding);
    
    _canvas->push(std::move(shape));
}

void ThorVGCanvasImpl::linearGradientFillPath(std::shared_ptr<lottie::CGPath> const &path, lottie::FillRule fillRule, Gradient const &gradient, lottie::Vector2D const &start, lottie::Vector2D const &end) {
    auto shape = tvg::Shape::gen();
    tvgPath(path, shape.get());
    
    shape->transform(tvgTransform(_transform));
    
    auto fill = tvg::LinearGradient::gen();
    fill->linear(start.x, start.y, end.x, end.y);
    
    std::vector<tvg::Fill::ColorStop> colors;
    for (size_t i = 0; i < gradient.colors().size(); i++) {
        const auto &color = gradient.colors()[i];
        tvg::Fill::ColorStop colorStop;
        colorStop.offset = gradient.locations()[i];
        colorStop.r = (int)(color.r * 255.0);
        colorStop.g = (int)(color.g * 255.0);
        colorStop.b = (int)(color.b * 255.0);
        colorStop.a = (int)(color.a * _alpha * 255.0);
        colors.push_back(colorStop);
    }
    fill->colorStops(colors.data(), (uint32_t)colors.size());
    shape->fill(std::move(fill));
    
    shape->fill(fillRule == lottie::FillRule::EvenOdd ? tvg::FillRule::EvenOdd : tvg::FillRule::Winding);
    
    _canvas->push(std::move(shape));
}

void ThorVGCanvasImpl::radialGradientFillPath(std::shared_ptr<lottie::CGPath> const &path, lottie::FillRule fillRule, Gradient const &gradient, lottie::Vector2D const &startCenter, float startRadius, lottie::Vector2D const &endCenter, float endRadius) {
    auto shape = tvg::Shape::gen();
    tvgPath(path, shape.get());
    
    shape->transform(tvgTransform(_transform));
    
    auto fill = tvg::RadialGradient::gen();
    fill->radial(startCenter.x, startCenter.y, endRadius);
    
    std::vector<tvg::Fill::ColorStop> colors;
    for (size_t i = 0; i < gradient.colors().size(); i++) {
        const auto &color = gradient.colors()[i];
        tvg::Fill::ColorStop colorStop;
        colorStop.offset = gradient.locations()[i];
        colorStop.r = (int)(color.r * 255.0);
        colorStop.g = (int)(color.g * 255.0);
        colorStop.b = (int)(color.b * 255.0);
        colorStop.a = (int)(color.a * _alpha * 255.0);
        colors.push_back(colorStop);
    }
    fill->colorStops(colors.data(), (uint32_t)colors.size());
    shape->fill(std::move(fill));
    
    shape->fill(fillRule == lottie::FillRule::EvenOdd ? tvg::FillRule::EvenOdd : tvg::FillRule::Winding);
    
    _canvas->push(std::move(shape));
}

void ThorVGCanvasImpl::strokePath(std::shared_ptr<lottie::CGPath> const &path, float lineWidth, lottie::LineJoin lineJoin, lottie::LineCap lineCap, float dashPhase, std::vector<float> const &dashPattern, lottie::Color const &color) {
    auto shape = tvg::Shape::gen();
    tvgPath(path, shape.get());
    
    shape->transform(tvgTransform(_transform));
    
    shape->strokeFill((int)(color.r * 255.0), (int)(color.g * 255.0), (int)(color.b * 255.0), (int)(color.a * _alpha * 255.0));
    shape->strokeWidth(lineWidth);
    
    switch (lineJoin) {
        case lottie::LineJoin::Miter: {
            shape->strokeJoin(tvg::StrokeJoin::Miter);
            break;
        }
        case lottie::LineJoin::Round: {
            shape->strokeJoin(tvg::StrokeJoin::Round);
            break;
        }
        case lottie::LineJoin::Bevel: {
            shape->strokeJoin(tvg::StrokeJoin::Bevel);
            break;
        }
        default: {
            shape->strokeJoin(tvg::StrokeJoin::Bevel);
            break;
        }
    }
    
    switch (lineCap) {
        case lottie::LineCap::Butt: {
            shape->strokeCap(tvg::StrokeCap::Butt);
            break;
        }
        case lottie::LineCap::Round: {
            shape->strokeCap(tvg::StrokeCap::Round);
            break;
        }
        case lottie::LineCap::Square: {
            shape->strokeCap(tvg::StrokeCap::Square);
            break;
        }
        default: {
            shape->strokeCap(tvg::StrokeCap::Square);
            break;
        }
    }
    
    if (!dashPattern.empty()) {
        std::vector<float> intervals;
        intervals.reserve(dashPattern.size());
        for (auto value : dashPattern) {
            intervals.push_back(value);
        }
        shape->strokeDash(intervals.data(), (uint32_t)intervals.size());
        //TODO:phase
    }
    
    _canvas->push(std::move(shape));
}

void ThorVGCanvasImpl::linearGradientStrokePath(std::shared_ptr<lottie::CGPath> const &path, float lineWidth, lottie::LineJoin lineJoin, lottie::LineCap lineCap, float dashPhase, std::vector<float> const &dashPattern, Gradient const &gradient, lottie::Vector2D const &start, lottie::Vector2D const &end) {
    assert(false);
}

void ThorVGCanvasImpl::radialGradientStrokePath(std::shared_ptr<lottie::CGPath> const &path, float lineWidth, lottie::LineJoin lineJoin, lottie::LineCap lineCap, float dashPhase, std::vector<float> const &dashPattern, Gradient const &gradient, lottie::Vector2D const &startCenter, float startRadius, lottie::Vector2D const &endCenter, float endRadius) {
    assert(false);
}

void ThorVGCanvasImpl::fill(lottie::CGRect const &rect, lottie::Color const &fillColor) {
    auto shape = tvg::Shape::gen();
    shape->appendRect(rect.x, rect.y, rect.width, rect.height, 0.0f, 0.0f);
    
    shape->transform(tvgTransform(_transform));
    
    shape->fill((int)(fillColor.r * 255.0), (int)(fillColor.g * 255.0), (int)(fillColor.b * 255.0), (int)(fillColor.a * _alpha * 255.0));
    
    _canvas->push(std::move(shape));
}

void ThorVGCanvasImpl::setBlendMode(BlendMode blendMode) {
    /*switch (blendMode) {
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
    }*/
}

void ThorVGCanvasImpl::setAlpha(float alpha) {
    _alpha = alpha;
}

void ThorVGCanvasImpl::concatenate(lottie::CATransform3D const &transform) {
    _transform = transform * _transform;
    /*_canvas->concat(SkM44(
        transform.m11, transform.m21, transform.m31, transform.m41,
        transform.m12, transform.m22, transform.m32, transform.m42,
        transform.m13, transform.m23, transform.m33, transform.m43,
        transform.m14, transform.m24, transform.m34, transform.m44
    ));*/
}

void ThorVGCanvasImpl::draw(std::shared_ptr<Canvas> const &other, lottie::CGRect const &rect) {
    /*ThorVGCanvasImpl *impl = (ThorVGCanvasImpl *)other.get();
    auto image = impl->surface()->makeImageSnapshot();
    SkPaint paint;
    paint.setBlendMode(_blendMode);
    paint.setAlphaf(_alpha);
    _canvas->drawImageRect(image.get(), SkRect::MakeXYWH(rect.x, rect.y, rect.width, rect.height), SkSamplingOptions(SkFilterMode::kLinear), &paint);*/
}

void ThorVGCanvasImpl::flush() {
    _canvas->draw();
    _canvas->sync();
    
    _statsNumStrokes = 0;
}

}
