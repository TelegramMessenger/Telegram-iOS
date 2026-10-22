#pragma once

#include <string_view>
#include <variant>
#include <vector>

#include "Generated/Bindings.h"
#include "Sources/DOM/Namespaces.h"
#include "Sources/DOM/Node.h"

namespace wr {

class Animation;
class Attr;
class Comment;
class DocumentTimeline;
class DocumentFragment;
class DocumentType;
class Element;
class HTMLElement;
class HTMLScriptElement;
class NodeList;
class Text;
class Window;

/// What the DOM's algorithms tell the layers above (M1b: mutation observers and scripts; M1c: the render tree).
class MutationListener {
public:
    virtual ~MutationListener() = default;
    virtual void childrenChanged(Node& parent) {}
    /// After `node` was inserted (once per inserted node, not per descendant).
    virtual void nodeInserted(Node& node) {}
    /// After `node` was removed from `oldParent`.
    virtual void nodeRemoved(Node& node, Node& oldParent) {}
    /// After the attribute `localName` in namespace `ns` (None: the null namespace) of `element` was set, changed or
    /// removed.
    virtual void attributeChanged(Element& element, JSAtom localName, Namespace ns) {}
    virtual void characterDataChanged(Node& node) {}
};

enum class DocumentKind : uint8_t { HTML, XML };
enum class DocumentMode : uint8_t { NoQuirks, Quirks, LimitedQuirks };
/// HTML's "current document readiness". A Document is "complete" unless the parser made it (boot sets "loading").
enum class DocumentReadiness : uint8_t { Loading, Interactive, Complete };

class Document : public Node {
public:
    Document(JSContext* ctx, DocumentKind kind);
    /// An empty HTML document (`text/html`, URL about:srcdoc).
    static Ref<Document> createHTML(JSContext* ctx);

    bool isHTMLDocument() const { return m_kind == DocumentKind::HTML; }
    /// HTML's visibility state: "hidden" until HostState makes the main document visible; the host changes it with
    /// HostState::setVisible. Other documents stay hidden.
    bool isHidden() const { return m_hidden; }
    void setHidden(bool hidden) { m_hidden = hidden; }
    DocumentMode mode() const { return m_mode; }
    /// The mode decides how class names compare (quirks: ASCII case-insensitively), so a change is a mutation.
    void setMode(DocumentMode mode) {
        if (mode != m_mode) {
            m_mode = mode;
            this->noteMutation();
        }
    }
    /// Bumped by every mutation of any node of this document, by the mode and by adopting a node into it: live
    /// collections recompute when it moved.
    uint64_t version() const { return m_version; }
    void noteMutation() { m_version++; }
    std::vector<MutationListener*>& mutationListeners() { return m_listeners; }
    /// Calls `f` with each listener, by index over the live list: a listener that registers or unregisters one while
    /// it is called cannot invalidate the walk, as it would a range-for's iterators. (One added during the walk is
    /// called too; one removed before the current position shifts the rest, so the next one is skipped.)
    template <class F>
    void forEachMutationListener(F&& f) {
        for (size_t i = 0; i < m_listeners.size(); i++) {
            f(*m_listeners[i]);
        }
    }
    /// The first element child and the doctype child: slots the raw child edits keep, so a read is O(1).
    Element* documentElementNode() const { return m_documentElement; }
    DocumentType* doctypeNode() const { return m_doctype; }

    // Document
    static Ref<Document> construct(JSContext* ctx);
    String nodeName(JSContext* ctx) override;
    USVString URL(JSContext* ctx);
    USVString documentURI(JSContext* ctx);
    String compatMode(JSContext* ctx);
    String characterSet(JSContext* ctx);
    String charset(JSContext* ctx) { return this->characterSet(ctx); }
    String inputEncoding(JSContext* ctx) { return this->characterSet(ctx); }
    String contentType(JSContext* ctx);
    DocumentType* doctype(JSContext*) { return this->doctypeNode(); }
    Element* documentElement(JSContext*) { return this->documentElementNode(); }
    Ref<Element> createElement(JSContext* ctx, String localName, std::variant<String, idl::ElementCreationOptions> options);
    Ref<Element> createElementNS(JSContext* ctx, std::optional<String> ns, String qualifiedName, std::variant<String, idl::ElementCreationOptions> options);
    Ref<DocumentFragment> createDocumentFragment(JSContext* ctx);
    Ref<Text> createTextNode(JSContext* ctx, String data);
    Ref<Comment> createComment(JSContext* ctx, String data);
    Ref<Node> importNode(JSContext* ctx, Node* node, bool subtree);
    Node* adoptNode(JSContext* ctx, Node* node);
    Ref<Attr> createAttribute(JSContext* ctx, String localName);
    Ref<Attr> createAttributeNS(JSContext* ctx, std::optional<String> namespaceURI, String qualifiedName);
    /// DOM's legacy createEvent: an uninitialized Event or CustomEvent (Sources/Events/Event.cpp).
    Ref<Event> createEvent(JSContext* ctx, String interface);

