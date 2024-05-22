#ifndef FitzModifier_hpp
#define FitzModifier_hpp

#include "Lottie/Private/Parsing/JsonParsing.hpp"

namespace lottie {

class FitzModifier {
public:
    explicit FitzModifier(lottiejson11::Json::object const &json) noexcept(false) {
        original = getInt(json, "o");
        type12 = getOptionalInt(json, "f12");
        type3 = getOptionalInt(json, "f3");
        type4 = getOptionalInt(json, "f4");
        type5 = getOptionalInt(json, "f5");
        type6 = getOptionalInt(json, "f6");
    }
    
    lottiejson11::Json::object toJson() const {
        lottiejson11::Json::object result;
        
        result.insert(std::make_pair("o", (float)original));
        if (type12.has_value()) {
            result.insert(std::make_pair("f12", (float)type12.value()));
        }
        if (type3.has_value()) {
            result.insert(std::make_pair("f3", (float)type3.value()));
        }
        if (type4.has_value()) {
            result.insert(std::make_pair("f4", (float)type4.value()));
        }
        if (type5.has_value()) {
            result.insert(std::make_pair("f5", (float)type5.value()));
        }
        if (type6.has_value()) {
            result.insert(std::make_pair("f6", (float)type6.value()));
        }
        
        return result;
    }
    
public:
    float original;
    std::optional<float> type12;
    std::optional<float> type3;
    std::optional<float> type4;
    std::optional<float> type5;
    std::optional<float> type6;
};

}

#endif /* FitzModifier_hpp */
