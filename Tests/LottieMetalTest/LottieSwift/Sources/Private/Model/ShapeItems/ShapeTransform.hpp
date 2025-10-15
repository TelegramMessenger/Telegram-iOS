#ifndef ShapeTransform_hpp
#define ShapeTransform_hpp

#include "Lottie/Private/Model/ShapeItems/ShapeItem.hpp"
#include "Lottie/Private/Model/Keyframes/KeyframeGroup.hpp"
#include "Lottie/Private/Parsing/JsonParsing.hpp"

namespace lottie {

/// An item that define a shape transform
class ShapeTransform: public ShapeItem {
public:
    explicit ShapeTransform(json11::Json::object const &json) noexcept(false) :
    ShapeItem(json) {
        if (const auto anchorData = getOptionalObject(json, "a")) {
            anchor = KeyframeGroup<Vector3D>(anchorData.value());
        }
        if (const auto positionData = getOptionalObject(json, "p")) {
            position = KeyframeGroup<Vector3D>(positionData.value());
        }
        if (const auto scaleData = getOptionalObject(json, "s")) {
            scale = KeyframeGroup<Vector3D>(scaleData.value());
        }
        if (const auto rotationData = getOptionalObject(json, "r")) {
            rotation = KeyframeGroup<Vector1D>(rotationData.value());
        }
        if (const auto opacityData = getOptionalObject(json, "o")) {
            opacity = KeyframeGroup<Vector1D>(opacityData.value());
        }
        if (const auto skewData = getOptionalObject(json, "sk")) {
            skew = KeyframeGroup<Vector1D>(skewData.value());
        }
        if (const auto skewAxisData = getOptionalObject(json, "sa")) {
            skewAxis = KeyframeGroup<Vector1D>(skewAxisData.value());
        }
    }
    
    virtual void toJson(json11::Json::object &json) const override {
        ShapeItem::toJson(json);
        
        if (anchor.has_value()) {
            json.insert(std::make_pair("a", anchor->toJson()));
        }
        if (position.has_value()) {
            json.insert(std::make_pair("p", position->toJson()));
        }
        if (scale.has_value()) {
            json.insert(std::make_pair("s", scale->toJson()));
        }
        if (rotation.has_value()) {
            json.insert(std::make_pair("r", rotation->toJson()));
        }
        if (opacity.has_value()) {
            json.insert(std::make_pair("o", opacity->toJson()));
        }
        if (skew.has_value()) {
            json.insert(std::make_pair("sk", skew->toJson()));
        }
        if (skewAxis.has_value()) {
            json.insert(std::make_pair("sa", skewAxis->toJson()));
        }
    }
    
public:
    /// Anchor Point
    std::optional<KeyframeGroup<Vector3D>> anchor;
    
    /// Position
    std::optional<KeyframeGroup<Vector3D>> position;
    
    /// Scale
    std::optional<KeyframeGroup<Vector3D>> scale;
    
    /// Rotation
    std::optional<KeyframeGroup<Vector1D>> rotation;
    
    /// opacity
    std::optional<KeyframeGroup<Vector1D>> opacity;
    
    /// Skew
    std::optional<KeyframeGroup<Vector1D>> skew;
    
    /// Skew Axis
    std::optional<KeyframeGroup<Vector1D>> skewAxis;
};

}

#endif /* ShapeTransform_hpp */
