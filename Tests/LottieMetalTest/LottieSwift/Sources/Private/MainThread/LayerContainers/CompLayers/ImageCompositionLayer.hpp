#ifndef ImageCompositionLayer_hpp
#define ImageCompositionLayer_hpp

#include "Lottie/Private/MainThread/LayerContainers/CompLayers/CompositionLayer.hpp"
#include "Lottie/Private/Model/Layers/ImageLayerModel.hpp"

namespace lottie {

class ImageCompositionLayer: public CompositionLayer {
public:
    ImageCompositionLayer(std::shared_ptr<ImageLayerModel> const &imageLayer, Vector2D const &size) :
    CompositionLayer(imageLayer, size) {
        _imageReferenceID = imageLayer->referenceID;
        
        contentsLayer()->setMasksToBounds(true);
    }
    
    std::shared_ptr<CGImage> image() {
        return _image;
    }
    void setImage(std::shared_ptr<CGImage> image) {
        _image = image;
        contentsLayer()->setContents(image);
    }
    
    std::string const &imageReferenceID() {
        return _imageReferenceID;
    }
    
public:
    virtual bool isImageCompositionLayer() const override {
        return true;
    }
    
private:
    std::string _imageReferenceID;
    std::shared_ptr<CGImage> _image;
};

}

#endif /* ImageCompositionLayer_hpp */
