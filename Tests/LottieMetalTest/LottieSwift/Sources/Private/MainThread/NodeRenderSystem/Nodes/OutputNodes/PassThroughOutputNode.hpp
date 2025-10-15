#ifndef PassThroughOutputNode_hpp
#define PassThroughOutputNode_hpp

#include "Lottie/Private/MainThread/NodeRenderSystem/NodeProperties/Protocols/HasRenderUpdates.hpp"
#include "Lottie/Private/MainThread/NodeRenderSystem/NodeProperties/Protocols/HasUpdate.hpp"
#include "Lottie/Private/MainThread/NodeRenderSystem/Protocols/NodeOutput.hpp"

namespace lottie {

class PassThroughOutputNode: virtual public NodeOutput, virtual public HasRenderUpdates, virtual public HasUpdate {
public:
    PassThroughOutputNode(std::shared_ptr<NodeOutput> parent) :
    _parent(parent) {
    }
    
    virtual std::shared_ptr<NodeOutput> parent() override {
        return _parent;
    }
    
    virtual bool isEnabled() const override {
        return _isEnabled;
    }
    virtual void setIsEnabled(bool isEnabled) override {
        _isEnabled = isEnabled;
    }
    
    virtual bool hasUpdate() override {
        return _hasUpdate;
    }
    void setHasUpdate(bool hasUpdate) {
        _hasUpdate = hasUpdate;
    }
    
    virtual std::shared_ptr<CGPath> outputPath() override {
        if (_parent) {
            return _parent->outputPath();
        }
        return nullptr;
    }
    
    virtual bool hasOutputUpdates(double forFrame) override {
        /// Changes to this node do not affect downstream nodes.
        bool parentUpdate = false;
        if (_parent) {
            parentUpdate = _parent->hasOutputUpdates(forFrame);
        }
        /// Changes to upstream nodes do, however, affect this nodes state.
        _hasUpdate = _hasUpdate || parentUpdate;
        return parentUpdate;
    }
    
    virtual bool hasRenderUpdates(double forFrame) override {
        /// Return true if there are upstream updates or if this node has updates
        bool upstreamUpdates = false;
        if (_parent) {
            upstreamUpdates = _parent->hasOutputUpdates(forFrame);
        }
        _hasUpdate = _hasUpdate || upstreamUpdates;
        return _hasUpdate;
    }
    
private:
    std::shared_ptr<NodeOutput> _parent;
    bool _hasUpdate = false;
    bool _isEnabled = true;
};

}

#endif /* PassThroughOutputNode_hpp */
