#ifndef ShapeCompositionLayer_hpp
#define ShapeCompositionLayer_hpp

#include "Lottie/Private/MainThread/LayerContainers/CompLayers/CompositionLayer.hpp"
#include "Lottie/Private/Model/Layers/ShapeLayerModel.hpp"
#include "Lottie/Private/Model/Layers/SolidLayerModel.hpp"
#include "Lottie/Private/MainThread/NodeRenderSystem/Protocols/AnimatorNode.hpp"

namespace lottie {

class ShapeLayerPresentationTree;

/// A CompositionLayer responsible for initializing and rendering shapes
class ShapeCompositionLayer: public CompositionLayer {
public:
    ShapeCompositionLayer(std::shared_ptr<ShapeLayerModel> const &shapeLayer);
    ShapeCompositionLayer(std::shared_ptr<SolidLayerModel> const &solidLayer);
    
    virtual void displayContentsWithFrame(float frame, bool forceUpdates, BezierPathsBoundingBoxContext &boundingBoxContext) override;
    virtual std::shared_ptr<RenderTreeNode> renderTreeNode(BezierPathsBoundingBoxContext &boundingBoxContext) override;
    void initializeContentsLayerParameters();
    virtual void updateContentsLayerParameters() override;
    
private:
    std::shared_ptr<ShapeLayerPresentationTree> _contentTree;
    
    AnimationFrameTime _frameTime = 0.0;
    bool _frameTimeInitialized = false;
    
    std::shared_ptr<RenderTreeNode> _renderTreeNode;
    std::shared_ptr<RenderTreeNode> _contentRenderTreeNode;
};

}

#endif /* ShapeCompositionLayer_hpp */
