// CSSOM View's geometry (V3 plan, Task 3): DOMRectReadOnly, DOMRect and DOMRectList, and the query every geometry
// member makes first. The members themselves (Element's client and scroll sizes and rects, HTMLElement's offsets,
// Document.elementFromPoint, Window's inner size) are defined in Geometry.cpp. Coordinates are CSS px from the
// document's top-left: a widget has no scrolling viewport.
#pragma once

#include <vector>

#include "Sources/DOM/Element.h"
#include "Sources/Render/HitTest.h"
#include "Sources/Support/Values.h"

namespace wr {

class DOMRect;
class RenderTree;

/// A rectangle; its sides are min/max of the origin and the far corner, so a negative size reads as the spec says.
class DOMRectReadOnly : public PlatformObject {
public:
    explicit DOMRectReadOnly(const RenderBox& box) : m_box(box) {}

    double x(JSContext*) const { return m_box.x; }
    double y(JSContext*) const { return m_box.y; }
    double width(JSContext*) const { return m_box.width; }
    double height(JSContext*) const { return m_box.height; }
    double top(JSContext*) const;
    double right(JSContext*) const;
    double bottom(JSContext*) const;
    double left(JSContext*) const;
    /// `{x, y, width, height, top, right, bottom, left}`, as the default toJSON writes it.
    Object toJSON(JSContext* ctx);

    /// A new DOMRect (what getBoundingClientRect returns).
    static Ref<DOMRect> make(JSContext* ctx, const RenderBox& box);

private:
    RenderBox m_box;
};

class DOMPoint;

/// Geometry Interfaces' point, what SVGGeometryElement.getPointAtLength returns (V3b plan, Task 4).
class DOMPointReadOnly : public PlatformObject {
public:
    DOMPointReadOnly(double x, double y) : m_x(x), m_y(y) {}
    double x(JSContext*) const { return m_x; }
    double y(JSContext*) const { return m_y; }
    double z(JSContext*) const { return 0; }
    double w(JSContext*) const { return 1; }
    Object toJSON(JSContext* ctx);
    static Ref<DOMPoint> make(JSContext* ctx, double x, double y);

private:
    double m_x;
    double m_y;
};

class DOMPoint final : public DOMPointReadOnly {
public:
    using DOMPointReadOnly::DOMPointReadOnly;
};

/// The rectangle the geometry members return. Read-only here: its setters are not bound (IDL/README.md).
class DOMRect final : public DOMRectReadOnly {
public:
    using DOMRectReadOnly::DOMRectReadOnly;
};

/// getClientRects' answer: a static list that holds its rects.
class DOMRectList final : public PlatformObject {
public:
    explicit DOMRectList(JSContext* ctx) : m_items(JSAllocator<Held>(JS_GetRuntime(ctx))) {}
    static Ref<DOMRectList> make(JSContext* ctx, const std::vector<RenderBox>& boxes);

    uint32_t length(JSContext*) { return uint32_t(m_items.size()); }
    DOMRect* item(JSContext*, uint32_t index);
    /// The indexed exotic's read: a new reference, undefined past the end.
    JSValue indexedValue(JSContext* ctx, uint32_t index);
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

private:
    Vector<Held> m_items;
};

/// The layout a geometry member reads, after charging the query, flushing what is pending
/// (RenderTree::flushForQuery) and counting that work against the step's layout-query budget
/// (work::kLayoutQueryBudget): past it the widget stops with StopReason::LayoutQuery and this throws Aborted.
/// nullptr when there is no render tree (a document that is not laid out).
RenderTree* layoutForQuery(JSContext* ctx);

/// Charges what a query's read walked and counts it against the step's layout-query budget, as layoutForQuery counts
/// the query and its flush: past the budget the widget stops with StopReason::LayoutQuery and this throws Aborted.
void chargeQueryRead(JSContext* ctx, uint64_t units);

} // namespace wr
