#ifndef GradientFill_hpp
#define GradientFill_hpp

#include "Lottie/Private/Model/ShapeItems/ShapeItem.hpp"
#include "Lottie/Private/Model/Keyframes/KeyframeGroup.hpp"
#include "Lottie/Private/Parsing/JsonParsing.hpp"
#include "Lottie/Public/Primitives/GradientColorSet.hpp"

namespace lottie {

enum class GradientType: int {
    None = 0,
    Linear = 1,
    Radial = 2
};

/// An item that define a gradient fill
class GradientFill: public ShapeItem {
public:
    explicit GradientFill(json11::Json::object const &json) noexcept(false) :
    ShapeItem(json),
    opacity(KeyframeGroup<Vector1D>(Vector1D(100.0))),
    startPoint(KeyframeGroup<Vector3D>(Vector3D(0.0, 0.0, 0.0))),
    endPoint(KeyframeGroup<Vector3D>(Vector3D(0.0, 0.0, 0.0))),
    gradientType(GradientType::None),
    numberOfColors(0),
    colors(KeyframeGroup<GradientColorSet>(GradientColorSet())) {
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
        
        auto colorsContainer = getObject(json, "g");
        numberOfColors = getInt(colorsContainer, "p");
        colors = KeyframeGroup<GradientColorSet>(getObject(colorsContainer, "k"));
        
        rValue = getOptionalInt(json, "r");
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
        
        json11::Json::object colorsContainer;
        colorsContainer.insert(std::make_pair("p", numberOfColors));
        colorsContainer.insert(std::make_pair("k", colors.toJson()));
        json.insert(std::make_pair("g", colorsContainer));
        
        if (rValue.has_value()) {
            json.insert(std::make_pair("r", rValue.value()));
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
    
    std::optional<int> rValue;
};

}

#endif /* GradientFill_hpp */
