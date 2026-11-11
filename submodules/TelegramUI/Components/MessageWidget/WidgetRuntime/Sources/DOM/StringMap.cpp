#include "Sources/DOM/StringMap.h"

#include "Sources/DOM/DOM.h"

namespace wr {

static bool isASCIILower(char16_t c) {
    return c >= 'a' && c <= 'z';
}

static bool isASCIIUpper(char16_t c) {
    return c >= 'A' && c <= 'Z';
}

static constexpr char16_t kDataPrefix[] = u"data-";
static constexpr size_t kDataPrefixLength = 5;

/// HTML's name of the pair a qualified attribute name gives ("data-foo-bar" -> "fooBar"), into `out`: false when the
/// name does not start with "data-" or has an ASCII upper alpha after it. Two passes over the name.
static bool pairName(JSContext* ctx, const Vector<char16_t>& qualified, Vector<char16_t>& out) {
    if (qualified.size() < kDataPrefixLength) {
        return false;
    }
    for (size_t i = 0; i < kDataPrefixLength; i++) {
        if (qualified[i] != kDataPrefix[i]) {
            return false;
        }
    }
    for (size_t i = kDataPrefixLength; i < qualified.size(); i++) {
        if (isASCIIUpper(qualified[i])) {
            return false;
        }
    }
    out.clear();
    for (size_t i = kDataPrefixLength; i < qualified.size(); i++) {
        char16_t c = qualified[i];
        if (c == '-' && i + 1 < qualified.size() && isASCIILower(qualified[i + 1])) {
            out.push_back(char16_t(qualified[i + 1] - 32));
            i++;
        } else {
            out.push_back(c);
        }
    }
    return true;
}

/// "fooBar" -> "data-foo-bar": the setter's and deleter's mapping.
static String attributeNameFor(JSContext* ctx, const String& name) {
    Vector<char16_t> out(kDataPrefix, kDataPrefix + kDataPrefixLength, JSAllocator<char16_t>(JS_GetRuntime(ctx)));
    JSStringView v = name.view();
    for (uint32_t i = 0; i < v.length; i++) {
        char16_t c = v.latin1 ? v.latin1[i] : v.utf16[i];
        if (isASCIIUpper(c)) {
            out.push_back(u'-');
            out.push_back(char16_t(c + 32));
        } else {
            out.push_back(c);
        }
    }
    return String::fromUTF16(ctx, out.data(), out.size());
}

/// Whether `name` has a '-' followed by an ASCII lower alpha: no pair has such a name, and the setter refuses it.
static bool hasHyphenBeforeLower(JSContext* ctx, const String& name) {
    JSStringView v = name.view();
    for (uint32_t i = 0; i + 1 < v.length; i++) {
        char16_t c = v.latin1 ? v.latin1[i] : v.utf16[i];
        char16_t next = v.latin1 ? v.latin1[i + 1] : v.utf16[i + 1];
        if (c == '-' && isASCIILower(next)) {
            return true;
        }
    }
    return false;
}

std::vector<String> DOMStringMap::supportedNames(JSContext* ctx) {
    JSRuntime* rt = JS_GetRuntime(ctx);
    std::vector<String> names;
    Vector<char16_t> qualified{JSAllocator<char16_t>(rt)};
    Vector<char16_t> name{JSAllocator<char16_t>(rt)};
    for (size_t i = 0; i < m_element->attributeCount(); i++) {
        const Attribute& a = m_element->attributeAt(i);
        // The buffers are reused, so after the first name the copies allocate nothing.
        qualified.clear();
        if (a.prefix.atom != JS_ATOM_NULL) {
            appendCodeUnits(qualified, String::fromAtom(ctx, a.prefix.atom));
            qualified.push_back(u':');
        }
        appendCodeUnits(qualified, String::fromAtom(ctx, a.localName.atom));
        if (!pairName(ctx, qualified, name)) {
            continue;
        }
        String s = String::fromUTF16(ctx, name.data(), name.size());
        // Two attributes can give one name (the same qualified name in two namespaces): it is listed once.
        bool listed = false;
        for (const String& n : names) {
            if (n.equals(ctx, s)) {
                listed = true;
                break;
            }
        }
        if (!listed) {
            names.push_back(std::move(s));
        }
    }
    return names;
}

int DOMStringMap::find(JSContext* ctx, const String& name) {
    if (hasHyphenBeforeLower(ctx, name)) {
        return -1;
    }
    // The pair named `name` is the first attribute whose qualified name is attributeNameFor(name): the two mappings are
    // each other's inverse on names without a '-' before a lower alpha. That name has no ASCII upper alpha, so the
    // lowercasing findByQualifiedName does for an HTML element changes nothing.
    return m_element->findByQualifiedName(ctx, attributeNameFor(ctx, name));
}

std::optional<String> DOMStringMap::namedValue(JSContext* ctx, const String& name) {
    int i = this->find(ctx, name);
    if (i < 0) {
        return std::nullopt;
    }
    return String::adopt(ctx, JS_DupValue(ctx, m_element->attributeAt(size_t(i)).value.value));
}

void DOMStringMap::setNamed(JSContext* ctx, const String& name, const String& value) {
    if (hasHyphenBeforeLower(ctx, name)) {
        throw DOMError{"SyntaxError", "'" + quotedForMessage(name) + "' is not a valid dataset name."};
    }
    String attribute = attributeNameFor(ctx, name);
    if (!isValidAttributeLocalName(ctx, attribute)) {
        throw DOMError{"InvalidCharacterError", "'" + quotedForMessage(attribute) + "' is not a valid attribute name."};
    }
    Atom atom = Atom::fromString(ctx, attribute);
    m_element->setAttributeValue(ctx, atom.get(), value);
}

bool DOMStringMap::deleteNamed(JSContext* ctx, const String& name) {
    int i = this->find(ctx, name);
    if (i < 0) {
        return false;
    }
    m_element->removeAttributeAt(ctx, size_t(i));
    return true;
}

} // namespace wr
