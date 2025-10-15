#ifndef CALayer_hpp
#define CALayer_hpp

#include "Lottie/Public/Primitives/Color.hpp"
#include "Lottie/Public/Primitives/Vectors.hpp"
#include "Lottie/Public/Primitives/CGPath.hpp"
#include "Lottie/Private/Model/ShapeItems/Fill.hpp"
#include "Lottie/Private/Model/Layers/LayerModel.hpp"
#include "Lottie/Public/Primitives/DrawingAttributes.hpp"
#include "Lottie/Private/Model/ShapeItems/GradientFill.hpp"

#include <memory>
#include <vector>
#include <functional>

namespace lottie {

enum class CGBlendMode {
    Normal,
    DestinationIn,
    DestinationOut
};

class CGImage {
public:
    virtual ~CGImage() = default;
};

class CGGradient {
public:
    CGGradient(std::vector<Color> const &colors, std::vector<double> const &locations) :
    _colors(colors),
    _locations(locations) {
        assert(_colors.size() == _locations.size());
    }
    
    std::vector<Color> const &colors() const {
        return _colors;
    }
    
    std::vector<double> const &locations() const {
        return _locations;
    }
    
private:
    std::vector<Color> _colors;
    std::vector<double> _locations;
};

class CGContext {
public:
    virtual ~CGContext() = default;
    
    virtual int width() const = 0;
    virtual int height() const = 0;
    
    virtual std::shared_ptr<CGContext> makeLayer(int width, int height) = 0;
    
    virtual void saveState() = 0;
    virtual void restoreState() = 0;
    
    virtual void fillPath(std::shared_ptr<CGPath> const &path, FillRule fillRule, Color const &color) = 0;
    virtual void linearGradientFillPath(std::shared_ptr<CGPath> const &path, FillRule fillRule, CGGradient const &gradient, Vector2D const &start, Vector2D const &end) = 0;
    virtual void radialGradientFillPath(std::shared_ptr<CGPath> const &path, FillRule fillRule, CGGradient const &gradient, Vector2D const &startCenter, double startRadius, Vector2D const &endCenter, double endRadius) = 0;
    
    virtual void strokePath(std::shared_ptr<CGPath> const &path, double lineWidth, LineJoin lineJoin, LineCap lineCap, double dashPhase, std::vector<double> const &dashPattern, Color const &color) = 0;
    virtual void linearGradientStrokePath(std::shared_ptr<CGPath> const &path, double lineWidth, LineJoin lineJoin, LineCap lineCap, double dashPhase, std::vector<double> const &dashPattern, CGGradient const &gradient, Vector2D const &start, Vector2D const &end) = 0;
    virtual void radialGradientStrokePath(std::shared_ptr<CGPath> const &path, double lineWidth, LineJoin lineJoin, LineCap lineCap, double dashPhase, std::vector<double> const &dashPattern, CGGradient const &gradient, Vector2D const &startCenter, double startRadius, Vector2D const &endCenter, double endRadius) = 0;
    
    virtual void fill(CGRect const &rect, Color const &fillColor) = 0;
    virtual void setBlendMode(CGBlendMode blendMode) = 0;
    
    virtual void setAlpha(double alpha) = 0;
    
    virtual void concatenate(CATransform3D const &transform) = 0;
    
    virtual void draw(std::shared_ptr<CGContext> const &other, CGRect const &rect) = 0;
};

class RenderableItem {
public:
    enum class Type {
        Shape,
        GradientFill
    };
    
public:
    RenderableItem() {
    }
    
    virtual ~RenderableItem() = default;
    
    virtual Type type() const = 0;
    virtual CGRect boundingRect() const = 0;
    
    virtual bool isEqual(std::shared_ptr<RenderableItem> rhs) const = 0;
};

class ShapeRenderableItem: public RenderableItem {
public:
    struct Fill {
        Color color;
        FillRule rule;
        
        Fill(Color color_, FillRule rule_) :
        color(color_), rule(rule_) {
        }
        
        bool operator==(Fill const &rhs) const {
            if (color != rhs.color) {
                return false;
            }
            if (rule != rhs.rule) {
                return false;
            }
            return true;
        }
        
        bool operator!=(Fill const &rhs) const {
            return !(*this == rhs);
        }
    };
    
    struct Stroke {
        Color color;
        double lineWidth = 0.0;
        LineJoin lineJoin = LineJoin::Round;
        LineCap lineCap = LineCap::Square;
        double dashPhase = 0.0;
        std::vector<double> dashPattern;
        
