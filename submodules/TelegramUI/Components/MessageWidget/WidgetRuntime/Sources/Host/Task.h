// A task of the event loop: a move-only owner of its work, which lives in QuickJS's allocator so a queued task counts
// toward the widget's memory limit (Global Constraints).
#pragma once

#include <new>
#include <type_traits>
#include <utility>

#include "quickjs.h"
#include "Sources/Support/Errors.h"

namespace wr {

class TaskBody {
public:
    virtual ~TaskBody() = default;
    virtual void run(JSContext* ctx) = 0;
};

/// Destroying a Task destroys its body and what the body captured. Tasks are destroyed by the loop, after they run or
/// with HostState (which goes before the context), so a body may capture context-bound references (Ref, Value). Those
/// are counted references the loop holds as roots: no gc_mark reports them, so they live until the task is destroyed.
class Task {
public:
    Task() = default;
    Task(JSRuntime* rt, TaskBody* body) noexcept : m_rt(rt), m_body(body) {}
    Task(Task&& other) noexcept : m_rt(other.m_rt), m_body(other.m_body) { other.m_body = nullptr; }
    Task& operator=(Task&& other) noexcept {
        if (this != &other) {
            this->reset();
            m_rt = other.m_rt;
            m_body = other.m_body;
            other.m_body = nullptr;
        }
        return *this;
    }
    Task(const Task&) = delete;
    Task& operator=(const Task&) = delete;
    ~Task() { this->reset(); }

    explicit operator bool() const { return m_body != nullptr; }
    void run(JSContext* ctx) { m_body->run(ctx); }

private:
    void reset() noexcept {
        if (m_body) {
            m_body->~TaskBody();
            js_free_rt(m_rt, m_body);
            m_body = nullptr;
        }
    }

    JSRuntime* m_rt = nullptr;
    TaskBody* m_body = nullptr;
};

/// A task that calls `f(ctx)`. Throws Thrown at the memory limit.
template <class F>
Task makeTask(JSContext* ctx, F&& f) {
    using Fn = std::decay_t<F>;
    struct Body final : TaskBody {
        explicit Body(Fn&& fn) : fn(std::move(fn)) {}
        void run(JSContext* ctx) override { fn(ctx); }
        Fn fn;
    };
    void* memory = js_malloc(ctx, sizeof(Body));
    if (!memory) {
        throw Thrown{};
    }
    Body* body;
    try {
        body = new (memory) Body(Fn(std::forward<F>(f)));
    } catch (...) {
        js_free(ctx, memory);
        throw;
    }
    return Task(JS_GetRuntime(ctx), body);
}

} // namespace wr
