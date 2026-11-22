// Text patched in place (M1c plan, Task 7; Ruling 8; twidget edit 16): a flush whose journal holds only Text entries
// patches the published litehtml document, and what it publishes is a rebuild's (Review Focus 1). What rebuilds
// instead (Review Focus 1's guard against a node that was mapped and then removed, a text under `<style>`, the budget
// and the piece cap), and that a stop while planning leaves the published state alone (Review Focus 2).
#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <memory>
#include <optional>
#include <string>
#include <tuple>
#include <vector>

#include <litehtml/document.h>

#include "Sources/Host/HostState.h"
#include "Sources/Render/LayerTree.h"
#include "Sources/Render/RenderTree.h"
#include "Sources/Support/Errors.h"
#include "Sources/Render/LayerMirror.h"
#include "Tests/RenderHarness.h"

using wr_test::findText;
using wr_test::RenderEnv;

namespace {

// The three dumps of the flushed tree equal a fresh rebuild's.
void expectMatchesRebuild(RenderEnv& env, const char* what) {
    auto [layout, input, layer] = wr_test::rebuildDump(env);
    std::shared_ptr<const wr::LayerTree> tree = env.render().layerTree();
    if (env.render().layoutDump() != layout || env.render().renderInput() != input ||
        (tree ? tree->dump() : std::string()) != layer) {
        std::printf("  differs after: %s\n", what);
    }
    CHECK_EQ(env.render().layoutDump(), layout);
    CHECK_EQ(env.render().renderInput(), input);
    CHECK_EQ(tree ? tree->dump() : std::string(), layer);
}

// Runs `script` as the widget's own change, then flushes.
void edit(RenderEnv& env, const std::string& script) {
    CHECK_EQ(env.env().eval("(() => { " + script + "; })(); 'ok'"), std::string("ok"));
    env.flush();
}

const char* const kPage =
    "<!doctype html><body style='margin:0'><p id=p>one two</p><ul><li id=li>item</li></ul>"
    "<table><tr><td id=td>cell</td></tr></table><pre id=pre>a  b\nc</pre><p id=q></p></body>";

} // namespace

WR_TEST(testTextPatchMatchesRebuild) {
    RenderEnv env(kPage);
    const uint64_t builds = env.render().buildCount();
    expectMatchesRebuild(env, "boot");
    const char* const edits[] = {
        "document.getElementById('p').firstChild.data = 'one two three four'",
        "document.getElementById('p').firstChild.appendData(' five six seven eight nine ten eleven twelve thirteen')",
        "document.getElementById('li').firstChild.data = 'a much longer list item than before'",
        "document.getElementById('td').firstChild.data = 'x'",
        "document.getElementById('pre').firstChild.data = '  keep   spaces\\n  here'",
        "document.getElementById('p').firstChild.data = 'short'",
        "document.getElementById('p').firstChild.data = '   '",
        "document.getElementById('td').firstChild.appendData(' and more & <less>')",
        "document.getElementById('li').firstChild.data = 'z'",
        "document.getElementById('pre').firstChild.appendData('\\nthird line')",
    };
    uint64_t patches = env.render().patchCount();
    for (const char* script : edits) {
        edit(env, script);
        CHECK_EQ(env.render().patchCount(), ++patches);
        CHECK_EQ(env.render().buildCount(), builds);
        CHECK_EQ(env.render().journalNodes(), size_t(0));
        expectMatchesRebuild(env, script);
    }
}

