// The layer tree (M1c plan, Task 4): litehtml's paint calls recorded by WidgetContainer::record into plain data that
// outlives its document (Review Focus 5), and the diff of two trees.
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <memory>
#include <optional>
#include <set>
#include <string>
#include <variant>
#include <vector>

#include <litehtml.h>
#include <pthread.h>

#include "Sources/Render/LayerDiff.h"
#include "Sources/Render/LayerTree.h"
#include "Sources/Render/RenderDump.h"
#include "Sources/Render/RenderHost.h"
#include "Sources/Render/WidgetContainer.h"
#include "Tests/FakeRenderHost.h"
#include "Tests/wr_test.h"

using wr::Layer;
using wr::LayerTree;
using wr::PaintItem;
using wr_test::FakeRenderHost;

namespace {

wr::RenderOptions options(double width = 300) {
    wr::RenderOptions result;
    result.width = width;
    return result;
}

/// `trustedCSS` is litehtml's user sheet, which a container takes as trusted (twidget edit 29): the profile leaves it
/// whole, so a paint call no widget can reach any more (clip-path, text-shadow) is still recorded and checked.
litehtml::document::ptr layOut(litehtml::document_container& container, const std::string& html, float width = 300,
                               const std::string& trustedCSS = {}) {
    litehtml::document::ptr document =
        litehtml::document::createFromString(litehtml::estring(html), &container, litehtml::master_css, trustedCSS);
    document->render(litehtml::pixel_t(width));
    return document;
}

// A 3×2 RGBA PNG (signature, IHDR, IDAT, IEND).
const char* const kPng3x2 =
    "data:image/png;base64,"
    "iVBORw0KGgoAAAANSUhEUgAAAAMAAAACCAYAAACddGYaAAAAEUlEQVR4nGP4z8DwH4YZkDkAm34L9XKwuTwAAAAASUVORK5CYII=";

// An item and where it is: its layer, its index there, and the layers above it (outermost first, its own last).
struct Located {
    const PaintItem* item;
    const Layer* layer;
    size_t index;
    std::vector<const Layer*> chain;
};

std::vector<Located> items(const LayerTree& tree) {
    std::vector<Located> found;
    struct Frame {
        const Layer* layer;
        size_t next;
        std::vector<const Layer*> chain;
    };
    std::vector<Frame> stack;
    stack.push_back({&tree.root(), 0, {&tree.root()}});
    while (!stack.empty()) {
        Frame& frame = stack.back();
        if (frame.next == frame.layer->entries.size()) {
            stack.pop_back();
            continue;
        }
        const size_t index = frame.next++;
        const auto& entry = frame.layer->entries[index];
        if (const PaintItem* item = std::get_if<PaintItem>(&entry)) {
            found.push_back({item, frame.layer, index, frame.chain});
        } else {
            const Layer* child = std::get<std::unique_ptr<Layer>>(entry).get();
            std::vector<const Layer*> chain = frame.chain;
            chain.push_back(child);
            stack.push_back({child, 0, std::move(chain)});
        }
    }
    return found;
}

std::vector<const Layer*> layers(const LayerTree& tree) {
    std::vector<const Layer*> found;
    std::vector<const Layer*> stack{&tree.root()};
    while (!stack.empty()) {
        const Layer* layer = stack.back();
        stack.pop_back();
        found.push_back(layer);
        for (const auto& entry : layer->entries) {
            if (const auto* child = std::get_if<std::unique_ptr<Layer>>(&entry)) {
                stack.push_back(child->get());
            }
        }
    }
    return found;
}

const wr::TextItem* textOf(const PaintItem& item) {
    return std::get_if<wr::TextItem>(&item.payload);
}

// The first text item whose text is `text`.
const Located* findText(const std::vector<Located>& all, const std::string& text) {
    for (const Located& located : all) {
        const wr::TextItem* t = textOf(*located.item);
        if (t && t->text == text) {
            return &located;
        }
    }
    return nullptr;
}

const Located* findKind(const std::vector<Located>& all, PaintItem::Kind kind) {
    for (const Located& located : all) {
        if (located.item->kind == kind) {
            return &located;
        }
    }
    return nullptr;
}

// The clip open at `index` in `layer`: the innermost set_clip or set_clip_path before it that no del_clip closed.
const PaintItem* openClip(const Layer& layer, size_t index) {
    std::vector<const PaintItem*> clips;
    for (size_t i = 0; i < index && i < layer.entries.size(); i++) {
        const PaintItem* item = std::get_if<PaintItem>(&layer.entries[i]);
        if (!item) {
            continue;
        }
        if (item->kind == PaintItem::Kind::SetClip || item->kind == PaintItem::Kind::SetClipPath) {
            clips.push_back(item);
        } else if (item->kind == PaintItem::Kind::DelClip && !clips.empty()) {
            clips.pop_back();
        }
    }
    return clips.empty() ? nullptr : clips.back();
}

size_t indexIn(const Layer& parent, const Layer* child) {
    for (size_t i = 0; i < parent.entries.size(); i++) {
        const auto* entry = std::get_if<std::unique_ptr<Layer>>(&parent.entries[i]);
        if (entry && entry->get() == child) {
            return i;
        }
    }
    return parent.entries.size();
}

bool same(const litehtml::position& a, const litehtml::position& b, float tolerance = 0) {
    return std::fabs(a.x.value() - b.x.value()) <= tolerance && std::fabs(a.y.value() - b.y.value()) <= tolerance &&
           std::fabs(a.width.value() - b.width.value()) <= tolerance &&
           std::fabs(a.height.value() - b.height.value()) <= tolerance;
}

bool contains(const litehtml::position& outer, const litehtml::position& inner) {
    return outer.x.value() <= inner.x.value() && outer.y.value() <= inner.y.value() &&
           outer.x.value() + outer.width.value() >= inner.x.value() + inner.width.value() &&
           outer.y.value() + outer.height.value() >= inner.y.value() + inner.height.value();
}

bool anyContains(const std::vector<litehtml::position>& rects, const litehtml::position& inner) {
    for (const auto& rect : rects) {
        if (contains(rect, inner)) {
            return true;
        }
    }
    return false;
}

std::string describe(const std::vector<litehtml::position>& rects) {
    std::string out;
    for (const auto& r : rects) {
        char text[96];
        std::snprintf(text, sizeof(text), "(%g,%g,%g,%g) ", double(r.x.value()), double(r.y.value()),
                      double(r.width.value()), double(r.height.value()));
        out += text;
    }
    return out;
}

litehtml::position grown(const litehtml::position& p, float by) {
    return litehtml::position(p.x.value() - by, p.y.value() - by, p.width.value() + 2 * by, p.height.value() + 2 * by);
}

size_t lineCount(const std::string& text) {
    size_t lines = 0;
    for (char c : text) {
        lines += c == '\n';
    }
    return lines;
}

// Records `before` and `after` through one container, so the trees share its fonts.
struct Pair {
    std::shared_ptr<const LayerTree> before;
    std::shared_ptr<const LayerTree> after;
};

Pair recordPair(wr::WidgetContainer& container, const std::string& before, const std::string& after) {
    litehtml::document::ptr a = layOut(container, before);
    litehtml::document::ptr b = layOut(container, after);
    return {container.record(*a), container.record(*b)};
}

const char* const kEveryKind =
    "<div style='border:1px solid red'>text</div>"
    "<div style='background-color:#00ff00;height:10px'></div>"
    "<div style='background-image:linear-gradient(red,blue);height:10px'></div>"
    "<div style='background-image:radial-gradient(red,blue);height:10px'></div>"
    "<div style='background-image:conic-gradient(red,blue);height:10px'></div>"
    "<div style='box-shadow:2px 3px 4px 1px black;height:10px'></div>"
    "<div style='opacity:.5'>half</div>"
    "<div style='transform:rotate(10deg)'>turned</div>"
    "<div style='overflow:hidden;border-radius:4px;height:20px'>clipped</div>"
    "<div style='filter:blur(2px)'>blurred</div>"
    "<div style='backdrop-filter:blur(3px);height:10px'></div>"
    "<div class=tw-clip style='height:10px'>c</div>"
    "<div style='position:fixed;left:0;top:0'>fixed</div>"
    "<svg width=20 height=20><rect width=10 height=10 fill=red /></svg>"
    "<ul><li>item</li></ul>"
    "<p class=tw-shadow>shadowed</p>"
    "<svg width=20 height=20><line x1=0 y1=5 x2=10 y2=5 stroke=blue stroke-width=2 /></svg>"
    "<svg width=20 height=20><path d='M0 10 C0 0 10 0 10 10' fill='#00ff00' /></svg>";

std::string everyKindHtml() {
    return std::string(kEveryKind) + "<img src='" + kPng3x2 + "'>";
}

// kEveryKind's two out-of-profile shapes, as trusted CSS (layOut's `trustedCSS`).
const char* const kEveryKindTrusted = ".tw-clip{clip-path:circle(5px)} .tw-shadow{text-shadow:3px 4px 2px red}";

void* runBody(void* body) {
    (*static_cast<void (**)()>(body))();
    return nullptr;
}

// Runs `body` on a thread with a 512 KiB stack and waits for it, as MutationTests' deep cases do.
void runOnSmallStack(void (*body)()) {
    pthread_attr_t attributes;
    pthread_attr_init(&attributes);
    pthread_attr_setstacksize(&attributes, 512 * 1024);
    pthread_t thread;
    int status = pthread_create(&thread, &attributes, runBody, &body);
    pthread_attr_destroy(&attributes);
    CHECK_EQ(status, 0);
    if (status == 0) {
        pthread_join(thread, nullptr);
    }
}

// A chain of `depth` nested groups, each translating by (1, 0), around one set-clip item at `clip`.
std::shared_ptr<const LayerTree> chain(size_t depth, const litehtml::position& clip) {
    Layer root;
    root.kind = Layer::Kind::Root;
    root.box = litehtml::position(0, 0, 100, 100);
    Layer* current = &root;
    for (size_t i = 0; i < depth; i++) {
        auto child = std::make_unique<Layer>();
        child->kind = Layer::Kind::Group;
        child->group.bounds = litehtml::position(0, 0, 10, 10);
        child->group.matrix.tx = 1;
        Layer* next = child.get();
        current->entries.emplace_back(std::move(child));
        current = next;
    }
    current->entries.emplace_back(PaintItem{PaintItem::Kind::SetClip, clip, wr::ClipItem{clip, {}}});
    return std::make_shared<const LayerTree>(100, 100, std::move(root));
}

} // namespace

