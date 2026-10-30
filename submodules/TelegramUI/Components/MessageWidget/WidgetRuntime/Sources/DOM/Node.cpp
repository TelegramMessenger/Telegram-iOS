#include "Sources/DOM/Node.h"

#include <algorithm>
#include <functional>

#include "Generated/Bindings.h"
#include "Sources/DOM/DOM.h"

namespace wr {

Node::Node(JSContext* ctx, NodeType type, Document* document)
    : m_type(type), m_children(JSAllocator<JSValue>(JS_GetRuntime(ctx))) {
    if (document) {
        m_document = document;
        m_documentRef.value = JS_DupValue(ctx, document->object());
    }
}

Document& Node::nodeDocument() const {
    return m_document ? *m_document : static_cast<Document&>(const_cast<Node&>(*this));
}

Node& Node::rootNode(JSContext* ctx) const {
    const Node* n = this;
    while (n->m_parent) {
        n = n->m_parent;
    }
    return const_cast<Node&>(*n);
}

bool Node::connected(JSContext* ctx) const {
    return this->rootNode(ctx).type() == NodeType::Document;
}

bool Node::isInclusiveAncestorOf(JSContext* ctx, const Node& other) const {
    if (m_children.empty()) {
        return this == &other;
    }
    for (const Node* n = &other; n; n = n->m_parent) {
        if (n == this) {
            return true;
        }
    }
    return false;
}

bool Node::isHostIncludingInclusiveAncestorOf(JSContext* ctx, const Node& other) const {
    // Without children and hosting no contents, this node has no host-including descendants.
    if (m_children.empty() && !this->hostsContents()) {
        return this == &other;
    }
    const Node* n = &other;
    while (n) {
        if (n == this) {
            return true;
        }
        if (n->m_parent) {
            n = n->m_parent;
        } else if (n->m_type == NodeType::DocumentFragment) {
            n = static_cast<const DocumentFragment*>(n)->host();
        } else {
            n = nullptr;
        }
    }
    return false;
}

Element* Node::parentElementNode() const {
    return m_parent && m_parent->isElement() ? static_cast<Element*>(m_parent) : nullptr;
}

Node* Node::nextInTreeOrder(const Node* stayWithin) const {
    if (!m_children.empty()) {
        return this->childAt(0);
    }
    return this->nextSkippingChildren(stayWithin);
}

Node* Node::nextSkippingChildren(const Node* stayWithin) const {
    for (const Node* n = this; n && n != stayWithin; n = n->m_parent) {
        if (Node* next = n->nextSiblingNode()) {
            return next;
        }
    }
    return nullptr;
}

void Node::insertChildAt(JSContext* ctx, size_t index, Node& child) {
    JSRuntime* rt = JS_GetRuntime(ctx);
    // limit.batch (widget-sandbox v0.3.0): an insertion is one operation, a node's first two (it is made and inserted),
    // and none more for a node whose two this batch paid (put in a fragment first) or that left the document in this
    // batch (a move: its removal counted upstream's one `ins`); counted before anything changes, as a stop past the cap
    // throws here. The removal's stamp stays: a stale one never equals a later batch.
    Runtime& runtime = Runtime::from(ctx);
    const uint64_t batch = runtime.batchSerial();
    runtime.addOps(child.m_announcedBatch == 0 ? 2 : child.m_announcedBatch == batch || child.m_removedBatch == batch ? 0 : 1);
    if (child.m_announcedBatch == 0) {
        child.m_announcedBatch = batch;
    }
    // The insert can fail at the memory limit (JSAllocator throws bad_alloc): the reference is taken once it is in.
    m_children.insert(m_children.begin() + ptrdiff_t(index), child.object());
    JS_DupValue(ctx, child.object());
    child.m_parent = this;
    child.m_parentRef.set(rt, JS_DupValue(ctx, this->object()));
    for (size_t i = index; i < m_children.size(); i++) {
        this->childAt(i)->m_index = i;
    }
    if (m_type == NodeType::Document) {
        static_cast<Document*>(this)->noteChildInserted(child);
    }
    this->nodeDocument().noteMutation();
}

void Node::removeChildAt(JSContext* ctx, size_t index) {
    JSRuntime* rt = JS_GetRuntime(ctx);
    // limit.batch: a removal from the document is one operation, and an insertion in the same batch is then a move; from
    // a tree outside it (a fragment, a detached element) none, as upstream's shim never sees such trees.
    Runtime& runtime = Runtime::from(ctx);
    const bool fromDocument = this->connected(ctx);
    runtime.addOps(fromDocument ? 1 : 0);
    Node* child = this->childAt(index);
    if (fromDocument) {
        child->m_removedBatch = runtime.batchSerial();
    }
    JSValue childValue = m_children[index];
    m_children.erase(m_children.begin() + ptrdiff_t(index));
    for (size_t i = index; i < m_children.size(); i++) {
        this->childAt(i)->m_index = i;
    }
    if (m_type == NodeType::Document) {
        static_cast<Document*>(this)->noteChildRemoved(*child);
    }
    this->nodeDocument().noteMutation();
    child->m_parent = nullptr;
    child->m_index = 0;
    child->m_parentRef.clear(rt);
    JS_FreeValueRT(rt, childValue);
}

void Node::removeAllChildren(JSContext* ctx) {
    JSRuntime* rt = JS_GetRuntime(ctx);
    Runtime& runtime = Runtime::from(ctx);
    const bool fromDocument = !m_children.empty() && this->connected(ctx);
    runtime.addOps(fromDocument ? m_children.size() : 0);
    for (size_t i = 0; fromDocument && i < m_children.size(); i++) {
        this->childAt(i)->m_removedBatch = runtime.batchSerial();
    }
    // The children's references to this node may be all that holds it: keep it alive until the end.
    JSValue self = JS_DupValue(ctx, this->object());
    // Each child's own fields first, in tree order, as removeChildAt does them. Nothing else runs meanwhile: nothing is
    // allocated, and the only references released are to this node, which `self` holds. So for this loop alone the
    // list may hold children that are already detached.
    for (size_t i = 0; i < m_children.size(); i++) {
        Node* child = this->childAt(i);
        if (m_type == NodeType::Document) {
            static_cast<Document*>(this)->noteChildRemoved(*child);
        }
        child->m_parent = nullptr;
        child->m_index = 0;
        child->m_parentRef.clear(rt);
    }
    // The list, emptied once; then the children's references, released in tree order. A finalizer those releases run
    // sees this node without children.
    Vector<JSValue> released(std::move(m_children));
    m_children.clear();
    this->nodeDocument().noteMutation();
    for (JSValue child : released) {
        JS_FreeValueRT(rt, child);
    }
    JS_FreeValueRT(rt, self);
}

void Node::setNodeDocument(JSContext* ctx, Document& document) {
    if (m_type == NodeType::Document || m_document == &document) {
        return;
    }
    m_document = &document;
    m_documentRef.set(JS_GetRuntime(ctx), JS_DupValue(ctx, document.object()));
    // A tree moving in changes the document: a collection whose root went to another document, changed there and came
    // back must not find the version it recorded (Collections.h, LiveElements).
    document.noteMutation();
}

USVString Node::baseURI(JSContext* ctx) {
    return this->nodeDocument().URL(ctx);
}

Document* Node::ownerDocument(JSContext*) {
    return m_type == NodeType::Document ? nullptr : m_document;
}

void Node::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    m_parentRef.mark(rt, mark);
    m_documentRef.mark(rt, mark);
    for (JSValue child : m_children) {
        JS_MarkValue(rt, child, mark);
    }
    m_childNodes.mark(rt, mark);
    m_childElements.mark(rt, mark);
    EventTarget::trace(rt, mark);
}

