// The selectable text (widget-sandbox v0.1.1, sdk-v1 §2.4, §5.10): what the client may select of a widget, and where it is
// drawn, exported from the published layout.

#include <cmath>
#include <cstdint>
#include <cstdio>
#include <optional>
#include <string>

#include <quickjs.h>

#include "Sources/DOM/DOM.h"
#include "Sources/Render/RenderTree.h"
#include "Sources/Render/SelectableText.h"
#include "Tests/JSHarness.h"
#include "Tests/RenderHarness.h"

using wr_test::RenderEnv;

namespace {

std::string utf8(const std::u16string& text) {
    std::string out;
    for (size_t i = 0; i < text.size(); i++) {
        uint32_t c = text[i];
        if (c >= 0xD800 && c < 0xDC00 && i + 1 < text.size()) {
            c = 0x10000 + ((c - 0xD800) << 10) + (text[++i] - 0xDC00);
        }
        if (c < 0x80) {
            out += char(c);
        } else if (c < 0x800) {
            out += char(0xC0 | (c >> 6));
            out += char(0x80 | (c & 0x3F));
        } else if (c < 0x10000) {
            out += char(0xE0 | (c >> 12));
            out += char(0x80 | ((c >> 6) & 0x3F));
            out += char(0x80 | (c & 0x3F));
        } else {
            out += char(0xF0 | (c >> 18));
            out += char(0x80 | ((c >> 12) & 0x3F));
            out += char(0x80 | ((c >> 6) & 0x3F));
            out += char(0x80 | (c & 0x3F));
        }
    }
    return out;
}

std::string page(const std::string& style, const std::string& body) {
    return "<!doctype html><html><head><style>body{margin:0} p{margin:0}" + style + "</style></head><body>" + body +
           "</body></html>";
}

wr::SelectableText exported(RenderEnv& env, double visibleHeight = 1e9) {
    env.flush();
    return env.render().selectableText(visibleHeight);
}

std::string runText(const wr::SelectableText& text, const wr::SelectableRun& run) {
    return utf8(text.text.substr(run.start, run.length));
}

} // namespace

/// widget-sandbox's visual/16-selection: only the paragraph marked user-select: text, its bold word included; a soft
/// wrap inside it is a space.
WR_TEST(testOnlyUserSelectTextIsExported) {
    RenderEnv env(page(".sel{user-select:text}",
                       "<div class=sel>You can select this sentence, <b>this bold word</b> too, and copy it.</div>"
                       "<div>This sentence cannot be selected: text in a widget is not selectable unless the widget says so.</div>"
                       "<div>Nor can this one.</div>"));
    CHECK_EQ(utf8(exported(env).text), std::string("You can select this sentence, this bold word too, and copy it."));
}

/// A `none` inside `text` is left out, and the white space around it collapses to one space.
WR_TEST(testNoneInsideTextIsSkippedAndJoined) {
    RenderEnv env(page("", "<p style=\"user-select:text\">one <span style=\"user-select:none\">two</span> three</p>"));
    CHECK_EQ(utf8(exported(env).text), std::string("one three"));
}

/// A new block and a <br> are one newline each.
WR_TEST(testBlocksAndBreaksAreNewlines) {
    RenderEnv env(page("", "<div style=\"user-select:text\"><p>a b</p><p>c<br>d</p></div>"));
    CHECK_EQ(utf8(exported(env).text), std::string("a b\nc\nd"));
}

/// White space `pre` preserves is kept as written.
WR_TEST(testPreKeepsItsWhiteSpace) {
    RenderEnv env(page("pre{margin:0}", "<pre style=\"user-select:text\">a  b\nc</pre>"));
    CHECK_EQ(utf8(exported(env).text), std::string("a  b\nc"));
}

/// Generated content, visibility: hidden and text an overflow clip hides are not selectable; opacity: 0 text is drawn,
/// so it is (as in Chromium).
WR_TEST(testGeneratedHiddenAndClippedTextIsExcluded) {
    RenderEnv env(page("p{user-select:text} p.g::before{content:\"X\"}",
                       "<p class=g>g</p><p>a<span style=\"visibility:hidden\">hid</span>b</p>"
                       "<div style=\"overflow:hidden;height:0\"><p>clip</p></div><p><span style=\"opacity:0\">o</span></p>"));
    CHECK_EQ(utf8(exported(env).text), std::string("g\nab\no"));
}

/// The text is what is drawn: text-transform applied, and offsets count in the drawn text.
WR_TEST(testTextTransformIsTheDrawnText) {
    RenderEnv env(page("", "<p style=\"user-select:text;text-transform:uppercase\">abc</p>"));
    const wr::SelectableText text = exported(env);
    CHECK_EQ(utf8(text.text), std::string("ABC"));
    CHECK_EQ(text.runs.size(), size_t(1));
    CHECK_EQ(text.runs[0].nodeOffset, uint32_t(0));
    CHECK_EQ(text.runs[0].length, uint32_t(3));
}

