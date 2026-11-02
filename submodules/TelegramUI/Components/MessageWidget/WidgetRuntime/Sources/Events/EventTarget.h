// DOM's EventTarget: the listener list every node, the window and `new EventTarget()` have. The list is allocated on
// the first add and counted against the memory limit. Its entries are shared with the clones dispatch takes, so a
// listener removed mid-dispatch is seen as removed (DOM "removed").
#pragma once

#include <cstdint>
#include <optional>
#include <utility>
#include <variant>

#include "Generated/Bindings.h"
#include "Sources/Support/Allocator.h"
#include "Sources/Support/Bindings.h"
#include "Sources/Support/Callbacks.h"

namespace wr {

class Event;
class EventHandlerMap;

/// DOM "event listener". Never copied: a target's list and dispatch's clones share it through ListenerRef, and it is
/// freed through the runtime's allocator when the last holder lets go.
struct EventListener {
    EventListener() = default;
    EventListener(const EventListener&) = delete;
    EventListener& operator=(const EventListener&) = delete;

    uint32_t refs = 1;
    HeldAtom type;
    /// The callback interface value (a function, or an object whose handleEvent is read at each call). Counted; the
    /// owning target's trace reports it while the listener is in its list.
    HeldCallback callback;
    bool capture = false;
    bool passive = false;
    bool once = false;
    bool removed = false;
};

/// One counted hold on an EventListener. Copying holds it again; the last release frees it.
class ListenerRef {
public:
    ListenerRef() = default;
    /// Takes over the listener's first reference.
    ListenerRef(JSRuntime* rt, EventListener* adopted) : m_rt(rt), m_listener(adopted) {}
    ListenerRef(const ListenerRef& other) : m_rt(other.m_rt), m_listener(other.m_listener) {
        if (m_listener) {
            m_listener->refs++;
        }
    }
    ListenerRef(ListenerRef&& other) noexcept : m_rt(other.m_rt), m_listener(other.m_listener) { other.m_listener = nullptr; }
    ListenerRef& operator=(ListenerRef other) noexcept {
        std::swap(m_rt, other.m_rt);
        std::swap(m_listener, other.m_listener);
        return *this;
    }
    ~ListenerRef();
    EventListener* get() const { return m_listener; }
    EventListener* operator->() const { return m_listener; }
    EventListener& operator*() const { return *m_listener; }

private:
    JSRuntime* m_rt = nullptr;
    EventListener* m_listener = nullptr;
};

class EventTarget : public PlatformObject {
public:
    EventTarget() = default;

    // EventTarget
    static Ref<EventTarget> construct(JSContext* ctx);
    void addEventListener(JSContext* ctx, String type, std::optional<CallbackInterface> callback, std::variant<idl::AddEventListenerOptions, bool> options);
    void removeEventListener(JSContext* ctx, String type, std::optional<CallbackInterface> callback, std::variant<idl::EventListenerOptions, bool> options);
    /// Throws DOMError InvalidStateError when `event` is being dispatched or was never initialized; otherwise dispatches
    /// it, untrusted (Sources/Events/Dispatch.h).
    bool dispatchEvent(JSContext* ctx, Event* event);

    // Native.
    /// DOM "add an event listener", options flattened: nothing when an equal listener (type, callback, capture) is
    /// there. A missing `passive` takes the default passive value. A new listener's type is noted in the DOM's
    /// ListenedTypes before the listener is made.
    void addListener(JSContext* ctx, JSAtom type, JSValueConst callback, bool capture, std::optional<bool> passive, bool once);
    /// Removes the listener equal to (type, callback, capture), if any.
    void removeListener(JSContext* ctx, JSAtom type, JSValueConst callback, bool capture);
    /// DOM "remove an event listener": the removed flag, and out of the list.
    void removeListenerEntry(JSContext* ctx, EventListener& listener);
    /// The listener list, or nullptr before the first add. Dispatch clones it.
    const Vector<ListenerRef>* listeners() const { return m_listeners; }
    /// Whether a listener of `type` is in the list.
    bool hasListenersFor(JSContext* ctx, JSAtom type) const;
    /// DOM "default passive value" for a listener of `type` on this target (Node and Window override).
    virtual bool defaultPassive(JSContext* ctx, JSAtom type) { return false; }
    /// DOM "get the parent": the next target in an event path (Node: its parent; Document: the window, see there).
    /// Runs no script and does constant work.
    virtual EventTarget* getTheParent(JSContext* ctx, Event& event) { return nullptr; }
    /// DOM's activation behaviour hooks, for a MouseEvent click (M1d fills them; none in M1b).
    virtual bool hasActivationBehavior(JSContext*) { return false; }
    virtual void legacyPreActivationBehavior(JSContext* ctx) {}
    virtual void activationBehavior(JSContext* ctx, Event& event) {}
    virtual void legacyCanceledActivationBehavior(JSContext* ctx) {}

    /// HTML's event handler map, made on first use (EventHandlers.h); nullptr until then.
    EventHandlerMap* eventHandlers() const { return m_eventHandlers; }
    /// Throws Thrown at the memory limit.
    EventHandlerMap& ensureEventHandlers(JSContext* ctx);

    /// Subclasses that override these call them.
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

protected:
    /// After a listener went into the list or out of it (MediaQueryList keeps itself alive through the window while it
    /// has a change listener). The target may be released inside: nothing of it is touched after the call.
    virtual void listenersChanged(JSContext* ctx) {}

private:
    Vector<ListenerRef>& ensureListeners(JSContext* ctx);

    Vector<ListenerRef>* m_listeners = nullptr;
    EventHandlerMap* m_eventHandlers = nullptr;
};

} // namespace wr
