#include "Sources/DOM/TokenList.h"

#include "Sources/DOM/DOM.h"

namespace wr {

DOMTokenList::DOMTokenList(JSContext* ctx, Element& element, JSAtom attribute)
    : m_element(&element), m_tokens(JSAllocator<Held>(JS_GetRuntime(ctx))) {
    m_elementRef.value = JS_DupValue(ctx, element.object());
    m_attribute.atom = JS_DupAtom(ctx, attribute);
}

void DOMTokenList::clearTokens(JSRuntime* rt) {
    for (Held& t : m_tokens) {
        t.clear(rt);
    }
    m_tokens.clear();
}

void DOMTokenList::dispose(JSRuntime* rt) {
    m_elementRef.clear(rt);
    m_attribute.clear(rt);
    m_parsedFrom.clear(rt);
    this->clearTokens(rt);
}

static char16_t unitAt(const JSStringView& v, uint32_t i) {
    return v.latin1 ? char16_t(v.latin1[i]) : char16_t(v.utf16[i]);
}

/// Whether the string `token` is `v`'s code units [start, end).
static bool tokenIs(JSContext* ctx, JSValueConst token, const JSStringView& v, uint32_t start, uint32_t end) {
    JSStringView t{nullptr, nullptr, 0};
    JS_GetStringView(token, &t);
    if (t.length != end - start) {
        return false;
    }
    for (uint32_t i = 0; i < t.length; i++) {
        if (unitAt(t, i) != unitAt(v, start + i)) {
            return false;
        }
    }
    return true;
}

// The DOM's "ordered set parser": the tokens in order, each kept once. A token is cut out of the value only when it
// is new, so a value repeating one token does not allocate per repeat.
void DOMTokenList::parse(JSContext* ctx, const String& value) {
    JSStringView v = value.view();
    // Every unit is read once by the scan.
    uint32_t i = 0;
    while (i < v.length) {
        while (i < v.length && isASCIIWhitespace(unitAt(v, i))) {
            i++;
        }
        uint32_t start = i;
        while (i < v.length && !isASCIIWhitespace(unitAt(v, i))) {
            i++;
        }
        if (i == start) {
            continue;
        }
        bool duplicate = false;
        for (const Held& t : m_tokens) {
            if (tokenIs(ctx, t.value, v, start, i)) {
                duplicate = true;
                break;
            }
        }
        if (!duplicate) {
            String token = value.substring(ctx, start, i);
            m_tokens.emplace_back();
            m_tokens.back().value = token.toJS(ctx);
        }
    }
}

const Vector<Held>& DOMTokenList::tokens(JSContext* ctx) {
    JSRuntime* rt = JS_GetRuntime(ctx);
    int i = m_element->findByNamespace(ctx, Namespace::None, JS_ATOM_NULL, m_attribute.atom);
    JSValueConst current = i < 0 ? JS_UNDEFINED : m_element->attributeAt(size_t(i)).value.value;
    bool same = m_parsed && JS_VALUE_GET_TAG(current) == JS_VALUE_GET_TAG(m_parsedFrom.value) &&
                (JS_IsUndefined(current) || JS_VALUE_GET_PTR(current) == JS_VALUE_GET_PTR(m_parsedFrom.value));
    if (same) {
        return m_tokens;
    }
    // Not parsed until the parse below is complete: a parse the memory limit stops is redone on the next read.
    m_parsed = false;
    this->clearTokens(rt);
    m_parsedFrom.set(rt, JS_DupValue(ctx, current));
    if (!JS_IsUndefined(current)) {
        this->parse(ctx, String::adopt(ctx, JS_DupValue(ctx, current)));
    }
    m_parsed = true;
    return m_tokens;
}

std::optional<String> DOMTokenList::item(JSContext* ctx, uint32_t index) {
    const Vector<Held>& t = this->tokens(ctx);
    if (index >= t.size()) {
        return std::nullopt;
    }
    return String::adopt(ctx, JS_DupValue(ctx, t[index].value));
}

/// The DOM's "validation" of a token argument: SyntaxError when empty, InvalidCharacterError with ASCII whitespace.
static void checkNotEmpty(const String& token) {
    if (token.empty()) {
        throw DOMError{"SyntaxError", "The token is empty."};
    }
}

static void checkNoWhitespace(JSContext* ctx, const String& token) {
    JSStringView v = token.view();
    for (uint32_t i = 0; i < v.length; i++) {
        if (isASCIIWhitespace(unitAt(v, i))) {
            throw DOMError{"InvalidCharacterError", "The token contains ASCII whitespace."};
        }
    }
}

static void validateToken(JSContext* ctx, const String& token) {
    checkNotEmpty(token);
    checkNoWhitespace(ctx, token);
}

/// The index of `token` in `set`, or -1.
static int indexOf(JSContext* ctx, const Vector<String>& set, const String& token) {
    for (size_t i = 0; i < set.size(); i++) {
        if (set[i].equals(ctx, token)) {
            return int(i);
        }
    }
    return -1;
}

Vector<String> DOMTokenList::copyOfTokens(JSContext* ctx) {
    const Vector<Held>& tokens = this->tokens(ctx);
    Vector<String> set{JSAllocator<String>(JS_GetRuntime(ctx))};
    set.reserve(tokens.size());
    for (const Held& t : tokens) {
        set.push_back(String::adopt(ctx, JS_DupValue(ctx, t.value)));
    }
    return set;
}

bool DOMTokenList::contains(JSContext* ctx, String token) {
    const Vector<Held>& tokens = this->tokens(ctx);
    JSStringView v = token.view();
    for (const Held& t : tokens) {
        if (tokenIs(ctx, t.value, v, 0, v.length)) {
            return true;
        }
    }
    return false;
}

void DOMTokenList::update(JSContext* ctx, const Vector<String>& set) {
    JSRuntime* rt = JS_GetRuntime(ctx);
    // No attribute and an empty set leave it absent.
    if (set.empty() && !m_element->hasAttributeAtom(ctx, m_attribute.atom)) {
        return;
    }
    // The ordered set serializer.
    Vector<char16_t> serialized{JSAllocator<char16_t>(rt)};
    for (size_t i = 0; i < set.size(); i++) {
        if (i) {
            serialized.push_back(u' ');
        }
        appendCodeUnits(serialized, set[i]);
    }
    String value = String::fromUTF16(ctx, serialized.data(), serialized.size());
    m_element->setAttributeValue(ctx, m_attribute.atom, value);
    // The attribute holds `value` itself (a reference to the same string), and its tokens are `set`: no other value
    // can match it, so the next read finds this set without parsing it back.
    Vector<Held> tokens{JSAllocator<Held>(rt)};
    tokens.reserve(set.size());
    m_parsed = false;
    for (const String& token : set) {
        tokens.emplace_back();
        tokens.back().value = token.toJS(ctx);
    }
    this->clearTokens(rt);
    m_tokens = std::move(tokens);
    m_parsedFrom.set(rt, value.toJS(ctx));
    m_parsed = true;
}

void DOMTokenList::add(JSContext* ctx, std::vector<String> tokens) {
    for (const String& token : tokens) {
        validateToken(ctx, token);
    }
    Vector<String> set = this->copyOfTokens(ctx);
    for (String& token : tokens) {
        if (indexOf(ctx, set, token) < 0) {
            set.push_back(std::move(token));
        }
    }
    this->update(ctx, set);
}

void DOMTokenList::remove(JSContext* ctx, std::vector<String> tokens) {
    for (const String& token : tokens) {
        validateToken(ctx, token);
    }
    Vector<String> set = this->copyOfTokens(ctx);
    for (const String& token : tokens) {
        int i = indexOf(ctx, set, token);
        if (i >= 0) {
            set.erase(set.begin() + i);
        }
    }
    this->update(ctx, set);
}

bool DOMTokenList::toggle(JSContext* ctx, String token, std::optional<bool> force) {
    validateToken(ctx, token);
    Vector<String> set = this->copyOfTokens(ctx);
    int i = indexOf(ctx, set, token);
    if (i >= 0) {
        if (!force || !*force) {
            set.erase(set.begin() + i);
            this->update(ctx, set);
            return false;
        }
        return true;
    }
    if (!force || *force) {
        set.push_back(token);
        this->update(ctx, set);
        return true;
    }
    return false;
}

bool DOMTokenList::replace(JSContext* ctx, String token, String newToken) {
    checkNotEmpty(token);
    checkNotEmpty(newToken);
    checkNoWhitespace(ctx, token);
    checkNoWhitespace(ctx, newToken);
    Vector<String> set = this->copyOfTokens(ctx);
    if (indexOf(ctx, set, token) < 0) {
        return false;
    }
    // Infra's "replace" within an ordered set: the first instance of either becomes newToken, every other goes.
    Vector<String> replaced{JSAllocator<String>(JS_GetRuntime(ctx))};
    replaced.reserve(set.size());
    bool placed = false;
    for (String& t : set) {
        if (t.equals(ctx, token) || t.equals(ctx, newToken)) {
            if (!placed) {
                replaced.push_back(newToken);
                placed = true;
            }
        } else {
            replaced.push_back(std::move(t));
        }
    }
    this->update(ctx, replaced);
    return true;
}

bool DOMTokenList::supports(JSContext*, String) {
    throw TypeError{"This attribute has no supported tokens."};
}

String DOMTokenList::value(JSContext* ctx) {
    return m_element->attributeValue(ctx, m_attribute.atom).value_or(String());
}

void DOMTokenList::setValue(JSContext* ctx, String value) {
    m_element->setAttributeValue(ctx, m_attribute.atom, value);
}

} // namespace wr
