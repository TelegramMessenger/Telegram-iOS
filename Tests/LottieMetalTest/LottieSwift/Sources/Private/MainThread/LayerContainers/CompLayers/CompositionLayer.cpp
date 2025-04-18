#include "CompositionLayer.hpp"

#include "Lottie/Public/Primitives/RenderTree.hpp"

namespace lottie {

InvertedMatteLayer::InvertedMatteLayer(std::shared_ptr<CompositionLayer> inputMatte) :
_inputMatte(inputMatte) {
    setBounds(inputMatte->bounds());
    setNeedsDisplay(true);
    
    addSublayer(_inputMatte);
}

void InvertedMatteLayer::setup() {
    _inputMatte->setLayerDelegate(shared_from_base<InvertedMatteLayer>());
}

void InvertedMatteLayer::frameUpdated(double frame) {
    setNeedsDisplay(true);
}

std::shared_ptr<InvertedMatteLayer> makeInvertedMatteLayer(std::shared_ptr<CompositionLayer> compositionLayer) {
    auto result = std::make_shared<InvertedMatteLayer>(compositionLayer);
    result->setup();
    return result;
}

}
