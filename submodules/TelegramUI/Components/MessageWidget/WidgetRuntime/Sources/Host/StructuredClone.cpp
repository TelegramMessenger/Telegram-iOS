#include "Sources/Host/StructuredClone.h"

#include <optional>
#include <string>
#include <string_view>
#include <unordered_map>

#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Allocator.h"
#include "Sources/Support/Errors.h"

namespace wr {

namespace {

[[noreturn]] void dataCloneError(const char* message) {
    throw DOMError{"DataCloneError", message};
}

/// Throws Thrown when `value` is the exception marker.
JSValue checked(JSValue value) {
    if (JS_IsException(value)) {
        throw Thrown{};
    }
    return value;
}

constexpr std::string_view kErrorNames[] = {"Error", "EvalError", "RangeError", "ReferenceError", "SyntaxError", "TypeError", "URIError"};

/// One clone: the memory map from each source object to its copy (references and cycles), and the depth.
class Cloner {
public:
    explicit Cloner(JSContext* ctx)
        : m_ctx(ctx),
          m_memory(JSAllocator<std::pair<void* const, Value>>(JS_GetRuntime(ctx))) {
        Value plain = Value::adopt(ctx, checked(JS_NewObject(ctx)));
        m_plainClass = JS_GetClassID(plain.get());
    }

    Value clone(JSValueConst value) {
        if (JS_IsSymbol(value)) {
            dataCloneError("A symbol cannot be cloned.");
        }
        if (!JS_IsObject(value)) {
            return Value::dup(m_ctx, value);
        }
        void* key = JS_VALUE_GET_PTR(value);
        if (auto found = m_memory.find(key); found != m_memory.end()) {
            return Value::dup(m_ctx, found->second.get());
        }
        if (m_depth >= kMaxCloneDepth) {
            dataCloneError("The value is nested too deeply to clone.");
        }
        struct Depth {
            size_t& depth;
            explicit Depth(size_t& d) : depth(d) { depth++; }
            ~Depth() { depth--; }
        } depth(m_depth);
        if (JS_IsProxy(value) || JS_IsDataView(value)) {
            dataCloneError("The value cannot be cloned.");
        }
        if (JS_IsArray(value)) {
            int64_t length = 0;
            if (JS_GetLength(m_ctx, value, &length) < 0) {
                throw Thrown{};
            }
            Value copy = Value::adopt(m_ctx, checked(JS_NewArray(m_ctx)));
            if (JS_SetPropertyStr(m_ctx, copy.get(), "length", JS_NewInt64(m_ctx, length)) < 0) {
                throw Thrown{};
            }
            this->remember(key, copy);
            this->copyProperties(value, copy.get());
            return copy;
        }
        if (JS_IsError(value)) {
            return this->cloneError(key, value);
        }
        if (JS_IsArrayBuffer(value)) {
            size_t size = 0;
            const uint8_t* bytes = JS_GetArrayBuffer(m_ctx, &size, value);
            if (!bytes) {
                // Detached (HTML: a DataCloneError). The engine's own TypeError is not this one's.
                this->dropException();
                dataCloneError("A detached ArrayBuffer cannot be cloned.");
            }
            Value copy = Value::adopt(m_ctx, checked(JS_NewArrayBufferCopy(m_ctx, bytes, size)));
            this->remember(key, copy);
            return copy;
        }
        if (const int type = JS_GetTypedArrayType(value); type >= 0) {
            size_t offset = 0, length = 0, elementSize = 1;
            Value buffer = Value::adopt(m_ctx, checked(JS_GetTypedArrayBuffer(m_ctx, value, &offset, &length, &elementSize)));
            Value clonedBuffer = this->clone(buffer.get());
            JSValueConst argv[] = {clonedBuffer.get(), JS_NewInt64(m_ctx, int64_t(offset)),
                                   JS_NewInt64(m_ctx, int64_t(length / (elementSize ? elementSize : 1)))};
            Value copy = Value::adopt(m_ctx, checked(JS_NewTypedArray(m_ctx, 3, argv, JSTypedArrayEnum(type))));
            this->remember(key, copy);
            return copy;
        }
        if (JS_GetClassID(value) == m_plainClass) {
            Value copy = Value::adopt(m_ctx, checked(JS_NewObject(m_ctx)));
            this->remember(key, copy);
            this->copyProperties(value, copy.get());
            return copy;
        }
        if (JS_IsMap(value) || JS_IsSet(value)) {
            return this->cloneCollection(key, value, JS_IsMap(value));
        }
        // Date, RegExp and the primitive wrappers: through the engine's serializer, which reads their internal slots (a
        // widget's overrides of their methods cannot change the clone) and runs no script for them. Every other class
        // (functions, promises, weak collections, platform objects) is one it refuses.
        Value copy = this->throughSerializer(value);
        this->remember(key, copy);
        return copy;
    }

private:
    void remember(void* key, const Value& copy) { m_memory.emplace(key, Value::dup(m_ctx, copy.get())); }

