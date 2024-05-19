#include "ThorVGCanvasImpl.h"

namespace lottieRendering {

namespace {

void tvgPath(CanvasPathEnumerator const &enumeratePath, tvg::Shape *shape) {
    enumeratePath([&](PathCommand const &command) {
        switch (command.type) {
            case PathCommandType::MoveTo: {
                shape->moveTo(command.points[0].x, command.points[0].y);
                break;
            }
            case PathCommandType::LineTo: {
                shape->lineTo(command.points[0].x, command.points[0].y);
                break;
            }
            case PathCommandType::CurveTo: {
                shape->cubicTo(command.points[0].x, command.points[0].y, command.points[1].x, command.points[1].y, command.points[2].x, command.points[2].y);
                break;
            }
            case PathCommandType::Close: {
                shape->close();
                break;
            }
        }
    });
}

tvg::Matrix tvgTransform(lottie::Transform2D const &transform) {
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
_width(width), _height(height), _transform(lottie::Transform2D::identity()) {
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

void ThorVGCanvasImpl::fillPath(CanvasPathEnumerator const &enumeratePath, lottie::FillRule fillRule, lottie::Color const &color) {
    auto shape = tvg::Shape::gen();
    tvgPath(enumeratePath, shape.get());
    
    shape->transform(tvgTransform(_transform));
    
    shape->fill((int)(color.r * 255.0), (int)(color.g * 255.0), (int)(color.b * 255.0), (int)(color.a * _alpha * 255.0));
    shape->fill(fillRule == lottie::FillRule::EvenOdd ? tvg::FillRule::EvenOdd : tvg::FillRule::Winding);
    
    _canvas->push(std::move(shape));
}

void ThorVGCanvasImpl::linearGradientFillPath(CanvasPathEnumerator const &enumeratePath, lottie::FillRule fillRule, Gradient const &gradient, lottie::Vector2D const &start, lottie::Vector2D const &end) {
    auto shape = tvg::Shape::gen();
    tvgPath(enumeratePath, shape.get());
    
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

void ThorVGCanvasImpl::radialGradientFillPath(CanvasPathEnumerator const &enumeratePath, lottie::FillRule fillRule, Gradient const &gradient, lottie::Vector2D const &startCenter, float startRadius, lottie::Vector2D const &endCenter, float endRadius) {
    auto shape = tvg::Shape::gen();
    tvgPath(enumeratePath, shape.get());
    
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

void ThorVGCanvasImpl::strokePath(CanvasPathEnumerator const &enumeratePath, float lineWidth, lottie::LineJoin lineJoin, lottie::LineCap lineCap, float dashPhase, std::vector<float> const &dashPattern, lottie::Color const &color) {
    auto shape = tvg::Shape::gen();
    tvgPath(enumeratePath, shape.get());
    
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

void ThorVGCanvasImpl::linearGradientStrokePath(CanvasPathEnumerator const &enumeratePath, float lineWidth, lottie::LineJoin lineJoin, lottie::LineCap lineCap, float dashPhase, std::vector<float> const &dashPattern, Gradient const &gradient, lottie::Vector2D const &start, lottie::Vector2D const &end) {
}

void ThorVGCanvasImpl::radialGradientStrokePath(CanvasPathEnumerator const &enumeratePath, float lineWidth, lottie::LineJoin lineJoin, lottie::LineCap lineCap, float dashPhase, std::vector<float> const &dashPattern, Gradient const &gradient, lottie::Vector2D const &startCenter, float startRadius, lottie::Vector2D const &endCenter, float endRadius) {
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

void ThorVGCanvasImpl::concatenate(lottie::Transform2D const &transform) {
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
