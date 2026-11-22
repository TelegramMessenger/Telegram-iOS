#include "Sources/Support/Promises.h"

#include "Sources/Support/Errors.h"

namespace wr {

namespace {

/// argv: the reject function, the name and the message.
JSValue rejectWithDOMExceptionJob(JSContext* ctx, int, JSValueConst* argv) {
    const char* name = JS_ToCString(ctx, argv[1]);
    const char* message = JS_ToCString(ctx, argv[2]);
    if (!name || !message) {
        JS_FreeCString(ctx, name);
        JS_FreeCString(ctx, message);
        return JS_EXCEPTION;
    }
    JS_ThrowDOMException(ctx, name, "%s", message);
    JS_FreeCString(ctx, name);
    JS_FreeCString(ctx, message);
    JSValue error = JS_GetException(ctx);
    JSValue result = JS_Call(ctx, argv[0], JS_UNDEFINED, 1, &error);
    JS_FreeValue(ctx, error);
    return result;
}

void enqueue(JSContext* ctx, JSJobFunc* job, int argc, JSValueConst* argv) {
    if (JS_EnqueueJob(ctx, job, argc, argv) < 0) {
        throw Thrown{};
    }
}

} // namespace

void makePending(JSContext* ctx, PromiseSlot& slot, bool handled) {
    JSValue resolving[2];
    JSValue promise = JS_NewPromiseCapability(ctx, resolving);
    if (JS_IsException(promise)) {
        throw Thrown{};
    }
    JSRuntime* rt = JS_GetRuntime(ctx);
    slot.promise.set(rt, promise);
    slot.resolve.set(rt, resolving[0]);
    slot.reject.set(rt, resolving[1]);
    slot.settled = false;
    if (handled) {
        JS_PromiseMarkAsHandled(ctx, slot.promise.value);
    }
}

void makeResolved(JSContext* ctx, PromiseSlot& slot, JSValueConst value) {
    makePending(ctx, slot, false);
    resolveNow(ctx, slot, value);
}

void resolveNow(JSContext* ctx, PromiseSlot& slot, JSValueConst value) {
    if (slot.settled) {
        return;
    }
    slot.settled = true;
    // Script reading `then` may replace the slot (cancel() makes a new finished promise): call a reference of our own.
    Value resolve = Value::dup(ctx, slot.resolve.value);
    Value result = Value::adopt(ctx, JS_Call(ctx, resolve.get(), JS_UNDEFINED, 1, &value));
    if (JS_IsException(result.get())) {
        throw Thrown{};
    }
}

void queueRejectWithDOMException(JSContext* ctx, PromiseSlot& slot, const char* name, const char* message) {
    if (slot.settled) {
        return;
    }
    Value nameValue = Value::adopt(ctx, JS_NewString(ctx, name));
    Value messageValue = Value::adopt(ctx, JS_NewString(ctx, message));
    if (JS_IsException(nameValue.get()) || JS_IsException(messageValue.get())) {
        throw Thrown{};
    }
    JS_PromiseMarkAsHandled(ctx, slot.promise.value);
    JSValueConst argv[3] = {slot.reject.value, nameValue.get(), messageValue.get()};
    enqueue(ctx, rejectWithDOMExceptionJob, 3, argv);
    slot.settled = true;
}

} // namespace wr
