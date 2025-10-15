#ifndef Marker_hpp
#define Marker_hpp

#include "Lottie/Public/Primitives/AnimationTime.hpp"
#include "Lottie/Private/Parsing/JsonParsing.hpp"

#include <string>

namespace lottie {

class Marker {
public:
    Marker(
        std::string const &name_,
        AnimationFrameTime frameTime_
    ) :
    name(name_),
    frameTime(frameTime_) {
    }
    
    explicit Marker(json11::Json::object const &json) noexcept(false) {
        name = getString(json, "cm");
        frameTime = getDouble(json, "tm");
        dr = getOptionalInt(json, "dr");
    }
    
    json11::Json::object toJson() const {
        json11::Json::object result;
        
        result.insert(std::make_pair("cm", name));
        result.insert(std::make_pair("tm", frameTime));
        
        if (dr.has_value()) {
            result.insert(std::make_pair("dr", dr.value()));
        }
        
        return result;
    }
    
public:
    /// The Marker Name
    std::string name;
    
    /// The Frame time of the marker
    AnimationFrameTime frameTime;
    
    std::optional<int> dr;
};

}

#endif /* Marker_hpp */
