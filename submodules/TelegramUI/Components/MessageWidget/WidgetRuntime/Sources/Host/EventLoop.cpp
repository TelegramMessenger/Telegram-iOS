#include "Sources/Host/EventLoop.h"

#include <algorithm>
#include <new>
#include <string>
#include <utility>
#include <vector>

#include "Sources/Animation/AnimationState.h"
#include "Sources/Host/ErrorReporting.h"
#include "Sources/Host/HostState.h"
#include "Sources/Host/Window.h"
#include "Sources/Host/Scripts.h"
#include "Sources/Render/RenderTree.h"
#include "Sources/Support/Callbacks.h"

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

/// Resize Observer: the rounds of delivery one rendering update makes (deliver, lay out, gather) before it reports
/// "ResizeObserver loop completed with undelivered notifications." and leaves the rest for the next one (V3b, Task 2).
constexpr uint64_t kResizeObserverRounds = 4;

constexpr TaskKind kKinds[] = {TaskKind::Boot,     TaskKind::Event,  TaskKind::Visibility, TaskKind::Timer, TaskKind::Frame,
                               TaskKind::Viewport, TaskKind::Resize, TaskKind::Theme,      TaskKind::Bridge, TaskKind::SafeArea};

} // namespace

std::string_view kindName(TaskKind kind) {
    switch (kind) {
    case TaskKind::Boot:
        return "boot";
    case TaskKind::Event:
        return "event";
    case TaskKind::Visibility:
        return "visibility";
    case TaskKind::Timer:
        return "timer";
    case TaskKind::Frame:
        return "frame";
    case TaskKind::Viewport:
        return "viewport";
    case TaskKind::Resize:
        return "resize";
    case TaskKind::Theme:
        return "theme";
    case TaskKind::Bridge:
        return "bridge";
    case TaskKind::SafeArea:
        return "safeArea";
    }
    return "boot";
}

EventLoop::EventLoop(JSContext* ctx)
    : m_ctx(ctx),
      m_tasks(JSAllocator<QueuedTask>(JS_GetRuntime(ctx))),
      m_deferred(JSAllocator<QueuedTask>(JS_GetRuntime(ctx))),
      m_jsBudget(Runtime::from(ctx).cpuLimits().cpuLimitMs, Runtime::from(ctx).cpuLimits().cpuQuotaMs,
                 Runtime::from(ctx).cpuLimits().cpuQuotaWindowMs, Runtime::from(ctx).cpuLimits().cpuKillAfterMs),
      m_hostBudget(Runtime::from(ctx).cpuLimits().cpuLimitMs, Runtime::from(ctx).cpuLimits().mainThreadQuotaMs,
                   Runtime::from(ctx).cpuLimits().cpuQuotaWindowMs, 0),
      m_scheduled(JSAllocator<ScheduledTask>(JS_GetRuntime(ctx))),
      m_rejections(ctx),
      m_timers(ctx),
      m_frames(ctx) {
    JS_SetHostPromiseRejectionTracker(JS_GetRuntime(ctx), &trackRejection, this);
    Runtime::from(ctx).setQuotaLeft([this] { return Runtime::from(m_ctx).cpuLimits().cpuQuotaMs - m_jsBudget.used(this->quotaNow()); });
}

