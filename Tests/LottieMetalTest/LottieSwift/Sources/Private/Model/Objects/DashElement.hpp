#ifndef DashElement_hpp
#define DashElement_hpp

#include "Lottie/Private/Model/Keyframes/KeyframeGroup.hpp"
#include "Lottie/Private/Parsing/JsonParsing.hpp"
#include "Lottie/Public/Primitives/DashPattern.hpp"

namespace lottie {

enum class DashElementType {
    Offset,
    Dash,
    Gap
};

class DashElement {
public:
    DashElement(
        DashElementType type_,
        KeyframeGroup<Vector1D> const &value_
    ) :
    type(type_),
    value(value_) {
    }
    
    explicit DashElement(json11::Json::object const &json) noexcept(false) :
    type(DashElementType::Offset),
    value(KeyframeGroup<Vector1D>(Vector1D(0.0))) {
        auto typeRawValue = getString(json, "n");
        if (typeRawValue == "o") {
            type = DashElementType::Offset;
        } else if (typeRawValue == "d") {
            type = DashElementType::Dash;
        } else if (typeRawValue == "g") {
            type = DashElementType::Gap;
        } else {
            throw LottieParsingException();
        }
        
        value = KeyframeGroup<Vector1D>(getObject(json, "v"));
        
        name = getOptionalString(json, "nm");
    }
    
    json11::Json::object toJson() const {
        json11::Json::object result;
        
        switch (type) {
            case DashElementType::Offset:
                result.insert(std::make_pair("n", "o"));
                break;
            case DashElementType::Dash:
                result.insert(std::make_pair("n", "d"));
                break;
            case DashElementType::Gap:
                result.insert(std::make_pair("n", "g"));
                break;
        }
        
        result.insert(std::make_pair("v", value.toJson()));
        
        if (name.has_value()) {
            result.insert(std::make_pair("nm", name.value()));
        }
        
        return result;
    }
    
public:
    DashElementType type;
    KeyframeGroup<Vector1D> value;
    
    std::optional<std::string> name;
};

}

#endif /* DashElement_hpp */
