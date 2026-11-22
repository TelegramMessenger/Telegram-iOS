// HTMLCanvasElement (V5d plan, Task 3; HTML "The canvas element"): the width and height that size its bitmap, the 2D
// context, and the read-back members profile 1 leaves out.
#pragma once

#include <optional>

#include "Sources/DOM/DOM.h"

namespace wr {

class CanvasRenderingContext2D;

class HTMLCanvasElement : public HTMLElement {
public:
    using HTMLElement::HTMLElement;

    /// HTML's reflection of an unsigned long with a default: the attribute as a non-negative integer up to
    /// 2147483647, else 300 (width) or 150 (height). Setting one past that range sets the default.
    uint32_t width(JSContext* ctx) const;
    uint32_t height(JSContext* ctx) const;
    void setWidth(JSContext* ctx, uint32_t value);
    void setHeight(JSContext* ctx, uint32_t value);

    /// "2d" (case-sensitive): the element's one CanvasRenderingContext2D, made on the first call; anything else null.
    Value getContext(JSContext* ctx, String contextId, std::optional<Value> options);
    /// Profile 1 hands no pixels back: "data:,", an empty image.
    USVString toDataURL(JSContext* ctx, String type, std::optional<Value> quality);
    /// Calls `callback` with null from a queued task; a non-callable `callback` is a TypeError.
    void toBlob(JSContext* ctx, Value callback, String type, std::optional<Value> quality);
    /// OffscreenCanvas is out: always a NotSupportedError.
    void transferControlToOffscreen(JSContext* ctx);

    /// A process-unique number for this canvas, which its twcanvas: source names (V5d plan, Task 4).
    uint64_t serial() const { return m_serial; }
    /// The 2D context, or nullptr before getContext("2d").
    CanvasRenderingContext2D* context() const { return m_contextImpl; }
    /// The width or height attribute was set, changed or removed (CanvasState's change steps): HTML resets the bitmap
    /// and the context to their defaults, even for the same value.
    void dimensionsChanged(JSContext* ctx);

    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

private:
    static uint64_t nextSerial();
    uint64_t m_serial = nextSerial();
    Held m_context;
    /// The payload of m_context's object, which m_context keeps alive.
    CanvasRenderingContext2D* m_contextImpl = nullptr;
};

} // namespace wr
