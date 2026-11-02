// Every node is a QuickJS object; this is its payload. Links between nodes are counted references reported by trace():
// QuickJS's collector owns DOM memory (spec section 4, M1a plan "Global Constraints").
#pragma once

#include <optional>
#include <utility>
#include <variant>
#include <vector>

#include "Sources/Support/Allocator.h"
#include "Sources/Support/Bindings.h"
#include "Sources/Events/EventTarget.h"

namespace wr {

class Document;
class Element;
class HTMLCollection;
class Node;
class NodeList;
namespace idl {
struct GetRootNodeOptions;
}

/// The child lists a deep clone has still to copy, as (source parent, its copy) pairs: a template's contents.
/// cloneNodeInto copies them in its own loop, so a clone never recurses, however deep script nests templates.
using CloneQueue = Vector<std::pair<Ref<Node>, Ref<Node>>>;

enum class NodeType : uint16_t {
    Element = 1,
    Attribute = 2,
    Text = 3,
    CDATASection = 4,
    ProcessingInstruction = 7,
    Comment = 8,
    Document = 9,
    DocumentType = 10,
    DocumentFragment = 11,
};

class Node : public EventTarget {
public:
    /// `document` is the node document; nullptr only for a Document (its own).
    Node(JSContext* ctx, NodeType type, Document* document);

    NodeType type() const { return m_type; }
    bool isElement() const { return m_type == NodeType::Element; }
    bool isCharacterData() const {
        return m_type == NodeType::Text || m_type == NodeType::Comment || m_type == NodeType::CDATASection || m_type == NodeType::ProcessingInstruction;
    }

    // Views: valid while this node is alive and the tree is unchanged.
    Node* parent() const { return m_parent; }
    size_t childCount() const { return m_children.size(); }
    Node* childAt(size_t index) const { return static_cast<Node*>(payloadOfKnown(m_children[index])); }
    Node* firstChildNode() const { return m_children.empty() ? nullptr : this->childAt(0); }
    Node* lastChildNode() const { return m_children.empty() ? nullptr : this->childAt(m_children.size() - 1); }
    Node* previousSiblingNode() const { return m_parent && m_index > 0 ? m_parent->childAt(m_index - 1) : nullptr; }
    Node* nextSiblingNode() const { return m_parent && m_index + 1 < m_parent->childCount() ? m_parent->childAt(m_index + 1) : nullptr; }
    size_t indexInParent() const { return m_index; }
    Document& nodeDocument() const;
    Node& rootNode(JSContext* ctx) const;
    bool connected(JSContext* ctx) const;
    /// A node without children is an inclusive ancestor of itself only, so inserting a new leaf walks nothing.
    bool isInclusiveAncestorOf(JSContext* ctx, const Node& other) const;
    /// DOM "host-including inclusive ancestor": the same walk, going on from a fragment with a host (a template's
    /// contents) to the host. A leaf that hosts no contents walks nothing.
    bool isHostIncludingInclusiveAncestorOf(JSContext* ctx, const Node& other) const;
    /// Whether this node hosts a fragment (a template whose contents exist).
    virtual bool hostsContents() const { return false; }
    Element* parentElementNode() const;
    /// The node after this one in tree order, not leaving `stayWithin`'s subtree (nullptr at its end).
    Node* nextInTreeOrder(const Node* stayWithin) const;
    /// The node after this one's subtree in tree order, within `stayWithin`.
    Node* nextSkippingChildren(const Node* stayWithin) const;

