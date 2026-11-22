#include "Sources/Host/Window.h"
#include "Sources/Host/TelegramWidget.h"

#include "Generated/Bindings.h"
#include "Sources/DOM/DOM.h"
#include "Sources/Host/Base64.h"
#include "Sources/Host/StructuredClone.h"
#include "Sources/Host/Crypto.h"
#include "Sources/Host/ErrorReporting.h"
#include "Sources/Host/EventLoop.h"
#include "Sources/Host/Links.h"
#include "Sources/Host/Location.h"
#include "Sources/Host/Performance.h"

namespace wr {

namespace {

/// The job queueMicrotask queues. HTML invokes the callback with this undefined (QuickJS's own queueMicrotask, which
/// installGlobalMembers deleted, passes the global object). What it throws is the job's exception: the checkpoint
/// reports it.
JSValue microtaskJob(JSContext* ctx, int argc, JSValueConst* argv) {
    return JS_Call(ctx, argv[0], JS_UNDEFINED, 0, nullptr);
}

} // namespace

Document* Window::document(JSContext* ctx) {
    return &DOMState::of(ctx).document();
}

Location* Window::location(JSContext* ctx) {
    if (m_location.isUndefined()) {
        m_location.set(JS_GetRuntime(ctx), create<Location>(ctx, idl::kLocation).release());
    }
    return static_cast<Location*>(payloadOfKnown(m_location.value));
}

wr::TelegramWidget* Window::TelegramWidget(JSContext* ctx) {
    if (m_telegramWidget.isUndefined()) {
        m_telegramWidget.set(JS_GetRuntime(ctx), create<wr::TelegramWidget>(ctx, idl::kTelegramWidget, ctx).release());
    }
    return static_cast<wr::TelegramWidget*>(payloadOfKnown(m_telegramWidget.value));
}

Navigator* Window::navigator(JSContext* ctx) {
    if (m_navigator.isUndefined()) {
        m_navigator.set(JS_GetRuntime(ctx), create<Navigator>(ctx, idl::kNavigator).release());
    }
    return static_cast<Navigator*>(payloadOfKnown(m_navigator.value));
}

Value Window::open(JSContext* ctx, String url, String, String) {
    // SDK v1 §2.5: an <a href>'s route, and always null (no browsing contexts).
    if (!url.empty()) {
        followLink(ctx, url);
    }
    return Value::adopt(ctx, JS_NULL);
}

Value Window::structuredClone(JSContext* ctx, Value value, std::optional<Value> options) {
    if (options && JS_IsObject(options->get())) {
        Value transfer = Value::adopt(ctx, JS_GetPropertyStr(ctx, options->get(), "transfer"));
        if (JS_IsException(transfer.get())) {
            throw Thrown{};
        }
        int64_t length = 0;
        if (!JS_IsUndefined(transfer.get()) && (JS_GetLength(ctx, transfer.get(), &length) < 0)) {
            throw Thrown{};
        }
        if (length > 0) {
            throw DOMError{"DataCloneError", "structuredClone: transferring is not supported."};
        }
    }
    return structuredCloneValue(ctx, value.get());
}

String Window::btoa(JSContext* ctx, String data) {
    return base64Encode(ctx, data);
}

String Window::atob(JSContext* ctx, String data) {
    return forgivingBase64Decode(ctx, data);
}

Crypto* Window::crypto(JSContext* ctx) {
    if (m_crypto.isUndefined()) {
        m_crypto.set(JS_GetRuntime(ctx), create<Crypto>(ctx, idl::kCrypto).release());
    }
    return static_cast<Crypto*>(payloadOfKnown(m_crypto.value));
}

Performance* Window::performance(JSContext* ctx) {
    if (m_performance.isUndefined()) {
        m_performance.set(JS_GetRuntime(ctx), create<Performance>(ctx, idl::kPerformance).release());
    }
    return static_cast<Performance*>(payloadOfKnown(m_performance.value));
}

void Window::queueMicrotask(JSContext* ctx, Callback callback) {
    // The job holds its own reference to the callback until it has run.
    JSValueConst fn = callback.get();
    check(ctx, JS_EnqueueJob(ctx, &microtaskJob, 1, &fn));
}

void Window::reportError(JSContext* ctx, Value e) {
    reportTheException(ctx, e.release());
}

int32_t Window::setTimeout(JSContext* ctx, std::variant<String, Callback> handler, int32_t timeout, std::vector<Value> arguments) {
    return EventLoop::of(ctx).timers().start(ctx, std::move(handler), timeout, std::move(arguments), false);
}

int32_t Window::setInterval(JSContext* ctx, std::variant<String, Callback> handler, int32_t timeout, std::vector<Value> arguments) {
    return EventLoop::of(ctx).timers().start(ctx, std::move(handler), timeout, std::move(arguments), true);
}

void Window::clearTimeout(JSContext* ctx, int32_t id) {
    EventLoop::of(ctx).timers().clear(ctx, id);
}

void Window::clearInterval(JSContext* ctx, int32_t id) {
    EventLoop::of(ctx).timers().clear(ctx, id);
}

uint32_t Window::requestAnimationFrame(JSContext* ctx, Callback callback) {
    return EventLoop::of(ctx).animationFrames().request(ctx, std::move(callback));
}

void Window::cancelAnimationFrame(JSContext* ctx, uint32_t handle) {
    EventLoop::of(ctx).animationFrames().cancel(ctx, handle);
}

bool Window::defaultPassive(JSContext* ctx, JSAtom type) {
    DOMState& state = DOMState::of(ctx);
    return type == state.name(Name::touchstart) || type == state.name(Name::touchmove) || type == state.name(Name::wheel) ||
           type == state.name(Name::mousewheel);
}

void Window::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    m_location.mark(rt, mark);
    m_telegramWidget.mark(rt, mark);
    m_navigator.mark(rt, mark);
    m_performance.mark(rt, mark);
    m_localStorage.mark(rt, mark);
    m_sessionStorage.mark(rt, mark);
    m_crypto.mark(rt, mark);
    if (m_heldMediaQueryLists) {
        for (const Held& held : *m_heldMediaQueryLists) {
            held.mark(rt, mark);
        }
    }
    if (m_observers) {
        for (const Held& held : *m_observers) {
            held.mark(rt, mark);
        }
    }
    EventTarget::trace(rt, mark);
}

