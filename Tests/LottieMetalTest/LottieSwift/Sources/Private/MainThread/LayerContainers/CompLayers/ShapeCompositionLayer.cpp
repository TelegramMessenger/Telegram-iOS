#include "ShapeCompositionLayer.hpp"

#include "Lottie/Private/Model/ShapeItems/Group.hpp"
#include "Lottie/Private/Model/ShapeItems/Ellipse.hpp"
#include "Lottie/Private/Model/ShapeItems/Rectangle.hpp"
#include "Lottie/Private/Model/ShapeItems/Star.hpp"
#include "Lottie/Private/Model/ShapeItems/Shape.hpp"
#include "Lottie/Private/Model/ShapeItems/Trim.hpp"
#include "Lottie/Private/Model/ShapeItems/Stroke.hpp"
#include "Lottie/Private/Model/ShapeItems/GradientStroke.hpp"
#include "Lottie/Private/MainThread/NodeRenderSystem/RenderLayers/GetGradientParameters.hpp"
#include "Lottie/Private/MainThread/NodeRenderSystem/Nodes/RenderNodes/StrokeNode.hpp"
#include "Lottie/Private/MainThread/NodeRenderSystem/NodeProperties/ValueProviders/DashPatternInterpolator.hpp"
#include "Lottie/Private/MainThread/LayerContainers/CompLayers/ShapeUtils/BezierPathUtils.hpp"
#include "Lottie/Private/Model/ShapeItems/ShapeTransform.hpp"

namespace lottie {

class ShapeLayerPresentationTree {
public:
    class FillOutput {
    public:
        FillOutput() {
        }
        ~FillOutput() = default;
        
        virtual void update(AnimationFrameTime frameTime) = 0;
        virtual std::shared_ptr<RenderTreeNodeContent::Fill> fill() = 0;
    };
    
    class SolidFillOutput : public FillOutput {
    public:
        explicit SolidFillOutput(Fill const &fill) :
        rule(fill.fillRule.value_or(FillRule::NonZeroWinding)),
        color(fill.color.keyframes),
        opacity(fill.opacity.keyframes) {
        }
        
        virtual void update(AnimationFrameTime frameTime) override {
            bool hasUpdates = false;
            
            if (color.hasUpdate(frameTime)) {
                hasUpdates = true;
                colorValue = color.value(frameTime);
            }
            
            if (opacity.hasUpdate(frameTime)) {
                hasUpdates = true;
                opacityValue = opacity.value(frameTime).value;
            }
            
            if (!_fill || hasUpdates) {
                auto solid = std::make_shared<RenderTreeNodeContent::SolidShading>(colorValue, opacityValue * 0.01);
                _fill = std::make_shared<RenderTreeNodeContent::Fill>(
                    solid,
                    rule
                );
            }
        }
        
        virtual std::shared_ptr<RenderTreeNodeContent::Fill> fill() override {
            return _fill;
        }
        
    private:
        FillRule rule;
        
        KeyframeInterpolator<Color> color;
        Color colorValue = Color(0.0, 0.0, 0.0, 0.0);
        
        KeyframeInterpolator<Vector1D> opacity;
        double opacityValue = 0.0;
        
        std::shared_ptr<RenderTreeNodeContent::Fill> _fill;
    };
    
    class GradientFillOutput : public FillOutput {
    public:
        explicit GradientFillOutput(GradientFill const &gradientFill) :
        rule(FillRule::NonZeroWinding),
        numberOfColors(gradientFill.numberOfColors),
        gradientType(gradientFill.gradientType),
        colors(gradientFill.colors.keyframes),
        startPoint(gradientFill.startPoint.keyframes),
        endPoint(gradientFill.endPoint.keyframes),
        opacity(gradientFill.opacity.keyframes) {
        }
        
        virtual void update(AnimationFrameTime frameTime) override {
            bool hasUpdates = false;
            
            if (colors.hasUpdate(frameTime)) {
                hasUpdates = true;
                colorsValue = colors.value(frameTime);
            }
            
            if (startPoint.hasUpdate(frameTime)) {
                hasUpdates = true;
                startPointValue = startPoint.value(frameTime);
            }
            
            if (endPoint.hasUpdate(frameTime)) {
                hasUpdates = true;
                endPointValue = endPoint.value(frameTime);
            }
            
            if (opacity.hasUpdate(frameTime)) {
                hasUpdates = true;
                opacityValue = opacity.value(frameTime).value;
            }
            
            if (!_fill || hasUpdates) {
                std::vector<Color> colors;
                std::vector<double> locations;
                getGradientParameters(numberOfColors, colorsValue, colors, locations);
                
                auto gradient = std::make_shared<RenderTreeNodeContent::GradientShading>(
                    opacityValue * 0.01,
                    gradientType,
                    colors,
                    locations,
                    Vector2D(startPointValue.x, startPointValue.y),
                    Vector2D(endPointValue.x, endPointValue.y)
                );
                _fill = std::make_shared<RenderTreeNodeContent::Fill>(
                    gradient,
                    rule
                );
            }
        }
        
        virtual std::shared_ptr<RenderTreeNodeContent::Fill> fill() override {
            return _fill;
        }
        
    private:
        FillRule rule;
        int numberOfColors = 0;
        GradientType gradientType;
        
        KeyframeInterpolator<GradientColorSet> colors;
        GradientColorSet colorsValue;
        
        KeyframeInterpolator<Vector3D> startPoint;
        Vector3D startPointValue = Vector3D(0.0, 0.0, 0.0);
        
        KeyframeInterpolator<Vector3D> endPoint;
        Vector3D endPointValue = Vector3D(0.0, 0.0, 0.0);
        
        KeyframeInterpolator<Vector1D> opacity;
        double opacityValue = 0.0;
        
