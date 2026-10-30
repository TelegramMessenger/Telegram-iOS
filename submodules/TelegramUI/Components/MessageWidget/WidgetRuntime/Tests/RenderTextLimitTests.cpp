// Profile 1's text and node limits in the renderer's copy (V4 plan, Task 7; RB §7) as they drop: the compat policy's
// Text value of at most 65,536 UTF-16 units and 262,144 units of text in the document (widget-sandbox v0.3.0's strict
// caps stop the widget instead: StrictLimitsTests), 8,192 of complex-script text, and 50,000 nodes. A build hands the
// budgets out in tree order; what does not fit is not rendered, the walk going on (past the node cap it stops), and a
// patch that crosses a limit walks the cut as a build walks it (RenderCut.h), so a flush always equals a rebuild.
#include <cstdio>
#include <string>
#include <tuple>

#include "Sources/Render/Builder.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

using wr_test::RenderEnv;

namespace {

std::string page(const std::string& body) {
    return "<!doctype html><html><head></head><body>" + body +
           "<script>window.$ = id => document.getElementById(id);"
           "window.h = id => $(id).getBoundingClientRect().height;</script></body></html>";
}

bool hasLimit(RenderEnv& env, const std::string& kind) {
    for (const std::string& limit : env.render().renderLimits()) {
        if (limit == kind) {
            return true;
        }
    }
    return false;
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

std::string units(wr::TextUnits u) {
    return std::to_string(u.units) + "," + std::to_string(u.complex);
}

} // namespace

/// RB §7.2: UTF-16 units, and the complex ones (>= U+0590: each surrogate of an emoji, typographic punctuation, CJK).
WR_TEST(testTheUnits) {
    RenderEnv env(page(""));
    std::string emoji;
    for (int i = 0; i < 100; i++) {
        emoji += "\xF0\x9F\x98\x80";
    }
    CHECK_EQ(units(wr::renderTextUnits(wr::String::fromUTF8(env.ctx(), emoji))), std::string("200,200"));
    CHECK_EQ(units(wr::renderTextUnits(wr::String::fromUTF8(env.ctx(), "\xE2\x80\x94\xE2\x80\xA6\xE2\x82\xAC\xE2\x96\xB2"))),
             std::string("4,4"));
    CHECK_EQ(units(wr::renderTextUnits(wr::String::fromUTF8(env.ctx(), "abc\xD0\x96"))), std::string("4,0"));
    // cssStringText: the contents of the strings, a backslash in one taking the next character.
    CHECK_EQ(units(wr::renderCssStringUnits("content:\"ab\" '\\x'")), std::string("3,0"));
    CHECK_EQ(units(wr::renderCssStringUnits("a\\\"b:\"\xE5\xAD\x97\"")), std::string("1,1"));
    // Reaching a budget exactly is allowed.
    const wr::Limits compat = wr::Limits::compat(), strict = wr::Limits::strict();
    CHECK(wr::renderTextFits(compat, {65536, 0}, {196608, 0}));
    CHECK(wr::renderTextFit(compat, {65537, 0}, {0, 0}) == wr::TextFit::ValueTooLong);
    CHECK(wr::renderTextFit(compat, {1, 0}, {262144, 0}) == wr::TextFit::OverBudget);
    CHECK(wr::renderTextFits(compat, {10, 10}, {100, 8182}));
    CHECK(wr::renderTextFit(compat, {10, 10}, {100, 8183}) == wr::TextFit::OverComplexBudget);
    CHECK(wr::renderTextFits(strict, {32768, 0}, {16384, 0}));
    CHECK(wr::renderTextFit(strict, {32769, 0}, {0, 0}) == wr::TextFit::ValueTooLong);
    CHECK(wr::renderTextFit(strict, {1, 0}, {49152, 0}) == wr::TextFit::OverBudget);
    CHECK(wr::renderTextFit(strict, {10, 10}, {100, 8183}) == wr::TextFit::OverComplexBudget);
}

/// Review Focus 5: 65,536 units render, 65,537 do not, through a patch and through a build.
WR_TEST(testATextNodeAtTheCapRendersAndOnePastItDoesNot) {
    wr_test::ScopedLimits compat(wr::Limits::compat());
    RenderEnv env(page("<div id=a style=\"white-space:nowrap;overflow:hidden;width:200px\">x</div>"));
    const uint64_t builds = env.render().buildCount();
    const uint64_t patches = env.render().patchCount();
    env.env().eval("$('a').firstChild.data = 'a'.repeat(65536); 1");
    env.flush();
    CHECK_EQ(env.env().eval("h('a') > 0"), std::string("true"));
    CHECK_EQ(env.render().patchCount(), patches + 1);
    CHECK(env.render().renderLimits().empty());
    env.env().eval("$('a').firstChild.data = 'a'.repeat(65537); 1");
    env.flush();
    CHECK_EQ(env.env().eval("h('a')"), std::string("0"));
    // Past the cap the flush walks the cut (RenderCut.h) and patches.
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().patchCount(), patches + 2);
    CHECK(hasLimit(env, "text-node"));
    expectMatchesRebuild(env, "past the cap");
    RenderEnv markup(page("<div id=a>" + std::string(65537, 'b') + "</div>"));
    CHECK_EQ(markup.env().eval("h('a')"), std::string("0"));
    CHECK(hasLimit(markup, "text-node"));
}

