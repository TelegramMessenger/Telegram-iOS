// Attributes and inline style patched in place (M1c plan, Task 8; Ruling 8; twidget edit 17): a flush whose journal
// holds only Text and Attribute entries patches the published litehtml document, and what it publishes is a rebuild's
// (Review Focus 1). What rebuilds instead (a selector the change could reach, an unsafe inline style, an element the
// fork does not patch, the render limits), what is ignored (an element Ruling 4 leaves out), that the render input is
// kept in step, and that a stop while planning leaves the published state alone (Review Focus 2).
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
#include "Sources/Support/Work.h"
#include "Tests/RenderHarness.h"

using wr_test::RenderEnv;

namespace {

// A 20x10 and an 8x16 RGBA PNG.
const std::string kWide =
    "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAKCAYAAAC0VX7mAAAAF0lEQVR4nGP4z8Dwn5qYYdTAUQOHo4EAf0SOgJVcF6MAAAAASUVORK5CYII=";
const std::string kTall =
    "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAgAAAAQCAYAAAArij59AAAAFUlEQVR4nGP4z8DwHx9mGFUwkhQAAAl5/wH+h3K7AAAAAElFTkSuQmCC";

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

// body.children: 0 p.a, 1 div.a (style), 2 div (hidden soon), 3 checkbox, 4 text input, 5 img, 6 a, 7 svg > circle,
// 8 script, 9 template, 10 ul > li.
std::string attributePage() {
    return "<!doctype html><style>.a{color:#c00;background:#00f;padding:2px}.b{color:#0a0;font-weight:bold}"
           ".c{background:#fc0}#x{background:#ccc;padding:4px}#y{background:#fc0;padding:12px}[hidden]{display:none}"
           "input:checked{outline:1px solid #f00}a:link{color:#909}</style>"
           "<body style='margin:0'><p class=a>para text</p><div class=a style='color:#c00'>div text</div>"
           "<div>hidden soon</div><input type=checkbox><input value=ab><img src='" + kWide + "'><a href=x>link</a>"
           "<svg width=40 height=40 viewBox='0 0 40 40'><circle cx=20 cy=20 r=10 fill=red></circle></svg>"
           "<script></script><template></template><ul><li>item</li></ul></body>";
}

std::string child(int index) {
    return "document.body.children[" + std::to_string(index) + "]";
}

} // namespace

