#include "ValueInterpolators.hpp"

#include <Accelerate/Accelerate.h>

namespace lottie {

void batchInterpolate(std::vector<PathElement> const &from, std::vector<PathElement> const &to, BezierPath &resultPath, float amount) {
    int elementCount = (int)from.size();
    if (elementCount > (int)to.size()) {
        elementCount = (int)to.size();
    }
    
    static_assert(sizeof(PathElement) == 4 * 2 * 3);
    
    resultPath.setElementCount(elementCount);
    float floatAmount = (float)amount;
    vDSP_vintb((float *)&from[0], 1, (float *)&to[0], 1, &floatAmount, (float *)&resultPath.elements()[0], 1, elementCount * 2 * 3);
}

}
