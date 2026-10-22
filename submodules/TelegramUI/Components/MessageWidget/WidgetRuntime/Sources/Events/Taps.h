// Taps (M1d plan, Task 2): the host's pointer phases, hit-tested on the runtime's own layout (RenderTree::nodeAt) and
// dispatched as touch browsers dispatch a tap.
// - Down: pointerdown, then touchstart, at the hit node, which becomes the tap's target (a touch's implicit capture).
//   A primary press also decides its gesture claim (GestureClaim) and whether it takes taps, which the host reads once
//   the task has run.
// - Move: dropped until either axis has moved kTapSlop px from the down point; after that, pointermove and touchmove at
//   the target, but only when the widget listens for one of them (ListenedTypes, as today's renderer forwards).
// - Up: pointerup, then touchend, at the target. Then, when it is a click, the compatibility mousedown and mouseup and
//   the click: a primary pointer that never moved past the slop, lifted over the target (or inside it), when the target
//   is not inside a disabled form control and neither touchstart nor touchend was canceled. A canceled pointerdown
//   drops the compatibility mouse events and keeps the click, as Pointer Events says.
// - Cancel: pointercancel and touchcancel at the target, and no click.
// Each phase is one task on the user interaction task source, queued by the host's call; every event is trusted.
#pragma once

#include <cstdint>

#include "quickjs.h"
#include "Sources/Support/PlatformObject.h"

namespace wr {

class Element;
class EventTarget;

enum class PointerPhase : uint8_t { Down, Move, Up, Cancel };

/// The drags of a primary press the widget takes for itself (sdk-v1 §5.5; protocol.md, "Touch gestures inside a
/// scrolling host"): `x` when the touch-action of the target or an ancestor below <html> forbids horizontal panning
/// (none, pan-y, pinch-zoom, …), `y` when one forbids vertical panning (none, pan-x, …), both when the widget cancels the
/// press's pointerdown or touchstart. touch-action is read as the press starts, before its handlers run, as browsers fix
/// it at touchstart. The host keeps swipe-to-reply off a press with `x` and the list still under one with `y`.
struct GestureClaim {
    bool x = false;
    bool y = false;
};

/// The slop, in CSS px: a move shorter than this on both axes is not delivered, and a tap that never moved past it is a
/// click.
inline constexpr double kTapSlop = 8;

class TapState {
public:
    TapState() = default;
    TapState(const TapState&) = delete;
    TapState& operator=(const TapState&) = delete;

    /// The host's call (HostState::pointer): updates what the host side knows (the down point, whether the pointer moved
    /// past the slop) and queues the phase's task. Never throws: a task that cannot be queued stops the widget.
    void pointer(JSContext* ctx, PointerPhase phase, double x, double y, int32_t pointerId, bool primary);

    /// Pointer Events' capture, task side: `element` takes the press's pointer events from the next one on
    /// (gotpointercapture before it, lostpointercapture after the pointerup or pointercancel); touch events stay with the
    /// touch's target, and the compatibility mouse events and the click with the down target. A touch's implicit capture
    /// (the down target) is not reported: hasPointerCapture answers only for an explicit one. Throws DOMError:
    /// NotFoundError when no press is dispatching pointer `pointerId`, InvalidStateError when `element` is not connected.
    void setCapture(JSContext* ctx, Element& element, int32_t pointerId);
    void releaseCapture(JSContext* ctx, Element& element, int32_t pointerId);
    bool hasCapture(const Element& element, int32_t pointerId) const;
    /// The claim of the last press whose down task has run: none for a press on nothing or not the primary pointer.
    GestureClaim claim() const { return m_claim; }
    /// Whether the last primary press whose down task has run landed on something the widget handles: a listener for a
    /// press's events (click, pointerdown, pointerup, touchstart, touchend, mousedown, mouseup) on the event's path
    /// (the target, its ancestors, the document, the window), an element on that path with activation behaviour outside
    /// a disabled control, a drag claim or a canceled pointerdown or touchstart. The client takes a tap there at once,
    /// as it does a message button's; anywhere else it waits for a double tap, the bubble's (sdk-v1 §5.5).
    bool takesTaps() const { return m_takesTaps; }

private:
    /// Makes the pending capture the current one, firing lostpointercapture at the old and gotpointercapture at the new;
    /// the target of the press's next pointer event.
    EventTarget& pointerTarget(JSContext* ctx, double x, double y, bool primary);
    void runDown(JSContext* ctx, double x, double y, int32_t pointerId, bool primary);
    void runMove(JSContext* ctx, double x, double y, int32_t pointerId, bool primary);
    void runUp(JSContext* ctx, double x, double y, int32_t pointerId, bool primary, bool moved);
    void runCancel(JSContext* ctx, double x, double y, int32_t pointerId, bool primary);

    // The host side: the pointer between its down and its up or cancel.
    bool m_active = false;
    int32_t m_pointerId = 0;
    double m_downX = 0;
    double m_downY = 0;
    /// The last position delivered (a move's movementX/Y is from it).
    double m_lastX = 0;
    double m_lastY = 0;
    bool m_moved = false;

    // The task side: the tap's target from its down task to its up or cancel task, and what canceled its defaults.
    Ref<EventTarget> m_target;
    /// The press's pointer, and its explicit capture: pending (set by script) and current (reported to script).
    int32_t m_taskPointerId = 0;
    Ref<EventTarget> m_pendingCapture;
    Ref<EventTarget> m_capture;
    /// The press's number (HostState::beginPress), active while its pointer and mouse events dispatch.
    uint64_t m_press = 0;
    bool m_pointerCanceled = false;
    bool m_touchCanceled = false;
    GestureClaim m_claim;
    bool m_takesTaps = false;
};

} // namespace wr
