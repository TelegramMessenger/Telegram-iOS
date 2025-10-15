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
        
        //_contentsLayer->addSublayer(_textLayer);
        
        assert(false);
        //self.textLayer.masksToBounds = false
        //self.textLayer.isGeometryFlipped = true
        
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
    
    virtual void displayContentsWithFrame(double frame, bool forceUpdates) override {
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
        
        assert(false);
        /*// Get Text Attributes
        let text = textDocument.value(frame: frame) as! TextDocument
        let strokeColor = rootNode?.textOutputNode.strokeColor ?? text.strokeColorData?.cgColorValue
        let strokeWidth = rootNode?.textOutputNode.strokeWidth ?? CGFloat(text.strokeWidth ?? 0)
        let tracking = (CGFloat(text.fontSize) * (rootNode?.textOutputNode.tracking ?? CGFloat(text.tracking))) / 1000.0
        let matrix = rootNode?.textOutputNode.xform ?? CATransform3DIdentity
        let textString = textProvider.textFor(keypathName: keypathName, sourceText: text.text)
        let ctFont = fontProvider.fontFor(family: text.fontFamily, size: CGFloat(text.fontSize))
        
        // Set all of the text layer options
        textLayer.text = textString
        textLayer.font = ctFont
        textLayer.alignment = text.justification.textAlignment
        textLayer.lineHeight = CGFloat(text.lineHeight)
        textLayer.tracking = tracking
        
        if let fillColor = rootNode?.textOutputNode.fillColor {
            textLayer.fillColor = fillColor
        } else if let fillColor = text.fillColorData?.cgColorValue {
            textLayer.fillColor = fillColor
        } else {
            textLayer.fillColor = nil
        }
        
        textLayer.preferredSize = text.textFrameSize?.sizeValue
        textLayer.strokeOnTop = text.strokeOverFill ?? false
        textLayer.strokeWidth = strokeWidth
        textLayer.strokeColor = strokeColor
        textLayer.sizeToFit()
        
        textLayer.opacity = Float(rootNode?.textOutputNode.opacity ?? 1)
        textLayer.transform = CATransform3DIdentity
        textLayer.position = text.textFramePosition?.pointValue ?? CGPoint.zero
        textLayer.transform = matrix*/
    }
    
public:
    virtual bool isTextCompositionLayer() const override {
        return true;
    }
    
private:
    std::shared_ptr<TextAnimatorNode> _rootNode;
    std::shared_ptr<KeyframeInterpolator<TextDocument>> _textDocument;
    
    //std::shared_ptr<CoreTextRenderLayer> _textLayer;
    std::shared_ptr<AnimationTextProvider> _textProvider;
    std::shared_ptr<AnimationFontProvider> _fontProvider;
};

}

#endif /* TextCompositionLayer_hpp */
