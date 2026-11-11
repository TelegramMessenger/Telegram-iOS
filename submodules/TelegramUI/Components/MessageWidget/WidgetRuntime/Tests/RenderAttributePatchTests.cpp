// Attributes and inline style patched in place (M1c plan, Task 8; Ruling 8; twidget edit 17): a flush whose journal
// holds only Text and Attribute entries patches the published litehtml document, and what it publishes is a rebuild's
// (Review Focus 1). What rebuilds instead (a selector the change could reach, an unsafe inline style, an element the
// fork does not patch, the render limits), what is ignored (an element Ruling 4 leaves out), that the render input is
// kept in step, and that a stop while planning leaves the published state alone (Review Focus 2).
#include <algorithm>
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
    // A class in an ancestor position of a selector, and sibling selectors, patch what they reach (twidget edit 77);
    // so do counters in the sheets (edit 78).
    for (const char* sheet : {".on p{color:#c00}", "div + p{color:#c00}", "li{counter-increment:n} .on p{color:#c00}"}) {
        RenderEnv env(std::string("<!doctype html><style>") + sheet + "</style><body><div id=d><p>one</p><p>two</p></div></body>");
        const uint64_t builds = env.render().buildCount();
        edit(env, "document.getElementById('d').className = 'on'");
        CHECK_EQ(env.render().buildCount(), builds);
        CHECK_EQ(env.render().patchCount(), uint64_t(1));
        expectMatchesRebuild(env, sheet);
    }
    // A positional pseudo-class reads an element's place, which no attribute changes (twidget edit 42): it patches.
    {
        RenderEnv env("<!doctype html><style>p:nth-child(2){color:#c00}</style><body><div id=d><p>one</p><p>two</p></div></body>");
        const uint64_t builds = env.render().buildCount();
        edit(env, "document.getElementById('d').className = 'on'");
        CHECK_EQ(env.render().buildCount(), builds);
        CHECK_EQ(env.render().patchCount(), uint64_t(1));
        expectMatchesRebuild(env, "positional");
    }
    // Inside a wrapper: a change to <body>'s own children widens to all of them (the UA layer's `body>:first-child`).
    RenderEnv env("<!doctype html><body><div><div id=d style='color:#c00'>d</div><table id=t><tr><td>c</td></tr></table>"
                  "<select id=s><option id=o>one</option><option>two</option></select><textarea id=ta></textarea>"
                  "<p id=p>p</p></div></body>");
    uint64_t builds = env.render().buildCount();
    // An inline style touching a counter, in or out (twidget edit 78), or a custom property or var() (edit 17), patches.
    edit(env, "document.getElementById('d').setAttribute('style', 'counter-reset:n;color:#0c0')");
    CHECK_EQ(env.render().buildCount(), builds);
    expectMatchesRebuild(env, "counter-reset");
    edit(env, "document.getElementById('d').setAttribute('style', 'color:#00c')");
    CHECK_EQ(env.render().buildCount(), builds);     // out of a style with a counter
    expectMatchesRebuild(env, "out of counter-reset");
    edit(env, "document.getElementById('d').setAttribute('style', '--x:1;color:#0c0')");
    CHECK_EQ(env.render().buildCount(), builds);
    expectMatchesRebuild(env, "--x");
    edit(env, "document.getElementById('d').setAttribute('style', 'color:var(--x)')");
    CHECK_EQ(env.render().buildCount(), builds);
    edit(env, "document.getElementById('d').setAttribute('style', 'color:#00c')");
    CHECK_EQ(env.render().buildCount(), builds);       // out of a style with --x
    expectMatchesRebuild(env, "out of var");
    // A table's class is patched (twidget edit 17).
    const uint64_t patchesAtTable = env.render().patchCount();
    edit(env, "document.getElementById('t').setAttribute('class', 'b')");
    CHECK_EQ(env.render().buildCount(), builds);
    expectMatchesRebuild(env, "table");
    CHECK_EQ(env.render().patchCount(), patchesAtTable + 1);
    // A select, its option and a textarea are dropped by profile 1 (V4 plan, Task 4): their changes render nothing,
    // neither a rebuild nor a patched element.
    edit(env, "document.getElementById('o').setAttribute('selected', '')");
    edit(env, "document.getElementById('s').setAttribute('class', 'z')");
    edit(env, "document.getElementById('ta').setAttribute('placeholder', 'hint')");
    CHECK_EQ(env.render().buildCount(), builds);
    expectMatchesRebuild(env, "dropped controls");
    const uint64_t patchesBefore = env.render().patchCount();
    // A change beside a removal elsewhere: not attribute-only, so the removal is not ignored; the structure path applies
    // both (a mixed journal).
    edit(env, "document.getElementById('p').className = 'q'; document.getElementById('t').remove()");
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().patchCount(), patchesBefore + 1);
    expectMatchesRebuild(env, "removal beside attribute");
    // A node mapped and then removed: the change sits beside its Removed entry and goes with it (Task 9 patches the
    // removal).
    edit(env, "const p = document.getElementById('p'); p.className = 'r'; p.remove()");
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().patchCount(), patchesBefore + 2);
    expectMatchesRebuild(env, "removed");
    // And an ordinary change still patches afterwards.
    edit(env, "document.getElementById('d').setAttribute('style', 'color:#0c0')");
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().patchCount(), patchesBefore + 3);
    expectMatchesRebuild(env, "resumed");
}