WR_TEST(testAttributePatchMatchesRebuild) {
    RenderEnv env(attributePage());
    const uint64_t builds = env.render().buildCount();
    expectMatchesRebuild(env, "boot");
    const std::string edits[] = {
        child(0) + ".className = 'b'",                                              // a class toggle
        child(0) + ".className = 'a c'",
        child(0) + ".id = 'x'",                                                     // an id change
        child(0) + ".id = 'y'",
        child(1) + ".setAttribute('style', 'color:#00c;padding:6px')",              // a local style change
        child(1) + ".setAttribute('style', 'background:#0f0')",                     // a background-only one
        child(2) + ".setAttribute('hidden', '')",                                   // hidden toggled
        child(2) + ".removeAttribute('hidden')",
        child(3) + ".setAttribute('checked', '')",                                  // input checked toggled
        child(3) + ".removeAttribute('checked')",
        child(4) + ".setAttribute('value', 'abcdef')",                              // input value changed
        child(4) + ".setAttribute('placeholder', 'hint')",
        child(5) + ".setAttribute('src', '" + kTall + "')",                         // img src between two data URLs
        child(5) + ".setAttribute('src', '" + kWide + "')",
        child(6) + ".setAttribute('href', 'y')",                                    // an a href change
        child(6) + ".removeAttribute('href')",
        child(6) + ".setAttribute('href', 'z')",
        child(7) + ".firstElementChild.setAttribute('fill', 'blue')",               // an SVG fill change
        child(7) + ".firstElementChild.setAttribute('r', '15')",
        child(10) + ".firstElementChild.setAttribute('class', 'a')",                // a list item: list_index stays
        child(10) + ".firstElementChild.setAttribute('class', 'b')",
        child(7) + ".setAttribute('width', '60')",                                  // the svg element itself
        child(7) + ".setAttribute('viewBox', '0 0 20 20')",                         // mixed case
        child(7) + ".firstElementChild.setAttributeNS('http://www.w3.org/1999/xlink', 'xlink:title', 't')",   // prefixed
        "document.body.setAttribute('style', 'margin:4px;background:#eee')",       // body's style
        "document.body.setAttribute('style', 'margin:0')",
        child(8) + ".setAttribute('type', 'module')",                               // a script: never rendered
        child(9) + ".setAttribute('id', 'tpl')",                                    // a template: never rendered
        child(0) + ".removeAttribute('class')",
        // Several changes in one flush: one element twice over, one with two attributes, and a Text beside them.
        child(0) + ".className = 'b'; " + child(0) + ".id = 'x'; " + child(0) + ".className = 'c'",
        child(1) + ".setAttribute('style', 'width:60px'); " + child(1) + ".className = 'b'; " + child(2) +
            ".setAttribute('hidden', ''); " + child(0) + ".firstChild.data = 'changed text'",
    };
    uint64_t patches = env.render().patchCount();
    for (const std::string& script : edits) {
        edit(env, script);
        CHECK_EQ(env.render().patchCount(), ++patches);
        CHECK_EQ(env.render().buildCount(), builds);
        CHECK_EQ(env.render().journalNodes(), size_t(0));
        expectMatchesRebuild(env, script.c_str());
    }
}

// Removing an attribute removes it from the render input, and a repeated name's first value wins as in a build.
WR_TEST(testRemovedAttributeIsRemoved) {
    RenderEnv env(attributePage());
    CHECK(env.render().renderInput().find("<p class=\"a\">") != std::string::npos);
    const uint64_t builds = env.render().buildCount();
    edit(env, child(0) + ".removeAttribute('class')");
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().patchCount(), uint64_t(1));
    CHECK(env.render().renderInput().find("<p class=\"a\">") == std::string::npos);
    CHECK(env.render().renderInput().find("<p>para text</p>") != std::string::npos);
    expectMatchesRebuild(env, "class removed");
    // And back, with a value that needs escaping.
    edit(env, child(0) + ".setAttribute('class', 'a&b\"<c>')");
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK(env.render().renderInput().find("<p class=\"a&amp;b&quot;&lt;c&gt;\">") != std::string::npos);
    expectMatchesRebuild(env, "class escaped");
    // Removing the only style leaves the element as a build without it makes it.
    edit(env, child(1) + ".removeAttribute('style')");
    CHECK_EQ(env.render().buildCount(), builds);
    expectMatchesRebuild(env, "style removed");
}