void Node::dispose(JSRuntime* rt) {
    m_parentRef.clear(rt);
    m_documentRef.clear(rt);
    for (JSValue child : m_children) {
        JS_FreeValueRT(rt, child);
    }
    m_children.clear();
    m_childNodes.clear(rt);
    m_childElements.clear(rt);
    EventTarget::dispose(rt);
}

bool Node::defaultPassive(JSContext* ctx, JSAtom type) {
    DOMState& state = DOMState::of(ctx);
    if (type != state.name(Name::touchstart) && type != state.name(Name::touchmove) && type != state.name(Name::wheel) &&
        type != state.name(Name::mousewheel)) {
        return false;
    }
    if (m_type == NodeType::Document) {
        return true;
    }
    Document& document = this->nodeDocument();
    return this == document.documentElementNode() || this == static_cast<Node*>(document.body(ctx));
}

NodeList* Node::childNodes(JSContext* ctx) {
    if (m_childNodes.isUndefined()) {
        m_childNodes.value = create<ChildNodeList>(ctx, idl::kNodeList, ctx, *this).release();
    }
    return static_cast<NodeList*>(payloadOfKnown(m_childNodes.value));
}

HTMLCollection* Node::children(JSContext* ctx) {
    if (m_childElements.isUndefined()) {
        m_childElements.value = create<HTMLCollection>(ctx, idl::kHTMLCollection, ctx, *this, HTMLCollection::Kind::Children).release();
    }
    return static_cast<HTMLCollection*>(payloadOfKnown(m_childElements.value));
}

