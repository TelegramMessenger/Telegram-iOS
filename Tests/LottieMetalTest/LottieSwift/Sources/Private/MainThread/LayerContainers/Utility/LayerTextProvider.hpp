#ifndef LayerTextProvider_hpp
#define LayerTextProvider_hpp

#include "Lottie/Public/TextProvider/AnimationTextProvider.hpp"
#include "Lottie/Private/MainThread/LayerContainers/CompLayers/TextCompositionLayer.hpp"

namespace lottie {

/// Connects a LottieTextProvider to a group of text layers
class LayerTextProvider {
public:
    LayerTextProvider(std::shared_ptr<AnimationTextProvider> const &textProvider) {
        _textProvider = textProvider;
        reloadTexts();
    }
    
    std::shared_ptr<AnimationTextProvider> const &textProvider() const {
        return _textProvider;
    }
    void setTextProvider(std::shared_ptr<AnimationTextProvider> const &textProvider) {
        _textProvider = textProvider;
        reloadTexts();
    }
    
    void addTextLayers(std::vector<std::shared_ptr<TextCompositionLayer>> const &layers) {
        for (const auto &layer : layers) {
            _textLayers.push_back(layer);
        }
    }
    
    void reloadTexts() {
        for (const auto &layer : _textLayers) {
            layer->setTextProvider(_textProvider);
        }
    }
    
private:
    std::vector<std::shared_ptr<TextCompositionLayer>> _textLayers;
    
    std::shared_ptr<AnimationTextProvider> _textProvider;
};

}

#endif /* LayerTextProvider_hpp */
