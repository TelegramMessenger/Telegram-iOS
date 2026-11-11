// The UI events taps dispatch (M1d plan, Task 2): UI Events' UIEvent, FocusEvent and MouseEvent, Pointer Events'
// PointerEvent, and Touch Events' Touch, TouchList and TouchEvent. Each holds what its constructor's dictionary or the
// tap that made it gave; the references it holds (view, related target, touch targets, touch lists) are counted,
// traced and released, as every payload's are.
#pragma once

#include <cstdint>
#include <vector>

#include "Generated/Bindings.h"
#include "Sources/Events/Event.h"
#include "Sources/Support/Bindings.h"

namespace wr {

class EventTarget;
class Window;

class UIEvent : public Event {
public:
    explicit UIEvent(JSContext* ctx) : Event(ctx) {}
    static Ref<UIEvent> construct(JSContext* ctx, String type, idl::UIEventInit init);
    Window* view(JSContext*);
    int32_t detail(JSContext*) { return m_detail; }

    // Native
    void setView(JSContext* ctx, Window* view);
    void setDetail(int32_t detail) { m_detail = detail; }
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

private:
    Held m_view;
    int32_t m_detail = 0;
};

class FocusEvent : public UIEvent {
public:
    explicit FocusEvent(JSContext* ctx) : UIEvent(ctx) {}
    static Ref<FocusEvent> construct(JSContext* ctx, String type, idl::FocusEventInit init);
    EventTarget* relatedTarget(JSContext*);

    // Native
    void setRelatedTarget(JSContext* ctx, EventTarget* target);
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

private:
    Held m_relatedTarget;
};

/// The modifier keys an event carries (EventModifierInit). A tap has none: iOS has no keyboard path into widgets.
struct Modifiers {
    bool ctrl = false;
    bool shift = false;
    bool alt = false;
    bool meta = false;
    /// UI Events' getModifierState for the four keys the dictionary sets; false for every other key.
    bool state(JSContext* ctx, const String& key) const;
};

class MouseEvent : public UIEvent {
public:
    explicit MouseEvent(JSContext* ctx) : UIEvent(ctx) {}
    static Ref<MouseEvent> construct(JSContext* ctx, String type, idl::MouseEventInit init);
    double screenX(JSContext*) { return m_screenX; }
    double screenY(JSContext*) { return m_screenY; }
    double clientX(JSContext*) { return m_clientX; }
    double clientY(JSContext*) { return m_clientY; }
    /// The widget has no scroll viewport: page coordinates are client coordinates.
    double pageX(JSContext*) { return m_clientX; }
    double pageY(JSContext*) { return m_clientY; }
    double x(JSContext*) { return m_clientX; }
    double y(JSContext*) { return m_clientY; }
    /// Relative to the target's padding edge in CSSOM View. No layout query exists until M2, so the client point.
    double offsetX(JSContext*) { return m_clientX; }
    double offsetY(JSContext*) { return m_clientY; }
    bool ctrlKey(JSContext*) { return m_modifiers.ctrl; }
    bool shiftKey(JSContext*) { return m_modifiers.shift; }
    bool altKey(JSContext*) { return m_modifiers.alt; }
    bool metaKey(JSContext*) { return m_modifiers.meta; }
    int16_t button(JSContext*) { return m_button; }
    uint16_t buttons(JSContext*) { return m_buttons; }
    EventTarget* relatedTarget(JSContext*);
    bool getModifierState(JSContext* ctx, String key) { return m_modifiers.state(ctx, key); }
    double movementX(JSContext*) { return m_movementX; }
    double movementY(JSContext*) { return m_movementY; }

    // Native
    void setPoint(double x, double y) {
        m_screenX = m_clientX = x;
        m_screenY = m_clientY = y;
    }
    void setButtons(int16_t button, uint16_t buttons) {
        m_button = button;
        m_buttons = buttons;
    }
    void setMovement(double x, double y) {
        m_movementX = x;
        m_movementY = y;
    }
    /// DOM "dispatch": a click has activation behaviour to look for (Task 3).
    bool isActivationClick(JSContext* ctx) const override;
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

protected:
    void initMouse(JSContext* ctx, const idl::MouseEventInit& init);

private:
    double m_screenX = 0;
    double m_screenY = 0;
    double m_clientX = 0;
    double m_clientY = 0;
    Modifiers m_modifiers;
    int16_t m_button = 0;
    uint16_t m_buttons = 0;
    double m_movementX = 0;
    double m_movementY = 0;
    Held m_relatedTarget;
};

class PointerEvent : public MouseEvent {
public:
    explicit PointerEvent(JSContext* ctx) : MouseEvent(ctx) {}
    static Ref<PointerEvent> construct(JSContext* ctx, String type, idl::PointerEventInit init);
    int32_t pointerId(JSContext*) { return m_pointerId; }
    double width(JSContext*) { return m_width; }
    double height(JSContext*) { return m_height; }
    double pressure(JSContext*) { return m_pressure; }
    double tangentialPressure(JSContext*) { return m_tangentialPressure; }
    int32_t tiltX(JSContext*) { return m_tiltX; }
    int32_t tiltY(JSContext*) { return m_tiltY; }
    int32_t twist(JSContext*) { return m_twist; }
    double altitudeAngle(JSContext*) { return m_altitudeAngle; }
    double azimuthAngle(JSContext*) { return m_azimuthAngle; }
    String pointerType(JSContext* ctx);
    bool isPrimary(JSContext*) { return m_isPrimary; }
    int32_t persistentDeviceId(JSContext*) { return m_persistentDeviceId; }

