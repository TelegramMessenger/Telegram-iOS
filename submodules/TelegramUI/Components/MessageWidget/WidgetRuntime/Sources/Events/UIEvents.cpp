#include "Sources/Events/UIEvents.h"

#include "Generated/Bindings.h"
#include "Sources/DOM/DOM.h"
#include "Sources/Events/EventTarget.h"
#include "Sources/Host/Window.h"

namespace wr {

namespace {

// A counted reference to `payload`'s object in `held`, or none.
void hold(JSContext* ctx, Held& held, PlatformObject* payload) {
    held.set(JS_GetRuntime(ctx), payload ? JS_DupValue(ctx, payload->object()) : JS_UNDEFINED);
}

template <class T>
T* heldPayload(const Held& held) {
    return held.isUndefined() ? nullptr : static_cast<T*>(payloadOfKnown(held.value));
}

} // namespace

// UIEvent

Ref<UIEvent> UIEvent::construct(JSContext* ctx, String type, idl::UIEventInit init) {
    Ref<UIEvent> event = create<UIEvent>(ctx, idl::kUIEvent, ctx);
    event->constructWith(ctx, type, init.bubbles, init.cancelable, init.composed);
    event->setView(ctx, init.view);
    event->m_detail = init.detail;
    return event;
}

Window* UIEvent::view(JSContext*) {
    return heldPayload<Window>(m_view);
}

void UIEvent::setView(JSContext* ctx, Window* view) {
    hold(ctx, m_view, view);
}

void UIEvent::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    m_view.mark(rt, mark);
    Event::trace(rt, mark);
}

void UIEvent::dispose(JSRuntime* rt) {
    m_view.clear(rt);
    Event::dispose(rt);
}

// FocusEvent

Ref<FocusEvent> FocusEvent::construct(JSContext* ctx, String type, idl::FocusEventInit init) {
    Ref<FocusEvent> event = create<FocusEvent>(ctx, idl::kFocusEvent, ctx);
    event->constructWith(ctx, type, init.bubbles, init.cancelable, init.composed);
    event->setView(ctx, init.view);
    event->setDetail(init.detail);
    event->setRelatedTarget(ctx, init.relatedTarget);
    return event;
}

EventTarget* FocusEvent::relatedTarget(JSContext*) {
    return heldPayload<EventTarget>(m_relatedTarget);
}

void FocusEvent::setRelatedTarget(JSContext* ctx, EventTarget* target) {
    hold(ctx, m_relatedTarget, target);
}

void FocusEvent::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    m_relatedTarget.mark(rt, mark);
    UIEvent::trace(rt, mark);
}

void FocusEvent::dispose(JSRuntime* rt) {
    m_relatedTarget.clear(rt);
    UIEvent::dispose(rt);
}

// Modifiers

bool Modifiers::state(JSContext*, const String& key) const {
    return (key.equalsASCII("Control") && ctrl) || (key.equalsASCII("Shift") && shift) ||
           (key.equalsASCII("Alt") && alt) || (key.equalsASCII("Meta") && meta);
}

// MouseEvent

Ref<MouseEvent> MouseEvent::construct(JSContext* ctx, String type, idl::MouseEventInit init) {
    Ref<MouseEvent> event = create<MouseEvent>(ctx, idl::kMouseEvent, ctx);
    event->constructWith(ctx, type, init.bubbles, init.cancelable, init.composed);
    event->initMouse(ctx, init);
    return event;
}

void MouseEvent::initMouse(JSContext* ctx, const idl::MouseEventInit& init) {
    this->setView(ctx, init.view);
    this->setDetail(init.detail);
    m_screenX = init.screenX;
    m_screenY = init.screenY;
    m_clientX = init.clientX;
    m_clientY = init.clientY;
    m_modifiers = Modifiers{init.ctrlKey, init.shiftKey, init.altKey, init.metaKey};
    m_button = init.button;
    m_buttons = init.buttons;
    m_movementX = init.movementX;
    m_movementY = init.movementY;
    hold(ctx, m_relatedTarget, init.relatedTarget);
}