Element* Node::getElementById(JSContext* ctx, String elementId) {
    // An element whose id attribute is empty has no ID (DOM, "unset element's ID"), so '' finds nothing.
    if (elementId.empty()) {
        return nullptr;
    }
    JSAtom id = DOMState::of(ctx).name(Name::id);
    for (Node* n = this->nextInTreeOrder(this); n; n = n->nextInTreeOrder(this)) {
        if (n->isElement()) {
            std::optional<String> value = static_cast<Element*>(n)->attributeValue(ctx, id);
            if (value && value->equals(ctx, elementId)) {
                return static_cast<Element*>(n);
            }
        }
    }
    return nullptr;
}

Ref<HTMLCollection> Node::getElementsByTagName(JSContext* ctx, String qualifiedName) {
    Ref<HTMLCollection> c = create<HTMLCollection>(ctx, idl::kHTMLCollection, ctx, *this, HTMLCollection::Kind::TagName);
    c->setQualifiedName(ctx, qualifiedName);
    return c;
}

Ref<HTMLCollection> Node::getElementsByTagNameNS(JSContext* ctx, std::optional<String> ns, String localName) {
    Ref<HTMLCollection> c = create<HTMLCollection>(ctx, idl::kHTMLCollection, ctx, *this, HTMLCollection::Kind::TagNameNS);
    c->setNamespaceAndLocalName(ctx, ns, localName);
    return c;
}

Ref<HTMLCollection> Node::getElementsByClassName(JSContext* ctx, String classNames) {
    Ref<HTMLCollection> c = create<HTMLCollection>(ctx, idl::kHTMLCollection, ctx, *this, HTMLCollection::Kind::ClassName);
    c->setClassNames(ctx, classNames);
    return c;
}

Node* Node::insertBefore(JSContext* ctx, Node* node, OrNull<Node> child) {
    return &preInsert(ctx, *node, *this, child.ptr);
}

Node* Node::appendChild(JSContext* ctx, Node* node) {
    return &preInsert(ctx, *node, *this, nullptr);
}

Node* Node::replaceChild(JSContext* ctx, Node* node, Node* child) {
    return &replaceChildNode(ctx, *child, *node, *this);
}

Node* Node::removeChild(JSContext* ctx, Node* child) {
    return &preRemove(ctx, *child, *this);
}

void Node::remove(JSContext* ctx) {
    removeNode(ctx, *this);
}

static std::optional<String> characterDataOf(JSContext* ctx, Node& node) {
    if (node.isCharacterData()) {
        return static_cast<CharacterData&>(node).dataString(ctx);
    }
    return std::nullopt;
}

std::optional<String> Node::nodeValue(JSContext* ctx) {
    if (m_type == NodeType::Attribute) {
        return static_cast<Attr*>(this)->currentValue(ctx);
    }
    return characterDataOf(ctx, *this);
}

void Node::setNodeValue(JSContext* ctx, std::optional<String> value) {
    if (m_type == NodeType::Attribute) {
        static_cast<Attr*>(this)->setValue(ctx, value ? std::move(*value) : String());
    } else if (this->isCharacterData()) {
        static_cast<CharacterData*>(this)->setDataString(ctx, value ? std::move(*value) : String());
    }
}

