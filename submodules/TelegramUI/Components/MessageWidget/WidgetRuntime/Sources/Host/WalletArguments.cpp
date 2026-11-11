#include "Sources/Host/WalletArguments.h"

#include <cstdint>
#include <string>

#include "Sources/Host/Sequences.h"
#include "Sources/Support/Errors.h"
#include "Sources/Support/Values.h"
#include "twidget/sdk_policy.h"

namespace wr {

namespace {

/// The deepest value a check reads: a transaction (0), its messages (1), a message (2), a message's field (3).
constexpr int kDeepestRead = 3;
/// The most keys a checked object may have: a `cell` payload's type, schema, cell, network and from.
constexpr uint32_t kMaxKeys = 5;
/// The most elements a checked array may have: a transaction's messages.
constexpr int64_t kMaxElements = int64_t(twidget::sdk::MAX_WALLET_MESSAGES);
/// Longer than any string a check takes (a payload's 8,192 characters).
constexpr uint32_t kMaxStringLength = 65536;

/// A value no check can pass, whatever else it holds.
struct Refused {};

/// Frees a property list from JS_GetOwnPropertyNames.
struct PropertyList {
    JSContext* ctx;
    JSPropertyEnum* tab = nullptr;
    uint32_t length = 0;
    ~PropertyList() {
        if (tab) {
            JS_FreePropertyEnum(ctx, tab, length);
        }
    }
};

/// `Array.isArray`: an array, or a proxy whose target is one (the spec's IsArray looks through proxies; JS_IsArray does
/// not). A revoked proxy has no target and is no array here.
bool isArray(JSContext* ctx, JSValueConst value) {
    Value current = Value::dup(ctx, value);
    while (!JS_IsArray(current.get())) {
        if (!JS_IsProxy(current.get())) {
            return false;
        }
        current = Value::adopt(ctx, checked(ctx, JS_GetProxyTarget(ctx, current.get())));
    }
    return true;
}

twidget::Json convert(JSContext* ctx, JSValueConst value, int depth);

/// The shim's reading of a transaction's messages (checkWalletTransaction): `length` from 1 to 255, then `for…of`, so
/// the values are the array's own iterator's (through the runtime's @@iterator, which a script cannot replace), whatever
/// its indices hold. No other check takes an array, so any other array is refused whichever way it is read. One value
/// more than a transaction takes refuses it with the rest unread and the iterator closed, where the shim reads on and
/// the glue's check refuses what it posts.
twidget::Json convertArray(JSContext* ctx, JSValueConst array, int depth) {
    int64_t length = 0;
    if (JS_GetLength(ctx, array, &length) < 0) {
        throw Thrown{};
    }
    if (length < 1 || length > kMaxElements) {
        throw Refused{};
    }
    std::optional<std::vector<Value>> values = sequenceValues(ctx, array, "TelegramWidget.wallet.sendTransaction", size_t(kMaxElements) + 1);
    if (!values || values->size() > size_t(kMaxElements)) {
        throw Refused{};
    }
    twidget::Json out = twidget::Json::array();
    for (const Value& element : *values) {
        out.push(convert(ctx, element.get(), depth + 1));
    }
    return out;
}

twidget::Json convertObject(JSContext* ctx, JSValueConst object, int depth) {
    PropertyList keys{ctx};
    if (JS_GetOwnPropertyNames(ctx, &keys.tab, &keys.length, object, JS_GPN_STRING_MASK | JS_GPN_ENUM_ONLY) < 0) {
        throw Thrown{};
    }
    if (keys.length > kMaxKeys) {
        throw Refused{};
    }
    twidget::Json out = twidget::Json::object();
    for (uint32_t i = 0; i < keys.length; i++) {
        String key = String::adopt(ctx, checked(ctx, JS_AtomToString(ctx, keys.tab[i].atom)));
        Value element = Value::adopt(ctx, checked(ctx, JS_GetProperty(ctx, object, keys.tab[i].atom)));
        out.set(key.utf8(), convert(ctx, element.get(), depth + 1));
    }
    return out;
}

twidget::Json convert(JSContext* ctx, JSValueConst value, int depth) {
    if (JS_IsUndefined(value) || JS_IsNull(value)) {
        return twidget::Json();
    }
    if (JS_IsBool(value)) {
        return twidget::Json(bool(JS_ToBool(ctx, value)));
    }
    if (JS_IsNumber(value)) {
        double number = 0;
        if (JS_ToFloat64(ctx, &number, value) < 0) {
            throw Thrown{};
        }
        return twidget::Json(number);
    }
    if (JS_IsString(value)) {
        String text = String::adopt(ctx, JS_DupValue(ctx, value));
        if (text.length() > kMaxStringLength) {
            throw Refused{};
        }
        // A lone surrogate becomes WTF-8, which every check that takes text refuses (not well-formed), as the shim does.
        return twidget::Json(text.utf8());
    }
    // A symbol, a bigint or a function: no check takes one, and `{}` is refused wherever one could stand.
    if (!JS_IsObject(value) || JS_IsFunction(ctx, value) || depth >= kDeepestRead) {
        return twidget::Json::object();
    }
    return isArray(ctx, value) ? convertArray(ctx, value, depth) : convertObject(ctx, value, depth);
}

} // namespace

std::optional<twidget::Json> walletArgumentJson(JSContext* ctx, JSValueConst value) {
    if (!JS_IsObject(value) || JS_IsFunction(ctx, value)) {
        return std::nullopt;
    }
    if (isArray(ctx, value)) {
        return std::nullopt;
    }
    try {
        return convert(ctx, value, 0);
    } catch (const Refused&) {
        return std::nullopt;
    }
}

} // namespace wr
