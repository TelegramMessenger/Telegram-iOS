#pragma once

#include "Sources/DOM/Node.h"

namespace wr {

class DocumentFragment : public Node {
public:
    DocumentFragment(JSContext* ctx, Document& document) : Node(ctx, NodeType::DocumentFragment, &document) {}
    static Ref<DocumentFragment> construct(JSContext* ctx);
    String nodeName(JSContext* ctx) override { return String::fromUTF8(ctx, "#document-fragment"); }
    Ref<Node> cloneShallow(JSContext* ctx, Document& document) override;

    /// A template's contents are hosted by the template (HTML); any other fragment has no host. "Host-including"
    /// walks go on from here to the host; every other ancestor walk stops at the fragment.
    Node* host() const { return m_host.isUndefined() ? nullptr : static_cast<Node*>(payloadOfKnown(m_host.value)); }
    void setHost(JSContext* ctx, Node& host) { m_host.set(JS_GetRuntime(ctx), JS_DupValue(ctx, host.object())); }
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override {
        m_host.mark(rt, mark);
        Node::trace(rt, mark);
    }
    void dispose(JSRuntime* rt) override {
        m_host.clear(rt);
        Node::dispose(rt);
    }

private:
    /// A counted reference, traced: the template and its contents are a cycle the collector frees.
    Held m_host;
};

} // namespace wr
