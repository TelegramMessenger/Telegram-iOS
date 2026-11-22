// The host-side runtime API (M1d plan, Task 1): what a real host reads besides the layer tree. The content size it
// sizes the widget by, a work observer that feeds main's wait meter while a step runs, and recording snapped at the
// scale the tree will be drawn at.
#include <cmath>
#include <cstdint>
#include <optional>
#include <memory>
#include <string>
#include <vector>

#include <litehtml/types.h>

#include "Sources/Render/LayerTree.h"
#include "Sources/Render/RenderTree.h"
#include "Sources/Runtime/Runtime.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

using wr_test::findText;
using wr_test::HostEnv;
using wr_test::RenderEnv;

namespace {

const char* const kFractional =
    "<!doctype html><html><head></head><body><div style=\"padding-top:0.3px\">x</div></body></html>";

double textY(RenderEnv& env) {
    std::shared_ptr<const wr::LayerTree> tree = env.render().layerTree();
    const wr::TextItem* text = tree ? findText(*tree, "x") : nullptr;
    return text ? double(text->pos.y.value()) : NAN;
}

} // namespace

WR_TEST(testSnapScaleMovesFractionalText) {
    wr::RenderOptions one;
    wr::RenderOptions three;
    three.pixelSnapScale = 3;
    RenderEnv a(kFractional, one);
    RenderEnv b(kFractional, three);
    const double ya = textY(a);
    const double yb = textY(b);
    CHECK(!std::isnan(ya) && !std::isnan(yb));
    // 4 px of body padding and 0.3 px: whole pixels at 1×, thirds at 3×.
    CHECK(std::fabs(ya - std::round(ya)) < 1e-4);
    CHECK(std::fabs(yb * 3 - std::round(yb * 3)) < 1e-4);
    CHECK(std::fabs(ya - yb) > 1e-4);
    // A patch records at the same scale as the build.
    CHECK_EQ(b.env().eval("document.querySelector('div').setAttribute('style', 'padding-top:0.6px'); 1"), std::string("1"));
    b.flush();
    const double patched = textY(b);
    CHECK(std::fabs(patched * 3 - std::round(patched * 3)) < 1e-4);
    // The scale is litehtml's thread-local: a flush leaves it as it found it.
    CHECK(litehtml::pixel_snap_scale() == 1.0f);
}

WR_TEST(testContentSizeIsTheLayoutsContent) {
    RenderEnv narrow("<!doctype html><html><head></head><body><div style=\"width:120px;height:40px\"></div></body></html>");
    std::optional<wr::ContentSize> size = narrow.render().contentSize();
    CHECK(size.has_value());
    if (!size) {
        return;
    }
    CHECK(size->width >= 120 && size->width < 300);
    CHECK(std::fabs(size->height - double(narrow.render().layerTree()->height())) < 1e-4);
    RenderEnv wide("<!doctype html><html><head></head><body><div style=\"width:200px;height:40px\"></div></body></html>");
    std::optional<wr::ContentSize> wider = wide.render().contentSize();
    CHECK(wider && wider->width > size->width);
    // Nothing is published before the first build.
    wr::RenderTree fresh(narrow.ctx(), narrow.host(), narrow.options());
    CHECK(!fresh.contentSize().has_value());
}

// The host's sheet (the spec renderer's root CSS, `body { margin: 8px }`, widget-sandbox v0.1.0) goes with the master
// sheet, as LHDocument's does (MasterWithCSS): the author's own body margin wins over it, and a page that sets none
// gets the host's.
WR_TEST(testTheAuthorsMarginWinsOverTheHostSheet) {
    RenderEnv own("<!doctype html><html><head><style>body{margin:0}</style></head><body>"
                  "<div style=\"height:40px\"></div></body></html>");
    std::optional<wr::ContentSize> size = own.render().contentSize();
    CHECK(size && std::fabs(size->height - 40) < 0.5);
    RenderEnv host("<!doctype html><html><head></head><body><div style=\"height:40px\"></div></body></html>");
    std::optional<wr::ContentSize> margined = host.render().contentSize();
    CHECK(margined && std::fabs(margined->height - 56) < 0.5);
}

