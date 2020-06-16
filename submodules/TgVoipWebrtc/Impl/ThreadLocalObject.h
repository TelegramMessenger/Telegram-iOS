#ifndef TGVOIP_WEBRTC_THREAD_LOCAL_OBJECT_H
#define TGVOIP_WEBRTC_THREAD_LOCAL_OBJECT_H

#include "rtc_base/thread.h"

#include <functional>
#include <memory>

#ifdef TGVOIP_NAMESPACE
namespace TGVOIP_NAMESPACE {
#endif

template<class T>
class ThreadLocalObject {
private:
    template<class TV>
    class ValueHolder {
    public:
        std::shared_ptr<TV> _value;
    };
    
public:
    ThreadLocalObject(rtc::Thread *thread, std::function<T *()> generator) :
    _thread(thread) {
        assert(_thread != nullptr);
        _valueHolder = new ThreadLocalObject::ValueHolder<T>();
        //ValueHolder<T> *valueHolder = _valueHolder;
        _thread->Invoke<void>(RTC_FROM_HERE, [this, generator](){
            this->_valueHolder->_value.reset(generator());
        });
    }
    
    ~ThreadLocalObject() {
        ValueHolder<T> *valueHolder = _valueHolder;
        _thread->Invoke<void>(RTC_FROM_HERE, [this](){
            this->_valueHolder->_value.reset();
        });
        delete valueHolder;
    }
    
    template <class FunctorT>
    void perform(FunctorT&& functor) {
        //ValueHolder<T> *valueHolder = _valueHolder;
        /*_thread->PostTask(RTC_FROM_HERE, [valueHolder, f = std::forward<std::function<void(T &)>>(f)](){
            T *value = valueHolder->_value;
            assert(value != nullptr);
            f(*value);
        });*/
        _thread->Invoke<void>(RTC_FROM_HERE, [this, f = std::forward<FunctorT>(functor)](){
            assert(_valueHolder->_value != nullptr);
            f(_valueHolder->_value.get());
        });
    }
    
private:
    rtc::Thread *_thread;
    ValueHolder<T> *_valueHolder;
};

#ifdef TGVOIP_NAMESPACE
}
#endif

#endif
