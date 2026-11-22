#pragma once

#include "Sources/DOM/Namespaces.h"
#include "Sources/DOM/Node.h"

namespace wr {

class Element;

/// An attribute as a node (DOM's Attr). While it belongs to an element, its value lives in the element's entry and the
/// Attr holds a counted, traced reference to the element; on its own it keeps its value.
class Attr : public Node {
public:
    /// The atoms are borrowed; the Attr keeps its own references.
    Attr(JSContext* ctx, Document& document, Namespace ns, JSAtom otherNamespace, JSAtom prefix, JSAtom localName, String value);

    Namespace ns() const { return m_ns; }
    JSAtom localNameAtom() const { return m_localName.atom; }
    JSAtom prefixAtom() const { return m_prefix.atom; }
    JSAtom otherNamespaceAtom() const { return m_otherNamespace.atom; }
    /// The element whose attribute it is (a view: the Attr holds the reference).
    Element* owner() const { return m_owner; }
    /// It is `element`'s from now on, in `element`'s document: its value lives in the element's entry.
    void attachTo(JSContext* ctx, Element& element);
    /// Its element let it go: it takes over `value`, a reference the caller gives up. Releases nothing but the
    /// element, so the element may call it at any point of an edit.
    void detach(JSRuntime* rt, JSValue value);
    String currentValue(JSContext* ctx) const;

    // Attr
    std::optional<String> namespaceURI(JSContext* ctx) { return namespaceURIOf(ctx, m_ns, m_otherNamespace.atom); }
    std::optional<String> prefix(JSContext* ctx);
    String localName(JSContext* ctx) { return String::fromAtom(ctx, m_localName.atom); }
    String name(JSContext* ctx);
    String value(JSContext* ctx) { return this->currentValue(ctx); }
    /// DOM "set an existing attribute value".
    void setValue(JSContext* ctx, String value);
    Element* ownerElement(JSContext*) { return m_owner; }
    bool specified(JSContext*) { return true; }
    String nodeName(JSContext* ctx) override { return this->name(ctx); }

    Ref<Node> cloneShallow(JSContext* ctx, Document& document) override;
    bool equalsShallow(JSContext* ctx, Node& other) override;
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

private:
    Namespace m_ns;
    HeldAtom m_localName;
    HeldAtom m_prefix;
    HeldAtom m_otherNamespace;
    /// The value while it has no element (undefined while it has one).
    Held m_value;
    Element* m_owner = nullptr;
    Held m_ownerRef;
};

} // namespace wr
