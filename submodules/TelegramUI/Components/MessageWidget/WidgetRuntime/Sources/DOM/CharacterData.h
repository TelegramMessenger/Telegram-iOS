#pragma once

#include "Sources/DOM/Node.h"

namespace wr {

class CharacterData : public Node {
public:
    CharacterData(JSContext* ctx, NodeType type, Document& document, String data);
    /// The data; the default String when empty.
    String dataString(JSContext* ctx) const;
    /// Replaces the data (DOM "replace data" for the whole range, without the range bookkeeping).
    void setDataString(JSContext* ctx, String data);

    String data(JSContext* ctx) { return this->dataString(ctx); }
    void setData(JSContext* ctx, LegacyNullToEmptyString value) { this->setDataString(ctx, std::move(value)); }
    uint32_t length(JSContext*) { return JS_GetStringLength(m_data.value); }
    String substringData(JSContext* ctx, uint32_t offset, uint32_t count);
    void appendData(JSContext* ctx, String data) { this->replaceData(ctx, this->length(ctx), 0, std::move(data)); }
    void insertData(JSContext* ctx, uint32_t offset, String data) { this->replaceData(ctx, offset, 0, std::move(data)); }
    void deleteData(JSContext* ctx, uint32_t offset, uint32_t count) { this->replaceData(ctx, offset, count, String()); }
    void replaceData(JSContext* ctx, uint32_t offset, uint32_t count, String data);

    bool equalsShallow(JSContext* ctx, Node& other) override {
        return this->dataString(ctx).equals(ctx, static_cast<CharacterData&>(other).dataString(ctx));
    }
    void dispose(JSRuntime* rt) override {
        m_data.clear(rt);
        Node::dispose(rt);
    }

private:
    Held m_data;
};

class Text : public CharacterData {
public:
    Text(JSContext* ctx, Document& document, String data) : CharacterData(ctx, NodeType::Text, document, std::move(data)) {}
    static Ref<Text> make(JSContext* ctx, Document& document, String data);
    static Ref<Text> construct(JSContext* ctx, String data);
    String nodeName(JSContext* ctx) override { return String::fromUTF8(ctx, "#text"); }
    Ref<Text> splitText(JSContext* ctx, uint32_t offset);
    String wholeText(JSContext* ctx);
    Ref<Node> cloneShallow(JSContext* ctx, Document& document) override { return make(ctx, document, this->dataString(ctx)); }
};

class Comment : public CharacterData {
public:
    Comment(JSContext* ctx, Document& document, String data) : CharacterData(ctx, NodeType::Comment, document, std::move(data)) {}
    static Ref<Comment> make(JSContext* ctx, Document& document, String data);
    static Ref<Comment> construct(JSContext* ctx, String data);
    String nodeName(JSContext* ctx) override { return String::fromUTF8(ctx, "#comment"); }
    Ref<Node> cloneShallow(JSContext* ctx, Document& document) override { return make(ctx, document, this->dataString(ctx)); }
};

/// The main document (DOMState::document): the node document constructors give a new node.
Document& globalDocument(JSContext* ctx);

} // namespace wr
