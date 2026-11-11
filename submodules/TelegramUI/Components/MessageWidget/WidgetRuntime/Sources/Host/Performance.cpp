#include "Sources/Host/Performance.h"

#include "Sources/Events/Event.h"
#include "Sources/Host/HostState.h"

namespace wr {

double Performance::now(JSContext* ctx) {
    return currentHighResTime(ctx);
}

double Performance::timeOrigin(JSContext* ctx) {
    return HostState::of(ctx).wallTimeOrigin();
}

Object Performance::toJSON(JSContext* ctx) {
    Value object = Value::adopt(ctx, checked(ctx, JS_NewObject(ctx)));
    check(ctx, JS_DefinePropertyValueStr(ctx, object.get(), "timeOrigin", JS_NewFloat64(ctx, this->timeOrigin(ctx)), JS_PROP_C_W_E));
    return Object(std::move(object));
}

} // namespace wr
