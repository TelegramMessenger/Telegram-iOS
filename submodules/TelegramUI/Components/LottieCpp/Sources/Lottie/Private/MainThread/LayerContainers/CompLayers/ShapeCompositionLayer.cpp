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
        virtual std::shared_ptr<RenderTreeNodeContentItem::Fill> fill() = 0;
    };
    
    class SolidFillOutput : public FillOutput {
    public:
        explicit SolidFillOutput(Fill const &fill) :
        rule(fill.fillRule.value_or(FillRule::NonZeroWinding)),
        color(fill.color.keyframes),
        opacity(fill.opacity.keyframes) {
            auto solid = std::make_shared<RenderTreeNodeContentItem::SolidShading>(Color(0.0, 0.0, 0.0, 0.0), 0.0);
            _fill = std::make_shared<RenderTreeNodeContentItem::Fill>(
                solid,
                rule
            );
        }
        
        virtual ~SolidFillOutput() = default;
        
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
            
            if (hasUpdates) {
                RenderTreeNodeContentItem::SolidShading *solid = (RenderTreeNodeContentItem::SolidShading *)_fill->shading.get();
                solid->color = colorValue;
                solid->opacity = opacityValue * 0.01;
            }
        }
        
        virtual std::shared_ptr<RenderTreeNodeContentItem::Fill> fill() override {
            return _fill;
        }
        
    private:
        FillRule rule;
        
        KeyframeInterpolator<Color> color;
        Color colorValue = Color(0.0, 0.0, 0.0, 0.0);
        
        KeyframeInterpolator<Vector1D> opacity;
        float opacityValue = 0.0;
        
        std::shared_ptr<RenderTreeNodeContentItem::Fill> _fill;
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
            auto gradient = std::make_shared<RenderTreeNodeContentItem::GradientShading>(
                0.0,
                gradientType,
                std::vector<Color>(),
                std::vector<float>(),
                Vector2D(0.0, 0.0),
                Vector2D(0.0, 0.0)
            );
            _fill = std::make_shared<RenderTreeNodeContentItem::Fill>(
                gradient,
                rule
            );
        }
        
        virtual ~GradientFillOutput() = default;
        
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
            
            if (hasUpdates) {
                std::vector<Color> colors;
                std::vector<float> locations;
                getGradientParameters(numberOfColors, colorsValue, colors, locations);
                
                RenderTreeNodeContentItem::GradientShading *gradient = ((RenderTreeNodeContentItem::GradientShading *)_fill->shading.get());
                gradient->opacity = opacityValue * 0.01;
                gradient->colors = colors;
                gradient->locations = locations;
                gradient->start = Vector2D(startPointValue.x, startPointValue.y);
                gradient->end = Vector2D(endPointValue.x, endPointValue.y);
            }
        }
        
        virtual std::shared_ptr<RenderTreeNodeContentItem::Fill> fill() override {
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
        float opacityValue = 0.0;
        
        std::shared_ptr<RenderTreeNodeContentItem::Fill> _fill;
    };
    
    class StrokeOutput {
    public:
        StrokeOutput() {
        }
        ~StrokeOutput() = default;
        
        virtual void update(AnimationFrameTime frameTime) = 0;
        virtual std::shared_ptr<RenderTreeNodeContentItem::Stroke> stroke() = 0;
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
            
            auto solid = std::make_shared<RenderTreeNodeContentItem::SolidShading>(Color(0.0, 0.0, 0.0, 0.0), 0.0);
            _stroke = std::make_shared<RenderTreeNodeContentItem::Stroke>(
                solid,
                0.0,
                lineJoin,
                lineCap,
                miterLimit,
                0.0,
                std::vector<float>()
            );
        }
        
        virtual ~SolidStrokeOutput() = default;
        
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
            
            if (hasUpdates) {
                bool hasNonZeroDashes = false;
                if (!dashPatternValue.values.empty()) {
                    for (const auto &value : dashPatternValue.values) {
                        if (value != 0) {
                            hasNonZeroDashes = true;
                            break;
                        }
                    }
                }
                
                RenderTreeNodeContentItem::SolidShading *solid = (RenderTreeNodeContentItem::SolidShading *)_stroke->shading.get();
                solid->color = colorValue;
                solid->opacity = opacityValue * 0.01;
                
                _stroke->lineWidth = widthValue;
                _stroke->dashPhase = hasNonZeroDashes ? dashPhaseValue : 0.0;
                _stroke->dashPattern = hasNonZeroDashes ? dashPatternValue.values : std::vector<float>();
            }
        }
        
        virtual std::shared_ptr<RenderTreeNodeContentItem::Stroke> stroke() override {
            return _stroke;
        }
        
    private:
        LineJoin lineJoin;
        LineCap lineCap;
        float miterLimit = 4.0;
        
        KeyframeInterpolator<Color> color;
        Color colorValue = Color(0.0, 0.0, 0.0, 0.0);
        
        KeyframeInterpolator<Vector1D> opacity;
        float opacityValue = 0.0;
        
        KeyframeInterpolator<Vector1D> width;
        float widthValue = 0.0;
        
        std::unique_ptr<DashPatternInterpolator> dashPattern;
        DashPattern dashPatternValue = DashPattern({});
        
        std::unique_ptr<KeyframeInterpolator<Vector1D>> dashPhase;
        float dashPhaseValue = 0.0;
        
        std::shared_ptr<RenderTreeNodeContentItem::Stroke> _stroke;
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
            
            auto gradient = std::make_shared<RenderTreeNodeContentItem::GradientShading>(
                0.0,
                gradientType,
                std::vector<Color>(),
                std::vector<float>(),
                Vector2D(0.0, 0.0),
                Vector2D(0.0, 0.0)
            );
            _stroke = std::make_shared<RenderTreeNodeContentItem::Stroke>(
                gradient,
                0.0,
                lineJoin,
                lineCap,
                miterLimit,
                0.0,
                std::vector<float>()
            );
        }
        
        virtual ~GradientStrokeOutput() = default;
        
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
            
            if (hasUpdates) {
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
                std::vector<float> locations;
                getGradientParameters(numberOfColors, colorsValue, colors, locations);
                
                RenderTreeNodeContentItem::GradientShading *gradient = ((RenderTreeNodeContentItem::GradientShading *)_stroke->shading.get());
                gradient->opacity = opacityValue * 0.01;
                gradient->colors = colors;
                gradient->locations = locations;
                gradient->start = Vector2D(startPointValue.x, startPointValue.y);
                gradient->end = Vector2D(endPointValue.x, endPointValue.y);
                
                _stroke->lineWidth = widthValue;
                _stroke->dashPhase = hasNonZeroDashes ? dashPhaseValue : 0.0;
                _stroke->dashPattern = hasNonZeroDashes ? dashPatternValue.values : std::vector<float>();
            }
        }
        
        virtual std::shared_ptr<RenderTreeNodeContentItem::Stroke> stroke() override {
            return _stroke;
        }
        
    private:
        LineJoin lineJoin;
        LineCap lineCap;
        float miterLimit = 4.0;
        
        int numberOfColors = 0;
        GradientType gradientType;
        
        KeyframeInterpolator<GradientColorSet> colors;
        GradientColorSet colorsValue;
        
        KeyframeInterpolator<Vector3D> startPoint;
        Vector3D startPointValue = Vector3D(0.0, 0.0, 0.0);
        
        KeyframeInterpolator<Vector3D> endPoint;
        Vector3D endPointValue = Vector3D(0.0, 0.0, 0.0);
        
        KeyframeInterpolator<Vector1D> opacity;
        float opacityValue = 0.0;
        
        KeyframeInterpolator<Vector1D> width;
        float widthValue = 0.0;
        
        std::unique_ptr<DashPatternInterpolator> dashPattern;
        DashPattern dashPatternValue = DashPattern({});
        
        std::unique_ptr<KeyframeInterpolator<Vector1D>> dashPhase;
        float dashPhaseValue = 0.0;
        
        std::shared_ptr<RenderTreeNodeContentItem::Stroke> _stroke;
    };
    
    class TrimParamsOutput {
    public:
        TrimParamsOutput(Trim const &trim) :
        type(trim.trimType),
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
            float resolvedStartValue = startValue * 0.01;
            float resolvedEndValue = endValue * 0.01;
            float resolvedStart = std::min(resolvedStartValue, resolvedEndValue);
            float resolvedEnd = std::max(resolvedStartValue, resolvedEndValue);
            
            float resolvedOffset = fmod(offsetValue, 360.0) / 360.0;
            
            return TrimParams(resolvedStart, resolvedEnd, resolvedOffset, type);
        }
        
    private:
        TrimType type;
        
        KeyframeInterpolator<Vector1D> start;
        float startValue = 0.0;
        
        KeyframeInterpolator<Vector1D> end;
        float endValue = 0.0;
        
        KeyframeInterpolator<Vector1D> offset;
        float offsetValue = 0.0;
    };
    
    struct ShadingVariant {
        std::shared_ptr<FillOutput> fill;
        std::shared_ptr<StrokeOutput> stroke;
        size_t subItemLimit = 0;
    };
    
    struct TransformedPath {
        BezierPath path;
        Transform2D transform;
        
        TransformedPath(BezierPath const &path_, Transform2D const &transform_) :
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
        virtual std::shared_ptr<RenderTreeNodeContentPath> &currentPath() = 0;
    };
    
    class StaticPathOutput : public PathOutput {
    public:
        explicit StaticPathOutput(BezierPath const &path) :
        resolvedPath(std::make_shared<RenderTreeNodeContentPath>(path)) {
        }
        
        virtual void update(AnimationFrameTime frameTime) override {
        }
        
        virtual std::shared_ptr<RenderTreeNodeContentPath> &currentPath() override {
            return resolvedPath;
        }
        
    private:
        std::shared_ptr<RenderTreeNodeContentPath> resolvedPath;
    };
    
    class ShapePathOutput : public PathOutput {
    public:
        explicit ShapePathOutput(Shape const &shape) :
        path(shape.path.keyframes),
        resolvedPath(std::make_shared<RenderTreeNodeContentPath>(BezierPath())) {
        }
        
        virtual void update(AnimationFrameTime frameTime) override {
            if (!hasValidData || path.hasUpdate(frameTime)) {
                path.update(frameTime, resolvedPath->path);
                resolvedPath->needsBoundsRecalculation = true;
            }
            hasValidData = true;
        }
        
        virtual std::shared_ptr<RenderTreeNodeContentPath> &currentPath() override {
            return resolvedPath;
        }
        
    private:
        bool hasValidData = false;
        
        BezierPathKeyframeInterpolator path;
        
        std::shared_ptr<RenderTreeNodeContentPath> resolvedPath;
    };
    
    class RectanglePathOutput : public PathOutput {
    public:
        explicit RectanglePathOutput(Rectangle const &rectangle) :
        direction(rectangle.direction.value_or(PathDirection::Clockwise)),
        position(rectangle.position.keyframes),
        size(rectangle.size.keyframes),
        cornerRadius(rectangle.cornerRadius.keyframes),
        resolvedPath(std::make_shared<RenderTreeNodeContentPath>(BezierPath())) {
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
                ValueInterpolator<BezierPath>::setInplace(makeRectangleBezierPath(Vector2D(positionValue.x, positionValue.y), Vector2D(sizeValue.x, sizeValue.y), cornerRadiusValue, direction), resolvedPath->path);
                resolvedPath->needsBoundsRecalculation = true;
            }
            
            hasValidData = true;
        }
        
        virtual std::shared_ptr<RenderTreeNodeContentPath> &currentPath() override {
            return resolvedPath;
        }
        
    private:
        bool hasValidData = false;
        
        PathDirection direction;
        
        KeyframeInterpolator<Vector3D> position;
        Vector3D positionValue = Vector3D(0.0, 0.0, 0.0);
        
        KeyframeInterpolator<Vector3D> size;
        Vector3D sizeValue = Vector3D(0.0, 0.0, 0.0);
        
        KeyframeInterpolator<Vector1D> cornerRadius;
        float cornerRadiusValue = 0.0;
        
        std::shared_ptr<RenderTreeNodeContentPath> resolvedPath;
    };
    
    class EllipsePathOutput : public PathOutput {
    public:
        explicit EllipsePathOutput(Ellipse const &ellipse) :
        direction(ellipse.direction.value_or(PathDirection::Clockwise)),
        position(ellipse.position.keyframes),
        size(ellipse.size.keyframes),
        resolvedPath(std::make_shared<RenderTreeNodeContentPath>(BezierPath())) {
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
                ValueInterpolator<BezierPath>::setInplace(makeEllipseBezierPath(Vector2D(sizeValue.x, sizeValue.y), Vector2D(positionValue.x, positionValue.y), direction), resolvedPath->path);
                resolvedPath->needsBoundsRecalculation = true;
            }
            
            hasValidData = true;
        }
        
        virtual std::shared_ptr<RenderTreeNodeContentPath> &currentPath() override {
            return resolvedPath;
        }
        
    private:
        bool hasValidData = false;
        
        PathDirection direction;
        
        KeyframeInterpolator<Vector3D> position;
        Vector3D positionValue = Vector3D(0.0, 0.0, 0.0);
        
        KeyframeInterpolator<Vector3D> size;
        Vector3D sizeValue = Vector3D(0.0, 0.0, 0.0);
        
        std::shared_ptr<RenderTreeNodeContentPath> resolvedPath;
    };
    
    class StarPathOutput : public PathOutput {
    public:
        explicit StarPathOutput(Star const &star) :
        direction(star.direction.value_or(PathDirection::Clockwise)),
        position(star.position.keyframes),
        outerRadius(star.outerRadius.keyframes),
        outerRoundedness(star.outerRoundness.keyframes),
        rotation(star.rotation.keyframes),
        points(star.points.keyframes),
        resolvedPath(std::make_shared<RenderTreeNodeContentPath>(BezierPath())) {
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
                ValueInterpolator<BezierPath>::setInplace(makeStarBezierPath(Vector2D(positionValue.x, positionValue.y), outerRadiusValue, innerRadiusValue, outerRoundednessValue, innerRoundednessValue, pointsValue, rotationValue, direction), resolvedPath->path);
                resolvedPath->needsBoundsRecalculation = true;
            }
            
            hasValidData = true;
        }
        
        virtual std::shared_ptr<RenderTreeNodeContentPath> &currentPath() override {
            return resolvedPath;
        }
        
    private:
        bool hasValidData = false;
        
        PathDirection direction;
        
        KeyframeInterpolator<Vector3D> position;
        Vector3D positionValue = Vector3D(0.0, 0.0, 0.0);
        
        KeyframeInterpolator<Vector1D> outerRadius;
        float outerRadiusValue = 0.0;
        
        KeyframeInterpolator<Vector1D> outerRoundedness;
        float outerRoundednessValue = 0.0;
        
        std::unique_ptr<NodeProperty<Vector1D>> innerRadius;
        float innerRadiusValue = 0.0;
        
        std::unique_ptr<NodeProperty<Vector1D>> innerRoundedness;
        float innerRoundednessValue = 0.0;
        
        KeyframeInterpolator<Vector1D> rotation;
        float rotationValue = 0.0;
        
        KeyframeInterpolator<Vector1D> points;
        float pointsValue = 0.0;
        
        std::shared_ptr<RenderTreeNodeContentPath> resolvedPath;
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
                
                float rotationValue = 0.0;
                if (_rotation) {
                    rotationValue = _rotation->value(frameTime).value;
                }
                
                float skewValue = 0.0;
                if (_skew) {
                    skewValue = _skew->value(frameTime).value;
                }
                
                float skewAxisValue = 0.0;
                if (_skewAxis) {
                    skewAxisValue = _skewAxis->value(frameTime).value;
                }
                
                if (_opacity) {
                    _opacityValue = _opacity->value(frameTime).value * 0.01;
                } else {
                    _opacityValue = 1.0;
                }
                
                _transformValue = Transform2D::identity().translated(Vector2D(positionValue.x, positionValue.y)).rotated(rotationValue).skewed(-skewValue, skewAxisValue).scaled(Vector2D(scaleValue.x * 0.01, scaleValue.y * 0.01)).translated(Vector2D(-anchorValue.x, -anchorValue.y));
                
                hasValidData = true;
            }
        }
        
        Transform2D const &transform() {
            return _transformValue;
        }
        
        float opacity() {
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
        
        Transform2D _transformValue = Transform2D::identity();
        float _opacityValue = 1.0;
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
        
    private:
        std::unique_ptr<PathOutput> path;
        std::unique_ptr<TransformOutput> transform;
        
        std::vector<ShadingVariant> shadings;
        std::shared_ptr<TrimParamsOutput> trim;
        
    public:
        std::vector<std::shared_ptr<ContentItem>> subItems;
        std::shared_ptr<RenderTreeNodeContentItem> _contentItem;
        
    private:
        std::vector<TransformedPath> collectPaths(size_t subItemLimit, Transform2D const &parentTransform, bool skipApplyTransform) {
            std::vector<TransformedPath> mappedPaths;
            
            //TODO:remove skipApplyTransform
            Transform2D effectiveTransform = parentTransform;
            if (!skipApplyTransform && isGroup && transform) {
                effectiveTransform = transform->transform() * effectiveTransform;
            }
            
            size_t maxSubitem = std::min(subItems.size(), subItemLimit);
            
            if (_contentItem->path) {
                mappedPaths.emplace_back(_contentItem->path->path, effectiveTransform);
            }
            
            for (size_t i = 0; i < maxSubitem; i++) {
                auto &subItem = subItems[i];
                
                std::optional<TrimParams> currentTrim;
                if (trim) {
                    currentTrim = trim->trimParams();
                }
                
                auto subItemPaths = subItem->collectPaths(INT32_MAX, effectiveTransform, false);
                
                if (currentTrim) {
                    CompoundBezierPath tempPath;
                    for (auto &path : subItemPaths) {
                        tempPath.appendPath(path.path.copyUsingTransform(path.transform));
                    }
                    CompoundBezierPath trimmedPath = trimCompoundPath(tempPath, currentTrim->start, currentTrim->end, currentTrim->offset, currentTrim->type);
                    for (auto &path : trimmedPath.paths) {
                        mappedPaths.emplace_back(path, Transform2D::identity());
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
        
        void setTrim(Trim const &trim_) {
            trim = std::make_shared<TrimParamsOutput>(trim_);
        }
        
    public:
        void initializeRenderChildren() {
            _contentItem = std::make_shared<RenderTreeNodeContentItem>();
            _contentItem->isGroup = isGroup;
            
            if (path) {
                _contentItem->path = path->currentPath();
            }
            
            if (!shadings.empty()) {
                for (int i = 0; i < shadings.size(); i++) {
                    auto &shadingVariant = shadings[i];
                    
                    if (!(shadingVariant.fill || shadingVariant.stroke)) {
                        continue;
                    }
                    
                    _contentItem->drawContentCount++;
                    
                    auto itemShadingVariant = std::make_shared<RenderTreeNodeContentShadingVariant>();
                    if (shadingVariant.fill) {
                        itemShadingVariant->fill = shadingVariant.fill->fill();
                    }
                    if (shadingVariant.stroke) {
                        itemShadingVariant->stroke = shadingVariant.stroke->stroke();
                    }
                    itemShadingVariant->subItemLimit = shadingVariant.subItemLimit;
                    
                    _contentItem->shadings.push_back(itemShadingVariant);
                }
            }
            
            if (isGroup && !subItems.empty()) {
                std::vector<std::shared_ptr<RenderTreeNode>> subItemNodes;
                for (const auto &subItem : subItems) {
                    subItem->initializeRenderChildren();
                    _contentItem->drawContentCount += subItem->_contentItem->drawContentCount;
                    _contentItem->subItems.push_back(subItem->_contentItem);
                }
            }
        }
        
    public:
        void updateFrame(AnimationFrameTime frameTime, BezierPathsBoundingBoxContext &boundingBoxContext) {
            if (transform) {
                transform->update(frameTime);
            }
            
            if (path) {
                path->update(frameTime);
            }
            if (trim) {
                trim->update(frameTime);
            }
            
            for (const auto &shadingVariant : shadings) {
                if (shadingVariant.fill) {
                    shadingVariant.fill->update(frameTime);
                }
                if (shadingVariant.stroke) {
                    shadingVariant.stroke->update(frameTime);
                }
            }
            
            for (const auto &subItem : subItems) {
                subItem->updateFrame(frameTime, boundingBoxContext);
            }
        }
        
        bool hasTrims() {
            if (trim) {
                return true;
            }
            
            for (const auto &subItem : subItems) {
                if (subItem->hasTrims()) {
                    return true;
                }
            }
            
            return false;
        }
        
        bool hasNestedTrims() {
            for (const auto &subItem : subItems) {
                if (subItem->hasTrims()) {
                    return true;
                }
            }
            
            return false;
        }
        
        void updateContents(std::optional<TrimParams> parentTrim) {
            Transform2D containerTransform = Transform2D::identity();
            float containerOpacity = 1.0;
            if (transform) {
                containerTransform = transform->transform();
                containerOpacity = transform->opacity();
            }
            _contentItem->transform = containerTransform;
            _contentItem->alpha = containerOpacity;
            
            if (parentTrim) {
                _contentItem->trimParams = parentTrim;
                
                CompoundBezierPath compoundPath;
                auto paths = collectPaths(INT32_MAX, Transform2D::identity(), true);
                for (const auto &path : paths) {
                    compoundPath.appendPath(path.path.copyUsingTransform(path.transform));
                }
                
                compoundPath = trimCompoundPath(compoundPath, parentTrim->start, parentTrim->end, parentTrim->offset, parentTrim->type);
                
                std::vector<BezierPath> resultPaths;
                for (const auto &path : compoundPath.paths) {
                    resultPaths.push_back(path);
                }
                
                _contentItem->trimmedPaths = resultPaths;
            }
            
            if (isGroup && !subItems.empty()) {
                for (int i = (int)subItems.size() - 1; i >= 0; i--) {
                    std::optional<TrimParams> childTrim = parentTrim;
                    if (trim) {
                        childTrim = trim->trimParams();
                    }
                    
                    subItems[i]->updateContents(childTrim);
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
    
    virtual ~ShapeLayerPresentationTree() = default;
    
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
                    
                    auto groupItem = std::make_shared<ContentItem>();
                    groupItem->isGroup = true;
                    groupItem->setTrim(trim);
                    
                    for (const auto &subItem : itemTree->subItems) {
                        groupItem->addSubItem(subItem);
                    }
                    itemTree->subItems.clear();
                    itemTree->addSubItem(groupItem);
                    
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

void ShapeCompositionLayer::displayContentsWithFrame(float frame, bool forceUpdates, BezierPathsBoundingBoxContext &boundingBoxContext) {
    _frameTime = frame;
    _frameTimeInitialized = true;
    _contentTree->itemTree->updateFrame(_frameTime, boundingBoxContext);
    _contentTree->itemTree->updateContents(std::nullopt);
}

std::shared_ptr<RenderTreeNode> ShapeCompositionLayer::renderTreeNode(BezierPathsBoundingBoxContext &boundingBoxContext) {
    if (!_frameTimeInitialized) {
        _frameTime = 0.0;
        _frameTimeInitialized = true;
        _contentTree->itemTree->updateFrame(_frameTime, boundingBoxContext);
        _contentTree->itemTree->updateContents(std::nullopt);
    }
    
    if (!_renderTreeNode) {
        _contentRenderTreeNode = std::make_shared<RenderTreeNode>(
            Vector2D(0.0, 0.0),
            Transform2D::identity(),
            1.0,
            false,
            false,
            std::vector<std::shared_ptr<RenderTreeNode>>(),
            nullptr,
            false
        );
        _contentRenderTreeNode->_contentItem = _contentTree->itemTree->_contentItem;
        _contentRenderTreeNode->drawContentCount = _contentTree->itemTree->_contentItem->drawContentCount;
        
        std::vector<std::shared_ptr<RenderTreeNode>> subnodes;
        subnodes.push_back(_contentRenderTreeNode);
        
        std::shared_ptr<RenderTreeNode> maskNode;
        bool invertMask = false;
        if (_matteLayer) {
            maskNode = _matteLayer->renderTreeNode(boundingBoxContext);
            if (maskNode && _matteType.has_value() && _matteType.value() == MatteType::Invert) {
                invertMask = true;
            }
        }
        
        _renderTreeNode = std::make_shared<RenderTreeNode>(
            Vector2D(0.0, 0.0),
            Transform2D::identity(),
            1.0,
            false,
            false,
            subnodes,
            maskNode,
            invertMask
        );
    }
    
    _contentRenderTreeNode->_size = _contentsLayer->size();
    _contentRenderTreeNode->_masksToBounds = _contentsLayer->masksToBounds();
    
    _renderTreeNode->_masksToBounds = masksToBounds();
    
    _renderTreeNode->_size = size();
    
    return _renderTreeNode;
}

void ShapeCompositionLayer::updateContentsLayerParameters() {
    _contentRenderTreeNode->_transform = _contentsLayer->transform();
    _contentRenderTreeNode->_alpha = _contentsLayer->opacity();
    _contentRenderTreeNode->_isHidden = _contentsLayer->isHidden();
}

}
