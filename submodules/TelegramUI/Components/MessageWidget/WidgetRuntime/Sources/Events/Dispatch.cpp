#include "Sources/Events/Dispatch.h"

#include "Generated/Bindings.h"
#include "Sources/DOM/DOMState.h"
#include "Sources/DOM/Document.h"
#include "Sources/Events/Event.h"
#include "Sources/Events/EventTarget.h"
#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Callbacks.h"

namespace wr {

namespace {

enum class ListenerPhase { Capturing, Bubbling };

/// DOM's legacy fallback for trusted events nobody listens to: the WebKit-prefixed type, or JS_ATOM_NULL (also in a
/// runtime without the DOM).
JSAtom legacyTypeOf(JSContext* ctx, JSAtom type) {
    const DOMState* state = DOMState::find(ctx);
    if (!state) {
        return JS_ATOM_NULL;
    }
    if (type == state->name(Name::animationend)) {
        return state->name(Name::webkitAnimationEnd);
    }
    if (type == state->name(Name::animationiteration)) {
        return state->name(Name::webkitAnimationIteration);
    }
    if (type == state->name(Name::animationstart)) {
        return state->name(Name::webkitAnimationStart);
    }
    if (type == state->name(Name::transitionend)) {
        return state->name(Name::webkitTransitionEnd);
    }
    return JS_ATOM_NULL;
}

/// DOM "inner invoke" step 12, on every way out of a listener's call: Aborted unwinds through it too.
struct PassiveListenerScope {
    Event& event;
    ~PassiveListenerScope() { event.setInPassiveListener(false); }
};

/// DOM "invoke" step 8.4, on every way out of the legacy pass: the event gets its own type back.
struct OriginalTypeScope {
    JSContext* ctx;
    Event& event;
    Atom original;
    ~OriginalTypeScope() { event.setTypeAtom(ctx, original.get()); }
};

/// DOM "inner invoke": the listeners of `current`, from the clone `listeners` taken before any of them ran. Both are
/// held by the caller for the whole walk (`current` as a counted reference, each listener by its ListenerRef).
bool innerInvoke(JSContext* ctx, Event& event, EventTarget& current, const Vector<ListenerRef>& listeners, ListenerPhase phase) {
    bool found = false;
    for (const ListenerRef& ref : listeners) {
        EventListener& listener = *ref;
        if (listener.removed || listener.type.atom != event.typeAtom()) {
            continue;
        }
        found = true;
        if (phase == ListenerPhase::Capturing && !listener.capture) {
            continue;
        }
        if (phase == ListenerPhase::Bubbling && listener.capture) {
            continue;
        }
        if (listener.once) {
            current.removeListenerEntry(ctx, listener);
        }
        {
            // Owned for the whole call: a listener that removes itself or clears its holder cannot free the running
            // function.
            Value callback = Value::dup(ctx, listener.callback.get());
            PassiveListenerScope passive{event};
            if (listener.passive) {
                event.setInPassiveListener(true);
            }
            JSValueConst argv[1] = {event.object()};
            CallResult result = callInterface(ctx, callback.get(), "handleEvent", current.object(), 1, argv);
            if (result.status == CallStatus::Threw) {
                Runtime::from(ctx).reportException(ctx, result.value.release());
            }
        }
        if (event.stopImmediatePropagationFlag()) {
            break;
        }
    }
    return found;
}

/// DOM "invoke" for the path's entry `index`.
void invoke(JSContext* ctx, Event& event, size_t index, ListenerPhase phase) {
    if (event.stopPropagationFlag()) {
        return;
    }
    // A counted reference of this frame's own, held across every listener call.
    Ref<EventTarget> current = Ref<EventTarget>::retain(ctx, &event.pathAt(index));
    event.setCurrentTarget(ctx, current.get());
    const Vector<ListenerRef>* list = current->listeners();
    if (!list || list->empty()) {
        return;
    }
    // The clone: a listener added from here on waits for the next dispatch, and one removed is skipped by its removed
    // flag.
    Vector<ListenerRef> listeners(*list);
    bool found = innerInvoke(ctx, event, *current, listeners, phase);
    if (found || !event.isTrusted(ctx)) {
        return;
    }
    JSAtom legacy = legacyTypeOf(ctx, event.typeAtom());
    if (legacy == JS_ATOM_NULL) {
        return;
    }
    OriginalTypeScope restore{ctx, event, Atom::dup(ctx, event.typeAtom())};
    event.setTypeAtom(ctx, legacy);
    innerInvoke(ctx, event, *current, listeners, phase);
}

/// DOM "dispatch" steps 6-9: the event is done with its path.
void finish(JSContext* ctx, Event& event) {
    event.setPhase(Event::None);
    event.setCurrentTarget(ctx, nullptr);
    event.clearPath(JS_GetRuntime(ctx));
    event.setDispatching(false);
    event.clearPropagationFlags();
}

} // namespace

bool dispatch(JSContext* ctx, Event& event, EventTarget& target, bool legacyTargetOverride) {
    // Before anything is touched, and outside the try below, whose reset would clear the outer dispatch's state: a
    // native re-dispatch from inside one of the event's listeners would rebuild the path the outer loop walks.
    if (event.dispatching()) {
        throw DOMError{"InvalidStateError", "The event is already being dispatched."};
    }
    event.setDispatching(true);
    Ref<EventTarget> activationTarget;
    try {
        EventTarget* targetOverride = &target;
        if (legacyTargetOverride) {
            // The window's associated document; no override in a runtime without the DOM's main document.
            DOMState* state = DOMState::find(ctx);
            if (state && state->hasDocument()) {
                targetOverride = &state->document();
            }
        }
        // The path: the target, then each get-the-parent. No shadow trees, so only the first entry has a
        // shadow-adjusted target (the target override). No script runs until it is complete.
        event.clearPath(JS_GetRuntime(ctx));
        event.appendToPath(ctx, target);
        bool isActivationEvent = event.isActivationClick(ctx);
        if (isActivationEvent && target.hasActivationBehavior(ctx)) {
            activationTarget = Ref<EventTarget>::retain(ctx, &target);
        }
        for (EventTarget* parent = target.getTheParent(ctx, event); parent; parent = parent->getTheParent(ctx, event)) {
            if (isActivationEvent && event.bubbles(ctx) && !activationTarget && parent->hasActivationBehavior(ctx)) {
                activationTarget = Ref<EventTarget>::retain(ctx, parent);
            }
            event.appendToPath(ctx, *parent);
        }
        event.setTarget(ctx, targetOverride);
        if (activationTarget) {
            activationTarget->legacyPreActivationBehavior(ctx);
        }
        size_t size = event.pathSize();
        for (size_t i = size; i-- > 0;) {
            event.setPhase(i == 0 ? Event::AtTarget : Event::Capturing);
            invoke(ctx, event, i, ListenerPhase::Capturing);
        }
        for (size_t i = 0; i < size; i++) {
            if (i == 0) {
                event.setPhase(Event::AtTarget);
            } else {
                if (!event.bubbles(ctx)) {
                    continue;
                }
                event.setPhase(Event::Bubbling);
            }
            invoke(ctx, event, i, ListenerPhase::Bubbling);
        }
    } catch (...) {
        finish(ctx, event);
        throw;
    }
    finish(ctx, event);
    if (activationTarget) {
        if (!event.canceledFlag()) {
            activationTarget->activationBehavior(ctx, event);
        } else {
            activationTarget->legacyCanceledActivationBehavior(ctx);
        }
    }
    return !event.canceledFlag();
}

bool fireEvent(JSContext* ctx, EventTarget& target, JSAtom type, bool bubbles, bool cancelable, bool legacyTargetOverride) {
    Ref<Event> event = create<Event>(ctx, idl::kEvent, ctx);
    event->initialize(ctx, type, bubbles, cancelable);
    event->setIsTrusted(true);
    return dispatch(ctx, *event, target, legacyTargetOverride);
}

} // namespace wr
