// SVG geometry (V3b plan, Task 4): SVGGraphicsElement, SVGGeometryElement and SVGTextContentElement's queries, each a
// layout query reading the published layout through RenderTree (svgBBox, svgPathLength, svgPointAtLength,
// svgTextLength), in the element's user units.
#include <cmath>

#include "Sources/DOM/DOM.h"
#include "Sources/Render/RenderTree.h"

namespace wr {

Ref<DOMRect> SVGGraphicsElement::getBBox(JSContext* ctx, idl::SVGBoundingBoxOptions) {
    RenderTree* render = layoutForQuery(ctx);
    std::optional<RenderBox> box = render ? render->svgBBox(*this) : std::nullopt;
    return DOMRectReadOnly::make(ctx, box.value_or(RenderBox{}));
}

double SVGGeometryElement::getTotalLength(JSContext* ctx) {
    RenderTree* render = layoutForQuery(ctx);
    std::optional<double> length = render ? render->svgPathLength(*this) : std::nullopt;
    return length.value_or(0);
}

Ref<DOMPoint> SVGGeometryElement::getPointAtLength(JSContext* ctx, Unrestricted given) {
    const double distance = given.value;
    RenderTree* render = layoutForQuery(ctx);
    std::optional<std::pair<double, double>> point =
        render ? render->svgPointAtLength(*this, std::isfinite(distance) ? distance : 0) : std::nullopt;
    return DOMPointReadOnly::make(ctx, point ? point->first : 0, point ? point->second : 0);
}

int32_t SVGTextContentElement::getNumberOfChars(JSContext* ctx) {
    RenderTree* render = layoutForQuery(ctx);
    return render ? int32_t(render->svgTextUnits(*this)) : 0;
}

double SVGTextContentElement::getComputedTextLength(JSContext* ctx) {
    RenderTree* render = layoutForQuery(ctx);
    std::optional<double> length = render ? render->svgTextLength(*this) : std::nullopt;
    return length.value_or(0);
}

} // namespace wr
