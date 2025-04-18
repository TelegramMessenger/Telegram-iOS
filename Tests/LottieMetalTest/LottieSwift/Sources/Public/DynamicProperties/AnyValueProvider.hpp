#ifndef AnyValueProvider_hpp
#define AnyValueProvider_hpp

#include "Lottie/Public/Primitives/AnimationTime.hpp"
#include "Lottie/Private/Model/Keyframes/KeyframeGroup.hpp"
#include "Lottie/Public/Primitives/AnyValue.hpp"

#include <vector>
#include <memory>

namespace lottie {

/// `AnyValueProvider` is a protocol that return animation data for a property at a
/// given time. Every frame an `AnimationView` queries all of its properties and asks
/// if their ValueProvider has an update. If it does the AnimationView will read the
/// property and update that portion of the animation.
///
/// Value Providers can be used to dynamically set animation properties at run time.
class AnyValueProvider {
public:
    /// The Type of the value provider
    virtual AnyValue::Type valueType() const = 0;
    
    /// Asks the provider if it has an update for the given frame.
    virtual bool hasUpdate(AnimationFrameTime frame) const = 0;
};

/// A base protocol for strongly-typed Value Providers
template<typename T>
class ValueProvider: public AnyValueProvider {
public:
    /// Asks the provider to update the container with its value for the frame.
    virtual T value(AnimationFrameTime frame) = 0;
};

}

#endif /* AnyValueProvider_hpp */
