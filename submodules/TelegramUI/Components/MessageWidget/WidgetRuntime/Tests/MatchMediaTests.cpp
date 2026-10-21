// CSSOM View's matchMedia and MediaQueryList (V3b plan, Task 1): a query is evaluated by litehtml's media query parser
// against the container's media features, exactly as @media is, so the two always agree; a change of the features (the
// host's theme) reports a `change` to every list whose answer flipped, after the task that changed them.
#include <string>

#include <litehtml/string_id.h>

#include "Sources/Host/HostState.h"
#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Work.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

using wr_test::RenderEnv;

namespace {

// Each probe is rgb(0, 0, 2) exactly when its @media applies.
const char* const kProbes =
    "<!doctype html><html><head><style>"
    "div { color: rgb(0, 0, 1) }"
    "@media (min-width: 200px) { #w { color: rgb(0, 0, 2) } }"
    "@media (max-width: 100px) { #n { color: rgb(0, 0, 2) } }"
    "@media (prefers-color-scheme: dark) { #d { color: rgb(0, 0, 2) } }"
    "@media (prefers-reduced-motion: reduce) { #r { color: rgb(0, 0, 2) } }"
    "@media (hover: hover) { #h { color: rgb(0, 0, 2) } }"
    "@media (pointer: fine) { #p { color: rgb(0, 0, 2) } }"
    "@media print { #pr { color: rgb(0, 0, 2) } }"
    "</style></head><body><div id=w></div><div id=n></div><div id=d></div><div id=r></div><div id=h></div>"
    "<div id=p></div><div id=pr></div>"
    "<script>for (const e of document.querySelectorAll('[id]')) window[e.id] = e;"
    "window.agree = (el, q) => (getComputedStyle(el).color === 'rgb(0, 0, 2)') === matchMedia(q).matches;</script>"
    "</body></html>";

const char* const kEmpty = "<!doctype html><html><head></head><body></body></html>";

void switchTheme(RenderEnv& env, wr::Theme theme) {
    wr::HostState::of(env.ctx()).themeChanged(env.ctx(), theme);
    env.env().drain();
}

uint64_t unitsOf(RenderEnv& env, const std::string& code) {
    JSRuntime* rt = env.env().runtime().jsRuntime();
    const uint64_t before = JS_GetWorkUnits(rt);
    env.env().eval(code);
    return JS_GetWorkUnits(rt) - before;
}

} // namespace

WR_TEST(testAWidthQueryMatchesTheLayoutWidth) {
    RenderEnv env(kEmpty);
    CHECK_EQ(env.env().eval("matchMedia('(min-width: 1px)').matches"), std::string("true"));
    CHECK_EQ(env.env().eval("matchMedia('(max-width: 100px)').matches"), std::string("false"));
    CHECK_EQ(env.env().eval("matchMedia('(min-width: 300px) and (max-width: 300px)').matches"), std::string("true"));
    CHECK_EQ(env.env().eval("matchMedia('screen').matches"), std::string("true"));
    CHECK_EQ(env.env().eval("matchMedia('') .matches"), std::string("true"));
    CHECK_EQ(env.env().eval("matchMedia('(min-width: 1px)') instanceof MediaQueryList && "
                            "matchMedia('(min-width: 1px)') instanceof EventTarget"),
             std::string("true"));
    // A new object per call.
    CHECK_EQ(env.env().eval("matchMedia('screen') !== matchMedia('screen')"), std::string("true"));
}

WR_TEST(testMediaIsTheQuery) {
    RenderEnv env(kEmpty);
    CHECK_EQ(env.env().eval("matchMedia('(min-width: 1px)').media.replace(/\\s/g, '')"), std::string("(min-width:1px)"));
    CHECK_EQ(env.env().eval("matchMedia('  screen  ').media"), std::string("screen"));
}

WR_TEST(testMatchMediaAgreesWithAtMedia) {
    RenderEnv env(kProbes);
    CHECK_EQ(env.env().eval("[agree(w, '(min-width: 200px)'), agree(n, '(max-width: 100px)'),"
                            " agree(d, '(prefers-color-scheme: dark)'), agree(r, '(prefers-reduced-motion: reduce)'),"
                            " agree(h, '(hover: hover)'), agree(p, '(pointer: fine)'), agree(pr, 'print')].join()"),
             std::string("true,true,true,true,true,true,true"));
    // Profile 1 drops hover and pointer; print never applies.
    CHECK_EQ(env.env().eval("[matchMedia('(hover: hover)').matches, matchMedia('(pointer: coarse)').matches,"
                            " matchMedia('(pointer: fine)').matches, matchMedia('print').matches].join()"),
             std::string("false,false,false,false"));
}