        std::shared_ptr<RenderTreeNodeContent::Fill> _fill;
    };
    
    class StrokeOutput {
    public:
        StrokeOutput() {
        }
        ~StrokeOutput() = default;
        
        virtual void update(AnimationFrameTime frameTime) = 0;
        virtual std::shared_ptr<RenderTreeNodeContent::Stroke> stroke() = 0;
    };
    
    class SolidStrokeOutput : public StrokeOutput {
    public:
        SolidStrokeOutput(Stroke const &stroke) :
        lineJoin(stroke.lineJoin),
        lineCap(stroke.lineCap),
        miterLimit(stroke.miterLimit.value_or(4.0)),
        color(stroke.color.keyframes),
        opacity(stroke.opacity.keyframes),
        width(stroke.width.keyframes) {
            if (stroke.dashPattern.has_value()) {
                StrokeShapeDashConfiguration dashConfiguration(stroke.dashPattern.value());
                dashPattern = std::make_unique<DashPatternInterpolator>(dashConfiguration.dashPatterns);
                
                if (!dashConfiguration.dashPhase.empty()) {
                    dashPhase = std::make_unique<KeyframeInterpolator<Vector1D>>(dashConfiguration.dashPhase);
                }
            }
        }
        
        virtual void update(AnimationFrameTime frameTime) override {
            bool hasUpdates = false;
            
            if (color.hasUpdate(frameTime)) {
                hasUpdates = true;
                colorValue = color.value(frameTime);
            }
            
            if (opacity.hasUpdate(frameTime)) {
                hasUpdates = true;
                opacityValue = opacity.value(frameTime).value;
            }
            
            if (width.hasUpdate(frameTime)) {
                hasUpdates = true;
                widthValue = width.value(frameTime).value;
            }
            
            if (dashPattern) {
                if (dashPattern->hasUpdate(frameTime)) {
                    hasUpdates = true;
                    dashPatternValue = dashPattern->value(frameTime);
                }
            }
            
            if (dashPhase) {
                if (dashPhase->hasUpdate(frameTime)) {
                    hasUpdates = true;
                    dashPhaseValue = dashPhase->value(frameTime).value;
                }
            }
            
            if (!_stroke || hasUpdates) {
                bool hasNonZeroDashes = false;
                if (!dashPatternValue.values.empty()) {
                    for (const auto &value : dashPatternValue.values) {
                        if (value != 0) {
                            hasNonZeroDashes = true;
                            break;
                        }
                    }
                }
                
                auto solid = std::make_shared<RenderTreeNodeContent::SolidShading>(colorValue, opacityValue * 0.01);
                _stroke = std::make_shared<RenderTreeNodeContent::Stroke>(
                    solid,
                    widthValue,
                    lineJoin,
                    lineCap,
                    miterLimit,
                    hasNonZeroDashes ? dashPhaseValue : 0.0,
                    hasNonZeroDashes ? dashPatternValue.values : std::vector<double>()
                );
            }
        }
        
        virtual std::shared_ptr<RenderTreeNodeContent::Stroke> stroke() override {
            return _stroke;
        }
        
    private:
        LineJoin lineJoin;
        LineCap lineCap;
        double miterLimit = 4.0;
        
        KeyframeInterpolator<Color> color;
        Color colorValue = Color(0.0, 0.0, 0.0, 0.0);
        
        KeyframeInterpolator<Vector1D> opacity;
        double opacityValue = 0.0;
        
        KeyframeInterpolator<Vector1D> width;
        double widthValue = 0.0;
        
        std::unique_ptr<DashPatternInterpolator> dashPattern;
        DashPattern dashPatternValue = DashPattern({});
        
        std::unique_ptr<KeyframeInterpolator<Vector1D>> dashPhase;
        double dashPhaseValue = 0.0;
        
        std::shared_ptr<RenderTreeNodeContent::Stroke> _stroke;
    };
    
    class GradientStrokeOutput : public StrokeOutput {
    public:
        GradientStrokeOutput(GradientStroke const &gradientStroke) :
        lineJoin(gradientStroke.lineJoin),
        lineCap(gradientStroke.lineCap),
        miterLimit(gradientStroke.miterLimit.value_or(4.0)),
        numberOfColors(gradientStroke.numberOfColors),
        gradientType(gradientStroke.gradientType),
        colors(gradientStroke.colors.keyframes),
        startPoint(gradientStroke.startPoint.keyframes),
        endPoint(gradientStroke.endPoint.keyframes),
        opacity(gradientStroke.opacity.keyframes),
        width(gradientStroke.width.keyframes) {
            if (gradientStroke.dashPattern.has_value()) {
                StrokeShapeDashConfiguration dashConfiguration(gradientStroke.dashPattern.value());
                dashPattern = std::make_unique<DashPatternInterpolator>(dashConfiguration.dashPatterns);
                
                if (!dashConfiguration.dashPhase.empty()) {
                    dashPhase = std::make_unique<KeyframeInterpolator<Vector1D>>(dashConfiguration.dashPhase);
                }
            }
        }
        
