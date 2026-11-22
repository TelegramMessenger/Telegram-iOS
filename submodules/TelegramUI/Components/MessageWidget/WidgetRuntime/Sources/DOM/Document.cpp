#include "Sources/DOM/Document.h"

#include "Generated/Bindings.h"
#include "Sources/DOM/DOM.h"
#include "Sources/Events/Event.h"

namespace wr {

Document::Document(JSContext* ctx, DocumentKind kind) : Node(ctx, NodeType::Document, nullptr), m_kind(kind) {}

Ref<Document> Document::createHTML(JSContext* ctx) {
    return create<Document>(ctx, idl::kDocument, ctx, DocumentKind::HTML);
}

Ref<Document> Document::construct(JSContext* ctx) {
    return create<Document>(ctx, idl::kDocument, ctx, DocumentKind::XML);
}

void Document::noteChildInserted(Node& child) {
    // An earlier child of the same kind keeps the slot (the first one in tree order), though pre-insertion validity
    // allows only one.
    if (child.isElement()) {
        if (!m_documentElement || child.indexInParent() < m_documentElement->indexInParent()) {
            m_documentElement = static_cast<Element*>(&child);
        }
    } else if (child.type() == NodeType::DocumentType) {
        if (!m_doctype || child.indexInParent() < m_doctype->indexInParent()) {
            m_doctype = static_cast<DocumentType*>(&child);
        }
    }
}

void Document::noteChildRemoved(Node& child) {
    if (&child == m_documentElement) {
        m_documentElement = nullptr;
    } else if (&child == m_doctype) {
        m_doctype = nullptr;
    }
}

// HTML: a template contents owner document is its own owner; any other document makes one on first use.
Document& Document::templateContentsOwner(JSContext* ctx) {
    if (m_isTemplateOwner) {
        return *this;
    }
    if (m_templateOwner.isUndefined()) {
        Ref<Document> owner = create<Document>(ctx, idl::kDocument, ctx, m_kind);
        owner->m_isTemplateOwner = true;
        m_templateOwner.set(JS_GetRuntime(ctx), owner.release());
    }
    return *static_cast<Document*>(payloadOfKnown(m_templateOwner.value));
}

HTMLScriptElement* Document::currentScriptElement() const {
    return m_currentScript.isUndefined() ? nullptr : static_cast<HTMLScriptElement*>(payloadOfKnown(m_currentScript.value));
}

void Document::setCurrentScript(JSContext* ctx, HTMLScriptElement* script) {
    m_currentScript.set(JS_GetRuntime(ctx), script ? JS_DupValue(ctx, script->object()) : JS_UNDEFINED);
}

void Document::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    m_templateOwner.mark(rt, mark);
    m_currentScript.mark(rt, mark);
    Node::trace(rt, mark);
}

void Document::dispose(JSRuntime* rt) {
    m_documentElement = nullptr;
    m_doctype = nullptr;
    m_templateOwner.clear(rt);
    m_currentScript.clear(rt);
    m_url.clear(rt);
    Node::dispose(rt);
}

String Document::nodeName(JSContext* ctx) {
    return String::fromUTF8(ctx, "#document");
}

void Document::setURL(JSContext* ctx, std::string_view url) {
    m_url.set(JS_GetRuntime(ctx), String::fromUTF8(ctx, url).toJS(ctx));
}

USVString Document::URL(JSContext* ctx) {
    if (m_url.isUndefined()) {
        return USVString(String::fromUTF8(ctx, "about:srcdoc"));
    }
    return USVString(String::adopt(ctx, JS_DupValue(ctx, m_url.value)));
}

USVString Document::documentURI(JSContext* ctx) {
    return this->URL(ctx);
}

String Document::compatMode(JSContext* ctx) {
    return String::fromUTF8(ctx, m_mode == DocumentMode::Quirks ? "BackCompat" : "CSS1Compat");
}

String Document::characterSet(JSContext* ctx) {
    return String::fromUTF8(ctx, "UTF-8");
}

String Document::contentType(JSContext* ctx) {
    return String::fromUTF8(ctx, m_kind == DocumentKind::HTML ? "text/html" : "application/xml");
}

String Document::readyState(JSContext* ctx) {
    switch (m_readiness) {
    case DocumentReadiness::Loading:
        return String::fromUTF8(ctx, "loading");
    case DocumentReadiness::Interactive:
        return String::fromUTF8(ctx, "interactive");
    case DocumentReadiness::Complete:
        break;
    }
    return String::fromUTF8(ctx, "complete");
}

static bool isASCIIAlpha(char16_t c) {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
}

bool isValidElementLocalName(JSContext* ctx, const String& name) {
    uint32_t n = name.length();
    if (n == 0) {
        return false;
    }
    char16_t first = name.at(0);
    if (isASCIIAlpha(first)) {
        for (uint32_t i = 1; i < n; i++) {
            char16_t c = name.at(i);
            if (isASCIIWhitespace(c) || c == 0 || c == '/' || c == '>') {
                return false;
            }
        }
        return true;
    }
    if (!(first == ':' || first == '_' || first >= 0x80)) {
        return false;
    }
    for (uint32_t i = 1; i < n; i++) {
        char16_t c = name.at(i);
        bool ok = isASCIIAlpha(c) || (c >= '0' && c <= '9') || c == '-' || c == '.' || c == ':' || c == '_' || c >= 0x80;
        if (!ok) {
            return false;
        }
    }
    return true;
}

