// DOM's Event and the M1b subclasses (HTML's ErrorEvent, PromiseRejectionEvent, PageTransitionEvent). The flags are
// DOM's ("stop propagation", "canceled", "initialized", "dispatch", …); the path is the invocation targets dispatch
// visits, counted and traced while it runs.
#pragma once

#include <cstdint>
#include <vector>

#include "Generated/Bindings.h"
#include "Sources/Support/Allocator.h"
#include "Sources/Support/Bindings.h"

namespace wr {

class EventTarget;

/// HR-Time "current high resolution time": the host's monotonic clock minus the window's time origin (the raw clock in
/// a runtime with no window).
double currentHighResTime(JSContext* ctx);

class Event : public PlatformObject {
public:
    enum Phase : uint16_t { None = 0, Capturing = 1, AtTarget = 2, Bubbling = 3 };

    explicit Event(JSContext* ctx);

    // Event
    static Ref<Event> construct(JSContext* ctx, String type, idl::EventInit init);
    String type(JSContext* ctx);
    EventTarget* target(JSContext*) { return this->targetNode(); }
    EventTarget* srcElement(JSContext*) { return this->targetNode(); }
    EventTarget* currentTarget(JSContext*);
    std::vector<EventTarget*> composedPath(JSContext* ctx);
    uint16_t eventPhase(JSContext*) { return m_phase; }
    void stopPropagation(JSContext*) { m_stopPropagation = true; }
    bool cancelBubble(JSContext*) { return m_stopPropagation; }
    void setCancelBubble(JSContext*, bool value) {
        if (value) {
            m_stopPropagation = true;
        }
    }
    void stopImmediatePropagation(JSContext*) {
        m_stopPropagation = true;
        m_stopImmediatePropagation = true;
    }
    bool bubbles(JSContext*) { return m_bubbles; }
    bool cancelable(JSContext*) { return m_cancelable; }
    bool returnValue(JSContext*) { return !m_canceled; }
    void setReturnValue(JSContext*, bool value) {
        if (!value) {
            this->setCanceledFlag();
        }
    }
    void preventDefault(JSContext*) { this->setCanceledFlag(); }
    bool defaultPrevented(JSContext*) { return m_canceled; }
    bool composed(JSContext*) { return m_composed; }
    bool isTrusted(JSContext*) { return m_isTrusted; }
    double timeStamp(JSContext*) { return m_timeStamp; }
    void initEvent(JSContext* ctx, String type, bool bubbles, bool cancelable);

    // Native (DOM's flags; dispatch is Sources/Events/Dispatch.h)
    JSAtom typeAtom() const { return m_type.atom; }
    void setTypeAtom(JSContext* ctx, JSAtom type);
    /// DOM "initialize": the initialized flag set, the propagation and canceled flags cleared, isTrusted false, no
    /// target, and the type, bubbles and cancelable given.
    void initialize(JSContext* ctx, JSAtom type, bool bubbles, bool cancelable);
    void setComposed(bool composed) { m_composed = composed; }
    bool initialized() const { return m_initialized; }
    void setInitialized(bool value) { m_initialized = value; }
    bool dispatching() const { return m_dispatching; }
    void setDispatching(bool value) { m_dispatching = value; }
    bool stopPropagationFlag() const { return m_stopPropagation; }
    bool stopImmediatePropagationFlag() const { return m_stopImmediatePropagation; }
    void clearPropagationFlags() {
        m_stopPropagation = false;
        m_stopImmediatePropagation = false;
    }
    bool canceledFlag() const { return m_canceled; }
    void setInPassiveListener(bool value) { m_inPassiveListener = value; }
    /// The one trusted-flag setter (fireEvent, reportTheException, boot).
    void setIsTrusted(bool value) { m_isTrusted = value; }
    void setPhase(uint16_t phase) { m_phase = phase; }
    EventTarget* targetNode() const;
    void setTarget(JSContext* ctx, EventTarget* target);
    void setCurrentTarget(JSContext* ctx, EventTarget* target);
    /// DOM "path", without shadow trees: the invocation targets, the target first.
    size_t pathSize() const { return m_path.size(); }
    EventTarget& pathAt(size_t index) const;
    void appendToPath(JSContext* ctx, EventTarget& target);
    void clearPath(JSRuntime* rt);
    /// DOM "dispatch" step: a MouseEvent whose type is click (M1d) has activation behaviour to look for.
    virtual bool isActivationClick(JSContext*) const { return false; }

    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

protected:
    /// The constructors' "inner event creation steps": initialized, and the dictionary's members.
    void constructWith(JSContext* ctx, const String& type, bool bubbles, bool cancelable, bool composed);

private:
    void setCanceledFlag() {
        if (m_cancelable && !m_inPassiveListener) {
            m_canceled = true;
        }
    }

