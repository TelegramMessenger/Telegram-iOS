#include "Sources/DOM/Geometry.h"

#include <algorithm>
#include <cmath>
#include <limits>

#include "Generated/Bindings.h"
#include "Sources/DOM/DOM.h"
#include "Sources/Host/HostState.h"
#include "Sources/Host/Window.h"
#include "Sources/Render/HitTest.h"
#include "Sources/Render/RenderTree.h"
#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Errors.h"

namespace wr {

namespace {

int32_t rounded(double value) {
    return int32_t(std::lround(value));
}

/// The window's document's root element: its client and scroll sizes are the viewport's.
bool isRootElement(JSContext* ctx, const Element& element) {
    DOMState* state = DOMState::find(ctx);
    return state && state->hasDocument() && state->document().documentElementNode() == &element;
}

/// The border box (RenderTree::borderBox: the union of the client rects); nullopt with no box.
std::optional<RenderBox> borderBoxOf(const RenderTree& render, const Node& node) {
    RenderBox box;
    if (!unionOfRects(render.clientRects(node), box)) {
        return std::nullopt;
    }
    return box;
}

/// CSSOM View's offsetParent: null for an element with no box, a fixed one, the body and the root; otherwise the
/// nearest positioned ancestor, else the body.
Element* offsetParentOf(JSContext* ctx, RenderTree& render, Element& element) {
    DOMState* state = DOMState::find(ctx);
    if (!state || !state->hasDocument()) {
        return nullptr;
    }
    Document& document = state->document();
    HTMLElement* body = document.body(ctx);
    std::optional<RenderTree::BoxMetrics> metrics = render.boxMetrics(element);
    if (!metrics || metrics->fixed || &element == body || &element == document.documentElementNode()) {
        return nullptr;
    }
    for (Element* ancestor = element.parentElementNode(); ancestor; ancestor = ancestor->parentElementNode()) {
        if (ancestor == body) {
            return body;
        }
        std::optional<RenderTree::BoxMetrics> ancestorMetrics = render.boxMetrics(*ancestor);
        if (ancestorMetrics && ancestorMetrics->positioned) {
            return ancestor;
        }
    }
    return nullptr;
}

/// The far edges (right, bottom) of `element`'s descendants' border boxes, at least `right` and `bottom`.
void extendByDescendants(JSContext* ctx, const RenderTree& render, const Element& element, double& right, double& bottom) {
    Node* node = element.firstChildNode();
    while (node) {
        if (node->isElement()) {
            if (std::optional<RenderBox> box = borderBoxOf(render, *node)) {
                right = std::max(right, box->x + box->width);
                bottom = std::max(bottom, box->y + box->height);
            }
        }
        if (Node* child = node->firstChildNode()) {
            node = child;
            continue;
        }
        while (node && node != &element && !node->nextSiblingNode()) {
            node = node->parent();
        }
        node = (node && node != &element) ? node->nextSiblingNode() : nullptr;
    }
}

/// The scrollable overflow from the padding box's origin: the padding box, and the descendants' boxes with the end
/// padding after them (CSS Overflow: the content's extent includes the end padding).
RenderBox scrollExtent(JSContext* ctx, const RenderTree& render, const Element& element, const RenderBox& padding) {
    double right = -std::numeric_limits<double>::infinity(), bottom = -std::numeric_limits<double>::infinity();
    extendByDescendants(ctx, render, element, right, bottom);
    std::optional<RenderTree::BoxMetrics> metrics = render.boxMetrics(element);
    double far = padding.x + padding.width, low = padding.y + padding.height;
    if (std::isfinite(right) && metrics) {
        far = std::max(far, right + metrics->paddingRight);
    }
    if (std::isfinite(bottom) && metrics) {
        low = std::max(low, bottom + metrics->paddingBottom);
    }
    return RenderBox{padding.x, padding.y, far - padding.x, low - padding.y};
}

/// The padding box of a rendered, non-inline element, and its metrics.
std::optional<RenderBox> paddingBox(JSContext* ctx, const RenderTree& render, const Element& element) {
    std::optional<RenderTree::BoxMetrics> metrics = render.boxMetrics(element);
    std::optional<RenderBox> box = borderBoxOf(render, element);
    if (!metrics || !box || metrics->inlineLevel) {
        return std::nullopt;
    }
    return RenderBox{box->x + metrics->borderLeft, box->y + metrics->borderTop,
                     std::max(0.0, box->width - metrics->borderLeft - metrics->borderRight),
                     std::max(0.0, box->height - metrics->borderTop - metrics->borderBottom)};
}

} // namespace

RenderTree* layoutForQuery(JSContext* ctx) {
    HostState* host = HostState::find(ctx);
    RenderTree* render = host ? host->render() : nullptr;
    if (!render) {
        return nullptr;
    }
    Runtime& runtime = Runtime::from(ctx);
    runtime.noteLayoutQuery();
    render->flushForQuery(ctx);
    // widget-sandbox's layout queries per task: past 100 ms of their time the widget stops.
    if (runtime.queryBudgetSpent()) {
        runtime.stopForLayoutQueries();
        throw Aborted{};
    }
    return render;
}

// MARK: DOMRectReadOnly, DOMRect

double DOMRectReadOnly::top(JSContext*) const {
    return std::min(m_box.y, m_box.y + m_box.height);
}

double DOMRectReadOnly::right(JSContext*) const {
    return std::max(m_box.x, m_box.x + m_box.width);
}

double DOMRectReadOnly::bottom(JSContext*) const {
    return std::max(m_box.y, m_box.y + m_box.height);
}

double DOMRectReadOnly::left(JSContext*) const {
    return std::min(m_box.x, m_box.x + m_box.width);
}

Object DOMRectReadOnly::toJSON(JSContext* ctx) {
    Value object = Value::adopt(ctx, checked(ctx, JS_NewObject(ctx)));
    const std::pair<const char*, double> fields[] = {
        {"x", this->x(ctx)}, {"y", this->y(ctx)}, {"width", this->width(ctx)}, {"height", this->height(ctx)},
        {"top", this->top(ctx)}, {"right", this->right(ctx)}, {"bottom", this->bottom(ctx)}, {"left", this->left(ctx)},
    };
    for (const auto& field : fields) {
        check(ctx, JS_DefinePropertyValueStr(ctx, object.get(), field.first, JS_NewFloat64(ctx, field.second), JS_PROP_C_W_E));
    }
    return Object(std::move(object));
}

Ref<DOMRect> DOMRectReadOnly::make(JSContext* ctx, const RenderBox& box) {
    return create<DOMRect>(ctx, idl::kDOMRect, box);
}

// MARK: DOMPointReadOnly

Object DOMPointReadOnly::toJSON(JSContext* ctx) {
    Value object = Value::adopt(ctx, checked(ctx, JS_NewObject(ctx)));
    const std::pair<const char*, double> fields[] = {{"x", m_x}, {"y", m_y}, {"z", 0}, {"w", 1}};
    for (const auto& field : fields) {
        check(ctx, JS_DefinePropertyValueStr(ctx, object.get(), field.first, JS_NewFloat64(ctx, field.second), JS_PROP_C_W_E));
    }
    return Object(std::move(object));
}

Ref<DOMPoint> DOMPointReadOnly::make(JSContext* ctx, double x, double y) {
    return create<DOMPoint>(ctx, idl::kDOMPoint, x, y);
}

// MARK: DOMRectList

Ref<DOMRectList> DOMRectList::make(JSContext* ctx, const std::vector<RenderBox>& boxes) {
    Ref<DOMRectList> list = create<DOMRectList>(ctx, idl::kDOMRectList, ctx);
    // Room first: growing can fail at the memory limit, and then nothing is held yet.
    list->m_items.reserve(boxes.size());
    for (const RenderBox& box : boxes) {
        Ref<DOMRect> rect = DOMRectReadOnly::make(ctx, box);
        list->m_items.push_back(Held{rect.release()});
    }
    return list;
}

DOMRect* DOMRectList::item(JSContext*, uint32_t index) {
    return index < m_items.size() ? static_cast<DOMRect*>(payloadOfKnown(m_items[index].value)) : nullptr;
}

JSValue DOMRectList::indexedValue(JSContext* ctx, uint32_t index) {
    return index < m_items.size() ? JS_DupValue(ctx, m_items[index].value) : JS_UNDEFINED;
}

void DOMRectList::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    for (const Held& h : m_items) {
        h.mark(rt, mark);
    }
}