std::optional<String> Node::textContent(JSContext* ctx) {
    if (m_type == NodeType::Element || m_type == NodeType::DocumentFragment) {
        return descendantTextContent(ctx, *this);
    }
    if (m_type == NodeType::Attribute) {
        return static_cast<Attr*>(this)->currentValue(ctx);
    }
    return characterDataOf(ctx, *this);
}

void Node::setTextContent(JSContext* ctx, std::optional<String> value) {
    String string = value ? std::move(*value) : String();
    if (m_type == NodeType::Element || m_type == NodeType::DocumentFragment) {
        stringReplaceAll(ctx, string, *this);
    } else if (m_type == NodeType::Attribute) {
        static_cast<Attr*>(this)->setValue(ctx, string);
    } else if (this->isCharacterData()) {
        static_cast<CharacterData*>(this)->setDataString(ctx, string);
    }
}

static bool isExclusiveText(const Node* n) {
    return n && n->type() == NodeType::Text;
}

void Node::normalize(JSContext* ctx) {
    JSRuntime* rt = JS_GetRuntime(ctx);
    Vector<Ref<Node>> texts{JSAllocator<Ref<Node>>(rt)};
    for (Node* n = this->nextInTreeOrder(this); n; n = n->nextInTreeOrder(this)) {
        if (n->type() == NodeType::Text) {
            texts.push_back(Ref<Node>::retain(ctx, n));
        }
    }
    for (Ref<Node>& ref : texts) {
        Node& node = *ref;
        if (!node.parent() || !this->isInclusiveAncestorOf(ctx, node)) {
            continue; // merged into an earlier node and removed
        }
        auto& text = static_cast<CharacterData&>(node);
        if (text.dataString(ctx).empty()) {
            removeNode(ctx, node);
            continue;
        }
        String data = text.dataString(ctx);
        Vector<Ref<Node>> following{JSAllocator<Ref<Node>>(rt)};
        for (Node* next = node.nextSiblingNode(); isExclusiveText(next); next = next->nextSiblingNode()) {
            following.push_back(Ref<Node>::retain(ctx, next));
            data = data.concat(ctx, static_cast<CharacterData*>(next)->dataString(ctx));
        }
        if (!following.empty()) {
            text.setDataString(ctx, data);
            for (Ref<Node>& f : following) {
                removeNode(ctx, *f);
            }
        }
    }
}

Ref<Node> Node::cloneNode(JSContext* ctx, bool subtree) {
    return cloneNodeInto(ctx, *this, this->nodeDocument(), subtree);
}

bool Node::isEqualNode(JSContext* ctx, OrNull<Node> other) {
    if (!other.ptr) {
        return false;
    }
    // Both subtrees in tree order, in step, without recursion (as cloneNodeInto): while each pair has as many
    // children, the two walks take the same steps, so `b` is always the node at `a`'s place in the other tree.
    Node* a = this;
    Node* b = other.ptr;
    for (;;) {
        if (a->m_type != b->m_type || a->childCount() != b->childCount() || !a->equalsShallow(ctx, *b)) {
            return false;
        }
        if (a->childCount()) {
            a = a->childAt(0);
            b = b->childAt(0);
            continue;
        }
        while (a != this && !a->nextSiblingNode()) {
            a = a->m_parent;
            b = b->m_parent;
        }
        if (a == this) {
            return true;
        }
        a = a->nextSiblingNode();
        b = b->nextSiblingNode();
    }
}

static Vector<const Node*> ancestorChain(JSContext* ctx, const Node* n) {
    Vector<const Node*> chain{JSAllocator<const Node*>(JS_GetRuntime(ctx))};
    for (; n; n = n->parent()) {
        chain.push_back(n);
    }
    std::reverse(chain.begin(), chain.end());
    return chain;
}