        virtual void update(AnimationFrameTime frameTime) override {
            bool hasUpdates = false;
            
            if (colors.hasUpdate(frameTime)) {
                hasUpdates = true;
                colorsValue = colors.value(frameTime);
            }
            
            if (startPoint.hasUpdate(frameTime)) {
                hasUpdates = true;
                startPointValue = startPoint.value(frameTime);
            }
            
            if (endPoint.hasUpdate(frameTime)) {
                hasUpdates = true;
                endPointValue = endPoint.value(frameTime);
            }
            
            if (opacity.hasUpdate(frameTime)) {
                hasUpdates = true;
                opacityValue = opacity.value(frameTime).value;
            }
            
            if (width.hasUpdate(frameTime)) {
                hasUpdates = true;
                widthValue = width.value(frameTime).value;
            }
            
            if (dashPattern) {
                if (dashPattern->hasUpdate(frameTime)) {
                    hasUpdates = true;
                    dashPatternValue = dashPattern->value(frameTime);
                }
            }
            
            if (dashPhase) {
                if (dashPhase->hasUpdate(frameTime)) {
                    hasUpdates = true;
                    dashPhaseValue = dashPhase->value(frameTime).value;
                }
            }
            
            if (!_stroke || hasUpdates) {
                bool hasNonZeroDashes = false;
                if (!dashPatternValue.values.empty()) {
                    for (const auto &value : dashPatternValue.values) {
                        if (value != 0) {
                            hasNonZeroDashes = true;
                            break;
                        }
                    }
                }
                
                std::vector<Color> colors;
                std::vector<double> locations;
                getGradientParameters(numberOfColors, colorsValue, colors, locations);
                
                auto gradient = std::make_shared<RenderTreeNodeContent::GradientShading>(
                    opacityValue * 0.01,
                    gradientType,
                    colors,
                    locations,
                    Vector2D(startPointValue.x, startPointValue.y),
                    Vector2D(endPointValue.x, endPointValue.y)
                );
                _stroke = std::make_shared<RenderTreeNodeContent::Stroke>(
                    gradient,
                    widthValue,
                    lineJoin,
                    lineCap,
                    miterLimit,
                    hasNonZeroDashes ? dashPhaseValue : 0.0,
                    hasNonZeroDashes ? dashPatternValue.values : std::vector<double>()
                );
            }
        }
        
        virtual std::shared_ptr<RenderTreeNodeContent::Stroke> stroke() override {
            return _stroke;
        }
        
    private:
        LineJoin lineJoin;
        LineCap lineCap;
        double miterLimit = 4.0;
        
        int numberOfColors = 0;
        GradientType gradientType;
        
        KeyframeInterpolator<GradientColorSet> colors;
        GradientColorSet colorsValue;
        
        KeyframeInterpolator<Vector3D> startPoint;
        Vector3D startPointValue = Vector3D(0.0, 0.0, 0.0);
        
        KeyframeInterpolator<Vector3D> endPoint;
        Vector3D endPointValue = Vector3D(0.0, 0.0, 0.0);
        
        KeyframeInterpolator<Vector1D> opacity;
        double opacityValue = 0.0;
        
        KeyframeInterpolator<Vector1D> width;
        double widthValue = 0.0;
        
        std::unique_ptr<DashPatternInterpolator> dashPattern;
        DashPattern dashPatternValue = DashPattern({});
        
        std::unique_ptr<KeyframeInterpolator<Vector1D>> dashPhase;
        double dashPhaseValue = 0.0;
        
        std::shared_ptr<RenderTreeNodeContent::Stroke> _stroke;
    };
    
    struct TrimParams {
        double start = 0.0;
        double end = 0.0;
        double offset = 0.0;
        TrimType type = TrimType::Simultaneously;
        size_t subItemLimit = 0;
        
        TrimParams(double start_, double end_, double offset_, TrimType type_, size_t subItemLimit_) :
        start(start_),
        end(end_),
        offset(offset_),
        type(type_),
        subItemLimit(subItemLimit_) {
        }
    };
    
    class TrimParamsOutput {
    public:
        TrimParamsOutput(Trim const &trim, size_t subItemLimit) :
        type(trim.trimType),
        subItemLimit(subItemLimit),
        start(trim.start.keyframes),
        end(trim.end.keyframes),
        offset(trim.offset.keyframes) {
        }
        
        void update(AnimationFrameTime frameTime) {
            if (start.hasUpdate(frameTime)) {
                startValue = start.value(frameTime).value;
            }
            
            if (end.hasUpdate(frameTime)) {
                endValue = end.value(frameTime).value;
            }
            
            if (offset.hasUpdate(frameTime)) {
                offsetValue = offset.value(frameTime).value;
            }
        }
        
        TrimParams trimParams() {
            double resolvedStartValue = startValue * 0.01;
            double resolvedEndValue = endValue * 0.01;
            double resolvedStart = std::min(resolvedStartValue, resolvedEndValue);
            double resolvedEnd = std::max(resolvedStartValue, resolvedEndValue);
            
            double resolvedOffset = fmod(offsetValue, 360.0) / 360.0;
            
            return TrimParams(resolvedStart, resolvedEnd, resolvedOffset, type, subItemLimit);
        }
        
    private:
        TrimType type;
        size_t subItemLimit = 0;
        
        KeyframeInterpolator<Vector1D> start;
        double startValue = 0.0;
        
        KeyframeInterpolator<Vector1D> end;
        double endValue = 0.0;
        
        KeyframeInterpolator<Vector1D> offset;
        double offsetValue = 0.0;
    };
    
    struct ShadingVariant {
        std::shared_ptr<FillOutput> fill;
        std::shared_ptr<StrokeOutput> stroke;
        size_t subItemLimit = 0;
        
        std::shared_ptr<RenderTreeNode> renderTree;
    };
    
    struct TransformedPath {
        BezierPath path;
        CATransform3D transform;
        
        TransformedPath(BezierPath const &path_, CATransform3D const &transform_) :
        path(path_),
        transform(transform_) {
        }
    };
    
    class PathOutput {
    public:
        PathOutput() {
        }
        virtual ~PathOutput() = default;
        
        virtual void update(AnimationFrameTime frameTime) = 0;
        virtual BezierPath const *currentPath() = 0;
    };
    
    class StaticPathOutput : public PathOutput {
    public:
        explicit StaticPathOutput(BezierPath const &path) :
        resolvedPath(path) {
        }
        
        virtual void update(AnimationFrameTime frameTime) override {
        }
        
