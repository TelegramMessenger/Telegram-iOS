#ifndef LayerTransformNode_hpp
#define LayerTransformNode_hpp

#include "Lottie/Private/Model/Objects/Transform.hpp"
#include "Lottie/Private/MainThread/NodeRenderSystem/NodeProperties/Protocols/NodePropertyMap.hpp"
#include "Lottie/Private/MainThread/NodeRenderSystem/NodeProperties/Protocols/KeypathSearchable.hpp"
#include "Lottie/Private/MainThread/NodeRenderSystem/NodeProperties/NodeProperty.hpp"
#include "Lottie/Private/MainThread/NodeRenderSystem/NodeProperties/ValueProviders/KeyframeInterpolator.hpp"
#include "Lottie/Private/MainThread/NodeRenderSystem/Protocols/AnimatorNode.hpp"
#include "Lottie/Private/MainThread/NodeRenderSystem/Protocols/NodeOutput.hpp"
#include "Lottie/Private/MainThread/NodeRenderSystem/Nodes/OutputNodes/PassThroughOutputNode.hpp"

namespace lottie {

class LayerTransformProperties: public KeypathSearchableNodePropertyMap {
public:
    LayerTransformProperties(std::shared_ptr<Transform> transform) {
        _anchor = std::make_shared<NodeProperty<Vector3D>>(std::make_shared<KeyframeInterpolator<Vector3D>>(transform->anchorPoint().keyframes));
        _scale = std::make_shared<NodeProperty<Vector3D>>(std::make_shared<KeyframeInterpolator<Vector3D>>(transform->scale().keyframes));
        _rotation = std::make_shared<NodeProperty<Vector1D>>(std::make_shared<KeyframeInterpolator<Vector1D>>(transform->rotation().keyframes));
        _opacity = std::make_shared<NodeProperty<Vector1D>>(std::make_shared<KeyframeInterpolator<Vector1D>>(transform->opacity().keyframes));
        
        std::map<std::string, std::shared_ptr<AnyNodeProperty>> propertyMap;
        _keypathProperties.insert(std::make_pair("Anchor Point", _anchor));
        _keypathProperties.insert(std::make_pair("Scale", _scale));
        _keypathProperties.insert(std::make_pair("Rotation", _rotation));
        _keypathProperties.insert(std::make_pair("Opacity", _opacity));
        
        if (transform->positionX().has_value() && transform->positionY().has_value()) {
            auto xPosition = std::make_shared<NodeProperty<Vector1D>>(std::make_shared<KeyframeInterpolator<Vector1D>>(transform->positionX()->keyframes));
            auto yPosition = std::make_shared<NodeProperty<Vector1D>>(std::make_shared<KeyframeInterpolator<Vector1D>>(transform->positionY()->keyframes));
            _keypathProperties.insert(std::make_pair("X Position", xPosition));
            _keypathProperties.insert(std::make_pair("Y Position", yPosition));
            
            _positionX = xPosition;
            _positionY = yPosition;
            _position = nullptr;
        } else if (transform->position().has_value()) {
            auto position = std::make_shared<NodeProperty<Vector3D>>(std::make_shared<KeyframeInterpolator<Vector3D>>(transform->position()->keyframes));
            _keypathProperties.insert(std::make_pair("Position", position));
            
            _position = position;
            _positionX = nullptr;
            _positionY = nullptr;
        } else {
            _position = nullptr;
            _positionX = nullptr;
            _positionY = nullptr;
        }
        
        for (const auto &it : _keypathProperties) {
            _properties.push_back(it.second);
        }
    }
    
    virtual std::vector<std::shared_ptr<AnyNodeProperty>> &properties() override {
        return _properties;
    }
    
    virtual std::vector<std::shared_ptr<KeypathSearchable>> const &childKeypaths() const override {
        return _childKeypaths;
    }
    
    virtual std::string keypathName() const override {
        return "Transform";
    }
    
    virtual std::map<std::string, std::shared_ptr<AnyNodeProperty>> keypathProperties() const override {
        return _keypathProperties;
    }
    
    virtual std::shared_ptr<CALayer> keypathLayer() const override {
        return nullptr;
    }

