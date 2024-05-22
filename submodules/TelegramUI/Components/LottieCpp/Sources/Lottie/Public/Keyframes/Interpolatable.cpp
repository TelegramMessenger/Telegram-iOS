#include "Interpolatable.hpp"

namespace lottie {

float remapFloat(float value, float fromLow, float fromHigh, float toLow, float toHigh) {
    return toLow + (value - fromLow) * (toHigh - toLow) / (fromHigh - fromLow);
}

float clampFloat(float value, float a, float b) {
    float minValue = a <= b ? a : b;
    float maxValue = a <= b ? b : a;
    return std::max(std::min(value, maxValue), minValue);
}

}
