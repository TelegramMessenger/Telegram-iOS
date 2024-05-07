#ifndef KeypathSearchable_hpp
#define KeypathSearchable_hpp

#include "Lottie/Private/MainThread/NodeRenderSystem/NodeProperties/Protocols/AnyNodeProperty.hpp"
#include "Lottie/Public/Primitives/CALayer.hpp"

#include <string>
#include <vector>
#include <map>
#include <memory>

namespace lottie {

class KeypathSearchable;

class HasChildKeypaths {
public:
    /// Children Keypaths
    virtual std::vector<std::shared_ptr<KeypathSearchable>> const &childKeypaths() const = 0;
};

/// Protocol that provides keypath search functionality. Returns all node properties associated with a keypath.
class KeypathSearchable: virtual public HasChildKeypaths {
public:
    /// The name of the Keypath
    virtual std::string keypathName() const = 0;
    
    /// A list of properties belonging to the keypath.
    virtual std::map<std::string, std::shared_ptr<AnyNodeProperty>> keypathProperties() const = 0;
    
    virtual std::shared_ptr<CALayer> keypathLayer() const = 0;
};

}

#endif /* KeypathSearchable_hpp */