// Several Text nodes in one flush, adjacent ones in one parent among them.
// twidget edit 16: the pieces are replaced in place wherever they sit, not only straight in a block's inline context: in
// an inline element (a counter's <span>, a <b> in a sentence), and beside other children (an element, a ::before). So
// litehtml keeps its render tree, the flush publishes operations, and the inline context's runs are what a fresh walk
// records.
WR_TEST(testTextInAnInlineElementKeepsTheTree) {
    RenderEnv env("<!doctype html><style>#m::before{content:'> '}</style><body style='margin:0'>"
                  "<p>count: <span id=s>0</span> and <b id=b>bold</b> words</p>"
                  "<div id=d>left <i>it</i> right</div><p id=m>marked</p>"
                  "<p><span id=g>grow</span> then <span style='opacity:.5'>faded</span> <b style='display:inline-block'>box</b></p>"
                  "<p id=q>p <span style='opacity:.5'>x &amp; y</span></p></body>");
    const uint64_t builds = env.render().buildCount();
    const char* const edits[] = {
        "document.getElementById('s').firstChild.data = '42'",
        "document.getElementById('s').textContent = '1,337 and more'",
        "document.getElementById('b').firstChild.data = 'much bolder words that wrap the line'",
        "document.getElementById('d').firstChild.data = 'a longer left part'",
        "document.getElementById('d').lastChild.data = ' right again'",
        "document.getElementById('m').firstChild.data = 'marked again'",
        "document.getElementById('s').textContent = '7'; document.getElementById('b').firstChild.data = 'b'",
        // What follows in the line moves: a paint group and an inline-block after the text.
        "document.getElementById('g').firstChild.data = 'grown a good deal longer'",
        "document.getElementById('q').firstChild.data = '  spaced  out  '",
        "document.getElementById('q').lastChild.firstChild.data = 'inside the group'",
    };
    for (const char* script : edits) {
        const uint64_t patches = env.render().patchCount();
        edit(env, script);
        expectMatchesRebuild(env, script);
        CHECK_EQ(env.render().patchCount(), patches + 1);
        CHECK(!env.render().layerOps().empty());
    }
    CHECK_EQ(env.render().buildCount(), builds);
}

WR_TEST(testTextPatchBatches) {
    RenderEnv env(kPage);
    // An empty node first, then text after it; these are structure changes and rebuild.
    edit(env, "const q = document.getElementById('q'); q.append('first'); q.append(document.createTextNode(''));"
              " q.append('second words')");
    const uint64_t builds = env.render().buildCount();
    uint64_t patches = env.render().patchCount();
    edit(env, "const q = document.getElementById('q'); q.firstChild.data = 'one'; q.lastChild.data = 'two three four';"
              " document.getElementById('p').firstChild.data = 'changed';"
              " document.getElementById('td').firstChild.data = 'cells and cells'");
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().patchCount(), ++patches);
    expectMatchesRebuild(env, "batch");
    // The other order: the later node grows and the earlier shrinks.
    edit(env, "const q = document.getElementById('q'); q.lastChild.data = 'a'; q.firstChild.data = 'b c d e f g h';"
              " document.getElementById('pre').firstChild.data = 'x\\ny'");
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().patchCount(), ++patches);
    expectMatchesRebuild(env, "batch 2");
    // An empty node has no pieces to replace: the flush walks the cut (RenderCut.h), which builds it again, and patches.
    edit(env, "const q = document.getElementById('q'); q.childNodes[1].data = 'mid'");
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().patchCount(), ++patches);
    expectMatchesRebuild(env, "empty node");
    // And the next change patches as a text change.
    edit(env, "document.getElementById('q').childNodes[1].data = 'middle'");
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().patchCount(), ++patches);
    expectMatchesRebuild(env, "after");
}

// A `<style>`'s Text is its sheet's: the structure path patches it (twidget edit 81).
WR_TEST(testStyleTextPatches) {
    RenderEnv env("<!doctype html><style id=s>p{color:#000001}</style><p>t</p>");
    const uint64_t builds = env.render().buildCount();
    edit(env, "document.getElementById('s').firstChild.data = 'p{color:#000002}'");
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().patchCount(), uint64_t(1));
    const wr::TextItem* item = env.render().layerTree() ? findText(*env.render().layerTree(), "t") : nullptr;
    CHECK(item && item->color.blue == 2);
    expectMatchesRebuild(env, "style");
}