namespace {

// A page whose first <div> has a `style` over 16 KiB: the build leaves it out and posts style-attribute, a limit its walk
// hit, so every later flush walks the cut (RenderCut.h).
std::string walkingPage(const std::string& body) {
    std::string declarations;
    while (declarations.size() < 17 * 1024) {
        declarations += "color:red;";
    }
    return "<!doctype html><body><div style=\"" + declarations + "\">x</div>" + body + "</body>";
}

} // namespace

// A <br>'s attributes patch (twidget's el_break takes kind 1, as a plain element): a class a rule makes block-level, and
// its removal.
WR_TEST(testABreaksAttributesPatch) {
    RenderEnv env("<!doctype html><style>.x{display:block;height:4px;background:#00f}</style><body><p>a<br id=b>b</p></body>");
    const uint64_t builds = env.render().buildCount();
    const uint64_t patches = env.render().patchCount();
    edit(env, "document.getElementById('b').className = 'x'");
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().patchCount(), patches + 1);
    expectMatchesRebuild(env, "a <br>'s class");
    edit(env, "document.getElementById('b').removeAttribute('class')");
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().patchCount(), patches + 2);
    expectMatchesRebuild(env, "a <br>'s class removed");
}

// Walking the cut, a <style>'s own attribute change builds it again, its sheet with it, as the structure path does.
WR_TEST(testAStyleAttributeChangeWhileWalkingPatches) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    RenderEnv env(walkingPage("<style id=s data-x=1>p{color:#c00}</style><p>p</p>"));
    CHECK(!env.render().renderLimits().empty());
    const uint64_t builds = env.render().buildCount();
    const uint64_t patches = env.render().patchCount();
    edit(env, "document.getElementById('s').setAttribute('data-x', '2')");
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().patchCount(), patches + 1);
    expectMatchesRebuild(env, "a <style>'s attribute while walking");
}

// Walking the cut, an element's own attribute change sets its attributes in place whatever their length, never building
// its subtree again: on a container of 3,000 paragraphs it patches and equals a fresh build.
WR_TEST(testAnAttributeChangeWhileWalkingSetsInPlace) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    std::string paragraphs;
    for (int i = 0; i < 3000; i++) {
        paragraphs += "<p>x</p>";
    }
    RenderEnv env(walkingPage("<div id=c class=a>" + paragraphs + "</div>"));
    CHECK(!env.render().renderLimits().empty());
    const uint64_t builds = env.render().buildCount();
    const uint64_t patches = env.render().patchCount();
    edit(env, "document.getElementById('c').className = 'ab'");
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().patchCount(), patches + 1);
    expectMatchesRebuild(env, "a longer class while walking");
}

