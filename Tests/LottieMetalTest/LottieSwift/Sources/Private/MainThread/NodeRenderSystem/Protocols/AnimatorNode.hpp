#ifndef AnimatorNode_hpp
#define AnimatorNode_hpp

#include "Lottie/Private/MainThread/NodeRenderSystem/NodeProperties/Protocols/KeypathSearchable.hpp"
#include "Lottie/Private/MainThread/NodeRenderSystem/NodeProperties/Protocols/NodePropertyMap.hpp"
#include "Lottie/Private/MainThread/NodeRenderSystem/Protocols/NodeOutput.hpp"

#include <memory>
#include <optional>

namespace lottie {

class LayerTransformNode;
class PathNode;
class RenderNode;

/// The Animator Node is the base node in the render system tree.
///
/// It defines a single node that has an output path and option input node.
/// At animation time the root animation node is asked to update its contents for
/// the current frame.
/// The node reaches up its chain of nodes until the first node that does not need
/// updating is found. Then each node updates its contents down the render pipeline.
/// Each node adds its local path to its input path and passes it forward.
///
/// An animator node holds a group of interpolators. These interpolators determine
/// if the node needs an update for the current frame.
///
class AnimatorNode: public KeypathSearchable {
public:
    AnimatorNode(std::shared_ptr<AnimatorNode> const &parentNode) :
    _parentNode(parentNode) {
    }
    
    AnimatorNode(const AnimatorNode&) = delete;
    AnimatorNode& operator=(AnimatorNode&) = delete;
    
    /// The available properties of the Node.
    ///
    /// These properties are automatically updated each frame.
    /// These properties are also settable and gettable through the dynamic
    /// property system.
    ///
    virtual std::shared_ptr<KeypathSearchableNodePropertyMap> propertyMap() const = 0;
    
    /// The upstream input node
    std::shared_ptr<AnimatorNode> parentNode() {
        return _parentNode;
    }
    void setParentNode(std::shared_ptr<AnimatorNode> const &parentNode) {
        _parentNode = parentNode;
    }
    
    /// The output of the node.
    virtual std::shared_ptr<NodeOutput> outputNode() = 0;
    
    /// Update the outputs of the node. Called if local contents were update or if outputsNeedUpdate returns true.
    virtual void rebuildOutputs(double frame) = 0;
    
    /// Setters for marking current node state.
    bool isEnabled() {
        return _isEnabled;
    }
    virtual void setIsEnabled(bool isEnabled) {
        _isEnabled = isEnabled;
    }
    
    bool hasLocalUpdates() {
        return _hasLocalUpdates;
    }
    virtual void setHasLocalUpdates(bool hasLocalUpdates) {
        _hasLocalUpdates = hasLocalUpdates;
    }
    
    bool hasUpstreamUpdates() {
        return _hasUpstreamUpdates;
    }
    virtual void setHasUpstreamUpdates(bool hasUpstreamUpdates) {
        _hasUpstreamUpdates = hasUpstreamUpdates;
    }
    
    std::optional<double> lastUpdateFrame() {
        return _lastUpdateFrame;
    }
    virtual void setLastUpdateFrame(std::optional<double> lastUpdateFrame) {
        _lastUpdateFrame = lastUpdateFrame;
    }
    
    /// Marks if updates to this node affect nodes downstream.
    virtual bool localUpdatesPermeateDownstream() {
        /// Optional override
        return true;
    }
    virtual bool forceUpstreamOutputUpdates() {
        /// Optional
        return false;
    }
    
    /// Called at the end of this nodes update cycle. Always called. Optional.
    virtual bool performAdditionalLocalUpdates(double frame, bool forceLocalUpdate) {
        /// Optional
        return forceLocalUpdate;
    }
    virtual void performAdditionalOutputUpdates(double frame, bool forceOutputUpdate) {
        /// Optional
    }
    
    /// The default simply returns `hasLocalUpdates`
    virtual bool shouldRebuildOutputs(double frame) {
        return hasLocalUpdates();
    }
    