// Every paint call becomes one item, in the layer the CSS implies, with its arguments and bounds.
WR_TEST(testItemsRecordTheirCalls) {
    FakeRenderHost host;
    wr::WidgetContainer container(host, options());
    litehtml::document::ptr document = layOut(container, everyKindHtml(), 300, kEveryKindTrusted);
    std::shared_ptr<const LayerTree> tree = container.record(*document);
    CHECK(tree != nullptr);
    if (!tree) {
        return;
    }
    CHECK_EQ(tree->width(), double(document->width().value()));
    CHECK_EQ(tree->height(), double(document->height().value()));
    const Layer& root = tree->root();
    CHECK(root.kind == Layer::Kind::Root);
    CHECK(same(root.box, litehtml::position(0, 0, document->width(), document->height())));
    const std::vector<Located> all = items(*tree);
    CHECK_EQ(all.size(), tree->itemCount());

    // Every kind appears.
    for (int kind = 0; kind <= int(PaintItem::Kind::SetClipPath); kind++) {
        const bool present = findKind(all, PaintItem::Kind(kind)) != nullptr;
        CHECK(present);
        if (!present) {
            std::printf("  kind %d not recorded\n", kind);
        }
    }

    // Text and its border, in the root. Text bounds are LHContainer's dirty allowance: pos grown by max(4, 16 / 2) = 8;
    // borders' are their draw position.
    const Located* text = findText(all, "text");
    CHECK(text && text->layer == &root);
    if (text) {
        const wr::TextItem& t = *textOf(*text->item);
        CHECK(t.font != nullptr);
        CHECK(same(text->item->bounds, grown(t.pos, 8)));
        CHECK(t.color == litehtml::web_color(0, 0, 0));
    }
    const Located* borders = findKind(all, PaintItem::Kind::Borders);
    CHECK(borders && borders->layer == &root);
    if (borders) {
        const auto& b = std::get<wr::BordersItem>(borders->item->payload);
        CHECK(float(b.borders.top.width) == 1 && b.borders.top.color == litehtml::web_color(255, 0, 0));
        CHECK(b.borders.top.style == litehtml::border_style_solid);
        CHECK(same(borders->item->bounds, b.drawPos));
        CHECK(!b.root);
    }

    // Backgrounds: bounds are the layer's clip box.
    const Located* fill = nullptr;
    for (const Located& located : all) {
        const auto* f = std::get_if<wr::FillItem>(&located.item->payload);
        if (f && f->color == litehtml::web_color(0, 255, 0)) {
            fill = &located;
        }
    }
    CHECK(fill && fill->layer == &root && fill->item->kind == PaintItem::Kind::SolidFill);
    if (fill) {
        CHECK(same(fill->item->bounds, std::get<wr::FillItem>(fill->item->payload).layer.clip_box));
        CHECK(float(fill->item->bounds.height) == 10);
    }
    const Located* linear = findKind(all, PaintItem::Kind::LinearGradient);
    CHECK(linear && linear->layer == &root);
    if (linear) {
        const auto& g = std::get<wr::LinearGradientItem>(linear->item->payload);
        CHECK(same(linear->item->bounds, g.layer.clip_box));
        CHECK(g.gradient.color_points.size() >= 2);
    }
    CHECK(findKind(all, PaintItem::Kind::RadialGradient) &&
          std::holds_alternative<wr::RadialGradientItem>(findKind(all, PaintItem::Kind::RadialGradient)->item->payload));
    CHECK(findKind(all, PaintItem::Kind::ConicGradient) &&
          std::holds_alternative<wr::ConicGradientItem>(findKind(all, PaintItem::Kind::ConicGradient)->item->payload));

    // The box shadow, grown as LHContainer grows it: blur + |spread| + max(|x|, |y|) + 2 = 4 + 1 + 3 + 2.
    const Located* shadow = findKind(all, PaintItem::Kind::BoxShadow);
    CHECK(shadow && shadow->layer == &root);
    if (shadow) {
        const auto& s = std::get<wr::BoxShadowItem>(shadow->item->payload);
        CHECK(float(s.shadow.x) == 2 && float(s.shadow.y) == 3 && float(s.shadow.blur) == 4 &&
              float(s.shadow.spread) == 1 && !s.shadow.inset);
        CHECK(same(shadow->item->bounds, grown(s.box, 10)));
    }

    // opacity:.5 is a Group with opacity 0.5 holding its text.
    const Located* half = findText(all, "half");
    CHECK(half && half->layer->kind == Layer::Kind::Group && half->layer->group.opacity == 0.5f);
    CHECK(half && half->chain.size() == 2 && half->chain[0] == &root);
    // transform:rotate(10deg) is a Group whose matrix rotates by 10 degrees.
    const Located* turned = findText(all, "turned");
    CHECK(turned && turned->layer->kind == Layer::Kind::Group);
    if (turned) {
        const auto& m = turned->layer->group.matrix;
        const float radians = float(10 * M_PI / 180);
        CHECK(std::fabs(m.a - std::cos(radians)) < 1e-5f && std::fabs(m.b - std::sin(radians)) < 1e-5f);
        CHECK(std::fabs(m.c + std::sin(radians)) < 1e-5f && turned->layer->group.opacity == 1);
    }
    // overflow:hidden with border-radius:4px is a set_clip, in the root, open around its text.
    const Located* clipped = findText(all, "clipped");
    CHECK(clipped && clipped->layer == &root);
    if (clipped) {
        const PaintItem* clip = openClip(*clipped->layer, clipped->index);
        CHECK(clip && clip->kind == PaintItem::Kind::SetClip);
        if (clip && clip->kind == PaintItem::Kind::SetClip) {
            const auto& c = std::get<wr::ClipItem>(clip->payload);
            CHECK(float(c.radius.top_left_x) == 4 && float(c.radius.bottom_right_y) == 4);
            CHECK(same(clip->bounds, c.pos));
        }
    }
    // filter:blur(2px) is a Filter, with its step copied, inside the element's Group.
    const Located* blurred = findText(all, "blurred");
    CHECK(blurred && blurred->layer->kind == Layer::Kind::Filter);
    if (blurred) {
        const Layer& filter = *blurred->layer;
        CHECK(blurred->chain.size() == 3 && blurred->chain[1]->kind == Layer::Kind::Group);
        CHECK_EQ(filter.filter.size(), size_t(1));
        if (!filter.filter.empty()) {
            CHECK(filter.filter[0].kind == litehtml::filter_function::blur);
            CHECK(filter.filter[0].radius.val() == 2 && filter.filter[0].radius.units() == litehtml::css_units_px);
        }
        // A filter's bounds are the union of its entries.
        CHECK(contains(filter.box, blurred->item->bounds));
        CHECK(same(wr::layerBounds(filter), filter.box));
    }
    // backdrop-filter is a Backdrop item in its Group, bounded by the group.
    const Located* backdrop = findKind(all, PaintItem::Kind::Backdrop);
    CHECK(backdrop && backdrop->layer->kind == Layer::Kind::Group);
    if (backdrop) {
        const auto& b = std::get<wr::BackdropItem>(backdrop->item->payload);
        CHECK(b.steps.size() == 1 && b.steps[0].kind == litehtml::filter_function::blur && b.steps[0].radius.val() == 3);
        CHECK(same(backdrop->item->bounds, backdrop->layer->group.bounds));
        CHECK(float(b.box.height) == 10);
    }
    // clip-path is a set_clip_path at the start of its Group, closed by a del_clip at its end.
    const Located* clipPath = findKind(all, PaintItem::Kind::SetClipPath);
    CHECK(clipPath && clipPath->layer->kind == Layer::Kind::Group && clipPath->index == 0);
    if (clipPath) {
        const Layer& group = *clipPath->layer;
        const PaintItem* last = std::get_if<PaintItem>(&group.entries.back());
        CHECK(last && last->kind == PaintItem::Kind::DelClip && last->bounds.empty());
        const Located* c = findText(all, "c");
        CHECK(c && c->layer == &group);
        const auto& path = std::get<wr::ClipPathItem>(clipPath->item->payload).path;
        CHECK(!path.points.empty());
        // A 5px circle: its points' bounds are 10×10.
        CHECK(std::fabs(clipPath->item->bounds.width.value() - 10) < 0.01f &&
              std::fabs(clipPath->item->bounds.height.value() - 10) < 0.01f);
    }
    // A fixed element outside any paint group escapes the clips: suspend_clips, its paint, resume_clips, in the root.
    const Located* fixed = findText(all, "fixed");
    CHECK(fixed && fixed->layer == &root);
    if (fixed) {
        bool suspended = false;
        bool resumed = false;
        for (size_t i = 0; i < root.entries.size(); i++) {
            const PaintItem* item = std::get_if<PaintItem>(&root.entries[i]);
            if (item && item->kind == PaintItem::Kind::SuspendClips && i < fixed->index) {
                suspended = true;
            }
            if (item && item->kind == PaintItem::Kind::ResumeClips && i > fixed->index && suspended) {
                resumed = true;
            }
        }
        CHECK(suspended && resumed);
    }
    // The SVG <rect> paints through draw_path, inside the viewBox's Group, inside draw_isolated's layer, under the
    // svg's set_clip in the root.
    const Located* path = findKind(all, PaintItem::Kind::Path);
    CHECK(path && path->layer->kind == Layer::Kind::Group);
    if (path) {
        const auto& p = std::get<wr::PathItem>(path->item->payload).path;
        CHECK(p.fill && p.fill_color == litehtml::web_color(255, 0, 0) && !p.stroke);
        // Filled only: its 10×10 bounds grown by 1 for antialiasing.
        CHECK(same(path->item->bounds, litehtml::position(-1, -1, 12, 12)));
        CHECK(path->chain.size() == 3 && path->chain[1]->kind == Layer::Kind::Isolated);
        if (path->chain.size() == 3) {
            const Layer* isolated = path->chain[1];
            CHECK(float(isolated->box.width) == 20 && float(isolated->box.height) == 20);
            const PaintItem* clip = openClip(root, indexIn(root, isolated));
            CHECK(clip && clip->kind == PaintItem::Kind::SetClip && same(clip->bounds, isolated->box));
        }
    }
    // The <li>'s disc is a list marker in the root; its handle and base URL are cleared, its font kept.
    const Located* marker = findKind(all, PaintItem::Kind::ListMarker);
    CHECK(marker && marker->layer == &root);
    if (marker) {
        const auto& m = std::get<wr::ListMarkerItem>(marker->item->payload);
        CHECK(m.marker.marker_type == litehtml::list_style_type_disc);
        CHECK(m.marker.baseurl == nullptr && m.marker.font == 0 && m.marker.image.empty());
        CHECK_EQ(m.marker.image.capacity(), std::string().capacity());
        CHECK(m.font != nullptr && !m.image);
        CHECK(same(marker->item->bounds, m.marker.pos));
    }
    // Text bounds hold its shadows as LHContainer's do: 8, plus the shadow's 2 × 2px blur + max(3, 4) = 16.
    const Located* shadowed = findText(all, "shadowed");
    CHECK(shadowed != nullptr);
    if (shadowed) {
        const wr::TextItem& t = *textOf(*shadowed->item);
        CHECK(t.description->shadow_x == 3 && t.description->shadow_y == 4 && t.description->shadow_blur == 2);
        CHECK(same(shadowed->item->bounds, grown(t.pos, 16)));
    }
    // A stroked path reaches past its points, so a horizontal line is never empty: by 2px × max(4, 1) / 2 + 1 = 5
    // around its (0, 5, 10, 0) bounds.
    const Located* line = nullptr;
    for (const Located& located : all) {
        const auto* p = std::get_if<wr::PathItem>(&located.item->payload);
        if (p && p->path.stroke) {
            line = &located;
        }
    }
    CHECK(line != nullptr);
    if (line) {
        CHECK(same(line->item->bounds, litehtml::position(-5, 0, 20, 10)));
    }
    // A path's bounds are on its curve, as CGPathGetPathBoundingBox's: M0 10 C0 0 10 0 10 10 peaks at y = 2.5 (its
    // control points reach 0), then grown by 1.
    const Located* curve = nullptr;
    for (const Located& located : all) {
        const auto* p = std::get_if<wr::PathItem>(&located.item->payload);
        if (p && p->path.fill && p->path.fill_color == litehtml::web_color(0, 255, 0)) {
            curve = &located;
        }
    }
    CHECK(curve != nullptr);
    if (curve) {
        CHECK(same(curve->item->bounds, litehtml::position(-1, 1.5f, 12, 9.5f), 0.001f));
        if (!same(curve->item->bounds, litehtml::position(-1, 1.5f, 12, 9.5f), 0.001f)) {
            std::printf("  curve: %s\n", describe({curve->item->bounds}).c_str());
        }
    }
    // The data: image is an image item of the decoded 3×2 image.
    const Located* image = findKind(all, PaintItem::Kind::Image);
    CHECK(image && image->layer == &root);
    if (image) {
        const auto& i = std::get<wr::ImageItem>(image->item->payload);
        CHECK(i.image.image != nullptr && i.image.width == 3 && i.image.height == 2);
        CHECK(same(image->item->bounds, i.layer.clip_box));
    }
    // The bare clip ops carry no payload and have empty bounds.
    for (const Located& located : all) {
        const PaintItem::Kind kind = located.item->kind;
        if (kind == PaintItem::Kind::DelClip || kind == PaintItem::Kind::SuspendClips ||
            kind == PaintItem::Kind::ResumeClips) {
            CHECK(std::holds_alternative<std::monostate>(located.item->payload) && located.item->bounds.empty());
        }
    }

    // draw_cached answers false, so litehtml paints for real.
    bool painted = false;
    CHECK(!container.draw_cached(0, litehtml::position(0, 0, 1, 1), 1, [&](litehtml::uint_ptr) { painted = true; }));
    CHECK(!painted);

    // dump() lists every entry: a root line, then one line per item and per layer.
    const std::string dump = tree->dump();
    const size_t layerCount = layers(*tree).size() - 1;
    CHECK_EQ(lineCount(dump), 1 + tree->itemCount() + layerCount);
    CHECK(dump.rfind("root 300x", 0) == 0);
    for (const char* name : {"\n  text bounds=", "\n  list-marker ", "\n  image ", "\n  solid-fill ", "\n  linear-gradient ",
                             "\n  radial-gradient ", "\n  conic-gradient ", "\n  borders ", "\n  box-shadow ",
                             "\n      path ", "\n    backdrop ", "\n  set-clip ", "\n  del-clip", "\n  suspend-clips",
                             "\n  resume-clips", "\n    set-clip-path ", "\n  group opacity=0.5 ", "\n    filter steps=",
                             "\n  isolated box=(", "\"half\"", "steps=((blur,"}) {
        const bool found = dump.find(name) != std::string::npos;
        CHECK(found);
        if (!found) {
            std::printf("  dump lacks %s\n", name);
        }
    }
    // Recording is deterministic and leaves the container ready for the next one.
    CHECK_EQ(container.record(*document)->dump(), dump);
}

