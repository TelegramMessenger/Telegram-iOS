#include "Sources/DOM/CharacterData.h"

#include <algorithm>

#include "Generated/Bindings.h"
#include "Sources/DOM/DOM.h"

namespace wr {

CharacterData::CharacterData(JSContext* ctx, NodeType type, Document& document, String data) : Node(ctx, type, &document) {
    m_data.value = data.toJS(ctx);
}

String CharacterData::dataString(JSContext* ctx) const {
    return String::adopt(ctx, JS_DupValue(ctx, m_data.value));
}

void CharacterData::setDataString(JSContext* ctx, String data) {
    this->countDataChange(ctx);
    m_data.set(JS_GetRuntime(ctx), data.toJS(ctx));
    Document& document = this->nodeDocument();
    document.noteMutation();
    document.forEachMutationListener([&](MutationListener& listener) { listener.characterDataChanged(*this); });
}

void CharacterData::countDataChange(JSContext* ctx) {
    // limit.batch (widget-sandbox v0.3.0): one operation per batch once the node was inserted in an earlier one
    // (Node::countsChange), counted before the change.
    Runtime& runtime = Runtime::from(ctx);
    if (this->countsChange(runtime.batchSerial(), m_dataOpBatch)) {
        runtime.addOps(1);
    }
}

String CharacterData::substringData(JSContext* ctx, uint32_t offset, uint32_t count) {
    uint32_t length = this->length(ctx);
    if (offset > length) {
        throw DOMError{"IndexSizeError", "The offset is greater than the data's length."};
    }
    uint64_t end = std::min<uint64_t>(uint64_t(offset) + count, length);
    return this->dataString(ctx).substring(ctx, offset, uint32_t(end));
}

void CharacterData::replaceData(JSContext* ctx, uint32_t offset, uint32_t count, String data) {
    uint32_t length = this->length(ctx);
    if (offset > length) {
        throw DOMError{"IndexSizeError", "The offset is greater than the data's length."};
    }
    if (uint64_t(offset) + count > length) {
        count = length - offset;
    }
    String current = this->dataString(ctx);
    String result = current.substring(ctx, 0, offset).concat(ctx, data).concat(ctx, current.substring(ctx, offset + count, length));
    this->setDataString(ctx, result);
}

Ref<Text> Text::splitText(JSContext* ctx, uint32_t offset) {
    uint32_t length = this->length(ctx);
    if (offset > length) {
        throw DOMError{"IndexSizeError", "The offset is greater than the data's length."};
    }
    String newData = this->dataString(ctx).substring(ctx, offset, length);
    Ref<Text> newNode = make(ctx, this->nodeDocument(), newData);
    if (Node* parent = this->parent()) {
        insertNode(ctx, *newNode, *parent, this->nextSiblingNode());
    }
    this->replaceData(ctx, offset, length - offset, String());
    return newNode;
}

String Text::wholeText(JSContext* ctx) {
    Node* first = this;
    while (first->previousSiblingNode() && first->previousSiblingNode()->type() == NodeType::Text) {
        first = first->previousSiblingNode();
    }
    Vector<char16_t> out{JSAllocator<char16_t>(JS_GetRuntime(ctx))};
    for (Node* n = first; n && n->type() == NodeType::Text; n = n->nextSiblingNode()) {
        appendCodeUnits(out, static_cast<Text*>(n)->dataString(ctx));
    }
    return String::fromUTF16(ctx, out.data(), out.size());
}

Ref<Text> Text::make(JSContext* ctx, Document& document, String data) {
    return create<Text>(ctx, idl::kText, ctx, document, std::move(data));
}

Ref<Text> Text::construct(JSContext* ctx, String data) {
    return make(ctx, globalDocument(ctx), std::move(data));
}

Ref<Comment> Comment::make(JSContext* ctx, Document& document, String data) {
    return create<Comment>(ctx, idl::kComment, ctx, document, std::move(data));
}

Ref<Comment> Comment::construct(JSContext* ctx, String data) {
    return make(ctx, globalDocument(ctx), std::move(data));
}

Document& globalDocument(JSContext* ctx) {
    // From the DOM state, not globalThis.document: no script-visible read inside a constructor (M1a carry-over).
    return DOMState::of(ctx).document();
}

} // namespace wr
