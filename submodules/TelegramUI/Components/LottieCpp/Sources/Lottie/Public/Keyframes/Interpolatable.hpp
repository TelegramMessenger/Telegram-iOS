#ifndef Interpolatable_hpp
#define Interpolatable_hpp

#include <algorithm>

namespace lottie {

float remapFloat(float value, float fromLow, float fromHigh, float toLow, float toHigh);

float clampFloat(float value, float a, float b);

}

#endif /* Interpolatable_hpp */