        Stroke(
            Color color_,
            double lineWidth_,
            LineJoin lineJoin_,
            LineCap lineCap_,
            double dashPhase_,
            std::vector<double> dashPattern_
        ) :
        color(color_),
        lineWidth(lineWidth_),
        lineJoin(lineJoin_),
        lineCap(lineCap_),
        dashPhase(dashPhase_),
        dashPattern(dashPattern_) {
        }
        
        bool operator==(Stroke const &rhs) const {
            if (color != rhs.color) {
                return false;
            }
            if (lineWidth != rhs.lineWidth) {
                return false;
            }
            if (lineJoin != rhs.lineJoin) {
                return false;
            }
            if (lineCap != rhs.lineCap) {
                return false;
            }
            if (dashPhase != rhs.dashPhase) {
                return false;
            }
            if (dashPattern != rhs.dashPattern) {
                return false;
            }
            return true;
        }
        
        bool operator!=(Stroke const &rhs) const {
            return !(*this == rhs);
        }
    };
    
public:
    ShapeRenderableItem(
        std::shared_ptr<CGPath> path_,
        std::optional<Fill> const &fill_,
        std::optional<Stroke> const &stroke_
    ) :
    path(path_),
    fill(fill_),
    stroke(stroke_) {
    }
    
    virtual Type type() const override {
        return Type::Shape;
    }
    
    virtual CGRect boundingRect() const override {
        if (path) {
            CGRect shapeBounds = path->boundingBox();
            if (stroke) {
                shapeBounds = shapeBounds.insetBy(-stroke->lineWidth / 2.0, -stroke->lineWidth / 2.0);
            }
            return shapeBounds;
        } else {
            return CGRect(0.0, 0.0, 0.0, 0.0);
        }
    }
    
    virtual bool isEqual(std::shared_ptr<RenderableItem> rhs) const override {
        if (rhs->type() != type()) {
            return false;
        }
        ShapeRenderableItem *other = (ShapeRenderableItem *)rhs.get();
        if ((path == nullptr) != (other->path == nullptr)) {
            return false;
        } else if (path) {
            if (!path->isEqual(other->path.get())) {
                return false;
            }
        }
        if (fill != other->fill) {
            return false;
        }
        if (stroke != other->stroke) {
            return false;
        }
        return false;
    }
    
public:
    std::shared_ptr<CGPath> path;
    std::optional<Fill> fill;
    std::optional<Stroke> stroke;
};

class GradientFillRenderableItem: public RenderableItem {
public:
    GradientFillRenderableItem(
        std::shared_ptr<CGPath> path_,
        FillRule pathFillRule_,
        GradientType gradientType_,
        std::vector<Color> const &colors_,
        std::vector<double> const &locations_,
        Vector2D const &start_,
        Vector2D const &end_,
        CGRect bounds_
    ) :
    path(path_),
    pathFillRule(pathFillRule_),
    gradientType(gradientType_),
    colors(colors_),
    locations(locations_),
    start(start_),
    end(end_),
    bounds(bounds_) {
    }
    
    virtual Type type() const override {
        return Type::GradientFill;
    }
    
    virtual CGRect boundingRect() const override {
        return bounds;
    }
    
    virtual bool isEqual(std::shared_ptr<RenderableItem> rhs) const override {
        if (rhs->type() != type()) {
            return false;
        }
        GradientFillRenderableItem *other = (GradientFillRenderableItem *)rhs.get();
        
        if (gradientType != other->gradientType) {
            return false;
        }
        if (colors != other->colors) {
            return false;
        }
        if (locations != other->locations) {
            return false;
        }
        if (start != other->start) {
            return false;
        }
        if (end != other->end) {
            return false;
        }
        if (bounds != other->bounds) {
            return false;
        }
        
        return true;
    }
    
public:
    std::shared_ptr<CGPath> path;
    FillRule pathFillRule;
    GradientType gradientType;
    std::vector<Color> colors;
    std::vector<double> locations;
    Vector2D start;
    Vector2D end;
    CGRect bounds;
};

class RenderTreeNodeContent {
public:
    enum class ShadingType {
        Solid,
        Gradient
    };
    
    class Shading {
    public:
        Shading() {
        }
        
        virtual ~Shading() = default;
        
        virtual ShadingType type() const = 0;
    };
    
    class SolidShading: public Shading {
    public:
        SolidShading(Color const &color_, double opacity_) :
        color(color_),
        opacity(opacity_) {
        }
        
