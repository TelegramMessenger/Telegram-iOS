#include "Sources/Support/Bindings.h"

#include <cmath>

#include "Sources/Runtime/Runtime.h"

namespace wr {

std::string argumentMessage(const ArgInfo& info, const char* what) {
    return std::string("Failed to execute '") + info.member + "' on '" + info.interface + "': parameter " + std::to_string(info.index + 1) + " " + what;
}

void requireArguments(int argc, int required, const char* interface, const char* member) {
    if (argc < required) {
        throw TypeError{std::string("Failed to execute '") + member + "' on '" + interface + "': " + std::to_string(required) +
                        " argument" + (required == 1 ? "" : "s") + " required, but only " + std::to_string(argc) + " present."};
    }
}

const char* interfaceName(JSContext* ctx, uint16_t iface) {
    return Runtime::from(ctx).interfaces().interfaces[iface].name;
}

JSAtom tableAtom(JSContext* ctx, uint16_t id) {
    return Runtime::from(ctx).reflectedAtom(id);
}

void replaceAttribute(JSContext* ctx, JSValueConst thisVal, const char* name, JSValueConst value) {
    Value target = JS_IsUndefined(thisVal) || JS_IsNull(thisVal) ? Value::adopt(ctx, JS_GetGlobalObject(ctx)) : Value::dup(ctx, thisVal);
    if (!JS_IsObject(target.get())) {
        throw TypeError{std::string("Cannot set '") + name + "' on a value that is not an object."};
    }
    check(ctx, JS_DefinePropertyValueStr(ctx, target.get(), name, JS_DupValue(ctx, value), JS_PROP_C_W_E | JS_PROP_THROW));
}

template <> bool Converter<bool>::from(JSContext* ctx, JSValueConst v, const ArgInfo&) {
    return JS_ToBool(ctx, v) == 1;
}

static int32_t toInt32(JSContext* ctx, JSValueConst v) {
    int32_t r = 0;
    check(ctx, JS_ToInt32(ctx, &r, v));
    return r;
}

template <> int8_t Converter<int8_t>::from(JSContext* ctx, JSValueConst v, const ArgInfo&) { return int8_t(toInt32(ctx, v)); }
template <> uint8_t Converter<uint8_t>::from(JSContext* ctx, JSValueConst v, const ArgInfo&) { return uint8_t(toInt32(ctx, v)); }
template <> int16_t Converter<int16_t>::from(JSContext* ctx, JSValueConst v, const ArgInfo&) { return int16_t(toInt32(ctx, v)); }
template <> uint16_t Converter<uint16_t>::from(JSContext* ctx, JSValueConst v, const ArgInfo&) { return uint16_t(toInt32(ctx, v)); }
template <> int32_t Converter<int32_t>::from(JSContext* ctx, JSValueConst v, const ArgInfo&) { return toInt32(ctx, v); }
template <> uint32_t Converter<uint32_t>::from(JSContext* ctx, JSValueConst v, const ArgInfo&) { return uint32_t(toInt32(ctx, v)); }

template <> int64_t Converter<int64_t>::from(JSContext* ctx, JSValueConst v, const ArgInfo&) {
    int64_t r = 0;
    check(ctx, JS_ToInt64(ctx, &r, v));
    return r;
}

template <> uint64_t Converter<uint64_t>::from(JSContext* ctx, JSValueConst v, const ArgInfo&) {
    int64_t r = 0;
    check(ctx, JS_ToInt64(ctx, &r, v));
    return uint64_t(r);
}

template <> double Converter<double>::from(JSContext* ctx, JSValueConst v, const ArgInfo& info) {
    double r = 0;
    check(ctx, JS_ToFloat64(ctx, &r, v));
    if (!std::isfinite(r)) {
        throw TypeError{argumentMessage(info, "is not a finite floating-point value.")};
    }
    return r;
}

template <> Unrestricted Converter<Unrestricted>::from(JSContext* ctx, JSValueConst v, const ArgInfo&) {
    double r = 0;
    check(ctx, JS_ToFloat64(ctx, &r, v));
    return Unrestricted{r};
}

template <> String Converter<String>::from(JSContext* ctx, JSValueConst v, const ArgInfo&) {
    return String::fromJS(ctx, v);
}

template <> USVString Converter<USVString>::from(JSContext* ctx, JSValueConst v, const ArgInfo&) {
    String s = String::fromJS(ctx, v);
    JSStringView view = s.view();
    if (!view.utf16) {
        return USVString(std::move(s));
    }
    std::u16string out(reinterpret_cast<const char16_t*>(view.utf16), view.length);
    bool changed = false;
    for (size_t i = 0; i < out.size(); i++) {
        char16_t c = out[i];
        if (c >= 0xD800 && c <= 0xDBFF && i + 1 < out.size() && out[i + 1] >= 0xDC00 && out[i + 1] <= 0xDFFF) {
            i++;
        } else if (c >= 0xD800 && c <= 0xDFFF) {
            out[i] = 0xFFFD;
            changed = true;
        }
    }
    return changed ? USVString(String::fromUTF16(ctx, out.data(), out.size())) : USVString(std::move(s));
}

template <> LegacyNullToEmptyString Converter<LegacyNullToEmptyString>::from(JSContext* ctx, JSValueConst v, const ArgInfo&) {
    if (JS_IsNull(v)) {
        return LegacyNullToEmptyString(String::fromUTF8(ctx, ""));
    }
    return LegacyNullToEmptyString(String::fromJS(ctx, v));
}

template <> Value Converter<Value>::from(JSContext* ctx, JSValueConst v, const ArgInfo&) {
    return Value::dup(ctx, v);
}

template <> Object Converter<Object>::from(JSContext* ctx, JSValueConst v, const ArgInfo& info) {
    if (!JS_IsObject(v)) {
        throw TypeError{argumentMessage(info, "is not an object.")};
    }
    return Object(Value::dup(ctx, v));
}

JSValue applyNewTarget(JSContext* ctx, JSValue object, JSValueConst newTarget, uint16_t iface) {
    Value owned = Value::adopt(ctx, object);
    JSValueConst own = Runtime::from(ctx).interfaceObject(iface);
    if (JS_IsObject(newTarget) && JS_VALUE_GET_PTR(newTarget) != JS_VALUE_GET_PTR(own)) {
        Value proto = Value::adopt(ctx, checked(ctx, JS_GetPropertyStr(ctx, newTarget, "prototype")));
        if (JS_IsObject(proto.get())) {
            check(ctx, JS_SetPrototype(ctx, owned.get(), proto.get()));
        }
    }
    return owned.release();
}

} // namespace wr
