#ifndef CompositionLayersInitializer_hpp
#define CompositionLayersInitializer_hpp

#include "Lottie/Private/MainThread/LayerContainers/CompLayers/CompositionLayer.hpp"
#include "Lottie/Private/Model/Assets/AssetLibrary.hpp"
#include "Lottie/Private/MainThread/LayerContainers/Utility/LayerImageProvider.hpp"
#include "Lottie/Public/TextProvider/AnimationTextProvider.hpp"
#include "Lottie/Public/FontProvider/AnimationFontProvider.hpp"

namespace lottie {

std::vector<std::shared_ptr<CompositionLayer>> initializeCompositionLayers(
    std::vector<std::shared_ptr<LayerModel>> const &layers,
    std::shared_ptr<AssetLibrary> const &assetLibrary,
    std::shared_ptr<LayerImageProvider> const &layerImageProvider,
    std::shared_ptr<AnimationTextProvider> const &textProvider,
    std::shared_ptr<AnimationFontProvider> const &fontProvider,
    double frameRate
);

}

#endif /* CompositionLayersInitializer_hpp */
