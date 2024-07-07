#ifndef NodePropertyMap_hpp
#define NodePropertyMap_hpp

#include "Lottie/Private/MainThread/NodeRenderSystem/NodeProperties/Protocols/AnyNodeProperty.hpp"
#include "Lottie/Private/MainThread/NodeRenderSystem/NodeProperties/Protocols/KeypathSearchable.hpp"
#include "Lottie/Public/Primitives/CALayer.hpp"

#include <vector>

namespace lottie {

class NodePropertyMap: virtual public HasChildKeypaths {
public:
    virtual std::vector<std::shared_ptr<AnyNodeProperty>> &properties() = 0;
    
    bool needsLocalUpdate(double frame) {
        for (auto &property : properties()) {
            if (property->needsUpdate(frame)) {
                return true;
            }
        }
        return false;
    }
    
    void updateNodeProperties(double frame) {
        for (auto &property : properties()) {
            property->update(frame);
        }
    }
};

class KeypathSearchableNodePropertyMap: virtual public NodePropertyMap, virtual public KeypathSearchable {
public:
    virtual std::shared_ptr<CALayer> keypathLayer() {
        return nullptr;
    }
};

}

#endif /* NodePropertyMap_hpp */
