#ifndef Shape_hpp
#define Shape_hpp

#include "Lottie/Private/Model/ShapeItems/ShapeItem.hpp"
#include "Lottie/Private/Model/ShapeItems/Ellipse.hpp"
#include "Lottie/Private/Utility/Primitives/BezierPath.hpp"
#include "Lottie/Private/Parsing/JsonParsing.hpp"

#include <optional>

namespace lottie {

/// An item that defines an custom shape
class Shape: public ShapeItem {
public:
    explicit Shape(json11::Json::object const &json) noexcept(false) :
    ShapeItem(json),
    path(KeyframeGroup<BezierPath>(getObject(json, "ks"))) {
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
    }
    
    virtual void toJson(json11::Json::object &json) const override {
        ShapeItem::toJson(json);
        
        json.insert(std::make_pair("ks", path.toJson()));
        
        if (direction.has_value()) {
            json.insert(std::make_pair("d", (int)direction.value()));
        }
    }
    
public:
    KeyframeGroup<BezierPath> path;
    std::optional<PathDirection> direction;
};

}

#endif /* Shape_hpp */
