#ifndef Color_hpp
#define Color_hpp

#include "Lottie/Private/Parsing/JsonParsing.hpp"

#include <string>

namespace lottie {

enum class ColorFormatDenominator {
    One,
    OneHundred,
    TwoFiftyFive
};

struct Color {
    double r;
    double g;
    double b;
    double a;
    
    bool operator==(Color const &rhs) const {
        if (r != rhs.r) {
            return false;
        }
        if (g != rhs.g) {
            return false;
        }
        if (b != rhs.b) {
            return false;
        }
        if (a != rhs.a) {
            return false;
        }
        return true;
    }
    
    bool operator!=(Color const &rhs) const {
        return !(*this == rhs);
    }
    
    explicit Color(double r_, double g_, double b_, double a_, ColorFormatDenominator denominator = ColorFormatDenominator::One) {
        double denominatorValue = 1.0;
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
    
    explicit Color(json11::Json const &jsonAny) noexcept(false) :
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
        
        double r1 = 0.0;
        if (index < jsonAny.array_items().size()) {
            if (!jsonAny.array_items()[index].is_number()) {
                throw LottieParsingException();
            }
            r1 = jsonAny.array_items()[index].number_value();
            index++;
        }
        
        double g1 = 0.0;
        if (index < jsonAny.array_items().size()) {
            if (!jsonAny.array_items()[index].is_number()) {
                throw LottieParsingException();
            }
            g1 = jsonAny.array_items()[index].number_value();
            index++;
        }
        
        double b1 = 0.0;
        if (index < jsonAny.array_items().size()) {
            if (!jsonAny.array_items()[index].is_number()) {
                throw LottieParsingException();
            }
            b1 = jsonAny.array_items()[index].number_value();
            index++;
        }
        
        double a1 = 0.0;
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
    
    json11::Json toJson() const {
        json11::Json::array result;
        
        result.push_back(json11::Json(r));
        result.push_back(json11::Json(g));
        result.push_back(json11::Json(b));
        result.push_back(json11::Json(a));
        
        return result;
    }
    
    static Color fromString(std::string const &string);
};

}

#endif /* Color_hpp */
