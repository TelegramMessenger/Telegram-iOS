#include "Sources/Events/EventHandlers.h"

#include <optional>
#include <string>

#include "Generated/Bindings.h"
#include "Sources/DOM/DOM.h"
#include "Sources/Events/Event.h"
#include "Sources/Host/EventHandlerAttributes.h"
#include "Sources/Host/HostState.h"
#include "Sources/Host/Window.h"
#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Callbacks.h"

namespace wr {

EventHandlerEntry* EventHandlerMap::find(JSContext* ctx, JSAtom type) {
    for (EventHandlerEntry& entry : m_entries) {
        if (entry.type.atom == type) {
            return &entry;
        }
    }
    return nullptr;
}

EventHandlerEntry& EventHandlerMap::findOrAdd(JSContext* ctx, JSAtom type) {
    if (EventHandlerEntry* entry = this->find(ctx, type)) {
        return *entry;
    }
    // The entry first: growing the list can fail at the memory limit, and then nothing is held yet.
    m_entries.emplace_back();
    EventHandlerEntry& entry = m_entries.back();
    entry.type.atom = JS_DupAtom(ctx, type);
    return entry;
}

void EventHandlerMap::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    for (const EventHandlerEntry& entry : m_entries) {
        entry.value.mark(rt, mark);
        entry.scopeElement.mark(rt, mark);
        entry.listener.mark(rt, mark);
    }
}

void EventHandlerMap::dispose(JSRuntime* rt) {
    for (EventHandlerEntry& entry : m_entries) {
        entry.type.clear(rt);
        entry.value.clear(rt);
        entry.scopeElement.clear(rt);
        entry.listener.clear(rt);
    }
    m_entries.clear();
}

