#include "Sources/DOM/StyleDeclaration.h"

#include <algorithm>
#include <functional>
#include <map>
#include <optional>

#include "Generated/Bindings.h"
#include "Sources/DOM/DOM.h"
#include "Sources/Host/Window.h"
#include "Sources/Render/RenderTree.h"
#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Errors.h"

namespace wr {

namespace {

/// IDL/css-properties.txt, sorted bytewise (IDL/generate-css-properties.py writes it).
constexpr std::string_view kSupportedProperties[] = {
#include "Sources/DOM/CSSProperties.inc"
};

bool isSpace(char c) {
    return c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\f';
}

std::string trimmed(std::string_view s) {
    size_t start = 0;
    size_t end = s.size();
    while (start < end && isSpace(s[start])) {
        start++;
    }
    while (end > start && isSpace(s[end - 1])) {
        end--;
    }
    return std::string(s.substr(start, end - start));
}

void lowerASCII(std::string& s) {
    for (char& c : s) {
        if (c >= 'A' && c <= 'Z') {
            c = char(c + 32);
        }
    }
}

bool isCustomProperty(std::string_view name) {
    return name.size() > 2 && name[0] == '-' && name[1] == '-';
}

/// The property's name as the block keys it: ASCII lower case, but for a custom property.
std::string keyFor(std::string name) {
    if (!isCustomProperty(name)) {
        lowerASCII(name);
    }
    return name;
}

/// Just past the comment that starts at s[i] ("/*"): past its "*/", or the end of an unterminated one.
size_t skipComment(std::string_view s, size_t i) {
    size_t close = s.find("*/", i + 2);
    return close == std::string_view::npos ? s.size() : close + 2;
}

/// Just past the string that starts at s[i] (its quote): past the closing quote, at a newline (a bad string), or the
/// end. A backslash escapes the next character.
size_t skipString(std::string_view s, size_t i) {
    const char quote = s[i];
    for (i++; i < s.size(); i++) {
        if (s[i] == '\\') {
            i++;
        } else if (s[i] == quote) {
            return i + 1;
        } else if (s[i] == '\n') {
            return i;
        }
    }
    return s.size();
}

/// `s` with each comment outside a string replaced by a space.
std::string withoutComments(std::string_view s) {
    std::string out;
    out.reserve(s.size());
    size_t i = 0;
    while (i < s.size()) {
        if (s[i] == '"' || s[i] == '\'') {
            size_t end = skipString(s, i);
            out.append(s.substr(i, end - i));
            i = end;
        } else if (s[i] == '/' && i + 1 < s.size() && s[i + 1] == '*') {
            out.push_back(' ');
            i = skipComment(s, i);
        } else {
            out.push_back(s[i++]);
        }
    }
    return out;
}

/// The offsets of `s`'s top-level `stop` characters: outside strings and brackets (comments are gone already).
std::vector<size_t> topLevel(std::string_view s, char stop) {
    std::vector<size_t> found;
    int depth = 0;
    for (size_t i = 0; i < s.size();) {
        char c = s[i];
        if (c == '"' || c == '\'') {
            i = skipString(s, i);
            continue;
        }
        if (c == '(' || c == '[' || c == '{') {
            depth++;
        } else if ((c == ')' || c == ']' || c == '}') && depth > 0) {
            depth--;
        } else if (c == stop && depth == 0) {
            found.push_back(i);
        }
        i++;
    }
    return found;
}

/// A property name as CSS Syntax reads one: an ident (letters, digits, '-', '_', non-ASCII; not starting with a digit,
/// nor with '-' and a digit), or a custom property's `--` and anything of an ident's.
bool isValidName(std::string_view name) {
    if (name.empty()) {
        return false;
    }
    for (char c : name) {
        const unsigned char u = static_cast<unsigned char>(c);
        if (!(u >= 0x80 || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '-' || c == '_')) {
            return false;
        }
    }
    if (isCustomProperty(name)) {
        return true;
    }
    const size_t first = name[0] == '-' ? 1 : 0;
    return first < name.size() && !(name[first] >= '0' && name[first] <= '9') && name[first] != '-';
}

/// A value setProperty may set: no top-level `;` or `!` (either would end it or make it another declaration's).
bool isValidValue(std::string_view value) {
    return topLevel(value, ';').empty() && topLevel(value, '!').empty();
}

/// A declaration's text, `name: value [!important]`, as a Declaration; false when it is not one the block keeps.
bool readDeclaration(std::string_view raw, CSSStyleDeclaration::Declaration& out) {
    const std::string text = withoutComments(raw);
    const size_t colon = text.find(':');
    if (colon == std::string::npos) {
        return false;
    }
    std::string name = trimmed(std::string_view(text).substr(0, colon));
    if (!isValidName(name)) {
        return false;
    }
    name = keyFor(std::move(name));
    if (!CSSStyleDeclaration::isSupported(name)) {
        return false;
    }
    std::string value = trimmed(std::string_view(text).substr(colon + 1));
    bool important = false;
    const std::vector<size_t> bangs = topLevel(value, '!');
    if (!bangs.empty()) {
        std::string tail = trimmed(std::string_view(value).substr(bangs.back() + 1));
        lowerASCII(tail);
        if (bangs.size() > 1 || tail != "important") {
            return false;
        }
        important = true;
        value = trimmed(std::string_view(value).substr(0, bangs.back()));
    }
    if (value.empty()) {
        return false;
    }
    out = CSSStyleDeclaration::Declaration{std::move(name), std::move(value), important};
    return true;
}

} // namespace

bool CSSStyleDeclaration::isSupported(std::string_view name) {
    if (isCustomProperty(name)) {
        return true;
    }
    return std::binary_search(std::begin(kSupportedProperties), std::end(kSupportedProperties), name);
}

std::vector<CSSStyleDeclaration::Declaration> CSSStyleDeclaration::parse(JSContext* ctx, std::string_view text) {
    std::vector<Declaration> found;
    // Each kept name's place in `found`, so a parse is O(n log n) in its declarations whatever their names (an ordered
    // map: a hash table's buckets can be flooded with names chosen offline, as libc++'s string hash has no seed); a
    // declaration a later one replaced keeps its place with an empty name (no kept name is empty) until the end.
    std::map<std::string, size_t, std::less<>> placeOf;
    auto keep = [&](std::string_view raw) {
        Declaration d;
        if (!readDeclaration(raw, d)) {
            return;
        }
        auto earlier = placeOf.find(d.name);
        if (earlier != placeOf.end()) {
            // The later wins, at its place, unless only the earlier is important (the cascade inside a block).
            if (found[earlier->second].important && !d.important) {
                return;
            }
            found[earlier->second].name.clear();
            earlier->second = found.size();
        } else {
            placeOf.emplace(d.name, found.size());
        }
        found.push_back(std::move(d));
    };
    size_t start = 0;
    int depth = 0;
    size_t i = 0;
    while (i < text.size()) {
        const char c = text[i];
        if (c == '"' || c == '\'') {
            i = skipString(text, i);
            continue;
        }
        if (c == '/' && i + 1 < text.size() && text[i + 1] == '*') {
            i = skipComment(text, i);
            continue;
        }
        if (c == '(' || c == '[' || c == '{') {
            depth++;
        } else if ((c == ')' || c == ']' || c == '}') && depth > 0) {
            depth--;
        } else if (c == ';' && depth == 0) {
            keep(text.substr(start, i - start));
            start = i + 1;
        }
        i++;
    }
    keep(text.substr(std::min(start, text.size())));
    found.erase(std::remove_if(found.begin(), found.end(), [](const Declaration& d) { return d.name.empty(); }), found.end());
    return found;
}

std::string CSSStyleDeclaration::serialize(JSContext* ctx, const std::vector<Declaration>& declarations) {
    std::string out;
    for (const Declaration& d : declarations) {
        if (!out.empty()) {
            out.push_back(' ');
        }
        out += d.name;
        out += ": ";
        out += d.value;
        if (d.important) {
            out += " !important";
        }
        out.push_back(';');
    }
    return out;
}

std::vector<CSSStyleDeclaration::Declaration> CSSStyleDeclaration::declarations(JSContext* ctx) {
    std::optional<String> text = m_element->attributeValue(ctx, DOMState::of(ctx).name(Name::style));
    if (!text) {
        return {};
    }
    return parse(ctx, text->utf8ForParse());
}

void CSSStyleDeclaration::write(JSContext* ctx, const std::vector<Declaration>& declarations, bool quietly) {
    const std::string text = serialize(ctx, declarations);
    std::optional<Runtime::QuietOps> quiet;
    if (quietly) {
        quiet.emplace(Runtime::from(ctx));
    }
    m_element->setAttributeValue(ctx, DOMState::of(ctx).name(Name::style), String::fromUTF8(ctx, text));
}

bool CSSStyleDeclaration::styleSentBefore(JSContext* ctx) {
    const int index = m_element->findByNamespace(ctx, Namespace::None, JS_ATOM_NULL, DOMState::of(ctx).name(Name::style));
    return index >= 0 && m_element->attributeAt(size_t(index)).addedBatch != Runtime::from(ctx).batchSerial();
}

void CSSStyleDeclaration::countPropertyChange(JSContext* ctx, const std::string& name) {
    Runtime& runtime = Runtime::from(ctx);
    const uint64_t batch = runtime.batchSerial();
    if (m_opsBatch != batch) {
        m_opsBatch = batch;
        m_opsCounted.clear();
    }
    uint64_t stamp = 0;
    if (!m_element->countsChange(batch, stamp)) {
        return;
    }
    if (m_opsCounted.insert(std::hash<std::string>{}(name)).second) {
        runtime.addOps(1);
    }
}

void CSSStyleDeclaration::set(JSContext* ctx, std::string name, const String& value, bool important) {
    std::string text = trimmed(withoutComments(value.utf8ForParse()));
    if (text.empty() || !isValidValue(text)) {
        return;
    }
    std::vector<Declaration> list = this->declarations(ctx);
    auto existing = std::find_if(list.begin(), list.end(), [&](const Declaration& d) { return d.name == name; });
    if (existing != list.end()) {
        if (existing->value == text && existing->important == important) {
            return;
        }
        existing->value = std::move(text);
        existing->important = important;
    } else {
        list.push_back(Declaration{name, std::move(text), important});
    }
    const bool perProperty = this->styleSentBefore(ctx);
    if (perProperty) {
        this->countPropertyChange(ctx, name);
    }
    this->write(ctx, list, perProperty);
}

std::string CSSStyleDeclaration::remove(JSContext* ctx, const std::string& name) {
    std::vector<Declaration> list = this->declarations(ctx);
    std::string removed;
    auto it = std::remove_if(list.begin(), list.end(), [&](const Declaration& d) {
        if (d.name != name) {
            return false;
        }
        removed = d.value;
        return true;
    });
    if (it == list.end()) {
        return removed;
    }
    list.erase(it, list.end());
    const bool perProperty = this->styleSentBefore(ctx);
    if (perProperty) {
        this->countPropertyChange(ctx, name);
    }
    this->write(ctx, list, perProperty);
    return removed;
}

namespace {

[[noreturn]] void throwReadOnly() {
    throw DOMError{"NoModificationAllowedError", "A computed style declaration cannot be modified."};
}

} // namespace

std::optional<std::string> CSSStyleDeclaration::computedValue(JSContext* ctx, const std::string& name) {
    RenderTree* render = layoutForQuery(ctx);
    return render ? render->computedStyleValue(*m_element, name, m_pseudo) : std::nullopt;
}

String CSSStyleDeclaration::cssText(JSContext* ctx) {
    if (m_computed) {
        return String();
    }
    return String::fromUTF8(ctx, serialize(ctx, this->declarations(ctx)));
}

void CSSStyleDeclaration::setCssText(JSContext* ctx, LegacyNullToEmptyString text) {
    if (m_computed) {
        throwReadOnly();
    }
    this->write(ctx, parse(ctx, text.utf8ForParse()));
}

uint32_t CSSStyleDeclaration::length(JSContext* ctx) {
    if (m_computed) {
        return this->computedValue(ctx, "display") ? uint32_t(computedPropertyNames().size()) : 0;
    }
    return uint32_t(this->declarations(ctx).size());
}

String CSSStyleDeclaration::item(JSContext* ctx, uint32_t index) {
    if (m_computed) {
        return index < this->length(ctx) ? String::fromUTF8(ctx, computedPropertyNames()[index]) : String();
    }
    std::vector<Declaration> list = this->declarations(ctx);
    return index < list.size() ? String::fromUTF8(ctx, list[index].name) : String();
}

JSValue CSSStyleDeclaration::indexedValue(JSContext* ctx, uint32_t index) {
    return this->item(ctx, index).toJS(ctx);
}

String CSSStyleDeclaration::getPropertyValue(JSContext* ctx, String property) {
    const std::string name = keyFor(property.utf8ForParse());
    if (m_computed) {
        std::optional<std::string> value = this->computedValue(ctx, name);
        return value ? String::fromUTF8(ctx, *value) : String();
    }
    for (const Declaration& d : this->declarations(ctx)) {
        if (d.name == name) {
            return String::fromUTF8(ctx, d.value);
        }
    }
    return String();
}

String CSSStyleDeclaration::getPropertyPriority(JSContext* ctx, String property) {
    if (m_computed) {
        return String();
    }
    const std::string name = keyFor(property.utf8ForParse());
    for (const Declaration& d : this->declarations(ctx)) {
        if (d.name == name && d.important) {
            return String::fromUTF8(ctx, "important");
        }
    }
    return String();
}

void CSSStyleDeclaration::setProperty(JSContext* ctx, String property, LegacyNullToEmptyString value, LegacyNullToEmptyString priority) {
    if (m_computed) {
        throwReadOnly();
    }
    std::string name = keyFor(property.utf8ForParse());
    if (!isValidName(name) || !isSupported(name)) {
        return;
    }
    if (value.empty()) {
        this->remove(ctx, name);
        return;
    }
    std::string p = priority.utf8ForParse();
    lowerASCII(p);
    if (!p.empty() && p != "important") {
        return;
    }
    this->set(ctx, std::move(name), value, !p.empty());
}

String CSSStyleDeclaration::removeProperty(JSContext* ctx, String property) {
    if (m_computed) {
        throwReadOnly();
    }
    const std::string name = keyFor(property.utf8ForParse());
    return String::fromUTF8(ctx, this->remove(ctx, name));
}

String CSSStyleDeclaration::cssFloat(JSContext* ctx) {
    return this->getPropertyValue(ctx, String::fromUTF8(ctx, "float"));
}

void CSSStyleDeclaration::setCssFloat(JSContext* ctx, LegacyNullToEmptyString value) {
    this->setProperty(ctx, String::fromUTF8(ctx, "float"), std::move(value), LegacyNullToEmptyString());
}

String CSSStyleDeclaration::propertyValue(JSContext* ctx, JSAtom property) {
    return this->getPropertyValue(ctx, String::fromAtom(ctx, property));
}

void CSSStyleDeclaration::setPropertyValue(JSContext* ctx, JSAtom property, LegacyNullToEmptyString value) {
    // CSSOM: the attribute's setter is setProperty(property, value) with no priority.
    this->setProperty(ctx, String::fromAtom(ctx, property), std::move(value), LegacyNullToEmptyString());
}

Ref<CSSStyleDeclaration> Window::getComputedStyle(JSContext* ctx, Element* element, std::optional<String> pseudoElt) {
    const PseudoElement pseudo = pseudoElt ? pseudoElementNamed(pseudoElt->utf8ForParse()) : PseudoElement::None;
    return create<CSSStyleDeclaration>(ctx, idl::kCSSStyleDeclaration, ctx, *element, CSSStyleDeclaration::Computed{pseudo});
}

} // namespace wr
