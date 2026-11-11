#include "Sources/Render/HitTest.h"

#include <algorithm>
#include <cctype>
#include <functional>
#include <string>

#include <litehtml.h>
#include <litehtml/el_svg.h>
#include <litehtml/render_item.h>
#include <litehtml/render_table.h>

namespace wr {

namespace {

RenderBox boxOf(const litehtml::position& p) {
    return RenderBox{double(p.x.value()), double(p.y.value()), double(p.width.value()), double(p.height.value())};
}

RenderBox unite(const RenderBox& a, const RenderBox& b) {
    const double left = std::min(a.x, b.x);
    const double top = std::min(a.y, b.y);
    const double right = std::max(a.x + a.width, b.x + b.width);
    const double bottom = std::max(a.y + a.height, b.y + b.height);
    return RenderBox{left, top, right - left, bottom - top};
}

} // namespace

litehtml::element::ptr hitElement(const litehtml::document& document, double x, double y) {
    // root_render() is not const, though it only returns the root.
    std::shared_ptr<litehtml::render_item> root = const_cast<litehtml::document&>(document).root_render();
    if (!root) {
        return nullptr;
    }
    static const litehtml::string_id pointerEvents = litehtml::raw_declaration_id(litehtml::_id("pointer-events"));
    const auto hittable = [](const std::shared_ptr<litehtml::render_item>& item) -> bool {
        for (litehtml::element::ptr el = item->src_el(); el; el = el->parent()) {
            auto tag = std::dynamic_pointer_cast<litehtml::html_tag>(el);
            if (!tag) {
                continue;
            }
            const litehtml::css_token_vector* tokens = tag->get_token_property(pointerEvents);
            if (!tokens) {
                continue;
            }
            std::string value = litehtml::get_repr(*tokens, 0, -1, true);
            if (value.empty()) {
                continue;
            }
            for (auto& c : value) {
                c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
            }
            // pointer-events is inherited: inherit, unset and revert (no master sheet rule declares it) take the
            // parent's; initial is auto.
            if (value == "inherit" || value == "unset" || value == "revert" || value == "revert-layer") {
                continue;
            }
            return value != "none";
        }
        return true;
    };
    const litehtml::pixel_t px(static_cast<float>(x)), py(static_cast<float>(y));
    litehtml::element::ptr hit = root->get_element_by_point(px, py, px, py, hittable);
    if (auto svg = std::dynamic_pointer_cast<litehtml::el_svg>(hit)) {
        if (litehtml::element::ptr inner = svg->element_at(svg->get_placement(), px, py)) {
            hit = inner;
        }
    }
    return hit;
}

std::vector<RenderBox> elementClientRects(const litehtml::element& element) {
    std::vector<RenderBox> rects;
    element.for_each_render_item([&](const std::shared_ptr<litehtml::render_item>& ri) {
        const litehtml::position p = ri->get_placement();
        const litehtml::position pos = ri->pos();
        std::vector<RenderBox> fragments;
        const bool isInline = ri->for_inline_boxes([&](const litehtml::position& b, bool, bool) {
            fragments.push_back(boxOf(b));
            return true;
        });
        if (isInline) {
            const double dx = double(p.x.value()) - double(pos.x.value());
            const double dy = double(p.y.value()) - double(pos.y.value());
            std::vector<RenderBox> mine;
            for (const RenderBox& f : fragments) {
                mine.push_back(RenderBox{f.x + dx, f.y + dy, f.width, f.height});
            }
            if (mine.empty()) {
                mine.push_back(RenderBox{double(p.x.value()), double(p.y.value()), 0, 0});
            }
            rects.insert(rects.end(), mine.begin(), mine.end());
            return;
        }
        const double left = double(ri->padding_left().value()) + double(ri->border_left().value());
        const double top = double(ri->padding_top().value()) + double(ri->border_top().value());
        const double right = double(ri->padding_right().value()) + double(ri->border_right().value());
        const double bottom = double(ri->padding_bottom().value()) + double(ri->border_bottom().value());
        rects.push_back(RenderBox{double(p.x.value()) - left, double(p.y.value()) - top,
                                  double(p.width.value()) + left + right, double(p.height.value()) + top + bottom});
    });
    if (rects.empty()) {
        // A table row or row group has no render item: its table's grid places it (twidget edit 61).
        const litehtml::style_display display = element.css().get_display();
        if (display == litehtml::display_table_row || display == litehtml::display_table_row_group ||
            display == litehtml::display_table_header_group || display == litehtml::display_table_footer_group) {
            for (auto el = element.parent(); el; el = el->parent()) {
                const litehtml::style_display d = el->css().get_display();
                if (d != litehtml::display_table && d != litehtml::display_inline_table) {
                    continue;
                }
                const auto table = std::dynamic_pointer_cast<litehtml::render_item_table>(el->get_render_item());
                litehtml::position box;
                if (table && table->part_placement(&element, box)) {
                    rects.push_back(boxOf(box));
                }
                break;
            }
        }
    }
    return rects;
}

bool unionOfRects(const std::vector<RenderBox>& rects, RenderBox& out) {
    if (rects.empty()) {
        return false;
    }
    out = rects.front();
    for (const RenderBox& r : rects) {
        out = unite(out, r);
    }
    return true;
}

bool elementBorderBox(const litehtml::element& element, RenderBox& out) {
    return unionOfRects(elementClientRects(element), out);
}

bool visualTransform(const litehtml::element& element, Affine& out) {
    // The element's own transform and every ancestor's, composed innermost first and applied once (review minors,
    // Task 4): a bounding box taken at every level inflated a rect whose rotation a child undoes. In double, as each
    // level used to map: nested large scales pass a float's range.
    Affine total;
    bool transformed = false;
    for (const litehtml::element* el = &element; el; el = el->parent().get()) {
        std::shared_ptr<litehtml::render_item> item;
        el->for_each_render_item([&](const std::shared_ptr<litehtml::render_item>& ri) {
            if (!item) {
                item = ri;
            }
        });
        if (!item) {
            continue;
        }
        const litehtml::transform_matrix m = item->get_visual_transform();
        if (m.is_identity()) {
            continue;
        }
        const Affine level{m.a, m.b, m.c, m.d, m.tx, m.ty};
        total = transformed ? Affine{total.a * level.a + total.b * level.c, total.a * level.b + total.b * level.d,
                                     total.c * level.a + total.d * level.c, total.c * level.b + total.d * level.d,
                                     total.tx * level.a + total.ty * level.c + level.tx,
                                     total.tx * level.b + total.ty * level.d + level.ty}
                            : level;
        transformed = true;
    }
    out = total;
    return transformed;
}

void transformRects(const litehtml::element& element, std::vector<RenderBox>& rects) {
    if (rects.empty()) {
        return;
    }
    Affine total;
    if (!visualTransform(element, total)) {
        return;
    }
    for (RenderBox& r : rects) {
        double left = 0, top = 0, right = 0, bottom = 0;
        bool first = true;
        for (const auto& [x, y] : {std::pair{r.x, r.y}, std::pair{r.x + r.width, r.y}, std::pair{r.x, r.y + r.height},
                                   std::pair{r.x + r.width, r.y + r.height}}) {
            const double mx = total.a * x + total.c * y + total.tx;
            const double my = total.b * x + total.d * y + total.ty;
            left = first ? mx : std::min(left, mx);
            right = first ? mx : std::max(right, mx);
            top = first ? my : std::min(top, my);
            bottom = first ? my : std::max(bottom, my);
            first = false;
        }
        r = RenderBox{left, top, right - left, bottom - top};
    }
}

} // namespace wr