uint16_t Node::compareDocumentPosition(JSContext* ctx, Node* other) {
    constexpr uint16_t kDisconnected = 0x01, kPreceding = 0x02, kFollowing = 0x04, kContains = 0x08, kContainedBy = 0x10, kImplementationSpecific = 0x20;
    if (other == this) {
        return 0;
    }
    // DOM steps 3 to 8: an attribute stands for its element, after its element in tree order and before the element's
    // children, and two attributes of one element are in the order of its attribute list.
    Node* node1 = other;
    Node* node2 = this;
    Attr* attr1 = nullptr;
    Attr* attr2 = nullptr;
    if (node1->type() == NodeType::Attribute) {
        attr1 = static_cast<Attr*>(node1);
        node1 = attr1->owner();
    }
    if (node2->type() == NodeType::Attribute) {
        attr2 = static_cast<Attr*>(node2);
        node2 = attr2->owner();
        if (attr1 && node1 && node2 == node1) {
            auto* element = static_cast<Element*>(node2);
            for (size_t i = 0; i < element->attributeCount(); i++) {
                const Attribute& a = element->attributeAt(i);
                PlatformObject* p = a.node.isUndefined() ? nullptr : payloadOfKnown(a.node.value);
                if (p == attr1) {
                    return kImplementationSpecific | kPreceding;
                }
                if (p == attr2) {
                    return kImplementationSpecific | kFollowing;
                }
            }
        }
    }
    if (!node1 || !node2 || &node1->rootNode(ctx) != &node2->rootNode(ctx)) {
        // Any order, as long as it is consistent: the nodes' addresses, an attribute's own where it has no element.
        const void* a = node1 ? static_cast<const void*>(node1) : static_cast<const void*>(attr1);
        const void* b = node2 ? static_cast<const void*>(node2) : static_cast<const void*>(attr2);
        return kDisconnected | kImplementationSpecific | (std::less<const void*>()(a, b) ? kPreceding : kFollowing);
    }
    if ((node1 != node2 && node1->isInclusiveAncestorOf(ctx, *node2) && !attr1) || (node1 == node2 && attr2)) {
        return kContains | kPreceding;
    }
    if ((node1 != node2 && node2->isInclusiveAncestorOf(ctx, *node1) && !attr2) || (node1 == node2 && attr1)) {
        return kContainedBy | kFollowing;
    }
    Vector<const Node*> a = ancestorChain(ctx, node1), b = ancestorChain(ctx, node2);
    size_t i = 0;
    while (i < a.size() && i < b.size() && a[i] == b[i]) {
        i++;
    }
    // With an attribute one node can be the other's ancestor (an attribute's element and the element's descendant):
    // the ancestor comes first in tree order.
    if (i == a.size()) {
        return kPreceding;
    }
    if (i == b.size()) {
        return kFollowing;
    }
    // a[i] and b[i] are siblings under a[i - 1].
    return a[i]->indexInParent() < b[i]->indexInParent() ? kPreceding : kFollowing;
}

Element* Node::firstElementChild(JSContext* ctx) {
    for (size_t i = 0; i < this->childCount(); i++) {
        if (this->childAt(i)->isElement()) {
            return static_cast<Element*>(this->childAt(i));
        }
    }
    return nullptr;
}

Element* Node::lastElementChild(JSContext* ctx) {
    for (size_t i = this->childCount(); i > 0; i--) {
        if (this->childAt(i - 1)->isElement()) {
            return static_cast<Element*>(this->childAt(i - 1));
        }
    }
    return nullptr;
}

uint32_t Node::childElementCount(JSContext* ctx) {
    uint32_t count = 0;
    for (size_t i = 0; i < this->childCount(); i++) {
        count += this->childAt(i)->isElement() ? 1 : 0;
    }
    return count;
}

void Node::prepend(JSContext* ctx, std::vector<std::variant<Node*, String>> nodes) {
    Ref<Node> node = convertNodesIntoNode(ctx, nodes, this->nodeDocument());
    preInsert(ctx, *node, *this, this->firstChildNode());
}

void Node::append(JSContext* ctx, std::vector<std::variant<Node*, String>> nodes) {
    Ref<Node> node = convertNodesIntoNode(ctx, nodes, this->nodeDocument());
    preInsert(ctx, *node, *this, nullptr);
}

void Node::replaceChildren(JSContext* ctx, std::vector<std::variant<Node*, String>> nodes) {
    Ref<Node> node = convertNodesIntoNode(ctx, nodes, this->nodeDocument());
    ensurePreInsertValidity(ctx, *node, *this, nullptr);
    replaceAllChildren(ctx, node.get(), *this);
}