Ref<Element> Document::createElement(JSContext* ctx, String localName, std::variant<String, idl::ElementCreationOptions>) {
    if (!isValidElementLocalName(ctx, localName)) {
        throw DOMError{"InvalidCharacterError", "The tag name provided ('" + quotedForMessage(localName) + "') is not a valid name."};
    }
    if (m_kind == DocumentKind::HTML) {
        localName = asciiLowercase(ctx, localName);
    }
    Namespace ns = m_kind == DocumentKind::HTML ? Namespace::HTML : Namespace::None;
    Atom name = Atom::fromString(ctx, localName);
    return createElementNode(ctx, *this, ns, name.get(), JS_ATOM_NULL, JS_ATOM_NULL);
}

Ref<Element> Document::createElementNS(JSContext* ctx, std::optional<String> namespaceURI, String qualifiedName, std::variant<String, idl::ElementCreationOptions>) {
    // "validate and extract" (DOM).
    Namespace ns = namespaceOf(namespaceURI);
    std::optional<String> prefix;
    String localName = qualifiedName;
    uint32_t colon = UINT32_MAX;
    // The colon is looked for once.
    for (uint32_t i = 0; i < qualifiedName.length(); i++) {
        if (qualifiedName.at(i) == ':') {
            colon = i;
            break;
        }
    }
    if (colon != UINT32_MAX) {
        prefix = qualifiedName.substring(ctx, 0, colon);
        localName = qualifiedName.substring(ctx, colon + 1, qualifiedName.length());
        if (!isValidNamespacePrefix(ctx, *prefix)) {
            throw DOMError{"InvalidCharacterError", "The qualified name provided ('" + quotedForMessage(qualifiedName) + "') has an invalid prefix."};
        }
    }
    if (!isValidElementLocalName(ctx, localName)) {
        throw DOMError{"InvalidCharacterError", "The qualified name provided ('" + quotedForMessage(qualifiedName) + "') is not valid."};
    }
    if (prefix && ns == Namespace::None) {
        throw DOMError{"NamespaceError", "A prefix needs a namespace."};
    }
    if (prefix && prefix->equalsASCII("xml") && ns != Namespace::XML) {
        throw DOMError{"NamespaceError", "The prefix 'xml' needs the XML namespace."};
    }
    bool xmlnsName = qualifiedName.equalsASCII("xmlns") || (prefix && prefix->equalsASCII("xmlns"));
    if (xmlnsName != (ns == Namespace::XMLNS)) {
        throw DOMError{"NamespaceError", "'xmlns' and the XMLNS namespace go together."};
    }
    Atom name = Atom::fromString(ctx, localName);
    Atom prefixAtom = prefix ? Atom::fromString(ctx, *prefix) : Atom();
    Atom otherNamespace = ns == Namespace::Other ? Atom::fromString(ctx, *namespaceURI) : Atom();
    return createElementNode(ctx, *this, ns, name.get(), prefixAtom.get(), otherNamespace.get());
}

Ref<DocumentFragment> Document::createDocumentFragment(JSContext* ctx) {
    return create<DocumentFragment>(ctx, idl::kDocumentFragment, ctx, *this);
}

Ref<Text> Document::createTextNode(JSContext* ctx, String data) {
    return Text::make(ctx, *this, std::move(data));
}

Ref<Comment> Document::createComment(JSContext* ctx, String data) {
    return Comment::make(ctx, *this, std::move(data));
}

Ref<Node> Document::importNode(JSContext* ctx, Node* node, bool subtree) {
    if (node->type() == NodeType::Document) {
        throw DOMError{"NotSupportedError", "A document cannot be imported."};
    }
    return cloneNodeInto(ctx, *node, *this, subtree);
}

Node* Document::adoptNode(JSContext* ctx, Node* node) {
    if (node->type() == NodeType::Document) {
        throw DOMError{"NotSupportedError", "A document cannot be adopted."};
    }
    adoptNodeInto(ctx, *node, *this);
    return node;
}

Ref<Attr> Document::createAttribute(JSContext* ctx, String localName) {
    if (!isValidAttributeLocalName(ctx, localName)) {
        throw DOMError{"InvalidCharacterError", "'" + quotedForMessage(localName) + "' is not a valid attribute name."};
    }
    if (m_kind == DocumentKind::HTML) {
        localName = asciiLowercase(ctx, localName);
    }
    Atom local = Atom::fromString(ctx, localName);
    return create<Attr>(ctx, idl::kAttr, ctx, *this, Namespace::None, JS_ATOM_NULL, JS_ATOM_NULL, local.get(), String());
}

Ref<Attr> Document::createAttributeNS(JSContext* ctx, std::optional<String> namespaceURI, String qualifiedName) {
    AttributeName name = validateAndExtractAttributeName(ctx, namespaceURI, qualifiedName);
    return create<Attr>(ctx, idl::kAttr, ctx, *this, name.ns, name.otherNamespace.get(), name.prefix.get(), name.localName.get(), String());
}

Ref<Node> Document::cloneShallow(JSContext* ctx, Document&) {
    Ref<Document> copy = create<Document>(ctx, idl::kDocument, ctx, m_kind);
    copy->setMode(m_mode);
    return copy;
}

EventTarget* Document::getTheParent(JSContext* ctx, Event& event) {
    DOMState* state = DOMState::find(ctx);
    if (!state || event.typeAtom() == state->name(Name::load)) {
        return nullptr;
    }
    if (!state->hasDocument() || &state->document() != this) {
        return nullptr;
    }
    return state->windowTarget();
}

Ref<DocumentFragment> DocumentFragment::construct(JSContext* ctx) {
    return globalDocument(ctx).createDocumentFragment(ctx);
}

Ref<Node> DocumentFragment::cloneShallow(JSContext* ctx, Document& document) {
    return document.createDocumentFragment(ctx);
}

} // namespace wr