// A text item carries the font that measured it, and the host's shaping of its text with that font.
WR_TEST(testTextCarriesTheMeasuringFont) {
    FakeRenderHost host;
    wr::WidgetContainer container(host, options());
    litehtml::document::ptr document = layOut(container, "<p>hello <b>bold</b> world</p>");
    std::shared_ptr<const LayerTree> tree = container.record(*document);
    const std::vector<Located> all = items(*tree);
    for (const char* word : {"hello", "bold"}) {
        const Located* located = findText(all, word);
        CHECK(located != nullptr);
        if (!located) {
            continue;
        }
        const wr::TextItem& t = *textOf(*located->item);
        // The font is the very object the host made for the text's description, at create_font.
        const FakeRenderHost::CreatedFont* made = nullptr;
        for (const auto& created : host.createdFonts) {
            if (t.description && created.description.hash() == t.description->hash()) {
                made = &created;
            }
        }
        CHECK(made != nullptr);
        CHECK(made && t.font != nullptr && made->font.lock() == t.font);
        CHECK(t.description && t.description->weight == (std::string(word) == "bold" ? 700 : 400));
        // One glyph per byte, and the advances sum to the measured width.
        CHECK_EQ(t.shaped.glyphs.size(), t.text.size());
        CHECK_EQ(t.shaped.advances.size(), t.text.size());
        double sum = 0;
        for (float advance : t.shaped.advances) {
            sum += advance;
        }
        CHECK(t.font && sum == host.textWidth(*t.font, t.text));
    }
    const Located* hello = findText(all, "hello");
    const Located* bold = findText(all, "bold");
    const Located* world = findText(all, "world");
    CHECK(hello && bold && world && textOf(*hello->item)->font != textOf(*bold->item)->font);
    // Ruling E4: one description object per font, shared by every item in it, and another for another font.
    if (hello && bold && world) {
        CHECK(textOf(*hello->item)->description == textOf(*world->item)->description);
        CHECK(textOf(*hello->item)->description != textOf(*bold->item)->description);
        // The same object across records too: it is the cached font's.
        std::shared_ptr<const LayerTree> second = container.record(*document);
        const std::vector<Located> again = items(*second);
        const Located* helloAgain = findText(again, "hello");
        CHECK(helloAgain && textOf(*helloAgain->item)->description == textOf(*hello->item)->description);
        // And across documents: another document's handle to the cached font shares it.
        litehtml::document::ptr other = layOut(container, "<p>hello</p>");
        std::shared_ptr<const LayerTree> third = container.record(*other);
        const std::vector<Located> elsewhere = items(*third);
        const Located* helloElsewhere = findText(elsewhere, "hello");
        CHECK(helloElsewhere && textOf(*helloElsewhere->item)->description == textOf(*hello->item)->description);
    }
}

