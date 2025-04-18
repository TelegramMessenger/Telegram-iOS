#ifndef TextAnimator_hpp
#define TextAnimator_hpp

#include "Lottie/Public/Primitives/Vectors.hpp"
#include "Lottie/Public/Primitives/Color.hpp"
#include "Lottie/Private/Model/Keyframes/KeyframeGroup.hpp"
#include "Lottie/Private/Parsing/JsonParsing.hpp"

#include <string>
#include <optional>

namespace lottie {

class TextAnimator {
public:
    TextAnimator(
        std::optional<std::string> &name_,
        std::optional<KeyframeGroup<Vector3D>> anchor_,
        std::optional<KeyframeGroup<Vector3D>> position_,
        std::optional<KeyframeGroup<Vector3D>> scale_,
        std::optional<KeyframeGroup<Vector1D>> skew_,
        std::optional<KeyframeGroup<Vector1D>> skewAxis_,
        std::optional<KeyframeGroup<Vector1D>> rotation_,
        std::optional<KeyframeGroup<Vector1D>> opacity_,
        std::optional<KeyframeGroup<Color>> strokeColor_,
        std::optional<KeyframeGroup<Color>> fillColor_,
        std::optional<KeyframeGroup<Vector1D>> strokeWidth_,
        std::optional<KeyframeGroup<Vector1D>> tracking_
    ) :
    name(name_),
    anchor(anchor_),
    position(position_),
    scale(scale_),
    skew(skew_),
    skewAxis(skewAxis_),
    rotation(rotation_),
    opacity(opacity_),
    strokeColor(strokeColor_),
    fillColor(fillColor_),
    strokeWidth(strokeWidth_),
    tracking(tracking_) {
    }
    
    explicit TextAnimator(json11::Json const &jsonAny) {
        if (!jsonAny.is_object()) {
            throw LottieParsingException();
        }
        json11::Json::object const &json = jsonAny.object_items();
        
        if (const auto nameData = getOptionalString(json, "nm")) {
            name = nameData.value();
        }
        _extraS = getOptionalAny(json, "s");
        
        json11::Json::object const &animatorContainer = getObject(json, "a");
        
        if (const auto fillColorData = getOptionalObject(animatorContainer, "fc")) {
            fillColor = KeyframeGroup<Color>(fillColorData.value());
        }
        if (const auto strokeColorData = getOptionalObject(animatorContainer, "sc")) {
            strokeColor = KeyframeGroup<Color>(strokeColorData.value());
        }
        if (const auto strokeWidthData = getOptionalObject(animatorContainer, "sw")) {
            strokeWidth = KeyframeGroup<Vector1D>(strokeWidthData.value());
        }
        if (const auto trackingData = getOptionalObject(animatorContainer, "t")) {
            tracking = KeyframeGroup<Vector1D>(trackingData.value());
        }
        if (const auto anchorData = getOptionalObject(animatorContainer, "a")) {
            anchor = KeyframeGroup<Vector3D>(anchorData.value());
        }
        if (const auto positionData = getOptionalObject(animatorContainer, "p")) {
            position = KeyframeGroup<Vector3D>(positionData.value());
        }
        if (const auto scaleData = getOptionalObject(animatorContainer, "s")) {
            scale = KeyframeGroup<Vector3D>(scaleData.value());
        }
        if (const auto skewData = getOptionalObject(animatorContainer, "sk")) {
            skew = KeyframeGroup<Vector1D>(skewData.value());
        }
        if (const auto skewAxisData = getOptionalObject(animatorContainer, "sa")) {
            skewAxis = KeyframeGroup<Vector1D>(skewAxisData.value());
        }
        if (const auto rotationData = getOptionalObject(animatorContainer, "r")) {
            rotation = KeyframeGroup<Vector1D>(rotationData.value());
        }
        if (const auto opacityData = getOptionalObject(animatorContainer, "o")) {
            opacity = KeyframeGroup<Vector1D>(opacityData.value());
        }
    }
    
    json11::Json::object toJson() const {
        json11::Json::object animatorContainer;
        
        if (fillColor.has_value()) {
            animatorContainer.insert(std::make_pair("fc", fillColor->toJson()));
        }
        if (strokeColor.has_value()) {
            animatorContainer.insert(std::make_pair("sc", strokeColor->toJson()));
        }
        if (strokeWidth.has_value()) {
            animatorContainer.insert(std::make_pair("sw", strokeWidth->toJson()));
        }
        if (tracking.has_value()) {
            animatorContainer.insert(std::make_pair("t", tracking->toJson()));
        }
        if (anchor.has_value()) {
            animatorContainer.insert(std::make_pair("a", anchor->toJson()));
        }
        if (position.has_value()) {
            animatorContainer.insert(std::make_pair("p", position->toJson()));
        }
        if (scale.has_value()) {
            animatorContainer.insert(std::make_pair("s", scale->toJson()));
        }
        if (skew.has_value()) {
            animatorContainer.insert(std::make_pair("sk", skew->toJson()));
        }
        if (skewAxis.has_value()) {
            animatorContainer.insert(std::make_pair("sa", skewAxis->toJson()));
        }
        if (rotation.has_value()) {
            animatorContainer.insert(std::make_pair("r", rotation->toJson()));
        }
        if (opacity.has_value()) {
            animatorContainer.insert(std::make_pair("o", opacity->toJson()));
        }
        
        json11::Json::object result;
        result.insert(std::make_pair("a", animatorContainer));
        
        if (name.has_value()) {
            result.insert(std::make_pair("nm", name.value()));
        }
        if (_extraS.has_value()) {
            result.insert(std::make_pair("s", _extraS.value()));
        }
        
        return result;
    }
    
public:
    std::optional<std::string> name;
    
    /// Anchor
    std::optional<KeyframeGroup<Vector3D>> anchor;
    
    /// Position
    std::optional<KeyframeGroup<Vector3D>> position;
    
    /// Scale
    std::optional<KeyframeGroup<Vector3D>> scale;
    
    /// Skew
    std::optional<KeyframeGroup<Vector1D>> skew;
    
    /// Skew Axis
    std::optional<KeyframeGroup<Vector1D>> skewAxis;
    
    /// Rotation
    std::optional<KeyframeGroup<Vector1D>> rotation;
    
    /// Opacity
    std::optional<KeyframeGroup<Vector1D>> opacity;
    
    /// Stroke Color
    std::optional<KeyframeGroup<Color>> strokeColor;
    
    /// Fill Color
    std::optional<KeyframeGroup<Color>> fillColor;
    
    /// Stroke Width
    std::optional<KeyframeGroup<Vector1D>> strokeWidth;
    
    /// Tracking
    std::optional<KeyframeGroup<Vector1D>> tracking;
    
    std::optional<json11::Json> _extraS;
};

}

#endif /* TextAnimator_hpp */
