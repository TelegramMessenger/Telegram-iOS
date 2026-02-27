#ifndef GradientStroke_hpp
#define GradientStroke_hpp

#include "Lottie/Private/Model/ShapeItems/ShapeItem.hpp"
#include "Lottie/Private/Model/ShapeItems/GradientFill.hpp"
#include "Lottie/Private/Model/Keyframes/KeyframeGroup.hpp"
#include "Lottie/Private/Model/Objects/DashElement.hpp"
#include "Lottie/Private/Parsing/JsonParsing.hpp"
#include "Lottie/Public/Primitives/DrawingAttributes.hpp"

namespace lottie {

/// An item that define a gradient stroke
class GradientStroke: public ShapeItem {
public:
    explicit GradientStroke(json11::Json::object const &json) noexcept(false) :
    ShapeItem(json),
    opacity(KeyframeGroup<Vector1D>(Vector1D(100.0))),
    startPoint(KeyframeGroup<Vector3D>(Vector3D(0.0, 0.0, 0.0))),
    endPoint(KeyframeGroup<Vector3D>(Vector3D(0.0, 0.0, 0.0))),
    gradientType(GradientType::None),
    numberOfColors(0),
    colors(KeyframeGroup<GradientColorSet>(GradientColorSet())),
    width(KeyframeGroup<Vector1D>(Vector1D(0.0))),
    lineCap(LineCap::Round),
    lineJoin(LineJoin::Round) {
        opacity = KeyframeGroup<Vector1D>(getObject(json, "o"));
        startPoint = KeyframeGroup<Vector3D>(getObject(json, "s"));
        endPoint = KeyframeGroup<Vector3D>(getObject(json, "e"));
        
        auto gradientTypeRawValue = getInt(json, "t");
        switch (gradientTypeRawValue) {
            case 0:
                gradientType = GradientType::None;
                break;
            case 1:
                gradientType = GradientType::Linear;
                break;
            case 2:
                gradientType = GradientType::Radial;
                break;
            default:
                throw LottieParsingException();
        }
        
        if (const auto highlightLengthData = getOptionalObject(json, "h")) {
            highlightLength = KeyframeGroup<Vector1D>(highlightLengthData.value());
        }
        if (const auto highlightAngleData = getOptionalObject(json, "a")) {
            highlightAngle = KeyframeGroup<Vector1D>(highlightAngleData.value());
        }
        
        width = KeyframeGroup<Vector1D>(getObject(json, "w"));
        
        if (const auto lineCapRawValue = getOptionalInt(json, "lc")) {
            switch (lineCapRawValue.value()) {
                case 0:
                    lineCap = LineCap::None;
                    break;
                case 1:
                    lineCap = LineCap::Butt;
                    break;
                case 2:
                    lineCap = LineCap::Round;
                    break;
                case 3:
                    lineCap = LineCap::Square;
                    break;
                default:
                    throw LottieParsingException();
            }
        }
        
        if (const auto lineJoinRawValue = getOptionalInt(json, "lj")) {
            switch (lineJoinRawValue.value()) {
                case 0:
                    lineJoin = LineJoin::None;
                    break;
                case 1:
                    lineJoin = LineJoin::Miter;
                    break;
                case 2:
                    lineJoin = LineJoin::Round;
                    break;
                case 3:
                    lineJoin = LineJoin::Bevel;
                    break;
                default:
                    throw LottieParsingException();
            }
        }
        
        if (const auto miterLimitData = getOptionalDouble(json, "ml")) {
            miterLimit = miterLimitData.value();
        }
        
        auto colorsContainer = getObject(json, "g");
        numberOfColors = getInt(colorsContainer, "p");
        auto colorsData = getObject(colorsContainer, "k");
        colors = KeyframeGroup<GradientColorSet>(colorsData);
        
        if (const auto dashElementsData = getOptionalObjectArray(json, "d")) {
            dashPattern = std::vector<DashElement>();
            for (const auto &dashElementData : dashElementsData.value()) {
                dashPattern->push_back(DashElement(dashElementData));
            }
        }
    }
    
    virtual void toJson(json11::Json::object &json) const override {
        ShapeItem::toJson(json);
        
        json.insert(std::make_pair("o", opacity.toJson()));
        json.insert(std::make_pair("s", startPoint.toJson()));
        json.insert(std::make_pair("e", endPoint.toJson()));
        json.insert(std::make_pair("t", (int)gradientType));
        
        if (highlightLength.has_value()) {
            json.insert(std::make_pair("h", highlightLength->toJson()));
        }
        if (highlightAngle.has_value()) {
            json.insert(std::make_pair("a", highlightAngle->toJson()));
        }
        
        json.insert(std::make_pair("w", width.toJson()));
        
        json.insert(std::make_pair("lc", (int)lineCap));
        json.insert(std::make_pair("lj", (int)lineJoin));
        
        if (miterLimit.has_value()) {
            json.insert(std::make_pair("ml", miterLimit.value()));
        }
        
        json11::Json::object colorsContainer;
        colorsContainer.insert(std::make_pair("p", numberOfColors));
        colorsContainer.insert(std::make_pair("k", colors.toJson()));
        json.insert(std::make_pair("g", colorsContainer));
        
        if (dashPattern.has_value()) {
            json11::Json::array dashElements;
            for (const auto &dashElement : dashPattern.value()) {
                dashElements.push_back(dashElement.toJson());
            }
            json.insert(std::make_pair("d", dashElements));
        }
    }
    
public:
    /// The opacity of the fill
    KeyframeGroup<Vector1D> opacity;
    
    /// The start of the gradient
    KeyframeGroup<Vector3D> startPoint;
    
    /// The end of the gradient
    KeyframeGroup<Vector3D> endPoint;
    
    /// The type of gradient
    GradientType gradientType;
    
    /// Gradient Highlight Length. Only if type is Radial
    std::optional<KeyframeGroup<Vector1D>> highlightLength;
    
    /// Highlight Angle. Only if type is Radial
    std::optional<KeyframeGroup<Vector1D>> highlightAngle;
    
    /// The number of color points in the gradient
    int numberOfColors;
    
    /// The Colors of the gradient.
    KeyframeGroup<GradientColorSet> colors;
    
    /// The width of the stroke
    KeyframeGroup<Vector1D> width;
    
    /// Line Cap
    LineCap lineCap;
    
    /// Line Join
    LineJoin lineJoin;
    
    /// Miter Limit
    std::optional<double> miterLimit;
    
    /// The dash pattern of the stroke
    std::optional<std::vector<DashElement>> dashPattern;
};

}

#endif /* GradientStroke_hpp */
