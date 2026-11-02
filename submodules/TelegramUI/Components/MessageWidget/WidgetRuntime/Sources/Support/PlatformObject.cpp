#include "Sources/Support/PlatformObject.h"

#include "Sources/Runtime/Runtime.h"

namespace wr {

void attachPayload(JSValue object, PlatformObject* payload) {
    JS_SetOpaque(object, payload);
    payload->m_object = object;
}

PlatformObject* payloadOfKnown(JSValueConst v) {
    JSClassID id;
    return static_cast<PlatformObject*>(JS_GetAnyOpaque(v, &id));
}

PlatformObject* payloadOf(JSContext* ctx, JSValueConst v) {
    return Runtime::from(ctx).interfaceOf(v) >= 0 ? payloadOfKnown(v) : nullptr;
}

PlatformObject* payloadImplementing(JSContext* ctx, JSValueConst v, uint16_t iface) {
    Runtime& runtime = Runtime::from(ctx);
    int index = runtime.interfaceOf(v);
    return index >= 0 && runtime.implementsInterface(index, iface) ? payloadOfKnown(v) : nullptr;
}

bool isPlatformObject(JSContext* ctx, JSValueConst v) {
    return Runtime::from(ctx).interfaceOf(v) >= 0;
}

void finalizePlatformObject(JSRuntime* rt, JSValueConst v) {
    PlatformObject* payload = payloadOfKnown(v);
    if (!payload) {
        return;
    }
    payload->dispose(rt);
    payload->~PlatformObject();
    js_free_rt(rt, payload);
    if (void* opaque = JS_GetRuntimeOpaque(rt)) {
        static_cast<Runtime*>(opaque)->noteObjectFinalized();
    }
}

void tracePlatformObject(JSRuntime* rt, JSValueConst v, JS_MarkFunc* mark) {
    if (PlatformObject* payload = payloadOfKnown(v)) {
        payload->trace(rt, mark);
    }
}

} // namespace wr
