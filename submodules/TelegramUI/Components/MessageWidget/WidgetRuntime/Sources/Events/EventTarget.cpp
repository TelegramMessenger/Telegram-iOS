#include "Sources/Events/EventTarget.h"

#include <memory>
#include <new>

#include "Generated/Bindings.h"
#include "Sources/DOM/DOMState.h"
#include "Sources/Events/Dispatch.h"
#include "Sources/Events/Event.h"
#include "Sources/Events/EventHandlers.h"

namespace wr {

namespace {

bool sameObject(JSValueConst a, JSValueConst b) {
    return JS_IsObject(a) && JS_IsObject(b) && JS_VALUE_GET_PTR(a) == JS_VALUE_GET_PTR(b);
}

bool matches(const EventListener& l, JSAtom type, JSValueConst callback, bool capture) {
    return l.type.atom == type && l.capture == capture && sameObject(l.callback.get(), callback);
}

} // namespace

ListenerRef::~ListenerRef() {
    if (!m_listener || --m_listener->refs > 0) {
        return;
    }
    m_listener->type.clear(m_rt);
    m_listener->callback.clear(m_rt);
    m_listener->~EventListener();
    js_free_rt(m_rt, m_listener);
}

Ref<EventTarget> EventTarget::construct(JSContext* ctx) {
    return create<EventTarget>(ctx, idl::kEventTarget);
}

Vector<ListenerRef>& EventTarget::ensureListeners(JSContext* ctx) {
    if (!m_listeners) {
        void* memory = js_malloc(ctx, sizeof(Vector<ListenerRef>));
        if (!memory) {
            throw Thrown{};
        }
        m_listeners = new (memory) Vector<ListenerRef>(JSAllocator<ListenerRef>(JS_GetRuntime(ctx)));
    }
    return *m_listeners;
}

EventHandlerMap& EventTarget::ensureEventHandlers(JSContext* ctx) {
    if (!m_eventHandlers) {
        void* memory = js_malloc(ctx, sizeof(EventHandlerMap));
        if (!memory) {
            throw Thrown{};
        }
        m_eventHandlers = new (memory) EventHandlerMap(JS_GetRuntime(ctx));
    }
    return *m_eventHandlers;
}

void EventTarget::addEventListener(JSContext* ctx, String type, std::optional<CallbackInterface> callback, std::variant<idl::AddEventListenerOptions, bool> options) {
    // DOM "flatten more".
    bool capture = false;
    std::optional<bool> passive;
    bool once = false;
    if (const bool* flag = std::get_if<bool>(&options)) {
        capture = *flag;
    } else {
        const idl::AddEventListenerOptions& o = std::get<idl::AddEventListenerOptions>(options);
        capture = o.capture;
        passive = o.passive;
        once = o.once;
    }
    if (!callback) {
        return;
    }
    Atom atom = Atom::fromString(ctx, type);
    this->addListener(ctx, atom.get(), callback->get(), capture, passive, once);
}

void EventTarget::removeEventListener(JSContext* ctx, String type, std::optional<CallbackInterface> callback, std::variant<idl::EventListenerOptions, bool> options) {
    bool capture = std::holds_alternative<bool>(options) ? std::get<bool>(options) : std::get<idl::EventListenerOptions>(options).capture;
    if (!callback || !m_listeners) {
        return;
    }
    Atom atom = Atom::fromString(ctx, type);
    this->removeListener(ctx, atom.get(), callback->get(), capture);
}

void EventTarget::addListener(JSContext* ctx, JSAtom type, JSValueConst callback, bool capture, std::optional<bool> passive, bool once) {
    bool isPassive = passive ? *passive : this->defaultPassive(ctx, type);
    Vector<ListenerRef>& list = this->ensureListeners(ctx);
    for (const ListenerRef& l : list) {
        if (matches(*l, type, callback, capture)) {
            return;
        }
    }
    // Before the listener is made, so every listener in a list has its type noted (a failure past this point leaves a
    // noted type without a listener, which the never-shrinking set allows anyway).
    if (DOMState* dom = DOMState::find(ctx)) {
        dom->listenedTypes().note(ctx, type);
    }
    JSRuntime* rt = JS_GetRuntime(ctx);
    void* memory = js_malloc(ctx, sizeof(EventListener));
    if (!memory) {
        throw Thrown{};
    }
    ListenerRef ref(rt, new (memory) EventListener());
    ref->type.set(rt, JS_DupAtom(ctx, type));
    ref->callback.set(rt, JS_DupValue(ctx, callback));
    ref->capture = capture;
    ref->passive = isPassive;
    ref->once = once;
    list.push_back(std::move(ref));
    this->listenersChanged(ctx);
}

void EventTarget::removeListener(JSContext* ctx, JSAtom type, JSValueConst callback, bool capture) {
    if (!m_listeners) {
        return;
    }
    for (size_t i = 0; i < m_listeners->size(); i++) {
        if (matches(*(*m_listeners)[i], type, callback, capture)) {
            this->removeListenerEntry(ctx, *(*m_listeners)[i]);
            return;
        }
    }
}

void EventTarget::removeListenerEntry(JSContext* ctx, EventListener& listener) {
    listener.removed = true;
    if (!m_listeners) {
        return;
    }
    for (size_t i = 0; i < m_listeners->size(); i++) {
        if ((*m_listeners)[i].get() == &listener) {
            // The list's hold goes; the listener itself stays while a dispatch clone holds it.
            m_listeners->erase(m_listeners->begin() + ptrdiff_t(i));
            this->listenersChanged(ctx);
            return;
        }
    }
}

bool EventTarget::dispatchEvent(JSContext* ctx, Event* event) {
    if (event->dispatching() || !event->initialized()) {
        throw DOMError{"InvalidStateError", "The event is already being dispatched or has not been initialized."};
    }
    event->setIsTrusted(false);
    return dispatch(ctx, *event, *this);
}

bool EventTarget::hasListenersFor(JSContext* ctx, JSAtom type) const {
    if (!m_listeners) {
        return false;
    }
    for (const ListenerRef& l : *m_listeners) {
        if (l->type.atom == type) {
            return true;
        }
    }
    return false;
}

void EventTarget::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    if (m_listeners) {
        for (const ListenerRef& l : *m_listeners) {
            l->callback.mark(rt, mark);
        }
    }
    if (m_eventHandlers) {
        m_eventHandlers->trace(rt, mark);
    }
}

void EventTarget::dispose(JSRuntime* rt) {
    if (m_listeners) {
        std::destroy_at(m_listeners);
        js_free_rt(rt, m_listeners);
        m_listeners = nullptr;
    }
    if (m_eventHandlers) {
        m_eventHandlers->dispose(rt);
        std::destroy_at(m_eventHandlers);
        js_free_rt(rt, m_eventHandlers);
        m_eventHandlers = nullptr;
    }
}

} // namespace wr
