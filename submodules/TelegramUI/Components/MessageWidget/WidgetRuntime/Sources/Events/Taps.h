// Taps (M1d plan, Task 2): the host's pointer phases, hit-tested on the runtime's own layout (RenderTree::nodeAt) and
// dispatched as touch browsers dispatch a tap. Each finger is its own pointer with a press of its own (multitouch
// design §5.1): up to kMaxPointers at once, each with its target, capture and defaults, lifting one disturbing no other.
// - Down: pointerdown, then touchstart, at the hit node, which becomes the tap's target (a touch's implicit capture).
//   The press also decides its gesture claim (GestureClaim) and whether it takes taps, which the host reads once the
//   task has run. Its element is :active until its own up or cancel; the primary pointer's is also hovered.
// - Move: dropped until either axis has moved kTapSlop px from the down point; after that, pointermove and touchmove at
//   the target, but only when the widget listens for one of them (ListenedTypes, as today's renderer forwards).
// - Up: pointerup, then touchend, at the target. Then, when it is a click, the compatibility mousedown and mouseup and
//   the click: a primary pointer that never moved past the slop, lifted over the target (or inside it), when the target
//   is not inside a disabled form control and neither touchstart nor touchend was canceled. A canceled pointerdown
//   drops the compatibility mouse events and keeps the click, as Pointer Events says.
// - Cancel: pointercancel and touchcancel at the target, and no click.
// Each phase is one task on the user interaction task source, queued by the host's call; every event is trusted.
#pragma once

#include <cstddef>
#include <cstdint>
#include <memory>
#include <vector>

#include "quickjs.h"
#include "twidget/gesture_policy.h"
#include "Sources/Support/PlatformObject.h"

namespace wr {

class Element;
class EventTarget;

/// `Retract`: a press the host started before its touch arrived (the bubble's question at a touch's down) that no touch
/// took up, a pointer's touch pressing instead: it ends for the widget as a cancel, and for the double tap it never was.
enum class PointerPhase : uint8_t { Down, Move, Up, Cancel, Retract };

/// What a press claims beyond its taps and double taps, which are always the widget's (sdk-v1 §5.5; widget-sandbox
/// v0.1.2, G1): widget-sandbox's shared gesture policy (`twidget::gesture::claimOf`) over the computed touch-action of
/// the target and its ancestors up to the widget's <html>: `x` when one forbids horizontal panning (none, pan-y,
/// pinch-zoom, …), `y` when one forbids vertical panning, `hold` for none (the hold is the widget's: `contextmenu`, no
/// message menu); a canceled pointerdown or touchstart claims both axes, never a hold. touch-action is read as the press
/// starts, before its handlers run, as browsers fix it at touchstart. A touch starting in the widget's leading
/// `EDGE_STRIP_PX` claims nothing (the back gesture starts there). The host keeps swipe-to-reply off a press with `x` and
/// the message menu off one with `hold`.
struct GestureClaim {
    bool x = false;
    bool y = false;
    bool hold = false;
};

/// The slop, in CSS px (the policy's TOUCH_SLOP_PX): a move no farther than this from the down is not delivered, and a
/// tap that never moved past it is a click.
inline constexpr double kTapSlop = twidget::gesture::TOUCH_SLOP_PX;

/// At most this many pointers press at once; a down past them is dropped whole, its later phases with it.
inline constexpr size_t kMaxPointers = 5;

class TapState {
public:
    TapState() = default;
    TapState(const TapState&) = delete;
    TapState& operator=(const TapState&) = delete;

    /// The host's call (HostState::pointer): updates what the host side knows of the pointer (its down point, whether it
    /// moved past the slop) and queues the phase's task. A down for a pointer already down, or past kMaxPointers, is
    /// ignored, and so is any phase of a pointer that is not down. Never throws: a task that cannot be queued stops the
    /// widget.
    /// `kind` is the pointer's (an iPad pointer is a mouse: its own events, no touch events, no edge strip); `button`
    /// the mouse button pressed (0 primary, 2 secondary), 0 for a touch.
    void pointer(JSContext* ctx, PointerPhase phase, double x, double y, int32_t pointerId, bool primary,
                 twidget::PointerKind kind = twidget::PointerKind::Touch, int16_t button = 0);

