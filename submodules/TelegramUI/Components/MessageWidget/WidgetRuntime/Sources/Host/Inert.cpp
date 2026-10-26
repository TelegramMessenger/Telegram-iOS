#include "Sources/Host/Inert.h"

#include "Sources/DOM/DOM.h"
#include "Sources/Host/Globals.h"
#include "Sources/Support/Errors.h"

namespace wr {

Value rejectedWithDOMException(JSContext* ctx, const char* name, const char* message) {
    JS_ThrowDOMException(ctx, name, "%s", message);
    Value error = Value::adopt(ctx, JS_GetException(ctx));
    JSValue resolving[2];
    Value promise = Value::adopt(ctx, JS_NewPromiseCapability(ctx, resolving));
    if (JS_IsException(promise.get())) {
        throw Thrown{};
    }
    Value resolve = Value::adopt(ctx, resolving[0]);
    Value reject = Value::adopt(ctx, resolving[1]);
    JSValueConst argv[1] = {error.get()};
    Value result = Value::adopt(ctx, JS_Call(ctx, reject.get(), JS_UNDEFINED, 1, argv));
    if (JS_IsException(result.get())) {
        throw Thrown{};
    }
    return promise;
}

void throwNetworkDisabled() {
    throw DOMError{"NetworkDisabledError", "Widgets have no network access."};
}

Value Window::fetch(JSContext* ctx, std::vector<Value>) {
    return rejectedWithDOMException(ctx, "NetworkDisabledError", "Widgets have no network access.");
}

void Window::importScripts(JSContext*, std::vector<Value>) {
    throwNetworkDisabled();
}

Value Element::requestFullscreen(JSContext* ctx, std::vector<Value>) {
    return rejectedWithDOMException(ctx, "NotAllowedError", "A widget cannot go full screen.");
}

} // namespace wr
