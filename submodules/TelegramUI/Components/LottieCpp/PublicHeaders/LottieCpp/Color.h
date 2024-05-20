#ifndef LottieColor_h
#define LottieColor_h

#ifdef __cplusplus

#include <LottieCpp/lottiejson11.hpp>
#include <string>

namespace lottie {

enum class ColorFormatDenominator {
    One,
    OneHundred,
    TwoFiftyFive
};

struct Color {
    float r;
    float g;
    float b;
    float a;
    
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
    
    explicit Color(float r_, float g_, float b_, float a_, ColorFormatDenominator denominator = ColorFormatDenominator::One);
    explicit Color(lottiejson11::Json const &jsonAny) noexcept(false);

    lottiejson11::Json toJson() const;
    
    static Color fromString(std::string const &string);
};

}

#endif

#endif /* LottieColor_h */
