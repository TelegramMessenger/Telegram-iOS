#ifndef Interpolatable_hpp
#define Interpolatable_hpp

#include <algorithm>

namespace lottie {

double remapDouble(double value, double fromLow, double fromHigh, double toLow, double toHigh);

double clampDouble(double value, double a, double b);

}

#endif /* Interpolatable_hpp */
