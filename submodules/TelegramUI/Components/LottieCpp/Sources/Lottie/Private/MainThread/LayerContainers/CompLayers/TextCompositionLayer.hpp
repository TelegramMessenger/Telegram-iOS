#ifndef TextCompositionLayer_hpp
#define TextCompositionLayer_hpp

#include "Lottie/Private/MainThread/LayerContainers/CompLayers/CompositionLayer.hpp"
#include "Lottie/Private/Model/Layers/TextLayerModel.hpp"
#include "Lottie/Public/TextProvider/AnimationTextProvider.hpp"
#include "Lottie/Public/FontProvider/AnimationFontProvider.hpp"
#include "Lottie/Private/MainThread/NodeRenderSystem/Nodes/Text/TextAnimatorNode.hpp"

namespace lottie {

class TextCompositionLayer: public CompositionLayer {
public:
    TextCompositionLayer(std::shared_ptr<TextLayerModel> const &textLayer, std::shared_ptr<AnimationTextProvider> textProvider, std::shared_ptr<AnimationFontProvider> fontProvider) :
    CompositionLayer(textLayer, Vector2D::Zero()) {
        std::shared_ptr<TextAnimatorNode> rootNode;
        for (const auto &animator : textLayer->animators) {
            rootNode = std::make_shared<TextAnimatorNode>(rootNode, animator);
        }
        _rootNode = rootNode;
        _textDocument = std::make_shared<KeyframeInterpolator<TextDocument>>(textLayer->text.keyframes);
        
        _textProvider = textProvider;
        _fontProvider = fontProvider;
        
        if (_rootNode) {
            _childKeypaths.push_back(rootNode);
        }
    }
    
    std::shared_ptr<AnimationTextProvider> const &textProvider() const {
        return _textProvider;
    }
    void setTextProvider(std::shared_ptr<AnimationTextProvider> const &textProvider) {
        _textProvider = textProvider;
    }
    
    std::shared_ptr<AnimationFontProvider> const &fontProvider() const {
        return _fontProvider;
    }
    void setFontProvider(std::shared_ptr<AnimationFontProvider> const &fontProvider) {
        _fontProvider = fontProvider;
    }
    
    virtual void displayContentsWithFrame(float frame, bool forceUpdates, BezierPathsBoundingBoxContext &boundingBoxContext) override {
        if (!_textDocument) {
            return;
        }
        
        bool documentUpdate = _textDocument->hasUpdate(frame);
        
        bool animatorUpdate = false;
        if (_rootNode) {
            animatorUpdate = _rootNode->updateContents(frame, forceUpdates);
        }
        
        if (!(documentUpdate || animatorUpdate)) {
            return;
        }
        
        if (_rootNode) {
            _rootNode->rebuildOutputs(frame);
        }
    }
    
public:
    virtual bool isTextCompositionLayer() const override {
        return true;
    }
    
private:
    std::shared_ptr<TextAnimatorNode> _rootNode;
    std::shared_ptr<KeyframeInterpolator<TextDocument>> _textDocument;
    
    std::shared_ptr<AnimationTextProvider> _textProvider;
    std::shared_ptr<AnimationFontProvider> _fontProvider;
};

}

#endif /* TextCompositionLayer_hpp */
