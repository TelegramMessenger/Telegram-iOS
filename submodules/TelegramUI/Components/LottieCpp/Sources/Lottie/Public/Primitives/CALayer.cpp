#include "CALayer.hpp"

namespace lottie {

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
