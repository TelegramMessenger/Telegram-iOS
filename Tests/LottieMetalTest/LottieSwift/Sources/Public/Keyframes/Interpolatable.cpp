#include "Interpolatable.hpp"

namespace lottie {

double remapDouble(double value, double fromLow, double fromHigh, double toLow, double toHigh) {
    return toLow + (value - fromLow) * (toHigh - toLow) / (fromHigh - fromLow);
}

double clampDouble(double value, double a, double b) {
    double minValue = a <= b ? a : b;
    double maxValue = a <= b ? b : a;
    return std::max(std::min(value, maxValue), minValue);
}

}
