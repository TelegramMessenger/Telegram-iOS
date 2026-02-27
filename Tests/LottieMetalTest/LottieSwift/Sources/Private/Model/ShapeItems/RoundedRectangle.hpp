#ifndef RoundedRectangle_hpp
#define RoundedRectangle_hpp

#include "Lottie/Private/Model/ShapeItems/ShapeItem.hpp"
#include "Lottie/Private/Model/ShapeItems/Ellipse.hpp"
#include "Lottie/Private/Model/Keyframes/KeyframeGroup.hpp"
#include "Lottie/Private/Parsing/JsonParsing.hpp"

namespace lottie {

/// An item that define an ellipse shape
class RoundedRectangle: public ShapeItem {
public:
    explicit RoundedRectangle(json11::Json::object const &json) noexcept(false) :
    ShapeItem(json),
    cornerRadius(KeyframeGroup<Vector1D>(Vector1D(0.0))) {
        if (const auto directionRawValue = getOptionalInt(json, "d")) {
            switch (directionRawValue.value()) {
                case 1:
                    direction = PathDirection::Clockwise;
                    break;
                case 2:
                    direction = PathDirection::UserSetClockwise;
                    break;
                case 3:
                    direction = PathDirection::CounterClockwise;
                    break;
                default:
                    throw LottieParsingException();
            }
        }
        
        if (const auto positionData = getOptionalObject(json, "p")) {
            position = KeyframeGroup<Vector3D>(positionData.value());
        }
        if (const auto sizeData = getOptionalObject(json, "s")) {
            size = KeyframeGroup<Vector3D>(sizeData.value());
        }
        
        cornerRadius = KeyframeGroup<Vector1D>(getObject(json, "r"));
    }
    
    virtual void toJson(json11::Json::object &json) const override {
        ShapeItem::toJson(json);
        
        if (direction.has_value()) {
            json.insert(std::make_pair("d", (int)direction.value()));
        }
        if (position.has_value()) {
            json.insert(std::make_pair("p", position->toJson()));
        }
        if (size.has_value()) {
            json.insert(std::make_pair("s", size->toJson()));
        }
        
        json.insert(std::make_pair("r", cornerRadius.toJson()));
    }
    
public:
    /// The direction of the rect.
    std::optional<PathDirection> direction;
    
    /// The position
    std::optional<KeyframeGroup<Vector3D>> position;
    
    /// The size
    std::optional<KeyframeGroup<Vector3D>> size;
    
    /// The Corner radius of the rectangle
    KeyframeGroup<Vector1D> cornerRadius;
};

}

#endif /* RoundedRectangle_hpp */