EventTarget* MouseEvent::relatedTarget(JSContext*) {
    return heldPayload<EventTarget>(m_relatedTarget);
}

bool MouseEvent::isActivationClick(JSContext* ctx) const {
    return const_cast<MouseEvent*>(this)->type(ctx).equalsASCII("click");
}

void MouseEvent::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    m_relatedTarget.mark(rt, mark);
    UIEvent::trace(rt, mark);
}

void MouseEvent::dispose(JSRuntime* rt) {
    m_relatedTarget.clear(rt);
    UIEvent::dispose(rt);
}

// PointerEvent

Ref<PointerEvent> PointerEvent::construct(JSContext* ctx, String type, idl::PointerEventInit init) {
    Ref<PointerEvent> event = create<PointerEvent>(ctx, idl::kPointerEvent, ctx);
    event->constructWith(ctx, type, init.bubbles, init.cancelable, init.composed);
    idl::MouseEventInit mouse;
    mouse.view = init.view;
    mouse.detail = init.detail;
    mouse.screenX = init.screenX;
    mouse.screenY = init.screenY;
    mouse.clientX = init.clientX;
    mouse.clientY = init.clientY;
    mouse.ctrlKey = init.ctrlKey;
    mouse.shiftKey = init.shiftKey;
    mouse.altKey = init.altKey;
    mouse.metaKey = init.metaKey;
    mouse.button = init.button;
    mouse.buttons = init.buttons;
    mouse.relatedTarget = init.relatedTarget;
    event->initMouse(ctx, mouse);
    event->m_pointerId = init.pointerId;
    event->m_width = init.width;
    event->m_height = init.height;
    event->m_pressure = init.pressure;
    event->m_tangentialPressure = init.tangentialPressure;
    event->m_tiltX = init.tiltX;
    event->m_tiltY = init.tiltY;
    event->m_twist = init.twist;
    event->m_altitudeAngle = init.altitudeAngle;
    event->m_azimuthAngle = init.azimuthAngle;
    event->m_pointerType.set(JS_GetRuntime(ctx), JS_DupValue(ctx, init.pointerType.value()));
    event->m_isPrimary = init.isPrimary;
    event->m_persistentDeviceId = init.persistentDeviceId;
    return event;
}

String PointerEvent::pointerType(JSContext* ctx) {
    return m_pointerType.isUndefined() ? String::fromUTF8(ctx, "")
                                       : String::adopt(ctx, JS_DupValue(ctx, m_pointerType.value));
}

void PointerEvent::setPointer(JSContext* ctx, int32_t pointerId, bool primary, double pressure, std::string_view pointerType) {
    m_pointerId = pointerId;
    m_isPrimary = primary;
    m_pressure = pressure;
    m_pointerType.set(JS_GetRuntime(ctx), JS_NewStringLen(ctx, pointerType.data(), pointerType.size()));
}

void PointerEvent::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    m_pointerType.mark(rt, mark);
    MouseEvent::trace(rt, mark);
}

void PointerEvent::dispose(JSRuntime* rt) {
    m_pointerType.clear(rt);
    MouseEvent::dispose(rt);
}

// Touch

Ref<Touch> Touch::construct(JSContext* ctx, idl::TouchInit init) {
    Ref<Touch> touch = create<Touch>(ctx, idl::kTouch, ctx);
    touch->m_identifier = init.identifier;
    hold(ctx, touch->m_target, init.target);
    touch->m_screenX = init.screenX;
    touch->m_screenY = init.screenY;
    touch->m_clientX = init.clientX;
    touch->m_clientY = init.clientY;
    touch->m_pageX = init.pageX;
    touch->m_pageY = init.pageY;
    touch->m_radiusX = init.radiusX;
    touch->m_radiusY = init.radiusY;
    touch->m_rotationAngle = init.rotationAngle;
    touch->m_force = init.force;
    touch->m_altitudeAngle = init.altitudeAngle;
    touch->m_azimuthAngle = init.azimuthAngle;
    touch->m_stylus = init.touchType.equalsASCII("stylus");
    return touch;
}

