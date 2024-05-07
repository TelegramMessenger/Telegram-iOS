#ifndef NodeOutput_hpp
#define NodeOutput_hpp

#include "Lottie/Public/Primitives/CGPath.hpp"

#include <memory>

namespace lottie {

/// Defines the basic outputs of an animator node.
///
class NodeOutput {
public:
    /// The parent node.
    virtual std::shared_ptr<NodeOutput> parent() = 0;
    
    /// Returns true if there are any updates upstream. OutputPath must be built before returning.
    virtual bool hasOutputUpdates(double forFrame) = 0;
    
    virtual std::shared_ptr<CGPath> outputPath() = 0;
    
    virtual bool isEnabled() const = 0;
    virtual void setIsEnabled(bool isEnabled) = 0;
};

}

#endif /* NodeOutput_hpp */