EventLoop::~EventLoop() {
    JS_SetHostPromiseRejectionTracker(JS_GetRuntime(m_ctx), nullptr, nullptr);
    Runtime::from(m_ctx).setQuotaLeft(nullptr);
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
        // Native code a task ran threw with a JS exception pending (a failed conversion or call into JS, an allocation
        // QuickJS refused).
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

double EventLoop::quotaNow() const {
    return std::max(m_now, Runtime::from(m_ctx).host().monotonicNow());
}

void EventLoop::beginTurn(double now) {
    this->advanceTime(now);
    this->releaseDeferred();
}

void EventLoop::releaseDeferred() {
    if (!m_retryAt || m_now < *m_retryAt) {
        return;
    }
    m_retryAt.reset();
    m_frameDeferred = false;
    while (!m_deferred.empty()) {
        m_tasks.push_front(std::move(m_deferred.back()));
        m_deferred.pop_back();
    }
}

std::optional<EventLoop::Admission> EventLoop::admit(TaskKind kind) {
    Runtime& runtime = Runtime::from(m_ctx);
    const CpuLimits& cpu = runtime.cpuLimits();
    const std::string_view name = kindName(kind);
    const double now = this->quotaNow();
    // Upstream's dispatch: a deferrable task waits for both windows; the slice is the JS quota's.
    const twidget::CpuDecision js = m_jsBudget.decide(name, now);
    const twidget::CpuDecision host = m_hostBudget.decide(name, now);
    if (js.run && host.run) {
        return Admission{js.sliceMs};
    }
    if (m_jsBudget.shouldKill(now)) {
        runtime.stopForThrottling(m_jsBudget.throttledFor(now));
        return std::nullopt;
    }
    const double retry = std::max(js.run ? 0.0 : js.retryAt, host.run ? 0.0 : host.retryAt);
    m_retryAt = m_retryAt ? std::min(*m_retryAt, retry) : retry;
    m_throttledSteps++;
    m_throttledSinceReport[size_t(kind)]++;
    if (now - m_lastThrottleReport >= 1000) {
        m_lastThrottleReport = now;
        // Upstream's text: the kinds in name order, then the window that deferred (the JS quota's when both did).
        std::vector<std::pair<std::string_view, uint32_t>> counts;
        for (TaskKind k : kKinds) {
            if (uint32_t n = m_throttledSinceReport[size_t(k)]) {
                counts.emplace_back(kindName(k), n);
            }
        }
        std::sort(counts.begin(), counts.end());
        m_throttledSinceReport.fill(0);
        std::string parts;
        for (const auto& [k, n] : counts) {
            if (!parts.empty()) {
                parts += ", ";
            }
            parts += std::to_string(n) + " " + std::string(k) + (n == 1 ? "" : "s");
        }
        const std::string window =
            js.run ? std::to_string(int(m_hostBudget.used(now))) + " ms of the " + std::to_string(int(cpu.mainThreadQuotaMs)) + " ms per " +
                         std::to_string(int(cpu.cpuQuotaWindowMs)) + " ms main-thread budget used by layout queries and ops"
                   : std::to_string(int(m_jsBudget.used(now))) + " ms of the " + std::to_string(int(cpu.cpuQuotaMs)) + " ms per " +
                         std::to_string(int(cpu.cpuQuotaWindowMs)) + " ms budget used";
        runtime.host().diagnostic("cpu-throttled", "deferred " + parts + ": " + window);
    }
    return std::nullopt;
}

void EventLoop::beginStep(TaskKind kind, TaskSource source, const Admission& admission) {
    Runtime& runtime = Runtime::from(m_ctx);
    m_stepKind = kind;
    m_stepOpsStart = runtime.totalOps();
    m_stepCanvasCommandsStart = runtime.totalCanvasCommands();
    const std::string_view where = kind == TaskKind::Boot && source == TaskSource::Script ? "script" : std::string_view();
    runtime.beginSlice(kindName(kind), admission.sliceMs, where);
}

void EventLoop::endStep() {
    Runtime& runtime = Runtime::from(m_ctx);
    const Runtime::SliceUsage usage = runtime.endSlice();
    const std::string_view name = kindName(m_stepKind);
    // At the step's end, as upstream's task() records: a long step's time lands in the buckets its end is in.
    const double end = this->quotaNow();
    m_jsBudget.record(name, usage.jsMs, end);
    // What the step cost the host, as upstream counts it (taskQueryMs_ + taskOpsCostMs_): its layout queries' time and
    // the modelled cost of its operations and canvas commands. Our renderer's other flushes are measured (kept out of
    // the slice, in cpuMsTotal) but charged to no window, as upstream's renderer's work is not.
    const double ops = double(runtime.totalOps() - m_stepOpsStart);
    const double commands = double(runtime.totalCanvasCommands() - m_stepCanvasCommandsStart);
    m_hostBudget.record(name, usage.queryMs + twidget::CpuBudget::opsCostMs(ops, commands), end);
    m_queryMsTotal += usage.queryMs;
    m_cpuMsTotal += usage.jsMs + usage.renderMs;
    if (m_stepIsBootLink) {
        m_bootLinkCpuMsTotal += usage.jsMs + usage.renderMs;
        m_stepIsBootLink = false;
    }
    m_jsMsTotal += usage.jsMs;
    m_largestStepMs = std::max(m_largestStepMs, usage.jsMs + usage.renderMs);
    m_stepKind = TaskKind::Boot;
}

void EventLoop::flushForHostChange(TaskKind kind) {
    Runtime& runtime = Runtime::from(m_ctx);
    RenderTree* render = HostState::of(m_ctx).render();
    if (!render || runtime.stopReason() != StopReason::None) {
        return;
    }
    // A host entry, as a step is: it may run on another thread than the one that made the runtime.
    JS_UpdateStackTop(JS_GetRuntime(m_ctx));
    if (runtime.inSlice()) {
        // Inside a step (a test's script): the step's slice governs.
        render->flush(m_ctx);
        return;
    }
    // A step of its own, admitted by no window: its operations a batch, its follow-ups of its kind, its cost recorded
    // as a step's (the fix waves' M-2).
    runtime.startBatch();
    this->beginStep(kind, TaskSource::Rendering, Admission{runtime.cpuLimits().cpuLimitMs});
    struct End {
        EventLoop& loop;
        ~End() { loop.endStep(); }
    } end{*this};
    render->flush(m_ctx);
}

bool EventLoop::runNow(TaskKind kind, double now, const std::function<void()>& body) {
    Runtime& runtime = Runtime::from(m_ctx);
    if (runtime.stopReason() != StopReason::None) {
        return false;
    }
    runtime.startBatch();
    JS_UpdateStackTop(JS_GetRuntime(m_ctx));
    this->beginTurn(now);
    std::optional<Admission> admission;
    this->guarded([&] { admission = this->admit(kind); });
    if (!admission) {
        return false;
    }
    this->beginStep(kind, TaskSource::UserInteraction, *admission);
    struct End {
        EventLoop& loop;
        ~End() { loop.endStep(); }
    } end{*this};
    body();
    return true;
}

StepResult EventLoop::runNextTask(double now) {
    Runtime& runtime = Runtime::from(m_ctx);
    if (runtime.stopReason() != StopReason::None) {
        return StepResult::Stopped;
    }
    // limit.batch (widget-sandbox v0.3.0): a task's DOM changes are one batch.
    runtime.startBatch();
    JS_UpdateStackTop(JS_GetRuntime(m_ctx));
    this->beginTurn(now);
    std::optional<QueuedTask> next;
    std::optional<Admission> admission;
    bool deferred = false;
    this->guarded([&] {
        this->promoteDueTasks();
        // The oldest task the windows admit; the deferrable ones before it wait apart, so an event behind them runs.
        while (!m_tasks.empty()) {
            QueuedTask task = std::move(m_tasks.front());
            m_tasks.pop_front();
            admission = this->admit(task.kind);
            if (admission) {
                next.emplace(std::move(task));
                return;
            }
            m_deferred.push_back(std::move(task));
            deferred = true;
            if (runtime.stopReason() != StopReason::None) {
                return;
            }
        }
    });
    if (!next) {
        if (runtime.stopReason() != StopReason::None) {
            return StepResult::Stopped;
        }
        return deferred ? StepResult::Deferred : StepResult::Idle;
    }
    this->beginStep(next->kind, next->source, *admission);
    this->guarded([&] {
        Task task = std::move(next->task);
        next.reset();
        task.run(m_ctx);
        // A native task that mutated outside a binding call left its scripts pending (Ruling 6).
        HostState::of(m_ctx).scripts().preparePending(m_ctx);
    });
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
    this->endStep();
    if (runtime.stopReason() != StopReason::None) {
        return StepResult::Stopped;
    }
    return StepResult::Ran;
}

void EventLoop::deliverResizeObservations() {
    Window& window = HostState::of(m_ctx).window();
    for (uint64_t round = 0;; round++) {
        bool active = false;
        if (!this->guarded([&] { active = window.gatherResizeObservations(m_ctx); }) || !active) {
            m_resizeObservationsPending = false;
            return;
        }
        if (round == kResizeObserverRounds) {
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
    if (Runtime::from(m_ctx).stopReason() != StopReason::None || m_frameDeferred) {
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
    // limit.batch (widget-sandbox v0.3.0): a task's DOM changes are one batch.
    runtime.startBatch();
    JS_UpdateStackTop(JS_GetRuntime(m_ctx));
    this->beginTurn(now);
    if (m_frameDeferred) {
        return StepResult::Deferred;
    }
    std::optional<Admission> admission;
    this->guarded([&] { admission = this->admit(TaskKind::Frame); });
    if (!admission) {
        if (runtime.stopReason() != StopReason::None) {
            return StepResult::Stopped;
        }
        // Upstream keeps one deferred frame however many are asked for.
        m_frameDeferred = m_retryAt.has_value();
        return StepResult::Deferred;
    }
    this->beginStep(TaskKind::Frame, TaskSource::Rendering, *admission);
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
    this->endStep();
    if (runtime.stopReason() != StopReason::None) {
        return StepResult::Stopped;
    }
    return ran ? StepResult::Ran : StepResult::Idle;
}

bool EventLoop::hasRunnableTask(double now) const {
    if (Runtime::from(m_ctx).stopReason() != StopReason::None) {
        return false;
    }
    return !m_tasks.empty() || (!m_scheduled.empty() && m_scheduled.front().deadline <= now) ||
           (this->hasDeferredWork() && m_retryAt && *m_retryAt <= now);
}

std::optional<double> EventLoop::nextTimerDeadline() const {
    if (Runtime::from(m_ctx).stopReason() != StopReason::None) {
        return std::nullopt;
    }
    std::optional<double> next = this->retryAt();
    if (!m_scheduled.empty()) {
        next = next ? std::min(*next, m_scheduled.front().deadline) : m_scheduled.front().deadline;
    }
    return next;
}

std::optional<double> EventLoop::retryAt() const {
    return this->hasDeferredWork() ? m_retryAt : std::nullopt;
}

void EventLoop::promoteDueTasks() {
    while (!m_scheduled.empty() && m_scheduled.front().deadline <= m_now) {
        std::pop_heap(m_scheduled.begin(), m_scheduled.end(), dueLater<ScheduledTask>);
        ScheduledTask due = std::move(m_scheduled.back());
        m_scheduled.pop_back();
        m_tasks.push_back(QueuedTask{due.source, due.kind, std::move(due.task)});
    }
}

void EventLoop::queueTask(TaskSource source, Task task, std::optional<TaskKind> kind) {
    m_tasks.push_back(QueuedTask{source, kind.value_or(m_stepKind), std::move(task)});
}

uint64_t EventLoop::queueTaskAt(double deadline, TaskSource source, Task task, std::optional<TaskKind> kind) {
    uint64_t id = m_nextScheduledId++;
    m_scheduled.push_back(ScheduledTask{deadline, m_nextSequence++, id, source, kind.value_or(m_stepKind), std::move(task)});
    std::push_heap(m_scheduled.begin(), m_scheduled.end(), dueLater<ScheduledTask>);
    return id;
}

bool EventLoop::cancelScheduled(uint64_t id) {
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
