// widget-sandbox v0.3.0, "Strict limits from the start": a counted cap passed stops the widget with upstream's reason
// (StopReason::Limit, Runtime::stopDetail), and the last published tree stays, as the bubble keeps its last render.
// The caps are judged on the render build, over what the renderer's copy holds (the plan's R-counting). Compat keeps
// the caps from before v0.3.0 and drops instead of stopping.
#include <string>

#include "Sources/Render/LayerTree.h"
#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Errors.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

using wr_test::RenderEnv;

namespace {

std::string page(const std::string& head, const std::string& body) {
    return "<!doctype html><html><head>" + head + "</head><body>" + body +
           "<script>window.$ = id => document.getElementById(id);"
           "window.h = id => $(id).getBoundingClientRect().height;"
           "window.cs = id => getComputedStyle($(id)).color;</script></body></html>";
}

/// render().flush(); true when it stopped the widget.
bool flushStops(RenderEnv& env) {
    try {
        env.flush();
    } catch (const wr::Aborted&) {
        return true;
    }
    return false;
}

std::string treeDump(RenderEnv& env) {
    const auto tree = env.render().layerTree();
    return tree ? tree->dump() : std::string();
}

bool stoppedWith(RenderEnv& env, const std::string& detail) {
    const bool same = env.env().runtime().stopReason() == wr::StopReason::Limit && env.env().runtime().stopDetail() == detail;
    if (!same) {
        std::printf("    stopped %d with \"%s\", wanted \"%s\"\n", int(env.env().runtime().stopReason()),
                    env.env().runtime().stopDetail().c_str(), detail.c_str());
    }
    return same;
}

} // namespace

/// limit.text-node: 32,768 units render; 40,000 stop the widget, and the tree from before stays.
WR_TEST(testATextValueAtTheCapRendersAndOnePastItStops) {
    RenderEnv env(page("", "<div id=a style=\"white-space:nowrap;overflow:hidden;width:200px\">x</div>"));
    env.env().eval("$('a').firstChild.data = 'a'.repeat(32768); 1");
    CHECK(!flushStops(env));
    CHECK_EQ(env.env().eval("h('a') > 0"), std::string("true"));
    const std::string before = treeDump(env);
    env.env().eval("$('a').firstChild.data = 'a'.repeat(40000); 1");
    CHECK(flushStops(env));
    CHECK(stoppedWith(env, "Text limit exceeded: a text value of 40000 characters (max 32768)"));
    CHECK_EQ(treeDump(env), before);
}

/// A boot whose markup already passes a cap publishes nothing: the parse's flush stops it.
WR_TEST(testMarkupPastTheCapStopsTheBoot) {
    RenderEnv env(page("", "<div id=a>" + std::string(40000, 'b') + "</div>"));
    CHECK(stoppedWith(env, "Text limit exceeded: a text value of 40000 characters (max 32768)"));
    CHECK(env.render().layerTree() == nullptr);
}

/// limit.text-budget: two texts of 24,576 units fill the document's 49,152 exactly; one more unit stops the widget.
WR_TEST(testTheDocumentsTextPastItsBudgetStops) {
    RenderEnv env(page("", ""));
    env.env().eval("for (let i = 0; i < 2; i++) { const d = document.createElement('div'); d.id = 'd' + i;"
                   " d.textContent = 'a'.repeat(24576); document.body.append(d); } 1");
    CHECK(!flushStops(env));
    CHECK_EQ(env.env().eval("h('d0') > 0 && h('d1') > 0"), std::string("true"));
    const std::string before = treeDump(env);
    env.env().eval("const x = document.createElement('div'); x.textContent = 'x'; document.body.append(x); 1");
    CHECK(flushStops(env));
    CHECK(stoppedWith(env, "Text limit exceeded: the document's text is over 49152 characters"));
    CHECK_EQ(treeDump(env), before);
}

