#pragma once

#include "Generated/Bindings.h"
#include "Sources/DOM/Node.h"

namespace wr {

class DocumentType : public Node {
public:
    DocumentType(JSContext* ctx, Document& document, String name, String publicId, String systemId)
        : Node(ctx, NodeType::DocumentType, &document) {
        m_name.value = name.toJS(ctx);
        m_publicId.value = publicId.toJS(ctx);
        m_systemId.value = systemId.toJS(ctx);
    }
    String nodeName(JSContext* ctx) override { return this->name(ctx); }
    String name(JSContext* ctx) { return String::adopt(ctx, JS_DupValue(ctx, m_name.value)); }
    String publicId(JSContext* ctx) { return String::adopt(ctx, JS_DupValue(ctx, m_publicId.value)); }
    String systemId(JSContext* ctx) { return String::adopt(ctx, JS_DupValue(ctx, m_systemId.value)); }
    Ref<Node> cloneShallow(JSContext* ctx, Document& document) override {
        return create<DocumentType>(ctx, idl::kDocumentType, ctx, document, this->name(ctx), this->publicId(ctx), this->systemId(ctx));
    }
    bool equalsShallow(JSContext* ctx, Node& other) override {
        auto& o = static_cast<DocumentType&>(other);
        return this->name(ctx).equals(ctx, o.name(ctx)) && this->publicId(ctx).equals(ctx, o.publicId(ctx)) && this->systemId(ctx).equals(ctx, o.systemId(ctx));
    }
    void dispose(JSRuntime* rt) override {
        m_name.clear(rt);
        m_publicId.clear(rt);
        m_systemId.clear(rt);
        Node::dispose(rt);
    }

private:
    Held m_name;
    Held m_publicId;
    Held m_systemId;
};

} // namespace wr
