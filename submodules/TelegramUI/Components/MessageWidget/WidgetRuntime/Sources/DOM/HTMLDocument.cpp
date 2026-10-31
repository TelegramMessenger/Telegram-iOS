// The HTML standard's Document members (https://html.spec.whatwg.org/#dom-tree-accessors). Every element in the HTML
// namespace is an HTMLElement (createElementNode).
// Not in M1a: the SVG document's title (a document whose element is an SVG svg element).
#include "Generated/Bindings.h"
#include "Sources/Host/HostState.h"
#include "Sources/DOM/DOM.h"

namespace wr {

/// "the html element": the document element, if it is an html element.
static Element* htmlElementOf(Document& document, JSContext* ctx) {
    Element* root = document.documentElementNode();
    return root && root->hasHTMLName(DOMState::of(ctx).name(Name::html)) ? root : nullptr;
}

/// The first child of `parent` that is an HTML element named `a` or `b`.
static Element* firstHTMLChild(JSContext* ctx, Element* parent, JSAtom a, JSAtom b) {
    if (!parent) {
        return nullptr;
    }
    for (size_t i = 0; i < parent->childCount(); i++) {
        Node* c = parent->childAt(i);
        if (c->isElement() && (static_cast<Element*>(c)->hasHTMLName(a) || static_cast<Element*>(c)->hasHTMLName(b))) {
            return static_cast<Element*>(c);
        }
    }
    return nullptr;
}

HTMLElement* Document::head(JSContext* ctx) {
    JSAtom head = DOMState::of(ctx).name(Name::head);
    return static_cast<HTMLElement*>(firstHTMLChild(ctx, htmlElementOf(*this, ctx), head, head));
}

Element* Document::activeElement(JSContext* ctx) {
    DOMState* state = DOMState::find(ctx);
    if (!state || !state->hasDocument() || &state->document() != this) {
        return nullptr;
    }
    // Nothing is ever focused (V4 plan, Task 8): the body, else the document element.
    if (HTMLElement* body = this->body(ctx)) {
        return body;
    }
    return this->documentElementNode();
}

HTMLElement* Document::body(JSContext* ctx) {
    DOMState& state = DOMState::of(ctx);
    return static_cast<HTMLElement*>(firstHTMLChild(ctx, htmlElementOf(*this, ctx), state.name(Name::body), state.name(Name::frameset)));
}

void Document::setBody(JSContext* ctx, OrNull<HTMLElement> value) {
    DOMState& state = DOMState::of(ctx);
    HTMLElement* element = value.ptr;
    if (!element || !(element->hasHTMLName(state.name(Name::body)) || element->hasHTMLName(state.name(Name::frameset)))) {
        throw DOMError{"HierarchyRequestError", "The new body must be a body or frameset element."};
    }
    HTMLElement* current = this->body(ctx);
    if (element == current) {
        return;
    }
    if (current) {
        replaceChildNode(ctx, *current, *element, *current->parent());
        return;
    }
    Element* root = this->documentElementNode();
    if (!root) {
        throw DOMError{"HierarchyRequestError", "The document has no element to hold a body."};
    }
    preInsert(ctx, *element, *root, nullptr);
}

/// "the title element": the first HTML title element in tree order.
static Element* titleElement(Document& document, JSContext* ctx) {
    JSAtom title = DOMState::of(ctx).name(Name::title);
    for (Node* n = document.nextInTreeOrder(&document); n; n = n->nextInTreeOrder(&document)) {
        if (n->isElement() && static_cast<Element*>(n)->hasHTMLName(title)) {
            return static_cast<Element*>(n);
        }
    }
    return nullptr;
}

String Document::title(JSContext* ctx) {
    Element* element = titleElement(*this, ctx);
    if (!element) {
        return String();
    }
    // The title element's child text content: its Text children's data only.
    Vector<char16_t> text{JSAllocator<char16_t>(JS_GetRuntime(ctx))};
    for (size_t i = 0; i < element->childCount(); i++) {
        Node* c = element->childAt(i);
        if (c->type() == NodeType::Text) {
            appendCodeUnits(text, static_cast<Text*>(c)->dataString(ctx));
        }
    }
    return stripAndCollapseASCIIWhitespace(ctx, String::fromUTF16(ctx, text.data(), text.size()));
}

Ref<NodeList> Document::getElementsByName(JSContext* ctx, String elementName) {
    return Ref<NodeList>(create<NameNodeList>(ctx, idl::kNodeList, ctx, *this, elementName));
}

void Document::setTitle(JSContext* ctx, String value) {
    // Only a document whose element is in the HTML namespace has a title to set here.
    Element* root = this->documentElementNode();
    if (!root || root->ns() != Namespace::HTML) {
        return;
    }
    Ref<Element> element = Ref<Element>::retain(ctx, titleElement(*this, ctx));
    if (!element) {
        HTMLElement* head = this->head(ctx);
        if (!head) {
            return;
        }
        element = createElementNode(ctx, *this, Namespace::HTML, DOMState::of(ctx).name(Name::title), JS_ATOM_NULL, JS_ATOM_NULL);
        preInsert(ctx, *element, *head, nullptr);
    }
    stringReplaceAll(ctx, value, *element);
}

String Document::visibilityState(JSContext* ctx) {
    return String::fromUTF8(ctx, m_hidden ? "hidden" : "visible");
}

} // namespace wr