namespace {

// The host state's answers, which a runtime without one (DOM-only: no Window) does not have (Ruling R4).
JSAtom errorAtom(JSContext* ctx) {
    HostState* host = HostState::find(ctx);
    return host ? host->eventHandlerAttributes().errorType() : JS_ATOM_NULL;
}

bool isWindow(JSContext* ctx, const EventTarget& target) {
    HostState* host = HostState::find(ctx);
    return host && &target == static_cast<const EventTarget*>(&host->window());
}

void clearValue(JSRuntime* rt, EventHandlerEntry& entry) {
    entry.value.clear(rt);
    entry.uncompiled = false;
    entry.scopeElement.clear(rt);
}

Value nullValue(JSContext* ctx) {
    return Value::adopt(ctx, JS_NULL);
}

/// Whether `entry` still holds `body` uncompiled: the same string value, compared by identity. `body` is held for the
/// whole compilation, so no other string can take its address; a body set again to this very value meanwhile matches
/// too, and its text is the same.
bool holdsBody(const EventHandlerEntry* entry, JSValueConst body) {
    return entry && entry->uncompiled && JS_IsString(entry->value.value) && JS_VALUE_GET_PTR(entry->value.value) == JS_VALUE_GET_PTR(body);
}

/// The factory's evaluation: a call into JS like callFunction's (Ruling R3), counted in Runtime::scriptDepth, its
/// exception through the fatal check (a stop throws Aborted there) and the cleanup after it when it is the outermost.
/// The one place compiling a body enters JS other than through callFunction, so it opens its own ScriptBoundary: a body
/// that closes the function early runs its code at native depth 0, as any script does, not inside the getter's frame.
CallResult evaluateFactory(JSContext* ctx, const std::string& source, const std::string& filename) {
    Runtime& runtime = Runtime::from(ctx);
    Runtime::ScriptBoundary boundary(runtime);
    runtime.throwIfStopped();
    runtime.enterScript();
    return runtime.leaveScript(ctx, JS_Eval(ctx, source.c_str(), source.size(), filename.c_str(), JS_EVAL_TYPE_GLOBAL));
}

/// HTML "getting the current value of the event handler", step 1: compiles `entry`'s uncompiled body (the entry is
/// read before any script runs). The body is the author's own script.
/// - An element's handler has the element and its node document as scopes, bound by a factory called with both, which
///   reads them through `arguments` so they add no name the body could see (Ruling 15). A Window's handler (a body's
///   window-reflecting one) has the global scope alone and the window's document, so its factory binds nothing.
/// - The function is anonymous and gets its name as a property's value (the object literal's SetFunctionName: not
///   writable, not enumerable, configurable). A named function expression would also bind the name in the body's
///   scope, and nothing is defined on a value an early-closing body chose (a proxy's trap would run uncounted).
/// - Compiling is a script entry (Ruling R3): the eval and the factory call each count as a call into JS, and every
///   exception passes the fatal check before it is reported, so a stop inside them stays a stop (Aborted).
/// - On a failure the value becomes null (the handler stays activated), then the error is reported, once: the next
///   read finds null.
Value compile(JSContext* ctx, EventTarget& owner, JSAtom type, const EventHandlerEntry& entry) {
    JSRuntime* rt = JS_GetRuntime(ctx);
    // Counted for the whole compilation: script that runs while it compiles cannot free what is read after it.
    Value ownerObject = Value::dup(ctx, owner.object());
    Value bodyValue = Value::dup(ctx, entry.value.value);
    bool windowHandler = isWindow(ctx, owner);
    Value elementObject = windowHandler ? Value() : Value::dup(ctx, entry.scopeElement.value);
    Document& windowDocument = DOMState::of(ctx).document();
    Document& document = windowHandler ? windowDocument : static_cast<Element*>(payloadOfKnown(elementObject.get()))->nodeDocument();
    // "If element's node document is not fully active, return null": only the window's document compiles.
    if (&document != &windowDocument) {
        return nullValue(ctx);
    }
    Value documentObject = Value::dup(ctx, document.object());
    String body = String::adopt(ctx, bodyValue.newRef());
    String url = document.URL(ctx);
    // Both are converted and copied into the source.
    const char* parameters = windowHandler && type == errorAtom(ctx) ? "event, source, lineno, colno, error" : "event";
    std::string name = "on" + String::fromAtom(ctx, type).utf8();
    std::string source = std::string("(function () { ") + (windowHandler ? "" : "with (arguments[0]) with (arguments[1]) ") + "return { " +
                         name + ": function (" + parameters + ") {\n" + body.utf8() + "\n} }." + name + "; })";
    std::string filename = url.utf8();
    auto fail = [&](Value error) {
        if (EventHandlerEntry* again = owner.eventHandlers()->find(ctx, type); holdsBody(again, bodyValue.get())) {
            clearValue(rt, *again);
        }
        Runtime::from(ctx).reportException(ctx, error.release());
        return nullValue(ctx);
    };
    CallResult factory = evaluateFactory(ctx, source, filename);
    if (factory.status == CallStatus::Threw) {
        // A body that does not parse: its SyntaxError. The fatal check ran in leaveScript.
        return fail(std::move(factory.value));
    }
    JSValueConst scopes[2] = {documentObject.get(), elementObject.get()};
    CallResult made = callFunction(ctx, factory.value.get(), JS_UNDEFINED, windowHandler ? 0 : 2, scopes);
    // Only a body that closes the function early fails from here on (its own code ran).
    if (made.status == CallStatus::Threw) {
        // callFunction ran the fatal check.
        return fail(std::move(made.value));
    }
    if (!JS_IsFunction(ctx, made.value.get())) {
        // What HTML's parse of such a body would have reported.
        JS_ThrowSyntaxError(ctx, "The event handler's body is not a function body.");
        Value error = Value::adopt(ctx, JS_GetException(ctx));
        throwIfFatal(ctx, error.get());
        return fail(std::move(error));
    }
    // Script can have run while it compiled: a body that closes the function early (`}` … `{`) runs its own code in the
    // eval or the factory call (Ruling 15's accepted cost; QuickJS's own Function constructor has the same shape), and
    // the microtask checkpoint follows an outermost eval. So the entry is looked up again, and the function is stored
    // only over the body it was compiled from.
    if (EventHandlerEntry* again = owner.eventHandlers()->find(ctx, type); holdsBody(again, bodyValue.get())) {
        again->value.set(rt, made.value.newRef());
        again->uncompiled = false;
        again->scopeElement.clear(rt);
    }
    return std::move(made.value);
}

/// The current value: null, the callback object, or a just-compiled body.
Value currentValue(JSContext* ctx, EventTarget& owner, JSAtom type) {
    EventHandlerMap* map = owner.eventHandlers();
    EventHandlerEntry* entry = map ? map->find(ctx, type) : nullptr;
    if (!entry || entry->value.isUndefined()) {
        return nullValue(ctx);
    }
    if (entry->uncompiled) {
        return compile(ctx, owner, type, *entry);
    }
    return Value::dup(ctx, entry->value.value);
}

/// HTML's event handler processing algorithm, as the listener's callback: `this` is the event's current target (the
/// handler's owner, where the listener is), the one argument the event, the one datum the handler's type.
JSValue processEventHandler(JSContext* ctx, JSValueConst thisVal, int argc, JSValueConst* argv, int magic, JSValueConst* data) {
    return glue(ctx, [&]() -> JSValue {
        auto* target = unwrap<EventTarget>(ctx, thisVal, idl::kEventTarget);
        auto* event = argc > 0 ? unwrap<Event>(ctx, argv[0], idl::kEvent) : nullptr;
        if (!target || !event) {
            return JS_UNDEFINED;
        }
        // Held for the whole call: script the handler (or compiling it) runs cannot free them.
        Value targetObject = Value::dup(ctx, thisVal);
        Value eventObject = Value::dup(ctx, argv[0]);
        Atom type = Atom::adopt(ctx, JS_ValueToAtom(ctx, data[0]));
        if (type.get() == JS_ATOM_NULL) {
            throw Thrown{};
        }
        Value callback = currentValue(ctx, *target, type.get());
        // A non-callable object from [LegacyTreatNonObjectAsNull]: invoking it returns undefined (WebIDL).
        if (!JS_IsObject(callback.get()) || !JS_IsFunction(ctx, callback.get())) {
            return JS_UNDEFINED;
        }
        // "special error event handling": an ErrorEvent whose type is error, at the window.
        JSAtom error = errorAtom(ctx);
        auto* errorEvent = unwrap<ErrorEvent>(ctx, argv[0], idl::kErrorEvent);
        bool special = errorEvent && error != JS_ATOM_NULL && event->typeAtom() == error && isWindow(ctx, *target);
        CallResult result;
        if (special) {
            Value message = Value::adopt(ctx, toJS(ctx, errorEvent->message(ctx)));
            Value filename = Value::adopt(ctx, toJS(ctx, errorEvent->filename(ctx)));
            Value lineno = Value::adopt(ctx, toJS(ctx, errorEvent->lineno(ctx)));
            Value colno = Value::adopt(ctx, toJS(ctx, errorEvent->colno(ctx)));
            Value errorValue = errorEvent->error(ctx);
            JSValueConst args[5] = {message.get(), filename.get(), lineno.get(), colno.get(), errorValue.get()};
            result = callFunction(ctx, callback.get(), thisVal, 5, args);
        } else {
            JSValueConst args[1] = {eventObject.get()};
            result = callFunction(ctx, callback.get(), thisVal, 1, args);
        }
        if (result.status == CallStatus::Threw) {
            // "rethrow": the listener's invocation reports it.
            return JS_Throw(ctx, result.value.release());
        }
        // The window's onerror cancels with true, every other handler with false.
        JSValueConst returned = result.value.get();
        if (JS_IsBool(returned) && (JS_ToBool(ctx, returned) == 1) == special) {
            event->preventDefault(ctx);
        }
        return JS_UNDEFINED;
    });
}

/// HTML "activate an event handler": once, the processing function becomes a listener. It is added before the entry
/// records it, so a failure on the way (out of memory) leaves the handler not activated, for the next value to
/// activate: never a listener in the list the entry does not know, nor a recorded one that is not there. Adding a
/// listener runs no script, so `entry` stays valid.
void activate(JSContext* ctx, EventTarget& owner, EventHandlerEntry& entry) {
    if (!entry.listener.isUndefined()) {
        return;
    }
    Value name = Value::adopt(ctx, checked(ctx, JS_AtomToString(ctx, entry.type.atom)));
    JSValueConst data[1] = {name.get()};
    Value fn = Value::adopt(ctx, checked(ctx, JS_NewCFunctionData(ctx, &processEventHandler, 1, 0, 1, data)));
    // DOM "add an event listener" (what addEventListener does, without its string conversions): the type is noted in
    // ListenedTypes, so an inline handler registers interest.
    owner.addListener(ctx, entry.type.atom, fn.get(), false, std::nullopt, false);
    entry.listener.set(JS_GetRuntime(ctx), fn.release());
}

} // namespace

