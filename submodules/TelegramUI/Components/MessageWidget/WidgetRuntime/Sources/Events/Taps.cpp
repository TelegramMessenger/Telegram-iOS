#include "Sources/Events/Taps.h"

#include <cmath>
#include <functional>
#include <string_view>

#include "Generated/Bindings.h"
#include "Sources/DOM/DOM.h"
#include "Sources/Events/Dispatch.h"
#include "Sources/Events/EventTarget.h"
#include "Sources/Events/ListenedTypes.h"
#include "Sources/Events/UIEvents.h"
#include "Sources/Events/UserActions.h"
#include "Sources/Host/EventLoop.h"
#include "Sources/Host/HostState.h"
#include "Sources/Host/Task.h"
#include "Sources/Host/Window.h"
#include "Sources/Render/RenderTree.h"
#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Errors.h"

namespace wr {

namespace {

// The node the layout hits at (x, y), as an event target; nullptr with no layout.
EventTarget* hitTarget(JSContext* ctx, double x, double y) {
    RenderTree* render = HostState::of(ctx).render();
    return render ? render->nodeAt(x, y) : nullptr;
}

// Whether `node` is `target` or inside it.
bool isInclusiveDescendant(Node* node, EventTarget& target) {
    for (Node* n = node; n; n = n->parentNode(nullptr)) {
        if (static_cast<EventTarget*>(n) == &target) {
            return true;
        }
    }
    return false;
}

// HTML: a disabled form control (or one inside a disabled fieldset's contents is left to M2's forms) does not get the
// click. The target or an ancestor that is a button, input, select or textarea with a `disabled` attribute.
bool insideDisabledControl(JSContext* ctx, EventTarget& target) {
    Node* node = dynamic_cast<Node*>(&target);
    static constexpr std::string_view kControls[] = {"button", "input", "select", "textarea"};
    Atom disabled = Atom::fromUTF8(ctx, "disabled");
    for (Node* n = node; n; n = n->parentNode(ctx)) {
        if (!n->isElement()) {
            continue;
        }
        auto* element = static_cast<Element*>(n);
        if (!element->isHTMLElement()) {
            continue;
        }
        for (std::string_view name : kControls) {
            Atom atom = Atom::fromUTF8(ctx, name);
            if (element->hasHTMLName(atom.get()) && element->hasAttributeAtom(ctx, disabled.get())) {
                return true;
            }
        }
    }
    return false;
}

// A trusted UI event of `type` at `target`, bubbling and cancelable as each type is; returns false when canceled.
template <class E>
bool fire(JSContext* ctx, uint16_t iface, std::string_view type, EventTarget& target, bool cancelable,
          const std::function<void(E&)>& fill) {
    Ref<E> event = create<E>(ctx, iface, ctx);
    Atom atom = Atom::fromUTF8(ctx, type);
    event->initialize(ctx, atom.get(), true, cancelable);
    event->setComposed(true);
    event->setView(ctx, &HostState::of(ctx).window());
    fill(*event);
    event->setIsTrusted(true);
    Ref<EventTarget> held = Ref<EventTarget>::retain(ctx, &target);
    return dispatch(ctx, *event, target);
}

bool firePointer(JSContext* ctx, std::string_view type, EventTarget& target, double x, double y, int32_t pointerId,
                 bool primary, bool cancelable, int16_t button, uint16_t buttons, double pressure) {
    return fire<PointerEvent>(ctx, idl::kPointerEvent, type, target, cancelable, [&](PointerEvent& event) {
        event.setPoint(x, y);
        event.setButtons(button, buttons);
        event.setTouchPointer(ctx, pointerId, primary, pressure);
    });
}

bool fireTouch(JSContext* ctx, std::string_view type, EventTarget& target, double x, double y, int32_t pointerId,
               bool down, bool cancelable) {
    Ref<Touch> touch = Touch::make(ctx, pointerId, target, x, y);
    Ref<TouchList> touches = TouchList::make(ctx, down ? touch.get() : nullptr);
    Ref<TouchList> targetTouches = TouchList::make(ctx, down ? touch.get() : nullptr);
    Ref<TouchList> changed = TouchList::make(ctx, touch.get());
    return fire<TouchEvent>(ctx, idl::kTouchEvent, type, target, cancelable,
                            [&](TouchEvent& event) { event.setLists(ctx, *touches, *targetTouches, *changed); });
}

bool fireMouse(JSContext* ctx, std::string_view type, EventTarget& target, double x, double y, uint16_t buttons,
               int32_t detail) {
    return fire<MouseEvent>(ctx, idl::kMouseEvent, type, target, true, [&](MouseEvent& event) {
        event.setPoint(x, y);
        event.setButtons(0, buttons);
        event.setDetail(detail);
    });
}

} // namespace

void TapState::pointer(JSContext* ctx, PointerPhase phase, double x, double y, int32_t pointerId, bool primary) {
    if (Runtime::from(ctx).stopReason() != StopReason::None || !std::isfinite(x) || !std::isfinite(y)) {
        return;
    }
    bool moved = false;
    switch (phase) {
    case PointerPhase::Down:
        m_active = true;
        m_pointerId = pointerId;
        m_downX = x;
        m_downY = y;
        m_moved = false;
        break;
    case PointerPhase::Move: {
        if (!m_active || pointerId != m_pointerId) {
            return;
        }
        if (!m_moved) {
            if (std::fabs(x - m_downX) < kTapSlop && std::fabs(y - m_downY) < kTapSlop) {
                return;
            }
            m_moved = true;
        }
        try {
            ListenedTypes& listened = HostState::of(ctx).listenedTypes();
            bool wanted = false;
            for (std::string_view type : {"pointermove", "touchmove"}) {
                Atom atom = Atom::fromUTF8(ctx, type);
                wanted = wanted || listened.contains(atom.get());
            }
            if (!wanted) {
                return;
            }
        } catch (...) {
            return;
        }
        break;
    }
    case PointerPhase::Up:
    case PointerPhase::Cancel:
        if (!m_active || pointerId != m_pointerId) {
            return;
        }
        moved = m_moved;
        m_active = false;
        break;
    }
    try {
        HostState::of(ctx).loop().queueTask(
            TaskSource::UserInteraction, makeTask(ctx, [this, phase, x, y, pointerId, primary, moved](JSContext* ctx) {
                switch (phase) {
                case PointerPhase::Down:
                    this->runDown(ctx, x, y, pointerId, primary);
                    break;
                case PointerPhase::Move:
                    this->runMove(ctx, x, y, pointerId, primary);
                    break;
                case PointerPhase::Up:
                    this->runUp(ctx, x, y, pointerId, primary, moved);
                    break;
                case PointerPhase::Cancel:
                    this->runCancel(ctx, x, y, pointerId, primary);
                    break;
                }
            }));
    } catch (...) {
        try {
            abortForCaughtException(ctx);
        } catch (const Aborted&) {
        }
    }
}

void TapState::runDown(JSContext* ctx, double x, double y, int32_t pointerId, bool primary) {
    m_target = Ref<EventTarget>();
    m_pointerCanceled = false;
    m_touchCanceled = false;
    EventTarget* target = hitTarget(ctx, x, y);
    if (!target) {
        return;
    }
    m_target = Ref<EventTarget>::retain(ctx, target);
    HostState& state = HostState::of(ctx);
    m_press = state.beginPress();
    UserActions& actions = state.userActions();
    Element* element = dynamic_cast<Element*>(target);
    actions.setPointer(ctx, element, element);
    {
        HostState::PressScope press(state, m_press);
        m_pointerCanceled = !firePointer(ctx, "pointerdown", *target, x, y, pointerId, primary, true, 0, 1, 0.5);
    }
    // A down that is not canceled moves focus: to the nearest focusable inclusive ancestor, or to none (the body).
    if (!m_pointerCanceled && primary) {
        actions.setFocus(ctx, focusableAncestor(ctx, dynamic_cast<Node*>(target)));
    }
    m_touchCanceled = !fireTouch(ctx, "touchstart", *target, x, y, pointerId, true, true);
}

void TapState::runMove(JSContext* ctx, double x, double y, int32_t pointerId, bool primary) {
    if (!m_target) {
        return;
    }
    Ref<EventTarget> target = m_target;
    firePointer(ctx, "pointermove", *target, x, y, pointerId, primary, true, -1, 1, 0.5);
    fireTouch(ctx, "touchmove", *target, x, y, pointerId, true, true);
}

void TapState::runUp(JSContext* ctx, double x, double y, int32_t pointerId, bool primary, bool moved) {
    if (!m_target) {
        return;
    }
    Ref<EventTarget> target = std::move(m_target);
    m_target = Ref<EventTarget>();
    // The press is over; the hover stays, as touch browsers keep it.
    HostState& state = HostState::of(ctx);
    state.userActions().setPointer(ctx, dynamic_cast<Element*>(target.get()), nullptr);
    {
        HostState::PressScope press(state, m_press);
        firePointer(ctx, "pointerup", *target, x, y, pointerId, primary, true, 0, 0, 0);
    }
    if (!fireTouch(ctx, "touchend", *target, x, y, pointerId, false, true)) {
        m_touchCanceled = true;
    }
    if (!primary || moved || m_touchCanceled) {
        return;
    }
    Node* hit = static_cast<Node*>(hitTarget(ctx, x, y));
    if (!hit || !isInclusiveDescendant(hit, *target) || insideDisabledControl(ctx, *target)) {
        return;
    }
    HostState::PressScope press(state, m_press);
    if (!m_pointerCanceled) {
        fireMouse(ctx, "mousedown", *target, x, y, 1, 1);
        fireMouse(ctx, "mouseup", *target, x, y, 0, 1);
    }
    fireMouse(ctx, "click", *target, x, y, 0, 1);
}

void TapState::runCancel(JSContext* ctx, double x, double y, int32_t pointerId, bool primary) {
    if (!m_target) {
        return;
    }
    Ref<EventTarget> target = std::move(m_target);
    m_target = Ref<EventTarget>();
    HostState::of(ctx).userActions().setPointer(ctx, dynamic_cast<Element*>(target.get()), nullptr);
    firePointer(ctx, "pointercancel", *target, x, y, pointerId, primary, false, 0, 0, 0);
    fireTouch(ctx, "touchcancel", *target, x, y, pointerId, false, false);
}

} // namespace wr
