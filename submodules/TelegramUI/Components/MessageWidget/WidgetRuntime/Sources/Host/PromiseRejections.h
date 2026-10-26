// HTML's promise rejection tracking (https://html.spec.whatwg.org/#the-hostpromiserejectiontracker-implementation):
// the about-to-be-notified rejected promises list, the outstanding rejected promises set, and the unhandledrejection
// and rejectionhandled events. QuickJS calls the tracker from C with no way to charge work, so the tracker charges
// nothing, queues nothing, and every list it searches is bounded (M1b plan, Ruling 13). The charged work, queuing the
// events' tasks, happens at the microtask checkpoint (notify).
#pragma once

#include <cstdint>
#include <deque>

#include "quickjs.h"
#include "Sources/Support/Allocator.h"
#include "Sources/Support/Values.h"

namespace wr {

class PromiseRejections {
public:
    /// The about-to-be-notified list and the list being notified hold at most this many each.
    static constexpr size_t kMaxPending = 1024;
    /// The outstanding set: past it the oldest is evicted, and never gets rejectionhandled.
    static constexpr size_t kMaxOutstanding = 256;
    /// Outstanding rejections handled since the last checkpoint, each waiting for its rejectionhandled task. Past it a
    /// handled rejection is dropped as an evicted outstanding one is.
    static constexpr size_t kMaxHandledLater = kMaxOutstanding;

    explicit PromiseRejections(JSContext* ctx);
    ~PromiseRejections();
    PromiseRejections(const PromiseRejections&) = delete;
    PromiseRejections& operator=(const PromiseRejections&) = delete;

    /// HostPromiseRejectionTracker: "reject" when `isHandled` is false, "handle" when true. Never throws, never runs
    /// script and charges nothing; a failed allocation stops the widget (StopReason::Memory). A rejection past
    /// kMaxPending is dropped, with one unhandled-rejection-dropped diagnostic per runtime. "Handle" of an outstanding
    /// rejection only records it: its rejectionhandled task is queued by the next notify().
    void track(JSContext* ctx, JSValueConst promise, JSValueConst reason, bool isHandled) noexcept;
    /// HTML "notify about rejected promises" (the end of a microtask checkpoint), with the rejectionhandled tasks the
    /// tracker deferred: queues one rejectionhandled task per outstanding rejection handled since the last call, then
    /// the task that fires unhandledrejection for the promises still unhandled when it runs. Linear, charged per
    /// rejection before its work. Throws Thrown at the limit, std::bad_alloc, or what Host::diagnostic throws.
    void notify(JSContext* ctx);

private:
    /// Copied between the lists by value: a Held has no destructor, so a copy transfers the references, and release()
    /// is the one place they go. Do not add a destructor.
    struct Rejection {
        uint64_t id = 0;
        uint64_t batch = 0;
        bool handled = false;
        Held promise;
        Held reason;
    };
    template <class T>
    using Deque = std::deque<T, JSAllocator<T>>;

    /// The notification task of `batch`: one pass from the front of m_notifying over the records notify() copied there
    /// (`batch` and any older one left behind). Charged per record before its work.
    void fireUnhandled(JSContext* ctx, uint64_t batch);
    /// The one unhandled-rejection-dropped diagnostic.
    void noteDropped(JSContext* ctx);
    void release(Rejection& r);

    JSRuntime* m_rt;
    Vector<Rejection> m_aboutToBeNotified;
    /// Copied out of the list by notify(), waiting for their task, oldest batch first: the tracker marks one handled
    /// here. notify() appends while a notification task dispatches, and only that task removes, from the front.
    Deque<Rejection> m_notifying;
    Deque<Rejection> m_outstanding;
    /// Outstanding rejections the tracker saw handled, waiting for notify() to queue their rejectionhandled tasks.
    Vector<Rejection> m_handledLater;
    uint64_t m_nextId = 1;
    uint64_t m_nextBatch = 1;
    bool m_droppedReported = false;
};

} // namespace wr
