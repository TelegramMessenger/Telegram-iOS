#include "Sources/Events/Taps.h"

#include <cctype>
#include <cmath>
#include <functional>
#include <iterator>
#include <optional>
#include <string>
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
#include "Sources/Render/ComputedStyle.h"
#include "Sources/Render/RenderTree.h"
#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Errors.h"
#include "Sources/Support/Work.h"

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

// The axes the computed touch-action of `target` and its ancestors below <html> forbids panning on, on the layout the
// press was hit-tested on (protocol.md's walk: auto and manipulation say nothing, none takes both, any other value takes
// each axis it has no pan-* keyword for). Charged per element visited and per byte of each value read.
GestureClaim touchActionClaim(JSContext* ctx, EventTarget& target) {
    GestureClaim claim;
    RenderTree* render = HostState::of(ctx).render();
    if (!render) {
        return claim;
    }
    for (Node* n = dynamic_cast<Node*>(&target); n; n = n->parentNode(ctx)) {
        Node* parent = n->parentNode(ctx);
        if (!parent || !parent->isElement()) {
            break;
        }
        if (!n->isElement()) {
            continue;
        }
        charge(ctx, work::kNodeVisit);
        std::optional<std::string> value = render->computedStyleValue(*n, "touch-action", PseudoElement::None);
        if (!value) {
            continue;
        }
        chargeScan(ctx, value->size());
        bool panX = false;
        bool panY = false;
        bool silent = false;
        size_t i = 0;
        while (i < value->size()) {
            while (i < value->size() && std::isspace(static_cast<unsigned char>((*value)[i]))) {
                i++;
            }
            size_t end = i;
            while (end < value->size() && !std::isspace(static_cast<unsigned char>((*value)[end]))) {
                end++;
            }
            std::string token = value->substr(i, end - i);
            for (char& c : token) {
                c = char(std::tolower(static_cast<unsigned char>(c)));
            }
            i = end;
            if (token.empty()) {
                continue;
            }
            if (token == "none") {
                return GestureClaim{true, true};
            }
            silent = silent || token == "auto" || token == "manipulation";
            panX = panX || token == "pan-x" || token == "pan-left" || token == "pan-right";
            panY = panY || token == "pan-y" || token == "pan-up" || token == "pan-down";
        }
        if (silent) {
            continue;
        }
        claim.x = claim.x || !panX;
        claim.y = claim.y || !panY;
    }
    return claim;
}