// The render limits decide what a build leaves out. A change that crosses one, or one in a document a build cut, walks the
// cut (RenderCut.h) and patches: every flush below patches and equals a build, its counts and limits included.
WR_TEST(testAttributePatchCutsAtTheLimits) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    RenderEnv env("<!doctype html><body><div id=d>d</div><p id=p>p</p></body>");
    const uint64_t builds = env.render().buildCount();
    const auto patched = [&](const std::string& script, const char* what) {
        const uint64_t patches = env.render().patchCount();
        edit(env, script);
        CHECK_EQ(env.render().buildCount(), builds);
        CHECK_EQ(env.render().patchCount(), patches + 1);
        expectMatchesRebuild(env, what);
        CHECK(wr_test::countsMatchAFreshBuild(env, what));
    };
    // A `style` over 16 KiB is not rendered, and style-attribute is posted.
    patched("document.getElementById('d').setAttribute('style', 'color:#c00;' + ' '.repeat(16400))", "style over 16 KiB");
    patched("document.getElementById('p').className = 'q'", "a change beside the limit");
    patched("document.getElementById('d').setAttribute('style', 'color:#0c0')", "the limit gone");
    patched("document.getElementById('p').className = 'q2'", "resumed");
    patched("document.getElementById('d').setAttribute('style', 'color:#c00;' + ' '.repeat(16300))", "style under 16 KiB");
    // Past the byte budget: 1.1 MB of one attribute value (one the text budgets do not count: V4 plan, Task 7).
    patched("document.getElementById('p').setAttribute('datetime', 'y'.repeat(1100000))", "bytes");
    patched("document.getElementById('p').setAttribute('datetime', 'y'.repeat(500000))", "within the budget again");
    patched("document.getElementById('p').setAttribute('datetime', 'z'.repeat(400000))", "smaller");
    // The budget a patch leaves is kept in step: a value that grows twice over, and then fits only because the first
    // growth was counted.
    patched("document.getElementById('p').setAttribute('datetime', 'z'.repeat(700000))", "grown once");
    patched("document.getElementById('p').setAttribute('datetime', 'z'.repeat(1000000))", "grown twice");
    patched("document.getElementById('d').setAttribute('role', 'w'.repeat(60000))", "over after growing");
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

// Runs `script` and flushes; whatever the flush did, the result, litehtml's counts and the limits equal a rebuild's. A
// rebuild posts every limit it hits; a patch, the kinds the published limits lacked (RenderTree::publishLimits). True
// when it patched.
bool flushAgreesWithRebuild(RenderEnv& env, const std::string& script, const char* what) {
    const size_t posted = limitPosts(env);
    const uint64_t patches = env.render().patchCount();
    const std::vector<std::string> before = env.render().renderLimits();
    edit(env, script);
    const bool patched = env.render().patchCount() != patches;
    const size_t byFlush = limitPosts(env) - posted;
    expectMatchesRebuild(env, what);
    size_t wanted = limitPosts(env) - posted - byFlush;
    if (patched) {
        wanted = 0;
        for (const std::string& kind : env.render().renderLimits()) {
            wanted += std::find(before.begin(), before.end(), kind) == before.end();
        }
    }
    if (byFlush != wanted) {
        std::printf("  limits posted after: %s (%zu, want %zu)\n", what, byFlush, wanted);
    }
    CHECK_EQ(byFlush, wanted);
    CHECK(wr_test::countsMatchAFreshBuild(env, what));
    return patched;
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
// :link is out of profile 1 for a widget's CSS (V4 plan, Task 3b), so these keep it where it still matches: in the
// trusted master sheet, through the host CSS, as the UA sheet's own `a:link` does.
static wr::RenderOptions withMasterCSS(const std::string& css) {
    wr::RenderOptions options;
    options.hostCSS += " " + css;
    return options;
}

WR_TEST(testLinkInAnAncestorPositionPatches) {
    RenderEnv env("<!doctype html><body><a>link <span>t</span></a></body>", withMasterCSS("a:link span{color:#c00} span{color:#00c}"));
    const uint64_t builds = env.render().buildCount();
    edit(env, "document.querySelector('a').setAttribute('href', 'x')");
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().patchCount(), uint64_t(1));
    expectMatchesRebuild(env, "href added");
    const wr::TextItem* span = wr_test::findText(*env.render().layerTree(), "t");
    CHECK(span && span->color.red == 0xcc);
    edit(env, "document.querySelector('a').removeAttribute('href')");
    CHECK_EQ(env.render().buildCount(), builds);
    expectMatchesRebuild(env, "href removed");
    span = wr_test::findText(*env.render().layerTree(), "t");
    CHECK(span && span->color.blue == 0xcc);
}