    /// Pointer Events' capture, task side: `element` takes the press's pointer events from the next one on
    /// (gotpointercapture before it, lostpointercapture after the pointerup or pointercancel); touch events stay with the
    /// touch's target, and the compatibility mouse events and the click with the down target. A touch's implicit capture
    /// (the down target) is not reported: hasPointerCapture answers only for an explicit one. Throws DOMError:
    /// NotFoundError when no press is dispatching pointer `pointerId`, InvalidStateError when `element` is not connected.
    void setCapture(JSContext* ctx, Element& element, int32_t pointerId);
    void releaseCapture(JSContext* ctx, Element& element, int32_t pointerId);
    bool hasCapture(const Element& element, int32_t pointerId) const;
    /// The claim of the last press whose down task has run, whatever its pointer: none for a press on nothing.
    GestureClaim claim() const { return m_claim; }
    /// Whether the last press whose down task has run landed on something the widget handles: a listener for a
    /// press's events (click, pointerdown, pointerup, touchstart, touchend, mousedown, mouseup) on the event's path
    /// (the target, its ancestors, the document, the window), an element on that path with activation behaviour outside
    /// a disabled control, a drag claim or a canceled pointerdown or touchstart. The client takes a tap there at once,
    /// as it does a message button's; anywhere else it waits for a double tap, the bubble's (sdk-v1 §5.5).
    bool takesTaps() const { return m_takesTaps; }
    /// A press whose down task is queued and has not run yet (the newest): claim() and takesTaps() still answer the one
    /// before it.
    bool downPending() const { return m_downsRun < m_downsQueued; }

private:
    /// The host side of a pointer, between its down and its up or cancel.
    struct HostPointer {
        int32_t id = 0;
        double downX = 0;
        double downY = 0;
        bool moved = false;
    };
    /// The task side of a press: its target from its down task to its up or cancel task, and what canceled its defaults.
    struct Press {
        int32_t pointerId = 0;
        Ref<EventTarget> target;
        /// Its explicit capture: pending (set by script) and current (reported to script).
        Ref<EventTarget> pendingCapture;
        Ref<EventTarget> capture;
        /// Its number (HostState::beginPress), active while its pointer and mouse events dispatch, but its contextmenu.
        uint64_t number = 0;
        /// The last position delivered (a move's movementX/Y is from it).
        double lastX = 0;
        double lastY = 0;
        bool pointerCanceled = false;
        bool touchCanceled = false;
        /// Its pointer's kind and, for a mouse, the button pressed.
        twidget::PointerKind kind = twidget::PointerKind::Touch;
        int16_t button = 0;
        /// The gesture policy made it a hold (its contextmenu, or the bubble's menu): its up clicks not.
        bool held = false;
    };

    /// The press of `pointerId` whose down task has run, or nullptr.
    Press* press(int32_t pointerId) const;
    /// Ends `press`: it leaves the list, and its pointer is no longer down to script (setPointerCapture throws).
    void endPress(const Press& press);
    /// Makes the press's pending capture the current one, firing lostpointercapture at the old and gotpointercapture at
    /// the new; the target of the press's next pointer event.
    EventTarget& pointerTarget(JSContext* ctx, Press& press, double x, double y, bool primary);
    void runDown(JSContext* ctx, double x, double y, int32_t pointerId, bool primary, twidget::PointerKind kind, int16_t button);
    /// `deliver` false: a move nothing listens for, past the slop for the first time, which only the arbiter hears.
    void runMove(JSContext* ctx, double x, double y, int32_t pointerId, bool primary, bool deliver);
    /// The arbiter's hold timer (its holdDeadline), a scheduled task of the loop.
    void runHold(JSContext* ctx);
    void cancelHold(JSContext* ctx);
    /// What the arbiter's verdict asks of the runtime for `press`: a hold clicks not, and `contextmenu` is delivered.
    void deliver(JSContext* ctx, const std::optional<twidget::GestureVerdict>& verdict, Press& press);
    bool arbitrates(int32_t pointerId, bool primary) const { return primary && m_arbiterOpen && pointerId == m_arbitered; }
    void runUp(JSContext* ctx, double x, double y, int32_t pointerId, bool primary, bool moved);
    void runCancel(JSContext* ctx, double x, double y, int32_t pointerId, bool primary, bool retract = false);

    std::vector<HostPointer> m_pointers;
    /// widget-sandbox's gesture policy on the primary pointer (as its renderer core runs it): the double tap's dblclick,
    /// the hold's contextmenu, the hold that clicks not. The press it hears, while open, and its hold task.
    twidget::GestureArbiter m_arbiter;
    /// The arbiter as it was before the open primary press's down, which a retraction (`PointerPhase::Retract`) restores.
    twidget::GestureArbiter m_arbiterBeforePress;
    int32_t m_arbitered = 0;
    bool m_arbiterOpen = false;
    uint64_t m_holdTask = 0;
    /// Owned one by one, so a press's address holds while another ends.
    std::vector<std::unique_ptr<Press>> m_presses;
    GestureClaim m_claim;
    bool m_takesTaps = false;
    /// Down tasks queued, and the serial of the newest that has run (a task dropped by a stop leaves the next to settle).
    uint64_t m_downsQueued = 0;
    uint64_t m_downsRun = 0;
};

} // namespace wr
