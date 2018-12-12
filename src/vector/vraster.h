#ifndef VRASTER_H
#define VRASTER_H
#include <future>
#include "vglobal.h"
#include "vrect.h"

V_BEGIN_NAMESPACE

class VPath;
class VRle;

template <class R>
class VSharedState {
public:
    void set_value(R value) {
        if (_ready) return;

        {
            std::lock_guard<std::mutex> lock(_mutex);
            _value = std::move(value);
            _ready = true;
        }
        _cv.notify_one();
    }
    R get(){
        std::unique_lock<std::mutex> lock(_mutex);
        while(!_ready) _cv.wait(lock);
        _valid = false;
        return std::move(_value);
    }
    bool valid() const {return _valid;}
    void reuse() {
        _ready = false;
        _valid = true;
    }
private:
    R                        _value;
    std::mutex               _mutex;
    std::condition_variable  _cv;
    bool                     _ready{false};
    bool                     _valid{true};
};

using RleShare = std::shared_ptr<VSharedState<VRle>>;

struct VRaster {

    static void
    generateFillInfo(RleShare &promise, VPath &&path, VRle &&rle,
                     FillRule fillRule = FillRule::Winding, const VRect &clip = VRect());

    static void
    generateStrokeInfo(RleShare &promise, VPath &&path, VRle &&rle,
                       CapStyle cap, JoinStyle join,
                       float width, float meterLimit, const VRect &clip = VRect());
};

V_END_NAMESPACE

#endif  // VRASTER_H
