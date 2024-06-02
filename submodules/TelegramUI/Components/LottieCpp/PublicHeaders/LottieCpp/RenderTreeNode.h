#ifndef RenderTreeNode_hpp
#define RenderTreeNode_hpp

#ifdef __cplusplus

#include <LottieCpp/Vectors.h>
#include <LottieCpp/CGPath.h>
#include <LottieCpp/Color.h>
#include <LottieCpp/ShapeAttributes.h>
#include <LottieCpp/BezierPath.h>

#include <optional>

namespace lottie {

class ProcessedRenderTreeNodeData {
public:    
    ProcessedRenderTreeNodeData() {
    }
    
    bool isValid = false;
    bool isInvertedMatte = false;
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
        float lineWidth = 0.0;
        LineJoin lineJoin = LineJoin::Round;
        LineCap lineCap = LineCap::Square;
        float dashPhase = 0.0;
        std::vector<float> dashPattern;
        
        Stroke(
            Color color_,
            float lineWidth_,
            LineJoin lineJoin_,
            LineCap lineCap_,
            float dashPhase_,
            std::vector<float> dashPattern_
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
        std::vector<float> const &locations_,
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
    std::vector<float> locations;
    Vector2D start;
    Vector2D end;
    CGRect bounds;
};

class RenderTreeNodeContentShadingVariant;

struct RenderTreeNodeContentPath {
public:
    explicit RenderTreeNodeContentPath(BezierPath path_) :
    path(path_) {
    }
    
    BezierPath path;
    CGRect bounds = CGRect(0.0, 0.0, 0.0, 0.0);
    bool needsBoundsRecalculation = true;
};

class RenderTreeNodeContentItem {
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
        SolidShading(Color const &color_, float opacity_) :
        color(color_),
        opacity(opacity_) {
        }
        
        virtual ShadingType type() const override {
            return ShadingType::Solid;
        }
        
    public:
        Color color;
        float opacity = 0.0;
    };
    
    class GradientShading: public Shading {
    public:
        GradientShading(
            float opacity_,
            GradientType gradientType_,
            std::vector<Color> const &colors_,
            std::vector<float> const &locations_,
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
        float opacity = 0.0;
        GradientType gradientType;
        std::vector<Color> colors;
        std::vector<float> locations;
        Vector2D start;
        Vector2D end;
    };
    
    struct Stroke {
        std::shared_ptr<Shading> shading;
        float lineWidth = 0.0;
        LineJoin lineJoin = LineJoin::Round;
        LineCap lineCap = LineCap::Square;
        float miterLimit = 4.0;
        float dashPhase = 0.0;
        std::vector<float> dashPattern;
        
        Stroke(
            std::shared_ptr<Shading> shading_,
            float lineWidth_,
            LineJoin lineJoin_,
            LineCap lineCap_,
            float miterLimit_,
            float dashPhase_,
            std::vector<float> dashPattern_
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
    RenderTreeNodeContentItem() {
    }
    
public:
    bool isGroup = false;
    Transform2D transform = Transform2D::identity();
    float alpha = 0.0;
    std::optional<TrimParams> trimParams;
    std::shared_ptr<RenderTreeNodeContentPath> path;
    std::optional<std::vector<BezierPath>> trimmedPaths;
    std::vector<std::shared_ptr<RenderTreeNodeContentShadingVariant>> shadings;
    std::vector<std::shared_ptr<RenderTreeNodeContentItem>> subItems;
    int drawContentCount = 0;
    
    ProcessedRenderTreeNodeData renderData;
};

class RenderTreeNodeContentShadingVariant {
public:
    RenderTreeNodeContentShadingVariant() {
    }
    
public:
    std::shared_ptr<RenderTreeNodeContentItem::Stroke> stroke;
    std::shared_ptr<RenderTreeNodeContentItem::Fill> fill;
    
    size_t subItemLimit = 0;
};

class RenderTreeNode {
public:
    RenderTreeNode(
        Vector2D size_,
        Transform2D transform_,
        float alpha_,
        bool masksToBounds_,
        bool isHidden_,
        std::vector<std::shared_ptr<RenderTreeNode>> subnodes_,
        std::shared_ptr<RenderTreeNode> mask_,
        bool invertMask_
    ) :
    _size(size_),
    _transform(transform_),
    _alpha(alpha_),
    _masksToBounds(masksToBounds_),
    _isHidden(isHidden_),
    _subnodes(subnodes_),
    _mask(mask_),
    _invertMask(invertMask_) {
        for (const auto &subnode : _subnodes) {
            drawContentCount += subnode->drawContentCount;
        }
    }
    
    ~RenderTreeNode() {
    }
    
public:
    Vector2D const &size() const {
        return _size;
    }
    
    Transform2D const &transform() const {
        return _transform;
    }
    
    float alpha() const {
        return _alpha;
    }
    
    bool masksToBounds() const {
        return _masksToBounds;
    }
    
    bool isHidden() const {
        return _isHidden;
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
    Vector2D _size;
    Transform2D _transform = Transform2D::identity();
    float _alpha = 1.0f;
    bool _masksToBounds = false;
    bool _isHidden = false;
    std::shared_ptr<RenderTreeNodeContentItem> _contentItem;
    int drawContentCount = 0;
    std::vector<std::shared_ptr<RenderTreeNode>> _subnodes;
    std::shared_ptr<RenderTreeNode> _mask;
    bool _invertMask = false;
    
    ProcessedRenderTreeNodeData renderData;
};

}

#endif

#endif /* RenderTreeNode_h */