/// Each run is where its word is drawn, and its caret offsets span it.
WR_TEST(testRunsAgreeWithTheDrawnTextItems) {
    RenderEnv env(page("", "<p style=\"user-select:text;width:100px\">alpha beta gamma delta</p>"));
    const wr::SelectableText text = exported(env);
    CHECK_EQ(text.runs.size(), size_t(4));
    for (const wr::SelectableRun& run : text.runs) {
        const wr::TextItem* item = wr_test::findText(*env.render().layerTree(), runText(text, run));
        CHECK(item != nullptr);
        if (!item) {
            continue;
        }
        CHECK(std::abs(run.box.x - double(item->pos.x.value())) <= 0.5);
        CHECK(std::abs(run.box.y - double(item->pos.y.value())) <= 1.0);
        CHECK(std::abs(run.box.width - double(item->pos.width.value())) <= 0.5);
        CHECK_EQ(run.carets.size(), size_t(run.length + 1));
        CHECK(std::abs(run.carets.front()) <= 0.01);
        CHECK(std::abs(double(run.carets.back()) - run.box.width) <= 0.5);
    }
    // Two lines: the second line's runs sit below the first's.
    CHECK(text.runs[0].box.y < text.runs[3].box.y);
}

/// A run under a transformed ancestor carries the composed transform; mapped through it, it lies inside that ancestor's
/// visual box.
WR_TEST(testTransformedRunsCarryTheirTransform) {
    RenderEnv env(page("", "<div id=d style=\"width:100px;height:40px;transform:translate(10px,20px) scale(2)\">"
                           "<p style=\"user-select:text\">ab</p></div>"));
    const wr::SelectableText text = exported(env);
    CHECK_EQ(text.runs.size(), size_t(1));
    const wr::SelectableRun& run = text.runs[0];
    CHECK(std::abs(run.transform[0] - 2) < 1e-9 && std::abs(run.transform[3] - 2) < 1e-9);
    CHECK(std::abs(run.transform[1]) < 1e-9 && std::abs(run.transform[2]) < 1e-9);
    wr::Node* div = wr::DOMState::of(env.ctx()).document().getElementById(env.ctx(), wr::String::fromUTF8(env.ctx(), "d"));
    std::optional<wr::RenderBox> box = env.render().visualBorderBox(*div);
    CHECK(box.has_value());
    const double x = run.transform[0] * run.box.x + run.transform[2] * run.box.y + run.transform[4];
    const double y = run.transform[1] * run.box.x + run.transform[3] * run.box.y + run.transform[5];
    CHECK(x >= box->x - 0.5 && x + 2 * run.box.width <= box->x + box->width + 0.5);
    CHECK(y >= box->y - 0.5 && y + 2 * run.box.height <= box->y + box->height + 0.5);
}

/// Every run names its Text node and where it starts in that node's drawn text; a separator belongs to no run.
WR_TEST(testRunsCarryTheirTextNodeAndOffset) {
    RenderEnv env(page("", "<p style=\"user-select:text\">ab cd</p>"));
    const wr::SelectableText text = exported(env);
    CHECK_EQ(utf8(text.text), std::string("ab cd"));
    CHECK_EQ(text.runs.size(), size_t(2));
    CHECK(text.runs[0].node != 0);
    CHECK_EQ(text.runs[0].node, text.runs[1].node);
    CHECK_EQ(text.runs[0].nodeOffset, uint32_t(0));
    CHECK_EQ(text.runs[1].nodeOffset, uint32_t(3));
    CHECK_EQ(text.runs[1].start, uint32_t(3));
}

/// A Text that `textContent` replaces is a new node with a new key, even when the text and its place are the same (the
/// text patch swaps it in: RenderTree::textSwaps), so a selection boundary named by the old one is gone.
WR_TEST(testAReplacedTextIsANewNode) {
    RenderEnv env(page("", "<p id=p style=\"user-select:text\">ab cd</p>"));
    const uint64_t before = exported(env).runs.at(0).node;
    const uint64_t patches = env.render().patchCount();
    env.env().eval("document.getElementById('p').textContent = 'ab cd'; 1");
    const wr::SelectableText after = exported(env);
    CHECK_EQ(env.render().patchCount(), patches + 1);
    CHECK_EQ(utf8(after.text), std::string("ab cd"));
    CHECK(!after.runs.empty() && after.runs[0].node != 0 && after.runs[0].node != before);
}

/// Review Focus 5: text the widget's clip hides (below the bubble's height) cannot be selected.
WR_TEST(testTextBelowTheVisibleHeightIsNotSelectable) {
    RenderEnv env(page("", "<p style=\"user-select:text\">top</p><p style=\"user-select:text;margin-top:700px\">x</p>"));
    CHECK_EQ(utf8(exported(env, 600).text), std::string("top"));
}

