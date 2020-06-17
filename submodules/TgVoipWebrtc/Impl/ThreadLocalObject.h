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
    _thread(thread),
    _valueHolder(new ThreadLocalObject::ValueHolder<T>()) {
        assert(_thread != nullptr);
        _thread->PostTask(RTC_FROM_HERE, [valueHolder = _valueHolder, generator](){
            valueHolder->_value.reset(generator());
        });
    }
    
    ~ThreadLocalObject() {
        _thread->PostTask(RTC_FROM_HERE, [valueHolder = _valueHolder](){
            valueHolder->_value.reset();
        });
    }
    
    template <class FunctorT>
    void perform(FunctorT&& functor) {
        _thread->PostTask(RTC_FROM_HERE, [valueHolder = _valueHolder, f = std::forward<FunctorT>(functor)](){
            assert(valueHolder->_value != nullptr);
            f(valueHolder->_value.get());
        });
    }
    
private:
    rtc::Thread *_thread;
    std::shared_ptr<ValueHolder<T>> _valueHolder;
};

#ifdef TGVOIP_NAMESPACE
}
#endif

#endif
