// The Window: the payload of the global object itself (quickjs-ng change 6 makes the global an instance of its class).
#pragma once

#include <cstdint>
#include <variant>
#include <vector>

#include "Generated/Bindings.h"
#include "Sources/Events/EventTarget.h"

namespace wr {

class Document;
class Location;
class Crypto;
class Navigator;
class Performance;
class TelegramWidget;

class CSSStyleDeclaration;
class Element;
class MediaQueryList;
class ResizeObserver;
class Storage;
class IntersectionObserver;

class Window : public EventTarget {
public:
    Window() = default;

    // Window
    Window* window(JSContext*) { return this; }
    Window* self(JSContext*) { return this; }
    Document* document(JSContext* ctx);
    Location* location(JSContext* ctx);
    Window* frames(JSContext*) { return this; }
    uint32_t length(JSContext*) { return 0; }
    Window* top(JSContext*) { return this; }
    Value opener(JSContext* ctx) { return Value::adopt(ctx, JS_NULL); }
    Window* parent(JSContext*) { return this; }
    // WindowOrWorkerGlobalScope
    Performance* performance(JSContext* ctx);
    /// CSSOM View (V3 plan, Task 3; Sources/DOM/Geometry.cpp): the layout width and the document's height, as a widget
    /// has no viewport of its own.
    int32_t innerWidth(JSContext* ctx);
    int32_t innerHeight(JSContext* ctx);
    /// The scale the widget is drawn at (RenderOptions::pixelSnapScale, the screen's; 1 before a render exists). Read
    /// without a layout: it is the host's, not the document's.
    double devicePixelRatio(JSContext* ctx);
    /// CSSOM's getComputedStyle (V3 plan, Task 4; Sources/DOM/StyleDeclaration.cpp): a new, read-only declaration whose
    /// values are computed at every read.
    Ref<CSSStyleDeclaration> getComputedStyle(JSContext* ctx, Element* element, std::optional<String> pseudoElt);
    /// CSSOM View's matchMedia (V3b plan, Task 1; Sources/DOM/MediaQueries.cpp): a new list for `query`.
    Ref<MediaQueryList> matchMedia(JSContext* ctx, String query);
    /// CSSOM View "evaluate media queries and report changes", which the event loop runs after a task's or a frame's
    /// microtasks: every held list (one with a change listener) whose answer differs from the last report's gets a
    /// `change`, oldest first; the render tree then keeps the features the report saw. Runs script.
    void reportMediaChanges(JSContext* ctx);
    /// A list with a change listener is held, counted and traced, until its last one goes.
    void holdMediaQueryList(JSContext* ctx, MediaQueryList& list);
    void releaseMediaQueryList(JSContext* ctx, MediaQueryList& list);
    /// Resize Observer and Intersection Observer (V3b plan, Tasks 2 and 3): an observer that observes something is held,
    /// counted and traced, until it observes nothing.
    void holdObserver(JSContext* ctx, PlatformObject& observer);
    void releaseObserver(JSContext* ctx, PlatformObject& observer);
    /// Resize Observer's steps, for EventLoop::deliverResizeObservations (Sources/DOM/ResizeObserver.cpp).
    bool gatherResizeObservations(JSContext* ctx);
    void broadcastResizeObservations(JSContext* ctx);
    void reportResizeObserverLoop(JSContext* ctx);
    /// Intersection Observer's update steps, after the resize observations (Sources/DOM/IntersectionObserver.cpp): queues
    /// the entries and, once, the task that notifies the observers.
    void updateIntersectionObservations(JSContext* ctx);
    void notifyIntersectionObservers(JSContext* ctx);
    /// HTML: queue a microtask that invokes `callback` with this undefined, reporting an exception (the checkpoint
    /// reports a job's exception).
    void queueMicrotask(JSContext* ctx, Callback callback);
    /// HTML: report the exception `e` (an ErrorEvent at the window, then the host).
    void reportError(JSContext* ctx, Value e);
    // WindowOrWorkerGlobalScope timers (Task 10)
    int32_t setTimeout(JSContext* ctx, std::variant<String, Callback> handler, int32_t timeout, std::vector<Value> arguments);
    int32_t setInterval(JSContext* ctx, std::variant<String, Callback> handler, int32_t timeout, std::vector<Value> arguments);
    void clearTimeout(JSContext* ctx, int32_t id);
    void clearInterval(JSContext* ctx, int32_t id);
    // The bridge (M1d plan, Task 4; telegram.webidl): made on first read, counted, traced.
    wr::TelegramWidget* TelegramWidget(JSContext* ctx);
    Navigator* navigator(JSContext* ctx);
    /// HTML's open() without browsing contexts: still openLink's path (V2a Task 5 adds the policy); returns null (SDK v1
    /// §2.5).
    Value open(JSContext* ctx, String url, String target, String features);
    /// HTML's simple dialogs, inert (SDK v1 §2.10): no dialog, nothing to the host; confirm() answers no, prompt() null.
    void alert(JSContext* ctx, String message) {}
    bool confirm(JSContext* ctx, String message) { return false; }
    std::optional<String> prompt(JSContext* ctx, String message, String defaultValue) { return std::nullopt; }
    /// SDK v1 §2.10 (Sources/Host/Inert.cpp): a promise rejected with NetworkDisabledError; throws it.
    Value fetch(JSContext* ctx, std::vector<Value> arguments);
    void importScripts(JSContext* ctx, std::vector<Value> urls);
    /// Web Storage (V2a plan, Task 2; Sources/Host/Storage.cpp): [SameObject], made at the first read.
    Storage* localStorage(JSContext* ctx);
    Storage* sessionStorage(JSContext* ctx);
    /// HTML's structuredClone (V5a plan, Task 4; Sources/Host/StructuredClone.cpp); a non-empty transfer list is a
    /// DataCloneError.
    Value structuredClone(JSContext* ctx, Value value, std::optional<Value> options);
    /// HTML's Base64 utility methods (V5a plan, Task 2; Sources/Host/Base64.cpp).
    String btoa(JSContext* ctx, String data);
    String atob(JSContext* ctx, String data);
    /// Web Crypto (V5a plan, Task 1; Sources/Host/Crypto.cpp): [SameObject], made at the first read.
    Crypto* crypto(JSContext* ctx);
    /// The end of a task (the event loop): each area that changed is committed to the host (SDK v1 §2.8).
    void commitStorage(JSContext* ctx);
    // AnimationFrameProvider (Task 11)
    uint32_t requestAnimationFrame(JSContext* ctx, Callback callback);
    void cancelAnimationFrame(JSContext* ctx, uint32_t handle);

