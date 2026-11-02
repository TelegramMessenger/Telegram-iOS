#include "Sources/DOM/NamedNodeMap.h"

#include "Sources/DOM/DOM.h"

namespace wr {

JSValue NamedNodeMap::indexedValue(JSContext* ctx, uint32_t index) {
    return JS_DupValue(ctx, m_element->attrAt(ctx, index)->object());
}

Ref<Attr> NamedNodeMap::removeNamedItem(JSContext* ctx, String qualifiedName) {
    Attr* attr = m_element->getAttributeNode(ctx, std::move(qualifiedName));
    if (!attr) {
        throw DOMError{"NotFoundError", "No attribute has that name."};
    }
    return m_element->removeAttributeNode(ctx, attr);
}

Ref<Attr> NamedNodeMap::removeNamedItemNS(JSContext* ctx, std::optional<String> ns, String localName) {
    Attr* attr = m_element->getAttributeNodeNS(ctx, std::move(ns), std::move(localName));
    if (!attr) {
        throw DOMError{"NotFoundError", "No attribute has that name."};
    }
    return m_element->removeAttributeNode(ctx, attr);
}

} // namespace wr
