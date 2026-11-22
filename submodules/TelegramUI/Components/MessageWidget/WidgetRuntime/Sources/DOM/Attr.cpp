#include "Sources/DOM/Attr.h"

#include "Generated/Bindings.h"
#include "Sources/DOM/DOM.h"

namespace wr {

Attr::Attr(JSContext* ctx, Document& document, Namespace ns, JSAtom otherNamespace, JSAtom prefix, JSAtom localName, String value)
    : Node(ctx, NodeType::Attribute, &document), m_ns(ns) {
    m_localName.atom = JS_DupAtom(ctx, localName);
    if (prefix != JS_ATOM_NULL) {
        m_prefix.atom = JS_DupAtom(ctx, prefix);
    }
    if (otherNamespace != JS_ATOM_NULL) {
        m_otherNamespace.atom = JS_DupAtom(ctx, otherNamespace);
    }
    m_value.value = value.toJS(ctx);
}

void Attr::attachTo(JSContext* ctx, Element& element) {
    JSRuntime* rt = JS_GetRuntime(ctx);
    m_owner = &element;
    m_ownerRef.set(rt, JS_DupValue(ctx, element.object()));
    // DOM "append" and "replace an attribute": it is in its element's document.
    this->setNodeDocument(ctx, element.nodeDocument());
    // The entry holds the value now: a copy here would keep a value the element has since replaced.
    m_value.clear(rt);
}

void Attr::detach(JSRuntime* rt, JSValue value) {
    m_value.set(rt, value);
    m_owner = nullptr;
    m_ownerRef.clear(rt);
}

String Attr::currentValue(JSContext* ctx) const {
    if (m_owner) {
        int i = m_owner->indexOfAttr(ctx, *this);
        if (i >= 0) {
            return String::adopt(ctx, JS_DupValue(ctx, m_owner->attributeAt(size_t(i)).value.value));
        }
    }
    return String::adopt(ctx, JS_DupValue(ctx, m_value.value));
}

void Attr::setValue(JSContext* ctx, String value) {
    if (m_owner) {
        int i = m_owner->indexOfAttr(ctx, *this);
        if (i >= 0) {
            m_owner->changeAttribute(ctx, size_t(i), value);
            return;
        }
    }
    m_value.set(JS_GetRuntime(ctx), value.toJS(ctx));
}

std::optional<String> Attr::prefix(JSContext* ctx) {
    if (m_prefix.atom == JS_ATOM_NULL) {
        return std::nullopt;
    }
    return String::fromAtom(ctx, m_prefix.atom);
}

String Attr::name(JSContext* ctx) {
    String local = String::fromAtom(ctx, m_localName.atom);
    if (m_prefix.atom == JS_ATOM_NULL) {
        return local;
    }
    return String::fromAtom(ctx, m_prefix.atom).concat(ctx, String::fromUTF8(ctx, ":")).concat(ctx, local);
}

Ref<Node> Attr::cloneShallow(JSContext* ctx, Document& document) {
    return create<Attr>(ctx, idl::kAttr, ctx, document, m_ns, m_otherNamespace.atom, m_prefix.atom, m_localName.atom, this->currentValue(ctx));
}

bool Attr::equalsShallow(JSContext* ctx, Node& other) {
    auto& o = static_cast<Attr&>(other);
    return m_ns == o.m_ns && m_otherNamespace.atom == o.m_otherNamespace.atom && m_localName.atom == o.m_localName.atom && this->currentValue(ctx).equals(ctx, o.currentValue(ctx));
}

void Attr::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    m_ownerRef.mark(rt, mark);
    Node::trace(rt, mark);
}

void Attr::dispose(JSRuntime* rt) {
    m_localName.clear(rt);
    m_prefix.clear(rt);
    m_otherNamespace.clear(rt);
    m_value.clear(rt);
    m_owner = nullptr;
    m_ownerRef.clear(rt);
    Node::dispose(rt);
}

} // namespace wr
