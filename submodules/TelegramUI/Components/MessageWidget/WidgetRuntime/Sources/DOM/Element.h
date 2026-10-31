#pragma once

#include "Sources/DOM/Namespaces.h"
#include "Sources/DOM/Node.h"

namespace wr {

class Attr;
class CSSStyleDeclaration;
class DOMStringMap;
class DOMTokenList;
class NamedNodeMap;

/// One entry of an element's attribute list: counted references the element releases. Its Attr object is made on
/// first request and then kept (traced); while it exists, the value lives here, not in the Attr.
struct Attribute {
    HeldAtom localName;
    Namespace ns = Namespace::None;
    HeldAtom otherNamespace;
    HeldAtom prefix;
    Held value;
    Held node;
    /// The batch of this attribute's last counted change (Node::countsChange; limit.batch).
    uint64_t opBatch = 0;
    /// The batch it was added in (limit.batch: an inline style added in the current batch goes whole, as one change).
    uint64_t addedBatch = 0;
};

/// The parts of a qualified attribute name, validated (DOM "validate and extract" for an attribute).
struct AttributeName {
    Namespace ns = Namespace::None;
    Atom otherNamespace;
    Atom prefix;
    Atom localName;
};

/// DOM "validate and extract" with the attribute rules: throws InvalidCharacterError or NamespaceError.
AttributeName validateAndExtractAttributeName(JSContext* ctx, const std::optional<String>& namespaceURI, const String& qualifiedName);

class Animation;
class DOMRect;
class DOMRectList;

namespace idl {
struct GetAnimationsOptions;
struct KeyframeAnimationOptions;
} // namespace idl

class Element : public Node {
public:
    /// The atoms are borrowed; the element keeps its own references.
    Element(JSContext* ctx, Document& document, Namespace ns, JSAtom localName, JSAtom prefix, JSAtom otherNamespace);

    Namespace ns() const { return m_ns; }
    JSAtom localNameAtom() const { return m_localName.atom; }
    JSAtom prefixAtom() const { return m_prefix.atom; }
    JSAtom otherNamespaceAtom() const { return m_otherNamespace.atom; }
    bool isHTMLElement() const { return m_ns == Namespace::HTML; }
    bool hasHTMLName(JSAtom name) const { return m_ns == Namespace::HTML && m_localName.atom == name; }

    // The attribute list (https://dom.spec.whatwg.org/#concept-element-attributes). Views: an entry is valid until the
    // list next changes.
    size_t attributeCount() const { return m_attributes.size(); }
    const Attribute& attributeAt(size_t i) const { return m_attributes[i]; }
    /// The index of the attribute `localName` in namespace `ns` (`otherNamespace` for Other), or -1.
    int findByNamespace(JSContext* ctx, Namespace ns, JSAtom otherNamespace, JSAtom localName) const;
    /// DOM "get an attribute by name": the first attribute whose qualified name is `qualifiedName`, lowercased first
    /// for an HTML element in an HTML document; or -1.
    int findByQualifiedName(JSContext* ctx, const String& qualifiedName) const;
    /// The index of `attr`'s entry, or -1 when it is not one of this element's.
    int indexOfAttr(JSContext* ctx, const Attr& attr) const;
    /// The value of the null-namespace attribute `localName`, as reflection and the DOM's "get an attribute value"
    /// read it.
    std::optional<String> attributeValue(JSContext* ctx, JSAtom localName) const;
    bool hasAttributeAtom(JSContext* ctx, JSAtom localName) const { return this->findByNamespace(ctx, Namespace::None, JS_ATOM_NULL, localName) >= 0; }
    /// DOM "set an attribute value" with no namespace and no prefix.
    void setAttributeValue(JSContext* ctx, JSAtom localName, const String& value);
    /// DOM "remove an attribute by namespace and local name" with no namespace.
    void removeAttributeAtom(JSContext* ctx, JSAtom localName);
    /// The Attr of the entry at `index`, made on first request.
    Attr* attrAt(JSContext* ctx, size_t index);
    String qualifiedNameOf(JSContext* ctx, const Attribute& attribute) const;

