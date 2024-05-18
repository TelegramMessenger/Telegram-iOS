#ifndef DashPattern_hpp
#define DashPattern_hpp

#include <vector>

namespace lottie {

struct DashPattern {
    DashPattern(std::vector<float> &&values_) :
    values(std::move(values_)) {
    }
    
    std::vector<float> values;
};

}

#endif /* DashPattern_hpp */