    /// The window ends an event path.
    EventTarget* getTheParent(JSContext*, Event&) override { return nullptr; }
    /// DOM "default passive value": touch and wheel listeners on the window.
    bool defaultPassive(JSContext* ctx, JSAtom type) override;

    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

private:
    // [SameObject]-like: made on first read, counted, traced.
    Held m_location;
    Held m_performance;
    Held m_telegramWidget;
    Held m_navigator;
    Held m_localStorage;
    Held m_sessionStorage;
    Held m_crypto;
    /// The held observers of class T, oldest first, each retained for the caller.
    template <class T>
    std::vector<Ref<T>> heldObservers(JSContext* ctx) const {
        std::vector<Ref<T>> out;
        if (m_observers) {
            for (const Held& held : *m_observers) {
                if (T* observer = dynamic_cast<T*>(payloadOfKnown(held.value))) {
                    out.push_back(Ref<T>::retain(ctx, observer));
                }
            }
        }
        return out;
    }
    /// The observers holdObserver holds; made on first use.
    Vector<Held>* m_observers = nullptr;
    bool m_intersectionTaskQueued = false;
    /// The lists holdMediaQueryList holds; made on first use.
    Vector<Held>* m_heldMediaQueryLists = nullptr;
    uint64_t m_nextMediaQueryList = 0;
    bool m_mediaQueryListsMade = false;
};

} // namespace wr
