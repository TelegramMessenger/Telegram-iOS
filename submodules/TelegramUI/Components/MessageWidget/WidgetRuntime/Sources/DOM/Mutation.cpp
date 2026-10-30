#include "Sources/DOM/Mutation.h"

#include "Generated/Bindings.h"
#include "Sources/DOM/DOM.h"

namespace wr {

static bool isContainerForChildren(const Node& n) {
    return n.type() == NodeType::Document || n.type() == NodeType::DocumentFragment || n.type() == NodeType::Element;
}

// A document's element and doctype children are slots its raw child edits keep (Document::noteChildInserted).
// Pre-insertion validity allows one of each, so the rules below read the slots instead of scanning the children,
// which script can make many (comments).

static bool hasElementChild(const Document& parent, const Node* except = nullptr) {
    const Element* element = parent.documentElementNode();
    return element && element != except;
}

static bool hasDoctypeChild(const Document& parent, const Node* except = nullptr) {
    const DocumentType* doctype = parent.doctypeNode();
    return doctype && doctype != except;
}

/// Whether a doctype follows `child`, a child of `parent`.
static bool doctypeFollows(const Document& parent, const Node& child) {
    const DocumentType* doctype = parent.doctypeNode();
    return doctype && doctype->indexInParent() > child.indexInParent();
}

/// Whether an element precedes `child`, a child of `parent`.
static bool elementPrecedes(const Document& parent, const Node& child) {
    const Element* element = parent.documentElementNode();
    return element && element->indexInParent() < child.indexInParent();
}

static void fragmentCounts(JSContext* ctx, const Node& fragment, int* elements, bool* text) {
    *elements = 0;
    *text = false;
    for (size_t i = 0; i < fragment.childCount(); i++) {
        const Node* c = fragment.childAt(i);
        if (c->isElement()) {
            (*elements)++;
        } else if (c->type() == NodeType::Text) {
            *text = true;
        }
    }
}

[[noreturn]] static void hierarchyError(const char* why) {
    throw DOMError{"HierarchyRequestError", why};
}

/// Steps 1 to 5 of "ensure pre-insert validity", which "replace" shares, in the standard's order: when several fail,
/// the order decides which error the call gets.
static void checkInsertableKinds(JSContext* ctx, Node& node, Node& parent, Node* child, const char* notAChild) {
    if (!isContainerForChildren(parent)) {
        hierarchyError("The parent cannot have children.");
    }
    if (node.isHostIncludingInclusiveAncestorOf(ctx, parent)) {
        hierarchyError("The new child contains the parent.");
    }
    if (child && child->parent() != &parent) {
        throw DOMError{"NotFoundError", notAChild};
    }
    NodeType t = node.type();
    if (!(t == NodeType::DocumentFragment || t == NodeType::DocumentType || t == NodeType::Element || node.isCharacterData())) {
        hierarchyError("Nodes of this type cannot be inserted.");
    }
    if ((t == NodeType::Text && parent.type() == NodeType::Document) || (t == NodeType::DocumentType && parent.type() != NodeType::Document)) {
        hierarchyError("Nodes of this type cannot be inserted here.");
    }
}

void ensurePreInsertValidity(JSContext* ctx, Node& node, Node& parent, Node* child) {
    checkInsertableKinds(ctx, node, parent, child, "The node before which the new node is to be inserted is not a child of this node.");
    if (parent.type() != NodeType::Document) {
        return;
    }
    const auto& document = static_cast<const Document&>(parent);
    switch (node.type()) {
    case NodeType::DocumentFragment: {
        int elements;
        bool text;
        fragmentCounts(ctx, node, &elements, &text);
        if (elements > 1 || text) {
            hierarchyError("A document has one element child.");
        }
        if (elements == 1 && (hasElementChild(document) || (child && child->type() == NodeType::DocumentType) || (child && doctypeFollows(document, *child)))) {
            hierarchyError("A document has one element child.");
        }
        break;
    }
    case NodeType::Element:
        if (hasElementChild(document) || (child && child->type() == NodeType::DocumentType) || (child && doctypeFollows(document, *child))) {
            hierarchyError("A document has one element child.");
        }
        break;
    case NodeType::DocumentType:
        if (hasDoctypeChild(document) || (child && elementPrecedes(document, *child)) || (!child && hasElementChild(document))) {
            hierarchyError("A document has one doctype, before its element.");
        }
        break;
    default:
        break;
    }
}

Node& preInsert(JSContext* ctx, Node& node, Node& parent, Node* child) {
    ensurePreInsertValidity(ctx, node, parent, child);
    Node* referenceChild = child;
    if (referenceChild == &node) {
        referenceChild = node.nextSiblingNode();
    }
    insertNode(ctx, node, parent, referenceChild);
    return node;
}

/// Refs to `parent`'s children, in tree order.
static Vector<Ref<Node>> childrenOf(JSContext* ctx, Node& parent) {
    Vector<Ref<Node>> children{JSAllocator<Ref<Node>>(JS_GetRuntime(ctx))};
    children.reserve(parent.childCount());
    for (size_t i = 0; i < parent.childCount(); i++) {
        children.push_back(Ref<Node>::retain(ctx, parent.childAt(i)));
    }
    return children;
}

/// "Remove" of every child of `parent`, in tree order, with the suppress observers flag set (as both callers want):
/// `children` holds them, in order (childrenOf). One detach, Node::removeAllChildren, instead of a removal per child
/// from the front, which moved and renumbered every later sibling each time. Listeners hear what removeNode would
/// tell them for each child, in tree order, once all of them are out: a listener finds the parent already empty.
static void removeAllChildNodes(JSContext* ctx, Node& parent, Vector<Ref<Node>>& children) {
    if (children.empty()) {
        return;
    }
    Ref<Node> keepParent = Ref<Node>::retain(ctx, &parent);
    parent.removeAllChildren(ctx);
    Document& document = parent.nodeDocument();
    for (Ref<Node>& child : children) {
        document.forEachMutationListener([&](MutationListener& listener) { listener.nodeRemoved(*child, parent); });
        document.forEachMutationListener([&](MutationListener& listener) { listener.childrenChanged(parent); });
    }
}

void insertNode(JSContext* ctx, Node& node, Node& parent, Node* child, bool suppressObservers) {
    Vector<Ref<Node>> nodes{JSAllocator<Ref<Node>>(JS_GetRuntime(ctx))};
    if (node.type() == NodeType::DocumentFragment) {
        nodes = childrenOf(ctx, node);
        if (nodes.empty()) {
            return;
        }
        removeAllChildNodes(ctx, node, nodes);
    } else {
        nodes.push_back(Ref<Node>::retain(ctx, &node));
    }
    Ref<Node> keepChild = Ref<Node>::retain(ctx, child);
    Document& document = parent.nodeDocument();
    for (Ref<Node>& n : nodes) {
        adoptNodeInto(ctx, *n, document);
        size_t index = child ? child->indexInParent() : parent.childCount();
        parent.insertChildAt(ctx, index, *n);
        document.forEachMutationListener([&](MutationListener& listener) { listener.nodeInserted(*n); });
    }
    document.forEachMutationListener([&](MutationListener& listener) { listener.childrenChanged(parent); });
}

void adoptNodeInto(JSContext* ctx, Node& node, Document& document) {
    Ref<Node> keep = Ref<Node>::retain(ctx, &node);
    if (node.parent()) {
        removeNode(ctx, node);
    }
    if (&node.nodeDocument() == &document) {
        return;
    }
    for (Node* n = &node; n; n = n->nextInTreeOrder(&node)) {
        n->setNodeDocument(ctx, document);
        n->adoptedInto(ctx, document);
    }
}

void removeNode(JSContext* ctx, Node& node, bool suppressObservers) {
    Node* parent = node.parent();
    if (!parent) {
        return;
    }
    Ref<Node> keepNode = Ref<Node>::retain(ctx, &node);
    Ref<Node> keepParent = Ref<Node>::retain(ctx, parent);
    parent->removeChildAt(ctx, node.indexInParent());
    Document& document = parent->nodeDocument();
    document.forEachMutationListener([&](MutationListener& listener) { listener.nodeRemoved(node, *parent); });
    document.forEachMutationListener([&](MutationListener& listener) { listener.childrenChanged(*parent); });
}

Node& replaceChildNode(JSContext* ctx, Node& child, Node& node, Node& parent) {
    checkInsertableKinds(ctx, node, parent, &child, "The node to be replaced is not a child of this node.");
    if (parent.type() == NodeType::Document) {
        const auto& document = static_cast<const Document&>(parent);
        switch (node.type()) {
        case NodeType::DocumentFragment: {
            int elements;
            bool text;
            fragmentCounts(ctx, node, &elements, &text);
            if (elements > 1 || text || (elements == 1 && (hasElementChild(document, &child) || doctypeFollows(document, child)))) {
                hierarchyError("A document has one element child.");
            }
            break;
        }
        case NodeType::Element:
            if (hasElementChild(document, &child) || doctypeFollows(document, child)) {
                hierarchyError("A document has one element child.");
            }
            break;
        case NodeType::DocumentType:
            if (hasDoctypeChild(document, &child) || elementPrecedes(document, child)) {
                hierarchyError("A document has one doctype, before its element.");
            }
            break;
        default:
            break;
        }
    }
    Ref<Node> keepChild = Ref<Node>::retain(ctx, &child);
    Node* referenceChild = child.nextSiblingNode();
    if (referenceChild == &node) {
        referenceChild = node.nextSiblingNode();
    }
    Ref<Node> keepReference = Ref<Node>::retain(ctx, referenceChild);
    if (child.parent()) {
        removeNode(ctx, child, true);
    }
    insertNode(ctx, node, parent, referenceChild, true);
    return child;
}

void replaceAllChildren(JSContext* ctx, Node* node, Node& parent) {
    Ref<Node> keep = Ref<Node>::retain(ctx, node);
    Vector<Ref<Node>> removed = childrenOf(ctx, parent);
    // limit.batch (widget-sandbox v0.3.0): a sole Text child replaced by a new Text (textContent, innerText, replaceChildren
    // with a string) is one `data` operation upstream, whose shim gives the new node the old one's id (capture.ts
    // reuseSoleText). It counts as a change of the old node's data, whose place in the count the new node takes; the DOM
    // still swaps the nodes.
    if (node && removed.size() == 1 && node->type() == NodeType::Text && removed[0]->type() == NodeType::Text &&
        !node->announced() && !node->parent()) {
        CharacterData& old = static_cast<CharacterData&>(*removed[0]);
        old.countDataChange(ctx);
        static_cast<CharacterData&>(*node).takeTextCountOf(old);
        {
            Runtime::QuietOps quiet(Runtime::from(ctx));
            removeAllChildNodes(ctx, parent, removed);
            insertNode(ctx, *node, parent, nullptr, true);
        }
        // Its place went to the new node: put back anywhere, it is a new one.
        old.forgetTextCount();
        return;
    }
    removeAllChildNodes(ctx, parent, removed);
    if (node) {
        insertNode(ctx, *node, parent, nullptr, true);
    }
}

Node& preRemove(JSContext* ctx, Node& child, Node& parent) {
    if (child.parent() != &parent) {
        throw DOMError{"NotFoundError", "The node to be removed is not a child of this node."};
    }
    removeNode(ctx, child);
    return child;
}

Ref<Node> convertNodesIntoNode(JSContext* ctx, std::vector<std::variant<Node*, String>>& nodes, Document& document) {
    Vector<Ref<Node>> converted{JSAllocator<Ref<Node>>(JS_GetRuntime(ctx))};
    converted.reserve(nodes.size());
    for (auto& item : nodes) {
        if (Node** node = std::get_if<Node*>(&item)) {
            converted.push_back(Ref<Node>::retain(ctx, *node));
        } else {
            converted.push_back(Ref<Node>(document.createTextNode(ctx, std::get<String>(item))));
        }
    }
    if (converted.size() == 1) {
        return converted[0];
    }
    Ref<Node> fragment(document.createDocumentFragment(ctx));
    for (Ref<Node>& n : converted) {
        preInsert(ctx, *n, *fragment, nullptr);
    }
    return fragment;
}

/// Copies `root`'s descendants into `rootCopy`, a copy of `root` without children, in `childDocument`: in tree order,
/// without recursion (a tree is as deep as memory allows, the native stack is not). `to` is the copy of `from`, and
/// since the copy mirrors the source, climbing one climbs the other.
static void cloneDescendants(JSContext* ctx, Node& root, Node& rootCopy, Document& childDocument, CloneQueue& pending) {
    Node* from = &root;
    Node* to = &rootCopy;
    for (;;) {
        Node* next = from->firstChildNode();
        if (!next) {
            while (from != &root && !from->nextSiblingNode()) {
                from = from->parent();
                to = to->parent();
            }
            if (from == &root) {
                break;
            }
            next = from->nextSiblingNode();
            to = to->parent();
        }
        // `to` is now the copy of next's parent.
        Ref<Node> child = next->cloneShallow(ctx, childDocument);
        next->cloneSteps(ctx, *child, true, pending);
        to->insertChildAt(ctx, to->childCount(), *child);
        from = next;
        to = child.get(); // held by its parent's child list
    }
}

Ref<Node> cloneNodeInto(JSContext* ctx, Node& node, Document& document, bool subtree) {
    Ref<Node> copy = node.cloneShallow(ctx, document);
    CloneQueue pending{JSAllocator<CloneQueue::value_type>(JS_GetRuntime(ctx))};
    node.cloneSteps(ctx, *copy, subtree, pending);
    if (!subtree) {
        return copy;
    }
    // A document's clone is its children's document.
    Document& childDocument = copy->type() == NodeType::Document ? static_cast<Document&>(*copy) : document;
    cloneDescendants(ctx, node, *copy, childDocument, pending);
    // The child lists cloning steps queued (template contents), each into its copy's node document (the copy's
    // template contents owner). Copying one can queue more: this loop, not the native stack, takes the nesting.
    while (!pending.empty()) {
        CloneQueue::value_type list = std::move(pending.back());
        pending.pop_back();
        cloneDescendants(ctx, *list.first, *list.second, list.second->nodeDocument(), pending);
    }
    return copy;
}

void appendCodeUnits(Vector<char16_t>& out, const String& data) {
    JSStringView v = data.view();
    if (v.latin1) {
        out.insert(out.end(), v.latin1, v.latin1 + v.length);
    } else if (v.utf16) {
        out.insert(out.end(), v.utf16, v.utf16 + v.length);
    }
}

String descendantTextContent(JSContext* ctx, Node& node) {
    Vector<char16_t> out{JSAllocator<char16_t>(JS_GetRuntime(ctx))};
    for (Node* n = node.nextInTreeOrder(&node); n; n = n->nextInTreeOrder(&node)) {
        if (n->type() == NodeType::Text) {
            appendCodeUnits(out, static_cast<CharacterData*>(n)->dataString(ctx));
        }
    }
    return String::fromUTF16(ctx, out.data(), out.size());
}

void stringReplaceAll(JSContext* ctx, const String& string, Node& parent) {
    Ref<Node> node;
    if (!string.empty()) {
        node = Ref<Node>(parent.nodeDocument().createTextNode(ctx, string));
    }
    replaceAllChildren(ctx, node.get(), parent);
}

} // namespace wr