void DOMRectList::dispose(JSRuntime* rt) {
    for (Held& h : m_items) {
        h.clear(rt);
    }
    m_items.clear();
}

// MARK: Element

// getClientRects and getBoundingClientRect report where the boxes are drawn: transformed (RenderTree::visualRects).
Ref<DOMRectList> Element::getClientRects(JSContext* ctx) {
    RenderTree* render = layoutForQuery(ctx);
    return DOMRectList::make(ctx, render ? render->visualRects(*this, render->clientRects(*this))
                                         : std::vector<RenderBox>());
}

Ref<DOMRect> Element::getBoundingClientRect(JSContext* ctx) {
    RenderTree* render = layoutForQuery(ctx);
    RenderBox box;
    if (!render || !unionOfRects(render->visualRects(*this, render->clientRects(*this)), box)) {
        box = RenderBox();
    }
    return DOMRectReadOnly::make(ctx, box);
}

int32_t Element::clientTop(JSContext* ctx) {
    RenderTree* render = layoutForQuery(ctx);
    std::optional<RenderTree::BoxMetrics> metrics = render ? render->boxMetrics(*this) : std::nullopt;
    return metrics && !metrics->inlineLevel ? rounded(metrics->borderTop) : 0;
}

int32_t Element::clientLeft(JSContext* ctx) {
    RenderTree* render = layoutForQuery(ctx);
    std::optional<RenderTree::BoxMetrics> metrics = render ? render->boxMetrics(*this) : std::nullopt;
    return metrics && !metrics->inlineLevel ? rounded(metrics->borderLeft) : 0;
}