    HeldAtom m_type;
    Held m_target;
    Held m_currentTarget;
    Vector<JSValue> m_path;
    double m_timeStamp = 0;
    uint16_t m_phase = None;
    bool m_bubbles = false;
    bool m_cancelable = false;
    bool m_composed = false;
    bool m_isTrusted = false;
    bool m_initialized = false;
    bool m_dispatching = false;
    bool m_stopPropagation = false;
    bool m_stopImmediatePropagation = false;
    bool m_canceled = false;
    bool m_inPassiveListener = false;
};

class CustomEvent : public Event {
public:
    explicit CustomEvent(JSContext* ctx) : Event(ctx) {}
    static Ref<CustomEvent> construct(JSContext* ctx, String type, idl::CustomEventInit init);
    Value detail(JSContext* ctx) { return Value::dup(ctx, m_detail.isUndefined() ? JS_NULL : m_detail.value); }
    void initCustomEvent(JSContext* ctx, String type, bool bubbles, bool cancelable, Value detail);
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

private:
    Held m_detail;
};

class ErrorEvent : public Event {
public:
    explicit ErrorEvent(JSContext* ctx) : Event(ctx) {}
    static Ref<ErrorEvent> construct(JSContext* ctx, String type, idl::ErrorEventInit init);
    String message(JSContext* ctx) { return stringOf(ctx, m_message); }
    String filename(JSContext* ctx) { return stringOf(ctx, m_filename); }
    uint32_t lineno(JSContext*) { return m_lineno; }
    uint32_t colno(JSContext*) { return m_colno; }
    Value error(JSContext* ctx) { return Value::dup(ctx, m_error.value); }
    /// HTML "report the exception" (Task 9) fills these.
    void setDetails(JSContext* ctx, const String& message, const String& filename, uint32_t lineno, uint32_t colno, JSValueConst error);
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

private:
    static String stringOf(JSContext* ctx, const Held& held) {
        return held.isUndefined() ? String::fromUTF8(ctx, "") : String::adopt(ctx, JS_DupValue(ctx, held.value));
    }
    Held m_message;
    Held m_filename;
    uint32_t m_lineno = 0;
    uint32_t m_colno = 0;
    Held m_error;
};

class PromiseRejectionEvent : public Event {
public:
    explicit PromiseRejectionEvent(JSContext* ctx) : Event(ctx) {}
    static Ref<PromiseRejectionEvent> construct(JSContext* ctx, String type, idl::PromiseRejectionEventInit init);
    Value promise(JSContext* ctx) { return Value::dup(ctx, m_promise.value); }
    Value reason(JSContext* ctx) { return Value::dup(ctx, m_reason.value); }
    /// HTML "notify about rejected promises" (Task 9) fills these.
    void setDetails(JSContext* ctx, JSValueConst promise, JSValueConst reason);
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

private:
    Held m_promise;
    Held m_reason;
};

class PageTransitionEvent : public Event {
public:
    explicit PageTransitionEvent(JSContext* ctx) : Event(ctx) {}
    static Ref<PageTransitionEvent> construct(JSContext* ctx, String type, idl::PageTransitionEventInit init);
    bool persisted(JSContext*) { return m_persisted; }

private:
    bool m_persisted = false;
};

} // namespace wr