WR_TEST(testPrefersColorSchemeFollowsTheTheme) {
    RenderEnv env(kProbes);
    CHECK_EQ(env.env().eval("matchMedia('(prefers-color-scheme: dark)').matches"), std::string("false"));
    CHECK_EQ(env.env().eval("matchMedia('(prefers-color-scheme: light)').matches"), std::string("true"));
    switchTheme(env, wr::Theme::Dark);
    CHECK_EQ(env.env().eval("matchMedia('(prefers-color-scheme: dark)').matches"), std::string("true"));
    CHECK_EQ(env.env().eval("agree(d, '(prefers-color-scheme: dark)')"), std::string("true"));
}

WR_TEST(testAChangeEventFiresWhenTheThemeFlips) {
    RenderEnv env(kEmpty);
    env.env().eval("window.log = [];"
                   "window.m = matchMedia('(prefers-color-scheme: dark)');"
                   "m.addEventListener('change', e => log.push('l:' + e.matches + ':' + e.media.replace(/\\s/g, '') +"
                   "  ':' + (e instanceof MediaQueryListEvent)));"
                   "m.onchange = e => log.push('h:' + e.matches);"
                   "m.addListener(e => log.push('a:' + e.matches));"
                   "window.w = matchMedia('(min-width: 1px)');"
                   "w.onchange = () => log.push('width');");
    switchTheme(env, wr::Theme::Dark);
    CHECK_EQ(env.env().eval("log.join()"), std::string("l:true:(prefers-color-scheme:dark):true,h:true,a:true"));
    switchTheme(env, wr::Theme::Light);
    CHECK_EQ(env.env().eval("log.slice(3).join()"), std::string("l:false:(prefers-color-scheme:dark):true,h:false,a:false"));
    // The same theme again: nothing flipped, nothing fires.
    switchTheme(env, wr::Theme::Light);
    CHECK_EQ(env.env().eval("log.length"), std::string("6"));
}

WR_TEST(testAListWithAListenerOutlivesItsWrapper) {
    RenderEnv env(kEmpty);
    env.env().eval("window.log = []; matchMedia('(prefers-color-scheme: dark)').onchange = e => log.push(e.matches); 1");
    JS_RunGC(env.env().runtime().jsRuntime());
    switchTheme(env, wr::Theme::Dark);
    CHECK_EQ(env.env().eval("log.join()"), std::string("true"));
}

WR_TEST(testRemoveListenerStopsTheEvents) {
    RenderEnv env(kEmpty);
    env.env().eval("window.log = []; window.m = matchMedia('(prefers-color-scheme: dark)');"
                   "window.f = e => log.push('a'); m.addListener(f); m.removeListener(f);"
                   "window.g = e => log.push('g'); m.addEventListener('change', g); m.removeEventListener('change', g);"
                   "m.addEventListener('change', e => log.push('kept'));");
    switchTheme(env, wr::Theme::Dark);
    CHECK_EQ(env.env().eval("log.join()"), std::string("kept"));
}

WR_TEST(testAnUnknownMediaKeywordDoesNotGrowTheIdTable) {
    RenderEnv env(kEmpty);
    CHECK_EQ(env.env().eval("matchMedia('(prefers-color-scheme: never-a-scheme-7)').matches"), std::string("false"));
    litehtml::string_id id;
    CHECK(!litehtml::_find_id("never-a-scheme-7", id));
}

WR_TEST(testMatchMediaIsChargedByTheQuery) {
    RenderEnv env(kEmpty);
    // Both queries are built before the measurement, so the measured script is the same few bytes.
    // Under the 16 KB cap (testAnOverlongQueryIsRefused).
    env.env().eval("window.s = '(min-width: 1px)'; window.q = s + ' and (min-width: 1px)'.repeat(700); 1");
    const uint64_t length = uint64_t(std::stoull(env.env().eval("q.length")));
    unitsOf(env, "matchMedia(s).matches");
    const uint64_t shortCost = unitsOf(env, "matchMedia(s).matches");
    const uint64_t longCost = unitsOf(env, "matchMedia(q).matches");
    CHECK(longCost >= shortCost + length * wr::work::kCssByte);
}

/// The final review's C2: a query past kMaxMediaQueryBytes is refused before it is copied or parsed (litehtml's
/// tokenizer allocates outside the memory limit): it never matches, reads back as "not all", and costs a constant.
WR_TEST(testAnOverlongQueryIsRefused) {
    RenderEnv env(kEmpty);
    env.env().eval("window.q = '(min-width: 1px)' + ' and (min-width: 1px)'.repeat(2000); 1");
    CHECK_EQ(env.env().eval("(m => m.matches + ':' + m.media)(matchMedia(q))"), std::string("false:not all"));
    unitsOf(env, "matchMedia(q).matches");
    CHECK(unitsOf(env, "matchMedia(q).matches") < 2000);
}