EventTarget* eventHandlerOwner(JSContext* ctx, EventTarget& target, JSAtom type) {
    auto* element = unwrap<Element>(ctx, target.object(), idl::kElement);
    if (!element) {
        return &target;
    }
    DOMState& dom = DOMState::of(ctx);
    if (!element->hasHTMLName(dom.name(Name::body)) && !element->hasHTMLName(dom.name(Name::frameset))) {
        return &target;
    }
    if (!isWindowReflectingEventHandler(ctx, type)) {
        return &target;
    }
    // "If eventTarget's node document is not an active document, then return null": only the window's document is one,
    // and only a runtime with the host state has a window.
    HostState* host = HostState::find(ctx);
    if (!host || &element->nodeDocument() != &dom.document()) {
        return nullptr;
    }
    return &host->window();
}

JSValue getEventHandler(JSContext* ctx, EventTarget& target, JSAtom type) {
    EventTarget* owner = eventHandlerOwner(ctx, target, type);
    return owner ? currentValue(ctx, *owner, type).release() : JS_NULL;
}

void setEventHandler(JSContext* ctx, EventTarget& target, JSAtom type, JSValueConst value) {
    EventTarget* owner = eventHandlerOwner(ctx, target, type);
    if (!owner) {
        return;
    }
    if (!JS_IsObject(value)) {
        clearEventHandler(ctx, *owner, type);
        return;
    }
    JSRuntime* rt = JS_GetRuntime(ctx);
    EventHandlerEntry& entry = owner->ensureEventHandlers(ctx).findOrAdd(ctx, type);
    entry.value.set(rt, JS_DupValue(ctx, value));
    entry.uncompiled = false;
    entry.scopeElement.clear(rt);
    activate(ctx, *owner, entry);
}