// I4: href x, y, x, y through the patch keeps :link (the match epoch).
WR_TEST(testHrefRoundTripKeepsLink) {
    // In a master layer after the UA layer's, which gives a[href] the link colour (twidget edit 41).
    RenderEnv env("<!doctype html><body><a href=x>link</a></body>",
                  withMasterCSS("@layer t{a:link{color:#909} a{color:#090}}"));
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

// twidget edit 62: a script's inline style change keeps litehtml's render tree when every property it changes is
// paint-only (an rAF loop setting el.style.transform), as an animated frame's does (or geometry only, edit 63); a property
// that shapes the tree still replaces a render subtree, alone or beside paint-only ones, which the mirror places with
// operations. Each flush equals a rebuild.
WR_TEST(testAPaintOnlyInlineStyleKeepsTheTree) {
    RenderEnv env("<!doctype html><body><div id=b style='width:40px;height:20px;background:#ccc'>b</div><p>after</p></body>");
    const uint64_t builds = env.render().buildCount();
    uint64_t replaced = env.render().subtreeReplacements();
    for (int i = 1; i <= 4; i++) {
        const std::string n = std::to_string(i);
        edit(env, "const b = document.getElementById('b'); b.style.transform = 'translateX(" + n + "0px)';"
                  " b.style.opacity = '0." + n + "'; b.style.color = 'rgb(" + n + "0, 0, 0)'");
        expectMatchesRebuild(env, ("paint-only " + n).c_str());
        CHECK_EQ(env.render().subtreeReplacements(), replaced);
    }
    edit(env, "document.getElementById('b').style.display = 'inline-block'");
    expectMatchesRebuild(env, "display");
    CHECK(env.render().subtreeReplacements() > replaced);
    replaced = env.render().subtreeReplacements();
    edit(env, "const b = document.getElementById('b'); b.style.transform = 'none'; b.style.cssFloat = 'left'");
    expectMatchesRebuild(env, "transform beside float");
    CHECK(env.render().subtreeReplacements() > replaced);
    CHECK_EQ(env.render().buildCount(), builds);
}

// twidget edit 63: a change of a box's geometry alone (its size, margins, padding, offsets, gaps, flex sizes) keeps
// litehtml's render tree, which only the layout reads them from; the restyle marks the box's layout dirty and the next
// layout places it. A change that shapes the tree (display, position, float) still replaces a render subtree, which the
// mirror places with operations. Inline style and a class rule alike; each flush equals a rebuild.
WR_TEST(testAGeometryChangeKeepsTheTree) {
    RenderEnv env("<!doctype html><style>.wide{width:200px;padding:6px} .gone{display:none} .abs{position:absolute}</style>"
                  "<body><div id=bar style='width:10px;height:8px;background:#0a0'></div>"
                  "<div id=box style='position:relative;left:0'>box <b>text</b></div><p id=p>after</p>"
                  "<div id=flex style='display:flex;gap:2px'><span id=f1>a</span><span>b</span></div>"
                  "<div style='display:flex;width:20px'><div id=a style='width:10px;flex:none'></div>"
                  "<div style='flex:1;overflow:hidden;border-radius:2px;background:#ccc'>c</div></div>"
                  "<p><span id=k>k</span> then <span style='opacity:.5'>faded</span> end</p></body>");
    const uint64_t builds = env.render().buildCount();
    uint64_t replacements = env.render().subtreeReplacements();
    auto kept = [&](const std::string& script, const char* what) {
        edit(env, script);
        expectMatchesRebuild(env, what);
        if (env.render().subtreeReplacements() != replacements) {
            std::printf("  a render subtree was replaced after: %s\n", what);
        }
        CHECK_EQ(env.render().subtreeReplacements(), replacements);
    };
    auto replaced = [&](const std::string& script, const char* what) {
        edit(env, script);
        expectMatchesRebuild(env, what);
        CHECK(env.render().subtreeReplacements() > replacements);
        replacements = env.render().subtreeReplacements();
    };
    for (int i = 1; i <= 3; i++) {
        kept("document.getElementById('bar').style.width = '" + std::to_string(i * 50) + "px'", "a progress bar's width");
        kept("document.getElementById('box').style.left = '" + std::to_string(i * 7) + "px'", "a relative box's left");
    }
    // A resize smaller than litehtml's pixel epsilon (0.0001 px) reaches the mirror too (twidget edit 20: exact
    // comparison): the clipping sibling, which nothing restyles, narrows by that much, and so does its clip.
    kept("document.getElementById('a').style.width = '10.00005px'", "a resize below the pixel epsilon");
    kept("const p = document.getElementById('p'); p.style.marginTop = '12px'; p.style.paddingLeft = '9px'", "margin and padding");
    kept("document.getElementById('flex').style.gap = '11px'; document.getElementById('f1').style.flexGrow = '1'", "gap and flex-grow");
    kept("document.getElementById('p').className = 'wide'", "a class whose rule sets width and padding");
    // An inline element's geometry is its line's: its subtree is built again (the line is laid out anew), a paint group
    // after it in the line included.
    replaced("document.getElementById('k').style.paddingLeft = '20px'", "an inline element's padding before a paint group");
    replaced("document.getElementById('p').className = 'gone'", "a class whose rule sets display");
    replaced("document.getElementById('box').style.position = 'absolute'", "position");
    replaced("document.getElementById('bar').style.width = '20px'; document.getElementById('bar').style.cssFloat = 'left'", "width beside float");
    CHECK_EQ(env.render().buildCount(), builds);
}

// An element matched again in place keeps its children for :empty (twidget edit 31.5): a style or class change on a
// span with text does not make `span:empty` match it, and a change on an empty one keeps the match.
WR_TEST(testARematchKeepsTheChildrenForEmpty) {
    RenderEnv env("<!doctype html><style>span:empty{padding:3px} p:not(:empty){margin:5px} .k{color:#c00}</style><body>"
                  "<span id=s>s</span><span id=e></span><p id=p>p</p></body>");
    const uint64_t builds = env.render().buildCount();
    edit(env, "document.getElementById('s').style.fontSize = '20px'");
    expectMatchesRebuild(env, "style on a span with text");
    edit(env, "document.getElementById('s').className = 'k'");
    expectMatchesRebuild(env, "class on a span with text");
    edit(env, "document.getElementById('e').className = 'k'");
    expectMatchesRebuild(env, "class on an empty span");
    edit(env, "document.getElementById('p').className = 'k'");
    expectMatchesRebuild(env, "class on a p with text");
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().patchCount(), uint64_t(4));
}

