#ifndef RenderNode_hpp
#define RenderNode_hpp

#include "Lottie/Public/Primitives/CALayer.hpp"
#include "Lottie/Private/MainThread/NodeRenderSystem/Protocols/AnimatorNode.hpp"
#include "Lottie/Private/MainThread/NodeRenderSystem/Protocols/NodeOutput.hpp"
#include "Lottie/Private/MainThread/NodeRenderSystem/NodeProperties/Protocols/HasRenderUpdates.hpp"
#include "Lottie/Private/MainThread/NodeRenderSystem/NodeProperties/Protocols/HasUpdate.hpp"

namespace lottie {

class StrokeRenderer;
class FillRenderer;
class GradientStrokeRenderer;
class GradientFillRenderer;

/// A protocol that defines anything with render instructions
class Renderable: virtual public HasRenderUpdates, virtual public HasUpdate {
public:
    enum RenderableType {
        Fill,
        Stroke,
        GradientFill,
        GradientStroke
    };
    
public:
    /// Determines if the renderer requires a custom context for drawing.
    /// If yes the shape layer will perform a custom drawing pass.
    /// If no the shape layer will be a standard CAShapeLayer
    virtual bool shouldRenderInContext() = 0;
    
    /// Passes in the CAShapeLayer to update
    virtual void updateShapeLayer(std::shared_ptr<CAShapeLayer> const &layer) = 0;
    
    /// Asks the renderer what the renderable bounds is for the given box.
    virtual CGRect renderBoundsFor(CGRect const &boundingBox) {
        /// Optional
        return boundingBox;
    }
    
    /// Opportunity for renderers to inject sublayers
    virtual void setupSublayers(std::shared_ptr<CAShapeLayer> const &layer) = 0;
    
    virtual RenderableType renderableType() const = 0;
    
    virtual StrokeRenderer *asStrokeRenderer() {
        return nullptr;
    }
    
    virtual FillRenderer *asFillRenderer() {
        return nullptr;
    }
    
    virtual GradientStrokeRenderer *asGradientStrokeRenderer() {
        return nullptr;
    }
    
    virtual GradientFillRenderer *asGradientFillRenderer() {
        return nullptr;
    }
};
    
/// A protocol that defines a node that holds render instructions
class RenderNode {
public:
    virtual std::shared_ptr<Renderable> renderer() = 0;
    virtual std::shared_ptr<NodeOutput> nodeOutput() = 0;
};

}

#endif /* RenderNode_hpp */
