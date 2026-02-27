#include "Color.hpp"

#include <sstream>

namespace lottie {

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
        ((double)((rgbValue & 0xFF0000) >> 16)) / 255.0,
        ((double)((rgbValue & 0x00FF00) >> 8)) / 255.0,
        ((double)(rgbValue & 0x0000FF)) / 255.0,
        1.0
    );
}

}
