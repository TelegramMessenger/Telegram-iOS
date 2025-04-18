#ifndef NullCompositionLayer_hpp
#define NullCompositionLayer_hpp

#include "Lottie/Private/MainThread/LayerContainers/CompLayers/CompositionLayer.hpp"

namespace lottie {

class NullCompositionLayer: public CompositionLayer {
public:
    NullCompositionLayer(std::shared_ptr<LayerModel> const &layer) :
    CompositionLayer(layer, Vector2D::Zero()) {
    }
};

}

#endif /* NullCompositionLayer_hpp */