void Window::dispose(JSRuntime* rt) {
    m_location.clear(rt);
    m_telegramWidget.clear(rt);
    m_navigator.clear(rt);
    m_performance.clear(rt);
    m_localStorage.clear(rt);
    m_sessionStorage.clear(rt);
    m_crypto.clear(rt);
    if (m_heldMediaQueryLists) {
        for (Held& held : *m_heldMediaQueryLists) {
            held.clear(rt);
        }
        std::destroy_at(m_heldMediaQueryLists);
        js_free_rt(rt, m_heldMediaQueryLists);
        m_heldMediaQueryLists = nullptr;
    }
    if (m_observers) {
        for (Held& held : *m_observers) {
            held.clear(rt);
        }
        std::destroy_at(m_observers);
        js_free_rt(rt, m_observers);
        m_observers = nullptr;
    }
    EventTarget::dispose(rt);
}

void Window::holdObserver(JSContext* ctx, PlatformObject& observer) {
    if (!m_observers) {
        void* memory = js_malloc(ctx, sizeof(Vector<Held>));
        if (!memory) {
            throw Thrown{};
        }
        m_observers = new (memory) Vector<Held>(JSAllocator<Held>(JS_GetRuntime(ctx)));
    }
    m_observers->push_back(Held{observer.newRef(ctx)});
}

void Window::releaseObserver(JSContext* ctx, PlatformObject& observer) {
    if (!m_observers) {
        return;
    }
    for (size_t i = 0; i < m_observers->size(); i++) {
        if (payloadOfKnown((*m_observers)[i].value) == &observer) {
            Held held = (*m_observers)[i];
            m_observers->erase(m_observers->begin() + ptrdiff_t(i));
            // Possibly the observer's last reference: nothing touches it after this.
            held.clear(JS_GetRuntime(ctx));
            return;
        }
    }
}

} // namespace wr
