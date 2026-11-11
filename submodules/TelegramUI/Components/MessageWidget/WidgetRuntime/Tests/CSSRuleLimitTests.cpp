// widget-sandbox v0.3.0, limit.css-rules: at most 400 style rules and 32 `@keyframes` in the document's stylesheets,
// past which the widget stops ("CSS limit exceeded"). Counted as upstream's validator counts them (countCssRules): a
// rule inside `@media`, `@supports` or another at-rule counts, a keyframe selector inside `@keyframes` does not, and
// braces inside strings and comments are not blocks.
#include <string>

#include "Sources/Render/CSSRuleCount.h"
#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Errors.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

using wr_test::RenderEnv;

namespace {

std::string rules(int count, const char* prefix = ".r") {
    std::string css;
    for (int i = 0; i < count; i++) {
        css += std::string(prefix) + std::to_string(i) + "{color:red}";
    }
    return css;
}

std::string counted(std::string_view css) {
    const wr::CSSRuleCount count = wr::countCssRules(css);
    return std::to_string(count.rules) + "," + std::to_string(count.keyframes);
}

bool flushStops(RenderEnv& env) {
    try {
        env.flush();
    } catch (const wr::Aborted&) {
        return true;
    }
    return false;
}

} // namespace

/// Upstream's countCssRules, case by case.
WR_TEST(testTheRuleCount) {
    CHECK_EQ(counted("a{color:red} b{color:blue}"), std::string("2,0"));
    CHECK_EQ(counted("@media (min-width: 1px) { a{} b{} } c{}"), std::string("3,0"));
    CHECK_EQ(counted("@supports (display:grid) { @media screen { a{} } }"), std::string("1,0"));
    CHECK_EQ(counted("@keyframes k { from{opacity:0} 50%{opacity:.5} to{opacity:1} } a{}"), std::string("1,1"));
    CHECK_EQ(counted("@-webkit-keyframes k { from{} to{} } @KEYFRAMES j { to{} }"), std::string("0,2"));
    CHECK_EQ(counted("a{content:'{}{}'} /* b{} c{} */ d{}"), std::string("2,0"));
    CHECK_EQ(counted("a{content:\"\\\"{\"} b{}"), std::string("2,0"));
    CHECK_EQ(counted("@font-face { font-family: x } @page { margin: 0 }"), std::string("0,0"));
    CHECK_EQ(counted("a{} b{"), std::string("2,0"));
    CHECK_EQ(counted(""), std::string("0,0"));
}

/// 400 rules apply; one more in the document's sheets stops the widget, and the tree from before stays.
WR_TEST(testRulesPastTheCapStop) {
    RenderEnv env("<!doctype html><html><head><style>" + rules(399) + "</style></head><body><p id=p>t</p></body></html>");
    CHECK(env.env().runtime().stopReason() == wr::StopReason::None);
    env.env().eval("const s = document.createElement('style'); s.textContent = 'p{color:blue}'; document.head.append(s); 1");
    CHECK(!flushStops(env));
    const std::string before = env.render().layerTree()->dump();
    env.env().eval("const t = document.createElement('style'); t.textContent = 'q{color:blue}'; document.head.append(t); 1");
    CHECK(flushStops(env));
    CHECK(env.env().runtime().stopReason() == wr::StopReason::Limit);
    CHECK_EQ(env.env().runtime().stopDetail(), std::string("CSS limit exceeded: 401 rules in the document's stylesheets (max 400)"));
    CHECK_EQ(env.render().layerTree()->dump(), before);
}

/// 33 @keyframes stop the widget at its boot.
WR_TEST(testKeyframesPastTheCapStop) {
    std::string css;
    for (int i = 0; i < 33; i++) {
        css += "@keyframes k" + std::to_string(i) + "{to{opacity:0}}";
    }
    RenderEnv env("<!doctype html><html><head><style>" + css + "</style></head><body><p>t</p></body></html>");
    CHECK(env.env().runtime().stopReason() == wr::StopReason::Limit);
    CHECK_EQ(env.env().runtime().stopDetail(), std::string("CSS limit exceeded: 33 @keyframes in the document's stylesheets (max 32)"));
}

/// Compat has no rule cap.
WR_TEST(testCompatHasNoRuleCap) {
    wr_test::ScopedLimits compat(wr::Limits::compat());
    RenderEnv env("<!doctype html><html><head><style>" + rules(1000) + "</style></head><body><p>t</p></body></html>");
    CHECK(env.env().runtime().stopReason() == wr::StopReason::None);
}
