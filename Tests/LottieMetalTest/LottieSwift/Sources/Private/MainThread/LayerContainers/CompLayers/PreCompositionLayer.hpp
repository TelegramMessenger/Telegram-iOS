#ifndef PreCompositionLayer_hpp
#define PreCompositionLayer_hpp

#include "Lottie/Private/MainThread/LayerContainers/CompLayers/CompositionLayer.hpp"
#include "Lottie/Private/Model/Layers/PreCompLayerModel.hpp"
#include "Lottie/Private/Model/Assets/PrecompAsset.hpp"
#include "Lottie/Private/MainThread/LayerContainers/Utility/LayerImageProvider.hpp"
#include "Lottie/Public/TextProvider/AnimationTextProvider.hpp"
#include "Lottie/Public/FontProvider/AnimationFontProvider.hpp"
#include "Lottie/Private/Model/Assets/AssetLibrary.hpp"
#include "Lottie/Private/MainThread/NodeRenderSystem/NodeProperties/NodeProperty.hpp"
#include "Lottie/Private/MainThread/NodeRenderSystem/NodeProperties/ValueProviders/KeyframeInterpolator.hpp"
#include "Lottie/Private/MainThread/LayerContainers/Utility/CompositionLayersInitializer.hpp"

namespace lottie {

class PreCompositionLayer: public CompositionLayer {
public:
    PreCompositionLayer(
        std::shared_ptr<PreCompLayerModel> const &precomp,
        PrecompAsset const &asset,
        std::shared_ptr<LayerImageProvider> const &layerImageProvider,
        std::shared_ptr<AnimationTextProvider> const &textProvider,
        std::shared_ptr<AnimationFontProvider> const &fontProvider,
        std::shared_ptr<AssetLibrary> const &assetLibrary,
        double frameRate
    ) : CompositionLayer(precomp, Vector2D(precomp->width, precomp->height)) {
        if (precomp->timeRemapping) {
            _remappingNode = std::make_shared<NodeProperty<Vector1D>>(std::make_shared<KeyframeInterpolator<Vector1D>>(precomp->timeRemapping->keyframes));
        }
        _frameRate = frameRate;
        
        setBounds(CGRect(0.0, 0.0, precomp->width, precomp->height));
        contentsLayer()->setMasksToBounds(true);
        contentsLayer()->setBounds(bounds());
        
        auto layers = initializeCompositionLayers(
            asset.layers,
            assetLibrary,
            layerImageProvider,
            textProvider,
            fontProvider,
            frameRate
        );
        
        std::vector<std::shared_ptr<ImageCompositionLayer>> imageLayers;
        
        std::shared_ptr<CompositionLayer> mattedLayer;
        
        for (auto layerIt = layers.rbegin(); layerIt != layers.rend(); layerIt++) {
            std::shared_ptr<CompositionLayer> layer = *layerIt;
            layer->setBounds(bounds());
            _animationLayers.push_back(layer);
            
            if (layer->isImageCompositionLayer()) {
                imageLayers.push_back(std::static_pointer_cast<ImageCompositionLayer>(layer));
            }
            if (mattedLayer) {
                /// The previous layer requires this layer to be its matte
                mattedLayer->setMatteLayer(layer);
                mattedLayer = nullptr;
                continue;
            }
            if (layer->matteType().has_value() && (layer->matteType().value() == MatteType::Add || layer->matteType().value() == MatteType::Invert)) {
                /// We have a layer that requires a matte.
                mattedLayer = layer;
            }
            contentsLayer()->addSublayer(layer);
        }
        
        for (const auto &layer : layers) {
            _childKeypaths.push_back(layer);
        }
        
        layerImageProvider->addImageLayers(imageLayers);
    }
    
    virtual std::map<std::string, std::shared_ptr<AnyNodeProperty>> keypathProperties() const override {
        if (!_remappingNode) {
            return {};
        }
        
        std::map<std::string, std::shared_ptr<AnyNodeProperty>> result;
        result.insert(std::make_pair("Time Remap", _remappingNode));
        
        return result;
    }
    
    virtual void displayContentsWithFrame(double frame, bool forceUpdates) override {
        double localFrame = 0.0;
        if (_remappingNode) {
            _remappingNode->update(frame);
            localFrame = _remappingNode->value().value * _frameRate;
        } else {
            localFrame = (frame - startFrame()) / timeStretch();
        }
        
        for (const auto &animationLayer : _animationLayers) {
            animationLayer->displayWithFrame(localFrame, forceUpdates);
        }
    }
    
    virtual std::shared_ptr<RenderTreeNode> renderTreeNode() override {
        if (_contentsLayer->isHidden()) {
            return nullptr;
        }
        
        std::shared_ptr<RenderTreeNode> maskNode;
        bool invertMask = false;
        if (_matteLayer) {
            maskNode = _matteLayer->renderTreeNode();
            if (maskNode && _matteType.has_value() && _matteType.value() == MatteType::Invert) {
                invertMask = true;
            }
        }
        
        std::vector<std::shared_ptr<RenderTreeNode>> renderTreeValue;
        auto renderTreeContentItem = renderTree();
        if (renderTreeContentItem) {
            renderTreeValue.push_back(renderTreeContentItem);
        }
        
        std::vector<std::shared_ptr<RenderTreeNode>> subnodes;
        subnodes.push_back(std::make_shared<RenderTreeNode>(
            _contentsLayer->bounds(),
            _contentsLayer->position(),
            _contentsLayer->transform(),
            _contentsLayer->opacity(),
            _contentsLayer->masksToBounds(),
            _contentsLayer->isHidden(),
            nullptr,
            renderTreeValue,
            nullptr,
            false
        ));
        
        assert(opacity() == 1.0);
        assert(!isHidden());
        assert(!masksToBounds());
        assert(transform().isIdentity());
        assert(position() == Vector2D::Zero());
        
        return std::make_shared<RenderTreeNode>(
            bounds(),
            position(),
            transform(),
            opacity(),
            masksToBounds(),
            isHidden(),
            nullptr,
            subnodes,
            maskNode,
            invertMask
        );
    }
    
    std::shared_ptr<RenderTreeNode> renderTree() {
        std::vector<std::shared_ptr<RenderTreeNode>> result;
        
        for (const auto &animationLayer : _animationLayers) {
            bool found = false;
            for (const auto &sublayer : contentsLayer()->sublayers()) {
                if (animationLayer == sublayer) {
                    found = true;
                    break;
                }
            }
            if (found) {
                auto node = animationLayer->renderTreeNode();
                if (node) {
                    result.push_back(node);
                }
            }
        }
        
        std::vector<std::shared_ptr<RenderTreeNode>> subnodes;
        return std::make_shared<RenderTreeNode>(
            CGRect(0.0, 0.0, 0.0, 0.0),
            Vector2D(0.0, 0.0),
            CATransform3D::identity(),
            1.0,
            false,
            false,
            nullptr,
            result,
            nullptr,
            false
        );
    }
    
private:
    double _frameRate = 0.0;
    std::shared_ptr<NodeProperty<Vector1D>> _remappingNode;
    
    std::vector<std::shared_ptr<CompositionLayer>> _animationLayers;
};

}

#endif /* PreCompositionLayer_hpp */
