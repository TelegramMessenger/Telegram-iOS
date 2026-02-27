#ifndef MainThreadAnimationLayer_hpp
#define MainThreadAnimationLayer_hpp

#include "Lottie/Public/Primitives/CALayer.hpp"
#include "Lottie/Public/ImageProvider/AnimationImageProvider.hpp"
#include "Lottie/Private/Model/Animation.hpp"
#include "Lottie/Public/TextProvider/AnimationTextProvider.hpp"
#include "Lottie/Public/FontProvider/AnimationFontProvider.hpp"
#include "Lottie/Private/MainThread/LayerContainers/Utility/LayerImageProvider.hpp"
#include "Lottie/Private/MainThread/LayerContainers/Utility/LayerTextProvider.hpp"
#include "Lottie/Private/MainThread/LayerContainers/Utility/CompositionLayersInitializer.hpp"
#include "Lottie/Private/MainThread/LayerContainers/Utility/LayerFontProvider.hpp"
#include "Lottie/Public/DynamicProperties/AnyValueProvider.hpp"
#include "Lottie/Public/DynamicProperties/AnimationKeypath.hpp"

namespace lottie {

class BlankImageProvider: public AnimationImageProvider {
public:
    std::shared_ptr<CGImage> imageForAsset(ImageAsset const &asset) {
        return nullptr;
    }
};

class MainThreadAnimationLayer: public CALayer {
public:
    MainThreadAnimationLayer(
        Animation const &animation,
        std::shared_ptr<AnimationImageProvider> const &imageProvider,
        std::shared_ptr<AnimationTextProvider> const &textProvider,
        std::shared_ptr<AnimationFontProvider> const &fontProvider
    ) {
        if (animation.assetLibrary) {
            _layerImageProvider = std::make_shared<LayerImageProvider>(imageProvider, animation.assetLibrary->imageAssets);
        } else {
            std::map<std::string, std::shared_ptr<ImageAsset>> imageAssets;
            _layerImageProvider = std::make_shared<LayerImageProvider>(imageProvider, imageAssets);
        }
        
        _layerTextProvider = std::make_shared<LayerTextProvider>(textProvider);
        _layerFontProvider = std::make_shared<LayerFontProvider>(fontProvider);
        
        setBounds(CGRect(0.0, 0.0, animation.width, animation.height));
        
        auto layers = initializeCompositionLayers(
            animation.layers,
            animation.assetLibrary,
            _layerImageProvider,
            textProvider,
            fontProvider,
            animation.framerate
        );
        
        std::vector<std::shared_ptr<ImageCompositionLayer>> imageLayers;
        std::vector<std::shared_ptr<TextCompositionLayer>> textLayers;
        
        std::shared_ptr<CompositionLayer> mattedLayer;
        
        for (auto layerIt = layers.rbegin(); layerIt != layers.rend(); layerIt++) {
            std::shared_ptr<CompositionLayer> const &layer = *layerIt;
            layer->setBounds(bounds());
            _animationLayers.push_back(layer);
            
            if (layer->isImageCompositionLayer()) {
                imageLayers.push_back(std::static_pointer_cast<ImageCompositionLayer>(layer));
            }
            if (layer->isTextCompositionLayer()) {
                textLayers.push_back(std::static_pointer_cast<TextCompositionLayer>(layer));
            }
            
            if (mattedLayer) {
                /// The previous layer requires this layer to be its matte
                mattedLayer->setMatteLayer(layer);
                mattedLayer = nullptr;
                continue;
            }
            if (layer->matteType().has_value() && (layer->matteType() == MatteType::Add || layer->matteType() == MatteType::Invert)) {
                /// We have a layer that requires a matte.
                mattedLayer = layer;
            }
            addSublayer(layer);
        }
        
        _layerImageProvider->addImageLayers(imageLayers);
        _layerImageProvider->reloadImages();
        _layerTextProvider->addTextLayers(textLayers);
        _layerTextProvider->reloadTexts();
        _layerFontProvider->addTextLayers(textLayers);
        _layerFontProvider->reloadTexts();
        
        setNeedsDisplay(true);
    }
    
    void setRespectAnimationFrameRate(bool respectAnimationFrameRate) {
        _respectAnimationFrameRate = respectAnimationFrameRate;
    }
    
    void display() {
        double newFrame = currentFrame();
        if (_respectAnimationFrameRate) {
            newFrame = floor(newFrame);
        }
        for (const auto &layer : _animationLayers) {
            layer->displayWithFrame(newFrame, false);
        }
    }
    
    std::vector<std::shared_ptr<CompositionLayer>> const &animationLayers() const {
        return _animationLayers;
    }
    
    void reloadImages() {
        _layerImageProvider->reloadImages();
    }
    
    /// Forces the view to update its drawing.
    void forceDisplayUpdate() {
        for (const auto &layer : _animationLayers) {
            layer->displayWithFrame(currentFrame(), true);
        }
    }
    
