// The window's map of active timers and HTML's timer initialization steps
// (https://html.spec.whatwg.org/#timer-initialisation-steps). Each timer waits as a scheduled task of the event loop,
// so timers due together run in (deadline, sequence) order (M1b plan, Ruling 7).
#pragma once

#include <cstdint>
#include <variant>
#include <vector>

#include "quickjs.h"
#include "Sources/Support/Allocator.h"
#include "Sources/Support/Callbacks.h"
#include "Sources/Support/Values.h"

namespace wr {

class Timers {
public:
    /// Live animation frame callbacks (M1b plan, Ruling 8's table bound). Live timers are the runtime's
    /// Limits::timers (widget-sandbox v0.3.0: 64 under strict, 256 under compat).
    static constexpr size_t kMaxLive = 256;

    explicit Timers(JSContext* ctx);
    ~Timers();
    Timers(const Timers&) = delete;
    Timers& operator=(const Timers&) = delete;

    /// setTimeout (repeat false) and setInterval (repeat true): an id > 0. Throws RangeError past kMaxLive. A timer it
    /// could not schedule (an allocation failed) is not kept.
    int32_t start(JSContext* ctx, std::variant<String, Callback> handler, int32_t timeout, std::vector<Value> arguments, bool repeat);
    /// clearTimeout and clearInterval (the ids are shared): removes the entry, releasing what it holds.
    void clear(JSContext* ctx, int32_t id);
    size_t liveCount() const { return m_active.size(); }
    /// The timer task: HTML's step 10. `handle` is the unique handle the task was made for; a re-armed or cleared
    /// timer's old task finds a different one (or none) and does nothing.
    void fire(JSContext* ctx, int32_t id, uint64_t handle, int taskNesting);

private:
    /// Tests only (TimerTests): moves the id counter near INT32_MAX, which no test can reach by making timers.
    friend struct TimersTestAccess;

    struct ActiveTimer {
        explicit ActiveTimer(JSRuntime* rt) : arguments(JSAllocator<Held>(rt)) {}
        int32_t id = 0;
        uint64_t handle = 0;
        bool repeat = false;
        /// After the clamp: an interval re-arms with it.
        int32_t timeout = 0;
        /// The loop's scheduled-task id while it waits, else 0.
        uint64_t scheduled = 0;
        Held function;
        Held source;
        Vector<Held> arguments;
    };
    /// HTML step 2: an id > 0 not already in the map, from the counter, which wraps from INT32_MAX to 1. At most
    /// kMaxLive ids are in use, so at most kMaxLive + 1 are tried.
    int32_t takeId(JSContext* ctx);
    /// HTML steps 3–14 for the entry `id`, which exists: clamps, takes a new unique handle, schedules the task.
    void schedule(JSContext* ctx, int32_t id, int32_t requested);
    /// The entry, or nullptr.
    ActiveTimer* find(JSContext* ctx, int32_t id);
    void erase(JSContext* ctx, int32_t id);
    /// Releases the entry at `index` and removes it.
    void removeAt(size_t index);
    void release(ActiveTimer& timer);

    JSRuntime* m_rt;
    Vector<ActiveTimer> m_active;
    /// The next id takeId tries.
    int32_t m_nextId = 1;
    uint64_t m_nextHandle = 1;
};

} // namespace wr