// Review Focus 5: the app paints a tree on its own schedule, so it must not point into the document, the container or
// the host. Destroy all three; the tree still walks, and it alone keeps its fonts and images alive.
WR_TEST(testTreeOutlivesItsDocument) {
    const size_t fontsBefore = FakeRenderHost::liveFonts();
    const size_t imagesBefore = FakeRenderHost::liveImages();
    std::shared_ptr<const LayerTree> tree;
    std::string dump;
    std::set<const void*> heldFonts;
    std::set<const void*> heldImages;
    {
        auto host = std::make_unique<FakeRenderHost>();
        auto container = std::make_unique<wr::WidgetContainer>(*host, options());
        litehtml::document::ptr document = layOut(*container,
            std::string("<p style='filter:blur(2px) drop-shadow(1px 2px 3px red)'>blurred <b>bold</b></p>"
                        "<ul><li>item</li></ul>"
                        "<svg width=20 height=20><rect width=10 height=10 fill=red /></svg>"
                        "<div style='backdrop-filter:blur(3px);height:10px'></div><img src='") +
                kPng3x2 + "'>");
        tree = container->record(*document);
        dump = tree->dump();
        // Every font and image the tree holds, by address while they are certainly alive.
        for (const Located& located : items(*tree)) {
            if (const wr::TextItem* t = textOf(*located.item)) {
                heldFonts.insert(t->font.get());
            } else if (const auto* m = std::get_if<wr::ListMarkerItem>(&located.item->payload)) {
                heldFonts.insert(m->font.get());
            } else if (const auto* i = std::get_if<wr::ImageItem>(&located.item->payload)) {
                heldImages.insert(i->image.image.get());
            }
        }
        document.reset();
        container.reset();
        host.reset();
    }
    // The tree alone keeps exactly the fonts and images it holds alive (two fonts: regular and bold).
    CHECK_EQ(heldFonts.size(), size_t(2));
    CHECK_EQ(heldImages.size(), size_t(1));
    CHECK(FakeRenderHost::liveFonts() > fontsBefore);
    CHECK(FakeRenderHost::liveImages() > imagesBefore);
    CHECK_EQ(FakeRenderHost::liveFonts() - fontsBefore, heldFonts.size());
    CHECK_EQ(FakeRenderHost::liveImages() - imagesBefore, heldImages.size());
    // dump() reads every entry, and every field of every payload, filter steps included.
    CHECK_EQ(tree->dump(), dump);
    CHECK(dump.find("filter steps=((blur,") != std::string::npos);
    CHECK(dump.find("(drop-shadow,") != std::string::npos);
    CHECK(dump.find("backdrop bounds=") != std::string::npos);
    const std::vector<Located> all = items(*tree);
    CHECK_EQ(all.size(), tree->itemCount());
    size_t fonts = 0;
    for (const Located& located : all) {
        if (const wr::TextItem* t = textOf(*located.item)) {
            fonts += t->font != nullptr;
            CHECK_EQ(t->shaped.glyphs.size(), t->text.size());
        }
    }
    CHECK(fonts > 0);
    bool sawFilter = false;
    for (const Layer* layer : layers(*tree)) {
        if (layer->kind == Layer::Kind::Filter) {
            sawFilter = true;
            CHECK_EQ(layer->filter.size(), size_t(2));
        }
    }
    CHECK(sawFilter);
    tree.reset();
    CHECK_EQ(FakeRenderHost::liveFonts(), fontsBefore);
    CHECK_EQ(FakeRenderHost::liveImages(), imagesBefore);
}

