// Hit-testing and boxes over a published litehtml document (M1c plan, Task 10), ported from LHDocument.mm so the host and
// the app agree. Pure reads of the current layout: nothing here lays out, flushes or changes the document. Coordinates are
// the document's (the space layoutDump reports), with (0, 0) at the top-left of the rendered document.
#pragma once

#include <cstdint>
#include <vector>

#include <litehtml.h>

namespace wr {

struct RenderBox { double x = 0, y = 0, width = 0, height = 0; };

/// The element under the point, as LHDocument.mm's attribute:atPoint: finds it: litehtml's get_element_by_point with a
/// check that refuses what `pointer-events` resolves to `none` (the first value on the item's element or an ancestor),
/// then a hit `<svg>` descends to its shape. nullptr when nothing is hit or there is no render tree.
litehtml::element::ptr hitElement(const litehtml::document& document, double x, double y);

/// An element's boxes, one per render item: an inline element's one rect per inline box (in the space of its position,
/// offset to the placement, as boundsByAttribute has it), a table row's the union of its cells, any other element's its
/// border box (the placement, which is the content box, grown by padding and border). Empty when it has no render item.
std::vector<RenderBox> elementClientRects(const litehtml::element& element);

/// The union of `rects`; false when there is none.
bool unionOfRects(const std::vector<RenderBox>& rects, RenderBox& out);

/// The union of elementClientRects; false when there is none.
bool elementBorderBox(const litehtml::element& element, RenderBox& out);

/// A 2D affine map: (x, y) → (a·x + c·y + tx, b·x + d·y + ty).
struct Affine {
    double a = 1, b = 0, c = 0, d = 1, tx = 0, ty = 0;
};

/// The transforms of `element` and each ancestor, composed innermost first (render_item::get_visual_transform): what
/// maps `element`'s layout boxes into the document. False (and `out` the identity) when none of them is transformed.
bool visualTransform(const litehtml::element& element, Affine& out);

/// Maps `rects` (layout boxes of `element`, document coordinates) through the transforms of `element` and each ancestor,
/// innermost first (render_item::get_visual_transform: transform, translate, rotate and scale about the origin), each rect
/// to the bounds of its four mapped corners, as CSSOM View's getClientRects reports them.
void transformRects(const litehtml::element& element, std::vector<RenderBox>& rects);

} // namespace wr