        virtual BezierPath const *currentPath() override {
            return &resolvedPath;
        }
        
    private:
        BezierPath resolvedPath;
    };
    
    class ShapePathOutput : public PathOutput {
    public:
        explicit ShapePathOutput(Shape const &shape) :
        path(shape.path.keyframes) {
        }
        
        virtual void update(AnimationFrameTime frameTime) override {
            if (!hasValidData || path.hasUpdate(frameTime)) {
                path.update(frameTime, resolvedPath);
            }
            
            hasValidData = true;
        }
        
        virtual BezierPath const *currentPath() override {
            return &resolvedPath;
        }
        
    private:
        bool hasValidData = false;
        
        BezierPathKeyframeInterpolator path;
        
        BezierPath resolvedPath;
    };
    
    class RectanglePathOutput : public PathOutput {
    public:
        explicit RectanglePathOutput(Rectangle const &rectangle) :
        direction(rectangle.direction.value_or(PathDirection::Clockwise)),
        position(rectangle.position.keyframes),
        size(rectangle.size.keyframes),
        cornerRadius(rectangle.cornerRadius.keyframes) {
        }
        
        virtual void update(AnimationFrameTime frameTime) override {
            bool hasUpdates = false;
            
            if (!hasValidData || position.hasUpdate(frameTime)) {
                hasUpdates = true;
                positionValue = position.value(frameTime);
            }
            if (!hasValidData || size.hasUpdate(frameTime)) {
                hasUpdates = true;
                sizeValue = size.value(frameTime);
            }
            if (!hasValidData || cornerRadius.hasUpdate(frameTime)) {
                hasUpdates = true;
                cornerRadiusValue = cornerRadius.value(frameTime).value;
            }
            
            if (hasUpdates) {
                resolvedPath = makeRectangleBezierPath(Vector2D(positionValue.x, positionValue.y), Vector2D(sizeValue.x, sizeValue.y), cornerRadiusValue, direction);
            }
            
            hasValidData = true;
        }
        
        virtual BezierPath const *currentPath() override {
            return &resolvedPath;
        }
        
    private:
        bool hasValidData = false;
        
        PathDirection direction;
        
        KeyframeInterpolator<Vector3D> position;
        Vector3D positionValue = Vector3D(0.0, 0.0, 0.0);
        
        KeyframeInterpolator<Vector3D> size;
        Vector3D sizeValue = Vector3D(0.0, 0.0, 0.0);
        
        KeyframeInterpolator<Vector1D> cornerRadius;
        double cornerRadiusValue = 0.0;
        
        BezierPath resolvedPath;
    };
    
    class EllipsePathOutput : public PathOutput {
    public:
        explicit EllipsePathOutput(Ellipse const &ellipse) :
        direction(ellipse.direction.value_or(PathDirection::Clockwise)),
        position(ellipse.position.keyframes),
        size(ellipse.size.keyframes) {
        }
        
        virtual void update(AnimationFrameTime frameTime) override {
            bool hasUpdates = false;
            
            if (!hasValidData || position.hasUpdate(frameTime)) {
                hasUpdates = true;
                positionValue = position.value(frameTime);
            }
            if (!hasValidData || size.hasUpdate(frameTime)) {
                hasUpdates = true;
                sizeValue = size.value(frameTime);
            }
            
            if (hasUpdates) {
                resolvedPath = makeEllipseBezierPath(Vector2D(sizeValue.x, sizeValue.y), Vector2D(positionValue.x, positionValue.y), direction);
            }
            
            hasValidData = true;
        }
        
        virtual BezierPath const *currentPath() override {
            return &resolvedPath;
        }
        
    private:
        bool hasValidData = false;
        
        PathDirection direction;
        
        KeyframeInterpolator<Vector3D> position;
        Vector3D positionValue = Vector3D(0.0, 0.0, 0.0);
        
        KeyframeInterpolator<Vector3D> size;
        Vector3D sizeValue = Vector3D(0.0, 0.0, 0.0);
        
        BezierPath resolvedPath;
    };
    
    class StarPathOutput : public PathOutput {
    public:
        explicit StarPathOutput(Star const &star) :
        direction(star.direction.value_or(PathDirection::Clockwise)),
        position(star.position.keyframes),
        outerRadius(star.outerRadius.keyframes),
        outerRoundedness(star.outerRoundness.keyframes),
        rotation(star.rotation.keyframes),
        points(star.points.keyframes) {
            if (star.innerRadius.has_value()) {
                innerRadius = std::make_unique<NodeProperty<Vector1D>>(std::make_shared<KeyframeInterpolator<Vector1D>>(star.innerRadius->keyframes));
            } else {
                innerRadius = std::make_unique<NodeProperty<Vector1D>>(std::make_shared<SingleValueProvider<Vector1D>>(Vector1D(0.0)));
            }
            
            if (star.innerRoundness.has_value()) {
                innerRoundedness = std::make_unique<NodeProperty<Vector1D>>(std::make_shared<KeyframeInterpolator<Vector1D>>(star.innerRoundness->keyframes));
            } else {
                innerRoundedness = std::make_unique<NodeProperty<Vector1D>>(std::make_shared<SingleValueProvider<Vector1D>>(Vector1D(0.0)));
            }
        }
        
