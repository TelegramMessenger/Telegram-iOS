#include "Sources/Events/Event.h"

#include "Generated/Bindings.h"
#include "Sources/DOM/DOM.h"
#include "Sources/Events/EventTarget.h"
#include "Sources/Events/UIEvents.h"
#include "Sources/Host/HostState.h"
#include "Sources/Runtime/Runtime.h"

namespace wr {

double currentHighResTime(JSContext* ctx) {
    double now = Runtime::from(ctx).host().monotonicNow();
    // Relative to the window's time origin once there is a window (HR-Time); the raw clock before.
    HostState* host = HostState::find(ctx);
    return host ? now - host->timeOrigin() : now;
}

Event::Event(JSContext* ctx) : m_path(JSAllocator<JSValue>(JS_GetRuntime(ctx))), m_timeStamp(currentHighResTime(ctx)) {
    m_type.atom = JS_NewAtom(ctx, "");
}

Ref<Event> Event::construct(JSContext* ctx, String type, idl::EventInit init) {
    Ref<Event> event = create<Event>(ctx, idl::kEvent, ctx);
    event->constructWith(ctx, type, init.bubbles, init.cancelable, init.composed);
    return event;
}

void Event::constructWith(JSContext* ctx, const String& type, bool bubbles, bool cancelable, bool composed) {
    Atom atom = Atom::fromString(ctx, type);
    m_type.set(JS_GetRuntime(ctx), atom.release());
    m_initialized = true;
    m_bubbles = bubbles;
    m_cancelable = cancelable;
    m_composed = composed;
}

String Event::type(JSContext* ctx) {
    return String::fromAtom(ctx, m_type.atom);
}

EventTarget* Event::targetNode() const {
    return m_target.isUndefined() ? nullptr : static_cast<EventTarget*>(payloadOfKnown(m_target.value));
}

EventTarget* Event::currentTarget(JSContext*) {
    return m_currentTarget.isUndefined() ? nullptr : static_cast<EventTarget*>(payloadOfKnown(m_currentTarget.value));
}

std::vector<EventTarget*> Event::composedPath(JSContext* ctx) {
    // Without shadow trees the composed path is the whole path, the target first; empty when not dispatching.
    std::vector<EventTarget*> out;
    out.reserve(m_path.size());
    for (size_t i = 0; i < m_path.size(); i++) {
        out.push_back(&this->pathAt(i));
    }
    return out;
}

void Event::initEvent(JSContext* ctx, String type, bool bubbles, bool cancelable) {
    if (m_dispatching) {
        return;
    }
    Atom atom = Atom::fromString(ctx, type);
    this->initialize(ctx, atom.get(), bubbles, cancelable);
}

void Event::setTypeAtom(JSContext* ctx, JSAtom type) {
    m_type.set(JS_GetRuntime(ctx), JS_DupAtom(ctx, type));
}

void Event::initialize(JSContext* ctx, JSAtom type, bool bubbles, bool cancelable) {
    JSRuntime* rt = JS_GetRuntime(ctx);
    m_initialized = true;
    m_stopPropagation = false;
    m_stopImmediatePropagation = false;
    m_canceled = false;
    m_isTrusted = false;
    m_target.clear(rt);
    m_type.set(rt, JS_DupAtom(ctx, type));
    m_bubbles = bubbles;
    m_cancelable = cancelable;
}

void Event::setTarget(JSContext* ctx, EventTarget* target) {
    m_target.set(JS_GetRuntime(ctx), target ? JS_DupValue(ctx, target->object()) : JS_UNDEFINED);
}

void Event::setCurrentTarget(JSContext* ctx, EventTarget* target) {
    m_currentTarget.set(JS_GetRuntime(ctx), target ? JS_DupValue(ctx, target->object()) : JS_UNDEFINED);
}

EventTarget& Event::pathAt(size_t index) const {
    return *static_cast<EventTarget*>(payloadOfKnown(m_path[index]));
}

void Event::appendToPath(JSContext* ctx, EventTarget& target) {
    JSValue v = JS_DupValue(ctx, target.object());
    try {
        m_path.push_back(v);
    } catch (...) {
        JS_FreeValue(ctx, v);
        throw;
    }
}

void Event::clearPath(JSRuntime* rt) {
    for (JSValue v : m_path) {
        JS_FreeValueRT(rt, v);
    }
    m_path.clear();
}

void Event::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    m_target.mark(rt, mark);
    m_currentTarget.mark(rt, mark);
    for (JSValue v : m_path) {
        JS_MarkValue(rt, v, mark);
    }
}

void Event::dispose(JSRuntime* rt) {
    m_type.clear(rt);
    m_target.clear(rt);
    m_currentTarget.clear(rt);
    this->clearPath(rt);
}

Ref<CustomEvent> CustomEvent::construct(JSContext* ctx, String type, idl::CustomEventInit init) {
    Ref<CustomEvent> event = create<CustomEvent>(ctx, idl::kCustomEvent, ctx);
    event->constructWith(ctx, type, init.bubbles, init.cancelable, init.composed);
    event->m_detail.set(JS_GetRuntime(ctx), init.detail.newRef());
    return event;
}

