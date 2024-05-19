#ifndef CALayer_hpp
#define CALayer_hpp

#import <LottieCpp/Color.h>
#include <LottieCpp/Vectors.h>
#include <LottieCpp/CGPath.h>
#include <LottieCpp/RenderTreeNode.h>
#include "Lottie/Private/Model/ShapeItems/Fill.hpp"
#include "Lottie/Private/Model/Layers/LayerModel.hpp"
#include <LottieCpp/ShapeAttributes.h>
#include "Lottie/Private/Model/ShapeItems/GradientFill.hpp"

#include <memory>
#include <vector>
#include <functional>

namespace lottie {

class CALayer: public std::enable_shared_from_this<CALayer> {
public:
    CALayer() {
    }
    
    virtual ~CALayer() = default;
    
    void addSublayer(std::shared_ptr<CALayer> layer) {
        _sublayers.push_back(layer);
    }
    
    void insertSublayer(std::shared_ptr<CALayer> layer, int index) {
        _sublayers.insert(_sublayers.begin() + index, layer);
    }
    
    virtual bool implementsDraw() const {
        return false;
    }
    
    virtual bool isInvertedMatte() const {
        return false;
    }
    
    virtual std::shared_ptr<RenderableItem> renderableItem() {
        return nullptr;
    }
    
    bool isHidden() const {
        return _isHidden;
    }
    void setIsHidden(bool isHidden) {
        _isHidden = isHidden;
    }
    
    float opacity() const {
        return _opacity;
    }
    void setOpacity(float opacity) {
        _opacity = opacity;
    }
    
    Vector2D const &size() const {
        return _size;
    }
    void setSize(Vector2D const &size) {
        _size = size;
    }
    
    Transform2D const &transform() const {
        return _transform;
    }
    void setTransform(Transform2D const &transform) {
        _transform = transform;
    }
    
    std::shared_ptr<CALayer> const &mask() const {
        return _mask;
    }
    void setMask(std::shared_ptr<CALayer> mask) {
        _mask = mask;
    }
    
    bool masksToBounds() const {
        return _masksToBounds;
    }
    void setMasksToBounds(bool masksToBounds) {
        _masksToBounds = masksToBounds;
    }
    
    std::vector<std::shared_ptr<CALayer>> const &sublayers() const {
        return _sublayers;
    }
    
    std::optional<BlendMode> const &compositingFilter() const {
        return _compositingFilter;
    }
    void setCompositingFilter(std::optional<BlendMode> const &compositingFilter) {
        _compositingFilter = compositingFilter;
    }
    
protected:
    template <typename Derived>
    std::shared_ptr<Derived> shared_from_base() {
        return std::static_pointer_cast<Derived>(shared_from_this());
    }
    
private:
    void removeSublayer(CALayer *layer) {
        for (auto it = _sublayers.begin(); it != _sublayers.end(); it++) {
            if (it->get() == layer) {
                _sublayers.erase(it);
                break;
            }
        }
    }
    
private:
    std::vector<std::shared_ptr<CALayer>> _sublayers;
    bool _isHidden = false;
    float _opacity = 1.0;
    Vector2D _size = Vector2D(0.0, 0.0);
    Transform2D _transform = Transform2D::identity();
    std::shared_ptr<CALayer> _mask;
    bool _masksToBounds = false;
    std::optional<BlendMode> _compositingFilter;
};

class CAShapeLayer: public CALayer {
public:
    CAShapeLayer() {
    }
    
    virtual ~CAShapeLayer() = default;
    
    std::optional<Color> const &strokeColor() {
        return _strokeColor;
    }
    void setStrokeColor(std::optional<Color> const &strokeColor) {
        _strokeColor = strokeColor;
    }
    
    std::optional<Color> const &fillColor() {
        return _fillColor;
    }
    void setFillColor(std::optional<Color> const &fillColor) {
        _fillColor = fillColor;
    }
    
    FillRule fillRule() {
        return _fillRule;
    }
    void setFillRule(FillRule fillRule) {
        _fillRule = fillRule;
    }
    
    std::shared_ptr<CGPath> const &path() const {
        return _path;
    }
    void setPath(std::shared_ptr<CGPath> const &path) {
        _path = path;
    }
    
    float lineWidth() const {
        return _lineWidth;
    }
    void setLineWidth(float lineWidth) {
        _lineWidth = lineWidth;
    }
    
    LineJoin lineJoin() const {
        return _lineJoin;
    }
    void setLineJoin(LineJoin lineJoin) {
        _lineJoin = lineJoin;
    }
    
    LineCap lineCap() const {
        return _lineCap;
    }
    void setLineCap(LineCap lineCap) {
        _lineCap = lineCap;
    }
    
    float lineDashPhase() const {
        return _lineDashPhase;
    }
    void setLineDashPhase(float lineDashPhase) {
        _lineDashPhase = lineDashPhase;
    }
    
    std::vector<float> const &dashPattern() const {
        return _dashPattern;
    }
    void setDashPattern(std::vector<float> const &dashPattern) {
        _dashPattern = dashPattern;
    }
    
    std::shared_ptr<RenderableItem> renderableItem() override;
    
private:
    std::optional<Color> _strokeColor;
    std::optional<Color> _fillColor = Color(0.0, 0.0, 0.0, 1.0);
    FillRule _fillRule = FillRule::NonZeroWinding;
    std::shared_ptr<CGPath> _path;
    float _lineWidth = 1.0;
    LineJoin _lineJoin = LineJoin::Miter;
    LineCap _lineCap = LineCap::Butt;
    float _lineDashPhase = 0.0;
    std::vector<float> _dashPattern;
};

}

#endif /* CALayer_hpp */
