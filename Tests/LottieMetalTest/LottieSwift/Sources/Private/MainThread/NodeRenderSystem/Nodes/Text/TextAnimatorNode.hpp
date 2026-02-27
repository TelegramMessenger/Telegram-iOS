#ifndef TextAnimatorNode_hpp
#define TextAnimatorNode_hpp

#include "Lottie/Private/MainThread/NodeRenderSystem/NodeProperties/Protocols/NodePropertyMap.hpp"
#include "Lottie/Private/Model/Text/TextAnimator.hpp"
#include "Lottie/Private/MainThread/NodeRenderSystem/NodeProperties/NodeProperty.hpp"
#include "Lottie/Private/MainThread/NodeRenderSystem/NodeProperties/ValueProviders/KeyframeInterpolator.hpp"
#include "Lottie/Private/MainThread/NodeRenderSystem/Protocols/NodeOutput.hpp"
#include "Lottie/Private/MainThread/NodeRenderSystem/Protocols/AnimatorNode.hpp"

namespace lottie {

class TextAnimatorNodeProperties: public KeypathSearchableNodePropertyMap {
public:
    TextAnimatorNodeProperties(std::shared_ptr<TextAnimator> const &textAnimator) {
        _keypathName = textAnimator->name.value_or("");
        
        if (textAnimator->anchor) {
            _anchor = std::make_shared<NodeProperty<Vector3D>>(std::make_shared<KeyframeInterpolator<Vector3D>>(textAnimator->anchor->keyframes));
            _keypathProperties.insert(std::make_pair("Anchor", _anchor));
        }
        
        if (textAnimator->position) {
            _position = std::make_shared<NodeProperty<Vector3D>>(std::make_shared<KeyframeInterpolator<Vector3D>>(textAnimator->position->keyframes));
            _keypathProperties.insert(std::make_pair("Position", _position));
        }
        
        if (textAnimator->scale) {
            _scale = std::make_shared<NodeProperty<Vector3D>>(std::make_shared<KeyframeInterpolator<Vector3D>>(textAnimator->scale->keyframes));
            _keypathProperties.insert(std::make_pair("Scale", _scale));
        }
        
        if (textAnimator->skew) {
            _skew = std::make_shared<NodeProperty<Vector1D>>(std::make_shared<KeyframeInterpolator<Vector1D>>(textAnimator->skew->keyframes));
            _keypathProperties.insert(std::make_pair("Skew", _skew));
        }
        
        if (textAnimator->skewAxis) {
            _skewAxis = std::make_shared<NodeProperty<Vector1D>>(std::make_shared<KeyframeInterpolator<Vector1D>>(textAnimator->skewAxis->keyframes));
            _keypathProperties.insert(std::make_pair("Skew Axis", _skewAxis));
        }
        
        if (textAnimator->rotation) {
            _rotation = std::make_shared<NodeProperty<Vector1D>>(std::make_shared<KeyframeInterpolator<Vector1D>>(textAnimator->rotation->keyframes));
            _keypathProperties.insert(std::make_pair("Rotation", _rotation));
        }
        
        if (textAnimator->rotation) {
            _opacity = std::make_shared<NodeProperty<Vector1D>>(std::make_shared<KeyframeInterpolator<Vector1D>>(textAnimator->opacity->keyframes));
            _keypathProperties.insert(std::make_pair("Opacity", _opacity));
        }
        
        if (textAnimator->strokeColor) {
            _strokeColor = std::make_shared<NodeProperty<Color>>(std::make_shared<KeyframeInterpolator<Color>>(textAnimator->strokeColor->keyframes));
            _keypathProperties.insert(std::make_pair("Stroke Color", _strokeColor));
        }
        
        if (textAnimator->fillColor) {
            _fillColor = std::make_shared<NodeProperty<Color>>(std::make_shared<KeyframeInterpolator<Color>>(textAnimator->fillColor->keyframes));
            _keypathProperties.insert(std::make_pair("Fill Color", _fillColor));
        }
        
        if (textAnimator->strokeWidth) {
            _strokeWidth = std::make_shared<NodeProperty<Vector1D>>(std::make_shared<KeyframeInterpolator<Vector1D>>(textAnimator->strokeWidth->keyframes));
            _keypathProperties.insert(std::make_pair("Stroke Width", _strokeWidth));
        }
        
        if (textAnimator->tracking) {
            _tracking = std::make_shared<NodeProperty<Vector1D>>(std::make_shared<KeyframeInterpolator<Vector1D>>(textAnimator->tracking->keyframes));
            _keypathProperties.insert(std::make_pair("Tracking", _tracking));
        }
        
        for (const auto &it : _keypathProperties) {
            _properties.push_back(it.second);
        }
    }
    
