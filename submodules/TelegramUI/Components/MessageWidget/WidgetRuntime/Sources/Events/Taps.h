// Taps (M1d plan, Task 2): the host's pointer phases, hit-tested on the runtime's own layout (RenderTree::nodeAt) and
// dispatched as touch browsers dispatch a tap.
// - Down: pointerdown, then touchstart, at the hit node, which becomes the tap's target (a touch's implicit capture).
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

class EventTarget;

enum class PointerPhase : uint8_t { Down, Move, Up, Cancel };

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

private:
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
    /// The press's number (HostState::beginPress), active while its pointer and mouse events dispatch.
    uint64_t m_press = 0;
    bool m_pointerCanceled = false;
    bool m_touchCanceled = false;
};

} // namespace wr
