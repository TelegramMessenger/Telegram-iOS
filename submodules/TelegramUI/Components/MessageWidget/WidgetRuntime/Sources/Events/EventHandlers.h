// HTML's event handlers (https://html.spec.whatwg.org/#event-handler-attributes): each EventTarget's event handler
// map, the IDL attributes' getter and setter, content attribute bodies compiled lazily, and the event handler
// processing algorithm registered as a listener when a handler is activated.
#pragma once

#include "quickjs.h"
#include "Sources/Support/Allocator.h"
#include "Sources/Support/Values.h"

namespace wr {

class Element;
class EventTarget;

/// One handler of a target. The references are counted; EventHandlerMap::trace reports them.
struct EventHandlerEntry {
    HeldAtom type;
    /// undefined: null. A JS string when `uncompiled`: the content attribute's body. Otherwise the callback object.
    Held value;
    bool uncompiled = false;
    /// For an element's handler, the element whose content attribute gave the uncompiled body: its scope, and whose node
    /// document must be the window's for it to compile. A Window's handler (a body's window-reflecting one) has none.
    Held scopeElement;
    /// Once activated: the event handler processing function, registered as a listener.
    Held listener;
};

/// A target's handlers, one entry per event type that ever had a value; an entry stays until the target is disposed.
/// An entry is valid until the next findOrAdd, so anything that can run script looks it up again afterwards.
class EventHandlerMap {
public:
    explicit EventHandlerMap(JSRuntime* rt) : m_entries(JSAllocator<EventHandlerEntry>(rt)) {}
    EventHandlerEntry* find(JSContext* ctx, JSAtom type);
    /// Throws std::bad_alloc at the memory limit.
    EventHandlerEntry& findOrAdd(JSContext* ctx, JSAtom type);
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const;
    void dispose(JSRuntime* rt);

private:
    Vector<EventHandlerEntry> m_entries;
};

// Each of these throws as a binding's body does (Thrown, std::bad_alloc), and Aborted when script it runs (compiling a
// body) stops the widget.
/// The IDL attribute's getter ("get the current value of the event handler", compiling a body): a new reference to
/// the callback object, or null.
JSValue getEventHandler(JSContext* ctx, EventTarget& target, JSAtom type);
/// The IDL attribute's setter ([LegacyTreatNonObjectAsNull]: a non-object deactivates).
void setEventHandler(JSContext* ctx, EventTarget& target, JSAtom type, JSValueConst value);
/// A content attribute's new body: stored uncompiled (with `scopeElement` as its scope, unless `owner` is the window),
/// then the handler is activated. Runs no script.
void setEventHandlerBody(JSContext* ctx, EventTarget& owner, JSAtom type, const String& body, Element& scopeElement);
/// HTML "deactivate an event handler": the value becomes null and the listener is removed. Runs no script.
void clearEventHandler(JSContext* ctx, EventTarget& owner, JSAtom type);
/// HTML "determine the target of an event handler": the target whose map holds `type`'s handler. That is the window for
/// a body (or frameset) element's window-reflecting handlers, and `target` otherwise. nullptr when such an element has
/// no window: its node document is not the window's, or the runtime has no host state (a DOM-only runtime).
EventTarget* eventHandlerOwner(JSContext* ctx, EventTarget& target, JSAtom type);

} // namespace wr
