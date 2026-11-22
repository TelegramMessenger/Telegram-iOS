// DOM "dispatch" (https://dom.spec.whatwg.org/#concept-event-dispatch), without shadow trees, and "fire an event".
#pragma once

#include "quickjs.h"

namespace wr {

class Event;
class EventTarget;

/// Dispatches `event` to `target`: the path first (held by the event as counted references), then the capture and
/// bubble passes, then the activation behaviour. `legacyTargetOverride` makes the window's associated document the
/// event's target (HTML fires `load` at the window that way). Returns false when the event was canceled. The caller
/// holds `event` and `target` for the call.
/// A listener's exception is reported and dispatch goes on. A stop inside a listener's call throws Aborted; dispatch's
/// own native work throws at the memory limit as every DOM native does (std::bad_alloc, or Thrown when QuickJS refuses
/// an allocation). Either way the event is left reset: no path, phase or current target, not dispatching, its
/// propagation flags clear, its own type back and not in a passive listener. An event already being dispatched is
/// refused with DOMError InvalidStateError, as dispatchEvent refuses it, and left as the dispatch under way has it.
bool dispatch(JSContext* ctx, Event& event, EventTarget& target, bool legacyTargetOverride = false);

/// DOM "fire an event": a new trusted Event of `type` dispatched to `target`, with dispatch's `legacyTargetOverride`.
/// Throws as dispatch does.
bool fireEvent(JSContext* ctx, EventTarget& target, JSAtom type, bool bubbles = false, bool cancelable = false,
               bool legacyTargetOverride = false);

} // namespace wr
