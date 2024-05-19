#include "NullCanvasImpl.h"

namespace lottieRendering {

namespace {

void addEnumeratedPath(CanvasPathEnumerator const &enumeratePath) {
    enumeratePath([&](PathCommand const &command) {
    });
}

}

NullCanvasImpl::NullCanvasImpl(int width, int height) :
_width(width), _height(height), _transform(lottie::Transform2D::identity()) {
}

NullCanvasImpl::~NullCanvasImpl() {
}

int NullCanvasImpl::width() const {
    return _width;
}

int NullCanvasImpl::height() const {
    return _height;
}

std::shared_ptr<Canvas> NullCanvasImpl::makeLayer(int width, int height) {
    return std::make_shared<NullCanvasImpl>(width, height);
}

void NullCanvasImpl::saveState() {
}

void NullCanvasImpl::restoreState() {
}

void NullCanvasImpl::fillPath(CanvasPathEnumerator const &enumeratePath, lottie::FillRule fillRule, lottie::Color const &color) {
    addEnumeratedPath(enumeratePath);
}

void NullCanvasImpl::linearGradientFillPath(CanvasPathEnumerator const &enumeratePath, lottie::FillRule fillRule, Gradient const &gradient, lottie::Vector2D const &start, lottie::Vector2D const &end) {
    addEnumeratedPath(enumeratePath);
}

void NullCanvasImpl::radialGradientFillPath(CanvasPathEnumerator const &enumeratePath, lottie::FillRule fillRule, Gradient const &gradient, lottie::Vector2D const &startCenter, float startRadius, lottie::Vector2D const &endCenter, float endRadius) {
    addEnumeratedPath(enumeratePath);
}

void NullCanvasImpl::strokePath(CanvasPathEnumerator const &enumeratePath, float lineWidth, lottie::LineJoin lineJoin, lottie::LineCap lineCap, float dashPhase, std::vector<float> const &dashPattern, lottie::Color const &color) {
    addEnumeratedPath(enumeratePath);
}

void NullCanvasImpl::linearGradientStrokePath(CanvasPathEnumerator const &enumeratePath, float lineWidth, lottie::LineJoin lineJoin, lottie::LineCap lineCap, float dashPhase, std::vector<float> const &dashPattern, Gradient const &gradient, lottie::Vector2D const &start, lottie::Vector2D const &end) {
    addEnumeratedPath(enumeratePath);
}

void NullCanvasImpl::radialGradientStrokePath(CanvasPathEnumerator const &enumeratePath, float lineWidth, lottie::LineJoin lineJoin, lottie::LineCap lineCap, float dashPhase, std::vector<float> const &dashPattern, Gradient const &gradient, lottie::Vector2D const &startCenter, float startRadius, lottie::Vector2D const &endCenter, float endRadius) {
    addEnumeratedPath(enumeratePath);
}

void NullCanvasImpl::fill(lottie::CGRect const &rect, lottie::Color const &fillColor) {
}

void NullCanvasImpl::setBlendMode(BlendMode blendMode) {
}

void NullCanvasImpl::setAlpha(float alpha) {
}

void NullCanvasImpl::concatenate(lottie::Transform2D const &transform) {
}

void NullCanvasImpl::draw(std::shared_ptr<Canvas> const &other, lottie::CGRect const &rect) {
}

void NullCanvasImpl::flush() {
}

}
