#include "Sources/Host/PromiseRejections.h"

#include <new>

#include "Generated/Bindings.h"
#include "Sources/Events/Dispatch.h"
#include "Sources/Events/Event.h"
#include "Sources/Host/ErrorReporting.h"
#include "Sources/Host/EventLoop.h"
#include "Sources/Host/HostState.h"
#include "Sources/Host/Window.h"
#include "Sources/Runtime/Runtime.h"

namespace wr {

namespace {

/// Fires a trusted PromiseRejectionEvent at the window; whether it was not canceled. Throws as dispatch does.
bool firePromiseRejectionEvent(JSContext* ctx, const char* type, JSValueConst promise, JSValueConst reason, bool cancelable) {
    idl::PromiseRejectionEventInit init;
    init.cancelable = cancelable;
    init.promise = Object(Value::dup(ctx, promise));
    init.reason = Value::dup(ctx, reason);
    Ref<PromiseRejectionEvent> event = PromiseRejectionEvent::construct(ctx, String::fromUTF8(ctx, type), std::move(init));
    event->setIsTrusted(true);
    // The window is the global object, alive for the context's life.
    return dispatch(ctx, *event, HostState::of(ctx).window());
}

/// The tracker's identity test. A promise is an object, so it is its address: no script.
bool samePromise(JSValueConst a, JSValueConst b) {
    return JS_VALUE_GET_TAG(a) == JS_TAG_OBJECT && JS_VALUE_GET_TAG(b) == JS_TAG_OBJECT && JS_VALUE_GET_PTR(a) == JS_VALUE_GET_PTR(b);
}

/// The index of `promise`'s record in `list`, searched from the newest, or -1. Every list the tracker searches is
/// capped (Ruling 13).
template <class List>
long indexOf(const List& list, JSValueConst promise) {
    for (size_t i = list.size(); i-- > 0;) {
        if (samePromise(list[i].promise.value, promise)) {
            return long(i);
        }
    }
    return -1;
}

static_assert(PromiseRejections::kMaxPending == 1024, "the dropped diagnostic's text names the cap");

} // namespace

PromiseRejections::PromiseRejections(JSContext* ctx)
    : m_rt(JS_GetRuntime(ctx)),
      m_aboutToBeNotified(JSAllocator<Rejection>(m_rt)),
      m_notifying(JSAllocator<Rejection>(m_rt)),
      m_outstanding(JSAllocator<Rejection>(m_rt)),
      m_handledLater(JSAllocator<Rejection>(m_rt)) {}

PromiseRejections::~PromiseRejections() {
    for (Rejection& r : m_aboutToBeNotified) {
        this->release(r);
    }
    for (Rejection& r : m_notifying) {
        this->release(r);
    }
    for (Rejection& r : m_outstanding) {
        this->release(r);
    }
    for (Rejection& r : m_handledLater) {
        this->release(r);
    }
}

void PromiseRejections::release(Rejection& r) {
    r.promise.clear(m_rt);
    r.reason.clear(m_rt);
}

void PromiseRejections::noteDropped(JSContext* ctx) {
    if (m_droppedReported) {
        return;
    }
    m_droppedReported = true;
    Runtime::from(ctx).host().diagnostic("unhandled-rejection-dropped", "more than 1024 rejections awaiting notification");
}

void PromiseRejections::track(JSContext* ctx, JSValueConst promise, JSValueConst reason, bool isHandled) noexcept {
    try {
        if (!isHandled) {
            // "reject": append to the about-to-be-notified list.
            if (m_aboutToBeNotified.size() >= kMaxPending) {
                this->noteDropped(ctx);
                return;
            }
            m_aboutToBeNotified.emplace_back();
            Rejection& r = m_aboutToBeNotified.back();
            r.id = m_nextId++;
            r.promise.value = JS_DupValue(ctx, promise);
            r.reason.value = JS_DupValue(ctx, reason);
            return;
        }
        // "handle". Most often the newest record: a promise handled by the script that rejected it.
        if (long i = indexOf(m_aboutToBeNotified, promise); i >= 0) {
            this->release(m_aboutToBeNotified[size_t(i)]);
            m_aboutToBeNotified.erase(m_aboutToBeNotified.begin() + i);
            return;
        }
        if (long i = indexOf(m_notifying, promise); i >= 0) {
            // HTML's notification task checks [[PromiseIsHandled]] when it runs; QuickJS does not expose it, so the
            // tracker records it here.
            m_notifying[size_t(i)].handled = true;
            return;
        }
        long i = indexOf(m_outstanding, promise);
        if (i < 0) {
            return;
        }
        // HTML queues the rejectionhandled task here; the tracker queues nothing, so it waits for the next notify()
        // (R1).
        if (m_handledLater.size() >= kMaxHandledLater) {
            this->release(m_outstanding[size_t(i)]);
        } else {
            m_handledLater.push_back(m_outstanding[size_t(i)]);
        }
        m_outstanding.erase(m_outstanding.begin() + i);
    } catch (const Thrown&) {
        // Nothing here throws it: a pending exception can only be the stop the interrupt already latched.
    } catch (const std::bad_alloc&) {
        Runtime::from(ctx).stop(StopReason::Memory);
    } catch (...) {
        Runtime::from(ctx).stop(StopReason::Internal);
    }
}

void PromiseRejections::notify(JSContext* ctx) {
    EventLoop& loop = EventLoop::of(ctx);
    // The rejectionhandled tasks the tracker deferred, one per record. A record's references go to its task once the
    // task is queued; on a throw, the records queued so far hold nothing, the rest still hold theirs, and the runtime is
    // stopped (the checkpoint latches), so the destructor's release is exact either way.
    for (Rejection& r : m_handledLater) {
        Value promise = Value::dup(ctx, r.promise.value);
        Value reason = Value::dup(ctx, r.reason.value);
        loop.queueTask(TaskSource::DOMManipulation, makeTask(ctx, [promise = std::move(promise), reason = std::move(reason)](JSContext* ctx) {
            firePromiseRejectionEvent(ctx, "rejectionhandled", promise.get(), reason.get(), false);
        }));
        this->release(r);
    }
    m_handledLater.clear();

    // HTML "notify about rejected promises": the list's records move behind the list being notified, which holds at most
    // kMaxPending (a record past it is dropped), and one task notifies them. The same transfer rule as above.
    if (m_aboutToBeNotified.empty()) {
        return;
    }
    uint64_t batch = m_nextBatch++;
    bool moved = false;
    for (Rejection& r : m_aboutToBeNotified) {
        if (m_notifying.size() >= kMaxPending) {
            this->release(r);
            this->noteDropped(ctx);
            continue;
        }
        r.batch = batch;
        m_notifying.push_back(r);
        r.promise.value = JS_UNDEFINED;
        r.reason.value = JS_UNDEFINED;
        moved = true;
    }
    m_aboutToBeNotified.clear();
    if (!moved) {
        return;
    }
    loop.queueTask(TaskSource::DOMManipulation, makeTask(ctx, [batch](JSContext* ctx) {
        EventLoop::of(ctx).rejections().fireUnhandled(ctx, batch);
    }));
}

void PromiseRejections::fireUnhandled(JSContext* ctx, uint64_t batch) {
    // One pass from the front. Only this task removes records, and tasks do not nest, so the record being dispatched
    // stays at the front while its listeners run; the checkpoint after each listener can append a later batch behind
    // it (a deque keeps the front's place), which the next notification task takes.
    while (!m_notifying.empty() && m_notifying.front().batch <= batch) {
        if (m_notifying.front().handled) {
            this->release(m_notifying.front());
            m_notifying.pop_front();
            continue;
        }
        uint64_t id = m_notifying.front().id;
        Value promise = Value::dup(ctx, m_notifying.front().promise.value);
        Value reason = Value::dup(ctx, m_notifying.front().reason.value);
        // A listener that handles the promise is recorded by the tracker, and decides below whether it joins the
        // outstanding set.
        bool notHandled = firePromiseRejectionEvent(ctx, "unhandledrejection", promise.get(), reason.get(), true);
        if (notHandled) {
            Runtime::from(ctx).host().diagnostic("unhandled-rejection", describeForHost(ctx, reason.get(), "Uncaught (in promise) "));
        }
        if (m_notifying.empty() || m_notifying.front().id != id) {
            continue;
        }
        Rejection& r = m_notifying.front();
        if (r.handled) {
            this->release(r);
        } else {
            if (m_outstanding.size() >= kMaxOutstanding) {
                this->release(m_outstanding.front());
                m_outstanding.pop_front();
            }
            m_outstanding.push_back(r);
        }
        m_notifying.pop_front();
    }
}

} // namespace wr