// I2: pseudo-element content is made again whenever an element is matched again, and a fresh build makes all of it in
// document order, so at the text-piece cap a patch and a rebuild cut at different words. Below the caps a page with
// ::before or ::after content patches (attribute and text) and equals a rebuild, limits included.
WR_TEST(testPseudoContentPatchesBelowTheCaps) {
    const char* const shapes[][2] = {
        {".x::before{content:\"a b c d\"} .y::before{content:\"e f g\"}", ""},
        {".x::before{content:ATTR(title)} .z::before{content:\"q\"}", ""},
        {".x::before{content:attr (title)} .z::before{content:\"q\"}", ""},
        {"[title]::before{content:attr(title)} .k::before{content:attr(title)} .x::before{content:\"a b c d\"}",
         "<div class=k title=\"w w w w w w w w w w w w w w w w w w w w w w w w w w w w w w w w w w w w w w w w w w\">k</div>"},
    };
    for (const auto& shape : shapes) {
        for (int words = 0; words <= 4800; words += 1200) {
            RenderEnv env(wordsPage(words, shape[0], (std::string("<div id=d title=\"t t t\">t</div>") + shape[1]).c_str()));
            const uint64_t builds = env.render().buildCount();
            CHECK(flushAgreesWithRebuild(env, "document.getElementById('d').className = 'x'", "class onto pseudo content"));
            CHECK(flushAgreesWithRebuild(env, "document.getElementById('d').firstChild.data = 'changed text'", "text"));
            CHECK_EQ(env.render().buildCount(), builds);
        }
    }
    // The master sheet's summary::before declares content: a document with a <summary> patches too.
    RenderEnv env("<!doctype html><body><details open><summary>s</summary><p id=p>t</p></details></body>");
    CHECK(flushAgreesWithRebuild(env, "document.getElementById('p').className = 'x'", "summary"));
    CHECK(flushAgreesWithRebuild(env, "document.getElementById('p').firstChild.data = 'text'", "summary text"));
}

