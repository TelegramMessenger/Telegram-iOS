#include "Sources/DOM/Collections.h"

#include "Generated/Bindings.h"
#include "Sources/DOM/DOM.h"

namespace wr {

const Vector<Element*>* LiveElements::current(const Document& document) const {
    return m_document == &document && m_version == document.version() ? &m_elements : nullptr;
}

Vector<Element*>& LiveElements::restart() {
    m_document = nullptr;
    m_elements.clear();
    return m_elements;
}

void LiveElements::record(JSContext* ctx, Document& document) {
    m_documentRef.set(JS_GetRuntime(ctx), JS_DupValue(ctx, document.object()));
    m_document = &document;
    m_version = document.version();
}

void LiveElements::clear(JSRuntime* rt) {
    m_document = nullptr;
    m_elements.clear();
    m_documentRef.clear(rt);
}

Ref<StaticNodeList> StaticNodeList::make(JSContext* ctx, const std::vector<Node*>& nodes) {
    Ref<StaticNodeList> list = create<StaticNodeList>(ctx, idl::kNodeList, ctx);
    // Room first: growing can fail at the memory limit (JSAllocator throws bad_alloc), and then nothing is held yet.
    list->m_items.reserve(nodes.size());
    for (Node* n : nodes) {
        list->m_items.push_back(Held{JS_DupValue(ctx, n->object())});
    }
    return list;
}

void StaticNodeList::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    for (const Held& h : m_items) {
        h.mark(rt, mark);
    }
}

void StaticNodeList::dispose(JSRuntime* rt) {
    for (Held& h : m_items) {
        h.clear(rt);
    }
    m_items.clear();
}

NameNodeList::NameNodeList(JSContext* ctx, Document& document, const String& name) : m_root(&document), m_cache(JS_GetRuntime(ctx)) {
    m_rootRef.value = JS_DupValue(ctx, document.object());
    m_name.value = name.toJS(ctx);
}

void NameNodeList::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    m_rootRef.mark(rt, mark);
    m_cache.trace(rt, mark);
}

void NameNodeList::dispose(JSRuntime* rt) {
    m_rootRef.clear(rt);
    m_name.clear(rt);
    m_cache.clear(rt);
}

Node* NameNodeList::item(JSContext* ctx, uint32_t index) {
    const Vector<Element*>& e = this->elements(ctx);
    return index < e.size() ? e[index] : nullptr;
}

const Vector<Element*>& NameNodeList::elements(JSContext* ctx) {
    Document& document = m_root->nodeDocument();
    if (const Vector<Element*>* cached = m_cache.current(document)) {
        return *cached;
    }
    Vector<Element*>& found = m_cache.restart();
    String name = String::adopt(ctx, JS_DupValue(ctx, m_name.value));
    JSAtom nameAtom = DOMState::of(ctx).name(Name::name);
    for (Node* n = m_root->nextInTreeOrder(m_root); n; n = n->nextInTreeOrder(m_root)) {
        if (n->isElement()) {
            auto* e = static_cast<Element*>(n);
            if (e->isHTMLElement()) {
                std::optional<String> value = e->attributeValue(ctx, nameAtom);
                if (value && value->equals(ctx, name)) {
                    found.push_back(e);
                }
            }
        }
    }
    m_cache.record(ctx, document);
    return found;
}

HTMLCollection::HTMLCollection(JSContext* ctx, Node& root, Kind kind)
    : m_root(&root), m_kind(kind), m_classes(JSAllocator<Held>(JS_GetRuntime(ctx))), m_cache(JS_GetRuntime(ctx)) {
    m_rootRef.value = JS_DupValue(ctx, root.object());
}

void HTMLCollection::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    m_rootRef.mark(rt, mark);
    m_cache.trace(rt, mark);
}

void HTMLCollection::dispose(JSRuntime* rt) {
    m_rootRef.clear(rt);
    m_qualifiedNameAtom.clear(rt);
    m_qualifiedNameLowerAtom.clear(rt);
    m_qualifiedName.clear(rt);
    m_qualifiedNameLower.clear(rt);
    m_otherNamespace.clear(rt);
    m_localName.clear(rt);
    for (Held& h : m_classes) {
        h.clear(rt);
    }
    m_classes.clear();
    m_cache.clear(rt);
}

void HTMLCollection::setQualifiedName(JSContext* ctx, const String& qualifiedName) {
    m_any = qualifiedName.equalsASCII("*");
    String lower = asciiLowercase(ctx, qualifiedName);
    m_qualifiedName.value = qualifiedName.toJS(ctx);
    m_qualifiedNameLower.value = lower.toJS(ctx);
    m_qualifiedNameAtom.atom = Atom::fromString(ctx, qualifiedName).release();
    m_qualifiedNameLowerAtom.atom = Atom::fromString(ctx, lower).release();
}

void HTMLCollection::setNamespaceAndLocalName(JSContext* ctx, const std::optional<String>& ns, const String& localName) {
    m_anyNamespace = ns && ns->equalsASCII("*");
    m_ns = m_anyNamespace ? Namespace::None : namespaceOf(ns);
    if (m_ns == Namespace::Other) {
        m_otherNamespace.atom = Atom::fromString(ctx, *ns).release();
    }
    m_anyLocalName = localName.equalsASCII("*");
    m_localName.atom = Atom::fromString(ctx, localName).release();
}

static char16_t unitOf(const JSStringView& v, uint32_t i) {
    return v.latin1 ? char16_t(v.latin1[i]) : char16_t(v.utf16[i]);
}