    // Raw edits, no checks (the DOM's algorithms in Mutation.cpp call these). These three are the only writers of a
    // child list, which is what keeps Document's element and doctype slots right, and each bumps the node document's
    // version itself, so no caller can edit a tree a live collection then misses (Collections.h). Each counts its
    // operations (Runtime::addOps) before it edits, so a widget the ops cap stops there is left with no half-made edit
    // and none its listeners were not told of.
    /// Inserts `child`, which has no parent, at `index`.
    void insertChildAt(JSContext* ctx, size_t index, Node& child);
    /// Whether this node was ever inserted (m_announcedBatch): upstream's shim would have sent it.
    bool announced() const { return m_announcedBatch != 0; }
    /// Whether a change to something of this node's that `stamp` stamps (an attribute's entry, a text's data) is an
    /// operation of batch `batch`, which it then stamps: once per batch each, as a flush's difference names a change
    /// once, and never in the batch of the node's first insertion, whose state travels whole with it (or before it).
    bool countsChange(uint64_t batch, uint64_t& stamp) const {
        if (m_announcedBatch == 0 || m_announcedBatch == batch || stamp == batch) {
            return false;
        }
        stamp = batch;
        return true;
    }
    /// Takes `other`'s place in the count (replaceAllChildren's sole text: upstream's new node takes the old one's id).
    void takeCountOf(const Node& other) { m_announcedBatch = other.m_announcedBatch; }
    /// Counts as never inserted (the sole text another took the place of: upstream deletes its id, so inserting it again
    /// makes it a new node).
    void forgetCount() {
        m_announcedBatch = 0;
        m_removedBatch = 0;
    }
    /// Removes the child at `index`. The caller holds a Ref to it if it still needs it.
    void removeChildAt(JSContext* ctx, size_t index);
    /// Removes every child, in tree order, as removeChildAt(0) would one by one, in time linear in their number: the
    /// later siblings are neither moved nor renumbered for each removal. The caller holds Refs to the children it still
    /// needs (to tell listeners).
    void removeAllChildren(JSContext* ctx);
    /// Sets this node's node document (not its descendants'), bumping that document's version when it changes.
    void setNodeDocument(JSContext* ctx, Document& document);

    // Node
    uint16_t nodeType(JSContext*) { return uint16_t(m_type); }
    virtual String nodeName(JSContext* ctx) = 0;
    USVString baseURI(JSContext* ctx);
    bool isConnected(JSContext* ctx) { return this->connected(ctx); }
    Document* ownerDocument(JSContext*);
    Node* getRootNode(JSContext* ctx, const idl::GetRootNodeOptions&) { return &this->rootNode(ctx); }
    Node* parentNode(JSContext*) { return m_parent; }
    Element* parentElement(JSContext*) { return this->parentElementNode(); }
    bool hasChildNodes(JSContext*) { return !m_children.empty(); }
    NodeList* childNodes(JSContext* ctx);
    Node* firstChild(JSContext*) { return this->firstChildNode(); }
    Node* lastChild(JSContext*) { return this->lastChildNode(); }
    Node* previousSibling(JSContext*) { return this->previousSiblingNode(); }
    Node* nextSibling(JSContext*) { return this->nextSiblingNode(); }
    bool isSameNode(JSContext*, OrNull<Node> other) { return other.ptr == this; }
    std::optional<String> nodeValue(JSContext* ctx);
    void setNodeValue(JSContext* ctx, std::optional<String> value);
    std::optional<String> textContent(JSContext* ctx);
    void setTextContent(JSContext* ctx, std::optional<String> value);
    void normalize(JSContext* ctx);
    Ref<Node> cloneNode(JSContext* ctx, bool subtree);
    bool isEqualNode(JSContext* ctx, OrNull<Node> other);
    uint16_t compareDocumentPosition(JSContext* ctx, Node* other);
    bool contains(JSContext* ctx, OrNull<Node> other) { return other.ptr && this->isInclusiveAncestorOf(ctx, *other.ptr); }
    Node* insertBefore(JSContext* ctx, Node* node, OrNull<Node> child);
    Node* appendChild(JSContext* ctx, Node* node);
    Node* replaceChild(JSContext* ctx, Node* node, Node* child);
    Node* removeChild(JSContext* ctx, Node* child);

