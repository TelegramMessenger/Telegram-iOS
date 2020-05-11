#ifndef DEMO_MEDIAENGINEBASE_H
#define DEMO_MEDIAENGINEBASE_H


#include "rtc_base/copy_on_write_buffer.h"
#include "rtc_base/third_party/sigslot/sigslot.h"

#include <cstdint>

class MediaEngineBase {
public:
    MediaEngineBase() = default;
    virtual ~MediaEngineBase() = default;

    sigslot::signal1<rtc::CopyOnWriteBuffer> Send;
    virtual void Receive(rtc::CopyOnWriteBuffer) = 0;
    sigslot::signal2<const int16_t *, size_t> Play;
    sigslot::signal2<int16_t *, size_t> Record;
};

#endif //DEMO_MEDIAENGINEBASE_H