    /// Clears the pending exception, unless the widget is stopping (Thrown then, to stop it).
    void dropException() {
        if (Runtime::from(m_ctx).stopReason() != StopReason::None) {
            throw Thrown{};
        }
        JS_FreeValue(m_ctx, JS_GetException(m_ctx));
    }

    /// HTML's Map and Set serialization: the entries copied first, so a script a later entry runs (a getter) cannot change
    /// which are cloned, then each key and value cloned like any value. Walked through the iterators the runtime took
    /// at startup: an iterator holds a reference to its record, so a source mutated mid-walk is safe (the engine's
    /// serializer held none, and a getter that cleared the map freed the record under it: V5a final review, C3).
    Value cloneCollection(void* key, JSValueConst value, bool isMap) {
        using I = Runtime::Intrinsic;
        const Runtime& runtime = Runtime::from(m_ctx);
        JSValueConst undefined = JS_UNDEFINED;
        Value copy = Value::adopt(m_ctx, checked(JS_CallConstructor(m_ctx, runtime.intrinsic(isMap ? I::MapConstructor : I::SetConstructor), 1, &undefined)));
        this->remember(key, copy);
        Value iterator = Value::adopt(m_ctx, checked(JS_Call(m_ctx, runtime.intrinsic(isMap ? I::MapEntries : I::SetValues), value, 0, nullptr)));
        JSValueConst next = runtime.intrinsic(isMap ? I::MapIteratorNext : I::SetIteratorNext);
        Vector<Value> entries{JSAllocator<Value>(JS_GetRuntime(m_ctx))};
        for (;;) {
            Value result = Value::adopt(m_ctx, checked(JS_Call(m_ctx, next, iterator.get(), 0, nullptr)));
            Value done = Value::adopt(m_ctx, checked(JS_GetPropertyStr(m_ctx, result.get(), "done")));
            if (JS_ToBool(m_ctx, done.get())) {
                break;
            }
            entries.push_back(Value::adopt(m_ctx, checked(JS_GetPropertyStr(m_ctx, result.get(), "value"))));
        }
        JSValueConst add = runtime.intrinsic(isMap ? I::MapSet : I::SetAdd);
        for (const Value& entry : entries) {
            if (isMap) {
                // A fresh [key, value] array the iterator made: its elements are data properties.
                Value k = Value::adopt(m_ctx, checked(JS_GetPropertyUint32(m_ctx, entry.get(), 0)));
                Value v = Value::adopt(m_ctx, checked(JS_GetPropertyUint32(m_ctx, entry.get(), 1)));
                Value clonedKey = this->clone(k.get());
                Value clonedValue = this->clone(v.get());
                JSValueConst argv[] = {clonedKey.get(), clonedValue.get()};
                Value ignored = Value::adopt(m_ctx, checked(JS_Call(m_ctx, add, copy.get(), 2, argv)));
            } else {
                Value cloned = this->clone(entry.get());
                JSValueConst argv[] = {cloned.get()};
                Value ignored = Value::adopt(m_ctx, checked(JS_Call(m_ctx, add, copy.get(), 1, argv)));
            }
        }
        return copy;
    }

    /// HTML's serialize of an ordinary object's own enumerable string-keyed properties, each read with [[Get]] (so a
    /// getter runs) and defined on the copy as a data property.
    void copyProperties(JSValueConst source, JSValueConst copy) {
        JSPropertyEnum* names = nullptr;
        uint32_t count = 0;
        if (JS_GetOwnPropertyNames(m_ctx, &names, &count, source, JS_GPN_STRING_MASK | JS_GPN_ENUM_ONLY) < 0) {
            throw Thrown{};
        }
        struct Names {
            JSContext* ctx;
            JSPropertyEnum* names;
            uint32_t count;
            ~Names() { JS_FreePropertyEnum(ctx, names, count); }
        } owned{m_ctx, names, count};
        for (uint32_t i = 0; i < count; i++) {
            Value value = Value::adopt(m_ctx, checked(JS_GetProperty(m_ctx, source, names[i].atom)));
            Value cloned = this->clone(value.get());
            if (JS_DefinePropertyValue(m_ctx, copy, names[i].atom, JS_DupValue(m_ctx, cloned.get()), JS_PROP_C_W_E) < 0) {
                throw Thrown{};
            }
        }
    }

