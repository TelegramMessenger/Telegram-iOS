// HTML's reflection of content attributes, for [Reflect] IDL attributes: the generated glue calls these with the
// table's reflected-name index (https://html.spec.whatwg.org/#reflecting-content-attributes-in-idl-attributes).
#include <climits>
#include <string>

#include "Sources/DOM/DOM.h"

namespace wr::reflect {

static JSAtom nameOf(JSContext* ctx, uint16_t id) {
    return Runtime::from(ctx).reflectedAtom(id);
}

String getString(JSContext* ctx, Element& element, uint16_t id) {
    return element.attributeValue(ctx, nameOf(ctx, id)).value_or(String());
}

void setString(JSContext* ctx, Element& element, uint16_t id, const String& value) {
    element.setAttributeValue(ctx, nameOf(ctx, id), value);
}

bool getBoolean(JSContext* ctx, Element& element, uint16_t id) {
    return element.hasAttributeAtom(ctx, nameOf(ctx, id));
}

void setBoolean(JSContext* ctx, Element& element, uint16_t id, bool value) {
    if (value) {
        element.setAttributeValue(ctx, nameOf(ctx, id), String());
    } else {
        element.removeAttributeAtom(ctx, nameOf(ctx, id));
    }
}

/// HTML's "rules for parsing integers" (a value past 2^32 fails: no reflected range reaches it). The leading whitespace
/// is the one unbounded scan (the digits stop past ten).
static std::optional<int64_t> parseInteger(JSContext* ctx, const String& s) {
    JSStringView v = s.view();
    auto at = [&](uint32_t i) -> char16_t { return v.latin1 ? v.latin1[i] : v.utf16[i]; };
    uint32_t i = 0;
    while (i < v.length && isASCIIWhitespace(at(i))) {
        i++;
    }
    bool negative = false;
    if (i < v.length && (at(i) == '-' || at(i) == '+')) {
        negative = at(i) == '-';
        i++;
    }
    if (i >= v.length || at(i) < '0' || at(i) > '9') {
        return std::nullopt;
    }
    int64_t value = 0;
    while (i < v.length && at(i) >= '0' && at(i) <= '9') {
        value = value * 10 + (at(i) - '0');
        if (value > (int64_t(1) << 32)) {
            return std::nullopt;
        }
        i++;
    }
    return negative ? -value : value;
}

int32_t getLong(JSContext* ctx, Element& element, uint16_t id) {
    std::optional<String> value = element.attributeValue(ctx, nameOf(ctx, id));
    std::optional<int64_t> parsed = value ? parseInteger(ctx, *value) : std::nullopt;
    return parsed && *parsed >= INT32_MIN && *parsed <= INT32_MAX ? int32_t(*parsed) : 0;
}

void setLong(JSContext* ctx, Element& element, uint16_t id, int32_t value) {
    element.setAttributeValue(ctx, nameOf(ctx, id), String::fromUTF8(ctx, std::to_string(value)));
}

uint32_t getUnsignedLong(JSContext* ctx, Element& element, uint16_t id) {
    std::optional<String> value = element.attributeValue(ctx, nameOf(ctx, id));
    std::optional<int64_t> parsed = value ? parseInteger(ctx, *value) : std::nullopt;
    return parsed && *parsed >= 0 && *parsed <= INT32_MAX ? uint32_t(*parsed) : 0;
}

void setUnsignedLong(JSContext* ctx, Element& element, uint16_t id, uint32_t value) {
    element.setAttributeValue(ctx, nameOf(ctx, id), String::fromUTF8(ctx, std::to_string(value > uint32_t(INT32_MAX) ? 0u : value)));
}

} // namespace wr::reflect
