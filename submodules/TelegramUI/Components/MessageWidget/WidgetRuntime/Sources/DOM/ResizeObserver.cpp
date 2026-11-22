#include "Sources/DOM/ResizeObserver.h"

#include <algorithm>
#include <optional>

#include "Sources/DOM/DOM.h"
#include "Sources/Events/Dispatch.h"
#include "Sources/Events/Event.h"
#include "Sources/Host/ErrorReporting.h"
#include "Sources/Host/HostState.h"
#include "Sources/Host/Window.h"
#include "Sources/Render/RenderTree.h"

namespace wr {

namespace {

/// The sizes Resize Observer reads of an element: its content box (its padding edge's offset, its width and height)
/// and its border box. A box that is not rendered, or an inline one, is 0×0 (Resize Observer, "calculate box size").
struct Sizes {
    double contentX = 0, contentY = 0, contentWidth = 0, contentHeight = 0;
    double borderWidth = 0, borderHeight = 0;
};

Sizes sizesOf(const RenderTree& render, const Element& element) {
    Sizes sizes;
    std::optional<RenderTree::BoxMetrics> metrics = render.boxMetrics(element);
    std::optional<RenderBox> box = render.borderBox(element);
    if (!metrics || !box || metrics->inlineLevel) {
        return sizes;
    }
    sizes.borderWidth = box->width;
    sizes.borderHeight = box->height;
    sizes.contentX = metrics->paddingLeft;
    sizes.contentY = metrics->paddingTop;
    sizes.contentWidth = std::max(0.0, box->width - metrics->borderLeft - metrics->borderRight - metrics->paddingLeft -
                                           metrics->paddingRight);
    sizes.contentHeight = std::max(0.0, box->height - metrics->borderTop - metrics->borderBottom - metrics->paddingTop -
                                            metrics->paddingBottom);
    return sizes;
}

/// The size an observation compares, per its box option (writing mode horizontal: inline is the width).
std::pair<double, double> observed(const Sizes& sizes, bool border) {
    return border ? std::make_pair(sizes.borderWidth, sizes.borderHeight) : std::make_pair(sizes.contentWidth, sizes.contentHeight);
}

/// A frozen array of one ResizeObserverSize.
JSValue frozenSizes(JSContext* ctx, double inlineSize, double blockSize) {
    Ref<ResizeObserverSize> size = create<ResizeObserverSize>(ctx, idl::kResizeObserverSize, inlineSize, blockSize);
    JSValue array = JS_NewArray(ctx);
    if (JS_IsException(array)) {
        throw Thrown{};
    }
    if (JS_SetPropertyUint32(ctx, array, 0, size.release()) < 0 || JS_FreezeObject(ctx, array) < 0) {
        JS_FreeValue(ctx, array);
        throw Thrown{};
    }
    return array;
}

} // namespace

// MARK: ResizeObserverEntry

Element* ResizeObserverEntry::target(JSContext*) {
    return static_cast<Element*>(payloadOfKnown(m_target.value));
}

DOMRectReadOnly* ResizeObserverEntry::contentRect(JSContext*) {
    return static_cast<DOMRectReadOnly*>(payloadOfKnown(m_contentRect.value));
}

void ResizeObserverEntry::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    m_target.mark(rt, mark);
    m_contentRect.mark(rt, mark);
    m_borderBoxSize.mark(rt, mark);
    m_contentBoxSize.mark(rt, mark);
    m_deviceBoxSize.mark(rt, mark);
}

void ResizeObserverEntry::dispose(JSRuntime* rt) {
    m_target.clear(rt);
    m_contentRect.clear(rt);
    m_borderBoxSize.clear(rt);
    m_contentBoxSize.clear(rt);
    m_deviceBoxSize.clear(rt);
}

// MARK: ResizeObserver

Ref<ResizeObserver> ResizeObserver::construct(JSContext* ctx, Callback callback) {
    Ref<ResizeObserver> observer = create<ResizeObserver>(ctx, idl::kResizeObserver, ctx);
    observer->m_callback.set(JS_GetRuntime(ctx), JS_DupValue(ctx, callback.get()));
    return observer;
}

void ResizeObserver::observe(JSContext* ctx, Element* target, idl::ResizeObserverOptions options) {
    const Box box = options.box.equalsASCII("border-box")                 ? Box::Border
                    : options.box.equalsASCII("device-pixel-content-box") ? Box::DevicePixel
                                                                         : Box::Content;
    // Observing a target again replaces its observation (its box option, a fresh last size).
    this->unobserve(ctx, target);
    const bool wasEmpty = m_observations.empty();
    Observation observation;
    observation.target.value = target->newRef(ctx);
    observation.box = box;
    m_observations.push_back(std::move(observation));
    if (wasEmpty) {
        HostState::of(ctx).window().holdObserver(ctx, *this);
    }
}