    // Document, from HTML (HTMLDocument.cpp)
    String title(JSContext* ctx);
    void setTitle(JSContext* ctx, String value);
    HTMLElement* body(JSContext* ctx);
    /// CSSOM View (V3 plan, Task 3; Sources/DOM/Geometry.cpp): the element under the point, null outside the document
    /// or for a document that is not the window's.
    Element* elementFromPoint(JSContext* ctx, double x, double y);
    /// Web Animations (V5e plan, Task 3; Sources/Animation/Animatable.cpp): the runtime's one document timeline, and the
    /// relevant animations whose targets are connected.
    DocumentTimeline* timeline(JSContext* ctx);
    std::vector<Ref<Animation>> getAnimations(JSContext* ctx);
    /// DocumentOrShadowRoot's activeElement: the main document's body (else its document element), since profile 1 has
    /// no focus (V4 plan, Task 8); null for any other document.
    Element* activeElement(JSContext* ctx);
    void setBody(JSContext* ctx, OrNull<HTMLElement> value);
    HTMLElement* head(JSContext* ctx);
    Ref<NodeList> getElementsByName(JSContext* ctx, String elementName);
    /// HTML's currentScript: the classic script executing in this document, or null. A counted reference, traced.
    HTMLScriptElement* currentScriptElement() const;
    void setCurrentScript(JSContext* ctx, HTMLScriptElement* script);
    HTMLScriptElement* currentScript(JSContext*) { return this->currentScriptElement(); }
    DocumentReadiness readiness() const { return m_readiness; }
    /// The raw state; HTML's "update the current document readiness" (which fires readystatechange) is the boot's.
    void setReadiness(DocumentReadiness readiness) { m_readiness = readiness; }
    String readyState(JSContext* ctx);
    /// The window, for the main document (DOMState::document()); null for any other. Defined in Host/Boot.cpp.
    Window* defaultView(JSContext* ctx);
    bool hidden(JSContext*) { return m_hidden; }
    String visibilityState(JSContext* ctx);

    /// HTML's "appropriate template contents owner document": the inert document template contents live in. Made on
    /// first use; a template contents owner document is its own.
    Document& templateContentsOwner(JSContext* ctx);

    /// The document's URL (DOM "URL"): about:srcdoc until the boot (or the WPT runner) sets it.
    void setURL(JSContext* ctx, std::string_view url);

    Ref<Node> cloneShallow(JSContext* ctx, Document& document) override;
    /// DOM: a document's parent in an event path is its window, except for `load` and for a document without a
    /// browsing context: every document but the main one (template contents owners, `new Document()`).
    EventTarget* getTheParent(JSContext* ctx, Event& event) override;
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

private:
    friend class Node;
    /// Called by Node::insertChildAt, removeChildAt and removeAllChildren, the one place a document's children change.
    /// A document has at most one element child and one doctype child (DOM's pre-insertion validity), so each is a slot
    /// rather than a scan.
    void noteChildInserted(Node& child);
    /// Before the child list releases its reference to `child`.
    void noteChildRemoved(Node& child);

    DocumentKind m_kind;
    DocumentMode m_mode = DocumentMode::NoQuirks;
    uint64_t m_version = 0;
    std::vector<MutationListener*> m_listeners;
    /// Not counted: the child list holds the reference, and the slot is cleared before it is released.
    Element* m_documentElement = nullptr;
    DocumentType* m_doctype = nullptr;
    /// The template contents owner document, made on first use: a counted reference, traced.
    Held m_templateOwner;
    Held m_currentScript;
    Held m_url;
    bool m_isTemplateOwner = false;
    bool m_hidden = true;
    DocumentReadiness m_readiness = DocumentReadiness::Complete;
};

/// "valid element local name" (DOM, 2025): the check createElement makes.
bool isValidElementLocalName(JSContext* ctx, const String& name);

} // namespace wr
