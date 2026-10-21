// Text patched in place (M1c plan, Task 7; Ruling 8; twidget edit 16): a flush whose journal holds only Text entries
// patches the published litehtml document, and what it publishes is a rebuild's (Review Focus 1). What rebuilds
// instead (Review Focus 1's guard against a node that was mapped and then removed, a text under `<style>`, the budget
// and the piece cap), and that a stop while planning leaves the published state alone (Review Focus 2).
#include <cstdint>
#include <cstdio>
#include <memory>
#include <string>
#include <tuple>
#include <vector>

#include <litehtml/document.h>

#include "Sources/Host/HostState.h"
#include "Sources/Render/LayerTree.h"
#include "Sources/Render/RenderTree.h"
#include "Sources/Support/Errors.h"
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
    // An empty node cannot be patched (it has no pieces to replace): a rebuild, which agrees with itself.
    edit(env, "const q = document.getElementById('q'); q.childNodes[1].data = 'mid'");
    CHECK_EQ(env.render().buildCount(), builds + 1);
    CHECK_EQ(env.render().patchCount(), patches);
    expectMatchesRebuild(env, "empty node");
    // And the next change patches.
    edit(env, "document.getElementById('q').childNodes[1].data = 'middle'");
    CHECK_EQ(env.render().buildCount(), builds + 1);
    CHECK_EQ(env.render().patchCount(), ++patches);
    expectMatchesRebuild(env, "after");
}

WR_TEST(testStyleTextRebuilds) {
    RenderEnv env("<!doctype html><style id=s>p{color:#000001}</style><p>t</p>");
    const uint64_t builds = env.render().buildCount();
    edit(env, "document.getElementById('s').firstChild.data = 'p{color:#000002}'");
    CHECK_EQ(env.render().buildCount(), builds + 1);
    CHECK_EQ(env.render().patchCount(), uint64_t(0));
    const wr::TextItem* item = env.render().layerTree() ? findText(*env.render().layerTree(), "t") : nullptr;
    CHECK(item && item->color.blue == 2);
    expectMatchesRebuild(env, "style");
}

// What the fork or the plan refuses rebuilds, and agrees with a rebuild.
WR_TEST(testTextPatchFallsBack) {
    RenderEnv env("<!doctype html><body><p id=p>text</p><select id=s><option id=o>one</option></select>"
                  "<button id=b>go</button><p id=r>gone soon</p><p id=k>keep</p><p id=x>drop</p></body>");
    uint64_t builds = env.render().buildCount();
    // An empty replacement.
    edit(env, "document.getElementById('p').firstChild.data = ''");
    CHECK_EQ(env.render().buildCount(), ++builds);
    expectMatchesRebuild(env, "empty");
    // Text in an element profile 1 drops (an <option>, V4 plan, Task 4) renders nothing; text a form control reads
    // rebuilds.
    edit(env, "document.getElementById('o').firstChild.data = 'two'");
    CHECK_EQ(env.render().buildCount(), builds);
    expectMatchesRebuild(env, "option");
    edit(env, "document.getElementById('b').firstChild.data = 'stop'");
    CHECK_EQ(env.render().buildCount(), ++builds);
    expectMatchesRebuild(env, "button");
    // A text node moved to another parent, and changed: it is mapped, has pieces and a parent, but not where it
    // rendered. Its Removed and Inserted entries make the flush structural (Task 9), which builds it again where it is.
    uint64_t patches = env.render().patchCount();
    edit(env, "const t = document.getElementById('k').firstChild; document.getElementById('x').append(t);"
              " t.data = 'moved text here'");
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().patchCount(), ++patches);
    expectMatchesRebuild(env, "moved");
    // A valid text change beside a removal elsewhere: a kept node's own change beside structure (a mixed journal)
    // rebuilds, so the removal is not ignored.
    edit(env, "document.getElementById('k').append('kept'); ");
    CHECK_EQ(env.render().patchCount(), ++patches);
    edit(env, "document.getElementById('k').firstChild.data = 'kept and longer'; document.getElementById('x').remove()");
    CHECK_EQ(env.render().buildCount(), ++builds);
    CHECK_EQ(env.render().patchCount(), patches);
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

