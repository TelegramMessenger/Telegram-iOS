#include <LottieCpp/Color.h>

#include "Lottie/Private/Parsing/JsonParsing.hpp"

#include <sstream>

namespace lottie {

Color::Color(float r_, float g_, float b_, float a_, ColorFormatDenominator denominator) {
    float denominatorValue = 1.0;
    switch (denominator) {
        case ColorFormatDenominator::One: {
            denominatorValue = 1.0;
            break;
        }
        case ColorFormatDenominator::OneHundred: {
            denominatorValue = 100.0;
            break;
        }
        case ColorFormatDenominator::TwoFiftyFive: {
            denominatorValue = 255.0;
            break;
        }
    }
    
    r = r_ / denominatorValue;
    g = g_ / denominatorValue;
    b = b_ / denominatorValue;
    a = a_ / denominatorValue;
}

Color::Color(lottiejson11::Json const &jsonAny) noexcept(false) :
    r(0.0), g(0.0), b(0.0), a(0.0) {
    if (!jsonAny.is_array()) {
        throw LottieParsingException();
    }
    
    for (const auto &item : jsonAny.array_items()) {
        if (!item.is_number()) {
            throw LottieParsingException();
        }
    }
    
    size_t index = 0;
    
    float r1 = 0.0;
    if (index < jsonAny.array_items().size()) {
        if (!jsonAny.array_items()[index].is_number()) {
            throw LottieParsingException();
        }
        r1 = jsonAny.array_items()[index].number_value();
        index++;
    }
    
    float g1 = 0.0;
    if (index < jsonAny.array_items().size()) {
        if (!jsonAny.array_items()[index].is_number()) {
            throw LottieParsingException();
        }
        g1 = jsonAny.array_items()[index].number_value();
        index++;
    }
    
    float b1 = 0.0;
    if (index < jsonAny.array_items().size()) {
        if (!jsonAny.array_items()[index].is_number()) {
            throw LottieParsingException();
        }
        b1 = jsonAny.array_items()[index].number_value();
        index++;
    }
    
    float a1 = 0.0;
    if (index < jsonAny.array_items().size()) {
        if (!jsonAny.array_items()[index].is_number()) {
            throw LottieParsingException();
        }
        a1 = jsonAny.array_items()[index].number_value();
        index++;
    }
    
    if (r1 > 1.0 && r1 > 1.0 && b1 > 1.0 && a1 > 1.0) {
        r1 = r1 / 255.0;
        g1 = g1 / 255.0;
        b1 = b1 / 255.0;
        a1 = a1 / 255.0;
    }
    
    r = r1;
    g = g1;
    b = b1;
    a = a1;
}

lottiejson11::Json Color::toJson() const {
    lottiejson11::Json::array result;
    
    result.push_back(lottiejson11::Json(r));
    result.push_back(lottiejson11::Json(g));
    result.push_back(lottiejson11::Json(b));
    result.push_back(lottiejson11::Json(a));
    
    return result;
}

Color Color::fromString(std::string const &string) {
    if (string.empty()) {
        return Color(0.0, 0.0, 0.0, 0.0);
    }
    
    std::string workString = string;
    if (workString[0] == '#') {
        workString.erase(workString.begin());
    }
    
    std::istringstream converter(workString);
    uint32_t rgbValue;
    converter >> std::hex >> rgbValue;

    return Color(
        ((float)((rgbValue & 0xFF0000) >> 16)) / 255.0,
        ((float)((rgbValue & 0x00FF00) >> 8)) / 255.0,
        ((float)(rgbValue & 0x0000FF)) / 255.0,
        1.0
    );
}

}
