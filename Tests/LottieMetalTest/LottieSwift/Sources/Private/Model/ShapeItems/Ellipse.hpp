#ifndef Ellipse_hpp
#define Ellipse_hpp

#include "Lottie/Private/Model/ShapeItems/ShapeItem.hpp"
#include "Lottie/Private/Model/Keyframes/KeyframeGroup.hpp"
#include "Lottie/Public/Primitives/Vectors.hpp"
#include "Lottie/Private/Parsing/JsonParsing.hpp"

namespace lottie {

enum class PathDirection: int {
    Clockwise = 1,
    UserSetClockwise = 2,
    CounterClockwise = 3
};

/// An item that define an ellipse shape
class Ellipse: public ShapeItem {
public:
    explicit Ellipse(json11::Json::object const &json) noexcept(false) :
    ShapeItem(json),
    position(KeyframeGroup<Vector3D>(Vector3D(0.0, 0.0, 0.0))),
    size(KeyframeGroup<Vector3D>(Vector3D(0.0, 0.0, 0.0))) {
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
        
        position = KeyframeGroup<Vector3D>(getObject(json, "p"));
        size = KeyframeGroup<Vector3D>(getObject(json, "s"));
    }
    
    virtual void toJson(json11::Json::object &json) const override {
        ShapeItem::toJson(json);
        
        if (direction.has_value()) {
            json.insert(std::make_pair("d", (int)direction.value()));
        }
        json.insert(std::make_pair("p", position.toJson()));
        json.insert(std::make_pair("s", size.toJson()));
    }
  
public:
    std::optional<PathDirection> direction;
    KeyframeGroup<Vector3D> position;
    KeyframeGroup<Vector3D> size;
};

}

#endif /* Ellipse_hpp */