Element* Node::previousElementSibling(JSContext* ctx) {
    for (Node* n = this->previousSiblingNode(); n; n = n->previousSiblingNode()) {
        if (n->isElement()) {
            return static_cast<Element*>(n);
        }
    }
    return nullptr;
}

Element* Node::nextElementSibling(JSContext* ctx) {
    for (Node* n = this->nextSiblingNode(); n; n = n->nextSiblingNode()) {
        if (n->isElement()) {
            return static_cast<Element*>(n);
        }
    }
    return nullptr;
}

/// ChildNode's "viable previous sibling" (`following` false) or "viable next sibling" of `self`, a child of `parent`:
/// its first sibling on that side that is not in `nodes`, or nullptr. Only siblings in `nodes` are stepped over, so
/// at most nodes.size() of them: the nearest ones are marked first, and the walk costs a step per sibling it passes,
/// not a scan of the arguments for each (script controls their number, up to QuickJS's 65,535).
static Node* viableSibling(JSContext* ctx, Node& self, Node& parent, const std::vector<std::variant<Node*, String>>& nodes, bool following) {
    size_t at = self.indexInParent();
    size_t available = following ? parent.childCount() - at - 1 : at;
    size_t span = std::min(available, nodes.size());
    // listed[d - 1]: the sibling at distance d is in `nodes`.
    Vector<uint8_t> listed(span, 0, JSAllocator<uint8_t>(JS_GetRuntime(ctx)));
    for (const auto& item : nodes) {
        Node* const* p = std::get_if<Node*>(&item);
        if (!p || (*p)->parent() != &parent) {
            continue;
        }
        size_t index = (*p)->indexInParent();
        if (following ? index > at : index < at) {
            size_t distance = following ? index - at : at - index;
            if (distance <= span) {
                listed[distance - 1] = 1;
            }
        }
    }
    size_t distance = 1;
    while (distance <= span && listed[distance - 1]) {
        distance++;
    }
    // Past `span` with siblings left, the next one is not listed: the `span` ones before it used every argument.
    if (distance > available) {
        return nullptr;
    }
    return parent.childAt(following ? at + distance : at - distance);
}

void Node::before(JSContext* ctx, std::vector<std::variant<Node*, String>> nodes) {
    Node* parent = this->parent();
    if (!parent) {
        return;
    }
    Ref<Node> keepParent = Ref<Node>::retain(ctx, parent);
    Node* viablePrevious = viableSibling(ctx, *this, *parent, nodes, false);
    Ref<Node> keepPrevious = Ref<Node>::retain(ctx, viablePrevious);
    Ref<Node> node = convertNodesIntoNode(ctx, nodes, this->nodeDocument());
    Node* reference = viablePrevious ? viablePrevious->nextSiblingNode() : parent->firstChildNode();
    preInsert(ctx, *node, *parent, reference);
}

void Node::after(JSContext* ctx, std::vector<std::variant<Node*, String>> nodes) {
    Node* parent = this->parent();
    if (!parent) {
        return;
    }
    Ref<Node> keepParent = Ref<Node>::retain(ctx, parent);
    Node* viableNext = viableSibling(ctx, *this, *parent, nodes, true);
    Ref<Node> keepNext = Ref<Node>::retain(ctx, viableNext);
    Ref<Node> node = convertNodesIntoNode(ctx, nodes, this->nodeDocument());
    preInsert(ctx, *node, *parent, viableNext);
}

void Node::replaceWith(JSContext* ctx, std::vector<std::variant<Node*, String>> nodes) {
    Node* parent = this->parent();
    if (!parent) {
        return;
    }
    Ref<Node> keepParent = Ref<Node>::retain(ctx, parent);
    Node* viableNext = viableSibling(ctx, *this, *parent, nodes, true);
    Ref<Node> keepNext = Ref<Node>::retain(ctx, viableNext);
    Ref<Node> node = convertNodesIntoNode(ctx, nodes, this->nodeDocument());
    if (this->parent() == parent) {
        replaceChildNode(ctx, *this, *node, *parent);
    } else {
        preInsert(ctx, *node, *parent, viableNext);
    }
}

Node* nodeOf(JSContext* ctx, JSValueConst v) {
    return static_cast<Node*>(payloadImplementing(ctx, v, idl::kNode));
}

} // namespace wr