// What the fork or the plan refuses rebuilds, and agrees with a rebuild.
WR_TEST(testTextPatchFallsBack) {
    RenderEnv env("<!doctype html><body><p id=p>text</p><select id=s><option id=o>one</option></select>"
                  "<button id=b>go</button><p id=r>gone soon</p><p id=k>keep</p><p id=x>drop</p></body>");
    uint64_t builds = env.render().buildCount();
    // An empty replacement: no pieces to replace them with, so the flush walks the cut, and the Text goes.
    edit(env, "document.getElementById('p').firstChild.data = ''");
    CHECK_EQ(env.render().buildCount(), builds);
    expectMatchesRebuild(env, "empty");
    // Text in an element profile 1 drops (an <option>, V4 plan, Task 4) renders nothing; a <button> reads none of its
    // text (twidget edit 16), which patches.
    edit(env, "document.getElementById('o').firstChild.data = 'two'");
    CHECK_EQ(env.render().buildCount(), builds);
    expectMatchesRebuild(env, "option");
    edit(env, "document.getElementById('b').firstChild.data = 'stop'");
    CHECK_EQ(env.render().buildCount(), builds);
    expectMatchesRebuild(env, "button");
    // A text node moved to another parent, and changed: it is mapped, has pieces and a parent, but not where it
    // rendered. Its Removed and Inserted entries make the flush structural (Task 9), which builds it again where it is.
    uint64_t patches = env.render().patchCount();
    edit(env, "const t = document.getElementById('k').firstChild; document.getElementById('x').append(t);"
              " t.data = 'moved text here'");
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().patchCount(), ++patches);
    expectMatchesRebuild(env, "moved");
    // A valid text change beside a removal elsewhere: a kept node's own change beside structure (a mixed journal), which
    // the structure path applies with the removal.
    edit(env, "document.getElementById('k').append('kept'); ");
    CHECK_EQ(env.render().patchCount(), ++patches);
    edit(env, "document.getElementById('k').firstChild.data = 'kept and longer'; document.getElementById('x').remove()");
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().patchCount(), ++patches);
    expectMatchesRebuild(env, "removal beside text");
    // A node mapped and then removed: its text change sits beside its Removed entry and goes with it.
    edit(env, "const r = document.getElementById('r'); const t = r.firstChild; r.firstChild.data = 'still here'; t.remove();"
              " r.append('new')");
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().patchCount(), ++patches);
    expectMatchesRebuild(env, "removed");
    // A removed node's later text change, with the parent kept.
    edit(env, "const p = document.getElementById('p'); p.append('abc'); ");
    CHECK_EQ(env.render().patchCount(), ++patches);
    edit(env, "const p = document.getElementById('p'); const t = p.firstChild; t.remove(); t.data = 'zzz'");
    CHECK_EQ(env.render().patchCount(), ++patches);
    CHECK_EQ(env.render().buildCount(), builds);
    expectMatchesRebuild(env, "removed 2");
}

// Twidget edit 84: a build's master pass gives every <summary> its triangle before the author pass drops the .x ones, so
// near the text-piece cap a text change cuts as a build cuts, the plain summaries' triangles included.
WR_TEST(testMasterContentNearTheTextCapPatchesAsABuild) {
    std::string page = "<!doctype html><style>summary.x::before{content:none}</style><body><p id=p>w";
    for (int i = 1; i < 1000; i++) {
        page += " w";
    }
    page += "</p>";
    for (int i = 0; i < 100; i++) {
        page += "<summary class=x>s</summary>";
    }
    for (int i = 0; i < 10; i++) {
        page += "<summary>t</summary>";
    }
    RenderEnv env(page + "</body>");
    const uint64_t builds = env.render().buildCount();
    const int fill =
        1000 + (litehtml::document::max_text_elements - 50 - env.render().document()->document_text_pieces()) / 2;
    edit(env, "document.getElementById('p').firstChild.data = 'w' + ' w'.repeat(" + std::to_string(fill - 1) + ")");
    CHECK_EQ(env.render().buildCount(), builds);
    expectMatchesRebuild(env, "a text near the cap beside master content");
    CHECK(wr_test::countsMatchAFreshBuild(env, "a text near the cap beside master content"));
}

