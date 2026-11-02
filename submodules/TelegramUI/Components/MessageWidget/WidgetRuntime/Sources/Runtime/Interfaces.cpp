// Making an interface (WebIDL "create an interface object" and "create an interface prototype object"), once, when a
// script reads it from the global or the first object of its class is created.
#include "Sources/Runtime/Runtime.h"

#include <stdexcept>
#include <string>

namespace wr {

static JSValue illegalConstructor(JSContext* ctx, JSValueConst, int, JSValueConst*) {
    return JS_ThrowTypeError(ctx, "Illegal constructor");
}

void Runtime::materialize(uint16_t i) {
    if (!JS_IsUndefined(m_prototypes[i])) {
        return;
    }
    JSContext* ctx = m_ctx;
    const InterfaceInfo& info = m_table->interfaces[i];

    Value parentPrototype;
    Value parentObject;
    if (info.parent >= 0) {
        this->materialize(uint16_t(info.parent));
        parentPrototype = Value::dup(ctx, m_prototypes[info.parent]);
        parentObject = Value::dup(ctx, m_interfaceObjects[info.parent]);
    } else {
        Value plain = Value::adopt(ctx, checked(ctx, JS_NewObject(ctx)));
        parentPrototype = Value::adopt(ctx, checked(ctx, JS_GetPrototype(ctx, plain.get())));
    }
    Value proto = Value::adopt(ctx, checked(ctx, JS_NewObjectProto(ctx, parentPrototype.get())));
    JSCFunction* constructor = info.constructor ? info.constructor : &illegalConstructor;
    Value object = Value::adopt(ctx, checked(ctx, JS_NewCFunction2(ctx, constructor, info.name, info.constructorLength, JS_CFUNC_constructor, 0)));
    if (info.parent >= 0) {
        check(ctx, JS_SetPrototype(ctx, object.get(), parentObject.get()));
    }
    // object.prototype (not writable, enumerable or configurable) and prototype.constructor (writable, configurable).
    check(ctx, JS_SetConstructor(ctx, object.get(), proto.get()));

    Value unscopables;
    for (uint16_t m = 0; m < info.memberCount; m++) {
        const MemberDef& def = info.members[m];
        // [LegacyUnforgeable] members are own properties of each instance (defineUnforgeableMembers), and a [Global]
        // interface's regular members own properties of the global (installGlobalMembers). Neither is on the
        // prototype. Constants and static members stay where they are.
        if (def.kind != MemberKind::Constant && !def.isStatic && (def.unforgeable || info.isGlobal)) {
            continue;
        }
        JSValueConst target = def.isStatic ? object.get() : proto.get();
        switch (def.kind) {
        case MemberKind::Constant:
            check(ctx, JS_DefinePropertyValueStr(ctx, proto.get(), def.name, JS_NewInt64(ctx, def.constValue), JS_PROP_ENUMERABLE));
            check(ctx, JS_DefinePropertyValueStr(ctx, object.get(), def.name, JS_NewInt64(ctx, def.constValue), JS_PROP_ENUMERABLE));
            break;
        case MemberKind::Method: {
            JSValue fn = checked(ctx, JS_NewCFunction2(ctx, def.method, def.name, def.length, JS_CFUNC_generic, 0));
            check(ctx, JS_DefinePropertyValueStr(ctx, target, def.name, fn, JS_PROP_C_W_E));
            break;
        }
        case MemberKind::Attribute: {
            // Through QuickJS's function-type union, as JS_NewCFunctionMagic does: a cast between the signatures is
            // -Wcast-function-type-mismatch.
            JSCFunctionType getterType;
            getterType.getter = def.getter;
            std::string getterName = std::string("get ") + def.name;
            JSValue getter = checked(ctx, JS_NewCFunction2(ctx, getterType.generic, getterName.c_str(), 0, JS_CFUNC_getter, 0));
            JSValue setter = JS_UNDEFINED;
            if (def.setter) {
                JSCFunctionType setterType;
                setterType.setter = def.setter;
                std::string setterName = std::string("set ") + def.name;
                setter = JS_NewCFunction2(ctx, setterType.generic, setterName.c_str(), 1, JS_CFUNC_setter, 0);
                if (JS_IsException(setter)) {
                    JS_FreeValue(ctx, getter);
                    throw Thrown{};
                }
            }
            JSAtom atom = JS_NewAtom(ctx, def.name);
            int status = JS_DefinePropertyGetSet(ctx, target, atom, getter, setter, JS_PROP_ENUMERABLE | JS_PROP_CONFIGURABLE);
            JS_FreeAtom(ctx, atom);
            check(ctx, status);
            break;
        }
        }
        if (def.unscopable) {
            if (!unscopables.context()) {
                unscopables = Value::adopt(ctx, checked(ctx, JS_NewObjectProto(ctx, JS_NULL)));
            }
            check(ctx, JS_DefinePropertyValueStr(ctx, unscopables.get(), def.name, JS_TRUE, JS_PROP_C_W_E));
        }
    }
    if (unscopables.context()) {
        check(ctx, JS_DefinePropertyValue(ctx, proto.get(), m_unscopables, unscopables.release(), JS_PROP_CONFIGURABLE));
    }
    check(ctx, JS_DefinePropertyValue(ctx, proto.get(), m_toStringTag, JS_NewString(ctx, info.name), JS_PROP_CONFIGURABLE));
    // WebIDL "define the iteration methods": @@iterator for indexed properties, the rest for a value iterator only (the
    // generator makes every value iterator indexed). The functions are Array.prototype's own, taken when the runtime
    // was made, before any script ran.
    if (info.indexedIterator) {
        check(ctx, JS_DefinePropertyValue(ctx, proto.get(), m_iterator, JS_DupValue(ctx, m_arrayValues), JS_PROP_WRITABLE | JS_PROP_CONFIGURABLE));
    }
    if (info.valueIterable) {
        check(ctx, JS_DefinePropertyValueStr(ctx, proto.get(), "entries", JS_DupValue(ctx, m_arrayEntries), JS_PROP_C_W_E));
        check(ctx, JS_DefinePropertyValueStr(ctx, proto.get(), "keys", JS_DupValue(ctx, m_arrayKeys), JS_PROP_C_W_E));
        check(ctx, JS_DefinePropertyValueStr(ctx, proto.get(), "values", JS_DupValue(ctx, m_arrayValues), JS_PROP_C_W_E));
        check(ctx, JS_DefinePropertyValueStr(ctx, proto.get(), "forEach", JS_DupValue(ctx, m_arrayForEach), JS_PROP_C_W_E));
    }

    if (info.pairIteration) {
        this->definePairIteration(i, proto.get());
    }

    m_prototypes[i] = proto.release();
    m_interfaceObjects[i] = object.release();
    m_materialized++;
    // The class's prototype in this context (quickjs-ng change 4 then finds the slot set and keeps it).
    JS_SetClassProto(ctx, this->classId(i), JS_DupValue(ctx, m_prototypes[i]));
}

JSValueConst Runtime::memberFunction(uint16_t iface, uint16_t member, bool setter) {
    size_t slot = (size_t(m_memberBase[iface]) + member) * 2 + (setter ? 1 : 0);
    JSValue& cached = m_memberFunctions[slot];
    if (!JS_IsUndefined(cached)) {
        return cached;
    }
    JSContext* ctx = m_ctx;
    const MemberDef& def = m_table->interfaces[iface].members[member];
    if (def.kind == MemberKind::Method) {
        cached = checked(ctx, JS_NewCFunction2(ctx, def.method, def.name, def.length, JS_CFUNC_generic, 0));
    } else if (!setter) {
        JSCFunctionType getterType;
        getterType.getter = def.getter;
        std::string name = std::string("get ") + def.name;
        cached = checked(ctx, JS_NewCFunction2(ctx, getterType.generic, name.c_str(), 0, JS_CFUNC_getter, 0));
    } else if (def.setter) {
        JSCFunctionType setterType;
        setterType.setter = def.setter;
        std::string name = std::string("set ") + def.name;
        cached = checked(ctx, JS_NewCFunction2(ctx, setterType.generic, name.c_str(), 1, JS_CFUNC_setter, 0));
    }
    return cached;
}

void Runtime::defineMember(JSValueConst object, uint16_t iface, uint16_t member, int flags) {
    JSContext* ctx = m_ctx;
    const MemberDef& def = m_table->interfaces[iface].members[member];
    // The functions first: making one can throw, and nothing is held yet.
    JSValueConst first = this->memberFunction(iface, member, false);
    JSValueConst second = def.kind == MemberKind::Attribute ? this->memberFunction(iface, member, true) : JS_UNDEFINED;
    JSAtom atom = JS_NewAtom(ctx, def.name);
    if (atom == JS_ATOM_NULL) {
        throw Thrown{};
    }
    int status;
    if (def.kind == MemberKind::Method) {
        status = JS_DefinePropertyValue(ctx, object, atom, JS_DupValue(ctx, first), flags);
    } else {
        status = JS_DefinePropertyGetSet(ctx, object, atom, JS_DupValue(ctx, first), JS_DupValue(ctx, second), flags);
    }
    JS_FreeAtom(ctx, atom);
    check(ctx, status);
}

void Runtime::defineUnforgeableMembers(JSValueConst object, uint16_t iface) {
    for (int i = iface; i >= 0; i = m_table->interfaces[i].parent) {
        const InterfaceInfo& info = m_table->interfaces[i];
        for (uint16_t m = 0; m < info.memberCount; m++) {
            const MemberDef& def = info.members[m];
            if (!def.unforgeable || def.isStatic || def.kind == MemberKind::Constant) {
                continue;
            }
            // WebIDL: an unforgeable attribute is an enumerable, non-configurable accessor; an unforgeable operation
            // an enumerable, non-writable, non-configurable data property.
            this->defineMember(object, uint16_t(i), m, JS_PROP_ENUMERABLE);
        }
    }
}

void Runtime::installGlobalMembers(uint16_t iface) {
    if (int(iface) != m_globalInterface) {
        throw std::logic_error("installGlobalMembers: not the table's [Global] interface");
    }
    JSContext* ctx = m_ctx;
    const InterfaceInfo& info = m_table->interfaces[iface];
    this->materialize(iface);
    Value global = Value::adopt(ctx, JS_GetGlobalObject(ctx));
    check(ctx, JS_SetPrototype(ctx, global.get(), m_prototypes[iface]));
    // QuickJS gives the global its own @@toStringTag ("global"). It gives way too: the global's tag is its
    // interface's, from the prototype (Object.prototype.toString.call(window) is "[object Window]").
    check(ctx, JS_DeleteProperty(ctx, global.get(), m_toStringTag, 0));
    // Once, at setup, over the static table.
    for (uint16_t m = 0; m < info.memberCount; m++) {
        const MemberDef& def = info.members[m];
        if (def.kind == MemberKind::Constant || def.isStatic) {
            continue;
        }
        JSAtom atom = JS_NewAtom(ctx, def.name);
        if (atom == JS_ATOM_NULL) {
            throw Thrown{};
        }
        // An engine global of the same name (QuickJS's queueMicrotask and performance) gives way to the IDL member.
        int deleted = JS_DeleteProperty(ctx, global.get(), atom, 0);
        if (deleted <= 0) {
            JS_FreeAtom(ctx, atom);
            if (deleted < 0) {
                throw Thrown{};
            }
            throw std::logic_error(std::string("installGlobalMembers: cannot replace the global's ") + def.name);
        }
        if (def.kind == MemberKind::Method && !def.unforgeable) {
            // Lazy, like an interface object: the function is made the first time a script reads or describes it.
            int status = JS_DefineHostAutoInitProperty(ctx, global.get(), atom, reinterpret_cast<void*>(kGlobalMemberTag | (uintptr_t(iface) << 16) | m), JS_PROP_C_W_E);
            JS_FreeAtom(ctx, atom);
            check(ctx, status);
            continue;
        }
        JS_FreeAtom(ctx, atom);
        // An accessor cannot be lazy (an auto-init entry only becomes a data property), so attributes are made now.
        this->defineMember(global.get(), iface, m, def.unforgeable ? JS_PROP_ENUMERABLE : JS_PROP_ENUMERABLE | JS_PROP_CONFIGURABLE);
    }
    if (info.parent >= 0) {
        this->defineUnforgeableMembers(global.get(), uint16_t(info.parent));
    }
}

} // namespace wr