/// The complex-script budget still drops, and never stops: a widget in those scripts needs all of its budget.
WR_TEST(testComplexTextPastItsBudgetIsDroppedNotStopped) {
    RenderEnv env(page("", "<div id=a></div><div id=b></div>"));
    env.env().eval("$('a').textContent = '\xE6\xBC\xA2'.repeat(3000); $('b').textContent = '\xE5\xAD\x97'.repeat(6000); 1");
    CHECK(!flushStops(env));
    CHECK_EQ(env.env().eval("[h('a') > 0, h('b')].join()"), std::string("true,0"));
    CHECK(env.env().runtime().stopReason() == wr::StopReason::None);
}

/// limit.attribute: a 6 K data-* attribute reaches the renderer (auto/19); one of 9,000 units stops the widget.
WR_TEST(testAnAttributePastTheCapStops) {
    RenderEnv env(page("<style>[data-big]{color:rgb(9,9,9)}</style>", "<p id=p>t</p>"));
    env.env().eval("$('p').setAttribute('data-big', 'z'.repeat(6144)); 1");
    CHECK(!flushStops(env));
    CHECK_EQ(env.env().eval("cs('p')"), std::string("rgb(9, 9, 9)"));
    const std::string before = treeDump(env);
    env.env().eval("$('p').setAttribute('data-x', 'x'.repeat(9000)); 1");
    CHECK(flushStops(env));
    CHECK(stoppedWith(env, "Attribute limit exceeded: a value of 9000 characters (max 8192)"));
    CHECK_EQ(treeDump(env), before);
}

/// The attribute cap is every attribute's, an inline style's and a src's included.
WR_TEST(testAnInlineStyleOrASourcePastTheCapStops) {
    {
        RenderEnv env(page("", "<p id=p>t</p>"));
        env.env().eval("$('p').setAttribute('style', 'color:red;/*' + 'x'.repeat(9000) + '*/'); 1");
        CHECK(flushStops(env));
        CHECK(stoppedWith(env, "Attribute limit exceeded: a value of 9014 characters (max 8192)"));
    }
    {
        RenderEnv env(page("", "<img id=i alt=''>"));
        env.env().eval("$('i').src = 'data:image/png;base64,' + 'A'.repeat(9000); 1");
        CHECK(flushStops(env));
        CHECK(stoppedWith(env, "Attribute limit exceeded: a value of 9022 characters (max 8192)"));
    }
}

/// A canvas string and Path2D data are text values too: past 32,768 units the call stops the widget.
WR_TEST(testACanvasStringOrPathDataPastTheCapStops) {
    {
        RenderEnv env(page("", "<canvas id=c></canvas>"));
        CHECK_EQ(env.env().eval("$('c').getContext('2d').fillText('a'.repeat(32768), 0, 10); 1"), std::string("1"));
        CHECK_EQ(env.env().eval("$('c').getContext('2d').fillText('a'.repeat(40000), 0, 10); 1"), std::string("ABORTED"));
        CHECK(stoppedWith(env, "Text limit exceeded: a text value of 40000 characters (max 32768)"));
    }
    {
        RenderEnv env(page("", ""));
        CHECK_EQ(env.env().eval("new Path2D('M0 0' + ' L1 1'.repeat(8000)); 1"), std::string("ABORTED"));
        CHECK(stoppedWith(env, "Text limit exceeded: a text value of 40004 characters (max 32768)"));
    }
}

/// Compat keeps the caps from before v0.3.0 and never stops on one: the stress kit's measuring runs.
WR_TEST(testCompatKeepsTheOldTextCapsAndDrops) {
    wr_test::ScopedLimits compat(wr::Limits::compat());
    RenderEnv env(page("<style>[data-x]{color:rgb(9,9,9)}</style>", "<div id=a>x</div><p id=p>t</p>"));
    env.env().eval("$('a').firstChild.data = 'a'.repeat(40000); $('p').setAttribute('data-x', 'x'.repeat(9000)); 1");
    CHECK(!flushStops(env));
    CHECK_EQ(env.env().eval("[h('a') > 0, cs('p')].join()"), std::string("true,rgb(9, 9, 9)"));
    env.env().eval("$('a').firstChild.data = 'a'.repeat(65537); 1");
    CHECK(!flushStops(env));
    CHECK_EQ(env.env().eval("h('a')"), std::string("0"));
    CHECK(env.env().runtime().stopReason() == wr::StopReason::None);
}
