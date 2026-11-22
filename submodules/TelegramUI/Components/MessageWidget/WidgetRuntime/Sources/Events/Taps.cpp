#include "Sources/Events/Taps.h"

#include <algorithm>
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

// The computed touch-action of `target` and each element ancestor up to the widget's <html>, target first, on the
// layout the press was hit-tested on: what the gesture policy's claimOf reads.
std::vector<std::string> touchActions(JSContext* ctx, EventTarget& target) {
    std::vector<std::string> values;
    RenderTree* render = HostState::of(ctx).render();
    if (!render) {
        return values;
    }
    for (Node* n = dynamic_cast<Node*>(&target); n && n->isElement(); n = n->parentNode(ctx)) {
        if (std::optional<std::string> value = render->computedStyleValue(*n, "touch-action", PseudoElement::None)) {
            values.push_back(std::move(*value));
        }
    }
    return values;
}

GestureClaim gestureClaim(const twidget::WidgetGestureClaim& claim) {
    return GestureClaim{claim.x, claim.y, claim.hold};
}

// Whether a press at `target` lands on something the widget handles (TapState::takesTaps), before its events
// dispatch.
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
                 twidget::PointerKind kind, bool primary, bool cancelable, int16_t button, uint16_t buttons, double pressure,
                 double movementX = 0, double movementY = 0) {
    return fire<PointerEvent>(ctx, idl::kPointerEvent, type, target, cancelable, [&](PointerEvent& event) {
        event.setPoint(x, y);
        event.setButtons(button, buttons);
        event.setMovement(movementX, movementY);
        event.setPointer(ctx, pointerId, primary, pressure, twidget::gesture::name(kind));
    });
}

/// MouseEvent.buttons of a pressed `button` (UI Events: primary 1, auxiliary 4, secondary 2).
uint16_t buttonsOf(int16_t button) {
    return button == 2 ? 2 : button == 1 ? 4 : 1;
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
               int32_t detail, int16_t button = 0) {
    return fire<MouseEvent>(ctx, idl::kMouseEvent, type, target, true, [&](MouseEvent& event) {
        event.setPoint(x, y);
        event.setButtons(button, buttons);
        event.setDetail(detail);
    });
}

} // namespace

void TapState::pointer(JSContext* ctx, PointerPhase phase, double x, double y, int32_t pointerId, bool primary,
                       twidget::PointerKind kind, int16_t button) {
    if (Runtime::from(ctx).stopReason() != StopReason::None || !std::isfinite(x) || !std::isfinite(y)) {
        return;
    }
    auto pointer = std::find_if(m_pointers.begin(), m_pointers.end(), [&](const HostPointer& p) { return p.id == pointerId; });
    bool moved = false;
    bool deliver = true;
    switch (phase) {
    case PointerPhase::Down:
        if (pointer != m_pointers.end() || m_pointers.size() >= kMaxPointers) {
            return;
        }
        m_pointers.push_back(HostPointer{pointerId, x, y, false});
        break;
    case PointerPhase::Move: {
        if (pointer == m_pointers.end()) {
            return;
        }
        bool pastSlop = false;
        if (!pointer->moved) {
            if (std::hypot(x - pointer->downX, y - pointer->downY) <= kTapSlop) {
                return;
            }
            pointer->moved = true;
            pastSlop = true;
        }
        try {
            ListenedTypes& listened = HostState::of(ctx).listenedTypes();
            bool wanted = false;
            for (std::string_view type : {"pointermove", "touchmove", "mousemove"}) {
                Atom atom = Atom::fromUTF8(ctx, type);
                wanted = wanted || listened.contains(atom.get());
            }
            if (!wanted) {
                // The arbiter still hears the primary's first move past the slop: it is a drag, no hold.
                if (!(primary && pastSlop)) {
                    return;
                }
                deliver = false;
            }
        } catch (...) {
            return;
        }
        break;
    }
    case PointerPhase::Up:
    case PointerPhase::Cancel:
    case PointerPhase::Retract:
        if (pointer == m_pointers.end()) {
            return;
        }
        moved = pointer->moved;
        m_pointers.erase(pointer);
        break;
    }
    try {
        const uint64_t downSerial = phase == PointerPhase::Down ? m_downsQueued + 1 : 0;
        HostState::of(ctx).loop().queueTask(
            TaskSource::UserInteraction, makeTask(ctx, [this, phase, x, y, pointerId, primary, moved, kind, button, deliver, downSerial](JSContext* ctx) {
                switch (phase) {
                case PointerPhase::Down:
                    m_downsRun = std::max(m_downsRun, downSerial);
                    this->runDown(ctx, x, y, pointerId, primary, kind, button);
                    break;
                case PointerPhase::Move:
                    this->runMove(ctx, x, y, pointerId, primary, deliver);
                    break;
                case PointerPhase::Up:
                    this->runUp(ctx, x, y, pointerId, primary, moved);
                    break;
                case PointerPhase::Cancel:
                    this->runCancel(ctx, x, y, pointerId, primary);
                    break;
                case PointerPhase::Retract:
                    this->runCancel(ctx, x, y, pointerId, primary, true);
                    break;
                }
            }), TaskKind::Event);
        if (phase == PointerPhase::Down) {
            m_downsQueued = downSerial;
        }
    } catch (...) {
        try {
            abortForCaughtException(ctx);
        } catch (const Aborted&) {
        }
    }
}

