#include "Sources/Host/Abort.h"

#include "Generated/Bindings.h"
#include "Sources/Events/Dispatch.h"
#include "Sources/Host/EventLoop.h"
#include "Sources/Host/Task.h"
#include "Sources/Support/Errors.h"

namespace wr {

namespace {

/// A new DOMException named `name`, as a value (thrown and taken back at once).
Value domException(JSContext* ctx, const char* name, const char* message) {
    JS_ThrowDOMException(ctx, name, "%s", message);
    return Value::adopt(ctx, JS_GetException(ctx));
}

} // namespace

Ref<AbortSignal> AbortSignal::abort(JSContext* ctx, std::optional<Value> reason) {
    Ref<AbortSignal> signal = create<AbortSignal>(ctx, idl::kAbortSignal);
    // A new signal has no listener: the event would reach nothing, so only the state is set.
    signal->m_aborted = true;
    Value value = reason && !JS_IsUndefined(reason->get()) ? std::move(*reason)
                                                           : domException(ctx, "AbortError", "signal is aborted without reason");
    signal->m_reason.set(JS_GetRuntime(ctx), value.release());
    return signal;
}

Ref<AbortSignal> AbortSignal::timeout(JSContext* ctx, uint64_t milliseconds) {
    Ref<AbortSignal> signal = create<AbortSignal>(ctx, idl::kAbortSignal);
    EventLoop& loop = EventLoop::of(ctx);
    const double deadline = loop.currentTime() + double(milliseconds);
    // The task holds the signal until it runs.
    Value held = Value::dup(ctx, signal->object());
    loop.queueTaskAt(deadline, TaskSource::Timer, makeTask(ctx, [held = std::move(held)](JSContext* ctx) {
        auto* target = static_cast<AbortSignal*>(payloadOfKnown(held.get()));
        target->signalAbort(ctx, domException(ctx, "TimeoutError", "signal timed out"));
    }), TaskKind::Timer);
    return signal;
}

Value AbortSignal::reason(JSContext* ctx) {
    return Value::dup(ctx, m_reason.value);
}

void AbortSignal::throwIfAborted(JSContext* ctx) {
    if (m_aborted) {
        JS_Throw(ctx, JS_DupValue(ctx, m_reason.value));
        throw Thrown{};
    }
}

void AbortSignal::signalAbort(JSContext* ctx, std::optional<Value> reason) {
    if (m_aborted) {
        return;
    }
    m_aborted = true;
    Value value = reason && !JS_IsUndefined(reason->get()) ? std::move(*reason)
                                                           : domException(ctx, "AbortError", "signal is aborted without reason");
    m_reason.set(JS_GetRuntime(ctx), value.release());
    Atom type = Atom::fromUTF8(ctx, "abort");
    fireEvent(ctx, *this, type.get());
}

void AbortSignal::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    m_reason.mark(rt, mark);
    EventTarget::trace(rt, mark);
}

void AbortSignal::dispose(JSRuntime* rt) {
    m_reason.clear(rt);
    EventTarget::dispose(rt);
}

Ref<AbortController> AbortController::construct(JSContext* ctx) {
    Ref<AbortController> controller = create<AbortController>(ctx, idl::kAbortController);
    controller->m_signal.set(JS_GetRuntime(ctx), create<AbortSignal>(ctx, idl::kAbortSignal).release());
    return controller;
}

AbortSignal* AbortController::signal(JSContext*) {
    return static_cast<AbortSignal*>(payloadOfKnown(m_signal.value));
}

void AbortController::abort(JSContext* ctx, std::optional<Value> reason) {
    this->signal(ctx)->signalAbort(ctx, std::move(reason));
}

void AbortController::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    m_signal.mark(rt, mark);
}

void AbortController::dispose(JSRuntime* rt) {
    m_signal.clear(rt);
}

} // namespace wr
