#include "RenderTree.hpp"

namespace lottie {

BoundingBoxNode::BoundingBoxNode(
    LayerParams const &layer_,
    CGRect const &globalRect_,
    CGRect const &localRect_,
    CATransform3D const &globalTransform_,
    bool drawsContent_,
    std::shared_ptr<RenderableItem> renderableItem_,
    bool isInvertedMatte_,
    std::vector<std::shared_ptr<BoundingBoxNode>> const &subnodes_,
    std::shared_ptr<BoundingBoxNode> const &mask_
) :
layer(layer_),
globalRect(globalRect_),
localRect(localRect_),
globalTransform(globalTransform_),
drawsContent(drawsContent_),
renderableItem(renderableItem_),
isInvertedMatte(isInvertedMatte_),
subnodes(subnodes_),
mask(mask_) {
}

std::shared_ptr<BoundingBoxNode> boundingBoxTree(std::shared_ptr<CALayer> const &layer, Vector2D const &globalSize, CATransform3D const &parentTransform) {
    if (layer->isHidden() || layer->opacity() == 0.0f) {
        return nullptr;
    }
    
    if (layer->masksToBounds()) {
        if (layer->bounds().empty()) {
            return nullptr;
        }
    }
    
    auto currentTransform = parentTransform;
    
    currentTransform = currentTransform.translated(Vector2D(layer->position().x, layer->position().y));
    currentTransform = currentTransform.translated(Vector2D(-layer->bounds().x, -layer->bounds().y));
    currentTransform = layer->transform() * currentTransform;
    
    if (!currentTransform.isInvertible()) {
        return nullptr;
    }
    
    std::optional<CGRect> effectiveLocalBounds;
    
    auto renderableItem = layer->renderableItem();
    if (renderableItem) {
        effectiveLocalBounds = renderableItem->boundingRect();
    } else if (layer->implementsDraw()) {
        effectiveLocalBounds = layer->bounds();
    }
    
    bool isInvertedMatte = layer->isInvertedMatte();
    if (isInvertedMatte) {
        effectiveLocalBounds = layer->bounds();
    }
    
    if (effectiveLocalBounds && effectiveLocalBounds->empty()) {
        effectiveLocalBounds = std::nullopt;
    }
    
    std::vector<std::shared_ptr<BoundingBoxNode>> subnodes;
    std::optional<CGRect> subnodesGlobalRect;
    
    for (const auto &sublayer : layer->sublayers()) {
        if (const auto subnode = boundingBoxTree(sublayer, globalSize, currentTransform)) {
            subnodes.push_back(subnode);
            
            if (subnodesGlobalRect) {
                subnodesGlobalRect = subnodesGlobalRect->unionWith(subnode->globalRect);
            } else {
                subnodesGlobalRect = subnode->globalRect;
            }
        }
    }
    
    std::optional<CGRect> fuzzyGlobalRect;
    
    if (effectiveLocalBounds) {
        CGRect effectiveGlobalBounds = effectiveLocalBounds->applyingTransform(currentTransform);
        if (fuzzyGlobalRect) {
            fuzzyGlobalRect = fuzzyGlobalRect->unionWith(effectiveGlobalBounds);
        } else {
            fuzzyGlobalRect = effectiveGlobalBounds;
        }
    }
    
    if (subnodesGlobalRect) {
        if (fuzzyGlobalRect) {
            fuzzyGlobalRect = fuzzyGlobalRect->unionWith(subnodesGlobalRect.value());
        } else {
            fuzzyGlobalRect = subnodesGlobalRect;
        }
    }
    
    if (!fuzzyGlobalRect) {
        return nullptr;
    }
    
    CGRect globalRect(
                      std::floor(fuzzyGlobalRect->x),
                      std::floor(fuzzyGlobalRect->y),
                      std::ceil(fuzzyGlobalRect->width + fuzzyGlobalRect->x - floor(fuzzyGlobalRect->x)),
                      std::ceil(fuzzyGlobalRect->height + fuzzyGlobalRect->y - floor(fuzzyGlobalRect->y))
                      );
    
    if (!CGRect(0.0, 0.0, globalSize.x, globalSize.y).intersects(globalRect)) {
        return nullptr;
    }
    
    std::shared_ptr<BoundingBoxNode> maskNode;
    if (layer->mask()) {
        if (const auto maskNodeValue = boundingBoxTree(layer->mask(), globalSize, currentTransform)) {
            if (!maskNodeValue->globalRect.intersects(globalRect)) {
                return nullptr;
            }
            maskNode = maskNodeValue;
        } else {
            return nullptr;
        }
    }
    
    return std::make_shared<BoundingBoxNode>(
        layer,
        globalRect,
        CGRect(0.0, 0.0, 0.0, 0.0),
        currentTransform,
        effectiveLocalBounds.has_value(),
        renderableItem,
        isInvertedMatte,
        subnodes,
        maskNode
    );
}

}