TapState::Press* TapState::press(int32_t pointerId) const {
    for (const std::unique_ptr<Press>& press : m_presses) {
        if (press->pointerId == pointerId) {
            return press.get();
        }
    }
    return nullptr;
}

void TapState::endPress(const Press& press) {
    m_presses.erase(std::remove_if(m_presses.begin(), m_presses.end(),
                                   [&](const std::unique_ptr<Press>& p) { return p.get() == &press; }),
                    m_presses.end());
}

void TapState::setCapture(JSContext* ctx, Element& element, int32_t pointerId) {
    Press* press = this->press(pointerId);
    if (!press) {
        throw DOMError{"NotFoundError", "No active pointer has that id."};
    }
    if (!element.isConnected(ctx)) {
        throw DOMError{"InvalidStateError", "The element is not connected."};
    }
    press->pendingCapture = Ref<EventTarget>::retain(ctx, &element);
}

void TapState::releaseCapture(JSContext*, Element& element, int32_t pointerId) {
    Press* press = this->press(pointerId);
    if (!press) {
        throw DOMError{"NotFoundError", "No active pointer has that id."};
    }
    if (this->hasCapture(element, pointerId)) {
        press->pendingCapture = Ref<EventTarget>();
    }
}

bool TapState::hasCapture(const Element& element, int32_t pointerId) const {
    const Press* press = this->press(pointerId);
    return press && press->pendingCapture.get() == &element;
}

EventTarget& TapState::pointerTarget(JSContext* ctx, Press& press, double x, double y, bool primary) {
    if (press.capture.get() != press.pendingCapture.get()) {
        Ref<EventTarget> lost = std::move(press.capture);
        press.capture = press.pendingCapture;
        if (lost) {
            firePointer(ctx, "lostpointercapture", *lost, x, y, press.pointerId, press.kind, primary, false, 0, 0, 0);
        }
        if (press.capture) {
            Ref<EventTarget> got = press.capture;
            firePointer(ctx, "gotpointercapture", *got, x, y, press.pointerId, press.kind, primary, false, 0, 0, 0);
        }
    }
    if (press.capture) {
        return *press.capture;
    }
    // A touch's pointer is captured by its down target (Pointer Events' implicit capture); a mouse's goes where it is.
    if (press.kind == twidget::PointerKind::Mouse) {
        if (EventTarget* hit = hitTarget(ctx, x, y)) {
            return *hit;
        }
    }
    return *press.target;
}

