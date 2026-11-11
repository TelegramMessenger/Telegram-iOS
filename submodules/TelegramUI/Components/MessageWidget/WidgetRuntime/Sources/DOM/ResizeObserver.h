// Resize Observer (V3b plan, Task 2; https://drafts.csswg.org/resize-observer/): ResizeObserver, ResizeObserverEntry
// and ResizeObserverSize. The event loop delivers after the flush that ends a task or a frame (EventLoop::
// deliverResizeObservations): gather, broadcast, run the microtasks, lay out, gather again, at most EventLoop's
// kResizeObserverRounds (4) rounds. An observer with observations is held by the window, so it keeps delivering after
// the widget drops it; it holds its targets.
#pragma once

#include <vector>

#include "Generated/Bindings.h"
#include "Sources/Support/Allocator.h"

namespace wr {

class DOMRectReadOnly;
class Element;
class RenderTree;

class ResizeObserverSize final : public PlatformObject {
public:
    ResizeObserverSize(double inlineSize, double blockSize) : m_inline(inlineSize), m_block(blockSize) {}
    double inlineSize(JSContext*) const { return m_inline; }
    double blockSize(JSContext*) const { return m_block; }

private:
    double m_inline;
    double m_block;
};

class ResizeObserverEntry final : public PlatformObject {
public:
    ResizeObserverEntry() = default;
    Element* target(JSContext*);
    DOMRectReadOnly* contentRect(JSContext*);
    /// Frozen arrays of one ResizeObserverSize (`any` in the IDL: the generator emits no FrozenArray, README.md).
    Value borderBoxSize(JSContext* ctx) { return Value::dup(ctx, m_borderBoxSize.value); }
    Value contentBoxSize(JSContext* ctx) { return Value::dup(ctx, m_contentBoxSize.value); }
    Value devicePixelContentBoxSize(JSContext* ctx) { return Value::dup(ctx, m_deviceBoxSize.value); }
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

private:
    friend class ResizeObserver;
    Held m_target;
    Held m_contentRect;
    Held m_borderBoxSize;
    Held m_contentBoxSize;
    Held m_deviceBoxSize;
};

class ResizeObserver final : public PlatformObject {
public:
    explicit ResizeObserver(JSContext* ctx) : m_observations(JSAllocator<Observation>(JS_GetRuntime(ctx))) {}
    static Ref<ResizeObserver> construct(JSContext* ctx, Callback callback);
    void observe(JSContext* ctx, Element* target, idl::ResizeObserverOptions options);
    void unobserve(JSContext* ctx, Element* target);
    void disconnect(JSContext* ctx);

    /// "gather active resize observations": marks every observation whose size differs from the one it last reported
    /// (0×0 at first); true when one does.
    bool gather(JSContext* ctx, const RenderTree& render);
    /// "broadcast active resize observations": the marked ones, as entries, to the callback (its exception reported),
    /// each now the size it reported. Runs script.
    void broadcast(JSContext* ctx, const RenderTree& render);

    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

private:
    enum class Box { Content, Border, DevicePixel };
    struct Observation {
        Held target;
        Box box = Box::Content;
        double lastInline = 0;
        double lastBlock = 0;
        bool active = false;
    };
    Held m_callback;
    Vector<Observation> m_observations;
};

} // namespace wr