    virtual std::string keypathName() const override {
        return _keypathName;
    }
    
    virtual std::map<std::string, std::shared_ptr<AnyNodeProperty>> keypathProperties() const override {
        return _keypathProperties;
    }
    
    virtual std::vector<std::shared_ptr<AnyNodeProperty>> &properties() override {
        return _properties;
    }
    
    virtual std::vector<std::shared_ptr<KeypathSearchable>> const &childKeypaths() const override {
        return _childKeypaths;
    }
    
    CATransform3D caTransform() {
        Vector2D anchor = Vector2D::Zero();
        if (_anchor) {
            auto anchor3d = _anchor->value();
            anchor = Vector2D(anchor3d.x, anchor3d.y);
        }
        
        Vector2D position = Vector2D::Zero();
        if (_position) {
            auto position3d = _position->value();
            position = Vector2D(position3d.x, position3d.y);
        }
        
        Vector2D scale = Vector2D(100.0, 100.0);
        if (_scale) {
            auto scale3d = _scale->value();
            scale = Vector2D(scale3d.x, scale3d.y);
        }
        
        double rotation = 0.0;
        if (_rotation) {
            rotation = _rotation->value().value;
        }
        
        std::optional<double> skew;
        if (_skew) {
            skew = _skew->value().value;
        }
        std::optional<double> skewAxis;
        if (_skewAxis) {
            skewAxis = _skewAxis->value().value;
        }
        
        return CATransform3D::makeTransform(
            anchor,
            position,
            scale,
            rotation,
            skew,
            skewAxis
        );
    }
    
    virtual std::shared_ptr<CALayer> keypathLayer() const override {
        return nullptr;
    }
    
    double opacity() {
        if (_opacity) {
            return _opacity->value().value;
        } else {
            return 100.0;
        }
    }
    
    std::optional<Color> strokeColor() {
        if (_strokeColor) {
            return _strokeColor->value();
        } else {
            return std::nullopt;
        }
    }
    
    std::optional<Color> fillColor() {
        if (_fillColor) {
            return _fillColor->value();
        } else {
            return std::nullopt;
        }
    }
    
    double tracking() {
        if (_tracking) {
            return _tracking->value().value;
        } else {
            return 1.0;
        }
    }
    
    double strokeWidth() {
        if (_strokeWidth) {
            return _strokeWidth->value().value;
        } else {
            return 0.0;
        }
    }
    
private:
    std::string _keypathName;
    
    std::shared_ptr<NodeProperty<Vector3D>> _anchor;
    std::shared_ptr<NodeProperty<Vector3D>> _position;
    std::shared_ptr<NodeProperty<Vector3D>> _scale;
    std::shared_ptr<NodeProperty<Vector1D>> _skew;
    std::shared_ptr<NodeProperty<Vector1D>> _skewAxis;
    std::shared_ptr<NodeProperty<Vector1D>> _rotation;
    std::shared_ptr<NodeProperty<Vector1D>> _opacity;
    std::shared_ptr<NodeProperty<Color>> _strokeColor;
    std::shared_ptr<NodeProperty<Color>> _fillColor;
    std::shared_ptr<NodeProperty<Vector1D>> _strokeWidth;
    std::shared_ptr<NodeProperty<Vector1D>> _tracking;
    
    std::map<std::string, std::shared_ptr<AnyNodeProperty>> _keypathProperties;
    std::vector<std::shared_ptr<KeypathSearchable>> _childKeypaths;
    std::vector<std::shared_ptr<AnyNodeProperty>> _properties;
};

class TextOutputNode: virtual public NodeOutput {
public:
    TextOutputNode(std::shared_ptr<TextOutputNode> parent) :
    _parentTextNode(parent) {
    }
    
    virtual std::shared_ptr<NodeOutput> parent() override {
        return _parentTextNode;
    }
    
    CATransform3D xform() {
        if (_xform.has_value()) {
            return _xform.value();
        } else if (_parentTextNode) {
            return _parentTextNode->xform();
        } else {
            return CATransform3D::identity();
        }
    }
    void setXform(CATransform3D const &xform) {
        _xform = xform;
    }
    