void TapState::runDown(JSContext* ctx, double x, double y, int32_t pointerId, bool primary, twidget::PointerKind kind,
                       int16_t button) {
    m_claim = GestureClaim();
    m_takesTaps = false;
    EventTarget* target = hitTarget(ctx, x, y);
    if (!target || this->press(pointerId)) {
        return;
    }
    const bool mouse = kind == twidget::PointerKind::Mouse;
    // A touch in the leading strip claims nothing, whatever its touch-action (the policy's edge strip; a mouse has none).
    const bool edge = !mouse && x < twidget::gesture::EDGE_STRIP_PX;
    const std::vector<std::string> declared = touchActions(ctx, *target);
    const bool handles = handlesPress(ctx, *target);
    HostState& state = HostState::of(ctx);
    m_presses.push_back(std::make_unique<Press>());
    Press& press = *m_presses.back();
    press.pointerId = pointerId;
    press.target = Ref<EventTarget>::retain(ctx, target);
    press.number = state.beginPress();
    if (primary) {
        // widget-sandbox v0.2.2: the primary press is the haptic gate's touch, before its pointerdown's handlers run.
        state.hapticPressed();
    }
    press.lastX = x;
    press.lastY = y;
    press.kind = kind;
    press.button = mouse ? button : 0;
    UserActions& actions = state.userActions();
    Element* element = dynamic_cast<Element*>(target);
    if (primary) {
        actions.setHover(ctx, element);
    }
    actions.addActive(ctx, element, press.number);
    {
        // widget-sandbox v0.3.0, the finger rule: a finger's or a pen's pointerdown is no gesture, as its press may still
        // become the chat's scroll (and end in pointercancel); its release is. A mouse's pointerdown and mousedown are,
        // as in browsers.
        std::optional<HostState::PressScope> scope;
        if (mouse) {
            scope.emplace(state, press.number);
        }
        press.pointerCanceled = !firePointer(ctx, "pointerdown", *target, x, y, pointerId, kind, primary, true, press.button,
                                             buttonsOf(press.button), 0.5);
        // A mouse's own mousedown follows (none after a canceled pointerdown); a touch's compatibility events come after
        // its touchend.
        if (mouse && !press.pointerCanceled) {
            fireMouse(ctx, "mousedown", *target, x, y, buttonsOf(press.button), 1, press.button);
        }
    }
    if (!mouse) {
        press.touchCanceled = !fireTouch(ctx, "touchstart", *target, x, y, pointerId, true, true);
    }
    const bool prevented = press.pointerCanceled || press.touchCanceled;
    const twidget::WidgetGestureClaim claim = twidget::gesture::claimOf(declared, prevented);
    m_claim = edge ? GestureClaim() : gestureClaim(claim);
    m_takesTaps = handles || m_claim.x || m_claim.y;
    if (primary) {
        // The arbiter applies the edge strip itself; a mouse's secondary click on a hold claim is its contextmenu now.
        this->cancelHold(ctx);
        m_arbitered = pointerId;
        m_arbiterOpen = true;
        m_arbiterBeforePress = m_arbiter;
        const twidget::GestureVerdict verdict = m_arbiter.down(EventLoop::of(ctx).currentTime(), x, y, claim, kind, press.button);
        this->deliver(ctx, verdict, press);
        // A press the bubble takes is over for the widget (the verdict's cancel: pointercancel, nothing more of it). A
        // touch's ends through the host, whose own recognizer took it (the menu, the chat's scroll, a swipe); a mouse's
        // secondary click where no hold is claimed, the message's menu, has nothing else to end it.
        if (verdict.cancel && mouse) {
            this->runCancel(ctx, x, y, pointerId, primary);
            return;
        }
        if (std::optional<double> deadline = m_arbiter.holdDeadline()) {
            m_holdTask = EventLoop::of(ctx).queueTaskAt(*deadline, TaskSource::UserInteraction,
                                                        makeTask(ctx, [this](JSContext* ctx) { this->runHold(ctx); }), TaskKind::Event);
        }
    }
}

