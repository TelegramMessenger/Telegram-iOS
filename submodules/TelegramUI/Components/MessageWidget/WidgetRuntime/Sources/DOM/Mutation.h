// The DOM standard's tree mutation algorithms (https://dom.spec.whatwg.org/#mutation-algorithms), without live ranges,
// node iterators, slots and mutation records (M2, M1b). Every algorithm keeps the nodes it works on alive with Refs:
// releasing a parent's reference can free a child nobody else holds.
#pragma once

#include <variant>
#include <vector>

#include "Sources/DOM/Node.h"

namespace wr {

class Document;

void ensurePreInsertValidity(JSContext* ctx, Node& node, Node& parent, Node* child);
Node& preInsert(JSContext* ctx, Node& node, Node& parent, Node* child);
void insertNode(JSContext* ctx, Node& node, Node& parent, Node* child, bool suppressObservers = false);
void adoptNodeInto(JSContext* ctx, Node& node, Document& document);
void removeNode(JSContext* ctx, Node& node, bool suppressObservers = false);
Node& replaceChildNode(JSContext* ctx, Node& child, Node& node, Node& parent);
void replaceAllChildren(JSContext* ctx, Node* node, Node& parent);
Node& preRemove(JSContext* ctx, Node& child, Node& parent);
/// ParentNode/ChildNode's "convert nodes into a node".
Ref<Node> convertNodesIntoNode(JSContext* ctx, std::vector<std::variant<Node*, String>>& nodes, Document& document);
/// "clone a node" into `document`.
Ref<Node> cloneNodeInto(JSContext* ctx, Node& node, Document& document, bool subtree);
/// The concatenated data of the Text descendants, in tree order.
String descendantTextContent(JSContext* ctx, Node& node);
/// "string replace all".
void stringReplaceAll(JSContext* ctx, const String& string, Node& parent);

/// Appends `data`'s code units to `out`. Text built from many nodes (textContent, wholeText) goes into one buffer:
/// concatenating the strings would copy the whole result once per node.
void appendCodeUnits(Vector<char16_t>& out, const String& data);

/// A native DOM mutation entry outside a binding call: the boot, a native task, a test (Ruling 6). Scripts the
/// mutations insert are prepared when the outermost scope (or binding call) is left with leave(). The destructor
/// alone is the unwinding path: it runs nothing.
class MutationScope {
public:
    explicit MutationScope(JSContext* ctx) : m_frame(ctx) {}
    void leave() { m_frame.leave(); }

private:
    NativeFrame m_frame;
};

} // namespace wr
