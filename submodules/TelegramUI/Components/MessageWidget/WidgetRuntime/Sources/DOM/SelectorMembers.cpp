// ParentNode's querySelector and querySelectorAll, and Element's closest, matches and webkitMatchesSelector: DOM's
// "scope-match a selectors string" over Selectors.h.
#include "Generated/Bindings.h"
#include "Sources/DOM/DOM.h"

namespace wr {

Element* Node::querySelector(JSContext* ctx, String selectors) {
    SelectorList list = parseSelectors(ctx, selectors);
    for (Node* n = this->nextInTreeOrder(this); n; n = n->nextInTreeOrder(this)) {
        if (n->isElement() && matchesSelectors(ctx, list, *static_cast<Element*>(n), this)) {
            return static_cast<Element*>(n);
        }
    }
    return nullptr;
}

Ref<NodeList> Node::querySelectorAll(JSContext* ctx, String selectors) {
    SelectorList list = parseSelectors(ctx, selectors);
    // A transient list of views: matching runs no script, so nothing found can leave the tree before the static list
    // holds it.
    std::vector<Node*> found;
    for (Node* n = this->nextInTreeOrder(this); n; n = n->nextInTreeOrder(this)) {
        if (n->isElement() && matchesSelectors(ctx, list, *static_cast<Element*>(n), this)) {
            found.push_back(n);
        }
    }
    return Ref<NodeList>(StaticNodeList::make(ctx, found));
}

Element* Element::closest(JSContext* ctx, String selectors) {
    SelectorList list = parseSelectors(ctx, selectors);
    for (Element* e = this; e; e = e->parentElementNode()) {
        if (matchesSelectors(ctx, list, *e, this)) {
            return e;
        }
    }
    return nullptr;
}

bool Element::matches(JSContext* ctx, String selectors) {
    SelectorList list = parseSelectors(ctx, selectors);
    return matchesSelectors(ctx, list, *this, this);
}

} // namespace wr
