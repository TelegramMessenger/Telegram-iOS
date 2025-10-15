#ifndef FitzModifier_hpp
#define FitzModifier_hpp

#include "Lottie/Private/Parsing/JsonParsing.hpp"

namespace lottie {

class FitzModifier {
public:
    explicit FitzModifier(json11::Json::object const &json) noexcept(false) {
        original = getInt(json, "o");
        type12 = getOptionalInt(json, "f12");
        type3 = getOptionalInt(json, "f3");
        type4 = getOptionalInt(json, "f4");
        type5 = getOptionalInt(json, "f5");
        type6 = getOptionalInt(json, "f6");
    }
    
    json11::Json::object toJson() const {
        json11::Json::object result;
        
        result.insert(std::make_pair("o", (double)original));
        if (type12.has_value()) {
            result.insert(std::make_pair("f12", (double)type12.value()));
        }
        if (type3.has_value()) {
            result.insert(std::make_pair("f3", (double)type3.value()));
        }
        if (type4.has_value()) {
            result.insert(std::make_pair("f4", (double)type4.value()));
        }
        if (type5.has_value()) {
            result.insert(std::make_pair("f5", (double)type5.value()));
        }
        if (type6.has_value()) {
            result.insert(std::make_pair("f6", (double)type6.value()));
        }
        
        return result;
    }
    
public:
    double original;
    std::optional<double> type12;
    std::optional<double> type3;
    std::optional<double> type4;
    std::optional<double> type5;
    std::optional<double> type6;
};

}

#endif /* FitzModifier_hpp */
