#ifndef LayerFontProvider_hpp
#define LayerFontProvider_hpp

#include "Lottie/Public/FontProvider/AnimationFontProvider.hpp"
#include "Lottie/Private/MainThread/LayerContainers/CompLayers/TextCompositionLayer.hpp"

namespace lottie {

/// Connects a LottieFontProvider to a group of text layers
class LayerFontProvider {
public:
    LayerFontProvider(std::shared_ptr<AnimationFontProvider> const &fontProvider) {
        _fontProvider = fontProvider;
        reloadTexts();
    }
    
    std::shared_ptr<AnimationFontProvider> const &fontProvider() const {
        return _fontProvider;
    }
    void setFontProvider(std::shared_ptr<AnimationFontProvider> const &fontProvider) {
        _fontProvider = fontProvider;
        reloadTexts();
    }
    
    void addTextLayers(std::vector<std::shared_ptr<TextCompositionLayer>> const &layers) {
        for (const auto &layer : layers) {
            _textLayers.push_back(layer);
        }
    }
    
    void reloadTexts() {
        for (const auto &layer : _textLayers) {
            layer->setFontProvider(_fontProvider);
        }
    }
    
private:
    std::vector<std::shared_ptr<TextCompositionLayer>> _textLayers;
    
    std::shared_ptr<AnimationFontProvider> _fontProvider;
};

}

#endif /* LayerFontProvider_hpp */
