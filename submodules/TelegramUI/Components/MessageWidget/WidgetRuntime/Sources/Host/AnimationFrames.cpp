#include "Sources/Host/AnimationFrames.h"

#include "Sources/Host/ErrorReporting.h"
#include "Sources/Host/EventLoop.h"
#include "Sources/Host/Timers.h"
#include "Sources/Support/Errors.h"

namespace wr {

AnimationFrames::AnimationFrames(JSContext* ctx) : m_rt(JS_GetRuntime(ctx)), m_entries(JSAllocator<Entry>(m_rt)) {}

AnimationFrames::~AnimationFrames() {
    for (Entry& entry : m_entries) {
        entry.callback.clear(m_rt);
    }
}

bool AnimationFrames::contains(JSContext* ctx, uint32_t handle) {
    for (const Entry& entry : m_entries) {
        if (entry.handle == handle) {
            return true;
        }
    }
    return false;
}

uint32_t AnimationFrames::takeHandle(JSContext* ctx) {
    for (;;) {
        uint32_t candidate = m_nextHandle;
        // Compared before it is incremented: the counter never passes UINT32_MAX, and never reaches 0.
        m_nextHandle = candidate == UINT32_MAX ? 1 : candidate + 1;
        if (!this->contains(ctx, candidate)) {
            return candidate;
        }
    }
}

uint32_t AnimationFrames::request(JSContext* ctx, Callback callback) {
    if (this->liveCount() >= Timers::kMaxLive) {
        throw RangeError{"too many animation frame callbacks"};
    }
    uint32_t handle = this->takeHandle(ctx);
    m_entries.emplace_back();
    Entry& entry = m_entries.back();
    entry.handle = handle;
    entry.sequence = m_nextSequence++;
    entry.callback.value = callback.newRef();
    return handle;
}

void AnimationFrames::cancel(JSContext* ctx, uint32_t handle) {
    for (size_t i = 0; i < m_entries.size(); i++) {
        if (m_entries[i].handle == handle) {
            m_entries[i].callback.clear(m_rt);
            m_entries.erase(m_entries.begin() + long(i));
            return;
        }
    }
}

bool AnimationFrames::run(JSContext* ctx, double timestamp) {
    if (m_entries.empty()) {
        return false;
    }
    // The callbacks present now; one requested while they run waits for the next frame, even when it was given the
    // handle of one an earlier callback canceled.
    Vector<uint64_t> present{JSAllocator<uint64_t>(m_rt)};
    for (const Entry& entry : m_entries) {
        present.push_back(entry.sequence);
    }
    Value now = Value::adopt(ctx, JS_NewFloat64(ctx, timestamp));
    for (uint64_t sequence : present) {
        Value callback;
        for (size_t i = 0; i < m_entries.size(); i++) {
            if (m_entries[i].sequence == sequence) {
                callback = Value::adopt(ctx, m_entries[i].callback.value);   // takes the entry's reference
                m_entries[i].callback.value = JS_UNDEFINED;
                m_entries.erase(m_entries.begin() + long(i));
                break;
            }
        }
        if (JS_IsUndefined(callback.get())) {
            continue;   // canceled by an earlier callback of this frame
        }
        JSValueConst argv[1] = {now.get()};
        invokeWithReport(ctx, callback.get(), JS_UNDEFINED, 1, argv);
    }
    return true;
}

} // namespace wr