// What the fork refuses rebuilds, and agrees with a rebuild.
WR_TEST(testAttributePatchFallsBack) {
    // A class in an ancestor position of a selector, and positional and sibling selectors.
    for (const char* sheet : {".on p{color:#c00}", "p:nth-child(2){color:#c00}", "div + p{color:#c00}"}) {
        RenderEnv env(std::string("<!doctype html><style>") + sheet + "</style><body><div id=d><p>one</p><p>two</p></div></body>");
        const uint64_t builds = env.render().buildCount();
        edit(env, "document.getElementById('d').className = 'on'");
        CHECK_EQ(env.render().buildCount(), builds + 1);
        CHECK_EQ(env.render().patchCount(), uint64_t(0));
        expectMatchesRebuild(env, sheet);
    }
    RenderEnv env("<!doctype html><body><div id=d style='color:#c00'>d</div><table id=t><tr><td>c</td></tr></table>"
                  "<select id=s><option id=o>one</option><option>two</option></select><textarea id=ta></textarea>"
                  "<p id=p>p</p></body>");
    uint64_t builds = env.render().buildCount();
    // An inline style touching a custom property, var() or a counter, in or out.
    edit(env, "document.getElementById('d').setAttribute('style', '--x:1;color:#0c0')");
    CHECK_EQ(env.render().buildCount(), ++builds);
    expectMatchesRebuild(env, "--x");
    edit(env, "document.getElementById('d').setAttribute('style', 'color:var(--x)')");
    CHECK_EQ(env.render().buildCount(), ++builds);
    edit(env, "document.getElementById('d').setAttribute('style', 'color:#00c')");
    CHECK_EQ(env.render().buildCount(), ++builds);     // out of a style with --x
    expectMatchesRebuild(env, "out of var");
    // Elements the fork does not patch in place: a table, a select and its option, a textarea.
    edit(env, "document.getElementById('t').setAttribute('border', '1')");
    CHECK_EQ(env.render().buildCount(), ++builds);
    expectMatchesRebuild(env, "table");
    edit(env, "document.getElementById('o').setAttribute('selected', '')");
    CHECK_EQ(env.render().buildCount(), ++builds);
    expectMatchesRebuild(env, "option");
    edit(env, "document.getElementById('s').setAttribute('class', 'z')");
    CHECK_EQ(env.render().buildCount(), ++builds);
    edit(env, "document.getElementById('ta').setAttribute('placeholder', 'hint')");
    CHECK_EQ(env.render().buildCount(), ++builds);
    expectMatchesRebuild(env, "textarea");
    CHECK_EQ(env.render().patchCount(), uint64_t(0));
    // A change beside a removal elsewhere: not attribute-only, so the removal is not ignored.
    edit(env, "document.getElementById('p').className = 'q'; document.getElementById('t').remove()");
    CHECK_EQ(env.render().buildCount(), ++builds);
    CHECK_EQ(env.render().patchCount(), uint64_t(0));
    expectMatchesRebuild(env, "removal beside attribute");
    // A node mapped and then removed: the change sits beside its Removed entry and goes with it (Task 9 patches the
    // removal).
    edit(env, "const p = document.getElementById('p'); p.className = 'r'; p.remove()");
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().patchCount(), uint64_t(1));
    expectMatchesRebuild(env, "removed");
    // And an ordinary change still patches afterwards.
    edit(env, "document.getElementById('d').setAttribute('style', 'color:#0c0')");
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().patchCount(), uint64_t(2));
    expectMatchesRebuild(env, "resumed");
}

// The render limits decide what a build leaves out, so a change that crosses one rebuilds, and a build that hit a
// limit is never patched.
WR_TEST(testAttributePatchRespectsLimits) {
    RenderEnv env("<!doctype html><body><div id=d>d</div><p id=p>p</p></body>");
    uint64_t builds = env.render().buildCount();
    // A `style` over 16 KiB is not rendered, and the build posts style-attribute.
    edit(env, "document.getElementById('d').setAttribute('style', 'color:#c00;' + ' '.repeat(16400))");
    CHECK_EQ(env.render().buildCount(), ++builds);
    expectMatchesRebuild(env, "style over 16 KiB");
    // That build hit a limit, so even a small change rebuilds.
    edit(env, "document.getElementById('p').className = 'q'");
    CHECK_EQ(env.render().buildCount(), ++builds);
    expectMatchesRebuild(env, "limit");
    // The limit is gone with the style that caused it: patching resumes.
    edit(env, "document.getElementById('d').setAttribute('style', 'color:#0c0')");
    CHECK_EQ(env.render().buildCount(), ++builds);
    edit(env, "document.getElementById('p').className = 'q2'");
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().patchCount(), uint64_t(1));
    expectMatchesRebuild(env, "resumed");
    // A style just under the cap patches.
    edit(env, "document.getElementById('d').setAttribute('style', 'color:#c00;' + ' '.repeat(16300))");
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().patchCount(), uint64_t(2));
    expectMatchesRebuild(env, "style under 16 KiB");
    // Past the byte budget: 1.1 MB of one attribute value.
    edit(env, "document.getElementById('p').setAttribute('data-x', 'y'.repeat(1100000))");
    CHECK_EQ(env.render().buildCount(), ++builds);
    expectMatchesRebuild(env, "bytes");
    // Within the budget again: the smaller value patches in place.
    edit(env, "document.getElementById('p').setAttribute('data-x', 'y'.repeat(500000))");
    CHECK_EQ(env.render().buildCount(), ++builds);
    edit(env, "document.getElementById('p').setAttribute('data-x', 'z'.repeat(400000))");
    CHECK_EQ(env.render().buildCount(), builds);
    expectMatchesRebuild(env, "smaller");
    // The budget a patch leaves is kept in step: a value that grows twice over, and then fits only because the first
    // growth was counted.
    edit(env, "document.getElementById('p').setAttribute('data-x', 'z'.repeat(700000))");
    CHECK_EQ(env.render().buildCount(), builds);
    edit(env, "document.getElementById('p').setAttribute('data-x', 'z'.repeat(1000000))");
    CHECK_EQ(env.render().buildCount(), builds);
    expectMatchesRebuild(env, "grown twice");
    edit(env, "document.getElementById('d').setAttribute('data-y', 'w'.repeat(60000))");
    CHECK_EQ(env.render().buildCount(), ++builds);   // 1,000,000 + 60,000 passes the budget
    expectMatchesRebuild(env, "over after growing");
}

