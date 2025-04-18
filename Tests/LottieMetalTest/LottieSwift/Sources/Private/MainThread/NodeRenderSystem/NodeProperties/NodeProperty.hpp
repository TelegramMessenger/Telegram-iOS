#ifndef NodeProperty_hpp
#define NodeProperty_hpp

#include "Lottie/Public/Primitives/AnyValue.hpp"
#include "Lottie/Private/MainThread/NodeRenderSystem/NodeProperties/Protocols/AnyNodeProperty.hpp"
#include "Lottie/Public/DynamicProperties/AnyValueProvider.hpp"
#include "Lottie/Private/MainThread/NodeRenderSystem/NodeProperties/ValueContainer.hpp"

namespace lottie {

/// A node property that holds a reference to a T ValueProvider and a T ValueContainer.
template<typename T>
class NodeProperty: public AnyNodeProperty {
public:
    NodeProperty(std::shared_ptr<ValueProvider<T>> provider) :
    _valueProvider(provider),
    //_originalValueProvider(provider),
    _typedContainer(provider->value(0.0)) {
        _typedContainer.setNeedsUpdate();
    }
    
public:
    virtual AnyValue::Type valueType() const override {
        return AnyValueType<T>::type();
    }
    
    virtual T value() {
        return _typedContainer.outputValue();
    }
    
    virtual bool needsUpdate(double frame) const override {
        return _typedContainer.needsUpdate() || _valueProvider->hasUpdate(frame);
    }
    
    virtual void setProvider(std::shared_ptr<AnyValueProvider> provider) override {
        /*if (provider->valueType() != valueType()) {
            return;
        }
        _valueProvider = provider;
        _typedContainer.setNeedsUpdate();*/
    }
    
    virtual void update(double frame) override {
        _typedContainer.setValue(_valueProvider->value(frame), frame);
    }
    
private:
    ValueContainer<T> _typedContainer;
    std::shared_ptr<ValueProvider<T>> _valueProvider;
    //std::shared_ptr<AnyValueProvider> _originalValueProvider;
};

}

#endif /* NodeProperty_hpp */
