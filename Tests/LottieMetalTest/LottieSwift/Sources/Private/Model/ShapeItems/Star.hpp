#ifndef Star_hpp
#define Star_hpp

#include "Lottie/Private/Model/ShapeItems/ShapeItem.hpp"
#include "Lottie/Private/Model/ShapeItems/Ellipse.hpp"
#include "Lottie/Private/Model/Keyframes/KeyframeGroup.hpp"
#include "Lottie/Private/Parsing/JsonParsing.hpp"

#include <optional>

namespace lottie {

enum class StarType: int {
    None = 0,
    Star = 1,
    Polygon = 2
};

/// An item that define a star shape
class Star: public ShapeItem {
public:
    explicit Star(json11::Json::object const &json) noexcept(false) :
    ShapeItem(json),
    position(KeyframeGroup<Vector3D>(Vector3D(0.0, 0.0, 0.0))),
    outerRadius(KeyframeGroup<Vector1D>(Vector1D(0.0))),
    outerRoundness(KeyframeGroup<Vector1D>(Vector1D(0.0))),
    rotation(KeyframeGroup<Vector1D>(Vector1D(0.0))),
    points(KeyframeGroup<Vector1D>(Vector1D(0.0))),
    starType(StarType::None) {
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
        outerRadius = KeyframeGroup<Vector1D>(getObject(json, "or"));
        outerRoundness = KeyframeGroup<Vector1D>(getObject(json, "os"));
        
        if (const auto innerRadiusData = getOptionalObject(json, "ir")) {
            innerRadius = KeyframeGroup<Vector1D>(innerRadiusData.value());
        }
        if (const auto innerRoundnessData = getOptionalObject(json, "is")) {
            innerRoundness = KeyframeGroup<Vector1D>(innerRoundnessData.value());
        }
        
        rotation = KeyframeGroup<Vector1D>(getObject(json, "r"));
        points = KeyframeGroup<Vector1D>(getObject(json, "pt"));
        
        auto starTypeRawValue = getInt(json, "sy");
        switch (starTypeRawValue) {
            case 0:
                starType = StarType::None;
                break;
            case 1:
                starType = StarType::Star;
                break;
            case 2:
                starType = StarType::Polygon;
                break;
            default:
                throw LottieParsingException();
        }
    }
    
    virtual void toJson(json11::Json::object &json) const override {
        ShapeItem::toJson(json);
        
        if (direction.has_value()) {
            json.insert(std::make_pair("d", (int)direction.value()));
        }
        
        json.insert(std::make_pair("p", position.toJson()));
        json.insert(std::make_pair("or", outerRadius.toJson()));
        json.insert(std::make_pair("os", outerRoundness.toJson()));
        
        if (innerRadius.has_value()) {
            json.insert(std::make_pair("ir", innerRadius->toJson()));
        }
        if (innerRoundness.has_value()) {
            json.insert(std::make_pair("is", innerRoundness->toJson()));
        }
        
        json.insert(std::make_pair("r", rotation.toJson()));
        json.insert(std::make_pair("pt", points.toJson()));
        
        json.insert(std::make_pair("sy", (int)starType));
    }
    
public:
    /// The direction of the star.
    std::optional<PathDirection> direction;
    
    /// The position of the star
    KeyframeGroup<Vector3D> position;
    
    /// The outer radius of the star
    KeyframeGroup<Vector1D> outerRadius;
    
    /// The outer roundness of the star
    KeyframeGroup<Vector1D> outerRoundness;
    
    /// The outer radius of the star
    std::optional<KeyframeGroup<Vector1D>> innerRadius;
    
    /// The outer roundness of the star
    std::optional<KeyframeGroup<Vector1D>> innerRoundness;
    
    /// The rotation of the star
    KeyframeGroup<Vector1D> rotation;
    
    /// The number of points on the star
    KeyframeGroup<Vector1D> points;
    
    /// The type of star
    StarType starType;
};

}

#endif /* Star_hpp */
