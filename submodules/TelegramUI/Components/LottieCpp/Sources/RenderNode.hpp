#ifndef RenderNode_hpp
#define RenderNode_hpp

#include "Lottie/Public/Primitives/CALayer.hpp"

namespace lottie {

struct OutputRenderNode {
    struct LayerParams {
        CGRect _bounds;
        Vector2D _position;
        CATransform3D _transform;
        double _opacity;
        bool _masksToBounds;
        bool _isHidden;
        
        LayerParams(
            CGRect bounds_,
            Vector2D position_,
            CATransform3D transform_,
            double opacity_,
            bool masksToBounds_,
            bool isHidden_
        ) :
        _bounds(bounds_),
        _position(position_),
        _transform(transform_),
        _opacity(opacity_),
        _masksToBounds(masksToBounds_),
        _isHidden(isHidden_) {
        }
        
        LayerParams(std::shared_ptr<CALayer> const &layer) :
        _bounds(layer->bounds()),
        _position(layer->position()),
        _transform(layer->transform()),
        _opacity(layer->opacity()),
        _masksToBounds(layer->masksToBounds()),
        _isHidden(layer->isHidden()) {
        }
        
        CGRect bounds() const {
            return _bounds;
        }
        
        Vector2D position() const {
            return _position;
        }
        
        CATransform3D transform() const {
            return _transform;
        }
        
        double opacity() const {
            return _opacity;
        }
        
        bool masksToBounds() const {
            return _masksToBounds;
        }
        
        bool isHidden() const {
            return _isHidden;
        }
    };
    
    LayerParams layer;
    CGRect globalRect;
    CGRect localRect;
    CATransform3D globalTransform;
    bool drawsContent;
    std::shared_ptr<RenderTreeNodeContent> renderContent;
    int drawContentDescendants;
    bool isInvertedMatte;
    std::vector<std::shared_ptr<OutputRenderNode>> subnodes;
    std::shared_ptr<OutputRenderNode> mask;
    
    explicit OutputRenderNode(
        LayerParams const &layer_,
        CGRect const &globalRect_,
        CGRect const &localRect_,
        CATransform3D const &globalTransform_,
        bool drawsContent_,
        std::shared_ptr<RenderTreeNodeContent> renderContent_,
        int drawContentDescendants_,
        bool isInvertedMatte_,
        std::vector<std::shared_ptr<OutputRenderNode>> const &subnodes_,
        std::shared_ptr<OutputRenderNode> const &mask_
    );
};

}

#endif /* RenderNode_hpp */