        virtual void update(AnimationFrameTime frameTime) override {
            bool hasUpdates = false;
            
            if (!hasValidData || position.hasUpdate(frameTime)) {
                hasUpdates = true;
                positionValue = position.value(frameTime);
            }
            
            if (!hasValidData || outerRadius.hasUpdate(frameTime)) {
                hasUpdates = true;
                outerRadiusValue = outerRadius.value(frameTime).value;
            }
            
            innerRadius->update(frameTime);
            if (!hasValidData || innerRadiusValue != innerRadius->value().value) {
                hasUpdates = true;
                innerRadiusValue = innerRadius->value().value;
            }
            
            if (!hasValidData || outerRoundedness.hasUpdate(frameTime)) {
                hasUpdates = true;
                outerRoundednessValue = outerRoundedness.value(frameTime).value;
            }
            
            innerRoundedness->update(frameTime);
            if (!hasValidData || innerRoundednessValue != innerRoundedness->value().value) {
                hasUpdates = true;
                innerRoundednessValue = innerRoundedness->value().value;
            }
            
            if (!hasValidData || points.hasUpdate(frameTime)) {
                hasUpdates = true;
                pointsValue = points.value(frameTime).value;
            }
            
            if (!hasValidData || rotation.hasUpdate(frameTime)) {
                hasUpdates = true;
                rotationValue = rotation.value(frameTime).value;
            }
            
            if (hasUpdates) {
                resolvedPath = makeStarBezierPath(Vector2D(positionValue.x, positionValue.y), outerRadiusValue, innerRadiusValue, outerRoundednessValue, innerRoundednessValue, pointsValue, rotationValue, direction);
            }
            
            hasValidData = true;
        }
        
        virtual BezierPath const *currentPath() override {
            return &resolvedPath;
        }
        
    private:
        bool hasValidData = false;
        
        PathDirection direction;
        
        KeyframeInterpolator<Vector3D> position;
        Vector3D positionValue = Vector3D(0.0, 0.0, 0.0);
        
        KeyframeInterpolator<Vector1D> outerRadius;
        double outerRadiusValue = 0.0;
        
        KeyframeInterpolator<Vector1D> outerRoundedness;
        double outerRoundednessValue = 0.0;
        
        std::unique_ptr<NodeProperty<Vector1D>> innerRadius;
        double innerRadiusValue = 0.0;
        
        std::unique_ptr<NodeProperty<Vector1D>> innerRoundedness;
        double innerRoundednessValue = 0.0;
        
        KeyframeInterpolator<Vector1D> rotation;
        double rotationValue = 0.0;
        
        KeyframeInterpolator<Vector1D> points;
        double pointsValue = 0.0;
        
        BezierPath resolvedPath;
    };
    
    class TransformOutput {
    public:
        TransformOutput(std::shared_ptr<ShapeTransform> shapeTransform) {
            if (shapeTransform->anchor) {
                _anchor = std::make_unique<KeyframeInterpolator<Vector3D>>(shapeTransform->anchor->keyframes);
            }
            if (shapeTransform->position) {
                _position = std::make_unique<KeyframeInterpolator<Vector3D>>(shapeTransform->position->keyframes);
            }
            if (shapeTransform->scale) {
                _scale = std::make_unique<KeyframeInterpolator<Vector3D>>(shapeTransform->scale->keyframes);
            }
            if (shapeTransform->rotation) {
                _rotation = std::make_unique<KeyframeInterpolator<Vector1D>>(shapeTransform->rotation->keyframes);
            }
            if (shapeTransform->skew) {
                _skew = std::make_unique<KeyframeInterpolator<Vector1D>>(shapeTransform->skew->keyframes);
            }
            if (shapeTransform->skewAxis) {
                _skewAxis = std::make_unique<KeyframeInterpolator<Vector1D>>(shapeTransform->skewAxis->keyframes);
            }
            if (shapeTransform->opacity) {
                _opacity = std::make_unique<KeyframeInterpolator<Vector1D>>(shapeTransform->opacity->keyframes);
            }
        }
        
        void update(AnimationFrameTime frameTime) {
            bool hasUpdates = false;
            
            if (!hasValidData) {
                hasUpdates = true;
            }
            if (_anchor && _anchor->hasUpdate(frameTime)) {
                hasUpdates = true;
            }
            if (_position && _position->hasUpdate(frameTime)) {
                hasUpdates = true;
            }
            if (_scale && _scale->hasUpdate(frameTime)) {
                hasUpdates = true;
            }
            if (_rotation && _rotation->hasUpdate(frameTime)) {
                hasUpdates = true;
            }
            if (_skew && _skew->hasUpdate(frameTime)) {
                hasUpdates = true;
            }
            if (_skewAxis && _skewAxis->hasUpdate(frameTime)) {
                hasUpdates = true;
            }
            if (_opacity && _opacity->hasUpdate(frameTime)) {
                hasUpdates = true;
            }
            
            if (hasUpdates) {
                //TODO:optimize by storing components
                
                Vector3D anchorValue(0.0, 0.0, 0.0);
                if (_anchor) {
                    anchorValue = _anchor->value(frameTime);
                }
                
                Vector3D positionValue(0.0, 0.0, 0.0);
                if (_position) {
                    positionValue = _position->value(frameTime);
                }
                
                Vector3D scaleValue(100.0, 100.0, 100.0);
                if (_scale) {
                    scaleValue = _scale->value(frameTime);
                }
                
                double rotationValue = 0.0;
                if (_rotation) {
                    rotationValue = _rotation->value(frameTime).value;
                }
                
                double skewValue = 0.0;
                if (_skew) {
                    skewValue = _skew->value(frameTime).value;
                }
                
                double skewAxisValue = 0.0;
                if (_skewAxis) {
                    skewAxisValue = _skewAxis->value(frameTime).value;
                }
                
                if (_opacity) {
                    _opacityValue = _opacity->value(frameTime).value * 0.01;
                } else {
                    _opacityValue = 1.0;
                }
                
                _transformValue = CATransform3D::identity().translated(Vector2D(positionValue.x, positionValue.y)).rotated(rotationValue).skewed(-skewValue, skewAxisValue).scaled(Vector2D(scaleValue.x * 0.01, scaleValue.y * 0.01)).translated(Vector2D(-anchorValue.x, -anchorValue.y));
                
                hasValidData = true;
            }
        }
        
