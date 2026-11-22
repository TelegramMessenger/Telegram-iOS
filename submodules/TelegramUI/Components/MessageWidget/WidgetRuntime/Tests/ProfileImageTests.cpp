// Profile 1's images in the renderer's copy (V4 plan, Task 6): an <img> whose src the profile refuses renders the 48 px
// placeholder (RB §3.5) with data-tg-placeholder, alike in a rebuild, a patch and the render input; the widget's DOM keeps
// the src it wrote, and nothing is loaded.
#include <cstdio>
#include <string>
#include <tuple>
#include <variant>
#include <vector>

#include "Sources/Render/LayerTree.h"
#include "Tests/FakeRenderHost.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

using wr_test::RenderEnv;

namespace {

// A 3×2 RGBA PNG (signature, IHDR, IDAT, IEND).
const char* const kPng3x2 =
    "data:image/png;base64,"
    "iVBORw0KGgoAAAANSUhEUgAAAAMAAAACCAYAAACddGYaAAAAEUlEQVR4nGP4z8DwH4YZkDkAm34L9XKwuTwAAAAASUVORK5CYII=";

void collectImages(const wr::Layer& layer, size_t& count) {
    for (const auto& entry : layer.entries) {
        if (const wr::PaintItem* item = std::get_if<wr::PaintItem>(&entry)) {
            count += item->kind == wr::PaintItem::Kind::Image ? 1 : 0;
        } else {
            collectImages(*std::get<std::unique_ptr<wr::Layer>>(entry), count);
        }
    }
}

size_t imageItems(RenderEnv& env) {
    size_t count = 0;
    if (auto tree = env.render().layerTree()) {
        collectImages(tree->root(), count);
    }
    return count;
}

void checkEval(RenderEnv& env, const std::string& code, const std::string& want) {
    const std::string got = env.env().eval(code);
    if (got != want) {
        std::printf("    %s\n    got  %s\n    want %s\n", code.c_str(), got.c_str(), want.c_str());
    }
    CHECK(got == want);
}

void expectMatchesRebuild(RenderEnv& env, const char* what) {
    auto [layout, input, tree] = wr_test::rebuildDump(env);
    const bool same = env.render().layoutDump() == layout && env.render().renderInput() == input &&
                      env.render().layerTree()->dump() == tree;
    if (!same) {
        std::printf("    %s: the flush differs from a rebuild\n", what);
    }
    CHECK(same);
}

} // namespace

WR_TEST(testARefusedImageRendersThePlaceholder) {
    RenderEnv env("<!doctype html><html><head><style>body{margin:0} #q{width:8px;height:8px;background:url(twcanvas:1:4:4)}"
                  "</style></head><body><img id=r src=\"https://x/p.png\" style=\"display:block\"><div id=q></div>"
                  "<script>window.$ = id => document.getElementById(id);</script></body></html>");
    CHECK(env.render().renderInput().find("src=\"twplaceholder:\" data-tg-placeholder=\"\"") != std::string::npos);
    CHECK(env.render().renderInput().find("https://x") == std::string::npos);
    checkEval(env, "var b = $('r').getBoundingClientRect(); [b.width, b.height].join()", "48,48");
    CHECK_EQ(env.render().refusedLoads(), uint64_t(0));
    // The placeholder, and nothing for the canvas URL a widget wrote (its declaration is dropped).
    CHECK_EQ(imageItems(env), size_t(1));
    checkEval(env, "getComputedStyle($('q')).backgroundImage", "none");
    checkEval(env, "$('r').getAttribute('src')", "https://x/p.png");
    // To an allowed source, and back: each flush is what a rebuild makes.
    env.env().eval(std::string("$('r').src = '") + kPng3x2 + "'; 1");
    env.flush();
    CHECK(env.render().renderInput().find("data-tg-placeholder") == std::string::npos);
    checkEval(env, "var b = $('r').getBoundingClientRect(); [b.width, b.height].join()", "3,2");
    expectMatchesRebuild(env, "allowed");
    env.env().eval("$('r').src = 'data:image/svg+xml,<svg/>'; 1");
    env.flush();
    CHECK(env.render().renderInput().find("src=\"twplaceholder:\" data-tg-placeholder=\"\"") != std::string::npos);
    expectMatchesRebuild(env, "refused again");
    // A widget's own internal URLs are refused like any other.
    env.env().eval("$('r').src = 'twcanvas:1:4:4'; 1");
    env.flush();
    // Its natural size once its load fired (widget-sandbox v0.2.3: pending until then).
    env.env().drain();
    checkEval(env, "var b = $('r').getBoundingClientRect(); [b.width, b.height, $('r').naturalWidth].join()", "48,48,48");
    expectMatchesRebuild(env, "twcanvas");
}

/// RB §8.5: an img with no src gets neither the placeholder nor the marker.
WR_TEST(testAnImageWithoutASourceHasNoPlaceholder) {
    RenderEnv env("<!doctype html><img id=n alt=x><img id=e src=\"\">");
    const std::string input = env.render().renderInput();
    CHECK(input.find("<img id=\"n\" alt=\"x\">") != std::string::npos);
    CHECK(input.find("<img id=\"e\" src=\"twplaceholder:\" data-tg-placeholder=\"\">") != std::string::npos);
}