WR_TEST(testChangedRects) {
    FakeRenderHost host;
    wr::WidgetContainer container(host, options());

    // No previous tree: everything changed.
    {
        litehtml::document::ptr document = layOut(container, "<p>one</p>");
        CHECK(!wr::changedRects(nullptr, *container.record(*document)));
    }
    // Two records of one document: nothing changed.
    const std::string three = "<p>one</p><p>two</p><p>three</p>";
    {
        litehtml::document::ptr document = layOut(container, three);
        std::shared_ptr<const LayerTree> first = container.record(*document);
        std::shared_ptr<const LayerTree> second = container.record(*document);
        auto rects = wr::changedRects(first.get(), *second);
        CHECK(rects && rects->empty());
    }
    // Fonts compare by identity: the same document through another container (another font object) changes its text.
    {
        FakeRenderHost otherHost;
        wr::WidgetContainer other(otherHost, options());
        litehtml::document::ptr mine = layOut(container, three);
        litehtml::document::ptr theirs = layOut(other, three);
        std::shared_ptr<const LayerTree> first = container.record(*mine);
        std::shared_ptr<const LayerTree> second = other.record(*theirs);
        CHECK_EQ(first->dump(), second->dump());
        auto rects = wr::changedRects(first.get(), *second);
        const std::vector<Located> all = items(*second);
        const Located* one = findText(all, "one");
        CHECK(rects && one && anyContains(*rects, one->item->bounds));
    }
    // A text change in the second of three paragraphs: its text item, below the first paragraph.
    {
        Pair pair = recordPair(container, three, "<p>one</p><p>owt</p><p>three</p>");
        auto rects = wr::changedRects(pair.before.get(), *pair.after);
        CHECK(rects && !rects->empty());
        const std::vector<Located> after = items(*pair.after);
        const Located* changed = findText(after, "owt");
        const Located* first = findText(after, "one");
        CHECK(changed && first);
        if (rects && changed && first) {
            CHECK(anyContains(*rects, changed->item->bounds));
            for (const auto& rect : *rects) {
                CHECK(rect.y.value() >= textOf(*first->item)->pos.bottom().value());
            }
            if (!anyContains(*rects, changed->item->bounds)) {
                std::printf("  rects: %s\n", describe(*rects).c_str());
            }
        }
    }
    // An opacity change: the group's bounds, united with what it paints (its text's dirty allowance reaches past them).
    {
        Pair pair = recordPair(container, "<p>a</p><div style='opacity:.5'>x</div>",
                               "<p>a</p><div style='opacity:.6'>x</div>");
        auto rects = wr::changedRects(pair.before.get(), *pair.after);
        const Layer* group = nullptr;
        for (const Layer* layer : layers(*pair.after)) {
            if (layer->kind == Layer::Kind::Group) {
                group = layer;
            }
        }
        CHECK(group && group->group.opacity == 0.6f);
        CHECK(rects && !rects->empty());
        const Located* x = nullptr;
        const std::vector<Located> after = items(*pair.after);
        x = findText(after, "x");
        CHECK(x && x->layer == group);
        if (rects && group && x) {
            const litehtml::position expected = wr::unite(group->group.bounds, x->item->bounds);
            CHECK(contains(expected, group->group.bounds));
            bool all = true;
            for (const auto& rect : *rects) {
                all = all && same(rect, expected);
            }
            CHECK(all);
            if (!all) {
                std::printf("  opacity rects: %s\n", describe(*rects).c_str());
            }
        }
    }
    // A different height: everything changed.
    {
        Pair pair = recordPair(container, "<p>one</p>", "<p>one</p><p>two</p>");
        CHECK(pair.before->height() != pair.after->height());
        CHECK(!wr::changedRects(pair.before.get(), *pair.after));
    }
    // A change inside translate(10px,20px): the text item's rect, offset by (10, 20).
    {
        Pair pair = recordPair(container, "<div style='transform:translate(10px,20px)'>abc</div>",
                               "<div style='transform:translate(10px,20px)'>abd</div>");
        auto rects = wr::changedRects(pair.before.get(), *pair.after);
        const std::vector<Located> after = items(*pair.after);
        const Located* changed = findText(after, "abd");
        CHECK(changed && changed->layer->kind == Layer::Kind::Group);
        CHECK(rects && rects->size() == 1);
        if (rects && rects->size() == 1 && changed) {
            const litehtml::position& b = changed->item->bounds;
            CHECK(same((*rects)[0], litehtml::position(b.x + 10, b.y + 20, b.width, b.height), 0.001f));
        }
    }
    // Nested transforms compose innermost first: scale(2) outside translate(10px,20px), each about its own box.
    {
        const std::string outer = "<div style='transform:scale(2);width:100px'><div style='transform:translate(10px,20px)'>";
        Pair pair = recordPair(container, outer + "abc</div></div>", outer + "abd</div></div>");
        auto rects = wr::changedRects(pair.before.get(), *pair.after);
        const std::vector<Located> after = items(*pair.after);
        const Located* changed = findText(after, "abd");
        CHECK(changed && changed->chain.size() == 3);
        CHECK(rects && rects->size() == 1);
        if (rects && rects->size() == 1 && changed && changed->chain.size() == 3) {
            // scale(2) about the outer box's centre (its transform origin); its group bounds are that box.
            const litehtml::position& box = changed->chain[1]->group.bounds;
            const float ox = box.x.value() + box.width.value() / 2;
            const float oy = box.y.value() + box.height.value() / 2;
            const litehtml::position& b = changed->item->bounds;
            const litehtml::position expected(2 * (b.x.value() + 10 - ox) + ox, 2 * (b.y.value() + 20 - oy) + oy,
                                              2 * b.width.value(), 2 * b.height.value());
            CHECK(same((*rects)[0], expected, 0.01f));
            if (!same((*rects)[0], expected, 0.01f)) {
                std::printf("  nested: %s expected %s\n", describe(*rects).c_str(), describe({expected}).c_str());
            }
        }
    }
    // A rotation maps the rect's corners: rotate(90deg) about the box's centre takes (x, y) to (-y, x) around it.
    {
        const std::string turned = "<div style='transform:rotate(90deg);width:40px'>";
        Pair pair = recordPair(container, turned + "abc</div>", turned + "abd</div>");
        auto rects = wr::changedRects(pair.before.get(), *pair.after);
        const std::vector<Located> after = items(*pair.after);
        const Located* changed = findText(after, "abd");
        CHECK(rects && rects->size() == 1 && changed);
        if (rects && rects->size() == 1 && changed) {
            const litehtml::position& box = changed->layer->group.bounds;
            const float ox = box.x.value() + box.width.value() / 2;
            const float oy = box.y.value() + box.height.value() / 2;
            const litehtml::position& b = changed->item->bounds;
            const litehtml::position expected(ox - (b.y.value() + b.height.value() - oy), oy + (b.x.value() - ox),
                                              b.height.value(), b.width.value());
            CHECK(same((*rects)[0], expected, 0.01f));
            if (!same((*rects)[0], expected, 0.01f)) {
                std::printf("  rotated: %s expected %s\n", describe(*rects).c_str(), describe({expected}).c_str());
            }
        }
    }
    // A change inside a blur spreads by the filter's reach: ceil(2px × 3) on every side.
    {
        Pair pair = recordPair(container, "<div style='filter:blur(2px)'>abc</div>",
                               "<div style='filter:blur(2px)'>abd</div>");
        auto rects = wr::changedRects(pair.before.get(), *pair.after);
        const std::vector<Located> after = items(*pair.after);
        const Located* changed = findText(after, "abd");
        CHECK(rects && rects->size() == 1 && changed && changed->layer->kind == Layer::Kind::Filter);
        if (rects && rects->size() == 1 && changed) {
            CHECK(same((*rects)[0], grown(changed->item->bounds, 6), 0.001f));
        }
    }
    // A group whose matrix changes reports everything it paints, beyond its own bounds too (a child's shadow).
    {
        const std::string child = "<div style='box-shadow:0 0 0 20px red;height:10px'></div></div>";
        Pair pair = recordPair(container, "<div style='transform:translate(1px,0)'>" + child,
                               "<div style='transform:translate(2px,0)'>" + child);
        auto rects = wr::changedRects(pair.before.get(), *pair.after);
        const std::vector<Located> after = items(*pair.after);
        const Located* shadow = findKind(after, PaintItem::Kind::BoxShadow);
        CHECK(rects && shadow && shadow->layer->kind == Layer::Kind::Group);
        if (rects && shadow) {
            const litehtml::position& b = shadow->item->bounds;
            CHECK(!contains(shadow->layer->group.bounds, b));
            CHECK(anyContains(*rects, litehtml::position(b.x + 2, b.y, b.width, b.height)));
        }
    }
}