    // ParentNode (Document, DocumentFragment, Element)
    HTMLCollection* children(JSContext* ctx);
    Element* firstElementChild(JSContext* ctx);
    Element* lastElementChild(JSContext* ctx);
    uint32_t childElementCount(JSContext* ctx);
    void prepend(JSContext* ctx, std::vector<std::variant<Node*, String>> nodes);
    void append(JSContext* ctx, std::vector<std::variant<Node*, String>> nodes);
    void replaceChildren(JSContext* ctx, std::vector<std::variant<Node*, String>> nodes);
    /// The first or every descendant, in tree order, that matches the selectors with this node as :scope
    /// (SelectorMembers.cpp). Throws DOMError SyntaxError.
    Element* querySelector(JSContext* ctx, String selectors);
    Ref<NodeList> querySelectorAll(JSContext* ctx, String selectors);
    // NonElementParentNode (Document, DocumentFragment)
    Element* getElementById(JSContext* ctx, String elementId);
    // Document and Element
    Ref<HTMLCollection> getElementsByTagName(JSContext* ctx, String qualifiedName);
    Ref<HTMLCollection> getElementsByTagNameNS(JSContext* ctx, std::optional<String> ns, String localName);
    Ref<HTMLCollection> getElementsByClassName(JSContext* ctx, String classNames);
    // NonDocumentTypeChildNode (Element, CharacterData)
    Element* previousElementSibling(JSContext* ctx);
    Element* nextElementSibling(JSContext* ctx);
    // ChildNode (DocumentType, Element, CharacterData)
    void before(JSContext* ctx, std::vector<std::variant<Node*, String>> nodes);
    void after(JSContext* ctx, std::vector<std::variant<Node*, String>> nodes);
    void replaceWith(JSContext* ctx, std::vector<std::variant<Node*, String>> nodes);
    void remove(JSContext* ctx);

    // Extension points for subclasses.
    /// A copy of this node without children, in `document` (DOM "clone a node", steps for the node itself).
    virtual Ref<Node> cloneShallow(JSContext* ctx, Document& document) = 0;
    /// The cloning steps other specifications define (HTML), run on `copy` right after cloneShallow made it, for the
    /// node a clone starts at and for every descendant it copies. Steps that copy a second child list (a template's
    /// contents) add it to `pending` rather than clone it themselves.
    virtual void cloneSteps(JSContext* ctx, Node& copy, bool subtree, CloneQueue& pending) {}
    /// The node-specific part of "equals" (children are compared by isEqualNode).
    virtual bool equalsShallow(JSContext* ctx, Node& other) { return true; }
    /// After this node moved to `document` (attribute nodes follow their element: Task 11).
    virtual void adoptedInto(JSContext* ctx, Document& document) {}
    /// DOM "default passive value": touch and wheel listeners on a document, its document element or its body.
    bool defaultPassive(JSContext* ctx, JSAtom type) override;
    /// DOM: a node's parent is the next target in an event path (no slots in the profile).
    EventTarget* getTheParent(JSContext*, Event&) override { return m_parent; }

    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

private:
    NodeType m_type;
    Node* m_parent = nullptr;
    Held m_parentRef;
    Document* m_document = nullptr;
    Held m_documentRef;
    Vector<JSValue> m_children;
    size_t m_index = 0;
    /// The batch (Runtime::batchSerial) of this node's first insertion, 0 before it: upstream's shim would have sent the
    /// node then (Runtime::addOps). That insertion counts its making too; its attribute and text changes count from the
    /// next batch on (countsChange).
    uint64_t m_announcedBatch = 0;
    /// The batch this node last left the document in: an insertion in the same batch is a move, one `ins` upstream, which
    /// the removal counted.
    uint64_t m_removedBatch = 0;
    // The [SameObject] lists, made on first request: counted references, traced. (`m_children` is the child list.)
    Held m_childNodes;
    Held m_childElements;
};

/// The Node payload of a value known to be a node of this runtime, or nullptr.
Node* nodeOf(JSContext* ctx, JSValueConst v);

} // namespace wr
