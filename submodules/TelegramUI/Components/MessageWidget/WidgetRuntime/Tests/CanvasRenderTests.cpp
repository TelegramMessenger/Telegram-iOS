// A canvas in the layout and the layer tree (V5d plan, Task 4): litehtml lays a <canvas> out as an image of its width
// and height (the fork's twcanvas: path), and the published tree draws the bitmap's snapshot as an image item there.
#include <string>
#include <variant>
#include <vector>

#include "Sources/Render/LayerTree.h"
#include "Tests/FakeRenderHost.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

using wr_test::FakeCanvas;
using wr_test::FakeRenderHost;
using wr_test::RenderEnv;

namespace {

void collectImages(const wr::Layer& layer, std::vector<const wr::PaintItem*>& out) {
    for (const auto& entry : layer.entries) {
        if (const wr::PaintItem* item = std::get_if<wr::PaintItem>(&entry)) {
            if (item->kind == wr::PaintItem::Kind::Image) {
                out.push_back(item);
            }
        } else {
            collectImages(*std::get<std::unique_ptr<wr::Layer>>(entry), out);
        }
    }
}

std::vector<const wr::PaintItem*> images(RenderEnv& env) {
    env.flush();
    std::vector<const wr::PaintItem*> out;
    if (auto tree = env.render().layerTree()) {
        collectImages(tree->root(), out);
    }
    return out;
}

std::string box(RenderEnv& env, const char* id) {
    return env.env().eval(std::string("var r = ") + id + ".getBoundingClientRect(); [r.width, r.height].join('x')");
}

const char* const kPage =
    "<!doctype html><html><head></head><body>"
    "<canvas id=a width=160 height=120></canvas><canvas id=b width=160 height=120 style=\"width:80px\"></canvas>"
    "<canvas id=c></canvas>"
    "<script>for (const e of document.querySelectorAll('[id]')) window[e.id] = e;</script></body></html>";

} // namespace

WR_TEST(testACanvasLaysOutAtItsAttributes) {
    RenderEnv env(kPage);
    CHECK_EQ(box(env, "a"), std::string("160x120"));
    CHECK_EQ(box(env, "b"), std::string("80x60"));
    CHECK_EQ(box(env, "c"), std::string("300x150"));
    env.env().eval("c.width = 40; c.height = 10; 1");
    CHECK_EQ(box(env, "c"), std::string("40x10"));
    // A src the widget sets on a canvas is not a source: it stays a canvas.
    env.env().eval("c.setAttribute('src', 'data:image/png;base64,AAAA'); 1");
    CHECK_EQ(box(env, "c"), std::string("40x10"));
}

WR_TEST(testAPaintedCanvasIsAnImageItem) {
    RenderEnv env(kPage);
    // Nothing drawn: no bitmap, no image item.
    CHECK(images(env).empty());
    env.env().eval("a.getContext('2d').fillRect(0, 0, 10, 10); 1");
    std::vector<const wr::PaintItem*> found = images(env);
    CHECK_EQ(found.size(), size_t(1));
    if (found.size() == 1) {
        const auto& item = std::get<wr::ImageItem>(found[0]->payload);
        CHECK(item.image.image != nullptr && item.image.width == 160 && item.image.height == 120);
        CHECK(item.image.image == FakeCanvas::live().back()->snapshot());
        CHECK(found[0]->bounds.width.value() == 160 && found[0]->bounds.height.value() == 120);
    }
}

WR_TEST(testRepaintingRepublishes) {
    RenderEnv env(kPage);
    env.env().eval("var ctx = a.getContext('2d'); ctx.fillRect(0, 0, 10, 10); 1");
    std::vector<const wr::PaintItem*> first = images(env);
    CHECK_EQ(first.size(), size_t(1));
    const void* before = first.empty() ? nullptr : std::get<wr::ImageItem>(first[0]->payload).image.image.get();
    env.render().takeChangedRects();
    env.env().eval("ctx.fillRect(20, 20, 10, 10); 1");
    std::vector<const wr::PaintItem*> second = images(env);
    CHECK_EQ(second.size(), size_t(1));
    const void* after = second.empty() ? nullptr : std::get<wr::ImageItem>(second[0]->payload).image.image.get();
    CHECK(before != nullptr && after != nullptr && before != after);
    // Only the canvas's box changed.
    std::optional<std::vector<litehtml::position>> changed = env.render().takeChangedRects();
    CHECK(changed.has_value() && !changed->empty());
    if (changed) {
        for (const litehtml::position& r : *changed) {
            CHECK(r.width.value() <= 160 && r.height.value() <= 120);
        }
    }
    // A canvas that is not in the document paints without a rebuild.
    const uint64_t builds = env.render().buildCount();
    env.env().eval("var off = document.createElement('canvas').getContext('2d'); off.fillRect(0, 0, 1, 1); 1");
    env.flush();
    CHECK_EQ(env.render().buildCount(), builds);
}

