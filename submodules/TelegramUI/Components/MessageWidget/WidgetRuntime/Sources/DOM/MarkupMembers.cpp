// HTML's innerHTML, outerHTML and insertAdjacentHTML (https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html),
// and DOM's legacy insertAdjacentElement and insertAdjacentText (https://dom.spec.whatwg.org/#interface-element).
//
// Divergence: M1a has no XML parser. HTML's "fragment parsing algorithm steps" run the XML fragment parser when the
// context's node document is not an HTML document (an element of `new Document()`, say); here that is a
// NotSupportedError (parseMarkup). The checks the members make before they parse keep their order, so an element
// without a parent still makes outerHTML's setter return and a bad position is still a SyntaxError. The "fragment
// serializing algorithm steps" run the XML serializer for such a node; here the getters run the HTML one.
//
// Divergence: script-parsed markup (the innerHTML and outerHTML setters, insertAdjacentHTML) longer than
// kMaxScriptMarkupUnits (1,048,576) UTF-16 units is a NotSupportedError. Browsers have no such limit; it bounds the
// transient gumbo heap, which is system heap outside the widget's memory limit (transientHeapBound in Parser.cpp
// states the bound, pinned by ParserTests). The boot document (parseDocumentInto, 256 KiB-source-capped) is unaffected.
#include "Generated/Bindings.h"
#include "Sources/DOM/DOM.h"
#include "Sources/DOM/ParserInternal.h"

namespace wr {

namespace {


enum class Where { BeforeBegin, AfterBegin, BeforeEnd, AfterEnd, Invalid };

Where whereFrom(const String& s) {
    if (s.equalsIgnoringASCIICase("beforebegin")) {
        return Where::BeforeBegin;
    }
    if (s.equalsIgnoringASCIICase("afterbegin")) {
        return Where::AfterBegin;
    }
    if (s.equalsIgnoringASCIICase("beforeend")) {
        return Where::BeforeEnd;
    }
    if (s.equalsIgnoringASCIICase("afterend")) {
        return Where::AfterEnd;
    }
    return Where::Invalid;
}

[[noreturn]] void invalidPosition() {
    throw DOMError{"SyntaxError", "The position is not one of 'beforeBegin', 'afterBegin', 'beforeEnd' or 'afterEnd'."};
}

/// DOM's "insert adjacent": null when the position needs a parent there is not.
Node* insertAdjacent(JSContext* ctx, Element& element, Where where, Node& node) {
    switch (where) {
    case Where::BeforeBegin:
        return element.parent() ? &preInsert(ctx, node, *element.parent(), &element) : nullptr;
    case Where::AfterBegin:
        return &preInsert(ctx, node, element, element.firstChildNode());
    case Where::BeforeEnd:
        return &preInsert(ctx, node, element, nullptr);
    case Where::AfterEnd:
        return element.parent() ? &preInsert(ctx, node, *element.parent(), element.nextSiblingNode()) : nullptr;
    case Where::Invalid:
        break;
    }
    invalidPosition();
}

/// A new <body> in `document`, the context markup parses in when there is no better element.
Ref<Element> bodyContext(JSContext* ctx, Document& document) {
    return createElementNode(ctx, document, Namespace::HTML, DOMState::of(ctx).name(Name::body), JS_ATOM_NULL, JS_ATOM_NULL);
}

/// HTML's "fragment parsing algorithm steps", for an HTML document only (the divergence above).
Ref<DocumentFragment> parseMarkup(JSContext* ctx, Element& context, const String& markup) {
    if (!context.nodeDocument().isHTMLDocument()) {
        throw DOMError{"NotSupportedError", "Markup can be parsed only for an element of an HTML document: there is no XML parser."};
    }
    // The length cap (the divergence noted at the top), on the String's length in O(1), before the UTF-8 copy, so
    // markup over the cap is refused without converting megabytes of it.
    if (markup.length() > kMaxScriptMarkupUnits) {
        throw DOMError{"NotSupportedError", "The markup is too long to parse."};
    }
    // utf8ForParse, not utf8: a lone surrogate becomes one U+FFFD rather than WTF-8 (which gumbo would reject byte by
    // byte into three).
    return parseFragment(ctx, context, markup.utf8ForParse());
}

bool isTemplate(JSContext* ctx, const Element& element) {
    return element.hasHTMLName(DOMState::of(ctx).name(Name::template_));
}

} // namespace

String Element::innerHTML(JSContext* ctx) {
    return serializeChildren(ctx, *this);
}

void Element::setInnerHTML(JSContext* ctx, LegacyNullToEmptyString value) {
    Ref<DocumentFragment> fragment = parseMarkup(ctx, *this, value);
    Node* target = this;
    if (isTemplate(ctx, *this)) {
        target = static_cast<HTMLTemplateElement*>(this)->content(ctx);
    }
    replaceAllChildren(ctx, fragment.get(), *target);
}

String Element::outerHTML(JSContext* ctx) {
    return serializeOuter(ctx, *this);
}

void Element::setOuterHTML(JSContext* ctx, LegacyNullToEmptyString value) {
    Node* parent = this->parent();
    // No parent: nothing could reach the nodes the markup would make.
    if (!parent) {
        return;
    }
    if (parent->type() == NodeType::Document) {
        throw DOMError{"NoModificationAllowedError", "An element whose parent is the document cannot be replaced by markup."};
    }
    Ref<Node> keepParent = Ref<Node>::retain(ctx, parent);
    Ref<Element> context = parent->type() == NodeType::DocumentFragment ? bodyContext(ctx, this->nodeDocument()) : Ref<Element>::retain(ctx, static_cast<Element*>(parent));
    Ref<DocumentFragment> fragment = parseMarkup(ctx, *context, value);
    replaceChildNode(ctx, *this, *fragment, *parent);
}

void Element::insertAdjacentHTML(JSContext* ctx, String position, String string) {
    Where where = whereFrom(position);
    Node* context = nullptr;
    switch (where) {
    case Where::BeforeBegin:
    case Where::AfterEnd:
        context = this->parent();
        if (!context || context->type() == NodeType::Document) {
            throw DOMError{"NoModificationAllowedError", "The element has no parent element to insert markup next to it in."};
        }
        break;
    case Where::AfterBegin:
    case Where::BeforeEnd:
        context = this;
        break;
    case Where::Invalid:
        invalidPosition();
    }
    Ref<Node> keepContext = Ref<Node>::retain(ctx, context);
    Ref<Element> contextElement;
    auto* asElement = context->isElement() ? static_cast<Element*>(context) : nullptr;
    if (!asElement || (asElement->nodeDocument().isHTMLDocument() && asElement->hasHTMLName(DOMState::of(ctx).name(Name::html)))) {
        contextElement = bodyContext(ctx, this->nodeDocument());
    } else {
        contextElement = Ref<Element>::retain(ctx, asElement);
    }
    Ref<DocumentFragment> fragment = parseMarkup(ctx, *contextElement, string);
    // HTML says "insert" for three of the positions and "append" for beforeend; pre-inserting a new fragment into an
    // element or a fragment passes every check, so the four share DOM's "insert adjacent".
    insertAdjacent(ctx, *this, where, *fragment);
}

Element* Element::insertAdjacentElement(JSContext* ctx, String where, Element* element) {
    return static_cast<Element*>(insertAdjacent(ctx, *this, whereFrom(where), *element));
}

void Element::insertAdjacentText(JSContext* ctx, String where, String data) {
    Ref<Text> text = Text::make(ctx, this->nodeDocument(), std::move(data));
    insertAdjacent(ctx, *this, whereFrom(where), *text);
}

} // namespace wr