// The byte budget and the piece cap decide what a build leaves out, so a text that crosses one rebuilds, and a build
// that hit a limit is never patched.
WR_TEST(testTextPatchRespectsLimits) {
    RenderEnv env("<!doctype html><body><p id=p>one</p><p id=q>two</p></body>");
    uint64_t builds = env.render().buildCount();
    edit(env, "document.getElementById('p').firstChild.data = 'word '.repeat(1000)");
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().patchCount(), uint64_t(1));
    expectMatchesRebuild(env, "large");
    // Past the piece cap: 12,000 pieces.
    edit(env, "document.getElementById('p').firstChild.data = 'w '.repeat(6000)");
    CHECK_EQ(env.render().buildCount(), ++builds);
    CHECK_EQ(env.render().patchCount(), uint64_t(1));
    expectMatchesRebuild(env, "cap");
    // That build hit the limit, so even a small change rebuilds (a smaller text could let more in).
    edit(env, "document.getElementById('q').firstChild.data = 'three'");
    CHECK_EQ(env.render().buildCount(), ++builds);
    expectMatchesRebuild(env, "limit");
    edit(env, "document.getElementById('p').firstChild.data = 'back'");
    CHECK_EQ(env.render().buildCount(), ++builds);
    // The limit is gone with the text that caused it: patching resumes.
    edit(env, "document.getElementById('p').firstChild.data = 'again'");
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().patchCount(), uint64_t(2));
    expectMatchesRebuild(env, "resumed");
    // Past the byte budget: 1.1 MB of text.
    edit(env, "document.getElementById('q').firstChild.data = 'y'.repeat(1100000)");
    CHECK_EQ(env.render().buildCount(), ++builds);
    expectMatchesRebuild(env, "bytes");
}

// A stop while planning (Review Focus 2): the limit is swept over the whole flush, charges and allocations both. A
// flush that stops leaves the document, the render input, the layout and the tree exactly as published; one that does
// not stop has patched, and agrees with a rebuild. A patch that charged after its first litehtml call would be seen
// stopped with a changed document at some limit.
WR_TEST(testTextPatchPrechargesBeforeTouchingLitehtml) {
    // 8,000 pieces: the layout pre-charge alone is 64,000 units.
    const char* const script = "document.getElementById('p').firstChild.data = 'a '.repeat(4000);"
                               " document.getElementById('li').firstChild.data = 'changed'; 'ok'";
    // The work a patching flush charges.
    uint64_t charged = 0;
    uint64_t reserve = 0;
    {
        RenderEnv env(kPage);
        CHECK_EQ(env.env().eval(script), std::string("ok"));
        JSRuntime* rt = env.env().runtime().jsRuntime();
        const uint64_t before = JS_GetWorkUnits(rt);
        env.flush();
        charged = JS_GetWorkUnits(rt) - before;
        reserve = env.render().buildCharge() + uint64_t(litehtml::document::default_selector_steps) + 1000;
        CHECK_EQ(env.render().patchCount(), uint64_t(1));
        CHECK(charged > 64000);
    }
    int stopped = 0;
    int patched = 0;
    std::vector<uint64_t> limits;
    for (uint64_t allowed = 1; allowed < charged + 200; allowed += allowed < 200 ? 7 : allowed / 6) {
        limits.push_back(allowed);
    }
    // Ruling E20: a patch runs only when the budget also holds its fallback rebuild (the build's charge and
    // litehtml's 4,000,000 steps); short of that it rebuilds, or stops with the published state as it was.
    limits.push_back(charged + reserve);
    for (uint64_t allowed : limits) {
        RenderEnv env(kPage);
        std::shared_ptr<const wr::LayerTree> tree = env.render().layerTree();
        const std::string input = env.render().renderInput();
        const std::string dump = env.render().layoutDump();
        const std::string layer = tree->dump();
        const uint64_t builds = env.render().buildCount();
        CHECK_EQ(env.env().eval(script), std::string("ok"));
        CHECK_EQ(env.render().journalNodes(), size_t(2));
        litehtml::document* document = env.render().document();
        JSRuntime* rt = env.env().runtime().jsRuntime();
        env.env().runtime().setWorkLimit(JS_GetWorkUnits(rt) + allowed);
        bool aborted = false;
        try {
            env.flush();
        } catch (const wr::Aborted&) {
            aborted = true;
        }
        if (aborted) {
            stopped++;
            CHECK(env.env().runtime().stopReason() == wr::StopReason::Budget);
            CHECK(env.render().document() == document);
            CHECK(env.render().layerTree() == tree);
            CHECK_EQ(env.render().renderInput(), input);
            CHECK_EQ(env.render().layoutDump(), dump);
            CHECK_EQ(tree->dump(), layer);
            CHECK_EQ(env.render().buildCount(), builds);
            CHECK_EQ(env.render().patchCount(), uint64_t(0));
        } else {
            env.env().runtime().setWorkLimit(~uint64_t(0));
            // Patched, or (short of the fallback's reserve) rebuilt: either equals a rebuild.
            if (env.render().patchCount() == 1) {
                patched++;
                CHECK_EQ(env.render().buildCount(), builds);
            } else {
                CHECK_EQ(env.render().buildCount(), builds + 1);
            }
            expectMatchesRebuild(env, "swept");
        }
    }
    CHECK(stopped >= 10);
    CHECK(patched >= 1);
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
