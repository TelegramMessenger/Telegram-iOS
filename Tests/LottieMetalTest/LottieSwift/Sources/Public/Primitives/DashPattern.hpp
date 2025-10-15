#ifndef DashPattern_hpp
#define DashPattern_hpp

#include <vector>

namespace lottie {

struct DashPattern {
    DashPattern(std::vector<double> &&values_) :
    values(std::move(values_)) {
    }
    
    std::vector<double> values;
};

}

#endif /* DashPattern_hpp */