// A backdrop filters what is painted behind it: a change it samples changes it too, though its own item is equal, and
// a backdrop reached that way can reach another. Each is reported grown by its blur's reach, ceil(2px × 3) = 6.
WR_TEST(testChangedRectsCoverBackdrops) {
    FakeRenderHost host;
    wr::WidgetContainer container(host, options());
    // Text at (8, 8, 24, 16), so its rect (0, 0, 40, 32); backdrop A over it at (8, 8, 100, 40), so sampling
    // (2, 2, 112, 52); backdrop B at (8, 58, 100, 20), sampling (2, 52, 112, 32): clear of the text, but overlapping A's.
    auto page = [](const char* text, bool chained) {
        return std::string("<div style='position:relative'><p style='margin:0'>") + text + "</p>"
               "<div style='position:absolute;left:0;top:0;width:100px;height:40px;backdrop-filter:blur(2px)'>"
               "</div>" +
               (chained ? "<div style='position:absolute;left:0;top:50px;width:100px;height:20px;"
                          "backdrop-filter:blur(2px)'></div>"
                        : "") +
               "</div><div style='height:200px'></div>"
               "<div style='height:20px;backdrop-filter:blur(2px)'></div>";
    };
    auto backdrops = [](const LayerTree& tree) {
        std::vector<litehtml::position> found;
        for (const Located& located : items(tree)) {
            if (located.item->kind == PaintItem::Kind::Backdrop) {
                found.push_back(located.item->bounds);
            }
        }
        return found;
    };
    // The backdrop whose top is at `y` (they paint positioned ones last, so not in document order); empty if none.
    auto at = [](const std::vector<litehtml::position>& found, float y) {
        for (const auto& r : found) {
            if (r.y.value() == y) {
                return r;
            }
        }
        return litehtml::position();
    };
    auto has = [](const std::vector<litehtml::position>& rects, const litehtml::position& rect) {
        for (const auto& r : rects) {
            if (same(r, rect)) {
                return true;
            }
        }
        return false;
    };

    // The text under A changes: its rect, and A grown by its reach; the far backdrop, which samples nothing that
    // changed, is not added.
    {
        Pair pair = recordPair(container, page("abc", false), page("abd", false));
        auto rects = wr::changedRects(pair.before.get(), *pair.after);
        const std::vector<litehtml::position> found = backdrops(*pair.after);
        const std::vector<Located> after = items(*pair.after);
        const Located* text = findText(after, "abd");
        CHECK(rects && found.size() == 2 && text);
        if (rects && found.size() == 2 && text) {
            const litehtml::position a = at(found, 8);
            const litehtml::position far = at(found, 224);
            CHECK(same(a, litehtml::position(8, 8, 100, 40)));
            CHECK(same(far, litehtml::position(8, 224, 284, 20)));
            CHECK(has(*rects, text->item->bounds));
            CHECK(has(*rects, grown(a, 6)));
            CHECK(!anyContains(*rects, far));
            CHECK_EQ(rects->size(), size_t(2));
            if (rects->size() != 2) {
                std::printf("  rects: %s\n", describe(*rects).c_str());
            }
        }
    }
    // Chained: B samples A's rect, so B is added too, though it overlaps nothing that changed itself.
    {
        Pair pair = recordPair(container, page("abc", true), page("abd", true));
        auto rects = wr::changedRects(pair.before.get(), *pair.after);
        const std::vector<litehtml::position> found = backdrops(*pair.after);
        CHECK(rects && found.size() == 3);
        if (rects && found.size() == 3) {
            const litehtml::position b = at(found, 58);
            CHECK(same(b, litehtml::position(8, 58, 100, 20)));
            CHECK(has(*rects, grown(at(found, 8), 6)));
            CHECK(has(*rects, grown(b, 6)));
            CHECK(!anyContains(*rects, at(found, 224)));
            CHECK_EQ(rects->size(), size_t(3));
        }
    }
    // Nothing under a backdrop changes: the text change is far from every backdrop, and none is added.
    {
        const std::string far = "<div style='height:20px;backdrop-filter:blur(2px)'></div>"
                                "<div style='height:200px'></div><p>";
        Pair pair = recordPair(container, far + "abc</p>", far + "abd</p>");
        auto rects = wr::changedRects(pair.before.get(), *pair.after);
        const std::vector<Located> after = items(*pair.after);
        const Located* text = findText(after, "abd");
        CHECK(rects && rects->size() == 1 && text);
        if (rects && rects->size() == 1 && text) {
            CHECK(same((*rects)[0], text->item->bounds));
        }
    }
    // A backdrop that moves is covered where it was and where it is, by its own item and by what it samples.
    {
        const std::string text = "<div style='position:relative'><p style='margin:0'>abc</p>"
                                 "<div style='position:absolute;width:100px;height:20px;backdrop-filter:blur(2px);top:";
        Pair pair = recordPair(container, text + "0'></div></div>", text + "2px'></div></div>");
        auto rects = wr::changedRects(pair.before.get(), *pair.after);
        const std::vector<litehtml::position> was = backdrops(*pair.before);
        const std::vector<litehtml::position> is = backdrops(*pair.after);
        CHECK(rects && was.size() == 1 && is.size() == 1);
        if (rects && was.size() == 1 && is.size() == 1) {
            CHECK(anyContains(*rects, was[0]) && anyContains(*rects, is[0]));
        }
    }
}

