// The window's map of animation frame callbacks and HTML's "run the animation frame callbacks"
// (https://html.spec.whatwg.org/#run-the-animation-frame-callbacks). When frames happen is the host's.
#pragma once

#include <cstddef>
#include <cstdint>

#include "quickjs.h"
#include "Sources/Support/Allocator.h"
#include "Sources/Support/Callbacks.h"
#include "Sources/Support/Values.h"

namespace wr {

class AnimationFrames {
public:
    explicit AnimationFrames(JSContext* ctx);
    ~AnimationFrames();
    AnimationFrames(const AnimationFrames&) = delete;
    AnimationFrames& operator=(const AnimationFrames&) = delete;

    /// A handle > 0. Throws RangeError past Timers::kMaxLive live callbacks (timers included).
    uint32_t request(JSContext* ctx, Callback callback);
    void cancel(JSContext* ctx, uint32_t handle);
    bool empty() const { return m_entries.empty(); }
    size_t liveCount() const { return m_entries.size(); }
    /// Runs the callbacks present now with `timestamp`, each removed before it is invoked and its exception reported;
    /// whether any ran. Throws Aborted.
    bool run(JSContext* ctx, double timestamp);

private:
    /// Tests only (AnimationFrameTests): moves the handle counter near UINT32_MAX, which no test can reach by requesting
    /// frames.
    friend struct AnimationFramesTestAccess;

    struct Entry {
        uint32_t handle = 0;
        /// Unique for the list's life, unlike a handle, which a wrapped counter can give again once it is free: what a
        /// frame finds the callbacks present at its start by.
        uint64_t sequence = 0;
        Held callback;
    };
    /// A handle > 0 not already in the list, from the counter, which wraps from UINT32_MAX to 1. At most
    /// Timers::kMaxLive handles are in use, so at most that many + 1 are tried.
    uint32_t takeHandle(JSContext* ctx);
    /// Whether an entry has `handle`.
    bool contains(JSContext* ctx, uint32_t handle);

    JSRuntime* m_rt;
    /// In request order.
    Vector<Entry> m_entries;
    /// The next handle takeHandle tries.
    uint32_t m_nextHandle = 1;
    uint64_t m_nextSequence = 1;
};

} // namespace wr