void TapState::runHold(JSContext* ctx) {
    m_holdTask = 0;
    if (!m_arbiterOpen) {
        return;
    }
    if (Press* press = this->press(m_arbitered)) {
        this->deliver(ctx, m_arbiter.tick(EventLoop::of(ctx).currentTime()), *press);
    }
}

void TapState::cancelHold(JSContext* ctx) {
    if (m_holdTask) {
        EventLoop::of(ctx).cancelScheduled(m_holdTask);
        m_holdTask = 0;
    }
}

void TapState::deliver(JSContext* ctx, const std::optional<twidget::GestureVerdict>& verdict, Press& press) {
    if (!verdict) {
        return;
    }
    if (verdict->gesture == twidget::Gesture::Hold) {
        press.held = true;
    }
    if (verdict->event == twidget::GestureEvent::ContextMenu) {
        // At the press's target and last point, with no activation, for a finger or a mouse: upstream's host numbers
        // gestures for click, dblclick, mousedown, mouseup, pointerdown and pointerup only (user-activation.ts), and a
        // bridge call carries the gesture of the event it is made in (worker.ts), so a hold's or a secondary click's
        // contextmenu cannot open a link, copy or request. The release that ends the hold still can.
        const bool mouse = press.kind == twidget::PointerKind::Mouse;
        Ref<EventTarget> target = press.target;
        fireMouse(ctx, "contextmenu", *target, press.lastX, press.lastY, mouse ? buttonsOf(press.button) : 1, 0,
                  mouse ? press.button : 0);
    }
}

void TapState::runMove(JSContext* ctx, double x, double y, int32_t pointerId, bool primary, bool deliver) {
    Press* press = this->press(pointerId);
    if (!press) {
        return;
    }
    if (this->arbitrates(pointerId, primary)) {
        this->deliver(ctx, m_arbiter.move(EventLoop::of(ctx).currentTime(), x, y), *press);
    }
    if (!deliver) {
        return;
    }
    Ref<EventTarget> target = press->target;
    // Pointer Lock 2's movement: from the last move delivered, the down point for the first (moves inside the slop are
    // not delivered: the first that is carries them).
    const double movementX = x - press->lastX;
    const double movementY = y - press->lastY;
    press->lastX = x;
    press->lastY = y;
    {
        Ref<EventTarget> pointer = Ref<EventTarget>::retain(ctx, &this->pointerTarget(ctx, *press, x, y, primary));
        firePointer(ctx, "pointermove", *pointer, x, y, pointerId, press->kind, primary, true, -1, buttonsOf(press->button),
                    0.5, movementX, movementY);
        if (press->kind == twidget::PointerKind::Mouse) {
            if (!press->pointerCanceled) {
                fireMouse(ctx, "mousemove", *pointer, x, y, buttonsOf(press->button), 0, 0);
            }
            return;
        }
    }
    fireTouch(ctx, "touchmove", *target, x, y, pointerId, true, true);
}

