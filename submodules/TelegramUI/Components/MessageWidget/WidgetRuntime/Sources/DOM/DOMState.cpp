#include "Sources/DOM/DOMState.h"

#include <utility>

#include "Generated/Bindings.h"
#include "Sources/DOM/DOM.h"

namespace wr {

static const char* const kNameStrings[] = {
    "id", "class", "slot", "name", "style", "src", "href", "type", "value", "checked", "selected", "disabled", "lang", "dir", "title", "hidden",
    "html", "head", "body", "template", "script", "svg", "math", "input", "option", "select", "textarea", "a", "area", "link",
    "frameset", "placeholder", "required", "readonly", "button", "optgroup", "fieldset", "xmlns", "*", "touchstart", "touchmove", "wheel", "mousewheel",
    "load", "animationend", "animationiteration", "animationstart", "transitionend", "webkitAnimationEnd", "webkitAnimationIteration",
    "webkitAnimationStart", "webkitTransitionEnd",
    "async", "defer", "nomodule", "language", "event", "for", "canvas", "width", "height", "img",
};
static_assert(sizeof(kNameStrings) / sizeof(kNameStrings[0]) == size_t(Name::Count));

// HTML elements with an interface of their own in IDL/html.webidl.
static const std::pair<const char*, uint16_t> kHTMLInterfaces[] = {
    {"html", idl::kHTMLHtmlElement}, {"head", idl::kHTMLHeadElement}, {"body", idl::kHTMLBodyElement},
    {"div", idl::kHTMLDivElement}, {"span", idl::kHTMLSpanElement}, {"p", idl::kHTMLParagraphElement},
    {"a", idl::kHTMLAnchorElement}, {"template", idl::kHTMLTemplateElement}, {"script", idl::kHTMLScriptElement},
    {"style", idl::kHTMLStyleElement}, {"input", idl::kHTMLInputElement}, {"button", idl::kHTMLButtonElement},
    {"label", idl::kHTMLLabelElement}, {"details", idl::kHTMLDetailsElement}, {"form", idl::kHTMLFormElement},
    {"canvas", idl::kHTMLCanvasElement}, {"img", idl::kHTMLImageElement}, {"dialog", idl::kHTMLDialogElement},
};

// Every element the HTML standard defines (https://html.spec.whatwg.org/multipage/indices.html#elements-3), plus the
// obsolete ones it still maps to HTMLElement or a legacy interface: anything else is HTMLUnknownElement.
static const char* const kKnownHTMLElements[] = {
    "a", "abbr", "address", "area", "article", "aside", "audio", "b", "base", "bdi", "bdo", "blockquote", "body", "br",
    "button", "canvas", "caption", "cite", "code", "col", "colgroup", "data", "datalist", "dd", "del", "details", "dfn",
    "dialog", "div", "dl", "dt", "em", "embed", "fieldset", "figcaption", "figure", "footer", "form", "h1", "h2", "h3",
    "h4", "h5", "h6", "head", "header", "hgroup", "hr", "html", "i", "iframe", "img", "input", "ins", "kbd", "label",
    "legend", "li", "link", "main", "map", "mark", "menu", "meta", "meter", "nav", "noscript", "object", "ol",
    "optgroup", "option", "output", "p", "picture", "pre", "progress", "q", "rp", "rt", "ruby", "s", "samp", "script",
    "search", "section", "select", "selectedcontent", "slot", "small", "source", "span", "strong", "style", "sub",
    "summary", "sup", "table", "tbody", "td", "template", "textarea", "tfoot", "th", "thead", "time", "title", "tr",
    "track", "u", "ul", "var", "video", "wbr",
    // Obsolete but still mapped: HTMLElement by HTML's "element interface" (acronym … tt), or a legacy interface of
    // its own (dir, font, frame, frameset, listing, marquee, param, xmp). Not here, so HTMLUnknownElement: the
    // algorithm's own list (applet, bgsound, blink, isindex, keygen, multicol, nextid, spacer), and menuitem, which
    // HTML no longer defines an interface for.
    "acronym", "basefont", "big", "center", "dir", "font", "frame", "frameset", "listing", "marquee", "nobr",
    "noembed", "noframes", "param", "plaintext", "rb", "rtc", "strike", "tt", "xmp",
};

// :checked: a checkbox or radio input with the checked attribute (its default checkedness), or an option with the
// selected attribute (its default selectedness).
bool ElementState::checked(JSContext* ctx, Element& element) {
    DOMState& state = DOMState::of(ctx);
    if (element.hasHTMLName(state.name(Name::option))) {
        return element.hasAttributeAtom(ctx, state.name(Name::selected));
    }
    if (!element.hasHTMLName(state.name(Name::input)) || !element.hasAttributeAtom(ctx, state.name(Name::checked))) {
        return false;
    }
    std::optional<String> type = element.attributeValue(ctx, state.name(Name::type));
    return type && (type->equalsIgnoringASCIICase("checkbox") || type->equalsIgnoringASCIICase("radio"));
}

static bool isFormControlWithDisabled(DOMState& state, Element& element) {
    for (Name n : {Name::button, Name::input, Name::select, Name::textarea, Name::optgroup, Name::option, Name::fieldset}) {
        if (element.hasHTMLName(state.name(n))) {
            return true;
        }
    }
    return false;
}

bool ElementState::disabled(JSContext* ctx, Element& element) {
    DOMState& state = DOMState::of(ctx);
    return isFormControlWithDisabled(state, element) && element.hasAttributeAtom(ctx, state.name(Name::disabled));
}

bool ElementState::placeholderShown(JSContext* ctx, Element& element) {
    DOMState& state = DOMState::of(ctx);
    if (!element.hasHTMLName(state.name(Name::input)) && !element.hasHTMLName(state.name(Name::textarea))) {
        return false;
    }
    if (!element.hasAttributeAtom(ctx, state.name(Name::placeholder))) {
        return false;
    }
    if (element.hasHTMLName(state.name(Name::input))) {
        std::optional<String> value = element.attributeValue(ctx, state.name(Name::value));
        return !value || value->empty();
    }
    return element.childCount() == 0;
}

DOMState::DOMState(JSContext* ctx) : m_ctx(ctx), m_listenedTypes(JS_GetRuntime(ctx)) {
    for (size_t i = 0; i < size_t(Name::Count); i++) {
        m_names[i] = JS_NewAtom(ctx, kNameStrings[i]);
    }
    for (const auto& [name, iface] : kHTMLInterfaces) {
        JSAtom a = JS_NewAtom(ctx, name);
        m_htmlInterfaces[a] = iface;
        m_heldAtoms.push_back(a);
    }
    for (const char* name : kKnownHTMLElements) {
        JSAtom a = JS_NewAtom(ctx, name);
        m_knownHTML[a] = true;
        m_heldAtoms.push_back(a);
    }
    static const char* const kVoidElements[] = {"area", "base", "basefont", "bgsound", "br", "col", "embed", "frame", "hr", "img",
                                                 "input", "keygen", "link", "meta", "param", "source", "track", "wbr"};
    static const char* const kRawTextElements[] = {"style", "script", "xmp", "iframe", "noembed", "noframes", "plaintext"};
    for (const char* name : kVoidElements) {
        JSAtom atom = JS_NewAtom(ctx, name);
        m_heldAtoms.push_back(atom);
        m_voidElements.insert(atom);
    }
    for (const char* name : kRawTextElements) {
        JSAtom atom = JS_NewAtom(ctx, name);
        m_heldAtoms.push_back(atom);
        m_rawTextElements.insert(atom);
    }
}

DOMState::~DOMState() {
    JS_FreeValue(m_ctx, m_documentValue);
    for (JSAtom a : m_names) {
        JS_FreeAtom(m_ctx, a);
    }
    for (JSAtom a : m_heldAtoms) {
        JS_FreeAtom(m_ctx, a);
    }
}

int DOMState::htmlInterface(JSAtom localName) const {
    auto it = m_htmlInterfaces.find(localName);
    return it == m_htmlInterfaces.end() ? -1 : int(it->second);
}

bool DOMState::isKnownHTMLElement(JSAtom localName) const {
    return m_knownHTML.count(localName) != 0;
}

Document& DOMState::document() const {
    if (!m_document) {
        throw TypeError{"no document"};
    }
    return *m_document;
}

void DOMState::setDocument(JSContext* ctx, Document& document) {
    JS_FreeValue(ctx, m_documentValue);
    m_documentValue = JS_DupValue(ctx, document.object());
    m_document = &document;
}

void installDOM(JSContext* ctx, Ref<Document> document) {
    Runtime& runtime = Runtime::from(ctx);
    if (!runtime.extension(ExtensionSlot::DOM)) {
        runtime.setExtension(ExtensionSlot::DOM, std::make_unique<DOMState>(ctx));
    }
    DOMState::of(ctx).setDocument(ctx, *document);
}

} // namespace wr