        virtual ShadingType type() const override {
            return ShadingType::Solid;
        }
        
    public:
        Color color;
        double opacity = 0.0;
    };
    
    class GradientShading: public Shading {
    public:
        GradientShading(
            double opacity_,
            GradientType gradientType_,
            std::vector<Color> const &colors_,
            std::vector<double> const &locations_,
            Vector2D const &start_,
            Vector2D const &end_
        ) :
        opacity(opacity_),
        gradientType(gradientType_),
        colors(colors_),
        locations(locations_),
        start(start_),
        end(end_) {
        }
        
        virtual ShadingType type() const override {
            return ShadingType::Gradient;
        }
        
    public:
        double opacity = 0.0;
        GradientType gradientType;
        std::vector<Color> colors;
        std::vector<double> locations;
        Vector2D start;
        Vector2D end;
    };
    
    struct Stroke {
        std::shared_ptr<Shading> shading;
        double lineWidth = 0.0;
        LineJoin lineJoin = LineJoin::Round;
        LineCap lineCap = LineCap::Square;
        double miterLimit = 4.0;
        double dashPhase = 0.0;
        std::vector<double> dashPattern;
        
        Stroke(
            std::shared_ptr<Shading> shading_,
            double lineWidth_,
            LineJoin lineJoin_,
            LineCap lineCap_,
            double miterLimit_,
            double dashPhase_,
            std::vector<double> dashPattern_
        ) :
        shading(shading_),
        lineWidth(lineWidth_),
        lineJoin(lineJoin_),
        lineCap(lineCap_),
        miterLimit(miterLimit_),
        dashPhase(dashPhase_),
        dashPattern(dashPattern_) {
        }
    };
    
    struct Fill {
        std::shared_ptr<Shading> shading;
        FillRule rule;
        
        Fill(
            std::shared_ptr<Shading> shading_,
            FillRule rule_
        ) :
        shading(shading_),
        rule(rule_) {
        }
    };
    
public:
    RenderTreeNodeContent(
        std::vector<BezierPath> paths_,
        std::shared_ptr<Stroke> stroke_,
        std::shared_ptr<Fill> fill_
    ) :
    paths(paths_),
    stroke(stroke_),
    fill(fill_) {
    }
    
public:
    std::vector<BezierPath> paths;
    std::shared_ptr<Stroke> stroke;
    std::shared_ptr<Fill> fill;
};

class RenderTreeNode {
public:
    RenderTreeNode(
        CGRect bounds_,
        Vector2D position_,
        CATransform3D transform_,
        double alpha_,
        bool masksToBounds_,
        bool isHidden_,
        std::shared_ptr<RenderTreeNodeContent> content_,
        std::vector<std::shared_ptr<RenderTreeNode>> subnodes_,
        std::shared_ptr<RenderTreeNode> mask_,
        bool invertMask_
    ) :
    _bounds(bounds_),
    _position(position_),
    _transform(transform_),
    _alpha(alpha_),
    _masksToBounds(masksToBounds_),
    _isHidden(isHidden_),
    _content(content_),
    _subnodes(subnodes_),
    _mask(mask_),
    _invertMask(invertMask_) {
    }
    
    ~RenderTreeNode() {
    }
    
public:
    CGRect const &bounds() const {
        return _bounds;
    }
    
    Vector2D const &position() const {
        return _position;
    }
    
    CATransform3D const &transform() const {
        return _transform;
    }
    
    double alpha() const {
        return _alpha;
    }
    
    bool masksToBounds() const {
        return _masksToBounds;
    }
    
    bool isHidden() const {
        return _isHidden;
    }
    
    std::shared_ptr<RenderTreeNodeContent> const &content() const {
        return _content;
    }
    
    std::vector<std::shared_ptr<RenderTreeNode>> const &subnodes() const {
        return _subnodes;
    }
    
    std::shared_ptr<RenderTreeNode> const &mask() const {
        return _mask;
    }
    
    bool invertMask() const {
        return _invertMask;
    }
    
public:
    CGRect _bounds;
    Vector2D _position;
    CATransform3D _transform = CATransform3D::identity();
    double _alpha = 1.0;
    bool _masksToBounds = false;
    bool _isHidden = false;
    std::shared_ptr<RenderTreeNodeContent> _content;
    std::vector<std::shared_ptr<RenderTreeNode>> _subnodes;
    std::shared_ptr<RenderTreeNode> _mask;
    bool _invertMask = false;
};

class CALayer: public std::enable_shared_from_this<CALayer> {
public:
    CALayer() {
    }
    