        CATransform3D const &transform() {
            return _transformValue;
        }
        
        double opacity() {
            return _opacityValue;
        }
        
    private:
        bool hasValidData = false;
        
        std::unique_ptr<KeyframeInterpolator<Vector3D>> _anchor;
        std::unique_ptr<KeyframeInterpolator<Vector3D>> _position;
        std::unique_ptr<KeyframeInterpolator<Vector3D>> _scale;
        std::unique_ptr<KeyframeInterpolator<Vector1D>> _rotation;
        std::unique_ptr<KeyframeInterpolator<Vector1D>> _skew;
        std::unique_ptr<KeyframeInterpolator<Vector1D>> _skewAxis;
        std::unique_ptr<KeyframeInterpolator<Vector1D>> _opacity;
        
        CATransform3D _transformValue = CATransform3D::identity();
        double _opacityValue = 1.0;
    };
    
    class ContentItem {
    public:
        ContentItem() {
        }
        
    public:
        bool isGroup = false;
        
        void setPath(std::unique_ptr<PathOutput> &&path_) {
            path = std::move(path_);
        }
        
        void setTransform(std::unique_ptr<TransformOutput> &&transform_) {
            transform = std::move(transform_);
        }
        
        std::shared_ptr<RenderTreeNode> const &renderTree() const {
            return _renderTree;
        }
        
    private:
        std::unique_ptr<PathOutput> path;
        std::unique_ptr<TransformOutput> transform;
        
        std::vector<ShadingVariant> shadings;
        std::vector<std::shared_ptr<TrimParamsOutput>> trims;
        
        std::vector<std::shared_ptr<ContentItem>> subItems;
        
        std::shared_ptr<RenderTreeNode> _renderTree;
        
    private:
        std::vector<TransformedPath> collectPaths(AnimationFrameTime frameTime, size_t subItemLimit, CATransform3D parentTransform) {
            std::vector<TransformedPath> mappedPaths;
            
            CATransform3D effectiveTransform = parentTransform;
            CATransform3D effectiveChildTransform = parentTransform;
            
            size_t maxSubitem = std::min(subItems.size(), subItemLimit);
            
            if (path) {
                path->update(frameTime);
                mappedPaths.emplace_back(*(path->currentPath()), effectiveTransform);
            }
            
            for (size_t i = 0; i < maxSubitem; i++) {
                auto &subItem = subItems[i];
                CATransform3D subItemTransform = effectiveChildTransform;
                
                if (subItem->isGroup && subItem->transform) {
                    subItem->transform->update(frameTime);
                    subItemTransform = subItem->transform->transform() * subItemTransform;
                }
                
                std::optional<TrimParams> currentTrim;
                if (!trims.empty()) {
                    trims[0]->update(frameTime);
                    currentTrim = trims[0]->trimParams();
                }
                
                auto subItemPaths = subItem->collectPaths(frameTime, INT32_MAX, subItemTransform);
                
                if (currentTrim) {
                    CompoundBezierPath tempPath;
                    for (auto &path : subItemPaths) {
                        tempPath.appendPath(path.path.copyUsingTransform(path.transform));
                    }
                    CompoundBezierPath trimmedPath = trimCompoundPath(tempPath, currentTrim->start, currentTrim->end, currentTrim->offset, currentTrim->type);
                    for (auto &path : trimmedPath.paths) {
                        mappedPaths.emplace_back(path, CATransform3D::identity());
                    }
                } else {
                    for (auto &path : subItemPaths) {
                        mappedPaths.emplace_back(path.path, path.transform);
                    }
                }
            }
            
            return mappedPaths;
        }
        
    public:
        void addSubItem(std::shared_ptr<ContentItem> const &subItem) {
            subItems.push_back(subItem);
        }
        
        void addFill(std::shared_ptr<FillOutput> fill) {
            ShadingVariant shading;
            shading.subItemLimit = subItems.size();
            shading.fill = fill;
            shadings.insert(shadings.begin(), shading);
        }
        
        void addStroke(std::shared_ptr<StrokeOutput> stroke) {
            ShadingVariant shading;
            shading.subItemLimit = subItems.size();
            shading.stroke = stroke;
            shadings.insert(shadings.begin(), shading);
        }
        
        void addTrim(Trim const &trim) {
            trims.push_back(std::make_shared<TrimParamsOutput>(trim, subItems.size()));
        }
        
    public:
        void initializeRenderChildren() {
            _renderTree = std::make_shared<RenderTreeNode>(
                CGRect(0.0, 0.0, 0.0, 0.0),
                Vector2D(0.0, 0.0),
                CATransform3D::identity(),
                1.0,
                false,
                false,
                nullptr,
                std::vector<std::shared_ptr<RenderTreeNode>>(),
                nullptr,
                false
            );
            
            if (!shadings.empty()) {
                for (int i = 0; i < shadings.size(); i++) {
                    auto &shadingVariant = shadings[i];
                    
                    if (!(shadingVariant.fill || shadingVariant.stroke)) {
                        continue;
                    }
                    
                    auto shadingRenderTree = std::make_shared<RenderTreeNode>(
                        CGRect(0.0, 0.0, 0.0, 0.0),
                        Vector2D(0.0, 0.0),
                        CATransform3D::identity(),
                        1.0,
                        false,
                        false,
                        nullptr,
                        std::vector<std::shared_ptr<RenderTreeNode>>(),
                        nullptr,
                        false
                    );
                    shadingVariant.renderTree = shadingRenderTree;
                    _renderTree->_subnodes.push_back(shadingRenderTree);
                }
            }
            
            if (isGroup && !subItems.empty()) {
                std::vector<std::shared_ptr<RenderTreeNode>> subItemNodes;
                for (int i = (int)subItems.size() - 1; i >= 0; i--) {
                    subItems[i]->initializeRenderChildren();
                    subItemNodes.push_back(subItems[i]->_renderTree);
                }
                
                if (!subItemNodes.empty()) {
                    _renderTree->_subnodes.push_back(std::make_shared<RenderTreeNode>(
                        CGRect(0.0, 0.0, 0.0, 0.0),
                        Vector2D(0.0, 0.0),
                        CATransform3D::identity(),
                        1.0,
                        false,
                        false,
                        nullptr,
                        subItemNodes,
                        nullptr,
                        false
                    ));
                }
            }
        }
        