    std::shared_ptr<NodeProperty<Vector3D>> const &anchor() {
        return _anchor;
    }
    
    std::shared_ptr<NodeProperty<Vector3D>> const &scale() {
        return _scale;
    }
    
    std::shared_ptr<NodeProperty<Vector1D>> const &rotation() {
        return _rotation;
    }
    
    std::shared_ptr<NodeProperty<Vector3D>> const &position() {
        return _position;
    }
    
    std::shared_ptr<NodeProperty<Vector1D>> const &positionX() {
        return _positionX;
    }
    
    std::shared_ptr<NodeProperty<Vector1D>> const &positionY() {
        return _positionY;
    }
    
    std::shared_ptr<NodeProperty<Vector1D>> const &opacity() {
        return _opacity;
    }
    
private:
    std::map<std::string, std::shared_ptr<AnyNodeProperty>> _keypathProperties;
    std::vector<std::shared_ptr<KeypathSearchable>> _childKeypaths;
    
    std::vector<std::shared_ptr<AnyNodeProperty>> _properties;
    
    std::shared_ptr<NodeProperty<Vector3D>> _anchor;
    std::shared_ptr<NodeProperty<Vector3D>> _scale;
    std::shared_ptr<NodeProperty<Vector1D>> _rotation;
    std::shared_ptr<NodeProperty<Vector3D>> _position;
    std::shared_ptr<NodeProperty<Vector1D>> _positionX;
    std::shared_ptr<NodeProperty<Vector1D>> _positionY;
    std::shared_ptr<NodeProperty<Vector1D>> _opacity;
};

class LayerTransformNode: public AnimatorNode {
public:
    LayerTransformNode(std::shared_ptr<Transform> transform) :
    AnimatorNode(nullptr),
    _transformProperties(std::make_shared<LayerTransformProperties>(transform)) {
        _outputNode = std::make_shared<PassThroughOutputNode>(nullptr);
    }
    
    virtual std::shared_ptr<NodeOutput> outputNode() override {
        return _outputNode;
    }
    
    virtual std::shared_ptr<KeypathSearchableNodePropertyMap> propertyMap() const override {
        return _transformProperties;
    }
    
    virtual bool shouldRebuildOutputs(double frame) override {
        return hasLocalUpdates() || hasUpstreamUpdates();
    }
    
    virtual void rebuildOutputs(double frame) override {
        _opacity = ((float)_transformProperties->opacity()->value().value) * 0.01f;
        
        Vector2D position(0.0, 0.0);
        if (_transformProperties->position()) {
            auto position3d = _transformProperties->position()->value();
            position.x = position3d.x;
            position.y = position3d.y;
        } else if (_transformProperties->positionX() && _transformProperties->positionY()) {
            position = Vector2D(
                _transformProperties->positionX()->value().value,
                _transformProperties->positionY()->value().value
            );
        }
        
        Vector3D anchor = _transformProperties->anchor()->value();
        Vector3D scale = _transformProperties->scale()->value();
        _localTransform = CATransform3D::makeTransform(
            Vector2D(anchor.x, anchor.y),
            position,
            Vector2D(scale.x, scale.y),
            _transformProperties->rotation()->value().value,
            std::nullopt,
            std::nullopt
        );
        
        if (parentNode() && parentNode()->asLayerTransformNode()) {
            _globalTransform = _localTransform * parentNode()->asLayerTransformNode()->_globalTransform;
        } else {
            _globalTransform = _localTransform;
        }
    }
    
    std::shared_ptr<LayerTransformProperties> const &transformProperties() {
        return _transformProperties;
    }
    
    float opacity() {
        return _opacity;
    }
    
    CATransform3D const &globalTransform() {
        return _globalTransform;
    }
    
private:
    std::shared_ptr<NodeOutput> _outputNode;
    
    std::shared_ptr<LayerTransformProperties> _transformProperties;
    
    float _opacity = 1.0;
    CATransform3D _localTransform = CATransform3D::identity();
    CATransform3D _globalTransform = CATransform3D::identity();
    
public:
    virtual LayerTransformNode *asLayerTransformNode() override {
        return this;
    }
};

}

#endif /* LayerTransformNode_hpp */
