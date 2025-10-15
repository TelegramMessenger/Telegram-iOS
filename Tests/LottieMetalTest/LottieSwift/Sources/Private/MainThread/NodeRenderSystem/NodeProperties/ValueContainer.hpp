#ifndef ValueContainer_hpp
#define ValueContainer_hpp

#include "Lottie/Public/Primitives/AnyValue.hpp"
#include "Lottie/Private/MainThread/NodeRenderSystem/NodeProperties/Protocols/AnyValueContainer.hpp"

namespace lottie {

/// A container for a node value that is Typed to T.
template<typename T>
class ValueContainer: public AnyValueContainer {
public:
    ValueContainer(T value) :
    _outputValue(value) {
    }
    
public:
    double _lastUpdateFrame = std::numeric_limits<double>::infinity();
    bool _needsUpdate = true;
    
    virtual AnyValue value() const override {
        return AnyValue(_outputValue);
    }
    
    virtual bool needsUpdate() const override {
        return _needsUpdate;
    }
    
    virtual double lastUpdateFrame() const override {
        return _lastUpdateFrame;
    }
    
    T _outputValue;
    
    T outputValue() {
        return _outputValue;
    }
    void setOutputValue(T value) {
        _outputValue = value;
        _needsUpdate = false;
    }
    
    void setValue(AnyValue value, double forFrame) {
        if (value.type() == AnyValueType<T>::type()) {
            _needsUpdate = false;
            _lastUpdateFrame = forFrame;
            _outputValue = value.get<T>();
        }
    }
    
    virtual void setNeedsUpdate() override {
        _needsUpdate = true;
    }
};

}

#endif /* ValueContainer_hpp */
