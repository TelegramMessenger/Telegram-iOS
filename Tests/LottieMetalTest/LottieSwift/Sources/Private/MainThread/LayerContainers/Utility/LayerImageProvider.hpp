#ifndef LayerImageProvider_hpp
#define LayerImageProvider_hpp

#include "Lottie/Public/ImageProvider/AnimationImageProvider.hpp"
#include "Lottie/Private/Model/Assets/ImageAsset.hpp"
#include "Lottie/Private/MainThread/LayerContainers/CompLayers/ImageCompositionLayer.hpp"

namespace lottie {

/// Connects a LottieImageProvider to a group of image layers
class LayerImageProvider {
public:
    LayerImageProvider(std::shared_ptr<AnimationImageProvider> const &imageProvider, std::map<std::string, std::shared_ptr<ImageAsset>> const &assets) :
    _imageProvider(imageProvider),
    _imageAssets(assets) {
        reloadImages();
    }
    
    std::shared_ptr<AnimationImageProvider> imageProvider() const {
        return _imageProvider;
    }
    void setImageProvider(std::shared_ptr<AnimationImageProvider> const &imageProvider) {
        _imageProvider = imageProvider;
        reloadImages();
    }
    
    std::vector<std::shared_ptr<ImageCompositionLayer>> const &imageLayers() const {
        return _imageLayers;
    }
    
    void addImageLayers(std::vector<std::shared_ptr<ImageCompositionLayer>> const &layers) {
        for (const auto &layer : layers) {
            auto it = _imageAssets.find(layer->imageReferenceID());
            if (it != _imageAssets.end()) {
                _imageLayers.push_back(layer);
            }
        }
    }
    
    void reloadImages() {
        for (const auto &imageLayer : imageLayers()) {
            auto it = _imageAssets.find(imageLayer->imageReferenceID());
            if (it != _imageAssets.end()) {
                imageLayer->setImage(_imageProvider->imageForAsset(*it->second));
            }
        }
    }
    
private:
    std::shared_ptr<AnimationImageProvider> _imageProvider;
    std::vector<std::shared_ptr<ImageCompositionLayer>> _imageLayers;
    
    std::map<std::string, std::shared_ptr<ImageAsset>> _imageAssets;
};

}

#endif /* LayerImageProvider_hpp */
