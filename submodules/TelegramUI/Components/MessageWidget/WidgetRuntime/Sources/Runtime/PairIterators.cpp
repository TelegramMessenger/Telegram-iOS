// WebIDL pair iterators (V5a plan, Task 5; WebIDL §3.7.9 "Iterable declarations" and §3.7.10 "Default iterator
// objects"): an interface with `iterable<K, V>` gets entries, keys, values and forEach, and @@iterator is entries. An
// iterator object holds its target, its kind and an index, and each next() reads the target's list afresh, so a change
// to the list during the iteration is seen as WebIDL's index-based iterator sees it.
#include "Sources/Runtime/Runtime.h"

#include "Sources/Support/Bindings.h"
#include "Sources/Support/Errors.h"

namespace wr {

namespace {

enum class PairKind : int { Keys = 0, Values = 1, Entries = 2 };

struct PairIteratorState {
    JSValue target;
    uint16_t iface;
    PairKind kind;
    uint32_t index;
};

// The class is the object's own: these run only on objects of the runtime's pair iterator class, whose ids differ
// between runtimes.
void finalizePairIterator(JSRuntime* rt, JSValueConst value) {
    JSClassID classId = 0;
    auto* state = static_cast<PairIteratorState*>(JS_GetAnyOpaque(value, &classId));
    if (state) {
        JS_FreeValueRT(rt, state->target);
        js_free_rt(rt, state);
    }
}

void markPairIterator(JSRuntime* rt, JSValueConst value, JS_MarkFunc* mark) {
    JSClassID classId = 0;
    auto* state = static_cast<PairIteratorState*>(JS_GetAnyOpaque(value, &classId));
    if (state) {
        JS_MarkValue(rt, state->target, mark);
    }
}

/// { value, done }, built with data properties so a widget's Object.prototype setters see nothing.
JSValue iteratorResult(JSContext* ctx, JSValue value, bool done) {
    Value result = Value::adopt(ctx, JS_NewObject(ctx));
    if (JS_IsException(result.get())) {
        JS_FreeValue(ctx, value);
        throw Thrown{};
    }
    if (JS_DefinePropertyValueStr(ctx, result.get(), "value", value, JS_PROP_C_W_E) < 0 ||
        JS_DefinePropertyValueStr(ctx, result.get(), "done", JS_NewBool(ctx, done), JS_PROP_C_W_E) < 0) {
        throw Thrown{};
    }
    return result.release();
}

} // namespace

void registerPairIteratorClass(JSRuntime* rt, JSClassID& id) {
    id = 0;
    JS_NewClassID(rt, &id);
    JSClassDef def{};
    def.class_name = "Iterator";
    def.finalizer = &finalizePairIterator;
    def.gc_mark = &markPairIterator;
    if (JS_NewClass(rt, id, &def) < 0) {
        throw std::bad_alloc();
    }
}

void Runtime::definePairIteration(uint16_t iface, JSValueConst proto) {
    JSContext* ctx = m_ctx;
    const InterfaceInfo& info = m_table->interfaces[iface];
    auto method = [&](const char* name, int length, JSCFunctionMagic* fn, int magic) {
        return checked(ctx, JS_NewCFunctionMagic(ctx, fn, name, length, JS_CFUNC_generic_magic, magic));
    };
    Value entries = Value::adopt(ctx, method("entries", 0, &Runtime::pairIteratorMethod, (int(iface) << 2) | int(PairKind::Entries)));
    check(ctx, JS_DefinePropertyValueStr(ctx, proto, "entries", JS_DupValue(ctx, entries.get()), JS_PROP_C_W_E));
    check(ctx, JS_DefinePropertyValueStr(ctx, proto, "keys", method("keys", 0, &Runtime::pairIteratorMethod, (int(iface) << 2) | int(PairKind::Keys)), JS_PROP_C_W_E));
    check(ctx, JS_DefinePropertyValueStr(ctx, proto, "values", method("values", 0, &Runtime::pairIteratorMethod, (int(iface) << 2) | int(PairKind::Values)), JS_PROP_C_W_E));
    check(ctx, JS_DefinePropertyValueStr(ctx, proto, "forEach", method("forEach", 1, &Runtime::pairForEach, iface), JS_PROP_C_W_E));
    check(ctx, JS_DefinePropertyValue(ctx, proto, m_iterator, entries.release(), JS_PROP_WRITABLE | JS_PROP_CONFIGURABLE));
    // The interface's iterator prototype.
    Value iteratorProto = Value::adopt(ctx, checked(ctx, JS_NewObjectProto(ctx, m_iteratorPrototype)));
    check(ctx, JS_DefinePropertyValueStr(ctx, iteratorProto.get(), "next", method("next", 0, &Runtime::pairIteratorNext, iface), JS_PROP_C_W_E));
    const std::string tag = std::string(info.name) + " Iterator";
    check(ctx, JS_DefinePropertyValue(ctx, iteratorProto.get(), m_toStringTag, JS_NewString(ctx, tag.c_str()), JS_PROP_CONFIGURABLE));
    JS_FreeValue(ctx, m_pairIteratorPrototypes[iface]);
    m_pairIteratorPrototypes[iface] = iteratorProto.release();
}

JSValue Runtime::pairIteratorMethod(JSContext* ctx, JSValueConst thisVal, int, JSValueConst*, int magic) {
    return glue(ctx, [&]() -> JSValue {
        Runtime& runtime = Runtime::from(ctx);
        const uint16_t iface = uint16_t(magic >> 2);
        const PairIteration& iteration = *runtime.m_table->interfaces[iface].pairIteration;
        // The brand check: the adapter's thisAs throws a TypeError for anything that is not an instance.
        iteration.length(ctx, thisVal);
        Value iterator = Value::adopt(ctx, checked(ctx, JS_NewObjectProtoClass(ctx, runtime.m_pairIteratorPrototypes[iface], runtime.m_pairIteratorClass)));
        auto* state = static_cast<PairIteratorState*>(js_mallocz(ctx, sizeof(PairIteratorState)));
        if (!state) {
            throw Thrown{};
        }
        state->target = JS_DupValue(ctx, thisVal);
        state->iface = iface;
        state->kind = PairKind(magic & 3);
        state->index = 0;
        JS_SetOpaque(iterator.get(), state);
        return iterator.release();
    });
}

JSValue Runtime::pairForEach(JSContext* ctx, JSValueConst thisVal, int argc, JSValueConst* argv, int magic) {
    return glue(ctx, [&]() -> JSValue {
        Runtime& runtime = Runtime::from(ctx);
        const PairIteration& iteration = *runtime.m_table->interfaces[magic].pairIteration;
        JSValueConst callback = argc > 0 ? argv[0] : JS_UNDEFINED;
        JSValueConst thisArg = argc > 1 ? argv[1] : JS_UNDEFINED;
        iteration.length(ctx, thisVal);
        if (!JS_IsFunction(ctx, callback)) {
            throw TypeError{"forEach: the callback is not a function."};
        }
        // WebIDL: the length is read again before every step.
        for (uint32_t i = 0; i < iteration.length(ctx, thisVal); i++) {
            JSValue key = JS_UNDEFINED, value = JS_UNDEFINED;
            iteration.pair(ctx, thisVal, i, &key, &value);
            Value k = Value::adopt(ctx, key), v = Value::adopt(ctx, value);
            JSValueConst args[] = {v.get(), k.get(), thisVal};
            Value result = Value::adopt(ctx, JS_Call(ctx, callback, thisArg, 3, args));
            if (JS_IsException(result.get())) {
                throw Thrown{};
            }
        }
        return JS_UNDEFINED;
    });
}

JSValue Runtime::pairIteratorNext(JSContext* ctx, JSValueConst thisVal, int, JSValueConst*, int magic) {
    return glue(ctx, [&]() -> JSValue {
        Runtime& runtime = Runtime::from(ctx);
        auto* state = static_cast<PairIteratorState*>(JS_GetOpaque(thisVal, runtime.m_pairIteratorClass));
        if (!state || state->iface != uint16_t(magic)) {
            throw TypeError{std::string("next: not a ") + runtime.m_table->interfaces[magic].name + " iterator."};
        }
        const PairIteration& iteration = *runtime.m_table->interfaces[magic].pairIteration;
        // Keep the target alive across the adapters, whatever they run.
        Value target = Value::dup(ctx, state->target);
        if (state->index >= iteration.length(ctx, target.get())) {
            return iteratorResult(ctx, JS_UNDEFINED, true);
        }
        JSValue key = JS_UNDEFINED, value = JS_UNDEFINED;
        iteration.pair(ctx, target.get(), state->index, &key, &value);
        state->index++;
        switch (state->kind) {
        case PairKind::Keys:
            JS_FreeValue(ctx, value);
            return iteratorResult(ctx, key, false);
        case PairKind::Values:
            JS_FreeValue(ctx, key);
            return iteratorResult(ctx, value, false);
        case PairKind::Entries: {
            Value k = Value::adopt(ctx, key), v = Value::adopt(ctx, value);
            Value pair = Value::adopt(ctx, checked(ctx, JS_NewArray(ctx)));
            check(ctx, JS_DefinePropertyValueUint32(ctx, pair.get(), 0, k.release(), JS_PROP_C_W_E));
            check(ctx, JS_DefinePropertyValueUint32(ctx, pair.get(), 1, v.release(), JS_PROP_C_W_E));
            return iteratorResult(ctx, pair.release(), false);
        }
        }
        return iteratorResult(ctx, JS_UNDEFINED, true);
    });
}

} // namespace wr