    // The DOM's "change", "append", "remove" and "replace" an attribute: the only writers of the list. Each tells the
    // document's mutation listeners and the DOM state's attribute listeners (attributeChanged, by local name and
    // namespace) and bumps the document's version.
    void changeAttribute(JSContext* ctx, size_t index, const String& value);
    /// The atoms are borrowed. `node`, when given, is a detached Attr that becomes the entry's.
    void appendAttribute(JSContext* ctx, Namespace ns, JSAtom otherNamespace, JSAtom prefix, JSAtom localName, const String& value, Attr* node);
    /// The caller holds a Ref to the entry's Attr if it still needs it.
    void removeAttributeAt(JSContext* ctx, size_t index);
    /// Replaces the entry at `index` (same namespace and local name) with the detached `attr`, prefix included. The
    /// caller holds a Ref to the old Attr if it still needs it.
    void replaceAttributeAt(JSContext* ctx, size_t index, Attr& attr);

    // Element
    std::optional<String> namespaceURI(JSContext* ctx) { return namespaceURIOf(ctx, m_ns, m_otherNamespace.atom); }
    std::optional<String> prefix(JSContext* ctx);
    String localName(JSContext* ctx) { return String::fromAtom(ctx, m_localName.atom); }
    String tagName(JSContext* ctx);
    String nodeName(JSContext* ctx) override { return this->tagName(ctx); }
    String id(JSContext* ctx);
    void setId(JSContext* ctx, String value);
    String className(JSContext* ctx);
    void setClassName(JSContext* ctx, String value);
    DOMTokenList* classList(JSContext* ctx);
    String slot(JSContext* ctx);
    void setSlot(JSContext* ctx, String value);
    bool hasAttributes(JSContext*) { return !m_attributes.empty(); }
    NamedNodeMap* attributes(JSContext* ctx);
    std::vector<String> getAttributeNames(JSContext* ctx);
    std::optional<String> getAttribute(JSContext* ctx, String qualifiedName);
    std::optional<String> getAttributeNS(JSContext* ctx, std::optional<String> namespaceURI, String localName);
    void setAttribute(JSContext* ctx, String qualifiedName, String value);
    void setAttributeNS(JSContext* ctx, std::optional<String> namespaceURI, String qualifiedName, String value);
    void removeAttribute(JSContext* ctx, String qualifiedName);
    void removeAttributeNS(JSContext* ctx, std::optional<String> namespaceURI, String localName);
    bool toggleAttribute(JSContext* ctx, String qualifiedName, std::optional<bool> force);
    bool hasAttribute(JSContext* ctx, String qualifiedName) { return this->findByQualifiedName(ctx, qualifiedName) >= 0; }
    bool hasAttributeNS(JSContext* ctx, std::optional<String> namespaceURI, String localName);
    Attr* getAttributeNode(JSContext* ctx, String qualifiedName);
    Attr* getAttributeNodeNS(JSContext* ctx, std::optional<String> namespaceURI, String localName);
    /// Returns the replaced Attr as a Ref: this call may release the element's last reference to it.
    Ref<Attr> setAttributeNode(JSContext* ctx, Attr* attr);
    Ref<Attr> setAttributeNodeNS(JSContext* ctx, Attr* attr) { return this->setAttributeNode(ctx, attr); }
    Ref<Attr> removeAttributeNode(JSContext* ctx, Attr* attr);
    // Selectors (SelectorMembers.cpp): this element is :scope. Throw DOMError SyntaxError.
    Element* closest(JSContext* ctx, String selectors);
    bool matches(JSContext* ctx, String selectors);
    bool webkitMatchesSelector(JSContext* ctx, String selectors) { return this->matches(ctx, std::move(selectors)); }
    /// SDK v1 §2.10 (Sources/Host/Inert.cpp): a promise rejected with NotAllowedError.
    Value requestFullscreen(JSContext* ctx, std::vector<Value> arguments);
    // HTMLOrSVGOrMathMLElement (HTMLElement, SVGElement)
    DOMStringMap* dataset(JSContext* ctx);
    // CSSOM's ElementCSSInlineStyle (HTMLElement, SVGElement): the declaration block over the style attribute.
    CSSStyleDeclaration* style(JSContext* ctx);
    // DOM Parsing and Serialization (HTML) and DOM's legacy insertAdjacent* (MarkupMembers.cpp). Divergence: M1a has no
    // XML parser, so the setters and insertAdjacentHTML throw NotSupportedError where an element of an XML document
    // (`new Document()`) would have its markup parsed as XML; the getters serialize such an element as HTML. Divergence:
    // the setters and insertAdjacentHTML also throw NotSupportedError for markup longer than 1,048,576 UTF-16 units,
    // which browsers accept; it bounds the transient parse heap (MarkupMembers.cpp, Parser.cpp).
    String innerHTML(JSContext* ctx);
    void setInnerHTML(JSContext* ctx, LegacyNullToEmptyString value);
    String outerHTML(JSContext* ctx);
    void setOuterHTML(JSContext* ctx, LegacyNullToEmptyString value);
    void insertAdjacentHTML(JSContext* ctx, String position, String string);
    Element* insertAdjacentElement(JSContext* ctx, String where, Element* element);
    void insertAdjacentText(JSContext* ctx, String where, String data);

