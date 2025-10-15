#ifndef AnyNodeProperty_hpp
#define AnyNodeProperty_hpp

#include "Lottie/Public/Primitives/AnyValue.hpp"
#include "Lottie/Private/MainThread/NodeRenderSystem/NodeProperties/Protocols/AnyValueContainer.hpp"
#include "Lottie/Public/DynamicProperties/AnyValueProvider.hpp"

#include <memory>

namespace lottie {

/// A property of a node. The node property holds a provider and a container
class AnyNodeProperty {
public:
    virtual ~AnyNodeProperty() = default;
    
public:
    /// Returns true if the property needs to recompute its stored value
    virtual bool needsUpdate(double frame) const = 0;
    
    /// Updates the property for the frame
    virtual void update(double frame) = 0;
    
    /// The Type of the value provider
    virtual AnyValue::Type valueType() const = 0;
    
    /// Sets the value provider for the property.
    virtual void setProvider(std::shared_ptr<AnyValueProvider> provider) = 0;
};

}

#endif /* AnyNodeProperty_hpp */