void setEventHandlerBody(JSContext* ctx, EventTarget& owner, JSAtom type, const String& body, Element& scopeElement) {
    JSRuntime* rt = JS_GetRuntime(ctx);
    EventHandlerEntry& entry = owner.ensureEventHandlers(ctx).findOrAdd(ctx, type);
    entry.value.set(rt, body.toJS(ctx));
    entry.uncompiled = true;
    // An element's handler's scope; a Window's handler has none (compile).
    entry.scopeElement.set(rt, isWindow(ctx, owner) ? JS_UNDEFINED : scopeElement.newRef(ctx));
    activate(ctx, owner, entry);
}

void clearEventHandler(JSContext* ctx, EventTarget& owner, JSAtom type) {
    EventHandlerMap* map = owner.eventHandlers();
    EventHandlerEntry* entry = map ? map->find(ctx, type) : nullptr;
    if (!entry) {
        return;
    }
    JSRuntime* rt = JS_GetRuntime(ctx);
    clearValue(rt, *entry);
    if (entry->listener.isUndefined()) {
        return;
    }
    // Out of the list before the entry forgets it, as activate's order. Removing a listener runs no script, so `entry`
    // stays valid.
    Value listener = Value::dup(ctx, entry->listener.value);
    owner.removeListener(ctx, type, listener.get(), false);
    entry->listener.clear(rt);
}

} // namespace wr
