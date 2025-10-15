#ifndef RenderTree_hpp
#define RenderTree_hpp

#include <memory>

#include "Lottie/Public/Primitives/Vectors.hpp"
#include "Lottie/Public/Primitives/CALayer.hpp"

namespace lottie {

struct BoundingBoxNode {
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
        
        bool operator==(LayerParams const &rhs) const {
            if (_bounds != rhs._bounds) {
                return false;
            }
            if (_position != rhs._position) {
                return false;
            }
            if (_transform != rhs._transform) {
                return false;
            }
            if (_opacity != rhs._opacity) {
                return false;
            }
            if (_masksToBounds != rhs._masksToBounds) {
                return false;
            }
            if (_isHidden != rhs._isHidden) {
                return false;
            }
            return true;
        }
        
        bool operator!=(LayerParams const &rhs) const {
            return !(*this == rhs);
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
    std::shared_ptr<RenderableItem> renderableItem;
    bool isInvertedMatte;
    std::vector<std::shared_ptr<BoundingBoxNode>> subnodes;
    std::shared_ptr<BoundingBoxNode> mask;
    
    explicit BoundingBoxNode(
        LayerParams const &layer_,
        CGRect const &globalRect_,
        CGRect const &localRect_,
        CATransform3D const &globalTransform_,
        bool drawsContent_,
        std::shared_ptr<RenderableItem> renderableItem_,
        bool isInvertedMatte_,
        std::vector<std::shared_ptr<BoundingBoxNode>> const &subnodes_,
        std::shared_ptr<BoundingBoxNode> const &mask_
    );
    
    bool operator==(BoundingBoxNode const &rhs) const {
        if (layer != rhs.layer) {
            return false;
        }
        if (globalRect != rhs.globalRect) {
            return false;
        }
        if (localRect != rhs.localRect) {
            return false;
        }
        if (globalTransform != rhs.globalTransform) {
            return false;
        }
        if (drawsContent != rhs.drawsContent) {
            return false;
        }
        if ((renderableItem == nullptr) != (rhs.renderableItem == nullptr)) {
            return false;
        } else if (renderableItem) {
            if (!renderableItem->isEqual(rhs.renderableItem)) {
                return false;
            }
        }
        if (isInvertedMatte != rhs.isInvertedMatte) {
            return false;
        }
        if (subnodes.size() != rhs.subnodes.size()) {
            return false;
        } else {
            for (size_t i = 0; i < subnodes.size(); i++) {
                if ((*subnodes[i].get()) != (*rhs.subnodes[i].get())) {
                    return false;
                }
            }
        }
        if ((mask == nullptr) != (rhs.mask == nullptr)) {
            return false;
        } else if (mask) {
            if ((*mask.get()) != *(rhs.mask.get())) {
                return false;
            }
        }
        return true;
    }
    
    bool operator!=(BoundingBoxNode const &rhs) const {
        return !(*this == rhs);
    }
};

std::shared_ptr<BoundingBoxNode> boundingBoxTree(std::shared_ptr<CALayer> const &layer, Vector2D const &globalSize, CATransform3D const &parentTransform);

}

#endif /* RenderTree_hpp */
