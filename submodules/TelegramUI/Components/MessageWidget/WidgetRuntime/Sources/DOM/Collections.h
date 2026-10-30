// The DOM's collections (https://dom.spec.whatwg.org/#interface-nodelist): NodeList (child lists, static lists,
// getElementsByName) and HTMLCollection (children, getElementsByTagName/TagNameNS/ClassName). A live collection holds
// its root (a counted, traced reference) and recomputes when the root's node document's version moved since it last
// looked; HTMLCollection has no named properties in M1a (M1a plan, ruling 3: namedItem is an ordinary method).
#pragma once

#include <vector>

#include "Sources/DOM/Element.h"

namespace wr {

class Document;

class NodeList : public PlatformObject {
public:
    virtual uint32_t length(JSContext* ctx) = 0;
    virtual Node* item(JSContext* ctx, uint32_t index) = 0;
    JSValue indexedValue(JSContext* ctx, uint32_t index) {
        Node* n = this->item(ctx, index);
        return n ? JS_DupValue(ctx, n->object()) : JS_UNDEFINED;
    }
};

/// What a live collection last found. Its `Element*` views are valid exactly while the document they were found in is
/// still the root's node document at the version recorded: every change to a tree bumps its node document's version
/// (the three child-list writers, the attribute writers, character data, the mode, adopting a node into it), and an
/// unchanged tree keeps every node in it alive. The document is held, counted and traced: once the root has moved to
/// another document the old one could otherwise be freed and a new document made at its address, whose version counts
/// from its own start and can be driven by script to the recorded number.
class LiveElements {
public:
    explicit LiveElements(JSRuntime* rt) : m_elements(JSAllocator<Element*>(rt)) {}
    /// The elements, if they are still the answer for `document`; else nullptr.
    const Vector<Element*>* current(const Document& document) const;
    /// Empties the answer for a new walk. Until record(), it is current for no document: a walk the memory limit stops
    /// is redone on the next read.
    Vector<Element*>& restart();
    /// The walk is complete: the elements are the answer for `document` at its version now.
    void record(JSContext* ctx, Document& document);
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const { m_documentRef.mark(rt, mark); }
    void clear(JSRuntime* rt);

private:
    Vector<Element*> m_elements;
    const Document* m_document = nullptr;
    Held m_documentRef;
    uint64_t m_version = 0;
};

/// Node.childNodes: live, over the root's children.
class ChildNodeList : public NodeList {
public:
    ChildNodeList(JSContext* ctx, Node& root) : m_root(&root) { m_rootRef.value = JS_DupValue(ctx, root.object()); }
    uint32_t length(JSContext*) override { return uint32_t(m_root->childCount()); }
    Node* item(JSContext*, uint32_t index) override { return index < m_root->childCount() ? m_root->childAt(index) : nullptr; }
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override { m_rootRef.mark(rt, mark); }
    void dispose(JSRuntime* rt) override { m_rootRef.clear(rt); }

private:
    Node* m_root;
    Held m_rootRef;
};

/// A static list (querySelectorAll): it holds its nodes.
class StaticNodeList : public NodeList {
public:
    explicit StaticNodeList(JSContext* ctx) : m_items(JSAllocator<Held>(JS_GetRuntime(ctx))) {}
    static Ref<StaticNodeList> make(JSContext* ctx, const std::vector<Node*>& nodes);
    uint32_t length(JSContext*) override { return uint32_t(m_items.size()); }
    Node* item(JSContext*, uint32_t index) override { return index < m_items.size() ? static_cast<Node*>(payloadOfKnown(m_items[index].value)) : nullptr; }
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

private:
    Vector<Held> m_items;
};

/// Document.getElementsByName: live.
class NameNodeList : public NodeList {
public:
    NameNodeList(JSContext* ctx, Document& document, const String& name);
    uint32_t length(JSContext* ctx) override { return uint32_t(this->elements(ctx).size()); }
    Node* item(JSContext* ctx, uint32_t index) override;
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

private:
    const Vector<Element*>& elements(JSContext* ctx);
    Node* m_root;
    Held m_rootRef;
    Held m_name;
    LiveElements m_cache;
};

class HTMLCollection : public PlatformObject {
public:
    enum class Kind : uint8_t { Children, TagName, TagNameNS, ClassName };
    HTMLCollection(JSContext* ctx, Node& root, Kind kind);
    /// Filters (set once, after construction).
    void setQualifiedName(JSContext* ctx, const String& qualifiedName);
    void setNamespaceAndLocalName(JSContext* ctx, const std::optional<String>& ns, const String& localName);
    void setClassNames(JSContext* ctx, const String& classNames);

    uint32_t length(JSContext* ctx) { return uint32_t(this->elements(ctx).size()); }
    Element* item(JSContext* ctx, uint32_t index);
    Element* namedItem(JSContext* ctx, String name);
    JSValue indexedValue(JSContext* ctx, uint32_t index) {
        Element* e = this->item(ctx, index);
        return e ? JS_DupValue(ctx, e->object()) : JS_UNDEFINED;
    }
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

private:
    const Vector<Element*>& elements(JSContext* ctx);
    /// Kind::ClassName reads its class names from m_classes in place.
    bool matches(JSContext* ctx, Element& element) const;
    Node* m_root;
    Held m_rootRef;
    Kind m_kind;
    bool m_any = false;
    /// getElementsByTagName's name, and lowercased (for HTML elements in an HTML document): as atoms, which an unprefixed
    /// element's local name is compared with in O(1), and as strings, for a prefixed element's qualified name.
    HeldAtom m_qualifiedNameAtom;
    HeldAtom m_qualifiedNameLowerAtom;
    Held m_qualifiedName;
    Held m_qualifiedNameLower;
    bool m_anyNamespace = false;
    Namespace m_ns = Namespace::None;
    HeldAtom m_otherNamespace;
    bool m_anyLocalName = false;
    HeldAtom m_localName;
    Vector<Held> m_classes;
    LiveElements m_cache;
};

/// A non-owning list of class-name strings to test, read in place: a parsed selector's std::vector<String> (one class
/// per Class simple), or an HTMLCollection's Vector<Held> of string values (getElementsByClassName, possibly many).
/// Reading a class is O(1) and copies nothing, so a recompute over a large class list allocates nothing.
class ClassNameList {
public:
    ClassNameList(const std::vector<String>& strings) : m_strings(&strings) {}
    ClassNameList(const Vector<Held>& held) : m_held(&held) {}
    bool empty() const { return this->size() == 0; }
    size_t size() const { return m_strings ? m_strings->size() : m_held->size(); }
    JSStringView view(size_t i) const {
        JSValueConst value = m_strings ? (*m_strings)[i].value() : (*m_held)[i].value;
        JSStringView out{nullptr, nullptr, 0};
        JS_GetStringView(value, &out);
        return out;
    }

private:
    const std::vector<String>* m_strings = nullptr;
    const Vector<Held>* m_held = nullptr;
};

/// Whether `element`'s class attribute holds every class (ASCII case-insensitively in quirks mode). The value's tokens
/// are compared in place, and `classes` is read in place from either source (no copy).
bool elementHasClasses(JSContext* ctx, Element& element, ClassNameList classes, bool quirks);

} // namespace wr
