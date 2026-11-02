#include "Sources/Host/Timers.h"

#include <cstdint>
#include <string>

#include "Sources/DOM/DOM.h"
#include "Sources/Host/ErrorReporting.h"
#include "Sources/Host/EventLoop.h"
#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Errors.h"

namespace wr {

Timers::Timers(JSContext* ctx) : m_rt(JS_GetRuntime(ctx)), m_active(JSAllocator<ActiveTimer>(m_rt)) {}

Timers::~Timers() {
    for (ActiveTimer& timer : m_active) {
        this->release(timer);
    }
}

void Timers::release(ActiveTimer& timer) {
    timer.function.clear(m_rt);
    timer.source.clear(m_rt);
    for (Held& argument : timer.arguments) {
        argument.clear(m_rt);
    }
    timer.arguments.clear();
}

Timers::ActiveTimer* Timers::find(JSContext* ctx, int32_t id) {
    for (ActiveTimer& timer : m_active) {
        if (timer.id == id) {
            return &timer;
        }
    }
    return nullptr;
}

int32_t Timers::start(JSContext* ctx, std::variant<String, Callback> handler, int32_t timeout, std::vector<Value> arguments, bool repeat) {
    if (this->liveCount() >= Runtime::from(ctx).limits().timers) {
        throw RangeError{"too many timers"};
    }
    // Step 2.
    int32_t id = this->takeId(ctx);
    m_active.emplace_back(m_rt);
    try {
        ActiveTimer& timer = m_active.back();
        timer.id = id;
        timer.repeat = repeat;
        if (auto* fn = std::get_if<Callback>(&handler)) {
            timer.function.value = fn->newRef();
        } else {
            timer.source.value = std::get<String>(handler).toJS(ctx);
        }
        for (Value& argument : arguments) {
            timer.arguments.emplace_back();
            timer.arguments.back().value = argument.release();
        }
        this->schedule(ctx, id, timeout);
        return id;
    } catch (...) {
        // Never scheduled, so no task will fire it: drop it, whether the failure stops the widget (an allocation
        // refused at the memory limit: quickjs-ng changes 9 and 10 make it uncatchable) or the script can catch it. No
        // JS ran since the emplace: the entry is the last.
        this->release(m_active.back());
        m_active.pop_back();
        throw;
    }
}

int32_t Timers::takeId(JSContext* ctx) {
    for (;;) {
        int32_t candidate = m_nextId;
        // Compared before it is incremented: the counter never passes INT32_MAX.
        m_nextId = candidate == INT32_MAX ? 1 : candidate + 1;
        if (!this->find(ctx, candidate)) {
            return candidate;
        }
    }
}

void Timers::schedule(JSContext* ctx, int32_t id, int32_t requested) {
    EventLoop& loop = EventLoop::of(ctx);
    ActiveTimer* timer = this->find(ctx, id);
    // Step 3: the nesting level of the task running, if a timer task (0 otherwise; 0 in a microtask).
    int nesting = loop.timerNestingLevel();
    // Steps 4–5.
    int32_t timeout = requested < 0 ? 0 : requested;
    if (nesting > 5 && timeout < 4) {
        timeout = 4;
    }
    timer->timeout = timeout;
    // Steps 8–9: a new unique handle; an older task for this id finds it changed.
    uint64_t handle = m_nextHandle++;
    timer->handle = handle;
    // Steps 11–14.
    int taskNesting = nesting + 1;
    timer->scheduled = loop.queueTaskAt(loop.currentTime() + double(timeout), TaskSource::Timer, makeTask(ctx, [id, handle, taskNesting](JSContext* ctx) {
        EventLoop::of(ctx).timers().fire(ctx, id, handle, taskNesting);
    }), TaskKind::Timer);
}

void Timers::fire(JSContext* ctx, int32_t id, uint64_t handle, int taskNesting) {
    // What escapes this task normally stops the widget: std::bad_alloc or a stop in the callback or the script already
    // has; a js_malloc refused at the memory limit latched Memory as it failed (quickjs-ng change 9). A stopped
    // widget's table is only released: an entry left behind is still held once, and freed with the table. A failed
    // re-arm is dropped all the same (below).
    ActiveTimer* timer = this->find(ctx, id);
    if (!timer || timer->handle != handle) {
        return;
    }
    timer->scheduled = 0;
    EventLoop& loop = EventLoop::of(ctx);
    struct Nesting {
        EventLoop& loop;
        int saved;
        ~Nesting() { loop.setTimerNestingLevel(saved); }
    } nesting{loop, loop.timerNestingLevel()};
    loop.setTimerNestingLevel(taskNesting);
    Value global = Value::adopt(ctx, JS_GetGlobalObject(ctx));
    if (!JS_IsUndefined(timer->function.value)) {
        // The callback may clear this timer, which frees the entry: call through references of our own.
        Value fn = Value::dup(ctx, timer->function.value);
        Vector<Value> arguments{JSAllocator<Value>(m_rt)};
        Vector<JSValueConst> argv{JSAllocator<JSValueConst>(m_rt)};
        for (const Held& argument : timer->arguments) {
            arguments.push_back(Value::dup(ctx, argument.value));
        }
        for (const Value& argument : arguments) {
            argv.push_back(argument.get());
        }
        invokeWithReport(ctx, fn.get(), global.get(), int(argv.size()), argv.data());
    } else {
        // HTML: create a classic script from the string and run it (its exception is reported by runScript).
        String source = String::adopt(ctx, JS_DupValue(ctx, timer->source.value));
        std::string code = source.utf8();
        String url = DOMState::of(ctx).document().URL(ctx);
        std::string filename = url.utf8();
        Runtime::from(ctx).runScript(code, filename.c_str(), false);
    }
    // Steps 6–7: the callback may have cleared this timer, or cleared it and started another under a new id.
    timer = this->find(ctx, id);
    if (!timer || timer->handle != handle) {
        return;
    }
    if (timer->repeat) {
        // Step 8: the timer initialization steps again, with this id; the nesting level is still this task's. Not
        // re-armed, no task would fire it again: drop it, as start drops a timer it could not schedule. No JS runs in
        // schedule, so the entry keeps its index.
        size_t index = size_t(timer - m_active.data());
        try {
            this->schedule(ctx, id, timer->timeout);
        } catch (...) {
            this->removeAt(index);
            throw;
        }
    } else {
        this->erase(ctx, id);
    }
}

void Timers::clear(JSContext* ctx, int32_t id) {
    ActiveTimer* timer = this->find(ctx, id);
    if (!timer) {
        return;
    }
    if (timer->scheduled) {
        EventLoop::of(ctx).cancelScheduled(timer->scheduled);
    }
    this->erase(ctx, id);
}

void Timers::erase(JSContext* ctx, int32_t id) {
    for (size_t i = 0; i < m_active.size(); i++) {
        if (m_active[i].id == id) {
            this->removeAt(i);
            return;
        }
    }
}

void Timers::removeAt(size_t index) {
    this->release(m_active[index]);
    m_active.erase(m_active.begin() + long(index));
}

} // namespace wr
