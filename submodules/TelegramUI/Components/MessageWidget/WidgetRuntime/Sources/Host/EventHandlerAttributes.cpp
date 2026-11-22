#include "Sources/Host/EventHandlerAttributes.h"

#include <algorithm>
#include <iterator>
#include <optional>
#include <string>
#include <string_view>

#include "Generated/Bindings.h"
#include "Sources/DOM/DOM.h"
#include "Sources/Host/HostState.h"
#include "Sources/Host/Window.h"
#include "Sources/Support/Callbacks.h"

namespace wr {

namespace {

// GlobalEventHandlers as html.webidl binds it, with Pointer Events' and Touch Events' partials. A test
// (testHandlerNamesMatchTheIDL) keeps the tables and the IDL equal.
constexpr const char* kGlobalTypes[] = {
    "abort", "auxclick", "beforeinput", "beforetoggle", "blur", "cancel", "change", "click", "close", "command",
    "contextmenu", "copy", "cut", "dblclick", "error", "focus", "input", "invalid", "keydown", "keypress", "keyup",
    "load", "mousedown", "mouseenter", "mouseleave", "mousemove", "mouseout", "mouseover", "mouseup", "paste", "reset",
    "resize", "scroll", "scrollend", "select", "submit", "toggle", "webkitanimationend", "webkitanimationiteration",
    "webkitanimationstart", "webkittransitionend", "wheel",
    "gotpointercapture", "lostpointercapture", "pointerdown", "pointermove", "pointerrawupdate", "pointerup",
    "pointercancel", "pointerover", "pointerout", "pointerenter", "pointerleave",
    "touchstart", "touchend", "touchmove", "touchcancel",
    // CSS Animations 1 and CSS Transitions 1 (V5f plan, Task 3).
    "animationstart", "animationiteration", "animationend", "animationcancel", "transitionrun", "transitionstart",
    "transitionend", "transitioncancel",
};
// The window-reflecting body element event handler set: these GlobalEventHandlers members, and WindowEventHandlers.
constexpr const char* kBodyReflectedGlobalTypes[] = {"blur", "error", "focus", "load", "resize", "scroll"};
constexpr const char* kWindowTypes[] = {"pagehide", "pageshow", "rejectionhandled", "unhandledrejection"};

bool isBodyReflectedGlobalType(const char* type) {
    return std::find_if(std::begin(kBodyReflectedGlobalTypes), std::end(kBodyReflectedGlobalTypes),
                        [&](const char* t) { return std::string_view(t) == type; }) != std::end(kBodyReflectedGlobalTypes);
}

} // namespace

EventHandlerAttributes::EventHandlerAttributes(JSContext* ctx)
    : m_ctx(ctx),
      m_dom(DOMState::of(ctx)),
      m_names(JSAllocator<HandlerName>(JS_GetRuntime(ctx))),
      m_windowReflecting(JSAllocator<JSAtom>(JS_GetRuntime(ctx))) {
    // Reserved first, so no push below allocates: once an atom is made, only the registration can still fail.
    m_names.reserve(std::size(kGlobalTypes) + std::size(kWindowTypes));
    m_windowReflecting.reserve(std::size(kBodyReflectedGlobalTypes) + std::size(kWindowTypes));
    auto add = [&](const char* type, bool global) {
        std::string attribute = std::string("on") + type;
        JSAtom typeAtom = JS_NewAtom(ctx, type);
        bool reflecting = !global || isBodyReflectedGlobalType(type);
        m_names.push_back(HandlerName{JS_NewAtom(ctx, attribute.c_str()), typeAtom, global, reflecting});
        if (reflecting) {
            m_windowReflecting.push_back(typeAtom);
        }
    };
    for (const char* type : kGlobalTypes) {
        add(type, true);
    }
    for (const char* type : kWindowTypes) {
        add(type, false);
    }
    std::sort(m_names.begin(), m_names.end(), [](const HandlerName& a, const HandlerName& b) { return a.attribute < b.attribute; });
    std::sort(m_windowReflecting.begin(), m_windowReflecting.end());
    m_error = JS_NewAtom(ctx, "error");
    try {
        m_dom.attributeListeners().push_back(this);
    } catch (...) {
        this->releaseAtoms();
        throw;
    }
}

EventHandlerAttributes::~EventHandlerAttributes() {
    auto& listeners = m_dom.attributeListeners();
    listeners.erase(std::remove(listeners.begin(), listeners.end(), this), listeners.end());
    this->releaseAtoms();
}

void EventHandlerAttributes::releaseAtoms() {
    for (const HandlerName& name : m_names) {
        JS_FreeAtom(m_ctx, name.attribute);
        JS_FreeAtom(m_ctx, name.type);
    }
    m_names.clear();
    m_windowReflecting.clear();
    JS_FreeAtom(m_ctx, m_error);
    m_error = JS_ATOM_NULL;
}

const EventHandlerAttributes::HandlerName* EventHandlerAttributes::lookup(JSAtom attribute) const {
    auto it = std::lower_bound(m_names.begin(), m_names.end(), attribute, [](const HandlerName& n, JSAtom a) { return n.attribute < a; });
    return it != m_names.end() && it->attribute == attribute ? &*it : nullptr;
}

bool EventHandlerAttributes::isWindowReflecting(JSContext* ctx, JSAtom type) const {
    return std::binary_search(m_windowReflecting.begin(), m_windowReflecting.end(), type);
}

void EventHandlerAttributes::attributeChanged(Element& element, JSAtom localName, Namespace ns) {
    JSContext* ctx = m_ctx;
    try {
        // "If namespace is not null, or localName is not the name of an event handler content attribute on element,
        // then return."
        if (ns != Namespace::None) {
            return;
        }
        const HandlerName* name = this->lookup(localName);
        if (!name || (element.ns() != Namespace::HTML && element.ns() != Namespace::SVG)) {
            return;
        }
        DOMState& dom = DOMState::of(ctx);
        bool bodyOrFrameset = element.hasHTMLName(dom.name(Name::body)) || element.hasHTMLName(dom.name(Name::frameset));
        if (!name->global && !bodyOrFrameset) {
            return;   // a WindowEventHandlers name on another element is an ordinary attribute
        }
        // On a body or frameset, the window-reflecting set is the window's (none outside the window's document). Any
        // other element's handler is its own in any document; it compiles once the element is in the window's.
        EventTarget* owner = eventHandlerOwner(ctx, element, name->type);
        if (!owner) {
            return;
        }
        // The null-namespace attribute's value after the change: none when it was removed.
        std::optional<String> value = element.attributeValue(ctx, localName);
        if (!value) {
            clearEventHandler(ctx, *owner, name->type);
        } else {
            setEventHandlerBody(ctx, *owner, name->type, *value, element);
        }
    } catch (...) {
        // Thrown (QuickJS out of memory), std::bad_alloc or anything else: latched, then Aborted unwinds the mutation.
        abortForCaughtException(ctx);
    }
}

bool isWindowReflectingEventHandler(JSContext* ctx, JSAtom type) {
    if (HostState* host = HostState::find(ctx)) {
        return host->eventHandlerAttributes().isWindowReflecting(ctx, type);
    }
    // No host state, so no table of atoms: the type's name against the table's (ten short names).
    String name = String::fromAtom(ctx, type);
    for (const char* t : kBodyReflectedGlobalTypes) {
        if (name.equalsASCII(t)) {
            return true;
        }
    }
    for (const char* t : kWindowTypes) {
        if (name.equalsASCII(t)) {
            return true;
        }
    }
    return false;
}

} // namespace wr