void CustomEvent::initCustomEvent(JSContext* ctx, String type, bool bubbles, bool cancelable, Value detail) {
    if (this->dispatching()) {
        return;
    }
    Atom atom = Atom::fromString(ctx, type);
    this->initialize(ctx, atom.get(), bubbles, cancelable);
    m_detail.set(JS_GetRuntime(ctx), detail.newRef());
}

void CustomEvent::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    m_detail.mark(rt, mark);
    Event::trace(rt, mark);
}

void CustomEvent::dispose(JSRuntime* rt) {
    m_detail.clear(rt);
    Event::dispose(rt);
}

Ref<ErrorEvent> ErrorEvent::construct(JSContext* ctx, String type, idl::ErrorEventInit init) {
    Ref<ErrorEvent> event = create<ErrorEvent>(ctx, idl::kErrorEvent, ctx);
    event->constructWith(ctx, type, init.bubbles, init.cancelable, init.composed);
    event->setDetails(ctx, init.message, init.filename, init.lineno, init.colno, init.error ? init.error->get() : JS_UNDEFINED);
    return event;
}

void ErrorEvent::setDetails(JSContext* ctx, const String& message, const String& filename, uint32_t lineno, uint32_t colno, JSValueConst error) {
    JSRuntime* rt = JS_GetRuntime(ctx);
    m_message.set(rt, message.toJS(ctx));
    m_filename.set(rt, filename.toJS(ctx));
    m_lineno = lineno;
    m_colno = colno;
    m_error.set(rt, JS_DupValue(ctx, error));
}

void ErrorEvent::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    m_error.mark(rt, mark);
    Event::trace(rt, mark);
}

void ErrorEvent::dispose(JSRuntime* rt) {
    m_message.clear(rt);
    m_filename.clear(rt);
    m_error.clear(rt);
    Event::dispose(rt);
}

Ref<PromiseRejectionEvent> PromiseRejectionEvent::construct(JSContext* ctx, String type, idl::PromiseRejectionEventInit init) {
    Ref<PromiseRejectionEvent> event = create<PromiseRejectionEvent>(ctx, idl::kPromiseRejectionEvent, ctx);
    event->constructWith(ctx, type, init.bubbles, init.cancelable, init.composed);
    event->setDetails(ctx, init.promise.get(), init.reason ? init.reason->get() : JS_UNDEFINED);
    return event;
}

void PromiseRejectionEvent::setDetails(JSContext* ctx, JSValueConst promise, JSValueConst reason) {
    JSRuntime* rt = JS_GetRuntime(ctx);
    m_promise.set(rt, JS_DupValue(ctx, promise));
    m_reason.set(rt, JS_DupValue(ctx, reason));
}

void PromiseRejectionEvent::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    m_promise.mark(rt, mark);
    m_reason.mark(rt, mark);
    Event::trace(rt, mark);
}

void PromiseRejectionEvent::dispose(JSRuntime* rt) {
    m_promise.clear(rt);
    m_reason.clear(rt);
    Event::dispose(rt);
}

Ref<PageTransitionEvent> PageTransitionEvent::construct(JSContext* ctx, String type, idl::PageTransitionEventInit init) {
    Ref<PageTransitionEvent> event = create<PageTransitionEvent>(ctx, idl::kPageTransitionEvent, ctx);
    event->constructWith(ctx, type, init.bubbles, init.cancelable, init.composed);
    event->m_persisted = init.persisted;
    return event;
}

// DOM's createEvent (Document.h declares it): an uninitialized event of the interface the legacy name maps to. DOM's
// table, for the interfaces the runtime has (the UI events since M1d, Task 2).
Ref<Event> Document::createEvent(JSContext* ctx, String interface) {
    // Type "", a time stamp and isTrusted false come from the constructor; the initialized flag stays unset.
    if (interface.equalsIgnoringASCIICase("customevent")) {
        return create<CustomEvent>(ctx, idl::kCustomEvent, ctx);
    }
    if (interface.equalsIgnoringASCIICase("event") || interface.equalsIgnoringASCIICase("events") ||
        interface.equalsIgnoringASCIICase("htmlevents") || interface.equalsIgnoringASCIICase("svgevents")) {
        return create<Event>(ctx, idl::kEvent, ctx);
    }
    if (interface.equalsIgnoringASCIICase("focusevent")) {
        return create<FocusEvent>(ctx, idl::kFocusEvent, ctx);
    }
    if (interface.equalsIgnoringASCIICase("mouseevent") || interface.equalsIgnoringASCIICase("mouseevents")) {
        return create<MouseEvent>(ctx, idl::kMouseEvent, ctx);
    }
    if (interface.equalsIgnoringASCIICase("touchevent")) {
        return create<TouchEvent>(ctx, idl::kTouchEvent, ctx);
    }
    if (interface.equalsIgnoringASCIICase("uievent") || interface.equalsIgnoringASCIICase("uievents")) {
        return create<UIEvent>(ctx, idl::kUIEvent, ctx);
    }
    throw DOMError{"NotSupportedError", "The provided event type is not supported."};
}

} // namespace wr