/// RB §7.3: four 65,536-unit texts fill the document's 262,144 exactly; a fifth of one unit does not fit.
WR_TEST(testTheDocumentBudget) {
    wr_test::ScopedLimits compat(wr::Limits::compat());
    RenderEnv env(page(""));
    env.env().eval("for (let i = 0; i < 5; i++) { const d = document.createElement('div'); d.id = 'd' + i;"
                   " d.textContent = i < 4 ? 'a'.repeat(65536) : 'x'; document.body.append(d); } 1");
    env.flush();
    CHECK_EQ(env.env().eval("[0, 1, 2, 3].every(i => h('d' + i) > 0)"), std::string("true"));
    CHECK_EQ(env.env().eval("h('d4')"), std::string("0"));
    CHECK(hasLimit(env, "text-budget"));
    expectMatchesRebuild(env, "budget");
}

/// RB §9 limit.text-budget: 8,192 units of complex-script text.
WR_TEST(testTheComplexScriptBudget) {
    RenderEnv env(page("<div id=a></div><div id=b></div>"));
    env.env().eval("$('a').textContent = '\xE6\xBC\xA2'.repeat(3000); 1");
    env.flush();
    CHECK_EQ(env.env().eval("h('a') > 0"), std::string("true"));
    CHECK(env.render().renderLimits().empty());
    env.env().eval("$('b').textContent = '\xE5\xAD\x97'.repeat(6000); 1");
    env.flush();
    CHECK_EQ(env.env().eval("[h('a') > 0, h('b')].join()"), std::string("true,0"));
    CHECK(hasLimit(env, "text-budget"));
    expectMatchesRebuild(env, "complex");
}

/// RB §9 behaviour.policy-strict: a text attribute over 65,536 units is left out of the renderer's copy; the DOM keeps it.
WR_TEST(testATextAttributeOverTheCapIsLeftOut) {
    wr_test::ScopedLimits compat(wr::Limits::compat());
    RenderEnv env("<!doctype html><html><head><style>[data-big]{color:rgb(9,9,9)}</style></head><body><p id=p>t</p>"
                  "<script>window.$ = id => document.getElementById(id);"
                  "window.cs = id => getComputedStyle($(id)).color;</script></body></html>");
    env.env().eval("$('p').setAttribute('data-big', 'z'.repeat(307200)); 1");
    env.flush();
    CHECK_EQ(env.env().eval("cs('p') !== 'rgb(9, 9, 9)'"), std::string("true"));
    CHECK_EQ(env.env().eval("String($('p').getAttribute('data-big').length)"), std::string("307200"));
    expectMatchesRebuild(env, "attribute past the cap");
    env.env().eval("$('p').setAttribute('data-big', 'z'.repeat(65536)); 1");
    env.flush();
    CHECK_EQ(env.env().eval("cs('p')"), std::string("rgb(9, 9, 9)"));
}

/// RB §7.1 MAX_NODES: the document node, every element, Text and Comment, rendered or not (a <script>'s children aside).
WR_TEST(testTheNodeCap) {
    wr_test::ScopedLimits compat(wr::Limits::compat());
    // document, html, head, body, div#d: five nodes before the comments; then span#last, its Text, the script.
    for (const auto& [comments, rendered] : {std::pair<int, bool>{49995, false}, std::pair<int, bool>{40000, true}}) {
        RenderEnv env("<!doctype html><html><head></head><body><div id=d></div><script>"
                      "window.$ = id => document.getElementById(id);</script></body></html>");
        env.env().eval("for (let i = 0; i < " + std::to_string(comments) + "; i++) $('d').appendChild(document.createComment('c'));"
                       " const s = document.createElement('span'); s.id = 'last'; s.style.display = 'block'; s.textContent = 'z';"
                       " $('d').appendChild(s); 1");
        env.flush();
        CHECK_EQ(env.env().eval("$('last').getBoundingClientRect().height > 0"), std::string(rendered ? "true" : "false"));
        CHECK_EQ(hasLimit(env, "nodes"), !rendered);
        expectMatchesRebuild(env, "nodes");
    }
}