// Twidget edit 84: a replay cut by the budget stops the widget after the commit, with litehtml's document patched and never
// laid out. The widget is frozen on the tree published before, and the selectable text, which reads the document, is
// empty.
WR_TEST(testAReplayCutLeavesNothingToSelect) {
    std::string page = "<!doctype html><style>s::before{content:'x'} p{user-select:text}</style><body><p>selectable</p>"
                       "<div style=display:flow-root;height:50px;overflow:hidden><p id=p>w";
    for (int i = 1; i < 1000; i++) {
        page += " w";
    }
    RenderEnv env(page + "</p><s></s></div></body>");
    const std::shared_ptr<const wr::LayerTree> before = env.render().layerTree();
    const std::optional<wr::SelectableText> selectable = env.render().selectableText(10000);
    CHECK(selectable.has_value() && !selectable->text.empty());
    const int fill =
        1000 + (litehtml::document::max_text_elements + 1 - env.render().document()->document_text_pieces()) / 2;
    env.render().setPatchStepCapForTesting(1);
    CHECK_EQ(env.env().eval("document.getElementById('p').firstChild.data = 'w' + ' w'.repeat(" + std::to_string(fill - 1) +
                            "); 'ok'"),
             std::string("ok"));
    // The stop is thrown to the step boundary, which the harness's own flush is.
    try {
        env.flush();
    } catch (const wr::Aborted&) {
    }
    CHECK(env.env().runtime().stopReason() == wr::StopReason::Internal);
    CHECK(env.render().layerTree() == before);
    const std::optional<wr::SelectableText> text = env.render().selectableText(10000);
    CHECK(text.has_value() && text->text.empty());
}

// The byte budget and the piece cap decide what a build leaves out. A text that crosses one, or one in a document a build
// cut, walks the cut (RenderCut.h) and patches: every flush below patches and equals a build, its counts included.
WR_TEST(testTextPatchCutsAtTheLimits) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    RenderEnv env("<!doctype html><body><p id=p>one</p><p id=q>two</p></body>");
    const uint64_t builds = env.render().buildCount();
    const auto patched = [&](const std::string& script, const char* what) {
        const uint64_t patches = env.render().patchCount();
        edit(env, script);
        CHECK_EQ(env.render().buildCount(), builds);
        CHECK_EQ(env.render().patchCount(), patches + 1);
        expectMatchesRebuild(env, what);
        CHECK(wr_test::countsMatchAFreshBuild(env, what));
    };
    patched("document.getElementById('p').firstChild.data = 'word '.repeat(1000)", "large");
    // Past the piece cap: 12,000 pieces.
    patched("document.getElementById('p').firstChild.data = 'w '.repeat(6000)", "cap");
    patched("document.getElementById('q').firstChild.data = 'three'", "a change past the cut");
    patched("document.getElementById('p').firstChild.data = 'back'", "back under");
    patched("document.getElementById('p').firstChild.data = 'again'", "resumed");
    // Past the byte budget: 1.1 MB of text.
    patched("document.getElementById('q').firstChild.data = 'y'.repeat(1100000)", "bytes");
}

// The flush publishes a new tree with changedRects against the previous one, as a rebuild does.
WR_TEST(testTextPatchPublishesChangedRects) {
    RenderEnv env("<!doctype html><body style='height:200px;margin:0'><p id=p>one</p></body>");
    std::shared_ptr<const wr::LayerTree> before = env.render().layerTree();
    edit(env, "document.getElementById('p').firstChild.data = 'two'");
    std::shared_ptr<const wr::LayerTree> after = env.render().layerTree();
    CHECK(after && after != before);
    CHECK_EQ(env.render().patchCount(), uint64_t(1));
    CHECK(before && findText(*before, "one") != nullptr && findText(*before, "two") == nullptr);
    CHECK(after && findText(*after, "two") != nullptr);
    CHECK(env.render().changedRects().has_value() && !env.render().changedRects()->empty());
    // The old tree is intact.
    CHECK(findText(*before, "one") != nullptr);
}

// A <button>'s text is the text path's (twidget edit 16): its data and a textContent swap patch, as a rebuild renders.
WR_TEST(testAButtonsTextIsAPatch) {
    RenderEnv env("<!doctype html><body><button id=b>go</button><p>after</p></body>");
    const uint64_t builds = env.render().buildCount();
    for (const char* script : {"document.getElementById('b').firstChild.data = 'a longer label'",
                               "document.getElementById('b').textContent = 'x'"}) {
        const uint64_t patches = env.render().patchCount();
        edit(env, script);
        if (env.render().patchCount() != patches + 1) {
            std::printf("  not patched (%s): %s\n", env.render().lastPatchRefusal(), script);
        }
        CHECK_EQ(env.render().patchCount(), patches + 1);
        CHECK_EQ(env.render().buildCount(), builds);
        expectMatchesRebuild(env, script);
    }
}
