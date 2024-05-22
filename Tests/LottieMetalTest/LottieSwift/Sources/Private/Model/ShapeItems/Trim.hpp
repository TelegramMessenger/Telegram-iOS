#ifndef Trim_hpp
#define Trim_hpp

#include "Lottie/Private/Model/ShapeItems/ShapeItem.hpp"
#include "Lottie/Private/Model/Keyframes/KeyframeGroup.hpp"
#include "Lottie/Public/Primitives/Vectors.hpp"
#include "Lottie/Private/Parsing/JsonParsing.hpp"

namespace lottie {

enum class TrimType: int {
    Simultaneously = 1,
    Individually = 2
};

/// An item that defines trim
class Trim: public ShapeItem {
public:
    explicit Trim(json11::Json::object const &json) noexcept(false) :
    ShapeItem(json),
    start(KeyframeGroup<Vector1D>(Vector1D(0.0))),
    end(KeyframeGroup<Vector1D>(Vector1D(0.0))),
    offset(KeyframeGroup<Vector1D>(Vector1D(0.0))),
    trimType(TrimType::Simultaneously) {
        start = KeyframeGroup<Vector1D>(getObject(json, "s"));
        end = KeyframeGroup<Vector1D>(getObject(json, "e"));
        offset = KeyframeGroup<Vector1D>(getObject(json, "o"));
        
        auto trimTypeRawValue = getInt(json, "m");
        switch (trimTypeRawValue) {
            case 1:
                trimType = TrimType::Simultaneously;
                break;
            case 2:
                trimType = TrimType::Individually;
                break;
            default:
                throw LottieParsingException();
        }
    }
    
    virtual void toJson(json11::Json::object &json) const override {
        ShapeItem::toJson(json);
        
        json.insert(std::make_pair("s", start.toJson()));
        json.insert(std::make_pair("e", end.toJson()));
        json.insert(std::make_pair("o", offset.toJson()));
        json.insert(std::make_pair("m", (int)trimType));
    }
    
public:
    KeyframeGroup<Vector1D> start;
    KeyframeGroup<Vector1D> end;
    KeyframeGroup<Vector1D> offset;
    TrimType trimType;
};

}

#endif /* Trim_hpp */
