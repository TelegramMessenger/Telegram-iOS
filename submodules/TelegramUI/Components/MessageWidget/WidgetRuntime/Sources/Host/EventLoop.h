// The HTML event loop (https://html.spec.whatwg.org/#event-loops), driven by the host. Each step takes the host's
// monotonic `now`, in milliseconds (M1b plan, Ruling 7). Waits, demotion and pacing stay the host's.
//
// widget-sandbox's CPU quota (the CPU-clock limits plan, Task 3; upstream's sandbox_engine.cpp `dispatch`): every step
// has a kind, and before it runs, two twidget::CpuBudgets decide at `now`: the JS quota (cpuQuotaMs of the widget's JS
// time per window) and the main-thread window (mainThreadQuotaMs of the layout queries' time and the modelled cost of
// the step's operations, as upstream counts it; our renderer's other flushes are charged to no window). A deferrable
// kind past either is not run: the task leaves the FIFO for the deferred list (order kept; a frame is one flag, so
// frames collapse) until the retry time, when the list returns to the FIFO's front, and the steps behind it (an event)
// still run. A step that runs gets the JS quota's slice (Runtime::beginSlice) and its times are recorded after it.
#pragma once

#include <array>
#include <cstdint>
#include <deque>
#include <functional>
#include <optional>
#include <string_view>

#include "Sources/Host/AnimationFrames.h"
#include "Sources/Host/PromiseRejections.h"
#include "Sources/Host/Task.h"
#include "Sources/Host/Timers.h"
#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Allocator.h"
#include "twidget/cpu_budget.h"

namespace wr {

/// Deferred: nothing ran because every runnable task, or the frame, waits for the CPU windows (retryAt()).
enum class StepResult : uint8_t { Ran, Idle, Stopped, Deferred };
/// Script: a task that runs a script (a boot's parser or deferred script, an async one's execution); a boot step of it
/// is `script` in a CPU stop's message, as upstream's pumpScripts names it.
enum class TaskSource : uint8_t { DOMManipulation, Timer, UserInteraction, Networking, Rendering, Script };
/// Upstream's task kinds (CpuBudget): boot, event and visibility always run; the others wait while a window is spent.
/// A width change's own layout is a Resize step (`flushForHostChange`), so its follow-ups are Resize; the widget's
/// task after it (its media changes, ResizeObserver) is Viewport. SafeArea (widget-sandbox v0.4.0) is the client's
/// content safe area changing, which upstream never defers.
enum class TaskKind : uint8_t { Boot, Event, Visibility, Timer, Frame, Viewport, Resize, Theme, Bridge, SafeArea };
/// Upstream's string for `kind` ("boot", "event", …).
std::string_view kindName(TaskKind kind);

class EventLoop {
public:
    explicit EventLoop(JSContext* ctx);
    ~EventLoop();
    EventLoop(const EventLoop&) = delete;
    EventLoop& operator=(const EventLoop&) = delete;

    static EventLoop& of(JSContext* ctx);

    // The host's steps. A stopped runtime runs nothing and answers Stopped.
    /// Returns the deferred tasks to the FIFO's front once `now` reaches their retry time, promotes every scheduled task
    /// due at `now` in (deadline, sequence) order, and runs the oldest task the CPU windows admit and a microtask
    /// checkpoint; the ones they do not are deferred on the way (Deferred when none ran).
    StepResult runNextTask(double now);
    /// A task is queued or due, or deferred work's retry time has come (a deferred frame's included).
    bool hasRunnableTask(double now) const;
    /// The earliest scheduled task's deadline or deferred work's retry time, or nothing.
    std::optional<double> nextTimerDeadline() const;
    /// When deferred work (tasks, the frame) may run again; nothing when none waits.
    std::optional<double> retryAt() const;
    /// Moves the loop's time to `now`; it never moves back.
    void advanceTime(double now);
    /// The `now` of the step running (or of the last one): what timers are scheduled against.
    double currentTime() const { return m_now; }
    /// Whether a frame would run a callback: the host schedules one when it is true. False while a frame is deferred:
    /// the host's wake at the retry time (nextTimerDeadline) brings it back.
    bool wantsAnimationFrame() const;
    /// HTML "run the animation frame callbacks" for a frame at the host's monotonic `now`, then a microtask checkpoint.
    /// Ran when a callback ran; Deferred when the CPU windows defer the frame (one flag for every frame asked for).
    StepResult runAnimationFrame(double now);
    /// A width, theme or reduced-motion change lays out at the call, outside any step (upstream's renderer lays out
    /// without the widget's thread, and charges no window for it). The flush is a step of `kind` that no window defers:
    /// the whole cpuLimitMs (script its style-change step runs is the widget's: the final review's C1), an operations
    /// batch of its own, its follow-ups of its kind, and endStep's records (the script's time to the JS quota, its
    /// queries and operations to the main-thread window, the flush's render time to cpuMsTotal and, as every step's, to
    /// largestStepMs: a host change's whole relayout is a step there, the renderer's work included).
    void flushForHostChange(TaskKind kind);