    // Native: a touch pointer, as a tap makes it.
    /// A trusted pointer event's pointer: its id, whether it is primary, its pressure and its type ("touch", "pen",
    /// "mouse").
    void setPointer(JSContext* ctx, int32_t pointerId, bool primary, double pressure, std::string_view pointerType);
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

private:
    int32_t m_pointerId = 0;
    double m_width = 1;
    double m_height = 1;
    double m_pressure = 0;
    double m_tangentialPressure = 0;
    int32_t m_tiltX = 0;
    int32_t m_tiltY = 0;
    int32_t m_twist = 0;
    double m_altitudeAngle = 1.5707963267948966;
    double m_azimuthAngle = 0;
    Held m_pointerType;
    bool m_isPrimary = false;
    int32_t m_persistentDeviceId = 0;
};

class Touch : public PlatformObject {
public:
    explicit Touch(JSContext*) {}
    static Ref<Touch> construct(JSContext* ctx, idl::TouchInit init);
    /// A tap's touch point: `identifier` is the host's pointer id; client, page and screen points are the same.
    static Ref<Touch> make(JSContext* ctx, int32_t identifier, EventTarget& target, double x, double y);
    int32_t identifier(JSContext*) { return m_identifier; }
    EventTarget* target(JSContext*);
    double screenX(JSContext*) { return m_screenX; }
    double screenY(JSContext*) { return m_screenY; }
    double clientX(JSContext*) { return m_clientX; }
    double clientY(JSContext*) { return m_clientY; }
    double pageX(JSContext*) { return m_pageX; }
    double pageY(JSContext*) { return m_pageY; }
    double radiusX(JSContext*) { return m_radiusX; }
    double radiusY(JSContext*) { return m_radiusY; }
    double rotationAngle(JSContext*) { return m_rotationAngle; }
    double force(JSContext*) { return m_force; }
    double altitudeAngle(JSContext*) { return m_altitudeAngle; }
    double azimuthAngle(JSContext*) { return m_azimuthAngle; }
    String touchType(JSContext* ctx);
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

private:
    int32_t m_identifier = 0;
    Held m_target;
    double m_screenX = 0;
    double m_screenY = 0;
    double m_clientX = 0;
    double m_clientY = 0;
    double m_pageX = 0;
    double m_pageY = 0;
    double m_radiusX = 0;
    double m_radiusY = 0;
    double m_rotationAngle = 0;
    double m_force = 0;
    double m_altitudeAngle = 0;
    double m_azimuthAngle = 0;
    bool m_stylus = false;
};

/// A fixed list of touches (a tap has at most one).
class TouchList : public PlatformObject {
public:
    explicit TouchList(JSContext* ctx);
    static Ref<TouchList> make(JSContext* ctx, Touch* touch);
    uint32_t length(JSContext*) { return uint32_t(m_touches.size()); }
    Touch* item(JSContext*, uint32_t index);
    JSValue indexedValue(JSContext* ctx, uint32_t index);
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

private:
    Vector<JSValue> m_touches;
};

class TouchEvent : public UIEvent {
public:
    explicit TouchEvent(JSContext* ctx) : UIEvent(ctx) {}
    static Ref<TouchEvent> construct(JSContext* ctx, String type, idl::TouchEventInit init);
    TouchList* touches(JSContext* ctx);
    TouchList* targetTouches(JSContext* ctx);
    TouchList* changedTouches(JSContext* ctx);
    bool altKey(JSContext*) { return m_modifiers.alt; }
    bool metaKey(JSContext*) { return m_modifiers.meta; }
    bool ctrlKey(JSContext*) { return m_modifiers.ctrl; }
    bool shiftKey(JSContext*) { return m_modifiers.shift; }
    bool getModifierState(JSContext* ctx, String key) { return m_modifiers.state(ctx, key); }

    // Native: the lists a tap's phase gives. `touches` and `targetTouches` hold the touch while it is down.
    void setLists(JSContext* ctx, TouchList& touches, TouchList& targetTouches, TouchList& changedTouches);
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

private:
    /// The lists, made empty on first read when nothing set them (a constructed event's).
    TouchList* list(JSContext* ctx, Held& held);
    Held m_touches;
    Held m_targetTouches;
    Held m_changedTouches;
    Modifiers m_modifiers;
};

} // namespace wr