    void addSublayer(std::shared_ptr<CALayer> layer) {
        if (layer->_superlayer) {
            layer->_superlayer->removeSublayer(layer.get());
        }
        layer->_superlayer = this;
        _sublayers.push_back(layer);
    }
    
    void insertSublayer(std::shared_ptr<CALayer> layer, int index) {
        if (layer->_superlayer) {
            layer->_superlayer->removeSublayer(layer.get());
        }
        layer->_superlayer = this;
        _sublayers.insert(_sublayers.begin() + index, layer);
    }
    
    void removeFromSuperlayer() {
        if (_superlayer) {
            _superlayer->removeSublayer(this);
        }
    }
    
    bool needsDisplay() const {
        return _needsDisplay;
    }
    void setNeedsDisplay(bool needsDisplay) {
        _needsDisplay = true;
    }
    
    virtual bool implementsDraw() const {
        return false;
    }
    
    virtual bool isInvertedMatte() const {
        return false;
    }
    
    virtual void draw(std::shared_ptr<CGContext> const &context) {
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
    
    Vector2D const &position() const {
        return _position;
    }
    void setPosition(Vector2D const &position) {
        _position = position;
    }
    
    CGRect const &bounds() const {
        return _bounds;
    }
    void setBounds(CGRect const &bounds) {
        _bounds = bounds;
    }
    
    virtual CGRect effectiveBounds() const {
        return bounds();
    }
    
    CATransform3D const &transform() const {
        return _transform;
    }
    void setTransform(CATransform3D const &transform) {
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
    
    std::shared_ptr<CGImage> const &contents() const {
        return _contents;
    }
    void setContents(std::shared_ptr<CGImage> contents) {
        _contents = contents;
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
                layer->_superlayer = nullptr;
                _sublayers.erase(it);
                break;
            }
        }
    }
    
private:
    CALayer *_superlayer = nullptr;
    std::vector<std::shared_ptr<CALayer>> _sublayers;
    bool _needsDisplay = false;
    bool _isHidden = false;
    float _opacity = 1.0;
    Vector2D _position = Vector2D(0.0, 0.0);
    CGRect _bounds = CGRect(0.0, 0.0, 0.0, 0.0);
    CATransform3D _transform = CATransform3D::identity();
    std::shared_ptr<CALayer> _mask;
    bool _masksToBounds = false;
    std::optional<BlendMode> _compositingFilter;
    std::shared_ptr<CGImage> _contents;
};

class CAShapeLayer: public CALayer {
public:
    CAShapeLayer() {
    }
    
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
    
    double lineWidth() const {
        return _lineWidth;
    }
    void setLineWidth(double lineWidth) {
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
    
    double lineDashPhase() const {
        return _lineDashPhase;
    }
    void setLineDashPhase(double lineDashPhase) {
        _lineDashPhase = lineDashPhase;
    }
    
    std::vector<double> const &dashPattern() const {
        return _dashPattern;
    }
    void setDashPattern(std::vector<double> const &dashPattern) {
        _dashPattern = dashPattern;
    }
    
    virtual CGRect effectiveBounds() const override {
        if (_path) {
            CGRect boundingBox = _path->boundingBox();
            if (_strokeColor) {
                boundingBox.x -= _lineWidth / 2.0;
                boundingBox.y -= _lineWidth / 2.0;
                boundingBox.width += _lineWidth;
                boundingBox.height += _lineWidth;
            }
            return boundingBox;
        } else {
            return CGRect(0.0, 0.0, 0.0, 0.0);
        }
    }
    
    /*virtual bool implementsDraw() const override {
        return true;
    }
    
    virtual void draw(std::shared_ptr<CGContext> const &context) override;*/
    
    std::shared_ptr<RenderableItem> renderableItem() override;
    
private:
    std::optional<Color> _strokeColor;
    std::optional<Color> _fillColor = Color(0.0, 0.0, 0.0, 1.0);
    FillRule _fillRule = FillRule::NonZeroWinding;
    std::shared_ptr<CGPath> _path;
    double _lineWidth = 1.0;
    LineJoin _lineJoin = LineJoin::Miter;
    LineCap _lineCap = LineCap::Butt;
    double _lineDashPhase = 0.0;
    std::vector<double> _dashPattern;
};

}

#endif /* CALayer_hpp */
