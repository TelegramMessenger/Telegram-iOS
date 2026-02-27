#ifndef SingleValueProvider_hpp
#define SingleValueProvider_hpp

#include "Lottie/Public/DynamicProperties/AnyValueProvider.hpp"

namespace lottie {

/// Returns a value for every frame.
template<typename T>
class SingleValueProvider: public ValueProvider<T> {
public:
    SingleValueProvider(T const &value) :
    _value(value) {
    }
    
    void setValue(T const &value) {
        _value = value;
        _hasUpdate = true;
    }
    
    virtual T value(AnimationFrameTime frame) override {
        return _value;
    }
    
    virtual AnyValue::Type valueType() const override {
        return AnyValueType<T>::type();
    }
    
    virtual bool hasUpdate(double frame) const override {
        return _hasUpdate;
    }
    
private:
    T _value;
    bool _hasUpdate = true;
};

}

#endif /* SingleValueProvider_hpp */