void HTMLCollection::setClassNames(JSContext* ctx, const String& classNames) {
    // DOM's ordered set parser (orderedSetTokens: worst-case O(n log n)), then a counted substring for each class kept
    // only: a value repeating one class keeps it once, with no copy per repeat.
    Vector<TokenRange> classes = orderedSetTokens(ctx, classNames);
    m_classes.reserve(classes.size());
    for (const TokenRange& t : classes) {
        m_classes.push_back(Held{classNames.substring(ctx, t.start, t.end).toJS(ctx)});
    }
}

static char16_t asciiLower(char16_t c) {
    return c >= 'A' && c <= 'Z' ? char16_t(c + ('a' - 'A')) : c;
}

/// Whether `token` is `v`'s code units [start, end), ASCII case-insensitively when `fold`.
static bool tokenIs(JSContext* ctx, const JSStringView& token, const JSStringView& v, uint32_t start, uint32_t end, bool fold) {
    if (token.length != end - start) {
        return false;
    }
    for (uint32_t i = 0; i < token.length; i++) {
        char16_t a = unitOf(token, i);
        char16_t b = unitOf(v, start + i);
        if (fold ? asciiLower(a) != asciiLower(b) : a != b) {
            return false;
        }
    }
    return true;
}

bool elementHasClasses(JSContext* ctx, Element& element, ClassNameList classes, bool quirks) {
    std::optional<String> value = element.attributeValue(ctx, DOMState::of(ctx).name(Name::class_));
    if (!value) {
        return classes.empty();
    }
    // The value's tokens in place (DOM's ordered set parser without the copies): a walk per class wanted, which stops at
    // the first token that is that class. `value` holds the string the view reads; `classes` is read in place too.
    JSStringView v = value->view();
    for (size_t ci = 0; ci < classes.size(); ci++) {
        JSStringView w = classes.view(ci);
        bool found = false;
        uint32_t i = 0;
        while (!found && i < v.length) {
            while (i < v.length && isASCIIWhitespace(unitOf(v, i))) {
                i++;
            }
            uint32_t start = i;
            while (i < v.length && !isASCIIWhitespace(unitOf(v, i))) {
                i++;
            }
            if (i > start) {
                found = tokenIs(ctx, w, v, start, i, quirks);
            }
        }
        if (!found) {
            return false;
        }
    }
    return true;
}

bool HTMLCollection::matches(JSContext* ctx, Element& element) const {
    switch (m_kind) {
    case Kind::Children:
        return true;
    case Kind::TagName: {
        if (m_any) {
            return true;
        }
        bool lower = element.isHTMLElement() && element.nodeDocument().isHTMLDocument();
        // An unprefixed element's qualified name is its local name: one atom to another (equal strings are one atom).
        if (element.prefixAtom() == JS_ATOM_NULL) {
            return element.localNameAtom() == (lower ? m_qualifiedNameLowerAtom.atom : m_qualifiedNameAtom.atom);
        }
        String name = String::adopt(ctx, JS_DupValue(ctx, (lower ? m_qualifiedNameLower : m_qualifiedName).value));
        return qualifiedNameIs(ctx, element.prefixAtom(), element.localNameAtom(), name);
    }
    case Kind::TagNameNS:
        if (!m_anyNamespace && (element.ns() != m_ns || (m_ns == Namespace::Other && element.otherNamespaceAtom() != m_otherNamespace.atom))) {
            return false;
        }
        return m_anyLocalName || element.localNameAtom() == m_localName.atom;
    case Kind::ClassName:
        return elementHasClasses(ctx, element, m_classes, element.nodeDocument().mode() == DocumentMode::Quirks);
    }
    return false;
}

const Vector<Element*>& HTMLCollection::elements(JSContext* ctx) {
    Document& document = m_root->nodeDocument();
    if (const Vector<Element*>* cached = m_cache.current(document)) {
        return *cached;
    }
    Vector<Element*>& found = m_cache.restart();
    if (m_kind == Kind::Children) {
        for (size_t i = 0; i < m_root->childCount(); i++) {
            if (m_root->childAt(i)->isElement()) {
                found.push_back(static_cast<Element*>(m_root->childAt(i)));
            }
        }
    } else if (m_kind != Kind::ClassName || !m_classes.empty()) {
        // No class names match nothing (DOM: "If classes is the empty set, return an empty HTMLCollection"). The class
        // list is read in place (no per-recompute copy).
        for (Node* n = m_root->nextInTreeOrder(m_root); n; n = n->nextInTreeOrder(m_root)) {
            if (n->isElement() && this->matches(ctx, *static_cast<Element*>(n))) {
                found.push_back(static_cast<Element*>(n));
            }
        }
    }
    m_cache.record(ctx, document);
    return found;
}

Element* HTMLCollection::item(JSContext* ctx, uint32_t index) {
    const Vector<Element*>& e = this->elements(ctx);
    return index < e.size() ? e[index] : nullptr;
}

Element* HTMLCollection::namedItem(JSContext* ctx, String name) {
    if (name.empty()) {
        return nullptr;
    }
    DOMState& state = DOMState::of(ctx);
    for (Element* e : this->elements(ctx)) {
        std::optional<String> id = e->attributeValue(ctx, state.name(Name::id));
        if (id && id->equals(ctx, name)) {
            return e;
        }
        if (e->isHTMLElement()) {
            std::optional<String> n = e->attributeValue(ctx, state.name(Name::name));
            if (n && n->equals(ctx, name)) {
                return e;
            }
        }
    }
    return nullptr;
}

} // namespace wr