Ref<Touch> Touch::make(JSContext* ctx, int32_t identifier, EventTarget& target, double x, double y) {
    Ref<Touch> touch = create<Touch>(ctx, idl::kTouch, ctx);
    touch->m_identifier = identifier;
    hold(ctx, touch->m_target, &target);
    touch->m_screenX = touch->m_clientX = touch->m_pageX = x;
    touch->m_screenY = touch->m_clientY = touch->m_pageY = y;
    touch->m_force = 0.5;
    return touch;
}

EventTarget* Touch::target(JSContext*) {
    return heldPayload<EventTarget>(m_target);
}

String Touch::touchType(JSContext* ctx) {
    return String::fromUTF8(ctx, m_stylus ? "stylus" : "direct");
}

void Touch::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    m_target.mark(rt, mark);
}

void Touch::dispose(JSRuntime* rt) {
    m_target.clear(rt);
}

// TouchList

TouchList::TouchList(JSContext* ctx) : m_touches(JSAllocator<JSValue>(JS_GetRuntime(ctx))) {}

Ref<TouchList> TouchList::make(JSContext* ctx, Touch* touch) {
    Ref<TouchList> list = create<TouchList>(ctx, idl::kTouchList, ctx);
    if (touch) {
        list->m_touches.push_back(JS_DupValue(ctx, touch->object()));
    }
    return list;
}

Touch* TouchList::item(JSContext*, uint32_t index) {
    return index < m_touches.size() ? static_cast<Touch*>(payloadOfKnown(m_touches[index])) : nullptr;
}

JSValue TouchList::indexedValue(JSContext* ctx, uint32_t index) {
    return index < m_touches.size() ? JS_DupValue(ctx, m_touches[index]) : JS_UNDEFINED;
}

void TouchList::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    for (JSValue value : m_touches) {
        JS_MarkValue(rt, value, mark);
    }
}

void TouchList::dispose(JSRuntime* rt) {
    for (JSValue value : m_touches) {
        JS_FreeValueRT(rt, value);
    }
    m_touches.clear();
}

// TouchEvent

Ref<TouchEvent> TouchEvent::construct(JSContext* ctx, String type, idl::TouchEventInit init) {
    Ref<TouchEvent> event = create<TouchEvent>(ctx, idl::kTouchEvent, ctx);
    event->constructWith(ctx, type, init.bubbles, init.cancelable, init.composed);
    event->setView(ctx, init.view);
    event->setDetail(init.detail);
    event->m_modifiers = Modifiers{init.ctrlKey, init.shiftKey, init.altKey, init.metaKey};
    return event;
}

TouchList* TouchEvent::list(JSContext* ctx, Held& held) {
    if (held.isUndefined()) {
        Ref<TouchList> empty = TouchList::make(ctx, nullptr);
        held.set(JS_GetRuntime(ctx), empty.release());
    }
    return heldPayload<TouchList>(held);
}

TouchList* TouchEvent::touches(JSContext* ctx) {
    return this->list(ctx, m_touches);
}

TouchList* TouchEvent::targetTouches(JSContext* ctx) {
    return this->list(ctx, m_targetTouches);
}

TouchList* TouchEvent::changedTouches(JSContext* ctx) {
    return this->list(ctx, m_changedTouches);
}

void TouchEvent::setLists(JSContext* ctx, TouchList& touches, TouchList& targetTouches, TouchList& changedTouches) {
    hold(ctx, m_touches, &touches);
    hold(ctx, m_targetTouches, &targetTouches);
    hold(ctx, m_changedTouches, &changedTouches);
}

void TouchEvent::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    m_touches.mark(rt, mark);
    m_targetTouches.mark(rt, mark);
    m_changedTouches.mark(rt, mark);
    UIEvent::trace(rt, mark);
}

void TouchEvent::dispose(JSRuntime* rt) {
    m_touches.clear(rt);
    m_targetTouches.clear(rt);
    m_changedTouches.clear(rt);
    UIEvent::dispose(rt);
}

} // namespace wr
