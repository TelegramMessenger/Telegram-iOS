// The HTML event loop (https://html.spec.whatwg.org/#event-loops), driven by the host: it never reads a clock. Each
// step takes the host's monotonic `now` (milliseconds) and the work limit the host set on the Runtime (M1b plan,
// Ruling 7). Waits, demotion and pacing stay the host's.
#pragma once

#include <cstdint>
#include <deque>
#include <optional>

#include "Sources/Host/AnimationFrames.h"
#include "Sources/Host/PromiseRejections.h"
#include "Sources/Host/Task.h"
#include "Sources/Host/Timers.h"
#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Allocator.h"

namespace wr {

enum class StepResult : uint8_t { Ran, Idle, Stopped };
enum class TaskSource : uint8_t { DOMManipulation, Timer, UserInteraction, Networking, Rendering, Script };

class EventLoop {
public:
    explicit EventLoop(JSContext* ctx);
    ~EventLoop();
    EventLoop(const EventLoop&) = delete;
    EventLoop& operator=(const EventLoop&) = delete;

    static EventLoop& of(JSContext* ctx);

    // The host's steps. A stopped runtime runs nothing and answers Stopped.
    /// Promotes every scheduled task due at `now` in (deadline, sequence) order, runs the oldest task and performs a
    /// microtask checkpoint.
    StepResult runNextTask(double now);
    bool hasRunnableTask(double now) const;
    /// The earliest scheduled task's deadline, or nothing.
    std::optional<double> nextTimerDeadline() const;
    /// Moves the loop's time to `now`; it never moves back.
    void advanceTime(double now);
    /// The `now` of the step running (or of the last one): what timers are scheduled against.
    double currentTime() const { return m_now; }
    /// Whether a frame would run a callback: the host schedules one when it is true.
    bool wantsAnimationFrame() const;
    /// HTML "run the animation frame callbacks" for a frame at the host's monotonic `now`, then a microtask checkpoint.
    /// Ran when a callback ran.
    StepResult runAnimationFrame(double now);

    // The runtime's side.
    /// Charges work::kNodeVisit. Throws Thrown at the limit.
    void queueTask(TaskSource source, Task task);
    /// Queues `task` when the loop's time reaches `deadline`. An id > 0. Charges work::kNodeVisit.
    uint64_t queueTaskAt(double deadline, TaskSource source, Task task);
    /// Removes a scheduled task not yet promoted; false otherwise. Charges work::kNodeVisit per scheduled task, before
    /// the scan and the heap's rebuild.
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
    /// most work::kResizeObserverRounds rounds; past them the loop error, the rest left for the next update.
    void deliverResizeObservations();
    /// A capped delivery left observations: the next frame delivers them (wantsAnimationFrame).
    bool m_resizeObservationsPending = false;
    struct QueuedTask {
        TaskSource source;
        Task task;
    };
    struct ScheduledTask {
        double deadline;
        uint64_t sequence;
        uint64_t id;
        TaskSource source;
        Task task;
    };
    /// Charged per task promoted; a stop is latched and thrown as Aborted.
    void promoteDueTasks();
    /// Runs `body`, turning what escapes into the stop latch or a report; whether the runtime still runs.
    template <class F>
    bool guarded(F&& body);

    JSContext* m_ctx;
    std::deque<QueuedTask, JSAllocator<QueuedTask>> m_tasks;
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