    void logHierarchyKeypaths() {
        printf("Lottie: Logging Animation Keypaths\n");
        assert(false);
        //animationLayers.forEach({ $0.logKeypaths(for: nil) })
    }
    
    void setValueProvider(std::shared_ptr<AnyValueProvider> const &valueProvider, AnimationKeypath const &keypath) {
        for (const auto &layer : _animationLayers) {
            assert(false);
            /*if let foundProperties = layer.nodeProperties(for: keypath) {
                for property in foundProperties {
                    property.setProvider(provider: valueProvider)
                }
                layer.displayWithFrame(frame: presentation()?.currentFrame ?? currentFrame, forceUpdates: true)
            }*/
        }
    }
    
    std::optional<AnyValue> getValue(AnimationKeypath const &keypath, std::optional<double> atFrame) {
        for (const auto &layer : _animationLayers) {
            assert(false);
            /*if
                let foundProperties = layer.nodeProperties(for: keypath),
                let first = foundProperties.first
            {
                return first.valueProvider.value(frame: atFrame ?? currentFrame)
            }*/
        }
        return std::nullopt;
    }
    
    std::optional<AnyValue> getOriginalValue(AnimationKeypath const &keypath, std::optional<double> atFrame) {
        for (const auto &layer : _animationLayers) {
            assert(false);
            /*if
                let foundProperties = layer.nodeProperties(for: keypath),
                let first = foundProperties.first
            {
                return first.originalValueProvider.value(frame: atFrame ?? currentFrame)
            }*/
        }
        return std::nullopt;
    }
    
    std::shared_ptr<CALayer> layerForKeypath(AnimationKeypath const &keyPath) {
        assert(false);
        /*for layer in animationLayers {
            if let foundLayer = layer.layer(for: keypath) {
                return foundLayer
            }
        }*/
        return nullptr;
    }
    
    std::vector<std::shared_ptr<AnimatorNode>> animatorNodesForKeypath(AnimationKeypath const &keypath) {
        std::vector<std::shared_ptr<AnimatorNode>> results;
        /*for (const auto &layer : _animationLayers) {
            if let nodes = layer.animatorNodes(for: keypath) {
                results.append(contentsOf: nodes)
            }
        }*/
        return results;
    }
    
    double currentFrame() const {
        return _currentFrame;
    }
    void setCurrentFrame(double currentFrame) {
        _currentFrame = currentFrame;
        
        for (size_t i = 0; i < _animationLayers.size(); i++) {
            _animationLayers[i]->displayWithFrame(_currentFrame, false);
        }
    }
    
    std::shared_ptr<AnimationImageProvider> imageProvider() const {
        return _layerImageProvider->imageProvider();
    }
    void setImageProvider(std::shared_ptr<AnimationImageProvider> const &imageProvider) {
        _layerImageProvider->setImageProvider(imageProvider);
    }
    
    std::shared_ptr<AnimationTextProvider> textProvider() const {
        return _layerTextProvider->textProvider();
    }
    void setTextProvider(std::shared_ptr<AnimationTextProvider> const &textProvider) {
        _layerTextProvider->setTextProvider(textProvider);
    }
    
    std::shared_ptr<AnimationFontProvider> fontProvider() const {
        return _layerFontProvider->fontProvider();
    }
    void setFontProvider(std::shared_ptr<AnimationFontProvider> const &fontProvider) {
        _layerFontProvider->setFontProvider(fontProvider);
    }
    
    virtual std::shared_ptr<RenderTreeNode> renderTreeNode() {
        std::vector<std::shared_ptr<RenderTreeNode>> subnodes;
        for (const auto &animationLayer : _animationLayers) {
            bool found = false;
            for (const auto &sublayer : sublayers()) {
                if (animationLayer == sublayer) {
                    found = true;
                    break;
                }
            }
            if (found) {
                auto node = animationLayer->renderTreeNode();
                if (node) {
                    subnodes.push_back(node);
                }
            }
        }
        
        return std::make_shared<RenderTreeNode>(
            bounds(),
            position(),
            CATransform3D::identity(),
            1.0,
            false,
            false,
            nullptr,
            subnodes,
            nullptr,
            false
        );
    }
    
private:
    // MARK: Internal
    
    /// The animatable Current Frame Property
    double _currentFrame = 0.0;
    
    std::shared_ptr<AnimationImageProvider> _imageProvider;
    std::shared_ptr<AnimationTextProvider> _textProvider;
    std::shared_ptr<AnimationFontProvider> _fontProvider;

    bool _respectAnimationFrameRate = true;
    
    std::vector<std::shared_ptr<CompositionLayer>> _animationLayers;
    
    std::shared_ptr<LayerImageProvider> _layerImageProvider;
    std::shared_ptr<LayerTextProvider> _layerTextProvider;
    std::shared_ptr<LayerFontProvider> _layerFontProvider;
};

}

#endif /* MainThreadAnimationLayer_hpp */
