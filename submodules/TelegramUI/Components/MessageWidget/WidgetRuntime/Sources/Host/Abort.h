// AbortController and AbortSignal (V5a plan, Task 8; DOM §3.1–3.2).
#pragma once

#include <optional>

#include "Sources/Events/EventTarget.h"
#include "Sources/Support/Bindings.h"

namespace wr {

class AbortSignal final : public EventTarget {
public:
    AbortSignal() = default;
    static Ref<AbortSignal> abort(JSContext* ctx, std::optional<Value> reason);
    /// Aborted with a TimeoutError DOMException when the loop's time reaches now + `milliseconds` (a timer task).
    static Ref<AbortSignal> timeout(JSContext* ctx, uint64_t milliseconds);
    bool aborted(JSContext*) const { return m_aborted; }
    Value reason(JSContext* ctx);
    void throwIfAborted(JSContext* ctx);
    /// DOM's "signal abort": once; the reason (an AbortError DOMException when absent), then an abort event.
    void signalAbort(JSContext* ctx, std::optional<Value> reason);
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

private:
    bool m_aborted = false;
    Held m_reason;
};

class AbortController final : public PlatformObject {
public:
    AbortController() = default;
    static Ref<AbortController> construct(JSContext* ctx);
    AbortSignal* signal(JSContext*);
    void abort(JSContext* ctx, std::optional<Value> reason);
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

private:
    Held m_signal;
};

} // namespace wr