    virtual bool updateOutputs(double frame, bool forceOutputUpdate) {
        if (!isEnabled()) {
            setLastUpdateFrame(frame);
            if (const auto parentNodeValue = parentNode()) {
                return parentNodeValue->updateOutputs(frame, forceOutputUpdate);
            } else {
                return false;
            }
        }
        
        if (!forceOutputUpdate && lastUpdateFrame().has_value() && lastUpdateFrame().value() == frame) {
            /// This node has already updated for this frame. Go ahead and return the results.
            return hasUpstreamUpdates() || hasLocalUpdates();
        }
        
        /// Ask if this node should force output updates upstream.
        bool forceUpstreamUpdates = forceOutputUpdate || forceUpstreamOutputUpdates();

        /// Perform upstream output updates. Optionally mark upstream updates if any.
        if (const auto parentNodeValue = parentNode()) {
            setHasUpstreamUpdates(parentNodeValue->updateOutputs(frame, forceUpstreamUpdates) || hasUpstreamUpdates());
        } else {
            setHasUpstreamUpdates(hasUpstreamUpdates());
        }

        /// Perform additional local output updates
        performAdditionalOutputUpdates(frame, forceUpstreamUpdates);

        /// If there are local updates, or if updates have been force, rebuild outputs
        if (forceUpstreamUpdates || shouldRebuildOutputs(frame)) {
            setLastUpdateFrame(frame);
            rebuildOutputs(frame);
        }
        return hasUpstreamUpdates() || hasLocalUpdates();
    }
    
    /// Rebuilds the content of this node, and upstream nodes if necessary.
    virtual bool updateContents(double frame, bool forceLocalUpdate) {
        if (!isEnabled()) {
            // Disabled node, pass through.
            if (const auto parentNodeValue = parentNode()) {
                return parentNodeValue->updateContents(frame, forceLocalUpdate);
            } else {
                return false;
            }
        }

        if (forceLocalUpdate == false && lastUpdateFrame().has_value() && lastUpdateFrame().value() == frame) {
            /// This node has already updated for this frame. Go ahead and return the results.
            return localUpdatesPermeateDownstream() ? hasUpstreamUpdates() || hasLocalUpdates() : hasUpstreamUpdates();
        }

        /// Are there local updates? If so mark the node.
        setHasLocalUpdates(forceLocalUpdate ? forceLocalUpdate : propertyMap()->needsLocalUpdate(frame));

        /// Were there upstream updates? If so mark the node
        if (const auto parentNodeValue = parentNode()) {
            setHasUpstreamUpdates(parentNodeValue->updateContents(frame, forceLocalUpdate));
        } else {
            setHasUpstreamUpdates(false);
        }

        /// Perform property updates if necessary.
        if (hasLocalUpdates()) {
            /// Rebuild local properties
            propertyMap()->updateNodeProperties(frame);
        }

        /// Ask the node to perform any other updates it might have.
        setHasUpstreamUpdates(performAdditionalLocalUpdates(frame, forceLocalUpdate) || hasUpstreamUpdates());

        /// If the node can update nodes downstream, notify them, otherwise pass on any upstream updates downstream.
        return localUpdatesPermeateDownstream() ? hasUpstreamUpdates() || hasLocalUpdates() : hasUpstreamUpdates();
    }
    
    virtual void updateTree(double frame, bool forceUpdates) {
        updateContents(frame, forceUpdates);
        updateOutputs(frame, forceUpdates);
    }
    
    /// The name of the Keypath
    virtual std::string keypathName() const override {
        return propertyMap()->keypathName();
    }
    
    /// A list of properties belonging to the keypath.
    virtual std::map<std::string, std::shared_ptr<AnyNodeProperty>> keypathProperties() const override {
        return propertyMap()->keypathProperties();
    }
    
    /// Children Keypaths
    virtual std::vector<std::shared_ptr<KeypathSearchable>> const &childKeypaths() const override {
        return propertyMap()->childKeypaths();
    }
    
    virtual std::shared_ptr<CALayer> keypathLayer() const override {
        return nullptr;
    }
    
public:
    virtual LayerTransformNode *asLayerTransformNode() {
        return nullptr;
    }
    
    virtual PathNode *asPathNode() {
        return nullptr;
    }
    
    virtual RenderNode *asRenderNode() {
        return nullptr;
    }
    
private:
    std::shared_ptr<AnimatorNode> _parentNode;
    bool _isEnabled = true;
    bool _hasLocalUpdates = false;
    bool _hasUpstreamUpdates = false;
    std::optional<double> _lastUpdateFrame;
};

}

#endif /* AnimatorNode_hpp */
