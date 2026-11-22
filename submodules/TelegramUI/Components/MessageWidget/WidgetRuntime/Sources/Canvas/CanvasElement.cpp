#include "Sources/Canvas/CanvasElement.h"

#include <atomic>
#include <string>

#include "Generated/Bindings.h"
#include "Sources/Canvas/CanvasContext2D.h"
#include "Sources/Canvas/CanvasState.h"
#include "Sources/DOM/DOMState.h"
#include "Sources/Host/ErrorReporting.h"
#include "Sources/Host/EventLoop.h"
#include "Sources/Support/Errors.h"

namespace wr {

namespace {

constexpr uint32_t kMaxReflected = 2147483647;

/// HTML's "rules for parsing non-negative integers": leading ASCII whitespace, an optional '+', digits; anything after
/// the digits ignored. nullopt for no digits or a value past 2147483647.
std::optional<uint32_t> nonNegativeInteger(const std::string& s) {
    size_t i = 0;
    while (i < s.size() && (s[i] == ' ' || s[i] == '\t' || s[i] == '\n' || s[i] == '\f' || s[i] == '\r')) {
        i++;
    }
    if (i < s.size() && s[i] == '+') {
        i++;
    }
    if (i >= s.size() || s[i] < '0' || s[i] > '9') {
        return std::nullopt;
    }
    uint64_t value = 0;
    for (; i < s.size() && s[i] >= '0' && s[i] <= '9'; i++) {
        value = value * 10 + uint64_t(s[i] - '0');
        if (value > kMaxReflected) {
            return std::nullopt;
        }
    }
    return uint32_t(value);
}

uint32_t reflectedDimension(JSContext* ctx, const Element& element, Name name, uint32_t fallback) {
    std::optional<String> value = element.attributeValue(ctx, DOMState::of(ctx).name(name));
    if (!value) {
        return fallback;
    }
    // A long attribute value parses no further than its digits: only a prefix is converted.
    std::optional<uint32_t> parsed = nonNegativeInteger(value->utf8Prefix(64, nullptr));
    return parsed ? *parsed : fallback;
}

void setReflectedDimension(JSContext* ctx, Element& element, Name name, uint32_t value, uint32_t fallback) {
    const uint32_t stored = value <= kMaxReflected ? value : fallback;
    element.setAttributeValue(ctx, DOMState::of(ctx).name(name), String::fromUTF8(ctx, std::to_string(stored)));
}

} // namespace

uint64_t HTMLCanvasElement::nextSerial() {
    static std::atomic<uint64_t> next{1};
    return next.fetch_add(1, std::memory_order_relaxed);
}

uint32_t HTMLCanvasElement::width(JSContext* ctx) const { return reflectedDimension(ctx, *this, Name::width, 300); }
uint32_t HTMLCanvasElement::height(JSContext* ctx) const { return reflectedDimension(ctx, *this, Name::height, 150); }
void HTMLCanvasElement::setWidth(JSContext* ctx, uint32_t value) { setReflectedDimension(ctx, *this, Name::width, value, 300); }
void HTMLCanvasElement::setHeight(JSContext* ctx, uint32_t value) { setReflectedDimension(ctx, *this, Name::height, value, 150); }

Value HTMLCanvasElement::getContext(JSContext* ctx, String contextId, std::optional<Value>) {
    if (!contextId.equalsASCII("2d")) {
        return Value::adopt(ctx, JS_NULL);
    }
    if (!m_contextImpl) {
        // Its change steps watch every canvas's width and height from now on.
        canvas::CanvasState::of(ctx);
        Ref<CanvasRenderingContext2D> made =
            create<CanvasRenderingContext2D>(ctx, idl::kCanvasRenderingContext2D, ctx, *this, this->object());
        m_contextImpl = made.get();
        m_context.set(JS_GetRuntime(ctx), made->newRef(ctx));
    }
    return Value::dup(ctx, m_context.value);
}

USVString HTMLCanvasElement::toDataURL(JSContext* ctx, String, std::optional<Value>) {
    return USVString(String::fromUTF8(ctx, "data:,"));
}

void HTMLCanvasElement::toBlob(JSContext* ctx, Value callback, String, std::optional<Value>) {
    if (!JS_IsFunction(ctx, callback.get())) {
        throw TypeError{"HTMLCanvasElement.toBlob: the callback is not a function."};
    }
    EventLoop::of(ctx).queueTask(TaskSource::DOMManipulation, makeTask(ctx, [callback = std::move(callback)](JSContext* ctx) {
        JSValue argv[] = {JS_NULL};
        invokeWithReport(ctx, callback.get(), JS_UNDEFINED, 1, argv);
    }));
}

void HTMLCanvasElement::transferControlToOffscreen(JSContext*) {
    throw DOMError{"NotSupportedError", "HTMLCanvasElement.transferControlToOffscreen: OffscreenCanvas is not available."};
}

void HTMLCanvasElement::dimensionsChanged(JSContext* ctx) {
    if (m_contextImpl) {
        m_contextImpl->dimensionsChanged(ctx);
    }
}

void HTMLCanvasElement::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    m_context.mark(rt, mark);
    HTMLElement::trace(rt, mark);
}

void HTMLCanvasElement::dispose(JSRuntime* rt) {
    m_contextImpl = nullptr;
    m_context.clear(rt);
    HTMLElement::dispose(rt);
}

} // namespace wr