int32_t Element::clientWidth(JSContext* ctx) {
    RenderTree* render = layoutForQuery(ctx);
    if (!render) {
        return 0;
    }
    if (isRootElement(ctx, *this)) {
        return rounded(render->layoutWidth());
    }
    std::optional<RenderBox> box = paddingBox(ctx, *render, *this);
    return box ? rounded(box->width) : 0;
}

int32_t Element::clientHeight(JSContext* ctx) {
    RenderTree* render = layoutForQuery(ctx);
    if (!render) {
        return 0;
    }
    if (isRootElement(ctx, *this)) {
        return rounded(render->documentHeight());
    }
    std::optional<RenderBox> box = paddingBox(ctx, *render, *this);
    return box ? rounded(box->height) : 0;
}

int32_t Element::scrollWidth(JSContext* ctx) {
    RenderTree* render = layoutForQuery(ctx);
    if (!render) {
        return 0;
    }
    if (isRootElement(ctx, *this)) {
        return rounded(render->layoutWidth());
    }
    std::optional<RenderBox> box = paddingBox(ctx, *render, *this);
    if (!box) {
        return 0;
    }
    return rounded(scrollExtent(ctx, *render, *this, *box).width);
}

int32_t Element::scrollHeight(JSContext* ctx) {
    RenderTree* render = layoutForQuery(ctx);
    if (!render) {
        return 0;
    }
    if (isRootElement(ctx, *this)) {
        return rounded(render->documentHeight());
    }
    std::optional<RenderBox> box = paddingBox(ctx, *render, *this);
    if (!box) {
        return 0;
    }
    return rounded(scrollExtent(ctx, *render, *this, *box).height);
}

// MARK: HTMLElement

Element* HTMLElement::offsetParent(JSContext* ctx) {
    RenderTree* render = layoutForQuery(ctx);
    return render ? offsetParentOf(ctx, *render, *this) : nullptr;
}