    /// HTML's Error serialization: the name if it is one of the standard ones (else Error), and the message when it is
    /// an own data property, converted to a string. The message is defined on the copy as a JS string (the engine's
    /// error constructors format it through a 256-byte buffer, which cut a longer one and stopped at a NUL).
    Value cloneError(void* key, JSValueConst value) {
        std::string name = "Error";
        Value nameValue = Value::adopt(m_ctx, checked(JS_GetPropertyStr(m_ctx, value, "name")));
        if (JS_IsString(nameValue.get())) {
            const std::string candidate = String::adopt(m_ctx, JS_DupValue(m_ctx, nameValue.get())).utf8Prefix(32, nullptr);
            for (std::string_view known : kErrorNames) {
                if (candidate == known) {
                    name = candidate;
                }
            }
        }
        std::optional<Value> message;
        Atom messageAtom = Atom::fromUTF8(m_ctx, "message");
        JSPropertyDescriptor descriptor;
        const int own = JS_GetOwnProperty(m_ctx, &descriptor, value, messageAtom.get());
        if (own < 0) {
            throw Thrown{};
        }
        if (own) {
            Value data = Value::adopt(m_ctx, descriptor.value);
            JS_FreeValue(m_ctx, descriptor.getter);
            JS_FreeValue(m_ctx, descriptor.setter);
            if (!(descriptor.flags & JS_PROP_GETSET)) {
                message = Value::adopt(m_ctx, checked(JS_ToString(m_ctx, data.get())));
            }
        }
        // The thrower makes an error with the right prototype; EvalError and URIError have none and come back as Error.
        if (name == "TypeError") {
            JS_ThrowTypeError(m_ctx, "%s", "");
        } else if (name == "RangeError") {
            JS_ThrowRangeError(m_ctx, "%s", "");
        } else if (name == "ReferenceError") {
            JS_ThrowReferenceError(m_ctx, "%s", "");
        } else if (name == "SyntaxError") {
            JS_ThrowSyntaxError(m_ctx, "%s", "");
        } else {
            JS_ThrowPlainError(m_ctx, "%s", "");
        }
        Value copy = Value::adopt(m_ctx, JS_GetException(m_ctx));
        if (message) {
            check(m_ctx, JS_DefinePropertyValue(m_ctx, copy.get(), messageAtom.get(), JS_DupValue(m_ctx, message->get()),
                                                JS_PROP_WRITABLE | JS_PROP_CONFIGURABLE));
        } else {
            JS_DeleteProperty(m_ctx, copy.get(), messageAtom.get(), 0);
        }
        this->remember(key, copy);
        return copy;
    }

    Value throughSerializer(JSValueConst value) {
        size_t size = 0;
        uint8_t* bytes = JS_WriteObject(m_ctx, &size, value, JS_WRITE_OBJ_REFERENCE);
        if (!bytes) {
            if (Runtime::from(m_ctx).stopReason() != StopReason::None) {
                throw Thrown{};
            }
            JS_FreeValue(m_ctx, JS_GetException(m_ctx));
            dataCloneError("The value cannot be cloned.");
        }
        struct Bytes {
            JSContext* ctx;
            uint8_t* bytes;
            ~Bytes() { js_free(ctx, bytes); }
        } owned{m_ctx, bytes};
        return Value::adopt(m_ctx, checked(JS_ReadObject(m_ctx, bytes, size, JS_READ_OBJ_REFERENCE)));
    }

    JSContext* m_ctx;
    JSClassID m_plainClass = 0;
    size_t m_depth = 0;
    std::unordered_map<void*, Value, std::hash<void*>, std::equal_to<void*>, JSAllocator<std::pair<void* const, Value>>> m_memory;
};

} // namespace

Value structuredCloneValue(JSContext* ctx, JSValueConst value) {
    Cloner cloner(ctx);
    return cloner.clone(value);
}

} // namespace wr
