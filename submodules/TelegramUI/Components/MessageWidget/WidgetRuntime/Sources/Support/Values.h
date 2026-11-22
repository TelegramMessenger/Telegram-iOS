// Values C++ owns. Value, String and Atom hold a context and are for code running in a call. Held and HeldAtom are
// what payloads store: they are released with the runtime, because a finalizer has no context.
#pragma once

#include <cstddef>
#include <cstdint>
#include <string>
#include <string_view>
#include <utility>

#include "quickjs.h"

namespace wr {

class Value {
public:
    Value() = default;
    static Value adopt(JSContext* ctx, JSValue v) {
        Value r;
        r.m_ctx = ctx;
        r.m_value = v;
        return r;
    }
    static Value dup(JSContext* ctx, JSValueConst v) { return adopt(ctx, JS_DupValue(ctx, v)); }
    Value(const Value& other) : m_ctx(other.m_ctx), m_value(other.m_ctx ? JS_DupValue(other.m_ctx, other.m_value) : JS_UNDEFINED) {}
    Value(Value&& other) noexcept : m_ctx(other.m_ctx), m_value(other.m_value) {
        other.m_ctx = nullptr;
        other.m_value = JS_UNDEFINED;
    }
    Value& operator=(Value other) noexcept {
        std::swap(m_ctx, other.m_ctx);
        std::swap(m_value, other.m_value);
        return *this;
    }
    ~Value() {
        if (m_ctx) {
            JS_FreeValue(m_ctx, m_value);
        }
    }
    JSValueConst get() const { return m_value; }
    JSContext* context() const { return m_ctx; }
    /// A new reference, for handing to QuickJS.
    JSValue newRef() const { return m_ctx ? JS_DupValue(m_ctx, m_value) : JS_UNDEFINED; }
    /// Gives the reference up.
    JSValue release() {
        JSValue v = m_value;
        m_ctx = nullptr;
        m_value = JS_UNDEFINED;
        return v;
    }

private:
    JSContext* m_ctx = nullptr;
    JSValue m_value = JS_UNDEFINED;
};

/// WebIDL `object`.
class Object : public Value {
public:
    Object() = default;
    explicit Object(Value v) : Value(std::move(v)) {}
};

/// A flat QuickJS string. A default String is "" with no value.
class String {
public:
    String() = default;
    /// ToString(v), flattened. Throws Thrown.
    static String fromJS(JSContext* ctx, JSValueConst v);
    /// Takes over a string value, flattening a rope. Throws Thrown.
    static String adopt(JSContext* ctx, JSValue v);
    static String fromUTF8(JSContext* ctx, std::string_view utf8);
    static String fromUTF16(JSContext* ctx, const char16_t* units, size_t length);
    static String fromAtom(JSContext* ctx, JSAtom atom);

    uint32_t length() const { return JS_GetStringLength(m_value.get()); }
    bool empty() const { return this->length() == 0; }
    char16_t at(uint32_t index) const;
    /// The characters, without copying ({nullptr, nullptr, 0} for the default).
    JSStringView view() const;
    /// Compares the characters (strings of different lengths compare nothing).
    bool equals(JSContext* ctx, const String& other) const;
    bool equalsASCII(std::string_view ascii) const;
    bool equalsIgnoringASCIICase(std::string_view ascii) const;
    String substring(JSContext* ctx, uint32_t start, uint32_t end) const;
    String concat(JSContext* ctx, const String& other) const;
    /// UTF-8; a lone surrogate becomes its 3-byte WTF-8 sequence.
    std::string utf8() const { return this->utf8Prefix(SIZE_MAX, nullptr); }
    /// UTF-8 for the HTML parser: a lone surrogate becomes one U+FFFD (EF BF BD) rather than WTF-8, which gumbo would
    /// reject byte by byte into three U+FFFD. Same byte count as utf8() for every character (a lone surrogate is three
    /// bytes either way).
    std::string utf8ForParse() const { return this->utf8Prefix(SIZE_MAX, nullptr, true); }
    /// The longest prefix of utf8() that is at most `maxBytes` and ends at a character boundary, converting only that
    /// much; *cut (when given) says whether anything was left out. `replaceLoneSurrogates` makes a lone surrogate one
    /// U+FFFD (for the parser) rather than WTF-8.
    std::string utf8Prefix(size_t maxBytes, bool* cut, bool replaceLoneSurrogates = false) const;
    /// A new reference ("" for the default).
    JSValue toJS(JSContext* ctx) const;
    JSValueConst value() const { return m_value.get(); }

private:
    Value m_value;
};

/// WebIDL USVString: lone surrogates became U+FFFD on conversion.
class USVString : public String {
public:
    USVString() = default;
    explicit USVString(String s) : String(std::move(s)) {}
};

/// [LegacyNullToEmptyString] DOMString: null converted to "".
class LegacyNullToEmptyString : public String {
public:
    LegacyNullToEmptyString() = default;
    explicit LegacyNullToEmptyString(String s) : String(std::move(s)) {}
};

class Atom {
public:
    Atom() = default;
    static Atom adopt(JSContext* ctx, JSAtom atom) {
        Atom r;
        r.m_ctx = ctx;
        r.m_atom = atom;
        return r;
    }
    static Atom dup(JSContext* ctx, JSAtom atom) { return adopt(ctx, JS_DupAtom(ctx, atom)); }
    /// Throws Thrown.
    static Atom fromString(JSContext* ctx, const String& s);
    static Atom fromUTF8(JSContext* ctx, std::string_view utf8);
    Atom(const Atom& other) : m_ctx(other.m_ctx), m_atom(other.m_ctx ? JS_DupAtom(other.m_ctx, other.m_atom) : JS_ATOM_NULL) {}
    Atom(Atom&& other) noexcept : m_ctx(other.m_ctx), m_atom(other.m_atom) {
        other.m_ctx = nullptr;
        other.m_atom = JS_ATOM_NULL;
    }
    Atom& operator=(Atom other) noexcept {
        std::swap(m_ctx, other.m_ctx);
        std::swap(m_atom, other.m_atom);
        return *this;
    }
    ~Atom() {
        if (m_ctx) {
            JS_FreeAtom(m_ctx, m_atom);
        }
    }
    JSAtom get() const { return m_atom; }
    JSAtom release() {
        JSAtom a = m_atom;
        m_ctx = nullptr;
        m_atom = JS_ATOM_NULL;
        return a;
    }
    bool operator==(const Atom& other) const { return m_atom == other.m_atom; }

private:
    JSContext* m_ctx = nullptr;
    JSAtom m_atom = JS_ATOM_NULL;
};

/// A counted value stored in a payload.
struct Held {
    JSValue value = JS_UNDEFINED;
    /// Replaces the value, taking over `owned` and releasing the old one.
    void set(JSRuntime* rt, JSValue owned) {
        JSValue old = value;
        value = owned;
        JS_FreeValueRT(rt, old);
    }
    void clear(JSRuntime* rt) { set(rt, JS_UNDEFINED); }
    void mark(JSRuntime* rt, JS_MarkFunc* markFunc) const { JS_MarkValue(rt, value, markFunc); }
    bool isUndefined() const { return JS_IsUndefined(value); }
};

/// A counted atom stored in a payload.
struct HeldAtom {
    JSAtom atom = JS_ATOM_NULL;
    void set(JSRuntime* rt, JSAtom owned) {
        JSAtom old = atom;
        atom = owned;
        if (old != JS_ATOM_NULL) {
            JS_FreeAtomRT(rt, old);
        }
    }
    void clear(JSRuntime* rt) { set(rt, JS_ATOM_NULL); }
};

} // namespace wr