    public:
        void renderChildren(AnimationFrameTime frameTime, std::optional<TrimParams> parentTrim) {
            CATransform3D containerTransform = CATransform3D::identity();
            double containerOpacity = 1.0;
            if (transform) {
                transform->update(frameTime);
                containerTransform = transform->transform();
                containerOpacity = transform->opacity();
            }
            _renderTree->_transform = containerTransform;
            _renderTree->_alpha = containerOpacity;
            
            for (int i = 0; i < shadings.size(); i++) {
                const auto &shadingVariant = shadings[i];
                
                if (!(shadingVariant.fill || shadingVariant.stroke)) {
                    continue;
                }
                
                CompoundBezierPath compoundPath;
                auto paths = collectPaths(frameTime, shadingVariant.subItemLimit, CATransform3D::identity());
                for (const auto &path : paths) {
                    compoundPath.appendPath(path.path.copyUsingTransform(path.transform));
                }
                
                //std::optional<TrimParams> currentTrim = parentTrim;
                //TODO:investigate
                /*if (!trims.empty()) {
                    currentTrim = trims[0];
                }*/
                
                if (parentTrim) {
                    compoundPath = trimCompoundPath(compoundPath, parentTrim->start, parentTrim->end, parentTrim->offset, parentTrim->type);
                }
                
                std::vector<BezierPath> resultPaths;
                for (const auto &path : compoundPath.paths) {
                    resultPaths.push_back(path);
                }
                
                std::shared_ptr<RenderTreeNodeContent> content;
                
                std::shared_ptr<RenderTreeNodeContent::Fill> fill;
                if (shadingVariant.fill) {
                    shadingVariant.fill->update(frameTime);
                    fill = shadingVariant.fill->fill();
                }
                
                std::shared_ptr<RenderTreeNodeContent::Stroke> stroke;
                if (shadingVariant.stroke) {
                    shadingVariant.stroke->update(frameTime);
                    stroke = shadingVariant.stroke->stroke();
                }
                
                content = std::make_shared<RenderTreeNodeContent>(
                    resultPaths,
                    stroke,
                    fill
                );
                
                shadingVariant.renderTree->_content = content;
            }
            
            if (isGroup && !subItems.empty()) {
                for (int i = (int)subItems.size() - 1; i >= 0; i--) {
                    std::optional<TrimParams> childTrim = parentTrim;
                    for (const auto &trim : trims) {
                        trim->update(frameTime);
                        
                        if (i < (int)trim->trimParams().subItemLimit) {
                            //TODO:allow combination
                            //assert(!parentTrim);
                            childTrim = trim->trimParams();
                        }
                    }
                    
                    subItems[i]->renderChildren(frameTime, childTrim);
                }
            }
        }
    };
    
public:
    ShapeLayerPresentationTree(std::vector<std::shared_ptr<ShapeItem>> const &items) {
        itemTree = std::make_shared<ShapeLayerPresentationTree::ContentItem>();
        itemTree->isGroup = true;
        ShapeLayerPresentationTree::renderTreeContent(items, itemTree);
    }
    