void TapState::runUp(JSContext* ctx, double x, double y, int32_t pointerId, bool primary, bool moved) {
    Press* press = this->press(pointerId);
    if (!press) {
        return;
    }
    bool doubleTap = false;
    if (this->arbitrates(pointerId, primary)) {
        m_arbiterOpen = false;
        this->cancelHold(ctx);
        const std::optional<twidget::GestureVerdict> verdict = m_arbiter.up(EventLoop::of(ctx).currentTime(), x, y);
        this->deliver(ctx, verdict, *press);
        doubleTap = verdict && verdict->event == twidget::GestureEvent::DblClick;
    }
    // The press is over; the hover stays, as touch browsers keep it.
    HostState& state = HostState::of(ctx);
    state.userActions().removeActive(ctx, press->number);
    {
        HostState::PressScope scope(state, press->number);
        Ref<EventTarget> pointer = Ref<EventTarget>::retain(ctx, &this->pointerTarget(ctx, *press, x, y, primary));
        firePointer(ctx, "pointerup", *pointer, x, y, pointerId, press->kind, primary, true, press->button, 0, 0);
        if (press->kind == twidget::PointerKind::Mouse && !press->pointerCanceled) {
            fireMouse(ctx, "mouseup", *pointer, x, y, 0, 1, press->button);
        }
        // The capture ends with the press: lostpointercapture after the pointerup.
        press->pendingCapture = Ref<EventTarget>();
        this->pointerTarget(ctx, *press, x, y, primary);
    }
    Ref<EventTarget> target = std::move(press->target);
    const uint64_t number = press->number;
    const bool pointerCanceled = press->pointerCanceled;
    bool touchCanceled = press->touchCanceled;
    const bool mouse = press->kind == twidget::PointerKind::Mouse;
    const int16_t button = press->button;
    const bool held = press->held;
    this->endPress(*press);
    if (primary) {
        state.hapticReleased();
    }
    // Its activation is forgotten after its last event: the click, when there is one.
    struct Forget {
        HostState& state;
        uint64_t number;
        ~Forget() { state.endPress(number); }
    } forget{state, number};
    if (mouse) {
        // A mouse clicks with its primary button over its down's target, moved or not; its mouse events came already.
        Node* hit = static_cast<Node*>(hitTarget(ctx, x, y));
        if (!primary || button != 0 || !hit || !isInclusiveDescendant(hit, *target) || insideDisabledControl(ctx, *target)) {
            return;
        }
        HostState::PressScope scope(state, number);
        fireMouse(ctx, "click", *target, x, y, 0, doubleTap ? 2 : 1);
        if (doubleTap) {
            fireMouse(ctx, "dblclick", *target, x, y, 0, 2);
        }
        return;
    }
    if (!fireTouch(ctx, "touchend", *target, x, y, pointerId, false, true)) {
        touchCanceled = true;
    }
    if (!primary || moved || touchCanceled || held) {
        return;
    }
    Node* hit = static_cast<Node*>(hitTarget(ctx, x, y));
    if (!hit || !isInclusiveDescendant(hit, *target) || insideDisabledControl(ctx, *target)) {
        return;
    }
    HostState::PressScope scope(state, number);
    if (!pointerCanceled) {
        fireMouse(ctx, "mousedown", *target, x, y, 1, 1);
        fireMouse(ctx, "mouseup", *target, x, y, 0, 1);
    }
    fireMouse(ctx, "click", *target, x, y, 0, doubleTap ? 2 : 1);
    // A double tap's second click is followed by the renderer's own dblclick (the policy's; the engine's never).
    if (doubleTap) {
        fireMouse(ctx, "dblclick", *target, x, y, 0, 2);
    }
}

void TapState::runCancel(JSContext* ctx, double x, double y, int32_t pointerId, bool primary, bool retract) {
    Press* press = this->press(pointerId);
    if (!press) {
        return;
    }
    if (this->arbitrates(pointerId, primary)) {
        m_arbiterOpen = false;
        this->cancelHold(ctx);
        // A retracted press never was, for the arbiter: the tap before it can still be a double tap's first.
        if (retract) {
            m_arbiter = m_arbiterBeforePress;
        } else {
            m_arbiter.cancel();
        }
    }
    HostState::of(ctx).userActions().removeActive(ctx, press->number);
    {
        Ref<EventTarget> pointer = Ref<EventTarget>::retain(ctx, &this->pointerTarget(ctx, *press, x, y, primary));
        firePointer(ctx, "pointercancel", *pointer, x, y, pointerId, press->kind, primary, false, 0, 0, 0);
        press->pendingCapture = Ref<EventTarget>();
        this->pointerTarget(ctx, *press, x, y, primary);
    }
    Ref<EventTarget> target = std::move(press->target);
    const uint64_t number = press->number;
    const bool mouse = press->kind == twidget::PointerKind::Mouse;
    this->endPress(*press);
    HostState::of(ctx).endPress(number);
    if (primary) {
        HostState::of(ctx).hapticReleased();
    }
    if (!mouse) {
        fireTouch(ctx, "touchcancel", *target, x, y, pointerId, false, false);
    }
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