/// A repaint republishes the canvas's box alone: no build, no new mirror, only Content operations, and the published tree
/// is what a fresh mirror of the document draws, the canvas's current snapshot included.
WR_TEST(testARepaintIsTheCanvasBoxAlone) {
    RenderEnv env(kPage);
    env.env().eval("var ctx = a.getContext('2d'); ctx.fillRect(0, 0, 10, 10); 1");
    env.flush();
    const uint64_t builds = env.render().buildCount();
    const uint64_t walks = env.render().mirrorWalks();
    for (int frame = 0; frame < 3; frame++) {
        env.env().eval("ctx.fillRect(" + std::to_string(20 + frame * 10) + ", 20, 10, 10); 1");
        env.flush();
        CHECK_EQ(env.render().buildCount(), builds);
        CHECK_EQ(env.render().mirrorWalks(), walks);
        const std::vector<wr::LayerOp>& ops = env.render().layerOps();
        CHECK(!ops.empty());
        for (const wr::LayerOp& op : ops) {
            CHECK(op.kind == wr::LayerOp::Content);
        }
        std::vector<const wr::PaintItem*> found = images(env);
        CHECK_EQ(found.size(), size_t(1));
        if (found.size() == 1) {
            CHECK(std::get<wr::ImageItem>(found[0]->payload).image.image == FakeCanvas::live().back()->snapshot());
        }
        std::shared_ptr<const wr::LayerTree> fresh = env.render().freshMirrorForTesting();
        CHECK(fresh && env.render().layerTree() && fresh->dump() == env.render().layerTree()->dump());
    }
}

/// A repaint in the same flush as a patch (a text change, an element inserted) is published with it: the canvas draws
/// its current snapshot, and nothing rebuilds.
WR_TEST(testARepaintRidesAPatch) {
    RenderEnv env("<!doctype html><html><head></head><body><p id=p>text</p><canvas id=a width=40 height=30></canvas>"
                  "<script>for (const e of document.querySelectorAll('[id]')) window[e.id] = e;</script></body></html>");
    env.env().eval("var ctx = a.getContext('2d'); ctx.fillRect(0, 0, 10, 10); 1");
    env.flush();
    const uint64_t builds = env.render().buildCount();
    for (const char* change : {"p.firstChild.data = 'other'", "p.appendChild(document.createElement('b')).textContent = 'b'"}) {
        env.env().eval(std::string("ctx.fillRect(20, 20, 5, 5); ") + change + "; 1");
        std::vector<const wr::PaintItem*> found = images(env);
        CHECK_EQ(found.size(), size_t(1));
        if (found.size() == 1) {
            CHECK(std::get<wr::ImageItem>(found[0]->payload).image.image == FakeCanvas::live().back()->snapshot());
        }
        CHECK_EQ(env.render().buildCount(), builds);
    }
}

/// Review Focus 3: an animation loop keeps one bitmap and a bounded number of snapshots.
WR_TEST(testAnAnimationLoopStaysFlat) {
    RenderEnv env(kPage);
    env.env().eval("var ctx = a.getContext('2d'); 1");
    const size_t imagesBefore = FakeRenderHost::liveImages();
    for (int frame = 0; frame < 1000; frame++) {
        env.env().eval("ctx.clearRect(0, 0, 160, 120); ctx.fillRect(" + std::to_string(frame % 100) + ", 0, 10, 10); 1");
        env.flush();
    }
    CHECK_EQ(FakeRenderHost::liveCanvases(), size_t(1));
    CHECK(FakeRenderHost::liveImages() <= imagesBefore + 2);
    CHECK_EQ(images(env).size(), size_t(1));
}

/// V5d final review, M10 (re-graded Important): `canvas.width = canvas.width`, the clear idiom, republishes the canvas
/// transparent even when nothing is drawn after it.
WR_TEST(testResettingTheSizeClearsThePublishedCanvas) {
    RenderEnv env(kPage);
    env.env().eval("a.getContext('2d').fillRect(0, 0, 10, 10); 1");
    CHECK_EQ(images(env).size(), size_t(1));
    env.env().eval("a.width = a.width; 1");
    CHECK(images(env).empty());
}