// Ruling E3: past 64 Backdrop items in a tree, everything changed. At 64 the result is still per rect: the changed text
// and the backdrop over it (grown by 6), none of the others.
WR_TEST(testChangedRectsBoundBackdrops) {
    FakeRenderHost host;
    wr::WidgetContainer container(host, options());
    auto page = [](const char* text, int backdrops) {
        std::string html = std::string("<div style='position:relative'><p style='margin:0'>") + text + "</p>"
                           "<div style='position:absolute;left:0;top:0;width:100px;height:20px;"
                           "backdrop-filter:blur(2px)'></div></div><div style='height:200px'></div>";
        for (int i = 1; i < backdrops; i++) {
            html += "<div style='height:4px;margin-bottom:20px;backdrop-filter:blur(2px)'></div>";
        }
        return html;
    };
    auto count = [](const LayerTree& tree) {
        size_t n = 0;
        for (const Located& located : items(tree)) {
            n += located.item->kind == PaintItem::Kind::Backdrop;
        }
        return n;
    };
    {
        Pair pair = recordPair(container, page("abc", 65), page("abd", 65));
        CHECK_EQ(count(*pair.after), size_t(65));
        CHECK(!wr::changedRects(pair.before.get(), *pair.after));
    }
    {
        Pair pair = recordPair(container, page("abc", 64), page("abd", 64));
        CHECK_EQ(count(*pair.after), size_t(64));
        auto rects = wr::changedRects(pair.before.get(), *pair.after);
        const std::vector<Located> after = items(*pair.after);
        const Located* text = findText(after, "abd");
        CHECK(rects && text && rects->size() == 2);
        if (rects && text && rects->size() == 2) {
            CHECK(same((*rects)[0], text->item->bounds));
            CHECK(same((*rects)[1], grown(litehtml::position(8, 8, 100, 20), 6)));
        } else if (rects) {
            std::printf("  rects: %s\n", describe(*rects).c_str());
        }
    }
}