// Content a class change makes crosses the text-piece cap. A build makes pseudo-element content after all text, in
// document order, so it cuts the later element's content; the commit replays the style pass in that order (twidget
// edit 84), so the patch cuts it there too. Every flush equals a rebuild, limits included.
WR_TEST(testPseudoContentAtTheCapPatches) {
    const char* const sheet = ".x::before{content:\"a b c d e f g h i j k l m n o p q r s t u v w x y z\"}"
                              " .later::before{content:\"A B C D E F G H I J K L M N O P Q R S T U V W X Y Z\"}";
    int reached = 0;
    for (int words = 4920; words <= 5000; words += 4) {
        RenderEnv env(wordsPage(words, sheet, "<div id=d>t</div><div class=later>u</div>"));
        if (!env.render().renderLimits().empty()) {
            continue;
        }
        const uint64_t builds = env.render().buildCount();
        CHECK(flushAgreesWithRebuild(env, "document.getElementById('d').className = 'x'", "content past the cap"));
        CHECK_EQ(env.render().buildCount(), builds);
        if (!env.render().renderLimits().empty()) {
            reached++;
        }
        CHECK(flushAgreesWithRebuild(env, "document.getElementById('d').firstChild.data = 'u'", "text after the cap"));
        CHECK_EQ(env.render().buildCount(), builds);
    }
    CHECK(reached > 0);
}

