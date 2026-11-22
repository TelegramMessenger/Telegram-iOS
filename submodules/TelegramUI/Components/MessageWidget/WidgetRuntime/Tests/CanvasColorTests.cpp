// The canvas colour (v0.1.1 plan, Task 6; CSS 2.1 §14.2, sdk-v1 §2.4 "A background the widget sets on its root or on
// its body paints the whole bubble"): every published tree carries the root's background colour, or the body's when the
// root has none, so the host can paint it under the tiles where the bubble is taller than the document (the 50 pt
// minimum, a fixed height anchor).
#include <cstdio>
#include <memory>
#include <string>

#include "Sources/Render/LayerTree.h"
#include "Sources/Render/RenderTree.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

using wr_test::RenderEnv;

namespace {

/// `#rrggbbaa`, or `none` without a tree.
std::string canvas(RenderEnv& env) {
    const std::shared_ptr<const wr::LayerTree> tree = env.render().layerTree();
    if (!tree) {
        return "none";
    }
    const litehtml::web_color color = tree->canvasColor();
    char text[16];
    std::snprintf(text, sizeof(text), "#%02x%02x%02x%02x", color.red, color.green, color.blue, color.alpha);
    return text;
}

void edit(RenderEnv& env, const std::string& script) {
    CHECK_EQ(env.env().eval("(() => { " + script + "; })(); 'ok'"), std::string("ok"));
    env.flush();
}

} // namespace

/// No background anywhere: transparent, so the bubble shows.
WR_TEST(testNoBackgroundIsTransparent) {
    RenderEnv env("<!doctype html><p>x</p>");
    CHECK_EQ(canvas(env), std::string("#00000000"));
}

/// The body's background propagates when the root has none; the root's own wins over the body's.
WR_TEST(testTheCanvasIsTheRootsBackgroundOrTheBodys) {
    RenderEnv body("<!doctype html><style>body{background:#123456}</style><p>x</p>");
    CHECK_EQ(canvas(body), std::string("#123456ff"));
    RenderEnv root("<!doctype html><style>html{background:rgba(171,205,239,.5)} body{background:#123456}</style><p>x</p>");
    CHECK_EQ(canvas(root), std::string("#abcdef80"));
    RenderEnv current("<!doctype html><style>body{color:#010203;background:currentColor}</style><p>x</p>");
    CHECK_EQ(canvas(current), std::string("#010203ff"));
}

/// A patch that changes the body's background (no rebuild) republishes the colour, and a cleared one is transparent.
WR_TEST(testAPatchedBackgroundRepublishesTheCanvas) {
    RenderEnv env("<!doctype html><style>.a{background:#ff0000}</style><body class=a><p>x</p></body>");
    CHECK_EQ(canvas(env), std::string("#ff0000ff"));
    edit(env, "document.body.style.background = '#00ff00'");
    CHECK_EQ(canvas(env), std::string("#00ff00ff"));
    edit(env, "document.body.style.background = ''; document.body.className = ''");
    CHECK_EQ(canvas(env), std::string("#00000000"));
}