    double opacity() {
        if (_opacity.has_value()) {
            return _opacity.value();
        } else if (_parentTextNode) {
            return _parentTextNode->opacity();
        } else {
            return 1.0;
        }
    }
    void setOpacity(double opacity) {
        _opacity = opacity;
    }
    
    std::optional<Color> strokeColor() {
        if (_strokeColor.has_value()) {
            return _strokeColor.value();
        } else if (_parentTextNode) {
            return _parentTextNode->strokeColor();
        } else {
            return std::nullopt;
        }
    }
    void setStrokeColor(std::optional<Color> strokeColor) {
        _strokeColor = strokeColor;
    }
    
    std::optional<Color> fillColor() {
        if (_fillColor.has_value()) {
            return _fillColor.value();
        } else if (_parentTextNode) {
            return _parentTextNode->fillColor();
        } else {
            return std::nullopt;
        }
    }
    void setFillColor(std::optional<Color> fillColor) {
        _fillColor = fillColor;
    }
    
    double tracking() {
        if (_tracking.has_value()) {
            return _tracking.value();
        } else if (_parentTextNode) {
            return _parentTextNode->tracking();
        } else {
            return 0.0;
        }
    }
    void setTracking(double tracking) {
        _tracking = tracking;
    }
    
    double strokeWidth() {
        if (_strokeWidth.has_value()) {
            return _strokeWidth.value();
        } else if (_parentTextNode) {
            return _parentTextNode->strokeWidth();
        } else {
            return 0.0;
        }
    }
    void setStrokeWidth(double strokeWidth) {
        _strokeWidth = strokeWidth;
    }
    
    virtual bool hasOutputUpdates(double frame) override {
        // TODO Fix This
        return true;
    }
    
    virtual std::shared_ptr<CGPath> outputPath() override {
        return _outputPath;
    }
    
    virtual bool isEnabled() const override {
        return _isEnabled;
    }
    virtual void setIsEnabled(bool isEnabled) override {
        _isEnabled = isEnabled;
    }
    
private:
    std::shared_ptr<TextOutputNode> _parentTextNode;
    bool _isEnabled = true;
    
    std::shared_ptr<CGPath> _outputPath;
    
    std::optional<CATransform3D> _xform;
    std::optional<double> _opacity;
    std::optional<Color> _strokeColor;
    std::optional<Color> _fillColor;
    std::optional<double> _tracking;
    std::optional<double> _strokeWidth;
};

class TextAnimatorNode: public AnimatorNode {
public:
    TextAnimatorNode(std::shared_ptr<TextAnimatorNode> const &parentNode, std::shared_ptr<TextAnimator> const &textAnimator) :
    AnimatorNode(parentNode) {
        std::shared_ptr<TextOutputNode> parentOutputNode;
        if (parentNode) {
            parentOutputNode = parentNode->_textOutputNode;
        }
        _textOutputNode = std::make_shared<TextOutputNode>(parentOutputNode);
        
        _textAnimatorProperties = std::make_shared<TextAnimatorNodeProperties>(textAnimator);
    }
    
    virtual std::shared_ptr<NodeOutput> outputNode() override {
        return _textOutputNode;
    }
    
    virtual std::shared_ptr<KeypathSearchableNodePropertyMap> propertyMap() const override {
        return _textAnimatorProperties;
    }
    
    virtual bool localUpdatesPermeateDownstream() override {
        return true;
    }
    
    virtual void rebuildOutputs(double frame) override {
        _textOutputNode->setXform(_textAnimatorProperties->caTransform());
        _textOutputNode->setOpacity(((float)_textAnimatorProperties->opacity()) * 0.01f);
        _textOutputNode->setStrokeColor(_textAnimatorProperties->strokeColor());
        _textOutputNode->setFillColor(_textAnimatorProperties->fillColor());
        _textOutputNode->setTracking(_textAnimatorProperties->tracking());
        _textOutputNode->setStrokeWidth(_textAnimatorProperties->strokeWidth());
    }
    
private:
    std::shared_ptr<TextOutputNode> _textOutputNode;
    
    std::shared_ptr<TextAnimatorNodeProperties> _textAnimatorProperties;
};

}

#endif /* TextAnimatorNode_hpp */