// A control makes its lh-* parts when it is matched again. Profile 1 drops the <input> (V4 plan, Task 4), so its type
// change renders nothing; a text change near the cap in the next flush still rebuilds (a rule makes pseudo-element
// content), and both equal a rebuild.
WR_TEST(testRangeThenTextNearTheCap) {
    const char* sheet = "lh-range-thumb::before{content:\"B1 B2 B3 B4 B5 B6 B7 B8 B9 B10 B11 B12 B13 B14 B15 B16 B17 B18 B19 B20\"}"
                        " input lh-range-thumb::before{content:\"q\"}";
    for (int words = 4900; words <= 5010; words += 13) {
        RenderEnv env(wordsPage(words, sheet, "<input id=i type=text><p id=t>before</p>"));
        const uint64_t builds = env.render().buildCount();
        // Near the cap a build may already have hit a limit (then every flush rebuilds); either way each flush equals a
        // rebuild, limits included.
        flushAgreesWithRebuild(env, "document.getElementById('i').setAttribute('type', 'range')", "range");
        flushAgreesWithRebuild(env, "document.getElementById('t').firstChild.data = 'n1 n2 n3 n4 n5 n6 n7 n8 n9 n10 n11 n12 n13 n14 n15 n16 n17 n18 n19 n20'", "text");
        CHECK(env.render().buildCount() >= builds);
    }
}

// Pseudo-element rules that make no content, and the master sheet's own (summary), do not stop patching.
WR_TEST(testPseudoRulesWithoutContentPatch) {
    for (const char* sheet : {".x::before{color:#c00}", ".x::before{content:none}", ".x{color:#c00;content:\"abc\"}"}) {
        RenderEnv env(wordsPage(4000, sheet, "<div id=d>t</div>"));
        const uint64_t builds = env.render().buildCount();
        CHECK(flushAgreesWithRebuild(env, "document.getElementById('d').className = 'x'", sheet));
        CHECK(flushAgreesWithRebuild(env, "document.getElementById('d').firstChild.data = 'text'", sheet));
        CHECK_EQ(env.render().buildCount(), builds);
    }
}

// twidget edit 21: the style-byte budget. A patch is charged exactly (what an element held is given back before it is
// charged again), so a document that has charged most of its budget still patches a leaf's class and the body's; a
// patch that really passes the budget replays the style pass in a build's order (twidget edit 84), so it cuts where a
// fresh build does. The same document with small values patches.
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
        return "<!doctype html><style>*{transition:" + list + "} .x{color:#c00} .big{transition:" + list + "," + list +
               "}</style><body><div id=d>t</div>" + elements + "</body>";
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
        // A leaf's class patches, and the predicate walks nothing for the budget.
        const uint64_t builds = env.render().buildCount();
        const uint64_t steps = env.render().document()->predicate_steps();
        CHECK(flushAgreesWithRebuild(env, "document.getElementById('d').className = 'x'", "a leaf's class near the style budget"));
        CHECK_EQ(env.render().buildCount(), builds);
        // The predicate walks nothing for the budget.
        CHECK_EQ(env.render().document()->predicate_steps(), steps);
        // The body's restyle is every element's, each giving back what it held before it is charged again: it patches.
        CHECK(flushAgreesWithRebuild(env, "document.body.className = 'x'", "the body's class near the style budget"));
        CHECK_EQ(env.render().buildCount(), builds);
        // Each <b> taking a list twice as long holds ~26 KB more, past the budget: the commit replays the style pass and
        // charges it from zero in a build's order (twidget edit 84), so the patch cuts where a rebuild does.
        CHECK(flushAgreesWithRebuild(env, "for (const b of document.querySelectorAll('b')) b.className = 'big'",
                                     "every <b> past the style budget"));
        CHECK_EQ(env.render().buildCount(), builds);
        CHECK(env.render().document()->style_bytes_limited());
    }
    // The control: values a hundred times smaller patch.
    {
        RenderEnv env(page(11));
        const uint64_t builds = env.render().buildCount();
        CHECK(flushAgreesWithRebuild(env, "document.getElementById('d').className = 'x'", "class far from the style budget"));
        CHECK_EQ(env.render().buildCount(), builds);
        // Nothing is walked for the budget.
        CHECK_EQ(env.render().document()->predicate_steps(), uint64_t(0));
    }
}

