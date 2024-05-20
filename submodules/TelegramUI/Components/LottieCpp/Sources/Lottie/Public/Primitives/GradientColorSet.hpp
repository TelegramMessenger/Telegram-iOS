#ifndef GradientColorSet_hpp
#define GradientColorSet_hpp

#include "Lottie/Private/Parsing/JsonParsing.hpp"

#include <vector>

namespace lottie {

struct GradientColorSet {
    GradientColorSet() {
    }
    
    explicit GradientColorSet(lottiejson11::Json const &jsonAny) noexcept(false) {
        if (!jsonAny.is_array()) {
            throw LottieParsingException();
        }
        
        for (const auto &item : jsonAny.array_items()) {
            if (!item.is_number()) {
                throw LottieParsingException();
            }
            colors.push_back(item.number_value());
        }
    }
    
    lottiejson11::Json toJson() const {
        lottiejson11::Json::array result;
        
        for (auto value : colors) {
            result.push_back(value);
        }
        
        return result;
    }
    
    std::vector<float> colors;
};

}

#endif /* GradientColorSet_hpp */