void ResizeObserver::unobserve(JSContext* ctx, Element* target) {
    JSRuntime* rt = JS_GetRuntime(ctx);
    for (size_t i = 0; i < m_observations.size(); i++) {
        if (payloadOfKnown(m_observations[i].target.value) == target) {
            m_observations[i].target.clear(rt);
            m_observations.erase(m_observations.begin() + ptrdiff_t(i));
            if (m_observations.empty()) {
                HostState::of(ctx).window().releaseObserver(ctx, *this);
            }
            return;
        }
    }
}

void ResizeObserver::disconnect(JSContext* ctx) {
    if (m_observations.empty()) {
        return;
    }
    JSRuntime* rt = JS_GetRuntime(ctx);
    for (Observation& observation : m_observations) {
        observation.target.clear(rt);
    }
    m_observations.clear();
    HostState::of(ctx).window().releaseObserver(ctx, *this);
}

bool ResizeObserver::gather(JSContext* ctx, const RenderTree& render) {
    bool any = false;
    for (Observation& observation : m_observations) {
        const Sizes sizes = sizesOf(render, *static_cast<Element*>(payloadOfKnown(observation.target.value)));
        const auto [inlineSize, blockSize] = observed(sizes, observation.box == Box::Border);
        observation.active = inlineSize != observation.lastInline || blockSize != observation.lastBlock;
        any = any || observation.active;
    }
    return any;
}

void ResizeObserver::broadcast(JSContext* ctx, const RenderTree& render) {
    // The entries first: the callback may observe, unobserve or disconnect.
    JSValue entries = JS_NewArray(ctx);
    if (JS_IsException(entries)) {
        throw Thrown{};
    }
    Value held = Value::adopt(ctx, entries);
    uint32_t count = 0;
    for (Observation& observation : m_observations) {
        if (!observation.active) {
            continue;
        }
        observation.active = false;
        Element& target = *static_cast<Element*>(payloadOfKnown(observation.target.value));
        const Sizes sizes = sizesOf(render, target);
        const auto [inlineSize, blockSize] = observed(sizes, observation.box == Box::Border);
        observation.lastInline = inlineSize;
        observation.lastBlock = blockSize;
        Ref<ResizeObserverEntry> entry = create<ResizeObserverEntry>(ctx, idl::kResizeObserverEntry);
        JSRuntime* rt = JS_GetRuntime(ctx);
        entry->m_target.set(rt, target.newRef(ctx));
        entry->m_contentRect.set(rt, DOMRectReadOnly::make(ctx, RenderBox{sizes.contentX, sizes.contentY, sizes.contentWidth, sizes.contentHeight}).release());
        entry->m_borderBoxSize.set(rt, frozenSizes(ctx, sizes.borderWidth, sizes.borderHeight));
        entry->m_contentBoxSize.set(rt, frozenSizes(ctx, sizes.contentWidth, sizes.contentHeight));
        entry->m_deviceBoxSize.set(rt, frozenSizes(ctx, sizes.contentWidth, sizes.contentHeight));
        if (JS_SetPropertyUint32(ctx, held.get(), count++, entry.release()) < 0) {
            throw Thrown{};
        }
    }
    if (count == 0) {
        return;
    }
    Value callback = Value::dup(ctx, m_callback.value);
    Value self = Value::adopt(ctx, this->newRef(ctx));
    JSValueConst argv[2] = {held.get(), self.get()};
    invokeWithReport(ctx, callback.get(), self.get(), 2, argv);
}

void ResizeObserver::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    m_callback.mark(rt, mark);
    for (const Observation& observation : m_observations) {
        observation.target.mark(rt, mark);
    }
}

void ResizeObserver::dispose(JSRuntime* rt) {
    m_callback.clear(rt);
    for (Observation& observation : m_observations) {
        observation.target.clear(rt);
    }
    m_observations.clear();
}

// MARK: Window

bool Window::gatherResizeObservations(JSContext* ctx) {
    RenderTree* render = HostState::of(ctx).render();
    if (!render || !m_observers) {
        return false;
    }
    bool any = false;
    for (const Ref<ResizeObserver>& observer : this->heldObservers<ResizeObserver>(ctx)) {
        any = observer->gather(ctx, *render) || any;
    }
    return any;
}

void Window::broadcastResizeObservations(JSContext* ctx) {
    RenderTree* render = HostState::of(ctx).render();
    if (!render || !m_observers) {
        return;
    }
    for (const Ref<ResizeObserver>& observer : this->heldObservers<ResizeObserver>(ctx)) {
        observer->broadcast(ctx, *render);
    }
}

void Window::reportResizeObserverLoop(JSContext* ctx) {
    // Resize Observer: "deliver resize loop error notification", an ErrorEvent at the window with no error.
    idl::ErrorEventInit init;
    init.cancelable = true;
    init.message = String::fromUTF8(ctx, "ResizeObserver loop completed with undelivered notifications.");
    Ref<ErrorEvent> event = ErrorEvent::construct(ctx, String::fromUTF8(ctx, "error"), std::move(init));
    event->setIsTrusted(true);
    dispatch(ctx, *event, *this);
}

} // namespace wr
