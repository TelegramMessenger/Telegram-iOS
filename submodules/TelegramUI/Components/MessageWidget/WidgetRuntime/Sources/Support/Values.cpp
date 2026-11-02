#include "Sources/Support/Values.h"

#include <algorithm>

#include "Sources/Support/Errors.h"

namespace wr {

String String::fromJS(JSContext* ctx, JSValueConst v) {
    return adopt(ctx, checked(ctx, JS_ToString(ctx, v)));
}

String String::adopt(JSContext* ctx, JSValue v) {
    Value owned = Value::adopt(ctx, v);
    String s;
    s.m_value = Value::adopt(ctx, checked(ctx, JS_FlattenString(ctx, owned.get())));
    return s;
}

String String::fromUTF8(JSContext* ctx, std::string_view utf8) {
    return adopt(ctx, checked(ctx, JS_NewStringLen(ctx, utf8.data(), utf8.size())));
}

String String::fromUTF16(JSContext* ctx, const char16_t* units, size_t length) {
    return adopt(ctx, checked(ctx, JS_NewStringUTF16(ctx, reinterpret_cast<const uint16_t*>(units), length)));
}

String String::fromAtom(JSContext* ctx, JSAtom atom) {
    return adopt(ctx, checked(ctx, JS_AtomToString(ctx, atom)));
}

JSStringView String::view() const {
    JSStringView v{nullptr, nullptr, 0};
    JS_GetStringView(m_value.get(), &v);
    return v;
}

char16_t String::at(uint32_t index) const {
    JSStringView v = this->view();
    if (index >= v.length) {
        return 0;
    }
    return v.latin1 ? char16_t(v.latin1[index]) : char16_t(v.utf16[index]);
}

bool String::equals(JSContext* ctx, const String& other) const {
    JSStringView a = this->view(), b = other.view();
    if (a.length != b.length) {
        return false;
    }
    for (uint32_t i = 0; i < a.length; i++) {
        char16_t x = a.latin1 ? a.latin1[i] : a.utf16[i];
        char16_t y = b.latin1 ? b.latin1[i] : b.utf16[i];
        if (x != y) {
            return false;
        }
    }
    return true;
}

bool String::equalsASCII(std::string_view ascii) const {
    JSStringView v = this->view();
    if (v.length != ascii.size()) {
        return false;
    }
    for (uint32_t i = 0; i < v.length; i++) {
        char16_t c = v.latin1 ? v.latin1[i] : v.utf16[i];
        if (c != char16_t(static_cast<unsigned char>(ascii[i]))) {
            return false;
        }
    }
    return true;
}

bool String::equalsIgnoringASCIICase(std::string_view ascii) const {
    auto lower = [](char16_t c) -> char16_t { return c >= 'A' && c <= 'Z' ? char16_t(c + 32) : c; };
    JSStringView v = this->view();
    if (v.length != ascii.size()) {
        return false;
    }
    for (uint32_t i = 0; i < v.length; i++) {
        char16_t c = v.latin1 ? v.latin1[i] : v.utf16[i];
        if (lower(c) != lower(char16_t(static_cast<unsigned char>(ascii[i])))) {
            return false;
        }
    }
    return true;
}

String String::substring(JSContext* ctx, uint32_t start, uint32_t end) const {
    if (!m_value.context()) {
        return String();
    }
    return adopt(ctx, checked(ctx, JS_SubString(ctx, m_value.get(), start, end)));
}

String String::concat(JSContext* ctx, const String& other) const {
    if (!m_value.context()) {
        return other;
    }
    if (!other.m_value.context()) {
        return *this;
    }
    return adopt(ctx, checked(ctx, JS_ConcatStrings2(ctx, m_value.get(), other.m_value.get())));
}

std::string String::utf8Prefix(size_t maxBytes, bool* cut, bool replaceLoneSurrogates) const {
    JSStringView v = this->view();
    std::string out;
    out.reserve(std::min<size_t>(v.length, maxBytes));
    uint32_t i = 0;
    for (; i < v.length; i++) {
        uint32_t c = v.latin1 ? v.latin1[i] : v.utf16[i];
        bool pair = !v.latin1 && c >= 0xD800 && c <= 0xDBFF && i + 1 < v.length && v.utf16[i + 1] >= 0xDC00 && v.utf16[i + 1] <= 0xDFFF;
        if (pair) {
            c = 0x10000 + ((c - 0xD800) << 10) + (v.utf16[i + 1] - 0xDC00);
        } else if (replaceLoneSurrogates && c >= 0xD800 && c <= 0xDFFF) {
            // A lone surrogate becomes one U+FFFD (still three bytes, so the byte count is unchanged).
            c = 0xFFFD;
        }
        size_t bytes = c < 0x80 ? 1 : c < 0x800 ? 2 : c < 0x10000 ? 3 : 4;
        if (out.size() + bytes > maxBytes) {
            break;
        }
        if (pair) {
            i++;
        }
        if (c < 0x80) {
            out += char(c);
        } else if (c < 0x800) {
            out += char(0xC0 | (c >> 6));
            out += char(0x80 | (c & 0x3F));
        } else if (c < 0x10000) {
            out += char(0xE0 | (c >> 12));
            out += char(0x80 | ((c >> 6) & 0x3F));
            out += char(0x80 | (c & 0x3F));
        } else {
            out += char(0xF0 | (c >> 18));
            out += char(0x80 | ((c >> 12) & 0x3F));
            out += char(0x80 | ((c >> 6) & 0x3F));
            out += char(0x80 | (c & 0x3F));
        }
    }
    if (cut) {
        *cut = i < v.length;
    }
    return out;
}

JSValue String::toJS(JSContext* ctx) const {
    return m_value.context() ? JS_DupValue(ctx, m_value.get()) : JS_NewString(ctx, "");
}

Atom Atom::fromString(JSContext* ctx, const String& s) {
    JSAtom a = JS_ValueToAtom(ctx, s.value());
    if (a == JS_ATOM_NULL) {
        throw Thrown{};
    }
    return adopt(ctx, a);
}

Atom Atom::fromUTF8(JSContext* ctx, std::string_view utf8) {
    JSAtom a = JS_NewAtomLen(ctx, utf8.data(), utf8.size());
    if (a == JS_ATOM_NULL) {
        throw Thrown{};
    }
    return adopt(ctx, a);
}

} // namespace wr
