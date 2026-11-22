#include "Sources/Support/Callbacks.h"

#include "Sources/Runtime/Runtime.h"

namespace wr {

template <> Callback Converter<Callback>::from(JSContext* ctx, JSValueConst v, const ArgInfo& info) {
    if (!JS_IsFunction(ctx, v)) {
        throw TypeError{argumentMessage(info, "is not a function.")};
    }
    return Callback(Value::dup(ctx, v));
}

template <> CallbackInterface Converter<CallbackInterface>::from(JSContext* ctx, JSValueConst v, const ArgInfo& info) {
    if (!JS_IsObject(v)) {
        throw TypeError{argumentMessage(info, "is not an object.")};
    }
    return CallbackInterface(Value::dup(ctx, v));
}

std::optional<LegacyCallback> Converter<std::optional<LegacyCallback>>::from(JSContext* ctx, JSValueConst v, const ArgInfo&) {
    if (!JS_IsObject(v)) {
        return std::nullopt;
    }
    return LegacyCallback(Value::dup(ctx, v));
}

CallResult callFunction(JSContext* ctx, JSValueConst fn, JSValueConst thisArg, int argc, JSValueConst* argv) {
    Runtime& runtime = Runtime::from(ctx);
    // Ruling 6: the JS this runs starts at native depth 0, so its binding calls are outermost again.
    Runtime::ScriptBoundary boundary(runtime);
    runtime.throwIfStopped();
    runtime.enterScript();
    JSValue result = JS_Call(ctx, fn, thisArg, argc, argv);
    return runtime.leaveScript(ctx, result);
}

CallResult callInterface(JSContext* ctx, JSValueConst object, const char* name, JSValueConst thisArg, int argc, JSValueConst* argv) {
    Runtime& runtime = Runtime::from(ctx);
    // It calls JS_Call itself rather than through callFunction, so it opens its own boundary (the operation's Get too
    // runs at native depth 0).
    Runtime::ScriptBoundary boundary(runtime);
    runtime.throwIfStopped();
    runtime.enterScript();
    if (JS_IsFunction(ctx, object)) {
        return runtime.leaveScript(ctx, JS_Call(ctx, object, thisArg, argc, argv));
    }
    JSValue operation = JS_GetPropertyStr(ctx, object, name);
    if (JS_IsException(operation)) {
        return runtime.leaveScript(ctx, JS_EXCEPTION);
    }
    if (!JS_IsFunction(ctx, operation)) {
        JS_FreeValue(ctx, operation);
        JS_ThrowTypeError(ctx, "'%s' is not a function", name);
        return runtime.leaveScript(ctx, JS_EXCEPTION);
    }
    JSValue result = JS_Call(ctx, operation, object, argc, argv);
    JS_FreeValue(ctx, operation);
    return runtime.leaveScript(ctx, result);
}

void throwIfFatal(JSContext* ctx, JSValueConst exception) {
    Runtime::from(ctx).throwIfFatal(ctx, exception);
}

void abortForCaughtException(JSContext* ctx) {
    Runtime::from(ctx).abortForCaughtException(ctx);
}

} // namespace wr
