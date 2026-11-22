#include "Sources/Host/Sequences.h"

#include <string>

#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Errors.h"

namespace wr {

std::optional<std::vector<Value>> sequenceValues(JSContext* ctx, JSValueConst object, const char* what, size_t limit) {
    Value method = Value::adopt(ctx, JS_GetProperty(ctx, object, Runtime::from(ctx).iteratorSymbol()));
    if (JS_IsException(method.get())) {
        throw Thrown{};
    }
    if (JS_IsUndefined(method.get()) || JS_IsNull(method.get())) {
        return std::nullopt;
    }
    Value iterator = Value::adopt(ctx, JS_Call(ctx, method.get(), object, 0, nullptr));
    if (JS_IsException(iterator.get())) {
        throw Thrown{};
    }
    if (!JS_IsObject(iterator.get())) {
        throw TypeError{std::string(what) + ": the iterator is not an object."};
    }
    Value next = Value::adopt(ctx, JS_GetPropertyStr(ctx, iterator.get(), "next"));
    if (JS_IsException(next.get())) {
        throw Thrown{};
    }
    std::vector<Value> values;
    for (;;) {
        if (values.size() == limit) {
            // IteratorClose: the iterator's return(), if it has one; what it throws propagates.
            Value close = Value::adopt(ctx, JS_GetPropertyStr(ctx, iterator.get(), "return"));
            if (JS_IsException(close.get())) {
                throw Thrown{};
            }
            if (!JS_IsUndefined(close.get()) && !JS_IsNull(close.get())) {
                Value closed = Value::adopt(ctx, JS_Call(ctx, close.get(), iterator.get(), 0, nullptr));
                if (JS_IsException(closed.get())) {
                    throw Thrown{};
                }
            }
            return values;
        }
        Value result = Value::adopt(ctx, JS_Call(ctx, next.get(), iterator.get(), 0, nullptr));
        if (JS_IsException(result.get())) {
            throw Thrown{};
        }
        if (!JS_IsObject(result.get())) {
            throw TypeError{std::string(what) + ": the iterator result is not an object."};
        }
        Value done = Value::adopt(ctx, JS_GetPropertyStr(ctx, result.get(), "done"));
        if (JS_IsException(done.get())) {
            throw Thrown{};
        }
        const int finished = JS_ToBool(ctx, done.get());
        if (finished < 0) {
            throw Thrown{};
        }
        if (finished) {
            return values;
        }
        Value value = Value::adopt(ctx, JS_GetPropertyStr(ctx, result.get(), "value"));
        if (JS_IsException(value.get())) {
            throw Thrown{};
        }
        values.push_back(std::move(value));
    }
}

} // namespace wr