int32_t HTMLElement::offsetTop(JSContext* ctx) {
    RenderTree* render = layoutForQuery(ctx);
    std::optional<RenderBox> box = render ? borderBoxOf(*render, *this) : std::nullopt;
    if (!box) {
        return 0;
    }
    Element* parent = offsetParentOf(ctx, *render, *this);
    DOMState* state = DOMState::find(ctx);
    if (!parent || (state && state->hasDocument() && parent == state->document().body(ctx))) {
        return rounded(box->y);
    }
    std::optional<RenderBox> parentBox = borderBoxOf(*render, *parent);
    std::optional<RenderTree::BoxMetrics> parentMetrics = render->boxMetrics(*parent);
    if (!parentBox || !parentMetrics) {
        return rounded(box->y);
    }
    return rounded(box->y - parentBox->y - parentMetrics->borderTop);
}

int32_t HTMLElement::offsetLeft(JSContext* ctx) {
    RenderTree* render = layoutForQuery(ctx);
    std::optional<RenderBox> box = render ? borderBoxOf(*render, *this) : std::nullopt;
    if (!box) {
        return 0;
    }
    Element* parent = offsetParentOf(ctx, *render, *this);
    DOMState* state = DOMState::find(ctx);
    if (!parent || (state && state->hasDocument() && parent == state->document().body(ctx))) {
        return rounded(box->x);
    }
    std::optional<RenderBox> parentBox = borderBoxOf(*render, *parent);
    std::optional<RenderTree::BoxMetrics> parentMetrics = render->boxMetrics(*parent);
    if (!parentBox || !parentMetrics) {
        return rounded(box->x);
    }
    return rounded(box->x - parentBox->x - parentMetrics->borderLeft);
}

std::optional<RenderedContentSize> renderedContentSize(JSContext* ctx, const Element& element) {
    RenderTree* render = layoutForQuery(ctx);
    if (!render) {
        return std::nullopt;
    }
    const bool rendered = render->beingRendered(element);
    if (!rendered) {
        return std::nullopt;
    }
    std::optional<RenderBox> box = borderBoxOf(*render, element);
    std::optional<RenderTree::BoxMetrics> metrics = box ? render->boxMetrics(element) : std::nullopt;
    if (!box || !metrics) {
        return std::nullopt;
    }
    const double width = box->width - metrics->borderLeft - metrics->borderRight - metrics->paddingLeft - metrics->paddingRight;
    const double height = box->height - metrics->borderTop - metrics->borderBottom - metrics->paddingTop - metrics->paddingBottom;
    return RenderedContentSize{std::max(0.0, width), std::max(0.0, height), metrics->autoWidth, metrics->autoHeight};
}

int32_t HTMLElement::offsetWidth(JSContext* ctx) {
    RenderTree* render = layoutForQuery(ctx);
    std::optional<RenderBox> box = render ? borderBoxOf(*render, *this) : std::nullopt;
    return box ? rounded(box->width) : 0;
}

int32_t HTMLElement::offsetHeight(JSContext* ctx) {
    RenderTree* render = layoutForQuery(ctx);
    std::optional<RenderBox> box = render ? borderBoxOf(*render, *this) : std::nullopt;
    return box ? rounded(box->height) : 0;
}

// MARK: Document, Window

Element* Document::elementFromPoint(JSContext* ctx, double x, double y) {
    DOMState* state = DOMState::find(ctx);
    if (!state || !state->hasDocument() || &state->document() != this) {
        return nullptr;
    }
    RenderTree* render = layoutForQuery(ctx);
    if (!render || x < 0 || y < 0 || x > render->layoutWidth() || y > render->documentHeight()) {
        return nullptr;
    }
    // The hit test walks the whole render tree.
    Node* node = render->nodeAt(x, y);
    return node && node->isElement() ? static_cast<Element*>(node) : nullptr;
}

int32_t Window::innerWidth(JSContext* ctx) {
    RenderTree* render = layoutForQuery(ctx);
    return render ? rounded(render->layoutWidth()) : 0;
}

int32_t Window::innerHeight(JSContext* ctx) {
    RenderTree* render = layoutForQuery(ctx);
    return render ? rounded(render->documentHeight()) : 0;
}

double Window::devicePixelRatio(JSContext* ctx) {
    HostState* host = HostState::find(ctx);
    RenderTree* render = host ? host->render() : nullptr;
    return render ? render->options().pixelSnapScale : 1.0;
}

} // namespace wr
