#include "RenderNode.hpp"

namespace lottie {

OutputRenderNode::OutputRenderNode(
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
) :
layer(layer_),
globalRect(globalRect_),
localRect(localRect_),
globalTransform(globalTransform_),
drawsContent(drawsContent_),
renderContent(renderContent_),
drawContentDescendants(drawContentDescendants_),
isInvertedMatte(isInvertedMatte_),
subnodes(subnodes_),
mask(mask_) {
}

}