// Ruling E51 under twidget edit 84: no estimate sees inline styles, which are charged as styles are computed, so an insert
// whose elements' inline var() splices pass the budget is replayed after the commit's restyle, as a build's style pass.
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
    const uint64_t builds = env.render().buildCount();
    CHECK(flushAgreesWithRebuild(env,
                                 "const d = document.getElementById('d'); for (let i = 0; i < 100; i++) { const e = document.createElement('b'); "
                                 "e.setAttribute('style', '--y:var(--x)'); d.appendChild(e); }",
                                 "inserts past the style budget"));
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK(env.render().document()->style_bytes_limited());
}

// The table-cell cap: a span change past it patches, as one below it does.
WR_TEST(testSpanChangeCutsAtTheCellCap) {
    RenderEnv env("<!doctype html><body><table><tbody><tr><td colspan=1000 rowspan=199>a</td><td id=b>b</td></tr></tbody></table></body>");
    const uint64_t builds = env.render().buildCount();
    CHECK(flushAgreesWithRebuild(env, "document.getElementById('b').setAttribute('colspan', '1000')", "200,000 cells"));
    CHECK_EQ(env.render().buildCount(), builds);
    // Past the cap: the commit recounts the cells from the root, as a build does (twidget edit 84).
    CHECK(flushAgreesWithRebuild(env, "document.getElementById('b').setAttribute('rowspan', '2')", "past the cap"));
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK(flushAgreesWithRebuild(env, "document.getElementById('b').setAttribute('colspan', '2')", "back under"));
    CHECK(flushAgreesWithRebuild(env, "document.getElementById('b').removeAttribute('rowspan')", "limit gone"));
    CHECK(flushAgreesWithRebuild(env, "document.getElementById('b').setAttribute('colspan', '3')", "patching again"));
}

// I3: an element's attributes are applied in one call, one re-match.
WR_TEST(testManyAttributesAreOneRematch) {
    const int counts[2] = {2500, 10000};
    for (int k = 0; k < 2; k++) {
        RenderEnv env("<!doctype html><body><div id=d>box</div></body>");
        const std::string n = std::to_string(counts[k]);
        edit(env, "const e = document.getElementById('d'); for (let i = 0; i < " + n + "; i++) e.setAttribute('data-a' + i, 'v')");
        const uint64_t builds = env.render().buildCount();
        litehtml::document* document = env.render().document();
        const uint64_t before = document->attribute_rematches();
        CHECK_EQ(env.env().eval("const e = document.getElementById('d'); for (let i = 0; i < " + n +
                                "; i++) e.setAttribute('data-a' + i, 'w'); 'ok'"),
                 std::string("ok"));
        env.flush();
        CHECK_EQ(env.render().buildCount(), builds);
        CHECK(env.render().document() == document);
        CHECK_EQ(document->attribute_rematches() - before, uint64_t(1));
        expectMatchesRebuild(env, "many attributes");
    }
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

// twidget edit 77: a class on <html> that rules read in an ancestor position is one patch over the document, its reach
// walked once; a descendant's display that flips with it is replaced and placed.
WR_TEST(testARootClassPatches) {
    std::string page = "<!doctype html><html><head><style>body{margin:0} .dark p{color:#eee} .big b{display:block}</style>"
                       "</head><body>";
    for (int i = 0; i < 600; i++) {
        page += "<p>p <b>b</b></p>";
    }
    RenderEnv env(page + "</body></html>");
    const uint64_t builds = env.render().buildCount();
    const uint64_t patches = env.render().patchCount();
    edit(env, "document.documentElement.className = 'dark'");
    if (env.render().buildCount() != builds) {
        std::printf("  rebuilt (%s)\n", env.render().lastPatchRefusal());
    }
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().patchCount(), patches + 1);
    expectMatchesRebuild(env, "a theme class on <html>");
    // A descendant's display flips: its subtree is replaced.
    edit(env, "document.documentElement.className = 'dark big'");
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().patchCount(), patches + 2);
    expectMatchesRebuild(env, "a display flipped below <html>");
}