    // CSSOM View's geometry (V3 plan, Task 3; Sources/DOM/Geometry.cpp). Each one is a layout query.
    Ref<DOMRectList> getClientRects(JSContext* ctx);
    Ref<DOMRect> getBoundingClientRect(JSContext* ctx);
    /// Pointer Events' capture (Sources/Events/Taps.cpp): the element takes a press's pointer events from the next one.
    void setPointerCapture(JSContext* ctx, int32_t pointerId);
    void releasePointerCapture(JSContext* ctx, int32_t pointerId);
    bool hasPointerCapture(JSContext* ctx, int32_t pointerId);

    // Web Animations' Animatable (V5e plan, Task 3; Sources/Animation/Animatable.cpp).
    Ref<Animation> animate(JSContext* ctx, std::optional<Object> keyframes, std::variant<Unrestricted, idl::KeyframeAnimationOptions> options);
    std::vector<Ref<Animation>> getAnimations(JSContext* ctx, const idl::GetAnimationsOptions& options);
    int32_t clientTop(JSContext* ctx);
    int32_t clientLeft(JSContext* ctx);
    int32_t clientWidth(JSContext* ctx);
    int32_t clientHeight(JSContext* ctx);
    /// Nothing scrolls: the offsets read 0 and a write does nothing.
    double scrollTop(JSContext*) { return 0; }
    void setScrollTop(JSContext*, Unrestricted) {}
    double scrollLeft(JSContext*) { return 0; }
    void setScrollLeft(JSContext*, Unrestricted) {}
    int32_t scrollWidth(JSContext* ctx);
    int32_t scrollHeight(JSContext* ctx);

    Ref<Node> cloneShallow(JSContext* ctx, Document& document) override;
    bool equalsShallow(JSContext* ctx, Node& other) override;
    /// The attributes' Attr objects follow the element (DOM "adopt"). A subclass that overrides this calls it.
    void adoptedInto(JSContext* ctx, Document& document) override;
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

private:
    /// The first attribute whose qualified name is exactly `qualifiedName`, or -1.
    int findQualified(JSContext* ctx, const String& qualifiedName) const;
    /// `name` lowercased when this is an HTML element in an HTML document (the attribute-name rule of the DOM).
    String attributeNameCase(JSContext* ctx, const String& name) const;

    Namespace m_ns;
    HeldAtom m_localName;
    HeldAtom m_prefix;
    HeldAtom m_otherNamespace;
    Vector<Attribute> m_attributes;
    // The [SameObject] objects, made on first request: counted references, traced.
    Held m_classList;
    Held m_attributeMap;
    Held m_dataset;
    Held m_style;
};

} // namespace wr
