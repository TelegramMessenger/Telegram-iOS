#pragma once

#include "Sources/DOM/Element.h"

namespace wr {

/// An element's attribute list as Attr nodes (DOM's NamedNodeMap, `element.attributes`). It holds its element alive:
/// a counted, traced reference, as the element holds it.
class NamedNodeMap : public PlatformObject {
public:
    NamedNodeMap(JSContext* ctx, Element& element) : m_element(&element) { m_elementRef.value = JS_DupValue(ctx, element.object()); }
    uint32_t length(JSContext*) { return uint32_t(m_element->attributeCount()); }
    Attr* item(JSContext* ctx, uint32_t index) { return index < m_element->attributeCount() ? m_element->attrAt(ctx, index) : nullptr; }
    /// For IndexedExotic: `index` is below length().
    JSValue indexedValue(JSContext* ctx, uint32_t index);
    Attr* getNamedItem(JSContext* ctx, String qualifiedName) { return m_element->getAttributeNode(ctx, std::move(qualifiedName)); }
    Attr* getNamedItemNS(JSContext* ctx, std::optional<String> ns, String localName) { return m_element->getAttributeNodeNS(ctx, std::move(ns), std::move(localName)); }
    Ref<Attr> setNamedItem(JSContext* ctx, Attr* attr) { return m_element->setAttributeNode(ctx, attr); }
    Ref<Attr> setNamedItemNS(JSContext* ctx, Attr* attr) { return m_element->setAttributeNode(ctx, attr); }
    Ref<Attr> removeNamedItem(JSContext* ctx, String qualifiedName);
    Ref<Attr> removeNamedItemNS(JSContext* ctx, std::optional<String> ns, String localName);
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override { m_elementRef.mark(rt, mark); }
    void dispose(JSRuntime* rt) override { m_elementRef.clear(rt); }

private:
    Element* m_element;
    Held m_elementRef;
};

} // namespace wr