    // Statistics (the stress kit's runner): never read by a decision.
    /// Steps deferred by either window.
    uint64_t throttledSteps() const { return m_throttledSteps; }
    /// The layout queries' time over every step (SliceUsage::queryMs).
    double queryMsTotal() const { return m_queryMsTotal; }
    /// The CPU time of every step so far, our renderer's included, and of the host changes' flushes: each measured within
    /// its own step on the thread that ran it, so a difference across steps on different threads means what it says
    /// (the core's demotion reads it around a drain).
    double cpuMsTotal() const { return m_cpuMsTotal; }
    /// Of cpuMsTotal, the boot lifecycle links' steps (its scripts, DOMContentLoaded, the load): the boot's own work,
    /// which the core does not count toward demotion for its first two slices in all, wherever it runs (the boot task
    /// stops once it has spent a slice, and the core's wakes run the rest). Follow-ups the links queue are not links.
    double bootLinkCpuMsTotal() const { return m_bootLinkCpuMsTotal; }
    /// The step running now is a boot lifecycle link (Boot.cpp's queueLink).
    void markBootLinkStep() { m_stepIsBootLink = true; }
    /// The widget's JS time over every step (SliceUsage::jsMs: what the JS quota records), and the most one step took
    /// (its JS and our renderer's).
    double jsMsTotal() const { return m_jsMsTotal; }
    double largestStepMs() const { return m_largestStepMs; }

    /// `body` as one step of `kind` at `now`, ahead of the queue, on the windows' slice with its times recorded: tests'
    /// scripts (WRSession's evaluateForTesting, "one event-kind task"). False when the runtime has stopped or the windows
    /// defer the kind; then nothing ran.
    bool runNow(TaskKind kind, double now, const std::function<void()>& body);

    // The runtime's side.
    /// Queues `task` of `kind`; without one, the kind of the step running (what a task causes is part of it, as
    /// upstream runs it inside its delivery), Boot outside any step. Throws std::bad_alloc at the memory limit.
    void queueTask(TaskSource source, Task task, std::optional<TaskKind> kind = std::nullopt);
    /// Queues `task` when the loop's time reaches `deadline`. An id > 0. Throws std::bad_alloc at the memory limit.
    uint64_t queueTaskAt(double deadline, TaskSource source, Task task, std::optional<TaskKind> kind = std::nullopt);
    /// Removes a scheduled task not yet promoted; false otherwise.
    bool cancelScheduled(uint64_t id);
    /// HTML "perform a microtask checkpoint": runs QuickJS's jobs until none is left, reporting a job's exception, then
    /// notifies about rejected promises. Re-entry is a no-op (HTML's flag). Throws only Aborted, and always once the
    /// runtime has stopped: on entry, after a job that stopped it, and for a native failure in its own work (C1: it never
    /// returns normally after a latch, so a script's caller sees the stop).
    void performMicrotaskCheckpoint(JSContext* ctx);

