// The DOM's per-runtime state: interned names, the element-state hook, the listened-types registry and the window's
// place in an event path.
#pragma once

#include <unordered_map>
#include <unordered_set>
#include <vector>

#include "Sources/Events/ListenedTypes.h"
#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/PlatformObject.h"
#include "Sources/Support/Values.h"

namespace wr {

class Document;
class Element;
class EventTarget;
class MutationListener;

/// Answers the state pseudo-classes and form state. M1a's defaults read attributes (M1a plan, ruling 4); M1c's focus
/// model and M2's form state replace them. Selector matching calls these on views of the tree: an implementation must
/// not run script or change the tree.
class ElementState {
public:
    virtual ~ElementState() = default;
    virtual bool checked(JSContext* ctx, Element& element);
    virtual bool indeterminate(JSContext* ctx, Element& element) { return false; }
    /// :default: a checked-by-default checkbox or radio, a selected-by-default option.
    virtual bool isDefault(JSContext* ctx, Element& element) { return this->checked(ctx, element); }
    /// :disabled: a disabled attribute on button, input, select, textarea, optgroup, option or fieldset.
    virtual bool disabled(JSContext* ctx, Element& element);
    /// :placeholder-shown: an input or textarea with a placeholder and no value.
    virtual bool placeholderShown(JSContext* ctx, Element& element);
    virtual bool focused(JSContext* ctx, Element& element) { return false; }
    virtual bool focusWithin(JSContext* ctx, Element& element) { return false; }
    virtual bool focusVisible(JSContext* ctx, Element& element) { return false; }
    virtual bool hovered(JSContext* ctx, Element& element) { return false; }
    virtual bool active(JSContext* ctx, Element& element) { return false; }
};

enum class Name : uint8_t {
    id, class_, slot, name, style, src, href, type, value, checked, selected, disabled, lang, dir, title, hidden,
    html, head, body, template_, script, svg, math, input, option, select, textarea, a, area, link, frameset,
    placeholder, required, readonly, button, optgroup, fieldset, xmlns, star, touchstart, touchmove, wheel, mousewheel,
    load, animationend, animationiteration, animationstart, transitionend, webkitAnimationEnd, webkitAnimationIteration,
    webkitAnimationStart, webkitTransitionEnd,
    async, defer, nomodule, language, event, for_, canvas, width, height, img, Count
};

class DOMState : public RuntimeExtension {
public:
    explicit DOMState(JSContext* ctx);
    ~DOMState() override;
    static DOMState& of(JSContext* ctx) { return *static_cast<DOMState*>(Runtime::from(ctx).extension(ExtensionSlot::DOM)); }
    /// The DOM state, or nullptr in a runtime without the DOM (the generator's test table).
    static DOMState* find(JSContext* ctx) { return static_cast<DOMState*>(Runtime::from(ctx).extension(ExtensionSlot::DOM)); }

    /// The main document (installDOM): the one the Window shows and the node constructors use (DOM "the current global
    /// object's associated Document"). Throws TypeError before installDOM.
    Document& document() const;
    bool hasDocument() const { return m_document != nullptr; }
    void setDocument(JSContext* ctx, Document& document);

    JSAtom name(Name n) const { return m_names[size_t(n)]; }
    /// The interface of an HTML element by local name (atom), or -1 when the element has no interface of its own here.
    int htmlInterface(JSAtom localName) const;
    bool isKnownHTMLElement(JSAtom localName) const;
    /// HTML's void elements, as "serializes as void" lists them: serialized without children or an end tag.
    bool isVoidHTMLElement(JSAtom localName) const { return m_voidElements.count(localName) > 0; }
    /// Elements whose Text children serialize unescaped (style, script, xmp, iframe, noembed, noframes, plaintext).
    /// Not noscript: gumbo parses as with scripting off, so a noscript's content is markup, and serializing its
    /// text unescaped would not survive a round trip.
    bool hasRawTextChildren(JSAtom localName) const { return m_rawTextElements.count(localName) > 0; }

    ElementState* elementState() const { return m_elementState; }
    void setElementState(ElementState* state) { m_elementState = state ? state : &m_defaultState; }

    /// The event types any listener was added for (Sources/Events/ListenedTypes.h).
    ListenedTypes& listenedTypes() { return m_listenedTypes; }
    /// The main document's parent in an event path: the Window, once the host layer installed one (Task 8).
    EventTarget* windowTarget() const { return m_windowTarget; }
    void setWindowTarget(EventTarget* window) { m_windowTarget = window; }

    /// Told of every attribute change in every document of the runtime, after the document's own listeners: for
    /// attribute change steps that belong to an element whatever its document, as HTML's event handler content
    /// attributes do. Only attributeChanged is called. Not owned: a listener's owner adds it and takes it out before it
    /// goes.
    std::vector<MutationListener*>& attributeListeners() { return m_attributeListeners; }
    /// Calls `f` with each, by index over the live list, as Document::forEachMutationListener does.
    template <class F>
    void forEachAttributeListener(F&& f) {
        for (size_t i = 0; i < m_attributeListeners.size(); i++) {
            f(*m_attributeListeners[i]);
        }
    }

    /// True while boot parses the document into the main one (Boot.cpp, a DocumentParseScope): a parsed <img> then
    /// queues no load or error of its own, and fireParsedImageEvents fires it at the window's load, after the page's
    /// scripts added their listeners (V4 plan, Task 6). A fragment parse (innerHTML) is not a document parse.
    bool parsingDocument() const { return m_parsingDocument; }

    class DocumentParseScope {
    public:
        explicit DocumentParseScope(DOMState& state) : m_state(state) { m_state.m_parsingDocument = true; }
        ~DocumentParseScope() { m_state.m_parsingDocument = false; }
        DocumentParseScope(const DocumentParseScope&) = delete;
        DocumentParseScope& operator=(const DocumentParseScope&) = delete;

    private:
        DOMState& m_state;
    };

private:
    JSContext* m_ctx;
    Document* m_document = nullptr;
    bool m_parsingDocument = false;
    /// The reference behind m_document: an untraced root, released with the state (the document lives as long as the
    /// widget anyway).
    JSValue m_documentValue = JS_UNDEFINED;
    ListenedTypes m_listenedTypes;
    /// Not counted: the window is the global object, alive for the context's life, which outlives this state.
    EventTarget* m_windowTarget = nullptr;
    std::vector<MutationListener*> m_attributeListeners;
    JSAtom m_names[size_t(Name::Count)];
    std::unordered_map<JSAtom, uint16_t> m_htmlInterfaces;
    std::unordered_map<JSAtom, bool> m_knownHTML;
    std::unordered_set<JSAtom> m_voidElements;
    std::unordered_set<JSAtom> m_rawTextElements;
    /// The references behind the map keys: an atom stays a key only while it is held.
    std::vector<JSAtom> m_heldAtoms;
    ElementState m_defaultState;
    ElementState* m_elementState = &m_defaultState;
};

/// Makes the DOM state, with `document` as the main document. The global `document` is the Window's (installHost).
void installDOM(JSContext* ctx, Ref<Document> document);

} // namespace wr