// Whether a press at `target` lands on something the widget handles (TapState::takesTaps), before its events
// dispatch. Charged per target visited and per listener list walked.
bool handlesPress(JSContext* ctx, EventTarget& target) {
    static constexpr std::string_view kTypes[] = {"click", "pointerdown", "pointerup", "touchstart", "touchend",
                                                  "mousedown", "mouseup"};
    Atom atoms[std::size(kTypes)] = {Atom::fromUTF8(ctx, kTypes[0]), Atom::fromUTF8(ctx, kTypes[1]),
                                     Atom::fromUTF8(ctx, kTypes[2]), Atom::fromUTF8(ctx, kTypes[3]),
                                     Atom::fromUTF8(ctx, kTypes[4]), Atom::fromUTF8(ctx, kTypes[5]),
                                     Atom::fromUTF8(ctx, kTypes[6])};
    const auto listens = [&](EventTarget& t) {
        for (const Atom& atom : atoms) {
            if (t.hasListenersFor(ctx, atom.get())) {
                return true;
            }
        }
        return false;
    };
    const bool disabled = insideDisabledControl(ctx, target);
    for (Node* n = dynamic_cast<Node*>(&target); n; n = n->parentNode(ctx)) {
        charge(ctx, work::kNodeVisit);
        if (listens(*n) || (!disabled && n->isElement() && n->hasActivationBehavior(ctx))) {
            return true;
        }
    }
    return listens(HostState::of(ctx).window());
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
                 bool primary, bool cancelable, int16_t button, uint16_t buttons, double pressure, double movementX = 0,
                 double movementY = 0) {
    return fire<PointerEvent>(ctx, idl::kPointerEvent, type, target, cancelable, [&](PointerEvent& event) {
        event.setPoint(x, y);
        event.setButtons(button, buttons);
        event.setMovement(movementX, movementY);
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
        m_lastX = x;
        m_lastY = y;
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

void TapState::setCapture(JSContext* ctx, Element& element, int32_t pointerId) {
    if (!m_target || pointerId != m_taskPointerId) {
        throw DOMError{"NotFoundError", "No active pointer has that id."};
    }
    if (!element.isConnected(ctx)) {
        throw DOMError{"InvalidStateError", "The element is not connected."};
    }
    m_pendingCapture = Ref<EventTarget>::retain(ctx, &element);
}

void TapState::releaseCapture(JSContext*, Element& element, int32_t pointerId) {
    if (!m_target || pointerId != m_taskPointerId) {
        throw DOMError{"NotFoundError", "No active pointer has that id."};
    }
    if (this->hasCapture(element, pointerId)) {
        m_pendingCapture = Ref<EventTarget>();
    }
}

bool TapState::hasCapture(const Element& element, int32_t pointerId) const {
    return m_target && pointerId == m_taskPointerId && m_pendingCapture.get() == &element;
}

EventTarget& TapState::pointerTarget(JSContext* ctx, double x, double y, bool primary) {
    if (m_capture.get() != m_pendingCapture.get()) {
        Ref<EventTarget> lost = std::move(m_capture);
        m_capture = m_pendingCapture;
        if (lost) {
            firePointer(ctx, "lostpointercapture", *lost, x, y, m_taskPointerId, primary, false, 0, 0, 0);
        }
        if (m_capture) {
            Ref<EventTarget> got = m_capture;
            firePointer(ctx, "gotpointercapture", *got, x, y, m_taskPointerId, primary, false, 0, 0, 0);
        }
    }
    return m_capture ? *m_capture : *m_target;
}

void TapState::runDown(JSContext* ctx, double x, double y, int32_t pointerId, bool primary) {
    m_target = Ref<EventTarget>();
    m_pendingCapture = Ref<EventTarget>();
    m_capture = Ref<EventTarget>();
    m_taskPointerId = pointerId;
    m_pointerCanceled = false;
    m_touchCanceled = false;
    m_claim = GestureClaim();
    m_takesTaps = false;
    EventTarget* target = hitTarget(ctx, x, y);
    if (!target) {
        return;
    }
    m_target = Ref<EventTarget>::retain(ctx, target);
    const GestureClaim claim = primary ? touchActionClaim(ctx, *target) : GestureClaim();
    const bool handles = primary && handlesPress(ctx, *target);
    HostState& state = HostState::of(ctx);
    m_press = state.beginPress();
    UserActions& actions = state.userActions();
    Element* element = dynamic_cast<Element*>(target);
    actions.setPointer(ctx, element, element);
    {
        HostState::PressScope press(state, m_press);
        m_pointerCanceled = !firePointer(ctx, "pointerdown", *target, x, y, pointerId, primary, true, 0, 1, 0.5);
    }
    m_touchCanceled = !fireTouch(ctx, "touchstart", *target, x, y, pointerId, true, true);
    if (primary) {
        m_claim = (m_pointerCanceled || m_touchCanceled) ? GestureClaim{true, true} : claim;
        m_takesTaps = handles || m_claim.x || m_claim.y;
    }
}

void TapState::runMove(JSContext* ctx, double x, double y, int32_t pointerId, bool primary) {
    if (!m_target) {
        return;
    }
    Ref<EventTarget> target = m_target;
    // Pointer Lock 2's movement: from the last move delivered, the down point for the first (moves inside the slop are
    // not delivered: the first that is carries them).
    const double movementX = x - m_lastX;
    const double movementY = y - m_lastY;
    m_lastX = x;
    m_lastY = y;
    {
        Ref<EventTarget> pointer = Ref<EventTarget>::retain(ctx, &this->pointerTarget(ctx, x, y, primary));
        firePointer(ctx, "pointermove", *pointer, x, y, pointerId, primary, true, -1, 1, 0.5, movementX, movementY);
    }
    fireTouch(ctx, "touchmove", *target, x, y, pointerId, true, true);
}

void TapState::runUp(JSContext* ctx, double x, double y, int32_t pointerId, bool primary, bool moved) {
    if (!m_target) {
        return;
    }
    // The press is over; the hover stays, as touch browsers keep it.
    HostState& state = HostState::of(ctx);
    state.userActions().setPointer(ctx, dynamic_cast<Element*>(m_target.get()), nullptr);
    {
        HostState::PressScope press(state, m_press);
        Ref<EventTarget> pointer = Ref<EventTarget>::retain(ctx, &this->pointerTarget(ctx, x, y, primary));
        firePointer(ctx, "pointerup", *pointer, x, y, pointerId, primary, true, 0, 0, 0);
        // The capture ends with the press: lostpointercapture after the pointerup.
        m_pendingCapture = Ref<EventTarget>();
        this->pointerTarget(ctx, x, y, primary);
    }
    Ref<EventTarget> target = std::move(m_target);
    m_target = Ref<EventTarget>();
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
    HostState::of(ctx).userActions().setPointer(ctx, dynamic_cast<Element*>(m_target.get()), nullptr);
    {
        Ref<EventTarget> pointer = Ref<EventTarget>::retain(ctx, &this->pointerTarget(ctx, x, y, primary));
        firePointer(ctx, "pointercancel", *pointer, x, y, pointerId, primary, false, 0, 0, 0);
        m_pendingCapture = Ref<EventTarget>();
        this->pointerTarget(ctx, x, y, primary);
    }
    Ref<EventTarget> target = std::move(m_target);
    m_target = Ref<EventTarget>();
    fireTouch(ctx, "touchcancel", *target, x, y, pointerId, false, false);
}

void Element::setPointerCapture(JSContext* ctx, int32_t pointerId) {
    HostState::of(ctx).taps().setCapture(ctx, *this, pointerId);
}

void Element::releasePointerCapture(JSContext* ctx, int32_t pointerId) {
    HostState::of(ctx).taps().releaseCapture(ctx, *this, pointerId);
}

bool Element::hasPointerCapture(JSContext* ctx, int32_t pointerId) {
    return HostState::of(ctx).taps().hasCapture(*this, pointerId);
}

} // namespace wr