    /// HTML's timer nesting level of the task running: set by timer tasks (Task 10), 0 inside a microtask.
    int timerNestingLevel() const { return m_timerNestingLevel; }
    void setTimerNestingLevel(int level) { m_timerNestingLevel = level; }
    /// HTML's error reporting mode of the global (ErrorReporting.cpp).
    bool reportingError() const { return m_reportingError; }
    void setReportingError(bool reporting) { m_reportingError = reporting; }
    PromiseRejections& rejections() { return m_rejections; }
    Timers& timers() { return m_timers; }
    AnimationFrames& animationFrames() { return m_frames; }
    /// Live timers and animation frame callbacks: Timers::kMaxLive bounds them together (Ruling 8).
    size_t liveCallbackCount() const { return m_timers.liveCount() + m_frames.liveCount(); }

private:
    /// Resize Observer, after the flush that ends a task or a frame: gather, broadcast, run the microtasks, lay out, at
    /// most kResizeObserverRounds (4) rounds; past them the loop error, the rest left for the next update.
    void deliverResizeObservations();
    /// A capped delivery left observations: the next frame delivers them (wantsAnimationFrame).
    bool m_resizeObservationsPending = false;
    struct QueuedTask {
        TaskSource source;
        TaskKind kind;
        Task task;
    };
    struct ScheduledTask {
        double deadline;
        uint64_t sequence;
        uint64_t id;
        TaskSource source;
        TaskKind kind;
        Task task;
    };
    /// What a step of `kind` may run with at quotaNow(): the JS quota's slice; nothing when a window defers it
    /// (recorded, reported, the retry time kept) or when the throttling kills the widget.
    struct Admission {
        double sliceMs;
    };
    /// The windows' time, upstream's nowMs() at dispatch and at a task's end: the host's clock, never before the turn's
    /// (m_now stays the drain's, for the timers).
    double quotaNow() const;
    std::optional<Admission> admit(TaskKind kind);
    /// The step's slice begins: kind, its operations and canvas commands so far. A boot step of a script task is
    /// `script` in a CPU stop's message.
    void beginStep(TaskKind kind, TaskSource source, const Admission& admission);
    /// The step's slice ends: its JS time to the quota, its render time and modelled operations to the host window.
    void endStep();
    /// A step's or a frame's start: the loop's time, deferred work released, the host-change flushes recorded.
    void beginTurn(double now);
    /// Deferred work whose retry time m_now has reached goes back: the tasks to the FIFO's front in order, the frame
    /// to the host.
    void releaseDeferred();
    bool hasDeferredWork() const { return !m_deferred.empty() || m_frameDeferred; }
    /// The scheduled tasks due at m_now go to the FIFO, in deadline order. Throws std::bad_alloc at the memory limit.
    void promoteDueTasks();
    /// Runs `body`, turning what escapes into the stop latch or a report; whether the runtime still runs.
    template <class F>
    bool guarded(F&& body);

    JSContext* m_ctx;
    std::deque<QueuedTask, JSAllocator<QueuedTask>> m_tasks;
    /// Tasks a window deferred, in their order.
    std::deque<QueuedTask, JSAllocator<QueuedTask>> m_deferred;
    bool m_frameDeferred = false;
    std::optional<double> m_retryAt;
    twidget::CpuBudget m_jsBudget;
    twidget::CpuBudget m_hostBudget;
    /// The kind of the step running; Boot outside steps.
    TaskKind m_stepKind = TaskKind::Boot;
    uint64_t m_stepOpsStart = 0;
    uint64_t m_stepCanvasCommandsStart = 0;
    uint64_t m_throttledSteps = 0;
    double m_queryMsTotal = 0;
    double m_cpuMsTotal = 0;
    double m_bootLinkCpuMsTotal = 0;
    bool m_stepIsBootLink = false;
    double m_jsMsTotal = 0;
    double m_largestStepMs = 0;
    /// The throttle diagnostic: at most one a second, counting the deferrals since the last (upstream's
    /// lastThrottleDiag_, throttledSinceDiag_).
    double m_lastThrottleReport = -1e300;
    std::array<uint32_t, 10> m_throttledSinceReport{};
    /// A binary heap (std::push_heap) whose front is due first.
    Vector<ScheduledTask> m_scheduled;
    PromiseRejections m_rejections;
    Timers m_timers;
    AnimationFrames m_frames;
    double m_now = 0;
    uint64_t m_nextSequence = 1;
    uint64_t m_nextScheduledId = 1;
    int m_timerNestingLevel = 0;
    bool m_performingCheckpoint = false;
    bool m_reportingError = false;
};

} // namespace wr