// A stop while planning (Review Focus 2): the limit is swept over the whole flush, charges and allocations both. A
// flush that stops leaves the document, the render input, the layout and the tree exactly as published; one that does
// not stop has patched, and agrees with a rebuild.
WR_TEST(testAttributePatchPrechargesBeforeTouchingLitehtml) {
    const std::string script = child(0) + ".className = 'b'; " + child(1) + ".setAttribute('style', 'color:#00c');" +
                               child(4) + ".setAttribute('value', 'abcdef'); " + child(2) + ".setAttribute('hidden', ''); 'ok'";
    uint64_t charged = 0;
    uint64_t reserve = 0;
    {
        RenderEnv env(attributePage());
        CHECK_EQ(env.env().eval(script), std::string("ok"));
        JSRuntime* rt = env.env().runtime().jsRuntime();
        const uint64_t before = JS_GetWorkUnits(rt);
        env.flush();
        charged = JS_GetWorkUnits(rt) - before;
        reserve = env.render().buildCharge() + uint64_t(litehtml::document::default_selector_steps) + 1000;
        CHECK_EQ(env.render().patchCount(), uint64_t(1));
        CHECK(charged > 0);
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
        RenderEnv env(attributePage());
        std::shared_ptr<const wr::LayerTree> tree = env.render().layerTree();
        const std::string input = env.render().renderInput();
        const std::string dump = env.render().layoutDump();
        const std::string layer = tree->dump();
        const uint64_t builds = env.render().buildCount();
        CHECK_EQ(env.env().eval(script), std::string("ok"));
        CHECK_EQ(env.render().journalNodes(), size_t(4));
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
WR_TEST(testAttributePatchPublishesChangedRects) {
    RenderEnv env("<!doctype html><style>.b{background:#00f;width:30px;height:30px}</style>"
                  "<body style='height:200px;margin:0'><div id=d>box</div></body>");
    std::shared_ptr<const wr::LayerTree> before = env.render().layerTree();
    edit(env, "document.getElementById('d').className = 'b'");
    std::shared_ptr<const wr::LayerTree> after = env.render().layerTree();
    CHECK(after && after != before);
    CHECK_EQ(env.render().patchCount(), uint64_t(1));
    CHECK(env.render().changedRects().has_value() && !env.render().changedRects()->empty());
    // The old tree is intact.
    CHECK(before && before->dump() != after->dump());
}

namespace {

// The render-limit diagnostics posted so far.
size_t limitPosts(RenderEnv& env) {
    size_t n = 0;
    for (const auto& entry : env.env().host().diagnostics) {
        n += entry.first == "render-limit";
    }
    return n;
}

// Runs `script` and flushes; whatever the flush did, the result and the limits it posted equal a rebuild's. True when it
// patched.
bool flushAgreesWithRebuild(RenderEnv& env, const std::string& script, const char* what) {
    const size_t posted = limitPosts(env);
    const uint64_t patches = env.render().patchCount();
    edit(env, script);
    const size_t byFlush = limitPosts(env) - posted;
    expectMatchesRebuild(env, what);
    const size_t byRebuild = limitPosts(env) - posted - byFlush;
    if (byFlush != byRebuild) {
        std::printf("  limits differ after: %s (%zu vs %zu)\n", what, byFlush, byRebuild);
    }
    CHECK_EQ(byFlush, byRebuild);
    return env.render().patchCount() != patches;
}

std::string wordsPage(int words, const char* sheet, const char* body) {
    std::string filler;
    for (int n = 0; n < words; n++) {
        filler += n ? " w" : "w";
    }
    return std::string("<!doctype html><style>") + sheet + "</style><body>" + body + "<p>" + filler + "</p></body>";
}

} // namespace

// I1: :link in an ancestor position names href.
WR_TEST(testLinkInAnAncestorPositionRebuilds) {
    RenderEnv env("<!doctype html><style>a:link span{color:#c00} span{color:#00c}</style><body><a>link <span>t</span></a></body>");
    uint64_t builds = env.render().buildCount();
    edit(env, "document.querySelector('a').setAttribute('href', 'x')");
    CHECK_EQ(env.render().buildCount(), ++builds);
    CHECK_EQ(env.render().patchCount(), uint64_t(0));
    expectMatchesRebuild(env, "href added");
    const wr::TextItem* span = wr_test::findText(*env.render().layerTree(), "t");
    CHECK(span && span->color.red == 0xcc);
    edit(env, "document.querySelector('a').removeAttribute('href')");
    CHECK_EQ(env.render().buildCount(), ++builds);
    expectMatchesRebuild(env, "href removed");
    span = wr_test::findText(*env.render().layerTree(), "t");
    CHECK(span && span->color.blue == 0xcc);
}

// I4: href x, y, x, y through the patch keeps :link (the match epoch).
WR_TEST(testHrefRoundTripKeepsLink) {
    RenderEnv env("<!doctype html><style>a:link{color:#909} a{color:#090}</style><body><a href=x>link</a></body>");
    const uint64_t builds = env.render().buildCount();
    for (const char* href : {"y", "x", "y"}) {
        edit(env, std::string("document.querySelector('a').setAttribute('href', '") + href + "')");
        expectMatchesRebuild(env, href);
    }
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().patchCount(), uint64_t(3));
    const wr::TextItem* item = wr_test::findText(*env.render().layerTree(), "link");
    CHECK(item && item->color.red == 0x99);
}

// I2: pseudo-element content is made again whenever an element is matched again, and a fresh build makes all of it in
// document order with the old and new alive together, so near the text-piece cap a patch and a rebuild cut at different
// words. While any ::before or ::after rule with content could match, no patch is made (attribute or text); the flush
// rebuilds, and what it publishes and the limits it posts are a rebuild's.
WR_TEST(testPseudoContentRebuilds) {
    const char* const shapes[][2] = {
        {".x::before{content:\"a b c d\"} .y::before{content:\"e f g\"}", ""},
        {".x::before{content:ATTR(title)} .z::before{content:\"q\"}", ""},
        {".x::before{content:attr (title)} .z::before{content:\"q\"}", ""},
        {"[title]::before{content:attr(title)} .k::before{content:attr(title)} .x::before{content:\"a b c d\"}",
         "<div class=k title=\"w w w w w w w w w w w w w w w w w w w w w w w w w w w w w w w w w w w w w w w w w w\">k</div>"},
    };
    for (const auto& shape : shapes) {
        for (int words = 3900; words <= 5010; words += 111) {
            RenderEnv env(wordsPage(words, shape[0], (std::string("<div id=d title=\"t t t\">t</div>") + shape[1]).c_str()));
            const uint64_t builds = env.render().buildCount();
            CHECK(!flushAgreesWithRebuild(env, "document.getElementById('d').className = 'x'", "class onto pseudo content"));
            CHECK_EQ(env.render().buildCount(), builds + 1);
            // A text change does not patch either.
            CHECK(!flushAgreesWithRebuild(env, "document.getElementById('d').firstChild.data = 'changed text'", "text"));
            CHECK_EQ(env.render().patchCount(), uint64_t(0));
            CHECK_EQ(env.render().buildCount(), builds + 2);   // one rebuild for each of the two flushes
        }
    }
}

// A control makes its lh-* parts when it is matched again. type text -> range in one flush, then a text change near the
// cap in the next: both flushes rebuild (the document has a control and a rule for one of its parts), and equal a rebuild.
WR_TEST(testRangeThenTextNearTheCap) {
    const char* sheet = "lh-range-thumb::before{content:\"B1 B2 B3 B4 B5 B6 B7 B8 B9 B10 B11 B12 B13 B14 B15 B16 B17 B18 B19 B20\"}"
                        " input lh-range-thumb::before{content:\"q\"}";
    for (int words = 4900; words <= 5010; words += 13) {
        RenderEnv env(wordsPage(words, sheet, "<input id=i type=text><p id=t>before</p>"));
        const uint64_t builds = env.render().buildCount();
        CHECK(!flushAgreesWithRebuild(env, "document.getElementById('i').setAttribute('type', 'range')", "range"));
        CHECK(!flushAgreesWithRebuild(env, "document.getElementById('t').firstChild.data = 'n1 n2 n3 n4 n5 n6 n7 n8 n9 n10 n11 n12 n13 n14 n15 n16 n17 n18 n19 n20'", "text"));
        CHECK_EQ(env.render().patchCount(), uint64_t(0));
        CHECK_EQ(env.render().buildCount(), builds + 2);
    }
}

// Pseudo-element rules that make no content, and the master sheet's own (summary), do not stop patching.
WR_TEST(testOnlyPseudoContentStopsPatching) {
    for (const char* sheet : {".x::before{color:#c00}", ".x::before{content:none}", ".x{color:#c00;content:\"abc\"}"}) {
        RenderEnv env(wordsPage(4000, sheet, "<div id=d>t</div>"));
        const uint64_t builds = env.render().buildCount();
        CHECK(flushAgreesWithRebuild(env, "document.getElementById('d').className = 'x'", sheet));
        CHECK(flushAgreesWithRebuild(env, "document.getElementById('d').firstChild.data = 'text'", sheet));
        CHECK_EQ(env.render().buildCount(), builds);
    }
    // No summary in the document: the master sheet's summary::before is not in play.
    {
        RenderEnv env("<!doctype html><body><div id=d>t</div></body>");
        CHECK(flushAgreesWithRebuild(env, "document.getElementById('d').className = 'x'", "no summary"));
    }
    // With one, it is: master rules declare content.
    {
        RenderEnv env("<!doctype html><body><details open><summary>s</summary><p id=p>t</p></details></body>");
        CHECK(!flushAgreesWithRebuild(env, "document.getElementById('p').className = 'x'", "summary"));
        CHECK(!flushAgreesWithRebuild(env, "document.getElementById('p').firstChild.data = 'text'", "summary text"));
    }
}

// twidget edit 21: the style-byte budget. A document that has charged most of its budget keeps the rest for a rebuild: a
// class patch whose restyle could pass the budget (every rule on every element) makes no patch, and what the flush
// publishes is a rebuild's. The same document with small values patches.
WR_TEST(testPatchPastTheStyleBudgetMatchesRebuild) {
    auto page = [](size_t listBytes) {
        std::string elements;
        for (int i = 0; i < 400; i++) {
            elements += "<b></b>";
        }
        // A transition list keeps its tokens twice (font-family is cut at 1 KiB, as it is inherited by every element).
        std::string list;
        while (list.size() < listBytes) {
            list += "color 1s,";
        }
        list.pop_back();
        return "<!doctype html><style>*{transition:" + list + "} .x{color:#c00}</style><body><div id=d>t</div>" +
               elements + "</body>";
    };
    // A list charging ~26 KB on each of ~400 elements: about 10 MB of the 16 MiB charged, below the budget, so the build is not cut.
    {
        RenderEnv env(page(1100));
        const size_t charged = env.render().document()->style_bytes_charged();
        std::printf("style budget: %zu of %zu bytes charged by the build\n", charged, size_t(litehtml::document::max_style_bytes));
        CHECK(charged > size_t(8) * 1024 * 1024);
        CHECK(charged < size_t(litehtml::document::max_style_bytes));
        for (const std::string& limit : env.render().renderLimits()) {
            CHECK(limit != "style-bytes");
        }
        const uint64_t builds = env.render().buildCount();
        const uint64_t patches = env.render().patchCount();
        CHECK(!flushAgreesWithRebuild(env, "document.getElementById('d').className = 'x'", "class near the style budget"));
        CHECK_EQ(env.render().patchCount(), patches);
        CHECK_EQ(env.render().buildCount(), builds + 1);
    }
    // The control: values a hundred times smaller patch.
    {
        RenderEnv env(page(11));
        const uint64_t builds = env.render().buildCount();
        CHECK(flushAgreesWithRebuild(env, "document.getElementById('d').className = 'x'", "class far from the style budget"));
        CHECK_EQ(env.render().buildCount(), builds);
    }
}

// Ruling E51: the patch's estimate cannot see inline styles, so an insert whose elements' inline var() splices pass the
// budget is abandoned for a rebuild after the fact, and what is published is the rebuild's.
WR_TEST(testInsertPastTheStyleBudgetByInlineStylesMatchesRebuild) {
    std::string value;
    while (value.size() < 600) {
        value += "aa,";
    }
    value.pop_back();
    std::string elements;
    for (int i = 0; i < 400; i++) {
        elements += "<b style='--y:var(--x)'></b>";
    }
    RenderEnv env("<!doctype html><body style='--x:" + value + "'><div id=d></div>" + elements + "</body>");
    const size_t charged = env.render().document()->style_bytes_charged();
    std::printf("style budget (inline): %zu of %zu bytes charged by the build\n", charged, size_t(litehtml::document::max_style_bytes));
    CHECK(charged > size_t(12) * 1024 * 1024);
    CHECK(charged < size_t(litehtml::document::max_style_bytes));
    const uint64_t patches = env.render().patchCount();
    const uint64_t builds = env.render().buildCount();
    CHECK(!flushAgreesWithRebuild(env,
                                  "const d = document.getElementById('d'); for (let i = 0; i < 100; i++) { const e = document.createElement('b'); "
                                  "e.setAttribute('style', '--y:var(--x)'); d.appendChild(e); }",
                                  "inserts past the style budget"));
    CHECK_EQ(std::string(env.render().lastPatchRefusal()), std::string("abandoned: the style budget was passed"));
    CHECK_EQ(env.render().patchCount(), patches);
    CHECK_EQ(env.render().buildCount(), builds + 1);
}

// The table-cell cap: a span change that would pass it rebuilds; below it patches.
WR_TEST(testSpanChangeRespectsTheCellCap) {
    RenderEnv env("<!doctype html><body><table><tbody><tr><td colspan=1000 rowspan=199>a</td><td id=b>b</td></tr></tbody></table></body>");
    const uint64_t builds = env.render().buildCount();
    CHECK(flushAgreesWithRebuild(env, "document.getElementById('b').setAttribute('colspan', '1000')", "200,000 cells"));
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK(!flushAgreesWithRebuild(env, "document.getElementById('b').setAttribute('rowspan', '2')", "past the cap"));
    CHECK_EQ(env.render().buildCount(), builds + 1);
    // The build past the cap hit the limit, so the next change rebuilds too, and resumes patching after.
    CHECK(!flushAgreesWithRebuild(env, "document.getElementById('b').setAttribute('colspan', '2')", "back under"));
    CHECK(flushAgreesWithRebuild(env, "document.getElementById('b').removeAttribute('rowspan')", "limit gone"));
    CHECK(flushAgreesWithRebuild(env, "document.getElementById('b').setAttribute('colspan', '3')", "patching again"));
}

// I3: an element's attributes are applied in one call, one re-match, and the plan charges for every attribute.
WR_TEST(testManyAttributesAreOneRematch) {
    uint64_t charged[2] = {0, 0};
    const int counts[2] = {2500, 10000};
    for (int k = 0; k < 2; k++) {
        RenderEnv env("<!doctype html><body><div id=d>box</div></body>");
        const std::string n = std::to_string(counts[k]);
        edit(env, "const e = document.getElementById('d'); for (let i = 0; i < " + n + "; i++) e.setAttribute('a' + i, 'v')");
        const uint64_t builds = env.render().buildCount();
        litehtml::document* document = env.render().document();
        const uint64_t before = document->attribute_rematches();
        CHECK_EQ(env.env().eval("const e = document.getElementById('d'); for (let i = 0; i < " + n +
                                "; i++) e.setAttribute('a' + i, 'w'); 'ok'"),
                 std::string("ok"));
        JSRuntime* rt = env.env().runtime().jsRuntime();
        const uint64_t start = JS_GetWorkUnits(rt);
        env.flush();
        charged[k] = JS_GetWorkUnits(rt) - start;
        CHECK_EQ(env.render().buildCount(), builds);
        CHECK(env.render().document() == document);
        CHECK_EQ(document->attribute_rematches() - before, uint64_t(1));
        expectMatchesRebuild(env, "many attributes");
        CHECK(charged[k] >= uint64_t(counts[k]) * wr::work::kRenderAttribute);
    }
    CHECK(charged[1] >= 3 * charged[0]);
}

// twidget edit 18: a style patch to font-size 0 on a kept render tree equals a rebuild. litehtml's get_font answered no
// font for size 0 and left the metrics as they were, so the element kept its old line height (24 px where a fresh one has
// 0; with line-height 0, 8 against 0), and a <caption> so restyled moved its table's cells. (The reviewer's wcap2.)
WR_TEST(testFontSizeZeroPatchMatchesRebuild) {
    {
        RenderEnv env("<!doctype html><body><div id=c>cap</div><p id=p>x</p></body>");
        edit(env, "document.getElementById('c').setAttribute('style', 'font-size:0')");
        CHECK_EQ(env.render().patchCount(), uint64_t(1));
        expectMatchesRebuild(env, "font-size 0");
        edit(env, "document.getElementById('c').setAttribute('style', 'font-size:0;line-height:0')");
        CHECK_EQ(env.render().patchCount(), uint64_t(2));
        expectMatchesRebuild(env, "font-size 0, line-height 0");
        edit(env, "document.getElementById('c').setAttribute('style', 'font-size:4px')");
        CHECK_EQ(env.render().patchCount(), uint64_t(3));
        expectMatchesRebuild(env, "font-size 4px");
    }
    {
        RenderEnv env("<!doctype html><body><table><caption id=c>cap</caption><tbody><tr><td>a</td></tr></tbody></table></body>");
        edit(env, "document.getElementById('c').setAttribute('style', 'font-size:0')");
        expectMatchesRebuild(env, "a caption at font-size 0");
        edit(env, "document.getElementById('c').setAttribute('style', 'font-size:4px')");
        expectMatchesRebuild(env, "a caption at font-size 4px");
    }
}