// Finding I1: a list marker never holds its URL, not even as a cleared buffer. Ruling 7 allows a ~60 KiB data: URL in
// one list-style-image rule over 10,000 <li>s; a copied-then-cleared string would keep its 60 KiB buffer per marker.
WR_TEST(testMarkersKeepNoUrl) {
    FakeRenderHost host;
    wr::WidgetContainer container(host, options());
    // A PNG's header (widget-sandbox v0.3.0 reads an image's size from its bytes), then zeros.
    const std::string url = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAAB" + std::string(60000, 'A');
    // list-style-image is out of profile 1, so the marker's image comes through the trusted sheet.
    litehtml::document::ptr document =
        layOut(container, "<ul><li>a</li><li>b</li><li>c</li></ul>", 300, "li { list-style-image: url(" + url + ") }");
    std::shared_ptr<const LayerTree> tree = container.record(*document);
    size_t markers = 0;
    for (const Located& located : items(*tree)) {
        if (const auto* m = std::get_if<wr::ListMarkerItem>(&located.item->payload)) {
            markers++;
            CHECK(m->marker.image.empty());
            CHECK_EQ(m->marker.image.capacity(), std::string().capacity());
            CHECK(m->marker.baseurl == nullptr && m->marker.font == 0);
        }
    }
    CHECK_EQ(markers, size_t(3));
    // The URL did reach the container and the host, which decoded the header's 1 × 1.
    CHECK(host.decodedMimeTypes == std::vector<std::string>{"image/png"});
}

// A refused image paints nothing, and its element keeps the size its attributes give it.
WR_TEST(testRefusedImagePaintsNothing) {
    FakeRenderHost host;
    wr::WidgetContainer container(host, options());
    litehtml::document::ptr document = layOut(container, "<img src=http://x width=10 height=10>");
    const uint64_t refusedBeforeRecord = container.refusedLoads();
    CHECK(refusedBeforeRecord > 0);
    std::shared_ptr<const LayerTree> tree = container.record(*document);
    CHECK(findKind(items(*tree), PaintItem::Kind::Image) == nullptr);
    CHECK(tree->dump().find("image") == std::string::npos);
    // Painting it is a request too, refused and counted as LHContainer counts it.
    CHECK(container.refusedLoads() > refusedBeforeRecord);
    const std::string layout = wr::dumpLayout(*document);
    const size_t img = layout.find("img ");
    CHECK(img != std::string::npos);
    if (img != std::string::npos) {
        const std::string line = layout.substr(img, layout.find('\n', img) - img);
        CHECK(line.size() > 6 && line.compare(line.size() - 6, 6, " 10 10") == 0);
    }
    CHECK(host.decodedMimeTypes.empty());
}

// Layers nest as deep as the elements that open them, and the app may drop a tree on any thread: counting, dumping,
// diffing and destroying walk with explicit stacks. 30,000 levels on a 512 KiB stack, where a frame per level would
// need several times that.
WR_TEST(testDeepLayersDoNotRecurse) {
    runOnSmallStack([] {
        const size_t depth = 30000;
        std::shared_ptr<const LayerTree> before = chain(depth, litehtml::position(1, 2, 3, 4));
        std::shared_ptr<const LayerTree> after = chain(depth, litehtml::position(1, 2, 3, 5));
        CHECK_EQ(before->itemCount(), size_t(1));
        const std::string dump = after->dump();
        CHECK_EQ(lineCount(dump), 1 + depth + 1);
        auto unchanged = wr::changedRects(before.get(), *chain(depth, litehtml::position(1, 2, 3, 4)));
        CHECK(unchanged && unchanged->empty());
        // The clip moved by every group's (1, 0): (1 + 30000, 2).
        auto rects = wr::changedRects(before.get(), *after);
        CHECK(rects && rects->size() == 2);
        if (rects && rects->size() == 2) {
            CHECK(float((*rects)[0].x) == 30001 && float((*rects)[0].y) == 2 && float((*rects)[0].height) == 4);
            CHECK(float((*rects)[1].height) == 5);
        }
        before.reset();
        after.reset();
    });
}
