#include "CompositionLayer.hpp"

namespace lottie {

InvertedMatteLayer::InvertedMatteLayer(std::shared_ptr<CompositionLayer> inputMatte) :
_inputMatte(inputMatte) {
    setSize(inputMatte->size());
    
    addSublayer(_inputMatte);
}

std::shared_ptr<InvertedMatteLayer> makeInvertedMatteLayer(std::shared_ptr<CompositionLayer> compositionLayer) {
    auto result = std::make_shared<InvertedMatteLayer>(compositionLayer);
    return result;
}

}