    ShapeLayerPresentationTree(std::shared_ptr<SolidLayerModel> const &solidLayer) {
        itemTree = std::make_shared<ShapeLayerPresentationTree::ContentItem>();
        itemTree->isGroup = true;
        
        std::vector<std::shared_ptr<ShapeItem>> items;
        items.push_back(std::make_shared<Rectangle>(
            std::nullopt,
            std::nullopt,
            std::nullopt,
            std::nullopt,
            solidLayer->hidden,
            std::nullopt,
            std::nullopt,
            std::nullopt,
            std::nullopt,
            KeyframeGroup<Vector3D>(Vector3D(0.0, 0.0, 0.0)),
            KeyframeGroup<Vector3D>(Vector3D(solidLayer->width, solidLayer->height, 0.0)),
            KeyframeGroup<Vector1D>(Vector1D(0.0))
        ));
        ShapeLayerPresentationTree::renderTreeContent(items, itemTree);
    }
    
private:
    static void renderTreeContent(std::vector<std::shared_ptr<ShapeItem>> const &items, std::shared_ptr<ContentItem> &itemTree) {
        for (const auto &item : items) {
            if (item->hidden()) {
                continue;
            }
            
            switch (item->type) {
                case ShapeType::Fill: {
                    Fill const &fill = *((Fill *)item.get());
                    
                    itemTree->addFill(std::make_shared<SolidFillOutput>(fill));
                    
                    break;
                }
                case ShapeType::GradientFill: {
                    GradientFill const &gradientFill = *((GradientFill *)item.get());
                    
                    itemTree->addFill(std::make_shared<GradientFillOutput>(gradientFill));
                    
                    break;
                }
                case ShapeType::Stroke: {
                    Stroke const &stroke = *((Stroke *)item.get());
                    
                    itemTree->addStroke(std::make_shared<SolidStrokeOutput>(stroke));
                    
                    break;
                }
                case ShapeType::GradientStroke: {
                    GradientStroke const &gradientStroke = *((GradientStroke *)item.get());
                    
                    itemTree->addStroke(std::make_shared<GradientStrokeOutput>(gradientStroke));
                    
                    break;
                }
                case ShapeType::Group: {
                    Group const &group = *((Group *)item.get());
                    
                    auto groupItem = std::make_shared<ContentItem>();
                    groupItem->isGroup = true;
                    
                    ShapeLayerPresentationTree::renderTreeContent(group.items, groupItem);
                    
                    itemTree->addSubItem(groupItem);
                    
                    break;
                }
                case ShapeType::Shape: {
                    Shape const &shape = *((Shape *)item.get());
                    
                    auto shapeItem = std::make_shared<ContentItem>();
                    shapeItem->setPath(std::make_unique<ShapePathOutput>(shape));
                    itemTree->addSubItem(shapeItem);
                    
                    break;
                }
                case ShapeType::Trim: {
                    Trim const &trim = *((Trim *)item.get());
                    
                    itemTree->addTrim(trim);
                    
                    break;
                }
                case ShapeType::Transform: {
                    auto transform = std::static_pointer_cast<ShapeTransform>(item);
                    
                    itemTree->setTransform(std::make_unique<TransformOutput>(transform));
                    
                    break;
                }
                case ShapeType::Ellipse: {
                    Ellipse const &ellipse = *((Ellipse *)item.get());
                    
                    auto shapeItem = std::make_shared<ContentItem>();
                    shapeItem->setPath(std::make_unique<EllipsePathOutput>(ellipse));
                    itemTree->addSubItem(shapeItem);
                    
                    break;
                }
                case ShapeType::Merge: {
                    //assert(false);
                    break;
                }
                case ShapeType::Rectangle: {
                    Rectangle const &rectangle = *((Rectangle *)item.get());
                    
                    auto shapeItem = std::make_shared<ContentItem>();
                    shapeItem->setPath(std::make_unique<RectanglePathOutput>(rectangle));
                    itemTree->addSubItem(shapeItem);
                    
                    break;
                }
                case ShapeType::Repeater: {
                    assert(false);
                    break;
                }
                case ShapeType::Star: {
                    Star const &star = *((Star *)item.get());
                    
                    auto shapeItem = std::make_shared<ContentItem>();
                    shapeItem->setPath(std::make_unique<StarPathOutput>(star));
                    itemTree->addSubItem(shapeItem);
                    
                    break;
                }
                case ShapeType::RoundedRectangle: {
                    //TODO:restore
                    break;
                }
                default: {
                    break;
                }
            }
        }
        
        itemTree->initializeRenderChildren();
    }
    
public:
    std::shared_ptr<ShapeLayerPresentationTree::ContentItem> itemTree;
};

ShapeCompositionLayer::ShapeCompositionLayer(std::shared_ptr<ShapeLayerModel> const &shapeLayer) :
CompositionLayer(shapeLayer, Vector2D::Zero()) {
    _contentTree = std::make_shared<ShapeLayerPresentationTree>(shapeLayer->items);
}

ShapeCompositionLayer::ShapeCompositionLayer(std::shared_ptr<SolidLayerModel> const &solidLayer) :
CompositionLayer(solidLayer, Vector2D::Zero()) {
    _contentTree = std::make_shared<ShapeLayerPresentationTree>(solidLayer);
}

void ShapeCompositionLayer::displayContentsWithFrame(double frame, bool forceUpdates) {
    _frameTime = frame;
    _frameTimeInitialized = true;
    
    _contentTree->itemTree->renderChildren(_frameTime, std::nullopt);
}

std::shared_ptr<RenderTreeNode> ShapeCompositionLayer::renderTreeNode() {
    if (_contentsLayer->isHidden()) {
        return nullptr;
    }
    
    assert(_frameTimeInitialized);
    
    std::shared_ptr<RenderTreeNode> maskNode;
    bool invertMask = false;
    if (_matteLayer) {
        maskNode = _matteLayer->renderTreeNode();
        if (maskNode && _matteType.has_value() && _matteType.value() == MatteType::Invert) {
            invertMask = true;
        }
    }
    
    std::vector<std::shared_ptr<RenderTreeNode>> renderTreeValue;
    renderTreeValue.push_back(_contentTree->itemTree->renderTree());
    
    //printf("Name: %s\n", keypathName().c_str());
    /*if (!maskNode && keypathName().find("Shape Layer 3") != -1) {
        return std::make_shared<RenderTreeNode>(
            bounds(),
            _contentsLayer->position(),
            _contentsLayer->transform(),
            _contentsLayer->opacity(),
            _contentsLayer->masksToBounds(),
            _contentsLayer->isHidden(),
            nullptr,
            renderTreeValue,
            nullptr,
            false
        );
    }*/
    
    std::vector<std::shared_ptr<RenderTreeNode>> subnodes;
    subnodes.push_back(std::make_shared<RenderTreeNode>(
        _contentsLayer->bounds(),
        _contentsLayer->position(),
        _contentsLayer->transform(),
        _contentsLayer->opacity(),
        _contentsLayer->masksToBounds(),
        _contentsLayer->isHidden(),
        nullptr,
        renderTreeValue,
        nullptr,
        false
    ));
    
    assert(position() == Vector2D::Zero());
    assert(transform().isIdentity());
    assert(opacity() == 1.0);
    assert(!masksToBounds());
    assert(!isHidden());
    
    assert(_contentsLayer->bounds() == CGRect(0.0, 0.0, 0.0, 0.0));
    assert(_contentsLayer->position() == Vector2D::Zero());
    assert(!_contentsLayer->masksToBounds());
    
    return std::make_shared<RenderTreeNode>(
        bounds(),
        position(),
        transform(),
        opacity(),
        masksToBounds(),
        isHidden(),
        nullptr,
        subnodes,
        maskNode,
        invertMask
    );
}

}
