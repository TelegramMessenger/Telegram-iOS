#ifndef Rectangle_hpp
#define Rectangle_hpp

#include "Lottie/Private/Model/ShapeItems/ShapeItem.hpp"
#include "Lottie/Private/Model/ShapeItems/Ellipse.hpp"
#include "Lottie/Private/Model/Keyframes/KeyframeGroup.hpp"
#include "Lottie/Private/Parsing/JsonParsing.hpp"

namespace lottie {

/// An item that define an ellipse shape
class Rectangle: public ShapeItem {
public:
    explicit Rectangle(json11::Json::object const &json) noexcept(false) :
    ShapeItem(json),
    position(KeyframeGroup<Vector3D>(Vector3D(0.0, 0.0, 0.0))),
    size(KeyframeGroup<Vector3D>(Vector3D(0.0, 0.0, 0.0))),
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
        
        position = KeyframeGroup<Vector3D>(getObject(json, "p"));
        size = KeyframeGroup<Vector3D>(getObject(json, "s"));
        cornerRadius = KeyframeGroup<Vector1D>(getObject(json, "r"));
    }
    
    explicit Rectangle(
       std::optional<std::string> name_,
       std::optional<std::string> matchName_,
       std::optional<int> expressionIndex_,
       std::optional<int> cix_,
       std::optional<bool> _hidden_,
       std::optional<int> index_,
       std::optional<int> blendMode_,
       std::optional<std::string> layerClass_,
       std::optional<PathDirection> direction_,
       KeyframeGroup<Vector3D> position_,
       KeyframeGroup<Vector3D> size_,
       KeyframeGroup<Vector1D> cornerRadius_
    ) :
    ShapeItem(
        name_,
        matchName_,
        expressionIndex_,
        cix_,
        ShapeType::Rectangle,
        _hidden_,
        index_,
        blendMode_,
        layerClass_
    ),
    direction(direction_),
    position(position_),
    size(size_),
    cornerRadius(cornerRadius_) {
    }
    
    virtual void toJson(json11::Json::object &json) const override {
        ShapeItem::toJson(json);
        
        if (direction.has_value()) {
            json.insert(std::make_pair("d", (int)direction.value()));
        }
        
        json.insert(std::make_pair("p", position.toJson()));
        json.insert(std::make_pair("s", size.toJson()));
        json.insert(std::make_pair("r", cornerRadius.toJson()));
    }
    
public:
    /// The direction of the rect.
    std::optional<PathDirection> direction;
    
    /// The position
    KeyframeGroup<Vector3D> position;
    
    /// The size
    KeyframeGroup<Vector3D> size;
    
    /// The Corner radius of the rectangle
    KeyframeGroup<Vector1D> cornerRadius;
};

}

#endif /* Rectangle_hpp */
