// The support layer generated bindings call (//build-system/WidgetIDL, M1a plan Task 6). Generated code includes it as
// "Sources/Support/Bindings.h".
#pragma once

#include <cstdint>
#include <optional>
#include <string>
#include <type_traits>
#include <variant>
#include <vector>

#include "quickjs.h"
#include "Sources/Support/Errors.h"
#include "Sources/Support/PlatformObject.h"
#include "Sources/Support/Values.h"

namespace wr {

class Element;

enum class MemberKind : uint8_t { Method, Attribute, Constant };

struct MemberDef {
    const char* name;
    MemberKind kind;
    JSCFunction* method;
    JSValue (*getter)(JSContext*, JSValueConst);
    JSValue (*setter)(JSContext*, JSValueConst, JSValueConst);
    int length;
    int64_t constValue;
    bool unscopable;
    bool isStatic;
    /// [LegacyUnforgeable]: an own, non-configurable property of every instance (Runtime::defineUnforgeableMembers)
    /// and of the global, never of the prototype.
    bool unforgeable;
};

/// A WebIDL pair iterator (`iterable<K, V>`; V5a plan, Task 5): the generated adapters over the implementation's
/// `iterationLength(ctx)` and `iterationPair(ctx, index)`. Both throw (a TypeError when `self` is not an instance, or
/// what the implementation throws); `pair` hands over owned values.
struct PairIteration {
    uint32_t (*length)(JSContext* ctx, JSValueConst self);
    void (*pair)(JSContext* ctx, JSValueConst self, uint32_t index, JSValue* key, JSValue* value);
};

struct InterfaceInfo {
    const char* name;
    int16_t parent;
    bool exposed;
    /// [Global]: the context's global object is an instance (quickjs-ng change 6), and the regular members are its
    /// own properties (Runtime::installGlobalMembers), not the prototype's.
    bool isGlobal;
    const MemberDef* members;
    uint16_t memberCount;
    JSCFunction* constructor;
    int constructorLength;
    const JSClassExoticMethods* exotic;
    /// A value iterator (`iterable<T>`): entries, keys, values and forEach, Array.prototype's.
    bool valueIterable;
    /// Supports indexed properties (an indexed getter and an integer `length`): @@iterator, %Array.prototype.values%.
    bool indexedIterator;
    /// A pair iterator: entries, keys, values, forEach and @@iterator, over these adapters. nullptr otherwise.
    const PairIteration* pairIteration;
};

struct InterfaceTable {
    const InterfaceInfo* interfaces;
    uint16_t count;
    const char* const* reflectedNames;
    uint16_t reflectedCount;
};

/// Specialized by generated headers: the table index of an impl type's interface.
template <class Impl>
struct InterfaceIndexOf;

struct ArgInfo {
    const char* interface;
    const char* member;
    int index;
};

/// "Failed to execute 'member' on 'Interface': parameter N <what>."
std::string argumentMessage(const ArgInfo& info, const char* what);
/// Throws TypeError when fewer than `required` arguments were passed.
void requireArguments(int argc, int required, const char* interface, const char* member);

struct Unrestricted {
    double value;
};

/// A nullable interface argument: an Impl* that may be null.
template <class T>
struct OrNull {
    T* ptr = nullptr;
    operator T*() const { return ptr; }
};

template <class T>
struct Converter {
    static T from(JSContext* ctx, JSValueConst v, const ArgInfo& info);
};

template <class T>
T convert(JSContext* ctx, JSValueConst v, const ArgInfo& info) {
    return Converter<T>::from(ctx, v, info);
}

template <class T>
std::vector<T> convertRest(JSContext* ctx, int argc, JSValueConst* argv, int start, const ArgInfo& info) {
    std::vector<T> out;
    for (int i = start; i < argc; i++) {
        out.push_back(Converter<T>::from(ctx, argv[i], ArgInfo{info.interface, info.member, i}));
    }
    return out;
}

template <class Impl>
Impl* unwrap(JSContext* ctx, JSValueConst v, uint16_t iface) {
    PlatformObject* p = payloadImplementing(ctx, v, iface);
    return p ? static_cast<Impl*>(p) : nullptr;
}

template <class Impl>
Impl& thisAs(JSContext* ctx, JSValueConst thisVal, uint16_t iface, const char* member) {
    Impl* p;
    if (JS_IsUndefined(thisVal) || JS_IsNull(thisVal)) {
        // WebIDL 3.7.5 and 3.7.6: a regular attribute or operation called with an undefined or null this uses the
        // realm's global object. The brand check below then passes only for an interface the global implements, so
        // bare setTimeout(…) and addEventListener(…) work and TestSample.prototype.find.call(undefined) still throws.
        // The context holds the global, so the payload outlives the reference freed here.
        JSValue global = JS_GetGlobalObject(ctx);
        p = unwrap<Impl>(ctx, global, iface);
        JS_FreeValue(ctx, global);
    } else {
        p = unwrap<Impl>(ctx, thisVal, iface);
    }
    if (!p) {
        throw TypeError{std::string("Illegal invocation (") + member + ")"};
    }
    return *p;
}

/// The name of interface `iface` in the context's table (for messages).
const char* interfaceName(JSContext* ctx, uint16_t iface);
/// The atom of entry `id` of the table's name list: reflected content attribute names and the event types of event
/// handler attributes.
JSAtom tableAtom(JSContext* ctx, uint16_t id);
/// [Replaceable]'s setter (WebIDL 3.7.6): an own data property named `name` of `thisVal`, or of the global when it is
/// undefined or null, with `value`. Throws Thrown or TypeError.
void replaceAttribute(JSContext* ctx, JSValueConst thisVal, const char* name, JSValueConst value);

template <class T>
struct Converter<T*> {
    static T* from(JSContext* ctx, JSValueConst v, const ArgInfo& info) {
        if (T* p = unwrap<T>(ctx, v, InterfaceIndexOf<T>::value)) {
            return p;
        }
        throw TypeError{argumentMessage(info, (std::string("is not of type '") + interfaceName(ctx, InterfaceIndexOf<T>::value) + "'").c_str())};
    }
};

template <class T>
struct Converter<OrNull<T>> {
    static OrNull<T> from(JSContext* ctx, JSValueConst v, const ArgInfo& info) {
        if (JS_IsNull(v) || JS_IsUndefined(v)) {
            return OrNull<T>{};
        }
        return OrNull<T>{Converter<T*>::from(ctx, v, info)};
    }
};

template <class T>
struct Converter<std::optional<T>> {
    static std::optional<T> from(JSContext* ctx, JSValueConst v, const ArgInfo& info) {
        if (JS_IsNull(v) || JS_IsUndefined(v)) {
            return std::nullopt;
        }
        return Converter<T>::from(ctx, v, info);
    }
};

template <> bool Converter<bool>::from(JSContext*, JSValueConst, const ArgInfo&);
template <> int8_t Converter<int8_t>::from(JSContext*, JSValueConst, const ArgInfo&);
template <> uint8_t Converter<uint8_t>::from(JSContext*, JSValueConst, const ArgInfo&);
template <> int16_t Converter<int16_t>::from(JSContext*, JSValueConst, const ArgInfo&);
template <> uint16_t Converter<uint16_t>::from(JSContext*, JSValueConst, const ArgInfo&);
template <> int32_t Converter<int32_t>::from(JSContext*, JSValueConst, const ArgInfo&);
template <> uint32_t Converter<uint32_t>::from(JSContext*, JSValueConst, const ArgInfo&);
template <> int64_t Converter<int64_t>::from(JSContext*, JSValueConst, const ArgInfo&);
template <> uint64_t Converter<uint64_t>::from(JSContext*, JSValueConst, const ArgInfo&);
template <> double Converter<double>::from(JSContext*, JSValueConst, const ArgInfo&);
template <> Unrestricted Converter<Unrestricted>::from(JSContext*, JSValueConst, const ArgInfo&);
template <> String Converter<String>::from(JSContext*, JSValueConst, const ArgInfo&);
template <> USVString Converter<USVString>::from(JSContext*, JSValueConst, const ArgInfo&);
template <> LegacyNullToEmptyString Converter<LegacyNullToEmptyString>::from(JSContext*, JSValueConst, const ArgInfo&);
template <> Value Converter<Value>::from(JSContext*, JSValueConst, const ArgInfo&);
template <> Object Converter<Object>::from(JSContext*, JSValueConst, const ArgInfo&);

inline JSValue toJS(JSContext* ctx, bool v) { return JS_NewBool(ctx, v); }
inline JSValue toJS(JSContext* ctx, int8_t v) { return JS_NewInt32(ctx, v); }
inline JSValue toJS(JSContext* ctx, uint8_t v) { return JS_NewInt32(ctx, v); }
inline JSValue toJS(JSContext* ctx, int16_t v) { return JS_NewInt32(ctx, v); }
inline JSValue toJS(JSContext* ctx, uint16_t v) { return JS_NewInt32(ctx, v); }
inline JSValue toJS(JSContext* ctx, int32_t v) { return JS_NewInt32(ctx, v); }
inline JSValue toJS(JSContext* ctx, uint32_t v) { return JS_NewUint32(ctx, v); }
inline JSValue toJS(JSContext* ctx, int64_t v) { return JS_NewInt64(ctx, v); }
inline JSValue toJS(JSContext* ctx, uint64_t v) { return JS_NewFloat64(ctx, double(v)); }
inline JSValue toJS(JSContext* ctx, double v) { return JS_NewFloat64(ctx, v); }
inline JSValue toJS(JSContext* ctx, Unrestricted v) { return JS_NewFloat64(ctx, v.value); }
inline JSValue toJS(JSContext* ctx, const String& v) { return v.toJS(ctx); }
inline JSValue toJS(JSContext* ctx, const Value& v) { return v.newRef(); }
/// An owned JSValue, handed on.
inline JSValue toJS(JSContext*, JSValue owned) { return owned; }
template <class T>
JSValue toJS(JSContext* ctx, const std::optional<T>& v) {
    return v ? toJS(ctx, *v) : JS_NULL;
}
template <class T, std::enable_if_t<std::is_base_of_v<PlatformObject, T>, int> = 0>
JSValue toJS(JSContext* ctx, T* p) {
    return p ? JS_DupValue(ctx, p->object()) : JS_NULL;
}
template <class T>
JSValue toJS(JSContext* ctx, Ref<T> r) {
    return r.release();
}
/// A sequence<T> return value: a new array.
template <class T>
JSValue toJS(JSContext* ctx, const std::vector<T>& items) {
    JSValue array = JS_NewArray(ctx);
    if (JS_IsException(array)) {
        return array;
    }
    for (uint32_t i = 0; i < items.size(); i++) {
        JSValue item = toJS(ctx, items[i]);
        if (JS_IsException(item) || JS_SetPropertyUint32(ctx, array, i, item) < 0) {
            JS_FreeValue(ctx, array);
            return JS_EXCEPTION;
        }
    }
    return array;
}

/// WebIDL's "new target" step of a constructor: an object made for a subclass gets the subclass's prototype.
JSValue applyNewTarget(JSContext* ctx, JSValue object, JSValueConst newTarget, uint16_t iface);

/// The exotic methods of an interface with an indexed property getter (WebIDL 3.9). Impl provides
/// `uint32_t length(JSContext*)` and `JSValue indexedValue(JSContext*, uint32_t)` (a new reference). A read of an index
/// and a listing of the indices are binding calls: each maps exceptions as `glue` does.
template <class Impl>
struct IndexedExotic {
    /// Whether `prop` is an array index (WebIDL: a canonical decimal below 2^32 - 1): 1 with *out set, 0, or -1 with an
    /// exception pending. JS_AtomToValue gives an integer atom back as its decimal string, never a number, so both atom
    /// kinds are read as text. Runs on every own-property lookup of the object (`length`, `item`, …): a name that is
    /// not a number is turned away at its first character.
    static int index(JSContext* ctx, JSAtom prop, uint32_t* out) {
        JSValue key = JS_AtomToValue(ctx, prop);
        if (JS_IsException(key)) {
            return -1;
        }
        JSStringView view{nullptr, nullptr, 0};
        int result = 0;
        if (JS_GetStringView(key, &view) && view.length > 0 && view.length <= 10) {
            uint64_t value = 0;
            result = 1;
            for (uint32_t i = 0; i < view.length; i++) {
                uint32_t c = view.latin1 ? view.latin1[i] : view.utf16[i];
                if (c < '0' || c > '9' || (i == 0 && c == '0' && view.length > 1)) {
                    result = 0;
                    break;
                }
                value = value * 10 + (c - '0');
            }
            if (result && value > 0xFFFFFFFEu) {
                result = 0;
            }
            if (result) {
                *out = uint32_t(value);
            }
        }
        JS_FreeValue(ctx, key);
        return result;
    }
    static int getOwnProperty(JSContext* ctx, JSPropertyDescriptor* desc, JSValueConst obj, JSAtom prop) {
        uint32_t i;
        int isIndex = index(ctx, prop, &i);
        if (isIndex <= 0) {
            return isIndex;
        }
        try {
            Impl* self = static_cast<Impl*>(payloadOfKnown(obj));
            if (i >= self->length(ctx)) {
                return 0;
            }
            if (desc) {
                desc->flags = JS_PROP_ENUMERABLE | JS_PROP_CONFIGURABLE;
                desc->value = self->indexedValue(ctx, i);
                desc->getter = JS_UNDEFINED;
                desc->setter = JS_UNDEFINED;
            }
            return 1;
        } catch (...) {
            rethrowAsJS(ctx);
            return -1;
        }
    }
    static int getOwnPropertyNames(JSContext* ctx, JSPropertyEnum** tab, uint32_t* len, JSValueConst obj) {
        uint32_t n;
        try {
            n = static_cast<Impl*>(payloadOfKnown(obj))->length(ctx);
        } catch (...) {
            rethrowAsJS(ctx);
            return -1;
        }
        auto* entries = static_cast<JSPropertyEnum*>(js_mallocz(ctx, sizeof(JSPropertyEnum) * (n ? n : 1)));
        if (!entries) {
            return -1;
        }
        for (uint32_t i = 0; i < n; i++) {
            entries[i].is_enumerable = true;
            entries[i].atom = JS_NewAtomUInt32(ctx, i);
        }
        *tab = entries;
        *len = n;
        return 0;
    }
    static constexpr JSClassExoticMethods methods = {
        .get_own_property = getOwnProperty,
        .get_own_property_names = getOwnPropertyNames,
    };
};

/// The exotic methods of an interface with named properties and no indexed getter (DOMStringMap: a named getter,
/// setter and deleter, [LegacyOverrideBuiltIns]). Impl provides
/// - `std::vector<String> supportedNames(JSContext*)`, in order;
/// - `std::optional<String> namedValue(JSContext*, const String&)`, nullopt for a name that is not supported;
/// - `void setNamed(JSContext*, const String&, const String&)`;
/// - `bool deleteNamed(JSContext*, const String&)`, which deletes a supported name only.
/// Each hook a string name reaches is a binding call, mapping exceptions as `glue` does. QuickJS consults
/// get_own_property before the prototype chain, which is [LegacyOverrideBuiltIns]: a named property shadows an
/// inherited one. Symbols are not names: reads fall through to the ordinary object, and a write of a symbol key is a
/// TypeError (WebIDL defines an ordinary property; nothing in the profile writes one).
template <class Impl>
struct NamedExotic {
    /// The property name as a string, or false for a symbol. An integer atom comes back as its decimal string.
    static bool nameOf(JSContext* ctx, JSAtom atom, String* out) {
        JSValue key = checked(ctx, JS_AtomToValue(ctx, atom));
        if (JS_IsSymbol(key)) {
            JS_FreeValue(ctx, key);
            return false;
        }
        *out = String::adopt(ctx, key);
        return true;
    }
    static Impl* self(JSValueConst obj) { return static_cast<Impl*>(payloadOfKnown(obj)); }
    static int getOwnProperty(JSContext* ctx, JSPropertyDescriptor* desc, JSValueConst obj, JSAtom prop) {
        try {
            String name;
            if (!nameOf(ctx, prop, &name)) {
                return 0;
            }
            std::optional<String> value = self(obj)->namedValue(ctx, name);
            if (!value) {
                return 0;
            }
            if (desc) {
                // WebIDL 3.9.6: writable with a named setter, enumerable without [LegacyUnenumerableNamedProperties].
                desc->flags = JS_PROP_ENUMERABLE | JS_PROP_WRITABLE | JS_PROP_CONFIGURABLE;
                desc->value = value->toJS(ctx);
                desc->getter = JS_UNDEFINED;
                desc->setter = JS_UNDEFINED;
            }
            return 1;
        } catch (...) {
            rethrowAsJS(ctx);
            return -1;
        }
    }
    static int getOwnPropertyNames(JSContext* ctx, JSPropertyEnum** tab, uint32_t* len, JSValueConst obj) {
        std::vector<String> names;
        try {
            names = self(obj)->supportedNames(ctx);
        } catch (...) {
            rethrowAsJS(ctx);
            return -1;
        }
        auto* entries = static_cast<JSPropertyEnum*>(js_mallocz(ctx, sizeof(JSPropertyEnum) * (names.empty() ? 1 : names.size())));
        if (!entries) {
            return -1;
        }
        for (uint32_t i = 0; i < names.size(); i++) {
            JSAtom atom = JS_ValueToAtom(ctx, names[i].value());
            if (atom == JS_ATOM_NULL) {
                JS_FreePropertyEnum(ctx, entries, i);
                return -1;
            }
            entries[i].is_enumerable = true;
            entries[i].atom = atom;
        }
        *tab = entries;
        *len = uint32_t(names.size());
        return 0;
    }
    static int deleteProperty(JSContext* ctx, JSValueConst obj, JSAtom prop) {
        try {
            String name;
            if (nameOf(ctx, prop, &name)) {
                self(obj)->deleteNamed(ctx, name);
            }
            // Deleted, or an ordinary delete of a property the object does not have (QuickJS looked at its own ones).
            return 1;
        } catch (...) {
            rethrowAsJS(ctx);
            return -1;
        }
    }
    static int defineOwnProperty(JSContext* ctx, JSValueConst obj, JSAtom prop, JSValueConst value, JSValueConst getter, JSValueConst setter, int flags) {
        try {
            String name;
            if (!nameOf(ctx, prop, &name)) {
                throw TypeError{"A symbol cannot be defined here."};
            }
            // WebIDL 3.9.3: only a data descriptor invokes the setter; anything else is refused.
            if ((flags & (JS_PROP_HAS_GET | JS_PROP_HAS_SET)) || !(flags & (JS_PROP_HAS_VALUE | JS_PROP_HAS_WRITABLE))) {
                if (flags & (JS_PROP_THROW | JS_PROP_THROW_STRICT)) {
                    throw TypeError{"Only a string value can be defined here."};
                }
                return 0;
            }
            self(obj)->setNamed(ctx, name, String::fromJS(ctx, value));
            return 1;
        } catch (...) {
            rethrowAsJS(ctx);
            return -1;
        }
    }
    static int setProperty(JSContext* ctx, JSValueConst obj, JSAtom prop, JSValueConst value, JSValueConst receiver, int flags) {
        try {
            if (!JS_IsObject(receiver) || JS_VALUE_GET_PTR(receiver) != JS_VALUE_GET_PTR(obj)) {
                // A write through an object that inherits from the map (or Reflect.set with another receiver) makes
                // the receiver an own data property, as OrdinarySetWithOwnDescriptor does for a writable one.
                if (!JS_IsObject(receiver)) {
                    if (flags & (JS_PROP_THROW | JS_PROP_THROW_STRICT)) {
                        throw TypeError{"The receiver is not an object."};
                    }
                    return 0;
                }
                return JS_DefinePropertyValue(ctx, receiver, prop, JS_DupValue(ctx, value), JS_PROP_C_W_E);
            }
            String name;
            if (!nameOf(ctx, prop, &name)) {
                throw TypeError{"A symbol cannot be set here."};
            }
            self(obj)->setNamed(ctx, name, String::fromJS(ctx, value));
            return 1;
        } catch (...) {
            rethrowAsJS(ctx);
            return -1;
        }
    }
    static constexpr JSClassExoticMethods methods = {
        .get_own_property = getOwnProperty,
        .get_own_property_names = getOwnPropertyNames,
        .delete_property = deleteProperty,
        .define_own_property = defineOwnProperty,
        .set_property = setProperty,
    };
};

/// Content attribute reflection for [Reflect] (defined with Element, Task 11). `id` indexes the table's
/// reflectedNames.
namespace reflect {
String getString(JSContext* ctx, Element& element, uint16_t id);
void setString(JSContext* ctx, Element& element, uint16_t id, const String& value);
bool getBoolean(JSContext* ctx, Element& element, uint16_t id);
void setBoolean(JSContext* ctx, Element& element, uint16_t id, bool value);
int32_t getLong(JSContext* ctx, Element& element, uint16_t id);
void setLong(JSContext* ctx, Element& element, uint16_t id, int32_t value);
uint32_t getUnsignedLong(JSContext* ctx, Element& element, uint16_t id);
void setUnsignedLong(JSContext* ctx, Element& element, uint16_t id, uint32_t value);
} // namespace reflect

} // namespace wr
