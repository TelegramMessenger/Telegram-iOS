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
    
    explicit Color(double r_, double g_, double b_, double a_, ColorFormatDenominator denominator = ColorFormatDenominator::One);
    explicit Color(lottiejson11::Json const &jsonAny) noexcept(false);

    lottiejson11::Json toJson() const;
    
    static Color fromString(std::string const &string);
};

}

#endif

#endif /* LottieColor_h */
