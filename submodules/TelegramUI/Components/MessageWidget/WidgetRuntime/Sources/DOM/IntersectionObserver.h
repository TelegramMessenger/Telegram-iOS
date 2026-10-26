// Intersection Observer (V3b plan, Task 3; https://w3c.github.io/IntersectionObserver/): IntersectionObserver and
// IntersectionObserverEntry. After the flush that ends a task or a frame the event loop runs the update steps
// (Window::updateIntersectionObservations): each observation's target, clipped by its clipping ancestors and the root
// rectangle (the widget's whole area for the implicit root: a widget has no viewport; an element root's padding box or
// border box), grown by rootMargin; an entry is queued when the threshold index or isIntersecting changed (always the
// first time) and delivered in a task. An observer with observations is held by the window; it holds its targets.
#pragma once

#include <array>

#include "Generated/Bindings.h"
#include "Sources/Render/HitTest.h"
#include "Sources/Support/Allocator.h"

namespace wr {

class DOMRectReadOnly;
class Element;
class RenderTree;

class IntersectionObserverEntry final : public PlatformObject {
public:
    IntersectionObserverEntry() = default;
    double time(JSContext*) const { return m_time; }
    DOMRectReadOnly* rootBounds(JSContext*);
    DOMRectReadOnly* boundingClientRect(JSContext*);
    DOMRectReadOnly* intersectionRect(JSContext*);
    bool isIntersecting(JSContext*) const { return m_isIntersecting; }
    double intersectionRatio(JSContext*) const { return m_ratio; }
    Element* target(JSContext*);
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

private:
    friend class IntersectionObserver;
    double m_time = 0;
    Held m_rootBounds;
    Held m_boundingClientRect;
    Held m_intersectionRect;
    Held m_target;
    bool m_isIntersecting = false;
    double m_ratio = 0;
};

class IntersectionObserver final : public PlatformObject {
public:
    explicit IntersectionObserver(JSContext* ctx);
    /// Throws SyntaxError for a rootMargin that is not one to four px or % lengths, RangeError for a threshold outside
    /// [0, 1].
    static Ref<IntersectionObserver> construct(JSContext* ctx, Callback callback, idl::IntersectionObserverInit options);
    Element* root(JSContext*);
    /// The four margins, top right bottom left, as given ("0px 0px 0px 0px" by default).
    String rootMargin(JSContext* ctx);
    /// A frozen array of the thresholds, ascending (`any` in the IDL, README.md).
    Value thresholds(JSContext* ctx);
    void observe(JSContext* ctx, Element* target);
    void unobserve(JSContext* ctx, Element* target);
    void disconnect(JSContext* ctx);
    /// The queued entries, as an array, the queue emptied (`any` in the IDL, README.md).
    Value takeRecords(JSContext* ctx);

    /// The update steps for this observer at `time`; true when it queued an entry.
    bool update(JSContext* ctx, const RenderTree& render, double time);
    /// The notify task's step: the queued entries to the callback (its exception reported), the queue emptied.
    void notify(JSContext* ctx);

    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

private:
    struct Margin {
        double value = 0;
        bool percent = false;
    };
    struct Observation {
        Held target;
        int previousThresholdIndex = -1;
        bool previousIsIntersecting = false;
    };
    Value queuedArray(JSContext* ctx);
    Held m_callback;
    Held m_root;
    std::array<Margin, 4> m_margin;
    Vector<double> m_thresholds;
    Vector<Observation> m_observations;
    Vector<Held> m_queue;
    Held m_thresholdsArray;
};

} // namespace wr
