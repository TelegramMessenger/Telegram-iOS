#ifndef MaskContainerLayer_hpp
#define MaskContainerLayer_hpp

#include "Lottie/Private/Model/Objects/Mask.hpp"
#include "Lottie/Public/Primitives/CALayer.hpp"
#include "Lottie/Private/MainThread/NodeRenderSystem/NodeProperties/Protocols/NodePropertyMap.hpp"
#include "Lottie/Private/MainThread/NodeRenderSystem/NodeProperties/NodeProperty.hpp"
#include "Lottie/Private/MainThread/NodeRenderSystem/NodeProperties/ValueProviders/KeyframeInterpolator.hpp"

namespace lottie {

inline MaskMode usableMaskMode(MaskMode mode) {
    switch (mode) {
        case MaskMode::Add:
            return MaskMode::Add;
        case MaskMode::Subtract:
            return MaskMode::Subtract;
        case MaskMode::Intersect:
            return MaskMode::Intersect;
        case MaskMode::Lighten:
            return MaskMode::Add;
        case MaskMode::Darken:
            return MaskMode::Darken;
        case MaskMode::Difference:
            return MaskMode::Intersect;
        case MaskMode::None:
            return MaskMode::None;
    }
}

class MaskNodeProperties: public NodePropertyMap {
public:
    MaskNodeProperties(std::shared_ptr<Mask> const &mask) :
    _mode(mask->mode()),
    _inverted(mask->inverted) {
        _opacity = std::make_shared<NodeProperty<Vector1D>>(std::make_shared<KeyframeInterpolator<Vector1D>>(mask->opacity->keyframes));
        _shape = std::make_shared<NodeProperty<BezierPath>>(std::make_shared<KeyframeInterpolator<BezierPath>>(mask->shape.keyframes));
        _expansion = std::make_shared<NodeProperty<Vector1D>>(std::make_shared<KeyframeInterpolator<Vector1D>>(mask->expansion->keyframes));
        
        _propertyMap.insert(std::make_pair("Opacity", _opacity));
        _propertyMap.insert(std::make_pair("Shape", _shape));
        _propertyMap.insert(std::make_pair("Expansion", _expansion));
        
        for (const auto &it : _propertyMap) {
            _properties.push_back(it.second);
        }
    }
    
    virtual std::vector<std::shared_ptr<AnyNodeProperty>> &properties() override {
        return _properties;
    }
    
    virtual std::vector<std::shared_ptr<KeypathSearchable>> const &childKeypaths() const override {
        return _childKeypaths;
    }
    
    std::shared_ptr<NodeProperty<Vector1D>> const &opacity() const {
        return _opacity;
    }
    
    std::shared_ptr<NodeProperty<BezierPath>> const &shape() const {
        return _shape;
    }
    
    std::shared_ptr<NodeProperty<Vector1D>> const &expansion() const {
        return _expansion;
    }
    
    MaskMode mode() const {
        return _mode;
    }
    
    bool inverted() const {
        return _inverted;
    }
    
private:
    std::map<std::string, std::shared_ptr<AnyNodeProperty>> _propertyMap;
    std::vector<std::shared_ptr<KeypathSearchable>> _childKeypaths;
    
    std::vector<std::shared_ptr<AnyNodeProperty>> _properties;
    
    MaskMode _mode = MaskMode::Add;
    bool _inverted = false;
    
    std::shared_ptr<NodeProperty<Vector1D>> _opacity;
    std::shared_ptr<NodeProperty<BezierPath>> _shape;
    std::shared_ptr<NodeProperty<Vector1D>> _expansion;
};

class MaskLayer: public CALayer {
public:
    MaskLayer(std::shared_ptr<Mask> const &mask) :
    _properties(mask) {
        _maskLayer = std::make_shared<CAShapeLayer>();
        
        addSublayer(_maskLayer);
        
        if (mask->mode() == MaskMode::Add) {
            _maskLayer->setFillColor(Color(1.0, 0.0, 0.0, 1.0));
        } else {
            _maskLayer->setFillColor(Color(0.0, 1.0, 0.0, 1.0));
        }
        _maskLayer->setFillRule(FillRule::EvenOdd);
    }
    
    void updateWithFrame(double frame, bool forceUpdates) {
        if (_properties.opacity()->needsUpdate(frame) || forceUpdates) {
            _properties.opacity()->update(frame);
            setOpacity(_properties.opacity()->value().value);
        }
        
        if (_properties.shape()->needsUpdate(frame) || forceUpdates) {
            _properties.shape()->update(frame);
            _properties.expansion()->update(frame);
            
            auto path = _properties.shape()->value().cgPath();
            auto usableMode = usableMaskMode(_properties.mode());
            if ((usableMode == MaskMode::Subtract && !_properties.inverted()) ||
                 (usableMode == MaskMode::Add && _properties.inverted())) {
                /// Add a bounds rect to invert the mask
                auto newPath = CGPath::makePath();
                newPath->addRect(CGRect::veryLarge());
                newPath->addPath(path);
                path = std::static_pointer_cast<CGPath>(newPath);
            }
            _maskLayer->setPath(path);
        }
    }
    
private:
    MaskNodeProperties _properties;
    
    std::shared_ptr<CAShapeLayer> _maskLayer;
};

class MaskContainerLayer: public CALayer {
public:
    MaskContainerLayer(std::vector<std::shared_ptr<Mask>> const &masks) {
        auto containerLayer = std::make_shared<CALayer>();
        bool firstObject = true;
        for (const auto &mask : masks) {
            auto maskLayer = std::make_shared<MaskLayer>(mask);
            _maskLayers.push_back(maskLayer);
            
            auto usableMode = usableMaskMode(mask->mode());
            if (usableMode == MaskMode::None) {
                continue;
            } else if (usableMode == MaskMode::Add || firstObject) {
                firstObject = false;
                containerLayer->addSublayer(maskLayer);
            } else {
                containerLayer->setMask(maskLayer);
                auto newContainer = std::make_shared<CALayer>();
                newContainer->addSublayer(containerLayer);
                containerLayer = newContainer;
            }
        }
        addSublayer(containerLayer);
    }
    
    // MARK: Internal
    
    void updateWithFrame(double frame, bool forceUpdates) {
        for (const auto &maskLayer : _maskLayers) {
            maskLayer->updateWithFrame(frame, forceUpdates);
        }
    }
    
private:
    std::vector<std::shared_ptr<MaskLayer>> _maskLayers;
};

}

#endif /* MaskContainerLayer_hpp */
