#ifndef Repeater_hpp
#define Repeater_hpp

#include "Lottie/Private/Model/ShapeItems/ShapeItem.hpp"
#include "Lottie/Private/Model/Keyframes/KeyframeGroup.hpp"
#include "Lottie/Private/Parsing/JsonParsing.hpp"

namespace lottie {

/// An item that define a repeater
class Repeater: public ShapeItem {
public:
    explicit Repeater(json11::Json::object const &json) noexcept(false) :
    ShapeItem(json) {
        if (const auto copiesData = getOptionalObject(json, "c")) {
            copies = KeyframeGroup<Vector1D>(copiesData.value());
        }
        if (const auto offsetData = getOptionalObject(json, "o")) {
            offset = KeyframeGroup<Vector1D>(offsetData.value());
        }
        
        auto transformContainer = getObject(json, "tr");
        if (const auto startOpacityData = getOptionalObject(transformContainer, "so")) {
            startOpacity = KeyframeGroup<Vector1D>(startOpacityData.value());
        }
        if (const auto endOpacityData = getOptionalObject(transformContainer, "eo")) {
            endOpacity = KeyframeGroup<Vector1D>(endOpacityData.value());
        }
        if (const auto rotationData = getOptionalObject(transformContainer, "r")) {
            rotation = KeyframeGroup<Vector1D>(rotationData.value());
        }
        if (const auto positionData = getOptionalObject(transformContainer, "p")) {
            position = KeyframeGroup<Vector3D>(positionData.value());
        }
        if (const auto scaleData = getOptionalObject(transformContainer, "s")) {
            scale = KeyframeGroup<Vector3D>(scaleData.value());
        }
    }
    
    virtual void toJson(json11::Json::object &json) const override {
        ShapeItem::toJson(json);
        
        if (copies.has_value()) {
            json.insert(std::make_pair("c", copies->toJson()));
        }
        if (offset.has_value()) {
            json.insert(std::make_pair("o", offset->toJson()));
        }
        
        json11::Json::object transformContainer;
        if (startOpacity.has_value()) {
            json.insert(std::make_pair("so", startOpacity->toJson()));
        }
        if (endOpacity.has_value()) {
            json.insert(std::make_pair("eo", endOpacity->toJson()));
        }
        if (rotation.has_value()) {
            json.insert(std::make_pair("r", rotation->toJson()));
        }
        if (position.has_value()) {
            json.insert(std::make_pair("p", position->toJson()));
        }
        if (scale.has_value()) {
            json.insert(std::make_pair("s", scale->toJson()));
        }
        
        json.insert(std::make_pair("tr", transformContainer));
    }
    
public:
    /// The number of copies to repeat
    std::optional<KeyframeGroup<Vector1D>> copies;
    
    /// The offset of each copy
    std::optional<KeyframeGroup<Vector1D>> offset;
    
    /// Start Opacity
    std::optional<KeyframeGroup<Vector1D>> startOpacity;
    
    /// End opacity
    std::optional<KeyframeGroup<Vector1D>> endOpacity;
    
    /// The rotation
    std::optional<KeyframeGroup<Vector1D>> rotation;
    
    /// Anchor Point
    std::optional<KeyframeGroup<Vector3D>> anchorPoint;
    
    /// Position
    std::optional<KeyframeGroup<Vector3D>> position;
    
    /// Scale
    std::optional<KeyframeGroup<Vector3D>> scale;
};

}

#endif /* Repeater_hpp */
