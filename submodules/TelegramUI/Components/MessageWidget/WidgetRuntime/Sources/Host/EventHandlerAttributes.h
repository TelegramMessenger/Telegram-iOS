// The attribute change steps of event handler content attributes: a MutationListener the DOM state tells of every
// document's attribute changes (a handler's body is the element's whatever its document), a native listener that runs
// no script, as Document's listeners must. It also holds the handler names the IDL binds, as atoms.
#pragma once

#include "Sources/DOM/Document.h"
#include "Sources/Support/Allocator.h"

namespace wr {

class DOMState;

class EventHandlerAttributes : public MutationListener {
public:
    /// Registers with the DOM state's attribute listeners; HostState makes it before the document is parsed.
    explicit EventHandlerAttributes(JSContext* ctx);
    ~EventHandlerAttributes() override;
    EventHandlerAttributes(const EventHandlerAttributes&) = delete;
    EventHandlerAttributes& operator=(const EventHandlerAttributes&) = delete;

    /// HTML's "event handler content attribute change steps". Inside a mutation, where it runs no script: a failure in
    /// it (out of memory) latches the stop and throws Aborted (Ruling R6), so the half-notified change is never
    /// observed.
    void attributeChanged(Element& element, JSAtom localName, Namespace ns) override;
    /// Whether `type` is in the window-reflecting body element event handler set.
    bool isWindowReflecting(JSContext* ctx, JSAtom type) const;
    JSAtom errorType() const { return m_error; }

private:
    struct HandlerName {
        JSAtom attribute;
        JSAtom type;
        /// A GlobalEventHandlers member: a content attribute of every HTML and SVG element.
        bool global;
        /// In the window-reflecting set: on a body or frameset, the window's.
        bool windowReflecting;
    };
    const HandlerName* lookup(JSAtom attribute) const;
    void releaseAtoms();

    JSContext* m_ctx;
    /// Outlives the host state, and so this listener (Runtime destroys the host slot first).
    DOMState& m_dom;
    /// Sorted by attribute atom.
    Vector<HandlerName> m_names;
    /// Sorted.
    Vector<JSAtom> m_windowReflecting;
    JSAtom m_error = JS_ATOM_NULL;
};

/// Whether `type` is the event type of a handler in HTML's window-reflecting body element event handler set (the
/// WindowEventHandlers members and six GlobalEventHandlers ones). The host state's table answers; a runtime without
/// one (DOM-only) compares the type's name with the table's names.
bool isWindowReflectingEventHandler(JSContext* ctx, JSAtom type);

} // namespace wr
