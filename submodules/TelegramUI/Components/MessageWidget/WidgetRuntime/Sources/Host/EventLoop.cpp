#include "Sources/Host/EventLoop.h"

#include <algorithm>
#include <new>

#include "Sources/Animation/AnimationState.h"
#include "Sources/Host/ErrorReporting.h"
#include "Sources/Host/HostState.h"
#include "Sources/Host/Window.h"
#include "Sources/Host/Scripts.h"
#include "Sources/Render/RenderTree.h"
#include "Sources/Support/Callbacks.h"
#include "Sources/Support/Work.h"

namespace wr {

namespace {

/// The scheduled heap's order: std's heap keeps the "greatest" at the front, so "greater" is "due earlier".
template <class T>
bool dueLater(const T& a, const T& b) {
    if (a.deadline != b.deadline) {
        return a.deadline > b.deadline;
    }
    return a.sequence > b.sequence;
}

/// QuickJS's HostPromiseRejectionTracker. track() is noexcept: nothing crosses into QuickJS.
void trackRejection(JSContext* ctx, JSValueConst promise, JSValueConst reason, bool isHandled, void* opaque) noexcept {
    static_cast<EventLoop*>(opaque)->rejections().track(ctx, promise, reason, isHandled);
}

/// charge(), with a stop made final: the budget refused the units, the runtime is latched and Aborted thrown.
void chargeOrStop(JSContext* ctx, uint64_t units) {
    try {
        charge(ctx, units);
    } catch (...) {
        abortForCaughtException(ctx);
    }
}

} // namespace

EventLoop::EventLoop(JSContext* ctx)
    : m_ctx(ctx),
      m_tasks(JSAllocator<QueuedTask>(JS_GetRuntime(ctx))),
      m_scheduled(JSAllocator<ScheduledTask>(JS_GetRuntime(ctx))),
      m_rejections(ctx),
      m_timers(ctx),
      m_frames(ctx) {
    JS_SetHostPromiseRejectionTracker(JS_GetRuntime(ctx), &trackRejection, this);
}

EventLoop::~EventLoop() {
    JS_SetHostPromiseRejectionTracker(JS_GetRuntime(m_ctx), nullptr, nullptr);
}

EventLoop& EventLoop::of(JSContext* ctx) {
    return HostState::of(ctx).loop();
}

template <class F>
bool EventLoop::guarded(F&& body) {
    Runtime& runtime = Runtime::from(m_ctx);
    try {
        body();
    } catch (const Aborted&) {
    } catch (const Thrown&) {
        // Native code a task ran threw with a JS exception pending (a charge, a failed conversion).
        try {
            reportTheException(m_ctx, JS_GetException(m_ctx));
        } catch (const Aborted&) {
        }
    } catch (const std::bad_alloc&) {
        runtime.stop(StopReason::Memory);
    } catch (...) {
        runtime.stop(StopReason::Internal);
    }
    return runtime.stopReason() == StopReason::None;
}

void EventLoop::advanceTime(double now) {
    m_now = std::max(m_now, now);
}

StepResult EventLoop::runNextTask(double now) {
    Runtime& runtime = Runtime::from(m_ctx);
    if (runtime.stopReason() != StopReason::None) {
        return StepResult::Stopped;
    }
    JS_UpdateStackTop(JS_GetRuntime(m_ctx));
    this->advanceTime(now);
    bool ran = false;
    this->guarded([&] {
        this->promoteDueTasks();
        if (m_tasks.empty()) {
            return;
        }
        Task task = std::move(m_tasks.front().task);
        m_tasks.pop_front();
        ran = true;
        chargeOrStop(m_ctx, work::kBindingCall);
        task.run(m_ctx);
        // A native task that mutated outside a binding call left its scripts pending (Ruling 6).
        HostState::of(m_ctx).scripts().preparePending(m_ctx);
    });
    if (ran) {
        this->guarded([&] { this->performMicrotaskCheckpoint(m_ctx); });
        // CSSOM View: evaluate media queries and report changes, then what the change listeners queued.
        this->guarded([&] { HostState::of(m_ctx).window().reportMediaChanges(m_ctx); });
        this->guarded([&] { this->performMicrotaskCheckpoint(m_ctx); });
        // Ruling 13: what the task and its microtasks changed is built, laid out, recorded and published. A stopped
        // widget's flush does nothing: the last published tree stays.
        this->guarded([&] {
            if (RenderTree* r = HostState::of(m_ctx).render()) {
                r->flush(m_ctx);
            }
        });
        this->deliverResizeObservations();
        this->guarded([&] { HostState::of(m_ctx).window().updateIntersectionObservations(m_ctx); });
        // SDK v1 §2.8: an area the step changed is committed to the host, last, so a write in the rendering update (a
        // media query's change listener, a ResizeObserver callback) is in it.
        this->guarded([&] { HostState::of(m_ctx).window().commitStorage(m_ctx); });
    }
    if (runtime.stopReason() != StopReason::None) {
        return StepResult::Stopped;
    }
    return ran ? StepResult::Ran : StepResult::Idle;
}

void EventLoop::deliverResizeObservations() {
    Window& window = HostState::of(m_ctx).window();
    for (uint64_t round = 0;; round++) {
        bool active = false;
        if (!this->guarded([&] { active = window.gatherResizeObservations(m_ctx); }) || !active) {
            m_resizeObservationsPending = false;
            return;
        }
        if (round == work::kResizeObserverRounds) {
            m_resizeObservationsPending = true;
            this->guarded([&] { window.reportResizeObserverLoop(m_ctx); });
            return;
        }
        if (!this->guarded([&] { window.broadcastResizeObservations(m_ctx); }) ||
            !this->guarded([&] { this->performMicrotaskCheckpoint(m_ctx); })) {
            return;
        }
        const bool flushed = this->guarded([&] {
            if (RenderTree* r = HostState::of(m_ctx).render()) {
                r->flush(m_ctx);
            }
        });
        if (!flushed) {
            return;
        }
    }
}

bool EventLoop::wantsAnimationFrame() const {
    if (Runtime::from(m_ctx).stopReason() != StopReason::None) {
        return false;
    }
    const animation::AnimationState* animations = animation::AnimationState::find(m_ctx);
    return !m_frames.empty() || m_resizeObservationsPending || (animations && animations->wantsFrame());
}

StepResult EventLoop::runAnimationFrame(double now) {
    Runtime& runtime = Runtime::from(m_ctx);
    if (runtime.stopReason() != StopReason::None) {
        return StepResult::Stopped;
    }
    JS_UpdateStackTop(JS_GetRuntime(m_ctx));
    this->advanceTime(now);
    // HTML: every callback of the frame gets the same timestamp, on the window's time origin.
    double timestamp = now - HostState::of(m_ctx).timeOrigin();
    bool ran = false;
    // HTML "update animations and send events" (Web Animations Level 1 §4.2.1), before the frame's callbacks: the
    // timelines take the frame's time, pending tasks and finished states settle, their promise reactions run, then the
    // queued animation events are dispatched.
    if (animation::AnimationState* animations = animation::AnimationState::find(m_ctx)) {
        this->guarded([&] { animations->updateAnimations(m_ctx, timestamp); });
        this->guarded([&] { this->performMicrotaskCheckpoint(m_ctx); });
        this->guarded([&] { animations->dispatchEvents(m_ctx); });
        this->guarded([&] { animations->release(m_ctx); });
    }
    this->guarded([&] {
        chargeOrStop(m_ctx, work::kBindingCall);
        ran = m_frames.run(m_ctx, timestamp);
    });
    this->guarded([&] { this->performMicrotaskCheckpoint(m_ctx); });
    this->guarded([&] { HostState::of(m_ctx).window().reportMediaChanges(m_ctx); });
    this->guarded([&] { this->performMicrotaskCheckpoint(m_ctx); });
    // Ruling 13: HTML's "update the rendering" comes after the frame's callbacks and their microtasks.
    this->guarded([&] {
        if (RenderTree* r = HostState::of(m_ctx).render()) {
            r->flush(m_ctx);
        }
    });
    this->deliverResizeObservations();
    this->guarded([&] { HostState::of(m_ctx).window().updateIntersectionObservations(m_ctx); });
    this->guarded([&] { HostState::of(m_ctx).window().commitStorage(m_ctx); });
    if (runtime.stopReason() != StopReason::None) {
        return StepResult::Stopped;
    }
    return ran ? StepResult::Ran : StepResult::Idle;
}

bool EventLoop::hasRunnableTask(double now) const {
    if (Runtime::from(m_ctx).stopReason() != StopReason::None) {
        return false;
    }
    return !m_tasks.empty() || (!m_scheduled.empty() && m_scheduled.front().deadline <= now);
}

std::optional<double> EventLoop::nextTimerDeadline() const {
    if (Runtime::from(m_ctx).stopReason() != StopReason::None || m_scheduled.empty()) {
        return std::nullopt;
    }
    return m_scheduled.front().deadline;
}

void EventLoop::promoteDueTasks() {
    while (!m_scheduled.empty() && m_scheduled.front().deadline <= m_now) {
        chargeOrStop(m_ctx, work::kNodeVisit);
        std::pop_heap(m_scheduled.begin(), m_scheduled.end(), dueLater<ScheduledTask>);
        ScheduledTask due = std::move(m_scheduled.back());
        m_scheduled.pop_back();
        m_tasks.push_back(QueuedTask{due.source, std::move(due.task)});
    }
}

void EventLoop::queueTask(TaskSource source, Task task) {
    charge(m_ctx, work::kNodeVisit);
    m_tasks.push_back(QueuedTask{source, std::move(task)});
}

uint64_t EventLoop::queueTaskAt(double deadline, TaskSource source, Task task) {
    charge(m_ctx, work::kNodeVisit);
    uint64_t id = m_nextScheduledId++;
    m_scheduled.push_back(ScheduledTask{deadline, m_nextSequence++, id, source, std::move(task)});
    std::push_heap(m_scheduled.begin(), m_scheduled.end(), dueLater<ScheduledTask>);
    return id;
}

bool EventLoop::cancelScheduled(uint64_t id) {
    // The scan and the heap's rebuild each visit every scheduled task: charged before either.
    charge(m_ctx, work::kNodeVisit * uint64_t(m_scheduled.size()));
    for (size_t i = 0; i < m_scheduled.size(); i++) {
        if (m_scheduled[i].id != id) {
            continue;
        }
        m_scheduled.erase(m_scheduled.begin() + long(i));
        std::make_heap(m_scheduled.begin(), m_scheduled.end(), dueLater<ScheduledTask>);
        return true;
    }
    return false;
}

void EventLoop::performMicrotaskCheckpoint(JSContext* ctx) {
    Runtime& runtime = Runtime::from(ctx);
    if (runtime.stopReason() != StopReason::None) {
        throw Aborted{};
    }
    if (m_performingCheckpoint) {
        return;
    }
    m_performingCheckpoint = true;
    // A microtask is not a timer task: HTML's nesting level is that of the task running, and here that is the microtask.
    int nesting = m_timerNestingLevel;
    m_timerNestingLevel = 0;
    struct Restore {
        EventLoop& loop;
        int nesting;
        ~Restore() {
            loop.m_performingCheckpoint = false;
            loop.m_timerNestingLevel = nesting;
        }
    } restore{*this, nesting};
    JSRuntime* rt = JS_GetRuntime(ctx);
    while (JS_IsJobPending(rt)) {
        chargeOrStop(ctx, work::kBindingCall);
        JSContext* jobContext = ctx;
        if (JS_ExecutePendingJob(rt, &jobContext) < 0) {
            // A microtask (or a promise job) threw: report it and go on; a fatal one aborts the step.
            reportTheException(jobContext, JS_GetException(jobContext));
        }
        if (runtime.stopReason() != StopReason::None) {
            // A job can return normally on a runtime it stopped: QuickJS turns some stops into a promise rejection
            // (VENDOR.md entry 8), and the tracker latches a failed allocation.
            throw Aborted{};
        }
    }
    try {
        m_rejections.notify(ctx);
    } catch (...) {
        abortForCaughtException(ctx);
    }
    if (runtime.stopReason() != StopReason::None) {
        throw Aborted{};
    }
}

} // namespace wr