WR_TEST(testAStructurePatchPastABudgetMatchesARebuild) {
    wr_test::ScopedLimits compat(wr::Limits::compat());
    RenderEnv env(page("<div id=d>x</div>"));
    const uint64_t builds = env.render().buildCount();
    env.env().eval("$('d').appendChild(document.createTextNode('a'.repeat(70000))); 1");
    env.flush();
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK(hasLimit(env, "text-node"));
    CHECK(wr_test::countsMatchAFreshBuild(env, "inserted past the cap"));
    expectMatchesRebuild(env, "inserted past the cap");
}

namespace {

/// 49,860 comments in markup: with the document, html, head, body, the div and the video, 49,866 nodes. The video is in
/// the div, so a patch under the body does not walk it again.
std::string nearTheNodeCap() {
    std::string html = "<!doctype html><html><head></head><body><div id=d>";
    for (int i = 0; i < 49860; i++) {
        html += "<!--c-->";
    }
    return html + "<video id=v></video></div></body></html>";
}

void appendTheLastSpan(RenderEnv& env) {
    env.env().eval("const s = document.createElement('span'); s.id = 'last'; s.style.display = 'block';"
                   " s.textContent = 'z'; document.body.appendChild(s); 1");
    env.flush();
}

} // namespace

/// The final review's C2: nodes a patch inserts without building them (comments) count toward the node cap, so a later
/// patch past it cuts where a fresh build would.
WR_TEST(testCommentsAPatchInsertsCountTowardTheNodeCap) {
    wr_test::ScopedLimits compat(wr::Limits::compat());
    RenderEnv env(nearTheNodeCap());
    CHECK(env.render().renderLimits().empty());
    env.env().eval("for (let i = 0; i < 150; i++) document.body.appendChild(document.createComment('c')); 1");
    env.flush();
    expectMatchesRebuild(env, "comments");
    appendTheLastSpan(env);
    CHECK_EQ(env.env().eval("document.getElementById('last').getBoundingClientRect().height > 0"), std::string("false"));
    CHECK(hasLimit(env, "nodes"));
    expectMatchesRebuild(env, "the span past the cap");
}

/// A removal the journal does not hear (inside an element no build renders) lowers the node count: what a build cut at
/// the cap comes back, as a fresh build renders it.
WR_TEST(testAnUnheardRemovalBringsBackWhatTheNodeCapCut) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    RenderEnv env(nearTheNodeCap());
    env.env().eval("const v = document.getElementById('v'); for (let i = 0; i < 150; i++) v.appendChild(document.createElement('i')); 1");
    env.flush();
    appendTheLastSpan(env);
    CHECK_EQ(env.env().eval("document.getElementById('last').getBoundingClientRect().height > 0"), std::string("false"));
    CHECK(hasLimit(env, "nodes"));
    env.env().eval("document.getElementById('v').replaceChildren(); 1");
    env.flush();
    CHECK_EQ(env.env().eval("document.getElementById('last').getBoundingClientRect().height > 0"), std::string("true"));
    expectMatchesRebuild(env, "the span back under the cap");
}

/// The final review's C2: an insertion the journal does not hear (inside an element the profile drops) still counts.
WR_TEST(testAnUnheardInsertionCountsTowardTheNodeCap) {
    wr_test::ScopedLimits compat(wr::Limits::compat());
    RenderEnv env(nearTheNodeCap());
    env.env().eval("const v = document.getElementById('v'); for (let i = 0; i < 150; i++) v.appendChild(document.createElement('i')); 1");
    env.flush();
    expectMatchesRebuild(env, "inside the video");
    appendTheLastSpan(env);
    CHECK_EQ(env.env().eval("document.getElementById('last').getBoundingClientRect().height > 0"), std::string("false"));
    CHECK(hasLimit(env, "nodes"));
    expectMatchesRebuild(env, "the span past the cap");
}
