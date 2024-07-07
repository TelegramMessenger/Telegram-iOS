#ifndef AnyValueContainer_hpp
#define AnyValueContainer_hpp

#include "Lottie/Public/Primitives/AnyValue.hpp"

namespace lottie {

class AnyValueContainer {
public:
    /// The stored value of the container
    virtual AnyValue value() const = 0;
    
    /// Notifies the provider that it should update its container
    virtual void setNeedsUpdate() = 0;
    
    /// When true the container needs to have its value updated by its provider
    virtual bool needsUpdate() const = 0;
    
    /// The frame time of the last provided update
    virtual double lastUpdateFrame() const = 0;
};

}

#endif /* AnyValueContainer_hpp */
